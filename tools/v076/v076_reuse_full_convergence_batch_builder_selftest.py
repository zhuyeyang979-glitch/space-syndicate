"""Focused self-test for the append-only full-convergence batch planner."""

from __future__ import annotations

import copy
import json
import os
import subprocess
import tempfile
from pathlib import Path

import v076_reuse_full_convergence_batch_builder as builder


AUTHORITY_SOURCE_HEAD = "38aa38f9881f01d67f94280678ade39b2bbee526"
AUTHORITY_LIVE_STATES = {
    "SOURCE",
    "APPLIED_UNCOMMITTED",
    "COMMITTED",
    "PARTIAL_OR_UNKNOWN",
}


def expect(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def expect_builder_error(fn, expected: str) -> None:
    try:
        fn()
    except builder.BuilderError as exc:
        expect(str(exc).startswith(expected), f"expected {expected!r}, got {exc!s}")
    else:
        raise AssertionError(f"expected BuilderError starting with {expected!r}")


def write_hashed_json(path: Path, payload: dict, hash_field: str) -> None:
    payload.pop(hash_field, None)
    payload[hash_field] = builder.sha(builder.canonical(payload))
    path.write_bytes(builder.canonical(payload))


def authority_review_payload(candidate: dict, review_id: str) -> dict:
    targets = builder._authority_target_bindings(candidate)
    authority = candidate["membership_authority"]
    payload = {
        "schema_version": builder.AUTHORITY_REVIEW_SCHEMA,
        "review_id": review_id,
        "reviewer_authority_id": builder.TRUSTED_REVIEWER_AUTHORITIES[review_id],
        "candidate_payload_sha256": candidate["candidate_payload_sha256"],
        "batch_id": candidate["batch_id"],
        "evaluated_head_sha": candidate["evaluated_head_sha"],
        "evaluated_tree_sha": candidate["evaluated_tree_sha"],
        "membership_candidate_file_sha256": authority["candidate_file_sha256"],
        "membership_seal_file_sha256": authority["seal_file_sha256"],
        "source_registry_sha256": targets[builder.REGISTRY.as_posix()]["source_bytes_sha256"],
        "source_supersession_map_sha256": targets[builder.SUPERSESSION_MAP.as_posix()]["source_bytes_sha256"],
        "target_registry_sha256": targets[builder.REGISTRY.as_posix()]["target_bytes_sha256"],
        "target_supersession_map_sha256": targets[builder.SUPERSESSION_MAP.as_posix()]["target_bytes_sha256"],
        "mutation_inventory_sha256": candidate["mutation_inventory_sha256"],
        "status": "GO",
        "p0_count": 0,
        "p1_count": 0,
        "findings": [],
    }
    payload["receipt_payload_sha256"] = builder.sha(builder.canonical(payload))
    return payload


def git_bytes(root: Path, *args: str) -> bytes | None:
    process = subprocess.run(
        ["git", *args],
        cwd=root,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    return process.stdout if process.returncode == 0 else None


def file_sha256(path: Path) -> str:
    try:
        return builder.sha(path.read_bytes())
    except OSError:
        return "MISSING"


def git_payload_sha256(root: Path, revision: str) -> str:
    payload = git_bytes(root, "show", revision)
    return builder.sha(payload) if payload is not None else "MISSING"


def classify_live_authority_state(root: Path, candidate: dict) -> str:
    """Classify exact authority bytes without mutating the live worktree."""

    head = builder.git(root, "rev-parse", "HEAD")
    rows = builder._authority_target_bindings(candidate)
    worktree_hashes = {
        relative: file_sha256(root / Path(relative))
        for relative in (builder.REGISTRY.as_posix(), builder.SUPERSESSION_MAP.as_posix())
    }
    head_hashes = {
        relative: git_payload_sha256(root, f"HEAD:{relative}")
        for relative in worktree_hashes
    }
    index_hashes = {
        relative: git_payload_sha256(root, f":{relative}")
        for relative in worktree_hashes
    }
    source = {
        relative: rows[relative]["source_bytes_sha256"]
        for relative in worktree_hashes
    }
    target = {
        relative: rows[relative]["target_bytes_sha256"]
        for relative in worktree_hashes
    }
    source_head = candidate["evaluated_head_sha"]
    if (
        head == source_head
        and worktree_hashes == source
        and head_hashes == source
        and index_hashes == source
    ):
        return "SOURCE"
    if (
        head == source_head
        and worktree_hashes == target
        and head_hashes == source
        and index_hashes == source
    ):
        return "APPLIED_UNCOMMITTED"
    if worktree_hashes == target and head_hashes == target and index_hashes == target:
        return "COMMITTED"
    return "PARTIAL_OR_UNKNOWN"


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    cases: list[dict[str, str]] = []

    def run(name: str, fn) -> None:
        try:
            fn(); cases.append({"name": name, "status": "PASS"})
        except Exception as exc:
            cases.append({"name": name, "status": "FAIL", "failure": f"{type(exc).__name__}: {exc}"})

    plan_holder: dict[str, object] = {}
    phase1_holder: dict[str, object] = {}
    authority_holder: dict[str, object] = {}

    def plan_case() -> None:
        first = builder.derive_plan(root)
        second = builder.derive_plan(root)
        expect(builder.canonical(first) == builder.canonical(second), "plan is not byte deterministic")
        expect(first["primary_authority_count"] == 501, str(first))
        expect(first["legacy_count"] == 12, str(first))
        expect(first["frozen_batch_001_007_count"] == 239, str(first))
        expect(first["remaining_count"] == 250, str(first))
        expect(first["component_remaining_count"] == 239, str(first))
        expect(first["dynamic_remaining_count"] == 11, str(first))
        expect([first["batches"][f"batch-{n:03d}"]["failure_count"] for n in range(8, 14)] == [50, 50, 50, 50, 39, 11], str(first))
        expect(first["batches"]["batch-013"]["terminal_remainder_batch"] is True, str(first))
        plan_holder["plan"] = first

    run("frozen 501-12-239 partition yields exact 250 plan", plan_case)

    def transition_case() -> None:
        plan = plan_holder["plan"]
        expected = {
            "batch-008": {"46b33bba77b3->e584cd4d8b0c": 50},
            "batch-009": {"46b33bba77b3->e584cd4d8b0c": 50},
            "batch-010": {"46b33bba77b3->e584cd4d8b0c": 48, "8208001e7be8->62ceba063d68": 1, "d701a81dce69->0d2a2b798f32": 1},
            "batch-011": {"46b33bba77b3->e584cd4d8b0c": 50},
            "batch-012": {"46b33bba77b3->e584cd4d8b0c": 39},
            "batch-013": {"46b33bba77b3->e584cd4d8b0c": 7, "8208001e7be8->62ceba063d68": 4},
        }
        for batch_id, counts in expected.items():
            expect(plan["batches"][batch_id]["transition_counts"] == counts, batch_id)

    run("transition partitions are exact and multi-transition aware", transition_case)

    with tempfile.TemporaryDirectory(prefix="v76-") as temp_name:
        temp = Path(temp_name)
        authority_root = temp / "c"
        cloned = subprocess.run(
            [
                "git", "clone", "--shared", "--no-checkout",
                str(root), str(authority_root),
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        expect(
            cloned.returncode == 0,
            f"shared clone failed: {cloned.stderr.decode(errors='replace').strip()}",
        )
        for key, value in (
            ("core.autocrlf", "false"),
            ("core.safecrlf", "false"),
            ("core.longpaths", "true"),
        ):
            subprocess.run(
                ["git", "config", key, value],
                cwd=authority_root,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=True,
            )
        subprocess.run(
            ["git", "checkout", "--detach", AUTHORITY_SOURCE_HEAD],
            cwd=authority_root,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=True,
        )
        expect(
            builder.git(authority_root, "rev-parse", "HEAD") == AUTHORITY_SOURCE_HEAD,
            "disposable authority clone did not pin the fixed source HEAD",
        )
        initial_clone_status = builder.git(authority_root, "status", "--porcelain")
        expect(
            initial_clone_status == "",
            f"disposable authority clone is not initially clean: {initial_clone_status}",
        )

        def candidate_case() -> None:
            path = temp / "candidate.json"
            candidate = builder.build_candidate(authority_root, "batch-008", temp, path)
            expect(path.is_file(), "candidate missing")
            expect(candidate["go_claim"] is False, str(candidate))
            expect(candidate["review_status"] == "PENDING", str(candidate))
            expect(candidate["official_batch_write_count"] == 0, str(candidate))
            try:
                builder.build_candidate(authority_root, "batch-008", temp, path)
            except builder.BuilderError as exc:
                expect(str(exc) == "APPEND_ONLY_OUTPUT_ALREADY_EXISTS", str(exc))
            else:
                raise AssertionError("append-only overwrite was accepted")

        run("candidate is non-authoritative and append-only", candidate_case)

        def forbidden_case() -> None:
            forbidden = authority_root / builder.BATCH_ROOT / "batch-008" / "candidate.json"
            try:
                builder._assert_output_safe(authority_root, temp, forbidden)
            except builder.BuilderError as exc:
                expect(str(exc) == "CANDIDATE_OUTPUT_INSIDE_AUTHORITY_ROOT", str(exc))
            else:
                raise AssertionError("authority-root candidate output accepted")
            try:
                builder._assert_output_safe(
                    authority_root,
                    authority_root / ".candidate-stage",
                    authority_root / ".candidate-stage" / "x.json",
                )
            except builder.BuilderError as exc:
                expect(str(exc) == "STAGING_ROOT_MUST_BE_OUTSIDE_PROJECT", str(exc))
            else:
                raise AssertionError("project-local staging root accepted")

        run("candidate requires explicit external staging root", forbidden_case)

        def review_case() -> None:
            candidate_path = temp / "review-candidate.json"
            candidate = builder.build_candidate(
                authority_root, "batch-008", temp, candidate_path
            )
            receipts = []
            for review_id in ("PRIMARY", "INDEPENDENT"):
                path = temp / f"{review_id}.json"
                review = {
                    "schema_version": builder.REVIEW_SCHEMA,
                    "review_id": review_id,
                    "reviewer_authority_id": builder.TRUSTED_REVIEWER_AUTHORITIES[review_id],
                    "candidate_payload_sha256": candidate["candidate_payload_sha256"],
                    "batch_id": "batch-008",
                    "evaluated_head_sha": candidate["evaluated_head_sha"],
                    "plan_sha256": candidate["plan_sha256"],
                    "failure_fingerprint_set_sha256": candidate["failure_fingerprint_set_sha256"],
                    "status": "GO",
                    "p0_count": 0,
                    "p1_count": 0,
                    "findings": [],
                }
                review["receipt_payload_sha256"] = builder.sha(builder.canonical(review))
                path.write_bytes(builder.canonical(review))
                receipts.append(path)
            seal_path = temp / "seal.json"
            result = builder.seal_candidate(
                authority_root, candidate_path, receipts, temp, seal_path
            )
            expect(result["review_status"] == "DUAL_REVIEW_PASS", str(result))
            expect(result["official_batch_write_count"] == 0, str(result))
            phase1_holder.update({
                "candidate_path": candidate_path,
                "candidate": candidate,
                "seal_path": seal_path,
                "seal": result,
            })
            bad = temp / "bad.json"
            bad.write_bytes(receipts[0].read_bytes())
            try:
                builder.seal_candidate(authority_root, candidate_path, [receipts[0], bad], temp, temp / "bad-seal.json")
            except builder.BuilderError as exc:
                expect(str(exc) == "REVIEWER_SET_INVALID", str(exc))
            else:
                raise AssertionError("duplicate reviewer set accepted")
            bool_receipt = temp / "bool-count.json"
            bad_review = json.loads(receipts[1].read_text(encoding="utf-8"))
            bad_review["p0_count"] = False
            bad_review.pop("receipt_payload_sha256")
            bad_review["receipt_payload_sha256"] = builder.sha(builder.canonical(bad_review))
            bool_receipt.write_bytes(builder.canonical(bad_review))
            try:
                builder.seal_candidate(authority_root, candidate_path, [receipts[0], bool_receipt], temp, temp / "bool-seal.json")
            except builder.BuilderError as exc:
                expect(str(exc).startswith("REVIEW_NOT_ACCEPTABLE:"), str(exc))
            else:
                raise AssertionError("boolean review count accepted as exact integer")
            wrong_authority = temp / "wrong-authority.json"
            bad_review = json.loads(receipts[1].read_text(encoding="utf-8"))
            bad_review["reviewer_authority_id"] = builder.TRUSTED_REVIEWER_AUTHORITIES["PRIMARY"]
            bad_review.pop("receipt_payload_sha256")
            bad_review["receipt_payload_sha256"] = builder.sha(builder.canonical(bad_review))
            wrong_authority.write_bytes(builder.canonical(bad_review))
            try:
                builder.seal_candidate(authority_root, candidate_path, [receipts[0], wrong_authority], temp, temp / "authority-seal.json")
            except builder.BuilderError as exc:
                expect(str(exc).startswith("REVIEW_NOT_ACCEPTABLE:"), str(exc))
            else:
                raise AssertionError("cross-wired reviewer authority accepted")
            extra_field_candidate = temp / "extra-field-candidate.json"
            bad_candidate = json.loads(candidate_path.read_text(encoding="utf-8"))
            bad_candidate["unexpected"] = "field"
            bad_candidate.pop("candidate_payload_sha256")
            bad_candidate["candidate_payload_sha256"] = builder.sha(builder.canonical(bad_candidate))
            extra_field_candidate.write_bytes(builder.canonical(bad_candidate))
            try:
                builder.seal_candidate(authority_root, extra_field_candidate, receipts, temp, temp / "extra-field-seal.json")
            except builder.BuilderError as exc:
                expect(str(exc) == "CANDIDATE_CONTRACT_INVALID", str(exc))
            else:
                raise AssertionError("candidate with an unknown field was accepted")
            static_attacks = {
                "authorization_id": "WRONG_AUTHORIZATION",
                "candidate_kind": "AUTHORITATIVE_BATCH",
                "required_review_ids": ["INDEPENDENT", "PRIMARY"],
                "review_status": "PASS",
                "official_batch_write_count": False,
                "official_record_write_count": 999,
                "next_builder_phase": "SKIP_VALIDATORS",
            }
            for field, value in static_attacks.items():
                attack_path = temp / f"static-{field}.json"
                attacked = json.loads(candidate_path.read_text(encoding="utf-8"))
                attacked[field] = value
                attacked.pop("candidate_payload_sha256")
                attacked["candidate_payload_sha256"] = builder.sha(builder.canonical(attacked))
                attack_path.write_bytes(builder.canonical(attacked))
                try:
                    builder.seal_candidate(authority_root, attack_path, receipts, temp, temp / f"static-{field}-seal.json")
                except builder.BuilderError as exc:
                    expect(str(exc) == "CANDIDATE_CONTRACT_INVALID", f"{field}: {exc}")
                else:
                    raise AssertionError(f"candidate static field attack accepted: {field}")

        run("seal requires two distinct exact candidate-bound reviews", review_case)

        def batch008_projection_case() -> None:
            head = builder.git(authority_root, "rev-parse", "HEAD")
            rows = builder._exact_batch008_component_rows(authority_root, head)
            expect(len(rows) == 48, str(len(rows)))
            expect(
                builder.sha(builder.compact_canonical(rows))
                == "8473e342ba1d617c6b5b5147b2afa4eeb5fc9f1c7cd6ae0a94366e41312c715c",
                "Batch-008 component projection drift",
            )
            counts = {
                role: sum(row["component_role"] == role for row in rows)
                for role in ("TEST_SUPPORT", "PORT", "PRESENTATION")
            }
            expect(counts == {"TEST_SUPPORT": 45, "PORT": 1, "PRESENTATION": 2}, str(counts))
            expect(sum(row["production_reachable"] is True for row in rows) == 3, str(rows))
            for row in rows:
                tagged = {"authority_source_kind": "component_inventory", **row}
                expect(builder.convergence._registry_row_failures(tagged) == [], row["path"])
            membership_rows = phase1_holder["candidate"]["rows"]
            projected_paths = {row["path"] for row in rows} | {
                builder.BATCH008_ALPHA01_HISTORICAL_PATH,
                builder.BATCH008_PLAYER_MANA_HISTORICAL_PATH,
            }
            actual_paths = {value["subject_value"] for value in membership_rows.values()}
            expect(projected_paths == actual_paths and len(actual_paths) == 50, str(actual_paths))

        run("Batch-008 projects exact 48 component rows plus two backfills", batch008_projection_case)

        def authority_candidate_case() -> None:
            candidate_path = temp / "authority-candidate.json"
            candidate = builder.build_authority_candidate(
                authority_root,
                phase1_holder["candidate_path"],
                phase1_holder["seal_path"],
                temp,
                candidate_path,
            )
            expect(candidate_path.is_file(), "authority candidate missing")
            expect(candidate["go_claim"] is False, str(candidate))
            expect(candidate["official_write_count"] == 0, str(candidate))
            expect([row["path"] for row in candidate["target_files"]] == [
                builder.REGISTRY.as_posix(), builder.SUPERSESSION_MAP.as_posix()
            ], str(candidate["target_files"]))
            targets = builder._authority_target_bindings(candidate)
            expect(
                targets[builder.REGISTRY.as_posix()]["target_bytes_sha256"]
                == "9b2eb0aac38e8db38258f5f71d0436ff9e016c4b76fc46f8b82d4c9688b922d7",
                str(targets),
            )
            expect(
                targets[builder.SUPERSESSION_MAP.as_posix()]["target_bytes_sha256"]
                == "e18b7d6eb47de0d2e4cc3f6e6f829e476afdfe5f9f3cc2c1741d2d1d726b330f",
                str(targets),
            )
            expect(len(candidate["mutation_inventory"]) == 4, str(candidate))
            live_state = classify_live_authority_state(root, candidate)
            expect(live_state in AUTHORITY_LIVE_STATES, live_state)
            authority_holder.update({
                "candidate": candidate,
                "candidate_path": candidate_path,
                "live_state": live_state,
            })

        run("authority candidate binds sealed membership and exact two targets", authority_candidate_case)

        def authority_candidate_negative_case() -> None:
            candidate = authority_holder["candidate"]
            bool_path = temp / "authority-candidate-bool.json"
            attacked = copy.deepcopy(candidate)
            attacked["go_claim"] = 0
            write_hashed_json(bool_path, attacked, "candidate_payload_sha256")
            expect_builder_error(
                lambda: builder._validate_authority_candidate_fresh(
                    authority_root, bool_path
                ),
                "AUTHORITY_CANDIDATE_CONTRACT_INVALID",
            )

            target = copy.deepcopy(candidate["target_files"][0])
            target["target_byte_count"] += 1
            expect_builder_error(
                lambda: builder._decode_authority_target(target, "tampered"),
                "AUTHORITY_TARGET_PAYLOAD_INVALID",
            )
            target = copy.deepcopy(candidate["target_files"][0])
            target["target_bytes_base64"] = "%%%"
            expect_builder_error(
                lambda: builder._decode_authority_target(target, "base64"),
                "AUTHORITY_TARGET_BASE64_INVALID",
            )
            mutation = copy.deepcopy(candidate["mutation_inventory"])
            mutation[0]["locator"] += ";path=*"
            expect_builder_error(
                lambda: builder._validate_mutation_inventory(mutation),
                "AUTHORITY_MUTATION_ROW_INVALID",
            )

            hardlink_path = temp / "authority-candidate-hardlink.json"
            os.link(authority_holder["candidate_path"], hardlink_path)
            try:
                expect_builder_error(
                    lambda: builder._validate_authority_candidate_fresh(
                        authority_root, hardlink_path
                    ),
                    "AUTHORITY_CANDIDATE_HARDLINK_FORBIDDEN",
                )
            finally:
                hardlink_path.unlink()
            symlink_path = temp / "authority-candidate-symlink.json"
            try:
                symlink_path.symlink_to(authority_holder["candidate_path"])
            except OSError:
                pass
            else:
                try:
                    expect_builder_error(
                        lambda: builder._validate_authority_candidate_fresh(
                            authority_root, symlink_path
                        ),
                        "AUTHORITY_CANDIDATE_REPARSE_FORBIDDEN",
                    )
                finally:
                    symlink_path.unlink()

        run("authority inputs reject bool payload and path or byte drift", authority_candidate_negative_case)

        def authority_target_path_safety_case() -> None:
            hardlink_root = temp / "authority-target-hardlink-root"
            hardlink_parent = hardlink_root / builder.REGISTRY.parent
            hardlink_parent.mkdir(parents=True)
            hardlink_target = hardlink_root / builder.REGISTRY
            hardlink_target.write_bytes(b"{}\n")
            hardlink_alias = hardlink_parent / "registry-hardlink-alias.json"
            os.link(hardlink_target, hardlink_alias)
            try:
                expect_builder_error(
                    lambda: builder._require_plain_repo_file(
                        hardlink_root, builder.REGISTRY
                    ),
                    "AUTHORITY_TARGET_HARDLINK_FORBIDDEN",
                )
            finally:
                hardlink_alias.unlink()

            junction_root = temp / "authority-target-junction-root"
            junction_parent = junction_root / builder.REGISTRY.parent
            junction_parent.parent.mkdir(parents=True)
            real_parent = temp / "authority-target-real-parent"
            real_parent.mkdir()
            (real_parent / builder.REGISTRY.name).write_bytes(b"{}\n")
            if os.name == "nt":
                created = subprocess.run(
                    [
                        "cmd.exe", "/d", "/c", "mklink", "/J",
                        str(junction_parent), str(real_parent),
                    ],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    check=False,
                ).returncode == 0
            else:
                try:
                    junction_parent.symlink_to(real_parent, target_is_directory=True)
                except OSError:
                    created = False
                else:
                    created = True
            expect(created, "unable to construct target-parent junction/symlink")
            try:
                expect_builder_error(
                    lambda: builder._require_plain_repo_file(
                        junction_root, builder.REGISTRY
                    ),
                    "AUTHORITY_TARGET_PARENT_REPARSE_FORBIDDEN",
                )
            finally:
                if junction_parent.is_symlink():
                    junction_parent.unlink()
                else:
                    os.rmdir(junction_parent)

        run(
            "authority targets reject hardlinks and parent junctions",
            authority_target_path_safety_case,
        )

        def authority_seal_case() -> None:
            candidate = authority_holder["candidate"]
            reviews: list[Path] = []
            for review_id in ("PRIMARY", "INDEPENDENT"):
                path = temp / f"authority-{review_id}.json"
                path.write_bytes(builder.canonical(authority_review_payload(candidate, review_id)))
                reviews.append(path)
            snapshots = builder._validate_authority_review_set(
                candidate, reviews, authority_root, temp
            )
            expect({snapshot[0]["review_id"] for snapshot in snapshots} == {"PRIMARY", "INDEPENDENT"}, str(snapshots))

            bool_review_path = temp / "authority-review-bool.json"
            bad_review = authority_review_payload(candidate, "INDEPENDENT")
            bad_review["p0_count"] = False
            write_hashed_json(bool_review_path, bad_review, "receipt_payload_sha256")
            expect_builder_error(
                lambda: builder._validate_authority_review_set(
                    candidate, [reviews[0], bool_review_path], authority_root, temp
                ),
                "AUTHORITY_REVIEW_NOT_ACCEPTABLE",
            )
            expect_builder_error(
                lambda: builder._validate_authority_review_set(
                    candidate, [reviews[0], reviews[0]], authority_root, temp
                ),
                "AUTHORITY_REVIEWER_SET_INVALID",
            )

            seal_path = temp / "authority-seal.json"
            seal = builder.seal_authority_candidate(
                authority_root,
                authority_holder["candidate_path"],
                reviews,
                temp,
                seal_path,
            )
            expect(seal["go_claim"] is True, str(seal))
            expect(seal["official_write_count"] == 0, str(seal))
            expect([row["review_id"] for row in seal["review_receipts"]] == [
                "INDEPENDENT", "PRIMARY"
            ], str(seal))
            authority_holder.update({
                "reviews": reviews,
                "seal": seal,
                "seal_path": seal_path,
            })

        run("authority seal requires two distinct exact target-bound reviews", authority_seal_case)

        def authority_preflight_case() -> None:
            result = builder.preflight_authority_apply(
                authority_root,
                authority_holder["candidate_path"],
                authority_holder["seal_path"],
                temp,
            )
            expect(result["status"] == "PASS", str(result))
            expect(result["target_file_count"] == 2, str(result))
            expect(result["official_write_count"] == 0, str(result))

            attacked_seal_path = temp / "authority-seal-bool.json"
            attacked = copy.deepcopy(authority_holder["seal"])
            attacked["go_claim"] = 1
            write_hashed_json(attacked_seal_path, attacked, "seal_payload_sha256")
            expect_builder_error(
                lambda: builder._validate_authority_seal(
                    authority_root,
                    authority_holder["candidate_path"],
                    attacked_seal_path,
                    require_source_worktree=True,
                ),
                "AUTHORITY_SEAL_CONTRACT_INVALID",
            )

        run("authority preflight is zero-write and rejects seal bool-as-int", authority_preflight_case)

        def authority_verify_case() -> None:
            candidate = authority_holder["candidate"]
            candidate_path = authority_holder["candidate_path"]
            seal_path = authority_holder["seal_path"]
            target_bytes = {
                row["path"]: builder._decode_authority_target(row, row["path"])
                for row in candidate["target_files"]
            }
            expect(
                classify_live_authority_state(authority_root, candidate) == "SOURCE",
                "disposable authority clone did not begin at exact source bytes",
            )
            preflight = builder.preflight_authority_apply(
                authority_root, candidate_path, seal_path, temp
            )
            expect(preflight["preflight_status"] == "EXACT_TWO_FILE_SOURCE_STATE_VERIFIED", str(preflight))

            registry_path = authority_root / builder.REGISTRY
            map_path = authority_root / builder.SUPERSESSION_MAP
            registry_path.write_bytes(target_bytes[builder.REGISTRY.as_posix()])
            expect(
                classify_live_authority_state(authority_root, candidate)
                == "PARTIAL_OR_UNKNOWN",
                "one-file authority apply was not classified as partial",
            )
            expect_builder_error(
                lambda: builder.verify_authority_applied(
                    authority_root, candidate_path, seal_path, temp
                ),
                f"AUTHORITY_TARGET_NOT_APPLIED:{builder.SUPERSESSION_MAP.as_posix()}",
            )
            expect_builder_error(
                lambda: builder.preflight_authority_apply(
                    authority_root, candidate_path, seal_path, temp
                ),
                f"AUTHORITY_WORKTREE_DRIFT:{builder.REGISTRY.as_posix()}",
            )

            map_path.write_bytes(target_bytes[builder.SUPERSESSION_MAP.as_posix()])
            expect(
                classify_live_authority_state(authority_root, candidate)
                == "APPLIED_UNCOMMITTED",
                "exact target bytes were not classified as applied-uncommitted",
            )
            verified = builder.verify_authority_applied(
                authority_root, candidate_path, seal_path, temp
            )
            expect(verified["verified_file_count"] == 2, str(verified))

            bindings = builder._authority_target_bindings(candidate)
            wrong_oid = bindings[builder.SUPERSESSION_MAP.as_posix()]["source_blob_oid"]
            registry_source_oid = bindings[builder.REGISTRY.as_posix()]["source_blob_oid"]
            subprocess.run(
                [
                    "git", "update-index", "--cacheinfo", "100644",
                    wrong_oid, builder.REGISTRY.as_posix(),
                ],
                cwd=authority_root,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=True,
            )
            expect_builder_error(
                lambda: builder.verify_authority_applied(
                    authority_root, candidate_path, seal_path, temp
                ),
                f"AUTHORITY_INDEX_DRIFT:{builder.REGISTRY.as_posix()}",
            )
            subprocess.run(
                [
                    "git", "update-index", "--cacheinfo", "100644",
                    registry_source_oid, builder.REGISTRY.as_posix(),
                ],
                cwd=authority_root,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=True,
            )
            verified_again = builder.verify_authority_applied(
                authority_root, candidate_path, seal_path, temp
            )
            expect(verified_again["verified_file_count"] == 2, str(verified_again))

            subprocess.run(
                [
                    "git", "add", "--",
                    builder.REGISTRY.as_posix(),
                    builder.SUPERSESSION_MAP.as_posix(),
                ],
                cwd=authority_root,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=True,
            )
            subprocess.run(
                [
                    "git",
                    "-c", "user.name=V076 Builder Selftest",
                    "-c", "user.email=v076-builder-selftest@example.invalid",
                    "-c", "core.hooksPath=NUL",
                    "commit", "--no-gpg-sign", "-m",
                    "test: temporary Batch-008 authority application",
                ],
                cwd=authority_root,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=True,
            )
            expect(
                classify_live_authority_state(authority_root, candidate) == "COMMITTED",
                "temporary exact-target commit was not classified as committed",
            )
            expect_builder_error(
                lambda: builder._validate_authority_candidate_fresh(
                    authority_root,
                    candidate_path,
                    require_source_worktree=True,
                ),
                "AUTHORITY_CANDIDATE_HEAD_DRIFT",
            )
            authority_holder["temp_commit_head"] = builder.git(
                authority_root, "rev-parse", "HEAD"
            )

        run(
            "authority lifecycle rejects partial apply, index drift, and stale candidate after commit",
            authority_verify_case,
        )

        def successor_append_case() -> None:
            candidate = authority_holder["candidate"]
            target = builder._decode_authority_target(candidate["target_files"][0], "registry")
            parsed = builder.strict_json_bytes(target, "BATCH008_TARGET")
            dummy = copy.deepcopy(parsed["component_inventory"][-1])
            dummy["component_id"] += ".successor_selftest"
            dummy["class_name"] += "SuccessorSelftest"
            dummy["path"] += ".successor_selftest"
            appended = builder._append_component_inventory_bytes(target, parsed, [dummy])
            after = builder.strict_json_bytes(appended, "SUCCESSOR_COMPONENT_APPEND")
            expect(len(after["component_inventory"]) == len(parsed["component_inventory"]) + 1, str(after))
            expect(after["historical_identity_backfill"] == parsed["historical_identity_backfill"], str(after))

            new_backfill = copy.deepcopy(parsed["historical_identity_backfill"][-1])
            new_backfill["component_id"] += ".successor_selftest"
            appended_backfill = builder._append_historical_backfill_bytes(
                target, parsed, [new_backfill]
            )
            after_backfill = builder.strict_json_bytes(appended_backfill, "SUCCESSOR_BACKFILL_APPEND")
            expect(
                len(after_backfill["historical_identity_backfill"])
                == len(parsed["historical_identity_backfill"]) + 1,
                str(after_backfill),
            )
            expect_builder_error(
                lambda: builder._splice_once(b"x", b"missing", b"y", "ZERO"),
                "SPLICE_ANCHOR_CARDINALITY_INVALID",
            )
            expect_builder_error(
                lambda: builder._splice_once(b"aa", b"a", b"b", "TWO"),
                "SPLICE_ANCHOR_CARDINALITY_INVALID",
            )

        run("successor append preserves existing backfill and anchor cardinality", successor_append_case)

    passed = sum(row["status"] == "PASS" for row in cases)
    report = {
        "schema_version": "space_syndicate.v076.reuse_full_convergence.batch_builder_selftest.v1",
        "status": "PASS" if passed == len(cases) else "FAIL",
        "case_count": len(cases),
        "pass_count": passed,
        "live_authority_state": authority_holder.get(
            "live_state", "PARTIAL_OR_UNKNOWN"
        ),
        "cases": cases,
    }
    print(json.dumps(report, sort_keys=True))
    return 0 if passed == len(cases) else 1


if __name__ == "__main__":
    raise SystemExit(main())
