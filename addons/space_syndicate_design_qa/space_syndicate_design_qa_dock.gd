@tool
extends PanelContainer
class_name SpaceSyndicateDesignQADock

signal open_preview_requested(scene_path: String)
signal run_preview_requested(scene_path: String)
signal open_capture_bench_requested(scene_path: String)
signal run_capture_bench_requested(scene_path: String)
signal open_interaction_bench_requested(scene_path: String)
signal run_interaction_bench_requested(scene_path: String)
signal open_mcp_editability_hub_requested(scene_path: String)
signal run_mcp_editability_hub_requested(scene_path: String)
signal open_player_turn_preview_requested(scene_path: String)
signal run_player_turn_preview_requested(scene_path: String)
signal open_player_turn_interaction_bench_requested(scene_path: String)
signal run_player_turn_interaction_bench_requested(scene_path: String)
signal open_runtime_player_flow_bench_requested(scene_path: String)
signal run_runtime_player_flow_bench_requested(scene_path: String)
signal open_first_playable_loop_bench_requested(scene_path: String)
signal run_first_playable_loop_bench_requested(scene_path: String)
signal open_first_round_runtime_playable_loop_bench_requested(scene_path: String)
signal run_first_round_runtime_playable_loop_bench_requested(scene_path: String)
signal open_first_mission_spine_bench_requested(scene_path: String)
signal run_first_mission_spine_bench_requested(scene_path: String)
signal open_first_mission_runtime_main_bench_requested(scene_path: String)
signal run_first_mission_runtime_main_bench_requested(scene_path: String)
signal open_planet_map_preview_requested(scene_path: String)
signal run_planet_map_preview_requested(scene_path: String)
signal open_planet_map_view_requested(scene_path: String)
signal open_planet_district_node_requested(scene_path: String)
signal open_planet_district_polygon_requested(scene_path: String)
signal open_planet_monster_token_requested(scene_path: String)
signal open_planet_route_marker_requested(scene_path: String)
signal open_planet_route_segment_requested(scene_path: String)
signal open_planet_movement_trail_requested(scene_path: String)
signal open_planet_map_event_effect_requested(scene_path: String)
signal open_planet_action_callout_requested(scene_path: String)
signal open_planet_globe_backdrop_requested(scene_path: String)
signal open_planet_orbit_guide_requested(scene_path: String)
signal open_planet_focus_range_overlay_requested(scene_path: String)
signal open_planet_scale_hint_requested(scene_path: String)
signal open_planet_render_cutover_bench_requested(scene_path: String)
signal run_planet_render_cutover_bench_requested(scene_path: String)
signal open_planet_interaction_bench_requested(scene_path: String)
signal run_planet_interaction_bench_requested(scene_path: String)
signal open_sceneization_audit_requested(scene_path: String)
signal run_sceneization_audit_requested(scene_path: String)
signal open_card_track_preview_requested(scene_path: String)
signal run_card_track_preview_requested(scene_path: String)
signal open_card_track_slot_requested(scene_path: String)
signal open_card_resolution_track_requested(scene_path: String)
signal open_card_resolution_track_slot_requested(scene_path: String)
signal open_card_resolution_track_preview_requested(scene_path: String)
signal run_card_resolution_track_preview_requested(scene_path: String)
signal open_card_resolution_track_interaction_bench_requested(scene_path: String)
signal run_card_resolution_track_interaction_bench_requested(scene_path: String)
signal open_runtime_card_resolution_track_flow_bench_requested(scene_path: String)
signal run_runtime_card_resolution_track_flow_bench_requested(scene_path: String)
signal open_compendium_codex_preview_requested(scene_path: String)
signal run_compendium_codex_preview_requested(scene_path: String)
signal open_compendium_codex_interaction_bench_requested(scene_path: String)
signal run_compendium_codex_interaction_bench_requested(scene_path: String)
signal open_compendium_content_registry_preview_requested(scene_path: String)
signal run_compendium_content_registry_bench_requested(scene_path: String)
signal open_system_resourceization_audit_requested(scene_path: String)
signal run_system_resourceization_audit_requested(scene_path: String)
signal open_balance_parameter_resource_preview_requested(scene_path: String)
signal run_balance_parameter_resource_bench_requested(scene_path: String)
signal open_balance_model_resource_sandbox_requested(scene_path: String)
signal run_balance_model_resource_sandbox_bench_requested(scene_path: String)
signal open_balance_runtime_bridge_requested(scene_path: String)
signal run_balance_runtime_bridge_bench_requested(scene_path: String)
signal open_gameplay_balance_diagnostics_service_requested(scene_path: String)
signal open_gameplay_balance_diagnostics_world_bridge_requested(scene_path: String)
signal open_ruleset_runtime_bridge_requested(scene_path: String)
signal run_ruleset_v04_conformance_bench_requested(scene_path: String)
signal open_city_development_runtime_controller_requested(scene_path: String)
signal open_city_development_world_bridge_requested(scene_path: String)
signal open_game_runtime_coordinator_requested(scene_path: String)
signal open_forced_decision_runtime_scheduler_requested(scene_path: String)
signal run_forced_decision_runtime_scheduler_bench_requested(scene_path: String)
signal open_game_session_runtime_controller_requested(scene_path: String)
signal open_game_save_runtime_coordinator_requested(scene_path: String)
signal run_game_session_save_ownership_bench_requested(scene_path: String)
signal open_district_purchase_runtime_controller_requested(scene_path: String)
signal open_district_purchase_settlement_runtime_service_requested(scene_path: String)
signal open_district_supply_drawer_requested(scene_path: String)
signal open_district_supply_snapshot_service_requested(scene_path: String)
signal run_district_purchase_runtime_cutover_bench_requested(scene_path: String)
signal open_card_inventory_runtime_service_requested(scene_path: String)
signal open_card_inventory_runtime_characterization_bench_requested(scene_path: String)
signal run_card_inventory_runtime_characterization_bench_requested(scene_path: String)
signal open_player_hand_interaction_runtime_service_requested(scene_path: String)
signal open_player_hand_interaction_runtime_characterization_bench_requested(scene_path: String)
signal run_player_hand_interaction_runtime_characterization_bench_requested(scene_path: String)
signal open_card_resolution_queue_runtime_service_requested(scene_path: String)
signal open_card_resolution_queue_runtime_characterization_bench_requested(scene_path: String)
signal run_card_resolution_queue_runtime_characterization_bench_requested(scene_path: String)
signal open_card_resolution_execution_runtime_service_requested(scene_path: String)
signal open_card_resolution_execution_runtime_characterization_bench_requested(scene_path: String)
signal run_card_resolution_execution_runtime_characterization_bench_requested(scene_path: String)
signal open_card_economy_product_route_effect_runtime_service_requested(scene_path: String)
signal open_card_economy_product_route_formula_runtime_service_requested(scene_path: String)
signal open_economy_cashflow_runtime_controller_requested(scene_path: String)
signal run_economy_cashflow_runtime_cutover_bench_requested(scene_path: String)
signal open_gdp_formula_runtime_controller_requested(scene_path: String)
signal run_gdp_formula_runtime_cutover_bench_requested(scene_path: String)
signal open_scenario_runtime_controller_requested(scene_path: String)
signal run_scenario_runtime_glue_cutover_bench_requested(scene_path: String)
signal open_first_table_authored_runtime_service_requested(scene_path: String)
signal run_first_table_authored_runtime_cutover_bench_requested(scene_path: String)
signal open_sceneized_main_requested(scene_path: String)
signal run_legacy_runtime_surface_retirement_bench_requested(scene_path: String)
signal open_legacy_player_surface_retirement_bench_requested(scene_path: String)
signal run_legacy_player_surface_retirement_bench_requested(scene_path: String)
signal open_card_presentation_runtime_service_requested(scene_path: String)
signal open_game_table_viewmodel_runtime_service_requested(scene_path: String)
signal open_card_play_eligibility_runtime_service_requested(scene_path: String)
signal open_card_play_eligibility_world_bridge_requested(scene_path: String)
signal open_card_play_eligibility_runtime_bench_requested(scene_path: String)
signal run_card_play_eligibility_runtime_bench_requested(scene_path: String)
signal open_menu_shell_runtime_cutover_bench_requested(scene_path: String)
signal run_menu_shell_runtime_cutover_bench_requested(scene_path: String)
signal open_codex_scene_hard_cutover_bench_requested(scene_path: String)
signal run_codex_scene_hard_cutover_bench_requested(scene_path: String)
signal open_codex_atlas_scene_cutover_bench_requested(scene_path: String)
signal run_codex_atlas_scene_cutover_bench_requested(scene_path: String)
signal open_codex_navigation_runtime_controller_requested(scene_path: String)
signal run_codex_navigation_runtime_cutover_bench_requested(scene_path: String)
signal open_codex_public_snapshot_service_requested(scene_path: String)
signal run_codex_public_snapshot_cutover_bench_requested(scene_path: String)
signal open_monster_codex_public_snapshot_service_requested(scene_path: String)
signal run_monster_codex_public_snapshot_cutover_bench_requested(scene_path: String)
signal open_monster_runtime_controller_requested(scene_path: String)
signal open_monster_runtime_world_bridge_requested(scene_path: String)
signal open_monster_runtime_characterization_bench_requested(scene_path: String)
signal run_monster_runtime_characterization_bench_requested(scene_path: String)
signal open_military_runtime_controller_requested(scene_path: String)
signal open_military_runtime_world_bridge_requested(scene_path: String)
signal open_military_runtime_characterization_bench_requested(scene_path: String)
signal run_military_runtime_characterization_bench_requested(scene_path: String)
signal open_weather_runtime_controller_requested(scene_path: String)
signal open_weather_runtime_world_bridge_requested(scene_path: String)
signal open_weather_runtime_characterization_bench_requested(scene_path: String)
signal run_weather_runtime_characterization_bench_requested(scene_path: String)
signal open_contract_runtime_controller_requested(scene_path: String)
signal open_contract_runtime_world_bridge_requested(scene_path: String)
signal open_contract_runtime_characterization_bench_requested(scene_path: String)
signal run_contract_runtime_characterization_bench_requested(scene_path: String)
signal open_product_market_runtime_characterization_bench_requested(scene_path: String)
signal run_product_market_runtime_characterization_bench_requested(scene_path: String)
signal open_product_futures_terms_catalog_requested(resource_path: String)
signal open_city_trade_network_runtime_controller_requested(scene_path: String)
signal open_city_trade_network_world_bridge_requested(scene_path: String)
signal open_city_trade_network_runtime_characterization_bench_requested(scene_path: String)
signal run_city_trade_network_runtime_characterization_bench_requested(scene_path: String)
signal open_city_development_settlement_characterization_bench_requested(scene_path: String)
signal run_city_development_settlement_characterization_bench_requested(scene_path: String)
signal open_city_gdp_derivative_runtime_controller_requested(scene_path: String)
signal open_city_gdp_derivative_runtime_world_bridge_requested(scene_path: String)
signal open_city_gdp_derivative_runtime_bench_requested(scene_path: String)
signal run_city_gdp_derivative_runtime_bench_requested(scene_path: String)
signal open_city_gdp_derivative_terms_catalog_requested(resource_path: String)
signal open_product_codex_public_snapshot_service_requested(scene_path: String)
signal run_product_codex_public_snapshot_cutover_bench_requested(scene_path: String)
signal open_card_codex_public_snapshot_service_requested(scene_path: String)
signal run_card_codex_public_snapshot_cutover_bench_requested(scene_path: String)
signal open_runtime_card_catalog_requested(resource_path: String)
signal open_runtime_card_catalog_service_requested(scene_path: String)
signal run_runtime_card_catalog_resource_bench_requested(scene_path: String)
signal open_runtime_card_authoring_workspace_requested(scene_path: String)
signal open_runtime_card_authoring_sample_family_requested(resource_path: String)
signal run_runtime_card_authoring_workflow_bench_requested(scene_path: String)
signal open_economy_dashboard_public_snapshot_service_requested(scene_path: String)
signal run_economy_dashboard_public_snapshot_cutover_bench_requested(scene_path: String)
signal open_standings_public_snapshot_service_requested(scene_path: String)
signal run_standings_public_snapshot_cutover_bench_requested(scene_path: String)
signal open_final_settlement_public_snapshot_service_requested(scene_path: String)
signal run_final_settlement_public_snapshot_cutover_bench_requested(scene_path: String)
signal open_intel_dossier_public_snapshot_service_requested(scene_path: String)
signal run_intel_dossier_public_snapshot_cutover_bench_requested(scene_path: String)
signal open_new_game_setup_page_requested(scene_path: String)
signal run_new_game_setup_page_cutover_bench_requested(scene_path: String)
signal open_ai_policy_resource_preview_requested(scene_path: String)
signal run_ai_policy_resource_bench_requested(scene_path: String)
signal open_ai_runtime_controller_requested(scene_path: String)
signal open_ai_runtime_world_bridge_requested(scene_path: String)

const PREVIEW_SCENE_PATH := "res://scenes/ui/TemporaryDecisionOverlayPreview.tscn"
const CAPTURE_BENCH_SCENE_PATH := "res://scenes/ui/TemporaryDecisionOverlayCaptureBench.tscn"
const INTERACTION_BENCH_SCENE_PATH := "res://scenes/ui/TemporaryDecisionOverlayInteractionBench.tscn"
const MCP_EDITABILITY_HUB_SCENE_PATH := "res://scenes/tools/SpaceSyndicateMcpEditabilityHub.tscn"
const PLAYER_TURN_PREVIEW_SCENE_PATH := "res://scenes/tools/PlayerTurnMcpPreview.tscn"
const PLAYER_TURN_INTERACTION_BENCH_SCENE_PATH := "res://scenes/tools/PlayerTurnInteractionBench.tscn"
const RUNTIME_PLAYER_FLOW_BENCH_SCENE_PATH := "res://scenes/tools/RuntimePlayerTurnFlowBench.tscn"
const FIRST_PLAYABLE_LOOP_BENCH_SCENE_PATH := "res://scenes/tools/FirstPlayableLoopBench.tscn"
const FIRST_ROUND_RUNTIME_PLAYABLE_LOOP_BENCH_SCENE_PATH := "res://scenes/tools/FirstRoundRuntimePlayableLoopBench.tscn"
const FIRST_MISSION_SPINE_BENCH_SCENE_PATH := "res://scenes/tools/FirstMissionSpineBench.tscn"
const FIRST_MISSION_RUNTIME_MAIN_BENCH_SCENE_PATH := "res://scenes/tools/FirstMissionRuntimeMainBench.tscn"
const PLANET_MAP_PREVIEW_SCENE_PATH := "res://scenes/tools/PlanetMapMcpPreview.tscn"
const PLANET_MAP_VIEW_SCENE_PATH := "res://scenes/ui/PlanetMapView.tscn"
const PLANET_DISTRICT_NODE_SCENE_PATH := "res://scenes/ui/map/PlanetDistrictNode.tscn"
const PLANET_DISTRICT_POLYGON_SCENE_PATH := "res://scenes/ui/map/PlanetDistrictPolygon.tscn"
const PLANET_MONSTER_TOKEN_SCENE_PATH := "res://scenes/ui/map/PlanetMonsterToken.tscn"
const PLANET_ROUTE_MARKER_SCENE_PATH := "res://scenes/ui/map/PlanetRouteMarker.tscn"
const PLANET_ROUTE_SEGMENT_SCENE_PATH := "res://scenes/ui/map/PlanetRouteSegment.tscn"
const PLANET_MOVEMENT_TRAIL_SCENE_PATH := "res://scenes/ui/map/PlanetMovementTrail.tscn"
const PLANET_MAP_EVENT_EFFECT_SCENE_PATH := "res://scenes/ui/map/PlanetMapEventEffect.tscn"
const PLANET_ACTION_CALLOUT_SCENE_PATH := "res://scenes/ui/map/PlanetActionCallout.tscn"
const PLANET_GLOBE_BACKDROP_SCENE_PATH := "res://scenes/ui/map/PlanetGlobeBackdrop.tscn"
const PLANET_ORBIT_GUIDE_SCENE_PATH := "res://scenes/ui/map/PlanetOrbitGuide.tscn"
const PLANET_FOCUS_RANGE_OVERLAY_SCENE_PATH := "res://scenes/ui/map/PlanetFocusRangeOverlay.tscn"
const PLANET_SCALE_HINT_SCENE_PATH := "res://scenes/ui/map/PlanetMapScaleHint.tscn"
const PLANET_MAP_RENDER_CUTOVER_BENCH_SCENE_PATH := "res://scenes/tools/PlanetMapRenderCutoverBench.tscn"
const PLANET_MAP_INTERACTION_BENCH_SCENE_PATH := "res://scenes/tools/PlanetMapInteractionBench.tscn"
const SCENEIZATION_AUDIT_PREVIEW_SCENE_PATH := "res://scenes/tools/SceneizationAuditMcpPreview.tscn"
const CARD_TRACK_PREVIEW_SCENE_PATH := "res://scenes/tools/CardTrackMcpPreview.tscn"
const CARD_TRACK_SLOT_SCENE_PATH := "res://scenes/ui/CardTrackSlot.tscn"
const CARD_RESOLUTION_TRACK_SCENE_PATH := "res://scenes/ui/CardResolutionTrack.tscn"
const CARD_RESOLUTION_TRACK_SLOT_SCENE_PATH := "res://scenes/ui/CardResolutionTrackSlot.tscn"
const CARD_RESOLUTION_TRACK_PREVIEW_SCENE_PATH := "res://scenes/tools/CardResolutionTrackMcpPreview.tscn"
const CARD_RESOLUTION_TRACK_INTERACTION_BENCH_SCENE_PATH := "res://scenes/tools/CardResolutionTrackInteractionBench.tscn"
const RUNTIME_CARD_RESOLUTION_TRACK_FLOW_BENCH_SCENE_PATH := "res://scenes/tools/RuntimeCardResolutionTrackFlowBench.tscn"
const COMPENDIUM_CODEX_PREVIEW_SCENE_PATH := "res://scenes/tools/CompendiumCodexMcpPreview.tscn"
const COMPENDIUM_CODEX_INTERACTION_BENCH_SCENE_PATH := "res://scenes/tools/CompendiumCodexInteractionBench.tscn"
const COMPENDIUM_CONTENT_REGISTRY_PREVIEW_SCENE_PATH := "res://scenes/tools/CompendiumContentRegistryMcpPreview.tscn"
const COMPENDIUM_CONTENT_REGISTRY_BENCH_SCENE_PATH := "res://scenes/tools/CompendiumContentRegistryBench.tscn"
const SYSTEM_RESOURCEIZATION_AUDIT_PREVIEW_SCENE_PATH := "res://scenes/tools/SystemResourceizationAuditMcpPreview.tscn"
const SYSTEM_RESOURCEIZATION_AUDIT_BENCH_SCENE_PATH := "res://scenes/tools/SystemResourceizationAuditBench.tscn"
const BALANCE_PARAMETER_RESOURCE_PREVIEW_SCENE_PATH := "res://scenes/tools/BalanceParameterResourceMcpPreview.tscn"
const BALANCE_PARAMETER_RESOURCE_BENCH_SCENE_PATH := "res://scenes/tools/BalanceParameterResourceBench.tscn"
const BALANCE_MODEL_RESOURCE_SANDBOX_SCENE_PATH := "res://scenes/tools/BalanceModelResourceSandbox.tscn"
const BALANCE_MODEL_RESOURCE_SANDBOX_BENCH_SCENE_PATH := "res://scenes/tools/BalanceModelResourceSandboxBench.tscn"
const BALANCE_RUNTIME_BRIDGE_PREVIEW_SCENE_PATH := "res://scenes/tools/BalanceRuntimeBridgeMcpPreview.tscn"
const BALANCE_RUNTIME_BRIDGE_BENCH_SCENE_PATH := "res://scenes/tools/BalanceRuntimeBridgeBench.tscn"
const GAMEPLAY_BALANCE_DIAGNOSTICS_SERVICE_SCENE_PATH := "res://scenes/runtime/GameplayBalanceDiagnosticsRuntimeService.tscn"
const GAMEPLAY_BALANCE_DIAGNOSTICS_WORLD_BRIDGE_SCENE_PATH := "res://scenes/runtime/GameplayBalanceDiagnosticsWorldBridge.tscn"
const RULESET_RUNTIME_BRIDGE_SCENE_PATH := "res://scenes/runtime/RulesetRuntimeBridge.tscn"
const RULESET_V04_CONFORMANCE_BENCH_SCENE_PATH := "res://scenes/tools/RulesetV04ConformanceBench.tscn"
const CITY_DEVELOPMENT_RUNTIME_CONTROLLER_SCENE_PATH := "res://scenes/runtime/CityDevelopmentRuntimeController.tscn"
const CITY_DEVELOPMENT_WORLD_BRIDGE_SCENE_PATH := "res://scenes/runtime/CityDevelopmentWorldBridge.tscn"
const GAME_RUNTIME_COORDINATOR_SCENE_PATH := "res://scenes/runtime/GameRuntimeCoordinator.tscn"
const FORCED_DECISION_RUNTIME_SCHEDULER_SCENE_PATH := "res://scenes/runtime/ForcedDecisionRuntimeScheduler.tscn"
const FORCED_DECISION_RUNTIME_SCHEDULER_BENCH_SCENE_PATH := "res://scenes/tools/ForcedDecisionRuntimeSchedulerBench.tscn"
const GAME_SESSION_RUNTIME_CONTROLLER_SCENE_PATH := "res://scenes/runtime/GameSessionRuntimeController.tscn"
const GAME_SAVE_RUNTIME_COORDINATOR_SCENE_PATH := "res://scenes/runtime/GameSaveRuntimeCoordinator.tscn"
const GAME_SESSION_SAVE_OWNERSHIP_BENCH_SCENE_PATH := "res://scenes/tools/GameSessionSaveOwnershipBench.tscn"
const DISTRICT_PURCHASE_RUNTIME_CONTROLLER_SCENE_PATH := "res://scenes/runtime/DistrictPurchaseRuntimeController.tscn"
const DISTRICT_PURCHASE_SETTLEMENT_RUNTIME_SERVICE_SCENE_PATH := "res://scenes/runtime/DistrictPurchaseSettlementRuntimeService.tscn"
const DISTRICT_SUPPLY_DRAWER_SCENE_PATH := "res://scenes/ui/DistrictSupplyDrawer.tscn"
const DISTRICT_SUPPLY_SNAPSHOT_SERVICE_SCENE_PATH := "res://scenes/runtime/DistrictSupplySnapshotService.tscn"
const DISTRICT_PURCHASE_RUNTIME_CUTOVER_BENCH_SCENE_PATH := "res://scenes/tools/DistrictPurchaseRuntimeCutoverBench.tscn"
const CARD_INVENTORY_RUNTIME_SERVICE_SCENE_PATH := "res://scenes/runtime/CardInventoryRuntimeService.tscn"
const CARD_INVENTORY_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH := "res://scenes/tools/CardInventoryRuntimeCharacterizationBench.tscn"
const PLAYER_HAND_INTERACTION_RUNTIME_SERVICE_SCENE_PATH := "res://scenes/runtime/PlayerHandInteractionRuntimeService.tscn"
const PLAYER_HAND_INTERACTION_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH := "res://scenes/tools/PlayerHandInteractionRuntimeCharacterizationBench.tscn"
const CARD_RESOLUTION_QUEUE_RUNTIME_SERVICE_SCENE_PATH := "res://scenes/runtime/CardResolutionQueueRuntimeService.tscn"
const CARD_RESOLUTION_QUEUE_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH := "res://scenes/tools/CardResolutionQueueRuntimeCharacterizationBench.tscn"
const CARD_RESOLUTION_EXECUTION_RUNTIME_SERVICE_SCENE_PATH := "res://scenes/runtime/CardResolutionExecutionRuntimeService.tscn"
const CARD_RESOLUTION_EXECUTION_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH := "res://scenes/tools/CardResolutionExecutionRuntimeCharacterizationBench.tscn"
const CARD_ECONOMY_PRODUCT_ROUTE_EFFECT_RUNTIME_SERVICE_SCENE_PATH := "res://scenes/runtime/CardEconomyProductRouteEffectRuntimeService.tscn"
const CARD_ECONOMY_PRODUCT_ROUTE_FORMULA_RUNTIME_SERVICE_SCENE_PATH := "res://scenes/runtime/CardEconomyProductRouteFormulaRuntimeService.tscn"
const ECONOMY_CASHFLOW_RUNTIME_CONTROLLER_SCENE_PATH := "res://scenes/runtime/EconomyCashflowRuntimeController.tscn"
const ECONOMY_CASHFLOW_RUNTIME_CUTOVER_BENCH_SCENE_PATH := "res://scenes/tools/EconomyCashflowRuntimeCutoverBench.tscn"
const GDP_FORMULA_RUNTIME_CONTROLLER_SCENE_PATH := "res://scenes/runtime/GdpFormulaRuntimeController.tscn"
const GDP_FORMULA_RUNTIME_CUTOVER_BENCH_SCENE_PATH := "res://scenes/tools/GdpFormulaRuntimeCutoverBench.tscn"
const SCENARIO_RUNTIME_CONTROLLER_SCENE_PATH := "res://scenes/runtime/ScenarioRuntimeController.tscn"
const SCENARIO_RUNTIME_GLUE_CUTOVER_BENCH_SCENE_PATH := "res://scenes/tools/ScenarioRuntimeGlueCutoverBench.tscn"
const FIRST_TABLE_AUTHORED_RUNTIME_SERVICE_SCENE_PATH := "res://scenes/runtime/FirstTableAuthoredRuntimeService.tscn"
const FIRST_TABLE_AUTHORED_RUNTIME_CUTOVER_BENCH_SCENE_PATH := "res://scenes/tools/FirstTableAuthoredRuntimeCutoverBench.tscn"
const SCENEIZED_MAIN_SCENE_PATH := "res://scenes/main.tscn"
const LEGACY_RUNTIME_SURFACE_RETIREMENT_BENCH_SCENE_PATH := "res://scenes/tools/LegacyRuntimeSurfaceRetirementBench.tscn"
const LEGACY_PLAYER_SURFACE_RETIREMENT_BENCH_SCENE_PATH := "res://scenes/tools/LegacyPlayerSurfaceRetirementBench.tscn"
const CARD_PRESENTATION_RUNTIME_SERVICE_SCENE_PATH := "res://scenes/runtime/CardPresentationRuntimeService.tscn"
const GAME_TABLE_VIEWMODEL_RUNTIME_SERVICE_SCENE_PATH := "res://scenes/runtime/GameTableViewModelRuntimeService.tscn"
const CARD_PLAY_ELIGIBILITY_RUNTIME_SERVICE_SCENE_PATH := "res://scenes/runtime/CardPlayEligibilityRuntimeService.tscn"
const CARD_PLAY_ELIGIBILITY_WORLD_BRIDGE_SCENE_PATH := "res://scenes/runtime/CardPlayEligibilityWorldBridge.tscn"
const CARD_PLAY_ELIGIBILITY_RUNTIME_BENCH_SCENE_PATH := "res://scenes/tools/CardPlayEligibilityRuntimeBench.tscn"
const MENU_SHELL_RUNTIME_CUTOVER_BENCH_SCENE_PATH := "res://scenes/tools/MenuShellRuntimeCutoverBench.tscn"
const CODEX_SCENE_HARD_CUTOVER_BENCH_SCENE_PATH := "res://scenes/tools/CodexSceneHardCutoverBench.tscn"
const CODEX_ATLAS_SCENE_CUTOVER_BENCH_SCENE_PATH := "res://scenes/tools/CodexAtlasSceneCutoverBench.tscn"
const CODEX_NAVIGATION_RUNTIME_CONTROLLER_SCENE_PATH := "res://scenes/runtime/CodexNavigationRuntimeController.tscn"
const CODEX_NAVIGATION_RUNTIME_CUTOVER_BENCH_SCENE_PATH := "res://scenes/tools/CodexNavigationRuntimeCutoverBench.tscn"
const CODEX_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH := "res://scenes/runtime/CodexPublicSnapshotService.tscn"
const CODEX_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH := "res://scenes/tools/CodexPublicSnapshotCutoverBench.tscn"
const MONSTER_CODEX_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH := "res://scenes/runtime/MonsterCodexPublicSnapshotService.tscn"
const MONSTER_CODEX_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH := "res://scenes/tools/MonsterCodexPublicSnapshotCutoverBench.tscn"
const MONSTER_RUNTIME_CONTROLLER_SCENE_PATH := "res://scenes/runtime/MonsterRuntimeController.tscn"
const MONSTER_RUNTIME_WORLD_BRIDGE_SCENE_PATH := "res://scenes/runtime/MonsterRuntimeWorldBridge.tscn"
const MONSTER_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH := "res://scenes/tools/MonsterRuntimeCharacterizationBench.tscn"
const MILITARY_RUNTIME_CONTROLLER_SCENE_PATH := "res://scenes/runtime/MilitaryRuntimeController.tscn"
const MILITARY_RUNTIME_WORLD_BRIDGE_SCENE_PATH := "res://scenes/runtime/MilitaryRuntimeWorldBridge.tscn"
const MILITARY_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH := "res://scenes/tools/MilitaryRuntimeCharacterizationBench.tscn"
const WEATHER_RUNTIME_CONTROLLER_SCENE_PATH := "res://scenes/runtime/WeatherRuntimeController.tscn"
const WEATHER_RUNTIME_WORLD_BRIDGE_SCENE_PATH := "res://scenes/runtime/WeatherRuntimeWorldBridge.tscn"
const WEATHER_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH := "res://scenes/tools/WeatherRuntimeCharacterizationBench.tscn"
const CONTRACT_RUNTIME_CONTROLLER_SCENE_PATH := "res://scenes/runtime/ContractRuntimeController.tscn"
const CONTRACT_RUNTIME_WORLD_BRIDGE_SCENE_PATH := "res://scenes/runtime/ContractRuntimeWorldBridge.tscn"
const CONTRACT_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH := "res://scenes/tools/ContractRuntimeCharacterizationBench.tscn"
const PRODUCT_MARKET_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH := "res://scenes/tools/ProductMarketRuntimeCharacterizationBench.tscn"
const PRODUCT_FUTURES_TERMS_CATALOG_PATH := "res://resources/finance/product_futures/product_futures_terms_v04_catalog.tres"
const CITY_TRADE_NETWORK_RUNTIME_CONTROLLER_SCENE_PATH := "res://scenes/runtime/CityTradeNetworkRuntimeController.tscn"
const CITY_TRADE_NETWORK_RUNTIME_WORLD_BRIDGE_SCENE_PATH := "res://scenes/runtime/CityTradeNetworkWorldBridge.tscn"
const CITY_TRADE_NETWORK_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH := "res://scenes/tools/CityTradeNetworkRuntimeCharacterizationBench.tscn"
const CITY_DEVELOPMENT_SETTLEMENT_CHARACTERIZATION_BENCH_SCENE_PATH := "res://scenes/tools/CityDevelopmentSettlementRuntimeCharacterizationBench.tscn"
const CITY_GDP_DERIVATIVE_RUNTIME_CONTROLLER_SCENE_PATH := "res://scenes/runtime/CityGdpDerivativeRuntimeController.tscn"
const CITY_GDP_DERIVATIVE_RUNTIME_WORLD_BRIDGE_SCENE_PATH := "res://scenes/runtime/CityGdpDerivativeRuntimeWorldBridge.tscn"
const CITY_GDP_DERIVATIVE_RUNTIME_BENCH_SCENE_PATH := "res://scenes/tools/CityGdpDerivativeRuntimeBench.tscn"
const CITY_GDP_DERIVATIVE_TERMS_CATALOG_PATH := "res://resources/finance/city_gdp_derivatives/city_gdp_derivative_terms_v04_catalog.tres"
const PRODUCT_CODEX_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH := "res://scenes/runtime/ProductCodexPublicSnapshotService.tscn"
const PRODUCT_CODEX_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH := "res://scenes/tools/ProductCodexPublicSnapshotCutoverBench.tscn"
const CARD_CODEX_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH := "res://scenes/runtime/CardCodexPublicSnapshotService.tscn"
const CARD_CODEX_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH := "res://scenes/tools/CardCodexPublicSnapshotCutoverBench.tscn"
const RUNTIME_CARD_CATALOG_RESOURCE_PATH := "res://resources/cards/runtime/card_runtime_catalog_v04.tres"
const RUNTIME_CARD_CATALOG_SERVICE_SCENE_PATH := "res://scenes/runtime/CardRuntimeCatalogService.tscn"
const RUNTIME_CARD_CATALOG_RESOURCE_BENCH_SCENE_PATH := "res://scenes/tools/RuntimeCardCatalogResourceBench.tscn"
const RUNTIME_CARD_AUTHORING_WORKSPACE_SCENE_PATH := "res://scenes/tools/RuntimeCardAuthoringWorkspace.tscn"
const RUNTIME_CARD_AUTHORING_WORKFLOW_BENCH_SCENE_PATH := "res://scenes/tools/RuntimeCardAuthoringWorkflowBench.tscn"
const RUNTIME_CARD_AUTHORING_SAMPLE_FAMILY_PATH := "res://resources/cards/runtime/families/001_城市融资.tres"
const ECONOMY_DASHBOARD_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH := "res://scenes/runtime/EconomyDashboardPublicSnapshotService.tscn"
const ECONOMY_DASHBOARD_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH := "res://scenes/tools/EconomyDashboardPublicSnapshotCutoverBench.tscn"
const STANDINGS_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH := "res://scenes/runtime/StandingsPublicSnapshotService.tscn"
const STANDINGS_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH := "res://scenes/tools/StandingsPublicSnapshotCutoverBench.tscn"
const FINAL_SETTLEMENT_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH := "res://scenes/runtime/FinalSettlementPublicSnapshotService.tscn"
const FINAL_SETTLEMENT_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH := "res://scenes/tools/FinalSettlementPublicSnapshotCutoverBench.tscn"
const INTEL_DOSSIER_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH := "res://scenes/runtime/IntelDossierPublicSnapshotService.tscn"
const INTEL_DOSSIER_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH := "res://scenes/tools/IntelDossierPublicSnapshotCutoverBench.tscn"
const NEW_GAME_SETUP_PAGE_SCENE_PATH := "res://scenes/ui/NewGameSetupPage.tscn"
const NEW_GAME_SETUP_PAGE_CUTOVER_BENCH_SCENE_PATH := "res://scenes/tools/NewGameSetupPageCutoverBench.tscn"
const AI_POLICY_RESOURCE_PREVIEW_SCENE_PATH := "res://scenes/tools/AiPolicyResourceMcpPreview.tscn"
const AI_POLICY_RESOURCE_BENCH_SCENE_PATH := "res://scenes/tools/AiPolicyResourceBench.tscn"
const AI_RUNTIME_CONTROLLER_SCENE_PATH := "res://scenes/runtime/AiRuntimeController.tscn"
const AI_RUNTIME_WORLD_BRIDGE_SCENE_PATH := "res://scenes/runtime/AiRuntimeWorldBridge.tscn"
const FIXTURE_SCRIPT_PATH := "res://scripts/ui/temporary_decision_preview_fixtures.gd"
const DESIGN_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/temporary_decision_overlay/"
const INTERACTION_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/temporary_decision_overlay_interactions/"
const PLAYER_TURN_INTERACTION_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/player_turn_interactions/"
const RUNTIME_PLAYER_FLOW_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/runtime_player_turn_flow/"
const FIRST_PLAYABLE_LOOP_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/first_playable_loop/"
const FIRST_ROUND_RUNTIME_PLAYABLE_LOOP_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/first_round_runtime_playable_loop/"
const FIRST_MISSION_SPINE_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/first_mission_spine/"
const FIRST_MISSION_RUNTIME_MAIN_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/first_mission_runtime_main/"
const PLANET_MAP_RENDER_CUTOVER_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/planet_map_render_cutover/"
const PLANET_MAP_INTERACTION_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/planet_map_interactions/"
const CARD_RESOLUTION_TRACK_INTERACTION_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/card_resolution_track_interactions/"
const RUNTIME_CARD_RESOLUTION_TRACK_FLOW_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/runtime_card_resolution_track_flow/"
const COMPENDIUM_CODEX_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/compendium_codex/"
const COMPENDIUM_CONTENT_REGISTRY_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/compendium_content_registry/"
const SYSTEM_RESOURCEIZATION_AUDIT_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/system_resourceization_audit/"
const BALANCE_PARAMETER_RESOURCE_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/balance_parameter_resourceization/"
const BALANCE_MODEL_RESOURCE_SANDBOX_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/balance_model_resource_sandbox/"
const BALANCE_RUNTIME_BRIDGE_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/gameplay_balance_diagnostics/"
const RULESET_V04_CONFORMANCE_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/ruleset_v04_conformance/"
const FORCED_DECISION_RUNTIME_SCHEDULER_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/forced_decision_scheduler/"
const GAME_SESSION_SAVE_OWNERSHIP_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/game_session_save_ownership/"
const DISTRICT_PURCHASE_RUNTIME_CUTOVER_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/district_purchase_runtime_cutover/"
const CARD_INVENTORY_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/card_inventory_runtime_cutover/"
const PLAYER_HAND_INTERACTION_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/player_hand_interaction_characterization/"
const CARD_RESOLUTION_QUEUE_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/card_resolution_queue_characterization/"
const CARD_RESOLUTION_EXECUTION_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/card_resolution_execution_characterization/"
const ECONOMY_CASHFLOW_RUNTIME_CUTOVER_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/economy_cashflow_runtime_cutover/"
const GDP_FORMULA_RUNTIME_CUTOVER_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/gdp_formula_runtime_cutover/"
const SCENARIO_RUNTIME_GLUE_CUTOVER_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/scenario_runtime_glue_cutover/"
const FIRST_TABLE_AUTHORED_RUNTIME_CUTOVER_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/first_table_authored_runtime_cutover/"
const LEGACY_RUNTIME_SURFACE_RETIREMENT_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/legacy_runtime_surface_retirement/"
const LEGACY_PLAYER_SURFACE_RETIREMENT_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/legacy_player_surface_retirement/"
const CARD_PLAY_ELIGIBILITY_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/card_play_eligibility/"
const MENU_SHELL_RUNTIME_CUTOVER_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/menu_shell_runtime_cutover/"
const CODEX_SCENE_HARD_CUTOVER_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/codex_scene_hard_cutover/"
const CODEX_ATLAS_SCENE_CUTOVER_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/codex_atlas_scene_cutover/"
const CODEX_NAVIGATION_RUNTIME_CUTOVER_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/codex_navigation_runtime_cutover/"
const CODEX_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/codex_public_snapshot_cutover/"
const MONSTER_CODEX_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/monster_codex_public_snapshot_cutover/"
const MONSTER_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/monster_runtime_characterization/"
const MILITARY_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/military_runtime_characterization/"
const WEATHER_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/weather_runtime_characterization/"
const CONTRACT_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/contract_runtime_characterization/"
const PRODUCT_MARKET_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/product_futures_v04_hard_alignment/"
const CITY_TRADE_NETWORK_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/city_trade_network_characterization/"
const CITY_DEVELOPMENT_SETTLEMENT_CHARACTERIZATION_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/city_development_settlement_characterization/"
const CITY_GDP_DERIVATIVE_RUNTIME_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/city_gdp_derivative_v04/"
const PRODUCT_CODEX_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/product_codex_public_snapshot_cutover/"
const CARD_CODEX_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/card_codex_public_snapshot_cutover/"
const RUNTIME_CARD_CATALOG_RESOURCE_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/runtime_card_catalog_resource/"
const RUNTIME_CARD_AUTHORING_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/runtime_card_authoring/"
const ECONOMY_DASHBOARD_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/economy_dashboard_public_snapshot_cutover/"
const STANDINGS_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/standings_public_snapshot_cutover/"
const FINAL_SETTLEMENT_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/final_settlement_public_snapshot_cutover/"
const INTEL_DOSSIER_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/intel_dossier_public_snapshot_cutover/"
const NEW_GAME_SETUP_PAGE_CUTOVER_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/new_game_setup_page_cutover/"
const AI_POLICY_RESOURCE_QA_OUTPUT_DIR := "user://space_syndicate_design_qa/ai_policy_resourceization/"
const PANEL_BY_FIXTURE_ID := {
	"monster_wager": "MonsterWagerDecisionPanel",
	"contract_response": "ContractResponseDecisionPanel",
	"discard_purchase": "TemporaryChoiceDecisionPanel",
	"monster_target_choice": "TemporaryChoiceDecisionPanel",
	"player_target_choice": "TemporaryChoiceDecisionPanel",
}

