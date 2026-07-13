extends Control
class_name BalanceModelResourceSandboxBench

const OUTPUT_DIR := "user://space_syndicate_design_qa/balance_model_resource_sandbox/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/balance_model_resource_sandbox_sprint_2.png"
const AdapterScript := preload("res://scripts/balance/balance_parameter_model_adapter.gd")
const CasesScript := preload("res://scripts/tools/balance_model_resource_sandbox_cases.gd")
const SANDBOX_SCENE := preload("res://scenes/tools/BalanceModelResourceSandbox.tscn")

@export var auto_run := true
@export var auto_quit_after_suite := false

@onready var status_label: Label = %BalanceModelResourceSandboxBenchStatusLabel
@onready var summary_label: Label = %BalanceModelResourceSandboxBenchSummaryLabel
@onready var preview_host: Control = %BalanceModelResourceSandboxBenchPreviewHost

var _adapter: RefCounted = AdapterScript.new()
var _cases_source: RefCounted = CasesScript.new()
var _suite_running := false


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_sandbox_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func screenshot_path() -> String:
	return SCREENSHOT_PATH


func sandbox_cases() -> Array:
	var cases_variant: Variant = _cases_source.call("cases")
	return cases_variant if cases_variant is Array else []


func build_sandbox_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_variant in sandbox_cases():
		var case_data: Dictionary = case_variant if case_variant is Dictionary else {}
		records.append({
			"case_id": str(case_data.get("case_id", "")),
			"category": str(case_data.get("category", "")),
			"input_checked": false,
			"runtime_model_checked": false,
			"resource_profile_checked": false,
			"json_anchor_checked": false,
			"parity_checked": false,
			"passed": false,
			"notes": "Preview manifest only; run_sandbox_suite records live dry-run parity.",
		})
	return {
		"suite": "balance_model_resource_sandbox",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"record_count": records.size(),
		"records": records,
	}


func run_sandbox_suite() -> void:
	if _suite_running:
		return
	_suite_running = true
	_set_status("Running Balance model Resource sandbox...")
	_prepare_output_dir()
	var sandbox := _ensure_sandbox()
	var records: Array = []
	var all_passed := sandbox != null
	if sandbox == null:
		push_error("BalanceModelResourceSandboxBench could not instantiate sandbox.")
	else:
		for case_variant in sandbox_cases():
			var case_data: Dictionary = case_variant if case_variant is Dictionary else {}
			var record: Dictionary = await _run_sandbox_case(sandbox, case_data)
			records.append(record)
			all_passed = all_passed and bool(record.get("passed", false))
	var manifest := {
		"suite": "balance_model_resource_sandbox",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"record_count": records.size(),
		"passed_count": _passed_count(records),
		"records": records,
	}
	_write_text_file(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text_file(REPORT_PATH, _build_report(manifest))
	await _settle_frames(2)
	_write_screenshot()
	print("BalanceModelResourceSandboxBench manifest: %s" % MANIFEST_PATH)
	print("BalanceModelResourceSandboxBench report: %s" % REPORT_PATH)
	print("BalanceModelResourceSandboxBench screenshot: %s" % SCREENSHOT_PATH)
	if all_passed:
		_set_status("Balance model Resource sandbox passed: %d/%d | %s" % [_passed_count(records), records.size(), MANIFEST_PATH])
	else:
		_set_status("Balance model Resource sandbox failed: %d/%d | %s" % [_passed_count(records), records.size(), MANIFEST_PATH])
		push_error("BalanceModelResourceSandboxBench failed. See %s" % MANIFEST_PATH)
	_suite_running = false
	if auto_quit_after_suite:
		await get_tree().create_timer(0.25).timeout
		get_tree().quit(0 if all_passed else 1)


func _ensure_sandbox() -> Control:
	if preview_host == null:
		return null
	var existing := preview_host.find_child("BalanceModelResourceSandbox", true, false) as Control
	if existing != null:
		return existing
	var sandbox := SANDBOX_SCENE.instantiate() as Control
	if sandbox == null:
		return null
	sandbox.name = "BalanceModelResourceSandbox"
	preview_host.add_child(sandbox)
	sandbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return sandbox


func _run_sandbox_case(sandbox: Control, case_data: Dictionary) -> Dictionary:
	var case_id := str(case_data.get("case_id", ""))
	var selected := bool(sandbox.call("apply_case", case_id)) if sandbox.has_method("apply_case") else false
	await _settle_frames(2)
	var record_variant: Variant = sandbox.call("current_record") if sandbox.has_method("current_record") else _adapter.call("sample_outputs_for_case", case_data)
	var record: Dictionary = record_variant if record_variant is Dictionary else {}
	if record.is_empty():
		var adapter_record_variant: Variant = _adapter.call("sample_outputs_for_case", case_data)
		record = adapter_record_variant if adapter_record_variant is Dictionary else {}
	record["sandbox_selected"] = selected
	record["passed"] = bool(record.get("passed", false)) and selected
	if not selected:
		record["notes"] = "sandbox could not select case"
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
		"# Balance Model Resource Sandbox QA",
		"",
		"Output: `%s`" % OUTPUT_DIR,
		"Passed: %d/%d" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))],
		"",
		"| Case | Category | Runtime | Resource | JSON | Parity | Passed | Notes |",
		"| --- | --- | --- | --- | --- | --- | --- | --- |",
	]
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		lines.append("| %s | %s | %s | %s | %s | %s | %s | %s |" % [
			str(record.get("case_id", "")),
			str(record.get("category", "")),
			str(record.get("runtime_model_checked", false)),
			str(record.get("resource_profile_checked", false)),
			str(record.get("json_anchor_checked", false)),
			str(record.get("parity_checked", false)),
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
