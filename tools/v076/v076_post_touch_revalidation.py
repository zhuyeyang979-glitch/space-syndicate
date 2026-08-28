#!/usr/bin/env python3
"""Strict append-only post-touch revalidation for full-convergence records.

This module is deliberately small and data-only.  A normal full-convergence
correction is invalidated when one of its bound paths/blob/projections is
touched.  A *post-touch revalidation* does not edit that historical record and
does not add its fingerprint to a correction batch.  It is a separate,
explicitly enumerated successor receipt which proves the exact old record,
the exact touch commit/path, and the exact current projection at a new binding
Head.  Callers still decide whether the receipt is trusted after running the
repository/projection checks in :func:`validate_manifest_and_records`.

No directory discovery is used as authority.  Every manifest and record path
is supplied by the caller or is listed in the manifest itself.  The module has
no Godot/runtime dependencies.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
from pathlib import Path, PurePosixPath
from typing import Any, Callable, Iterable


SCHEMA_VERSION = (
    "space_syndicate.v076.reuse_exact_failure_correction.v2."
    "post_touch_revalidation_schema.v1"
)
MANIFEST_SCHEMA_VERSION = (
    "space_syndicate.v076.reuse_exact_failure_correction.v2."
    "post_touch_revalidation_manifest.v1"
)
RECORD_SCHEMA_VERSION = (
    "space_syndicate.v076.reuse_exact_failure_correction.v2."
    "post_touch_revalidation_record.v1"
)
MANIFEST_KIND = "POST_TOUCH_REVALIDATION_MANIFEST"
RECORD_KIND = "POST_TOUCH_REVALIDATION_RECORD"
AUTHORIZATION_ID = "USER_AUTHORIZATION_V076_REUSE_FULL_CONVERGENCE_AND_MCP_ONLY_20260827"
AUTHORIZATION_BASE_HEAD = "d701a81dce693b584d52fbfca3e0e78b521ad775"
FULL_CONVERGENCE_EPOCH_ID = "FULL_CONVERGENCE_20260827"

SCHEMA_REL = Path(
    "docs/architecture/reuse_corrections/v2/"
    "schema_post_touch_revalidation_20260828.json"
)
MANIFEST_ROOT = Path(
    "docs/architecture/reuse_corrections/v2/post_touch_revalidation"
)
RECORD_ROOT = MANIFEST_ROOT / "records"
FULL_BATCH_ROOT = Path("docs/architecture/reuse_corrections/v2/batches/full_convergence_20260827")
FULL_RECORD_ROOT = Path("docs/architecture/reuse_corrections/v2/records/full_convergence_20260827")
FULL_BATCH_SCHEMA_VERSION = (
    "space_syndicate.v076.reuse_exact_failure_correction.v2."
    "full_convergence_batch.v1"
)
LEGACY_RECORD_CHAIN_TERMINAL_SHA256 = (
    "99f051cd23c250e0282db1708e49e2625d0e82279753a846a00a713614fed67d"
)

# Filled after the schema document is added.  The digest is the exact Git
# blob/worktree byte digest, not a JSON semantic digest.
AUTHORIZED_SCHEMA_SHA256 = "706d4f298ea9e83972ad9820e5bd2d9d215b38b168dd5454f94174fb18667c4e"

SCHEMA_FIELDS = frozenset(
    {
        "schema_version", "manifest_schema_version", "record_schema_version",
        "manifest_kind", "record_kind", "authorization_id",
        "authorization_base_head_sha", "prior_epoch_id",
        "no_correction_batch_fingerprint_reuse", "future_failure_auto_revalidation",
        "wildcard_allowed", "record_fingerprint_cardinality",
        "manifest_required_fields", "record_required_fields",
        "manifest_record_binding_fields", "touch_proof_fields",
        "allowed_invalidations", "touch_invalidation_policy", "future_failure_policy",
        "revocation_policy",
    }
)

MANIFEST_FIELDS = frozenset(
    {
        "schema_version",
        "manifest_kind",
        "manifest_id",
        "authorization_id",
        "authorization_base_head_sha",
        "schema_sha256",
        "prior_epoch_id",
        "revalidation_binding_head_sha",
        "revalidation_binding_tree_sha",
        "current_batch_manifest_path",
        "current_batch_manifest_sha256",
        "current_batch_fingerprint_set_sha256",
        "record_count",
        "failure_fingerprints",
        "failure_fingerprint_set_sha256",
        "record_bindings",
        "record_chain_start_sha256",
        "record_chain_terminal_sha256",
        "previous_revalidation_manifest_path",
        "previous_revalidation_manifest_sha256",
        "no_correction_batch_fingerprint_reuse",
        "future_failure_auto_revalidation",
        "created_at",
        "creator",
    }
)

MANIFEST_RECORD_BINDING_FIELDS = frozenset(
    {
        "path",
        "record_sha256",
        "record_payload_sha256",
        "revalidation_id",
        "prior_record_path",
        "prior_record_sha256",
        "prior_record_payload_sha256",
        "prior_correction_id",
        "failure_fingerprints",
        "previous_revalidation_chain_sha256",
    }
)

TOUCH_PROOF_FIELDS = frozenset(
    {
        "commit_sha",
        "parent_sha",
        "path",
        "before_blob_sha256",
        "after_blob_sha256",
        "diff_sha256",
    }
)

RECORD_FIELDS = frozenset(
    {
        "schema_version",
        "record_kind",
        "revalidation_id",
        "authorization_id",
        "authorization_base_head_sha",
        "prior_record_path",
        "prior_record_sha256",
        "prior_record_payload_sha256",
        "prior_correction_id",
        "failure_fingerprints",
        "failure_fingerprint_set_sha256",
        "prior_binding_head_sha",
        "prior_binding_tree_sha",
        "revalidation_binding_head_sha",
        "revalidation_binding_tree_sha",
        "touch_proof",
        "prior_invalidations",
        "rebound_current_blob_sha256_by_path",
        "rebound_subject_projection_by_failure",
        "rebound_subject_projection_sha256_by_failure",
        "touch_invalidation_policy",
        "future_failure_policy",
        "new_effective_status",
        "revocation_policy",
        "previous_revalidation_chain_sha256",
        "correction_batch_manifest_path",
        "correction_batch_manifest_sha256",
        "created_at",
        "creator",
        "revalidation_reason",
        "record_payload_sha256",
    }
)

TOUCH_INVALIDATION_POLICY = {
    "BLOB_CHANGED_CORRECTION_AUTO_INVALIDATION": True,
    "COMPONENT_CHANGED_CORRECTION_AUTO_INVALIDATION": True,
    "DOMAIN_CHANGED_CORRECTION_AUTO_INVALIDATION": True,
    "OWNER_BINDING_CHANGED_INVALIDATION": True,
    "PRODUCTION_REACHABILITY_CHANGED_INVALIDATION": True,
    "RETIREMENT_CHANGED_INVALIDATION": True,
    "SUPERSESSION_CHANGED_INVALIDATION": True,
    "TOUCH_INVALIDATES_CORRECTION": True,
    "UNRELATED_DELTA_PRESERVES_CORRECTION": True,
}
FUTURE_FAILURE_POLICY = {
    "FUTURE_FAILURE_AUTO_REVALIDATION_COUNT": 0,
    "NEW_FAILURE_REQUIRES_NEW_RECORD": True,
}
REVOCATION_POLICY = {
    "CUMULATIVE_PREDECESSOR_TRUST": True,
    "OLD_RECORD_MUTATION_FORBIDDEN": True,
    "PREDECESSOR_FINGERPRINT_OVERLAP_ALLOWED": False,
    "PREDECESSOR_REVALIDATED_AT_CURRENT_EVALUATED_HEAD": True,
    "REVOCATION_APPEND_ONLY": True,
}

ALLOWED_INVALIDATIONS = frozenset(
    {
        "BLOB_CHANGED_CORRECTION_INVALID",
        "TOUCHED_CORRECTION_INVALID",
        "SUBJECT_PROJECTION_CHANGED_INVALID",
    }
)


def canonical_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
        + "\n"
    ).encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def line_set_sha(values: Iterable[str]) -> str:
    ordered = sorted(str(value) for value in values)
    return sha256_bytes(("\n".join(ordered) + "\n").encode("utf-8"))


def load_json_strict(path: Path) -> Any:
    def strict_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
        result: dict[str, Any] = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f"duplicate JSON key: {key}")
            result[key] = value
        return result

    return json.loads(path.read_text(encoding="utf-8-sig"), object_pairs_hook=strict_object)


def normalize_path(value: str) -> str:
    result = str(value).strip().replace("\\", "/")
    if result.startswith("res://"):
        result = result[6:]
    while "//" in result:
        result = result.replace("//", "/")
    return result


def is_sha256(value: Any) -> bool:
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{64}", value) is not None


def is_commit(value: Any) -> bool:
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{40}", value) is not None


def is_tree_oid(value: Any) -> bool:
    """Git tree objects use the same 40-hex SHA-1 OID shape as commits."""

    return is_commit(value)


def is_exact_int(value: Any, expected: int | None = None) -> bool:
    valid = type(value) is int and (expected is None or value == expected)
    return bool(valid)


def record_payload(record: dict[str, Any]) -> dict[str, Any]:
    return {key: value for key, value in record.items() if key != "record_payload_sha256"}


def _contains_selector(value: Any) -> bool:
    return any(char in str(value) for char in "*?[]")


def _exact_path(value: Any) -> bool:
    if not isinstance(value, str):
        return False
    # Validate the original spelling before normalization so `./x`, `a/./b`,
    # trailing separators, UNC paths, and separator aliases cannot collapse
    # into an apparently safe path.
    if not value or value.startswith(("/", "\\")) or value.endswith(("/", "\\")):
        return False
    if "\\" in value or "\x00" in value or ":" in value:
        return False
    raw_parts = value.split("/")
    if any(part in ("", ".", "..") for part in raw_parts):
        return False
    normalized = normalize_path(value)
    if not normalized or normalized != value or normalized.startswith("/"):
        return False
    if _contains_selector(normalized):
        return False
    try:
        parts = PurePosixPath(normalized).parts
    except (TypeError, ValueError):
        return False
    return bool(parts) and all(part not in ("", ".", "..") for part in parts)


def _exact_timestamp(value: Any) -> bool:
    return isinstance(value, str) and re.fullmatch(
        r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z", value
    ) is not None


def validate_schema_document(document: Any) -> list[str]:
    """Validate the immutable post-touch schema's semantic contract."""

    if not isinstance(document, dict):
        return ["POST_TOUCH_SCHEMA_NOT_OBJECT"]
    failures: list[str] = []
    if set(document) != SCHEMA_FIELDS:
        failures.append("POST_TOUCH_SCHEMA_FIELD_SET_MISMATCH")
    expected = {
        "schema_version": SCHEMA_VERSION,
        "manifest_schema_version": MANIFEST_SCHEMA_VERSION,
        "record_schema_version": RECORD_SCHEMA_VERSION,
        "manifest_kind": MANIFEST_KIND,
        "record_kind": RECORD_KIND,
        "authorization_id": AUTHORIZATION_ID,
        "authorization_base_head_sha": AUTHORIZATION_BASE_HEAD,
        "prior_epoch_id": FULL_CONVERGENCE_EPOCH_ID,
        "no_correction_batch_fingerprint_reuse": True,
        "future_failure_auto_revalidation": False,
        "wildcard_allowed": False,
        "record_fingerprint_cardinality": "ONE_EXACT_FINGERPRINT_PER_RECORD",
    }
    for key, value in expected.items():
        if document.get(key) != value:
            failures.append(f"POST_TOUCH_SCHEMA_{key.upper()}_MISMATCH")
    manifest_fields = document.get("manifest_required_fields")
    if not isinstance(manifest_fields, list) or any(not isinstance(x, str) for x in manifest_fields) or set(manifest_fields) != set(MANIFEST_FIELDS):
        failures.append("POST_TOUCH_SCHEMA_MANIFEST_FIELDS_MISMATCH")
    record_fields = document.get("record_required_fields")
    if not isinstance(record_fields, list) or any(not isinstance(x, str) for x in record_fields) or set(record_fields) != set(RECORD_FIELDS):
        failures.append("POST_TOUCH_SCHEMA_RECORD_FIELDS_MISMATCH")
    binding_fields = document.get("manifest_record_binding_fields")
    if not isinstance(binding_fields, list) or any(not isinstance(x, str) for x in binding_fields) or set(binding_fields) != set(
        MANIFEST_RECORD_BINDING_FIELDS
    ):
        failures.append("POST_TOUCH_SCHEMA_MANIFEST_BINDING_FIELDS_MISMATCH")
    touch_fields = document.get("touch_proof_fields")
    if not isinstance(touch_fields, list) or any(not isinstance(x, str) for x in touch_fields) or set(touch_fields) != set(TOUCH_PROOF_FIELDS):
        failures.append("POST_TOUCH_SCHEMA_TOUCH_PROOF_FIELDS_MISMATCH")
    allowed_invalidations = document.get("allowed_invalidations")
    if not isinstance(allowed_invalidations, list) or any(not isinstance(x, str) for x in allowed_invalidations) or set(allowed_invalidations) != set(ALLOWED_INVALIDATIONS):
        failures.append("POST_TOUCH_SCHEMA_ALLOWED_INVALIDATIONS_MISMATCH")
    if document.get("touch_invalidation_policy") != TOUCH_INVALIDATION_POLICY:
        failures.append("POST_TOUCH_SCHEMA_TOUCH_POLICY_MISMATCH")
    if document.get("future_failure_policy") != FUTURE_FAILURE_POLICY:
        failures.append("POST_TOUCH_SCHEMA_FUTURE_POLICY_MISMATCH")
    if document.get("revocation_policy") != REVOCATION_POLICY:
        failures.append("POST_TOUCH_SCHEMA_REVOCATION_POLICY_MISMATCH")
    return sorted(set(failures))


