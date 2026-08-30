#!/usr/bin/env python3
"""Build and apply the exact dual-reviewed Batch-009 Registry projection.

This builder is intentionally batch-specific.  It turns the already sealed
Batch-009 membership into a two-file, non-authoritative review candidate.  It
does not write correction records, batch evidence, product files, workflows,
or any older batch.  The only apply targets are the historical reuse Registry
and the supersession map.
"""

from __future__ import annotations

import argparse
import base64
import copy
import json
import os
from pathlib import Path
from typing import Any, Iterable

import v076_reuse_exact_failure_correction_v2_full_convergence as convergence
import v076_reuse_full_convergence_batch009_materializer as materializer
import v076_reuse_full_convergence_batch_builder as shared


BATCH_ID = "batch-009"
SOURCE_COMMIT = "e584cd4d8b0cd8afca7ff508cffcb05d1ba801a3"
CUTOVER_COMMIT = "ad12cfa8c9fd877a1f69283d04f1d671796bbf74"
REGISTRY = Path("docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json")
SUPERSESSION = Path("docs/architecture/V076_SUPERSESSION_MAP.json")
OUTPUT_ALLOWLIST = (REGISTRY.as_posix(), SUPERSESSION.as_posix())
DOMAIN_ID = "current.v075_production_combat_candidate"
CURRENT_OWNER_ID = "component.current.v075_runtime_owner"
CURRENT_OWNER_PATH = "scripts/v075_runtime/v075_runtime_owner.gd"
MILITARY_COMPONENT_ID = "component.current.military_runtime_controller"
MILITARY_PATH = "scripts/runtime/military_runtime_controller.gd"
MILITARY_REUSE_ID = "reuse.current.military_runtime_owner"
MILITARY_SUPERSESSION_KIND = (
    "HISTORICAL_IDENTITY_BACKFILL_OWNER_TO_CURRENT_OWNER"
)
MILITARY_SUPERSESSION_ID = (
    "historical.military-runtime-controller-to-v075-runtime-owner"
)

CANDIDATE_SCHEMA = (
    "space_syndicate.v076.reuse_full_convergence."
    "batch009_registry_projection_candidate.v1"
)
REVIEW_SCHEMA = (
    "space_syndicate.v076.reuse_full_convergence."
    "batch009_registry_projection_review.v1"
)
SEAL_SCHEMA = (
    "space_syndicate.v076.reuse_full_convergence."
    "batch009_registry_projection_seal.v1"
)
CANDIDATE_KIND = "NON_AUTHORITATIVE_EXACT_BATCH009_REGISTRY_MUTATION"
NEXT_REVIEW_PHASE = "OBTAIN_TWO_DISTINCT_EXACT_TARGET_REVIEWS_AND_SEAL"
NEXT_APPLY_PHASE = "PREFLIGHT_AND_APPLY_EXACT_TWO_FILE_TRANSACTION"
TRUSTED_REVIEWERS = {
    "PRIMARY": "V076_BATCH009_REGISTRY_PRIMARY_REVIEWER_V1",
    "INDEPENDENT": "V076_BATCH009_REGISTRY_INDEPENDENT_REVIEWER_V1",
}

COMPONENT_FIELDS = frozenset(
    {
        "component_id",
        "class_name",
        "path",
        "domain_id",
        "component_role",
        "production_reachable",
        "writes_authority",
        "reads_authority",
        "owns_rng",
        "owns_tick",
        "owns_save",
        "owns_replay",
        "owns_identity",
        "owns_presentation",
        "owner_component_id",
        "owner_path",
        "reuse_disposition",
        "reuse_source_ids",
        "reuse_candidates_considered",
        "new_component_justification",
        "supersedes",
        "superseded_by",
        "change_class",
        "focused_test_ids",
        "golden_scenario_steps",
    }
)
TARGET_FIELDS = frozenset(
    {
        "path",
        "source_blob_oid",
        "source_bytes_sha256",
        "source_byte_count",
        "target_encoding",
        "target_bytes_base64",
        "target_bytes_sha256",
        "target_byte_count",
    }
)
MUTATION_FIELDS = frozenset(
    {
        "target_path",
        "operation",
        "locator",
        "before_exists",
        "before_canonical_sha256",
        "after_canonical_sha256",
    }
)
CANDIDATE_FIELDS = frozenset(
    {
        "schema_version",
        "candidate_kind",
        "authorization_id",
        "batch_id",
        "evaluated_head_sha",
        "evaluated_tree_sha",
        "source_commit",
        "membership_authority",
        "failure_count",
        "failure_fingerprint_set_sha256",
        "path_set_sha256",
        "component_id_set_sha256",
        "class_name_set_sha256",
        "source_current_blob_drift_count",
        "classification_counts",
        "target_files",
        "mutation_inventory",
        "mutation_inventory_sha256",
        "required_review_ids",
        "review_status",
        "go_claim",
        "official_write_count",
        "next_phase",
        "candidate_payload_sha256",
    }
)
REVIEW_FIELDS = frozenset(
    {
        "schema_version",
        "review_id",
        "reviewer_authority_id",
        "candidate_payload_sha256",
        "batch_id",
        "evaluated_head_sha",
        "evaluated_tree_sha",
        "membership_candidate_file_sha256",
        "membership_seal_file_sha256",
        "source_registry_sha256",
        "source_supersession_map_sha256",
        "target_registry_sha256",
        "target_supersession_map_sha256",
        "mutation_inventory_sha256",
        "classification_counts",
        "military_owner_to_owner_supersession_verified",
        "status",
        "p0_count",
        "p1_count",
        "findings",
        "receipt_payload_sha256",
    }
)
SEAL_FIELDS = frozenset(
    {
        "schema_version",
        "authorization_id",
        "batch_id",
        "evaluated_head_sha",
        "evaluated_tree_sha",
        "candidate_path",
        "candidate_file_sha256",
        "candidate_payload_sha256",
        "membership_candidate_file_sha256",
        "membership_seal_file_sha256",
        "review_receipts",
        "source_registry_sha256",
        "source_supersession_map_sha256",
        "target_registry_sha256",
        "target_supersession_map_sha256",
        "mutation_inventory_sha256",
        "review_status",
        "go_claim",
        "official_write_count",
        "next_phase",
        "seal_payload_sha256",
    }
)


class ProjectionError(ValueError):
    pass


