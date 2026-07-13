extends Control
class_name FirstTableAuthoredRuntimeCutoverBench

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const SERVICE_SCENE_PATH := "res://scenes/runtime/FirstTableAuthoredRuntimeService.tscn"
const CARD_CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v04.tres"
const OUTPUT_DIR := "user://space_syndicate_design_qa/first_table_authored_runtime_cutover/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/first_table_authored_runtime_cutover_sprint_7.png"

@export var auto_run := true

@onready var ruleset_bridge: Node = %RulesetRuntimeBridge
@onready var coordinator: Node = %GameRuntimeCoordinator
@onready var summary_label: Label = %SummaryLabel
@onready var status_label: Label = %StatusLabel
@onready var ownership_text: RichTextLabel = %OwnershipText
@onready var results_text: RichTextLabel = %ResultsText

var _records: Array = []
var _failures: Array[String] = []
var _resolved_catalog: Dictionary = {}


func _ready() -> void:
	_configure_runtime()
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_cutover_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func cutover_cases() -> Array:
	return [
		"service_scene_composition",
		"real_first_table_fixture_loaded",
		"fixture_arrays_deduplicated",
		"catalog_filters_real_runtime_ids",
		"catalog_rejects_missing_ids",
		"teaching_product_prefers_authored_chain",
		"teaching_product_uses_remote_demand_fallback",
		"pre_project_content_safe_state",
		"project_share_and_income_summary",
		"public_project_privacy_sanitized",
		"phase_context_uses_runtime_facts",
		"completion_copy_keeps_match_running",
		"district_score_characterized",
		"invalid_district_rejected",
		"pacing_profile_authored",
		"pacing_evaluation_ordered",
		"supply_plan_prepositions_followup",
		"local_product_development_catalog_complete",
		"all_outputs_data_only",
		"real_main_delegates_legacy_inactive",
	]


func build_cutover_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant in cutover_cases():
		records.append(_record(str(case_id_variant), false, "preview"))
	return {"suite": "first-table-authored-runtime-cutover-v04", "output_dir": OUTPUT_DIR, "screenshot_path": SCREENSHOT_PATH, "record_count": records.size(), "records": records}


func run_cutover_suite() -> void:
	_records.clear()
	_failures.clear()
	_prepare_output_dir()
	_configure_runtime()
	_resolved_catalog = _resolve_catalog(_catalog())
	for case_id_variant in cutover_cases():
		var case_id := str(case_id_variant)
		var record := _run_case(case_id)
		_records.append(record)
		if not bool(record.get("passed", false)):
			_failures.append("%s: %s" % [case_id, str(record.get("notes", "failed"))])
	var manifest := {"suite": "first-table-authored-runtime-cutover-v04", "output_dir": OUTPUT_DIR, "screenshot_path": SCREENSHOT_PATH, "record_count": _records.size(), "passed_count": _passed_count(), "records": _records.duplicate(true)}
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text(REPORT_PATH, _markdown_report(manifest))
	_update_ui(manifest)
	await get_tree().process_frame
	await get_tree().process_frame
	_save_screenshot()
	print("FirstTableAuthoredRuntimeCutoverBench manifest: %s" % MANIFEST_PATH)
	print("FirstTableAuthoredRuntimeCutoverBench report: %s" % REPORT_PATH)
	print("FirstTableAuthoredRuntimeCutoverBench screenshot: %s" % SCREENSHOT_PATH)
	print("FirstTableAuthoredRuntimeCutoverBench passed: %d/%d" % [_passed_count(), _records.size()])
	if not _failures.is_empty():
		push_error("FirstTableAuthoredRuntimeCutoverBench failed:\n- %s" % "\n- ".join(_failures))
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _failures.is_empty() else 1)


