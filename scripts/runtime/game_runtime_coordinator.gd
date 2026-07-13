@tool
extends Node
class_name GameRuntimeCoordinator

var _ruleset_id := ""
var _configured := false


func configure(ruleset_snapshot: Dictionary) -> void:
	_ruleset_id = str(ruleset_snapshot.get("ruleset_id", ""))
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
	if session != null and session.has_method("configure"):
		session.call("configure", ruleset_snapshot, {})
	var purchase := _purchase_node()
	if purchase != null and purchase.has_method("configure"):
		var timing_variant: Variant = ruleset_snapshot.get("timing", {})
		purchase.call("configure", timing_variant if timing_variant is Dictionary else {})
	var card_inventory := _card_inventory_node()
	if card_inventory != null and card_inventory.has_method("configure"):
		card_inventory.call("configure", ruleset_snapshot)
	var card_resolution_queue := _card_resolution_queue_node()
	if card_resolution_queue != null and card_resolution_queue.has_method("configure"):
		card_resolution_queue.call("configure", ruleset_snapshot)
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
	var economy := _economy_node()
	if economy != null and economy.has_method("configure"):
		economy.call("configure", ruleset_snapshot, {})
	var gdp_formula := _gdp_formula_node()
	if gdp_formula != null and gdp_formula.has_method("configure"):
		gdp_formula.call("configure", {})
	var city_trade_network_controller := _city_trade_network_runtime_controller_node()
	var city_trade_network_bridge := _city_trade_network_world_bridge_node()
	if city_trade_network_controller != null and city_trade_network_controller.has_method("set_world_bridge"):
		city_trade_network_controller.call("set_world_bridge", city_trade_network_bridge)
	if city_trade_network_controller != null and city_trade_network_controller.has_method("set_gdp_formula_controller"):
		city_trade_network_controller.call("set_gdp_formula_controller", gdp_formula)
	if city_trade_network_controller != null and city_trade_network_controller.has_method("set_cashflow_controller"):
		city_trade_network_controller.call("set_cashflow_controller", economy)
	if city_trade_network_controller != null and city_trade_network_controller.has_method("set_formula_service"):
		city_trade_network_controller.call("set_formula_service", economy_product_route_formula)
	if city_trade_network_controller != null and city_trade_network_controller.has_method("configure"):
		city_trade_network_controller.call("configure", ruleset_snapshot)
	var city_development_controller := _city_development_runtime_controller_node()
	var city_development_bridge := _city_development_world_bridge_node()
	if city_development_bridge != null and city_development_bridge.has_method("set_runtime_dependencies"):
		city_development_bridge.call("set_runtime_dependencies", city_trade_network_controller, city_trade_network_bridge, product_market_controller)
	if city_development_controller != null and city_development_controller.has_method("configure"):
		city_development_controller.call("configure", ruleset_snapshot)
	var scenario := _scenario_node()
	if scenario != null and scenario.has_method("configure"):
		scenario.call("configure", {})
	var first_table_authored := _first_table_authored_node()
	if first_table_authored != null and first_table_authored.has_method("configure"):
		var first_table_definition: Dictionary = scenario.call("scenario_definition", "first_table") if scenario != null and scenario.has_method("scenario_definition") else {}
		first_table_authored.call("configure", {"scenario_definition": first_table_definition})
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
		card_play_eligibility.call("configure", ruleset_snapshot)
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
	if weather_controller != null and weather_controller.has_method("set_world_bridge"):
		weather_controller.call("set_world_bridge", weather_world_bridge)
	if weather_controller != null and weather_controller.has_method("configure"):
		weather_controller.call("configure", ruleset_snapshot)
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
	if ai_controller != null and ai_controller.has_method("set_city_development_runtime"):
		ai_controller.call("set_city_development_runtime", city_development_controller, city_development_bridge)
	if ai_controller != null and ai_controller.has_method("set_victory_control_runtime_controller"):
		ai_controller.call("set_victory_control_runtime_controller", victory_controller)
	if ai_controller != null and ai_controller.has_method("configure"):
		ai_controller.call("configure", ruleset_snapshot, ai_controller.get("policy_profile"))
	if monster_controller != null and monster_controller.has_method("set_world_bridge"):
		monster_controller.call("set_world_bridge", monster_world_bridge)
	if monster_controller != null and monster_controller.has_method("set_product_market_runtime_controller"):
		monster_controller.call("set_product_market_runtime_controller", product_market_controller)
	if monster_controller != null and monster_controller.has_method("set_card_runtime_catalog_service"):
		monster_controller.call("set_card_runtime_catalog_service", card_runtime_catalog)
	if monster_controller != null and monster_controller.has_method("configure"):
		monster_controller.call("configure", ruleset_snapshot)
	if military_controller != null and military_controller.has_method("set_world_bridge"):
		military_controller.call("set_world_bridge", military_world_bridge)
	if military_controller != null and military_controller.has_method("set_monster_runtime_controller"):
		military_controller.call("set_monster_runtime_controller", monster_controller)
	if military_controller != null and military_controller.has_method("set_inventory_service"):
		military_controller.call("set_inventory_service", card_inventory)
	if military_controller != null and military_controller.has_method("set_product_market_runtime_controller"):
		military_controller.call("set_product_market_runtime_controller", product_market_controller)
	if military_controller != null and military_controller.has_method("set_card_runtime_catalog_service"):
		military_controller.call("set_card_runtime_catalog_service", card_runtime_catalog)
	if military_controller != null and military_controller.has_method("configure"):
		military_controller.call("configure", ruleset_snapshot)
	if weather_controller != null and weather_controller.has_method("set_product_market_runtime_controller"):
		weather_controller.call("set_product_market_runtime_controller", product_market_controller)
	if victory_world_bridge != null and victory_world_bridge.has_method("set_runtime_dependencies"):
		victory_world_bridge.call("set_runtime_dependencies", city_trade_network_controller, contract_controller, product_market_controller, city_gdp_derivative_controller, military_controller)
	if victory_controller != null and victory_controller.has_method("set_world_bridge"):
		victory_controller.call("set_world_bridge", victory_world_bridge)
	if victory_controller != null and victory_controller.has_method("configure"):
		victory_controller.call("configure")
	var session_snapshot := _session_debug_snapshot()
	var purchase_snapshot := _purchase_debug_snapshot()
	var card_inventory_snapshot := _card_inventory_debug_snapshot()
	var card_runtime_catalog_snapshot := _card_runtime_catalog_debug_snapshot()
	var card_definition_bridge_snapshot := _card_runtime_definition_bridge_debug_snapshot()
	var balance_diagnostics_snapshot := _gameplay_balance_diagnostics_debug_snapshot()
	var card_resolution_queue_snapshot := _card_resolution_queue_debug_snapshot()
	var card_resolution_execution_snapshot := _card_resolution_execution_debug_snapshot()
	var economy_product_route_effect_snapshot := _card_economy_product_route_effect_debug_snapshot()
	var economy_product_route_formula_snapshot := _card_economy_product_route_formula_debug_snapshot()
	var product_market_snapshot := _product_market_runtime_debug_snapshot()
	var city_gdp_derivative_snapshot := _city_gdp_derivative_runtime_debug_snapshot()
	var city_trade_network_snapshot := _city_trade_network_runtime_debug_snapshot()
	var city_development_snapshot := _city_development_runtime_debug_snapshot()
	var city_development_bridge_snapshot := _city_development_world_bridge_debug_snapshot()
	var hand_interaction_snapshot := _player_hand_interaction_debug_snapshot()
	var purchase_settlement_snapshot := _purchase_settlement_debug_snapshot()
	var economy_snapshot := _economy_debug_snapshot()
	var gdp_formula_snapshot := _gdp_formula_debug_snapshot()
	var scenario_snapshot := _scenario_debug_snapshot()
	var first_table_authored_snapshot := _first_table_authored_debug_snapshot()
	var codex_navigation_snapshot := _codex_navigation_debug_snapshot()
	var codex_public_snapshot_debug := _codex_public_snapshot_debug_snapshot()
	var monster_codex_public_snapshot_debug := _monster_codex_public_snapshot_debug_snapshot()
	var product_codex_public_snapshot_debug := _product_codex_public_snapshot_debug_snapshot()
	var card_codex_public_snapshot_debug := _card_codex_public_snapshot_debug_snapshot()
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
	_configured = _ruleset_id == "v0.4" and scheduler != null and not priority_order.is_empty() and bool(card_runtime_catalog_snapshot.get("service_ready", false)) and bool(card_definition_bridge_snapshot.get("bridge_ready", false)) and bool(balance_diagnostics_snapshot.get("service_ready", false)) and bool(session_snapshot.get("session_ready", false)) and bool(purchase_snapshot.get("controller_ready", false)) and bool(card_inventory_snapshot.get("service_ready", false)) and bool(card_resolution_queue_snapshot.get("service_ready", false)) and bool(card_resolution_execution_snapshot.get("service_ready", false)) and bool(economy_product_route_effect_snapshot.get("service_ready", false)) and bool(economy_product_route_formula_snapshot.get("service_ready", false)) and bool(product_market_snapshot.get("controller_ready", false)) and bool(city_gdp_derivative_snapshot.get("controller_ready", false)) and bool(city_trade_network_snapshot.get("controller_ready", false)) and bool(city_development_snapshot.get("controller_ready", false)) and bool(city_development_bridge_snapshot.get("bridge_ready", false)) and bool(hand_interaction_snapshot.get("service_ready", false)) and bool(purchase_settlement_snapshot.get("service_ready", false)) and bool(economy_snapshot.get("controller_ready", false)) and bool(gdp_formula_snapshot.get("controller_ready", false)) and bool(scenario_snapshot.get("controller_ready", false)) and bool(first_table_authored_snapshot.get("service_ready", false)) and bool(codex_navigation_snapshot.get("controller_ready", false)) and bool(codex_public_snapshot_debug.get("service_ready", false)) and bool(monster_codex_public_snapshot_debug.get("service_ready", false)) and bool(product_codex_public_snapshot_debug.get("service_ready", false)) and bool(card_codex_public_snapshot_debug.get("service_ready", false)) and bool(economy_dashboard_public_snapshot_debug.get("service_ready", false)) and bool(standings_public_snapshot_debug.get("service_ready", false)) and bool(final_settlement_public_snapshot_debug.get("service_ready", false)) and bool(intel_dossier_public_snapshot_debug.get("service_ready", false)) and bool(district_supply_snapshot_state.get("service_ready", false)) and bool(card_presentation_snapshot.get("service_ready", false)) and bool(card_play_eligibility_snapshot.get("service_ready", false)) and bool(card_play_world_bridge_snapshot.get("bridge_ready", false)) and bool(table_viewmodel_snapshot.get("service_ready", false)) and bool(ai_snapshot.get("controller_ready", false)) and bool(monster_snapshot.get("controller_ready", false)) and bool(military_snapshot.get("controller_ready", false)) and bool(weather_snapshot.get("controller_ready", false)) and bool(contract_snapshot.get("controller_ready", false)) and bool(victory_snapshot.get("controller_ready", false))


func bind_ai_world(world: Node) -> void:
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
	var city_trade_network_bridge := _city_trade_network_world_bridge_node()
	if city_trade_network_bridge != null and city_trade_network_bridge.has_method("bind_world"):
		city_trade_network_bridge.call("bind_world", world)
	var city_trade_network_controller := _city_trade_network_runtime_controller_node()
	if city_trade_network_controller != null and city_trade_network_controller.has_method("set_world_bridge"):
		city_trade_network_controller.call("set_world_bridge", city_trade_network_bridge)
	var city_development_bridge := _city_development_world_bridge_node()
	if city_development_bridge != null and city_development_bridge.has_method("bind_world"):
		city_development_bridge.call("bind_world", world)
	if city_development_bridge != null and city_development_bridge.has_method("set_runtime_dependencies"):
		city_development_bridge.call("set_runtime_dependencies", city_trade_network_controller, city_trade_network_bridge, product_market_controller)
	var bridge := _ai_runtime_world_bridge_node()
	if bridge != null and bridge.has_method("bind_world"):
		bridge.call("bind_world", world)
	var controller := _ai_runtime_controller_node()
	if controller != null and controller.has_method("set_world_bridge"):
		controller.call("set_world_bridge", bridge)
	if controller != null and controller.has_method("set_gameplay_balance_diagnostics_service"):
		controller.call("set_gameplay_balance_diagnostics_service", balance_diagnostics)
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
	if controller != null and controller.has_method("set_city_development_runtime"):
		controller.call("set_city_development_runtime", _city_development_runtime_controller_node(), city_development_bridge)
	if monster_controller != null and monster_controller.has_method("set_product_market_runtime_controller"):
		monster_controller.call("set_product_market_runtime_controller", product_market_controller)
	if military_controller != null and military_controller.has_method("set_product_market_runtime_controller"):
		military_controller.call("set_product_market_runtime_controller", product_market_controller)
	if weather_controller != null and weather_controller.has_method("set_product_market_runtime_controller"):
		weather_controller.call("set_product_market_runtime_controller", product_market_controller)
	if contract_bridge != null and contract_bridge.has_method("set_product_market_runtime_controller"):
		contract_bridge.call("set_product_market_runtime_controller", product_market_controller)
	var effect_bridge := _card_economy_product_route_effect_world_bridge_node()
	if effect_bridge != null and effect_bridge.has_method("set_product_market_runtime_controller"):
		effect_bridge.call("set_product_market_runtime_controller", product_market_controller)
	if effect_bridge != null and effect_bridge.has_method("set_city_gdp_derivative_runtime_controller"):
		effect_bridge.call("set_city_gdp_derivative_runtime_controller", city_gdp_derivative_controller)
	var victory_bridge := _victory_control_world_bridge_node()
	if victory_bridge != null and victory_bridge.has_method("bind_world"):
		victory_bridge.call("bind_world", world)
	if victory_bridge != null and victory_bridge.has_method("set_runtime_dependencies"):
		victory_bridge.call("set_runtime_dependencies", city_trade_network_controller, contract_controller, product_market_controller, city_gdp_derivative_controller, military_controller)
	var victory_controller := _victory_control_runtime_controller_node()
	if victory_controller != null and victory_controller.has_method("set_world_bridge"):
		victory_controller.call("set_world_bridge", victory_bridge)
	if controller != null and controller.has_method("set_victory_control_runtime_controller"):
		controller.call("set_victory_control_runtime_controller", victory_controller)


