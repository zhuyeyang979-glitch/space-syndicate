"""Build and materialize the exact Batch012 historical identity correction.

The frozen membership and dual-reviewed Registry append already exist. This
successor binds those inputs to one committed Head, requires two distinct
external review receipts, and reuses the Batch009 pure document constructors.
It writes only a fresh external stage; official paths remain coordinator-owned.
"""
from __future__ import annotations

import argparse
import base64
import json
import os
from pathlib import Path
from typing import Any

import v076_reuse_exact_failure_correction_v2_full_convergence as convergence
import v076_reuse_full_convergence_batch009_materializer as base
import v076_reuse_full_convergence_batch010_materializer as identities
import v076_reuse_full_convergence_batch012_registry_projection_builder as registry_projection
import v076_reuse_full_convergence_batch_builder as membership_builder


BATCH_ID = "batch-012"
CREATED_AT = "2026-09-05T00:00:00Z"
MEMBERSHIP_COUNT = 39
MEMBERSHIP_SET_SHA256 = registry_projection.FINGERPRINT_SET_SHA
MEMBERSHIP_CANDIDATE_PAYLOAD_SHA256 = registry_projection.MEMBERSHIP_PAYLOAD_SHA
MEMBERSHIP_SEAL_PAYLOAD_SHA256 = (
    "b37246f3857383b8ca22d92687e6fb8ce4893e121264f3a5bde4d9afa013e041"
)
REGISTRY_PROJECTION_REL = Path(
    "reports/reuse/full_convergence/generation10/"
    "batch012_registry_projection_001/registry-candidate.json"
)
MEMBERSHIP_ROOT_REL = Path(
    "reports/reuse/full_convergence/generation10/"
    "historical_identity_batch012_membership_001"
)
REGISTRY_REL = Path("docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json")
BATCH_ROOT = Path(
    "docs/architecture/reuse_corrections/v2/batches/full_convergence_20260827"
)
RECORD_ROOT = Path(
    "docs/architecture/reuse_corrections/v2/records/full_convergence_20260827"
)
PREDECESSOR_REL = BATCH_ROOT / "batch-011" / "batch-011-manifest.json"
PREDECESSOR_SHA256 = (
    "a99427561919d9c8a8da3276d008ee713b213e03851662552048f84310f86b24"
)
PREDECESSOR_TERMINAL_SHA256 = (
    "9d92fec88df9baa132854c020293df74f7e3640f3f2466884e140d798c5f5f3f"
)
LAST_SEEN_COMMIT = convergence.AUTHORIZATION_BASE_HEAD_SHA

PROPOSAL_SCHEMA = (
    "space_syndicate.v076.reuse_full_convergence."
    "batch012_exact_projection_candidate.v1"
)
REVIEW_SCHEMA = (
    "space_syndicate.v076.reuse_full_convergence."
    "batch012_exact_projection_review.v1"
)
PROPOSAL_KIND = "NON_AUTHORITATIVE_EXACT_REGISTRY_PROJECTION_REVIEW_INPUT"
PROPOSAL_FIELDS = base.PROPOSAL_FIELDS
PROPOSAL_ROW_FIELDS = base.PROPOSAL_ROW_FIELDS
REVIEW_FIELDS = base.PROPOSAL_REVIEW_FIELDS
REVIEWERS = base.TRUSTED_PROPOSAL_REVIEWERS

SUPPORTED_GROUPS = (
    (
        "HISTORICAL_TEST_ONLY",
        "transition_46b33bba77b3_e584cd4d8b0c_test-only.json",
        "TEST_ONLY",
    ),
)
BASE_OUTPUTS = frozenset(
    {
        "batch-012/batch-012-manifest.json",
        "batch-012/batch_inventory.json",
        "batch-012/batch_classification.json",
        "batch-012/batch_correction_records.json",
        "batch-012/batch_negative_checks.json",
        "batch-012/batch_review_A.json",
        "batch-012/batch_review_B.json",
    }
)
RECORD_OUTPUTS = {
    disposition: f"records/batch-012/{filename}"
    for disposition, filename, _suffix in SUPPORTED_GROUPS
}
OUTPUT_ALLOWLIST = frozenset({*BASE_OUTPUTS, *RECORD_OUTPUTS.values()})


class Batch012Error(ValueError):
    """Fail-closed Batch012 trust-boundary error."""


def _canonical(value: Any) -> bytes:
    return base.canonical(value)


def _sha(payload: bytes) -> str:
    return base.sha(payload)


def _payload_hash_valid(document: dict[str, Any], field: str) -> bool:
    return base._payload_hash_valid(document, field)


def _head_tree(root: Path) -> tuple[str, str]:
    return base._head_tree(root)


