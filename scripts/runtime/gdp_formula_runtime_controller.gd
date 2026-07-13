@tool
extends Node
class_name GdpFormulaRuntimeController

@export var formula_profile: Resource

var _configured := false
var _parameters: Dictionary = {}
var _calculation_count := 0
var _last_net_gdp := 0
var _legacy_formula_fallback_used := false


func configure(parameter_overrides: Dictionary = {}) -> void:
	_parameters = {}
	if formula_profile != null and formula_profile.has_method("to_dictionary"):
		var profile_variant: Variant = formula_profile.call("to_dictionary")
		if profile_variant is Dictionary:
			_parameters = (profile_variant as Dictionary).duplicate(true)
	if _is_data_only(parameter_overrides):
		_parameters.merge(parameter_overrides, true)
	_configured = str(_parameters.get("profile_id", "")) == "gdp_formula_v04" and _parameters_valid(_parameters)
	_calculation_count = 0
	_last_net_gdp = 0
	_legacy_formula_fallback_used = false


func parameters_snapshot() -> Dictionary:
	return _parameters.duplicate(true)


func empty_breakdown() -> Dictionary:
	return {
		"bonus": 0,
		"role_bonus": 0,
		"contract": 0,
		"product": 0,
		"route": 0,
		"transit": 0,
		"gross": 0,
		"competition_penalty": 0,
		"route_penalty": 0,
		"damage_penalty": 0,
		"control_penalty": 0,
		"military_penalty": 0,
		"penalty": 0,
		"net_before_floor": 0,
		"net": 0,
		"product_lines": [],
		"route_lines": [],
		"transit_lines": [],
	}


