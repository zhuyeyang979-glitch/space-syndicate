#!/usr/bin/env python3
"""Stage, committed, and fail-closed checks for SPR successor-v5."""
from __future__ import annotations

import json
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Any

try:
    from . import v076_subject_projection_revalidation_successor_v5 as primary
    from . import v076_subject_projection_revalidation_successor_v5_independent_audit as independent
except ImportError:  # pragma: no cover - direct script execution
    import v076_subject_projection_revalidation_successor_v5 as primary
    import v076_subject_projection_revalidation_successor_v5_independent_audit as independent


BINDING_HEAD = "7e87c564fc2c092a0fb00519c15711d19f99305f"
BINDING_TREE = "ab8d71ef783710b348eb299dc7c9d5ba58172a1b"
UNCHANGED_BASE = "3a4c8b0d32dd3821b15a98c30bab7107b5f693ab"
UNCHANGED_PATHS = (
    "docs/architecture/reuse_corrections/v2/schema_subject_projection_revalidation_20260828.json",
    "docs/architecture/reuse_corrections/v2/schema_subject_projection_revalidation_successor_v2_20260829.json",
    "docs/architecture/reuse_corrections/v2/schema_subject_projection_revalidation_successor_v3_20260830.json",
    "docs/architecture/reuse_corrections/v2/schema_subject_projection_revalidation_successor_v4_20260830.json",
    "docs/architecture/reuse_corrections/v2/subject_projection_revalidation",
    "docs/architecture/reuse_corrections/v2/subject_projection_revalidation_successor_v2",
    "docs/architecture/reuse_corrections/v2/subject_projection_revalidation_successor_v3",
    "docs/architecture/reuse_corrections/v2/subject_projection_revalidation_successor_v4",
    "docs/architecture/reuse_corrections/v2/records",
    "docs/architecture/reuse_corrections/v2/post_touch_revalidation",
    "docs/architecture/reuse_corrections/v2/post_touch_revalidation_successor_v2",
)


class Checks:
    def __init__(self) -> None:
        self.total = 0

    def true(self, value: bool, message: str) -> None:
        self.total += 1
        if not value:
            raise AssertionError(message)


def document(path: Path) -> dict[str, Any]:
    value = primary.strict(path.read_bytes())
    if not isinstance(value, dict):
        raise AssertionError(f"document is not an object: {path}")
    return value


