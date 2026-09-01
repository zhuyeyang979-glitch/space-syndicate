"""Deterministic, append-only planner for V076 full-convergence batches 008-013.

This tool deliberately separates membership planning from authoritative batch
sealing.  ``build-candidate`` writes one non-authoritative review package; it
never writes below the production batch or record roots and never claims GO.
``seal`` accepts that package only after two distinct, exact-byte-bound review
receipts pass.  The authority phase then projects exactly two target files,
binds a second pair of reviews, and exposes zero-write preflight plus exact-byte
post-apply verification.  It intentionally does not mutate Registry or Map:
the task's single writer applies one reviewed two-file patch between those two
checks.  No cross-file OS-atomic or crash-safe transaction claim is made.
"""

from __future__ import annotations

import argparse
import base64
import copy
import json
import os
import re
import stat
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
REGISTRY = Path("docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json")
SUPERSESSION_MAP = Path("docs/architecture/V076_SUPERSESSION_MAP.json")

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
AUTHORITY_CANDIDATE_SCHEMA = (
    "space_syndicate.v076.reuse_full_convergence.registry_mutation_candidate.v1"
)
AUTHORITY_REVIEW_SCHEMA = (
    "space_syndicate.v076.reuse_full_convergence.registry_mutation_review_receipt.v1"
)
AUTHORITY_SEAL_SCHEMA = (
    "space_syndicate.v076.reuse_full_convergence.registry_mutation_candidate_seal.v1"
)
AUTHORITY_CANDIDATE_KIND = "NON_AUTHORITATIVE_REGISTRY_MUTATION_REVIEW_INPUT"
AUTHORITY_CANDIDATE_NEXT_PHASE = "OBTAIN_TWO_DISTINCT_EXACT_TARGET_REVIEWS_AND_SEAL"
AUTHORITY_SEAL_NEXT_PHASE = "PREFLIGHT_AND_APPLY_EXACT_TWO_FILE_TRANSACTION"
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
SEALED_FIELDS = {
    "schema_version", "authorization_id", "batch_id", "evaluated_head_sha",
    "candidate_path", "candidate_payload_sha256", "review_receipts",
    "review_status", "go_claim", "official_batch_write_count",
    "official_record_write_count", "next_builder_phase", "seal_payload_sha256",
}
MEMBERSHIP_AUTHORITY_FIELDS = {
    "candidate_path", "candidate_file_sha256", "candidate_payload_sha256",
    "seal_path", "seal_file_sha256", "seal_payload_sha256",
    "primary_review_file_sha256", "independent_review_file_sha256",
}
AUTHORITY_TARGET_FIELDS = {
    "path", "source_blob_oid", "source_bytes_sha256", "source_byte_count",
    "target_encoding", "target_bytes_base64", "target_bytes_sha256",
    "target_byte_count",
}
MUTATION_FIELDS = {
    "target_path", "operation", "locator", "before_exists",
    "before_canonical_sha256", "after_canonical_sha256",
}
AUTHORITY_CANDIDATE_FIELDS = {
    "schema_version", "candidate_kind", "authorization_id", "batch_id",
    "evaluated_head_sha", "evaluated_tree_sha", "membership_authority",
    "target_files", "mutation_inventory", "mutation_inventory_sha256",
    "required_review_ids", "review_status", "go_claim", "official_write_count",
    "next_builder_phase", "candidate_payload_sha256",
}
AUTHORITY_REVIEW_FIELDS = {
    "schema_version", "review_id", "reviewer_authority_id",
    "candidate_payload_sha256", "batch_id", "evaluated_head_sha",
    "evaluated_tree_sha", "membership_candidate_file_sha256",
    "membership_seal_file_sha256", "source_registry_sha256",
    "source_supersession_map_sha256", "target_registry_sha256",
    "target_supersession_map_sha256", "mutation_inventory_sha256", "status",
    "p0_count", "p1_count", "findings", "receipt_payload_sha256",
}
AUTHORITY_SEAL_FIELDS = {
    "schema_version", "authorization_id", "batch_id", "evaluated_head_sha",
    "evaluated_tree_sha", "candidate_path", "candidate_file_sha256",
    "candidate_payload_sha256", "membership_candidate_file_sha256",
    "membership_seal_file_sha256", "review_receipts", "source_registry_sha256",
    "source_supersession_map_sha256", "target_registry_sha256",
    "target_supersession_map_sha256", "mutation_inventory_sha256",
    "review_status", "go_claim", "official_write_count", "next_builder_phase",
    "seal_payload_sha256",
}
TRUSTED_REVIEWER_AUTHORITIES = {
    "PRIMARY": "V076_FULL_CONVERGENCE_PRIMARY_REVIEWER_V1",
    "INDEPENDENT": "V076_FULL_CONVERGENCE_INDEPENDENT_REVIEWER_V1",
}
ALPHA01_BACKFILL_PROJECTION_SHA256 = (
    "013dcee9935eb56a98797140d7c12ee71eb7b87b3f786e93635c0a067b9219d0"
)
PLAYER_MANA_BACKFILL_PROJECTION_SHA256 = (
    "8d555552f540c8eda48bbe91da4485161a02af863ea4ce952ec1ddb36b1dfdf9"
)
V07_ASSET_ROW_AFTER_SHA256 = (
    "8a76105787ec22b423bd04e0468d776fbbc5611d485b907d5097385cb8f9d7d7"
)
PLAYER_MANA_SUPERSESSION_COMPACT_SHA256 = (
    "efe2a913f9a1c25e9d9820411bf4d2d7166a66ed63a50a496500f85b4307b5b9"
)
HISTORICAL_OWNER_TO_REDUCER_KIND = (
    "HISTORICAL_IDENTITY_BACKFILL_OWNER_TO_CURRENT_REDUCER"
)
ALPHA01_REGISTRY_ROW_BEFORE_SHA256 = (
    "14356a9dd5706b1ca5fecdcc3bef5d095de582bcdb70ae21590cba91e7b6cf97"
)
BATCH008_SOURCE_COMMIT = "e584cd4d8b0cd8afca7ff508cffcb05d1ba801a3"
BATCH008_ALPHA01_HISTORICAL_PATH = (
    "resources/content/alpha01/alpha01_content_manifest.gd"
)
BATCH008_PLAYER_MANA_HISTORICAL_PATH = (
    "scripts/runtime/player_mana_runtime_controller.gd"
)
BATCH008_CUTOVER_COMMIT = "f49c86af20b6a65e9792aa87703154e853d4dc76"
BATCH008_CUTOVER_MANIFEST = Path("docs/migration/v07_atomic_cutover_manifest.json")
BATCH008_CUTOVER_MANIFEST_SHA256 = (
    "9562593e7173d4d6437992916f64562107593e539833ca27b64d6ff4bc0ac52d"
)
COMPONENT_ROW_FIELDS = {
    "component_id", "class_name", "path", "domain_id", "component_role",
    "production_reachable", "writes_authority", "reads_authority", "owns_rng",
    "owns_tick", "owns_save", "owns_replay", "owns_identity",
    "owns_presentation", "owner_component_id", "owner_path",
    "reuse_disposition", "reuse_source_ids", "reuse_candidates_considered",
    "new_component_justification", "supersedes", "superseded_by",
    "change_class", "focused_test_ids", "golden_scenario_steps",
}

# Exact Batch-008 classification.  The tuple fields are:
# path, component_id, class_name, component_role, production_reachable,
# focused_test_ids.  Forty-five rows are detached historical TEST_SUPPORT.
# ProductIndustryCatalogResource and the CardFace scene/script are the three new
# production-reachable consumers; none of these rows owns gameplay or
# presentation state.  Focused tests are explicit authority, not a mutable grep
# heuristic.
BATCH008_COMPONENT_SPECS = (
    ("resources/ai/personalities/disruptor_ai_policy.tres", "component.current.disruptor_ai_policy_resource_instance", "DisruptorAiPolicyResourceInstance", "TEST_SUPPORT", False, ("ai_business_cost_architecture_gate_test", "layout_scene_smoke_test")),
    ("resources/ai/personalities/monster_tamer_ai_policy.tres", "component.current.monster_tamer_ai_policy_resource_instance", "MonsterTamerAiPolicyResourceInstance", "TEST_SUPPORT", False, ("ai_business_cost_architecture_gate_test", "layout_scene_smoke_test")),
    ("resources/monsters/monster_family_weather_traits_v1.tres", "component.current.monster_family_weather_traits_v1_resource_instance", "MonsterFamilyWeatherTraitsV1ResourceInstance", "TEST_SUPPORT", False, ("monster_weather_integration_v1_test",)),
    ("resources/rules/space_syndicate_ruleset_v06.tres", "component.current.space_syndicate_ruleset_v06_resource_instance", "SpaceSyndicateRulesetProfileV06ResourceInstance", "TEST_SUPPORT", False, ("card_core_effect_adapters_v06_test", "card_player_state_production_adapter_v06_test")),
    ("scenes/ui/CardFace.tscn", "component.current.card_face_scene", "SpaceSyndicateCardFaceScene", "PRESENTATION", True, ("alpha04_commodity_art_coverage_test", "visual_snapshot")),
    ("scenes/ui/DistrictSupplyPreviewCard.tscn", "component.current.district_supply_preview_card_scene", "SpaceSyndicateDistrictSupplyPreviewCardScene", "TEST_SUPPORT", False, ("layout_scene_smoke_test",)),
    ("scenes/ui/DistrictSupplyStatusChip.tscn", "component.current.district_supply_status_chip_scene", "SpaceSyndicateDistrictSupplyStatusChipScene", "TEST_SUPPORT", False, ("layout_scene_smoke_test",)),
    ("scripts/balance/development_route_catalog_resource.gd", "component.current.development_route_catalog_resource", "DevelopmentRouteCatalogResource", "TEST_SUPPORT", False, ("runtime_balance_report_test", "main_runtime_composition_test")),
    ("scripts/content/product_industry_catalog_resource.gd", "component.current.product_industry_catalog_resource", "ProductIndustryCatalogResource", "PORT", True, ("full_run_facility_acquisition_policy_test", "weather_product_classification_tags_test")),
    ("scripts/finance/city_gdp_derivative_terms_catalog_resource.gd", "component.current.city_gdp_derivative_terms_catalog_resource", "CityGdpDerivativeTermsCatalogResource", "TEST_SUPPORT", False, ("layout_scene_smoke_test",)),
    ("scripts/presentation/context_detail_projection_v1.gd", "component.current.context_detail_projection_v1", "ContextDetailProjectionV1", "TEST_SUPPORT", False, ("alpha04_player_card_dock_invariants_test", "alpha04b_contextual_surface_contract_test")),
    ("scripts/presentation/current_action_context_projection_v1.gd", "component.current.current_action_context_projection_v1", "CurrentActionContextProjectionV1", "TEST_SUPPORT", False, ("alpha04_player_card_dock_invariants_test", "alpha04_player_card_dock_production_cutover_test")),
    ("scripts/presentation/local_viewer_authorization.gd", "component.current.local_viewer_authorization", "LocalViewerAuthorization", "TEST_SUPPORT", False, ("card_target_choice_response_cutover_test", "district_product_hand_selection_cutover_test")),
    ("scripts/presentation/public_facility_target_candidates_snapshot.gd", "component.current.public_facility_target_candidates_snapshot", "PublicFacilityTargetCandidatesSnapshot", "TEST_SUPPORT", False, ("full_run_facility_acquisition_policy_test", "alpha04_claim_to_sale_integration_test")),
    ("scripts/presentation/public_feedback_projection_v1.gd", "component.current.public_feedback_projection_v1", "PublicFeedbackProjectionV1", "TEST_SUPPORT", False, ("alpha04b_contextual_surface_contract_test", "alpha04b_presentation_shell_schema_contract_test")),
    ("scripts/presentation/table_live_presentation_snapshot.gd", "component.current.table_live_presentation_snapshot", "TableLivePresentationSnapshot", "TEST_SUPPORT", False, ("district_supply_surface_query_cutover_test",)),
    ("scripts/presentation/viewer_private_feedback_owner.gd", "component.current.viewer_private_feedback_owner", "ViewerPrivateFeedbackOwner", "TEST_SUPPORT", False, ("table_presentation_query_ports_cutover_test",)),
    ("scripts/presentation/world_session_presentation_query.gd", "component.current.world_session_presentation_query", "WorldSessionPresentationQuery", "TEST_SUPPORT", False, ("standings_application_flow_cutover_test", "world_session_geometry_owner_cutover_test")),
    ("scripts/runtime/alpha01_runtime_content_selection.gd", "component.current.alpha01_runtime_content_selection", "Alpha01RuntimeContentSelection", "TEST_SUPPORT", False, ("alpha01_manifest_runtime_activation_test",)),
    ("scripts/runtime/card_inventory_runtime_service.gd", "component.current.card_inventory_runtime_service", "CardInventoryRuntimeService", "TEST_SUPPORT", False, ("ai_actor_economy_facts_typed_port_migration_test", "ai_actor_hand_inventory_typed_port_migration_test")),
    ("scripts/runtime/card_market_policy_world_bridge.gd", "component.current.card_market_policy_world_bridge", "CardMarketPolicyWorldBridge", "TEST_SUPPORT", False, ("planet_solar_camera_presentation_test", "world_session_state_cutover_test")),
    ("scripts/runtime/card_market_pricing_runtime_controller.gd", "component.current.card_market_pricing_runtime_controller", "CardMarketPricingRuntimeController", "TEST_SUPPORT", False, ("card_market_public_quote_player_privacy_test", "district_supply_surface_query_cutover_test")),
    ("scripts/runtime/card_presentation_runtime_service.gd", "component.current.card_presentation_runtime_service", "CardPresentationRuntimeService", "TEST_SUPPORT", False, ("alpha01_card_illustration_production_cutover_test", "alpha04_commodity_art_coverage_test")),
    ("scripts/runtime/card_resolution_stable_target_envelope.gd", "component.current.card_resolution_stable_target_envelope", "CardResolutionStableTargetEnvelope", "TEST_SUPPORT", False, ("card_resolution_product_market_target_envelope_test", "card_resolution_stable_target_envelope_test")),
    ("scripts/runtime/card_runtime_definition_world_bridge.gd", "component.current.card_runtime_definition_world_bridge", "CardRuntimeDefinitionWorldBridge", "TEST_SUPPORT", False, ("ai_actor_hand_inventory_typed_port_migration_test", "layout_scene_smoke_test")),
    ("scripts/runtime/card_target_choice_response_receipt.gd", "component.current.card_target_choice_response_receipt", "CardTargetChoiceResponseReceipt", "TEST_SUPPORT", False, ("card_target_choice_response_cutover_test",)),
    ("scripts/runtime/card_target_choice_response_sink.gd", "component.current.card_target_choice_response_sink", "CardTargetChoiceResponseSink", "TEST_SUPPORT", False, ("card_resolution_stable_target_envelope_test", "card_target_choice_response_cutover_test")),
    ("scripts/runtime/commodity_sushi_track_runtime_service.gd", "component.current.commodity_sushi_track_runtime_service", "CommoditySushiTrackRuntimeService", "TEST_SUPPORT", False, ("alpha04_claim_to_sale_integration_test", "alpha04_player_card_dock_invariants_test")),
    ("scripts/runtime/forced_decision_candidate_sources.gd", "component.current.forced_decision_candidate_sources", "ForcedDecisionCandidateSources", "TEST_SUPPORT", False, ("forced_decision_candidate_sources_cutover_test", "typed_world_ports_boundary_test")),
    ("scripts/runtime/military_monster_damage_command_sink.gd", "component.current.military_monster_damage_command_sink", "MilitaryMonsterDamageCommandSink", "TEST_SUPPORT", False, ("simulation_runtime_authority_migration_test",)),
    ("scripts/runtime/military_runtime_world_bridge.gd", "component.current.military_runtime_world_bridge", "MilitaryRuntimeWorldBridge", "TEST_SUPPORT", False, ("layout_scene_smoke_test", "main_runtime_composition_test")),
    ("scripts/runtime/monster_wager_cash_commitment_query_port.gd", "component.current.monster_wager_cash_commitment_query_port", "MonsterWagerCashCommitmentQueryPort", "TEST_SUPPORT", False, ("ai_actor_economy_facts_typed_port_migration_test", "ai_business_cost_formal_four_player_test")),
    ("scripts/runtime/player_identity_action_request.gd", "component.current.player_identity_action_request", "PlayerIdentityActionRequest", "TEST_SUPPORT", False, ("alpha04b_table_selection_source_surface_contract_test", "player_identity_authorization_boundary_test")),
    ("scripts/runtime/player_organization_runtime_controller.gd", "component.current.player_organization_runtime_controller", "PlayerOrganizationRuntimeController", "TEST_SUPPORT", False, ("organization_card_privacy_v06_test", "organization_card_runtime_v06_test")),
    ("scripts/runtime/runtime_card_port.gd", "component.current.runtime_card_port", "RuntimeCardPort", "TEST_SUPPORT", False, ("runtime_loop_cutover_test", "typed_world_ports_boundary_test")),
    ("scripts/runtime/runtime_monster_port.gd", "component.current.runtime_monster_port", "RuntimeMonsterPort", "TEST_SUPPORT", False, ("runtime_loop_cutover_test", "typed_world_ports_boundary_test")),
    ("scripts/runtime/runtime_phase_coordinator.gd", "component.current.runtime_phase_coordinator", "RuntimePhaseCoordinator", "TEST_SUPPORT", False, ("ai_business_cost_formal_four_player_test", "full_run_authoritative_runtime_stepper_test")),
    ("scripts/runtime/runtime_presentation_schedule_coordinator.gd", "component.current.runtime_presentation_schedule_coordinator", "RuntimePresentationScheduleCoordinator", "TEST_SUPPORT", False, ("runtime_coordination_phase_decomposition_test", "runtime_loop_cutover_test")),
    ("scripts/runtime/table_selection_intent_port.gd", "component.current.table_selection_intent_port", "TableSelectionIntentPort", "TEST_SUPPORT", False, ("district_product_hand_selection_cutover_test", "main_runtime_composition_test")),
    ("scripts/runtime/table_selection_receipt.gd", "component.current.table_selection_receipt", "TableSelectionReceipt", "TEST_SUPPORT", False, ("player_card_dock_target_mode_game_screen_integration_test", "public_card_track_focus_selection_cutover_test")),
    ("scripts/runtime/weather_runtime_world_bridge.gd", "component.current.weather_runtime_world_bridge", "WeatherRuntimeWorldBridge", "TEST_SUPPORT", False, ("layout_scene_smoke_test", "main_runtime_composition_test")),
    ("scripts/semantic/game_action_receipt_v1.gd", "component.current.game_action_receipt_v1", "GameActionReceiptV1", "TEST_SUPPORT", False, ("action_result_v1_test", "full_run_facility_acquisition_policy_test")),
    ("scripts/ui/card_face.gd", "component.current.card_face", "SpaceSyndicateCardFace", "PRESENTATION", True, ("alpha04_commodity_art_coverage_test", "visual_snapshot")),
    ("scripts/ui/map/planet_map_control_toolbar.gd", "component.current.planet_map_control_toolbar", "PlanetMapControlToolbar", "TEST_SUPPORT", False, ("layout_scene_smoke_test", "main_runtime_composition_test")),
    ("scripts/ui/player_board.gd", "component.current.player_board", "SpaceSyndicatePlayerBoard", "TEST_SUPPORT", False, ("alpha04_player_card_dock_invariants_test", "alpha04_player_card_dock_production_cutover_test")),
    ("scripts/ui/table/card_dock_action_feedback.gd", "component.current.card_dock_action_feedback", "SpaceSyndicateCardDockActionFeedback", "TEST_SUPPORT", False, ("alpha04_player_card_dock_invariants_test",)),
    ("scripts/ui/table/player_card_dock.gd", "component.current.player_card_dock", "SpaceSyndicatePlayerCardDock", "TEST_SUPPORT", False, ("alpha04_player_card_dock_invariants_test", "alpha04_player_card_dock_production_cutover_test")),
    ("scripts/viewmodels/bid_board_snapshot.gd", "component.current.bid_board_snapshot", "BidBoardSnapshot", "TEST_SUPPORT", False, ("layout_scene_smoke_test",)),
)


