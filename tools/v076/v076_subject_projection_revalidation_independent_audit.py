#!/usr/bin/env python3
"""Independent audit for Registry-only subject-projection revalidation.

This module intentionally does not import the primary revalidation validator.
It rebuilds every Git and projection fact from repository objects and accepts
only the sealed 7de7b95e Registry metadata transition.  It never grants trust
for BLOB_CHANGED_CORRECTION_INVALID or TOUCHED_CORRECTION_INVALID.
"""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
from pathlib import Path, PurePosixPath
from typing import Any, Iterable


AUTHORIZATION_ID = "USER_AUTHORIZATION_V076_REUSE_FULL_CONVERGENCE_AND_MCP_ONLY_20260827"
AUTHORIZATION_BASE_HEAD = "d701a81dce693b584d52fbfca3e0e78b521ad775"
SCHEMA_VERSION = "space_syndicate.v076.reuse_exact_failure_correction.v2.subject_projection_revalidation_schema.v1"
MANIFEST_SCHEMA_VERSION = "space_syndicate.v076.reuse_exact_failure_correction.v2.subject_projection_revalidation_manifest.v1"
RECORD_SCHEMA_VERSION = "space_syndicate.v076.reuse_exact_failure_correction.v2.subject_projection_revalidation_record.v1"
PRIOR_EPOCH_ID = "FULL_CONVERGENCE_20260827"
CHANGE_COMMIT = "7de7b95e6b26d755d9ccaacbf483e57a949504da"
CHANGE_PARENT = "864cb731fd68af0f48e29fd78b650ad726293103"
REGISTRY_PATH = "docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json"
SUPERSESSION_PATH = "docs/architecture/V076_SUPERSESSION_MAP.json"
OWNER_MAP_PATH = "docs/architecture/V076_OWNER_REUSE_MAP.md"
DYNAMIC_REFERENCE_PATH = "docs/architecture/V076_DYNAMIC_REFERENCE_MANIFEST.json"
SCHEMA_PATH = "docs/architecture/reuse_corrections/v2/schema_subject_projection_revalidation_20260828.json"
SCHEMA_SHA256 = "1c1a5eeaa786ef8ccaf87badaf7ef3009acf398be4f55cb636fd7060453f6c22"
LEDGER_PATH = "docs/architecture/V076_HISTORICAL_DELTA_METADATA_LEDGER.json"
LEDGER_SHA256 = "2bbcba050fd8c8f7027bd762d80c1187b29742dec81034c3f3eecc456eaa075d"
HDM_REUSE_SCAN_PATH = (
    "docs/architecture/reuse_corrections/v2/records/full_convergence_20260827/"
    "historical_delta_metadata/v2-hdm-20260827-5af52a5b-authority-reuse-scan.json"
)
HDM_IDENTITY_RECORDS = {
    "docs/architecture/reuse_corrections/v2/records/full_convergence_20260827/"
    "historical_delta_metadata/v2-hdm-20260827-488c21f5-component-identity.json":
        "V2-HDM-20260827-488C21F5-COMPONENT-IDENTITY",
    "docs/architecture/reuse_corrections/v2/records/full_convergence_20260827/"
    "historical_delta_metadata/v2-hdm-20260827-5af52a5b-component-identity.json":
        "V2-HDM-20260827-5AF52A5B-COMPONENT-IDENTITY",
    "docs/architecture/reuse_corrections/v2/records/full_convergence_20260827/"
    "historical_delta_metadata/v2-hdm-20260827-8e6ce3e6-component-identity.json":
        "V2-HDM-20260827-8E6CE3E6-COMPONENT-IDENTITY",
}
HDM_REUSE_SCAN_ID = "V2-HDM-20260827-5AF52A5B-AUTHORITY-REUSE-SCAN"
FULL_RECORD_ROOT = "docs/architecture/reuse_corrections/v2/records/full_convergence_20260827/"
FULL_BATCH_ROOT = "docs/architecture/reuse_corrections/v2/batches/full_convergence_20260827/"
CURRENT_BATCH_PATH = FULL_BATCH_ROOT + "batch-007/batch-007-manifest.json"
MANIFEST_ROOT = "docs/architecture/reuse_corrections/v2/subject_projection_revalidation/"
REVALIDATION_RECORD_ROOT = MANIFEST_ROOT + "records/"
RECORD_KIND = "SUBJECT_PROJECTION_REVALIDATION_RECORD"
MANIFEST_KIND = "SUBJECT_PROJECTION_REVALIDATION_MANIFEST"
ALLOWED_INVALIDATION = "SUBJECT_PROJECTION_CHANGED_INVALID"
IDENTITY_RULE = "NEW_COMPONENT_CANNOT_CLAIM_INHERITED"
REUSE_RULE = "HISTORY_NEW_AUTHORITY_REUSE_SCAN_INVALID"
MANIFEST_FIELDS = frozenset("""schema_version manifest_kind manifest_id authorization_id authorization_base_head_sha schema_path schema_sha256 prior_epoch_id revalidation_binding_head_sha revalidation_binding_tree_sha current_batch_manifest_path current_batch_manifest_sha256 authority_source_path authority_source_change_commit_sha authority_source_change_parent_sha authority_source_before_blob_sha256 authority_source_after_blob_sha256 authority_source_diff_sha256 authority_source_changed_path_count historical_delta_metadata_ledger_path historical_delta_metadata_ledger_sha256 record_count failure_fingerprints failure_fingerprint_set_sha256 change_class_only_count change_class_reuse_scan_count record_bindings record_chain_start_sha256 record_chain_terminal_sha256 allowed_invalidation future_failure_auto_revalidation wildcard_count created_at creator""".split())
RECORD_FIELDS = frozenset("""schema_version record_kind revalidation_id authorization_id authorization_base_head_sha prior_epoch_id failure_fingerprints failure_fingerprint_set_sha256 prior_invalidations prior_record_path prior_record_sha256 prior_record_payload_sha256 prior_correction_id correction_batch_manifest_path correction_batch_manifest_sha256 prior_binding_head_sha prior_binding_tree_sha revalidation_binding_head_sha revalidation_binding_tree_sha authority_selectors authority_selector_sha256 component_id change_profile changed_metadata_fields touch_proof prior_subject_projection prior_subject_projection_sha256 rebound_subject_projection rebound_subject_projection_sha256 bound_product_blob_sha256_by_path component_identity_hdm_authority reuse_scan_hdm_authority future_failure_policy wildcard_count new_effective_status previous_revalidation_chain_sha256 created_at creator revalidation_reason record_payload_sha256""".split())
MANIFEST_BINDING_FIELDS = frozenset("""path record_sha256 record_payload_sha256 revalidation_id prior_record_path prior_record_sha256 prior_record_payload_sha256 prior_correction_id failure_fingerprints previous_revalidation_chain_sha256""".split())
HDM_BINDING_FIELDS = frozenset("""authority_kind correction_id path file_sha256 record_payload_sha256 failure_fingerprint rule_id""".split())
TOUCH_FIELDS = frozenset("""commit_sha parent_sha path before_blob_sha256 after_blob_sha256 diff_sha256""".split())
SCHEMA_FIELDS = frozenset({
    "schema_version", "manifest_schema_version", "record_schema_version",
    "manifest_kind", "record_kind", "authorization_id",
    "authorization_base_head_sha", "prior_epoch_id", "authority_source_path",
    "authority_source_change_commit_sha", "authority_source_change_parent_sha",
    "allowed_invalidation", "record_fingerprint_cardinality", "record_count",
    "change_class_only_count", "change_class_reuse_scan_count",
    "authorized_metadata_change_profiles", "reuse_scan_authorized_component_ids",
    "manifest_required_fields", "record_required_fields",
    "manifest_record_binding_fields", "touch_proof_fields",
    "hdm_authority_binding_fields", "projection_sections",
    "future_failure_policy", "wildcard_count", "future_failure_auto_revalidation",
})
FUTURE_POLICY = {
    "FUTURE_FAILURE_AUTO_REVALIDATION_COUNT": 0,
    "NEW_FAILURE_REQUIRES_NEW_RECORD": True,
}
PROFILE_FIELDS = {
    "CHANGE_CLASS_ONLY": ["change_class"],
    "CHANGE_CLASS_AND_REUSE_SCAN": ["change_class", "reuse_scan"],
}