func victory_control_runtime_controller() -> VictoryControlRuntimeController:
	return _victory_control_runtime_controller_node() as VictoryControlRuntimeController


func victory_control_world_bridge() -> VictoryControlWorldBridge:
	return _victory_control_world_bridge_node() as VictoryControlWorldBridge


func victory_control_world_snapshot(clock_pause: Dictionary = {}) -> Dictionary:
	var bridge := _victory_control_world_bridge_node()
	var value: Variant = bridge.call("capture_world_snapshot", clock_pause) if bridge != null and bridge.has_method("capture_world_snapshot") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func advance_victory_control(delta_seconds: float, clock_pause: Dictionary = {}) -> Dictionary:
	var controller := _victory_control_runtime_controller_node()
	if controller == null or not controller.has_method("advance_world_effective"):
		return {"valid": false, "reason": "victory_controller_unavailable"}
	var world_snapshot := victory_control_world_snapshot(clock_pause)
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


func monster_runtime_controller() -> MonsterRuntimeController:
	return _monster_runtime_controller_node() as MonsterRuntimeController


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


func city_trade_network_runtime_controller() -> CityTradeNetworkRuntimeController:
	return _city_trade_network_runtime_controller_node() as CityTradeNetworkRuntimeController


func city_trade_network_runtime_world_bridge() -> CityTradeNetworkWorldBridge:
	return _city_trade_network_world_bridge_node() as CityTradeNetworkWorldBridge


func city_trade_network_runtime_call(method_name: StringName, arguments: Array = []) -> Variant:
	var controller := _city_trade_network_runtime_controller_node()
	if controller == null or not controller.has_method(method_name):
		push_error("CityTradeNetworkRuntimeController method unavailable: %s" % method_name)
		return null
	return controller.callv(method_name, arguments)


func city_trade_network_to_save_data() -> Dictionary:
	var value: Variant = city_trade_network_runtime_call("to_save_data")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func apply_city_trade_network_save_data(data: Dictionary) -> Dictionary:
	var value: Variant = city_trade_network_runtime_call("apply_save_data", [data])
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func refresh_city_trade_networks() -> Dictionary:
	var value: Variant = city_trade_network_runtime_call("refresh_networks")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func city_development_runtime_controller() -> CityDevelopmentRuntimeController:
	return _city_development_runtime_controller_node() as CityDevelopmentRuntimeController


func city_development_world_bridge() -> CityDevelopmentWorldBridge:
	return _city_development_world_bridge_node() as CityDevelopmentWorldBridge


func city_development_site_status(player_index: int, district_index: int, require_empty_city := true, require_cooldown := false) -> Dictionary:
	var controller := _city_development_runtime_controller_node()
	var bridge := _city_development_world_bridge_node()
	if controller == null or bridge == null or not controller.has_method("evaluate_development_site") or not bridge.has_method("capture_site_facts"):
		return {"allowed": false, "reason": "城市发展运行时服务不可用。", "reason_code": "runtime_unavailable", "player_index": player_index, "district_index": district_index}
	var facts_variant: Variant = bridge.call("capture_site_facts", player_index, district_index, require_empty_city, require_cooldown)
	var facts: Dictionary = facts_variant if facts_variant is Dictionary else {}
	var value: Variant = controller.call("evaluate_development_site", facts)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {"allowed": false, "reason": "城市发展目标检查失败。", "reason_code": "site_evaluation_failed"}


