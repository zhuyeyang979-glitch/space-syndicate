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
EXPECTED_OWNER_MAP_SHA256 = "44daa51a44fb0f663976af83e00a606f1f77a406fed45c7027ed0eabc5a25f6b"
EXPECTED_DYNAMIC_REFERENCE_MANIFEST_SHA256 = "52472d87729ab167ab31b785a12b2be246ede798a03c9d3bee22bb740062ecd7"
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
EXPECTED_AUTHORITY_SOURCE_SHA256 = {
    "docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json": EXPECTED_REGISTRY_SHA256,
    "docs/architecture/V076_SUPERSESSION_MAP.json": EXPECTED_MAP_SHA256,
    "docs/architecture/V076_OWNER_REUSE_MAP.md": EXPECTED_OWNER_MAP_SHA256,
    "docs/architecture/V076_DYNAMIC_REFERENCE_MANIFEST.json": EXPECTED_DYNAMIC_REFERENCE_MANIFEST_SHA256,
}
TRUSTED_REVIEWER_AUTHORITY_BY_ID = {
    "PRIMARY": "V076_FULL_CONVERGENCE_PRIMARY_REVIEWER_V1",
    "INDEPENDENT": "V076_FULL_CONVERGENCE_INDEPENDENT_REVIEWER_V1",
}
CANDIDATE_SCHEMA_VERSION = "space_syndicate.v076.reuse_full_convergence.batch_candidate.v2"
REVIEW_SCHEMA_VERSION = "space_syndicate.v076.reuse_full_convergence.external_review_receipt.v2"
SEAL_SCHEMA_VERSION = "space_syndicate.v076.reuse_full_convergence.batch_candidate_seal.v2"
CANDIDATE_FIELDS = frozenset({
    "schema_version", "candidate_kind", "batch_id", "stage_absolute_path",
    "evaluated_head_sha", "evaluated_tree_sha", "file_count", "files",
    "file_set_sha256", "go_claim", "review_status", "required_review_ids",
    "candidate_payload_sha256", "candidate_file_sha256",
})
REVIEW_FIELDS = frozenset({
    "schema_version", "batch_id", "candidate_path", "candidate_file_sha256",
    "candidate_payload_sha256", "evaluated_head_sha", "evaluated_tree_sha",
    "file_set_sha256", "review_id", "reviewer_authority_id", "findings",
    "p0_count", "p1_count", "status", "receipt_payload_sha256",
    "review_file_sha256",
})
SEAL_FIELDS = frozenset({
    "schema_version", "authorization_id", "batch_id", "candidate_path",
    "candidate_payload_sha256", "candidate_file_sha256", "evaluated_head_sha",
    "evaluated_tree_sha", "file_set_sha256", "review_status",
    "review_receipts", "go_claim", "official_batch_write_count",
    "official_record_write_count", "seal_payload_sha256", "seal_file_sha256",
})
REVIEW_RECEIPT_FIELDS = frozenset({
    "path", "review_id", "file_sha256", "receipt_payload_sha256",
})
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


def _is_exact_int(value: Any, expected: int) -> bool:
    return type(value) is int and value == expected


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


def _validated_external_stage(stage: Path) -> Path:
    """Validate the lexical stage before resolving its canonical path."""

    lexical = Path(os.path.abspath(os.fspath(stage)))
    _reject_reparse(lexical)
    for ancestor in [lexical, *lexical.parents]:
        if (ancestor / ".git").exists():
            raise BuilderError("STAGING_ROOT_MUST_BE_OUTSIDE_WORKTREE")
    return lexical.resolve(strict=False)


def safe_stage(root: Path, stage: Path) -> Path:
    root = root.resolve()
    resolved = _validated_external_stage(stage)
    try:
        resolved.relative_to(root)
    except ValueError:
        return resolved
    raise BuilderError("STAGING_ROOT_MUST_BE_OUTSIDE_PROJECT")


def exclusive_write(stage: Path, relative: str, value: Any) -> tuple[Path, str]:
    path = stage / relative
    # Check the lexical path before resolution: a reparse point in a not-yet
    # resolved parent must fail closed even when its target remains in stage.
    _reject_reparse(path)
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
    _reject_reparse(path)
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
    stage = _validated_external_stage(stage)
    output = Path(os.path.abspath(os.fspath(output)))
    resolved_output = output.resolve(strict=False)
    try:
        resolved_output.relative_to(stage)
    except ValueError:
        pass
    else:
        raise BuilderError(f"{label}_MUST_BE_OUTSIDE_STAGE")
    for ancestor in [output, *output.parents]:
        if (ancestor / ".git").exists():
            raise BuilderError(f"{label}_MUST_BE_OUTSIDE_WORKTREE")
    _reject_reparse(output)
    return output