REUSE_SCAN_COMPONENTS = frozenset({
    "component.current.card_flow_policy_v06",
    "component.current.card_flow_transaction_service_v06",
    "component.current.card_player_state_port_v06",
    "component.current.global_supply_demand_runtime_service_v06",
})


class DuplicateKeyError(ValueError):
    pass


def _strict_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise DuplicateKeyError(key)
        result[key] = value
    return result


def strict_json_bytes(payload: bytes) -> Any:
    return json.loads(payload.decode("utf-8-sig"), object_pairs_hook=_strict_pairs)


def strict_json_file(path: Path) -> Any:
    return strict_json_bytes(path.read_bytes())


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode()


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def line_set_sha(values: Iterable[str]) -> str:
    return sha256_bytes(("\n".join(sorted(str(x) for x in values)) + "\n").encode())


def _schema_contract_failures(document: Any, raw: bytes) -> list[str]:
    """Independently lock the complete schema semantics and exact byte seal."""

    if not isinstance(document, dict):
        return ["SPR_SCHEMA_NOT_OBJECT"]
    failures: list[str] = []
    if sha256_bytes(raw) != SCHEMA_SHA256:
        failures.append("SPR_SCHEMA_BYTE_SEAL_INVALID")
    if set(document) != set(SCHEMA_FIELDS):
        failures.append("SPR_SCHEMA_FIELD_SET_INVALID")
    expected = {
        "schema_version": SCHEMA_VERSION,
        "manifest_schema_version": MANIFEST_SCHEMA_VERSION,
        "record_schema_version": RECORD_SCHEMA_VERSION,
        "manifest_kind": MANIFEST_KIND,
        "record_kind": RECORD_KIND,
        "authorization_id": AUTHORIZATION_ID,
        "authorization_base_head_sha": AUTHORIZATION_BASE_HEAD,
        "prior_epoch_id": PRIOR_EPOCH_ID,
        "authority_source_path": REGISTRY_PATH,
        "authority_source_change_commit_sha": CHANGE_COMMIT,
        "authority_source_change_parent_sha": CHANGE_PARENT,
        "allowed_invalidation": ALLOWED_INVALIDATION,
        "record_fingerprint_cardinality": "ONE_EXACT_FINGERPRINT_PER_RECORD",
        "record_count": 82,
        "change_class_only_count": 78,
        "change_class_reuse_scan_count": 4,
        "authorized_metadata_change_profiles": PROFILE_FIELDS,
        "reuse_scan_authorized_component_ids": sorted(REUSE_SCAN_COMPONENTS),
        "projection_sections": [
            "dynamic_reference_rows", "owner_map_lines", "registry_rows",
            "supersession_rows",
        ],
        "future_failure_policy": FUTURE_POLICY,
        "wildcard_count": 0,
        "future_failure_auto_revalidation": False,
    }
    for key, value in expected.items():
        if document.get(key) != value:
            failures.append(f"SPR_SCHEMA_VALUE_INVALID:{key}")
    for key, expected_fields in (
        ("manifest_required_fields", MANIFEST_FIELDS),
        ("record_required_fields", RECORD_FIELDS),
        ("manifest_record_binding_fields", MANIFEST_BINDING_FIELDS),
        ("touch_proof_fields", TOUCH_FIELDS),
        ("hdm_authority_binding_fields", HDM_BINDING_FIELDS),
    ):
        actual = document.get(key)
        if (
            not isinstance(actual, list)
            or len(actual) != len(set(actual))
            or set(actual) != set(expected_fields)
        ):
            failures.append(f"SPR_SCHEMA_REQUIRED_FIELDS_INVALID:{key}")
    return sorted(set(failures))


def _git(root: Path, *args: str, binary: bool = False) -> bytes | str:
    result = subprocess.run(
        ["git", "-C", str(root), *args], stdout=subprocess.PIPE,
        stderr=subprocess.PIPE, check=False,
    )
    if result.returncode:
        raise ValueError(result.stderr.decode("utf-8", "replace").strip())
    return result.stdout if binary else result.stdout.decode("utf-8", "replace").strip()


def _blob(root: Path, commit: str, path: str) -> bytes | None:
    try:
        return _git(root, "cat-file", "blob", f"{commit}:{path}", binary=True)  # type: ignore[return-value]
    except ValueError:
        return None


def _exact_path(value: Any) -> bool:
    if not isinstance(value, str) or not value or "\\" in value or ":" in value:
        return False
    if any(c in value for c in "*?[]") or value.startswith("/") or value.endswith("/"):
        return False
    parts = PurePosixPath(value).parts
    return bool(parts) and all(p not in ("", ".", "..") for p in parts) and "/".join(parts) == value


def _exact_selector(selector: Any) -> bool:
    if not isinstance(selector, dict):
        return False
    allowed = {"component_ids", "paths", "dynamic_reference_ids", "supersession_ids", "retirement_ids"}
    if set(selector) != allowed:
        return False
    for key, values in selector.items():
        if not isinstance(values, list) or values != sorted(values) or len(values) != len(set(values)):
            return False
        for value in values:
            if not isinstance(value, str) or not value or any(c in value for c in "*?[]"):
                return False
            if key == "paths" and not _exact_path(value):
                return False
    return bool(selector["component_ids"] or selector["paths"])


def _selector_matches_prior(receipt: Any, prior: Any) -> bool:
    return _exact_selector(receipt) and isinstance(prior, dict) and receipt == prior.get("authority_selectors")


def _nonregistry_surfaces_unchanged(old: dict[str, Any], new: dict[str, Any]) -> bool:
    return all(old.get(key) == new.get(key) for key in ("dynamic_reference_rows", "owner_map_lines", "supersession_rows"))


def _bijective_component_coverage(values: Iterable[str], authorized: set[str]) -> bool:
    rendered = [str(value) for value in values]
    return len(rendered) == 82 and len(set(rendered)) == 82 and set(rendered) == authorized


def _changed_paths(root: Path, old: str, new: str) -> list[str]:
    text = _git(root, "diff", "--name-only", old, new)
    return [x for x in str(text).splitlines() if x]


def _touches(root: Path, old: str, new: str, path: str) -> list[str]:
    text = _git(root, "rev-list", "--reverse", f"{old}..{new}", "--", path)
    return [x for x in str(text).splitlines() if x]


def _registry_rows(document: Any) -> dict[str, dict[str, Any]]:
    if not isinstance(document, dict) or not isinstance(document.get("component_inventory"), list):
        raise ValueError("registry shape")
    rows: dict[str, dict[str, Any]] = {}
    for row in document["component_inventory"]:
        if not isinstance(row, dict) or not isinstance(row.get("component_id"), str):
            raise ValueError("registry row")
        component_id = row["component_id"]
        if component_id in rows:
            raise ValueError("duplicate component")
        rows[component_id] = row
    return rows