def _strict_committed_file(root: Path, head: str, relative: Path) -> bytes:
    payload = base.committed(root, head, relative)
    path = root / relative
    if not path.is_file() or path.read_bytes() != payload:
        raise Batch012Error(
            f"COMMITTED_WORKTREE_PARITY_INVALID:{relative.as_posix()}"
        )
    return payload


def _require_helper_parity(root: Path, head: str) -> None:
    helpers = (
        Path(__file__).resolve(),
        root
        / "tools/v076/"
        "v076_reuse_full_convergence_batch012_independent_review.py",
    )
    for helper in helpers:
        relative = helper.relative_to(root).as_posix()
        if (
            not helper.is_file()
            or helper.read_bytes() != base.committed(root, head, relative)
        ):
            raise Batch012Error(
                f"EXECUTION_HELPER_NOT_COMMITTED:{relative}"
            )


def validate_membership(root: Path, stage: Path) -> dict[str, Any]:
    root = root.resolve()
    stage = base._require_external_stage(
        root, stage, "BATCH012_MEMBERSHIP_STAGE"
    )
    expected = {
        "membership-candidate.json",
        "membership-review-independent.json",
        "membership-review-primary.json",
        "membership-seal.json",
    }
    if (
        not stage.is_dir()
        or {item.name for item in stage.iterdir() if item.is_file()} != expected
        or any(item.is_dir() for item in stage.iterdir())
    ):
        raise Batch012Error("MEMBERSHIP_STAGE_FILE_SET_INVALID")
    head, _tree = _head_tree(root)
    if not convergence._is_ancestor(
        root, registry_projection.MEMBERSHIP_HEAD, head
    ):
        raise Batch012Error("CURRENT_HEAD_NOT_MEMBERSHIP_DESCENDANT")
    candidate = registry_projection.frozen_members(root)
    documents: dict[str, dict[str, Any]] = {}
    raw_by_name: dict[str, bytes] = {}
    for filename in sorted(expected):
        external = stage / filename
        trusted = base.committed(
            root,
            registry_projection.ARTIFACT_HEAD,
            MEMBERSHIP_ROOT_REL / filename,
        )
        raw = external.read_bytes()
        if raw != trusted:
            raise Batch012Error(
                f"MEMBERSHIP_EXTERNAL_COMMITTED_DRIFT:{filename}"
            )
        raw_by_name[filename] = raw
        documents[filename] = base.strict_json_bytes(raw, filename)
    if documents["membership-candidate.json"] != candidate:
        raise Batch012Error("MEMBERSHIP_CANDIDATE_OBJECT_DRIFT")
    seal = documents["membership-seal.json"]
    if (
        seal.get("seal_payload_sha256") != MEMBERSHIP_SEAL_PAYLOAD_SHA256
        or not _payload_hash_valid(seal, "seal_payload_sha256")
        or seal.get("candidate_payload_sha256")
        != MEMBERSHIP_CANDIDATE_PAYLOAD_SHA256
        or seal.get("review_status") != "DUAL_REVIEW_PASS"
        or seal.get("go_claim") is not True
        or seal.get("official_batch_write_count") != 0
        or seal.get("official_record_write_count") != 0
    ):
        raise Batch012Error("MEMBERSHIP_SEAL_INVALID")
    if Path(str(seal.get("candidate_path", ""))).resolve() != (
        stage / "membership-candidate.json"
    ).resolve():
        raise Batch012Error("MEMBERSHIP_SEAL_CANDIDATE_PATH_INVALID")
    review_names = {
        "INDEPENDENT": "membership-review-independent.json",
        "PRIMARY": "membership-review-primary.json",
    }
    references = seal.get("review_receipts")
    if not isinstance(references, list) or [
        row.get("review_id") for row in references
    ] != ["INDEPENDENT", "PRIMARY"]:
        raise Batch012Error("MEMBERSHIP_REVIEW_REFERENCE_SET_INVALID")
    for reference in references:
        review_id = str(reference.get("review_id", ""))
        filename = review_names.get(review_id)
        if (
            not filename
            or Path(str(reference.get("path", ""))).resolve()
            != (stage / filename).resolve()
            or reference.get("sha256") != _sha(raw_by_name[filename])
        ):
            raise Batch012Error("MEMBERSHIP_REVIEW_REFERENCE_INVALID")
        review = documents[filename]
        if (
            review.get("review_id") != review_id
            or review.get("status") != "GO"
            or review.get("p0_count") != 0
            or review.get("p1_count") != 0
            or review.get("findings") != []
            or not _payload_hash_valid(review, "receipt_payload_sha256")
        ):
            raise Batch012Error(f"MEMBERSHIP_REVIEW_INVALID:{review_id}")
    return {"candidate": candidate, "seal": seal, "stage": stage}


