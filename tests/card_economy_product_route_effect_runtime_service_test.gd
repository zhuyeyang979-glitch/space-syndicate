extends SceneTree

const SERVICE_SCENE := "res://scenes/runtime/CardEconomyProductRouteEffectRuntimeService.tscn"
const BRIDGE_SCENE := "res://scenes/runtime/CardEconomyProductRouteEffectWorldBridge.tscn"
const ACTIVE_HANDLERS := [
	"city_gdp_derivative",
	"market_stabilize",
	"news_event",
	"product_contract_boon",
	"product_futures",
	"product_growth_boon",
	"product_speculation",
]
const RETIRED_HANDLERS := [
	"cash_gain",
	"city_contract_boon",
	"city_demand_shift",
	"city_product_shift",
	"city_product_upgrade",
	"city_revenue_boost",
	"region_economy_shift",
	"route_flow_boon",
	"route_insurance",
	"route_sabotage",
]

var _failed := false


class FakeWorld:
	extends Node
	var players := [{"cash": 100}]
	var selected_district := 0
	var districts := [{"name": "fixture", "destroyed": false, "terrain": "land", "panic": 0, "production_level": 2, "transport_level": 2, "consumption_level": 2, "city": {"active": true, "trade_route_damage": 0}}]
	var calls: Array = []


class FakeProductMarketController:
	extends ProductMarketRuntimeController
	var calls: Array

	func apply_speculation(_player_index: int, _skill: Dictionary, _target_context: Dictionary = {}) -> bool: return _record("product_speculation")
	func apply_futures(_player_index: int, _skill: Dictionary, _target_context: Dictionary = {}) -> bool: return _record("product_futures")
	func apply_product_contract_boon(_player_index: int, _skill: Dictionary, _target_context: Dictionary = {}) -> bool: return _record("product_contract_boon")
	func apply_market_stabilize(_skill: Dictionary, _target_context: Dictionary = {}) -> bool: return _record("market_stabilize")
	func apply_news_market_pressure(_skill: Dictionary, _target_context: Dictionary = {}) -> Dictionary:
		_record("news_event")
		return {"changed": true, "product_id": "星露莓", "demand_delta": 1, "supply_delta": 0, "volatility_delta": 0}
	func refresh_after_news_event() -> void: pass
	func apply_product_growth_boon(_skill: Dictionary, _target_context: Dictionary = {}) -> bool: return _record("product_growth_boon")

	func _record(handler_id: String) -> bool:
		calls.append(handler_id)
		return true


class FakeCityGdpDerivativeController:
	extends CityGdpDerivativeRuntimeController
	var calls: Array

	func open_position(_player_index: int, _skill: Dictionary, _district_index: int) -> Dictionary:
		calls.append("city_gdp_derivative")
		return {"committed": true, "reason": "fixture"}


