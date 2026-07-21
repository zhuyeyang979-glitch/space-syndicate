extends Control
class_name SpaceSyndicateTemporaryDecisionOverlayInteractionBench

const PREVIEW_SCENE_PATH := "res://scenes/ui/TemporaryDecisionOverlayPreview.tscn"
const FIXTURE_SCRIPT_PATH := "res://scripts/ui/temporary_decision_preview_fixtures.gd"
const OUTPUT_DIR := "user://space_syndicate_design_qa/temporary_decision_overlay_interactions/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const VIEWPORT_SIZE := {"width": 1600, "height": 960}
const PANEL_BY_FIXTURE_ID := {
	"monster_wager": "MonsterWagerDecisionPanel",
	"discard_purchase": "TemporaryChoiceDecisionPanel",
	"monster_target_choice": "TemporaryChoiceDecisionPanel",
	"player_target_choice": "TemporaryChoiceDecisionPanel",
}
const TEMPORARY_DECISION_PANEL_NAMES := [
	"MonsterWagerDecisionPanel",
	"TemporaryChoiceDecisionPanel",
	"TemporaryDecisionModal",
	"ConfirmPanel",
]

@export var auto_run_on_ready := true
@export var quit_when_complete := true
@export_range(0.0, 10.0, 0.5) var quit_delay_seconds := 3.0

@onready var status_label: Label = %InteractionBenchStatusLabel

var _fixtures: RefCounted = null
var _failures: Array[String] = []


func _ready() -> void:
	if auto_run_on_ready:
		call_deferred("_run_interaction_suite_and_maybe_quit")


func output_dir() -> String:
	return OUTPUT_DIR


func interaction_cases() -> Array:
	var result: Array = []
	for fixture_id in _fixture_ids():
		result.append(_case_record(fixture_id, "base", _case_payload(fixture_id, "base"), "Base fixture action should emit through the OverlayLayer signal."))
	for fixture_id in _fixture_ids():
		result.append(_case_record(fixture_id, "disabled_action", _case_payload(fixture_id, "disabled_action"), "Disabled stress fixture should display a disabled action and keep it silent."))
	result.append(_edge_case_record("empty_payload", {}, "", "Empty payload should hide every temporary decision panel."))
	result.append(_edge_case_record("malformed_payload", _malformed_payload(), "TemporaryDecisionModal", "Malformed payload should fall back to the generic temporary decision panel."))
	return result


func build_interaction_manifest_preview() -> Dictionary:
	var records: Array = []
	for case in interaction_cases():
		records.append(_preview_manifest_record(case))
	return {
		"version": "temporary-decision-overlay-interaction-v1",
		"output_dir": OUTPUT_DIR,
		"preview_scene": PREVIEW_SCENE_PATH,
		"case_count": records.size(),
		"records": records,
	}


func run_interaction_suite() -> void:
	await _run_interaction_suite_internal()


func _run_interaction_suite_and_maybe_quit() -> void:
	var exit_code := await _run_interaction_suite_internal()
	if quit_when_complete and get_tree() != null:
		if quit_delay_seconds > 0.0:
			await get_tree().create_timer(quit_delay_seconds).timeout
		get_tree().quit(exit_code)


func _run_interaction_suite_internal() -> int:
	_failures.clear()
	_set_status("Preparing Temporary Decision Overlay interaction bench...")
	var preview_scene := load(PREVIEW_SCENE_PATH) as PackedScene
	if preview_scene == null:
		_failures.append("preview scene could not load: %s" % PREVIEW_SCENE_PATH)
		return _finish_interaction_suite([])
	if not _prepare_output_dir():
		return _finish_interaction_suite([])
	var viewport := SubViewport.new()
	viewport.size = Vector2i(int(VIEWPORT_SIZE.get("width", 1600)), int(VIEWPORT_SIZE.get("height", 960)))
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.gui_disable_input = false
	add_child(viewport)
	var preview := preview_scene.instantiate() as Control
	if preview == null:
		_failures.append("preview root was not Control")
		remove_child(viewport)
		viewport.queue_free()
		return _finish_interaction_suite([])
	viewport.add_child(preview)
	await _pump_frames(6)
	var overlay := preview.find_child("OverlayLayer", true, false) as CanvasLayer
	var emitted_action_ids: Array[String] = []
	if overlay == null or not overlay.has_signal("temporary_decision_action_requested"):
		_failures.append("OverlayLayer with temporary_decision_action_requested signal was not available")
	else:
		overlay.connect("temporary_decision_action_requested", func(action_id: String) -> void:
			emitted_action_ids.append(action_id)
		)
	var records: Array = []
	for case in interaction_cases():
		var record := await _run_case(viewport, preview, case, emitted_action_ids)
		records.append(record)
	viewport.remove_child(preview)
	preview.queue_free()
	remove_child(viewport)
	viewport.queue_free()
	var manifest := {
		"version": "temporary-decision-overlay-interaction-v1",
		"output_dir": OUTPUT_DIR,
		"preview_scene": PREVIEW_SCENE_PATH,
		"case_count": records.size(),
		"records": records,
	}
	_write_text_file(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text_file(REPORT_PATH, _build_markdown_report(manifest))
	return _finish_interaction_suite(records)


func _finish_interaction_suite(_records: Array) -> int:
	if _failures.is_empty():
		var message := "Temporary Decision Overlay interaction QA complete. manifest=%s report=%s" % [MANIFEST_PATH, REPORT_PATH]
		print(message)
		_set_status(message)
		return 0
	var failure_text := "Temporary Decision Overlay interaction QA failed:\n- %s" % "\n- ".join(_failures)
	push_error(failure_text)
	_set_status(failure_text)
	return 1


func _run_case(viewport: SubViewport, preview: Control, case: Dictionary, emitted_action_ids: Array[String]) -> Dictionary:
	_stage_preview_case(preview, case)
	await _pump_frames(5)
	var expected_panel := str(case.get("expected_panel", ""))
	var visible_panels := _visible_temporary_decision_panel_names(preview)
	var panel_exclusive := visible_panels.is_empty() if expected_panel == "" else visible_panels.size() == 1 and visible_panels[0] == expected_panel
	var panel := (preview.find_child(expected_panel, true, false) as Control) if expected_panel != "" else null
	var payload: Dictionary = case.get("payload", {}) if case.get("payload", {}) is Dictionary else {}
	var expected_clicked_action_id := _first_enabled_action_id(payload)
	var clicked_action_id := ""
	var emitted_action_id := ""
	var disabled_action_checked := await _check_disabled_action(viewport, panel, emitted_action_ids, str(case.get("variant", "")) == "disabled_action")
	if panel != null and expected_clicked_action_id != "":
		var enabled_button := _first_enabled_button(panel)
		if enabled_button == null:
			_failures.append("%s/%s did not render an enabled action button" % [str(case.get("fixture_id", "")), str(case.get("variant", ""))])
		else:
			clicked_action_id = expected_clicked_action_id
			var before_count := emitted_action_ids.size()
			await _click_button(viewport, enabled_button)
			if emitted_action_ids.size() > before_count:
				emitted_action_id = emitted_action_ids[emitted_action_ids.size() - 1]
	if expected_clicked_action_id != "" and emitted_action_id != expected_clicked_action_id:
		_failures.append("%s/%s expected action %s but emitted %s" % [
			str(case.get("fixture_id", "")),
			str(case.get("variant", "")),
			expected_clicked_action_id,
			emitted_action_id,
		])
	if not panel_exclusive:
		_failures.append("%s/%s expected only %s visible, saw %s" % [
			str(case.get("fixture_id", "")),
			str(case.get("variant", "")),
			expected_panel,
			str(visible_panels),
		])
	if not disabled_action_checked:
		_failures.append("%s/%s did not prove disabled action silence" % [str(case.get("fixture_id", "")), str(case.get("variant", ""))])
	if preview.has_method("hide_overlay"):
		preview.call("hide_overlay")
	await _pump_frames(2)
	var hide_checked := _visible_temporary_decision_panel_names(preview).is_empty()
	if not hide_checked:
		_failures.append("%s/%s left a temporary decision panel visible after hide" % [str(case.get("fixture_id", "")), str(case.get("variant", ""))])
	var passed := panel_exclusive and disabled_action_checked and hide_checked and (expected_clicked_action_id == "" or emitted_action_id == expected_clicked_action_id)
	return {
		"fixture_id": str(case.get("fixture_id", "")),
		"variant": str(case.get("variant", "")),
		"expected_panel": expected_panel,
		"clicked_action_id": clicked_action_id,
		"emitted_action_id": emitted_action_id,
		"disabled_action_checked": disabled_action_checked,
		"panel_exclusive": panel_exclusive,
		"hide_checked": hide_checked,
		"passed": passed,
		"notes": str(case.get("notes", "")),
	}


func _stage_preview_case(preview: Control, case: Dictionary) -> void:
	var variant := str(case.get("variant", "base"))
	var fixture_id := str(case.get("fixture_id", ""))
	match variant:
		"base":
			preview.call("show_preview_id", fixture_id)
		"disabled_action":
			preview.call("show_preview_id", fixture_id)
			preview.call("show_disabled_action_stress")
		"empty_payload":
			preview.call("show_empty_payload")
		"malformed_payload":
			preview.call("show_malformed_payload")
		_:
			preview.call("show_preview_id", fixture_id)


func _check_disabled_action(viewport: SubViewport, panel: Control, emitted_action_ids: Array[String], should_have_disabled: bool) -> bool:
	if panel == null:
		return not should_have_disabled
	var disabled_button := _first_disabled_button(panel)
	if disabled_button == null:
		return not should_have_disabled
	var before_count := emitted_action_ids.size()
	await _click_button(viewport, disabled_button)
	return emitted_action_ids.size() == before_count


func _click_button(viewport: SubViewport, button: Button) -> void:
	if viewport == null or button == null or not button.is_inside_tree() or not button.is_visible_in_tree():
		return
	var center := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = center
	motion.global_position = center
	viewport.push_input(motion, true)
	await _pump_frames(1)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = center
	press.global_position = center
	press.pressed = true
	viewport.push_input(press, true)
	await _pump_frames(1)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = center
	release.global_position = center
	release.pressed = false
	viewport.push_input(release, true)
	await _pump_frames(2)


func _case_record(fixture_id: String, variant: String, payload: Dictionary, notes: String) -> Dictionary:
	var actions: Array = payload.get("actions", []) if payload.get("actions", []) is Array else []
	return {
		"fixture_id": fixture_id,
		"variant": variant,
		"expected_panel": str(PANEL_BY_FIXTURE_ID.get(fixture_id, "TemporaryDecisionModal")),
		"payload": payload.duplicate(true),
		"action_count": actions.size(),
		"notes": notes,
	}


func _edge_case_record(variant: String, payload: Dictionary, expected_panel: String, notes: String) -> Dictionary:
	var actions: Array = payload.get("actions", []) if payload.get("actions", []) is Array else []
	return {
		"fixture_id": "edge",
		"variant": variant,
		"expected_panel": expected_panel,
		"payload": payload.duplicate(true),
		"action_count": actions.size(),
		"notes": notes,
	}


func _preview_manifest_record(case: Dictionary) -> Dictionary:
	var payload: Dictionary = case.get("payload", {}) if case.get("payload", {}) is Dictionary else {}
	return {
		"fixture_id": str(case.get("fixture_id", "")),
		"variant": str(case.get("variant", "")),
		"expected_panel": str(case.get("expected_panel", "")),
		"clicked_action_id": _first_enabled_action_id(payload),
		"emitted_action_id": "",
		"disabled_action_checked": false,
		"panel_exclusive": false,
		"hide_checked": false,
		"passed": false,
		"notes": str(case.get("notes", "")),
	}


func _build_markdown_report(manifest: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("# Temporary Decision Overlay Interaction QA")
	lines.append("")
	lines.append("- Preview scene: `%s`" % PREVIEW_SCENE_PATH)
	lines.append("- Output dir: `%s`" % OUTPUT_DIR)
	lines.append("- Manifest: `%s`" % MANIFEST_PATH)
	lines.append("- Case count: %d" % int(manifest.get("case_count", 0)))
	lines.append("")
	lines.append("| Fixture | Variant | Expected Panel | Clicked | Emitted | Disabled Silent | Exclusive | Hide | Passed |")
	lines.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- |")
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		lines.append("| %s | %s | %s | `%s` | `%s` | %s | %s | %s | %s |" % [
			str(record.get("fixture_id", "")),
			str(record.get("variant", "")),
			str(record.get("expected_panel", "")),
			str(record.get("clicked_action_id", "")),
			str(record.get("emitted_action_id", "")),
			str(record.get("disabled_action_checked", false)),
			str(record.get("panel_exclusive", false)),
			str(record.get("hide_checked", false)),
			str(record.get("passed", false)),
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
		if not dir.current_is_dir() and (file_name.ends_with(".json") or file_name.ends_with(".md")):
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


func _visible_temporary_decision_panel_names(root_node: Node) -> Array[String]:
	var names: Array[String] = []
	for node_name in TEMPORARY_DECISION_PANEL_NAMES:
		var panel := root_node.find_child(node_name, true, false) as Control
		if panel != null and panel.visible:
			names.append(node_name)
	return names


func _first_enabled_button(node: Node) -> Button:
	for button_variant in _visible_buttons_in(node):
		var button := button_variant as Button
		if button != null and not button.disabled:
			return button
	return null


func _first_disabled_button(node: Node) -> Button:
	for button_variant in _visible_buttons_in(node):
		var button := button_variant as Button
		if button != null and button.disabled:
			return button
	return null


func _visible_buttons_in(node: Node) -> Array:
	if node == null:
		return []
	var result: Array = []
	for button_variant in node.find_children("*", "Button", true, false):
		var button := button_variant as Button
		if button != null and button.visible and button.is_visible_in_tree():
			result.append(button)
	return result


func _first_enabled_action_id(payload: Dictionary) -> String:
	var actions: Array = payload.get("actions", []) if payload.get("actions", []) is Array else []
	for action_variant in actions:
		if not (action_variant is Dictionary):
			continue
		var action: Dictionary = action_variant
		var action_id := str(action.get("id", "")).strip_edges()
		if action_id != "" and not bool(action.get("disabled", false)):
			return action_id
	return ""


func _case_payload(fixture_id: String, variant: String) -> Dictionary:
	var fixtures := _fixtures_instance()
	if fixtures == null:
		return {}
	var payload_variant: Variant
	if variant == "disabled_action":
		payload_variant = fixtures.call("disabled_action_fixture", fixture_id)
	else:
		payload_variant = fixtures.call("fixture", fixture_id)
	return (payload_variant as Dictionary).duplicate(true) if payload_variant is Dictionary else {}


func _malformed_payload() -> Dictionary:
	var fixtures := _fixtures_instance()
	if fixtures == null:
		return {}
	var payload_variant: Variant = fixtures.call("malformed_fixture")
	return (payload_variant as Dictionary).duplicate(true) if payload_variant is Dictionary else {}


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


func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text


func _pump_frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame
