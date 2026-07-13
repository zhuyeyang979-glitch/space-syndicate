extends Control
class_name GdpFormulaRuntimeCutoverBench

const PROJECT_STATE := preload("res://scripts/economy/city_product_project_state.gd")
const PROJECT_BRIDGE := preload("res://scripts/economy/city_product_project_bridge.gd")
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const CONTROLLER_SCENE_PATH := "res://scenes/runtime/GdpFormulaRuntimeController.tscn"
const CONTROLLER_SCRIPT_PATH := "res://scripts/runtime/gdp_formula_runtime_controller.gd"
const NETWORK_SCRIPT_PATH := "res://scripts/runtime/city_trade_network_runtime_controller.gd"
const PROJECT_STATE_PATH := "res://scripts/economy/city_product_project_state.gd"
const PROJECT_BRIDGE_PATH := "res://scripts/economy/city_product_project_bridge.gd"
const CASHFLOW_SCRIPT_PATH := "res://scripts/runtime/economy_cashflow_runtime_controller.gd"
const PROFILE_PATH := "res://resources/economy/space_syndicate_gdp_formula_v05.tres"
const OUTPUT_DIR := "user://space_syndicate_design_qa/gdp_formula_runtime_cutover/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/structured_project_gdp_v05_sprint_3.png"

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
		"profile_v05_identity",
		"profile_schema_version",
		"no_minimum_floor_parameter",
		"product_catalog_ready",
		"inactive_city_zero",
		"destroyed_city_zero",
		"neutral_adjustment_row",
		"production_project_row",
		"demand_project_row",
		"commerce_project_row",
		"production_baseline_exact",
		"production_rank_direction",
		"production_factor_direction",
		"production_transport_direction",
		"demand_baseline_exact",
		"demand_missing_route_zero",
		"demand_flow_direction",
		"demand_speed_direction",
		"commerce_baseline_exact",
		"commerce_destination_excluded",
		"commerce_path_excluded",
		"competition_penalty_exact",
		"route_disruption_penalty_exact",
		"damage_penalty_exact",
		"control_pressure_exact",
		"military_pressure_exact",
		"zero_gdp_no_floor",
		"unabsorbed_penalty_reported",
		"row_conservation",
		"deterministic_pressure_allocation",
		"stable_receipt_identity",
		"product_industry_mapping",
		"unknown_product_fails_closed",
		"missing_project_identity_fails_closed",
		"duplicate_receipt_rejected",
		"project_attribution_conservation",
		"share_rounding_remainder_is_neutral",
		"public_private_attribution_boundary",
		"runtime_owner_and_legacy_absence",
	]


func build_cutover_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant in cutover_cases():
		records.append(_record(str(case_id_variant), false, "preview"))
	return {"suite": "structured-project-gdp-v05", "output_dir": OUTPUT_DIR, "screenshot_path": SCREENSHOT_PATH, "record_count": records.size(), "records": records}


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
	var manifest := {"suite": "structured-project-gdp-v05", "output_dir": OUTPUT_DIR, "screenshot_path": SCREENSHOT_PATH, "record_count": _records.size(), "passed_count": _passed_count(), "records": _records.duplicate(true)}
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
	var result: Dictionary = {}
	var evidence := {}
	match case_id:
		"profile_scene_composition":
			var controller := _controller_node()
			passed = controller != null and controller.scene_file_path == CONTROLLER_SCENE_PATH and controller.get("formula_profile") is Resource and (controller.get("formula_profile") as Resource).resource_path == PROFILE_PATH
			notes = "the editable controller scene owns the v0.5 Inspector profile"
		"profile_v05_identity":
			var parameters := _parameters()
			passed = str(parameters.get("profile_id", "")) == "gdp_formula_v05" and bool(parameters.get("zero_gdp_allowed", false))
			evidence["pure_data_checked"] = _is_data_only(parameters)
			notes = "the active GDP domain profile is structured-project GDP v0.5"
		"profile_schema_version":
			passed = str(_parameters().get("schema_version", "")) == "v0.5.structured-project-gdp.1"
			notes = "row schema has an explicit v0.5 version"
		"no_minimum_floor_parameter":
			var parameters := _parameters()
			var controller_source := FileAccess.get_file_as_string(CONTROLLER_SCRIPT_PATH)
			var profile_source := FileAccess.get_file_as_string("res://scripts/economy/gdp_formula_profile_v05_resource.gd")
			passed = not parameters.has("minimum_city_gdp") and not controller_source.contains("get(\"minimum_city_gdp\"") and not profile_source.contains("minimum_city_gdp")
			notes = "the legacy 40 GDP floor is absent from profile and algorithm"
		"product_catalog_ready":
			var debug := _debug()
			passed = bool(debug.get("product_industry_catalog_ready", false))
			notes = "all project rows resolve product industry from the unique v0.5 catalog"
		"inactive_city_zero":
			result = _calculate({"active": false})
			passed = int(result.get("net", -1)) == 0 and (result.get("gdp_rows", []) as Array).is_empty()
			notes = "inactive regions emit no GDP rows"
		"destroyed_city_zero":
			result = _calculate({"destroyed": true, "production_projects": [_production_project()]})
			passed = int(result.get("net", -1)) == 0 and (result.get("gdp_rows", []) as Array).is_empty()
			notes = "destroyed regions emit no stale project GDP"
		"neutral_adjustment_row":
			result = _calculate({"adjustments": [_adjustment("legacy_revenue_bonus", 30)]})
			var rows: Array = result.get("gdp_rows", []) as Array
			passed = rows.size() == 1 and bool((rows[0] as Dictionary).get("neutral", false)) and int(result.get("explicit_neutral_gdp_per_minute", 0)) == 30
			notes = "unassigned legacy additions are explicit neutral rows"
		"production_project_row":
			result = _calculate({"production_projects": [_production_project()]})
			passed = _row_matches(result, "production", "production_output")
			notes = "production output maps to the same stable production project"
		"demand_project_row":
			result = _calculate({"demand_projects": [_demand_project()]})
			passed = _row_matches(result, "demand", "demand_delivery")
			notes = "delivery GDP maps to the same stable demand project"
		"commerce_project_row":
			result = _calculate({"commerce_projects": [_commerce_project()]})
			passed = _row_matches(result, "commerce", "commerce_transit")
			notes = "transit GDP maps to the same stable commerce project"
		"production_baseline_exact":
			result = _calculate({"production_projects": [_production_project()]})
			passed = int(result.get("product", 0)) == 36 and int(result.get("net", 0)) == 36
			notes = "production formula preserves characterized rounding without a floor"
		"production_rank_direction":
			var rank_one := _calculate({"production_projects": [_production_project()]})
			var rank_three := _production_project().merged({"rank": 3}, true)
			result = _calculate({"production_projects": [rank_three]})
			passed = int(result.get("product", 0)) > int(rank_one.get("product", 0))
			notes = "project rank increases production GDP"
		"production_factor_direction":
			var baseline := _calculate({"production_projects": [_production_project()]})
			result = _calculate({"production_projects": [_production_project().merged({"production_factor": 2.0}, true)]})
			passed = int(result.get("product", 0)) == int(baseline.get("product", 0)) * 2
			notes = "regional production factor scales the project row"
		"production_transport_direction":
			var baseline := _calculate({"production_projects": [_production_project()]})
			result = _calculate({"production_projects": [_production_project().merged({"transport_speed": 1.5}, true)]})
			passed = int(result.get("product", 0)) > int(baseline.get("product", 0))
			notes = "transport speed scales production output"
		"demand_baseline_exact":
			result = _calculate({"demand_projects": [_demand_project()]})
			passed = int(result.get("route", 0)) == 27 and int(result.get("net", 0)) == 27
			notes = "demand delivery preserves characterized rounding without a floor"
		"demand_missing_route_zero":
			result = _calculate({"demand_projects": [_demand_project().merged({"route_available": false, "disrupted": true}, true)]})
			passed = int(result.get("route", -1)) == 0 and int(result.get("net", -1)) == 0
			notes = "an unavailable route produces a zero-valued demand row"
		"demand_flow_direction":
			var baseline := _calculate({"demand_projects": [_demand_project()]})
			result = _calculate({"demand_projects": [_demand_project().merged({"flow_amount": 2.0}, true)]})
			passed = int(result.get("route", 0)) > int(baseline.get("route", 0))
			notes = "larger delivered flow raises demand GDP"
		"demand_speed_direction":
			var baseline := _calculate({"demand_projects": [_demand_project()]})
			result = _calculate({"demand_projects": [_demand_project().merged({"flow_speed": 1.5}, true)]})
			passed = int(result.get("route", 0)) > int(baseline.get("route", 0))
			notes = "faster delivery raises demand GDP"
		"commerce_baseline_exact":
			result = _calculate({"commerce_projects": [_commerce_project()]})
			passed = int(result.get("transit", 0)) == 23 and int(result.get("net", 0)) == 23
			notes = "commerce transit keeps the characterized unit formula"
		"commerce_destination_excluded":
			var route := _transit().merged({"destination_is_district": true}, true)
			result = _calculate({"commerce_projects": [_commerce_project().merged({"transit_routes": [route]}, true)]})
			passed = int(result.get("transit", -1)) == 0
			notes = "destination delivery is not double-counted as transit"
		"commerce_path_excluded":
			var route := _transit().merged({"path_contains_district": false}, true)
			result = _calculate({"commerce_projects": [_commerce_project().merged({"transit_routes": [route]}, true)]})
			passed = int(result.get("transit", -1)) == 0
			notes = "routes not crossing the region produce no transit GDP"
		"competition_penalty_exact":
			result = _calculate({"adjustments": [_adjustment("test", 100)], "competition_matches": 2})
			passed = int(result.get("competition_penalty", 0)) == 32 and int(result.get("net", 0)) == 68
			notes = "two competing production projects cost 2 x 16 GDP"
		"route_disruption_penalty_exact":
			result = _calculate({"adjustments": [_adjustment("test", 100)], "disrupted_route_count": 1})
			passed = int(result.get("route_penalty", 0)) == 55 and int(result.get("net", 0)) == 45
			notes = "one disrupted route costs 55 GDP"
		"damage_penalty_exact":
			result = _calculate({"adjustments": [_adjustment("test", 100)], "district_damage": 2})
			passed = int(result.get("damage_penalty", 0)) == 36 and int(result.get("net", 0)) == 64
			notes = "district damage costs 18 GDP per point"
		"control_pressure_exact":
			result = _calculate({"adjustments": [_adjustment("test", 100)], "control_gdp_penalty": 20, "control_pressure_active": true})
			passed = int(result.get("control_penalty", 0)) == 20 and int(result.get("net", 0)) == 80
			notes = "active control pressure applies exactly once"
		"military_pressure_exact":
			result = _calculate({"adjustments": [_adjustment("test", 100)], "military_gdp_penalty": 15, "military_pressure_active": true})
			passed = int(result.get("military_penalty", 0)) == 15 and int(result.get("net", 0)) == 85
			notes = "active military pressure applies exactly once"
		"zero_gdp_no_floor":
			result = _calculate({"adjustments": [_adjustment("test", 20)], "district_damage": 2})
			passed = int(result.get("net", -1)) == 0 and int(result.get("net_before_floor", 0)) == -16
			notes = "v0.5 permits pressure to reduce the region to zero GDP"
		"unabsorbed_penalty_reported":
			result = _calculate({"adjustments": [_adjustment("test", 20)], "district_damage": 2})
			passed = int(result.get("penalty", 0)) == 20 and int(result.get("unabsorbed_penalty", 0)) == 16
			notes = "pressure beyond gross GDP remains explicit audit evidence"
		"row_conservation":
			result = _mixed_result()
			var validation: Dictionary = _controller_node().call("validate_gdp_rows", result.get("gdp_rows", []) as Array)
			passed = bool(validation.get("valid", false)) and _row_total(result, "net_gdp_per_minute") == int(result.get("region_gdp_per_minute", -1))
			evidence["conservation_checked"] = passed
			notes = "every row conserves gross - pressure = net and rows sum to region GDP"
		"deterministic_pressure_allocation":
			var first := _mixed_result({"competition_matches": 1, "district_damage": 1})
			var second := _mixed_result({"competition_matches": 1, "district_damage": 1})
			passed = first.get("gdp_rows", []) == second.get("gdp_rows", [])
			notes = "same inputs allocate pressure by stable receipt order"
		"stable_receipt_identity":
			var first := _calculate({"production_projects": [_production_project()]})
			var second := _calculate({"production_projects": [_production_project()]})
			var first_id := str((((first.get("gdp_rows", []) as Array)[0]) as Dictionary).get("receipt_id", ""))
			var second_id := str((((second.get("gdp_rows", []) as Array)[0]) as Dictionary).get("receipt_id", ""))
			passed = first_id != "" and first_id == second_id and first_id.contains("project.g1")
			evidence["receipt_checked"] = passed
			notes = "receipt identity is deterministic and includes the stable project generation"
		"product_industry_mapping":
			result = _calculate({"production_projects": [_production_project()]})
			var row: Dictionary = (result.get("gdp_rows", []) as Array)[0]
			passed = str(row.get("product_id", "")) == "星露莓" and str(row.get("industry_id", "")) != ""
			notes = "industry is resolved from the catalog, never inferred by UI"
		"unknown_product_fails_closed":
			result = _calculate({"production_projects": [_production_project().merged({"product_id": "unknown.product"}, true)]})
			passed = not bool(result.get("valid", true)) and str(result.get("errors", [])).contains("unknown_product")
			notes = "unknown product identity fails closed"
		"missing_project_identity_fails_closed":
			result = _calculate({"production_projects": [_production_project().merged({"project_id": ""}, true)]})
			passed = not bool(result.get("valid", true)) and str(result.get("errors", [])).contains("project_identity_invalid")
			notes = "GDP cannot be emitted without stable project identity"
		"duplicate_receipt_rejected":
			result = _calculate({"production_projects": [_production_project()]})
			var rows: Array = (result.get("gdp_rows", []) as Array).duplicate(true)
			rows.append((rows[0] as Dictionary).duplicate(true))
			var validation: Dictionary = _controller_node().call("validate_gdp_rows", rows)
			passed = not bool(validation.get("valid", true)) and str(validation.get("errors", [])).contains("receipt_id_missing_or_duplicate")
			notes = "duplicate receipts are rejected before attribution"
		"project_attribution_conservation":
			result = _calculate({"production_projects": [_production_project()]})
			var attribution := PROJECT_STATE.attribute_gdp_rows([_shared_state_project()], result.get("gdp_rows", []) as Array)
			passed = bool(attribution.get("valid", false)) and int(attribution.get("player_gdp_per_minute", 0)) + int(attribution.get("neutral_gdp_per_minute", 0)) == int(attribution.get("region_gdp_per_minute", -1))
			evidence["conservation_checked"] = passed
			notes = "player-attributable GDP plus neutral GDP equals region GDP"
		"share_rounding_remainder_is_neutral":
			var project := _shared_state_project()
			var row := _state_row(project, 35)
			var attribution := PROJECT_STATE.attribute_gdp_rows([project], [row])
			passed = int(attribution.get("player_gdp_per_minute", 0)) == 34 and int(attribution.get("neutral_gdp_per_minute", 0)) == 1 and int(attribution.get("region_gdp_per_minute", 0)) == 35
			notes = "per-player floors leave the remainder neutral instead of awarding a controller"
		"public_private_attribution_boundary":
			var project := _shared_state_project()
			var city := _city_with_project(project)
			var applied := PROJECT_BRIDGE.apply_gdp_rows(city, [_state_row(project, 35)])
			var applied_city: Dictionary = applied.get("city", {}) as Dictionary
			var public_snapshot := PROJECT_BRIDGE.public_gdp_snapshot(applied_city)
			var private_snapshot := PROJECT_BRIDGE.private_gdp_snapshot(applied_city, 0)
			passed = not public_snapshot.has("player_gdp_by_index") and not str(public_snapshot).contains("player_index") and int(private_snapshot.get("own_gdp_per_minute", 0)) == 17 and (private_snapshot.get("own_attribution_rows", []) as Array).size() == 1
			evidence["privacy_checked"] = passed
			notes = "public GDP hides player attribution while viewer-private GDP exposes only self"
		"runtime_owner_and_legacy_absence":
			var main_scene := load(MAIN_SCENE_PATH) as PackedScene
			var main := main_scene.instantiate() if main_scene != null else null
			var main_controller := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GdpFormulaRuntimeController") if main != null else null
			var combined_source := FileAccess.get_file_as_string("res://scripts/main.gd") + FileAccess.get_file_as_string(NETWORK_SCRIPT_PATH) + FileAccess.get_file_as_string(PROJECT_STATE_PATH) + FileAccess.get_file_as_string(PROJECT_BRIDGE_PATH) + FileAccess.get_file_as_string(CASHFLOW_SCRIPT_PATH)
			var forbidden := ["assign_city_gdp", "gdp_by_player", "player_gdp(", "project_gdp_by_player", "project_cashflow_remainder_by_player", "minimum_city_gdp", "\"source_kind\": \"city_owner\""]
			passed = main_controller != null and main_controller.scene_file_path == CONTROLLER_SCENE_PATH
			for token_variant in forbidden:
				passed = passed and not combined_source.contains(str(token_variant))
			evidence["main_delegation_checked"] = passed
			notes = "the scene-owned controller is unique and legacy floor, whole-city split, owner payout, and remainder maps are absent"
			if main != null:
				main.free()
	if not result.is_empty():
		evidence["region_id"] = str(result.get("region_id", ""))
		evidence["row_count"] = (result.get("gdp_rows", []) as Array).size()
		evidence["region_gdp_per_minute"] = int(result.get("region_gdp_per_minute", 0))
		evidence["pure_data_checked"] = _is_data_only(result)
		passed = passed and bool(evidence["pure_data_checked"])
	return _record(case_id, passed, notes, evidence)


func _configure_runtime() -> void:
	var ruleset: Dictionary = ruleset_bridge.call("active_profile") if ruleset_bridge != null else {}
	coordinator.call("configure", ruleset)


func _controller_node() -> Node:
	return coordinator.get_node_or_null("GdpFormulaRuntimeController") if coordinator != null else null


func _parameters() -> Dictionary:
	return coordinator.call("gdp_formula_parameters") as Dictionary


func _debug() -> Dictionary:
	return _controller_node().call("debug_snapshot") as Dictionary if _controller_node() != null else {}


func _calculate(overrides: Dictionary) -> Dictionary:
	var snapshot := {"active": true, "destroyed": false, "region_id": "region.0001", "production_projects": [], "demand_projects": [], "commerce_projects": [], "adjustments": []}
	snapshot.merge(overrides, true)
	var value: Variant = coordinator.call("calculate_city_gdp", snapshot)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _project(direction: String, product_id: String, slot_index: int = 0, generation: int = 1) -> Dictionary:
	var slot_id := "region.0001.slot.%s.%d" % [direction, slot_index]
	return {"active": true, "project_id": "%s.project.g%d" % [slot_id, generation], "slot_id": slot_id, "generation": generation, "product_id": product_id, "direction": direction}


func _production_project() -> Dictionary:
	return _project("production", "星露莓").merged({"price": 100, "rank": 1, "production_factor": 1.0, "supply_demand_ratio": 1.0, "transport_speed": 1.0}, true)