func _initialize() -> void:
	var packed := load(SERVICE_SCENE) as PackedScene
	_expect(packed != null, "effect family service scene loads")
	var service := packed.instantiate() if packed != null else null
	_expect(service != null, "effect family service scene instantiates")
	if service == null:
		quit(1)
		return
	root.add_child(service)
	service.call("configure", {"ruleset_id": "v0.4"})
	_expect(service.call("supported_handlers") == ACTIVE_HANDLERS, "service owns the exact seven active economy and product handlers")
	_expect(str(service.call("family_for_handler", "city_gdp_derivative")) == "economy", "GDP derivative is classified as economy")
	_expect(str(service.call("family_for_handler", "product_futures")) == "product", "futures are classified as product")
	var product_plan := service.call("plan_effect", _request(3801, "product_speculation")) as Dictionary
	_expect(bool(product_plan.get("ready", false)) and bool(product_plan.get("supported", false)), "active supported handler creates a ready plan")
	_expect(_is_data_only(product_plan), "effect plan contains pure data only")
	var unsupported := service.call("plan_effect", _request(3802, "monster_card")) as Dictionary
	_expect(str(unsupported.get("status", "")) == "unsupported" and not bool(unsupported.get("supported", true)), "unowned handler is explicitly unsupported")
	for retired_handler_variant in RETIRED_HANDLERS:
		var retired_handler := str(retired_handler_variant)
		var retired := service.call("plan_effect", _request(3803, retired_handler)) as Dictionary
		_expect(
			str(retired.get("status", "")) == "unsupported"
			and not bool(retired.get("supported", true))
			and str(retired.get("reason", "")) == "handler_not_owned"
			and not bool(service.call("supports_handler", retired_handler))
			and str(service.call("family_for_handler", retired_handler)).is_empty(),
			"retired handler %s remains explicitly unsupported" % retired_handler
		)
	var bad_request := _request(3813, "product_speculation")
	bad_request["runtime_object"] = Node.new()
	var rejected := service.call("plan_effect", bad_request) as Dictionary
	(bad_request["runtime_object"] as Node).free()
	_expect(str(rejected.get("reason", "")) == "request_not_data_only", "runtime objects are rejected from plans")
	var bridge_packed := load(BRIDGE_SCENE) as PackedScene
	var bridge := bridge_packed.instantiate() if bridge_packed != null else null
	_expect(bridge != null, "effect family world bridge scene instantiates")
	if bridge != null:
		root.add_child(bridge)
		var fake_world := FakeWorld.new()
		root.add_child(fake_world)
		var world_state := WorldSessionState.new()
		world_state.players = fake_world.players
		world_state.districts = fake_world.districts
		root.add_child(world_state)
		var fake_market := FakeProductMarketController.new()
		fake_market.calls = fake_world.calls
		root.add_child(fake_market)
		bridge.call("set_product_market_runtime_controller", fake_market)
		bridge.call("set_world_session_state", world_state)
		var fake_derivative := FakeCityGdpDerivativeController.new()
		fake_derivative.calls = fake_world.calls
		root.add_child(fake_derivative)
		bridge.call("set_city_gdp_derivative_runtime_controller", fake_derivative)
		var formula := CardEconomyProductRouteFormulaRuntimeService.new()
		formula.configure({"ruleset_id": "v0.4"})
		root.add_child(formula)
		bridge.call("set_formula_runtime_service", formula)
		var receipt := bridge.call("apply_effect", product_plan) as Dictionary
		_expect(bool(receipt.get("resolved", false)) and fake_world.calls == ["product_speculation"], "bridge applies the active planned product operation exactly once")
		var finalized := service.call("finalize_effect", product_plan, receipt) as Dictionary
		_expect(bool(finalized.get("dispatched", false)) and bool(finalized.get("resolved", false)), "service finalizes a successful world receipt")
		fake_world.calls.clear()
		var all_handlers_routed := true
		for handler_variant in service.call("supported_handlers") as Array:
			var handler_id := str(handler_variant)
			var handler_plan := service.call("plan_effect", _request(3900 + fake_world.calls.size(), handler_id, {"cash": 1})) as Dictionary
			var handler_receipt := bridge.call("apply_effect", handler_plan) as Dictionary
			var handler_result := service.call("finalize_effect", handler_plan, handler_receipt) as Dictionary
			all_handlers_routed = all_handlers_routed and bool(handler_result.get("resolved", false))
		_expect(all_handlers_routed and fake_world.calls == ACTIVE_HANDLERS, "world bridge routes all seven active owned handlers exactly once")
		fake_world.queue_free()
		world_state.queue_free()
		fake_market.queue_free()
		fake_derivative.queue_free()
		formula.queue_free()
		bridge.queue_free()
	var debug := service.call("debug_snapshot") as Dictionary
	_expect(_is_data_only(debug), "service debug snapshot contains pure data only")
	_expect(bool(debug.get("effect_family_dispatch_authority", false)) and not bool(debug.get("execution_lifecycle_authority", true)) and not bool(debug.get("queue_authority", true)) and not bool(debug.get("timing_authority", true)) and not bool(debug.get("inventory_authority", true)), "service advertises the narrow effect-family boundary")
	service.queue_free()
	print("Card economy/product/route effect runtime service test %s." % ["failed" if _failed else "passed"])
	quit(1 if _failed else 0)


func _request(resolution_id: int, handler_id: String, extra: Dictionary = {}) -> Dictionary:
	var skill := {"name": "fixture-%s" % handler_id, "kind": handler_id}
	for key_variant in extra.keys():
		skill[key_variant] = extra[key_variant]
	return {
		"handler_id": handler_id,
		"active_entry": {"resolution_id": resolution_id, "player_index": 0, "slot_index": 0, "selected_district": 0, "selected_trade_product": "星露莓"},
		"skill": skill,
	}


func _is_data_only(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return true
	if value is Dictionary:
		for key_variant in value.keys():
			if not _is_data_only(key_variant) or not _is_data_only(value[key_variant]):
				return false
		return true
	if value is Array:
		for item in value:
			if not _is_data_only(item):
				return false
		return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failed = true
	push_error("FAIL: %s" % message)
