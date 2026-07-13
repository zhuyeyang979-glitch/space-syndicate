@tool
extends Node
class_name CardEconomyProductRouteEffectWorldBridge

var _product_market_runtime_controller: ProductMarketRuntimeController
var _city_gdp_derivative_runtime_controller: CityGdpDerivativeRuntimeController


func set_product_market_runtime_controller(controller: ProductMarketRuntimeController) -> void:
	_product_market_runtime_controller = controller


func set_city_gdp_derivative_runtime_controller(controller: CityGdpDerivativeRuntimeController) -> void:
	_city_gdp_derivative_runtime_controller = controller


func apply_effect(world: Node, plan: Dictionary) -> Dictionary:
	var handler_id := str(plan.get("handler_id", ""))
	if world == null:
		return _receipt(handler_id, false, "world_missing")
	if str(plan.get("status", "")) != "ready" or not bool(plan.get("supported", false)):
		return _receipt(handler_id, false, "effect_plan_not_ready")
	var payload: Dictionary = plan.get("effect_payload", {}) as Dictionary
	var entry: Dictionary = payload.get("active_entry", {}) as Dictionary
	var skill: Dictionary = payload.get("skill", {}) as Dictionary
	var player_index := int(payload.get("player_index", -1))
	var players_variant: Variant = world.get("players")
	var players: Array = players_variant if players_variant is Array else []
	if player_index < 0 or player_index >= players.size() or not (players[player_index] is Dictionary) or skill.is_empty():
		return _receipt(handler_id, false, "effect_context_missing")
	var player: Dictionary = players[player_index]
	var resolved := false
	match handler_id:
		"cash_gain":
			resolved = _call_bool(world, "_apply_cash_gain_card_effect", [player_index, skill])
		"city_revenue_boost":
			resolved = _call_bool(world, "_boost_selected_city_revenue", [int(skill.get("revenue_amount", 40)), int(skill.get("panic", 0)), str(skill.get("name", "城市收益"))])
		"product_speculation":
			resolved = _product_market_runtime_controller.apply_speculation(player_index, skill) if _product_market_runtime_controller != null else false
		"product_futures":
			resolved = _product_market_runtime_controller.apply_futures(player_index, skill) if _product_market_runtime_controller != null else false
		"city_gdp_derivative":
			var district_index := int(world.get("selected_district"))
			var derivative_receipt := _city_gdp_derivative_runtime_controller.open_position(player_index, skill, district_index) if _city_gdp_derivative_runtime_controller != null else {"committed": false}
			resolved = bool(derivative_receipt.get("committed", false))
		"product_contract_boon":
			resolved = _product_market_runtime_controller.apply_product_contract_boon(player_index, skill) if _product_market_runtime_controller != null else false
		"area_trade_contract":
			var contract_controller := _contract_runtime_controller(world)
			var contract_result := contract_controller.open_offer(skill, entry) if contract_controller != null else {"opened": false, "reason": "contract_controller_missing"}
			resolved = bool(contract_result.get("opened", false))
		"route_insurance":
			resolved = _call_bool(world, "_apply_route_insurance", [player, skill])
		"city_product_upgrade":
			resolved = _call_bool(world, "_apply_city_product_upgrade", [player, skill])
		"city_product_shift":
			resolved = _call_bool(world, "_apply_city_product_shift", [player, skill])
		"city_demand_shift":
			resolved = _call_bool(world, "_apply_city_demand_shift", [player, skill])
		"market_stabilize":
			resolved = _product_market_runtime_controller.apply_market_stabilize(skill) if _product_market_runtime_controller != null else false
		"product_growth_boon":
			resolved = _product_market_runtime_controller.apply_product_growth_boon(skill) if _product_market_runtime_controller != null else false
		"route_flow_boon":
			resolved = _call_bool(world, "_apply_route_flow_boon", [player, skill])
		"region_economy_shift":
			resolved = _call_bool(world, "_apply_region_economy_shift", [skill])
		"city_contract_boon":
			resolved = _call_bool(world, "_apply_city_contract_boon", [player, skill])
		"route_sabotage":
			resolved = _call_bool(world, "_apply_route_sabotage", [skill])
		_:
			return _receipt(handler_id, false, "handler_not_owned")
	return _receipt(handler_id, resolved, "resolved" if resolved else "effect_not_resolved", true)


func debug_snapshot() -> Dictionary:
	return {
		"bridge_id": "card_economy_product_route_effect_world_bridge_v1",
		"bridge_ready": true,
		"holds_world_reference": false,
		"owns_rules": false,
		"owns_execution_lifecycle": false,
		"owns_queue": false,
		"product_market_controller_bound": _product_market_runtime_controller != null,
		"city_gdp_derivative_controller_bound": _city_gdp_derivative_runtime_controller != null,
	}


func _call_bool(world: Node, method_name: StringName, arguments: Array) -> bool:
	if not world.has_method(method_name):
		return false
	return bool(world.callv(method_name, arguments))


func _contract_runtime_controller(world: Node) -> ContractRuntimeController:
	return world.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ContractRuntimeController") as ContractRuntimeController


func _receipt(handler_id: String, resolved: bool, reason: String, dispatched: bool = false) -> Dictionary:
	return {
		"handler_id": handler_id,
		"dispatched": dispatched,
		"resolved": resolved,
		"reason": reason,
	}