@onready var fixture_title_label: Label = %FixtureTitleLabel
@onready var fixture_summary_label: Label = %FixtureSummaryLabel
@onready var status_label: Label = %DesignQAStatusLabel
@onready var open_preview_button: Button = %OpenTemporaryDecisionPreviewButton
@onready var run_preview_button: Button = %RunTemporaryDecisionPreviewButton
@onready var open_capture_bench_button: Button = %OpenTemporaryDecisionCaptureBenchButton
@onready var run_capture_bench_button: Button = %RunTemporaryDecisionCaptureBenchButton
@onready var open_output_folder_button: Button = %OpenDesignQAOutputFolderButton
@onready var open_interaction_bench_button: Button = %OpenTemporaryDecisionInteractionBenchButton
@onready var run_interaction_bench_button: Button = %RunTemporaryDecisionInteractionBenchButton
@onready var open_interaction_output_folder_button: Button = %OpenInteractionQAOutputFolderButton
@onready var open_mcp_hub_button: Button = %OpenMcpEditabilityHubButton
@onready var run_mcp_hub_button: Button = %RunMcpEditabilityHubButton
@onready var open_player_turn_preview_button: Button = %OpenPlayerTurnPreviewButton
@onready var run_player_turn_preview_button: Button = %RunPlayerTurnPreviewButton
@onready var open_player_turn_interaction_bench_button: Button = %OpenPlayerTurnInteractionBenchButton
@onready var run_player_turn_interaction_bench_button: Button = %RunPlayerTurnInteractionBenchButton
@onready var open_player_turn_interaction_output_folder_button: Button = %OpenPlayerTurnInteractionQAOutputFolderButton
@onready var open_runtime_player_flow_bench_button: Button = %OpenRuntimePlayerFlowBenchButton
@onready var run_runtime_player_flow_bench_button: Button = %RunRuntimePlayerFlowBenchButton
@onready var open_runtime_player_flow_output_folder_button: Button = %OpenRuntimePlayerFlowOutputFolderButton
@onready var open_first_playable_loop_bench_button: Button = %OpenFirstPlayableLoopBenchButton
@onready var run_first_playable_loop_bench_button: Button = %RunFirstPlayableLoopBenchButton
@onready var open_first_playable_loop_output_folder_button: Button = %OpenFirstPlayableLoopOutputFolderButton
@onready var open_first_round_runtime_playable_loop_bench_button: Button = %OpenFirstRoundRuntimePlayableLoopBenchButton
@onready var run_first_round_runtime_playable_loop_bench_button: Button = %RunFirstRoundRuntimePlayableLoopBenchButton
@onready var open_first_round_runtime_playable_loop_output_folder_button: Button = %OpenFirstRoundRuntimePlayableLoopOutputFolderButton
@onready var open_first_mission_spine_bench_button: Button = %OpenFirstMissionSpineBenchButton
@onready var run_first_mission_spine_bench_button: Button = %RunFirstMissionSpineBenchButton
@onready var open_first_mission_spine_output_folder_button: Button = %OpenFirstMissionSpineOutputFolderButton
@onready var open_first_mission_runtime_main_bench_button: Button = %OpenFirstMissionRuntimeMainBenchButton
@onready var run_first_mission_runtime_main_bench_button: Button = %RunFirstMissionRuntimeMainBenchButton
@onready var open_first_mission_runtime_main_output_folder_button: Button = %OpenFirstMissionRuntimeMainOutputFolderButton
@onready var open_planet_map_preview_button: Button = %OpenPlanetMapPreviewButton
@onready var run_planet_map_preview_button: Button = %RunPlanetMapPreviewButton
@onready var open_planet_map_view_button: Button = %OpenPlanetMapViewButton
@onready var open_planet_district_node_button: Button = %OpenPlanetDistrictNodeButton
@onready var open_planet_district_polygon_button: Button = %OpenPlanetDistrictPolygonButton
@onready var open_planet_monster_token_button: Button = %OpenPlanetMonsterTokenButton
@onready var open_planet_route_marker_button: Button = %OpenPlanetRouteMarkerButton
@onready var open_planet_route_segment_button: Button = %OpenPlanetRouteSegmentButton
@onready var open_planet_movement_trail_button: Button = %OpenPlanetMovementTrailButton
@onready var open_planet_map_event_effect_button: Button = %OpenPlanetMapEventEffectButton
@onready var open_planet_action_callout_button: Button = %OpenPlanetActionCalloutButton
@onready var open_planet_globe_backdrop_button: Button = %OpenPlanetGlobeBackdropButton
@onready var open_planet_orbit_guide_button: Button = %OpenPlanetOrbitGuideButton
@onready var open_planet_focus_range_overlay_button: Button = %OpenPlanetFocusRangeOverlayButton
@onready var open_planet_scale_hint_button: Button = %OpenPlanetScaleHintButton
@onready var open_planet_render_cutover_bench_button: Button = %OpenPlanetRenderCutoverBenchButton
@onready var run_planet_render_cutover_bench_button: Button = %RunPlanetRenderCutoverBenchButton
@onready var open_planet_render_cutover_output_folder_button: Button = %OpenPlanetRenderCutoverOutputFolderButton
@onready var open_planet_interaction_bench_button: Button = %OpenPlanetInteractionBenchButton
@onready var run_planet_interaction_bench_button: Button = %RunPlanetInteractionBenchButton
@onready var open_planet_interaction_output_folder_button: Button = %OpenPlanetInteractionOutputFolderButton
@onready var open_sceneization_audit_button: Button = %OpenSceneizationAuditButton
@onready var run_sceneization_audit_button: Button = %RunSceneizationAuditButton
@onready var open_card_track_preview_button: Button = %OpenCardTrackPreviewButton
@onready var run_card_track_preview_button: Button = %RunCardTrackPreviewButton
@onready var open_card_track_slot_button: Button = %OpenCardTrackSlotButton
@onready var open_card_resolution_track_button: Button = %OpenCardResolutionTrackButton
@onready var open_card_resolution_track_slot_button: Button = %OpenCardResolutionTrackSlotButton
@onready var open_card_resolution_track_preview_button: Button = %OpenCardResolutionTrackPreviewButton
@onready var run_card_resolution_track_preview_button: Button = %RunCardResolutionTrackPreviewButton
@onready var open_card_resolution_track_interaction_bench_button: Button = %OpenCardResolutionTrackInteractionBenchButton
@onready var run_card_resolution_track_interaction_bench_button: Button = %RunCardResolutionTrackInteractionBenchButton
@onready var open_card_resolution_track_interaction_output_folder_button: Button = %OpenCardResolutionTrackInteractionOutputFolderButton
@onready var open_runtime_card_resolution_track_flow_bench_button: Button = %OpenRuntimeCardResolutionTrackFlowBenchButton
@onready var run_runtime_card_resolution_track_flow_bench_button: Button = %RunRuntimeCardResolutionTrackFlowBenchButton
@onready var open_runtime_card_resolution_track_flow_output_folder_button: Button = %OpenRuntimeCardResolutionTrackFlowOutputFolderButton
@onready var open_compendium_codex_preview_button: Button = %OpenCompendiumCodexPreviewButton
@onready var run_compendium_codex_preview_button: Button = %RunCompendiumCodexPreviewButton
@onready var open_compendium_codex_interaction_bench_button: Button = %OpenCompendiumCodexInteractionBenchButton
@onready var run_compendium_codex_interaction_bench_button: Button = %RunCompendiumCodexInteractionBenchButton
@onready var open_compendium_codex_output_folder_button: Button = %OpenCompendiumCodexOutputFolderButton
@onready var open_compendium_content_registry_preview_button: Button = %OpenCompendiumContentRegistryPreviewButton
@onready var run_compendium_content_registry_bench_button: Button = %RunCompendiumContentRegistryBenchButton
@onready var open_compendium_content_registry_output_folder_button: Button = %OpenCompendiumContentRegistryOutputFolderButton
@onready var open_system_resourceization_audit_button: Button = %OpenSystemResourceizationAuditButton
@onready var run_system_resourceization_audit_button: Button = %RunSystemResourceizationAuditButton
@onready var open_system_resourceization_output_folder_button: Button = %OpenSystemResourceizationOutputFolderButton
@onready var open_balance_parameter_resource_preview_button: Button = %OpenBalanceParameterResourcePreviewButton
@onready var run_balance_parameter_resource_bench_button: Button = %RunBalanceParameterResourceBenchButton
@onready var open_balance_parameter_resource_output_folder_button: Button = %OpenBalanceParameterResourceOutputFolderButton
@onready var open_balance_model_resource_sandbox_button: Button = %OpenBalanceModelResourceSandboxButton
@onready var run_balance_model_resource_sandbox_bench_button: Button = %RunBalanceModelResourceSandboxBenchButton
@onready var open_balance_model_resource_sandbox_output_folder_button: Button = %OpenBalanceModelResourceSandboxOutputFolderButton
@onready var open_balance_runtime_bridge_button: Button = %OpenBalanceRuntimeBridgeButton
@onready var run_balance_runtime_bridge_bench_button: Button = %RunBalanceRuntimeBridgeBenchButton
@onready var open_balance_runtime_bridge_output_folder_button: Button = %OpenBalanceRuntimeBridgeOutputFolderButton
@onready var open_gameplay_balance_diagnostics_service_button: Button = %OpenGameplayBalanceDiagnosticsServiceButton
@onready var open_gameplay_balance_diagnostics_world_bridge_button: Button = %OpenGameplayBalanceDiagnosticsWorldBridgeButton
@onready var open_ruleset_runtime_bridge_button: Button = %OpenRulesetRuntimeBridgeButton
@onready var run_ruleset_v04_conformance_bench_button: Button = %RunRulesetV04ConformanceBenchButton
@onready var open_ruleset_v04_conformance_output_folder_button: Button = %OpenRulesetV04ConformanceOutputFolderButton
@onready var open_city_development_runtime_controller_button: Button = %OpenCityDevelopmentRuntimeControllerButton
@onready var open_city_development_world_bridge_button: Button = %OpenCityDevelopmentWorldBridgeButton
@onready var open_game_runtime_coordinator_button: Button = %OpenGameRuntimeCoordinatorButton
@onready var open_forced_decision_runtime_scheduler_button: Button = %OpenForcedDecisionRuntimeSchedulerButton
@onready var run_forced_decision_runtime_scheduler_bench_button: Button = %RunForcedDecisionRuntimeSchedulerBenchButton
@onready var open_forced_decision_runtime_scheduler_output_folder_button: Button = %OpenForcedDecisionRuntimeSchedulerOutputFolderButton
@onready var open_game_session_runtime_controller_button: Button = %OpenGameSessionRuntimeControllerButton
@onready var open_game_save_runtime_coordinator_button: Button = %OpenGameSaveRuntimeCoordinatorButton
@onready var run_game_session_save_ownership_bench_button: Button = %RunGameSessionSaveOwnershipBenchButton
@onready var open_game_session_save_ownership_output_folder_button: Button = %OpenGameSessionSaveOwnershipOutputFolderButton
@onready var open_district_purchase_runtime_controller_button: Button = %OpenDistrictPurchaseRuntimeControllerButton
@onready var open_district_purchase_settlement_runtime_service_button: Button = %OpenDistrictPurchaseSettlementRuntimeServiceButton
@onready var open_district_supply_drawer_button: Button = %OpenDistrictSupplyDrawerButton
@onready var open_district_supply_snapshot_service_button: Button = %OpenDistrictSupplySnapshotServiceButton
@onready var run_district_purchase_runtime_cutover_bench_button: Button = %RunDistrictPurchaseRuntimeCutoverBenchButton
@onready var open_district_purchase_runtime_cutover_output_folder_button: Button = %OpenDistrictPurchaseRuntimeCutoverOutputFolderButton
@onready var open_card_inventory_runtime_service_button: Button = %OpenCardInventoryRuntimeServiceButton
@onready var open_card_inventory_runtime_characterization_bench_button: Button = %OpenCardInventoryRuntimeCharacterizationBenchButton
@onready var run_card_inventory_runtime_characterization_bench_button: Button = %RunCardInventoryRuntimeCharacterizationBenchButton
@onready var open_card_inventory_runtime_characterization_output_folder_button: Button = %OpenCardInventoryRuntimeCharacterizationOutputFolderButton
@onready var open_player_hand_interaction_runtime_service_button: Button = %OpenPlayerHandInteractionRuntimeServiceButton
@onready var open_player_hand_interaction_runtime_characterization_bench_button: Button = %OpenPlayerHandInteractionRuntimeCharacterizationBenchButton
@onready var run_player_hand_interaction_runtime_characterization_bench_button: Button = %RunPlayerHandInteractionRuntimeCharacterizationBenchButton
@onready var open_player_hand_interaction_runtime_characterization_output_folder_button: Button = %OpenPlayerHandInteractionRuntimeCharacterizationOutputFolderButton
@onready var open_card_resolution_queue_runtime_service_button: Button = %OpenCardResolutionQueueRuntimeServiceButton
@onready var open_card_resolution_queue_runtime_characterization_bench_button: Button = %OpenCardResolutionQueueRuntimeCharacterizationBenchButton
@onready var run_card_resolution_queue_runtime_characterization_bench_button: Button = %RunCardResolutionQueueRuntimeCharacterizationBenchButton
@onready var open_card_resolution_queue_runtime_characterization_output_folder_button: Button = %OpenCardResolutionQueueRuntimeCharacterizationOutputFolderButton
@onready var open_card_resolution_execution_runtime_service_button: Button = %OpenCardResolutionExecutionRuntimeServiceButton
@onready var open_card_resolution_execution_runtime_characterization_bench_button: Button = %OpenCardResolutionExecutionRuntimeCharacterizationBenchButton
@onready var run_card_resolution_execution_runtime_characterization_bench_button: Button = %RunCardResolutionExecutionRuntimeCharacterizationBenchButton
@onready var open_card_resolution_execution_runtime_characterization_output_folder_button: Button = %OpenCardResolutionExecutionRuntimeCharacterizationOutputFolderButton
@onready var open_card_economy_product_route_effect_runtime_service_button: Button = %OpenCardEconomyProductRouteEffectRuntimeServiceButton
@onready var open_card_economy_product_route_formula_runtime_service_button: Button = %OpenCardEconomyProductRouteFormulaRuntimeServiceButton
@onready var open_economy_cashflow_runtime_controller_button: Button = %OpenEconomyCashflowRuntimeControllerButton
@onready var run_economy_cashflow_runtime_cutover_bench_button: Button = %RunEconomyCashflowRuntimeCutoverBenchButton
@onready var open_economy_cashflow_runtime_cutover_output_folder_button: Button = %OpenEconomyCashflowRuntimeCutoverOutputFolderButton
@onready var open_gdp_formula_runtime_controller_button: Button = %OpenGdpFormulaRuntimeControllerButton
@onready var run_gdp_formula_runtime_cutover_bench_button: Button = %RunGdpFormulaRuntimeCutoverBenchButton
@onready var open_gdp_formula_runtime_cutover_output_folder_button: Button = %OpenGdpFormulaRuntimeCutoverOutputFolderButton
@onready var open_scenario_runtime_controller_button: Button = %OpenScenarioRuntimeControllerButton
@onready var run_scenario_runtime_glue_cutover_bench_button: Button = %RunScenarioRuntimeGlueCutoverBenchButton
@onready var open_scenario_runtime_glue_cutover_output_folder_button: Button = %OpenScenarioRuntimeGlueCutoverOutputFolderButton
@onready var open_first_table_authored_runtime_service_button: Button = %OpenFirstTableAuthoredRuntimeServiceButton
@onready var run_first_table_authored_runtime_cutover_bench_button: Button = %RunFirstTableAuthoredRuntimeCutoverBenchButton
@onready var open_first_table_authored_runtime_cutover_output_folder_button: Button = %OpenFirstTableAuthoredRuntimeCutoverOutputFolderButton
@onready var open_sceneized_main_button: Button = %OpenSceneizedMainButton
@onready var run_legacy_runtime_surface_retirement_bench_button: Button = %RunLegacyRuntimeSurfaceRetirementBenchButton
@onready var open_legacy_runtime_surface_retirement_output_folder_button: Button = %OpenLegacyRuntimeSurfaceRetirementOutputFolderButton
@onready var open_legacy_player_surface_retirement_bench_button: Button = %OpenLegacyPlayerSurfaceRetirementBenchButton
@onready var run_legacy_player_surface_retirement_bench_button: Button = %RunLegacyPlayerSurfaceRetirementBenchButton
@onready var open_legacy_player_surface_retirement_output_folder_button: Button = %OpenLegacyPlayerSurfaceRetirementOutputFolderButton
@onready var open_card_presentation_runtime_service_button: Button = %OpenCardPresentationRuntimeServiceButton
@onready var open_game_table_viewmodel_runtime_service_button: Button = %OpenGameTableViewModelRuntimeServiceButton
@onready var open_card_play_eligibility_runtime_service_button: Button = %OpenCardPlayEligibilityRuntimeServiceButton
@onready var open_card_play_eligibility_world_bridge_button: Button = %OpenCardPlayEligibilityWorldBridgeButton
@onready var open_card_play_eligibility_runtime_bench_button: Button = %OpenCardPlayEligibilityRuntimeBenchButton
@onready var run_card_play_eligibility_runtime_bench_button: Button = %RunCardPlayEligibilityRuntimeBenchButton
@onready var open_card_play_eligibility_output_folder_button: Button = %OpenCardPlayEligibilityOutputFolderButton
@onready var open_menu_shell_runtime_cutover_bench_button: Button = %OpenMenuShellRuntimeCutoverBenchButton
@onready var run_menu_shell_runtime_cutover_bench_button: Button = %RunMenuShellRuntimeCutoverBenchButton
@onready var open_menu_shell_runtime_cutover_output_folder_button: Button = %OpenMenuShellRuntimeCutoverOutputFolderButton
@onready var open_codex_scene_hard_cutover_bench_button: Button = %OpenCodexSceneHardCutoverBenchButton
@onready var run_codex_scene_hard_cutover_bench_button: Button = %RunCodexSceneHardCutoverBenchButton
@onready var open_codex_scene_hard_cutover_output_folder_button: Button = %OpenCodexSceneHardCutoverOutputFolderButton
@onready var open_codex_atlas_scene_cutover_bench_button: Button = %OpenCodexAtlasSceneCutoverBenchButton
@onready var run_codex_atlas_scene_cutover_bench_button: Button = %RunCodexAtlasSceneCutoverBenchButton
@onready var open_codex_atlas_scene_cutover_output_folder_button: Button = %OpenCodexAtlasSceneCutoverOutputFolderButton
@onready var open_codex_navigation_runtime_controller_button: Button = %OpenCodexNavigationRuntimeControllerButton
@onready var run_codex_navigation_runtime_cutover_bench_button: Button = %RunCodexNavigationRuntimeCutoverBenchButton
@onready var open_codex_navigation_runtime_cutover_output_folder_button: Button = %OpenCodexNavigationRuntimeCutoverOutputFolderButton
@onready var open_codex_public_snapshot_service_button: Button = %OpenCodexPublicSnapshotServiceButton
@onready var run_codex_public_snapshot_cutover_bench_button: Button = %RunCodexPublicSnapshotCutoverBenchButton
@onready var open_codex_public_snapshot_cutover_output_folder_button: Button = %OpenCodexPublicSnapshotCutoverOutputFolderButton
@onready var open_monster_codex_public_snapshot_service_button: Button = %OpenMonsterCodexPublicSnapshotServiceButton
@onready var run_monster_codex_public_snapshot_cutover_bench_button: Button = %RunMonsterCodexPublicSnapshotCutoverBenchButton
@onready var open_monster_codex_public_snapshot_cutover_output_folder_button: Button = %OpenMonsterCodexPublicSnapshotCutoverOutputFolderButton
@onready var open_monster_runtime_controller_button: Button = %OpenMonsterRuntimeControllerButton
@onready var open_monster_runtime_world_bridge_button: Button = %OpenMonsterRuntimeWorldBridgeButton
@onready var open_monster_runtime_characterization_bench_button: Button = %OpenMonsterRuntimeCharacterizationBenchButton
@onready var run_monster_runtime_characterization_bench_button: Button = %RunMonsterRuntimeCharacterizationBenchButton
@onready var open_monster_runtime_characterization_output_folder_button: Button = %OpenMonsterRuntimeCharacterizationOutputFolderButton
@onready var open_military_runtime_controller_button: Button = %OpenMilitaryRuntimeControllerButton
@onready var open_military_runtime_world_bridge_button: Button = %OpenMilitaryRuntimeWorldBridgeButton
@onready var open_military_runtime_characterization_bench_button: Button = %OpenMilitaryRuntimeCharacterizationBenchButton
@onready var run_military_runtime_characterization_bench_button: Button = %RunMilitaryRuntimeCharacterizationBenchButton
@onready var open_military_runtime_characterization_output_folder_button: Button = %OpenMilitaryRuntimeCharacterizationOutputFolderButton
@onready var open_weather_runtime_controller_button: Button = %OpenWeatherRuntimeControllerButton
@onready var open_weather_runtime_world_bridge_button: Button = %OpenWeatherRuntimeWorldBridgeButton
@onready var open_weather_runtime_characterization_bench_button: Button = %OpenWeatherRuntimeCharacterizationBenchButton
@onready var run_weather_runtime_characterization_bench_button: Button = %RunWeatherRuntimeCharacterizationBenchButton
@onready var open_weather_runtime_characterization_output_folder_button: Button = %OpenWeatherRuntimeCharacterizationOutputFolderButton
@onready var open_contract_runtime_controller_button: Button = %OpenContractRuntimeControllerButton
@onready var open_contract_runtime_world_bridge_button: Button = %OpenContractRuntimeWorldBridgeButton
@onready var open_contract_runtime_characterization_bench_button: Button = %OpenContractRuntimeCharacterizationBenchButton
@onready var run_contract_runtime_characterization_bench_button: Button = %RunContractRuntimeCharacterizationBenchButton
@onready var open_contract_runtime_characterization_output_folder_button: Button = %OpenContractRuntimeCharacterizationOutputFolderButton
@onready var open_product_market_runtime_characterization_bench_button: Button = %OpenProductMarketRuntimeCharacterizationBenchButton
@onready var run_product_market_runtime_characterization_bench_button: Button = %RunProductMarketRuntimeCharacterizationBenchButton
@onready var open_product_futures_terms_catalog_button: Button = %OpenProductFuturesTermsCatalogButton
@onready var open_product_market_runtime_characterization_output_folder_button: Button = %OpenProductMarketRuntimeCharacterizationOutputFolderButton
@onready var open_city_trade_network_runtime_controller_button: Button = %OpenCityTradeNetworkRuntimeControllerButton
@onready var open_city_trade_network_runtime_world_bridge_button: Button = %OpenCityTradeNetworkRuntimeWorldBridgeButton
@onready var open_city_trade_network_runtime_characterization_bench_button: Button = %OpenCityTradeNetworkRuntimeCharacterizationBenchButton
@onready var run_city_trade_network_runtime_characterization_bench_button: Button = %RunCityTradeNetworkRuntimeCharacterizationBenchButton
@onready var open_city_trade_network_runtime_characterization_output_folder_button: Button = %OpenCityTradeNetworkRuntimeCharacterizationOutputFolderButton
@onready var open_city_development_settlement_characterization_bench_button: Button = %OpenCityDevelopmentSettlementCharacterizationBenchButton
@onready var run_city_development_settlement_characterization_bench_button: Button = %RunCityDevelopmentSettlementCharacterizationBenchButton
@onready var open_city_development_settlement_characterization_output_folder_button: Button = %OpenCityDevelopmentSettlementCharacterizationOutputFolderButton
@onready var open_city_gdp_derivative_runtime_controller_button: Button = %OpenCityGdpDerivativeRuntimeControllerButton
@onready var open_city_gdp_derivative_runtime_world_bridge_button: Button = %OpenCityGdpDerivativeRuntimeWorldBridgeButton
@onready var open_city_gdp_derivative_runtime_bench_button: Button = %OpenCityGdpDerivativeRuntimeBenchButton
@onready var run_city_gdp_derivative_runtime_bench_button: Button = %RunCityGdpDerivativeRuntimeBenchButton
@onready var open_city_gdp_derivative_terms_catalog_button: Button = %OpenCityGdpDerivativeTermsCatalogButton
@onready var open_city_gdp_derivative_runtime_output_folder_button: Button = %OpenCityGdpDerivativeRuntimeOutputFolderButton
@onready var open_product_codex_public_snapshot_service_button: Button = %OpenProductCodexPublicSnapshotServiceButton
@onready var run_product_codex_public_snapshot_cutover_bench_button: Button = %RunProductCodexPublicSnapshotCutoverBenchButton
@onready var open_product_codex_public_snapshot_cutover_output_folder_button: Button = %OpenProductCodexPublicSnapshotCutoverOutputFolderButton
@onready var open_card_codex_public_snapshot_service_button: Button = %OpenCardCodexPublicSnapshotServiceButton
@onready var run_card_codex_public_snapshot_cutover_bench_button: Button = %RunCardCodexPublicSnapshotCutoverBenchButton
@onready var open_card_codex_public_snapshot_cutover_output_folder_button: Button = %OpenCardCodexPublicSnapshotCutoverOutputFolderButton
@onready var open_runtime_card_catalog_button: Button = %OpenRuntimeCardCatalogButton
@onready var open_runtime_card_catalog_service_button: Button = %OpenRuntimeCardCatalogServiceButton
@onready var run_runtime_card_catalog_resource_bench_button: Button = %RunRuntimeCardCatalogResourceBenchButton
@onready var open_runtime_card_catalog_resource_output_folder_button: Button = %OpenRuntimeCardCatalogResourceOutputFolderButton
@onready var open_runtime_card_authoring_workspace_button: Button = %OpenRuntimeCardAuthoringWorkspaceButton
@onready var open_runtime_card_authoring_sample_family_button: Button = %OpenRuntimeCardAuthoringSampleFamilyButton
@onready var run_runtime_card_authoring_workflow_bench_button: Button = %RunRuntimeCardAuthoringWorkflowBenchButton
@onready var open_runtime_card_authoring_output_folder_button: Button = %OpenRuntimeCardAuthoringOutputFolderButton
@onready var open_economy_dashboard_public_snapshot_service_button: Button = %OpenEconomyDashboardPublicSnapshotServiceButton
@onready var run_economy_dashboard_public_snapshot_cutover_bench_button: Button = %RunEconomyDashboardPublicSnapshotCutoverBenchButton
@onready var open_economy_dashboard_public_snapshot_cutover_output_folder_button: Button = %OpenEconomyDashboardPublicSnapshotCutoverOutputFolderButton
@onready var open_standings_public_snapshot_service_button: Button = %OpenStandingsPublicSnapshotServiceButton
@onready var run_standings_public_snapshot_cutover_bench_button: Button = %RunStandingsPublicSnapshotCutoverBenchButton
@onready var open_standings_public_snapshot_cutover_output_folder_button: Button = %OpenStandingsPublicSnapshotCutoverOutputFolderButton
@onready var open_final_settlement_public_snapshot_service_button: Button = %OpenFinalSettlementPublicSnapshotServiceButton
@onready var run_final_settlement_public_snapshot_cutover_bench_button: Button = %RunFinalSettlementPublicSnapshotCutoverBenchButton
@onready var open_final_settlement_public_snapshot_cutover_output_folder_button: Button = %OpenFinalSettlementPublicSnapshotCutoverOutputFolderButton
@onready var open_intel_dossier_public_snapshot_service_button: Button = %OpenIntelDossierPublicSnapshotServiceButton
@onready var run_intel_dossier_public_snapshot_cutover_bench_button: Button = %RunIntelDossierPublicSnapshotCutoverBenchButton
@onready var open_intel_dossier_public_snapshot_cutover_output_folder_button: Button = %OpenIntelDossierPublicSnapshotCutoverOutputFolderButton
@onready var open_new_game_setup_page_button: Button = %OpenNewGameSetupPageButton
@onready var run_new_game_setup_page_cutover_bench_button: Button = %RunNewGameSetupPageCutoverBenchButton
@onready var open_new_game_setup_page_cutover_output_folder_button: Button = %OpenNewGameSetupPageCutoverOutputFolderButton
@onready var open_ai_policy_resource_preview_button: Button = %OpenAiPolicyResourcePreviewButton
@onready var run_ai_policy_resource_bench_button: Button = %RunAiPolicyResourceBenchButton
@onready var open_ai_policy_resource_output_folder_button: Button = %OpenAiPolicyResourceOutputFolderButton
@onready var open_ai_runtime_controller_button: Button = %OpenAiRuntimeControllerButton
@onready var open_ai_runtime_world_bridge_button: Button = %OpenAiRuntimeWorldBridgeButton
@onready var monster_wager_button: Button = %MonsterWagerFixtureButton
@onready var contract_response_button: Button = %ContractResponseFixtureButton
@onready var discard_button: Button = %DiscardPurchaseFixtureButton
@onready var monster_target_button: Button = %MonsterTargetFixtureButton
@onready var player_target_button: Button = %PlayerTargetFixtureButton
@onready var long_text_hint_button: Button = %LongTextStressHintButton
@onready var disabled_hint_button: Button = %DisabledActionHintButton
@onready var malformed_hint_button: Button = %MalformedPayloadHintButton