class BuilderError(ValueError):
    pass


def canonical(value: Any) -> bytes:
    return convergence.canonical_bytes(value)


def compact_canonical(value: Any) -> bytes:
    return json.dumps(
        value, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")


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


def strict_json_bytes(payload: bytes, label: str) -> dict[str, Any]:
    if payload.startswith(b"\xef\xbb\xbf"):
        raise BuilderError(f"JSON_BOM_FORBIDDEN:{label}")
    try:
        value = json.loads(
            payload.decode("utf-8"),
            object_pairs_hook=convergence._strict_object,
        )
    except Exception as exc:
        raise BuilderError(f"JSON_BYTES_INVALID:{label}") from exc
    if not isinstance(value, dict):
        raise BuilderError(f"JSON_BYTES_NOT_OBJECT:{label}")
    return value


def _exact_sha256(value: Any) -> bool:
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{64}", value) is not None


def _exact_commit(value: Any) -> bool:
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{40}", value) is not None


def _exact_nonnegative_int(value: Any) -> bool:
    return type(value) is int and value >= 0


def _payload_hash_valid(value: dict[str, Any], field: str) -> bool:
    claimed = value.get(field)
    payload = dict(value)
    payload.pop(field, None)
    return _exact_sha256(claimed) and claimed == sha(canonical(payload))


def _git_blob_oid(root: Path, head: str, relative: Path) -> str:
    oid = git(root, "rev-parse", f"{head}:{relative.as_posix()}")
    if not _exact_commit(oid):
        raise BuilderError(f"AUTHORITY_BLOB_OID_INVALID:{relative.as_posix()}")
    return oid


def _require_plain_repo_file(root: Path, relative: Path) -> Path:
    if relative.is_absolute() or ".." in relative.parts:
        raise BuilderError(f"AUTHORITY_PATH_INVALID:{relative.as_posix()}")
    project = root.resolve()
    path = project / relative
    _reject_reparse_chain(path.parent, "AUTHORITY_TARGET_PARENT")
    _reject_reparse_chain(path, "AUTHORITY_TARGET")
    try:
        path.resolve(strict=True).relative_to(project)
    except ValueError as exc:
        raise BuilderError(f"AUTHORITY_PATH_ESCAPES_PROJECT:{relative.as_posix()}") from exc
    except OSError as exc:
        raise BuilderError(f"AUTHORITY_NOT_PLAIN_FILE:{relative.as_posix()}") from exc
    try:
        info = os.stat(path, follow_symlinks=False)
    except OSError as exc:
        raise BuilderError(f"AUTHORITY_NOT_PLAIN_FILE:{relative.as_posix()}") from exc
    if not stat.S_ISREG(info.st_mode):
        raise BuilderError(f"AUTHORITY_NOT_PLAIN_FILE:{relative.as_posix()}")
    if int(getattr(info, "st_nlink", 1)) != 1:
        raise BuilderError(f"AUTHORITY_TARGET_HARDLINK_FORBIDDEN:{relative.as_posix()}")
    return path


def _committed_bytes(root: Path, head: str, relative: Path) -> bytes:
    if not _exact_commit(head):
        raise BuilderError("AUTHORITY_HEAD_INVALID")
    if relative.is_absolute() or ".." in relative.parts:
        raise BuilderError(f"AUTHORITY_PATH_INVALID:{relative.as_posix()}")
    process = subprocess.run(
        ["git", "cat-file", "blob", "--", f"{head}:{relative.as_posix()}"],
        cwd=root,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
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


def _committed_reader(root: Path, head: str):
    """Return an immutable reader for files in one exact authorized commit."""
    if not _exact_commit(head):
        raise BuilderError("FROZEN_HEAD_INVALID")
    cache: dict[str, bytes] = {}

    def read(relative: Path) -> bytes:
        relative = Path(relative)
        if relative.is_absolute() or ".." in relative.parts:
            raise BuilderError(f"FROZEN_PATH_INVALID:{relative.as_posix()}")
        key = relative.as_posix()
        if key not in cache:
            cache[key] = _committed_bytes(root, head, relative)
        return cache[key]

    return read


def _verify_legacy_anchor_from_reader(read) -> dict[str, Any]:
    """Verify the frozen legacy chain without consulting live worktree files."""
    failures: list[str] = []
    previous = ""
    fingerprints: list[str] = []
    correction_ids: list[str] = []
    record_paths: list[str] = []
    for binding in convergence.LEGACY_RECORD_BINDINGS:
        relative = Path(str(binding["path"]))
        record_paths.append(relative.as_posix())
        try:
            payload = read(relative)
        except BuilderError:
            failures.append(f"LEGACY_RECORD_MISSING:{relative.as_posix()}")
            continue
        if sha(payload) != binding["sha256"]:
            failures.append(f"LEGACY_RECORD_BYTE_DRIFT:{relative.as_posix()}")
            continue
        try:
            record = strict_json_bytes(payload, relative.as_posix())
        except BuilderError:
            failures.append(f"LEGACY_RECORD_JSON_INVALID:{relative.as_posix()}")
            continue
        if record.get("authorization_id") != convergence.LEGACY_AUTHORIZATION_ID:
            failures.append(f"LEGACY_RECORD_AUTHORIZATION_DRIFT:{relative.as_posix()}")
        if record.get("authorized_head_sha") != convergence.LEGACY_AUTHORIZED_HEAD_SHA:
            failures.append(f"LEGACY_RECORD_HEAD_DRIFT:{relative.as_posix()}")
        if record.get("baseline_report_sha256") != convergence.LEGACY_BASELINE_REPORT_SHA256:
            failures.append(f"LEGACY_RECORD_BASELINE_DRIFT:{relative.as_posix()}")
        if record.get("previous_correction_chain_sha256", "") != previous:
            failures.append(f"LEGACY_RECORD_CHAIN_BREAK:{relative.as_posix()}")
        if record.get("record_payload_sha256") != binding["payload_sha256"]:
            failures.append(f"LEGACY_RECORD_PAYLOAD_DRIFT:{relative.as_posix()}")
        correction_id = str(record.get("correction_id", ""))
        if not correction_id:
            failures.append(f"LEGACY_RECORD_CORRECTION_ID_MISSING:{relative.as_posix()}")
        correction_ids.append(correction_id)
        previous = str(record.get("record_payload_sha256", ""))
        fingerprints.extend(str(value) for value in record.get("failure_fingerprints", []))
    if previous != convergence.LEGACY_RECORD_CHAIN_TERMINAL_SHA256:
        failures.append("LEGACY_RECORD_CHAIN_TERMINAL_MISMATCH")
    if len(fingerprints) != 12 or len(fingerprints) != len(set(fingerprints)):
        failures.append("LEGACY_RECORD_FINGERPRINT_SET_INVALID")
    if len(correction_ids) != len(set(correction_ids)):
        failures.append("LEGACY_RECORD_CORRECTION_ID_SET_INVALID")
    for relative, expected in (
        (convergence.LEGACY_SCHEMA_REL, convergence.LEGACY_SCHEMA_SHA256),
        (convergence.LEGACY_SEAL_MANIFEST_REL, convergence.LEGACY_SEAL_MANIFEST_SHA256),
        (convergence.LEGACY_SEAL_PLAN_REL, convergence.LEGACY_SEAL_PLAN_SHA256),
    ):
        try:
            payload = read(Path(relative))
        except BuilderError:
            failures.append(f"LEGACY_ANCHOR_BYTE_DRIFT:{relative.as_posix()}")
            continue
        if sha(payload) != expected:
            failures.append(f"LEGACY_ANCHOR_BYTE_DRIFT:{relative.as_posix()}")
    return {
        "status": "PASS" if not failures else "FAIL",
        "legacy_record_count": len(convergence.LEGACY_RECORD_BINDINGS),
        "legacy_corrected_fingerprint_count": len(fingerprints),
        "legacy_corrected_fingerprints": sorted(fingerprints),
        "legacy_correction_ids": sorted(correction_ids),
        "legacy_record_paths": sorted(record_paths),
        "legacy_record_chain_terminal_sha256": previous,
        "legacy_seal_manifest_sha256": convergence.LEGACY_SEAL_MANIFEST_SHA256,
        "failures": sorted(set(failures)),
    }


def _load_authority_from_committed_head(root: Path, head: str, read):
    payloads = {relative: read(relative) for relative in AUTHORITY_INPUTS}
    baseline = strict_json_bytes(payloads[BASELINE], BASELINE.as_posix())
    supplement = strict_json_bytes(payloads[SUPPLEMENT], SUPPLEMENT.as_posix())
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
    legacy_result = _verify_legacy_anchor_from_reader(read)
    if legacy_result.get("status") != "PASS":
        raise BuilderError("LEGACY_ANCHOR_NOT_PASS")
    legacy = {str(value) for value in legacy_result["legacy_corrected_fingerprints"]}
    if len(primary) != 501 or len(legacy) != 12 or primary & legacy != legacy:
        raise BuilderError("FROZEN_PARTITION_CARDINALITY_INVALID")
    if not primary.issubset(identities):
        raise BuilderError("PRIMARY_IDENTITY_COVERAGE_INCOMPLETE")
    return identities, primary, legacy, payloads


def _derive_plan_core(
    root: Path,
    head: str,
    identities: dict[str, dict[str, Any]],
    primary: set[str],
    legacy: set[str],
    read,
    *,
    parse_manifest,
) -> dict[str, Any]:
    consumed = set(legacy)
    manifests: dict[int, dict[str, Any]] = {}
    for batch in range(1, 8):
        relative = _batch_manifest(batch)
        manifest = parse_manifest(relative)
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
            relative.as_posix(): sha(read(relative))
            for relative in AUTHORITY_INPUTS
        },
    }
    result["plan_sha256"] = sha(canonical(result))
    return result


def derive_plan(root: Path, head_ref: str = "HEAD") -> dict[str, Any]:
    root = root.resolve()
    head = git(root, "rev-parse", f"{head_ref}^{{commit}}")
    if not convergence._is_ancestor(root, convergence.AUTHORIZATION_BASE_HEAD_SHA, head):
        raise BuilderError("HEAD_NOT_AUTHORIZED_DESCENDANT")
    identities, primary, legacy = _load_authority(root, head)
    def read(relative: Path) -> bytes:
        _require_committed_parity(root, head, relative)
        return (root / relative).read_bytes()
    return _derive_plan_core(
        root,
        head,
        identities,
        primary,
        legacy,
        read,
        parse_manifest=lambda relative: strict_json(root / relative),
    )


