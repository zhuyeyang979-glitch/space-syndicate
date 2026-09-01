#!/usr/bin/env python3
"""Exact append-only replacement for the two-record SPR successor-v2 epoch.

The v2 artifacts remain immutable lineage evidence.  This successor binds the
same two explicit fingerprints to the current evaluated authority projection.
Committed validation reads v5 evidence from an artifact commit while reading
all predecessor and authority inputs from the separately supplied binding
commit.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path
from typing import Any

try:
    from . import v076_subject_projection_revalidation_successor_v2 as v2
except ImportError:  # pragma: no cover - direct script execution
    import v076_subject_projection_revalidation_successor_v2 as v2


AUTHORIZATION_ID = v2.AUTHORIZATION_ID
AUTHORIZATION_BASE_HEAD = v2.AUTHORIZATION_BASE_HEAD
PRIOR_EPOCH_ID = v2.PRIOR_EPOCH_ID
SCHEMA_VERSION = "space_syndicate.v076.reuse_exact_failure_correction.v2.subject_projection_revalidation_successor_v5_schema.v1"
MANIFEST_SCHEMA_VERSION = "space_syndicate.v076.reuse_exact_failure_correction.v2.subject_projection_revalidation_successor_v5_manifest.v1"
RECORD_SCHEMA_VERSION = "space_syndicate.v076.reuse_exact_failure_correction.v2.subject_projection_revalidation_successor_v5_record.v1"
MANIFEST_KIND = "SUBJECT_PROJECTION_REVALIDATION_SUCCESSOR_V5_MANIFEST"
RECORD_KIND = "SUBJECT_PROJECTION_REVALIDATION_SUCCESSOR_V5_RECORD"
MANIFEST_ID = "V076-SUBJECT-PROJECTION-REVALIDATION-SUCCESSOR-V5-20260830"
SCHEMA_PATH = "docs/architecture/reuse_corrections/v2/schema_subject_projection_revalidation_successor_v5_20260830.json"
SUCCESSOR_ROOT = "docs/architecture/reuse_corrections/v2/subject_projection_revalidation_successor_v5/"
RECORD_ROOT = SUCCESSOR_ROOT + "records/"
PREDECESSOR_MANIFEST_PATH = "docs/architecture/reuse_corrections/v2/subject_projection_revalidation_successor_v2/manifest.json"
PREDECESSOR_MANIFEST_SHA256 = "3c5a6171a4faa6f297569470b4a5bccd52a7e07cdd72241579ef01123cc89db4"
PREDECESSOR_BINDING_HEAD = "f7404bb7b3670d72214541acc6f277ad363b4279"
PREDECESSOR_RECORD_COUNT = 2
PREDECESSOR_CHAIN_TERMINAL_SHA256 = "ab5ec81bf2ca6c4a4a061fa31e104f682d678e15499e88359e40b9dddacca80e"
PREDECESSOR_FINGERPRINT_SET_SHA256 = "3a734ff7c57373b215dd7cb4dd6eb16206def7f4c7e5fc1f26a4a6b09b0a51d3"
TRANSITION_PARENT = "9926d3955da7c14a292259e270f2ac2ff7559dcd"
TRANSITION_COMMIT = "6209465da4a9ca0c1cb6f0db0cd8a088bd63e793"
REGISTRY_PATH = v2.REGISTRY_PATH
SUPERSESSION_PATH = v2.SUPERSESSION_PATH
OWNER_MAP_PATH = v2.OWNER_MAP_PATH
DYNAMIC_REFERENCE_PATH = v2.DYNAMIC_REFERENCE_PATH
AUTHORITY_PATHS = (REGISTRY_PATH, SUPERSESSION_PATH)
ALLOWED_INVALIDATION = "SUBJECT_PROJECTION_CHANGED_INVALID"
FUTURE_POLICY = {
    "FUTURE_FAILURE_AUTO_REVALIDATION_COUNT": 0,
    "NEW_FAILURE_REQUIRES_NEW_RECORD": True,
}
PROJECTION_FIELDS = (
    "dynamic_reference_rows",
    "owner_map_lines",
    "registry_rows",
    "supersession_rows",
)
EXPECTED_CHANGED_COMPONENT_IDS = ["component.current.v075_runtime_owner"]

MANIFEST_FIELDS = frozenset(
    """schema_version manifest_kind manifest_id artifact_root_kind authorization_id authorization_base_head_sha prior_epoch_id schema_path schema_sha256 predecessor_manifest_path predecessor_manifest_sha256 predecessor_record_count predecessor_record_chain_terminal_sha256 predecessor_failure_fingerprint_set_sha256 authority_transition_parent_sha authority_transition_commit_sha authority_source_paths authority_source_before_blob_sha256_by_path authority_source_after_blob_sha256_by_path authority_source_diff_sha256_by_path revalidation_binding_head_sha revalidation_binding_tree_sha record_count failure_fingerprints failure_fingerprint_set_sha256 record_chain_start_sha256 record_chain_terminal_sha256 allowed_invalidation future_failure_auto_revalidation wildcard_count created_at creator record_bindings""".split()
)
RECORD_FIELDS = frozenset(
    """schema_version record_kind revalidation_id authorization_id authorization_base_head_sha prior_epoch_id failure_fingerprints failure_fingerprint_set_sha256 prior_invalidations prior_record_path prior_record_sha256 prior_record_payload_sha256 prior_correction_id prior_batch_manifest_path prior_batch_manifest_sha256 predecessor_revalidation_record_path predecessor_revalidation_record_sha256 predecessor_revalidation_record_payload_sha256 predecessor_revalidation_id previous_revalidation_chain_sha256 revalidation_binding_head_sha revalidation_binding_tree_sha authority_selectors component_id prior_identity_binding prior_subject_projection prior_subject_projection_sha256 pre_change_subject_projection pre_change_subject_projection_sha256 rebound_subject_projection rebound_subject_projection_sha256 live_subject_projection live_subject_projection_sha256 changed_projection_sections changed_projection_component_ids authority_transition_proof bound_product_blob_sha256_by_path future_failure_policy wildcard_count new_effective_status revalidation_reason created_at creator record_payload_sha256""".split()
)
BINDING_FIELDS = frozenset(
    """path record_sha256 record_payload_sha256 revalidation_id failure_fingerprints prior_record_path prior_record_sha256 prior_record_payload_sha256 prior_correction_id predecessor_revalidation_record_path predecessor_revalidation_record_sha256 predecessor_revalidation_record_payload_sha256 predecessor_revalidation_id previous_revalidation_chain_sha256""".split()
)


def canonical_bytes(value: Any) -> bytes:
    return (
        json.dumps(
            value,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
            allow_nan=False,
        )
        + "\n"
    ).encode()


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def line_set_sha(values: list[str]) -> str:
    return sha256_bytes(("\n".join(sorted(values)) + "\n").encode())


def payload_sha(value: dict[str, Any]) -> str:
    body = dict(value)
    body.pop("record_payload_sha256", None)
    return sha256_bytes(canonical_bytes(body))


def _pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("DUPLICATE_JSON_KEY")
        result[key] = value
    return result


def strict(raw: bytes) -> Any:
    return json.loads(
        raw.decode("utf-8-sig"),
        object_pairs_hook=_pairs,
        parse_constant=lambda _: (_ for _ in ()).throw(ValueError("NONFINITE_JSON")),
    )


def _git(root: Path, *args: str, binary: bool = False) -> str | bytes:
    process = subprocess.run(
        ["git", "--no-replace-objects", "-C", str(root), *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if process.returncode:
        raise ValueError(process.stderr.decode("utf-8", "replace").strip())
    return process.stdout if binary else process.stdout.decode().strip()


def blob(root: Path, ref: str, path: str) -> bytes | None:
    process = subprocess.run(
        ["git", "--no-replace-objects", "-C", str(root), "cat-file", "blob", f"{ref}:{path}"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    return process.stdout if process.returncode == 0 else None


def document(root: Path, ref: str, path: str) -> tuple[dict[str, Any], bytes]:
    raw = blob(root, ref, path)
    if raw is None:
        raise ValueError("MISSING_BLOB:" + path)
    value = strict(raw)
    if not isinstance(value, dict):
        raise ValueError("DOCUMENT_NOT_OBJECT:" + path)
    return value, raw


def projection(root: Path, ref: str, selector: dict[str, Any]) -> dict[str, Any]:
    return v2.subject_projection(root, ref, selector)


def expected_record_path(fingerprint: str) -> str:
    return RECORD_ROOT + "spr5-" + fingerprint[4:] + ".json"


def expected_id(fingerprint: str) -> str:
    return "V076-SPR5-" + fingerprint[4:20].upper()


def transition_proof(root: Path) -> dict[str, Any]:
    if str(_git(root, "rev-parse", f"{TRANSITION_COMMIT}^1")) != TRANSITION_PARENT:
        raise ValueError("SPR5_TRANSITION_PARENT_INVALID")
    changed = str(
        _git(root, "diff", "--name-only", TRANSITION_PARENT, TRANSITION_COMMIT)
    ).splitlines()
    if changed != sorted(AUTHORITY_PATHS):
        raise ValueError("SPR5_TRANSITION_PATH_SET_INVALID")
    before: dict[str, str] = {}
    after: dict[str, str] = {}
    diffs: dict[str, str] = {}
    for path in AUTHORITY_PATHS:
        before_raw = blob(root, TRANSITION_PARENT, path)
        after_raw = blob(root, TRANSITION_COMMIT, path)
        if before_raw is None or after_raw is None:
            raise ValueError("SPR5_TRANSITION_BLOB_MISSING:" + path)
        before[path] = sha256_bytes(before_raw)
        after[path] = sha256_bytes(after_raw)
        diffs[path] = sha256_bytes(
            _git(
                root,
                "diff",
                "--binary",
                "--no-ext-diff",
                TRANSITION_PARENT,
                TRANSITION_COMMIT,
                "--",
                path,
                binary=True,
            )
        )
    return {
        "commit_sha": TRANSITION_COMMIT,
        "parent_sha": TRANSITION_PARENT,
        "before_sha256_by_path": before,
        "after_sha256_by_path": after,
        "diff_sha256_by_path": diffs,
    }


def _changed_components(before: dict[str, Any], after: dict[str, Any]) -> list[str]:
    old_rows = {row.get("component_id"): row for row in before["registry_rows"]}
    new_rows = {row.get("component_id"): row for row in after["registry_rows"]}
    return sorted(
        key for key in set(old_rows) | set(new_rows) if old_rows.get(key) != new_rows.get(key)
    )


def target_rows(
    root: Path, evaluated_head: str
) -> tuple[list[str], dict[str, dict[str, Any]], dict[str, Any]]:
    predecessor, predecessor_raw = document(root, evaluated_head, PREDECESSOR_MANIFEST_PATH)
    if sha256_bytes(predecessor_raw) != PREDECESSOR_MANIFEST_SHA256:
        raise ValueError("SPR5_PREDECESSOR_MANIFEST_SHA_INVALID")
    if (
        predecessor.get("manifest_kind") != v2.MANIFEST_KIND
        or predecessor.get("record_count") != PREDECESSOR_RECORD_COUNT
        or predecessor.get("record_chain_terminal_sha256") != PREDECESSOR_CHAIN_TERMINAL_SHA256
        or predecessor.get("failure_fingerprint_set_sha256")
        != PREDECESSOR_FINGERPRINT_SET_SHA256
        or predecessor.get("revalidation_binding_head_sha") != PREDECESSOR_BINDING_HEAD
        or predecessor.get("wildcard_count") != 0
        or predecessor.get("future_failure_auto_revalidation") is not False
    ):
        raise ValueError("SPR5_PREDECESSOR_IDENTITY_INVALID")
    fingerprints = list(predecessor.get("failure_fingerprints", []))
    if len(fingerprints) != 2 or fingerprints != sorted(fingerprints):
        raise ValueError("SPR5_PREDECESSOR_FINGERPRINTS_INVALID")
    rows: dict[str, dict[str, Any]] = {}
    for binding in predecessor.get("record_bindings", []):
        if not isinstance(binding, dict):
            raise ValueError("SPR5_PREDECESSOR_BINDING_INVALID")
        binding_fingerprints = binding.get("failure_fingerprints", [])
        if not isinstance(binding_fingerprints, list) or len(binding_fingerprints) != 1:
            raise ValueError("SPR5_PREDECESSOR_BINDING_NOT_EXACT")
        fingerprint = binding_fingerprints[0]
        if fingerprint not in fingerprints or fingerprint in rows:
            raise ValueError("SPR5_PREDECESSOR_BINDING_COLLISION")
        record, record_raw = document(root, evaluated_head, str(binding.get("path", "")))
        if (
            sha256_bytes(record_raw) != binding.get("record_sha256")
            or record.get("record_payload_sha256") != binding.get("record_payload_sha256")
            or payload_sha(record) != binding.get("record_payload_sha256")
            or record.get("record_kind") != v2.RECORD_KIND
            or record.get("failure_fingerprints") != [fingerprint]
        ):
            raise ValueError("SPR5_PREDECESSOR_RECORD_SEAL_INVALID:" + str(fingerprint))
        selector = record["authority_selectors"]
        prior = projection(root, PREDECESSOR_BINDING_HEAD, selector)
        before = projection(root, TRANSITION_PARENT, selector)
        rebound = projection(root, TRANSITION_COMMIT, selector)
        live = projection(root, evaluated_head, selector)
        changed = [field for field in PROJECTION_FIELDS if before[field] != rebound[field]]
        if (
            prior != record.get("live_subject_projection")
            or before != prior
            or rebound != live
            or before == rebound
            or changed != ["registry_rows"]
            or _changed_components(before, rebound) != EXPECTED_CHANGED_COMPONENT_IDS
        ):
            raise ValueError("SPR5_TARGET_PROJECTION_INVALID:" + str(fingerprint))
        row = dict(record)
        row["_v5_predecessor_path"] = binding.get("path")
        row["_v5_predecessor_sha256"] = binding.get("record_sha256")
        row["_v5_predecessor_payload_sha256"] = binding.get("record_payload_sha256")
        rows[str(fingerprint)] = row
    if set(rows) != set(fingerprints):
        raise ValueError("SPR5_PREDECESSOR_COVERAGE_INVALID")
    return fingerprints, rows, predecessor


def make_record(
    root: Path,
    fingerprint: str,
    predecessor: dict[str, Any],
    previous: str,
    binding_head: str,
    binding_tree: str,
    proof: dict[str, Any],
    created_at: str,
) -> dict[str, Any]:
    selector = predecessor["authority_selectors"]
    prior = projection(root, PREDECESSOR_BINDING_HEAD, selector)
    before = projection(root, TRANSITION_PARENT, selector)
    rebound = projection(root, TRANSITION_COMMIT, selector)
    live = projection(root, binding_head, selector)
    changed = [field for field in PROJECTION_FIELDS if before[field] != rebound[field]]
    changed_components = _changed_components(before, rebound)
    if (
        prior != predecessor.get("live_subject_projection")
        or before != prior
        or rebound != live
        or changed != ["registry_rows"]
        or changed_components != EXPECTED_CHANGED_COMPONENT_IDS
    ):
        raise ValueError("SPR5_RECORD_PROJECTION_INVALID:" + fingerprint)
    product_blobs: dict[str, str] = {}
    for path in selector.get("paths", []):
        raw = blob(root, binding_head, str(path))
        if raw is None:
            raise ValueError("SPR5_PRODUCT_BLOB_MISSING:" + fingerprint)
        product_blobs[str(path)] = sha256_bytes(raw)
    record: dict[str, Any] = {
        "schema_version": RECORD_SCHEMA_VERSION,
        "record_kind": RECORD_KIND,
        "revalidation_id": expected_id(fingerprint),
        "authorization_id": AUTHORIZATION_ID,
        "authorization_base_head_sha": AUTHORIZATION_BASE_HEAD,
        "prior_epoch_id": PRIOR_EPOCH_ID,
        "failure_fingerprints": [fingerprint],
        "failure_fingerprint_set_sha256": line_set_sha([fingerprint]),
        "prior_invalidations": [ALLOWED_INVALIDATION],
        "prior_record_path": predecessor.get("prior_record_path", ""),
        "prior_record_sha256": predecessor.get("prior_record_sha256", ""),
        "prior_record_payload_sha256": predecessor.get("prior_record_payload_sha256", ""),
        "prior_correction_id": predecessor.get("prior_correction_id", ""),
        "prior_batch_manifest_path": predecessor.get("prior_batch_manifest_path", ""),
        "prior_batch_manifest_sha256": predecessor.get("prior_batch_manifest_sha256", ""),
        "predecessor_revalidation_record_path": predecessor["_v5_predecessor_path"],
        "predecessor_revalidation_record_sha256": predecessor["_v5_predecessor_sha256"],
        "predecessor_revalidation_record_payload_sha256": predecessor[
            "_v5_predecessor_payload_sha256"
        ],
        "predecessor_revalidation_id": predecessor.get("revalidation_id", ""),
        "previous_revalidation_chain_sha256": previous,
        "revalidation_binding_head_sha": binding_head,
        "revalidation_binding_tree_sha": binding_tree,
        "authority_selectors": selector,
        "component_id": predecessor["component_id"],
        "prior_identity_binding": predecessor["prior_identity_binding"],
        "prior_subject_projection": prior,
        "prior_subject_projection_sha256": sha256_bytes(canonical_bytes(prior)),
        "pre_change_subject_projection": before,
        "pre_change_subject_projection_sha256": sha256_bytes(canonical_bytes(before)),
        "rebound_subject_projection": rebound,
        "rebound_subject_projection_sha256": sha256_bytes(canonical_bytes(rebound)),
        "live_subject_projection": live,
        "live_subject_projection_sha256": sha256_bytes(canonical_bytes(live)),
        "changed_projection_sections": changed,
        "changed_projection_component_ids": changed_components,
        "authority_transition_proof": proof,
        "bound_product_blob_sha256_by_path": product_blobs,
        "future_failure_policy": FUTURE_POLICY,
        "wildcard_count": 0,
        "new_effective_status": "CORRECTED_HISTORICAL_DEBT",
        "revalidation_reason": "REGISTRY_AUTHORITY_SOURCE_METADATA_ONLY_SUCCESSOR_V5",
        "created_at": created_at,
        "creator": "v076_subject_projection_revalidation_successor_v5_builder.py",
    }
    record["record_payload_sha256"] = payload_sha(record)
    return record


def _empty_failure(mode: str, failure: str, artifact_ref: str = "", evaluated_ref: str = "") -> dict[str, Any]:
    return {
        "status": "FAIL",
        "mode": mode,
        "failures": [failure],
        "trusted_by_fingerprint": {},
        "review_trusted_by_fingerprint": {},
        "record_count": 0,
        "artifact_head_sha": artifact_ref,
        "evaluated_head_sha": evaluated_ref,
    }


def validate(
    root: Path,
    manifest_path: Path,
    evaluated_head: str,
    stage_dir: Path | None = None,
    artifact_head: str | None = None,
) -> dict[str, Any]:
    failures: list[str] = []
    trusted: dict[str, dict[str, Any]] = {}
    mode = "COMMITTED" if stage_dir is None else "STAGE_REVIEW"
    artifact_ref = ""
    try:
        evaluated_ref = str(_git(root, "rev-parse", f"{evaluated_head}^{{commit}}"))
        evaluated_tree = str(_git(root, "rev-parse", f"{evaluated_ref}^{{tree}}"))
        if stage_dir is None:
            artifact_ref = str(_git(root, "rev-parse", f"{artifact_head or 'HEAD'}^{{commit}}"))
            manifest_relative = str(manifest_path.resolve().relative_to(root.resolve())).replace(
                "\\", "/"
            )
            if manifest_relative != SUCCESSOR_ROOT + "manifest.json":
                raise ValueError("SPR5_MANIFEST_PATH_INVALID")
            manifest, manifest_raw = document(root, artifact_ref, manifest_relative)
            schema_raw = blob(root, artifact_ref, SCHEMA_PATH)
            if schema_raw is None:
                raise ValueError("SPR5_SCHEMA_BLOB_MISSING")
        else:
            manifest_raw = manifest_path.read_bytes()
            manifest = strict(manifest_raw)
            schema_raw = (root / SCHEMA_PATH).read_bytes()
        if not isinstance(manifest, dict):
            raise ValueError("SPR5_MANIFEST_NOT_OBJECT")
    except Exception as error:
        return _empty_failure(mode, str(error), artifact_ref)
    if (
        manifest.get("revalidation_binding_head_sha") != evaluated_ref
        or manifest.get("revalidation_binding_tree_sha") != evaluated_tree
    ):
        return _empty_failure(
            mode, "SPR5_BINDING_INVALID", artifact_ref, evaluated_ref
        )
    try:
        fingerprints, predecessor_rows, predecessor_manifest = target_rows(
            root, evaluated_ref
        )
        proof = transition_proof(root)
    except Exception as error:
        return _empty_failure(mode, str(error), artifact_ref, evaluated_ref)

    if set(manifest) != MANIFEST_FIELDS:
        failures.append("SPR5_MANIFEST_FIELD_SET_INVALID")
    if (
        manifest.get("manifest_kind") != MANIFEST_KIND
        or manifest.get("schema_version") != MANIFEST_SCHEMA_VERSION
        or manifest.get("manifest_id") != MANIFEST_ID
        or manifest.get("authorization_id") != AUTHORIZATION_ID
        or manifest.get("authorization_base_head_sha") != AUTHORIZATION_BASE_HEAD
        or manifest.get("prior_epoch_id") != PRIOR_EPOCH_ID
    ):
        failures.append("SPR5_MANIFEST_IDENTITY_INVALID")
    if (
        manifest.get("predecessor_manifest_path") != PREDECESSOR_MANIFEST_PATH
        or manifest.get("predecessor_manifest_sha256") != PREDECESSOR_MANIFEST_SHA256
        or manifest.get("predecessor_record_count") != PREDECESSOR_RECORD_COUNT
        or manifest.get("predecessor_record_chain_terminal_sha256")
        != PREDECESSOR_CHAIN_TERMINAL_SHA256
        or manifest.get("predecessor_failure_fingerprint_set_sha256")
        != PREDECESSOR_FINGERPRINT_SET_SHA256
    ):
        failures.append("SPR5_PREDECESSOR_INVALID")
    if (
        manifest.get("authority_transition_parent_sha") != TRANSITION_PARENT
        or manifest.get("authority_transition_commit_sha") != TRANSITION_COMMIT
        or manifest.get("authority_source_paths") != list(AUTHORITY_PATHS)
        or manifest.get("authority_source_before_blob_sha256_by_path")
        != proof["before_sha256_by_path"]
        or manifest.get("authority_source_after_blob_sha256_by_path")
        != proof["after_sha256_by_path"]
        or manifest.get("authority_source_diff_sha256_by_path")
        != proof["diff_sha256_by_path"]
    ):
        failures.append("SPR5_TRANSITION_INVALID")
    if manifest.get("schema_path") != SCHEMA_PATH or manifest.get(
        "schema_sha256"
    ) != sha256_bytes(schema_raw):
        failures.append("SPR5_SCHEMA_SHA_INVALID")
    if (
        manifest.get("failure_fingerprints") != fingerprints
        or manifest.get("record_count") != 2
        or manifest.get("failure_fingerprint_set_sha256") != line_set_sha(fingerprints)
    ):
        failures.append("SPR5_TARGET_SET_INVALID")
    if (
        manifest.get("allowed_invalidation") != ALLOWED_INVALIDATION
        or manifest.get("future_failure_auto_revalidation") is not False
        or manifest.get("wildcard_count") != 0
    ):
        failures.append("SPR5_FAIL_CLOSED_POLICY_INVALID")

    previous = str(manifest.get("record_chain_start_sha256", ""))
    bindings = manifest.get("record_bindings", [])
    if not isinstance(bindings, list) or len(bindings) != 2:
        failures.append("SPR5_BINDING_COUNT_INVALID")
        bindings = []
    for index, fingerprint in enumerate(fingerprints):
        try:
            if stage_dir is None:
                record, raw = document(root, artifact_ref, expected_record_path(fingerprint))
            else:
                raw = (
                    stage_dir / "records" / Path(expected_record_path(fingerprint)).name
                ).read_bytes()
                record = strict(raw)
            if not isinstance(record, dict):
                raise ValueError("NOT_OBJECT")
            source = predecessor_rows[fingerprint]
            selector = source["authority_selectors"]
            prior = projection(root, PREDECESSOR_BINDING_HEAD, selector)
            before = projection(root, TRANSITION_PARENT, selector)
            rebound = projection(root, TRANSITION_COMMIT, selector)
            live = projection(root, evaluated_ref, selector)
            product_blobs: dict[str, str] = {}
            for path in selector.get("paths", []):
                product_raw = blob(root, evaluated_ref, str(path))
                if product_raw is None:
                    raise ValueError("PRODUCT_BLOB_MISSING")
                product_blobs[str(path)] = sha256_bytes(product_raw)
        except Exception:
            failures.append("SPR5_RECORD_UNREADABLE:" + fingerprint)
            continue
        local: list[str] = []
        if set(record) != RECORD_FIELDS:
            local.append("RECORD_FIELD_SET")
        if (
            record.get("record_kind") != RECORD_KIND
            or record.get("schema_version") != RECORD_SCHEMA_VERSION
            or record.get("failure_fingerprints") != [fingerprint]
            or record.get("failure_fingerprint_set_sha256") != line_set_sha([fingerprint])
            or record.get("revalidation_id") != expected_id(fingerprint)
        ):
            local.append("RECORD_IDENTITY")
        if (
            record.get("previous_revalidation_chain_sha256") != previous
            or record.get("record_payload_sha256") != payload_sha(record)
        ):
            local.append("RECORD_CHAIN_PAYLOAD")
        if (
            record.get("predecessor_revalidation_record_path")
            != source["_v5_predecessor_path"]
            or record.get("predecessor_revalidation_record_sha256")
            != source["_v5_predecessor_sha256"]
            or record.get("predecessor_revalidation_record_payload_sha256")
            != source["_v5_predecessor_payload_sha256"]
            or record.get("predecessor_revalidation_id") != source.get("revalidation_id")
            or record.get("prior_record_path") != source.get("prior_record_path")
            or record.get("prior_record_sha256") != source.get("prior_record_sha256")
            or record.get("prior_record_payload_sha256")
            != source.get("prior_record_payload_sha256")
            or record.get("prior_correction_id") != source.get("prior_correction_id")
        ):
            local.append("RECORD_PREDECESSOR")
        if (
            record.get("revalidation_binding_head_sha") != evaluated_ref
            or record.get("revalidation_binding_tree_sha") != evaluated_tree
            or record.get("authority_selectors") != selector
            or record.get("prior_subject_projection") != prior
            or record.get("pre_change_subject_projection") != before
            or record.get("rebound_subject_projection") != rebound
            or record.get("live_subject_projection") != live
            or rebound != live
            or record.get("prior_subject_projection_sha256")
            != sha256_bytes(canonical_bytes(prior))
            or record.get("pre_change_subject_projection_sha256")
            != sha256_bytes(canonical_bytes(before))
            or record.get("rebound_subject_projection_sha256")
            != sha256_bytes(canonical_bytes(rebound))
            or record.get("live_subject_projection_sha256")
            != sha256_bytes(canonical_bytes(live))
            or record.get("changed_projection_sections") != ["registry_rows"]
            or record.get("changed_projection_component_ids")
            != EXPECTED_CHANGED_COMPONENT_IDS
            or record.get("authority_transition_proof") != proof
            or record.get("bound_product_blob_sha256_by_path") != product_blobs
        ):
            local.append("RECORD_PROJECTION")
        if (
            record.get("prior_invalidations") != [ALLOWED_INVALIDATION]
            or record.get("future_failure_policy") != FUTURE_POLICY
            or record.get("wildcard_count") != 0
            or record.get("new_effective_status") != "CORRECTED_HISTORICAL_DEBT"
        ):
            local.append("RECORD_FAIL_CLOSED_POLICY")
        if index < len(bindings):
            binding = bindings[index]
            if (
                set(binding) != BINDING_FIELDS
                or binding.get("path") != expected_record_path(fingerprint)
                or binding.get("record_sha256") != sha256_bytes(raw)
                or binding.get("record_payload_sha256")
                != record.get("record_payload_sha256")
                or binding.get("failure_fingerprints") != [fingerprint]
                or binding.get("previous_revalidation_chain_sha256") != previous
                or binding.get("predecessor_revalidation_record_path")
                != source["_v5_predecessor_path"]
                or binding.get("predecessor_revalidation_record_sha256")
                != source["_v5_predecessor_sha256"]
                or binding.get("predecessor_revalidation_record_payload_sha256")
                != source["_v5_predecessor_payload_sha256"]
            ):
                local.append("MANIFEST_BINDING")
        if local:
            failures.extend(item + ":" + fingerprint for item in local)
        else:
            trusted[fingerprint] = {
                "allowed_invalidations": [ALLOWED_INVALIDATION],
                "prior_record_path": record.get("prior_record_path", ""),
                "revalidation_id": record.get("revalidation_id", ""),
                "record_path": expected_record_path(fingerprint),
                "revalidation_binding_head_sha": evaluated_ref,
            }
        previous = str(record.get("record_payload_sha256", previous))
    if (
        manifest.get("record_chain_start_sha256")
        != predecessor_manifest.get("record_chain_terminal_sha256")
        or previous != manifest.get("record_chain_terminal_sha256")
    ):
        failures.append("SPR5_CHAIN_TERMINAL_INVALID")
    if failures:
        trusted = {}
    committed = trusted if stage_dir is None else {}
    review = trusted if stage_dir is not None else {}
    return {
        "status": "PASS" if not failures else "FAIL",
        "mode": mode,
        "failures": sorted(set(failures)),
        "trusted_by_fingerprint": committed,
        "review_trusted_by_fingerprint": review,
        "record_count": len(trusted),
        "replacement_record_count": 2,
        "wildcard_count": 0,
        "future_failure_auto_revalidation_count": 0,
        "artifact_head_sha": artifact_ref,
        "evaluated_head_sha": evaluated_ref,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path, default=Path.cwd())
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--evaluated-head", required=True)
    parser.add_argument("--artifact-head", default="HEAD")
    parser.add_argument("--stage-dir", type=Path)
    args = parser.parse_args(argv)
    result = validate(
        args.project.resolve(),
        args.manifest.resolve(),
        args.evaluated_head,
        args.stage_dir.resolve() if args.stage_dir else None,
        args.artifact_head,
    )
    print(json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2))
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