def _projection_evidence(root: Path, head: str) -> dict[str, Any]:
    raw = _strict_committed_file(root, head, REGISTRY_PROJECTION_REL)
    document = base.strict_json_bytes(raw, "BATCH012_REGISTRY_PROJECTION")
    if (
        document.get("batch_id") != BATCH_ID
        or document.get("failure_count") != MEMBERSHIP_COUNT
        or document.get("failure_fingerprint_set_sha256")
        != MEMBERSHIP_SET_SHA256
        or document.get("classification_counts")
        != {"HISTORICAL_TEST_ONLY": 39}
        or document.get("appended_path_row_count") != 39
        or document.get("unchanged_reused_member_count") != 0
        or document.get("old_component_row_mutation_count") != 0
        or document.get("new_owner_count") != 0
        or document.get("go_claim") is not False
        or not _payload_hash_valid(document, "payload_sha256")
        or not convergence._is_ancestor(
            root, str(document.get("binding_head_sha", "")), head
        )
    ):
        raise Batch012Error("REGISTRY_PROJECTION_EVIDENCE_INVALID")
    target = document.get("target_registry")
    if not isinstance(target, dict):
        raise Batch012Error("REGISTRY_PROJECTION_TARGET_INVALID")
    try:
        target_bytes = base64.b64decode(
            target.get("target_bytes_base64", ""), validate=True
        )
    except Exception as exc:
        raise Batch012Error("REGISTRY_PROJECTION_TARGET_BASE64_INVALID") from exc
    registry_bytes = _strict_committed_file(root, head, REGISTRY_REL)
    if (
        _sha(target_bytes) != target.get("target_sha256")
        or target_bytes != registry_bytes
    ):
        raise Batch012Error(
            "REGISTRY_PROJECTION_TARGET_NOT_CURRENT_AUTHORITY"
        )
    rows = document.get("rows")
    if not isinstance(rows, list) or len(rows) != MEMBERSHIP_COUNT:
        raise Batch012Error("REGISTRY_PROJECTION_ROW_SET_INVALID")
    by_fingerprint = {
        str(row.get("failure_fingerprint", "")): row
        for row in rows
        if isinstance(row, dict)
    }
    if len(by_fingerprint) != MEMBERSHIP_COUNT:
        raise Batch012Error("REGISTRY_PROJECTION_ROW_IDENTITY_INVALID")
    for binding in document.get("source_graph_bindings", []):
        path = str(binding.get("path", ""))
        if base.git(root, "rev-parse", f"{head}:{path}") != binding.get(
            "binding_head_git_object"
        ):
            raise Batch012Error(
                f"REGISTRY_PROJECTION_SOURCE_GRAPH_DRIFT:{path}"
            )
    return {"document": document, "rows": by_fingerprint}


