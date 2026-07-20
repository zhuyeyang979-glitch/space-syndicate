@tool
extends Node
class_name CardEconomyProductRouteEffectWorldBridge

const FrozenTargetContext := preload("res://scripts/runtime/product_market_frozen_target_context.gd")
const PRODUCT_TARGET_HANDLERS := [
	"product_speculation",
	"product_futures",
	"product_contract_boon",
	"market_stabilize",
	"product_growth_boon",
]

var _product_market_runtime_controller: ProductMarketRuntimeController
var _city_gdp_derivative_runtime_controller: CityGdpDerivativeRuntimeController
var _formula_runtime_service: CardEconomyProductRouteFormulaRuntimeService
var _table_selection_state: TableSelectionState
var _world_session_state: WorldSessionState
var _contract_runtime_controller: ContractRuntimeController


func set_product_market_runtime_controller(controller: ProductMarketRuntimeController) -> void:
	_product_market_runtime_controller = controller


func set_city_gdp_derivative_runtime_controller(controller: CityGdpDerivativeRuntimeController) -> void:
	_city_gdp_derivative_runtime_controller = controller


func set_formula_runtime_service(service: CardEconomyProductRouteFormulaRuntimeService) -> void:
	_formula_runtime_service = service


func set_table_selection_state(state: TableSelectionState) -> void:
	_table_selection_state = state


func set_world_session_state(state: WorldSessionState) -> void:
	_world_session_state = state


func set_contract_runtime_controller(controller: ContractRuntimeController) -> void:
	_contract_runtime_controller = controller


func world_session_state() -> WorldSessionState:
	return _world_session_state


func table_selection_state() -> TableSelectionState:
	return _table_selection_state


func apply_effect(plan: Dictionary) -> Dictionary:
	var handler_id := str(plan.get("handler_id", ""))
	if str(plan.get("status", "")) != "ready" or not bool(plan.get("supported", false)):
		return _receipt(handler_id, false, "effect_plan_not_ready")
	var payload: Dictionary = plan.get("effect_payload", {}) as Dictionary
	var entry: Dictionary = payload.get("active_entry", {}) as Dictionary
	var skill: Dictionary = payload.get("skill", {}) as Dictionary
	var player_index := int(payload.get("player_index", -1))
	var players_variant: Variant = _world_session_state.players if _world_session_state != null else []
	var players: Array = players_variant if players_variant is Array else []
	if player_index < 0 or player_index >= players.size() or not (players[player_index] is Dictionary) or skill.is_empty():
		return _receipt(handler_id, false, "effect_context_missing")
	var target_context := {}
	if PRODUCT_TARGET_HANDLERS.has(handler_id) or (handler_id == "news_event" and _news_event_has_market_effect(skill)):
		var target_result := _frozen_product_target_context(entry, skill, handler_id)
		if not bool(target_result.get("valid", false)):
			return _receipt(handler_id, false, str(target_result.get("reason_code", "product_target_context_invalid")))
		target_context = (target_result.get("context", {}) as Dictionary).duplicate(true)
	var resolved := false
	match handler_id:
		"product_speculation":
			resolved = _product_market_runtime_controller.apply_speculation(player_index, skill, target_context) if _product_market_runtime_controller != null else false
		"product_futures":
			resolved = _product_market_runtime_controller.apply_futures(player_index, skill, target_context) if _product_market_runtime_controller != null else false
		"city_gdp_derivative":
			var district_index := int(entry.get("selected_district", -1))
			var derivative_receipt := _city_gdp_derivative_runtime_controller.open_position(player_index, skill, district_index) if _city_gdp_derivative_runtime_controller != null else {"committed": false}
			resolved = bool(derivative_receipt.get("committed", false))
		"product_contract_boon":
			resolved = _product_market_runtime_controller.apply_product_contract_boon(player_index, skill, target_context) if _product_market_runtime_controller != null else false
		"area_trade_contract":
			var contract_result := _contract_runtime_controller.open_offer(skill, entry) if _contract_runtime_controller != null else {"opened": false, "reason": "contract_controller_missing"}
			resolved = bool(contract_result.get("opened", false))
		"market_stabilize":
			resolved = _product_market_runtime_controller.apply_market_stabilize(skill, target_context) if _product_market_runtime_controller != null else false
		"news_event":
			return _apply_news_event(handler_id, skill, int(entry.get("selected_district", -1)), target_context)
		"product_growth_boon":
			resolved = _product_market_runtime_controller.apply_product_growth_boon(skill, target_context) if _product_market_runtime_controller != null else false
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
		"formula_runtime_service_bound": _formula_runtime_service != null,
		"contract_runtime_controller_bound": _contract_runtime_controller != null,
		"frozen_product_target_context_supported": true,
	}


