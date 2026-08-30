#!/usr/bin/env python3
"""Repair the Batch-010 current-component classification projection exactly once.

Batch-010 correctly classified historical failures, but its current Registry
projection copied the historical batch label into ``change_class``.  This
successor is intentionally narrow: it accepts one exact Registry input, changes
only the 50 affected current rows, and writes a new append-only receipt.  It
never edits the older Batch-010 evidence or any product file.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import subprocess
from pathlib import Path
from typing import Any


REGISTRY_REL = Path("docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json")
DEFAULT_RECEIPT_REL = Path(
    "reports/reuse/full_convergence/"
    "batch010_current_registry_classification_successor_20260831.json"
)
SOURCE_REGISTRY_SHA256 = (
    "230c1f8a46f90d33eb97bb2b7f0e259a86afd86d2d3300d07cc44036da93f235"
)
SOURCE_HEAD_SHA = "46d76b57a5ad848da6487e69993afc9bdae6fd95"
SOURCE_TREE_SHA = "91f156cc268739dc391b6ae1637c774cae12419d"
DEFECT_INTRODUCTION_HEAD_SHA = "e645c74ac1b9bff25e3898f881f3f944be73525d"
DEFECT_INTRODUCTION_PARENT_SHA = "ae67a00402055af300852ae700a55422dd6015b9"
INVALID_REGISTRY_BLOB_OID = "e5d4e6cb38c97e8941cb9a3320afe90a089f95ea"
INVALID_REGISTRY_CONTIGUOUS_COMMIT_COUNT = 21
INVALID_REGISTRY_TRANSITION_COUNT = 23
INVALID_CHANGE_CLASS = "HISTORICAL_IDENTITY_BACKFILL"
TEST_CHANGE_CLASS = "TEST_ORACLE_ONLY"
PRODUCT_CHANGE_CLASS = "DOMAIN_CORE"
DOCS_CHANGE_CLASS = "DOCS_ONLY"
DOCS_ROLE = "TOOLING"
PRODUCT_COMPONENT_ID = "component.current.product_industry_catalog_v05"
DOCS_COMPONENT_IDS = {
    "component.current.tabletop_rulebook_v06",
    "component.current.v06_mechanic_status_registry",
}
SCHEMA_VERSION = (
    "space_syndicate.v076.reuse_full_convergence."
    "batch010_current_registry_classification_successor.v1"
)
REPAIR_ID = "V076_BATCH010_CURRENT_REGISTRY_CLASSIFICATION_SUCCESSOR_20260831"


class RepairError(ValueError):
    pass


def canonical(value: Any) -> bytes:
    return json.dumps(
        value, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")


def sha256(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def git(root: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", *args],
        cwd=root,
        text=True,
        encoding="utf-8",
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode:
        raise RepairError(f"GIT_FAILED:{' '.join(args)}:{result.stderr.strip()}")
    return result.stdout.strip()


def load_canonical_object(path: Path, label: str) -> tuple[dict[str, Any], bytes]:
    try:
        raw = path.read_bytes()
        value = json.loads(raw.decode("utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise RepairError(f"{label}_READ_INVALID:{path}") from exc
    if not isinstance(value, dict) or raw != canonical(value) + b"\n":
        raise RepairError(f"{label}_NOT_CANONICAL:{path}")
    return value, raw


def _assert_source(root: Path, registry_bytes: bytes) -> None:
    if git(root, "rev-parse", "HEAD^{commit}") != SOURCE_HEAD_SHA:
        raise RepairError("SOURCE_HEAD_MISMATCH")
    if git(root, "rev-parse", "HEAD^{tree}") != SOURCE_TREE_SHA:
        raise RepairError("SOURCE_TREE_MISMATCH")
    if sha256(registry_bytes) != SOURCE_REGISTRY_SHA256:
        raise RepairError("SOURCE_REGISTRY_SHA256_MISMATCH")


def build_target(registry: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
    inventory = registry.get("component_inventory")
    if not isinstance(inventory, list) or any(not isinstance(row, dict) for row in inventory):
        raise RepairError("COMPONENT_INVENTORY_INVALID")
    affected = [row for row in inventory if row.get("change_class") == INVALID_CHANGE_CLASS]
    if len(affected) != 50:
        raise RepairError(f"AFFECTED_COMPONENT_COUNT_INVALID:{len(affected)}")
    affected_ids = [str(row.get("component_id", "")) for row in affected]
    if len(set(affected_ids)) != 50 or any(not value for value in affected_ids):
        raise RepairError("AFFECTED_COMPONENT_ID_SET_INVALID")

    product = [row for row in affected if row.get("component_id") == PRODUCT_COMPONENT_ID]
    docs = [row for row in affected if row.get("component_id") in DOCS_COMPONENT_IDS]
    tests = [
        row
        for row in affected
        if row.get("component_id") not in DOCS_COMPONENT_IDS | {PRODUCT_COMPONENT_ID}
    ]
    if len(product) != 1 or len(docs) != 2 or len(tests) != 47:
        raise RepairError("AFFECTED_CLASSIFICATION_PARTITION_INVALID")
    if set(row.get("component_id") for row in docs) != DOCS_COMPONENT_IDS:
        raise RepairError("DOCS_COMPONENT_SET_INVALID")
    if any(
        row.get("component_role") != "TEST_SUPPORT"
        or row.get("production_reachable") is not False
        or row.get("reuse_disposition") != "REUSE_AS_TEST"
        for row in tests
    ):
        raise RepairError("TEST_COMPONENT_CONTRACT_INVALID")
    if (
        product[0].get("component_role") != "PORT"
        or product[0].get("production_reachable") is not True
        or product[0].get("reuse_disposition") != "ADAPT_AS_CONSUMER"
    ):
        raise RepairError("PRODUCT_COMPONENT_CONTRACT_INVALID")
    if any(
        row.get("component_role") != "DOCUMENTATION_ONLY"
        or row.get("production_reachable") is not False
        or row.get("reuse_disposition") != "REFERENCE_ONLY"
        for row in docs
    ):
        raise RepairError("DOCS_COMPONENT_CONTRACT_INVALID")

    target = copy.deepcopy(registry)
    target_inventory = target["component_inventory"]
    target_by_id = {row["component_id"]: row for row in target_inventory}
    for component_id in affected_ids:
        row = target_by_id[component_id]
        if component_id == PRODUCT_COMPONENT_ID:
            row["change_class"] = PRODUCT_CHANGE_CLASS
        elif component_id in DOCS_COMPONENT_IDS:
            row["change_class"] = DOCS_CHANGE_CLASS
            row["component_role"] = DOCS_ROLE
        else:
            row["change_class"] = TEST_CHANGE_CLASS

    allowed_field_changes = {
        component_id: ({"change_class", "component_role"} if component_id in DOCS_COMPONENT_IDS else {"change_class"})
        for component_id in affected_ids
    }
    before_by_id = {row["component_id"]: row for row in inventory}
    for component_id, before in before_by_id.items():
        after = target_by_id.get(component_id)
        if after is None:
            raise RepairError(f"COMPONENT_REMOVED:{component_id}")
        changed_fields = {key for key in set(before) | set(after) if before.get(key) != after.get(key)}
        if changed_fields != allowed_field_changes.get(component_id, set()):
            raise RepairError(
                f"NON_ALLOWLISTED_FIELD_CHANGE:{component_id}:{','.join(sorted(changed_fields))}"
            )
    if len(target_inventory) != len(inventory):
        raise RepairError("COMPONENT_INVENTORY_CARDINALITY_CHANGED")
    if [row["component_id"] for row in target_inventory] != [row["component_id"] for row in inventory]:
        raise RepairError("COMPONENT_INVENTORY_ORDER_CHANGED")

    summary = {
        "affected_component_count": 50,
        "affected_component_ids": sorted(affected_ids),
        "classification_counts": {
            DOCS_CHANGE_CLASS: 2,
            PRODUCT_CHANGE_CLASS: 1,
            TEST_CHANGE_CLASS: 47,
        },
        "component_role_change_count": 2,
        "component_role_changes": {
            component_id: {"before": "DOCUMENTATION_ONLY", "after": DOCS_ROLE}
            for component_id in sorted(DOCS_COMPONENT_IDS)
        },
        "component_inventory_append_count": 0,
        "component_inventory_remove_count": 0,
        "component_inventory_reorder_count": 0,
        "non_allowlisted_field_change_count": 0,
    }
    allowed_transitions = []
    for component_id in sorted(affected_ids):
        if component_id == PRODUCT_COMPONENT_ID:
            target_change_class = PRODUCT_CHANGE_CLASS
        elif component_id in DOCS_COMPONENT_IDS:
            target_change_class = DOCS_CHANGE_CLASS
        else:
            target_change_class = TEST_CHANGE_CLASS
        allowed_transitions.append(
            {
                "after": target_change_class,
                "before": INVALID_CHANGE_CLASS,
                "component_id": component_id,
                "field": "change_class",
            }
        )
    allowed_transitions.extend(
        {
            "after": DOCS_ROLE,
            "before": "DOCUMENTATION_ONLY",
            "component_id": component_id,
            "field": "component_role",
        }
        for component_id in sorted(DOCS_COMPONENT_IDS)
    )
    summary["allowed_field_transition_count"] = len(allowed_transitions)
    summary["allowed_field_transition_set_sha256"] = sha256(
        canonical(allowed_transitions)
    )
    return target, summary


def apply(root: Path, receipt_rel: Path) -> dict[str, Any]:
    root = root.resolve()
    registry_path = root / REGISTRY_REL
    receipt_path = root / receipt_rel
    if receipt_path.exists():
        raise RepairError("RECEIPT_ALREADY_EXISTS")
    registry, before_bytes = load_canonical_object(registry_path, "REGISTRY")
    _assert_source(root, before_bytes)
    target, summary = build_target(registry)
    target_bytes = canonical(target) + b"\n"
    if registry_path.read_bytes() != before_bytes:
        raise RepairError("REGISTRY_CHANGED_BEFORE_WRITE")
    registry_path.write_bytes(target_bytes)
    if registry_path.read_bytes() != target_bytes:
        raise RepairError("REGISTRY_POSTWRITE_MISMATCH")

    receipt = {
        "schema_version": SCHEMA_VERSION,
        "repair_id": REPAIR_ID,
        "defect_introduction_head_sha": DEFECT_INTRODUCTION_HEAD_SHA,
        "defect_introduction_parent_sha": DEFECT_INTRODUCTION_PARENT_SHA,
        "invalid_registry_blob_oid": INVALID_REGISTRY_BLOB_OID,
        "invalid_registry_sha256": SOURCE_REGISTRY_SHA256,
        "invalid_registry_contiguous_commit_count": (
            INVALID_REGISTRY_CONTIGUOUS_COMMIT_COUNT
        ),
        "invalid_registry_transition_count": INVALID_REGISTRY_TRANSITION_COUNT,
        "source_head_sha": SOURCE_HEAD_SHA,
        "source_tree_sha": SOURCE_TREE_SHA,
        "target_path": REGISTRY_REL.as_posix(),
        "before_registry_sha256": sha256(before_bytes),
        "after_registry_sha256": sha256(target_bytes),
        "repair_tool_path": Path(__file__).resolve().relative_to(root).as_posix(),
        "repair_tool_sha256": sha256(Path(__file__).read_bytes()),
        **summary,
        "expected_raw_invalid_failure_fingerprint_count": 52,
        "expected_raw_invalid_failure_occurrence_count": (
            52 * INVALID_REGISTRY_TRANSITION_COUNT
        ),
        "expected_identity_migration_count": 2,
        "wildcard_count": 0,
        "future_auto_apply_count": 0,
        "current_failure_correction_count": 0,
        "historical_correction_record_count": 0,
        "old_batch_file_mutation_count": 0,
        "old_evidence_file_mutation_count": 0,
        "product_file_mutation_count": 0,
        "godot_runtime_resource_mutation_count": 0,
        "registry_write_count": 1,
        "receipt_write_count": 1,
        "status": "PASS",
    }
    receipt["receipt_payload_sha256"] = sha256(canonical(receipt))
    receipt_path.parent.mkdir(parents=True, exist_ok=True)
    receipt_path.write_bytes(canonical(receipt))
    return receipt


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--receipt", type=Path, default=DEFAULT_RECEIPT_REL)
    args = parser.parse_args(argv)
    try:
        result = apply(args.root, args.receipt)
    except RepairError as exc:
        print(json.dumps({"status": "FAIL", "error": str(exc)}, sort_keys=True))
        return 2
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