def _audit_hdm_record(root: Path, relative: str, expected_id: str, *, authority_head: str) -> tuple[dict[str, Any], list[str]]:
    failures: list[str] = []
    try:
        committed = _blob(root, authority_head, relative)
        if committed is None:
            raise ValueError("missing committed HDM")
        document = strict_json_bytes(committed)
    except (OSError, ValueError, json.JSONDecodeError, DuplicateKeyError):
        return {}, [f"SPR_HDM_UNREADABLE:{relative}"]
    if not isinstance(document, dict):
        return {}, [f"SPR_HDM_NOT_OBJECT:{relative}"]
    if document.get("correction_id") != expected_id:
        failures.append(f"SPR_HDM_ID_MISMATCH:{relative}")
    payload = {key: value for key, value in document.items() if key != "record_payload_sha256"}
    if document.get("record_payload_sha256") != sha256_bytes(canonical_bytes(payload)):
        failures.append(f"SPR_HDM_PAYLOAD_MISMATCH:{relative}")
    if document.get("authorization_id") != AUTHORIZATION_ID:
        failures.append(f"SPR_HDM_AUTHORIZATION_MISMATCH:{relative}")
    components = document.get("component_ids")
    if (
        not isinstance(components, list)
        or components != sorted(components)
        or len(components) != len(set(components))
        or document.get("component_set_sha256") != line_set_sha(components)
    ):
        failures.append(f"SPR_HDM_COMPONENT_MEMBERSHIP_INVALID:{relative}")
    return document, failures


def audit_authority_change(root: Path, *, authority_head: str | None = None) -> tuple[dict[str, set[str]], list[str]]:
    """Independently prove the sealed 78+4 Registry-only transition."""
    failures: list[str] = []
    if authority_head is None:
        authority_head = str(_git(root, "rev-parse", "HEAD"))
    try:
        parent = str(_git(root, "rev-parse", f"{CHANGE_COMMIT}^1"))
        if parent != CHANGE_PARENT:
            failures.append("SPR_CHANGE_PARENT_MISMATCH")
        if _changed_paths(root, CHANGE_PARENT, CHANGE_COMMIT) != [REGISTRY_PATH]:
            failures.append("SPR_CHANGE_NOT_REGISTRY_ONLY")
        before_raw = _blob(root, CHANGE_PARENT, REGISTRY_PATH)
        after_raw = _blob(root, CHANGE_COMMIT, REGISTRY_PATH)
        if before_raw is None or after_raw is None:
            raise ValueError("registry blob missing")
        before = _registry_rows(strict_json_bytes(before_raw))
        after = _registry_rows(strict_json_bytes(after_raw))
    except (OSError, ValueError, json.JSONDecodeError, DuplicateKeyError):
        return {}, ["SPR_CHANGE_UNRESOLVED"]
    if set(before) != set(after):
        failures.append("SPR_REGISTRY_COMPONENT_SET_CHANGED")
    by_fields: dict[str, set[str]] = {"change_class_only": set(), "change_class_reuse_scan": set()}
    for component_id in sorted(set(before) | set(after)):
        old, new = before.get(component_id), after.get(component_id)
        if old == new:
            continue
        if not isinstance(old, dict) or not isinstance(new, dict):
            failures.append(f"SPR_REGISTRY_ROW_ADDED_OR_REMOVED:{component_id}")
            continue
        changed = {key for key in set(old) | set(new) if old.get(key) != new.get(key)}
        if changed == {"change_class"}:
            by_fields["change_class_only"].add(component_id)
        elif changed == {"change_class", "reuse_scan"}:
            by_fields["change_class_reuse_scan"].add(component_id)
        else:
            failures.append(f"SPR_REGISTRY_UNAUTHORIZED_FIELDS:{component_id}")
    if len(by_fields["change_class_only"]) != 78:
        failures.append("SPR_CHANGE_CLASS_ONLY_COUNT_MISMATCH")
    if by_fields["change_class_reuse_scan"] != set(REUSE_SCAN_COMPONENTS):
        failures.append("SPR_REUSE_SCAN_COMPONENT_SET_MISMATCH")
    identity_membership: set[str] = set()
    for relative, expected_id in HDM_IDENTITY_RECORDS.items():
        document, record_failures = _audit_hdm_record(root, relative, expected_id, authority_head=authority_head)
        failures.extend(record_failures)
        components = document.get("component_ids", []) if isinstance(document, dict) else []
        overlap = identity_membership & set(components)
        if overlap:
            failures.append(f"SPR_HDM_IDENTITY_MEMBERSHIP_OVERLAP:{relative}")
        identity_membership.update(str(value) for value in components)
    changed_membership = by_fields["change_class_only"] | by_fields["change_class_reuse_scan"]
    if identity_membership != changed_membership:
        failures.append("SPR_HDM_IDENTITY_MEMBERSHIP_NOT_EXACT_82")
    try:
        hdm, hdm_failures = _audit_hdm_record(root, HDM_REUSE_SCAN_PATH, HDM_REUSE_SCAN_ID, authority_head=authority_head)
        failures.extend(hdm_failures)
        hdm_components = set(hdm.get("component_ids", [])) if isinstance(hdm, dict) else set()
        if hdm_components != set(REUSE_SCAN_COMPONENTS):
            failures.append("SPR_HDM_REUSE_SCAN_COMPONENT_SET_MISMATCH")
        if not isinstance(hdm, dict) or hdm.get("authorization_id") != AUTHORIZATION_ID:
            failures.append("SPR_HDM_AUTHORITY_INVALID")
        if hdm.get("component_set_sha256") != line_set_sha(REUSE_SCAN_COMPONENTS):
            failures.append("SPR_HDM_COMPONENT_HASH_MISMATCH")
        if hdm.get("future_failure_policy") != {"automatic_match": False, "new_failure_requires_new_record": True}:
            failures.append("SPR_HDM_FUTURE_POLICY_INVALID")
    except (OSError, ValueError, json.JSONDecodeError, DuplicateKeyError):
        failures.append("SPR_HDM_REUSE_SCAN_UNREADABLE")
    return by_fields, sorted(set(failures))


def _json_at(root: Path, commit: str, path: str) -> Any:
    payload = _blob(root, commit, path)
    if payload is None:
        raise ValueError(path)
    return strict_json_bytes(payload)


