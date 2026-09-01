#!/usr/bin/env python3
"""Focused contract tests for the append-only post-touch sidecar."""

from __future__ import annotations

import tempfile
from pathlib import Path
from unittest.mock import patch

import v076_post_touch_revalidation as subject


def _write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(subject.canonical_bytes(value))


def _exercise_complete_record(
    source_root: Path,
    *,
    semantic_at_binding: bool = False,
    malformed_field: str = "",
) -> dict[str, object]:
    """Run one record through the complete repository/projection path."""

    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        schema_path = root / subject.SCHEMA_REL
        schema_path.parent.mkdir(parents=True, exist_ok=True)
        schema_path.write_bytes((source_root / subject.SCHEMA_REL).read_bytes())

        fingerprint = "V2F-" + "1" * 64
        current_fingerprint = "V2F-" + "2" * 64
        prior_head = "1" * 40
        touch_commit = "2" * 40
        binding_head = touch_commit
        artifact_head = "3" * 40
        prior_tree = "a" * 40
        binding_tree = "b" * 40
        artifact_tree = "c" * 40
        current_path = "scripts/example.gd"
        # The real 2a111 correction binds historical_path == current_path while
        # its source-commit historical blob differs from the prior binding blob.
        historical_path = current_path
        before_bytes = b"extends Node\nvar value = 1\n"
        after_bytes = b"extends Node\nvar value = 2\n"
        historical_bytes = b"extends Node\nvar historical = true\n"
        before_sha = subject.sha256_bytes(before_bytes)
        after_sha = subject.sha256_bytes(after_bytes)
        historical_sha = subject.sha256_bytes(historical_bytes)
        diff_sha = subject.sha256_bytes(b"exact modeled diff")
        projection = {
            "component_id": "PRESENTATION_ANIMATION_DIRECTOR",
            "owner_id": "PRESENTATION_OWNER",
        }
        selector = {"component_ids": ["PRESENTATION_ANIMATION_DIRECTOR"]}

        for relative, payload in ((current_path, after_bytes),):
            target = root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(payload)

        prior_record_rel = (
            subject.FULL_RECORD_ROOT / "batch-001" / "prior-record.json"
        ).as_posix()
        prior_payload_sha = subject.sha256_bytes(b"prior payload")
        prior_record = {
            "binding_head_sha": prior_head,
            "correction_id": "V076-FULL-CONVERGENCE-001",
            "failure_fingerprints": [fingerprint],
            "identity_binding_by_failure": {
                fingerprint: {
                    "authority_selectors": selector,
                    "current_blob_sha256": before_sha,
                    "current_path": current_path,
                    "historical_blob_sha256": historical_sha,
                    "historical_path": historical_path,
                    "subject_projection": projection,
                }
            },
            "record_payload_sha256": prior_payload_sha,
        }
        prior_record_path = root / prior_record_rel
        _write_json(prior_record_path, prior_record)
        prior_record_sha = subject.sha256_file(prior_record_path)

        prior_batch_rel = (
            subject.FULL_BATCH_ROOT / "batch-001" / "batch-001-manifest.json"
        ).as_posix()
        prior_batch = {
            "authorization_base_head_sha": subject.AUTHORIZATION_BASE_HEAD,
            "authorization_id": subject.AUTHORIZATION_ID,
            "batch_id": "batch-001",
            "binding_head_sha": prior_head,
            "binding_tree_sha": prior_tree,
            "previous_batch_append_sha256": "",
            "record_bindings": [
                {
                    "correction_id": prior_record["correction_id"],
                    "failure_fingerprints": [fingerprint],
                    "path": prior_record_rel,
                    "record_payload_sha256": prior_payload_sha,
                    "record_sha256": prior_record_sha,
                }
            ],
            "record_chain_start_sha256": subject.LEGACY_RECORD_CHAIN_TERMINAL_SHA256,
            "record_chain_terminal_sha256": prior_payload_sha,
            "schema_version": "space_syndicate.v076.reuse_exact_failure_correction.v2.full_convergence_batch.v1",
        }
        prior_batch_path = root / prior_batch_rel
        _write_json(prior_batch_path, prior_batch)

        current_batch_rel = (
            subject.FULL_BATCH_ROOT / "batch-002" / "batch-002-manifest.json"
        ).as_posix()
        current_batch = {
            "authorization_base_head_sha": subject.AUTHORIZATION_BASE_HEAD,
            "authorization_id": subject.AUTHORIZATION_ID,
            "batch_id": "batch-002",
            "binding_head_sha": prior_head,
            "binding_tree_sha": prior_tree,
            "failure_fingerprints": [current_fingerprint],
            "previous_batch_append_sha256": subject.sha256_file(prior_batch_path),
            "record_chain_start_sha256": prior_payload_sha,
            "record_chain_terminal_sha256": subject.sha256_bytes(b"current terminal"),
            "schema_version": subject.FULL_BATCH_SCHEMA_VERSION,
        }
        current_batch_path = root / current_batch_rel
        _write_json(current_batch_path, current_batch)

        record_rel = (subject.RECORD_ROOT / "record-valid.json").as_posix()
        record = {
            "authorization_base_head_sha": subject.AUTHORIZATION_BASE_HEAD,
            "authorization_id": subject.AUTHORIZATION_ID,
            "correction_batch_manifest_path": prior_batch_rel,
            "correction_batch_manifest_sha256": subject.sha256_file(prior_batch_path),
            "created_at": "2026-08-28T00:00:00Z",
            "creator": "V076_POST_TOUCH_SELFTEST",
            "failure_fingerprint_set_sha256": subject.line_set_sha([fingerprint]),
            "failure_fingerprints": [fingerprint],
            "future_failure_policy": subject.FUTURE_FAILURE_POLICY,
            "new_effective_status": "CORRECTED_HISTORICAL_DEBT",
            "previous_revalidation_chain_sha256": "",
            "prior_binding_head_sha": prior_head,
            "prior_binding_tree_sha": prior_tree,
            "prior_correction_id": prior_record["correction_id"],
            "prior_invalidations": [
                "BLOB_CHANGED_CORRECTION_INVALID",
                "TOUCHED_CORRECTION_INVALID",
            ],
            "prior_record_path": prior_record_rel,
            "prior_record_payload_sha256": prior_payload_sha,
            "prior_record_sha256": prior_record_sha,
            "record_kind": subject.RECORD_KIND,
            "rebound_current_blob_sha256_by_path": {current_path: after_sha},
            "rebound_subject_projection_by_failure": {fingerprint: projection},
            "rebound_subject_projection_sha256_by_failure": {
                fingerprint: subject.sha256_bytes(subject.canonical_bytes(projection))
            },
            "revalidation_binding_head_sha": binding_head,
            "revalidation_binding_tree_sha": binding_tree,
            "revalidation_id": "V076-POST-TOUCH-SELFTEST-001",
            "revalidation_reason": "Focused complete valid record regression",
            "revocation_policy": subject.REVOCATION_POLICY,
            "schema_version": subject.RECORD_SCHEMA_VERSION,
            "touch_invalidation_policy": subject.TOUCH_INVALIDATION_POLICY,
            "touch_proof": {
                "after_blob_sha256": after_sha,
                "before_blob_sha256": before_sha,
                "commit_sha": touch_commit,
                "diff_sha256": diff_sha,
                "parent_sha": prior_head,
                "path": current_path,
            },
        }
        record["record_payload_sha256"] = subject.sha256_bytes(
            subject.canonical_bytes(subject.record_payload(record))
        )
        record_path = root / record_rel
        _write_json(record_path, record)

        manifest_rel = (subject.MANIFEST_ROOT / "manifest-valid.json").as_posix()
        manifest = {
            "authorization_base_head_sha": subject.AUTHORIZATION_BASE_HEAD,
            "authorization_id": subject.AUTHORIZATION_ID,
            "created_at": "2026-08-28T00:00:00Z",
            "creator": "V076_POST_TOUCH_SELFTEST",
            "current_batch_fingerprint_set_sha256": subject.line_set_sha([current_fingerprint]),
            "current_batch_manifest_path": current_batch_rel,
            "current_batch_manifest_sha256": subject.sha256_file(current_batch_path),
            "failure_fingerprint_set_sha256": subject.line_set_sha([fingerprint]),
            "failure_fingerprints": [fingerprint],
            "future_failure_auto_revalidation": False,
            "manifest_id": "V076_POST_TOUCH_SELFTEST_MANIFEST_001",
            "manifest_kind": subject.MANIFEST_KIND,
            "no_correction_batch_fingerprint_reuse": True,
            "previous_revalidation_manifest_path": "",
            "previous_revalidation_manifest_sha256": "",
            "prior_epoch_id": subject.FULL_CONVERGENCE_EPOCH_ID,
            "record_bindings": [
                {
                    "failure_fingerprints": [fingerprint],
                    "path": record_rel,
                    "previous_revalidation_chain_sha256": "",
                    "prior_correction_id": prior_record["correction_id"],
                    "prior_record_path": prior_record_rel,
                    "prior_record_payload_sha256": prior_payload_sha,
                    "prior_record_sha256": prior_record_sha,
                    "record_payload_sha256": record["record_payload_sha256"],
                    "record_sha256": subject.sha256_file(record_path),
                    "revalidation_id": record["revalidation_id"],
                }
            ],
            "record_chain_start_sha256": "",
            "record_chain_terminal_sha256": record["record_payload_sha256"],
            "record_count": 1,
            "revalidation_binding_head_sha": binding_head,
            "revalidation_binding_tree_sha": binding_tree,
            "schema_sha256": subject.AUTHORIZED_SCHEMA_SHA256,
            "schema_version": subject.MANIFEST_SCHEMA_VERSION,
        }
        manifest_path = root / manifest_rel
        _write_json(manifest_path, manifest)

        if malformed_field == "record_failure_fingerprints":
            record["failure_fingerprints"] = 7
            _write_json(record_path, record)
        elif malformed_field == "manifest_binding_failure_fingerprints":
            manifest["record_bindings"][0]["failure_fingerprints"] = True
            _write_json(manifest_path, manifest)
        elif malformed_field == "prior_failure_fingerprints":
            prior_record["failure_fingerprints"] = 7
            _write_json(prior_record_path, prior_record)
        elif malformed_field == "prior_invalidations":
            record["prior_invalidations"] = False
            _write_json(record_path, record)
        elif malformed_field == "orphan_prior_batch":
            orphan_batch_rel = (
                subject.FULL_BATCH_ROOT / "orphan" / "manifest.json"
            ).as_posix()
            orphan_batch_path = root / orphan_batch_rel
            _write_json(orphan_batch_path, prior_batch)
            record["correction_batch_manifest_path"] = orphan_batch_rel
            record["correction_batch_manifest_sha256"] = subject.sha256_file(
                orphan_batch_path
            )
            record["record_payload_sha256"] = subject.sha256_bytes(
                subject.canonical_bytes(subject.record_payload(record))
            )
            _write_json(record_path, record)
            manifest_binding = manifest["record_bindings"][0]
            manifest_binding["record_payload_sha256"] = record["record_payload_sha256"]
            manifest_binding["record_sha256"] = subject.sha256_file(record_path)
            manifest["record_chain_terminal_sha256"] = record["record_payload_sha256"]
            _write_json(manifest_path, manifest)

        artifact_relatives = {
            subject.SCHEMA_REL.as_posix(),
            manifest_rel,
            current_batch_rel,
            prior_batch_rel,
            prior_record_rel,
            record_rel,
        }
        if malformed_field == "orphan_prior_batch":
            artifact_relatives.add(orphan_batch_rel)
        elif malformed_field == "prior_record_uncommitted":
            artifact_relatives.discard(prior_record_rel)
        elif malformed_field == "prior_batch_uncommitted":
            artifact_relatives.discard(prior_batch_rel)
        tree_by_head = {
            prior_head: prior_tree,
            touch_commit: binding_tree,
            artifact_head: artifact_tree,
        }

        def fake_git(_root: Path, *args: str) -> str:
            if args[:1] == ("rev-parse",):
                expression = args[1]
                if expression == f"{touch_commit}^1":
                    return prior_head
                if expression.endswith("^{tree}"):
                    return tree_by_head[expression[:-7]]
            if args[:2] == ("diff", "--name-only"):
                return current_path if args[2:4] == (prior_head, binding_head) else ""
            if args[:2] == ("rev-list", "--reverse"):
                commit_range = args[2]
                path = args[4]
                if commit_range == f"{prior_head}..{binding_head}" and path == current_path:
                    return touch_commit
                return ""
            raise ValueError(f"unexpected modeled git call: {args!r}")

        def fake_git_bytes(_root: Path, commit: str, relative: str) -> bytes | None:
            normalized = subject.normalize_path(relative)
            if commit == artifact_head and normalized in artifact_relatives:
                return (root / normalized).read_bytes()
            if normalized == current_path:
                return before_bytes if commit == prior_head else after_bytes
            return None

        with (
            patch.object(subject, "_git", side_effect=fake_git),
            patch.object(subject, "_git_bytes", side_effect=fake_git_bytes),
            patch.object(subject, "_git_diff_sha", return_value=diff_sha),
            patch.object(subject, "_is_ancestor", return_value=True),
        ):
            kwargs: dict[str, object] = {}
            semantic_head = artifact_head
            if semantic_at_binding:
                semantic_head = binding_head
                kwargs["_artifact_head"] = artifact_head
            return subject.validate_manifest_and_records(
                root,
                manifest_path,
                evaluated_head=semantic_head,
                current_batch_manifest_path=current_batch_path,
                projection_loader=lambda *_: projection,
                **kwargs,
            )


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    checks: list[tuple[str, bool]] = []
    checks.append(("schema_contract", not subject.validate_schema_file(root)))
    checks.append(("strict_relative_path", subject._exact_path("a/b.json")))
    checks.append(("reject_parent_path", not subject._exact_path("a/../b.json")))
    checks.append(("reject_drive_path", not subject._exact_path("C:/escape.json")))
    checks.append(("reject_selector", not subject._exact_path("a/*.json")))
    with tempfile.TemporaryDirectory() as td:
        safe_root = Path(td)
        safe_file = safe_root / "a" / "b.json"
        safe_file.parent.mkdir(parents=True)
        safe_file.write_text("{}\n", encoding="utf-8")
        checks.append((
            "safe_repo_path_runtime",
            subject._safe_repo_path(safe_root, "a/b.json") == safe_file.resolve(),
        ))
        missing = safe_root / "missing.json"
        result = subject.validate_manifest_and_records(
            root,
            missing,
            evaluated_head="0" * 40,
            current_batch_manifest_path=None,
            projection_loader=lambda *_: None,
        )
        checks.append((
            "missing_sidecar_fail_closed",
            result["status"] == "FAIL" and not result["trusted_by_fingerprint"],
        ))

    complete = _exercise_complete_record(root)
    checks.append((
        "complete_valid_record_path",
        complete["status"] == "PASS" and len(complete["trusted_by_fingerprint"]) == 1,
    ))
    split_head = _exercise_complete_record(root, semantic_at_binding=True)
    checks.append(("artifact_head_after_semantic_binding", split_head["status"] == "PASS"))
    malformed_ok = True
    for malformed_field in (
        "record_failure_fingerprints",
        "manifest_binding_failure_fingerprints",
        "prior_failure_fingerprints",
        "prior_invalidations",
    ):
        malformed = _exercise_complete_record(root, malformed_field=malformed_field)
        malformed_ok = (
            malformed_ok
            and malformed["status"] == "FAIL"
            and not malformed["trusted_by_fingerprint"]
        )
    checks.append(("malformed_sequence_fields_fail_closed", malformed_ok))
    derived = Path("root/batch-004/batch-004-manifest.json")
    derivation_ok = True
    for current_number in (4, 3, 2):
        current_id = f"batch-{current_number:03d}"
        prior_id = f"batch-{current_number - 1:03d}"
        derived = subject._derive_prior_batch_path(derived, current_id, prior_id)
        derivation_ok = (
            derivation_ok
            and derived is not None
            and derived.parent.name == prior_id
            and derived.name == f"{prior_id}-manifest.json"
        )
    checks.append(("batch004_to_batch001_path_derivation", derivation_ok))
    orphan = _exercise_complete_record(root, malformed_field="orphan_prior_batch")
    checks.append((
        "orphan_prior_batch_rejected",
        orphan["status"] == "FAIL"
        and any(
            str(value).startswith("POST_TOUCH_PRIOR_BATCH_NOT_IN_EXPLICIT_CHAIN:")
            for value in orphan["failures"]
        ),
    ))
    prior_record_uncommitted = _exercise_complete_record(
        root,
        malformed_field="prior_record_uncommitted",
    )
    checks.append((
        "uncommitted_prior_record_rejected",
        any(
            str(value).startswith("POST_TOUCH_PRIOR_RECORD_COMMITTED_BYTES_MISSING:")
            for value in prior_record_uncommitted["failures"]
        ),
    ))
    prior_batch_uncommitted = _exercise_complete_record(
        root,
        malformed_field="prior_batch_uncommitted",
    )
    checks.append((
        "uncommitted_prior_batch_rejected",
        any(
            str(value).startswith("POST_TOUCH_PRIOR_BATCH_COMMITTED_BYTES_MISSING:")
            for value in prior_batch_uncommitted["failures"]
        ),
    ))
    trusted = {
        "V2F-" + "a" * 64: {
            "allowed_invalidations": ["BLOB_CHANGED_CORRECTION_INVALID"],
            "prior_record_path": "records/exact.json",
        }
    }
    checks.append((
        "suppression_requires_exact_prior_record_path",
        subject.allows_invalidation(
            trusted,
            fingerprint="V2F-" + "a" * 64,
            invalidation_code="BLOB_CHANGED_CORRECTION_INVALID",
            prior_record_path="records/exact.json",
        )
        and not subject.allows_invalidation(
            trusted,
            fingerprint="V2F-" + "a" * 64,
            invalidation_code="BLOB_CHANGED_CORRECTION_INVALID",
            prior_record_path="records/different.json",
        ),
    ))
    predecessor_fp = "V2F-" + "b" * 64
    successor_fp = "V2F-" + "c" * 64
    predecessor_result = {
        "trusted_by_fingerprint": {
            predecessor_fp: {
                "allowed_invalidations": ["TOUCHED_CORRECTION_INVALID"],
                "prior_record_path": "records/prior.json",
            }
        }
    }
    merged, disjoint_failures = subject._merge_disjoint_predecessor_trust(
        predecessor_result,
        [successor_fp],
    )
    _, overlap_failures = subject._merge_disjoint_predecessor_trust(
        predecessor_result,
        [predecessor_fp],
    )
    checks.append((
        "cumulative_disjoint_predecessor_contract",
        set(merged) == {predecessor_fp}
        and not disjoint_failures
        and overlap_failures == [
            f"POST_TOUCH_PREDECESSOR_FINGERPRINT_OVERLAP:{predecessor_fp}"
        ],
    ))
    long_relative = "docs/" + "nested/" * 24 + "committed-sidecar.json"
    with patch.object(subject.subprocess, "run") as run_git:
        run_git.return_value.returncode = 0
        run_git.return_value.stdout = b"committed sidecar bytes"
        committed_bytes = subject._git_bytes(root, "d" * 40, long_relative)
        command = run_git.call_args.args[0]
    checks.append((
        "committed_bytes_use_blob_plumbing_for_long_paths",
        committed_bytes == b"committed sidecar bytes"
        and command == [
            "git",
            "-C",
            str(root),
            "cat-file",
            "blob",
            f"{'d' * 40}:{long_relative}",
        ],
    ))

    passed = sum(ok for _, ok in checks)
    for name, ok in checks:
        print(f"{name}: {'PASS' if ok else 'FAIL'}")
    print(f"V076_POST_TOUCH_REVALIDATION_SELFTEST={passed}/{len(checks)}")
    return 0 if passed == len(checks) else 1


if __name__ == "__main__":
    raise SystemExit(main())
