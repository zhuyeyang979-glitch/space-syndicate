#!/usr/bin/env python3
"""Primary validator for the V076 HDM predecessor successor v2.

Validation is fail-closed and reads predecessor inputs from immutable Git
objects.  The successor has no authority to change the old ledger; it only
records how each of its 86 identities resolves against the current C head.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

try:
    from . import v076_historical_delta_metadata_successor_v2_builder as builder
except ImportError:  # pragma: no cover
    import v076_historical_delta_metadata_successor_v2_builder as builder

MANIFEST_FIELDS = {
    "schema_version", "manifest_kind", "manifest_id", "authorization_id",
    "authorization_base_head_sha", "schema_path", "schema_sha256",
    "predecessor_ledger_path", "predecessor_ledger_head_sha",
    "predecessor_ledger_sha256", "predecessor_record_count",
    "predecessor_failure_count", "predecessor_failure_fingerprint_set_sha256",
    "predecessor_raw_authorities", "raw_report_path", "raw_report_head_sha",
    "raw_report_tree_sha", "raw_report_materialized_head_sha", "raw_report_sha256",
    "current_binding_head_sha", "current_binding_tree_sha", "selector_policy",
    "future_failure_policy", "identity_count", "identity_fingerprints",
    "identity_fingerprint_set_sha256", "rebound_count", "preserved_count",
    "record_chain_start_sha256", "record_chain_terminal_sha256", "record_count",
    "record_bindings", "wildcard_count", "created_at", "creator",
}
RECORD_FIELDS = {
    "schema_version", "record_kind", "record_id", "authorization_id",
    "authorization_base_head_sha", "predecessor_ledger_path",
    "predecessor_ledger_head_sha", "predecessor_ledger_sha256",
    "predecessor_record_path", "predecessor_record_sha256",
    "predecessor_record_payload_sha256", "predecessor_correction_id",
    "source_commit", "parent_commit", "source_registry_sha256",
    "current_binding_head_sha", "current_binding_tree_sha", "raw_report_path",
    "raw_report_head_sha", "raw_report_tree_sha", "raw_report_sha256", "failure_count",
    "failure_fingerprints", "failure_fingerprint_set_sha256", "component_ids",
    "component_set_sha256", "identity_set_sha256", "rebound_count",
    "preserved_count", "identity_bindings", "selector_policy",
    "future_failure_policy", "previous_record_payload_sha256",
    "transition_class_id", "record_payload_sha256",
}


def _sha(value: Any) -> bool:
    return isinstance(value, str) and bool(re.fullmatch(r"[0-9a-f]{64}", value))


def _oid(value: Any) -> bool:
    return isinstance(value, str) and bool(re.fullmatch(r"[0-9a-f]{40}", value))


def _load(path: Path) -> Any:
    return builder.strict_json(path.read_bytes())


def _record_path(root: Path, manifest_path: Path, value: str) -> Path:
    # During staging, records are siblings of the stage manifest.  Once
    # committed, resolve the canonical repository-relative path.
    staged = manifest_path.parent / "records" / Path(value).name
    if staged.is_file():
        return staged
    return root / value


def _expected(root: Path, binding_head: str) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    metadata, records = builder.derive_identities(root, binding_head)
    return metadata, [item["document"] for item in records]


def validate_manifest(root: Path, manifest_path: Path, *, evaluated_head: str | None = None) -> dict[str, Any]:
    failures: list[str] = []
    try:
        manifest = _load(manifest_path)
    except Exception as exc:
        return {"status": "FAIL", "failures": [str(exc)], "identity_count": 0}
    if not isinstance(manifest, dict):
        return {"status": "FAIL", "failures": ["HDM2_MANIFEST_NOT_OBJECT"], "identity_count": 0}
    if set(manifest) != MANIFEST_FIELDS:
        failures.append("HDM2_MANIFEST_FIELD_SET_INVALID")
    for key, expected in (
        ("schema_version", builder.MANIFEST_SCHEMA_VERSION),
        ("manifest_kind", builder.MANIFEST_KIND),
        ("authorization_id", builder.AUTHORIZATION_ID),
        ("authorization_base_head_sha", builder.AUTHORIZATION_BASE_HEAD),
        ("predecessor_ledger_path", builder.PREDECESSOR_LEDGER_PATH),
        ("raw_report_path", builder.RAW_PATH),
        ("raw_report_head_sha", builder.RAW_AUTHORITY_HEAD),
        ("selector_policy", builder.SELECTOR_POLICY),
        ("future_failure_policy", builder.FUTURE_POLICY),
    ):
        if manifest.get(key) != expected:
            failures.append("HDM2_MANIFEST_" + key.upper() + "_INVALID")
    if manifest.get("wildcard_count") != 0:
        failures.append("HDM2_WILDCARD_PRESENT")
    binding_head = str(manifest.get("current_binding_head_sha", ""))
    if not _oid(binding_head):
        failures.append("HDM2_BINDING_HEAD_INVALID")
    evaluated_commit = binding_head
    if evaluated_head:
        try:
            evaluated_commit = str(builder.git(root, "rev-parse", f"{evaluated_head}^{{commit}}")).strip()
            ancestor = str(builder.git(root, "merge-base", "--is-ancestor", binding_head, evaluated_commit)).strip()
            # ``merge-base --is-ancestor`` is silent on success; builder.git
            # raises on a non-ancestor return code.
            if ancestor:
                failures.append("HDM2_EVALUATED_ANCESTRY_OUTPUT_INVALID")
        except Exception:
            failures.append("HDM2_EVALUATED_HEAD_NOT_DESCENDANT")
    try:
        metadata, expected_records = _expected(root, binding_head)
    except Exception as exc:
        return {"status": "FAIL", "failures": sorted(set(failures + ["HDM2_EXPECTED_DERIVATION:" + str(exc)])), "identity_count": 0}
    ledger = metadata["ledger"]
    ledger_raw = metadata["ledger_raw"]
    if manifest.get("predecessor_ledger_sha256") != builder.sha256_bytes(ledger_raw):
        failures.append("HDM2_PREDECESSOR_LEDGER_HASH_INVALID")
    if manifest.get("predecessor_record_count") != 4 or manifest.get("predecessor_record_count") != ledger.get("correction_record_count"):
        failures.append("HDM2_PREDECESSOR_RECORD_COUNT_INVALID")
    if manifest.get("predecessor_failure_count") != ledger.get("corrected_failure_count"):
        failures.append("HDM2_PREDECESSOR_FAILURE_COUNT_INVALID")
    if manifest.get("predecessor_failure_fingerprint_set_sha256") != ledger.get("failure_fingerprint_set_sha256"):
        failures.append("HDM2_PREDECESSOR_FINGERPRINT_SET_INVALID")
    authorities = manifest.get("predecessor_raw_authorities")
    if not isinstance(authorities, list) or len(authorities) != 1:
        failures.append("HDM2_PREDECESSOR_RAW_AUTHORITY_COUNT_INVALID")
    else:
        authority = authorities[0]
        expected_paths = sorted(str(item.get("path", "")) for item in ledger.get("correction_record_bindings", []) if isinstance(item, dict))
        if not isinstance(authority, dict) or authority.get("path") != builder.RAW_PATH or authority.get("sha256") != metadata["raw_report_sha256"] or authority.get("head_sha") != builder.RAW_AUTHORITY_HEAD or authority.get("tree_sha") != builder.RAW_AUTHORITY_TREE or sorted(authority.get("correction_paths", [])) != expected_paths or authority.get("materialized_head_sha") != builder.RAW_HEAD:
            failures.append("HDM2_PREDECESSOR_RAW_AUTHORITY_INVALID")
    if manifest.get("raw_report_tree_sha") != builder.RAW_AUTHORITY_TREE or manifest.get("raw_report_materialized_head_sha") != builder.RAW_HEAD:
        failures.append("HDM2_RAW_REPORT_AUTHORITY_TUPLE_INVALID")
    expected_fps = sorted(item["failure_fingerprint"] for item in metadata["identities"])
    if manifest.get("identity_count") != builder.EXPECTED_TOTAL or manifest.get("identity_fingerprints") != expected_fps:
        failures.append("HDM2_IDENTITY_SET_INVALID")
    if manifest.get("identity_fingerprint_set_sha256") != builder.line_set_sha(expected_fps):
        failures.append("HDM2_IDENTITY_SET_HASH_INVALID")
    if manifest.get("rebound_count") != builder.EXPECTED_REBOUND or manifest.get("preserved_count") != builder.EXPECTED_PRESERVED:
        failures.append("HDM2_CLASSIFICATION_TOTAL_INVALID")
    expected_tree = str(builder.git(root, "rev-parse", f"{binding_head}^{{tree}}")).strip()
    if manifest.get("current_binding_tree_sha") != expected_tree:
        failures.append("HDM2_BINDING_TREE_INVALID")
    schema_file = root / str(manifest.get("schema_path", ""))
    if not schema_file.is_file() or not _sha(manifest.get("schema_sha256")) or builder.sha256_bytes(schema_file.read_bytes()) != manifest.get("schema_sha256"):
        failures.append("HDM2_SCHEMA_BINDING_INVALID")
    if evaluated_commit != binding_head:
        try:
            if builder.blob(root, binding_head, builder.REGISTRY_PATH) != builder.blob(root, evaluated_commit, builder.REGISTRY_PATH):
                failures.append("HDM2_EVALUATED_REGISTRY_DRIFT")
            current_snapshots: dict[str, str] = {}
            for identity in metadata["identities"]:
                for key in ("current_component", "current_owner"):
                    snapshot = identity[key]
                    current_snapshots[str(snapshot["path"])] = str(snapshot["path_blob_sha256"])
            for path, expected_sha in current_snapshots.items():
                if builder.sha256_bytes(builder.blob(root, evaluated_commit, path)) != expected_sha:
                    failures.append("HDM2_EVALUATED_PRODUCT_BLOB_DRIFT:" + path)
        except Exception as exc:
            failures.append("HDM2_EVALUATED_BINDING_INVALID:" + str(exc))

    bindings = manifest.get("record_bindings")
    if not isinstance(bindings, list) or len(bindings) != 4 or manifest.get("record_count") != 4:
        failures.append("HDM2_RECORD_BINDING_COUNT_INVALID")
        bindings = []
    previous = "0" * 64
    actual_identities: list[dict[str, Any]] = []
    for index, (binding, expected_record) in enumerate(zip(bindings, expected_records), 1):
        if not isinstance(binding, dict) or set(binding) != {"path", "record_sha256", "record_payload_sha256", "failure_fingerprints", "previous_record_payload_sha256", "predecessor_correction_id"}:
            failures.append(f"HDM2_RECORD_BINDING_SHAPE_INVALID:{index}")
            continue
        path = str(binding.get("path", ""))
        record_path = _record_path(root, manifest_path, path)
        try:
            raw = record_path.read_bytes(); record = builder.strict_json(raw)
        except Exception as exc:
            failures.append(f"HDM2_RECORD_READ_INVALID:{index}:{exc}"); continue
        if builder.sha256_bytes(raw) != binding.get("record_sha256"):
            failures.append(f"HDM2_RECORD_HASH_INVALID:{index}")
        if not isinstance(record, dict) or set(record) != RECORD_FIELDS:
            failures.append(f"HDM2_RECORD_FIELD_SET_INVALID:{index}"); continue
        if record.get("record_payload_sha256") != binding.get("record_payload_sha256") or builder.payload_sha256(record, "record_payload_sha256") != record.get("record_payload_sha256"):
            failures.append(f"HDM2_RECORD_PAYLOAD_HASH_INVALID:{index}")
        if record.get("previous_record_payload_sha256") != previous or binding.get("previous_record_payload_sha256") != previous:
            failures.append(f"HDM2_RECORD_CHAIN_INVALID:{index}")
        previous = str(record.get("record_payload_sha256", ""))
        if record != expected_record:
            # Compare field-level identity content to avoid allowing a record
            # that merely has the right aggregate count/fingerprint set.
            for key in RECORD_FIELDS:
                if record.get(key) != expected_record.get(key):
                    failures.append(f"HDM2_RECORD_FIELD_DRIFT:{index}:{key}")
        actual_identities.extend(record.get("identity_bindings", []) if isinstance(record.get("identity_bindings"), list) else [])
    if previous != manifest.get("record_chain_terminal_sha256"):
        failures.append("HDM2_RECORD_CHAIN_TERMINAL_INVALID")
    if len(actual_identities) != builder.EXPECTED_TOTAL:
        failures.append("HDM2_IDENTITY_BINDING_COUNT_INVALID")
    rebound = sum(1 for item in actual_identities if isinstance(item, dict) and item.get("classification") == "REBOUND_OWNER")
    preserved = sum(1 for item in actual_identities if isinstance(item, dict) and item.get("classification") == "PRESERVED_OWNER")
    if rebound != builder.EXPECTED_REBOUND or preserved != builder.EXPECTED_PRESERVED:
        failures.append("HDM2_IDENTITY_CLASSIFICATION_INVALID")
    identity_projection = sorted(
        (dict(value) for value in actual_identities if isinstance(value, dict)),
        key=lambda value: str(value.get("failure_fingerprint", "")),
    )
    return {
        "status": "PASS" if not failures else "FAIL",
        "failures": sorted(set(failures)),
        "identity_count": len(actual_identities),
        "rebound_count": rebound,
        "preserved_count": preserved,
        "record_count": len(bindings),
        "authority_projection_sha256": builder.sha256_bytes(
            builder.canonical_bytes(identity_projection)
        ),
        "manifest_path": str(manifest_path),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path.cwd())
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--evaluated-head", default=None)
    args = parser.parse_args(argv)
    result = validate_manifest(args.project.resolve(), args.manifest.resolve(), evaluated_head=args.evaluated_head)
    print(json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2))
    return 0 if result.get("status") == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
