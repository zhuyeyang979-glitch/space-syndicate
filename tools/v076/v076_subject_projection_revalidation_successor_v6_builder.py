#!/usr/bin/env python3
"""Build the exact two-record SPR successor-v6 artifact set."""
from __future__ import annotations

import argparse
import json
import os
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

try:
    from . import v076_subject_projection_revalidation_successor_v6 as v6
except ImportError:  # pragma: no cover - direct script execution
    import v076_subject_projection_revalidation_successor_v6 as v6


def build(
    root: Path,
    output: Path,
    *,
    binding_head: str,
    created_at: str,
) -> dict[str, Any]:
    root = root.resolve()
    output = output.absolute()
    official = (root / v6.SUCCESSOR_ROOT.rstrip("/")).resolve()
    if output.resolve() != official:
        raise ValueError("SPR6_OUTPUT_NOT_CANONICAL")
    if os.path.lexists(output):
        raise ValueError("SPR6_OUTPUT_ALREADY_EXISTS")
    head = str(v6._git(root, "rev-parse", f"{binding_head}^{{commit}}"))
    tree = str(v6._git(root, "rev-parse", f"{head}^{{tree}}"))
    if head != binding_head or re.fullmatch(r"[0-9a-f]{40}", head) is None:
        raise ValueError("SPR6_BINDING_HEAD_INVALID")
    predecessor, predecessor_raw = v6.document(
        root, head, v6.PREDECESSOR_MANIFEST_PATH
    )
    if (
        v6.sha256_bytes(predecessor_raw) != v6.PREDECESSOR_MANIFEST_SHA256
        or predecessor.get("record_chain_terminal_sha256")
        != v6.PREDECESSOR_CHAIN_TERMINAL_SHA256
    ):
        raise ValueError("SPR6_PREDECESSOR_INVALID")
    schema_raw = (root / v6.SCHEMA_PATH).read_bytes()
    current = v6.current_resolution(root, head)
    fingerprints = sorted(v6.RAW_SPECS)
    previous = v6.PREDECESSOR_CHAIN_TERMINAL_SHA256
    bindings: list[dict[str, Any]] = []
    artifacts: list[tuple[str, bytes]] = []
    for fingerprint in fingerprints:
        record = v6.make_record(
            root, fingerprint, previous, head, tree, created_at
        )
        raw = v6.canonical_bytes(record)
        spec = v6.RAW_SPECS[fingerprint]
        path = v6.expected_record_path(fingerprint)
        bindings.append(
            {
                "path": path,
                "record_sha256": v6.sha256_bytes(raw),
                "record_payload_sha256": record["record_payload_sha256"],
                "correction_id": record["correction_id"],
                "failure_fingerprint": fingerprint,
                "raw_failure": spec["raw_failure"],
                "rule_id": v6.RULE_ID,
                "transition_parent_sha": spec["parent_sha"],
                "transition_commit_sha": spec["commit_sha"],
                "previous_correction_chain_sha256": previous,
            }
        )
        artifacts.append((path, raw))
        previous = record["record_payload_sha256"]
    raws = sorted(str(v6.RAW_SPECS[value]["raw_failure"]) for value in fingerprints)
    manifest = {
        "schema_version": v6.MANIFEST_SCHEMA_VERSION,
        "manifest_kind": v6.MANIFEST_KIND,
        "manifest_id": v6.MANIFEST_ID,
        "artifact_root_kind": "COMMITTED_SUCCESSOR_ROOT",
        "authorization_id": v6.AUTHORIZATION_ID,
        "authorization_base_head_sha": v6.AUTHORIZATION_BASE_HEAD,
        "schema_path": v6.SCHEMA_PATH,
        "schema_sha256": v6.sha256_bytes(schema_raw),
        "predecessor_manifest_path": v6.PREDECESSOR_MANIFEST_PATH,
        "predecessor_manifest_sha256": v6.PREDECESSOR_MANIFEST_SHA256,
        "predecessor_record_chain_terminal_sha256": (
            v6.PREDECESSOR_CHAIN_TERMINAL_SHA256
        ),
        "revalidation_binding_head_sha": head,
        "revalidation_binding_tree_sha": tree,
        "record_count": 2,
        "failure_fingerprints": fingerprints,
        "failure_fingerprint_set_sha256": v6.line_set_sha(fingerprints),
        "raw_failures": raws,
        "raw_failure_set_sha256": v6.line_set_sha(raws),
        "record_chain_start_sha256": v6.PREDECESSOR_CHAIN_TERMINAL_SHA256,
        "record_chain_terminal_sha256": previous,
        "component_id": v6.COMPONENT_ID,
        "component_path": v6.COMPONENT_PATH,
        "retired_reuse_id": v6.REUSE_ID,
        "active_successor_reuse_id": v6.ACTIVE_SUCCESSOR_REUSE_ID,
        "current_registry_sha256": current["registry_sha256"],
        "current_product_blob_sha256": current["component_blob_sha256"],
        "detachment_receipt_path": v6.DETACHMENT_RECEIPT_PATH,
        "detachment_receipt_sha256": v6.DETACHMENT_RECEIPT_SHA256,
        "future_failure_auto_correction": False,
        "wildcard_count": 0,
        "created_at": created_at,
        "creator": Path(__file__).name,
        "record_bindings": bindings,
    }
    if set(manifest) != v6.MANIFEST_FIELDS:
        raise ValueError("SPR6_BUILDER_MANIFEST_FIELDS_INVALID")
    output.mkdir()
    (output / "records").mkdir()
    for path, raw in artifacts:
        (output / "records" / Path(path).name).write_bytes(raw)
    (output / "manifest.json").write_bytes(v6.canonical_bytes(manifest))
    return {
        "status": "PASS",
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
    parser.add_argument("--created-at")
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