def _binding(
    root: Path,
    head: str,
    fingerprint: str,
    path: str,
    proof: dict[str, Any],
    identity: dict[str, Any],
) -> tuple[dict[str, Any], dict[str, Any]]:
    row = proof.get("component_row")
    if (
        not isinstance(row, dict)
        or proof.get("recommended_disposition") != "HISTORICAL_TEST_ONLY"
        or proof.get("current_production_reachability") != "TEST_ONLY"
        or row.get("component_role") != "TEST_SUPPORT"
        or row.get("production_reachable") is not False
        or row.get("writes_authority") is not False
    ):
        raise Batch012Error(
            f"PROJECTION_PROOF_CLASSIFICATION_INVALID:{fingerprint}"
        )
    historical_source = identities.source_identity(
        root, registry_projection.SOURCE, path
    )
    current_source = identities.source_identity(root, head, path)
    if (
        proof.get("historical_source_identity") != historical_source
        or proof.get("current_source_identity") != current_source
        or historical_source != current_source
        or proof.get("source_commit") != registry_projection.SOURCE
        or proof.get("raw_failure") != identity.get("raw_failure")
    ):
        raise Batch012Error(
            f"PROJECTION_PROOF_SOURCE_IDENTITY_DRIFT:{fingerprint}"
        )
    component_id = str(row.get("component_id", ""))
    owner_id = str(row.get("owner_component_id", ""))
    selector = {
        "component_ids": sorted([component_id, owner_id]),
        "dynamic_reference_ids": [],
        "paths": [path],
        "retirement_ids": [],
        "supersession_ids": [],
    }
    projection = convergence.subject_projection(root, head, selector)
    binding = {
        "authority_selectors": selector,
        "current_blob_sha256": current_source["source_blob_sha256"],
        "current_component_id": component_id,
        "current_owner_id": owner_id,
        "current_path": path,
        "current_production_reachability": "TEST_ONLY",
        "current_role": "TEST_SUPPORT",
        "diagnostic_only_status": "NOT_DIAGNOSTIC_ONLY",
        "documentation_only_status": "NOT_DOCUMENTATION_ONLY",
        "domain_id": str(row.get("domain_id", "")),
        "duplicate_identity_sha256": "",
        "duplicate_of_failure_fingerprint": "",
        "duplicate_reason": "",
        "dynamic_reference_status": "NOT_DYNAMIC_REFERENCE",
        "first_seen_commit": registry_projection.SOURCE,
        "generated_evidence_status": "NOT_GENERATED_EVIDENCE",
        "historical_blob_sha256": historical_source["source_blob_sha256"],
        "historical_component_id": component_id,
        "historical_owner_id": owner_id,
        "historical_path": path,
        "historical_production_reachability": "TEST_ONLY",
        "historical_role": "TEST_SUPPORT",
        "invalidation_policy": base.TOUCH_POLICY,
        "last_seen_commit": LAST_SEEN_COMMIT,
        "recommended_disposition": "HISTORICAL_TEST_ONLY",
        "retired_status": "NOT_RETIRED",
        "source_commit": registry_projection.SOURCE,
        "subject_projection": projection,
        "subject_projection_sha256": _sha(_canonical(projection)),
        "superseded_by": list(row.get("superseded_by", [])),
        "supersedes": list(row.get("supersedes", [])),
        "test_only_status": "TEST_ONLY",
    }
    if set(binding) != set(convergence.IDENTITY_BINDING_FIELDS):
        raise Batch012Error(
            f"GENERATED_BINDING_FIELD_SET_INVALID:{fingerprint}"
        )
    failures = convergence._authorized_identity_binding_failures(
        root,
        fingerprint,
        binding,
        identity,
        record_rule_ids=["HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT"],
    )
    if failures:
        raise Batch012Error(
            f"GENERATED_BINDING_INVALID:{fingerprint}:{failures[0]}"
        )
    return binding, historical_source


def build_proposal(root: Path, membership_stage: Path) -> dict[str, Any]:
    root = root.resolve()
    membership = validate_membership(root, membership_stage)
    head, tree = _head_tree(root)
    _require_helper_parity(root, head)
    evidence = _projection_evidence(root, head)
    candidate = membership["candidate"]
    fingerprints = list(candidate["failure_fingerprints"])
    if set(evidence["rows"]) != set(fingerprints):
        raise Batch012Error("REGISTRY_PROJECTION_MEMBERSHIP_SET_MISMATCH")
    registry_document = base.strict_json_bytes(
        _strict_committed_file(root, head, REGISTRY_REL), "REGISTRY"
    )
    direct_rows = base._registry_exact_rows(
        registry_document,
        {
            fingerprint: candidate["rows"][fingerprint]["subject_value"]
            for fingerprint in fingerprints
        },
    )
    authorized, _primary, _legacy = membership_builder._load_authority(
        root, head
    )
    proposal_rows: dict[str, Any] = {}
    for fingerprint in fingerprints:
        path = str(candidate["rows"][fingerprint]["subject_value"])
        proof = evidence["rows"][fingerprint]
        if proof.get("component_row") != direct_rows[fingerprint]:
            raise Batch012Error(
                f"DIRECT_REGISTRY_ROW_PROOF_DRIFT:{fingerprint}"
            )
        binding, source = _binding(
            root,
            head,
            fingerprint,
            path,
            proof,
            authorized[fingerprint],
        )
        proposal_rows[fingerprint] = {
            "failure_fingerprint": fingerprint,
            "source_identity": source,
            "expected_registry_rows": base._canonical_registry_rows(
                binding["subject_projection"]
            ),
            "identity_binding": binding,
        }
    proposal = {
        "schema_version": PROPOSAL_SCHEMA,
        "candidate_kind": PROPOSAL_KIND,
        "batch_id": BATCH_ID,
        "membership_candidate_payload_sha256": (
            MEMBERSHIP_CANDIDATE_PAYLOAD_SHA256
        ),
        "membership_seal_payload_sha256": MEMBERSHIP_SEAL_PAYLOAD_SHA256,
        "evaluated_head_sha": head,
        "evaluated_tree_sha": tree,
        "authority_source_sha256": base._authority_source_hashes(root, head),
        "failure_count": MEMBERSHIP_COUNT,
        "failure_fingerprints": fingerprints,
        "failure_fingerprint_set_sha256": MEMBERSHIP_SET_SHA256,
        "rows": proposal_rows,
        "required_review_ids": ["A", "B"],
        "review_status": "PENDING",
        "go_claim": False,
        "official_batch_write_count": 0,
        "official_record_write_count": 0,
    }
    proposal["proposal_payload_sha256"] = _sha(_canonical(proposal))
    validate_proposal_document(root, membership, proposal)
    return proposal


