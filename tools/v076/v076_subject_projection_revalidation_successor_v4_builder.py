#!/usr/bin/env python3
"""Build the exact committed 48-record/34-preserved SPR successor-v4."""
from __future__ import annotations
import argparse, json, os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
try:
    from . import v076_subject_projection_revalidation_successor_v4 as v4
except ImportError:  # pragma: no cover
    import v076_subject_projection_revalidation_successor_v4 as v4

def build(root: Path, output: Path, *, binding_head: str, created_at: str) -> dict[str, Any]:
    root = root.resolve(); output = output.absolute()
    official = (root / v4.SUCCESSOR_ROOT.rstrip("/")).resolve()
    if output.resolve() != official: raise ValueError("SPR4_OUTPUT_NOT_CANONICAL")
    if os.path.lexists(output): raise ValueError("SPR4_OUTPUT_ALREADY_EXISTS")
    head = str(v4._git(root, "rev-parse", f"{binding_head}^{{commit}}"))
    tree = str(v4._git(root, "rev-parse", f"{head}^{{tree}}"))
    if head != binding_head or not re_full_oid(head): raise ValueError("SPR4_BINDING_HEAD_INVALID")
    drift, preserved, rows, predecessor = v4.target_sets(root, head)
    proof = v4.transition_proof(root)
    schema_raw = (root / v4.SCHEMA_PATH).read_bytes()
    previous = str(predecessor["record_chain_terminal_sha256"])
    bindings: list[dict[str, Any]] = []; artifacts: list[tuple[str, bytes]] = []
    for fp in drift:
        record = v4._record(root, fp, rows[fp], previous, head, tree, proof, created_at)
        raw = v4.canonical_bytes(record); path = v4.expected_record_path(fp)
        bindings.append({"path": path, "record_sha256": v4.sha256_bytes(raw), "record_payload_sha256": record["record_payload_sha256"], "revalidation_id": record["revalidation_id"], "failure_fingerprints": [fp], "prior_record_path": record["prior_record_path"], "prior_record_sha256": record["prior_record_sha256"], "prior_record_payload_sha256": record["prior_record_payload_sha256"], "prior_correction_id": record["prior_correction_id"], "predecessor_revalidation_record_path": record["predecessor_revalidation_record_path"], "predecessor_revalidation_record_sha256": record["predecessor_revalidation_record_sha256"], "predecessor_revalidation_record_payload_sha256": record["predecessor_revalidation_record_payload_sha256"], "predecessor_revalidation_id": record["predecessor_revalidation_id"], "previous_revalidation_chain_sha256": previous})
        artifacts.append((path, raw)); previous = record["record_payload_sha256"]
    manifest = {"schema_version": v4.MANIFEST_SCHEMA_VERSION, "manifest_kind": v4.MANIFEST_KIND, "manifest_id": v4.MANIFEST_ID, "artifact_root_kind": "COMMITTED_SUCCESSOR_ROOT", "authorization_id": v4.AUTHORIZATION_ID, "authorization_base_head_sha": v4.AUTHORIZATION_BASE_HEAD, "prior_epoch_id": v4.PRIOR_EPOCH_ID, "schema_path": v4.SCHEMA_PATH, "schema_sha256": v4.sha256_bytes(schema_raw), "predecessor_manifest_path": v4.PREDECESSOR_MANIFEST_PATH, "predecessor_manifest_sha256": v4.PREDECESSOR_MANIFEST_SHA256, "predecessor_record_count": 82, "predecessor_record_chain_terminal_sha256": predecessor["record_chain_terminal_sha256"], "predecessor_failure_fingerprint_set_sha256": predecessor["failure_fingerprint_set_sha256"], "authority_transition_parent_sha": v4.TRANSITION_PARENT, "authority_transition_commit_sha": v4.TRANSITION_COMMIT, "authority_source_paths": list(v4.AUTHORITY_PATHS), "authority_source_before_blob_sha256_by_path": proof["before_sha256_by_path"], "authority_source_after_blob_sha256_by_path": proof["after_sha256_by_path"], "authority_source_diff_sha256_by_path": proof["diff_sha256_by_path"], "revalidation_binding_head_sha": head, "revalidation_binding_tree_sha": tree, "record_count": 48, "failure_fingerprints": drift, "failure_fingerprint_set_sha256": v4.line_set_sha(drift), "preserved_failure_fingerprints": preserved, "preserved_failure_fingerprint_set_sha256": v4.line_set_sha(preserved), "preserved_record_count": 34, "record_chain_start_sha256": predecessor["record_chain_terminal_sha256"], "record_chain_terminal_sha256": previous, "allowed_invalidation": v4.ALLOWED_INVALIDATION, "future_failure_auto_revalidation": False, "wildcard_count": 0, "created_at": created_at, "creator": Path(__file__).name, "record_bindings": bindings}
    if set(manifest) != v4.MANIFEST_FIELDS: raise ValueError("SPR4_BUILDER_MANIFEST_FIELDS_INVALID")
    output.mkdir(); (output / "records").mkdir()
    for path, raw in artifacts: (output / "records" / Path(path).name).write_bytes(raw)
    (output / "manifest.json").write_bytes(v4.canonical_bytes(manifest))
    return {"status": "PASS", "output": str(output), "binding_head": head, "binding_tree": tree, "drift_record_count": 48, "preserved_record_count": 34, "record_chain_terminal_sha256": previous}

def re_full_oid(value: str) -> bool:
    import re
    return re.fullmatch(r"[0-9a-f]{40}", value) is not None
def main(argv: list[str] | None = None) -> int:
    p=argparse.ArgumentParser(); p.add_argument("--project",type=Path,default=Path.cwd()); p.add_argument("--output",type=Path,required=True); p.add_argument("--binding-head",required=True); p.add_argument("--created-at",default=None); a=p.parse_args(argv)
    try: result=build(a.project,a.output,binding_head=a.binding_head,created_at=a.created_at or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))
    except Exception as e: print(json.dumps({"status":"FAIL","failures":[str(e)]},indent=2)); return 1
    print(json.dumps(result,sort_keys=True,indent=2)); return 0
if __name__ == "__main__": raise SystemExit(main())