var _editor_plugin: Object = null
var _fixtures: RefCounted = null
var _selected_fixture_id := "monster_wager"


func _ready() -> void:
	_connect_buttons()
	select_fixture(_selected_fixture_id)


func set_editor_plugin(plugin: Object) -> void:
	_editor_plugin = plugin


func preview_scene_path() -> String:
	return PREVIEW_SCENE_PATH


func capture_bench_scene_path() -> String:
	return CAPTURE_BENCH_SCENE_PATH


func interaction_bench_scene_path() -> String:
	return INTERACTION_BENCH_SCENE_PATH


func mcp_editability_hub_scene_path() -> String:
	return MCP_EDITABILITY_HUB_SCENE_PATH


func player_turn_preview_scene_path() -> String:
	return PLAYER_TURN_PREVIEW_SCENE_PATH


func player_turn_interaction_bench_scene_path() -> String:
	return PLAYER_TURN_INTERACTION_BENCH_SCENE_PATH


func runtime_player_flow_bench_scene_path() -> String:
	return RUNTIME_PLAYER_FLOW_BENCH_SCENE_PATH


func first_playable_loop_bench_scene_path() -> String:
	return FIRST_PLAYABLE_LOOP_BENCH_SCENE_PATH


func first_round_runtime_playable_loop_bench_scene_path() -> String:
	return FIRST_ROUND_RUNTIME_PLAYABLE_LOOP_BENCH_SCENE_PATH


func first_mission_spine_bench_scene_path() -> String:
	return FIRST_MISSION_SPINE_BENCH_SCENE_PATH


func first_mission_runtime_main_bench_scene_path() -> String:
	return FIRST_MISSION_RUNTIME_MAIN_BENCH_SCENE_PATH


func planet_map_preview_scene_path() -> String:
	return PLANET_MAP_PREVIEW_SCENE_PATH


func planet_map_view_scene_path() -> String:
	return PLANET_MAP_VIEW_SCENE_PATH


func planet_district_node_scene_path() -> String:
	return PLANET_DISTRICT_NODE_SCENE_PATH


func planet_district_polygon_scene_path() -> String:
	return PLANET_DISTRICT_POLYGON_SCENE_PATH


func planet_monster_token_scene_path() -> String:
	return PLANET_MONSTER_TOKEN_SCENE_PATH


func planet_route_marker_scene_path() -> String:
	return PLANET_ROUTE_MARKER_SCENE_PATH


func planet_route_segment_scene_path() -> String:
	return PLANET_ROUTE_SEGMENT_SCENE_PATH


func planet_movement_trail_scene_path() -> String:
	return PLANET_MOVEMENT_TRAIL_SCENE_PATH


func planet_map_event_effect_scene_path() -> String:
	return PLANET_MAP_EVENT_EFFECT_SCENE_PATH


func planet_action_callout_scene_path() -> String:
	return PLANET_ACTION_CALLOUT_SCENE_PATH


func planet_globe_backdrop_scene_path() -> String:
	return PLANET_GLOBE_BACKDROP_SCENE_PATH


func planet_orbit_guide_scene_path() -> String:
	return PLANET_ORBIT_GUIDE_SCENE_PATH


func planet_focus_range_overlay_scene_path() -> String:
	return PLANET_FOCUS_RANGE_OVERLAY_SCENE_PATH


func planet_scale_hint_scene_path() -> String:
	return PLANET_SCALE_HINT_SCENE_PATH


func planet_map_render_cutover_bench_scene_path() -> String:
	return PLANET_MAP_RENDER_CUTOVER_BENCH_SCENE_PATH


func planet_map_interaction_bench_scene_path() -> String:
	return PLANET_MAP_INTERACTION_BENCH_SCENE_PATH


func sceneization_audit_preview_scene_path() -> String:
	return SCENEIZATION_AUDIT_PREVIEW_SCENE_PATH


func card_track_preview_scene_path() -> String:
	return CARD_TRACK_PREVIEW_SCENE_PATH


func card_track_slot_scene_path() -> String:
	return CARD_TRACK_SLOT_SCENE_PATH


func card_resolution_track_scene_path() -> String:
	return CARD_RESOLUTION_TRACK_SCENE_PATH


func card_resolution_track_slot_scene_path() -> String:
	return CARD_RESOLUTION_TRACK_SLOT_SCENE_PATH


func card_resolution_track_preview_scene_path() -> String:
	return CARD_RESOLUTION_TRACK_PREVIEW_SCENE_PATH


func card_resolution_track_interaction_bench_scene_path() -> String:
	return CARD_RESOLUTION_TRACK_INTERACTION_BENCH_SCENE_PATH


func runtime_card_resolution_track_flow_bench_scene_path() -> String:
	return RUNTIME_CARD_RESOLUTION_TRACK_FLOW_BENCH_SCENE_PATH


func compendium_codex_preview_scene_path() -> String:
	return COMPENDIUM_CODEX_PREVIEW_SCENE_PATH


func compendium_codex_interaction_bench_scene_path() -> String:
	return COMPENDIUM_CODEX_INTERACTION_BENCH_SCENE_PATH


func compendium_content_registry_preview_scene_path() -> String:
	return COMPENDIUM_CONTENT_REGISTRY_PREVIEW_SCENE_PATH


func compendium_content_registry_bench_scene_path() -> String:
	return COMPENDIUM_CONTENT_REGISTRY_BENCH_SCENE_PATH


func system_resourceization_audit_preview_scene_path() -> String:
	return SYSTEM_RESOURCEIZATION_AUDIT_PREVIEW_SCENE_PATH


func system_resourceization_audit_bench_scene_path() -> String:
	return SYSTEM_RESOURCEIZATION_AUDIT_BENCH_SCENE_PATH


func balance_parameter_resource_preview_scene_path() -> String:
	return BALANCE_PARAMETER_RESOURCE_PREVIEW_SCENE_PATH


func balance_parameter_resource_bench_scene_path() -> String:
	return BALANCE_PARAMETER_RESOURCE_BENCH_SCENE_PATH


func balance_model_resource_sandbox_scene_path() -> String:
	return BALANCE_MODEL_RESOURCE_SANDBOX_SCENE_PATH


func balance_model_resource_sandbox_bench_scene_path() -> String:
	return BALANCE_MODEL_RESOURCE_SANDBOX_BENCH_SCENE_PATH


func balance_runtime_bridge_preview_scene_path() -> String:
	return BALANCE_RUNTIME_BRIDGE_PREVIEW_SCENE_PATH


func balance_runtime_bridge_bench_scene_path() -> String:
	return BALANCE_RUNTIME_BRIDGE_BENCH_SCENE_PATH


func gameplay_balance_diagnostics_service_scene_path() -> String:
	return GAMEPLAY_BALANCE_DIAGNOSTICS_SERVICE_SCENE_PATH


func gameplay_balance_diagnostics_world_bridge_scene_path() -> String:
	return GAMEPLAY_BALANCE_DIAGNOSTICS_WORLD_BRIDGE_SCENE_PATH


func ruleset_runtime_bridge_scene_path() -> String:
	return RULESET_RUNTIME_BRIDGE_SCENE_PATH


func ruleset_v04_conformance_bench_scene_path() -> String:
	return RULESET_V04_CONFORMANCE_BENCH_SCENE_PATH


func city_development_runtime_controller_scene_path() -> String:
	return CITY_DEVELOPMENT_RUNTIME_CONTROLLER_SCENE_PATH


func city_development_world_bridge_scene_path() -> String:
	return CITY_DEVELOPMENT_WORLD_BRIDGE_SCENE_PATH


func game_runtime_coordinator_scene_path() -> String:
	return GAME_RUNTIME_COORDINATOR_SCENE_PATH


func forced_decision_runtime_scheduler_scene_path() -> String:
	return FORCED_DECISION_RUNTIME_SCHEDULER_SCENE_PATH


func forced_decision_runtime_scheduler_bench_scene_path() -> String:
	return FORCED_DECISION_RUNTIME_SCHEDULER_BENCH_SCENE_PATH


func game_session_runtime_controller_scene_path() -> String:
	return GAME_SESSION_RUNTIME_CONTROLLER_SCENE_PATH


func game_save_runtime_coordinator_scene_path() -> String:
	return GAME_SAVE_RUNTIME_COORDINATOR_SCENE_PATH


func game_session_save_ownership_bench_scene_path() -> String:
	return GAME_SESSION_SAVE_OWNERSHIP_BENCH_SCENE_PATH


func district_purchase_runtime_controller_scene_path() -> String:
	return DISTRICT_PURCHASE_RUNTIME_CONTROLLER_SCENE_PATH


func district_purchase_settlement_runtime_service_scene_path() -> String:
	return DISTRICT_PURCHASE_SETTLEMENT_RUNTIME_SERVICE_SCENE_PATH


func district_supply_drawer_scene_path() -> String:
	return DISTRICT_SUPPLY_DRAWER_SCENE_PATH


func district_supply_snapshot_service_scene_path() -> String:
	return DISTRICT_SUPPLY_SNAPSHOT_SERVICE_SCENE_PATH


func district_purchase_runtime_cutover_bench_scene_path() -> String:
	return DISTRICT_PURCHASE_RUNTIME_CUTOVER_BENCH_SCENE_PATH


func card_inventory_runtime_service_scene_path() -> String:
	return CARD_INVENTORY_RUNTIME_SERVICE_SCENE_PATH


func card_inventory_runtime_characterization_bench_scene_path() -> String:
	return CARD_INVENTORY_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH


func player_hand_interaction_runtime_service_scene_path() -> String:
	return PLAYER_HAND_INTERACTION_RUNTIME_SERVICE_SCENE_PATH


func player_hand_interaction_runtime_characterization_bench_scene_path() -> String:
	return PLAYER_HAND_INTERACTION_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH


func card_resolution_queue_runtime_service_scene_path() -> String:
	return CARD_RESOLUTION_QUEUE_RUNTIME_SERVICE_SCENE_PATH


func card_resolution_queue_runtime_characterization_bench_scene_path() -> String:
	return CARD_RESOLUTION_QUEUE_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH


func card_resolution_execution_runtime_service_scene_path() -> String:
	return CARD_RESOLUTION_EXECUTION_RUNTIME_SERVICE_SCENE_PATH


func card_resolution_execution_runtime_characterization_bench_scene_path() -> String:
	return CARD_RESOLUTION_EXECUTION_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH


func card_economy_product_route_effect_runtime_service_scene_path() -> String:
	return CARD_ECONOMY_PRODUCT_ROUTE_EFFECT_RUNTIME_SERVICE_SCENE_PATH


func card_economy_product_route_formula_runtime_service_scene_path() -> String:
	return CARD_ECONOMY_PRODUCT_ROUTE_FORMULA_RUNTIME_SERVICE_SCENE_PATH


func economy_cashflow_runtime_controller_scene_path() -> String:
	return ECONOMY_CASHFLOW_RUNTIME_CONTROLLER_SCENE_PATH


func economy_cashflow_runtime_cutover_bench_scene_path() -> String:
	return ECONOMY_CASHFLOW_RUNTIME_CUTOVER_BENCH_SCENE_PATH


func gdp_formula_runtime_controller_scene_path() -> String:
	return GDP_FORMULA_RUNTIME_CONTROLLER_SCENE_PATH


func gdp_formula_runtime_cutover_bench_scene_path() -> String:
	return GDP_FORMULA_RUNTIME_CUTOVER_BENCH_SCENE_PATH


func scenario_runtime_controller_scene_path() -> String:
	return SCENARIO_RUNTIME_CONTROLLER_SCENE_PATH


func scenario_runtime_glue_cutover_bench_scene_path() -> String:
	return SCENARIO_RUNTIME_GLUE_CUTOVER_BENCH_SCENE_PATH


func first_table_authored_runtime_service_scene_path() -> String:
	return FIRST_TABLE_AUTHORED_RUNTIME_SERVICE_SCENE_PATH


func first_table_authored_runtime_cutover_bench_scene_path() -> String:
	return FIRST_TABLE_AUTHORED_RUNTIME_CUTOVER_BENCH_SCENE_PATH


func sceneized_main_scene_path() -> String:
	return SCENEIZED_MAIN_SCENE_PATH


func legacy_runtime_surface_retirement_bench_scene_path() -> String:
	return LEGACY_RUNTIME_SURFACE_RETIREMENT_BENCH_SCENE_PATH


func legacy_player_surface_retirement_bench_scene_path() -> String:
	return LEGACY_PLAYER_SURFACE_RETIREMENT_BENCH_SCENE_PATH


func card_presentation_runtime_service_scene_path() -> String:
	return CARD_PRESENTATION_RUNTIME_SERVICE_SCENE_PATH


func game_table_viewmodel_runtime_service_scene_path() -> String:
	return GAME_TABLE_VIEWMODEL_RUNTIME_SERVICE_SCENE_PATH


func card_play_eligibility_runtime_service_scene_path() -> String:
	return CARD_PLAY_ELIGIBILITY_RUNTIME_SERVICE_SCENE_PATH


func card_play_eligibility_world_bridge_scene_path() -> String:
	return CARD_PLAY_ELIGIBILITY_WORLD_BRIDGE_SCENE_PATH


