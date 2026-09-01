#!/usr/bin/env python3
"""Independent, primary-validator-free audit for the HDM successor v2.

This audit intentionally does not import the primary validator or builder.  It
checks the committed manifest/record bytes, chain, exact identity cardinality,
and fail-closed policy from an independent implementation.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path
from typing import Any

LEDGER_PATH = "docs/architecture/V076_HISTORICAL_DELTA_METADATA_LEDGER.json"
LEDGER_HEAD = "d4720d34b5dd99541c20907cb5231b1a780d1cf7"
RAW_MATERIALIZED_HEAD = LEDGER_HEAD
RAW_AUTHORITY_HEAD = "7b2bd08a9916a3a517f2d418765c544cce0261cc"
RAW_AUTHORITY_TREE = "990b070c3f7cfefa3bf6853ff22f9023049ede29"
REGISTRY_PATH = "docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json"
RAW_PATH = "reports/reuse/correction_v2/epochs/full_convergence_20260827/v076_current_7b2bd08a_raw.json"
RAW_HEAD = LEDGER_HEAD
TARGET_RULES = (
    "NEW_COMPONENT_CANNOT_CLAIM_INHERITED",
    "HISTORY_NEW_AUTHORITY_REUSE_SCAN_INVALID",
    "HISTORY_PRODUCT_REUSE_SCAN_INVALID",
)
EXPECTED_MANIFEST_KIND = "HISTORICAL_DELTA_METADATA_SUCCESSOR_V2_MANIFEST"
EXPECTED_RECORD_KIND = "HISTORICAL_DELTA_METADATA_SUCCESSOR_V2_RECORD"
EXPECTED_SCHEMA = "space_syndicate.v076.reuse_exact_failure_correction.v2.historical_delta_metadata_successor_v2_manifest.v1"
EXPECTED_RECORD_SCHEMA = "space_syndicate.v076.reuse_exact_failure_correction.v2.historical_delta_metadata_successor_v2_record.v1"
SELECTOR = {"match_mode": "EXACT_FAILURE_FINGERPRINTS_ONLY", "wildcard_allowed": False, "regex_allowed": False, "path_prefix_allowed": False, "branch_selector_allowed": False, "date_selector_allowed": False, "future_failure_auto_match": False}
FUTURE = {"automatic_match": False, "new_failure_requires_new_record": True}


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def strict(raw: bytes) -> Any:
    def pairs(items: list[tuple[str, Any]]) -> dict[str, Any]:
        result: dict[str, Any] = {}
        for key, value in items:
            if key in result:
                raise ValueError("DUPLICATE_JSON_KEY:" + key)
            result[key] = value
        return result
    return json.loads(raw.decode("utf-8-sig"), object_pairs_hook=pairs, parse_constant=lambda value: (_ for _ in ()).throw(ValueError("NONFINITE_JSON:" + value)))


def git_blob(root: Path, commit: str, path: str) -> bytes | None:
    result = subprocess.run(["git", "cat-file", "-p", f"{commit}:{path}"], cwd=root, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    return result.stdout if result.returncode == 0 else None


def git_text(root: Path, *args: str) -> str:
    result = subprocess.run(["git", *args], cwd=root, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=False)
    if result.returncode:
        raise ValueError(result.stderr.strip() or "GIT_COMMAND_FAILED")
    return result.stdout.strip()


def line_set_sha(values: list[str]) -> str:
    return sha(("\n".join(sorted(set(values))) + "\n").encode())


def payload_sha(document: dict[str, Any]) -> str:
    body = dict(document); body.pop("record_payload_sha256", None)
    return sha((json.dumps(body, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode())


def canonical(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False) + "\n").encode()


def fingerprint(raw_failure: str, rule_id: str) -> str:
    return "V2F-" + sha(f"V076_RAW_FAILURE_V2\nHISTORICAL\n{rule_id}\n{raw_failure}\n".encode())


def load_committed_json(root: Path, commit: str, path: str) -> tuple[Any, bytes]:
    raw = git_blob(root, commit, path)
    if raw is None:
        raise ValueError(f"COMMITTED_BLOB_MISSING:{commit}:{path}")
    return strict(raw), raw


def component_map(registry: dict[str, Any]) -> dict[str, dict[str, Any]]:
    rows = registry.get("component_inventory")
    if not isinstance(rows, list):
        raise ValueError("REGISTRY_COMPONENT_INVENTORY_INVALID")
    result: dict[str, dict[str, Any]] = {}
    for row in rows:
        component_id = row.get("component_id") if isinstance(row, dict) else None
        if not isinstance(component_id, str) or component_id in result:
            raise ValueError("REGISTRY_COMPONENT_ROW_INVALID")
        result[component_id] = row
    return result


def raw_identity_map(raw_report: dict[str, Any]) -> dict[str, tuple[str, str, str]]:
    failures = raw_report.get("failures")
    if not isinstance(failures, list):
        raise ValueError("RAW_FAILURES_INVALID")
    result: dict[str, tuple[str, str, str]] = {}
    for item in failures:
        value = str(item)
        for rule_id in TARGET_RULES:
            if not value.startswith(rule_id + ":"):
                continue
            pieces = value.split(":", 2)
            if len(pieces) != 3:
                raise ValueError("RAW_FAILURE_SHAPE_INVALID:" + value)
            failure_fingerprint = fingerprint(value, rule_id)
            if failure_fingerprint in result:
                raise ValueError("RAW_FAILURE_FINGERPRINT_DUPLICATE:" + failure_fingerprint)
            result[failure_fingerprint] = (rule_id, value, pieces[2])
    return result


def component_snapshot(root: Path, commit: str, components: dict[str, dict[str, Any]], component_id: str) -> dict[str, Any]:
    row = components.get(component_id)
    if row is None:
        raise ValueError("COMPONENT_MISSING:" + component_id)
    path = row.get("path")
    if not isinstance(path, str) or not path or path.startswith("/"):
        raise ValueError("COMPONENT_PATH_INVALID:" + component_id)
    path_raw = git_blob(root, commit, path)
    if path_raw is None:
        raise ValueError(f"COMPONENT_BLOB_MISSING:{commit}:{path}")
    return {
        "component_id": component_id,
        "row": row,
        "row_sha256": sha(canonical(row)),
        "path": path,
        "path_blob_sha256": sha(path_raw),
        "domain_id": row.get("domain_id"),
        "owner_component_id": row.get("owner_component_id"),
        "production_reachable": row.get("production_reachable"),
    }


def expected_identity_projection(root: Path, binding_head: str, ledger: dict[str, Any]) -> tuple[dict[str, dict[str, Any]], dict[str, list[str]]]:
    raw_report, _ = load_committed_json(root, RAW_HEAD, RAW_PATH)
    current_registry, _ = load_committed_json(root, binding_head, REGISTRY_PATH)
    if not isinstance(raw_report, dict) or not isinstance(current_registry, dict):
        raise ValueError("COMMITTED_AUTHORITY_NOT_OBJECT")
    raw_identities = raw_identity_map(raw_report)
    current_components = component_map(current_registry)
    correction_bindings = ledger.get("correction_record_bindings")
    if not isinstance(correction_bindings, list) or len(correction_bindings) != 4:
        raise ValueError("PREDECESSOR_CORRECTION_BINDINGS_INVALID")
    expected: dict[str, dict[str, Any]] = {}
    ordered_by_correction: dict[str, list[str]] = {}
    for ledger_binding in correction_bindings:
        if not isinstance(ledger_binding, dict):
            raise ValueError("PREDECESSOR_CORRECTION_BINDING_INVALID")
        record_path = ledger_binding.get("path")
        predecessor, _ = load_committed_json(root, LEDGER_HEAD, str(record_path))
        if not isinstance(predecessor, dict):
            raise ValueError("PREDECESSOR_RECORD_NOT_OBJECT:" + str(record_path))
        source_commit = predecessor.get("source_commit")
        parent_commit = predecessor.get("parent_commit")
        if not isinstance(source_commit, str) or not re.fullmatch(r"[0-9a-f]{40}", source_commit):
            raise ValueError("PREDECESSOR_SOURCE_COMMIT_INVALID")
        if not isinstance(parent_commit, str) or not re.fullmatch(r"[0-9a-f]{40}", parent_commit):
            raise ValueError("PREDECESSOR_PARENT_COMMIT_INVALID")
        source_registry, _ = load_committed_json(root, source_commit, REGISTRY_PATH)
        if not isinstance(source_registry, dict):
            raise ValueError("SOURCE_REGISTRY_NOT_OBJECT")
        source_components = component_map(source_registry)
        fingerprints = predecessor.get("failure_fingerprints")
        if not isinstance(fingerprints, list) or len(fingerprints) != predecessor.get("failure_count"):
            raise ValueError("PREDECESSOR_FAILURE_LIST_INVALID")
        correction_id = str(ledger_binding.get("correction_id"))
        ordered_by_correction[correction_id] = sorted(str(value) for value in fingerprints)
        for failure_fingerprint in fingerprints:
            if not isinstance(failure_fingerprint, str) or failure_fingerprint not in raw_identities:
                raise ValueError("PREDECESSOR_FAILURE_NOT_IN_RAW:" + str(failure_fingerprint))
            rule_id, raw_failure, component_id = raw_identities[failure_fingerprint]
            source_component = component_snapshot(root, source_commit, source_components, component_id)
            current_component = component_snapshot(root, binding_head, current_components, component_id)
            source_owner_id = source_component.get("owner_component_id")
            current_owner_id = current_component.get("owner_component_id")
            if not isinstance(source_owner_id, str) or not isinstance(current_owner_id, str):
                raise ValueError("OWNER_COMPONENT_ID_INVALID:" + component_id)
            source_owner = component_snapshot(root, source_commit, source_components, source_owner_id)
            current_owner = component_snapshot(root, binding_head, current_components, current_owner_id)
            owner_rebound = source_owner["row_sha256"] != current_owner["row_sha256"]
            expected[failure_fingerprint] = {
                "failure_fingerprint": failure_fingerprint,
                "rule_id": rule_id,
                "raw_failure": raw_failure,
                "component_id": component_id,
                "source_commit": source_commit,
                "parent_commit": parent_commit,
                "source_component": source_component,
                "current_component": current_component,
                "source_owner": source_owner,
                "current_owner": current_owner,
                "classification": "REBOUND_OWNER" if owner_rebound else "PRESERVED_OWNER",
                "owner_rebound": owner_rebound,
                "classification_basis": "SOURCE_OWNER_ROW_SHA256_VS_CURRENT_OWNER_ROW_SHA256",
            }
    return expected, ordered_by_correction


def row_sha(row: dict[str, Any]) -> str:
    return sha((json.dumps(row, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode())


def registry_components(root: Path, commit: str) -> dict[str, dict[str, Any]]:
    raw = git_blob(root, commit, "docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json")
    if raw is None:
        raise ValueError("REGISTRY_BLOB_MISSING:" + commit)
    document = strict(raw)
    rows = document.get("component_inventory") if isinstance(document, dict) else None
    if not isinstance(rows, list):
        raise ValueError("REGISTRY_COMPONENT_INVENTORY_INVALID:" + commit)
    result: dict[str, dict[str, Any]] = {}
    for row in rows:
        if not isinstance(row, dict) or not isinstance(row.get("component_id"), str) or row["component_id"] in result:
            raise ValueError("REGISTRY_COMPONENT_ROW_INVALID:" + commit)
        result[row["component_id"]] = row
    return result


def snapshot_failures(root: Path, commit: str, expected_row: dict[str, Any], snapshot: Any, prefix: str) -> list[str]:
    failures: list[str] = []
    if not isinstance(snapshot, dict):
        return [prefix + "_SNAPSHOT_NOT_OBJECT"]
    path = expected_row.get("path")
    if snapshot.get("component_id") != expected_row.get("component_id") or snapshot.get("row") != expected_row or snapshot.get("row_sha256") != row_sha(expected_row):
        failures.append(prefix + "_ROW_BINDING_INVALID")
    if snapshot.get("path") != path or snapshot.get("domain_id") != expected_row.get("domain_id") or snapshot.get("owner_component_id") != expected_row.get("owner_component_id") or snapshot.get("production_reachable") != expected_row.get("production_reachable"):
        failures.append(prefix + "_FIELD_BINDING_INVALID")
    path_raw = git_blob(root, commit, str(path)) if isinstance(path, str) else None
    if path_raw is None or snapshot.get("path_blob_sha256") != sha(path_raw):
        failures.append(prefix + "_PATH_BLOB_INVALID")
    return failures


def audit(root: Path, manifest_path: Path) -> dict[str, Any]:
    failures: list[str] = []
    try:
        manifest_raw = manifest_path.read_bytes(); manifest = strict(manifest_raw)
    except Exception as exc:
        return {"status": "NO_GO", "failures": [str(exc)]}
    if not isinstance(manifest, dict):
        return {"status": "NO_GO", "failures": ["HDM2_MANIFEST_NOT_OBJECT"]}
    for key, expected in (("manifest_kind", EXPECTED_MANIFEST_KIND), ("schema_version", EXPECTED_SCHEMA), ("predecessor_ledger_path", LEDGER_PATH), ("predecessor_ledger_head_sha", LEDGER_HEAD), ("selector_policy", SELECTOR), ("future_failure_policy", FUTURE)):
        if manifest.get(key) != expected:
            failures.append("HDM2_MANIFEST_" + key.upper() + "_INVALID")
    if manifest.get("wildcard_count") != 0 or manifest.get("identity_count") != 86 or manifest.get("record_count") != 4:
        failures.append("HDM2_CARDINALITY_OR_WILDCARD_INVALID")
    current_head = str(manifest.get("current_binding_head_sha", ""))
    if not re.fullmatch(r"[0-9a-f]{40}", current_head):
        failures.append("HDM2_CURRENT_BINDING_HEAD_INVALID")
    else:
        tree = subprocess.run(["git", "rev-parse", f"{current_head}^{{tree}}"], cwd=root, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=False)
        if tree.returncode != 0 or tree.stdout.strip() != str(manifest.get("current_binding_tree_sha", "")):
            failures.append("HDM2_CURRENT_BINDING_TREE_INVALID")
    schema_path = root / str(manifest.get("schema_path", ""))
    if not schema_path.is_file() or sha(schema_path.read_bytes()) != manifest.get("schema_sha256"):
        failures.append("HDM2_SCHEMA_BYTES_INVALID")
    raw_report = git_blob(root, str(manifest.get("raw_report_head_sha", "")), str(manifest.get("raw_report_path", "")))
    if raw_report is None and manifest.get("raw_report_head_sha") == RAW_AUTHORITY_HEAD:
        raw_report = git_blob(root, RAW_MATERIALIZED_HEAD, str(manifest.get("raw_report_path", "")))
    if raw_report is None or sha(raw_report) != manifest.get("raw_report_sha256"):
        failures.append("HDM2_RAW_REPORT_BYTES_INVALID")
    if manifest.get("raw_report_tree_sha") != RAW_AUTHORITY_TREE or manifest.get("raw_report_materialized_head_sha") != RAW_MATERIALIZED_HEAD:
        failures.append("HDM2_RAW_REPORT_AUTHORITY_TUPLE_INVALID")
    authorities = manifest.get("predecessor_raw_authorities")
    if not isinstance(authorities, list) or len(authorities) != 1:
        failures.append("HDM2_PREDECESSOR_RAW_AUTHORITY_COUNT_INVALID")
    elif authorities[0].get("head_sha") != RAW_AUTHORITY_HEAD or authorities[0].get("tree_sha") != RAW_AUTHORITY_TREE or authorities[0].get("materialized_head_sha") != RAW_MATERIALIZED_HEAD:
        failures.append("HDM2_PREDECESSOR_RAW_AUTHORITY_INVALID")
    current_head = manifest.get("current_binding_head_sha")
    if not isinstance(current_head, str) or not re.fullmatch(r"[0-9a-f]{40}", current_head):
        failures.append("HDM2_BINDING_HEAD_INVALID")
        current_head = ""
    else:
        try:
            if manifest.get("current_binding_tree_sha") != git_text(root, "rev-parse", f"{current_head}^{{tree}}"):
                failures.append("HDM2_BINDING_TREE_INVALID")
        except Exception as exc:
            failures.append("HDM2_BINDING_TREE_READ_INVALID:" + str(exc))
    ledger_raw = git_blob(root, LEDGER_HEAD, LEDGER_PATH)
    ledger: dict[str, Any] = {}
    expected_predecessor_fps: set[str] = set()
    if ledger_raw is None or sha(ledger_raw) != manifest.get("predecessor_ledger_sha256"):
        failures.append("HDM2_PREDECESSOR_LEDGER_BYTES_INVALID")
    else:
        try:
            ledger = strict(ledger_raw)
            if manifest.get("predecessor_failure_count") != ledger.get("corrected_failure_count") or manifest.get("predecessor_failure_fingerprint_set_sha256") != ledger.get("failure_fingerprint_set_sha256"):
                failures.append("HDM2_PREDECESSOR_LEDGER_SUMMARY_INVALID")
            predecessor_bindings = ledger.get("correction_record_bindings")
            if not isinstance(predecessor_bindings, list) or len(predecessor_bindings) != 4:
                failures.append("HDM2_PREDECESSOR_BINDINGS_INVALID")
            else:
                for binding in predecessor_bindings:
                    if not isinstance(binding, dict) or not isinstance(binding.get("failure_fingerprints"), list):
                        failures.append("HDM2_PREDECESSOR_BINDING_INVALID"); continue
                    expected_predecessor_fps.update(str(value) for value in binding["failure_fingerprints"])
        except Exception as exc:
            failures.append("HDM2_PREDECESSOR_LEDGER_JSON_INVALID:" + str(exc))
    expected_identities: dict[str, dict[str, Any]] = {}
    expected_by_correction: dict[str, list[str]] = {}
    if ledger and current_head:
        try:
            expected_identities, expected_by_correction = expected_identity_projection(root, current_head, ledger)
        except Exception as exc:
            failures.append("HDM2_COMMITTED_PROJECTION_INVALID:" + str(exc))
    if len(expected_identities) != 86:
        failures.append("HDM2_COMMITTED_PROJECTION_CARDINALITY_INVALID")
    raw_bytes = git_blob(root, RAW_MATERIALIZED_HEAD, RAW_PATH)
    if (
        raw_bytes is None
        or sha(raw_bytes) != manifest.get("raw_report_sha256")
        or manifest.get("raw_report_path") != RAW_PATH
        or manifest.get("raw_report_head_sha") != RAW_AUTHORITY_HEAD
        or manifest.get("raw_report_tree_sha") != RAW_AUTHORITY_TREE
        or manifest.get("raw_report_materialized_head_sha") != RAW_MATERIALIZED_HEAD
    ):
        failures.append("HDM2_RAW_AUTHORITY_BINDING_INVALID")
    bindings = manifest.get("record_bindings")
    if not isinstance(bindings, list) or len(bindings) != 4:
        failures.append("HDM2_RECORD_BINDINGS_INVALID"); bindings = []
    previous = "0" * 64; all_fps: list[str] = []; rebound = preserved = 0
    try:
        current_components = registry_components(root, current_head)
    except Exception as exc:
        current_components = {}; failures.append("HDM2_CURRENT_REGISTRY_INVALID:" + str(exc))
    for index, binding in enumerate(bindings, 1):
        if not isinstance(binding, dict):
            failures.append(f"HDM2_RECORD_BINDING_NOT_OBJECT:{index}"); continue
        path = str(binding.get("path", "")); local = manifest_path.parent / "records" / Path(path).name
        if not local.is_file():
            local = root / path
        try:
            raw = local.read_bytes(); record = strict(raw)
        except Exception as exc:
            failures.append(f"HDM2_RECORD_READ_INVALID:{index}:{exc}"); continue
        if sha(raw) != binding.get("record_sha256"):
            failures.append(f"HDM2_RECORD_HASH_INVALID:{index}")
        if not isinstance(record, dict) or record.get("record_kind") != EXPECTED_RECORD_KIND or record.get("schema_version") != EXPECTED_RECORD_SCHEMA:
            failures.append(f"HDM2_RECORD_KIND_INVALID:{index}"); continue
        if record.get("record_payload_sha256") != binding.get("record_payload_sha256") or payload_sha(record) != record.get("record_payload_sha256"):
            failures.append(f"HDM2_RECORD_PAYLOAD_HASH_INVALID:{index}")
        if record.get("previous_record_payload_sha256") != previous or binding.get("previous_record_payload_sha256") != previous:
            failures.append(f"HDM2_RECORD_CHAIN_INVALID:{index}")
        previous = str(record.get("record_payload_sha256", ""))
        fps = record.get("failure_fingerprints")
        identities = record.get("identity_bindings")
        if not isinstance(fps, list) or not isinstance(identities, list) or len(fps) != len(identities) or record.get("failure_count") != len(fps):
            failures.append(f"HDM2_RECORD_IDENTITY_LIST_INVALID:{index}"); continue
        if fps != sorted(fps) or len(set(fps)) != len(fps) or any(not isinstance(fp, str) or not re.fullmatch(r"V2F-[0-9a-f]{64}", fp) for fp in fps):
            failures.append(f"HDM2_RECORD_FINGERPRINTS_INVALID:{index}")
        if record.get("failure_fingerprint_set_sha256") != line_set_sha(fps):
            failures.append(f"HDM2_RECORD_FINGERPRINT_SET_HASH_INVALID:{index}")
        if record.get("selector_policy") != SELECTOR or record.get("future_failure_policy") != FUTURE:
            failures.append(f"HDM2_RECORD_POLICY_INVALID:{index}")
        correction_id = str(record.get("predecessor_correction_id", ""))
        if binding.get("predecessor_correction_id") != correction_id or sorted(fps) != expected_by_correction.get(correction_id):
            failures.append(f"HDM2_PREDECESSOR_CORRECTION_MEMBERSHIP_INVALID:{index}")
        predecessor_path = str(record.get("predecessor_record_path", ""))
        predecessor_raw = git_blob(root, LEDGER_HEAD, predecessor_path)
        if predecessor_raw is None or sha(predecessor_raw) != record.get("predecessor_record_sha256"):
            failures.append(f"HDM2_PREDECESSOR_RECORD_BYTES_INVALID:{index}")
        else:
            predecessor = strict(predecessor_raw)
            if predecessor.get("record_payload_sha256") != record.get("predecessor_record_payload_sha256") or predecessor.get("correction_id") != record.get("predecessor_correction_id"):
                failures.append(f"HDM2_PREDECESSOR_RECORD_IDENTITY_INVALID:{index}")
            if isinstance(predecessor.get("failure_fingerprints"), list) and sorted(str(value) for value in predecessor["failure_fingerprints"]) != fps:
                failures.append(f"HDM2_PREDECESSOR_RECORD_FAILURE_SET_INVALID:{index}")
        source_commit = str(record.get("source_commit", ""))
        if record.get("current_binding_head_sha") != current_head or record.get("current_binding_tree_sha") != manifest.get("current_binding_tree_sha"):
            failures.append(f"HDM2_RECORD_CURRENT_HEAD_INVALID:{index}")
        if record.get("raw_report_head_sha") != RAW_AUTHORITY_HEAD or record.get("raw_report_tree_sha") != RAW_AUTHORITY_TREE:
            failures.append(f"HDM2_RECORD_RAW_AUTHORITY_INVALID:{index}")
        try:
            source_components = registry_components(root, source_commit)
        except Exception as exc:
            source_components = {}; failures.append(f"HDM2_SOURCE_REGISTRY_INVALID:{index}:{exc}")
        for identity in identities:
            if not isinstance(identity, dict) or identity.get("failure_fingerprint") not in fps:
                failures.append(f"HDM2_IDENTITY_BINDING_INVALID:{index}"); continue
            cls = identity.get("classification")
            if cls == "REBOUND_OWNER": rebound += 1
            elif cls == "PRESERVED_OWNER": preserved += 1
            else: failures.append(f"HDM2_IDENTITY_CLASSIFICATION_INVALID:{index}")
            if identity.get("owner_rebound") is not (cls == "REBOUND_OWNER"):
                failures.append(f"HDM2_IDENTITY_OWNER_FLAG_INVALID:{index}")
            expected_identity = expected_identities.get(str(identity.get("failure_fingerprint")))
            if expected_identity is None or identity != expected_identity:
                failures.append(f"HDM2_COMMITTED_IDENTITY_PROJECTION_DRIFT:{index}")
            rule = str(identity.get("rule_id", "")); raw_failure = str(identity.get("raw_failure", "")); component_id = str(identity.get("component_id", ""))
            parts = raw_failure.split(":", 2)
            if fingerprint(raw_failure, rule) != identity.get("failure_fingerprint") or len(parts) != 3 or parts[2] != component_id or not raw_failure.startswith(rule + ":"):
                failures.append(f"HDM2_IDENTITY_RAW_BINDING_INVALID:{index}")
            source_row = source_components.get(component_id); current_row = current_components.get(component_id)
            if source_row is None or current_row is None:
                failures.append(f"HDM2_IDENTITY_COMPONENT_MISSING:{index}")
            else:
                failures.extend(snapshot_failures(root, source_commit, source_row, identity.get("source_component"), f"HDM2_SOURCE_COMPONENT:{index}"))
                failures.extend(snapshot_failures(root, current_head, current_row, identity.get("current_component"), f"HDM2_CURRENT_COMPONENT:{index}"))
                source_owner_id = str(source_row.get("owner_component_id", "")); current_owner_id = str(current_row.get("owner_component_id", ""))
                source_owner_row = source_components.get(source_owner_id); current_owner_row = current_components.get(current_owner_id)
                if source_owner_row is None or current_owner_row is None:
                    failures.append(f"HDM2_IDENTITY_OWNER_MISSING:{index}")
                else:
                    failures.extend(snapshot_failures(root, source_commit, source_owner_row, identity.get("source_owner"), f"HDM2_SOURCE_OWNER:{index}"))
                    failures.extend(snapshot_failures(root, current_head, current_owner_row, identity.get("current_owner"), f"HDM2_CURRENT_OWNER:{index}"))
            source = identity.get("source_owner"); current = identity.get("current_owner")
            if not isinstance(source, dict) or not isinstance(current, dict):
                failures.append(f"HDM2_IDENTITY_OWNER_SNAPSHOT_INVALID:{index}")
            elif cls == "PRESERVED_OWNER" and source.get("row_sha256") != current.get("row_sha256"):
                failures.append(f"HDM2_PRESERVED_OWNER_DRIFT:{index}")
            elif cls == "REBOUND_OWNER" and source.get("row_sha256") == current.get("row_sha256"):
                failures.append(f"HDM2_REBOUND_OWNER_NOT_DIFFERENT:{index}")
            all_fps.append(str(identity.get("failure_fingerprint")))
        if record.get("rebound_count") + record.get("preserved_count") != record.get("failure_count"):
            failures.append(f"HDM2_RECORD_CLASSIFICATION_TOTAL_INVALID:{index}")
    if previous != manifest.get("record_chain_terminal_sha256"):
        failures.append("HDM2_RECORD_CHAIN_TERMINAL_INVALID")
    if len(all_fps) != 86 or len(set(all_fps)) != 86 or sorted(all_fps) != manifest.get("identity_fingerprints") or set(all_fps) != expected_predecessor_fps:
        failures.append("HDM2_GLOBAL_IDENTITY_SET_INVALID")
    if manifest.get("identity_fingerprint_set_sha256") != line_set_sha(all_fps):
        failures.append("HDM2_GLOBAL_IDENTITY_SET_HASH_INVALID")
    if rebound != 52 or preserved != 34 or manifest.get("rebound_count") != rebound or manifest.get("preserved_count") != preserved:
        failures.append("HDM2_GLOBAL_CLASSIFICATION_INVALID")
    committed_projection = [
        expected_identities[fingerprint]
        for fingerprint in sorted(expected_identities)
    ]
    return {
        "status": "PASS" if not failures else "NO_GO",
        "failures": sorted(set(failures)),
        "identity_count": len(all_fps),
        "rebound_count": rebound,
        "preserved_count": preserved,
        "record_count": len(bindings),
        "authority_projection_sha256": sha(canonical(committed_projection)),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path.cwd())
    parser.add_argument("--manifest", type=Path, required=True)
    args = parser.parse_args(argv)
    result = audit(args.project.resolve(), args.manifest.resolve())
    print(json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2))
    return 0 if result.get("status") == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
