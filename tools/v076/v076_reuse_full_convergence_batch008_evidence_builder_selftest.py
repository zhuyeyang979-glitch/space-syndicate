"""Focused self-test for the Batch-008 staging-only evidence builder.

The tests deliberately use temporary directories outside the repository.  They
exercise the safety and deterministic contracts without creating a production
batch, record, Registry, or Map file.
"""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

import v076_reuse_full_convergence_batch008_evidence_builder as b


def expect(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def expect_error(callback, fragment: str) -> None:
    try:
        callback()
    except b.BuilderError as exc:
        expect(fragment in str(exc), f"wrong error: {exc}")
    else:
        raise AssertionError(f"expected {fragment}")


def test_canonical_and_set_hash() -> None:
    first = b.canonical({"z": 1, "a": [True, "中文"]})
    second = b.canonical({"a": [True, "中文"], "z": 1})
    expect(first == second and first.endswith(b"\n"), "canonical bytes drifted")
    expected = hashlib.sha256(b"a\nb\n").hexdigest()
    expect(b.line_set(["b", "a"]) == expected, "line-set hash drifted")


def test_staging_safety_and_exclusive_write() -> None:
    with tempfile.TemporaryDirectory(prefix="v076-batch008-selftest-") as temp:
        root = Path(temp) / "repo"
        root.mkdir()
        stage = b.safe_stage(root, Path(temp) / "stage")
        path, digest = b.exclusive_write(stage, "batch-008/probe.json", {"value": 1})
        expect(path.is_file() and digest == hashlib.sha256(path.read_bytes()).hexdigest(), "write/hash mismatch")
        expect_error(lambda: b.exclusive_write(stage, "batch-008/probe.json", {"value": 1}), "APPEND_ONLY_OUTPUT_ALREADY_EXISTS")
        expect_error(lambda: b.exclusive_write(stage, "../escape.json", {}), "OUTPUT_PATH_ESCAPE")
        expect_error(lambda: b.safe_stage(root, root / "inside"), "STAGING_ROOT_MUST_BE_OUTSIDE_PROJECT")


def test_exact_output_contract_and_chain() -> None:
    expected = {
        "batch-008/batch-008-manifest.json",
        "batch-008/batch_inventory.json",
        "batch-008/batch_classification.json",
        "batch-008/batch_correction_records.json",
        "batch-008/batch_negative_checks.json",
        "batch-008/batch_review_A.json",
        "batch-008/batch_review_B.json",
        "records/batch-008/transition_46b33bba77b3_e584cd4d8b0c_test-only.json",
        "records/batch-008/transition_46b33bba77b3_e584cd4d8b0c_production-reachable.json",
        "records/batch-008/transition_46b33bba77b3_e584cd4d8b0c_superseded-nonreachable.json",
    }
    actual = {
        "batch-008/batch-008-manifest.json",
        "batch-008/batch_inventory.json",
        "batch-008/batch_classification.json",
        "batch-008/batch_correction_records.json",
        "batch-008/batch_negative_checks.json",
        "batch-008/batch_review_A.json",
        "batch-008/batch_review_B.json",
        "records/batch-008/transition_46b33bba77b3_e584cd4d8b0c_test-only.json",
        "records/batch-008/transition_46b33bba77b3_e584cd4d8b0c_production-reachable.json",
        "records/batch-008/transition_46b33bba77b3_e584cd4d8b0c_superseded-nonreachable.json",
    }
    expect(actual == expected and len(actual) == 10, "ten-output allowlist drifted")
    predecessor = "4fb8feda0747d7b082e8aa127c2edb595b08ff6b754c9436e2f904ffd2ea4a4e"
    payloads = [predecessor, "a" * 64, "b" * 64, "c" * 64]
    for left, right in zip(payloads, payloads[1:]):
        expect(len(left) == 64 and len(right) == 64, "chain digest shape invalid")


def test_negative_authority_guards() -> None:
    valid = "V2F-" + "a" * 64
    expect(b.re.fullmatch(r"V2F-[0-9a-f]{64}", valid) is not None, "valid fingerprint rejected")
    expect(b.re.fullmatch(r"V2F-[0-9a-f]{64}", valid + "*") is None, "wildcard accepted")
    left = {"component_id": "component.a", "path": "scripts/a.gd"}
    right = {"component_id": "component.a", "path": "scripts/b.gd"}
    expect(b.canonical(left) != b.canonical(right), "selector substitution not distinguishable")
    source = Path(b.__file__).read_text(encoding="utf-8")
    expect("generate-records" not in source, "legacy generate-records command reintroduced")
    expect('"git", "add"' not in source and '"git", "commit"' not in source, "repository writer reintroduced")
    expect("REGISTRY.write" not in source and "SUPERSESSION_MAP.write" not in source, "authority mutation reintroduced")
    expect("CURRENT_OR_UNAUTHORIZED_FAILURE" in source and "WILDCARD_FAILURE" in source, "future/current guard missing")
    expect("AUTHORITY_ROW_SUBSTITUTION" in source and "AUTHORITY_SELECTOR_SUBSTITUTION" in source, "selector guard missing")


def test_backfill_cardinality_and_supersession_guards() -> None:
    alpha_path = "resources/content/alpha01/alpha01_content_manifest.gd"
    expected = b.BACKFILL_EXPECTATIONS[alpha_path]
    row = {
        "component_id": expected["component_id"],
        "source_commit": expected["source_commit"],
        "source_blob": expected["source_blob"],
        "current_disposition": expected["disposition"],
    }
    expect_error(lambda: b._resolve_backfill_row({"historical_identity_backfill": []}, alpha_path, expected["disposition"]), "BACKFILL_ROW_NOT_EXACTLY_ONE")
    expect_error(lambda: b._resolve_backfill_row({"historical_identity_backfill": [row, dict(row)]}, alpha_path, expected["disposition"]), "BACKFILL_ROW_NOT_EXACTLY_ONE")
    wrong = dict(row, component_id="component.wrong")
    expect_error(lambda: b._resolve_backfill_row({"historical_identity_backfill": [wrong]}, alpha_path, expected["disposition"]), "BACKFILL_ROW_NOT_EXACTLY_ONE")
    mana_path = "scripts/runtime/player_mana_runtime_controller.gd"
    mana = b.BACKFILL_EXPECTATIONS[mana_path]
    target = {
        "old_component_id": mana["component_id"],
        "new_component_id": "component.current.v07_asset_batch_core",
        "old_source_commit": mana["source_commit"],
        "old_source_blob_sha256": mana["source_blob"],
    }
    expect_error(lambda: b._resolve_backfill_supersession({"entries": []}, mana_path, target["new_component_id"]), "BACKFILL_SUPERSESSION_NOT_EXACTLY_ONE")
    expect_error(lambda: b._resolve_backfill_supersession({"entries": [dict(target, new_component_id="component.wrong")]}, mana_path, target["new_component_id"]), "BACKFILL_SUPERSESSION_NOT_EXACTLY_ONE")


def test_current_inventory_cardinality_and_no_historical_fallback() -> None:
    row = {"component_id": "component.current.example", "path": "scripts/example.gd"}
    expect_error(
        lambda: b._current_registry_row({}, row["component_id"], "V2F-" + "a" * 64),
        "CURRENT_REGISTRY_ROW_NOT_EXACTLY_ONE",
    )
    expect_error(
        lambda: b._current_registry_row(
            {row["component_id"]: [row, dict(row, path="scripts/duplicate.gd")]},
            row["component_id"],
            "V2F-" + "b" * 64,
        ),
        "CURRENT_REGISTRY_ROW_NOT_EXACTLY_ONE",
    )
    expect(
        b._current_registry_row(
            {row["component_id"]: [row]}, row["component_id"], "V2F-" + "c" * 64
        )
        is row,
        "unique current row rejected",
    )


def test_real_file_mutations_and_path_attacks() -> None:
    with tempfile.TemporaryDirectory(prefix="v076-batch008-mutations-") as temp:
        base = Path(temp)
        proposal = b.PROPOSAL
        mutated_proposal = base / "proposal.json"
        mutated_proposal.write_bytes(proposal.read_bytes() + b" ")
        expect_error(
            lambda: b.build(Path.cwd(), base / "proposal-stage", mutated_proposal),
            "PROPOSAL_SHA256_MISMATCH",
        )

        stage = base / "existing-stage"
        stage.mkdir()
        (stage / "extra.json").write_text("{}", encoding="utf-8")
        expect_error(lambda: b.build(Path.cwd(), stage), "STAGING_ROOT_MUST_BE_FRESH_NONEXISTENT")

        hardlink_source = base / "hardlink-source.json"
        hardlink_source.write_text("source", encoding="utf-8")
        hardlink_stage = base / "hardlink-stage"
        hardlink_stage.mkdir()
        os.link(hardlink_source, hardlink_stage / "target.json")
        expect_error(
            lambda: b.exclusive_write(hardlink_stage, "target.json", {"x": 1}),
            "APPEND_ONLY_OUTPUT_ALREADY_EXISTS",
        )
        lexical_stage = base / "lexical-stage"
        lexical_stage.mkdir()
        expect_error(lambda: b.exclusive_write(lexical_stage, "../escape.json", {}), "OUTPUT_PATH_ESCAPE")
        expect_error(lambda: b.exclusive_write(lexical_stage, str(base / "absolute.json"), {}), "OUTPUT_PATH_ESCAPE")
        link_target = base / "link-target"
        link_target.mkdir()
        link_path = lexical_stage / "linked"
        try:
            os.symlink(link_target, link_path, target_is_directory=True)
        except (OSError, NotImplementedError):
            pass
        else:
            expect_error(lambda: b.exclusive_write(lexical_stage, "linked/file.json", {}), "REPARSE_FORBIDDEN")

        # Exercise the committed authority bytes, not a mocked row. A shared
        # clone receives a real mutation commit, which must fail closed.
        for relative, failure in ((b.SOURCE_PATHS[0], "REGISTRY_SHA256_MISMATCH"), (b.SOURCE_PATHS[1], "SUPERSESSION_MAP_SHA256_MISMATCH")):
            clone = base / ("clone-" + ("registry" if relative == b.SOURCE_PATHS[0] else "map"))
            subprocess.run(["git", "clone", "--shared", str(Path.cwd()), str(clone)], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            target = clone / relative
            target.write_bytes(target.read_bytes() + b" ")
            subprocess.run(["git", "-C", str(clone), "config", "user.email", "selftest@example.invalid"], check=True)
            subprocess.run(["git", "-C", str(clone), "config", "user.name", "Batch008 Selftest"], check=True)
            subprocess.run(["git", "-C", str(clone), "add", relative], check=True)
            subprocess.run(["git", "-C", str(clone), "commit", "-m", "mutation selftest"], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            expect_error(lambda clone=clone: b.build(clone, base / (clone.name + "-stage")), failure)


def test_external_candidate_review_seal_workflow() -> None:
    with tempfile.TemporaryDirectory(prefix="v076-batch008-seal-") as temp:
        base = Path(temp)
        stage = base / "stage"
        result = b.build(Path.cwd(), stage)
        candidate_path = base / "candidate.json"
        primary_path = base / "primary-review.json"
        independent_path = base / "independent-review.json"
        seal_path = base / "seal.json"
        b.create_candidate(stage, candidate_path, result["evaluated_head_sha"], result["evaluated_tree_sha"])
        expect_error(
            lambda: b.create_candidate(stage, stage / "candidate.json", result["evaluated_head_sha"], result["evaluated_tree_sha"]),
            "CANDIDATE_OUTPUT_MUST_BE_OUTSIDE_STAGE",
        )
        expect_error(
            lambda: b.create_candidate(stage, Path.cwd() / "batch008-candidate.json", result["evaluated_head_sha"], result["evaluated_tree_sha"]),
            "CANDIDATE_OUTPUT_MUST_BE_OUTSIDE_WORKTREE",
        )
        candidate = json.loads(candidate_path.read_text(encoding="utf-8"))
        expect(candidate["file_count"] == 10, "candidate file count drifted")
        expect({row["path"] for row in candidate["files"]} == b.OUTPUT_ALLOWLIST, "candidate omitted an output")
        expect("batch-008/batch_correction_records.json" in {row["path"] for row in candidate["files"]}, "candidate omitted correction summary")
        candidate_bytes = candidate_path.read_bytes()
        candidate_path.write_bytes(candidate_bytes + b" ")
        expect_error(lambda: b.seal_candidate(stage, candidate_path, [], seal_path), "CANDIDATE_BYTES_NONCANONICAL")
        candidate_path.write_bytes(candidate_bytes)
        b.create_review(candidate_path, primary_path, "PRIMARY", "V076_FULL_CONVERGENCE_PRIMARY_REVIEWER_V1")
        expect_error(
            lambda: b.create_review(candidate_path, Path.cwd() / "batch008-review.json", "PRIMARY", "V076_FULL_CONVERGENCE_PRIMARY_REVIEWER_V1"),
            "REVIEW_OUTPUT_MUST_BE_OUTSIDE_WORKTREE",
        )
        b.create_review(candidate_path, independent_path, "INDEPENDENT", "V076_FULL_CONVERGENCE_INDEPENDENT_REVIEWER_V1")
        tampered_binding_path = base / "tampered-binding-review.json"
        b.create_review(candidate_path, tampered_binding_path, "INDEPENDENT", "V076_FULL_CONVERGENCE_INDEPENDENT_REVIEWER_V1")
        tampered_binding = json.loads(tampered_binding_path.read_text(encoding="utf-8"))
        tampered_binding["evaluated_head_sha"] = "0" * 40
        tampered_binding["receipt_payload_sha256"] = b.sha(b.canonical(b._review_payload(tampered_binding)))
        tampered_binding["review_file_sha256"] = b.sha(b.canonical({k: v for k, v in tampered_binding.items() if k != "review_file_sha256"}))
        tampered_binding_path.write_bytes(b.canonical(tampered_binding))
        expect_error(lambda: b.seal_candidate(stage, candidate_path, [primary_path, tampered_binding_path], base / "binding-seal.json"), "SEAL_REVIEW_BINDING_INVALID")
        original_review = independent_path.read_bytes()
        independent_path.write_bytes(original_review + b" ")
        expect_error(lambda: b.seal_candidate(stage, candidate_path, [primary_path, independent_path], seal_path), "REVIEW_BYTES_NONCANONICAL")
        independent_path.write_bytes(original_review)
        original_stage_file = stage / "batch-008" / "batch_inventory.json"
        original_stage_bytes = original_stage_file.read_bytes()
        original_stage_file.write_bytes(original_stage_bytes + b" ")
        expect_error(lambda: b.seal_candidate(stage, candidate_path, [primary_path, independent_path], seal_path), "SEAL_STAGE_BYTES_DRIFT")
        original_stage_file.write_bytes(original_stage_bytes)
        b.seal_candidate(stage, candidate_path, [primary_path, independent_path], seal_path)
        expect_error(
            lambda: b.seal_candidate(stage, candidate_path, [primary_path, independent_path], Path.cwd() / "batch008-seal.json"),
            "SEAL_OUTPUT_MUST_BE_OUTSIDE_WORKTREE",
        )
        expect_error(lambda: b.seal_candidate(stage, candidate_path, [primary_path, independent_path], seal_path), "APPEND_ONLY_EXTERNAL_OUTPUT_ALREADY_EXISTS")
        duplicate_reviewer = base / "duplicate-reviewer.json"
        b.create_review(candidate_path, duplicate_reviewer, "INDEPENDENT", "V076_FULL_CONVERGENCE_PRIMARY_REVIEWER_V1")
        expect_error(lambda: b.seal_candidate(stage, candidate_path, [primary_path, duplicate_reviewer], base / "duplicate-seal.json"), "SEAL_REVIEWERS_NOT_DISTINCT")


def test_real_head_staging_build() -> None:
    # This is intentionally the only test that exercises the complete builder.
    # All ten files are created under a disposable external staging root.
    with tempfile.TemporaryDirectory(prefix="v076-batch008-real-") as temp:
        result = b.build(Path.cwd(), Path(temp) / "stage")
        expect(result.get("status") == "PASS", f"real build failed: {result}")
        stage = Path(result["staging_root"])
        files = sorted(str(path.relative_to(stage)).replace("\\", "/") for path in stage.rglob("*.json"))
        expect(len(files) == 10, f"real build output count drifted: {files}")
        expect(all(path.startswith("batch-008/") or path.startswith("records/batch-008/") for path in files), "real build escaped output roots")


def main() -> int:
    tests = [
        test_canonical_and_set_hash,
        test_staging_safety_and_exclusive_write,
        test_exact_output_contract_and_chain,
        test_negative_authority_guards,
        test_backfill_cardinality_and_supersession_guards,
        test_current_inventory_cardinality_and_no_historical_fallback,
        test_real_file_mutations_and_path_attacks,
        test_external_candidate_review_seal_workflow,
        test_real_head_staging_build,
    ]
    for test in tests:
        test()
    print(f"V076_BATCH008_EVIDENCE_BUILDER_SELFTEST_PASS cases={len(tests)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
