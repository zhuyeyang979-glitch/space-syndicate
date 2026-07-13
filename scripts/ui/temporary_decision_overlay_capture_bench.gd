extends Control
class_name SpaceSyndicateTemporaryDecisionOverlayCaptureBench

const PREVIEW_SCENE_PATH := "res://scenes/ui/TemporaryDecisionOverlayPreview.tscn"
const FIXTURE_SCRIPT_PATH := "res://scripts/ui/temporary_decision_preview_fixtures.gd"
const OUTPUT_DIR := "user://space_syndicate_design_qa/temporary_decision_overlay/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const BASE_SIZES := [
	{"width": 1280, "height": 720},
	{"width": 1600, "height": 960},
]
const STRESS_SIZE := {"width": 1600, "height": 960}
const PANEL_BY_FIXTURE_ID := {
	"monster_wager": "MonsterWagerDecisionPanel",
	"contract_response": "ContractResponseDecisionPanel",
	"discard_purchase": "TemporaryChoiceDecisionPanel",
	"monster_target_choice": "TemporaryChoiceDecisionPanel",
	"player_target_choice": "TemporaryChoiceDecisionPanel",
}

@export var auto_run_on_ready := true
@export var quit_when_complete := true
@export_range(0.0, 10.0, 0.5) var quit_delay_seconds := 3.0

@onready var status_label: Label = %CaptureBenchStatusLabel

var _fixtures: RefCounted = null
var _failures: Array[String] = []


func _ready() -> void:
	if auto_run_on_ready:
		call_deferred("_run_capture_suite_and_maybe_quit")


func output_dir() -> String:
	return OUTPUT_DIR


func capture_cases() -> Array:
	var result: Array = []
	for fixture_id in _fixture_ids():
		for viewport_size_dict in BASE_SIZES:
			result.append(_case_record(fixture_id, "base", viewport_size_dict))
	for fixture_id in _fixture_ids():
		result.append(_case_record(fixture_id, "long_text", STRESS_SIZE))
	for fixture_id in _fixture_ids():
		result.append(_case_record(fixture_id, "disabled_action", STRESS_SIZE))
	result.append(_edge_case_record("empty_payload", "", "", 0, "Empty payload should hide every temporary decision panel."))
	result.append(_edge_case_record("malformed_payload", "edge", "TemporaryDecisionModal", _malformed_action_count(), "Malformed payload should fall back to the generic temporary decision panel."))
	return result


func build_capture_manifest_preview() -> Dictionary:
	var records: Array = []
	for case in capture_cases():
		records.append(_manifest_record(case))
	return {
		"version": "temporary-decision-overlay-capture-v1",
		"output_dir": OUTPUT_DIR,
		"preview_scene": PREVIEW_SCENE_PATH,
		"case_count": records.size(),
		"records": records,
	}


func run_capture_suite() -> void:
	await _run_capture_suite_internal()


func _run_capture_suite_and_maybe_quit() -> void:
	var exit_code := await _run_capture_suite_internal()
	if quit_when_complete and get_tree() != null:
		if quit_delay_seconds > 0.0:
			await get_tree().create_timer(quit_delay_seconds).timeout
		get_tree().quit(exit_code)


