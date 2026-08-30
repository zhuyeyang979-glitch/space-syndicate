#!/usr/bin/env python3
"""Focused stage and committed integrity checks for SPR v1 successor-v4."""

from __future__ import annotations

import subprocess
from pathlib import Path
from typing import Any

try:
    from . import v076_subject_projection_revalidation_successor_v4 as primary
    from . import v076_subject_projection_revalidation_successor_v4_independent_audit as independent
except ImportError:  # pragma: no cover - direct script execution
    import v076_subject_projection_revalidation_successor_v4 as primary
    import v076_subject_projection_revalidation_successor_v4_independent_audit as independent


BINDING_HEAD = "7e87c564fc2c092a0fb00519c15711d19f99305f"
BINDING_TREE = "ab8d71ef783710b348eb299dc7c9d5ba58172a1b"
UNCHANGED_BASE = "38e3776accee3cbe64e5abbf3d776561114d8d01"
UNCHANGED_PATHS = (
    "docs/architecture/reuse_corrections/v2/subject_projection_revalidation",
    "docs/architecture/reuse_corrections/v2/subject_projection_revalidation_successor_v2",
    "docs/architecture/reuse_corrections/v2/subject_projection_revalidation_successor_v3",
    "docs/architecture/reuse_corrections/v2/records",
    "docs/architecture/reuse_corrections/v2/post_touch_revalidation",
)


class Checks:
    def __init__(self) -> None:
        self.total = 0

    def true(self, value: bool, message: str) -> None:
        self.total += 1
        if not value:
            raise AssertionError(message)


def _document(path: Path) -> dict[str, Any]:
    value = primary.strict(path.read_bytes())
    if not isinstance(value, dict):
        raise AssertionError(f"document is not an object: {path}")
    return value


def _by_fingerprint(bindings: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    for binding in bindings:
        fingerprints = binding.get("failure_fingerprints", [])
        if not isinstance(fingerprints, list) or len(fingerprints) != 1:
            raise AssertionError("binding is not exact-one")
        result[str(fingerprints[0])] = binding
    return result


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    stage = root / primary.SUCCESSOR_ROOT
    artifact_head = str(primary._git(root, "rev-parse", "HEAD^{commit}"))
    manifest = _document(stage / "manifest.json")
    predecessor = _document(root / primary.PREDECESSOR_MANIFEST_PATH)
    checks = Checks()

    checks.true(
        manifest["revalidation_binding_head_sha"] == BINDING_HEAD
        and manifest["revalidation_binding_tree_sha"] == BINDING_TREE
        and primary._git(root, "rev-parse", f"{BINDING_HEAD}^{{tree}}") == BINDING_TREE,
        "binding Head/Tree drifted",
    )

    drift = list(manifest["failure_fingerprints"])
    preserved = list(manifest["preserved_failure_fingerprints"])
    predecessor_fingerprints = list(predecessor["failure_fingerprints"])
    checks.true(len(drift) == manifest["record_count"] == 48, "drift partition is not 48")
    checks.true(len(preserved) == manifest["preserved_record_count"] == 34, "preserved partition is not 34")
    checks.true(set(drift).isdisjoint(preserved), "drift and preserved partitions overlap")
    checks.true(
        len(predecessor_fingerprints) == 82
        and len(set(drift) | set(preserved)) == 82
        and set(drift) | set(preserved) == set(predecessor_fingerprints),
        "successor partition does not exactly cover the v1 fingerprint set",
    )

    predecessor_bindings = _by_fingerprint(list(predecessor["record_bindings"]))
    successor_bindings = _by_fingerprint(list(manifest["record_bindings"]))
    record_files = sorted((stage / "records").glob("*.json"))
    record_semantics_valid = len(record_files) == len(successor_bindings) == 48
    for fingerprint in drift:
        binding = successor_bindings.get(fingerprint, {})
        predecessor_binding = predecessor_bindings.get(fingerprint, {})
        expected_path = primary.expected_record_path(fingerprint)
        record_path = root / expected_path
        if not record_path.is_file():
            record_semantics_valid = False
            continue
        record = _document(record_path)
        record_semantics_valid = record_semantics_valid and all(
            (
                binding.get("path") == expected_path,
                record.get("changed_projection_sections") == ["registry_rows"],
                record.get("changed_projection_component_ids") == ["component.current.v075_runtime_owner"],
                record.get("predecessor_revalidation_id") == predecessor_binding.get("revalidation_id"),
                record.get("predecessor_revalidation_record_path") == predecessor_binding.get("path"),
                record.get("predecessor_revalidation_record_sha256") == predecessor_binding.get("record_sha256"),
                record.get("predecessor_revalidation_record_payload_sha256") == predecessor_binding.get("record_payload_sha256"),
                record.get("prior_record_path") == predecessor_binding.get("prior_record_path"),
                record.get("prior_record_sha256") == predecessor_binding.get("prior_record_sha256"),
                record.get("prior_record_payload_sha256") == predecessor_binding.get("prior_record_payload_sha256"),
            )
        )
    checks.true(record_semantics_valid, "canonical record or predecessor/correction semantics drifted")

    primary_result = primary.validate(
        root,
        stage / "manifest.json",
        evaluated_head=BINDING_HEAD,
        stage_dir=stage,
    )
    primary_trust = primary_result.get("review_trusted_by_fingerprint", {})
    preserved_rows_valid = all(
        primary_trust.get(fingerprint, {}).get("revalidation_id")
        == predecessor_bindings[fingerprint].get("revalidation_id")
        and primary_trust.get(fingerprint, {}).get("prior_record_path")
        == predecessor_bindings[fingerprint].get("prior_record_path")
        and primary_trust.get(fingerprint, {}).get("record_path") == ""
        for fingerprint in preserved
    )
    checks.true(
        primary_result.get("status") == "PASS"
        and primary_result.get("mode") == "STAGE_REVIEW"
        and primary_result.get("failures") == []
        and len(primary_trust) == 82
        and preserved_rows_valid,
        "primary stage review did not attest exact 82-row trust",
    )

    independent_result = independent.audit(
        root,
        stage / "manifest.json",
        evaluated_head=BINDING_HEAD,
        stage_dir=stage,
    )
    checks.true(
        independent_result.get("status") == "PASS"
        and independent_result.get("mode") == "STAGE_REVIEW"
        and independent_result.get("independent") is True
        and independent_result.get("failures") == []
        and len(independent_result.get("review_trusted_by_fingerprint", {})) == 82,
        "independent stage review did not attest exact 82-row trust",
    )

    primary_committed = primary.validate(
        root,
        stage / "manifest.json",
        evaluated_head=BINDING_HEAD,
        artifact_head=artifact_head,
    )
    primary_committed_trust = primary_committed.get("trusted_by_fingerprint", {})
    checks.true(
        primary_committed.get("status") == "PASS"
        and primary_committed.get("mode") == "COMMITTED"
        and primary_committed.get("failures") == []
        and primary_committed.get("artifact_head_sha") == artifact_head
        and primary_committed.get("evaluated_head_sha") == BINDING_HEAD
        and len(primary_committed_trust) == 82
        and primary_committed.get("review_trusted_by_fingerprint") == {},
        "primary committed audit did not separate artifact and binding refs",
    )

    independent_committed = independent.audit(
        root,
        stage / "manifest.json",
        evaluated_head=BINDING_HEAD,
        artifact_head=artifact_head,
    )
    checks.true(
        independent_committed.get("status") == "PASS"
        and independent_committed.get("mode") == "COMMITTED"
        and independent_committed.get("independent") is True
        and independent_committed.get("failures") == []
        and independent_committed.get("artifact_head_sha") == artifact_head
        and independent_committed.get("evaluated_head_sha") == BINDING_HEAD
        and len(independent_committed.get("trusted_by_fingerprint", {})) == 82
        and independent_committed.get("review_trusted_by_fingerprint") == {},
        "independent committed audit did not separate artifact and binding refs",
    )

    primary_wrong_artifact = primary.validate(
        root,
        stage / "manifest.json",
        evaluated_head=BINDING_HEAD,
        artifact_head=BINDING_HEAD,
    )
    primary_wrong_binding = primary.validate(
        root,
        stage / "manifest.json",
        evaluated_head=artifact_head,
        artifact_head=artifact_head,
    )
    primary_wrong_path = primary.validate(
        root,
        root / primary.SCHEMA_PATH,
        evaluated_head=BINDING_HEAD,
        artifact_head=artifact_head,
    )
    checks.true(
        primary_wrong_artifact.get("status") == "FAIL"
        and primary_wrong_artifact.get("trusted_by_fingerprint") == {}
        and primary_wrong_binding.get("status") == "FAIL"
        and primary_wrong_binding.get("failures") == ["SPR4_BINDING_INVALID"]
        and primary_wrong_binding.get("trusted_by_fingerprint") == {}
        and primary_wrong_path.get("status") == "FAIL"
        and primary_wrong_path.get("failures") == ["SPR4_MANIFEST_PATH_INVALID"]
        and primary_wrong_path.get("trusted_by_fingerprint") == {},
        "primary committed audit accepted a wrong artifact, binding, or manifest path",
    )

    independent_wrong_artifact = independent.audit(
        root,
        stage / "manifest.json",
        evaluated_head=BINDING_HEAD,
        artifact_head=BINDING_HEAD,
    )
    independent_wrong_binding = independent.audit(
        root,
        stage / "manifest.json",
        evaluated_head=artifact_head,
        artifact_head=artifact_head,
    )
    independent_wrong_path = independent.audit(
        root,
        root / primary.SCHEMA_PATH,
        evaluated_head=BINDING_HEAD,
        artifact_head=artifact_head,
    )
    checks.true(
        independent_wrong_artifact.get("status") == "FAIL"
        and independent_wrong_artifact.get("trusted_by_fingerprint") == {}
        and independent_wrong_binding.get("status") == "FAIL"
        and independent_wrong_binding.get("failures") == ["SPR4I_BINDING_INVALID"]
        and independent_wrong_binding.get("trusted_by_fingerprint") == {}
        and independent_wrong_path.get("status") == "FAIL"
        and independent_wrong_path.get("failures") == ["SPR4I_MANIFEST_PATH_INVALID"]
        and independent_wrong_path.get("trusted_by_fingerprint") == {},
        "independent committed audit accepted a wrong artifact, binding, or manifest path",
    )

    fail_closed_policy_valid = (
        manifest.get("wildcard_count") == 0
        and manifest.get("future_failure_auto_revalidation") is False
    )
    for record_path in record_files:
        record = _document(record_path)
        fail_closed_policy_valid = fail_closed_policy_valid and (
            record.get("wildcard_count") == 0
            and record.get("future_failure_policy") == primary.FUTURE_POLICY
        )
    checks.true(fail_closed_policy_valid, "wildcard or future auto-revalidation policy drifted")

    unchanged = subprocess.run(
        ["git", "--no-replace-objects", "-C", str(root), "diff", "--quiet", UNCHANGED_BASE, "--", *UNCHANGED_PATHS],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    checks.true(unchanged.returncode == 0, "frozen v1/v2/v3/correction paths changed")

    print(f"SPR_V4_SELF_TEST {checks.total}/{checks.total} PASS")
    print("BINDING_HEAD=" + BINDING_HEAD)
    print("BINDING_TREE=" + BINDING_TREE)
    print("ARTIFACT_HEAD=" + artifact_head)
    print("COMMITTED_PRIMARY_AND_INDEPENDENT=PASS")
    print("PARTITION=48_DRIFT+34_PRESERVED=82_DISJOINT")
    print("OLD_V1_V2_V3_CORRECTION_DIFF=ZERO")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
