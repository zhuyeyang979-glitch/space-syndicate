"""Build the closed Batch012 Registry projection outside the repository.

The frozen members are historical components from the retired
GameRuntimeCoordinator/GameScreen composition.  The current executable root
uses V075RuntimeComposition and V075SampleGameScreen instead.  This builder
therefore appends exactly 39 TEST_SUPPORT rows, preserves every existing
authority byte, and never treats a type annotation, preload, or compatibility
NodePath as evidence that the retired scene graph is instantiated.
"""
from __future__ import annotations

import argparse
import base64
import copy
import json
from pathlib import Path

import v076_reuse_point_inertia_gate as gate
import v076_reuse_full_convergence_batch_builder as membership
import v076_reuse_full_convergence_batch010_materializer as identities
import v076_reuse_full_convergence_batch010_registry_projection_builder as io
import v076_current_component_registration_58_builder as splice


MEMBERSHIP_HEAD = "4c6ddc42fb20a5f09e14110e3a784534a7b7f905"
ARTIFACT_HEAD = "6e1d184d7d8edbbf009de7a3743e5ee4c44d9755"
MEMBERSHIP_PATH = (
    "reports/reuse/full_convergence/generation10/"
    "historical_identity_batch012_membership_001/membership-candidate.json"
)
MEMBERSHIP_SHA = "53c4c82c2107318f35ad6fb34ff35b762341a7187ef79beb0cdfa341ea43e942"
MEMBERSHIP_PAYLOAD_SHA = "5bf331244067cc871bcbe61e0c3f670f51ee081a48c6c9c9433ab2d75f09231b"
FINGERPRINT_SET_SHA = "e0df091128327115a7ff339fba6f4a945f5d99e17054561ee1d62ec80eaf5c29"
SOURCE = "e584cd4d8b0cd8afca7ff508cffcb05d1ba801a3"
PARENT = "46b33bba77b356b100ab68bc7c3676d503049a2c"
REGISTRY = "docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json"
REGISTRY_SHA = "fa8486af2023a067df3af6e4e1eb5f4247e78f96f2b26e18a050d015c3a7667f"
OWNER_ID = "component.current.v075_runtime_owner"
OWNER_PATH = "scripts/v075_runtime/v075_runtime_owner.gd"
DOMAIN = "current.v075_production_combat_candidate"

EXPECTED_PATHS = frozenset(
    {
        "resources/weather/crystal_dust_storm.tres",
        "resources/weather/deep_freeze.tres",
        "scenes/ui/table/PlayerRosterEntry.tscn",
        "scripts/finance/product_futures_terms_catalog_resource.gd",
        "scripts/presentation/developer_balance_presentation_target.gd",
        "scripts/presentation/public_player_roster_projection_service.gd",
        "scripts/presentation/table_interaction_mode_v1.gd",
        "scripts/presentation/table_presentation_refresh_receipt.gd",
        "scripts/presentation/table_presentation_source_owner.gd",
        "scripts/presentation/victory_presentation_state_change_receipt.gd",
        "scripts/presentation/world_session_private_projection.gd",
        "scripts/presentation/world_session_public_projection.gd",
        "scripts/runtime/card_play_eligibility_runtime_service.gd",
        "scripts/runtime/card_resolution_history_runtime_service.gd",
        "scripts/runtime/commodity_card_inventory_runtime_controller.gd",
        "scripts/runtime/district_purchase_settlement_runtime_service.gd",
        "scripts/runtime/district_supply_snapshot_service.gd",
        "scripts/runtime/game_runtime_coordinator.gd",
        "scripts/runtime/game_session_runtime_controller.gd",
        "scripts/runtime/gameplay_balance_diagnostics_runtime_service.gd",
        "scripts/runtime/gameplay_balance_diagnostics_world_bridge.gd",
        "scripts/runtime/monster_wager_response_receipt.gd",
        "scripts/runtime/product_market_runtime_controller.gd",
        "scripts/runtime/role_resource_cash_settlement_runtime_service.gd",
        "scripts/runtime/runtime_command_pipeline.gd",
        "scripts/runtime/runtime_lifecycle_phase_coordinator.gd",
        "scripts/runtime/runtime_victory_port.gd",
        "scripts/runtime/simulation_determinism_audit.gd",
        "scripts/runtime/weather_presentation_runtime_service.gd",
        "scripts/runtime/world_effective_clock_runtime_controller.gd",
        "scripts/semantic/ai_card_interaction_legacy_source_bundle_v1.gd",
        "scripts/ui/district_supply_status_chip.gd",
        "scripts/ui/overlay_layer.gd",
        "scripts/ui/table/compact_current_action_surface.gd",
        "scripts/ui/table/context_detail_drawer.gd",
        "scripts/ui/table/player_roster_entry.gd",
        "scripts/ui/table/region_supply_popup.gd",
        "scripts/viewmodels/card_view_snapshot.gd",
        "scripts/viewmodels/public_region_selection_catalog_entry.gd",
    }
)