func _run_capture_suite_internal() -> int:
	_failures.clear()
	_set_status("Preparing Temporary Decision Overlay capture bench...")
	var preview_scene := load(PREVIEW_SCENE_PATH) as PackedScene
	if preview_scene == null:
		_failures.append("preview scene could not load: %s" % PREVIEW_SCENE_PATH)
		return _finish_capture_suite()
	if not _prepare_output_dir():
		return _finish_capture_suite()
	var records: Array = []
	for case in capture_cases():
		var record := await _capture_case(preview_scene, case)
		records.append(record)
	var manifest := {
		"version": "temporary-decision-overlay-capture-v1",
		"output_dir": OUTPUT_DIR,
		"preview_scene": PREVIEW_SCENE_PATH,
		"case_count": records.size(),
		"records": records,
	}
	_write_text_file(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text_file(REPORT_PATH, _build_markdown_report(manifest))
	return _finish_capture_suite()


func _finish_capture_suite() -> int:
	if _failures.is_empty():
		var message := "Temporary Decision Overlay capture complete. manifest=%s report=%s" % [MANIFEST_PATH, REPORT_PATH]
		print(message)
		_set_status(message)
		return 0
	var failure_text := "Temporary Decision Overlay capture failed:\n- %s" % "\n- ".join(_failures)
	push_error(failure_text)
	_set_status(failure_text)
	return 1


func _capture_case(preview_scene: PackedScene, case: Dictionary) -> Dictionary:
	var capture_size := _case_size(case)
	var viewport := SubViewport.new()
	viewport.size = capture_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.gui_disable_input = true
	add_child(viewport)
	var preview := preview_scene.instantiate() as Control
	if preview == null:
		_failures.append("preview root was not Control for %s" % str(case.get("name", "")))
		remove_child(viewport)
		viewport.queue_free()
		return _manifest_record(case)
	viewport.add_child(preview)
	await _pump_frames(4)
	_stage_preview_case(preview, case)
	await _pump_frames(6)
	var record := _manifest_record(case)
	var texture := viewport.get_texture()
	if texture == null:
		_failures.append("viewport texture was unavailable for %s" % str(case.get("name", "")))
	else:
		var image := texture.get_image()
		if image == null:
			_failures.append("viewport image was unavailable for %s" % str(case.get("name", "")))
		else:
			var save_path := ProjectSettings.globalize_path(str(record.get("image_path", "")))
			var save_error := image.save_png(save_path)
			if save_error != OK:
				_failures.append("failed to save %s: %s" % [str(record.get("image_path", "")), str(save_error)])
	viewport.remove_child(preview)
	preview.queue_free()
	remove_child(viewport)
	viewport.queue_free()
	await _pump_frames(1)
	return record


func _stage_preview_case(preview: Control, case: Dictionary) -> void:
	var variant := str(case.get("variant", "base"))
	var fixture_id := str(case.get("fixture_id", ""))
	match variant:
		"base":
			preview.call("show_preview_id", fixture_id)
		"long_text":
			preview.call("show_preview_id", fixture_id)
			preview.call("show_long_text_stress")
		"disabled_action":
			preview.call("show_preview_id", fixture_id)
			preview.call("show_disabled_action_stress")
		"empty_payload":
			preview.call("show_empty_payload")
		"malformed_payload":
			preview.call("show_malformed_payload")
		_:
			preview.call("show_preview_id", fixture_id)


func _case_record(fixture_id: String, variant: String, viewport_size_dict: Dictionary) -> Dictionary:
	var fixture := _fixture(fixture_id)
	var actions: Array = fixture.get("actions", []) if fixture.get("actions", []) is Array else []
	return {
		"fixture_id": fixture_id,
		"variant": variant,
		"viewport_size": viewport_size_dict.duplicate(true),
		"expected_panel": str(PANEL_BY_FIXTURE_ID.get(fixture_id, "TemporaryDecisionModal")),
		"action_count": actions.size(),
		"notes": _case_notes(fixture_id, variant),
		"name": "%s_%s_%dx%d" % [fixture_id, variant, int(viewport_size_dict.get("width", 0)), int(viewport_size_dict.get("height", 0))],
	}


func _edge_case_record(variant: String, fixture_id: String, expected_panel: String, action_count: int, notes: String) -> Dictionary:
	return {
		"fixture_id": fixture_id,
		"variant": variant,
		"viewport_size": STRESS_SIZE.duplicate(true),
		"expected_panel": expected_panel,
		"action_count": action_count,
		"notes": notes,
		"name": "edge_%s_%dx%d" % [variant, int(STRESS_SIZE.get("width", 0)), int(STRESS_SIZE.get("height", 0))],
	}


func _manifest_record(case: Dictionary) -> Dictionary:
	var record := case.duplicate(true)
	record["image_path"] = OUTPUT_DIR + "%s.png" % _safe_filename(str(case.get("name", "capture")))
	record.erase("name")
	return record


func _build_markdown_report(manifest: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("# Temporary Decision Overlay Visual QA")
	lines.append("")
	lines.append("- Preview scene: `%s`" % PREVIEW_SCENE_PATH)
	lines.append("- Output dir: `%s`" % OUTPUT_DIR)
	lines.append("- Manifest: `%s`" % MANIFEST_PATH)
	lines.append("- Case count: %d" % int(manifest.get("case_count", 0)))
	lines.append("")
	lines.append("| Fixture | Variant | Size | Expected Panel | Actions | Image |")
	lines.append("| --- | --- | --- | --- | ---: | --- |")
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		var viewport_size_dict: Dictionary = record.get("viewport_size", {}) if record.get("viewport_size", {}) is Dictionary else {}
		lines.append("| %s | %s | %dx%d | %s | %d | `%s` |" % [
			str(record.get("fixture_id", "")),
			str(record.get("variant", "")),
			int(viewport_size_dict.get("width", 0)),
			int(viewport_size_dict.get("height", 0)),
			str(record.get("expected_panel", "")),
			int(record.get("action_count", 0)),
			str(record.get("image_path", "")),
		])
	return "\n".join(lines) + "\n"


func _prepare_output_dir() -> bool:
	var absolute_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	var make_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if make_error != OK:
		_failures.append("failed to create output dir %s: %s" % [OUTPUT_DIR, str(make_error)])
		return false
	var dir := DirAccess.open(absolute_dir)
	if dir == null:
		_failures.append("failed to open output dir %s" % OUTPUT_DIR)
		return false
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and (file_name.ends_with(".png") or file_name.ends_with(".json") or file_name.ends_with(".md")):
			var remove_error := dir.remove(file_name)
			if remove_error != OK:
				_failures.append("failed to remove old output %s: %s" % [file_name, str(remove_error)])
		file_name = dir.get_next()
	dir.list_dir_end()
	return true


func _write_text_file(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures.append("failed to write %s: %s" % [path, str(FileAccess.get_open_error())])
		return
	file.store_string(text)


func _fixture_ids() -> Array[String]:
	var fixtures := _fixtures_instance()
	if fixtures == null:
		return []
	var ids_variant: Variant = fixtures.call("preview_ids")
	var result: Array[String] = []
	if ids_variant is Array:
		for id_variant in ids_variant:
			result.append(str(id_variant))
	return result


func _fixture(id: String) -> Dictionary:
	var fixtures := _fixtures_instance()
	if fixtures == null:
		return {}
	var data_variant: Variant = fixtures.call("fixture", id)
	return data_variant if data_variant is Dictionary else {}


func _malformed_action_count() -> int:
	var fixtures := _fixtures_instance()
	if fixtures == null:
		return 0
	var data_variant: Variant = fixtures.call("malformed_fixture")
	var data: Dictionary = data_variant if data_variant is Dictionary else {}
	var actions: Array = data.get("actions", []) if data.get("actions", []) is Array else []
	return actions.size()


func _fixtures_instance() -> RefCounted:
	if _fixtures != null:
		return _fixtures
	var script := load(FIXTURE_SCRIPT_PATH)
	if script == null:
		return null
	var instance_variant: Variant = script.new()
	if instance_variant is RefCounted:
		_fixtures = instance_variant
	return _fixtures


func _case_size(case: Dictionary) -> Vector2i:
	var viewport_size_dict: Dictionary = case.get("viewport_size", {}) if case.get("viewport_size", {}) is Dictionary else {}
	return Vector2i(int(viewport_size_dict.get("width", 1600)), int(viewport_size_dict.get("height", 960)))


func _case_notes(fixture_id: String, variant: String) -> String:
	if variant == "base":
		return "Base fixture for %s." % fixture_id
	if variant == "long_text":
		return "Long text stress for %s." % fixture_id
	if variant == "disabled_action":
		return "Disabled action stress for %s." % fixture_id
	return variant


func _safe_filename(value: String) -> String:
	var safe := value.to_lower()
	for token in [" ", "/", "\\", ":", "|", "?", "*", "\"", "<", ">"]:
		safe = safe.replace(token, "_")
	return safe


func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text


func _pump_frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame
