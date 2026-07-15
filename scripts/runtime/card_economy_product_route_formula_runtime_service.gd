@tool
extends Node
class_name CardEconomyProductRouteFormulaRuntimeService

const SERVICE_ID := "card_economy_product_route_formula_runtime_v1"
const LEGACY_TURN_SECONDS := 30.0
const PRODUCT_FUTURES_PAYOUT_UNIT := 10
const PRODUCT_GROWTH_MULTIPLIER_MAX := 3.0
const PRODUCT_VOLATILITY_MIN := 1
const PRODUCT_VOLATILITY_MAX := 30
const ROUTE_FLOW_MULTIPLIER_MAX := 2.8
const CITY_PRODUCT_LEVEL_MAX := 5
const REGION_ECONOMY_LEVEL_MIN := 1
const REGION_ECONOMY_LEVEL_MAX := 5
const REGION_TRANSPORT_SCORE_MIN := 0.6
const REGION_TRANSPORT_SCORE_MAX := 2.4

const FORMULA_IDS := [
	"city_contract_boon",
	"city_demand_shift_step",
	"city_product_shift_step",
	"city_product_upgrade",
	"city_revenue_route_adjustment",
	"city_route_flow_boon",
	"city_gdp_derivative_v04_destruction",
	"city_gdp_derivative_v04_projected_settlement",
	"city_gdp_derivative_v04_settlement",
	"merge_boon_source",
	"news_event_region_effect",
	"product_contract_boon",
	"product_futures_duration",
	"product_futures_v04_settlement",
	"product_futures_v04_projected_settlement",
	"warehouse_futures_v04_loss",
	"product_market_boon",
	"product_speculation_pressure",
	"route_base_flow",
	"route_flow_multiplier",
	"route_insurance",
]

const DELEGATED_FORMULA_OWNERS := {
	"city_gdp": "GdpFormulaRuntimeController",
	"product_flow_speed": "RuntimeBalanceModel",
	"product_price": "RuntimeBalanceModel",
}

var _configured := false
var _ruleset_id := ""


func configure(config: Dictionary = {}) -> void:
	_ruleset_id = str(config.get("ruleset_id", "v0.4"))
	_configured = _ruleset_id == "v0.4"


func supported_formulas() -> Array:
	return FORMULA_IDS.duplicate()


func supports_formula(formula_id: String) -> bool:
	return FORMULA_IDS.has(formula_id)


func calculate(formula_id: String, input_snapshot: Dictionary) -> Dictionary:
	if not _configured:
		return _failure(formula_id, "service_not_configured")
	if not _is_data_only(input_snapshot):
		return _failure(formula_id, "input_not_data_only")
	if not supports_formula(formula_id):
		return _failure(formula_id, "formula_not_owned")
	match formula_id:
		"city_contract_boon":
			return _city_contract_boon(input_snapshot)
		"city_demand_shift_step":
			return _city_demand_shift_step(input_snapshot)
		"city_product_shift_step":
			return _city_product_shift_step(input_snapshot)
		"city_product_upgrade":
			return _city_product_upgrade(input_snapshot)
		"city_revenue_route_adjustment":
			return _city_revenue_route_adjustment(input_snapshot)
		"city_route_flow_boon":
			return _city_route_flow_boon(input_snapshot)
		"product_market_boon":
			return _product_market_boon(input_snapshot)
		"product_contract_boon":
			return _product_contract_boon(input_snapshot)
		"product_speculation_pressure":
			return _product_speculation_pressure(input_snapshot)
		"product_futures_duration":
			return _product_futures_duration(input_snapshot)
		"product_futures_v04_settlement":
			return _product_futures_v04_settlement(input_snapshot)
		"product_futures_v04_projected_settlement":
			return _product_futures_v04_projected_settlement(input_snapshot)
		"warehouse_futures_v04_loss":
			return _warehouse_futures_v04_loss(input_snapshot)
		"city_gdp_derivative_v04_settlement":
			return _city_gdp_derivative_v04_settlement(input_snapshot)
		"city_gdp_derivative_v04_destruction":
			return _city_gdp_derivative_v04_destruction(input_snapshot)
		"city_gdp_derivative_v04_projected_settlement":
			return _city_gdp_derivative_v04_projected_settlement(input_snapshot)
		"route_base_flow":
			return _route_base_flow(input_snapshot)
		"route_flow_multiplier":
			return _route_flow_multiplier(input_snapshot)
		"merge_boon_source":
			return _merge_boon_source_result(input_snapshot)
		"news_event_region_effect":
			return _news_event_region_effect(input_snapshot)
		"route_insurance":
			return _route_insurance(input_snapshot)
	return _failure(formula_id, "formula_not_implemented")


func formula_ownership_snapshot() -> Dictionary:
	return {
		"owned_formulas": supported_formulas(),
		"delegated_formulas": DELEGATED_FORMULA_OWNERS.duplicate(true),
	}


func debug_snapshot() -> Dictionary:
	return {
		"service_id": SERVICE_ID,
		"ruleset_id": _ruleset_id,
		"service_ready": _configured,
		"service_authoritative": _configured,
		"pure_formula_authority": true,
		"effect_dispatch_authority": false,
		"world_mutation_authority": false,
		"execution_lifecycle_authority": false,
		"queue_authority": false,
		"timing_authority": false,
		"inventory_authority": false,
		"formula_ownership": formula_ownership_snapshot(),
	}


func _product_contract_boon(input_snapshot: Dictionary) -> Dictionary:
	var entry := _dictionary(input_snapshot.get("entry", {}))
	if entry.is_empty():
		return _failure("product_contract_boon", "market_entry_missing")
	var before_demand := int(entry.get("market_contract_demand", 0))
	var before_supply := int(entry.get("market_contract_supply", 0))
	var before_seconds := _remaining_effect_seconds(entry, "market_contract_seconds", "market_contract_turns")
	var before_volatility := int(entry.get("volatility", 4))
	var demand_pressure := maxi(0, int(input_snapshot.get("demand_pressure", 0)))
	var supply_pressure := maxi(0, int(input_snapshot.get("supply_pressure", 0)))
	var contract_seconds := maxf(0.0, float(input_snapshot.get("contract_seconds", 0.0)))
	var source := str(input_snapshot.get("source", ""))
	if demand_pressure > 0 or supply_pressure > 0:
		entry["market_contract_demand"] = maxi(before_demand, demand_pressure)
		entry["market_contract_supply"] = maxi(before_supply, supply_pressure)
		_set_remaining_effect_seconds(entry, "market_contract_seconds", "market_contract_turns", maxf(before_seconds, contract_seconds))
		entry["market_contract_source"] = _merge_boon_source(str(entry.get("market_contract_source", "")), source)
	var volatility_delta := int(input_snapshot.get("volatility_delta", 0))
	if volatility_delta != 0:
		entry["volatility"] = clampi(before_volatility + volatility_delta, PRODUCT_VOLATILITY_MIN, PRODUCT_VOLATILITY_MAX)
	var after_demand := int(entry.get("market_contract_demand", 0))
	var after_supply := int(entry.get("market_contract_supply", 0))
	var after_seconds := _remaining_effect_seconds(entry, "market_contract_seconds", "market_contract_turns")
	var after_volatility := int(entry.get("volatility", before_volatility))
	return _success("product_contract_boon", {
		"entry": entry,
		"changed": after_demand > before_demand or after_supply > before_supply or after_seconds > before_seconds or after_volatility != before_volatility,
		"before_demand": before_demand,
		"after_demand": after_demand,
		"before_supply": before_supply,
		"after_supply": after_supply,
		"before_seconds": before_seconds,
		"after_seconds": after_seconds,
		"before_volatility": before_volatility,
		"after_volatility": after_volatility,
	})


func _news_event_region_effect(input_snapshot: Dictionary) -> Dictionary:
	var district := _dictionary(input_snapshot.get("district", {}))
	var effect := _dictionary(input_snapshot.get("effect", {}))
	if district.is_empty():
		return _failure("news_event_region_effect", "district_missing")
	if bool(district.get("destroyed", false)):
		return _failure("news_event_region_effect", "district_destroyed")
	var before_panic := clampi(int(district.get("panic", 0)), 0, 100)
	var before_production := clampi(int(district.get("production_level", 2)), REGION_ECONOMY_LEVEL_MIN, REGION_ECONOMY_LEVEL_MAX)
	var before_transport := clampi(int(district.get("transport_level", 2)), REGION_ECONOMY_LEVEL_MIN, REGION_ECONOMY_LEVEL_MAX)
	var before_consumption := clampi(int(district.get("consumption_level", 2)), REGION_ECONOMY_LEVEL_MIN, REGION_ECONOMY_LEVEL_MAX)
	var panic_gain := maxi(0, int(effect.get("panic", 0)))
	var after_panic := clampi(before_panic + panic_gain, 0, 100)
	var after_production := clampi(before_production + int(effect.get("production_delta", 0)), REGION_ECONOMY_LEVEL_MIN, REGION_ECONOMY_LEVEL_MAX)
	var after_transport := clampi(before_transport + int(effect.get("transport_delta", 0)), REGION_ECONOMY_LEVEL_MIN, REGION_ECONOMY_LEVEL_MAX)
	var after_consumption := clampi(before_consumption + int(effect.get("consumption_delta", 0)), REGION_ECONOMY_LEVEL_MIN, REGION_ECONOMY_LEVEL_MAX)
	district["panic"] = after_panic
	district["production_level"] = after_production
	district["transport_level"] = after_transport
	district["consumption_level"] = after_consumption
	var transport_base := 1.25 if str(district.get("terrain", "land")) == "ocean" else 1.0
	district["transport_score"] = clampf(
		transport_base + float(after_transport - REGION_ECONOMY_LEVEL_MIN) * 0.18,
		REGION_TRANSPORT_SCORE_MIN,
		REGION_TRANSPORT_SCORE_MAX
	)
	var route_damage := maxi(0, int(effect.get("route_damage", 0)))
	var city: Dictionary = district.get("city", {}) if district.get("city", {}) is Dictionary else {}
	var city_active := not city.is_empty() and bool(city.get("active", true))
	var before_route_damage := int(city.get("trade_route_damage", 0)) if city_active else 0
	if city_active and route_damage > 0:
		city["trade_route_damage"] = before_route_damage + route_damage
		district["city"] = city
	var after_route_damage := int(city.get("trade_route_damage", 0)) if city_active else 0
	return _success("news_event_region_effect", {
		"district": district,
		"changed": (
			after_panic != before_panic
			or after_production != before_production
			or after_transport != before_transport
			or after_consumption != before_consumption
			or after_route_damage != before_route_damage
		),
		"before_panic": before_panic,
		"after_panic": after_panic,
		"panic_delta": after_panic - before_panic,
		"before_production": before_production,
		"after_production": after_production,
		"before_transport": before_transport,
		"after_transport": after_transport,
		"before_consumption": before_consumption,
		"after_consumption": after_consumption,
		"before_route_damage": before_route_damage,
		"after_route_damage": after_route_damage,
		"route_damage_delta": after_route_damage - before_route_damage,
	})


func _city_route_flow_boon(input_snapshot: Dictionary) -> Dictionary:
	var city := _dictionary(input_snapshot.get("city", {}))
	if city.is_empty():
		return _failure("city_route_flow_boon", "city_missing")
	var before_damage := int(city.get("trade_route_damage", 0))
	var repair_routes := maxi(0, int(input_snapshot.get("repair_routes", 0)))
	if repair_routes > 0:
		city["trade_route_damage"] = maxi(0, before_damage - repair_routes)
	var before_multiplier := float(city.get("route_flow_multiplier", 1.0))
	var before_seconds := _remaining_effect_seconds(city, "route_flow_seconds", "route_flow_turns")
	var requested_multiplier := clampf(float(input_snapshot.get("route_flow_multiplier", 1.0)), 1.0, ROUTE_FLOW_MULTIPLIER_MAX)
	var requested_seconds := maxf(0.0, float(input_snapshot.get("route_flow_seconds", 0.0)))
	if requested_multiplier > 1.001:
		city["route_flow_multiplier"] = maxf(before_multiplier, requested_multiplier)
		_set_remaining_effect_seconds(city, "route_flow_seconds", "route_flow_turns", maxf(before_seconds, requested_seconds))
		city["route_flow_source"] = _merge_boon_source(str(city.get("route_flow_source", "")), str(input_snapshot.get("source", "")))
	var after_damage := int(city.get("trade_route_damage", 0))
	var after_multiplier := float(city.get("route_flow_multiplier", 1.0))
	var after_seconds := _remaining_effect_seconds(city, "route_flow_seconds", "route_flow_turns")
	return _success("city_route_flow_boon", {
		"city": city,
		"changed": after_damage != before_damage or after_multiplier > before_multiplier + 0.001 or after_seconds > before_seconds,
		"before_damage": before_damage,
		"after_damage": after_damage,
		"before_multiplier": before_multiplier,
		"after_multiplier": after_multiplier,
		"before_seconds": before_seconds,
		"after_seconds": after_seconds,
	})