# path, component id, class name, exact disposition, focused tests
COMPONENT_SPECS = (
    ("scenes/ui/DistrictSupplyMarketCard.tscn", "component.current.district_supply_market_card_scene", "SpaceSyndicateDistrictSupplyMarketCardScene", "TEST_ONLY", ("layout_scene_smoke_test", "runtime_table_focus_order_test")),
    ("scripts/presentation/table_selection_catalog_query_port.gd", "component.current.table_selection_catalog_query_port", "TableSelectionCatalogQueryPort", "TEST_ONLY", ("public_selection_catalog_snapshot_api_test", "card_resolution_stable_target_envelope_test")),
    ("scripts/runtime/monster_wager_response_sink.gd", "component.current.monster_wager_response_sink", "MonsterWagerResponseSink", "TEST_ONLY", ("monster_wager_response_cutover_test", "v075_application_composition_test")),
    ("scripts/runtime/gameplay_actor_authorization_context.gd", "component.current.gameplay_actor_authorization_context", "GameplayActorAuthorizationContext", "TEST_ONLY", ("selected_player_actor_authority_split_test", "table_player_action_application_flow_test")),
    ("scripts/runtime/intel_application_intent.gd", "component.current.intel_application_intent", "IntelApplicationIntent", "TEST_ONLY", ("intel_query_command_cutover_test", "main_application_flow_handler_extraction_test")),
    ("scripts/runtime/weather_telemetry_runtime_service.gd", "component.current.weather_telemetry_runtime_service", "WeatherTelemetryRuntimeService", "TEST_ONLY", ("weather_telemetry_runtime_service_test", "weather_telemetry_production_integration_test")),
    ("scripts/runtime/route_network_runtime_controller.gd", "component.current.route_network_runtime_controller", "RouteNetworkRuntimeController", "TEST_ONLY", ("main_runtime_composition_test", "v06_contract_response_retirement_test")),
    ("scripts/viewmodels/public_region_selection_catalog_snapshot.gd", "component.current.public_region_selection_catalog_snapshot", "PublicRegionSelectionCatalogSnapshot", "TEST_ONLY", ("card_resolution_product_market_target_envelope_test", "public_selection_catalog_snapshot_api_test")),
    ("scripts/viewmodels/public_product_selection_catalog_entry.gd", "component.current.public_product_selection_catalog_entry", "PublicProductSelectionCatalogEntry", "TEST_ONLY", ("public_selection_catalog_snapshot_api_test",)),
    ("resources/weather/gravity_tide.tres", "component.current.gravity_tide_weather_definition_resource_instance", "GravityTideWeatherDefinitionResourceInstance", "TEST_ONLY", ("weather_card_ai_v1_test", "layout_scene_smoke_test")),
    ("scripts/runtime/victory_control_world_bridge.gd", "component.current.victory_control_world_bridge", "VictoryControlWorldBridge", "TEST_ONLY", ("runtime_victory_port_terminal_presentation_exact_once_test", "v075_final_settlement_presentation_exact_once_regression_test")),
    ("resources/weather/ion_storm.tres", "component.current.ion_storm_weather_definition_resource_instance", "IonStormWeatherDefinitionResourceInstance", "TEST_ONLY", ("weather_card_ai_v1_test", "weather_v1_save_privacy_acceptance_test")),
    ("scripts/runtime/weather_runtime_state.gd", "component.current.weather_runtime_state", "WeatherRuntimeState", "TEST_ONLY", ("weather_save_owner_transaction_test", "weather_v1_save_privacy_acceptance_test")),
    ("scripts/runtime/run_rng_service.gd", "component.current.run_rng_service", "RunRngService", "TEST_ONLY", ("run_rng_service_cutover_test", "simulation_determinism_foundation_test")),
    ("scripts/runtime/commodity_card_effect_runtime_bridge.gd", "component.current.commodity_card_effect_runtime_bridge", "CommodityCardEffectRuntimeBridge", "TEST_ONLY", ("card_flow_region_supply_purchase_v06_test", "facility_card_production_unlock_v06_test")),
    ("resources/ai/personalities/arbitrage_ai_policy.tres", "component.current.arbitrage_ai_policy_resource_instance", "ArbitrageAiPolicyResourceInstance", "TEST_ONLY", ("ai_business_cost_architecture_gate_test", "layout_scene_smoke_test")),
    ("scripts/runtime/district_supply_action_port.gd", "component.current.district_supply_action_port", "DistrictSupplyActionPort", "TEST_ONLY", ("district_supply_action_port_cutover_test", "table_player_action_application_flow_test")),
    ("scripts/runtime/table_player_action_application_flow_controller.gd", "component.current.table_player_action_application_flow_controller", "TablePlayerActionApplicationFlowController", "TEST_ONLY", ("table_player_action_application_flow_test", "alpha04_player_card_dock_production_cutover_test")),
    ("scripts/runtime/product_market_frozen_target_context.gd", "component.current.product_market_frozen_target_context", "ProductMarketFrozenTargetContext", "TEST_ONLY", ("card_resolution_product_market_target_envelope_test", "card_resolution_stable_target_envelope_test")),
    (MILITARY_PATH, MILITARY_COMPONENT_ID, "MilitaryRuntimeController", "SUPERSEDED_OWNER", ("v076_private_military_direct_action_integration_test", "v075_application_composition_test")),
    ("scenes/CardUI.tscn", "component.current.card_ui_scene", "CardUIScene", "ACTIVE_PRESENTATION", ("v076_alpha07_human_playability_readiness_test", "card_illustration_layer_test")),
    ("scripts/runtime/runtime_world_ports.gd", "component.current.runtime_world_ports", "RuntimeWorldPorts", "TEST_ONLY", ("typed_world_ports_boundary_test", "runtime_loop_cutover_test")),
    ("scripts/runtime/simulation_state_identity.gd", "component.current.simulation_state_identity", "SimulationStateIdentity", "TEST_ONLY", ("simulation_determinism_foundation_test", "runtime_loop_cutover_test")),
    ("scripts/runtime/card_resolution_runtime_controller.gd", "component.current.card_resolution_runtime_controller", "CardResolutionRuntimeController", "TEST_ONLY", ("card_resolution_runtime_controller_test", "shared_card_window_production_cutover_v06_test")),
    ("scripts/viewmodels/action_dock_snapshot.gd", "component.current.action_dock_snapshot", "ActionDockSnapshot", "TEST_ONLY", ("layout_scene_smoke_test", "player_board_strategy_action_port_test")),
    ("scripts/runtime/weather_definition.gd", "component.current.weather_definition", "WeatherDefinition", "TEST_ONLY", ("weather_card_ai_v1_test", "weather_v1_save_privacy_acceptance_test")),
    ("scripts/presentation/table_public_map_projection.gd", "component.current.table_public_map_projection", "TablePublicMapProjection", "TEST_ONLY", ("table_presentation_query_ports_cutover_test", "world_session_geometry_owner_cutover_test")),
    ("scripts/presentation/district_supply_viewer_query_port.gd", "component.current.district_supply_viewer_query_port", "DistrictSupplyViewerQueryPort", "TEST_ONLY", ("district_supply_surface_query_cutover_test", "layout_scene_smoke_test")),
    ("scripts/runtime/runtime_loop.gd", "component.current.runtime_loop", "RuntimeLoop", "TEST_ONLY", ("runtime_loop_cutover_test", "simulation_determinism_foundation_test")),
    ("scripts/runtime/table_selection_state.gd", "component.current.table_selection_state", "TableSelectionState", "TEST_ONLY", ("selected_player_actor_authority_split_test", "public_card_track_focus_selection_cutover_test")),
    ("scripts/runtime/weather_runtime_controller.gd", "component.current.weather_runtime_controller", "WeatherRuntimeController", "TEST_ONLY", ("layout_scene_smoke_test", "visual_cue_runtime_owner_cutover_test")),
    ("scripts/presentation/developer_balance_presentation_snapshot.gd", "component.current.developer_balance_presentation_snapshot", "DeveloperBalancePresentationSnapshot", "TEST_ONLY", ("runtime_balance_report_test", "table_presentation_query_ports_cutover_test")),
    ("scripts/runtime/monster_runtime_world_bridge.gd", "component.current.monster_runtime_world_bridge", "MonsterRuntimeWorldBridge", "TEST_ONLY", ("monster_card_real_owner_integration_v06_test", "run_rng_service_cutover_test")),
    ("scenes/runtime/RoleCatalogRuntimeService.tscn", "component.current.role_catalog_runtime_service_scene", "RoleCatalogRuntimeServiceScene", "ACTIVE_PORT", ("role_catalog_runtime_service_test", "alpha01_manifest_runtime_activation_test")),
    ("scripts/presentation/victory_presentation_receipt_service.gd", "component.current.victory_presentation_receipt_service", "VictoryPresentationReceiptService", "TEST_ONLY", ("runtime_victory_port_terminal_presentation_exact_once_test", "v075_final_settlement_presentation_exact_once_regression_test")),
    ("scripts/runtime/weather_definition_catalog.gd", "component.current.weather_definition_catalog", "WeatherDefinitionCatalog", "TEST_ONLY", ("weather_card_ai_v1_test", "weather_v1_save_privacy_acceptance_test")),
    ("scripts/runtime/role_catalog_runtime_service.gd", "component.current.role_catalog_runtime_service", "RoleCatalogRuntimeService", "ACTIVE_PORT", ("role_catalog_runtime_service_test", "alpha01_manifest_runtime_activation_test")),
    ("scripts/runtime/world_session_state.gd", "component.current.world_session_state", "WorldSessionState", "TEST_ONLY", ("world_session_state_cutover_test", "session_envelope_save_owner_test")),
    ("scripts/runtime/runtime_simulation_step.gd", "component.current.runtime_simulation_step", "RuntimeSimulationStep", "TEST_ONLY", ("simulation_determinism_foundation_test", "runtime_loop_cutover_test")),
    ("scripts/balance/runtime_balance_model.gd", "component.current.runtime_balance_model", "ANONYMOUS_PATH_BOUND:scripts/balance/runtime_balance_model.gd", "TEST_ONLY", ("runtime_balance_report_test", "main_runtime_composition_test")),
    ("scripts/ai/ai_personality_policy_resource.gd", "component.current.ai_personality_policy_resource", "AiPersonalityPolicyResource", "TEST_ONLY", ("ai_business_cost_architecture_gate_test", "layout_scene_smoke_test")),
    ("scripts/runtime/region_infrastructure_world_bridge.gd", "component.current.region_infrastructure_world_bridge", "RegionInfrastructureWorldBridge", "TEST_ONLY", ("district_supply_runtime_query_port_cutover_test", "region_codex_public_source_test")),
    ("scripts/presentation/world_map_geometry_projection.gd", "component.current.world_map_geometry_projection", "WorldMapGeometryProjection", "TEST_ONLY", ("world_session_geometry_owner_cutover_test", "table_presentation_query_ports_cutover_test")),
    ("scripts/presentation/table_action_presentation_query.gd", "component.current.table_action_presentation_query", "TableActionPresentationQuery", "TEST_ONLY", ("table_presentation_query_ports_cutover_test", "public_card_track_focus_selection_cutover_test")),
    ("scripts/viewmodels/public_track_snapshot.gd", "component.current.public_track_snapshot", "PublicTrackSnapshot", "TEST_ONLY", ("layout_scene_smoke_test", "public_card_track_focus_selection_cutover_test")),
    ("scripts/semantic/game_action_card_binding_v1.gd", "component.current.game_action_card_binding_v1", "GameActionCardBindingV1", "TEST_ONLY", ("game_action_semantic_protocol_v1_test", "player_card_dock_projection_v1_test")),
    ("scripts/presentation/table_action_presentation_projection.gd", "component.current.table_action_presentation_projection", "TableActionPresentationProjection", "TEST_ONLY", ("table_presentation_query_ports_cutover_test", "public_card_track_focus_selection_cutover_test")),
    ("scripts/runtime/weather_effect_resolver.gd", "component.current.weather_effect_resolver", "WeatherEffectResolver", "TEST_ONLY", ("weather_card_ai_v1_test", "weather_economy_v1_test")),
    ("scripts/runtime/district_purchase_runtime_controller.gd", "component.current.district_purchase_runtime_controller", "DistrictPurchaseRuntimeController", "TEST_ONLY", ("main_runtime_composition_test", "district_supply_surface_query_cutover_test")),
    ("resources/weather/weather_definition_catalog_v1.tres", "component.current.weather_definition_catalog_v1_resource_instance", "WeatherDefinitionCatalogV1ResourceInstance", "TEST_ONLY", ("weather_card_ai_v1_test", "weather_v1_save_privacy_acceptance_test")),
)


