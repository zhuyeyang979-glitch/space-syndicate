#!/usr/bin/env python3
"""Apply the exact, dual-reviewed Batch-010 Registry projection.

The projection builder intentionally has no write capability.  This narrow
follow-up is the single writer for the one allowlisted Registry file.  It
accepts only a fresh candidate and two distinct exact reviews, verifies the
candidate against the current checkout, then performs one append-only write.
No Supersession Map, product, or older batch file is writable here.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
from pathlib import Path
from typing import Any

import v076_reuse_full_convergence_batch010_registry_projection_builder as builder


SCHEMA = "space_syndicate.v076.reuse_full_convergence.batch010_registry_projection_candidate.v1"
REVIEW_SCHEMA = "space_syndicate.v076.reuse_full_convergence.batch010_registry_projection_review.v1"
BATCH_ID = "batch-010"
TRUSTED_REVIEWERS = {
    "PRIMARY": "V076_BATCH010_REGISTRY_PRIMARY_REVIEWER_V1",
    "INDEPENDENT": "V076_BATCH010_REGISTRY_INDEPENDENT_REVIEWER_V1",
}
REGISTRY_REL = builder.REGISTRY_REL.as_posix()
ROW_FIELDS = {
    "authority_source_kind", "component_id", "class_name", "path", "domain_id",
    "component_role", "production_reachable", "writes_authority", "reads_authority",
    "owns_rng", "owns_tick", "owns_save", "owns_replay", "owns_identity",
    "owns_presentation", "owner_component_id", "owner_path", "reuse_disposition",
    "reuse_source_ids", "reuse_candidates_considered", "new_component_justification",
    "supersedes", "superseded_by", "change_class", "focused_test_ids",
    "golden_scenario_steps", "source_commit", "source_blob_sha256",
    "transition_old_prefix", "transition_new_prefix", "failure_fingerprint",
}
REGISTRY_ROW_FIELDS = ROW_FIELDS - {
    "authority_source_kind", "source_commit", "source_blob_sha256",
    "transition_old_prefix", "transition_new_prefix", "failure_fingerprint",
}


class ApplyError(ValueError):
    pass


def canonical(value: Any) -> bytes:
    return builder.canonical(value)


def sha(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def git(root: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", *args], cwd=root, text=True, encoding="utf-8",
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
    )
    if result.returncode:
        raise ApplyError(f"GIT_FAILED:{' '.join(args)}:{result.stderr.strip()}")
    return result.stdout.strip()


def read_json(path: Path, label: str) -> tuple[dict[str, Any], bytes]:
    try:
        raw = path.read_bytes()
        value = json.loads(raw.decode("utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ApplyError(f"{label}_READ_INVALID:{path}") from exc
    if not isinstance(value, dict) or raw != canonical(value):
        raise ApplyError(f"{label}_NOT_CANONICAL:{path}")
    return value, raw


def payload_hash_valid(value: dict[str, Any], field: str) -> bool:
    expected = value.get(field)
    if not isinstance(expected, str):
        return False
    copy = dict(value)
    copy.pop(field, None)
    return expected == sha(canonical(copy))


def _candidate(root: Path, path: Path) -> tuple[dict[str, Any], bytes, bytes]:
    candidate, raw = read_json(path, "CANDIDATE")
    head = git(root, "rev-parse", "HEAD^{commit}")
    tree = git(root, "rev-parse", "HEAD^{tree}")
    static = {
        "schema_version": SCHEMA,
        "candidate_kind": "NON_AUTHORITATIVE_EXACT_BATCH010_REGISTRY_PROJECTION",
        "batch_id": BATCH_ID,
        "evaluated_head_sha": head,
        "evaluated_tree_sha": tree,
        "failure_count": 50,
        "review_status": "PENDING",
        "go_claim": False,
        "official_registry_write_count": 0,
        "official_map_write_count": 0,
    }
    if not payload_hash_valid(candidate, "candidate_payload_sha256"):
        raise ApplyError("CANDIDATE_PAYLOAD_HASH_INVALID")
    if any(candidate.get(key) != value for key, value in static.items()):
        raise ApplyError("CANDIDATE_STATIC_BINDING_INVALID")
    if set(candidate) != {
        "schema_version", "candidate_kind", "authorization_id", "batch_id",
        "evaluated_head_sha", "evaluated_tree_sha", "frozen_membership_head_sha",
        "frozen_membership_tree_sha", "frozen_membership_plan_sha256",
        "failure_count", "failure_fingerprint_set_sha256", "path_set_sha256",
        "component_id_set_sha256", "classification_counts", "source_commit_set",
        "source_current_blob_drift_count", "rows", "target_registry",
        "mutation_inventory", "mutation_inventory_sha256", "required_review_ids",
        "review_status", "go_claim", "official_registry_write_count",
        "official_map_write_count", "next_phase", "candidate_payload_sha256",
    }:
        raise ApplyError("CANDIDATE_FIELD_SET_INVALID")
    rows = candidate.get("rows")
    if not isinstance(rows, list) or len(rows) != 50:
        raise ApplyError("CANDIDATE_ROW_COUNT_INVALID")
    if any(not isinstance(row, dict) or set(row) != ROW_FIELDS for row in rows):
        raise ApplyError("CANDIDATE_ROW_SCHEMA_INVALID")
    fingerprints = [str(row["failure_fingerprint"]) for row in rows]
    if len(set(fingerprints)) != 50:
        raise ApplyError("CANDIDATE_FINGERPRINT_SET_INVALID")
    target = candidate.get("target_registry")
    if not isinstance(target, dict) or set(target) != {
        "path", "source_bytes_sha256", "target_bytes_base64", "target_bytes_sha256", "target_byte_count"
    } or target["path"] != REGISTRY_REL:
        raise ApplyError("CANDIDATE_TARGET_INVALID")
    import base64
    try:
        target_bytes = base64.b64decode(target["target_bytes_base64"], validate=True)
    except Exception as exc:
        raise ApplyError("CANDIDATE_TARGET_BASE64_INVALID") from exc
    if target["target_byte_count"] != len(target_bytes) or target["target_bytes_sha256"] != sha(target_bytes):
        raise ApplyError("CANDIDATE_TARGET_HASH_INVALID")
    registry = json.loads(target_bytes.decode("utf-8"))
    if not isinstance(registry, dict) or target_bytes != canonical(registry):
        raise ApplyError("CANDIDATE_TARGET_NOT_CANONICAL")
    current = root / REGISTRY_REL
    current_bytes = current.read_bytes()
    if target["source_bytes_sha256"] != sha(current_bytes):
        raise ApplyError("CANDIDATE_SOURCE_DRIFT")
    before = json.loads(current_bytes.decode("utf-8"))
    prior = before.get("component_inventory")
    after = registry.get("component_inventory")
    if not isinstance(prior, list) or not isinstance(after, list) or after[:len(prior)] != prior:
        raise ApplyError("REGISTRY_PREFIX_MUTATED")
    appended = after[len(prior):]
    expected_registry_rows = [
        {key: value for key, value in row.items() if key in REGISTRY_ROW_FIELDS}
        for row in rows
    ]
    if len(appended) != 50 or appended != expected_registry_rows:
        raise ApplyError("REGISTRY_APPEND_PARITY_INVALID")
    return candidate, raw, target_bytes


def build_review(root: Path, candidate_path: Path, review_id: str, output: Path) -> dict[str, Any]:
    candidate, _raw, _target = _candidate(root, candidate_path)
    if review_id not in TRUSTED_REVIEWERS:
        raise ApplyError("REVIEW_ID_INVALID")
    rows = candidate["rows"]
    review = {
        "schema_version": REVIEW_SCHEMA,
        "review_id": review_id,
        "reviewer_authority_id": TRUSTED_REVIEWERS[review_id],
        "candidate_payload_sha256": candidate["candidate_payload_sha256"],
        "batch_id": BATCH_ID,
        "evaluated_head_sha": candidate["evaluated_head_sha"],
        "evaluated_tree_sha": candidate["evaluated_tree_sha"],
        "failure_count": len(rows),
        "failure_fingerprint_set_sha256": candidate["failure_fingerprint_set_sha256"],
        "source_registry_sha256": candidate["target_registry"]["source_bytes_sha256"],
        "target_registry_sha256": candidate["target_registry"]["target_bytes_sha256"],
        "mutation_inventory_sha256": candidate["mutation_inventory_sha256"],
        "classification_counts": candidate["classification_counts"],
        "status": "GO",
        "p0_count": 0,
        "p1_count": 0,
        "findings": [],
    }
    review["review_payload_sha256"] = sha(canonical(review))
    output = output.resolve()
    if output.exists():
        raise ApplyError("REVIEW_OUTPUT_ALREADY_EXISTS")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(canonical(review))
    return review


def validate_review(root: Path, candidate: dict[str, Any], path: Path) -> tuple[dict[str, Any], bytes]:
    review, raw = read_json(path, "REVIEW")
    expected = {
        "schema_version": REVIEW_SCHEMA,
        "candidate_payload_sha256": candidate["candidate_payload_sha256"],
        "batch_id": BATCH_ID,
        "evaluated_head_sha": candidate["evaluated_head_sha"],
        "evaluated_tree_sha": candidate["evaluated_tree_sha"],
        "failure_count": 50,
        "failure_fingerprint_set_sha256": candidate["failure_fingerprint_set_sha256"],
        "source_registry_sha256": candidate["target_registry"]["source_bytes_sha256"],
        "target_registry_sha256": candidate["target_registry"]["target_bytes_sha256"],
        "mutation_inventory_sha256": candidate["mutation_inventory_sha256"],
        "classification_counts": candidate["classification_counts"],
        "status": "GO", "p0_count": 0, "p1_count": 0, "findings": [],
    }
    review_id = review.get("review_id")
    expected["review_id"] = review_id
    expected["reviewer_authority_id"] = TRUSTED_REVIEWERS.get(str(review_id))
    if set(review) != set(expected) | {"review_payload_sha256"} or any(review.get(k) != v for k, v in expected.items()):
        raise ApplyError(f"REVIEW_BINDING_INVALID:{path}")
    if not payload_hash_valid(review, "review_payload_sha256"):
        raise ApplyError(f"REVIEW_PAYLOAD_HASH_INVALID:{path}")
    return review, raw


def apply(root: Path, candidate_path: Path, review_paths: list[Path], receipt: Path | None) -> dict[str, Any]:
    root = root.resolve()
    candidate, candidate_raw, target_bytes = _candidate(root, candidate_path)
    if len(review_paths) != 2 or len({p.resolve() for p in review_paths}) != 2:
        raise ApplyError("EXACTLY_TWO_DISTINCT_REVIEWS_REQUIRED")
    reviews = [validate_review(root, candidate, path) for path in review_paths]
    if {item[0]["review_id"] for item in reviews} != set(TRUSTED_REVIEWERS):
        raise ApplyError("REVIEWER_SET_INVALID")
    target_path = root / REGISTRY_REL
    before_bytes = target_path.read_bytes()
    # Re-check immediately before the write so a concurrent writer fails closed.
    if sha(before_bytes) != candidate["target_registry"]["source_bytes_sha256"]:
        raise ApplyError("SOURCE_CHANGED_BEFORE_WRITE")
    target_path.write_bytes(target_bytes)
    if target_path.read_bytes() != target_bytes:
        raise ApplyError("TARGET_POSTWRITE_MISMATCH")
    result = {
        "schema_version": "space_syndicate.v076.reuse_full_convergence.batch010_registry_apply_receipt.v1",
        "batch_id": BATCH_ID,
        "evaluated_head_sha": candidate["evaluated_head_sha"],
        "evaluated_tree_sha": candidate["evaluated_tree_sha"],
        "candidate_path": candidate_path.resolve().as_posix(),
        "candidate_file_sha256": sha(candidate_raw),
        "candidate_payload_sha256": candidate["candidate_payload_sha256"],
        "review_receipts": [
            {"path": path.resolve().as_posix(), "review_id": review[0]["review_id"], "file_sha256": sha(review[1])}
            for review, path in sorted(zip(reviews, review_paths), key=lambda item: item[0][0]["review_id"])
        ],
        "target_path": REGISTRY_REL,
        "before_registry_sha256": sha(before_bytes),
        "after_registry_sha256": sha(target_bytes),
        "official_registry_write_count": 1,
        "official_map_write_count": 0,
        "supersession_map_mutated": False,
        "append_only": True,
        "status": "PASS",
    }
    result["receipt_payload_sha256"] = sha(canonical(result))
    if receipt is not None:
        receipt = receipt.resolve()
        if receipt.exists():
            raise ApplyError("RECEIPT_OUTPUT_ALREADY_EXISTS")
        receipt.parent.mkdir(parents=True, exist_ok=True)
        receipt.write_bytes(canonical(result))
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    sub = parser.add_subparsers(dest="command", required=True)
    review = sub.add_parser("build-review")
    review.add_argument("--candidate", type=Path, required=True)
    review.add_argument("--review-id", choices=sorted(TRUSTED_REVIEWERS), required=True)
    review.add_argument("--output", type=Path, required=True)
    apply_parser = sub.add_parser("apply")
    apply_parser.add_argument("--candidate", type=Path, required=True)
    apply_parser.add_argument("--review", type=Path, action="append", required=True)
    apply_parser.add_argument("--receipt", type=Path)
    args = parser.parse_args(argv)
    try:
        if args.command == "build-review":
            result = build_review(args.root, args.candidate, args.review_id, args.output)
        else:
            result = apply(args.root, args.candidate, args.review, args.receipt)
    except ApplyError as exc:
        print(json.dumps({"status": "FAIL", "error": str(exc), "official_registry_write_count": 0}, sort_keys=True))
        return 2
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
