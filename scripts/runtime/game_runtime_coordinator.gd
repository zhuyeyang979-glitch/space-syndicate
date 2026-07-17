@tool
extends Node
class_name GameRuntimeCoordinator

const RULESET_V06_PROFILE := preload("res://resources/rules/space_syndicate_ruleset_v06.tres")
const MONSTER_CARD_EFFECT_ADAPTER_V06 := preload("res://scripts/cards/v06/units/monster_card_effect_adapter_v06.gd")
const AI_V06_ECONOMY_ACTION_PORT := preload("res://scripts/runtime/ai_v06_economy_action_port.gd")
const RUNTIME_BALANCE_MODEL_SCRIPT := preload("res://scripts/balance/runtime_balance_model.gd")
const CORE_ECONOMIC_CARD_EFFECT_KINDS_V06 := [
	"install_commodity_rate",
	"build_upgrade_or_repair_facility",
	"global_order_budget",
	"global_supply_spawn",
	"install_organization_upgrade",
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
var _ai_v06_economy_action_port: RefCounted


func _ready() -> void:
	_wire_run_rng_service()
	_wire_table_selection_state()
	_wire_world_session_state()
	_wire_forced_decision_candidate_sources()
	_wire_card_resolution_frame_driver()
	_wire_card_cooldown_runtime_controller()
	_wire_card_execution_typed_ports()


func configure(ruleset_snapshot: Dictionary) -> void:
	_ruleset_id = str(ruleset_snapshot.get("ruleset_id", ""))
	_wire_run_rng_service()
	_wire_table_selection_state()
	_wire_world_session_state()
	_wire_forced_decision_candidate_sources()
	_wire_card_resolution_frame_driver()
	_wire_card_cooldown_runtime_controller()
	_wire_card_execution_typed_ports()
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
	var card_runtime_catalog := _card_runtime_catalog_node()
	if card_runtime_catalog != null and card_runtime_catalog.has_method("configure"):
		card_runtime_catalog.call("configure", ruleset_snapshot)
	var card_definition_bridge := _card_runtime_definition_bridge_node()
	if card_definition_bridge != null and card_definition_bridge.has_method("set_catalog_service"):
		card_definition_bridge.call("set_catalog_service", card_runtime_catalog)
	var balance_diagnostics := _gameplay_balance_diagnostics_node()
	var balance_diagnostics_bridge := _gameplay_balance_diagnostics_world_bridge_node()
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
	if card_definition_bridge != null and card_definition_bridge.has_method("set_product_market_runtime_controller"):
		card_definition_bridge.call("set_product_market_runtime_controller", product_market_controller)
	if card_definition_bridge != null and card_definition_bridge.has_method("set_city_gdp_derivative_runtime_controller"):
		card_definition_bridge.call("set_city_gdp_derivative_runtime_controller", city_gdp_derivative_controller)
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
	_bind_region_supply_source_port()
	var codex_navigation := _codex_navigation_node()
	if codex_navigation != null and codex_navigation.has_method("configure"):
		codex_navigation.call("configure", {})
	var codex_public_snapshot := _codex_public_snapshot_node()
	if codex_public_snapshot != null and codex_public_snapshot.has_method("configure"):
		codex_public_snapshot.call("configure", {})
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
			"card_catalog": card_runtime_catalog,
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
			"catalog": card_runtime_catalog,
			"presentation": card_presentation,
			"eligibility": card_play_eligibility,
			"diagnostics": balance_diagnostics,
			"snapshot": card_codex_public_snapshot,
			"runtime_balance_model": RUNTIME_BALANCE_MODEL_SCRIPT.new(),
		})
	var table_viewmodel := _table_viewmodel_node()
	if table_viewmodel != null and table_viewmodel.has_method("configure"):
		table_viewmodel.call("configure", card_presentation)
	var monster_controller := _monster_runtime_controller_node()
	var monster_world_bridge := _monster_runtime_world_bridge_node()
	var military_controller := _military_runtime_controller_node()
	var military_world_bridge := _military_runtime_world_bridge_node()
	var weather_controller := _weather_runtime_controller_node()
	var weather_world_bridge := _weather_runtime_world_bridge_node()
	var contract_controller := _contract_runtime_controller_node()
	var contract_world_bridge := _contract_runtime_world_bridge_node()
	var ai_controller := _ai_runtime_controller_node()
	var ai_world_bridge := _ai_runtime_world_bridge_node()
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
	if contract_world_bridge != null and contract_world_bridge.has_method("set_product_market_runtime_controller"):
		contract_world_bridge.call("set_product_market_runtime_controller", product_market_controller)
	if contract_world_bridge != null and contract_world_bridge.has_method("set_route_network_runtime_controller"):
		contract_world_bridge.call("set_route_network_runtime_controller", route_network_controller)
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
	if contract_controller != null and contract_controller.has_method("set_world_bridge"):
		contract_controller.call("set_world_bridge", contract_world_bridge)
	if contract_controller != null and contract_controller.has_method("configure"):
		contract_controller.call("configure", ruleset_snapshot)
	if ai_controller != null and ai_controller.has_method("set_world_bridge"):
		ai_controller.call("set_world_bridge", ai_world_bridge)
	if ai_controller != null and ai_controller.has_method("set_monster_runtime_controller"):
		ai_controller.call("set_monster_runtime_controller", monster_controller)
	if ai_controller != null and ai_controller.has_method("set_military_runtime_controller"):
		ai_controller.call("set_military_runtime_controller", military_controller)
	if ai_controller != null and ai_controller.has_method("set_weather_runtime_controller"):
		ai_controller.call("set_weather_runtime_controller", weather_controller)
	if ai_controller != null and ai_controller.has_method("set_contract_runtime_controller"):
		ai_controller.call("set_contract_runtime_controller", contract_controller)
	if ai_controller != null and ai_controller.has_method("set_product_market_runtime_controller"):
		ai_controller.call("set_product_market_runtime_controller", product_market_controller)
	if ai_controller != null and ai_controller.has_method("set_city_gdp_derivative_runtime_controller"):
		ai_controller.call("set_city_gdp_derivative_runtime_controller", city_gdp_derivative_controller)
	if ai_controller != null and ai_controller.has_method("set_card_definition_bridge"):
		ai_controller.call("set_card_definition_bridge", card_definition_bridge)
	if ai_controller != null and ai_controller.has_method("set_gameplay_balance_diagnostics_service"):
		ai_controller.call("set_gameplay_balance_diagnostics_service", balance_diagnostics)
	if ai_controller != null and ai_controller.has_method("set_victory_control_runtime_controller"):
		ai_controller.call("set_victory_control_runtime_controller", victory_controller)
	if ai_controller != null and ai_controller.has_method("set_route_network_runtime_controller"):
		ai_controller.call("set_route_network_runtime_controller", route_network_controller)
	if ai_controller != null and ai_controller.has_method("set_visual_cue_runtime_owner"):
		ai_controller.call("set_visual_cue_runtime_owner", visual_cue_owner)
	if ai_controller != null and ai_controller.has_method("configure"):
		ai_controller.call("configure", ruleset_snapshot, ai_controller.get("policy_profile"))
	_refresh_ai_v06_economy_action_port()
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
		victory_world_bridge.call("set_runtime_dependencies", region_infrastructure, commodity_flow, contract_controller, product_market_controller, city_gdp_derivative_controller, military_controller)
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
	var route_network_snapshot := _route_network_runtime_debug_snapshot()
	var commodity_flow_snapshot := _commodity_flow_runtime_debug_snapshot()
	var commodity_flow_bridge_snapshot := _commodity_flow_world_bridge_debug_snapshot()
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
	var contract_snapshot := _contract_runtime_debug_snapshot()
	var victory_snapshot := _victory_control_runtime_debug_snapshot()
	var world_clock_snapshot := _node_debug_snapshot(world_clock)
	var solar_snapshot := _node_debug_snapshot(solar_availability)
	var card_market_snapshot := _node_debug_snapshot(card_market_pricing)
	_composition_ready = _ruleset_id == "v0.4" and scheduler != null and not priority_order.is_empty() and bool(world_clock_snapshot.get("controller_ready", false)) and bool(solar_snapshot.get("service_ready", false)) and bool(card_market_snapshot.get("controller_ready", false)) and bool(card_runtime_catalog_snapshot.get("service_ready", false)) and bool(card_definition_bridge_snapshot.get("bridge_ready", false)) and bool(balance_diagnostics_snapshot.get("service_ready", false)) and bool(session_snapshot.get("session_ready", false)) and bool(purchase_snapshot.get("controller_ready", false)) and bool(card_inventory_snapshot.get("service_ready", false)) and bool(card_resolution_queue_snapshot.get("service_ready", false)) and bool(card_resolution_execution_snapshot.get("service_ready", false)) and bool(economy_product_route_effect_snapshot.get("service_ready", false)) and bool(economy_product_route_formula_snapshot.get("service_ready", false)) and bool(product_market_snapshot.get("controller_ready", false)) and bool(city_gdp_derivative_snapshot.get("controller_ready", false)) and bool(route_network_snapshot.get("controller_ready", false)) and bool(commodity_flow_snapshot.get("controller_ready", false)) and bool(commodity_flow_bridge_snapshot.get("bridge_ready", false)) and bool(player_mana_snapshot.get("controller_ready", false)) and bool(hand_interaction_snapshot.get("service_ready", false)) and bool(purchase_settlement_snapshot.get("service_ready", false)) and bool(codex_navigation_snapshot.get("controller_ready", false)) and bool(codex_public_snapshot_debug.get("service_ready", false)) and bool(monster_codex_public_snapshot_debug.get("service_ready", false)) and bool(monster_codex_public_source_debug.get("service_ready", false)) and bool(product_codex_public_snapshot_debug.get("service_ready", false)) and bool(product_codex_public_source_debug.get("service_ready", false)) and bool(card_codex_public_snapshot_debug.get("service_ready", false)) and bool(card_codex_public_source_debug.get("service_ready", false)) and bool(region_codex_public_source_debug.get("service_ready", false)) and bool(economy_dashboard_public_snapshot_debug.get("service_ready", false)) and bool(standings_public_snapshot_debug.get("service_ready", false)) and bool(final_settlement_public_snapshot_debug.get("service_ready", false)) and bool(intel_dossier_public_snapshot_debug.get("service_ready", false)) and bool(district_supply_snapshot_state.get("service_ready", false)) and bool(card_presentation_snapshot.get("service_ready", false)) and bool(card_play_eligibility_snapshot.get("service_ready", false)) and bool(card_play_world_bridge_snapshot.get("bridge_ready", false)) and bool(table_viewmodel_snapshot.get("service_ready", false)) and bool(ai_snapshot.get("controller_ready", false)) and bool(monster_snapshot.get("controller_ready", false)) and bool(military_snapshot.get("controller_ready", false)) and bool(weather_snapshot.get("controller_ready", false)) and bool(contract_snapshot.get("controller_ready", false)) and bool(victory_snapshot.get("controller_ready", false))
	_composition_ready = _composition_ready and bool(action_result_presentation_snapshot.get("service_ready", false))
	_refresh_coordinator_readiness()