def derive_plan_from_committed_head(root: Path, head: str) -> dict[str, Any]:
    """Reconstruct a frozen plan exclusively from one exact commit's blobs."""
    root = root.resolve()
    if not _exact_commit(head):
        raise BuilderError("FROZEN_HEAD_INVALID")
    if not convergence._is_ancestor(root, convergence.AUTHORIZATION_BASE_HEAD_SHA, head):
        raise BuilderError("FROZEN_HEAD_NOT_AUTHORIZED_DESCENDANT")
    read = _committed_reader(root, head)
    identities, primary, legacy, payloads = _load_authority_from_committed_head(
        root, head, read
    )
    plan = _derive_plan_core(
        root,
        head,
        identities,
        primary,
        legacy,
        read,
        parse_manifest=lambda relative: strict_json_bytes(
            read(relative), relative.as_posix()
        ),
    )
    expected_authority = {
        relative.as_posix(): sha(payloads[relative])
        for relative in AUTHORITY_INPUTS
    }
    if plan["authority_inputs"] != expected_authority:
        raise BuilderError("FROZEN_AUTHORITY_INPUT_HASH_INVALID")
    return plan


def _lexical_absolute(path: Path, label: str) -> Path:
    if not path.is_absolute():
        raise BuilderError(f"{label}_PATH_NOT_ABSOLUTE")
    return Path(os.path.abspath(os.fspath(path)))


def _reject_reparse_chain(path: Path, label: str) -> None:
    lexical = _lexical_absolute(path, label)
    chain = list(reversed(lexical.parents)) + [lexical]
    reparse_flag = getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400)
    for entry in chain:
        if not os.path.lexists(entry):
            continue
        try:
            info = os.lstat(entry)
        except OSError as exc:
            raise BuilderError(f"{label}_LSTAT_FAILED:{entry.as_posix()}") from exc
        attributes = int(getattr(info, "st_file_attributes", 0))
        if stat.S_ISLNK(info.st_mode) or attributes & reparse_flag:
            raise BuilderError(f"{label}_REPARSE_FORBIDDEN:{entry.as_posix()}")


def _assert_external_stage(root: Path, staging_root: Path, label: str) -> Path:
    project = root.resolve()
    stage = _lexical_absolute(staging_root, label)
    _reject_reparse_chain(stage, label)
    resolved_stage = stage.resolve(strict=False)
    try:
        resolved_stage.relative_to(project)
    except ValueError:
        pass
    else:
        raise BuilderError("STAGING_ROOT_MUST_BE_OUTSIDE_PROJECT")
    return resolved_stage


def _assert_output_safe(root: Path, staging_root: Path, output: Path) -> Path:
    project = root.resolve()
    stage = _assert_external_stage(root, staging_root, "STAGING_ROOT")
    lexical_output = _lexical_absolute(output, "OUTPUT")
    _reject_reparse_chain(lexical_output.parent, "OUTPUT_PARENT")
    resolved = lexical_output.resolve(strict=False)
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
    if os.path.lexists(resolved):
        raise BuilderError("APPEND_ONLY_OUTPUT_ALREADY_EXISTS")
    resolved.parent.mkdir(parents=True, exist_ok=True)
    _reject_reparse_chain(stage, "STAGING_ROOT")
    _reject_reparse_chain(resolved.parent, "OUTPUT_PARENT")
    return resolved


def _exclusive_write(path: Path, payload: bytes) -> None:
    _reject_reparse_chain(path.parent, "OUTPUT_PARENT")
    try:
        with path.open("xb") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
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
    safe_output = _assert_output_safe(root.resolve(), staging_root, output)
    _exclusive_write(safe_output, canonical(candidate))
    return candidate


def _expected_membership_rows(
    root: Path,
    head: str,
    fingerprints: list[str],
) -> dict[str, Any]:
    identities, _, _ = _load_authority(root, head)
    rows: dict[str, Any] = {}
    for fp in fingerprints:
        identity = identities[fp]
        old, new = _transition(identity)
        rows[fp] = {
            "failure_fingerprint": fp,
            "raw_failure": str(identity.get("raw_failure", "")),
            "rule_id": str(identity.get("rule_id", "")),
            "transition_old_prefix": old,
            "transition_new_prefix": new,
            "subject_kind": str(identity.get("subject_kind", "")),
            "subject_value": str(
                identity.get("subject_value", identity.get("source_path", ""))
            ),
            "classification_status": "REQUIRES_EXACT_AUTHORITY_PROJECTION",
        }
    return rows


def expected_membership_rows_from_committed_head(
    root: Path,
    head: str,
    fingerprints: list[str],
) -> dict[str, Any]:
    """Build membership rows from the same immutable committed authority view."""
    root = root.resolve()
    plan = derive_plan_from_committed_head(root, head)
    planned = plan.get("batches", {}).get("batch-009", {})
    expected = planned.get("failure_fingerprints")
    if fingerprints != expected:
        raise BuilderError("FROZEN_MEMBERSHIP_FINGERPRINT_SET_INVALID")
    read = _committed_reader(root, head)
    baseline = strict_json_bytes(read(BASELINE), BASELINE.as_posix())
    supplement = strict_json_bytes(read(SUPPLEMENT), SUPPLEMENT.as_posix())
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
    rows: dict[str, Any] = {}
    for fp in fingerprints:
        if fp not in identities:
            raise BuilderError(f"FROZEN_MEMBERSHIP_IDENTITY_MISSING:{fp}")
        identity = identities[fp]
        old, new = _transition(identity)
        rows[fp] = {
            "failure_fingerprint": fp,
            "raw_failure": str(identity.get("raw_failure", "")),
            "rule_id": str(identity.get("rule_id", "")),
            "transition_old_prefix": old,
            "transition_new_prefix": new,
            "subject_kind": str(identity.get("subject_kind", "")),
            "subject_value": str(
                identity.get("subject_value", identity.get("source_path", ""))
            ),
            "classification_status": "REQUIRES_EXACT_AUTHORITY_PROJECTION",
        }
    return rows


def _validate_membership_candidate_fresh(
    root: Path,
    candidate_path: Path,
) -> tuple[dict[str, Any], str]:
    root = root.resolve()
    candidate_path = _require_external_plain_file(
        candidate_path,
        "MEMBERSHIP_CANDIDATE",
        root,
        candidate_path.parent,
    )
    raw = candidate_path.read_bytes()
    candidate = strict_json_bytes(raw, "MEMBERSHIP_CANDIDATE")
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
    if raw != canonical(candidate):
        raise BuilderError("CANDIDATE_BYTES_NOT_CANONICAL")
    if not _payload_hash_valid(candidate, "candidate_payload_sha256"):
        raise BuilderError("CANDIDATE_PAYLOAD_HASH_INVALID")
    fresh = derive_plan(root, "HEAD")
    batch_id = str(candidate.get("batch_id", ""))
    planned = fresh.get("batches", {}).get(batch_id)
    if not isinstance(planned, dict):
        raise BuilderError("CANDIDATE_BATCH_NOT_IN_FRESH_PLAN")
    expected_rows = _expected_membership_rows(
        root,
        fresh["evaluated_head_sha"],
        planned["failure_fingerprints"],
    )
    parity = {
        "evaluated_head_sha": fresh["evaluated_head_sha"], "plan_sha256": fresh["plan_sha256"],
        "failure_count": planned["failure_count"], "failure_fingerprints": planned["failure_fingerprints"],
        "failure_fingerprint_set_sha256": line_set_sha(planned["failure_fingerprints"]),
        "rows": expected_rows, "authority_inputs": fresh["authority_inputs"],
    }
    for field, expected in parity.items():
        if candidate.get(field) != expected:
            raise BuilderError(f"CANDIDATE_FRESH_PARITY_INVALID:{field}")
    return candidate, sha(raw)


def _validate_membership_review(
    candidate: dict[str, Any],
    path: Path,
    root: Path,
    staging_root: Path,
) -> tuple[dict[str, Any], Path, str]:
    path = _require_external_plain_file(
        path,
        "MEMBERSHIP_REVIEW",
        root,
        staging_root,
    )
    raw = path.read_bytes()
    review = strict_json_bytes(raw, f"MEMBERSHIP_REVIEW:{path.as_posix()}")
    if raw != canonical(review):
        raise BuilderError(f"REVIEW_BYTES_NOT_CANONICAL:{path.as_posix()}")
    if set(review) != REVIEW_FIELDS or review.get("schema_version") != REVIEW_SCHEMA:
        raise BuilderError(f"REVIEW_SCHEMA_INVALID:{path.as_posix()}")
    if not _payload_hash_valid(review, "receipt_payload_sha256"):
        raise BuilderError(f"REVIEW_PAYLOAD_HASH_INVALID:{path.as_posix()}")
    if (
        review.get("candidate_payload_sha256")
        != candidate.get("candidate_payload_sha256")
        or review.get("reviewer_authority_id")
        != TRUSTED_REVIEWER_AUTHORITIES.get(str(review.get("review_id", "")))
        or review.get("batch_id") != candidate.get("batch_id")
        or review.get("evaluated_head_sha") != candidate.get("evaluated_head_sha")
        or review.get("plan_sha256") != candidate.get("plan_sha256")
        or review.get("failure_fingerprint_set_sha256")
        != candidate.get("failure_fingerprint_set_sha256")
        or review.get("status") != "GO"
        or type(review.get("p0_count")) is not int
        or review.get("p0_count") != 0
        or type(review.get("p1_count")) is not int
        or review.get("p1_count") != 0
        or review.get("findings") != []
    ):
        raise BuilderError(f"REVIEW_NOT_ACCEPTABLE:{path.as_posix()}")
    return review, path, sha(raw)


def _validate_membership_review_set(
    candidate: dict[str, Any],
    receipts: list[Path],
    root: Path,
    staging_root: Path,
) -> list[tuple[dict[str, Any], Path, str]]:
    if len(receipts) != 2:
        raise BuilderError("EXACTLY_TWO_REVIEWS_REQUIRED")
    snapshots = [
        _validate_membership_review(candidate, path, root, staging_root)
        for path in receipts
    ]
    reviews = [snapshot[0] for snapshot in snapshots]
    ids = {str(review.get("review_id", "")) for review in reviews}
    if ids != {"PRIMARY", "INDEPENDENT"}:
        raise BuilderError("REVIEWER_SET_INVALID")
    authorities = {str(review.get("reviewer_authority_id", "")) for review in reviews}
    if authorities != set(TRUSTED_REVIEWER_AUTHORITIES.values()):
        raise BuilderError("REVIEWER_AUTHORITY_SET_INVALID")
    if len({snapshot[1] for snapshot in snapshots}) != 2:
        raise BuilderError("REVIEW_FILE_IDENTITY_SET_INVALID")
    return snapshots


def seal_candidate(root: Path, candidate_path: Path, receipts: list[Path], staging_root: Path, output: Path) -> dict[str, Any]:
    membership_stage = candidate_path.parent
    candidate, _ = _validate_membership_candidate_fresh(root, candidate_path)
    review_snapshots = _validate_membership_review_set(
        candidate,
        receipts,
        root.resolve(),
        membership_stage,
    )
    payload_hash = candidate["candidate_payload_sha256"]
    seal = {
        "schema_version": SEALED_SCHEMA,
        "authorization_id": convergence.AUTHORIZATION_ID,
        "batch_id": candidate["batch_id"],
        "evaluated_head_sha": candidate["evaluated_head_sha"],
        "candidate_path": candidate_path.as_posix(),
        "candidate_payload_sha256": payload_hash,
        "review_receipts": [
            {
                "path": path.as_posix(),
                "sha256": file_sha256,
                "review_id": review["review_id"],
            }
            for review, path, file_sha256 in sorted(
                review_snapshots,
                key=lambda item: str(item[0]["review_id"]),
            )
        ],
        "review_status": "DUAL_REVIEW_PASS",
        "go_claim": True,
        "official_batch_write_count": 0,
        "official_record_write_count": 0,
        "next_builder_phase": "MATERIALIZE_AND_RUN_EXISTING_PRIMARY_AND_INDEPENDENT_VALIDATORS",
    }
    seal["seal_payload_sha256"] = sha(canonical(seal))
    safe_output = _assert_output_safe(root.resolve(), staging_root, output)
    _exclusive_write(safe_output, canonical(seal))
    return seal


def _validate_membership_seal(
    root: Path,
    candidate_path: Path,
    seal_path: Path,
) -> dict[str, Any]:
    root = root.resolve()
    membership_stage = candidate_path.parent
    candidate, candidate_file_sha256 = _validate_membership_candidate_fresh(
        root, candidate_path
    )
    seal_path = _require_external_plain_file(
        seal_path,
        "MEMBERSHIP_SEAL",
        root,
        membership_stage,
    )
    raw = seal_path.read_bytes()
    seal = strict_json_bytes(raw, "MEMBERSHIP_SEAL")
    if raw != canonical(seal):
        raise BuilderError("MEMBERSHIP_SEAL_BYTES_NOT_CANONICAL")
    if (
        set(seal) != SEALED_FIELDS
        or seal.get("schema_version") != SEALED_SCHEMA
        or seal.get("authorization_id") != convergence.AUTHORIZATION_ID
        or seal.get("batch_id") != candidate.get("batch_id")
        or seal.get("evaluated_head_sha") != candidate.get("evaluated_head_sha")
        or seal.get("candidate_payload_sha256")
        != candidate.get("candidate_payload_sha256")
        or seal.get("review_status") != "DUAL_REVIEW_PASS"
        or seal.get("go_claim") is not True
        or type(seal.get("official_batch_write_count")) is not int
        or seal.get("official_batch_write_count") != 0
        or type(seal.get("official_record_write_count")) is not int
        or seal.get("official_record_write_count") != 0
        or seal.get("next_builder_phase")
        != "MATERIALIZE_AND_RUN_EXISTING_PRIMARY_AND_INDEPENDENT_VALIDATORS"
        or not _payload_hash_valid(seal, "seal_payload_sha256")
    ):
        raise BuilderError("MEMBERSHIP_SEAL_CONTRACT_INVALID")
    try:
        declared_candidate = Path(str(seal.get("candidate_path", ""))).resolve()
    except Exception as exc:
        raise BuilderError("MEMBERSHIP_SEAL_CANDIDATE_PATH_INVALID") from exc
    if declared_candidate != candidate_path.resolve():
        raise BuilderError("MEMBERSHIP_SEAL_CANDIDATE_PATH_MISMATCH")
    references = seal.get("review_receipts")
    if not isinstance(references, list) or len(references) != 2:
        raise BuilderError("MEMBERSHIP_SEAL_REVIEW_REFS_INVALID")
    if [reference.get("review_id") for reference in references if isinstance(reference, dict)] != [
        "INDEPENDENT", "PRIMARY"
    ]:
        raise BuilderError("MEMBERSHIP_SEAL_REVIEW_REF_ORDER_INVALID")
    review_paths: list[Path] = []
    declared_ids: set[str] = set()
    for reference in references:
        if not isinstance(reference, dict) or set(reference) != {
            "path", "sha256", "review_id"
        }:
            raise BuilderError("MEMBERSHIP_SEAL_REVIEW_REF_INVALID")
        path = _require_external_plain_file(
            Path(str(reference.get("path", ""))),
            "MEMBERSHIP_REVIEW",
            root,
            membership_stage,
        )
        if not _exact_sha256(reference.get("sha256")):
            raise BuilderError("MEMBERSHIP_SEAL_REVIEW_HASH_INVALID")
        review_paths.append(path)
        declared_ids.add(str(reference.get("review_id", "")))
    review_snapshots = _validate_membership_review_set(
        candidate,
        review_paths,
        root,
        membership_stage,
    )
    reviews = [snapshot[0] for snapshot in review_snapshots]
    for reference, snapshot in zip(references, review_snapshots):
        review, _, file_sha256 = snapshot
        if (
            reference["sha256"] != file_sha256
            or reference["review_id"] != review["review_id"]
        ):
            raise BuilderError("MEMBERSHIP_SEAL_REVIEW_HASH_INVALID")
    if declared_ids != {str(review["review_id"]) for review in reviews}:
        raise BuilderError("MEMBERSHIP_SEAL_REVIEW_ID_MISMATCH")
    review_file_sha256 = {
        str(review["review_id"]): file_sha256
        for review, _, file_sha256 in review_snapshots
    }
    return {
        "candidate": candidate,
        "candidate_file_sha256": candidate_file_sha256,
        "seal": seal,
        "seal_file_sha256": sha(raw),
        "review_file_sha256": review_file_sha256,
    }