def validate_schema_file(root: Path) -> list[str]:
    path = root / SCHEMA_REL
    if not path.is_file():
        return ["POST_TOUCH_SCHEMA_MISSING"]
    if AUTHORIZED_SCHEMA_SHA256 == "TO_BE_FILLED":
        return ["POST_TOUCH_SCHEMA_HASH_NOT_AUTHORIZED"]
    try:
        digest = sha256_file(path)
        document = load_json_strict(path)
    except (OSError, ValueError, json.JSONDecodeError):
        return ["POST_TOUCH_SCHEMA_UNREADABLE"]
    failures = []
    if digest != AUTHORIZED_SCHEMA_SHA256:
        failures.append("POST_TOUCH_SCHEMA_HASH_MISMATCH")
    failures.extend(validate_schema_document(document))
    return sorted(set(failures))


def validate_manifest_document(document: Any) -> list[str]:
    if not isinstance(document, dict):
        return ["POST_TOUCH_MANIFEST_NOT_OBJECT"]
    failures: list[str] = []
    if set(document) != set(MANIFEST_FIELDS):
        failures.append("POST_TOUCH_MANIFEST_FIELD_SET_MISMATCH")
    for key, expected in (
        ("schema_version", MANIFEST_SCHEMA_VERSION),
        ("manifest_kind", MANIFEST_KIND),
        ("authorization_id", AUTHORIZATION_ID),
        ("authorization_base_head_sha", AUTHORIZATION_BASE_HEAD),
        ("prior_epoch_id", FULL_CONVERGENCE_EPOCH_ID),
        ("no_correction_batch_fingerprint_reuse", True),
        ("future_failure_auto_revalidation", False),
    ):
        actual = document.get(key)
        mismatch = actual is not expected if isinstance(expected, bool) else actual != expected
        if mismatch:
            failures.append(f"POST_TOUCH_MANIFEST_{key.upper()}_MISMATCH")
    if document.get("schema_sha256") != AUTHORIZED_SCHEMA_SHA256:
        failures.append("POST_TOUCH_MANIFEST_SCHEMA_HASH_INVALID")
    for key in ("revalidation_binding_head_sha",):
        if not is_commit(document.get(key)):
            failures.append(f"POST_TOUCH_MANIFEST_{key.upper()}_INVALID")
    for key in (
        "revalidation_binding_tree_sha",
        "current_batch_manifest_sha256",
        "current_batch_fingerprint_set_sha256",
        "failure_fingerprint_set_sha256",
        "record_chain_terminal_sha256",
    ):
        if key == "revalidation_binding_tree_sha":
            valid = is_tree_oid(document.get(key))
        else:
            valid = is_sha256(document.get(key))
        if not valid:
            failures.append(f"POST_TOUCH_MANIFEST_{key.upper()}_INVALID")
    if not isinstance(document.get("current_batch_manifest_path"), str) or not _exact_path(
        document.get("current_batch_manifest_path")
    ):
        failures.append("POST_TOUCH_MANIFEST_CURRENT_BATCH_PATH_INVALID")
    elif not normalize_path(str(document.get("current_batch_manifest_path"))).startswith(
        normalize_path(str(FULL_BATCH_ROOT)) + "/"
    ):
        failures.append("POST_TOUCH_MANIFEST_CURRENT_BATCH_PATH_SCOPE_INVALID")
    if not isinstance(document.get("manifest_id"), str) or not document.get("manifest_id") or _contains_selector(document.get("manifest_id")):
        failures.append("POST_TOUCH_MANIFEST_ID_INVALID")
    if not _exact_timestamp(document.get("created_at")):
        failures.append("POST_TOUCH_MANIFEST_CREATED_AT_INVALID")
    if not isinstance(document.get("creator"), str) or not document.get("creator") or _contains_selector(document.get("creator")):
        failures.append("POST_TOUCH_MANIFEST_CREATOR_INVALID")
    fingerprints = document.get("failure_fingerprints")
    rendered = [str(value) for value in fingerprints] if isinstance(fingerprints, list) else []
    if (
        not rendered
        or rendered != sorted(rendered)
        or len(rendered) != len(set(rendered))
        or any(re.fullmatch(r"V2F-[0-9a-f]{64}", value) is None for value in rendered)
    ):
        failures.append("POST_TOUCH_MANIFEST_FINGERPRINT_SET_INVALID")
    if not is_exact_int(document.get("record_count"), len(rendered)):
        failures.append("POST_TOUCH_MANIFEST_RECORD_COUNT_MISMATCH")
    if document.get("failure_fingerprint_set_sha256") != line_set_sha(rendered):
        failures.append("POST_TOUCH_MANIFEST_FINGERPRINT_SET_HASH_MISMATCH")
    bindings = document.get("record_bindings")
    if not isinstance(bindings, list) or len(bindings) != len(rendered) or not bindings:
        failures.append("POST_TOUCH_MANIFEST_RECORD_BINDINGS_INVALID")
        bindings = []
    covered: list[str] = []
    previous = document.get("record_chain_start_sha256")
    previous_manifest_path = document.get("previous_revalidation_manifest_path")
    previous_manifest_sha = document.get("previous_revalidation_manifest_sha256")
    if not isinstance(previous_manifest_path, str) or not _exact_path(previous_manifest_path):
        if previous_manifest_path != "":
            failures.append("POST_TOUCH_MANIFEST_PREVIOUS_PATH_INVALID")
    if previous_manifest_path == "":
        if previous_manifest_sha != "" or previous != "":
            failures.append("POST_TOUCH_MANIFEST_INITIAL_CHAIN_NOT_EMPTY")
    else:
        if not isinstance(previous_manifest_path, str) or not previous_manifest_path.startswith(normalize_path(str(MANIFEST_ROOT)) + "/"):
            failures.append("POST_TOUCH_MANIFEST_PREVIOUS_PATH_SCOPE_INVALID")
        if not is_sha256(previous_manifest_sha):
            failures.append("POST_TOUCH_MANIFEST_PREVIOUS_SHA_INVALID")
        if not is_sha256(previous):
            failures.append("POST_TOUCH_MANIFEST_CHAIN_START_INVALID")
    for index, binding in enumerate(bindings):
        if not isinstance(binding, dict) or set(binding) != set(MANIFEST_RECORD_BINDING_FIELDS):
            failures.append(f"POST_TOUCH_MANIFEST_RECORD_BINDING_FIELDS_INVALID:{index}")
            continue
        path = binding.get("path")
        if not _exact_path(path) or not normalize_path(path).startswith(
            normalize_path(str(RECORD_ROOT)) + "/"
        ):
            failures.append(f"POST_TOUCH_MANIFEST_RECORD_PATH_INVALID:{index}")
        for key in (
            "record_sha256",
            "record_payload_sha256",
            "prior_record_sha256",
            "prior_record_payload_sha256",
        ):
            if not is_sha256(binding.get(key)):
                failures.append(f"POST_TOUCH_MANIFEST_RECORD_{key.upper()}_INVALID:{index}")
        if not isinstance(binding.get("revalidation_id"), str) or not binding.get("revalidation_id"):
            failures.append(f"POST_TOUCH_MANIFEST_REVALIDATION_ID_INVALID:{index}")
        prior_record_path = binding.get("prior_record_path")
        if not _exact_path(prior_record_path) or not normalize_path(str(prior_record_path)).startswith(
            normalize_path(str(FULL_RECORD_ROOT)) + "/"
        ):
            failures.append(f"POST_TOUCH_MANIFEST_PRIOR_RECORD_PATH_INVALID:{index}")
        if not isinstance(binding.get("prior_correction_id"), str) or not binding.get("prior_correction_id") or _contains_selector(binding.get("prior_correction_id")):
            failures.append(f"POST_TOUCH_MANIFEST_PRIOR_CORRECTION_ID_INVALID:{index}")
        values = binding.get("failure_fingerprints")
        values = [str(value) for value in values] if isinstance(values, list) else []
        if len(values) != 1 or any(re.fullmatch(r"V2F-[0-9a-f]{64}", value) is None for value in values):
            failures.append(f"POST_TOUCH_MANIFEST_RECORD_FINGERPRINT_INVALID:{index}")
        if binding.get("previous_revalidation_chain_sha256") != previous:
            failures.append(f"POST_TOUCH_MANIFEST_RECORD_CHAIN_BREAK:{index}")
        previous = binding.get("record_payload_sha256")
        covered.extend(values)
    if previous != document.get("record_chain_terminal_sha256"):
        failures.append("POST_TOUCH_MANIFEST_CHAIN_TERMINAL_MISMATCH")
    if sorted(covered) != rendered or len(covered) != len(set(covered)):
        failures.append("POST_TOUCH_MANIFEST_RECORD_COVERAGE_MISMATCH")
    return sorted(set(failures))


