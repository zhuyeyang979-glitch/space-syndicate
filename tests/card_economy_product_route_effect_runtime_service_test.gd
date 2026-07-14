extends SceneTree

const SERVICE_SCENE := "res://scenes/runtime/CardEconomyProductRouteEffectRuntimeService.tscn"
const BRIDGE_SCENE := "res://scenes/runtime/CardEconomyProductRouteEffectWorldBridge.tscn"
const ACTIVE_HANDLERS := [
	"area_trade_contract",
	"city_gdp_derivative",
	"market_stabilize",
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
	var calls: Array = []


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
	_expect(service.call("supported_handlers") == ACTIVE_HANDLERS, "service owns the exact seven active economy, product, and route handlers")
	_expect(str(service.call("family_for_handler", "city_gdp_derivative")) == "economy", "GDP derivative is classified as economy")
	_expect(str(service.call("family_for_handler", "product_futures")) == "product", "futures are classified as product")
	_expect(str(service.call("family_for_handler", "area_trade_contract")) == "route", "area trade contract is classified as route")
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
		var receipt := bridge.call("apply_effect", fake_world, product_plan) as Dictionary
		_expect(bool(receipt.get("resolved", false)) and fake_world.calls == ["product_speculation"], "bridge applies the active planned product operation exactly once")
		var finalized := service.call("finalize_effect", product_plan, receipt) as Dictionary
		_expect(bool(finalized.get("dispatched", false)) and bool(finalized.get("resolved", false)), "service finalizes a successful world receipt")
		var contract_plan := service.call("plan_effect", _request(3804, "area_trade_contract")) as Dictionary
		var contract_result := service.call("finalize_effect", contract_plan, {"handler_id": "area_trade_contract", "dispatched": true, "resolved": true, "reason": "resolved"}) as Dictionary
		_expect(str(contract_result.get("continuation_kind", "")) == "contract_response", "area contract retains its non-blocking continuation classification")
		fake_world.calls.clear()
		var all_handlers_routed := true
		for handler_variant in service.call("supported_handlers") as Array:
			var handler_id := str(handler_variant)
			var handler_plan := service.call("plan_effect", _request(3900 + fake_world.calls.size(), handler_id, {"cash": 1})) as Dictionary
			var handler_receipt := bridge.call("apply_effect", fake_world, handler_plan) as Dictionary
			var handler_result := service.call("finalize_effect", handler_plan, handler_receipt) as Dictionary
			all_handlers_routed = all_handlers_routed and bool(handler_result.get("resolved", false))
		_expect(all_handlers_routed and fake_world.calls == ACTIVE_HANDLERS, "world bridge routes all seven active owned handlers exactly once")
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