func _city_revenue_route_adjustment(input_snapshot: Dictionary) -> Dictionary:
	var city := _dictionary(input_snapshot.get("city", {}))
	if city.is_empty():
		return _failure("city_revenue_route_adjustment", "city_missing")
	var before_damage := int(city.get("trade_route_damage", 0))
	var before_revenue := int(city.get("revenue_bonus", 0))
	var repair_routes := maxi(0, int(input_snapshot.get("repair_routes", 0)))
	var revenue_amount := maxi(0, int(input_snapshot.get("revenue_amount", 0)))
	if repair_routes > 0:
		city["trade_route_damage"] = maxi(0, before_damage - repair_routes)
	city["revenue_bonus"] = before_revenue + revenue_amount
	return _success("city_revenue_route_adjustment", {
		"city": city,
		"changed": int(city.get("trade_route_damage", 0)) != before_damage or revenue_amount > 0,
		"before_damage": before_damage,
		"after_damage": int(city.get("trade_route_damage", 0)),
		"before_revenue": before_revenue,
		"after_revenue": int(city.get("revenue_bonus", 0)),
		"revenue_amount": revenue_amount,
	})


func _route_insurance(input_snapshot: Dictionary) -> Dictionary:
	var adjustment := _city_revenue_route_adjustment(input_snapshot)
	if not bool(adjustment.get("ok", false)):
		return _failure("route_insurance", str(adjustment.get("reason", "city_missing")))
	var flow := _city_route_flow_boon({
		"city": adjustment.get("city", {}),
		"route_flow_multiplier": input_snapshot.get("route_flow_multiplier", 1.0),
		"route_flow_seconds": input_snapshot.get("route_flow_seconds", 0.0),
		"source": input_snapshot.get("source", ""),
	})
	if not bool(flow.get("ok", false)):
		return _failure("route_insurance", str(flow.get("reason", "city_missing")))
	return _success("route_insurance", {
		"city": flow.get("city", {}),
		"changed": bool(adjustment.get("changed", false)) or bool(flow.get("changed", false)),
		"before_damage": adjustment.get("before_damage", 0),
		"after_damage": adjustment.get("after_damage", 0),
		"before_revenue": adjustment.get("before_revenue", 0),
		"after_revenue": adjustment.get("after_revenue", 0),
		"before_multiplier": flow.get("before_multiplier", 1.0),
		"after_multiplier": flow.get("after_multiplier", 1.0),
		"before_seconds": flow.get("before_seconds", 0.0),
		"after_seconds": flow.get("after_seconds", 0.0),
	})


func _city_product_upgrade(input_snapshot: Dictionary) -> Dictionary:
	var city := _dictionary(input_snapshot.get("city", {}))
	if city.is_empty():
		return _failure("city_product_upgrade", "city_missing")
	var products_variant: Variant = city.get("products", [])
	var products: Array = (products_variant as Array).duplicate(true) if products_variant is Array else []
	var product_index := _lowest_level_product_index(products)
	if product_index < 0:
		return _failure("city_product_upgrade", "products_missing")
	var product: Dictionary = products[product_index] as Dictionary
	var before_level := int(product.get("level", 1))
	var level_gain := maxi(0, int(input_snapshot.get("level_gain", 1)))
	var after_level := clampi(before_level + level_gain, 1, CITY_PRODUCT_LEVEL_MAX)
	var revenue_amount := maxi(0, int(input_snapshot.get("revenue_amount", 0)))
	if after_level != before_level:
		product["level"] = after_level
		products[product_index] = product
	city["products"] = products
	city["revenue_bonus"] = int(city.get("revenue_bonus", 0)) + revenue_amount
	return _success("city_product_upgrade", {
		"city": city,
		"changed": after_level != before_level or revenue_amount > 0,
		"product_index": product_index,
		"product_name": str(product.get("name", "未知商品")),
		"before_level": before_level,
		"after_level": after_level,
		"revenue_amount": revenue_amount,
	})


func _city_product_shift_step(input_snapshot: Dictionary) -> Dictionary:
	var products_variant: Variant = input_snapshot.get("products", [])
	var products: Array = (products_variant as Array).duplicate(true) if products_variant is Array else []
	var replace_index := _lowest_level_product_index(products)
	if replace_index < 0:
		return _failure("city_product_shift_step", "products_missing")
	var new_product := str(input_snapshot.get("new_product", ""))
	if new_product.is_empty():
		return _failure("city_product_shift_step", "replacement_missing")
	var old_product: Dictionary = products[replace_index] as Dictionary
	var old_name := str(old_product.get("name", "未知商品"))
	products[replace_index] = {"name": new_product, "level": 1}
	return _success("city_product_shift_step", {
		"products": products,
		"changed": true,
		"replace_index": replace_index,
		"old_name": old_name,
		"new_name": new_product,
	})


func _city_demand_shift_step(input_snapshot: Dictionary) -> Dictionary:
	var demands_variant: Variant = input_snapshot.get("demands", [])
	var demands: Array = (demands_variant as Array).duplicate(true) if demands_variant is Array else []
	if demands.is_empty():
		return _failure("city_demand_shift_step", "demands_missing")
	var new_demand := str(input_snapshot.get("new_demand", ""))
	if new_demand.is_empty():
		return _failure("city_demand_shift_step", "replacement_missing")
	var iteration := maxi(0, int(input_snapshot.get("iteration", 0)))
	var replace_index := iteration % demands.size()
	var old_name := str(demands[replace_index])
	demands[replace_index] = new_demand
	return _success("city_demand_shift_step", {
		"demands": demands,
		"changed": true,
		"replace_index": replace_index,
		"old_name": old_name,
		"new_name": new_demand,
	})


func _city_contract_boon(input_snapshot: Dictionary) -> Dictionary:
	var city := _dictionary(input_snapshot.get("city", {}))
	if city.is_empty():
		return _failure("city_contract_boon", "city_missing")
	var source := str(input_snapshot.get("source", ""))
	var before_contract := int(city.get("contract_income_bonus", 0))
	var before_contract_seconds := _remaining_effect_seconds(city, "contract_seconds", "contract_turns")
	var contract_income := maxi(0, int(input_snapshot.get("contract_income", 0)))
	var contract_seconds := maxf(0.0, float(input_snapshot.get("contract_seconds", 0.0)))
	if contract_income > 0:
		city["contract_income_bonus"] = maxi(before_contract, contract_income)
		_set_remaining_effect_seconds(city, "contract_seconds", "contract_turns", maxf(before_contract_seconds, contract_seconds))
		city["contract_source"] = _merge_boon_source(str(city.get("contract_source", "")), source)
	var flow := _city_route_flow_boon({
		"city": city,
		"route_flow_multiplier": input_snapshot.get("route_flow_multiplier", 1.0),
		"route_flow_seconds": input_snapshot.get("route_flow_seconds", 0.0),
		"source": source,
	})
	if not bool(flow.get("ok", false)):
		return _failure("city_contract_boon", str(flow.get("reason", "city_missing")))
	city = _dictionary(flow.get("city", {}))
	var after_contract := int(city.get("contract_income_bonus", 0))
	var after_contract_seconds := _remaining_effect_seconds(city, "contract_seconds", "contract_turns")
	return _success("city_contract_boon", {
		"city": city,
		"changed": after_contract > before_contract or after_contract_seconds > before_contract_seconds or bool(flow.get("changed", false)),
		"before_contract": before_contract,
		"after_contract": after_contract,
		"before_contract_seconds": before_contract_seconds,
		"after_contract_seconds": after_contract_seconds,
		"before_multiplier": flow.get("before_multiplier", 1.0),
		"after_multiplier": flow.get("after_multiplier", 1.0),
		"before_flow_seconds": flow.get("before_seconds", 0.0),
		"after_flow_seconds": flow.get("after_seconds", 0.0),
	})


func _product_market_boon(input_snapshot: Dictionary) -> Dictionary:
	var entry := _dictionary(input_snapshot.get("entry", {}))
	if entry.is_empty():
		return _failure("product_market_boon", "market_entry_missing")
	var growth_multiplier := float(input_snapshot.get("growth_multiplier", 1.0))
	var route_flow_multiplier := float(input_snapshot.get("route_flow_multiplier", 1.0))
	var safe_turns := maxi(0, int(input_snapshot.get("turns", 0)))
	var duration_seconds := float(input_snapshot.get("duration_seconds", -1.0))
	var safe_seconds := maxf(0.0, duration_seconds if duration_seconds >= 0.0 else float(safe_turns) * LEGACY_TURN_SECONDS)
	var source := str(input_snapshot.get("source", ""))
	var persistent := bool(input_snapshot.get("persistent", false))
	var changed := false
	if growth_multiplier > 1.0:
		var growth_value := clampf(growth_multiplier, 1.0, PRODUCT_GROWTH_MULTIPLIER_MAX)
		if persistent:
			if growth_value > float(entry.get("base_growth_multiplier", 1.0)):
				entry["base_growth_multiplier"] = growth_value
				entry["base_growth_source"] = _merge_boon_source(str(entry.get("base_growth_source", "")), source)
				changed = true
		else:
			_set_remaining_effect_seconds(entry, "growth_seconds", "growth_turns", maxf(_remaining_effect_seconds(entry, "growth_seconds", "growth_turns"), safe_seconds))
		if growth_value > float(entry.get("growth_multiplier", 1.0)) or persistent:
			entry["growth_multiplier"] = maxf(float(entry.get("growth_multiplier", 1.0)), growth_value)
			entry["growth_source"] = _merge_boon_source(str(entry.get("growth_source", "")), source)
			changed = true
	if route_flow_multiplier > 1.0:
		var flow_value := clampf(route_flow_multiplier, 1.0, ROUTE_FLOW_MULTIPLIER_MAX)
		if persistent:
			if flow_value > float(entry.get("base_route_flow_multiplier", 1.0)):
				entry["base_route_flow_multiplier"] = flow_value
				entry["base_route_flow_source"] = _merge_boon_source(str(entry.get("base_route_flow_source", "")), source)
				changed = true
		else:
			_set_remaining_effect_seconds(entry, "route_flow_seconds", "route_flow_turns", maxf(_remaining_effect_seconds(entry, "route_flow_seconds", "route_flow_turns"), safe_seconds))
		if flow_value > float(entry.get("route_flow_multiplier", 1.0)) or persistent:
			entry["route_flow_multiplier"] = maxf(float(entry.get("route_flow_multiplier", 1.0)), flow_value)
			entry["route_flow_source"] = _merge_boon_source(str(entry.get("route_flow_source", "")), source)
			changed = true
	return _success("product_market_boon", {"changed": changed, "entry": entry})


func _product_speculation_pressure(input_snapshot: Dictionary) -> Dictionary:
	var price_delta := int(input_snapshot.get("price_delta", 0))
	var pressure := maxi(1, int(ceil(abs(float(price_delta)) / 10.0)))
	return _success("product_speculation_pressure", {
		"pressure": pressure,
		"pressure_kind": "demand" if price_delta >= 0 else "supply",
		"operation": "up" if price_delta >= 0 else "down",
	})


func _product_futures_duration(input_snapshot: Dictionary) -> Dictionary:
	var skill := _dictionary(input_snapshot.get("skill", input_snapshot))
	var terms := _dictionary(skill.get("futures_terms", skill))
	var duration := float(terms.get("duration_seconds", 0.0))
	return _success("product_futures_duration", {"seconds": maxf(5.0, duration)})


func _product_futures_v04_settlement(input_snapshot: Dictionary) -> Dictionary:
	var current_price := int(input_snapshot.get("current_price", 0))
	var position := _dictionary(input_snapshot.get("position", {}))
	var baseline := int(position.get("baseline_price", current_price))
	var direction := str(position.get("direction", "up"))
	var delta := current_price - baseline
	var directional_delta := delta if direction == "up" else -delta
	var multiplier := maxf(0.1, float(position.get("multiplier", 1.0)))
	var units := maxi(1, int(position.get("units", 1)))
	var raw_pnl := int(round(float(directional_delta * PRODUCT_FUTURES_PAYOUT_UNIT * units) * multiplier))
	var locked_margin := maxi(0, int(position.get("locked_margin", 0)))
	var maximum_gain := maxi(0, int(position.get("maximum_gain", 0)))
	var maximum_loss := mini(locked_margin, maxi(0, int(position.get("maximum_loss", 0))))
	var gain := mini(maximum_gain, maxi(0, raw_pnl))
	var loss := mini(maximum_loss, maxi(0, -raw_pnl))
	var margin_refund := maxi(0, locked_margin - loss)
	return _success("product_futures_v04_settlement", {
		"baseline_price": baseline,
		"direction": direction,
		"directional_delta": directional_delta,
		"raw_pnl": raw_pnl,
		"gain": gain,
		"loss": loss,
		"locked_margin": locked_margin,
		"margin_refund": margin_refund,
		"cash_return": margin_refund + gain,
		"net_pnl": gain - loss,
	})


func _product_futures_v04_projected_settlement(input_snapshot: Dictionary) -> Dictionary:
	var skill := _dictionary(input_snapshot.get("skill", input_snapshot))
	var terms := _dictionary(skill.get("futures_terms", skill))
	var benchmark_price_delta := maxi(1, int(input_snapshot.get("benchmark_price_delta", 30)))
	var units := maxi(1, int(terms.get("units", 1)))
	var multiplier := maxf(0.1, float(terms.get("multiplier", 1.0)))
	var raw_gain := int(round(float(benchmark_price_delta * PRODUCT_FUTURES_PAYOUT_UNIT * units) * multiplier))
	var maximum_gain := maxi(0, int(terms.get("maximum_gain", 0)))
	var maximum_loss := maxi(0, int(terms.get("maximum_loss", 0)))
	return _success("product_futures_v04_projected_settlement", {
		"raw_gain": raw_gain,
		"projected_gain": mini(raw_gain, maximum_gain),
		"maximum_gain": maximum_gain,
		"maximum_loss": maximum_loss,
		"margin_cash": maxi(0, int(terms.get("margin_cash", 0))),
	})


func _warehouse_futures_v04_loss(input_snapshot: Dictionary) -> Dictionary:
	var position := _dictionary(input_snapshot.get("position", {}))
	var damage_receipt := _dictionary(input_snapshot.get("damage_receipt", {}))
	var max_hp := maxi(0, int(damage_receipt.get("max_hp", 0)))
	if max_hp <= 0:
		return _failure("warehouse_futures_v04_loss", "warehouse_max_hp_missing")
	var pre_hit_hp := clampi(int(damage_receipt.get("pre_hit_hp", max_hp)), 0, max_hp)
	var post_hit_hp := clampi(int(damage_receipt.get("post_hit_hp", 0)), 0, max_hp)
	var maximum_loss := mini(maxi(0, int(position.get("locked_margin", 0))), maxi(0, int(position.get("maximum_loss", 0))))
	var loss_ratio := clampf(1.0 - float(post_hit_hp) / float(max_hp), 0.0, 1.0)
	var loss := mini(maximum_loss, int(round(float(maximum_loss) * loss_ratio)))
	var margin_refund := maxi(0, int(position.get("locked_margin", 0)) - loss)
	return _success("warehouse_futures_v04_loss", {
		"max_hp": max_hp,
		"pre_hit_hp": pre_hit_hp,
		"post_hit_hp": post_hit_hp,
		"loss_ratio": loss_ratio,
		"loss": loss,
		"gain": 0,
		"margin_refund": margin_refund,
		"cash_return": margin_refund,
		"net_pnl": -loss,
	})


func _city_gdp_derivative_v04_settlement(input_snapshot: Dictionary) -> Dictionary:
	var current_gdp := int(input_snapshot.get("current_gdp", 0))
	var position := _dictionary(input_snapshot.get("position", {}))
	var baseline := int(position.get("baseline_gdp", current_gdp))
	var direction := str(position.get("direction", "up"))
	var delta := current_gdp - baseline
	var directional_delta := delta if direction == "up" else -delta
	var raw_pnl := int(round(float(directional_delta) * maxf(0.1, float(position.get("multiplier", 1.0)))))
	var locked_margin := maxi(0, int(position.get("locked_margin", 0)))
	var maximum_gain := maxi(0, int(position.get("maximum_gain", 0)))
	var maximum_loss := mini(locked_margin, maxi(0, int(position.get("maximum_loss", 0))))
	var gain := mini(maximum_gain, maxi(0, raw_pnl))
	var loss := mini(maximum_loss, maxi(0, -raw_pnl))
	var margin_refund := maxi(0, locked_margin - loss)
	return _success("city_gdp_derivative_v04_settlement", {
		"baseline_gdp": baseline,
		"direction": direction,
		"directional_delta": directional_delta,
		"raw_pnl": raw_pnl,
		"gain": gain,
		"loss": loss,
		"locked_margin": locked_margin,
		"margin_refund": margin_refund,
		"cash_return": margin_refund + gain,
		"net_pnl": gain - loss,
	})


func _city_gdp_derivative_v04_destruction(input_snapshot: Dictionary) -> Dictionary:
	var position := _dictionary(input_snapshot.get("position", {}))
	var direction := str(position.get("direction", "up"))
	var baseline := int(position.get("baseline_gdp", 0))
	var multiplier := maxf(0.1, float(position.get("multiplier", 1.0)))
	var locked_margin := maxi(0, int(position.get("locked_margin", 0)))
	var maximum_gain := maxi(0, int(position.get("maximum_gain", 0)))
	var maximum_loss := mini(locked_margin, maxi(0, int(position.get("maximum_loss", 0))))
	var raw_pnl := int(round(float(maxi(0, baseline)) * multiplier))
	if direction == "down":
		raw_pnl += maxi(0, int(position.get("destroy_bonus", 0)))
	else:
		raw_pnl = -raw_pnl
	var gain := mini(maximum_gain, maxi(0, raw_pnl))
	var loss := mini(maximum_loss, maxi(0, -raw_pnl))
	var margin_refund := maxi(0, locked_margin - loss)
	return _success("city_gdp_derivative_v04_destruction", {
		"baseline_gdp": baseline,
		"direction": direction,
		"raw_pnl": raw_pnl,
		"gain": gain,
		"loss": loss,
		"locked_margin": locked_margin,
		"margin_refund": margin_refund,
		"cash_return": margin_refund + gain,
		"net_pnl": gain - loss,
	})


