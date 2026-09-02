#!/usr/bin/env python3
"""Build the append-only V076 HDM predecessor revalidation successor.

The predecessor ledger is frozen at ``d4720d34...`` and contains 86 exact
historical failure identities spread over four correction records.  This
builder derives each identity from the committed predecessor record and its
Raw report, then binds the source/current component and owner rows at the
requested C head.  It never edits the predecessor ledger or any predecessor
record.  Owner-row changes are classified as ``REBOUND_OWNER``; unchanged
owner rows are ``PRESERVED_OWNER``.  The expected split is 52/34.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

PREDECESSOR_LEDGER_PATH = "docs/architecture/V076_HISTORICAL_DELTA_METADATA_LEDGER.json"
REGISTRY_PATH = "docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json"
PREDECESSOR_HEAD = "d4720d34b5dd99541c20907cb5231b1a780d1cf7"
CURRENT_BINDING_HEAD = "38e3776accee3cbe64e5abbf3d776561114d8d01"
RAW_PATH = "reports/reuse/correction_v2/epochs/full_convergence_20260827/v076_current_7b2bd08a_raw.json"
# The raw report was introduced by the predecessor ledger at d4720d34, while
# its immutable authority tuple points to the scanner source head 7b2bd08a.
# Keep both identities explicit: bytes are materialized from the predecessor
# snapshot, but the recorded authority remains the original scan head/tree.
RAW_HEAD = PREDECESSOR_HEAD
RAW_AUTHORITY_HEAD = "7b2bd08a9916a3a517f2d418765c544cce0261cc"
RAW_AUTHORITY_TREE = "990b070c3f7cfefa3bf6853ff22f9023049ede29"
AUTHORIZATION_ID = "USER_AUTHORIZATION_V076_CURRENT_SUBJECT_CONVERGENCE_AND_COMMERCIAL_RESUME_20260830"
AUTHORIZATION_BASE_HEAD = "d701a81dce693b584d52fbfca3e0e78b521ad775"
TARGET_RULES = (
    "NEW_COMPONENT_CANNOT_CLAIM_INHERITED",
    "HISTORY_NEW_AUTHORITY_REUSE_SCAN_INVALID",
    "HISTORY_PRODUCT_REUSE_SCAN_INVALID",
)
SELECTOR_POLICY = {
    "match_mode": "EXACT_FAILURE_FINGERPRINTS_ONLY",
    "wildcard_allowed": False,
    "regex_allowed": False,
    "path_prefix_allowed": False,
    "branch_selector_allowed": False,
    "date_selector_allowed": False,
    "future_failure_auto_match": False,
}
FUTURE_POLICY = {"automatic_match": False, "new_failure_requires_new_record": True}
EXPECTED_TOTAL = 86
EXPECTED_REBOUND = 52
EXPECTED_PRESERVED = 34
MANIFEST_KIND = "HISTORICAL_DELTA_METADATA_SUCCESSOR_V2_MANIFEST"
RECORD_KIND = "HISTORICAL_DELTA_METADATA_SUCCESSOR_V2_RECORD"
MANIFEST_SCHEMA_VERSION = "space_syndicate.v076.reuse_exact_failure_correction.v2.historical_delta_metadata_successor_v2_manifest.v1"
RECORD_SCHEMA_VERSION = "space_syndicate.v076.reuse_exact_failure_correction.v2.historical_delta_metadata_successor_v2_record.v1"
SCHEMA_VERSION = "space_syndicate.v076.reuse_exact_failure_correction.v2.historical_delta_metadata_successor_v2_schema.v1"
SUCCESSOR_ROOT = "docs/architecture/reuse_corrections/v2/historical_delta_metadata_successor_v2/"
RECORD_ROOT = SUCCESSOR_ROOT + "records/"
SCHEMA_PATH = "docs/architecture/reuse_corrections/v2/schema_historical_delta_metadata_successor_v2_20260830.json"
CREATOR = "v076_historical_delta_metadata_successor_v2_builder.py"
LEGACY_MANIFEST_ID = "V076-HDM-SUCCESSOR-V2-20260830-CHEAD-38E3776"


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False) + "\n").encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def payload_sha256(value: dict[str, Any], field: str) -> str:
    body = dict(value)
    body.pop(field, None)
    return sha256_bytes(canonical_bytes(body))


def line_set_sha(values: list[str] | tuple[str, ...]) -> str:
    return sha256_bytes(("\n".join(sorted(set(values))) + "\n").encode())


def fingerprint(raw_failure: str, rule_id: str) -> str:
    return "V2F-" + sha256_bytes(f"V076_RAW_FAILURE_V2\nHISTORICAL\n{rule_id}\n{raw_failure}\n".encode())


def strict_json(raw: bytes) -> Any:
    def pairs(items: list[tuple[str, Any]]) -> dict[str, Any]:
        result: dict[str, Any] = {}
        for key, value in items:
            if key in result:
                raise ValueError("DUPLICATE_JSON_KEY:" + key)
            result[key] = value
        return result

    return json.loads(raw.decode("utf-8-sig"), object_pairs_hook=pairs, parse_constant=lambda value: (_ for _ in ()).throw(ValueError("NONFINITE_JSON:" + value)))


def git(root: Path, *args: str, binary: bool = False) -> str | bytes:
    result = subprocess.run(["git", *args], cwd=root, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=not binary, check=False)
    if result.returncode:
        message = result.stderr.decode(errors="replace") if binary else result.stderr
        raise ValueError(message.strip() or "GIT_COMMAND_FAILED")
    return result.stdout


def blob(root: Path, commit: str, path: str) -> bytes:
    result = subprocess.run(["git", "cat-file", "-p", f"{commit}:{path}"], cwd=root, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    if result.returncode:
        raise ValueError(f"COMMITTED_BLOB_MISSING:{commit}:{path}")
    return result.stdout


def load_json(root: Path, commit: str, path: str) -> tuple[Any, bytes]:
    raw = blob(root, commit, path)
    return strict_json(raw), raw


def row_sha(row: dict[str, Any]) -> str:
    return sha256_bytes(canonical_bytes(row))


def path_blob_sha(root: Path, commit: str, path: str) -> str:
    return sha256_bytes(blob(root, commit, path))


def oid(value: str) -> bool:
    return bool(re.fullmatch(r"[0-9a-f]{40}", value))


def component_map(registry: dict[str, Any]) -> dict[str, dict[str, Any]]:
    rows = registry.get("component_inventory")
    if not isinstance(rows, list):
        raise ValueError("REGISTRY_COMPONENT_INVENTORY_INVALID")
    result: dict[str, dict[str, Any]] = {}
    for row in rows:
        if not isinstance(row, dict) or not isinstance(row.get("component_id"), str) or row["component_id"] in result:
            raise ValueError("REGISTRY_COMPONENT_ROW_INVALID")
        result[row["component_id"]] = row
    return result


def raw_identity_map(raw_report: dict[str, Any]) -> dict[str, tuple[str, str, str]]:
    failures = raw_report.get("failures")
    if not isinstance(failures, list):
        raise ValueError("RAW_FAILURES_INVALID")
    result: dict[str, tuple[str, str, str]] = {}
    for item in failures:
        value = str(item)
        for rule in TARGET_RULES:
            prefix = rule + ":"
            if not value.startswith(prefix):
                continue
            pieces = value.split(":", 2)
            if len(pieces) != 3:
                raise ValueError("RAW_FAILURE_SHAPE_INVALID:" + value)
            fp = fingerprint(value, rule)
            if fp in result:
                raise ValueError("RAW_FAILURE_FINGERPRINT_DUPLICATE:" + fp)
            result[fp] = (rule, value, pieces[2])
    return result


def _component_snapshot(root: Path, commit: str, components: dict[str, dict[str, Any]], component_id: str, role: str) -> dict[str, Any]:
    row = components.get(component_id)
    if row is None:
        raise ValueError(f"{role}_COMPONENT_MISSING:{component_id}")
    path = row.get("path")
    if not isinstance(path, str) or not path or path.startswith("/"):
        raise ValueError(f"{role}_COMPONENT_PATH_INVALID:{component_id}")
    # Keep the exact registry row in the artifact so an audit can recompute
    # every derived field without trusting a summary field.
    return {
        "component_id": component_id,
        "row": row,
        "row_sha256": row_sha(row),
        "path": path,
        "path_blob_sha256": path_blob_sha(root, commit, path),
        "domain_id": row.get("domain_id"),
        "owner_component_id": row.get("owner_component_id"),
        "production_reachable": row.get("production_reachable"),
    }


def derive_identities(root: Path, binding_head: str) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    ledger, ledger_raw = load_json(root, PREDECESSOR_HEAD, PREDECESSOR_LEDGER_PATH)
    if not isinstance(ledger, dict):
        raise ValueError("PREDECESSOR_LEDGER_NOT_OBJECT")
    raw_report, raw_raw = load_json(root, RAW_HEAD, RAW_PATH)
    if not isinstance(raw_report, dict):
        raise ValueError("RAW_REPORT_NOT_OBJECT")
    identities_by_fp = raw_identity_map(raw_report)
    current_registry, current_registry_raw = load_json(root, binding_head, REGISTRY_PATH)
    current_components = component_map(current_registry)
    all_identities: list[dict[str, Any]] = []
    records: list[dict[str, Any]] = []
    bindings = ledger.get("correction_record_bindings")
    if not isinstance(bindings, list) or len(bindings) != 4:
        raise ValueError("PREDECESSOR_CORRECTION_RECORD_COUNT_INVALID")
    previous = "0" * 64
    for index, ledger_binding in enumerate(bindings, 1):
        if not isinstance(ledger_binding, dict):
            raise ValueError("PREDECESSOR_CORRECTION_BINDING_INVALID")
        record_path = str(ledger_binding.get("path", ""))
        predecessor_record, predecessor_record_raw = load_json(root, PREDECESSOR_HEAD, record_path)
        if not isinstance(predecessor_record, dict):
            raise ValueError("PREDECESSOR_RECORD_NOT_OBJECT:" + record_path)
        source_commit = str(predecessor_record.get("source_commit", ""))
        parent_commit = str(predecessor_record.get("parent_commit", ""))
        if not oid(source_commit) or not oid(parent_commit):
            raise ValueError("PREDECESSOR_RECORD_COMMIT_INVALID:" + record_path)
        source_registry, source_registry_raw = load_json(root, source_commit, REGISTRY_PATH)
        source_components = component_map(source_registry)
        fps = predecessor_record.get("failure_fingerprints")
        if not isinstance(fps, list) or len(fps) != int(predecessor_record.get("failure_count", -1)):
            raise ValueError("PREDECESSOR_FAILURE_LIST_INVALID:" + record_path)
        local: list[dict[str, Any]] = []
        for fp in fps:
            if not isinstance(fp, str) or fp not in identities_by_fp:
                raise ValueError("PREDECESSOR_FAILURE_IDENTITY_NOT_IN_RAW:" + str(fp))
            rule_id, raw_failure, component_id = identities_by_fp[fp]
            source_component = _component_snapshot(root, source_commit, source_components, component_id, "SOURCE")
            current_component = _component_snapshot(root, binding_head, current_components, component_id, "CURRENT")
            source_owner_id = str(source_component["owner_component_id"])
            current_owner_id = str(current_component["owner_component_id"])
            source_owner = _component_snapshot(root, source_commit, source_components, source_owner_id, "SOURCE_OWNER")
            current_owner = _component_snapshot(root, binding_head, current_components, current_owner_id, "CURRENT_OWNER")
            owner_rebound = source_owner["row_sha256"] != current_owner["row_sha256"]
            classification = "REBOUND_OWNER" if owner_rebound else "PRESERVED_OWNER"
            identity = {
                "failure_fingerprint": fp,
                "rule_id": rule_id,
                "raw_failure": raw_failure,
                "component_id": component_id,
                "source_commit": source_commit,
                "parent_commit": parent_commit,
                "source_component": source_component,
                "current_component": current_component,
                "source_owner": source_owner,
                "current_owner": current_owner,
                "classification": classification,
                "owner_rebound": owner_rebound,
                "classification_basis": "SOURCE_OWNER_ROW_SHA256_VS_CURRENT_OWNER_ROW_SHA256",
            }
            local.append(identity)
            all_identities.append(identity)
        local_fps = [item["failure_fingerprint"] for item in local]
        rebound = sum(1 for item in local if item["classification"] == "REBOUND_OWNER")
        preserved = len(local) - rebound
        record = {
            "schema_version": RECORD_SCHEMA_VERSION,
            "record_kind": RECORD_KIND,
            "record_id": f"V076-HDM2-{index:02d}-{str(ledger_binding.get('correction_id', 'UNKNOWN')).split('-')[-1].upper()}",
            "authorization_id": AUTHORIZATION_ID,
            "authorization_base_head_sha": AUTHORIZATION_BASE_HEAD,
            "predecessor_ledger_path": PREDECESSOR_LEDGER_PATH,
            "predecessor_ledger_head_sha": PREDECESSOR_HEAD,
            "predecessor_ledger_sha256": sha256_bytes(ledger_raw),
            "predecessor_record_path": record_path,
            "predecessor_record_sha256": sha256_bytes(predecessor_record_raw),
            "predecessor_record_payload_sha256": predecessor_record.get("record_payload_sha256"),
            "predecessor_correction_id": ledger_binding.get("correction_id"),
            "source_commit": source_commit,
            "parent_commit": parent_commit,
            "source_registry_sha256": sha256_bytes(source_registry_raw),
            "current_binding_head_sha": binding_head,
            "current_binding_tree_sha": str(git(root, "rev-parse", f"{binding_head}^{{tree}}")).strip(),
            "raw_report_path": RAW_PATH,
            "raw_report_head_sha": RAW_AUTHORITY_HEAD,
            "raw_report_tree_sha": RAW_AUTHORITY_TREE,
            "raw_report_sha256": sha256_bytes(raw_raw),
            "failure_count": len(local),
            "failure_fingerprints": sorted(local_fps),
            "component_ids": sorted({item["component_id"] for item in local}),
            "rebound_count": rebound,
            "preserved_count": preserved,
            "identity_bindings": sorted(local, key=lambda item: item["failure_fingerprint"]),
            "selector_policy": SELECTOR_POLICY,
            "future_failure_policy": FUTURE_POLICY,
            "previous_record_payload_sha256": previous,
            "transition_class_id": "HISTORICAL_COMPONENT_IDENTITY_METADATA_REVALIDATION",
            "record_payload_sha256": "",
        }
        record["failure_fingerprint_set_sha256"] = line_set_sha(local_fps)
        record["component_set_sha256"] = line_set_sha(record["component_ids"])
        record["identity_set_sha256"] = line_set_sha(local_fps)
        record["record_payload_sha256"] = payload_sha256(record, "record_payload_sha256")
        previous = record["record_payload_sha256"]
        records.append({"document": record, "raw": canonical_bytes(record), "predecessor_binding": ledger_binding})
    if len(all_identities) != EXPECTED_TOTAL:
        raise ValueError(f"IDENTITY_COUNT_INVALID:{len(all_identities)}")
    rebound = sum(1 for item in all_identities if item["classification"] == "REBOUND_OWNER")
    preserved = len(all_identities) - rebound
    if rebound != EXPECTED_REBOUND or preserved != EXPECTED_PRESERVED:
        raise ValueError(f"OWNER_CLASSIFICATION_SPLIT_INVALID:{rebound}:{preserved}")
    metadata = {
        "ledger": ledger,
        "ledger_raw": ledger_raw,
        "raw_report_sha256": sha256_bytes(raw_raw),
        "current_registry_sha256": sha256_bytes(current_registry_raw),
        "identities": all_identities,
        "records": records,
        "rebound": rebound,
        "preserved": preserved,
    }
    return metadata, records


def artifact_identity(
    binding_head: str,
    repository_output_root: str | None = None,
    manifest_id: str | None = None,
) -> tuple[str, str]:
    """Locate one explicit exact-Head epoch without redefining old artifacts.

    This is an artifact destination, not a failure selector. Identity membership,
    predecessor bytes, owner derivation and both validators remain unchanged.
    """
    if not oid(binding_head):
        raise ValueError("BINDING_HEAD_INVALID")
    if repository_output_root is None and manifest_id is None:
        if binding_head != CURRENT_BINDING_HEAD:
            raise ValueError("NEW_BINDING_REQUIRES_EXPLICIT_ARTIFACT_IDENTITY")
        return SUCCESSOR_ROOT, LEGACY_MANIFEST_ID
    if repository_output_root is None or manifest_id is None:
        raise ValueError("ARTIFACT_IDENTITY_ARGUMENT_PAIR_REQUIRED")
    expected_root = SUCCESSOR_ROOT + "epochs/" + binding_head + "/"
    expected_id = "V076-HDM-SUCCESSOR-V2-CHEAD-" + binding_head.upper()
    if repository_output_root != expected_root:
        raise ValueError("ARTIFACT_ROOT_NOT_EXACT_BINDING_HEAD")
    if manifest_id != expected_id:
        raise ValueError("ARTIFACT_MANIFEST_ID_NOT_EXACT_BINDING_HEAD")
    return repository_output_root, manifest_id


def build(
    root: Path,
    output: Path,
    binding_head: str = CURRENT_BINDING_HEAD,
    created_at: str | None = None,
    *,
    repository_output_root: str | None = None,
    manifest_id: str | None = None,
) -> dict[str, Any]:
    if not oid(binding_head):
        raise ValueError("BINDING_HEAD_INVALID")
    artifact_root, artifact_manifest_id = artifact_identity(
        binding_head, repository_output_root, manifest_id
    )
    if output.resolve().is_relative_to(root.resolve()):
        actual_root = output.resolve().relative_to(root.resolve()).as_posix() + "/"
        if actual_root != artifact_root:
            raise ValueError("REPOSITORY_OUTPUT_DESTINATION_MISMATCH")
    metadata, records = derive_identities(root, binding_head)
    schema_file = root / SCHEMA_PATH
    schema_raw = schema_file.read_bytes() if schema_file.is_file() else blob(root, binding_head, SCHEMA_PATH)
    output.mkdir(parents=True, exist_ok=False)
    (output / "records").mkdir()
    previous = "0" * 64
    record_bindings: list[dict[str, Any]] = []
    for item in records:
        document = item["document"]
        raw = item["raw"]
        filename = "hdm2-" + document["record_id"].lower().replace(" ", "-") + ".json"
        path = output / "records" / filename
        path.write_bytes(raw)
        record_bindings.append({
            "path": artifact_root + "records/" + filename,
            "record_sha256": sha256_bytes(raw),
            "record_payload_sha256": document["record_payload_sha256"],
            "failure_fingerprints": document["failure_fingerprints"],
            "previous_record_payload_sha256": previous,
            "predecessor_correction_id": document["predecessor_correction_id"],
        })
        previous = document["record_payload_sha256"]
    all_fps = [item["failure_fingerprint"] for item in metadata["identities"]]
    manifest = {
        "schema_version": MANIFEST_SCHEMA_VERSION,
        "manifest_kind": MANIFEST_KIND,
        "manifest_id": artifact_manifest_id,
        "authorization_id": AUTHORIZATION_ID,
        "authorization_base_head_sha": AUTHORIZATION_BASE_HEAD,
        "predecessor_ledger_path": PREDECESSOR_LEDGER_PATH,
        "predecessor_ledger_head_sha": PREDECESSOR_HEAD,
        "predecessor_ledger_sha256": sha256_bytes(metadata["ledger_raw"]),
        "predecessor_record_count": len(records),
        "predecessor_failure_count": int(metadata["ledger"].get("corrected_failure_count", -1)),
        "predecessor_failure_fingerprint_set_sha256": metadata["ledger"].get("failure_fingerprint_set_sha256"),
        "predecessor_raw_authorities": [{
            "path": RAW_PATH,
            "sha256": metadata["raw_report_sha256"],
            "head_sha": RAW_AUTHORITY_HEAD,
            "tree_sha": RAW_AUTHORITY_TREE,
            "correction_paths": [str(binding.get("path", "")) for binding in metadata["ledger"].get("correction_record_bindings", []) if isinstance(binding, dict)],
            "materialized_head_sha": RAW_HEAD,
        }],
        "raw_report_path": RAW_PATH,
        "raw_report_head_sha": RAW_AUTHORITY_HEAD,
        "raw_report_tree_sha": RAW_AUTHORITY_TREE,
        "raw_report_materialized_head_sha": RAW_HEAD,
        "raw_report_sha256": metadata["raw_report_sha256"],
        "schema_path": SCHEMA_PATH,
        "schema_sha256": sha256_bytes(schema_raw),
        "current_binding_head_sha": binding_head,
        "current_binding_tree_sha": str(git(root, "rev-parse", f"{binding_head}^{{tree}}" )).strip(),
        "selector_policy": SELECTOR_POLICY,
        "future_failure_policy": FUTURE_POLICY,
        "identity_count": len(all_fps),
        "identity_fingerprints": sorted(all_fps),
        "identity_fingerprint_set_sha256": line_set_sha(all_fps),
        "rebound_count": metadata["rebound"],
        "preserved_count": metadata["preserved"],
        "record_chain_start_sha256": "0" * 64,
        "record_chain_terminal_sha256": previous,
        "record_count": len(records),
        "record_bindings": record_bindings,
        "wildcard_count": 0,
        "created_at": created_at or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "creator": CREATOR,
    }
    (output / "manifest.json").write_bytes(canonical_bytes(manifest))
    return {
        "status": "PASS",
        "output": str(output),
        "manifest": str(output / "manifest.json"),
        "record_count": len(records),
        "identity_count": len(all_fps),
        "rebound_count": metadata["rebound"],
        "preserved_count": metadata["preserved"],
        "binding_head": binding_head,
        "repository_output_root": artifact_root,
        "manifest_id": artifact_manifest_id,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path.cwd())
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--binding-head", default=CURRENT_BINDING_HEAD)
    parser.add_argument("--created-at", default=None)
    parser.add_argument("--repository-output-root", default=None)
    parser.add_argument("--manifest-id", default=None)
    args = parser.parse_args(argv)
    try:
        result = build(
            args.project.resolve(), args.output.resolve(), args.binding_head, args.created_at,
            repository_output_root=args.repository_output_root, manifest_id=args.manifest_id,
        )
    except Exception as error:
        print(json.dumps({"status": "FAIL", "failures": [str(error)]}, ensure_ascii=False, indent=2))
        return 1
    print(json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
