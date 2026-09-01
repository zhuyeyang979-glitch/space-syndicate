#!/usr/bin/env python3
"""Fail-closed primary validator for the 7de7b95e subject revalidation.

This is a sidecar authority.  It does not mutate the seven correction batches,
does not discover records from a directory, and can suppress only the exact
``SUBJECT_PROJECTION_CHANGED_INVALID`` emitted for an explicitly bound prior
record.  Product blobs and product-path touches remain invalidating.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
from pathlib import Path, PurePosixPath
from typing import Any, Iterable


SCHEMA_VERSION = "space_syndicate.v076.reuse_exact_failure_correction.v2.subject_projection_revalidation_schema.v1"
MANIFEST_SCHEMA_VERSION = "space_syndicate.v076.reuse_exact_failure_correction.v2.subject_projection_revalidation_manifest.v1"
RECORD_SCHEMA_VERSION = "space_syndicate.v076.reuse_exact_failure_correction.v2.subject_projection_revalidation_record.v1"
MANIFEST_KIND = "SUBJECT_PROJECTION_REVALIDATION_MANIFEST"
RECORD_KIND = "SUBJECT_PROJECTION_REVALIDATION_RECORD"
AUTHORIZATION_ID = "USER_AUTHORIZATION_V076_REUSE_FULL_CONVERGENCE_AND_MCP_ONLY_20260827"
AUTHORIZATION_BASE_HEAD = "d701a81dce693b584d52fbfca3e0e78b521ad775"
PRIOR_EPOCH_ID = "FULL_CONVERGENCE_20260827"
ALLOWED_INVALIDATION = "SUBJECT_PROJECTION_CHANGED_INVALID"

SCHEMA_PATH = "docs/architecture/reuse_corrections/v2/schema_subject_projection_revalidation_20260828.json"
SCHEMA_SHA256 = "1c1a5eeaa786ef8ccaf87badaf7ef3009acf398be4f55cb636fd7060453f6c22"
MANIFEST_ROOT = "docs/architecture/reuse_corrections/v2/subject_projection_revalidation/"
RECORD_ROOT = MANIFEST_ROOT + "records/"
FULL_BATCH_ROOT = "docs/architecture/reuse_corrections/v2/batches/full_convergence_20260827/"
FULL_RECORD_ROOT = "docs/architecture/reuse_corrections/v2/records/full_convergence_20260827/"
CURRENT_BATCH_PATH = FULL_BATCH_ROOT + "batch-007/batch-007-manifest.json"
FULL_BATCH_SCHEMA = "space_syndicate.v076.reuse_exact_failure_correction.v2.full_convergence_batch.v1"
LEGACY_CHAIN_ANCHOR = "99f051cd23c250e0282db1708e49e2625d0e82279753a846a00a713614fed67d"

REGISTRY_PATH = "docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json"
SUPERSESSION_PATH = "docs/architecture/V076_SUPERSESSION_MAP.json"
OWNER_MAP_PATH = "docs/architecture/V076_OWNER_REUSE_MAP.md"
DYNAMIC_REFERENCE_PATH = "docs/architecture/V076_DYNAMIC_REFERENCE_MANIFEST.json"
AUTHORITY_PATHS = (REGISTRY_PATH, SUPERSESSION_PATH, OWNER_MAP_PATH, DYNAMIC_REFERENCE_PATH)
CHANGE_COMMIT = "7de7b95e6b26d755d9ccaacbf483e57a949504da"
CHANGE_PARENT = "864cb731fd68af0f48e29fd78b650ad726293103"
BEFORE_REGISTRY_SHA256 = "99dfd1dff415ad36d2f0e791e1388f5a0c389bb39711a33248deebe1a837e071"
AFTER_REGISTRY_SHA256 = "88b0c8e22772849912c9449a5f5bf12df86c32d09516cca0bd0e85f7e0f4117d"
REGISTRY_DIFF_SHA256 = "c5bc17cdde05a7a528e487aa7b3fe665165bd588e6c180b772a1c925e1800125"

LEDGER_PATH = "docs/architecture/V076_HISTORICAL_DELTA_METADATA_LEDGER.json"
LEDGER_SHA256 = "2bbcba050fd8c8f7027bd762d80c1187b29742dec81034c3f3eecc456eaa075d"
IDENTITY_RULE = "NEW_COMPONENT_CANNOT_CLAIM_INHERITED"
REUSE_RULE = "HISTORY_NEW_AUTHORITY_REUSE_SCAN_INVALID"
HDM_IDENTITY = {
    "docs/architecture/reuse_corrections/v2/records/full_convergence_20260827/historical_delta_metadata/v2-hdm-20260827-5af52a5b-component-identity.json": "V2-HDM-20260827-5AF52A5B-COMPONENT-IDENTITY",
    "docs/architecture/reuse_corrections/v2/records/full_convergence_20260827/historical_delta_metadata/v2-hdm-20260827-488c21f5-component-identity.json": "V2-HDM-20260827-488C21F5-COMPONENT-IDENTITY",
    "docs/architecture/reuse_corrections/v2/records/full_convergence_20260827/historical_delta_metadata/v2-hdm-20260827-8e6ce3e6-component-identity.json": "V2-HDM-20260827-8E6CE3E6-COMPONENT-IDENTITY",
}
HDM_REUSE_PATH = "docs/architecture/reuse_corrections/v2/records/full_convergence_20260827/historical_delta_metadata/v2-hdm-20260827-5af52a5b-authority-reuse-scan.json"
HDM_REUSE_ID = "V2-HDM-20260827-5AF52A5B-AUTHORITY-REUSE-SCAN"
REUSE_COMPONENTS = frozenset({
    "component.current.card_flow_policy_v06",
    "component.current.card_flow_transaction_service_v06",
    "component.current.card_player_state_port_v06",
    "component.current.global_supply_demand_runtime_service_v06",
})

SELECTOR_FIELDS = frozenset({"component_ids", "paths", "dynamic_reference_ids", "supersession_ids", "retirement_ids"})
PROJECTION_FIELDS = frozenset({"dynamic_reference_rows", "owner_map_lines", "registry_rows", "supersession_rows"})
TOUCH_FIELDS = frozenset({"commit_sha", "parent_sha", "path", "before_blob_sha256", "after_blob_sha256", "diff_sha256"})
HDM_BINDING_FIELDS = frozenset({"authority_kind", "correction_id", "path", "file_sha256", "record_payload_sha256", "failure_fingerprint", "rule_id"})
FUTURE_POLICY = {"FUTURE_FAILURE_AUTO_REVALIDATION_COUNT": 0, "NEW_FAILURE_REQUIRES_NEW_RECORD": True}
PROFILE_FIELDS = {"CHANGE_CLASS_ONLY": ["change_class"], "CHANGE_CLASS_AND_REUSE_SCAN": ["change_class", "reuse_scan"]}

MANIFEST_FIELDS = frozenset("""schema_version manifest_kind manifest_id authorization_id authorization_base_head_sha schema_path schema_sha256 prior_epoch_id revalidation_binding_head_sha revalidation_binding_tree_sha current_batch_manifest_path current_batch_manifest_sha256 authority_source_path authority_source_change_commit_sha authority_source_change_parent_sha authority_source_before_blob_sha256 authority_source_after_blob_sha256 authority_source_diff_sha256 authority_source_changed_path_count historical_delta_metadata_ledger_path historical_delta_metadata_ledger_sha256 record_count failure_fingerprints failure_fingerprint_set_sha256 change_class_only_count change_class_reuse_scan_count record_bindings record_chain_start_sha256 record_chain_terminal_sha256 allowed_invalidation future_failure_auto_revalidation wildcard_count created_at creator""".split())
RECORD_FIELDS = frozenset("""schema_version record_kind revalidation_id authorization_id authorization_base_head_sha prior_epoch_id failure_fingerprints failure_fingerprint_set_sha256 prior_invalidations prior_record_path prior_record_sha256 prior_record_payload_sha256 prior_correction_id correction_batch_manifest_path correction_batch_manifest_sha256 prior_binding_head_sha prior_binding_tree_sha revalidation_binding_head_sha revalidation_binding_tree_sha authority_selectors authority_selector_sha256 component_id change_profile changed_metadata_fields touch_proof prior_subject_projection prior_subject_projection_sha256 rebound_subject_projection rebound_subject_projection_sha256 bound_product_blob_sha256_by_path component_identity_hdm_authority reuse_scan_hdm_authority future_failure_policy wildcard_count new_effective_status previous_revalidation_chain_sha256 created_at creator revalidation_reason record_payload_sha256""".split())
BINDING_FIELDS = frozenset("""path record_sha256 record_payload_sha256 revalidation_id prior_record_path prior_record_sha256 prior_record_payload_sha256 prior_correction_id failure_fingerprints previous_revalidation_chain_sha256""".split())


class DuplicateJsonKeyError(ValueError):
    pass


def _strict_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise DuplicateJsonKeyError(key)
        result[key] = value
    return result


def _reject_constant(value: str) -> Any:
    raise ValueError(f"non-finite JSON number: {value}")


def strict_json_bytes(payload: bytes) -> Any:
    return json.loads(payload.decode("utf-8-sig"), object_pairs_hook=_strict_pairs, parse_constant=_reject_constant)


def strict_json_file(path: Path) -> Any:
    return strict_json_bytes(path.read_bytes())


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False) + "\n").encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def line_set_sha(values: Iterable[str]) -> str:
    return sha256_bytes(("\n".join(sorted(str(v) for v in values)) + "\n").encode())


def _sha(value: Any, length: int) -> bool:
    return isinstance(value, str) and re.fullmatch(f"[0-9a-f]{{{length}}}", value) is not None


def _exact_int(value: Any, expected: int) -> bool:
    return type(value) is int and value == expected


def _exact_path(value: Any) -> bool:
    if not isinstance(value, str) or not value or value.startswith(("/", "\\")) or value.endswith(("/", "\\")):
        return False
    if "\\" in value or ":" in value or "\0" in value or any(c in value for c in "*?[]"):
        return False
    parts = PurePosixPath(value).parts
    return bool(parts) and "/".join(parts) == value and all(x not in ("", ".", "..") for x in parts)


def _timestamp(value: Any) -> bool:
    return isinstance(value, str) and re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z", value) is not None


def _fingerprints(value: Any, count: int) -> list[str] | None:
    if not isinstance(value, list):
        return None
    rendered = [str(v) for v in value]
    if len(rendered) != count or rendered != sorted(rendered) or len(set(rendered)) != count:
        return None
    return rendered if all(re.fullmatch(r"V2F-[0-9a-f]{64}", v) for v in rendered) else None


def selector_failures(value: Any) -> list[str]:
    if not isinstance(value, dict) or set(value) != SELECTOR_FIELDS:
        return ["SPR_SELECTOR_FIELD_SET_INVALID"]
    failures: list[str] = []
    for key in sorted(SELECTOR_FIELDS):
        rows = value.get(key)
        if not isinstance(rows, list) or rows != sorted(rows) or len(rows) != len(set(rows)):
            failures.append(f"SPR_SELECTOR_VALUES_INVALID:{key}")
            continue
        for row in rows:
            if not isinstance(row, str) or not row or any(c in row for c in "*?[]") or (key == "paths" and not _exact_path(row)):
                failures.append(f"SPR_SELECTOR_VALUE_NOT_EXACT:{key}")
    if not value.get("component_ids") and not value.get("paths"):
        failures.append("SPR_SELECTOR_SUBJECT_EMPTY")
    return sorted(set(failures))


def _git(root: Path, *args: str, binary: bool = False) -> bytes | str:
    env = os.environ.copy(); env["GIT_NO_REPLACE_OBJECTS"] = "1"
    proc = subprocess.run(["git", "--no-replace-objects", "-C", str(root), *args], stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env, check=False)
    if proc.returncode:
        raise ValueError(proc.stderr.decode("utf-8", "replace").strip())
    return proc.stdout if binary else proc.stdout.decode("utf-8", "replace").strip()


def _blob(root: Path, commit: str, path: str) -> bytes | None:
    try:
        return _git(root, "cat-file", "blob", f"{commit}:{path}", binary=True)  # type: ignore[return-value]
    except ValueError:
        return None


def _ancestor(root: Path, old: str, new: str) -> bool:
    proc = subprocess.run(["git", "--no-replace-objects", "-C", str(root), "merge-base", "--is-ancestor", old, new], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    return proc.returncode == 0


def _repo_path(root: Path, value: Path | str) -> tuple[str, Path]:
    candidate = Path(value)
    if not candidate.is_absolute():
        candidate = root / candidate
    resolved = candidate.resolve(); relative = resolved.relative_to(root.resolve()).as_posix()
    if not _exact_path(relative) or resolved != (root / relative).resolve():
        raise ValueError("unsafe path")
    return relative, resolved


def _committed_document(root: Path, head: str, relative: str) -> tuple[dict[str, Any], bytes]:
    if not _exact_path(relative):
        raise ValueError("unsafe path")
    local = (root / relative).read_bytes(); committed = _blob(root, head, relative)
    if committed is None or committed != local:
        raise ValueError("committed/local bytes mismatch")
    value = strict_json_bytes(local)
    if not isinstance(value, dict):
        raise ValueError("document not object")
    return value, local


def validate_schema_document(document: Any) -> list[str]:
    if not isinstance(document, dict):
        return ["SPR_SCHEMA_NOT_OBJECT"]
    failures: list[str] = []
    expected = {
        "schema_version": SCHEMA_VERSION, "manifest_schema_version": MANIFEST_SCHEMA_VERSION,
        "record_schema_version": RECORD_SCHEMA_VERSION, "manifest_kind": MANIFEST_KIND,
        "record_kind": RECORD_KIND, "authorization_id": AUTHORIZATION_ID,
        "authorization_base_head_sha": AUTHORIZATION_BASE_HEAD, "prior_epoch_id": PRIOR_EPOCH_ID,
        "authority_source_path": REGISTRY_PATH, "authority_source_change_commit_sha": CHANGE_COMMIT,
        "authority_source_change_parent_sha": CHANGE_PARENT, "allowed_invalidation": ALLOWED_INVALIDATION,
        "record_fingerprint_cardinality": "ONE_EXACT_FINGERPRINT_PER_RECORD",
        "record_count": 82, "change_class_only_count": 78, "change_class_reuse_scan_count": 4,
        "authorized_metadata_change_profiles": PROFILE_FIELDS,
        "reuse_scan_authorized_component_ids": sorted(REUSE_COMPONENTS),
        "projection_sections": ["dynamic_reference_rows", "owner_map_lines", "registry_rows", "supersession_rows"],
        "future_failure_policy": FUTURE_POLICY, "wildcard_count": 0, "future_failure_auto_revalidation": False,
    }
    required_keys = set(expected) | {"manifest_required_fields", "record_required_fields", "manifest_record_binding_fields", "touch_proof_fields", "hdm_authority_binding_fields"}
    if set(document) != required_keys: failures.append("SPR_SCHEMA_FIELD_SET_INVALID")
    for key, expected_value in expected.items():
        if document.get(key) != expected_value: failures.append(f"SPR_SCHEMA_VALUE_INVALID:{key}")
    for key, fields in (("manifest_required_fields", MANIFEST_FIELDS), ("record_required_fields", RECORD_FIELDS), ("manifest_record_binding_fields", BINDING_FIELDS), ("touch_proof_fields", TOUCH_FIELDS), ("hdm_authority_binding_fields", HDM_BINDING_FIELDS)):
        value = document.get(key)
        if not isinstance(value, list) or len(value) != len(set(value)) or set(value) != fields:
            failures.append(f"SPR_SCHEMA_REQUIRED_FIELDS_INVALID:{key}")
    return sorted(set(failures))


def validate_schema_file(root: Path) -> list[str]:
    try:
        raw = (root / SCHEMA_PATH).read_bytes(); document = strict_json_bytes(raw)
    except Exception:
        return ["SPR_SCHEMA_UNREADABLE"]
    failures = validate_schema_document(document)
    if sha256_bytes(raw) != SCHEMA_SHA256: failures.append("SPR_SCHEMA_SHA256_INVALID")
    return sorted(set(failures))


def validate_manifest_document(document: Any) -> list[str]:
    if not isinstance(document, dict): return ["SPR_MANIFEST_NOT_OBJECT"]
    f: list[str] = []
    if set(document) != MANIFEST_FIELDS: f.append("SPR_MANIFEST_FIELD_SET_INVALID")
    expected = {"schema_version": MANIFEST_SCHEMA_VERSION, "manifest_kind": MANIFEST_KIND, "authorization_id": AUTHORIZATION_ID, "authorization_base_head_sha": AUTHORIZATION_BASE_HEAD, "schema_path": SCHEMA_PATH, "schema_sha256": SCHEMA_SHA256, "prior_epoch_id": PRIOR_EPOCH_ID, "authority_source_path": REGISTRY_PATH, "authority_source_change_commit_sha": CHANGE_COMMIT, "authority_source_change_parent_sha": CHANGE_PARENT, "authority_source_before_blob_sha256": BEFORE_REGISTRY_SHA256, "authority_source_after_blob_sha256": AFTER_REGISTRY_SHA256, "authority_source_diff_sha256": REGISTRY_DIFF_SHA256, "authority_source_changed_path_count": 1, "historical_delta_metadata_ledger_path": LEDGER_PATH, "historical_delta_metadata_ledger_sha256": LEDGER_SHA256, "record_count": 82, "change_class_only_count": 78, "change_class_reuse_scan_count": 4, "allowed_invalidation": ALLOWED_INVALIDATION, "future_failure_auto_revalidation": False, "wildcard_count": 0}
    for key, value in expected.items():
        if document.get(key) != value or (type(value) is int and type(document.get(key)) is not int): f.append(f"SPR_MANIFEST_VALUE_INVALID:{key}")
    for key in ("revalidation_binding_head_sha", "revalidation_binding_tree_sha"):
        if not _sha(document.get(key), 40): f.append(f"SPR_MANIFEST_OID_INVALID:{key}")
    for key in ("current_batch_manifest_sha256", "failure_fingerprint_set_sha256", "record_chain_terminal_sha256"):
        if not _sha(document.get(key), 64): f.append(f"SPR_MANIFEST_SHA_INVALID:{key}")
    if document.get("record_chain_start_sha256") != "": f.append("SPR_MANIFEST_CHAIN_START_NOT_EMPTY")
    for key in ("current_batch_manifest_path",):
        if not _exact_path(document.get(key)): f.append(f"SPR_MANIFEST_PATH_INVALID:{key}")
    fps = _fingerprints(document.get("failure_fingerprints"), 82)
    if fps is None: f.append("SPR_MANIFEST_FINGERPRINTS_INVALID"); fps = []
    if document.get("failure_fingerprint_set_sha256") != line_set_sha(fps): f.append("SPR_MANIFEST_FINGERPRINT_HASH_INVALID")
    bindings = document.get("record_bindings")
    if not isinstance(bindings, list) or len(bindings) != 82: f.append("SPR_MANIFEST_BINDINGS_INVALID")
    if not isinstance(document.get("manifest_id"), str) or not document.get("manifest_id") or not _timestamp(document.get("created_at")) or not isinstance(document.get("creator"), str) or not document.get("creator"): f.append("SPR_MANIFEST_IDENTITY_INVALID")
    return sorted(set(f))


def validate_record_document(document: Any) -> list[str]:
    if not isinstance(document, dict): return ["SPR_RECORD_NOT_OBJECT"]
    f: list[str] = []
    if set(document) != RECORD_FIELDS: f.append("SPR_RECORD_FIELD_SET_INVALID")
    for key, value in (("schema_version", RECORD_SCHEMA_VERSION), ("record_kind", RECORD_KIND), ("authorization_id", AUTHORIZATION_ID), ("authorization_base_head_sha", AUTHORIZATION_BASE_HEAD), ("prior_epoch_id", PRIOR_EPOCH_ID), ("prior_invalidations", [ALLOWED_INVALIDATION]), ("future_failure_policy", FUTURE_POLICY), ("wildcard_count", 0), ("new_effective_status", "CORRECTED_HISTORICAL_DEBT"), ("revalidation_reason", "REGISTRY_AUTHORITY_SOURCE_METADATA_ONLY")):
        if document.get(key) != value or (type(value) is int and type(document.get(key)) is not int): f.append(f"SPR_RECORD_VALUE_INVALID:{key}")
    fps = _fingerprints(document.get("failure_fingerprints"), 1)
    if fps is None: f.append("SPR_RECORD_FINGERPRINT_INVALID"); fps=[]
    if document.get("failure_fingerprint_set_sha256") != line_set_sha(fps): f.append("SPR_RECORD_FINGERPRINT_HASH_INVALID")
    for key in ("prior_record_sha256", "prior_record_payload_sha256", "correction_batch_manifest_sha256", "authority_selector_sha256", "prior_subject_projection_sha256", "rebound_subject_projection_sha256", "record_payload_sha256"):
        if not _sha(document.get(key), 64): f.append(f"SPR_RECORD_SHA_INVALID:{key}")
    for key in ("prior_binding_head_sha", "prior_binding_tree_sha", "revalidation_binding_head_sha", "revalidation_binding_tree_sha"):
        if not _sha(document.get(key), 40): f.append(f"SPR_RECORD_OID_INVALID:{key}")
    if document.get("previous_revalidation_chain_sha256") != "" and not _sha(document.get("previous_revalidation_chain_sha256"),64): f.append("SPR_RECORD_CHAIN_INVALID")
    for key, prefix in (("prior_record_path", FULL_RECORD_ROOT), ("correction_batch_manifest_path", FULL_BATCH_ROOT)):
        value=document.get(key)
        if not _exact_path(value) or not str(value).startswith(prefix): f.append(f"SPR_RECORD_PATH_INVALID:{key}")
    f.extend(selector_failures(document.get("authority_selectors")))
    if not isinstance(document.get("component_id"), str) or not document.get("component_id"): f.append("SPR_RECORD_COMPONENT_INVALID")
    profile=document.get("change_profile")
    if profile not in PROFILE_FIELDS or document.get("changed_metadata_fields") != PROFILE_FIELDS.get(profile): f.append("SPR_RECORD_CHANGE_PROFILE_INVALID")
    if not isinstance(document.get("touch_proof"),dict) or set(document.get("touch_proof",{})) != TOUCH_FIELDS: f.append("SPR_RECORD_TOUCH_FIELDS_INVALID")
    for key in ("prior_subject_projection","rebound_subject_projection"):
        if not isinstance(document.get(key),dict) or set(document.get(key,{})) != PROJECTION_FIELDS: f.append(f"SPR_RECORD_PROJECTION_INVALID:{key}")
    blobs=document.get("bound_product_blob_sha256_by_path")
    if not isinstance(blobs,dict) or any(not _exact_path(k) or not (_sha(v,64) or v=="MISSING") for k,v in blobs.items()): f.append("SPR_RECORD_BLOB_MAP_INVALID")
    if not isinstance(document.get("component_identity_hdm_authority"),dict) or set(document.get("component_identity_hdm_authority",{})) != HDM_BINDING_FIELDS: f.append("SPR_RECORD_IDENTITY_HDM_FIELDS_INVALID")
    reuse=document.get("reuse_scan_hdm_authority")
    if not isinstance(reuse,dict) or (reuse and set(reuse) != HDM_BINDING_FIELDS): f.append("SPR_RECORD_REUSE_HDM_FIELDS_INVALID")
    payload={k:v for k,v in document.items() if k!="record_payload_sha256"}
    try: digest=sha256_bytes(canonical_bytes(payload))
    except Exception: digest=""
    if document.get("record_payload_sha256") != digest: f.append("SPR_RECORD_PAYLOAD_INVALID")
    if not isinstance(document.get("revalidation_id"),str) or not document.get("revalidation_id") or not _timestamp(document.get("created_at")) or not isinstance(document.get("creator"),str) or not document.get("creator"): f.append("SPR_RECORD_IDENTITY_INVALID")
    return sorted(set(f))


def _registry_rows(document: Any) -> dict[str, dict[str, Any]]:
    if not isinstance(document,dict) or not isinstance(document.get("component_inventory"),list): raise ValueError("registry shape")
    result: dict[str,dict[str,Any]]={}
    for row in document["component_inventory"]:
        if not isinstance(row,dict) or not isinstance(row.get("component_id"),str) or row["component_id"] in result: raise ValueError("registry row")
        result[row["component_id"]]=row
    return result


def audit_authority_transition(root: Path, *, evaluated_head: str | None = None) -> tuple[dict[str, Any], list[str]]:
    failures: list[str]=[]
    try:
        if _git(root,"rev-parse",f"{CHANGE_COMMIT}^1") != CHANGE_PARENT: failures.append("SPR_CHANGE_PARENT_INVALID")
        changed=str(_git(root,"diff","--name-only",CHANGE_PARENT,CHANGE_COMMIT)).splitlines()
        if changed != [REGISTRY_PATH]: failures.append("SPR_CHANGE_NOT_REGISTRY_ONLY")
        before=_blob(root,CHANGE_PARENT,REGISTRY_PATH); after=_blob(root,CHANGE_COMMIT,REGISTRY_PATH)
        diff=_git(root,"diff","--binary","--no-ext-diff",CHANGE_PARENT,CHANGE_COMMIT,"--",REGISTRY_PATH,binary=True)
        if before is None or after is None: raise ValueError("blob")
        if sha256_bytes(before)!=BEFORE_REGISTRY_SHA256 or sha256_bytes(after)!=AFTER_REGISTRY_SHA256 or sha256_bytes(diff)!=REGISTRY_DIFF_SHA256: failures.append("SPR_CHANGE_BYTES_INVALID")
        old_doc=strict_json_bytes(before); new_doc=strict_json_bytes(after); old=_registry_rows(old_doc); new=_registry_rows(new_doc)
        if set(old_doc)-{"component_inventory"} != set(new_doc)-{"component_inventory"} or any(old_doc[k]!=new_doc[k] for k in set(old_doc)-{"component_inventory"}): failures.append("SPR_REGISTRY_NON_INVENTORY_CHANGED")
        if set(old)!=set(new): failures.append("SPR_REGISTRY_COMPONENT_SET_CHANGED")
        groups={"change_class_only":set(),"change_class_reuse_scan":set()}
        missing=object()
        for component in sorted(set(old)|set(new)):
            if old.get(component)==new.get(component): continue
            if component not in old or component not in new: failures.append(f"SPR_REGISTRY_ROW_ADDED_REMOVED:{component}"); continue
            fields={k for k in set(old[component])|set(new[component]) if old[component].get(k,missing)!=new[component].get(k,missing)}
            if fields=={"change_class"}: groups["change_class_only"].add(component)
            elif fields=={"change_class","reuse_scan"}: groups["change_class_reuse_scan"].add(component)
            else: failures.append(f"SPR_REGISTRY_FIELDS_UNAUTHORIZED:{component}")
        if len(groups["change_class_only"])!=78: failures.append("SPR_CHANGE_CLASS_ONLY_COUNT_INVALID")
        if groups["change_class_reuse_scan"]!=set(REUSE_COMPONENTS): failures.append("SPR_REUSE_COMPONENT_SET_INVALID")
        if evaluated_head and not _ancestor(root,CHANGE_COMMIT,evaluated_head): failures.append("SPR_CHANGE_NOT_EVALUATED_ANCESTOR")
    except Exception:
        return {},["SPR_CHANGE_UNRESOLVED"]
    groups.update({"before_sha256":BEFORE_REGISTRY_SHA256,"after_sha256":AFTER_REGISTRY_SHA256,"diff_sha256":REGISTRY_DIFF_SHA256})
    return groups,sorted(set(failures))


def _authority_binding(document: dict[str,Any], raw: bytes, path: str, fingerprint: str) -> dict[str,Any]:
    return {"authority_kind":document["transition_class_id"],"correction_id":document["correction_id"],"path":path,"file_sha256":sha256_bytes(raw),"record_payload_sha256":document["record_payload_sha256"],"failure_fingerprint":fingerprint,"rule_id":document["rule_id"]}


def validate_hdm_authority(root: Path, evaluated_head: str) -> tuple[dict[str,Any],list[str]]:
    """Build exact component->fingerprint authority through ledger source bindings."""
    failures: list[str]=[]; result={"identity_by_component":{},"reuse_by_component":{},"identity_fingerprints":set()}
    try: ledger,ledger_raw=_committed_document(root,evaluated_head,LEDGER_PATH)
    except Exception: return result,["SPR_LEDGER_COMMITTED_BYTES_INVALID"]
    if sha256_bytes(ledger_raw)!=LEDGER_SHA256: failures.append("SPR_LEDGER_SHA_INVALID")
    if ledger.get("authorization_id")!=AUTHORIZATION_ID or ledger.get("ledger_id")!="V076_HISTORICAL_DELTA_METADATA_LEDGER": failures.append("SPR_LEDGER_AUTHORITY_INVALID")
    if ledger.get("ledger_payload_sha256")!=sha256_bytes(canonical_bytes({k:v for k,v in ledger.items() if k!="ledger_payload_sha256"})): failures.append("SPR_LEDGER_PAYLOAD_INVALID")
    sources: dict[tuple[str,str],dict[str,Any]]={}; source_fps:set[str]=set()
    records=ledger.get("records",[])
    if not isinstance(records,list): records=[]; failures.append("SPR_LEDGER_RECORDS_INVALID")
    for metadata in records:
        if not isinstance(metadata,dict): failures.append("SPR_LEDGER_METADATA_NOT_OBJECT"); continue
        if metadata.get("record_payload_sha256")!=sha256_bytes(canonical_bytes({k:v for k,v in metadata.items() if k!="record_payload_sha256"})): failures.append("SPR_LEDGER_METADATA_PAYLOAD_INVALID")
        bindings=metadata.get("failure_bindings",[])
        if not isinstance(bindings,list): failures.append("SPR_LEDGER_FAILURE_BINDINGS_INVALID"); continue
        fps=[]
        for row in bindings:
            if not isinstance(row,dict): failures.append("SPR_LEDGER_FAILURE_BINDING_NOT_OBJECT"); continue
            rule=str(row.get("rule_id","")); component=str(row.get("component_id","")); fp=str(row.get("failure_fingerprint","")); key=(rule,component)
            if rule not in (IDENTITY_RULE,REUSE_RULE) or not component or re.fullmatch(r"V2F-[0-9a-f]{64}",fp) is None or key in sources: failures.append(f"SPR_LEDGER_SOURCE_BINDING_INVALID:{component}"); continue
            tagged=dict(row)
            tagged["metadata_record_id"]=metadata.get("record_id")
            tagged["metadata_source_commit"]=metadata.get("source_commit")
            sources[key]=tagged; fps.append(fp); source_fps.add(fp)
        if metadata.get("failure_count")!=len(fps) or metadata.get("failure_fingerprint_set_sha256")!=line_set_sha(fps): failures.append("SPR_LEDGER_METADATA_MEMBERSHIP_INVALID")
    if ledger.get("failure_count")!=86 or len(source_fps)!=86 or ledger.get("failure_fingerprint_set_sha256")!=line_set_sha(source_fps): failures.append("SPR_LEDGER_GLOBAL_MEMBERSHIP_INVALID")
    ledger_bindings=ledger.get("correction_record_bindings",[])
    if not isinstance(ledger_bindings,list): ledger_bindings=[]; failures.append("SPR_LEDGER_CORRECTION_BINDINGS_INVALID")
    binding_by_path={str(x.get("path")):x for x in ledger_bindings if isinstance(x,dict)}
    expected={**HDM_IDENTITY,HDM_REUSE_PATH:HDM_REUSE_ID}
    if set(binding_by_path)!=set(expected): failures.append("SPR_LEDGER_CORRECTION_PATH_SET_INVALID")
    for path,expected_id in expected.items():
        try: document,raw=_committed_document(root,evaluated_head,path)
        except Exception: failures.append(f"SPR_HDM_COMMITTED_BYTES_INVALID:{path}"); continue
        payload_sha=sha256_bytes(canonical_bytes({k:v for k,v in document.items() if k!="record_payload_sha256"}))
        if document.get("correction_id")!=expected_id or document.get("authorization_id")!=AUTHORIZATION_ID or document.get("record_payload_sha256")!=payload_sha: failures.append(f"SPR_HDM_DOCUMENT_INVALID:{path}")
        rule=IDENTITY_RULE if path in HDM_IDENTITY else REUSE_RULE
        if document.get("rule_id")!=rule or document.get("future_failure_policy")!={"automatic_match":False,"new_failure_requires_new_record":True}: failures.append(f"SPR_HDM_POLICY_INVALID:{path}")
        components=document.get("component_ids",[]); fps=document.get("failure_fingerprints",[])
        if not isinstance(components,list) or not isinstance(fps,list) or components!=sorted(components) or fps!=sorted(fps) or len(components)!=len(fps) or document.get("component_set_sha256")!=line_set_sha(components) or document.get("failure_fingerprint_set_sha256")!=line_set_sha(fps): failures.append(f"SPR_HDM_MEMBERSHIP_INVALID:{path}"); continue
        ledger_binding=binding_by_path.get(path,{})
        if ledger_binding.get("correction_id")!=expected_id or ledger_binding.get("file_sha256")!=sha256_bytes(raw) or ledger_binding.get("record_payload_sha256")!=payload_sha or ledger_binding.get("failure_fingerprints")!=fps: failures.append(f"SPR_HDM_LEDGER_BINDING_INVALID:{path}")
        mapped={c:sources.get((rule,c)) for c in components}
        metadata_ids=document.get("metadata_record_ids",[])
        if (
            any(v is None for v in mapped.values())
            or {str(v.get("failure_fingerprint")) for v in mapped.values() if v}!=set(fps)
            or not isinstance(metadata_ids,list)
            or any(v.get("metadata_record_id") not in metadata_ids for v in mapped.values() if v)
            or any(v.get("metadata_source_commit")!=document.get("source_commit") for v in mapped.values() if v)
        ):
            failures.append(f"SPR_HDM_SOURCE_MAPPING_INVALID:{path}"); continue
        target=result["identity_by_component"] if rule==IDENTITY_RULE else result["reuse_by_component"]
        for component,source in mapped.items():
            fp=str(source["failure_fingerprint"]); target[component]=_authority_binding(document,raw,path,fp)
            if rule==IDENTITY_RULE: result["identity_fingerprints"].add(fp)
    if len(result["identity_by_component"])!=82 or len(result["identity_fingerprints"])!=82: failures.append("SPR_HDM_IDENTITY_CARDINALITY_INVALID")
    if set(result["reuse_by_component"])!=set(REUSE_COMPONENTS): failures.append("SPR_HDM_REUSE_CARDINALITY_INVALID")
    if failures: result={"identity_by_component":{},"reuse_by_component":{},"identity_fingerprints":set()}
    return result,sorted(set(failures))


def validate_explicit_batch_chain(root: Path, evaluated_head: str, paths: Iterable[Path]) -> tuple[dict[str,dict[str,Any]],list[str]]:
    failures: list[str]=[]; numbered:dict[int,tuple[str,dict[str,Any],bytes]]={}
    for supplied in paths:
        try: relative,_=_repo_path(root,supplied); document,raw=_committed_document(root,evaluated_head,relative)
        except Exception: failures.append("SPR_BATCH_COMMITTED_BYTES_INVALID"); continue
        match=re.fullmatch(re.escape(FULL_BATCH_ROOT)+r"batch-([0-9]{3})/batch-\1-manifest\.json",relative)
        if match is None: failures.append(f"SPR_BATCH_PATH_INVALID:{relative}"); continue
        number=int(match.group(1))
        if number in numbered: failures.append(f"SPR_BATCH_DUPLICATE:{number}"); continue
        numbered[number]=(relative,document,raw)
    if not numbered or sorted(numbered)!=list(range(1,max(numbered)+1)): failures.append("SPR_BATCH_CHAIN_NOT_CONTIGUOUS_FROM_001")
    previous=None
    for number in sorted(numbered):
        relative,document,raw=numbered[number]; batch_id=f"batch-{number:03d}"
        if document.get("schema_version")!=FULL_BATCH_SCHEMA or document.get("authorization_id")!=AUTHORIZATION_ID or document.get("authorization_base_head_sha")!=AUTHORIZATION_BASE_HEAD or document.get("batch_id")!=batch_id: failures.append(f"SPR_BATCH_AUTHORITY_INVALID:{batch_id}")
        head=str(document.get("binding_head_sha",""))
        try: tree=_git(root,"rev-parse",f"{head}^{{tree}}")
        except Exception: tree=""
        if document.get("binding_tree_sha")!=tree or not _ancestor(root,AUTHORIZATION_BASE_HEAD,head) or not _ancestor(root,head,evaluated_head): failures.append(f"SPR_BATCH_BINDING_INVALID:{batch_id}")
        fps=document.get("failure_fingerprints",[]); bindings=document.get("record_bindings",[])
        covered=[str(fp) for b in bindings if isinstance(b,dict) for fp in b.get("failure_fingerprints",[]) ] if isinstance(bindings,list) else []
        if not isinstance(fps,list) or sorted(covered)!=fps or len(covered)!=len(set(covered)): failures.append(f"SPR_BATCH_RECORD_COVERAGE_INVALID:{batch_id}")
        if number==1:
            if document.get("previous_batch_append_sha256")!="" or document.get("record_chain_start_sha256")!=LEGACY_CHAIN_ANCHOR: failures.append("SPR_BATCH_INITIAL_ANCHOR_INVALID")
        elif previous:
            _,prior,prior_raw=previous
            if document.get("previous_batch_append_sha256")!=sha256_bytes(prior_raw) or document.get("record_chain_start_sha256")!=prior.get("record_chain_terminal_sha256"): failures.append(f"SPR_BATCH_LINK_INVALID:{batch_id}")
            if not _ancestor(root,str(prior.get("binding_head_sha","")),head): failures.append(f"SPR_BATCH_HEAD_SEQUENCE_INVALID:{batch_id}")
        previous=(relative,document,raw)
    index={rel:{"document":doc,"raw":raw,"sha256":sha256_bytes(raw)} for rel,doc,raw in numbered.values()}
    return ({} if failures else index),sorted(set(failures))


def derive_revalidation_targets(
    root: Path,
    evaluated_head: str,
    batches: dict[str,dict[str,Any]],
    current_batch_path: str,
    authorized_components: set[str],
) -> tuple[dict[str,dict[str,str]],list[str]]:
    """Derive the exact old correction fingerprints affected by the sealed Registry touch.

    HDM fingerprints authorize the metadata mutation; they are not the old batch
    fingerprints whose subject projections became stale.  This derivation keeps
    those identities separate and binds each old fingerprint to exactly one
    changed component and its committed prior record.
    """

    failures: list[str]=[]; targets: dict[str,dict[str,str]]={}; component_to_fp: dict[str,str]={}
    current_match=re.fullmatch(re.escape(FULL_BATCH_ROOT)+r"batch-([0-9]{3})/batch-\1-manifest\.json",current_batch_path)
    if current_match is None:
        return {},["SPR_TARGET_CURRENT_BATCH_PATH_INVALID"]
    current_number=int(current_match.group(1)); expected_numbers=set(range(1,current_number+1)); prefix: list[tuple[int,str,dict[str,Any]]]=[]
    for relative,entry in batches.items():
        match=re.fullmatch(re.escape(FULL_BATCH_ROOT)+r"batch-([0-9]{3})/batch-\1-manifest\.json",relative)
        if match is None: continue
        number=int(match.group(1))
        if number<=current_number: prefix.append((number,relative,entry))
    if {number for number,_,_ in prefix}!=expected_numbers:
        failures.append("SPR_TARGET_BATCH_PREFIX_INCOMPLETE")
    for _,_,entry in sorted(prefix):
        batch=entry.get("document",{})
        bindings=batch.get("record_bindings",[]) if isinstance(batch,dict) else []
        if not isinstance(bindings,list): failures.append("SPR_TARGET_BATCH_BINDINGS_INVALID"); continue
        for binding in bindings:
            if not isinstance(binding,dict): failures.append("SPR_TARGET_BATCH_BINDING_NOT_OBJECT"); continue
            prior_path=str(binding.get("path",""))
            try: prior,raw=_committed_document(root,evaluated_head,prior_path)
            except Exception: failures.append(f"SPR_TARGET_PRIOR_RECORD_UNREADABLE:{prior_path}"); continue
            if binding.get("record_sha256")!=sha256_bytes(raw) or binding.get("record_payload_sha256")!=prior.get("record_payload_sha256"):
                failures.append(f"SPR_TARGET_PRIOR_RECORD_BINDING_INVALID:{prior_path}"); continue
            fingerprints=binding.get("failure_fingerprints",[]); identities=prior.get("identity_binding_by_failure",{})
            if not isinstance(fingerprints,list) or not isinstance(identities,dict):
                failures.append(f"SPR_TARGET_PRIOR_IDENTITY_SET_INVALID:{prior_path}"); continue
            for value in fingerprints:
                fingerprint=str(value); identity=identities.get(fingerprint)
                if not isinstance(identity,dict): failures.append(f"SPR_TARGET_PRIOR_IDENTITY_MISSING:{fingerprint}"); continue
                component=str(identity.get("current_component_id",""))
                if component not in authorized_components: continue
                if fingerprint in targets: failures.append(f"SPR_TARGET_FINGERPRINT_DUPLICATE:{fingerprint}"); continue
                if component in component_to_fp: failures.append(f"SPR_TARGET_COMPONENT_DUPLICATE:{component}"); continue
                targets[fingerprint]={"component_id":component,"prior_record_path":prior_path}
                component_to_fp[component]=fingerprint
    if len(targets)!=82 or set(component_to_fp)!=authorized_components:
        failures.append("SPR_TARGET_SET_NOT_EXACT_82")
    return ({} if failures else targets),sorted(set(failures))


def subject_projection(root: Path, commit: str, selector: dict[str,Any]) -> dict[str,Any]:
    failures=selector_failures(selector)
    if failures: raise ValueError(";".join(failures))
    registry=strict_json_bytes(_blob(root,commit,REGISTRY_PATH) or b""); supersession=strict_json_bytes(_blob(root,commit,SUPERSESSION_PATH) or b""); dynamic=strict_json_bytes(_blob(root,commit,DYNAMIC_REFERENCE_PATH) or b""); owner=_blob(root,commit,OWNER_MAP_PATH)
    if not isinstance(registry,dict) or not isinstance(supersession,dict) or not isinstance(dynamic,dict) or owner is None: raise ValueError("projection authority")
    components=set(selector["component_ids"]); paths=set(selector["paths"]); registry_rows=[]
    for key in ("component_inventory","historical_identity_backfill"):
        for row in registry.get(key,[]) if isinstance(registry.get(key,[]),list) else []:
            if isinstance(row,dict) and (row.get("component_id") in components or row.get("path") in paths): tagged=dict(row); tagged["authority_source_kind"]=key; registry_rows.append(tagged)
    supersession_rows=[]
    for key in ("entries","retirement_entries"):
        for row in supersession.get(key,[]) if isinstance(supersession.get(key,[]),list) else []:
            if isinstance(row,dict) and (row.get("supersession_id") in set(selector["supersession_ids"]) or row.get("retirement_id") in set(selector["retirement_ids"])): supersession_rows.append(row)
    dynamic_rows=[r for r in dynamic.get("entries",[]) if isinstance(r,dict) and r.get("dynamic_reference_id") in set(selector["dynamic_reference_ids"])] if isinstance(dynamic.get("entries",[]),list) else []
    needles=sorted({str(v) for values in selector.values() for v in values if v}); owner_lines=sorted({line.rstrip() for line in owner.decode("utf-8-sig","replace").splitlines() if any(n in line for n in needles)})
    result={"dynamic_reference_rows":sorted(dynamic_rows,key=canonical_bytes),"owner_map_lines":owner_lines,"registry_rows":sorted(registry_rows,key=canonical_bytes),"supersession_rows":sorted(supersession_rows,key=canonical_bytes)}
    if not any(result.values()): raise ValueError("unresolved selector")
    return result


def _touches(root: Path, old: str, new: str, path: str) -> list[str]:
    try: return [x for x in str(_git(root,"rev-list","--reverse",f"{old}..{new}","--",path)).splitlines() if x]
    except Exception: return []


def projection_changing_commits(root: Path, old: str, new: str, selector: dict[str,Any]) -> list[str]:
    commits=[x for x in str(_git(root,"rev-list","--reverse",f"{old}..{new}","--",*AUTHORITY_PATHS)).splitlines() if x]; changed=[]
    for commit in commits:
        parent=str(_git(root,"rev-parse",f"{commit}^1"))
        if subject_projection(root,parent,selector)!=subject_projection(root,commit,selector): changed.append(commit)
    return changed


def _prior_membership(batch: dict[str,Any], record: dict[str,Any], fp: str) -> bool:
    matches=[]
    for binding in batch.get("record_bindings",[]) if isinstance(batch.get("record_bindings",[]),list) else []:
        if isinstance(binding,dict) and binding.get("path")==record.get("prior_record_path") and binding.get("correction_id")==record.get("prior_correction_id") and binding.get("record_sha256")==record.get("prior_record_sha256") and binding.get("record_payload_sha256")==record.get("prior_record_payload_sha256") and fp in binding.get("failure_fingerprints",[]): matches.append(binding)
    return len(matches)==1


def _changed_component(old: dict[str,Any], new: dict[str,Any]) -> tuple[set[str],dict[str,set[str]]]:
    def rows(projection:dict[str,Any])->dict[str,dict[str,Any]]:
        return {str(r.get("component_id")):r for r in projection["registry_rows"] if isinstance(r,dict) and r.get("component_id")}
    a=rows(old); b=rows(new); components={c for c in set(a)|set(b) if a.get(c)!=b.get(c)}; fields={}; missing=object()
    for c in components:
        if c in a and c in b: fields[c]={k for k in set(a[c])|set(b[c]) if a[c].get(k,missing)!=b[c].get(k,missing)}
        else: fields[c]={"__row_added_or_removed__"}
    return components,fields


def validate_manifest_and_records(root: Path, manifest_path: Path, *, evaluated_head: str,
                                  current_batch_manifest_path: Path,
                                  explicit_batch_manifest_paths: Iterable[Path]) -> dict[str,Any]:
    root=root.resolve(); failures:list[str]=[]; trusted:dict[str,dict[str,Any]]={}; manifest:dict[str,Any]={}
    try:
        evaluated=str(_git(root,"rev-parse",evaluated_head))
        if evaluated!=evaluated_head or not _sha(evaluated,40): failures.append("SPR_EVALUATED_HEAD_NOT_EXACT")
        grafts=Path(str(_git(root,"rev-parse","--git-path","info/grafts")))
        if not grafts.is_absolute(): grafts=root/grafts
        if grafts.is_file() and grafts.read_bytes().strip(): failures.append("SPR_GIT_GRAFTS_FORBIDDEN")
    except Exception:
        return {"status":"FAIL","failures":["SPR_EVALUATED_HEAD_UNRESOLVED"],"trusted_by_fingerprint":{},"record_count":0,"fingerprints":[]}
    try:
        schema,schema_raw=_committed_document(root,evaluated_head,SCHEMA_PATH)
        failures.extend(validate_schema_document(schema))
        if sha256_bytes(schema_raw)!=SCHEMA_SHA256: failures.append("SPR_SCHEMA_COMMITTED_SHA_INVALID")
    except Exception: failures.append("SPR_SCHEMA_COMMITTED_BYTES_INVALID")
    try:
        manifest_rel,_=_repo_path(root,manifest_path)
        if not manifest_rel.startswith(MANIFEST_ROOT) or manifest_rel.startswith(RECORD_ROOT): failures.append("SPR_MANIFEST_PATH_SCOPE_INVALID")
        manifest,manifest_raw=_committed_document(root,evaluated_head,manifest_rel)
        failures.extend(validate_manifest_document(manifest))
    except Exception:
        failures.append("SPR_MANIFEST_COMMITTED_BYTES_INVALID"); manifest={}; manifest_raw=b""
    batches,batch_failures=validate_explicit_batch_chain(root,evaluated_head,explicit_batch_manifest_paths); failures.extend(batch_failures)
    try: selected_rel,_=_repo_path(root,current_batch_manifest_path)
    except Exception: selected_rel=""; failures.append("SPR_CURRENT_BATCH_PATH_INVALID")
    if selected_rel!=CURRENT_BATCH_PATH or manifest.get("current_batch_manifest_path")!=selected_rel or selected_rel not in batches: failures.append("SPR_CURRENT_BATCH_NOT_EXPLICIT")
    elif manifest.get("current_batch_manifest_sha256")!=batches[selected_rel]["sha256"]: failures.append("SPR_CURRENT_BATCH_SHA_INVALID")
    transition,transition_failures=audit_authority_transition(root,evaluated_head=evaluated_head); failures.extend(transition_failures)
    hdm,hdm_failures=validate_hdm_authority(root,evaluated_head); failures.extend(hdm_failures)
    if manifest.get("historical_delta_metadata_ledger_sha256")!=LEDGER_SHA256: failures.append("SPR_MANIFEST_LEDGER_SHA_INVALID")
    binding_head=str(manifest.get("revalidation_binding_head_sha",""))
    try:
        if not _ancestor(root,AUTHORIZATION_BASE_HEAD,binding_head) or not _ancestor(root,CHANGE_COMMIT,binding_head) or not _ancestor(root,binding_head,evaluated_head): failures.append("SPR_MANIFEST_BINDING_ANCESTRY_INVALID")
        if manifest.get("revalidation_binding_tree_sha")!=_git(root,"rev-parse",f"{binding_head}^{{tree}}"): failures.append("SPR_MANIFEST_BINDING_TREE_INVALID")
    except Exception: failures.append("SPR_MANIFEST_BINDING_UNRESOLVED")
    authorized=set(transition.get("change_class_only",set()))|set(transition.get("change_class_reuse_scan",set()))
    targets,target_failures=derive_revalidation_targets(root,evaluated_head,batches,selected_rel,authorized); failures.extend(target_failures)
    manifest_fps=_fingerprints(manifest.get("failure_fingerprints"),82) or []
    if manifest_fps!=sorted(targets): failures.append("SPR_MANIFEST_NOT_EXACT_PRIOR_INVALIDATION_SET")
    bindings=manifest.get("record_bindings",[]) if isinstance(manifest.get("record_bindings",[]),list) else []
    previous=str(manifest.get("record_chain_start_sha256","")); covered=[]; components=[]; ids=set(); paths=set()
    for index,binding in enumerate(bindings):
        record_failures:list[str]=[]
        if not isinstance(binding,dict) or set(binding)!=BINDING_FIELDS: failures.append(f"SPR_BINDING_FIELDS_INVALID:{index}"); continue
        relative=str(binding.get("path",""))
        if not _exact_path(relative) or not relative.startswith(RECORD_ROOT) or relative in paths: record_failures.append("SPR_RECORD_PATH_INVALID")
        paths.add(relative)
        try: record,raw=_committed_document(root,evaluated_head,relative)
        except Exception: failures.append(f"SPR_RECORD_COMMITTED_BYTES_INVALID:{index}"); continue
        record_failures.extend(validate_record_document(record))
        rfps=_fingerprints(record.get("failure_fingerprints"),1) or []
        if len(rfps)!=1: failures.append(f"SPR_RECORD_FINGERPRINT_INVALID:{index}"); continue
        fp=rfps[0]; covered.append(fp); component=str(record.get("component_id","")); components.append(component)
        target=targets.get(fp,{})
        if target.get("component_id")!=component or target.get("prior_record_path")!=record.get("prior_record_path"):
            record_failures.append("SPR_RECORD_NOT_EXACT_DERIVED_TARGET")
        if binding.get("record_sha256")!=sha256_bytes(raw): record_failures.append("SPR_RECORD_BYTE_SHA_INVALID")
        for key in ("record_payload_sha256","revalidation_id","prior_record_path","prior_record_sha256","prior_record_payload_sha256","prior_correction_id","failure_fingerprints","previous_revalidation_chain_sha256"):
            expected=record.get(key) if key!="failure_fingerprints" else [fp]
            if binding.get(key)!=expected: record_failures.append(f"SPR_BINDING_RECORD_MISMATCH:{key}")
        if record.get("previous_revalidation_chain_sha256")!=previous: record_failures.append("SPR_RECORD_CHAIN_BREAK")
        previous=str(record.get("record_payload_sha256","")); rid=str(record.get("revalidation_id",""))
        if rid in ids: record_failures.append("SPR_REVALIDATION_ID_DUPLICATE")
        ids.add(rid)
        batch_rel=str(record.get("correction_batch_manifest_path","")); batch_entry=batches.get(batch_rel)
        if not batch_entry or record.get("correction_batch_manifest_sha256")!=batch_entry.get("sha256"): record_failures.append("SPR_PRIOR_BATCH_NOT_EXPLICIT")
        try: prior,prior_raw=_committed_document(root,evaluated_head,str(record.get("prior_record_path","")))
        except Exception: prior={}; prior_raw=b""; record_failures.append("SPR_PRIOR_RECORD_COMMITTED_BYTES_INVALID")
        if sha256_bytes(prior_raw)!=record.get("prior_record_sha256") or prior.get("record_payload_sha256")!=record.get("prior_record_payload_sha256") or prior.get("correction_id")!=record.get("prior_correction_id"): record_failures.append("SPR_PRIOR_RECORD_BINDING_INVALID")
        if batch_entry and not _prior_membership(batch_entry["document"],record,fp): record_failures.append("SPR_PRIOR_MEMBERSHIP_NOT_EXACT")
        try: identity=prior["identity_binding_by_failure"][fp]
        except Exception: identity={}; record_failures.append("SPR_PRIOR_IDENTITY_UNRESOLVED")
        selector=record.get("authority_selectors")
        if selector!=identity.get("authority_selectors"): record_failures.append("SPR_SELECTOR_NOT_PRIOR_EXACT")
        if isinstance(selector,dict) and record.get("authority_selector_sha256")!=sha256_bytes(canonical_bytes(selector)): record_failures.append("SPR_SELECTOR_HASH_INVALID")
        prior_head=str(record.get("prior_binding_head_sha",""))
        if prior_head!=prior.get("binding_head_sha") or record.get("prior_binding_tree_sha")!=prior.get("binding_tree_sha") or record.get("revalidation_binding_head_sha")!=binding_head or record.get("revalidation_binding_tree_sha")!=manifest.get("revalidation_binding_tree_sha"): record_failures.append("SPR_RECORD_HEAD_TREE_BINDING_INVALID")
        if component!=identity.get("current_component_id"): record_failures.append("SPR_COMPONENT_NOT_PRIOR_SUBJECT")
        try:
            if not _ancestor(root,prior_head,CHANGE_PARENT): record_failures.append("SPR_PRIOR_NOT_CHANGE_ANCESTOR")
            old=subject_projection(root,prior_head,selector); rebound=subject_projection(root,binding_head,selector); live=subject_projection(root,evaluated_head,selector)
            if projection_changing_commits(root,prior_head,evaluated_head,selector)!=[CHANGE_COMMIT]: record_failures.append("SPR_PROJECTION_CHANGE_COMMIT_NOT_UNIQUE")
        except Exception: old={}; rebound={}; live={}; record_failures.append("SPR_PROJECTION_RECOMPUTE_FAILED")
        if identity.get("subject_projection")!=old or identity.get("subject_projection_sha256")!=sha256_bytes(canonical_bytes(old)) or record.get("prior_subject_projection")!=old or record.get("prior_subject_projection_sha256")!=sha256_bytes(canonical_bytes(old)): record_failures.append("SPR_PRIOR_PROJECTION_INVALID")
        if record.get("rebound_subject_projection")!=rebound or record.get("rebound_subject_projection_sha256")!=sha256_bytes(canonical_bytes(rebound)) or live!=rebound: record_failures.append("SPR_REBOUND_PROJECTION_INVALID")
        if old and rebound and any(old.get(k)!=rebound.get(k) for k in PROJECTION_FIELDS-{"registry_rows"}): record_failures.append("SPR_NON_REGISTRY_PROJECTION_CHANGED")
        try: changed,fields=_changed_component(old,rebound)
        except Exception: changed=set(); fields={}
        expected_fields={"change_class","reuse_scan"} if component in REUSE_COMPONENTS else {"change_class"}; expected_profile="CHANGE_CLASS_AND_REUSE_SCAN" if component in REUSE_COMPONENTS else "CHANGE_CLASS_ONLY"
        if changed!={component} or fields.get(component)!=expected_fields or record.get("change_profile")!=expected_profile or record.get("changed_metadata_fields")!=PROFILE_FIELDS[expected_profile]: record_failures.append("SPR_COMPONENT_CHANGE_NOT_EXACT")
        if record.get("component_identity_hdm_authority")!=hdm.get("identity_by_component",{}).get(component): record_failures.append("SPR_IDENTITY_HDM_BINDING_INVALID")
        expected_reuse=hdm.get("reuse_by_component",{}).get(component,{}) if component in REUSE_COMPONENTS else {}
        if record.get("reuse_scan_hdm_authority")!=expected_reuse: record_failures.append("SPR_REUSE_HDM_BINDING_INVALID")
        bound={str(identity.get(k)) for k in ("historical_path","current_path") if identity.get(k)}; blob_map=record.get("bound_product_blob_sha256_by_path",{})
        if not isinstance(blob_map,dict) or set(blob_map)!=bound: record_failures.append("SPR_BOUND_PRODUCT_PATH_SET_INVALID")
        for path in bound:
            a=_blob(root,prior_head,path); b=_blob(root,binding_head,path); c=_blob(root,evaluated_head,path); expected=sha256_bytes(a) if a is not None else "MISSING"
            if blob_map.get(path)!=expected or a!=b or a!=c or _touches(root,prior_head,binding_head,path) or _touches(root,binding_head,evaluated_head,path): record_failures.append(f"SPR_BOUND_PRODUCT_PATH_CHANGED:{path}")
        proof=record.get("touch_proof",{}); expected_proof={"commit_sha":CHANGE_COMMIT,"parent_sha":CHANGE_PARENT,"path":REGISTRY_PATH,"before_blob_sha256":BEFORE_REGISTRY_SHA256,"after_blob_sha256":AFTER_REGISTRY_SHA256,"diff_sha256":REGISTRY_DIFF_SHA256}
        if proof!=expected_proof: record_failures.append("SPR_TOUCH_PROOF_INVALID")
        if record_failures: failures.extend(f"{x}:{fp}" for x in record_failures)
        else: trusted[fp]={"allowed_invalidations":[ALLOWED_INVALIDATION],"prior_record_path":record.get("prior_record_path"),"revalidation_id":rid,"record_path":relative,"revalidation_binding_head_sha":binding_head}
    if covered!=manifest_fps or len(set(covered))!=82: failures.append("SPR_RECORD_FINGERPRINT_COVERAGE_INVALID")
    if len(components)!=82 or len(set(components))!=82 or set(components)!=authorized: failures.append("SPR_COMPONENT_BIJECTION_INVALID")
    if previous!=manifest.get("record_chain_terminal_sha256"): failures.append("SPR_CHAIN_TERMINAL_INVALID")
    failures=sorted(set(failures))
    if failures: trusted={}
    return {"status":"PASS" if not failures else "FAIL","failures":failures,"manifest":manifest,"trusted_by_fingerprint":trusted,"record_count":len(bindings),"fingerprints":sorted(set(covered)),"trusted_fingerprint_count":len(trusted)}


def allows_invalidation(trusted_by_fingerprint: dict[str,dict[str,Any]], *, fingerprint: str,
                        invalidation_code: str, prior_record_path: str) -> bool:
    if invalidation_code!=ALLOWED_INVALIDATION or not _exact_path(prior_record_path): return False
    row=trusted_by_fingerprint.get(fingerprint)
    return isinstance(row,dict) and row.get("allowed_invalidations")==[ALLOWED_INVALIDATION] and row.get("prior_record_path")==prior_record_path
