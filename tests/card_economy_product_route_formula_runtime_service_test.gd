extends SceneTree

const SERVICE_SCENE := "res://scenes/runtime/CardEconomyProductRouteFormulaRuntimeService.tscn"

var _failed := false


func _initialize() -> void:
	var packed := load(SERVICE_SCENE) as PackedScene
	_expect(packed != null, "formula service scene loads")
	var service := packed.instantiate() if packed != null else null
	_expect(service != null, "formula service scene instantiates")
	if service == null:
		quit(1)
		return
	root.add_child(service)
	service.call("configure", {"ruleset_id": "v0.4"})
	var expected := [
		"city_contract_boon", "city_demand_shift_step", "city_product_shift_step",
		"city_product_upgrade", "city_revenue_route_adjustment", "city_route_flow_boon",
		"city_gdp_derivative_v04_destruction", "city_gdp_derivative_v04_projected_settlement", "city_gdp_derivative_v04_settlement",
		"merge_boon_source", "product_contract_boon", "product_futures_duration", "product_futures_v04_settlement",
		"product_futures_v04_projected_settlement", "warehouse_futures_v04_loss", "product_market_boon", "product_speculation_pressure",
		"route_base_flow", "route_flow_multiplier", "route_insurance",
	]
	_expect(service.call("supported_formulas") == expected, "service owns the exact characterized pure formula set")
	var boon := service.call("calculate", "product_market_boon", {
		"entry": {"growth_multiplier": 1.0, "route_flow_multiplier": 1.0, "growth_seconds": 15.0, "route_flow_seconds": 0.0},
		"growth_multiplier": 1.5,
		"route_flow_multiplier": 1.4,
		"turns": 2,
		"duration_seconds": 45.0,
		"source": "fixture",
		"persistent": false,
	}) as Dictionary
	var boon_entry: Dictionary = boon.get("entry", {})
	_expect(bool(boon.get("changed", false)) and is_equal_approx(float(boon_entry.get("growth_multiplier", 0.0)), 1.5) and is_equal_approx(float(boon_entry.get("route_flow_multiplier", 0.0)), 1.4), "temporary market boon preserves multiplier maxima")
	_expect(is_equal_approx(float(boon_entry.get("growth_seconds", 0.0)), 45.0) and int(boon_entry.get("growth_turns", 0)) == 2 and str(boon_entry.get("growth_source", "")) == "fixture", "temporary market boon preserves seconds and legacy-turn mirror")
	var persistent := service.call("calculate", "product_market_boon", {
		"entry": boon_entry,
		"growth_multiplier": 5.0,
		"route_flow_multiplier": 4.0,
		"source": "persistent",
		"persistent": true,
	}) as Dictionary
	var persistent_entry: Dictionary = persistent.get("entry", {})
	_expect(is_equal_approx(float(persistent_entry.get("base_growth_multiplier", 0.0)), 3.0) and is_equal_approx(float(persistent_entry.get("base_route_flow_multiplier", 0.0)), 2.8), "persistent market boon preserves characterized caps")
	var product_contract := service.call("calculate", "product_contract_boon", {
		"entry": {"market_contract_demand": 2, "market_contract_supply": 1, "market_contract_seconds": 30.0, "volatility": 4},
		"demand_pressure": 5,
		"supply_pressure": 0,
		"contract_seconds": 60.0,
		"volatility_delta": -5,
		"source": "contract-fixture",
	}) as Dictionary
	var product_contract_entry: Dictionary = product_contract.get("entry", {})
	_expect(bool(product_contract.get("changed", false)) and int(product_contract_entry.get("market_contract_demand", 0)) == 5 and int(product_contract_entry.get("market_contract_supply", 0)) == 1 and is_equal_approx(float(product_contract_entry.get("market_contract_seconds", 0.0)), 60.0) and int(product_contract_entry.get("market_contract_turns", 0)) == 2 and int(product_contract_entry.get("volatility", 0)) == 1, "product contract boon preserves maxima, duration mirror, and volatility clamp")
	var demand_pressure := service.call("calculate", "product_speculation_pressure", {"price_delta": 21}) as Dictionary
	var supply_pressure := service.call("calculate", "product_speculation_pressure", {"price_delta": -20}) as Dictionary
	_expect(int(demand_pressure.get("pressure", 0)) == 3 and str(demand_pressure.get("pressure_kind", "")) == "demand", "positive speculation uses ceil(delta/10) demand pressure")
	_expect(int(supply_pressure.get("pressure", 0)) == 2 and str(supply_pressure.get("pressure_kind", "")) == "supply", "negative speculation uses absolute supply pressure")
	var futures_seconds := service.call("calculate", "product_futures_duration", {"skill": {"futures_terms": {"duration_seconds": 4.0}}}) as Dictionary
	var futures_authored := service.call("calculate", "product_futures_duration", {"skill": {"futures_terms": {"duration_seconds": 90.0}}}) as Dictionary
	_expect(is_equal_approx(float(futures_seconds.get("seconds", 0.0)), 5.0) and is_equal_approx(float(futures_authored.get("seconds", 0.0)), 90.0), "futures duration reads the authored terms with the five-second safety floor")
	var futures_up := service.call("calculate", "product_futures_v04_settlement", {"current_price": 130, "position": {"baseline_price": 100, "direction": "up", "units": 2, "multiplier": 1.5, "locked_margin": 300, "maximum_gain": 900, "maximum_loss": 300}}) as Dictionary
	var futures_down := service.call("calculate", "product_futures_v04_settlement", {"current_price": 70, "position": {"baseline_price": 100, "direction": "down", "units": 1, "multiplier": 2.0, "locked_margin": 200, "maximum_gain": 600, "maximum_loss": 200}}) as Dictionary
	var futures_miss := service.call("calculate", "product_futures_v04_settlement", {"current_price": 90, "position": {"baseline_price": 100, "direction": "up", "units": 1, "multiplier": 1.0, "locked_margin": 120, "maximum_gain": 260, "maximum_loss": 120}}) as Dictionary
	_expect(int(futures_up.get("gain", -1)) == 900 and int(futures_up.get("cash_return", -1)) == 1200 and int(futures_down.get("gain", -1)) == 600 and int(futures_miss.get("loss", -1)) == 100, "v0.4 futures settlement preserves direction and multiplier while capping gain/loss and returning margin")
	var projected := service.call("calculate", "product_futures_v04_projected_settlement", {"skill": {"futures_terms": {"units": 2, "multiplier": 1.5, "margin_cash": 300, "maximum_gain": 800, "maximum_loss": 300}}, "benchmark_price_delta": 30}) as Dictionary
	_expect(int(projected.get("raw_gain", -1)) == 900 and int(projected.get("projected_gain", -1)) == 800, "futures projection shares the runtime payout unit and authored gain cap")
	var warehouse_loss := service.call("calculate", "warehouse_futures_v04_loss", {"position": {"locked_margin": 600, "maximum_loss": 600}, "damage_receipt": {"max_hp": 100, "pre_hit_hp": 80, "post_hit_hp": 25}}) as Dictionary
	_expect(int(warehouse_loss.get("loss", -1)) == 450 and int(warehouse_loss.get("margin_refund", -1)) == 150, "warehouse loss uses post-hit HP without overkill")
	var gdp_up := service.call("calculate", "city_gdp_derivative_v04_settlement", {"current_gdp": 150, "position": {"baseline_gdp": 100, "direction": "up", "multiplier": 1.5, "locked_margin": 120, "maximum_gain": 260, "maximum_loss": 120}}) as Dictionary
	var gdp_down := service.call("calculate", "city_gdp_derivative_v04_settlement", {"current_gdp": 70, "position": {"baseline_gdp": 100, "direction": "down", "multiplier": 2.0, "locked_margin": 180, "maximum_gain": 420, "maximum_loss": 180}}) as Dictionary
	var gdp_loss := service.call("calculate", "city_gdp_derivative_v04_settlement", {"current_gdp": 70, "position": {"baseline_gdp": 100, "direction": "up", "multiplier": 2.0, "locked_margin": 120, "maximum_gain": 260, "maximum_loss": 120}}) as Dictionary
	var gdp_flat := service.call("calculate", "city_gdp_derivative_v04_settlement", {"current_gdp": 100, "position": {"baseline_gdp": 100, "direction": "up", "multiplier": 1.0, "locked_margin": 120, "maximum_gain": 260, "maximum_loss": 120}}) as Dictionary
	var gdp_destroy := service.call("calculate", "city_gdp_derivative_v04_destruction", {"position": {"baseline_gdp": 100, "direction": "down", "multiplier": 1.5, "destroy_bonus": 40, "locked_margin": 180, "maximum_gain": 420, "maximum_loss": 180}}) as Dictionary
	_expect(int(gdp_up.get("gain", -1)) == 75 and int(gdp_up.get("cash_return", -1)) == 195 and int(gdp_down.get("gain", -1)) == 60 and int(gdp_loss.get("loss", -1)) == 60 and int(gdp_flat.get("cash_return", -1)) == 120 and int(gdp_destroy.get("gain", -1)) == 190, "v0.4 GDP derivatives cap two-way PnL, refund flat margin, and settle destruction through one formula family")
	var route := service.call("calculate", "route_base_flow", {"source_factor": 1.44, "destination_factor": 1.0, "relation": 0.5}) as Dictionary
	var multiplier := service.call("calculate", "route_flow_multiplier", {"city_multiplier": 1.5, "product_multiplier": 2.0}) as Dictionary
	_expect(is_equal_approx(float(route.get("value", 0.0)), 1.26), "route base flow preserves geometric-mean and relation formula")
	_expect(is_equal_approx(float(multiplier.get("value", 0.0)), 2.8), "route multiplier composition preserves the 2.8 cap")
	var city_flow := service.call("calculate", "city_route_flow_boon", {
		"city": {"trade_route_damage": 3, "route_flow_multiplier": 1.2, "route_flow_seconds": 30.0},
		"repair_routes": 1,
		"route_flow_multiplier": 1.5,
		"route_flow_seconds": 60.0,
		"source": "flow-fixture",
	}) as Dictionary
	var city_flow_state: Dictionary = city_flow.get("city", {})
	_expect(bool(city_flow.get("changed", false)) and int(city_flow_state.get("trade_route_damage", -1)) == 2 and is_equal_approx(float(city_flow_state.get("route_flow_multiplier", 0.0)), 1.5) and is_equal_approx(float(city_flow_state.get("route_flow_seconds", 0.0)), 60.0), "city route boon preserves repair, maximum multiplier, and longest duration")
	var insurance := service.call("calculate", "route_insurance", {
		"city": {"trade_route_damage": 3, "revenue_bonus": 2, "route_flow_multiplier": 1.1},
		"repair_routes": 2,
		"revenue_amount": 4,
		"route_flow_multiplier": 1.4,
		"route_flow_seconds": 60.0,
		"source": "insurance-fixture",
	}) as Dictionary
	var insured_city: Dictionary = insurance.get("city", {})
	_expect(bool(insurance.get("changed", false)) and int(insured_city.get("trade_route_damage", -1)) == 1 and int(insured_city.get("revenue_bonus", -1)) == 6 and is_equal_approx(float(insured_city.get("route_flow_multiplier", 0.0)), 1.4), "route insurance preserves route repair, permanent revenue, and temporary flow boon")
	var upgraded := service.call("calculate", "city_product_upgrade", {
		"city": {"products": [{"name": "A", "level": 3}, {"name": "B", "level": 1}], "revenue_bonus": 2},
		"level_gain": 2,
		"revenue_amount": 5,
	}) as Dictionary
	var upgraded_city: Dictionary = upgraded.get("city", {})
	var upgraded_products: Array = upgraded_city.get("products", [])
	_expect(bool(upgraded.get("changed", false)) and int(upgraded.get("product_index", -1)) == 1 and int((upgraded_products[1] as Dictionary).get("level", 0)) == 3 and int(upgraded_city.get("revenue_bonus", 0)) == 7, "city product upgrade preserves first-lowest selection, level cap path, and revenue")
	var product_shift := service.call("calculate", "city_product_shift_step", {"products": [{"name": "A", "level": 3}, {"name": "B", "level": 1}], "new_product": "C"}) as Dictionary
	var shifted_products: Array = product_shift.get("products", [])
	_expect(int(product_shift.get("replace_index", -1)) == 1 and str(product_shift.get("old_name", "")) == "B" and str((shifted_products[1] as Dictionary).get("name", "")) == "C" and int((shifted_products[1] as Dictionary).get("level", 0)) == 1, "city product shift preserves first-lowest replacement and resets level to one")
	var demand_shift := service.call("calculate", "city_demand_shift_step", {"demands": ["A", "B"], "iteration": 3, "new_demand": "C"}) as Dictionary
	_expect(int(demand_shift.get("replace_index", -1)) == 1 and (demand_shift.get("demands", []) as Array) == ["A", "C"], "city demand shift preserves modulo replacement order")
	var adjustment := service.call("calculate", "city_revenue_route_adjustment", {"city": {"trade_route_damage": 3, "revenue_bonus": 2}, "repair_routes": 5, "revenue_amount": 4}) as Dictionary
	var adjusted_city: Dictionary = adjustment.get("city", {})
	_expect(int(adjusted_city.get("trade_route_damage", -1)) == 0 and int(adjusted_city.get("revenue_bonus", -1)) == 6, "city adjustment preserves zero-floor route repair and permanent revenue")
	var city_contract := service.call("calculate", "city_contract_boon", {
		"city": {"contract_income_bonus": 1, "contract_seconds": 30.0, "route_flow_multiplier": 1.2, "route_flow_seconds": 20.0},
		"contract_income": 5,
		"contract_seconds": 60.0,
		"route_flow_multiplier": 1.5,
		"route_flow_seconds": 90.0,
		"source": "city-contract-fixture",
	}) as Dictionary
	var contracted_city: Dictionary = city_contract.get("city", {})
	_expect(bool(city_contract.get("changed", false)) and int(contracted_city.get("contract_income_bonus", 0)) == 5 and is_equal_approx(float(contracted_city.get("contract_seconds", 0.0)), 60.0) and is_equal_approx(float(contracted_city.get("route_flow_multiplier", 0.0)), 1.5) and is_equal_approx(float(contracted_city.get("route_flow_seconds", 0.0)), 90.0), "city contract boon preserves contract and route maxima")
	var merged := service.call("calculate", "merge_boon_source", {"existing": "A", "source": "B"}) as Dictionary
	var duplicate := service.call("calculate", "merge_boon_source", {"existing": "A、B", "source": "B"}) as Dictionary
	_expect(str(merged.get("value", "")) == "A、B" and str(duplicate.get("value", "")) == "A、B", "boon source merge remains stable and duplicate-safe")
	var bad_input := {"node": Node.new()}
	var rejected := service.call("calculate", "route_base_flow", bad_input) as Dictionary
	(bad_input["node"] as Node).free()
	_expect(str(rejected.get("reason", "")) == "input_not_data_only", "runtime objects are rejected from formulas")
	var ownership := service.call("formula_ownership_snapshot") as Dictionary
	var debug := service.call("debug_snapshot") as Dictionary
	_expect(str((ownership.get("delegated_formulas", {}) as Dictionary).get("product_price", "")) == "RuntimeBalanceModel" and str((ownership.get("delegated_formulas", {}) as Dictionary).get("city_gdp", "")) == "GdpFormulaRuntimeController", "already modular price and GDP formulas retain their existing owners")
	_expect(_is_data_only(debug) and bool(debug.get("pure_formula_authority", false)) and not bool(debug.get("effect_dispatch_authority", true)) and not bool(debug.get("world_mutation_authority", true)) and not bool(debug.get("execution_lifecycle_authority", true)), "formula service is pure-data and does not expand execution or world ownership")
	service.queue_free()
	print("Card economy/product/route formula runtime service test %s." % ["failed" if _failed else "passed"])
	quit(1 if _failed else 0)


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
