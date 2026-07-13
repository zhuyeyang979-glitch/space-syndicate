@tool
extends Node
class_name GdpFormulaRuntimeController

const VALID_DIRECTIONS := ["production", "demand", "commerce"]
const PUBLIC_VISIBILITY := "public"

@export var formula_profile: Resource
@export var product_industry_catalog: Resource

var _configured := false
var _parameters: Dictionary = {}
var _calculation_count := 0
var _last_region_gdp := 0
var _last_row_count := 0
var _last_errors: Array = []
var _legacy_formula_fallback_used := false


func configure(parameter_overrides: Dictionary = {}) -> void:
	_parameters = {}
	if formula_profile != null and formula_profile.has_method("to_dictionary"):
		var profile_variant: Variant = formula_profile.call("to_dictionary")
		if profile_variant is Dictionary:
			_parameters = (profile_variant as Dictionary).duplicate(true)
	if _is_data_only(parameter_overrides):
		_parameters.merge(parameter_overrides, true)
	_configured = str(_parameters.get("profile_id", "")) == "gdp_formula_v05" \
		and _parameters_valid(_parameters) \
		and _catalog_valid()
	_calculation_count = 0
	_last_region_gdp = 0
	_last_row_count = 0
	_last_errors = []
	_legacy_formula_fallback_used = false


func parameters_snapshot() -> Dictionary:
	return _parameters.duplicate(true)


func empty_breakdown(errors: Array = []) -> Dictionary:
	return {
		"valid": errors.is_empty(),
		"errors": errors.duplicate(true),
		"schema_version": str(_parameters.get("schema_version", "v0.5.structured-project-gdp.1")),
		"region_id": "",
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
		"unabsorbed_penalty": 0,
		"net_before_floor": 0,
		"net": 0,
		"region_gdp_per_minute": 0,
		"explicit_neutral_gdp_per_minute": 0,
		"gdp_rows": [],
		"product_lines": [],
		"route_lines": [],
		"transit_lines": [],
	}


func calculate_city_gdp(input_snapshot: Dictionary) -> Dictionary:
	if not _configured or not _is_data_only(input_snapshot):
		return _finish_result(empty_breakdown(["controller_not_ready_or_input_not_pure"]))
	if not bool(input_snapshot.get("active", false)) or bool(input_snapshot.get("destroyed", false)):
		var inactive := empty_breakdown()
		inactive["region_id"] = str(input_snapshot.get("region_id", ""))
		return _finish_result(inactive)
	var region_id := str(input_snapshot.get("region_id", "")).strip_edges().to_lower()
	if region_id.is_empty():
		return _finish_result(empty_breakdown(["region_id_missing"]))
	var rows: Array = []
	var errors: Array = []
	_append_production_rows(rows, errors, region_id, input_snapshot.get("production_projects", []))
	_append_demand_rows(rows, errors, region_id, input_snapshot.get("demand_projects", []))
	_append_commerce_rows(rows, errors, region_id, input_snapshot.get("commerce_projects", []))
	_append_adjustment_rows(rows, errors, region_id, input_snapshot.get("adjustments", []))
	if not errors.is_empty():
		var invalid := empty_breakdown(errors)
		invalid["region_id"] = region_id
		return _finish_result(invalid)
	rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("receipt_id", "")) < str(right.get("receipt_id", ""))
	)
	var competition_penalty := maxi(0, int(input_snapshot.get("competition_matches", 0))) * int(_parameters.get("competition_penalty", 0))
	var route_penalty := maxi(0, int(input_snapshot.get("disrupted_route_count", 0))) * int(_parameters.get("trade_disruption_penalty", 0))
	var damage_penalty := maxi(0, int(input_snapshot.get("district_damage", 0))) * int(_parameters.get("district_damage_penalty", 0))
	var control_penalty := maxi(0, int(input_snapshot.get("control_gdp_penalty", 0))) if bool(input_snapshot.get("control_pressure_active", false)) else 0
	var military_penalty := maxi(0, int(input_snapshot.get("military_gdp_penalty", 0))) if bool(input_snapshot.get("military_pressure_active", false)) else 0
	var requested_penalty := competition_penalty + route_penalty + damage_penalty + control_penalty + military_penalty
	var gross := _row_total(rows, "gross_gdp_per_minute")
	var applied_penalty := mini(gross, requested_penalty)
	rows = _apply_pressure(rows, applied_penalty)
	var product_income := _gross_for_direction(rows, "production")
	var route_income := _gross_for_direction(rows, "demand")
	var transit_income := _gross_for_direction(rows, "commerce")
	var bonus := _gross_for_adjustment(rows, false)
	var contract_income := _gross_for_adjustment(rows, true)
	var role_bonus := _gross_for_source(rows, "legacy_role_bonus")
	var net := _row_total(rows, "net_gdp_per_minute")
	var result := empty_breakdown()
	result.merge({
		"valid": true,
		"region_id": region_id,
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
		"penalty": applied_penalty,
		"unabsorbed_penalty": maxi(0, requested_penalty - applied_penalty),
		"net_before_floor": gross - requested_penalty,
		"net": net,
		"region_gdp_per_minute": net,
		"explicit_neutral_gdp_per_minute": _neutral_row_total(rows),
		"gdp_rows": rows,
		"product_lines": _display_lines(rows, "production"),
		"route_lines": _display_lines(rows, "demand"),
		"transit_lines": _display_lines(rows, "commerce"),
	}, true)
	return _finish_result(result)


