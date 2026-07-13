extends SceneTree

const CONTROLLER_SCENE := "res://scenes/runtime/GdpFormulaRuntimeController.tscn"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(CONTROLLER_SCENE) as PackedScene
	_expect(packed != null, "GDP formula controller scene loads")
	if packed == null:
		quit(1)
		return
	var controller := packed.instantiate()
	root.add_child(controller)
	controller.call("configure", {})
	var debug: Dictionary = controller.call("debug_snapshot")
	_expect(bool(debug.get("controller_ready", false)) and str(debug.get("profile_id", "")) == "gdp_formula_v05", "v0.5 GDP formula controller is authoritative")
	var parameters: Dictionary = controller.call("parameters_snapshot")
	_expect(int(parameters.get("product_base_revenue", 0)) == 42 and bool(parameters.get("zero_gdp_allowed", false)) and not parameters.has("minimum_city_gdp"), "v0.5 profile removes the legacy minimum-city floor")

	var inactive: Dictionary = controller.call("calculate_city_gdp", {"active": false, "region_id": "region.0001"})
	_expect(int(inactive.get("net", -1)) == 0 and (inactive.get("gdp_rows", []) as Array).is_empty(), "inactive city produces no GDP rows")
	var composition: Dictionary = controller.call("calculate_city_gdp", _input({"adjustments": [_adjustment("legacy_revenue_bonus", 30), _adjustment("legacy_role_bonus", 10), _adjustment("legacy_contract_income", 20)]}))
	_expect(int(composition.get("gross", 0)) == 60 and int(composition.get("net", 0)) == 60 and int(composition.get("explicit_neutral_gdp_per_minute", 0)) == 60, "unassigned legacy adjustments become explicit neutral GDP")
	var production: Dictionary = controller.call("calculate_city_gdp", _input({"production_projects": [_project("production", "星露莓", 0, 1).merged({"price": 100, "rank": 1, "production_factor": 1.0, "supply_demand_ratio": 1.0, "transport_speed": 1.0}, true)]}))
	_expect(int(production.get("product", 0)) == 36 and int(production.get("net", 0)) == 36 and (production.get("gdp_rows", []) as Array).size() == 1, "production GDP maps to its stable production project without a floor")
	var demand: Dictionary = controller.call("calculate_city_gdp", _input({"demand_projects": [_project("demand", "月壤葡萄", 0, 1).merged({"price": 80, "flow_amount": 1.0, "consumption_factor": 1.0, "supply_availability_ratio": 1.0, "flow_speed": 1.0, "route_available": true, "disrupted": false}, true)]}))
	_expect(int(demand.get("route", 0)) == 27 and str(((demand.get("gdp_rows", []) as Array)[0] as Dictionary).get("direction", "")) == "demand", "demand delivery GDP maps to its stable demand project")
	var commerce: Dictionary = controller.call("calculate_city_gdp", _input({"commerce_projects": [_project("commerce", "星露莓", 0, 1).merged({"transit_routes": [_transit(100, 1.0, 1.0)]}, true)]}))
	_expect(int(commerce.get("transit", 0)) == 23 and str(((commerce.get("gdp_rows", []) as Array)[0] as Dictionary).get("direction", "")) == "commerce", "transit GDP maps to its stable commerce project")
	var pressure: Dictionary = controller.call("calculate_city_gdp", _input({"adjustments": [_adjustment("legacy_revenue_bonus", 100)], "competition_matches": 2, "disrupted_route_count": 1, "district_damage": 1}))
	_expect(int(pressure.get("penalty", 0)) == 100 and int(pressure.get("unabsorbed_penalty", 0)) == 5 and int(pressure.get("net", -1)) == 0, "pressure can reduce region GDP to zero without recreating a floor")
	var row_validation: Dictionary = controller.call("validate_gdp_rows", pressure.get("gdp_rows", []) as Array)
	_expect(bool(row_validation.get("valid", false)) and int(row_validation.get("row_count", 0)) == 1, "GDP receipt rows conserve gross, penalty, and net")
	var summary := str(controller.call("breakdown_summary", pressure))
	var reason := str(controller.call("change_reason_text", pressure))
	_expect(summary.contains("GDP/min") and reason.contains("断路") and reason.contains("压力"), "GDP/min summary and pressure explanation remain available")
	_expect(_is_data_only(parameters) and _is_data_only(pressure) and not bool(debug.get("legacy_formula_fallback_used", true)), "GDP controller outputs pure data and never uses a legacy fallback")

	controller.queue_free()
	await process_frame
	if _failures.is_empty():
		print("GDP formula runtime controller test passed.")
	else:
		for failure in _failures:
			push_error(failure)
	quit(_failures.size())


func _input(overrides: Dictionary) -> Dictionary:
	var result := {
		"active": true,
		"destroyed": false,
		"region_id": "region.0001",
		"production_projects": [],
		"demand_projects": [],
		"commerce_projects": [],
		"adjustments": [],
	}
	result.merge(overrides, true)
	return result


func _project(direction: String, product_id: String, slot_index: int, generation: int) -> Dictionary:
	var slot_id := "region.0001.slot.%s.%d" % [direction, slot_index]
	return {
		"active": true,
		"project_id": "%s.project.g%d" % [slot_id, generation],
		"slot_id": slot_id,
		"generation": generation,
		"product_id": product_id,
		"direction": direction,
	}


func _adjustment(source_kind: String, amount: int) -> Dictionary:
	return {"source_kind": source_kind, "amount_gdp_per_minute": amount}


func _transit(price: int, amount: float, speed: float) -> Dictionary:
	return {"price": price, "flow_amount": amount, "transport_speed": speed, "disrupted": false, "destination_is_district": false, "path_contains_district": true}


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		print("FAIL: %s" % message)


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