def _is_sha(value: Any) -> bool:
    return is_sha256(value)


def validate_record_document(document: Any) -> list[str]:
    if not isinstance(document, dict):
        return ["POST_TOUCH_RECORD_NOT_OBJECT"]
    failures: list[str] = []
    if set(document) != set(RECORD_FIELDS):
        failures.append("POST_TOUCH_RECORD_FIELD_SET_MISMATCH")
    for key, expected in (
        ("schema_version", RECORD_SCHEMA_VERSION),
        ("record_kind", RECORD_KIND),
        ("authorization_id", AUTHORIZATION_ID),
        ("authorization_base_head_sha", AUTHORIZATION_BASE_HEAD),
        ("new_effective_status", "CORRECTED_HISTORICAL_DEBT"),
    ):
        if document.get(key) != expected:
            failures.append(f"POST_TOUCH_RECORD_{key.upper()}_MISMATCH")
    if document.get("revocation_policy") != REVOCATION_POLICY:
        failures.append("POST_TOUCH_RECORD_REVOCATION_POLICY_MISMATCH")
    for key in (
        "prior_record_sha256",
        "prior_record_payload_sha256",
        "correction_batch_manifest_sha256",
    ):
        if not is_sha256(document.get(key)):
            failures.append(f"POST_TOUCH_RECORD_{key.upper()}_INVALID")
    for key in ("prior_binding_tree_sha", "revalidation_binding_tree_sha"):
        if not is_tree_oid(document.get(key)):
            failures.append(f"POST_TOUCH_RECORD_{key.upper()}_INVALID")
    for key in (
        "prior_binding_head_sha",
        "revalidation_binding_head_sha",
    ):
        if not is_commit(document.get(key)):
            failures.append(f"POST_TOUCH_RECORD_{key.upper()}_INVALID")
    for key in ("prior_record_path", "correction_batch_manifest_path"):
        if not _exact_path(document.get(key)):
            failures.append(f"POST_TOUCH_RECORD_{key.upper()}_INVALID")
    for key in ("revalidation_id", "prior_correction_id", "creator", "revalidation_reason"):
        value = document.get(key)
        if not isinstance(value, str) or not value or _contains_selector(value):
            failures.append(f"POST_TOUCH_RECORD_{key.upper()}_INVALID")
    if not _exact_timestamp(document.get("created_at")):
        failures.append("POST_TOUCH_RECORD_CREATED_AT_INVALID")
    fingerprints = document.get("failure_fingerprints")
    rendered = [str(value) for value in fingerprints] if isinstance(fingerprints, list) else []
    if len(rendered) != 1 or any(re.fullmatch(r"V2F-[0-9a-f]{64}", value) is None for value in rendered):
        failures.append("POST_TOUCH_RECORD_FINGERPRINT_INVALID")
    if document.get("failure_fingerprint_set_sha256") != line_set_sha(rendered):
        failures.append("POST_TOUCH_RECORD_FINGERPRINT_SET_HASH_MISMATCH")
    touch_proof = document.get("touch_proof")
    if not isinstance(touch_proof, dict) or set(touch_proof) != set(TOUCH_PROOF_FIELDS):
        failures.append("POST_TOUCH_RECORD_TOUCH_PROOF_FIELDS_INVALID")
    else:
        if not is_commit(touch_proof.get("commit_sha")) or not is_commit(touch_proof.get("parent_sha")):
            failures.append("POST_TOUCH_RECORD_TOUCH_COMMIT_INVALID")
        if not _exact_path(touch_proof.get("path")):
            failures.append("POST_TOUCH_RECORD_TOUCH_PATH_INVALID")
        for key in ("before_blob_sha256", "after_blob_sha256", "diff_sha256"):
            if not is_sha256(touch_proof.get(key)) and touch_proof.get(key) != "MISSING":
                failures.append(f"POST_TOUCH_RECORD_TOUCH_{key.upper()}_INVALID")
    invalidations = document.get("prior_invalidations")
    rendered_invalidations = [str(value) for value in invalidations] if isinstance(invalidations, list) else []
    if (
        not rendered_invalidations
        or rendered_invalidations != sorted(rendered_invalidations)
        or len(rendered_invalidations) != len(set(rendered_invalidations))
        or any(value not in ALLOWED_INVALIDATIONS for value in rendered_invalidations)
        or "TOUCHED_CORRECTION_INVALID" not in rendered_invalidations
    ):
        failures.append("POST_TOUCH_RECORD_INVALIDATION_SET_INVALID")
    blobs = document.get("rebound_current_blob_sha256_by_path")
    if not isinstance(blobs, dict) or not blobs or any(
        not _exact_path(key) or (value != "MISSING" and not is_sha256(value))
        for key, value in blobs.items()
    ):
        failures.append("POST_TOUCH_RECORD_REBOUND_BLOB_MAP_INVALID")
    projections = document.get("rebound_subject_projection_by_failure")
    projection_hashes = document.get("rebound_subject_projection_sha256_by_failure")
    if not isinstance(projections, dict) or set(projections) != set(rendered):
        failures.append("POST_TOUCH_RECORD_REBOUND_PROJECTION_SET_INVALID")
    if not isinstance(projection_hashes, dict) or set(projection_hashes) != set(rendered):
        failures.append("POST_TOUCH_RECORD_REBOUND_PROJECTION_HASH_SET_INVALID")
    else:
        for fingerprint in rendered:
            projection = projections.get(fingerprint) if isinstance(projections, dict) else None
            if not isinstance(projection, dict) or projection_hashes.get(fingerprint) != sha256_bytes(canonical_bytes(projection)):
                failures.append(f"POST_TOUCH_RECORD_REBOUND_PROJECTION_HASH_MISMATCH:{fingerprint}")
    if document.get("touch_invalidation_policy") != TOUCH_INVALIDATION_POLICY:
        failures.append("POST_TOUCH_RECORD_TOUCH_POLICY_MISMATCH")
    if document.get("future_failure_policy") != FUTURE_FAILURE_POLICY:
        failures.append("POST_TOUCH_RECORD_FUTURE_POLICY_MISMATCH")
    previous = document.get("previous_revalidation_chain_sha256")
    if previous != "" and not is_sha256(previous):
        failures.append("POST_TOUCH_RECORD_CHAIN_PREDECESSOR_INVALID")
    payload_hash = document.get("record_payload_sha256")
    if not is_sha256(payload_hash) or payload_hash != sha256_bytes(canonical_bytes(record_payload(document))):
        failures.append("POST_TOUCH_RECORD_PAYLOAD_HASH_MISMATCH")
    return sorted(set(failures))


