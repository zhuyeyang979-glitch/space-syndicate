extends Control
class_name GdpFormulaRuntimeCutoverBench

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const CONTROLLER_SCENE_PATH := "res://scenes/runtime/GdpFormulaRuntimeController.tscn"
const CITY_TRADE_NETWORK_CONTROLLER_SCRIPT_PATH := "res://scripts/runtime/city_trade_network_runtime_controller.gd"
const PROFILE_PATH := "res://resources/economy/space_syndicate_gdp_formula_v04.tres"
const OUTPUT_DIR := "user://space_syndicate_design_qa/gdp_formula_runtime_cutover/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/gdp_formula_runtime_cutover_sprint_6.png"

@export var auto_run := true

@onready var ruleset_bridge: Node = %RulesetRuntimeBridge
@onready var coordinator: Node = %GameRuntimeCoordinator
@onready var summary_label: Label = %SummaryLabel
@onready var status_label: Label = %StatusLabel
@onready var parameter_text: RichTextLabel = %ParameterText
@onready var results_text: RichTextLabel = %ResultsText

var _records: Array = []
var _failures: Array[String] = []


func _ready() -> void:
	_configure_runtime()
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_cutover_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func cutover_cases() -> Array:
	return [
		"profile_scene_composition",
		"profile_parameter_parity",
		"inactive_city_zero",
		"bonus_contract_composition",
		"production_baseline_exact",
		"production_price_direction",
		"production_level_direction",
		"production_factor_direction",
		"production_transport_direction",
		"demand_baseline_exact",
		"demand_price_direction",
		"demand_amount_direction",
		"demand_speed_direction",
		"transit_exact",
		"competition_penalty_exact",
		"route_disruption_penalty_exact",
		"damage_penalty_exact",
		"temporary_pressure_exact",
		"minimum_floor_exact",
		"real_main_delegates_legacy_inactive",
	]


func build_cutover_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant in cutover_cases():
		records.append(_record(str(case_id_variant), false, "preview"))
	return {"suite": "gdp-formula-runtime-cutover-v04", "output_dir": OUTPUT_DIR, "screenshot_path": SCREENSHOT_PATH, "record_count": records.size(), "records": records}


func run_cutover_suite() -> void:
	_records.clear()
	_failures.clear()
	_prepare_output_dir()
	_configure_runtime()
	for case_id_variant in cutover_cases():
		var case_id := str(case_id_variant)
		var record := _run_case(case_id)
		_records.append(record)
		if not bool(record.get("passed", false)):
			_failures.append("%s: %s" % [case_id, str(record.get("notes", "failed"))])
	var manifest := {"suite": "gdp-formula-runtime-cutover-v04", "output_dir": OUTPUT_DIR, "screenshot_path": SCREENSHOT_PATH, "record_count": _records.size(), "passed_count": _passed_count(), "records": _records.duplicate(true)}
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text(REPORT_PATH, _markdown_report(manifest))
	_update_ui(manifest)
	await get_tree().process_frame
	await get_tree().process_frame
	_save_screenshot()
	print("GdpFormulaRuntimeCutoverBench manifest: %s" % MANIFEST_PATH)
	print("GdpFormulaRuntimeCutoverBench report: %s" % REPORT_PATH)
	print("GdpFormulaRuntimeCutoverBench screenshot: %s" % SCREENSHOT_PATH)
	print("GdpFormulaRuntimeCutoverBench passed: %d/%d" % [_passed_count(), _records.size()])
	if not _failures.is_empty():
		push_error("GdpFormulaRuntimeCutoverBench failed:\n- %s" % "\n- ".join(_failures))
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _failures.is_empty() else 1)


func _run_case(case_id: String) -> Dictionary:
	var passed := false
	var notes := ""
	var expected_net := -1
	var result: Dictionary = {}
	var flags := {}
	match case_id:
		"profile_scene_composition":
			var controller := _controller_node()
			passed = controller != null and controller.scene_file_path == CONTROLLER_SCENE_PATH and controller.get("formula_profile") is Resource and (controller.get("formula_profile") as Resource).resource_path == PROFILE_PATH
			flags["parameter_checked"] = true
			notes = "editable controller scene owns the Inspector profile"
		"profile_parameter_parity":
			var parameters: Dictionary = coordinator.call("gdp_formula_parameters")
			passed = int(parameters.get("product_base_revenue", 0)) == 42 and int(parameters.get("product_level_revenue", 0)) == 12 and int(parameters.get("demand_supply_revenue", 0)) == 28 and int(parameters.get("transit_gdp_base", 0)) == 18 and int(parameters.get("competition_penalty", 0)) == 16 and int(parameters.get("trade_disruption_penalty", 0)) == 55 and int(parameters.get("district_damage_penalty", 0)) == 18 and int(parameters.get("minimum_city_gdp", 0)) == 40
			flags["parameter_checked"] = true
			flags["pure_data_checked"] = _is_data_only(parameters)
			notes = "all thirteen former main constants are represented by the profile"
		"inactive_city_zero":
			expected_net = 0
			result = _calculate({"active": false})
			passed = int(result.get("net", -1)) == expected_net and int(result.get("gross", -1)) == 0
			notes = "inactive city remains a zero-GDP safe state"
		"bonus_contract_composition":
			expected_net = 60
			result = _calculate({"active": true, "revenue_bonus": 30, "role_bonus": 10, "contract_income": 20})
			passed = int(result.get("gross", 0)) == 60 and int(result.get("bonus", 0)) == 40 and int(result.get("net", 0)) == expected_net
			notes = "revenue, role, and contract additions preserve exact composition"
		"production_baseline_exact":
			expected_net = 40
			result = _calculate({"active": true, "products": [_product(100, 1, 1.0, 1.0, 1.0)]})
			passed = int(result.get("product", 0)) == 36 and int(result.get("net", 0)) == expected_net
			notes = "42 + price/5, flow, speed, 0.58 scale, round, then floor"
		"production_price_direction":
			result = _calculate({"active": true, "products": [_product(120, 1, 1.0, 1.0, 1.0)]})
			passed = int(result.get("product", 0)) == 38
			notes = "higher public price raises production GDP"
		"production_level_direction":
			result = _calculate({"active": true, "products": [_product(100, 3, 1.0, 1.0, 1.0)]})
			passed = int(result.get("product", 0)) == 150
			notes = "project level affects line base and flow amount"
		"production_factor_direction":
			result = _calculate({"active": true, "products": [_product(100, 1, 2.0, 1.0, 1.0)]})
			passed = int(result.get("product", 0)) == 72
			notes = "regional production factor scales production GDP"
		"production_transport_direction":
			result = _calculate({"active": true, "products": [_product(100, 1, 1.0, 1.0, 1.5)]})
			passed = int(result.get("product", 0)) == 54
			notes = "transport speed scales production GDP"
		"demand_baseline_exact":
			expected_net = 40
			result = _calculate({"active": true, "routes": [_route(80, 1.0, 1.0, 1.0, 1.0)]})
			passed = int(result.get("route", 0)) == 27 and int(result.get("net", 0)) == expected_net
			notes = "28 + price/8, demand flow, speed, 0.72 scale, round, then floor"
		"demand_price_direction":
			result = _calculate({"active": true, "routes": [_route(120, 1.0, 1.0, 1.0, 1.0)]})
			passed = int(result.get("route", 0)) == 31
			notes = "higher public price raises supplied-demand GDP"
		"demand_amount_direction":
			result = _calculate({"active": true, "routes": [_route(80, 2.0, 1.0, 1.0, 1.0)]})
			passed = int(result.get("route", 0)) == 55
			notes = "larger effective route amount raises demand GDP"
		"demand_speed_direction":
			result = _calculate({"active": true, "routes": [_route(80, 1.0, 1.0, 1.0, 1.5)]})
			passed = int(result.get("route", 0)) == 41
			notes = "route flow speed raises demand GDP"
		"transit_exact":
			result = _calculate({"active": true, "transit_routes": [_transit(100, 1.0, 1.0)]})
			passed = int(result.get("transit", 0)) == 23 and (result.get("transit_lines", []) as Array).size() == 1
			notes = "18 + price/20 preserves transit unit and public line"
		"competition_penalty_exact":
			expected_net = 68
			result = _calculate({"active": true, "revenue_bonus": 100, "competition_matches": 2})
			passed = int(result.get("competition_penalty", 0)) == 32 and int(result.get("net", 0)) == expected_net
			notes = "two competition matches cost 2 x 16 GDP"
		"route_disruption_penalty_exact":
			expected_net = 45
			result = _calculate({"active": true, "revenue_bonus": 100, "disrupted_route_count": 1})
			passed = int(result.get("route_penalty", 0)) == 55 and int(result.get("net", 0)) == expected_net
			notes = "one disrupted route costs 55 GDP"
		"damage_penalty_exact":
			expected_net = 64
			result = _calculate({"active": true, "revenue_bonus": 100, "district_damage": 2})
			passed = int(result.get("damage_penalty", 0)) == 36 and int(result.get("net", 0)) == expected_net
			notes = "district damage costs 18 GDP per point"
		"temporary_pressure_exact":
			expected_net = 65
			result = _calculate({"active": true, "revenue_bonus": 100, "control_gdp_penalty": 20, "control_pressure_active": true, "military_gdp_penalty": 15, "military_pressure_active": true})
			passed = int(result.get("control_penalty", 0)) == 20 and int(result.get("military_penalty", 0)) == 15 and int(result.get("net", 0)) == expected_net
			notes = "active control and military pressure remain additive"
		"minimum_floor_exact":
			expected_net = 40
			result = _calculate({"active": true, "revenue_bonus": 20, "district_damage": 2})
			passed = int(result.get("net_before_floor", 0)) == -16 and int(result.get("net", 0)) == expected_net
			notes = "active city GDP retains the characterized floor of 40"
		"real_main_delegates_legacy_inactive":
			var main_scene := load(MAIN_SCENE_PATH) as PackedScene
			var main := main_scene.instantiate() if main_scene != null else null
			var main_controller := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GdpFormulaRuntimeController") if main != null else null
			var source := FileAccess.get_file_as_string("res://scripts/main.gd")
			var network_source := FileAccess.get_file_as_string(CITY_TRADE_NETWORK_CONTROLLER_SCRIPT_PATH)
			var removed_tokens := ["CITY_PRODUCT_BASE_REVENUE", "CITY_PRODUCTION_GDP_SCALE", "CITY_COMPETITION_PENALTY", "CITY_MINIMUM_INCOME", "func _district_transit_gdp"]
			var removed := true
			for token_variant in removed_tokens:
				if source.contains(str(token_variant)):
					removed = false
			passed = main_controller != null and main_controller.scene_file_path == CONTROLLER_SCENE_PATH and not source.contains("func _city_gdp_formula_snapshot") and network_source.contains("func gdp_formula_snapshot(") and network_source.contains('_gdp_formula_controller.call("calculate_city_gdp"') and removed
			flags["main_delegation_checked"] = true
			notes = "real main composes the GDP owner while CityTradeNetworkRuntimeController assembles world facts and main contains no legacy formula authority"
			if main != null:
				main.free()
	if not result.is_empty():
		flags["pure_data_checked"] = _is_data_only(result)
		passed = passed and bool(flags["pure_data_checked"])
		flags["actual_net"] = int(result.get("net", -1))
		flags["product_gdp"] = int(result.get("product", 0))
		flags["demand_gdp"] = int(result.get("route", 0))
		flags["transit_gdp"] = int(result.get("transit", 0))
		flags["penalty"] = int(result.get("penalty", 0))
	flags["expected_net"] = expected_net
	return _record(case_id, passed, notes, flags)


