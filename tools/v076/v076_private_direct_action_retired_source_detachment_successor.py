#!/usr/bin/env python3
"""Detach one retired reuse source from the active Direct Action projection.

The retired MilitaryRuntimeController remains visible as a considered reuse
candidate, but it is not a live source of the production Direct Action owner.
This exact successor mutates only that one ``reuse_source_ids`` element and
writes a new append-only receipt.  Batch-009 and its retirement evidence remain
immutable.
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
    "private_direct_action_retired_source_detachment_20260831.json"
)
SOURCE_REGISTRY_SHA256 = (
    "64c8b385292e82332368a122d3d41151ca98eb517778428aa4f536f2d08194ca"
)
SOURCE_HEAD_SHA = "846810513887e8a32c4345df0e14129a35764e09"
SOURCE_TREE_SHA = "7202f4d8cd3f5e177891f3305ae5e8418de54779"
SOURCE_REGISTRY_BLOB_OID = "9a748875cfba50b3d28755ed320a60494891d46a"
COMPONENT_ID = "component.v076.private_direct_action_input"
RETIRED_SOURCE_ID = "reuse.current.military_runtime_owner"
ACTIVE_SUCCESSOR_SOURCE_ID = "reuse.v075.production_military_direct_action.current"


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
        ["git", *args], cwd=root, text=True, encoding="utf-8",
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
    )
    if result.returncode:
        raise RepairError(f"GIT_FAILED:{' '.join(args)}:{result.stderr.strip()}")
    return result.stdout.strip()


def apply(root: Path, receipt_rel: Path) -> dict[str, Any]:
    root = root.resolve()
    registry_path = root / REGISTRY_REL
    receipt_path = root / receipt_rel
    if receipt_path.exists():
        raise RepairError("RECEIPT_ALREADY_EXISTS")
    before_bytes = registry_path.read_bytes()
    if sha256(before_bytes) != SOURCE_REGISTRY_SHA256:
        raise RepairError("SOURCE_REGISTRY_SHA256_MISMATCH")
    if git(root, "rev-parse", "HEAD^{commit}") != SOURCE_HEAD_SHA:
        raise RepairError("SOURCE_HEAD_MISMATCH")
    if git(root, "rev-parse", "HEAD^{tree}") != SOURCE_TREE_SHA:
        raise RepairError("SOURCE_TREE_MISMATCH")
    try:
        registry = json.loads(before_bytes.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise RepairError("SOURCE_REGISTRY_JSON_INVALID") from exc
    if not isinstance(registry, dict) or before_bytes != canonical(registry) + b"\n":
        raise RepairError("SOURCE_REGISTRY_NOT_CANONICAL")
    inventory = registry.get("component_inventory")
    reuse_entries = registry.get("reuse_entries")
    if not isinstance(inventory, list) or not isinstance(reuse_entries, list):
        raise RepairError("SOURCE_REGISTRY_STRUCTURE_INVALID")
    matches = [row for row in inventory if isinstance(row, dict) and row.get("component_id") == COMPONENT_ID]
    if len(matches) != 1:
        raise RepairError(f"TARGET_COMPONENT_CARDINALITY_INVALID:{len(matches)}")
    target_before = matches[0]
    sources_before = target_before.get("reuse_source_ids")
    considered_before = target_before.get("reuse_candidates_considered")
    scan_before = target_before.get("reuse_scan")
    if (
        not isinstance(sources_before, list)
        or sources_before.count(RETIRED_SOURCE_ID) != 1
        or ACTIVE_SUCCESSOR_SOURCE_ID not in sources_before
        or not isinstance(considered_before, list)
        or RETIRED_SOURCE_ID not in considered_before
        or not isinstance(scan_before, dict)
        or scan_before.get("reuse_candidate_count") != 12
        or RETIRED_SOURCE_ID not in scan_before.get("reuse_candidate_ids", [])
        or ACTIVE_SUCCESSOR_SOURCE_ID not in scan_before.get("reuse_candidate_ids", [])
    ):
        raise RepairError("TARGET_COMPONENT_SOURCE_CONTRACT_INVALID")
    retired_rows = [
        row for row in reuse_entries
        if isinstance(row, dict) and row.get("reuse_id") == RETIRED_SOURCE_ID
    ]
    if len(retired_rows) != 1 or retired_rows[0].get("disposition") != "RETIRED":
        raise RepairError("RETIRED_SOURCE_ROW_INVALID")

    target_registry = copy.deepcopy(registry)
    target_rows = [row for row in target_registry["component_inventory"] if row.get("component_id") == COMPONENT_ID]
    target_after = target_rows[0]
    target_after["reuse_source_ids"] = [
        source for source in target_after["reuse_source_ids"] if source != RETIRED_SOURCE_ID
    ]
    if len(target_after["reuse_source_ids"]) != len(sources_before) - 1:
        raise RepairError("RETIRED_SOURCE_DETACHMENT_CARDINALITY_INVALID")
    if target_after["reuse_candidates_considered"] != considered_before:
        raise RepairError("CONSIDERED_CANDIDATES_CHANGED")
    if target_after["reuse_scan"] != scan_before:
        raise RepairError("REUSE_SCAN_CHANGED")
    before_by_id = {row.get("component_id"): row for row in inventory if isinstance(row, dict)}
    after_by_id = {
        row.get("component_id"): row
        for row in target_registry["component_inventory"]
        if isinstance(row, dict)
    }
    for component_id, before in before_by_id.items():
        after = after_by_id.get(component_id)
        if after is None:
            raise RepairError(f"COMPONENT_REMOVED:{component_id}")
        changed_fields = {
            key for key in set(before) | set(after) if before.get(key) != after.get(key)
        }
        expected = {"reuse_source_ids"} if component_id == COMPONENT_ID else set()
        if changed_fields != expected:
            raise RepairError(
                f"NON_ALLOWLISTED_FIELD_CHANGE:{component_id}:{','.join(sorted(changed_fields))}"
            )
    if [row.get("component_id") for row in inventory] != [
        row.get("component_id") for row in target_registry["component_inventory"]
    ]:
        raise RepairError("COMPONENT_INVENTORY_ORDER_CHANGED")

    after_bytes = canonical(target_registry) + b"\n"
    if registry_path.read_bytes() != before_bytes:
        raise RepairError("REGISTRY_CHANGED_BEFORE_WRITE")
    registry_path.write_bytes(after_bytes)
    if registry_path.read_bytes() != after_bytes:
        raise RepairError("REGISTRY_POSTWRITE_MISMATCH")
    receipt = {
        "schema_version": (
            "space_syndicate.v076.reuse_full_convergence."
            "private_direct_action_retired_source_detachment.v1"
        ),
        "repair_id": "V076_PRIVATE_DIRECT_ACTION_RETIRED_SOURCE_DETACHMENT_20260831",
        "source_head_sha": SOURCE_HEAD_SHA,
        "source_tree_sha": SOURCE_TREE_SHA,
        "source_registry_blob_oid": SOURCE_REGISTRY_BLOB_OID,
        "target_path": REGISTRY_REL.as_posix(),
        "repair_tool_path": Path(__file__).resolve().relative_to(root).as_posix(),
        "repair_tool_sha256": sha256(Path(__file__).read_bytes()),
        "component_id": COMPONENT_ID,
        "detached_reuse_source_id": RETIRED_SOURCE_ID,
        "retained_active_successor_source_id": ACTIVE_SUCCESSOR_SOURCE_ID,
        "before_registry_sha256": sha256(before_bytes),
        "after_registry_sha256": sha256(after_bytes),
        "before_live_source_count": len(sources_before),
        "after_live_source_count": len(target_after["reuse_source_ids"]),
        "retired_candidate_considered_count_after": target_after[
            "reuse_candidates_considered"
        ].count(RETIRED_SOURCE_ID),
        "retired_candidate_scan_count_after": target_after["reuse_scan"][
            "reuse_candidate_ids"
        ].count(RETIRED_SOURCE_ID),
        "reuse_scan_candidate_count_after": target_after["reuse_scan"][
            "reuse_candidate_count"
        ],
        "changed_component_count": 1,
        "changed_field_count": 1,
        "changed_fields": ["reuse_source_ids"],
        "old_batch_file_mutation_count": 0,
        "old_evidence_file_mutation_count": 0,
        "product_file_mutation_count": 0,
        "current_failure_correction_count": 0,
        "waiver_count": 0,
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
    except (OSError, RepairError) as exc:
        print(json.dumps({"status": "FAIL", "error": str(exc)}, sort_keys=True))
        return 2
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
