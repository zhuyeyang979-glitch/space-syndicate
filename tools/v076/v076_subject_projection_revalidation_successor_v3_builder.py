#!/usr/bin/env python3
"""Generate the exact 25-record Batch-007 projection successor."""

from __future__ import annotations

import argparse
import json
import os
import stat
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

try:
    from . import v076_subject_projection_revalidation_successor_v3 as v3
except ImportError:  # pragma: no cover
    import v076_subject_projection_revalidation_successor_v3 as v3


CREATOR = "v076_subject_projection_revalidation_successor_v3_builder.py"


def _reparse(path: Path) -> bool:
    try:
        info = path.lstat()
    except OSError:
        return False
    return path.is_symlink() or bool(getattr(info, "st_file_attributes", 0) & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400))


def _record(
    root: Path,
    *,
    fingerprint: str,
    identity: dict[str, Any],
    binding_head: str,
    binding_tree: str,
    change_commit: str,
    change_parent: str,
    previous: str,
    proof: dict[str, Any],
    created_at: str,
) -> dict[str, Any]:
    selector = v3._selector(identity)
    prior = identity["subject_projection"]
    prechange = v3._projection(root, change_parent, selector)
    rebound = v3._projection(root, change_commit, selector)
    live = v3._projection(root, binding_head, selector)
    if prior != prechange:
        raise ValueError("SPR3_PRIOR_PRECHANGE_PROJECTION_DRIFT:" + fingerprint)
    if rebound != live:
        raise ValueError("SPR3_REBOUND_LIVE_PROJECTION_DRIFT:" + fingerprint)
    if [key for key in v3.PROJECTION_FIELDS if prechange[key] != rebound[key]] != ["registry_rows"]:
        raise ValueError("SPR3_PROJECTION_CHANGE_SCOPE_INVALID:" + fingerprint)
    added = v3._added_rows(prechange, rebound)
    component = identity["current_component_id"]
    changed_rows = [row for row in added if row.get("component_id") == component]
    if len(added) != 1 or len(changed_rows) != 1 or changed_rows[0].get("change_class") != v3.CHANGE_CLASS:
        raise ValueError("SPR3_CHANGED_ROW_INVALID:" + fingerprint)
    path = identity["current_path"]
    expected_blob = identity["current_blob_sha256"]
    for ref in (change_parent, change_commit, binding_head):
        blob = v3._blob(root, ref, path)
        if blob is None or v3.sha256_bytes(blob) != expected_blob:
            raise ValueError("SPR3_PRODUCT_BLOB_DRIFT:" + fingerprint + ":" + ref)
    result: dict[str, Any] = {
        "schema_version": v3.RECORD_SCHEMA_VERSION,
        "record_kind": v3.RECORD_KIND,
        "revalidation_id": v3.expected_revalidation_id(fingerprint),
        "authorization_id": v3.AUTHORIZATION_ID,
        "authorization_base_head_sha": v3.AUTHORIZATION_BASE_HEAD,
        "prior_epoch_id": v3.PRIOR_EPOCH_ID,
        "failure_fingerprints": [fingerprint],
        "failure_fingerprint_set_sha256": v3.line_set_sha([fingerprint]),
        "prior_invalidations": [v3.PRIOR_INVALIDATION],
        "prior_record_path": v3.PRIOR_RECORD_PATH,
        "prior_record_sha256": v3.PRIOR_RECORD_SHA256,
        "prior_record_payload_sha256": v3.PRIOR_RECORD_PAYLOAD_SHA256,
        "prior_correction_id": v3.PRIOR_CORRECTION_ID,
        "prior_batch_manifest_path": v3.PRIOR_BATCH_PATH,
        "prior_batch_manifest_sha256": v3.PRIOR_BATCH_SHA256,
        "prior_batch_id": v3.PRIOR_BATCH_ID,
        "predecessor_manifest_path": v3.PREDECESSOR_MANIFEST_PATH,
        "predecessor_manifest_sha256": v3.PREDECESSOR_MANIFEST_SHA256,
        "predecessor_record_chain_terminal_sha256": v3.PREDECESSOR_CHAIN_TERMINAL_SHA256,
        "previous_revalidation_chain_sha256": previous,
        "revalidation_binding_head_sha": binding_head,
        "revalidation_binding_tree_sha": binding_tree,
        "authority_selectors": selector,
        "component_id": component,
        "prior_identity_binding": identity,
        "prior_subject_projection": prior,
        "prior_subject_projection_sha256": v3._projection_sha(prior),
        "pre_change_subject_projection": prechange,
        "pre_change_subject_projection_sha256": v3._projection_sha(prechange),
        "rebound_subject_projection": rebound,
        "rebound_subject_projection_sha256": v3._projection_sha(rebound),
        "live_subject_projection": live,
        "live_subject_projection_sha256": v3._projection_sha(live),
        "changed_projection_sections": ["registry_rows"],
        "added_registry_rows": added,
        "authority_transition_proof": proof,
        "future_failure_policy": v3.FUTURE_POLICY,
        "wildcard_count": 0,
        "new_effective_status": "CORRECTED_HISTORICAL_DEBT",
        "revalidation_reason": "BATCH007_TEST_ONLY_CHANGE_CLASS_SUCCESSOR_V3",
        "created_at": created_at,
        "creator": CREATOR,
    }
    result["record_payload_sha256"] = v3._payload_sha(result)
    return result