func card_play_eligibility_runtime_bench_scene_path() -> String:
	return CARD_PLAY_ELIGIBILITY_RUNTIME_BENCH_SCENE_PATH


func menu_shell_runtime_cutover_bench_scene_path() -> String:
	return MENU_SHELL_RUNTIME_CUTOVER_BENCH_SCENE_PATH


func codex_scene_hard_cutover_bench_scene_path() -> String:
	return CODEX_SCENE_HARD_CUTOVER_BENCH_SCENE_PATH


func codex_atlas_scene_cutover_bench_scene_path() -> String:
	return CODEX_ATLAS_SCENE_CUTOVER_BENCH_SCENE_PATH


func codex_navigation_runtime_controller_scene_path() -> String:
	return CODEX_NAVIGATION_RUNTIME_CONTROLLER_SCENE_PATH


func codex_navigation_runtime_cutover_bench_scene_path() -> String:
	return CODEX_NAVIGATION_RUNTIME_CUTOVER_BENCH_SCENE_PATH


func codex_public_snapshot_service_scene_path() -> String:
	return CODEX_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH


func codex_public_snapshot_cutover_bench_scene_path() -> String:
	return CODEX_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH


func monster_codex_public_snapshot_service_scene_path() -> String:
	return MONSTER_CODEX_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH


func monster_codex_public_snapshot_cutover_bench_scene_path() -> String:
	return MONSTER_CODEX_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH


func monster_runtime_characterization_bench_scene_path() -> String:
	return MONSTER_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH


func monster_runtime_controller_scene_path() -> String:
	return MONSTER_RUNTIME_CONTROLLER_SCENE_PATH


func monster_runtime_world_bridge_scene_path() -> String:
	return MONSTER_RUNTIME_WORLD_BRIDGE_SCENE_PATH


func military_runtime_characterization_bench_scene_path() -> String:
	return MILITARY_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH


func military_runtime_controller_scene_path() -> String:
	return MILITARY_RUNTIME_CONTROLLER_SCENE_PATH


func military_runtime_world_bridge_scene_path() -> String:
	return MILITARY_RUNTIME_WORLD_BRIDGE_SCENE_PATH


func weather_runtime_controller_scene_path() -> String:
	return WEATHER_RUNTIME_CONTROLLER_SCENE_PATH


func weather_runtime_world_bridge_scene_path() -> String:
	return WEATHER_RUNTIME_WORLD_BRIDGE_SCENE_PATH


func weather_runtime_characterization_bench_scene_path() -> String:
	return WEATHER_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH


func contract_runtime_controller_scene_path() -> String:
	return CONTRACT_RUNTIME_CONTROLLER_SCENE_PATH


func contract_runtime_world_bridge_scene_path() -> String:
	return CONTRACT_RUNTIME_WORLD_BRIDGE_SCENE_PATH


func contract_runtime_characterization_bench_scene_path() -> String:
	return CONTRACT_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH


func product_market_runtime_characterization_bench_scene_path() -> String:
	return PRODUCT_MARKET_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH


func product_futures_terms_catalog_path() -> String:
	return PRODUCT_FUTURES_TERMS_CATALOG_PATH


func city_trade_network_runtime_controller_scene_path() -> String:
	return CITY_TRADE_NETWORK_RUNTIME_CONTROLLER_SCENE_PATH


func city_trade_network_runtime_world_bridge_scene_path() -> String:
	return CITY_TRADE_NETWORK_RUNTIME_WORLD_BRIDGE_SCENE_PATH


func city_trade_network_runtime_characterization_bench_scene_path() -> String:
	return CITY_TRADE_NETWORK_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH


func city_development_settlement_characterization_bench_scene_path() -> String:
	return CITY_DEVELOPMENT_SETTLEMENT_CHARACTERIZATION_BENCH_SCENE_PATH


func city_gdp_derivative_runtime_bench_scene_path() -> String:
	return CITY_GDP_DERIVATIVE_RUNTIME_BENCH_SCENE_PATH


func city_gdp_derivative_terms_catalog_path() -> String:
	return CITY_GDP_DERIVATIVE_TERMS_CATALOG_PATH


func product_codex_public_snapshot_service_scene_path() -> String:
	return PRODUCT_CODEX_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH


func product_codex_public_snapshot_cutover_bench_scene_path() -> String:
	return PRODUCT_CODEX_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH


func card_codex_public_snapshot_service_scene_path() -> String:
	return CARD_CODEX_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH


func card_codex_public_snapshot_cutover_bench_scene_path() -> String:
	return CARD_CODEX_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH


func runtime_card_catalog_resource_path() -> String:
	return RUNTIME_CARD_CATALOG_RESOURCE_PATH


func runtime_card_catalog_service_scene_path() -> String:
	return RUNTIME_CARD_CATALOG_SERVICE_SCENE_PATH


func runtime_card_catalog_resource_bench_scene_path() -> String:
	return RUNTIME_CARD_CATALOG_RESOURCE_BENCH_SCENE_PATH


func runtime_card_authoring_workspace_scene_path() -> String:
	return RUNTIME_CARD_AUTHORING_WORKSPACE_SCENE_PATH


func runtime_card_authoring_workflow_bench_scene_path() -> String:
	return RUNTIME_CARD_AUTHORING_WORKFLOW_BENCH_SCENE_PATH


func runtime_card_authoring_sample_family_path() -> String:
	return RUNTIME_CARD_AUTHORING_SAMPLE_FAMILY_PATH


func economy_dashboard_public_snapshot_service_scene_path() -> String:
	return ECONOMY_DASHBOARD_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH


func economy_dashboard_public_snapshot_cutover_bench_scene_path() -> String:
	return ECONOMY_DASHBOARD_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH


func standings_public_snapshot_service_scene_path() -> String:
	return STANDINGS_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH


func standings_public_snapshot_cutover_bench_scene_path() -> String:
	return STANDINGS_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH


func final_settlement_public_snapshot_service_scene_path() -> String:
	return FINAL_SETTLEMENT_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH


func final_settlement_public_snapshot_cutover_bench_scene_path() -> String:
	return FINAL_SETTLEMENT_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH


func intel_dossier_public_snapshot_service_scene_path() -> String:
	return INTEL_DOSSIER_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH


func intel_dossier_public_snapshot_cutover_bench_scene_path() -> String:
	return INTEL_DOSSIER_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH


func new_game_setup_page_scene_path() -> String:
	return NEW_GAME_SETUP_PAGE_SCENE_PATH


func new_game_setup_page_cutover_bench_scene_path() -> String:
	return NEW_GAME_SETUP_PAGE_CUTOVER_BENCH_SCENE_PATH


func ai_policy_resource_preview_scene_path() -> String:
	return AI_POLICY_RESOURCE_PREVIEW_SCENE_PATH


func ai_policy_resource_bench_scene_path() -> String:
	return AI_POLICY_RESOURCE_BENCH_SCENE_PATH


func ai_runtime_controller_scene_path() -> String:
	return AI_RUNTIME_CONTROLLER_SCENE_PATH


func ai_runtime_world_bridge_scene_path() -> String:
	return AI_RUNTIME_WORLD_BRIDGE_SCENE_PATH


func fixture_script_path() -> String:
	return FIXTURE_SCRIPT_PATH


func qa_output_dir() -> String:
	return DESIGN_QA_OUTPUT_DIR


func interaction_qa_output_dir() -> String:
	return INTERACTION_QA_OUTPUT_DIR


func player_turn_interaction_qa_output_dir() -> String:
	return PLAYER_TURN_INTERACTION_QA_OUTPUT_DIR


func runtime_player_flow_qa_output_dir() -> String:
	return RUNTIME_PLAYER_FLOW_QA_OUTPUT_DIR


func first_playable_loop_qa_output_dir() -> String:
	return FIRST_PLAYABLE_LOOP_QA_OUTPUT_DIR


func first_round_runtime_playable_loop_qa_output_dir() -> String:
	return FIRST_ROUND_RUNTIME_PLAYABLE_LOOP_QA_OUTPUT_DIR


func first_mission_spine_qa_output_dir() -> String:
	return FIRST_MISSION_SPINE_QA_OUTPUT_DIR


func first_mission_runtime_main_qa_output_dir() -> String:
	return FIRST_MISSION_RUNTIME_MAIN_QA_OUTPUT_DIR


func planet_map_render_cutover_qa_output_dir() -> String:
	return PLANET_MAP_RENDER_CUTOVER_QA_OUTPUT_DIR


func planet_map_interaction_qa_output_dir() -> String:
	return PLANET_MAP_INTERACTION_QA_OUTPUT_DIR


func card_resolution_track_interaction_qa_output_dir() -> String:
	return CARD_RESOLUTION_TRACK_INTERACTION_QA_OUTPUT_DIR


func runtime_card_resolution_track_flow_qa_output_dir() -> String:
	return RUNTIME_CARD_RESOLUTION_TRACK_FLOW_QA_OUTPUT_DIR


func compendium_codex_qa_output_dir() -> String:
	return COMPENDIUM_CODEX_QA_OUTPUT_DIR


func compendium_content_registry_qa_output_dir() -> String:
	return COMPENDIUM_CONTENT_REGISTRY_QA_OUTPUT_DIR


func system_resourceization_audit_qa_output_dir() -> String:
	return SYSTEM_RESOURCEIZATION_AUDIT_QA_OUTPUT_DIR


func balance_parameter_resource_qa_output_dir() -> String:
	return BALANCE_PARAMETER_RESOURCE_QA_OUTPUT_DIR


func balance_model_resource_sandbox_qa_output_dir() -> String:
	return BALANCE_MODEL_RESOURCE_SANDBOX_QA_OUTPUT_DIR


func balance_runtime_bridge_qa_output_dir() -> String:
	return BALANCE_RUNTIME_BRIDGE_QA_OUTPUT_DIR


func ruleset_v04_conformance_qa_output_dir() -> String:
	return RULESET_V04_CONFORMANCE_QA_OUTPUT_DIR


func forced_decision_runtime_scheduler_qa_output_dir() -> String:
	return FORCED_DECISION_RUNTIME_SCHEDULER_QA_OUTPUT_DIR


func game_session_save_ownership_qa_output_dir() -> String:
	return GAME_SESSION_SAVE_OWNERSHIP_QA_OUTPUT_DIR


func district_purchase_runtime_cutover_qa_output_dir() -> String:
	return DISTRICT_PURCHASE_RUNTIME_CUTOVER_QA_OUTPUT_DIR


func card_inventory_runtime_characterization_qa_output_dir() -> String:
	return CARD_INVENTORY_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR


func card_inventory_runtime_cutover_qa_output_dir() -> String:
	return CARD_INVENTORY_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR


func player_hand_interaction_runtime_characterization_qa_output_dir() -> String:
	return PLAYER_HAND_INTERACTION_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR


func card_resolution_queue_runtime_characterization_qa_output_dir() -> String:
	return CARD_RESOLUTION_QUEUE_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR


func card_resolution_execution_runtime_characterization_qa_output_dir() -> String:
	return CARD_RESOLUTION_EXECUTION_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR


func economy_cashflow_runtime_cutover_qa_output_dir() -> String:
	return ECONOMY_CASHFLOW_RUNTIME_CUTOVER_QA_OUTPUT_DIR


func scenario_runtime_glue_cutover_qa_output_dir() -> String:
	return SCENARIO_RUNTIME_GLUE_CUTOVER_QA_OUTPUT_DIR


func first_table_authored_runtime_cutover_qa_output_dir() -> String:
	return FIRST_TABLE_AUTHORED_RUNTIME_CUTOVER_QA_OUTPUT_DIR


func legacy_runtime_surface_retirement_qa_output_dir() -> String:
	return LEGACY_RUNTIME_SURFACE_RETIREMENT_QA_OUTPUT_DIR


func legacy_player_surface_retirement_qa_output_dir() -> String:
	return LEGACY_PLAYER_SURFACE_RETIREMENT_QA_OUTPUT_DIR


func card_play_eligibility_qa_output_dir() -> String:
	return CARD_PLAY_ELIGIBILITY_QA_OUTPUT_DIR


func menu_shell_runtime_cutover_qa_output_dir() -> String:
	return MENU_SHELL_RUNTIME_CUTOVER_QA_OUTPUT_DIR


func codex_scene_hard_cutover_qa_output_dir() -> String:
	return CODEX_SCENE_HARD_CUTOVER_QA_OUTPUT_DIR


func codex_atlas_scene_cutover_qa_output_dir() -> String:
	return CODEX_ATLAS_SCENE_CUTOVER_QA_OUTPUT_DIR


func codex_navigation_runtime_cutover_qa_output_dir() -> String:
	return CODEX_NAVIGATION_RUNTIME_CUTOVER_QA_OUTPUT_DIR


func codex_public_snapshot_cutover_qa_output_dir() -> String:
	return CODEX_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR


func monster_codex_public_snapshot_cutover_qa_output_dir() -> String:
	return MONSTER_CODEX_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR


func monster_runtime_characterization_qa_output_dir() -> String:
	return MONSTER_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR


func military_runtime_characterization_qa_output_dir() -> String:
	return MILITARY_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR


func weather_runtime_characterization_qa_output_dir() -> String:
	return WEATHER_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR


func contract_runtime_characterization_qa_output_dir() -> String:
	return CONTRACT_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR


func product_market_runtime_characterization_qa_output_dir() -> String:
	return PRODUCT_MARKET_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR


func city_trade_network_runtime_characterization_qa_output_dir() -> String:
	return CITY_TRADE_NETWORK_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR


func city_development_settlement_characterization_qa_output_dir() -> String:
	return CITY_DEVELOPMENT_SETTLEMENT_CHARACTERIZATION_QA_OUTPUT_DIR


func city_gdp_derivative_runtime_qa_output_dir() -> String:
	return CITY_GDP_DERIVATIVE_RUNTIME_QA_OUTPUT_DIR


func product_codex_public_snapshot_cutover_qa_output_dir() -> String:
	return PRODUCT_CODEX_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR


func card_codex_public_snapshot_cutover_qa_output_dir() -> String:
	return CARD_CODEX_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR


func runtime_card_catalog_resource_qa_output_dir() -> String:
	return RUNTIME_CARD_CATALOG_RESOURCE_QA_OUTPUT_DIR


func runtime_card_authoring_qa_output_dir() -> String:
	return RUNTIME_CARD_AUTHORING_QA_OUTPUT_DIR


func economy_dashboard_public_snapshot_cutover_qa_output_dir() -> String:
	return ECONOMY_DASHBOARD_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR


func standings_public_snapshot_cutover_qa_output_dir() -> String:
	return STANDINGS_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR


func final_settlement_public_snapshot_cutover_qa_output_dir() -> String:
	return FINAL_SETTLEMENT_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR


func intel_dossier_public_snapshot_cutover_qa_output_dir() -> String:
	return INTEL_DOSSIER_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR


func new_game_setup_page_cutover_qa_output_dir() -> String:
	return NEW_GAME_SETUP_PAGE_CUTOVER_QA_OUTPUT_DIR


func ai_policy_resource_qa_output_dir() -> String:
	return AI_POLICY_RESOURCE_QA_OUTPUT_DIR


func selected_fixture_id() -> String:
	return _selected_fixture_id


func fixture_ids() -> Array[String]:
	var fixtures := _fixtures_instance()
	var result: Array[String] = []
	if fixtures == null:
		return result
	var ids_variant: Variant = fixtures.call("preview_ids")
	if ids_variant is Array:
		for id_variant in ids_variant:
			result.append(str(id_variant))
	return result


func preview_fixture(id: String) -> Dictionary:
	var fixtures := _fixtures_instance()
	if fixtures == null:
		return {}
	var data_variant: Variant = fixtures.call("fixture", id)
	if data_variant is Dictionary:
		return (data_variant as Dictionary).duplicate(true)
	return {}


func select_fixture(id: String) -> void:
	_selected_fixture_id = id
	var data := preview_fixture(id)
	var actions: Array = data.get("actions", []) if data.get("actions", []) is Array else []
	var chips: Array = data.get("chips", []) if data.get("chips", []) is Array else []
	var title := str(data.get("title", id))
	var panel_name := str(PANEL_BY_FIXTURE_ID.get(id, "TemporaryDecisionModal"))
	if fixture_title_label != null:
		fixture_title_label.text = "%s -> %s" % [_fixture_label(id), panel_name]
	if fixture_summary_label != null:
		fixture_summary_label.text = "%s\nkind: %s\nid: %s\nactions: %d  chips: %d" % [
			title,
			str(data.get("kind", "")),
			str(data.get("id", "")),
			actions.size(),
			chips.size(),
		]
	_set_status("Fixture selected: %s" % id)


func open_preview_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", PREVIEW_SCENE_PATH)
	else:
		open_preview_requested.emit(PREVIEW_SCENE_PATH)
	_set_status("Open scene: %s" % PREVIEW_SCENE_PATH)


func run_preview_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", PREVIEW_SCENE_PATH)
	else:
		run_preview_requested.emit(PREVIEW_SCENE_PATH)
	_set_status("Run scene: %s" % PREVIEW_SCENE_PATH)


func open_capture_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", CAPTURE_BENCH_SCENE_PATH)
	else:
		open_capture_bench_requested.emit(CAPTURE_BENCH_SCENE_PATH)
	_set_status("Open capture bench: %s" % CAPTURE_BENCH_SCENE_PATH)


func run_capture_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", CAPTURE_BENCH_SCENE_PATH)
	else:
		run_capture_bench_requested.emit(CAPTURE_BENCH_SCENE_PATH)
	_set_status("Run capture bench: %s" % CAPTURE_BENCH_SCENE_PATH)


func open_interaction_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", INTERACTION_BENCH_SCENE_PATH)
	else:
		open_interaction_bench_requested.emit(INTERACTION_BENCH_SCENE_PATH)
	_set_status("Open interaction bench: %s" % INTERACTION_BENCH_SCENE_PATH)


func run_interaction_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", INTERACTION_BENCH_SCENE_PATH)
	else:
		run_interaction_bench_requested.emit(INTERACTION_BENCH_SCENE_PATH)
	_set_status("Run interaction bench: %s" % INTERACTION_BENCH_SCENE_PATH)


func open_mcp_editability_hub_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", MCP_EDITABILITY_HUB_SCENE_PATH)
	else:
		open_mcp_editability_hub_requested.emit(MCP_EDITABILITY_HUB_SCENE_PATH)
	_set_status("Open MCP editability hub: %s" % MCP_EDITABILITY_HUB_SCENE_PATH)


func run_mcp_editability_hub_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", MCP_EDITABILITY_HUB_SCENE_PATH)
	else:
		run_mcp_editability_hub_requested.emit(MCP_EDITABILITY_HUB_SCENE_PATH)
	_set_status("Run MCP editability hub: %s" % MCP_EDITABILITY_HUB_SCENE_PATH)


func open_player_turn_preview_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", PLAYER_TURN_PREVIEW_SCENE_PATH)
	else:
		open_player_turn_preview_requested.emit(PLAYER_TURN_PREVIEW_SCENE_PATH)
	_set_status("Open player turn preview: %s" % PLAYER_TURN_PREVIEW_SCENE_PATH)


func run_player_turn_preview_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", PLAYER_TURN_PREVIEW_SCENE_PATH)
	else:
		run_player_turn_preview_requested.emit(PLAYER_TURN_PREVIEW_SCENE_PATH)
	_set_status("Run player turn preview: %s" % PLAYER_TURN_PREVIEW_SCENE_PATH)


func open_player_turn_interaction_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", PLAYER_TURN_INTERACTION_BENCH_SCENE_PATH)
	else:
		open_player_turn_interaction_bench_requested.emit(PLAYER_TURN_INTERACTION_BENCH_SCENE_PATH)
	_set_status("Open player turn interaction bench: %s" % PLAYER_TURN_INTERACTION_BENCH_SCENE_PATH)


func run_player_turn_interaction_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", PLAYER_TURN_INTERACTION_BENCH_SCENE_PATH)
	else:
		run_player_turn_interaction_bench_requested.emit(PLAYER_TURN_INTERACTION_BENCH_SCENE_PATH)
	_set_status("Run player turn interaction bench: %s" % PLAYER_TURN_INTERACTION_BENCH_SCENE_PATH)


func open_runtime_player_flow_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", RUNTIME_PLAYER_FLOW_BENCH_SCENE_PATH)
	else:
		open_runtime_player_flow_bench_requested.emit(RUNTIME_PLAYER_FLOW_BENCH_SCENE_PATH)
	_set_status("Open runtime player flow bench: %s" % RUNTIME_PLAYER_FLOW_BENCH_SCENE_PATH)


func run_runtime_player_flow_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", RUNTIME_PLAYER_FLOW_BENCH_SCENE_PATH)
	else:
		run_runtime_player_flow_bench_requested.emit(RUNTIME_PLAYER_FLOW_BENCH_SCENE_PATH)
	_set_status("Run runtime player flow bench: %s" % RUNTIME_PLAYER_FLOW_BENCH_SCENE_PATH)


func open_first_playable_loop_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", FIRST_PLAYABLE_LOOP_BENCH_SCENE_PATH)
	else:
		open_first_playable_loop_bench_requested.emit(FIRST_PLAYABLE_LOOP_BENCH_SCENE_PATH)
	_set_status("Open first playable loop bench: %s" % FIRST_PLAYABLE_LOOP_BENCH_SCENE_PATH)


func run_first_playable_loop_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", FIRST_PLAYABLE_LOOP_BENCH_SCENE_PATH)
	else:
		run_first_playable_loop_bench_requested.emit(FIRST_PLAYABLE_LOOP_BENCH_SCENE_PATH)
	_set_status("Run first playable loop bench: %s" % FIRST_PLAYABLE_LOOP_BENCH_SCENE_PATH)


func open_first_round_runtime_playable_loop_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", FIRST_ROUND_RUNTIME_PLAYABLE_LOOP_BENCH_SCENE_PATH)
	else:
		open_first_round_runtime_playable_loop_bench_requested.emit(FIRST_ROUND_RUNTIME_PLAYABLE_LOOP_BENCH_SCENE_PATH)
	_set_status("Open first-round runtime playable loop bench: %s" % FIRST_ROUND_RUNTIME_PLAYABLE_LOOP_BENCH_SCENE_PATH)


func run_first_round_runtime_playable_loop_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", FIRST_ROUND_RUNTIME_PLAYABLE_LOOP_BENCH_SCENE_PATH)
	else:
		run_first_round_runtime_playable_loop_bench_requested.emit(FIRST_ROUND_RUNTIME_PLAYABLE_LOOP_BENCH_SCENE_PATH)
	_set_status("Run first-round runtime playable loop bench: %s" % FIRST_ROUND_RUNTIME_PLAYABLE_LOOP_BENCH_SCENE_PATH)


func open_first_mission_spine_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", FIRST_MISSION_SPINE_BENCH_SCENE_PATH)
	else:
		open_first_mission_spine_bench_requested.emit(FIRST_MISSION_SPINE_BENCH_SCENE_PATH)
	_set_status("Open first mission spine bench: %s" % FIRST_MISSION_SPINE_BENCH_SCENE_PATH)


func run_first_mission_spine_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", FIRST_MISSION_SPINE_BENCH_SCENE_PATH)
	else:
		run_first_mission_spine_bench_requested.emit(FIRST_MISSION_SPINE_BENCH_SCENE_PATH)
	_set_status("Run first mission spine bench: %s" % FIRST_MISSION_SPINE_BENCH_SCENE_PATH)


func open_first_mission_runtime_main_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", FIRST_MISSION_RUNTIME_MAIN_BENCH_SCENE_PATH)
	else:
		open_first_mission_runtime_main_bench_requested.emit(FIRST_MISSION_RUNTIME_MAIN_BENCH_SCENE_PATH)
	_set_status("Open first mission runtime main bench: %s" % FIRST_MISSION_RUNTIME_MAIN_BENCH_SCENE_PATH)


func run_first_mission_runtime_main_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", FIRST_MISSION_RUNTIME_MAIN_BENCH_SCENE_PATH)
	else:
		run_first_mission_runtime_main_bench_requested.emit(FIRST_MISSION_RUNTIME_MAIN_BENCH_SCENE_PATH)
	_set_status("Run first mission runtime main bench: %s" % FIRST_MISSION_RUNTIME_MAIN_BENCH_SCENE_PATH)


func open_planet_map_preview_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", PLANET_MAP_PREVIEW_SCENE_PATH)
	else:
		open_planet_map_preview_requested.emit(PLANET_MAP_PREVIEW_SCENE_PATH)
	_set_status("Open planet map preview: %s" % PLANET_MAP_PREVIEW_SCENE_PATH)


func run_planet_map_preview_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", PLANET_MAP_PREVIEW_SCENE_PATH)
	else:
		run_planet_map_preview_requested.emit(PLANET_MAP_PREVIEW_SCENE_PATH)
	_set_status("Run planet map preview: %s" % PLANET_MAP_PREVIEW_SCENE_PATH)


func open_planet_map_view_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", PLANET_MAP_VIEW_SCENE_PATH)
	else:
		open_planet_map_view_requested.emit(PLANET_MAP_VIEW_SCENE_PATH)
	_set_status("Open PlanetMapView scene: %s" % PLANET_MAP_VIEW_SCENE_PATH)


func open_planet_district_node_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", PLANET_DISTRICT_NODE_SCENE_PATH)
	else:
		open_planet_district_node_requested.emit(PLANET_DISTRICT_NODE_SCENE_PATH)
	_set_status("Open PlanetDistrictNode scene: %s" % PLANET_DISTRICT_NODE_SCENE_PATH)


func open_planet_district_polygon_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", PLANET_DISTRICT_POLYGON_SCENE_PATH)
	else:
		open_planet_district_polygon_requested.emit(PLANET_DISTRICT_POLYGON_SCENE_PATH)
	_set_status("Open PlanetDistrictPolygon scene: %s" % PLANET_DISTRICT_POLYGON_SCENE_PATH)


func open_planet_monster_token_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", PLANET_MONSTER_TOKEN_SCENE_PATH)
	else:
		open_planet_monster_token_requested.emit(PLANET_MONSTER_TOKEN_SCENE_PATH)
	_set_status("Open PlanetMonsterToken scene: %s" % PLANET_MONSTER_TOKEN_SCENE_PATH)


func open_planet_route_marker_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", PLANET_ROUTE_MARKER_SCENE_PATH)
	else:
		open_planet_route_marker_requested.emit(PLANET_ROUTE_MARKER_SCENE_PATH)
	_set_status("Open PlanetRouteMarker scene: %s" % PLANET_ROUTE_MARKER_SCENE_PATH)


func open_planet_route_segment_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", PLANET_ROUTE_SEGMENT_SCENE_PATH)
	else:
		open_planet_route_segment_requested.emit(PLANET_ROUTE_SEGMENT_SCENE_PATH)
	_set_status("Open PlanetRouteSegment scene: %s" % PLANET_ROUTE_SEGMENT_SCENE_PATH)


func open_planet_movement_trail_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", PLANET_MOVEMENT_TRAIL_SCENE_PATH)
	else:
		open_planet_movement_trail_requested.emit(PLANET_MOVEMENT_TRAIL_SCENE_PATH)
	_set_status("Open PlanetMovementTrail scene: %s" % PLANET_MOVEMENT_TRAIL_SCENE_PATH)


func open_planet_map_event_effect_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", PLANET_MAP_EVENT_EFFECT_SCENE_PATH)
	else:
		open_planet_map_event_effect_requested.emit(PLANET_MAP_EVENT_EFFECT_SCENE_PATH)
	_set_status("Open PlanetMapEventEffect scene: %s" % PLANET_MAP_EVENT_EFFECT_SCENE_PATH)