def validate_proposal_document(
    root: Path,
    membership: dict[str, Any],
    proposal: dict[str, Any],
) -> dict[str, Any]:
    root = root.resolve()
    head, tree = _head_tree(root)
    candidate = membership["candidate"]
    if (
        set(proposal) != PROPOSAL_FIELDS
        or proposal.get("schema_version") != PROPOSAL_SCHEMA
        or proposal.get("candidate_kind") != PROPOSAL_KIND
        or proposal.get("batch_id") != BATCH_ID
        or proposal.get("membership_candidate_payload_sha256")
        != MEMBERSHIP_CANDIDATE_PAYLOAD_SHA256
        or proposal.get("membership_seal_payload_sha256")
        != MEMBERSHIP_SEAL_PAYLOAD_SHA256
        or proposal.get("evaluated_head_sha") != head
        or proposal.get("evaluated_tree_sha") != tree
        or proposal.get("authority_source_sha256")
        != base._authority_source_hashes(root, head)
        or proposal.get("failure_count") != MEMBERSHIP_COUNT
        or proposal.get("failure_fingerprints")
        != candidate.get("failure_fingerprints")
        or proposal.get("failure_fingerprint_set_sha256")
        != MEMBERSHIP_SET_SHA256
        or proposal.get("required_review_ids") != ["A", "B"]
        or proposal.get("review_status") != "PENDING"
        or proposal.get("go_claim") is not False
        or proposal.get("official_batch_write_count") != 0
        or proposal.get("official_record_write_count") != 0
        or not _payload_hash_valid(proposal, "proposal_payload_sha256")
    ):
        raise Batch012Error("PROPOSAL_CONTRACT_INVALID")
    rows = proposal.get("rows")
    fingerprints = list(candidate["failure_fingerprints"])
    if not isinstance(rows, dict) or set(rows) != set(fingerprints):
        raise Batch012Error("PROPOSAL_ROW_SET_INVALID")
    authorized, _primary, _legacy = membership_builder._load_authority(
        root, head
    )
    bindings: dict[str, dict[str, Any]] = {}
    for fingerprint in fingerprints:
        proposal_row = rows[fingerprint]
        if (
            not isinstance(proposal_row, dict)
            or set(proposal_row) != PROPOSAL_ROW_FIELDS
            or proposal_row.get("failure_fingerprint") != fingerprint
        ):
            raise Batch012Error(f"PROPOSAL_ROW_INVALID:{fingerprint}")
        binding = proposal_row.get("identity_binding")
        path = str(candidate["rows"][fingerprint]["subject_value"])
        source = identities.source_identity(
            root, registry_projection.SOURCE, path
        )
        if (
            not isinstance(binding, dict)
            or set(binding) != set(convergence.IDENTITY_BINDING_FIELDS)
            or proposal_row.get("source_identity") != source
        ):
            raise Batch012Error(
                f"PROPOSAL_BINDING_OR_SOURCE_INVALID:{fingerprint}"
            )
        actual_projection = convergence.subject_projection(
            root, head, binding["authority_selectors"]
        )
        if (
            binding.get("subject_projection") != actual_projection
            or binding.get("subject_projection_sha256")
            != _sha(_canonical(actual_projection))
            or proposal_row.get("expected_registry_rows")
            != base._canonical_registry_rows(actual_projection)
        ):
            raise Batch012Error(
                f"PROPOSAL_PROJECTION_INVALID:{fingerprint}"
            )
        failures = convergence._authorized_identity_binding_failures(
            root,
            fingerprint,
            binding,
            authorized.get(fingerprint),
            record_rule_ids=["HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT"],
        )
        if failures:
            raise Batch012Error(
                f"PROPOSAL_BINDING_INVALID:{fingerprint}:{failures[0]}"
            )
        bindings[fingerprint] = binding
    return {
        "proposal": proposal,
        "bindings": bindings,
        "authorized_identities": authorized,
        "head": head,
        "tree": tree,
    }


def _external_document(
    root: Path, path: Path, label: str
) -> tuple[dict[str, Any], bytes, Path]:
    try:
        return base._read_external_json(root, path, label=label)
    except base.MaterializerError as exc:
        raise Batch012Error(str(exc)) from exc