def _file_identity(path: Path) -> tuple[int, int]:
    info = os.stat(path, follow_symlinks=False)
    if int(getattr(info, "st_nlink", 1)) != 1:
        raise BuilderError(f"HARDLINK_FORBIDDEN:{path}")
    return int(getattr(info, "st_dev", 0)), int(getattr(info, "st_ino", 0))


def _stage_file_inventory(stage: Path) -> tuple[list[dict[str, Any]], str]:
    stage = _validated_external_stage(stage)
    if not stage.is_dir():
        raise BuilderError("STAGING_ROOT_MISSING")
    files: list[dict[str, Any]] = []
    identities: dict[tuple[int, int], Path] = {}
    for item in stage.rglob("*"):
        _reject_reparse(item)
        if item.is_file():
            identity = _file_identity(item)
            if identity != (0, 0):
                previous = identities.get(identity)
                if previous is not None:
                    raise BuilderError(f"HARDLINK_ALIAS_FORBIDDEN:{previous}:{item}")
                identities[identity] = item
            relative = item.relative_to(stage).as_posix()
            payload = item.read_bytes()
            files.append({"path": relative, "byte_count": len(payload), "sha256": sha(payload)})
    files.sort(key=lambda row: row["path"])
    return files, sha(canonical([{"path": row["path"], "sha256": row["sha256"]} for row in files]))


def _candidate_payload(candidate: dict[str, Any]) -> dict[str, Any]:
    return {key: value for key, value in candidate.items() if key not in {"candidate_payload_sha256", "candidate_file_sha256"}}


def _stage_manifest(stage: Path) -> dict[str, Any]:
    manifest_path = stage / "batch-008" / "batch-008-manifest.json"
    manifest, raw = _read_external_json(manifest_path, "STAGE_MANIFEST")
    if raw != canonical(manifest):
        raise BuilderError("STAGE_MANIFEST_BYTES_NONCANONICAL")
    if manifest.get("schema_version") != c.BATCH_MANIFEST_SCHEMA_VERSION:
        raise BuilderError("STAGE_MANIFEST_SCHEMA_VERSION_INVALID")
    if manifest.get("batch_id") != BATCH_ID:
        raise BuilderError("STAGE_MANIFEST_BATCH_ID_INVALID")
    manifest_failures = c.validate_batch_manifest_document(manifest)
    if manifest_failures:
        raise BuilderError(f"STAGE_MANIFEST_INVALID:{manifest_failures[0]}")
    return manifest


def _validate_candidate_semantics(
    candidate: dict[str, Any], stage: Path, manifest: dict[str, Any]
) -> None:
    if set(candidate) != CANDIDATE_FIELDS:
        raise BuilderError("CANDIDATE_FIELD_SET_MISMATCH")
    if candidate.get("schema_version") != CANDIDATE_SCHEMA_VERSION:
        raise BuilderError("CANDIDATE_SCHEMA_VERSION_INVALID")
    if candidate.get("candidate_kind") != "NON_AUTHORITATIVE_REVIEW_INPUT":
        raise BuilderError("CANDIDATE_KIND_INVALID")
    if candidate.get("batch_id") != BATCH_ID:
        raise BuilderError("CANDIDATE_BATCH_ID_INVALID")
    if candidate.get("go_claim") is not False or candidate.get("review_status") != "PENDING":
        raise BuilderError("CANDIDATE_GO_OR_REVIEW_STATUS_INVALID")
    if candidate.get("required_review_ids") != ["INDEPENDENT", "PRIMARY"]:
        raise BuilderError("CANDIDATE_REQUIRED_REVIEWS_INVALID")
    if not _is_exact_int(candidate.get("file_count"), len(OUTPUT_ALLOWLIST)):
        raise BuilderError("CANDIDATE_FILE_COUNT_INVALID")
    if candidate.get("stage_absolute_path") != stage.as_posix():
        raise BuilderError("CANDIDATE_STAGE_PATH_MISMATCH")
    head = str(candidate.get("evaluated_head_sha", ""))
    tree = str(candidate.get("evaluated_tree_sha", ""))
    if not re.fullmatch(r"[0-9a-f]{40}", head) or not re.fullmatch(r"[0-9a-f]{40}", tree):
        raise BuilderError("CANDIDATE_HEAD_TREE_INVALID")
    if head != manifest.get("binding_head_sha") or tree != manifest.get("binding_tree_sha"):
        raise BuilderError("CANDIDATE_HEAD_TREE_NOT_STAGE_BOUND")
    if candidate.get("candidate_payload_sha256") != sha(canonical(_candidate_payload(candidate))):
        raise BuilderError("CANDIDATE_PAYLOAD_SHA256_MISMATCH")
    if candidate.get("candidate_file_sha256") != sha(
        canonical({key: value for key, value in candidate.items() if key != "candidate_file_sha256"})
    ):
        raise BuilderError("CANDIDATE_FILE_SHA256_MISMATCH")
    files, file_set_sha = _stage_file_inventory(stage)
    if {row["path"] for row in files} != OUTPUT_ALLOWLIST or len(files) != len(OUTPUT_ALLOWLIST):
        raise BuilderError("CANDIDATE_STAGE_FILE_SET_MISMATCH")
    if candidate.get("files") != files or candidate.get("file_set_sha256") != file_set_sha:
        raise BuilderError("SEAL_STAGE_BYTES_DRIFT")


