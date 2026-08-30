#!/usr/bin/env python3
"""Build the exact two-record SPR successor-v5 artifact set."""
from __future__ import annotations

import argparse
import json
import os
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

try:
    from . import v076_subject_projection_revalidation_successor_v5 as v5
except ImportError:  # pragma: no cover - direct script execution
    import v076_subject_projection_revalidation_successor_v5 as v5


def full_oid(value: str) -> bool:
    return re.fullmatch(r"[0-9a-f]{40}", value) is not None


def build(
    root: Path,
    output: Path,
    *,
    binding_head: str,
    created_at: str,
) -> dict[str, Any]:
    root = root.resolve()
    output = output.absolute()
    official = (root / v5.SUCCESSOR_ROOT.rstrip("/")).resolve()
    if output.resolve() != official:
        raise ValueError("SPR5_OUTPUT_NOT_CANONICAL")
    if os.path.lexists(output):
        raise ValueError("SPR5_OUTPUT_ALREADY_EXISTS")
    head = str(v5._git(root, "rev-parse", f"{binding_head}^{{commit}}"))
    tree = str(v5._git(root, "rev-parse", f"{head}^{{tree}}"))
    if head != binding_head or not full_oid(head):
        raise ValueError("SPR5_BINDING_HEAD_INVALID")
    fingerprints, predecessor_rows, predecessor_manifest = v5.target_rows(root, head)
    if len(fingerprints) != 2:
        raise ValueError("SPR5_TARGET_CARDINALITY_INVALID")
    proof = v5.transition_proof(root)
    schema_raw = (root / v5.SCHEMA_PATH).read_bytes()
    previous = str(predecessor_manifest["record_chain_terminal_sha256"])
    bindings: list[dict[str, Any]] = []
    artifacts: list[tuple[str, bytes]] = []
    for fingerprint in fingerprints:
        record = v5.make_record(
            root,
            fingerprint,
            predecessor_rows[fingerprint],
            previous,
            head,
            tree,
            proof,
            created_at,
        )
        raw = v5.canonical_bytes(record)
        path = v5.expected_record_path(fingerprint)
        bindings.append(
            {
                "path": path,
                "record_sha256": v5.sha256_bytes(raw),
                "record_payload_sha256": record["record_payload_sha256"],
                "revalidation_id": record["revalidation_id"],
                "failure_fingerprints": [fingerprint],
                "prior_record_path": record["prior_record_path"],
                "prior_record_sha256": record["prior_record_sha256"],
                "prior_record_payload_sha256": record["prior_record_payload_sha256"],
                "prior_correction_id": record["prior_correction_id"],
                "predecessor_revalidation_record_path": record[
                    "predecessor_revalidation_record_path"
                ],
                "predecessor_revalidation_record_sha256": record[
                    "predecessor_revalidation_record_sha256"
                ],
                "predecessor_revalidation_record_payload_sha256": record[
                    "predecessor_revalidation_record_payload_sha256"
                ],
                "predecessor_revalidation_id": record["predecessor_revalidation_id"],
                "previous_revalidation_chain_sha256": previous,
            }
        )
        artifacts.append((path, raw))
        previous = record["record_payload_sha256"]
    manifest = {
        "schema_version": v5.MANIFEST_SCHEMA_VERSION,
        "manifest_kind": v5.MANIFEST_KIND,
        "manifest_id": v5.MANIFEST_ID,
        "artifact_root_kind": "COMMITTED_SUCCESSOR_ROOT",
        "authorization_id": v5.AUTHORIZATION_ID,
        "authorization_base_head_sha": v5.AUTHORIZATION_BASE_HEAD,
        "prior_epoch_id": v5.PRIOR_EPOCH_ID,
        "schema_path": v5.SCHEMA_PATH,
        "schema_sha256": v5.sha256_bytes(schema_raw),
        "predecessor_manifest_path": v5.PREDECESSOR_MANIFEST_PATH,
        "predecessor_manifest_sha256": v5.PREDECESSOR_MANIFEST_SHA256,
        "predecessor_record_count": v5.PREDECESSOR_RECORD_COUNT,
        "predecessor_record_chain_terminal_sha256": predecessor_manifest[
            "record_chain_terminal_sha256"
        ],
        "predecessor_failure_fingerprint_set_sha256": predecessor_manifest[
            "failure_fingerprint_set_sha256"
        ],
        "authority_transition_parent_sha": v5.TRANSITION_PARENT,
        "authority_transition_commit_sha": v5.TRANSITION_COMMIT,
        "authority_source_paths": list(v5.AUTHORITY_PATHS),
        "authority_source_before_blob_sha256_by_path": proof["before_sha256_by_path"],
        "authority_source_after_blob_sha256_by_path": proof["after_sha256_by_path"],
        "authority_source_diff_sha256_by_path": proof["diff_sha256_by_path"],
        "revalidation_binding_head_sha": head,
        "revalidation_binding_tree_sha": tree,
        "record_count": 2,
        "failure_fingerprints": fingerprints,
        "failure_fingerprint_set_sha256": v5.line_set_sha(fingerprints),
        "record_chain_start_sha256": predecessor_manifest["record_chain_terminal_sha256"],
        "record_chain_terminal_sha256": previous,
        "allowed_invalidation": v5.ALLOWED_INVALIDATION,
        "future_failure_auto_revalidation": False,
        "wildcard_count": 0,
        "created_at": created_at,
        "creator": Path(__file__).name,
        "record_bindings": bindings,
    }
    if set(manifest) != v5.MANIFEST_FIELDS:
        raise ValueError("SPR5_BUILDER_MANIFEST_FIELDS_INVALID")
    output.mkdir()
    (output / "records").mkdir()
    for path, raw in artifacts:
        (output / "records" / Path(path).name).write_bytes(raw)
    (output / "manifest.json").write_bytes(v5.canonical_bytes(manifest))
    return {
        "status": "PASS",
        "output": str(output),
        "binding_head": head,
        "binding_tree": tree,
        "record_count": 2,
        "record_chain_terminal_sha256": previous,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path, default=Path.cwd())
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--binding-head", required=True)
    parser.add_argument("--created-at", default=None)
    args = parser.parse_args(argv)
    try:
        result = build(
            args.project,
            args.output,
            binding_head=args.binding_head,
            created_at=args.created_at
            or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        )
    except Exception as error:
        print(json.dumps({"status": "FAIL", "failures": [str(error)]}, indent=2))
        return 1
    print(json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
