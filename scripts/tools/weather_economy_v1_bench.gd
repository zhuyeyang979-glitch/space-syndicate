extends Control
class_name WeatherEconomyV1Bench

const WEATHER_CONTROLLER_SCENE := preload("res://scenes/runtime/WeatherRuntimeController.tscn")
const WEATHER_BRIDGE_SCENE := preload("res://scenes/runtime/WeatherRuntimeWorldBridge.tscn")
const MARKET_CONTROLLER_SCENE := preload("res://scenes/runtime/ProductMarketRuntimeController.tscn")
const MARKET_BRIDGE_SCENE := preload("res://scenes/runtime/ProductMarketRuntimeWorldBridge.tscn")
const FLOW_CONTROLLER_SCENE := preload("res://scenes/runtime/CommodityFlowRuntimeController.tscn")
const PROFILE := preload("res://resources/rules/space_syndicate_ruleset_v06.tres")
const PRODUCT_CATALOG := preload("res://resources/content/product_industry_catalog_v05.tres")
const WEATHER_CATALOG := preload("res://resources/weather/weather_definition_catalog_v1.tres")
const BALANCE_SCRIPT := preload("res://scripts/balance/runtime_balance_model.gd")

@export var auto_run := true

@onready var summary_label: Label = %SummaryLabel
@onready var detail_label: RichTextLabel = %DetailLabel

var _clock: FakeClock
var _world: FakeWorld
var _weather_bridge: WeatherRuntimeWorldBridge
var _weather: WeatherRuntimeController
var _market_bridge: ProductMarketRuntimeWorldBridge
var _market: ProductMarketRuntimeController
var _checks := 0
var _failures: Array[String] = []
var _case_lines: Array[String] = []


class FakeClock:
	extends Node
	var us := 0

	func world_effective_micros() -> int:
		return us

	func restore_micros(value: int) -> Dictionary:
		us = maxi(0, value)
		return {"world_effective_us": us}


class FakeWorld:
	extends Node
	var rng := RandomNumberGenerator.new()
	var districts: Array = []
	var auto_monsters: Array = []
	var players: Array = [{"cash": 999999, "hand": ["PRIVATE_CARD"], "ai_plan": "PRIVATE_PLAN"}]
	var selected_player := 0
	var selected_district := 0
	var selected_trade_product := ""
	var game_time := 120.0
	var last_price_model_args: Array = []
	var weather_modifier_calls: Array = []
	var balance := BALANCE_SCRIPT.new()

	func _balance_product_price_model(base_price: int, supply: int, demand: int, disrupted: int, monster_pressure: int, weather_modifier: int, volatility: int, noise: float, growth_multiplier: float) -> Dictionary:
		last_price_model_args = [base_price, supply, demand, disrupted, monster_pressure, weather_modifier, volatility, noise, growth_multiplier]
		weather_modifier_calls.append(weather_modifier)
		return balance.product_price_model(base_price, supply, demand, disrupted, monster_pressure, weather_modifier, volatility, noise, growth_multiplier)

	func _balance_product_price_step_cap(volatility: int, base_price: int) -> int:
		return int(balance.product_price_step_cap(volatility, base_price))

	func _roll_timer(_kind: String) -> float:
		return 8.0

	func _duration_short_text(seconds: float) -> String:
		return "%d秒" % ceili(maxf(0.0, seconds))

	func _district_center(index: int) -> Vector2:
		return Vector2(float(index) * 10.0, 0.0)

	func _log(_message: String) -> void:
		pass

	func _add_action_callout(_source: String, _title: String, _detail: String, _accent: Color, _world_position: Vector2, _duration := 5.0) -> void:
		pass


class FlowFactsBridge:
	extends Node
	var facts: Dictionary = {}
	var batches: Array = []

	func capture_flow_facts() -> Dictionary:
		return facts.duplicate(true)

	func apply_sale_receipt_batch(batch: Dictionary) -> Dictionary:
		batches.append(batch.duplicate(true))
		return {"applied": true, "receipt_count": (batch.get("receipts", []) as Array).size()}

	func notify_sale_receipt_batch_committed(_batch: Dictionary) -> void:
		pass


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_suite")


func run_suite() -> void:
	_checks = 0
	_failures.clear()
	_case_lines.clear()
	_setup()
	_case_price_model_weather_contribution()
	_case_product_tag_matrix()
	_case_flow_multiplier_matrix()
	_case_fade_resistance_exploitation_and_end()
	_case_income_and_public_explanations()
	_update_ui()
	print("WEATHER_ECONOMY_V1_BENCH|status=%s|checks=%d|failures=%d|details=%s" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
		JSON.stringify(_failures),
	])


func debug_snapshot() -> Dictionary:
	return {
		"bench_complete": true,
		"status": "PASS" if _failures.is_empty() else "FAIL",
		"check_count": _checks,
		"failure_count": _failures.size(),
		"failed_cases": _failures.duplicate(),
	}


func _setup() -> void:
	_clock = FakeClock.new()
	_world = FakeWorld.new()
	_world.rng.seed = 7102026
	_world.districts = _weather_districts()
	_weather_bridge = WEATHER_BRIDGE_SCENE.instantiate() as WeatherRuntimeWorldBridge
	_weather = WEATHER_CONTROLLER_SCENE.instantiate() as WeatherRuntimeController
	_market_bridge = MARKET_BRIDGE_SCENE.instantiate() as ProductMarketRuntimeWorldBridge
	_market = MARKET_CONTROLLER_SCENE.instantiate() as ProductMarketRuntimeController
	add_child(_clock)
	add_child(_world)
	add_child(_weather_bridge)
	add_child(_weather)
	add_child(_market_bridge)
	add_child(_market)
	_weather_bridge.bind_world(_world)
	_weather.set_world_bridge(_weather_bridge)
	_weather.set_world_effective_clock(_clock)
	_weather.configure({"ruleset_id": "v0.6"})
	_market_bridge.bind_world(_world)
	_market.set_world_bridge(_market_bridge)
	_market.set_weather_runtime_controller(_weather)
	_market.reset_state()
	_expect(bool(_weather.debug_snapshot().get("controller_ready", false)), "real WeatherRuntimeController is ready")
	_expect(bool(_market.debug_snapshot().get("weather_runtime_ready", false)), "ProductMarket has the narrow Weather runtime dependency")


func _case_price_model_weather_contribution() -> void:
	var energy_product := _product_with_tags(["weather_energy"], [])
	_expect(not energy_product.is_empty(), "catalog supplies a tagged energy product")
	_activate_weather("ion_storm")
	_set_market_fixture_product(energy_product)
	_world.weather_modifier_calls.clear()
	_market.refresh_prices()
	var snapshot := _market.product_weather_contribution_snapshot(energy_product)
	var weather_modifier := int(snapshot.get("weather_modifier", 0))
	_expect(float(snapshot.get("price_growth_multiplier", 1.0)) > 1.0 and weather_modifier > 0, "ion storm creates a positive tagged energy price contribution")
	_expect(_world.weather_modifier_calls.has(weather_modifier), "weather contribution enters RuntimeBalanceModel weather_modifier before its cap")
	var public_entry: Dictionary = (_market.public_market_snapshot().get("product_market", {}) as Dictionary).get(energy_product, {})
	_expect(int(public_entry.get("price_step_cap", 0)) > 0 and int(public_entry.get("raw_trend", 0)) >= int(public_entry.get("trend", 0)), "existing price step cap still governs the weather-influenced price")
	_expect(not str(public_entry.get("weather_driver_summary", "")).is_empty(), "public price diagnostics explain the weather driver")
	var saved_entry: Dictionary = ((_market.to_save_data().get("product_market", {}) as Dictionary).get(energy_product, {}) as Dictionary)
	_expect(not saved_entry.has("weather_price_growth_multiplier") and not saved_entry.has("weather_modifier") and not saved_entry.has("weather_contributions") and not saved_entry.has("weather_driver_summary"), "ProductMarket save data does not copy the active weather projection")