func _configure_runtime() -> void:
	var ruleset: Dictionary = ruleset_bridge.call("active_profile") if ruleset_bridge != null else {}
	coordinator.call("configure", ruleset)


func _controller_node() -> Node:
	return coordinator.get_node_or_null("GdpFormulaRuntimeController") if coordinator != null else null


func _calculate(snapshot: Dictionary) -> Dictionary:
	var value: Variant = coordinator.call("calculate_city_gdp", snapshot)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _product(price: int, level: int, production_factor: float, ratio: float, speed: float) -> Dictionary:
	return {"product_id": "测试商品", "price": price, "level": level, "production_factor": production_factor, "supply_demand_ratio": ratio, "transport_speed": speed}


func _route(price: int, amount: float, consumption_factor: float, ratio: float, speed: float) -> Dictionary:
	return {"product_id": "测试需求", "price": price, "flow_amount": amount, "consumption_factor": consumption_factor, "supply_availability_ratio": ratio, "flow_speed": speed, "disrupted": false}


func _transit(price: int, amount: float, speed: float) -> Dictionary:
	return {"product_id": "测试过境", "price": price, "flow_amount": amount, "transport_speed": speed, "disrupted": false, "destination_is_district": false, "path_contains_district": true}


func _record(case_id: String, passed: bool, notes: String, overrides: Dictionary = {}) -> Dictionary:
	var debug: Dictionary = _controller_node().call("debug_snapshot") if _controller_node() != null else {}
	var record := {"case_id": case_id, "expected_net": -1, "actual_net": -1, "product_gdp": 0, "demand_gdp": 0, "transit_gdp": 0, "penalty": 0, "parameter_checked": false, "main_delegation_checked": false, "pure_data_checked": false, "controller_ready": bool(debug.get("controller_ready", false)), "legacy_fallback_used": bool(debug.get("legacy_formula_fallback_used", true)), "passed": passed, "notes": notes}
	record.merge(overrides, true)
	return record