func calculate_transit_gdp(input_snapshot: Dictionary) -> Dictionary:
	var total := 0
	var lines: Array = []
	if not _configured or not _is_data_only(input_snapshot):
		return {"income": total, "lines": lines}
	for route_variant in _array(input_snapshot.get("routes", [])):
		if not (route_variant is Dictionary):
			continue
		var route: Dictionary = route_variant
		if bool(route.get("disrupted", false)) or bool(route.get("destination_is_district", false)) or not bool(route.get("path_contains_district", false)):
			continue
		var income := _transit_income(route)
		total += income
		lines.append("%s过境:+%d" % [str(route.get("product_id", "")), income])
	return {"income": total, "lines": lines}


func validate_gdp_rows(rows: Array) -> Dictionary:
	var errors: Array = []
	var seen := {}
	for row_variant in rows:
		if not (row_variant is Dictionary):
			errors.append("row_not_dictionary")
			continue
		var row: Dictionary = row_variant
		var receipt_id := str(row.get("receipt_id", ""))
		if receipt_id.is_empty() or seen.has(receipt_id):
			errors.append("receipt_id_missing_or_duplicate")
		seen[receipt_id] = true
		if not VALID_DIRECTIONS.has(str(row.get("direction", ""))) and not bool(row.get("neutral", false)):
			errors.append("direction_invalid:%s" % receipt_id)
		if int(row.get("gross_gdp_per_minute", -1)) < 0 or int(row.get("penalty_gdp_per_minute", -1)) < 0 or int(row.get("net_gdp_per_minute", -1)) < 0:
			errors.append("negative_amount:%s" % receipt_id)
		if int(row.get("gross_gdp_per_minute", 0)) - int(row.get("penalty_gdp_per_minute", 0)) != int(row.get("net_gdp_per_minute", 0)):
			errors.append("row_conservation_failed:%s" % receipt_id)
		var product_id := str(row.get("product_id", ""))
		if product_id != "" and str(row.get("industry_id", "")) != _industry_for_product(product_id):
			errors.append("industry_mismatch:%s" % receipt_id)
	return {"valid": errors.is_empty(), "errors": errors, "row_count": rows.size()}


func breakdown_summary(breakdown: Dictionary) -> String:
	return "生产GDP%d + 需求GDP%d + 通商GDP%d + 调整%d + 合约%d - 压力%d = %d GDP/min" % [
		int(breakdown.get("product", 0)), int(breakdown.get("route", 0)), int(breakdown.get("transit", 0)),
		int(breakdown.get("bonus", 0)), int(breakdown.get("contract", 0)), int(breakdown.get("penalty", 0)), int(breakdown.get("net", 0)),
	]