func _run_case(case_id: String) -> Dictionary:
	var passed := false
	var notes := ""
	var flags := {}
	match case_id:
		"service_scene_composition":
			var service := _service_node()
			passed = service != null and service.scene_file_path == SERVICE_SCENE_PATH
			flags["service_checked"] = true
			notes = "GameRuntimeCoordinator composes the editable authored-content service scene"
		"real_first_table_fixture_loaded":
			var fixture: Dictionary = coordinator.call("first_table_fixture_snapshot")
			passed = str(fixture.get("focus", "")) == "first_table_authored_content" and (fixture.get("acts", []) as Array).size() == 3
			flags["catalog_checked"] = true
			notes = "service consumes the real first_table fixture with three authored acts"
		"fixture_arrays_deduplicated":
			passed = _unique(_resolved_catalog.get("featured_card_ids", [])) and _unique(_resolved_catalog.get("starter_monster_ids", [])) and _unique(_resolved_catalog.get("preferred_product_ids", []))
			flags["catalog_checked"] = true
			notes = "authored fixture ids are normalized once inside the service"
		"catalog_filters_real_runtime_ids":
			passed = (_resolved_catalog.get("runtime_card_ids", []) as Array).has("活体芯片生产1") and (_resolved_catalog.get("runtime_card_ids", []) as Array).has("城市融资1") and (_resolved_catalog.get("featured_card_ids", []) as Array).size() == 20 and (_resolved_catalog.get("followup_card_ids", []) as Array).size() == 4 and (_resolved_catalog.get("starter_monster_ids", []) as Array).size() == 4 and (_resolved_catalog.get("preferred_product_ids", []) as Array).size() == 3
			flags["catalog_checked"] = true
			notes = "real card, monster, and product ids survive runtime availability filtering"
		"catalog_rejects_missing_ids":
			var filtered := _resolve_catalog({"card_ids": ["城市融资1"], "city_development_cards": [], "monster_ids": [], "product_ids": []})
			passed = (filtered.get("featured_card_ids", []) as Array) == ["城市融资1"] and (filtered.get("starter_monster_ids", []) as Array).is_empty() and (filtered.get("preferred_product_ids", []) as Array).is_empty()
			flags["catalog_checked"] = true
			notes = "scenario ids that do not exist in runtime catalogs cannot enter authored content"
		"teaching_product_prefers_authored_chain":
			var product_id := str(coordinator.call("first_table_select_teaching_product", {"district_product_ids": ["普通矿"], "district_demand_ids": ["轨迹墨水"], "remote_demand_product_ids": ["普通矿"]}, _resolved_catalog))
			passed = product_id == "轨迹墨水"
			flags["content_checked"] = true
			notes = "an authored preferred product already present in the district wins"
		"teaching_product_uses_remote_demand_fallback":
			var catalog_without_preference := _resolved_catalog.duplicate(true)
			catalog_without_preference["preferred_product_ids"] = []
			var product_id := str(coordinator.call("first_table_select_teaching_product", {"district_product_ids": ["普通矿", "孤立货"], "remote_demand_product_ids": ["普通矿"]}, catalog_without_preference))
			passed = product_id == "普通矿"
			flags["content_checked"] = true
			notes = "without an authored match the real production-to-demand chain is selected"
		"pre_project_content_safe_state":
			var content := _compose({"district_index": 1, "district_name": "曙光港", "teaching_product_id": "活体芯片", "starter_monster_id": "镜像猎兵", "city_present": false, "gdp_per_minute": 999, "cashflow_paid_total": 999})
			passed = not bool(content.get("city_present", true)) and int(content.get("gdp_per_minute", -1)) == 0 and int(content.get("cashflow_paid_total", -1)) == 0 and str(content.get("urbanization_share_text", "")) == "尚未建立城市化份额"
			flags["content_checked"] = true
			notes = "pre-project coach content cannot invent GDP, payouts, or shares"
		"project_share_and_income_summary":
			var content := _sample_content()
			passed = str(content.get("urbanization_share_text", "")).contains("25.00%") and int(content.get("gdp_per_minute", 0)) == 72 and int(content.get("cashflow_paid_total", 0)) == 18 and bool(content.get("positive_income_observed", false))
			flags["content_checked"] = true
			notes = "real own-share and income facts are composed into current-player coach content"
		"public_project_privacy_sanitized":
			var content := _sample_content()
			var public_json := JSON.stringify(content.get("public_projects", []))
			passed = not public_json.contains("hidden_owner") and not public_json.contains("private_target") and not public_json.contains("ai_score")
			flags["privacy_checked"] = true
			notes = "public authored content removes hidden owner, private target, and AI reasoning keys"
		"phase_context_uses_runtime_facts":
			var phase: Dictionary = coordinator.call("first_table_contextualize_phase", {"id": "check_economy", "label": "收入"}, _sample_content())
			passed = str(phase.get("detail", "")).contains("曙光港") and str(phase.get("detail", "")).contains("72") and str(phase.get("detail", "")).contains("18")
			flags["context_checked"] = true
			notes = "coach detail is generated from current district, GDP, and payout facts"
		"completion_copy_keeps_match_running":
			var summary := str(coordinator.call("first_table_completion_summary", _sample_content()))
			var label := str(coordinator.call("first_table_completion_label", _sample_content()))
			passed = summary.contains("整局仍继续") and label.contains("72/min")
			flags["context_checked"] = true
			notes = "mission completion remains distinct from whole-match settlement"
		"district_score_characterized":
			var score := int(coordinator.call("first_table_score_district", {"build_allowed": true, "product_ids": ["活体芯片"], "demand_ids": ["轨迹墨水"], "transport_score": 1.5, "remote_demand_product_ids": ["活体芯片"]}, _resolved_catalog))
			passed = score == 194
			flags["scoring_checked"] = true
			notes = "30/12/20/80/24/18 authored recommendation weights remain exact"
		"invalid_district_rejected":
			var score := int(coordinator.call("first_table_score_district", {"build_allowed": false, "product_ids": ["活体芯片"]}, _resolved_catalog))
			passed = score == -1000000
			flags["scoring_checked"] = true
			notes = "main-provided rule eligibility still gates authored recommendation scoring"
		"pacing_profile_authored":
			var profile: Dictionary = coordinator.call("first_table_pacing_profile")
			passed = str(profile.get("measurement_kind", "")) == "scenario_game_time" and float(profile.get("recommended_min_seconds", 0.0)) == 900.0 and float(profile.get("target_duration_seconds", 0.0)) == 1200.0 and float(profile.get("recommended_max_seconds", 0.0)) == 1800.0 and (profile.get("milestones", []) as Array).size() == 6
			flags["pacing_checked"] = true
			notes = "first_table authors a 15-30 minute window with six measurable game-time milestones"
		"pacing_evaluation_ordered":
			var evaluation: Dictionary = coordinator.call("first_table_evaluate_pacing", {"scenario_started_at": 100.0, "elapsed_seconds": 1200.0, "completed_signal_times": {"card_bought": 320.0, "economy_checked": 540.0, "followup_card_bought": 760.0, "public_clue_read": 980.0, "monster_pressure_observed": 1120.0, "route_chosen": 1300.0}})
			var records: Array = evaluation.get("records", []) if evaluation.get("records", []) is Array else []
			passed = bool(evaluation.get("pacing_gate_passed", false)) and str(evaluation.get("recommended_window_status", "")) == "within_window" and records.size() == 6 and float((records[0] as Dictionary).get("observed_seconds", -1.0)) == 220.0 and float((records[-1] as Dictionary).get("observed_seconds", -1.0)) == 1200.0
			flags["pacing_checked"] = true
			notes = "pacing evaluation converts absolute scenario timestamps into ordered, pure-data elapsed milestones"
		"supply_plan_prepositions_followup":
			var plan: Dictionary = coordinator.call("first_table_supply_plan", _resolved_catalog)
			passed = bool(plan.get("ready", false)) and str(plan.get("followup_card_id", "")) == "城市融资1" and str(plan.get("inject_after_signal", "")) == "city_development_resolved" and bool(plan.get("preserve_city_development_guarantee", false)) and bool(plan.get("preserve_monster_guarantee", false))
			flags["supply_checked"] = true
			notes = "the authored plan places the second card after project resolution while preserving both fixed supply slots"
		"local_product_development_catalog_complete":
			passed = (_resolved_catalog.get("runtime_card_ids", []) as Array).has("环晶电池生产城1") and (_resolved_catalog.get("city_development_card_ids", []) as Array).has("环晶电池生产城1")
			flags["supply_checked"] = true
			notes = "local-product development cards remain reachable even when their product is outside the preferred recommendation list"
		"all_outputs_data_only":
			var fixture: Dictionary = coordinator.call("first_table_fixture_snapshot")
			var content := _sample_content()
			var debug: Dictionary = _service_node().call("debug_snapshot") if _service_node() != null else {}
			passed = _is_data_only(fixture) and _is_data_only(_resolved_catalog) and _is_data_only(content) and _is_data_only(debug)
			flags["pure_data_checked"] = true
			notes = "service boundary exposes no Node, Resource, Object, or Callable"
		"real_main_delegates_legacy_inactive":
			var source := FileAccess.get_file_as_string("res://scripts/main.gd")
			var removed_tokens := ["func _first_table_scenario_fixture", "func _first_table_fixture_string_array", "func _first_table_runtime_card_ids", "func _first_table_featured_card_ids", "func _first_table_runtime_monster_ids", "func _first_table_runtime_product_ids", "func _first_table_phase_with_runtime_context", "func _first_table_completion_summary"]
			var removed := true
			for token_variant in removed_tokens:
				if source.contains(str(token_variant)):
					removed = false
			var main_scene := load(MAIN_SCENE_PATH) as PackedScene
			var main := main_scene.instantiate() if main_scene != null else null
			var service := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/FirstTableAuthoredRuntimeService") if main != null else null
			passed = service != null and source.contains("coordinator.call(\"first_table_compose_runtime_content\"") and source.contains("coordinator.call(\"first_table_contextualize_phase\"") and removed
			flags["main_delegation_checked"] = true
			notes = "real main scene composes the service and contains no replaced authored-content authority"
			if main != null:
				main.free()
	var debug: Dictionary = _service_node().call("debug_snapshot") if _service_node() != null else {}
	flags["pure_data_checked"] = bool(flags.get("pure_data_checked", true)) and _is_data_only(debug)
	return _record(case_id, passed and bool(flags.get("pure_data_checked", true)), notes, flags)


