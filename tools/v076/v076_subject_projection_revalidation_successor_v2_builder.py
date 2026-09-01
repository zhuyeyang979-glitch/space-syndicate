#!/usr/bin/env python3
"""Build an external, review-only successor-v2 subject-projection stage.

The builder has no committed-output mode.  The explicitly supplied stage root
must not exist, must be outside the repository, and must not be a link or
reparse point.  It writes exactly one manifest and two records, then validates
the result with the primary successor validator.  A successful stage remains
review evidence only and never contributes committed trust.
"""

from __future__ import annotations

import argparse
import json
import os
import stat
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

try:
    from . import v076_subject_projection_revalidation_successor_v2 as successor
except ImportError:  # pragma: no cover - direct script execution
    import v076_subject_projection_revalidation_successor_v2 as successor


DEFAULT_CREATOR = "v076_subject_projection_revalidation_successor_v2_builder.py"


def _is_reparse(path: Path) -> bool:
    try:
        info = path.lstat()
    except OSError:
        return False
    return bool(getattr(info, "st_file_attributes", 0) & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400))


def _new_stage_target_failures(root: Path, stage_dir: Path) -> list[str]:
    root = root.resolve()
    stage_dir = stage_dir.absolute()
    failures: list[str] = []
    if os.path.lexists(stage_dir):
        failures.append("SPR_SUCCESSOR_STAGE_TARGET_ALREADY_EXISTS")
    parent = stage_dir.parent
    if not parent.is_dir():
        failures.append("SPR_SUCCESSOR_STAGE_PARENT_NOT_DIRECTORY")
        return failures
    if parent.is_symlink() or _is_reparse(parent):
        failures.append("SPR_SUCCESSOR_STAGE_PARENT_REPARSE_POINT")
    candidate = (parent.resolve() / stage_dir.name).resolve()
    try:
        candidate.relative_to(root)
        failures.append("SPR_SUCCESSOR_STAGE_INSIDE_REPOSITORY")
    except ValueError:
        pass
    return sorted(set(failures))