def _projection(root: Path, commit: str, selector: dict[str, Any]) -> dict[str, Any]:
    """Independent equivalent of the formal four-authority projection."""
    if not _exact_selector(selector):
        raise ValueError("selector")
    registry = _json_at(root, commit, REGISTRY_PATH)
    supersession = _json_at(root, commit, SUPERSESSION_PATH)
    dynamic = _json_at(root, commit, DYNAMIC_REFERENCE_PATH)
    owner_payload = _blob(root, commit, OWNER_MAP_PATH)
    if owner_payload is None or not isinstance(registry, dict) or not isinstance(supersession, dict) or not isinstance(dynamic, dict):
        raise ValueError("authority")
    component_ids = set(selector["component_ids"]); paths = set(selector["paths"])
    registry_candidates: list[dict[str, Any]] = []
    for source_kind in ("component_inventory", "historical_identity_backfill"):
        values = registry.get(source_kind, [])
        if isinstance(values, list):
            for value in values:
                if isinstance(value, dict):
                    tagged = dict(value); tagged["authority_source_kind"] = source_kind
                    registry_candidates.append(tagged)
    registry_rows = [row for row in registry_candidates if row.get("component_id") in component_ids or row.get("path") in paths]
    supersession_ids = set(selector["supersession_ids"]); retirement_ids = set(selector["retirement_ids"])
    supersession_rows = []
    for key in ("entries", "retirement_entries"):
        values = supersession.get(key, [])
        if isinstance(values, list):
            supersession_rows.extend(row for row in values if isinstance(row, dict) and
                (row.get("supersession_id") in supersession_ids or row.get("retirement_id") in retirement_ids))
    dynamic_ids = set(selector["dynamic_reference_ids"])
    entries = dynamic.get("entries", [])
    dynamic_rows = [row for row in entries if isinstance(row, dict) and row.get("dynamic_reference_id") in dynamic_ids] if isinstance(entries, list) else []
    needles = sorted({str(value) for values in selector.values() for value in values if value})
    owner_lines = sorted({line.rstrip() for line in owner_payload.decode("utf-8-sig", "replace").splitlines() if any(n in line for n in needles)})
    result = {
        "dynamic_reference_rows": sorted(dynamic_rows, key=canonical_bytes),
        "owner_map_lines": owner_lines,
        "registry_rows": sorted(registry_rows, key=canonical_bytes),
        "supersession_rows": sorted(supersession_rows, key=canonical_bytes),
    }
    if not any(result.values()):
        raise ValueError("unresolved selector")
    return result


def _prior_record_membership(root: Path, record: dict[str, Any], fingerprint: str, *, evaluated_head: str) -> list[str]:
    failures: list[str] = []
    prior_path = record.get("prior_record_path")
    batch_path = record.get("correction_batch_manifest_path")
    if not _exact_path(prior_path) or not str(prior_path).startswith(FULL_RECORD_ROOT):
        return ["SPR_PRIOR_RECORD_PATH_INVALID"]
    if not _exact_path(batch_path) or not str(batch_path).startswith(FULL_BATCH_ROOT):
        return ["SPR_PRIOR_BATCH_PATH_INVALID"]
    try:
        prior_raw = _blob(root, evaluated_head, str(prior_path))
        batch_raw = _blob(root, evaluated_head, str(batch_path))
        if prior_raw is None or batch_raw is None:
            raise ValueError("missing committed prior authority")
        prior = strict_json_bytes(prior_raw)
        batch = strict_json_bytes(batch_raw)
    except (OSError, ValueError, json.JSONDecodeError, DuplicateKeyError):
        return ["SPR_PRIOR_AUTHORITY_UNREADABLE"]
    if sha256_bytes(prior_raw) != record.get("prior_record_sha256"):
        failures.append("SPR_PRIOR_RECORD_SHA_MISMATCH")
    if not isinstance(prior, dict) or prior.get("record_payload_sha256") != record.get("prior_record_payload_sha256"):
        failures.append("SPR_PRIOR_PAYLOAD_MISMATCH")
    if not isinstance(prior, dict) or prior.get("correction_id") != record.get("prior_correction_id"):
        failures.append("SPR_PRIOR_CORRECTION_ID_MISMATCH")
    if sha256_bytes(batch_raw) != record.get("correction_batch_manifest_sha256"):
        failures.append("SPR_PRIOR_BATCH_SHA_MISMATCH")
    matches = []
    if isinstance(batch, dict):
        for binding in batch.get("record_bindings", []):
            if isinstance(binding, dict) and binding.get("path") == prior_path and fingerprint in binding.get("failure_fingerprints", []):
                matches.append(binding)
    if len(matches) != 1:
        failures.append("SPR_PRIOR_BATCH_MEMBERSHIP_NOT_EXACT")
    return failures


def _committed_document(root: Path, evaluated_head: str, relative: str) -> tuple[dict[str, Any], bytes]:
    if not _exact_path(relative):
        raise ValueError("path")
    payload = _blob(root, evaluated_head, relative)
    if payload is None:
        raise ValueError("missing")
    value = strict_json_bytes(payload)
    if not isinstance(value, dict):
        raise ValueError("object")
    return value, payload


def _hdm_binding_failures(root: Path, evaluated_head: str, binding: Any, component_id: str,
                          *, reuse_scan: bool) -> list[str]:
    failures: list[str] = []
    if not isinstance(binding, dict):
        return ["SPR_HDM_BINDING_NOT_OBJECT"]
    required = {"authority_kind", "correction_id", "path", "file_sha256", "record_payload_sha256",
                "failure_fingerprint", "rule_id"}
    if set(binding) != required:
        failures.append("SPR_HDM_BINDING_FIELD_SET_INVALID")
    expected_paths = {HDM_REUSE_SCAN_PATH} if reuse_scan else set(HDM_IDENTITY_RECORDS)
    path = binding.get("path")
    if path not in expected_paths:
        return failures + ["SPR_HDM_BINDING_PATH_INVALID"]
    expected_id = HDM_REUSE_SCAN_ID if reuse_scan else HDM_IDENTITY_RECORDS[str(path)]
    try:
        document, payload = _committed_document(root, evaluated_head, str(path))
    except Exception:
        return failures + ["SPR_HDM_BINDING_AUTHORITY_UNREADABLE"]
    if binding.get("file_sha256") != sha256_bytes(payload): failures.append("SPR_HDM_BINDING_FILE_SHA_INVALID")
    if binding.get("correction_id") != expected_id or document.get("correction_id") != expected_id: failures.append("SPR_HDM_BINDING_ID_INVALID")
    if binding.get("record_payload_sha256") != document.get("record_payload_sha256"): failures.append("SPR_HDM_BINDING_PAYLOAD_INVALID")
    if component_id not in document.get("component_ids", []): failures.append("SPR_HDM_BINDING_COMPONENT_NOT_MEMBER")
    if binding.get("failure_fingerprint") not in document.get("failure_fingerprints", []): failures.append("SPR_HDM_BINDING_FINGERPRINT_NOT_MEMBER")
    if binding.get("rule_id") != document.get("rule_id"): failures.append("SPR_HDM_BINDING_RULE_INVALID")
    return failures


def _expected_hdm_binding(
    document: dict[str, Any], raw: bytes, path: str, fingerprint: str
) -> dict[str, Any]:
    return {
        "authority_kind": document.get("transition_class_id"),
        "correction_id": document.get("correction_id"),
        "path": path,
        "file_sha256": sha256_bytes(raw),
        "record_payload_sha256": document.get("record_payload_sha256"),
        "failure_fingerprint": fingerprint,
        "rule_id": document.get("rule_id"),
    }