func _demand_project() -> Dictionary:
	return _project("demand", "月壤葡萄").merged({"price": 80, "flow_amount": 1.0, "consumption_factor": 1.0, "supply_availability_ratio": 1.0, "flow_speed": 1.0, "route_available": true, "disrupted": false}, true)


func _commerce_project() -> Dictionary:
	return _project("commerce", "星露莓").merged({"transit_routes": [_transit()]}, true)


func _transit() -> Dictionary:
	return {"price": 100, "flow_amount": 1.0, "transport_speed": 1.0, "disrupted": false, "destination_is_district": false, "path_contains_district": true}


func _adjustment(source_kind: String, amount: int) -> Dictionary:
	return {"source_kind": source_kind, "amount_gdp_per_minute": amount}


func _mixed_result(overrides: Dictionary = {}) -> Dictionary:
	var input := {"production_projects": [_production_project()], "demand_projects": [_demand_project()], "commerce_projects": [_commerce_project()], "adjustments": [_adjustment("authored_neutral", 11)]}
	input.merge(overrides, true)
	return _calculate(input)


func _row_matches(result: Dictionary, direction: String, source_kind: String) -> bool:
	var rows: Array = result.get("gdp_rows", []) as Array
	if rows.size() != 1:
		return false
	var row: Dictionary = rows[0]
	return str(row.get("direction", "")) == direction and str(row.get("source_kind", "")) == source_kind and str(row.get("project_id", "")) != "" and str(row.get("slot_id", "")) != "" and int(row.get("project_generation", 0)) == 1