PATH_BOUND_IDENTITIES = {
    "resources/weather/crystal_dust_storm.tres": (
        "crystal_dust_storm_weather_definition_resource_instance",
        "CrystalDustStormWeatherDefinitionResourceInstance",
        "GODOT_RESOURCE",
        "WeatherDefinition",
        "scripts/runtime/weather_definition.gd",
    ),
    "resources/weather/deep_freeze.tres": (
        "deep_freeze_weather_definition_resource_instance",
        "DeepFreezeWeatherDefinitionResourceInstance",
        "GODOT_RESOURCE",
        "WeatherDefinition",
        "scripts/runtime/weather_definition.gd",
    ),
    "scenes/ui/table/PlayerRosterEntry.tscn": (
        "player_roster_entry_scene",
        "SpaceSyndicatePlayerRosterEntryScene",
        "GODOT_SCENE",
        "",
        "scripts/ui/table/player_roster_entry.gd",
    ),
}

DETACHED_REGISTRY_ANCHORS = {
    "scripts/ui/game_screen.gd": "component.current.game_screen",
    "scripts/ui/table/player_roster_panel.gd": "component.current.player_roster_panel",
    "scripts/runtime/card_presentation_runtime_service.gd": (
        "component.current.card_presentation_runtime_service"
    ),
    "scripts/runtime/weather_runtime_controller.gd": (
        "component.current.weather_runtime_controller"
    ),
    "scripts/runtime/runtime_simulation_step.gd": (
        "component.current.runtime_simulation_step"
    ),
    "scripts/presentation/table_presentation_refresh_port.gd": (
        "component.current.table_presentation_refresh_port"
    ),
}


def frozen_members(root: Path) -> dict:
    raw = io.committed(root, ARTIFACT_HEAD, MEMBERSHIP_PATH)
    if io.sha(raw) != MEMBERSHIP_SHA:
        raise ValueError("FROZEN_MEMBERSHIP_BYTES_CHANGED")
    document = membership.strict_json_bytes(raw, MEMBERSHIP_PATH)
    unsigned = dict(document)
    digest = unsigned.pop("candidate_payload_sha256", None)
    fingerprints = document.get("failure_fingerprints", [])
    rows = document.get("rows", {})
    if not (
        digest == MEMBERSHIP_PAYLOAD_SHA == io.sha(io.canonical(unsigned))
        and document.get("evaluated_head_sha") == MEMBERSHIP_HEAD
        and document.get("batch_id") == "batch-012"
        and len(fingerprints) == len(set(fingerprints)) == 39
        and fingerprints == sorted(fingerprints)
        and io.line_set(fingerprints) == FINGERPRINT_SET_SHA
        and set(rows) == set(fingerprints)
    ):
        raise ValueError("FROZEN_MEMBERSHIP_IDENTITY_INVALID")
    if io.git(root, "rev-parse", SOURCE + "^1") != PARENT:
        raise ValueError("FROZEN_TRANSITION_PARENT_INVALID")
    paths: list[str] = []
    for fingerprint in fingerprints:
        row = rows[fingerprint]
        path = row.get("subject_value", "")
        expected_raw = (
            "HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT:"
            f"{PARENT[:12]}->{SOURCE[:12]}:{path}"
        )
        if (
            row.get("failure_fingerprint") != fingerprint
            or row.get("raw_failure") != expected_raw
            or row.get("transition_old_prefix") != PARENT[:12]
            or row.get("transition_new_prefix") != SOURCE[:12]
            or row.get("subject_kind") != "path"
        ):
            raise ValueError("FROZEN_MEMBER_DRIFT:" + fingerprint)
        paths.append(path)
    if len(paths) != len(set(paths)) or set(paths) != EXPECTED_PATHS:
        raise ValueError("CLOSED_BATCH012_MEMBER_SET_INVALID")
    return document


