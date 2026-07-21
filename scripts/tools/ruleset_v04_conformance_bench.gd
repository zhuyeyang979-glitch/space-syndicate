extends Control
class_name RulesetV04ConformanceBench

const OUTPUT_DIR := "user://space_syndicate_design_qa/ruleset_v04_conformance/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/ruleset_v04_source_of_truth_sprint_1.png"
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const RegistryScript := preload("res://scripts/tools/ruleset_v04_conformance_registry.gd")

const FLOW_CASES := [
	{"case_id": "profile_loads", "notes": "The Inspector-editable v0.4 profile loads and validates."},
	{"case_id": "bridge_loads", "notes": "The scene-owned runtime bridge exposes a valid profile snapshot."},
	{"case_id": "main_composition_owns_bridge", "notes": "main.tscn owns RulesetRuntimeBridge under RuntimeServices."},
	{"case_id": "shared_window_30_25_5", "notes": "Shared window timing is 30 seconds with 25 organize and 5 lock."},
	{"case_id": "card_group_limits_3_4", "notes": "Default card group is 0-3 with an explicit maximum of 4."},
	{"case_id": "final_countdown_75", "notes": "Final countdown is 75 seconds."},
	{"case_id": "monster_wager_15", "notes": "Monster wager uses one 15-second mandatory decision window."},
	{"case_id": "realtime_income_enabled", "notes": "Realtime income remains enabled."},
	{"case_id": "direct_city_build_disabled", "notes": "The v0.4 capability profile disallows direct city building."},
	{"case_id": "city_development_controller_ready", "notes": "The runtime controller binds v0.4 capabilities and owns city-entry legality."},
	{"case_id": "direct_city_build_runtime_cutover", "notes": "Legacy direct requests are rejected while a fully bound card project is accepted."},
	{"case_id": "conformance_registry_tracks_legacy", "notes": "Known legacy blocks are explicit mismatch or missing records."},
	{"case_id": "decision_priority_v04", "notes": "Forced-decision priority matches v0.4."},
	{"case_id": "pure_data_outputs", "notes": "Bridge, registry, and manifest output contain no runtime objects."},
]

@export var auto_run := true
@export var auto_quit_after_suite := false

@onready var bridge: Node = %RulesetRuntimeBridge
@onready var city_development_controller: Node = %CityDevelopmentRuntimeController
@onready var status_label: Label = %StatusLabel
@onready var summary_label: Label = %SummaryLabel
@onready var rule_summary_text: RichTextLabel = %RuleSummaryText

var _registry: RefCounted = RegistryScript.new()
var _suite_running := false


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_flow_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func screenshot_path() -> String:
	return SCREENSHOT_PATH


func flow_cases() -> Array:
	return FLOW_CASES.duplicate(true)


func build_flow_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_variant in flow_cases():
		var flow_case: Dictionary = case_variant
		records.append(_record(str(flow_case.get("case_id", "")), false, "Preview manifest only."))
	return {
		"suite": "ruleset_v04_conformance",
		"ruleset_id": "v0.4",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"record_count": records.size(),
		"records": records,
	}