func bind_ai_world(world: Node) -> void:
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
	var balance_diagnostics := _gameplay_balance_diagnostics_node()
	if balance_diagnostics != null and balance_diagnostics.has_method("set_world_bridge"):
		balance_diagnostics.call("set_world_bridge", balance_diagnostics_bridge)
	var card_definition_bridge := _card_runtime_definition_bridge_node()
	if card_definition_bridge != null and card_definition_bridge.has_method("bind_world"):
		card_definition_bridge.call("bind_world", world)
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
	if commodity_flow_bridge != null and commodity_flow_bridge.has_method("bind_world"):
		commodity_flow_bridge.call("bind_world", world)
	var commodity_flow_controller := _commodity_flow_runtime_controller_node()
	if commodity_flow_bridge != null and commodity_flow_bridge.has_method("set_controller"):
		commodity_flow_bridge.call("set_controller", commodity_flow_controller)
	if commodity_flow_bridge != null and commodity_flow_bridge.has_method("set_runtime_dependencies"):
		commodity_flow_bridge.call("set_runtime_dependencies", region_infrastructure, product_market_controller, route_network_controller)
	if commodity_flow_controller != null and commodity_flow_controller.has_method("set_world_bridge"):
		commodity_flow_controller.call("set_world_bridge", commodity_flow_bridge)
	refresh_v06_production_player_bindings(world)
	var bridge := _ai_runtime_world_bridge_node()
	if bridge != null and bridge.has_method("bind_world"):
		bridge.call("bind_world", world)
	var controller := _ai_runtime_controller_node()
	if controller != null and controller.has_method("set_world_bridge"):
		controller.call("set_world_bridge", bridge)
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
	var contract_bridge := _contract_runtime_world_bridge_node()
	if contract_bridge != null and contract_bridge.has_method("bind_world"):
		contract_bridge.call("bind_world", world)
	var contract_controller := _contract_runtime_controller_node()
	if contract_controller != null and contract_controller.has_method("set_world_bridge"):
		contract_controller.call("set_world_bridge", contract_bridge)
	if controller != null and controller.has_method("set_contract_runtime_controller"):
		controller.call("set_contract_runtime_controller", contract_controller)
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
	if contract_bridge != null and contract_bridge.has_method("set_product_market_runtime_controller"):
		contract_bridge.call("set_product_market_runtime_controller", product_market_controller)
	if contract_bridge != null and contract_bridge.has_method("set_route_network_runtime_controller"):
		contract_bridge.call("set_route_network_runtime_controller", route_network_controller)
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
		victory_bridge.call("set_runtime_dependencies", region_infrastructure, commodity_flow_controller, contract_controller, product_market_controller, city_gdp_derivative_controller, military_controller)
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
	var ai_v06_economy_port := _refresh_ai_v06_economy_action_port()
	var binding_ready := not actor_map.is_empty() and state_ready and inventory_ready and core_ready and monster_adapter_ready and public_demand_ready
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
		"ai_v06_economy_port_ready": bool(ai_v06_economy_port.get("available", false)),
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
	var controller := _victory_control_runtime_controller_node()
	if controller == null or not controller.has_method("advance_world_effective"):
		return {"valid": false, "reason": "victory_controller_unavailable"}
	var world_snapshot := victory_control_world_snapshot(clock_pause, "post_world_settlement")
	var value: Variant = controller.call("advance_world_effective", delta_seconds, world_snapshot)
	var result: Dictionary = (value as Dictionary).duplicate(true) if value is Dictionary else {}
	_apply_victory_outcome_receipt(result.get("outcome_receipt", {}) as Dictionary if result.get("outcome_receipt", {}) is Dictionary else {})
	return result


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
	var session := _session_node()
	return bool(session.call("is_finished")) if session != null and session.has_method("is_finished") else false


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


func world_session_state() -> WorldSessionState:
	return _world_session_state_node()


func card_resolution_history_service() -> CardResolutionHistoryRuntimeService:
	return _card_resolution_history_runtime_service_node()


func card_play_submission_controller() -> CardPlaySubmissionRuntimeController:
	return _card_play_submission_runtime_controller_node()


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


func select_card_resolution(resolution_id: int) -> Dictionary:
	var state := _table_selection_state_node()
	if state == null:
		return {"selected": false, "reason": "selection_state_missing"}
	state.selected_card_resolution_id = resolution_id
	return {"selected": true, "resolution_id": state.selected_card_resolution_id}


func execute_active_card_resolution(request: Dictionary) -> Dictionary:
	var execution := _card_resolution_execution_node() as CardResolutionExecutionRuntimeService
	var port := _card_resolution_execution_world_bridge_node() as CardResolutionExecutionWorldBridge
	if execution == null or port == null:
		return {"completed": false, "reason": "typed_execution_path_missing"}
	var transaction := execution.plan_execution(request)
	if not bool(transaction.get("ready", false)):
		return {"completed": false, "reason": str(transaction.get("reason", "execution_plan_rejected")), "transaction": transaction}
	var guard := 0
	while not (transaction.get("next_intent", {}) as Dictionary).is_empty() and guard < 20:
		guard += 1
		var receipt := port.apply_intent(transaction)
		transaction = execution.advance_execution(transaction, receipt)
		if str(transaction.get("status", "")) != CardResolutionExecutionRuntimeService.STATUS_READY:
			break
	if guard >= 20 or str(transaction.get("status", "")) != CardResolutionExecutionRuntimeService.STATUS_READY:
		return {"completed": false, "reason": str(transaction.get("failure_reason", transaction.get("reason", "intent_guard"))), "transaction": transaction}
	var finalized := execution.finalize_execution(transaction)
	if bool(finalized.get("completed", false)):
		settle_card_mana_reservation((transaction.get("active_entry", {}) as Dictionary).duplicate(true) if transaction.get("active_entry", {}) is Dictionary else {}, finalized)
	finalized["transaction"] = transaction
	return finalized


