#!/usr/bin/env python3
"""Fail-closed validator for the append-only subject-projection successor v2.

The original 82-record subject-projection sidecar is frozen.  This new,
explicit authority can revalidate only the two Alpha01 fingerprints whose
selector-visible projection changed at the sealed Batch-008 authority commit.
An external stage is review-only: it can never populate committed trust.
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
PROJECTION_AUTHORITY_PATHS = (REGISTRY_PATH, SUPERSESSION_PATH, OWNER_MAP_PATH, DYNAMIC_REFERENCE_PATH)
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
TRANSITION_PROOF_FIELDS = frozenset("""commit_sha parent_sha baseline_head_sha before_sha256_by_path after_sha256_by_path diff_sha256_by_path combined_diff_sha256 baseline_parent_authority_bytes_equal""".split())
TRUST_ROW_FIELDS = frozenset({"allowed_invalidations", "prior_record_path", "revalidation_id", "record_path", "revalidation_binding_head_sha"})


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
    return sha256_bytes(("\n".join(sorted(str(value) for value in values)) + "\n").encode("utf-8"))


def _sha(value: Any, length: int = 64) -> bool:
    return isinstance(value, str) and re.fullmatch(rf"[0-9a-f]{{{length}}}", value) is not None


def _exact_path(value: Any) -> bool:
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


def _blob(root: Path, commit: str, path: str) -> bytes | None:
    try:
        return _git(root, "cat-file", "blob", f"{commit}:{path}", binary=True)  # type: ignore[return-value]
    except ValueError:
        return None


def _ancestor(root: Path, old: str, new: str) -> bool:
    proc = subprocess.run(["git", "--no-replace-objects", "-C", str(root), "merge-base", "--is-ancestor", old, new], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    return proc.returncode == 0


def _committed_document(root: Path, head: str, relative: str) -> tuple[Any, bytes]:
    if not _exact_path(relative):
        raise ValueError("unsafe path")
    committed = _blob(root, head, relative)
    local = root / relative
    if committed is None or not local.is_file() or local.read_bytes() != committed:
        raise ValueError("committed/local bytes mismatch")
    return strict_json_bytes(committed), committed


def _json_at(root: Path, commit: str, relative: str) -> Any:
    raw = _blob(root, commit, relative)
    if raw is None:
        raise ValueError(f"missing blob: {relative}")
    return strict_json_bytes(raw)


def _selector_failures(value: Any) -> list[str]:
    if not isinstance(value, dict) or set(value) != SELECTOR_FIELDS:
        return ["SPR_SUCCESSOR_SELECTOR_FIELD_SET_INVALID"]
    failures: list[str] = []
    for key in sorted(SELECTOR_FIELDS):
        rows = value.get(key)
        if not isinstance(rows, list) or rows != sorted(rows) or len(rows) != len(set(rows)):
            failures.append(f"SPR_SUCCESSOR_SELECTOR_VALUES_INVALID:{key}")
            continue
        for row in rows:
            if type(row) is not str or not row or any(token in row for token in ("*", "?", "[", "]")):
                failures.append(f"SPR_SUCCESSOR_SELECTOR_VALUE_INVALID:{key}")
            elif key == "paths" and not _exact_path(row):
                failures.append(f"SPR_SUCCESSOR_SELECTOR_PATH_INVALID:{row}")
    if not value.get("component_ids") and not value.get("paths"):
        failures.append("SPR_SUCCESSOR_SELECTOR_EMPTY")
    return sorted(set(failures))


def subject_projection(root: Path, commit: str, selector: dict[str, Any]) -> dict[str, Any]:
    failures = _selector_failures(selector)
    if failures:
        raise ValueError(";".join(failures))
    registry = _json_at(root, commit, REGISTRY_PATH)
    supersession = _json_at(root, commit, SUPERSESSION_PATH)
    dynamic = _json_at(root, commit, DYNAMIC_REFERENCE_PATH)
    owner = _blob(root, commit, OWNER_MAP_PATH)
    if not isinstance(registry, dict) or not isinstance(supersession, dict) or not isinstance(dynamic, dict) or owner is None:
        raise ValueError("projection authority invalid")
    components = set(selector["component_ids"])
    paths = set(selector["paths"])
    registry_rows: list[dict[str, Any]] = []
    for kind in ("component_inventory", "historical_identity_backfill"):
        rows = registry.get(kind, [])
        if not isinstance(rows, list):
            continue
        for row in rows:
            if isinstance(row, dict) and (row.get("component_id") in components or row.get("path") in paths):
                tagged = dict(row)
                tagged["authority_source_kind"] = kind
                registry_rows.append(tagged)
    supersession_rows: list[dict[str, Any]] = []
    for kind in ("entries", "retirement_entries"):
        rows = supersession.get(kind, [])
        if not isinstance(rows, list):
            continue
        for row in rows:
            if isinstance(row, dict) and (row.get("supersession_id") in set(selector["supersession_ids"]) or row.get("retirement_id") in set(selector["retirement_ids"])):
                supersession_rows.append(row)
    dynamic_rows = [row for row in dynamic.get("entries", []) if isinstance(row, dict) and row.get("dynamic_reference_id") in set(selector["dynamic_reference_ids"])] if isinstance(dynamic.get("entries"), list) else []
    needles = sorted({str(item) for values in selector.values() for item in values if item})
    owner_lines = sorted({line.rstrip() for line in owner.decode("utf-8-sig", "replace").splitlines() if any(needle in line for needle in needles)})
    result = {
        "dynamic_reference_rows": sorted(dynamic_rows, key=canonical_bytes),
        "owner_map_lines": owner_lines,
        "registry_rows": sorted(registry_rows, key=canonical_bytes),
        "supersession_rows": sorted(supersession_rows, key=canonical_bytes),
    }
    if not any(result.values()):
        raise ValueError("unresolved selector")
    return result


def _projection_sha(value: dict[str, Any]) -> str:
    return sha256_bytes(canonical_bytes(value))


def _added_registry_rows(old: dict[str, Any], new: dict[str, Any]) -> list[dict[str, Any]]:
    old_set = {canonical_bytes(row) for row in old.get("registry_rows", []) if isinstance(row, dict)}
    return sorted([row for row in new.get("registry_rows", []) if isinstance(row, dict) and canonical_bytes(row) not in old_set], key=canonical_bytes)


def _schema_expected() -> dict[str, Any]:
    return {
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


def validate_schema_document(document: Any) -> list[str]:
    if not isinstance(document, dict):
        return ["SPR_SUCCESSOR_SCHEMA_NOT_OBJECT"]
    failures: list[str] = []
    expected = _schema_expected()
    required = set(expected) | {"manifest_required_fields", "record_required_fields", "record_binding_fields", "authority_path_binding_fields", "touch_proof_fields", "projection_fields", "selector_fields", "negative_policy"}
    if set(document) != required:
        failures.append("SPR_SUCCESSOR_SCHEMA_FIELD_SET_INVALID")
    for key, value in expected.items():
        if document.get(key) != value:
            failures.append(f"SPR_SUCCESSOR_SCHEMA_VALUE_INVALID:{key}")
    expected_fields = {
        "manifest_required_fields": MANIFEST_FIELDS,
        "record_required_fields": RECORD_FIELDS,
        "record_binding_fields": BINDING_FIELDS,
        "projection_fields": PROJECTION_FIELDS,
        "selector_fields": SELECTOR_FIELDS,
    }
    for key, fields in expected_fields.items():
        value = document.get(key)
        if not isinstance(value, list) or len(value) != len(set(value)) or set(value) != set(fields):
            failures.append(f"SPR_SUCCESSOR_SCHEMA_REQUIRED_FIELDS_INVALID:{key}")
    if set(document.get("authority_path_binding_fields", [])) != {"path", "before_blob_sha256", "after_blob_sha256", "diff_sha256"}:
        failures.append("SPR_SUCCESSOR_SCHEMA_AUTHORITY_BINDING_FIELDS_INVALID")
    if set(document.get("touch_proof_fields", [])) != {"commit_sha", "parent_sha", "path", "before_blob_sha256", "after_blob_sha256", "diff_sha256"}:
        failures.append("SPR_SUCCESSOR_SCHEMA_TOUCH_FIELDS_INVALID")
    negative = document.get("negative_policy")
    required_negative = {"NO_WILDCARD", "NO_FUTURE_FAILURE_AUTO_TRUST", "NO_PRODUCT_BLOB_CHANGE", "NO_PRODUCT_PATH_TOUCH", "NO_AUTHORITY_PATH_OMISSION", "NO_TRUST_OVERLAP", "NO_STAGE_AS_COMMITTED_TRUST"}
    if not isinstance(negative, list) or len(negative) != len(set(negative)) or set(negative) != required_negative:
        failures.append("SPR_SUCCESSOR_SCHEMA_NEGATIVE_POLICY_INVALID")
    return sorted(set(failures))


def validate_schema_file(root: Path, *, evaluated_head: str | None = None) -> list[str]:
    try:
        raw = (root / SCHEMA_PATH).read_bytes()
        document = strict_json_bytes(raw)
    except Exception:
        return ["SPR_SUCCESSOR_SCHEMA_UNREADABLE"]
    failures = validate_schema_document(document)
    if sha256_bytes(raw) != SCHEMA_SHA256:
        failures.append("SPR_SUCCESSOR_SCHEMA_SHA256_INVALID")
    if evaluated_head is not None:
        committed = _blob(root, evaluated_head, SCHEMA_PATH)
        if committed is None or committed != raw:
            failures.append("SPR_SUCCESSOR_SCHEMA_COMMITTED_BYTES_INVALID")
    return sorted(set(failures))


def _manifest_shape_failures(document: Any) -> list[str]:
    if not isinstance(document, dict):
        return ["SPR_SUCCESSOR_MANIFEST_NOT_OBJECT"]
    failures: list[str] = []
    if set(document) != MANIFEST_FIELDS:
        failures.append("SPR_SUCCESSOR_MANIFEST_FIELD_SET_INVALID")
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
        "failure_fingerprint_set_sha256": line_set_sha(TARGET_FINGERPRINTS),
        "record_chain_start_sha256": PREDECESSOR_CHAIN_TERMINAL_SHA256,
        "allowed_invalidation": ALLOWED_INVALIDATION,
        "future_failure_auto_revalidation": False,
        "wildcard_count": 0,
    }
    for key, value in expected.items():
        if document.get(key) != value:
            failures.append(f"SPR_SUCCESSOR_MANIFEST_VALUE_INVALID:{key}")
    for key in ("revalidation_binding_head_sha", "revalidation_binding_tree_sha", "authority_baseline_tree_sha", "authority_transition_parent_tree_sha", "authority_transition_commit_tree_sha"):
        if not _sha(document.get(key), 40):
            failures.append(f"SPR_SUCCESSOR_MANIFEST_OID_INVALID:{key}")
    if document.get("artifact_root_kind") not in ("EXTERNAL_STAGE_REVIEW", "COMMITTED_SUCCESSOR_ROOT"):
        failures.append("SPR_SUCCESSOR_MANIFEST_ARTIFACT_ROOT_KIND_INVALID")
    if not _timestamp(document.get("created_at")) or not isinstance(document.get("creator"), str) or not document.get("creator"):
        failures.append("SPR_SUCCESSOR_MANIFEST_IDENTITY_INVALID")
    bindings = document.get("record_bindings")
    if not isinstance(bindings, list) or len(bindings) != 2:
        failures.append("SPR_SUCCESSOR_MANIFEST_BINDING_COUNT_INVALID")
    elif any(not isinstance(binding, dict) or set(binding) != BINDING_FIELDS for binding in bindings):
        failures.append("SPR_SUCCESSOR_MANIFEST_BINDING_FIELDS_INVALID")
    if not _sha(document.get("record_chain_terminal_sha256")):
        failures.append("SPR_SUCCESSOR_MANIFEST_CHAIN_TERMINAL_INVALID")
    return sorted(set(failures))


def _record_shape_failures(document: Any) -> list[str]:
    if not isinstance(document, dict):
        return ["SPR_SUCCESSOR_RECORD_NOT_OBJECT"]
    failures: list[str] = []
    if set(document) != RECORD_FIELDS:
        failures.append("SPR_SUCCESSOR_RECORD_FIELD_SET_INVALID")
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
        "authority_selector_sha256": sha256_bytes(canonical_bytes(TARGET_SELECTOR)),
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
            failures.append(f"SPR_SUCCESSOR_RECORD_VALUE_INVALID:{key}")
    fps = _fingerprints(document.get("failure_fingerprints"), 1)
    if fps is None or fps[0] not in TARGET_FINGERPRINTS:
        failures.append("SPR_SUCCESSOR_RECORD_FINGERPRINT_INVALID")
    elif document.get("failure_fingerprint_set_sha256") != line_set_sha(fps):
        failures.append("SPR_SUCCESSOR_RECORD_FINGERPRINT_SHA_INVALID")
    for key in ("prior_record_sha256", "prior_record_payload_sha256", "prior_batch_manifest_sha256", "predecessor_manifest_sha256", "authority_selector_sha256", "prior_subject_projection_sha256", "pre_change_subject_projection_sha256", "rebound_subject_projection_sha256", "live_subject_projection_sha256", "record_payload_sha256"):
        if not _sha(document.get(key)):
            failures.append(f"SPR_SUCCESSOR_RECORD_SHA_INVALID:{key}")
    for key in ("revalidation_binding_head_sha", "revalidation_binding_tree_sha"):
        if not _sha(document.get(key), 40):
            failures.append(f"SPR_SUCCESSOR_RECORD_OID_INVALID:{key}")
    for key in ("prior_subject_projection", "pre_change_subject_projection", "rebound_subject_projection", "live_subject_projection"):
        if not isinstance(document.get(key), dict) or set(document.get(key, {})) != PROJECTION_FIELDS:
            failures.append(f"SPR_SUCCESSOR_RECORD_PROJECTION_FIELDS_INVALID:{key}")
    if not isinstance(document.get("prior_identity_binding"), dict):
        failures.append("SPR_SUCCESSOR_RECORD_PRIOR_IDENTITY_INVALID")
    if not isinstance(document.get("added_registry_rows"), list) or len(document.get("added_registry_rows", [])) != 1:
        failures.append("SPR_SUCCESSOR_RECORD_ADDED_ROWS_INVALID")
    proof = document.get("authority_transition_proof")
    if not isinstance(proof, dict) or set(proof) != TRANSITION_PROOF_FIELDS:
        failures.append("SPR_SUCCESSOR_RECORD_TRANSITION_PROOF_FIELDS_INVALID")
    payload = {key: value for key, value in document.items() if key != "record_payload_sha256"}
    try:
        digest = sha256_bytes(canonical_bytes(payload))
    except Exception:
        digest = ""
    if document.get("record_payload_sha256") != digest:
        failures.append("SPR_SUCCESSOR_RECORD_PAYLOAD_INVALID")
    if not _timestamp(document.get("created_at")) or not isinstance(document.get("creator"), str) or not document.get("creator"):
        failures.append("SPR_SUCCESSOR_RECORD_IDENTITY_INVALID")
    return sorted(set(failures))


def _authority_transition(root: Path, evaluated_head: str) -> tuple[dict[str, Any], list[str]]:
    failures: list[str] = []
    proof: dict[str, Any] = {}
    try:
        if _git(root, "rev-parse", f"{CHANGE_COMMIT}^1") != CHANGE_PARENT:
            failures.append("SPR_SUCCESSOR_CHANGE_PARENT_INVALID")
        if not _ancestor(root, BASELINE_HEAD, CHANGE_PARENT):
            failures.append("SPR_SUCCESSOR_BASELINE_PARENT_ANCESTRY_INVALID")
        if not _ancestor(root, CHANGE_COMMIT, evaluated_head):
            failures.append("SPR_SUCCESSOR_CHANGE_NOT_EVALUATED_ANCESTOR")
        changed = str(_git(root, "diff", "--name-only", CHANGE_PARENT, CHANGE_COMMIT)).splitlines()
        if changed != sorted(AUTHORITY_PATHS):
            failures.append("SPR_SUCCESSOR_CHANGE_PATH_SET_INVALID")
        before_by_path: dict[str, str] = {}
        after_by_path: dict[str, str] = {}
        diff_by_path: dict[str, str] = {}
        baseline_equal = True
        for path in AUTHORITY_PATHS:
            baseline = _blob(root, BASELINE_HEAD, path)
            parent = _blob(root, CHANGE_PARENT, path)
            after = _blob(root, CHANGE_COMMIT, path)
            diff = _git(root, "diff", "--binary", "--no-ext-diff", CHANGE_PARENT, CHANGE_COMMIT, "--", path, binary=True)
            if baseline is None or parent is None or after is None:
                failures.append(f"SPR_SUCCESSOR_AUTHORITY_BLOB_MISSING:{path}")
                continue
            before_by_path[path] = sha256_bytes(parent)
            after_by_path[path] = sha256_bytes(after)
            diff_by_path[path] = sha256_bytes(diff)
            if baseline != parent:
                baseline_equal = False
                failures.append(f"SPR_SUCCESSOR_BASELINE_PARENT_BYTES_DRIFT:{path}")
            if before_by_path[path] != BEFORE_SHA256[path] or after_by_path[path] != AFTER_SHA256[path] or diff_by_path[path] != DIFF_SHA256[path]:
                failures.append(f"SPR_SUCCESSOR_AUTHORITY_SEAL_INVALID:{path}")
        combined = _git(root, "diff", "--binary", "--no-ext-diff", CHANGE_PARENT, CHANGE_COMMIT, "--", *AUTHORITY_PATHS, binary=True)
        if sha256_bytes(combined) != COMBINED_DIFF_SHA256:
            failures.append("SPR_SUCCESSOR_COMBINED_DIFF_INVALID")
        for path, expected in ((OWNER_MAP_PATH, OWNER_MAP_SHA256), (DYNAMIC_REFERENCE_PATH, DYNAMIC_REFERENCE_SHA256)):
            values = [_blob(root, commit, path) for commit in (BASELINE_HEAD, CHANGE_PARENT, CHANGE_COMMIT, evaluated_head)]
            if any(value is None or sha256_bytes(value) != expected for value in values):
                failures.append(f"SPR_SUCCESSOR_UNCHANGED_AUTHORITY_DRIFT:{path}")
        proof = {
            "commit_sha": CHANGE_COMMIT,
            "parent_sha": CHANGE_PARENT,
            "baseline_head_sha": BASELINE_HEAD,
            "before_sha256_by_path": before_by_path,
            "after_sha256_by_path": after_by_path,
            "diff_sha256_by_path": diff_by_path,
            "combined_diff_sha256": sha256_bytes(combined),
            "baseline_parent_authority_bytes_equal": baseline_equal,
        }
    except Exception as error:
        failures.append(f"SPR_SUCCESSOR_CHANGE_UNRESOLVED:{type(error).__name__}")
    return proof, sorted(set(failures))


def _load_predecessor(root: Path, head: str) -> tuple[dict[str, Any], list[str]]:
    failures: list[str] = []
    try:
        document, raw = _committed_document(root, head, PREDECESSOR_MANIFEST_PATH)
    except Exception:
        return {}, ["SPR_SUCCESSOR_PREDECESSOR_UNREADABLE"]
    if not isinstance(document, dict):
        return {}, ["SPR_SUCCESSOR_PREDECESSOR_NOT_OBJECT"]
    if sha256_bytes(raw) != PREDECESSOR_MANIFEST_SHA256:
        failures.append("SPR_SUCCESSOR_PREDECESSOR_SHA_INVALID")
    if document.get("record_count") != 82 or document.get("record_chain_terminal_sha256") != PREDECESSOR_CHAIN_TERMINAL_SHA256 or document.get("failure_fingerprint_set_sha256") != PREDECESSOR_FINGERPRINT_SET_SHA256:
        failures.append("SPR_SUCCESSOR_PREDECESSOR_CONTRACT_INVALID")
    fps = _fingerprints(document.get("failure_fingerprints"), 82)
    if fps is None:
        failures.append("SPR_SUCCESSOR_PREDECESSOR_FINGERPRINTS_INVALID")
        fps = []
    return {"document": document, "fingerprints": fps}, sorted(set(failures))


def _load_current_batch(root: Path, head: str) -> list[str]:
    try:
        document, raw = _committed_document(root, head, CURRENT_BATCH_PATH)
    except Exception:
        return ["SPR_SUCCESSOR_CURRENT_BATCH_UNREADABLE"]
    failures: list[str] = []
    if sha256_bytes(raw) != CURRENT_BATCH_SHA256:
        failures.append("SPR_SUCCESSOR_CURRENT_BATCH_SHA_INVALID")
    if not isinstance(document, dict) or document.get("batch_id") != CURRENT_BATCH_ID or document.get("failure_fingerprint_set_sha256") != CURRENT_BATCH_FINGERPRINT_SET_SHA256:
        failures.append("SPR_SUCCESSOR_CURRENT_BATCH_CONTRACT_INVALID")
    return failures


def _prior_record(root: Path, head: str, fp: str) -> tuple[dict[str, Any], list[str]]:
    failures: list[str] = []
    path = PRIOR_RECORD_PATHS[fp]
    try:
        document, raw = _committed_document(root, head, path)
    except Exception:
        return {}, [f"SPR_SUCCESSOR_PRIOR_RECORD_UNREADABLE:{fp}"]
    if not isinstance(document, dict):
        return {}, [f"SPR_SUCCESSOR_PRIOR_RECORD_NOT_OBJECT:{fp}"]
    identity = document.get("identity_binding_by_failure", {}).get(fp)
    if not isinstance(identity, dict):
        failures.append(f"SPR_SUCCESSOR_PRIOR_IDENTITY_MISSING:{fp}")
        identity = {}
    if sha256_bytes(raw) != PRIOR_RECORD_SHA256[fp] or document.get("record_payload_sha256") != PRIOR_RECORD_PAYLOAD_SHA256[fp] or document.get("correction_id") != PRIOR_CORRECTION_IDS[fp]:
        failures.append(f"SPR_SUCCESSOR_PRIOR_RECORD_SEAL_INVALID:{fp}")
    if fp not in document.get("failure_fingerprints", []) or identity.get("authority_selectors") != TARGET_SELECTOR:
        failures.append(f"SPR_SUCCESSOR_PRIOR_MEMBERSHIP_INVALID:{fp}")
    try:
        batch, batch_raw = _committed_document(root, head, PRIOR_BATCH_PATH)
        if sha256_bytes(batch_raw) != PRIOR_BATCH_SHA256:
            failures.append(f"SPR_SUCCESSOR_PRIOR_BATCH_SHA_INVALID:{fp}")
        matches = [row for row in batch.get("record_bindings", []) if isinstance(row, dict) and row.get("path") == path and row.get("record_sha256") == PRIOR_RECORD_SHA256[fp] and row.get("record_payload_sha256") == PRIOR_RECORD_PAYLOAD_SHA256[fp] and row.get("correction_id") == PRIOR_CORRECTION_IDS[fp] and fp in row.get("failure_fingerprints", [])]
        if len(matches) != 1:
            failures.append(f"SPR_SUCCESSOR_PRIOR_BATCH_MEMBERSHIP_INVALID:{fp}")
    except Exception:
        failures.append(f"SPR_SUCCESSOR_PRIOR_BATCH_UNREADABLE:{fp}")
    return {"document": document, "identity": identity, "path": path}, sorted(set(failures))


def _stage_safety(root: Path, stage: Path) -> list[str]:
    failures: list[str] = []
    if not os.path.lexists(stage) or not stage.is_dir():
        failures.append("SPR_SUCCESSOR_STAGE_NOT_DIRECTORY")
    try:
        stage.resolve().relative_to(root.resolve())
        failures.append("SPR_SUCCESSOR_STAGE_INSIDE_REPOSITORY")
    except ValueError:
        pass
    if stage.is_symlink():
        failures.append("SPR_SUCCESSOR_STAGE_SYMLINK")
    try:
        if stage.lstat().st_file_attributes & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400):
            failures.append("SPR_SUCCESSOR_STAGE_REPARSE_POINT")
    except (OSError, AttributeError):
        pass
    return sorted(set(failures))


def _artifact_file(root: Path, stage: Path | None, relative: str) -> Path:
    if not _exact_path(relative):
        raise ValueError("unsafe artifact path")
    if stage is None:
        return (root / relative).resolve()
    if not relative.startswith(RECORD_ROOT):
        raise ValueError("stage record not in successor root")
    tail = relative[len(SUCCESSOR_ROOT):]
    candidate = (stage / tail).resolve()
    candidate.relative_to(stage.resolve())
    return candidate


def validate_manifest_and_records(
    root: Path,
    manifest_path: Path,
    *,
    evaluated_head: str,
    current_batch_manifest_path: Path,
    explicit_batch_manifest_paths: Iterable[Path],
    stage_dir: Path | None = None,
) -> dict[str, Any]:
    root = root.resolve()
    failures: list[str] = []
    mode = "STAGE_REVIEW" if stage_dir is not None else "COMMITTED"
    if stage_dir is not None:
        lexical_stage_dir = stage_dir.absolute()
        failures.extend(_stage_safety(root, lexical_stage_dir))
        stage_dir = lexical_stage_dir.resolve()
        try:
            if manifest_path.resolve() != (stage_dir / "manifest.json").resolve():
                failures.append("SPR_SUCCESSOR_STAGE_MANIFEST_PATH_INVALID")
        except ValueError:
            failures.append("SPR_SUCCESSOR_STAGE_MANIFEST_OUTSIDE_STAGE")
    try:
        evaluated = str(_git(root, "rev-parse", evaluated_head))
        if evaluated != evaluated_head or not _sha(evaluated, 40):
            failures.append("SPR_SUCCESSOR_EVALUATED_HEAD_NOT_EXACT")
    except Exception:
        return {"status": "FAIL", "mode": mode, "failures": ["SPR_SUCCESSOR_EVALUATED_HEAD_UNRESOLVED"], "trusted_by_fingerprint": {}, "review_trusted_by_fingerprint": {}, "record_count": 0, "fingerprints": []}
    failures.extend(validate_schema_file(root, evaluated_head=None if stage_dir is not None else evaluated_head))
    try:
        manifest_raw = manifest_path.read_bytes()
        manifest = strict_json_bytes(manifest_raw)
    except Exception:
        manifest_raw = b""
        manifest = {}
        failures.append("SPR_SUCCESSOR_MANIFEST_UNREADABLE")
    failures.extend(_manifest_shape_failures(manifest))
    if not isinstance(manifest, dict):
        manifest = {}
    if mode == "STAGE_REVIEW" and manifest.get("artifact_root_kind") != "EXTERNAL_STAGE_REVIEW":
        failures.append("SPR_SUCCESSOR_STAGE_ROOT_KIND_INVALID")
    if mode == "COMMITTED":
        try:
            relative = manifest_path.resolve().relative_to(root).as_posix()
            if relative != SUCCESSOR_ROOT + "manifest.json":
                failures.append("SPR_SUCCESSOR_MANIFEST_PATH_SCOPE_INVALID")
            committed = _blob(root, evaluated_head, relative)
            if committed is None or committed != manifest_raw:
                failures.append("SPR_SUCCESSOR_MANIFEST_COMMITTED_BYTES_INVALID")
        except ValueError:
            failures.append("SPR_SUCCESSOR_MANIFEST_OUTSIDE_REPOSITORY")
        if manifest.get("artifact_root_kind") != "COMMITTED_SUCCESSOR_ROOT":
            failures.append("SPR_SUCCESSOR_COMMITTED_ROOT_KIND_INVALID")

    predecessor, predecessor_failures = _load_predecessor(root, evaluated_head)
    failures.extend(predecessor_failures)
    failures.extend(_load_current_batch(root, evaluated_head))
    proof, transition_failures = _authority_transition(root, evaluated_head)
    failures.extend(transition_failures)
    explicit_rel: set[str] = set()
    for path in explicit_batch_manifest_paths:
        try:
            explicit_rel.add(path.resolve().relative_to(root).as_posix())
        except ValueError:
            failures.append("SPR_SUCCESSOR_EXPLICIT_BATCH_OUTSIDE_ROOT")
    try:
        current_rel = current_batch_manifest_path.resolve().relative_to(root).as_posix()
    except ValueError:
        current_rel = ""
        failures.append("SPR_SUCCESSOR_CURRENT_BATCH_OUTSIDE_ROOT")
    if current_rel != CURRENT_BATCH_PATH or current_rel not in explicit_rel or manifest.get("current_batch_manifest_path") != current_rel:
        failures.append("SPR_SUCCESSOR_CURRENT_BATCH_NOT_EXPLICIT")
    if not trust_sets_disjoint(predecessor.get("fingerprints", []), TARGET_FINGERPRINTS):
        failures.append("SPR_SUCCESSOR_PREDECESSOR_TRUST_OVERLAP")
    try:
        binding_head = str(manifest.get("revalidation_binding_head_sha", ""))
        if not _ancestor(root, CHANGE_COMMIT, binding_head) or not _ancestor(root, binding_head, evaluated_head):
            failures.append("SPR_SUCCESSOR_BINDING_ANCESTRY_INVALID")
        tree_pairs = {
            "revalidation_binding_tree_sha": binding_head,
            "authority_baseline_tree_sha": BASELINE_HEAD,
            "authority_transition_parent_tree_sha": CHANGE_PARENT,
            "authority_transition_commit_tree_sha": CHANGE_COMMIT,
        }
        for field, commit in tree_pairs.items():
            if manifest.get(field) != _git(root, "rev-parse", f"{commit}^{{tree}}"):
                failures.append(f"SPR_SUCCESSOR_TREE_BINDING_INVALID:{field}")
    except Exception:
        failures.append("SPR_SUCCESSOR_BINDING_UNRESOLVED")

    bindings = manifest.get("record_bindings", []) if isinstance(manifest.get("record_bindings"), list) else []
    covered: list[str] = []
    review_trusted: dict[str, dict[str, Any]] = {}
    committed_trusted: dict[str, dict[str, Any]] = {}
    previous = str(manifest.get("record_chain_start_sha256", ""))
    for index, binding in enumerate(bindings):
        record_failures: list[str] = []
        if not isinstance(binding, dict) or set(binding) != BINDING_FIELDS:
            failures.append(f"SPR_SUCCESSOR_BINDING_FIELDS_INVALID:{index}")
            continue
        relative = str(binding.get("path", ""))
        try:
            path = _artifact_file(root, stage_dir, relative)
            raw = path.read_bytes()
            record = strict_json_bytes(raw)
            if mode == "COMMITTED":
                committed = _blob(root, evaluated_head, relative)
                if committed is None or committed != raw:
                    record_failures.append("SPR_SUCCESSOR_RECORD_COMMITTED_BYTES_INVALID")
        except Exception:
            failures.append(f"SPR_SUCCESSOR_RECORD_UNREADABLE:{index}")
            continue
        record_failures.extend(_record_shape_failures(record))
        fps = _fingerprints(record.get("failure_fingerprints"), 1) if isinstance(record, dict) else None
        if fps is None:
            failures.extend(f"{code}:{index}" for code in record_failures)
            continue
        fp = fps[0]
        covered.append(fp)
        if fp not in TARGET_FINGERPRINTS:
            record_failures.append("SPR_SUCCESSOR_RECORD_NOT_TARGET")
            failures.extend(f"{code}:{fp}" for code in record_failures)
            continue
        if fp != TARGET_FINGERPRINTS[index] or relative != EXPECTED_RECORD_PATHS[fp]:
            record_failures.append("SPR_SUCCESSOR_RECORD_IDENTITY_PATH_INVALID")
        if record.get("revalidation_id") != EXPECTED_REVALIDATION_IDS[fp]:
            record_failures.append("SPR_SUCCESSOR_REVALIDATION_ID_INVALID")
        if record.get("created_at") != manifest.get("created_at") or record.get("creator") != manifest.get("creator"):
            record_failures.append("SPR_SUCCESSOR_RECORD_MANIFEST_IDENTITY_MISMATCH")
        if binding.get("record_sha256") != sha256_bytes(raw):
            record_failures.append("SPR_SUCCESSOR_BINDING_RECORD_SHA_INVALID")
        for key in ("record_payload_sha256", "revalidation_id", "failure_fingerprints", "prior_record_path", "prior_record_sha256", "prior_record_payload_sha256", "prior_correction_id", "previous_revalidation_chain_sha256"):
            if binding.get(key) != record.get(key):
                record_failures.append(f"SPR_SUCCESSOR_BINDING_RECORD_MISMATCH:{key}")
        if record.get("previous_revalidation_chain_sha256") != previous:
            record_failures.append("SPR_SUCCESSOR_CHAIN_BREAK")
        previous = str(record.get("record_payload_sha256", ""))
        prior, prior_failures = _prior_record(root, evaluated_head, fp)
        record_failures.extend(prior_failures)
        identity = prior.get("identity", {})
        if record.get("prior_record_path") != PRIOR_RECORD_PATHS[fp] or record.get("prior_record_sha256") != PRIOR_RECORD_SHA256[fp] or record.get("prior_record_payload_sha256") != PRIOR_RECORD_PAYLOAD_SHA256[fp] or record.get("prior_correction_id") != PRIOR_CORRECTION_IDS[fp]:
            record_failures.append("SPR_SUCCESSOR_PRIOR_RECORD_BINDING_INVALID")
        if record.get("prior_identity_binding") != identity:
            record_failures.append("SPR_SUCCESSOR_PRIOR_IDENTITY_BINDING_INVALID")
        if record.get("authority_selectors") != identity.get("authority_selectors"):
            record_failures.append("SPR_SUCCESSOR_SELECTOR_NOT_PRIOR_EXACT")
        try:
            prior_head = str(prior.get("document", {}).get("binding_head_sha", ""))
            prior_projection = subject_projection(root, prior_head, TARGET_SELECTOR)
            pre_change = subject_projection(root, CHANGE_PARENT, TARGET_SELECTOR)
            rebound = subject_projection(root, CHANGE_COMMIT, TARGET_SELECTOR)
            live = subject_projection(root, evaluated_head, TARGET_SELECTOR)
            if _projection_sha(prior_projection) != PRIOR_PROJECTION_SHA256 or identity.get("subject_projection") != prior_projection or identity.get("subject_projection_sha256") != PRIOR_PROJECTION_SHA256:
                record_failures.append("SPR_SUCCESSOR_PRIOR_PROJECTION_RECOMPUTE_INVALID")
            comparisons = (
                ("prior_subject_projection", "prior_subject_projection_sha256", prior_projection, PRIOR_PROJECTION_SHA256),
                ("pre_change_subject_projection", "pre_change_subject_projection_sha256", pre_change, PRIOR_PROJECTION_SHA256),
                ("rebound_subject_projection", "rebound_subject_projection_sha256", rebound, REBOUND_PROJECTION_SHA256),
                ("live_subject_projection", "live_subject_projection_sha256", live, REBOUND_PROJECTION_SHA256),
            )
            for field, sha_field, value, expected_sha in comparisons:
                if record.get(field) != value or record.get(sha_field) != _projection_sha(value) or _projection_sha(value) != expected_sha:
                    record_failures.append(f"SPR_SUCCESSOR_PROJECTION_INVALID:{field}")
            changed_sections = sorted(key for key in PROJECTION_FIELDS if pre_change.get(key) != rebound.get(key))
            added = _added_registry_rows(pre_change, rebound)
            if changed_sections != ["registry_rows"] or record.get("changed_projection_sections") != changed_sections:
                record_failures.append("SPR_SUCCESSOR_PROJECTION_SCOPE_INVALID")
            if record.get("added_registry_rows") != added or len(added) != 1 or added[0].get("component_id") != TARGET_COMPONENT or added[0].get("authority_source_kind") != "historical_identity_backfill":
                record_failures.append("SPR_SUCCESSOR_SELECTOR_VISIBLE_ROW_INVALID")
            changing: list[str] = []
            commits = str(_git(root, "rev-list", "--reverse", f"{prior_head}..{evaluated_head}", "--", *PROJECTION_AUTHORITY_PATHS)).splitlines()
            for commit in commits:
                parent = str(_git(root, "rev-parse", f"{commit}^1"))
                if subject_projection(root, parent, TARGET_SELECTOR) != subject_projection(root, commit, TARGET_SELECTOR):
                    changing.append(commit)
            if changing != [CHANGE_COMMIT]:
                record_failures.append("SPR_SUCCESSOR_PROJECTION_CHANGE_NOT_UNIQUE")
        except Exception:
            record_failures.append("SPR_SUCCESSOR_PROJECTION_RECOMPUTE_FAILED")
        product_blobs = [_blob(root, commit, PRODUCT_PATH) for commit in (BASELINE_HEAD, CHANGE_PARENT, CHANGE_COMMIT, binding_head, evaluated_head)]
        if any(value is None or sha256_bytes(value) != PRODUCT_BLOB_SHA256 for value in product_blobs) or len({value for value in product_blobs if value is not None}) != 1:
            record_failures.append("SPR_SUCCESSOR_PRODUCT_BLOB_CHANGED")
        try:
            touches = [line for line in str(_git(root, "rev-list", "--reverse", f"{CHANGE_PARENT}..{evaluated_head}", "--", PRODUCT_PATH)).splitlines() if line]
            if touches:
                record_failures.append("SPR_SUCCESSOR_PRODUCT_PATH_TOUCHED")
        except Exception:
            record_failures.append("SPR_SUCCESSOR_PRODUCT_TOUCH_SCAN_FAILED")
        if record.get("authority_transition_proof") != proof:
            record_failures.append("SPR_SUCCESSOR_TRANSITION_PROOF_INVALID")
        if record.get("revalidation_binding_head_sha") != binding_head or record.get("revalidation_binding_tree_sha") != manifest.get("revalidation_binding_tree_sha"):
            record_failures.append("SPR_SUCCESSOR_RECORD_BINDING_HEAD_TREE_INVALID")
        if record_failures:
            failures.extend(f"{code}:{fp}" for code in record_failures)
        else:
            trust_row = {
                "allowed_invalidations": [ALLOWED_INVALIDATION],
                "prior_record_path": record.get("prior_record_path"),
                "revalidation_id": record.get("revalidation_id"),
                "record_path": relative,
                "revalidation_binding_head_sha": binding_head,
            }
            review_trusted[fp] = trust_row
            if mode == "COMMITTED":
                committed_trusted[fp] = trust_row
    if sorted(covered) != list(TARGET_FINGERPRINTS) or len(set(covered)) != 2:
        failures.append("SPR_SUCCESSOR_RECORD_COVERAGE_INVALID")
    if previous != manifest.get("record_chain_terminal_sha256"):
        failures.append("SPR_SUCCESSOR_CHAIN_TERMINAL_INVALID")
    failures = sorted(set(failures))
    if failures:
        review_trusted = {}
        committed_trusted = {}
    return {
        "status": "PASS" if not failures else "FAIL",
        "mode": mode,
        "failures": failures,
        "manifest": manifest,
        "trusted_by_fingerprint": committed_trusted,
        "review_trusted_by_fingerprint": review_trusted,
        "trusted_fingerprint_count": len(committed_trusted),
        "review_trusted_fingerprint_count": len(review_trusted),
        "record_count": len(bindings),
        "fingerprints": sorted(set(covered)),
        "stage_only": mode == "STAGE_REVIEW",
    }


def allows_invalidation(trusted_by_fingerprint: dict[str, dict[str, Any]], *, fingerprint: str, invalidation_code: str, prior_record_path: str) -> bool:
    if invalidation_code != ALLOWED_INVALIDATION or not _exact_path(prior_record_path):
        return False
    row = trusted_by_fingerprint.get(fingerprint)
    return isinstance(row, dict) and set(row) == TRUST_ROW_FIELDS and row.get("allowed_invalidations") == [ALLOWED_INVALIDATION] and row.get("prior_record_path") == prior_record_path


def trust_sets_disjoint(predecessor_fingerprints: Iterable[str], successor_fingerprints: Iterable[str]) -> bool:
    """Return whether the frozen predecessor and explicit successor trust sets do not overlap."""
    predecessor = list(predecessor_fingerprints)
    successor = list(successor_fingerprints)
    return len(predecessor) == len(set(predecessor)) and len(successor) == len(set(successor)) and not (set(predecessor) & set(successor))


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
    result = validate_manifest_and_records(
        root,
        args.manifest.resolve(),
        evaluated_head=head,
        current_batch_manifest_path=(args.current_batch_manifest or root / CURRENT_BATCH_PATH).resolve(),
        explicit_batch_manifest_paths=args.explicit_batch_manifest or default_explicit_batch_paths(root),
        stage_dir=args.stage_dir.resolve() if args.stage_dir is not None else None,
    )
    print(json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2))
    return 0 if result.get("status") == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
