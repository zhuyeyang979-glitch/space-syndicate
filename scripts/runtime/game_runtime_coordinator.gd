@tool
extends Node
class_name GameRuntimeCoordinator

signal victory_presentation_receipt_ready(receipt: VictoryPresentationStateChangeReceipt)

@export var presentation_game_screen_path: NodePath

const RULESET_V06_PROFILE := preload("res://resources/rules/space_syndicate_ruleset_v06.tres")
const MONSTER_CARD_EFFECT_ADAPTER_V06 := preload("res://scripts/cards/v06/units/monster_card_effect_adapter_v06.gd")
const RUNTIME_BALANCE_MODEL_SCRIPT := preload("res://scripts/balance/runtime_balance_model.gd")
const COMMODITY_SUSHI_TRACK_SERVICE_SCRIPT := preload("res://scripts/runtime/commodity_sushi_track_runtime_service.gd")
const CARD_TARGET_CHOICE_RESPONSE_SINK_SCRIPT := preload("res://scripts/runtime/card_target_choice_response_sink.gd")
const MONSTER_WAGER_RESPONSE_SINK_SCRIPT := preload("res://scripts/runtime/monster_wager_response_sink.gd")
const AlphaContentLoader := preload("res://scripts/runtime/alpha01_content_manifest_loader.gd")
const CORE_ECONOMIC_CARD_EFFECT_KINDS_V06 := [
	"install_commodity_rate",
	"build_upgrade_or_repair_facility",
	"global_order_budget",
	"global_supply_spawn",
	"install_organization_upgrade",
]
const SHARED_RESOLUTION_EFFECT_KINDS_V06 := [
	"global_order_budget",
	"global_supply_spawn",
]

var _ruleset_id := ""
var _configured := false
var _composition_ready := false
var _bound_world: Node
var _world_session_state_cache: WorldSessionState
var _last_v06_player_binding_result: Dictionary = {
	"ready": false,
	"reason_code": "production_players_not_bound",
}
var _monster_card_effect_adapter_v06: Object
var _new_session_test_fault_stage := ""
var _new_session_commit_side_effect_count := 0
var _new_session_presentation_refresh_count := 0
var _last_new_session_commit_only_receipt: Dictionary = {}


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_wire_run_rng_service()
	_wire_table_selection_state()
	_wire_world_session_state()
	_wire_ai_world_typed_ports()
	_wire_table_presentation_query_ports()
	_wire_monster_wager_cash_commitment_query_port()
	_wire_player_cash_mutation_port()
	_wire_ai_business_cost_cash_port()
	_wire_commodity_flow_postcommit()
	_wire_forced_decision_candidate_sources()
	call_deferred("_wire_table_selection_intent_port")
	call_deferred("_wire_forced_decision_response_paths")
	_wire_card_cooldown_runtime_controller()
	_wire_card_execution_typed_ports()
	_wire_card_resolution_transition_sink()
	_wire_runtime_command_pipeline()
	_wire_card_resolution_frame_driver()
	_wire_runtime_world_ports()
	call_deferred("_wire_district_supply_action_port")
	call_deferred("_wire_table_presentation_source_target")


func configure(ruleset_snapshot: Dictionary) -> void:
	_ruleset_id = str(ruleset_snapshot.get("ruleset_id", ""))
	_wire_run_rng_service()
	_wire_table_selection_state()
	_wire_world_session_state()
	_wire_ai_world_typed_ports()
	_wire_table_presentation_query_ports()
	_wire_monster_wager_cash_commitment_query_port()
	_wire_player_cash_mutation_port()
	_wire_ai_business_cost_cash_port()
	_wire_commodity_flow_postcommit()
	_wire_forced_decision_candidate_sources()
	call_deferred("_wire_table_selection_intent_port")
	call_deferred("_wire_forced_decision_response_paths")
	_wire_card_cooldown_runtime_controller()
	_wire_card_execution_typed_ports()
	_wire_card_resolution_transition_sink()
	_wire_runtime_command_pipeline()
	_wire_card_resolution_frame_driver()
	_wire_runtime_world_ports()
	call_deferred("_wire_district_supply_action_port")
	call_deferred("_wire_table_presentation_source_target")
	var world_clock := _world_effective_clock_runtime_controller_node()
	if world_clock != null and world_clock.has_method("configure"):
		world_clock.call("configure", {})
	var solar_availability := _solar_availability_runtime_service_node()
	if solar_availability != null and solar_availability.has_method("configure"):
		solar_availability.call("configure", {})
	var card_market_bridge := _card_market_policy_world_bridge_node()
	var card_market_pricing := _card_market_pricing_runtime_controller_node()
	if card_market_pricing != null and card_market_pricing.has_method("set_dependencies"):
		card_market_pricing.call("set_dependencies", world_clock, solar_availability, card_market_bridge)
	if card_market_pricing != null and card_market_pricing.has_method("configure"):
		card_market_pricing.call("configure", {})
	var region_infrastructure := _region_infrastructure_runtime_controller_node()
	var region_infrastructure_bridge := _region_infrastructure_world_bridge_node()
	var weather_telemetry := _weather_telemetry_runtime_service_node()
	if region_infrastructure_bridge != null and region_infrastructure_bridge.has_method("set_controller"):
		region_infrastructure_bridge.call("set_controller", region_infrastructure)
	if region_infrastructure != null and region_infrastructure.has_method("configure"):
		region_infrastructure.call("configure", RULESET_V06_PROFILE.debug_snapshot())
	var card_runtime_catalog := _card_runtime_catalog_node() as CardRuntimeCatalogService
	if card_runtime_catalog != null and card_runtime_catalog.has_method("configure"):
		card_runtime_catalog.call("configure", ruleset_snapshot)
	var card_definition_bridge := _card_runtime_definition_bridge_node() as CardRuntimeDefinitionWorldBridge
	if card_definition_bridge != null:
		card_definition_bridge.set_catalog_service(card_runtime_catalog)
	var balance_diagnostics := _gameplay_balance_diagnostics_node()
	var balance_diagnostics_bridge := _gameplay_balance_diagnostics_world_bridge_node() as GameplayBalanceDiagnosticsWorldBridge
	if balance_diagnostics_bridge != null:
		balance_diagnostics_bridge.set_card_catalog_service(card_runtime_catalog)
		balance_diagnostics_bridge.set_role_catalog(_role_catalog_runtime_service_node() as RoleCatalogRuntimeService)
	if balance_diagnostics != null and balance_diagnostics.has_method("set_world_bridge"):
		balance_diagnostics.call("set_world_bridge", balance_diagnostics_bridge)
	if balance_diagnostics != null and balance_diagnostics.has_method("configure"):
		balance_diagnostics.call("configure", balance_diagnostics.get("route_catalog"), null)
	var priority_variant: Variant = ruleset_snapshot.get("forced_decision_priority", [])
	var priority_order: Array = priority_variant if priority_variant is Array else []
	var scheduler := _scheduler_node()
	if scheduler != null and scheduler.has_method("configure"):
		scheduler.call("configure", priority_order)
	var session := _session_node()
	if session != null and session.has_method("set_world_effective_clock"):
		session.call("set_world_effective_clock", world_clock)
	if session != null and session.has_method("configure"):
		session.call("configure", ruleset_snapshot, {})
	var purchase := _purchase_node()
	if purchase != null and purchase.has_method("set_quote_authority"):
		purchase.call("set_quote_authority", card_market_pricing)
	if purchase != null and purchase.has_method("configure"):
		var timing_variant: Variant = ruleset_snapshot.get("timing", {})
		purchase.call("configure", timing_variant if timing_variant is Dictionary else {})
	var card_inventory := _card_inventory_node()
	if card_inventory != null and card_inventory.has_method("configure"):
		card_inventory.call("configure", ruleset_snapshot)
	var card_resolution_queue := _card_resolution_queue_node()
	if card_resolution_queue != null and card_resolution_queue.has_method("configure"):
		card_resolution_queue.call("configure", _v06_card_group_runtime_snapshot())
	var card_resolution_history := _card_resolution_history_runtime_service_node()
	if card_resolution_history != null:
		card_resolution_history.configure({"history_limit": 24})
	var action_result_presentation := _action_result_presentation_node()
	if action_result_presentation != null and action_result_presentation.has_method("configure"):
		action_result_presentation.call("configure", {})
	var card_resolution_execution := _card_resolution_execution_node()
	if card_resolution_execution != null and card_resolution_execution.has_method("configure"):
		card_resolution_execution.call("configure", ruleset_snapshot)
	var economy_product_route_effect := _card_economy_product_route_effect_node()
	if economy_product_route_effect != null and economy_product_route_effect.has_method("configure"):
		economy_product_route_effect.call("configure", ruleset_snapshot)
	var economy_product_route_formula := _card_economy_product_route_formula_node()
	if economy_product_route_formula != null and economy_product_route_formula.has_method("configure"):
		economy_product_route_formula.call("configure", ruleset_snapshot)
	var product_market_controller := _product_market_runtime_controller_node()
	var product_market_world_bridge := _product_market_runtime_world_bridge_node()
	if product_market_controller != null and product_market_controller.has_method("set_world_bridge"):
		product_market_controller.call("set_world_bridge", product_market_world_bridge)
	if product_market_controller != null and product_market_controller.has_method("set_weather_telemetry_runtime_service"):
		product_market_controller.call("set_weather_telemetry_runtime_service", weather_telemetry)
	if product_market_controller != null and product_market_controller.has_method("configure"):
		product_market_controller.call("configure", ruleset_snapshot, economy_product_route_formula)
	var city_gdp_derivative_controller := _city_gdp_derivative_runtime_controller_node()
	var city_gdp_derivative_world_bridge := _city_gdp_derivative_runtime_world_bridge_node()
	if city_gdp_derivative_controller != null and city_gdp_derivative_controller.has_method("set_world_bridge"):
		city_gdp_derivative_controller.call("set_world_bridge", city_gdp_derivative_world_bridge)
	if city_gdp_derivative_controller != null and city_gdp_derivative_controller.has_method("configure"):
		city_gdp_derivative_controller.call("configure", ruleset_snapshot, economy_product_route_formula)
	if card_definition_bridge != null:
		card_definition_bridge.set_product_market_runtime_controller(product_market_controller)
		card_definition_bridge.set_city_gdp_derivative_runtime_controller(city_gdp_derivative_controller)
	var hand_interaction := _player_hand_interaction_node()
	if hand_interaction != null and hand_interaction.has_method("set_inventory_service"):
		hand_interaction.call("set_inventory_service", card_inventory)
	if hand_interaction != null and hand_interaction.has_method("configure"):
		hand_interaction.call("configure", {})
	var purchase_settlement := _purchase_settlement_node()
	if purchase_settlement != null and purchase_settlement.has_method("set_inventory_service"):
		purchase_settlement.call("set_inventory_service", card_inventory)
	if purchase_settlement != null and purchase_settlement.has_method("configure"):
		purchase_settlement.call("configure", {})
	var route_network_controller := _route_network_runtime_controller_node()
	var route_network_bridge := _route_network_world_bridge_node()
	if route_network_bridge != null and route_network_bridge.has_method("set_region_infrastructure_controller"):
		route_network_bridge.call("set_region_infrastructure_controller", region_infrastructure)
	if route_network_controller != null and route_network_controller.has_method("set_world_bridge"):
		route_network_controller.call("set_world_bridge", route_network_bridge)
	if route_network_controller != null and route_network_controller.has_method("set_weather_telemetry_runtime_service"):
		route_network_controller.call("set_weather_telemetry_runtime_service", weather_telemetry)
	if route_network_controller != null and route_network_controller.has_method("configure"):
		route_network_controller.call("configure", RULESET_V06_PROFILE.debug_snapshot())
	var commodity_flow := _commodity_flow_runtime_controller_node()
	var commodity_flow_bridge := _commodity_flow_world_bridge_node()
	if commodity_flow_bridge != null and commodity_flow_bridge.has_method("set_controller"):
		commodity_flow_bridge.call("set_controller", commodity_flow)
	if commodity_flow_bridge != null and commodity_flow_bridge.has_method("set_runtime_dependencies"):
		commodity_flow_bridge.call("set_runtime_dependencies", region_infrastructure, product_market_controller, route_network_controller)
	if commodity_flow != null and commodity_flow.has_method("set_world_bridge"):
		commodity_flow.call("set_world_bridge", commodity_flow_bridge)
	_wire_commodity_flow_postcommit()
	if commodity_flow != null and commodity_flow.has_method("configure"):
		commodity_flow.call("configure", RULESET_V06_PROFILE.debug_snapshot())
	var player_mana := _player_mana_runtime_controller_node()
	if player_mana != null and player_mana.has_method("configure"):
		player_mana.call("configure", RULESET_V06_PROFILE.debug_snapshot())
	var commodity_card_inventory := _commodity_card_inventory_runtime_controller_node()
	var card_player_state_adapter := _card_player_state_production_adapter_v06_node()
	if card_player_state_adapter != null and card_player_state_adapter.has_method("configure"):
		var commodity_catalog: Resource = commodity_card_inventory.call("catalog") if commodity_card_inventory != null and commodity_card_inventory.has_method("catalog") else null
		card_player_state_adapter.call("configure", commodity_catalog, player_mana)
	if commodity_card_inventory != null and commodity_card_inventory.has_method("set_market_quote_authority"):
		commodity_card_inventory.call("set_market_quote_authority", card_market_pricing)
	if commodity_card_inventory != null and commodity_card_inventory.has_method("configure"):
		commodity_card_inventory.call(
			"configure",
			RULESET_V06_PROFILE.debug_snapshot(),
			card_player_state_adapter,
			commodity_flow,
			region_infrastructure
		)
	var commodity_sushi_track := _commodity_sushi_track_runtime_service_node()
	if commodity_sushi_track != null:
		commodity_sushi_track.configure(
			commodity_card_inventory as CommodityCardInventoryRuntimeController,
			card_player_state_adapter as CardPlayerStateProductionAdapterV06,
			product_market_controller as ProductMarketRuntimeController
		)
	_bind_region_supply_source_port()
	var codex_navigation := _codex_navigation_node()
	if codex_navigation != null and codex_navigation.has_method("configure"):
		codex_navigation.call("configure", {})
	var codex_public_snapshot := _codex_public_snapshot_node()
	if codex_public_snapshot != null and codex_public_snapshot.has_method("configure"):
		codex_public_snapshot.call("configure", {})
	var role_codex_public_source := _role_codex_public_source_node()
	if role_codex_public_source != null and role_codex_public_source.has_method("configure"):
		role_codex_public_source.call("configure", {
			"catalog": _role_catalog_runtime_service_node(),
			"snapshot": codex_public_snapshot,
		})
	var monster_codex_public_snapshot := _monster_codex_public_snapshot_node()
	if monster_codex_public_snapshot != null and monster_codex_public_snapshot.has_method("configure"):
		monster_codex_public_snapshot.call("configure", {})
	var product_codex_public_snapshot := _product_codex_public_snapshot_node()
	if product_codex_public_snapshot != null and product_codex_public_snapshot.has_method("configure"):
		product_codex_public_snapshot.call("configure", {})
	var product_codex_public_source := _product_codex_public_source_node()
	if product_codex_public_source != null and product_codex_public_source.has_method("configure"):
		product_codex_public_source.call("configure", {
			"product_market": product_market_controller,
			"snapshot": product_codex_public_snapshot,
			"region_public_bridge": region_infrastructure_bridge,
		})
	var card_codex_public_snapshot := _card_codex_public_snapshot_node()
	if card_codex_public_snapshot != null and card_codex_public_snapshot.has_method("configure"):
		card_codex_public_snapshot.call("configure", {})
	var economy_dashboard_public_snapshot := _economy_dashboard_public_snapshot_node()
	if economy_dashboard_public_snapshot != null and economy_dashboard_public_snapshot.has_method("configure"):
		economy_dashboard_public_snapshot.call("configure", {})
	var standings_public_snapshot := _standings_public_snapshot_node()
	if standings_public_snapshot != null and standings_public_snapshot.has_method("configure"):
		standings_public_snapshot.call("configure", {})
	var final_settlement_public_snapshot := _final_settlement_public_snapshot_node()
	if final_settlement_public_snapshot != null and final_settlement_public_snapshot.has_method("configure"):
		final_settlement_public_snapshot.call("configure", {})
	var intel_dossier_public_snapshot := _intel_dossier_public_snapshot_node()
	if intel_dossier_public_snapshot != null and intel_dossier_public_snapshot.has_method("configure"):
		intel_dossier_public_snapshot.call("configure", {})
	var district_supply_snapshot := _district_supply_snapshot_node()
	if district_supply_snapshot != null and district_supply_snapshot.has_method("configure"):
		district_supply_snapshot.call("configure", {})
	var card_presentation := _card_presentation_node()
	if card_presentation != null and card_presentation.has_method("set_product_market_runtime_controller"):
		card_presentation.call("set_product_market_runtime_controller", product_market_controller)
	if card_presentation != null and card_presentation.has_method("set_city_gdp_derivative_runtime_controller"):
		card_presentation.call("set_city_gdp_derivative_runtime_controller", city_gdp_derivative_controller)
	if card_presentation != null and card_presentation.has_method("configure"):
		card_presentation.call("configure", {})
	var card_play_eligibility := _card_play_eligibility_node()
	if card_play_eligibility != null and card_play_eligibility.has_method("set_product_market_runtime_controller"):
		card_play_eligibility.call("set_product_market_runtime_controller", product_market_controller)
	if card_play_eligibility != null and card_play_eligibility.has_method("set_city_gdp_derivative_runtime_controller"):
		card_play_eligibility.call("set_city_gdp_derivative_runtime_controller", city_gdp_derivative_controller)
	if card_play_eligibility != null and card_play_eligibility.has_method("configure"):
		card_play_eligibility.call("configure", _v06_card_group_runtime_snapshot())
	var card_codex_public_source := _card_codex_public_source_node()
	if card_codex_public_source != null and card_codex_public_source.has_method("configure"):
		card_codex_public_source.call("configure", {
			"snapshot": card_codex_public_snapshot,
		})
	var table_viewmodel := _table_viewmodel_node()
	if table_viewmodel != null and table_viewmodel.has_method("configure"):
		table_viewmodel.call("configure", card_presentation)
	var monster_controller := _monster_runtime_controller_node() as MonsterRuntimeController
	var monster_world_bridge := _monster_runtime_world_bridge_node()
	if card_definition_bridge != null and monster_controller != null:
		card_definition_bridge.set_monster_runtime_controller(monster_controller)
	var military_controller := _military_runtime_controller_node()
	var military_world_bridge := _military_runtime_world_bridge_node()
	var weather_controller := _weather_runtime_controller_node()
	var weather_world_bridge := _weather_runtime_world_bridge_node()
	var ai_controller := _ai_runtime_controller_node()
	var visual_cue_owner := _visual_cue_runtime_owner_node()
	var victory_controller := _victory_control_runtime_controller_node()
	var victory_world_bridge := _victory_control_world_bridge_node()
	if economy_product_route_effect != null and economy_product_route_effect.has_method("set_product_market_runtime_controller"):
		economy_product_route_effect.call("set_product_market_runtime_controller", product_market_controller)
	var economy_product_route_bridge := _card_economy_product_route_effect_world_bridge_node()
	if economy_product_route_bridge != null and economy_product_route_bridge.has_method("set_product_market_runtime_controller"):
		economy_product_route_bridge.call("set_product_market_runtime_controller", product_market_controller)
	if economy_product_route_bridge != null and economy_product_route_bridge.has_method("set_city_gdp_derivative_runtime_controller"):
		economy_product_route_bridge.call("set_city_gdp_derivative_runtime_controller", city_gdp_derivative_controller)
	if weather_controller != null and weather_controller.has_method("set_world_bridge"):
		weather_controller.call("set_world_bridge", weather_world_bridge)
	if weather_controller != null and weather_controller.has_method("set_world_effective_clock"):
		weather_controller.call("set_world_effective_clock", world_clock)
	if weather_controller != null and weather_controller.has_method("set_route_network_runtime_controller"):
		weather_controller.call("set_route_network_runtime_controller", route_network_controller)
	if weather_controller != null and weather_controller.has_method("set_region_infrastructure_world_bridge"):
		weather_controller.call("set_region_infrastructure_world_bridge", region_infrastructure_bridge)
	if weather_controller != null and weather_controller.has_method("set_weather_telemetry_runtime_service"):
		weather_controller.call("set_weather_telemetry_runtime_service", weather_telemetry)
	if weather_controller != null and weather_controller.has_method("set_visual_cue_runtime_owner"):
		weather_controller.call("set_visual_cue_runtime_owner", visual_cue_owner)
	if weather_controller != null and weather_controller.has_method("configure"):
		weather_controller.call("configure", ruleset_snapshot)
	var weather_presentation := _weather_presentation_runtime_service_node()
	if weather_presentation != null and weather_presentation.has_method("configure"):
		weather_presentation.call("configure", weather_controller)

	if ai_controller != null and ai_controller.has_method("set_product_market_runtime_controller"):
		ai_controller.call("set_product_market_runtime_controller", product_market_controller)
	if ai_controller != null and ai_controller.has_method("set_city_gdp_derivative_runtime_controller"):
		ai_controller.call("set_city_gdp_derivative_runtime_controller", city_gdp_derivative_controller)
	if ai_controller != null and ai_controller.has_method("set_card_definition_bridge"):
		ai_controller.call(
			"set_card_definition_bridge",
			card_definition_bridge,
			_card_play_eligibility_node()
		)
	if ai_controller != null and ai_controller.has_method("set_gameplay_balance_diagnostics_service"):
		ai_controller.call("set_gameplay_balance_diagnostics_service", balance_diagnostics)

	if ai_controller != null and ai_controller.has_method("set_route_network_runtime_controller"):
		ai_controller.call("set_route_network_runtime_controller", route_network_controller)
	if ai_controller != null and ai_controller.has_method("set_visual_cue_runtime_owner"):
		ai_controller.call("set_visual_cue_runtime_owner", visual_cue_owner)
	if ai_controller != null and ai_controller.has_method("configure"):
		ai_controller.call("configure", ruleset_snapshot, ai_controller.get("policy_profile"))
	if monster_controller != null and monster_controller.has_method("set_world_bridge"):
		monster_controller.call("set_world_bridge", monster_world_bridge)
	if monster_controller != null and monster_controller.has_method("set_product_market_runtime_controller"):
		monster_controller.call("set_product_market_runtime_controller", product_market_controller)
	if monster_controller != null and monster_controller.has_method("set_region_infrastructure_world_bridge"):
		monster_controller.call("set_region_infrastructure_world_bridge", region_infrastructure_bridge)
	if monster_controller != null and monster_controller.has_method("set_route_network_runtime_controller"):
		monster_controller.call("set_route_network_runtime_controller", route_network_controller)
	if monster_controller != null and monster_controller.has_method("set_weather_runtime_controller"):
		monster_controller.call("set_weather_runtime_controller", weather_controller)
	if monster_controller != null and monster_controller.has_method("set_weather_telemetry_runtime_service"):
		monster_controller.call("set_weather_telemetry_runtime_service", weather_telemetry)
	if monster_controller != null and monster_controller.has_method("set_visual_cue_runtime_owner"):
		monster_controller.call("set_visual_cue_runtime_owner", visual_cue_owner)
	if monster_controller != null and monster_controller.has_method("set_card_runtime_catalog_service"):
		monster_controller.call("set_card_runtime_catalog_service", card_runtime_catalog)
	if monster_controller != null and monster_controller.has_method("configure"):
		monster_controller.call("configure", ruleset_snapshot)
	if monster_controller is MonsterRuntimeController:
		var battle_configuration := (monster_controller as MonsterRuntimeController).configure_battle_lifecycle_v06(RULESET_V06_PROFILE.monster_rules())
		if not bool(battle_configuration.get("configured", false)):
			push_error("GameRuntimeCoordinator requires the v0.6 monster battle lifecycle profile.")
	var region_codex_public_source := _region_codex_public_source_node()
	if region_codex_public_source != null and region_codex_public_source.has_method("configure"):
		region_codex_public_source.call("configure", {
			"region_public_bridge": region_infrastructure_bridge,
			"monster": monster_controller,
			"weather": weather_controller,
			"route": route_network_controller,
			"snapshot": codex_public_snapshot,
		})
	var monster_codex_public_source := _monster_codex_public_source_node()
	if monster_codex_public_source != null and monster_codex_public_source.has_method("configure"):
		monster_codex_public_source.call("configure", {
			"monster": monster_controller,
			"snapshot": monster_codex_public_snapshot,
			"card_source": card_codex_public_source,
		})
	if military_controller != null and military_controller.has_method("set_world_bridge"):
		military_controller.call("set_world_bridge", military_world_bridge)
	if military_controller != null and military_controller.has_method("set_monster_runtime_controller"):
		military_controller.call("set_monster_runtime_controller", monster_controller)
	if military_controller != null and military_controller.has_method("set_inventory_service"):
		military_controller.call("set_inventory_service", card_inventory)
	if military_controller != null and military_controller.has_method("set_product_market_runtime_controller"):
		military_controller.call("set_product_market_runtime_controller", product_market_controller)
	if military_controller != null and military_controller.has_method("set_region_infrastructure_world_bridge"):
		military_controller.call("set_region_infrastructure_world_bridge", region_infrastructure_bridge)
	if military_controller != null and military_controller.has_method("set_route_network_runtime_controller"):
		military_controller.call("set_route_network_runtime_controller", route_network_controller)
	if military_controller != null and military_controller.has_method("set_weather_runtime_controller"):
		military_controller.call("set_weather_runtime_controller", weather_controller)
	if military_controller != null and military_controller.has_method("set_card_runtime_catalog_service"):
		military_controller.call("set_card_runtime_catalog_service", card_runtime_catalog)
	if military_controller != null and military_controller.has_method("set_visual_cue_runtime_owner"):
		military_controller.call("set_visual_cue_runtime_owner", visual_cue_owner)
	if military_controller != null and military_controller.has_method("configure"):
		military_controller.call("configure", ruleset_snapshot)
	if weather_controller != null and weather_controller.has_method("set_product_market_runtime_controller"):
		weather_controller.call("set_product_market_runtime_controller", product_market_controller)
	if product_market_controller != null and product_market_controller.has_method("set_weather_runtime_controller"):
		product_market_controller.call("set_weather_runtime_controller", weather_controller)
	if commodity_flow != null and commodity_flow.has_method("set_weather_runtime_controller"):
		commodity_flow.call("set_weather_runtime_controller", weather_controller)
	if commodity_flow != null and commodity_flow.has_method("set_weather_telemetry_runtime_service"):
		commodity_flow.call("set_weather_telemetry_runtime_service", weather_telemetry)
	if route_network_controller != null and route_network_controller.has_method("set_weather_runtime_controller"):
		route_network_controller.call("set_weather_runtime_controller", weather_controller)
	if product_market_controller != null and product_market_controller.has_method("set_route_network_runtime_controller"):
		product_market_controller.call("set_route_network_runtime_controller", route_network_controller)
	if victory_world_bridge != null and victory_world_bridge.has_method("set_runtime_dependencies"):
		victory_world_bridge.call("set_runtime_dependencies", region_infrastructure, commodity_flow, product_market_controller, city_gdp_derivative_controller, military_controller)
	if victory_controller != null and victory_controller.has_method("set_world_bridge"):
		victory_controller.call("set_world_bridge", victory_world_bridge)
	if victory_controller != null and victory_controller.has_method("configure"):
		victory_controller.call("configure")
	var bankruptcy_estate := _bankruptcy_neutral_estate_runtime_controller_node()
	var bankruptcy_estate_bridge := _bankruptcy_neutral_estate_world_bridge_node()
	if bankruptcy_estate_bridge != null and bankruptcy_estate_bridge.has_method("set_runtime_dependencies"):
		bankruptcy_estate_bridge.call("set_runtime_dependencies", card_player_state_adapter, commodity_flow, military_controller, monster_controller, region_infrastructure, route_network_controller, self)
	if bankruptcy_estate != null and bankruptcy_estate.has_method("set_world_bridge"):
		bankruptcy_estate.call("set_world_bridge", bankruptcy_estate_bridge)
	if bankruptcy_estate != null and bankruptcy_estate.has_method("configure"):
		bankruptcy_estate.call("configure", RULESET_V06_PROFILE.debug_snapshot())
	if commodity_flow_bridge != null and commodity_flow_bridge.has_method("set_bankruptcy_estate_controller"):
		commodity_flow_bridge.call("set_bankruptcy_estate_controller", bankruptcy_estate)
	_last_v06_player_binding_result = refresh_v06_production_player_bindings()
	_wire_table_presentation_query_ports()
	var session_snapshot := _session_debug_snapshot()
	var purchase_snapshot := _purchase_debug_snapshot()
	var card_inventory_snapshot := _card_inventory_debug_snapshot()
	var card_runtime_catalog_snapshot := _card_runtime_catalog_debug_snapshot()
	var card_definition_bridge_snapshot := _card_runtime_definition_bridge_debug_snapshot()
	var balance_diagnostics_snapshot := _gameplay_balance_diagnostics_debug_snapshot()
	var card_resolution_queue_snapshot := _card_resolution_queue_debug_snapshot()
	var action_result_presentation_snapshot := _action_result_presentation_debug_snapshot()
	var card_resolution_execution_snapshot := _card_resolution_execution_debug_snapshot()
	var economy_product_route_effect_snapshot := _card_economy_product_route_effect_debug_snapshot()
	var economy_product_route_formula_snapshot := _card_economy_product_route_formula_debug_snapshot()
	var product_market_snapshot := _product_market_runtime_debug_snapshot()
	var city_gdp_derivative_snapshot := _city_gdp_derivative_runtime_debug_snapshot()
	var player_cash_mutation_snapshot := _player_cash_mutation_port_node().debug_snapshot() if _player_cash_mutation_port_node() != null else {}
	var ai_business_cost_cash_snapshot := _ai_business_cost_cash_port_node().debug_snapshot() if _ai_business_cost_cash_port_node() != null else {}
	var route_network_snapshot := _route_network_runtime_debug_snapshot()
	var commodity_flow_snapshot := _commodity_flow_runtime_debug_snapshot()
	var commodity_flow_bridge_snapshot := _commodity_flow_world_bridge_debug_snapshot()
	var commodity_postcommit_snapshot := _commodity_flow_postcommit_debug_snapshot()
	var player_mana_snapshot := _player_mana_runtime_debug_snapshot()
	var hand_interaction_snapshot := _player_hand_interaction_debug_snapshot()
	var purchase_settlement_snapshot := _purchase_settlement_debug_snapshot()
	var codex_navigation_snapshot := _codex_navigation_debug_snapshot()
	var codex_public_snapshot_debug := _codex_public_snapshot_debug_snapshot()
	var monster_codex_public_snapshot_debug := _monster_codex_public_snapshot_debug_snapshot()
	var product_codex_public_snapshot_debug := _product_codex_public_snapshot_debug_snapshot()
	var product_codex_public_source_debug := _product_codex_public_source_debug_snapshot()
	var card_codex_public_snapshot_debug := _card_codex_public_snapshot_debug_snapshot()
	var card_codex_public_source_debug := _card_codex_public_source_debug_snapshot()
	var region_codex_public_source_debug := _region_codex_public_source_debug_snapshot()
	var monster_codex_public_source_debug := _monster_codex_public_source_debug_snapshot()
	var economy_dashboard_public_snapshot_debug := _economy_dashboard_public_snapshot_debug_snapshot()
	var standings_public_snapshot_debug := _standings_public_snapshot_debug_snapshot()
	var final_settlement_public_snapshot_debug := _final_settlement_public_snapshot_debug_snapshot()
	var intel_dossier_public_snapshot_debug := _intel_dossier_public_snapshot_debug_snapshot()
	var district_supply_snapshot_state := _district_supply_snapshot_debug_snapshot()
	var card_presentation_snapshot := _card_presentation_debug_snapshot()
	var card_play_eligibility_snapshot := _card_play_eligibility_debug_snapshot()
	var card_play_world_bridge_snapshot := _card_play_world_bridge_debug_snapshot()
	var table_viewmodel_snapshot := _table_viewmodel_debug_snapshot()
	var ai_snapshot := _ai_runtime_debug_snapshot()
	var monster_snapshot := _monster_runtime_debug_snapshot()
	var military_snapshot := _military_runtime_debug_snapshot()
	var weather_snapshot := _weather_runtime_debug_snapshot()
	var victory_snapshot := _victory_control_runtime_debug_snapshot()
	var world_clock_snapshot := _node_debug_snapshot(world_clock)
	var solar_snapshot := _node_debug_snapshot(solar_availability)
	var card_market_snapshot := _node_debug_snapshot(card_market_pricing)
	_composition_ready = _ruleset_id == "v0.4" and scheduler != null and not priority_order.is_empty() and bool(world_clock_snapshot.get("controller_ready", false)) and bool(solar_snapshot.get("service_ready", false)) and bool(card_market_snapshot.get("controller_ready", false)) and bool(card_runtime_catalog_snapshot.get("service_ready", false)) and bool(card_definition_bridge_snapshot.get("bridge_ready", false)) and bool(balance_diagnostics_snapshot.get("service_ready", false)) and bool(session_snapshot.get("session_ready", false)) and bool(purchase_snapshot.get("controller_ready", false)) and bool(card_inventory_snapshot.get("service_ready", false)) and bool(card_resolution_queue_snapshot.get("service_ready", false)) and bool(card_resolution_execution_snapshot.get("service_ready", false)) and bool(economy_product_route_effect_snapshot.get("service_ready", false)) and bool(economy_product_route_formula_snapshot.get("service_ready", false)) and bool(product_market_snapshot.get("controller_ready", false)) and bool(city_gdp_derivative_snapshot.get("controller_ready", false)) and bool(player_cash_mutation_snapshot.get("port_ready", false)) and bool(ai_business_cost_cash_snapshot.get("port_ready", false)) and bool(route_network_snapshot.get("controller_ready", false)) and bool(commodity_flow_snapshot.get("controller_ready", false)) and bool(commodity_flow_bridge_snapshot.get("bridge_ready", false)) and bool(commodity_postcommit_snapshot.get("consumer_ready", false)) and bool(player_mana_snapshot.get("controller_ready", false)) and bool(hand_interaction_snapshot.get("service_ready", false)) and bool(purchase_settlement_snapshot.get("service_ready", false)) and bool(codex_navigation_snapshot.get("controller_ready", false)) and bool(codex_public_snapshot_debug.get("service_ready", false)) and bool(monster_codex_public_snapshot_debug.get("service_ready", false)) and bool(monster_codex_public_source_debug.get("service_ready", false)) and bool(product_codex_public_snapshot_debug.get("service_ready", false)) and bool(product_codex_public_source_debug.get("service_ready", false)) and bool(card_codex_public_snapshot_debug.get("service_ready", false)) and bool(card_codex_public_source_debug.get("service_ready", false)) and bool(region_codex_public_source_debug.get("service_ready", false)) and bool(economy_dashboard_public_snapshot_debug.get("service_ready", false)) and bool(standings_public_snapshot_debug.get("service_ready", false)) and bool(final_settlement_public_snapshot_debug.get("service_ready", false)) and bool(intel_dossier_public_snapshot_debug.get("service_ready", false)) and bool(district_supply_snapshot_state.get("service_ready", false)) and bool(card_presentation_snapshot.get("service_ready", false)) and bool(card_play_eligibility_snapshot.get("service_ready", false)) and bool(card_play_world_bridge_snapshot.get("bridge_ready", false)) and bool(table_viewmodel_snapshot.get("service_ready", false)) and bool(ai_snapshot.get("controller_ready", false)) and bool(monster_snapshot.get("controller_ready", false)) and bool(military_snapshot.get("controller_ready", false)) and bool(weather_snapshot.get("controller_ready", false)) and bool(victory_snapshot.get("controller_ready", false))
	_composition_ready = _composition_ready and bool(action_result_presentation_snapshot.get("service_ready", false))
	_refresh_coordinator_readiness()


func bind_runtime_world(world: Node) -> void:
	_bound_world = world
	var card_market_bridge := _card_market_policy_world_bridge_node()
	if card_market_bridge != null and card_market_bridge.has_method("bind_world"):
		card_market_bridge.call("bind_world", world)
	var region_infrastructure_bridge := _region_infrastructure_world_bridge_node()
	if region_infrastructure_bridge != null and region_infrastructure_bridge.has_method("bind_world"):
		region_infrastructure_bridge.call("bind_world", world)
	var region_infrastructure := _region_infrastructure_runtime_controller_node()
	if region_infrastructure_bridge != null and region_infrastructure_bridge.has_method("set_controller"):
		region_infrastructure_bridge.call("set_controller", region_infrastructure)
	var balance_diagnostics_bridge := _gameplay_balance_diagnostics_world_bridge_node()
	if balance_diagnostics_bridge != null and balance_diagnostics_bridge.has_method("bind_world"):
		balance_diagnostics_bridge.call("bind_world", world)
	if balance_diagnostics_bridge != null and balance_diagnostics_bridge.has_method("set_role_catalog"):
		balance_diagnostics_bridge.call("set_role_catalog", _role_catalog_runtime_service_node())
	var balance_diagnostics := _gameplay_balance_diagnostics_node()
	if balance_diagnostics != null and balance_diagnostics.has_method("set_world_bridge"):
		balance_diagnostics.call("set_world_bridge", balance_diagnostics_bridge)
	var product_market_bridge := _product_market_runtime_world_bridge_node()
	if product_market_bridge != null and product_market_bridge.has_method("bind_world"):
		product_market_bridge.call("bind_world", world)
	var product_market_controller := _product_market_runtime_controller_node()
	if product_market_controller != null and product_market_controller.has_method("set_world_bridge"):
		product_market_controller.call("set_world_bridge", product_market_bridge)
	var city_gdp_derivative_bridge := _city_gdp_derivative_runtime_world_bridge_node()
	if city_gdp_derivative_bridge != null and city_gdp_derivative_bridge.has_method("bind_world"):
		city_gdp_derivative_bridge.call("bind_world", world)
	var city_gdp_derivative_controller := _city_gdp_derivative_runtime_controller_node()
	if city_gdp_derivative_controller != null and city_gdp_derivative_controller.has_method("set_world_bridge"):
		city_gdp_derivative_controller.call("set_world_bridge", city_gdp_derivative_bridge)
	var route_network_bridge := _route_network_world_bridge_node()
	if route_network_bridge != null and route_network_bridge.has_method("bind_world"):
		route_network_bridge.call("bind_world", world)
	if route_network_bridge != null and route_network_bridge.has_method("set_region_infrastructure_controller"):
		route_network_bridge.call("set_region_infrastructure_controller", region_infrastructure)
	var route_network_controller := _route_network_runtime_controller_node()
	if route_network_controller != null and route_network_controller.has_method("set_world_bridge"):
		route_network_controller.call("set_world_bridge", route_network_bridge)
	if route_network_controller != null and route_network_controller.has_method("refresh_routes"):
		route_network_controller.call("refresh_routes", true)
	var commodity_flow_bridge := _commodity_flow_world_bridge_node()
	var commodity_flow_controller := _commodity_flow_runtime_controller_node()
	if commodity_flow_bridge != null and commodity_flow_bridge.has_method("set_controller"):
		commodity_flow_bridge.call("set_controller", commodity_flow_controller)
	if commodity_flow_bridge != null and commodity_flow_bridge.has_method("set_runtime_dependencies"):
		commodity_flow_bridge.call("set_runtime_dependencies", region_infrastructure, product_market_controller, route_network_controller)
	if commodity_flow_controller != null and commodity_flow_controller.has_method("set_world_bridge"):
		commodity_flow_controller.call("set_world_bridge", commodity_flow_bridge)
	_wire_commodity_flow_postcommit()
	refresh_v06_production_player_bindings(world)
	var controller := _ai_runtime_controller_node()
	if controller != null and controller.has_method("set_gameplay_balance_diagnostics_service"):
		controller.call("set_gameplay_balance_diagnostics_service", balance_diagnostics)
	if controller != null and controller.has_method("set_route_network_runtime_controller"):
		controller.call("set_route_network_runtime_controller", route_network_controller)
	var card_play_bridge := _card_play_world_bridge_node()
	if card_play_bridge != null and card_play_bridge.has_method("bind_world"):
		card_play_bridge.call("bind_world", world)
	var monster_bridge := _monster_runtime_world_bridge_node()
	if monster_bridge != null and monster_bridge.has_method("bind_world"):
		monster_bridge.call("bind_world", world)
	var monster_controller := _monster_runtime_controller_node()
	if monster_controller != null and monster_controller.has_method("set_world_bridge"):
		monster_controller.call("set_world_bridge", monster_bridge)
	var military_bridge := _military_runtime_world_bridge_node()
	if military_bridge != null and military_bridge.has_method("bind_world"):
		military_bridge.call("bind_world", world)
	var military_controller := _military_runtime_controller_node()
	if military_controller != null and military_controller.has_method("set_world_bridge"):
		military_controller.call("set_world_bridge", military_bridge)
	var weather_bridge := _weather_runtime_world_bridge_node()
	if weather_bridge != null and weather_bridge.has_method("bind_world"):
		weather_bridge.call("bind_world", world)
	var weather_controller := _weather_runtime_controller_node()
	if weather_controller != null and weather_controller.has_method("set_world_bridge"):
		weather_controller.call("set_world_bridge", weather_bridge)
	if controller != null and controller.has_method("set_product_market_runtime_controller"):
		controller.call("set_product_market_runtime_controller", product_market_controller)
	if controller != null and controller.has_method("set_city_gdp_derivative_runtime_controller"):
		controller.call("set_city_gdp_derivative_runtime_controller", city_gdp_derivative_controller)
	if monster_controller != null and monster_controller.has_method("set_product_market_runtime_controller"):
		monster_controller.call("set_product_market_runtime_controller", product_market_controller)
	if monster_controller != null and monster_controller.has_method("set_route_network_runtime_controller"):
		monster_controller.call("set_route_network_runtime_controller", route_network_controller)
	if monster_controller != null and monster_controller.has_method("set_region_infrastructure_world_bridge"):
		monster_controller.call("set_region_infrastructure_world_bridge", region_infrastructure_bridge)
	if military_controller != null and military_controller.has_method("set_product_market_runtime_controller"):
		military_controller.call("set_product_market_runtime_controller", product_market_controller)
	if military_controller != null and military_controller.has_method("set_route_network_runtime_controller"):
		military_controller.call("set_route_network_runtime_controller", route_network_controller)
	if military_controller != null and military_controller.has_method("set_region_infrastructure_world_bridge"):
		military_controller.call("set_region_infrastructure_world_bridge", region_infrastructure_bridge)
	if weather_controller != null and weather_controller.has_method("set_product_market_runtime_controller"):
		weather_controller.call("set_product_market_runtime_controller", product_market_controller)
	if weather_controller != null and weather_controller.has_method("set_route_network_runtime_controller"):
		weather_controller.call("set_route_network_runtime_controller", route_network_controller)
	if product_market_controller != null and product_market_controller.has_method("set_route_network_runtime_controller"):
		product_market_controller.call("set_route_network_runtime_controller", route_network_controller)
	var effect_bridge := _card_economy_product_route_effect_world_bridge_node()
	if effect_bridge != null and effect_bridge.has_method("set_product_market_runtime_controller"):
		effect_bridge.call("set_product_market_runtime_controller", product_market_controller)
	if effect_bridge != null and effect_bridge.has_method("set_city_gdp_derivative_runtime_controller"):
		effect_bridge.call("set_city_gdp_derivative_runtime_controller", city_gdp_derivative_controller)
	if effect_bridge != null and effect_bridge.has_method("set_formula_runtime_service"):
		effect_bridge.call("set_formula_runtime_service", _card_economy_product_route_formula_node())
	var victory_bridge := _victory_control_world_bridge_node()
	if victory_bridge != null and victory_bridge.has_method("bind_world"):
		victory_bridge.call("bind_world", world)
	if victory_bridge != null and victory_bridge.has_method("set_runtime_dependencies"):
		victory_bridge.call("set_runtime_dependencies", region_infrastructure, commodity_flow_controller, product_market_controller, city_gdp_derivative_controller, military_controller)
	var victory_controller := _victory_control_runtime_controller_node()
	if victory_controller != null and victory_controller.has_method("set_world_bridge"):
		victory_controller.call("set_world_bridge", victory_bridge)
	if controller != null and controller.has_method("set_victory_control_runtime_controller"):
		controller.call("set_victory_control_runtime_controller", victory_controller)
	var bankruptcy_estate := _bankruptcy_neutral_estate_runtime_controller_node()
	var bankruptcy_estate_bridge := _bankruptcy_neutral_estate_world_bridge_node()
	if bankruptcy_estate_bridge != null and bankruptcy_estate_bridge.has_method("bind_world"):
		bankruptcy_estate_bridge.call("bind_world", world)
	if bankruptcy_estate_bridge != null and bankruptcy_estate_bridge.has_method("set_runtime_dependencies"):
		bankruptcy_estate_bridge.call("set_runtime_dependencies", _card_player_state_production_adapter_v06_node(), commodity_flow_controller, military_controller, monster_controller, region_infrastructure, route_network_controller, self)
	if commodity_flow_bridge != null and commodity_flow_bridge.has_method("set_bankruptcy_estate_controller"):
		commodity_flow_bridge.call("set_bankruptcy_estate_controller", bankruptcy_estate)


func refresh_v06_production_player_bindings(world: Node = null) -> Dictionary:
	if world != null:
		_bound_world = world
	return refresh_v06_session_player_bindings()


func refresh_v06_session_player_bindings(commodity_seed: int = 1, commodity_card_ids: Array = []) -> Dictionary:
	var card_player_state_adapter := _card_player_state_production_adapter_v06_node()
	var commodity_card_inventory := _commodity_card_inventory_runtime_controller_node()
	var core_economic_adapter := _core_economic_card_runtime_adapter_v06_node()
	var commodity_flow_controller := _commodity_flow_runtime_controller_node()
	var region_infrastructure := _region_infrastructure_runtime_controller_node()
	var region_infrastructure_bridge := _region_infrastructure_world_bridge_node()
	var organization_owner := _player_organization_runtime_controller_node()
	var session_state := _world_session_state_node()
	if card_player_state_adapter is CardPlayerStateProductionAdapterV06:
		(card_player_state_adapter as CardPlayerStateProductionAdapterV06).set_world_session_state(session_state)
	if commodity_card_inventory is CommodityCardInventoryRuntimeController:
		(commodity_card_inventory as CommodityCardInventoryRuntimeController).set_world_session_state(session_state)
	var actor_map: Dictionary = card_player_state_adapter.call("actor_player_indices") if card_player_state_adapter != null and card_player_state_adapter.has_method("actor_player_indices") else {}
	var belt_bootstrap: Dictionary = commodity_card_inventory.call("initialize_default_belt_if_empty", commodity_seed, commodity_card_ids) \
		if commodity_card_inventory != null and commodity_card_inventory.has_method("initialize_default_belt_if_empty") else {}
	var organization_owner_result := _configure_player_organization_runtime(actor_map)
	var public_demand_bootstrap := _bootstrap_v06_public_demand_endpoints()
	var core_configure: Dictionary = {}
	if core_economic_adapter != null and core_economic_adapter.has_method("configure"):
		var configured_variant: Variant = core_economic_adapter.call(
			"configure",
			commodity_card_inventory,
			commodity_flow_controller,
			region_infrastructure,
			actor_map,
			region_infrastructure_bridge,
			organization_owner,
			_organization_consumer_ports_v06()
		)
		if configured_variant is Dictionary:
			core_configure = (configured_variant as Dictionary).duplicate(true)
	var state_snapshot := _card_player_state_production_adapter_v06_debug_snapshot()
	var inventory_snapshot := _commodity_card_inventory_runtime_debug_snapshot()
	var core_snapshot := _core_economic_card_runtime_adapter_v06_debug_snapshot()
	var monster_adapter_ready := _refresh_monster_card_effect_adapter_v06()
	var state_ready := bool(state_snapshot.get("adapter_ready", false))
	var inventory_ready := bool(inventory_snapshot.get("controller_ready", false))
	var core_ready := bool(core_snapshot.get("configured", false)) and bool(core_configure.get("configured", core_snapshot.get("configured", false)))
	var organization_readiness: Dictionary = core_snapshot.get("organization_consumer_readiness", {}) if core_snapshot.get("organization_consumer_readiness", {}) is Dictionary else {}
	var public_demand_ready := bool(public_demand_bootstrap.get("ready", false))
	var belt_ready := bool(belt_bootstrap.get("configured", false))
	var binding_ready := not actor_map.is_empty() and state_ready and inventory_ready and core_ready and monster_adapter_ready and public_demand_ready and belt_ready
	_last_v06_player_binding_result = {
		"ready": binding_ready,
		"reason_code": "production_players_bound" if binding_ready else "production_players_not_bound",
		"actor_count": actor_map.size(),
		"state_adapter_ready": state_ready,
		"inventory_ready": inventory_ready,
		"core_economic_ready": core_ready,
		"organization_owner_ready": bool(organization_owner_result.get("configured", false)),
		"organization_owner": organization_owner_result.duplicate(true),
		"organization_consumers_ready": bool(organization_readiness.get("production_ready", false)),
		"organization_consumer_readiness": organization_readiness.duplicate(true),
		"monster_card_adapter_ready": monster_adapter_ready,
		"public_demand_ready": public_demand_ready,
		"public_demand_bootstrap": public_demand_bootstrap.duplicate(true),
		"commodity_belt_ready": belt_ready,
		"commodity_belt_bootstrap": belt_bootstrap.duplicate(true),
	}
	_refresh_coordinator_readiness()
	return _last_v06_player_binding_result.duplicate(true)


func _configure_player_organization_runtime(actor_map: Dictionary) -> Dictionary:
	var organization_owner := _player_organization_runtime_controller_node()
	var actor_ids: Array = actor_map.keys()
	actor_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
	if organization_owner == null or actor_ids.is_empty() or not organization_owner.has_method("configure"):
		return {"configured": false, "reason_code": "organization_owner_or_actors_unavailable", "actor_count": actor_ids.size()}
	var debug: Dictionary = _player_organization_runtime_debug_snapshot()
	var existing_ids: Array = []
	if debug.get("players", {}) is Dictionary:
		existing_ids = (debug.get("players", {}) as Dictionary).keys()
		existing_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
	if bool(debug.get("configured", false)) and existing_ids == actor_ids:
		return {"configured": true, "reason_code": "organization_owner_binding_preserved", "actor_count": actor_ids.size()}
	var configured_variant: Variant = organization_owner.call("configure", actor_ids)
	return (configured_variant as Dictionary).duplicate(true) if configured_variant is Dictionary else {"configured": false, "reason_code": "organization_owner_configure_invalid", "actor_count": actor_ids.size()}


func _organization_consumer_ports_v06() -> Dictionary:
	return {
		"asset_recovery": _player_mana_runtime_controller_node(),
		"hand_limit": _card_player_state_production_adapter_v06_node(),
		"card_window": _card_resolution_queue_node(),
		"monster_binding": _monster_runtime_controller_node(),
		"military_command": _military_runtime_controller_node(),
	}


func _bootstrap_v06_public_demand_endpoints() -> Dictionary:
	var infrastructure := _region_infrastructure_runtime_controller_node()
	var infrastructure_bridge := _region_infrastructure_world_bridge_node()
	var flow := _commodity_flow_runtime_controller_node()
	if infrastructure == null \
		or infrastructure_bridge == null \
		or flow == null \
		or not infrastructure.has_method("apply_facility_action") \
		or not infrastructure.has_method("rollback_facility_action") \
		or not infrastructure.has_method("finalize_facility_action") \
		or not infrastructure.has_method("facility_action_lifecycle_snapshot") \
		or not infrastructure.has_method("facilities_snapshot") \
		or not infrastructure_bridge.has_method("public_commodity_region_facts") \
		or not flow.has_method("install_public_demand") \
		or not flow.has_method("rollback_commodity_installation") \
		or not flow.has_method("commodity_installation_finalize_preflight") \
		or not flow.has_method("finalize_commodity_installation"):
		return {"ready": false, "reason_code": "public_demand_owner_unavailable"}
	var facts_variant: Variant = infrastructure_bridge.call("public_commodity_region_facts")
	if not (facts_variant is Array) or (facts_variant as Array).is_empty():
		return {"ready": false, "reason_code": "public_demand_region_facts_unavailable"}
	var groups: Dictionary = {}
	for facts_variant_item in facts_variant as Array:
		if not (facts_variant_item is Dictionary):
			return {"ready": false, "reason_code": "public_demand_region_facts_invalid"}
		var facts: Dictionary = facts_variant_item
		if not bool(facts.get("available", false)) or not bool(facts.get("authoritative", false)):
			return {"ready": false, "reason_code": "public_demand_region_facts_invalid"}
		var region_id := str(facts.get("region_id", "")).strip_edges()
		var demand_rows: Array = facts.get("demand_products", []) if facts.get("demand_products", []) is Array else []
		for demand_variant in demand_rows:
			if not (demand_variant is Dictionary):
				return {"ready": false, "reason_code": "public_demand_product_facts_invalid"}
			var demand: Dictionary = demand_variant
			var product_id := str(demand.get("product_id", "")).strip_edges()
			var industry_id := str(demand.get("industry_id", "")).strip_edges()
			if region_id.is_empty() or product_id.is_empty() or industry_id.is_empty():
				return {"ready": false, "reason_code": "public_demand_product_facts_invalid"}
			var group_id := "%s|%s" % [region_id, industry_id]
			if not groups.has(group_id):
				groups[group_id] = {
					"region_id": region_id,
					"industry_id": industry_id,
					"products": [],
				}
			var group: Dictionary = groups[group_id]
			var products: Array = group.get("products", []) if group.get("products", []) is Array else []
			if not products.has(product_id):
				products.append(product_id)
				products.sort()
			group["products"] = products
			groups[group_id] = group
	if groups.is_empty():
		return {"ready": false, "reason_code": "public_demand_products_missing"}
	var group_ids: Array = groups.keys()
	group_ids.sort()
	var installation_count := 0
	var market_count := 0
	for group_id_variant in group_ids:
		var group: Dictionary = groups[group_id_variant]
		var group_result := _bootstrap_v06_public_demand_group(infrastructure, flow, group)
		if not bool(group_result.get("ready", false)):
			return group_result
		installation_count += int(group_result.get("installation_count", 0))
		market_count += int(group_result.get("market_count", 0))
	var route_network := _route_network_runtime_controller_node()
	if route_network != null and route_network.has_method("refresh_routes"):
		route_network.call("refresh_routes", true)
	return {
		"ready": true,
		"reason_code": "public_demand_endpoints_ready",
		"market_count": market_count,
		"installation_count": installation_count,
		"owner_kind": "public",
		"player_attribution": false,
	}


func _bootstrap_v06_public_demand_group(infrastructure: Object, flow: Object, group: Dictionary) -> Dictionary:
	var region_id := str(group.get("region_id", ""))
	var industry_id := str(group.get("industry_id", ""))
	var products: Array = group.get("products", []) if group.get("products", []) is Array else []
	# v0.6 initial region facts define one public demand product per industry.
	# Multi-product finalization requires an owner-level batch protocol and remains closed.
	if region_id.is_empty() or industry_id.is_empty() or products.size() != 1:
		return {
			"ready": false,
			"reason_code": "public_demand_group_cardinality_unsupported",
			"region_id": region_id,
			"industry_id": industry_id,
			"product_count": products.size(),
		}
	var market_transaction_id := "vs06-public-demand-market:%s:%s" % [region_id, industry_id]
	var market_variant: Variant = infrastructure.call("apply_facility_action", {
		"transaction_id": market_transaction_id,
		"region_id": region_id,
		"owner_kind": "neutral",
		"owner_player_index": -1,
		"facility_type": "market",
		"industry_id": industry_id,
		"rank": 1,
		"occurred_at": 0.0,
	})
	var market_receipt: Dictionary = (market_variant as Dictionary).duplicate(true) if market_variant is Dictionary else {}
	if not bool(market_receipt.get("committed", false)):
		return {
			"ready": false,
			"reason_code": str(market_receipt.get("reason_code", market_receipt.get("reason", "public_demand_market_commit_failed"))),
			"region_id": region_id,
			"industry_id": industry_id,
		}
	var market_facility := _v06_facility_snapshot(infrastructure, str(market_receipt.get("facility_id", "")))
	if market_facility.is_empty() or str(market_facility.get("owner_kind", "")) != "neutral":
		return _rollback_v06_public_demand_group(infrastructure, flow, market_receipt, [], "public_demand_market_snapshot_invalid")
	var installation_receipts: Array = []
	for product_variant in products:
		var product_id := str(product_variant)
		var product_token := product_id.sha256_text().substr(0, 16)
		var installation_transaction_id := "vs06-public-demand-install:%s:%s:%s" % [region_id, industry_id, product_token]
		var region_snapshot_variant: Variant = infrastructure.call("region_snapshot", region_id)
		var region_snapshot: Dictionary = (region_snapshot_variant as Dictionary).duplicate(true) if region_snapshot_variant is Dictionary else {}
		var install_variant: Variant = flow.call("install_public_demand", {
			"transaction_id": installation_transaction_id,
			"installation_id": "%s:installation" % installation_transaction_id,
			"facility": market_facility.duplicate(true),
			"facility_id": str(market_facility.get("facility_id", "")),
			"region_id": region_id,
			"region_revision": int(region_snapshot.get("revision", 0)),
			"commodity_id": product_id,
			"source_card_rank": 1,
			"color": industry_id,
			"installed_at": 0.0,
		})
		var install_receipt: Dictionary = (install_variant as Dictionary).duplicate(true) if install_variant is Dictionary else {}
		if not bool(install_receipt.get("committed", false)):
			return _rollback_v06_public_demand_group(infrastructure, flow, market_receipt, installation_receipts, str(install_receipt.get("reason_code", install_receipt.get("reason", "public_demand_install_failed"))))
		installation_receipts.append(install_receipt)
	var installation_receipt: Dictionary = installation_receipts[0]
	var market_preflight := _v06_facility_finalize_preflight(infrastructure, market_receipt)
	if not bool(market_preflight.get("ready", false)):
		return _rollback_v06_public_demand_group(infrastructure, flow, market_receipt, installation_receipts, str(market_preflight.get("reason_code", "public_demand_market_finalize_preflight_failed")))
	var installation_preflight_variant: Variant = flow.call("commodity_installation_finalize_preflight", installation_receipt.duplicate(true))
	var installation_preflight: Dictionary = (installation_preflight_variant as Dictionary).duplicate(true) if installation_preflight_variant is Dictionary else {}
	if not bool(installation_preflight.get("ready", false)):
		return _rollback_v06_public_demand_group(infrastructure, flow, market_receipt, installation_receipts, str(installation_preflight.get("reason_code", "public_demand_install_finalize_preflight_failed")))
	# Finalize the facility first. The preflighted flow finalizer has no remaining
	# rejection branch in this synchronous call stack.
	var market_finalize_variant: Variant = infrastructure.call("finalize_facility_action", market_receipt.duplicate(true))
	var market_finalize: Dictionary = (market_finalize_variant as Dictionary).duplicate(true) if market_finalize_variant is Dictionary else {}
	if not bool(market_finalize.get("finalized", false)):
		return _rollback_v06_public_demand_group(infrastructure, flow, market_receipt, installation_receipts, str(market_finalize.get("reason_code", "public_demand_market_finalize_failed")))
	var finalize_variant: Variant = flow.call("finalize_commodity_installation", installation_receipt.duplicate(true))
	var finalize_result: Dictionary = (finalize_variant as Dictionary).duplicate(true) if finalize_variant is Dictionary else {}
	if not bool(finalize_result.get("finalized", false)):
		return {
			"ready": false,
			"reason_code": "public_demand_install_finalize_failed_after_market",
			"owner_reason_code": str(finalize_result.get("reason_code", "public_demand_install_finalize_failed")),
			"region_id": region_id,
			"industry_id": industry_id,
		}
	return {
		"ready": true,
		"reason_code": "public_demand_group_ready",
		"region_id": region_id,
		"industry_id": industry_id,
		"market_count": 1,
		"installation_count": installation_receipts.size(),
	}


func _rollback_v06_public_demand_group(infrastructure: Object, flow: Object, market_receipt: Dictionary, installation_receipts: Array, reason_code: String) -> Dictionary:
	var rollback_failed := false
	for index in range(installation_receipts.size() - 1, -1, -1):
		var receipt: Dictionary = installation_receipts[index]
		var rollback_variant: Variant = flow.call("rollback_commodity_installation", str(receipt.get("transaction_id", "")))
		var rollback_result: Dictionary = (rollback_variant as Dictionary).duplicate(true) if rollback_variant is Dictionary else {}
		rollback_failed = rollback_failed or not bool(rollback_result.get("rolled_back", false))
	if bool(market_receipt.get("rollback_open", true)):
		var market_rollback_variant: Variant = infrastructure.call("rollback_facility_action", market_receipt.duplicate(true))
		var market_rollback: Dictionary = (market_rollback_variant as Dictionary).duplicate(true) if market_rollback_variant is Dictionary else {}
		rollback_failed = rollback_failed or not bool(market_rollback.get("rolled_back", false))
	return {
		"ready": false,
		"reason_code": reason_code,
		"compensation_failed": rollback_failed,
	}


func _v06_facility_snapshot(infrastructure: Object, facility_id: String) -> Dictionary:
	var value: Variant = infrastructure.call("facilities_snapshot", false)
	if not (value is Array):
		return {}
	for facility_variant in value as Array:
		if facility_variant is Dictionary and str((facility_variant as Dictionary).get("facility_id", "")) == facility_id:
			return (facility_variant as Dictionary).duplicate(true)
	return {}


func _v06_facility_finalize_preflight(infrastructure: Object, receipt: Dictionary) -> Dictionary:
	if infrastructure == null or not infrastructure.has_method("facility_action_lifecycle_snapshot"):
		return {"ready": false, "reason_code": "facility_finalize_preflight_unavailable"}
	var transaction_id := str(receipt.get("transaction_id", "")).strip_edges()
	if transaction_id.is_empty() or not ["facility_action", "facility_action_finalize"].has(str(receipt.get("receipt_kind", ""))):
		return {"ready": false, "reason_code": "facility_receipt_binding_invalid", "transaction_id": transaction_id}
	var lifecycle_variant: Variant = infrastructure.call("facility_action_lifecycle_snapshot", transaction_id)
	var lifecycle: Dictionary = (lifecycle_variant as Dictionary).duplicate(true) if lifecycle_variant is Dictionary else {}
	if lifecycle.is_empty():
		return {"ready": false, "reason_code": "facility_action_transaction_missing", "transaction_id": transaction_id}
	var state := str(lifecycle.get("state", ""))
	if state == "finalized":
		return {"ready": true, "reason_code": "facility_finalize_ready", "transaction_id": transaction_id, "already_finalized": true}
	var original: Dictionary = lifecycle.get("original_receipt", {}) if lifecycle.get("original_receipt", {}) is Dictionary else {}
	if state != "applied" \
		or not bool(lifecycle.get("rollback_open", false)) \
		or str(original.get("owner_binding_fingerprint", "")) != str(receipt.get("owner_binding_fingerprint", "")) \
		or int(original.get("receipt_sequence", -1)) != int(receipt.get("receipt_sequence", -2)):
		return {"ready": false, "reason_code": "facility_receipt_binding_invalid", "transaction_id": transaction_id}
	return {"ready": true, "reason_code": "facility_finalize_ready", "transaction_id": transaction_id, "already_finalized": false}


func _v06_world_game_time() -> float:
	var state := _world_session_state_node()
	return state.game_time if state != null else 0.0


func _refresh_coordinator_readiness() -> void:
	_configured = _composition_ready and bool(_last_v06_player_binding_result.get("ready", false))
	var ports := _runtime_world_ports_node()
	if ports != null and _runtime_lifecycle_port_node() != null:
		_runtime_lifecycle_port_node().set_composition_ready(_bound_world != null and is_instance_valid(_bound_world) and _configured)


func _wire_runtime_world_ports() -> void:
	var ports := _runtime_world_ports_node()
	var phases := get_node_or_null("RuntimePhaseCoordinator") as RuntimePhaseCoordinator
	var loop := _runtime_loop_node()
	if ports == null or phases == null or loop == null:
		return
	_runtime_lifecycle_port_node().bind_dependencies(
		_session_node() as GameSessionRuntimeController,
		_scheduler_node() as ForcedDecisionRuntimeScheduler,
		_forced_decision_candidate_sources_node(),
		_world_effective_clock_runtime_controller_node() as WorldEffectiveClockRuntimeController,
		_world_session_state_node()
	)
	_runtime_card_port_node().bind_dependencies(
		_card_resolution_frame_driver_node(),
		_card_cooldown_runtime_controller_node(),
		_scheduler_node() as ForcedDecisionRuntimeScheduler
	)
	_runtime_economy_port_node().bind_dependencies(
		_city_gdp_derivative_runtime_controller_node() as CityGdpDerivativeRuntimeController,
		_product_market_runtime_controller_node() as ProductMarketRuntimeController,
		_commodity_flow_runtime_controller_node() as CommodityFlowRuntimeController,
		_bankruptcy_neutral_estate_runtime_controller_node() as BankruptcyNeutralEstateRuntimeController,
		_player_mana_runtime_controller_node() as PlayerManaRuntimeController,
		_session_node() as GameSessionRuntimeController,
		_scheduler_node() as ForcedDecisionRuntimeScheduler,
		_world_session_state_node()
	)
	_runtime_actor_port_node().bind_dependencies(
		_weather_runtime_controller_node() as WeatherRuntimeController,
		_ai_runtime_controller_node() as AiRuntimeController,
		_military_runtime_controller_node() as MilitaryRuntimeController,
		_victory_control_runtime_controller_node() as VictoryControlRuntimeController
	)
	_runtime_monster_port_node().bind_dependency(_monster_runtime_controller_node() as MonsterRuntimeController)
	_runtime_presentation_port_node().bind_dependencies(
		_visual_cue_runtime_owner_node(),
		_table_presentation_refresh_scheduler_node(),
		_table_presentation_refresh_port_node(),
		_developer_balance_presentation_target_node()
	)
	_runtime_victory_port_node().bind_dependencies(
		_victory_control_runtime_controller_node() as VictoryControlRuntimeController,
		_victory_control_world_bridge_node() as VictoryControlWorldBridge,
		_session_node() as GameSessionRuntimeController,
		_ai_runtime_controller_node() as AiRuntimeController,
		_table_presentation_query_ports_node()
	)
	phases.bind_ports(ports)
	loop.bind_phase_coordinator(phases)
	_runtime_lifecycle_port_node().set_composition_ready(_bound_world != null and is_instance_valid(_bound_world) and _configured)


func _refresh_monster_card_effect_adapter_v06() -> bool:
	var monster_controller := _monster_runtime_controller_node()
	if monster_controller == null:
		_monster_card_effect_adapter_v06 = null
		return false
	if _monster_card_effect_adapter_v06 == null:
		_monster_card_effect_adapter_v06 = MONSTER_CARD_EFFECT_ADAPTER_V06.new()
	var configured_variant: Variant = _monster_card_effect_adapter_v06.call("configure", monster_controller)
	var configured: Dictionary = configured_variant if configured_variant is Dictionary else {}
	var matrix_variant: Variant = _monster_card_effect_adapter_v06.call("capability_matrix") if _monster_card_effect_adapter_v06.has_method("capability_matrix") else {}
	var matrix: Dictionary = matrix_variant if matrix_variant is Dictionary else {}
	return bool(configured.get("configured", false)) and bool(matrix.get("atomic_mutation_ready", false))


func victory_control_runtime_controller() -> VictoryControlRuntimeController:
	return _victory_control_runtime_controller_node() as VictoryControlRuntimeController


func victory_control_world_bridge() -> VictoryControlWorldBridge:
	return _victory_control_world_bridge_node() as VictoryControlWorldBridge


func victory_control_world_snapshot(clock_pause: Dictionary = {}, settlement_checkpoint := "read_only") -> Dictionary:
	var bridge := _victory_control_world_bridge_node()
	var value: Variant = bridge.call("capture_world_snapshot", clock_pause, settlement_checkpoint) if bridge != null and bridge.has_method("capture_world_snapshot") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func advance_victory_control(delta_seconds: float, clock_pause: Dictionary = {}) -> Dictionary:
	var ports := _runtime_world_ports_node()
	return _runtime_victory_port_node().advance_victory_control(delta_seconds, clock_pause) if ports != null and _runtime_victory_port_node() != null else {
		"valid": false,
		"reason": "runtime_victory_port_unavailable",
	}


func resolve_victory_outcome(reason_code: String, clock_pause: Dictionary = {}) -> Dictionary:
	var controller := _victory_control_runtime_controller_node()
	if controller == null or not controller.has_method("resolve_special_outcome"):
		return {}
	var world_snapshot := victory_control_world_snapshot(clock_pause)
	var value: Variant = controller.call("resolve_special_outcome", reason_code, world_snapshot)
	var receipt: Dictionary = (value as Dictionary).duplicate(true) if value is Dictionary else {}
	_apply_victory_outcome_receipt(receipt)
	return receipt


func victory_control_public_snapshot(viewer_index := -1) -> Dictionary:
	var controller := _victory_control_runtime_controller_node()
	var value: Variant = controller.call("public_snapshot", viewer_index) if controller != null and controller.has_method("public_snapshot") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func table_presentation_query_ports() -> TablePresentationQueryPorts:
	return _table_presentation_query_ports_node()


func presentation_authorized_viewer_index() -> int:
	var ports := _table_presentation_query_ports_node()
	return ports.authorized_viewer_index() if ports != null else -1


func presentation_can_view_private_subject(subject_index: int) -> bool:
	var ports := _table_presentation_query_ports_node()
	var viewer_index := ports.authorized_viewer_index() if ports != null else -1
	return ports.can_view_private_subject(viewer_index, subject_index) if ports != null else false


func presentation_public_world_projection() -> WorldSessionPublicProjection:
	var ports := _table_presentation_query_ports_node()
	return ports.public_world_projection() if ports != null else WorldSessionPublicProjection.new()


func presentation_private_world_projection(viewer_index: int, subject_index: int) -> WorldSessionPrivateProjection:
	var ports := _table_presentation_query_ports_node()
	return ports.private_world_projection(viewer_index, subject_index) if ports != null else WorldSessionPrivateProjection.new()


func presentation_action_projection(viewer_index: int) -> TableActionPresentationProjection:
	var ports := _table_presentation_query_ports_node()
	return ports.action_projection(viewer_index) if ports != null else TableActionPresentationProjection.new()


func presentation_public_map_projection(viewer_index: int, commodity_id := "") -> TablePublicMapProjection:
	var ports := _table_presentation_query_ports_node()
	return ports.public_map_projection(viewer_index, commodity_id) if ports != null else TablePublicMapProjection.new()


func record_public_log_event(
	event_kind: StringName,
	localization_key: StringName,
	public_values: Dictionary,
	source_revision: int,
	world_time: float,
	receipt_id := ""
) -> Dictionary:
	var ports := _table_presentation_query_ports_node()
	return ports.publish_public_log(event_kind, localization_key, public_values, source_revision, world_time, receipt_id) if ports != null else {"applied": false, "reason_code": "table_presentation_query_ports_missing"}


func record_legacy_viewer_feedback(message: String) -> Dictionary:
	var ports := _table_presentation_query_ports_node()
	if ports == null:
		return {"applied": false, "reason_code": "presentation_query_ports_missing"}
	var viewer := ports.authorized_viewer_index()
	return ports.record_viewer_private_feedback(viewer, message)


func append_public_log_receipt(receipt: PublicLogReceipt) -> Dictionary:
	var ports := _table_presentation_query_ports_node()
	return ports.append_public_log_receipt(receipt) if ports != null else {"applied": false, "reason_code": "table_presentation_query_ports_missing"}


func presentation_recent_public_log_messages(limit := 6) -> Array:
	var ports := _table_presentation_query_ports_node()
	return ports.recent_public_log_messages(limit) if ports != null else []


func presentation_recent_public_log_entries(limit := 6) -> Array:
	var ports := _table_presentation_query_ports_node()
	return ports.recent_public_log_entries(limit) if ports != null else []


func import_legacy_viewer_feedback(messages: Array) -> Dictionary:
	var ports := _table_presentation_query_ports_node()
	return ports.import_legacy_viewer_feedback(messages) if ports != null else {"applied": 0, "reason_code": "table_presentation_query_ports_missing"}


func reset_public_log() -> void:
	var ports := _table_presentation_query_ports_node()
	if ports != null:
		ports.reset_public_log()


func victory_control_private_snapshot(viewer_index: int) -> Dictionary:
	var controller := _victory_control_runtime_controller_node()
	var value: Variant = controller.call("private_snapshot", viewer_index) if controller != null and controller.has_method("private_snapshot") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func victory_control_outcome_receipt() -> Dictionary:
	var controller := _victory_control_runtime_controller_node()
	var value: Variant = controller.call("outcome_receipt") if controller != null and controller.has_method("outcome_receipt") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func victory_control_rankings(eligible_only := false) -> Array:
	var controller := _victory_control_runtime_controller_node()
	if controller == null or not controller.has_method("preview_rankings"):
		return []
	var value: Variant = controller.call("preview_rankings", victory_control_world_snapshot(), eligible_only)
	return (value as Array).duplicate(true) if value is Array else []


func victory_control_to_save_data() -> Dictionary:
	var controller := _victory_control_runtime_controller_node()
	var value: Variant = controller.call("to_save_data") if controller != null and controller.has_method("to_save_data") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func apply_victory_control_save_data(data: Dictionary) -> Dictionary:
	var controller := _victory_control_runtime_controller_node()
	var value: Variant = controller.call("apply_save_data", data) if controller != null and controller.has_method("apply_save_data") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func reset_victory_control_runtime() -> void:
	var controller := _victory_control_runtime_controller_node()
	if controller != null and controller.has_method("reset_state"):
		controller.call("reset_state")


func session_is_finished() -> bool:
	var ports := _runtime_world_ports_node()
	return _runtime_lifecycle_port_node().session_is_finished() if ports != null and _runtime_lifecycle_port_node() != null else true


func session_is_paused() -> bool:
	var ports := _runtime_world_ports_node()
	return _runtime_lifecycle_port_node().session_is_paused() if ports != null and _runtime_lifecycle_port_node() != null else true


func session_to_save_data() -> Dictionary:
	var session := _session_node()
	var value: Variant = session.call("to_save_data") if session != null and session.has_method("to_save_data") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func apply_session_save_data(data: Dictionary) -> Dictionary:
	var session := _session_node()
	var value: Variant = session.call("apply_save_data", data) if session != null and session.has_method("apply_save_data") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func advance_world_effective_clock(delta_seconds: float) -> Dictionary:
	var clock := _world_effective_clock_runtime_controller_node()
	var value: Variant = clock.call("advance", delta_seconds) if clock != null and clock.has_method("advance") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func advance_runtime_world_time(delta_seconds: float) -> Dictionary:
	var ports := _runtime_world_ports_node()
	return _runtime_lifecycle_port_node().advance_world_time(delta_seconds) if ports != null and _runtime_lifecycle_port_node() != null else {
		"advanced": false,
		"reason": "runtime_lifecycle_port_unavailable",
	}


func restore_world_effective_seconds(seconds: float) -> Dictionary:
	var clock := _world_effective_clock_runtime_controller_node()
	var value: Variant = clock.call("restore_seconds", seconds) if clock != null and clock.has_method("restore_seconds") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func world_effective_clock_snapshot() -> Dictionary:
	var clock := _world_effective_clock_runtime_controller_node()
	var value: Variant = clock.call("snapshot") if clock != null and clock.has_method("snapshot") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func run_rng_service() -> RunRngService:
	return _run_rng_service_node()


func table_selection_state() -> TableSelectionState:
	return _table_selection_state_node()


func gameplay_actor_authorization_context(source_surface: StringName = &"game_screen") -> GameplayActorAuthorizationContext:
	var boundary := get_node_or_null("PlayerIdentityAuthorizationBoundary") as PlayerIdentityAuthorizationBoundary
	return boundary.current_actor_context(source_surface) if boundary != null else GameplayActorAuthorizationContext.denied("actor_authority_missing", 0, source_surface)


func card_supply_presentation_state() -> TableCardSupplyPresentationState:
	return _table_card_supply_presentation_state_node()


func world_session_state() -> WorldSessionState:
	return _world_session_state_node()


func current_runtime_simulation_step_index() -> int:
	var step := get_node_or_null("RuntimePhaseCoordinator/RuntimeSimulationStep") as RuntimeSimulationStep
	return step.current_step_index() if step != null else 0


func card_resolution_history_service() -> CardResolutionHistoryRuntimeService:
	return _card_resolution_history_runtime_service_node()


func card_play_submission_controller() -> CardPlaySubmissionRuntimeController:
	return _card_play_submission_runtime_controller_node()


func card_target_choice_response_sink() -> CARD_TARGET_CHOICE_RESPONSE_SINK_SCRIPT:
	return get_node_or_null("CardTargetChoiceResponseSink") as CARD_TARGET_CHOICE_RESPONSE_SINK_SCRIPT


func submit_card_play(request: Dictionary) -> Dictionary:
	var controller := _card_play_submission_runtime_controller_node()
	return controller.submit_card_play(request) if controller != null else {"accepted": false, "reason": "submission_controller_missing"}


func request_hand_card_play(request: Dictionary) -> Dictionary:
	var controller := _card_play_submission_runtime_controller_node()
	return controller.request_hand_play(request) if controller != null else {"accepted": false, "reason": "submission_controller_missing"}


func card_resolution_history_snapshot() -> Array:
	var service := _card_resolution_history_runtime_service_node()
	return service.history_snapshot() if service != null else []


func card_resolution_public_history_snapshot() -> Array:
	var service := _card_resolution_history_runtime_service_node()
	return service.public_history_snapshot() if service != null else []


func card_resolution_viewer_history_snapshot(viewer_index: int) -> Array:
	var service := _card_resolution_history_runtime_service_node()
	return service.private_viewer_snapshot(viewer_index) if service != null else []


func card_history_public_snapshot() -> Dictionary:
	var query := _card_history_public_query_port_node()
	var value: Variant = query.call("compose_history") if query != null and query.has_method("compose_history") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func card_history_private_annotations(viewer_index: int) -> Dictionary:
	var annotations := _card_history_private_annotation_service_node()
	var value: Variant = annotations.call("viewer_snapshot", viewer_index) if annotations != null and annotations.has_method("viewer_snapshot") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func apply_card_history_private_annotation(viewer_index: int, history_entry_id: String, patch: Dictionary) -> Dictionary:
	var annotations := _card_history_private_annotation_service_node()
	var value: Variant = annotations.call("apply_annotation", viewer_index, history_entry_id, patch.duplicate(true)) if annotations != null and annotations.has_method("apply_annotation") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {"applied": false, "reason_code": "annotation_service_unavailable"}


func refresh_card_history_private_subscriptions() -> Dictionary:
	var annotations := _card_history_private_annotation_service_node()
	var value: Variant = annotations.call("refresh_subscriptions") if annotations != null and annotations.has_method("refresh_subscriptions") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {"refreshed": false, "reason_code": "annotation_service_unavailable"}


func card_resolution_history_entry(resolution_id: int) -> Dictionary:
	var service := _card_resolution_history_runtime_service_node()
	return service.entry_by_id(resolution_id) if service != null else {}


func patch_card_resolution_history_entry(resolution_id: int, entry: Dictionary) -> Dictionary:
	var service := _card_resolution_history_runtime_service_node()
	if service == null:
		return {"patched": false, "reason": "history_service_missing"}
	var patch := entry.duplicate(true)
	patch.erase("resolution_id")
	patch.erase("queued_order")
	patch.erase("player_index")
	return service.patch_entry(resolution_id, patch)


func replace_card_resolution_legacy_history(entries: Array) -> Dictionary:
	var service := _card_resolution_history_runtime_service_node()
	return service.replace_legacy_entries(entries) if service != null else {"applied": false, "reason": "history_service_missing"}


func reset_card_resolution_history() -> void:
	var service := _card_resolution_history_runtime_service_node()
	if service != null:
		service.reset_state()
	var annotations := _card_history_private_annotation_service_node()
	if annotations != null and annotations.has_method("reset_state"):
		annotations.call("reset_state")


func _wire_run_rng_service() -> void:
	var service := _run_rng_service_node()
	if service == null:
		return
	service.configure({})
	var ai_controller := _ai_runtime_controller_node() as AiRuntimeController
	var monster_bridge := _monster_runtime_world_bridge_node()
	var weather_bridge := _weather_runtime_world_bridge_node()
	var product_market_bridge := _product_market_runtime_world_bridge_node()
	if ai_controller != null:
		ai_controller.set_run_rng_service(service)
	if monster_bridge is MonsterRuntimeWorldBridge:
		(monster_bridge as MonsterRuntimeWorldBridge).set_rng_service(service)
	if weather_bridge is WeatherRuntimeWorldBridge:
		(weather_bridge as WeatherRuntimeWorldBridge).set_rng_service(service)
	if product_market_bridge is ProductMarketRuntimeWorldBridge:
		(product_market_bridge as ProductMarketRuntimeWorldBridge).set_rng_service(service)


func _wire_table_selection_state() -> void:
	var state := _table_selection_state_node()
	if state == null:
		return
	var monster_bridge := _monster_runtime_world_bridge_node()
	var military_bridge := _military_runtime_world_bridge_node()
	var market_bridge := _product_market_runtime_world_bridge_node()
	var eligibility_bridge := _card_play_world_bridge_node()
	var diagnostics_bridge := _gameplay_balance_diagnostics_world_bridge_node()
	var infrastructure_bridge := _region_infrastructure_world_bridge_node()
	var resolution_bridge := _card_resolution_execution_world_bridge_node()
	var economy_bridge := _card_economy_product_route_effect_world_bridge_node()
	if monster_bridge is MonsterRuntimeWorldBridge:
		(monster_bridge as MonsterRuntimeWorldBridge).set_table_selection_state(state)
	if military_bridge is MilitaryRuntimeWorldBridge:
		(military_bridge as MilitaryRuntimeWorldBridge).set_table_selection_state(state)
	if market_bridge is ProductMarketRuntimeWorldBridge:
		(market_bridge as ProductMarketRuntimeWorldBridge).set_table_selection_state(state)
	if eligibility_bridge is CardPlayEligibilityWorldBridge:
		(eligibility_bridge as CardPlayEligibilityWorldBridge).set_table_selection_state(state)
	if diagnostics_bridge is GameplayBalanceDiagnosticsWorldBridge:
		(diagnostics_bridge as GameplayBalanceDiagnosticsWorldBridge).set_table_selection_state(state)
	if infrastructure_bridge is RegionInfrastructureWorldBridge:
		(infrastructure_bridge as RegionInfrastructureWorldBridge).set_table_selection_state(state)
	if resolution_bridge is CardResolutionExecutionWorldBridge:
		(resolution_bridge as CardResolutionExecutionWorldBridge).set_table_selection_state(state)
	if economy_bridge is CardEconomyProductRouteEffectWorldBridge:
		(economy_bridge as CardEconomyProductRouteEffectWorldBridge).set_table_selection_state(state)


func _wire_world_session_state() -> void:
	var state := _world_session_state_node()
	if state == null:
		return
	var monster_bridge := _monster_runtime_world_bridge_node()
	var military_bridge := _military_runtime_world_bridge_node()
	var weather_bridge := _weather_runtime_world_bridge_node()
	var market_bridge := _product_market_runtime_world_bridge_node()
	var eligibility_bridge := _card_play_world_bridge_node()
	var diagnostics_bridge := _gameplay_balance_diagnostics_world_bridge_node()
	var infrastructure_bridge := _region_infrastructure_world_bridge_node()
	var resolution_bridge := _card_resolution_execution_world_bridge_node()
	var economy_bridge := _card_economy_product_route_effect_world_bridge_node()
	var card_market_bridge := _card_market_policy_world_bridge_node()
	var derivative_bridge := _city_gdp_derivative_runtime_world_bridge_node()
	var route_bridge := _route_network_world_bridge_node()
	var flow_bridge := _commodity_flow_world_bridge_node()
	var victory_bridge := _victory_control_world_bridge_node()
	var bankruptcy_bridge := _bankruptcy_neutral_estate_world_bridge_node()
	var card_player_state := _card_player_state_production_adapter_v06_node()
	var card_inventory := _commodity_card_inventory_runtime_controller_node()
	if monster_bridge is MonsterRuntimeWorldBridge:
		(monster_bridge as MonsterRuntimeWorldBridge).set_world_session_state(state)
	if military_bridge is MilitaryRuntimeWorldBridge:
		(military_bridge as MilitaryRuntimeWorldBridge).set_world_session_state(state)
	if weather_bridge is WeatherRuntimeWorldBridge:
		(weather_bridge as WeatherRuntimeWorldBridge).set_world_session_state(state)
	if market_bridge is ProductMarketRuntimeWorldBridge:
		(market_bridge as ProductMarketRuntimeWorldBridge).set_world_session_state(state)
	if eligibility_bridge is CardPlayEligibilityWorldBridge:
		(eligibility_bridge as CardPlayEligibilityWorldBridge).set_world_session_state(state)
	if diagnostics_bridge is GameplayBalanceDiagnosticsWorldBridge:
		(diagnostics_bridge as GameplayBalanceDiagnosticsWorldBridge).set_world_session_state(state)
	if infrastructure_bridge is RegionInfrastructureWorldBridge:
		(infrastructure_bridge as RegionInfrastructureWorldBridge).set_world_session_state(state)
	if resolution_bridge is CardResolutionExecutionWorldBridge:
		(resolution_bridge as CardResolutionExecutionWorldBridge).set_world_session_state(state)
	if economy_bridge is CardEconomyProductRouteEffectWorldBridge:
		(economy_bridge as CardEconomyProductRouteEffectWorldBridge).set_world_session_state(state)
	if card_market_bridge is CardMarketPolicyWorldBridge:
		(card_market_bridge as CardMarketPolicyWorldBridge).set_world_session_state(state)
	if derivative_bridge is CityGdpDerivativeRuntimeWorldBridge:
		(derivative_bridge as CityGdpDerivativeRuntimeWorldBridge).set_world_session_state(state)
	if route_bridge is RouteNetworkWorldBridge:
		(route_bridge as RouteNetworkWorldBridge).set_world_session_state(state)
	if flow_bridge is CommodityFlowWorldBridge:
		(flow_bridge as CommodityFlowWorldBridge).set_world_session_state(state)
	if victory_bridge is VictoryControlWorldBridge:
		(victory_bridge as VictoryControlWorldBridge).set_world_session_state(state)
	if bankruptcy_bridge is BankruptcyNeutralEstateWorldBridge:
		(bankruptcy_bridge as BankruptcyNeutralEstateWorldBridge).set_world_session_state(state)
	if card_player_state is CardPlayerStateProductionAdapterV06:
		(card_player_state as CardPlayerStateProductionAdapterV06).set_world_session_state(state)
	if card_inventory is CommodityCardInventoryRuntimeController:
		(card_inventory as CommodityCardInventoryRuntimeController).set_world_session_state(state)


func _wire_ai_world_typed_ports() -> void:
	var session_public_port := _ai_session_public_query_port_node()
	var actor_state_port := _ai_actor_state_port_node()
	var region_query_port := _ai_region_knowledge_query_port_node()
	var city_inference_port := _ai_city_inference_command_port_node()
	var market_public_port := _ai_market_public_query_port_node()
	var route_public_port := _ai_route_public_query_port_node()
	var card_queue_query_port := _ai_card_queue_query_port_node()
	var card_eligibility_query_port := _ai_card_eligibility_query_port_node()
	var monster_public_query_port := _ai_monster_public_query_port_node()
	var monster_actor_query_port := _ai_monster_actor_query_port_node()
	var military_public_query_port := _ai_military_public_query_port_node()
	var military_actor_query_port := _ai_military_actor_query_port_node()
	var weather_public_query_port := _ai_weather_public_query_port_node()
	var victory_public_query_port := _ai_victory_public_query_port_node()
	var actor_victory_query_port := _ai_actor_victory_query_port_node()
	var ai := _ai_runtime_controller_node() as AiRuntimeController
	if session_public_port == null or actor_state_port == null or region_query_port == null \
			or city_inference_port == null or market_public_port == null \
			or route_public_port == null or card_queue_query_port == null \
			or card_eligibility_query_port == null \
			or monster_public_query_port == null or monster_actor_query_port == null \
			or military_public_query_port == null or military_actor_query_port == null \
			or weather_public_query_port == null or victory_public_query_port == null \
			or actor_victory_query_port == null or ai == null:
		push_error("GameRuntimeCoordinator requires the AI session, actor, region, card, monster, military, weather, victory, and inference typed ports; AI world queries fail closed.")
		return
	if not actor_state_port.ai_capability_refresh_requested.is_connected(_refresh_ai_actor_state_capabilities):
		actor_state_port.ai_capability_refresh_requested.connect(_refresh_ai_actor_state_capabilities)
	var game_session := _session_node() as GameSessionRuntimeController
	if game_session != null and not game_session.session_identity_changed.is_connected(_on_ai_session_identity_changed):
		game_session.session_identity_changed.connect(_on_ai_session_identity_changed)
	ai.set_world_typed_ports(
		session_public_port,
		actor_state_port,
		{},
		region_query_port,
		{},
		city_inference_port
	)
	ai.set_market_route_query_ports(market_public_port, route_public_port)
	ai.set_monster_runtime_controller(_monster_runtime_controller_node() as MonsterRuntimeController)
	ai.set_role_catalog_runtime_service(_role_catalog_runtime_service_node() as RoleCatalogRuntimeService)
	ai.set_table_presentation_refresh_port(_table_presentation_refresh_port_node())
	ai.set_monster_military_query_ports(
		monster_public_query_port,
		monster_actor_query_port,
		{},
		military_public_query_port,
		military_actor_query_port,
		{}
	)
	ai.set_weather_victory_query_ports(
		weather_public_query_port,
		victory_public_query_port,
		actor_victory_query_port,
		{}
	)
	_refresh_ai_actor_state_capabilities()
	if (
		not session_public_port.is_ready()
		or not actor_state_port.is_ready()
		or not region_query_port.is_ready()
		or not city_inference_port.is_ready()
		or not weather_public_query_port.is_ready()
		or not victory_public_query_port.is_ready()
		or not actor_victory_query_port.is_ready()
	):
		push_error("AI typed world ports are missing authoritative runtime owners; AI world queries fail closed.")


func _on_ai_session_identity_changed() -> void:
	_refresh_ai_actor_state_capabilities()


func _refresh_ai_actor_state_capabilities() -> void:
	var actor_state_port := _ai_actor_state_port_node()
	var region_query := _ai_region_knowledge_query_port_node()
	var city_inference := _ai_city_inference_command_port_node()
	var card_hand_query := _ai_card_hand_query_port_node()
	var card_queue_query := _ai_card_queue_query_port_node()
	var card_eligibility_query := _ai_card_eligibility_query_port_node()
	var actor_economy_query := _ai_actor_economy_query_port_node()
	var monster_actor_query := _ai_monster_actor_query_port_node()
	var military_actor_query := _ai_military_actor_query_port_node()
	var actor_victory_query := _ai_actor_victory_query_port_node()
	var district_supply_query := district_supply_runtime_query_port()
	var ai := _ai_runtime_controller_node() as AiRuntimeController
	if actor_state_port == null or ai == null:
		return
	var actor_capabilities: Dictionary = {}
	for actor_index_variant in actor_state_port.ai_player_indices(true):
		var actor_index := int(actor_index_variant)
		actor_capabilities[actor_index] = AiActorStateCapability.new()
	var bound := actor_state_port.bind_ai_capabilities(actor_capabilities)
	ai.set_actor_state_capabilities(actor_capabilities if bound else {})
	if region_query != null and city_inference != null:
		var region_capabilities: Dictionary = {}
		for actor_index_variant in actor_state_port.ai_player_indices(true):
			var actor_index := int(actor_index_variant)
			region_capabilities[actor_index] = AiRegionKnowledgeCapability.new()
		var region_query_bound := region_query.bind_ai_capabilities(
			region_capabilities
		)
		var city_inference_bound := city_inference.bind_ai_capabilities(
			region_capabilities
		)
		ai.set_region_knowledge_capabilities(
			region_capabilities
			if region_query_bound and city_inference_bound
			else {}
		)
	if card_hand_query != null:
		var hand_capabilities: Dictionary = {}
		for actor_index_variant in actor_state_port.ai_player_indices(true):
			var actor_index := int(actor_index_variant)
			hand_capabilities[actor_index] = AiCardHandCapability.new()
		var hand_bound := card_hand_query.bind_ai_capabilities(hand_capabilities)
		ai.set_card_hand_query_port(card_hand_query, hand_capabilities if hand_bound else {})
	if card_queue_query != null:
		var queue_capabilities: Dictionary = {}
		for actor_index_variant in actor_state_port.ai_player_indices(true):
			var actor_index := int(actor_index_variant)
			queue_capabilities[actor_index] = AiCardQueueCapability.new()
		var queue_bound := card_queue_query.bind_ai_capabilities(queue_capabilities)
		ai.set_card_queue_query_port(
			card_queue_query,
			queue_capabilities if queue_bound else {}
		)
	if card_eligibility_query != null:
		var eligibility_capabilities: Dictionary = {}
		for actor_index_variant in actor_state_port.ai_player_indices(true):
			var actor_index := int(actor_index_variant)
			eligibility_capabilities[actor_index] = AiCardEligibilityCapability.new()
		var eligibility_bound := card_eligibility_query.bind_ai_capabilities(
			eligibility_capabilities
		)
		ai.set_card_eligibility_query_port(
			card_eligibility_query,
			eligibility_capabilities if eligibility_bound else {}
		)
	if actor_economy_query != null:
		var economy_capabilities: Dictionary = {}
		for actor_index_variant in actor_state_port.ai_player_indices(true):
			var actor_index := int(actor_index_variant)
			economy_capabilities[actor_index] = AiActorEconomyCapability.new()
		var economy_bound := actor_economy_query.bind_ai_capabilities(economy_capabilities)
		ai.set_actor_economy_query_port(
			actor_economy_query,
			economy_capabilities if economy_bound else {}
		)
	if monster_actor_query != null and military_actor_query != null:
		var monster_capabilities: Dictionary = {}
		var military_capabilities: Dictionary = {}
		for actor_index_variant in actor_state_port.ai_player_indices(true):
			var actor_index := int(actor_index_variant)
			monster_capabilities[actor_index] = AiMonsterActorCapability.new()
			military_capabilities[actor_index] = AiMilitaryActorCapability.new()
		var monster_bound := monster_actor_query.bind_ai_capabilities(monster_capabilities)
		var military_bound := military_actor_query.bind_ai_capabilities(military_capabilities)
		ai.set_monster_actor_capabilities(monster_capabilities if monster_bound else {})
		ai.set_military_actor_capabilities(military_capabilities if military_bound else {})
	if actor_victory_query != null:
		var victory_capabilities: Dictionary = {}
		for actor_index_variant in actor_state_port.ai_player_indices(true):
			var actor_index := int(actor_index_variant)
			victory_capabilities[actor_index] = AiActorVictoryCapability.new()
		var victory_bound := actor_victory_query.bind_ai_capabilities(victory_capabilities)
		ai.set_actor_victory_capabilities(victory_capabilities if victory_bound else {})
	if district_supply_query != null:
		var supply_capabilities: Dictionary = {}
		for actor_index_variant in actor_state_port.ai_player_indices(true):
			var actor_index := int(actor_index_variant)
			supply_capabilities[actor_index] = DistrictSupplyAiQueryCapability.new()
		var supply_bound := district_supply_query.bind_ai_private_capabilities(supply_capabilities)
		ai.set_district_supply_runtime_query_port(
			district_supply_query,
			supply_capabilities if supply_bound else {}
		)


func _wire_monster_wager_cash_commitment_query_port() -> void:
	var port := _monster_wager_cash_commitment_query_port_node()
	var state := _world_session_state_node()
	var monster := _monster_runtime_controller_node() as MonsterRuntimeController
	if port == null:
		push_error("GameRuntimeCoordinator requires MonsterWagerCashCommitmentQueryPort; cash spending is disabled by invalid production composition.")
		return
	port.configure(state, monster)
	var card_player_state := _card_player_state_production_adapter_v06_node()
	if card_player_state is CardPlayerStateProductionAdapterV06:
		(card_player_state as CardPlayerStateProductionAdapterV06).set_cash_commitment_query_port(port)
	var market_bridge := _product_market_runtime_world_bridge_node()
	if market_bridge is ProductMarketRuntimeWorldBridge:
		(market_bridge as ProductMarketRuntimeWorldBridge).set_cash_commitment_query_port(port)
	var derivative_bridge := _city_gdp_derivative_runtime_world_bridge_node()
	if derivative_bridge is CityGdpDerivativeRuntimeWorldBridge:
		(derivative_bridge as CityGdpDerivativeRuntimeWorldBridge).set_cash_commitment_query_port(port)
	var flow_bridge := _commodity_flow_world_bridge_node()
	if flow_bridge is CommodityFlowWorldBridge:
		(flow_bridge as CommodityFlowWorldBridge).set_cash_commitment_query_port(port)
	var hand_interaction := _player_hand_interaction_node()
	if hand_interaction is PlayerHandInteractionRuntimeService:
		(hand_interaction as PlayerHandInteractionRuntimeService).set_cash_commitment_query_port(port)
	var purchase_settlement := _purchase_settlement_node()
	if purchase_settlement is DistrictPurchaseSettlementRuntimeService:
		(purchase_settlement as DistrictPurchaseSettlementRuntimeService).set_cash_commitment_query_port(port)
	if not port.is_ready():
		push_error("MonsterWagerCashCommitmentQueryPort dependencies are unavailable; bound consumers will fail closed.")


func _wire_player_cash_mutation_port() -> void:
	var port := _player_cash_mutation_port_node()
	var state := _world_session_state_node()
	var commitment_query := _monster_wager_cash_commitment_query_port_node()
	var mutation_authority := _simulation_mutation_authority_node()
	if port == null:
		push_error("GameRuntimeCoordinator requires one PlayerCashMutationPort; product, GDP, and role cash mutations are disabled.")
		return
	port.configure(state, commitment_query, mutation_authority)
	var market_bridge := _product_market_runtime_world_bridge_node()
	if market_bridge is ProductMarketRuntimeWorldBridge:
		(market_bridge as ProductMarketRuntimeWorldBridge).set_cash_mutation_port(port)
	var derivative_bridge := _city_gdp_derivative_runtime_world_bridge_node()
	if derivative_bridge is CityGdpDerivativeRuntimeWorldBridge:
		(derivative_bridge as CityGdpDerivativeRuntimeWorldBridge).set_cash_mutation_port(port)
		(derivative_bridge as CityGdpDerivativeRuntimeWorldBridge).set_product_market_runtime_controller(_product_market_runtime_controller_node() as ProductMarketRuntimeController)
	var monster := _monster_runtime_controller_node() as MonsterRuntimeController
	if monster != null:
		monster.set_player_cash_mutation_port(port)
	if not port.is_ready():
		push_error("PlayerCashMutationPort dependencies are unavailable; bound cash consumers will fail closed.")


func _wire_ai_business_cost_cash_port() -> void:
	var port := _ai_business_cost_cash_port_node()
	var ai := _ai_runtime_controller_node() as AiRuntimeController
	if port == null or ai == null:
		push_error("GameRuntimeCoordinator requires one AiBusinessCostCashPort and AiRuntimeController; AI business spending is disabled.")
		return
	var capability := AiBusinessCostCapability.new()
	var configured := port.configure(
		_world_session_state_node(),
		_monster_wager_cash_commitment_query_port_node(),
		_player_cash_mutation_port_node(),
		_session_node() as GameSessionRuntimeController,
		_simulation_mutation_authority_node(),
		ai.policy_profile as AiPolicyProfileResource,
		_product_market_runtime_controller_node() as ProductMarketRuntimeController,
		capability
	)
	ai.set_ai_business_cost_cash_port(port, capability)
	if not bool(configured.get("configured", false)):
		push_error("AiBusinessCostCashPort dependencies are unavailable; AI business actions fail closed.")


func _wire_commodity_flow_postcommit() -> void:
	var flow := _commodity_flow_runtime_controller_node() as CommodityFlowRuntimeController
	var consumer := _commodity_flow_postcommit_consumer_node()
	if flow == null:
		push_error("GameRuntimeCoordinator requires CommodityFlowRuntimeController for post-commit settlement.")
		return
	var configured := {"configured": false, "reason_code": "commodity_postcommit_consumer_missing"}
	if consumer != null:
		var presentation_ports := _table_presentation_query_ports_node()
		configured = consumer.configure(
			flow,
			_world_session_state_node(),
			_city_gdp_derivative_runtime_controller_node() as CityGdpDerivativeRuntimeController,
			_visual_cue_runtime_owner_node(),
			_bankruptcy_neutral_estate_runtime_controller_node() as BankruptcyNeutralEstateRuntimeController,
			_player_mana_runtime_controller_node() as PlayerManaRuntimeController,
			presentation_ports.public_log_port if presentation_ports != null else null,
			_table_presentation_refresh_scheduler_node()
		)
	flow.set_postcommit_consumer(consumer)
	if not bool(configured.get("configured", false)):
		push_error("CommodityFlow post-commit consumer dependencies are unavailable; flow settlement fails closed.")


func _wire_card_execution_typed_ports() -> void:
	var world_state := _world_session_state_node()
	var selection := _table_selection_state_node()
	var queue := _card_resolution_queue_node() as CardResolutionQueueRuntimeService
	var resolution := _card_resolution_runtime_controller_node()
	var target_choice := _card_target_choice_runtime_controller_node()
	var eligibility_facts := _card_play_world_bridge_node() as CardPlayEligibilityWorldBridge
	var eligibility := _card_play_eligibility_node() as CardPlayEligibilityRuntimeService
	var monster := _monster_runtime_controller_node() as MonsterRuntimeController
	var military := _military_runtime_controller_node() as MilitaryRuntimeController
	var weather := _weather_runtime_controller_node() as WeatherRuntimeController
	var session := _session_node() as GameSessionRuntimeController
	var scheduler := _scheduler_node() as ForcedDecisionRuntimeScheduler
	var commodity_flow := _commodity_flow_runtime_controller_node() as CommodityFlowRuntimeController
	var history := _card_resolution_history_runtime_service_node()
	var history_query := _card_history_public_query_port_node() as CardHistoryPublicQueryPort
	var history_annotations := _card_history_private_annotation_service_node() as CardHistoryPrivateAnnotationService
	var presentation := _card_resolution_presentation_port_node()
	var intel := _card_intel_runtime_service_node()
	var commitment := _card_commitment_runtime_service_node()
	var counter := _card_counter_settlement_runtime_service_node()
	var effect_router := _card_effect_runtime_router_node()
	var submission := _card_play_submission_runtime_controller_node()
	var selection_catalog := get_node_or_null("TableSelectionCatalogQueryPort") as TableSelectionCatalogQueryPort
	var execution := _card_resolution_execution_node() as CardResolutionExecutionRuntimeService
	var economy_port := _card_economy_product_route_effect_world_bridge_node() as CardEconomyProductRouteEffectWorldBridge
	var cash_commitment_query := _monster_wager_cash_commitment_query_port_node()
	if eligibility_facts != null:
		eligibility_facts.set_runtime_dependencies(queue, resolution, target_choice, monster, military, session, scheduler, commodity_flow, cash_commitment_query)
		eligibility_facts.set_facility_target_preflight_port(_core_economic_card_runtime_adapter_v06_node() as CoreEconomicCardRuntimeAdapterV06)
	if history_query != null:
		history_query.configure(history)
	if history_annotations != null:
		history_annotations.configure(history_query)
	if intel != null:
		intel.set_dependencies(world_state, history_query, history_annotations)
	if commitment != null:
		commitment.set_dependencies(world_state, _card_cooldown_runtime_controller_node(), _weather_telemetry_runtime_service_node() as WeatherTelemetryRuntimeService, eligibility_facts, eligibility, cash_commitment_query)
	if effect_router != null:
		effect_router.set_dependencies(
			world_state, selection, monster, military, weather,
			_player_hand_interaction_node() as PlayerHandInteractionRuntimeService,
			_card_economy_product_route_effect_node() as CardEconomyProductRouteEffectRuntimeService,
			economy_port, intel, presentation, self
		)
	var diagnostics_bridge := _gameplay_balance_diagnostics_world_bridge_node() as GameplayBalanceDiagnosticsWorldBridge
	if diagnostics_bridge != null:
		diagnostics_bridge.set_card_effect_router(effect_router)
	if counter != null:
		counter.set_dependencies(queue, eligibility_facts, eligibility, commitment, history, presentation, self, world_state)
	var execution_port := _card_resolution_execution_world_bridge_node() as CardResolutionExecutionWorldBridge
	if execution_port != null:
		execution_port.set_runtime_dependencies(queue, resolution, eligibility_facts, eligibility, counter, commitment, history, presentation, effect_router, self)
	if execution != null:
		execution.set_transition_checkpoint_owner(resolution)
	if submission != null:
		submission.set_dependencies(
			world_state, selection, eligibility_facts, eligibility, queue, resolution,
			target_choice,
			_product_market_runtime_controller_node() as ProductMarketRuntimeController,
			_city_gdp_derivative_runtime_controller_node() as CityGdpDerivativeRuntimeController,
			selection_catalog,
			self,
			cash_commitment_query
		)
	var ai := _ai_runtime_controller_node() as AiRuntimeController
	if ai != null:
		ai.set_card_execution_dependencies(submission, history)


func solar_public_presentation_snapshot() -> Dictionary:
	var clock_snapshot := world_effective_clock_snapshot()
	var solar := _solar_availability_runtime_service_node()
	if solar == null or not solar.has_method("public_presentation_snapshot") or not (clock_snapshot.get("world_effective_us") is int):
		return {}
	var value: Variant = solar.call("public_presentation_snapshot", int(clock_snapshot.get("world_effective_us", -1)))
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func card_market_quote(request: Dictionary) -> Dictionary:
	var controller := _card_market_pricing_runtime_controller_node()
	var value: Variant = controller.call("quote_listing", request) if controller != null and controller.has_method("quote_listing") else {}
	var quote: Dictionary = (value as Dictionary).duplicate(true) if value is Dictionary else {}
	if not str(quote.get("quote_id", "")).is_empty():
		var purchase := _purchase_node()
		if purchase != null and purchase.has_method("attach_quote"):
			purchase.call("attach_quote", int(request.get("player_index", -1)), int(request.get("district_index", -1)), quote)
	return quote


func card_market_preview(request: Dictionary) -> Dictionary:
	var controller := _card_market_pricing_runtime_controller_node()
	var value: Variant = controller.call("preview_listing", request) if controller != null and controller.has_method("preview_listing") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func card_market_listing_availability(source_district_index: int) -> Dictionary:
	var controller := _card_market_pricing_runtime_controller_node()
	var value: Variant = controller.call("listing_availability", source_district_index) if controller != null and controller.has_method("listing_availability") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func authorize_card_market_purchase(request: Dictionary) -> Dictionary:
	var controller := _card_market_pricing_runtime_controller_node()
	var value: Variant = controller.call("authorize_purchase", request) if controller != null and controller.has_method("authorize_purchase") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {"authorized": false, "reason": "card_market_unavailable"}


func card_market_active_quote(player_index: int, district_index: int) -> Dictionary:
	var purchase := _purchase_node()
	var value: Variant = purchase.call("active_quote", player_index, district_index) if purchase != null and purchase.has_method("active_quote") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func reset_runtime_session() -> void:
	var session := _session_node()
	if session != null and session.has_method("reset_state"):
		session.call("reset_state")


func _apply_victory_outcome_receipt(receipt: Dictionary) -> void:
	if receipt.is_empty():
		return
	var session := _session_node() as GameSessionRuntimeController
	if session == null or session.is_finished():
		return
	_drain_ai_business_publications_before_session_finish()
	session.finish_session(receipt)
	if not session.is_finished():
		return
	var ai_runtime := _ai_runtime_controller_node() as AiRuntimeController
	if ai_runtime != null:
		ai_runtime.finalize_victory_outcome_learning(receipt)
	var ports := _table_presentation_query_ports_node()
	if ports != null:
		ports.capture_victory_outcome(victory_control_public_snapshot(-1))


func card_runtime_catalog_service() -> CardRuntimeCatalogService:
	return _card_runtime_catalog_node() as CardRuntimeCatalogService


func role_catalog_runtime_service() -> RoleCatalogRuntimeService:
	return _role_catalog_runtime_service_node() as RoleCatalogRuntimeService


func card_runtime_definition_bridge() -> CardRuntimeDefinitionWorldBridge:
	return _card_runtime_definition_bridge_node() as CardRuntimeDefinitionWorldBridge


func gameplay_balance_diagnostics_service() -> GameplayBalanceDiagnosticsRuntimeService:
	return _gameplay_balance_diagnostics_node() as GameplayBalanceDiagnosticsRuntimeService


func gameplay_balance_diagnostics_world_snapshot(sample_only := false) -> Dictionary:
	var bridge := _gameplay_balance_diagnostics_world_bridge_node()
	var value: Variant = bridge.call("build_world_snapshot", sample_only) if bridge != null else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func gameplay_balance_diagnostics_call(method_name: StringName, arguments: Array = []) -> Variant:
	var service := _gameplay_balance_diagnostics_node()
	if service == null or not service.has_method(method_name):
		push_error("GameplayBalanceDiagnosticsRuntimeService method unavailable: %s" % method_name)
		return null
	return service.callv(method_name, arguments)


func build_gameplay_balance_report(world_snapshot: Dictionary = {}) -> Dictionary:
	var value: Variant = gameplay_balance_diagnostics_call("build_balance_report", [world_snapshot])
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func build_developer_balance_panel_snapshot(world_snapshot: Dictionary = {}, sample_only := true) -> Dictionary:
	var value: Variant = gameplay_balance_diagnostics_call("build_developer_panel_snapshot", [world_snapshot, sample_only])
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func card_exists(card_id: String) -> bool:
	var bridge := _card_runtime_definition_bridge_node()
	return bool(bridge.call("has_runtime_card", card_id)) if bridge != null else false


func card_definition(card_id: String) -> Dictionary:
	var bridge := _card_runtime_definition_bridge_node()
	var value: Variant = bridge.call("resolve_definition", card_id) if bridge != null else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func card_exact_catalog_definition(card_id: String) -> Dictionary:
	var service := _card_runtime_catalog_node()
	var value: Variant = service.call("exact_definition", card_id) if service != null else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func card_authored_catalog_definition(card_id: String) -> Dictionary:
	var service := _card_runtime_catalog_node()
	var value: Variant = service.call("authored_definition", card_id) if service != null else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func card_rank(card_id: String) -> int:
	var service := _card_runtime_catalog_node()
	return int(service.call("rank", card_id)) if service != null else 0


func card_family_id(card_id: String) -> String:
	var service := _card_runtime_catalog_node()
	return str(service.call("family_id", card_id)) if service != null else ""


func card_catalog_ordered_ids() -> Array:
	var service := _card_runtime_catalog_node()
	var value: Variant = service.call("ordered_card_ids") if service != null else []
	return (value as Array).duplicate(true) if value is Array else []


func card_catalog_public_pool() -> Array:
	var service := _card_runtime_catalog_node()
	var value: Variant = service.call("public_pool") if service != null else []
	return (value as Array).duplicate(true) if value is Array else []


func card_catalog_upgradeable_families() -> Array:
	var service := _card_runtime_catalog_node()
	var value: Variant = service.call("upgradeable_families") if service != null else []
	return (value as Array).duplicate(true) if value is Array else []


func region_supply_runtime_controller() -> RegionSupplyRuntimeController:
	return _region_supply_runtime_controller_node() as RegionSupplyRuntimeController


func region_supply_runtime_call(method_name: StringName, arguments: Array = []) -> Variant:
	var controller := _region_supply_runtime_controller_node()
	if controller == null or not controller.has_method(method_name):
		push_error("RegionSupplyRuntimeController method unavailable: %s" % method_name)
		return null
	return controller.callv(method_name, arguments)


func configure_region_supply(
	gameplay_seed: int,
	region_descriptors: Array,
	legal_card_descriptors: Array,
	slots_per_region := 4
) -> Dictionary:
	var value: Variant = region_supply_runtime_call(
		"configure",
		[gameplay_seed, region_descriptors, legal_card_descriptors, slots_per_region]
	)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func region_supply_catalog_card_ids() -> Array:
	var catalog := _v06_runtime_card_catalog() as CardRuntimeCatalogV06Resource
	var content := AlphaContentLoader.load_active_selection()
	if catalog == null or not content.is_valid():
		return []
	var result: Array = []
	for card_id_variant in content.region_supply_card_ids:
		var card_id := str(card_id_variant).strip_edges()
		if not _region_supply_card_descriptor(card_id).is_empty():
			result.append(card_id)
	return result


func configure_region_supply_from_world(
	gameplay_seed: int,
	district_rows: Array,
	card_ids: Array,
	slots_per_region := 4
) -> Dictionary:
	var region_descriptors: Array = []
	for district_index in range(district_rows.size()):
		if not (district_rows[district_index] is Dictionary):
			continue
		var district: Dictionary = district_rows[district_index]
		region_descriptors.append({
			"region_id": str(district.get("region_id", "region.%03d" % district_index)),
			"region_index": district_index,
			"display_name": str(district.get("name", "区域%d" % (district_index + 1))),
			"terrain": str(district.get("terrain", "")),
			"active": not bool(district.get("destroyed", false)),
			"destroyed": bool(district.get("destroyed", false)),
			"mode_tags": (district.get("mode_tags", []) as Array).duplicate()
				if district.get("mode_tags", []) is Array
				else [],
		})
	var card_descriptors: Array = []
	for card_id_variant in card_ids:
		var card_id := str(card_id_variant).strip_edges()
		var descriptor := _region_supply_card_descriptor(card_id)
		if not descriptor.is_empty():
			card_descriptors.append(descriptor)
	return configure_region_supply(gameplay_seed, region_descriptors, card_descriptors, slots_per_region)


func region_supply_public_rack(region_id := "") -> Dictionary:
	var value: Variant = region_supply_runtime_call("public_rack_snapshot", [region_id])
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func region_supply_listing(region_id: String, card_id := "") -> Dictionary:
	var snapshot := region_supply_public_rack(region_id)
	var regions: Array = snapshot.get("regions", []) if snapshot.get("regions", []) is Array else []
	if regions.is_empty() or not (regions[0] is Dictionary):
		return {}
	var slots: Array = (regions[0] as Dictionary).get("slots", []) if (regions[0] as Dictionary).get("slots", []) is Array else []
	for listing_variant in slots:
		if not (listing_variant is Dictionary):
			continue
		var listing: Dictionary = listing_variant
		if card_id.is_empty() or str(listing.get("card_id", "")) == card_id:
			return listing.duplicate(true)
	return {}


func region_supply_card_ids(region_id: String) -> Array:
	var result: Array = []
	var snapshot := region_supply_public_rack(region_id)
	var regions: Array = snapshot.get("regions", []) if snapshot.get("regions", []) is Array else []
	if regions.is_empty() or not (regions[0] is Dictionary):
		return result
	var slots: Array = (regions[0] as Dictionary).get("slots", []) if (regions[0] as Dictionary).get("slots", []) is Array else []
	for listing_variant in slots:
		if not (listing_variant is Dictionary):
			continue
		var card_id := str((listing_variant as Dictionary).get("card_id", ""))
		if not card_id.is_empty():
			result.append(card_id)
	return result


func region_supply_rack_revision(region_id: String) -> String:
	var snapshot := region_supply_public_rack(region_id)
	var regions: Array = snapshot.get("regions", []) if snapshot.get("regions", []) is Array else []
	return str((regions[0] as Dictionary).get("rack_revision", "")) \
		if not regions.is_empty() and regions[0] is Dictionary \
		else ""


func prepare_region_supply_slot_refill(
	transaction_id: String,
	region_id: String,
	slot_index: int,
	expected_item_id: String,
	expected_supply_revision: String
) -> Dictionary:
	var value: Variant = region_supply_runtime_call(
		"prepare_slot_refill",
		[region_id, slot_index, expected_item_id, expected_supply_revision, transaction_id]
	)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func commit_region_supply_slot_refill(transaction_id: String) -> Dictionary:
	var value: Variant = region_supply_runtime_call("commit_slot_refill", [transaction_id])
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func rollback_region_supply_slot_refill(transaction_id: String) -> Dictionary:
	var value: Variant = region_supply_runtime_call("rollback_slot_refill", [transaction_id])
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func finalize_region_supply_slot_refill(transaction_id: String) -> Dictionary:
	var value: Variant = region_supply_runtime_call("finalize_slot_refill", [transaction_id])
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


## Thin production facade. RegionSupply remains the sole rack/bag/RNG owner and
## CommodityCardInventory/CardFlow remains the sole purchase transaction owner.
func purchase_region_supply_card(request: Dictionary) -> Dictionary:
	var inventory := _commodity_card_inventory_runtime_controller_node()
	if inventory == null or not inventory.has_method("purchase_region_supply_card"):
		return {
			"committed": false,
			"reason_code": "region_supply_purchase_inventory_unavailable",
		}
	var quote_request: Dictionary = (
		(request.get("quote_request", {}) as Dictionary).duplicate(true)
		if request.get("quote_request", {}) is Dictionary
		else {}
	)
	var value_variant: Variant = inventory.call(
		"purchase_region_supply_card",
		str(request.get("actor_id", "")).strip_edges(),
		str(request.get("region_id", "")).strip_edges(),
		int(request.get("slot_index", -1)),
		str(request.get("item_id", "")).strip_edges(),
		str(request.get("card_id", "")).strip_edges(),
		int(request.get("player_revision", -1)),
		str(request.get("supply_revision", "")).strip_edges(),
		str(request.get("transaction_id", "")).strip_edges(),
		quote_request,
		int(request.get("discard_slot", -1))
	)
	return (
		(value_variant as Dictionary).duplicate(true)
		if value_variant is Dictionary
		else {
			"committed": false,
			"reason_code": "region_supply_purchase_result_invalid",
		}
	)


func monster_runtime_controller() -> MonsterRuntimeController:
	return _monster_runtime_controller_node() as MonsterRuntimeController


func region_infrastructure_runtime_controller() -> Node:
	return _region_infrastructure_runtime_controller_node()


func region_infrastructure_world_bridge() -> Node:
	return _region_infrastructure_world_bridge_node()


func submit_public_facility_card(request: Dictionary) -> Dictionary:
	# The legacy queue entry cannot prove a v0.6 runtime instance, authoritative
	# slot, or CardFlow binding. It must never mutate RegionInfrastructure beside
	# the formal submission owner.
	var skill: Dictionary = (request.get("skill", {}) as Dictionary).duplicate(true) if request.get("skill", {}) is Dictionary else {}
	if str(skill.get("kind", "")) != "public_facility":
		return {"committed": false, "reason": "legacy_city_development_retired"}
	return {"committed": false, "reason": "legacy_public_facility_entry_retired"}


func military_runtime_controller() -> MilitaryRuntimeController:
	return _military_runtime_controller_node() as MilitaryRuntimeController


func weather_runtime_controller() -> WeatherRuntimeController:
	return _weather_runtime_controller_node() as WeatherRuntimeController


func product_market_runtime_controller() -> ProductMarketRuntimeController:
	return _product_market_runtime_controller_node() as ProductMarketRuntimeController


func product_market_runtime_call(method_name: StringName, arguments: Array = []) -> Variant:
	var controller := _product_market_runtime_controller_node()
	if controller == null or not controller.has_method(method_name):
		push_error("ProductMarketRuntimeController method unavailable: %s" % method_name)
		return null
	return controller.callv(method_name, arguments)


func product_market_to_save_data() -> Dictionary:
	var value: Variant = product_market_runtime_call("to_save_data")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func apply_product_market_save_data(data: Dictionary) -> Dictionary:
	var value: Variant = product_market_runtime_call("apply_save_data", [data])
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func reset_product_market_runtime() -> Dictionary:
	var value: Variant = product_market_runtime_call("reset_state")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func tick_product_market_cycle(delta: float) -> Dictionary:
	var ports := _runtime_world_ports_node()
	return _runtime_economy_port_node().tick_product_market_cycle(delta) if ports != null and _runtime_economy_port_node() != null else {
		"advanced": false,
		"reason": "runtime_economy_port_unavailable",
	}


func advance_product_futures_timers() -> void:
	var ports := _runtime_world_ports_node()
	if ports != null and _runtime_economy_port_node() != null:
		_runtime_economy_port_node().advance_product_futures_timers()


func advance_economic_boons(delta_seconds: float) -> void:
	var ports := _runtime_world_ports_node()
	if ports != null and _runtime_economy_port_node() != null:
		_runtime_economy_port_node().advance_economic_boons(delta_seconds)


func city_gdp_derivative_runtime_controller() -> CityGdpDerivativeRuntimeController:
	return _city_gdp_derivative_runtime_controller_node() as CityGdpDerivativeRuntimeController


func city_gdp_derivative_runtime_call(method_name: StringName, arguments: Array = []) -> Variant:
	var controller := _city_gdp_derivative_runtime_controller_node()
	if controller == null or not controller.has_method(method_name):
		push_error("CityGdpDerivativeRuntimeController method unavailable: %s" % method_name)
		return null
	return controller.callv(method_name, arguments)


func city_gdp_derivative_to_save_data() -> Dictionary:
	var value: Variant = city_gdp_derivative_runtime_call("to_save_data")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func apply_city_gdp_derivative_save_data(data: Dictionary, legacy_positions_by_district: Dictionary = {}) -> Dictionary:
	var value: Variant = city_gdp_derivative_runtime_call("apply_save_data", [data, legacy_positions_by_district])
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func reset_city_gdp_derivative_runtime() -> Dictionary:
	var value: Variant = city_gdp_derivative_runtime_call("reset_state")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func advance_city_gdp_derivative_timers() -> Dictionary:
	var ports := _runtime_world_ports_node()
	return _runtime_economy_port_node().advance_city_gdp_derivative_timers() if ports != null and _runtime_economy_port_node() != null else {
		"updated": false,
		"reason": "runtime_economy_port_unavailable",
	}


func route_network_runtime_controller() -> RouteNetworkRuntimeController:
	return _route_network_runtime_controller_node() as RouteNetworkRuntimeController


func route_network_world_bridge() -> RouteNetworkWorldBridge:
	return _route_network_world_bridge_node() as RouteNetworkWorldBridge


func route_network_runtime_call(method_name: StringName, arguments: Array = []) -> Variant:
	var controller := _route_network_runtime_controller_node()
	if controller == null or not controller.has_method(method_name):
		push_error("RouteNetworkRuntimeController method unavailable: %s" % method_name)
		return null
	return controller.callv(method_name, arguments)


func route_network_to_save_data() -> Dictionary:
	var value: Variant = route_network_runtime_call("to_save_data")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func apply_route_network_save_data(data: Dictionary) -> Dictionary:
	var value: Variant = route_network_runtime_call("apply_save_data", [data])
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func refresh_route_network(force := false) -> Dictionary:
	var value: Variant = route_network_runtime_call("refresh_routes", [force])
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func commodity_flow_runtime_controller() -> CommodityFlowRuntimeController:
	return _commodity_flow_runtime_controller_node() as CommodityFlowRuntimeController


func commodity_flow_world_bridge() -> CommodityFlowWorldBridge:
	return _commodity_flow_world_bridge_node() as CommodityFlowWorldBridge


func commodity_flow_runtime_call(method_name: StringName, arguments: Array = []) -> Variant:
	var controller := _commodity_flow_runtime_controller_node()
	if controller == null or not controller.has_method(method_name):
		push_error("CommodityFlowRuntimeController method unavailable: %s" % method_name)
		return null
	return controller.callv(method_name, arguments)


func commodity_card_inventory_runtime_controller() -> CommodityCardInventoryRuntimeController:
	return _commodity_card_inventory_runtime_controller_node() as CommodityCardInventoryRuntimeController


func card_player_state_production_adapter_v06() -> CardPlayerStateProductionAdapterV06:
	return _card_player_state_production_adapter_v06_node() as CardPlayerStateProductionAdapterV06


func core_economic_card_runtime_adapter_v06() -> CoreEconomicCardRuntimeAdapterV06:
	return _core_economic_card_runtime_adapter_v06_node() as CoreEconomicCardRuntimeAdapterV06


func v06_card_definition(card_id: String) -> Dictionary:
	var catalog := _v06_runtime_card_catalog()
	if catalog == null or not catalog.has_method("card_snapshot"):
		return {}
	var value_variant: Variant = catalog.call("card_snapshot", card_id.strip_edges())
	return (value_variant as Dictionary).duplicate(true) if value_variant is Dictionary else {}


func v06_starter_monster_card_by_name(monster_name: String) -> Dictionary:
	var catalog := _v06_runtime_card_catalog()
	if catalog == null or not catalog.has_method("card_ids"):
		return {}
	var card_ids_variant: Variant = catalog.call("card_ids")
	var card_ids: Array = card_ids_variant if card_ids_variant is Array else []
	for card_id_variant in card_ids:
		var card := v06_card_definition(str(card_id_variant))
		var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
		var player_text: Dictionary = card.get("player", {}) if card.get("player", {}) is Dictionary else {}
		if str(machine.get("category_id", "")) == "monster" \
			and int(machine.get("rank", 0)) == 1 \
			and str(player_text.get("name", "")) == monster_name:
			return card
	return {}


func v06_card_player_snapshot(actor_id: String) -> Dictionary:
	var inventory := _commodity_card_inventory_runtime_controller_node()
	if inventory == null or not inventory.has_method("player_snapshot"):
		return {}
	var value_variant: Variant = inventory.call("player_snapshot", actor_id.strip_edges())
	return (value_variant as Dictionary).duplicate(true) if value_variant is Dictionary else {}


func actor_id_for_player_index(player_index: int) -> Dictionary:
	var adapter := _card_player_state_production_adapter_v06_node()
	if player_index < 0 or adapter == null or not adapter.has_method("actor_player_indices"):
		return _ai_v06_economy_failure("ai_v06_actor_mapping_unavailable")
	var actor_map_variant: Variant = adapter.call("actor_player_indices")
	var actor_map: Dictionary = actor_map_variant if actor_map_variant is Dictionary else {}
	var matching_actor_ids: Array[String] = []
	for actor_id_variant in actor_map.keys():
		var actor_id := str(actor_id_variant).strip_edges()
		if not actor_id.is_empty() and int(actor_map.get(actor_id_variant, -1)) == player_index:
			matching_actor_ids.append(actor_id)
	matching_actor_ids.sort()
	var revision := _ai_v06_binding_revision(actor_map)
	if matching_actor_ids.size() != 1:
		return _ai_v06_economy_failure(
			"ai_v06_actor_mapping_missing" if matching_actor_ids.is_empty() else "ai_v06_actor_mapping_ambiguous",
			revision
		)
	return {
		"available": true,
		"revision": revision,
		"reason_code": "ai_v06_actor_mapping_ready",
		"actor_id": matching_actor_ids[0],
	}


func play_runtime_card(request: Dictionary) -> Dictionary:
	var actor_id := str(request.get("actor_id", "")).strip_edges()
	var transaction_id := str(request.get("transaction_id", "")).strip_edges()
	var slot_index := int(request.get("slot_index", -1))
	var runtime_instance_id := str(request.get("runtime_instance_id", "")).strip_edges()
	var region_id := str(request.get("region_id", "")).strip_edges()
	if actor_id.is_empty() or transaction_id.is_empty() or slot_index < 0 or runtime_instance_id.is_empty() or region_id.is_empty():
		return _ai_v06_economy_failure("ai_v06_facility_play_request_invalid")
	var terminal := _ai_v06_inventory_transaction_result(transaction_id)
	if not terminal.is_empty():
		if str(terminal.get("operation", "")) != "play_card" or str(terminal.get("actor_id", "")) != actor_id:
			return _ai_v06_economy_failure("ai_v06_facility_play_transaction_collision")
		var replay_variant: Variant = play_v06_runtime_card(request.duplicate(true))
		var replay: Dictionary = (replay_variant as Dictionary).duplicate(true) if replay_variant is Dictionary else {}
		return _ai_v06_owner_result(replay, actor_id)
	var source := economic_source_snapshot(actor_id)
	if not bool(source.get("available", false)) or int(source.get("revision", -1)) != int(request.get("expected_source_revision", -2)):
		return _ai_v06_economy_failure("ai_v06_economic_source_revision_stale", maxi(0, int(source.get("revision", 0))))
	var authoritative_player := v06_card_player_snapshot(actor_id)
	if authoritative_player.is_empty() or int(authoritative_player.get("revision", -1)) != int(request.get("expected_player_revision", -2)):
		return _ai_v06_economy_failure("ai_v06_facility_player_revision_stale", maxi(0, int(authoritative_player.get("revision", 0))))
	var card := _v06_player_card_at(authoritative_player, slot_index)
	if not _ai_v06_is_rank_i_facility_card(card) or str(card.get("runtime_instance_id", "")) != runtime_instance_id:
		return _ai_v06_economy_failure("ai_v06_facility_card_binding_changed", int(authoritative_player.get("revision", 0)))
	var legal_region_ids := _ai_v06_legal_facility_region_ids(card, actor_id)
	if not legal_region_ids.has(region_id):
		return _ai_v06_economy_failure("ai_v06_facility_authoritative_target_unavailable", int(source.get("revision", 0)))
	var value_variant: Variant = play_v06_runtime_card(request.duplicate(true))
	var result: Dictionary = (value_variant as Dictionary).duplicate(true) if value_variant is Dictionary else {}
	return _ai_v06_owner_result(result, actor_id)


func economic_source_snapshot(actor_id: String) -> Dictionary:
	var normalized_actor_id := actor_id.strip_edges()
	var player_index := _ai_v06_actor_player_index(normalized_actor_id)
	var infrastructure := _region_infrastructure_runtime_controller_node()
	var flow := _commodity_flow_runtime_controller_node()
	var inventory := _commodity_card_inventory_runtime_controller_node()
	if normalized_actor_id.is_empty() or player_index < 0 or infrastructure == null or flow == null or inventory == null \
			or not infrastructure.has_method("facilities_snapshot") or not flow.has_method("installations_snapshot") \
			or not inventory.has_method("transaction_journal_snapshot"):
		return _ai_v06_economy_failure("ai_v06_economic_source_unavailable")
	var owned_facility_ids: Array[String] = []
	for facility_variant in infrastructure.call("facilities_snapshot", false):
		if not (facility_variant is Dictionary):
			continue
		var facility: Dictionary = facility_variant
		if bool(facility.get("active", false)) and str(facility.get("owner_kind", "")) == "player" \
				and int(facility.get("owner_player_index", -1)) == player_index:
			owned_facility_ids.append(str(facility.get("facility_id", "")))
	owned_facility_ids.sort()
	var production_installation_ids: Array[String] = []
	for installation_variant in flow.call("installations_snapshot", false):
		if not (installation_variant is Dictionary):
			continue
		var installation: Dictionary = installation_variant
		if bool(installation.get("active", false)) and str(installation.get("direction", "")) == "production" \
				and str(installation.get("owner_kind", "")) == "player" \
				and int(installation.get("installer_player_index", -1)) == player_index:
			production_installation_ids.append(str(installation.get("installation_id", "")))
	production_installation_ids.sort()
	var finalized_transaction_ids: Array[String] = []
	var journal_variant: Variant = inventory.call("transaction_journal_snapshot")
	var journal: Dictionary = journal_variant if journal_variant is Dictionary else {}
	for transaction_id_variant in journal.keys():
		var record_variant: Variant = journal.get(transaction_id_variant)
		if not (record_variant is Dictionary):
			continue
		var result_variant: Variant = (record_variant as Dictionary).get("result", {})
		if not (result_variant is Dictionary):
			continue
		var result: Dictionary = result_variant
		var finalization: Dictionary = result.get("effect_finalization", {}) if result.get("effect_finalization", {}) is Dictionary else {}
		if str(result.get("operation", "")) == "play_card" and str(result.get("actor_id", "")) == normalized_actor_id \
				and str(result.get("effect_kind", "")) == "build_upgrade_or_repair_facility" \
				and bool(result.get("committed", false)) and bool(result.get("finalized", finalization.get("finalized", false))):
			finalized_transaction_ids.append(str(transaction_id_variant))
	finalized_transaction_ids.sort()
	var source_card := _ai_v06_current_facility_card(normalized_actor_id)
	var legal_region_ids: Array[String] = []
	if not source_card.is_empty():
		legal_region_ids = _ai_v06_legal_facility_region_ids(source_card, normalized_actor_id)
	var infrastructure_debug := _region_infrastructure_runtime_debug_snapshot()
	var flow_debug := _commodity_flow_runtime_debug_snapshot()
	var revision := _ai_v06_binding_revision({
		"infrastructure_revision": int(infrastructure_debug.get("revision", 0)),
		"flow_revision": int(flow_debug.get("flow_revision", 0)),
		"owned_facility_ids": owned_facility_ids,
		"production_installation_ids": production_installation_ids,
		"finalized_transaction_ids": finalized_transaction_ids,
		"legal_region_ids": legal_region_ids,
	})
	return {
		"available": true,
		"revision": revision,
		"reason_code": "ai_v06_economic_source_ready",
		"has_source": not owned_facility_ids.is_empty() or not production_installation_ids.is_empty(),
		"bootstrap_finalized": not finalized_transaction_ids.is_empty(),
		"owned_facility_count": owned_facility_ids.size(),
		"production_installation_count": production_installation_ids.size(),
		"legal_region_count": legal_region_ids.size(),
		"expansion_available": not legal_region_ids.is_empty(),
		"lineage_transaction_id": finalized_transaction_ids.back() if not finalized_transaction_ids.is_empty() else "",
		"target_region_id": str(legal_region_ids[0]) if not legal_region_ids.is_empty() else "",
		"legal_region_ids": legal_region_ids.duplicate(),
	}


func _ai_v06_economy_failure(reason_code: String, revision := 0) -> Dictionary:
	return {
		"available": false,
		"revision": maxi(0, int(revision)),
		"reason_code": reason_code,
	}


func _ai_v06_owner_result(result: Dictionary, actor_id: String) -> Dictionary:
	var current_player := v06_card_player_snapshot(actor_id)
	var finalization: Dictionary = result.get("effect_finalization", {}) if result.get("effect_finalization", {}) is Dictionary else {}
	var normalized := {
		"available": not result.is_empty(),
		"revision": maxi(0, int(current_player.get("revision", 0))),
		"reason_code": str(result.get("reason_code", "ai_v06_production_owner_result_invalid")),
		"committed": bool(result.get("committed", false)),
		"finalized": bool(result.get("finalized", finalization.get("finalized", false))),
		"idempotent_replay": bool(result.get("idempotent_replay", false)),
	}
	if not finalization.is_empty():
		normalized["effect_finalization"] = finalization.duplicate(true)
	return normalized


func _ai_v06_actor_player_index(actor_id: String) -> int:
	var adapter := _card_player_state_production_adapter_v06_node()
	if adapter == null or not adapter.has_method("actor_player_indices"):
		return -1
	var actor_map_variant: Variant = adapter.call("actor_player_indices")
	var actor_map: Dictionary = actor_map_variant if actor_map_variant is Dictionary else {}
	return int(actor_map.get(actor_id, -1))


func _ai_v06_is_rank_i_facility_card(card: Dictionary) -> bool:
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	return str(machine.get("category_id", "")) == "facility" \
		and int(machine.get("rank", 0)) == 1 \
		and str(machine.get("effect_kind", "")) == "build_upgrade_or_repair_facility"


func _v06_is_facility_card(card: Dictionary) -> bool:
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	return str(machine.get("category_id", "")) == "facility" \
		and str(machine.get("effect_kind", "")) == "build_upgrade_or_repair_facility" \
		and str(machine.get("target_kind", "")) == "region_unique_facility_slot"


func _ai_v06_current_facility_card(actor_id: String) -> Dictionary:
	var player := v06_card_player_snapshot(actor_id)
	var inventory: Dictionary = player.get("inventory", {}) if player.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	for card_variant in slots:
		if card_variant is Dictionary and _ai_v06_is_rank_i_facility_card(card_variant as Dictionary):
			return (card_variant as Dictionary).duplicate(true)
	return {}


func _ai_v06_legal_facility_region_ids(card: Dictionary, _actor_id: String) -> Array[String]:
	var preferred: Array[String] = []
	var fallback: Array[String] = []
	if not _ai_v06_is_rank_i_facility_card(card):
		return preferred
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	var payload: Dictionary = machine.get("effect_payload", {}) if machine.get("effect_payload", {}) is Dictionary else {}
	var facility_kind := str(payload.get("facility_kind", ""))
	var industry_id := str(payload.get("industry_id", machine.get("industry_id", "")))
	var allowed_states: Array = payload.get("allowed_region_states", []) if payload.get("allowed_region_states", []) is Array else []
	if facility_kind.is_empty() or industry_id.is_empty() or allowed_states.is_empty():
		return preferred
	var infrastructure := _region_infrastructure_runtime_controller_node()
	var bridge := _region_infrastructure_world_bridge_node()
	if infrastructure == null or bridge == null or not infrastructure.has_method("region_snapshot") \
			or not infrastructure.has_method("slot_id") or not bridge.has_method("public_commodity_region_facts"):
		return preferred
	var facts_variant: Variant = bridge.call("public_commodity_region_facts")
	var facts_rows: Array = facts_variant if facts_variant is Array else []
	var product_rows_key := "demand_products" if facility_kind == "market" else "production_products"
	for facts_variant_item in facts_rows:
		if not (facts_variant_item is Dictionary):
			continue
		var facts: Dictionary = facts_variant_item
		var has_matching_product := false
		for product_variant in facts.get(product_rows_key, []) as Array:
			if product_variant is Dictionary and str((product_variant as Dictionary).get("industry_id", "")) == industry_id:
				has_matching_product = true
				break
		var region_id := str(facts.get("region_id", "")).strip_edges()
		var region_variant: Variant = infrastructure.call("region_snapshot", region_id)
		var region: Dictionary = region_variant if region_variant is Dictionary else {}
		if region.is_empty() or not allowed_states.has(str(region.get("lifecycle_state", ""))):
			continue
		var slot_id := str(infrastructure.call("slot_id", region_id, facility_kind, industry_id))
		var slot_ids: Array = region.get("facility_slot_ids", []) if region.get("facility_slot_ids", []) is Array else []
		if slot_id.is_empty() or not slot_ids.has(slot_id):
			continue
		var occupied := false
		for facility_variant in region.get("facilities", []) as Array:
			if facility_variant is Dictionary and bool((facility_variant as Dictionary).get("active", false)) \
					and str((facility_variant as Dictionary).get("slot_id", "")) == slot_id:
				occupied = true
				break
		if not occupied:
			if has_matching_product:
				preferred.append(region_id)
			else:
				fallback.append(region_id)
	preferred.sort()
	fallback.sort()
	preferred.append_array(fallback)
	return preferred


func _ai_v06_inventory_transaction_result(transaction_id: String) -> Dictionary:
	if transaction_id.is_empty():
		return {}
	var inventory := _commodity_card_inventory_runtime_controller_node()
	if inventory == null or not inventory.has_method("transaction_journal_snapshot"):
		return {}
	var journal_variant: Variant = inventory.call("transaction_journal_snapshot")
	var journal: Dictionary = journal_variant if journal_variant is Dictionary else {}
	var record_variant: Variant = journal.get(transaction_id, {})
	if not (record_variant is Dictionary):
		return {}
	var result_variant: Variant = (record_variant as Dictionary).get("result", {})
	return (result_variant as Dictionary).duplicate(true) if result_variant is Dictionary else {}


func _ai_v06_binding_revision(binding: Dictionary) -> int:
	var digest := JSON.stringify(_v06_canonicalize(binding)).sha256_text()
	return int(digest.substr(0, 7).hex_to_int()) if digest.length() >= 7 else 0


func execute_v06_facility_play_action(actor_id: String, card_id: String, region_id: String) -> Dictionary:
	var action_source := {
		"schema_version": 1,
		"action_id": "facility_card_play",
		"action_family": "card_play",
	}
	var normalized_actor_id := actor_id.strip_edges()
	var normalized_card_id := card_id.strip_edges()
	var normalized_region_id := region_id.strip_edges()
	if normalized_actor_id.is_empty() or normalized_card_id.is_empty() or normalized_region_id.is_empty():
		action_source["failure_code"] = "facility_play_request_invalid"
		return compose_action_result_v1(action_source)
	var player := v06_card_player_snapshot(normalized_actor_id)
	var inventory: Dictionary = player.get("inventory", {}) if player.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	var slot_index := -1
	var runtime_instance_id := ""
	for index in range(slots.size()):
		if not (slots[index] is Dictionary):
			continue
		var card: Dictionary = slots[index]
		var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
		if str(machine.get("card_id", "")).strip_edges() == normalized_card_id and _v06_is_facility_card(card):
			if slot_index >= 0:
				slot_index = -1
				runtime_instance_id = ""
				break
			slot_index = index
			runtime_instance_id = str(card.get("runtime_instance_id", "")).strip_edges()
	if slot_index < 0 or runtime_instance_id.is_empty():
		action_source["failure_code"] = "ai_v06_facility_card_binding_changed"
		return compose_action_result_v1(action_source)
	var player_index := _ai_v06_actor_player_index(normalized_actor_id)
	var submission := _card_play_submission_runtime_controller_node()
	if player_index < 0 or submission == null or not submission.has_method("submit_v06_facility_play_action"):
		action_source["failure_code"] = "facility_play_settlement_unavailable"
		return compose_action_result_v1(action_source)
	var submission_receipt := submission.submit_v06_facility_play_action({
		"player_index": player_index,
		"actor_id": normalized_actor_id,
		"slot_index": slot_index,
		"card_id": normalized_card_id,
		"runtime_instance_id": runtime_instance_id,
		"transaction_id": "v06-play:%s:%s:%s" % [normalized_actor_id, runtime_instance_id, normalized_region_id],
		"region_id": normalized_region_id,
	})
	var owner_result: Dictionary = submission_receipt.get("v06_receipt", {}) if submission_receipt.get("v06_receipt", {}) is Dictionary else {}
	var effect_finalization: Dictionary = owner_result.get("effect_finalization", {}) if owner_result.get("effect_finalization", {}) is Dictionary else {}
	var finalized := bool(submission_receipt.get("accepted", false)) \
		and bool(owner_result.get("committed", false)) \
		and bool(effect_finalization.get("finalized", owner_result.get("finalized", false)))
	if not finalized:
		action_source["failure_code"] = _v06_facility_public_action_failure_code(
			str(submission_receipt.get("reason", owner_result.get("reason_code", "facility_play_settlement_unavailable")))
		)
		return compose_action_result_v1(action_source)
	var source_after := economic_source_snapshot(normalized_actor_id)
	if not bool(source_after.get("available", false)) or int(source_after.get("owned_facility_count", 0)) < 1:
		action_source["failure_code"] = "facility_play_settlement_unavailable"
		return compose_action_result_v1(action_source)
	action_source["public_receipt"] = {
		"event_code": "facility_play_committed",
		"region_id": normalized_region_id,
		"owned_facility_count": int(source_after.get("owned_facility_count", 0)),
		"production_installation_count": int(source_after.get("production_installation_count", 0)),
		"idempotent_replay": bool(owner_result.get("idempotent_replay", false)),
	}
	return compose_action_result_v1(action_source)


func _v06_facility_public_action_failure_code(reason_code: String) -> String:
	match reason_code:
		"public_facility_target_unavailable", "public_facility_slot_occupied", \
		"public_facility_slot_incompatible", "public_facility_product_unavailable":
			return "facility_play_target_unavailable"
		"public_facility_card_unavailable", "v06_authoritative_slot_changed", \
		"v06_authoritative_instance_missing":
			return "facility_play_card_changed"
		"game_over", "forced_decision_pending", "player_action_cooldown", \
		"card_locked", "card_cooldown", "asset_cost_unavailable", \
		"player_mana_snapshot_missing", "public_facility_preflight_unavailable":
			return "facility_play_settlement_unavailable"
	return reason_code


func _v06_runtime_card_catalog() -> Resource:
	var inventory := _commodity_card_inventory_runtime_controller_node()
	if inventory == null or not inventory.has_method("catalog"):
		return null
	var value_variant: Variant = inventory.call("catalog")
	return value_variant as Resource if value_variant is Resource else null


func v06_runtime_card_route(card: Dictionary) -> Dictionary:
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	var card_id := str(machine.get("card_id", ""))
	var effect_kind := str(machine.get("effect_kind", ""))
	if card_id.is_empty() or effect_kind.is_empty():
		return {"handled": false, "ready": false, "reason_code": "not_v06_runtime_card"}
	if CORE_ECONOMIC_CARD_EFFECT_KINDS_V06.has(effect_kind):
		return {
			"handled": true,
			"ready": bool(_core_economic_card_runtime_adapter_v06_debug_snapshot().get("configured", false)),
			"route_id": "core_economic_card_runtime",
			"effect_kind": effect_kind,
			"card_id": card_id,
			"reason_code": "core_economic_card_runtime_ready",
		}
	if effect_kind == "deploy_or_upgrade_monster":
		var matrix_variant: Variant = _monster_card_effect_adapter_v06.call("capability_matrix") if _monster_card_effect_adapter_v06 != null and _monster_card_effect_adapter_v06.has_method("capability_matrix") else {}
		var matrix: Dictionary = matrix_variant if matrix_variant is Dictionary else {}
		return {
			"handled": true,
			"ready": bool(matrix.get("atomic_mutation_ready", false)),
			"route_id": "monster_card_runtime",
			"effect_kind": effect_kind,
			"card_id": card_id,
			"reason_code": str(matrix.get("capability_reason", "monster_cross_owner_atomicity_unavailable")),
		}
	return {
		"handled": true,
		"ready": false,
		"route_id": "unsupported_v06_card_runtime",
		"effect_kind": effect_kind,
		"card_id": card_id,
		"reason_code": "v06_card_effect_route_unavailable",
	}


func play_v06_runtime_card(request: Dictionary) -> Dictionary:
	var actor_id := str(request.get("actor_id", "")).strip_edges()
	var slot_index := int(request.get("slot_index", -1))
	var transaction_id := str(request.get("transaction_id", "")).strip_edges()
	if actor_id.is_empty() or slot_index < 0 or transaction_id.is_empty():
		return {"handled": true, "committed": false, "reason_code": "v06_card_play_request_invalid"}
	var inventory := _commodity_card_inventory_runtime_controller_node()
	if not _configured or inventory == null or not inventory.has_method("player_snapshot"):
		return {"handled": true, "committed": false, "reason_code": "v06_card_runtime_not_ready"}
	var terminal_replay := _v06_runtime_card_terminal_replay(request, inventory)
	if bool(terminal_replay.get("handled", false)):
		return terminal_replay
	var player_variant: Variant = inventory.call("player_snapshot", actor_id)
	var player: Dictionary = (player_variant as Dictionary).duplicate(true) if player_variant is Dictionary else {}
	var card := _v06_player_card_at(player, slot_index)
	var route := v06_runtime_card_route(card)
	if not bool(route.get("handled", false)):
		return route
	if not bool(route.get("ready", false)):
		route["committed"] = false
		return route
	if SHARED_RESOLUTION_EFFECT_KINDS_V06.has(str(route.get("effect_kind", ""))):
		return {
			"handled": true,
			"committed": false,
			"route_id": str(route.get("route_id", "")),
			"effect_kind": str(route.get("effect_kind", "")),
			"card_id": str(route.get("card_id", "")),
			"reason_code": "v06_card_requires_shared_resolution",
		}
	var target_result := _v06_runtime_card_target_context(card, actor_id, request)
	if not bool(target_result.get("ready", false)):
		return {
			"handled": true,
			"committed": false,
			"route_id": str(route.get("route_id", "")),
			"effect_kind": str(route.get("effect_kind", "")),
			"card_id": str(route.get("card_id", "")),
			"reason_code": str(target_result.get("reason_code", "v06_card_target_unavailable")),
		}
	var target_context: Dictionary = target_result.get("target_context", {}) if target_result.get("target_context", {}) is Dictionary else {}
	var expected_revision := int(player.get("revision", -1))
	var value_variant: Variant
	if str(route.get("route_id", "")) == "core_economic_card_runtime":
		var core_adapter := _core_economic_card_runtime_adapter_v06_node()
		value_variant = core_adapter.call("play_card", actor_id, slot_index, target_context, expected_revision, transaction_id)
	elif str(route.get("route_id", "")) == "monster_card_runtime":
		value_variant = inventory.call("play_core_card", actor_id, slot_index, target_context, _monster_card_effect_adapter_v06, expected_revision, transaction_id)
	else:
		return {"handled": true, "committed": false, "reason_code": "v06_card_effect_route_unavailable"}
	var result: Dictionary = (value_variant as Dictionary).duplicate(true) if value_variant is Dictionary else {}
	result["handled"] = true
	result["route_id"] = str(route.get("route_id", ""))
	result["card_id"] = str(route.get("card_id", result.get("card_id", "")))
	result["effect_kind"] = str(route.get("effect_kind", result.get("effect_kind", "")))
	if str(result.get("reason_code", "")).is_empty():
		result["reason_code"] = "v06_card_play_committed" if bool(result.get("committed", false)) else "v06_card_play_rejected"
	return result


func revalidate_queued_v06_automatic_supply_demand(entry: Dictionary, skill: Dictionary) -> Dictionary:
	var machine: Dictionary = skill.get("machine", {}) if skill.get("machine", {}) is Dictionary else {}
	var effect_kind := str(machine.get("effect_kind", ""))
	var card_id := str(machine.get("card_id", ""))
	var card_instance_id := str(skill.get("runtime_instance_id", ""))
	var player_index := int(entry.get("player_index", -1))
	if not _configured or not SHARED_RESOLUTION_EFFECT_KINDS_V06.has(effect_kind) or card_id.is_empty() or card_instance_id.is_empty() or player_index < 0:
		return {"valid": false, "reason_code": "queued_supply_demand_binding_invalid", "skill": skill.duplicate(true)}
	var actor_binding := actor_id_for_player_index(player_index)
	var actor_id := str(actor_binding.get("actor_id", ""))
	if not bool(actor_binding.get("available", false)) \
			or actor_id != str(entry.get("v06_actor_id", "")) \
			or card_id != str(entry.get("v06_card_id", "")) \
			or card_instance_id != str(entry.get("v06_card_instance_id", "")) \
			or effect_kind != str(entry.get("v06_effect_kind", "")):
		return {"valid": false, "reason_code": "queued_supply_demand_binding_changed", "skill": skill.duplicate(true)}
	var preflight := preflight_v06_automatic_supply_demand(actor_id, skill)
	if not bool(preflight.get("ready", false)):
		return {
			"valid": false,
			"reason_code": str(preflight.get("reason_code", "queued_supply_demand_conditions_unmet")),
			"skill": skill.duplicate(true),
		}
	var refreshed_skill := skill.duplicate(true)
	refreshed_skill["_v06_automatic_target_context"] = (preflight.get("target_context", {}) as Dictionary).duplicate(true)
	return {
		"valid": true,
		"reason_code": "queued_supply_demand_ready",
		"skill": refreshed_skill,
	}


func preflight_v06_automatic_supply_demand(actor_id: String, card: Dictionary) -> Dictionary:
	var target_result := _v06_runtime_card_target_context(card, actor_id, {})
	if not bool(target_result.get("ready", false)):
		return {
			"ready": false,
			"reason_code": str(target_result.get("reason_code", "queued_supply_demand_conditions_unmet")),
		}
	var core_adapter := _core_economic_card_runtime_adapter_v06_node()
	if core_adapter == null or not core_adapter.has_method("preflight_automatic_supply_demand"):
		return {"ready": false, "reason_code": "core_economic_runtime_unavailable"}
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	var card_instance_id := str(card.get("runtime_instance_id", ""))
	var target_context: Dictionary = target_result.get("target_context", {}) if target_result.get("target_context", {}) is Dictionary else {}
	var transaction_id := "preflight:v06-supply-demand:%s:%s:%s" % [
		actor_id,
		card_instance_id,
		str(machine.get("effect_kind", "")),
	]
	var value_variant: Variant = core_adapter.call(
		"preflight_automatic_supply_demand",
		actor_id,
		card.duplicate(true),
		target_context.duplicate(true),
		transaction_id
	)
	var result: Dictionary = (value_variant as Dictionary).duplicate(true) if value_variant is Dictionary else {
		"ready": false,
		"reason_code": "automatic_supply_demand_preflight_invalid",
	}
	if bool(result.get("ready", false)):
		result["target_context"] = target_context.duplicate(true)
	return result


func resolve_queued_v06_automatic_supply_demand(entry: Dictionary, skill: Dictionary) -> Dictionary:
	var resolution_id := int(entry.get("resolution_id", entry.get("queued_order", -1)))
	var actor_id := str(entry.get("v06_actor_id", ""))
	var target_context: Dictionary = skill.get("_v06_automatic_target_context", {}) if skill.get("_v06_automatic_target_context", {}) is Dictionary else {}
	var core_adapter := _core_economic_card_runtime_adapter_v06_node()
	if resolution_id < 0 or actor_id.is_empty() or target_context.is_empty() or core_adapter == null or not core_adapter.has_method("resolve_queued_automatic_supply_demand"):
		return {"handled": true, "committed": false, "finalized": false, "resolved": false, "reason_code": "queued_supply_demand_runtime_unavailable"}
	var result_variant: Variant = core_adapter.call(
		"resolve_queued_automatic_supply_demand",
		actor_id,
		skill.duplicate(true),
		target_context.duplicate(true),
		"card-resolution:%d:v06-supply-demand" % resolution_id
	)
	return (result_variant as Dictionary).duplicate(true) if result_variant is Dictionary else {
		"handled": true,
		"committed": false,
		"finalized": false,
		"resolved": false,
		"reason_code": "queued_supply_demand_receipt_invalid",
	}


func _v06_runtime_card_terminal_replay(request: Dictionary, inventory: Object) -> Dictionary:
	var transaction_id := str(request.get("transaction_id", "")).strip_edges()
	if transaction_id.is_empty() or inventory == null or not inventory.has_method("transaction_journal_snapshot"):
		return {"handled": false}
	var journal_variant: Variant = inventory.call("transaction_journal_snapshot")
	if not (journal_variant is Dictionary) or not (journal_variant as Dictionary).has(transaction_id):
		return {"handled": false}
	var record_variant: Variant = (journal_variant as Dictionary).get(transaction_id)
	if not (record_variant is Dictionary):
		return _v06_runtime_card_replay_failure("v06_card_play_terminal_invalid")
	var saved_variant: Variant = (record_variant as Dictionary).get("result")
	if not (saved_variant is Dictionary):
		return _v06_runtime_card_replay_failure("v06_card_play_terminal_invalid")
	var saved := saved_variant as Dictionary
	# A rejected play leaves the card in hand, so the ordinary path can ask the
	# Inventory owner to replay it with the current authoritative card facts.
	if not bool(saved.get("committed", false)):
		return {"handled": false}
	var actor_id := str(request.get("actor_id", "")).strip_edges()
	if (
		str(saved.get("operation", "")) != "play_card"
		or str(saved.get("transaction_id", "")) != transaction_id
		or str(saved.get("actor_id", "")) != actor_id
	):
		return _v06_runtime_card_replay_failure("v06_card_play_replay_binding_mismatch")
	var card_id := str(saved.get("card_id", ""))
	var effect_kind := str(saved.get("effect_kind", ""))
	var card := v06_card_definition(card_id)
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	if card_id.is_empty() or effect_kind.is_empty() or str(machine.get("card_id", "")) != card_id or str(machine.get("effect_kind", "")) != effect_kind:
		return _v06_runtime_card_replay_failure("v06_card_play_replay_card_binding_mismatch")
	var effect_receipt: Dictionary = saved.get("effect_receipt", {}) if saved.get("effect_receipt", {}) is Dictionary else {}
	var player_after: Dictionary = saved.get("player_state", {}) if saved.get("player_state", {}) is Dictionary else {}
	var expected_player_revision := int(player_after.get("revision", -1)) - 1
	if expected_player_revision < 0 or str(effect_receipt.get("target_hash", "")).is_empty():
		return _v06_runtime_card_replay_failure("v06_card_play_terminal_invalid")
	var target_result := _v06_runtime_card_replay_target_context(card, request, effect_receipt, expected_player_revision)
	if not bool(target_result.get("ready", false)):
		return _v06_runtime_card_replay_failure(str(target_result.get("reason_code", "v06_card_play_replay_binding_mismatch")))
	var target_context: Dictionary = target_result.get("target_context", {}) if target_result.get("target_context", {}) is Dictionary else {}
	var slot_index := int(request.get("slot_index", -1))
	var card_flow_intent_hash := _v06_stable_hash({
		"operation": "play_card",
		"actor_id": actor_id,
		"slot_index": slot_index,
		"target_hash": str(effect_receipt.get("target_hash", "")),
		"expected_player_revision": expected_player_revision,
	})
	if card_flow_intent_hash != str(saved.get("intent_hash", "")) or card_flow_intent_hash != str(effect_receipt.get("intent_hash", "")):
		return _v06_runtime_card_replay_failure("v06_card_play_replay_binding_mismatch")
	var route := v06_runtime_card_route(card)
	if not bool(route.get("handled", false)) or not bool(route.get("ready", false)):
		return _v06_runtime_card_replay_failure(str(route.get("reason_code", "v06_card_effect_route_unavailable")))
	var replay_variant: Variant
	if str(route.get("route_id", "")) == "core_economic_card_runtime":
		var core_adapter := _core_economic_card_runtime_adapter_v06_node()
		replay_variant = core_adapter.call("play_card", actor_id, slot_index, target_context, expected_player_revision, transaction_id)
	elif str(route.get("route_id", "")) == "monster_card_runtime":
		replay_variant = inventory.call("play_core_card", actor_id, slot_index, target_context, _monster_card_effect_adapter_v06, expected_player_revision, transaction_id)
	else:
		return _v06_runtime_card_replay_failure("v06_card_effect_route_unavailable")
	var replay: Dictionary = (replay_variant as Dictionary).duplicate(true) if replay_variant is Dictionary else {}
	replay["handled"] = true
	replay["route_id"] = str(route.get("route_id", ""))
	replay["card_id"] = card_id
	replay["effect_kind"] = effect_kind
	if not bool(replay.get("idempotent_replay", false)):
		return _v06_runtime_card_replay_failure(str(replay.get("reason_code", "v06_card_play_replay_binding_mismatch")))
	return replay


func _v06_runtime_card_replay_target_context(card: Dictionary, request: Dictionary, effect_receipt: Dictionary, expected_player_revision: int) -> Dictionary:
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	var payload: Dictionary = machine.get("effect_payload", {}) if machine.get("effect_payload", {}) is Dictionary else {}
	var effect_kind := str(machine.get("effect_kind", ""))
	var region_id := str(request.get("region_id", "")).strip_edges()
	var game_time := float(request.get("game_time", 0.0))
	var target_hash := str(effect_receipt.get("target_hash", ""))
	if target_hash.is_empty():
		return {"ready": false, "reason_code": "v06_card_play_replay_binding_mismatch"}
	if effect_kind == "build_upgrade_or_repair_facility":
		if region_id.is_empty():
			return {"ready": false, "reason_code": "v06_card_play_replay_binding_mismatch"}
		var infrastructure := _region_infrastructure_runtime_controller_node()
		if infrastructure == null:
			return {"ready": false, "reason_code": "facility_target_region_missing"}
		var facility_kind := str(payload.get("facility_kind", ""))
		var industry_id := str(payload.get("industry_id", machine.get("industry_id", "")))
		var target_context := {
			"valid": true,
			"target_kind": str(machine.get("target_kind", "")),
			"region_id": region_id,
			"slot_id": str(infrastructure.call("slot_id", region_id, facility_kind, industry_id)),
			"industry_id": industry_id,
			"game_time": game_time,
		}
		return {"ready": _v06_stable_hash(target_context) == target_hash, "reason_code": "v06_card_play_replay_binding_mismatch", "target_context": target_context}
	if effect_kind == "install_organization_upgrade":
		var actor_id := str(request.get("actor_id", "")).strip_edges()
		var activation_sequence := int(effect_receipt.get("activation_window_sequence", -1))
		var committed_owner_revision := int(effect_receipt.get("owner_revision", -1))
		if actor_id.is_empty() or activation_sequence <= 0 or committed_owner_revision <= 0:
			return {"ready": false, "reason_code": "v06_card_play_terminal_invalid"}
		var target_context := {
			"target_actor_id": actor_id,
			"target_kind": str(machine.get("target_kind", "")),
			"window_sequence": activation_sequence - 1,
			"expected_owner_revision": committed_owner_revision - 1,
		}
		return {"ready": _v06_stable_hash(target_context) == target_hash, "reason_code": "v06_card_play_replay_binding_mismatch", "target_context": target_context}
	if ["global_order_budget", "global_supply_spawn"].has(effect_kind):
		var owner_receipt: Dictionary = effect_receipt.get("owner_receipt", {}) if effect_receipt.get("owner_receipt", {}) is Dictionary else {}
		var candidate_snapshot_revision := int(owner_receipt.get("candidate_snapshot_revision", -1))
		if candidate_snapshot_revision < 0:
			return {"ready": false, "reason_code": "v06_card_play_terminal_invalid"}
		var target_context := {
			"valid": true,
			"target_kind": str(machine.get("target_kind", "")),
			"candidate_snapshot_revision": candidate_snapshot_revision,
		}
		return {
			"ready": _v06_stable_hash(target_context) == target_hash,
			"reason_code": "v06_card_play_replay_binding_mismatch",
			"target_context": target_context,
		}
	if effect_kind == "deploy_or_upgrade_monster":
		if region_id.is_empty():
			return {"ready": false, "reason_code": "v06_card_play_replay_binding_mismatch"}
		var region_snapshot_variant: Variant = _region_infrastructure_runtime_controller_node().call("region_snapshot", region_id) if _region_infrastructure_runtime_controller_node() != null else {}
		var region_snapshot: Dictionary = region_snapshot_variant if region_snapshot_variant is Dictionary else {}
		var latest_region_revision := maxi(0, int(region_snapshot.get("revision", 0)))
		var expected_owner_revision := int(effect_receipt.get("expected_owner_revision", -1))
		var action_kind := str(effect_receipt.get("action_kind", ""))
		if expected_owner_revision < 0 or action_kind.is_empty():
			return {"ready": false, "reason_code": "v06_card_play_terminal_invalid"}
		for expected_region_revision in range(latest_region_revision + 1):
			var target_context := {
				"region_id": region_id,
				"expected_region_revision": expected_region_revision,
				"expected_binding_rule_revision": expected_player_revision,
				"valid": true,
				"target_kind": str(machine.get("target_kind", "")),
				"expected_owner_revision": expected_owner_revision,
				"action_kind": action_kind,
				"game_time": game_time,
			}
			if _v06_stable_hash(target_context) == target_hash:
				return {"ready": true, "reason_code": "v06_card_play_replay_target_ready", "target_context": target_context}
		return {"ready": false, "reason_code": "v06_card_play_replay_binding_mismatch"}
	return {"ready": false, "reason_code": "v06_card_play_replay_route_unsupported"}


func _v06_runtime_card_replay_failure(reason_code: String) -> Dictionary:
	return {
		"handled": true,
		"committed": false,
		"idempotent_replay": false,
		"reason_code": reason_code,
	}


func _v06_stable_hash(value: Variant) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(JSON.stringify(_v06_canonicalize(value)).to_utf8_buffer())
	return context.finish().hex_encode()


func _v06_canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		var keys: Array = (value as Dictionary).keys()
		keys.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
		for key_variant in keys:
			result[str(key_variant)] = _v06_canonicalize((value as Dictionary).get(key_variant))
		return result
	if value is Array:
		var result: Array = []
		for item_variant in value as Array:
			result.append(_v06_canonicalize(item_variant))
		return result
	return value


func _v06_player_card_at(player: Dictionary, slot_index: int) -> Dictionary:
	var inventory: Dictionary = player.get("inventory", {}) if player.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	if slot_index < 0 or slot_index >= slots.size() or not (slots[slot_index] is Dictionary):
		return {}
	return (slots[slot_index] as Dictionary).duplicate(true)


func _v06_runtime_card_target_context(card: Dictionary, actor_id: String, request: Dictionary) -> Dictionary:
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	var effect_kind := str(machine.get("effect_kind", ""))
	var region_id := str(request.get("region_id", "")).strip_edges()
	var game_time := float(request.get("game_time", 0.0))
	if effect_kind == "build_upgrade_or_repair_facility":
		var core_adapter := _core_economic_card_runtime_adapter_v06_node()
		if core_adapter == null or not core_adapter.has_method("facility_target_context"):
			return {"ready": false, "reason_code": "core_economic_runtime_unavailable"}
		var target_variant: Variant = core_adapter.call(
			"facility_target_context",
			actor_id,
			int(request.get("slot_index", -1)),
			str(machine.get("card_id", "")),
			region_id,
			game_time
		)
		return (target_variant as Dictionary).duplicate(true) if target_variant is Dictionary else {
			"ready": false,
			"reason_code": "facility_target_context_invalid",
		}
	if effect_kind == "install_organization_upgrade":
		var organization_owner := _player_organization_runtime_controller_node()
		var window_sequence := _authoritative_organization_window_sequence()
		if organization_owner == null or window_sequence < 0 or not organization_owner.has_method("private_snapshot"):
			return {"ready": false, "reason_code": "organization_window_or_owner_unavailable"}
		var private_variant: Variant = organization_owner.call("private_snapshot", actor_id, window_sequence)
		var private_snapshot: Dictionary = private_variant if private_variant is Dictionary else {}
		if not bool(private_snapshot.get("available", false)):
			return {"ready": false, "reason_code": "organization_actor_unavailable"}
		return {
			"ready": true,
			"target_context": {
				"target_actor_id": actor_id,
				"target_kind": str(machine.get("target_kind", "")),
				"window_sequence": window_sequence,
				"expected_owner_revision": int(private_snapshot.get("owner_revision", -1)),
			},
		}
	if ["global_order_budget", "global_supply_spawn"].has(effect_kind):
		var core_adapter := _core_economic_card_runtime_adapter_v06_node()
		if core_adapter == null or not core_adapter.has_method("automatic_supply_demand_target_context"):
			return {"ready": false, "reason_code": "core_economic_runtime_unavailable"}
		var context_variant: Variant = core_adapter.call(
			"automatic_supply_demand_target_context",
			effect_kind,
			str(machine.get("target_kind", ""))
		)
		return (context_variant as Dictionary).duplicate(true) if context_variant is Dictionary else {
			"ready": false,
			"reason_code": "automatic_supply_demand_target_context_invalid",
		}
	if effect_kind == "deploy_or_upgrade_monster":
		var monster_controller := _monster_runtime_controller_node()
		if monster_controller == null or region_id.is_empty():
			return {"ready": false, "reason_code": "monster_target_region_missing"}
		var context_variant: Variant = monster_controller.call("monster_starter_first_summon_context_v06", actor_id, region_id, str(machine.get("card_id", "")))
		var context: Dictionary = context_variant if context_variant is Dictionary else {}
		if not bool(context.get("available", false)):
			return {"ready": false, "reason_code": str(context.get("reason_code", "monster_starter_context_unavailable"))}
		var target: Dictionary = (context.get("target_context", {}) as Dictionary).duplicate(true) if context.get("target_context", {}) is Dictionary else {}
		target["valid"] = true
		target["target_kind"] = str(machine.get("target_kind", ""))
		target["expected_owner_revision"] = int(context.get("expected_owner_revision", -1))
		target["action_kind"] = str(context.get("action_kind", ""))
		target["game_time"] = game_time
		return {"ready": true, "target_context": target}
	return {"ready": false, "reason_code": "v06_card_target_context_not_composed"}


func _authoritative_organization_window_sequence() -> int:
	var queue := _card_resolution_queue_node()
	if queue == null or not queue.has_method("queue_state_snapshot"):
		return -1
	var value_variant: Variant = queue.call("queue_state_snapshot")
	if not (value_variant is Dictionary):
		return -1
	return int((value_variant as Dictionary).get("last_group_window_sequence", -1))


func commodity_card_inventory_runtime_call(method_name: StringName, arguments: Array = []) -> Variant:
	var controller := _commodity_card_inventory_runtime_controller_node()
	if controller == null or not controller.has_method(method_name):
		push_error("CommodityCardInventoryRuntimeController method unavailable: %s" % method_name)
		return null
	return controller.callv(method_name, arguments)


func weather_runtime_call(method_name: StringName, arguments: Array = []) -> Variant:
	var controller := _weather_runtime_controller_node()
	if controller == null or not controller.has_method(method_name):
		push_error("WeatherRuntimeController method unavailable: %s" % method_name)
		return null
	return controller.callv(method_name, arguments)


func weather_to_save_data() -> Dictionary:
	var controller := _weather_runtime_controller_node()
	var value: Variant = controller.call("to_save_data") if controller != null and controller.has_method("to_save_data") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func apply_weather_save_data(data: Dictionary) -> Dictionary:
	var controller := _weather_runtime_controller_node()
	var value: Variant = controller.call("apply_save_data", data) if controller != null and controller.has_method("apply_save_data") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func tick_weather(delta: float) -> void:
	var ports := _runtime_world_ports_node()
	if ports != null and _runtime_actor_port_node() != null:
		_runtime_actor_port_node().tick_weather(delta)


func weather_runtime_public_projection() -> Dictionary:
	var service := _weather_presentation_runtime_service_node()
	var value: Variant = service.call("runtime_public_projection") if service != null and service.has_method("runtime_public_projection") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func weather_definitions_public_projection() -> Dictionary:
	var service := _weather_presentation_runtime_service_node()
	var value: Variant = service.call("definitions_public_projection") if service != null and service.has_method("definitions_public_projection") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func weather_forecast_view_model() -> Dictionary:
	var service := _weather_presentation_runtime_service_node()
	var value: Variant = service.call("forecast_view_model") if service != null and service.has_method("forecast_view_model") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func weather_map_overlay_view_model() -> Dictionary:
	var service := _weather_presentation_runtime_service_node()
	var value: Variant = service.call("map_overlay_view_model") if service != null and service.has_method("map_overlay_view_model") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func weather_region_detail_snapshot(region_index: int) -> Dictionary:
	var service := _weather_presentation_runtime_service_node()
	var value: Variant = service.call("region_detail_snapshot", region_index) if service != null and service.has_method("region_detail_snapshot") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func weather_telemetry_recent_events_snapshot() -> Dictionary:
	var service := _weather_telemetry_runtime_service_node()
	var value: Variant = service.call("recent_events_snapshot") if service != null and service.has_method("recent_events_snapshot") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func weather_telemetry_aggregate_snapshot() -> Dictionary:
	var service := _weather_telemetry_runtime_service_node()
	var value: Variant = service.call("aggregate_snapshot") if service != null and service.has_method("aggregate_snapshot") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func weather_telemetry_debug_snapshot() -> Dictionary:
	var service := _weather_telemetry_runtime_service_node()
	var value: Variant = service.call("debug_snapshot") if service != null and service.has_method("debug_snapshot") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func record_weather_public_response(region_index: int, category: String) -> int:
	var service := _weather_telemetry_runtime_service_node()
	if service == null or not service.has_method("record_public_response"):
		return 0
	return int(service.call("record_public_response", region_index, category))


func military_runtime_call(method_name: StringName, arguments: Array = []) -> Variant:
	var controller := _military_runtime_controller_node()
	if controller == null or not controller.has_method(method_name):
		push_error("MilitaryRuntimeController method unavailable: %s" % method_name)
		return null
	return controller.callv(method_name, arguments)


func military_to_save_data() -> Dictionary:
	var controller := _military_runtime_controller_node()
	var value: Variant = controller.call("to_save_data") if controller != null and controller.has_method("to_save_data") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func apply_military_save_data(data: Dictionary) -> Dictionary:
	var controller := _military_runtime_controller_node()
	var value: Variant = controller.call("apply_save_data", data) if controller != null and controller.has_method("apply_save_data") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func tick_military(delta: float) -> void:
	var ports := _runtime_world_ports_node()
	if ports != null and _runtime_actor_port_node() != null:
		_runtime_actor_port_node().tick_military(delta)


func monster_runtime_call(method_name: StringName, arguments: Array = []) -> Variant:
	var controller := _monster_runtime_controller_node()
	if controller == null or not controller.has_method(method_name):
		push_error("MonsterRuntimeController method unavailable: %s" % method_name)
		return null
	return controller.callv(method_name, arguments)


func player_organization_runtime_controller() -> PlayerOrganizationRuntimeController:
	return _player_organization_runtime_controller_node() as PlayerOrganizationRuntimeController


func organization_consumer_readiness_snapshot() -> Dictionary:
	var adapter := _core_economic_card_runtime_adapter_v06_node()
	if adapter != null and adapter.has_method("organization_consumer_readiness_snapshot"):
		var value_variant: Variant = adapter.call("organization_consumer_readiness_snapshot")
		if value_variant is Dictionary:
			return (value_variant as Dictionary).duplicate(true)
	return {"available": false, "production_ready": false, "reason_code": "organization_consumer_capabilities_incomplete"}


func organization_public_receipt(receipt: Dictionary) -> Dictionary:
	var adapter := _core_economic_card_runtime_adapter_v06_node()
	if adapter != null and adapter.has_method("organization_public_receipt"):
		var value_variant: Variant = adapter.call("organization_public_receipt", receipt.duplicate(true))
		if value_variant is Dictionary:
			return (value_variant as Dictionary).duplicate(true)
	return {"schema_version": "v0.6", "effect_kind": "install_organization_upgrade", "reason_code": "organization_owner_unavailable"}


func player_organization_checkpoint_status() -> Dictionary:
	var organization_owner := _player_organization_runtime_controller_node()
	var value_variant: Variant = organization_owner.call("checkpoint_status") if organization_owner != null and organization_owner.has_method("checkpoint_status") else {}
	return (value_variant as Dictionary).duplicate(true) if value_variant is Dictionary else {"can_checkpoint": false, "reason_code": "organization_owner_checkpoint_unavailable"}


func player_organization_to_save_data() -> Dictionary:
	var checkpoint := player_organization_checkpoint_status()
	if not bool(checkpoint.get("can_checkpoint", false)):
		return {"saved": false, "reason_code": str(checkpoint.get("reason_code", "organization_transactions_inflight")), "checkpoint": checkpoint}
	var organization_owner := _player_organization_runtime_controller_node()
	var value_variant: Variant = organization_owner.call("to_save_data") if organization_owner != null and organization_owner.has_method("to_save_data") else {}
	if not (value_variant is Dictionary):
		return {"saved": false, "reason_code": "organization_save_unavailable", "checkpoint": checkpoint}
	return {"saved": true, "reason_code": "organization_save_ready", "checkpoint": checkpoint, "owner_snapshot": (value_variant as Dictionary).duplicate(true)}


func apply_player_organization_save_data(data: Dictionary) -> Dictionary:
	var source: Dictionary = data.get("owner_snapshot", {}) if data.get("owner_snapshot", {}) is Dictionary else data
	var organization_owner := _player_organization_runtime_controller_node()
	var value_variant: Variant = organization_owner.call("apply_save_data", source.duplicate(true)) if organization_owner != null and organization_owner.has_method("apply_save_data") else {}
	return (value_variant as Dictionary).duplicate(true) if value_variant is Dictionary else {"applied": false, "reason_code": "organization_save_unavailable"}


func monster_to_save_data() -> Dictionary:
	var controller := _monster_runtime_controller_node()
	var value: Variant = controller.call("to_save_data") if controller != null and controller.has_method("to_save_data") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func apply_monster_save_data(data: Dictionary) -> Dictionary:
	var controller := _monster_runtime_controller_node()
	var value: Variant = controller.call("apply_save_data", data) if controller != null and controller.has_method("apply_save_data") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func tick_monster_wager_decisions_realtime(delta: float) -> void:
	var ports := _runtime_world_ports_node()
	if ports != null and _runtime_monster_port_node() != null:
		_runtime_monster_port_node().tick_wager_decisions_realtime(delta)


func tick_monster_battle_lifecycles(delta: float) -> void:
	var ports := _runtime_world_ports_node()
	if ports != null and _runtime_monster_port_node() != null:
		_runtime_monster_port_node().tick_battle_lifecycles(delta)


func tick_monster_motion(delta: float) -> void:
	var ports := _runtime_world_ports_node()
	if ports != null and _runtime_monster_port_node() != null:
		_runtime_monster_port_node().tick_motion(delta)


func tick_monster_lifecycle(delta: float) -> void:
	var controller := _monster_runtime_controller_node()
	if controller != null:
		controller.call("tick_lifecycle", delta)


func tick_monster_durations(delta: float) -> void:
	var ports := _runtime_world_ports_node()
	if ports != null and _runtime_monster_port_node() != null:
		_runtime_monster_port_node().tick_durations(delta)


func tick_monster_revivals(delta: float) -> void:
	var ports := _runtime_world_ports_node()
	if ports != null and _runtime_monster_port_node() != null:
		_runtime_monster_port_node().tick_revivals(delta)


func tick_monster_actions(delta: float) -> void:
	var ports := _runtime_world_ports_node()
	if ports != null and _runtime_monster_port_node() != null:
		_runtime_monster_port_node().tick_actions(delta)


func tick_ai(delta: float) -> void:
	var ports := _runtime_world_ports_node()
	if ports != null and _runtime_actor_port_node() != null:
		_runtime_actor_port_node().tick_ai(delta)


func ai_runtime_call(method_name: StringName, arguments: Array = []) -> Variant:
	var controller := _ai_runtime_controller_node()
	if controller == null or not controller.has_method(method_name):
		push_error("AiRuntimeController method unavailable: %s" % method_name)
		return null
	return controller.callv(method_name, arguments)


func ai_to_save_data() -> Dictionary:
	var controller := _ai_runtime_controller_node()
	var value: Variant = controller.call("to_save_data") if controller != null and controller.has_method("to_save_data") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func apply_ai_save_data(data: Dictionary) -> Dictionary:
	var controller := _ai_runtime_controller_node()
	var value: Variant = controller.call("apply_save_data", data) if controller != null and controller.has_method("apply_save_data") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func ai_policy_snapshot() -> Dictionary:
	var controller := _ai_runtime_controller_node()
	var value: Variant = controller.call("policy_snapshot") if controller != null and controller.has_method("policy_snapshot") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func synchronize_forced_decisions() -> Dictionary:
	var ports := _runtime_world_ports_node()
	return _runtime_lifecycle_port_node().synchronize_forced_decisions() if ports != null and _runtime_lifecycle_port_node() != null else {
		"synchronized": false,
		"reason": "runtime_lifecycle_port_unavailable",
	}


func advance_card_resolution_frame(delta: float) -> Dictionary:
	var ports := _runtime_world_ports_node()
	return _runtime_card_port_node().advance_card_resolution_frame(delta) if ports != null and _runtime_card_port_node() != null else {
		"handled": false,
		"reason": "runtime_card_port_unavailable",
	}


func card_resolution_frame_facts() -> Dictionary:
	_wire_card_resolution_frame_driver()
	var driver := _card_resolution_frame_driver_node()
	return driver.facts_snapshot() if driver != null else {}


func card_resolution_frame_driver_debug() -> Dictionary:
	var driver := _card_resolution_frame_driver_node()
	return driver.debug_snapshot() if driver != null else {}


func advance_card_cooldowns(delta: float) -> Dictionary:
	var ports := _runtime_world_ports_node()
	return _runtime_card_port_node().advance_card_cooldowns(delta) if ports != null and _runtime_card_port_node() != null else {
		"advanced": false,
		"reason": "runtime_card_port_unavailable",
	}


func arm_player_action_cooldown(player_index: int, seconds: float) -> Dictionary:
	_wire_card_cooldown_runtime_controller()
	var controller := _card_cooldown_runtime_controller_node()
	return controller.arm_player_action(player_index, seconds) if controller != null else {"armed": false, "reason": "card_cooldown_controller_unavailable"}


func arm_persistent_card_cooldown(player_index: int, slot_index: int, expected_runtime_instance_id: String, seconds: float) -> Dictionary:
	_wire_card_cooldown_runtime_controller()
	var controller := _card_cooldown_runtime_controller_node()
	return controller.arm_persistent_card(player_index, slot_index, expected_runtime_instance_id, seconds) if controller != null else {"armed": false, "reason": "card_cooldown_controller_unavailable"}


func card_cooldown_debug_snapshot() -> Dictionary:
	var controller := _card_cooldown_runtime_controller_node()
	return controller.debug_snapshot() if controller != null else {}


func configure_visual_cue_world_bounds(width_m: float, height_m: float) -> void:
	var cue_owner := _visual_cue_runtime_owner_node()
	if cue_owner != null:
		cue_owner.configure_world_bounds(width_m, height_m)


func bind_visual_cue_sfx_players(players: Dictionary) -> void:
	var cue_owner := _visual_cue_runtime_owner_node()
	if cue_owner != null:
		cue_owner.bind_sfx_players(players)


func reset_visual_cues() -> void:
	var cue_owner := _visual_cue_runtime_owner_node()
	if cue_owner != null:
		cue_owner.reset_state()


func import_legacy_visual_cues(state: Dictionary) -> Dictionary:
	var cue_owner := _visual_cue_runtime_owner_node()
	return cue_owner.import_legacy_state(state, _world_session_state_node().districts) if cue_owner != null else {"imported": false, "reason": "visual_cue_owner_unavailable"}


func advance_visual_cues(delta: float) -> Dictionary:
	var ports := _runtime_world_ports_node()
	return _runtime_presentation_port_node().advance_visual_cues(delta) if ports != null and _runtime_presentation_port_node() != null else {
		"advanced": false,
		"reason": "runtime_presentation_port_unavailable",
	}


func visual_cue_public_snapshot() -> Dictionary:
	var cue_owner := _visual_cue_runtime_owner_node()
	return cue_owner.public_snapshot() if cue_owner != null else {}


func visual_cue_districts_with_pulses(districts: Array) -> Array:
	var cue_owner := _visual_cue_runtime_owner_node()
	return cue_owner.districts_with_pulses(districts) if cue_owner != null else districts.duplicate(true)


func add_visual_action_callout(actor: String, action: String, detail: String, color: Color, world_position: Vector2, duration: float = VisualCueRuntimeOwner.ACTION_CALLOUT_DURATION) -> Dictionary:
	var cue_owner := _visual_cue_runtime_owner_node()
	return cue_owner.add_action_callout(actor, action, detail, color, world_position, duration) if cue_owner != null else {}


func add_visual_trail(from_position: Vector2, to_position: Vector2, color: Color, label: String, duration: float = VisualCueRuntimeOwner.VISUAL_TRAIL_DURATION, style: String = "movement") -> Dictionary:
	var cue_owner := _visual_cue_runtime_owner_node()
	return cue_owner.add_visual_trail(from_position, to_position, color, label, duration, style) if cue_owner != null else {}


func add_visual_map_event(kind: String, world_position: Vector2, color: Color, label: String = "", duration: float = VisualCueRuntimeOwner.MAP_EVENT_EFFECT_DURATION, radius_m: float = 70.0, card_style: String = "") -> Dictionary:
	var cue_owner := _visual_cue_runtime_owner_node()
	return cue_owner.add_map_event_effect(kind, world_position, color, label, duration, radius_m, card_style) if cue_owner != null else {}


func add_visual_attack_effect(kind: String, from_position: Vector2, to_position: Vector2, color: Color, label: String = "", duration: float = 0.95, radius_m: float = 80.0, action_profile: Dictionary = {}) -> Dictionary:
	var cue_owner := _visual_cue_runtime_owner_node()
	return cue_owner.add_attack_effect(kind, from_position, to_position, color, label, duration, radius_m, action_profile) if cue_owner != null else {}


func add_visual_district_damage(index: int, center: Vector2, radius_m: float, source: String, color: Color = Color("#f97316")) -> Dictionary:
	var cue_owner := _visual_cue_runtime_owner_node()
	return cue_owner.add_district_damage_effect(index, center, radius_m, source, color) if cue_owner != null else {}


func pulse_visual_district(index: int, color: Color) -> Dictionary:
	var cue_owner := _visual_cue_runtime_owner_node()
	return cue_owner.pulse_district(index, color) if cue_owner != null else {"pulsed": false, "reason": "visual_cue_owner_unavailable"}


func visual_cue_debug_snapshot() -> Dictionary:
	var cue_owner := _visual_cue_runtime_owner_node()
	return cue_owner.debug_snapshot() if cue_owner != null else {}


func advance_presentation_refresh_cadence(real_delta: float, developer_surface_visible: bool = false) -> Dictionary:
	var scheduler := _table_presentation_refresh_scheduler_node()
	return scheduler.advance(real_delta, developer_surface_visible) if scheduler != null else {"advanced": false, "reason": "presentation_refresh_scheduler_unavailable", "due": []}


func advance_table_presentation(real_delta: float) -> Array[TablePresentationApplyReceipt]:
	var ports := _runtime_world_ports_node()
	return _runtime_presentation_port_node().advance_table_presentation(real_delta) if ports != null and _runtime_presentation_port_node() != null else [] as Array[TablePresentationApplyReceipt]


func request_table_presentation_refresh(kind: StringName, _reason: StringName = &"state_changed") -> TablePresentationApplyReceipt:
	_wire_table_presentation_source_target()
	var port := _table_presentation_refresh_port_node()
	if port == null:
		return TablePresentationApplyReceipt.new()
	return port.request_immediate(kind, _reason)


func reset_presentation_refresh_cadence() -> Dictionary:
	var scheduler := _table_presentation_refresh_scheduler_node()
	return scheduler.reset_table_cadence() if scheduler != null else {"reset": false, "reason": "presentation_refresh_scheduler_unavailable"}


func request_immediate_presentation_refresh(kind: StringName) -> Dictionary:
	var scheduler := _table_presentation_refresh_scheduler_node()
	return scheduler.request_immediate(kind) if scheduler != null else {"accepted": false, "reason": "presentation_refresh_scheduler_unavailable"}


func presentation_refresh_cadence_debug_snapshot() -> Dictionary:
	var scheduler := _table_presentation_refresh_scheduler_node()
	return scheduler.debug_snapshot() if scheduler != null else {}


func table_presentation_source_target_debug_snapshot() -> Dictionary:
	return {
		"source": _table_presentation_source_owner_node().debug_snapshot() if _table_presentation_source_owner_node() != null else {},
		"port": _table_presentation_refresh_port_node().debug_snapshot() if _table_presentation_refresh_port_node() != null else {},
		"developer_target": _developer_balance_presentation_target_node().debug_snapshot() if _developer_balance_presentation_target_node() != null else {},
	}


func bind_developer_balance_presentation_panel(panel: DeveloperBalancePanel) -> void:
	var target := _developer_balance_presentation_target_node()
	if target == null:
		return
	target.bind_panel(panel)
	target.enabled = panel != null


func active_forced_decision(viewer_index: int = -1) -> Dictionary:
	synchronize_forced_decisions()
	var scheduler := _scheduler_node()
	if scheduler == null or not scheduler.has_method("active_decision"):
		return {}
	var decision_variant: Variant = scheduler.call("active_decision", viewer_index)
	return (decision_variant as Dictionary).duplicate(true) if decision_variant is Dictionary else {}


func blocks_global_time() -> bool:
	var ports := _runtime_world_ports_node()
	return _runtime_lifecycle_port_node().blocks_global_time() if ports != null and _runtime_lifecycle_port_node() != null else false


func blocks_player_actions(player_index: int) -> bool:
	var scheduler := _scheduler_node()
	return scheduler != null and scheduler.has_method("blocks_player_actions") and bool(scheduler.call("blocks_player_actions", player_index))


func allows_card_resolution_progress() -> bool:
	var ports := _runtime_world_ports_node()
	return _runtime_lifecycle_port_node().allows_card_resolution_progress() if ports != null and _runtime_lifecycle_port_node() != null else false


func district_purchase_pending_discard_private_snapshot(viewer_index: int) -> Dictionary:
	var purchase := _purchase_node()
	return purchase.pending_discard_private_snapshot(viewer_index) if purchase != null else {}


func forced_decision_sources_debug() -> Dictionary:
	var sources := _forced_decision_candidate_sources_node()
	return sources.debug_snapshot() if sources != null else {}


func preflight_new_session_plan(plan: Dictionary) -> Dictionary:
	if int(plan.get("plan_schema_version", 0)) != 1 or not (plan.get("districts", []) is Array) or not (plan.get("card_pool", []) is Array):
		return {"accepted": false, "reason_code": "runtime_new_session_plan_invalid"}
	var content := AlphaContentLoader.load_active_selection()
	if not content.is_valid():
		return {"accepted": false, "reason_code": "runtime_alpha_content_invalid", "errors": content.errors.duplicate()}
	if int(plan.get("challenge_depth", 0)) != content.active_challenge_depth() or (plan.get("card_pool", []) as Array) != content.region_supply_card_ids:
		return {"accepted": false, "reason_code": "runtime_alpha_content_plan_mismatch"}
	var required_nodes := [
		_product_market_runtime_controller_node(), _region_infrastructure_runtime_controller_node(),
		_region_supply_runtime_controller_node(), _world_session_state_node(), _table_selection_state_node(),
		_weather_runtime_controller_node(),
		_ai_runtime_controller_node(), _card_resolution_queue_node(), _card_resolution_execution_node(),
		_card_resolution_history_runtime_service_node(), _card_history_private_annotation_service_node(),
		_core_economic_card_runtime_adapter_v06_node(),
	]
	for node_variant in required_nodes:
		if node_variant == null:
			return {"accepted": false, "reason_code": "runtime_new_session_owner_missing"}
	var market_preflight: Dictionary = _product_market_runtime_controller_node().call("preflight_new_session", plan.get("product_market_state", {}))
	if not bool(market_preflight.get("accepted", false)):
		return market_preflight
	var weather_preflight: Dictionary = _weather_runtime_controller_node().call("preflight_new_session", plan.get("weather_state", {}))
	if not bool(weather_preflight.get("accepted", false)):
		return weather_preflight
	var region_definitions := _new_session_region_definitions(plan.get("districts", []) as Array)
	var infrastructure_preflight: Dictionary = _region_infrastructure_runtime_controller_node().call("preflight_new_session_regions", region_definitions)
	if not bool(infrastructure_preflight.get("accepted", false)):
		return infrastructure_preflight
	var supply_inputs := _new_session_region_supply_inputs(plan)
	if not bool(supply_inputs.get("valid", false)):
		return {"accepted": false, "reason_code": str(supply_inputs.get("reason_code", "runtime_new_session_supply_inputs_invalid"))}
	var supply_preflight: Dictionary = _region_supply_runtime_controller_node().call(
		"preflight_new_session_configuration",
		supply_inputs.get("regions", []),
		supply_inputs.get("cards", []),
		int(supply_inputs.get("slot_count", 4))
	)
	if not bool(supply_preflight.get("accepted", false)):
		return supply_preflight
	return {
		"accepted": true,
		"reason_code": "runtime_new_session_plan_valid",
		"region_definitions": region_definitions,
		"supply_inputs": supply_inputs,
	}


func capture_new_session_checkpoint() -> Dictionary:
	var saved_owners := {}
	for entry_variant in _new_session_saved_owners():
		var entry: Dictionary = entry_variant
		var owner_id := str(entry.get("owner_id", ""))
		var owner := entry.get("owner") as Node
		if owner == null or not owner.has_method("to_save_data"):
			return {"captured": false, "reason_code": "new_session_checkpoint_owner_unavailable", "owner_id": owner_id}
		var data_variant: Variant = owner.call("to_save_data")
		if not (data_variant is Dictionary):
			return {"captured": false, "reason_code": "new_session_checkpoint_data_invalid", "owner_id": owner_id}
		if owner_id == "product_market" and (data_variant as Dictionary).is_empty():
			return {"captured": false, "reason_code": "new_session_checkpoint_product_market_blocked", "owner_id": owner_id}
		saved_owners[owner_id] = (data_variant as Dictionary).duplicate(true)
	var annotations := _card_history_private_annotation_service_node()
	var ai_runtime := _ai_runtime_controller_node()
	var core_adapter := _core_economic_card_runtime_adapter_v06_node()
	return {
		"captured": true,
		"schema_version": 1,
		"configured": _configured,
		"binding_result": _last_v06_player_binding_result.duplicate(true),
		"saved_owners": saved_owners,
		"queue": _card_resolution_queue_node().capture_runtime_checkpoint(),
		"pricing": _card_market_pricing_runtime_controller_node().capture_runtime_checkpoint(),
		"card_inventory": _card_inventory_node().capture_runtime_checkpoint(),
		"hand_interaction": _player_hand_interaction_node().capture_runtime_checkpoint(),
		"purchase_settlement": _purchase_settlement_node().capture_runtime_checkpoint(),
		"economy_route_effect": _card_economy_product_route_effect_node().capture_runtime_checkpoint(),
		"annotations": annotations.call("capture_runtime_checkpoint") if annotations != null else {},
		"ai_runtime": ai_runtime.call("capture_new_session_checkpoint") if ai_runtime != null else {},
		"core_binding": core_adapter.call("capture_new_session_binding_checkpoint") if core_adapter != null else {},
		"world_effective_us": int(_world_effective_clock_runtime_controller_node().call("world_effective_micros")) if _world_effective_clock_runtime_controller_node() != null else 0,
	}


func apply_new_session_plan(plan: Dictionary) -> Dictionary:
	var preflight := preflight_new_session_plan(plan)
	if not bool(preflight.get("accepted", false)):
		return {"applied": false, "reason_code": str(preflight.get("reason_code", "runtime_new_session_preflight_failed"))}
	_configured = false
	_last_v06_player_binding_result = {"ready": false, "reason_code": "new_session_applying"}
	for owner in [
		_card_target_choice_runtime_controller_node(), _city_gdp_derivative_runtime_controller_node(),
		_route_network_runtime_controller_node(), _commodity_flow_runtime_controller_node(),
		_player_mana_runtime_controller_node(), _commodity_card_inventory_runtime_controller_node(),
		_player_organization_runtime_controller_node(), _bankruptcy_neutral_estate_runtime_controller_node(),
		_victory_control_runtime_controller_node(), _ai_runtime_controller_node(), _monster_runtime_controller_node(),
		_military_runtime_controller_node(), _weather_runtime_controller_node(),
		_purchase_node(), _card_resolution_execution_node(), _card_resolution_runtime_controller_node(),
	]:
		if owner != null and owner.has_method("reset_state"):
			owner.call("reset_state")
	_card_resolution_queue_node().reset_state()
	_card_market_pricing_runtime_controller_node().reset_state()
	_card_inventory_node().reset_state()
	_player_hand_interaction_node().reset_state()
	_purchase_settlement_node().reset_state()
	_card_economy_product_route_effect_node().reset_state()
	reset_card_resolution_history()
	if _new_session_fault("after_resets"):
		return {"applied": false, "reason_code": "new_session_fault_after_resets"}
	var clock := _world_effective_clock_runtime_controller_node()
	if clock != null and clock.has_method("reset_state"):
		clock.call("reset_state")
	var market_result: Dictionary = _product_market_runtime_controller_node().call("apply_new_session_plan", plan.get("product_market_state", {}))
	if not bool(market_result.get("applied", false)):
		return market_result
	if _new_session_fault("after_market_apply"):
		return {"applied": false, "reason_code": "new_session_fault_after_market_apply"}
	var infrastructure_result: Dictionary = _region_infrastructure_runtime_controller_node().call("initialize_regions", preflight.get("region_definitions", []))
	if not bool(infrastructure_result.get("initialized", false)):
		return {"applied": false, "reason_code": str(infrastructure_result.get("reason", "new_session_infrastructure_failed"))}
	if _new_session_fault("after_infrastructure_apply"):
		return {"applied": false, "reason_code": "new_session_fault_after_infrastructure_apply"}
	var supply_inputs: Dictionary = preflight.get("supply_inputs", {})
	var supply_result: Dictionary = _region_supply_runtime_controller_node().call(
		"configure",
		int(plan.get("region_supply_seed", 1)),
		supply_inputs.get("regions", []),
		supply_inputs.get("cards", []),
		int(supply_inputs.get("slot_count", 4))
	)
	if not bool(supply_result.get("configured", false)):
		return {"applied": false, "reason_code": str(supply_result.get("reason_code", "new_session_region_supply_failed"))}
	if _new_session_fault("after_supply_apply"):
		return {"applied": false, "reason_code": "new_session_fault_after_supply_apply"}
	var weather_result: Dictionary = _weather_runtime_controller_node().call("apply_new_session_plan", plan.get("weather_state", {}))
	if not bool(weather_result.get("applied", false)):
		return weather_result
	if _new_session_fault("after_weather_market_apply"):
		return {"applied": false, "reason_code": "new_session_fault_after_weather_market_apply"}
	var selection := _table_selection_state_node()
	selection.restore({
		"selected_player": 0, "inspected_player": 0,
		"selected_district": int(plan.get("selected_district", 0)),
		"selected_trade_product": "", "selected_card_resolution_id": -1,
		"selected_hand_slot": -1, "selected_map_layer_focus": "all",
	})
	var content := AlphaContentLoader.load_active_selection()
	var binding := refresh_v06_session_player_bindings(int(plan.get("region_supply_seed", 1)), content.commodity_track_card_ids)
	if not bool(binding.get("ready", false)):
		return {"applied": false, "reason_code": str(binding.get("reason_code", "new_session_player_binding_failed")), "binding": binding}
	if _new_session_fault("after_player_binding"):
		return {"applied": false, "reason_code": "new_session_fault_after_player_binding"}
	_ai_runtime_controller_node().call("ensure_player_state")
	_configured = true
	return {"applied": true, "reason_code": "runtime_new_session_applied", "binding": binding, "supply": supply_result}


func rollback_new_session_checkpoint(checkpoint: Dictionary) -> Dictionary:
	if int(checkpoint.get("schema_version", 0)) != 1 or not (checkpoint.get("saved_owners", {}) is Dictionary):
		return {"restored": false, "reason_code": "runtime_new_session_checkpoint_invalid", "failures": []}
	var failures: Array = []
	var core_adapter := _core_economic_card_runtime_adapter_v06_node()
	if core_adapter == null or not bool((core_adapter.call("restore_new_session_binding_checkpoint", checkpoint.get("core_binding", {})) as Dictionary).get("restored", false)):
		failures.append("core_binding")
	var ai_runtime := _ai_runtime_controller_node()
	if ai_runtime == null or not bool((ai_runtime.call("restore_new_session_checkpoint", checkpoint.get("ai_runtime", {})) as Dictionary).get("restored", false)):
		failures.append("ai_runtime")
	var annotations := _card_history_private_annotation_service_node()
	if annotations == null or not bool((annotations.call("restore_runtime_checkpoint", checkpoint.get("annotations", {})) as Dictionary).get("restored", false)):
		failures.append("annotations")
	for custom in [
		{"id": "economy_route_effect", "owner": _card_economy_product_route_effect_node()},
		{"id": "purchase_settlement", "owner": _purchase_settlement_node()},
		{"id": "hand_interaction", "owner": _player_hand_interaction_node()},
		{"id": "card_inventory", "owner": _card_inventory_node()},
		{"id": "pricing", "owner": _card_market_pricing_runtime_controller_node()},
		{"id": "queue", "owner": _card_resolution_queue_node()},
	]:
		var custom_owner := (custom as Dictionary).get("owner") as Node
		var custom_id := str((custom as Dictionary).get("id", ""))
		if custom_owner == null or not bool((custom_owner.call("restore_runtime_checkpoint", checkpoint.get(custom_id, {})) as Dictionary).get("restored", false)):
			failures.append(custom_id)
	var saved_owners: Dictionary = checkpoint.get("saved_owners", {})
	var owners := _new_session_saved_owners()
	owners.reverse()
	for entry_variant in owners:
		var entry: Dictionary = entry_variant
		var owner_id := str(entry.get("owner_id", ""))
		var owner := entry.get("owner") as Node
		var restore_method := str(entry.get("restore_method", "apply_save_data"))
		if owner == null or not owner.has_method(restore_method):
			failures.append(owner_id)
			continue
		var restored_variant: Variant = owner.call(restore_method, saved_owners.get(owner_id, {}))
		var restored: Dictionary = restored_variant if restored_variant is Dictionary else {}
		var accepted := bool(restored.get("restored", false)) if restore_method == "restore_new_session_checkpoint" else bool(restored.get("applied", false))
		if not accepted:
			failures.append(owner_id)
	var clock := _world_effective_clock_runtime_controller_node()
	if clock != null and clock.has_method("restore_micros"):
		clock.call("restore_micros", int(checkpoint.get("world_effective_us", 0)))
	_configured = bool(checkpoint.get("configured", false))
	_last_v06_player_binding_result = (checkpoint.get("binding_result", {}) as Dictionary).duplicate(true)
	return {"restored": failures.is_empty(), "reason_code": "runtime_new_session_checkpoint_restored" if failures.is_empty() else "runtime_new_session_rollback_incomplete", "failures": failures}


func commit_new_session_side_effects(plan: Dictionary) -> Dictionary:
	_new_session_commit_side_effect_count += 1
	var rng_before := _run_rng_service_node().capture_plan_checkpoint()
	var market_before: Dictionary = _product_market_runtime_controller_node().call("to_save_data")
	var weather_before: Dictionary = _weather_runtime_controller_node().call("to_save_data")
	var card_supply_presentation := _table_card_supply_presentation_state_node()
	if card_supply_presentation != null:
		card_supply_presentation.reset_for_committed_session()
	reset_public_log()
	reset_visual_cues()
	var query_ports := _table_presentation_query_ports_node()
	if query_ports != null:
		query_ports.reset_state()
	var scheduler := _scheduler_node()
	if scheduler != null:
		scheduler.sync_candidates([])
	var sushi_track := _commodity_sushi_track_runtime_service_node()
	if sushi_track != null:
		sushi_track.reset_projection_state()
	var weather_presentation: Dictionary = _weather_runtime_controller_node().call("commit_new_session_presentation")
	request_table_presentation_refresh(&"full", &"session_start_committed")
	_new_session_presentation_refresh_count += 1
	var rng_after := _run_rng_service_node().capture_plan_checkpoint()
	var market_after: Dictionary = _product_market_runtime_controller_node().call("to_save_data")
	var weather_after: Dictionary = _weather_runtime_controller_node().call("to_save_data")
	var rng_delta := int(rng_after.get("draw_count", 0)) - int(rng_before.get("draw_count", 0))
	var gameplay_mutation_count := int(market_after != market_before) + int(weather_after != weather_before)
	var committed := bool(weather_presentation.get("committed", false)) and rng_delta == 0 and gameplay_mutation_count == 0
	_last_new_session_commit_only_receipt = {
		"committed": committed,
		"reason_code": "new_session_side_effects_committed" if committed else "new_session_commit_only_invariant_failed",
		"player_count": int(plan.get("player_count", 0)),
		"rng_draw_delta": rng_delta,
		"gameplay_mutation_count": gameplay_mutation_count,
		"weather_presentation": weather_presentation.duplicate(true),
	}
	return _last_new_session_commit_only_receipt.duplicate(true)


func set_new_session_test_fault_stage(stage: String) -> void:
	_new_session_test_fault_stage = stage.strip_edges()


func new_session_start_debug_snapshot() -> Dictionary:
	return {
		"commit_side_effect_count": _new_session_commit_side_effect_count,
		"presentation_refresh_count": _new_session_presentation_refresh_count,
		"last_commit_only_receipt": _last_new_session_commit_only_receipt.duplicate(true),
		"test_fault_stage": _new_session_test_fault_stage,
	}


func _new_session_fault(stage: String) -> bool:
	return not _new_session_test_fault_stage.is_empty() and _new_session_test_fault_stage == stage


func _new_session_saved_owners() -> Array:
	return [
		{"owner_id": "selection", "owner": _table_selection_state_node()},
		{"owner_id": "target_choice", "owner": _card_target_choice_runtime_controller_node()},
		{"owner_id": "product_market", "owner": _product_market_runtime_controller_node(), "restore_method": "restore_new_session_checkpoint"},
		{"owner_id": "city_gdp", "owner": _city_gdp_derivative_runtime_controller_node(), "restore_method": "restore_new_session_checkpoint"},
		{"owner_id": "route_network", "owner": _route_network_runtime_controller_node()},
		{"owner_id": "region_infrastructure", "owner": _region_infrastructure_runtime_controller_node()},
		{"owner_id": "commodity_flow", "owner": _commodity_flow_runtime_controller_node()},
		{"owner_id": "player_mana", "owner": _player_mana_runtime_controller_node()},
		{"owner_id": "commodity_inventory", "owner": _commodity_card_inventory_runtime_controller_node()},
		{"owner_id": "organization", "owner": _player_organization_runtime_controller_node()},
		{"owner_id": "bankruptcy", "owner": _bankruptcy_neutral_estate_runtime_controller_node()},
		{"owner_id": "victory", "owner": _victory_control_runtime_controller_node()},
		{"owner_id": "monster", "owner": _monster_runtime_controller_node()},
		{"owner_id": "military", "owner": _military_runtime_controller_node()},
		{"owner_id": "weather", "owner": _weather_runtime_controller_node()},
		{"owner_id": "purchase", "owner": _purchase_node()},
		{"owner_id": "resolution_execution", "owner": _card_resolution_execution_node()},
		{"owner_id": "resolution_history", "owner": _card_resolution_history_runtime_service_node()},
		{"owner_id": "resolution_runtime", "owner": _card_resolution_runtime_controller_node()},
		{"owner_id": "region_supply", "owner": _region_supply_runtime_controller_node()},
	]


func _new_session_region_definitions(district_rows: Array) -> Array:
	var result: Array = []
	for district_index in range(district_rows.size()):
		if not (district_rows[district_index] is Dictionary):
			continue
		var district: Dictionary = district_rows[district_index]
		var neighbor_ids: Array = []
		for neighbor_variant in (district.get("neighbors", []) as Array):
			var neighbor_index := int(neighbor_variant)
			if neighbor_index >= 0 and neighbor_index < district_rows.size() and district_rows[neighbor_index] is Dictionary:
				neighbor_ids.append(str((district_rows[neighbor_index] as Dictionary).get("region_id", "region.%03d" % neighbor_index)))
		result.append({
			"region_id": str(district.get("region_id", "region.%03d" % district_index)),
			"terrain_id": str(district.get("terrain", "unknown")),
			"neighbor_region_ids": neighbor_ids,
			"legacy_index": district_index,
		})
	return result


func _new_session_region_supply_inputs(plan: Dictionary) -> Dictionary:
	var district_rows: Array = plan.get("districts", [])
	var region_descriptors: Array = []
	for district_index in range(district_rows.size()):
		if not (district_rows[district_index] is Dictionary):
			return {"valid": false, "reason_code": "new_session_supply_district_invalid"}
		var district: Dictionary = district_rows[district_index]
		region_descriptors.append({
			"region_id": str(district.get("region_id", "region.%03d" % district_index)),
			"region_index": district_index,
			"display_name": str(district.get("name", "区域%d" % (district_index + 1))),
			"terrain": str(district.get("terrain", "")),
			"active": not bool(district.get("destroyed", false)),
			"destroyed": bool(district.get("destroyed", false)),
			"mode_tags": (district.get("mode_tags", []) as Array).duplicate() if district.get("mode_tags", []) is Array else [],
		})
	var card_descriptors: Array = []
	for card_id_variant in (plan.get("card_pool", []) as Array):
		var descriptor := _region_supply_card_descriptor(str(card_id_variant))
		if not descriptor.is_empty():
			card_descriptors.append(descriptor)
	return {"valid": not region_descriptors.is_empty() and not card_descriptors.is_empty(), "reason_code": "new_session_supply_inputs_ready", "regions": region_descriptors, "cards": card_descriptors, "slot_count": 4}


func reset_state() -> void:
	_configured = false
	_last_v06_player_binding_result = {
		"ready": false,
		"reason_code": "production_players_not_bound",
	}
	var presentation_query_ports := _table_presentation_query_ports_node()
	if presentation_query_ports != null:
		presentation_query_ports.reset_state()
	var scheduler := _scheduler_node()
	if scheduler != null:
		scheduler.sync_candidates([])
	var target_choice := _card_target_choice_runtime_controller_node()
	if target_choice != null:
		target_choice.reset_state()
	var world_clock := _world_effective_clock_runtime_controller_node()
	if world_clock != null and world_clock.has_method("reset_state"):
		world_clock.call("reset_state")
	var card_market_pricing := _card_market_pricing_runtime_controller_node()
	if card_market_pricing != null and card_market_pricing.has_method("reset_state"):
		card_market_pricing.call("reset_state")
	var ai_controller := _ai_runtime_controller_node()
	if ai_controller != null and ai_controller.has_method("reset_state"):
		ai_controller.call("reset_state")
	var monster_controller := _monster_runtime_controller_node()
	if monster_controller != null and monster_controller.has_method("reset_state"):
		monster_controller.call("reset_state")
	var military_controller := _military_runtime_controller_node()
	if military_controller != null and military_controller.has_method("reset_state"):
		military_controller.call("reset_state")
	var weather_controller := _weather_runtime_controller_node()
	if weather_controller != null and weather_controller.has_method("reset_state"):
		weather_controller.call("reset_state")
	var route_network_controller := _route_network_runtime_controller_node()
	if route_network_controller != null and route_network_controller.has_method("reset_state"):
		route_network_controller.call("reset_state")
	var commodity_flow_controller := _commodity_flow_runtime_controller_node()
	if commodity_flow_controller != null and commodity_flow_controller.has_method("reset_state"):
		commodity_flow_controller.call("reset_state")
	var player_mana_controller := _player_mana_runtime_controller_node()
	if player_mana_controller != null and player_mana_controller.has_method("reset_state"):
		player_mana_controller.call("reset_state")
	var commodity_card_inventory := _commodity_card_inventory_runtime_controller_node()
	if commodity_card_inventory != null and commodity_card_inventory.has_method("reset_state"):
		commodity_card_inventory.call("reset_state")
	var commodity_sushi_track := _commodity_sushi_track_runtime_service_node()
	if commodity_sushi_track != null:
		commodity_sushi_track.reset_projection_state()
	_bind_region_supply_source_port()
	var organization_owner := _player_organization_runtime_controller_node()
	if organization_owner != null and organization_owner.has_method("reset_state"):
		organization_owner.call("reset_state")
	var core_economic_adapter := _core_economic_card_runtime_adapter_v06_node()
	if core_economic_adapter != null and core_economic_adapter.has_method("reset_state"):
		core_economic_adapter.call("reset_state")
	var commodity_flow_bridge := _commodity_flow_world_bridge_node()
	if commodity_flow_bridge != null and commodity_flow_bridge.has_method("reset_state"):
		commodity_flow_bridge.call("reset_state")
	var bankruptcy_estate := _bankruptcy_neutral_estate_runtime_controller_node()
	if bankruptcy_estate != null and bankruptcy_estate.has_method("reset_state"):
		bankruptcy_estate.call("reset_state")
	var victory_controller := _victory_control_runtime_controller_node()
	if victory_controller != null and victory_controller.has_method("reset_state"):
		victory_controller.call("reset_state")
	var victory_bridge := _victory_control_world_bridge_node()
	if victory_bridge != null and victory_bridge.has_method("reset_state"):
		victory_bridge.call("reset_state")
	var session := _session_node()
	if session != null and session.has_method("reset_state"):
		session.call("reset_state")
	var purchase := _purchase_node()
	if purchase != null and purchase.has_method("reset_state"):
		purchase.call("reset_state")
	var card_inventory := _card_inventory_node()
	if card_inventory != null and card_inventory.has_method("reset_state"):
		card_inventory.call("reset_state")
	var card_resolution_queue := _card_resolution_queue_node()
	if card_resolution_queue != null and card_resolution_queue.has_method("reset_state"):
		card_resolution_queue.call("reset_state")
	var card_resolution_execution := _card_resolution_execution_node()
	if card_resolution_execution != null and card_resolution_execution.has_method("reset_state"):
		card_resolution_execution.call("reset_state")
	var economy_product_route_effect := _card_economy_product_route_effect_node()
	if economy_product_route_effect != null and economy_product_route_effect.has_method("reset_state"):
		economy_product_route_effect.call("reset_state")
	var hand_interaction := _player_hand_interaction_node()
	if hand_interaction != null and hand_interaction.has_method("reset_state"):
		hand_interaction.call("reset_state")
	var purchase_settlement := _purchase_settlement_node()
	if purchase_settlement != null and purchase_settlement.has_method("reset_state"):
		purchase_settlement.call("reset_state")
func open_district_purchase_window(player_index: int, district_index: int, qualification_snapshot: Dictionary) -> Dictionary:
	var purchase := _purchase_node()
	if purchase == null or not purchase.has_method("open_window"):
		return {}
	var value: Variant = purchase.call("open_window", player_index, district_index, qualification_snapshot)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func close_district_purchase_window(player_index: int, reason: String = "closed") -> Dictionary:
	var purchase := _purchase_node()
	if purchase == null or not purchase.has_method("close_window"):
		return {}
	var value: Variant = purchase.call("close_window", player_index, reason)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func district_purchase_window(player_index: int) -> Dictionary:
	var purchase := _purchase_node()
	if purchase == null or not purchase.has_method("active_window"):
		return {}
	var value: Variant = purchase.call("active_window", player_index)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func district_purchase_window_active(player_index: int, district_index: int = -1) -> bool:
	var purchase := _purchase_node()
	return purchase != null and purchase.has_method("is_window_active") and bool(purchase.call("is_window_active", player_index, district_index))


func plan_district_purchase_settlement(request_snapshot: Dictionary) -> Dictionary:
	var service := _purchase_settlement_node()
	if service == null or not service.has_method("plan_purchase"):
		return {"status": "rejected", "ready": false, "reason": "settlement_service_missing"}
	var value: Variant = service.call("plan_purchase", request_snapshot)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func commit_district_purchase_settlement(player_state: Dictionary, current_facts: Dictionary, plan: Dictionary) -> Dictionary:
	var service := _purchase_settlement_node()
	if service == null or not service.has_method("commit_purchase"):
		return {"committed": false, "reason": "settlement_service_missing"}
	var value: Variant = service.call("commit_purchase", player_state, current_facts, plan)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func validate_district_purchase_discard(request_snapshot: Dictionary, discard_slot: int) -> Dictionary:
	var service := _purchase_settlement_node()
	if service == null or not service.has_method("validate_discard"):
		return {"valid": false, "reason": "settlement_service_missing"}
	var value: Variant = service.call("validate_discard", request_snapshot, discard_slot)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func plan_card_inventory_receive(inventory_snapshot: Dictionary) -> Dictionary:
	var service := _card_inventory_node()
	if service == null or not service.has_method("plan_receive"):
		return {"status": "rejected", "ready": false, "reason": "inventory_service_missing"}
	var value: Variant = service.call("plan_receive", inventory_snapshot)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func commit_card_inventory_receive(player_state: Dictionary, current_facts: Dictionary, plan: Dictionary) -> Dictionary:
	var service := _card_inventory_node()
	if service == null or not service.has_method("commit_receive"):
		return {"committed": false, "reason": "inventory_service_missing"}
	var value: Variant = service.call("commit_receive", player_state, current_facts, plan)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func card_inventory_discardable_slots(inventory_snapshot: Dictionary) -> Array:
	var service := _card_inventory_node()
	if service == null or not service.has_method("discardable_slots"):
		return []
	var value: Variant = service.call("discardable_slots", inventory_snapshot)
	return (value as Array).duplicate() if value is Array else []


func plan_card_inventory_remove(request_snapshot: Dictionary) -> Dictionary:
	return _card_inventory_dictionary_call("plan_remove", [request_snapshot])


func commit_card_inventory_remove(player_state: Dictionary, current_facts: Dictionary, plan: Dictionary) -> Dictionary:
	return _card_inventory_dictionary_call("commit_remove", [player_state, current_facts, plan])


func plan_card_inventory_lock(request_snapshot: Dictionary) -> Dictionary:
	return _card_inventory_dictionary_call("plan_lock", [request_snapshot])


func commit_card_inventory_lock(player_state: Dictionary, current_facts: Dictionary, plan: Dictionary) -> Dictionary:
	return _card_inventory_dictionary_call("commit_lock", [player_state, current_facts, plan])


func plan_card_inventory_transfer(request_snapshot: Dictionary) -> Dictionary:
	return _card_inventory_dictionary_call("plan_transfer", [request_snapshot])


func commit_card_inventory_transfer(source_state: Dictionary, target_state: Dictionary, current_facts: Dictionary, plan: Dictionary) -> Dictionary:
	return _card_inventory_dictionary_call("commit_transfer", [source_state, target_state, current_facts, plan])


func plan_card_inventory_queue_commit(request_snapshot: Dictionary) -> Dictionary:
	return _card_inventory_dictionary_call("plan_queue_commit", [request_snapshot])


func commit_card_inventory_queue_commit(player_state: Dictionary, current_facts: Dictionary, plan: Dictionary) -> Dictionary:
	return _card_inventory_dictionary_call("commit_queue_commit", [player_state, current_facts, plan])


func card_inventory_debug() -> Dictionary:
	return _card_inventory_debug_snapshot()


func plan_card_resolution_queue_submission(request_snapshot: Dictionary, facts: Dictionary) -> Dictionary:
	var queue_facts := facts.duplicate(true)
	var queue_plan := _card_resolution_queue_dictionary_call("plan_submission", [request_snapshot, queue_facts])
	if not bool(queue_plan.get("accepted", false)):
		return queue_plan
	var entry := (queue_plan.get("entry", {}) as Dictionary).duplicate(true) if queue_plan.get("entry", {}) is Dictionary else {}
	var skill := (request_snapshot.get("skill", {}) as Dictionary).duplicate(true) if request_snapshot.get("skill", {}) is Dictionary else {}
	var asset_cost_variant: Variant = request_snapshot.get("asset_cost", skill.get("asset_cost", {}))
	var asset_cost: Dictionary = (asset_cost_variant as Dictionary).duplicate(true) if asset_cost_variant is Dictionary else {}
	var resolution_id := int(entry.get("resolution_id", entry.get("queued_order", -1)))
	var window_sequence := int(entry.get("window_sequence", 0))
	var transaction_id := "card_asset.%d.%d" % [window_sequence, resolution_id]
	var mana := _player_mana_runtime_controller_node()
	if mana == null or not mana.has_method("plan_reservation"):
		return {"accepted": false, "reason": "player_mana_runtime_missing"}
	var mana_plan_variant: Variant = mana.call("plan_reservation", {
		"transaction_id": transaction_id,
		"player_index": int(request_snapshot.get("player_index", -1)),
		"asset_cost": asset_cost,
		"generic_asset_allocation": (request_snapshot.get("generic_asset_allocation", {}) as Dictionary).duplicate(true) if request_snapshot.get("generic_asset_allocation", {}) is Dictionary else {},
	})
	var mana_plan: Dictionary = (mana_plan_variant as Dictionary).duplicate(true) if mana_plan_variant is Dictionary else {}
	if not bool(mana_plan.get("accepted", false)):
		return {
			"accepted": false,
			"reason": str(mana_plan.get("reason", "asset_reservation_rejected")),
			"asset_status": mana_plan,
			"expected_revision": int(queue_plan.get("expected_revision", -1)),
		}
	entry["asset_reservation_id"] = str(mana_plan.get("transaction_id", ""))
	entry["asset_cost"] = (mana_plan.get("asset_cost", {}) as Dictionary).duplicate(true) if mana_plan.get("asset_cost", {}) is Dictionary else {}
	entry["asset_debit"] = (mana_plan.get("asset_debit", {}) as Dictionary).duplicate(true) if mana_plan.get("asset_debit", {}) is Dictionary else {}
	entry["asset_reservation_required"] = bool(mana_plan.get("required", false))
	queue_plan["entry"] = entry
	queue_plan["asset_reservation_plan"] = mana_plan
	queue_plan["asset_status"] = {
		"satisfied": true,
		"required": bool(mana_plan.get("required", false)),
		"asset_cost": entry["asset_cost"],
		"asset_debit": entry["asset_debit"],
	}
	return queue_plan


func commit_card_resolution_queue_submission(plan: Dictionary, commit_receipt: Dictionary) -> Dictionary:
	var mana := _player_mana_runtime_controller_node()
	var mana_plan := (plan.get("asset_reservation_plan", {}) as Dictionary).duplicate(true) if plan.get("asset_reservation_plan", {}) is Dictionary else {}
	if mana == null or not mana.has_method("commit_reservation"):
		return {"committed": false, "reason": "player_mana_runtime_missing"}
	var mana_commit_variant: Variant = mana.call("commit_reservation", mana_plan)
	var mana_commit: Dictionary = (mana_commit_variant as Dictionary).duplicate(true) if mana_commit_variant is Dictionary else {}
	if not bool(mana_commit.get("authorized", false)):
		return {"committed": false, "reason": str(mana_commit.get("reason", "asset_reservation_commit_failed")), "asset_receipt": mana_commit}
	var external_receipt := commit_receipt.duplicate(true)
	external_receipt["asset_authorized"] = true
	var queue_commit := _card_resolution_queue_dictionary_call("commit_submission", [plan, external_receipt])
	if not bool(queue_commit.get("committed", false)):
		var reservation_id := str(mana_commit.get("transaction_id", ""))
		if not reservation_id.is_empty() and mana.has_method("release_reservation"):
			mana.call("release_reservation", reservation_id, "queue_commit_failed")
		queue_commit["asset_receipt"] = mana_commit
		return queue_commit
	queue_commit["asset_receipt"] = mana_commit
	queue_commit["asset_reservation_id"] = str(mana_commit.get("transaction_id", ""))
	return queue_commit


func settle_card_mana_reservation(entry: Dictionary, execution_receipt: Dictionary) -> Dictionary:
	var transaction_id := str(entry.get("asset_reservation_id", ""))
	if transaction_id.is_empty():
		return {"settled": true, "required": false, "transaction_id": ""}
	var mana := _player_mana_runtime_controller_node()
	if mana == null:
		return {"settled": false, "reason": "player_mana_runtime_missing", "transaction_id": transaction_id}
	if bool(execution_receipt.get("resolved", false)) and mana.has_method("consume_reservation"):
		var consumed: Variant = mana.call("consume_reservation", transaction_id, execution_receipt)
		return (consumed as Dictionary).duplicate(true) if consumed is Dictionary else {}
	if mana.has_method("release_reservation"):
		var released: Variant = mana.call("release_reservation", transaction_id, str(execution_receipt.get("reason", "card_not_resolved")))
		return (released as Dictionary).duplicate(true) if released is Dictionary else {}
	return {"settled": false, "reason": "player_mana_settlement_api_missing", "transaction_id": transaction_id}


func player_mana_availability(player_index: int) -> Dictionary:
	var mana := _player_mana_runtime_controller_node()
	var value: Variant = mana.call("availability_snapshot", player_index) if mana != null and mana.has_method("availability_snapshot") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func player_mana_to_save_data() -> Dictionary:
	var mana := _player_mana_runtime_controller_node()
	var value: Variant = mana.call("to_save_data") if mana != null and mana.has_method("to_save_data") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func apply_player_mana_save_data(data: Dictionary) -> Dictionary:
	var mana := _player_mana_runtime_controller_node()
	var value: Variant = mana.call("apply_save_data", data) if mana != null and mana.has_method("apply_save_data") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func player_mana_debug() -> Dictionary:
	return _player_mana_runtime_debug_snapshot()


func card_resolution_queue_state() -> Dictionary:
	return _card_resolution_queue_dictionary_call("queue_state_snapshot", [])


func card_resolution_queue_legacy_save_snapshot() -> Dictionary:
	return _card_resolution_queue_dictionary_call("to_legacy_save_snapshot", [])


func apply_card_resolution_queue_legacy_save_snapshot(data: Dictionary) -> void:
	var service := _card_resolution_queue_node()
	if service != null and service.has_method("apply_legacy_save_snapshot"):
		service.call("apply_legacy_save_snapshot", data)


func card_resolution_queue_debug() -> Dictionary:
	return _card_resolution_queue_debug_snapshot()


func compose_action_result_v1(source: Dictionary) -> Dictionary:
	var service := _action_result_presentation_node()
	var value: Variant = service.call("compose", source) if service != null and service.has_method("compose") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func plan_card_resolution_execution(request_snapshot: Dictionary) -> Dictionary:
	return _card_resolution_execution_dictionary_call("plan_execution", [request_snapshot])


func advance_card_resolution_execution(transaction: Dictionary, receipt: Dictionary) -> Dictionary:
	return _card_resolution_execution_dictionary_call("advance_execution", [transaction, receipt])


func finalize_card_resolution_execution(transaction: Dictionary) -> Dictionary:
	return _card_resolution_execution_dictionary_call("finalize_execution", [transaction])


func recover_card_resolution_execution(active_entry: Dictionary, facts: Dictionary = {}) -> Dictionary:
	return _card_resolution_execution_dictionary_call("recover_from_active", [active_entry, facts])


func card_resolution_execution_debug() -> Dictionary:
	return _card_resolution_execution_debug_snapshot()


func plan_card_economy_product_route_effect(request_snapshot: Dictionary) -> Dictionary:
	return _card_economy_product_route_effect_dictionary_call("plan_effect", [request_snapshot])


func finalize_card_economy_product_route_effect(plan: Dictionary, receipt: Dictionary) -> Dictionary:
	return _card_economy_product_route_effect_dictionary_call("finalize_effect", [plan, receipt])


func card_economy_product_route_effect_debug() -> Dictionary:
	return _card_economy_product_route_effect_debug_snapshot()


func calculate_card_economy_product_route_formula(formula_id: String, input_snapshot: Dictionary) -> Dictionary:
	return _card_economy_product_route_formula_dictionary_call("calculate", [formula_id, input_snapshot])


func card_economy_product_route_formula_debug() -> Dictionary:
	return _card_economy_product_route_formula_debug_snapshot()


func plan_player_hand_interaction(request_snapshot: Dictionary) -> Dictionary:
	var service := _player_hand_interaction_node()
	if service == null or not service.has_method("plan_interaction"):
		return {"status": "rejected", "ready": false, "reason": "hand_interaction_service_missing"}
	var value: Variant = service.call("plan_interaction", request_snapshot)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func commit_player_hand_interaction(actor_state: Dictionary, target_state: Dictionary, current_facts: Dictionary, plan: Dictionary) -> Dictionary:
	var service := _player_hand_interaction_node()
	if service == null or not service.has_method("commit_interaction"):
		return {"committed": false, "reason": "hand_interaction_service_missing"}
	var value: Variant = service.call("commit_interaction", actor_state, target_state, current_facts, plan)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func player_hand_interaction_debug() -> Dictionary:
	return _player_hand_interaction_debug_snapshot()


func _card_inventory_dictionary_call(method_name: StringName, arguments: Array) -> Dictionary:
	var service := _card_inventory_node()
	if service == null or not service.has_method(method_name):
		return {"committed": false, "status": "rejected", "reason": "inventory_service_missing"}
	var value: Variant = service.callv(method_name, arguments)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _card_resolution_queue_dictionary_call(method_name: StringName, arguments: Array) -> Dictionary:
	var service := _card_resolution_queue_node()
	if service == null or not service.has_method(method_name):
		return {"committed": false, "accepted": false, "reason": "queue_service_missing"}
	var value: Variant = service.callv(method_name, arguments)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _card_resolution_execution_dictionary_call(method_name: StringName, arguments: Array) -> Dictionary:
	var service := _card_resolution_execution_node()
	if service == null or not service.has_method(method_name):
		return {"completed": false, "ready": false, "status": "rejected", "reason": "execution_service_missing"}
	var value: Variant = service.callv(method_name, arguments)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _card_economy_product_route_effect_dictionary_call(method_name: StringName, arguments: Array) -> Dictionary:
	var service := _card_economy_product_route_effect_node()
	if service == null or not service.has_method(method_name):
		return {"dispatched": false, "resolved": false, "ready": false, "supported": false, "status": "rejected", "reason": "effect_family_service_missing"}
	var value: Variant = service.callv(method_name, arguments)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _card_economy_product_route_formula_dictionary_call(method_name: StringName, arguments: Array) -> Dictionary:
	var service := _card_economy_product_route_formula_node()
	if service == null or not service.has_method(method_name):
		return {"ok": false, "reason": "effect_formula_service_missing"}
	var value: Variant = service.callv(method_name, arguments)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func district_purchase_settlement_debug() -> Dictionary:
	return _purchase_settlement_debug_snapshot()


func mark_district_supply_revision(player_index: int, district_index: int, revision: String) -> Dictionary:
	var purchase := _purchase_node()
	if purchase == null or not purchase.has_method("mark_supply_revision"):
		return {}
	var value: Variant = purchase.call("mark_supply_revision", player_index, district_index, revision)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func acknowledge_district_purchase_selection(player_index: int, district_index: int, card_id: String, supply_revision: String) -> Dictionary:
	var purchase := _purchase_node()
	if purchase == null or not purchase.has_method("acknowledge_card_selection"):
		return {}
	var value: Variant = purchase.call("acknowledge_card_selection", player_index, district_index, card_id, supply_revision)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func reserve_district_purchase_discard(request_snapshot: Dictionary) -> Dictionary:
	var purchase := _purchase_node()
	if purchase == null or not purchase.has_method("reserve_pending_discard"):
		return {}
	var value: Variant = purchase.call("reserve_pending_discard", request_snapshot)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func resolve_district_purchase_discard(result_snapshot: Dictionary) -> Dictionary:
	var purchase := _purchase_node()
	if purchase == null or not purchase.has_method("resolve_pending_discard"):
		return {}
	var value: Variant = purchase.call("resolve_pending_discard", result_snapshot)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func district_purchase_legacy_save_snapshot(player_index: int) -> Dictionary:
	var purchase := _purchase_node()
	if purchase == null or not purchase.has_method("to_legacy_save_snapshot"):
		return {}
	var value: Variant = purchase.call("to_legacy_save_snapshot", player_index)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func apply_district_purchase_legacy_save_snapshot(snapshot: Dictionary, current_game_time: float) -> Dictionary:
	var purchase := _purchase_node()
	if purchase == null or not purchase.has_method("apply_legacy_save_snapshot"):
		return {}
	var value: Variant = purchase.call("apply_legacy_save_snapshot", snapshot, current_game_time)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func restore_district_purchase_legacy_state(snapshot: Dictionary, current_game_time: float, pending_discard: Dictionary = {}) -> Dictionary:
	var restored := apply_district_purchase_legacy_save_snapshot(snapshot, current_game_time)
	if not pending_discard.is_empty():
		var migrated_pending := pending_discard.duplicate(true)
		migrated_pending["card_id"] = str(pending_discard.get("skill_name", pending_discard.get("card_id", "")))
		reserve_district_purchase_discard(migrated_pending)
	return restored


func district_purchase_private_ui_snapshot(viewer_index: int) -> Dictionary:
	var purchase := _purchase_node()
	if purchase == null or not purchase.has_method("private_ui_snapshot"):
		return {}
	var value: Variant = purchase.call("private_ui_snapshot", viewer_index)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func install_commodity(request: Dictionary) -> Dictionary:
	var controller := _commodity_flow_runtime_controller_node()
	var bridge := _commodity_flow_world_bridge_node()
	if controller == null or bridge == null or not controller.has_method("install_commodity") or not bridge.has_method("enriched_installation_request"):
		return {"committed": false, "reason": "commodity_flow_runtime_missing"}
	var enriched_variant: Variant = bridge.call("enriched_installation_request", request)
	var enriched: Dictionary = (enriched_variant as Dictionary).duplicate(true) if enriched_variant is Dictionary else {}
	if enriched.is_empty():
		return {"committed": false, "reason": "commodity_installation_facts_missing"}
	var value: Variant = controller.call("install_commodity", enriched)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func configure_commodity_card_belt(revision: int, entries: Array) -> Dictionary:
	var value: Variant = commodity_card_inventory_runtime_call("configure_belt", [revision, entries])
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func claim_commodity_card(
	actor_id: String,
	source_item_id: String,
	expected_player_revision: int,
	expected_belt_revision: int,
	transaction_id: String
) -> Dictionary:
	var value: Variant = commodity_card_inventory_runtime_call("claim_belt_card", [
		actor_id,
		source_item_id,
		expected_player_revision,
		expected_belt_revision,
		transaction_id,
	])
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func merge_commodity_cards(
	actor_id: String,
	first_slot: int,
	second_slot: int,
	expected_player_revision: int,
	transaction_id: String
) -> Dictionary:
	var value: Variant = commodity_card_inventory_runtime_call("manual_merge", [
		actor_id,
		first_slot,
		second_slot,
		expected_player_revision,
		transaction_id,
	])
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func play_commodity_card(
	actor_id: String,
	slot_index: int,
	target_context: Dictionary,
	expected_player_revision: int,
	transaction_id: String
) -> Dictionary:
	var value: Variant = commodity_card_inventory_runtime_call("play_commodity_card", [
		actor_id,
		slot_index,
		target_context,
		expected_player_revision,
		transaction_id,
	])
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func commodity_card_inventory_to_save_data() -> Dictionary:
	var value: Variant = commodity_card_inventory_runtime_call("to_save_data")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func apply_commodity_card_inventory_save_data(data: Dictionary) -> Dictionary:
	var value: Variant = commodity_card_inventory_runtime_call("apply_save_data", [data])
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func advance_commodity_flow(delta_seconds: float, blocking_snapshot: Dictionary = {}) -> Dictionary:
	var ports := _runtime_world_ports_node()
	return _runtime_economy_port_node().advance_commodity_flow(delta_seconds, blocking_snapshot) if ports != null and _runtime_economy_port_node() != null else {
		"advanced": false,
		"reason": "runtime_economy_port_unavailable",
		"receipt_count": 0,
	}


func advance_runtime_commodity_flow(delta_seconds: float) -> bool:
	var ports := _runtime_world_ports_node()
	return _runtime_economy_port_node().advance_runtime_commodity_flow(delta_seconds) if ports != null and _runtime_economy_port_node() != null else false


func commodity_flow_to_save_data() -> Dictionary:
	var controller := _commodity_flow_runtime_controller_node()
	var value: Variant = controller.call("to_save_data") if controller != null and controller.has_method("to_save_data") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func apply_commodity_flow_save_data(data: Dictionary) -> Dictionary:
	var controller := _commodity_flow_runtime_controller_node()
	var value: Variant = controller.call("apply_save_data", data) if controller != null and controller.has_method("apply_save_data") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func commodity_flow_installations(include_inactive := false) -> Array:
	var controller := _commodity_flow_runtime_controller_node()
	var value: Variant = controller.call("installations_snapshot", include_inactive) if controller != null and controller.has_method("installations_snapshot") else []
	return (value as Array).duplicate(true) if value is Array else []


func commodity_flow_recent_receipts(viewer_index := -1) -> Array:
	var controller := _commodity_flow_runtime_controller_node()
	var value: Variant = controller.call("recent_sale_receipts_snapshot", viewer_index) if controller != null and controller.has_method("recent_sale_receipts_snapshot") else []
	return (value as Array).duplicate(true) if value is Array else []


func settle_bankruptcy_checkpoint(request: Dictionary) -> Dictionary:
	var controller := _bankruptcy_neutral_estate_runtime_controller_node()
	var value: Variant = controller.call("settle_checkpoint", request) if controller != null and controller.has_method("settle_checkpoint") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func bankruptcy_neutral_estate_public_receipt() -> Dictionary:
	var controller := _bankruptcy_neutral_estate_runtime_controller_node()
	var value: Variant = controller.call("public_receipt") if controller != null and controller.has_method("public_receipt") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func commodity_flow_region_gdp_snapshot(region_id: String) -> Dictionary:
	var controller := _commodity_flow_runtime_controller_node()
	var value: Variant = controller.call("region_gdp_snapshot", region_id) if controller != null and controller.has_method("region_gdp_snapshot") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func commodity_flow_player_region_share_bp(player_index: int, region_id: String) -> int:
	var controller := _commodity_flow_runtime_controller_node()
	return int(controller.call("player_region_gdp_share_basis_points", player_index, region_id)) if controller != null and controller.has_method("player_region_gdp_share_basis_points") else 0


func begin_session(setup_snapshot: Dictionary) -> Dictionary:
	var session := _session_node()
	if session == null or not session.has_method("begin_session"):
		return {}
	var result_variant: Variant = session.call("begin_session", setup_snapshot)
	return (result_variant as Dictionary).duplicate(true) if result_variant is Dictionary else {}


func pause_session() -> void:
	var session := _session_node()
	if session != null and session.has_method("pause_session"):
		session.call("pause_session")


func resume_session() -> void:
	var session := _session_node()
	if session != null and session.has_method("resume_session"):
		session.call("resume_session")


func finish_session(result_summary: Dictionary = {}) -> void:
	var session := _session_node()
	if session != null and session.has_method("finish_session"):
		_drain_ai_business_publications_before_session_finish()
		session.call("finish_session", result_summary)


func _drain_ai_business_publications_before_session_finish() -> void:
	var product_market := _product_market_runtime_controller_node() as ProductMarketRuntimeController
	if product_market != null:
		product_market.retry_pending_ai_business_publications()


func mark_session_dirty(reason: String = "runtime_change") -> void:
	var session := _session_node()
	if session != null and session.has_method("mark_dirty"):
		session.call("mark_dirty", reason)


func request_run_save(path: String, domain_sections: Dictionary) -> Dictionary:
	var session := _session_node()
	if session == null or not session.has_method("request_save"):
		return {"ok": false, "error_code": ERR_UNCONFIGURED, "payload": {}}
	var result_variant: Variant = session.call("request_save", path, domain_sections)
	return (result_variant as Dictionary).duplicate(true) if result_variant is Dictionary else {}


func request_run_load(path: String = "") -> Dictionary:
	var session := _session_node()
	if session == null or not session.has_method("request_load"):
		return {"ok": false, "applied": false, "error_code": ERR_UNCONFIGURED, "reason_code": "session_runtime_unavailable", "summary": "存档：运行时恢复服务不可用。"}
	var result_variant: Variant = session.call("request_load", path)
	return (result_variant as Dictionary).duplicate(true) if result_variant is Dictionary else {}


func inspect_run_save(path: String = "") -> Dictionary:
	var session := _session_node()
	if session == null or not session.has_method("inspect_save"):
		return {"ok": false, "applied": false, "error_code": ERR_UNCONFIGURED, "reason_code": "session_runtime_unavailable", "summary": "存档：运行时恢复服务不可用。"}
	var result_variant: Variant = session.call("inspect_save", path)
	return (result_variant as Dictionary).duplicate(true) if result_variant is Dictionary else {}


func complete_run_load(error_code: int) -> void:
	var session := _session_node()
	if session != null and session.has_method("complete_load"):
		session.call("complete_load", error_code)


func read_run_save(path: String = "") -> Dictionary:
	var session := _session_node()
	if session == null or not session.has_method("read_save"):
		return {"ok": false, "error_code": ERR_UNCONFIGURED, "payload": {}, "exists": false}
	var result_variant: Variant = session.call("read_save", path)
	return (result_variant as Dictionary).duplicate(true) if result_variant is Dictionary else {}


func has_valid_run_save(path: String = "") -> bool:
	var session := _session_node()
	return session != null and session.has_method("has_valid_save") and bool(session.call("has_valid_save", path))


func compose_run_save_payload(domain_sections: Dictionary) -> Dictionary:
	var session := _session_node()
	if session == null or not session.has_method("compose_run_save_payload"):
		return {}
	var payload_variant: Variant = session.call("compose_run_save_payload", domain_sections)
	return (payload_variant as Dictionary).duplicate(true) if payload_variant is Dictionary else {}


func normalize_run_save_payload(payload: Dictionary) -> Dictionary:
	var session := _session_node()
	if session == null or not session.has_method("normalize_run_save_payload"):
		return {}
	var normalized_variant: Variant = session.call("normalize_run_save_payload", payload)
	return (normalized_variant as Dictionary).duplicate(true) if normalized_variant is Dictionary else {}


func validate_run_save_payload(payload: Dictionary) -> Dictionary:
	var session := _session_node()
	if session == null or not session.has_method("validate_run_save_payload"):
		return {"valid": false, "error_code": ERR_UNCONFIGURED}
	var result_variant: Variant = session.call("validate_run_save_payload", payload)
	return (result_variant as Dictionary).duplicate(true) if result_variant is Dictionary else {}


func build_run_save_summary(payload: Dictionary, scoring_rules: Dictionary) -> Dictionary:
	var session := _session_node()
	if session == null or not session.has_method("build_run_save_summary"):
		return {}
	var summary_variant: Variant = session.call("build_run_save_summary", payload, scoring_rules)
	return (summary_variant as Dictionary).duplicate(true) if summary_variant is Dictionary else {}


func run_save_version() -> int:
	var session := _session_node()
	return int(session.call("save_version")) if session != null and session.has_method("save_version") else 0


func default_run_save_path() -> String:
	var session := _session_node()
	return str(session.call("default_save_path")) if session != null and session.has_method("default_save_path") else ""


func codex_navigation_state() -> Dictionary:
	var controller := _codex_navigation_node()
	var value: Variant = controller.call("navigation_snapshot") if controller != null and controller.has_method("navigation_snapshot") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func codex_navigation_domain_state(domain: String) -> Dictionary:
	var controller := _codex_navigation_node()
	var value: Variant = controller.call("domain_state", domain) if controller != null and controller.has_method("domain_state") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func update_codex_navigation_domain(domain: String, patch: Dictionary) -> Dictionary:
	var controller := _codex_navigation_node()
	var value: Variant = controller.call("update_domain", domain, patch) if controller != null and controller.has_method("update_domain") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func codex_navigation_legacy_save_snapshot() -> Dictionary:
	var controller := _codex_navigation_node()
	var value: Variant = controller.call("to_legacy_save_snapshot") if controller != null and controller.has_method("to_legacy_save_snapshot") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func apply_codex_navigation_legacy_save_snapshot(snapshot: Dictionary) -> Dictionary:
	var controller := _codex_navigation_node()
	var value: Variant = controller.call("apply_legacy_save_snapshot", snapshot) if controller != null and controller.has_method("apply_legacy_save_snapshot") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func compose_codex_role_snapshot(source: Dictionary) -> Dictionary:
	var service := _codex_public_snapshot_node()
	var value: Variant = service.call("compose_role", source) if service != null and service.has_method("compose_role") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func role_codex_public_snapshot(role_index: int, presentation: Dictionary = {}) -> Dictionary:
	var service := _role_codex_public_source_node()
	var value: Variant = service.call("compose_snapshot", role_index, presentation) if service != null and service.has_method("compose_snapshot") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func codex_role_route_label(role_card: Dictionary, starting_cash_delta: int = 0) -> String:
	var service := _codex_public_snapshot_node()
	return str(service.call("role_route_label", role_card, starting_cash_delta)) if service != null and service.has_method("role_route_label") else "通用经营"


func monster_codex_public_browser_snapshot(request: Dictionary) -> Dictionary:
	var service := _monster_codex_public_source_node()
	var value: Variant = service.call("compose_browser_source", request) if service != null and service.has_method("compose_browser_source") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func monster_codex_public_detail_snapshot(catalog_index: int, selected: bool = false) -> Dictionary:
	var service := _monster_codex_public_source_node()
	var value: Variant = service.call("compose_snapshot", catalog_index, selected) if service != null and service.has_method("compose_snapshot") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func product_codex_public_browser_snapshot(request: Dictionary) -> Dictionary:
	var service := _product_codex_public_source_node()
	var value: Variant = service.call("compose_browser_snapshot", request) if service != null and service.has_method("compose_browser_snapshot") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func product_codex_public_detail_snapshot(product_name: String, catalog_index: int = -1, selected: bool = false) -> Dictionary:
	var service := _product_codex_public_source_node()
	var value: Variant = service.call("compose_snapshot", product_name, catalog_index, selected) if service != null and service.has_method("compose_snapshot") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func compose_card_codex_browser(source: Dictionary) -> Dictionary:
	var service := _card_codex_public_snapshot_node()
	var value: Variant = service.call("compose_browser", source) if service != null and service.has_method("compose_browser") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func compose_card_codex_detail(source: Dictionary) -> Dictionary:
	var service := _card_codex_public_snapshot_node()
	var value: Variant = service.call("compose_detail", source) if service != null and service.has_method("compose_detail") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func card_codex_public_browser_snapshot(request: Dictionary) -> Dictionary:
	var service := _card_codex_public_source_node()
	var value: Variant = service.call("compose_browser", request) if service != null and service.has_method("compose_browser") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func card_codex_public_card_ids(filter_id: String = "all") -> Array[String]:
	var service := _card_codex_public_source_node()
	if service == null or not service.has_method("ordered_card_ids"):
		return []
	var value: Variant = service.call("ordered_card_ids", filter_id)
	var result: Array[String] = []
	if value is Array:
		for item_variant: Variant in value:
			result.append(str(item_variant))
	return result


func card_codex_public_filter_options() -> Array:
	var service := _card_codex_public_source_node()
	if service == null or not service.has_method("public_filter_options"):
		return []
	var value: Variant = service.call("public_filter_options")
	return (value as Array).duplicate(true) if value is Array else []


func resolve_card_codex_public_id(card_identity: String) -> String:
	var service := _card_codex_public_source_node()
	return str(service.call("resolve_card_id", card_identity)) if service != null and service.has_method("resolve_card_id") else ""


func card_codex_public_detail_snapshot(card_name: String, index: int, total: int) -> Dictionary:
	var service := _card_codex_public_source_node()
	var value: Variant = service.call("compose_detail", card_name, index, total) if service != null and service.has_method("compose_detail") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func region_codex_public_snapshot(region_index: int) -> Dictionary:
	var service := _region_codex_public_source_node()
	var value: Variant = service.call("compose_region", region_index) if service != null and service.has_method("compose_region") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func compose_economy_dashboard_snapshot(source: Dictionary) -> Dictionary:
	var service := _economy_dashboard_public_snapshot_node()
	var value: Variant = service.call("compose", source) if service != null and service.has_method("compose") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func compose_standings_snapshot(source: Dictionary) -> Dictionary:
	var service := _standings_public_snapshot_node()
	var value: Variant = service.call("compose", source) if service != null and service.has_method("compose") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func compose_final_settlement_snapshot(source: Dictionary) -> Dictionary:
	var service := _final_settlement_public_snapshot_node()
	var value: Variant = service.call("compose", source) if service != null and service.has_method("compose") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func compose_card_presentation(source: Dictionary) -> Dictionary:
	var service := _card_presentation_node()
	if service == null or not service.has_method("compose_card"):
		push_error("GameRuntimeCoordinator requires CardPresentationRuntimeService.")
		return {}
	var value: Variant = service.call("compose_card", source)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func compose_card_hand_viewmodel(source: Dictionary) -> Dictionary:
	var service := _card_presentation_node()
	if service == null or not service.has_method("compose_hand_card"):
		return {}
	var value: Variant = service.call("compose_hand_card", source)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func compose_card_resolution_presentation(source: Dictionary) -> Dictionary:
	var service := _card_presentation_node()
	if service == null or not service.has_method("compose_resolution"):
		return {}
	var value: Variant = service.call("compose_resolution", source)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func card_play_world_facts(player_index: int, skill: Dictionary, context: Dictionary = {}) -> Dictionary:
	var bridge := _card_play_world_bridge_node()
	if bridge == null or not bridge.has_method("build_facts"):
		push_error("GameRuntimeCoordinator requires CardPlayEligibilityWorldBridge.")
		return {"player_valid": false, "reason": "world_bridge_missing"}
	var value: Variant = bridge.call("build_facts", player_index, skill, context)
	var facts: Dictionary = (value as Dictionary).duplicate(true) if value is Dictionary else {}
	facts["commodity_color_flow"] = commodity_color_flow_snapshot(player_index)
	facts["player_mana"] = player_mana_availability(player_index)
	return facts


func commodity_color_flow_snapshot(player_index: int) -> Dictionary:
	var controller := _commodity_flow_runtime_controller_node()
	var value: Variant = controller.call("player_color_flow_snapshot", player_index) if controller != null and controller.has_method("player_color_flow_snapshot") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _v06_card_group_runtime_snapshot() -> Dictionary:
	return {
		"ruleset_id": str(RULESET_V06_PROFILE.ruleset_id),
		"card_group": RULESET_V06_PROFILE.card_group_rules(),
		"mana": RULESET_V06_PROFILE.mana_rules(),
		"capabilities": RULESET_V06_PROFILE.capability_rules(),
	}


func card_group_runtime_rules() -> Dictionary:
	return RULESET_V06_PROFILE.card_group_rules().duplicate(true)


func evaluate_card_play(request: Dictionary, facts: Dictionary) -> Dictionary:
	var service := _card_play_eligibility_node()
	if service == null or not service.has_method("evaluate_play"):
		push_error("GameRuntimeCoordinator requires CardPlayEligibilityRuntimeService.")
		return {"allowed": false, "actionable": false, "reason_code": "service_missing"}
	var value: Variant = service.call("evaluate_play", request, facts)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func evaluate_card_hand(requests: Array, facts: Dictionary) -> Array:
	var service := _card_play_eligibility_node()
	var value: Variant = service.call("evaluate_hand", requests, facts) if service != null and service.has_method("evaluate_hand") else []
	return (value as Array).duplicate(true) if value is Array else []


func card_play_requirement_status(request: Dictionary, facts: Dictionary) -> Dictionary:
	var service := _card_play_eligibility_node()
	var value: Variant = service.call("requirement_status", request, facts) if service != null and service.has_method("requirement_status") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func card_play_target_status(request: Dictionary, facts: Dictionary) -> Dictionary:
	var service := _card_play_eligibility_node()
	var value: Variant = service.call("target_status", request, facts) if service != null and service.has_method("target_status") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func audit_card_play_requirements(card_requests: Array) -> Dictionary:
	var service := _card_play_eligibility_node()
	var value: Variant = service.call("audit_requirement_profiles", card_requests) if service != null and service.has_method("audit_requirement_profiles") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func compose_card_play_eligibility(eligibility: Dictionary, card_source: Dictionary = {}) -> Dictionary:
	var service := _card_presentation_node()
	var value: Variant = service.call("compose_play_eligibility", eligibility, card_source) if service != null and service.has_method("compose_play_eligibility") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func card_presentation_icon_legend() -> String:
	var service := _card_presentation_node()
	return str(service.call("icon_legend_text")) if service != null and service.has_method("icon_legend_text") else ""


func card_presentation_category_icon(category_id: String) -> String:
	var service := _card_presentation_node()
	return str(service.call("category_icon", category_id)) if service != null and service.has_method("category_icon") else "□"


func compose_game_table_source(source: Dictionary) -> Dictionary:
	var service := _table_viewmodel_node()
	if service == null or not service.has_method("compose_table_source"):
		push_error("GameRuntimeCoordinator requires GameTableViewModelRuntimeService.")
		return {}
	var value: Variant = service.call("compose_table_source", source)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func compose_game_card_surfaces(source: Dictionary) -> Dictionary:
	var service := _table_viewmodel_node()
	if service == null or not service.has_method("compose_card_surfaces"):
		return {}
	var value: Variant = service.call("compose_card_surfaces", source)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func compose_game_resolution_overlay_badges(source: Dictionary) -> Array:
	var service := _table_viewmodel_node()
	if service == null or not service.has_method("compose_resolution_overlay_badges"):
		return []
	var value: Variant = service.call("compose_resolution_overlay_badges", source)
	return (value as Array).duplicate(true) if value is Array else []


func compose_game_table_snapshot(source: Dictionary) -> Dictionary:
	var service := _table_viewmodel_node()
	if service == null or not service.has_method("compose_table"):
		push_error("GameRuntimeCoordinator requires GameTableViewModelRuntimeService.")
		return {}
	var value: Variant = service.call("compose_table", source)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func district_supply_snapshot_debug() -> Dictionary:
	return _district_supply_snapshot_debug_snapshot()


func debug_snapshot() -> Dictionary:
	var scheduler := _scheduler_node()
	var scheduler_snapshot: Dictionary = {}
	if scheduler != null and scheduler.has_method("debug_snapshot"):
		var snapshot_variant: Variant = scheduler.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			scheduler_snapshot = (snapshot_variant as Dictionary).duplicate(true)
	var session_snapshot := _session_debug_snapshot()
	var purchase_snapshot := _purchase_debug_snapshot()
	var world_clock_snapshot := _node_debug_snapshot(_world_effective_clock_runtime_controller_node())
	var solar_availability_snapshot := _node_debug_snapshot(_solar_availability_runtime_service_node())
	var card_market_pricing_snapshot := _node_debug_snapshot(_card_market_pricing_runtime_controller_node())
	var card_market_bridge_snapshot := _node_debug_snapshot(_card_market_policy_world_bridge_node())
	var card_runtime_catalog_snapshot := _card_runtime_catalog_debug_snapshot()
	var card_definition_bridge_snapshot := _card_runtime_definition_bridge_debug_snapshot()
	var balance_diagnostics_snapshot := _gameplay_balance_diagnostics_debug_snapshot()
	var card_inventory_snapshot := _card_inventory_debug_snapshot()
	var card_resolution_queue_snapshot := _card_resolution_queue_debug_snapshot()
	var action_result_presentation_snapshot := _action_result_presentation_debug_snapshot()
	var card_resolution_execution_snapshot := _card_resolution_execution_debug_snapshot()
	var economy_product_route_effect_snapshot := _card_economy_product_route_effect_debug_snapshot()
	var economy_product_route_formula_snapshot := _card_economy_product_route_formula_debug_snapshot()
	var product_market_runtime_snapshot := _product_market_runtime_debug_snapshot()
	var city_gdp_derivative_runtime_snapshot := _city_gdp_derivative_runtime_debug_snapshot()
	var player_cash_mutation_snapshot := _player_cash_mutation_port_node().debug_snapshot() if _player_cash_mutation_port_node() != null else {}
	var ai_business_cost_cash_snapshot := _ai_business_cost_cash_port_node().debug_snapshot() if _ai_business_cost_cash_port_node() != null else {}
	var route_network_runtime_snapshot := _route_network_runtime_debug_snapshot()
	var commodity_flow_runtime_snapshot := _commodity_flow_runtime_debug_snapshot()
	var commodity_flow_postcommit_snapshot := _commodity_flow_postcommit_debug_snapshot()
	var commodity_flow_world_bridge_snapshot := _commodity_flow_world_bridge_debug_snapshot()
	var bankruptcy_estate_snapshot := _bankruptcy_neutral_estate_runtime_debug_snapshot()
	var bankruptcy_estate_bridge_snapshot := _bankruptcy_neutral_estate_world_bridge_debug_snapshot()
	var player_mana_runtime_snapshot := _player_mana_runtime_debug_snapshot()
	var commodity_card_inventory_snapshot := _commodity_card_inventory_runtime_debug_snapshot()
	var card_player_state_adapter_snapshot := _card_player_state_production_adapter_v06_debug_snapshot()
	var core_economic_adapter_snapshot := _core_economic_card_runtime_adapter_v06_debug_snapshot()
	var player_organization_snapshot := _player_organization_runtime_health_snapshot()
	var hand_interaction_snapshot := _player_hand_interaction_debug_snapshot()
	var purchase_settlement_snapshot := _purchase_settlement_debug_snapshot()
	var codex_navigation_snapshot := _codex_navigation_debug_snapshot()
	var codex_public_snapshot := _codex_public_snapshot_debug_snapshot()
	var monster_codex_public_snapshot := _monster_codex_public_snapshot_debug_snapshot()
	var monster_codex_public_source := _monster_codex_public_source_debug_snapshot()
	var product_codex_public_snapshot := _product_codex_public_snapshot_debug_snapshot()
	var product_codex_public_source := _product_codex_public_source_debug_snapshot()
	var card_codex_public_snapshot := _card_codex_public_snapshot_debug_snapshot()
	var card_codex_public_source := _card_codex_public_source_debug_snapshot()
	var region_codex_public_source := _region_codex_public_source_debug_snapshot()
	var economy_dashboard_public_snapshot := _economy_dashboard_public_snapshot_debug_snapshot()
	var standings_public_snapshot := _standings_public_snapshot_debug_snapshot()
	var final_settlement_public_snapshot := _final_settlement_public_snapshot_debug_snapshot()
	var intel_dossier_public_snapshot := _intel_dossier_public_snapshot_debug_snapshot()
	var district_supply_snapshot := _district_supply_snapshot_debug_snapshot()
	var card_presentation_snapshot := _card_presentation_debug_snapshot()
	var card_play_eligibility_snapshot := _card_play_eligibility_debug_snapshot()
	var card_play_world_bridge_snapshot := _card_play_world_bridge_debug_snapshot()
	var table_viewmodel_snapshot := _table_viewmodel_debug_snapshot()
	var ai_runtime_snapshot := _ai_runtime_debug_snapshot()
	var region_infrastructure_snapshot := _region_infrastructure_runtime_debug_snapshot()
	var region_infrastructure_bridge_snapshot := _region_infrastructure_world_bridge_debug_snapshot()
	var monster_runtime_snapshot := _monster_runtime_debug_snapshot()
	var military_runtime_snapshot := _military_runtime_debug_snapshot()
	var weather_runtime_snapshot := _weather_runtime_debug_snapshot()
	var victory_control_runtime_snapshot := _victory_control_runtime_debug_snapshot()
	var victory_control_world_bridge_snapshot := _victory_control_world_bridge_debug_snapshot()
	var table_presentation_query_ports_snapshot := _table_presentation_query_ports_node().debug_snapshot() if _table_presentation_query_ports_node() != null else {}
	return {
		"coordinator_ready": _configured,
		"coordinator_composition_ready": _composition_ready,
		"v06_production_player_bindings_ready": bool(_last_v06_player_binding_result.get("ready", false)),
		"v06_production_player_bindings": _last_v06_player_binding_result.duplicate(true),
		"coordinator_authoritative": _configured and bool(scheduler_snapshot.get("scheduler_authoritative", false)) and bool(card_runtime_catalog_snapshot.get("service_authoritative", false)) and bool(session_snapshot.get("session_authoritative", false)) and bool(purchase_snapshot.get("controller_authoritative", false)) and bool(card_inventory_snapshot.get("service_authoritative", false)) and bool(card_resolution_queue_snapshot.get("service_authoritative", false)) and bool(card_resolution_execution_snapshot.get("service_authoritative", false)) and bool(economy_product_route_effect_snapshot.get("service_authoritative", false)) and bool(economy_product_route_formula_snapshot.get("service_authoritative", false)) and bool(product_market_runtime_snapshot.get("controller_authoritative", false)) and bool(city_gdp_derivative_runtime_snapshot.get("controller_authoritative", false)) and bool(commodity_flow_runtime_snapshot.get("controller_authoritative", false)) and bool(hand_interaction_snapshot.get("service_authoritative", false)) and bool(purchase_settlement_snapshot.get("service_authoritative", false)) and bool(codex_navigation_snapshot.get("controller_authoritative", false)) and bool(codex_public_snapshot.get("service_authoritative", false)) and bool(monster_codex_public_snapshot.get("service_authoritative", false)) and bool(monster_codex_public_source.get("service_authoritative", false)) and bool(product_codex_public_snapshot.get("service_authoritative", false)) and bool(product_codex_public_source.get("service_authoritative", false)) and bool(card_codex_public_snapshot.get("service_authoritative", false)) and bool(economy_dashboard_public_snapshot.get("service_authoritative", false)) and bool(standings_public_snapshot.get("service_authoritative", false)) and bool(final_settlement_public_snapshot.get("service_authoritative", false)) and bool(intel_dossier_public_snapshot.get("service_authoritative", false)) and bool(district_supply_snapshot.get("service_authoritative", false)) and bool(card_presentation_snapshot.get("service_authoritative", false)) and bool(card_play_eligibility_snapshot.get("service_authoritative", false)) and bool(table_viewmodel_snapshot.get("service_authoritative", false)) and bool(monster_runtime_snapshot.get("controller_authoritative", false)) and bool(military_runtime_snapshot.get("controller_authoritative", false)) and bool(weather_runtime_snapshot.get("controller_authoritative", false)),
		"ruleset_id": _ruleset_id,
		"forced_decision_scheduler": scheduler_snapshot,
		"world_effective_clock": world_clock_snapshot,
		"solar_availability": solar_availability_snapshot,
		"card_market_pricing": card_market_pricing_snapshot,
		"card_market_policy_world_bridge": card_market_bridge_snapshot,
		"card_runtime_catalog": card_runtime_catalog_snapshot,
		"card_runtime_definition_bridge": card_definition_bridge_snapshot,
		"gameplay_balance_diagnostics": balance_diagnostics_snapshot,
		"game_session": session_snapshot,
		"district_purchase": purchase_snapshot,
		"card_inventory": card_inventory_snapshot,
		"card_resolution_queue": card_resolution_queue_snapshot,
		"action_result_presentation": action_result_presentation_snapshot,
		"card_resolution_execution": card_resolution_execution_snapshot,
		"card_economy_product_route_effect": economy_product_route_effect_snapshot,
		"card_economy_product_route_formula": economy_product_route_formula_snapshot,
		"product_market_runtime": product_market_runtime_snapshot,
		"city_gdp_derivative_runtime": city_gdp_derivative_runtime_snapshot,
		"player_cash_mutation_port": player_cash_mutation_snapshot,
		"ai_business_cost_cash_port": ai_business_cost_cash_snapshot,
		"route_network_runtime": route_network_runtime_snapshot,
		"commodity_flow_runtime": commodity_flow_runtime_snapshot,
		"commodity_flow_postcommit": commodity_flow_postcommit_snapshot,
		"commodity_flow_world_bridge": commodity_flow_world_bridge_snapshot,
		"bankruptcy_neutral_estate_runtime": bankruptcy_estate_snapshot,
		"bankruptcy_neutral_estate_world_bridge": bankruptcy_estate_bridge_snapshot,
		"player_mana_runtime": player_mana_runtime_snapshot,
		"commodity_card_inventory_runtime": commodity_card_inventory_snapshot,
		"card_player_state_production_adapter_v06": card_player_state_adapter_snapshot,
		"core_economic_card_runtime_adapter_v06": core_economic_adapter_snapshot,
		"player_organization_runtime": player_organization_snapshot,
		"organization_consumer_readiness": organization_consumer_readiness_snapshot(),
		"player_hand_interaction": hand_interaction_snapshot,
		"district_purchase_settlement": purchase_settlement_snapshot,
		"codex_navigation_runtime": codex_navigation_snapshot,
		"codex_public_snapshot": codex_public_snapshot,
		"monster_codex_public_snapshot": monster_codex_public_snapshot,
		"monster_codex_public_source": monster_codex_public_source,
		"product_codex_public_snapshot": product_codex_public_snapshot,
		"product_codex_public_source": product_codex_public_source,
		"card_codex_public_snapshot": card_codex_public_snapshot,
		"card_codex_public_source": card_codex_public_source,
		"region_codex_public_source": region_codex_public_source,
		"economy_dashboard_public_snapshot": economy_dashboard_public_snapshot,
		"standings_public_snapshot": standings_public_snapshot,
		"final_settlement_public_snapshot": final_settlement_public_snapshot,
		"intel_dossier_public_snapshot": intel_dossier_public_snapshot,
		"district_supply_snapshot": district_supply_snapshot,
		"card_presentation": card_presentation_snapshot,
		"card_play_eligibility": card_play_eligibility_snapshot,
		"card_play_world_bridge": card_play_world_bridge_snapshot,
		"game_table_viewmodel": table_viewmodel_snapshot,
		"ai_runtime": ai_runtime_snapshot,
		"region_infrastructure_runtime": region_infrastructure_snapshot,
		"region_infrastructure_world_bridge": region_infrastructure_bridge_snapshot,
		"monster_runtime": monster_runtime_snapshot,
		"military_runtime": military_runtime_snapshot,
		"weather_runtime": weather_runtime_snapshot,
		"victory_control_runtime": victory_control_runtime_snapshot,
		"victory_control_world_bridge": victory_control_world_bridge_snapshot,
		"table_presentation_query_ports": table_presentation_query_ports_snapshot,
	}


func _scheduler_node() -> Node:
	return get_node_or_null("ForcedDecisionRuntimeScheduler")


func _runtime_loop_node() -> RuntimeLoop:
	return get_node_or_null("RuntimeLoop") as RuntimeLoop


func _runtime_world_ports_node() -> RuntimeWorldPorts:
	return get_node_or_null("RuntimeWorldPorts") as RuntimeWorldPorts


func _runtime_lifecycle_port_node() -> RuntimeLifecyclePort:
	var ports := get_node_or_null("RuntimeWorldPorts")
	return ports.get_node_or_null("RuntimeLifecyclePort") as RuntimeLifecyclePort if ports != null else null


func _runtime_card_port_node() -> RuntimeCardPort:
	var ports := get_node_or_null("RuntimeWorldPorts")
	return ports.get_node_or_null("RuntimeCardPort") as RuntimeCardPort if ports != null else null


func _runtime_economy_port_node() -> RuntimeEconomyPort:
	var ports := get_node_or_null("RuntimeWorldPorts")
	return ports.get_node_or_null("RuntimeEconomyPort") as RuntimeEconomyPort if ports != null else null


func _runtime_actor_port_node() -> RuntimeActorPort:
	var ports := get_node_or_null("RuntimeWorldPorts")
	return ports.get_node_or_null("RuntimeActorPort") as RuntimeActorPort if ports != null else null


func _runtime_monster_port_node() -> RuntimeMonsterPort:
	var ports := get_node_or_null("RuntimeWorldPorts")
	return ports.get_node_or_null("RuntimeMonsterPort") as RuntimeMonsterPort if ports != null else null


func _runtime_presentation_port_node() -> RuntimePresentationPort:
	var ports := get_node_or_null("RuntimeWorldPorts")
	return ports.get_node_or_null("RuntimePresentationPort") as RuntimePresentationPort if ports != null else null


func _runtime_victory_port_node() -> RuntimeVictoryPort:
	var ports := get_node_or_null("RuntimeWorldPorts")
	return ports.get_node_or_null("RuntimeVictoryPort") as RuntimeVictoryPort if ports != null else null


func _card_target_choice_runtime_controller_node() -> CardTargetChoiceRuntimeController:
	return get_node_or_null("CardTargetChoiceRuntimeController") as CardTargetChoiceRuntimeController


func _forced_decision_candidate_sources_node() -> ForcedDecisionCandidateSources:
	return get_node_or_null("ForcedDecisionCandidateSources") as ForcedDecisionCandidateSources


func _wire_forced_decision_candidate_sources() -> void:
	var sources := _forced_decision_candidate_sources_node()
	if sources == null:
		return
	sources.configure(
		_monster_runtime_controller_node() as MonsterRuntimeController,
		_card_resolution_runtime_controller_node(),
		_card_resolution_queue_node(),
		_purchase_node() as DistrictPurchaseRuntimeController,
		_card_target_choice_runtime_controller_node(),
		_scheduler_node() as ForcedDecisionRuntimeScheduler
	)


func _card_resolution_runtime_controller_node() -> CardResolutionRuntimeController:
	return get_node_or_null("CardResolutionRuntimeController") as CardResolutionRuntimeController


func _card_resolution_frame_driver_node() -> CardResolutionFrameDriver:
	return get_node_or_null("CardResolutionFrameDriver") as CardResolutionFrameDriver


func _card_resolution_transition_sink_node() -> CardResolutionTransitionSink:
	return get_node_or_null("CardResolutionTransitionSink") as CardResolutionTransitionSink


func _runtime_command_pipeline_node() -> RuntimeCommandPipeline:
	return get_node_or_null("RuntimeCommandPipeline") as RuntimeCommandPipeline


func _military_monster_damage_command_sink_node() -> MilitaryMonsterDamageCommandSink:
	return get_node_or_null("MilitaryMonsterDamageCommandSink") as MilitaryMonsterDamageCommandSink


func _monster_move_command_sink_node() -> MonsterMoveCommandSink:
	return get_node_or_null("MonsterMoveCommandSink") as MonsterMoveCommandSink


func _monster_action_command_sink_node() -> MonsterActionCommandSink:
	return get_node_or_null("MonsterActionCommandSink") as MonsterActionCommandSink


func _simulation_mutation_authority_node() -> SimulationMutationAuthority:
	return get_node_or_null("RuntimePhaseCoordinator/RuntimeSimulationStep/SimulationMutationAuthority") as SimulationMutationAuthority


func _wire_card_resolution_transition_sink() -> void:
	var sink := _card_resolution_transition_sink_node()
	if sink == null:
		return
	sink.configure(
		_card_resolution_runtime_controller_node(),
		_card_resolution_queue_node() as CardResolutionQueueRuntimeService,
		_world_session_state_node(),
		_card_resolution_execution_node() as CardResolutionExecutionRuntimeService,
		_card_resolution_execution_world_bridge_node() as CardResolutionExecutionWorldBridge,
		_card_resolution_presentation_port_node(),
		_card_play_eligibility_node() as CardPlayEligibilityRuntimeService,
		_monster_runtime_controller_node() as MonsterRuntimeController
	)


func _wire_runtime_command_pipeline() -> void:
	var pipeline := _runtime_command_pipeline_node()
	if pipeline != null:
		pipeline.bind_card_transition_sink(_card_resolution_transition_sink_node())
		var damage_sink := _military_monster_damage_command_sink_node()
		if damage_sink != null:
			damage_sink.configure(_simulation_mutation_authority_node(), _monster_runtime_controller_node() as MonsterRuntimeController)
			pipeline.bind_military_monster_damage_sink(damage_sink)
		var move_sink := _monster_move_command_sink_node()
		if move_sink != null:
			move_sink.configure(_simulation_mutation_authority_node(), _monster_runtime_controller_node() as MonsterRuntimeController)
			pipeline.bind_monster_move_sink(move_sink)
		var action_sink := _monster_action_command_sink_node()
		if action_sink != null:
			action_sink.configure(_simulation_mutation_authority_node(), _monster_runtime_controller_node() as MonsterRuntimeController)
			pipeline.bind_monster_action_sink(action_sink)
		var military := _military_runtime_controller_node()
		if military != null:
			military.set_runtime_command_pipeline(pipeline)
		var monster := _monster_runtime_controller_node() as MonsterRuntimeController
		if monster != null:
			monster.set_runtime_command_pipeline(pipeline)


func _wire_card_resolution_frame_driver() -> void:
	var driver := _card_resolution_frame_driver_node()
	if driver == null:
		return
	driver.configure(
		_card_resolution_runtime_controller_node(),
		_card_resolution_queue_node() as CardResolutionQueueRuntimeService,
		_world_session_state_node(),
		_card_play_eligibility_node() as CardPlayEligibilityRuntimeService,
		_runtime_command_pipeline_node()
	)


func _wire_table_presentation_query_ports() -> void:
	var ports := _table_presentation_query_ports_node()
	if ports == null:
		return
	ports.configure(
		_world_session_state_node(),
		_table_selection_state_node(),
		_scheduler_node() as ForcedDecisionRuntimeScheduler,
		_purchase_node() as DistrictPurchaseRuntimeController,
		_card_target_choice_runtime_controller_node(),
		_card_resolution_runtime_controller_node(),
		_card_resolution_queue_node() as CardResolutionQueueRuntimeService,
		_card_resolution_history_runtime_service_node(),
		_monster_runtime_controller_node() as MonsterRuntimeController,
		_military_runtime_controller_node() as MilitaryRuntimeController,
		_commodity_flow_runtime_controller_node() as CommodityFlowRuntimeController,
		_victory_control_runtime_controller_node() as VictoryControlRuntimeController
	)
	if not ports.victory_presentation_receipt_ready.is_connected(_on_victory_presentation_receipt_ready):
		ports.victory_presentation_receipt_ready.connect(_on_victory_presentation_receipt_ready)


func _wire_table_presentation_source_target() -> void:
	if Engine.is_editor_hint():
		return
	var source := _table_presentation_source_owner_node()
	var viewmodel_query := _table_presentation_viewmodel_query_node()
	var port := _table_presentation_refresh_port_node()
	var game_screen := get_node_or_null(presentation_game_screen_path) as SpaceSyndicateGameScreen if not presentation_game_screen_path.is_empty() else null
	if source == null or viewmodel_query == null or port == null or game_screen == null:
		return
	var developer_target := _developer_balance_presentation_target_node()
	var developer_diagnostics := _gameplay_balance_diagnostics_node() as GameplayBalanceDiagnosticsRuntimeService \
		if developer_target != null and developer_target.is_available() else null
	var district_supply_query := _district_supply_viewer_query_port_node()
	if district_supply_query == null:
		push_error("GameRuntimeCoordinator requires DistrictSupplyViewerQueryPort.")
		return
	district_supply_query.configure(
		_table_presentation_query_ports_node(),
		_table_card_supply_presentation_state_node(),
		_region_supply_runtime_controller_node() as RegionSupplyRuntimeController,
		_purchase_node() as DistrictPurchaseRuntimeController,
		_card_market_pricing_runtime_controller_node() as CardMarketPricingRuntimeController,
		_card_runtime_catalog_node() as CardRuntimeCatalogService,
		_card_presentation_node() as CardPresentationRuntimeService,
		_district_supply_snapshot_node() as DistrictSupplySnapshotService,
		_card_inventory_node() as CardInventoryRuntimeService,
		_session_node() as GameSessionRuntimeController
	)
	viewmodel_query.configure(
		_table_presentation_query_ports_node(),
		_table_selection_state_node(),
		_table_viewmodel_node() as GameTableViewModelRuntimeService,
		_card_runtime_catalog_node() as CardRuntimeCatalogService,
		_card_play_world_bridge_node() as CardPlayEligibilityWorldBridge,
		_card_play_eligibility_node() as CardPlayEligibilityRuntimeService,
		_region_supply_runtime_controller_node() as RegionSupplyRuntimeController,
		_region_infrastructure_runtime_controller_node() as RegionInfrastructureRuntimeController,
		_weather_presentation_runtime_service_node() as WeatherPresentationRuntimeService,
		_victory_control_runtime_controller_node() as VictoryControlRuntimeController,
		_purchase_node() as DistrictPurchaseRuntimeController,
		_card_target_choice_runtime_controller_node(),
		_monster_runtime_controller_node() as MonsterRuntimeController,
		_military_runtime_controller_node() as MilitaryRuntimeController,
		_commodity_flow_runtime_controller_node() as CommodityFlowRuntimeController,
		_player_mana_runtime_controller_node() as PlayerManaRuntimeController,
		_card_resolution_runtime_controller_node(),
		_card_resolution_queue_node() as CardResolutionQueueRuntimeService,
		_card_resolution_history_runtime_service_node(),
		_card_resolution_presentation_port_node(),
		_player_seat_public_source_node() as PlayerSeatPublicSourceService,
		_commodity_sushi_track_runtime_service_node(),
		district_supply_query,
		_v06_runtime_card_catalog() as CardRuntimeCatalogV06Resource
	)
	source.configure(
		_table_presentation_query_ports_node(),
		viewmodel_query,
		developer_diagnostics,
		_visual_cue_runtime_owner_node() as VisualCueRuntimeOwner,
		_solar_availability_runtime_service_node() as SolarAvailabilityRuntimeService,
		_world_effective_clock_runtime_controller_node() as WorldEffectiveClockRuntimeController,
		_weather_presentation_runtime_service_node() as WeatherPresentationRuntimeService
	)
	port.configure(source, game_screen, game_screen.presentation_planet_target(), developer_target, _table_presentation_refresh_scheduler_node())
	_wire_domain_presentation_ports(port, _table_presentation_query_ports_node().public_log_port)
	_wire_table_selection_intent_port()
	_wire_forced_decision_response_paths()


func _wire_table_selection_intent_port() -> void:
	if Engine.is_editor_hint():
		return
	var port := get_node_or_null("TableSelectionIntentPort") as TableSelectionIntentPort
	var game_screen := get_node_or_null(presentation_game_screen_path) as SpaceSyndicateGameScreen \
		if not presentation_game_screen_path.is_empty() else null
	if port == null or game_screen == null:
		return
	game_screen.bind_gameplay_actor_authorization_context(gameplay_actor_authorization_context(&"game_screen"))
	if not game_screen.table_selection_intent_requested.is_connected(port.submit_intent):
		game_screen.table_selection_intent_requested.connect(port.submit_intent)
	if not port.receipt_ready.is_connected(game_screen.apply_table_selection_receipt):
		port.receipt_ready.connect(game_screen.apply_table_selection_receipt)
	if not port.presentation_refresh_requested.is_connected(_on_table_selection_presentation_refresh_requested):
		port.presentation_refresh_requested.connect(_on_table_selection_presentation_refresh_requested)


func _wire_forced_decision_response_paths() -> void:
	if Engine.is_editor_hint():
		return
	var response_port := get_node_or_null("ForcedDecisionResponsePort") as ForcedDecisionResponsePort
	var target_sink := card_target_choice_response_sink()
	var wager_sink := get_node_or_null("MonsterWagerResponseSink") as MONSTER_WAGER_RESPONSE_SINK_SCRIPT
	var game_screen := get_node_or_null(presentation_game_screen_path) as SpaceSyndicateGameScreen \
			if not presentation_game_screen_path.is_empty() else null
	if response_port == null or target_sink == null or wager_sink == null:
		return
	if not response_port.response_authorized.is_connected(target_sink.consume_authorized_response):
		response_port.response_authorized.connect(target_sink.consume_authorized_response)
	if not response_port.response_authorized.is_connected(wager_sink.consume_authorized_response):
		response_port.response_authorized.connect(wager_sink.consume_authorized_response)
	if not response_port.receipt_ready.is_connected(_on_forced_decision_response_receipt_ready):
		response_port.receipt_ready.connect(_on_forced_decision_response_receipt_ready)
	if not target_sink.presentation_refresh_requested.is_connected(_on_forced_decision_domain_refresh_requested):
		target_sink.presentation_refresh_requested.connect(_on_forced_decision_domain_refresh_requested)
	if not wager_sink.presentation_refresh_requested.is_connected(_on_forced_decision_domain_refresh_requested):
		wager_sink.presentation_refresh_requested.connect(_on_forced_decision_domain_refresh_requested)
	if game_screen == null:
		return
	game_screen.bind_gameplay_actor_authorization_context(gameplay_actor_authorization_context(&"game_screen"))
	if not game_screen.forced_decision_response_requested.is_connected(response_port.submit_response):
		game_screen.forced_decision_response_requested.connect(response_port.submit_response)
	if not target_sink.receipt_ready.is_connected(game_screen.apply_card_target_choice_response_receipt):
		target_sink.receipt_ready.connect(game_screen.apply_card_target_choice_response_receipt)
	if not wager_sink.receipt_ready.is_connected(game_screen.apply_monster_wager_response_receipt):
		wager_sink.receipt_ready.connect(game_screen.apply_monster_wager_response_receipt)
	if not response_port.receipt_ready.is_connected(game_screen.apply_forced_decision_response_receipt):
		response_port.receipt_ready.connect(game_screen.apply_forced_decision_response_receipt)


func _on_forced_decision_response_receipt_ready(receipt: ForcedDecisionResponseReceipt) -> void:
	if receipt == null or receipt.accepted \
			or str(receipt.decision_kind) not in [&"monster_wager", CardTargetChoiceRuntimeController.KIND_MONSTER, CardTargetChoiceRuntimeController.KIND_PLAYER]:
		return
	synchronize_forced_decisions()
	var refresh_port := _table_presentation_refresh_port_node()
	if refresh_port != null:
		refresh_port.request_immediate(&"full", &"forced_decision_response_rejected")


func _on_forced_decision_domain_refresh_requested(kind: StringName, reason: StringName) -> void:
	synchronize_forced_decisions()
	var refresh_port := _table_presentation_refresh_port_node()
	if refresh_port != null:
		refresh_port.request_immediate(kind, reason)


func district_supply_action_port() -> DistrictSupplyActionPort:
	return get_node_or_null("DistrictSupplyActionPort") as DistrictSupplyActionPort


func district_supply_runtime_query_port() -> DistrictSupplyRuntimeQueryPort:
	return get_node_or_null("DistrictSupplyRuntimeQueryPort") as DistrictSupplyRuntimeQueryPort


func _wire_district_supply_action_port() -> void:
	if Engine.is_editor_hint():
		return
	var port := district_supply_action_port()
	var query := district_supply_runtime_query_port()
	var game_screen := get_node_or_null(presentation_game_screen_path) as SpaceSyndicateGameScreen \
		if not presentation_game_screen_path.is_empty() else null
	if port == null or query == null:
		return
	var ai := _ai_runtime_controller_node() as AiRuntimeController
	if ai != null:
		ai.set_district_supply_action_port(port)
	var diagnostics_bridge := _gameplay_balance_diagnostics_world_bridge_node() as GameplayBalanceDiagnosticsWorldBridge
	if diagnostics_bridge != null:
		diagnostics_bridge.set_district_supply_runtime_query_port(query)
	var infrastructure_bridge := _region_infrastructure_world_bridge_node() as RegionInfrastructureWorldBridge
	if infrastructure_bridge != null:
		infrastructure_bridge.set_district_supply_runtime_query_port(query)
	if game_screen == null:
		return
	game_screen.bind_gameplay_actor_authorization_context(gameplay_actor_authorization_context(&"game_screen"))
	if not game_screen.district_supply_action_intent_requested.is_connected(port.submit_intent):
		game_screen.district_supply_action_intent_requested.connect(port.submit_intent)
	if not port.receipt_ready.is_connected(game_screen.apply_district_supply_action_receipt):
		port.receipt_ready.connect(game_screen.apply_district_supply_action_receipt)
	if not port.presentation_refresh_requested.is_connected(_on_district_supply_presentation_refresh_requested):
		port.presentation_refresh_requested.connect(_on_district_supply_presentation_refresh_requested)


func _on_district_supply_presentation_refresh_requested(kind: StringName, reason: StringName) -> void:
	var refresh_port := _table_presentation_refresh_port_node()
	if refresh_port != null:
		refresh_port.request_immediate(kind, reason)


func _on_table_selection_presentation_refresh_requested(kind: StringName, reason: StringName) -> void:
	if reason == &"selected_district_changed":
		_reconcile_selected_district_card_supply()
	elif reason == &"selected_trade_product_changed":
		_record_selected_route_weather_response()
	var refresh_port := _table_presentation_refresh_port_node()
	if refresh_port != null:
		refresh_port.request_immediate(kind, reason)


func _reconcile_selected_district_card_supply() -> void:
	var selection := _table_selection_state_node()
	var world := _world_session_state_node()
	var presentation := _table_card_supply_presentation_state_node()
	if selection == null or world == null or presentation == null:
		return
	var district_index := selection.selected_district
	if district_index < 0 or district_index >= world.districts.size():
		presentation.reconcile_district_card_choices([])
		return
	var district: Dictionary = world.districts[district_index]
	if bool(district.get("destroyed", false)):
		presentation.reconcile_district_card_choices([])
		return
	var region_id := str(district.get("region_id", "region.%03d" % district_index))
	var choices: Array = []
	for card_id_variant in region_supply_card_ids(region_id):
		var card_id := str(card_id_variant)
		if card_exists(card_id):
			choices.append(card_id)
	presentation.reconcile_district_card_choices(choices)


func _record_selected_route_weather_response() -> void:
	var selection := _table_selection_state_node()
	var world := _world_session_state_node()
	if selection == null or world == null:
		return
	var district_index := selection.selected_district
	if district_index >= 0 and district_index < world.districts.size():
		record_weather_public_response(district_index, "route_after_forecast")


func _wire_domain_presentation_ports(refresh_port: TablePresentationRefreshPort, public_log_port: PublicLogProducerPort) -> void:
	var clock := _world_effective_clock_runtime_controller_node() as WorldEffectiveClockRuntimeController
	var monster := _monster_runtime_controller_node()
	var military := _military_runtime_controller_node()
	var weather := _weather_runtime_controller_node()
	if monster != null:
		monster.set_table_presentation_ports(refresh_port, public_log_port, clock)
	if military != null:
		military.set_table_presentation_ports(refresh_port, public_log_port, clock)
	if weather != null:
		weather.set_table_presentation_ports(refresh_port, public_log_port, clock)
	var product_market := _product_market_runtime_controller_node() as ProductMarketRuntimeController
	if product_market != null:
		product_market.set_table_presentation_log_port(public_log_port, clock)


func _on_victory_presentation_receipt_ready(receipt: VictoryPresentationStateChangeReceipt) -> void:
	if receipt != null and receipt.is_valid():
		var port := _table_presentation_refresh_port_node()
		if port != null:
			for kind in receipt.immediate_refresh_mask:
				port.request_immediate(kind, &"victory_state_changed")
	victory_presentation_receipt_ready.emit(receipt)


func _card_cooldown_runtime_controller_node() -> CardCooldownRuntimeController:
	return get_node_or_null("CardCooldownRuntimeController") as CardCooldownRuntimeController


func _visual_cue_runtime_owner_node() -> VisualCueRuntimeOwner:
	return get_node_or_null("VisualCueRuntimeOwner") as VisualCueRuntimeOwner


func _table_presentation_refresh_scheduler_node() -> TablePresentationRefreshScheduler:
	return get_node_or_null("TablePresentationRefreshScheduler") as TablePresentationRefreshScheduler


func _table_presentation_source_owner_node() -> TablePresentationSourceOwner:
	return get_node_or_null("TablePresentationSourceOwner") as TablePresentationSourceOwner


func _table_presentation_viewmodel_query_node() -> TablePresentationViewModelQuery:
	return get_node_or_null("TablePresentationViewModelQuery") as TablePresentationViewModelQuery


func _district_supply_viewer_query_port_node() -> DistrictSupplyViewerQueryPort:
	return get_node_or_null("DistrictSupplyViewerQueryPort") as DistrictSupplyViewerQueryPort


func _table_presentation_refresh_port_node() -> TablePresentationRefreshPort:
	return get_node_or_null("TablePresentationRefreshPort") as TablePresentationRefreshPort


func _developer_balance_presentation_target_node() -> DeveloperBalancePresentationTarget:
	return get_node_or_null("DeveloperBalancePresentationTarget") as DeveloperBalancePresentationTarget


func _table_presentation_query_ports_node() -> TablePresentationQueryPorts:
	return get_node_or_null("TablePresentationQueryPorts") as TablePresentationQueryPorts


func _wire_card_cooldown_runtime_controller() -> void:
	var controller := _card_cooldown_runtime_controller_node()
	if controller != null:
		controller.configure(_world_session_state_node())


func _region_supply_card_descriptor(card_id: String) -> Dictionary:
	var catalog := _v06_runtime_card_catalog() as CardRuntimeCatalogV06Resource
	if card_id.is_empty() or catalog == null:
		return {}
	var card := catalog.card_snapshot(card_id)
	if card.is_empty():
		return {}
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	var player: Dictionary = card.get("player", {}) if card.get("player", {}) is Dictionary else {}
	var developer: Dictionary = card.get("developer", {}) if card.get("developer", {}) is Dictionary else {}
	var effect_payload: Dictionary = machine.get("effect_payload", {}) if machine.get("effect_payload", {}) is Dictionary else {}
	var rank := int(machine.get("rank", 0))
	var category_id := str(machine.get("category_id", ""))
	var acquisition_kind := str(machine.get("acquisition_kind", ""))
	if rank != 1 \
			or category_id == "commodity" \
			or not bool(machine.get("available_for_acquisition", false)) \
			or acquisition_kind not in ["dynamic_market_cash", "starter_or_dynamic_market_cash"]:
		return {}
	var route_tags: Array = machine.get("route_tags", []) if machine.get("route_tags", []) is Array else []
	var legal_region_ids: Array = machine.get("legal_region_ids", effect_payload.get("legal_region_ids", [])) if machine.get("legal_region_ids", effect_payload.get("legal_region_ids", [])) is Array else []
	var disabled_region_ids: Array = machine.get("disabled_region_ids", effect_payload.get("disabled_region_ids", [])) if machine.get("disabled_region_ids", effect_payload.get("disabled_region_ids", [])) is Array else []
	var allowed_terrain: Array = machine.get("allowed_terrain", effect_payload.get("allowed_terrain", [])) if machine.get("allowed_terrain", effect_payload.get("allowed_terrain", [])) is Array else []
	var required_mode_tags: Array = machine.get("required_mode_tags", effect_payload.get("required_mode_tags", [])) if machine.get("required_mode_tags", effect_payload.get("required_mode_tags", [])) is Array else []
	return {
		"card_id": card_id,
		"family_id": str(machine.get("family_id", card_id)),
		"card_type": category_id,
		"rank": rank,
		"name": card_id,
		"display_name": str(player.get("name", card_id)),
		"price_cash": maxi(0, int(machine.get("purchase_cash", 0))),
		"target_type": str(machine.get("target_kind", "")),
		"effect_text": str(player.get("effect", player.get("short_effect", ""))),
		"requirement_text": str(player.get("cost", "")),
		"route_tags": route_tags.duplicate(),
		"art_key": str(developer.get("art_key", card_id)),
		"enabled": true,
		"retired": false,
		"valid": true,
		"potential_target_exists": bool(machine.get("potential_target_exists", true)),
		"is_commodity": false,
		"region_supply_weight": maxi(1, int(machine.get("region_supply_weight", 1))),
		"global_unique": bool(machine.get("global_unique", false)),
		"unique_key": str(machine.get("unique_key", machine.get("family_id", card_id))),
		"legal_region_ids": legal_region_ids,
		"disabled_region_ids": disabled_region_ids,
		"allowed_terrain": allowed_terrain,
		"required_mode_tags": required_mode_tags,
	}


func _card_runtime_catalog_node() -> Node:
	return get_node_or_null("CardRuntimeCatalogService")


func _role_catalog_runtime_service_node() -> Node:
	return get_node_or_null("RoleCatalogRuntimeService")


func _card_runtime_definition_bridge_node() -> Node:
	return get_node_or_null("CardRuntimeDefinitionWorldBridge")


func _region_supply_runtime_controller_node() -> Node:
	return get_node_or_null("RegionSupplyRuntimeController")


func _gameplay_balance_diagnostics_node() -> Node:
	return get_node_or_null("GameplayBalanceDiagnosticsRuntimeService")


func _gameplay_balance_diagnostics_world_bridge_node() -> Node:
	return get_node_or_null("GameplayBalanceDiagnosticsWorldBridge")


func _product_market_runtime_controller_node() -> Node:
	return get_node_or_null("ProductMarketRuntimeController")


func _product_market_runtime_world_bridge_node() -> Node:
	return get_node_or_null("ProductMarketRuntimeWorldBridge")


func _city_gdp_derivative_runtime_controller_node() -> Node:
	return get_node_or_null("CityGdpDerivativeRuntimeController")


func _city_gdp_derivative_runtime_world_bridge_node() -> Node:
	return get_node_or_null("CityGdpDerivativeRuntimeWorldBridge")


func _route_network_runtime_controller_node() -> Node:
	return get_node_or_null("RouteNetworkRuntimeController")


func _route_network_world_bridge_node() -> Node:
	return get_node_or_null("RouteNetworkWorldBridge")


func _region_infrastructure_runtime_controller_node() -> Node:
	return get_node_or_null("RegionInfrastructureRuntimeController")


func _region_infrastructure_world_bridge_node() -> Node:
	return get_node_or_null("RegionInfrastructureWorldBridge")


func _commodity_flow_runtime_controller_node() -> Node:
	return get_node_or_null("CommodityFlowRuntimeController")


func _commodity_flow_postcommit_consumer_node() -> CommodityFlowPostCommitReceiptConsumer:
	return get_node_or_null("CommodityFlowPostCommitReceiptConsumer") as CommodityFlowPostCommitReceiptConsumer


func _player_mana_runtime_controller_node() -> Node:
	return get_node_or_null("PlayerManaRuntimeController")


func _commodity_card_inventory_runtime_controller_node() -> Node:
	return get_node_or_null("CommodityCardInventoryRuntimeController")


func _commodity_sushi_track_runtime_service_node() -> COMMODITY_SUSHI_TRACK_SERVICE_SCRIPT:
	return get_node_or_null("CommoditySushiTrackRuntimeService") as COMMODITY_SUSHI_TRACK_SERVICE_SCRIPT


func _bind_region_supply_source_port() -> Dictionary:
	var inventory := _commodity_card_inventory_runtime_controller_node()
	var source := _region_supply_runtime_controller_node()
	if inventory == null or not inventory.has_method("set_region_supply_source_port"):
		return {
			"configured": false,
			"reason_code": "region_supply_inventory_unavailable",
		}
	if source == null:
		return {
			"configured": false,
			"reason_code": "region_supply_source_unavailable",
		}
	var value_variant: Variant = inventory.call("set_region_supply_source_port", source)
	return (
		(value_variant as Dictionary).duplicate(true)
		if value_variant is Dictionary
		else {
			"configured": false,
			"reason_code": "region_supply_source_binding_invalid",
		}
	)


func _card_player_state_production_adapter_v06_node() -> Node:
	return get_node_or_null("CardPlayerStateProductionAdapterV06")


func _core_economic_card_runtime_adapter_v06_node() -> Node:
	return get_node_or_null("CoreEconomicCardRuntimeAdapterV06")


func _player_organization_runtime_controller_node() -> Node:
	return get_node_or_null("PlayerOrganizationRuntimeController")


func _commodity_flow_world_bridge_node() -> Node:
	return get_node_or_null("CommodityFlowWorldBridge")


func _bankruptcy_neutral_estate_runtime_controller_node() -> Node:
	return get_node_or_null("BankruptcyNeutralEstateRuntimeController")


func _bankruptcy_neutral_estate_world_bridge_node() -> Node:
	return get_node_or_null("BankruptcyNeutralEstateWorldBridge")


func _victory_control_runtime_controller_node() -> Node:
	return get_node_or_null("VictoryControlRuntimeController")


func _victory_control_world_bridge_node() -> Node:
	return get_node_or_null("VictoryControlWorldBridge")


func _ai_runtime_controller_node() -> Node:
	return get_node_or_null("AiRuntimeController")


func _ai_actor_state_port_node() -> AiActorStatePort:
	return get_node_or_null("AiActorStatePort") as AiActorStatePort


func _ai_session_public_query_port_node() -> AiSessionPublicQueryPort:
	return get_node_or_null("AiSessionPublicQueryPort") as AiSessionPublicQueryPort


func _ai_card_hand_query_port_node() -> AiCardHandQueryPort:
	return get_node_or_null("AiCardHandQueryPort") as AiCardHandQueryPort


func _ai_card_queue_query_port_node() -> AiCardQueueQueryPort:
	return get_node_or_null("AiCardQueueQueryPort") as AiCardQueueQueryPort


func _ai_card_eligibility_query_port_node() -> AiCardEligibilityQueryPort:
	return get_node_or_null(
		"AiCardEligibilityQueryPort"
	) as AiCardEligibilityQueryPort


func _ai_actor_economy_query_port_node() -> AiActorEconomyQueryPort:
	return get_node_or_null("AiActorEconomyQueryPort") as AiActorEconomyQueryPort


func _ai_market_public_query_port_node() -> AiMarketPublicQueryPort:
	return get_node_or_null("AiMarketPublicQueryPort") as AiMarketPublicQueryPort


func _ai_route_public_query_port_node() -> AiRoutePublicQueryPort:
	return get_node_or_null("AiRoutePublicQueryPort") as AiRoutePublicQueryPort


func _ai_region_knowledge_query_port_node() -> AiRegionKnowledgeQueryPort:
	return get_node_or_null("AiRegionKnowledgeQueryPort") as AiRegionKnowledgeQueryPort


func _ai_city_inference_command_port_node() -> AiCityInferenceCommandPort:
	return get_node_or_null("AiCityInferenceCommandPort") as AiCityInferenceCommandPort


func _ai_monster_public_query_port_node() -> AiMonsterPublicQueryPort:
	return get_node_or_null("AiMonsterPublicQueryPort") as AiMonsterPublicQueryPort


func _ai_monster_actor_query_port_node() -> AiMonsterActorQueryPort:
	return get_node_or_null("AiMonsterActorQueryPort") as AiMonsterActorQueryPort


func _ai_military_public_query_port_node() -> AiMilitaryPublicQueryPort:
	return get_node_or_null("AiMilitaryPublicQueryPort") as AiMilitaryPublicQueryPort


func _ai_military_actor_query_port_node() -> AiMilitaryActorQueryPort:
	return get_node_or_null("AiMilitaryActorQueryPort") as AiMilitaryActorQueryPort


func _ai_weather_public_query_port_node() -> AiWeatherPublicQueryPort:
	return get_node_or_null("AiWeatherPublicQueryPort") as AiWeatherPublicQueryPort


func _ai_victory_public_query_port_node() -> AiVictoryPublicQueryPort:
	return get_node_or_null("AiVictoryPublicQueryPort") as AiVictoryPublicQueryPort


func _ai_actor_victory_query_port_node() -> AiActorVictoryQueryPort:
	return get_node_or_null("AiActorVictoryQueryPort") as AiActorVictoryQueryPort


func _monster_runtime_controller_node() -> Node:
	return get_node_or_null("MonsterRuntimeController")


func _monster_wager_cash_commitment_query_port_node() -> MonsterWagerCashCommitmentQueryPort:
	return get_node_or_null("MonsterWagerCashCommitmentQueryPort") as MonsterWagerCashCommitmentQueryPort


func _player_cash_mutation_port_node() -> PlayerCashMutationPort:
	return get_node_or_null("PlayerCashMutationPort") as PlayerCashMutationPort


func _ai_business_cost_cash_port_node() -> AiBusinessCostCashPort:
	return get_node_or_null("AiBusinessCostCashPort") as AiBusinessCostCashPort


func _monster_runtime_world_bridge_node() -> Node:
	return get_node_or_null("MonsterRuntimeWorldBridge")


func _military_runtime_controller_node() -> Node:
	return get_node_or_null("MilitaryRuntimeController")


func _military_runtime_world_bridge_node() -> Node:
	return get_node_or_null("MilitaryRuntimeWorldBridge")


func _weather_runtime_controller_node() -> Node:
	return get_node_or_null("WeatherRuntimeController")


func _weather_runtime_world_bridge_node() -> Node:
	return get_node_or_null("WeatherRuntimeWorldBridge")


func _weather_presentation_runtime_service_node() -> Node:
	return get_node_or_null("WeatherPresentationRuntimeService")


func _weather_telemetry_runtime_service_node() -> Node:
	return get_node_or_null("WeatherTelemetryRuntimeService")


func _card_play_eligibility_node() -> Node:
	return get_node_or_null("CardPlayEligibilityRuntimeService")


func _card_play_world_bridge_node() -> Node:
	return get_node_or_null("CardPlayEligibilityWorldBridge")


func _card_resolution_execution_world_bridge_node() -> Node:
	return get_node_or_null("CardResolutionExecutionWorldBridge")


func _card_resolution_history_runtime_service_node() -> CardResolutionHistoryRuntimeService:
	return get_node_or_null("CardResolutionHistoryRuntimeService") as CardResolutionHistoryRuntimeService


func _card_history_public_query_port_node() -> Node:
	return get_node_or_null("CardHistoryPublicQueryPort")


func _card_history_private_annotation_service_node() -> Node:
	return get_node_or_null("CardHistoryPrivateAnnotationService")


func _card_resolution_presentation_port_node() -> CardResolutionPresentationPort:
	return get_node_or_null("CardResolutionPresentationPort") as CardResolutionPresentationPort


func _card_intel_runtime_service_node() -> CardIntelRuntimeService:
	return get_node_or_null("CardIntelRuntimeService") as CardIntelRuntimeService


func _card_effect_runtime_router_node() -> CardEffectRuntimeRouter:
	return get_node_or_null("CardEffectRuntimeRouter") as CardEffectRuntimeRouter


func _card_commitment_runtime_service_node() -> CardCommitmentRuntimeService:
	return get_node_or_null("CardCommitmentRuntimeService") as CardCommitmentRuntimeService


func _card_counter_settlement_runtime_service_node() -> CardCounterSettlementRuntimeService:
	return get_node_or_null("CardCounterSettlementRuntimeService") as CardCounterSettlementRuntimeService


func _card_play_submission_runtime_controller_node() -> CardPlaySubmissionRuntimeController:
	return get_node_or_null("CardPlaySubmissionRuntimeController") as CardPlaySubmissionRuntimeController


func _world_effective_clock_runtime_controller_node() -> Node:
	return get_node_or_null("WorldEffectiveClockRuntimeController")


func _run_rng_service_node() -> RunRngService:
	return get_node_or_null("RunRngService") as RunRngService


func _table_selection_state_node() -> TableSelectionState:
	return get_node_or_null("TableSelectionState") as TableSelectionState


func _table_card_supply_presentation_state_node() -> TableCardSupplyPresentationState:
	return get_node_or_null("TableCardSupplyPresentationState") as TableCardSupplyPresentationState


func _world_session_state_node() -> WorldSessionState:
	if _world_session_state_cache != null and is_instance_valid(_world_session_state_cache):
		return _world_session_state_cache
	_world_session_state_cache = get_node_or_null("WorldSessionState") as WorldSessionState
	return _world_session_state_cache


func _solar_availability_runtime_service_node() -> Node:
	return get_node_or_null("SolarAvailabilityRuntimeService")


func _card_market_policy_world_bridge_node() -> Node:
	return get_node_or_null("CardMarketPolicyWorldBridge")


func _card_market_pricing_runtime_controller_node() -> Node:
	return get_node_or_null("CardMarketPricingRuntimeController")


func _session_node() -> Node:
	return get_node_or_null("GameSessionRuntimeController")


func _purchase_node() -> Node:
	return get_node_or_null("DistrictPurchaseRuntimeController")


func _card_inventory_node() -> Node:
	return get_node_or_null("CardInventoryRuntimeService")


func _card_resolution_queue_node() -> Node:
	return get_node_or_null("CardResolutionQueueRuntimeService")


func _action_result_presentation_node() -> Node:
	return get_node_or_null("ActionResultPresentationService")


func _card_resolution_execution_node() -> Node:
	return get_node_or_null("CardResolutionExecutionRuntimeService")


func _card_economy_product_route_effect_node() -> Node:
	return get_node_or_null("CardEconomyProductRouteEffectRuntimeService")


func _card_economy_product_route_effect_world_bridge_node() -> Node:
	return get_node_or_null("CardEconomyProductRouteEffectWorldBridge")


func _card_economy_product_route_formula_node() -> Node:
	return get_node_or_null("CardEconomyProductRouteFormulaRuntimeService")


func _player_hand_interaction_node() -> Node:
	return get_node_or_null("PlayerHandInteractionRuntimeService")


func _purchase_settlement_node() -> Node:
	return get_node_or_null("DistrictPurchaseSettlementRuntimeService")


func _codex_navigation_node() -> Node:
	return get_node_or_null("CodexNavigationRuntimeController")


func _codex_public_snapshot_node() -> Node:
	return get_node_or_null("CodexPublicSnapshotService")


func _role_codex_public_source_node() -> Node:
	return get_node_or_null("RoleCodexPublicSourceService")


func _monster_codex_public_snapshot_node() -> Node:
	return get_node_or_null("MonsterCodexPublicSnapshotService")


func _monster_codex_public_source_node() -> Node:
	return get_node_or_null("MonsterCodexPublicSourceService")


func _product_codex_public_snapshot_node() -> Node:
	return get_node_or_null("ProductCodexPublicSnapshotService")


func _product_codex_public_source_node() -> Node:
	return get_node_or_null("ProductCodexPublicSourceService")


func _card_codex_public_snapshot_node() -> Node:
	return get_node_or_null("CardCodexPublicSnapshotService")


func _card_codex_public_source_node() -> Node:
	return get_node_or_null("CardCodexPublicSourceService")


func _region_codex_public_source_node() -> Node:
	return get_node_or_null("RegionCodexPublicSourceService")


func _economy_dashboard_public_snapshot_node() -> Node:
	return get_node_or_null("EconomyDashboardPublicSnapshotService")


func _standings_public_snapshot_node() -> Node:
	return get_node_or_null("StandingsPublicSnapshotService")


func _final_settlement_public_snapshot_node() -> Node:
	return get_node_or_null("FinalSettlementPublicSnapshotService")


func _intel_dossier_public_snapshot_node() -> Node:
	return get_node_or_null("IntelDossierPublicSnapshotService")


func _district_supply_snapshot_node() -> Node:
	return get_node_or_null("DistrictSupplySnapshotService")


func _card_presentation_node() -> Node:
	return get_node_or_null("CardPresentationRuntimeService")


func _table_viewmodel_node() -> Node:
	return get_node_or_null("GameTableViewModelRuntimeService")


func _player_seat_public_source_node() -> Node:
	return get_node_or_null("PlayerSeatPublicSourceService")


func _ai_runtime_debug_snapshot() -> Dictionary:
	var controller := _ai_runtime_controller_node()
	if controller != null and controller.has_method("debug_snapshot"):
		var snapshot_variant: Variant = controller.call("debug_snapshot", -1)
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _monster_runtime_debug_snapshot() -> Dictionary:
	var controller := _monster_runtime_controller_node()
	if controller != null and controller.has_method("debug_snapshot"):
		var snapshot_variant: Variant = controller.call("debug_snapshot", -1)
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _military_runtime_debug_snapshot() -> Dictionary:
	var controller := _military_runtime_controller_node()
	if controller != null and controller.has_method("debug_snapshot"):
		var snapshot_variant: Variant = controller.call("debug_snapshot", -1)
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _weather_runtime_debug_snapshot() -> Dictionary:
	var controller := _weather_runtime_controller_node()
	if controller != null and controller.has_method("debug_snapshot"):
		var snapshot_variant: Variant = controller.call("debug_snapshot", -1)
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _session_debug_snapshot() -> Dictionary:
	var session := _session_node()
	if session != null and session.has_method("debug_snapshot"):
		var snapshot_variant: Variant = session.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _purchase_debug_snapshot() -> Dictionary:
	var purchase := _purchase_node()
	if purchase != null and purchase.has_method("debug_snapshot"):
		var snapshot_variant: Variant = purchase.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _card_runtime_catalog_debug_snapshot() -> Dictionary:
	var service := _card_runtime_catalog_node()
	if service != null and service.has_method("debug_snapshot"):
		var snapshot_variant: Variant = service.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _node_debug_snapshot(node: Node) -> Dictionary:
	if node != null and node.has_method("debug_snapshot"):
		var snapshot_variant: Variant = node.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _card_runtime_definition_bridge_debug_snapshot() -> Dictionary:
	var bridge := _card_runtime_definition_bridge_node()
	if bridge != null and bridge.has_method("debug_snapshot"):
		var snapshot_variant: Variant = bridge.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _gameplay_balance_diagnostics_debug_snapshot() -> Dictionary:
	var service := _gameplay_balance_diagnostics_node()
	if service != null and service.has_method("debug_snapshot"):
		var snapshot_variant: Variant = service.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _card_inventory_debug_snapshot() -> Dictionary:
	var service := _card_inventory_node()
	if service != null and service.has_method("debug_snapshot"):
		var snapshot_variant: Variant = service.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _card_resolution_queue_debug_snapshot() -> Dictionary:
	var service := _card_resolution_queue_node()
	if service != null and service.has_method("debug_snapshot"):
		var snapshot_variant: Variant = service.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _action_result_presentation_debug_snapshot() -> Dictionary:
	var service := _action_result_presentation_node()
	if service != null and service.has_method("debug_snapshot"):
		var snapshot_variant: Variant = service.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _card_resolution_execution_debug_snapshot() -> Dictionary:
	var service := _card_resolution_execution_node()
	if service != null and service.has_method("debug_snapshot"):
		var snapshot_variant: Variant = service.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _card_economy_product_route_effect_debug_snapshot() -> Dictionary:
	var service := _card_economy_product_route_effect_node()
	if service != null and service.has_method("debug_snapshot"):
		var snapshot_variant: Variant = service.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _card_economy_product_route_formula_debug_snapshot() -> Dictionary:
	var service := _card_economy_product_route_formula_node()
	if service != null and service.has_method("debug_snapshot"):
		var snapshot_variant: Variant = service.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _product_market_runtime_debug_snapshot() -> Dictionary:
	var controller := _product_market_runtime_controller_node()
	if controller != null and controller.has_method("debug_snapshot"):
		var snapshot_variant: Variant = controller.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _city_gdp_derivative_runtime_debug_snapshot() -> Dictionary:
	var controller := _city_gdp_derivative_runtime_controller_node()
	if controller != null and controller.has_method("debug_snapshot"):
		var snapshot_variant: Variant = controller.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _route_network_runtime_debug_snapshot() -> Dictionary:
	var controller := _route_network_runtime_controller_node()
	if controller != null and controller.has_method("debug_snapshot"):
		var snapshot_variant: Variant = controller.call("debug_snapshot", -1)
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _region_infrastructure_runtime_debug_snapshot() -> Dictionary:
	var controller := _region_infrastructure_runtime_controller_node()
	if controller != null and controller.has_method("debug_snapshot"):
		var snapshot_variant: Variant = controller.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _region_infrastructure_world_bridge_debug_snapshot() -> Dictionary:
	var bridge := _region_infrastructure_world_bridge_node()
	if bridge != null and bridge.has_method("debug_snapshot"):
		var snapshot_variant: Variant = bridge.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _commodity_flow_runtime_debug_snapshot() -> Dictionary:
	var controller := _commodity_flow_runtime_controller_node()
	if controller != null and controller.has_method("debug_snapshot"):
		var value: Variant = controller.call("debug_snapshot")
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {}


func _commodity_flow_postcommit_debug_snapshot() -> Dictionary:
	var consumer := _commodity_flow_postcommit_consumer_node()
	return consumer.debug_snapshot() if consumer != null else {}


func _player_mana_runtime_debug_snapshot() -> Dictionary:
	var controller := _player_mana_runtime_controller_node()
	if controller != null and controller.has_method("debug_snapshot"):
		var value: Variant = controller.call("debug_snapshot")
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {}


func _commodity_card_inventory_runtime_debug_snapshot() -> Dictionary:
	var controller := _commodity_card_inventory_runtime_controller_node()
	if controller != null and controller.has_method("debug_snapshot"):
		var value: Variant = controller.call("debug_snapshot")
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {}


func _card_player_state_production_adapter_v06_debug_snapshot() -> Dictionary:
	var adapter := _card_player_state_production_adapter_v06_node()
	if adapter != null and adapter.has_method("debug_snapshot"):
		var value: Variant = adapter.call("debug_snapshot")
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {}


func _core_economic_card_runtime_adapter_v06_debug_snapshot() -> Dictionary:
	var adapter := _core_economic_card_runtime_adapter_v06_node()
	if adapter != null and adapter.has_method("debug_snapshot"):
		var value: Variant = adapter.call("debug_snapshot")
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {}


func _player_organization_runtime_debug_snapshot() -> Dictionary:
	var organization_owner := _player_organization_runtime_controller_node()
	if organization_owner != null and organization_owner.has_method("debug_snapshot"):
		var value_variant: Variant = organization_owner.call("debug_snapshot")
		if value_variant is Dictionary:
			return (value_variant as Dictionary).duplicate(true)
	return {}


func _player_organization_runtime_health_snapshot() -> Dictionary:
	var debug := _player_organization_runtime_debug_snapshot()
	var public_snapshot: Dictionary = {}
	var organization_owner := _player_organization_runtime_controller_node()
	if organization_owner != null and organization_owner.has_method("public_snapshot"):
		var public_variant: Variant = organization_owner.call("public_snapshot")
		if public_variant is Dictionary:
			public_snapshot = (public_variant as Dictionary).duplicate(true)
	return {
		"configured": bool(debug.get("configured", false)),
		"controller_authoritative": bool(debug.get("controller_authoritative", false)),
		"parallel_business_owner": bool(debug.get("parallel_business_owner", true)),
		"actor_count": int(debug.get("actor_count", 0)),
		"revision": int(debug.get("revision", 0)),
		"checkpoint": (debug.get("checkpoint", {}) as Dictionary).duplicate(true) if debug.get("checkpoint", {}) is Dictionary else {},
		"public_snapshot": public_snapshot,
		"consumer_readiness": organization_consumer_readiness_snapshot(),
	}


func _commodity_flow_world_bridge_debug_snapshot() -> Dictionary:
	var bridge := _commodity_flow_world_bridge_node()
	if bridge != null and bridge.has_method("debug_snapshot"):
		var value: Variant = bridge.call("debug_snapshot")
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {}


func _bankruptcy_neutral_estate_runtime_debug_snapshot() -> Dictionary:
	var controller := _bankruptcy_neutral_estate_runtime_controller_node()
	if controller != null and controller.has_method("debug_snapshot"):
		var value: Variant = controller.call("debug_snapshot")
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {}


func _bankruptcy_neutral_estate_world_bridge_debug_snapshot() -> Dictionary:
	var bridge := _bankruptcy_neutral_estate_world_bridge_node()
	if bridge != null and bridge.has_method("debug_snapshot"):
		var value: Variant = bridge.call("debug_snapshot")
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {}


func _victory_control_runtime_debug_snapshot() -> Dictionary:
	var controller := _victory_control_runtime_controller_node()
	if controller != null and controller.has_method("debug_snapshot"):
		var snapshot_variant: Variant = controller.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _victory_control_world_bridge_debug_snapshot() -> Dictionary:
	var bridge := _victory_control_world_bridge_node()
	if bridge != null and bridge.has_method("debug_snapshot"):
		var snapshot_variant: Variant = bridge.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _player_hand_interaction_debug_snapshot() -> Dictionary:
	var service := _player_hand_interaction_node()
	if service != null and service.has_method("debug_snapshot"):
		var snapshot_variant: Variant = service.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _purchase_settlement_debug_snapshot() -> Dictionary:
	var service := _purchase_settlement_node()
	if service != null and service.has_method("debug_snapshot"):
		var snapshot_variant: Variant = service.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _codex_navigation_debug_snapshot() -> Dictionary:
	var controller := _codex_navigation_node()
	if controller != null and controller.has_method("debug_snapshot"):
		var snapshot_variant: Variant = controller.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _codex_public_snapshot_debug_snapshot() -> Dictionary:
	var service := _codex_public_snapshot_node()
	if service != null and service.has_method("debug_snapshot"):
		var snapshot_variant: Variant = service.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _monster_codex_public_snapshot_debug_snapshot() -> Dictionary:
	var service := _monster_codex_public_snapshot_node()
	if service != null and service.has_method("debug_snapshot"):
		var snapshot_variant: Variant = service.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _monster_codex_public_source_debug_snapshot() -> Dictionary:
	var service := _monster_codex_public_source_node()
	if service != null and service.has_method("debug_snapshot"):
		var snapshot_variant: Variant = service.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _product_codex_public_snapshot_debug_snapshot() -> Dictionary:
	var service := _product_codex_public_snapshot_node()
	if service != null and service.has_method("debug_snapshot"):
		var snapshot_variant: Variant = service.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _product_codex_public_source_debug_snapshot() -> Dictionary:
	var service := _product_codex_public_source_node()
	if service != null and service.has_method("debug_snapshot"):
		var snapshot_variant: Variant = service.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _card_codex_public_snapshot_debug_snapshot() -> Dictionary:
	var service := _card_codex_public_snapshot_node()
	if service != null and service.has_method("debug_snapshot"):
		var snapshot_variant: Variant = service.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _card_codex_public_source_debug_snapshot() -> Dictionary:
	var service := _card_codex_public_source_node()
	if service != null and service.has_method("debug_snapshot"):
		var snapshot_variant: Variant = service.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _region_codex_public_source_debug_snapshot() -> Dictionary:
	var service := _region_codex_public_source_node()
	if service != null and service.has_method("debug_snapshot"):
		var snapshot_variant: Variant = service.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _economy_dashboard_public_snapshot_debug_snapshot() -> Dictionary:
	var service := _economy_dashboard_public_snapshot_node()
	if service != null and service.has_method("debug_snapshot"):
		var snapshot_variant: Variant = service.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _standings_public_snapshot_debug_snapshot() -> Dictionary:
	var service := _standings_public_snapshot_node()
	if service != null and service.has_method("debug_snapshot"):
		var snapshot_variant: Variant = service.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _final_settlement_public_snapshot_debug_snapshot() -> Dictionary:
	var service := _final_settlement_public_snapshot_node()
	if service != null and service.has_method("debug_snapshot"):
		var snapshot_variant: Variant = service.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _intel_dossier_public_snapshot_debug_snapshot() -> Dictionary:
	var service := _intel_dossier_public_snapshot_node()
	if service != null and service.has_method("debug_snapshot"):
		var snapshot_variant: Variant = service.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _district_supply_snapshot_debug_snapshot() -> Dictionary:
	var service := _district_supply_snapshot_node()
	if service != null and service.has_method("debug_snapshot"):
		var snapshot_variant: Variant = service.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _card_presentation_debug_snapshot() -> Dictionary:
	var service := _card_presentation_node()
	if service != null and service.has_method("debug_snapshot"):
		var value: Variant = service.call("debug_snapshot")
		if value is Dictionary: return (value as Dictionary).duplicate(true)
	return {}


func _card_play_eligibility_debug_snapshot() -> Dictionary:
	var service := _card_play_eligibility_node()
	if service != null and service.has_method("debug_snapshot"):
		var value: Variant = service.call("debug_snapshot")
		if value is Dictionary: return (value as Dictionary).duplicate(true)
	return {}


func _card_play_world_bridge_debug_snapshot() -> Dictionary:
	var bridge := _card_play_world_bridge_node()
	if bridge != null and bridge.has_method("debug_snapshot"):
		var value: Variant = bridge.call("debug_snapshot")
		if value is Dictionary: return (value as Dictionary).duplicate(true)
	return {}


func _table_viewmodel_debug_snapshot() -> Dictionary:
	var service := _table_viewmodel_node()
	if service != null and service.has_method("debug_snapshot"):
		var value: Variant = service.call("debug_snapshot")
		if value is Dictionary: return (value as Dictionary).duplicate(true)
	return {}
