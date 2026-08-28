"""Deterministic, append-only planner for V076 full-convergence batches 008-013.

This tool deliberately separates membership planning from authoritative batch
sealing.  ``build-candidate`` writes one non-authoritative review package; it
never writes below the production batch or record roots and never claims GO.
``seal`` accepts that package only after two distinct, exact-byte-bound review
receipts pass.  The sealed package is still an input to the existing primary
and independent batch validators, not a replacement for either validator.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from pathlib import Path
from typing import Any

import v076_reuse_exact_failure_correction_v2_full_convergence as convergence


BASELINE = Path("reports/reuse/correction_v2/epochs/full_convergence_20260827/baseline_raw_failure_report.json")
SUPPLEMENT = Path("reports/reuse/correction_v2/epochs/full_convergence_20260827/descendant_history_supplement_da48a74b_003.json")
RAW = Path("reports/reuse/correction_v2/epochs/full_convergence_20260827/descendant_history_raw_da48a74b_003.json")
SCANNER = Path("tools/v076/v076_reuse_point_inertia_gate.py")
POST_TOUCH = Path("docs/architecture/reuse_corrections/v2/post_touch_revalidation/full_convergence_batch004_20260828_manifest.json")
SPR = Path("docs/architecture/reuse_corrections/v2/subject_projection_revalidation/manifest.json")
HDM = Path("docs/architecture/V076_HISTORICAL_DELTA_METADATA_LEDGER.json")
BATCH_ROOT = Path("docs/architecture/reuse_corrections/v2/batches/full_convergence_20260827")
RECORD_ROOT = Path("docs/architecture/reuse_corrections/v2/records/full_convergence_20260827")

AUTHORITY_INPUTS = (BASELINE, SUPPLEMENT, RAW, SCANNER, POST_TOUCH, SPR, HDM)
COMPONENT_RULE = "HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT"
DYNAMIC_RULE = "HISTORY_DYNAMIC_REFERENCE_UNRESOLVED"
EXPECTED_SIZES = {8: 50, 9: 50, 10: 50, 11: 50, 12: 39, 13: 11}
EXPECTED_FINGERPRINT_SET_SHA256 = {
    8: "276a5082ed1846073ff85a0afa98f4d518bfb6a49906785c4a7037343e6d110e",
    9: "034611fa9bedce94293532ba27c43f0387dfb859e4479fdb128c76395e3bd871",
    10: "121ee606175934acfebcb7bf729b9c49ad469ead0ca2e58afacc41163ff7ba69",
    11: "6d9d0dcb974b7c72175f87888a1d7a4bcbcfe44dda45cd91c56297ea1b34daa1",
    12: "e0df091128327115a7ff339fba6f4a945f5d99e17054561ee1d62ec80eaf5c29",
    13: "44c6c9b08c2ea58f59beab10ffa0cd64bc5280909dc79f14741c129c63459532",
}
PLAN_SCHEMA = "space_syndicate.v076.reuse_full_convergence.batch_plan.v1"
CANDIDATE_SCHEMA = "space_syndicate.v076.reuse_full_convergence.batch_candidate.v1"
SEALED_SCHEMA = "space_syndicate.v076.reuse_full_convergence.batch_candidate_seal.v1"
REVIEW_SCHEMA = "space_syndicate.v076.reuse_full_convergence.external_review_receipt.v1"
CANDIDATE_FIELDS = {
    "schema_version", "candidate_kind", "authorization_id", "batch_id",
    "evaluated_head_sha", "plan_sha256", "failure_count",
    "failure_fingerprints", "failure_fingerprint_set_sha256",
    "authority_inputs", "rows", "required_review_ids", "review_status",
    "go_claim", "official_batch_write_count", "official_record_write_count",
    "next_builder_phase", "candidate_payload_sha256",
}
REVIEW_FIELDS = {
    "schema_version", "review_id", "reviewer_authority_id", "candidate_payload_sha256",
    "batch_id", "evaluated_head_sha", "plan_sha256", "failure_fingerprint_set_sha256",
    "status", "p0_count", "p1_count", "findings", "receipt_payload_sha256",
}
TRUSTED_REVIEWER_AUTHORITIES = {
    "PRIMARY": "V076_FULL_CONVERGENCE_PRIMARY_REVIEWER_V1",
    "INDEPENDENT": "V076_FULL_CONVERGENCE_INDEPENDENT_REVIEWER_V1",
}


class BuilderError(ValueError):
    pass


def canonical(value: Any) -> bytes:
    return convergence.canonical_bytes(value)


def sha(value: bytes) -> str:
    return convergence.sha256_bytes(value)


def line_set_sha(values: list[str]) -> str:
    return sha(("\n".join(sorted(str(value) for value in values)) + "\n").encode("utf-8"))


def git(root: Path, *args: str) -> str:
    process = subprocess.run(
        ["git", *args], cwd=root, text=True, encoding="utf-8",
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
    )
    if process.returncode:
        raise BuilderError(f"GIT_FAILED:{' '.join(args)}:{process.stderr.strip()}")
    return process.stdout.strip()


def strict_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_bytes().decode("utf-8-sig"), object_pairs_hook=convergence._strict_object)
    except Exception as exc:
        raise BuilderError(f"JSON_INVALID:{path.as_posix()}") from exc
    if not isinstance(value, dict):
        raise BuilderError(f"JSON_NOT_OBJECT:{path.as_posix()}")
    return value


def _committed_bytes(root: Path, head: str, relative: Path) -> bytes:
    process = subprocess.run(
        ["git", "show", f"{head}:{relative.as_posix()}"], cwd=root,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
    )
    if process.returncode:
        raise BuilderError(f"AUTHORITY_NOT_COMMITTED:{relative.as_posix()}")
    return process.stdout


def _require_committed_parity(root: Path, head: str, relative: Path) -> bytes:
    payload = _committed_bytes(root, head, relative)
    path = root / relative
    if not path.is_file() or path.read_bytes() != payload:
        raise BuilderError(f"AUTHORITY_WORKTREE_DRIFT:{relative.as_posix()}")
    return payload


def _batch_manifest(batch: int) -> Path:
    return BATCH_ROOT / f"batch-{batch:03d}" / f"batch-{batch:03d}-manifest.json"


def _transition(identity: dict[str, Any]) -> tuple[str, str]:
    old = str(identity.get("transition_old_prefix", ""))
    new = str(identity.get("transition_new_prefix", ""))
    if not old:
        old = str(identity.get("transition_old_sha", ""))[:12]
    if not new:
        new = str(identity.get("transition_new_sha", ""))[:12]
    if not re.fullmatch(r"[0-9a-f]{12}", old) or not re.fullmatch(r"[0-9a-f]{12}", new):
        raise BuilderError("IDENTITY_TRANSITION_UNRESOLVED")
    return old, new


def _load_authority(root: Path, head: str) -> tuple[dict[str, dict[str, Any]], set[str], set[str]]:
    for relative in AUTHORITY_INPUTS:
        _require_committed_parity(root, head, relative)
    baseline = strict_json(root / BASELINE)
    supplement = strict_json(root / SUPPLEMENT)
    identities: dict[str, dict[str, Any]] = {
        key: dict(value)
        for key, value in convergence.authorized_failure_identity_by_fingerprint(baseline).items()
    }
    descendant = supplement.get("identity_binding_by_failure")
    if not isinstance(descendant, dict):
        raise BuilderError("DESCENDANT_IDENTITY_MAP_INVALID")
    for fingerprint, identity in descendant.items():
        if not isinstance(identity, dict):
            raise BuilderError(f"DESCENDANT_IDENTITY_INVALID:{fingerprint}")
        identities[str(fingerprint)] = dict(identity)
    live = supplement.get("live_frozen_historical_fingerprints")
    added = supplement.get("descendant_history_fingerprints")
    if not isinstance(live, list) or not isinstance(added, list):
        raise BuilderError("PRIMARY_AUTHORITY_SET_INVALID")
    primary = {str(value) for value in live} | {str(value) for value in added}
    legacy_result = convergence.verify_legacy_anchor(root)
    if legacy_result.get("status") != "PASS":
        raise BuilderError("LEGACY_ANCHOR_NOT_PASS")
    legacy = {str(value) for value in legacy_result["legacy_corrected_fingerprints"]}
    if len(primary) != 501 or len(legacy) != 12 or primary & legacy != legacy:
        raise BuilderError("FROZEN_PARTITION_CARDINALITY_INVALID")
    if not primary.issubset(identities):
        raise BuilderError("PRIMARY_IDENTITY_COVERAGE_INCOMPLETE")
    return identities, primary, legacy


def derive_plan(root: Path, head_ref: str = "HEAD") -> dict[str, Any]:
    root = root.resolve()
    head = git(root, "rev-parse", f"{head_ref}^{{commit}}")
    if not convergence._is_ancestor(root, convergence.AUTHORIZATION_BASE_HEAD_SHA, head):
        raise BuilderError("HEAD_NOT_AUTHORIZED_DESCENDANT")
    identities, primary, legacy = _load_authority(root, head)
    consumed = set(legacy)
    manifests: dict[int, dict[str, Any]] = {}
    for batch in range(1, 8):
        relative = _batch_manifest(batch)
        _require_committed_parity(root, head, relative)
        manifest = strict_json(root / relative)
        if manifest.get("batch_id") != f"batch-{batch:03d}":
            raise BuilderError(f"PRIOR_BATCH_ID_INVALID:{batch}")
        fingerprints = manifest.get("failure_fingerprints")
        if not isinstance(fingerprints, list):
            raise BuilderError(f"PRIOR_BATCH_FINGERPRINTS_INVALID:{batch}")
        rendered = {str(value) for value in fingerprints}
        if consumed & rendered:
            raise BuilderError(f"PRIOR_BATCH_OVERLAP:{batch}")
        consumed.update(rendered)
        manifests[batch] = manifest
    terminal_pool = primary - consumed
    component = sorted(fp for fp in terminal_pool if identities[fp].get("rule_id") == COMPONENT_RULE)
    dynamic = sorted(fp for fp in terminal_pool if identities[fp].get("rule_id") == DYNAMIC_RULE)
    if len(primary) != 501 or len(consumed) != 251 or len(terminal_pool) != 250:
        raise BuilderError("TERMINAL_POOL_CARDINALITY_INVALID")
    if len(component) != 239 or len(dynamic) != 11 or set(component) | set(dynamic) != terminal_pool:
        raise BuilderError("TERMINAL_POOL_RULE_PARTITION_INVALID")
    chunks = {
        8: component[0:50], 9: component[50:100], 10: component[100:150],
        11: component[150:200], 12: component[200:239], 13: dynamic,
    }
    batches: dict[str, Any] = {}
    for batch, fingerprints in chunks.items():
        transitions: dict[str, int] = {}
        for fp in fingerprints:
            old, new = _transition(identities[fp])
            key = f"{old}->{new}"
            transitions[key] = transitions.get(key, 0) + 1
        if len(fingerprints) != EXPECTED_SIZES[batch]:
            raise BuilderError(f"BATCH_SIZE_INVALID:{batch}")
        fingerprint_set_sha256 = line_set_sha(fingerprints)
        if fingerprint_set_sha256 != EXPECTED_FINGERPRINT_SET_SHA256[batch]:
            raise BuilderError(f"BATCH_FINGERPRINT_SET_AUTHORITY_MISMATCH:{batch}:{fingerprint_set_sha256}")
        batches[f"batch-{batch:03d}"] = {
            "failure_count": len(fingerprints),
            "failure_fingerprints": fingerprints,
            "failure_fingerprint_set_sha256": fingerprint_set_sha256,
            "rule_ids": sorted({str(identities[fp]["rule_id"]) for fp in fingerprints}),
            "transition_counts": {key: transitions[key] for key in sorted(transitions)},
            "terminal_remainder_batch": batch == 13,
        }
    result = {
        "schema_version": PLAN_SCHEMA,
        "authorization_id": convergence.AUTHORIZATION_ID,
        "authorization_base_head_sha": convergence.AUTHORIZATION_BASE_HEAD_SHA,
        "evaluated_head_sha": head,
        "primary_authority_count": len(primary),
        "legacy_count": len(legacy),
        "frozen_batch_001_007_count": len(consumed - legacy),
        "remaining_count": len(terminal_pool),
        "component_remaining_count": len(component),
        "dynamic_remaining_count": len(dynamic),
        "batches": batches,
        "authority_inputs": {
            relative.as_posix(): sha(_committed_bytes(root, head, relative))
            for relative in AUTHORITY_INPUTS
        },
    }
    result["plan_sha256"] = sha(canonical(result))
    return result


def _assert_output_safe(root: Path, staging_root: Path, output: Path) -> None:
    project = root.resolve()
    stage = staging_root.resolve()
    resolved = output.resolve()
    try:
        stage.relative_to(project)
    except ValueError:
        pass
    else:
        raise BuilderError("STAGING_ROOT_MUST_BE_OUTSIDE_PROJECT")
    try:
        resolved.relative_to(stage)
    except ValueError as exc:
        raise BuilderError("OUTPUT_OUTSIDE_EXPLICIT_STAGING_ROOT") from exc
    for forbidden in (root / BATCH_ROOT, root / RECORD_ROOT):
        try:
            resolved.relative_to(forbidden.resolve())
        except ValueError:
            continue
        raise BuilderError("CANDIDATE_OUTPUT_INSIDE_AUTHORITY_ROOT")
    if resolved.exists():
        raise BuilderError("APPEND_ONLY_OUTPUT_ALREADY_EXISTS")
    resolved.parent.mkdir(parents=True, exist_ok=True)


def _exclusive_write(path: Path, payload: bytes) -> None:
    try:
        with path.open("xb") as handle:
            handle.write(payload)
    except FileExistsError as exc:
        raise BuilderError("APPEND_ONLY_OUTPUT_ALREADY_EXISTS") from exc


def build_candidate(root: Path, batch_id: str, staging_root: Path, output: Path, head_ref: str = "HEAD") -> dict[str, Any]:
    match = re.fullmatch(r"batch-(00[8-9]|01[0-3])", batch_id)
    if not match:
        raise BuilderError("BATCH_ID_OUT_OF_AUTHORIZED_RANGE")
    batch = int(batch_id.split("-")[1])
    plan = derive_plan(root, head_ref)
    # Earlier future batches, if present, are authority only when committed and
    # exactly equal to the frozen plan membership.
    for prior in range(8, batch):
        relative = _batch_manifest(prior)
        payload = _require_committed_parity(root.resolve(), plan["evaluated_head_sha"], relative)
        manifest = json.loads(payload.decode("utf-8"), object_pairs_hook=convergence._strict_object)
        expected = plan["batches"][f"batch-{prior:03d}"]["failure_fingerprints"]
        if manifest.get("failure_fingerprints") != expected:
            raise BuilderError(f"FUTURE_PRIOR_MEMBERSHIP_DRIFT:{prior}")
    identities, _, _ = _load_authority(root.resolve(), plan["evaluated_head_sha"])
    selected = plan["batches"][batch_id]["failure_fingerprints"]
    rows = {}
    for fp in selected:
        identity = identities[fp]
        old, new = _transition(identity)
        rows[fp] = {
            "failure_fingerprint": fp,
            "raw_failure": str(identity.get("raw_failure", "")),
            "rule_id": str(identity.get("rule_id", "")),
            "transition_old_prefix": old,
            "transition_new_prefix": new,
            "subject_kind": str(identity.get("subject_kind", "")),
            "subject_value": str(identity.get("subject_value", identity.get("source_path", ""))),
            "classification_status": "REQUIRES_EXACT_AUTHORITY_PROJECTION",
        }
    candidate = {
        "schema_version": CANDIDATE_SCHEMA,
        "candidate_kind": "NON_AUTHORITATIVE_REVIEW_INPUT",
        "authorization_id": convergence.AUTHORIZATION_ID,
        "batch_id": batch_id,
        "evaluated_head_sha": plan["evaluated_head_sha"],
        "plan_sha256": plan["plan_sha256"],
        "failure_count": len(selected),
        "failure_fingerprints": selected,
        "failure_fingerprint_set_sha256": line_set_sha(selected),
        "authority_inputs": plan["authority_inputs"],
        "rows": rows,
        "required_review_ids": ["PRIMARY", "INDEPENDENT"],
        "review_status": "PENDING",
        "go_claim": False,
        "official_batch_write_count": 0,
        "official_record_write_count": 0,
        "next_builder_phase": "PROJECT_EXACT_AUTHORITY_AND_BUILD_RECORDS",
    }
    candidate["candidate_payload_sha256"] = sha(canonical(candidate))
    _assert_output_safe(root.resolve(), staging_root, output)
    _exclusive_write(output.resolve(), canonical(candidate))
    return candidate


def seal_candidate(root: Path, candidate_path: Path, receipts: list[Path], staging_root: Path, output: Path) -> dict[str, Any]:
    candidate = strict_json(candidate_path)
    static_contract = {
        "schema_version": CANDIDATE_SCHEMA,
        "candidate_kind": "NON_AUTHORITATIVE_REVIEW_INPUT",
        "authorization_id": convergence.AUTHORIZATION_ID,
        "required_review_ids": ["PRIMARY", "INDEPENDENT"],
        "review_status": "PENDING",
        "go_claim": False,
        "official_batch_write_count": 0,
        "official_record_write_count": 0,
        "next_builder_phase": "PROJECT_EXACT_AUTHORITY_AND_BUILD_RECORDS",
    }
    if (
        set(candidate) != CANDIDATE_FIELDS
        or any(
            type(candidate.get(field)) is not type(expected)
            or candidate.get(field) != expected
            for field, expected in static_contract.items()
        )
    ):
        raise BuilderError("CANDIDATE_CONTRACT_INVALID")
    payload_hash = candidate.get("candidate_payload_sha256")
    check = dict(candidate); check.pop("candidate_payload_sha256", None)
    if payload_hash != sha(canonical(check)):
        raise BuilderError("CANDIDATE_PAYLOAD_HASH_INVALID")
    fresh = derive_plan(root, "HEAD")
    batch_id = str(candidate.get("batch_id", ""))
    planned = fresh.get("batches", {}).get(batch_id)
    if not isinstance(planned, dict):
        raise BuilderError("CANDIDATE_BATCH_NOT_IN_FRESH_PLAN")
    expected_rows: dict[str, Any] = {}
    identities, _, _ = _load_authority(root.resolve(), fresh["evaluated_head_sha"])
    for fp in planned["failure_fingerprints"]:
        identity = identities[fp]
        old, new = _transition(identity)
        expected_rows[fp] = {
            "failure_fingerprint": fp, "raw_failure": str(identity.get("raw_failure", "")),
            "rule_id": str(identity.get("rule_id", "")), "transition_old_prefix": old,
            "transition_new_prefix": new, "subject_kind": str(identity.get("subject_kind", "")),
            "subject_value": str(identity.get("subject_value", identity.get("source_path", ""))),
            "classification_status": "REQUIRES_EXACT_AUTHORITY_PROJECTION",
        }
    parity = {
        "evaluated_head_sha": fresh["evaluated_head_sha"], "plan_sha256": fresh["plan_sha256"],
        "failure_count": planned["failure_count"], "failure_fingerprints": planned["failure_fingerprints"],
        "failure_fingerprint_set_sha256": line_set_sha(planned["failure_fingerprints"]),
        "rows": expected_rows, "authority_inputs": fresh["authority_inputs"],
    }
    for field, expected in parity.items():
        if candidate.get(field) != expected:
            raise BuilderError(f"CANDIDATE_FRESH_PARITY_INVALID:{field}")
    if len(receipts) != 2:
        raise BuilderError("EXACTLY_TWO_REVIEWS_REQUIRED")
    reviews = []
    for path in receipts:
        review = strict_json(path)
        if set(review) != REVIEW_FIELDS or review.get("schema_version") != REVIEW_SCHEMA:
            raise BuilderError(f"REVIEW_SCHEMA_INVALID:{path.as_posix()}")
        receipt_hash = review.get("receipt_payload_sha256")
        receipt_payload = dict(review); receipt_payload.pop("receipt_payload_sha256", None)
        if receipt_hash != sha(canonical(receipt_payload)):
            raise BuilderError(f"REVIEW_PAYLOAD_HASH_INVALID:{path.as_posix()}")
        if (
            review.get("candidate_payload_sha256") != payload_hash
            or review.get("reviewer_authority_id") != TRUSTED_REVIEWER_AUTHORITIES.get(str(review.get("review_id", "")))
            or review.get("batch_id") != candidate.get("batch_id")
            or review.get("evaluated_head_sha") != candidate.get("evaluated_head_sha")
            or review.get("plan_sha256") != candidate.get("plan_sha256")
            or review.get("failure_fingerprint_set_sha256") != candidate.get("failure_fingerprint_set_sha256")
            or review.get("status") != "GO"
            or type(review.get("p0_count")) is not int or review.get("p0_count") != 0
            or type(review.get("p1_count")) is not int or review.get("p1_count") != 0
            or review.get("findings") != []
        ):
            raise BuilderError(f"REVIEW_NOT_ACCEPTABLE:{path.as_posix()}")
        reviews.append(review)
    ids = {str(review.get("review_id", "")) for review in reviews}
    if ids != {"PRIMARY", "INDEPENDENT"}:
        raise BuilderError("REVIEWER_SET_INVALID")
    authorities = {str(review.get("reviewer_authority_id", "")) for review in reviews}
    if authorities != set(TRUSTED_REVIEWER_AUTHORITIES.values()):
        raise BuilderError("REVIEWER_AUTHORITY_SET_INVALID")
    seal = {
        "schema_version": SEALED_SCHEMA,
        "authorization_id": convergence.AUTHORIZATION_ID,
        "batch_id": candidate["batch_id"],
        "evaluated_head_sha": candidate["evaluated_head_sha"],
        "candidate_path": candidate_path.as_posix(),
        "candidate_payload_sha256": payload_hash,
        "review_receipts": [
            {"path": path.as_posix(), "sha256": sha(path.read_bytes()), "review_id": review["review_id"]}
            for path, review in sorted(zip(receipts, reviews), key=lambda item: str(item[1]["review_id"]))
        ],
        "review_status": "DUAL_REVIEW_PASS",
        "go_claim": True,
        "official_batch_write_count": 0,
        "official_record_write_count": 0,
        "next_builder_phase": "MATERIALIZE_AND_RUN_EXISTING_PRIMARY_AND_INDEPENDENT_VALIDATORS",
    }
    seal["seal_payload_sha256"] = sha(canonical(seal))
    _assert_output_safe(root.resolve(), staging_root, output)
    _exclusive_write(output.resolve(), canonical(seal))
    return seal


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path.cwd())
    parser.add_argument("--head-ref", default="HEAD")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("plan")
    candidate = sub.add_parser("build-candidate")
    candidate.add_argument("--batch-id", required=True)
    candidate.add_argument("--staging-root", type=Path, required=True)
    candidate.add_argument("--output", type=Path, required=True)
    seal = sub.add_parser("seal")
    seal.add_argument("--candidate", type=Path, required=True)
    seal.add_argument("--review", type=Path, action="append", required=True)
    seal.add_argument("--staging-root", type=Path, required=True)
    seal.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == "plan":
            result = derive_plan(args.project, args.head_ref)
        elif args.command == "build-candidate":
            result = build_candidate(args.project, args.batch_id, args.staging_root, args.output, args.head_ref)
        elif args.command == "seal":
            result = seal_candidate(args.project, args.candidate, args.review, args.staging_root, args.output)
        else:
            raise BuilderError("COMMAND_UNREACHABLE")
    except BuilderError as exc:
        print(json.dumps({"status": "FAIL", "failure": str(exc)}, sort_keys=True))
        return 1
    print(json.dumps({"status": "PASS", "result": result}, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
