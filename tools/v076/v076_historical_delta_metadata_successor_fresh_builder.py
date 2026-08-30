#!/usr/bin/env python3
"""Build an HDM successor from an explicit fresh Raw authority tuple.

This companion builder deliberately has a distinct name from the historical
Registry repair builder. It never rewrites the frozen predecessor ledger or
correction records and never invents a Raw SHA/head/tree.
"""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

try:
    from . import v076_historical_delta_metadata_successor as successor
except ImportError:  # pragma: no cover
    import v076_historical_delta_metadata_successor as successor

CREATOR = "v076_historical_delta_metadata_successor_fresh_builder.py"


def _git_sha(root: Path, *args: str) -> str:
    return str(successor._git(root, *args)).strip()


def _registry(root: Path, commit: str) -> dict[str, Any]:
    value, _ = successor._load_committed_json(root, commit, successor.REGISTRY_PATH)
    if not isinstance(value, dict):
        raise ValueError("HDMS_REGISTRY_NOT_OBJECT")
    return value


def _transition_proof(root: Path) -> dict[str, Any]:
    before = successor._blob(root, successor.CHANGE_PARENT, successor.REGISTRY_PATH)
    after = successor._blob(root, successor.CHANGE_COMMIT, successor.REGISTRY_PATH)
    if before is None or after is None:
        raise ValueError("HDMS_TRANSITION_REGISTRY_BLOB_MISSING")
    diff = successor._git(root, "diff", "--binary", "--no-ext-diff", successor.CHANGE_PARENT, successor.CHANGE_COMMIT, "--", successor.REGISTRY_PATH, binary=True)
    return {
        "parent_sha": successor.CHANGE_PARENT,
        "commit_sha": successor.CHANGE_COMMIT,
        "parent_tree_sha": _git_sha(root, "rev-parse", f"{successor.CHANGE_PARENT}^{{tree}}"),
        "commit_tree_sha": _git_sha(root, "rev-parse", f"{successor.CHANGE_COMMIT}^{{tree}}"),
        "path": successor.REGISTRY_PATH,
        "before_blob_sha256": successor.sha256_bytes(before),
        "after_blob_sha256": successor.sha256_bytes(after),
        "diff_sha256": successor.sha256_bytes(diff),
    }


