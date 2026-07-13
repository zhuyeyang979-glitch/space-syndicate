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
	_expect(bool(debug.get("controller_ready", false)) and bool(debug.get("controller_authoritative", false)), "GDP formula controller is authoritative after configuration")
	var parameters: Dictionary = controller.call("parameters_snapshot")
	_expect(int(parameters.get("product_base_revenue", 0)) == 42 and int(parameters.get("minimum_city_gdp", 0)) == 40, "GDP formula profile preserves characterized production and floor parameters")

	var inactive: Dictionary = controller.call("calculate_city_gdp", {"active": false})
	_expect(int(inactive.get("net", -1)) == 0, "inactive city produces zero GDP")
	var composition: Dictionary = controller.call("calculate_city_gdp", {"active": true, "revenue_bonus": 30, "role_bonus": 10, "contract_income": 20})
	_expect(int(composition.get("gross", 0)) == 60 and int(composition.get("net", 0)) == 60, "bonus, role, and contract GDP compose exactly")
	var production: Dictionary = controller.call("calculate_city_gdp", {"active": true, "products": [_product(100, 1, 1.0, 1.0, 1.0)]})
	_expect(int(production.get("product", 0)) == 36 and int(production.get("net", 0)) == 40, "production formula and minimum floor preserve legacy rounding")
	var demand: Dictionary = controller.call("calculate_city_gdp", {"active": true, "routes": [_route(80, 1.0, 1.0, 1.0, 1.0)]})
	_expect(int(demand.get("route", 0)) == 27 and int(demand.get("net", 0)) == 40, "demand formula preserves legacy rounding")
	var transit: Dictionary = controller.call("calculate_city_gdp", {"active": true, "transit_routes": [_transit(100, 1.0, 1.0)]})
	_expect(int(transit.get("transit", 0)) == 23, "transit formula preserves legacy unit calculation")
	var pressure: Dictionary = controller.call("calculate_city_gdp", {"active": true, "revenue_bonus": 100, "competition_matches": 2, "disrupted_route_count": 1, "district_damage": 1})
	_expect(int(pressure.get("penalty", 0)) == 105 and int(pressure.get("net_before_floor", 0)) == -5 and int(pressure.get("net", 0)) == 40, "competition, disruption, damage, and floor semantics remain exact")
	var summary := str(controller.call("breakdown_summary", pressure))
	var reason := str(controller.call("change_reason_text", pressure))
	_expect(summary.contains("生产GDP") and summary.contains("断路") and reason.contains("驱动") and reason.contains("压力"), "GDP summary and change reason remain available through the controller")
	_expect(_is_data_only(parameters) and _is_data_only(pressure) and not bool(debug.get("legacy_formula_fallback_used", true)), "GDP controller outputs pure data and never uses a legacy formula fallback")

	controller.queue_free()
	await process_frame
	if _failures.is_empty():
		print("GDP formula runtime controller test passed.")
	else:
		for failure in _failures:
			push_error(failure)
	quit(_failures.size())


func _product(price: int, level: int, production_factor: float, ratio: float, speed: float) -> Dictionary:
	return {"product_id": "测试商品", "price": price, "level": level, "production_factor": production_factor, "supply_demand_ratio": ratio, "transport_speed": speed}


func _route(price: int, amount: float, consumption_factor: float, ratio: float, speed: float) -> Dictionary:
	return {"product_id": "测试需求", "price": price, "flow_amount": amount, "consumption_factor": consumption_factor, "supply_availability_ratio": ratio, "flow_speed": speed, "disrupted": false}


func _transit(price: int, amount: float, speed: float) -> Dictionary:
	return {"product_id": "测试过境", "price": price, "flow_amount": amount, "transport_speed": speed, "disrupted": false, "destination_is_district": false, "path_contains_district": true}


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
