extends Control
class_name AiPolicyResourceBench

const OUTPUT_DIR := "user://space_syndicate_design_qa/ai_policy_resourceization/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/ai_runtime_hard_cutover_sprint_41.png"
const PROFILE_RESOURCE_PATH := "res://resources/ai/ai_policy_profile_v1.tres"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const RUNTIME_OWNER_SCRIPT_PATH := "res://scripts/runtime/ai_runtime_controller.gd"
const RegistryScript := preload("res://scripts/ai/ai_policy_resource_registry.gd")
const PREVIEW_SCENE := preload("res://scenes/tools/AiPolicyResourceMcpPreview.tscn")

@export var auto_run := true
@export var auto_quit_after_suite := false

@onready var status_label: Label = %AiPolicyResourceBenchStatusLabel
@onready var summary_label: Label = %AiPolicyResourceBenchSummaryLabel
@onready var preview_host: Control = %AiPolicyResourceBenchPreviewHost

var _registry := RegistryScript.new()
var _suite_running := false


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		auto_quit_after_suite = true
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_resource_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func screenshot_path() -> String:
	return SCREENSHOT_PATH


func resource_cases() -> Array:
	return _registry.resource_cases()


func build_resource_manifest_preview() -> Dictionary:
	var manifest := _registry.build_manifest_preview()
	manifest["output_dir"] = OUTPUT_DIR
	manifest["screenshot_path"] = SCREENSHOT_PATH
	return manifest


func run_resource_suite() -> void:
	if _suite_running:
		return
	_suite_running = true
	_set_status("Running AI Policy Resourceization suite...")
	_prepare_output_dir()
	var preview := _ensure_preview()
	var records: Array = []
	var all_passed := preview != null
	if preview == null:
		push_error("AiPolicyResourceBench could not instantiate preview.")
	else:
		for case_variant in resource_cases():
			var case: Dictionary = case_variant if case_variant is Dictionary else {}
			var record := await _run_resource_case(preview, case)
			records.append(record)
			all_passed = all_passed and bool(record.get("passed", false))
	var manifest := {
		"suite": "ai_policy_resourceization",
		"output_dir": OUTPUT_DIR,
		"profile_resource": PROFILE_RESOURCE_PATH,
		"main_source": MAIN_SCRIPT_PATH,
		"runtime_owner": RUNTIME_OWNER_SCRIPT_PATH,
		"runtime_cutover_enabled": true,
		"screenshot_path": SCREENSHOT_PATH,
		"record_count": records.size(),
		"passed_count": _passed_count(records),
		"records": records,
	}
	_write_text_file(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text_file(REPORT_PATH, _build_report(manifest))
	await _settle_frames(2)
	_write_screenshot()
	print("AiPolicyResourceBench manifest: %s" % MANIFEST_PATH)
	print("AiPolicyResourceBench report: %s" % REPORT_PATH)
	print("AiPolicyResourceBench screenshot: %s" % SCREENSHOT_PATH)
	print("AiPolicyResourceBench passed: %d/%d" % [_passed_count(records), records.size()])
	if all_passed:
		_set_status("AI Policy Resourceization passed: %d/%d | %s" % [_passed_count(records), records.size(), MANIFEST_PATH])
	else:
		_set_status("AI Policy Resourceization failed: %d/%d | %s" % [_passed_count(records), records.size(), MANIFEST_PATH])
		push_error("AiPolicyResourceBench failed. See %s" % MANIFEST_PATH)
	_suite_running = false
	if auto_quit_after_suite:
		await get_tree().create_timer(0.25).timeout
		get_tree().quit(0 if all_passed else 1)


func _ensure_preview() -> Control:
	if preview_host == null:
		return null
	var existing := preview_host.find_child("AiPolicyResourceMcpPreview", true, false) as Control
	if existing != null:
		return existing
	var preview := PREVIEW_SCENE.instantiate() as Control
	if preview == null:
		return null
	preview.name = "AiPolicyResourceMcpPreview"
	preview_host.add_child(preview)
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return preview


func _run_resource_case(preview: Control, case: Dictionary) -> Dictionary:
	var case_id := str(case.get("case_id", ""))
	var selected := bool(preview.call("select_record", case_id)) if preview.has_method("select_record") else false
	await _settle_frames(2)
	var record := _registry.validation_record_for_case(case_id)
	if record.is_empty():
		record = {
			"case_id": case_id,
			"category": str(case.get("category", "")),
			"resource_path": PROFILE_RESOURCE_PATH,
			"source_path": MAIN_SCRIPT_PATH,
			"inspector_visible": false,
			"main_parity_checked": false,
			"personality_checked": false,
			"runtime_owner_checked": false,
			"pure_data_checked": false,
			"passed": false,
			"notes": "missing validation record",
		}
	record["preview_selected"] = selected
	record["passed"] = bool(record.get("passed", false)) and selected
	if not selected:
		record["notes"] = "preview could not select case"
	return record


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
		"# AI Policy Resourceization QA",
		"",
		"Output: `%s`" % OUTPUT_DIR,
		"Runtime owner: `%s`" % RUNTIME_OWNER_SCRIPT_PATH,
		"Resource cutover: enabled",
		"Passed: %d/%d" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))],
		"",
		"| Case | Category | Runtime parity | Personality | Runtime owner | Passed | Notes |",
		"| --- | --- | --- | --- | --- | --- | --- |",
	]
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		lines.append("| %s | %s | %s | %s | %s | %s | %s |" % [
			str(record.get("case_id", "")),
			str(record.get("category", "")),
			str(record.get("main_parity_checked", false)),
			str(record.get("personality_checked", false)),
			str(record.get("runtime_owner_checked", false)),
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
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(SCREENSHOT_PATH)


func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text
	if summary_label != null:
		summary_label.text = text


func _settle_frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame
