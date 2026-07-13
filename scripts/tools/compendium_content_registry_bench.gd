extends Control
class_name CompendiumContentRegistryBench

const OUTPUT_DIR := "user://space_syndicate_design_qa/compendium_content_registry/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/compendium_content_registry_sprint_2.png"
const RegistryScript := preload("res://scripts/content/compendium_content_registry.gd")
const PREVIEW_SCENE := preload("res://scenes/tools/CompendiumContentRegistryMcpPreview.tscn")

@export var auto_run := true
@export var auto_quit_after_suite := false

@onready var status_label: Label = %CompendiumContentRegistryBenchStatusLabel
@onready var summary_label: Label = %CompendiumContentRegistryBenchSummaryLabel
@onready var preview_host: Control = %CompendiumContentRegistryBenchPreviewHost

var _registry := RegistryScript.new()
var _suite_running := false


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_registry_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func screenshot_path() -> String:
	return SCREENSHOT_PATH


func registry_cases() -> Array:
	var cases: Array = []
	for entry_id in _registry.entry_ids():
		var payload := _registry.entry_payload(entry_id)
		cases.append({
			"case_id": "resource_%s" % entry_id,
			"entry_id": entry_id,
			"entry_type": str(payload.get("entry_type", "")),
			"resource_path": str(payload.get("resource_path", "")),
		})
	return cases


func build_registry_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_variant in registry_cases():
		var case: Dictionary = case_variant if case_variant is Dictionary else {}
		records.append({
			"case_id": str(case.get("case_id", "")),
			"entry_id": str(case.get("entry_id", "")),
			"entry_type": str(case.get("entry_type", "")),
			"resource_path": str(case.get("resource_path", "")),
			"payload_checked": false,
			"privacy_checked": false,
			"ui_payload_checked": false,
			"passed": false,
			"notes": "Preview manifest only; run_registry_suite records live results.",
		})
	return {
		"suite": "compendium_content_registry",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"record_count": records.size(),
		"records": records,
	}


