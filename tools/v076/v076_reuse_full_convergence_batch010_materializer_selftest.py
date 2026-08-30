#!/usr/bin/env python3
"""Fail-closed self-test for the Batch-010 frozen successor materializer."""

from __future__ import annotations

import json
from pathlib import Path

import v076_reuse_full_convergence_batch010_materializer as materializer


def expect(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def test_frozen_schema(root: Path) -> None:
    result = materializer.validate_frozen_membership(root)
    candidate = result["candidate"]
    seal = result["seal"]
    expect(candidate["batch_id"] == "batch-010", "batch id drift")
    expect(candidate["failure_count"] == 50, "failure count drift")
    expect(candidate["failure_fingerprint_set_sha256"] == materializer.SEALED_MEMBERSHIP_SET_SHA256, "set hash drift")
    expect(candidate["candidate_payload_sha256"] == materializer.SEALED_MEMBERSHIP_CANDIDATE_PAYLOAD_SHA256, "candidate hash drift")
    expect(seal["seal_payload_sha256"] == materializer.SEALED_MEMBERSHIP_SEAL_PAYLOAD_SHA256, "seal hash drift")
    expect(result["stage"] is None, "frozen membership unexpectedly has writable stage")


def test_exact_paths_and_documentation_identity(root: Path) -> None:
    paths = [row[1] for row in materializer.FROZEN_MEMBERSHIP_SPECS]
    expect(len(paths) == len(set(paths)) == 50, "path set drift")
    mechanic = materializer.source_identity(root, "0d2a2b798f328624cc9aaee65be4187609b142a2", "docs/rules/v06_mechanic_status_registry.json")
    rulebook = materializer.source_identity(root, "62ceba063d685871ee3869707862598da00ba649", "docs/tabletop_rulebook_v06.md")
    expect(mechanic["identity_kind"] == "DOCUMENTATION", "mechanic registry documentation identity drift")
    expect(rulebook["identity_kind"] == "DOCUMENTATION", "rulebook documentation identity drift")


def test_current_head_reports_real_registry_blocker_without_writes(root: Path) -> None:
    before = (root / materializer.REGISTRY_REL).read_bytes()
    try:
        materializer.preflight(root)
    except materializer.MaterializerError as exc:
        rendered = str(exc)
        expect(rendered.startswith("MISSING_EXACT_REGISTRY_ROWS:50:"), "preflight did not fail on exact current Registry rows")
        paths = rendered.split(":", 2)[2].split("|")
        expect(len(paths) == 50 and paths == sorted(paths), "missing path set is not exact")
    else:
        raise AssertionError("preflight unexpectedly passed before Registry projection")
    expect((root / materializer.REGISTRY_REL).read_bytes() == before, "preflight mutated Registry")


def test_current_subject_and_batch009_are_not_accepted() -> None:
    expect(materializer.BATCH_ID != "batch-009", "Batch-009 was accidentally parameterized")
    expect("batch-009" not in {relative.split("/", 1)[0] for relative in materializer.BASE_OUTPUT_ALLOWLIST}, "Batch-009 output leaked")
    expect(materializer.OUTPUT_ALLOWLIST == {
        "batch-010/batch-010-manifest.json",
        "batch-010/batch_inventory.json",
        "batch-010/batch_classification.json",
        "batch-010/batch_correction_records.json",
        "batch-010/batch_negative_checks.json",
        "batch-010/batch_review_A.json",
        "batch-010/batch_review_B.json",
        "records/batch-010/transition_46b33bba77b3_e584cd4d8b0c_test-only.json",
        "records/batch-010/transition_46b33bba77b3_e584cd4d8b0c_production-reachable.json",
        "records/batch-010/batch010_documentation-only.json",
    }, "output allowlist drift")


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    test_frozen_schema(root)
    test_exact_paths_and_documentation_identity(root)
    test_current_head_reports_real_registry_blocker_without_writes(root)
    test_current_subject_and_batch009_are_not_accepted()
    print("V076_BATCH010_MATERIALIZER_SELFTEST_PASS cases=4 current_head_gate=MISSING_EXACT_REGISTRY_ROWS:50 official_registry_write_count=0 official_record_write_count=0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