func open_planet_action_callout_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", PLANET_ACTION_CALLOUT_SCENE_PATH)
	else:
		open_planet_action_callout_requested.emit(PLANET_ACTION_CALLOUT_SCENE_PATH)
	_set_status("Open PlanetActionCallout scene: %s" % PLANET_ACTION_CALLOUT_SCENE_PATH)


func open_planet_globe_backdrop_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", PLANET_GLOBE_BACKDROP_SCENE_PATH)
	else:
		open_planet_globe_backdrop_requested.emit(PLANET_GLOBE_BACKDROP_SCENE_PATH)
	_set_status("Open PlanetGlobeBackdrop scene: %s" % PLANET_GLOBE_BACKDROP_SCENE_PATH)


func open_planet_orbit_guide_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", PLANET_ORBIT_GUIDE_SCENE_PATH)
	else:
		open_planet_orbit_guide_requested.emit(PLANET_ORBIT_GUIDE_SCENE_PATH)
	_set_status("Open PlanetOrbitGuide scene: %s" % PLANET_ORBIT_GUIDE_SCENE_PATH)


func open_planet_focus_range_overlay_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", PLANET_FOCUS_RANGE_OVERLAY_SCENE_PATH)
	else:
		open_planet_focus_range_overlay_requested.emit(PLANET_FOCUS_RANGE_OVERLAY_SCENE_PATH)
	_set_status("Open PlanetFocusRangeOverlay scene: %s" % PLANET_FOCUS_RANGE_OVERLAY_SCENE_PATH)


func open_planet_scale_hint_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", PLANET_SCALE_HINT_SCENE_PATH)
	else:
		open_planet_scale_hint_requested.emit(PLANET_SCALE_HINT_SCENE_PATH)
	_set_status("Open PlanetMapScaleHint scene: %s" % PLANET_SCALE_HINT_SCENE_PATH)


func open_planet_render_cutover_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", PLANET_MAP_RENDER_CUTOVER_BENCH_SCENE_PATH)
	else:
		open_planet_render_cutover_bench_requested.emit(PLANET_MAP_RENDER_CUTOVER_BENCH_SCENE_PATH)
	_set_status("Open PlanetMap render cutover bench: %s" % PLANET_MAP_RENDER_CUTOVER_BENCH_SCENE_PATH)


func run_planet_render_cutover_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", PLANET_MAP_RENDER_CUTOVER_BENCH_SCENE_PATH)
	else:
		run_planet_render_cutover_bench_requested.emit(PLANET_MAP_RENDER_CUTOVER_BENCH_SCENE_PATH)
	_set_status("Run PlanetMap render cutover bench: %s" % PLANET_MAP_RENDER_CUTOVER_BENCH_SCENE_PATH)


func open_planet_interaction_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", PLANET_MAP_INTERACTION_BENCH_SCENE_PATH)
	else:
		open_planet_interaction_bench_requested.emit(PLANET_MAP_INTERACTION_BENCH_SCENE_PATH)
	_set_status("Open PlanetMap interaction bench: %s" % PLANET_MAP_INTERACTION_BENCH_SCENE_PATH)


func run_planet_interaction_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", PLANET_MAP_INTERACTION_BENCH_SCENE_PATH)
	else:
		run_planet_interaction_bench_requested.emit(PLANET_MAP_INTERACTION_BENCH_SCENE_PATH)
	_set_status("Run PlanetMap interaction bench: %s" % PLANET_MAP_INTERACTION_BENCH_SCENE_PATH)


func open_sceneization_audit_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", SCENEIZATION_AUDIT_PREVIEW_SCENE_PATH)
	else:
		open_sceneization_audit_requested.emit(SCENEIZATION_AUDIT_PREVIEW_SCENE_PATH)
	_set_status("Open sceneization audit: %s" % SCENEIZATION_AUDIT_PREVIEW_SCENE_PATH)


func run_sceneization_audit_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", SCENEIZATION_AUDIT_PREVIEW_SCENE_PATH)
	else:
		run_sceneization_audit_requested.emit(SCENEIZATION_AUDIT_PREVIEW_SCENE_PATH)
	_set_status("Run sceneization audit: %s" % SCENEIZATION_AUDIT_PREVIEW_SCENE_PATH)


func open_card_track_preview_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", CARD_TRACK_PREVIEW_SCENE_PATH)
	else:
		open_card_track_preview_requested.emit(CARD_TRACK_PREVIEW_SCENE_PATH)
	_set_status("Open card track preview: %s" % CARD_TRACK_PREVIEW_SCENE_PATH)


func run_card_track_preview_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", CARD_TRACK_PREVIEW_SCENE_PATH)
	else:
		run_card_track_preview_requested.emit(CARD_TRACK_PREVIEW_SCENE_PATH)
	_set_status("Run card track preview: %s" % CARD_TRACK_PREVIEW_SCENE_PATH)


func open_card_track_slot_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", CARD_TRACK_SLOT_SCENE_PATH)
	else:
		open_card_track_slot_requested.emit(CARD_TRACK_SLOT_SCENE_PATH)
	_set_status("Open CardTrackSlot scene: %s" % CARD_TRACK_SLOT_SCENE_PATH)


func open_card_resolution_track_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", CARD_RESOLUTION_TRACK_SCENE_PATH)
	else:
		open_card_resolution_track_requested.emit(CARD_RESOLUTION_TRACK_SCENE_PATH)
	_set_status("Open CardResolutionTrack scene: %s" % CARD_RESOLUTION_TRACK_SCENE_PATH)


func open_card_resolution_track_slot_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", CARD_RESOLUTION_TRACK_SLOT_SCENE_PATH)
	else:
		open_card_resolution_track_slot_requested.emit(CARD_RESOLUTION_TRACK_SLOT_SCENE_PATH)
	_set_status("Open CardResolutionTrackSlot scene: %s" % CARD_RESOLUTION_TRACK_SLOT_SCENE_PATH)


func open_card_resolution_track_preview_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", CARD_RESOLUTION_TRACK_PREVIEW_SCENE_PATH)
	else:
		open_card_resolution_track_preview_requested.emit(CARD_RESOLUTION_TRACK_PREVIEW_SCENE_PATH)
	_set_status("Open CardResolutionTrack preview: %s" % CARD_RESOLUTION_TRACK_PREVIEW_SCENE_PATH)


func run_card_resolution_track_preview_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", CARD_RESOLUTION_TRACK_PREVIEW_SCENE_PATH)
	else:
		run_card_resolution_track_preview_requested.emit(CARD_RESOLUTION_TRACK_PREVIEW_SCENE_PATH)
	_set_status("Run CardResolutionTrack preview: %s" % CARD_RESOLUTION_TRACK_PREVIEW_SCENE_PATH)


func open_card_resolution_track_interaction_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", CARD_RESOLUTION_TRACK_INTERACTION_BENCH_SCENE_PATH)
	else:
		open_card_resolution_track_interaction_bench_requested.emit(CARD_RESOLUTION_TRACK_INTERACTION_BENCH_SCENE_PATH)
	_set_status("Open CardResolutionTrack interaction bench: %s" % CARD_RESOLUTION_TRACK_INTERACTION_BENCH_SCENE_PATH)


func run_card_resolution_track_interaction_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", CARD_RESOLUTION_TRACK_INTERACTION_BENCH_SCENE_PATH)
	else:
		run_card_resolution_track_interaction_bench_requested.emit(CARD_RESOLUTION_TRACK_INTERACTION_BENCH_SCENE_PATH)
	_set_status("Run CardResolutionTrack interaction bench: %s" % CARD_RESOLUTION_TRACK_INTERACTION_BENCH_SCENE_PATH)


func open_runtime_card_resolution_track_flow_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", RUNTIME_CARD_RESOLUTION_TRACK_FLOW_BENCH_SCENE_PATH)
	else:
		open_runtime_card_resolution_track_flow_bench_requested.emit(RUNTIME_CARD_RESOLUTION_TRACK_FLOW_BENCH_SCENE_PATH)
	_set_status("Open Runtime CardResolutionTrack flow bench: %s" % RUNTIME_CARD_RESOLUTION_TRACK_FLOW_BENCH_SCENE_PATH)


func run_runtime_card_resolution_track_flow_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", RUNTIME_CARD_RESOLUTION_TRACK_FLOW_BENCH_SCENE_PATH)
	else:
		run_runtime_card_resolution_track_flow_bench_requested.emit(RUNTIME_CARD_RESOLUTION_TRACK_FLOW_BENCH_SCENE_PATH)
	_set_status("Run Runtime CardResolutionTrack flow bench: %s" % RUNTIME_CARD_RESOLUTION_TRACK_FLOW_BENCH_SCENE_PATH)


func open_compendium_codex_preview_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", COMPENDIUM_CODEX_PREVIEW_SCENE_PATH)
	else:
		open_compendium_codex_preview_requested.emit(COMPENDIUM_CODEX_PREVIEW_SCENE_PATH)
	_set_status("Open Compendium Codex preview: %s" % COMPENDIUM_CODEX_PREVIEW_SCENE_PATH)


func run_compendium_codex_preview_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", COMPENDIUM_CODEX_PREVIEW_SCENE_PATH)
	else:
		run_compendium_codex_preview_requested.emit(COMPENDIUM_CODEX_PREVIEW_SCENE_PATH)
	_set_status("Run Compendium Codex preview: %s" % COMPENDIUM_CODEX_PREVIEW_SCENE_PATH)


func open_compendium_codex_interaction_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", COMPENDIUM_CODEX_INTERACTION_BENCH_SCENE_PATH)
	else:
		open_compendium_codex_interaction_bench_requested.emit(COMPENDIUM_CODEX_INTERACTION_BENCH_SCENE_PATH)
	_set_status("Open Compendium Codex interaction bench: %s" % COMPENDIUM_CODEX_INTERACTION_BENCH_SCENE_PATH)


func run_compendium_codex_interaction_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", COMPENDIUM_CODEX_INTERACTION_BENCH_SCENE_PATH)
	else:
		run_compendium_codex_interaction_bench_requested.emit(COMPENDIUM_CODEX_INTERACTION_BENCH_SCENE_PATH)
	_set_status("Run Compendium Codex interaction bench: %s" % COMPENDIUM_CODEX_INTERACTION_BENCH_SCENE_PATH)


func open_compendium_content_registry_preview_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", COMPENDIUM_CONTENT_REGISTRY_PREVIEW_SCENE_PATH)
	else:
		open_compendium_content_registry_preview_requested.emit(COMPENDIUM_CONTENT_REGISTRY_PREVIEW_SCENE_PATH)
	_set_status("Open Compendium Content Registry preview: %s" % COMPENDIUM_CONTENT_REGISTRY_PREVIEW_SCENE_PATH)


func run_compendium_content_registry_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", COMPENDIUM_CONTENT_REGISTRY_BENCH_SCENE_PATH)
	else:
		run_compendium_content_registry_bench_requested.emit(COMPENDIUM_CONTENT_REGISTRY_BENCH_SCENE_PATH)
	_set_status("Run Compendium Content Registry bench: %s" % COMPENDIUM_CONTENT_REGISTRY_BENCH_SCENE_PATH)


func open_system_resourceization_audit_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", SYSTEM_RESOURCEIZATION_AUDIT_PREVIEW_SCENE_PATH)
	else:
		open_system_resourceization_audit_requested.emit(SYSTEM_RESOURCEIZATION_AUDIT_PREVIEW_SCENE_PATH)
	_set_status("Open System Resourceization Audit: %s" % SYSTEM_RESOURCEIZATION_AUDIT_PREVIEW_SCENE_PATH)


func run_system_resourceization_audit_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", SYSTEM_RESOURCEIZATION_AUDIT_BENCH_SCENE_PATH)
	else:
		run_system_resourceization_audit_requested.emit(SYSTEM_RESOURCEIZATION_AUDIT_BENCH_SCENE_PATH)
	_set_status("Run System Resourceization Audit: %s" % SYSTEM_RESOURCEIZATION_AUDIT_BENCH_SCENE_PATH)


func open_balance_parameter_resource_preview_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", BALANCE_PARAMETER_RESOURCE_PREVIEW_SCENE_PATH)
	else:
		open_balance_parameter_resource_preview_requested.emit(BALANCE_PARAMETER_RESOURCE_PREVIEW_SCENE_PATH)
	_set_status("Open Balance Parameter Resource preview: %s" % BALANCE_PARAMETER_RESOURCE_PREVIEW_SCENE_PATH)


func run_balance_parameter_resource_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", BALANCE_PARAMETER_RESOURCE_BENCH_SCENE_PATH)
	else:
		run_balance_parameter_resource_bench_requested.emit(BALANCE_PARAMETER_RESOURCE_BENCH_SCENE_PATH)
	_set_status("Run Balance Parameter Resource bench: %s" % BALANCE_PARAMETER_RESOURCE_BENCH_SCENE_PATH)


func open_balance_model_resource_sandbox_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", BALANCE_MODEL_RESOURCE_SANDBOX_SCENE_PATH)
	else:
		open_balance_model_resource_sandbox_requested.emit(BALANCE_MODEL_RESOURCE_SANDBOX_SCENE_PATH)
	_set_status("Open Balance Model Resource sandbox: %s" % BALANCE_MODEL_RESOURCE_SANDBOX_SCENE_PATH)


func run_balance_model_resource_sandbox_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", BALANCE_MODEL_RESOURCE_SANDBOX_BENCH_SCENE_PATH)
	else:
		run_balance_model_resource_sandbox_bench_requested.emit(BALANCE_MODEL_RESOURCE_SANDBOX_BENCH_SCENE_PATH)
	_set_status("Run Balance Model Resource sandbox bench: %s" % BALANCE_MODEL_RESOURCE_SANDBOX_BENCH_SCENE_PATH)


func open_balance_runtime_bridge_preview_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", BALANCE_RUNTIME_BRIDGE_PREVIEW_SCENE_PATH)
	else:
		open_balance_runtime_bridge_requested.emit(BALANCE_RUNTIME_BRIDGE_PREVIEW_SCENE_PATH)
	_set_status("Open Balance Runtime Bridge preview: %s" % BALANCE_RUNTIME_BRIDGE_PREVIEW_SCENE_PATH)


func run_balance_runtime_bridge_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", BALANCE_RUNTIME_BRIDGE_BENCH_SCENE_PATH)
	else:
		run_balance_runtime_bridge_bench_requested.emit(BALANCE_RUNTIME_BRIDGE_BENCH_SCENE_PATH)
	_set_status("Run Balance Runtime Bridge bench: %s" % BALANCE_RUNTIME_BRIDGE_BENCH_SCENE_PATH)


func open_gameplay_balance_diagnostics_service_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", GAMEPLAY_BALANCE_DIAGNOSTICS_SERVICE_SCENE_PATH)
	else:
		open_gameplay_balance_diagnostics_service_requested.emit(GAMEPLAY_BALANCE_DIAGNOSTICS_SERVICE_SCENE_PATH)
	_set_status("Open Gameplay Balance Diagnostics Service: %s" % GAMEPLAY_BALANCE_DIAGNOSTICS_SERVICE_SCENE_PATH)


func open_gameplay_balance_diagnostics_world_bridge_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", GAMEPLAY_BALANCE_DIAGNOSTICS_WORLD_BRIDGE_SCENE_PATH)
	else:
		open_gameplay_balance_diagnostics_world_bridge_requested.emit(GAMEPLAY_BALANCE_DIAGNOSTICS_WORLD_BRIDGE_SCENE_PATH)
	_set_status("Open Gameplay Balance Diagnostics World Bridge: %s" % GAMEPLAY_BALANCE_DIAGNOSTICS_WORLD_BRIDGE_SCENE_PATH)


func open_ruleset_runtime_bridge_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", RULESET_RUNTIME_BRIDGE_SCENE_PATH)
	else:
		open_ruleset_runtime_bridge_requested.emit(RULESET_RUNTIME_BRIDGE_SCENE_PATH)
	_set_status("Open Ruleset Runtime Bridge: %s" % RULESET_RUNTIME_BRIDGE_SCENE_PATH)


func run_ruleset_v04_conformance_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", RULESET_V04_CONFORMANCE_BENCH_SCENE_PATH)
	else:
		run_ruleset_v04_conformance_bench_requested.emit(RULESET_V04_CONFORMANCE_BENCH_SCENE_PATH)
	_set_status("Run Ruleset v0.4 Conformance bench: %s" % RULESET_V04_CONFORMANCE_BENCH_SCENE_PATH)


func open_city_development_runtime_controller_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", CITY_DEVELOPMENT_RUNTIME_CONTROLLER_SCENE_PATH)
	else:
		open_city_development_runtime_controller_requested.emit(CITY_DEVELOPMENT_RUNTIME_CONTROLLER_SCENE_PATH)
	_set_status("Open City Development Runtime Controller: %s" % CITY_DEVELOPMENT_RUNTIME_CONTROLLER_SCENE_PATH)


func open_city_development_world_bridge_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", CITY_DEVELOPMENT_WORLD_BRIDGE_SCENE_PATH)
	else:
		open_city_development_world_bridge_requested.emit(CITY_DEVELOPMENT_WORLD_BRIDGE_SCENE_PATH)
	_set_status("Open City Development World Bridge: %s" % CITY_DEVELOPMENT_WORLD_BRIDGE_SCENE_PATH)


func open_game_runtime_coordinator_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", GAME_RUNTIME_COORDINATOR_SCENE_PATH)
	else:
		open_game_runtime_coordinator_requested.emit(GAME_RUNTIME_COORDINATOR_SCENE_PATH)
	_set_status("Open Game Runtime Coordinator: %s" % GAME_RUNTIME_COORDINATOR_SCENE_PATH)


func open_forced_decision_runtime_scheduler_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", FORCED_DECISION_RUNTIME_SCHEDULER_SCENE_PATH)
	else:
		open_forced_decision_runtime_scheduler_requested.emit(FORCED_DECISION_RUNTIME_SCHEDULER_SCENE_PATH)
	_set_status("Open Forced Decision Runtime Scheduler: %s" % FORCED_DECISION_RUNTIME_SCHEDULER_SCENE_PATH)


func run_forced_decision_runtime_scheduler_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", FORCED_DECISION_RUNTIME_SCHEDULER_BENCH_SCENE_PATH)
	else:
		run_forced_decision_runtime_scheduler_bench_requested.emit(FORCED_DECISION_RUNTIME_SCHEDULER_BENCH_SCENE_PATH)
	_set_status("Run Forced Decision Runtime Scheduler bench: %s" % FORCED_DECISION_RUNTIME_SCHEDULER_BENCH_SCENE_PATH)


func open_game_session_runtime_controller_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", GAME_SESSION_RUNTIME_CONTROLLER_SCENE_PATH)
	else:
		open_game_session_runtime_controller_requested.emit(GAME_SESSION_RUNTIME_CONTROLLER_SCENE_PATH)
	_set_status("Open Game Session Runtime Controller: %s" % GAME_SESSION_RUNTIME_CONTROLLER_SCENE_PATH)


func open_game_save_runtime_coordinator_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", GAME_SAVE_RUNTIME_COORDINATOR_SCENE_PATH)
	else:
		open_game_save_runtime_coordinator_requested.emit(GAME_SAVE_RUNTIME_COORDINATOR_SCENE_PATH)
	_set_status("Open Game Save Runtime Coordinator: %s" % GAME_SAVE_RUNTIME_COORDINATOR_SCENE_PATH)


func run_game_session_save_ownership_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", GAME_SESSION_SAVE_OWNERSHIP_BENCH_SCENE_PATH)
	else:
		run_game_session_save_ownership_bench_requested.emit(GAME_SESSION_SAVE_OWNERSHIP_BENCH_SCENE_PATH)
	_set_status("Run Game Session & Save Ownership bench: %s" % GAME_SESSION_SAVE_OWNERSHIP_BENCH_SCENE_PATH)


func open_district_purchase_runtime_controller_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", DISTRICT_PURCHASE_RUNTIME_CONTROLLER_SCENE_PATH)
	else:
		open_district_purchase_runtime_controller_requested.emit(DISTRICT_PURCHASE_RUNTIME_CONTROLLER_SCENE_PATH)
	_set_status("Open District Purchase Runtime Controller: %s" % DISTRICT_PURCHASE_RUNTIME_CONTROLLER_SCENE_PATH)


func open_district_purchase_settlement_runtime_service_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", DISTRICT_PURCHASE_SETTLEMENT_RUNTIME_SERVICE_SCENE_PATH)
	else:
		open_district_purchase_settlement_runtime_service_requested.emit(DISTRICT_PURCHASE_SETTLEMENT_RUNTIME_SERVICE_SCENE_PATH)
	_set_status("Open District Purchase Settlement Service: %s" % DISTRICT_PURCHASE_SETTLEMENT_RUNTIME_SERVICE_SCENE_PATH)


func open_district_supply_drawer_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", DISTRICT_SUPPLY_DRAWER_SCENE_PATH)
	else:
		open_district_supply_drawer_requested.emit(DISTRICT_SUPPLY_DRAWER_SCENE_PATH)
	_set_status("Open District Supply Drawer: %s" % DISTRICT_SUPPLY_DRAWER_SCENE_PATH)


func open_district_supply_snapshot_service_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", DISTRICT_SUPPLY_SNAPSHOT_SERVICE_SCENE_PATH)
	else:
		open_district_supply_snapshot_service_requested.emit(DISTRICT_SUPPLY_SNAPSHOT_SERVICE_SCENE_PATH)
	_set_status("Open District Supply Snapshot Service: %s" % DISTRICT_SUPPLY_SNAPSHOT_SERVICE_SCENE_PATH)


func run_district_purchase_runtime_cutover_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", DISTRICT_PURCHASE_RUNTIME_CUTOVER_BENCH_SCENE_PATH)
	else:
		run_district_purchase_runtime_cutover_bench_requested.emit(DISTRICT_PURCHASE_RUNTIME_CUTOVER_BENCH_SCENE_PATH)
	_set_status("Run District Purchase QA: 45 ownership + 17 characterization + 18 service cases")


func open_card_inventory_runtime_service_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", CARD_INVENTORY_RUNTIME_SERVICE_SCENE_PATH)
	else:
		open_card_inventory_runtime_service_requested.emit(CARD_INVENTORY_RUNTIME_SERVICE_SCENE_PATH)
	_set_status("Open Card Inventory Runtime Service: %s" % CARD_INVENTORY_RUNTIME_SERVICE_SCENE_PATH)