func execute_city_development(runtime_request: Dictionary) -> Dictionary:
	var controller := _city_development_runtime_controller_node()
	var bridge := _city_development_world_bridge_node()
	if controller == null or bridge == null:
		return {"resolved": false, "committed": false, "reason": "city_development_runtime_unavailable", "reason_code": "city_development_runtime_unavailable"}
	var player_index := int(runtime_request.get("player_index", -1))
	var skill: Dictionary = (runtime_request.get("skill", {}) as Dictionary).duplicate(true) if runtime_request.get("skill", {}) is Dictionary else {}
	var district_index := int(runtime_request.get("district_index", skill.get("development_target_district", -1)))
	skill["development_target_district"] = district_index
	var request := {
		"source_kind": "city_development_card",
		"action_id": str(runtime_request.get("action_id", skill.get("action_id", ""))),
		"player_index": player_index,
		"district_index": district_index,
		"product_id": str(skill.get("product_id", "")),
		"project_direction": str(skill.get("project_direction", "production")),
		"slot_id": str(runtime_request.get("slot_id", skill.get("slot_id", ""))),
		"slot_index": int(runtime_request.get("slot_index", skill.get("slot_index", -1))),
		"allowed_terrains": (skill.get("allowed_terrains", []) as Array).duplicate(true) if skill.get("allowed_terrains", []) is Array else [],
		"skill": skill.duplicate(true),
	}
	var facts_variant: Variant = bridge.call("capture_settlement_facts", request)
	var facts: Dictionary = facts_variant if facts_variant is Dictionary else {}
	var plan_variant: Variant = controller.call("plan_settlement", request, facts)
	var plan: Dictionary = plan_variant if plan_variant is Dictionary else {}
	if not bool(plan.get("valid", false)):
		var plan_reason := str(plan.get("reason_code", plan.get("reason", "settlement_plan_rejected")))
		return {"resolved": false, "committed": false, "reason": plan_reason, "reason_code": plan_reason, "project_id": str(plan.get("project_id", ""))}
	var preflight_variant: Variant = bridge.call("preflight_settlement", plan)
	var preflight: Dictionary = preflight_variant if preflight_variant is Dictionary else {}
	var current_facts: Dictionary = preflight.get("facts", {}) as Dictionary if preflight.get("facts", {}) is Dictionary else {}
	var validation_variant: Variant = controller.call("validate_settlement_plan", plan, current_facts)
	var validation: Dictionary = validation_variant if validation_variant is Dictionary else {}
	if not bool(preflight.get("valid", false)) or not bool(validation.get("valid", false)):
		var failure_reason := str(preflight.get("reason_code", preflight.get("reason", "preflight_failed"))) if not bool(preflight.get("valid", false)) else str(validation.get("reason_code", validation.get("reason", "validation_failed")))
		return controller.call("finalize_settlement", {"applied": false, "reason": failure_reason, "reason_code": failure_reason, "project_id": str(plan.get("project_id", ""))}) as Dictionary
	controller.call("record_project_opened", {
		"project_id": str(plan.get("project_id", "")),
		"slot_id": str(plan.get("slot_id", "")),
		"slot_index": int(plan.get("slot_index", -1)),
		"generation": int(plan.get("generation", 0)),
		"district_index": district_index,
		"product_id": str(plan.get("product_id", "")),
		"project_direction": str(plan.get("project_direction", "")),
		"source_kind": "city_development_card",
		"action_id": str(plan.get("action_id", "")),
		"created_city_surface": bool(plan.get("created_city_surface", false)),
	})
	var receipt_variant: Variant = bridge.call("apply_settlement_plan", plan)
	var receipt: Dictionary = receipt_variant if receipt_variant is Dictionary else {"applied": false, "reason": "settlement_receipt_missing", "reason_code": "settlement_receipt_missing", "project_id": str(plan.get("project_id", ""))}
	var finalized_variant: Variant = controller.call("finalize_settlement", receipt)
	var finalized: Dictionary = finalized_variant if finalized_variant is Dictionary else {"resolved": false, "committed": false, "reason": "settlement_finalize_failed"}
	if bool(finalized.get("committed", false)):
		var event_result_variant: Variant = bridge.call("apply_post_commit_intents", finalized)
		var event_result: Dictionary = event_result_variant if event_result_variant is Dictionary else {}
		finalized["events_applied"] = bool(event_result.get("applied", false))
		finalized["event_reason"] = str(event_result.get("reason", ""))
		finalized["public_receipt"] = (receipt.get("public_receipt", {}) as Dictionary).duplicate(true) if receipt.get("public_receipt", {}) is Dictionary else {}
	return finalized


func city_development_debug_snapshot() -> Dictionary:
	return {
		"controller": _city_development_runtime_debug_snapshot(),
		"world_bridge": _city_development_world_bridge_debug_snapshot(),
	}


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
	if controller != null and controller.has_method("tick"):
		controller.call("tick", delta)


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


func sync_forced_decision_candidates(candidates: Array) -> void:
	var scheduler := _scheduler_node()
	if scheduler != null and scheduler.has_method("sync_candidates"):
		scheduler.call("sync_candidates", candidates)


func active_forced_decision(viewer_index: int = -1) -> Dictionary:
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


func reset_state() -> void:
	sync_forced_decision_candidates([])
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
	var city_trade_network_controller := _city_trade_network_runtime_controller_node()
	if city_trade_network_controller != null and city_trade_network_controller.has_method("reset_state"):
		city_trade_network_controller.call("reset_state")
	var city_development_controller := _city_development_runtime_controller_node()
	if city_development_controller != null and city_development_controller.has_method("reset_state"):
		city_development_controller.call("reset_state")
	var city_development_bridge := _city_development_world_bridge_node()
	if city_development_bridge != null and city_development_bridge.has_method("reset_state"):
		city_development_bridge.call("reset_state")
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
	var economy := _economy_node()
	if economy != null and economy.has_method("reset_state"):
		economy.call("reset_state")


func open_district_purchase_window(player_index: int, district_index: int, qualification_snapshot: Dictionary) -> Dictionary:
	var purchase := _purchase_node()
	if purchase == null or not purchase.has_method("open_window"):
		return {}
	var value: Variant = purchase.call("open_window", player_index, district_index, qualification_snapshot)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func build_district_purchase_qualification(world_snapshot: Dictionary) -> Dictionary:
	var purchase := _purchase_node()
	if purchase == null or not purchase.has_method("build_qualification_snapshot"):
		return {}
	var value: Variant = purchase.call("build_qualification_snapshot", world_snapshot)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func resolve_district_purchase_access_kind(player_index: int, district_index: int, live_qualification: Dictionary) -> String:
	var purchase := _purchase_node()
	return str(purchase.call("resolve_access_kind", player_index, district_index, live_qualification)) if purchase != null and purchase.has_method("resolve_access_kind") else "none"


func resolve_district_purchase_price_multiplier(player_index: int, district_index: int, live_qualification: Dictionary) -> float:
	var purchase := _purchase_node()
	return float(purchase.call("resolve_price_multiplier", player_index, district_index, live_qualification)) if purchase != null and purchase.has_method("resolve_price_multiplier") else 1.0


func district_purchase_access_text(access_kind: String, price_context: Dictionary = {}) -> String:
	var purchase := _purchase_node()
	return str(purchase.call("access_text", access_kind, price_context)) if purchase != null and purchase.has_method("access_text") else ""


func close_district_purchase_window(player_index: int, reason: String = "closed") -> Dictionary:
	var purchase := _purchase_node()
	if purchase == null or not purchase.has_method("close_window"):
		return {}
	var value: Variant = purchase.call("close_window", player_index, reason)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func tick_district_purchase_windows(delta: float, blocked_player_indices: Array = []) -> Array:
	var purchase := _purchase_node()
	if purchase == null or not purchase.has_method("tick_window"):
		return []
	var session := _session_node()
	var blocking_snapshot := {
		"global_blocked": blocks_global_time(),
		"session_paused": session != null and session.has_method("session_state") and str(session.call("session_state")) == "paused",
		"blocked_player_indices": blocked_player_indices.duplicate(),
	}
	var value: Variant = purchase.call("tick_window", delta, blocking_snapshot)
	return (value as Array).duplicate(true) if value is Array else []


func district_purchase_window(player_index: int) -> Dictionary:
	var purchase := _purchase_node()
	if purchase == null or not purchase.has_method("active_window"):
		return {}
	var value: Variant = purchase.call("active_window", player_index)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func district_purchase_window_active(player_index: int, district_index: int = -1) -> bool:
	var purchase := _purchase_node()
	return purchase != null and purchase.has_method("is_window_active") and bool(purchase.call("is_window_active", player_index, district_index))


func district_purchase_access_kind(player_index: int, district_index: int) -> String:
	var purchase := _purchase_node()
	return str(purchase.call("locked_access_kind", player_index, district_index)) if purchase != null and purchase.has_method("locked_access_kind") else "none"


func district_purchase_price_context(player_index: int, district_index: int) -> Dictionary:
	var purchase := _purchase_node()
	if purchase == null or not purchase.has_method("locked_price_context"):
		return {}
	var value: Variant = purchase.call("locked_price_context", player_index, district_index)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func authorize_district_purchase(request_snapshot: Dictionary) -> Dictionary:
	var purchase := _purchase_node()
	if purchase == null or not purchase.has_method("authorize_purchase"):
		return {"authorized": false, "reason": "controller_missing", "price_context": {}}
	var value: Variant = purchase.call("authorize_purchase", request_snapshot)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


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
	return _card_resolution_queue_dictionary_call("plan_submission", [request_snapshot, facts])


func commit_card_resolution_queue_submission(plan: Dictionary, commit_receipt: Dictionary) -> Dictionary:
	return _card_resolution_queue_dictionary_call("commit_submission", [plan, commit_receipt])


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
		reserve_district_purchase_discard({"player_index": int(pending_discard.get("player_index", -1)), "district_index": int(pending_discard.get("district_index", -1)), "card_id": str(pending_discard.get("skill_name", ""))})
	return restored


func district_purchase_private_ui_snapshot(viewer_index: int) -> Dictionary:
	var purchase := _purchase_node()
	if purchase == null or not purchase.has_method("private_ui_snapshot"):
		return {}
	var value: Variant = purchase.call("private_ui_snapshot", viewer_index)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func advance_economy_cashflow(delta_seconds: float, blocking_snapshot: Dictionary = {}) -> Array:
	var economy := _economy_node()
	if economy == null or not economy.has_method("advance_clock"):
		return []
	var merged := blocking_snapshot.duplicate(true)
	var session := _session_node()
	merged["global_blocked"] = bool(merged.get("global_blocked", false)) or blocks_global_time()
	merged["session_paused"] = bool(merged.get("session_paused", false)) or (session != null and session.has_method("session_state") and str(session.call("session_state")) == "paused")
	var value: Variant = economy.call("advance_clock", delta_seconds, merged)
	return (value as Array).duplicate(true) if value is Array else []


func settle_economy_sources(seconds: float, income_source_snapshot: Dictionary) -> Dictionary:
	var economy := _economy_node()
	if economy == null or not economy.has_method("settle_sources"):
		return {"valid": false, "payout_total": 0, "payout_events": []}
	var value: Variant = economy.call("settle_sources", seconds, income_source_snapshot)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func economy_cashflow_accumulator_seconds() -> float:
	var economy := _economy_node()
	return float(economy.call("accumulator_seconds")) if economy != null and economy.has_method("accumulator_seconds") else 0.0


func economy_cashflow_legacy_save_snapshot() -> Dictionary:
	var economy := _economy_node()
	if economy == null or not economy.has_method("to_legacy_save_snapshot"):
		return {}
	var value: Variant = economy.call("to_legacy_save_snapshot")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func apply_economy_cashflow_legacy_save_snapshot(snapshot: Dictionary) -> void:
	var economy := _economy_node()
	if economy != null and economy.has_method("apply_legacy_save_snapshot"):
		economy.call("apply_legacy_save_snapshot", snapshot)


func economy_cashflow_private_ui_snapshot(viewer_index: int) -> Dictionary:
	var economy := _economy_node()
	if economy == null or not economy.has_method("private_ui_snapshot"):
		return {}
	var value: Variant = economy.call("private_ui_snapshot", viewer_index)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func calculate_city_gdp(input_snapshot: Dictionary) -> Dictionary:
	var gdp_formula := _gdp_formula_node()
	if gdp_formula == null or not gdp_formula.has_method("calculate_city_gdp"):
		return {}
	var value: Variant = gdp_formula.call("calculate_city_gdp", input_snapshot)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func gdp_formula_parameters() -> Dictionary:
	var gdp_formula := _gdp_formula_node()
	if gdp_formula == null or not gdp_formula.has_method("parameters_snapshot"):
		return {}
	var value: Variant = gdp_formula.call("parameters_snapshot")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func gdp_formula_breakdown_summary(breakdown: Dictionary) -> String:
	var gdp_formula := _gdp_formula_node()
	return str(gdp_formula.call("breakdown_summary", breakdown)) if gdp_formula != null and gdp_formula.has_method("breakdown_summary") else ""


func gdp_formula_change_reason_text(breakdown: Dictionary) -> String:
	var gdp_formula := _gdp_formula_node()
	return str(gdp_formula.call("change_reason_text", breakdown)) if gdp_formula != null and gdp_formula.has_method("change_reason_text") else ""


func scenario_catalog() -> Array:
	var scenario := _scenario_node()
	var value: Variant = scenario.call("scenario_catalog") if scenario != null and scenario.has_method("scenario_catalog") else []
	return (value as Array).duplicate(true) if value is Array else []


func scenario_definition(scenario_id: String) -> Dictionary:
	var scenario := _scenario_node()
	var value: Variant = scenario.call("scenario_definition", scenario_id) if scenario != null and scenario.has_method("scenario_definition") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func first_table_fixture_snapshot() -> Dictionary:
	var service := _first_table_authored_node()
	var value: Variant = service.call("fixture_snapshot") if service != null and service.has_method("fixture_snapshot") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func first_table_resolve_content_catalog(catalog_snapshot: Dictionary) -> Dictionary:
	var service := _first_table_authored_node()
	var value: Variant = service.call("resolve_content_catalog", catalog_snapshot) if service != null and service.has_method("resolve_content_catalog") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func first_table_pacing_profile() -> Dictionary:
	var service := _first_table_authored_node()
	var value: Variant = service.call("pacing_profile") if service != null and service.has_method("pacing_profile") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func first_table_evaluate_pacing(runtime_snapshot: Dictionary) -> Dictionary:
	var service := _first_table_authored_node()
	var value: Variant = service.call("evaluate_pacing", runtime_snapshot) if service != null and service.has_method("evaluate_pacing") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func first_table_supply_plan(resolved_catalog: Dictionary) -> Dictionary:
	var service := _first_table_authored_node()
	var value: Variant = service.call("supply_plan", resolved_catalog) if service != null and service.has_method("supply_plan") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func first_table_select_teaching_product(district_snapshot: Dictionary, resolved_catalog: Dictionary) -> String:
	var service := _first_table_authored_node()
	return str(service.call("select_teaching_product", district_snapshot, resolved_catalog)) if service != null and service.has_method("select_teaching_product") else ""


