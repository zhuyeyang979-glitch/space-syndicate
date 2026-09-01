#!/usr/bin/env python3
"""Independent fail-closed audit for the subject-projection successor v2.

This module deliberately does not import or invoke the primary validator.  It
re-parses every JSON document, recomputes Git ancestry/trees/blobs/diffs,
rebuilds all four subject projections, proves prior-record membership, and
checks the product path is byte-identical and untouched.  External stages are
review-only and can never populate committed trust.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import stat
import subprocess
from pathlib import Path, PurePosixPath
from typing import Any, Iterable

AUTHORIZATION_ID = "USER_AUTHORIZATION_V076_REUSE_FULL_CONVERGENCE_AND_MCP_ONLY_20260827"
AUTHORIZATION_BASE_HEAD = "d701a81dce693b584d52fbfca3e0e78b521ad775"
PRIOR_EPOCH_ID = "FULL_CONVERGENCE_20260827"
SCHEMA_VERSION = "space_syndicate.v076.reuse_exact_failure_correction.v2.subject_projection_revalidation_successor_v2_schema.v1"
MANIFEST_SCHEMA_VERSION = "space_syndicate.v076.reuse_exact_failure_correction.v2.subject_projection_revalidation_successor_v2_manifest.v1"
RECORD_SCHEMA_VERSION = "space_syndicate.v076.reuse_exact_failure_correction.v2.subject_projection_revalidation_successor_v2_record.v1"
MANIFEST_KIND = "SUBJECT_PROJECTION_REVALIDATION_SUCCESSOR_V2_MANIFEST"
RECORD_KIND = "SUBJECT_PROJECTION_REVALIDATION_SUCCESSOR_V2_RECORD"
MANIFEST_ID = "V076-SUBJECT-PROJECTION-REVALIDATION-SUCCESSOR-V2-20260829"
SCHEMA_PATH = "docs/architecture/reuse_corrections/v2/schema_subject_projection_revalidation_successor_v2_20260829.json"
SCHEMA_SHA256 = "21074fca254e4dad61b781f6c087d5a337b50efaa4fb3151a1d5c6afa8e17355"

PREDECESSOR_MANIFEST_PATH = "docs/architecture/reuse_corrections/v2/subject_projection_revalidation/manifest.json"
PREDECESSOR_MANIFEST_SHA256 = "dff148179980c4e49f277a516bf7f1d0670f4d8b02a40e0f95b077ed92e0967e"
PREDECESSOR_RECORD_COUNT = 82
PREDECESSOR_CHAIN_TERMINAL_SHA256 = "c36b968b316fd3c9153d07d2d07c1ddade1d893304b8b282aacdcf8fbb7622ba"
PREDECESSOR_FINGERPRINT_SET_SHA256 = "e688be102bfb94507cbca9377d03693d3e1f5547678e9ead60ae51ae7f937166"
CURRENT_BATCH_PATH = "docs/architecture/reuse_corrections/v2/batches/full_convergence_20260827/batch-008/batch-008-manifest.json"
CURRENT_BATCH_ID = "batch-008"
CURRENT_BATCH_SHA256 = "ce195de78e8c1f52cb7816c468f918b81c2c7fbf5a2c2a79a77f98efd2ecd22b"
CURRENT_BATCH_FINGERPRINT_SET_SHA256 = "276a5082ed1846073ff85a0afa98f4d518bfb6a49906785c4a7037343e6d110e"

BASELINE_HEAD = "a483684e2309a38c92c913584b097bda5c7cd6c7"
CHANGE_PARENT = "38aa38f9881f01d67f94280678ade39b2bbee526"
CHANGE_COMMIT = "4006086fc66d057271a83c1361d715bdfe0d5ae7"
REGISTRY_PATH = "docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json"
SUPERSESSION_PATH = "docs/architecture/V076_SUPERSESSION_MAP.json"
OWNER_MAP_PATH = "docs/architecture/V076_OWNER_REUSE_MAP.md"
DYNAMIC_REFERENCE_PATH = "docs/architecture/V076_DYNAMIC_REFERENCE_MANIFEST.json"
AUTHORITY_PATHS = (REGISTRY_PATH, SUPERSESSION_PATH)
PROJECTION_PATHS = (REGISTRY_PATH, SUPERSESSION_PATH, OWNER_MAP_PATH, DYNAMIC_REFERENCE_PATH)
BEFORE_SHA256 = {
    REGISTRY_PATH: "a0debdbc7fed8cd17803587c0947ac01d33a959d65f967d0fb2fd07f7bfe6a66",
    SUPERSESSION_PATH: "2b262536cc9dd9cedb34ec4578210fb57c737e1e4735675cebcac73623ea0451",
}
AFTER_SHA256 = {
    REGISTRY_PATH: "9b2eb0aac38e8db38258f5f71d0436ff9e016c4b76fc46f8b82d4c9688b922d7",
    SUPERSESSION_PATH: "e18b7d6eb47de0d2e4cc3f6e6f829e476afdfe5f9f3cc2c1741d2d1d726b330f",
}
DIFF_SHA256 = {
    REGISTRY_PATH: "ca85b885d82fb6b4523c62782faccfae491dc43231174124e3f8117248a88ccd",
    SUPERSESSION_PATH: "7e24735d6a78c2ea918f8a0aa2487dc882f82fdea88de8afec32c978cd2636af",
}
COMBINED_DIFF_SHA256 = "830528328a08ccaf43d88623754725b3b2cd0273ef12bcb09275d3c3ac30e921"
OWNER_MAP_SHA256 = "44daa51a44fb0f663976af83e00a606f1f77a406fed45c7027ed0eabc5a25f6b"
DYNAMIC_REFERENCE_SHA256 = "52472d87729ab167ab31b785a12b2be246ede798a03c9d3bee22bb740062ecd7"

TARGET_FINGERPRINTS = (
    "V2F-48c2308416d22a41a3a38071e4bac92bbbb68e59c0931a5328b4e1aaf3616176",
    "V2F-7f5052fb7759b9e44d51872fc8490f89119d327518c5a64559c02a97db829416",
)
TARGET_COMPONENT = "component.current.alpha01_content_manifest"
TARGET_SELECTOR = {
    "component_ids": ["component.current.alpha01_content_manifest", "component.current.v075_runtime_owner"],
    "dynamic_reference_ids": [],
    "paths": ["resources/content/alpha01/alpha01_content_manifest.tres"],
    "retirement_ids": [],
    "supersession_ids": [],
}
PRODUCT_PATH = "resources/content/alpha01/alpha01_content_manifest.tres"
PRODUCT_BLOB_SHA256 = "302bffb7912b2890ef8b02e37dc85f9d011341dde2d5d5aa2a3685f0245902ff"
PRIOR_PROJECTION_SHA256 = "8c2071dfe5cb53b856cd6ef66ecd59293ec57ba8da1e8e3b4b29e9e4380b6a95"
REBOUND_PROJECTION_SHA256 = "6aab57b551f1be53cbad0b629e2d5825863c552ecb1a68931238d6129505a458"
ALLOWED_INVALIDATION = "SUBJECT_PROJECTION_CHANGED_INVALID"
FUTURE_POLICY = {"FUTURE_FAILURE_AUTO_REVALIDATION_COUNT": 0, "NEW_FAILURE_REQUIRES_NEW_RECORD": True}
SUCCESSOR_ROOT = "docs/architecture/reuse_corrections/v2/subject_projection_revalidation_successor_v2/"
RECORD_ROOT = SUCCESSOR_ROOT + "records/"
FULL_RECORD_ROOT = "docs/architecture/reuse_corrections/v2/records/full_convergence_20260827/"
PRIOR_RECORD_PATHS = {
    TARGET_FINGERPRINTS[0]: FULL_RECORD_ROOT + "batch-003/transition_46b33bba77b3_e584cd4d8b0c_production-reachable.json",
    TARGET_FINGERPRINTS[1]: FULL_RECORD_ROOT + "batch-003/transition_d701a81dce69_0d2a2b798f32_production-reachable.json",
}
PRIOR_RECORD_SHA256 = {
    TARGET_FINGERPRINTS[0]: "a19bf7e62150dd019b1ef00294b701b4ddb66afec4edd270195856aba106cabc",
    TARGET_FINGERPRINTS[1]: "0d6a62f7901e6e53308a3470665e39f6beb56736fe39155d5eb6d4a3ec6e2eef",
}
PRIOR_RECORD_PAYLOAD_SHA256 = {
    TARGET_FINGERPRINTS[0]: "64eb6c6c59f994f0351c3408e9be557422be24ef3af75d62923394f0afec2584",
    TARGET_FINGERPRINTS[1]: "c4baca6e8e2a62c7da2a814a67b40446791a3bcbdee9844d316704c05fc20f1d",
}
PRIOR_CORRECTION_IDS = {
    TARGET_FINGERPRINTS[0]: "V2-FC-batch-003-05-46b33bba77b3-e584cd4d8b0c-production_reachable",
    TARGET_FINGERPRINTS[1]: "V2-FC-batch-003-09-d701a81dce69-0d2a2b798f32-production_reachable",
}
PRIOR_BATCH_PATH = "docs/architecture/reuse_corrections/v2/batches/full_convergence_20260827/batch-003/batch-003-manifest.json"
PRIOR_BATCH_SHA256 = "dd831d070d896a8f4c3e0b8d87663533fd6035068b64a29b8a28b23b879efdf5"
EXPECTED_RECORD_PATHS = {fp: RECORD_ROOT + "spr2-" + fp[4:] + ".json" for fp in TARGET_FINGERPRINTS}
EXPECTED_REVALIDATION_IDS = {fp: "V076-SPR2-" + fp[4:20].upper() for fp in TARGET_FINGERPRINTS}

SELECTOR_FIELDS = frozenset({"component_ids", "paths", "dynamic_reference_ids", "supersession_ids", "retirement_ids"})
PROJECTION_FIELDS = frozenset({"dynamic_reference_rows", "owner_map_lines", "registry_rows", "supersession_rows"})
MANIFEST_FIELDS = frozenset("""schema_version manifest_kind manifest_id artifact_root_kind authorization_id authorization_base_head_sha prior_epoch_id schema_path schema_sha256 predecessor_manifest_path predecessor_manifest_sha256 predecessor_record_count predecessor_record_chain_terminal_sha256 predecessor_failure_fingerprint_set_sha256 current_batch_manifest_path current_batch_manifest_sha256 current_batch_id current_batch_failure_fingerprint_set_sha256 revalidation_binding_head_sha revalidation_binding_tree_sha authority_baseline_head_sha authority_baseline_tree_sha authority_transition_parent_sha authority_transition_parent_tree_sha authority_transition_commit_sha authority_transition_commit_tree_sha authority_source_paths authority_source_changed_path_count authority_source_before_blob_sha256_by_path authority_source_after_blob_sha256_by_path authority_source_diff_sha256_by_path combined_authority_diff_sha256 baseline_parent_authority_bytes_equal registry_added_row_count registry_added_component_id product_blob_sha256_by_path record_count failure_fingerprints failure_fingerprint_set_sha256 record_chain_start_sha256 record_chain_terminal_sha256 allowed_invalidation future_failure_auto_revalidation wildcard_count created_at creator record_bindings""".split())
RECORD_FIELDS = frozenset("""schema_version record_kind revalidation_id authorization_id authorization_base_head_sha prior_epoch_id failure_fingerprints failure_fingerprint_set_sha256 prior_invalidations prior_record_path prior_record_sha256 prior_record_payload_sha256 prior_correction_id prior_batch_manifest_path prior_batch_manifest_sha256 prior_batch_id predecessor_manifest_path predecessor_manifest_sha256 predecessor_record_chain_terminal_sha256 previous_revalidation_chain_sha256 revalidation_binding_head_sha revalidation_binding_tree_sha authority_selectors authority_selector_sha256 component_id prior_identity_binding prior_subject_projection prior_subject_projection_sha256 pre_change_subject_projection pre_change_subject_projection_sha256 rebound_subject_projection rebound_subject_projection_sha256 live_subject_projection live_subject_projection_sha256 changed_projection_sections added_registry_rows authority_transition_proof bound_product_blob_sha256_by_path future_failure_policy wildcard_count new_effective_status revalidation_reason created_at creator record_payload_sha256""".split())
BINDING_FIELDS = frozenset("""path record_sha256 record_payload_sha256 revalidation_id failure_fingerprints prior_record_path prior_record_sha256 prior_record_payload_sha256 prior_correction_id previous_revalidation_chain_sha256""".split())
PROOF_FIELDS = frozenset("""commit_sha parent_sha baseline_head_sha before_sha256_by_path after_sha256_by_path diff_sha256_by_path combined_diff_sha256 baseline_parent_authority_bytes_equal""".split())
TRUST_ROW_FIELDS = frozenset({"allowed_invalidations", "prior_record_path", "revalidation_id", "record_path", "revalidation_binding_head_sha"})


class DuplicateKeyError(ValueError):
    pass


def _pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise DuplicateKeyError(key)
        result[key] = value
    return result


def _constant(value: str) -> Any:
    raise ValueError(f"non-finite JSON number: {value}")


def _json_bytes(raw: bytes) -> Any:
    return json.loads(raw.decode("utf-8-sig"), object_pairs_hook=_pairs, parse_constant=_constant)


def _canonical(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False) + "\n").encode("utf-8")


def _digest(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def _set_digest(values: Iterable[str]) -> str:
    return _digest(("\n".join(sorted(str(value) for value in values)) + "\n").encode("utf-8"))


def _sha(value: Any, length: int = 64) -> bool:
    return isinstance(value, str) and re.fullmatch(rf"[0-9a-f]{{{length}}}", value) is not None


def _path(value: Any) -> bool:
    if not isinstance(value, str) or not value or value.startswith(("/", "\\")) or value.endswith(("/", "\\")):
        return False
    if "\\" in value or ":" in value or "\0" in value or any(token in value for token in ("*", "?", "[", "]")):
        return False
    parts = PurePosixPath(value).parts
    return bool(parts) and "/".join(parts) == value and all(part not in ("", ".", "..") for part in parts)


def _timestamp(value: Any) -> bool:
    return isinstance(value, str) and re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z", value) is not None


def _fingerprints(value: Any, count: int) -> list[str] | None:
    if not isinstance(value, list) or len(value) != count or value != sorted(value) or len(set(value)) != count:
        return None
    if any(type(item) is not str or re.fullmatch(r"V2F-[0-9a-f]{64}", item) is None for item in value):
        return None
    return list(value)


def _git(root: Path, *args: str, binary: bool = False) -> bytes | str:
    env = os.environ.copy()
    env["GIT_NO_REPLACE_OBJECTS"] = "1"
    proc = subprocess.run(["git", "--no-replace-objects", "-C", str(root), *args], stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env, check=False)
    if proc.returncode:
        raise ValueError(proc.stderr.decode("utf-8", "replace").strip())
    return proc.stdout if binary else proc.stdout.decode("utf-8", "replace").strip()


def _blob(root: Path, commit: str, relative: str) -> bytes | None:
    try:
        return _git(root, "cat-file", "blob", f"{commit}:{relative}", binary=True)  # type: ignore[return-value]
    except ValueError:
        return None


def _ancestor(root: Path, older: str, newer: str) -> bool:
    proc = subprocess.run(["git", "--no-replace-objects", "-C", str(root), "merge-base", "--is-ancestor", older, newer], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    return proc.returncode == 0


def _committed_local(root: Path, head: str, relative: str) -> tuple[Any, bytes]:
    if not _path(relative):
        raise ValueError("unsafe path")
    raw = _blob(root, head, relative)
    local = root / relative
    if raw is None or not local.is_file() or local.read_bytes() != raw:
        raise ValueError("committed/local mismatch")
    return _json_bytes(raw), raw


def _json_at(root: Path, commit: str, relative: str) -> Any:
    raw = _blob(root, commit, relative)
    if raw is None:
        raise ValueError(relative)
    return _json_bytes(raw)


def _selector_findings(selector: Any) -> list[str]:
    if not isinstance(selector, dict) or set(selector) != SELECTOR_FIELDS:
        return ["SPR2_AUDIT_SELECTOR_FIELD_SET_INVALID"]
    findings: list[str] = []
    for key in sorted(SELECTOR_FIELDS):
        rows = selector.get(key)
        if not isinstance(rows, list) or rows != sorted(rows) or len(rows) != len(set(rows)):
            findings.append(f"SPR2_AUDIT_SELECTOR_VALUES_INVALID:{key}")
            continue
        for row in rows:
            if type(row) is not str or not row or any(token in row for token in ("*", "?", "[", "]")):
                findings.append(f"SPR2_AUDIT_SELECTOR_WILDCARD_OR_VALUE_INVALID:{key}")
            elif key == "paths" and not _path(row):
                findings.append(f"SPR2_AUDIT_SELECTOR_PATH_INVALID:{row}")
    if not selector.get("component_ids") and not selector.get("paths"):
        findings.append("SPR2_AUDIT_SELECTOR_EMPTY")
    return sorted(set(findings))


def _projection(root: Path, commit: str, selector: dict[str, Any]) -> dict[str, Any]:
    selector_findings = _selector_findings(selector)
    if selector_findings:
        raise ValueError(";".join(selector_findings))
    registry = _json_at(root, commit, REGISTRY_PATH)
    supersession = _json_at(root, commit, SUPERSESSION_PATH)
    dynamic = _json_at(root, commit, DYNAMIC_REFERENCE_PATH)
    owner = _blob(root, commit, OWNER_MAP_PATH)
    if not isinstance(registry, dict) or not isinstance(supersession, dict) or not isinstance(dynamic, dict) or owner is None:
        raise ValueError("authority invalid")
    components = set(selector["component_ids"])
    paths = set(selector["paths"])
    registry_rows: list[dict[str, Any]] = []
    for kind in ("component_inventory", "historical_identity_backfill"):
        rows = registry.get(kind, [])
        if isinstance(rows, list):
            for row in rows:
                if isinstance(row, dict) and (row.get("component_id") in components or row.get("path") in paths):
                    tagged = dict(row)
                    tagged["authority_source_kind"] = kind
                    registry_rows.append(tagged)
    supersession_rows: list[dict[str, Any]] = []
    for kind in ("entries", "retirement_entries"):
        rows = supersession.get(kind, [])
        if isinstance(rows, list):
            for row in rows:
                if isinstance(row, dict) and (row.get("supersession_id") in set(selector["supersession_ids"]) or row.get("retirement_id") in set(selector["retirement_ids"])):
                    supersession_rows.append(row)
    dynamic_rows = []
    if isinstance(dynamic.get("entries"), list):
        dynamic_rows = [row for row in dynamic["entries"] if isinstance(row, dict) and row.get("dynamic_reference_id") in set(selector["dynamic_reference_ids"])]
    needles = sorted({str(item) for values in selector.values() for item in values if item})
    owner_lines = sorted({line.rstrip() for line in owner.decode("utf-8-sig", "replace").splitlines() if any(needle in line for needle in needles)})
    result = {
        "dynamic_reference_rows": sorted(dynamic_rows, key=_canonical),
        "owner_map_lines": owner_lines,
        "registry_rows": sorted(registry_rows, key=_canonical),
        "supersession_rows": sorted(supersession_rows, key=_canonical),
    }
    if not any(result.values()):
        raise ValueError("selector unresolved")
    return result


def _projection_digest(value: dict[str, Any]) -> str:
    return _digest(_canonical(value))


def _added_rows(before: dict[str, Any], after: dict[str, Any]) -> list[dict[str, Any]]:
    old = {_canonical(row) for row in before.get("registry_rows", []) if isinstance(row, dict)}
    return sorted([row for row in after.get("registry_rows", []) if isinstance(row, dict) and _canonical(row) not in old], key=_canonical)


def _schema_findings(root: Path, evaluated_head: str | None) -> list[str]:
    try:
        raw = (root / SCHEMA_PATH).read_bytes()
        document = _json_bytes(raw)
    except Exception:
        return ["SPR2_AUDIT_SCHEMA_UNREADABLE"]
    findings: list[str] = []
    if _digest(raw) != SCHEMA_SHA256:
        findings.append("SPR2_AUDIT_SCHEMA_SHA_INVALID")
    expected_scalar = {
        "schema_version": SCHEMA_VERSION,
        "manifest_schema_version": MANIFEST_SCHEMA_VERSION,
        "record_schema_version": RECORD_SCHEMA_VERSION,
        "manifest_kind": MANIFEST_KIND,
        "record_kind": RECORD_KIND,
        "authorization_id": AUTHORIZATION_ID,
        "authorization_base_head_sha": AUTHORIZATION_BASE_HEAD,
        "prior_epoch_id": PRIOR_EPOCH_ID,
        "predecessor_manifest_path": PREDECESSOR_MANIFEST_PATH,
        "predecessor_record_count": 82,
        "successor_record_count": 2,
        "authority_transition_commit_sha": CHANGE_COMMIT,
        "authority_transition_parent_sha": CHANGE_PARENT,
        "authority_baseline_head_sha": BASELINE_HEAD,
        "authority_source_paths": list(AUTHORITY_PATHS),
        "authority_source_changed_path_count": 2,
        "registry_before_blob_sha256": BEFORE_SHA256[REGISTRY_PATH],
        "registry_after_blob_sha256": AFTER_SHA256[REGISTRY_PATH],
        "registry_diff_sha256": DIFF_SHA256[REGISTRY_PATH],
        "supersession_before_blob_sha256": BEFORE_SHA256[SUPERSESSION_PATH],
        "supersession_after_blob_sha256": AFTER_SHA256[SUPERSESSION_PATH],
        "supersession_diff_sha256": DIFF_SHA256[SUPERSESSION_PATH],
        "combined_authority_diff_sha256": COMBINED_DIFF_SHA256,
        "registry_added_row_count": 1,
        "registry_added_component_id": TARGET_COMPONENT,
        "product_blob_path": PRODUCT_PATH,
        "product_blob_sha256": PRODUCT_BLOB_SHA256,
        "prior_projection_sha256": PRIOR_PROJECTION_SHA256,
        "rebound_projection_sha256": REBOUND_PROJECTION_SHA256,
        "allowed_invalidation": ALLOWED_INVALIDATION,
        "future_failure_policy": FUTURE_POLICY,
        "wildcard_count": 0,
        "future_failure_auto_revalidation": False,
        "artifact_root_kinds": ["EXTERNAL_STAGE_REVIEW", "COMMITTED_SUCCESSOR_ROOT"],
        "target_fingerprints": list(TARGET_FINGERPRINTS),
    }
    required = set(expected_scalar) | {"manifest_required_fields", "record_required_fields", "record_binding_fields", "authority_path_binding_fields", "touch_proof_fields", "projection_fields", "selector_fields", "negative_policy"}
    if not isinstance(document, dict) or set(document) != required:
        findings.append("SPR2_AUDIT_SCHEMA_FIELD_SET_INVALID")
        document = document if isinstance(document, dict) else {}
    for key, value in expected_scalar.items():
        if document.get(key) != value:
            findings.append(f"SPR2_AUDIT_SCHEMA_VALUE_INVALID:{key}")
    expected_lists = {
        "manifest_required_fields": MANIFEST_FIELDS,
        "record_required_fields": RECORD_FIELDS,
        "record_binding_fields": BINDING_FIELDS,
        "projection_fields": PROJECTION_FIELDS,
        "selector_fields": SELECTOR_FIELDS,
    }
    for key, expected in expected_lists.items():
        rows = document.get(key)
        if not isinstance(rows, list) or len(rows) != len(set(rows)) or set(rows) != set(expected):
            findings.append(f"SPR2_AUDIT_SCHEMA_LIST_INVALID:{key}")
    if set(document.get("authority_path_binding_fields", [])) != {"path", "before_blob_sha256", "after_blob_sha256", "diff_sha256"}:
        findings.append("SPR2_AUDIT_SCHEMA_AUTHORITY_FIELDS_INVALID")
    if set(document.get("touch_proof_fields", [])) != {"commit_sha", "parent_sha", "path", "before_blob_sha256", "after_blob_sha256", "diff_sha256"}:
        findings.append("SPR2_AUDIT_SCHEMA_TOUCH_FIELDS_INVALID")
    negatives = {"NO_WILDCARD", "NO_FUTURE_FAILURE_AUTO_TRUST", "NO_PRODUCT_BLOB_CHANGE", "NO_PRODUCT_PATH_TOUCH", "NO_AUTHORITY_PATH_OMISSION", "NO_TRUST_OVERLAP", "NO_STAGE_AS_COMMITTED_TRUST"}
    if not isinstance(document.get("negative_policy"), list) or len(document["negative_policy"]) != len(set(document["negative_policy"])) or set(document["negative_policy"]) != negatives:
        findings.append("SPR2_AUDIT_SCHEMA_NEGATIVE_POLICY_INVALID")
    if evaluated_head is not None and _blob(root, evaluated_head, SCHEMA_PATH) != raw:
        findings.append("SPR2_AUDIT_SCHEMA_NOT_COMMITTED_EXACT")
    return sorted(set(findings))


def _manifest_findings(document: Any) -> list[str]:
    if not isinstance(document, dict):
        return ["SPR2_AUDIT_MANIFEST_NOT_OBJECT"]
    findings: list[str] = []
    if set(document) != MANIFEST_FIELDS:
        findings.append("SPR2_AUDIT_MANIFEST_FIELD_SET_INVALID")
    expected = {
        "schema_version": MANIFEST_SCHEMA_VERSION,
        "manifest_kind": MANIFEST_KIND,
        "manifest_id": MANIFEST_ID,
        "authorization_id": AUTHORIZATION_ID,
        "authorization_base_head_sha": AUTHORIZATION_BASE_HEAD,
        "prior_epoch_id": PRIOR_EPOCH_ID,
        "schema_path": SCHEMA_PATH,
        "schema_sha256": SCHEMA_SHA256,
        "predecessor_manifest_path": PREDECESSOR_MANIFEST_PATH,
        "predecessor_manifest_sha256": PREDECESSOR_MANIFEST_SHA256,
        "predecessor_record_count": PREDECESSOR_RECORD_COUNT,
        "predecessor_record_chain_terminal_sha256": PREDECESSOR_CHAIN_TERMINAL_SHA256,
        "predecessor_failure_fingerprint_set_sha256": PREDECESSOR_FINGERPRINT_SET_SHA256,
        "current_batch_manifest_path": CURRENT_BATCH_PATH,
        "current_batch_manifest_sha256": CURRENT_BATCH_SHA256,
        "current_batch_id": CURRENT_BATCH_ID,
        "current_batch_failure_fingerprint_set_sha256": CURRENT_BATCH_FINGERPRINT_SET_SHA256,
        "authority_baseline_head_sha": BASELINE_HEAD,
        "authority_transition_parent_sha": CHANGE_PARENT,
        "authority_transition_commit_sha": CHANGE_COMMIT,
        "authority_source_paths": list(AUTHORITY_PATHS),
        "authority_source_changed_path_count": 2,
        "authority_source_before_blob_sha256_by_path": BEFORE_SHA256,
        "authority_source_after_blob_sha256_by_path": AFTER_SHA256,
        "authority_source_diff_sha256_by_path": DIFF_SHA256,
        "combined_authority_diff_sha256": COMBINED_DIFF_SHA256,
        "baseline_parent_authority_bytes_equal": True,
        "registry_added_row_count": 1,
        "registry_added_component_id": TARGET_COMPONENT,
        "product_blob_sha256_by_path": {PRODUCT_PATH: PRODUCT_BLOB_SHA256},
        "record_count": 2,
        "failure_fingerprints": list(TARGET_FINGERPRINTS),
        "failure_fingerprint_set_sha256": _set_digest(TARGET_FINGERPRINTS),
        "record_chain_start_sha256": PREDECESSOR_CHAIN_TERMINAL_SHA256,
        "allowed_invalidation": ALLOWED_INVALIDATION,
        "future_failure_auto_revalidation": False,
        "wildcard_count": 0,
    }
    for key, value in expected.items():
        if document.get(key) != value:
            findings.append(f"SPR2_AUDIT_MANIFEST_VALUE_INVALID:{key}")
    if document.get("artifact_root_kind") not in ("EXTERNAL_STAGE_REVIEW", "COMMITTED_SUCCESSOR_ROOT"):
        findings.append("SPR2_AUDIT_MANIFEST_ROOT_KIND_INVALID")
    for key in ("revalidation_binding_head_sha", "revalidation_binding_tree_sha", "authority_baseline_tree_sha", "authority_transition_parent_tree_sha", "authority_transition_commit_tree_sha"):
        if not _sha(document.get(key), 40):
            findings.append(f"SPR2_AUDIT_MANIFEST_OID_INVALID:{key}")
    if not _sha(document.get("record_chain_terminal_sha256")):
        findings.append("SPR2_AUDIT_MANIFEST_CHAIN_TERMINAL_INVALID")
    if not _timestamp(document.get("created_at")) or not isinstance(document.get("creator"), str) or not document.get("creator"):
        findings.append("SPR2_AUDIT_MANIFEST_IDENTITY_INVALID")
    bindings = document.get("record_bindings")
    if not isinstance(bindings, list) or len(bindings) != 2:
        findings.append("SPR2_AUDIT_MANIFEST_BINDING_COUNT_INVALID")
    elif any(not isinstance(binding, dict) or set(binding) != BINDING_FIELDS for binding in bindings):
        findings.append("SPR2_AUDIT_MANIFEST_BINDING_FIELDS_INVALID")
    return sorted(set(findings))


def _record_findings(document: Any) -> list[str]:
    if not isinstance(document, dict):
        return ["SPR2_AUDIT_RECORD_NOT_OBJECT"]
    findings: list[str] = []
    if set(document) != RECORD_FIELDS:
        findings.append("SPR2_AUDIT_RECORD_FIELD_SET_INVALID")
    expected = {
        "schema_version": RECORD_SCHEMA_VERSION,
        "record_kind": RECORD_KIND,
        "authorization_id": AUTHORIZATION_ID,
        "authorization_base_head_sha": AUTHORIZATION_BASE_HEAD,
        "prior_epoch_id": PRIOR_EPOCH_ID,
        "prior_invalidations": [ALLOWED_INVALIDATION],
        "prior_batch_manifest_path": PRIOR_BATCH_PATH,
        "prior_batch_manifest_sha256": PRIOR_BATCH_SHA256,
        "prior_batch_id": "batch-003",
        "predecessor_manifest_path": PREDECESSOR_MANIFEST_PATH,
        "predecessor_manifest_sha256": PREDECESSOR_MANIFEST_SHA256,
        "predecessor_record_chain_terminal_sha256": PREDECESSOR_CHAIN_TERMINAL_SHA256,
        "authority_selectors": TARGET_SELECTOR,
        "authority_selector_sha256": _digest(_canonical(TARGET_SELECTOR)),
        "component_id": TARGET_COMPONENT,
        "changed_projection_sections": ["registry_rows"],
        "bound_product_blob_sha256_by_path": {PRODUCT_PATH: PRODUCT_BLOB_SHA256},
        "future_failure_policy": FUTURE_POLICY,
        "wildcard_count": 0,
        "new_effective_status": "CORRECTED_HISTORICAL_DEBT",
        "revalidation_reason": "REGISTRY_AUTHORITY_SOURCE_METADATA_ONLY_SUCCESSOR_V2",
    }
    for key, value in expected.items():
        if document.get(key) != value:
            findings.append(f"SPR2_AUDIT_RECORD_VALUE_INVALID:{key}")
    fps = _fingerprints(document.get("failure_fingerprints"), 1)
    if fps is None or fps[0] not in TARGET_FINGERPRINTS:
        findings.append("SPR2_AUDIT_RECORD_FINGERPRINT_INVALID")
    elif document.get("failure_fingerprint_set_sha256") != _set_digest(fps):
        findings.append("SPR2_AUDIT_RECORD_FINGERPRINT_HASH_INVALID")
    for key in ("prior_record_sha256", "prior_record_payload_sha256", "prior_batch_manifest_sha256", "predecessor_manifest_sha256", "authority_selector_sha256", "prior_subject_projection_sha256", "pre_change_subject_projection_sha256", "rebound_subject_projection_sha256", "live_subject_projection_sha256", "record_payload_sha256"):
        if not _sha(document.get(key)):
            findings.append(f"SPR2_AUDIT_RECORD_SHA_INVALID:{key}")
    for key in ("revalidation_binding_head_sha", "revalidation_binding_tree_sha"):
        if not _sha(document.get(key), 40):
            findings.append(f"SPR2_AUDIT_RECORD_OID_INVALID:{key}")
    for key in ("prior_subject_projection", "pre_change_subject_projection", "rebound_subject_projection", "live_subject_projection"):
        if not isinstance(document.get(key), dict) or set(document.get(key, {})) != PROJECTION_FIELDS:
            findings.append(f"SPR2_AUDIT_RECORD_PROJECTION_FIELDS_INVALID:{key}")
    if not isinstance(document.get("prior_identity_binding"), dict):
        findings.append("SPR2_AUDIT_RECORD_PRIOR_IDENTITY_INVALID")
    if not isinstance(document.get("added_registry_rows"), list) or len(document.get("added_registry_rows", [])) != 1:
        findings.append("SPR2_AUDIT_RECORD_ADDED_ROWS_INVALID")
    if not isinstance(document.get("authority_transition_proof"), dict) or set(document.get("authority_transition_proof", {})) != PROOF_FIELDS:
        findings.append("SPR2_AUDIT_RECORD_PROOF_FIELDS_INVALID")
    payload = {key: value for key, value in document.items() if key != "record_payload_sha256"}
    try:
        payload_digest = _digest(_canonical(payload))
    except Exception:
        payload_digest = ""
    if document.get("record_payload_sha256") != payload_digest:
        findings.append("SPR2_AUDIT_RECORD_PAYLOAD_INVALID")
    if not _timestamp(document.get("created_at")) or not isinstance(document.get("creator"), str) or not document.get("creator"):
        findings.append("SPR2_AUDIT_RECORD_IDENTITY_INVALID")
    return sorted(set(findings))


def _authority_transition(root: Path, evaluated_head: str) -> tuple[dict[str, Any], list[str]]:
    findings: list[str] = []
    proof: dict[str, Any] = {}
    try:
        if _git(root, "rev-parse", f"{CHANGE_COMMIT}^1") != CHANGE_PARENT:
            findings.append("SPR2_AUDIT_CHANGE_PARENT_INVALID")
        if not _ancestor(root, BASELINE_HEAD, CHANGE_PARENT):
            findings.append("SPR2_AUDIT_BASELINE_PARENT_ANCESTRY_INVALID")
        if not _ancestor(root, CHANGE_COMMIT, evaluated_head):
            findings.append("SPR2_AUDIT_CHANGE_NOT_EVALUATED_ANCESTOR")
        changed = str(_git(root, "diff", "--name-only", CHANGE_PARENT, CHANGE_COMMIT)).splitlines()
        if changed != sorted(AUTHORITY_PATHS):
            findings.append("SPR2_AUDIT_CHANGE_PATH_SET_INVALID")
        before: dict[str, str] = {}
        after: dict[str, str] = {}
        diffs: dict[str, str] = {}
        baseline_equal = True
        for relative in AUTHORITY_PATHS:
            baseline_blob = _blob(root, BASELINE_HEAD, relative)
            parent_blob = _blob(root, CHANGE_PARENT, relative)
            after_blob = _blob(root, CHANGE_COMMIT, relative)
            diff = _git(root, "diff", "--binary", "--no-ext-diff", CHANGE_PARENT, CHANGE_COMMIT, "--", relative, binary=True)
            if baseline_blob is None or parent_blob is None or after_blob is None:
                findings.append(f"SPR2_AUDIT_AUTHORITY_BLOB_MISSING:{relative}")
                continue
            before[relative] = _digest(parent_blob)
            after[relative] = _digest(after_blob)
            diffs[relative] = _digest(diff)
            if baseline_blob != parent_blob:
                baseline_equal = False
                findings.append(f"SPR2_AUDIT_BASELINE_PARENT_BYTES_DRIFT:{relative}")
            if before[relative] != BEFORE_SHA256[relative] or after[relative] != AFTER_SHA256[relative] or diffs[relative] != DIFF_SHA256[relative]:
                findings.append(f"SPR2_AUDIT_AUTHORITY_SEAL_INVALID:{relative}")
        combined = _git(root, "diff", "--binary", "--no-ext-diff", CHANGE_PARENT, CHANGE_COMMIT, "--", *AUTHORITY_PATHS, binary=True)
        if _digest(combined) != COMBINED_DIFF_SHA256:
            findings.append("SPR2_AUDIT_COMBINED_DIFF_INVALID")
        for relative, expected in ((OWNER_MAP_PATH, OWNER_MAP_SHA256), (DYNAMIC_REFERENCE_PATH, DYNAMIC_REFERENCE_SHA256)):
            blobs = [_blob(root, commit, relative) for commit in (BASELINE_HEAD, CHANGE_PARENT, CHANGE_COMMIT, evaluated_head)]
            if any(blob is None or _digest(blob) != expected for blob in blobs):
                findings.append(f"SPR2_AUDIT_UNCHANGED_AUTHORITY_DRIFT:{relative}")
        proof = {
            "commit_sha": CHANGE_COMMIT,
            "parent_sha": CHANGE_PARENT,
            "baseline_head_sha": BASELINE_HEAD,
            "before_sha256_by_path": before,
            "after_sha256_by_path": after,
            "diff_sha256_by_path": diffs,
            "combined_diff_sha256": _digest(combined),
            "baseline_parent_authority_bytes_equal": baseline_equal,
        }
    except Exception as error:
        findings.append(f"SPR2_AUDIT_CHANGE_UNRESOLVED:{type(error).__name__}")
    return proof, sorted(set(findings))


def _predecessor(root: Path, head: str) -> tuple[dict[str, Any], list[str]]:
    try:
        document, raw = _committed_local(root, head, PREDECESSOR_MANIFEST_PATH)
    except Exception:
        return {}, ["SPR2_AUDIT_PREDECESSOR_UNREADABLE"]
    findings: list[str] = []
    if not isinstance(document, dict):
        return {}, ["SPR2_AUDIT_PREDECESSOR_NOT_OBJECT"]
    if _digest(raw) != PREDECESSOR_MANIFEST_SHA256:
        findings.append("SPR2_AUDIT_PREDECESSOR_SHA_INVALID")
    if document.get("record_count") != 82 or document.get("record_chain_terminal_sha256") != PREDECESSOR_CHAIN_TERMINAL_SHA256 or document.get("failure_fingerprint_set_sha256") != PREDECESSOR_FINGERPRINT_SET_SHA256:
        findings.append("SPR2_AUDIT_PREDECESSOR_CONTRACT_INVALID")
    fps = _fingerprints(document.get("failure_fingerprints"), 82)
    if fps is None:
        findings.append("SPR2_AUDIT_PREDECESSOR_FINGERPRINTS_INVALID")
        fps = []
    return {"document": document, "fingerprints": fps}, sorted(set(findings))


def _batch_findings(root: Path, head: str) -> list[str]:
    try:
        document, raw = _committed_local(root, head, CURRENT_BATCH_PATH)
    except Exception:
        return ["SPR2_AUDIT_CURRENT_BATCH_UNREADABLE"]
    findings: list[str] = []
    if _digest(raw) != CURRENT_BATCH_SHA256:
        findings.append("SPR2_AUDIT_CURRENT_BATCH_SHA_INVALID")
    if not isinstance(document, dict) or document.get("batch_id") != CURRENT_BATCH_ID or document.get("failure_fingerprint_set_sha256") != CURRENT_BATCH_FINGERPRINT_SET_SHA256:
        findings.append("SPR2_AUDIT_CURRENT_BATCH_CONTRACT_INVALID")
    return findings


def _prior_record(root: Path, head: str, fingerprint: str) -> tuple[dict[str, Any], list[str]]:
    path = PRIOR_RECORD_PATHS[fingerprint]
    try:
        document, raw = _committed_local(root, head, path)
    except Exception:
        return {}, [f"SPR2_AUDIT_PRIOR_RECORD_UNREADABLE:{fingerprint}"]
    findings: list[str] = []
    if not isinstance(document, dict):
        return {}, [f"SPR2_AUDIT_PRIOR_RECORD_NOT_OBJECT:{fingerprint}"]
    identity = document.get("identity_binding_by_failure", {}).get(fingerprint)
    if not isinstance(identity, dict):
        identity = {}
        findings.append(f"SPR2_AUDIT_PRIOR_IDENTITY_MISSING:{fingerprint}")
    if _digest(raw) != PRIOR_RECORD_SHA256[fingerprint] or document.get("record_payload_sha256") != PRIOR_RECORD_PAYLOAD_SHA256[fingerprint] or document.get("correction_id") != PRIOR_CORRECTION_IDS[fingerprint]:
        findings.append(f"SPR2_AUDIT_PRIOR_RECORD_SEAL_INVALID:{fingerprint}")
    if fingerprint not in document.get("failure_fingerprints", []) or identity.get("authority_selectors") != TARGET_SELECTOR:
        findings.append(f"SPR2_AUDIT_PRIOR_MEMBERSHIP_INVALID:{fingerprint}")
    try:
        batch, batch_raw = _committed_local(root, head, PRIOR_BATCH_PATH)
        if _digest(batch_raw) != PRIOR_BATCH_SHA256:
            findings.append(f"SPR2_AUDIT_PRIOR_BATCH_SHA_INVALID:{fingerprint}")
        matches = [row for row in batch.get("record_bindings", []) if isinstance(row, dict) and row.get("path") == path and row.get("record_sha256") == PRIOR_RECORD_SHA256[fingerprint] and row.get("record_payload_sha256") == PRIOR_RECORD_PAYLOAD_SHA256[fingerprint] and row.get("correction_id") == PRIOR_CORRECTION_IDS[fingerprint] and fingerprint in row.get("failure_fingerprints", [])]
        if len(matches) != 1:
            findings.append(f"SPR2_AUDIT_PRIOR_BATCH_MEMBERSHIP_INVALID:{fingerprint}")
    except Exception:
        findings.append(f"SPR2_AUDIT_PRIOR_BATCH_UNREADABLE:{fingerprint}")
    return {"document": document, "identity": identity}, sorted(set(findings))


def _stage_findings(root: Path, lexical_stage: Path) -> list[str]:
    findings: list[str] = []
    if not os.path.lexists(lexical_stage) or not lexical_stage.is_dir():
        findings.append("SPR2_AUDIT_STAGE_NOT_DIRECTORY")
    try:
        lexical_stage.resolve().relative_to(root.resolve())
        findings.append("SPR2_AUDIT_STAGE_INSIDE_REPOSITORY")
    except ValueError:
        pass
    if lexical_stage.is_symlink():
        findings.append("SPR2_AUDIT_STAGE_SYMLINK")
    try:
        if lexical_stage.lstat().st_file_attributes & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400):
            findings.append("SPR2_AUDIT_STAGE_REPARSE_POINT")
    except (OSError, AttributeError):
        pass
    return sorted(set(findings))


def _artifact(root: Path, stage: Path | None, relative: str) -> Path:
    if not _path(relative):
        raise ValueError("unsafe artifact path")
    if stage is None:
        return (root / relative).resolve()
    if not relative.startswith(RECORD_ROOT):
        raise ValueError("record outside successor root")
    candidate = (stage / relative[len(SUCCESSOR_ROOT) :]).resolve()
    candidate.relative_to(stage.resolve())
    return candidate


def audit_manifest_and_records(
    root: Path,
    manifest_path: Path,
    *,
    evaluated_head: str,
    current_batch_manifest_path: Path,
    explicit_batch_manifest_paths: Iterable[Path],
    stage_dir: Path | None = None,
) -> dict[str, Any]:
    root = root.resolve()
    findings: list[str] = []
    mode = "STAGE_REVIEW" if stage_dir is not None else "COMMITTED"
    if stage_dir is not None:
        lexical = stage_dir.absolute()
        findings.extend(_stage_findings(root, lexical))
        stage_dir = lexical.resolve()
        if manifest_path.resolve() != (stage_dir / "manifest.json").resolve():
            findings.append("SPR2_AUDIT_STAGE_MANIFEST_PATH_INVALID")
    try:
        head = str(_git(root, "rev-parse", evaluated_head))
        if head != evaluated_head or not _sha(head, 40):
            findings.append("SPR2_AUDIT_EVALUATED_HEAD_NOT_EXACT")
    except Exception:
        return {"status": "NO_GO", "mode": mode, "findings": ["SPR2_AUDIT_EVALUATED_HEAD_UNRESOLVED"], "trusted_by_fingerprint": {}, "review_trusted_by_fingerprint": {}, "record_count": 0, "fingerprints": []}
    findings.extend(_schema_findings(root, None if stage_dir is not None else evaluated_head))
    try:
        manifest_raw = manifest_path.read_bytes()
        manifest = _json_bytes(manifest_raw)
    except Exception:
        manifest_raw = b""
        manifest = {}
        findings.append("SPR2_AUDIT_MANIFEST_UNREADABLE")
    findings.extend(_manifest_findings(manifest))
    if not isinstance(manifest, dict):
        manifest = {}
    if mode == "STAGE_REVIEW":
        if manifest.get("artifact_root_kind") != "EXTERNAL_STAGE_REVIEW":
            findings.append("SPR2_AUDIT_STAGE_ROOT_KIND_INVALID")
    else:
        try:
            relative = manifest_path.resolve().relative_to(root).as_posix()
            if relative != SUCCESSOR_ROOT + "manifest.json":
                findings.append("SPR2_AUDIT_MANIFEST_PATH_SCOPE_INVALID")
            if _blob(root, evaluated_head, relative) != manifest_raw:
                findings.append("SPR2_AUDIT_MANIFEST_NOT_COMMITTED_EXACT")
        except ValueError:
            findings.append("SPR2_AUDIT_MANIFEST_OUTSIDE_REPOSITORY")
        if manifest.get("artifact_root_kind") != "COMMITTED_SUCCESSOR_ROOT":
            findings.append("SPR2_AUDIT_COMMITTED_ROOT_KIND_INVALID")

    predecessor, predecessor_findings = _predecessor(root, evaluated_head)
    findings.extend(predecessor_findings)
    findings.extend(_batch_findings(root, evaluated_head))
    proof, proof_findings = _authority_transition(root, evaluated_head)
    findings.extend(proof_findings)
    explicit_rel: set[str] = set()
    for path in explicit_batch_manifest_paths:
        try:
            explicit_rel.add(path.resolve().relative_to(root).as_posix())
        except ValueError:
            findings.append("SPR2_AUDIT_EXPLICIT_BATCH_OUTSIDE_ROOT")
    try:
        current_rel = current_batch_manifest_path.resolve().relative_to(root).as_posix()
    except ValueError:
        current_rel = ""
        findings.append("SPR2_AUDIT_CURRENT_BATCH_OUTSIDE_ROOT")
    if current_rel != CURRENT_BATCH_PATH or current_rel not in explicit_rel or manifest.get("current_batch_manifest_path") != current_rel:
        findings.append("SPR2_AUDIT_CURRENT_BATCH_NOT_EXPLICIT")
    predecessor_fps = predecessor.get("fingerprints", [])
    if len(predecessor_fps) != len(set(predecessor_fps)) or set(predecessor_fps) & set(TARGET_FINGERPRINTS):
        findings.append("SPR2_AUDIT_PREDECESSOR_TRUST_OVERLAP")
    if len(set(predecessor_fps) | set(TARGET_FINGERPRINTS)) != 84:
        findings.append("SPR2_AUDIT_DISJOINT_UNION_NOT_84")
    try:
        binding_head = str(manifest.get("revalidation_binding_head_sha", ""))
        if not _ancestor(root, CHANGE_COMMIT, binding_head) or not _ancestor(root, binding_head, evaluated_head):
            findings.append("SPR2_AUDIT_BINDING_ANCESTRY_INVALID")
        tree_pairs = {
            "revalidation_binding_tree_sha": binding_head,
            "authority_baseline_tree_sha": BASELINE_HEAD,
            "authority_transition_parent_tree_sha": CHANGE_PARENT,
            "authority_transition_commit_tree_sha": CHANGE_COMMIT,
        }
        for field, commit in tree_pairs.items():
            if manifest.get(field) != _git(root, "rev-parse", f"{commit}^{{tree}}"):
                findings.append(f"SPR2_AUDIT_TREE_BINDING_INVALID:{field}")
    except Exception:
        binding_head = ""
        findings.append("SPR2_AUDIT_BINDING_UNRESOLVED")

    bindings = manifest.get("record_bindings", []) if isinstance(manifest.get("record_bindings"), list) else []
    covered: list[str] = []
    committed_trust: dict[str, dict[str, Any]] = {}
    review_trust: dict[str, dict[str, Any]] = {}
    previous = str(manifest.get("record_chain_start_sha256", ""))
    for index, binding in enumerate(bindings):
        row_findings: list[str] = []
        if not isinstance(binding, dict) or set(binding) != BINDING_FIELDS:
            findings.append(f"SPR2_AUDIT_BINDING_FIELDS_INVALID:{index}")
            continue
        relative = str(binding.get("path", ""))
        try:
            path = _artifact(root, stage_dir, relative)
            raw = path.read_bytes()
            record = _json_bytes(raw)
            if mode == "COMMITTED" and _blob(root, evaluated_head, relative) != raw:
                row_findings.append("SPR2_AUDIT_RECORD_NOT_COMMITTED_EXACT")
        except Exception:
            findings.append(f"SPR2_AUDIT_RECORD_UNREADABLE:{index}")
            continue
        row_findings.extend(_record_findings(record))
        fps = _fingerprints(record.get("failure_fingerprints"), 1) if isinstance(record, dict) else None
        if fps is None:
            findings.extend(f"{code}:{index}" for code in row_findings)
            continue
        fingerprint = fps[0]
        covered.append(fingerprint)
        if fingerprint not in TARGET_FINGERPRINTS:
            row_findings.append("SPR2_AUDIT_RECORD_NOT_TARGET")
            findings.extend(f"{code}:{fingerprint}" for code in row_findings)
            continue
        if fingerprint != TARGET_FINGERPRINTS[index] or relative != EXPECTED_RECORD_PATHS[fingerprint]:
            row_findings.append("SPR2_AUDIT_RECORD_IDENTITY_PATH_INVALID")
        if record.get("revalidation_id") != EXPECTED_REVALIDATION_IDS[fingerprint]:
            row_findings.append("SPR2_AUDIT_REVALIDATION_ID_INVALID")
        if record.get("created_at") != manifest.get("created_at") or record.get("creator") != manifest.get("creator"):
            row_findings.append("SPR2_AUDIT_RECORD_MANIFEST_IDENTITY_MISMATCH")
        if binding.get("record_sha256") != _digest(raw):
            row_findings.append("SPR2_AUDIT_BINDING_RECORD_SHA_INVALID")
        for key in ("record_payload_sha256", "revalidation_id", "failure_fingerprints", "prior_record_path", "prior_record_sha256", "prior_record_payload_sha256", "prior_correction_id", "previous_revalidation_chain_sha256"):
            if binding.get(key) != record.get(key):
                row_findings.append(f"SPR2_AUDIT_BINDING_RECORD_MISMATCH:{key}")
        if record.get("previous_revalidation_chain_sha256") != previous:
            row_findings.append("SPR2_AUDIT_CHAIN_BREAK")
        previous = str(record.get("record_payload_sha256", ""))
        prior, prior_findings = _prior_record(root, evaluated_head, fingerprint)
        row_findings.extend(prior_findings)
        identity = prior.get("identity", {})
        if record.get("prior_record_path") != PRIOR_RECORD_PATHS[fingerprint] or record.get("prior_record_sha256") != PRIOR_RECORD_SHA256[fingerprint] or record.get("prior_record_payload_sha256") != PRIOR_RECORD_PAYLOAD_SHA256[fingerprint] or record.get("prior_correction_id") != PRIOR_CORRECTION_IDS[fingerprint]:
            row_findings.append("SPR2_AUDIT_PRIOR_RECORD_BINDING_INVALID")
        if record.get("prior_identity_binding") != identity:
            row_findings.append("SPR2_AUDIT_PRIOR_IDENTITY_BINDING_INVALID")
        if record.get("authority_selectors") != identity.get("authority_selectors") or record.get("authority_selectors") != TARGET_SELECTOR:
            row_findings.append("SPR2_AUDIT_SELECTOR_NOT_PRIOR_EXACT")
        try:
            prior_head = str(prior.get("document", {}).get("binding_head_sha", ""))
            prior_projection = _projection(root, prior_head, TARGET_SELECTOR)
            pre_change = _projection(root, CHANGE_PARENT, TARGET_SELECTOR)
            rebound = _projection(root, CHANGE_COMMIT, TARGET_SELECTOR)
            live = _projection(root, evaluated_head, TARGET_SELECTOR)
            if _projection_digest(prior_projection) != PRIOR_PROJECTION_SHA256 or identity.get("subject_projection") != prior_projection or identity.get("subject_projection_sha256") != PRIOR_PROJECTION_SHA256:
                row_findings.append("SPR2_AUDIT_PRIOR_PROJECTION_RECOMPUTE_INVALID")
            comparisons = (
                ("prior_subject_projection", "prior_subject_projection_sha256", prior_projection, PRIOR_PROJECTION_SHA256),
                ("pre_change_subject_projection", "pre_change_subject_projection_sha256", pre_change, PRIOR_PROJECTION_SHA256),
                ("rebound_subject_projection", "rebound_subject_projection_sha256", rebound, REBOUND_PROJECTION_SHA256),
                ("live_subject_projection", "live_subject_projection_sha256", live, REBOUND_PROJECTION_SHA256),
            )
            for field, digest_field, value, expected_digest in comparisons:
                if record.get(field) != value or record.get(digest_field) != _projection_digest(value) or _projection_digest(value) != expected_digest:
                    row_findings.append(f"SPR2_AUDIT_PROJECTION_INVALID:{field}")
            changed_sections = sorted(key for key in PROJECTION_FIELDS if pre_change.get(key) != rebound.get(key))
            added = _added_rows(pre_change, rebound)
            if changed_sections != ["registry_rows"] or record.get("changed_projection_sections") != changed_sections:
                row_findings.append("SPR2_AUDIT_PROJECTION_SCOPE_INVALID")
            if record.get("added_registry_rows") != added or len(added) != 1 or added[0].get("component_id") != TARGET_COMPONENT or added[0].get("authority_source_kind") != "historical_identity_backfill":
                row_findings.append("SPR2_AUDIT_SELECTOR_VISIBLE_ROW_INVALID")
            changing: list[str] = []
            commits = str(_git(root, "rev-list", "--reverse", f"{prior_head}..{evaluated_head}", "--", *PROJECTION_PATHS)).splitlines()
            for commit in commits:
                parent = str(_git(root, "rev-parse", f"{commit}^1"))
                if _projection(root, parent, TARGET_SELECTOR) != _projection(root, commit, TARGET_SELECTOR):
                    changing.append(commit)
            if changing != [CHANGE_COMMIT]:
                row_findings.append("SPR2_AUDIT_PROJECTION_CHANGE_NOT_UNIQUE")
        except Exception:
            row_findings.append("SPR2_AUDIT_PROJECTION_RECOMPUTE_FAILED")
        product_blobs = [_blob(root, commit, PRODUCT_PATH) for commit in (BASELINE_HEAD, CHANGE_PARENT, CHANGE_COMMIT, binding_head, evaluated_head)]
        if any(blob is None or _digest(blob) != PRODUCT_BLOB_SHA256 for blob in product_blobs) or len({blob for blob in product_blobs if blob is not None}) != 1:
            row_findings.append("SPR2_AUDIT_PRODUCT_BLOB_CHANGED")
        try:
            touches = [line for line in str(_git(root, "rev-list", "--reverse", f"{CHANGE_PARENT}..{evaluated_head}", "--", PRODUCT_PATH)).splitlines() if line]
            if touches:
                row_findings.append("SPR2_AUDIT_PRODUCT_PATH_TOUCHED")
        except Exception:
            row_findings.append("SPR2_AUDIT_PRODUCT_TOUCH_SCAN_FAILED")
        if record.get("authority_transition_proof") != proof:
            row_findings.append("SPR2_AUDIT_TRANSITION_PROOF_INVALID")
        if record.get("revalidation_binding_head_sha") != binding_head or record.get("revalidation_binding_tree_sha") != manifest.get("revalidation_binding_tree_sha"):
            row_findings.append("SPR2_AUDIT_RECORD_BINDING_HEAD_TREE_INVALID")
        if row_findings:
            findings.extend(f"{code}:{fingerprint}" for code in row_findings)
        else:
            trust_row = {
                "allowed_invalidations": [ALLOWED_INVALIDATION],
                "prior_record_path": record.get("prior_record_path"),
                "revalidation_id": record.get("revalidation_id"),
                "record_path": relative,
                "revalidation_binding_head_sha": binding_head,
            }
            review_trust[fingerprint] = trust_row
            if mode == "COMMITTED":
                committed_trust[fingerprint] = trust_row
    if sorted(covered) != list(TARGET_FINGERPRINTS) or len(set(covered)) != 2:
        findings.append("SPR2_AUDIT_RECORD_COVERAGE_INVALID")
    if previous != manifest.get("record_chain_terminal_sha256"):
        findings.append("SPR2_AUDIT_CHAIN_TERMINAL_INVALID")
    findings = sorted(set(findings))
    if findings:
        committed_trust = {}
        review_trust = {}
    return {
        "status": "GO" if not findings else "NO_GO",
        "mode": mode,
        "findings": findings,
        "trusted_by_fingerprint": committed_trust,
        "review_trusted_by_fingerprint": review_trust,
        "trusted_fingerprint_count": len(committed_trust),
        "review_trusted_fingerprint_count": len(review_trust),
        "record_count": len(bindings),
        "fingerprints": sorted(set(covered)),
        "stage_only": mode == "STAGE_REVIEW",
    }


def agrees_with_primary(primary_result: dict[str, Any], audit_result: dict[str, Any]) -> bool:
    """Compare only public trust-bearing surfaces; any mismatch fails closed."""
    return (
        primary_result.get("status") == "PASS"
        and audit_result.get("status") == "GO"
        and primary_result.get("mode") == audit_result.get("mode")
        and primary_result.get("fingerprints") == audit_result.get("fingerprints")
        and primary_result.get("trusted_by_fingerprint") == audit_result.get("trusted_by_fingerprint")
        and primary_result.get("review_trusted_by_fingerprint") == audit_result.get("review_trusted_by_fingerprint")
    )


def allows_invalidation(trusted: dict[str, dict[str, Any]], *, fingerprint: str, invalidation_code: str, prior_record_path: str) -> bool:
    if invalidation_code != ALLOWED_INVALIDATION or not _path(prior_record_path):
        return False
    row = trusted.get(fingerprint)
    return isinstance(row, dict) and set(row) == TRUST_ROW_FIELDS and row.get("allowed_invalidations") == [ALLOWED_INVALIDATION] and row.get("prior_record_path") == prior_record_path


def default_explicit_batch_paths(root: Path) -> list[Path]:
    return [root / f"docs/architecture/reuse_corrections/v2/batches/full_convergence_20260827/batch-{index:03d}/batch-{index:03d}-manifest.json" for index in range(1, 9)]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path.cwd())
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--stage-dir", type=Path, default=None)
    parser.add_argument("--evaluated-head", default="HEAD")
    parser.add_argument("--current-batch-manifest", type=Path, default=None)
    parser.add_argument("--explicit-batch-manifest", type=Path, action="append", default=[])
    args = parser.parse_args(argv)
    root = args.project.resolve()
    head = str(_git(root, "rev-parse", f"{args.evaluated_head}^{{commit}}"))
    result = audit_manifest_and_records(
        root,
        args.manifest.resolve(),
        evaluated_head=head,
        current_batch_manifest_path=(args.current_batch_manifest or root / CURRENT_BATCH_PATH).resolve(),
        explicit_batch_manifest_paths=args.explicit_batch_manifest or default_explicit_batch_paths(root),
        stage_dir=args.stage_dir.absolute() if args.stage_dir is not None else None,
    )
    print(json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2))
    return 0 if result.get("status") == "GO" else 1


if __name__ == "__main__":
    raise SystemExit(main())