func run_flow_suite() -> void:
	if _suite_running:
		return
	_suite_running = true
	_configure_city_development_controller()
	_prepare_output_dir()
	_set_status("Running v0.4 source-of-truth checks...")
	var records: Array = []
	for case_variant in flow_cases():
		var flow_case: Dictionary = case_variant
		var case_id := str(flow_case.get("case_id", ""))
		var passed := _run_case(case_id)
		var notes := str(flow_case.get("notes", ""))
		records.append(_record(case_id, passed, notes if passed else "FAILED: %s" % notes))
	var manifest := {
		"suite": "ruleset_v04_conformance",
		"ruleset_id": "v0.4",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"record_count": records.size(),
		"passed_count": _passed_count(records),
		"records": records,
		"conformance": _registry.call("summary"),
	}
	_write_text_file(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text_file(REPORT_PATH, _build_report(manifest))
	await _settle_frames(2)
	_write_screenshot()
	var all_passed := _passed_count(records) == records.size()
	print("RulesetV04ConformanceBench manifest: %s" % MANIFEST_PATH)
	print("RulesetV04ConformanceBench report: %s" % REPORT_PATH)
	print("RulesetV04ConformanceBench screenshot: %s" % SCREENSHOT_PATH)
	print("RulesetV04ConformanceBench passed: %d/%d" % [_passed_count(records), records.size()])
	_set_status("Ruleset v0.4 conformance: %d/%d | %s" % [_passed_count(records), records.size(), MANIFEST_PATH])
	if not all_passed:
		push_error("RulesetV04ConformanceBench failed. See %s" % MANIFEST_PATH)
	_suite_running = false
	if auto_quit_after_suite:
		await get_tree().create_timer(0.25).timeout
		get_tree().quit(0 if all_passed else 1)


func _run_case(case_id: String) -> bool:
	var snapshot := _bridge_snapshot()
	var timing: Dictionary = snapshot.get("timing", {}) if snapshot.get("timing", {}) is Dictionary else {}
	var group: Dictionary = snapshot.get("card_group", {}) if snapshot.get("card_group", {}) is Dictionary else {}
	var capabilities: Dictionary = snapshot.get("capabilities", {}) if snapshot.get("capabilities", {}) is Dictionary else {}
	match case_id:
		"profile_loads":
			return str(snapshot.get("ruleset_id", "")) == "v0.4" and bool((snapshot.get("validation", {}) as Dictionary).get("valid", false))
		"bridge_loads":
			return bridge != null and bridge.has_method("active_profile") and bool(snapshot.get("bridge_ready", false))
		"main_composition_owns_bridge":
			return _main_scene_has_bridge()
		"shared_window_30_25_5":
			return _near(timing.get("shared_window_seconds", 0.0), 30.0) and _near(timing.get("organize_seconds", 0.0), 25.0) and _near(timing.get("lock_seconds", 0.0), 5.0)
		"card_group_limits_3_4":
			return int(group.get("default_group_card_limit", 0)) == 3 and int(group.get("maximum_group_card_limit", 0)) == 4
		"final_countdown_75":
			return _near(timing.get("final_countdown_seconds", 0.0), 75.0)
		"monster_wager_15":
			return _near(timing.get("monster_wager_default_seconds", 0.0), 15.0) and _near(timing.get("monster_wager_max_seconds", 0.0), 15.0)
		"realtime_income_enabled":
			return bool(capabilities.get("realtime_income_enabled", false))
		"direct_city_build_disabled":
			return not bool(capabilities.get("direct_city_build_allowed", true)) and bool(capabilities.get("city_development_requires_product_project", false))
		"city_development_controller_ready":
			_configure_city_development_controller()
			var controller_snapshot := _city_development_snapshot()
			return bool(controller_snapshot.get("controller_ready", false)) and bool(controller_snapshot.get("controller_authoritative", false)) and not bool(controller_snapshot.get("direct_build_allowed", true))
		"direct_city_build_runtime_cutover":
			return _city_development_runtime_cutover_is_active()
		"conformance_registry_tracks_legacy":
			return _legacy_registry_is_explicit()
		"decision_priority_v04":
			return snapshot.get("forced_decision_priority", []) == ["monster_wager", "counter_response", "contract_response", "other_choice"]
		"pure_data_outputs":
			return _is_pure_data(snapshot) and _is_pure_data(_registry.call("summary")) and _is_pure_data(build_flow_manifest_preview())
	return false


func _bridge_snapshot() -> Dictionary:
	if bridge == null or not bridge.has_method("debug_snapshot"):
		return {}
	var snapshot_variant: Variant = bridge.call("debug_snapshot")
	return snapshot_variant if snapshot_variant is Dictionary else {}


func _main_scene_has_bridge() -> bool:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		return false
	var main := packed.instantiate()
	if main == null:
		return false
	var found := main.get_node_or_null("RuntimeServices/RulesetRuntimeBridge")
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	var region_infrastructure := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/RegionInfrastructureRuntimeController")
	var valid := (
		found != null
		and found.has_method("debug_snapshot")
		and coordinator is GameRuntimeCoordinator
		and region_infrastructure is RegionInfrastructureRuntimeController
	)
	main.free()
	return valid


func _configure_city_development_controller() -> void:
	if city_development_controller != null and city_development_controller.has_method("configure"):
		city_development_controller.call("configure", _bridge_snapshot())


func _city_development_snapshot() -> Dictionary:
	if city_development_controller == null or not city_development_controller.has_method("debug_snapshot"):
		return {}
	var snapshot_variant: Variant = city_development_controller.call("debug_snapshot")
	return snapshot_variant if snapshot_variant is Dictionary else {}


func _city_development_runtime_cutover_is_active() -> bool:
	_configure_city_development_controller()
	if city_development_controller == null or not city_development_controller.has_method("evaluate_development_request"):
		return false
	var legacy: Dictionary = city_development_controller.call("evaluate_development_request", {
		"source_kind": "direct_city_build",
		"action_id": "build_city",
		"district_index": 1,
	})
	var legal: Dictionary = city_development_controller.call("evaluate_development_request", {
		"source_kind": "city_development_card",
		"action_id": "play_city_development_card",
		"district_index": 1,
		"product_id": "活体芯片",
		"project_direction": "production",
		"project_id": "1:活体芯片:production",
	})
	return not bool(legacy.get("allowed", true)) and str(legacy.get("disabled_reason", "")).contains("不能直接建城") and bool(legal.get("allowed", false))


func _legacy_registry_is_explicit() -> bool:
	var expected := {
		"realtime_cashflow": "cutover_complete",
		"city_development_product_binding": "cutover_complete",
		"direct_city_build_legacy": "cutover_complete",
		"district_purchase_12_second_window": "cutover_complete",
		"forced_decision_scheduler": "cutover_complete",
		"private_plan_slot": "missing",
		"end_turn_legacy_surface": "mismatch",
	}
	for rule_id in expected.keys():
		var record: Dictionary = _registry.call("record_for_id", str(rule_id))
		if str(record.get("current_status", "")) != str(expected[rule_id]):
			return false
	return true


func _record(case_id: String, passed: bool, notes: String) -> Dictionary:
	return {
		"case_id": case_id,
		"ruleset_id": "v0.4",
		"profile_checked": true,
		"runtime_checked": case_id in ["bridge_loads", "main_composition_owns_bridge", "shared_window_30_25_5", "final_countdown_75", "monster_wager_15", "city_development_controller_ready", "direct_city_build_runtime_cutover"],
		"registry_checked": case_id == "conformance_registry_tracks_legacy",
		"pure_data_checked": case_id == "pure_data_outputs",
		"passed": passed,
		"notes": notes,
	}


func _prepare_output_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))