func first_table_compose_runtime_content(world_snapshot: Dictionary, resolved_catalog: Dictionary) -> Dictionary:
	var service := _first_table_authored_node()
	var value: Variant = service.call("compose_runtime_content", world_snapshot, resolved_catalog) if service != null and service.has_method("compose_runtime_content") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func first_table_contextualize_phase(phase_snapshot: Dictionary, content_snapshot: Dictionary) -> Dictionary:
	var service := _first_table_authored_node()
	var value: Variant = service.call("contextualize_phase", phase_snapshot, content_snapshot) if service != null and service.has_method("contextualize_phase") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func first_table_completion_summary(content_snapshot: Dictionary) -> String:
	var service := _first_table_authored_node()
	return str(service.call("completion_summary", content_snapshot)) if service != null and service.has_method("completion_summary") else ""


func first_table_completion_label(content_snapshot: Dictionary) -> String:
	var service := _first_table_authored_node()
	return str(service.call("completion_label", content_snapshot)) if service != null and service.has_method("completion_label") else ""


func first_table_score_district(district_snapshot: Dictionary, resolved_catalog: Dictionary) -> int:
	var service := _first_table_authored_node()
	return int(service.call("score_district", district_snapshot, resolved_catalog)) if service != null and service.has_method("score_district") else -1000000


func start_runtime_scenario(scenario_id: String, now_seconds: float) -> Dictionary:
	var scenario := _scenario_node()
	var value: Variant = scenario.call("start_scenario", scenario_id, now_seconds) if scenario != null and scenario.has_method("start_scenario") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func clear_runtime_scenario() -> void:
	var scenario := _scenario_node()
	if scenario != null and scenario.has_method("clear_scenario"):
		scenario.call("clear_scenario")


func active_runtime_scenario_id() -> String:
	var scenario := _scenario_node()
	return str(scenario.call("active_scenario_id")) if scenario != null and scenario.has_method("active_scenario_id") else ""


func runtime_scenario_progress(now_seconds: float) -> Dictionary:
	var scenario := _scenario_node()
	var value: Variant = scenario.call("progress_snapshot", now_seconds) if scenario != null and scenario.has_method("progress_snapshot") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func complete_runtime_scenario_signal(signal_id: String, event_snapshot: Dictionary, now_seconds: float) -> Dictionary:
	var scenario := _scenario_node()
	var value: Variant = scenario.call("complete_signal", signal_id, event_snapshot, now_seconds) if scenario != null and scenario.has_method("complete_signal") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func record_runtime_scenario_action(entry_snapshot: Dictionary) -> Dictionary:
	var scenario := _scenario_node()
	var value: Variant = scenario.call("record_action", entry_snapshot) if scenario != null and scenario.has_method("record_action") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func record_runtime_scenario_failed_attempt(phase_id: String, entry_snapshot: Dictionary, now_seconds: float) -> Dictionary:
	var scenario := _scenario_node()
	var value: Variant = scenario.call("record_failed_attempt", phase_id, entry_snapshot, now_seconds) if scenario != null and scenario.has_method("record_failed_attempt") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func set_runtime_scenario_coach_closed(closed: bool) -> void:
	var scenario := _scenario_node()
	if scenario != null and scenario.has_method("set_coach_closed"):
		scenario.call("set_coach_closed", closed)


func set_runtime_scenario_snapshot_key(snapshot_key: String) -> void:
	var scenario := _scenario_node()
	if scenario != null and scenario.has_method("set_snapshot_key"):
		scenario.call("set_snapshot_key", snapshot_key)


func runtime_scenario_state(now_seconds: float = 0.0) -> Dictionary:
	var scenario := _scenario_node()
	var value: Variant = scenario.call("runtime_state_snapshot", now_seconds) if scenario != null and scenario.has_method("runtime_state_snapshot") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func runtime_scenario_viewer_action_log(viewer_index: int, include_developer: bool = false) -> Array:
	var scenario := _scenario_node()
	var value: Variant = scenario.call("viewer_action_log", viewer_index, include_developer) if scenario != null and scenario.has_method("viewer_action_log") else []
	return (value as Array).duplicate(true) if value is Array else []


func build_runtime_scenario_visual_event_request(scenario_id: String, snapshot_key: String, trigger_id: String = "") -> Dictionary:
	var scenario := _scenario_node()
	var value: Variant = scenario.call("build_visual_event_request", scenario_id, snapshot_key, trigger_id) if scenario != null and scenario.has_method("build_visual_event_request") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


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


func compose_codex_region_snapshot(source: Dictionary) -> Dictionary:
	var service := _codex_public_snapshot_node()
	var value: Variant = service.call("compose_region", source) if service != null and service.has_method("compose_region") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func codex_role_route_label(role_card: Dictionary, starting_cash_delta: int = 0) -> String:
	var service := _codex_public_snapshot_node()
	return str(service.call("role_route_label", role_card, starting_cash_delta)) if service != null and service.has_method("role_route_label") else "通用经营"


func compose_monster_codex_snapshot(source: Dictionary) -> Dictionary:
	var service := _monster_codex_public_snapshot_node()
	var value: Variant = service.call("compose", source) if service != null and service.has_method("compose") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func compose_product_codex_snapshot(source: Dictionary) -> Dictionary:
	var service := _product_codex_public_snapshot_node()
	var value: Variant = service.call("compose", source) if service != null and service.has_method("compose") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func compose_card_codex_browser(source: Dictionary) -> Dictionary:
	var service := _card_codex_public_snapshot_node()
	var value: Variant = service.call("compose_browser", source) if service != null and service.has_method("compose_browser") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func compose_card_codex_detail(source: Dictionary) -> Dictionary:
	var service := _card_codex_public_snapshot_node()
	var value: Variant = service.call("compose_detail", source) if service != null and service.has_method("compose_detail") else {}
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
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


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
	var card_runtime_catalog_snapshot := _card_runtime_catalog_debug_snapshot()
	var card_definition_bridge_snapshot := _card_runtime_definition_bridge_debug_snapshot()
	var balance_diagnostics_snapshot := _gameplay_balance_diagnostics_debug_snapshot()
	var card_inventory_snapshot := _card_inventory_debug_snapshot()
	var card_resolution_queue_snapshot := _card_resolution_queue_debug_snapshot()
	var card_resolution_execution_snapshot := _card_resolution_execution_debug_snapshot()
	var economy_product_route_effect_snapshot := _card_economy_product_route_effect_debug_snapshot()
	var economy_product_route_formula_snapshot := _card_economy_product_route_formula_debug_snapshot()
	var product_market_runtime_snapshot := _product_market_runtime_debug_snapshot()
	var city_gdp_derivative_runtime_snapshot := _city_gdp_derivative_runtime_debug_snapshot()
	var city_trade_network_runtime_snapshot := _city_trade_network_runtime_debug_snapshot()
	var city_development_runtime_snapshot := _city_development_runtime_debug_snapshot()
	var city_development_world_bridge_snapshot := _city_development_world_bridge_debug_snapshot()
	var hand_interaction_snapshot := _player_hand_interaction_debug_snapshot()
	var purchase_settlement_snapshot := _purchase_settlement_debug_snapshot()
	var economy_snapshot := _economy_debug_snapshot()
	var gdp_formula_snapshot := _gdp_formula_debug_snapshot()
	var scenario_snapshot := _scenario_debug_snapshot()
	var first_table_authored_snapshot := _first_table_authored_debug_snapshot()
	var codex_navigation_snapshot := _codex_navigation_debug_snapshot()
	var codex_public_snapshot := _codex_public_snapshot_debug_snapshot()
	var monster_codex_public_snapshot := _monster_codex_public_snapshot_debug_snapshot()
	var product_codex_public_snapshot := _product_codex_public_snapshot_debug_snapshot()
	var card_codex_public_snapshot := _card_codex_public_snapshot_debug_snapshot()
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
	var monster_runtime_snapshot := _monster_runtime_debug_snapshot()
	var military_runtime_snapshot := _military_runtime_debug_snapshot()
	var weather_runtime_snapshot := _weather_runtime_debug_snapshot()
	var contract_runtime_snapshot := _contract_runtime_debug_snapshot()
	var victory_control_runtime_snapshot := _victory_control_runtime_debug_snapshot()
	var victory_control_world_bridge_snapshot := _victory_control_world_bridge_debug_snapshot()
	return {
		"coordinator_ready": _configured and bool(scheduler_snapshot.get("scheduler_ready", false)) and bool(card_runtime_catalog_snapshot.get("service_ready", false)) and bool(card_definition_bridge_snapshot.get("bridge_ready", false)) and bool(balance_diagnostics_snapshot.get("service_ready", false)) and bool(session_snapshot.get("session_ready", false)) and bool(purchase_snapshot.get("controller_ready", false)) and bool(card_inventory_snapshot.get("service_ready", false)) and bool(card_resolution_queue_snapshot.get("service_ready", false)) and bool(card_resolution_execution_snapshot.get("service_ready", false)) and bool(economy_product_route_effect_snapshot.get("service_ready", false)) and bool(economy_product_route_formula_snapshot.get("service_ready", false)) and bool(product_market_runtime_snapshot.get("controller_ready", false)) and bool(city_gdp_derivative_runtime_snapshot.get("controller_ready", false)) and bool(city_trade_network_runtime_snapshot.get("controller_ready", false)) and bool(city_development_runtime_snapshot.get("controller_ready", false)) and bool(city_development_world_bridge_snapshot.get("bridge_ready", false)) and bool(hand_interaction_snapshot.get("service_ready", false)) and bool(purchase_settlement_snapshot.get("service_ready", false)) and bool(economy_snapshot.get("controller_ready", false)) and bool(gdp_formula_snapshot.get("controller_ready", false)) and bool(scenario_snapshot.get("controller_ready", false)) and bool(first_table_authored_snapshot.get("service_ready", false)) and bool(codex_navigation_snapshot.get("controller_ready", false)) and bool(codex_public_snapshot.get("service_ready", false)) and bool(monster_codex_public_snapshot.get("service_ready", false)) and bool(product_codex_public_snapshot.get("service_ready", false)) and bool(card_codex_public_snapshot.get("service_ready", false)) and bool(economy_dashboard_public_snapshot.get("service_ready", false)) and bool(standings_public_snapshot.get("service_ready", false)) and bool(final_settlement_public_snapshot.get("service_ready", false)) and bool(intel_dossier_public_snapshot.get("service_ready", false)) and bool(district_supply_snapshot.get("service_ready", false)) and bool(card_presentation_snapshot.get("service_ready", false)) and bool(card_play_eligibility_snapshot.get("service_ready", false)) and bool(card_play_world_bridge_snapshot.get("bridge_ready", false)) and bool(table_viewmodel_snapshot.get("service_ready", false)) and bool(ai_runtime_snapshot.get("controller_ready", false)) and bool(monster_runtime_snapshot.get("controller_ready", false)) and bool(military_runtime_snapshot.get("controller_ready", false)) and bool(weather_runtime_snapshot.get("controller_ready", false)) and bool(contract_runtime_snapshot.get("controller_ready", false)),
		"coordinator_authoritative": _configured and bool(scheduler_snapshot.get("scheduler_authoritative", false)) and bool(card_runtime_catalog_snapshot.get("service_authoritative", false)) and bool(session_snapshot.get("session_authoritative", false)) and bool(purchase_snapshot.get("controller_authoritative", false)) and bool(card_inventory_snapshot.get("service_authoritative", false)) and bool(card_resolution_queue_snapshot.get("service_authoritative", false)) and bool(card_resolution_execution_snapshot.get("service_authoritative", false)) and bool(economy_product_route_effect_snapshot.get("service_authoritative", false)) and bool(economy_product_route_formula_snapshot.get("service_authoritative", false)) and bool(product_market_runtime_snapshot.get("controller_authoritative", false)) and bool(city_gdp_derivative_runtime_snapshot.get("controller_authoritative", false)) and bool(city_trade_network_runtime_snapshot.get("controller_authoritative", false)) and bool(city_development_runtime_snapshot.get("controller_authoritative", false)) and bool(hand_interaction_snapshot.get("service_authoritative", false)) and bool(purchase_settlement_snapshot.get("service_authoritative", false)) and bool(economy_snapshot.get("controller_authoritative", false)) and bool(gdp_formula_snapshot.get("controller_authoritative", false)) and bool(scenario_snapshot.get("controller_authoritative", false)) and bool(first_table_authored_snapshot.get("service_authoritative", false)) and bool(codex_navigation_snapshot.get("controller_authoritative", false)) and bool(codex_public_snapshot.get("service_authoritative", false)) and bool(monster_codex_public_snapshot.get("service_authoritative", false)) and bool(product_codex_public_snapshot.get("service_authoritative", false)) and bool(card_codex_public_snapshot.get("service_authoritative", false)) and bool(economy_dashboard_public_snapshot.get("service_authoritative", false)) and bool(standings_public_snapshot.get("service_authoritative", false)) and bool(final_settlement_public_snapshot.get("service_authoritative", false)) and bool(intel_dossier_public_snapshot.get("service_authoritative", false)) and bool(district_supply_snapshot.get("service_authoritative", false)) and bool(card_presentation_snapshot.get("service_authoritative", false)) and bool(card_play_eligibility_snapshot.get("service_authoritative", false)) and bool(table_viewmodel_snapshot.get("service_authoritative", false)) and bool(monster_runtime_snapshot.get("controller_authoritative", false)) and bool(military_runtime_snapshot.get("controller_authoritative", false)) and bool(weather_runtime_snapshot.get("controller_authoritative", false)) and bool(contract_runtime_snapshot.get("controller_authoritative", false)),
		"ruleset_id": _ruleset_id,
		"forced_decision_scheduler": scheduler_snapshot,
		"card_runtime_catalog": card_runtime_catalog_snapshot,
		"card_runtime_definition_bridge": card_definition_bridge_snapshot,
		"gameplay_balance_diagnostics": balance_diagnostics_snapshot,
		"game_session": session_snapshot,
		"district_purchase": purchase_snapshot,
		"card_inventory": card_inventory_snapshot,
		"card_resolution_queue": card_resolution_queue_snapshot,
		"card_resolution_execution": card_resolution_execution_snapshot,
		"card_economy_product_route_effect": economy_product_route_effect_snapshot,
		"card_economy_product_route_formula": economy_product_route_formula_snapshot,
		"product_market_runtime": product_market_runtime_snapshot,
		"city_gdp_derivative_runtime": city_gdp_derivative_runtime_snapshot,
		"city_trade_network_runtime": city_trade_network_runtime_snapshot,
		"city_development_runtime": city_development_runtime_snapshot,
		"city_development_world_bridge": city_development_world_bridge_snapshot,
		"player_hand_interaction": hand_interaction_snapshot,
		"district_purchase_settlement": purchase_settlement_snapshot,
		"economy_cashflow": economy_snapshot,
		"gdp_formula": gdp_formula_snapshot,
		"scenario_runtime": scenario_snapshot,
		"first_table_authored_runtime": first_table_authored_snapshot,
		"codex_navigation_runtime": codex_navigation_snapshot,
		"codex_public_snapshot": codex_public_snapshot,
		"monster_codex_public_snapshot": monster_codex_public_snapshot,
		"product_codex_public_snapshot": product_codex_public_snapshot,
		"card_codex_public_snapshot": card_codex_public_snapshot,
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
		"monster_runtime": monster_runtime_snapshot,
		"military_runtime": military_runtime_snapshot,
		"weather_runtime": weather_runtime_snapshot,
		"contract_runtime": contract_runtime_snapshot,
		"victory_control_runtime": victory_control_runtime_snapshot,
		"victory_control_world_bridge": victory_control_world_bridge_snapshot,
	}