func _wire_run_rng_service() -> void:
	var service := _run_rng_service_node()
	if service == null:
		return
	service.configure({})
	var ai_bridge := _ai_runtime_world_bridge_node()
	var monster_bridge := _monster_runtime_world_bridge_node()
	var weather_bridge := _weather_runtime_world_bridge_node()
	var product_market_bridge := _product_market_runtime_world_bridge_node()
	if ai_bridge is AiRuntimeWorldBridge:
		(ai_bridge as AiRuntimeWorldBridge).set_rng_service(service)
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
	var ai_bridge := _ai_runtime_world_bridge_node()
	var monster_bridge := _monster_runtime_world_bridge_node()
	var military_bridge := _military_runtime_world_bridge_node()
	var market_bridge := _product_market_runtime_world_bridge_node()
	var contract_bridge := _contract_runtime_world_bridge_node()
	var eligibility_bridge := _card_play_world_bridge_node()
	var diagnostics_bridge := _gameplay_balance_diagnostics_world_bridge_node()
	var infrastructure_bridge := _region_infrastructure_world_bridge_node()
	var resolution_bridge := _card_resolution_execution_world_bridge_node()
	var economy_bridge := _card_economy_product_route_effect_world_bridge_node()
	if ai_bridge is AiRuntimeWorldBridge:
		(ai_bridge as AiRuntimeWorldBridge).set_table_selection_state(state)
	if monster_bridge is MonsterRuntimeWorldBridge:
		(monster_bridge as MonsterRuntimeWorldBridge).set_table_selection_state(state)
	if military_bridge is MilitaryRuntimeWorldBridge:
		(military_bridge as MilitaryRuntimeWorldBridge).set_table_selection_state(state)
	if market_bridge is ProductMarketRuntimeWorldBridge:
		(market_bridge as ProductMarketRuntimeWorldBridge).set_table_selection_state(state)
	if contract_bridge is ContractRuntimeWorldBridge:
		(contract_bridge as ContractRuntimeWorldBridge).set_table_selection_state(state)
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
	var ai_bridge := _ai_runtime_world_bridge_node()
	var monster_bridge := _monster_runtime_world_bridge_node()
	var military_bridge := _military_runtime_world_bridge_node()
	var weather_bridge := _weather_runtime_world_bridge_node()
	var market_bridge := _product_market_runtime_world_bridge_node()
	var contract_bridge := _contract_runtime_world_bridge_node()
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
	if ai_bridge is AiRuntimeWorldBridge:
		(ai_bridge as AiRuntimeWorldBridge).set_world_session_state(state)
	if monster_bridge is MonsterRuntimeWorldBridge:
		(monster_bridge as MonsterRuntimeWorldBridge).set_world_session_state(state)
	if military_bridge is MilitaryRuntimeWorldBridge:
		(military_bridge as MilitaryRuntimeWorldBridge).set_world_session_state(state)
	if weather_bridge is WeatherRuntimeWorldBridge:
		(weather_bridge as WeatherRuntimeWorldBridge).set_world_session_state(state)
	if market_bridge is ProductMarketRuntimeWorldBridge:
		(market_bridge as ProductMarketRuntimeWorldBridge).set_world_session_state(state)
	if contract_bridge is ContractRuntimeWorldBridge:
		(contract_bridge as ContractRuntimeWorldBridge).set_world_session_state(state)
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
	var contract := _contract_runtime_controller_node() as ContractRuntimeController
	var session := _session_node() as GameSessionRuntimeController
	var scheduler := _scheduler_node() as ForcedDecisionRuntimeScheduler
	var commodity_flow := _commodity_flow_runtime_controller_node() as CommodityFlowRuntimeController
	var history := _card_resolution_history_runtime_service_node()
	var presentation := _card_resolution_presentation_port_node()
	var intel := _card_intel_runtime_service_node()
	var commitment := _card_commitment_runtime_service_node()
	var counter := _card_counter_settlement_runtime_service_node()
	var effect_router := _card_effect_runtime_router_node()
	var submission := _card_play_submission_runtime_controller_node()
	var economy_port := _card_economy_product_route_effect_world_bridge_node() as CardEconomyProductRouteEffectWorldBridge
	if eligibility_facts != null:
		eligibility_facts.set_runtime_dependencies(queue, resolution, target_choice, monster, military, contract, session, scheduler, commodity_flow)
	if economy_port != null:
		economy_port.set_contract_runtime_controller(contract)
	if intel != null:
		intel.set_dependencies(world_state, selection, history, contract)
	if commitment != null:
		commitment.set_dependencies(world_state, _card_cooldown_runtime_controller_node(), _weather_telemetry_runtime_service_node() as WeatherTelemetryRuntimeService, eligibility_facts, eligibility)
	if effect_router != null:
		effect_router.set_dependencies(
			world_state, selection, monster, military, weather, contract,
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
	if submission != null:
		submission.set_dependencies(
			world_state, selection, eligibility_facts, eligibility, queue, resolution,
			target_choice, contract,
			_product_market_runtime_controller_node() as ProductMarketRuntimeController,
			_city_gdp_derivative_runtime_controller_node() as CityGdpDerivativeRuntimeController,
			self
		)
	var ai := _ai_runtime_controller_node() as AiRuntimeController
	if ai != null:
		ai.set_card_execution_dependencies(submission, history, selection)
	var contract_bridge := _contract_runtime_world_bridge_node() as ContractRuntimeWorldBridge
	if contract_bridge != null:
		contract_bridge.set_card_resolution_history_service(history, queue)


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
	var session := _session_node()
	if session != null and session.has_method("finish_session"):
		session.call("finish_session", receipt)
	var bridge := _victory_control_world_bridge_node()
	if bridge != null and bridge.has_method("apply_outcome_receipt"):
		bridge.call("apply_outcome_receipt", receipt)


func card_runtime_catalog_service() -> CardRuntimeCatalogService:
	return _card_runtime_catalog_node() as CardRuntimeCatalogService


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
		quote_request
	)
	return (
		(value_variant as Dictionary).duplicate(true)
		if value_variant is Dictionary
		else {
			"committed": false,
			"reason_code": "region_supply_purchase_result_invalid",
		}
	)


func commit_district_purchase_with_region_supply(
	player_state: Dictionary,
	current_facts: Dictionary,
	plan: Dictionary,
	listing: Dictionary,
	transaction_id: String
) -> Dictionary:
	if listing.is_empty() \
			or str(listing.get("card_id", "")) != str(current_facts.get("card_id", "")):
		return {"committed": false, "reason": "region_supply_listing_changed"}
	var prepared := prepare_region_supply_slot_refill(
		transaction_id,
		str(listing.get("source_region_id", "")),
		int(listing.get("slot_index", -1)),
		str(listing.get("item_id", "")),
		str(listing.get("supply_revision", ""))
	)
	if not bool(prepared.get("prepared", false)):
		return {"committed": false, "reason": str(prepared.get("reason_code", "region_supply_prepare_failed"))}
	var supply_commit := commit_region_supply_slot_refill(transaction_id)
	if not bool(supply_commit.get("committed", false)):
		rollback_region_supply_slot_refill(transaction_id)
		return {"committed": false, "reason": str(supply_commit.get("reason_code", "region_supply_commit_failed"))}
	var settlement := commit_district_purchase_settlement(player_state, current_facts, plan)
	if not bool(settlement.get("committed", false)):
		var rollback := rollback_region_supply_slot_refill(transaction_id)
		if not bool(rollback.get("rolled_back", false)):
			return {
				"committed": false,
				"reason": "district_purchase_failed_region_supply_rollback_failed",
				"settlement": settlement,
				"region_supply": rollback,
			}
		return settlement
	var finalized := finalize_region_supply_slot_refill(transaction_id)
	var result := settlement.duplicate(true)
	result["region_supply"] = finalized
	result["region_supply_finalized"] = bool(finalized.get("finalized", false))
	return result


func monster_runtime_controller() -> MonsterRuntimeController:
	return _monster_runtime_controller_node() as MonsterRuntimeController


func region_infrastructure_runtime_controller() -> Node:
	return _region_infrastructure_runtime_controller_node()


func region_infrastructure_world_bridge() -> Node:
	return _region_infrastructure_world_bridge_node()


func submit_public_facility_card(request: Dictionary) -> Dictionary:
	var skill: Dictionary = (request.get("skill", {}) as Dictionary).duplicate(true) if request.get("skill", {}) is Dictionary else {}
	if str(skill.get("kind", "")) != "public_facility":
		return {"committed": false, "reason": "legacy_city_development_retired"}
	var transaction_id := str(request.get("transaction_id", "")).strip_edges()
	if transaction_id.is_empty():
		return {"committed": false, "reason": "transaction_id_missing"}
	var bridge := _region_infrastructure_world_bridge_node()
	if bridge == null or not bridge.has_method("submit_legacy_index_facility_action"):
		return {"committed": false, "reason": "region_infrastructure_bridge_missing"}
	var target_region_index := int(request.get("target_region_index", skill.get("target_region_index", -1)))
	var normalized := {
		"transaction_id": transaction_id,
		"owner_kind": "player",
		"owner_player_index": int(request.get("player_index", -1)),
		"facility_type": str(skill.get("facility_type", "")),
		"industry_id": str(skill.get("industry_id", "")),
		"rank": int(skill.get("rank", 0)),
		"occurred_at": float(request.get("occurred_at", 0.0)),
		"source_card_id": str(skill.get("card_id", skill.get("name", ""))),
	}
	var value: Variant = bridge.call("submit_legacy_index_facility_action", target_region_index, normalized)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {"committed": false, "reason": "region_infrastructure_receipt_invalid"}


func military_runtime_controller() -> MilitaryRuntimeController:
	return _military_runtime_controller_node() as MilitaryRuntimeController


func weather_runtime_controller() -> WeatherRuntimeController:
	return _weather_runtime_controller_node() as WeatherRuntimeController


func contract_runtime_controller() -> ContractRuntimeController:
	return _contract_runtime_controller_node() as ContractRuntimeController


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
	var value: Variant = product_market_runtime_call("tick_market_cycle", [delta])
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


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


func v06_rank_i_facility_cards() -> Array:
	var catalog := _v06_runtime_card_catalog()
	if catalog == null or not catalog.has_method("card_ids"):
		return []
	var result: Array = []
	var card_ids_variant: Variant = catalog.call("card_ids")
	var card_ids: Array = card_ids_variant if card_ids_variant is Array else []
	for card_id_variant in card_ids:
		var card := v06_card_definition(str(card_id_variant))
		var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
		if str(machine.get("category_id", "")) != "facility" or int(machine.get("rank", 0)) != 1:
			continue
		if str(machine.get("effect_kind", "")) != "build_upgrade_or_repair_facility":
			continue
		result.append(card)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_machine: Dictionary = a.get("machine", {}) if a.get("machine", {}) is Dictionary else {}
		var b_machine: Dictionary = b.get("machine", {}) if b.get("machine", {}) is Dictionary else {}
		var a_payload: Dictionary = a_machine.get("effect_payload", {}) if a_machine.get("effect_payload", {}) is Dictionary else {}
		var b_payload: Dictionary = b_machine.get("effect_payload", {}) if b_machine.get("effect_payload", {}) is Dictionary else {}
		var a_industry := str(a_payload.get("industry_id", a_machine.get("industry_id", "")))
		var b_industry := str(b_payload.get("industry_id", b_machine.get("industry_id", "")))
		var a_kind := str(a_payload.get("facility_kind", ""))
		var b_kind := str(b_payload.get("facility_kind", ""))
		var a_key := "%s:%d:%s" % [a_industry, 0 if a_kind == "factory" else 1, str(a_machine.get("card_id", ""))]
		var b_key := "%s:%d:%s" % [b_industry, 0 if b_kind == "factory" else 1, str(b_machine.get("card_id", ""))]
		return a_key < b_key
	)
	return result


func v06_facility_card() -> Dictionary:
	var cards := v06_rank_i_facility_cards()
	var bridge := _region_infrastructure_world_bridge_node()
	if cards.is_empty() or bridge == null or not bridge.has_method("selected_region_commodity_facts"):
		return {}
	var facts_variant: Variant = bridge.call("selected_region_commodity_facts")
	var facts: Dictionary = (facts_variant as Dictionary).duplicate(true) if facts_variant is Dictionary else {}
	if not bool(facts.get("available", false)) or not bool(facts.get("authoritative", false)):
		return {}
	var production_industries: Dictionary = {}
	var production_rows: Array = facts.get("production_products", []) if facts.get("production_products", []) is Array else []
	for product_variant in production_rows:
		if product_variant is Dictionary:
			var industry_id := str((product_variant as Dictionary).get("industry_id", ""))
			if not industry_id.is_empty():
				production_industries[industry_id] = true
	var viable_factories := _v06_viable_facility_pair_factories(cards)
	for card_variant in viable_factories:
		var card: Dictionary = card_variant
		var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
		var payload: Dictionary = machine.get("effect_payload", {}) if machine.get("effect_payload", {}) is Dictionary else {}
		if production_industries.has(str(payload.get("industry_id", machine.get("industry_id", "")))):
			return card.duplicate(true)
	if not viable_factories.is_empty():
		return (viable_factories[0] as Dictionary).duplicate(true)
	return {}


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


