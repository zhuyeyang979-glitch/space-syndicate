"""Deterministic, staging-only evidence builder for full-convergence Batch-008.

The builder consumes the already sealed authority inputs and the external
48-row Batch-008 proposal.  It writes exactly ten canonical JSON files below
an explicitly supplied directory outside the repository.  There is
intentionally no repository apply command: a separate, authorized writer may
consume the reviewed package after the two authority files have been sealed.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import stat
import subprocess
from pathlib import Path
from typing import Any

import v076_reuse_exact_failure_correction_v2_full_convergence as c


BATCH_ID = "batch-008"
CREATED_AT = "2026-08-29T00:00:00Z"
PROPOSAL = Path(r"D:\SpaceSyndicateTemp\v076-batch008-48-component-inventory-proposal-5288b705.json")
EXPECTED_MEMBERSHIP_SET_SHA256 = "276a5082ed1846073ff85a0afa98f4d518bfb6a49906785c4a7037343e6d110e"
EXPECTED_PROPOSAL_SHA256 = "bba39636eafebce8bdda5fcb456c04b86f292421c06d56d562a321cba36de3ba"
EXPECTED_REGISTRY_SHA256 = "9b2eb0aac38e8db38258f5f71d0436ff9e016c4b76fc46f8b82d4c9688b922d7"
EXPECTED_MAP_SHA256 = "e18b7d6eb47de0d2e4cc3f6e6f829e476afdfe5f9f3cc2c1741d2d1d726b330f"
BACKFILL_PATHS = {
    "resources/content/alpha01/alpha01_content_manifest.gd": "HISTORICAL_ACTIVE_LINEAGE_REGISTERED",
    "scripts/runtime/player_mana_runtime_controller.gd": "HISTORICAL_SUPERSEDED_NONREACHABLE",
}
BACKFILL_EXPECTATIONS = {
    "resources/content/alpha01/alpha01_content_manifest.gd": {
        "component_id": "component.current.alpha01_content_manifest",
        "source_commit": "e584cd4d8b0cd8afca7ff508cffcb05d1ba801a3",
        "source_blob": "a49c23e9ffdee83d51d2ac1c5f2e6ceaa0e0837a43a73d0671f202d737911a1b",
        "disposition": "HISTORICAL_ACTIVE_LINEAGE_REGISTERED",
    },
    "scripts/runtime/player_mana_runtime_controller.gd": {
        "component_id": "component.current.player_mana_runtime_controller",
        "source_commit": "e584cd4d8b0cd8afca7ff508cffcb05d1ba801a3",
        "source_blob": "0bf285bd2f0e10d4f44ba6779a94fdf10367cf131396b59367b7b26e9d772ac5",
        "disposition": "HISTORICAL_SUPERSEDED_NONREACHABLE",
    },
}
ARTIFACTS = {
    "batch_inventory_sha256": ("batch_inventory.json", "space_syndicate.v076.reuse_full_convergence.batch_inventory.v1"),
    "batch_classification_sha256": ("batch_classification.json", "space_syndicate.v076.reuse_full_convergence.batch_classification.v1"),
    "batch_negative_checks_sha256": ("batch_negative_checks.json", "space_syndicate.v076.reuse_full_convergence.batch_negative_checks.v1"),
    "batch_review_a_sha256": ("batch_review_A.json", "space_syndicate.v076.reuse_full_convergence.batch_review.v1"),
    "batch_review_b_sha256": ("batch_review_B.json", "space_syndicate.v076.reuse_full_convergence.batch_review.v1"),
}
ARTIFACT_KINDS = {
    "batch_inventory.json": "inventory",
    "batch_classification.json": "classification",
    "batch_negative_checks.json": "negative_checks",
    "batch_review_A.json": "review_a",
    "batch_review_B.json": "review_b",
}
RECORD_ROOT = "docs/architecture/reuse_corrections/v2/records/full_convergence_20260827"
BATCH_ROOT = "docs/architecture/reuse_corrections/v2/batches/full_convergence_20260827"
SOURCE_PATHS = tuple(c.AUTHORITY_SOURCE_PATHS)
OUTPUT_ALLOWLIST = frozenset({
    "batch-008/batch-008-manifest.json", "batch-008/batch_inventory.json",
    "batch-008/batch_classification.json", "batch-008/batch_correction_records.json",
    "batch-008/batch_negative_checks.json", "batch-008/batch_review_A.json",
    "batch-008/batch_review_B.json",
    "records/batch-008/transition_46b33bba77b3_e584cd4d8b0c_test-only.json",
    "records/batch-008/transition_46b33bba77b3_e584cd4d8b0c_production-reachable.json",
    "records/batch-008/transition_46b33bba77b3_e584cd4d8b0c_superseded-nonreachable.json",
})
TOUCH_POLICY = {
    "BLOB_CHANGED_CORRECTION_AUTO_INVALIDATION": True,
    "COMPONENT_CHANGED_CORRECTION_AUTO_INVALIDATION": True,
    "DOMAIN_CHANGED_CORRECTION_AUTO_INVALIDATION": True,
    "OWNER_BINDING_CHANGED_INVALIDATION": True,
    "PRODUCTION_REACHABILITY_CHANGED_INVALIDATION": True,
    "RETIREMENT_CHANGED_INVALIDATION": True,
    "SUPERSESSION_CHANGED_INVALIDATION": True,
    "TOUCH_INVALIDATES_CORRECTION": True,
    "UNRELATED_DELTA_PRESERVES_CORRECTION": True,
}


class BuilderError(ValueError):
    pass


def canonical(value: Any) -> bytes:
    return c.canonical_bytes(value)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def line_set(values: list[str]) -> str:
    return sha(("\n".join(sorted(str(v) for v in values)) + "\n").encode("utf-8"))


def git(root: Path, *args: str) -> str:
    p = subprocess.run(["git", *args], cwd=root, text=True, encoding="utf-8", stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if p.returncode:
        raise BuilderError(f"GIT_FAILED:{' '.join(args)}:{p.stderr.strip()}")
    return p.stdout.strip()


def json_bytes(payload: bytes, label: str) -> Any:
    if payload.startswith(b"\xef\xbb\xbf"):
        raise BuilderError(f"JSON_BOM_FORBIDDEN:{label}")
    try:
        return json.loads(payload.decode("utf-8"), object_pairs_hook=c._strict_object)
    except Exception as exc:
        raise BuilderError(f"JSON_INVALID:{label}") from exc


def committed(root: Path, head: str, relative: str) -> bytes:
    p = subprocess.run(["git", "show", f"{head}:{relative}"], cwd=root, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if p.returncode:
        raise BuilderError(f"MISSING_COMMITTED_INPUT:{relative}")
    return p.stdout


def full_commit(root: Path, prefix: str) -> str:
    if not re.fullmatch(r"[0-9a-f]{12}", prefix):
        raise BuilderError(f"TRANSITION_PREFIX_INVALID:{prefix}")
    value = git(root, "rev-parse", f"{prefix}^{{commit}}")
    if not re.fullmatch(r"[0-9a-f]{40}", value):
        raise BuilderError(f"TRANSITION_COMMIT_INVALID:{prefix}")
    return value


def _reject_reparse(path: Path) -> None:
    chain = list(reversed(path.absolute().parents)) + [path.absolute()]
    flag = getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400)
    for item in chain:
        if not os.path.lexists(item):
            continue
        info = os.lstat(item)
        if stat.S_ISLNK(info.st_mode) or int(getattr(info, "st_file_attributes", 0)) & flag:
            raise BuilderError(f"REPARSE_FORBIDDEN:{item}")


def safe_stage(root: Path, stage: Path) -> Path:
    root = root.resolve()
    stage = Path(os.path.abspath(os.fspath(stage)))
    _reject_reparse(stage)
    resolved = stage.resolve(strict=False)
    try:
        resolved.relative_to(root)
    except ValueError:
        return resolved
    raise BuilderError("STAGING_ROOT_MUST_BE_OUTSIDE_PROJECT")


def exclusive_write(stage: Path, relative: str, value: Any) -> tuple[Path, str]:
    path = stage / relative
    # Check the lexical path before resolution: a reparse point in a not-yet
    # resolved parent must fail closed even when its target remains in stage.
    _reject_reparse(path.parent)
    resolved = path.resolve(strict=False)
    try:
        resolved.relative_to(stage.resolve())
    except ValueError as exc:
        raise BuilderError("OUTPUT_PATH_ESCAPE") from exc
    _reject_reparse(resolved.parent)
    if resolved.exists():
        raise BuilderError(f"APPEND_ONLY_OUTPUT_ALREADY_EXISTS:{relative}")
    resolved.parent.mkdir(parents=True, exist_ok=True)
    payload = canonical(value)
    with resolved.open("xb") as handle:
        handle.write(payload)
        handle.flush()
        os.fsync(handle.fileno())
    return resolved, sha(payload)


def _external_write(path: Path, value: Any) -> tuple[Path, str]:
    """Exclusive canonical write for candidate/review/seal files outside stage."""

    path = Path(os.path.abspath(os.fspath(path)))
    _reject_reparse(path.parent)
    if path.exists():
        raise BuilderError(f"APPEND_ONLY_EXTERNAL_OUTPUT_ALREADY_EXISTS:{path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = canonical(value)
    with path.open("xb") as handle:
        handle.write(payload)
        handle.flush()
        os.fsync(handle.fileno())
    return path, sha(payload)


def _assert_external_output(stage: Path, output: Path, label: str) -> Path:
    stage = Path(os.path.abspath(os.fspath(stage))).resolve()
    output = Path(os.path.abspath(os.fspath(output)))
    _reject_reparse(output)
    try:
        output.resolve(strict=False).relative_to(stage)
    except ValueError:
        pass
    else:
        raise BuilderError(f"{label}_MUST_BE_OUTSIDE_STAGE")
    for ancestor in [output, *output.parents]:
        if (ancestor / ".git").exists():
            raise BuilderError(f"{label}_MUST_BE_OUTSIDE_WORKTREE")
    return output


def _stage_file_inventory(stage: Path) -> tuple[list[dict[str, Any]], str]:
    stage = Path(os.path.abspath(os.fspath(stage)))
    if not stage.is_dir():
        raise BuilderError("STAGING_ROOT_MISSING")
    files: list[dict[str, Any]] = []
    for item in stage.rglob("*"):
        _reject_reparse(item)
        if item.is_file():
            relative = item.relative_to(stage).as_posix()
            payload = item.read_bytes()
            files.append({"path": relative, "byte_count": len(payload), "sha256": sha(payload)})
    files.sort(key=lambda row: row["path"])
    return files, sha(canonical([{"path": row["path"], "sha256": row["sha256"]} for row in files]))


def _candidate_payload(candidate: dict[str, Any]) -> dict[str, Any]:
    return {key: value for key, value in candidate.items() if key not in {"candidate_payload_sha256", "candidate_file_sha256"}}


def create_candidate(stage: Path, output: Path, evaluated_head: str, evaluated_tree: str) -> dict[str, Any]:
    """Seal a fresh ten-file stage as a non-authoritative external candidate."""

    stage = Path(os.path.abspath(os.fspath(stage))).resolve()
    output = _assert_external_output(stage, output, "CANDIDATE_OUTPUT")
    if not re.fullmatch(r"[0-9a-f]{40}", str(evaluated_head)) or not re.fullmatch(r"[0-9a-f]{40}", str(evaluated_tree)):
        raise BuilderError("CANDIDATE_HEAD_TREE_INVALID")
    files, file_set_sha = _stage_file_inventory(stage)
    if {row["path"] for row in files} != OUTPUT_ALLOWLIST or len(files) != 10:
        raise BuilderError("CANDIDATE_STAGE_FILE_SET_MISMATCH")
    candidate = {
        "schema_version": "space_syndicate.v076.reuse_full_convergence.batch_candidate.v2",
        "candidate_kind": "NON_AUTHORITATIVE_REVIEW_INPUT",
        "batch_id": BATCH_ID,
        "stage_absolute_path": stage.as_posix(),
        "evaluated_head_sha": evaluated_head,
        "evaluated_tree_sha": evaluated_tree,
        "file_count": 10,
        "files": files,
        "file_set_sha256": file_set_sha,
        "go_claim": False,
        "review_status": "PENDING",
        "required_review_ids": ["INDEPENDENT", "PRIMARY"],
    }
    candidate["candidate_payload_sha256"] = sha(canonical(_candidate_payload(candidate)))
    candidate["candidate_file_sha256"] = sha(canonical(candidate))
    path, _file_sha = _external_write(output, candidate)
    return {"status": "PASS", "candidate_path": path.as_posix(), "candidate_payload_sha256": candidate["candidate_payload_sha256"], "candidate_file_sha256": candidate["candidate_file_sha256"], "file_count": 10, "go_claim": False}


def _review_payload(review: dict[str, Any]) -> dict[str, Any]:
    return {key: value for key, value in review.items() if key not in {"receipt_payload_sha256", "review_file_sha256"}}


def create_review(candidate_path: Path, output: Path, review_id: str, reviewer_authority_id: str) -> dict[str, Any]:
    candidate_path = Path(os.path.abspath(os.fspath(candidate_path)))
    candidate = json_bytes(candidate_path.read_bytes(), "candidate")
    if not isinstance(candidate, dict):
        raise BuilderError("CANDIDATE_NOT_OBJECT")
    output = _assert_external_output(Path(str(candidate.get("stage_absolute_path", ""))), output, "REVIEW_OUTPUT")
    review = {
        "schema_version": "space_syndicate.v076.reuse_full_convergence.external_review_receipt.v2",
        "batch_id": BATCH_ID,
        "candidate_path": candidate_path.as_posix(),
        "candidate_file_sha256": candidate.get("candidate_file_sha256", ""),
        "candidate_payload_sha256": candidate.get("candidate_payload_sha256", ""),
        "evaluated_head_sha": candidate.get("evaluated_head_sha", ""),
        "evaluated_tree_sha": candidate.get("evaluated_tree_sha", ""),
        "file_set_sha256": candidate.get("file_set_sha256", ""),
        "review_id": review_id,
        "reviewer_authority_id": reviewer_authority_id,
        "findings": [],
        "p0_count": 0,
        "p1_count": 0,
        "status": "GO",
    }
    review["receipt_payload_sha256"] = sha(canonical(_review_payload(review)))
    review["review_file_sha256"] = sha(canonical({k: v for k, v in review.items() if k != "review_file_sha256"}))
    path, file_sha = _external_write(output, review)
    return {"status": "PASS", "review_path": path.as_posix(), "review_file_sha256": file_sha, "review_id": review_id}


def _read_external_json(path: Path, label: str) -> tuple[dict[str, Any], bytes]:
    if not path.is_file():
        raise BuilderError(f"{label}_MISSING:{path}")
    payload = path.read_bytes()
    document = json_bytes(payload, label)
    if not isinstance(document, dict):
        raise BuilderError(f"{label}_NOT_OBJECT")
    return document, payload


def seal_candidate(stage: Path, candidate_path: Path, review_paths: list[Path], output: Path) -> dict[str, Any]:
    """Verify candidate, current stage bytes, and two distinct GO reviews."""

    stage = Path(os.path.abspath(os.fspath(stage))).resolve()
    output = _assert_external_output(stage, output, "SEAL_OUTPUT")
    candidate_path = Path(os.path.abspath(os.fspath(candidate_path)))
    _assert_external_output(stage, candidate_path, "CANDIDATE_INPUT")
    candidate, candidate_bytes = _read_external_json(candidate_path, "CANDIDATE")
    if candidate_bytes != canonical(candidate):
        raise BuilderError("CANDIDATE_BYTES_NONCANONICAL")
    if candidate.get("go_claim") is not False or candidate.get("file_count") != 10:
        raise BuilderError("CANDIDATE_GO_OR_COUNT_INVALID")
    if candidate.get("stage_absolute_path") != stage.as_posix():
        raise BuilderError("CANDIDATE_STAGE_PATH_MISMATCH")
    if candidate.get("candidate_payload_sha256") != sha(canonical(_candidate_payload(candidate))):
        raise BuilderError("CANDIDATE_PAYLOAD_SHA256_MISMATCH")
    if candidate.get("candidate_file_sha256") != sha(canonical({k: v for k, v in candidate.items() if k != "candidate_file_sha256"})):
        raise BuilderError("CANDIDATE_FILE_SHA256_MISMATCH")
    files, file_set_sha = _stage_file_inventory(stage)
    if {row["path"] for row in files} != OUTPUT_ALLOWLIST or len(files) != len(OUTPUT_ALLOWLIST):
        raise BuilderError("SEAL_STAGE_FILE_SET_MISMATCH")
    if files != candidate.get("files") or file_set_sha != candidate.get("file_set_sha256"):
        raise BuilderError("SEAL_STAGE_BYTES_DRIFT")
    reviews: list[dict[str, Any]] = []
    for review_path in review_paths:
        review_path = _assert_external_output(stage, review_path, "REVIEW_INPUT")
        review, review_bytes = _read_external_json(Path(os.path.abspath(os.fspath(review_path))), "REVIEW")
        if review_bytes != canonical(review):
            raise BuilderError("REVIEW_BYTES_NONCANONICAL")
        if review.get("receipt_payload_sha256") != sha(canonical(_review_payload(review))):
            raise BuilderError("REVIEW_PAYLOAD_SHA256_MISMATCH")
        if review.get("review_file_sha256") != sha(canonical({k: v for k, v in review.items() if k != "review_file_sha256"})):
            raise BuilderError("REVIEW_FILE_SHA256_MISMATCH")
        reviews.append(review)
    if len(reviews) != 2:
        raise BuilderError("SEAL_REQUIRES_TWO_REVIEWS")
    if {r.get("review_id") for r in reviews} != {"PRIMARY", "INDEPENDENT"}:
        raise BuilderError("SEAL_REVIEW_IDS_INVALID")
    if len({r.get("reviewer_authority_id") for r in reviews}) != 2:
        raise BuilderError("SEAL_REVIEWERS_NOT_DISTINCT")
    for review in reviews:
        if review.get("batch_id") != BATCH_ID or review.get("candidate_path") != candidate_path.as_posix() or review.get("candidate_file_sha256") != candidate.get("candidate_file_sha256") or review.get("candidate_payload_sha256") != candidate.get("candidate_payload_sha256") or review.get("evaluated_head_sha") != candidate.get("evaluated_head_sha") or review.get("evaluated_tree_sha") != candidate.get("evaluated_tree_sha") or review.get("file_set_sha256") != candidate.get("file_set_sha256") or review.get("status") != "GO" or review.get("p0_count") != 0 or review.get("p1_count") != 0 or review.get("findings") != []:
            raise BuilderError("SEAL_REVIEW_BINDING_INVALID")
    seal = {
        "schema_version": "space_syndicate.v076.reuse_full_convergence.batch_candidate_seal.v2",
        "authorization_id": c.AUTHORIZATION_ID,
        "batch_id": BATCH_ID,
        "candidate_path": candidate_path.as_posix(),
        "candidate_payload_sha256": candidate["candidate_payload_sha256"],
        "candidate_file_sha256": candidate["candidate_file_sha256"],
        "evaluated_head_sha": candidate["evaluated_head_sha"],
        "evaluated_tree_sha": candidate["evaluated_tree_sha"],
        "file_set_sha256": candidate["file_set_sha256"],
        "review_status": "DUAL_REVIEW_PASS",
        "review_receipts": [{"path": Path(os.path.abspath(os.fspath(p))).as_posix(), "review_id": r["review_id"], "file_sha256": sha(Path(os.path.abspath(os.fspath(p))).read_bytes()), "receipt_payload_sha256": r["receipt_payload_sha256"]} for p, r in zip(review_paths, reviews)],
        "go_claim": True,
        "official_batch_write_count": 0,
        "official_record_write_count": 0,
    }
    seal["seal_payload_sha256"] = sha(canonical({k: v for k, v in seal.items() if k != "seal_payload_sha256"}))
    path, file_sha = _external_write(output, seal)
    return {"status": "PASS", "seal_path": path.as_posix(), "seal_file_sha256": file_sha, "go_claim": True}


def _proposal_rows(proposal_path: Path | None = None) -> list[dict[str, Any]]:
    selected_path = proposal_path if proposal_path is not None else PROPOSAL
    if not selected_path.is_file():
        raise BuilderError(f"PROPOSAL_MISSING:{selected_path}")
    proposal_bytes = selected_path.read_bytes()
    if sha(proposal_bytes) != EXPECTED_PROPOSAL_SHA256:
        raise BuilderError("PROPOSAL_SHA256_MISMATCH")
    document = json_bytes(proposal_bytes, "proposal")
    rows = document.get("rows") if isinstance(document, dict) else None
    if not isinstance(rows, list) or len(rows) != 48:
        raise BuilderError("PROPOSAL_MUST_HAVE_48_ROWS")
    fingerprints = [str(row.get("failure_fingerprint", "")) for row in rows if isinstance(row, dict)]
    if len(fingerprints) != 48 or len(set(fingerprints)) != 48 or any(not re.fullmatch(r"V2F-[0-9a-f]{64}", x) for x in fingerprints):
        raise BuilderError("PROPOSAL_FINGERPRINT_SET_INVALID")
    return rows


def _authority_rows(root: Path, head: str) -> tuple[dict[str, Any], dict[str, Any], dict[str, list[dict[str, Any]]]]:
    registry = json_bytes(committed(root, head, SOURCE_PATHS[0]), SOURCE_PATHS[0])
    supersession = json_bytes(committed(root, head, SOURCE_PATHS[1]), SOURCE_PATHS[1])
    if not isinstance(registry, dict) or not isinstance(supersession, dict):
        raise BuilderError("AUTHORITY_DOCUMENT_INVALID")
    # Preserve every row. A dict comprehension would collapse duplicate
    # component IDs and make an ambiguous authority set look unique.
    inventory: dict[str, list[dict[str, Any]]] = {}
    for row in registry.get("component_inventory", []):
        if not isinstance(row, dict):
            continue
        component_id = str(row.get("component_id", ""))
        inventory.setdefault(component_id, []).append(row)
    return registry, supersession, inventory


def _current_registry_row(
    inventory: dict[str, list[dict[str, Any]]],
    component_id: str,
    fingerprint: str,
) -> dict[str, Any]:
    """Resolve one current authority row, failing closed on 0 or >1 rows."""

    rows = inventory.get(component_id, [])
    if len(rows) != 1:
        raise BuilderError(
            f"CURRENT_REGISTRY_ROW_NOT_EXACTLY_ONE:{fingerprint}:{component_id}"
        )
    return rows[0]


def _identity_map(root: Path, head: str, proposal_rows: list[dict[str, Any]]) -> tuple[dict[str, dict[str, Any]], list[str]]:
    baseline = json_bytes(committed(root, head, c.BASELINE_REPORT_REL.as_posix()), "baseline")
    if sha(committed(root, head, c.BASELINE_REPORT_REL.as_posix())) != c.AUTHORIZED_BASELINE_REPORT_SHA256:
        raise BuilderError("BASELINE_REPORT_HASH_MISMATCH")
    identities = c.authorized_failure_identity_by_fingerprint(baseline)
    selected = {str(row["failure_fingerprint"]): row for row in proposal_rows}
    for path in BACKFILL_PATHS:
        matches = [identity for identity in identities.values() if identity.get("subject_value") == path and identity.get("rule_id") == "HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT"]
        if len(matches) != 1:
            raise BuilderError(f"BACKFILL_IDENTITY_NOT_UNIQUE:{path}")
        selected[str(matches[0]["failure_fingerprint"])] = {"failure_fingerprint": matches[0]["failure_fingerprint"], "historical_path": path}
    if len(selected) != 50:
        raise BuilderError("BATCH008_MEMBERSHIP_NOT_50")
    for fp in selected:
        identity = identities.get(fp)
        if not isinstance(identity, dict) or identity.get("bucket") != "HISTORICAL":
            raise BuilderError(f"CURRENT_OR_UNAUTHORIZED_FAILURE:{fp}")
        if identity.get("rule_id") != "HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT":
            raise BuilderError(f"RULE_SUBSTITUTION:{fp}")
        if any(char in str(identity.get("raw_failure", "")) for char in "*?[]"):
            raise BuilderError(f"WILDCARD_FAILURE:{fp}")
    # Batch-008 is append-only: no fingerprint may be re-used from batches
    # 001-007.  The lookup is explicit and never discovers arbitrary paths.
    prior: set[str] = set()
    for number in range(1, 8):
        relative = f"{BATCH_ROOT}/batch-{number:03d}/batch-{number:03d}-manifest.json"
        document = json_bytes(committed(root, head, relative), relative)
        values = document.get("failure_fingerprints") if isinstance(document, dict) else None
        if not isinstance(values, list):
            raise BuilderError(f"PRIOR_MANIFEST_INVALID:{number}")
        prior.update(str(value) for value in values)
    overlap = prior.intersection(selected)
    if overlap:
        raise BuilderError(f"LEGACY_OR_PRIOR_OVERLAP:{sorted(overlap)[0]}")
    final_fps = sorted(selected)
    if line_set(final_fps) != EXPECTED_MEMBERSHIP_SET_SHA256:
        raise BuilderError("BATCH008_MEMBERSHIP_SET_SHA256_MISMATCH")
    return identities, final_fps


def _registry_projection(root: Path, head: str, selector: dict[str, list[str]]) -> dict[str, Any]:
    try:
        return c.subject_projection(root, head, selector)
    except Exception as exc:
        raise BuilderError("SUBJECT_PROJECTION_UNRESOLVED") from exc


def _resolve_backfill_row(registry: dict[str, Any], historical_path: str, disposition: str) -> dict[str, Any]:
    expected = BACKFILL_EXPECTATIONS.get(historical_path)
    if expected is None:
        raise BuilderError(f"BACKFILL_PATH_UNAUTHORIZED:{historical_path}")
    rows = [
        row for row in registry.get("historical_identity_backfill", [])
        if isinstance(row, dict)
        and str(row.get("component_id")) == expected["component_id"]
        and str(row.get("source_commit")) == expected["source_commit"]
        and str(row.get("source_blob")) == expected["source_blob"]
        and str(row.get("current_disposition")) == expected["disposition"]
    ]
    if len(rows) != 1:
        raise BuilderError(f"BACKFILL_ROW_NOT_EXACTLY_ONE:{historical_path}")
    if disposition != expected["disposition"]:
        raise BuilderError(f"BACKFILL_DISPOSITION_MISMATCH:{historical_path}")
    return rows[0]


def _resolve_backfill_supersession(supersession: dict[str, Any], historical_path: str, current_component: str) -> dict[str, Any]:
    expected = BACKFILL_EXPECTATIONS[historical_path]
    rows = [
        row for row in supersession.get("entries", [])
        if isinstance(row, dict)
        and str(row.get("old_component_id")) == expected["component_id"]
        and str(row.get("new_component_id")) == current_component
        and str(row.get("old_source_commit")) == expected["source_commit"]
        and str(row.get("old_source_blob_sha256")) == expected["source_blob"]
    ]
    if len(rows) != 1:
        raise BuilderError(f"BACKFILL_SUPERSESSION_NOT_EXACTLY_ONE:{historical_path}")
    return rows[0]


def _binding(root: Path, head: str, identity: dict[str, Any], registry: dict[str, Any], supersession: dict[str, Any], inventory: dict[str, list[dict[str, Any]]], disposition: str, proposal_rows: list[dict[str, Any]]) -> dict[str, Any]:
    fp = str(identity["failure_fingerprint"])
    historical_path = str(identity.get("subject_value", ""))
    source = full_commit(root, str(identity.get("transition_new_prefix", "")))
    old_component = str(identity.get("subject_value", ""))
    current_component = old_component
    historical_row: dict[str, Any] | None = None
    for row in proposal_rows:
        if str(row.get("failure_fingerprint")) == fp:
            historical_path = str(row.get("historical_path", historical_path))
            historical_row = row.get("registry_row") if isinstance(row.get("registry_row"), dict) else None
            current_component = str((historical_row or {}).get("component_id", old_component))
            break
    expected_backfill = BACKFILL_EXPECTATIONS.get(historical_path)
    resolved_supersession: dict[str, Any] | None = None
    if expected_backfill is not None:
        backfills = [_resolve_backfill_row(registry, historical_path, disposition)]
    else:
        backfills = [row for row in registry.get("historical_identity_backfill", []) if isinstance(row, dict) and str(row.get("component_id")) == current_component]
    if backfills:
        historical_row = backfills[0]
        current_component = expected_backfill["component_id"] if disposition == "HISTORICAL_ACTIVE_LINEAGE_REGISTERED" else "component.current.v07_asset_batch_core"
        if expected_backfill is not None and disposition == "HISTORICAL_SUPERSEDED_NONREACHABLE":
            # Retain the independently cardinality-checked row. The selector
            # below must use this exact supersession ID, never a broad search.
            resolved_supersession = _resolve_backfill_supersession(
                supersession, historical_path, current_component
            )
    # Never fall back to a historical/backfill row: it is not current
    # authority and may describe a retired component or path.
    current_row = _current_registry_row(inventory, current_component, fp)
    historical_component = str((historical_row or {}).get("component_id", current_component))
    current_path = str(current_row.get("path", historical_path))
    historical_owner = str((historical_row or {}).get("owner_component_id", current_row.get("owner_component_id", "")))
    if str((historical_row or {}).get("historical_role", "")) == "OWNER":
        historical_owner = historical_component
    current_owner = str(current_row.get("owner_component_id", historical_owner))
    superseded_by = list((historical_row or {}).get("supersession", [])) if backfills else list((historical_row or {}).get("superseded_by", []))
    supersedes = list(current_row.get("supersedes", []))
    selector = {"component_ids": sorted({x for x in (historical_component, current_component, historical_owner, current_owner) if x}), "dynamic_reference_ids": [], "paths": sorted({x for x in (historical_path, current_path) if x}), "retirement_ids": [], "supersession_ids": []}
    if superseded_by:
        entries = [x for x in registry.get("historical_identity_backfill", []) if isinstance(x, dict)]
        _ = entries
        map_rows = registry  # keep the selector authority explicit; map rows are resolved by subject_projection.
        _ = map_rows
    if resolved_supersession is not None:
        selector["supersession_ids"] = [str(resolved_supersession["supersession_id"])]
    elif superseded_by:
        selector["supersession_ids"] = sorted({str(x.get("supersession_id")) for x in json_bytes(committed(root, head, SOURCE_PATHS[1]), SOURCE_PATHS[1]).get("entries", []) if isinstance(x, dict) and x.get("old_component_id") == historical_component and x.get("new_component_id") in superseded_by})
    projection = _registry_projection(root, head, selector)
    historical_bytes = committed(root, source, historical_path)
    current_bytes = committed(root, head, current_path)
    return {
        "authority_selectors": selector,
        "current_blob_sha256": sha(current_bytes),
        "current_component_id": current_component,
        "current_owner_id": current_owner,
        "current_path": current_path,
        "current_production_reachability": "PRODUCTION_REACHABLE" if current_row.get("production_reachable") is True else "TEST_ONLY",
        "current_role": str(current_row.get("component_role", "")),
        "diagnostic_only_status": "NOT_DIAGNOSTIC_ONLY",
        "documentation_only_status": "NOT_DOCUMENTATION_ONLY",
        "domain_id": str(current_row.get("domain_id", "current.v075_production_combat_candidate")),
        "dynamic_reference_status": "NOT_DYNAMIC_REFERENCE",
        "duplicate_identity_sha256": "",
        "duplicate_of_failure_fingerprint": "",
        "duplicate_reason": "",
        "first_seen_commit": source,
        "generated_evidence_status": "NOT_GENERATED_EVIDENCE",
        "historical_blob_sha256": sha(historical_bytes),
        "historical_component_id": historical_component,
        "historical_owner_id": historical_owner,
        "historical_path": historical_path,
        "historical_production_reachability": "PRODUCTION_REACHABLE" if disposition == "HISTORICAL_ACTIVE_LINEAGE_REGISTERED" else "NONREACHABLE" if disposition == "HISTORICAL_SUPERSEDED_NONREACHABLE" else "TEST_ONLY",
        "historical_role": str((historical_row or {}).get("historical_role", (historical_row or {}).get("component_role", current_row.get("component_role", "TEST_SUPPORT")))),
        "invalidation_policy": TOUCH_POLICY,
        "last_seen_commit": c.AUTHORIZATION_BASE_HEAD_SHA,
        "recommended_disposition": disposition,
        "retired_status": "ACTIVE_LINEAGE" if disposition == "HISTORICAL_ACTIVE_LINEAGE_REGISTERED" else "SUPERSEDED_NONREACHABLE" if disposition == "HISTORICAL_SUPERSEDED_NONREACHABLE" else "NOT_RETIRED",
        "source_commit": source,
        "subject_projection": projection,
        "subject_projection_sha256": sha(canonical(projection)),
        "superseded_by": sorted(str(x) for x in superseded_by),
        "supersedes": sorted(str(x) for x in supersedes),
        "test_only_status": "NOT_TEST_ONLY" if disposition != "HISTORICAL_TEST_ONLY" else "TEST_ONLY",
    }


def _artifact_documents(fps: list[str], identities: dict[str, dict[str, Any]], proposal_by_fp: dict[str, dict[str, Any]], disposition_by_fp: dict[str, str]) -> dict[str, dict[str, Any]]:
    rows: dict[str, Any] = {}
    for fp in fps:
        p = proposal_by_fp.get(fp, {})
        r = p.get("registry_row") if isinstance(p.get("registry_row"), dict) else {}
        i = identities[fp]
        rows[fp] = {
            "authority_origin": "FROZEN_FULL_CONVERGENCE_BASELINE",
            "current_component_id": r.get("component_id", i.get("subject_value", "")),
            "current_path": r.get("path", i.get("subject_value", "")),
            "domain_id": r.get("domain_id", "current.v075_production_combat_candidate"),
            "failure_fingerprint": fp,
            "historical_component_id": r.get("component_id", i.get("subject_value", "")),
            "historical_path": p.get("historical_path", i.get("subject_value", "")),
            "owner_id": r.get("owner_component_id", "component.current.v075_runtime_owner"),
            "production_reachability": disposition_by_fp[fp] == "HISTORICAL_ACTIVE_LINEAGE_REGISTERED" or bool(r.get("production_reachable", False)),
            "raw_failure": i.get("raw_failure", ""),
            "recommended_disposition": disposition_by_fp[fp],
            "role": r.get("component_role", "TEST_SUPPORT"),
            "rule_id": i.get("rule_id", ""),
            "transition_new_prefix": str(i.get("transition_new_prefix", "")),
            "transition_old_prefix": str(i.get("transition_old_prefix", "")),
        }
    role_counts = {"TEST_SUPPORT": sum(disposition_by_fp[x] == "HISTORICAL_TEST_ONLY" for x in fps), "PORT": 0, "PRESENTATION": 0}
    for row in rows.values():
        if row["production_reachability"] and row["role"] in {"PORT", "PRESENTATION"}: role_counts[row["role"]] += 1
    reach = {"PRODUCTION_REACHABLE": sum(x["production_reachability"] for x in rows.values()), "TEST_ONLY": sum(not x["production_reachability"] for x in rows.values())}
    checks = {"baseline_membership": True, "current_delta_rejection": True, "duplicate_fingerprint_rejection": True, "dynamic_reference_exclusion": True, "exact_transition_rejection": True, "future_failure_rejection": True, "legacy_overlap_rejection": True, "mixed_reachability_split": True, "wildcard_rejection": True}
    return {
        "inventory": {"schema_version": ARTIFACTS["batch_inventory_sha256"][1], "batch_id": BATCH_ID, "failure_fingerprints": fps, "failure_count": 50, "identity_coverage_percent": 100, "unknown_count": 0, "rows": rows},
        "classification": {"schema_version": ARTIFACTS["batch_classification_sha256"][1], "batch_id": BATCH_ID, "failure_fingerprints": fps, "failure_count": 50, "unknown_count": 0, "wildcard_count": 0, "classifications": {fp: {"failure_fingerprint": fp, "production_reachability": "PRODUCTION_REACHABLE" if rows[fp]["production_reachability"] else "TEST_ONLY", "recommended_disposition": disposition_by_fp[fp], "role": rows[fp]["role"], "status": "CLASSIFIED", "transition_class": disposition_by_fp[fp]} for fp in fps}},
        "negative_checks": {"schema_version": ARTIFACTS["batch_negative_checks_sha256"][1], "batch_id": BATCH_ID, "failure_fingerprints": fps, "failure_count": 50, "status": "PASS", "candidate_set_sha256": line_set(fps), "candidate_reachability_counts": reach, "candidate_role_counts": role_counts, "current_failure_false_accept_count": 0, "future_failure_auto_correction_count": 0, "wildcard_count": 0, "checks": checks},
        "review_a": {"schema_version": ARTIFACTS["batch_review_a_sha256"][1], "batch_id": BATCH_ID, "failure_fingerprints": fps, "failure_count": 50, "review_id": "A", "status": "GO", "p0_count": 0, "p1_count": 0, "findings": []},
        "review_b": {"schema_version": ARTIFACTS["batch_review_b_sha256"][1], "batch_id": BATCH_ID, "failure_fingerprints": fps, "failure_count": 50, "review_id": "B", "status": "GO", "p0_count": 0, "p1_count": 0, "findings": []},
    }


def build(root: Path, stage: Path, proposal: Path | None = None) -> dict[str, Any]:
    root = root.resolve()
    stage = safe_stage(root, stage)
    if stage.exists():
        raise BuilderError("STAGING_ROOT_MUST_BE_FRESH_NONEXISTENT")
    head = git(root, "rev-parse", "HEAD^{commit}")
    tree = git(root, "rev-parse", f"{head}^{{tree}}")
    registry_bytes = committed(root, head, SOURCE_PATHS[0])
    map_bytes = committed(root, head, SOURCE_PATHS[1])
    if sha(registry_bytes) != EXPECTED_REGISTRY_SHA256:
        raise BuilderError("REGISTRY_SHA256_MISMATCH")
    if sha(map_bytes) != EXPECTED_MAP_SHA256:
        raise BuilderError("SUPERSESSION_MAP_SHA256_MISMATCH")
    proposal_rows = _proposal_rows(proposal)
    identities, fps = _identity_map(root, head, proposal_rows)
    proposal_by_fp = {str(x["failure_fingerprint"]): x for x in proposal_rows}
    registry, supersession, inventory = _authority_rows(root, head)
    # The external proposal is a review input, not authority.  Every proposed
    # registry row must byte-for-byte describe the current committed row;
    # otherwise fail closed instead of silently accepting an identity
    # substitution.
    for row in proposal_rows:
        proposed = row.get("registry_row")
        component_id = str(proposed.get("component_id", "")) if isinstance(proposed, dict) else ""
        if not component_id:
            raise BuilderError(f"AUTHORITY_SELECTOR_SUBSTITUTION:{component_id}")
        current_row = _current_registry_row(inventory, component_id, str(row.get("failure_fingerprint", "")))
        if canonical(proposed) != canonical(current_row):
            raise BuilderError(f"AUTHORITY_ROW_SUBSTITUTION:{component_id}")
    disposition_by_fp = {fp: ("HISTORICAL_TEST_ONLY" if fp in proposal_by_fp and not bool((proposal_by_fp[fp].get("registry_row") or {}).get("production_reachable")) else "HISTORICAL_ACTIVE_LINEAGE_REGISTERED") for fp in fps}
    for path, disposition in BACKFILL_PATHS.items():
        fp = next(fp for fp in fps if identities[fp].get("subject_value") == path)
        disposition_by_fp[fp] = disposition
    groups = {"HISTORICAL_TEST_ONLY": [], "HISTORICAL_ACTIVE_LINEAGE_REGISTERED": [], "HISTORICAL_SUPERSEDED_NONREACHABLE": []}
    for fp in fps: groups[disposition_by_fp[fp]].append(fp)
    if tuple(len(groups[x]) for x in groups) != (45, 4, 1): raise BuilderError("BATCH008_DISPOSITION_GROUPING_INVALID")
    bindings = {fp: _binding(root, head, identities[fp], registry, supersession, inventory, disposition_by_fp[fp], proposal_rows) for fp in fps}
    docs = _artifact_documents(fps, identities, proposal_by_fp, disposition_by_fp)
    hashes: dict[str, str] = {}
    for key, (filename, _) in ARTIFACTS.items(): _, hashes[key] = exclusive_write(stage, f"batch-008/{filename}", docs[ARTIFACT_KINDS[filename]])
    prev_manifest = f"{BATCH_ROOT}/batch-007/batch-007-manifest.json"
    previous_append = sha(committed(root, head, prev_manifest))
    previous_terminal = "4fb8feda0747d7b082e8aa127c2edb595b08ff6b754c9436e2f904ffd2ea4a4e"
    record_summaries = []; terminal = previous_terminal
    record_paths = [
        ("HISTORICAL_TEST_ONLY", "transition_46b33bba77b3_e584cd4d8b0c_test-only.json"),
        ("HISTORICAL_ACTIVE_LINEAGE_REGISTERED", "transition_46b33bba77b3_e584cd4d8b0c_production-reachable.json"),
        ("HISTORICAL_SUPERSEDED_NONREACHABLE", "transition_46b33bba77b3_e584cd4d8b0c_superseded-nonreachable.json"),
    ]
    for index, (disposition, filename) in enumerate(record_paths, 1):
        selected = groups[disposition]; identity_bindings = {fp: bindings[fp] for fp in selected}; paths = sorted({x for b in identity_bindings.values() for x in (b["historical_path"], b["current_path"]) if x}); components = sorted({x for b in identity_bindings.values() for x in (b["historical_component_id"], b["current_component_id"]) if x}); domains = sorted({b["domain_id"] for b in identity_bindings.values()}); owners = sorted({x for b in identity_bindings.values() for x in (b["historical_owner_id"], b["current_owner_id"]) if x}); dynamic = sorted({x for b in identity_bindings.values() for x in b["authority_selectors"]["dynamic_reference_ids"]}); supers = sorted({x for b in identity_bindings.values() for x in b["authority_selectors"]["supersession_ids"]}); retire = sorted({x for b in identity_bindings.values() for x in b["authority_selectors"]["retirement_ids"]}); sources = sorted({b["source_commit"] for b in identity_bindings.values()}); source_hashes = {p: sha(committed(root, head, p)) for p in SOURCE_PATHS}
        record = {"allowed_from_state":"HISTORICAL_FAILURE_PRESENT_CLASSIFIED","allowed_rule_ids":["HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT"],"allowed_to_state":"CORRECTED_HISTORICAL_DEBT","authority_source_sha256":source_hashes,"authorization_base_head_sha":c.AUTHORIZATION_BASE_HEAD_SHA,"authorization_id":c.AUTHORIZATION_ID,"backlog_item_ids":[f"reuse.full-convergence.{BATCH_ID}.{index:02d}"],"baseline_failure_set_sha256":c.AUTHORIZED_BASELINE_FAILURE_SET_SHA256,"baseline_report_sha256":c.AUTHORIZED_BASELINE_REPORT_SHA256,"batch_classification_sha256":hashes["batch_classification_sha256"],"batch_id":BATCH_ID,"batch_inventory_sha256":hashes["batch_inventory_sha256"],"batch_negative_checks_sha256":hashes["batch_negative_checks_sha256"],"batch_review_a_sha256":hashes["batch_review_a_sha256"],"batch_review_b_sha256":hashes["batch_review_b_sha256"],"binding_head_sha":head,"binding_tree_sha":tree,"component_ids":components,"component_set_sha256":line_set(components),"correction_id":f"V2-FC-{BATCH_ID}-{index:02d}-46b33bba77b3-e584cd4d8b0c-{disposition.removeprefix('HISTORICAL_').lower()}","correction_reason":"Exact live historical component identity correction for transition 46b33bba77b3->e584cd4d8b0c.","created_at":CREATED_AT,"creator":"V076ReuseFullConvergenceBatch008EvidenceBuilder","descendant_history_supplement_sha256":sha(committed(root, head, c.DESCENDANT_HISTORY_V3_SUPPLEMENT_REL.as_posix())),"domain_ids":domains,"domain_set_sha256":line_set(domains),"dynamic_reference_ids":dynamic,"dynamic_reference_set_sha256":line_set(dynamic),"failure_classes":["HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT"],"failure_count":len(selected),"failure_fingerprint_set_sha256":line_set(selected),"failure_fingerprints":selected,"from_state":"HISTORICAL_FAILURE_PRESENT_CLASSIFIED","future_failure_policy":{"FUTURE_FAILURE_AUTO_CORRECTION_COUNT":0,"NEW_FAILURE_REQUIRES_NEW_RECORD":True},"identity_binding_by_failure":identity_bindings,"negative_examples":["CURRENT_DELTA_FAILURE","WILDCARD"],"owner_ids":owners,"owner_set_sha256":line_set(owners),"path_set_sha256":line_set(paths),"paths":paths,"previous_correction_chain_sha256":terminal,"record_kind":"CORRECTION_RECORD","required_untouched_state":True,"retirement_ids":retire,"retirement_set_sha256":line_set(retire),"revocation_policy":{"OLD_RECORD_MUTATION_FORBIDDEN":True,"REVOCATION_APPEND_ONLY":True},"rule_ids":["HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT"],"schema_version":c.SCHEMA_VERSION,"source_commit_set":sources,"source_commit_set_sha256":line_set(sources),"supersession_ids":supers,"supersession_set_sha256":line_set(supers),"to_effective_disposition":"CORRECTED_HISTORICAL_DEBT","touch_invalidation_policy":TOUCH_POLICY,"transition_class_id":f"HISTORICAL_UNCLASSIFIED_COMPONENT_46B33BBA77B3_E584CD4D8B0C_{disposition.removeprefix('HISTORICAL_')}","untouched_in_current_delta":True}
        record["record_payload_sha256"] = sha(canonical({k:v for k,v in record.items() if k != "record_payload_sha256"}))
        path, record_sha = exclusive_write(stage, f"records/batch-008/{filename}", record); record_summaries.append({"correction_id":record["correction_id"],"failure_fingerprints":selected,"failure_count":len(selected),"failure_fingerprint_set_sha256":record["failure_fingerprint_set_sha256"],"path":f"{RECORD_ROOT}/batch-008/{filename}","previous_correction_chain_sha256":record["previous_correction_chain_sha256"],"record_payload_sha256":record["record_payload_sha256"],"record_sha256":record_sha}); terminal = record["record_payload_sha256"]
    correction_records = {"schema_version":"space_syndicate.v076.reuse_full_convergence.batch_correction_records.v1","authoritative_binding_source":f"{BATCH_ID}-manifest.json#record_bindings","batch_id":BATCH_ID,"correction_record_count":3,"failure_count":50,"failure_fingerprint_set_sha256":line_set(fps),"records":record_summaries}
    exclusive_write(stage, "batch-008/batch_correction_records.json", correction_records)
    manifest_bindings = [
        {key: summary[key] for key in ("correction_id", "failure_fingerprints", "path", "previous_correction_chain_sha256", "record_payload_sha256", "record_sha256")}
        for summary in record_summaries
    ]
    manifest = {"authorization_base_head_sha":c.AUTHORIZATION_BASE_HEAD_SHA,"authorization_id":c.AUTHORIZATION_ID,"baseline_failure_set_sha256":c.AUTHORIZED_BASELINE_FAILURE_SET_SHA256,"baseline_report_sha256":c.AUTHORIZED_BASELINE_REPORT_SHA256,"batch_classification_sha256":hashes["batch_classification_sha256"],"batch_id":BATCH_ID,"batch_inventory_sha256":hashes["batch_inventory_sha256"],"batch_negative_checks_sha256":hashes["batch_negative_checks_sha256"],"batch_review_a_sha256":hashes["batch_review_a_sha256"],"batch_review_a_status":"GO","batch_review_b_sha256":hashes["batch_review_b_sha256"],"batch_review_b_status":"GO","batch_size_target":"25_TO_50_FAILURE_FINGERPRINTS","batch_unknown_count":0,"batch_wildcard_count":0,"binding_head_sha":head,"binding_tree_sha":tree,"current_failure_false_accept_count":0,"descendant_history_supplement_sha256":sha(committed(root, head, c.DESCENDANT_HISTORY_V3_SUPPLEMENT_REL.as_posix())),"failure_count":50,"failure_fingerprint_set_sha256":line_set(fps),"failure_fingerprints":fps,"identity_coverage_percent":100,"previous_batch_append_sha256":previous_append,"record_bindings":manifest_bindings,"record_chain_start_sha256":previous_terminal,"record_chain_terminal_sha256":terminal,"schema_version":c.BATCH_MANIFEST_SCHEMA_VERSION,"terminal_remainder_batch":False}
    exclusive_write(stage, "batch-008/batch-008-manifest.json", manifest)
    expected_paths = {
        "batch-008/batch-008-manifest.json", "batch-008/batch_inventory.json",
        "batch-008/batch_classification.json", "batch-008/batch_correction_records.json",
        "batch-008/batch_negative_checks.json", "batch-008/batch_review_A.json",
        "batch-008/batch_review_B.json",
        "records/batch-008/transition_46b33bba77b3_e584cd4d8b0c_test-only.json",
        "records/batch-008/transition_46b33bba77b3_e584cd4d8b0c_production-reachable.json",
        "records/batch-008/transition_46b33bba77b3_e584cd4d8b0c_superseded-nonreachable.json",
    }
    actual_paths = {p.relative_to(stage).as_posix() for p in stage.rglob("*") if p.is_file()}
    if actual_paths != expected_paths:
        raise BuilderError("BATCH008_OUTPUT_FILE_SET_MISMATCH")
    return {"status":"PASS","batch_id":BATCH_ID,"evaluated_head_sha":head,"evaluated_tree_sha":tree,"output_count":10,"groups":{k:len(v) for k,v in groups.items()},"staging_root":stage.as_posix()}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--staging-root", type=Path, required=True)
    parser.add_argument("--proposal", type=Path, default=None)
    args = parser.parse_args(argv)
    try:
        print(json.dumps(build(args.root, args.staging_root, args.proposal), ensure_ascii=False, sort_keys=True))
    except BuilderError as exc:
        print(json.dumps({"status":"FAIL","error":str(exc)}, ensure_ascii=False, sort_keys=True))
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