def _write_external_document(
    root: Path, path: Path, document: dict[str, Any]
) -> Path:
    root = root.resolve()
    resolved = path.resolve(strict=False)
    try:
        resolved.relative_to(root)
    except ValueError:
        pass
    else:
        raise Batch012Error("EXTERNAL_OUTPUT_INSIDE_REPOSITORY")
    if resolved.exists():
        raise Batch012Error("APPEND_ONLY_EXTERNAL_OUTPUT_EXISTS")
    resolved.parent.mkdir(parents=True, exist_ok=True)
    base._reject_reparse_chain(resolved.parent, "EXTERNAL_OUTPUT_PARENT")
    try:
        with resolved.open("xb") as handle:
            handle.write(_canonical(document))
            handle.flush()
            os.fsync(handle.fileno())
    except FileExistsError as exc:
        raise Batch012Error("APPEND_ONLY_EXTERNAL_OUTPUT_EXISTS") from exc
    return resolved


def review_a(
    root: Path,
    membership_stage: Path,
    proposal_path: Path,
    output: Path,
) -> dict[str, Any]:
    membership = validate_membership(root, membership_stage)
    proposal, _raw, _resolved = _external_document(
        root, proposal_path, "PROPOSAL_A"
    )
    validate_proposal_document(root, membership, proposal)
    review = {
        "schema_version": REVIEW_SCHEMA,
        "batch_id": BATCH_ID,
        "proposal_payload_sha256": proposal["proposal_payload_sha256"],
        "evaluated_head_sha": proposal["evaluated_head_sha"],
        "evaluated_tree_sha": proposal["evaluated_tree_sha"],
        "failure_fingerprint_set_sha256": MEMBERSHIP_SET_SHA256,
        "review_id": "A",
        "reviewer_authority_id": REVIEWERS["A"],
        "findings": [],
        "p0_count": 0,
        "p1_count": 0,
        "status": "GO",
    }
    review["receipt_payload_sha256"] = _sha(_canonical(review))
    path = _write_external_document(root, output, review)
    return {
        "status": "PASS",
        "review_id": "A",
        "path": path.as_posix(),
        "sha256": _sha(path.read_bytes()),
    }


def _review(
    root: Path,
    path: Path,
    proposal: dict[str, Any],
    expected_id: str,
) -> tuple[dict[str, Any], Path]:
    review, _raw, resolved = _external_document(
        root, path, f"REVIEW_{expected_id}"
    )
    if (
        set(review) != REVIEW_FIELDS
        or review.get("schema_version") != REVIEW_SCHEMA
        or review.get("batch_id") != BATCH_ID
        or review.get("proposal_payload_sha256")
        != proposal.get("proposal_payload_sha256")
        or review.get("evaluated_head_sha")
        != proposal.get("evaluated_head_sha")
        or review.get("evaluated_tree_sha")
        != proposal.get("evaluated_tree_sha")
        or review.get("failure_fingerprint_set_sha256")
        != MEMBERSHIP_SET_SHA256
        or review.get("review_id") != expected_id
        or review.get("reviewer_authority_id") != REVIEWERS[expected_id]
        or review.get("status") != "GO"
        or review.get("p0_count") != 0
        or review.get("p1_count") != 0
        or review.get("findings") != []
        or not _payload_hash_valid(review, "receipt_payload_sha256")
    ):
        raise Batch012Error(f"REVIEW_INVALID:{expected_id}")
    return review, resolved