def build(root: Path, output_dir: Path, *, predecessor_ledger_head: str, fresh_raw_report: Path, fresh_raw_head: str, fresh_raw_tree: str) -> dict[str, Any]:
    ledger, ledger_raw = successor._load_committed_json(root, predecessor_ledger_head, successor.LEDGER_PATH)
    if not isinstance(ledger, dict):
        raise ValueError("HDMS_PREDECESSOR_LEDGER_NOT_OBJECT")
    raw = successor.strict_json_file(fresh_raw_report)
    if not isinstance(raw, dict) or not isinstance(raw.get("failures"), list):
        raise ValueError("HDMS_FRESH_RAW_FAILURES_INVALID")
    matched = [str(value) for value in raw["failures"] if successor.TARGET_RULE in str(value) and successor.CHANGE_PARENT[:12] in str(value) and successor.CHANGE_COMMIT[:12] in str(value)]
    fingerprints = sorted(successor.failure_fingerprint(value, successor.TARGET_RULE) for value in matched)
    if len(fingerprints) != successor.EXPECTED_SUCCESSOR_FAILURE_COUNT or len(set(fingerprints)) != len(fingerprints):
        raise ValueError("HDMS_FRESH_RAW_TARGET_FAILURE_COUNT_INVALID")
    if not matched:
        raise ValueError("HDMS_FRESH_RAW_TARGET_FAILURES_EMPTY")
    source_registry = _registry(root, successor.CHANGE_COMMIT)
    source_rows = {row.get("component_id"): row for row in source_registry.get("component_inventory", []) if isinstance(row, dict) and isinstance(row.get("component_id"), str)}
    component_ids = sorted({value.rsplit(":", 1)[-1] for value in matched})
    current_registry = _registry(root, fresh_raw_head)
    current_rows = {row.get("component_id"): row for row in current_registry.get("component_inventory", []) if isinstance(row, dict) and isinstance(row.get("component_id"), str)}
    if any(component_id not in source_rows or component_id not in current_rows for component_id in component_ids):
        raise ValueError("HDMS_TARGET_COMPONENT_NOT_REGISTERED")
    if any(source_rows[component_id].get("change_class") == current_rows[component_id].get("change_class") for component_id in component_ids):
        raise ValueError("HDMS_REGISTRY_PROJECTION_NOT_CHANGED")
    report_path = fresh_raw_report.resolve().relative_to(root.resolve()).as_posix() if fresh_raw_report.resolve().is_relative_to(root.resolve()) else fresh_raw_report.as_posix()
    raw_sha = successor.sha256_bytes(fresh_raw_report.read_bytes())
    record: dict[str, Any] = {
        "schema_version": successor.RECORD_SCHEMA_VERSION,
        "record_kind": successor.RECORD_KIND,
        "correction_id": "V2-HDM-SUCCESSOR-20260830-A483684E-COMPONENT-IDENTITY",
        "ledger_id": "V076_HISTORICAL_DELTA_METADATA_LEDGER_SUCCESSOR",
        "authorization_id": successor.AUTHORIZATION_ID,
        "authorization_base_head_sha": successor.AUTHORIZATION_BASE_HEAD,
        "raw_report_path": report_path,
        "raw_report_sha256": raw_sha,
        "raw_report_head_sha": fresh_raw_head,
        "raw_report_tree_sha": fresh_raw_tree,
        "rule_id": successor.TARGET_RULE,
        "transition_class_id": successor.TRANSITION_CLASS,
        "source_commit": successor.CHANGE_COMMIT,
        "parent_commit": successor.CHANGE_PARENT,
        "component_ids": component_ids,
        "component_set_sha256": successor.line_set_sha(component_ids),
        "failure_count": len(fingerprints),
        "failure_fingerprints": fingerprints,
        "failure_fingerprint_set_sha256": successor.line_set_sha(fingerprints),
        "selector_policy": successor.SELECTOR_POLICY,
        "from_state": "RAW_HISTORICAL_METADATA_FAILURE",
        "to_effective_disposition": "CORRECTED_HISTORICAL_METADATA_DEBT",
        "untouched_in_current_delta": True,
        "touch_invalidation_policy": {"path_touch_invalidates": True, "blob_change_invalidates": True, "component_change_invalidates": True, "domain_change_invalidates": True, "owner_change_invalidates": True, "production_reachability_change_invalidates": True, "supersession_change_invalidates": True, "retirement_change_invalidates": True, "unrelated_delta_preserves": True},
        "future_failure_policy": successor.FUTURE_POLICY,
        "previous_correction_payload_sha256": "0" * 64,
    }
    record["record_payload_sha256"] = successor.payload_sha256(record)
    record_path = output_dir / "records" / "v2-hdm-successor-20260830-a483684e-component-identity.json"
    record_path.parent.mkdir(parents=True, exist_ok=True)
    record_path.write_bytes(successor.canonical_bytes(record))
    manifest: dict[str, Any] = {
        "schema_version": successor.MANIFEST_SCHEMA_VERSION,
        "manifest_kind": successor.MANIFEST_KIND,
        "manifest_id": "V076-HDM-SUCCESSOR-20260830-A483684E",
        "authorization_id": successor.AUTHORIZATION_ID,
        "authorization_base_head_sha": successor.AUTHORIZATION_BASE_HEAD,
        "predecessor_ledger_path": successor.LEDGER_PATH,
        "predecessor_ledger_head_sha": predecessor_ledger_head,
        "predecessor_ledger_sha256": successor.sha256_bytes(ledger_raw),
        "predecessor_record_count": ledger.get("correction_record_count"),
        "predecessor_failure_count": ledger.get("corrected_failure_count"),
        "predecessor_failure_fingerprint_set_sha256": ledger.get("failure_fingerprint_set_sha256"),
        "predecessor_raw_authorities": successor._predecessor_raw_authorities(ledger, root, predecessor_ledger_head),
        "new_raw_authority": {"path": report_path, "sha256": raw_sha, "head_sha": fresh_raw_head, "tree_sha": fresh_raw_tree},
        "authority_transition": _transition_proof(root),
        "selector_policy": successor.SELECTOR_POLICY,
        "future_failure_policy": successor.FUTURE_POLICY,
        "successor_record_count": 1,
        "successor_failure_count": len(fingerprints),
        "successor_failure_fingerprints": fingerprints,
        "successor_failure_fingerprint_set_sha256": successor.line_set_sha(fingerprints),
        "record_chain_start_sha256": "0" * 64,
        "record_chain_terminal_sha256": record["record_payload_sha256"],
        "wildcard_count": 0,
        "record_bindings": [{"path": successor.RECORD_ROOT + record_path.name, "record_sha256": successor.sha256_bytes(record_path.read_bytes()), "record_payload_sha256": record["record_payload_sha256"], "failure_fingerprints": fingerprints, "previous_correction_payload_sha256": "0" * 64}],
        "created_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "creator": CREATOR,
    }
    manifest_path = output_dir / "manifest.json"
    manifest_path.write_bytes(successor.canonical_bytes(manifest))
    return {"manifest_path": str(manifest_path), "record_path": str(record_path), "validation": successor.validate_manifest(root, manifest_path)}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path.cwd())
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--predecessor-ledger-head", required=True)
    parser.add_argument("--fresh-raw-report", type=Path, required=True)
    parser.add_argument("--fresh-raw-head", required=True)
    parser.add_argument("--fresh-raw-tree", required=True)
    args = parser.parse_args(argv)
    result = build(args.project.resolve(), args.output_dir.resolve(), predecessor_ledger_head=args.predecessor_ledger_head, fresh_raw_report=args.fresh_raw_report.resolve(), fresh_raw_head=args.fresh_raw_head, fresh_raw_tree=args.fresh_raw_tree)
    print(json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2))
    return 0 if result.get("validation", {}).get("status") == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