def _git(root: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(root), *args],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if result.returncode != 0:
        raise ValueError(result.stderr.strip() or "git command failed")
    return result.stdout.strip()


def _git_bytes(root: Path, commit: str, relative: str) -> bytes | None:
    result = subprocess.run(
        [
            "git",
            "-C",
            str(root),
            "cat-file",
            "blob",
            f"{commit}:{normalize_path(relative)}",
        ],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return bytes(result.stdout) if result.returncode == 0 else None


def _safe_repo_path(root: Path, relative: str) -> Path | None:
    """Resolve a repository-relative path and reject symlink/path escapes."""

    if not _exact_path(relative):
        return None
    candidate = root / normalize_path(relative)
    try:
        resolved_root = root.resolve()
        # Reject symlink/reparse aliases in every path component, even when
        # the resolved target remains beneath the repository root.
        cursor = resolved_root
        for part in PurePosixPath(normalize_path(relative)).parts:
            cursor = cursor / part
            st = os.lstat(cursor)
            if os.path.islink(cursor) or bool(getattr(st, "st_file_attributes", 0) & 0x400):
                return None
        resolved = candidate.resolve()
        resolved.relative_to(resolved_root)
    except (OSError, ValueError):
        return None
    return resolved


def _git_diff_sha(root: Path, parent: str, commit: str, path: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(root), "diff", "--binary", "--no-ext-diff", parent, commit, "--", normalize_path(path)],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode != 0:
        return ""
    return sha256_bytes(bytes(result.stdout))


def _changed_paths(root: Path, old: str, new: str) -> set[str]:
    try:
        return {
            normalize_path(value)
            for value in _git(root, "diff", "--name-only", old, new).splitlines()
            if value.strip()
        }
    except ValueError:
        return set()


def _touch_commits(root: Path, old: str, new: str, path: str) -> list[str]:
    try:
        output = _git(root, "rev-list", "--reverse", f"{old}..{new}", "--", normalize_path(path))
    except ValueError:
        return []
    return [value for value in output.splitlines() if value]


def _derive_prior_batch_path(
    current_path: Path,
    current_batch_id: str,
    prior_batch_id: str,
) -> Path | None:
    """Derive one predecessor path without granting directory discovery."""

    if current_path.parent.name == current_batch_id:
        prior_name = (
            current_path.name.replace(current_batch_id, prior_batch_id, 1)
            if current_batch_id in current_path.name
            else current_path.name
        )
        return current_path.parent.parent / prior_batch_id / prior_name
    if current_batch_id in current_path.name:
        return current_path.with_name(
            current_path.name.replace(current_batch_id, prior_batch_id, 1)
        )
    return None


def _explicit_batch_chain(
    root: Path,
    current_batch_path: Path,
    current_batch: dict[str, Any],
    *,
    artifact_head: str,
) -> tuple[dict[str, str], list[str]]:
    """Load the exact hash-linked correction chain ending at current batch.

    The current batch is supplied explicitly by the caller.  Every predecessor
    path is derived from its exact numeric batch id, every manifest byte string
    must be committed at the artifact Head, and every link is sealed by
    ``previous_batch_append_sha256`` plus the record-chain terminal.  This is
    intentionally not directory discovery.
    """

    failures: list[str] = []
    authorized: dict[str, str] = {}
    current_path = current_batch_path.resolve()
    manifest: Any = current_batch
    expected_number: int | None = None
    seen_paths: set[str] = set()
    for depth in range(1, 512):
        if not isinstance(manifest, dict):
            failures.append("POST_TOUCH_BATCH_CHAIN_MANIFEST_NOT_OBJECT")
            break
        try:
            relative = current_path.relative_to(root.resolve()).as_posix()
        except ValueError:
            failures.append("POST_TOUCH_BATCH_CHAIN_PATH_OUTSIDE_ROOT")
            break
        safe_path = _safe_repo_path(root, relative)
        if safe_path is None or safe_path != current_path:
            failures.append("POST_TOUCH_BATCH_CHAIN_PATH_UNSAFE")
            break
        if relative in seen_paths:
            failures.append("POST_TOUCH_BATCH_CHAIN_CYCLE")
            break
        seen_paths.add(relative)
        try:
            local_bytes = current_path.read_bytes()
        except OSError:
            failures.append("POST_TOUCH_BATCH_CHAIN_MANIFEST_UNREADABLE")
            break
        digest = sha256_bytes(local_bytes)
        committed_bytes = _git_bytes(root, artifact_head, relative)
        if committed_bytes is None:
            failures.append("POST_TOUCH_BATCH_CHAIN_COMMITTED_BYTES_MISSING")
        elif committed_bytes != local_bytes:
            failures.append("POST_TOUCH_BATCH_CHAIN_COMMITTED_BYTES_MISMATCH")
        if manifest.get("schema_version") != FULL_BATCH_SCHEMA_VERSION:
            failures.append("POST_TOUCH_BATCH_CHAIN_SCHEMA_INVALID")
        if (
            manifest.get("authorization_id") != AUTHORIZATION_ID
            or manifest.get("authorization_base_head_sha") != AUTHORIZATION_BASE_HEAD
        ):
            failures.append("POST_TOUCH_BATCH_CHAIN_AUTHORITY_INVALID")
        match = re.fullmatch(r"batch-([0-9]{3})", str(manifest.get("batch_id", "")))
        if match is None:
            failures.append("POST_TOUCH_BATCH_CHAIN_BATCH_ID_INVALID")
            break
        number = int(match.group(1))
        if expected_number is not None and number != expected_number:
            failures.append("POST_TOUCH_BATCH_CHAIN_SEQUENCE_MISMATCH")
        authorized[relative] = digest
        previous_sha = manifest.get("previous_batch_append_sha256")
        if previous_sha == "":
            if number != 1:
                failures.append("POST_TOUCH_BATCH_CHAIN_DID_NOT_REACH_BATCH_001")
            if manifest.get("record_chain_start_sha256") != LEGACY_RECORD_CHAIN_TERMINAL_SHA256:
                failures.append("POST_TOUCH_BATCH_CHAIN_LEGACY_ANCHOR_MISMATCH")
            break
        if not is_sha256(previous_sha) or number <= 1:
            failures.append("POST_TOUCH_BATCH_CHAIN_PREVIOUS_APPEND_INVALID")
            break
        prior_id = f"batch-{number - 1:03d}"
        prior_path = _derive_prior_batch_path(current_path, f"batch-{number:03d}", prior_id)
        if prior_path is None:
            failures.append("POST_TOUCH_BATCH_CHAIN_PATH_NOT_SEQUENCE_BOUND")
            break
        try:
            prior = load_json_strict(prior_path)
            prior_sha = sha256_file(prior_path)
        except (OSError, ValueError, json.JSONDecodeError):
            failures.append("POST_TOUCH_BATCH_CHAIN_PREVIOUS_UNREADABLE")
            break
        if prior_sha != previous_sha:
            failures.append("POST_TOUCH_BATCH_CHAIN_PREVIOUS_SHA_MISMATCH")
        if not isinstance(prior, dict):
            failures.append("POST_TOUCH_BATCH_CHAIN_PREVIOUS_NOT_OBJECT")
            break
        if manifest.get("record_chain_start_sha256") != prior.get("record_chain_terminal_sha256"):
            failures.append("POST_TOUCH_BATCH_CHAIN_RECORD_TERMINAL_MISMATCH")
        current_path = prior_path.resolve()
        manifest = prior
        expected_number = number - 1
    else:
        failures.append("POST_TOUCH_BATCH_CHAIN_DEPTH_EXCEEDED")
    if failures:
        authorized = {}
    return authorized, sorted(set(failures))


def _prior_record_membership(
    root: Path,
    prior_batch_path: Path,
    prior_record_path: str,
    prior_record_id: str,
    fingerprint: str,
    expected_record_sha256: str,
    expected_payload_sha256: str,
) -> tuple[bool, str]:
    """Check exact prior record membership in the explicitly named batch.

    The function intentionally reads only the supplied predecessor manifest;
    callers can separately validate the complete correction chain.
    """

    try:
        batch = load_json_strict(prior_batch_path)
    except (OSError, ValueError, json.JSONDecodeError):
        return False, "POST_TOUCH_PRIOR_BATCH_UNREADABLE"
    if not isinstance(batch, dict):
        return False, "POST_TOUCH_PRIOR_BATCH_NOT_OBJECT"
    if batch.get("schema_version") != "space_syndicate.v076.reuse_exact_failure_correction.v2.full_convergence_batch.v1":
        return False, "POST_TOUCH_PRIOR_BATCH_SCHEMA_INVALID"
    if batch.get("authorization_id") != AUTHORIZATION_ID or batch.get("authorization_base_head_sha") != AUTHORIZATION_BASE_HEAD:
        return False, "POST_TOUCH_PRIOR_BATCH_AUTHORITY_INVALID"
    batch_head = str(batch.get("binding_head_sha", ""))
    batch_tree = str(batch.get("binding_tree_sha", ""))
    if not is_commit(batch_head) or not is_tree_oid(batch_tree):
        return False, "POST_TOUCH_PRIOR_BATCH_BINDING_INVALID"
    try:
        actual_tree = _git(root, "rev-parse", f"{batch_head}^{{tree}}")
    except ValueError:
        return False, "POST_TOUCH_PRIOR_BATCH_HEAD_UNRESOLVED"
    if actual_tree != batch_tree:
        return False, "POST_TOUCH_PRIOR_BATCH_TREE_MISMATCH"
    bindings = batch.get("record_bindings")
    if not isinstance(bindings, list):
        return False, "POST_TOUCH_PRIOR_BATCH_BINDINGS_INVALID"
    normalized = normalize_path(prior_record_path)
    matches: list[dict[str, Any]] = []
    for binding in bindings:
        if not isinstance(binding, dict):
            continue
        row_fingerprints = binding.get("failure_fingerprints")
        if not isinstance(row_fingerprints, list):
            continue
        if (
            normalize_path(str(binding.get("path", ""))) == normalized
            and str(binding.get("correction_id", "")) == prior_record_id
            and fingerprint in [str(value) for value in row_fingerprints]
            and str(binding.get("record_sha256", "")) == expected_record_sha256
            and str(binding.get("record_payload_sha256", "")) == expected_payload_sha256
        ):
            matches.append(binding)
    if len(matches) == 1:
        return True, ""
    if len(matches) > 1:
        return False, "POST_TOUCH_PRIOR_RECORD_MEMBERSHIP_NOT_UNIQUE"
    return False, "POST_TOUCH_PRIOR_RECORD_NOT_IN_EXPLICIT_BATCH"


ProjectionLoader = Callable[[Path, str, dict[str, Any]], dict[str, Any] | None]


def allows_invalidation(
    trusted_by_fingerprint: dict[str, dict[str, Any]],
    *,
    fingerprint: str,
    invalidation_code: str,
    prior_record_path: str,
) -> bool:
    """Require exact code, fingerprint, and correction-record identity."""

    trusted = trusted_by_fingerprint.get(fingerprint)
    if not isinstance(trusted, dict):
        return False
    allowed = trusted.get("allowed_invalidations")
    if not isinstance(allowed, list) or invalidation_code not in allowed:
        return False
    return normalize_path(str(trusted.get("prior_record_path", ""))) == normalize_path(
        str(prior_record_path)
    )


def _merge_disjoint_predecessor_trust(
    previous_result: dict[str, Any],
    current_fingerprints: Iterable[str],
) -> tuple[dict[str, dict[str, Any]], list[str]]:
    """Merge only typed predecessor trust with no fingerprint recurrence."""

    previous_value = previous_result.get("trusted_by_fingerprint", {})
    previous = (
        {
            str(key): value
            for key, value in previous_value.items()
            if isinstance(value, dict)
        }
        if isinstance(previous_value, dict)
        else {}
    )
    overlap = set(previous) & {str(value) for value in current_fingerprints}
    failures = [
        f"POST_TOUCH_PREDECESSOR_FINGERPRINT_OVERLAP:{fingerprint}"
        for fingerprint in sorted(overlap)
    ]
    return previous, failures


def validate_manifest_and_records(
    root: Path,
    manifest_path: Path,
    *,
    evaluated_head: str,
    current_batch_manifest_path: Path | None,
    projection_loader: ProjectionLoader,
    _chain_depth: int = 0,
    _artifact_head: str | None = None,
) -> dict[str, Any]:
    """Validate one explicit post-touch manifest and return trusted bindings.

    ``trusted_by_fingerprint`` is non-empty only when every structural and
    repository assertion passes.  Callers must not suppress old invalidation
    findings from a partially valid manifest.  The chain is cumulative and
    disjoint: every predecessor is revalidated at the current evaluated Head,
    predecessor trust is merged only after success, and a fingerprint may not
    recur in a successor manifest.  A second touch therefore fails closed in
    v1 instead of silently replacing or auto-revalidating an old receipt.
    """

    failures: list[str] = []
    trusted: dict[str, dict[str, Any]] = {}
    predecessor_trusted: dict[str, dict[str, Any]] = {}
    # A sidecar's semantic binding Head necessarily predates the commit that
    # appends the sidecar bytes.  Public callers normally evaluate both the
    # artifact and its semantics at the same descendant Head.  Predecessor
    # recursion keeps artifact byte lookup at the outer descendant and
    # revalidates its touch/projection semantics at the current evaluated Head.
    artifact_head = _artifact_head if _artifact_head is not None else evaluated_head
    if not is_commit(artifact_head):
        failures.append("POST_TOUCH_ARTIFACT_HEAD_INVALID")
    if is_commit(evaluated_head) and is_commit(artifact_head) and not _is_ancestor(
        root, evaluated_head, artifact_head
    ):
        failures.append("POST_TOUCH_ARTIFACT_HEAD_ORDER_INVALID")
    if _chain_depth > 8:
        return {
            "status": "FAIL",
            "failures": ["POST_TOUCH_REVALIDATION_CHAIN_DEPTH_EXCEEDED"],
            "manifest": {},
            "trusted_by_fingerprint": {},
            "record_count": 0,
            "fingerprints": [],
        }
    if AUTHORIZED_SCHEMA_SHA256 != "TO_BE_FILLED":
        failures.extend(validate_schema_file(root))
    else:
        failures.append("POST_TOUCH_SCHEMA_HASH_NOT_AUTHORIZED")
    if is_commit(artifact_head):
        committed_schema = _git_bytes(root, artifact_head, SCHEMA_REL.as_posix())
        try:
            local_schema = (root / SCHEMA_REL).read_bytes()
        except OSError:
            local_schema = None
        if committed_schema is None:
            failures.append("POST_TOUCH_SCHEMA_COMMITTED_BYTES_MISSING")
        elif local_schema != committed_schema:
            failures.append("POST_TOUCH_SCHEMA_COMMITTED_BYTES_MISMATCH")
    try:
        manifest = load_json_strict(manifest_path)
    except (OSError, ValueError, json.JSONDecodeError):
        manifest = {}
        failures.append("POST_TOUCH_MANIFEST_UNREADABLE")
    failures.extend(validate_manifest_document(manifest))
    if not isinstance(manifest, dict):
        manifest = {}
    # Manifest path is itself authority-bound; a copied file outside the
    # designated sidecar root is never accepted.
    try:
        relative_manifest = manifest_path.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        relative_manifest = ""
    if not relative_manifest.startswith(normalize_path(str(MANIFEST_ROOT)) + "/") or \
        PurePosixPath(relative_manifest).parent != PurePosixPath(str(MANIFEST_ROOT).replace("\\", "/")):
        failures.append("POST_TOUCH_MANIFEST_PATH_NOT_EXACT")
    elif is_commit(artifact_head):
        safe_manifest = _safe_repo_path(root, relative_manifest)
        if safe_manifest is None or safe_manifest != manifest_path.resolve():
            failures.append("POST_TOUCH_MANIFEST_PATH_UNSAFE")
        committed_manifest_bytes = _git_bytes(root, artifact_head, relative_manifest)
        try:
            local_manifest_bytes = manifest_path.read_bytes()
        except OSError:
            local_manifest_bytes = None
        if committed_manifest_bytes is None:
            failures.append("POST_TOUCH_MANIFEST_COMMITTED_BYTES_MISSING")
        elif local_manifest_bytes != committed_manifest_bytes:
            failures.append("POST_TOUCH_MANIFEST_COMMITTED_BYTES_MISMATCH")
    binding_head = str(manifest.get("revalidation_binding_head_sha", ""))
    if is_commit(binding_head) and is_commit(evaluated_head):
        if not _is_ancestor(root, AUTHORIZATION_BASE_HEAD, binding_head):
            failures.append("POST_TOUCH_REVALIDATION_HEAD_NOT_AUTHORIZED_DESCENDANT")
        if not _is_ancestor(root, binding_head, evaluated_head):
            failures.append("POST_TOUCH_REVALIDATION_HEAD_NOT_EVALUATED_ANCESTOR")
        try:
            tree = _git(root, "rev-parse", f"{binding_head}^{{tree}}")
            if manifest.get("revalidation_binding_tree_sha") != tree:
                failures.append("POST_TOUCH_REVALIDATION_TREE_MISMATCH")
        except ValueError:
            failures.append("POST_TOUCH_REVALIDATION_HEAD_UNRESOLVED")
    else:
        failures.append("POST_TOUCH_REVALIDATION_HEAD_INVALID")

    current_path_value = normalize_path(str(manifest.get("current_batch_manifest_path", "")))
    current_path = current_batch_manifest_path
    if current_batch_manifest_path is None:
        failures.append("POST_TOUCH_CURRENT_BATCH_MANIFEST_ARGUMENT_REQUIRED")
    if current_batch_manifest_path is not None:
        try:
            supplied = current_batch_manifest_path.resolve().relative_to(root.resolve()).as_posix()
        except ValueError:
            supplied = ""
        if supplied != current_path_value:
            failures.append("POST_TOUCH_CURRENT_BATCH_PATH_ARGUMENT_MISMATCH")
        if not supplied or not supplied.startswith(normalize_path(str(FULL_BATCH_ROOT)) + "/"):
            failures.append("POST_TOUCH_CURRENT_BATCH_PATH_SCOPE_INVALID")
        try:
            current_batch_manifest_path.resolve().relative_to(root.resolve())
        except ValueError:
            failures.append("POST_TOUCH_CURRENT_BATCH_PATH_OUTSIDE_ROOT")
        safe_current = _safe_repo_path(root, supplied)
        if safe_current is None:
            failures.append("POST_TOUCH_CURRENT_BATCH_PATH_UNSAFE")
            current_path = None
        else:
            current_path = safe_current
    current_fingerprints: set[str] = set()
    current_batch: dict[str, Any] = {}
    if current_path is None or not current_path.is_file():
        failures.append("POST_TOUCH_CURRENT_BATCH_MANIFEST_MISSING")
    else:
        try:
            if _safe_repo_path(root, current_path_value) is None:
                failures.append("POST_TOUCH_CURRENT_BATCH_PATH_UNSAFE")
            if sha256_file(current_path) != manifest.get("current_batch_manifest_sha256"):
                failures.append("POST_TOUCH_CURRENT_BATCH_MANIFEST_SHA_MISMATCH")
            current_batch = load_json_strict(current_path)
            if not isinstance(current_batch, dict):
                failures.append("POST_TOUCH_CURRENT_BATCH_NOT_OBJECT")
                current_batch = {}
            values = current_batch.get("failure_fingerprints", [])
            current_rendered = [str(value) for value in values] if isinstance(values, list) else []
            if (
                not current_rendered
                or current_rendered != sorted(current_rendered)
                or len(current_rendered) != len(set(current_rendered))
                or any(re.fullmatch(r"V2F-[0-9a-f]{64}", value) is None for value in current_rendered)
            ):
                failures.append("POST_TOUCH_CURRENT_BATCH_FINGERPRINTS_INVALID")
            current_fingerprints = set(current_rendered)
            if line_set_sha(current_rendered) != manifest.get("current_batch_fingerprint_set_sha256"):
                failures.append("POST_TOUCH_CURRENT_BATCH_FINGERPRINT_SET_MISMATCH")
            if isinstance(current_batch, dict):
                current_batch_head = str(current_batch.get("binding_head_sha", ""))
                try:
                    batch_tree = _git(root, "rev-parse", f"{current_batch_head}^{{tree}}")
                except ValueError:
                    batch_tree = ""
                if not is_tree_oid(batch_tree) or batch_tree != current_batch.get("binding_tree_sha"):
                    failures.append("POST_TOUCH_CURRENT_BATCH_TREE_UNRESOLVED")
                if not _is_ancestor(root, current_batch_head, binding_head):
                    failures.append("POST_TOUCH_CURRENT_BATCH_HEAD_ORDER_INVALID")
                if not _is_ancestor(root, binding_head, evaluated_head):
                    failures.append("POST_TOUCH_REVALIDATION_HEAD_NOT_CURRENT_BATCH_ANCESTOR")
                # Batch evidence is intentionally appended after its own
                # product binding Head.  Require its exact bytes at the
                # evaluated Head, never the impossible self-referential
                # condition that it already existed at its binding Head.
                batch_bytes = _git_bytes(root, artifact_head, current_path_value)
                if batch_bytes is None:
                    failures.append("POST_TOUCH_CURRENT_BATCH_EVALUATED_BYTES_MISSING")
                elif sha256_bytes(batch_bytes) != manifest.get("current_batch_manifest_sha256"):
                    failures.append("POST_TOUCH_CURRENT_BATCH_EVALUATED_BYTES_MISMATCH")
        except (OSError, ValueError, json.JSONDecodeError):
            failures.append("POST_TOUCH_CURRENT_BATCH_MANIFEST_UNREADABLE")

    authorized_batch_chain: dict[str, str] = {}
    if current_path is not None and current_path.is_file() and isinstance(current_batch, dict):
        authorized_batch_chain, batch_chain_failures = _explicit_batch_chain(
            root,
            current_path,
            current_batch,
            artifact_head=artifact_head,
        )
        failures.extend(batch_chain_failures)

    previous_manifest_path_value = normalize_path(str(manifest.get("previous_revalidation_manifest_path", "")))
    if previous_manifest_path_value:
        previous_manifest_path = _safe_repo_path(root, previous_manifest_path_value)
        if previous_manifest_path is None or not previous_manifest_path_value.startswith(normalize_path(str(MANIFEST_ROOT)) + "/"):
            failures.append("POST_TOUCH_PREVIOUS_MANIFEST_PATH_INVALID")
            previous_manifest_path = None
        if previous_manifest_path is not None and previous_manifest_path == manifest_path.resolve():
            failures.append("POST_TOUCH_PREVIOUS_MANIFEST_SELF_REFERENCE")
        try:
            if previous_manifest_path is None:
                raise OSError("unsafe previous manifest path")
            previous_manifest = load_json_strict(previous_manifest_path)
            if sha256_file(previous_manifest_path) != manifest.get("previous_revalidation_manifest_sha256"):
                failures.append("POST_TOUCH_PREVIOUS_MANIFEST_SHA_MISMATCH")
            if not isinstance(previous_manifest, dict):
                failures.append("POST_TOUCH_PREVIOUS_MANIFEST_NOT_OBJECT")
            else:
                if previous_manifest.get("record_chain_terminal_sha256") != manifest.get("record_chain_start_sha256"):
                    failures.append("POST_TOUCH_PREVIOUS_MANIFEST_CHAIN_ANCHOR_MISMATCH")
                previous_head = str(previous_manifest.get("revalidation_binding_head_sha", ""))
                if not _is_ancestor(root, previous_head, binding_head):
                    failures.append("POST_TOUCH_PREVIOUS_MANIFEST_HEAD_ORDER_INVALID")
                previous_result = validate_manifest_and_records(
                    root,
                    previous_manifest_path,
                    evaluated_head=evaluated_head,
                    current_batch_manifest_path=(
                        _safe_repo_path(
                            root,
                            normalize_path(str(previous_manifest.get("current_batch_manifest_path", ""))),
                        )
                        if isinstance(previous_manifest, dict)
                        else None
                    ),
                    projection_loader=projection_loader,
                    _chain_depth=_chain_depth + 1,
                    _artifact_head=artifact_head,
                )
                failures.extend(
                    f"POST_TOUCH_PREVIOUS_MANIFEST_INVALID:{value}"
                    for value in previous_result.get("failures", [])
                )
                manifest_fingerprint_values = manifest.get("failure_fingerprints")
                current_manifest_fingerprints = (
                    [str(value) for value in manifest_fingerprint_values]
                    if isinstance(manifest_fingerprint_values, list)
                    else []
                )
                predecessor_trusted, predecessor_merge_failures = (
                    _merge_disjoint_predecessor_trust(
                        previous_result,
                        current_manifest_fingerprints,
                    )
                )
                failures.extend(predecessor_merge_failures)
                trusted.update(predecessor_trusted)
        except (OSError, ValueError, json.JSONDecodeError):
            failures.append("POST_TOUCH_PREVIOUS_MANIFEST_UNREADABLE")

    bindings = manifest.get("record_bindings", []) if isinstance(manifest, dict) else []
    if not isinstance(bindings, list):
        bindings = []
    seen_ids: set[str] = set()
    seen_fingerprints: set[str] = set()
    previous_chain = manifest.get("record_chain_start_sha256", "")
    for index, manifest_binding in enumerate(bindings):
        if not isinstance(manifest_binding, dict) or set(manifest_binding) != set(MANIFEST_RECORD_BINDING_FIELDS):
            continue
        relative = normalize_path(str(manifest_binding.get("path", "")))
        record_path = _safe_repo_path(root, relative)
        if record_path is None:
            failures.append(f"POST_TOUCH_RECORD_PATH_UNSAFE:{index}")
            continue
        committed_record_bytes = _git_bytes(root, artifact_head, relative)
        try:
            local_record_bytes = record_path.read_bytes()
        except OSError:
            local_record_bytes = None
        if committed_record_bytes is None:
            failures.append(f"POST_TOUCH_RECORD_COMMITTED_BYTES_MISSING:{index}")
        elif local_record_bytes != committed_record_bytes:
            failures.append(f"POST_TOUCH_RECORD_COMMITTED_BYTES_MISMATCH:{index}")
        try:
            record = load_json_strict(record_path)
        except (OSError, ValueError, json.JSONDecodeError):
            failures.append(f"POST_TOUCH_RECORD_UNREADABLE:{index}")
            continue
        record_failures = validate_record_document(record)
        failures.extend(f"POST_TOUCH_RECORD_DOCUMENT:{index}:{value}" for value in record_failures)
        if not isinstance(record, dict):
            continue
        if sha256_file(record_path) != manifest_binding.get("record_sha256"):
            failures.append(f"POST_TOUCH_RECORD_BYTE_MISMATCH:{index}")
        if record.get("record_payload_sha256") != manifest_binding.get("record_payload_sha256"):
            failures.append(f"POST_TOUCH_RECORD_PAYLOAD_BINDING_MISMATCH:{index}")
        if record.get("previous_revalidation_chain_sha256") != previous_chain:
            failures.append(f"POST_TOUCH_RECORD_CHAIN_BREAK:{index}")
        if record.get("revalidation_binding_head_sha") != binding_head:
            failures.append(f"POST_TOUCH_RECORD_REVALIDATION_HEAD_MISMATCH:{index}")
        if record.get("revalidation_binding_tree_sha") != manifest.get("revalidation_binding_tree_sha"):
            failures.append(f"POST_TOUCH_RECORD_REVALIDATION_TREE_MISMATCH:{index}")
        previous_chain = record.get("record_payload_sha256", "")
        rid = str(record.get("revalidation_id", ""))
        if rid in seen_ids:
            failures.append(f"POST_TOUCH_REVALIDATION_ID_DUPLICATE:{rid}")
        seen_ids.add(rid)
        record_fingerprint_values = record.get("failure_fingerprints")
        fingerprints = (
            [str(value) for value in record_fingerprint_values]
            if isinstance(record_fingerprint_values, list)
            else []
        )
        if len(fingerprints) != 1:
            continue
        fp = fingerprints[0]
        if fp in seen_fingerprints:
            failures.append(f"POST_TOUCH_FINGERPRINT_DUPLICATE:{fp}")
        seen_fingerprints.add(fp)
        if fp in current_fingerprints:
            failures.append(f"POST_TOUCH_CORRECTION_BATCH_FINGERPRINT_REUSE:{fp}")
        # Manifest binding must duplicate the record's exact predecessor
        # authority; this prevents path/id substitution after the sidecar was
        # sealed.
        for key in (
            "revalidation_id",
            "prior_record_path",
            "prior_record_sha256",
            "prior_record_payload_sha256",
            "prior_correction_id",
        ):
            if record.get(key) != manifest_binding.get(key):
                failures.append(f"POST_TOUCH_RECORD_MANIFEST_BINDING_MISMATCH:{index}:{key}")
        manifest_binding_fingerprint_values = manifest_binding.get("failure_fingerprints")
        manifest_binding_fingerprints = (
            [str(value) for value in manifest_binding_fingerprint_values]
            if isinstance(manifest_binding_fingerprint_values, list)
            else []
        )
        if [fp] != manifest_binding_fingerprints:
            failures.append(f"POST_TOUCH_RECORD_MANIFEST_FINGERPRINT_MISMATCH:{index}")
        prior_path_value = normalize_path(str(record.get("prior_record_path", "")))
        prior_path = _safe_repo_path(root, prior_path_value)
        if prior_path is None:
            failures.append(f"POST_TOUCH_PRIOR_RECORD_PATH_UNSAFE:{fp}")
            continue
        try:
            prior = load_json_strict(prior_path)
        except (OSError, ValueError, json.JSONDecodeError):
            failures.append(f"POST_TOUCH_PRIOR_RECORD_UNREADABLE:{fp}")
            continue
        if not isinstance(prior, dict):
            failures.append(f"POST_TOUCH_PRIOR_RECORD_NOT_OBJECT:{fp}")
            continue
        try:
            prior_local_bytes = prior_path.read_bytes()
        except OSError:
            prior_local_bytes = None
        prior_committed_bytes = _git_bytes(root, artifact_head, prior_path_value)
        if prior_committed_bytes is None:
            failures.append(f"POST_TOUCH_PRIOR_RECORD_COMMITTED_BYTES_MISSING:{fp}")
        elif prior_local_bytes != prior_committed_bytes:
            failures.append(f"POST_TOUCH_PRIOR_RECORD_COMMITTED_BYTES_MISMATCH:{fp}")
        if sha256_file(prior_path) != record.get("prior_record_sha256"):
            failures.append(f"POST_TOUCH_PRIOR_RECORD_SHA_MISMATCH:{fp}")
        if prior.get("record_payload_sha256") != record.get("prior_record_payload_sha256"):
            failures.append(f"POST_TOUCH_PRIOR_RECORD_PAYLOAD_MISMATCH:{fp}")
        prior_fingerprint_values = prior.get("failure_fingerprints")
        prior_fps = (
            [str(value) for value in prior_fingerprint_values]
            if isinstance(prior_fingerprint_values, list)
            else []
        )
        if fp not in prior_fps:
            failures.append(f"POST_TOUCH_PRIOR_FINGERPRINT_NOT_IN_RECORD:{fp}")
        if prior.get("correction_id") != record.get("prior_correction_id"):
            failures.append(f"POST_TOUCH_PRIOR_CORRECTION_ID_MISMATCH:{fp}")
        if prior.get("binding_head_sha") != record.get("prior_binding_head_sha"):
            failures.append(f"POST_TOUCH_PRIOR_BINDING_HEAD_MISMATCH:{fp}")
        try:
            prior_tree = _git(root, "rev-parse", f"{record.get('prior_binding_head_sha')}^{{tree}}")
            if prior_tree != record.get("prior_binding_tree_sha"):
                failures.append(f"POST_TOUCH_PRIOR_BINDING_TREE_MISMATCH:{fp}")
        except ValueError:
            failures.append(f"POST_TOUCH_PRIOR_BINDING_HEAD_UNRESOLVED:{fp}")
        touch = record.get("touch_proof") if isinstance(record.get("touch_proof"), dict) else {}
        touch_commit = str(touch.get("commit_sha", ""))
        touch_parent = str(touch.get("parent_sha", ""))
        touch_path = normalize_path(str(touch.get("path", "")))
        prior_identity_map = prior.get("identity_binding_by_failure")
        prior_identity = prior_identity_map.get(fp, {}) if isinstance(prior_identity_map, dict) else {}
        if not isinstance(prior_identity, dict):
            prior_identity = {}
            failures.append(f"POST_TOUCH_PRIOR_IDENTITY_INVALID:{fp}")
        bound_paths = {
            normalize_path(str(prior_identity.get(key, "")))
            for key in ("historical_path", "current_path")
            if isinstance(prior_identity.get(key), str) and prior_identity.get(key)
        }
        old_path = normalize_path(str(prior_identity.get("current_path", "")))
        historical_path = normalize_path(str(prior_identity.get("historical_path", "")))
        if touch_path not in bound_paths:
            failures.append(f"POST_TOUCH_PROOF_PATH_NOT_BOUND:{fp}")
        changed_before = _changed_paths(root, str(record.get("prior_binding_head_sha", "")), binding_head)
        if touch_path and touch_path not in changed_before:
            failures.append(f"POST_TOUCH_PROOF_PATH_NOT_TOUCHED:{fp}")
        commits = _touch_commits(root, str(record.get("prior_binding_head_sha", "")), binding_head, touch_path)
        if commits != [touch_commit]:
            failures.append(f"POST_TOUCH_PROOF_COMMIT_SEQUENCE_MISMATCH:{fp}")
        bound_touch_commits: set[str] = set()
        for bound_path in bound_paths:
            bound_touch_commits.update(
                _touch_commits(
                    root,
                    str(record.get("prior_binding_head_sha", "")),
                    binding_head,
                    bound_path,
                )
            )
        if not (bound_paths & changed_before):
            failures.append(f"POST_TOUCH_PROOF_NO_BOUND_PATH_TOUCHED:{fp}")
        if bound_touch_commits != {touch_commit}:
            failures.append(f"POST_TOUCH_PROOF_BOUND_PATH_COMMIT_SET_MISMATCH:{fp}")
        try:
            actual_parent = _git(root, "rev-parse", f"{touch_commit}^1")
        except ValueError:
            actual_parent = ""
        if actual_parent != touch_parent:
            failures.append(f"POST_TOUCH_PROOF_PARENT_MISMATCH:{fp}")
        if not _is_ancestor(root, str(record.get("prior_binding_head_sha", "")), touch_parent):
            failures.append(f"POST_TOUCH_PROOF_PRIOR_HEAD_NOT_ANCESTOR:{fp}")
        if not _is_ancestor(root, touch_commit, binding_head):
            failures.append(f"POST_TOUCH_PROOF_TOUCH_NOT_REVALIDATION_ANCESTOR:{fp}")
        before = _git_bytes(root, touch_parent, touch_path) if touch_parent and touch_path else None
        after = _git_bytes(root, touch_commit, touch_path) if touch_commit and touch_path else None
        before_sha = sha256_bytes(before) if before is not None else "MISSING"
        after_sha = sha256_bytes(after) if after is not None else "MISSING"
        if touch.get("before_blob_sha256") != before_sha or touch.get("after_blob_sha256") != after_sha:
            failures.append(f"POST_TOUCH_PROOF_BLOB_MISMATCH:{fp}")
        prior_binding_bytes = _git_bytes(
            root,
            str(record.get("prior_binding_head_sha", "")),
            touch_path,
        ) if touch_path else None
        prior_binding_sha = (
            sha256_bytes(prior_binding_bytes)
            if prior_binding_bytes is not None
            else "MISSING"
        )
        if touch.get("before_blob_sha256") != prior_binding_sha:
            failures.append(f"POST_TOUCH_PROOF_BEFORE_PRIOR_BINDING_BLOB_MISMATCH:{fp}")
        if touch.get("diff_sha256") != _git_diff_sha(root, touch_parent, touch_commit, touch_path):
            failures.append(f"POST_TOUCH_PROOF_DIFF_MISMATCH:{fp}")
        rebound_blobs = record.get("rebound_current_blob_sha256_by_path", {})
        rebound_projections = record.get("rebound_subject_projection_by_failure", {})
        rebound_projection_hashes = record.get("rebound_subject_projection_sha256_by_failure", {})
        if not isinstance(rebound_blobs, dict):
            failures.append(f"POST_TOUCH_REBOUND_BLOB_MAP_NOT_OBJECT:{fp}")
            rebound_blobs = {}
        if not isinstance(rebound_projections, dict):
            failures.append(f"POST_TOUCH_REBOUND_PROJECTION_MAP_NOT_OBJECT:{fp}")
            rebound_projections = {}
        if not isinstance(rebound_projection_hashes, dict):
            failures.append(f"POST_TOUCH_REBOUND_PROJECTION_HASH_MAP_NOT_OBJECT:{fp}")
            rebound_projection_hashes = {}
        # Rebind each exact subject from the old record.  No authority field is
        # accepted solely because it was copied into the new receipt.
        if old_path and rebound_blobs.get(old_path) != (
            sha256_bytes(_git_bytes(root, binding_head, old_path))
            if _git_bytes(root, binding_head, old_path) is not None
            else "MISSING"
        ):
            failures.append(f"POST_TOUCH_REBOUND_BLOB_MISMATCH:{fp}")
        if old_path and rebound_blobs.get(old_path) != (
            sha256_bytes(_git_bytes(root, evaluated_head, old_path))
            if _git_bytes(root, evaluated_head, old_path) is not None
            else "MISSING"
        ):
            failures.append(f"POST_TOUCH_REBOUND_EVALUATED_BLOB_CHANGED:{fp}")
        if touch_path == old_path and old_path and touch.get("after_blob_sha256") != rebound_blobs.get(old_path):
            failures.append(f"POST_TOUCH_PROOF_AFTER_REBOUND_BLOB_MISMATCH:{fp}")
        expected_blob_paths = {old_path} if old_path else set()
        if set(rebound_blobs) != expected_blob_paths:
            failures.append(f"POST_TOUCH_REBOUND_BLOB_PATH_SET_MISMATCH:{fp}")
        # A receipt is valid only until the evaluated Head: touching a bound
        # path later (even if reverted) must invalidate it just like the
        # primary validator.
        later_touch_commits: set[str] = set()
        for bound_path in bound_paths:
            later_touch_commits.update(
                _touch_commits(root, binding_head, evaluated_head, bound_path)
            )
        if later_touch_commits:
            failures.append(f"POST_TOUCH_LATER_BOUND_PATH_TOUCHED:{fp}")
        selector = prior_identity.get("authority_selectors") if isinstance(prior_identity, dict) else None
        try:
            rebound_projection = projection_loader(root, binding_head, selector) if isinstance(selector, dict) else None
            evaluated_projection = projection_loader(root, evaluated_head, selector) if isinstance(selector, dict) else None
        except Exception:
            rebound_projection = None
            evaluated_projection = None
            failures.append(f"POST_TOUCH_REBOUND_PROJECTION_UNRESOLVED:{fp}")
        if rebound_projection is None or rebound_projection != rebound_projections.get(fp):
            failures.append(f"POST_TOUCH_REBOUND_PROJECTION_MISMATCH:{fp}")
        if evaluated_projection is None or evaluated_projection != rebound_projection:
            failures.append(f"POST_TOUCH_REBOUND_EVALUATED_PROJECTION_CHANGED:{fp}")
        if rebound_projection_hashes.get(fp) != (
            sha256_bytes(canonical_bytes(rebound_projection)) if isinstance(rebound_projection, dict) else ""
        ):
            failures.append(f"POST_TOUCH_REBOUND_PROJECTION_DIGEST_MISMATCH:{fp}")
        # Recompute exactly which old-record invalidations occurred at the new
        # binding Head.  Only that declared set may be bypassed by the caller.
        observed: set[str] = set()
        old_blob = prior_identity.get("current_blob_sha256")
        if old_path and rebound_blobs.get(old_path) != old_blob:
            observed.add("BLOB_CHANGED_CORRECTION_INVALID")
        if bound_paths & changed_before:
            observed.add("TOUCHED_CORRECTION_INVALID")
        old_projection = prior_identity.get("subject_projection")
        if isinstance(old_projection, dict) and rebound_projection != old_projection:
            observed.add("SUBJECT_PROJECTION_CHANGED_INVALID")
        prior_invalidation_values = record.get("prior_invalidations")
        declared = set(
            str(value) for value in prior_invalidation_values
        ) if isinstance(prior_invalidation_values, list) else set()
        if observed != declared:
            failures.append(f"POST_TOUCH_INVALIDATION_SET_MISMATCH:{fp}")
        prior_batch_path_value = normalize_path(str(record.get("correction_batch_manifest_path", "")))
        if not prior_batch_path_value.startswith(normalize_path(str(FULL_BATCH_ROOT)) + "/"):
            failures.append(f"POST_TOUCH_PRIOR_BATCH_PATH_SCOPE_INVALID:{fp}")
        prior_batch_path = _safe_repo_path(root, prior_batch_path_value)
        if prior_batch_path is None or not prior_batch_path.is_file():
            failures.append(f"POST_TOUCH_PRIOR_BATCH_MANIFEST_MISSING:{fp}")
        else:
            try:
                prior_batch_local_bytes = prior_batch_path.read_bytes()
                actual_batch_sha = sha256_file(prior_batch_path)
            except OSError:
                prior_batch_local_bytes = None
                actual_batch_sha = ""
            prior_batch_committed_bytes = _git_bytes(
                root,
                artifact_head,
                prior_batch_path_value,
            )
            if prior_batch_committed_bytes is None:
                failures.append(f"POST_TOUCH_PRIOR_BATCH_COMMITTED_BYTES_MISSING:{fp}")
            elif prior_batch_committed_bytes != prior_batch_local_bytes:
                failures.append(f"POST_TOUCH_PRIOR_BATCH_COMMITTED_BYTES_MISMATCH:{fp}")
            if actual_batch_sha != record.get("correction_batch_manifest_sha256"):
                failures.append(f"POST_TOUCH_PRIOR_BATCH_MANIFEST_SHA_MISMATCH:{fp}")
            if authorized_batch_chain.get(prior_batch_path_value) != actual_batch_sha:
                failures.append(f"POST_TOUCH_PRIOR_BATCH_NOT_IN_EXPLICIT_CHAIN:{fp}")
            ok, reason = _prior_record_membership(
                root,
                prior_batch_path,
                prior_path_value,
                str(record.get("prior_correction_id", "")),
                fp,
                str(record.get("prior_record_sha256", "")),
                str(record.get("prior_record_payload_sha256", "")),
            )
            if not ok:
                failures.append(f"{reason}:{fp}")
        # Any failure tied to this fingerprint, including a generic record
        # contract failure, prevents it from becoming trusted.
        if not any(value.endswith(f":{fp}") for value in failures):
            trusted[fp] = {
                "allowed_invalidations": sorted(declared),
                "prior_record_path": prior_path_value,
                "revalidation_id": rid,
                "record_path": relative,
                "revalidation_binding_head_sha": binding_head,
            }
    if previous_chain != manifest.get("record_chain_terminal_sha256"):
        failures.append("POST_TOUCH_MANIFEST_ACTUAL_CHAIN_TERMINAL_MISMATCH")
    # A single malformed record invalidates the whole sidecar authority.  This
    # prevents a caller from using a valid-looking subset to hide another bad
    # receipt.
    if failures:
        trusted = {}
    return {
        "status": "PASS" if not failures else "FAIL",
        "failures": sorted(set(failures)),
        "manifest": manifest,
        "trusted_by_fingerprint": trusted,
        "record_count": len(bindings),
        "fingerprints": sorted(seen_fingerprints | set(predecessor_trusted)),
    }


def _is_ancestor(root: Path, ancestor: str, descendant: str) -> bool:
    if not is_commit(ancestor) or not is_commit(descendant):
        return False
    result = subprocess.run(
        ["git", "-C", str(root), "merge-base", "--is-ancestor", ancestor, descendant],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return result.returncode == 0