func run_registry_suite() -> void:
	if _suite_running:
		return
	_suite_running = true
	_set_status("Running Compendium content registry suite...")
	_prepare_output_dir()
	var preview := _ensure_preview()
	var records: Array = []
	var all_passed := preview != null
	if preview == null:
		push_error("CompendiumContentRegistryBench could not instantiate registry preview.")
	else:
		for case_variant in registry_cases():
			var case: Dictionary = case_variant if case_variant is Dictionary else {}
			var record := await _run_registry_case(preview, case)
			records.append(record)
			all_passed = all_passed and bool(record.get("passed", false))
	var manifest := {
		"suite": "compendium_content_registry",
		"output_dir": OUTPUT_DIR,
		"preview_scene": "res://scenes/tools/CompendiumContentRegistryMcpPreview.tscn",
		"screenshot_path": SCREENSHOT_PATH,
		"record_count": records.size(),
		"passed_count": _passed_count(records),
		"records": records,
	}
	_write_text_file(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text_file(REPORT_PATH, _build_report(manifest))
	await _settle_frames(2)
	_write_screenshot()
	print("CompendiumContentRegistryBench manifest: %s" % MANIFEST_PATH)
	print("CompendiumContentRegistryBench report: %s" % REPORT_PATH)
	print("CompendiumContentRegistryBench screenshot: %s" % SCREENSHOT_PATH)
	if all_passed:
		_set_status("Compendium content registry passed: %d/%d | %s" % [_passed_count(records), records.size(), MANIFEST_PATH])
	else:
		_set_status("Compendium content registry failed: %d/%d | %s" % [_passed_count(records), records.size(), MANIFEST_PATH])
		push_error("CompendiumContentRegistryBench failed. See %s" % MANIFEST_PATH)
	_suite_running = false
	if auto_quit_after_suite:
		await get_tree().create_timer(0.25).timeout
		get_tree().quit(0 if all_passed else 1)


func _ensure_preview() -> Control:
	if preview_host == null:
		return null
	var existing := preview_host.find_child("CompendiumContentRegistryMcpPreview", true, false) as Control
	if existing != null:
		return existing
	var preview := PREVIEW_SCENE.instantiate() as Control
	if preview == null:
		return null
	preview.name = "CompendiumContentRegistryMcpPreview"
	preview_host.add_child(preview)
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return preview


func _run_registry_case(preview: Control, case: Dictionary) -> Dictionary:
	var entry_id := str(case.get("entry_id", ""))
	var entry_type := str(case.get("entry_type", ""))
	var payload := _registry.entry_payload(entry_id)
	var applied := bool(preview.call("apply_entry", entry_id)) if preview.has_method("apply_entry") else false
	await _settle_frames(3)
	var payload_checked := _is_pure_data(payload) and not payload.is_empty()
	var privacy_checked := _privacy_checked(payload) and _privacy_checked(preview)
	var ui_payload_checked := _ui_payload_checked(entry_id, entry_type, preview)
	var passed := applied and payload_checked and privacy_checked and ui_payload_checked
	var notes := "ok" if passed else "applied=%s payload=%s privacy=%s ui=%s" % [str(applied), str(payload_checked), str(privacy_checked), str(ui_payload_checked)]
	return {
		"case_id": str(case.get("case_id", "")),
		"entry_id": entry_id,
		"entry_type": entry_type,
		"resource_path": str(case.get("resource_path", "")),
		"payload_checked": payload_checked,
		"privacy_checked": privacy_checked,
		"ui_payload_checked": ui_payload_checked,
		"passed": passed,
		"notes": notes,
	}


func _ui_payload_checked(entry_id: String, entry_type: String, preview: Control) -> bool:
	match entry_type:
		"card":
			return not _registry.to_card_codex_payload(entry_id).is_empty() and preview.find_child("CardCodexDetailPanel", true, false) != null
		"product":
			return not _registry.to_product_codex_payload(entry_id).is_empty() and preview.find_child("ProductCodexMarketBoardPanel", true, false) != null
		"monster":
			return not _registry.to_bestiary_payload(entry_id).is_empty() and preview.find_child("BestiaryMonsterBoardPanel", true, false) != null
	return false


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
		"# Compendium Content Registry QA",
		"",
		"Output: `%s`" % OUTPUT_DIR,
		"Passed: %d/%d" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))],
		"",
		"| Case | Entry | Type | Passed | Notes |",
		"| --- | --- | --- | --- | --- |",
	]
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		lines.append("| %s | %s | %s | %s | %s |" % [
			str(record.get("case_id", "")),
			str(record.get("entry_id", "")),
			str(record.get("entry_type", "")),
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


func _privacy_checked(value: Variant) -> bool:
	var text := ""
	if value is Node:
		text = _node_tree_text(value)
	else:
		text = JSON.stringify(value)
	text = text.to_lower()
	for token in ["hidden_owner", "private_target", "private_discard"]:
		if text.contains(token):
			return false
	return true


func _is_pure_data(value: Variant) -> bool:
	if value is Callable or value is Object:
		return false
	if value is Dictionary:
		for key in value.keys():
			if not _is_pure_data(key) or not _is_pure_data(value[key]):
				return false
		return true
	if value is Array:
		for item in value:
			if not _is_pure_data(item):
				return false
	return true


func _node_tree_text(node: Node) -> String:
	if node == null:
		return ""
	var parts: Array[String] = [str(node.name)]
	if node is Label:
		parts.append((node as Label).text)
	elif node is Button:
		parts.append((node as Button).text)
	for child in node.get_children():
		parts.append(_node_tree_text(child))
	return " ".join(parts)


func _settle_frames(count: int) -> void:
	for _index in range(maxi(1, count)):
		await get_tree().process_frame
