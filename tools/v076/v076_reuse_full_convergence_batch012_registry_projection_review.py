"""Dual-algorithm read-only review for the external Batch012 projection.

Review A performs an exact rebuild with the sealed projection builder. Review B
independently reconstructs the Registry append and checks the current V075
execution root. Both reviews write only one canonical receipt to a fresh
external directory.
"""
from __future__ import annotations

import argparse
import base64
import binascii
import copy
import json
from pathlib import Path

import v076_reuse_point_inertia_gate as gate
import v076_reuse_full_convergence_batch_builder as membership
import v076_reuse_full_convergence_batch010_materializer as identities
import v076_reuse_full_convergence_batch010_registry_projection_builder as io
import v076_reuse_full_convergence_batch012_registry_projection_builder as builder


SCHEMA = "space_syndicate.v076.batch012_registry_projection_review.v1"
REVIEWERS = {
    "A": "V076_FULL_CONVERGENCE_PRIMARY_REVIEWER_V1",
    "B": "V076_FULL_CONVERGENCE_INDEPENDENT_REVIEWER_V1",
}
EXPECTED_FIELDS = frozenset(
    {
        "schema_version",
        "candidate_kind",
        "batch_id",
        "binding_head_sha",
        "binding_tree_sha",
        "frozen_membership_head_sha",
        "frozen_membership_sha256",
        "failure_fingerprint_set_sha256",
        "failure_count",
        "registry_rows_before",
        "registry_rows_after",
        "appended_path_row_count",
        "unchanged_reused_member_count",
        "classification_counts",
        "source_current_blob_equal_count",
        "historical_current_blob_difference_count",
        "old_component_row_mutation_count",
        "new_owner_count",
        "original_snapshot_guard_failures",
        "original_monotonic_guard_failures",
        "detached_graph_evidence",
        "source_graph_bindings",
        "execution_helper_bindings",
        "rows",
        "target_registry",
        "review_status",
        "go_claim",
        "official_write_count",
        "product_file_mutation_count",
        "formal_step11_reexecution_count",
        "required_gate_green",
        "human_green",
        "production_green",
        "builder_sha256",
        "payload_sha256",
    }
)
PROOF_FIELDS = frozenset(
    {
        "failure_fingerprint",
        "raw_failure",
        "source_commit",
        "historical_source_identity",
        "current_source_identity",
        "component_row",
        "recommended_disposition",
        "current_production_reachability",
        "citation",
    }
)


def _read_candidate(root: Path, path: Path) -> tuple[dict, bytes, Path]:
    root = root.resolve()
    resolved = path.resolve()
    try:
        resolved.relative_to(root)
    except ValueError:
        pass
    else:
        raise ValueError("CANDIDATE_MUST_BE_EXTERNAL")
    if not resolved.is_file() or resolved.is_symlink():
        raise ValueError("CANDIDATE_MUST_BE_PLAIN_FILE")
    raw = resolved.read_bytes()
    candidate = membership.strict_json_bytes(raw, "BATCH012_REGISTRY_CANDIDATE")
    if raw != io.canonical(candidate) or set(candidate) != EXPECTED_FIELDS:
        raise ValueError("CANDIDATE_CANONICAL_CONTRACT_INVALID")
    unsigned = dict(candidate)
    digest = unsigned.pop("payload_sha256", None)
    if digest != io.sha(io.canonical(unsigned)):
        raise ValueError("CANDIDATE_PAYLOAD_SHA_INVALID")
    if (
        candidate.get("schema_version")
        != "space_syndicate.v076.batch012_registry_projection_candidate.v1"
        or candidate.get("candidate_kind")
        != "NON_AUTHORITATIVE_EXACT_BATCH012_METADATA_PROJECTION"
        or candidate.get("batch_id") != "batch-012"
        or candidate.get("failure_count") != 39
        or candidate.get("failure_fingerprint_set_sha256")
        != builder.FINGERPRINT_SET_SHA
        or candidate.get("review_status") != "PENDING_PRIMARY_AND_INDEPENDENT"
        or candidate.get("go_claim") is not False
        or candidate.get("official_write_count") != 0
        or candidate.get("new_owner_count") != 0
        or candidate.get("product_file_mutation_count") != 0
        or candidate.get("formal_step11_reexecution_count") != 0
        or candidate.get("required_gate_green") is not False
        or candidate.get("human_green") is not False
        or candidate.get("production_green") is not False
    ):
        raise ValueError("CANDIDATE_STATIC_CONTRACT_INVALID")
    return candidate, raw, resolved