def build(
    root: Path,
    output: Path,
    *,
    binding_head: str,
    change_commit: str,
    change_parent: str,
    created_at: str,
    committed_root: bool = False,
) -> dict[str, Any]:
    root = root.resolve()
    output = output.absolute()
    if os.path.lexists(output):
        raise ValueError("SPR3_OUTPUT_ALREADY_EXISTS")
    if not output.parent.is_dir() or _reparse(output.parent):
        raise ValueError("SPR3_OUTPUT_PARENT_INVALID")
    inside = False
    try:
        output.resolve().relative_to(root)
        inside = True
    except ValueError:
        pass
    official = root / v3.SUCCESSOR_ROOT.rstrip("/")
    if inside and (not committed_root or output.resolve() != official.resolve()):
        raise ValueError("SPR3_OUTPUT_INSIDE_REPOSITORY")
    if committed_root and not inside:
        raise ValueError("SPR3_COMMITTED_OUTPUT_NOT_CANONICAL")
    if not v3._timestamp(created_at):
        raise ValueError("SPR3_CREATED_AT_INVALID")
    binding_head = str(v3._git(root, "rev-parse", f"{binding_head}^{{commit}}")).strip()
    binding_tree = str(v3._git(root, "rev-parse", f"{binding_head}^{{tree}}")).strip()
    targets, identities = v3._target_rows(root)
    proof = v3.transition_proof(root, change_commit, change_parent, binding_head)
    schema_raw = (root / v3.SCHEMA_PATH).read_bytes()
    predecessor_raw = (root / v3.PREDECESSOR_MANIFEST_PATH).read_bytes()
    if v3.sha256_bytes(predecessor_raw) != v3.PREDECESSOR_MANIFEST_SHA256:
        raise ValueError("SPR3_PREDECESSOR_MANIFEST_DRIFT")
    previous = v3.PREDECESSOR_CHAIN_TERMINAL_SHA256
    records: list[tuple[str, dict[str, Any], bytes]] = []
    bindings: list[dict[str, Any]] = []
    for fingerprint in targets:
        record = _record(root, fingerprint=fingerprint, identity=identities[fingerprint], binding_head=binding_head, binding_tree=binding_tree, change_commit=change_commit, change_parent=change_parent, previous=previous, proof=proof, created_at=created_at)
        raw = v3.canonical_bytes(record)
        path = v3.expected_record_path(fingerprint)
        bindings.append({"path": path, "record_sha256": v3.sha256_bytes(raw), "record_payload_sha256": record["record_payload_sha256"], "revalidation_id": record["revalidation_id"], "failure_fingerprints": [fingerprint], "previous_revalidation_chain_sha256": previous, "prior_record_path": v3.PRIOR_RECORD_PATH, "prior_record_sha256": v3.PRIOR_RECORD_SHA256, "prior_record_payload_sha256": v3.PRIOR_RECORD_PAYLOAD_SHA256, "prior_correction_id": v3.PRIOR_CORRECTION_ID})
        records.append((path, record, raw))
        previous = record["record_payload_sha256"]
    manifest = {
        "schema_version": v3.MANIFEST_SCHEMA_VERSION,
        "manifest_kind": v3.MANIFEST_KIND,
        "manifest_id": "V076-SUBJECT-PROJECTION-REVALIDATION-SUCCESSOR-V3-20260830",
        "artifact_root_kind": "COMMITTED_SUCCESSOR_ROOT" if committed_root else "EXTERNAL_STAGE_REVIEW",
        "authorization_id": v3.AUTHORIZATION_ID,
        "authorization_base_head_sha": v3.AUTHORIZATION_BASE_HEAD,
        "prior_epoch_id": v3.PRIOR_EPOCH_ID,
        "schema_path": v3.SCHEMA_PATH,
        "schema_sha256": v3.sha256_bytes(schema_raw),
        "predecessor_manifest_path": v3.PREDECESSOR_MANIFEST_PATH,
        "predecessor_manifest_sha256": v3.PREDECESSOR_MANIFEST_SHA256,
        "predecessor_record_count": v3.PREDECESSOR_RECORD_COUNT,
        "predecessor_record_chain_terminal_sha256": v3.PREDECESSOR_CHAIN_TERMINAL_SHA256,
        "predecessor_failure_fingerprint_set_sha256": v3.PREDECESSOR_FINGERPRINT_SET_SHA256,
        "authority_transition_parent_sha": change_parent,
        "authority_transition_commit_sha": change_commit,
        "authority_source_paths": sorted([v3.REGISTRY_PATH, v3.SUPERSESSION_PATH]),
        "authority_source_before_blob_sha256_by_path": proof["before_sha256_by_path"],
        "authority_source_after_blob_sha256_by_path": proof["after_sha256_by_path"],
        "authority_source_diff_sha256_by_path": proof["diff_sha256_by_path"],
        "revalidation_binding_head_sha": binding_head,
        "revalidation_binding_tree_sha": binding_tree,
        "record_count": 25,
        "failure_fingerprints": targets,
        "failure_fingerprint_set_sha256": v3.line_set_sha(targets),
        "record_chain_start_sha256": v3.PREDECESSOR_CHAIN_TERMINAL_SHA256,
        "record_chain_terminal_sha256": previous,
        "allowed_invalidation": v3.PRIOR_INVALIDATION,
        "future_failure_auto_revalidation": False,
        "wildcard_count": 0,
        "created_at": created_at,
        "creator": CREATOR,
        "record_bindings": bindings,
    }
    output.mkdir()
    (output / "records").mkdir()
    for path, _document, raw in records:
        (output / "records" / Path(path).name).write_bytes(raw)
    (output / "manifest.json").write_bytes(v3.canonical_bytes(manifest))
    result = v3.validate_manifest_and_records(root, output / "manifest.json", evaluated_head=binding_head, stage_dir=None if committed_root else output)
    if result.get("status") != "PASS":
        raise ValueError("SPR3_BUILT_ARTIFACT_INVALID:" + json.dumps(result.get("failures", [])))
    return {"status": "PASS", "output": str(output), "record_count": 25, "binding_head": binding_head, "binding_tree": binding_tree, "validation": result}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path.cwd())
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--binding-head", required=True)
    parser.add_argument("--change-commit", required=True)
    parser.add_argument("--change-parent", required=True)
    parser.add_argument("--created-at", default=None)
    parser.add_argument("--committed-root", action="store_true")
    args = parser.parse_args(argv)
    try:
        result = build(args.project, args.output, binding_head=args.binding_head, change_commit=args.change_commit, change_parent=args.change_parent, created_at=args.created_at or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"), committed_root=args.committed_root)
    except Exception as error:
        print(json.dumps({"status": "FAIL", "failures": [str(error)]}, ensure_ascii=False, indent=2))
        return 1
    print(json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
