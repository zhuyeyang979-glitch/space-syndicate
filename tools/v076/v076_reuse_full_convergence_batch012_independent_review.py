"""Independent read-only proposal audit and external B receipt for Batch012."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import v076_reuse_exact_failure_correction_v2_full_convergence as convergence
import v076_reuse_full_convergence_batch009_materializer as base
import v076_reuse_full_convergence_batch010_materializer as identities
import v076_reuse_full_convergence_batch012_materializer as batch012
import v076_reuse_full_convergence_batch_builder as membership_builder


class IndependentReviewError(ValueError):
    pass


def audit(
    root: Path, membership_stage: Path, proposal_path: Path
) -> dict[str, Any]:
    root = root.resolve()
    membership = batch012.validate_membership(root, membership_stage)
    proposal, raw, resolved = base._read_external_json(
        root, proposal_path, label="INDEPENDENT_PROPOSAL"
    )
    head, tree = base._head_tree(root)
    if (
        set(proposal) != batch012.PROPOSAL_FIELDS
        or proposal.get("schema_version") != batch012.PROPOSAL_SCHEMA
        or proposal.get("candidate_kind") != batch012.PROPOSAL_KIND
        or proposal.get("evaluated_head_sha") != head
        or proposal.get("evaluated_tree_sha") != tree
        or proposal.get("failure_count") != batch012.MEMBERSHIP_COUNT
        or proposal.get("failure_fingerprint_set_sha256")
        != batch012.MEMBERSHIP_SET_SHA256
        or proposal.get("failure_fingerprints")
        != membership["candidate"]["failure_fingerprints"]
        or proposal.get("authority_source_sha256")
        != base._authority_source_hashes(root, head)
        or not base._payload_hash_valid(proposal, "proposal_payload_sha256")
        or raw != base.canonical(proposal)
    ):
        raise IndependentReviewError("INDEPENDENT_PROPOSAL_CONTRACT_INVALID")
    authorized, _primary, _legacy = membership_builder._load_authority(root, head)
    seen_paths: set[str] = set()
    seen_components: set[str] = set()
    for fingerprint in proposal["failure_fingerprints"]:
        row = proposal["rows"].get(fingerprint)
        member = membership["candidate"]["rows"][fingerprint]
        if not isinstance(row, dict) or set(row) != batch012.PROPOSAL_ROW_FIELDS:
            raise IndependentReviewError(
                f"INDEPENDENT_ROW_INVALID:{fingerprint}"
            )
        binding = row.get("identity_binding")
        path = str(member.get("subject_value", ""))
        if (
            not isinstance(binding, dict)
            or set(binding) != set(convergence.IDENTITY_BINDING_FIELDS)
            or row.get("failure_fingerprint") != fingerprint
            or row.get("source_identity")
            != identities.source_identity(
                root, batch012.registry_projection.SOURCE, path
            )
        ):
            raise IndependentReviewError(
                f"INDEPENDENT_BINDING_SOURCE_INVALID:{fingerprint}"
            )
        component = str(binding.get("current_component_id", ""))
        owner = str(binding.get("current_owner_id", ""))
        expected_selector = {
            "component_ids": sorted([component, owner]),
            "dynamic_reference_ids": [],
            "paths": [path],
            "retirement_ids": [],
            "supersession_ids": [],
        }
        projection = convergence.subject_projection(root, head, expected_selector)
        if (
            binding.get("authority_selectors") != expected_selector
            or binding.get("historical_path") != path
            or binding.get("current_path") != path
            or binding.get("historical_component_id") != component
            or binding.get("recommended_disposition")
            != "HISTORICAL_TEST_ONLY"
            or binding.get("historical_production_reachability") != "TEST_ONLY"
            or binding.get("current_production_reachability") != "TEST_ONLY"
            or binding.get("historical_role") != "TEST_SUPPORT"
            or binding.get("current_role") != "TEST_SUPPORT"
            or binding.get("test_only_status") != "TEST_ONLY"
            or binding.get("subject_projection") != projection
            or binding.get("subject_projection_sha256")
            != base.sha(base.canonical(projection))
            or row.get("expected_registry_rows")
            != base._canonical_registry_rows(projection)
        ):
            raise IndependentReviewError(
                f"INDEPENDENT_EXACT_PROJECTION_INVALID:{fingerprint}"
            )
        failures = convergence._authorized_identity_binding_failures(
            root,
            fingerprint,
            binding,
            authorized.get(fingerprint),
            record_rule_ids=["HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT"],
        )
        if failures:
            raise IndependentReviewError(
                f"INDEPENDENT_AUTHORITY_INVALID:{fingerprint}:{failures[0]}"
            )
        if path in seen_paths or component in seen_components:
            raise IndependentReviewError(
                f"INDEPENDENT_IDENTITY_COLLISION:{fingerprint}"
            )
        seen_paths.add(path)
        seen_components.add(component)
    if len(seen_paths) != 39 or seen_paths != set(
        batch012.registry_projection.EXPECTED_PATHS
    ):
        raise IndependentReviewError("INDEPENDENT_MEMBER_SET_INVALID")
    return {"proposal": proposal, "path": resolved}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--membership-stage", type=Path, required=True)
    parser.add_argument("--proposal", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        result = audit(args.root, args.membership_stage, args.proposal)
        proposal = result["proposal"]
        review = {
            "schema_version": batch012.REVIEW_SCHEMA,
            "batch_id": batch012.BATCH_ID,
            "proposal_payload_sha256": proposal["proposal_payload_sha256"],
            "evaluated_head_sha": proposal["evaluated_head_sha"],
            "evaluated_tree_sha": proposal["evaluated_tree_sha"],
            "failure_fingerprint_set_sha256": (
                batch012.MEMBERSHIP_SET_SHA256
            ),
            "review_id": "B",
            "reviewer_authority_id": batch012.REVIEWERS["B"],
            "findings": [],
            "p0_count": 0,
            "p1_count": 0,
            "status": "GO",
        }
        review["receipt_payload_sha256"] = base.sha(base.canonical(review))
        path = batch012._write_external_document(args.root, args.output, review)
        print(
            json.dumps(
                {
                    "status": "PASS",
                    "review_id": "B",
                    "path": path.as_posix(),
                    "sha256": base.sha(path.read_bytes()),
                },
                sort_keys=True,
            )
        )
        return 0
    except (
        IndependentReviewError,
        batch012.Batch012Error,
        base.MaterializerError,
        membership_builder.BuilderError,
    ) as exc:
        print(
            json.dumps(
                {
                    "status": "FAIL",
                    "batch_id": batch012.BATCH_ID,
                    "error": str(exc),
                },
                sort_keys=True,
            )
        )
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