def _primary(root: Path, candidate: dict) -> list[str]:
    expected = builder.build(root, candidate["binding_head_sha"])
    if candidate != expected:
        raise ValueError("PRIMARY_EXACT_REBUILD_MISMATCH")
    return [
        "exact sealed builder reconstruction matched candidate bytes",
        "original authority snapshot and monotonic guards returned zero failures",
        "39 historical identities remained byte-identical",
        "candidate contains no authority GO or production-green claim",
    ]


def _expected_identity(path: str, identity: dict) -> tuple[str, str]:
    path_bound = {
        "resources/weather/crystal_dust_storm.tres": (
            "component.current.crystal_dust_storm_weather_definition_resource_instance",
            "CrystalDustStormWeatherDefinitionResourceInstance",
        ),
        "resources/weather/deep_freeze.tres": (
            "component.current.deep_freeze_weather_definition_resource_instance",
            "DeepFreezeWeatherDefinitionResourceInstance",
        ),
        "scenes/ui/table/PlayerRosterEntry.tscn": (
            "component.current.player_roster_entry_scene",
            "SpaceSyndicatePlayerRosterEntryScene",
        ),
    }
    if path in path_bound:
        return path_bound[path]
    declared = str(identity.get("declared_class_name", ""))
    if identity.get("identity_kind") != "GDSCRIPT" or not declared:
        raise ValueError("INDEPENDENT_SOURCE_IDENTITY_INVALID:" + path)
    return "component.current." + Path(path).stem, declared


def _assert_execution_root(root: Path, head: str) -> None:
    main = io.committed(root, head, "scenes/main.tscn").decode("utf-8-sig")
    runtime = io.committed(
        root, head, "scenes/runtime/V075RuntimeComposition.tscn"
    ).decode("utf-8-sig")
    screen = io.committed(
        root, head, "scenes/ui/v075/V075SampleGameScreen.tscn"
    ).decode("utf-8-sig")
    menu = io.committed(
        root,
        head,
        "scripts/runtime/menu_lifecycle_application_flow_controller.gd",
    ).decode("utf-8-sig")
    direct = io.committed(
        root,
        head,
        "scripts/v076/direct_action/v076_private_direct_action_input_owner_v1.gd",
    ).decode("utf-8-sig")
    checks = (
        "res://scenes/runtime/V075RuntimeComposition.tscn" in main,
        "res://scenes/ui/v075/V075SampleGameScreen.tscn" in main,
        "res://scenes/runtime/GameRuntimeCoordinator.tscn" not in main,
        "res://scenes/ui/GameScreen.tscn" not in main,
        "coordinator_path =" not in main,
        "GameRuntimeCoordinator" not in runtime,
        "RuntimeCommandPipeline" not in runtime,
        "res://scenes/ui/v074/V074SampleGameScreen.tscn" in screen,
        "res://scenes/ui/GameScreen.tscn" not in screen,
        "func _coordinator() -> GameRuntimeCoordinator:" in menu,
        "not coordinator_path.is_empty()" in menu,
        '"../GameRuntimeCoordinator/RuntimeCommandPipeline"' in direct,
    )
    if not all(checks):
        raise ValueError("INDEPENDENT_CURRENT_EXECUTION_ROOT_INVALID")


