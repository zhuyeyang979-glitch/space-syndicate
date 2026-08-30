"""Exact-only, staging-only materializer for V076 full-convergence Batch-009.

This tool deliberately owns no Registry or product mutation.  It accepts the
already sealed Batch-009 membership package, then requires fifty exact current
``component_inventory`` path rows before it will even inspect a classification
proposal.  Materialization additionally requires two exact-byte-bound reviews
of an explicit proposal and canonical parity between every proposal Registry
row and the committed Registry projection at the binding Head.

The only write surface is a fresh external staging directory containing seven
batch files plus one correction record per non-empty reviewed disposition.
There is no apply, stage, commit, or official-record command in this module.
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
from typing import Any, Iterable

import v076_reuse_exact_failure_correction_v2_full_convergence as convergence
import v076_reuse_full_convergence_batch_builder as membership_builder


BATCH_ID = "batch-009"
CREATED_AT = "2026-08-29T00:00:00Z"
SEALED_MEMBERSHIP_HEAD_SHA = "d1f48b52966d50627126f7e0e1accb6011bec1de"
SEALED_MEMBERSHIP_FAILURE_COUNT = 50
SEALED_MEMBERSHIP_SET_SHA256 = (
    "034611fa9bedce94293532ba27c43f0387dfb859e4479fdb128c76395e3bd871"
)
SEALED_MEMBERSHIP_CANDIDATE_PAYLOAD_SHA256 = (
    "c6a9c8ab9fad6af94cc08ad88dc531ee3cf14f1f8bfe234e0caec7fc1c427080"
)
SEALED_MEMBERSHIP_SEAL_PAYLOAD_SHA256 = (
    "979ea321224049a7cb56eb719db07f4d7594bbf3cf7c8affc5ffb615b58aec06"
)

REGISTRY_REL = Path("docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json")
SUPERSESSION_REL = Path("docs/architecture/V076_SUPERSESSION_MAP.json")
BATCH_ROOT = Path(
    "docs/architecture/reuse_corrections/v2/batches/full_convergence_20260827"
)
RECORD_ROOT = Path(
    "docs/architecture/reuse_corrections/v2/records/full_convergence_20260827"
)

PROPOSAL_SCHEMA = (
    "space_syndicate.v076.reuse_full_convergence."
    "batch009_exact_projection_candidate.v1"
)
PROPOSAL_REVIEW_SCHEMA = (
    "space_syndicate.v076.reuse_full_convergence."
    "batch009_exact_projection_review.v1"
)
PROPOSAL_KIND = "NON_AUTHORITATIVE_EXACT_REGISTRY_PROJECTION_REVIEW_INPUT"
PROPOSAL_FIELDS = frozenset({
    "schema_version",
    "candidate_kind",
    "batch_id",
    "membership_candidate_payload_sha256",
    "membership_seal_payload_sha256",
    "evaluated_head_sha",
    "evaluated_tree_sha",
    "authority_source_sha256",
    "failure_count",
    "failure_fingerprints",
    "failure_fingerprint_set_sha256",
    "rows",
    "required_review_ids",
    "review_status",
    "go_claim",
    "official_batch_write_count",
    "official_record_write_count",
    "proposal_payload_sha256",
})
PROPOSAL_ROW_FIELDS = frozenset({
    "failure_fingerprint",
    "source_identity",
    "expected_registry_rows",
    "identity_binding",
})
SOURCE_IDENTITY_FIELDS = frozenset({
    "declared_class_name",
    "extends_type",
    "identity_kind",
    "path",
    "resource_script_class",
    "resource_type",
    "root_node_name",
    "root_node_type",
    "script_path",
    "source_blob_sha256",
})
PROPOSAL_REVIEW_FIELDS = frozenset({
    "schema_version",
    "batch_id",
    "proposal_payload_sha256",
    "evaluated_head_sha",
    "evaluated_tree_sha",
    "failure_fingerprint_set_sha256",
    "review_id",
    "reviewer_authority_id",
    "findings",
    "p0_count",
    "p1_count",
    "status",
    "receipt_payload_sha256",
})
TRUSTED_PROPOSAL_REVIEWERS = {
    "A": "V076_FULL_CONVERGENCE_PRIMARY_REVIEWER_V1",
    "B": "V076_FULL_CONVERGENCE_INDEPENDENT_REVIEWER_V1",
}

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

SUPPORTED_GROUPS = (
    (
        "HISTORICAL_TEST_ONLY",
        "transition_46b33bba77b3_e584cd4d8b0c_test-only.json",
        "TEST_ONLY",
    ),
    (
        "HISTORICAL_ACTIVE_LINEAGE_REGISTERED",
        "transition_46b33bba77b3_e584cd4d8b0c_production-reachable.json",
        "PRODUCTION_REACHABLE",
    ),
    (
        "HISTORICAL_SUPERSEDED_NONREACHABLE",
        "transition_46b33bba77b3_e584cd4d8b0c_superseded-nonreachable.json",
        "SUPERSEDED_NONREACHABLE",
    ),
)

BASE_OUTPUT_ALLOWLIST = frozenset({
    "batch-009/batch-009-manifest.json",
    "batch-009/batch_inventory.json",
    "batch-009/batch_classification.json",
    "batch-009/batch_correction_records.json",
    "batch-009/batch_negative_checks.json",
    "batch-009/batch_review_A.json",
    "batch-009/batch_review_B.json",
})
RECORD_OUTPUT_BY_DISPOSITION = {
    disposition: f"records/batch-009/{filename}"
    for disposition, filename, _suffix in SUPPORTED_GROUPS
}
OUTPUT_ALLOWLIST = frozenset({
    *BASE_OUTPUT_ALLOWLIST,
    *RECORD_OUTPUT_BY_DISPOSITION.values(),
})


class MaterializerError(ValueError):
    """Fail-closed error emitted at an exact trust boundary."""


def canonical(value: Any) -> bytes:
    return convergence.canonical_bytes(value)


def sha(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def line_set(values: Iterable[str]) -> str:
    rendered = sorted(str(value) for value in values)
    return sha(("\n".join(rendered) + "\n").encode("utf-8"))


def git(root: Path, *args: str) -> str:
    process = subprocess.run(
        ["git", *args],
        cwd=root,
        text=True,
        encoding="utf-8",
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if process.returncode:
        raise MaterializerError(
            f"GIT_FAILED:{' '.join(args)}:{process.stderr.strip()}"
        )
    return process.stdout.strip()


def _exact_commit(value: Any, label: str) -> str:
    rendered = str(value)
    if re.fullmatch(r"[0-9a-f]{40}", rendered) is None:
        raise MaterializerError(f"{label}_COMMIT_INVALID")
    return rendered


def _exact_repo_path(value: Path | str, label: str) -> str:
    rendered = Path(value).as_posix()
    normalized = convergence.normalize_path(rendered)
    if (
        not rendered
        or normalized != rendered
        or rendered.startswith(("-", "/", "../"))
        or rendered.endswith("/")
        or "/../" in rendered
        or any(char in rendered for char in "*?[]\r\n\x00")
    ):
        raise MaterializerError(f"{label}_PATH_INVALID")
    return rendered


def committed(root: Path, head: str, relative: Path | str) -> bytes:
    # Validate both object-name components before spawning Git.  In particular,
    # an untrusted value such as ``--output=...`` must never reach option
    # parsing.  ``cat-file`` is read-only and the explicit ``--`` terminates
    # option parsing before the already validated ``commit:path`` object name.
    validated_head = _exact_commit(head, "COMMITTED_OBJECT")
    rendered = _exact_repo_path(relative, "COMMITTED_OBJECT")
    process = subprocess.run(
        ["git", "cat-file", "blob", "--", f"{validated_head}:{rendered}"],
        cwd=root,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if process.returncode:
        raise MaterializerError(f"MISSING_COMMITTED_INPUT:{rendered}")
    return process.stdout


def strict_json_bytes(payload: bytes, label: str) -> Any:
    if payload.startswith(b"\xef\xbb\xbf"):
        raise MaterializerError(f"JSON_BOM_FORBIDDEN:{label}")
    try:
        return json.loads(
            payload.decode("utf-8"), object_pairs_hook=convergence._strict_object
        )
    except Exception as exc:
        raise MaterializerError(f"JSON_INVALID:{label}") from exc


def _payload_hash_valid(value: dict[str, Any], field: str) -> bool:
    claimed = value.get(field)
    payload = dict(value)
    payload.pop(field, None)
    return (
        isinstance(claimed, str)
        and re.fullmatch(r"[0-9a-f]{64}", claimed) is not None
        and claimed == sha(canonical(payload))
    )


def _is_exact_int(value: Any, expected: int) -> bool:
    return type(value) is int and value == expected


def _lexical_absolute(path: Path, label: str) -> Path:
    if not path.is_absolute():
        raise MaterializerError(f"{label}_PATH_NOT_ABSOLUTE")
    return Path(os.path.abspath(os.fspath(path)))


def _reject_reparse_chain(path: Path, label: str) -> None:
    lexical = _lexical_absolute(path, label)
    reparse_flag = getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400)
    for entry in [*reversed(lexical.parents), lexical]:
        if not os.path.lexists(entry):
            continue
        try:
            info = os.lstat(entry)
        except OSError as exc:
            raise MaterializerError(
                f"{label}_LSTAT_FAILED:{entry.as_posix()}"
            ) from exc
        attributes = int(getattr(info, "st_file_attributes", 0))
        if stat.S_ISLNK(info.st_mode) or attributes & reparse_flag:
            raise MaterializerError(
                f"{label}_REPARSE_FORBIDDEN:{entry.as_posix()}"
            )


def _reject_git_ancestor(path: Path, label: str) -> None:
    for ancestor in [path, *path.parents]:
        if (ancestor / ".git").exists():
            raise MaterializerError(f"{label}_MUST_BE_OUTSIDE_WORKTREE")


def _require_external_stage(root: Path, stage: Path, label: str) -> Path:
    lexical = _lexical_absolute(stage, label)
    _reject_reparse_chain(lexical, label)
    resolved = lexical.resolve(strict=False)
    try:
        resolved.relative_to(root.resolve())
    except ValueError:
        pass
    else:
        raise MaterializerError(f"{label}_MUST_BE_OUTSIDE_PROJECT")
    _reject_git_ancestor(resolved, label)
    return resolved


def _require_disjoint_stages(
    root: Path,
    membership_stage: Path,
    output_stage: Path,
) -> tuple[Path, Path]:
    membership = _require_external_stage(
        root, membership_stage, "MEMBERSHIP_STAGE"
    )
    output = _require_external_stage(root, output_stage, "OUTPUT_STAGE")
    membership_key = os.path.normcase(os.path.normpath(os.fspath(membership)))
    output_key = os.path.normcase(os.path.normpath(os.fspath(output)))
    try:
        common = os.path.commonpath([membership_key, output_key])
    except ValueError:
        common = ""  # Different Windows volumes are necessarily disjoint.
    intersects = common in {membership_key, output_key}
    if intersects:
        raise MaterializerError("OUTPUT_MEMBERSHIP_STAGE_INTERSECTION_FORBIDDEN")
    return membership, output


def _require_plain_external_file(
    root: Path,
    path: Path,
    *,
    label: str,
    allowed_stage: Path | None = None,
) -> Path:
    lexical = _lexical_absolute(path, label)
    _reject_reparse_chain(lexical, label)
    resolved = lexical.resolve(strict=True)
    try:
        resolved.relative_to(root.resolve())
    except ValueError:
        pass
    else:
        raise MaterializerError(f"{label}_MUST_BE_OUTSIDE_PROJECT")
    if allowed_stage is not None:
        try:
            resolved.relative_to(allowed_stage.resolve())
        except ValueError as exc:
            raise MaterializerError(f"{label}_OUTSIDE_DECLARED_STAGE") from exc
    _reject_git_ancestor(resolved.parent, label)
    try:
        info = os.stat(resolved, follow_symlinks=False)
    except OSError as exc:
        raise MaterializerError(f"{label}_NOT_PLAIN_FILE") from exc
    if not stat.S_ISREG(info.st_mode):
        raise MaterializerError(f"{label}_NOT_PLAIN_FILE")
    if int(getattr(info, "st_nlink", 1)) != 1:
        raise MaterializerError(f"{label}_HARDLINK_FORBIDDEN")
    return resolved


def _read_external_json(
    root: Path,
    path: Path,
    *,
    label: str,
    allowed_stage: Path | None = None,
) -> tuple[dict[str, Any], bytes, Path]:
    resolved = _require_plain_external_file(
        root, path, label=label, allowed_stage=allowed_stage
    )
    raw = resolved.read_bytes()
    value = strict_json_bytes(raw, label)
    if not isinstance(value, dict):
        raise MaterializerError(f"{label}_NOT_OBJECT")
    if raw != canonical(value):
        raise MaterializerError(f"{label}_BYTES_NOT_CANONICAL")
    return value, raw, resolved


def _head_tree(root: Path, head_ref: str = "HEAD") -> tuple[str, str]:
    head = git(root, "rev-parse", f"{head_ref}^{{commit}}")
    tree = git(root, "rev-parse", f"{head}^{{tree}}")
    if (
        re.fullmatch(r"[0-9a-f]{40}", head) is None
        or re.fullmatch(r"[0-9a-f]{40}", tree) is None
    ):
        raise MaterializerError("HEAD_OR_TREE_INVALID")
    return head, tree


def _require_worktree_parity(root: Path, head: str, relative: Path) -> bytes:
    payload = committed(root, head, relative)
    path = root / relative
    if not path.is_file() or path.read_bytes() != payload:
        raise MaterializerError(f"AUTHORITY_WORKTREE_DRIFT:{relative.as_posix()}")
    return payload


def validate_membership_stage(root: Path, stage: Path) -> dict[str, Any]:
    """Validate the sealed Batch-009 membership without requiring HEAD equality.

    The generic membership validator intentionally requires a same-Head seal.
    Batch-009 classification, however, needs a successor Head containing exact
    Registry rows.  This validator keeps the membership bytes bound to their
    sealed Head and merely requires that Head to remain an ancestor.
    """

    root = root.resolve()
    stage = _require_external_stage(root, stage, "MEMBERSHIP_STAGE")
    if not stage.is_dir():
        raise MaterializerError("MEMBERSHIP_STAGE_MISSING")
    expected_files = {
        "candidate.json",
        "primary-review.json",
        "independent-review.json",
        "seal.json",
    }
    actual_files = {
        item.name
        for item in stage.iterdir()
        if item.is_file()
    }
    if actual_files != expected_files or any(item.is_dir() for item in stage.iterdir()):
        raise MaterializerError("MEMBERSHIP_STAGE_FILE_SET_MISMATCH")

    candidate, candidate_raw, candidate_path = _read_external_json(
        root,
        stage / "candidate.json",
        label="MEMBERSHIP_CANDIDATE",
        allowed_stage=stage,
    )
    if (
        set(candidate) != membership_builder.CANDIDATE_FIELDS
        or candidate.get("schema_version") != membership_builder.CANDIDATE_SCHEMA
        or candidate.get("candidate_kind") != "NON_AUTHORITATIVE_REVIEW_INPUT"
        or candidate.get("authorization_id") != convergence.AUTHORIZATION_ID
        or candidate.get("batch_id") != BATCH_ID
        or candidate.get("evaluated_head_sha") != SEALED_MEMBERSHIP_HEAD_SHA
        or not _is_exact_int(
            candidate.get("failure_count"), SEALED_MEMBERSHIP_FAILURE_COUNT
        )
        or candidate.get("failure_fingerprint_set_sha256")
        != SEALED_MEMBERSHIP_SET_SHA256
        or candidate.get("candidate_payload_sha256")
        != SEALED_MEMBERSHIP_CANDIDATE_PAYLOAD_SHA256
        or candidate.get("required_review_ids") != ["PRIMARY", "INDEPENDENT"]
        or candidate.get("review_status") != "PENDING"
        or candidate.get("go_claim") is not False
        or not _is_exact_int(candidate.get("official_batch_write_count"), 0)
        or not _is_exact_int(candidate.get("official_record_write_count"), 0)
        or candidate.get("next_builder_phase")
        != "PROJECT_EXACT_AUTHORITY_AND_BUILD_RECORDS"
        or not _payload_hash_valid(candidate, "candidate_payload_sha256")
    ):
        raise MaterializerError("MEMBERSHIP_CANDIDATE_CONTRACT_INVALID")

    fingerprints = candidate.get("failure_fingerprints")
    rows = candidate.get("rows")
    if (
        not isinstance(fingerprints, list)
        or fingerprints != sorted(str(value) for value in fingerprints)
        or len(fingerprints) != len(set(fingerprints))
        or len(fingerprints) != SEALED_MEMBERSHIP_FAILURE_COUNT
        or line_set(fingerprints) != SEALED_MEMBERSHIP_SET_SHA256
        or not isinstance(rows, dict)
        or set(rows) != set(fingerprints)
    ):
        raise MaterializerError("MEMBERSHIP_CANDIDATE_SET_INVALID")

    # Rebuild the exact frozen plan at the candidate Head.  The seven authority
    # inputs are not Registry inputs, so a Registry-only successor remains
    # valid while any scanner/report/membership drift fails closed.
    try:
        plan = membership_builder.derive_plan_from_committed_head(
            root, SEALED_MEMBERSHIP_HEAD_SHA
        )
        planned = plan.get("batches", {}).get(BATCH_ID, {})
        expected_rows = membership_builder.expected_membership_rows_from_committed_head(
            root, SEALED_MEMBERSHIP_HEAD_SHA, list(fingerprints)
        )
    except membership_builder.BuilderError as exc:
        raise MaterializerError(
            f"MEMBERSHIP_FROZEN_RECONSTRUCTION_FAILED:{exc}"
        ) from exc
    for field, expected in {
        "evaluated_head_sha": plan["evaluated_head_sha"],
        "plan_sha256": plan["plan_sha256"],
        "authority_inputs": plan["authority_inputs"],
        "failure_fingerprints": planned.get("failure_fingerprints"),
        "failure_count": planned.get("failure_count"),
        "failure_fingerprint_set_sha256": planned.get(
            "failure_fingerprint_set_sha256"
        ),
        "rows": expected_rows,
    }.items():
        if candidate.get(field) != expected:
            raise MaterializerError(f"MEMBERSHIP_FROZEN_PARITY_INVALID:{field}")

    reviews: dict[str, dict[str, Any]] = {}
    review_file_hashes: dict[str, str] = {}
    review_paths: dict[str, Path] = {}
    for filename in ("primary-review.json", "independent-review.json"):
        review, raw, resolved = _read_external_json(
            root,
            stage / filename,
            label=f"MEMBERSHIP_REVIEW:{filename}",
            allowed_stage=stage,
        )
        review_id = str(review.get("review_id", ""))
        if (
            set(review) != membership_builder.REVIEW_FIELDS
            or review.get("schema_version") != membership_builder.REVIEW_SCHEMA
            or review_id not in membership_builder.TRUSTED_REVIEWER_AUTHORITIES
            or review.get("reviewer_authority_id")
            != membership_builder.TRUSTED_REVIEWER_AUTHORITIES[review_id]
            or review.get("candidate_payload_sha256")
            != candidate.get("candidate_payload_sha256")
            or review.get("batch_id") != BATCH_ID
            or review.get("evaluated_head_sha") != SEALED_MEMBERSHIP_HEAD_SHA
            or review.get("plan_sha256") != candidate.get("plan_sha256")
            or review.get("failure_fingerprint_set_sha256")
            != SEALED_MEMBERSHIP_SET_SHA256
            or review.get("status") != "GO"
            or not _is_exact_int(review.get("p0_count"), 0)
            or not _is_exact_int(review.get("p1_count"), 0)
            or review.get("findings") != []
            or not _payload_hash_valid(review, "receipt_payload_sha256")
        ):
            raise MaterializerError(f"MEMBERSHIP_REVIEW_INVALID:{filename}")
        reviews[review_id] = review
        review_file_hashes[review_id] = sha(raw)
        review_paths[review_id] = resolved
    if set(reviews) != {"PRIMARY", "INDEPENDENT"}:
        raise MaterializerError("MEMBERSHIP_REVIEW_SET_INVALID")
    if len(set(review_paths.values())) != 2:
        raise MaterializerError("MEMBERSHIP_REVIEW_FILE_IDENTITY_INVALID")

    seal, seal_raw, _seal_path = _read_external_json(
        root,
        stage / "seal.json",
        label="MEMBERSHIP_SEAL",
        allowed_stage=stage,
    )
    if (
        set(seal) != membership_builder.SEALED_FIELDS
        or seal.get("schema_version") != membership_builder.SEALED_SCHEMA
        or seal.get("authorization_id") != convergence.AUTHORIZATION_ID
        or seal.get("batch_id") != BATCH_ID
        or seal.get("evaluated_head_sha") != SEALED_MEMBERSHIP_HEAD_SHA
        or seal.get("candidate_payload_sha256")
        != SEALED_MEMBERSHIP_CANDIDATE_PAYLOAD_SHA256
        or seal.get("seal_payload_sha256")
        != SEALED_MEMBERSHIP_SEAL_PAYLOAD_SHA256
        or seal.get("review_status") != "DUAL_REVIEW_PASS"
        or seal.get("go_claim") is not True
        or not _is_exact_int(seal.get("official_batch_write_count"), 0)
        or not _is_exact_int(seal.get("official_record_write_count"), 0)
        or seal.get("next_builder_phase")
        != "MATERIALIZE_AND_RUN_EXISTING_PRIMARY_AND_INDEPENDENT_VALIDATORS"
        or not _payload_hash_valid(seal, "seal_payload_sha256")
    ):
        raise MaterializerError("MEMBERSHIP_SEAL_CONTRACT_INVALID")
    try:
        declared_candidate = Path(str(seal.get("candidate_path", ""))).resolve()
    except Exception as exc:
        raise MaterializerError("MEMBERSHIP_SEAL_CANDIDATE_PATH_INVALID") from exc
    if declared_candidate != candidate_path.resolve():
        raise MaterializerError("MEMBERSHIP_SEAL_CANDIDATE_PATH_MISMATCH")
    references = seal.get("review_receipts")
    if not isinstance(references, list) or len(references) != 2:
        raise MaterializerError("MEMBERSHIP_SEAL_REVIEW_REFS_INVALID")
    if [row.get("review_id") for row in references if isinstance(row, dict)] != [
        "INDEPENDENT",
        "PRIMARY",
    ]:
        raise MaterializerError("MEMBERSHIP_SEAL_REVIEW_REF_ORDER_INVALID")
    for reference in references:
        if not isinstance(reference, dict) or set(reference) != {
            "path",
            "sha256",
            "review_id",
        }:
            raise MaterializerError("MEMBERSHIP_SEAL_REVIEW_REF_INVALID")
        review_id = str(reference["review_id"])
        declared_path = _require_plain_external_file(
            root,
            Path(str(reference["path"])),
            label="MEMBERSHIP_SEAL_REVIEW",
            allowed_stage=stage,
        )
        if (
            declared_path != review_paths.get(review_id)
            or reference.get("sha256") != review_file_hashes.get(review_id)
        ):
            raise MaterializerError("MEMBERSHIP_SEAL_REVIEW_BINDING_MISMATCH")

    current_head, _ = _head_tree(root)
    if not convergence._is_ancestor(
        root, SEALED_MEMBERSHIP_HEAD_SHA, current_head
    ):
        raise MaterializerError("CURRENT_HEAD_NOT_MEMBERSHIP_DESCENDANT")
    return {
        "candidate": candidate,
        "candidate_file_sha256": sha(candidate_raw),
        "seal": seal,
        "seal_file_sha256": sha(seal_raw),
        "review_file_sha256": review_file_hashes,
        "stage": stage,
    }


def _registry_document(root: Path, head: str) -> tuple[dict[str, Any], bytes]:
    payload = _require_worktree_parity(root, head, REGISTRY_REL)
    value = strict_json_bytes(payload, "REGISTRY")
    if not isinstance(value, dict):
        raise MaterializerError("REGISTRY_NOT_OBJECT")
    rows = value.get("component_inventory")
    if not isinstance(rows, list) or any(not isinstance(row, dict) for row in rows):
        raise MaterializerError("REGISTRY_COMPONENT_INVENTORY_INVALID")
    return value, payload


def _failure_paths(membership: dict[str, Any]) -> dict[str, str]:
    candidate = membership["candidate"]
    result: dict[str, str] = {}
    for fingerprint in candidate["failure_fingerprints"]:
        row = candidate["rows"][fingerprint]
        if (
            not isinstance(row, dict)
            or row.get("rule_id") != "HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT"
            or row.get("subject_kind") != "path"
        ):
            raise MaterializerError(
                f"MEMBERSHIP_NOT_EXACT_COMPONENT_PATH:{fingerprint}"
            )
        path = convergence.normalize_path(str(row.get("subject_value", "")))
        if (
            not path
            or path != row.get("subject_value")
            or any(char in path for char in "*?[]")
            or path.startswith(("/", "../"))
            or path.endswith("/")
            or "/../" in path
        ):
            raise MaterializerError(f"MEMBERSHIP_PATH_NOT_EXACT:{fingerprint}")
        result[fingerprint] = path
    if len(result) != SEALED_MEMBERSHIP_FAILURE_COUNT or len(set(result.values())) != len(result):
        raise MaterializerError("MEMBERSHIP_PATH_SET_NOT_UNIQUE")
    return result


def _registry_exact_rows(
    registry: dict[str, Any],
    failure_paths: dict[str, str],
) -> dict[str, dict[str, Any]]:
    inventory = registry["component_inventory"]
    missing: list[str] = []
    duplicate: list[str] = []
    resolved: dict[str, dict[str, Any]] = {}
    for fingerprint, path in failure_paths.items():
        matches = [
            row
            for row in inventory
            if convergence.normalize_path(str(row.get("path", ""))) == path
        ]
        if not matches:
            missing.append(path)
        elif len(matches) != 1:
            duplicate.append(path)
        else:
            resolved[fingerprint] = matches[0]
    if missing:
        rendered = sorted(missing)
        raise MaterializerError(
            f"MISSING_EXACT_REGISTRY_ROWS:{len(rendered)}:"
            + "|".join(rendered)
        )
    if duplicate:
        rendered = sorted(duplicate)
        raise MaterializerError(
            f"DUPLICATE_EXACT_REGISTRY_ROWS:{len(rendered)}:"
            + "|".join(rendered)
        )
    component_ids = [str(row.get("component_id", "")) for row in resolved.values()]
    class_names = [str(row.get("class_name", "")) for row in resolved.values()]
    if (
        any(not value for value in component_ids)
        or len(component_ids) != len(set(component_ids))
    ):
        raise MaterializerError("BATCH009_COMPONENT_ID_SET_NOT_UNIQUE")
    if any(not value for value in class_names) or len(class_names) != len(set(class_names)):
        raise MaterializerError("BATCH009_CLASS_NAME_SET_NOT_UNIQUE")
    return resolved


def preflight(
    root: Path,
    membership_stage: Path,
) -> dict[str, Any]:
    root = root.resolve()
    membership = validate_membership_stage(root, membership_stage)
    head, tree = _head_tree(root)
    registry, registry_bytes = _registry_document(root, head)
    failure_paths = _failure_paths(membership)
    direct_rows = _registry_exact_rows(registry, failure_paths)
    return {
        "status": "PASS",
        "batch_id": BATCH_ID,
        "evaluated_head_sha": head,
        "evaluated_tree_sha": tree,
        "failure_count": len(failure_paths),
        "failure_fingerprint_set_sha256": SEALED_MEMBERSHIP_SET_SHA256,
        "exact_registry_row_count": len(direct_rows),
        "exact_registry_row_set_sha256": sha(
            canonical(sorted(direct_rows.values(), key=canonical))
        ),
        "registry_sha256": sha(registry_bytes),
        "official_batch_write_count": 0,
        "official_record_write_count": 0,
        "next_phase": "OBTAIN_EXPLICIT_DUAL_REVIEWED_PROPOSAL",
    }


def _extract_ext_resources(text: str) -> dict[str, tuple[str, str]]:
    result: dict[str, tuple[str, str]] = {}
    pattern = re.compile(
        r'^\[ext_resource\s+type="([^"]+)"\s+path="([^"]+)"\s+id="([^"]+)"\]$',
        re.MULTILINE,
    )
    for match in pattern.finditer(text):
        result[match.group(3)] = (match.group(1), match.group(2))
    return result


def source_identity(root: Path, source_commit: str, path: str) -> dict[str, Any]:
    validated_source_commit = _exact_commit(source_commit, "SOURCE_IDENTITY")
    validated_path = _exact_repo_path(path, "SOURCE_IDENTITY")
    payload = committed(root, validated_source_commit, validated_path)
    try:
        text = payload.decode("utf-8-sig")
    except UnicodeDecodeError as exc:
        raise MaterializerError(f"SOURCE_IDENTITY_UTF8_INVALID:{path}") from exc
    result = {
        "declared_class_name": "",
        "extends_type": "",
        "identity_kind": "",
        "path": validated_path,
        "resource_script_class": "",
        "resource_type": "",
        "root_node_name": "",
        "root_node_type": "",
        "script_path": "",
        "source_blob_sha256": sha(payload),
    }
    suffix = Path(validated_path).suffix.casefold()
    if suffix == ".gd":
        result["identity_kind"] = "GDSCRIPT"
        class_match = re.search(
            r"^class_name\s+([A-Za-z_][A-Za-z0-9_]*)\s*$", text, re.MULTILINE
        )
        extends_match = re.search(r"^extends\s+([^\r\n#]+)", text, re.MULTILINE)
        result["declared_class_name"] = class_match.group(1) if class_match else ""
        result["extends_type"] = (
            extends_match.group(1).strip() if extends_match else ""
        )
    elif suffix == ".tscn":
        result["identity_kind"] = "GODOT_SCENE"
        root_match = re.search(
            r'^\[node\s+name="([^"]+)"\s+type="([^"]+)"[^\]]*\]$',
            text,
            re.MULTILINE,
        )
        if root_match is None:
            raise MaterializerError(f"SCENE_ROOT_IDENTITY_UNRESOLVED:{path}")
        result["root_node_name"] = root_match.group(1)
        result["root_node_type"] = root_match.group(2)
        resources = _extract_ext_resources(text)
        script_match = re.search(
            r'^script\s*=\s*ExtResource\("([^"]+)"\)\s*$', text, re.MULTILINE
        )
        if script_match:
            resource = resources.get(script_match.group(1))
            if resource is None or resource[0] != "Script":
                raise MaterializerError(f"SCENE_SCRIPT_IDENTITY_UNRESOLVED:{path}")
            result["script_path"] = convergence.normalize_path(resource[1])
    elif suffix == ".tres":
        result["identity_kind"] = "GODOT_RESOURCE"
        header = re.search(
            r'^\[gd_resource\s+type="([^"]+)"(?:\s+script_class="([^"]+)")?[^\]]*\]$',
            text,
            re.MULTILINE,
        )
        if header is None:
            raise MaterializerError(f"RESOURCE_HEADER_IDENTITY_UNRESOLVED:{path}")
        result["resource_type"] = header.group(1)
        result["resource_script_class"] = header.group(2) or ""
        resources = _extract_ext_resources(text)
        script_match = re.search(
            r'^script\s*=\s*ExtResource\("([^"]+)"\)\s*$', text, re.MULTILINE
        )
        if script_match:
            resource = resources.get(script_match.group(1))
            if resource is None or resource[0] != "Script":
                raise MaterializerError(f"RESOURCE_SCRIPT_IDENTITY_UNRESOLVED:{path}")
            result["script_path"] = convergence.normalize_path(resource[1])
    else:
        raise MaterializerError(f"SOURCE_IDENTITY_KIND_UNSUPPORTED:{path}")
    return result


def _canonical_registry_rows(projection: dict[str, Any]) -> list[dict[str, Any]]:
    rows = projection.get("registry_rows")
    if not isinstance(rows, list) or any(not isinstance(row, dict) for row in rows):
        raise MaterializerError("PROJECTION_REGISTRY_ROWS_INVALID")
    stripped = [
        {key: value for key, value in row.items() if key != "authority_source_kind"}
        for row in rows
    ]
    return sorted(stripped, key=canonical)


def _authority_source_hashes(root: Path, head: str) -> dict[str, str]:
    return {
        relative: sha(committed(root, head, relative))
        for relative in convergence.AUTHORITY_SOURCE_PATHS
    }


def _validate_proposal_review(
    root: Path,
    path: Path,
    proposal: dict[str, Any],
    *,
    label: str,
) -> tuple[dict[str, Any], Path, str]:
    review, raw, resolved = _read_external_json(root, path, label=label)
    review_id = str(review.get("review_id", ""))
    if (
        set(review) != PROPOSAL_REVIEW_FIELDS
        or review.get("schema_version") != PROPOSAL_REVIEW_SCHEMA
        or review.get("batch_id") != BATCH_ID
        or review.get("proposal_payload_sha256")
        != proposal.get("proposal_payload_sha256")
        or review.get("evaluated_head_sha") != proposal.get("evaluated_head_sha")
        or review.get("evaluated_tree_sha") != proposal.get("evaluated_tree_sha")
        or review.get("failure_fingerprint_set_sha256")
        != SEALED_MEMBERSHIP_SET_SHA256
        or review_id not in TRUSTED_PROPOSAL_REVIEWERS
        or review.get("reviewer_authority_id")
        != TRUSTED_PROPOSAL_REVIEWERS[review_id]
        or review.get("status") != "GO"
        or not _is_exact_int(review.get("p0_count"), 0)
        or not _is_exact_int(review.get("p1_count"), 0)
        or review.get("findings") != []
        or not _payload_hash_valid(review, "receipt_payload_sha256")
    ):
        raise MaterializerError(f"{label}_INVALID")
    return review, resolved, sha(raw)


def validate_proposal(
    root: Path,
    membership: dict[str, Any],
    proposal_path: Path,
    review_a_path: Path,
    review_b_path: Path,
) -> dict[str, Any]:
    root = root.resolve()
    head, tree = _head_tree(root)
    registry, _registry_bytes = _registry_document(root, head)
    paths = _failure_paths(membership)
    direct_rows = _registry_exact_rows(registry, paths)
    proposal, _proposal_raw, resolved_proposal = _read_external_json(
        root, proposal_path, label="PROJECTION_PROPOSAL"
    )
    candidate = membership["candidate"]
    if (
        set(proposal) != PROPOSAL_FIELDS
        or proposal.get("schema_version") != PROPOSAL_SCHEMA
        or proposal.get("candidate_kind") != PROPOSAL_KIND
        or proposal.get("batch_id") != BATCH_ID
        or proposal.get("membership_candidate_payload_sha256")
        != SEALED_MEMBERSHIP_CANDIDATE_PAYLOAD_SHA256
        or proposal.get("membership_seal_payload_sha256")
        != SEALED_MEMBERSHIP_SEAL_PAYLOAD_SHA256
        or proposal.get("evaluated_head_sha") != head
        or proposal.get("evaluated_tree_sha") != tree
        or proposal.get("authority_source_sha256")
        != _authority_source_hashes(root, head)
        or not _is_exact_int(proposal.get("failure_count"), 50)
        or proposal.get("failure_fingerprints")
        != candidate.get("failure_fingerprints")
        or proposal.get("failure_fingerprint_set_sha256")
        != SEALED_MEMBERSHIP_SET_SHA256
        or proposal.get("required_review_ids") != ["A", "B"]
        or proposal.get("review_status") != "PENDING"
        or proposal.get("go_claim") is not False
        or not _is_exact_int(proposal.get("official_batch_write_count"), 0)
        or not _is_exact_int(proposal.get("official_record_write_count"), 0)
        or not _payload_hash_valid(proposal, "proposal_payload_sha256")
    ):
        raise MaterializerError("PROJECTION_PROPOSAL_CONTRACT_INVALID")
    rows = proposal.get("rows")
    if not isinstance(rows, dict) or set(rows) != set(paths):
        raise MaterializerError("PROJECTION_PROPOSAL_ROW_SET_INVALID")

    reviews = [
        _validate_proposal_review(
            root, review_a_path, proposal, label="PROJECTION_REVIEW_A"
        ),
        _validate_proposal_review(
            root, review_b_path, proposal, label="PROJECTION_REVIEW_B"
        ),
    ]
    if {review[0]["review_id"] for review in reviews} != {"A", "B"}:
        raise MaterializerError("PROJECTION_REVIEW_SET_INVALID")
    if len({review[1] for review in reviews}) != 2:
        raise MaterializerError("PROJECTION_REVIEW_FILE_IDENTITY_INVALID")
    if resolved_proposal in {review[1] for review in reviews}:
        raise MaterializerError("PROJECTION_PROPOSAL_REVIEW_FILE_ALIAS")

    identities, _primary, _legacy = membership_builder._load_authority(root, head)
    validated_bindings: dict[str, dict[str, Any]] = {}
    direct_component_ids: list[str] = []
    direct_class_names: list[str] = []
    for fingerprint in candidate["failure_fingerprints"]:
        proposal_row = rows[fingerprint]
        if not isinstance(proposal_row, dict) or set(proposal_row) != PROPOSAL_ROW_FIELDS:
            raise MaterializerError(f"PROJECTION_ROW_FIELD_SET_INVALID:{fingerprint}")
        if proposal_row.get("failure_fingerprint") != fingerprint:
            raise MaterializerError(f"PROJECTION_ROW_FINGERPRINT_INVALID:{fingerprint}")
        binding = proposal_row.get("identity_binding")
        if (
            not isinstance(binding, dict)
            or set(binding) != set(convergence.IDENTITY_BINDING_FIELDS)
        ):
            raise MaterializerError(f"PROJECTION_BINDING_FIELD_SET_INVALID:{fingerprint}")
        expected_identity = source_identity(
            root, str(binding.get("source_commit", "")), paths[fingerprint]
        )
        if (
            not isinstance(proposal_row.get("source_identity"), dict)
            or set(proposal_row["source_identity"]) != SOURCE_IDENTITY_FIELDS
            or proposal_row["source_identity"] != expected_identity
        ):
            raise MaterializerError(f"SOURCE_IDENTITY_PARITY_INVALID:{fingerprint}")

        selector = binding.get("authority_selectors")
        try:
            actual_projection = convergence.subject_projection(root, head, selector)
        except Exception as exc:
            raise MaterializerError(
                f"SUBJECT_PROJECTION_UNRESOLVED:{fingerprint}"
            ) from exc
        expected_registry_rows = proposal_row.get("expected_registry_rows")
        if (
            not isinstance(expected_registry_rows, list)
            or any(not isinstance(row, dict) for row in expected_registry_rows)
            or expected_registry_rows != sorted(expected_registry_rows, key=canonical)
            or expected_registry_rows != _canonical_registry_rows(actual_projection)
        ):
            raise MaterializerError(
                f"PROPOSAL_REGISTRY_CANONICAL_PARITY_INVALID:{fingerprint}"
            )
        if binding.get("subject_projection") != actual_projection:
            raise MaterializerError(
                f"PROPOSAL_SUBJECT_PROJECTION_PARITY_INVALID:{fingerprint}"
            )
        if binding.get("subject_projection_sha256") != sha(canonical(actual_projection)):
            raise MaterializerError(
                f"PROPOSAL_SUBJECT_PROJECTION_HASH_INVALID:{fingerprint}"
            )
        direct_row = direct_rows[fingerprint]
        if canonical(direct_row) not in {canonical(row) for row in expected_registry_rows}:
            raise MaterializerError(
                f"DIRECT_PATH_REGISTRY_ROW_NOT_PROPOSAL_BOUND:{fingerprint}"
            )
        direct_component_ids.append(str(direct_row.get("component_id", "")))
        direct_class_names.append(str(direct_row.get("class_name", "")))
        declared_class = expected_identity["declared_class_name"]
        if declared_class and direct_row.get("class_name") != declared_class:
            raise MaterializerError(f"GDSCRIPT_CLASS_NAME_SUBSTITUTION:{fingerprint}")
        if (
            expected_identity["identity_kind"] == "GDSCRIPT"
            and not declared_class
            and direct_row.get("class_name") != f"ANONYMOUS_PATH_BOUND:{paths[fingerprint]}"
        ):
            raise MaterializerError(
                f"ANONYMOUS_GDSCRIPT_IDENTITY_SUBSTITUTION:{fingerprint}"
            )

        failures = convergence._authorized_identity_binding_failures(
            root,
            fingerprint,
            binding,
            identities.get(fingerprint),
            record_rule_ids=["HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT"],
        )
        if failures:
            raise MaterializerError(
                f"PROJECTION_BINDING_INVALID:{fingerprint}:{failures[0]}"
            )
        validated_bindings[fingerprint] = binding

    if len(direct_component_ids) != len(set(direct_component_ids)):
        raise MaterializerError("PROPOSAL_COMPONENT_ID_COLLISION")
    if len(direct_class_names) != len(set(direct_class_names)):
        raise MaterializerError("PROPOSAL_CLASS_NAME_COLLISION")
    return {
        "proposal": proposal,
        "proposal_path": resolved_proposal,
        "reviews": {review[0]["review_id"]: review[0] for review in reviews},
        "review_file_sha256": {
            review[0]["review_id"]: review[2] for review in reviews
        },
        "bindings": validated_bindings,
        "authorized_identities": identities,
        "head": head,
        "tree": tree,
    }


def _artifact_documents(
    fingerprints: list[str],
    bindings: dict[str, dict[str, Any]],
    identities: dict[str, dict[str, Any]],
    proposal_reviews: dict[str, dict[str, Any]],
) -> dict[str, dict[str, Any]]:
    inventory_rows: dict[str, Any] = {}
    classifications: dict[str, Any] = {}
    reachability_counts: dict[str, int] = {}
    role_counts: dict[str, int] = {}
    for fingerprint in fingerprints:
        binding = bindings[fingerprint]
        identity = identities[fingerprint]
        reachability = str(binding["current_production_reachability"])
        role = str(binding["current_role"])
        reachability_counts[reachability] = reachability_counts.get(reachability, 0) + 1
        role_counts[role] = role_counts.get(role, 0) + 1
        inventory_rows[fingerprint] = {
            "authority_origin": str(identity.get("authority_origin", "FROZEN_FULL_CONVERGENCE_BASELINE")),
            "current_component_id": binding["current_component_id"],
            "current_path": binding["current_path"],
            "domain_id": binding["domain_id"],
            "failure_fingerprint": fingerprint,
            "historical_component_id": binding["historical_component_id"],
            "historical_path": binding["historical_path"],
            "owner_id": binding["current_owner_id"],
            "production_reachability": reachability == "PRODUCTION_REACHABLE",
            "raw_failure": identity["raw_failure"],
            "recommended_disposition": binding["recommended_disposition"],
            "role": role,
            "rule_id": identity["rule_id"],
            "transition_new_prefix": identity["transition_new_prefix"],
            "transition_old_prefix": identity["transition_old_prefix"],
        }
        classifications[fingerprint] = {
            "failure_fingerprint": fingerprint,
            "production_reachability": reachability,
            "recommended_disposition": binding["recommended_disposition"],
            "role": role,
            "status": "CLASSIFIED",
            "transition_class": binding["recommended_disposition"],
        }
    common = {
        "batch_id": BATCH_ID,
        "failure_count": len(fingerprints),
        "failure_fingerprints": fingerprints,
    }
    return {
        "inventory": {
            "schema_version": convergence.BATCH_ARTIFACT_SPECS["batch_inventory_sha256"][1],
            **common,
            "identity_coverage_percent": 100,
            "unknown_count": 0,
            "rows": inventory_rows,
        },
        "classification": {
            "schema_version": convergence.BATCH_ARTIFACT_SPECS["batch_classification_sha256"][1],
            **common,
            "unknown_count": 0,
            "wildcard_count": 0,
            "classifications": classifications,
        },
        "negative_checks": {
            "schema_version": convergence.BATCH_ARTIFACT_SPECS["batch_negative_checks_sha256"][1],
            **common,
            "status": "PASS",
            "candidate_set_sha256": line_set(fingerprints),
            "candidate_reachability_counts": {
                key: reachability_counts[key] for key in sorted(reachability_counts)
            },
            "candidate_role_counts": {key: role_counts[key] for key in sorted(role_counts)},
            "current_failure_false_accept_count": 0,
            "future_failure_auto_correction_count": 0,
            "wildcard_count": 0,
            "checks": {
                "baseline_membership": True,
                "current_delta_rejection": True,
                "duplicate_fingerprint_rejection": True,
                "exact_registry_projection": True,
                "future_failure_rejection": True,
                "legacy_overlap_rejection": True,
                "mixed_reachability_split": True,
                "proposal_registry_canonical_parity": True,
                "wildcard_rejection": True,
            },
        },
        "review_a": {
            "schema_version": convergence.BATCH_ARTIFACT_SPECS["batch_review_a_sha256"][1],
            **common,
            "review_id": "A",
            "status": proposal_reviews["A"]["status"],
            "p0_count": proposal_reviews["A"]["p0_count"],
            "p1_count": proposal_reviews["A"]["p1_count"],
            "findings": proposal_reviews["A"]["findings"],
        },
        "review_b": {
            "schema_version": convergence.BATCH_ARTIFACT_SPECS["batch_review_b_sha256"][1],
            **common,
            "review_id": "B",
            "status": proposal_reviews["B"]["status"],
            "p0_count": proposal_reviews["B"]["p0_count"],
            "p1_count": proposal_reviews["B"]["p1_count"],
            "findings": proposal_reviews["B"]["findings"],
        },
    }


def _set_values(
    bindings: dict[str, dict[str, Any]],
    binding_fields: tuple[str, ...],
) -> list[str]:
    return sorted({
        str(binding[field])
        for binding in bindings.values()
        for field in binding_fields
        if binding.get(field)
    })


def _selector_values(
    bindings: dict[str, dict[str, Any]], selector_field: str
) -> list[str]:
    return sorted({
        str(value)
        for binding in bindings.values()
        for value in binding["authority_selectors"].get(selector_field, [])
    })


def _record_document(
    *,
    index: int,
    disposition: str,
    suffix: str,
    fingerprints: list[str],
    bindings: dict[str, dict[str, Any]],
    artifact_hashes: dict[str, str],
    authority_hashes: dict[str, str],
    head: str,
    tree: str,
    previous_chain: str,
    supplement_sha256: str,
) -> dict[str, Any]:
    paths = _set_values(bindings, ("historical_path", "current_path"))
    components = _set_values(
        bindings, ("historical_component_id", "current_component_id")
    )
    domains = _set_values(bindings, ("domain_id",))
    owners = _set_values(bindings, ("historical_owner_id", "current_owner_id"))
    dynamic_ids = _selector_values(bindings, "dynamic_reference_ids")
    supersession_ids = _selector_values(bindings, "supersession_ids")
    retirement_ids = _selector_values(bindings, "retirement_ids")
    source_commits = _set_values(bindings, ("source_commit",))
    record = {
        "allowed_from_state": "HISTORICAL_FAILURE_PRESENT_CLASSIFIED",
        "allowed_rule_ids": ["HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT"],
        "allowed_to_state": "CORRECTED_HISTORICAL_DEBT",
        "authority_source_sha256": authority_hashes,
        "authorization_base_head_sha": convergence.AUTHORIZATION_BASE_HEAD_SHA,
        "authorization_id": convergence.AUTHORIZATION_ID,
        "backlog_item_ids": [f"reuse.full-convergence.{BATCH_ID}.{index:02d}"],
        "baseline_failure_set_sha256": convergence.AUTHORIZED_BASELINE_FAILURE_SET_SHA256,
        "baseline_report_sha256": convergence.AUTHORIZED_BASELINE_REPORT_SHA256,
        "batch_classification_sha256": artifact_hashes["batch_classification_sha256"],
        "batch_id": BATCH_ID,
        "batch_inventory_sha256": artifact_hashes["batch_inventory_sha256"],
        "batch_negative_checks_sha256": artifact_hashes["batch_negative_checks_sha256"],
        "batch_review_a_sha256": artifact_hashes["batch_review_a_sha256"],
        "batch_review_b_sha256": artifact_hashes["batch_review_b_sha256"],
        "binding_head_sha": head,
        "binding_tree_sha": tree,
        "component_ids": components,
        "component_set_sha256": line_set(components),
        "correction_id": (
            f"V2-FC-{BATCH_ID}-{index:02d}-46b33bba77b3-"
            f"e584cd4d8b0c-{suffix.lower()}"
        ),
        "correction_reason": (
            "Exact dual-reviewed historical component identity correction for "
            "transition 46b33bba77b3->e584cd4d8b0c."
        ),
        "created_at": CREATED_AT,
        "creator": "V076ReuseFullConvergenceBatch009Materializer",
        "descendant_history_supplement_sha256": supplement_sha256,
        "domain_ids": domains,
        "domain_set_sha256": line_set(domains),
        "dynamic_reference_ids": dynamic_ids,
        "dynamic_reference_set_sha256": line_set(dynamic_ids),
        "failure_classes": ["HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT"],
        "failure_count": len(fingerprints),
        "failure_fingerprint_set_sha256": line_set(fingerprints),
        "failure_fingerprints": fingerprints,
        "from_state": "HISTORICAL_FAILURE_PRESENT_CLASSIFIED",
        "future_failure_policy": {
            "FUTURE_FAILURE_AUTO_CORRECTION_COUNT": 0,
            "NEW_FAILURE_REQUIRES_NEW_RECORD": True,
        },
        "identity_binding_by_failure": bindings,
        "negative_examples": ["CURRENT_DELTA_FAILURE", "WILDCARD"],
        "owner_ids": owners,
        "owner_set_sha256": line_set(owners),
        "path_set_sha256": line_set(paths),
        "paths": paths,
        "previous_correction_chain_sha256": previous_chain,
        "record_kind": "CORRECTION_RECORD",
        "required_untouched_state": True,
        "retirement_ids": retirement_ids,
        "retirement_set_sha256": line_set(retirement_ids),
        "revocation_policy": {
            "OLD_RECORD_MUTATION_FORBIDDEN": True,
            "REVOCATION_APPEND_ONLY": True,
        },
        "rule_ids": ["HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT"],
        "schema_version": convergence.SCHEMA_VERSION,
        "source_commit_set": source_commits,
        "source_commit_set_sha256": line_set(source_commits),
        "supersession_ids": supersession_ids,
        "supersession_set_sha256": line_set(supersession_ids),
        "to_effective_disposition": "CORRECTED_HISTORICAL_DEBT",
        "touch_invalidation_policy": TOUCH_POLICY,
        "transition_class_id": (
            "HISTORICAL_UNCLASSIFIED_COMPONENT_46B33BBA77B3_"
            f"E584CD4D8B0C_{suffix}"
        ),
        "untouched_in_current_delta": True,
    }
    record["record_payload_sha256"] = sha(
        canonical({key: value for key, value in record.items() if key != "record_payload_sha256"})
    )
    return record


def _partition_supported_dispositions(
    fingerprints: list[str],
    bindings: dict[str, dict[str, Any]],
) -> dict[str, list[str]]:
    """Partition exactly fifty identities without inventing an empty class.

    A zero-cardinality supported disposition is a valid observation, not a
    correction record.  In particular, Batch-009 has no supersession authority,
    so emitting a superseded record merely to preserve a fixed file count would
    manufacture evidence.  Unsupported dispositions still fail closed.
    """

    if (
        len(fingerprints) != SEALED_MEMBERSHIP_FAILURE_COUNT
        or len(set(fingerprints)) != SEALED_MEMBERSHIP_FAILURE_COUNT
        or set(bindings) != set(fingerprints)
    ):
        raise MaterializerError("BATCH009_DISPOSITION_COVERAGE_INVALID")
    groups: dict[str, list[str]] = {
        key: [] for key, _filename, _suffix in SUPPORTED_GROUPS
    }
    for fingerprint in fingerprints:
        disposition = str(bindings[fingerprint].get("recommended_disposition", ""))
        if disposition not in groups:
            raise MaterializerError(
                f"BATCH009_UNSUPPORTED_DISPOSITION:{fingerprint}:{disposition}"
            )
        groups[disposition].append(fingerprint)
    for disposition in groups:
        groups[disposition].sort()
    if sum(len(values) for values in groups.values()) != SEALED_MEMBERSHIP_FAILURE_COUNT:
        raise MaterializerError("BATCH009_DISPOSITION_TOTAL_INVALID")
    return groups


def build_documents(
    root: Path,
    validated: dict[str, Any],
) -> dict[str, dict[str, Any]]:
    root = root.resolve()
    proposal = validated["proposal"]
    fingerprints = list(proposal["failure_fingerprints"])
    bindings = validated["bindings"]
    identities = validated["authorized_identities"]
    head = validated["head"]
    tree = validated["tree"]
    groups = _partition_supported_dispositions(fingerprints, bindings)

    artifacts = _artifact_documents(
        fingerprints, bindings, identities, validated["reviews"]
    )
    artifact_by_hash_field = {
        "batch_inventory_sha256": artifacts["inventory"],
        "batch_classification_sha256": artifacts["classification"],
        "batch_negative_checks_sha256": artifacts["negative_checks"],
        "batch_review_a_sha256": artifacts["review_a"],
        "batch_review_b_sha256": artifacts["review_b"],
    }
    artifact_hashes = {
        field: sha(canonical(document))
        for field, document in artifact_by_hash_field.items()
    }

    previous_manifest_rel = BATCH_ROOT / "batch-008" / "batch-008-manifest.json"
    previous_manifest_bytes = committed(root, head, previous_manifest_rel)
    previous_manifest = strict_json_bytes(previous_manifest_bytes, "BATCH008_MANIFEST")
    if not isinstance(previous_manifest, dict) or previous_manifest.get("batch_id") != "batch-008":
        raise MaterializerError("BATCH008_PREDECESSOR_INVALID")
    previous_terminal = str(previous_manifest.get("record_chain_terminal_sha256", ""))
    if re.fullmatch(r"[0-9a-f]{64}", previous_terminal) is None:
        raise MaterializerError("BATCH008_PREDECESSOR_TERMINAL_INVALID")

    authority_hashes = _authority_source_hashes(root, head)
    supplement_sha256 = sha(
        committed(root, head, convergence.DESCENDANT_HISTORY_V3_SUPPLEMENT_REL)
    )
    records: dict[str, dict[str, Any]] = {}
    record_summaries: list[dict[str, Any]] = []
    previous_chain = previous_terminal
    for index, (disposition, filename, suffix) in enumerate(SUPPORTED_GROUPS, 1):
        selected = sorted(groups[disposition])
        if not selected:
            # Zero membership means zero record.  Never emit a no-op correction
            # or imply supersession authority that the reviewed proposal lacks.
            continue
        selected_bindings = {fp: bindings[fp] for fp in selected}
        record = _record_document(
            index=index,
            disposition=disposition,
            suffix=suffix,
            fingerprints=selected,
            bindings=selected_bindings,
            artifact_hashes=artifact_hashes,
            authority_hashes=authority_hashes,
            head=head,
            tree=tree,
            previous_chain=previous_chain,
            supplement_sha256=supplement_sha256,
        )
        document_failures = convergence.validate_extension_record_document(record)
        if document_failures:
            raise MaterializerError(
                f"GENERATED_RECORD_DOCUMENT_INVALID:{filename}:{document_failures[0]}"
            )
        repo_failures = convergence.validate_extension_record_against_repo(
            root,
            record,
            evaluated_head=head,
            authorized_identities=identities,
        )
        if repo_failures:
            raise MaterializerError(
                f"GENERATED_RECORD_REPO_INVALID:{filename}:{repo_failures[0]}"
            )
        relative_output = f"records/batch-009/{filename}"
        official_path = (RECORD_ROOT / "batch-009" / filename).as_posix()
        record_bytes = canonical(record)
        records[relative_output] = record
        record_summaries.append({
            "correction_id": record["correction_id"],
            "failure_fingerprints": selected,
            "failure_count": len(selected),
            "failure_fingerprint_set_sha256": record["failure_fingerprint_set_sha256"],
            "path": official_path,
            "previous_correction_chain_sha256": record["previous_correction_chain_sha256"],
            "record_payload_sha256": record["record_payload_sha256"],
            "record_sha256": sha(record_bytes),
        })
        previous_chain = record["record_payload_sha256"]

    correction_records = {
        "schema_version": "space_syndicate.v076.reuse_full_convergence.batch_correction_records.v1",
        "authoritative_binding_source": "batch-009-manifest.json#record_bindings",
        "batch_id": BATCH_ID,
        "correction_record_count": len(record_summaries),
        "failure_count": len(fingerprints),
        "failure_fingerprint_set_sha256": line_set(fingerprints),
        "records": record_summaries,
    }
    manifest_bindings = [
        {
            key: summary[key]
            for key in (
                "correction_id",
                "failure_fingerprints",
                "path",
                "previous_correction_chain_sha256",
                "record_payload_sha256",
                "record_sha256",
            )
        }
        for summary in record_summaries
    ]
    manifest = {
        "authorization_base_head_sha": convergence.AUTHORIZATION_BASE_HEAD_SHA,
        "authorization_id": convergence.AUTHORIZATION_ID,
        "baseline_failure_set_sha256": convergence.AUTHORIZED_BASELINE_FAILURE_SET_SHA256,
        "baseline_report_sha256": convergence.AUTHORIZED_BASELINE_REPORT_SHA256,
        **artifact_hashes,
        "batch_id": BATCH_ID,
        "batch_review_a_status": "GO",
        "batch_review_b_status": "GO",
        "batch_size_target": "25_TO_50_FAILURE_FINGERPRINTS",
        "batch_unknown_count": 0,
        "batch_wildcard_count": 0,
        "binding_head_sha": head,
        "binding_tree_sha": tree,
        "current_failure_false_accept_count": 0,
        "descendant_history_supplement_sha256": supplement_sha256,
        "failure_count": len(fingerprints),
        "failure_fingerprint_set_sha256": line_set(fingerprints),
        "failure_fingerprints": fingerprints,
        "identity_coverage_percent": 100,
        "previous_batch_append_sha256": sha(previous_manifest_bytes),
        "record_bindings": manifest_bindings,
        "record_chain_start_sha256": previous_terminal,
        "record_chain_terminal_sha256": previous_chain,
        "schema_version": convergence.BATCH_MANIFEST_SCHEMA_VERSION,
        "terminal_remainder_batch": False,
    }
    manifest_failures = convergence.validate_batch_manifest_document(manifest)
    if manifest_failures:
        raise MaterializerError(f"GENERATED_MANIFEST_INVALID:{manifest_failures[0]}")
    for field, (_filename, schema, kind) in convergence.BATCH_ARTIFACT_SPECS.items():
        failures = convergence._validate_batch_artifact_document(
            artifact_by_hash_field[field],
            manifest,
            expected_schema=schema,
            kind=kind,
            authorized_identities=identities,
        )
        if failures:
            raise MaterializerError(
                f"GENERATED_BATCH_ARTIFACT_INVALID:{field}:{failures[0]}"
            )

    documents = {
        "batch-009/batch-009-manifest.json": manifest,
        "batch-009/batch_inventory.json": artifacts["inventory"],
        "batch-009/batch_classification.json": artifacts["classification"],
        "batch-009/batch_correction_records.json": correction_records,
        "batch-009/batch_negative_checks.json": artifacts["negative_checks"],
        "batch-009/batch_review_A.json": artifacts["review_a"],
        "batch-009/batch_review_B.json": artifacts["review_b"],
        **records,
    }
    expected_outputs = set(BASE_OUTPUT_ALLOWLIST) | {
        RECORD_OUTPUT_BY_DISPOSITION[disposition]
        for disposition, values in groups.items()
        if values
    }
    if set(documents) != expected_outputs:
        raise MaterializerError("BATCH009_DOCUMENT_SET_INVALID")
    return documents


def _exclusive_write(stage: Path, relative: str, document: dict[str, Any]) -> None:
    if relative not in OUTPUT_ALLOWLIST:
        raise MaterializerError(f"OUTPUT_PATH_NOT_ALLOWLISTED:{relative}")
    path = stage / Path(relative)
    _reject_reparse_chain(path.parent, "OUTPUT_PARENT")
    resolved = path.resolve(strict=False)
    try:
        resolved.relative_to(stage.resolve())
    except ValueError as exc:
        raise MaterializerError("OUTPUT_PATH_ESCAPE") from exc
    resolved.parent.mkdir(parents=True, exist_ok=True)
    _reject_reparse_chain(resolved.parent, "OUTPUT_PARENT")
    try:
        with resolved.open("xb") as handle:
            handle.write(canonical(document))
            handle.flush()
            os.fsync(handle.fileno())
    except FileExistsError as exc:
        raise MaterializerError(f"APPEND_ONLY_OUTPUT_ALREADY_EXISTS:{relative}") from exc


def _validate_output_document_set(documents: dict[str, dict[str, Any]]) -> set[str]:
    actual = set(documents)
    if not BASE_OUTPUT_ALLOWLIST.issubset(actual):
        raise MaterializerError("OUTPUT_DOCUMENT_BASE_SET_MISMATCH")
    record_outputs = actual - set(BASE_OUTPUT_ALLOWLIST)
    if not record_outputs.issubset(set(RECORD_OUTPUT_BY_DISPOSITION.values())):
        raise MaterializerError("OUTPUT_DOCUMENT_RECORD_SET_MISMATCH")
    if not record_outputs:
        raise MaterializerError("OUTPUT_DOCUMENT_RECORD_SET_EMPTY")
    classification = documents.get("batch-009/batch_classification.json")
    classifications = (
        classification.get("classifications")
        if isinstance(classification, dict)
        else None
    )
    if not isinstance(classifications, dict) or len(classifications) != 50:
        raise MaterializerError("OUTPUT_CLASSIFICATION_SET_INVALID")
    disposition_counts = {
        disposition: 0 for disposition in RECORD_OUTPUT_BY_DISPOSITION
    }
    for fingerprint, row in classifications.items():
        if (
            re.fullmatch(r"V2F-[0-9a-f]{64}", str(fingerprint)) is None
            or not isinstance(row, dict)
        ):
            raise MaterializerError("OUTPUT_CLASSIFICATION_ROW_INVALID")
        disposition = str(row.get("recommended_disposition", ""))
        if disposition not in disposition_counts:
            raise MaterializerError(
                f"OUTPUT_CLASSIFICATION_DISPOSITION_UNSUPPORTED:{disposition}"
            )
        disposition_counts[disposition] += 1
    expected_record_outputs = {
        RECORD_OUTPUT_BY_DISPOSITION[disposition]
        for disposition, count in disposition_counts.items()
        if count
    }
    if record_outputs != expected_record_outputs:
        raise MaterializerError("OUTPUT_RECORD_CLASSIFICATION_PARITY_INVALID")
    return actual


def write_stage(root: Path, stage: Path, documents: dict[str, dict[str, Any]]) -> Path:
    root = root.resolve()
    stage = _require_external_stage(root, stage, "OUTPUT_STAGE")
    if stage.exists():
        raise MaterializerError("OUTPUT_STAGE_MUST_BE_FRESH_NONEXISTENT")
    expected_outputs = _validate_output_document_set(documents)
    # All documents were constructed and validated in memory.  Only now create
    # the stage, and use exclusive writes for every allowlisted path.
    stage.mkdir(parents=True, exist_ok=False)
    for relative in sorted(documents):
        _exclusive_write(stage, relative, documents[relative])
    actual: dict[str, tuple[int, int]] = {}
    identities: set[tuple[int, int]] = set()
    for item in stage.rglob("*"):
        _reject_reparse_chain(item, "OUTPUT_SCAN")
        if not item.is_file():
            continue
        relative = item.relative_to(stage).as_posix()
        info = os.stat(item, follow_symlinks=False)
        if int(getattr(info, "st_nlink", 1)) != 1:
            raise MaterializerError(f"OUTPUT_HARDLINK_FORBIDDEN:{relative}")
        identity = (
            int(getattr(info, "st_dev", 0)),
            int(getattr(info, "st_ino", 0)),
        )
        if identity != (0, 0) and identity in identities:
            raise MaterializerError(f"OUTPUT_HARDLINK_ALIAS:{relative}")
        identities.add(identity)
        actual[relative] = identity
        raw = item.read_bytes()
        document = strict_json_bytes(raw, f"OUTPUT:{relative}")
        if raw != canonical(document) or document != documents[relative]:
            raise MaterializerError(f"OUTPUT_POSTWRITE_PARITY_INVALID:{relative}")
    if set(actual) != expected_outputs:
        raise MaterializerError("OUTPUT_POSTWRITE_FILE_SET_INVALID")
    return stage


def materialize(
    root: Path,
    membership_stage: Path,
    proposal_path: Path,
    review_a_path: Path,
    review_b_path: Path,
    output_stage: Path,
) -> dict[str, Any]:
    root = root.resolve()
    membership = validate_membership_stage(root, membership_stage)
    _membership_stage, validated_output_stage = _require_disjoint_stages(
        root, membership["stage"], output_stage
    )
    # Exact Registry rows are checked before proposal parsing, so the current
    # Head always reports the real authority blocker rather than a missing or
    # speculative proposal.
    preflight_result = preflight(root, membership_stage)
    validated = validate_proposal(
        root, membership, proposal_path, review_a_path, review_b_path
    )
    documents = build_documents(root, validated)
    stage = write_stage(root, validated_output_stage, documents)
    return {
        "status": "PASS",
        "batch_id": BATCH_ID,
        "evaluated_head_sha": validated["head"],
        "evaluated_tree_sha": validated["tree"],
        "failure_count": 50,
        "failure_fingerprint_set_sha256": SEALED_MEMBERSHIP_SET_SHA256,
        "exact_registry_row_count": preflight_result["exact_registry_row_count"],
        "proposal_payload_sha256": validated["proposal"]["proposal_payload_sha256"],
        "output_count": len(documents),
        "staging_root": stage.as_posix(),
        "official_batch_write_count": 0,
        "official_record_write_count": 0,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    subparsers = parser.add_subparsers(dest="command", required=True)
    preflight_parser = subparsers.add_parser("preflight")
    preflight_parser.add_argument("--membership-stage", type=Path, required=True)
    materialize_parser = subparsers.add_parser("materialize")
    materialize_parser.add_argument("--membership-stage", type=Path, required=True)
    materialize_parser.add_argument("--proposal", type=Path, required=True)
    materialize_parser.add_argument("--review-a", type=Path, required=True)
    materialize_parser.add_argument("--review-b", type=Path, required=True)
    materialize_parser.add_argument("--output-stage", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == "preflight":
            result = preflight(args.root, args.membership_stage)
        elif args.command == "materialize":
            result = materialize(
                args.root,
                args.membership_stage,
                args.proposal,
                args.review_a,
                args.review_b,
                args.output_stage,
            )
        else:  # pragma: no cover - argparse keeps this unreachable.
            raise MaterializerError("COMMAND_UNREACHABLE")
    except MaterializerError as exc:
        print(
            json.dumps(
                {
                    "status": "FAIL",
                    "batch_id": BATCH_ID,
                    "error": str(exc),
                    "official_batch_write_count": 0,
                    "official_record_write_count": 0,
                },
                ensure_ascii=False,
                sort_keys=True,
            )
        )
        return 2
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