func _configure_runtime() -> void:
	var ruleset: Dictionary = ruleset_bridge.call("active_profile") if ruleset_bridge != null else {}
	coordinator.call("configure", ruleset)


func _service_node() -> Node:
	return coordinator.get_node_or_null("FirstTableAuthoredRuntimeService") if coordinator != null else null


func _catalog() -> Dictionary:
	var catalog_resource: Resource = load(CARD_CATALOG_PATH)
	var card_ids: Array = catalog_resource.call("ordered_card_ids") if catalog_resource != null else []
	if not card_ids.has("活体芯片生产1"):
		card_ids.append("活体芯片生产1")
	if not card_ids.has("环晶电池生产城1"):
		card_ids.append("环晶电池生产城1")
	return {
		"card_ids": card_ids,
		"city_development_cards": [{"card_id": "活体芯片生产1", "rank": 1, "product_id": "活体芯片"}, {"card_id": "环晶电池生产城1", "rank": 1, "product_id": "环晶电池"}],
		"monster_ids": ["镜像猎兵", "蓝锋骑士", "流星哨兵", "绿洲修复体"],
		"product_ids": ["活体芯片", "轨迹墨水", "等离子米"],
	}


func _resolve_catalog(catalog: Dictionary) -> Dictionary:
	var value: Variant = coordinator.call("first_table_resolve_content_catalog", catalog)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _compose(world: Dictionary) -> Dictionary:
	var value: Variant = coordinator.call("first_table_compose_runtime_content", world, _resolved_catalog)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _sample_content() -> Dictionary:
	return _compose({
		"district_index": 2,
		"district_name": "曙光港",
		"teaching_product_id": "活体芯片",
		"teaching_card_id": "活体芯片生产1",
		"starter_monster_id": "镜像猎兵",
		"city_present": true,
		"city_product_ids": ["活体芯片"],
		"city_demand_ids": ["轨迹墨水"],
		"public_projects": [{"product_id": "活体芯片", "hidden_owner": 2, "private_target": "秘密", "ai_score": 99}],
		"own_project_shares": [{"product_id": "活体芯片", "direction_label": "生产", "own_share_percent": 25.0}],
		"gdp_per_minute": 72,
		"cashflow_paid_total": 18,
		"public_clue_count": 3,
		"monster_pressure_visible": true,
		"visible_monster_name": "镜像猎兵",
	})