def _record_document(
    root: Path,
    *,
    fingerprint: str,
    binding_head: str,
    binding_tree: str,
    previous_chain_sha256: str,
    transition_proof: dict[str, Any],
    created_at: str,
    creator: str,
) -> dict[str, Any]:
    prior, failures = successor._prior_record(root, binding_head, fingerprint)
    if failures:
        raise ValueError(";".join(failures))
    prior_document = prior["document"]
    identity = prior["identity"]
    prior_head = str(prior_document.get("binding_head_sha", ""))
    prior_projection = successor.subject_projection(root, prior_head, successor.TARGET_SELECTOR)
    pre_change = successor.subject_projection(root, successor.CHANGE_PARENT, successor.TARGET_SELECTOR)
    rebound = successor.subject_projection(root, successor.CHANGE_COMMIT, successor.TARGET_SELECTOR)
    live = successor.subject_projection(root, binding_head, successor.TARGET_SELECTOR)
    added = successor._added_registry_rows(pre_change, rebound)
    record: dict[str, Any] = {
        "schema_version": successor.RECORD_SCHEMA_VERSION,
        "record_kind": successor.RECORD_KIND,
        "revalidation_id": successor.EXPECTED_REVALIDATION_IDS[fingerprint],
        "authorization_id": successor.AUTHORIZATION_ID,
        "authorization_base_head_sha": successor.AUTHORIZATION_BASE_HEAD,
        "prior_epoch_id": successor.PRIOR_EPOCH_ID,
        "failure_fingerprints": [fingerprint],
        "failure_fingerprint_set_sha256": successor.line_set_sha([fingerprint]),
        "prior_invalidations": [successor.ALLOWED_INVALIDATION],
        "prior_record_path": successor.PRIOR_RECORD_PATHS[fingerprint],
        "prior_record_sha256": successor.PRIOR_RECORD_SHA256[fingerprint],
        "prior_record_payload_sha256": successor.PRIOR_RECORD_PAYLOAD_SHA256[fingerprint],
        "prior_correction_id": successor.PRIOR_CORRECTION_IDS[fingerprint],
        "prior_batch_manifest_path": successor.PRIOR_BATCH_PATH,
        "prior_batch_manifest_sha256": successor.PRIOR_BATCH_SHA256,
        "prior_batch_id": "batch-003",
        "predecessor_manifest_path": successor.PREDECESSOR_MANIFEST_PATH,
        "predecessor_manifest_sha256": successor.PREDECESSOR_MANIFEST_SHA256,
        "predecessor_record_chain_terminal_sha256": successor.PREDECESSOR_CHAIN_TERMINAL_SHA256,
        "previous_revalidation_chain_sha256": previous_chain_sha256,
        "revalidation_binding_head_sha": binding_head,
        "revalidation_binding_tree_sha": binding_tree,
        "authority_selectors": successor.TARGET_SELECTOR,
        "authority_selector_sha256": successor.sha256_bytes(successor.canonical_bytes(successor.TARGET_SELECTOR)),
        "component_id": successor.TARGET_COMPONENT,
        "prior_identity_binding": identity,
        "prior_subject_projection": prior_projection,
        "prior_subject_projection_sha256": successor._projection_sha(prior_projection),
        "pre_change_subject_projection": pre_change,
        "pre_change_subject_projection_sha256": successor._projection_sha(pre_change),
        "rebound_subject_projection": rebound,
        "rebound_subject_projection_sha256": successor._projection_sha(rebound),
        "live_subject_projection": live,
        "live_subject_projection_sha256": successor._projection_sha(live),
        "changed_projection_sections": sorted(
            key for key in successor.PROJECTION_FIELDS if pre_change.get(key) != rebound.get(key)
        ),
        "added_registry_rows": added,
        "authority_transition_proof": transition_proof,
        "bound_product_blob_sha256_by_path": {successor.PRODUCT_PATH: successor.PRODUCT_BLOB_SHA256},
        "future_failure_policy": successor.FUTURE_POLICY,
        "wildcard_count": 0,
        "new_effective_status": "CORRECTED_HISTORICAL_DEBT",
        "revalidation_reason": "REGISTRY_AUTHORITY_SOURCE_METADATA_ONLY_SUCCESSOR_V2",
        "created_at": created_at,
        "creator": creator,
    }
    record["record_payload_sha256"] = successor.sha256_bytes(successor.canonical_bytes(record))
    return record


