extends SceneTree

const BRIDGE_SCENE := preload("res://scenes/runtime/CardEconomyProductRouteEffectWorldBridge.tscn")
const FORMULA_SCENE := preload("res://scenes/runtime/CardEconomyProductRouteFormulaRuntimeService.tscn")
const StableTargetEnvelope := preload("res://scripts/runtime/card_resolution_stable_target_envelope.gd")
const FrozenTargetContext := preload("res://scripts/runtime/product_market_frozen_target_context.gd")

var _checks := 0
var _failures: Array[String] = []


class FixtureWorld:

	extends WorldSessionState

	func _init() -> void:
		players = [{"cash": 1000}, {"cash": 1000}]
		districts = [
			_district("region.000", "北环区", 0),
			_district("region.001", "南环区", 1),
		]
		game_time = 12.0

	static func _district(region_id: String, region_name: String, owner: int) -> Dictionary:
		return {
			"region_id": region_id,
			"name": region_name,
			"destroyed": false,
			"terrain": "land",
			"products": ["星露莓"],
			"demands": ["磁核榴莲"],
			"city": {"active": true, "owner": owner, "trade_route_damage": 0},
		}


class RecordingMarket:

	extends ProductMarketRuntimeController

	var calls := 0
	var last_context: Dictionary = {}
	var last_product := ""

	func apply_speculation(_player_index: int, _skill: Dictionary, target_context: Dictionary = {}) -> bool:
		calls += 1
		last_context = target_context.duplicate(true)
		last_product = str(target_context.get("product_id", ""))
		return true

	func apply_futures(_player_index: int, _skill: Dictionary, target_context: Dictionary = {}) -> bool:
		calls += 1
		last_context = target_context.duplicate(true)
		last_product = str(target_context.get("product_id", ""))
		return true

	func apply_product_contract_boon(_player_index: int, _skill: Dictionary, target_context: Dictionary = {}) -> bool:
		calls += 1
		last_context = target_context.duplicate(true)
		last_product = str(target_context.get("product_id", ""))
		return true

	func apply_market_stabilize(_skill: Dictionary, target_context: Dictionary = {}) -> bool:
		calls += 1
		last_context = target_context.duplicate(true)
		last_product = str(target_context.get("product_id", ""))
		return true

	func apply_product_growth_boon(_skill: Dictionary, target_context: Dictionary = {}) -> bool:
		calls += 1
		last_context = target_context.duplicate(true)
		last_product = str(target_context.get("product_id", ""))
		return true

	func apply_news_market_pressure(_effect: Dictionary, target_context: Dictionary = {}) -> Dictionary:
		calls += 1
		last_context = target_context.duplicate(true)
		last_product = str(target_context.get("product_id", ""))
		return {"changed": true, "product_id": last_product, "demand_delta": 1, "supply_delta": 0, "volatility_delta": 0}

	func futures_terms(_skill: Dictionary) -> Dictionary:
		return {
			"card_id": "仓储测试期货",
			"direction": "up",
			"units": 1,
			"duration_seconds": 30.0,
			"requires_warehouse": true,
			"margin_cash": 10,
			"action_fee_cash": 0,
			"multiplier": 1.0,
			"maximum_gain": 20,
			"maximum_loss": 10,
			"settlement_formula_id": "product_futures_v04_settlement",
			"warehouse_loss_formula_id": "warehouse_futures_v04_loss",
			"terms_version": "v0.6-test",
		}


class MarketWorld:

	extends Node

	var cash_calls := 0
	var warehouse_clue_calls := 0

	func _commit_product_market_cash_delta(_player_index: int, _cash_delta: int, _source: String, _product_name: String, _reason: String, _income_amount: int) -> Dictionary:
		cash_calls += 1
		return {"committed": true, "cash_after": 990}

	func _append_product_futures_warehouse_clue(_district_index: int, _source: String, _direction: String, _product_name: String, _units: int, _duration_seconds: float) -> void:
		warehouse_clue_calls += 1

	func _refresh_warehouse_stockpile_city_markers() -> void:
		pass

	func _present_product_futures_opened(_source: String, _product_name: String, _direction: String, _before_price: int, _duration_seconds: float, _warehouse_district: int) -> void:
		pass

	func _default_economy_product() -> String:
		return "磁核榴莲"

	func _balance_product_price_model(base_price: int, _supply: int, _demand: int, _disrupted: int, _unused: int, _weather_modifier: int, _volatility: int, _noise: float, _growth_multiplier: float) -> Dictionary:
		return {"price": base_price, "delta": 0, "raw_delta": 0, "step_cap": 1, "driver_summary": "fixture"}


class WarehouseMarket:

	extends ProductMarketRuntimeController

	var refresh_calls := 0

	func futures_terms(_skill: Dictionary) -> Dictionary:
		return {
			"card_id": "仓储测试期货",
			"direction": "up",
			"units": 1,
			"duration_seconds": 30.0,
			"requires_warehouse": true,
			"margin_cash": 10,
			"action_fee_cash": 0,
			"multiplier": 1.0,
			"maximum_gain": 20,
			"maximum_loss": 10,
			"settlement_formula_id": "product_futures_v04_settlement",
			"warehouse_loss_formula_id": "warehouse_futures_v04_loss",
			"terms_version": "v0.6-test",
		}

	func refresh_prices() -> Dictionary:
		refresh_calls += 1
		return {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := FixtureWorld.new()
	var selection := TableSelectionState.new()
	var bridge := BRIDGE_SCENE.instantiate()
	var formula := FORMULA_SCENE.instantiate()
	var market := RecordingMarket.new()
	root.add_child(world)
	root.add_child(selection)
	root.add_child(bridge)
	root.add_child(formula)
	root.add_child(market)
	formula.configure({"ruleset_id": "v0.4"})
	bridge.set_world_session_state(world)
	bridge.set_table_selection_state(selection)
	bridge.set_formula_runtime_service(formula)
	bridge.set_product_market_runtime_controller(market)
	var catalogs := _catalogs()
	var envelope := StableTargetEnvelope.capture(_selection_snapshot("星露莓", 0), catalogs.region, catalogs.product, {"capture_source": "focused_test"})
	_expect(not envelope.is_empty(), "stable target envelope captures product and region")
	var entry := {
		"resolution_id": 41,
		"selected_card_resolution_id": -1,
		"selected_district": 0,
		"selected_trade_product": "星露莓",
		"target_slot": -1,
		"target_monster_uid": -1,
		"target_player": -1,
		"play_requirement_district": -1,
		"stable_target_envelope": envelope,
	}
	var context_result := FrozenTargetContext.from_entry(entry, world, false)
	_expect(bool(context_result.get("valid", false)), "stable product target context validates")
	var context: Dictionary = context_result.get("context", {}) as Dictionary
	_expect(TablePresentationPureDataPolicy.is_pure_data(context), "frozen product target context is pure data")
	_expect(not JSON.stringify(context).contains("cash") and not JSON.stringify(context).contains("hand") and not JSON.stringify(context).contains("owner"), "frozen context contains no private owner state")
	selection.restore({"selected_district": 1, "selected_trade_product": "磁核榴莲"})
	var plan := _effect_plan("product_speculation", entry, {"name": "冻结商品测试牌", "price_delta": 1})
	var receipt: Dictionary = bridge.apply_effect(plan)
	_expect(bool(receipt.get("resolved", false)) and market.calls == 1, "product effect dispatches exactly once")
	_expect(market.last_product == "星露莓", "delayed product effect uses frozen product instead of current UI focus")
	_expect(selection.selected_trade_product == "磁核榴莲" and selection.selected_district == 1, "frozen product execution does not overwrite presentation focus")
	var tampered := entry.duplicate(true)
	var tampered_envelope: Dictionary = (tampered["stable_target_envelope"] as Dictionary).duplicate(true)
	tampered_envelope["product_id"] = "磁核榴莲"
	tampered["stable_target_envelope"] = tampered_envelope
	var tampered_receipt: Dictionary = bridge.apply_effect(_effect_plan("product_speculation", tampered, {"name": "篡改测试牌", "price_delta": 1}))
	_expect(not bool(tampered_receipt.get("resolved", false)) and market.calls == 1, "tampered envelope fails closed before market mutation")
	world.replace_districts([world.districts[1], world.districts[0]], true)
	var resolved_after_reorder := StableTargetEnvelope.resolved_entry(entry, world)
	var reordered_entry: Dictionary = resolved_after_reorder.get("entry", {}) if resolved_after_reorder.get("entry", {}) is Dictionary else {}
	var reordered_context := FrozenTargetContext.from_entry(reordered_entry, world, false)
	_expect(bool(reordered_context.get("valid", false)) and int((reordered_context.get("context", {}) as Dictionary).get("region_district_index", -1)) == 1, "stable region identity survives district reorder")
	var legacy_entry := {"resolution_id": 42, "selected_district": 1, "selected_trade_product": "星露莓"}
	var legacy_context := FrozenTargetContext.from_entry(legacy_entry, world, false)
	_expect(bool(legacy_context.get("valid", false)) and str((legacy_context.get("context", {}) as Dictionary).get("source", "")) == FrozenTargetContext.SOURCE_LEGACY_ENTRY, "legacy queue uses its detached numeric target without live focus")
	var missing_product := FrozenTargetContext.from_entry({"selected_district": 1, "selected_trade_product": ""}, world, false)
	_expect(not bool(missing_product.get("valid", false)), "missing legacy product fails closed")
	_test_warehouse_context(world, entry, catalogs)
	for node in [market, formula, bridge, selection, world]:
		node.free()
	print("CARD_RESOLUTION_PRODUCT_MARKET_TARGET_ENVELOPE|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _test_warehouse_context(world: FixtureWorld, entry: Dictionary, catalogs: Dictionary) -> void:
	var warehouse_entry := entry.duplicate(true)
	warehouse_entry["selected_district"] = 1
	var context_result := FrozenTargetContext.from_entry(warehouse_entry, world, true)
	_expect(bool(context_result.get("valid", false)), "warehouse target context validates")
	var warehouse_context: Dictionary = context_result.get("context", {}) as Dictionary
	var product_context_result := FrozenTargetContext.from_entry(warehouse_entry, world, false)
	var product_context: Dictionary = product_context_result.get("context", {}) as Dictionary
	var market_world := MarketWorld.new()
	var market_bridge := ProductMarketRuntimeWorldBridge.new()
	var market := WarehouseMarket.new()
	var selection := TableSelectionState.new()
	root.add_child(market_world)
	root.add_child(market_bridge)
	root.add_child(market)
	root.add_child(selection)
	market_bridge.bind_world(market_world)
	market_bridge.set_world_session_state(world)
	market_bridge.set_table_selection_state(selection)
	market.set_world_bridge(market_bridge)
	market.product_market = {"星露莓": {"base_price": 50, "price": 50, "volatility": 4, "price_history": [50], "futures_positions": []}}
	selection.restore({"selected_district": 0, "selected_trade_product": "磁核榴莲"})
	var speculation_applied := market.apply_speculation(0, {"name": "冻结商品测试牌", "price_delta": 1}, product_context)
	_expect(speculation_applied, "real ProductMarket applies the frozen product target")
	_expect(selection.selected_trade_product == "磁核榴莲" and selection.selected_district == 0, "real ProductMarket leaves presentation focus unchanged")
	var skill := {"name": "仓储测试期货", "futures_terms": {"card_id": "仓储测试期货"}}
	var opened := market.open_futures_position(0, skill, warehouse_context)
	var positions: Array = (market.market_entry("星露莓").get("futures_positions", []) as Array)
	_expect(bool(opened.get("committed", false)) and positions.size() == 1, "warehouse future commits through frozen target")
	_expect(not positions.is_empty() and str((positions[0] as Dictionary).get("warehouse_region_id", "")) == "region.000", "warehouse position stores stable region identity")
	var cash_calls_before := market_world.cash_calls
	world.districts[1]["city"]["owner"] = 1
	var rejected := market.open_futures_position(0, skill, warehouse_context)
	_expect(not bool(rejected.get("committed", false)) and str(rejected.get("reason", "")) == "warehouse_owner_mismatch", "warehouse owner is revalidated at execution")
	_expect(market_world.cash_calls == cash_calls_before and (market.market_entry("星露莓").get("futures_positions", []) as Array).size() == 1, "warehouse authorization failure mutates no cash or position")
	selection.free()
	market.free()
	market_bridge.free()
	market_world.free()


func _catalogs() -> Dictionary:
	var region := PublicRegionSelectionCatalogSnapshot.new().build(true, "", [
		{"region_id": "region.000", "public_index": 0, "public_name": "北环区", "public_status": "active", "selectable": true, "disabled_reason": "", "public_terrain": "land"},
		{"region_id": "region.001", "public_index": 1, "public_name": "南环区", "public_status": "active", "selectable": true, "disabled_reason": "", "public_terrain": "land"},
	], "target-session", 1, true)
	var product := PublicProductSelectionCatalogSnapshot.new().build(true, "", [
		{"product_id": "星露莓", "public_index": 0, "public_name": "星露莓", "selectable": true, "disabled_reason": "", "public_category": "food"},
		{"product_id": "磁核榴莲", "public_index": 1, "public_name": "磁核榴莲", "selectable": true, "disabled_reason": "", "public_category": "energy"},
	], "target-session", 1, true)
	return {"region": region, "product": product}


func _selection_snapshot(product_id: String, district_index: int) -> Dictionary:
	return {
		"schema_version": 1,
		"revision": 7,
		"selected_player": 0,
		"inspected_player": 0,
		"selected_district": district_index,
		"selected_trade_product": product_id,
		"selected_card_resolution_id": -1,
		"selected_hand_slot": -1,
		"selected_map_layer_focus": "all",
	}


func _effect_plan(handler_id: String, entry: Dictionary, skill: Dictionary) -> Dictionary:
	var active_entry := entry.duplicate(true)
	active_entry["player_index"] = 0
	var resolved_skill := skill.duplicate(true)
	resolved_skill["kind"] = handler_id
	return {
		"status": "ready",
		"supported": true,
		"handler_id": handler_id,
		"effect_payload": {"player_index": 0, "active_entry": active_entry, "skill": resolved_skill},
	}


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(label)
	push_error("FAIL: %s" % label)
