extends SceneTree

const SERVICE_SCENE := preload("res://scenes/runtime/CardEconomyProductRouteEffectRuntimeService.tscn")
const BRIDGE_SCENE := preload("res://scenes/runtime/CardEconomyProductRouteEffectWorldBridge.tscn")
const FORMULA_SCENE := preload("res://scenes/runtime/CardEconomyProductRouteFormulaRuntimeService.tscn")
const MARKET_SCENE := preload("res://scenes/runtime/ProductMarketRuntimeController.tscn")
const MARKET_BRIDGE_SCENE := preload("res://scenes/runtime/ProductMarketRuntimeWorldBridge.tscn")

var _checks := 0
var _failures := 0


class FixtureWorld:
	extends Node
	var selected_district := 0
	var selected_trade_product := "星露莓"
	var game_time := 12.0
	var rng := RandomNumberGenerator.new()
	var players := [{"cash": 999, "hand": ["PRIVATE_HAND_SENTINEL"]}]
	var districts := [{
		"name": "北环区",
		"destroyed": false,
		"terrain": "land",
		"panic": 12,
		"production_level": 3,
		"transport_level": 2,
		"consumption_level": 4,
		"products": ["星露莓"],
		"demands": ["磁核榴莲"],
		"city": {"active": true, "trade_route_damage": 2, "owner": 0, "private_note": "PRIVATE_CITY_SENTINEL"},
	}]

	func _default_economy_product() -> String: return selected_trade_product


class RecordingMarket:
	extends ProductMarketRuntimeController
	var pressure_calls := 0
	var refresh_calls := 0
	var last_effect := {}

	func apply_news_market_pressure(effect: Dictionary) -> Dictionary:
		pressure_calls += 1
		last_effect = effect.duplicate(true)
		return {
			"changed": int(effect.get("market_demand_pressure", 0)) > 0,
			"product_id": "星露莓",
			"demand_delta": int(effect.get("market_demand_pressure", 0)),
			"supply_delta": int(effect.get("market_supply_pressure", 0)),
			"volatility_delta": int(effect.get("volatility_delta", 0)),
		}

	func refresh_after_news_event() -> void:
		refresh_calls += 1