func _case_product_tag_matrix() -> void:
	var energy_product := _product_with_tags(["weather_energy"], ["weather_electronic"])
	var electronic_product := _product_with_tags(["weather_electronic"], ["weather_energy", "weather_biological", "weather_medicine", "weather_food", "weather_crystal"])
	var biological_product := _product_with_tags(["weather_biological"], ["weather_energy", "weather_crystal"])
	var crystal_product := _product_with_tags(["weather_crystal"], ["weather_energy", "weather_biological"])
	var food_product := _product_with_tags(["weather_food"], ["weather_energy"])
	for product_id in [energy_product, electronic_product, biological_product, crystal_product, food_product]:
		_expect(not product_id.is_empty(), "weather matrix product is resolved from authored catalog tags")

	_activate_weather("ion_storm")
	_expect(_market_price_multiplier(energy_product) > 1.0, "ion storm matches weather_energy")
	_expect(is_equal_approx(_market_price_multiplier(electronic_product), 1.0), "ion storm ignores an electronic-only product")

	_activate_weather("solar_flare")
	_expect(_market_price_multiplier(energy_product) > 1.0, "solar flare matches weather_energy price growth")
	_expect(is_equal_approx(_market_price_multiplier(biological_product), 1.0), "solar flare ignores a biological-only product price")

	_activate_weather("gravity_tide")
	_expect(is_equal_approx(_market_price_multiplier(energy_product), 1.0), "gravity tide adds no invented commodity price effect")

	_activate_weather("spore_season")
	_expect(_flow_multiplier(biological_product, "production") > 1.0 and _flow_multiplier(biological_product, "demand") > 1.0, "spore season raises matching biological production and demand")
	_expect(is_equal_approx(_flow_multiplier(electronic_product, "production"), 1.0), "spore season ignores a nonmatching electronic product")

	_activate_weather("crystal_dust_storm")
	_expect(_flow_multiplier(crystal_product, "production") > 1.0, "crystal dust raises matching crystal production")
	_expect(is_equal_approx(_flow_multiplier(biological_product, "production"), 1.0), "crystal dust ignores a nonmatching biological product")

	_activate_weather("deep_freeze")
	_expect(_flow_multiplier(food_product, "demand") > 1.0, "deep freeze raises matching food demand")
	_expect(is_equal_approx(_flow_multiplier(crystal_product, "demand"), 1.0), "deep freeze ignores a nonmatching crystal product")

	_activate_weather("solar_flare")
	_expect(_flow_multiplier(electronic_product, "production") < 1.0, "solar flare lowers matching electronic production")
	_expect(is_equal_approx(_flow_multiplier(biological_product, "production"), 1.0), "solar flare ignores a nonmatching biological product production rate")


func _case_flow_multiplier_matrix() -> void:
	var biological_product := _product_with_tags(["weather_biological"], ["weather_energy", "weather_crystal"])
	_activate_weather("spore_season")
	var fixture := _flow_fixture(biological_product, {})
	var production_row := _rate_row(fixture.get("flow"), "production")
	var demand_row := _rate_row(fixture.get("flow"), "demand")
	_expect(int(production_row.get("effective_milliunits_per_minute", 0)) > int(production_row.get("baseline_milliunits_per_minute", 0)), "production multiplier is applied before CommodityFlow allocation")
	_expect(int(demand_row.get("effective_milliunits_per_minute", 0)) > int(demand_row.get("baseline_milliunits_per_minute", 0)), "demand multiplier is applied before CommodityFlow allocation")
	_expect(not (production_row.get("weather_contributions", []) as Array).is_empty(), "flow metrics retain a structured weather explanation row")
	_free_flow_fixture(fixture)


func _case_fade_resistance_exploitation_and_end() -> void:
	var biological_product := _product_with_tags(["weather_biological"], ["weather_energy", "weather_crystal"])
	_activate_weather("spore_season")
	var full := _flow_multiplier(biological_product, "production")
	var resisted := _flow_multiplier(biological_product, "production", {"weather_resistance": 0.5})
	var exploited := _flow_multiplier(biological_product, "production", {"weather_exploitation_multiplier": 1.5})
	_expect(full > 1.0 and resisted > 1.0 and resisted < full, "weather resistance dampens the positive production delta")
	_expect(exploited > full and exploited <= 1.30, "weather exploitation amplifies only the positive gain within the 30 percent economy cap")

	_activate_weather("spore_season", "fade_half")
	var fading := _flow_multiplier(biological_product, "production")
	_expect(fading > 1.0 and fading < full, "fade intensity gradually reduces the production effect")

	_activate_weather("spore_season", "ended")
	_expect(is_equal_approx(_flow_multiplier(biological_product, "production"), 1.0), "ended weather restores the exact production baseline")
	_expect(is_equal_approx(_market_price_multiplier(biological_product), 1.0), "ended weather leaves no stale market contribution")


func _case_income_and_public_explanations() -> void:
	var biological_product := _product_with_tags(["weather_biological"], ["weather_energy", "weather_crystal"])
	_activate_weather("gravity_tide")
	var baseline_fixture := _flow_fixture(biological_product, {}, 60.0)
	var baseline_gdp := int((baseline_fixture.get("result", {}) as Dictionary).get("gdp_value", 0))
	_free_flow_fixture(baseline_fixture)

	_activate_weather("spore_season")
	var weather_fixture := _flow_fixture(biological_product, {}, 60.0)
	var weather_result: Dictionary = weather_fixture.get("result", {})
	var weather_gdp := int(weather_result.get("gdp_value", 0))
	var gain_ratio := float(weather_gdp - baseline_gdp) / float(maxi(1, baseline_gdp))
	_expect(weather_gdp > baseline_gdp and gain_ratio >= 0.10 and gain_ratio <= 0.30, "matching weather changes realized route income within the 10-30 percent target")
	var flow: CommodityFlowRuntimeController = weather_fixture.get("flow")
	var public_weather := flow.public_weather_contribution_snapshot()
	var receipts := flow.recent_sale_receipts_snapshot(-1)
	var receipt_weather_rows: Array = []
	for receipt_variant in receipts:
		if receipt_variant is Dictionary:
			for row_variant in (receipt_variant as Dictionary).get("weather_contributions", []):
				receipt_weather_rows.append(row_variant)
	_expect(not (public_weather.get("contributions", []) as Array).is_empty(), "public income diagnostics expose structured weather contributions")
	_expect(not receipts.is_empty() and not ((receipts.back() as Dictionary).get("weather_contributions", []) as Array).is_empty(), "sale receipt history explains the weather contribution")
	_expect(not _contains_forbidden_key(public_weather) and not _contains_forbidden_key(receipt_weather_rows), "public weather explanations contain no cash, hand, owner, AI, or private fields")
	_free_flow_fixture(weather_fixture)

	var energy_product := _product_with_tags(["weather_energy"], [])
	_activate_weather("ion_storm")
	_set_market_fixture_product(energy_product)
	_market.refresh_prices()
	var market_public := _market.product_weather_contribution_snapshot(energy_product)
	_expect(not _contains_forbidden_key(market_public), "public market weather explanation passes the same privacy allowlist")


func _activate_weather(weather_id: String, phase_case := "active") -> void:
	_clock.restore_micros(0)
	_weather.reset_state()
	var definition: WeatherDefinition = WEATHER_CATALOG.definition(weather_id)
	_expect(definition != null, "weather definition exists: %s" % weather_id)
	if definition == null:
		return
	_expect(_weather.schedule_forecast(weather_id, 0, 1, definition.forecast_duration, definition.active_duration, "natural", false), "weather schedules: %s" % weather_id)
	var target_us := int(round(definition.forecast_duration * 1_000_000.0))
	if phase_case == "fade_half":
		target_us += int(round(definition.active_duration * 1_000_000.0)) + int(round(definition.fade_duration * 500_000.0))
	elif phase_case == "ended":
		target_us += int(round((definition.active_duration + definition.fade_duration) * 1_000_000.0))
	_clock.restore_micros(target_us)
	_weather.tick(0.0)


func _market_price_multiplier(product_id: String, region_overrides: Dictionary = {}) -> float:
	_set_market_fixture_product(product_id, region_overrides)
	_market.refresh_prices()
	return float(_market.product_weather_contribution_snapshot(product_id).get("price_growth_multiplier", 1.0))


func _set_market_fixture_product(product_id: String, region_overrides: Dictionary = {}) -> void:
	var district := {
		"name": "天气经济区",
		"destroyed": false,
		"products": [product_id],
		"demands": [product_id],
		"city": {"active": false},
	}
	for key_variant in region_overrides.keys():
		district[key_variant] = region_overrides[key_variant]
	_world.districts = [district]
	var entry := _market.market_entry(product_id)
	entry["base_price"] = 100
	entry["price"] = 100
	entry["volatility"] = 18
	entry["temporary_demand_pressure"] = 0
	entry["temporary_supply_pressure"] = 0
	_market.product_market[product_id] = entry


func _flow_multiplier(product_id: String, direction: String, region_overrides: Dictionary = {}) -> float:
	var fixture := _flow_fixture(product_id, region_overrides)
	var row := _rate_row(fixture.get("flow"), direction)
	var multiplier := float(row.get("weather_multiplier", 1.0))
	_free_flow_fixture(fixture)
	return multiplier


func _flow_fixture(product_id: String, region_overrides: Dictionary = {}, delta_seconds := 1.0) -> Dictionary:
	var flow := FLOW_CONTROLLER_SCENE.instantiate() as CommodityFlowRuntimeController
	var bridge := FlowFactsBridge.new()
	add_child(bridge)
	add_child(flow)
	flow.set_world_bridge(bridge)
	flow.set_weather_runtime_controller(_weather)
	flow.configure(PROFILE.debug_snapshot())
	var industry_id := str(PRODUCT_CATALOG.industry_for_product(product_id))
	var region := {
		"region_id": "region.weather.0",
		"legacy_index": 0,
		"neighbor_region_ids": [],
		"lifecycle_state": "active",
		"revision": 1,
		"integrity_basis_points": 10000,
	}
	for key_variant in region_overrides.keys():
		region[key_variant] = region_overrides[key_variant]
	var factory := {"facility_id": "factory.weather", "region_id": "region.weather.0", "facility_type": "factory", "industry_id": industry_id, "owner_kind": "player", "owner_player_index": 0, "rank": 4, "active": true}
	var market := {"facility_id": "market.weather", "region_id": "region.weather.0", "facility_type": "market", "industry_id": industry_id, "owner_kind": "neutral", "owner_player_index": -1, "rank": 4, "active": true}
	bridge.facts = {
		"game_time": 120.0,
		"regions": [region],
		"facilities": [factory, market],
		"destroyed_facility_ids": [],
		"price_cents_by_commodity": {product_id: 10000},
		"route_candidates": [],
	}
	var production := flow.install_commodity({"transaction_id": "weather-production", "facility_id": factory.facility_id, "facility": factory, "region_id": region.region_id, "region_revision": 1, "commodity_id": product_id, "direction": "production", "installer_player_index": 0, "owner_kind": "player", "source_card_rank": 4, "color": industry_id})
	var demand := flow.install_public_demand({"transaction_id": "weather-demand", "facility_id": market.facility_id, "facility": market, "region_id": region.region_id, "region_revision": 1, "commodity_id": product_id, "source_card_rank": 4, "color": industry_id})
	_expect(bool(production.get("committed", false)) and bool(demand.get("committed", false)), "weather flow fixture installs matching production and demand")
	var result := flow.advance_world(delta_seconds, {})
	_expect(bool(result.get("advanced", false)), "weather flow fixture advances")
	return {"flow": flow, "bridge": bridge, "result": result}


func _rate_row(flow_variant: Variant, direction: String) -> Dictionary:
	var flow := flow_variant as CommodityFlowRuntimeController
	if flow == null:
		return {}
	var metrics: Dictionary = flow.debug_snapshot().get("last_flow_metrics", {})
	for row_variant in metrics.get("effective_rate_rows", []):
		if row_variant is Dictionary and str((row_variant as Dictionary).get("direction", "")) == direction:
			return (row_variant as Dictionary).duplicate(true)
	return {}


func _free_flow_fixture(fixture: Dictionary) -> void:
	var flow: Node = fixture.get("flow")
	var bridge: Node = fixture.get("bridge")
	if flow != null:
		flow.free()
	if bridge != null:
		bridge.free()


func _product_with_tags(required: Array, excluded: Array) -> String:
	for product_variant in PRODUCT_CATALOG.product_ids():
		var product_id := str(product_variant)
		var tags: Array = PRODUCT_CATALOG.tags_for_product(product_id)
		var matches := true
		for required_tag_variant in required:
			if not tags.has(str(required_tag_variant)):
				matches = false
				break
		if not matches:
			continue
		for excluded_tag_variant in excluded:
			if tags.has(str(excluded_tag_variant)):
				matches = false
				break
		if matches:
			return product_id
	return ""


func _contains_forbidden_key(value: Variant) -> bool:
	var forbidden := ["player", "cash", "hand", "discard", "owner", "ai_", "private", "city_guess"]
	if value is Dictionary:
		for key_variant in value.keys():
			var key := str(key_variant).to_lower()
			for token_variant in forbidden:
				if key.contains(str(token_variant)):
					return true
			if _contains_forbidden_key(value[key_variant]):
				return true
	elif value is Array:
		for item_variant in value:
			if _contains_forbidden_key(item_variant):
				return true
	return false


func _weather_districts() -> Array:
	return [
		{"name": "天气经济区", "destroyed": false, "terrain": "land", "neighbors": [], "products": [], "demands": [], "city": {"active": false}, "trade_volume_bucket": 2},
	]


func _update_ui() -> void:
	if summary_label != null:
		summary_label.text = "Weather Economy v1 | %s | %d checks" % ["PASS" if _failures.is_empty() else "FAIL", _checks]
	if detail_label != null:
		detail_label.text = "\n".join(_case_lines)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	_case_lines.append("[color=#75d59a]PASS[/color] %s" % message if condition else "[color=#ef7b7b]FAIL[/color] %s" % message)
	if condition:
		return
	_failures.append(message)
	push_error(message)