func _row_total(result: Dictionary, key: String) -> int:
	var total := 0
	for row_variant in result.get("gdp_rows", []):
		if row_variant is Dictionary:
			total += int((row_variant as Dictionary).get(key, 0))
	return total


func _shared_state_project() -> Dictionary:
	var project := PROJECT_STATE.create_project(1, "星露莓", "production", 0, 1, 1)
	return PROJECT_STATE.contribute(project, 1, 1, 2)


func _state_row(project: Dictionary, amount: int) -> Dictionary:
	return {"receipt_id": "gdp.region.0001.project.share-test", "region_id": str(project.get("region_id", "")), "project_id": str(project.get("project_id", "")), "project_generation": int(project.get("generation", 0)), "slot_id": str(project.get("slot_id", "")), "product_id": str(project.get("product_id", "")), "industry_id": "life", "direction": str(project.get("direction", "")), "source_kind": "production_output", "gross_gdp_per_minute": amount, "penalty_gdp_per_minute": 0, "net_gdp_per_minute": amount, "neutral": false, "visibility_scope": "public"}


func _city_with_project(project: Dictionary) -> Dictionary:
	var city := PROJECT_BRIDGE.normalize_city({"active": true}, 1)
	var slots: Array = (city.get("project_slots", []) as Array).duplicate(true)
	for index in range(slots.size()):
		var slot: Dictionary = (slots[index] as Dictionary).duplicate(true)
		if str(slot.get("slot_id", "")) == str(project.get("slot_id", "")):
			slot["generation"] = int(project.get("generation", 1))
			slot["active_project"] = project.duplicate(true)
			slots[index] = slot
			break
	city["project_slots"] = slots
	city["projects"] = PROJECT_BRIDGE.active_projects(city)
	return city


