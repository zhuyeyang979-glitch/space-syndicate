extends Control
class_name BalanceParameterResourceBench

const OUTPUT_DIR := "user://space_syndicate_design_qa/balance_parameter_resourceization/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/balance_parameter_resourceization_sprint_1.png"
const PROFILE_RESOURCE_PATH := "res://resources/balance/balance_parameter_profile_v1.tres"
const RUNTIME_RESOURCE_PATH := "res://resources/balance/runtime_balance_parameters_v1.tres"
const PRICE_CURVE_RESOURCE_PATH := "res://resources/balance/card_price_curve_parameters_v1.tres"
const RUNTIME_JSON_PATH := "res://data/balance/runtime_balance_targets.json"
const PRICE_CURVE_JSON_PATH := "res://data/balance/price_curve_v1.json"
const RegistryScript := preload("res://scripts/balance/balance_parameter_resource_registry.gd")
const PREVIEW_SCENE := preload("res://scenes/tools/BalanceParameterResourceMcpPreview.tscn")

@export var auto_run := true
@export var auto_quit_after_suite := false

@onready var status_label: Label = %BalanceParameterResourceBenchStatusLabel
@onready var summary_label: Label = %BalanceParameterResourceBenchSummaryLabel
@onready var preview_host: Control = %BalanceParameterResourceBenchPreviewHost

var _registry := RegistryScript.new()
var _suite_running := false


func _ready() -> void:
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
	_set_status("Running Balance Parameter Resourceization suite...")
	_prepare_output_dir()
	var preview := _ensure_preview()
	var records: Array = []
	var all_passed := preview != null
	if preview == null:
		push_error("BalanceParameterResourceBench could not instantiate preview.")
	else:
		for case_variant in resource_cases():
			var case: Dictionary = case_variant if case_variant is Dictionary else {}
			var record := await _run_resource_case(preview, case)
			records.append(record)
			all_passed = all_passed and bool(record.get("passed", false))
	var manifest := {
		"suite": "balance_parameter_resourceization",
		"output_dir": OUTPUT_DIR,
		"profile_resource": PROFILE_RESOURCE_PATH,
		"runtime_resource": RUNTIME_RESOURCE_PATH,
		"price_curve_resource": PRICE_CURVE_RESOURCE_PATH,
		"runtime_json": RUNTIME_JSON_PATH,
		"price_curve_json": PRICE_CURVE_JSON_PATH,
		"screenshot_path": SCREENSHOT_PATH,
		"record_count": records.size(),
		"passed_count": _passed_count(records),
		"records": records,
	}
	_write_text_file(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text_file(REPORT_PATH, _build_report(manifest))
	await _settle_frames(2)
	_write_screenshot()
	print("BalanceParameterResourceBench manifest: %s" % MANIFEST_PATH)
	print("BalanceParameterResourceBench report: %s" % REPORT_PATH)
	print("BalanceParameterResourceBench screenshot: %s" % SCREENSHOT_PATH)
	if all_passed:
		_set_status("Balance Parameter Resourceization passed: %d/%d | %s" % [_passed_count(records), records.size(), MANIFEST_PATH])
	else:
		_set_status("Balance Parameter Resourceization failed: %d/%d | %s" % [_passed_count(records), records.size(), MANIFEST_PATH])
		push_error("BalanceParameterResourceBench failed. See %s" % MANIFEST_PATH)
	_suite_running = false
	if auto_quit_after_suite:
		await get_tree().create_timer(0.25).timeout
		get_tree().quit(0 if all_passed else 1)


func _ensure_preview() -> Control:
	if preview_host == null:
		return null
	var existing := preview_host.find_child("BalanceParameterResourceMcpPreview", true, false) as Control
	if existing != null:
		return existing
	var preview := PREVIEW_SCENE.instantiate() as Control
	if preview == null:
		return null
	preview.name = "BalanceParameterResourceMcpPreview"
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
			"resource_path": str(case.get("resource_path", "")),
			"json_path": str(case.get("json_path", "")),
			"category": str(case.get("category", "")),
			"inspector_visible": false,
			"json_parity_checked": false,
			"model_compatibility_checked": false,
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
		"# Balance Parameter Resourceization QA",
		"",
		"Output: `%s`" % OUTPUT_DIR,
		"Passed: %d/%d" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))],
		"",
		"| Case | Category | Resource | JSON | Passed | Notes |",
		"| --- | --- | --- | --- | --- | --- |",
	]
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		lines.append("| %s | %s | %s | %s | %s | %s |" % [
			str(record.get("case_id", "")),
			str(record.get("category", "")),
			str(record.get("resource_path", "")),
			str(record.get("json_path", "")),
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