func open_card_inventory_runtime_characterization_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", CARD_INVENTORY_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	else:
		open_card_inventory_runtime_characterization_bench_requested.emit(CARD_INVENTORY_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	_set_status("Open Card Inventory Cutover QA: %s" % CARD_INVENTORY_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)


func run_card_inventory_runtime_characterization_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", CARD_INVENTORY_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	else:
		run_card_inventory_runtime_characterization_bench_requested.emit(CARD_INVENTORY_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	_set_status("Run Card Inventory QA: 20 characterization + 20 cutover cases")


func open_player_hand_interaction_runtime_service_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", PLAYER_HAND_INTERACTION_RUNTIME_SERVICE_SCENE_PATH)
	else:
		open_player_hand_interaction_runtime_service_requested.emit(PLAYER_HAND_INTERACTION_RUNTIME_SERVICE_SCENE_PATH)
	_set_status("Open Player Hand Interaction Runtime Service: %s" % PLAYER_HAND_INTERACTION_RUNTIME_SERVICE_SCENE_PATH)


func open_player_hand_interaction_runtime_characterization_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", PLAYER_HAND_INTERACTION_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	else:
		open_player_hand_interaction_runtime_characterization_bench_requested.emit(PLAYER_HAND_INTERACTION_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	_set_status("Open Player Hand Interaction Cutover QA: %s" % PLAYER_HAND_INTERACTION_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)


func run_player_hand_interaction_runtime_characterization_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", PLAYER_HAND_INTERACTION_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	else:
		run_player_hand_interaction_runtime_characterization_bench_requested.emit(PLAYER_HAND_INTERACTION_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	_set_status("Run Player Hand Interaction QA: 20 characterization + 20 cutover cases")


func open_card_resolution_queue_runtime_service_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", CARD_RESOLUTION_QUEUE_RUNTIME_SERVICE_SCENE_PATH)
	else:
		open_card_resolution_queue_runtime_service_requested.emit(CARD_RESOLUTION_QUEUE_RUNTIME_SERVICE_SCENE_PATH)
	_set_status("Open Card Resolution Queue Runtime Service: %s" % CARD_RESOLUTION_QUEUE_RUNTIME_SERVICE_SCENE_PATH)


func open_card_resolution_queue_runtime_characterization_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", CARD_RESOLUTION_QUEUE_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	else:
		open_card_resolution_queue_runtime_characterization_bench_requested.emit(CARD_RESOLUTION_QUEUE_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	_set_status("Open Card Resolution Queue Cutover QA: %s" % CARD_RESOLUTION_QUEUE_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)


func run_card_resolution_queue_runtime_characterization_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", CARD_RESOLUTION_QUEUE_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	else:
		run_card_resolution_queue_runtime_characterization_bench_requested.emit(CARD_RESOLUTION_QUEUE_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	_set_status("Run Card Resolution Queue QA: 28 characterization + 28 cutover cases")


func open_card_resolution_execution_runtime_service_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", CARD_RESOLUTION_EXECUTION_RUNTIME_SERVICE_SCENE_PATH)
	else:
		open_card_resolution_execution_runtime_service_requested.emit(CARD_RESOLUTION_EXECUTION_RUNTIME_SERVICE_SCENE_PATH)
	_set_status("Open Card Resolution Execution Runtime Service: %s" % CARD_RESOLUTION_EXECUTION_RUNTIME_SERVICE_SCENE_PATH)


func open_card_resolution_execution_runtime_characterization_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", CARD_RESOLUTION_EXECUTION_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	else:
		open_card_resolution_execution_runtime_characterization_bench_requested.emit(CARD_RESOLUTION_EXECUTION_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	_set_status("Open Card Resolution Execution Cutover QA: %s" % CARD_RESOLUTION_EXECUTION_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)


func run_card_resolution_execution_runtime_characterization_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", CARD_RESOLUTION_EXECUTION_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	else:
		run_card_resolution_execution_runtime_characterization_bench_requested.emit(CARD_RESOLUTION_EXECUTION_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	_set_status("Run Card Resolution Execution QA: 28 observations + 40 cutover cases")


func open_card_economy_product_route_effect_runtime_service_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", CARD_ECONOMY_PRODUCT_ROUTE_EFFECT_RUNTIME_SERVICE_SCENE_PATH)
	else:
		open_card_economy_product_route_effect_runtime_service_requested.emit(CARD_ECONOMY_PRODUCT_ROUTE_EFFECT_RUNTIME_SERVICE_SCENE_PATH)
	_set_status("Open Economy / Product / Route Effect Runtime Service: %s" % CARD_ECONOMY_PRODUCT_ROUTE_EFFECT_RUNTIME_SERVICE_SCENE_PATH)


func open_card_economy_product_route_formula_runtime_service_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", CARD_ECONOMY_PRODUCT_ROUTE_FORMULA_RUNTIME_SERVICE_SCENE_PATH)
	else:
		open_card_economy_product_route_formula_runtime_service_requested.emit(CARD_ECONOMY_PRODUCT_ROUTE_FORMULA_RUNTIME_SERVICE_SCENE_PATH)
	_set_status("Open Economy / Product / Route Formula Runtime Service: %s" % CARD_ECONOMY_PRODUCT_ROUTE_FORMULA_RUNTIME_SERVICE_SCENE_PATH)


func open_economy_cashflow_runtime_controller_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", ECONOMY_CASHFLOW_RUNTIME_CONTROLLER_SCENE_PATH)
	else:
		open_economy_cashflow_runtime_controller_requested.emit(ECONOMY_CASHFLOW_RUNTIME_CONTROLLER_SCENE_PATH)
	_set_status("Open Economy Cashflow Runtime Controller: %s" % ECONOMY_CASHFLOW_RUNTIME_CONTROLLER_SCENE_PATH)


func run_economy_cashflow_runtime_cutover_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", ECONOMY_CASHFLOW_RUNTIME_CUTOVER_BENCH_SCENE_PATH)
	else:
		run_economy_cashflow_runtime_cutover_bench_requested.emit(ECONOMY_CASHFLOW_RUNTIME_CUTOVER_BENCH_SCENE_PATH)
	_set_status("Run Economy Cashflow Runtime Cutover bench: %s" % ECONOMY_CASHFLOW_RUNTIME_CUTOVER_BENCH_SCENE_PATH)


func open_gdp_formula_runtime_controller_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", GDP_FORMULA_RUNTIME_CONTROLLER_SCENE_PATH)
	else:
		open_gdp_formula_runtime_controller_requested.emit(GDP_FORMULA_RUNTIME_CONTROLLER_SCENE_PATH)
	_set_status("Open GDP Formula Runtime Controller: %s" % GDP_FORMULA_RUNTIME_CONTROLLER_SCENE_PATH)


func run_gdp_formula_runtime_cutover_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", GDP_FORMULA_RUNTIME_CUTOVER_BENCH_SCENE_PATH)
	else:
		run_gdp_formula_runtime_cutover_bench_requested.emit(GDP_FORMULA_RUNTIME_CUTOVER_BENCH_SCENE_PATH)
	_set_status("Run GDP Formula Runtime Cutover bench: %s" % GDP_FORMULA_RUNTIME_CUTOVER_BENCH_SCENE_PATH)


func open_scenario_runtime_controller_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", SCENARIO_RUNTIME_CONTROLLER_SCENE_PATH)
	else:
		open_scenario_runtime_controller_requested.emit(SCENARIO_RUNTIME_CONTROLLER_SCENE_PATH)
	_set_status("Open Scenario Runtime Controller: %s" % SCENARIO_RUNTIME_CONTROLLER_SCENE_PATH)


func run_scenario_runtime_glue_cutover_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", SCENARIO_RUNTIME_GLUE_CUTOVER_BENCH_SCENE_PATH)
	else:
		run_scenario_runtime_glue_cutover_bench_requested.emit(SCENARIO_RUNTIME_GLUE_CUTOVER_BENCH_SCENE_PATH)
	_set_status("Run Scenario Runtime Glue Cutover bench: %s" % SCENARIO_RUNTIME_GLUE_CUTOVER_BENCH_SCENE_PATH)


func open_first_table_authored_runtime_service_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", FIRST_TABLE_AUTHORED_RUNTIME_SERVICE_SCENE_PATH)
	else:
		open_first_table_authored_runtime_service_requested.emit(FIRST_TABLE_AUTHORED_RUNTIME_SERVICE_SCENE_PATH)
	_set_status("Open First Table Authored Runtime Service: %s" % FIRST_TABLE_AUTHORED_RUNTIME_SERVICE_SCENE_PATH)


func run_first_table_authored_runtime_cutover_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", FIRST_TABLE_AUTHORED_RUNTIME_CUTOVER_BENCH_SCENE_PATH)
	else:
		run_first_table_authored_runtime_cutover_bench_requested.emit(FIRST_TABLE_AUTHORED_RUNTIME_CUTOVER_BENCH_SCENE_PATH)
	_set_status("Run First Table Authored Runtime Cutover bench: %s" % FIRST_TABLE_AUTHORED_RUNTIME_CUTOVER_BENCH_SCENE_PATH)


func open_sceneized_main_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", SCENEIZED_MAIN_SCENE_PATH)
	else:
		open_sceneized_main_requested.emit(SCENEIZED_MAIN_SCENE_PATH)
	_set_status("Open sceneized main table: %s" % SCENEIZED_MAIN_SCENE_PATH)


func run_legacy_runtime_surface_retirement_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", LEGACY_RUNTIME_SURFACE_RETIREMENT_BENCH_SCENE_PATH)
	else:
		run_legacy_runtime_surface_retirement_bench_requested.emit(LEGACY_RUNTIME_SURFACE_RETIREMENT_BENCH_SCENE_PATH)
	_set_status("Run Legacy Runtime Surface Retirement bench: %s" % LEGACY_RUNTIME_SURFACE_RETIREMENT_BENCH_SCENE_PATH)


func open_legacy_player_surface_retirement_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", LEGACY_PLAYER_SURFACE_RETIREMENT_BENCH_SCENE_PATH)
	else:
		open_legacy_player_surface_retirement_bench_requested.emit(LEGACY_PLAYER_SURFACE_RETIREMENT_BENCH_SCENE_PATH)
	_set_status("Open Legacy Player Surface Retirement bench: %s" % LEGACY_PLAYER_SURFACE_RETIREMENT_BENCH_SCENE_PATH)


func run_legacy_player_surface_retirement_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", LEGACY_PLAYER_SURFACE_RETIREMENT_BENCH_SCENE_PATH)
	else:
		run_legacy_player_surface_retirement_bench_requested.emit(LEGACY_PLAYER_SURFACE_RETIREMENT_BENCH_SCENE_PATH)
	_set_status("Run Legacy Player Surface Retirement bench: %s" % LEGACY_PLAYER_SURFACE_RETIREMENT_BENCH_SCENE_PATH)


func open_card_presentation_runtime_service_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", CARD_PRESENTATION_RUNTIME_SERVICE_SCENE_PATH)
	else:
		open_card_presentation_runtime_service_requested.emit(CARD_PRESENTATION_RUNTIME_SERVICE_SCENE_PATH)
	_set_status("Open Card Presentation Runtime Service: %s" % CARD_PRESENTATION_RUNTIME_SERVICE_SCENE_PATH)


func open_game_table_viewmodel_runtime_service_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", GAME_TABLE_VIEWMODEL_RUNTIME_SERVICE_SCENE_PATH)
	else:
		open_game_table_viewmodel_runtime_service_requested.emit(GAME_TABLE_VIEWMODEL_RUNTIME_SERVICE_SCENE_PATH)
	_set_status("Open Game Table ViewModel Runtime Service: %s" % GAME_TABLE_VIEWMODEL_RUNTIME_SERVICE_SCENE_PATH)


func open_card_play_eligibility_runtime_service_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", CARD_PLAY_ELIGIBILITY_RUNTIME_SERVICE_SCENE_PATH)
	else:
		open_card_play_eligibility_runtime_service_requested.emit(CARD_PLAY_ELIGIBILITY_RUNTIME_SERVICE_SCENE_PATH)
	_set_status("Open Card Play Eligibility Runtime Service: %s" % CARD_PLAY_ELIGIBILITY_RUNTIME_SERVICE_SCENE_PATH)


func open_card_play_eligibility_world_bridge_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", CARD_PLAY_ELIGIBILITY_WORLD_BRIDGE_SCENE_PATH)
	else:
		open_card_play_eligibility_world_bridge_requested.emit(CARD_PLAY_ELIGIBILITY_WORLD_BRIDGE_SCENE_PATH)
	_set_status("Open Card Play Eligibility World Bridge: %s" % CARD_PLAY_ELIGIBILITY_WORLD_BRIDGE_SCENE_PATH)


func open_card_play_eligibility_runtime_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", CARD_PLAY_ELIGIBILITY_RUNTIME_BENCH_SCENE_PATH)
	else:
		open_card_play_eligibility_runtime_bench_requested.emit(CARD_PLAY_ELIGIBILITY_RUNTIME_BENCH_SCENE_PATH)
	_set_status("Open Card Play Eligibility Runtime bench: %s" % CARD_PLAY_ELIGIBILITY_RUNTIME_BENCH_SCENE_PATH)


func run_card_play_eligibility_runtime_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", CARD_PLAY_ELIGIBILITY_RUNTIME_BENCH_SCENE_PATH)
	else:
		run_card_play_eligibility_runtime_bench_requested.emit(CARD_PLAY_ELIGIBILITY_RUNTIME_BENCH_SCENE_PATH)
	_set_status("Run Card Play Eligibility Runtime bench: %s" % CARD_PLAY_ELIGIBILITY_RUNTIME_BENCH_SCENE_PATH)


func open_menu_shell_runtime_cutover_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", MENU_SHELL_RUNTIME_CUTOVER_BENCH_SCENE_PATH)
	else:
		open_menu_shell_runtime_cutover_bench_requested.emit(MENU_SHELL_RUNTIME_CUTOVER_BENCH_SCENE_PATH)
	_set_status("Open Menu Shell Runtime Cutover bench: %s" % MENU_SHELL_RUNTIME_CUTOVER_BENCH_SCENE_PATH)


func run_menu_shell_runtime_cutover_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", MENU_SHELL_RUNTIME_CUTOVER_BENCH_SCENE_PATH)
	else:
		run_menu_shell_runtime_cutover_bench_requested.emit(MENU_SHELL_RUNTIME_CUTOVER_BENCH_SCENE_PATH)
	_set_status("Run Menu 24-case gate + Global Navigation 32-case characterization: %s" % MENU_SHELL_RUNTIME_CUTOVER_BENCH_SCENE_PATH)


func open_codex_scene_hard_cutover_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", CODEX_SCENE_HARD_CUTOVER_BENCH_SCENE_PATH)
	else:
		open_codex_scene_hard_cutover_bench_requested.emit(CODEX_SCENE_HARD_CUTOVER_BENCH_SCENE_PATH)
	_set_status("Open Codex Scene Hard Cutover bench: %s" % CODEX_SCENE_HARD_CUTOVER_BENCH_SCENE_PATH)


func run_codex_scene_hard_cutover_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", CODEX_SCENE_HARD_CUTOVER_BENCH_SCENE_PATH)
	else:
		run_codex_scene_hard_cutover_bench_requested.emit(CODEX_SCENE_HARD_CUTOVER_BENCH_SCENE_PATH)
	_set_status("Run Codex Scene Hard Cutover bench: %s" % CODEX_SCENE_HARD_CUTOVER_BENCH_SCENE_PATH)


func open_codex_atlas_scene_cutover_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", CODEX_ATLAS_SCENE_CUTOVER_BENCH_SCENE_PATH)
	else:
		open_codex_atlas_scene_cutover_bench_requested.emit(CODEX_ATLAS_SCENE_CUTOVER_BENCH_SCENE_PATH)
	_set_status("Open Codex Atlas Scene Cutover bench: %s" % CODEX_ATLAS_SCENE_CUTOVER_BENCH_SCENE_PATH)


func run_codex_atlas_scene_cutover_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", CODEX_ATLAS_SCENE_CUTOVER_BENCH_SCENE_PATH)
	else:
		run_codex_atlas_scene_cutover_bench_requested.emit(CODEX_ATLAS_SCENE_CUTOVER_BENCH_SCENE_PATH)
	_set_status("Run Codex Atlas Scene Cutover bench: %s" % CODEX_ATLAS_SCENE_CUTOVER_BENCH_SCENE_PATH)


func open_codex_navigation_runtime_controller_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", CODEX_NAVIGATION_RUNTIME_CONTROLLER_SCENE_PATH)
	else:
		open_codex_navigation_runtime_controller_requested.emit(CODEX_NAVIGATION_RUNTIME_CONTROLLER_SCENE_PATH)
	_set_status("Open Codex Navigation Runtime Controller: %s" % CODEX_NAVIGATION_RUNTIME_CONTROLLER_SCENE_PATH)


func run_codex_navigation_runtime_cutover_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", CODEX_NAVIGATION_RUNTIME_CUTOVER_BENCH_SCENE_PATH)
	else:
		run_codex_navigation_runtime_cutover_bench_requested.emit(CODEX_NAVIGATION_RUNTIME_CUTOVER_BENCH_SCENE_PATH)
	_set_status("Run Codex Navigation Runtime Cutover bench: %s" % CODEX_NAVIGATION_RUNTIME_CUTOVER_BENCH_SCENE_PATH)


func open_codex_public_snapshot_service_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", CODEX_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH)
	else:
		open_codex_public_snapshot_service_requested.emit(CODEX_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH)
	_set_status("Open Codex Public Snapshot Service: %s" % CODEX_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH)


func run_codex_public_snapshot_cutover_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", CODEX_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH)
	else:
		run_codex_public_snapshot_cutover_bench_requested.emit(CODEX_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH)
	_set_status("Run Codex Public Snapshot Cutover bench: %s" % CODEX_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH)


func open_monster_codex_public_snapshot_service_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", MONSTER_CODEX_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH)
	else:
		open_monster_codex_public_snapshot_service_requested.emit(MONSTER_CODEX_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH)
	_set_status("Open Monster Codex Public Snapshot Service: %s" % MONSTER_CODEX_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH)


func run_monster_codex_public_snapshot_cutover_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", MONSTER_CODEX_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH)
	else:
		run_monster_codex_public_snapshot_cutover_bench_requested.emit(MONSTER_CODEX_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH)
	_set_status("Run Monster Codex Public Snapshot Cutover bench: %s" % MONSTER_CODEX_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH)


func open_monster_runtime_characterization_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", MONSTER_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	else:
		open_monster_runtime_characterization_bench_requested.emit(MONSTER_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	_set_status("Open Monster Runtime Characterization bench: %s" % MONSTER_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)


func open_monster_runtime_controller_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", MONSTER_RUNTIME_CONTROLLER_SCENE_PATH)
	else:
		open_monster_runtime_controller_requested.emit(MONSTER_RUNTIME_CONTROLLER_SCENE_PATH)
	_set_status("Open Monster Runtime Controller: %s" % MONSTER_RUNTIME_CONTROLLER_SCENE_PATH)


func open_monster_runtime_world_bridge_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", MONSTER_RUNTIME_WORLD_BRIDGE_SCENE_PATH)
	else:
		open_monster_runtime_world_bridge_requested.emit(MONSTER_RUNTIME_WORLD_BRIDGE_SCENE_PATH)
	_set_status("Open Monster Runtime World Bridge: %s" % MONSTER_RUNTIME_WORLD_BRIDGE_SCENE_PATH)


func run_monster_runtime_characterization_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", MONSTER_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	else:
		run_monster_runtime_characterization_bench_requested.emit(MONSTER_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	_set_status("Run Monster Runtime Characterization bench: %s" % MONSTER_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)


func open_military_runtime_characterization_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", MILITARY_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	else:
		open_military_runtime_characterization_bench_requested.emit(MILITARY_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	_set_status("Open Military Runtime Characterization bench: %s" % MILITARY_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)


func open_military_runtime_controller_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", MILITARY_RUNTIME_CONTROLLER_SCENE_PATH)
	else:
		open_military_runtime_controller_requested.emit(MILITARY_RUNTIME_CONTROLLER_SCENE_PATH)
	_set_status("Open Military Runtime Controller: %s" % MILITARY_RUNTIME_CONTROLLER_SCENE_PATH)


func open_military_runtime_world_bridge_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", MILITARY_RUNTIME_WORLD_BRIDGE_SCENE_PATH)
	else:
		open_military_runtime_world_bridge_requested.emit(MILITARY_RUNTIME_WORLD_BRIDGE_SCENE_PATH)
	_set_status("Open Military Runtime World Bridge: %s" % MILITARY_RUNTIME_WORLD_BRIDGE_SCENE_PATH)


func run_military_runtime_characterization_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", MILITARY_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	else:
		run_military_runtime_characterization_bench_requested.emit(MILITARY_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	_set_status("Run Military Runtime Characterization bench: %s" % MILITARY_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)


func open_weather_runtime_characterization_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", WEATHER_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	else:
		open_weather_runtime_characterization_bench_requested.emit(WEATHER_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	_set_status("Open Weather Runtime Characterization bench: %s" % WEATHER_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)


func open_weather_runtime_controller_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", WEATHER_RUNTIME_CONTROLLER_SCENE_PATH)
	else:
		open_weather_runtime_controller_requested.emit(WEATHER_RUNTIME_CONTROLLER_SCENE_PATH)
	_set_status("Open Weather Runtime Controller: %s" % WEATHER_RUNTIME_CONTROLLER_SCENE_PATH)


func open_weather_runtime_world_bridge_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", WEATHER_RUNTIME_WORLD_BRIDGE_SCENE_PATH)
	else:
		open_weather_runtime_world_bridge_requested.emit(WEATHER_RUNTIME_WORLD_BRIDGE_SCENE_PATH)
	_set_status("Open Weather Runtime World Bridge: %s" % WEATHER_RUNTIME_WORLD_BRIDGE_SCENE_PATH)


func run_weather_runtime_characterization_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", WEATHER_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	else:
		run_weather_runtime_characterization_bench_requested.emit(WEATHER_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	_set_status("Run Weather Runtime Characterization bench: %s" % WEATHER_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)


func open_contract_runtime_controller_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", CONTRACT_RUNTIME_CONTROLLER_SCENE_PATH)
	else:
		open_contract_runtime_controller_requested.emit(CONTRACT_RUNTIME_CONTROLLER_SCENE_PATH)
	_set_status("Open Contract Runtime Controller: %s" % CONTRACT_RUNTIME_CONTROLLER_SCENE_PATH)


func open_contract_runtime_world_bridge_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", CONTRACT_RUNTIME_WORLD_BRIDGE_SCENE_PATH)
	else:
		open_contract_runtime_world_bridge_requested.emit(CONTRACT_RUNTIME_WORLD_BRIDGE_SCENE_PATH)
	_set_status("Open Contract Runtime World Bridge: %s" % CONTRACT_RUNTIME_WORLD_BRIDGE_SCENE_PATH)


func open_contract_runtime_characterization_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", CONTRACT_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	else:
		open_contract_runtime_characterization_bench_requested.emit(CONTRACT_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	_set_status("Open Contract Runtime Characterization bench: %s" % CONTRACT_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)


func run_contract_runtime_characterization_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", CONTRACT_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	else:
		run_contract_runtime_characterization_bench_requested.emit(CONTRACT_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	_set_status("Run Contract Runtime Characterization bench: %s" % CONTRACT_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)


func open_product_market_runtime_characterization_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", PRODUCT_MARKET_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	else:
		open_product_market_runtime_characterization_bench_requested.emit(PRODUCT_MARKET_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	_set_status("Open Product Market Runtime Characterization bench: %s" % PRODUCT_MARKET_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)


func run_product_market_runtime_characterization_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", PRODUCT_MARKET_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	else:
		run_product_market_runtime_characterization_bench_requested.emit(PRODUCT_MARKET_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	_set_status("Run Product Market Runtime Characterization bench: %s" % PRODUCT_MARKET_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)


func open_product_futures_terms_catalog() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_resource"):
		_editor_plugin.call("open_resource", PRODUCT_FUTURES_TERMS_CATALOG_PATH)
	else:
		open_product_futures_terms_catalog_requested.emit(PRODUCT_FUTURES_TERMS_CATALOG_PATH)
	_set_status("Open Product Futures v0.4 terms catalog: %s" % PRODUCT_FUTURES_TERMS_CATALOG_PATH)


func open_city_trade_network_runtime_controller_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", CITY_TRADE_NETWORK_RUNTIME_CONTROLLER_SCENE_PATH)
	else:
		open_city_trade_network_runtime_controller_requested.emit(CITY_TRADE_NETWORK_RUNTIME_CONTROLLER_SCENE_PATH)
	_set_status("Open City / Trade Network runtime controller: %s" % CITY_TRADE_NETWORK_RUNTIME_CONTROLLER_SCENE_PATH)


func open_city_trade_network_runtime_world_bridge_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", CITY_TRADE_NETWORK_RUNTIME_WORLD_BRIDGE_SCENE_PATH)
	else:
		open_city_trade_network_world_bridge_requested.emit(CITY_TRADE_NETWORK_RUNTIME_WORLD_BRIDGE_SCENE_PATH)
	_set_status("Open City / Trade Network world bridge: %s" % CITY_TRADE_NETWORK_RUNTIME_WORLD_BRIDGE_SCENE_PATH)


func open_city_trade_network_runtime_characterization_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", CITY_TRADE_NETWORK_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	else:
		open_city_trade_network_runtime_characterization_bench_requested.emit(CITY_TRADE_NETWORK_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	_set_status("Open City / Trade Network Characterization bench: %s" % CITY_TRADE_NETWORK_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)


func run_city_trade_network_runtime_characterization_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", CITY_TRADE_NETWORK_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	else:
		run_city_trade_network_runtime_characterization_bench_requested.emit(CITY_TRADE_NETWORK_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)
	_set_status("Run City / Trade Network Characterization bench: %s" % CITY_TRADE_NETWORK_RUNTIME_CHARACTERIZATION_BENCH_SCENE_PATH)


func open_city_development_settlement_characterization_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", CITY_DEVELOPMENT_SETTLEMENT_CHARACTERIZATION_BENCH_SCENE_PATH)
	else:
		open_city_development_settlement_characterization_bench_requested.emit(CITY_DEVELOPMENT_SETTLEMENT_CHARACTERIZATION_BENCH_SCENE_PATH)
	_set_status("Open City Development Settlement Characterization bench: %s" % CITY_DEVELOPMENT_SETTLEMENT_CHARACTERIZATION_BENCH_SCENE_PATH)


func run_city_development_settlement_characterization_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", CITY_DEVELOPMENT_SETTLEMENT_CHARACTERIZATION_BENCH_SCENE_PATH)
	else:
		run_city_development_settlement_characterization_bench_requested.emit(CITY_DEVELOPMENT_SETTLEMENT_CHARACTERIZATION_BENCH_SCENE_PATH)
	_set_status("Run City Development Settlement Characterization bench: %s" % CITY_DEVELOPMENT_SETTLEMENT_CHARACTERIZATION_BENCH_SCENE_PATH)


func open_city_gdp_derivative_runtime_controller_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", CITY_GDP_DERIVATIVE_RUNTIME_CONTROLLER_SCENE_PATH)
	else:
		open_city_gdp_derivative_runtime_controller_requested.emit(CITY_GDP_DERIVATIVE_RUNTIME_CONTROLLER_SCENE_PATH)
	_set_status("Open City GDP Derivative Runtime Controller: %s" % CITY_GDP_DERIVATIVE_RUNTIME_CONTROLLER_SCENE_PATH)


func open_city_gdp_derivative_runtime_world_bridge_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", CITY_GDP_DERIVATIVE_RUNTIME_WORLD_BRIDGE_SCENE_PATH)
	else:
		open_city_gdp_derivative_runtime_world_bridge_requested.emit(CITY_GDP_DERIVATIVE_RUNTIME_WORLD_BRIDGE_SCENE_PATH)
	_set_status("Open City GDP Derivative Runtime World Bridge: %s" % CITY_GDP_DERIVATIVE_RUNTIME_WORLD_BRIDGE_SCENE_PATH)


func open_city_gdp_derivative_runtime_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", CITY_GDP_DERIVATIVE_RUNTIME_BENCH_SCENE_PATH)
	else:
		open_city_gdp_derivative_runtime_bench_requested.emit(CITY_GDP_DERIVATIVE_RUNTIME_BENCH_SCENE_PATH)
	_set_status("Open City GDP Derivative Runtime Bench: %s" % CITY_GDP_DERIVATIVE_RUNTIME_BENCH_SCENE_PATH)


func run_city_gdp_derivative_runtime_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", CITY_GDP_DERIVATIVE_RUNTIME_BENCH_SCENE_PATH)
	else:
		run_city_gdp_derivative_runtime_bench_requested.emit(CITY_GDP_DERIVATIVE_RUNTIME_BENCH_SCENE_PATH)
	_set_status("Run City GDP Derivative Runtime Bench: %s" % CITY_GDP_DERIVATIVE_RUNTIME_BENCH_SCENE_PATH)


func open_city_gdp_derivative_terms_catalog() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_resource"):
		_editor_plugin.call("open_resource", CITY_GDP_DERIVATIVE_TERMS_CATALOG_PATH)
	else:
		open_city_gdp_derivative_terms_catalog_requested.emit(CITY_GDP_DERIVATIVE_TERMS_CATALOG_PATH)
	_set_status("Open City GDP Derivative v0.4 terms catalog: %s" % CITY_GDP_DERIVATIVE_TERMS_CATALOG_PATH)


func open_product_codex_public_snapshot_service_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", PRODUCT_CODEX_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH)
	else:
		open_product_codex_public_snapshot_service_requested.emit(PRODUCT_CODEX_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH)
	_set_status("Open Product Codex Public Snapshot Service: %s" % PRODUCT_CODEX_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH)


func run_product_codex_public_snapshot_cutover_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", PRODUCT_CODEX_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH)
	else:
		run_product_codex_public_snapshot_cutover_bench_requested.emit(PRODUCT_CODEX_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH)
	_set_status("Run Product Codex Public Snapshot Cutover bench: %s" % PRODUCT_CODEX_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH)


func open_card_codex_public_snapshot_service_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", CARD_CODEX_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH)
	else:
		open_card_codex_public_snapshot_service_requested.emit(CARD_CODEX_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH)
	_set_status("Open Card Codex Public Snapshot Service: %s" % CARD_CODEX_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH)


func run_card_codex_public_snapshot_cutover_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", CARD_CODEX_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH)
	else:
		run_card_codex_public_snapshot_cutover_bench_requested.emit(CARD_CODEX_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH)
	_set_status("Run Card Codex Public Snapshot Cutover bench: %s" % CARD_CODEX_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH)


func open_runtime_card_catalog() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_resource"):
		_editor_plugin.call("open_resource", RUNTIME_CARD_CATALOG_RESOURCE_PATH)
	else:
		open_runtime_card_catalog_requested.emit(RUNTIME_CARD_CATALOG_RESOURCE_PATH)
	_set_status("Open Runtime Card Catalog: %s" % RUNTIME_CARD_CATALOG_RESOURCE_PATH)


func open_runtime_card_catalog_service_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", RUNTIME_CARD_CATALOG_SERVICE_SCENE_PATH)
	else:
		open_runtime_card_catalog_service_requested.emit(RUNTIME_CARD_CATALOG_SERVICE_SCENE_PATH)
	_set_status("Open Runtime Card Catalog Service: %s" % RUNTIME_CARD_CATALOG_SERVICE_SCENE_PATH)


func run_runtime_card_catalog_resource_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", RUNTIME_CARD_CATALOG_RESOURCE_BENCH_SCENE_PATH)
	else:
		run_runtime_card_catalog_resource_bench_requested.emit(RUNTIME_CARD_CATALOG_RESOURCE_BENCH_SCENE_PATH)
	_set_status("Run Runtime Card Catalog Resource bench: %s" % RUNTIME_CARD_CATALOG_RESOURCE_BENCH_SCENE_PATH)


func open_runtime_card_authoring_workspace_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", RUNTIME_CARD_AUTHORING_WORKSPACE_SCENE_PATH)
	else:
		open_runtime_card_authoring_workspace_requested.emit(RUNTIME_CARD_AUTHORING_WORKSPACE_SCENE_PATH)
	_set_status("Open Runtime Card Authoring Workspace: %s" % RUNTIME_CARD_AUTHORING_WORKSPACE_SCENE_PATH)


func open_runtime_card_authoring_sample_family() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_resource"):
		_editor_plugin.call("open_resource", RUNTIME_CARD_AUTHORING_SAMPLE_FAMILY_PATH)
	else:
		open_runtime_card_authoring_sample_family_requested.emit(RUNTIME_CARD_AUTHORING_SAMPLE_FAMILY_PATH)
	_set_status("Open authoring sample family: %s" % RUNTIME_CARD_AUTHORING_SAMPLE_FAMILY_PATH)


func run_runtime_card_authoring_workflow_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", RUNTIME_CARD_AUTHORING_WORKFLOW_BENCH_SCENE_PATH)
	else:
		run_runtime_card_authoring_workflow_bench_requested.emit(RUNTIME_CARD_AUTHORING_WORKFLOW_BENCH_SCENE_PATH)
	_set_status("Run Runtime Card Authoring Workflow bench: %s" % RUNTIME_CARD_AUTHORING_WORKFLOW_BENCH_SCENE_PATH)


func open_economy_dashboard_public_snapshot_service_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", ECONOMY_DASHBOARD_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH)
	else:
		open_economy_dashboard_public_snapshot_service_requested.emit(ECONOMY_DASHBOARD_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH)
	_set_status("Open Economy Dashboard Public Snapshot Service: %s" % ECONOMY_DASHBOARD_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH)


func run_economy_dashboard_public_snapshot_cutover_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", ECONOMY_DASHBOARD_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH)
	else:
		run_economy_dashboard_public_snapshot_cutover_bench_requested.emit(ECONOMY_DASHBOARD_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH)
	_set_status("Run Economy Dashboard Public Snapshot Cutover bench: %s" % ECONOMY_DASHBOARD_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH)


func open_standings_public_snapshot_service_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", STANDINGS_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH)
	else:
		open_standings_public_snapshot_service_requested.emit(STANDINGS_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH)
	_set_status("Open Standings Public Snapshot Service: %s" % STANDINGS_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH)


func run_standings_public_snapshot_cutover_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", STANDINGS_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH)
	else:
		run_standings_public_snapshot_cutover_bench_requested.emit(STANDINGS_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH)
	_set_status("Run Standings Public Snapshot Cutover bench: %s" % STANDINGS_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH)


func open_final_settlement_public_snapshot_service_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", FINAL_SETTLEMENT_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH)
	else:
		open_final_settlement_public_snapshot_service_requested.emit(FINAL_SETTLEMENT_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH)
	_set_status("Open Final Settlement Public Snapshot Service: %s" % FINAL_SETTLEMENT_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH)


func run_final_settlement_public_snapshot_cutover_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", FINAL_SETTLEMENT_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH)
	else:
		run_final_settlement_public_snapshot_cutover_bench_requested.emit(FINAL_SETTLEMENT_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH)
	_set_status("Run Final Settlement Public Snapshot Cutover bench: %s" % FINAL_SETTLEMENT_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH)


func open_intel_dossier_public_snapshot_service_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", INTEL_DOSSIER_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH)
	else:
		open_intel_dossier_public_snapshot_service_requested.emit(INTEL_DOSSIER_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH)
	_set_status("Open Intel Dossier Public Snapshot Service: %s" % INTEL_DOSSIER_PUBLIC_SNAPSHOT_SERVICE_SCENE_PATH)


func run_intel_dossier_public_snapshot_cutover_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", INTEL_DOSSIER_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH)
	else:
		run_intel_dossier_public_snapshot_cutover_bench_requested.emit(INTEL_DOSSIER_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH)
	_set_status("Run Intel Dossier Public Snapshot Cutover bench: %s" % INTEL_DOSSIER_PUBLIC_SNAPSHOT_CUTOVER_BENCH_SCENE_PATH)


func open_new_game_setup_page_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", NEW_GAME_SETUP_PAGE_SCENE_PATH)
	else:
		open_new_game_setup_page_requested.emit(NEW_GAME_SETUP_PAGE_SCENE_PATH)
	_set_status("Open New Game Setup Page: %s" % NEW_GAME_SETUP_PAGE_SCENE_PATH)


func run_new_game_setup_page_cutover_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", NEW_GAME_SETUP_PAGE_CUTOVER_BENCH_SCENE_PATH)
	else:
		run_new_game_setup_page_cutover_bench_requested.emit(NEW_GAME_SETUP_PAGE_CUTOVER_BENCH_SCENE_PATH)
	_set_status("Run New Game Setup Page Cutover bench: %s" % NEW_GAME_SETUP_PAGE_CUTOVER_BENCH_SCENE_PATH)


func open_ai_policy_resource_preview_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", AI_POLICY_RESOURCE_PREVIEW_SCENE_PATH)
	else:
		open_ai_policy_resource_preview_requested.emit(AI_POLICY_RESOURCE_PREVIEW_SCENE_PATH)
	_set_status("Open AI Policy Resource preview: %s" % AI_POLICY_RESOURCE_PREVIEW_SCENE_PATH)


func run_ai_policy_resource_bench_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("run_scene"):
		_editor_plugin.call("run_scene", AI_POLICY_RESOURCE_BENCH_SCENE_PATH)
	else:
		run_ai_policy_resource_bench_requested.emit(AI_POLICY_RESOURCE_BENCH_SCENE_PATH)
	_set_status("Run AI Policy Resource bench: %s" % AI_POLICY_RESOURCE_BENCH_SCENE_PATH)


func open_ai_runtime_controller_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", AI_RUNTIME_CONTROLLER_SCENE_PATH)
	else:
		open_ai_runtime_controller_requested.emit(AI_RUNTIME_CONTROLLER_SCENE_PATH)
	_set_status("Open AI Runtime Controller: %s" % AI_RUNTIME_CONTROLLER_SCENE_PATH)


func open_ai_runtime_world_bridge_scene() -> void:
	if _editor_plugin != null and _editor_plugin.has_method("open_scene"):
		_editor_plugin.call("open_scene", AI_RUNTIME_WORLD_BRIDGE_SCENE_PATH)
	else:
		open_ai_runtime_world_bridge_requested.emit(AI_RUNTIME_WORLD_BRIDGE_SCENE_PATH)
	_set_status("Open AI Runtime World Bridge: %s" % AI_RUNTIME_WORLD_BRIDGE_SCENE_PATH)


func open_qa_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(DESIGN_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open QA output folder: %s" % DESIGN_QA_OUTPUT_DIR)
	else:
		_set_status("QA output folder: %s" % DESIGN_QA_OUTPUT_DIR)


func open_interaction_qa_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(INTERACTION_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open interaction QA output folder: %s" % INTERACTION_QA_OUTPUT_DIR)
	else:
		_set_status("Interaction QA output folder: %s" % INTERACTION_QA_OUTPUT_DIR)


func open_player_turn_interaction_qa_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(PLAYER_TURN_INTERACTION_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open player turn interaction QA output folder: %s" % PLAYER_TURN_INTERACTION_QA_OUTPUT_DIR)
	else:
		_set_status("Player turn interaction QA output folder: %s" % PLAYER_TURN_INTERACTION_QA_OUTPUT_DIR)


func open_runtime_player_flow_qa_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(RUNTIME_PLAYER_FLOW_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open runtime player flow QA output folder: %s" % RUNTIME_PLAYER_FLOW_QA_OUTPUT_DIR)
	else:
		_set_status("Runtime player flow QA output folder: %s" % RUNTIME_PLAYER_FLOW_QA_OUTPUT_DIR)


func open_first_playable_loop_qa_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(FIRST_PLAYABLE_LOOP_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open first playable loop QA output folder: %s" % FIRST_PLAYABLE_LOOP_QA_OUTPUT_DIR)
	else:
		_set_status("First playable loop QA output folder: %s" % FIRST_PLAYABLE_LOOP_QA_OUTPUT_DIR)


func open_first_round_runtime_playable_loop_qa_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(FIRST_ROUND_RUNTIME_PLAYABLE_LOOP_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open first-round runtime playable loop QA output folder: %s" % FIRST_ROUND_RUNTIME_PLAYABLE_LOOP_QA_OUTPUT_DIR)
	else:
		_set_status("First-round runtime playable loop QA output folder: %s" % FIRST_ROUND_RUNTIME_PLAYABLE_LOOP_QA_OUTPUT_DIR)


func open_first_mission_spine_qa_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(FIRST_MISSION_SPINE_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open first mission spine QA output folder: %s" % FIRST_MISSION_SPINE_QA_OUTPUT_DIR)
	else:
		_set_status("First mission spine QA output folder: %s" % FIRST_MISSION_SPINE_QA_OUTPUT_DIR)


func open_first_mission_runtime_main_qa_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(FIRST_MISSION_RUNTIME_MAIN_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open first mission runtime main QA output folder: %s" % FIRST_MISSION_RUNTIME_MAIN_QA_OUTPUT_DIR)
	else:
		_set_status("First mission runtime main QA output folder: %s" % FIRST_MISSION_RUNTIME_MAIN_QA_OUTPUT_DIR)


func open_planet_render_cutover_qa_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(PLANET_MAP_RENDER_CUTOVER_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open PlanetMap render cutover output folder: %s" % PLANET_MAP_RENDER_CUTOVER_QA_OUTPUT_DIR)
	else:
		_set_status("PlanetMap render cutover output folder: %s" % PLANET_MAP_RENDER_CUTOVER_QA_OUTPUT_DIR)


func open_planet_interaction_qa_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(PLANET_MAP_INTERACTION_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open PlanetMap interaction output folder: %s" % PLANET_MAP_INTERACTION_QA_OUTPUT_DIR)
	else:
		_set_status("PlanetMap interaction output folder: %s" % PLANET_MAP_INTERACTION_QA_OUTPUT_DIR)


func open_card_resolution_track_interaction_qa_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(CARD_RESOLUTION_TRACK_INTERACTION_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open CardResolutionTrack interaction output folder: %s" % CARD_RESOLUTION_TRACK_INTERACTION_QA_OUTPUT_DIR)
	else:
		_set_status("CardResolutionTrack interaction output folder: %s" % CARD_RESOLUTION_TRACK_INTERACTION_QA_OUTPUT_DIR)


func open_runtime_card_resolution_track_flow_qa_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(RUNTIME_CARD_RESOLUTION_TRACK_FLOW_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open Runtime CardResolutionTrack flow output folder: %s" % RUNTIME_CARD_RESOLUTION_TRACK_FLOW_QA_OUTPUT_DIR)
	else:
		_set_status("Runtime CardResolutionTrack flow output folder: %s" % RUNTIME_CARD_RESOLUTION_TRACK_FLOW_QA_OUTPUT_DIR)


func open_compendium_codex_qa_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(COMPENDIUM_CODEX_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open Compendium Codex output folder: %s" % COMPENDIUM_CODEX_QA_OUTPUT_DIR)
	else:
		_set_status("Compendium Codex output folder: %s" % COMPENDIUM_CODEX_QA_OUTPUT_DIR)


func open_compendium_content_registry_qa_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(COMPENDIUM_CONTENT_REGISTRY_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open Compendium Content Registry output folder: %s" % COMPENDIUM_CONTENT_REGISTRY_QA_OUTPUT_DIR)
	else:
		_set_status("Compendium Content Registry output folder: %s" % COMPENDIUM_CONTENT_REGISTRY_QA_OUTPUT_DIR)


func open_system_resourceization_audit_qa_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(SYSTEM_RESOURCEIZATION_AUDIT_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open System Resourceization Audit output folder: %s" % SYSTEM_RESOURCEIZATION_AUDIT_QA_OUTPUT_DIR)
	else:
		_set_status("System Resourceization Audit output folder: %s" % SYSTEM_RESOURCEIZATION_AUDIT_QA_OUTPUT_DIR)


func open_balance_parameter_resource_qa_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(BALANCE_PARAMETER_RESOURCE_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open Balance Parameter Resource output folder: %s" % BALANCE_PARAMETER_RESOURCE_QA_OUTPUT_DIR)
	else:
		_set_status("Balance Parameter Resource output folder: %s" % BALANCE_PARAMETER_RESOURCE_QA_OUTPUT_DIR)


func open_balance_model_resource_sandbox_qa_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(BALANCE_MODEL_RESOURCE_SANDBOX_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open Balance Model Resource sandbox output folder: %s" % BALANCE_MODEL_RESOURCE_SANDBOX_QA_OUTPUT_DIR)
	else:
		_set_status("Balance Model Resource sandbox output folder: %s" % BALANCE_MODEL_RESOURCE_SANDBOX_QA_OUTPUT_DIR)


func open_balance_runtime_bridge_qa_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(BALANCE_RUNTIME_BRIDGE_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open Balance Runtime Bridge output folder: %s" % BALANCE_RUNTIME_BRIDGE_QA_OUTPUT_DIR)
	else:
		_set_status("Balance Runtime Bridge output folder: %s" % BALANCE_RUNTIME_BRIDGE_QA_OUTPUT_DIR)


func open_ruleset_v04_conformance_qa_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(RULESET_V04_CONFORMANCE_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open Ruleset v0.4 Conformance output folder: %s" % RULESET_V04_CONFORMANCE_QA_OUTPUT_DIR)
	else:
		_set_status("Ruleset v0.4 Conformance output folder: %s" % RULESET_V04_CONFORMANCE_QA_OUTPUT_DIR)


func open_forced_decision_runtime_scheduler_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(FORCED_DECISION_RUNTIME_SCHEDULER_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open Forced Decision Scheduler output folder: %s" % FORCED_DECISION_RUNTIME_SCHEDULER_QA_OUTPUT_DIR)
	else:
		_set_status("Forced Decision Scheduler output folder: %s" % FORCED_DECISION_RUNTIME_SCHEDULER_QA_OUTPUT_DIR)


func open_game_session_save_ownership_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(GAME_SESSION_SAVE_OWNERSHIP_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open Game Session/Save output folder: %s" % GAME_SESSION_SAVE_OWNERSHIP_QA_OUTPUT_DIR)
	else:
		_set_status("Game Session/Save output folder: %s" % GAME_SESSION_SAVE_OWNERSHIP_QA_OUTPUT_DIR)


func open_district_purchase_runtime_cutover_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(DISTRICT_PURCHASE_RUNTIME_CUTOVER_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open District Purchase output folder: %s" % DISTRICT_PURCHASE_RUNTIME_CUTOVER_QA_OUTPUT_DIR)
	else:
		_set_status("District Purchase output folder: %s" % DISTRICT_PURCHASE_RUNTIME_CUTOVER_QA_OUTPUT_DIR)


func open_card_inventory_runtime_characterization_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(CARD_INVENTORY_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open Card Inventory output folder: %s" % CARD_INVENTORY_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR)
	else:
		_set_status("Card Inventory output folder: %s" % CARD_INVENTORY_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR)


func open_player_hand_interaction_runtime_characterization_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(PLAYER_HAND_INTERACTION_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open Player Hand Interaction output folder: %s" % PLAYER_HAND_INTERACTION_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR)
	else:
		_set_status("Player Hand Interaction output folder: %s" % PLAYER_HAND_INTERACTION_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR)


func open_card_resolution_queue_runtime_characterization_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(CARD_RESOLUTION_QUEUE_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open Card Resolution Queue output folder: %s" % CARD_RESOLUTION_QUEUE_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR)
	else:
		_set_status("Card Resolution Queue output folder: %s" % CARD_RESOLUTION_QUEUE_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR)


func open_card_resolution_execution_runtime_characterization_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(CARD_RESOLUTION_EXECUTION_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open Card Resolution Execution output folder: %s" % CARD_RESOLUTION_EXECUTION_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR)
	else:
		_set_status("Card Resolution Execution output folder: %s" % CARD_RESOLUTION_EXECUTION_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR)


func open_economy_cashflow_runtime_cutover_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(ECONOMY_CASHFLOW_RUNTIME_CUTOVER_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open Economy Cashflow output folder: %s" % ECONOMY_CASHFLOW_RUNTIME_CUTOVER_QA_OUTPUT_DIR)
	else:
		_set_status("Economy Cashflow output folder: %s" % ECONOMY_CASHFLOW_RUNTIME_CUTOVER_QA_OUTPUT_DIR)


func open_gdp_formula_runtime_cutover_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(GDP_FORMULA_RUNTIME_CUTOVER_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open GDP Formula output folder: %s" % GDP_FORMULA_RUNTIME_CUTOVER_QA_OUTPUT_DIR)
	else:
		_set_status("GDP Formula output folder: %s" % GDP_FORMULA_RUNTIME_CUTOVER_QA_OUTPUT_DIR)


func open_scenario_runtime_glue_cutover_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(SCENARIO_RUNTIME_GLUE_CUTOVER_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open Scenario Runtime output folder: %s" % SCENARIO_RUNTIME_GLUE_CUTOVER_QA_OUTPUT_DIR)
	else:
		_set_status("Scenario Runtime output folder: %s" % SCENARIO_RUNTIME_GLUE_CUTOVER_QA_OUTPUT_DIR)


func open_first_table_authored_runtime_cutover_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(FIRST_TABLE_AUTHORED_RUNTIME_CUTOVER_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open First Table Authored Runtime output folder: %s" % FIRST_TABLE_AUTHORED_RUNTIME_CUTOVER_QA_OUTPUT_DIR)
	else:
		_set_status("First Table Authored Runtime output folder: %s" % FIRST_TABLE_AUTHORED_RUNTIME_CUTOVER_QA_OUTPUT_DIR)


func open_legacy_runtime_surface_retirement_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(LEGACY_RUNTIME_SURFACE_RETIREMENT_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open Legacy Runtime Surface Retirement output folder: %s" % LEGACY_RUNTIME_SURFACE_RETIREMENT_QA_OUTPUT_DIR)
	else:
		_set_status("Legacy Runtime Surface Retirement output folder: %s" % LEGACY_RUNTIME_SURFACE_RETIREMENT_QA_OUTPUT_DIR)


func open_legacy_player_surface_retirement_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(LEGACY_PLAYER_SURFACE_RETIREMENT_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open Legacy Player Surface Retirement output folder: %s" % LEGACY_PLAYER_SURFACE_RETIREMENT_QA_OUTPUT_DIR)
	else:
		_set_status("Legacy Player Surface Retirement output folder: %s" % LEGACY_PLAYER_SURFACE_RETIREMENT_QA_OUTPUT_DIR)


func open_card_play_eligibility_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(CARD_PLAY_ELIGIBILITY_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open Card Play Eligibility output folder: %s" % CARD_PLAY_ELIGIBILITY_QA_OUTPUT_DIR)
	else:
		_set_status("Card Play Eligibility output folder: %s" % CARD_PLAY_ELIGIBILITY_QA_OUTPUT_DIR)


func open_menu_shell_runtime_cutover_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(MENU_SHELL_RUNTIME_CUTOVER_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open Menu Shell Runtime Cutover output folder: %s" % MENU_SHELL_RUNTIME_CUTOVER_QA_OUTPUT_DIR)
	else:
		_set_status("Menu Shell Runtime Cutover output folder: %s" % MENU_SHELL_RUNTIME_CUTOVER_QA_OUTPUT_DIR)


func open_codex_scene_hard_cutover_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(CODEX_SCENE_HARD_CUTOVER_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open Codex Scene Hard Cutover output folder: %s" % CODEX_SCENE_HARD_CUTOVER_QA_OUTPUT_DIR)
	else:
		_set_status("Codex Scene Hard Cutover output folder: %s" % CODEX_SCENE_HARD_CUTOVER_QA_OUTPUT_DIR)


func open_codex_atlas_scene_cutover_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(CODEX_ATLAS_SCENE_CUTOVER_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open Codex Atlas Scene Cutover output folder: %s" % CODEX_ATLAS_SCENE_CUTOVER_QA_OUTPUT_DIR)
	else:
		_set_status("Codex Atlas Scene Cutover output folder: %s" % CODEX_ATLAS_SCENE_CUTOVER_QA_OUTPUT_DIR)


func open_codex_navigation_runtime_cutover_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(CODEX_NAVIGATION_RUNTIME_CUTOVER_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open Codex Navigation Runtime Cutover output folder: %s" % CODEX_NAVIGATION_RUNTIME_CUTOVER_QA_OUTPUT_DIR)
	else:
		_set_status("Codex Navigation Runtime Cutover output folder: %s" % CODEX_NAVIGATION_RUNTIME_CUTOVER_QA_OUTPUT_DIR)


func open_codex_public_snapshot_cutover_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(CODEX_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open Codex Public Snapshot Cutover output folder: %s" % CODEX_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR)
	else:
		_set_status("Codex Public Snapshot Cutover output folder: %s" % CODEX_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR)


func open_monster_codex_public_snapshot_cutover_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(MONSTER_CODEX_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open Monster Codex Public Snapshot Cutover output folder: %s" % MONSTER_CODEX_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR)
	else:
		_set_status("Monster Codex Public Snapshot Cutover output folder: %s" % MONSTER_CODEX_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR)


func open_monster_runtime_characterization_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(MONSTER_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open Monster Runtime Characterization output folder: %s" % MONSTER_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR)
	else:
		_set_status("Monster Runtime Characterization output folder: %s" % MONSTER_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR)


func open_military_runtime_characterization_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(MILITARY_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open Military Runtime Characterization output folder: %s" % MILITARY_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR)
	else:
		_set_status("Military Runtime Characterization output folder: %s" % MILITARY_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR)


func open_weather_runtime_characterization_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(WEATHER_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open Weather Runtime Characterization output folder: %s" % WEATHER_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR)
	else:
		_set_status("Weather Runtime Characterization output folder: %s" % WEATHER_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR)


func open_contract_runtime_characterization_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(CONTRACT_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open Contract Runtime Characterization output folder: %s" % CONTRACT_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR)
	else:
		_set_status("Contract Runtime Characterization output folder: %s" % CONTRACT_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR)


func open_product_market_runtime_characterization_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(PRODUCT_MARKET_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open Product Market Runtime Characterization output folder: %s" % PRODUCT_MARKET_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR)
	else:
		_set_status("Product Market Runtime Characterization output folder: %s" % PRODUCT_MARKET_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR)


func open_city_trade_network_runtime_characterization_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(CITY_TRADE_NETWORK_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open City / Trade Network Characterization output folder: %s" % CITY_TRADE_NETWORK_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR)
	else:
		_set_status("City / Trade Network Characterization output folder: %s" % CITY_TRADE_NETWORK_RUNTIME_CHARACTERIZATION_QA_OUTPUT_DIR)


func open_city_development_settlement_characterization_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(CITY_DEVELOPMENT_SETTLEMENT_CHARACTERIZATION_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open City Development Settlement Characterization output folder: %s" % CITY_DEVELOPMENT_SETTLEMENT_CHARACTERIZATION_QA_OUTPUT_DIR)
	else:
		_set_status("City Development Settlement Characterization output folder: %s" % CITY_DEVELOPMENT_SETTLEMENT_CHARACTERIZATION_QA_OUTPUT_DIR)


func open_city_gdp_derivative_runtime_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(CITY_GDP_DERIVATIVE_RUNTIME_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open City GDP Derivative Runtime output folder: %s" % CITY_GDP_DERIVATIVE_RUNTIME_QA_OUTPUT_DIR)
	else:
		_set_status("City GDP Derivative Runtime output folder: %s" % CITY_GDP_DERIVATIVE_RUNTIME_QA_OUTPUT_DIR)


func open_product_codex_public_snapshot_cutover_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(PRODUCT_CODEX_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open Product Codex Public Snapshot Cutover output folder: %s" % PRODUCT_CODEX_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR)
	else:
		_set_status("Product Codex Public Snapshot Cutover output folder: %s" % PRODUCT_CODEX_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR)


func open_card_codex_public_snapshot_cutover_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(CARD_CODEX_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open Card Codex Public Snapshot Cutover output folder: %s" % CARD_CODEX_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR)
	else:
		_set_status("Card Codex Public Snapshot Cutover output folder: %s" % CARD_CODEX_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR)


func open_runtime_card_catalog_resource_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(RUNTIME_CARD_CATALOG_RESOURCE_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open Runtime Card Catalog Resource output folder: %s" % RUNTIME_CARD_CATALOG_RESOURCE_QA_OUTPUT_DIR)
	else:
		_set_status("Runtime Card Catalog Resource output folder: %s" % RUNTIME_CARD_CATALOG_RESOURCE_QA_OUTPUT_DIR)


func open_runtime_card_authoring_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(RUNTIME_CARD_AUTHORING_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open Runtime Card Authoring output folder: %s" % RUNTIME_CARD_AUTHORING_QA_OUTPUT_DIR)
	else:
		_set_status("Runtime Card Authoring output folder: %s" % RUNTIME_CARD_AUTHORING_QA_OUTPUT_DIR)


func open_economy_dashboard_public_snapshot_cutover_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(ECONOMY_DASHBOARD_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open Economy Dashboard Public Snapshot Cutover output folder: %s" % ECONOMY_DASHBOARD_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR)
	else:
		_set_status("Economy Dashboard Public Snapshot Cutover output folder: %s" % ECONOMY_DASHBOARD_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR)


func open_standings_public_snapshot_cutover_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(STANDINGS_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open Standings Public Snapshot Cutover output folder: %s" % STANDINGS_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR)
	else:
		_set_status("Standings Public Snapshot Cutover output folder: %s" % STANDINGS_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR)


func open_final_settlement_public_snapshot_cutover_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(FINAL_SETTLEMENT_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open Final Settlement Public Snapshot Cutover output folder: %s" % FINAL_SETTLEMENT_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR)
	else:
		_set_status("Final Settlement Public Snapshot Cutover output folder: %s" % FINAL_SETTLEMENT_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR)


func open_intel_dossier_public_snapshot_cutover_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(INTEL_DOSSIER_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open Intel Dossier Public Snapshot Cutover output folder: %s" % INTEL_DOSSIER_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR)
	else:
		_set_status("Intel Dossier Public Snapshot Cutover output folder: %s" % INTEL_DOSSIER_PUBLIC_SNAPSHOT_CUTOVER_QA_OUTPUT_DIR)


func open_new_game_setup_page_cutover_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(NEW_GAME_SETUP_PAGE_CUTOVER_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open New Game Setup Page Cutover output folder: %s" % NEW_GAME_SETUP_PAGE_CUTOVER_QA_OUTPUT_DIR)
	else:
		_set_status("New Game Setup Page Cutover output folder: %s" % NEW_GAME_SETUP_PAGE_CUTOVER_QA_OUTPUT_DIR)


func open_ai_policy_resource_qa_output_folder() -> void:
	var absolute_path := ProjectSettings.globalize_path(AI_POLICY_RESOURCE_QA_OUTPUT_DIR)
	var error := OS.shell_open(absolute_path)
	if error == OK:
		_set_status("Open AI Policy Resource output folder: %s" % AI_POLICY_RESOURCE_QA_OUTPUT_DIR)
	else:
		_set_status("AI Policy Resource output folder: %s" % AI_POLICY_RESOURCE_QA_OUTPUT_DIR)


func show_long_text_hint() -> void:
	_set_status("Long-text stress uses the preview scene button for: %s" % _selected_fixture_id)


func show_disabled_action_hint() -> void:
	_set_status("Disabled-action stress keeps the first visible action disabled for: %s" % _selected_fixture_id)


func show_malformed_payload_hint() -> void:
	_set_status("Malformed payload falls back through OverlayLayer's generic temporary decision panel.")


func _connect_buttons() -> void:
	_connect_button(open_preview_button, "open_preview_scene")
	_connect_button(run_preview_button, "run_preview_scene")
	_connect_button(open_capture_bench_button, "open_capture_bench_scene")
	_connect_button(run_capture_bench_button, "run_capture_bench_scene")
	_connect_button(open_output_folder_button, "open_qa_output_folder")
	_connect_button(open_interaction_bench_button, "open_interaction_bench_scene")
	_connect_button(run_interaction_bench_button, "run_interaction_bench_scene")
	_connect_button(open_interaction_output_folder_button, "open_interaction_qa_output_folder")
	_connect_button(open_mcp_hub_button, "open_mcp_editability_hub_scene")
	_connect_button(run_mcp_hub_button, "run_mcp_editability_hub_scene")
	_connect_button(open_player_turn_preview_button, "open_player_turn_preview_scene")
	_connect_button(run_player_turn_preview_button, "run_player_turn_preview_scene")
	_connect_button(open_player_turn_interaction_bench_button, "open_player_turn_interaction_bench_scene")
	_connect_button(run_player_turn_interaction_bench_button, "run_player_turn_interaction_bench_scene")
	_connect_button(open_player_turn_interaction_output_folder_button, "open_player_turn_interaction_qa_output_folder")
	_connect_button(open_runtime_player_flow_bench_button, "open_runtime_player_flow_bench_scene")
	_connect_button(run_runtime_player_flow_bench_button, "run_runtime_player_flow_bench_scene")
	_connect_button(open_runtime_player_flow_output_folder_button, "open_runtime_player_flow_qa_output_folder")
	_connect_button(open_first_playable_loop_bench_button, "open_first_playable_loop_bench_scene")
	_connect_button(run_first_playable_loop_bench_button, "run_first_playable_loop_bench_scene")
	_connect_button(open_first_playable_loop_output_folder_button, "open_first_playable_loop_qa_output_folder")
	_connect_button(open_first_round_runtime_playable_loop_bench_button, "open_first_round_runtime_playable_loop_bench_scene")
	_connect_button(run_first_round_runtime_playable_loop_bench_button, "run_first_round_runtime_playable_loop_bench_scene")
	_connect_button(open_first_round_runtime_playable_loop_output_folder_button, "open_first_round_runtime_playable_loop_qa_output_folder")
	_connect_button(open_first_mission_spine_bench_button, "open_first_mission_spine_bench_scene")
	_connect_button(run_first_mission_spine_bench_button, "run_first_mission_spine_bench_scene")
	_connect_button(open_first_mission_spine_output_folder_button, "open_first_mission_spine_qa_output_folder")
	_connect_button(open_first_mission_runtime_main_bench_button, "open_first_mission_runtime_main_bench_scene")
	_connect_button(run_first_mission_runtime_main_bench_button, "run_first_mission_runtime_main_bench_scene")
	_connect_button(open_first_mission_runtime_main_output_folder_button, "open_first_mission_runtime_main_qa_output_folder")
	_connect_button(open_planet_map_preview_button, "open_planet_map_preview_scene")
	_connect_button(run_planet_map_preview_button, "run_planet_map_preview_scene")
	_connect_button(open_planet_map_view_button, "open_planet_map_view_scene")
	_connect_button(open_planet_district_node_button, "open_planet_district_node_scene")
	_connect_button(open_planet_district_polygon_button, "open_planet_district_polygon_scene")
	_connect_button(open_planet_monster_token_button, "open_planet_monster_token_scene")
	_connect_button(open_planet_route_marker_button, "open_planet_route_marker_scene")
	_connect_button(open_planet_route_segment_button, "open_planet_route_segment_scene")
	_connect_button(open_planet_movement_trail_button, "open_planet_movement_trail_scene")
	_connect_button(open_planet_map_event_effect_button, "open_planet_map_event_effect_scene")
	_connect_button(open_planet_action_callout_button, "open_planet_action_callout_scene")
	_connect_button(open_planet_globe_backdrop_button, "open_planet_globe_backdrop_scene")
	_connect_button(open_planet_orbit_guide_button, "open_planet_orbit_guide_scene")
	_connect_button(open_planet_focus_range_overlay_button, "open_planet_focus_range_overlay_scene")
	_connect_button(open_planet_scale_hint_button, "open_planet_scale_hint_scene")
	_connect_button(open_planet_render_cutover_bench_button, "open_planet_render_cutover_bench_scene")
	_connect_button(run_planet_render_cutover_bench_button, "run_planet_render_cutover_bench_scene")
	_connect_button(open_planet_render_cutover_output_folder_button, "open_planet_render_cutover_qa_output_folder")
	_connect_button(open_planet_interaction_bench_button, "open_planet_interaction_bench_scene")
	_connect_button(run_planet_interaction_bench_button, "run_planet_interaction_bench_scene")
	_connect_button(open_planet_interaction_output_folder_button, "open_planet_interaction_qa_output_folder")
	_connect_button(open_sceneization_audit_button, "open_sceneization_audit_scene")
	_connect_button(run_sceneization_audit_button, "run_sceneization_audit_scene")
	_connect_button(open_card_track_preview_button, "open_card_track_preview_scene")
	_connect_button(run_card_track_preview_button, "run_card_track_preview_scene")
	_connect_button(open_card_track_slot_button, "open_card_track_slot_scene")
	_connect_button(open_card_resolution_track_button, "open_card_resolution_track_scene")
	_connect_button(open_card_resolution_track_slot_button, "open_card_resolution_track_slot_scene")
	_connect_button(open_card_resolution_track_preview_button, "open_card_resolution_track_preview_scene")
	_connect_button(run_card_resolution_track_preview_button, "run_card_resolution_track_preview_scene")
	_connect_button(open_card_resolution_track_interaction_bench_button, "open_card_resolution_track_interaction_bench_scene")
	_connect_button(run_card_resolution_track_interaction_bench_button, "run_card_resolution_track_interaction_bench_scene")
	_connect_button(open_card_resolution_track_interaction_output_folder_button, "open_card_resolution_track_interaction_qa_output_folder")
	_connect_button(open_runtime_card_resolution_track_flow_bench_button, "open_runtime_card_resolution_track_flow_bench_scene")
	_connect_button(run_runtime_card_resolution_track_flow_bench_button, "run_runtime_card_resolution_track_flow_bench_scene")
	_connect_button(open_runtime_card_resolution_track_flow_output_folder_button, "open_runtime_card_resolution_track_flow_qa_output_folder")
	_connect_button(open_compendium_codex_preview_button, "open_compendium_codex_preview_scene")
	_connect_button(run_compendium_codex_preview_button, "run_compendium_codex_preview_scene")
	_connect_button(open_compendium_codex_interaction_bench_button, "open_compendium_codex_interaction_bench_scene")
	_connect_button(run_compendium_codex_interaction_bench_button, "run_compendium_codex_interaction_bench_scene")
	_connect_button(open_compendium_codex_output_folder_button, "open_compendium_codex_qa_output_folder")
	_connect_button(open_compendium_content_registry_preview_button, "open_compendium_content_registry_preview_scene")
	_connect_button(run_compendium_content_registry_bench_button, "run_compendium_content_registry_bench_scene")
	_connect_button(open_compendium_content_registry_output_folder_button, "open_compendium_content_registry_qa_output_folder")
	_connect_button(open_system_resourceization_audit_button, "open_system_resourceization_audit_scene")
	_connect_button(run_system_resourceization_audit_button, "run_system_resourceization_audit_scene")
	_connect_button(open_system_resourceization_output_folder_button, "open_system_resourceization_audit_qa_output_folder")
	_connect_button(open_balance_parameter_resource_preview_button, "open_balance_parameter_resource_preview_scene")
	_connect_button(run_balance_parameter_resource_bench_button, "run_balance_parameter_resource_bench_scene")
	_connect_button(open_balance_parameter_resource_output_folder_button, "open_balance_parameter_resource_qa_output_folder")
	_connect_button(open_balance_model_resource_sandbox_button, "open_balance_model_resource_sandbox_scene")
	_connect_button(run_balance_model_resource_sandbox_bench_button, "run_balance_model_resource_sandbox_bench_scene")
	_connect_button(open_balance_model_resource_sandbox_output_folder_button, "open_balance_model_resource_sandbox_qa_output_folder")
	_connect_button(open_balance_runtime_bridge_button, "open_balance_runtime_bridge_preview_scene")
	_connect_button(run_balance_runtime_bridge_bench_button, "run_balance_runtime_bridge_bench_scene")
	_connect_button(open_balance_runtime_bridge_output_folder_button, "open_balance_runtime_bridge_qa_output_folder")
	_connect_button(open_gameplay_balance_diagnostics_service_button, "open_gameplay_balance_diagnostics_service_scene")
	_connect_button(open_gameplay_balance_diagnostics_world_bridge_button, "open_gameplay_balance_diagnostics_world_bridge_scene")
	_connect_button(open_ruleset_runtime_bridge_button, "open_ruleset_runtime_bridge_scene")
	_connect_button(run_ruleset_v04_conformance_bench_button, "run_ruleset_v04_conformance_bench_scene")
	_connect_button(open_ruleset_v04_conformance_output_folder_button, "open_ruleset_v04_conformance_qa_output_folder")
	_connect_button(open_city_development_runtime_controller_button, "open_city_development_runtime_controller_scene")
	_connect_button(open_city_development_world_bridge_button, "open_city_development_world_bridge_scene")
	_connect_button(open_game_runtime_coordinator_button, "open_game_runtime_coordinator_scene")
	_connect_button(open_forced_decision_runtime_scheduler_button, "open_forced_decision_runtime_scheduler_scene")
	_connect_button(run_forced_decision_runtime_scheduler_bench_button, "run_forced_decision_runtime_scheduler_bench_scene")
	_connect_button(open_forced_decision_runtime_scheduler_output_folder_button, "open_forced_decision_runtime_scheduler_output_folder")
	_connect_button(open_game_session_runtime_controller_button, "open_game_session_runtime_controller_scene")
	_connect_button(open_game_save_runtime_coordinator_button, "open_game_save_runtime_coordinator_scene")
	_connect_button(run_game_session_save_ownership_bench_button, "run_game_session_save_ownership_bench_scene")
	_connect_button(open_game_session_save_ownership_output_folder_button, "open_game_session_save_ownership_output_folder")
	_connect_button(open_district_purchase_runtime_controller_button, "open_district_purchase_runtime_controller_scene")
	_connect_button(open_district_purchase_settlement_runtime_service_button, "open_district_purchase_settlement_runtime_service_scene")
	_connect_button(open_district_supply_drawer_button, "open_district_supply_drawer_scene")
	_connect_button(open_district_supply_snapshot_service_button, "open_district_supply_snapshot_service_scene")
	_connect_button(run_district_purchase_runtime_cutover_bench_button, "run_district_purchase_runtime_cutover_bench_scene")
	_connect_button(open_district_purchase_runtime_cutover_output_folder_button, "open_district_purchase_runtime_cutover_output_folder")
	_connect_button(open_card_inventory_runtime_service_button, "open_card_inventory_runtime_service_scene")
	_connect_button(open_card_inventory_runtime_characterization_bench_button, "open_card_inventory_runtime_characterization_bench_scene")
	_connect_button(run_card_inventory_runtime_characterization_bench_button, "run_card_inventory_runtime_characterization_bench_scene")
	_connect_button(open_card_inventory_runtime_characterization_output_folder_button, "open_card_inventory_runtime_characterization_output_folder")
	_connect_button(open_player_hand_interaction_runtime_service_button, "open_player_hand_interaction_runtime_service_scene")
	_connect_button(open_player_hand_interaction_runtime_characterization_bench_button, "open_player_hand_interaction_runtime_characterization_bench_scene")
	_connect_button(run_player_hand_interaction_runtime_characterization_bench_button, "run_player_hand_interaction_runtime_characterization_bench_scene")
	_connect_button(open_player_hand_interaction_runtime_characterization_output_folder_button, "open_player_hand_interaction_runtime_characterization_output_folder")
	_connect_button(open_card_resolution_queue_runtime_service_button, "open_card_resolution_queue_runtime_service_scene")
	_connect_button(open_card_resolution_queue_runtime_characterization_bench_button, "open_card_resolution_queue_runtime_characterization_bench_scene")
	_connect_button(run_card_resolution_queue_runtime_characterization_bench_button, "run_card_resolution_queue_runtime_characterization_bench_scene")
	_connect_button(open_card_resolution_queue_runtime_characterization_output_folder_button, "open_card_resolution_queue_runtime_characterization_output_folder")
	_connect_button(open_card_resolution_execution_runtime_service_button, "open_card_resolution_execution_runtime_service_scene")
	_connect_button(open_card_resolution_execution_runtime_characterization_bench_button, "open_card_resolution_execution_runtime_characterization_bench_scene")
	_connect_button(run_card_resolution_execution_runtime_characterization_bench_button, "run_card_resolution_execution_runtime_characterization_bench_scene")
	_connect_button(open_card_resolution_execution_runtime_characterization_output_folder_button, "open_card_resolution_execution_runtime_characterization_output_folder")
	_connect_button(open_card_economy_product_route_effect_runtime_service_button, "open_card_economy_product_route_effect_runtime_service_scene")
	_connect_button(open_card_economy_product_route_formula_runtime_service_button, "open_card_economy_product_route_formula_runtime_service_scene")
	_connect_button(open_economy_cashflow_runtime_controller_button, "open_economy_cashflow_runtime_controller_scene")
	_connect_button(run_economy_cashflow_runtime_cutover_bench_button, "run_economy_cashflow_runtime_cutover_bench_scene")
	_connect_button(open_economy_cashflow_runtime_cutover_output_folder_button, "open_economy_cashflow_runtime_cutover_output_folder")
	_connect_button(open_gdp_formula_runtime_controller_button, "open_gdp_formula_runtime_controller_scene")
	_connect_button(run_gdp_formula_runtime_cutover_bench_button, "run_gdp_formula_runtime_cutover_bench_scene")
	_connect_button(open_gdp_formula_runtime_cutover_output_folder_button, "open_gdp_formula_runtime_cutover_output_folder")
	_connect_button(open_scenario_runtime_controller_button, "open_scenario_runtime_controller_scene")
	_connect_button(run_scenario_runtime_glue_cutover_bench_button, "run_scenario_runtime_glue_cutover_bench_scene")
	_connect_button(open_scenario_runtime_glue_cutover_output_folder_button, "open_scenario_runtime_glue_cutover_output_folder")
	_connect_button(open_first_table_authored_runtime_service_button, "open_first_table_authored_runtime_service_scene")
	_connect_button(run_first_table_authored_runtime_cutover_bench_button, "run_first_table_authored_runtime_cutover_bench_scene")
	_connect_button(open_first_table_authored_runtime_cutover_output_folder_button, "open_first_table_authored_runtime_cutover_output_folder")
	_connect_button(open_sceneized_main_button, "open_sceneized_main_scene")
	_connect_button(run_legacy_runtime_surface_retirement_bench_button, "run_legacy_runtime_surface_retirement_bench_scene")
	_connect_button(open_legacy_runtime_surface_retirement_output_folder_button, "open_legacy_runtime_surface_retirement_output_folder")
	_connect_button(open_legacy_player_surface_retirement_bench_button, "open_legacy_player_surface_retirement_bench_scene")
	_connect_button(run_legacy_player_surface_retirement_bench_button, "run_legacy_player_surface_retirement_bench_scene")
	_connect_button(open_legacy_player_surface_retirement_output_folder_button, "open_legacy_player_surface_retirement_output_folder")
	_connect_button(open_card_presentation_runtime_service_button, "open_card_presentation_runtime_service_scene")
	_connect_button(open_game_table_viewmodel_runtime_service_button, "open_game_table_viewmodel_runtime_service_scene")
	_connect_button(open_card_play_eligibility_runtime_service_button, "open_card_play_eligibility_runtime_service_scene")
	_connect_button(open_card_play_eligibility_world_bridge_button, "open_card_play_eligibility_world_bridge_scene")
	_connect_button(open_card_play_eligibility_runtime_bench_button, "open_card_play_eligibility_runtime_bench_scene")
	_connect_button(run_card_play_eligibility_runtime_bench_button, "run_card_play_eligibility_runtime_bench_scene")
	_connect_button(open_card_play_eligibility_output_folder_button, "open_card_play_eligibility_output_folder")
	_connect_button(open_menu_shell_runtime_cutover_bench_button, "open_menu_shell_runtime_cutover_bench_scene")
	_connect_button(run_menu_shell_runtime_cutover_bench_button, "run_menu_shell_runtime_cutover_bench_scene")
	_connect_button(open_menu_shell_runtime_cutover_output_folder_button, "open_menu_shell_runtime_cutover_output_folder")
	_connect_button(open_codex_scene_hard_cutover_bench_button, "open_codex_scene_hard_cutover_bench_scene")
	_connect_button(run_codex_scene_hard_cutover_bench_button, "run_codex_scene_hard_cutover_bench_scene")
	_connect_button(open_codex_scene_hard_cutover_output_folder_button, "open_codex_scene_hard_cutover_output_folder")
	_connect_button(open_codex_atlas_scene_cutover_bench_button, "open_codex_atlas_scene_cutover_bench_scene")
	_connect_button(run_codex_atlas_scene_cutover_bench_button, "run_codex_atlas_scene_cutover_bench_scene")
	_connect_button(open_codex_atlas_scene_cutover_output_folder_button, "open_codex_atlas_scene_cutover_output_folder")
	_connect_button(open_codex_navigation_runtime_controller_button, "open_codex_navigation_runtime_controller_scene")
	_connect_button(run_codex_navigation_runtime_cutover_bench_button, "run_codex_navigation_runtime_cutover_bench_scene")
	_connect_button(open_codex_navigation_runtime_cutover_output_folder_button, "open_codex_navigation_runtime_cutover_output_folder")
	_connect_button(open_codex_public_snapshot_service_button, "open_codex_public_snapshot_service_scene")
	_connect_button(run_codex_public_snapshot_cutover_bench_button, "run_codex_public_snapshot_cutover_bench_scene")
	_connect_button(open_codex_public_snapshot_cutover_output_folder_button, "open_codex_public_snapshot_cutover_output_folder")
	_connect_button(open_monster_codex_public_snapshot_service_button, "open_monster_codex_public_snapshot_service_scene")
	_connect_button(run_monster_codex_public_snapshot_cutover_bench_button, "run_monster_codex_public_snapshot_cutover_bench_scene")
	_connect_button(open_monster_codex_public_snapshot_cutover_output_folder_button, "open_monster_codex_public_snapshot_cutover_output_folder")
	_connect_button(open_monster_runtime_controller_button, "open_monster_runtime_controller_scene")
	_connect_button(open_monster_runtime_world_bridge_button, "open_monster_runtime_world_bridge_scene")
	_connect_button(open_monster_runtime_characterization_bench_button, "open_monster_runtime_characterization_bench_scene")
	_connect_button(run_monster_runtime_characterization_bench_button, "run_monster_runtime_characterization_bench_scene")
	_connect_button(open_monster_runtime_characterization_output_folder_button, "open_monster_runtime_characterization_output_folder")
	_connect_button(open_military_runtime_controller_button, "open_military_runtime_controller_scene")
	_connect_button(open_military_runtime_world_bridge_button, "open_military_runtime_world_bridge_scene")
	_connect_button(open_military_runtime_characterization_bench_button, "open_military_runtime_characterization_bench_scene")
	_connect_button(run_military_runtime_characterization_bench_button, "run_military_runtime_characterization_bench_scene")
	_connect_button(open_military_runtime_characterization_output_folder_button, "open_military_runtime_characterization_output_folder")
	_connect_button(open_weather_runtime_controller_button, "open_weather_runtime_controller_scene")
	_connect_button(open_weather_runtime_world_bridge_button, "open_weather_runtime_world_bridge_scene")
	_connect_button(open_weather_runtime_characterization_bench_button, "open_weather_runtime_characterization_bench_scene")
	_connect_button(run_weather_runtime_characterization_bench_button, "run_weather_runtime_characterization_bench_scene")
	_connect_button(open_weather_runtime_characterization_output_folder_button, "open_weather_runtime_characterization_output_folder")
	_connect_button(open_contract_runtime_controller_button, "open_contract_runtime_controller_scene")
	_connect_button(open_contract_runtime_world_bridge_button, "open_contract_runtime_world_bridge_scene")
	_connect_button(open_contract_runtime_characterization_bench_button, "open_contract_runtime_characterization_bench_scene")
	_connect_button(run_contract_runtime_characterization_bench_button, "run_contract_runtime_characterization_bench_scene")
	_connect_button(open_contract_runtime_characterization_output_folder_button, "open_contract_runtime_characterization_output_folder")
	_connect_button(open_product_market_runtime_characterization_bench_button, "open_product_market_runtime_characterization_bench_scene")
	_connect_button(run_product_market_runtime_characterization_bench_button, "run_product_market_runtime_characterization_bench_scene")
	_connect_button(open_product_futures_terms_catalog_button, "open_product_futures_terms_catalog")
	_connect_button(open_product_market_runtime_characterization_output_folder_button, "open_product_market_runtime_characterization_output_folder")
	_connect_button(open_city_trade_network_runtime_controller_button, "open_city_trade_network_runtime_controller_scene")
	_connect_button(open_city_trade_network_runtime_world_bridge_button, "open_city_trade_network_runtime_world_bridge_scene")
	_connect_button(open_city_trade_network_runtime_characterization_bench_button, "open_city_trade_network_runtime_characterization_bench_scene")
	_connect_button(run_city_trade_network_runtime_characterization_bench_button, "run_city_trade_network_runtime_characterization_bench_scene")
	_connect_button(open_city_trade_network_runtime_characterization_output_folder_button, "open_city_trade_network_runtime_characterization_output_folder")
	_connect_button(open_city_development_settlement_characterization_bench_button, "open_city_development_settlement_characterization_bench_scene")
	_connect_button(run_city_development_settlement_characterization_bench_button, "run_city_development_settlement_characterization_bench_scene")
	_connect_button(open_city_development_settlement_characterization_output_folder_button, "open_city_development_settlement_characterization_output_folder")
	_connect_button(open_city_gdp_derivative_runtime_controller_button, "open_city_gdp_derivative_runtime_controller_scene")
	_connect_button(open_city_gdp_derivative_runtime_world_bridge_button, "open_city_gdp_derivative_runtime_world_bridge_scene")
	_connect_button(open_city_gdp_derivative_runtime_bench_button, "open_city_gdp_derivative_runtime_bench_scene")
	_connect_button(run_city_gdp_derivative_runtime_bench_button, "run_city_gdp_derivative_runtime_bench_scene")
	_connect_button(open_city_gdp_derivative_terms_catalog_button, "open_city_gdp_derivative_terms_catalog")
	_connect_button(open_city_gdp_derivative_runtime_output_folder_button, "open_city_gdp_derivative_runtime_output_folder")
	_connect_button(open_product_codex_public_snapshot_service_button, "open_product_codex_public_snapshot_service_scene")
	_connect_button(run_product_codex_public_snapshot_cutover_bench_button, "run_product_codex_public_snapshot_cutover_bench_scene")
	_connect_button(open_product_codex_public_snapshot_cutover_output_folder_button, "open_product_codex_public_snapshot_cutover_output_folder")
	_connect_button(open_card_codex_public_snapshot_service_button, "open_card_codex_public_snapshot_service_scene")
	_connect_button(run_card_codex_public_snapshot_cutover_bench_button, "run_card_codex_public_snapshot_cutover_bench_scene")
	_connect_button(open_card_codex_public_snapshot_cutover_output_folder_button, "open_card_codex_public_snapshot_cutover_output_folder")
	_connect_button(open_runtime_card_catalog_button, "open_runtime_card_catalog")
	_connect_button(open_runtime_card_catalog_service_button, "open_runtime_card_catalog_service_scene")
	_connect_button(run_runtime_card_catalog_resource_bench_button, "run_runtime_card_catalog_resource_bench_scene")
	_connect_button(open_runtime_card_catalog_resource_output_folder_button, "open_runtime_card_catalog_resource_output_folder")
	_connect_button(open_runtime_card_authoring_workspace_button, "open_runtime_card_authoring_workspace_scene")
	_connect_button(open_runtime_card_authoring_sample_family_button, "open_runtime_card_authoring_sample_family")
	_connect_button(run_runtime_card_authoring_workflow_bench_button, "run_runtime_card_authoring_workflow_bench_scene")
	_connect_button(open_runtime_card_authoring_output_folder_button, "open_runtime_card_authoring_output_folder")
	_connect_button(open_economy_dashboard_public_snapshot_service_button, "open_economy_dashboard_public_snapshot_service_scene")
	_connect_button(run_economy_dashboard_public_snapshot_cutover_bench_button, "run_economy_dashboard_public_snapshot_cutover_bench_scene")
	_connect_button(open_economy_dashboard_public_snapshot_cutover_output_folder_button, "open_economy_dashboard_public_snapshot_cutover_output_folder")
	_connect_button(open_standings_public_snapshot_service_button, "open_standings_public_snapshot_service_scene")
	_connect_button(run_standings_public_snapshot_cutover_bench_button, "run_standings_public_snapshot_cutover_bench_scene")
	_connect_button(open_standings_public_snapshot_cutover_output_folder_button, "open_standings_public_snapshot_cutover_output_folder")
	_connect_button(open_final_settlement_public_snapshot_service_button, "open_final_settlement_public_snapshot_service_scene")
	_connect_button(run_final_settlement_public_snapshot_cutover_bench_button, "run_final_settlement_public_snapshot_cutover_bench_scene")
	_connect_button(open_final_settlement_public_snapshot_cutover_output_folder_button, "open_final_settlement_public_snapshot_cutover_output_folder")
	_connect_button(open_intel_dossier_public_snapshot_service_button, "open_intel_dossier_public_snapshot_service_scene")
	_connect_button(run_intel_dossier_public_snapshot_cutover_bench_button, "run_intel_dossier_public_snapshot_cutover_bench_scene")
	_connect_button(open_intel_dossier_public_snapshot_cutover_output_folder_button, "open_intel_dossier_public_snapshot_cutover_output_folder")
	_connect_button(open_new_game_setup_page_button, "open_new_game_setup_page_scene")
	_connect_button(run_new_game_setup_page_cutover_bench_button, "run_new_game_setup_page_cutover_bench_scene")
	_connect_button(open_new_game_setup_page_cutover_output_folder_button, "open_new_game_setup_page_cutover_output_folder")
	_connect_button(open_ai_policy_resource_preview_button, "open_ai_policy_resource_preview_scene")
	_connect_button(run_ai_policy_resource_bench_button, "run_ai_policy_resource_bench_scene")
	_connect_button(open_ai_policy_resource_output_folder_button, "open_ai_policy_resource_qa_output_folder")
	_connect_button(open_ai_runtime_controller_button, "open_ai_runtime_controller_scene")
	_connect_button(open_ai_runtime_world_bridge_button, "open_ai_runtime_world_bridge_scene")
	_connect_button(monster_wager_button, "_on_monster_wager_fixture_pressed")
	_connect_button(contract_response_button, "_on_contract_response_fixture_pressed")
	_connect_button(discard_button, "_on_discard_fixture_pressed")
	_connect_button(monster_target_button, "_on_monster_target_fixture_pressed")
	_connect_button(player_target_button, "_on_player_target_fixture_pressed")
	_connect_button(long_text_hint_button, "show_long_text_hint")
	_connect_button(disabled_hint_button, "show_disabled_action_hint")
	_connect_button(malformed_hint_button, "show_malformed_payload_hint")


func _connect_button(button: Button, method_name: String) -> void:
	if button == null:
		return
	var callback := Callable(self, method_name)
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)


func _fixtures_instance() -> RefCounted:
	if _fixtures != null:
		return _fixtures
	var script := load(FIXTURE_SCRIPT_PATH)
	if script == null:
		_set_status("Missing fixture script: %s" % FIXTURE_SCRIPT_PATH)
		return null
	var instance_variant: Variant = script.new()
	if instance_variant is RefCounted:
		_fixtures = instance_variant
	return _fixtures


func _fixture_label(id: String) -> String:
	var fixtures := _fixtures_instance()
	if fixtures == null:
		return id
	var label_variant: Variant = fixtures.call("preview_label", id)
	var label := str(label_variant)
	return label if label.strip_edges() != "" else id


func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text


func _on_monster_wager_fixture_pressed() -> void:
	select_fixture("monster_wager")


func _on_contract_response_fixture_pressed() -> void:
	select_fixture("contract_response")


func _on_discard_fixture_pressed() -> void:
	select_fixture("discard_purchase")


func _on_monster_target_fixture_pressed() -> void:
	select_fixture("monster_target_choice")


func _on_player_target_fixture_pressed() -> void:
	select_fixture("player_target_choice")