func _refresh_ai_v06_economy_action_port() -> Dictionary:
	var ai_controller := _ai_runtime_controller_node()
	if ai_controller == null or not ai_controller.has_method("set_v06_economy_action_port"):
		return {"available": false, "revision": 0, "reason_code": "ai_v06_controller_unavailable"}
	if _ai_v06_economy_action_port == null:
		_ai_v06_economy_action_port = AI_V06_ECONOMY_ACTION_PORT.new()
	var binding_variant: Variant = _ai_v06_economy_action_port.call("bind_delegate", self)
	var binding: Dictionary = (binding_variant as Dictionary).duplicate(true) if binding_variant is Dictionary else {}
	if not bool(binding.get("available", false)):
		return binding
	var injected_variant: Variant = ai_controller.call("set_v06_economy_action_port", _ai_v06_economy_action_port)
	return (injected_variant as Dictionary).duplicate(true) if injected_variant is Dictionary else {
		"available": false,
		"revision": 0,
		"reason_code": "ai_v06_economy_port_injection_failed",
	}


# AiV06EconomyActionPort production delegate. These six methods expose only
# narrow pure-data views and forward all mutations to the existing owners.
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


func market_snapshot(actor_id: String) -> Dictionary:
	var normalized_actor_id := actor_id.strip_edges()
	var surface := v06_facility_market_snapshot(normalized_actor_id)
	var market: Dictionary = surface.get("market", {}) if surface.get("market", {}) is Dictionary else {}
	var listing: Dictionary = surface.get("listing", {}) if surface.get("listing", {}) is Dictionary else {}
	var card: Dictionary = listing.get("card", {}) if listing.get("card", {}) is Dictionary else {}
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	var quote: Dictionary = surface.get("quote", {}) if surface.get("quote", {}) is Dictionary else {}
	var revision := maxi(0, int(market.get("revision", 0)))
	if not bool(surface.get("ready", false)) or card.is_empty():
		return _ai_v06_economy_failure(str(surface.get("reason_code", "ai_v06_market_snapshot_unavailable")), revision)
	if not bool(quote.get("confirmable", quote.get("eligible", false))):
		return _ai_v06_economy_failure("ai_v06_market_source_dark", revision)
	var legal_region_ids := _ai_v06_legal_facility_region_ids(card, normalized_actor_id)
	if legal_region_ids.is_empty():
		return _ai_v06_economy_failure("ai_v06_facility_authoritative_target_unavailable", revision)
	return {
		"available": true,
		"revision": revision,
		"reason_code": "ai_v06_market_snapshot_ready",
		"listing": {
			"canonical": true,
			"bootstrap_eligible": _ai_v06_is_rank_i_facility_card(card),
			"item_id": str(listing.get("item_id", "")),
			"card_id": str(machine.get("card_id", "")),
			"category_id": str(machine.get("category_id", "")),
			"rank": int(machine.get("rank", 0)),
			"effect_kind": str(machine.get("effect_kind", "")),
			"purchase_cash": int(quote.get("final_price", listing.get("price_cash", -1))),
			"source_district_index": int(listing.get("source_district_index", -1)),
			"source_region_id": str(listing.get("source_region_id", "")),
			"supply_revision": str(listing.get("supply_revision", "")),
			"target_region_id": str(legal_region_ids[0]),
			"legal_region_ids": legal_region_ids.duplicate(),
		},
	}


func purchase_rank_i_facility(
	actor_id: String,
	item_id: String,
	transaction_id: String,
	expected_market_revision: int,
	expected_player_revision: int,
	expected_source_revision: int
) -> Dictionary:
	var normalized_actor_id := actor_id.strip_edges()
	var normalized_transaction_id := transaction_id.strip_edges()
	var terminal := _ai_v06_inventory_transaction_result(normalized_transaction_id)
	if not terminal.is_empty():
		if str(terminal.get("operation", "")) != "market_purchase" \
				or str(terminal.get("actor_id", "")) != normalized_actor_id \
				or str(terminal.get("source_item_id", "")) != item_id.strip_edges():
			return _ai_v06_economy_failure("ai_v06_facility_purchase_transaction_collision")
		var terminal_replay := _ai_v06_owner_result(terminal, normalized_actor_id)
		terminal_replay["idempotent_replay"] = true
		return terminal_replay
	var source := economic_source_snapshot(normalized_actor_id)
	if not bool(source.get("available", false)) or int(source.get("revision", -1)) != expected_source_revision:
		return _ai_v06_economy_failure("ai_v06_economic_source_revision_stale", maxi(0, int(source.get("revision", 0))))
	var current_market := market_snapshot(normalized_actor_id)
	var listing: Dictionary = current_market.get("listing", {}) if current_market.get("listing", {}) is Dictionary else {}
	if not bool(current_market.get("available", false)) \
			or int(current_market.get("revision", -1)) != expected_market_revision \
			or str(listing.get("item_id", "")) != item_id.strip_edges():
		return _ai_v06_economy_failure("ai_v06_facility_market_revision_stale", maxi(0, int(current_market.get("revision", 0))))
	var current_player := player_snapshot(normalized_actor_id)
	if not bool(current_player.get("available", false)) or int(current_player.get("revision", -1)) != expected_player_revision:
		return _ai_v06_economy_failure("ai_v06_facility_player_revision_stale", maxi(0, int(current_player.get("revision", 0))))
	var value_variant: Variant = purchase_v06_facility_card(normalized_actor_id, item_id, normalized_transaction_id)
	var result: Dictionary = (value_variant as Dictionary).duplicate(true) if value_variant is Dictionary else {}
	return _ai_v06_owner_result(result, normalized_actor_id)