func _scheduler_node() -> Node:
	return get_node_or_null("ForcedDecisionRuntimeScheduler")


func _card_runtime_catalog_node() -> Node:
	return get_node_or_null("CardRuntimeCatalogService")


func _card_runtime_definition_bridge_node() -> Node:
	return get_node_or_null("CardRuntimeDefinitionWorldBridge")


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


func _city_trade_network_runtime_controller_node() -> Node:
	return get_node_or_null("CityTradeNetworkRuntimeController")


func _city_trade_network_world_bridge_node() -> Node:
	return get_node_or_null("CityTradeNetworkWorldBridge")


func _city_development_runtime_controller_node() -> Node:
	return get_node_or_null("CityDevelopmentRuntimeController")


func _city_development_world_bridge_node() -> Node:
	return get_node_or_null("CityDevelopmentWorldBridge")


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


func _contract_runtime_controller_node() -> Node:
	return get_node_or_null("ContractRuntimeController")


func _contract_runtime_world_bridge_node() -> Node:
	return get_node_or_null("ContractRuntimeWorldBridge")


func _card_play_eligibility_node() -> Node:
	return get_node_or_null("CardPlayEligibilityRuntimeService")


func _card_play_world_bridge_node() -> Node:
	return get_node_or_null("CardPlayEligibilityWorldBridge")


func _session_node() -> Node:
	return get_node_or_null("GameSessionRuntimeController")


func _purchase_node() -> Node:
	return get_node_or_null("DistrictPurchaseRuntimeController")


func _card_inventory_node() -> Node:
	return get_node_or_null("CardInventoryRuntimeService")


func _card_resolution_queue_node() -> Node:
	return get_node_or_null("CardResolutionQueueRuntimeService")


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


func _economy_node() -> Node:
	return get_node_or_null("EconomyCashflowRuntimeController")


func _gdp_formula_node() -> Node:
	return get_node_or_null("GdpFormulaRuntimeController")


func _scenario_node() -> Node:
	return get_node_or_null("ScenarioRuntimeController")


func _first_table_authored_node() -> Node:
	return get_node_or_null("FirstTableAuthoredRuntimeService")


func _codex_navigation_node() -> Node:
	return get_node_or_null("CodexNavigationRuntimeController")


func _codex_public_snapshot_node() -> Node:
	return get_node_or_null("CodexPublicSnapshotService")


func _monster_codex_public_snapshot_node() -> Node:
	return get_node_or_null("MonsterCodexPublicSnapshotService")


func _product_codex_public_snapshot_node() -> Node:
	return get_node_or_null("ProductCodexPublicSnapshotService")


func _card_codex_public_snapshot_node() -> Node:
	return get_node_or_null("CardCodexPublicSnapshotService")


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


func _city_trade_network_runtime_debug_snapshot() -> Dictionary:
	var controller := _city_trade_network_runtime_controller_node()
	if controller != null and controller.has_method("debug_snapshot"):
		var snapshot_variant: Variant = controller.call("debug_snapshot", -1)
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _city_development_runtime_debug_snapshot() -> Dictionary:
	var controller := _city_development_runtime_controller_node()
	if controller != null and controller.has_method("debug_snapshot"):
		var snapshot_variant: Variant = controller.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _city_development_world_bridge_debug_snapshot() -> Dictionary:
	var bridge := _city_development_world_bridge_node()
	if bridge != null and bridge.has_method("debug_snapshot"):
		var snapshot_variant: Variant = bridge.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
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


func _economy_debug_snapshot() -> Dictionary:
	var economy := _economy_node()
	if economy != null and economy.has_method("debug_snapshot"):
		var snapshot_variant: Variant = economy.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _gdp_formula_debug_snapshot() -> Dictionary:
	var gdp_formula := _gdp_formula_node()
	if gdp_formula != null and gdp_formula.has_method("debug_snapshot"):
		var snapshot_variant: Variant = gdp_formula.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _scenario_debug_snapshot() -> Dictionary:
	var scenario := _scenario_node()
	if scenario != null and scenario.has_method("debug_snapshot"):
		var snapshot_variant: Variant = scenario.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _first_table_authored_debug_snapshot() -> Dictionary:
	var service := _first_table_authored_node()
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


func _product_codex_public_snapshot_debug_snapshot() -> Dictionary:
	var service := _product_codex_public_snapshot_node()
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