func change_reason_text(breakdown: Dictionary) -> String:
	var drivers: Array = []
	var pressures: Array = []
	_append_delta(drivers, "生产", int(breakdown.get("product", 0)), "+")
	_append_delta(drivers, "需求", int(breakdown.get("route", 0)), "+")
	_append_delta(drivers, "通商", int(breakdown.get("transit", 0)), "+")
	_append_delta(drivers, "调整", int(breakdown.get("bonus", 0)), "+")
	_append_delta(drivers, "合约", int(breakdown.get("contract", 0)), "+")
	_append_delta(pressures, "竞争", int(breakdown.get("competition_penalty", 0)), "-")
	_append_delta(pressures, "断路", int(breakdown.get("route_penalty", 0)), "-")
	_append_delta(pressures, "损伤", int(breakdown.get("damage_penalty", 0)), "-")
	_append_delta(pressures, "控制", int(breakdown.get("control_penalty", 0)), "-")
	_append_delta(pressures, "军事", int(breakdown.get("military_penalty", 0)), "-")
	return "驱动%s；压力%s" % [_limited_list(drivers, 4, "无主要增益"), _limited_list(pressures, 4, "无主要压力")]


func debug_snapshot() -> Dictionary:
	return {
		"controller_ready": _configured,
		"controller_authoritative": _configured,
		"profile_id": str(_parameters.get("profile_id", "")),
		"schema_version": str(_parameters.get("schema_version", "")),
		"product_industry_catalog_ready": _catalog_valid(),
		"parameter_count": _parameters.size(),
		"calculation_count": _calculation_count,
		"last_region_gdp": _last_region_gdp,
		"last_row_count": _last_row_count,
		"last_errors": _last_errors.duplicate(true),
		"zero_gdp_allowed": bool(_parameters.get("zero_gdp_allowed", false)),
		"legacy_formula_fallback_used": _legacy_formula_fallback_used,
	}


func _append_production_rows(rows: Array, errors: Array, region_id: String, value: Variant) -> void:
	var ordinal := 0
	for project_variant in _array(value):
		if not (project_variant is Dictionary):
			continue
		var project: Dictionary = project_variant
		if not bool(project.get("active", true)):
			continue
		var validation := _project_fact_validation(project, "production")
		if validation != "":
			errors.append(validation)
			continue
		var rank := clampi(int(project.get("rank", 1)), 1, 4)
		var price := maxi(0, int(project.get("price", 0)))
		var base := int(_parameters.get("product_base_revenue", 0)) + int(round(float(price) / float(_parameters.get("product_price_revenue_divisor", 1))))
		base += maxi(0, rank - 1) * int(_parameters.get("product_rank_revenue", 0))
		var flow := maxf(float(_parameters.get("minimum_flow_amount", 0.25)), float(rank) * maxf(0.0, float(project.get("production_factor", 1.0))) * maxf(0.0, float(project.get("supply_demand_ratio", 1.0))))
		var speed := maxf(0.0, float(project.get("transport_speed", 1.0)))
		var gross := maxi(0, int(round(float(base) * flow * speed * float(_parameters.get("production_gdp_scale", 0.0)))))
		rows.append(_project_row(region_id, project, "production_output", ordinal, gross))
		ordinal += 1