func _apply_news_event(handler_id: String, skill: Dictionary, district_index: int, target_context: Dictionary = {}) -> Dictionary:
	if _formula_runtime_service == null or _product_market_runtime_controller == null:
		return _receipt(handler_id, false, "news_event_owner_unavailable")
	var districts_variant: Variant = _world_session_state.districts if _world_session_state != null else []
	if not (districts_variant is Array):
		return _receipt(handler_id, false, "news_event_world_facts_unavailable")
	var districts := (districts_variant as Array).duplicate(true)
	if district_index < 0 or district_index >= districts.size() or not (districts[district_index] is Dictionary):
		return _receipt(handler_id, false, "news_event_target_invalid")
	var effect := _news_effect_allowlist(skill)
	var region_result := _formula_runtime_service.calculate("news_event_region_effect", {
		"district": (districts[district_index] as Dictionary).duplicate(true),
		"effect": effect,
	})
	if not bool(region_result.get("ok", false)):
		return _receipt(handler_id, false, str(region_result.get("reason", "news_event_region_rejected")))
	var market_result := _product_market_runtime_controller.apply_news_market_pressure(effect, target_context)
	var region_changed := bool(region_result.get("changed", false))
	var market_changed := bool(market_result.get("changed", false))
	if not region_changed and not market_changed:
		return _receipt(handler_id, false, "news_event_no_effect")
	var district: Dictionary = (region_result.get("district", {}) as Dictionary).duplicate(true)
	var public_receipt := _news_public_receipt(district_index, district, effect, region_result, market_result)
	_append_news_public_clue(district, public_receipt)
	districts[district_index] = district
	if _world_session_state != null:
		_world_session_state.districts = districts
	_product_market_runtime_controller.refresh_after_news_event()
	var result := _receipt(handler_id, true, "news_event_committed", true)
	result["public_receipt"] = public_receipt
	return result


func _frozen_product_target_context(entry: Dictionary, skill: Dictionary, handler_id: String) -> Dictionary:
	if _world_session_state == null:
		return {"valid": false, "reason_code": "product_target_context_world_unavailable"}
	var requires_warehouse := false
	if handler_id == "product_futures":
		var terms: Dictionary = skill.get("futures_terms", {}) as Dictionary if skill.get("futures_terms", {}) is Dictionary else {}
		if terms.is_empty() and _product_market_runtime_controller != null:
			terms = _product_market_runtime_controller.futures_terms(skill)
		requires_warehouse = bool(terms.get("requires_warehouse", false))
	return FrozenTargetContext.from_entry(entry, _world_session_state, requires_warehouse)


func _news_event_has_market_effect(skill: Dictionary) -> bool:
	return int(skill.get("market_demand_pressure", 0)) != 0 \
		or int(skill.get("market_supply_pressure", 0)) != 0 \
		or int(skill.get("volatility_delta", 0)) != 0


func _news_effect_allowlist(skill: Dictionary) -> Dictionary:
	var result := {}
	for key in ["name", "news_category", "panic", "production_delta", "transport_delta", "consumption_delta", "route_damage", "market_demand_pressure", "market_supply_pressure", "volatility_delta"]:
		if skill.has(key):
			result[key] = skill[key]
	return result


func _news_public_receipt(district_index: int, district: Dictionary, effect: Dictionary, region: Dictionary, market: Dictionary) -> Dictionary:
	return {
		"schema_version": "v0.6.news-event-public-receipt.1",
		"event_kind": "news_event",
		"card_name": str(effect.get("name", "匿名新闻")),
		"news_category": str(effect.get("news_category", "public")),
		"district_index": district_index,
		"district_name": str(district.get("name", "区域%d" % (district_index + 1))),
		"panic_delta": int(region.get("panic_delta", 0)),
		"production_delta": int(region.get("after_production", 0)) - int(region.get("before_production", 0)),
		"transport_delta": int(region.get("after_transport", 0)) - int(region.get("before_transport", 0)),
		"consumption_delta": int(region.get("after_consumption", 0)) - int(region.get("before_consumption", 0)),
		"route_damage_delta": int(region.get("route_damage_delta", 0)),
		"product_id": str(market.get("product_id", "")),
		"market_demand_delta": int(market.get("demand_delta", 0)) if bool(market.get("changed", false)) else 0,
		"market_supply_delta": int(market.get("supply_delta", 0)) if bool(market.get("changed", false)) else 0,
		"volatility_delta": int(market.get("volatility_delta", 0)) if bool(market.get("changed", false)) else 0,
		"anonymous_source": true,
	}


func _append_news_public_clue(district: Dictionary, receipt: Dictionary) -> void:
	var city: Dictionary = district.get("city", {}) if district.get("city", {}) is Dictionary else {}
	if city.is_empty() or not bool(city.get("active", true)):
		return
	var clue := "%s新闻：热度%+d，生产%+d、交通%+d、消费%+d、断路%+d；出牌者匿名。" % [
		str(receipt.get("news_category", "public")),
		int(receipt.get("panic_delta", 0)),
		int(receipt.get("production_delta", 0)),
		int(receipt.get("transport_delta", 0)),
		int(receipt.get("consumption_delta", 0)),
		int(receipt.get("route_damage_delta", 0)),
	]
	city["last_public_clue"] = clue
	var clues: Array = (city.get("public_clues", []) as Array).duplicate(true) if city.get("public_clues", []) is Array else []
	clues.append({"kind": "新闻", "text": clue})
	while clues.size() > 12:
		clues.pop_front()
	city["public_clues"] = clues
	district["city"] = city


func _receipt(handler_id: String, resolved: bool, reason: String, dispatched: bool = false) -> Dictionary:
	return {
		"handler_id": handler_id,
		"dispatched": dispatched,
		"resolved": resolved,
		"reason": reason,
	}