def build_stage(
    root: Path,
    stage_dir: Path,
    *,
    binding_head: str,
    created_at: str,
    creator: str = DEFAULT_CREATOR,
    current_batch_manifest_path: Path | None = None,
    explicit_batch_manifest_paths: Iterable[Path] | None = None,
) -> dict[str, Any]:
    """Create and validate one external review stage; never write official evidence."""
    root = root.resolve()
    stage_dir = stage_dir.absolute()
    failures = _new_stage_target_failures(root, stage_dir)
    if failures:
        raise ValueError(";".join(failures))
    if not successor._timestamp(created_at):
        raise ValueError("SPR_SUCCESSOR_CREATED_AT_INVALID")
    if not isinstance(creator, str) or not creator:
        raise ValueError("SPR_SUCCESSOR_CREATOR_INVALID")
    resolved_head = str(successor._git(root, "rev-parse", f"{binding_head}^{{commit}}"))
    if resolved_head != binding_head or not successor._sha(binding_head, 40):
        raise ValueError("SPR_SUCCESSOR_BINDING_HEAD_NOT_EXACT")
    schema_failures = successor.validate_schema_file(root)
    if schema_failures:
        raise ValueError(";".join(schema_failures))
    predecessor, predecessor_failures = successor._load_predecessor(root, binding_head)
    batch_failures = successor._load_current_batch(root, binding_head)
    transition_proof, transition_failures = successor._authority_transition(root, binding_head)
    if predecessor_failures or batch_failures or transition_failures:
        raise ValueError(";".join(predecessor_failures + batch_failures + transition_failures))
    if not successor.trust_sets_disjoint(predecessor.get("fingerprints", []), successor.TARGET_FINGERPRINTS):
        raise ValueError("SPR_SUCCESSOR_PREDECESSOR_TRUST_OVERLAP")
    binding_tree = str(successor._git(root, "rev-parse", f"{binding_head}^{{tree}}"))
    previous = successor.PREDECESSOR_CHAIN_TERMINAL_SHA256
    record_bindings: list[dict[str, Any]] = []
    artifacts: list[tuple[str, dict[str, Any], bytes]] = []
    for fingerprint in successor.TARGET_FINGERPRINTS:
        record = _record_document(
            root,
            fingerprint=fingerprint,
            binding_head=binding_head,
            binding_tree=binding_tree,
            previous_chain_sha256=previous,
            transition_proof=transition_proof,
            created_at=created_at,
            creator=creator,
        )
        relative = successor.EXPECTED_RECORD_PATHS[fingerprint]
        raw = successor.canonical_bytes(record)
        binding = {
            "path": relative,
            "record_sha256": successor.sha256_bytes(raw),
            "record_payload_sha256": record["record_payload_sha256"],
            "revalidation_id": record["revalidation_id"],
            "failure_fingerprints": record["failure_fingerprints"],
            "prior_record_path": record["prior_record_path"],
            "prior_record_sha256": record["prior_record_sha256"],
            "prior_record_payload_sha256": record["prior_record_payload_sha256"],
            "prior_correction_id": record["prior_correction_id"],
            "previous_revalidation_chain_sha256": record["previous_revalidation_chain_sha256"],
        }
        record_bindings.append(binding)
        artifacts.append((relative, record, raw))
        previous = record["record_payload_sha256"]
    manifest: dict[str, Any] = {
        "schema_version": successor.MANIFEST_SCHEMA_VERSION,
        "manifest_kind": successor.MANIFEST_KIND,
        "manifest_id": successor.MANIFEST_ID,
        "artifact_root_kind": "EXTERNAL_STAGE_REVIEW",
        "authorization_id": successor.AUTHORIZATION_ID,
        "authorization_base_head_sha": successor.AUTHORIZATION_BASE_HEAD,
        "prior_epoch_id": successor.PRIOR_EPOCH_ID,
        "schema_path": successor.SCHEMA_PATH,
        "schema_sha256": successor.SCHEMA_SHA256,
        "predecessor_manifest_path": successor.PREDECESSOR_MANIFEST_PATH,
        "predecessor_manifest_sha256": successor.PREDECESSOR_MANIFEST_SHA256,
        "predecessor_record_count": successor.PREDECESSOR_RECORD_COUNT,
        "predecessor_record_chain_terminal_sha256": successor.PREDECESSOR_CHAIN_TERMINAL_SHA256,
        "predecessor_failure_fingerprint_set_sha256": successor.PREDECESSOR_FINGERPRINT_SET_SHA256,
        "current_batch_manifest_path": successor.CURRENT_BATCH_PATH,
        "current_batch_manifest_sha256": successor.CURRENT_BATCH_SHA256,
        "current_batch_id": successor.CURRENT_BATCH_ID,
        "current_batch_failure_fingerprint_set_sha256": successor.CURRENT_BATCH_FINGERPRINT_SET_SHA256,
        "revalidation_binding_head_sha": binding_head,
        "revalidation_binding_tree_sha": binding_tree,
        "authority_baseline_head_sha": successor.BASELINE_HEAD,
        "authority_baseline_tree_sha": str(successor._git(root, "rev-parse", f"{successor.BASELINE_HEAD}^{{tree}}")),
        "authority_transition_parent_sha": successor.CHANGE_PARENT,
        "authority_transition_parent_tree_sha": str(successor._git(root, "rev-parse", f"{successor.CHANGE_PARENT}^{{tree}}")),
        "authority_transition_commit_sha": successor.CHANGE_COMMIT,
        "authority_transition_commit_tree_sha": str(successor._git(root, "rev-parse", f"{successor.CHANGE_COMMIT}^{{tree}}")),
        "authority_source_paths": list(successor.AUTHORITY_PATHS),
        "authority_source_changed_path_count": 2,
        "authority_source_before_blob_sha256_by_path": successor.BEFORE_SHA256,
        "authority_source_after_blob_sha256_by_path": successor.AFTER_SHA256,
        "authority_source_diff_sha256_by_path": successor.DIFF_SHA256,
        "combined_authority_diff_sha256": successor.COMBINED_DIFF_SHA256,
        "baseline_parent_authority_bytes_equal": True,
        "registry_added_row_count": 1,
        "registry_added_component_id": successor.TARGET_COMPONENT,
        "product_blob_sha256_by_path": {successor.PRODUCT_PATH: successor.PRODUCT_BLOB_SHA256},
        "record_count": 2,
        "failure_fingerprints": list(successor.TARGET_FINGERPRINTS),
        "failure_fingerprint_set_sha256": successor.line_set_sha(successor.TARGET_FINGERPRINTS),
        "record_chain_start_sha256": successor.PREDECESSOR_CHAIN_TERMINAL_SHA256,
        "record_chain_terminal_sha256": previous,
        "allowed_invalidation": successor.ALLOWED_INVALIDATION,
        "future_failure_auto_revalidation": False,
        "wildcard_count": 0,
        "created_at": created_at,
        "creator": creator,
        "record_bindings": record_bindings,
    }
    shape_failures = successor._manifest_shape_failures(manifest)
    if shape_failures:
        raise ValueError(";".join(shape_failures))
    for _relative, record, _raw in artifacts:
        record_failures = successor._record_shape_failures(record)
        if record_failures:
            raise ValueError(";".join(record_failures))
    stage_dir.mkdir()
    records_dir = stage_dir / "records"
    records_dir.mkdir()
    for relative, _record, raw in artifacts:
        target = stage_dir / relative[len(successor.SUCCESSOR_ROOT) :]
        target.write_bytes(raw)
    manifest_path = stage_dir / "manifest.json"
    manifest_path.write_bytes(successor.canonical_bytes(manifest))
    current = (current_batch_manifest_path or root / successor.CURRENT_BATCH_PATH).resolve()
    explicit = list(explicit_batch_manifest_paths or successor.default_explicit_batch_paths(root))
    validation = successor.validate_manifest_and_records(
        root,
        manifest_path,
        evaluated_head=binding_head,
        current_batch_manifest_path=current,
        explicit_batch_manifest_paths=explicit,
        stage_dir=stage_dir,
    )
    if validation.get("status") != "PASS" or validation.get("trusted_by_fingerprint") != {} or validation.get("review_trusted_fingerprint_count") != 2:
        raise ValueError("SPR_SUCCESSOR_BUILT_STAGE_VALIDATION_FAILED:" + json.dumps(validation.get("failures", [])))
    return {
        "status": "PASS",
        "mode": "EXTERNAL_STAGE_REVIEW",
        "stage_dir": str(stage_dir),
        "manifest_path": str(manifest_path),
        "binding_head": binding_head,
        "binding_tree": binding_tree,
        "record_count": 2,
        "failure_fingerprints": list(successor.TARGET_FINGERPRINTS),
        "trusted_by_fingerprint": {},
        "review_trusted_by_fingerprint": validation["review_trusted_by_fingerprint"],
        "validation": validation,
    }


def _now_utc() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path.cwd())
    parser.add_argument("--stage-dir", type=Path, required=True)
    parser.add_argument("--binding-head", required=True, help="Exact 40-hex descendant commit")
    parser.add_argument("--created-at", default=None)
    parser.add_argument("--creator", default=DEFAULT_CREATOR)
    args = parser.parse_args(argv)
    try:
        result = build_stage(
            args.project,
            args.stage_dir,
            binding_head=args.binding_head,
            created_at=args.created_at or _now_utc(),
            creator=args.creator,
        )
    except Exception as error:
        print(json.dumps({"status": "FAIL", "failures": [str(error)]}, ensure_ascii=False, sort_keys=True, indent=2))
        return 1
    print(json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