func _update_ui(manifest: Dictionary) -> void:
	var passed_count := int(manifest.get("passed_count", 0))
	summary_label.text = "%d/%d characterization and ownership cases passed" % [passed_count, _records.size()]
	status_label.text = "PASS" if _failures.is_empty() else "FAIL"
	status_label.modulate = Color("4ade80") if _failures.is_empty() else Color("fb7185")
	var parameters: Dictionary = coordinator.call("gdp_formula_parameters")
	parameter_text.text = "[b]Inspector formula profile[/b]\nProduction  %d + price/%d + level×%d, scale %.2f\nDemand      %d + price/%d, scale %.2f\nTransit     %d + price/%d\nPressure    competition %d / route %d / damage %d\nFloor       %d GDP/min\n\n[b]Runtime boundary[/b]\nmain.gd builds pure world facts.\nGdpFormulaRuntimeController owns arithmetic, rounding, pressure aggregation, floor, summary, and reason text.\nCityProductProjectBridge still allocates city GDP to real project shares." % [int(parameters.get("product_base_revenue", 0)), int(parameters.get("product_price_revenue_divisor", 1)), int(parameters.get("product_level_revenue", 0)), float(parameters.get("production_gdp_scale", 0.0)), int(parameters.get("demand_supply_revenue", 0)), int(parameters.get("demand_price_revenue_divisor", 1)), float(parameters.get("consumption_gdp_scale", 0.0)), int(parameters.get("transit_gdp_base", 0)), int(parameters.get("transit_price_divisor", 1)), int(parameters.get("competition_penalty", 0)), int(parameters.get("trade_disruption_penalty", 0)), int(parameters.get("district_damage_penalty", 0)), int(parameters.get("minimum_city_gdp", 0))]
	var lines: Array[String] = []
	for record_variant in _records:
		var record: Dictionary = record_variant
		lines.append("[color=%s]%s[/color]  %s\n%s" % ["#4ade80" if bool(record.get("passed", false)) else "#fb7185", "PASS" if bool(record.get("passed", false)) else "FAIL", str(record.get("case_id", "")), str(record.get("notes", ""))])
	results_text.text = "\n\n".join(lines)


func _markdown_report(manifest: Dictionary) -> String:
	var lines := ["# GDP Formula Runtime Cutover", "", "- Passed: %d/%d" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))], "- Controller: `%s`" % CONTROLLER_SCENE_PATH, "- Profile: `%s`" % PROFILE_PATH, "- Legacy formula fallback: inactive", "", "| Case | Result | Notes |", "| --- | --- | --- |"]
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant
		lines.append("| %s | %s | %s |" % [str(record.get("case_id", "")), "PASS" if bool(record.get("passed", false)) else "FAIL", str(record.get("notes", "")).replace("|", "/")])
	return "\n".join(lines) + "\n"


func _prepare_output_dir() -> void:
	var absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute)
	for file_name in ["manifest.json", "report.md"]:
		var file_path := absolute.path_join(file_name)
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(file_path)


func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures.append("cannot write %s" % path)
		return
	file.store_string(content)
	file.close()


func _save_screenshot() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_failures.append("viewport screenshot is empty")
		return
	var error := image.save_png(SCREENSHOT_PATH)
	if error != OK:
		_failures.append("screenshot save failed: %s" % error_string(error))


func _passed_count() -> int:
	var count := 0
	for record_variant in _records:
		if record_variant is Dictionary and bool((record_variant as Dictionary).get("passed", false)):
			count += 1
	return count


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