def _ledger_hdm_authority(
    root: Path, evaluated_head: str
) -> tuple[dict[str, Any], list[str]]:
    """Rebuild exact component-to-HDM authority from the committed ledger."""

    result: dict[str, Any] = {
        "identity_by_component": {},
        "reuse_by_component": {},
        "identity_fingerprints": set(),
    }
    failures: list[str] = []
    try:
        ledger, ledger_raw = _committed_document(root, evaluated_head, LEDGER_PATH)
    except Exception:
        return result, ["SPR_LEDGER_COMMITTED_BYTES_INVALID"]
    if sha256_bytes(ledger_raw) != LEDGER_SHA256:
        failures.append("SPR_LEDGER_SHA_INVALID")
    if (
        ledger.get("authorization_id") != AUTHORIZATION_ID
        or ledger.get("ledger_id") != "V076_HISTORICAL_DELTA_METADATA_LEDGER"
    ):
        failures.append("SPR_LEDGER_AUTHORITY_INVALID")
    payload = {key: value for key, value in ledger.items() if key != "ledger_payload_sha256"}
    if ledger.get("ledger_payload_sha256") != sha256_bytes(canonical_bytes(payload)):
        failures.append("SPR_LEDGER_PAYLOAD_INVALID")

    sources: dict[tuple[str, str], dict[str, Any]] = {}
    source_fingerprints: set[str] = set()
    metadata_records = ledger.get("records", [])
    if not isinstance(metadata_records, list):
        metadata_records = []
        failures.append("SPR_LEDGER_RECORDS_INVALID")
    for metadata in metadata_records:
        if not isinstance(metadata, dict):
            failures.append("SPR_LEDGER_METADATA_NOT_OBJECT")
            continue
        metadata_payload = {
            key: value for key, value in metadata.items() if key != "record_payload_sha256"
        }
        if metadata.get("record_payload_sha256") != sha256_bytes(canonical_bytes(metadata_payload)):
            failures.append("SPR_LEDGER_METADATA_PAYLOAD_INVALID")
        rows = metadata.get("failure_bindings", [])
        if not isinstance(rows, list):
            failures.append("SPR_LEDGER_FAILURE_BINDINGS_INVALID")
            continue
        record_fingerprints: list[str] = []
        for row in rows:
            if not isinstance(row, dict):
                failures.append("SPR_LEDGER_FAILURE_BINDING_NOT_OBJECT")
                continue
            rule = str(row.get("rule_id", ""))
            component = str(row.get("component_id", ""))
            fingerprint = str(row.get("failure_fingerprint", ""))
            key = (rule, component)
            if (
                rule not in {IDENTITY_RULE, REUSE_RULE}
                or not component
                or re.fullmatch(r"V2F-[0-9a-f]{64}", fingerprint) is None
                or key in sources
            ):
                failures.append(f"SPR_LEDGER_SOURCE_BINDING_INVALID:{component}")
                continue
            tagged = dict(row)
            tagged["metadata_record_id"] = metadata.get("record_id")
            tagged["metadata_source_commit"] = metadata.get("source_commit")
            sources[key] = tagged
            record_fingerprints.append(fingerprint)
            source_fingerprints.add(fingerprint)
        if (
            metadata.get("failure_count") != len(record_fingerprints)
            or metadata.get("failure_fingerprint_set_sha256")
            != line_set_sha(record_fingerprints)
        ):
            failures.append("SPR_LEDGER_METADATA_MEMBERSHIP_INVALID")
    if (
        ledger.get("failure_count") != 86
        or len(source_fingerprints) != 86
        or ledger.get("failure_fingerprint_set_sha256")
        != line_set_sha(source_fingerprints)
    ):
        failures.append("SPR_LEDGER_GLOBAL_MEMBERSHIP_INVALID")

    correction_bindings = ledger.get("correction_record_bindings", [])
    if not isinstance(correction_bindings, list):
        correction_bindings = []
        failures.append("SPR_LEDGER_CORRECTION_BINDINGS_INVALID")
    binding_by_path = {
        str(value.get("path")): value
        for value in correction_bindings
        if isinstance(value, dict)
    }
    expected_paths = {**HDM_IDENTITY_RECORDS, HDM_REUSE_SCAN_PATH: HDM_REUSE_SCAN_ID}
    if set(binding_by_path) != set(expected_paths):
        failures.append("SPR_LEDGER_CORRECTION_PATH_SET_INVALID")
    for path, expected_id in expected_paths.items():
        try:
            document, raw = _committed_document(root, evaluated_head, path)
        except Exception:
            failures.append(f"SPR_HDM_COMMITTED_BYTES_INVALID:{path}")
            continue
        document_payload = {
            key: value for key, value in document.items() if key != "record_payload_sha256"
        }
        payload_sha = sha256_bytes(canonical_bytes(document_payload))
        if (
            document.get("correction_id") != expected_id
            or document.get("authorization_id") != AUTHORIZATION_ID
            or document.get("record_payload_sha256") != payload_sha
        ):
            failures.append(f"SPR_HDM_DOCUMENT_INVALID:{path}")
        rule = IDENTITY_RULE if path in HDM_IDENTITY_RECORDS else REUSE_RULE
        if (
            document.get("rule_id") != rule
            or document.get("future_failure_policy")
            != {"automatic_match": False, "new_failure_requires_new_record": True}
        ):
            failures.append(f"SPR_HDM_POLICY_INVALID:{path}")
        components = document.get("component_ids", [])
        fingerprints = document.get("failure_fingerprints", [])
        if (
            not isinstance(components, list)
            or not isinstance(fingerprints, list)
            or components != sorted(components)
            or fingerprints != sorted(fingerprints)
            or len(components) != len(fingerprints)
            or document.get("component_set_sha256") != line_set_sha(components)
            or document.get("failure_fingerprint_set_sha256")
            != line_set_sha(fingerprints)
        ):
            failures.append(f"SPR_HDM_MEMBERSHIP_INVALID:{path}")
            continue
        ledger_binding = binding_by_path.get(path, {})
        if (
            ledger_binding.get("correction_id") != expected_id
            or ledger_binding.get("file_sha256") != sha256_bytes(raw)
            or ledger_binding.get("record_payload_sha256") != payload_sha
            or ledger_binding.get("failure_fingerprints") != fingerprints
        ):
            failures.append(f"SPR_HDM_LEDGER_BINDING_INVALID:{path}")
        mapped = {component: sources.get((rule, component)) for component in components}
        metadata_ids = document.get("metadata_record_ids", [])
        if (
            any(value is None for value in mapped.values())
            or {
                str(value.get("failure_fingerprint"))
                for value in mapped.values() if value is not None
            } != set(fingerprints)
            or not isinstance(metadata_ids, list)
            or any(
                value.get("metadata_record_id") not in metadata_ids
                for value in mapped.values() if value is not None
            )
            or any(
                value.get("metadata_source_commit") != document.get("source_commit")
                for value in mapped.values() if value is not None
            )
        ):
            failures.append(f"SPR_HDM_SOURCE_MAPPING_INVALID:{path}")
            continue
        target = (
            result["identity_by_component"]
            if rule == IDENTITY_RULE else result["reuse_by_component"]
        )
        for component, source in mapped.items():
            assert source is not None
            fingerprint = str(source["failure_fingerprint"])
            target[component] = _expected_hdm_binding(document, raw, path, fingerprint)
            if rule == IDENTITY_RULE:
                result["identity_fingerprints"].add(fingerprint)
    if (
        len(result["identity_by_component"]) != 82
        or len(result["identity_fingerprints"]) != 82
    ):
        failures.append("SPR_HDM_IDENTITY_CARDINALITY_INVALID")
    if set(result["reuse_by_component"]) != set(REUSE_SCAN_COMPONENTS):
        failures.append("SPR_HDM_REUSE_CARDINALITY_INVALID")
    if failures:
        result = {
            "identity_by_component": {}, "reuse_by_component": {},
            "identity_fingerprints": set(),
        }
    return result, sorted(set(failures))