def build_documents(
    root: Path,
    validated: dict[str, Any],
    reviews: dict[str, dict[str, Any]],
) -> dict[str, dict[str, Any]]:
    fingerprints = list(validated["proposal"]["failure_fingerprints"])
    bindings = validated["bindings"]
    authorized = validated["authorized_identities"]
    head = validated["head"]
    tree = validated["tree"]
    if (
        len(fingerprints) != MEMBERSHIP_COUNT
        or any(
            binding.get("recommended_disposition")
            != "HISTORICAL_TEST_ONLY"
            for binding in bindings.values()
        )
    ):
        raise Batch012Error("DISPOSITION_CARDINALITY_INVALID")

    artifacts = base._artifact_documents(
        fingerprints,
        bindings,
        authorized,
        reviews,
        batch_id=BATCH_ID,
    )
    artifact_by_field = {
        "batch_inventory_sha256": artifacts["inventory"],
        "batch_classification_sha256": artifacts["classification"],
        "batch_negative_checks_sha256": artifacts["negative_checks"],
        "batch_review_a_sha256": artifacts["review_a"],
        "batch_review_b_sha256": artifacts["review_b"],
    }
    artifact_hashes = {
        field: _sha(_canonical(document))
        for field, document in artifact_by_field.items()
    }
    predecessor_bytes = base.committed(root, head, PREDECESSOR_REL)
    predecessor = base.strict_json_bytes(
        predecessor_bytes, "BATCH011_PREDECESSOR"
    )
    if (
        _sha(predecessor_bytes) != PREDECESSOR_SHA256
        or predecessor.get("batch_id") != "batch-011"
        or predecessor.get("record_chain_terminal_sha256")
        != PREDECESSOR_TERMINAL_SHA256
    ):
        raise Batch012Error("BATCH011_PREDECESSOR_INVALID")
    authority_hashes = base._authority_source_hashes(root, head)
    supplement_sha256 = _sha(
        base.committed(
            root, head, convergence.DESCENDANT_HISTORY_V3_SUPPLEMENT_REL
        )
    )
    disposition, filename, suffix = SUPPORTED_GROUPS[0]
    record = base._record_document(
        index=1,
        disposition=disposition,
        suffix=suffix,
        fingerprints=sorted(fingerprints),
        bindings={fingerprint: bindings[fingerprint] for fingerprint in sorted(fingerprints)},
        artifact_hashes=artifact_hashes,
        authority_hashes=authority_hashes,
        head=head,
        tree=tree,
        previous_chain=PREDECESSOR_TERMINAL_SHA256,
        supplement_sha256=supplement_sha256,
        batch_id=BATCH_ID,
        created_at=CREATED_AT,
        creator="V076ReuseFullConvergenceBatch012Materializer",
    )
    failures = convergence.validate_extension_record_document(record)
    if failures:
        raise Batch012Error(
            f"GENERATED_RECORD_INVALID:{filename}:{failures[0]}"
        )
    failures = convergence.validate_extension_record_against_repo(
        root,
        record,
        evaluated_head=head,
        authorized_identities=authorized,
    )
    if failures:
        raise Batch012Error(
            f"GENERATED_RECORD_REPO_INVALID:{filename}:{failures[0]}"
        )
    record_relative = f"records/batch-012/{filename}"
    record_path = (RECORD_ROOT / "batch-012" / filename).as_posix()
    record_sha256 = _sha(_canonical(record))
    summary = {
        "correction_id": record["correction_id"],
        "failure_fingerprints": sorted(fingerprints),
        "failure_count": MEMBERSHIP_COUNT,
        "failure_fingerprint_set_sha256": record[
            "failure_fingerprint_set_sha256"
        ],
        "path": record_path,
        "previous_correction_chain_sha256": record[
            "previous_correction_chain_sha256"
        ],
        "record_payload_sha256": record["record_payload_sha256"],
        "record_sha256": record_sha256,
    }
    correction_records = {
        "schema_version": (
            "space_syndicate.v076.reuse_full_convergence."
            "batch_correction_records.v1"
        ),
        "authoritative_binding_source": (
            "batch-012-manifest.json#record_bindings"
        ),
        "batch_id": BATCH_ID,
        "correction_record_count": 1,
        "failure_count": MEMBERSHIP_COUNT,
        "failure_fingerprint_set_sha256": MEMBERSHIP_SET_SHA256,
        "records": [summary],
    }
    manifest_binding = {
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
    manifest = {
        "authorization_base_head_sha": convergence.AUTHORIZATION_BASE_HEAD_SHA,
        "authorization_id": convergence.AUTHORIZATION_ID,
        "baseline_failure_set_sha256": (
            convergence.AUTHORIZED_BASELINE_FAILURE_SET_SHA256
        ),
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
        "failure_count": MEMBERSHIP_COUNT,
        "failure_fingerprint_set_sha256": MEMBERSHIP_SET_SHA256,
        "failure_fingerprints": fingerprints,
        "identity_coverage_percent": 100,
        "previous_batch_append_sha256": PREDECESSOR_SHA256,
        "record_bindings": [manifest_binding],
        "record_chain_start_sha256": PREDECESSOR_TERMINAL_SHA256,
        "record_chain_terminal_sha256": record["record_payload_sha256"],
        "schema_version": convergence.BATCH_MANIFEST_SCHEMA_VERSION,
        "terminal_remainder_batch": False,
    }
    failures = convergence.validate_batch_manifest_document(manifest)
    if failures:
        raise Batch012Error(f"GENERATED_MANIFEST_INVALID:{failures[0]}")
    for field, (_name, schema, kind) in convergence.BATCH_ARTIFACT_SPECS.items():
        failures = convergence._validate_batch_artifact_document(
            artifact_by_field[field],
            manifest,
            expected_schema=schema,
            kind=kind,
            authorized_identities=authorized,
        )
        if failures:
            raise Batch012Error(
                f"GENERATED_ARTIFACT_INVALID:{field}:{failures[0]}"
            )
    documents = {
        "batch-012/batch-012-manifest.json": manifest,
        "batch-012/batch_inventory.json": artifacts["inventory"],
        "batch-012/batch_classification.json": artifacts["classification"],
        "batch-012/batch_correction_records.json": correction_records,
        "batch-012/batch_negative_checks.json": artifacts["negative_checks"],
        "batch-012/batch_review_A.json": artifacts["review_a"],
        "batch-012/batch_review_B.json": artifacts["review_b"],
        record_relative: record,
    }
    if set(documents) != OUTPUT_ALLOWLIST:
        raise Batch012Error("OUTPUT_DOCUMENT_SET_INVALID")
    return documents


def write_stage(
    root: Path, stage: Path, documents: dict[str, dict[str, Any]]
) -> Path:
    root = root.resolve()
    stage = base._require_external_stage(root, stage, "BATCH012_OUTPUT_STAGE")
    if stage.exists():
        raise Batch012Error("OUTPUT_STAGE_MUST_BE_FRESH")
    stage.mkdir(parents=True, exist_ok=False)
    for relative in sorted(documents):
        if relative not in OUTPUT_ALLOWLIST:
            raise Batch012Error(f"OUTPUT_PATH_NOT_ALLOWLISTED:{relative}")
        path = stage / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        base._reject_reparse_chain(path.parent, "OUTPUT_PARENT")
        with path.open("xb") as handle:
            handle.write(_canonical(documents[relative]))
            handle.flush()
            os.fsync(handle.fileno())
    actual = {
        path.relative_to(stage).as_posix()
        for path in stage.rglob("*")
        if path.is_file()
    }
    if actual != OUTPUT_ALLOWLIST:
        raise Batch012Error("OUTPUT_POSTWRITE_SET_INVALID")
    for relative, document in documents.items():
        if (stage / relative).read_bytes() != _canonical(document):
            raise Batch012Error(f"OUTPUT_POSTWRITE_PARITY_INVALID:{relative}")
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
    membership = validate_membership(root, membership_stage)
    proposal, _raw, proposal_resolved = _external_document(
        root, proposal_path, "PROPOSAL"
    )
    validated = validate_proposal_document(root, membership, proposal)
    review_a_document, review_a_resolved = _review(
        root, review_a_path, proposal, "A"
    )
    review_b_document, review_b_resolved = _review(
        root, review_b_path, proposal, "B"
    )
    if len({proposal_resolved, review_a_resolved, review_b_resolved}) != 3:
        raise Batch012Error("PROPOSAL_REVIEW_FILE_ALIAS")
    documents = build_documents(
        root,
        validated,
        {"A": review_a_document, "B": review_b_document},
    )
    stage = write_stage(root, output_stage, documents)
    return {
        "status": "PASS",
        "batch_id": BATCH_ID,
        "evaluated_head_sha": validated["head"],
        "evaluated_tree_sha": validated["tree"],
        "failure_count": MEMBERSHIP_COUNT,
        "failure_fingerprint_set_sha256": MEMBERSHIP_SET_SHA256,
        "proposal_payload_sha256": proposal["proposal_payload_sha256"],
        "output_count": len(documents),
        "staging_root": stage.as_posix(),
        "official_batch_write_count": 0,
        "official_record_write_count": 0,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    commands = parser.add_subparsers(dest="command", required=True)
    proposal = commands.add_parser("proposal")
    proposal.add_argument("--membership-stage", type=Path, required=True)
    proposal.add_argument("--output", type=Path, required=True)
    primary = commands.add_parser("review-a")
    primary.add_argument("--membership-stage", type=Path, required=True)
    primary.add_argument("--proposal", type=Path, required=True)
    primary.add_argument("--output", type=Path, required=True)
    materializer = commands.add_parser("materialize")
    materializer.add_argument("--membership-stage", type=Path, required=True)
    materializer.add_argument("--proposal", type=Path, required=True)
    materializer.add_argument("--review-a", type=Path, required=True)
    materializer.add_argument("--review-b", type=Path, required=True)
    materializer.add_argument("--output-stage", type=Path, required=True)
    args = parser.parse_args()
    try:
        if args.command == "proposal":
            document = build_proposal(args.root, args.membership_stage)
            path = _write_external_document(args.root, args.output, document)
            result = {
                "status": "PASS",
                "batch_id": BATCH_ID,
                "proposal_payload_sha256": document[
                    "proposal_payload_sha256"
                ],
                "path": path.as_posix(),
                "sha256": _sha(path.read_bytes()),
            }
        elif args.command == "review-a":
            result = review_a(
                args.root,
                args.membership_stage,
                args.proposal,
                args.output,
            )
        else:
            result = materialize(
                args.root,
                args.membership_stage,
                args.proposal,
                args.review_a,
                args.review_b,
                args.output_stage,
            )
    except (
        Batch012Error,
        base.MaterializerError,
        membership_builder.BuilderError,
    ) as exc:
        print(
            json.dumps(
                {"status": "FAIL", "batch_id": BATCH_ID, "error": str(exc)},
                sort_keys=True,
            )
        )
        return 2
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
