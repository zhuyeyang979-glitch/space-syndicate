"""Apply one exact, dual-reviewed Batch012 Registry append.

This is the only Batch012 authority writer.  It accepts the immutable external
projection and two distinct review receipts, re-runs both review algorithms,
and writes only V076_HISTORICAL_REUSE_REGISTRY.json.  The Supersession Map,
product files, older corrections, and formal STEP11 evidence are not writable.
"""
from __future__ import annotations

import argparse
import base64
import binascii
import json
from pathlib import Path

import v076_reuse_full_convergence_batch010_registry_projection_builder as io
import v076_reuse_full_convergence_batch012_registry_projection_builder as builder
import v076_reuse_full_convergence_batch012_registry_projection_review as reviewer


RECEIPT_SCHEMA = "space_syndicate.v076.batch012_registry_apply_receipt.v1"
REVIEW_FIELDS = frozenset(
    {
        "schema_version",
        "batch_id",
        "candidate_path",
        "candidate_file_sha256",
        "candidate_payload_sha256",
        "binding_head_sha",
        "binding_tree_sha",
        "failure_fingerprint_set_sha256",
        "review_id",
        "reviewer_authority_id",
        "algorithm",
        "checks",
        "findings",
        "p0_count",
        "p1_count",
        "status",
        "official_write_count",
        "receipt_payload_sha256",
    }
)


def _review(
    root: Path,
    candidate: dict,
    candidate_path: Path,
    candidate_raw: bytes,
    path: Path,
) -> tuple[dict, bytes, Path]:
    resolved = path.resolve()
    try:
        resolved.relative_to(root.resolve())
    except ValueError:
        pass
    else:
        raise ValueError("REVIEW_MUST_BE_EXTERNAL")
    if not resolved.is_file() or resolved.is_symlink():
        raise ValueError("REVIEW_MUST_BE_PLAIN_FILE")
    raw = resolved.read_bytes()
    review = reviewer.membership.strict_json_bytes(raw, "BATCH012_REVIEW")
    if raw != io.canonical(review) or set(review) != REVIEW_FIELDS:
        raise ValueError("REVIEW_CANONICAL_CONTRACT_INVALID")
    unsigned = dict(review)
    digest = unsigned.pop("receipt_payload_sha256", None)
    review_id = str(review.get("review_id", ""))
    expected_algorithm = {
        "A": "PRIMARY_EXACT_SEALED_REBUILD",
        "B": "INDEPENDENT_TARGET_DELTA_RECONSTRUCTION",
    }.get(review_id)
    if (
        digest != io.sha(io.canonical(unsigned))
        or review.get("schema_version") != reviewer.SCHEMA
        or review.get("batch_id") != "batch-012"
        or review.get("candidate_path") != candidate_path.as_posix()
        or review.get("candidate_file_sha256") != io.sha(candidate_raw)
        or review.get("candidate_payload_sha256")
        != candidate.get("payload_sha256")
        or review.get("binding_head_sha") != candidate.get("binding_head_sha")
        or review.get("binding_tree_sha") != candidate.get("binding_tree_sha")
        or review.get("failure_fingerprint_set_sha256")
        != builder.FINGERPRINT_SET_SHA
        or review.get("reviewer_authority_id")
        != reviewer.REVIEWERS.get(review_id)
        or review.get("algorithm") != expected_algorithm
        or not isinstance(review.get("checks"), list)
        or not review.get("checks")
        or review.get("findings") != []
        or review.get("p0_count") != 0
        or review.get("p1_count") != 0
        or review.get("status") != "GO"
        or review.get("official_write_count") != 0
    ):
        raise ValueError("REVIEW_BINDING_INVALID:" + review_id)
    return review, raw, resolved