def canonical(value: Any) -> bytes:
    return json.dumps(
        value, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8") + b"\n"


def compact(value: Any) -> bytes:
    return json.dumps(
        value, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")


def sha(value: bytes) -> str:
    return shared.sha(value)


def line_set(values: Iterable[str]) -> str:
    return sha(("\n".join(sorted(values)) + "\n").encode("utf-8"))


def _payload_hash_valid(value: dict[str, Any], field: str) -> bool:
    declared = value.get(field)
    if not isinstance(declared, str) or len(declared) != 64:
        return False
    payload = dict(value)
    payload.pop(field, None)
    return declared == sha(canonical(payload))


def _full_head(root: Path, ref: str = "HEAD") -> tuple[str, str]:
    head = shared.git(root, "rev-parse", f"{ref}^{{commit}}")
    live = shared.git(root, "rev-parse", "HEAD")
    if head != live:
        raise ProjectionError("HEAD_REF_NOT_LIVE_HEAD")
    return head, shared.git(root, "show", "-s", "--format=%T", head)


def _strict_document(payload: bytes, label: str) -> dict[str, Any]:
    try:
        value = json.loads(payload.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ProjectionError(f"{label}_JSON_INVALID") from exc
    if not isinstance(value, dict):
        raise ProjectionError(f"{label}_NOT_OBJECT")
    return value


def _scan_value_end(payload: bytes, start: int) -> int:
    if start >= len(payload) or payload[start] not in (ord("{"), ord("[")):
        raise ProjectionError("JSON_VALUE_START_INVALID")
    opener = payload[start]
    closer = ord("}") if opener == ord("{") else ord("]")
    depth = 0
    quoted = False
    escaped = False
    for index in range(start, len(payload)):
        char = payload[index]
        if quoted:
            if escaped:
                escaped = False
            elif char == ord("\\"):
                escaped = True
            elif char == ord('"'):
                quoted = False
            continue
        if char == ord('"'):
            quoted = True
        elif char == opener:
            depth += 1
        elif char == closer:
            depth -= 1
            if depth == 0:
                return index + 1
    raise ProjectionError("JSON_VALUE_UNTERMINATED")


def _top_level_value_span(payload: bytes, key: str) -> tuple[int, int]:
    marker = json.dumps(key).encode("ascii")
    matches: list[tuple[int, int]] = []
    offset = 0
    while True:
        found = payload.find(marker, offset)
        if found < 0:
            break
        colon = payload.find(b":", found + len(marker))
        if colon < 0:
            break
        start = colon + 1
        while start < len(payload) and payload[start] in b" \t\r\n":
            start += 1
        if start < len(payload) and payload[start] in (ord("{"), ord("[")):
            matches.append((start, _scan_value_end(payload, start)))
        offset = found + len(marker)
    if len(matches) != 1:
        raise ProjectionError(f"TOP_LEVEL_VALUE_NOT_UNIQUE:{key}:{len(matches)}")
    return matches[0]


def _array_object_span(
    payload: bytes, array_key: str, id_key: str, id_value: str
) -> tuple[int, int, dict[str, Any]]:
    start, end = _top_level_value_span(payload, array_key)
    cursor = start + 1
    matches: list[tuple[int, int, dict[str, Any]]] = []
    while cursor < end - 1:
        while cursor < end - 1 and payload[cursor] in b" \t\r\n,":
            cursor += 1
        if cursor >= end - 1:
            break
        if payload[cursor] != ord("{"):
            raise ProjectionError(f"ARRAY_ELEMENT_NOT_OBJECT:{array_key}")
        object_end = _scan_value_end(payload, cursor)
        value = _strict_document(payload[cursor:object_end], f"{array_key}_ROW")
        if value.get(id_key) == id_value:
            matches.append((cursor, object_end, value))
        cursor = object_end
    if len(matches) != 1:
        raise ProjectionError(
            f"ARRAY_ROW_NOT_UNIQUE:{array_key}:{id_key}:{id_value}:{len(matches)}"
        )
    return matches[0]


def _render_value(value: Any, base_indent: int) -> bytes:
    text = json.dumps(value, ensure_ascii=False, indent=2)
    prefix = " " * base_indent
    return text.replace("\n", "\n" + prefix).encode("utf-8")


def _replace_span(payload: bytes, start: int, end: int, replacement: bytes) -> bytes:
    return payload[:start] + replacement + payload[end:]


def _replace_array_row(
    payload: bytes,
    array_key: str,
    id_key: str,
    id_value: str,
    replacement: dict[str, Any],
) -> bytes:
    start, end, _ = _array_object_span(payload, array_key, id_key, id_value)
    return _replace_span(payload, start, end, _render_value(replacement, 4))


def _append_array_rows(
    payload: bytes, array_key: str, rows: list[dict[str, Any]], *, compact_rows: bool
) -> bytes:
    start, end = _top_level_value_span(payload, array_key)
    close = end - 1
    content_end = close
    while content_end > start + 1 and payload[content_end - 1] in b" \t\r\n":
        content_end -= 1
    if content_end == start + 1:
        prefix = b"\n"
    else:
        prefix = b",\n"
    rendered = []
    for row in rows:
        value = compact(row) if compact_rows else _render_value(row, 4)
        rendered.append(b"    " + value if compact_rows else b"    " + value)
    insertion = prefix + b",\n".join(rendered)
    return payload[:content_end] + insertion + payload[content_end:]


def _replace_top_level_value(payload: bytes, key: str, value: Any) -> bytes:
    start, end = _top_level_value_span(payload, key)
    return _replace_span(payload, start, end, _render_value(value, 2))


def _one(rows: list[Any], key: str, value: str, label: str) -> dict[str, Any]:
    matches = [row for row in rows if isinstance(row, dict) and row.get(key) == value]
    if len(matches) != 1:
        raise ProjectionError(f"{label}_NOT_UNIQUE:{len(matches)}")
    return matches[0]


def _membership_paths(membership: dict[str, Any]) -> dict[str, str]:
    return materializer._failure_paths(membership)


def _validate_specs(membership: dict[str, Any]) -> None:
    if len(COMPONENT_SPECS) != 50:
        raise ProjectionError("SPEC_COUNT_INVALID")
    paths = [row[0] for row in COMPONENT_SPECS]
    component_ids = [row[1] for row in COMPONENT_SPECS]
    class_names = [row[2] for row in COMPONENT_SPECS]
    dispositions = [row[3] for row in COMPONENT_SPECS]
    expected_paths = set(_membership_paths(membership).values())
    if set(paths) != expected_paths or len(paths) != len(set(paths)):
        raise ProjectionError("SPEC_PATH_SET_INVALID")
    if len(component_ids) != len(set(component_ids)):
        raise ProjectionError("SPEC_COMPONENT_ID_COLLISION")
    if len(class_names) != len(set(class_names)):
        raise ProjectionError("SPEC_CLASS_NAME_COLLISION")
    if set(dispositions) != {
        "TEST_ONLY",
        "ACTIVE_PRESENTATION",
        "ACTIVE_PORT",
        "SUPERSEDED_OWNER",
    }:
        raise ProjectionError("SPEC_DISPOSITION_SET_INVALID")
    forbidden = ("UNKNOWN", "WAIVE", "WILDCARD", "IGNORE", "OTHER", "MISC")
    for spec in COMPONENT_SPECS:
        rendered = "|".join((spec[0], spec[1], spec[2], spec[3]))
        if any(token in rendered.upper() for token in forbidden):
            raise ProjectionError(f"SPEC_FORBIDDEN_CLASSIFICATION:{spec[0]}")
        if any(char in spec[0] for char in "*?[]"):
            raise ProjectionError(f"SPEC_WILDCARD_PATH:{spec[0]}")
    military = [row for row in COMPONENT_SPECS if row[0] == MILITARY_PATH]
    if len(military) != 1 or military[0][3] != "SUPERSEDED_OWNER":
        raise ProjectionError("MILITARY_FALSE_CLASSIFICATION")


def _reuse_scan() -> dict[str, Any]:
    return {
        "reuse_registry_search": True,
        "class_name_search": True,
        "semantic_signature_search": True,
        "owner_map_search": True,
        "state_write_surface_search": True,
        "rng_owner_search": True,
        "save_owner_search": True,
        "replay_owner_search": True,
        "signal_and_receipt_search": True,
        "reuse_candidate_count": 1,
        "reuse_candidate_ids": [MILITARY_REUSE_ID],
        "selected_reuse_disposition": "ADOPT_AS_OWNER",
        "why_existing_owner_cannot_be_extended": (
            "Historical identity only: this row records the former standalone "
            "Owner and does not authorize a new production Owner."
        ),
        "why_adapter_is_insufficient": (
            "The V076 adapter is a stateless consumer and is intentionally not "
            "registered as the unit-state Owner."
        ),
        "why_new_owner_is_required": (
            "No new Owner is created; the current production unit-state APIs are "
            "owned by the existing V075RuntimeOwner."
        ),
    }


def _component_row(spec: tuple[Any, ...]) -> dict[str, Any]:
    path, component_id, class_name, disposition, tests = spec
    active = disposition in {"ACTIVE_PRESENTATION", "ACTIVE_PORT"}
    role = {
        "TEST_ONLY": "TEST_SUPPORT",
        "ACTIVE_PRESENTATION": "PRESENTATION",
        "ACTIVE_PORT": "PORT",
        "SUPERSEDED_OWNER": "OWNER",
    }[disposition]
    is_military = disposition == "SUPERSEDED_OWNER"
    if disposition == "TEST_ONLY":
        justification = (
            f"Historical {class_name} at {path} is retained only for the detached "
            "GameRuntimeCoordinator/focused-test graph after the V075 production "
            "cutover. It creates no gameplay, catalog, asset, topology, tick, RNG, "
            "save, replay, identity, or presentation Owner."
        )
    elif disposition == "ACTIVE_PRESENTATION":
        justification = (
            "Existing CardUI scene remains a production-reachable presentation "
            "consumer through CardFace and V075InteractiveCardFace. It owns no card "
            "definition, hand, gameplay, exact-once, asset, tick, RNG, save, replay, "
            "identity, or presentation authority."
        )
    elif disposition == "ACTIVE_PORT":
        justification = (
            f"Existing {class_name} remains an immutable role-catalog input port "
            "transitively loaded by the Alpha01 content manifest used by the current "
            "V075 runtime. It owns no session, gameplay, asset, topology, tick, RNG, "
            "save, replay, identity, or presentation authority."
        )
    else:
        justification = (
            "Historical MilitaryRuntimeController records the former standalone "
            "military-unit-state Owner. It is forbidden from the current V075 "
            "production composition and is superseded by V075RuntimeOwner; the "
            "remaining file is a non-production focused-test surface only."
        )
    row: dict[str, Any] = {
        "component_id": component_id,
        "class_name": class_name,
        "path": path,
        "domain_id": DOMAIN_ID,
        "component_role": role,
        "production_reachable": active,
        "writes_authority": False,
        "reads_authority": True,
        "owns_rng": False,
        "owns_tick": False,
        "owns_save": False,
        "owns_replay": False,
        "owns_identity": False,
        "owns_presentation": False,
        "owner_component_id": component_id if is_military else CURRENT_OWNER_ID,
        "owner_path": path if is_military else CURRENT_OWNER_PATH,
        "reuse_disposition": "ADOPT_AS_OWNER" if is_military else (
            "ADAPT_AS_CONSUMER" if active else "REUSE_AS_TEST"
        ),
        "reuse_source_ids": [
            MILITARY_REUSE_ID
            if is_military
            else (
                "reuse.current.card_runtime_catalog"
                if disposition == "ACTIVE_PRESENTATION"
                else "reuse.v075.combat_candidate"
            )
        ],
        "reuse_candidates_considered": [
            MILITARY_REUSE_ID
            if is_military
            else (
                "reuse.current.card_runtime_catalog"
                if disposition == "ACTIVE_PRESENTATION"
                else "reuse.v075.combat_candidate"
            )
        ],
        "new_component_justification": justification,
        "supersedes": [],
        "superseded_by": [CURRENT_OWNER_ID] if is_military else [],
        "change_class": "PRODUCTION_COMPOSITION",
        "focused_test_ids": list(tests),
        "golden_scenario_steps": (
            ["STEP06", "STEP07"]
            if disposition == "ACTIVE_PRESENTATION"
            else (["STEP01"] if disposition == "ACTIVE_PORT" else [])
        ),
    }
    if is_military:
        row["reuse_scan"] = _reuse_scan()
    return row


def _source_blob(root: Path, commit: str, path: str) -> str:
    return sha(materializer.committed(root, commit, path))


def _component_rows(
    root: Path, head: str, membership: dict[str, Any]
) -> tuple[list[dict[str, Any]], int]:
    _validate_specs(membership)
    rows: list[dict[str, Any]] = []
    drift = 0
    for spec in COMPONENT_SPECS:
        path, _component_id, class_name, _disposition, _tests = spec
        source = materializer.committed(root, SOURCE_COMMIT, path)
        current = materializer.committed(root, head, path)
        if source != current:
            drift += 1
        identity = materializer.source_identity(root, SOURCE_COMMIT, path)
        if identity["identity_kind"] == "GDSCRIPT":
            declared = identity["declared_class_name"]
            expected = declared or f"ANONYMOUS_PATH_BOUND:{path}"
            if class_name != expected:
                raise ProjectionError(f"CLASS_IDENTITY_MISMATCH:{path}")
        rows.append(_component_row(spec))
    if drift:
        raise ProjectionError(f"SOURCE_CURRENT_BLOB_DRIFT:{drift}")
    return rows, drift


def _military_backfill(root: Path) -> dict[str, Any]:
    return {
        "component_id": MILITARY_COMPONENT_ID,
        "current_disposition": "HISTORICAL_SUPERSEDED_NONREACHABLE",
        "historical_role": "OWNER",
        "production_reachability": "NONREACHABLE",
        "source_blob": _source_blob(root, SOURCE_COMMIT, MILITARY_PATH),
        "source_commit": SOURCE_COMMIT,
        "supersession": [CURRENT_OWNER_ID],
    }


def _military_supersession(root: Path) -> dict[str, Any]:
    return {
        "supersession_id": MILITARY_SUPERSESSION_ID,
        "domain_id": DOMAIN_ID,
        "kind": MILITARY_SUPERSESSION_KIND,
        "old_component_id": MILITARY_COMPONENT_ID,
        "new_component_id": CURRENT_OWNER_ID,
        "old_owner_path": MILITARY_PATH,
        "new_owner_path": CURRENT_OWNER_PATH,
        "old_authority_source_kind": "historical_identity_backfill",
        "old_source_commit": SOURCE_COMMIT,
        "old_source_blob_sha256": _source_blob(root, SOURCE_COMMIT, MILITARY_PATH),
        "production_scene_path": "scenes/main.tscn",
        "old_runtime_composition_path": "scenes/runtime/GameRuntimeCoordinator.tscn",
        "old_component_scene_path": "scenes/runtime/MilitaryRuntimeController.tscn",
        "new_runtime_composition_path": "scenes/runtime/V075RuntimeComposition.tscn",
        "production_adapter_path": "scripts/v076/direct_action/v076_v075_production_adapter_v1.gd",
        "replacement_reason": (
            "MilitaryRuntimeController is retained only in the detached legacy/test "
            "composition. Current production military unit state and its mutation APIs "
            "are owned by the existing V075RuntimeOwner; the V076 adapter only consumes "
            "that authority."
        ),
        "migration_strategy": (
            "The production application flow cut over atomically at "
            f"{CUTOVER_COMMIT}; main.tscn composes V075RuntimeComposition, the old "
            "MilitaryRuntimeController scene is forbidden, and no dual write or "
            "fallback remains."
        ),
        "consumer_inventory": [
            "component.v076.v075_production_adapter",
            CURRENT_OWNER_ID,
        ],
        "save_impact": "NONE_EXISTING_V075_OWNER_STATE",
        "rng_impact": "NONE_EXISTING_V076_KERNEL_SEQUENCE",
        "replay_impact": (
            "No replay input, tick, authority sequence, or cursor is added; the "
            "existing deterministic runtime lineage remains authoritative."
        ),
        "cutover_commit": CUTOVER_COMMIT,
        "old_owner_retirement_status": "RETIRED_BY_CONSTITUTION",
        "dual_write_count": 0,
        "fallback_count": 0,
        "old_owner_production_reachability": 0,
        "new_owner_production_owner_count": 1,
    }


def _retired_military_reuse(before: dict[str, Any]) -> dict[str, Any]:
    return {
        "reuse_id": before["reuse_id"],
        "domain_id": before["domain_id"],
        "disposition": "RETIRED",
        "source": copy.deepcopy(before["source"]),
        "retirement_scope": (
            "The standalone MilitaryRuntimeController no longer owns current military "
            "unit state. The V075 production cutover keeps that authority in "
            "V075RuntimeOwner and retains the old path only for detached focused tests."
        ),
        "forbidden_scope": (
            "Do not restore the legacy controller, its scene, a parallel unit roster, "
            "dual write, fallback, GUARD, or PROTECT into current production."
        ),
    }


def _validate_component_rows(
    before: dict[str, Any], after: dict[str, Any], rows: list[dict[str, Any]]
) -> None:
    before_inventory = before.get("component_inventory")
    after_inventory = after.get("component_inventory")
    if not isinstance(before_inventory, list) or not isinstance(after_inventory, list):
        raise ProjectionError("COMPONENT_INVENTORY_INVALID")
    old_paths = {str(row.get("path", "")) for row in before_inventory if isinstance(row, dict)}
    old_ids = {str(row.get("component_id", "")) for row in before_inventory if isinstance(row, dict)}
    old_classes = {str(row.get("class_name", "")) for row in before_inventory if isinstance(row, dict)}
    for row in rows:
        allowed_fields = COMPONENT_FIELDS | ({"reuse_scan"} if row["component_id"] == MILITARY_COMPONENT_ID else set())
        if set(row) != allowed_fields:
            raise ProjectionError(f"COMPONENT_FIELD_SET_INVALID:{row['component_id']}")
        if row["path"] in old_paths:
            raise ProjectionError(f"COMPONENT_PATH_COLLISION:{row['path']}")
        if row["component_id"] in old_ids:
            raise ProjectionError(f"COMPONENT_ID_COLLISION:{row['component_id']}")
        if row["class_name"] in old_classes:
            raise ProjectionError(f"COMPONENT_CLASS_COLLISION:{row['class_name']}")
    if (
        len(after_inventory) != len(before_inventory) + len(rows)
        or after_inventory[len(before_inventory) :] != rows
    ):
        raise ProjectionError("COMPONENT_APPEND_NOT_EXACT")
    for before_row, after_row in zip(
        before_inventory, after_inventory[: len(before_inventory)]
    ):
        component_id = str(before_row.get("component_id", ""))
        if component_id == CURRENT_OWNER_ID:
            expected = copy.deepcopy(before_row)
            expected["supersedes"] = list(expected.get("supersedes", [])) + [
                MILITARY_COMPONENT_ID
            ]
            if after_row != expected:
                raise ProjectionError("CURRENT_OWNER_MUTATION_NOT_EXACT")
        elif after_row != before_row:
            raise ProjectionError(f"PREEXISTING_COMPONENT_MUTATED:{component_id}")


def _validate_projection(
    before_registry: dict[str, Any],
    after_registry: dict[str, Any],
    before_map: dict[str, Any],
    after_map: dict[str, Any],
    rows: list[dict[str, Any]],
    root: Path,
) -> None:
    _validate_component_rows(before_registry, after_registry, rows)
    military = _one(
        after_registry["component_inventory"],
        "component_id",
        MILITARY_COMPONENT_ID,
        "MILITARY_COMPONENT",
    )
    owner = _one(
        after_registry["component_inventory"],
        "component_id",
        CURRENT_OWNER_ID,
        "CURRENT_OWNER",
    )
    if not (
        military.get("component_role") == "OWNER"
        and military.get("production_reachable") is False
        and military.get("writes_authority") is False
        and military.get("superseded_by") == [CURRENT_OWNER_ID]
        and military.get("reuse_disposition") == "ADOPT_AS_OWNER"
        and owner.get("component_role") == "OWNER"
        and owner.get("production_reachable") is True
        and owner.get("writes_authority") is True
        and MILITARY_COMPONENT_ID in owner.get("supersedes", [])
    ):
        raise ProjectionError("MILITARY_OWNER_TO_OWNER_RECIPROCAL_INVALID")
    retired = _one(
        after_registry["reuse_entries"],
        "reuse_id",
        MILITARY_REUSE_ID,
        "MILITARY_REUSE",
    )
    if retired.get("disposition") != "RETIRED":
        raise ProjectionError("MILITARY_STALE_ACTIVE_REUSE_ENTRY")
    backfill = _one(
        after_registry["historical_identity_backfill"],
        "component_id",
        MILITARY_COMPONENT_ID,
        "MILITARY_BACKFILL",
    )
    if backfill != _military_backfill(root):
        raise ProjectionError("MILITARY_BACKFILL_INVALID")
    if after_map.get("supersession_kinds", []).count(MILITARY_SUPERSESSION_KIND) != 1:
        raise ProjectionError("MILITARY_SUPERSESSION_KIND_INVALID")
    relation = _one(
        after_map["entries"],
        "supersession_id",
        MILITARY_SUPERSESSION_ID,
        "MILITARY_SUPERSESSION",
    )
    if relation != _military_supersession(root):
        raise ProjectionError("MILITARY_SUPERSESSION_INVALID")
    if set(before_registry) != set(after_registry) or set(before_map) != set(after_map):
        raise ProjectionError("TOP_LEVEL_SCHEMA_DRIFT")
    if after_map["summary"].get("entry_count") != len(after_map["entries"]):
        raise ProjectionError("SUPERSESSION_SUMMARY_COUNT_INVALID")


def _build_registry_target(
    root: Path, head: str, source: bytes, membership: dict[str, Any]
) -> tuple[bytes, dict[str, Any], dict[str, Any], list[dict[str, Any]], list[dict[str, Any]]]:
    before = _strict_document(source, "REGISTRY")
    after = copy.deepcopy(before)
    rows, _drift = _component_rows(root, head, membership)
    current_owner = _one(
        after["component_inventory"], "component_id", CURRENT_OWNER_ID, "CURRENT_OWNER"
    )
    if MILITARY_COMPONENT_ID in current_owner.get("supersedes", []):
        raise ProjectionError("MILITARY_RECIPROCAL_ALREADY_PRESENT")
    current_owner["supersedes"] = list(current_owner.get("supersedes", [])) + [
        MILITARY_COMPONENT_ID
    ]
    stale = _one(
        after["reuse_entries"], "reuse_id", MILITARY_REUSE_ID, "MILITARY_REUSE"
    )
    retired = _retired_military_reuse(stale)
    after["reuse_entries"][after["reuse_entries"].index(stale)] = retired
    after["component_inventory"].extend(rows)
    backfill = _military_backfill(root)
    if any(
        isinstance(row, dict) and row.get("component_id") == MILITARY_COMPONENT_ID
        for row in after["historical_identity_backfill"]
    ):
        raise ProjectionError("MILITARY_BACKFILL_ALREADY_PRESENT")
    after["historical_identity_backfill"].append(backfill)

    target = source
    target = _replace_array_row(
        target,
        "component_inventory",
        "component_id",
        CURRENT_OWNER_ID,
        current_owner,
    )
    target = _append_array_rows(
        target, "component_inventory", rows, compact_rows=True
    )
    target = _append_array_rows(
        target, "historical_identity_backfill", [backfill], compact_rows=True
    )
    target = _replace_array_row(
        target, "reuse_entries", "reuse_id", MILITARY_REUSE_ID, retired
    )
    parsed_target = _strict_document(target, "REGISTRY_TARGET")
    if canonical(parsed_target) != canonical(after):
        raise ProjectionError("REGISTRY_TARGET_SEMANTIC_PARITY_INVALID")
    return target, before, after, rows, [backfill]


def _build_map_target(
    root: Path, source: bytes
) -> tuple[bytes, dict[str, Any], dict[str, Any], dict[str, Any]]:
    before = _strict_document(source, "SUPERSESSION")
    after = copy.deepcopy(before)
    if MILITARY_SUPERSESSION_KIND in after.get("supersession_kinds", []):
        raise ProjectionError("MILITARY_SUPERSESSION_KIND_ALREADY_PRESENT")
    after["supersession_kinds"].append(MILITARY_SUPERSESSION_KIND)
    relation = _military_supersession(root)
    if any(
        isinstance(row, dict)
        and row.get("supersession_id") == MILITARY_SUPERSESSION_ID
        for row in after.get("entries", [])
    ):
        raise ProjectionError("MILITARY_SUPERSESSION_ALREADY_PRESENT")
    after["entries"].append(relation)
    after["summary"]["entry_count"] = len(after["entries"])
    after["summary"]["retired_authority_count"] = int(
        after["summary"].get("retired_authority_count", 0)
    ) + 1

    target = _replace_top_level_value(
        source, "supersession_kinds", after["supersession_kinds"]
    )
    target = _append_array_rows(target, "entries", [relation], compact_rows=False)
    target = _replace_top_level_value(target, "summary", after["summary"])
    parsed_target = _strict_document(target, "SUPERSESSION_TARGET")
    if canonical(parsed_target) != canonical(after):
        raise ProjectionError("SUPERSESSION_TARGET_SEMANTIC_PARITY_INVALID")
    return target, before, after, relation


def _source(
    root: Path,
    head: str,
    relative: Path,
    *,
    require_worktree_parity: bool,
) -> dict[str, Any]:
    payload = (
        materializer._require_worktree_parity(root, head, relative)
        if require_worktree_parity
        else materializer.committed(root, head, relative)
    )
    return {
        "path": relative.as_posix(),
        "source_blob_oid": shared._git_blob_oid(root, head, relative),
        "source_bytes_sha256": sha(payload),
        "source_byte_count": len(payload),
        "bytes": payload,
    }


def _target_entry(source: dict[str, Any], target: bytes) -> dict[str, Any]:
    return {
        "path": source["path"],
        "source_blob_oid": source["source_blob_oid"],
        "source_bytes_sha256": source["source_bytes_sha256"],
        "source_byte_count": source["source_byte_count"],
        "target_encoding": "BASE64",
        "target_bytes_base64": base64.b64encode(target).decode("ascii"),
        "target_bytes_sha256": sha(target),
        "target_byte_count": len(target),
    }


def _mutation(
    path: str,
    operation: str,
    locator: str,
    before: Any | None,
    after: Any,
) -> dict[str, Any]:
    return {
        "target_path": path,
        "operation": operation,
        "locator": locator,
        "before_exists": before is not None,
        "before_canonical_sha256": sha(canonical(before)) if before is not None else "",
        "after_canonical_sha256": sha(canonical(after)),
    }


def _projection(
    root: Path,
    head: str,
    membership: dict[str, Any],
    *,
    require_worktree_parity: bool = True,
) -> dict[str, Any]:
    registry_source = _source(
        root, head, REGISTRY, require_worktree_parity=require_worktree_parity
    )
    map_source = _source(
        root, head, SUPERSESSION, require_worktree_parity=require_worktree_parity
    )
    (
        registry_target,
        before_registry,
        after_registry,
        component_rows,
        backfills,
    ) = _build_registry_target(
        root, head, registry_source["bytes"], membership
    )
    map_target, before_map, after_map, relation = _build_map_target(
        root, map_source["bytes"]
    )
    _validate_projection(
        before_registry,
        after_registry,
        before_map,
        after_map,
        component_rows,
        root,
    )
    before_owner = _one(
        before_registry["component_inventory"],
        "component_id",
        CURRENT_OWNER_ID,
        "BEFORE_OWNER",
    )
    after_owner = _one(
        after_registry["component_inventory"],
        "component_id",
        CURRENT_OWNER_ID,
        "AFTER_OWNER",
    )
    before_reuse = _one(
        before_registry["reuse_entries"],
        "reuse_id",
        MILITARY_REUSE_ID,
        "BEFORE_MILITARY_REUSE",
    )
    after_reuse = _one(
        after_registry["reuse_entries"],
        "reuse_id",
        MILITARY_REUSE_ID,
        "AFTER_MILITARY_REUSE",
    )
    mutations = [
        _mutation(
            REGISTRY.as_posix(),
            "APPEND_EXACT_COMPONENT_INVENTORY_ROWS",
            f"batch_id={BATCH_ID};count=50;path_set_sha256={line_set(row['path'] for row in component_rows)}",
            None,
            component_rows,
        ),
        _mutation(
            REGISTRY.as_posix(),
            "APPEND_RECIPROCAL_SUPERSEDES_LINK",
            f"component_id={CURRENT_OWNER_ID};old_component_id={MILITARY_COMPONENT_ID}",
            before_owner,
            after_owner,
        ),
        _mutation(
            REGISTRY.as_posix(),
            "RETIRE_STALE_REUSE_ENTRY",
            f"reuse_id={MILITARY_REUSE_ID}",
            before_reuse,
            after_reuse,
        ),
        _mutation(
            REGISTRY.as_posix(),
            "APPEND_HISTORICAL_IDENTITY_BACKFILL",
            f"component_id={MILITARY_COMPONENT_ID}",
            None,
            backfills[0],
        ),
        _mutation(
            SUPERSESSION.as_posix(),
            "DECLARE_EXACT_OWNER_TO_OWNER_KIND",
            f"kind={MILITARY_SUPERSESSION_KIND}",
            None,
            MILITARY_SUPERSESSION_KIND,
        ),
        _mutation(
            SUPERSESSION.as_posix(),
            "APPEND_EXACT_OWNER_TO_OWNER_SUPERSESSION",
            f"supersession_id={MILITARY_SUPERSESSION_ID}",
            None,
            relation,
        ),
    ]
    return {
        "target_files": [
            _target_entry(registry_source, registry_target),
            _target_entry(map_source, map_target),
        ],
        "target_bytes": {
            REGISTRY.as_posix(): registry_target,
            SUPERSESSION.as_posix(): map_target,
        },
        "mutations": mutations,
        "rows": component_rows,
    }


def _membership_authority(membership: dict[str, Any]) -> dict[str, Any]:
    stage = Path(membership["stage"])
    return {
        "candidate_path": (stage / "candidate.json").resolve().as_posix(),
        "candidate_file_sha256": membership["candidate_file_sha256"],
        "candidate_payload_sha256": membership["candidate"][
            "candidate_payload_sha256"
        ],
        "seal_path": (stage / "seal.json").resolve().as_posix(),
        "seal_file_sha256": membership["seal_file_sha256"],
        "seal_payload_sha256": membership["seal"]["seal_payload_sha256"],
        "primary_review_file_sha256": membership["review_file_sha256"]["PRIMARY"],
        "independent_review_file_sha256": membership["review_file_sha256"][
            "INDEPENDENT"
        ],
    }


def _classification_counts() -> dict[str, int]:
    values = [spec[3] for spec in COMPONENT_SPECS]
    return {
        "HISTORICAL_TEST_ONLY": values.count("TEST_ONLY"),
        "HISTORICAL_ACTIVE_LINEAGE_REGISTERED": values.count(
            "ACTIVE_PRESENTATION"
        )
        + values.count("ACTIVE_PORT"),
        "HISTORICAL_SUPERSEDED_NONREACHABLE": values.count(
            "SUPERSEDED_OWNER"
        ),
        "UNKNOWN": 0,
    }


def build_candidate(
    root: Path,
    membership_stage: Path,
    staging_root: Path,
    output: Path,
    head_ref: str = "HEAD",
) -> dict[str, Any]:
    root = root.resolve()
    head, tree = _full_head(root, head_ref)
    membership = materializer.validate_membership_stage(root, membership_stage)
    projection = _projection(root, head, membership)
    rows = projection["rows"]
    candidate = {
        "schema_version": CANDIDATE_SCHEMA,
        "candidate_kind": CANDIDATE_KIND,
        "authorization_id": convergence.AUTHORIZATION_ID,
        "batch_id": BATCH_ID,
        "evaluated_head_sha": head,
        "evaluated_tree_sha": tree,
        "source_commit": SOURCE_COMMIT,
        "membership_authority": _membership_authority(membership),
        "failure_count": 50,
        "failure_fingerprint_set_sha256": materializer.SEALED_MEMBERSHIP_SET_SHA256,
        "path_set_sha256": line_set(row["path"] for row in rows),
        "component_id_set_sha256": line_set(row["component_id"] for row in rows),
        "class_name_set_sha256": line_set(row["class_name"] for row in rows),
        "source_current_blob_drift_count": 0,
        "classification_counts": _classification_counts(),
        "target_files": projection["target_files"],
        "mutation_inventory": projection["mutations"],
        "mutation_inventory_sha256": sha(canonical(projection["mutations"])),
        "required_review_ids": ["PRIMARY", "INDEPENDENT"],
        "review_status": "PENDING",
        "go_claim": False,
        "official_write_count": 0,
        "next_phase": NEXT_REVIEW_PHASE,
    }
    candidate["candidate_payload_sha256"] = sha(canonical(candidate))
    safe_output = shared._assert_output_safe(root, staging_root, output)
    shared._exclusive_write(safe_output, canonical(candidate))
    return candidate


def _read_external(
    root: Path, path: Path, stage: Path, label: str
) -> tuple[dict[str, Any], bytes, Path]:
    resolved = shared._require_external_plain_file(path, label, root, stage)
    raw = resolved.read_bytes()
    value = _strict_document(raw, label)
    if raw != canonical(value):
        raise ProjectionError(f"{label}_BYTES_NOT_CANONICAL")
    return value, raw, resolved


def _decode_targets(candidate: dict[str, Any]) -> dict[str, bytes]:
    rows = candidate.get("target_files")
    if not isinstance(rows, list) or len(rows) != 2:
        raise ProjectionError("TARGET_SET_INVALID")
    result: dict[str, bytes] = {}
    for row in rows:
        if not isinstance(row, dict) or set(row) != TARGET_FIELDS:
            raise ProjectionError("TARGET_ROW_INVALID")
        try:
            payload = base64.b64decode(row["target_bytes_base64"], validate=True)
        except Exception as exc:
            raise ProjectionError("TARGET_BASE64_INVALID") from exc
        path = str(row.get("path", ""))
        if (
            path in result
            or path not in OUTPUT_ALLOWLIST
            or row.get("target_encoding") != "BASE64"
            or row.get("target_bytes_sha256") != sha(payload)
            or type(row.get("target_byte_count")) is not int
            or row.get("target_byte_count") != len(payload)
        ):
            raise ProjectionError("TARGET_BINDING_INVALID")
        result[path] = payload
    if list(result) != list(OUTPUT_ALLOWLIST):
        raise ProjectionError("TARGET_PATH_ORDER_INVALID")
    return result


def _validate_candidate_fresh(
    root: Path, candidate_path: Path, *, require_worktree_parity: bool
) -> tuple[dict[str, Any], str, dict[str, bytes]]:
    root = root.resolve()
    stage = candidate_path.parent
    candidate, raw, resolved = _read_external(
        root, candidate_path, stage, "PROJECTION_CANDIDATE"
    )
    static = {
        "schema_version": CANDIDATE_SCHEMA,
        "candidate_kind": CANDIDATE_KIND,
        "authorization_id": convergence.AUTHORIZATION_ID,
        "batch_id": BATCH_ID,
        "source_commit": SOURCE_COMMIT,
        "failure_count": 50,
        "failure_fingerprint_set_sha256": materializer.SEALED_MEMBERSHIP_SET_SHA256,
        "source_current_blob_drift_count": 0,
        "classification_counts": _classification_counts(),
        "required_review_ids": ["PRIMARY", "INDEPENDENT"],
        "review_status": "PENDING",
        "go_claim": False,
        "official_write_count": 0,
        "next_phase": NEXT_REVIEW_PHASE,
    }
    if (
        set(candidate) != CANDIDATE_FIELDS
        or any(candidate.get(key) != value for key, value in static.items())
        or not _payload_hash_valid(candidate, "candidate_payload_sha256")
    ):
        raise ProjectionError("CANDIDATE_CONTRACT_INVALID")
    head, tree = _full_head(root)
    if candidate.get("evaluated_head_sha") != head:
        raise ProjectionError("CANDIDATE_HEAD_DRIFT")
    if candidate.get("evaluated_tree_sha") != tree:
        raise ProjectionError("CANDIDATE_TREE_DRIFT")
    membership_authority = candidate.get("membership_authority")
    if not isinstance(membership_authority, dict):
        raise ProjectionError("MEMBERSHIP_AUTHORITY_INVALID")
    membership_stage = Path(str(membership_authority.get("candidate_path", ""))).parent
    membership = materializer.validate_membership_stage(root, membership_stage)
    if membership_authority != _membership_authority(membership):
        raise ProjectionError("MEMBERSHIP_AUTHORITY_DRIFT")
    targets = _decode_targets(candidate)
    mutations = candidate.get("mutation_inventory")
    if (
        not isinstance(mutations, list)
        or any(not isinstance(row, dict) or set(row) != MUTATION_FIELDS for row in mutations)
        or candidate.get("mutation_inventory_sha256") != sha(canonical(mutations))
    ):
        raise ProjectionError("MUTATION_INVENTORY_INVALID")
    projection = _projection(
        root,
        head,
        membership,
        require_worktree_parity=require_worktree_parity,
    )
    if candidate["target_files"] != projection["target_files"]:
        raise ProjectionError("CANDIDATE_TARGET_FRESH_PARITY_INVALID")
    if mutations != projection["mutations"]:
        raise ProjectionError("CANDIDATE_MUTATION_FRESH_PARITY_INVALID")
    return candidate, sha(raw), targets


def _target_rows(candidate: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {str(row["path"]): row for row in candidate["target_files"]}


def build_review(
    root: Path, candidate_path: Path, review_id: str, output: Path
) -> dict[str, Any]:
    root = root.resolve()
    candidate, _candidate_file_sha, _targets = _validate_candidate_fresh(
        root, candidate_path, require_worktree_parity=True
    )
    if review_id not in TRUSTED_REVIEWERS:
        raise ProjectionError("REVIEW_ID_INVALID")
    bindings = _target_rows(candidate)
    authority = candidate["membership_authority"]
    review = {
        "schema_version": REVIEW_SCHEMA,
        "review_id": review_id,
        "reviewer_authority_id": TRUSTED_REVIEWERS[review_id],
        "candidate_payload_sha256": candidate["candidate_payload_sha256"],
        "batch_id": BATCH_ID,
        "evaluated_head_sha": candidate["evaluated_head_sha"],
        "evaluated_tree_sha": candidate["evaluated_tree_sha"],
        "membership_candidate_file_sha256": authority["candidate_file_sha256"],
        "membership_seal_file_sha256": authority["seal_file_sha256"],
        "source_registry_sha256": bindings[REGISTRY.as_posix()][
            "source_bytes_sha256"
        ],
        "source_supersession_map_sha256": bindings[SUPERSESSION.as_posix()][
            "source_bytes_sha256"
        ],
        "target_registry_sha256": bindings[REGISTRY.as_posix()][
            "target_bytes_sha256"
        ],
        "target_supersession_map_sha256": bindings[SUPERSESSION.as_posix()][
            "target_bytes_sha256"
        ],
        "mutation_inventory_sha256": candidate["mutation_inventory_sha256"],
        "classification_counts": _classification_counts(),
        "military_owner_to_owner_supersession_verified": True,
        "status": "GO",
        "p0_count": 0,
        "p1_count": 0,
        "findings": [],
    }
    review["receipt_payload_sha256"] = sha(canonical(review))
    safe = shared._assert_output_safe(root, candidate_path.parent, output)
    shared._exclusive_write(safe, canonical(review))
    return review


def _validate_review(
    root: Path, stage: Path, candidate: dict[str, Any], path: Path
) -> tuple[dict[str, Any], Path, str]:
    review, raw, resolved = _read_external(root, path, stage, "PROJECTION_REVIEW")
    bindings = _target_rows(candidate)
    authority = candidate["membership_authority"]
    expected = {
        "candidate_payload_sha256": candidate["candidate_payload_sha256"],
        "batch_id": BATCH_ID,
        "evaluated_head_sha": candidate["evaluated_head_sha"],
        "evaluated_tree_sha": candidate["evaluated_tree_sha"],
        "membership_candidate_file_sha256": authority["candidate_file_sha256"],
        "membership_seal_file_sha256": authority["seal_file_sha256"],
        "source_registry_sha256": bindings[REGISTRY.as_posix()]["source_bytes_sha256"],
        "source_supersession_map_sha256": bindings[SUPERSESSION.as_posix()]["source_bytes_sha256"],
        "target_registry_sha256": bindings[REGISTRY.as_posix()]["target_bytes_sha256"],
        "target_supersession_map_sha256": bindings[SUPERSESSION.as_posix()]["target_bytes_sha256"],
        "mutation_inventory_sha256": candidate["mutation_inventory_sha256"],
        "classification_counts": _classification_counts(),
        "military_owner_to_owner_supersession_verified": True,
        "status": "GO",
        "p0_count": 0,
        "p1_count": 0,
        "findings": [],
    }
    review_id = str(review.get("review_id", ""))
    if (
        set(review) != REVIEW_FIELDS
        or review.get("schema_version") != REVIEW_SCHEMA
        or review.get("reviewer_authority_id") != TRUSTED_REVIEWERS.get(review_id)
        or any(review.get(key) != value for key, value in expected.items())
        or not _payload_hash_valid(review, "receipt_payload_sha256")
    ):
        raise ProjectionError(f"REVIEW_INVALID:{resolved.as_posix()}")
    return review, resolved, sha(raw)


def seal_candidate(
    root: Path,
    candidate_path: Path,
    reviews: list[Path],
    staging_root: Path,
    output: Path,
) -> dict[str, Any]:
    root = root.resolve()
    candidate, candidate_file_sha, _targets = _validate_candidate_fresh(
        root, candidate_path, require_worktree_parity=True
    )
    if len(reviews) != 2:
        raise ProjectionError("EXACTLY_TWO_REVIEWS_REQUIRED")
    snapshots = [
        _validate_review(root, candidate_path.parent, candidate, path)
        for path in reviews
    ]
    if {row[0]["review_id"] for row in snapshots} != set(TRUSTED_REVIEWERS):
        raise ProjectionError("REVIEWER_SET_INVALID")
    if len({row[1] for row in snapshots}) != 2:
        raise ProjectionError("REVIEW_FILE_IDENTITY_INVALID")
    bindings = _target_rows(candidate)
    authority = candidate["membership_authority"]
    seal = {
        "schema_version": SEAL_SCHEMA,
        "authorization_id": convergence.AUTHORIZATION_ID,
        "batch_id": BATCH_ID,
        "evaluated_head_sha": candidate["evaluated_head_sha"],
        "evaluated_tree_sha": candidate["evaluated_tree_sha"],
        "candidate_path": candidate_path.resolve().as_posix(),
        "candidate_file_sha256": candidate_file_sha,
        "candidate_payload_sha256": candidate["candidate_payload_sha256"],
        "membership_candidate_file_sha256": authority["candidate_file_sha256"],
        "membership_seal_file_sha256": authority["seal_file_sha256"],
        "review_receipts": [
            {
                "path": path.as_posix(),
                "sha256": file_sha,
                "review_id": review["review_id"],
            }
            for review, path, file_sha in sorted(
                snapshots, key=lambda item: str(item[0]["review_id"])
            )
        ],
        "source_registry_sha256": bindings[REGISTRY.as_posix()]["source_bytes_sha256"],
        "source_supersession_map_sha256": bindings[SUPERSESSION.as_posix()]["source_bytes_sha256"],
        "target_registry_sha256": bindings[REGISTRY.as_posix()]["target_bytes_sha256"],
        "target_supersession_map_sha256": bindings[SUPERSESSION.as_posix()]["target_bytes_sha256"],
        "mutation_inventory_sha256": candidate["mutation_inventory_sha256"],
        "review_status": "DUAL_REVIEW_PASS",
        "go_claim": True,
        "official_write_count": 0,
        "next_phase": NEXT_APPLY_PHASE,
    }
    seal["seal_payload_sha256"] = sha(canonical(seal))
    safe = shared._assert_output_safe(root, staging_root, output)
    shared._exclusive_write(safe, canonical(seal))
    return seal


def _validate_seal(
    root: Path,
    candidate_path: Path,
    seal_path: Path,
    *,
    require_worktree_parity: bool,
) -> tuple[dict[str, Any], dict[str, bytes]]:
    candidate, candidate_file_sha, targets = _validate_candidate_fresh(
        root, candidate_path, require_worktree_parity=require_worktree_parity
    )
    seal, raw, _resolved = _read_external(
        root, seal_path, candidate_path.parent, "PROJECTION_SEAL"
    )
    bindings = _target_rows(candidate)
    authority = candidate["membership_authority"]
    static = {
        "schema_version": SEAL_SCHEMA,
        "authorization_id": convergence.AUTHORIZATION_ID,
        "batch_id": BATCH_ID,
        "evaluated_head_sha": candidate["evaluated_head_sha"],
        "evaluated_tree_sha": candidate["evaluated_tree_sha"],
        "candidate_path": candidate_path.resolve().as_posix(),
        "candidate_file_sha256": candidate_file_sha,
        "candidate_payload_sha256": candidate["candidate_payload_sha256"],
        "membership_candidate_file_sha256": authority["candidate_file_sha256"],
        "membership_seal_file_sha256": authority["seal_file_sha256"],
        "source_registry_sha256": bindings[REGISTRY.as_posix()]["source_bytes_sha256"],
        "source_supersession_map_sha256": bindings[SUPERSESSION.as_posix()]["source_bytes_sha256"],
        "target_registry_sha256": bindings[REGISTRY.as_posix()]["target_bytes_sha256"],
        "target_supersession_map_sha256": bindings[SUPERSESSION.as_posix()]["target_bytes_sha256"],
        "mutation_inventory_sha256": candidate["mutation_inventory_sha256"],
        "review_status": "DUAL_REVIEW_PASS",
        "go_claim": True,
        "official_write_count": 0,
        "next_phase": NEXT_APPLY_PHASE,
    }
    if (
        set(seal) != SEAL_FIELDS
        or any(seal.get(key) != value for key, value in static.items())
        or not _payload_hash_valid(seal, "seal_payload_sha256")
    ):
        raise ProjectionError("SEAL_CONTRACT_INVALID")
    references = seal.get("review_receipts")
    if not isinstance(references, list) or len(references) != 2:
        raise ProjectionError("SEAL_REVIEW_REFS_INVALID")
    snapshots = []
    for reference in references:
        if not isinstance(reference, dict) or set(reference) != {
            "path",
            "sha256",
            "review_id",
        }:
            raise ProjectionError("SEAL_REVIEW_REF_INVALID")
        snapshot = _validate_review(
            root, candidate_path.parent, candidate, Path(reference["path"])
        )
        if (
            reference["sha256"] != snapshot[2]
            or reference["review_id"] != snapshot[0]["review_id"]
        ):
            raise ProjectionError("SEAL_REVIEW_REF_DRIFT")
        snapshots.append(snapshot)
    if {row[0]["review_id"] for row in snapshots} != set(TRUSTED_REVIEWERS):
        raise ProjectionError("SEAL_REVIEWER_SET_INVALID")
    if sha(raw) == candidate_file_sha:
        raise ProjectionError("SEAL_CANDIDATE_FILE_ALIAS")
    return seal, targets


def preflight_apply(
    root: Path, candidate_path: Path, seal_path: Path
) -> dict[str, Any]:
    root = root.resolve()
    seal, _targets = _validate_seal(
        root, candidate_path, seal_path, require_worktree_parity=True
    )
    return {
        "status": "PASS",
        "batch_id": BATCH_ID,
        "evaluated_head_sha": seal["evaluated_head_sha"],
        "evaluated_tree_sha": seal["evaluated_tree_sha"],
        "target_file_count": 2,
        "official_write_count": 0,
        "preflight_status": "EXACT_TWO_FILE_SOURCE_STATE_VERIFIED",
    }


def apply_projection(
    root: Path, candidate_path: Path, seal_path: Path
) -> dict[str, Any]:
    root = root.resolve()
    preflight_apply(root, candidate_path, seal_path)
    seal, targets = _validate_seal(
        root, candidate_path, seal_path, require_worktree_parity=True
    )
    for rendered in OUTPUT_ALLOWLIST:
        path = shared._require_plain_repo_file(root, Path(rendered))
        path.write_bytes(targets[rendered])
    return verify_applied(root, candidate_path, seal_path) | {
        "apply_status": "EXACT_TWO_FILE_TRANSACTION_APPLIED",
        "seal_payload_sha256": seal["seal_payload_sha256"],
    }


def verify_applied(
    root: Path, candidate_path: Path, seal_path: Path
) -> dict[str, Any]:
    root = root.resolve()
    seal, targets = _validate_seal(
        root, candidate_path, seal_path, require_worktree_parity=False
    )
    mismatches = [
        rendered
        for rendered, expected in targets.items()
        if shared._require_plain_repo_file(root, Path(rendered)).read_bytes() != expected
    ]
    if mismatches:
        raise ProjectionError("TARGET_NOT_APPLIED:" + ",".join(mismatches))
    return {
        "status": "PASS",
        "batch_id": BATCH_ID,
        "evaluated_head_sha": seal["evaluated_head_sha"],
        "evaluated_tree_sha": seal["evaluated_tree_sha"],
        "verified_file_count": 2,
        "verification_status": "EXACT_TWO_FILE_TARGET_STATE_VERIFIED",
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path.cwd())
    parser.add_argument("--head-ref", default="HEAD")
    sub = parser.add_subparsers(dest="command", required=True)
    build = sub.add_parser("build-candidate")
    build.add_argument("--membership-stage", type=Path, required=True)
    build.add_argument("--staging-root", type=Path, required=True)
    build.add_argument("--output", type=Path, required=True)
    review = sub.add_parser("build-review")
    review.add_argument("--candidate", type=Path, required=True)
    review.add_argument("--review-id", choices=sorted(TRUSTED_REVIEWERS), required=True)
    review.add_argument("--output", type=Path, required=True)
    seal = sub.add_parser("seal")
    seal.add_argument("--candidate", type=Path, required=True)
    seal.add_argument("--review", type=Path, action="append", required=True)
    seal.add_argument("--staging-root", type=Path, required=True)
    seal.add_argument("--output", type=Path, required=True)
    for name in ("preflight-apply", "apply", "verify-applied"):
        command = sub.add_parser(name)
        command.add_argument("--candidate", type=Path, required=True)
        command.add_argument("--seal", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == "build-candidate":
            result = build_candidate(
                args.project,
                args.membership_stage,
                args.staging_root,
                args.output,
                args.head_ref,
            )
        elif args.command == "build-review":
            result = build_review(
                args.project, args.candidate, args.review_id, args.output
            )
        elif args.command == "seal":
            result = seal_candidate(
                args.project,
                args.candidate,
                args.review,
                args.staging_root,
                args.output,
            )
        elif args.command == "preflight-apply":
            result = preflight_apply(args.project, args.candidate, args.seal)
        elif args.command == "apply":
            result = apply_projection(args.project, args.candidate, args.seal)
        elif args.command == "verify-applied":
            result = verify_applied(args.project, args.candidate, args.seal)
        else:
            raise ProjectionError("COMMAND_UNREACHABLE")
    except (ProjectionError, materializer.MaterializerError, shared.BuilderError) as exc:
        print(json.dumps({"status": "FAIL", "failure": str(exc)}, sort_keys=True))
        return 1
    print(json.dumps({"status": "PASS", "result": result}, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