func _append_demand_rows(rows: Array, errors: Array, region_id: String, value: Variant) -> void:
	var ordinal := 0
	for project_variant in _array(value):
		if not (project_variant is Dictionary):
			continue
		var project: Dictionary = project_variant
		if not bool(project.get("active", true)):
			continue
		var validation := _project_fact_validation(project, "demand")
		if validation != "":
			errors.append(validation)
			continue
		var gross := 0
		if not bool(project.get("disrupted", false)) and bool(project.get("route_available", true)):
			var price := maxi(0, int(project.get("price", 0)))
			var base := int(_parameters.get("demand_supply_revenue", 0)) + int(round(float(price) / float(_parameters.get("demand_price_revenue_divisor", 1))))
			var flow := maxf(float(_parameters.get("minimum_flow_amount", 0.25)), maxf(0.0, float(project.get("flow_amount", 1.0))) * maxf(0.0, float(project.get("consumption_factor", 1.0))) * maxf(0.0, float(project.get("supply_availability_ratio", 1.0))))
			gross = maxi(0, int(round(float(base) * flow * maxf(0.0, float(project.get("flow_speed", 1.0))) * float(_parameters.get("consumption_gdp_scale", 0.0)))))
		rows.append(_project_row(region_id, project, "demand_delivery", ordinal, gross))
		ordinal += 1


func _append_commerce_rows(rows: Array, errors: Array, region_id: String, value: Variant) -> void:
	var ordinal := 0
	for project_variant in _array(value):
		if not (project_variant is Dictionary):
			continue
		var project: Dictionary = project_variant
		if not bool(project.get("active", true)):
			continue
		var validation := _project_fact_validation(project, "commerce")
		if validation != "":
			errors.append(validation)
			continue
		var gross := 0
		for route_variant in _array(project.get("transit_routes", [])):
			if route_variant is Dictionary:
				gross += _transit_income(route_variant as Dictionary)
		rows.append(_project_row(region_id, project, "commerce_transit", ordinal, gross))
		ordinal += 1


func _append_adjustment_rows(rows: Array, errors: Array, region_id: String, value: Variant) -> void:
	var ordinal := 0
	for adjustment_variant in _array(value):
		if not (adjustment_variant is Dictionary):
			continue
		var adjustment: Dictionary = adjustment_variant
		var amount := maxi(0, int(adjustment.get("amount_gdp_per_minute", 0)))
		if amount <= 0:
			continue
		var project_id := str(adjustment.get("project_id", ""))
		var source_kind := _safe_id_piece(str(adjustment.get("source_kind", "adjustment")))
		var direction := str(adjustment.get("direction", ""))
		var product_id := str(adjustment.get("product_id", ""))
		if project_id != "" and not VALID_DIRECTIONS.has(direction):
			errors.append("adjustment_direction_invalid:%s" % project_id)
			continue
		if product_id != "" and _industry_for_product(product_id) == "":
			errors.append("unknown_product:%s" % product_id)
			continue
		var neutral := project_id.is_empty()
		var receipt_id := "gdp.%s.%s.%s.%d" % [region_id, "neutral" if neutral else project_id, source_kind, ordinal]
		rows.append({
			"receipt_id": receipt_id,
			"region_id": region_id,
			"project_id": project_id,
			"project_generation": int(adjustment.get("project_generation", 0)),
			"slot_id": str(adjustment.get("slot_id", "")),
			"product_id": product_id,
			"industry_id": _industry_for_product(product_id) if product_id != "" else "",
			"direction": direction,
			"source_kind": source_kind,
			"gross_gdp_per_minute": amount,
			"penalty_gdp_per_minute": 0,
			"net_gdp_per_minute": amount,
			"neutral": neutral,
			"visibility_scope": PUBLIC_VISIBILITY,
		})
		ordinal += 1


func _project_row(region_id: String, project: Dictionary, source_kind: String, ordinal: int, gross: int) -> Dictionary:
	var project_id := str(project.get("project_id", ""))
	var product_id := str(project.get("product_id", ""))
	return {
		"receipt_id": "gdp.%s.%s.%s.%d" % [region_id, project_id, source_kind, ordinal],
		"region_id": region_id,
		"project_id": project_id,
		"project_generation": int(project.get("generation", 0)),
		"slot_id": str(project.get("slot_id", "")),
		"product_id": product_id,
		"industry_id": _industry_for_product(product_id),
		"direction": str(project.get("direction", "")),
		"source_kind": source_kind,
		"gross_gdp_per_minute": maxi(0, gross),
		"penalty_gdp_per_minute": 0,
		"net_gdp_per_minute": maxi(0, gross),
		"neutral": false,
		"visibility_scope": PUBLIC_VISIBILITY,
	}


func _project_fact_validation(project: Dictionary, expected_direction: String) -> String:
	var project_id := str(project.get("project_id", ""))
	if project_id.is_empty() or str(project.get("slot_id", "")).is_empty() or int(project.get("generation", 0)) <= 0:
		return "project_identity_invalid:%s" % project_id
	if str(project.get("direction", "")) != expected_direction:
		return "project_direction_invalid:%s" % project_id
	var product_id := str(project.get("product_id", ""))
	if product_id.is_empty() or _industry_for_product(product_id).is_empty():
		return "unknown_product:%s" % product_id
	return ""


func _transit_income(route: Dictionary) -> int:
	if bool(route.get("disrupted", false)) or bool(route.get("destination_is_district", false)) or not bool(route.get("path_contains_district", false)):
		return 0
	var price := maxi(0, int(route.get("price", 0)))
	var flow := maxf(float(_parameters.get("minimum_flow_amount", 0.25)), float(route.get("flow_amount", 1.0)))
	var speed := maxf(0.0, float(route.get("transport_speed", 1.0)))
	var unit := int(_parameters.get("transit_gdp_base", 0)) + int(round(float(price) / float(_parameters.get("transit_price_divisor", 1))))
	return maxi(0, int(round(float(unit) * flow * speed)))


func _apply_pressure(row_values: Array, total_penalty: int) -> Array:
	var rows := row_values.duplicate(true)
	var gross_total := _row_total(rows, "gross_gdp_per_minute")
	if total_penalty <= 0 or gross_total <= 0:
		return rows
	var assigned := 0
	var remainders: Array = []
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		var gross := maxi(0, int(row.get("gross_gdp_per_minute", 0)))
		var numerator := gross * total_penalty
		var base := floori(float(numerator) / float(gross_total))
		row["penalty_gdp_per_minute"] = base
		row["net_gdp_per_minute"] = gross - base
		rows[index] = row
		assigned += base
		remainders.append({"index": index, "remainder": numerator % gross_total, "receipt_id": str(row.get("receipt_id", ""))})
	remainders.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_value := int(left.get("remainder", 0))
		var right_value := int(right.get("remainder", 0))
		if left_value != right_value:
			return left_value > right_value
		return str(left.get("receipt_id", "")) < str(right.get("receipt_id", ""))
	)
	for offset in range(maxi(0, total_penalty - assigned)):
		if remainders.is_empty():
			break
		var index := int((remainders[offset % remainders.size()] as Dictionary).get("index", -1))
		if index < 0 or index >= rows.size():
			continue
		var row: Dictionary = rows[index]
		if int(row.get("net_gdp_per_minute", 0)) <= 0:
			continue
		row["penalty_gdp_per_minute"] = int(row.get("penalty_gdp_per_minute", 0)) + 1
		row["net_gdp_per_minute"] = int(row.get("net_gdp_per_minute", 0)) - 1
		rows[index] = row
	return rows


func _finish_result(result: Dictionary) -> Dictionary:
	_calculation_count += 1
	_last_region_gdp = int(result.get("region_gdp_per_minute", result.get("net", 0)))
	_last_row_count = _array(result.get("gdp_rows", [])).size()
	_last_errors = _array(result.get("errors", [])).duplicate(true)
	return result


func _industry_for_product(product_id: String) -> String:
	if product_industry_catalog == null or not product_industry_catalog.has_method("industry_for_product"):
		return ""
	return str(product_industry_catalog.call("industry_for_product", product_id))


func _catalog_valid() -> bool:
	if product_industry_catalog == null or not product_industry_catalog.has_method("validation_snapshot"):
		return false
	var validation: Variant = product_industry_catalog.call("validation_snapshot", [])
	return validation is Dictionary and bool((validation as Dictionary).get("valid", false))