func _record(case_id: String, passed: bool, notes: String, overrides: Dictionary = {}) -> Dictionary:
	var debug := _debug()
	var record := {"case_id": case_id, "region_id": "", "row_count": 0, "region_gdp_per_minute": 0, "project_gdp_per_minute": 0, "player_gdp_per_minute": 0, "neutral_gdp_per_minute": 0, "conservation_checked": false, "receipt_checked": false, "privacy_checked": false, "main_delegation_checked": false, "pure_data_checked": false, "controller_ready": bool(debug.get("controller_ready", false)), "legacy_fallback_used": bool(debug.get("legacy_formula_fallback_used", true)), "passed": passed, "notes": notes}
	record.merge(overrides, true)
	return record


func _update_ui(manifest: Dictionary) -> void:
	summary_label.text = "%d/%d structured project GDP cases passed" % [int(manifest.get("passed_count", 0)), _records.size()]
	status_label.text = "PASS" if _failures.is_empty() else "FAIL"
	status_label.modulate = Color("4ade80") if _failures.is_empty() else Color("fb7185")
	var parameters := _parameters()
	parameter_text.text = "[b]Structured project GDP v0.5[/b]\nProduction  %d + price/%d + rank×%d, scale %.2f\nDemand      %d + price/%d, scale %.2f\nTransit     %d + price/%d\nPressure    competition %d / route %d / damage %d\nFloor       none; zero GDP is valid\n\n[b]Ownership[/b]\nFormula controller emits public project-keyed receipt rows.\nProject state floors each private share and records the remainder as neutral.\nCashflow consumes receipt+player attribution IDs." % [int(parameters.get("product_base_revenue", 0)), int(parameters.get("product_price_revenue_divisor", 1)), int(parameters.get("product_rank_revenue", 0)), float(parameters.get("production_gdp_scale", 0.0)), int(parameters.get("demand_supply_revenue", 0)), int(parameters.get("demand_price_revenue_divisor", 1)), float(parameters.get("consumption_gdp_scale", 0.0)), int(parameters.get("transit_gdp_base", 0)), int(parameters.get("transit_price_divisor", 1)), int(parameters.get("competition_penalty", 0)), int(parameters.get("trade_disruption_penalty", 0)), int(parameters.get("district_damage_penalty", 0))]
	var lines: Array[String] = []
	for record_variant in _records:
		var record: Dictionary = record_variant
		lines.append("[color=%s]%s[/color]  %s\n%s" % ["#4ade80" if bool(record.get("passed", false)) else "#fb7185", "PASS" if bool(record.get("passed", false)) else "FAIL", str(record.get("case_id", "")), str(record.get("notes", ""))])
	results_text.text = "\n\n".join(lines)


func _markdown_report(manifest: Dictionary) -> String:
	var lines := ["# Structured Project GDP v0.5", "", "- Passed: %d/%d" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))], "- Controller: `%s`" % CONTROLLER_SCENE_PATH, "- Profile: `%s`" % PROFILE_PATH, "- Legacy formula fallback: absent", "", "| Case | Result | Notes |", "| --- | --- | --- |"]
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