def _component_identity(path: str, identity: dict) -> tuple[str, str]:
    if path in PATH_BOUND_IDENTITIES:
        suffix, class_name, kind, script_class, script_path = (
            PATH_BOUND_IDENTITIES[path]
        )
        if (
            identity.get("identity_kind") != kind
            or identity.get("resource_script_class", "") != script_class
            or identity.get("script_path", "") != script_path
        ):
            raise ValueError("PATH_BOUND_IDENTITY_DRIFT:" + path)
        return suffix, class_name
    if (
        identity.get("identity_kind") != "GDSCRIPT"
        or not identity.get("declared_class_name")
    ):
        raise ValueError("EXACT_GDSCRIPT_IDENTITY_REQUIRED:" + path)
    return Path(path).stem, str(identity["declared_class_name"])


def new_row(path: str, identity: dict) -> dict:
    suffix, class_name = _component_identity(path, identity)
    return {
        "component_id": "component.current." + suffix,
        "class_name": class_name,
        "path": path,
        "domain_id": DOMAIN,
        "component_role": "TEST_SUPPORT",
        "production_reachable": False,
        "writes_authority": False,
        "reads_authority": True,
        "owns_rng": False,
        "owns_tick": False,
        "owns_save": False,
        "owns_replay": False,
        "owns_identity": False,
        "owns_presentation": False,
        "owner_component_id": OWNER_ID,
        "owner_path": OWNER_PATH,
        "reuse_disposition": "REUSE_AS_TEST",
        "reuse_source_ids": ["reuse.v075.combat_candidate"],
        "reuse_candidates_considered": ["reuse.v075.combat_candidate"],
        "new_component_justification": (
            "Batch012 exact historical identity registration. This unchanged "
            "component belongs to the retired GameRuntimeCoordinator or "
            "SpaceSyndicateGameScreen dependency graph, which is not "
            "instantiated by the current V075 executable root. Type "
            "annotations, preloads, compatibility paths and focused-test "
            "references do not promote it into production authority. No "
            "runtime, state, tick, RNG, identity, replay, save or presentation "
            "Owner is introduced."
        ),
        "supersedes": [],
        "superseded_by": [],
        "change_class": "TEST_ORACLE_ONLY",
        "focused_test_ids": ["v076_reuse_point_inertia_gate_selftest"],
        "golden_scenario_steps": [],
    }


def _identity_citation(source: bytes, identity: dict, path: str) -> dict:
    lines = source.decode("utf-8-sig").splitlines()
    tokens = [
        str(identity.get("declared_class_name", "")),
        str(identity.get("script_path", "")),
    ]
    for line_number, text in enumerate(lines, start=1):
        if any(token and token in text for token in tokens):
            return {
                "path": path,
                "line": line_number,
                "source_sha256": io.sha(source),
                "line_text": text,
                "kind": "SOURCE_IDENTITY_CITATION_NOT_EXECUTION_PROOF",
            }
    raise ValueError("SOURCE_IDENTITY_CITATION_MISSING:" + path)


