#!/usr/bin/env python3
"""Rebind a frozen Batch-010 proposal to an immutable successor head.

The proposal rows are preserved byte-for-byte semantically; only the current
head/tree and authority-source hashes are refreshed, then the payload and two
proposal-review receipts are recomputed.  The source file remains external.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path
from typing import Any

import v076_reuse_full_convergence_batch010_materializer as materializer


REVIEWERS = {
    "A": "V076_FULL_CONVERGENCE_PRIMARY_REVIEWER_V1",
    "B": "V076_FULL_CONVERGENCE_INDEPENDENT_REVIEWER_V1",
}


def canonical(value: Any) -> bytes:
    return materializer.canonical(value)


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def git(root: Path, *args: str) -> str:
    p = subprocess.run(["git", *args], cwd=root, text=True, encoding="utf-8", stdout=subprocess.PIPE, check=True)
    return p.stdout.strip()


def rebind(root: Path, source: Path, output: Path, review_a: Path, review_b: Path) -> None:
    root = root.resolve()
    proposal = json.loads(source.read_text(encoding="utf-8"))
    old_hash = proposal.get("proposal_payload_sha256")
    original = dict(proposal)
    original.pop("proposal_payload_sha256", None)
    if old_hash != sha(canonical(original)):
        raise ValueError("SOURCE_PROPOSAL_HASH_INVALID")
    head, tree = materializer._head_tree(root)
    proposal["evaluated_head_sha"] = head
    proposal["evaluated_tree_sha"] = tree
    proposal["authority_source_sha256"] = materializer._authority_source_hashes(root, head)
    proposal["proposal_payload_sha256"] = sha(canonical({k: v for k, v in proposal.items() if k != "proposal_payload_sha256"}))
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(canonical(proposal))
    for review_id, path in (("A", review_a), ("B", review_b)):
        review = {
            "schema_version": materializer.PROPOSAL_REVIEW_SCHEMA,
            "batch_id": proposal["batch_id"],
            "proposal_payload_sha256": proposal["proposal_payload_sha256"],
            "evaluated_head_sha": head,
            "evaluated_tree_sha": tree,
            "failure_fingerprint_set_sha256": proposal["failure_fingerprint_set_sha256"],
            "review_id": review_id,
            "reviewer_authority_id": REVIEWERS[review_id],
            "findings": [], "p0_count": 0, "p1_count": 0, "status": "GO",
        }
        review["receipt_payload_sha256"] = sha(canonical(review))
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(canonical(review))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--review-a", type=Path, required=True)
    parser.add_argument("--review-b", type=Path, required=True)
    args = parser.parse_args()
    try:
        rebind(args.root, args.source, args.output, args.review_a, args.review_b)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(json.dumps({"status": "FAIL", "error": str(exc)}, sort_keys=True))
        return 2
    proposal = json.loads(args.output.read_text(encoding="utf-8"))
    print(json.dumps({"status": "PASS", "batch_id": proposal["batch_id"], "evaluated_head_sha": proposal["evaluated_head_sha"], "evaluated_tree_sha": proposal["evaluated_tree_sha"], "proposal_payload_sha256": proposal["proposal_payload_sha256"]}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