func _write_text_file(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write %s" % path)
		return
	file.store_string(contents)
	file.close()


func _build_report(manifest: Dictionary) -> String:
	var lines: Array[String] = [
		"# Ruleset v0.4 Conformance",
		"",
		"Passed: %d/%d" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))],
		"Profile: `res://resources/rules/space_syndicate_ruleset_v04.tres`",
		"Output: `%s`" % OUTPUT_DIR,
		"",
		"| Case | Passed | Notes |",
		"| --- | --- | --- |",
	]
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant
		lines.append("| %s | %s | %s |" % [str(record.get("case_id", "")), str(record.get("passed", false)), str(record.get("notes", "")).replace("|", "/")])
	lines.append_array([
		"",
		"## Next replacement blocks",
		"",
		"- City development runtime cutover is complete: the compatibility shim rejects old direct-build requests while real cards own project creation.",
		"- Forced decision scheduling is cut over: one scene-owned arbiter applies v0.4 priority without changing existing action ids or rule handlers.",
		"- District purchase 12-second authority, private plan slot, and legacy End Turn removal remain separate gated sprints.",
	])
	return "\n".join(lines) + "\n"


func _write_screenshot() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		return
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(SCREENSHOT_PATH)


func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text
	if summary_label != null:
		summary_label.text = text
	if rule_summary_text != null:
		rule_summary_text.text = "[b]Runtime source[/b]  v0.4\n[b]Timing[/b]  30 shared / 25 organize / 5 lock\n[b]Wager[/b]  one mandatory 15-second window\n[b]Final countdown[/b]  75 seconds\n\n%s" % text


func _settle_frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame


func _passed_count(records: Array) -> int:
	var count := 0
	for record_variant in records:
		var record: Dictionary = record_variant
		if bool(record.get("passed", false)):
			count += 1
	return count


func _near(value: Variant, expected: float) -> bool:
	return is_equal_approx(float(value), expected)


func _is_pure_data(value: Variant) -> bool:
	if value is Callable or value is Object:
		return false
	if value is Dictionary:
		for key in (value as Dictionary).keys():
			if not _is_pure_data(key) or not _is_pure_data((value as Dictionary)[key]):
				return false
		return true
	if value is Array:
		for item in value:
			if not _is_pure_data(item):
				return false
	return true