func _initialize() -> void:
	var service := SERVICE_SCENE.instantiate()
	var bridge := BRIDGE_SCENE.instantiate()
	var formula := FORMULA_SCENE.instantiate()
	var market := RecordingMarket.new()
	var world := FixtureWorld.new()
	var table_selection := TableSelectionState.new()
	root.add_child(service)
	root.add_child(bridge)
	root.add_child(formula)
	root.add_child(market)
	root.add_child(world)
	root.add_child(table_selection)
	table_selection.restore({
		"selected_district": 0,
		"selected_trade_product": "星露莓",
	})
	service.configure({"ruleset_id": "v0.4"})
	formula.configure({"ruleset_id": "v0.4"})
	bridge.set_product_market_runtime_controller(market)
	bridge.set_formula_runtime_service(formula)
	bridge.set_table_selection_state(table_selection)

	var skill := {
		"name": "监管风暴1",
		"kind": "news_event",
		"news_category": "regulation",
		"panic": 18,
		"production_delta": -1,
		"transport_delta": 1,
		"consumption_delta": -1,
		"route_damage": 1,
		"market_demand_pressure": 2,
		"market_supply_pressure": 0,
		"volatility_delta": 1,
		"player_index": 0,
		"owner": "PRIVATE_OWNER_SENTINEL",
		"private_hand": ["PRIVATE_HAND_SENTINEL"],
	}
	var plan: Dictionary = service.plan_effect({
		"handler_id": "news_event",
		"active_entry": {"resolution_id": 77, "player_index": 0, "private_actor": "PRIVATE_ACTOR_SENTINEL"},
		"skill": skill,
	})
	_expect(bool(plan.get("ready", false)) and str(plan.get("family_id", "")) == "economy", "news event is planned by the existing effect owner")
	var receipt: Dictionary = bridge.apply_effect(world, plan)
	var finalization: Dictionary = service.finalize_effect(plan, receipt)
	_expect(bool(receipt.get("resolved", false)) and bool(finalization.get("resolved", false)), "valid news event commits through the production dispatch chain")
	var district: Dictionary = world.districts[0]
	var city: Dictionary = district.get("city", {})
	_expect(int(district.get("panic", -1)) == 30, "panic changes exactly once")
	_expect(int(district.get("production_level", -1)) == 2 and int(district.get("transport_level", -1)) == 3 and int(district.get("consumption_level", -1)) == 3, "production, transport, and consumption use the formula owner")
	_expect(int(city.get("trade_route_damage", -1)) == 3, "route damage changes exactly once")
	_expect(market.pressure_calls == 1 and market.refresh_calls == 1 and int(market.last_effect.get("market_demand_pressure", 0)) == 2, "product market owner receives one allowlisted pressure mutation and one refresh")
	var public_receipt: Dictionary = receipt.get("public_receipt", {})
	_expect(finalization.get("public_receipt", {}) == public_receipt, "finalization preserves the owner public receipt without recomposition")
	_expect(_exact_keys(public_receipt, ["anonymous_source", "card_name", "consumption_delta", "district_index", "district_name", "event_kind", "market_demand_delta", "market_supply_delta", "news_category", "panic_delta", "product_id", "production_delta", "route_damage_delta", "schema_version", "transport_delta", "volatility_delta"]), "public aftermath uses a fixed allowlist")
	_expect(bool(public_receipt.get("anonymous_source", false)) and not _contains_private_sentinel(public_receipt), "public aftermath hides player, owner, hand, and private actor state")
	_expect(str(city.get("last_public_clue", "")).contains("出牌者匿名") and not _contains_private_sentinel(city.get("public_clues", [])), "city receives a public anonymous aftermath clue")

	var invalid_world := FixtureWorld.new()
	invalid_world.districts[0]["destroyed"] = true
	root.add_child(invalid_world)
	var invalid_before := invalid_world.districts.duplicate(true)
	var pressure_before := market.pressure_calls
	var invalid_receipt: Dictionary = bridge.apply_effect(invalid_world, plan)
	_expect(not bool(invalid_receipt.get("resolved", true)) and str(invalid_receipt.get("reason", "")) == "district_destroyed", "destroyed target fails closed")
	_expect(invalid_world.districts == invalid_before and market.pressure_calls == pressure_before, "invalid target mutates no region or market owner")

	var market_formula := FORMULA_SCENE.instantiate()
	var real_market := MARKET_SCENE.instantiate()
	var market_bridge := MARKET_BRIDGE_SCENE.instantiate()
	var market_world := FixtureWorld.new()
	root.add_child(market_formula)
	root.add_child(real_market)
	root.add_child(market_bridge)
	root.add_child(market_world)
	market_formula.configure({"ruleset_id": "v0.4"})
	market_bridge.bind_world(market_world)
	market_bridge.set_table_selection_state(table_selection)
	real_market.set_world_bridge(market_bridge)
	real_market.product_market = {"星露莓": {"base_price": 50, "price": 50, "volatility": 4, "temporary_demand_pressure": 0, "temporary_supply_pressure": 0, "price_history": [50]}}
	var real_market_receipt: Dictionary = real_market.apply_news_market_pressure({"market_demand_pressure": 2, "market_supply_pressure": 1, "volatility_delta": 1})
	var real_entry: Dictionary = real_market.market_entry("星露莓")
	_expect(bool(real_market_receipt.get("changed", false)) and int(real_entry.get("temporary_demand_pressure", -1)) == 2 and int(real_entry.get("temporary_supply_pressure", -1)) == 1 and int(real_entry.get("volatility", -1)) == 5, "real ProductMarket owner applies news pressure without duplicating its price formula")
	_expect(not service.has_method("to_save_data") and not bridge.has_method("to_save_data") and not formula.has_method("to_save_data"), "news dispatch adds no duplicate save owner")

	print("NEWS_EVENT_RUNTIME_OWNER_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(_failures)


func _exact_keys(value: Dictionary, expected: Array) -> bool:
	var actual := value.keys()
	actual.sort()
	var sorted_expected := expected.duplicate()
	sorted_expected.sort()
	return actual == sorted_expected


func _contains_private_sentinel(value: Variant) -> bool:
	return JSON.stringify(value).contains("PRIVATE_")


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % label)
		return
	_failures += 1
	push_error("FAIL: %s" % label)