func _city_gdp_derivative_v04_projected_settlement(input_snapshot: Dictionary) -> Dictionary:
	var skill := _dictionary(input_snapshot.get("skill", input_snapshot))
	var terms := _dictionary(skill.get("gdp_derivative_terms", skill))
	var benchmark_gdp_delta := maxi(1, int(input_snapshot.get("benchmark_gdp_delta", 100)))
	var raw_gain := int(round(float(benchmark_gdp_delta) * maxf(0.1, float(terms.get("multiplier", 1.0)))))
	return _success("city_gdp_derivative_v04_projected_settlement", {
		"raw_gain": raw_gain,
		"projected_gain": mini(raw_gain, maxi(0, int(terms.get("maximum_gain", 0)))),
		"maximum_gain": maxi(0, int(terms.get("maximum_gain", 0))),
		"maximum_loss": maxi(0, int(terms.get("maximum_loss", 0))),
		"margin_cash": maxi(0, int(terms.get("margin_cash", 0))),
		"destroy_bonus": maxi(0, int(terms.get("destroy_bonus", 0))),
	})


func _route_base_flow(input_snapshot: Dictionary) -> Dictionary:
	var source_factor := float(input_snapshot.get("source_factor", 1.0))
	var destination_factor := float(input_snapshot.get("destination_factor", 1.0))
	var relation := float(input_snapshot.get("relation", 1.0))
	var value := maxf(0.35, sqrt(source_factor * destination_factor) * clampf(0.55 + relation, 0.55, 1.55))
	return _success("route_base_flow", {"value": value})


func _route_flow_multiplier(input_snapshot: Dictionary) -> Dictionary:
	var city_multiplier := clampf(float(input_snapshot.get("city_multiplier", 1.0)), 1.0, ROUTE_FLOW_MULTIPLIER_MAX)
	var product_multiplier := clampf(float(input_snapshot.get("product_multiplier", 1.0)), 1.0, ROUTE_FLOW_MULTIPLIER_MAX)
	return _success("route_flow_multiplier", {"value": clampf(city_multiplier * product_multiplier, 1.0, ROUTE_FLOW_MULTIPLIER_MAX)})


func _merge_boon_source_result(input_snapshot: Dictionary) -> Dictionary:
	return _success("merge_boon_source", {"value": _merge_boon_source(str(input_snapshot.get("existing", "")), str(input_snapshot.get("source", "")))})


func _merge_boon_source(existing: String, source: String) -> String:
	if source == "":
		return existing
	if existing == "":
		return source
	if existing.contains(source):
		return existing
	return "%s、%s" % [existing, source]


func _remaining_effect_seconds(source: Dictionary, seconds_key: String, turns_key: String) -> float:
	if source.has(seconds_key):
		return maxf(0.0, float(source.get(seconds_key, 0.0)))
	return float(maxi(0, int(source.get(turns_key, 0)))) * LEGACY_TURN_SECONDS


func _set_remaining_effect_seconds(source: Dictionary, seconds_key: String, turns_key: String, seconds: float) -> void:
	var safe_seconds := maxf(0.0, seconds)
	source[seconds_key] = safe_seconds
	source[turns_key] = int(ceil(safe_seconds / LEGACY_TURN_SECONDS)) if safe_seconds > 0.0 else 0


func _lowest_level_product_index(products: Array) -> int:
	if products.is_empty():
		return -1
	var product_index := 0
	var first_product: Dictionary = products[0] as Dictionary
	var lowest_level := int(first_product.get("level", 1))
	for index in range(1, products.size()):
		var candidate: Dictionary = products[index] as Dictionary
		var candidate_level := int(candidate.get("level", 1))
		if candidate_level < lowest_level:
			lowest_level = candidate_level
			product_index = index
	return product_index


func _success(formula_id: String, values: Dictionary) -> Dictionary:
	var result := {"ok": true, "formula_id": formula_id, "reason": "calculated"}
	result.merge(values, true)
	return result


func _failure(formula_id: String, reason: String) -> Dictionary:
	return {"ok": false, "formula_id": formula_id, "reason": reason}


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


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