func _parameters_valid(parameters: Dictionary) -> bool:
	return not parameters.has("minimum_city_gdp") \
		and bool(parameters.get("zero_gdp_allowed", false)) \
		and str(parameters.get("pressure_allocation_mode", "")) == "proportional_gross_receipt_id" \
		and int(parameters.get("product_price_revenue_divisor", 0)) > 0 \
		and int(parameters.get("demand_price_revenue_divisor", 0)) > 0 \
		and int(parameters.get("transit_price_divisor", 0)) > 0 \
		and float(parameters.get("production_gdp_scale", 0.0)) > 0.0 \
		and float(parameters.get("consumption_gdp_scale", 0.0)) > 0.0 \
		and float(parameters.get("minimum_flow_amount", 0.0)) > 0.0


func _row_total(rows: Array, key: String) -> int:
	var total := 0
	for row_variant in rows:
		if row_variant is Dictionary:
			total += maxi(0, int((row_variant as Dictionary).get(key, 0)))
	return total


func _gross_for_direction(rows: Array, direction: String) -> int:
	var total := 0
	for row_variant in rows:
		if row_variant is Dictionary and str((row_variant as Dictionary).get("direction", "")) == direction and not bool((row_variant as Dictionary).get("neutral", false)):
			total += maxi(0, int((row_variant as Dictionary).get("gross_gdp_per_minute", 0)))
	return total


func _gross_for_adjustment(rows: Array, contract_only: bool) -> int:
	var total := 0
	for row_variant in rows:
		if not (row_variant is Dictionary):
			continue
		var row: Dictionary = row_variant
		var source_kind := str(row.get("source_kind", ""))
		var is_contract := source_kind.contains("contract")
		if is_contract == contract_only and not ["production_output", "demand_delivery", "commerce_transit"].has(source_kind):
			total += maxi(0, int(row.get("gross_gdp_per_minute", 0)))
	return total


func _gross_for_source(rows: Array, source_kind: String) -> int:
	var total := 0
	for row_variant in rows:
		if row_variant is Dictionary and str((row_variant as Dictionary).get("source_kind", "")) == source_kind:
			total += maxi(0, int((row_variant as Dictionary).get("gross_gdp_per_minute", 0)))
	return total


func _neutral_row_total(rows: Array) -> int:
	var total := 0
	for row_variant in rows:
		if row_variant is Dictionary and bool((row_variant as Dictionary).get("neutral", false)):
			total += maxi(0, int((row_variant as Dictionary).get("net_gdp_per_minute", 0)))
	return total


func _display_lines(rows: Array, direction: String) -> Array:
	var result: Array = []
	for row_variant in rows:
		if not (row_variant is Dictionary):
			continue
		var row: Dictionary = row_variant
		if str(row.get("direction", "")) == direction and not bool(row.get("neutral", false)):
			result.append("%s｜%s｜GDP/min %d" % [str(row.get("product_id", "")), str(row.get("slot_id", "")), int(row.get("net_gdp_per_minute", 0))])
	return result


func _append_delta(target: Array, label: String, amount: int, sign_text: String) -> void:
	if amount > 0:
		target.append("%s%s%d" % [label, sign_text, amount])


func _limited_list(values: Array, limit: int, empty_text: String) -> String:
	if values.is_empty():
		return empty_text
	var pieces: Array = []
	for index in range(mini(limit, values.size())):
		pieces.append(str(values[index]))
	if values.size() > limit:
		pieces.append("+%d" % (values.size() - limit))
	return "、".join(pieces)


func _safe_id_piece(value: String) -> String:
	var result := ""
	for index in range(value.length()):
		var code := value.unicode_at(index)
		var character := value.substr(index, 1).to_lower()
		if (code >= 48 and code <= 57) or (code >= 97 and code <= 122) or character in ["_", "-"]:
			result += character
		else:
			result += "_"
	return result.strip_edges().trim_prefix("_").trim_suffix("_") if result != "" else "adjustment"


func _array(value: Variant) -> Array:
	return value as Array if value is Array else []


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