def _derive_revalidation_targets(
    root: Path,
    evaluated_head: str,
    explicit_paths: Iterable[str],
    current_batch_path: str,
    authorized_components: set[str],
) -> tuple[dict[str, dict[str, str]], list[str]]:
    """Derive the exact old fingerprints, independently of HDM fingerprints."""

    failures: list[str] = []
    targets: dict[str, dict[str, str]] = {}
    component_to_fingerprint: dict[str, str] = {}
    match = re.fullmatch(
        re.escape(FULL_BATCH_ROOT) + r"batch-([0-9]{3})/batch-\1-manifest\.json",
        current_batch_path,
    )
    if match is None:
        return {}, ["SPR_TARGET_CURRENT_BATCH_PATH_INVALID"]
    current_number = int(match.group(1))
    numbered: dict[int, str] = {}
    for relative in explicit_paths:
        item = re.fullmatch(
            re.escape(FULL_BATCH_ROOT) + r"batch-([0-9]{3})/batch-\1-manifest\.json",
            relative,
        )
        if item is not None and int(item.group(1)) <= current_number:
            numbered[int(item.group(1))] = relative
    if set(numbered) != set(range(1, current_number + 1)):
        failures.append("SPR_TARGET_BATCH_PREFIX_INCOMPLETE")
    for number in sorted(numbered):
        try:
            batch, _ = _committed_document(root, evaluated_head, numbered[number])
        except Exception:
            failures.append(f"SPR_TARGET_BATCH_UNREADABLE:{number}")
            continue
        bindings = batch.get("record_bindings", [])
        if not isinstance(bindings, list):
            failures.append(f"SPR_TARGET_BATCH_BINDINGS_INVALID:{number}")
            continue
        for binding in bindings:
            if not isinstance(binding, dict):
                failures.append("SPR_TARGET_BATCH_BINDING_NOT_OBJECT")
                continue
            prior_path = str(binding.get("path", ""))
            try:
                prior, raw = _committed_document(root, evaluated_head, prior_path)
            except Exception:
                failures.append(f"SPR_TARGET_PRIOR_RECORD_UNREADABLE:{prior_path}")
                continue
            if (
                binding.get("record_sha256") != sha256_bytes(raw)
                or binding.get("record_payload_sha256")
                != prior.get("record_payload_sha256")
            ):
                failures.append(f"SPR_TARGET_PRIOR_RECORD_BINDING_INVALID:{prior_path}")
                continue
            fingerprints = binding.get("failure_fingerprints", [])
            identities = prior.get("identity_binding_by_failure", {})
            if not isinstance(fingerprints, list) or not isinstance(identities, dict):
                failures.append(f"SPR_TARGET_PRIOR_IDENTITY_SET_INVALID:{prior_path}")
                continue
            for value in fingerprints:
                fingerprint = str(value)
                identity = identities.get(fingerprint)
                if not isinstance(identity, dict):
                    failures.append(f"SPR_TARGET_PRIOR_IDENTITY_MISSING:{fingerprint}")
                    continue
                component = str(identity.get("current_component_id", ""))
                if component not in authorized_components:
                    continue
                if fingerprint in targets:
                    failures.append(f"SPR_TARGET_FINGERPRINT_DUPLICATE:{fingerprint}")
                    continue
                if component in component_to_fingerprint:
                    failures.append(f"SPR_TARGET_COMPONENT_DUPLICATE:{component}")
                    continue
                targets[fingerprint] = {
                    "component_id": component, "prior_record_path": prior_path,
                }
                component_to_fingerprint[component] = fingerprint
    if len(targets) != 82 or set(component_to_fingerprint) != authorized_components:
        failures.append("SPR_TARGET_SET_NOT_EXACT_82")
    return ({} if failures else targets), sorted(set(failures))