func calculate_city_gdp(input_snapshot: Dictionary) -> Dictionary:
	if not _configured or not _is_data_only(input_snapshot):
		return empty_breakdown()
	if not bool(input_snapshot.get("active", false)):
		return empty_breakdown()
	var minimum_flow := maxf(0.0001, float(_parameters.get("minimum_flow_amount", 0.25)))
	var product_income := 0
	var route_income := 0
	var product_lines: Array = []
	var route_lines: Array = []
	var products_variant: Variant = input_snapshot.get("products", [])
	var products: Array = products_variant if products_variant is Array else []
	for product_variant in products:
		if not (product_variant is Dictionary):
			continue
		var product: Dictionary = product_variant
		var product_id := str(product.get("product_id", ""))
		var price := maxi(0, int(product.get("price", 0)))
		var level := maxi(1, int(product.get("level", 1)))
		var line_base := int(_parameters.get("product_base_revenue", 42)) + int(round(float(price) / float(_parameters.get("product_price_revenue_divisor", 5))))
		line_base += maxi(0, level - 1) * int(_parameters.get("product_level_revenue", 12))
		var flow_amount := maxf(minimum_flow, float(level) * maxf(0.0, float(product.get("production_factor", 1.0))) * maxf(0.0, float(product.get("supply_demand_ratio", 1.0))))
		var flow_speed := maxf(0.0, float(product.get("transport_speed", 1.0)))
		var line_income := int(round(float(line_base) * flow_amount * flow_speed * float(_parameters.get("production_gdp_scale", 0.58))))
		product_income += line_income
		product_lines.append("%s¥%d 量%.2f×速%.2f:+%d" % [product_id, price, flow_amount, flow_speed, line_income])
	var routes_variant: Variant = input_snapshot.get("routes", [])
	var routes: Array = routes_variant if routes_variant is Array else []
	for route_variant in routes:
		if not (route_variant is Dictionary):
			continue
		var route: Dictionary = route_variant
		if bool(route.get("disrupted", false)):
			continue
		var product_id := str(route.get("product_id", ""))
		var price := maxi(0, int(route.get("price", 0)))
		var line_base := int(_parameters.get("demand_supply_revenue", 28)) + int(round(float(price) / float(_parameters.get("demand_price_revenue_divisor", 8))))
		var flow_amount := maxf(minimum_flow, maxf(0.0, float(route.get("flow_amount", 1.0))) * maxf(0.0, float(route.get("consumption_factor", 1.0))) * maxf(0.0, float(route.get("supply_availability_ratio", 1.0))))
		var flow_speed := maxf(0.0, float(route.get("flow_speed", 1.0)))
		var line_income := int(round(float(line_base) * flow_amount * flow_speed * float(_parameters.get("consumption_gdp_scale", 0.72))))
		route_income += line_income
		route_lines.append("%s¥%d 量%.2f×速%.2f:+%d" % [product_id, price, flow_amount, flow_speed, line_income])
	var transit_data := calculate_transit_gdp({"routes": input_snapshot.get("transit_routes", [])})
	var revenue_bonus := int(input_snapshot.get("revenue_bonus", 0))
	var role_bonus := int(input_snapshot.get("role_bonus", 0))
	var bonus := revenue_bonus + role_bonus
	var contract_income := int(input_snapshot.get("contract_income", 0))
	var transit_income := int(transit_data.get("income", 0))
	var gross := bonus + contract_income + product_income + route_income + transit_income
	var competition_penalty := maxi(0, int(input_snapshot.get("competition_matches", 0))) * int(_parameters.get("competition_penalty", 16))
	var route_penalty := maxi(0, int(input_snapshot.get("disrupted_route_count", 0))) * int(_parameters.get("trade_disruption_penalty", 55))
	var damage_penalty := maxi(0, int(input_snapshot.get("district_damage", 0))) * int(_parameters.get("district_damage_penalty", 18))
	var control_penalty := maxi(0, int(input_snapshot.get("control_gdp_penalty", 0))) if bool(input_snapshot.get("control_pressure_active", false)) else 0
	var military_penalty := maxi(0, int(input_snapshot.get("military_gdp_penalty", 0))) if bool(input_snapshot.get("military_pressure_active", false)) else 0
	var penalties := competition_penalty + route_penalty + damage_penalty + control_penalty + military_penalty
	var net_before_floor := gross - penalties
	var result := {
		"bonus": bonus,
		"role_bonus": role_bonus,
		"contract": contract_income,
		"product": product_income,
		"route": route_income,
		"transit": transit_income,
		"gross": gross,
		"competition_penalty": competition_penalty,
		"route_penalty": route_penalty,
		"damage_penalty": damage_penalty,
		"control_penalty": control_penalty,
		"military_penalty": military_penalty,
		"penalty": penalties,
		"net_before_floor": net_before_floor,
		"net": maxi(int(_parameters.get("minimum_city_gdp", 40)), net_before_floor),
		"product_lines": product_lines,
		"route_lines": route_lines,
		"transit_lines": transit_data.get("lines", []),
	}
	_calculation_count += 1
	_last_net_gdp = int(result.get("net", 0))
	return result


func calculate_transit_gdp(input_snapshot: Dictionary) -> Dictionary:
	var total := 0
	var lines: Array = []
	if not _configured or not _is_data_only(input_snapshot):
		return {"income": total, "lines": lines}
	var minimum_flow := maxf(0.0001, float(_parameters.get("minimum_flow_amount", 0.25)))
	var routes_variant: Variant = input_snapshot.get("routes", [])
	var routes: Array = routes_variant if routes_variant is Array else []
	for route_variant in routes:
		if not (route_variant is Dictionary):
			continue
		var route: Dictionary = route_variant
		if bool(route.get("disrupted", false)) or bool(route.get("destination_is_district", false)) or not bool(route.get("path_contains_district", false)):
			continue
		var product_id := str(route.get("product_id", ""))
		var price := maxi(0, int(route.get("price", 0)))
		var flow_amount := maxf(minimum_flow, float(route.get("flow_amount", 1.0)))
		var transport_speed := maxf(0.0, float(route.get("transport_speed", 1.0)))
		var unit := int(_parameters.get("transit_gdp_base", 18)) + int(round(float(price) / float(_parameters.get("transit_price_divisor", 20))))
		var income := int(round(float(unit) * flow_amount * transport_speed))
		total += income
		lines.append("%s过境 量%.2f×速%.2f:+%d" % [product_id, flow_amount, transport_speed, income])
	return {"income": total, "lines": lines}


func breakdown_summary(breakdown: Dictionary) -> String:
	return "生产GDP%d + 消费GDP%d + 过境GDP%d + 加成%d + 合约%d - 竞争%d - 断路%d - 损伤%d - 产权%d - 军事%d = %d" % [
		int(breakdown.get("product", 0)),
		int(breakdown.get("route", 0)),
		int(breakdown.get("transit", 0)),
		int(breakdown.get("bonus", 0)),
		int(breakdown.get("contract", 0)),
		int(breakdown.get("competition_penalty", 0)),
		int(breakdown.get("route_penalty", 0)),
		int(breakdown.get("damage_penalty", 0)),
		int(breakdown.get("control_penalty", 0)),
		int(breakdown.get("military_penalty", 0)),
		int(breakdown.get("net", 0)),
	]


func change_reason_text(breakdown: Dictionary) -> String:
	var drivers: Array = []
	var pressures: Array = []
	_append_delta(drivers, "生产", int(breakdown.get("product", 0)), "+")
	_append_delta(drivers, "消费", int(breakdown.get("route", 0)), "+")
	_append_delta(drivers, "过境", int(breakdown.get("transit", 0)), "+")
	_append_delta(drivers, "加成", int(breakdown.get("bonus", 0)), "+")
	_append_delta(drivers, "合约", int(breakdown.get("contract", 0)), "+")
	_append_delta(pressures, "竞争", int(breakdown.get("competition_penalty", 0)), "-")
	_append_delta(pressures, "断路", int(breakdown.get("route_penalty", 0)), "-")
	_append_delta(pressures, "损伤", int(breakdown.get("damage_penalty", 0)), "-")
	_append_delta(pressures, "产权", int(breakdown.get("control_penalty", 0)), "-")
	_append_delta(pressures, "军事", int(breakdown.get("military_penalty", 0)), "-")
	return "驱动%s；压力%s" % [_limited_list(drivers, 4, "无主要增益"), _limited_list(pressures, 4, "无主要压力")]


func debug_snapshot() -> Dictionary:
	return {
		"controller_ready": _configured,
		"controller_authoritative": _configured,
		"profile_id": str(_parameters.get("profile_id", "")),
		"parameter_count": _parameters.size(),
		"calculation_count": _calculation_count,
		"last_net_gdp": _last_net_gdp,
		"legacy_formula_fallback_used": _legacy_formula_fallback_used,
	}


func _append_delta(target: Array, label: String, amount: int, sign_text: String) -> void:
	if amount > 0:
		target.append("%s%s%d" % [label, sign_text, amount])


func _limited_list(values: Array, limit: int, empty_text: String) -> String:
	if values.is_empty():
		return empty_text
	var pieces: Array = []
	for i in range(mini(limit, values.size())):
		pieces.append(str(values[i]))
	if values.size() > limit:
		pieces.append("+%d" % (values.size() - limit))
	return "、".join(pieces)


func _parameters_valid(parameters: Dictionary) -> bool:
	return int(parameters.get("product_price_revenue_divisor", 0)) > 0 \
		and int(parameters.get("demand_price_revenue_divisor", 0)) > 0 \
		and int(parameters.get("transit_price_divisor", 0)) > 0 \
		and float(parameters.get("production_gdp_scale", 0.0)) > 0.0 \
		and float(parameters.get("consumption_gdp_scale", 0.0)) > 0.0 \
		and float(parameters.get("minimum_flow_amount", 0.0)) > 0.0


func _is_data_only(value: Variant) -> bool:
	if value == null or value is String or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item in value:
			if not _is_data_only(item):
				return false
		return true
	if value is Dictionary:
		for key in value.keys():
			if not _is_data_only(key) or not _is_data_only(value[key]):
				return false
		return true
	return false