def _require_authority_index_parity(root: Path, head: str, relative: Path) -> None:
    staged = subprocess.run(
        [
            "git", "diff", "--cached", "--quiet", "--exit-code",
            head, "--", relative.as_posix(),
        ],
        cwd=root,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if staged.returncode not in {0, 1}:
        raise BuilderError(f"AUTHORITY_INDEX_CHECK_FAILED:{relative.as_posix()}")
    if staged.returncode == 1:
        raise BuilderError(f"AUTHORITY_INDEX_DRIFT:{relative.as_posix()}")


def _load_registry_sources(
    root: Path,
    head: str,
    *,
    require_worktree_parity: bool = True,
) -> dict[str, dict[str, Any]]:
    root = root.resolve()
    result: dict[str, dict[str, Any]] = {}
    for relative in (REGISTRY, SUPERSESSION_MAP):
        path = _require_plain_repo_file(root, relative)
        payload = _committed_bytes(root, head, relative)
        if require_worktree_parity and path.read_bytes() != payload:
            raise BuilderError(f"AUTHORITY_WORKTREE_DRIFT:{relative.as_posix()}")
        _require_authority_index_parity(root, head, relative)
        parsed = strict_json_bytes(payload, relative.as_posix())
        result[relative.as_posix()] = {
            "path": path,
            "bytes": payload,
            "json": parsed,
            "source_blob_oid": _git_blob_oid(root, head, relative),
            "source_bytes_sha256": sha(payload),
            "source_byte_count": len(payload),
        }
    return result


def _git_grep_test_paths(
    root: Path,
    head: str,
    pattern: str,
) -> set[str]:
    process = subprocess.run(
        ["git", "grep", "-l", "-F", pattern, head, "--", "tests"],
        cwd=root,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if process.returncode not in {0, 1}:
        raise BuilderError(f"FOCUSED_TEST_SEARCH_FAILED:{pattern}")
    result: set[str] = set()
    for raw_line in process.stdout.decode("utf-8", errors="strict").splitlines():
        line = raw_line.split(":", 1)[1] if raw_line.startswith(f"{head}:") else raw_line
        if line.startswith("tests/") and line.endswith(".gd"):
            result.add(line)
    return result


def _focused_test_ids(
    root: Path,
    head: str,
    path: str,
    class_name: str,
) -> list[str]:
    paths = _git_grep_test_paths(root, head, path)
    if class_name:
        paths.update(_git_grep_test_paths(root, head, class_name))
    result = sorted({Path(value).stem for value in paths})
    if not result:
        raise BuilderError(f"BATCH008_FOCUSED_TESTS_EMPTY:{path}")
    return result


def _exact_batch008_component_rows(root: Path, head: str) -> list[dict[str, Any]]:
    if len(BATCH008_COMPONENT_SPECS) != 48:
        raise BuilderError("BATCH008_COMPONENT_SPEC_COUNT_INVALID")
    paths = [spec[0] for spec in BATCH008_COMPONENT_SPECS]
    component_ids = [spec[1] for spec in BATCH008_COMPONENT_SPECS]
    class_names = [spec[2] for spec in BATCH008_COMPONENT_SPECS]
    if any(len(values) != len(set(values)) for values in (paths, component_ids, class_names)):
        raise BuilderError("BATCH008_COMPONENT_SPEC_IDENTITY_COLLISION")

    rows: list[dict[str, Any]] = []
    for (
        path,
        component_id,
        class_name,
        role,
        production_reachable,
        focused_test_ids,
    ) in BATCH008_COMPONENT_SPECS:
        relative = Path(path)
        historical = _committed_bytes(root, BATCH008_SOURCE_COMMIT, relative)
        current = _require_committed_parity(root, head, relative)
        if historical != current:
            raise BuilderError(f"BATCH008_HISTORICAL_CURRENT_BLOB_DRIFT:{path}")
        if path.endswith(".gd"):
            match = re.search(
                rb"^\s*class_name\s+([A-Za-z_][A-Za-z0-9_]*)\b",
                current,
                flags=re.MULTILINE,
            )
            declared = match.group(1).decode("ascii") if match else ""
            if declared != class_name:
                raise BuilderError(f"BATCH008_CLASS_IDENTITY_DRIFT:{path}")
        if (
            not isinstance(focused_test_ids, tuple)
            or not focused_test_ids
            or len(focused_test_ids) != len(set(focused_test_ids))
        ):
            raise BuilderError(f"BATCH008_FOCUSED_TEST_CONTRACT_INVALID:{path}")
        for focused_test_id in focused_test_ids:
            if not isinstance(focused_test_id, str) or not focused_test_id:
                raise BuilderError(f"BATCH008_FOCUSED_TEST_CONTRACT_INVALID:{path}")
            _committed_bytes(root, head, Path("tests") / f"{focused_test_id}.gd")

        if role == "TEST_SUPPORT":
            reuse_ids = [
                "reuse.v06.fullrun_settlement_tests",
                "reuse.v075.combat_candidate",
            ]
            justification = (
                f"Historical {class_name} at {path} is retained only as a focused-test "
                "support surface after the V075 cutover. It is outside the active V075 "
                "authority/presentation composition and creates no gameplay, catalog, "
                "asset, topology, tick, RNG, save, replay, identity, or presentation Owner."
            )
            disposition = "REUSE_AS_TEST"
            change_class = "PRODUCTION_COMPOSITION"
            golden_steps: list[str] = []
        elif role == "PORT":
            reuse_ids = [
                "reuse.current.card_runtime_catalog_v06",
                "reuse.v075.combat_candidate",
            ]
            justification = (
                "Existing ProductIndustryCatalogResource remains the immutable "
                "product-definition input port transitively consumed by the current V075 "
                "runtime through the Alpha01 manifest. It owns no gameplay state, asset "
                "quantity, topology, tick, RNG, save, replay, identity, or presentation "
                "authority."
            )
            disposition = "ADAPT_AS_CONSUMER"
            change_class = "PRODUCTION_COMPOSITION"
            golden_steps = ["STEP06", "STEP08"]
        elif role == "PRESENTATION":
            reuse_ids = [
                "reuse.current.card_runtime_catalog",
                "reuse.v075.combat_candidate",
            ]
            justification = (
                f"Existing {class_name} is the CardFace presentation consumer used by "
                "the current V075 interactive card surface. It consumes catalog-owned "
                "definitions and emits presentation/typed interaction signals only; it "
                "owns no card, hand, gameplay, exact-once, asset, topology, tick, RNG, "
                "save, replay, identity, or presentation authority."
            )
            disposition = "ADAPT_AS_CONSUMER"
            change_class = "PRODUCTION_COMPOSITION"
            golden_steps = ["STEP06", "STEP07"]
        else:
            raise BuilderError(f"BATCH008_COMPONENT_ROLE_INVALID:{path}")

        row = {
            "component_id": component_id,
            "class_name": class_name,
            "path": path,
            "domain_id": "current.v075_production_combat_candidate",
            "component_role": role,
            "production_reachable": production_reachable,
            "writes_authority": False,
            "reads_authority": True,
            "owns_rng": False,
            "owns_tick": False,
            "owns_save": False,
            "owns_replay": False,
            "owns_identity": False,
            "owns_presentation": False,
            "owner_component_id": "component.current.v075_runtime_owner",
            "owner_path": "scripts/v075_runtime/v075_runtime_owner.gd",
            "reuse_disposition": disposition,
            "reuse_source_ids": reuse_ids,
            "reuse_candidates_considered": reuse_ids,
            "new_component_justification": justification,
            "supersedes": [],
            "superseded_by": [],
            "change_class": change_class,
            "focused_test_ids": list(focused_test_ids),
            "golden_scenario_steps": golden_steps,
        }
        if set(row) != COMPONENT_ROW_FIELDS:
            raise BuilderError(f"BATCH008_COMPONENT_ROW_SCHEMA_INVALID:{path}")
        rows.append(row)

    role_counts = {
        role: sum(row["component_role"] == role for row in rows)
        for role in {"TEST_SUPPORT", "PORT", "PRESENTATION"}
    }
    if role_counts != {"TEST_SUPPORT": 45, "PORT": 1, "PRESENTATION": 2}:
        raise BuilderError("BATCH008_COMPONENT_ROLE_COUNTS_INVALID")
    if sum(row["production_reachable"] is True for row in rows) != 3:
        raise BuilderError("BATCH008_COMPONENT_REACHABILITY_COUNT_INVALID")
    return rows


def _validate_batch008_membership_projection(
    membership_candidate: dict[str, Any],
) -> None:
    if (
        membership_candidate.get("batch_id") != "batch-008"
        or membership_candidate.get("failure_count") != 50
    ):
        raise BuilderError("AUTHORITY_MEMBERSHIP_BATCH008_CONTRACT_INVALID")
    rows = membership_candidate.get("rows")
    if not isinstance(rows, dict) or len(rows) != 50:
        raise BuilderError("AUTHORITY_MEMBERSHIP_ROWS_INVALID")
    actual_paths = {
        str(row.get("subject_value", ""))
        for row in rows.values()
        if isinstance(row, dict)
    }
    expected_paths = {spec[0] for spec in BATCH008_COMPONENT_SPECS} | {
        BATCH008_ALPHA01_HISTORICAL_PATH,
        BATCH008_PLAYER_MANA_HISTORICAL_PATH,
    }
    if actual_paths != expected_paths or len(actual_paths) != 50:
        raise BuilderError("AUTHORITY_MEMBERSHIP_PROJECTION_COVERAGE_INVALID")


def _exact_batch008_registry_values() -> dict[str, Any]:
    alpha = {
        "component_id": "component.current.alpha01_content_manifest",
        "current_disposition": "HISTORICAL_ACTIVE_LINEAGE_REGISTERED",
        "historical_role": "PORT",
        "production_reachability": "PRODUCTION_REACHABLE",
        "source_blob": "a49c23e9ffdee83d51d2ac1c5f2e6ceaa0e0837a43a73d0671f202d737911a1b",
        "source_commit": "e584cd4d8b0cd8afca7ff508cffcb05d1ba801a3",
        "supersession": [],
    }
    player_mana = {
        "component_id": "component.current.player_mana_runtime_controller",
        "current_disposition": "HISTORICAL_SUPERSEDED_NONREACHABLE",
        "historical_role": "OWNER",
        "production_reachability": "NONREACHABLE",
        "source_blob": "0bf285bd2f0e10d4f44ba6779a94fdf10367cf131396b59367b7b26e9d772ac5",
        "source_commit": "e584cd4d8b0cd8afca7ff508cffcb05d1ba801a3",
        "supersession": ["component.current.v07_asset_batch_core"],
    }
    for row, expected in (
        (alpha, ALPHA01_BACKFILL_PROJECTION_SHA256),
        (player_mana, PLAYER_MANA_BACKFILL_PROJECTION_SHA256),
    ):
        projection = dict(row)
        projection["authority_source_kind"] = "historical_identity_backfill"
        if sha(compact_canonical(projection)) != expected:
            raise BuilderError("BATCH008_BACKFILL_LITERAL_HASH_INVALID")
    return {
        "alpha01_backfill": alpha,
        "player_mana_backfill": player_mana,
        "v07_supersedes": ["component.current.player_mana_runtime_controller"],
    }


def _splice_once(source: bytes, anchor: bytes, replacement: bytes, label: str) -> bytes:
    if source.count(anchor) != 1:
        raise BuilderError(f"SPLICE_ANCHOR_CARDINALITY_INVALID:{label}")
    if anchor == replacement:
        raise BuilderError(f"SPLICE_NOOP_FORBIDDEN:{label}")
    return source.replace(anchor, replacement, 1)


def _unique_row_by_id(
    rows: Any,
    key: str,
    value: str,
    label: str,
) -> dict[str, Any]:
    if not isinstance(rows, list):
        raise BuilderError(f"ROW_COLLECTION_INVALID:{label}")
    matches = [row for row in rows if isinstance(row, dict) and row.get(key) == value]
    if len(matches) != 1:
        raise BuilderError(f"ROW_ID_CARDINALITY_INVALID:{label}:{value}")
    return matches[0]


def _append_historical_backfill_bytes(
    source: bytes,
    before: dict[str, Any],
    rows: list[dict[str, Any]],
) -> bytes:
    existing = before.get("historical_identity_backfill")
    if existing is not None and not isinstance(existing, list):
        raise BuilderError("REGISTRY_BACKFILL_SOURCE_NOT_LIST")
    existing_rows = existing if isinstance(existing, list) else []
    existing_keys: dict[tuple[str, str], str] = {}
    for row in existing_rows:
        if not isinstance(row, dict):
            raise BuilderError("REGISTRY_BACKFILL_SOURCE_ROW_INVALID")
        component_id = str(row.get("component_id", ""))
        source_commit = str(row.get("source_commit", ""))
        source_blob = str(row.get("source_blob", ""))
        key = (component_id, source_commit)
        if not component_id or not source_commit or not _exact_sha256(source_blob):
            raise BuilderError("REGISTRY_BACKFILL_SOURCE_IDENTITY_INVALID")
        if key in existing_keys:
            raise BuilderError("REGISTRY_BACKFILL_SOURCE_DUPLICATE")
        existing_keys[key] = source_blob
    for row in rows:
        key = (str(row["component_id"]), str(row["source_commit"]))
        if key in existing_keys:
            if existing_keys[key] == row["source_blob"]:
                raise BuilderError("REGISTRY_BACKFILL_ALREADY_PRESENT")
            raise BuilderError("REGISTRY_BACKFILL_IDENTITY_DRIFT")

    rendered = b",\n".join(b"    " + compact_canonical(row) for row in rows)
    legacy_anchor = b'\n  ],\n  "legacy_debt_grandfather_paths": ['
    if existing is None:
        replacement = (
            b'\n  ],\n  "historical_identity_backfill": [\n'
            + rendered
            + b'\n  ],\n  "legacy_debt_grandfather_paths": ['
        )
        return _splice_once(source, legacy_anchor, replacement, "REGISTRY_BACKFILL_CREATE")
    if existing_rows:
        replacement = (
            b",\n" + rendered + b'\n  ],\n  "legacy_debt_grandfather_paths": ['
        )
        return _splice_once(source, legacy_anchor, replacement, "REGISTRY_BACKFILL_APPEND")
    empty_anchor = b'"historical_identity_backfill": [],\n  "legacy_debt_grandfather_paths": ['
    empty_replacement = (
        b'"historical_identity_backfill": [\n'
        + rendered
        + b'\n  ],\n  "legacy_debt_grandfather_paths": ['
    )
    return _splice_once(source, empty_anchor, empty_replacement, "REGISTRY_BACKFILL_EMPTY_APPEND")


def _append_component_inventory_bytes(
    source: bytes,
    before: dict[str, Any],
    rows: list[dict[str, Any]],
) -> bytes:
    if not rows:
        raise BuilderError("REGISTRY_COMPONENT_APPEND_EMPTY")
    rendered = b",\n".join(b"    " + compact_canonical(row) for row in rows)
    if "historical_identity_backfill" in before:
        anchor = b'\n  ],\n  "historical_identity_backfill": ['
        replacement = (
            b",\n" + rendered + b'\n  ],\n  "historical_identity_backfill": ['
        )
        label = "REGISTRY_COMPONENT_APPEND_BEFORE_BACKFILL"
    else:
        anchor = b'\n  ],\n  "legacy_debt_grandfather_paths": ['
        replacement = (
            b",\n" + rendered + b'\n  ],\n  "legacy_debt_grandfather_paths": ['
        )
        label = "REGISTRY_COMPONENT_APPEND_BEFORE_LEGACY_DEBT"
    return _splice_once(source, anchor, replacement, label)


def _build_registry_target(
    root: Path,
    head: str,
    source: bytes,
) -> tuple[bytes, dict[str, Any], dict[str, Any], list[dict[str, Any]]]:
    before = strict_json_bytes(source, REGISTRY.as_posix())
    inventory = before.get("component_inventory")
    if not isinstance(inventory, list):
        raise BuilderError("REGISTRY_COMPONENT_INVENTORY_INVALID")
    component_rows = _exact_batch008_component_rows(root, head)
    existing_ids = {str(row.get("component_id", "")) for row in inventory if isinstance(row, dict)}
    existing_paths = {str(row.get("path", "")) for row in inventory if isinstance(row, dict)}
    existing_classes = {str(row.get("class_name", "")) for row in inventory if isinstance(row, dict)}
    for row in component_rows:
        if row["component_id"] in existing_ids:
            raise BuilderError(f"BATCH008_COMPONENT_ID_ALREADY_PRESENT:{row['component_id']}")
        if row["path"] in existing_paths:
            raise BuilderError(f"BATCH008_COMPONENT_PATH_ALREADY_PRESENT:{row['path']}")
        if row["class_name"] in existing_classes:
            raise BuilderError(f"BATCH008_COMPONENT_CLASS_ALREADY_PRESENT:{row['class_name']}")
    alpha_row = _unique_row_by_id(
        inventory,
        "component_id",
        "component.current.alpha01_content_manifest",
        "REGISTRY_ALPHA01",
    )
    v07_row = _unique_row_by_id(
        inventory,
        "component_id",
        "component.current.v07_asset_batch_core",
        "REGISTRY_V07_ASSET",
    )
    if sha(compact_canonical(alpha_row)) != ALPHA01_REGISTRY_ROW_BEFORE_SHA256:
        raise BuilderError("ALPHA01_REGISTRY_ROW_AUTHORITY_DRIFT")
    if v07_row.get("supersedes") != []:
        raise BuilderError("V07_ASSET_SUPERSEDES_NOT_EMPTY")

    values = _exact_batch008_registry_values()
    for path, row in (
        (BATCH008_ALPHA01_HISTORICAL_PATH, values["alpha01_backfill"]),
        (BATCH008_PLAYER_MANA_HISTORICAL_PATH, values["player_mana_backfill"]),
    ):
        relative = Path(path)
        historical = _committed_bytes(root, BATCH008_SOURCE_COMMIT, relative)
        current = _require_committed_parity(root, head, relative)
        if historical != current or sha(historical) != row["source_blob"]:
            raise BuilderError(f"BATCH008_BACKFILL_SOURCE_DRIFT:{path}")
    marker = b'"component_id": "component.current.v07_asset_batch_core"'
    if source.count(marker) != 1:
        raise BuilderError("V07_ASSET_MARKER_CARDINALITY_INVALID")
    marker_at = source.index(marker)
    object_start = source.rfind(b"\n    {", 0, marker_at)
    object_end_marker = b"\n    },\n    {"
    object_end_at = source.find(object_end_marker, marker_at)
    if object_start < 0 or object_end_at < 0:
        raise BuilderError("V07_ASSET_OBJECT_BOUNDARY_INVALID")
    object_end = object_end_at + len(b"\n    }")
    scope = source[object_start:object_end]
    link_anchor = b'\n      "supersedes": [],\n      "superseded_by": []'
    link_replacement = (
        b'\n      "supersedes": [\n'
        b'        "component.current.player_mana_runtime_controller"\n'
        b'      ],\n      "superseded_by": []'
    )
    updated_scope = _splice_once(scope, link_anchor, link_replacement, "V07_SUPERSEDES")
    target = source[:object_start] + updated_scope + source[object_end:]

    target = _append_component_inventory_bytes(target, before, component_rows)
    target = _append_historical_backfill_bytes(
        target,
        before,
        [values["alpha01_backfill"], values["player_mana_backfill"]],
    )
    after = strict_json_bytes(target, "REGISTRY_TARGET")
    return target, before, after, component_rows


def _exact_player_mana_supersession() -> dict[str, Any]:
    row = {
        "supersession_id": "historical.player-mana-to-v07-asset-batch-core",
        "domain_id": "current.v075_production_combat_candidate",
        "kind": HISTORICAL_OWNER_TO_REDUCER_KIND,
        "old_component_id": "component.current.player_mana_runtime_controller",
        "new_component_id": "component.current.v07_asset_batch_core",
        "old_owner_path": "scripts/runtime/player_mana_runtime_controller.gd",
        "new_owner_path": "scripts/v07_semantic/v07_asset_batch_core.gd",
        "old_authority_source_kind": "historical_identity_backfill",
        "old_source_commit": BATCH008_SOURCE_COMMIT,
        "old_source_blob_sha256": (
            "0bf285bd2f0e10d4f44ba6779a94fdf10367cf131396b59367b7b26e9d772ac5"
        ),
        "new_component_role": "REDUCER",
        "new_owner_component_id": "component.current.v075_runtime_owner",
        "production_scene_path": "scenes/main.tscn",
        "old_runtime_composition_path": "scenes/runtime/GameRuntimeCoordinator.tscn",
        "old_component_scene_path": "scenes/runtime/PlayerManaRuntimeController.tscn",
        "new_runtime_composition_path": "scenes/runtime/V073RuntimeComposition.tscn",
        "cutover_new_runtime_owner_path": (
            "scripts/v073_runtime/v073_sample_runtime_owner.gd"
        ),
        "cutover_manifest_path": BATCH008_CUTOVER_MANIFEST.as_posix(),
        "cutover_manifest_sha256": BATCH008_CUTOVER_MANIFEST_SHA256,
        "replacement_reason": (
            "The former standalone PlayerManaRuntimeController asset Owner is retained "
            "only in the detached legacy GameRuntimeCoordinator composition. The current "
            "production lineage keeps the same six-color asset quantity in the existing "
            "V07AssetBatchCore reducer under V075RuntimeOwner, so a second asset Owner is "
            "not registered."
        ),
        "migration_strategy": (
            "The production main scene cut over atomically from GameRuntimeCoordinator to "
            "the V073 runtime lineage at f49c86af20b6a65e9792aa87703154e853d4dc76; "
            "V074 and V075 continue the same V07 asset reducer lineage with no dual write "
            "or fallback to PlayerManaRuntimeController."
        ),
        "consumer_inventory": ["component.current.v075_runtime_owner"],
        "save_impact": "NONE_NEW_GAME_ONLY",
        "rng_impact": "NONE_NEITHER_COMPONENT_OWNS_RNG",
        "replay_impact": (
            "No replay input or cursor is added; current replay remains owned by the "
            "existing deterministic runtime lineage."
        ),
        "cutover_commit": BATCH008_CUTOVER_COMMIT,
        "old_owner_retirement_status": "RETIRED_BY_CONSTITUTION",
        "dual_write_count": 0,
        "fallback_count": 0,
        "old_owner_production_reachability": 0,
        "new_owner_production_owner_count": 1,
    }
    if len(row) != 31 or sha(compact_canonical(row)) != PLAYER_MANA_SUPERSESSION_COMPACT_SHA256:
        raise BuilderError("PLAYER_MANA_SUPERSESSION_LITERAL_DRIFT")
    return row


def _require_blob_markers(
    payload: bytes,
    *,
    required: tuple[bytes, ...],
    forbidden: tuple[bytes, ...] = (),
    label: str,
) -> None:
    if any(marker not in payload for marker in required):
        raise BuilderError(f"CUTOVER_REQUIRED_MARKER_MISSING:{label}")
    if any(marker in payload for marker in forbidden):
        raise BuilderError(f"CUTOVER_FORBIDDEN_MARKER_PRESENT:{label}")


def _validate_player_mana_cutover_authority(
    root: Path,
    head: str,
    before_registry: dict[str, Any],
    after_registry: dict[str, Any],
) -> None:
    ancestry = subprocess.run(
        ["git", "merge-base", "--is-ancestor", BATCH008_CUTOVER_COMMIT, head],
        cwd=root,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if ancestry.returncode != 0:
        raise BuilderError("PLAYER_MANA_CUTOVER_NOT_HEAD_ANCESTOR")
    parent = git(root, "rev-parse", f"{BATCH008_CUTOVER_COMMIT}^")

    manifest_at_cutover = _committed_bytes(
        root, BATCH008_CUTOVER_COMMIT, BATCH008_CUTOVER_MANIFEST
    )
    manifest_at_head = _require_committed_parity(
        root, head, BATCH008_CUTOVER_MANIFEST
    )
    if (
        manifest_at_cutover != manifest_at_head
        or sha(manifest_at_head) != BATCH008_CUTOVER_MANIFEST_SHA256
    ):
        raise BuilderError("PLAYER_MANA_CUTOVER_MANIFEST_DRIFT")

    old_main = _committed_bytes(root, parent, Path("scenes/main.tscn"))
    old_composition = _committed_bytes(
        root, parent, Path("scenes/runtime/GameRuntimeCoordinator.tscn")
    )
    old_component_scene = _committed_bytes(
        root, parent, Path("scenes/runtime/PlayerManaRuntimeController.tscn")
    )
    _require_blob_markers(
        old_main,
        required=(b"scenes/runtime/GameRuntimeCoordinator.tscn",),
        forbidden=(b"scenes/runtime/V073RuntimeComposition.tscn",),
        label="CUTOVER_PARENT_MAIN",
    )
    _require_blob_markers(
        old_composition,
        required=(b"scenes/runtime/PlayerManaRuntimeController.tscn",),
        label="CUTOVER_PARENT_COMPOSITION",
    )
    _require_blob_markers(
        old_component_scene,
        required=(b"scripts/runtime/player_mana_runtime_controller.gd",),
        label="CUTOVER_PARENT_PLAYER_MANA_SCENE",
    )

    cutover_main = _committed_bytes(
        root, BATCH008_CUTOVER_COMMIT, Path("scenes/main.tscn")
    )
    cutover_composition = _committed_bytes(
        root,
        BATCH008_CUTOVER_COMMIT,
        Path("scenes/runtime/V073RuntimeComposition.tscn"),
    )
    cutover_owner = _committed_bytes(
        root,
        BATCH008_CUTOVER_COMMIT,
        Path("scripts/v073_runtime/v073_sample_runtime_owner.gd"),
    )
    _require_blob_markers(
        cutover_main,
        required=(b"scenes/runtime/V073RuntimeComposition.tscn",),
        forbidden=(
            b"scenes/runtime/GameRuntimeCoordinator.tscn",
            b"scenes/runtime/PlayerManaRuntimeController.tscn",
        ),
        label="CUTOVER_MAIN",
    )
    _require_blob_markers(
        cutover_composition,
        required=(b"scripts/v073_runtime/v073_sample_runtime_owner.gd",),
        forbidden=(
            b"scenes/runtime/GameRuntimeCoordinator.tscn",
            b"scenes/runtime/PlayerManaRuntimeController.tscn",
        ),
        label="CUTOVER_COMPOSITION",
    )
    _require_blob_markers(
        cutover_owner,
        required=(b"scripts/v07_semantic/v07_asset_batch_core.gd",),
        forbidden=(b"scripts/runtime/player_mana_runtime_controller.gd",),
        label="CUTOVER_RUNTIME_OWNER",
    )

    current_main = _require_committed_parity(root, head, Path("scenes/main.tscn"))
    current_composition = _require_committed_parity(
        root, head, Path("scenes/runtime/V075RuntimeComposition.tscn")
    )
    current_v075_owner = _require_committed_parity(
        root, head, Path("scripts/v075_runtime/v075_runtime_owner.gd")
    )
    current_v074_owner = _require_committed_parity(
        root, head, Path("scripts/v074_runtime/v074_runtime_owner.gd")
    )
    current_v073_owner = _require_committed_parity(
        root, head, Path("scripts/v073_runtime/v073_sample_runtime_owner.gd")
    )
    _require_blob_markers(
        current_main,
        required=(b"scenes/runtime/V075RuntimeComposition.tscn",),
        forbidden=(
            b"scenes/runtime/GameRuntimeCoordinator.tscn",
            b"scenes/runtime/PlayerManaRuntimeController.tscn",
        ),
        label="CURRENT_MAIN",
    )
    _require_blob_markers(
        current_composition,
        required=(b"scripts/v075_runtime/v075_runtime_owner.gd",),
        forbidden=(
            b"scenes/runtime/GameRuntimeCoordinator.tscn",
            b"scenes/runtime/PlayerManaRuntimeController.tscn",
        ),
        label="CURRENT_V075_COMPOSITION",
    )
    _require_blob_markers(
        current_v075_owner,
        required=(b"scripts/v074_runtime/v074_runtime_owner.gd",),
        label="CURRENT_V075_OWNER",
    )
    _require_blob_markers(
        current_v074_owner,
        required=(b"scripts/v073_runtime/v073_sample_runtime_owner.gd",),
        label="CURRENT_V074_OWNER",
    )
    _require_blob_markers(
        current_v073_owner,
        required=(b"scripts/v07_semantic/v07_asset_batch_core.gd",),
        forbidden=(b"scripts/runtime/player_mana_runtime_controller.gd",),
        label="CURRENT_V073_OWNER",
    )

    old_id = "component.current.player_mana_runtime_controller"
    new_id = "component.current.v07_asset_batch_core"
    owner_id = "component.current.v075_runtime_owner"
    before_inventory = before_registry.get("component_inventory")
    after_inventory = after_registry.get("component_inventory")
    if not isinstance(before_inventory, list) or not isinstance(after_inventory, list):
        raise BuilderError("PLAYER_MANA_COMPONENT_INVENTORY_INVALID")
    if any(
        isinstance(row, dict) and row.get("component_id") == old_id
        for row in after_inventory
    ):
        raise BuilderError("PLAYER_MANA_OLD_COMPONENT_REGISTERED_AS_CURRENT")
    new_row = _unique_row_by_id(
        after_inventory, "component_id", new_id, "PLAYER_MANA_CURRENT_REDUCER"
    )
    owner_row = _unique_row_by_id(
        after_inventory, "component_id", owner_id, "PLAYER_MANA_CURRENT_OWNER"
    )
    if not (
        new_row.get("component_role") == "REDUCER"
        and new_row.get("production_reachable") is True
        and new_row.get("writes_authority") is True
        and new_row.get("owner_component_id") == owner_id
        and old_id in set(map(str, new_row.get("supersedes", [])))
        and owner_row.get("component_role") == "OWNER"
        and owner_row.get("production_reachable") is True
        and owner_row.get("writes_authority") is True
    ):
        raise BuilderError("PLAYER_MANA_CURRENT_REDUCER_OWNER_BINDING_INVALID")
    backfills = after_registry.get("historical_identity_backfill")
    old_backfill = _unique_row_by_id(
        backfills, "component_id", old_id, "PLAYER_MANA_HISTORICAL_BACKFILL"
    )
    if old_backfill != _exact_batch008_registry_values()["player_mana_backfill"]:
        raise BuilderError("PLAYER_MANA_HISTORICAL_BACKFILL_INVALID")


def _indented_json_object(value: dict[str, Any], spaces: int) -> bytes:
    rendered = json.dumps(value, ensure_ascii=False, indent=2).splitlines()
    prefix = " " * spaces
    return ("\n".join(prefix + line for line in rendered)).encode("utf-8")


def _build_map_target(source: bytes) -> tuple[bytes, dict[str, Any], dict[str, Any]]:
    before = strict_json_bytes(source, SUPERSESSION_MAP.as_posix())
    entries = before.get("entries")
    summary = before.get("summary")
    kinds = before.get("supersession_kinds")
    if not isinstance(entries, list):
        raise BuilderError("SUPERSESSION_SOURCE_ENTRY_COUNT_INVALID")
    if (
        not isinstance(kinds, list)
        or any(not isinstance(value, str) or not value for value in kinds)
        or len(kinds) != len(set(kinds))
        or HISTORICAL_OWNER_TO_REDUCER_KIND in kinds
    ):
        raise BuilderError("SUPERSESSION_SOURCE_KINDS_INVALID")
    if (
        not isinstance(summary, dict)
        or type(summary.get("entry_count")) is not int
        or summary.get("entry_count") != len(entries)
    ):
        raise BuilderError("SUPERSESSION_SOURCE_SUMMARY_INVALID")
    row = _exact_player_mana_supersession()
    if any(
        isinstance(value, dict)
        and (
            value.get("supersession_id") == row["supersession_id"]
            or (
                value.get("old_component_id") == row["old_component_id"]
                and value.get("new_component_id") == row["new_component_id"]
            )
        )
        for value in entries
    ):
        raise BuilderError("PLAYER_MANA_SUPERSESSION_ALREADY_PRESENT")
    kinds_anchor = b'\n  ],\n  "entries": ['
    kinds_replacement = (
        b',\n    "'
        + HISTORICAL_OWNER_TO_REDUCER_KIND.encode("ascii")
        + b'"\n  ],\n  "entries": ['
    )
    target = _splice_once(
        source,
        kinds_anchor,
        kinds_replacement,
        "SUPERSESSION_KIND_APPEND",
    )
    map_anchor = b'\n    }\n  ],\n  "summary": {'
    map_replacement = (
        b"\n    },\n"
        + _indented_json_object(row, 4)
        + b'\n  ],\n  "summary": {'
    )
    target = _splice_once(target, map_anchor, map_replacement, "SUPERSESSION_APPEND")
    before_count = len(entries)
    after_count = before_count + 1
    target = _splice_once(
        target,
        f'"entry_count": {before_count}'.encode("ascii"),
        f'"entry_count": {after_count}'.encode("ascii"),
        "SUPERSESSION_SUMMARY_COUNT",
    )
    after = strict_json_bytes(target, "SUPERSESSION_MAP_TARGET")
    return target, before, after


def _assert_unique_ids(rows: Any, key: str, label: str) -> None:
    if not isinstance(rows, list) or any(not isinstance(row, dict) for row in rows):
        raise BuilderError(f"SEMANTIC_ROWS_INVALID:{label}")
    ids = [str(row.get(key, "")) for row in rows]
    if "" in ids or len(ids) != len(set(ids)):
        raise BuilderError(f"SEMANTIC_ID_NOT_UNIQUE:{label}")


def _validate_exact_authority_semantics(
    before_registry: dict[str, Any],
    after_registry: dict[str, Any],
    before_map: dict[str, Any],
    after_map: dict[str, Any],
    component_rows: list[dict[str, Any]],
) -> None:
    values = _exact_batch008_registry_values()
    supersession_row = _exact_player_mana_supersession()
    expected_registry = copy.deepcopy(before_registry)
    expected_registry["component_inventory"].extend(copy.deepcopy(component_rows))
    prior_backfills = expected_registry.get("historical_identity_backfill", [])
    if not isinstance(prior_backfills, list):
        raise BuilderError("EXPECTED_BACKFILL_SOURCE_NOT_LIST")
    expected_registry["historical_identity_backfill"] = prior_backfills + [
        values["alpha01_backfill"], values["player_mana_backfill"]
    ]
    expected_v07 = _unique_row_by_id(
        expected_registry.get("component_inventory"),
        "component_id",
        "component.current.v07_asset_batch_core",
        "EXPECTED_REGISTRY_V07_ASSET",
    )
    expected_v07["supersedes"] = values["v07_supersedes"]
    if after_registry != expected_registry:
        raise BuilderError("REGISTRY_SEMANTIC_DIFF_NOT_ALLOWLISTED")

    expected_map = copy.deepcopy(before_map)
    expected_map["supersession_kinds"].append(HISTORICAL_OWNER_TO_REDUCER_KIND)
    expected_map["entries"].append(supersession_row)
    expected_map["summary"]["entry_count"] = len(expected_map["entries"])
    if after_map != expected_map:
        raise BuilderError("SUPERSESSION_SEMANTIC_DIFF_NOT_ALLOWLISTED")

    _assert_unique_ids(after_registry.get("component_inventory"), "component_id", "COMPONENT_INVENTORY")
    _assert_unique_ids(after_registry.get("component_inventory"), "path", "COMPONENT_PATHS")
    _assert_unique_ids(after_registry.get("component_inventory"), "class_name", "COMPONENT_CLASSES")
    _assert_unique_ids(after_registry.get("reuse_entries"), "reuse_id", "REUSE_ENTRIES")
    _assert_unique_ids(after_map.get("entries"), "supersession_id", "SUPERSESSION_ENTRIES")
    if (
        after_map.get("supersession_kinds", []).count(HISTORICAL_OWNER_TO_REDUCER_KIND)
        != 1
    ):
        raise BuilderError("SUPERSESSION_KIND_CARDINALITY_INVALID")
    backfills = after_registry.get("historical_identity_backfill")
    if not isinstance(backfills, list) or len(backfills) != len(prior_backfills) + 2:
        raise BuilderError("BACKFILL_CARDINALITY_INVALID")
    primary_keys = [
        (
            str(row.get("component_id", "")),
            str(row.get("source_commit", "")),
            str(row.get("source_blob", "")),
        )
        for row in backfills
        if isinstance(row, dict)
    ]
    if len(primary_keys) != len(backfills) or len(primary_keys) != len(set(primary_keys)):
        raise BuilderError("BACKFILL_PRIMARY_KEY_NOT_UNIQUE")
    for row, expected_hash in (
        (backfills[-2], ALPHA01_BACKFILL_PROJECTION_SHA256),
        (backfills[-1], PLAYER_MANA_BACKFILL_PROJECTION_SHA256),
    ):
        projection = dict(row)
        projection["authority_source_kind"] = "historical_identity_backfill"
        if sha(compact_canonical(projection)) != expected_hash:
            raise BuilderError("BACKFILL_PROJECTION_HASH_INVALID")
    after_v07 = _unique_row_by_id(
        after_registry.get("component_inventory"),
        "component_id",
        "component.current.v07_asset_batch_core",
        "AFTER_REGISTRY_V07_ASSET",
    )
    if sha(compact_canonical(after_v07)) != V07_ASSET_ROW_AFTER_SHA256:
        raise BuilderError("V07_ASSET_AFTER_HASH_INVALID")
    before_alpha = _unique_row_by_id(
        before_registry.get("component_inventory"),
        "component_id",
        "component.current.alpha01_content_manifest",
        "BEFORE_REGISTRY_ALPHA01",
    )
    after_alpha = _unique_row_by_id(
        after_registry.get("component_inventory"),
        "component_id",
        "component.current.alpha01_content_manifest",
        "AFTER_REGISTRY_ALPHA01",
    )
    if before_alpha != after_alpha:
        raise BuilderError("ALPHA01_CURRENT_ROW_MUTATED")
    appended_components = after_registry.get("component_inventory", [
    ])[len(before_registry.get("component_inventory", [])):]
    if appended_components != component_rows or len(appended_components) != 48:
        raise BuilderError("BATCH008_COMPONENT_APPEND_INVALID")
    for row in appended_components:
        if set(row) != COMPONENT_ROW_FIELDS:
            raise BuilderError("BATCH008_COMPONENT_ROW_SCHEMA_INVALID")
        owner = _unique_row_by_id(
            after_registry.get("component_inventory"),
            "component_id",
            str(row.get("owner_component_id", "")),
            "BATCH008_COMPONENT_OWNER",
        )
        if owner.get("component_role") != "OWNER" or owner.get("production_reachable") is not True:
            raise BuilderError("BATCH008_COMPONENT_OWNER_BINDING_INVALID")


def _build_mutation_inventory(
    before_registry: dict[str, Any],
    after_registry: dict[str, Any],
    before_map: dict[str, Any],
    after_map: dict[str, Any],
    component_rows: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    before_v07 = _unique_row_by_id(
        before_registry["component_inventory"],
        "component_id",
        "component.current.v07_asset_batch_core",
        "MUTATION_BEFORE_V07",
    )
    after_v07 = _unique_row_by_id(
        after_registry["component_inventory"],
        "component_id",
        "component.current.v07_asset_batch_core",
        "MUTATION_AFTER_V07",
    )
    map_row = _exact_player_mana_supersession()
    values = _exact_batch008_registry_values()
    component_id_set_sha256 = line_set_sha(
        sorted(str(row["component_id"]) for row in component_rows)
    )
    inventory = [
        {
            "target_path": REGISTRY.as_posix(),
            "operation": "APPEND_COMPONENT_INVENTORY_ROWS",
            "locator": f"batch_id=batch-008;count=48;component_id_set_sha256={component_id_set_sha256}",
            "before_exists": False,
            "before_canonical_sha256": sha(compact_canonical(None)),
            "after_canonical_sha256": sha(compact_canonical(component_rows)),
        },
        {
            "target_path": REGISTRY.as_posix(),
            "operation": "ADD_HISTORICAL_IDENTITY_BACKFILL",
            "locator": "batch_id=batch-008;count=2;source_commit=e584cd4d8b0cd8afca7ff508cffcb05d1ba801a3",
            "before_exists": False,
            "before_canonical_sha256": sha(compact_canonical(None)),
            "after_canonical_sha256": sha(compact_canonical([
                values["alpha01_backfill"], values["player_mana_backfill"]
            ])),
        },
        {
            "target_path": REGISTRY.as_posix(),
            "operation": "EXTEND_COMPONENT_SUPERSEDES",
            "locator": "component_id=component.current.v07_asset_batch_core",
            "before_exists": True,
            "before_canonical_sha256": sha(compact_canonical(before_v07)),
            "after_canonical_sha256": sha(compact_canonical(after_v07)),
        },
        {
            "target_path": SUPERSESSION_MAP.as_posix(),
            "operation": "APPEND_KIND_SUPERSESSION_AND_INCREMENT_ENTRY_COUNT",
            "locator": (
                "kind=HISTORICAL_IDENTITY_BACKFILL_OWNER_TO_CURRENT_REDUCER;"
                "supersession_id=historical.player-mana-to-v07-asset-batch-core;"
                f"summary.entry_count={before_map['summary']['entry_count']}-to-"
                f"{after_map['summary']['entry_count']}"
            ),
            "before_exists": False,
            "before_canonical_sha256": sha(compact_canonical({"entry": None, "entry_count": before_map["summary"]["entry_count"]})),
            "after_canonical_sha256": sha(compact_canonical({"entry": map_row, "entry_count": after_map["summary"]["entry_count"]})),
        },
    ]
    for row in inventory:
        if set(row) != MUTATION_FIELDS or any(char in row["locator"] for char in "*?[]"):
            raise BuilderError("MUTATION_INVENTORY_CONTRACT_INVALID")
    if len(inventory) != 4:
        raise BuilderError("MUTATION_INVENTORY_COUNT_INVALID")
    return inventory


def _authority_target_entry(source: dict[str, Any], target: bytes) -> dict[str, Any]:
    return {
        "path": str(source["relative_path"]),
        "source_blob_oid": source["source_blob_oid"],
        "source_bytes_sha256": source["source_bytes_sha256"],
        "source_byte_count": source["source_byte_count"],
        "target_encoding": "BASE64",
        "target_bytes_base64": base64.b64encode(target).decode("ascii"),
        "target_bytes_sha256": sha(target),
        "target_byte_count": len(target),
    }


def _build_authority_projection(
    root: Path,
    head: str,
    *,
    require_worktree_parity: bool,
) -> dict[str, Any]:
    sources = _load_registry_sources(
        root,
        head,
        require_worktree_parity=require_worktree_parity,
    )
    registry_source = sources[REGISTRY.as_posix()]
    map_source = sources[SUPERSESSION_MAP.as_posix()]
    registry_target, before_registry, after_registry, component_rows = (
        _build_registry_target(root, head, registry_source["bytes"])
    )
    map_target, before_map, after_map = _build_map_target(map_source["bytes"])
    _validate_exact_authority_semantics(
        before_registry,
        after_registry,
        before_map,
        after_map,
        component_rows,
    )
    _validate_player_mana_cutover_authority(
        root,
        head,
        before_registry,
        after_registry,
    )
    mutation_inventory = _build_mutation_inventory(
        before_registry,
        after_registry,
        before_map,
        after_map,
        component_rows,
    )
    target_files: list[dict[str, Any]] = []
    for relative, source, target in (
        (REGISTRY, registry_source, registry_target),
        (SUPERSESSION_MAP, map_source, map_target),
    ):
        material = dict(source)
        material["relative_path"] = relative.as_posix()
        target_files.append(_authority_target_entry(material, target))
    return {
        "target_files": target_files,
        "target_bytes": {
            REGISTRY.as_posix(): registry_target,
            SUPERSESSION_MAP.as_posix(): map_target,
        },
        "mutation_inventory": mutation_inventory,
        "component_rows": component_rows,
    }


def _require_external_plain_file(
    path: Path,
    label: str,
    root: Path,
    staging_root: Path,
) -> Path:
    stage = _assert_external_stage(root, staging_root, f"{label}_STAGING_ROOT")
    lexical = _lexical_absolute(path, label)
    _reject_reparse_chain(lexical, label)
    try:
        resolved = lexical.resolve(strict=True)
    except OSError as exc:
        raise BuilderError(f"{label}_FILE_INVALID") from exc
    try:
        resolved.relative_to(stage)
    except ValueError as exc:
        raise BuilderError(f"{label}_OUTSIDE_EXPLICIT_STAGING_ROOT") from exc
    if not resolved.is_file():
        raise BuilderError(f"{label}_FILE_INVALID")
    try:
        info = os.stat(resolved, follow_symlinks=False)
    except OSError as exc:
        raise BuilderError(f"{label}_STAT_FAILED") from exc
    if int(getattr(info, "st_nlink", 1)) != 1:
        raise BuilderError(f"{label}_HARDLINK_FORBIDDEN")
    return resolved


def build_authority_candidate(
    root: Path,
    membership_candidate_path: Path,
    membership_seal_path: Path,
    staging_root: Path,
    output: Path,
    head_ref: str = "HEAD",
) -> dict[str, Any]:
    root = root.resolve()
    head = git(root, "rev-parse", f"{head_ref}^{{commit}}")
    live_head = git(root, "rev-parse", "HEAD")
    if head != live_head:
        raise BuilderError("AUTHORITY_HEAD_REF_NOT_LIVE_HEAD")
    membership_stage = membership_candidate_path.parent
    membership_candidate_path = _require_external_plain_file(
        membership_candidate_path,
        "MEMBERSHIP_CANDIDATE",
        root,
        membership_stage,
    )
    membership_seal_path = _require_external_plain_file(
        membership_seal_path,
        "MEMBERSHIP_SEAL",
        root,
        membership_stage,
    )
    membership = _validate_membership_seal(
        root, membership_candidate_path, membership_seal_path
    )
    _validate_batch008_membership_projection(membership["candidate"])
    if membership["candidate"].get("evaluated_head_sha") != head:
        raise BuilderError("AUTHORITY_MEMBERSHIP_HEAD_MISMATCH")
    tree = git(root, "rev-parse", f"{head}^{{tree}}")
    projection = _build_authority_projection(
        root, head, require_worktree_parity=True
    )
    candidate = {
        "schema_version": AUTHORITY_CANDIDATE_SCHEMA,
        "candidate_kind": AUTHORITY_CANDIDATE_KIND,
        "authorization_id": convergence.AUTHORIZATION_ID,
        "batch_id": "batch-008",
        "evaluated_head_sha": head,
        "evaluated_tree_sha": tree,
        "membership_authority": {
            "candidate_path": membership_candidate_path.as_posix(),
            "candidate_file_sha256": membership["candidate_file_sha256"],
            "candidate_payload_sha256": membership["candidate"]["candidate_payload_sha256"],
            "seal_path": membership_seal_path.as_posix(),
            "seal_file_sha256": membership["seal_file_sha256"],
            "seal_payload_sha256": membership["seal"]["seal_payload_sha256"],
            "primary_review_file_sha256": membership["review_file_sha256"]["PRIMARY"],
            "independent_review_file_sha256": membership["review_file_sha256"]["INDEPENDENT"],
        },
        "target_files": projection["target_files"],
        "mutation_inventory": projection["mutation_inventory"],
        "mutation_inventory_sha256": sha(canonical(projection["mutation_inventory"])),
        "required_review_ids": ["PRIMARY", "INDEPENDENT"],
        "review_status": "PENDING",
        "go_claim": False,
        "official_write_count": 0,
        "next_builder_phase": AUTHORITY_CANDIDATE_NEXT_PHASE,
    }
    candidate["candidate_payload_sha256"] = sha(canonical(candidate))
    safe_output = _assert_output_safe(root, staging_root, output)
    _exclusive_write(safe_output, canonical(candidate))
    return candidate


def _decode_authority_target(row: Any, label: str) -> bytes:
    if not isinstance(row, dict) or set(row) != AUTHORITY_TARGET_FIELDS:
        raise BuilderError(f"AUTHORITY_TARGET_SCHEMA_INVALID:{label}")
    if (
        not isinstance(row.get("path"), str)
        or not row.get("path")
        or Path(row["path"]).is_absolute()
        or ".." in Path(row["path"]).parts
        or not _exact_commit(row.get("source_blob_oid"))
        or not _exact_sha256(row.get("source_bytes_sha256"))
        or not _exact_nonnegative_int(row.get("source_byte_count"))
        or row.get("target_encoding") != "BASE64"
        or not isinstance(row.get("target_bytes_base64"), str)
        or not _exact_sha256(row.get("target_bytes_sha256"))
        or not _exact_nonnegative_int(row.get("target_byte_count"))
    ):
        raise BuilderError(f"AUTHORITY_TARGET_CONTRACT_INVALID:{label}")
    try:
        decoded = base64.b64decode(row["target_bytes_base64"], validate=True)
    except Exception as exc:
        raise BuilderError(f"AUTHORITY_TARGET_BASE64_INVALID:{label}") from exc
    if base64.b64encode(decoded).decode("ascii") != row["target_bytes_base64"]:
        raise BuilderError(f"AUTHORITY_TARGET_BASE64_NONCANONICAL:{label}")
    if len(decoded) != row["target_byte_count"] or sha(decoded) != row["target_bytes_sha256"]:
        raise BuilderError(f"AUTHORITY_TARGET_PAYLOAD_INVALID:{label}")
    return decoded


def _validate_mutation_inventory(value: Any) -> list[dict[str, Any]]:
    if not isinstance(value, list) or len(value) != 4:
        raise BuilderError("AUTHORITY_MUTATION_INVENTORY_INVALID")
    for index, row in enumerate(value):
        if (
            not isinstance(row, dict)
            or set(row) != MUTATION_FIELDS
            or not isinstance(row.get("target_path"), str)
            or row.get("target_path") not in {REGISTRY.as_posix(), SUPERSESSION_MAP.as_posix()}
            or not isinstance(row.get("operation"), str)
            or not row.get("operation")
            or not isinstance(row.get("locator"), str)
            or not row.get("locator")
            or any(char in row.get("locator", "") for char in "*?[]")
            or type(row.get("before_exists")) is not bool
            or not _exact_sha256(row.get("before_canonical_sha256"))
            or not _exact_sha256(row.get("after_canonical_sha256"))
        ):
            raise BuilderError(f"AUTHORITY_MUTATION_ROW_INVALID:{index}")
    return value


def _validate_authority_candidate_fresh(
    root: Path,
    candidate_path: Path,
    *,
    require_source_worktree: bool = True,
) -> tuple[dict[str, Any], str, dict[str, bytes]]:
    root = root.resolve()
    authority_stage = candidate_path.parent
    candidate_path = _require_external_plain_file(
        candidate_path,
        "AUTHORITY_CANDIDATE",
        root,
        authority_stage,
    )
    raw = candidate_path.read_bytes()
    candidate = strict_json_bytes(raw, "AUTHORITY_CANDIDATE")
    if raw != canonical(candidate):
        raise BuilderError("AUTHORITY_CANDIDATE_BYTES_NOT_CANONICAL")
    static_contract = {
        "schema_version": AUTHORITY_CANDIDATE_SCHEMA,
        "candidate_kind": AUTHORITY_CANDIDATE_KIND,
        "authorization_id": convergence.AUTHORIZATION_ID,
        "batch_id": "batch-008",
        "required_review_ids": ["PRIMARY", "INDEPENDENT"],
        "review_status": "PENDING",
        "go_claim": False,
        "official_write_count": 0,
        "next_builder_phase": AUTHORITY_CANDIDATE_NEXT_PHASE,
    }
    if (
        set(candidate) != AUTHORITY_CANDIDATE_FIELDS
        or any(
            type(candidate.get(key)) is not type(value)
            or candidate.get(key) != value
            for key, value in static_contract.items()
        )
        or type(candidate.get("official_write_count")) is not int
        or not _payload_hash_valid(candidate, "candidate_payload_sha256")
        or not _exact_commit(candidate.get("evaluated_head_sha"))
        or not _exact_commit(candidate.get("evaluated_tree_sha"))
    ):
        raise BuilderError("AUTHORITY_CANDIDATE_CONTRACT_INVALID")
    head = git(root, "rev-parse", "HEAD")
    tree = git(root, "rev-parse", "HEAD^{tree}")
    if candidate["evaluated_head_sha"] != head:
        raise BuilderError("AUTHORITY_CANDIDATE_HEAD_DRIFT")
    if candidate["evaluated_tree_sha"] != tree:
        raise BuilderError("AUTHORITY_CANDIDATE_TREE_DRIFT")

    authority = candidate.get("membership_authority")
    if not isinstance(authority, dict) or set(authority) != MEMBERSHIP_AUTHORITY_FIELDS:
        raise BuilderError("AUTHORITY_MEMBERSHIP_AUTHORITY_SCHEMA_INVALID")
    for key in MEMBERSHIP_AUTHORITY_FIELDS - {"candidate_path", "seal_path"}:
        if not _exact_sha256(authority.get(key)):
            raise BuilderError(f"AUTHORITY_MEMBERSHIP_HASH_INVALID:{key}")
    declared_membership_candidate = Path(str(authority.get("candidate_path", "")))
    membership_stage = declared_membership_candidate.parent
    membership_candidate_path = _require_external_plain_file(
        declared_membership_candidate,
        "MEMBERSHIP_CANDIDATE",
        root,
        membership_stage,
    )
    membership_seal_path = _require_external_plain_file(
        Path(str(authority.get("seal_path", ""))),
        "MEMBERSHIP_SEAL",
        root,
        membership_stage,
    )
    membership = _validate_membership_seal(
        root, membership_candidate_path, membership_seal_path
    )
    _validate_batch008_membership_projection(membership["candidate"])
    expected_membership = {
        "candidate_path": membership_candidate_path.as_posix(),
        "candidate_file_sha256": membership["candidate_file_sha256"],
        "candidate_payload_sha256": membership["candidate"]["candidate_payload_sha256"],
        "seal_path": membership_seal_path.as_posix(),
        "seal_file_sha256": membership["seal_file_sha256"],
        "seal_payload_sha256": membership["seal"]["seal_payload_sha256"],
        "primary_review_file_sha256": membership["review_file_sha256"]["PRIMARY"],
        "independent_review_file_sha256": membership["review_file_sha256"]["INDEPENDENT"],
    }
    if authority != expected_membership:
        raise BuilderError("AUTHORITY_MEMBERSHIP_AUTHORITY_DRIFT")

    target_rows = candidate.get("target_files")
    if not isinstance(target_rows, list) or len(target_rows) != 2:
        raise BuilderError("AUTHORITY_TARGET_SET_INVALID")
    decoded_targets: dict[str, bytes] = {}
    for index, row in enumerate(target_rows):
        decoded = _decode_authority_target(row, str(index))
        path = str(row["path"])
        if path in decoded_targets:
            raise BuilderError("AUTHORITY_TARGET_PATH_DUPLICATE")
        decoded_targets[path] = decoded
    if list(decoded_targets) != [REGISTRY.as_posix(), SUPERSESSION_MAP.as_posix()]:
        raise BuilderError("AUTHORITY_TARGET_PATH_SET_INVALID")
    mutations = _validate_mutation_inventory(candidate.get("mutation_inventory"))
    if (
        not _exact_sha256(candidate.get("mutation_inventory_sha256"))
        or candidate["mutation_inventory_sha256"] != sha(canonical(mutations))
    ):
        raise BuilderError("AUTHORITY_MUTATION_INVENTORY_HASH_INVALID")
    projection = _build_authority_projection(
        root,
        head,
        require_worktree_parity=require_source_worktree,
    )
    if target_rows != projection["target_files"]:
        raise BuilderError("AUTHORITY_TARGET_FRESH_PARITY_INVALID")
    if mutations != projection["mutation_inventory"]:
        raise BuilderError("AUTHORITY_MUTATION_FRESH_PARITY_INVALID")
    return candidate, sha(raw), decoded_targets


def _authority_target_bindings(candidate: dict[str, Any]) -> dict[str, dict[str, Any]]:
    rows = candidate.get("target_files")
    if not isinstance(rows, list):
        raise BuilderError("AUTHORITY_TARGET_BINDINGS_INVALID")
    result = {str(row.get("path", "")): row for row in rows if isinstance(row, dict)}
    if set(result) != {REGISTRY.as_posix(), SUPERSESSION_MAP.as_posix()}:
        raise BuilderError("AUTHORITY_TARGET_BINDINGS_INVALID")
    return result


def _validate_authority_review(
    candidate: dict[str, Any],
    path: Path,
    root: Path,
    staging_root: Path,
) -> tuple[dict[str, Any], Path, str]:
    path = _require_external_plain_file(
        path,
        "AUTHORITY_REVIEW",
        root,
        staging_root,
    )
    raw = path.read_bytes()
    review = strict_json_bytes(raw, f"AUTHORITY_REVIEW:{path.as_posix()}")
    if raw != canonical(review):
        raise BuilderError(f"AUTHORITY_REVIEW_BYTES_NOT_CANONICAL:{path.as_posix()}")
    if (
        set(review) != AUTHORITY_REVIEW_FIELDS
        or review.get("schema_version") != AUTHORITY_REVIEW_SCHEMA
        or not _payload_hash_valid(review, "receipt_payload_sha256")
    ):
        raise BuilderError(f"AUTHORITY_REVIEW_SCHEMA_INVALID:{path.as_posix()}")
    authority = candidate["membership_authority"]
    targets = _authority_target_bindings(candidate)
    expected = {
        "candidate_payload_sha256": candidate["candidate_payload_sha256"],
        "batch_id": candidate["batch_id"],
        "evaluated_head_sha": candidate["evaluated_head_sha"],
        "evaluated_tree_sha": candidate["evaluated_tree_sha"],
        "membership_candidate_file_sha256": authority["candidate_file_sha256"],
        "membership_seal_file_sha256": authority["seal_file_sha256"],
        "source_registry_sha256": targets[REGISTRY.as_posix()]["source_bytes_sha256"],
        "source_supersession_map_sha256": targets[SUPERSESSION_MAP.as_posix()]["source_bytes_sha256"],
        "target_registry_sha256": targets[REGISTRY.as_posix()]["target_bytes_sha256"],
        "target_supersession_map_sha256": targets[SUPERSESSION_MAP.as_posix()]["target_bytes_sha256"],
        "mutation_inventory_sha256": candidate["mutation_inventory_sha256"],
        "status": "GO",
        "p0_count": 0,
        "p1_count": 0,
        "findings": [],
    }
    review_id = str(review.get("review_id", ""))
    if (
        review.get("reviewer_authority_id") != TRUSTED_REVIEWER_AUTHORITIES.get(review_id)
        or any(review.get(key) != value for key, value in expected.items())
        or type(review.get("p0_count")) is not int
        or type(review.get("p1_count")) is not int
    ):
        raise BuilderError(f"AUTHORITY_REVIEW_NOT_ACCEPTABLE:{path.as_posix()}")
    return review, path, sha(raw)


def _validate_authority_review_set(
    candidate: dict[str, Any],
    receipts: list[Path],
    root: Path,
    staging_root: Path,
) -> list[tuple[dict[str, Any], Path, str]]:
    if len(receipts) != 2:
        raise BuilderError("AUTHORITY_EXACTLY_TWO_REVIEWS_REQUIRED")
    snapshots = [
        _validate_authority_review(candidate, path, root, staging_root)
        for path in receipts
    ]
    reviews = [snapshot[0] for snapshot in snapshots]
    ids = {str(review.get("review_id", "")) for review in reviews}
    authorities = {str(review.get("reviewer_authority_id", "")) for review in reviews}
    if ids != {"PRIMARY", "INDEPENDENT"}:
        raise BuilderError("AUTHORITY_REVIEWER_SET_INVALID")
    if authorities != set(TRUSTED_REVIEWER_AUTHORITIES.values()):
        raise BuilderError("AUTHORITY_REVIEWER_AUTHORITY_SET_INVALID")
    if len({snapshot[1] for snapshot in snapshots}) != 2:
        raise BuilderError("AUTHORITY_REVIEW_FILE_IDENTITY_SET_INVALID")
    return snapshots


def seal_authority_candidate(
    root: Path,
    candidate_path: Path,
    receipts: list[Path],
    staging_root: Path,
    output: Path,
) -> dict[str, Any]:
    authority_stage = candidate_path.parent
    candidate, candidate_file_sha256, _ = _validate_authority_candidate_fresh(
        root, candidate_path, require_source_worktree=True
    )
    review_snapshots = _validate_authority_review_set(
        candidate,
        receipts,
        root.resolve(),
        authority_stage,
    )
    targets = _authority_target_bindings(candidate)
    authority = candidate["membership_authority"]
    seal = {
        "schema_version": AUTHORITY_SEAL_SCHEMA,
        "authorization_id": convergence.AUTHORIZATION_ID,
        "batch_id": candidate["batch_id"],
        "evaluated_head_sha": candidate["evaluated_head_sha"],
        "evaluated_tree_sha": candidate["evaluated_tree_sha"],
        "candidate_path": candidate_path.resolve().as_posix(),
        "candidate_file_sha256": candidate_file_sha256,
        "candidate_payload_sha256": candidate["candidate_payload_sha256"],
        "membership_candidate_file_sha256": authority["candidate_file_sha256"],
        "membership_seal_file_sha256": authority["seal_file_sha256"],
        "review_receipts": [
            {
                "path": path.as_posix(),
                "sha256": file_sha256,
                "review_id": review["review_id"],
            }
            for review, path, file_sha256 in sorted(
                review_snapshots,
                key=lambda item: str(item[0]["review_id"]),
            )
        ],
        "source_registry_sha256": targets[REGISTRY.as_posix()]["source_bytes_sha256"],
        "source_supersession_map_sha256": targets[SUPERSESSION_MAP.as_posix()]["source_bytes_sha256"],
        "target_registry_sha256": targets[REGISTRY.as_posix()]["target_bytes_sha256"],
        "target_supersession_map_sha256": targets[SUPERSESSION_MAP.as_posix()]["target_bytes_sha256"],
        "mutation_inventory_sha256": candidate["mutation_inventory_sha256"],
        "review_status": "DUAL_REVIEW_PASS",
        "go_claim": True,
        "official_write_count": 0,
        "next_builder_phase": AUTHORITY_SEAL_NEXT_PHASE,
    }
    seal["seal_payload_sha256"] = sha(canonical(seal))
    safe_output = _assert_output_safe(root.resolve(), staging_root, output)
    _exclusive_write(safe_output, canonical(seal))
    return seal


def _validate_authority_seal(
    root: Path,
    candidate_path: Path,
    seal_path: Path,
    *,
    require_source_worktree: bool,
) -> dict[str, Any]:
    authority_stage = candidate_path.parent
    candidate, candidate_file_sha256, target_bytes = _validate_authority_candidate_fresh(
        root,
        candidate_path,
        require_source_worktree=require_source_worktree,
    )
    seal_path = _require_external_plain_file(
        seal_path,
        "AUTHORITY_SEAL",
        root,
        authority_stage,
    )
    raw = seal_path.read_bytes()
    seal = strict_json_bytes(raw, "AUTHORITY_SEAL")
    if raw != canonical(seal):
        raise BuilderError("AUTHORITY_SEAL_BYTES_NOT_CANONICAL")
    targets = _authority_target_bindings(candidate)
    authority = candidate["membership_authority"]
    static_expected = {
        "schema_version": AUTHORITY_SEAL_SCHEMA,
        "authorization_id": convergence.AUTHORIZATION_ID,
        "batch_id": candidate["batch_id"],
        "evaluated_head_sha": candidate["evaluated_head_sha"],
        "evaluated_tree_sha": candidate["evaluated_tree_sha"],
        "candidate_path": candidate_path.resolve().as_posix(),
        "candidate_file_sha256": candidate_file_sha256,
        "candidate_payload_sha256": candidate["candidate_payload_sha256"],
        "membership_candidate_file_sha256": authority["candidate_file_sha256"],
        "membership_seal_file_sha256": authority["seal_file_sha256"],
        "source_registry_sha256": targets[REGISTRY.as_posix()]["source_bytes_sha256"],
        "source_supersession_map_sha256": targets[SUPERSESSION_MAP.as_posix()]["source_bytes_sha256"],
        "target_registry_sha256": targets[REGISTRY.as_posix()]["target_bytes_sha256"],
        "target_supersession_map_sha256": targets[SUPERSESSION_MAP.as_posix()]["target_bytes_sha256"],
        "mutation_inventory_sha256": candidate["mutation_inventory_sha256"],
        "review_status": "DUAL_REVIEW_PASS",
        "go_claim": True,
        "official_write_count": 0,
        "next_builder_phase": AUTHORITY_SEAL_NEXT_PHASE,
    }
    if (
        set(seal) != AUTHORITY_SEAL_FIELDS
        or any(
            type(seal.get(key)) is not type(value)
            or seal.get(key) != value
            for key, value in static_expected.items()
        )
        or type(seal.get("official_write_count")) is not int
        or not _payload_hash_valid(seal, "seal_payload_sha256")
    ):
        raise BuilderError("AUTHORITY_SEAL_CONTRACT_INVALID")
    references = seal.get("review_receipts")
    if not isinstance(references, list) or len(references) != 2:
        raise BuilderError("AUTHORITY_SEAL_REVIEW_REFS_INVALID")
    if [reference.get("review_id") for reference in references if isinstance(reference, dict)] != [
        "INDEPENDENT", "PRIMARY"
    ]:
        raise BuilderError("AUTHORITY_SEAL_REVIEW_REF_ORDER_INVALID")
    review_paths: list[Path] = []
    declared_ids: set[str] = set()
    for reference in references:
        if not isinstance(reference, dict) or set(reference) != {"path", "sha256", "review_id"}:
            raise BuilderError("AUTHORITY_SEAL_REVIEW_REF_INVALID")
        path = _require_external_plain_file(
            Path(str(reference.get("path", ""))),
            "AUTHORITY_REVIEW",
            root,
            authority_stage,
        )
        if not _exact_sha256(reference.get("sha256")):
            raise BuilderError("AUTHORITY_SEAL_REVIEW_HASH_INVALID")
        review_paths.append(path)
        declared_ids.add(str(reference.get("review_id", "")))
    review_snapshots = _validate_authority_review_set(
        candidate,
        review_paths,
        root,
        authority_stage,
    )
    reviews = [snapshot[0] for snapshot in review_snapshots]
    for reference, snapshot in zip(references, review_snapshots):
        review, _, file_sha256 = snapshot
        if (
            reference["sha256"] != file_sha256
            or reference["review_id"] != review["review_id"]
        ):
            raise BuilderError("AUTHORITY_SEAL_REVIEW_HASH_INVALID")
    if declared_ids != {str(review["review_id"]) for review in reviews}:
        raise BuilderError("AUTHORITY_SEAL_REVIEW_ID_MISMATCH")
    return {
        "candidate": candidate,
        "candidate_file_sha256": candidate_file_sha256,
        "target_bytes": target_bytes,
        "seal": seal,
        "seal_file_sha256": sha(raw),
    }


def _require_declared_authority_stage(
    root: Path,
    staging_root: Path,
    candidate_path: Path,
    seal_path: Path,
) -> Path:
    stage = _assert_external_stage(root, staging_root, "AUTHORITY_STAGING_ROOT")
    for path, label in (
        (candidate_path, "AUTHORITY_CANDIDATE"),
        (seal_path, "AUTHORITY_SEAL"),
    ):
        lexical = _lexical_absolute(path, label).resolve(strict=False)
        try:
            lexical.relative_to(stage)
        except ValueError as exc:
            raise BuilderError(f"{label}_OUTSIDE_EXPLICIT_STAGING_ROOT") from exc
    return stage


def _require_authority_source_state(root: Path, candidate: dict[str, Any]) -> None:
    targets = _authority_target_bindings(candidate)
    mismatches: list[str] = []
    for relative in (REGISTRY, SUPERSESSION_MAP):
        rendered = relative.as_posix()
        row = targets[rendered]
        payload = _require_plain_repo_file(root, relative).read_bytes()
        if (
            len(payload) != row["source_byte_count"]
            or sha(payload) != row["source_bytes_sha256"]
        ):
            mismatches.append(rendered)
    if mismatches:
        raise BuilderError(f"AUTHORITY_SOURCE_STATE_DRIFT:{','.join(mismatches)}")


def preflight_authority_apply(
    root: Path,
    candidate_path: Path,
    seal_path: Path,
    staging_root: Path | None = None,
) -> dict[str, Any]:
    root = root.resolve()
    _require_declared_authority_stage(
        root,
        staging_root if staging_root is not None else candidate_path.parent,
        candidate_path,
        seal_path,
    )
    validated = _validate_authority_seal(
        root,
        candidate_path,
        seal_path,
        require_source_worktree=True,
    )
    candidate = validated["candidate"]
    # Re-read the two source files after the full seal/review validation.  This
    # narrows the validation-to-apply window and makes a repeated preflight on
    # an already-applied (or partially-applied) worktree fail closed.
    _require_authority_source_state(root, candidate)
    return {
        "status": "PASS",
        "preflight_status": "EXACT_TWO_FILE_SOURCE_STATE_VERIFIED",
        "batch_id": candidate["batch_id"],
        "evaluated_head_sha": candidate["evaluated_head_sha"],
        "evaluated_tree_sha": candidate["evaluated_tree_sha"],
        "candidate_payload_sha256": candidate["candidate_payload_sha256"],
        "seal_payload_sha256": validated["seal"]["seal_payload_sha256"],
        "target_file_count": 2,
        "official_write_count": 0,
    }


def verify_authority_applied(
    root: Path,
    candidate_path: Path,
    seal_path: Path,
    staging_root: Path | None = None,
) -> dict[str, Any]:
    root = root.resolve()
    _require_declared_authority_stage(
        root,
        staging_root if staging_root is not None else candidate_path.parent,
        candidate_path,
        seal_path,
    )
    validated = _validate_authority_seal(
        root,
        candidate_path,
        seal_path,
        require_source_worktree=False,
    )
    mismatches: list[str] = []
    for rendered, expected in validated["target_bytes"].items():
        relative = Path(rendered)
        path = _require_plain_repo_file(root, relative)
        if path.read_bytes() != expected:
            mismatches.append(rendered)
    if mismatches:
        raise BuilderError(f"AUTHORITY_TARGET_NOT_APPLIED:{','.join(mismatches)}")
    candidate = validated["candidate"]
    # Applied worktree bytes are expected to differ from HEAD, but the index is
    # not: the task-owned writer is an unstaged two-file patch.  Recheck this at
    # the end of verification so index-only drift cannot hide behind target
    # byte parity.
    for relative in (REGISTRY, SUPERSESSION_MAP):
        _require_authority_index_parity(
            root, candidate["evaluated_head_sha"], relative
        )
    return {
        "status": "PASS",
        "verification_status": "EXACT_TWO_FILE_TARGET_STATE_VERIFIED",
        "batch_id": candidate["batch_id"],
        "evaluated_head_sha": candidate["evaluated_head_sha"],
        "evaluated_tree_sha": candidate["evaluated_tree_sha"],
        "candidate_payload_sha256": candidate["candidate_payload_sha256"],
        "seal_payload_sha256": validated["seal"]["seal_payload_sha256"],
        "verified_file_count": 2,
    }


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
    authority_candidate = sub.add_parser("build-authority-candidate")
    authority_candidate.add_argument("--membership-candidate", type=Path, required=True)
    authority_candidate.add_argument("--membership-seal", type=Path, required=True)
    authority_candidate.add_argument("--staging-root", type=Path, required=True)
    authority_candidate.add_argument("--output", type=Path, required=True)
    authority_seal = sub.add_parser("seal-authority")
    authority_seal.add_argument("--candidate", type=Path, required=True)
    authority_seal.add_argument("--review", type=Path, action="append", required=True)
    authority_seal.add_argument("--staging-root", type=Path, required=True)
    authority_seal.add_argument("--output", type=Path, required=True)
    authority_preflight = sub.add_parser("preflight-authority-apply")
    authority_preflight.add_argument("--candidate", type=Path, required=True)
    authority_preflight.add_argument("--seal", type=Path, required=True)
    authority_preflight.add_argument("--staging-root", type=Path, required=True)
    authority_verify = sub.add_parser("verify-authority-applied")
    authority_verify.add_argument("--candidate", type=Path, required=True)
    authority_verify.add_argument("--seal", type=Path, required=True)
    authority_verify.add_argument("--staging-root", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == "plan":
            result = derive_plan(args.project, args.head_ref)
        elif args.command == "build-candidate":
            result = build_candidate(args.project, args.batch_id, args.staging_root, args.output, args.head_ref)
        elif args.command == "seal":
            result = seal_candidate(args.project, args.candidate, args.review, args.staging_root, args.output)
        elif args.command == "build-authority-candidate":
            result = build_authority_candidate(
                args.project,
                args.membership_candidate,
                args.membership_seal,
                args.staging_root,
                args.output,
                args.head_ref,
            )
        elif args.command == "seal-authority":
            result = seal_authority_candidate(
                args.project,
                args.candidate,
                args.review,
                args.staging_root,
                args.output,
            )
        elif args.command == "preflight-authority-apply":
            result = preflight_authority_apply(
                args.project,
                args.candidate,
                args.seal,
                args.staging_root,
            )
        elif args.command == "verify-authority-applied":
            result = verify_authority_applied(
                args.project,
                args.candidate,
                args.seal,
                args.staging_root,
            )
        else:
            raise BuilderError("COMMAND_UNREACHABLE")
    except BuilderError as exc:
        print(json.dumps({"status": "FAIL", "failure": str(exc)}, sort_keys=True))
        return 1
    print(json.dumps({"status": "PASS", "result": result}, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
