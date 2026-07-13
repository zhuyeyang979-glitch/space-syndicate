extends Control
class_name SystemResourceizationAuditBench

const OUTPUT_DIR := "user://space_syndicate_design_qa/system_resourceization_audit/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/system_resourceization_audit_sprint_1.png"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const RegistryScript := preload("res://scripts/tools/system_resourceization_audit_registry.gd")

@export var auto_run := true
@export var auto_quit_after_suite := false

@onready var status_label: Label = %SystemResourceizationAuditBenchStatusLabel
@onready var summary_label: Label = %SystemResourceizationAuditBenchSummaryLabel
@onready var preview_host: Control = %SystemResourceizationAuditBenchPreviewHost

var _registry: RefCounted = RegistryScript.new()
var _suite_running := false


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_audit_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func screenshot_path() -> String:
	return SCREENSHOT_PATH


func audit_cases() -> Array:
	var cases: Array = []
	for record_variant in _registry.call("records"):
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		cases.append({
			"case_id": "audit_%s" % str(record.get("id", "")),
			"id": str(record.get("id", "")),
			"category": str(record.get("category", "")),
			"status": str(record.get("current_status", "")),
			"current_path": str(record.get("current_path", "")),
			"key_functions": _string_array(record.get("key_functions", [])),
		})
	return cases


func build_audit_manifest_preview() -> Dictionary:
	var source := _read_main_source()
	var function_names := _function_names_from_source(source)
	var records: Array = []
	for case_variant in audit_cases():
		var case: Dictionary = case_variant if case_variant is Dictionary else {}
		var function_count := _case_function_count(case, function_names)
		records.append({
			"category": str(case.get("category", "")),
			"id": str(case.get("id", "")),
			"status": str(case.get("status", "")),
			"current_path": str(case.get("current_path", "")),
			"function_count": function_count,
			"editor_visible": _editor_visible(case),
			"recommended_next_step": _recommended_next_step(str(case.get("id", ""))),
			"passed": false,
			"notes": "Preview manifest only; run_audit_suite records live checks.",
		})
	return {
		"suite": "system_resourceization_audit",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"menu_function_count": _count_functions(function_names, "menu"),
		"balance_function_count": _count_functions(function_names, "balance"),
		"ai_function_count": _count_functions(function_names, "ai"),
		"auto_monster_function_count": _count_functions(function_names, "auto_monster"),
		"record_count": records.size(),
		"records": records,
	}


func run_audit_suite() -> void:
	if _suite_running:
		return
	_suite_running = true
	_set_status("Running system resourceization audit...")
	_prepare_output_dir()
	var source := _read_main_source()
	var function_names := _function_names_from_source(source)
	var records: Array = []
	var all_passed := not source.is_empty()
	for case_variant in audit_cases():
		var case: Dictionary = case_variant if case_variant is Dictionary else {}
		var record := _run_audit_case(case, function_names)
		records.append(record)
		all_passed = all_passed and bool(record.get("passed", false))
	var manifest := {
		"suite": "system_resourceization_audit",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"menu_function_count": _count_functions(function_names, "menu"),
		"balance_function_count": _count_functions(function_names, "balance"),
		"ai_function_count": _count_functions(function_names, "ai"),
		"auto_monster_function_count": _count_functions(function_names, "auto_monster"),
		"record_count": records.size(),
		"passed_count": _passed_count(records),
		"records": records,
	}
	_render_summary(manifest)
	_write_text_file(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text_file(REPORT_PATH, _build_report(manifest))
	await _settle_frames(2)
	_write_screenshot()
	print("SystemResourceizationAuditBench manifest: %s" % MANIFEST_PATH)
	print("SystemResourceizationAuditBench report: %s" % REPORT_PATH)
	print("SystemResourceizationAuditBench screenshot: %s" % SCREENSHOT_PATH)
	if all_passed:
		_set_status("System resourceization audit passed: %d/%d | %s" % [_passed_count(records), records.size(), MANIFEST_PATH])
	else:
		_set_status("System resourceization audit failed: %d/%d | %s" % [_passed_count(records), records.size(), MANIFEST_PATH])
		push_error("SystemResourceizationAuditBench failed. See %s" % MANIFEST_PATH)
	_suite_running = false
	if auto_quit_after_suite or DisplayServer.get_name() == "headless":
		await get_tree().create_timer(0.25).timeout
		get_tree().quit(0 if all_passed else 1)


func _run_audit_case(case: Dictionary, function_names: Array[String]) -> Dictionary:
	var case_id := str(case.get("id", ""))
	var current_path := str(case.get("current_path", ""))
	var function_count := _case_function_count(case, function_names)
	var path_checked := _path_checked(current_path)
	var related_checked := _related_paths_checked(case_id)
	var editor_visible := _editor_visible(case)
	var record_variant: Variant = _registry.call("record_for_id", case_id) if _registry != null else {}
	var record: Dictionary = record_variant if record_variant is Dictionary else {}
	var visibility_checked := str(record.get("editor_visibility", "")).strip_edges() != ""
	var needs_functions := current_path == MAIN_SCRIPT_PATH
	var functions_checked := function_count > 0 if needs_functions else true
	var passed := path_checked and related_checked and visibility_checked and functions_checked
	var notes := "ok" if passed else "path=%s related=%s visibility=%s functions=%d" % [str(path_checked), str(related_checked), str(visibility_checked), function_count]
	return {
		"category": str(case.get("category", "")),
		"id": case_id,
		"status": str(case.get("status", "")),
		"current_path": current_path,
		"function_count": function_count,
		"editor_visible": editor_visible,
		"recommended_next_step": _recommended_next_step(case_id),
		"passed": passed,
		"notes": notes,
	}


func _related_paths_checked(case_id: String) -> bool:
	var record_variant: Variant = _registry.call("record_for_id", case_id) if _registry != null else {}
	if not (record_variant is Dictionary):
		return false
	var record: Dictionary = record_variant
	var paths_variant: Variant = record.get("related_paths", [])
	if not (paths_variant is Array):
		return true
	for path_variant in paths_variant:
		var path := str(path_variant)
		if path == MAIN_SCRIPT_PATH:
			continue
		if not _path_checked(path):
			return false
	return true


func _case_function_count(case: Dictionary, function_names: Array[String]) -> int:
	var case_id := str(case.get("id", ""))
	match case_id:
		"main_gd_menu_controller_runtime":
			return _count_functions(function_names, "menu")
		"main_gd_balance_wrappers":
			return _count_functions(function_names, "balance")
		"main_gd_ai_policy_runtime", "ai_policy_resource_candidate":
			return _count_functions(function_names, "ai")
		"main_gd_monster_ai_runtime":
			return _count_functions(function_names, "auto_monster")
		"runtime_fallbacks_main_gd":
			return _count_matching_functions(function_names, ["_build_runtime_game_screen", "_bind_runtime_overlay_surfaces", "_runtime_composition_snapshot"])
	var key_functions: Array[String] = _string_array(case.get("key_functions", []))
	return key_functions.size()


func _count_functions(function_names: Array[String], mode: String) -> int:
	match mode:
		"menu":
			return _count_matching_functions(function_names, ["menu", "codex", "bestiary"])
		"balance":
			return _count_matching_functions(function_names, ["balance", "price", "gradient", "curve", "gdp", "payout"])
		"ai":
			return _count_matching_functions(function_names, ["_ai_", "_auto_ai_", "_weighted_", "score", "weight", "candidate"])
		"auto_monster":
			return _count_matching_functions(function_names, ["_auto_monster_", "_monster_action", "_monster_target", "_monster_wager"])
	return 0


func _count_matching_functions(function_names: Array[String], needles: Array) -> int:
	var count := 0
	for function_name in function_names:
		var lowered := function_name.to_lower()
		for needle_variant in needles:
			var needle := str(needle_variant).to_lower()
			if lowered.contains(needle):
				count += 1
				break
	return count


func _function_names_from_source(source: String) -> Array[String]:
	var names: Array[String] = []
	for raw_line in source.split("\n"):
		var line := str(raw_line).strip_edges()
		if not line.begins_with("func "):
			continue
		var name_part := line.substr(5)
		var paren_index := name_part.find("(")
		if paren_index >= 0:
			name_part = name_part.substr(0, paren_index)
		names.append(name_part.strip_edges())
	return names


func _read_main_source() -> String:
	var file := FileAccess.open(MAIN_SCRIPT_PATH, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _path_checked(path: String) -> bool:
	if path.strip_edges() == "":
		return true
	if path.contains("::"):
		path = path.get_slice("::", 0)
	if path.ends_with(".json"):
		return FileAccess.file_exists(path)
	if path.ends_with(".gd"):
		return ResourceLoader.exists(path)
	if path.ends_with(".tscn") or path.ends_with(".tres"):
		return ResourceLoader.exists(path) and load(path) != null
	return FileAccess.file_exists(path) or ResourceLoader.exists(path)


func _editor_visible(case: Dictionary) -> bool:
	var status := str(case.get("status", ""))
	var path := str(case.get("current_path", ""))
	if status == "sceneized":
		return path.ends_with(".tscn") and ResourceLoader.exists(path)
	if status == "candidate_resource":
		return false
	return str(case.get("current_path", "")).begins_with("res://")


func _recommended_next_step(id: String) -> String:
	var record_variant: Variant = _registry.call("record_for_id", id) if _registry != null else {}
	if record_variant is Dictionary:
		var record: Dictionary = record_variant
		return str(record.get("recommended_next_step", ""))
	return ""


func _render_summary(manifest: Dictionary) -> void:
	if preview_host == null:
		return
	for child in preview_host.get_children():
		preview_host.remove_child(child)
		child.queue_free()
	var label := Label.new()
	label.name = "SystemResourceizationAuditBenchManifestSummary"
	label.text = "Menu functions: %d\nBalance/gradient functions: %d\nAI functions: %d\nAuto monster functions: %d\nPassed: %d/%d" % [
		int(manifest.get("menu_function_count", 0)),
		int(manifest.get("balance_function_count", 0)),
		int(manifest.get("ai_function_count", 0)),
		int(manifest.get("auto_monster_function_count", 0)),
		int(manifest.get("passed_count", 0)),
		int(manifest.get("record_count", 0)),
	]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color("#dbeafe"))
	label.add_theme_font_size_override("font_size", 16)
	preview_host.add_child(label)


func _prepare_output_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))


func _write_text_file(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write %s" % path)
		return
	file.store_string(text)
	file.close()


func _build_report(manifest: Dictionary) -> String:
	var lines: Array[String] = [
		"# System Resourceization Audit",
		"",
		"Output: `%s`" % OUTPUT_DIR,
		"Passed: %d/%d" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))],
		"",
		"- Menu functions: %d" % int(manifest.get("menu_function_count", 0)),
		"- Balance / gradient functions: %d" % int(manifest.get("balance_function_count", 0)),
		"- AI functions: %d" % int(manifest.get("ai_function_count", 0)),
		"- Auto monster functions: %d" % int(manifest.get("auto_monster_function_count", 0)),
		"",
		"| Category | ID | Status | Functions | Editor Visible | Passed | Notes |",
		"| --- | --- | --- | --- | --- | --- | --- |",
	]
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		lines.append("| %s | %s | %s | %d | %s | %s | %s |" % [
			str(record.get("category", "")),
			str(record.get("id", "")),
			str(record.get("status", "")),
			int(record.get("function_count", 0)),
			str(record.get("editor_visible", false)),
			str(record.get("passed", false)),
			str(record.get("notes", "")).replace("|", "/"),
		])
	return "\n".join(lines) + "\n"


func _passed_count(records: Array) -> int:
	var count := 0
	for record_variant in records:
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		if bool(record.get("passed", false)):
			count += 1
	return count


func _write_screenshot() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var viewport := get_viewport()
	if viewport == null or viewport.get_texture() == null:
		return
	var image := viewport.get_texture().get_image()
	if image == null:
		return
	var absolute_path := ProjectSettings.globalize_path(SCREENSHOT_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	image.save_png(absolute_path)


func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text
	if summary_label != null:
		summary_label.text = text


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result


func _settle_frames(count: int) -> void:
	for _index in range(maxi(1, count)):
		await get_tree().process_frame