def _detached_graph_evidence(root: Path, head: str, before: dict) -> dict:
    by_path = {row["path"]: row for row in before["component_inventory"]}
    anchor_rows = []
    for path, component_id in DETACHED_REGISTRY_ANCHORS.items():
        row = by_path.get(path)
        if not (
            row
            and row.get("component_id") == component_id
            and row.get("component_role") == "TEST_SUPPORT"
            and row.get("production_reachable") is False
            and row.get("writes_authority") is False
        ):
            raise ValueError("DETACHED_REGISTRY_ANCHOR_INVALID:" + path)
        anchor_rows.append(
            {
                "path": path,
                "component_id": component_id,
                "row_sha256": io.sha(io.canonical(row)),
            }
        )
    files = {
        path: io.committed(root, head, path)
        for path in (
            "scenes/main.tscn",
            "scenes/runtime/V075RuntimeComposition.tscn",
            "scenes/ui/v075/V075SampleGameScreen.tscn",
            "scripts/runtime/menu_lifecycle_application_flow_controller.gd",
            "scripts/v076/direct_action/v076_private_direct_action_input_owner_v1.gd",
        )
    }
    main = files["scenes/main.tscn"].decode("utf-8-sig")
    runtime = files["scenes/runtime/V075RuntimeComposition.tscn"].decode(
        "utf-8-sig"
    )
    screen = files["scenes/ui/v075/V075SampleGameScreen.tscn"].decode(
        "utf-8-sig"
    )
    menu = files[
        "scripts/runtime/menu_lifecycle_application_flow_controller.gd"
    ].decode("utf-8-sig")
    direct = files[
        "scripts/v076/direct_action/v076_private_direct_action_input_owner_v1.gd"
    ].decode("utf-8-sig")
    if not (
        "res://scenes/runtime/V075RuntimeComposition.tscn" in main
        and "res://scenes/ui/v075/V075SampleGameScreen.tscn" in main
        and "res://scenes/runtime/GameRuntimeCoordinator.tscn" not in main
        and "res://scenes/ui/GameScreen.tscn" not in main
        and "coordinator_path =" not in main
        and "GameRuntimeCoordinator" not in runtime
        and "RuntimeCommandPipeline" not in runtime
        and "res://scenes/ui/v074/V074SampleGameScreen.tscn" in screen
        and "res://scenes/ui/GameScreen.tscn" not in screen
        and "func _coordinator() -> GameRuntimeCoordinator:" in menu
        and "not coordinator_path.is_empty()" in menu
        and '"../GameRuntimeCoordinator/RuntimeCommandPipeline"' in direct
    ):
        raise ValueError("CURRENT_V075_DETACHED_GRAPH_CONTRACT_INVALID")
    return {
        "execution_root": "scenes/main.tscn",
        "active_runtime_scene": "scenes/runtime/V075RuntimeComposition.tscn",
        "active_screen_scene": "scenes/ui/v075/V075SampleGameScreen.tscn",
        "retired_runtime_scene_instantiated": False,
        "retired_screen_scene_instantiated": False,
        "menu_legacy_coordinator_path_configured": False,
        "direct_action_legacy_pipeline_node_present": False,
        "registry_anchor_rows": anchor_rows,
        "source_sha256": {path: io.sha(raw) for path, raw in files.items()},
    }


