#!/usr/bin/env python3
"""Fail-closed append-only successor for the two post-touch receipts.

The predecessor receipts were bound at 5af52a5b.  This layer replays their
original touch proof, enumerates every later touch to the exact selected
product and authority paths, and rebinds exact committed bytes/projections at
7e87c564.  It never discovers fingerprints from a current scan and cannot
trust wildcard or future failures.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path
from typing import Any, Iterable


SCHEMA_VERSION = "space_syndicate.v076.reuse_exact_failure_correction.v2.post_touch_revalidation_successor_v2_schema.v1"
MANIFEST_SCHEMA_VERSION = "space_syndicate.v076.reuse_exact_failure_correction.v2.post_touch_revalidation_successor_v2_manifest.v1"
RECORD_SCHEMA_VERSION = "space_syndicate.v076.reuse_exact_failure_correction.v2.post_touch_revalidation_successor_v2_record.v1"
MANIFEST_KIND = "POST_TOUCH_REVALIDATION_SUCCESSOR_V2_MANIFEST"
RECORD_KIND = "POST_TOUCH_REVALIDATION_SUCCESSOR_V2_RECORD"
MANIFEST_ID = "V076-POST-TOUCH-REVALIDATION-SUCCESSOR-V2-20260830"

AUTHORIZATION_ID = "USER_AUTHORIZATION_V076_CURRENT_SUBJECT_CONVERGENCE_AND_COMMERCIAL_RESUME_20260830"
AUTHORIZATION_BASE_HEAD = "7b2bd08a9916a3a517f2d418765c544cce0261cc"
PREDECESSOR_AUTHORIZATION_ID = "USER_AUTHORIZATION_V076_REUSE_FULL_CONVERGENCE_AND_MCP_ONLY_20260827"
PREDECESSOR_AUTHORIZATION_BASE_HEAD = "d701a81dce693b584d52fbfca3e0e78b521ad775"

BINDING_HEAD = "7e87c564fc2c092a0fb00519c15711d19f99305f"
BINDING_TREE = "ab8d71ef783710b348eb299dc7c9d5ba58172a1b"
PREDECESSOR_BINDING_HEAD = "5af52a5bfe4f7734b0a01aeb9b63dd5e2d606acb"
PREDECESSOR_BINDING_TREE = "6e1df65d9945e3a46a4dd979f3af65f9971958a6"

SCHEMA_PATH = "docs/architecture/reuse_corrections/v2/schema_post_touch_revalidation_successor_v2_20260830.json"
SCHEMA_SHA256 = "5fc638c163c10463a71d289ac052febc41b8ec083462cc9f57e59ee6ea75033c"
SUCCESSOR_ROOT = "docs/architecture/reuse_corrections/v2/post_touch_revalidation_successor_v2"
MANIFEST_PATH = SUCCESSOR_ROOT + "/manifest.json"
RECORD_ROOT = SUCCESSOR_ROOT + "/records"
PREDECESSOR_MANIFEST_PATH = "docs/architecture/reuse_corrections/v2/post_touch_revalidation/full_convergence_batch004_20260828_manifest.json"
PREDECESSOR_MANIFEST_SHA256 = "95b8f25cda3f42fd2b7cff4a611f1b860d58d5c5187a0b1f34bbd27cedd09ee2"
PREDECESSOR_RECORD_COUNT = 2
PREDECESSOR_FINGERPRINT_SET_SHA256 = "10d0cec35ae238a13bdaf6e761583012e8105fbbc4606f6f361f9dfca3834f0c"
PREDECESSOR_CHAIN_TERMINAL_SHA256 = "6aa50705a471a94dc0af71484564a777a0ec6fc325ce68eb6592d1ba3d8427dc"

TARGET_FINGERPRINTS = (
    "V2F-2a1119496ba5fe9ab1d523118e7f325946ad8c01fbd9d9e3c575c7d7dd4dac2b",
    "V2F-6a4c0788f95300f0ef3c63df2b8f838824d5f4a4aa552c032b908cab9090d618",
)
TARGET_PRODUCT_PATHS = (
    "scripts/presentation/v076_presentation_animation_director.gd",
    "scripts/v075_runtime/v075_runtime_owner.gd",
)
AUTHORITY_PATHS = (
    "docs/architecture/V076_DYNAMIC_REFERENCE_MANIFEST.json",
    "docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json",
    "docs/architecture/V076_OWNER_REUSE_MAP.md",
    "docs/architecture/V076_SUPERSESSION_MAP.json",
)
PROJECTION_FIELDS = (
    "dynamic_reference_rows", "owner_map_lines", "registry_rows", "supersession_rows"
)
FUTURE_POLICY = {
    "FUTURE_FAILURE_AUTO_REVALIDATION_COUNT": 0,
    "NEW_FAILURE_REQUIRES_NEW_RECORD": True,
}
CREATED_AT = "2026-08-30T00:00:00Z"
CREATOR = "v076_post_touch_revalidation_successor_v2_builder.py"

MANIFEST_FIELDS = frozenset("""schema_version manifest_kind manifest_id authorization_id authorization_base_head_sha predecessor_authorization_id predecessor_authorization_base_head_sha schema_path schema_sha256 predecessor_manifest_path predecessor_manifest_sha256 predecessor_record_count predecessor_failure_fingerprint_set_sha256 predecessor_record_chain_terminal_sha256 revalidation_binding_head_sha revalidation_binding_tree_sha record_count failure_fingerprints failure_fingerprint_set_sha256 record_chain_start_sha256 record_chain_terminal_sha256 record_bindings product_paths authority_source_paths current_projection_sha256_by_failure wildcard_count future_failure_auto_revalidation_count committed_only_bytes created_at creator""".split())
RECORD_FIELDS = frozenset("""schema_version record_kind revalidation_id authorization_id authorization_base_head_sha predecessor_authorization_id predecessor_authorization_base_head_sha failure_fingerprints failure_fingerprint_set_sha256 predecessor_manifest_path predecessor_manifest_sha256 predecessor_record_chain_terminal_sha256 predecessor_record_path predecessor_record_sha256 predecessor_record_payload_sha256 predecessor_revalidation_id original_correction_record_path original_correction_record_sha256 original_correction_record_payload_sha256 original_correction_id predecessor_binding_head_sha predecessor_binding_tree_sha revalidation_binding_head_sha revalidation_binding_tree_sha authority_selectors authority_selector_sha256 predecessor_touch_proof predecessor_touch_proof_sha256 prior_invalidations predecessor_subject_projection predecessor_subject_projection_sha256 current_subject_projection current_subject_projection_sha256 changed_projection_sections product_path_transitions authority_path_transitions current_product_blob_sha256_by_path future_failure_policy wildcard_count new_effective_status previous_revalidation_chain_sha256 created_at creator revalidation_reason record_payload_sha256""".split())
BINDING_FIELDS = frozenset("""path record_sha256 record_payload_sha256 revalidation_id failure_fingerprints previous_revalidation_chain_sha256 predecessor_record_path predecessor_record_sha256 predecessor_record_payload_sha256 predecessor_revalidation_id""".split())


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def line_set_sha(values: Iterable[str]) -> str:
    rendered = sorted(str(value) for value in values)
    return sha256_bytes((("\n".join(rendered) + "\n") if rendered else "").encode("utf-8"))


def payload_sha(document: dict[str, Any]) -> str:
    payload = dict(document)
    payload.pop("record_payload_sha256", None)
    return sha256_bytes(canonical_bytes(payload))


def _strict_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("DUPLICATE_JSON_KEY:" + key)
        result[key] = value
    return result


def strict_json_bytes(raw: bytes) -> Any:
    return json.loads(
        raw.decode("utf-8-sig"),
        object_pairs_hook=_strict_pairs,
        parse_constant=lambda value: (_ for _ in ()).throw(ValueError("NONFINITE_JSON:" + value)),
    )


def _git(root: Path, *args: str, binary: bool = False) -> str | bytes:
    return subprocess.check_output(
        ["git", *args], cwd=root, stderr=subprocess.STDOUT, text=not binary
    )


def _blob(root: Path, commit: str, path: str) -> bytes | None:
    result = subprocess.run(
        ["git", "show", f"{commit}:{path}"], cwd=root,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
    )
    return result.stdout if result.returncode == 0 else None


def _ancestor(root: Path, ancestor: str, descendant: str) -> bool:
    return subprocess.run(
        ["git", "merge-base", "--is-ancestor", ancestor, descendant],
        cwd=root, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False,
    ).returncode == 0


def _load_committed_json(root: Path, commit: str, path: str) -> tuple[dict[str, Any], bytes]:
    raw = _blob(root, commit, path)
    if raw is None:
        raise ValueError("COMMITTED_JSON_MISSING:" + path)
    document = strict_json_bytes(raw)
    if not isinstance(document, dict):
        raise ValueError("COMMITTED_JSON_NOT_OBJECT:" + path)
    return document, raw


def _projection(root: Path, commit: str, selector: dict[str, Any]) -> dict[str, Any]:
    expected_selector_fields = {
        "component_ids", "dynamic_reference_ids", "paths", "retirement_ids", "supersession_ids"
    }
    if set(selector) != expected_selector_fields:
        raise ValueError("SELECTOR_FIELD_SET_INVALID")
    for field in expected_selector_fields:
        values = selector.get(field)
        if (
            not isinstance(values, list)
            or values != sorted(values)
            or len(values) != len(set(values))
            or any(not isinstance(value, str) or not value or any(c in value for c in "*?[]") for value in values)
        ):
            raise ValueError("SELECTOR_NOT_EXACT:" + field)
    registry, _ = _load_committed_json(root, commit, AUTHORITY_PATHS[1])
    dynamic, _ = _load_committed_json(root, commit, AUTHORITY_PATHS[0])
    supersession, _ = _load_committed_json(root, commit, AUTHORITY_PATHS[3])
    owner_raw = _blob(root, commit, AUTHORITY_PATHS[2])
    if owner_raw is None:
        raise ValueError("OWNER_MAP_MISSING")
    component_ids = set(selector["component_ids"])
    paths = set(selector["paths"])
    registry_rows: list[dict[str, Any]] = []
    for key in ("component_inventory", "historical_identity_backfill"):
        rows = registry.get(key, [])
        if isinstance(rows, list):
            for row in rows:
                if isinstance(row, dict) and (
                    str(row.get("component_id", "")) in component_ids
                    or str(row.get("path", "")) in paths
                ):
                    tagged = dict(row)
                    tagged["authority_source_kind"] = key
                    registry_rows.append(tagged)
    supersession_rows: list[dict[str, Any]] = []
    for key in ("entries", "retirement_entries"):
        rows = supersession.get(key, [])
        if isinstance(rows, list):
            for row in rows:
                if isinstance(row, dict) and (
                    str(row.get("supersession_id", "")) in set(selector["supersession_ids"])
                    or str(row.get("retirement_id", "")) in set(selector["retirement_ids"])
                ):
                    supersession_rows.append(row)
    dynamic_rows = [
        row for row in dynamic.get("entries", [])
        if isinstance(row, dict) and str(row.get("dynamic_reference_id", "")) in set(selector["dynamic_reference_ids"])
    ] if isinstance(dynamic.get("entries", []), list) else []
    needles = sorted({str(value) for field in expected_selector_fields for value in selector[field]})
    owner_lines = sorted({
        line.rstrip() for line in owner_raw.decode("utf-8-sig", errors="replace").splitlines()
        if any(needle in line for needle in needles)
    })
    result = {
        "dynamic_reference_rows": sorted(dynamic_rows, key=canonical_bytes),
        "owner_map_lines": owner_lines,
        "registry_rows": sorted(registry_rows, key=canonical_bytes),
        "supersession_rows": sorted(supersession_rows, key=canonical_bytes),
    }
    if not any(result.values()):
        raise ValueError("SELECTOR_UNRESOLVED")
    return result


def _touch_commits(root: Path, start: str, end: str, path: str) -> list[str]:
    output = str(_git(root, "log", "--format=%H", "--reverse", f"{start}..{end}", "--", path))
    return [line.strip() for line in output.splitlines() if line.strip()]


def _diff_sha(root: Path, parent: str, commit: str, path: str) -> str:
    raw = _git(root, "diff", "--binary", "--no-ext-diff", parent, commit, "--", path, binary=True)
    assert isinstance(raw, bytes)
    return sha256_bytes(raw)


def path_transition(root: Path, start: str, end: str, path: str) -> dict[str, Any]:
    before = _blob(root, start, path)
    after = _blob(root, end, path)
    if before is None or after is None:
        raise ValueError("TRANSITION_BLOB_MISSING:" + path)
    touches: list[dict[str, Any]] = []
    for commit in _touch_commits(root, start, end, path):
        parent = str(_git(root, "rev-parse", f"{commit}^1")).strip()
        old = _blob(root, parent, path)
        new = _blob(root, commit, path)
        if old is None or new is None:
            raise ValueError("TOUCH_BLOB_MISSING:" + path + ":" + commit)
        touches.append({
            "commit_sha": commit,
            "parent_sha": parent,
            "before_blob_sha256": sha256_bytes(old),
            "after_blob_sha256": sha256_bytes(new),
            "diff_sha256": _diff_sha(root, parent, commit, path),
        })
    return {
        "path": path,
        "before_blob_sha256": sha256_bytes(before),
        "after_blob_sha256": sha256_bytes(after),
        "touch_count": len(touches),
        "touch_commits": touches,
    }


def expected_record_path(fingerprint: str) -> str:
    return RECORD_ROOT + "/pts2-" + fingerprint[4:] + ".json"


def expected_revalidation_id(fingerprint: str) -> str:
    return "V076-POST-TOUCH-SUCCESSOR-V2-" + fingerprint[4:20].upper()


def allows_invalidation(
    trusted_by_fingerprint: dict[str, dict[str, Any]],
    *,
    fingerprint: str,
    invalidation_code: str,
    prior_record_path: str,
) -> bool:
    """Allow only an exact predecessor correction identity and exact code."""
    row = trusted_by_fingerprint.get(fingerprint)
    if not isinstance(row, dict):
        return False
    allowed = row.get("allowed_invalidations")
    return (
        isinstance(allowed, list)
        and invalidation_code in allowed
        and str(row.get("prior_record_path", "")).replace("\\", "/")
        == str(prior_record_path).replace("\\", "/")
    )


def _predecessor_context(root: Path, fingerprint: str) -> tuple[dict[str, Any], bytes, dict[str, Any], bytes]:
    manifest, manifest_raw = _load_committed_json(root, BINDING_HEAD, PREDECESSOR_MANIFEST_PATH)
    if sha256_bytes(manifest_raw) != PREDECESSOR_MANIFEST_SHA256:
        raise ValueError("PREDECESSOR_MANIFEST_SHA_DRIFT")
    if (
        manifest.get("failure_fingerprints") != list(TARGET_FINGERPRINTS)
        or manifest.get("record_count") != PREDECESSOR_RECORD_COUNT
        or manifest.get("failure_fingerprint_set_sha256") != PREDECESSOR_FINGERPRINT_SET_SHA256
        or manifest.get("record_chain_terminal_sha256") != PREDECESSOR_CHAIN_TERMINAL_SHA256
        or manifest.get("revalidation_binding_head_sha") != PREDECESSOR_BINDING_HEAD
        or manifest.get("revalidation_binding_tree_sha") != PREDECESSOR_BINDING_TREE
    ):
        raise ValueError("PREDECESSOR_MANIFEST_IDENTITY_DRIFT")
    bindings = manifest.get("record_bindings")
    matches = [binding for binding in bindings if isinstance(binding, dict) and binding.get("failure_fingerprints") == [fingerprint]] if isinstance(bindings, list) else []
    if len(matches) != 1:
        raise ValueError("PREDECESSOR_BINDING_CARDINALITY:" + fingerprint)
    record_path = str(matches[0].get("path", ""))
    record, record_raw = _load_committed_json(root, BINDING_HEAD, record_path)
    if (
        sha256_bytes(record_raw) != matches[0].get("record_sha256")
        or record.get("record_payload_sha256") != matches[0].get("record_payload_sha256")
        or record.get("failure_fingerprints") != [fingerprint]
        or record.get("revalidation_binding_head_sha") != PREDECESSOR_BINDING_HEAD
    ):
        raise ValueError("PREDECESSOR_RECORD_SEAL_DRIFT:" + fingerprint)
    return matches[0], record_raw, record, manifest_raw


def derive_record(root: Path, fingerprint: str, previous_chain: str) -> dict[str, Any]:
    binding, predecessor_raw, predecessor, _ = _predecessor_context(root, fingerprint)
    original_path = str(predecessor.get("prior_record_path", ""))
    original, original_raw = _load_committed_json(root, BINDING_HEAD, original_path)
    if (
        sha256_bytes(original_raw) != predecessor.get("prior_record_sha256")
        or original.get("record_payload_sha256") != predecessor.get("prior_record_payload_sha256")
        or original.get("correction_id") != predecessor.get("prior_correction_id")
    ):
        raise ValueError("ORIGINAL_CORRECTION_SEAL_DRIFT:" + fingerprint)
    identities = original.get("identity_binding_by_failure")
    identity = identities.get(fingerprint) if isinstance(identities, dict) else None
    if not isinstance(identity, dict):
        raise ValueError("ORIGINAL_IDENTITY_MISSING:" + fingerprint)
    selector = identity.get("authority_selectors")
    if not isinstance(selector, dict):
        raise ValueError("ORIGINAL_SELECTOR_MISSING:" + fingerprint)
    predecessor_projection = _projection(root, PREDECESSOR_BINDING_HEAD, selector)
    stored_projection = predecessor.get("rebound_subject_projection_by_failure", {}).get(fingerprint)
    stored_projection_sha = predecessor.get("rebound_subject_projection_sha256_by_failure", {}).get(fingerprint)
    if predecessor_projection != stored_projection or sha256_bytes(canonical_bytes(predecessor_projection)) != stored_projection_sha:
        raise ValueError("PREDECESSOR_PROJECTION_DRIFT:" + fingerprint)
    current_projection = _projection(root, BINDING_HEAD, selector)
    product_paths = sorted({
        value
        for row in current_projection["registry_rows"]
        if isinstance(row, dict)
        for key in ("path", "owner_path")
        for value in [row.get(key)]
        if isinstance(value, str) and value and _blob(root, BINDING_HEAD, value) is not None
    } | {str(identity.get("current_path", ""))})
    if product_paths != list(TARGET_PRODUCT_PATHS):
        raise ValueError("PRODUCT_PATH_SET_DRIFT:" + fingerprint + ":" + repr(product_paths))
    predecessor_touch = predecessor.get("touch_proof")
    if not isinstance(predecessor_touch, dict):
        raise ValueError("PREDECESSOR_TOUCH_PROOF_MISSING:" + fingerprint)
    touch_path = str(predecessor_touch.get("path", ""))
    touch_commit = str(predecessor_touch.get("commit_sha", ""))
    original_start = str(predecessor.get("prior_binding_head_sha", ""))
    if _touch_commits(root, original_start, PREDECESSOR_BINDING_HEAD, touch_path) != [touch_commit]:
        raise ValueError("PREDECESSOR_TOUCH_SEQUENCE_DRIFT:" + fingerprint)
    touch_parent = str(_git(root, "rev-parse", f"{touch_commit}^1")).strip()
    old = _blob(root, touch_parent, touch_path)
    new = _blob(root, touch_commit, touch_path)
    expected_touch = {
        "commit_sha": touch_commit,
        "parent_sha": touch_parent,
        "path": touch_path,
        "before_blob_sha256": sha256_bytes(old) if old is not None else "MISSING",
        "after_blob_sha256": sha256_bytes(new) if new is not None else "MISSING",
        "diff_sha256": _diff_sha(root, touch_parent, touch_commit, touch_path),
    }
    if predecessor_touch != expected_touch:
        raise ValueError("PREDECESSOR_TOUCH_PROOF_DRIFT:" + fingerprint)
    product_transitions = {
        path: path_transition(root, PREDECESSOR_BINDING_HEAD, BINDING_HEAD, path)
        for path in product_paths
    }
    authority_transitions = {
        path: path_transition(root, PREDECESSOR_BINDING_HEAD, BINDING_HEAD, path)
        for path in AUTHORITY_PATHS
    }
    changed_sections = sorted(
        field for field in PROJECTION_FIELDS
        if predecessor_projection.get(field) != current_projection.get(field)
    )
    record: dict[str, Any] = {
        "schema_version": RECORD_SCHEMA_VERSION,
        "record_kind": RECORD_KIND,
        "revalidation_id": expected_revalidation_id(fingerprint),
        "authorization_id": AUTHORIZATION_ID,
        "authorization_base_head_sha": AUTHORIZATION_BASE_HEAD,
        "predecessor_authorization_id": PREDECESSOR_AUTHORIZATION_ID,
        "predecessor_authorization_base_head_sha": PREDECESSOR_AUTHORIZATION_BASE_HEAD,
        "failure_fingerprints": [fingerprint],
        "failure_fingerprint_set_sha256": line_set_sha([fingerprint]),
        "predecessor_manifest_path": PREDECESSOR_MANIFEST_PATH,
        "predecessor_manifest_sha256": PREDECESSOR_MANIFEST_SHA256,
        "predecessor_record_chain_terminal_sha256": PREDECESSOR_CHAIN_TERMINAL_SHA256,
        "predecessor_record_path": str(binding["path"]),
        "predecessor_record_sha256": sha256_bytes(predecessor_raw),
        "predecessor_record_payload_sha256": str(predecessor["record_payload_sha256"]),
        "predecessor_revalidation_id": str(predecessor["revalidation_id"]),
        "original_correction_record_path": original_path,
        "original_correction_record_sha256": sha256_bytes(original_raw),
        "original_correction_record_payload_sha256": str(original["record_payload_sha256"]),
        "original_correction_id": str(original["correction_id"]),
        "predecessor_binding_head_sha": PREDECESSOR_BINDING_HEAD,
        "predecessor_binding_tree_sha": PREDECESSOR_BINDING_TREE,
        "revalidation_binding_head_sha": BINDING_HEAD,
        "revalidation_binding_tree_sha": BINDING_TREE,
        "authority_selectors": selector,
        "authority_selector_sha256": sha256_bytes(canonical_bytes(selector)),
        "predecessor_touch_proof": predecessor_touch,
        "predecessor_touch_proof_sha256": sha256_bytes(canonical_bytes(predecessor_touch)),
        "prior_invalidations": predecessor.get("prior_invalidations"),
        "predecessor_subject_projection": predecessor_projection,
        "predecessor_subject_projection_sha256": sha256_bytes(canonical_bytes(predecessor_projection)),
        "current_subject_projection": current_projection,
        "current_subject_projection_sha256": sha256_bytes(canonical_bytes(current_projection)),
        "changed_projection_sections": changed_sections,
        "product_path_transitions": product_transitions,
        "authority_path_transitions": authority_transitions,
        "current_product_blob_sha256_by_path": {
            path: product_transitions[path]["after_blob_sha256"] for path in product_paths
        },
        "future_failure_policy": FUTURE_POLICY,
        "wildcard_count": 0,
        "new_effective_status": "HISTORICAL_DEBT_REVALIDATED_AT_CURRENT_BINDING",
        "previous_revalidation_chain_sha256": previous_chain,
        "created_at": CREATED_AT,
        "creator": CREATOR,
        "revalidation_reason": "EXACT_POST_TOUCH_CURRENT_BYTES_AND_PROJECTION_SUCCESSOR_V2",
    }
    record["record_payload_sha256"] = payload_sha(record)
    if set(record) != RECORD_FIELDS:
        raise ValueError("DERIVED_RECORD_FIELD_SET_INVALID")
    return record


def derive_records(root: Path) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    previous = PREDECESSOR_CHAIN_TERMINAL_SHA256
    for fingerprint in TARGET_FINGERPRINTS:
        record = derive_record(root, fingerprint, previous)
        records.append(record)
        previous = record["record_payload_sha256"]
    return records


def derive_manifest(records: list[dict[str, Any]]) -> dict[str, Any]:
    bindings: list[dict[str, Any]] = []
    for fingerprint, record in zip(TARGET_FINGERPRINTS, records, strict=True):
        raw = canonical_bytes(record)
        bindings.append({
            "path": expected_record_path(fingerprint),
            "record_sha256": sha256_bytes(raw),
            "record_payload_sha256": record["record_payload_sha256"],
            "revalidation_id": record["revalidation_id"],
            "failure_fingerprints": [fingerprint],
            "previous_revalidation_chain_sha256": record["previous_revalidation_chain_sha256"],
            "predecessor_record_path": record["predecessor_record_path"],
            "predecessor_record_sha256": record["predecessor_record_sha256"],
            "predecessor_record_payload_sha256": record["predecessor_record_payload_sha256"],
            "predecessor_revalidation_id": record["predecessor_revalidation_id"],
        })
    manifest = {
        "schema_version": MANIFEST_SCHEMA_VERSION,
        "manifest_kind": MANIFEST_KIND,
        "manifest_id": MANIFEST_ID,
        "authorization_id": AUTHORIZATION_ID,
        "authorization_base_head_sha": AUTHORIZATION_BASE_HEAD,
        "predecessor_authorization_id": PREDECESSOR_AUTHORIZATION_ID,
        "predecessor_authorization_base_head_sha": PREDECESSOR_AUTHORIZATION_BASE_HEAD,
        "schema_path": SCHEMA_PATH,
        "schema_sha256": SCHEMA_SHA256,
        "predecessor_manifest_path": PREDECESSOR_MANIFEST_PATH,
        "predecessor_manifest_sha256": PREDECESSOR_MANIFEST_SHA256,
        "predecessor_record_count": PREDECESSOR_RECORD_COUNT,
        "predecessor_failure_fingerprint_set_sha256": PREDECESSOR_FINGERPRINT_SET_SHA256,
        "predecessor_record_chain_terminal_sha256": PREDECESSOR_CHAIN_TERMINAL_SHA256,
        "revalidation_binding_head_sha": BINDING_HEAD,
        "revalidation_binding_tree_sha": BINDING_TREE,
        "record_count": len(records),
        "failure_fingerprints": list(TARGET_FINGERPRINTS),
        "failure_fingerprint_set_sha256": line_set_sha(TARGET_FINGERPRINTS),
        "record_chain_start_sha256": PREDECESSOR_CHAIN_TERMINAL_SHA256,
        "record_chain_terminal_sha256": records[-1]["record_payload_sha256"],
        "record_bindings": bindings,
        "product_paths": list(TARGET_PRODUCT_PATHS),
        "authority_source_paths": list(AUTHORITY_PATHS),
        "current_projection_sha256_by_failure": {
            fingerprint: record["current_subject_projection_sha256"]
            for fingerprint, record in zip(TARGET_FINGERPRINTS, records, strict=True)
        },
        "wildcard_count": 0,
        "future_failure_auto_revalidation_count": 0,
        "committed_only_bytes": True,
        "created_at": CREATED_AT,
        "creator": CREATOR,
    }
    if set(manifest) != MANIFEST_FIELDS:
        raise ValueError("DERIVED_MANIFEST_FIELD_SET_INVALID")
    return manifest


def _schema_failures(root: Path, artifact_head: str, stage: bool) -> list[str]:
    failures: list[str] = []
    try:
        raw = (root / SCHEMA_PATH).read_bytes() if stage else _blob(root, artifact_head, SCHEMA_PATH)
        if raw is None:
            raise ValueError("COMMITTED_SCHEMA_BLOB_MISSING")
        document = strict_json_bytes(raw)
    except Exception as error:
        return ["PTS2_SCHEMA_UNREADABLE:" + str(error)]
    if sha256_bytes(raw) != SCHEMA_SHA256:
        failures.append("PTS2_SCHEMA_SHA256_INVALID")
    if not isinstance(document, dict):
        failures.append("PTS2_SCHEMA_NOT_OBJECT")
    else:
        expected = {
            "schema_version": SCHEMA_VERSION,
            "manifest_schema_version": MANIFEST_SCHEMA_VERSION,
            "record_schema_version": RECORD_SCHEMA_VERSION,
            "manifest_kind": MANIFEST_KIND,
            "record_kind": RECORD_KIND,
            "authorization_id": AUTHORIZATION_ID,
            "authorization_base_head_sha": AUTHORIZATION_BASE_HEAD,
            "predecessor_authorization_id": PREDECESSOR_AUTHORIZATION_ID,
            "predecessor_authorization_base_head_sha": PREDECESSOR_AUTHORIZATION_BASE_HEAD,
            "revalidation_binding_head_sha": BINDING_HEAD,
            "revalidation_binding_tree_sha": BINDING_TREE,
            "predecessor_manifest_path": PREDECESSOR_MANIFEST_PATH,
            "predecessor_manifest_sha256": PREDECESSOR_MANIFEST_SHA256,
            "predecessor_record_count": 2,
            "predecessor_failure_fingerprint_set_sha256": PREDECESSOR_FINGERPRINT_SET_SHA256,
            "predecessor_record_chain_terminal_sha256": PREDECESSOR_CHAIN_TERMINAL_SHA256,
            "target_fingerprints": list(TARGET_FINGERPRINTS),
            "target_fingerprint_set_sha256": line_set_sha(TARGET_FINGERPRINTS),
            "wildcard_count": 0,
            "future_failure_auto_revalidation_count": 0,
            "committed_only_bytes": True,
            "one_exact_fingerprint_per_record": True,
        }
        for key, value in expected.items():
            if document.get(key) != value:
                failures.append("PTS2_SCHEMA_VALUE_INVALID:" + key)
        for key, expected_fields in (
            ("manifest_required_fields", MANIFEST_FIELDS),
            ("record_required_fields", RECORD_FIELDS),
            ("record_binding_fields", BINDING_FIELDS),
        ):
            actual = document.get(key)
            if not isinstance(actual, list) or len(actual) != len(set(actual)) or set(actual) != set(expected_fields):
                failures.append("PTS2_SCHEMA_FIELD_LIST_INVALID:" + key)
        if set(document.get("path_transition_fields", [])) != {"path", "before_blob_sha256", "after_blob_sha256", "touch_count", "touch_commits"}:
            failures.append("PTS2_SCHEMA_PATH_TRANSITION_FIELDS_INVALID")
        if set(document.get("touch_commit_fields", [])) != {"commit_sha", "parent_sha", "before_blob_sha256", "after_blob_sha256", "diff_sha256"}:
            failures.append("PTS2_SCHEMA_TOUCH_FIELDS_INVALID")
        if set(document.get("projection_fields", [])) != set(PROJECTION_FIELDS):
            failures.append("PTS2_SCHEMA_PROJECTION_FIELDS_INVALID")
        negative = document.get("negative_policy")
        required_negative = {"NO_WILDCARD", "NO_FUTURE_FAILURE_AUTO_TRUST", "NO_PREDECESSOR_MUTATION", "NO_UNCOMMITTED_BYTES", "NO_TARGET_SET_EXPANSION", "NO_POST_BINDING_PRODUCT_TOUCH", "NO_POST_BINDING_AUTHORITY_TOUCH", "NO_UNVERIFIED_TOUCH_PROOF"}
        if not isinstance(negative, list) or len(negative) != len(set(negative)) or set(negative) != required_negative:
            failures.append("PTS2_SCHEMA_NEGATIVE_POLICY_INVALID")
    return failures


def validate(
    root: Path,
    *,
    artifact_head: str = "HEAD",
    evaluated_binding_head: str = BINDING_HEAD,
    stage: bool = False,
) -> dict[str, Any]:
    failures: list[str] = []
    try:
        artifact = str(_git(root, "rev-parse", artifact_head)).strip()
        evaluated_binding = str(_git(root, "rev-parse", evaluated_binding_head)).strip()
        if evaluated_binding != BINDING_HEAD:
            failures.append("PTS2_EVALUATED_BINDING_HEAD_INVALID")
        if str(_git(root, "rev-parse", f"{BINDING_HEAD}^{{tree}}")).strip() != BINDING_TREE:
            failures.append("PTS2_BINDING_TREE_INVALID")
        if not _ancestor(root, AUTHORIZATION_BASE_HEAD, BINDING_HEAD):
            failures.append("PTS2_AUTHORIZATION_ANCESTRY_INVALID")
        if not _ancestor(root, PREDECESSOR_BINDING_HEAD, BINDING_HEAD):
            failures.append("PTS2_PREDECESSOR_ANCESTRY_INVALID")
        if not _ancestor(root, BINDING_HEAD, artifact):
            failures.append("PTS2_ARTIFACT_HEAD_NOT_DESCENDANT")
        expected_records = derive_records(root)
        expected_manifest = derive_manifest(expected_records)
    except Exception as error:
        return {"status": "FAIL", "mode": "STAGE_REVIEW" if stage else "COMMITTED", "failures": ["PTS2_DERIVATION_FAILED:" + str(error)], "trusted_by_fingerprint": {}, "record_count": 0}
    failures.extend(_schema_failures(root, artifact, stage))
    if _blob(root, BINDING_HEAD, SCHEMA_PATH) is not None or _blob(root, BINDING_HEAD, MANIFEST_PATH) is not None:
        failures.append("PTS2_ARTIFACT_NOT_APPEND_ONLY")
    try:
        manifest_raw = (root / MANIFEST_PATH).read_bytes() if stage else _blob(root, artifact, MANIFEST_PATH)
        if manifest_raw is None:
            raise ValueError("COMMITTED_MANIFEST_BLOB_MISSING")
        manifest = strict_json_bytes(manifest_raw)
    except Exception as error:
        manifest = None
        manifest_raw = b""
        failures.append("PTS2_MANIFEST_UNREADABLE:" + str(error))
    if manifest != expected_manifest:
        failures.append("PTS2_MANIFEST_SEMANTIC_MISMATCH")
    if isinstance(manifest, dict) and set(manifest) != MANIFEST_FIELDS:
        failures.append("PTS2_MANIFEST_FIELD_SET_INVALID")
    records_dir = root / RECORD_ROOT
    if stage:
        actual_members = sorted(
            path.relative_to(root).as_posix()
            for path in records_dir.glob("*.json")
        ) if records_dir.is_dir() else []
    else:
        listed = str(_git(root, "ls-tree", "-r", "--name-only", artifact, "--", RECORD_ROOT))
        actual_members = sorted(line.strip() for line in listed.splitlines() if line.strip())
    expected_members = sorted(expected_record_path(fp) for fp in TARGET_FINGERPRINTS)
    if actual_members != expected_members:
        failures.append("PTS2_RECORD_MEMBER_SET_INVALID")
    for fingerprint, expected in zip(TARGET_FINGERPRINTS, expected_records, strict=True):
        relative = expected_record_path(fingerprint)
        try:
            raw = (root / relative).read_bytes() if stage else _blob(root, artifact, relative)
            if raw is None:
                raise ValueError("COMMITTED_RECORD_BLOB_MISSING")
            actual = strict_json_bytes(raw)
        except Exception as error:
            failures.append("PTS2_RECORD_UNREADABLE:" + fingerprint + ":" + str(error))
            continue
        if raw != canonical_bytes(actual):
            failures.append("PTS2_RECORD_NOT_CANONICAL:" + fingerprint)
        if actual != expected or not isinstance(actual, dict) or set(actual) != RECORD_FIELDS:
            failures.append("PTS2_RECORD_SEMANTIC_MISMATCH:" + fingerprint)
        if _blob(root, BINDING_HEAD, relative) is not None:
            failures.append("PTS2_RECORD_NOT_APPEND_ONLY:" + fingerprint)
    for path in TARGET_PRODUCT_PATHS + AUTHORITY_PATHS:
        if _touch_commits(root, BINDING_HEAD, artifact, path):
            failures.append("PTS2_POST_BINDING_PATH_TOUCHED:" + path)
        bound = _blob(root, BINDING_HEAD, path)
        live = _blob(root, evaluated_binding, path)
        if bound is None or live != bound:
            failures.append("PTS2_EVALUATED_BINDING_BYTES_DRIFT:" + path)
    for fingerprint, record in zip(TARGET_FINGERPRINTS, expected_records, strict=True):
        live_projection = _projection(root, evaluated_binding, record["authority_selectors"])
        if live_projection != record["current_subject_projection"]:
            failures.append("PTS2_EVALUATED_BINDING_PROJECTION_DRIFT:" + fingerprint)
    failures = sorted(set(failures))
    trusted = {} if failures or stage else {
        fingerprint: {
            "allowed_invalidations": record["prior_invalidations"],
            "prior_record_path": record["original_correction_record_path"],
            "predecessor_record_path": record["predecessor_record_path"],
            "revalidation_id": record["revalidation_id"],
            "record_path": expected_record_path(fingerprint),
            "record_payload_sha256": record["record_payload_sha256"],
            "revalidation_binding_head_sha": BINDING_HEAD,
            "current_subject_projection_sha256": record["current_subject_projection_sha256"],
        }
        for fingerprint, record in zip(TARGET_FINGERPRINTS, expected_records, strict=True)
    }
    return {
        "status": "PASS" if not failures else "FAIL",
        "mode": "STAGE_REVIEW" if stage else "COMMITTED",
        "failures": failures,
        "trusted_by_fingerprint": trusted,
        "review_fingerprint_count": len(TARGET_FINGERPRINTS) if not failures and stage else 0,
        "trusted_fingerprint_count": len(trusted),
        "record_count": len(expected_records),
        "failure_fingerprints": list(TARGET_FINGERPRINTS),
        "wildcard_count": 0,
        "future_failure_auto_revalidation_count": 0,
        "committed_only_bytes": not stage,
        "artifact_head": artifact,
        "evaluated_binding_head": evaluated_binding,
        "changed_projection_sections_by_failure": {
            fingerprint: record["changed_projection_sections"]
            for fingerprint, record in zip(TARGET_FINGERPRINTS, expected_records, strict=True)
        },
        "product_touch_count_by_path": {
            path: expected_records[0]["product_path_transitions"][path]["touch_count"]
            for path in TARGET_PRODUCT_PATHS
        },
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path.cwd())
    parser.add_argument("--artifact-head", default="HEAD")
    parser.add_argument("--evaluated-binding-head", default=BINDING_HEAD)
    parser.add_argument("--stage", action="store_true")
    args = parser.parse_args(argv)
    result = validate(
        args.project.resolve(), artifact_head=args.artifact_head,
        evaluated_binding_head=args.evaluated_binding_head, stage=args.stage,
    )
    print(json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2))
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