func player_snapshot(actor_id: String) -> Dictionary:
	var normalized_actor_id := actor_id.strip_edges()
	var player := v06_card_player_snapshot(normalized_actor_id)
	if player.is_empty():
		return _ai_v06_economy_failure("ai_v06_player_snapshot_unavailable")
	return {
		"available": true,
		"revision": maxi(0, int(player.get("revision", 0))),
		"reason_code": "ai_v06_player_snapshot_ready",
		"cash": int(player.get("cash", 0)),
		"cards": _ai_v06_facility_card_rows(player),
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


func _ai_v06_facility_card_rows(player: Dictionary) -> Array:
	var result: Array = []
	var inventory: Dictionary = player.get("inventory", {}) if player.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	for slot_index in range(slots.size()):
		if not (slots[slot_index] is Dictionary):
			continue
		var card: Dictionary = slots[slot_index]
		if not _ai_v06_is_rank_i_facility_card(card):
			continue
		var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
		result.append({
			"slot_index": slot_index,
			"runtime_instance_id": str(card.get("runtime_instance_id", "")),
			"card_id": str(machine.get("card_id", "")),
			"category_id": str(machine.get("category_id", "")),
			"rank": int(machine.get("rank", 0)),
			"effect_kind": str(machine.get("effect_kind", "")),
			"bootstrap_eligible": true,
		})
	return result


func _ai_v06_is_rank_i_facility_card(card: Dictionary) -> bool:
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	return str(machine.get("category_id", "")) == "facility" \
		and int(machine.get("rank", 0)) == 1 \
		and str(machine.get("effect_kind", "")) == "build_upgrade_or_repair_facility"


func _ai_v06_current_facility_card(actor_id: String) -> Dictionary:
	var player := v06_card_player_snapshot(actor_id)
	var inventory: Dictionary = player.get("inventory", {}) if player.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	for card_variant in slots:
		if card_variant is Dictionary and _ai_v06_is_rank_i_facility_card(card_variant as Dictionary):
			return (card_variant as Dictionary).duplicate(true)
	var card_inventory := _commodity_card_inventory_runtime_controller_node()
	var market_variant: Variant = card_inventory.call("market_snapshot") if card_inventory != null and card_inventory.has_method("market_snapshot") else {}
	var market: Dictionary = market_variant if market_variant is Dictionary else {}
	var listing: Dictionary = market.get("listing", {}) if market.get("listing", {}) is Dictionary else {}
	var listing_card: Dictionary = listing.get("card", {}) if listing.get("card", {}) is Dictionary else {}
	if _ai_v06_is_rank_i_facility_card(listing_card):
		return listing_card.duplicate(true)
	return v06_facility_card()


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


func v06_facility_market_snapshot(actor_id: String) -> Dictionary:
	var inventory := _commodity_card_inventory_runtime_controller_node()
	if not _configured or inventory == null or not inventory.has_method("market_snapshot"):
		return {"ready": false, "reason_code": "v06_card_runtime_not_ready"}
	var card := v06_facility_card()
	if card.is_empty():
		return {"ready": false, "reason_code": "v06_rank_i_facility_unavailable"}
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	var price_cash := int(machine.get("purchase_cash", -1))
	if price_cash < 0:
		return {"ready": false, "reason_code": "v06_facility_price_invalid"}
	var market_variant: Variant = inventory.call("market_snapshot")
	var market: Dictionary = (market_variant as Dictionary).duplicate(true) if market_variant is Dictionary else {}
	var revision := int(market.get("revision", 0))
	var listing: Dictionary = market.get("listing", {}) if market.get("listing", {}) is Dictionary else {}
	if listing.is_empty():
		listing = _v06_facility_market_listing(card, revision)
		if listing.is_empty():
			return {"ready": false, "reason_code": "v06_market_listing_source_unavailable"}
		var configured_variant: Variant = inventory.call("configure_market", revision, listing)
		var configured: Dictionary = configured_variant if configured_variant is Dictionary else {}
		if not bool(configured.get("configured", false)):
			return {"ready": false, "reason_code": str(configured.get("reason_code", "v06_facility_market_configuration_failed"))}
		market = (configured.get("market", {}) as Dictionary).duplicate(true) if configured.get("market", {}) is Dictionary else {}
		listing = (market.get("listing", {}) as Dictionary).duplicate(true) if market.get("listing", {}) is Dictionary else {}
	elif not _ai_v06_is_rank_i_facility_card(listing.get("card", {}) as Dictionary):
		return {"ready": false, "reason_code": "v06_market_owned_by_other_listing"}
	if int(listing.get("source_district_index", -1)) < 0 or str(listing.get("source_region_id", "")).is_empty() or str(listing.get("supply_revision", "")).is_empty():
		return {"ready": false, "reason_code": "v06_market_listing_source_invalid"}
	var player_index := _ai_v06_actor_player_index(actor_id)
	if player_index < 0:
		return {"ready": false, "reason_code": "v06_facility_player_binding_unavailable"}
	var quote := card_market_quote({
		"player_index": player_index,
		"district_index": int(listing.get("source_district_index", -1)),
		"card_id": str(machine.get("card_id", "")),
		"supply_revision": str(listing.get("supply_revision", "")),
		"base_price": int(listing.get("price_cash", price_cash)),
	})
	var player := v06_card_player_snapshot(actor_id)
	return {
		"ready": not player.is_empty() and not listing.is_empty() and bool(quote.get("viewable", false)),
		"reason_code": "v06_facility_market_ready" if not player.is_empty() and not listing.is_empty() and bool(quote.get("viewable", false)) else "v06_facility_player_unavailable",
		"market": market.duplicate(true),
		"listing": listing.duplicate(true),
		"player": player.duplicate(true),
		"quote": quote.duplicate(true),
	}


func refresh_v06_facility_quote(actor_id: String, expected_card_id: String) -> Dictionary:
	var snapshot := v06_facility_market_snapshot(actor_id)
	var listing: Dictionary = snapshot.get("listing", {}) if snapshot.get("listing", {}) is Dictionary else {}
	var card: Dictionary = listing.get("card", {}) if listing.get("card", {}) is Dictionary else {}
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	var listed_card_id := str(machine.get("card_id", "")).strip_edges()
	if not bool(snapshot.get("ready", false)) or listed_card_id.is_empty() or listed_card_id != expected_card_id.strip_edges():
		return {"confirmable": false, "reason_code": "market_listing_changed"}
	var player_index := _ai_v06_actor_player_index(actor_id)
	var controller := _card_market_pricing_runtime_controller_node()
	if player_index < 0 or controller == null or not controller.has_method("refresh_quote_listing"):
		return {"confirmable": false, "reason_code": "market_quote_unavailable"}
	var value_variant: Variant = controller.call("refresh_quote_listing", {
		"player_index": player_index,
		"district_index": int(listing.get("source_district_index", -1)),
		"card_id": listed_card_id,
		"supply_revision": str(listing.get("supply_revision", "")),
		"base_price": int(listing.get("price_cash", -1)),
	})
	var quote: Dictionary = (value_variant as Dictionary).duplicate(true) if value_variant is Dictionary else {}
	if not str(quote.get("quote_id", "")).is_empty():
		var purchase := _purchase_node()
		if purchase != null and purchase.has_method("attach_quote"):
			purchase.call("attach_quote", player_index, int(listing.get("source_district_index", -1)), quote)
	return quote


func purchase_v06_facility_card(actor_id: String, source_item_id: String, transaction_id: String) -> Dictionary:
	var snapshot := v06_facility_market_snapshot(actor_id)
	if not bool(snapshot.get("ready", false)):
		return {"committed": false, "reason_code": str(snapshot.get("reason_code", "v06_facility_market_unavailable"))}
	var inventory := _commodity_card_inventory_runtime_controller_node()
	var market: Dictionary = snapshot.get("market", {}) if snapshot.get("market", {}) is Dictionary else {}
	var listing: Dictionary = snapshot.get("listing", {}) if snapshot.get("listing", {}) is Dictionary else {}
	var player: Dictionary = snapshot.get("player", {}) if snapshot.get("player", {}) is Dictionary else {}
	if str(listing.get("item_id", "")) != source_item_id.strip_edges():
		return {"committed": false, "reason_code": "market_listing_changed"}
	var card: Dictionary = listing.get("card", {}) if listing.get("card", {}) is Dictionary else {}
	var next_card := _v06_next_rank_i_facility_card(card)
	var next_listing := _v06_facility_market_listing(next_card, int(market.get("revision", 0)) + 1)
	if next_listing.is_empty():
		return {"committed": false, "reason_code": "v06_market_listing_source_unavailable"}
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	var player_index := _ai_v06_actor_player_index(actor_id)
	var quote := card_market_quote({
		"player_index": player_index,
		"district_index": int(listing.get("source_district_index", -1)),
		"card_id": str(machine.get("card_id", "")),
		"supply_revision": str(listing.get("supply_revision", "")),
		"base_price": int(listing.get("price_cash", -1)),
	})
	var quote_request := {
		"quote_id": str(quote.get("quote_id", "")),
		"quote_fingerprint": str(quote.get("quote_fingerprint", "")),
		"player_index": player_index,
		"district_index": int(listing.get("source_district_index", -1)),
		"card_id": str(machine.get("card_id", "")),
		"supply_revision": str(listing.get("supply_revision", "")),
	}
	var value_variant: Variant = inventory.call(
		"purchase_market_card",
		actor_id.strip_edges(),
		source_item_id.strip_edges(),
		next_listing,
		int(player.get("revision", -1)),
		int(market.get("revision", -1)),
		transaction_id.strip_edges(),
		quote_request
	)
	var result: Dictionary = (value_variant as Dictionary).duplicate(true) if value_variant is Dictionary else {}
	result["card_id"] = str(machine.get("card_id", ""))
	result["canonical_price_cash"] = int(quote.get("final_price", -1))
	result["base_price_cash"] = int(listing.get("price_cash", -1))
	if bool(result.get("committed", false)):
		result["public_receipt"] = {
			"event_code": "anonymous_purchase_committed",
			"district_index": int(listing.get("source_district_index", -1)),
			"price_cash": int(result.get("canonical_price_cash", -1)),
		}
	return result


func execute_v06_facility_purchase_action(actor_id: String, expected_card_id: String) -> Dictionary:
	var snapshot := v06_facility_market_snapshot(actor_id)
	if not bool(snapshot.get("ready", false)):
		return compose_action_result_v1({
			"schema_version": 1,
			"action_id": "district_card_purchase",
			"action_family": "card_market",
			"failure_code": str(snapshot.get("reason_code", "v06_facility_market_unavailable")),
		})
	var market: Dictionary = snapshot.get("market", {}) if snapshot.get("market", {}) is Dictionary else {}
	var listing: Dictionary = snapshot.get("listing", {}) if snapshot.get("listing", {}) is Dictionary else {}
	var card: Dictionary = listing.get("card", {}) if listing.get("card", {}) is Dictionary else {}
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	if expected_card_id.strip_edges().is_empty() or str(machine.get("card_id", "")) != expected_card_id.strip_edges():
		return compose_action_result_v1({
			"schema_version": 1,
			"action_id": "district_card_purchase",
			"action_family": "card_market",
			"failure_code": "market_listing_changed",
		})
	var source_item_id := str(listing.get("item_id", ""))
	var transaction_id := "vs06-facility-purchase:%s:%s:%d" % [actor_id.strip_edges(), source_item_id, int(market.get("revision", 0))]
	var owner_result := purchase_v06_facility_card(actor_id, source_item_id, transaction_id)
	var action_source := {
		"schema_version": 1,
		"action_id": "district_card_purchase",
		"action_family": "card_market",
	}
	if bool(owner_result.get("committed", false)):
		action_source["public_receipt"] = (owner_result.get("public_receipt", {}) as Dictionary).duplicate(true) if owner_result.get("public_receipt", {}) is Dictionary else {}
	else:
		action_source["failure_code"] = str(owner_result.get("reason_code", "purchase_conflict"))
	return compose_action_result_v1(action_source)


func v06_facility_purchase_public_state(actor_id: String, expected_card_id: String) -> Dictionary:
	var snapshot := v06_facility_market_snapshot(actor_id)
	var listing: Dictionary = snapshot.get("listing", {}) if snapshot.get("listing", {}) is Dictionary else {}
	var card: Dictionary = listing.get("card", {}) if listing.get("card", {}) is Dictionary else {}
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	var quote: Dictionary = snapshot.get("quote", {}) if snapshot.get("quote", {}) is Dictionary else {}
	var player: Dictionary = snapshot.get("player", {}) if snapshot.get("player", {}) is Dictionary else {}
	var normalized_card_id := expected_card_id.strip_edges()
	var listed_card_id := str(machine.get("card_id", ""))
	var reason_code := str(snapshot.get("reason_code", "v06_facility_market_unavailable"))
	var listing_matches := not listed_card_id.is_empty() and (normalized_card_id.is_empty() or listed_card_id == normalized_card_id)
	var price_cash := maxi(0, int(quote.get("final_price", listing.get("price_cash", 0))))
	var quote_confirmable := bool(quote.get("confirmable", false))
	var cash_ready := int(player.get("cash", 0)) >= price_cash
	var confirmable := bool(snapshot.get("ready", false)) and listing_matches and quote_confirmable and cash_ready
	if not listing_matches:
		reason_code = "market_listing_changed"
	elif not quote_confirmable:
		var availability_kind := str(quote.get("availability_kind", "invalid"))
		if not bool(quote.get("quote_active", false)):
			reason_code = "quote_expired"
		elif availability_kind == "dark":
			reason_code = "source_region_dark"
		elif availability_kind == "destroyed":
			reason_code = "source_region_destroyed"
		else:
			reason_code = str(quote.get("reason_code", "market_quote_unavailable"))
	elif not cash_ready:
		reason_code = "cash_insufficient"
	else:
		reason_code = "facility_purchase_ready"
	return {
		"schema_version": 1,
		"available": bool(snapshot.get("ready", false)) and listing_matches,
		"actionable": confirmable,
		"card_id": listed_card_id if listing_matches else "",
		"price_cash": price_cash,
		"availability_kind": str(quote.get("availability_kind", "invalid")),
		"reason_code": reason_code,
	}


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
		if str(machine.get("card_id", "")).strip_edges() == normalized_card_id and _ai_v06_is_rank_i_facility_card(card):
			slot_index = index
			runtime_instance_id = str(card.get("runtime_instance_id", "")).strip_edges()
			break
	if slot_index < 0 or runtime_instance_id.is_empty():
		action_source["failure_code"] = "ai_v06_facility_card_binding_changed"
		return compose_action_result_v1(action_source)
	var source := economic_source_snapshot(normalized_actor_id)
	var resolved_region_id := normalized_region_id
	var legal_region_ids: Array = source.get("legal_region_ids", []) if source.get("legal_region_ids", []) is Array else []
	if not legal_region_ids.has(resolved_region_id):
		var infrastructure := _region_infrastructure_runtime_controller_node()
		var requested_region_variant: Variant = infrastructure.call("region_snapshot", resolved_region_id) if infrastructure != null and infrastructure.has_method("region_snapshot") else {}
		var requested_region: Dictionary = requested_region_variant if requested_region_variant is Dictionary else {}
		var recommended_region_id := str(source.get("target_region_id", "")).strip_edges()
		if not requested_region.is_empty() and legal_region_ids.has(recommended_region_id):
			resolved_region_id = recommended_region_id
	var clock := world_effective_clock_snapshot()
	var owner_request := {
		"actor_id": normalized_actor_id,
		"slot_index": slot_index,
		"runtime_instance_id": runtime_instance_id,
		"transaction_id": "facility-play:%s:%s:%s" % [normalized_actor_id, runtime_instance_id, resolved_region_id],
		"region_id": resolved_region_id,
		"expected_player_revision": int(player.get("revision", -1)),
		"expected_source_revision": int(source.get("revision", -1)),
		"game_time": float(clock.get("world_effective_seconds", 0.0)),
	}
	var owner_result := play_runtime_card(owner_request)
	var finalized := bool(owner_result.get("committed", false)) and bool(owner_result.get("finalized", false))
	if not finalized:
		action_source["failure_code"] = str(owner_result.get("reason_code", "facility_play_settlement_unavailable"))
		return compose_action_result_v1(action_source)
	var source_after := economic_source_snapshot(normalized_actor_id)
	if not bool(source_after.get("available", false)) or not bool(source_after.get("has_source", false)) \
			or int(source_after.get("owned_facility_count", 0)) < 1 \
			or int(source_after.get("production_installation_count", 0)) < 1:
		action_source["failure_code"] = "facility_play_settlement_unavailable"
		return compose_action_result_v1(action_source)
	action_source["public_receipt"] = {
		"event_code": "facility_play_committed",
		"region_id": resolved_region_id,
		"owned_facility_count": int(source_after.get("owned_facility_count", 0)),
		"production_installation_count": int(source_after.get("production_installation_count", 0)),
		"idempotent_replay": bool(owner_result.get("idempotent_replay", false)),
	}
	return compose_action_result_v1(action_source)


func _v06_runtime_card_catalog() -> Resource:
	var inventory := _commodity_card_inventory_runtime_controller_node()
	if inventory == null or not inventory.has_method("catalog"):
		return null
	var value_variant: Variant = inventory.call("catalog")
	return value_variant as Resource if value_variant is Resource else null


func _v06_facility_market_listing(card: Dictionary, revision: int) -> Dictionary:
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	var source := _v06_market_source_snapshot()
	if source.is_empty():
		return {}
	var item_id := "v06:facility:%d" % maxi(0, revision)
	return {
		"item_id": item_id,
		"card": card.duplicate(true),
		"price_cash": int(machine.get("purchase_cash", -1)),
		"claimable": true,
		"legal_actor_ids": [],
		"source_district_index": int(source.get("district_index", -1)),
		"source_region_id": str(source.get("region_id", "")),
		"supply_revision": "v06-facility:%d:%s" % [maxi(0, revision), item_id],
	}


func _v06_next_rank_i_facility_card(current_card: Dictionary) -> Dictionary:
	var cards := v06_rank_i_facility_cards()
	if cards.is_empty():
		return current_card.duplicate(true)
	var current_machine: Dictionary = current_card.get("machine", {}) if current_card.get("machine", {}) is Dictionary else {}
	var current_payload: Dictionary = current_machine.get("effect_payload", {}) if current_machine.get("effect_payload", {}) is Dictionary else {}
	var current_industry := str(current_payload.get("industry_id", current_machine.get("industry_id", "")))
	var current_kind := str(current_payload.get("facility_kind", ""))
	if current_kind == "factory":
		var market := _v06_facility_card_for_pair(cards, current_industry, "market")
		if not market.is_empty() and not _ai_v06_legal_facility_region_ids(market, "").is_empty():
			return market
	var viable_factories := _v06_viable_facility_pair_factories(cards)
	for index in range(viable_factories.size()):
		var factory: Dictionary = viable_factories[index]
		var machine: Dictionary = factory.get("machine", {}) if factory.get("machine", {}) is Dictionary else {}
		var payload: Dictionary = machine.get("effect_payload", {}) if machine.get("effect_payload", {}) is Dictionary else {}
		if str(payload.get("industry_id", machine.get("industry_id", ""))) == current_industry:
			return (viable_factories[wrapi(index + 1, 0, viable_factories.size())] as Dictionary).duplicate(true)
	if not viable_factories.is_empty():
		return (viable_factories[0] as Dictionary).duplicate(true)
	return current_card.duplicate(true)


func _v06_viable_facility_pair_factories(cards: Array) -> Array:
	var result: Array = []
	for card_variant in cards:
		if not (card_variant is Dictionary):
			continue
		var card: Dictionary = card_variant
		var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
		var payload: Dictionary = machine.get("effect_payload", {}) if machine.get("effect_payload", {}) is Dictionary else {}
		var industry_id := str(payload.get("industry_id", machine.get("industry_id", "")))
		if str(payload.get("facility_kind", "")) != "factory" or industry_id.is_empty():
			continue
		var market := _v06_facility_card_for_pair(cards, industry_id, "market")
		if not market.is_empty() \
				and not _ai_v06_legal_facility_region_ids(card, "").is_empty() \
				and not _ai_v06_legal_facility_region_ids(market, "").is_empty():
			result.append(card.duplicate(true))
	return result


func _v06_facility_card_for_pair(cards: Array, industry_id: String, facility_kind: String) -> Dictionary:
	for card_variant in cards:
		if not (card_variant is Dictionary):
			continue
		var card: Dictionary = card_variant
		var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
		var payload: Dictionary = machine.get("effect_payload", {}) if machine.get("effect_payload", {}) is Dictionary else {}
		if str(payload.get("industry_id", machine.get("industry_id", ""))) == industry_id \
				and str(payload.get("facility_kind", "")) == facility_kind:
			return card.duplicate(true)
	return {}


func _v06_market_source_snapshot() -> Dictionary:
	var state := _world_session_state_node()
	if state == null:
		return {}
	var districts_variant: Variant = state.districts
	var districts: Array = districts_variant if districts_variant is Array else []
	for source_index in range(districts.size()):
		if not (districts[source_index] is Dictionary):
			continue
		var source: Dictionary = districts[source_index]
		var region_id := str(source.get("region_id", "")).strip_edges()
		if bool(source.get("destroyed", false)) or str(source.get("terrain", "land")) == "ocean" or region_id.is_empty():
			continue
		return {
			"district_index": source_index,
			"region_id": region_id,
		}
	return {}


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
	var payload: Dictionary = machine.get("effect_payload", {}) if machine.get("effect_payload", {}) is Dictionary else {}
	var effect_kind := str(machine.get("effect_kind", ""))
	var region_id := str(request.get("region_id", "")).strip_edges()
	var game_time := float(request.get("game_time", 0.0))
	if effect_kind == "build_upgrade_or_repair_facility":
		var infrastructure := _region_infrastructure_runtime_controller_node()
		if infrastructure == null or region_id.is_empty():
			return {"ready": false, "reason_code": "facility_target_region_missing"}
		var facility_kind := str(payload.get("facility_kind", ""))
		var industry_id := str(payload.get("industry_id", machine.get("industry_id", "")))
		var slot_id := str(infrastructure.call("slot_id", region_id, facility_kind, industry_id))
		var region_variant: Variant = infrastructure.call("region_snapshot", region_id)
		var region: Dictionary = region_variant if region_variant is Dictionary else {}
		if region.is_empty() or slot_id.is_empty():
			return {"ready": false, "reason_code": "facility_target_unavailable"}
		return {
			"ready": true,
			"target_context": {
				"valid": true,
				"target_kind": str(machine.get("target_kind", "")),
				"region_id": region_id,
				"slot_id": slot_id,
				"industry_id": industry_id,
				"game_time": game_time,
			},
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


func contract_runtime_call(method_name: StringName, arguments: Array = []) -> Variant:
	var controller := _contract_runtime_controller_node()
	if controller == null or not controller.has_method(method_name):
		push_error("ContractRuntimeController method unavailable: %s" % method_name)
		return null
	return controller.callv(method_name, arguments)


func contract_to_save_data() -> Dictionary:
	var controller := _contract_runtime_controller_node()
	var value: Variant = controller.call("to_save_data") if controller != null and controller.has_method("to_save_data") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func apply_contract_save_data(data: Dictionary) -> Dictionary:
	var controller := _contract_runtime_controller_node()
	var value: Variant = controller.call("apply_save_data", data) if controller != null and controller.has_method("apply_save_data") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func tick_contract_runtime(delta: float) -> Dictionary:
	var controller := _contract_runtime_controller_node()
	var scheduler := _scheduler_node()
	if controller == null or scheduler == null or not controller.has_method("tick_visible_offer") or not scheduler.has_method("debug_snapshot"):
		return {"ticked": false, "reason": "contract_runtime_unavailable"}
	var scheduler_snapshot: Dictionary = scheduler.call("debug_snapshot") as Dictionary
	var candidates: Array = scheduler_snapshot.get("candidates", []) as Array if scheduler_snapshot.get("candidates", []) is Array else []
	var active_id := str((candidates[0] as Dictionary).get("id", "")) if not candidates.is_empty() and candidates[0] is Dictionary else ""
	var value: Variant = controller.call("tick_visible_offer", delta, active_id)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


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
	var controller := _weather_runtime_controller_node()
	if controller == null:
		return
	if controller.has_method("set_new_forecasts_allowed"):
		var victory_state := str(victory_control_public_snapshot().get("state", "idle"))
		controller.call("set_new_forecasts_allowed", victory_state == "idle")
	if controller.has_method("tick"):
		controller.call("tick", delta)


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
	var controller := _military_runtime_controller_node()
	if controller != null and controller.has_method("tick"):
		controller.call("tick", delta)


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


func tick_monster_wagers(delta: float) -> void:
	var controller := _monster_runtime_controller_node()
	if controller != null:
		controller.call("tick_wagers", delta)


func tick_monster_motion(delta: float) -> void:
	var controller := _monster_runtime_controller_node()
	if controller != null:
		controller.call("tick_motion", delta)


func tick_monster_lifecycle(delta: float) -> void:
	var controller := _monster_runtime_controller_node()
	if controller != null:
		controller.call("tick_lifecycle", delta)


func tick_monster_durations(delta: float) -> void:
	var controller := _monster_runtime_controller_node()
	if controller != null:
		controller.call("tick_durations", delta)


func tick_monster_revivals(delta: float) -> void:
	var controller := _monster_runtime_controller_node()
	if controller != null:
		controller.call("tick_revivals", delta)


func tick_monster_actions(delta: float) -> void:
	var controller := _monster_runtime_controller_node()
	if controller != null:
		controller.call("tick_action_timers", delta)


func tick_ai(delta: float) -> void:
	var controller := _ai_runtime_controller_node()
	if controller != null and controller.has_method("tick"):
		controller.call("tick", delta)


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
	_wire_forced_decision_candidate_sources()
	var sources := _forced_decision_candidate_sources_node()
	if sources == null:
		return {"synchronized": false, "reason": "forced_decision_sources_unavailable"}
	return sources.synchronize()


func advance_card_resolution_frame(delta: float) -> Array:
	_wire_card_resolution_frame_driver()
	var driver := _card_resolution_frame_driver_node()
	return driver.advance_world(delta) if driver != null else []


func card_resolution_frame_facts() -> Dictionary:
	_wire_card_resolution_frame_driver()
	var driver := _card_resolution_frame_driver_node()
	return driver.facts_snapshot() if driver != null else {}


func card_resolution_frame_driver_debug() -> Dictionary:
	var driver := _card_resolution_frame_driver_node()
	return driver.debug_snapshot() if driver != null else {}


func advance_card_cooldowns(delta: float) -> Dictionary:
	_wire_card_cooldown_runtime_controller()
	var controller := _card_cooldown_runtime_controller_node()
	return controller.advance_world(delta) if controller != null else {"advanced": false, "reason": "card_cooldown_controller_unavailable"}


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
	var cue_owner := _visual_cue_runtime_owner_node()
	return cue_owner.advance(delta) if cue_owner != null else {"advanced": false, "reason": "visual_cue_owner_unavailable"}


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


func reset_presentation_refresh_cadence() -> Dictionary:
	var scheduler := _table_presentation_refresh_scheduler_node()
	return scheduler.reset_table_cadence() if scheduler != null else {"reset": false, "reason": "presentation_refresh_scheduler_unavailable"}


func request_immediate_presentation_refresh(kind: StringName) -> Dictionary:
	var scheduler := _table_presentation_refresh_scheduler_node()
	return scheduler.request_immediate(kind) if scheduler != null else {"accepted": false, "reason": "presentation_refresh_scheduler_unavailable"}


func presentation_refresh_cadence_debug_snapshot() -> Dictionary:
	var scheduler := _table_presentation_refresh_scheduler_node()
	return scheduler.debug_snapshot() if scheduler != null else {}


func active_forced_decision(viewer_index: int = -1) -> Dictionary:
	synchronize_forced_decisions()
	var scheduler := _scheduler_node()
	if scheduler == null or not scheduler.has_method("active_decision"):
		return {}
	var decision_variant: Variant = scheduler.call("active_decision", viewer_index)
	return (decision_variant as Dictionary).duplicate(true) if decision_variant is Dictionary else {}


func blocks_global_time() -> bool:
	var scheduler := _scheduler_node()
	return scheduler != null and scheduler.has_method("blocks_global_time") and bool(scheduler.call("blocks_global_time"))


func blocks_player_actions(player_index: int) -> bool:
	var scheduler := _scheduler_node()
	return scheduler != null and scheduler.has_method("blocks_player_actions") and bool(scheduler.call("blocks_player_actions", player_index))


func allows_card_resolution_progress() -> bool:
	var scheduler := _scheduler_node()
	return scheduler == null or not scheduler.has_method("blocks_card_resolution") or not bool(scheduler.call("blocks_card_resolution"))


func begin_card_target_choice(kind: String, player_index: int, slot_index: int) -> Dictionary:
	var target_choice_owner := _card_target_choice_runtime_controller_node()
	return target_choice_owner.begin_choice(kind, player_index, slot_index) if target_choice_owner != null else {"accepted": false, "reason": "target_choice_owner_unavailable"}


func card_target_choice_snapshot(kind: String) -> Dictionary:
	var target_choice_owner := _card_target_choice_runtime_controller_node()
	return target_choice_owner.choice_snapshot(kind) if target_choice_owner != null else {}


func card_target_choice_private_snapshot(viewer_index: int) -> Dictionary:
	var target_choice_owner := _card_target_choice_runtime_controller_node()
	return target_choice_owner.private_snapshot(viewer_index) if target_choice_owner != null else {}


func clear_card_target_choice(kind: String) -> Dictionary:
	var target_choice_owner := _card_target_choice_runtime_controller_node()
	return target_choice_owner.clear_choice(kind) if target_choice_owner != null else {"cleared": false, "reason": "target_choice_owner_unavailable"}


func apply_card_target_choice_legacy_state(data: Dictionary) -> Dictionary:
	var target_choice_owner := _card_target_choice_runtime_controller_node()
	return target_choice_owner.apply_legacy_state(data) if target_choice_owner != null else {"applied": false, "reason": "target_choice_owner_unavailable"}


func district_purchase_pending_discard_private_snapshot(viewer_index: int) -> Dictionary:
	var purchase := _purchase_node()
	return purchase.pending_discard_private_snapshot(viewer_index) if purchase != null else {}


func forced_decision_sources_debug() -> Dictionary:
	var sources := _forced_decision_candidate_sources_node()
	return sources.debug_snapshot() if sources != null else {}


func reset_state() -> void:
	_configured = false
	_last_v06_player_binding_result = {
		"ready": false,
		"reason_code": "production_players_not_bound",
	}
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
	var contract_controller := _contract_runtime_controller_node()
	if contract_controller != null and contract_controller.has_method("reset_state"):
		contract_controller.call("reset_state")
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
	var controller := _commodity_flow_runtime_controller_node()
	if controller == null or not controller.has_method("advance_world"):
		return {"advanced": false, "reason": "commodity_flow_runtime_missing", "receipt_count": 0}
	var merged := blocking_snapshot.duplicate(true)
	var session := _session_node()
	merged["global_blocked"] = bool(merged.get("global_blocked", false)) or blocks_global_time()
	merged["session_paused"] = bool(merged.get("session_paused", false)) or (session != null and session.has_method("session_state") and str(session.call("session_state")) == "paused")
	var value: Variant = controller.call("advance_world", delta_seconds, merged)
	var flow_result: Dictionary = (value as Dictionary).duplicate(true) if value is Dictionary else {}
	if not bool(flow_result.get("advanced", false)):
		return flow_result
	var bankruptcy_estate := _bankruptcy_neutral_estate_runtime_controller_node()
	if bankruptcy_estate == null or not bankruptcy_estate.has_method("settle_checkpoint"):
		flow_result["bankruptcy_checkpoint"] = {"finalized": false, "reason_code": "bankruptcy_checkpoint_missing"}
		return flow_result
	var bankruptcy_variant: Variant = bankruptcy_estate.call("settle_checkpoint", {
		"transaction_id": "bankruptcy:%s" % str(flow_result.get("batch_id", "")),
		"reason_code": "post_sale_receipt",
		"occurred_at": float(merged.get("game_time", 0.0)),
	})
	flow_result["bankruptcy_checkpoint"] = (bankruptcy_variant as Dictionary).duplicate(true) if bankruptcy_variant is Dictionary else {}
	if not bool((flow_result.get("bankruptcy_checkpoint", {}) as Dictionary).get("finalized", false)):
		return flow_result
	var player_count := maxi(0, int(merged.get("player_count", 0)))
	var color_gdp_by_player: Dictionary = {}
	for player_index in range(player_count):
		color_gdp_by_player[str(player_index)] = commodity_color_flow_snapshot(player_index)
	var mana := _player_mana_runtime_controller_node()
	if mana == null or not mana.has_method("advance"):
		flow_result["asset_recovery"] = {"advanced": false, "reason": "player_mana_runtime_missing"}
		return flow_result
	var recovery_variant: Variant = mana.call(
		"advance",
		maxi(1, int(round(delta_seconds * 1000.0))),
		float(merged.get("game_time", 0.0)),
		color_gdp_by_player
	)
	flow_result["asset_recovery"] = (recovery_variant as Dictionary).duplicate(true) if recovery_variant is Dictionary else {}
	return flow_result


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
		session.call("finish_session", result_summary)


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
		return {"ok": false, "error_code": ERR_UNCONFIGURED, "payload": {}}
	var result_variant: Variant = session.call("request_load", path)
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


func compose_intel_dossier_snapshot(source: Dictionary) -> Dictionary:
	var service := _intel_dossier_public_snapshot_node()
	var value: Variant = service.call("compose", source) if service != null and service.has_method("compose") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func compose_district_supply_snapshot(source: Dictionary) -> Dictionary:
	var service := _district_supply_snapshot_node()
	if service == null or not service.has_method("compose"):
		push_error("GameRuntimeCoordinator requires DistrictSupplySnapshotService.")
		return {}
	var value: Variant = service.call("compose", source)
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
	var route_network_runtime_snapshot := _route_network_runtime_debug_snapshot()
	var commodity_flow_runtime_snapshot := _commodity_flow_runtime_debug_snapshot()
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
	var contract_runtime_snapshot := _contract_runtime_debug_snapshot()
	var victory_control_runtime_snapshot := _victory_control_runtime_debug_snapshot()
	var victory_control_world_bridge_snapshot := _victory_control_world_bridge_debug_snapshot()
	return {
		"coordinator_ready": _configured,
		"coordinator_composition_ready": _composition_ready,
		"v06_production_player_bindings_ready": bool(_last_v06_player_binding_result.get("ready", false)),
		"v06_production_player_bindings": _last_v06_player_binding_result.duplicate(true),
		"coordinator_authoritative": _configured and bool(scheduler_snapshot.get("scheduler_authoritative", false)) and bool(card_runtime_catalog_snapshot.get("service_authoritative", false)) and bool(session_snapshot.get("session_authoritative", false)) and bool(purchase_snapshot.get("controller_authoritative", false)) and bool(card_inventory_snapshot.get("service_authoritative", false)) and bool(card_resolution_queue_snapshot.get("service_authoritative", false)) and bool(card_resolution_execution_snapshot.get("service_authoritative", false)) and bool(economy_product_route_effect_snapshot.get("service_authoritative", false)) and bool(economy_product_route_formula_snapshot.get("service_authoritative", false)) and bool(product_market_runtime_snapshot.get("controller_authoritative", false)) and bool(city_gdp_derivative_runtime_snapshot.get("controller_authoritative", false)) and bool(commodity_flow_runtime_snapshot.get("controller_authoritative", false)) and bool(hand_interaction_snapshot.get("service_authoritative", false)) and bool(purchase_settlement_snapshot.get("service_authoritative", false)) and bool(codex_navigation_snapshot.get("controller_authoritative", false)) and bool(codex_public_snapshot.get("service_authoritative", false)) and bool(monster_codex_public_snapshot.get("service_authoritative", false)) and bool(monster_codex_public_source.get("service_authoritative", false)) and bool(product_codex_public_snapshot.get("service_authoritative", false)) and bool(product_codex_public_source.get("service_authoritative", false)) and bool(card_codex_public_snapshot.get("service_authoritative", false)) and bool(economy_dashboard_public_snapshot.get("service_authoritative", false)) and bool(standings_public_snapshot.get("service_authoritative", false)) and bool(final_settlement_public_snapshot.get("service_authoritative", false)) and bool(intel_dossier_public_snapshot.get("service_authoritative", false)) and bool(district_supply_snapshot.get("service_authoritative", false)) and bool(card_presentation_snapshot.get("service_authoritative", false)) and bool(card_play_eligibility_snapshot.get("service_authoritative", false)) and bool(table_viewmodel_snapshot.get("service_authoritative", false)) and bool(monster_runtime_snapshot.get("controller_authoritative", false)) and bool(military_runtime_snapshot.get("controller_authoritative", false)) and bool(weather_runtime_snapshot.get("controller_authoritative", false)) and bool(contract_runtime_snapshot.get("controller_authoritative", false)),
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
		"route_network_runtime": route_network_runtime_snapshot,
		"commodity_flow_runtime": commodity_flow_runtime_snapshot,
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
		"contract_runtime": contract_runtime_snapshot,
		"victory_control_runtime": victory_control_runtime_snapshot,
		"victory_control_world_bridge": victory_control_world_bridge_snapshot,
	}


func _scheduler_node() -> Node:
	return get_node_or_null("ForcedDecisionRuntimeScheduler")


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
		_contract_runtime_controller_node() as ContractRuntimeController,
		_purchase_node() as DistrictPurchaseRuntimeController,
		_card_target_choice_runtime_controller_node(),
		_scheduler_node() as ForcedDecisionRuntimeScheduler
	)


func _card_resolution_runtime_controller_node() -> CardResolutionRuntimeController:
	return get_node_or_null("CardResolutionRuntimeController") as CardResolutionRuntimeController


func _card_resolution_frame_driver_node() -> CardResolutionFrameDriver:
	return get_node_or_null("CardResolutionFrameDriver") as CardResolutionFrameDriver


func _wire_card_resolution_frame_driver() -> void:
	var driver := _card_resolution_frame_driver_node()
	if driver == null:
		return
	driver.configure(
		_card_resolution_runtime_controller_node(),
		_card_resolution_queue_node() as CardResolutionQueueRuntimeService,
		_world_session_state_node(),
		_card_play_eligibility_node() as CardPlayEligibilityRuntimeService
	)


func _card_cooldown_runtime_controller_node() -> CardCooldownRuntimeController:
	return get_node_or_null("CardCooldownRuntimeController") as CardCooldownRuntimeController


func _visual_cue_runtime_owner_node() -> VisualCueRuntimeOwner:
	return get_node_or_null("VisualCueRuntimeOwner") as VisualCueRuntimeOwner


func _table_presentation_refresh_scheduler_node() -> Node:
	return get_node_or_null("TablePresentationRefreshScheduler")


func _wire_card_cooldown_runtime_controller() -> void:
	var controller := _card_cooldown_runtime_controller_node()
	if controller != null:
		controller.configure(_world_session_state_node())


func _region_supply_card_descriptor(card_id: String) -> Dictionary:
	if card_id.is_empty() or not card_exists(card_id):
		return {}
	var definition := card_definition(card_id)
	var rank := card_rank(card_id)
	if definition.is_empty() or rank != 1:
		return {}
	var kind := str(definition.get("kind", "ordinary"))
	var machine: Dictionary = definition.get("machine", {}) if definition.get("machine", {}) is Dictionary else {}
	var machine_price := int(machine.get("purchase_cash", -1))
	var purchase_cash := machine_price
	if purchase_cash < 0:
		var balance_model := RUNTIME_BALANCE_MODEL_SCRIPT.new()
		purchase_cash = int(balance_model.call("card_price_for_skill", definition))
	var allowed_terrain: Array = []
	if definition.get("allowed_terrain", []) is Array:
		allowed_terrain = (definition.get("allowed_terrain", []) as Array).duplicate()
	var legal_region_ids: Array = []
	if definition.get("legal_region_ids", []) is Array:
		legal_region_ids = (definition.get("legal_region_ids", []) as Array).duplicate()
	var disabled_region_ids: Array = []
	if definition.get("disabled_region_ids", []) is Array:
		disabled_region_ids = (definition.get("disabled_region_ids", []) as Array).duplicate()
	var required_mode_tags: Array = []
	if definition.get("required_mode_tags", []) is Array:
		required_mode_tags = (definition.get("required_mode_tags", []) as Array).duplicate()
	return {
		"card_id": card_id,
		"family_id": card_family_id(card_id),
		"card_type": str(definition.get("card_type", kind)),
		"rank": rank,
		"name": card_id,
		"display_name": str(definition.get("display_name", definition.get("name", card_id))),
		"price_cash": maxi(0, purchase_cash),
		"target_type": str(definition.get("target_type", definition.get("target_kind", ""))),
		"effect_text": str(definition.get("effect_text", definition.get("text", ""))),
		"requirement_text": str(definition.get("requirement_text", definition.get("play_requirement_text", ""))),
		"route_tags": (definition.get("route_tags", []) as Array).duplicate()
			if definition.get("route_tags", []) is Array
			else [],
		"art_key": str(definition.get("art_key", card_id)),
		"enabled": bool(definition.get("enabled", true)),
		"retired": bool(definition.get("retired", false)),
		"valid": true,
		"potential_target_exists": bool(definition.get("potential_target_exists", true)),
		"is_commodity": kind in ["commodity", "installed_commodity"],
		"region_supply_weight": maxi(1, int(definition.get("region_supply_weight", 1))),
		"global_unique": bool(definition.get("global_unique", false)),
		"unique_key": str(definition.get("unique_key", card_family_id(card_id))),
		"legal_region_ids": legal_region_ids,
		"disabled_region_ids": disabled_region_ids,
		"allowed_terrain": allowed_terrain,
		"required_mode_tags": required_mode_tags,
	}


func _card_runtime_catalog_node() -> Node:
	return get_node_or_null("CardRuntimeCatalogService")


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


func _player_mana_runtime_controller_node() -> Node:
	return get_node_or_null("PlayerManaRuntimeController")


func _commodity_card_inventory_runtime_controller_node() -> Node:
	return get_node_or_null("CommodityCardInventoryRuntimeController")


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


func _ai_runtime_world_bridge_node() -> Node:
	return get_node_or_null("AiRuntimeWorldBridge")


func _monster_runtime_controller_node() -> Node:
	return get_node_or_null("MonsterRuntimeController")


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


func _contract_runtime_controller_node() -> Node:
	return get_node_or_null("ContractRuntimeController")


func _contract_runtime_world_bridge_node() -> Node:
	return get_node_or_null("ContractRuntimeWorldBridge")


func _card_play_eligibility_node() -> Node:
	return get_node_or_null("CardPlayEligibilityRuntimeService")


func _card_play_world_bridge_node() -> Node:
	return get_node_or_null("CardPlayEligibilityWorldBridge")


func _card_resolution_execution_world_bridge_node() -> Node:
	return get_node_or_null("CardResolutionExecutionWorldBridge")


func _card_resolution_history_runtime_service_node() -> CardResolutionHistoryRuntimeService:
	return get_node_or_null("CardResolutionHistoryRuntimeService") as CardResolutionHistoryRuntimeService


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


func _contract_runtime_debug_snapshot() -> Dictionary:
	var controller := _contract_runtime_controller_node()
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