def bindings_by_fingerprint(bindings: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    for binding in bindings:
        fingerprints = binding.get("failure_fingerprints", [])
        if not isinstance(fingerprints, list) or len(fingerprints) != 1:
            raise AssertionError("binding is not exact-one")
        fingerprint = str(fingerprints[0])
        if fingerprint in result:
            raise AssertionError("binding fingerprint collision")
        result[fingerprint] = binding
    return result


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    stage = root / primary.SUCCESSOR_ROOT
    artifact_head = str(primary._git(root, "rev-parse", "HEAD^{commit}"))
    artifact_tree = str(primary._git(root, "rev-parse", f"{artifact_head}^{{tree}}"))
    manifest = document(stage / "manifest.json")
    predecessor = document(root / primary.PREDECESSOR_MANIFEST_PATH)
    checks = Checks()

    checks.true(
        artifact_head != BINDING_HEAD
        and manifest["revalidation_binding_head_sha"] == BINDING_HEAD
        and manifest["revalidation_binding_tree_sha"] == BINDING_TREE
        and primary._git(root, "rev-parse", f"{BINDING_HEAD}^{{tree}}") == BINDING_TREE,
        "artifact and evaluated binding identities were not separated",
    )

    fingerprints = list(manifest["failure_fingerprints"])
    predecessor_fingerprints = list(predecessor["failure_fingerprints"])
    checks.true(
        len(fingerprints) == manifest["record_count"] == 2
        and fingerprints == predecessor_fingerprints
        and manifest["failure_fingerprint_set_sha256"]
        == predecessor["failure_fingerprint_set_sha256"],
        "v5 does not exactly replace the two-record v2 fingerprint set",
    )

    predecessor_bindings = bindings_by_fingerprint(list(predecessor["record_bindings"]))
    successor_bindings = bindings_by_fingerprint(list(manifest["record_bindings"]))
    record_files = sorted((stage / "records").glob("*.json"))
    semantics_valid = len(record_files) == len(successor_bindings) == 2
    for fingerprint in fingerprints:
        binding = successor_bindings.get(fingerprint, {})
        old_binding = predecessor_bindings.get(fingerprint, {})
        expected_path = primary.expected_record_path(fingerprint)
        record_path = root / expected_path
        if not record_path.is_file():
            semantics_valid = False
            continue
        record = document(record_path)
        semantics_valid = semantics_valid and all(
            (
                binding.get("path") == expected_path,
                record.get("changed_projection_sections") == ["registry_rows"],
                record.get("changed_projection_component_ids")
                == ["component.current.v075_runtime_owner"],
                record.get("predecessor_revalidation_id")
                == old_binding.get("revalidation_id"),
                record.get("predecessor_revalidation_record_path")
                == old_binding.get("path"),
                record.get("predecessor_revalidation_record_sha256")
                == old_binding.get("record_sha256"),
                record.get("predecessor_revalidation_record_payload_sha256")
                == old_binding.get("record_payload_sha256"),
                record.get("prior_record_path") == old_binding.get("prior_record_path"),
                record.get("prior_record_sha256") == old_binding.get("prior_record_sha256"),
                record.get("prior_record_payload_sha256")
                == old_binding.get("prior_record_payload_sha256"),
            )
        )
    checks.true(semantics_valid, "record lineage or exact replacement semantics drifted")

    primary_stage = primary.validate(
        root,
        stage / "manifest.json",
        evaluated_head=BINDING_HEAD,
        stage_dir=stage,
    )
    checks.true(
        primary_stage.get("status") == "PASS"
        and primary_stage.get("mode") == "STAGE_REVIEW"
        and primary_stage.get("failures") == []
        and primary_stage.get("trusted_by_fingerprint") == {}
        and len(primary_stage.get("review_trusted_by_fingerprint", {})) == 2,
        "primary stage review did not attest exact two-row review trust",
    )

    independent_stage = independent.audit(
        root,
        stage / "manifest.json",
        evaluated_head=BINDING_HEAD,
        stage_dir=stage,
    )
    checks.true(
        independent_stage.get("status") == "PASS"
        and independent_stage.get("mode") == "STAGE_REVIEW"
        and independent_stage.get("independent") is True
        and independent_stage.get("failures") == []
        and independent_stage.get("trusted_by_fingerprint") == {}
        and len(independent_stage.get("review_trusted_by_fingerprint", {})) == 2,
        "independent stage review did not attest exact two-row review trust",
    )

    with tempfile.TemporaryDirectory(prefix="v076-spr5-stage-") as temporary:
        bad_stage = Path(temporary)
        (bad_stage / "records").mkdir()
        shutil.copy2(stage / "manifest.json", bad_stage / "manifest.json")
        for record_file in record_files:
            shutil.copy2(record_file, bad_stage / "records" / record_file.name)
        bad_record_path = bad_stage / "records" / record_files[0].name
        bad_record = document(bad_record_path)
        bad_record["wildcard_count"] = 1
        bad_record_path.write_bytes(primary.canonical_bytes(bad_record))
        primary_bad_stage = primary.validate(
            root,
            bad_stage / "manifest.json",
            evaluated_head=BINDING_HEAD,
            stage_dir=bad_stage,
        )
        independent_bad_stage = independent.audit(
            root,
            bad_stage / "manifest.json",
            evaluated_head=BINDING_HEAD,
            stage_dir=bad_stage,
        )
    checks.true(
        primary_bad_stage.get("status") == "FAIL"
        and primary_bad_stage.get("review_trusted_by_fingerprint") == {}
        and primary_bad_stage.get("trusted_by_fingerprint") == {}
        and independent_bad_stage.get("status") == "FAIL"
        and independent_bad_stage.get("review_trusted_by_fingerprint") == {}
        and independent_bad_stage.get("trusted_by_fingerprint") == {},
        "mutated stage evidence did not fail closed in both audits",
    )

    primary_committed = primary.validate(
        root,
        stage / "manifest.json",
        evaluated_head=BINDING_HEAD,
        artifact_head=artifact_head,
    )
    checks.true(
        primary_committed.get("status") == "PASS"
        and primary_committed.get("mode") == "COMMITTED"
        and primary_committed.get("failures") == []
        and primary_committed.get("artifact_head_sha") == artifact_head
        and primary_committed.get("evaluated_head_sha") == BINDING_HEAD
        and len(primary_committed.get("trusted_by_fingerprint", {})) == 2
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
        and len(independent_committed.get("trusted_by_fingerprint", {})) == 2
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
        and primary_wrong_binding.get("failures") == ["SPR5_BINDING_INVALID"]
        and primary_wrong_binding.get("trusted_by_fingerprint") == {}
        and primary_wrong_path.get("status") == "FAIL"
        and primary_wrong_path.get("failures") == ["SPR5_MANIFEST_PATH_INVALID"]
        and primary_wrong_path.get("trusted_by_fingerprint") == {},
        "primary committed audit accepted a wrong artifact, binding, or path",
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
        and independent_wrong_binding.get("failures") == ["SPR5I_BINDING_INVALID"]
        and independent_wrong_binding.get("trusted_by_fingerprint") == {}
        and independent_wrong_path.get("status") == "FAIL"
        and independent_wrong_path.get("failures") == ["SPR5I_MANIFEST_PATH_INVALID"]
        and independent_wrong_path.get("trusted_by_fingerprint") == {},
        "independent committed audit accepted a wrong artifact, binding, or path",
    )

    policy_valid = (
        manifest.get("wildcard_count") == 0
        and manifest.get("future_failure_auto_revalidation") is False
    )
    for record_file in record_files:
        record = document(record_file)
        policy_valid = policy_valid and (
            record.get("wildcard_count") == 0
            and record.get("future_failure_policy") == primary.FUTURE_POLICY
            and record.get("failure_fingerprints") in ([fingerprints[0]], [fingerprints[1]])
        )
    checks.true(policy_valid, "wildcard or future auto-trust policy drifted")

    unchanged = subprocess.run(
        [
            "git",
            "--no-replace-objects",
            "-C",
            str(root),
            "diff",
            "--quiet",
            UNCHANGED_BASE,
            "--",
            *UNCHANGED_PATHS,
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    checks.true(unchanged.returncode == 0, "frozen v1/v2/v3/v4/correction paths changed")

    print(f"SPR_V5_SELF_TEST {checks.total}/{checks.total} PASS")
    print("BINDING_HEAD=" + BINDING_HEAD)
    print("BINDING_TREE=" + BINDING_TREE)
    print("ARTIFACT_HEAD=" + artifact_head)
    print("ARTIFACT_TREE=" + artifact_tree)
    print("COMMITTED_PRIMARY_AND_INDEPENDENT=PASS")
    print("EXACT_V2_REPLACEMENT_COUNT=2")
    print("WILDCARD_COUNT=0")
    print("FUTURE_FAILURE_AUTO_REVALIDATION_COUNT=0")
    print("OLD_V2_RECORDS_SCHEMA_MANIFEST_DIFF=ZERO")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