def _independent(root: Path, candidate: dict) -> list[str]:
    root = root.resolve()
    head = io.git(root, "rev-parse", "HEAD^{commit}")
    tree = io.git(root, "rev-parse", "HEAD^{tree}")
    if (
        candidate.get("binding_head_sha") != head
        or candidate.get("binding_tree_sha") != tree
    ):
        raise ValueError("INDEPENDENT_CURRENT_HEAD_BINDING_INVALID")
    if io.git(root, "diff", "--name-only") or io.git(
        root, "diff", "--cached", "--name-only"
    ):
        raise ValueError("INDEPENDENT_TRACKED_WORKTREE_NOT_CLEAN")
    changed = set(
        filter(
            None,
            io.git(
                root, "diff", "--name-only", builder.ARTIFACT_HEAD, head
            ).splitlines(),
        )
    )
    allowed = {
        "tools/v076/v076_reuse_full_convergence_batch012_registry_projection_builder.py",
        "tools/v076/v076_reuse_full_convergence_batch012_registry_projection_review.py",
    }
    if changed != allowed:
        raise ValueError("INDEPENDENT_POST_ARTIFACT_DELTA_INVALID")

    member_document = builder.frozen_members(root)
    fingerprints = member_document["failure_fingerprints"]
    if len(fingerprints) != 39:
        raise ValueError("INDEPENDENT_MEMBERSHIP_COUNT_INVALID")
    proofs = candidate.get("rows")
    if not isinstance(proofs, list) or len(proofs) != 39:
        raise ValueError("INDEPENDENT_PROOF_ROWS_INVALID")

    source = io.committed(root, head, builder.REGISTRY)
    before = membership.strict_json_bytes(source, builder.REGISTRY)
    target = candidate.get("target_registry")
    if not isinstance(target, dict) or set(target) != {
        "path",
        "source_sha256",
        "target_sha256",
        "target_bytes_base64",
    }:
        raise ValueError("INDEPENDENT_TARGET_ENVELOPE_INVALID")
    try:
        target_bytes = base64.b64decode(
            str(target["target_bytes_base64"]), validate=True
        )
    except (ValueError, binascii.Error) as exc:
        raise ValueError("INDEPENDENT_TARGET_BASE64_INVALID") from exc
    if (
        target.get("path") != builder.REGISTRY
        or target.get("source_sha256") != io.sha(source)
        or target.get("target_sha256") != io.sha(target_bytes)
    ):
        raise ValueError("INDEPENDENT_TARGET_HASH_INVALID")
    after = membership.strict_json_bytes(target_bytes, builder.REGISTRY)
    existing_ids = {
        row["reuse_id"] for row in before.get("reuse_entries", [])
    }
    additions = []
    for fingerprint, proof in zip(fingerprints, proofs, strict=True):
        member = member_document["rows"][fingerprint]
        if not isinstance(proof, dict) or set(proof) != PROOF_FIELDS:
            raise ValueError("INDEPENDENT_PROOF_CONTRACT_INVALID:" + fingerprint)
        path = str(member.get("subject_value", ""))
        historical = identities.source_identity(root, builder.SOURCE, path)
        current = identities.source_identity(root, head, path)
        component = proof.get("component_row")
        if not isinstance(component, dict):
            raise ValueError("INDEPENDENT_COMPONENT_ROW_MISSING:" + fingerprint)
        expected_id, expected_class = _expected_identity(path, historical)
        if (
            proof.get("failure_fingerprint") != fingerprint
            or proof.get("raw_failure") != member.get("raw_failure")
            or proof.get("source_commit") != builder.SOURCE
            or proof.get("historical_source_identity") != historical
            or proof.get("current_source_identity") != current
            or historical != current
            or proof.get("recommended_disposition") != "HISTORICAL_TEST_ONLY"
            or proof.get("current_production_reachability") != "TEST_ONLY"
            or component.get("component_id") != expected_id
            or component.get("class_name") != expected_class
            or component.get("path") != path
            or component.get("domain_id") != builder.DOMAIN
            or component.get("component_role") != "TEST_SUPPORT"
            or component.get("production_reachable") is not False
            or component.get("writes_authority") is not False
            or component.get("owner_component_id") != builder.OWNER_ID
            or component.get("owner_path") != builder.OWNER_PATH
            or component.get("owns_rng") is not False
            or component.get("owns_tick") is not False
            or component.get("owns_save") is not False
            or component.get("owns_replay") is not False
            or component.get("owns_identity") is not False
            or component.get("owns_presentation") is not False
            or component.get("reuse_disposition") != "REUSE_AS_TEST"
        ):
            raise ValueError("INDEPENDENT_ROW_CLASSIFICATION_INVALID:" + fingerprint)
        failures = gate._component_row_contract_failures(
            component, existing_ids, fingerprint
        )
        if failures:
            raise ValueError(
                "INDEPENDENT_ROW_CONTRACT_INVALID:"
                + fingerprint
                + ":"
                + failures[0]
            )
        additions.append(component)

    expected_after = copy.deepcopy(before)
    expected_after["component_inventory"].extend(additions)
    if after != expected_after:
        raise ValueError("INDEPENDENT_EXACT_APPEND_INVALID")
    if (
        candidate.get("registry_rows_before")
        != len(before["component_inventory"])
        or candidate.get("registry_rows_after")
        != len(after["component_inventory"])
        or candidate.get("appended_path_row_count") != 39
        or candidate.get("unchanged_reused_member_count") != 0
        or candidate.get("classification_counts")
        != {"HISTORICAL_TEST_ONLY": 39}
        or candidate.get("source_current_blob_equal_count") != 39
        or candidate.get("historical_current_blob_difference_count") != 0
        or candidate.get("old_component_row_mutation_count") != 0
        or candidate.get("original_snapshot_guard_failures") != []
        or candidate.get("original_monotonic_guard_failures") != []
    ):
        raise ValueError("INDEPENDENT_AGGREGATE_COUNTS_INVALID")

    all_rows = after["component_inventory"]
    for field in ("component_id", "path"):
        values = [row[field] for row in all_rows]
        if len(values) != len(set(values)):
            raise ValueError("INDEPENDENT_REGISTRY_COLLISION:" + field)
    class_sources = gate._component_class_source_bytes(root, head, all_rows)
    keys = gate._component_class_identity_keys(all_rows, class_sources)
    if len(keys) != len(set(keys)):
        raise ValueError("INDEPENDENT_TYPED_CLASS_COLLISION")
    _assert_execution_root(root, head)
    return [
        "independent Registry decode reconstructed one exact 39-row append",
        "all historical and current source identities matched byte-for-byte",
        "current executable root excludes retired runtime and screen scenes",
        "all 39 rows are non-writing TEST_SUPPORT under the existing V075 Owner",
        "no tracked product or authority source changed after membership seal",
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path.cwd())
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--review-id", choices=("A", "B"), required=True)
    parser.add_argument("--output-stage", type=Path, required=True)
    args = parser.parse_args()
    try:
        root = args.project.resolve()
        reviewer_path = Path(__file__).resolve()
        reviewer_relative = reviewer_path.relative_to(root).as_posix()
        head = io.git(root, "rev-parse", "HEAD^{commit}")
        if io.committed(root, head, reviewer_relative) != reviewer_path.read_bytes():
            raise ValueError("REVIEWER_WORKTREE_DRIFT")
        candidate, raw, candidate_path = _read_candidate(root, args.candidate)
        checks = (
            _primary(root, candidate)
            if args.review_id == "A"
            else _independent(root, candidate)
        )
        receipt = {
            "schema_version": SCHEMA,
            "batch_id": "batch-012",
            "candidate_path": candidate_path.as_posix(),
            "candidate_file_sha256": io.sha(raw),
            "candidate_payload_sha256": candidate["payload_sha256"],
            "binding_head_sha": candidate["binding_head_sha"],
            "binding_tree_sha": candidate["binding_tree_sha"],
            "failure_fingerprint_set_sha256": builder.FINGERPRINT_SET_SHA,
            "review_id": args.review_id,
            "reviewer_authority_id": REVIEWERS[args.review_id],
            "algorithm": (
                "PRIMARY_EXACT_SEALED_REBUILD"
                if args.review_id == "A"
                else "INDEPENDENT_TARGET_DELTA_RECONSTRUCTION"
            ),
            "checks": checks,
            "findings": [],
            "p0_count": 0,
            "p1_count": 0,
            "status": "GO",
            "official_write_count": 0,
        }
        receipt["receipt_payload_sha256"] = io.sha(io.canonical(receipt))
        stage = io._stage(root, args.output_stage)
        stage.mkdir(parents=True, exist_ok=False)
        output = stage / f"review-{args.review_id.lower()}.json"
        with output.open("xb") as stream:
            stream.write(io.canonical(receipt))
        print(
            json.dumps(
                {
                    "status": "PASS",
                    "review_id": args.review_id,
                    "path": output.as_posix(),
                    "sha256": io.sha(output.read_bytes()),
                },
                sort_keys=True,
            )
        )
        return 0
    except ValueError as exc:
        print(
            json.dumps(
                {
                    "status": "FAIL",
                    "batch_id": "batch-012",
                    "error": str(exc),
                },
                sort_keys=True,
            )
        )
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