def build(root: Path, head: str) -> dict:
    root = root.resolve()
    head = io.git(root, "rev-parse", head + "^{commit}")
    io.git(root, "merge-base", "--is-ancestor", ARTIFACT_HEAD, head)
    builder_path = Path(__file__).resolve()
    builder_relative = builder_path.relative_to(root).as_posix()
    if io.committed(root, head, builder_relative) != builder_path.read_bytes():
        raise ValueError("EXECUTION_BUILDER_DRIFT")

    document = frozen_members(root)
    source = io.committed(root, head, REGISTRY)
    if io.sha(source) != REGISTRY_SHA or (root / REGISTRY).read_bytes() != source:
        raise ValueError("EXACT_REGISTRY_SOURCE_REQUIRED")
    before = membership.strict_json_bytes(source, REGISTRY)
    by_path = {row["path"]: row for row in before["component_inventory"]}
    owner = by_path[OWNER_PATH]
    domain = next(
        row for row in before["domain_inventory"] if row["domain_id"] == DOMAIN
    )
    if not (
        owner.get("component_id") == OWNER_ID
        and owner.get("component_role") == "OWNER"
        and owner.get("production_reachable") is True
        and owner.get("writes_authority") is True
        and domain.get("owner_component_id") == OWNER_ID
        and domain.get("lifecycle") == "ACTIVE_CURRENT_DOMAIN"
    ):
        raise ValueError("EXISTING_OWNER_BINDING_INVALID")

    dependency_bindings = []
    for path in (
        "scripts",
        "resources",
        "scenes",
        "addons",
        "assets",
        "project.godot",
    ):
        old = io.git(root, "rev-parse", ARTIFACT_HEAD + ":" + path)
        new = io.git(root, "rev-parse", head + ":" + path)
        if old != new:
            raise ValueError("AUDITED_SOURCE_GRAPH_DRIFT:" + path)
        dependency_bindings.append(
            {
                "path": path,
                "audited_head_git_object": old,
                "binding_head_git_object": new,
            }
        )

    detached_evidence = _detached_graph_evidence(root, head, before)
    additions = []
    proof_rows = []
    for fingerprint in document["failure_fingerprints"]:
        frozen = document["rows"][fingerprint]
        path = frozen["subject_value"]
        historical = identities.source_identity(root, SOURCE, path)
        current = identities.source_identity(root, head, path)
        if historical != current or path in by_path:
            raise ValueError("NEW_HISTORICAL_ROW_SOURCE_OR_PATH_DRIFT:" + path)
        row = new_row(path, historical)
        failures = gate._component_row_contract_failures(
            row,
            {item["reuse_id"] for item in before["reuse_entries"]},
            fingerprint,
        )
        if failures:
            raise ValueError("ORIGINAL_ROW_CONTRACT:" + "|".join(failures))
        additions.append(row)
        source_bytes = io.committed(root, head, path)
        proof_rows.append(
            {
                "failure_fingerprint": fingerprint,
                "raw_failure": frozen["raw_failure"],
                "source_commit": SOURCE,
                "historical_source_identity": historical,
                "current_source_identity": current,
                "component_row": row,
                "recommended_disposition": "HISTORICAL_TEST_ONLY",
                "current_production_reachability": "TEST_ONLY",
                "citation": _identity_citation(source_bytes, current, path),
            }
        )
    if len(additions) != 39 or len(proof_rows) != 39:
        raise ValueError("EXACT_ROW_CARDINALITY_REQUIRED")

    target = splice.append_inventory(source, before, additions)
    after = membership.strict_json_bytes(target, REGISTRY)
    expected = copy.deepcopy(before)
    expected["component_inventory"] += additions
    if after != expected:
        raise ValueError("UNEXPECTED_AUTHORITY_MUTATION")
    for key in ("component_id", "path"):
        values = [row[key] for row in after["component_inventory"]]
        if len(values) != len(set(values)):
            raise ValueError("REGISTRY_IDENTITY_COLLISION:" + key)

    class_sources = gate._component_class_source_bytes(
        root, head, after["component_inventory"]
    )
    class_keys = gate._component_class_identity_keys(
        after["component_inventory"], class_sources
    )
    if len(class_keys) != len(set(class_keys)):
        raise ValueError("REGISTRY_TYPED_CLASS_IDENTITY_COLLISION")
    _, authority_paths = gate.discover_authorities(root)
    old_authorities = gate.load_baseline_authorities(root, head, authority_paths)
    new_authorities = copy.deepcopy(old_authorities)
    new_authorities["historical_reuse"] = after
    snapshot_failures = gate._authority_snapshot_contract_failures(
        new_authorities, "batch012-proposal", class_sources
    )
    monotonic_failures = gate._monotonic_transition_failures(
        old_authorities,
        new_authorities,
        "batch012-proposal",
        [{"path": REGISTRY, "status": "M"}],
        class_sources,
    )
    if snapshot_failures or monotonic_failures:
        raise ValueError(
            "ORIGINAL_AUTHORITY_GUARD:"
            + "|".join(snapshot_failures + monotonic_failures)
        )

    helper_bindings = []
    for module in (gate, membership, identities, io, splice):
        path = Path(module.__file__).resolve()
        relative = path.relative_to(root).as_posix()
        content = io.committed(root, head, relative)
        if path.read_bytes() != content:
            raise ValueError("EXECUTION_HELPER_DRIFT:" + relative)
        helper_bindings.append({"path": relative, "sha256": io.sha(content)})

    result = {
        "schema_version": (
            "space_syndicate.v076.batch012_registry_projection_candidate.v1"
        ),
        "candidate_kind": "NON_AUTHORITATIVE_EXACT_BATCH012_METADATA_PROJECTION",
        "batch_id": "batch-012",
        "binding_head_sha": head,
        "binding_tree_sha": io.git(root, "rev-parse", head + "^{tree}"),
        "frozen_membership_head_sha": MEMBERSHIP_HEAD,
        "frozen_membership_sha256": MEMBERSHIP_SHA,
        "failure_fingerprint_set_sha256": FINGERPRINT_SET_SHA,
        "failure_count": 39,
        "registry_rows_before": len(before["component_inventory"]),
        "registry_rows_after": len(after["component_inventory"]),
        "appended_path_row_count": 39,
        "unchanged_reused_member_count": 0,
        "classification_counts": {"HISTORICAL_TEST_ONLY": 39},
        "source_current_blob_equal_count": 39,
        "historical_current_blob_difference_count": 0,
        "old_component_row_mutation_count": 0,
        "new_owner_count": 0,
        "original_snapshot_guard_failures": snapshot_failures,
        "original_monotonic_guard_failures": monotonic_failures,
        "detached_graph_evidence": detached_evidence,
        "source_graph_bindings": dependency_bindings,
        "execution_helper_bindings": helper_bindings,
        "rows": proof_rows,
        "target_registry": {
            "path": REGISTRY,
            "source_sha256": io.sha(source),
            "target_sha256": io.sha(target),
            "target_bytes_base64": base64.b64encode(target).decode(),
        },
        "review_status": "PENDING_PRIMARY_AND_INDEPENDENT",
        "go_claim": False,
        "official_write_count": 0,
        "product_file_mutation_count": 0,
        "formal_step11_reexecution_count": 0,
        "required_gate_green": False,
        "human_green": False,
        "production_green": False,
        "builder_sha256": io.sha(builder_path.read_bytes()),
    }
    result["payload_sha256"] = io.sha(io.canonical(result))
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path.cwd())
    parser.add_argument("--head-ref", default="HEAD")
    parser.add_argument("--output-stage", type=Path, required=True)
    args = parser.parse_args()
    project = args.project.resolve()
    stage = io._stage(project, args.output_stage)
    result = build(project, args.head_ref)
    stage.mkdir(parents=True, exist_ok=False)
    output = stage / "batch012_registry_projection_candidate.json"
    with output.open("xb") as stream:
        stream.write(io.canonical(result))
    print(
        json.dumps(
            {
                "status": "PASS_PROPOSAL_ONLY",
                "candidate": str(output),
                "candidate_sha256": io.sha(output.read_bytes()),
                "official_write_count": 0,
            },
            sort_keys=True,
        )
    )
