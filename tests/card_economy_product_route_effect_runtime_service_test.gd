extends SceneTree

const SERVICE_SCENE := "res://scenes/runtime/CardEconomyProductRouteEffectRuntimeService.tscn"
const BRIDGE_SCENE := "res://scenes/runtime/CardEconomyProductRouteEffectWorldBridge.tscn"

var _failed := false


class FakeWorld:
	extends Node
	var players := [{"cash": 100}]
	var selected_district := 0
	var cash_calls := 0
	var calls: Array = []

	func _apply_cash_gain_card_effect(player_index: int, skill: Dictionary) -> bool:
		cash_calls += 1
		calls.append("cash_gain")
		players[player_index]["cash"] = int(players[player_index].get("cash", 0)) + int(skill.get("cash", 0))
		return true

	func _boost_selected_city_revenue(_amount: int, _panic: int, _source: String) -> bool: return _record("city_revenue_boost")
	func _apply_product_speculation(_player: Dictionary, _skill: Dictionary) -> bool: return _record("product_speculation")
	func _apply_product_futures(_player: Dictionary, _skill: Dictionary) -> bool: return _record("product_futures")
	func _apply_product_contract_boon(_player: Dictionary, _skill: Dictionary) -> bool: return _record("product_contract_boon")
	func _apply_route_insurance(_player: Dictionary, _skill: Dictionary) -> bool: return _record("route_insurance")
	func _apply_city_product_upgrade(_player: Dictionary, _skill: Dictionary) -> bool: return _record("city_product_upgrade")
	func _apply_city_product_shift(_player: Dictionary, _skill: Dictionary) -> bool: return _record("city_product_shift")
	func _apply_city_demand_shift(_player: Dictionary, _skill: Dictionary) -> bool: return _record("city_demand_shift")
	func _apply_market_stabilize(_skill: Dictionary) -> bool: return _record("market_stabilize")
	func _apply_product_growth_boon(_skill: Dictionary) -> bool: return _record("product_growth_boon")
	func _apply_route_flow_boon(_player: Dictionary, _skill: Dictionary) -> bool: return _record("route_flow_boon")
	func _apply_region_economy_shift(_skill: Dictionary) -> bool: return _record("region_economy_shift")
	func _apply_city_contract_boon(_player: Dictionary, _skill: Dictionary) -> bool: return _record("city_contract_boon")
	func _apply_route_sabotage(_skill: Dictionary) -> bool: return _record("route_sabotage")

	func _record(handler_id: String) -> bool:
		calls.append(handler_id)
		return true


class FakeContractController:
	extends ContractRuntimeController
	var calls: Array

	func open_offer(_skill: Dictionary, _entry: Dictionary) -> Dictionary:
		calls.append("area_trade_contract")
		return {"opened": true, "reason": "fixture"}


class FakeProductMarketController:
	extends ProductMarketRuntimeController
	var calls: Array

	func apply_speculation(_player_index: int, _skill: Dictionary) -> bool: return _record("product_speculation")
	func apply_futures(_player_index: int, _skill: Dictionary) -> bool: return _record("product_futures")
	func apply_product_contract_boon(_player_index: int, _skill: Dictionary) -> bool: return _record("product_contract_boon")
	func apply_market_stabilize(_skill: Dictionary) -> bool: return _record("market_stabilize")
	func apply_product_growth_boon(_skill: Dictionary) -> bool: return _record("product_growth_boon")

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
	var expected := [
		"area_trade_contract", "cash_gain", "city_contract_boon", "city_demand_shift",
		"city_gdp_derivative", "city_product_shift", "city_product_upgrade", "city_revenue_boost",
		"market_stabilize", "product_contract_boon", "product_futures", "product_growth_boon",
		"product_speculation", "region_economy_shift", "route_flow_boon", "route_insurance", "route_sabotage",
	]
	_expect(service.call("supported_handlers") == expected, "service owns the exact seventeen economy, product, and route handlers")
	_expect(str(service.call("family_for_handler", "cash_gain")) == "economy", "cash gain is classified as economy")
	_expect(str(service.call("family_for_handler", "product_futures")) == "product", "futures are classified as product")
	_expect(str(service.call("family_for_handler", "route_insurance")) == "route", "route insurance is classified as route")
	var cash_plan := service.call("plan_effect", _request(3801, "cash_gain", {"cash": 90})) as Dictionary
	_expect(bool(cash_plan.get("ready", false)) and bool(cash_plan.get("supported", false)), "supported handler creates a ready plan")
	_expect(_is_data_only(cash_plan), "effect plan contains pure data only")
	var unsupported := service.call("plan_effect", _request(3802, "monster_card")) as Dictionary
	_expect(str(unsupported.get("status", "")) == "unsupported" and not bool(unsupported.get("supported", true)), "unowned handler is explicitly unsupported")
	var bad_request := _request(3803, "cash_gain")
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
		var fake_market := FakeProductMarketController.new()
		fake_market.calls = fake_world.calls
		root.add_child(fake_market)
		bridge.call("set_product_market_runtime_controller", fake_market)
		var fake_derivative := FakeCityGdpDerivativeController.new()
		fake_derivative.calls = fake_world.calls
		root.add_child(fake_derivative)
		bridge.call("set_city_gdp_derivative_runtime_controller", fake_derivative)
		var runtime_services := Node.new()
		runtime_services.name = "RuntimeServices"
		fake_world.add_child(runtime_services)
		var controller_host := Node.new()
		controller_host.name = "RuntimeControllerHost"
		runtime_services.add_child(controller_host)
		var coordinator := Node.new()
		coordinator.name = "GameRuntimeCoordinator"
		controller_host.add_child(coordinator)
		var fake_contract := FakeContractController.new()
		fake_contract.name = "ContractRuntimeController"
		fake_contract.calls = fake_world.calls
		coordinator.add_child(fake_contract)
		var receipt := bridge.call("apply_effect", fake_world, cash_plan) as Dictionary
		_expect(bool(receipt.get("resolved", false)) and fake_world.cash_calls == 1 and int(fake_world.players[0].get("cash", 0)) == 190, "bridge applies the planned world operation exactly once")
		var finalized := service.call("finalize_effect", cash_plan, receipt) as Dictionary
		_expect(bool(finalized.get("dispatched", false)) and bool(finalized.get("resolved", false)), "service finalizes a successful world receipt")
		var contract_plan := service.call("plan_effect", _request(3804, "area_trade_contract")) as Dictionary
		var contract_result := service.call("finalize_effect", contract_plan, {"handler_id": "area_trade_contract", "dispatched": true, "resolved": true, "reason": "resolved"}) as Dictionary
		_expect(str(contract_result.get("continuation_kind", "")) == "contract_response", "area contract retains its non-blocking continuation classification")
		fake_world.calls.clear()
		var all_handlers_routed := true
		for handler_variant in expected:
			var handler_id := str(handler_variant)
			var handler_plan := service.call("plan_effect", _request(3900 + fake_world.calls.size(), handler_id, {"cash": 1})) as Dictionary
			var handler_receipt := bridge.call("apply_effect", fake_world, handler_plan) as Dictionary
			var handler_result := service.call("finalize_effect", handler_plan, handler_receipt) as Dictionary
			all_handlers_routed = all_handlers_routed and bool(handler_result.get("resolved", false))
		_expect(all_handlers_routed and fake_world.calls == expected, "world bridge routes all seventeen handlers exactly once")
		fake_world.queue_free()
		fake_market.queue_free()
		fake_derivative.queue_free()
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
		"active_entry": {"resolution_id": resolution_id, "player_index": 0, "slot_index": 0},
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