def apply(
    root: Path,
    candidate_path: Path,
    review_paths: list[Path],
    receipt_stage: Path,
) -> dict:
    root = root.resolve()
    writer_path = Path(__file__).resolve()
    writer_relative = writer_path.relative_to(root).as_posix()
    head = io.git(root, "rev-parse", "HEAD^{commit}")
    if io.committed(root, head, writer_relative) != writer_path.read_bytes():
        raise ValueError("WRITER_WORKTREE_DRIFT")
    candidate, candidate_raw, resolved_candidate = reviewer._read_candidate(
        root, candidate_path
    )
    if candidate.get("binding_head_sha") != head:
        raise ValueError("CANDIDATE_NOT_BOUND_TO_CURRENT_HEAD")
    if len(review_paths) != 2 or len({path.resolve() for path in review_paths}) != 2:
        raise ValueError("EXACT_TWO_DISTINCT_REVIEWS_REQUIRED")
    reviews = [
        _review(root, candidate, resolved_candidate, candidate_raw, path)
        for path in review_paths
    ]
    if {review[0]["review_id"] for review in reviews} != {"A", "B"}:
        raise ValueError("EXACT_REVIEWER_SET_REQUIRED")

    # Run the two algorithms again immediately before the only allowed write.
    reviewer._primary(root, candidate)
    reviewer._independent(root, candidate)
    target = candidate["target_registry"]
    try:
        target_bytes = base64.b64decode(
            str(target["target_bytes_base64"]), validate=True
        )
    except (ValueError, binascii.Error) as exc:
        raise ValueError("TARGET_BASE64_INVALID") from exc
    target_path = root / builder.REGISTRY
    before = target_path.read_bytes()
    if (
        io.sha(before) != builder.REGISTRY_SHA
        or io.sha(before) != target.get("source_sha256")
        or io.sha(target_bytes) != target.get("target_sha256")
    ):
        raise ValueError("REGISTRY_SOURCE_OR_TARGET_DRIFT")
    target_path.write_bytes(target_bytes)
    if target_path.read_bytes() != target_bytes:
        raise ValueError("REGISTRY_POSTWRITE_PARITY_INVALID")
    changed = io.git(root, "diff", "--name-only").splitlines()
    if changed != [builder.REGISTRY] or io.git(
        root, "diff", "--cached", "--name-only"
    ):
        raise ValueError("POSTWRITE_SCOPE_INVALID")

    result = {
        "schema_version": RECEIPT_SCHEMA,
        "batch_id": "batch-012",
        "binding_head_sha": candidate["binding_head_sha"],
        "binding_tree_sha": candidate["binding_tree_sha"],
        "candidate_path": resolved_candidate.as_posix(),
        "candidate_file_sha256": io.sha(candidate_raw),
        "candidate_payload_sha256": candidate["payload_sha256"],
        "review_receipts": [
            {
                "path": resolved.as_posix(),
                "review_id": review["review_id"],
                "file_sha256": io.sha(raw),
                "receipt_payload_sha256": review["receipt_payload_sha256"],
            }
            for review, raw, resolved in sorted(
                reviews, key=lambda item: item[0]["review_id"]
            )
        ],
        "target_path": builder.REGISTRY,
        "before_registry_sha256": io.sha(before),
        "after_registry_sha256": io.sha(target_bytes),
        "appended_row_count": 39,
        "old_row_mutation_count": 0,
        "new_owner_count": 0,
        "official_registry_write_count": 1,
        "official_supersession_map_write_count": 0,
        "product_file_mutation_count": 0,
        "append_only": True,
        "status": "PASS",
        "formal_step11_reexecution_count": 0,
        "required_gate_green": False,
        "human_green": False,
        "production_green": False,
    }
    result["receipt_payload_sha256"] = io.sha(io.canonical(result))
    stage = io._stage(root, receipt_stage)
    stage.mkdir(parents=True, exist_ok=False)
    receipt_path = stage / "batch012_registry_apply_receipt.json"
    with receipt_path.open("xb") as stream:
        stream.write(io.canonical(result))
    result["receipt_path"] = receipt_path.as_posix()
    result["receipt_file_sha256"] = io.sha(receipt_path.read_bytes())
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path.cwd())
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--review", type=Path, action="append", required=True)
    parser.add_argument("--receipt-stage", type=Path, required=True)
    args = parser.parse_args()
    try:
        result = apply(
            args.project,
            args.candidate,
            args.review,
            args.receipt_stage,
        )
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))
        return 0
    except ValueError as exc:
        print(
            json.dumps(
                {
                    "status": "FAIL",
                    "batch_id": "batch-012",
                    "error": str(exc),
                    "official_registry_write_count": 0,
                },
                sort_keys=True,
            )
        )
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