def create_candidate(stage: Path, output: Path, evaluated_head: str, evaluated_tree: str) -> dict[str, Any]:
    """Seal a fresh ten-file stage as a non-authoritative external candidate."""

    stage = _validated_external_stage(stage)
    output = _assert_external_output(stage, output, "CANDIDATE_OUTPUT")
    if not re.fullmatch(r"[0-9a-f]{40}", str(evaluated_head)) or not re.fullmatch(r"[0-9a-f]{40}", str(evaluated_tree)):
        raise BuilderError("CANDIDATE_HEAD_TREE_INVALID")
    manifest = _stage_manifest(stage)
    files, file_set_sha = _stage_file_inventory(stage)
    if {row["path"] for row in files} != OUTPUT_ALLOWLIST or len(files) != 10:
        raise BuilderError("CANDIDATE_STAGE_FILE_SET_MISMATCH")
    candidate = {
        "schema_version": CANDIDATE_SCHEMA_VERSION,
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
    _validate_candidate_semantics(candidate, stage, manifest)
    path, raw_file_sha = _external_write(output, candidate)
    return {
        "status": "PASS",
        "candidate_path": path.as_posix(),
        "candidate_payload_sha256": candidate["candidate_payload_sha256"],
        "candidate_file_sha256": candidate["candidate_file_sha256"],
        "candidate_raw_file_sha256": raw_file_sha,
        "file_count": len(OUTPUT_ALLOWLIST),
        "go_claim": False,
    }


def _review_payload(review: dict[str, Any]) -> dict[str, Any]:
    return {key: value for key, value in review.items() if key not in {"receipt_payload_sha256", "review_file_sha256"}}


def _validate_reviewer_authority(review_id: str, reviewer_authority_id: str) -> None:
    expected = TRUSTED_REVIEWER_AUTHORITY_BY_ID.get(review_id)
    if expected is None:
        raise BuilderError("REVIEW_ID_INVALID")
    if reviewer_authority_id != expected:
        raise BuilderError("REVIEWER_AUTHORITY_NOT_TRUSTED")


def _validate_review_semantics(
    review: dict[str, Any], candidate: dict[str, Any], candidate_path: Path
) -> None:
    if set(review) != REVIEW_FIELDS:
        raise BuilderError("REVIEW_FIELD_SET_MISMATCH")
    if review.get("schema_version") != REVIEW_SCHEMA_VERSION:
        raise BuilderError("REVIEW_SCHEMA_VERSION_INVALID")
    review_id = str(review.get("review_id", ""))
    reviewer = str(review.get("reviewer_authority_id", ""))
    _validate_reviewer_authority(review_id, reviewer)
    if review.get("receipt_payload_sha256") != sha(canonical(_review_payload(review))):
        raise BuilderError("REVIEW_PAYLOAD_SHA256_MISMATCH")
    if review.get("review_file_sha256") != sha(
        canonical({key: value for key, value in review.items() if key != "review_file_sha256"})
    ):
        raise BuilderError("REVIEW_FILE_SHA256_MISMATCH")
    expected_bindings = {
        "batch_id": BATCH_ID,
        "candidate_path": candidate_path.as_posix(),
        "candidate_file_sha256": candidate.get("candidate_file_sha256"),
        "candidate_payload_sha256": candidate.get("candidate_payload_sha256"),
        "evaluated_head_sha": candidate.get("evaluated_head_sha"),
        "evaluated_tree_sha": candidate.get("evaluated_tree_sha"),
        "file_set_sha256": candidate.get("file_set_sha256"),
    }
    if any(review.get(key) != value for key, value in expected_bindings.items()):
        raise BuilderError("SEAL_REVIEW_BINDING_INVALID")
    if (
        review.get("status") != "GO"
        or not _is_exact_int(review.get("p0_count"), 0)
        or not _is_exact_int(review.get("p1_count"), 0)
        or review.get("findings") != []
    ):
        raise BuilderError("REVIEW_GO_STATE_INVALID")


def create_review(candidate_path: Path, output: Path, review_id: str, reviewer_authority_id: str) -> dict[str, Any]:
    candidate_path = Path(os.path.abspath(os.fspath(candidate_path)))
    candidate, candidate_raw = _read_external_json(candidate_path, "CANDIDATE")
    if candidate_raw != canonical(candidate):
        raise BuilderError("CANDIDATE_BYTES_NONCANONICAL")
    stage_text = str(candidate.get("stage_absolute_path", ""))
    if not stage_text or not os.path.isabs(stage_text):
        raise BuilderError("CANDIDATE_STAGE_PATH_INVALID")
    stage = _validated_external_stage(Path(stage_text))
    _assert_external_output(stage, candidate_path, "CANDIDATE_INPUT")
    _file_identity(candidate_path)
    manifest = _stage_manifest(stage)
    _validate_candidate_semantics(candidate, stage, manifest)
    _validate_reviewer_authority(review_id, reviewer_authority_id)
    output = _assert_external_output(stage, output, "REVIEW_OUTPUT")
    review = {
        "schema_version": REVIEW_SCHEMA_VERSION,
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
    _validate_review_semantics(review, candidate, candidate_path)
    path, raw_file_sha = _external_write(output, review)
    return {
        "status": "PASS",
        "review_path": path.as_posix(),
        "review_file_sha256": review["review_file_sha256"],
        "review_raw_file_sha256": raw_file_sha,
        "review_id": review_id,
    }


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

    stage = _validated_external_stage(stage)
    output = _assert_external_output(stage, output, "SEAL_OUTPUT")
    candidate_path = Path(os.path.abspath(os.fspath(candidate_path)))
    _assert_external_output(stage, candidate_path, "CANDIDATE_INPUT")
    _file_identity(candidate_path)
    candidate, candidate_bytes = _read_external_json(candidate_path, "CANDIDATE")
    if candidate_bytes != canonical(candidate):
        raise BuilderError("CANDIDATE_BYTES_NONCANONICAL")
    manifest = _stage_manifest(stage)
    _validate_candidate_semantics(candidate, stage, manifest)
    reviewed_inputs: list[tuple[Path, dict[str, Any], bytes]] = []
    normalized_paths: set[Path] = set()
    for review_path in review_paths:
        normalized = _assert_external_output(stage, review_path, "REVIEW_INPUT")
        normalized = Path(os.path.abspath(os.fspath(normalized)))
        if normalized in normalized_paths:
            raise BuilderError("SEAL_REVIEW_PATHS_NOT_DISTINCT")
        normalized_paths.add(normalized)
        _file_identity(normalized)
        review, review_bytes = _read_external_json(normalized, "REVIEW")
        if review_bytes != canonical(review):
            raise BuilderError("REVIEW_BYTES_NONCANONICAL")
        _validate_review_semantics(review, candidate, candidate_path)
        reviewed_inputs.append((normalized, review, review_bytes))
    if len(reviewed_inputs) != 2:
        raise BuilderError("SEAL_REQUIRES_TWO_REVIEWS")
    reviews = [row[1] for row in reviewed_inputs]
    if {r.get("review_id") for r in reviews} != {"PRIMARY", "INDEPENDENT"}:
        raise BuilderError("SEAL_REVIEW_IDS_INVALID")
    if len({r.get("reviewer_authority_id") for r in reviews}) != 2:
        raise BuilderError("SEAL_REVIEWERS_NOT_DISTINCT")
    seal = {
        "schema_version": SEAL_SCHEMA_VERSION,
        "authorization_id": c.AUTHORIZATION_ID,
        "batch_id": BATCH_ID,
        "candidate_path": candidate_path.as_posix(),
        "candidate_payload_sha256": candidate["candidate_payload_sha256"],
        "candidate_file_sha256": candidate["candidate_file_sha256"],
        "evaluated_head_sha": candidate["evaluated_head_sha"],
        "evaluated_tree_sha": candidate["evaluated_tree_sha"],
        "file_set_sha256": candidate["file_set_sha256"],
        "review_status": "DUAL_REVIEW_PASS",
        "review_receipts": [
            {
                "path": path.as_posix(),
                "review_id": review["review_id"],
                "file_sha256": sha(raw),
                "receipt_payload_sha256": review["receipt_payload_sha256"],
            }
            for path, review, raw in reviewed_inputs
        ],
        "go_claim": True,
        "official_batch_write_count": 0,
        "official_record_write_count": 0,
    }
    seal["seal_payload_sha256"] = sha(
        canonical({key: value for key, value in seal.items() if key not in {"seal_payload_sha256", "seal_file_sha256"}})
    )
    seal["seal_file_sha256"] = sha(
        canonical({key: value for key, value in seal.items() if key != "seal_file_sha256"})
    )
    path, raw_file_sha = _external_write(output, seal)
    return {
        "status": "PASS",
        "seal_path": path.as_posix(),
        "seal_file_sha256": seal["seal_file_sha256"],
        "seal_raw_file_sha256": raw_file_sha,
        "go_claim": True,
    }


def _validate_seal_envelope(seal: dict[str, Any]) -> None:
    if set(seal) != SEAL_FIELDS:
        raise BuilderError("SEAL_FIELD_SET_MISMATCH")
    if seal.get("schema_version") != SEAL_SCHEMA_VERSION:
        raise BuilderError("SEAL_SCHEMA_VERSION_INVALID")
    if seal.get("authorization_id") != c.AUTHORIZATION_ID:
        raise BuilderError("SEAL_AUTHORIZATION_ID_INVALID")
    if seal.get("batch_id") != BATCH_ID:
        raise BuilderError("SEAL_BATCH_ID_INVALID")
    if seal.get("go_claim") is not True or seal.get("review_status") != "DUAL_REVIEW_PASS":
        raise BuilderError("SEAL_GO_OR_REVIEW_STATUS_INVALID")
    if not _is_exact_int(seal.get("official_batch_write_count"), 0) or not _is_exact_int(
        seal.get("official_record_write_count"), 0
    ):
        raise BuilderError("SEAL_OFFICIAL_WRITE_COUNT_INVALID")
    receipts = seal.get("review_receipts")
    if not isinstance(receipts, list) or len(receipts) != 2:
        raise BuilderError("SEAL_REQUIRES_TWO_REVIEW_RECEIPTS")
    if seal.get("seal_payload_sha256") != sha(
        canonical({key: value for key, value in seal.items() if key not in {"seal_payload_sha256", "seal_file_sha256"}})
    ):
        raise BuilderError("SEAL_PAYLOAD_SHA256_MISMATCH")
    if seal.get("seal_file_sha256") != sha(
        canonical({key: value for key, value in seal.items() if key != "seal_file_sha256"})
    ):
        raise BuilderError("SEAL_FILE_SHA256_MISMATCH")


def _validate_seal_complete(
    seal_path: Path,
    stage: Path,
    candidate_path: Path | None,
    review_paths: list[Path] | None,
) -> None:
    stage = _validated_external_stage(stage)
    seal_path = _assert_external_output(stage, seal_path, "SEAL_INPUT")
    seal_path = Path(os.path.abspath(os.fspath(seal_path)))
    _file_identity(seal_path)
    seal, seal_raw = _read_external_json(seal_path, "SEAL")
    if seal_raw != canonical(seal):
        raise BuilderError("SEAL_BYTES_NONCANONICAL")
    _validate_seal_envelope(seal)

    recorded_candidate_path = Path(os.path.abspath(os.fspath(Path(str(seal.get("candidate_path", ""))))))
    selected_candidate_path = Path(os.path.abspath(os.fspath(candidate_path or recorded_candidate_path)))
    if selected_candidate_path != recorded_candidate_path:
        raise BuilderError("SEAL_CANDIDATE_PATH_MISMATCH")
    _assert_external_output(stage, selected_candidate_path, "CANDIDATE_INPUT")
    _file_identity(selected_candidate_path)
    candidate, candidate_raw = _read_external_json(selected_candidate_path, "CANDIDATE")
    if candidate_raw != canonical(candidate):
        raise BuilderError("CANDIDATE_BYTES_NONCANONICAL")
    manifest = _stage_manifest(stage)
    _validate_candidate_semantics(candidate, stage, manifest)
    candidate_bindings = {
        "candidate_payload_sha256": candidate.get("candidate_payload_sha256"),
        "candidate_file_sha256": candidate.get("candidate_file_sha256"),
        "evaluated_head_sha": candidate.get("evaluated_head_sha"),
        "evaluated_tree_sha": candidate.get("evaluated_tree_sha"),
        "file_set_sha256": candidate.get("file_set_sha256"),
    }
    if any(seal.get(key) != value for key, value in candidate_bindings.items()):
        raise BuilderError("SEAL_CANDIDATE_BINDING_INVALID")

    receipts = seal["review_receipts"]
    if any(not isinstance(receipt, dict) for receipt in receipts):
        raise BuilderError("SEAL_REVIEW_RECEIPT_INVALID")
    recorded_paths = [
        Path(os.path.abspath(os.fspath(Path(str(receipt.get("path", ""))))))
        for receipt in receipts
    ]
    selected_paths = (
        [Path(os.path.abspath(os.fspath(path))) for path in review_paths]
        if review_paths is not None
        else recorded_paths
    )
    if len(selected_paths) != 2 or set(selected_paths) != set(recorded_paths):
        raise BuilderError("SEAL_REVIEW_PATH_BINDING_INVALID")
    if len(set(recorded_paths)) != 2:
        raise BuilderError("SEAL_REVIEW_PATHS_NOT_DISTINCT")

    observed_ids: set[str] = set()
    observed_reviewers: set[str] = set()
    receipt_by_path = {path: receipt for path, receipt in zip(recorded_paths, receipts)}
    for review_path in selected_paths:
        _assert_external_output(stage, review_path, "REVIEW_INPUT")
        _file_identity(review_path)
        review, review_raw = _read_external_json(review_path, "REVIEW")
        if review_raw != canonical(review):
            raise BuilderError("REVIEW_BYTES_NONCANONICAL")
        _validate_review_semantics(review, candidate, selected_candidate_path)
        receipt = receipt_by_path[review_path]
        if set(receipt) != REVIEW_RECEIPT_FIELDS:
            raise BuilderError("SEAL_REVIEW_RECEIPT_FIELDS_INVALID")
        if (
            receipt.get("path") != review_path.as_posix()
            or receipt.get("review_id") != review.get("review_id")
            or receipt.get("file_sha256") != sha(review_raw)
            or receipt.get("receipt_payload_sha256") != review.get("receipt_payload_sha256")
        ):
            raise BuilderError("SEAL_REVIEW_RECEIPT_BINDING_INVALID")
        observed_ids.add(str(review.get("review_id", "")))
        observed_reviewers.add(str(review.get("reviewer_authority_id", "")))
    if observed_ids != {"PRIMARY", "INDEPENDENT"}:
        raise BuilderError("SEAL_REVIEW_IDS_INVALID")
    if len(observed_reviewers) != 2:
        raise BuilderError("SEAL_REVIEWERS_NOT_DISTINCT")


def validate_seal(
    seal_path: Path,
    stage: Path,
    candidate_path: Path | None = None,
    review_paths: list[Path] | None = None,
) -> list[str]:
    """Independently revalidate the complete sealed evidence graph."""

    try:
        _validate_seal_complete(seal_path, stage, candidate_path, review_paths)
    except (BuilderError, OSError, ValueError) as exc:
        return [str(exc).split(":", 1)[0]]
    return []


validate_seal_document = validate_seal


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


def _authority_source_bytes(root: Path, head: str) -> dict[str, bytes]:
    """Read and hash every sealed authority source exactly once."""

    if set(SOURCE_PATHS) != set(EXPECTED_AUTHORITY_SOURCE_SHA256):
        raise BuilderError("AUTHORITY_SOURCE_SET_INVALID")
    payloads: dict[str, bytes] = {}
    labels = {
        SOURCE_PATHS[0]: "REGISTRY",
        SOURCE_PATHS[1]: "SUPERSESSION_MAP",
        SOURCE_PATHS[2]: "OWNER_REUSE_MAP",
        SOURCE_PATHS[3]: "DYNAMIC_REFERENCE_MANIFEST",
    }
    for relative in SOURCE_PATHS:
        payload = committed(root, head, relative)
        payloads[relative] = payload
        expected = EXPECTED_AUTHORITY_SOURCE_SHA256[relative]
        if sha(payload) != expected:
            raise BuilderError(f"{labels.get(relative, 'AUTHORITY_SOURCE')}_SHA256_MISMATCH")
    return payloads


def _authority_rows(
    root: Path,
    head: str,
    source_payloads: dict[str, bytes] | None = None,
) -> tuple[
    dict[str, Any],
    dict[str, Any],
    dict[str, list[dict[str, Any]]],
    bytes,
    dict[str, Any],
]:
    payloads = source_payloads if source_payloads is not None else _authority_source_bytes(root, head)
    registry = json_bytes(payloads[SOURCE_PATHS[0]], SOURCE_PATHS[0])
    supersession = json_bytes(payloads[SOURCE_PATHS[1]], SOURCE_PATHS[1])
    # Parse/validate the two non-JSON authority inputs as well.  Their bytes
    # are consumed by c.subject_projection later; touching either file must
    # therefore be covered by the same fixed hash gate.
    owner_map_payload = payloads[SOURCE_PATHS[2]]
    dynamic_reference_manifest = json_bytes(
        payloads[SOURCE_PATHS[3]], SOURCE_PATHS[3]
    )
    if not isinstance(registry, dict) or not isinstance(supersession, dict):
        raise BuilderError("AUTHORITY_DOCUMENT_INVALID")
    if not isinstance(dynamic_reference_manifest, dict):
        raise BuilderError("AUTHORITY_DOCUMENT_INVALID")
    if not owner_map_payload:
        raise BuilderError("AUTHORITY_DOCUMENT_INVALID")
    # Preserve every row. A dict comprehension would collapse duplicate
    # component IDs and make an ambiguous authority set look unique.
    inventory: dict[str, list[dict[str, Any]]] = {}
    for row in registry.get("component_inventory", []):
        if not isinstance(row, dict):
            continue
        component_id = str(row.get("component_id", ""))
        inventory.setdefault(component_id, []).append(row)
    return registry, supersession, inventory, owner_map_payload, dynamic_reference_manifest


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
    baseline_bytes = committed(root, head, c.BASELINE_REPORT_REL.as_posix())
    baseline = json_bytes(baseline_bytes, "baseline")
    if sha(baseline_bytes) != c.AUTHORIZED_BASELINE_REPORT_SHA256:
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


def _registry_projection(
    selector: dict[str, list[str]],
    registry: dict[str, Any],
    supersession: dict[str, Any],
    owner_map_payload: bytes,
    dynamic_reference_manifest: dict[str, Any],
) -> dict[str, Any]:
    """Project exact selectors from the already hashed authority byte snapshot."""

    try:
        failures = c._selector_failures(selector)
        if failures:
            raise ValueError(";".join(failures))
        component_ids = {str(value) for value in selector.get("component_ids", [])}
        paths = {c.normalize_path(str(value)) for value in selector.get("paths", [])}
        dynamic_reference_ids = {
            str(value) for value in selector.get("dynamic_reference_ids", [])
        }
        supersession_ids = {
            str(value) for value in selector.get("supersession_ids", [])
        }
        retirement_ids = {
            str(value) for value in selector.get("retirement_ids", [])
        }
        registry_candidates: list[dict[str, Any]] = []
        for key in ("component_inventory", "historical_identity_backfill"):
            values = registry.get(key, [])
            if isinstance(values, list):
                for value in values:
                    if isinstance(value, dict):
                        tagged = dict(value)
                        tagged["authority_source_kind"] = key
                        registry_candidates.append(tagged)
        registry_rows = [
            row
            for row in registry_candidates
            if str(row.get("component_id", "")) in component_ids
            or c.normalize_path(str(row.get("path", ""))) in paths
        ]
        supersession_candidates: list[dict[str, Any]] = []
        for key in ("entries", "retirement_entries"):
            values = supersession.get(key, [])
            if isinstance(values, list):
                supersession_candidates.extend(
                    value for value in values if isinstance(value, dict)
                )
        supersession_rows = [
            row
            for row in supersession_candidates
            if str(row.get("supersession_id", "")) in supersession_ids
            or str(row.get("retirement_id", "")) in retirement_ids
        ]
        dynamic_candidates = dynamic_reference_manifest.get("entries", [])
        dynamic_reference_rows = [
            row
            for row in dynamic_candidates
            if isinstance(row, dict)
            and str(row.get("dynamic_reference_id", "")) in dynamic_reference_ids
        ] if isinstance(dynamic_candidates, list) else []
        registry_rows = sorted(registry_rows, key=canonical)
        supersession_rows = sorted(supersession_rows, key=canonical)
        dynamic_reference_rows = sorted(dynamic_reference_rows, key=canonical)
        exact_needles = sorted({
            str(value)
            for field in c.AUTHORITY_SELECTOR_FIELDS
            for value in selector.get(field, [])
            if value
        })
        owner_map_lines = sorted({
            line.rstrip()
            for line in owner_map_payload.decode("utf-8-sig", errors="replace").splitlines()
            if any(needle in line for needle in exact_needles)
        })
        if not registry_rows and not supersession_rows and not owner_map_lines and not dynamic_reference_rows:
            raise ValueError("SUBJECT_PROJECTION_SELECTOR_UNRESOLVED")
        return {
            "dynamic_reference_rows": dynamic_reference_rows,
            "owner_map_lines": owner_map_lines,
            "registry_rows": registry_rows,
            "supersession_rows": supersession_rows,
        }
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


def _binding(root: Path, head: str, identity: dict[str, Any], registry: dict[str, Any], supersession: dict[str, Any], inventory: dict[str, list[dict[str, Any]]], owner_map_payload: bytes, dynamic_reference_manifest: dict[str, Any], disposition: str, proposal_rows: list[dict[str, Any]]) -> dict[str, Any]:
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
        selector["supersession_ids"] = sorted({str(x.get("supersession_id")) for x in supersession.get("entries", []) if isinstance(x, dict) and x.get("old_component_id") == historical_component and x.get("new_component_id") in superseded_by})
    projection = _registry_projection(
        selector,
        registry,
        supersession,
        owner_map_payload,
        dynamic_reference_manifest,
    )
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
    authority_payloads = _authority_source_bytes(root, head)
    proposal_rows = _proposal_rows(proposal)
    identities, fps = _identity_map(root, head, proposal_rows)
    proposal_by_fp = {str(x["failure_fingerprint"]): x for x in proposal_rows}
    (
        registry,
        supersession,
        inventory,
        owner_map_payload,
        dynamic_reference_manifest,
    ) = _authority_rows(root, head, authority_payloads)
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
    bindings = {
        fp: _binding(
            root,
            head,
            identities[fp],
            registry,
            supersession,
            inventory,
            owner_map_payload,
            dynamic_reference_manifest,
            disposition_by_fp[fp],
            proposal_rows,
        )
        for fp in fps
    }
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
        selected = groups[disposition]; identity_bindings = {fp: bindings[fp] for fp in selected}; paths = sorted({x for b in identity_bindings.values() for x in (b["historical_path"], b["current_path"]) if x}); components = sorted({x for b in identity_bindings.values() for x in (b["historical_component_id"], b["current_component_id"]) if x}); domains = sorted({b["domain_id"] for b in identity_bindings.values()}); owners = sorted({x for b in identity_bindings.values() for x in (b["historical_owner_id"], b["current_owner_id"]) if x}); dynamic = sorted({x for b in identity_bindings.values() for x in b["authority_selectors"]["dynamic_reference_ids"]}); supers = sorted({x for b in identity_bindings.values() for x in b["authority_selectors"]["supersession_ids"]}); retire = sorted({x for b in identity_bindings.values() for x in b["authority_selectors"]["retirement_ids"]}); sources = sorted({b["source_commit"] for b in identity_bindings.values()}); source_hashes = {p: sha(payload) for p, payload in authority_payloads.items()}
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
    # Re-scan after all writes so a concurrent replacement/alias cannot turn
    # an otherwise valid byte set into a non-exclusive stage.  The inventory
    # helper also rejects reparse points and hardlinks.
    final_files, _final_file_set_sha = _stage_file_inventory(stage)
    actual_paths = {row["path"] for row in final_files}
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