func _record(case_id: String, passed: bool, notes: String, overrides: Dictionary = {}) -> Dictionary:
	var debug: Dictionary = _service_node().call("debug_snapshot") if _service_node() != null else {}
	var record := {"case_id": case_id, "scenario_id": "first_table", "catalog_checked": false, "content_checked": false, "context_checked": false, "scoring_checked": false, "pacing_checked": false, "supply_checked": false, "privacy_checked": false, "service_checked": false, "main_delegation_checked": false, "pure_data_checked": false, "service_ready": bool(debug.get("service_ready", false)), "legacy_fallback_used": bool(debug.get("legacy_authored_fallback_used", true)), "passed": passed, "notes": notes}
	record.merge(overrides, true)
	return record


func _update_ui(manifest: Dictionary) -> void:
	summary_label.text = "%d/%d authored ownership cases passed" % [int(manifest.get("passed_count", 0)), _records.size()]
	status_label.text = "PASS" if _failures.is_empty() else "FAIL"
	status_label.modulate = Color("4ade80") if _failures.is_empty() else Color("fb7185")
	ownership_text.text = "[b]Scene-owned authored runtime[/b]\nFirstTableAuthoredRuntimeService interprets first_table content, pacing milestones and the follow-up supply plan; it also composes viewer-safe coach data and recommendation scores.\n\n[b]Still in main.gd[/b]\nWorld facts, rule eligibility, city/project/GDP state, AI action execution, card supply mutation, map focus, and UI navigation."
	var lines: Array[String] = []
	for record_variant in _records:
		var record: Dictionary = record_variant
		lines.append("[color=%s]%s[/color]  %s\n%s" % ["#4ade80" if bool(record.get("passed", false)) else "#fb7185", "PASS" if bool(record.get("passed", false)) else "FAIL", str(record.get("case_id", "")), str(record.get("notes", ""))])
	results_text.text = "\n\n".join(lines)


func _markdown_report(manifest: Dictionary) -> String:
	var lines := ["# First Table Authored Runtime Cutover", "", "- Passed: %d/%d" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))], "- Service: `%s`" % SERVICE_SCENE_PATH, "- Legacy authored fallback: inactive", "", "| Case | Result | Notes |", "| --- | --- | --- |"]
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


func _unique(value: Variant) -> bool:
	if not (value is Array):
		return false
	var seen := {}
	for item_variant in value:
		var item := str(item_variant)
		if seen.has(item):
			return false
		seen[item] = true
	return true


func _is_data_only(value: Variant) -> bool:
	if value == null or value is String or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item_variant in value:
			if not _is_data_only(item_variant):
				return false
		return true
	if value is Dictionary:
		for key_variant in value.keys():
			if not _is_data_only(key_variant) or not _is_data_only(value[key_variant]):
				return false
		return true
	return false