def audit_manifest_and_records(
    root: Path,
    manifest_path: Path,
    *,
    evaluated_head: str,
    current_batch_manifest_path: Path | None = None,
    explicit_batch_manifest_paths: Iterable[Path] | None = None,
) -> dict[str, Any]:
    root = root.resolve(); failures: list[str] = []; trusted: dict[str, dict[str, Any]] = {}
    changed_groups, change_failures = audit_authority_change(root, authority_head=evaluated_head); failures.extend(change_failures)
    try:
        schema, schema_raw = _committed_document(root, evaluated_head, SCHEMA_PATH)
        manifest_rel = manifest_path.resolve().relative_to(root).as_posix()
        manifest, manifest_raw = _committed_document(root, evaluated_head, manifest_rel)
    except Exception:
        return {"status": "NO_GO", "findings": ["SPR_MANIFEST_OR_SCHEMA_UNREADABLE"], "trusted_by_fingerprint": {}}
    manifest_fields = set(MANIFEST_FIELDS); record_fields = set(RECORD_FIELDS)
    binding_fields = set(MANIFEST_BINDING_FIELDS); hdm_fields = set(HDM_BINDING_FIELDS)
    failures.extend(_schema_contract_failures(schema, schema_raw))
    if not manifest_rel.startswith(MANIFEST_ROOT) or manifest_rel.startswith(REVALIDATION_RECORD_ROOT):
        failures.append("SPR_MANIFEST_PATH_SCOPE_INVALID")
    if set(manifest) != manifest_fields: failures.append("SPR_MANIFEST_FIELD_SET_INVALID")
    if manifest.get("schema_path") != SCHEMA_PATH or manifest.get("schema_sha256") != SCHEMA_SHA256 or manifest.get("schema_sha256") != sha256_bytes(schema_raw): failures.append("SPR_MANIFEST_SCHEMA_BINDING_INVALID")
    if manifest.get("schema_version") != MANIFEST_SCHEMA_VERSION or manifest.get("manifest_kind") != MANIFEST_KIND: failures.append("SPR_MANIFEST_SCHEMA_OR_KIND_INVALID")
    if manifest.get("authorization_id") != AUTHORIZATION_ID or manifest.get("authorization_base_head_sha") != AUTHORIZATION_BASE_HEAD or manifest.get("prior_epoch_id") != PRIOR_EPOCH_ID: failures.append("SPR_MANIFEST_AUTHORITY_INVALID")
    binding_head = str(manifest.get("revalidation_binding_head_sha", ""))
    try:
        _git(root, "merge-base", "--is-ancestor", AUTHORIZATION_BASE_HEAD, binding_head)
        _git(root, "merge-base", "--is-ancestor", CHANGE_COMMIT, binding_head)
        _git(root, "merge-base", "--is-ancestor", binding_head, evaluated_head)
        if manifest.get("revalidation_binding_tree_sha") != _git(root, "rev-parse", f"{binding_head}^{{tree}}"): failures.append("SPR_MANIFEST_BINDING_TREE_INVALID")
    except ValueError: failures.append("SPR_MANIFEST_BINDING_ANCESTRY_INVALID")
    if manifest.get("authority_source_path") != REGISTRY_PATH or manifest.get("authority_source_change_commit_sha") != CHANGE_COMMIT or manifest.get("authority_source_change_parent_sha") != CHANGE_PARENT or manifest.get("authority_source_changed_path_count") != 1: failures.append("SPR_MANIFEST_CHANGE_BINDING_INVALID")
    before = _blob(root, CHANGE_PARENT, REGISTRY_PATH); after = _blob(root, CHANGE_COMMIT, REGISTRY_PATH)
    diff = _git(root, "diff", "--binary", "--no-ext-diff", CHANGE_PARENT, CHANGE_COMMIT, "--", REGISTRY_PATH, binary=True)
    if manifest.get("authority_source_before_blob_sha256") != sha256_bytes(before or b"") or manifest.get("authority_source_after_blob_sha256") != sha256_bytes(after or b"") or manifest.get("authority_source_diff_sha256") != sha256_bytes(diff): failures.append("SPR_MANIFEST_AUTHORITY_BLOB_OR_DIFF_INVALID")
    batch_path = manifest.get("current_batch_manifest_path")
    explicit_chain: set[str] = set()
    for supplied in explicit_batch_manifest_paths or []:
        try:
            explicit_chain.add(supplied.resolve().relative_to(root).as_posix())
        except ValueError:
            failures.append("SPR_EXPLICIT_BATCH_PATH_OUTSIDE_ROOT")
    selected_batch = ""
    if current_batch_manifest_path is not None:
        try:
            selected_batch = current_batch_manifest_path.resolve().relative_to(root).as_posix()
        except ValueError:
            failures.append("SPR_CURRENT_BATCH_PATH_OUTSIDE_ROOT")
    if not explicit_chain or selected_batch != CURRENT_BATCH_PATH or str(batch_path) != CURRENT_BATCH_PATH or str(batch_path) not in explicit_chain or str(batch_path) != selected_batch:
        failures.append("SPR_MANIFEST_BATCH_NOT_EXPLICITLY_ROUTED")
    try:
        _, batch_raw = _committed_document(root, evaluated_head, str(batch_path))
        if not str(batch_path).startswith(FULL_BATCH_ROOT) or manifest.get("current_batch_manifest_sha256") != sha256_bytes(batch_raw): failures.append("SPR_MANIFEST_BATCH_BINDING_INVALID")
    except Exception: failures.append("SPR_MANIFEST_BATCH_UNREADABLE")
    ledger_path = manifest.get("historical_delta_metadata_ledger_path")
    try:
        _, ledger_raw = _committed_document(root, evaluated_head, str(ledger_path))
        if ledger_path != LEDGER_PATH or manifest.get("historical_delta_metadata_ledger_sha256") != LEDGER_SHA256 or manifest.get("historical_delta_metadata_ledger_sha256") != sha256_bytes(ledger_raw):
            failures.append("SPR_MANIFEST_HDM_LEDGER_BINDING_INVALID")
    except Exception:
        failures.append("SPR_MANIFEST_HDM_LEDGER_UNREADABLE")
    hdm, hdm_failures = _ledger_hdm_authority(root, evaluated_head)
    failures.extend(hdm_failures)
    authorized_components=changed_groups.get("change_class_only",set())|changed_groups.get("change_class_reuse_scan",set())
    targets, target_failures = _derive_revalidation_targets(
        root, evaluated_head, explicit_chain, selected_batch, authorized_components
    )
    failures.extend(target_failures)
    fps = manifest.get("failure_fingerprints", [])
    if not isinstance(fps, list) or fps != sorted(fps) or len(fps) != 82 or len(set(fps)) != 82 or any(re.fullmatch(r"V2F-[0-9a-f]{64}", str(x)) is None for x in fps): failures.append("SPR_MANIFEST_FINGERPRINT_CARDINALITY_INVALID"); fps=[]
    if fps != sorted(targets): failures.append("SPR_MANIFEST_NOT_EXACT_PRIOR_INVALIDATION_SET")
    if manifest.get("failure_fingerprint_set_sha256") != line_set_sha(fps): failures.append("SPR_MANIFEST_FINGERPRINT_HASH_INVALID")
    if manifest.get("record_count") != 82 or manifest.get("change_class_only_count") != 78 or manifest.get("change_class_reuse_scan_count") != 4: failures.append("SPR_MANIFEST_COUNTS_INVALID")
    if manifest.get("allowed_invalidation") != ALLOWED_INVALIDATION or manifest.get("future_failure_auto_revalidation") is not False or manifest.get("wildcard_count") != 0: failures.append("SPR_MANIFEST_POLICY_INVALID")
    bindings = manifest.get("record_bindings", [])
    if not isinstance(bindings, list) or len(bindings) != 82: failures.append("SPR_MANIFEST_BINDING_COUNT_INVALID"); bindings=[]
    previous = manifest.get("record_chain_start_sha256", ""); covered: list[str] = []; covered_components: list[str] = []
    for index, binding in enumerate(bindings):
        if not isinstance(binding, dict) or set(binding) != binding_fields: failures.append(f"SPR_BINDING_FIELD_SET_INVALID:{index}"); continue
        if not _exact_path(binding.get("path")) or not str(binding.get("path")).startswith(REVALIDATION_RECORD_ROOT): failures.append(f"SPR_RECORD_PATH_SCOPE_INVALID:{index}"); continue
        try:
            record, raw = _committed_document(root, evaluated_head, str(binding.get("path", "")))
        except Exception: failures.append(f"SPR_RECORD_UNREADABLE:{index}"); continue
        if set(record) != record_fields: failures.append(f"SPR_RECORD_FIELD_SET_INVALID:{index}")
        if sha256_bytes(raw) != binding.get("record_sha256"): failures.append(f"SPR_RECORD_SHA_INVALID:{index}")
        rfps = record.get("failure_fingerprints", [])
        if not isinstance(rfps,list) or len(rfps)!=1 or rfps[0] not in fps: failures.append(f"SPR_RECORD_FINGERPRINT_INVALID:{index}"); continue
        fp=str(rfps[0]); covered.append(fp)
        target=targets.get(fp,{})
        if target.get("component_id") != record.get("component_id") or target.get("prior_record_path") != record.get("prior_record_path"): failures.append(f"SPR_RECORD_NOT_EXACT_DERIVED_TARGET:{fp}")
        if binding.get("failure_fingerprints") != [fp] or record.get("failure_fingerprint_set_sha256") != line_set_sha([fp]): failures.append(f"SPR_RECORD_FINGERPRINT_BINDING_INVALID:{fp}")
        for key in ("revalidation_id","prior_record_path","prior_record_sha256","prior_record_payload_sha256","prior_correction_id","previous_revalidation_chain_sha256"):
            if binding.get(key) != record.get(key): failures.append(f"SPR_BINDING_RECORD_MISMATCH:{key}:{fp}")
        if record.get("record_kind") != RECORD_KIND or record.get("schema_version") != RECORD_SCHEMA_VERSION or record.get("authorization_id") != AUTHORIZATION_ID or record.get("authorization_base_head_sha") != AUTHORIZATION_BASE_HEAD or record.get("prior_epoch_id") != PRIOR_EPOCH_ID: failures.append(f"SPR_RECORD_AUTHORITY_INVALID:{fp}")
        if record.get("prior_invalidations") != [ALLOWED_INVALIDATION] or record.get("wildcard_count") != 0 or record.get("future_failure_policy") != FUTURE_POLICY or record.get("new_effective_status") != "CORRECTED_HISTORICAL_DEBT" or record.get("revalidation_reason") != "REGISTRY_AUTHORITY_SOURCE_METADATA_ONLY": failures.append(f"SPR_RECORD_POLICY_INVALID:{fp}")
        if record.get("previous_revalidation_chain_sha256") != previous: failures.append(f"SPR_RECORD_CHAIN_BREAK:{fp}")
        payload_sha=sha256_bytes(canonical_bytes({k:v for k,v in record.items() if k!="record_payload_sha256"}))
        if payload_sha != record.get("record_payload_sha256") or payload_sha != binding.get("record_payload_sha256"): failures.append(f"SPR_RECORD_PAYLOAD_INVALID:{fp}")
        previous=payload_sha
        failures.extend(f"{x}:{fp}" for x in _prior_record_membership(root, record, fp, evaluated_head=evaluated_head))
        try:
            prior, prior_raw = _committed_document(root, evaluated_head, str(record.get("prior_record_path")))
            prior_identity = prior["identity_binding_by_failure"][fp]
        except Exception: failures.append(f"SPR_PRIOR_IDENTITY_UNRESOLVED:{fp}"); continue
        if record.get("correction_batch_manifest_path") not in explicit_chain:
            failures.append(f"SPR_PRIOR_BATCH_NOT_IN_EXPLICIT_CHAIN:{fp}")
        selector=record.get("authority_selectors")
        if not _selector_matches_prior(selector, prior_identity): failures.append(f"SPR_SELECTOR_NOT_PRIOR_EXACT:{fp}"); continue
        if record.get("authority_selector_sha256") != sha256_bytes(canonical_bytes(selector)): failures.append(f"SPR_SELECTOR_HASH_INVALID:{fp}")
        prior_head=str(record.get("prior_binding_head_sha")); rebound_head=str(record.get("revalidation_binding_head_sha"))
        if prior_head != prior.get("binding_head_sha") or record.get("prior_binding_tree_sha") != prior.get("binding_tree_sha") or rebound_head != binding_head or record.get("revalidation_binding_tree_sha") != manifest.get("revalidation_binding_tree_sha"): failures.append(f"SPR_RECORD_HEAD_TREE_BINDING_INVALID:{fp}")
        try:
            _git(root,"merge-base","--is-ancestor",prior_head,CHANGE_COMMIT); _git(root,"merge-base","--is-ancestor",CHANGE_COMMIT,rebound_head); _git(root,"merge-base","--is-ancestor",rebound_head,evaluated_head)
            old_projection=_projection(root,prior_head,selector); new_projection=_projection(root,rebound_head,selector); evaluated_projection=_projection(root,evaluated_head,selector)
        except Exception: failures.append(f"SPR_RECORD_ANCESTRY_OR_PROJECTION_INVALID:{fp}"); continue
        if prior_identity.get("subject_projection") != old_projection or prior_identity.get("subject_projection_sha256") != sha256_bytes(canonical_bytes(old_projection)) or record.get("prior_subject_projection") != old_projection or record.get("prior_subject_projection_sha256") != sha256_bytes(canonical_bytes(old_projection)): failures.append(f"SPR_PRIOR_PROJECTION_NOT_EXACT:{fp}")
        if record.get("rebound_subject_projection") != new_projection or record.get("rebound_subject_projection_sha256") != sha256_bytes(canonical_bytes(new_projection)) or evaluated_projection != new_projection: failures.append(f"SPR_REBOUND_OR_EVALUATED_PROJECTION_INVALID:{fp}")
        if not _nonregistry_surfaces_unchanged(old_projection, new_projection): failures.append(f"SPR_NON_REGISTRY_SURFACE_CHANGED:{fp}")
        old_rows={r.get("component_id"):r for r in old_projection["registry_rows"]}; new_rows={r.get("component_id"):r for r in new_projection["registry_rows"]}
        changed={cid for cid in set(old_rows)|set(new_rows) if old_rows.get(cid)!=new_rows.get(cid)}
        component_id=record.get("component_id"); covered_components.append(str(component_id))
        if changed != {component_id}: failures.append(f"SPR_CHANGED_COMPONENT_NOT_EXACT_ONE:{fp}")
        expected_profile="CHANGE_CLASS_AND_REUSE_SCAN" if component_id in REUSE_SCAN_COMPONENTS else "CHANGE_CLASS_ONLY"
        expected_fields=["change_class","reuse_scan"] if component_id in REUSE_SCAN_COMPONENTS else ["change_class"]
        if record.get("change_profile") != expected_profile or record.get("changed_metadata_fields") != expected_fields: failures.append(f"SPR_CHANGE_PROFILE_INVALID:{fp}")
        identity_binding=record.get("component_identity_hdm_authority"); reuse_binding=record.get("reuse_scan_hdm_authority")
        if not isinstance(identity_binding,dict) or set(identity_binding)!=hdm_fields or identity_binding != hdm.get("identity_by_component",{}).get(str(component_id)): failures.append(f"SPR_IDENTITY_HDM_BINDING_INVALID:{fp}")
        if component_id in REUSE_SCAN_COMPONENTS:
            if not isinstance(reuse_binding,dict) or set(reuse_binding)!=hdm_fields or reuse_binding != hdm.get("reuse_by_component",{}).get(str(component_id)): failures.append(f"SPR_REUSE_HDM_BINDING_INVALID:{fp}")
        elif reuse_binding != {}: failures.append(f"SPR_UNEXPECTED_REUSE_HDM_BINDING:{fp}")
        bound_paths={str(prior_identity.get(k)) for k in ("historical_path","current_path") if prior_identity.get(k)}
        blob_map=record.get("bound_product_blob_sha256_by_path")
        if not isinstance(blob_map,dict) or set(blob_map)!=bound_paths: failures.append(f"SPR_BOUND_BLOB_PATH_SET_INVALID:{fp}")
        for path in bound_paths:
            old_blob=_blob(root,prior_head,path); rebound_blob=_blob(root,rebound_head,path); evaluated_blob=_blob(root,evaluated_head,path)
            expected=sha256_bytes(old_blob) if old_blob is not None else "MISSING"
            if blob_map.get(path)!=expected or rebound_blob!=old_blob or evaluated_blob!=old_blob or _touches(root,prior_head,rebound_head,path) or _touches(root,rebound_head,evaluated_head,path): failures.append(f"SPR_BOUND_PATH_OR_BLOB_CHANGED:{fp}:{path}")
        touch=record.get("touch_proof")
        if not isinstance(touch,dict) or set(touch)!=set(TOUCH_FIELDS) or touch.get("commit_sha")!=CHANGE_COMMIT or touch.get("parent_sha")!=CHANGE_PARENT or touch.get("path")!=REGISTRY_PATH or touch.get("before_blob_sha256")!=manifest.get("authority_source_before_blob_sha256") or touch.get("after_blob_sha256")!=manifest.get("authority_source_after_blob_sha256") or touch.get("diff_sha256")!=manifest.get("authority_source_diff_sha256"): failures.append(f"SPR_TOUCH_PROOF_INVALID:{fp}")
        trusted[fp]={
            "allowed_invalidations":[ALLOWED_INVALIDATION],
            "prior_record_path":record.get("prior_record_path",""),
            "revalidation_id":record.get("revalidation_id",""),
            "record_path":str(binding.get("path","")),
            "revalidation_binding_head_sha":binding_head,
        }
    if sorted(covered)!=fps: failures.append("SPR_RECORD_COVERAGE_INVALID")
    if not _bijective_component_coverage(covered_components, authorized_components): failures.append("SPR_COMPONENT_COVERAGE_NOT_BIJECTIVE_82")
    if previous != manifest.get("record_chain_terminal_sha256"): failures.append("SPR_RECORD_CHAIN_TERMINAL_INVALID")
    failures=sorted(set(failures)); trusted={} if failures else trusted
    return {
        "status":"GO" if not failures else "NO_GO",
        "findings":failures,
        "trusted_by_fingerprint":trusted,
        "trusted_fingerprint_count":len(trusted),
        "record_count":len(bindings),
        "fingerprints":sorted(set(covered)),
    }


def allows_invalidation(trusted: dict[str, dict[str, Any]], *, fingerprint: str,
                        invalidation_code: str, prior_record_path: str) -> bool:
    if invalidation_code != ALLOWED_INVALIDATION:
        return False
    row = trusted.get(fingerprint)
    return isinstance(row, dict) and row.get("allowed_invalidations") == [ALLOWED_INVALIDATION] and row.get("prior_record_path") == prior_record_path
