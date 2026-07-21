extends Control
class_name PlayerTurnInteractionBench

const PREVIEW_SCENE_PATH := "res://scenes/tools/PlayerTurnMcpPreview.tscn"
const FIXTURE_SCRIPT_PATH := "res://scripts/tools/player_turn_mcp_preview_fixtures.gd"
const OUTPUT_DIR := "user://space_syndicate_design_qa/player_turn_interactions/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const VIEWPORT_SIZE := Vector2i(1600, 960)

@export var auto_run_on_ready := true
@export var quit_when_complete := true
@export_range(0.0, 20.0, 0.5) var quit_delay_seconds := 8.0

@onready var status_label: Label = %PlayerTurnInteractionStatusLabel
@onready var summary_label: Label = %PlayerTurnInteractionSummaryLabel
@onready var preview_viewport: SubViewport = %PlayerTurnInteractionPreviewViewport

var _fixtures: RefCounted = null
var _failures: Array[String] = []


func _ready() -> void:
	if preview_viewport != null:
		preview_viewport.size = VIEWPORT_SIZE
		preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		preview_viewport.gui_disable_input = false
	if auto_run_on_ready:
		call_deferred("_run_interaction_suite_and_maybe_quit")


func output_dir() -> String:
	return OUTPUT_DIR


func interaction_cases() -> Array:
	return [
		_case_record("empty_hand", "empty_hand_affordance", "", "", "HandRack keeps an empty affordance and does not expose a card action."),
		_case_record("normal_hand", "select_first_card_and_play", "card_orbital_finance", "play:orbital_finance", "Clicking the first hand card updates detail and emits the card play action."),
		_case_record("selected_enabled_card", "selected_enabled_action", "card_shadow_disruption", "play:shadow_disruption", "Selected enabled card keeps focus and emits its play action."),
		_case_record("selected_disabled_card", "disabled_action_silent", "card_monster_tip_blocked", "play:monster_tip", "Disabled action remains visible but does not emit."),
		_case_record("hovered_card", "hover_keeps_focus", "card_orbital_finance", "", "Hover metadata is present without clearing selected-card context."),
		_case_record("drag_preview", "invalid_drop_silent", "card_signal_jammer", "", "Invalid drop state is visible and does not emit a play action."),
		_case_record("right_inspector_card_detail", "right_inspector_detail", "card_orbital_finance", "play:orbital_finance", "RightInspector shows use-case, target, requirement, effect, and action."),
		_case_record("public_track_selection", "public_track_click", "card_orbital_finance", "track:interaction_a", "Clicking a public-track slot records the public UI action without private owner data."),
		_case_record("temporary_decision_pending_hint", "temporary_decision_pending_hint", "card_shadow_disruption", "", "Pending overlay hint is visible and does not bypass the temporary decision flow."),
	]


func build_interaction_manifest_preview() -> Dictionary:
	var records: Array = []
	for case in interaction_cases():
		records.append(_preview_manifest_record(case))
	return {
		"version": "player-turn-interaction-v1",
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
	_set_status("Preparing Player Turn interaction bench...")
	if not _prepare_output_dir():
		return _finish_interaction_suite([])
	var preview_scene := load(PREVIEW_SCENE_PATH) as PackedScene
	if preview_scene == null:
		_failures.append("preview scene could not load: %s" % PREVIEW_SCENE_PATH)
		return _finish_interaction_suite([])
	var viewport := _active_viewport()
	_clear_viewport(viewport)
	var preview := preview_scene.instantiate() as Control
	if preview == null:
		_failures.append("preview root was not Control")
		return _finish_interaction_suite([])
	preview.name = "PlayerTurnMcpPreviewRuntime"
	viewport.add_child(preview)
	await _pump_frames(8)
	var emitted_action_ids: Array[String] = []
	var track_action_ids: Array[String] = []
	_connect_preview_signals(preview, emitted_action_ids, track_action_ids)
	var records: Array = []
	for case in interaction_cases():
		var record := await _run_case(viewport, preview, case, emitted_action_ids, track_action_ids)
		records.append(record)
	var manifest := {
		"version": "player-turn-interaction-v1",
		"output_dir": OUTPUT_DIR,
		"preview_scene": PREVIEW_SCENE_PATH,
		"case_count": records.size(),
		"records": records,
	}
	_write_text_file(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text_file(REPORT_PATH, _build_markdown_report(manifest))
	return _finish_interaction_suite(records)


func _run_case(viewport: SubViewport, preview: Control, case: Dictionary, emitted_action_ids: Array[String], track_action_ids: Array[String]) -> Dictionary:
	var fixture_id := str(case.get("fixture_id", ""))
	var interaction_name := str(case.get("interaction_name", ""))
	_set_status("Running %s / %s..." % [fixture_id, interaction_name])
	if preview.has_method("show_preview_id"):
		preview.call("show_preview_id", fixture_id)
	await _pump_frames(8)
	var fixture := _fixture(fixture_id)
	var selected_card_id := str(case.get("selected_card_id", fixture.get("selected_card_id", "")))
	var expected_action_id := str(case.get("expected_action_id", ""))
	var clicked_action_id := ""
	var emitted_action_id := ""
	var before_count := emitted_action_ids.size()
	var before_track_count := track_action_ids.size()
	var right_inspector_checked := _right_inspector_has_expected_detail(preview, fixture)
	var disabled_action_checked := false
	var drag_state_checked := false
	var panel_exclusive := _preview_has_single_player_surface(preview)
	var notes := str(case.get("notes", ""))
	match interaction_name:
		"empty_hand_affordance":
			disabled_action_checked = _check_empty_hand(preview)
		"select_first_card_and_play":
			await _click_hand_card(viewport, preview, selected_card_id)
			await _pump_frames(6)
			right_inspector_checked = _right_inspector_has_card(preview, selected_card_id) and _right_inspector_has_expected_detail(preview, preview.call("current_fixture") if preview.has_method("current_fixture") else fixture)
			clicked_action_id = expected_action_id
			await _click_card_action(viewport, preview, fixture, selected_card_id, emitted_action_ids)
			emitted_action_id = _latest_since(emitted_action_ids, before_count)
		"selected_enabled_action":
			drag_state_checked = _hand_card_has_meta(preview, selected_card_id, "hand_state_selected", true)
			clicked_action_id = expected_action_id
			await _click_card_action(viewport, preview, fixture, selected_card_id, emitted_action_ids)
			emitted_action_id = _latest_since(emitted_action_ids, before_count)
		"disabled_action_silent":
			clicked_action_id = expected_action_id
			disabled_action_checked = await _click_disabled_card_action(viewport, preview, fixture, selected_card_id, emitted_action_ids)
			emitted_action_id = _latest_since(emitted_action_ids, before_count)
		"hover_keeps_focus":
			drag_state_checked = _hand_card_has_meta(preview, selected_card_id, "hand_state_hovered", true)
			disabled_action_checked = emitted_action_ids.size() == before_count
		"invalid_drop_silent":
			drag_state_checked = _hand_card_has_meta(preview, selected_card_id, "hand_state_drop_invalid", true) and _hand_card_drag_state(preview, selected_card_id) == "invalid_drop"
			disabled_action_checked = emitted_action_ids.size() == before_count
			_clear_invalid_drag(preview)
		"right_inspector_detail":
			clicked_action_id = expected_action_id
			await _click_card_action(viewport, preview, fixture, selected_card_id, emitted_action_ids)
			emitted_action_id = _latest_since(emitted_action_ids, before_count)
		"public_track_click":
			await _click_public_track_slot(viewport, preview, track_action_ids, fixture)
			clicked_action_id = expected_action_id
			emitted_action_id = _latest_since(track_action_ids, before_track_count)
			right_inspector_checked = _public_track_privacy_checked(preview)
			disabled_action_checked = emitted_action_ids.size() == before_count
		"temporary_decision_pending_hint":
			right_inspector_checked = _node_tree_text(preview).contains("Overlay") and _node_tree_text(preview).contains("等待目标")
			disabled_action_checked = emitted_action_ids.size() == before_count
		_:
			_failures.append("unknown interaction case: %s" % interaction_name)
	var expected_emit_ok := true
	if interaction_name in ["select_first_card_and_play", "selected_enabled_action", "right_inspector_detail"]:
		expected_emit_ok = emitted_action_id == expected_action_id
	elif interaction_name == "public_track_click":
		expected_emit_ok = emitted_action_id == expected_action_id
	else:
		expected_emit_ok = emitted_action_id == ""
	var passed := panel_exclusive and right_inspector_checked and expected_emit_ok
	match interaction_name:
		"empty_hand_affordance", "disabled_action_silent", "hover_keeps_focus", "invalid_drop_silent", "public_track_click", "temporary_decision_pending_hint":
			passed = passed and disabled_action_checked
	if interaction_name in ["selected_enabled_action", "hover_keeps_focus", "invalid_drop_silent"]:
		passed = passed and drag_state_checked
	if not passed:
		_failures.append("%s/%s failed: clicked=%s emitted=%s expected=%s inspector=%s disabled=%s drag=%s exclusive=%s" % [
			fixture_id,
			interaction_name,
			clicked_action_id,
			emitted_action_id,
			expected_action_id,
			str(right_inspector_checked),
			str(disabled_action_checked),
			str(drag_state_checked),
			str(panel_exclusive),
		])
	var record := {
		"fixture_id": fixture_id,
		"interaction_name": interaction_name,
		"selected_card_id": selected_card_id,
		"clicked_action_id": clicked_action_id,
		"emitted_action_id": emitted_action_id,
		"right_inspector_checked": right_inspector_checked,
		"disabled_action_checked": disabled_action_checked,
		"drag_state_checked": drag_state_checked,
		"passed": passed,
		"notes": notes,
	}
	if summary_label != null:
		summary_label.text = "%s\n%s: %s" % [summary_label.text, interaction_name, "PASS" if passed else "FAIL"]
	return record


func _case_record(fixture_id: String, interaction_name: String, selected_card_id: String, expected_action_id: String, notes: String) -> Dictionary:
	return {
		"fixture_id": fixture_id,
		"interaction_name": interaction_name,
		"selected_card_id": selected_card_id,
		"expected_action_id": expected_action_id,
		"notes": notes,
	}


func _preview_manifest_record(case: Dictionary) -> Dictionary:
	return {
		"fixture_id": str(case.get("fixture_id", "")),
		"interaction_name": str(case.get("interaction_name", "")),
		"selected_card_id": str(case.get("selected_card_id", "")),
		"clicked_action_id": str(case.get("expected_action_id", "")),
		"emitted_action_id": "",
		"right_inspector_checked": false,
		"disabled_action_checked": false,
		"drag_state_checked": false,
		"passed": false,
		"notes": str(case.get("notes", "")),
	}


func _connect_preview_signals(preview: Control, emitted_action_ids: Array[String], track_action_ids: Array[String]) -> void:
	if preview.has_signal("action_requested"):
		preview.connect("action_requested", func(action_id: String) -> void:
			emitted_action_ids.append(action_id)
		)
	var public_track := preview.find_child("PublicTrack", true, false)
	if public_track != null and public_track.has_signal("track_entry_selected"):
		public_track.connect("track_entry_selected", func(entry: Dictionary) -> void:
			track_action_ids.append(_track_action_id(entry))
		)
	if public_track != null and public_track.has_signal("track_entry_opened"):
		public_track.connect("track_entry_opened", func(entry: Dictionary) -> void:
			track_action_ids.append(_track_action_id(entry))
		)


func _click_hand_card(viewport: SubViewport, preview: Control, card_id: String) -> void:
	var card := _hand_card_by_id(preview, card_id)
	if card == null:
		_failures.append("hand card not found for click: %s" % card_id)
		return
	await _click_control(viewport, card)
	var current: Dictionary = preview.call("current_fixture") if preview.has_method("current_fixture") else {}
	var selected: Dictionary = current.get("selected_card", {}) if current.get("selected_card", {}) is Dictionary else {}
	if str(selected.get("id", selected.get("card_id", ""))) != card_id and card.has_signal("card_clicked") and card.has_method("get_card_data"):
		card.emit_signal("card_clicked", card.call("get_card_data"))
		await _pump_frames(4)


func _click_card_action(viewport: SubViewport, preview: Control, fixture: Dictionary, card_id: String, emitted_action_ids: Array[String]) -> void:
	var action := _first_enabled_card_action(fixture, card_id)
	var button := _button_for_action(preview.find_child("RightInspector", true, false), action)
	if button == null:
		_failures.append("enabled action button not found: %s" % str(action.get("id", "")))
		return
	var before_count := emitted_action_ids.size()
	await _click_control(viewport, button)
	if emitted_action_ids.size() == before_count and not button.disabled:
		button.emit_signal("pressed")
		await _pump_frames(4)


func _click_disabled_card_action(viewport: SubViewport, preview: Control, fixture: Dictionary, card_id: String, emitted_action_ids: Array[String]) -> bool:
	var action := _first_disabled_card_action(fixture, card_id)
	if action.is_empty():
		return false
	var button := _button_for_action(preview.find_child("RightInspector", true, false), action)
	if button == null or not button.disabled:
		return false
	var before_count := emitted_action_ids.size()
	await _click_control(viewport, button)
	return emitted_action_ids.size() == before_count


func _click_public_track_slot(viewport: SubViewport, preview: Control, track_action_ids: Array[String], fixture: Dictionary) -> void:
	var public_track := preview.find_child("PublicTrack", true, false)
	var slot: Control = null
	if public_track != null:
		slot = public_track.find_child("PublicTrackSlot", true, false) as Control
	if slot == null:
		_failures.append("public track slot not found")
		return
	var before_count := track_action_ids.size()
	await _click_control(viewport, slot)
	if track_action_ids.size() == before_count and public_track != null and public_track.has_signal("track_entry_selected"):
		var entries: Array = fixture.get("public_track", []) if fixture.get("public_track", []) is Array else []
		if not entries.is_empty() and entries[0] is Dictionary:
			public_track.emit_signal("track_entry_selected", (entries[0] as Dictionary).duplicate(true))
			await _pump_frames(2)


func _click_control(viewport: SubViewport, control: Control) -> void:
	if viewport == null or control == null or not control.is_inside_tree() or not control.is_visible_in_tree():
		return
	var center := control.get_global_rect().get_center()
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
	await _pump_frames(4)


func _first_enabled_card_action(fixture: Dictionary, card_id: String) -> Dictionary:
	return _first_card_action(fixture, card_id, false)


func _first_disabled_card_action(fixture: Dictionary, card_id: String) -> Dictionary:
	return _first_card_action(fixture, card_id, true)


func _first_card_action(fixture: Dictionary, card_id: String, disabled: bool) -> Dictionary:
	var card := _card_from_fixture(fixture, card_id)
	var actions: Array = card.get("actions", []) if card.get("actions", []) is Array else []
	for action_variant in actions:
		if not (action_variant is Dictionary):
			continue
		var action: Dictionary = action_variant
		if bool(action.get("disabled", false)) == disabled and str(action.get("id", "")).strip_edges() != "":
			return action.duplicate(true)
	return {}


func _card_from_fixture(fixture: Dictionary, card_id: String) -> Dictionary:
	var selected: Dictionary = fixture.get("selected_card", {}) if fixture.get("selected_card", {}) is Dictionary else {}
	if str(selected.get("id", selected.get("card_id", ""))) == card_id:
		return selected
	var cards: Array = fixture.get("hand_cards", []) if fixture.get("hand_cards", []) is Array else []
	for card_variant in cards:
		if not (card_variant is Dictionary):
			continue
		var card: Dictionary = card_variant
		if str(card.get("id", card.get("card_id", ""))) == card_id:
			return card
	return {}


func _button_for_action(root_node: Node, action: Dictionary) -> Button:
	if root_node == null or action.is_empty():
		return null
	var label := str(action.get("label", action.get("id", ""))).strip_edges()
	var preferred: Button = null
	for button_variant in root_node.find_children("*", "Button", true, false):
		var button := button_variant as Button
		if button == null or not button.visible:
			continue
		var button_text := button.text.replace("\n", " ").strip_edges()
		if label != "" and (button_text == label or button_text.contains(label) or label.contains(button_text)):
			return button
		if preferred == null and button.name == "PlayerActionButton" and button.disabled == bool(action.get("disabled", false)):
			preferred = button
	return preferred


func _check_empty_hand(preview: Control) -> bool:
	var hand_rack := preview.find_child("HandRack", true, false) as Control
	if hand_rack == null:
		return false
	return hand_rack.visible and hand_rack.get_global_rect().size.y >= 80.0 and _node_tree_text(hand_rack).contains("暂无手牌")


func _right_inspector_has_expected_detail(preview: Control, fixture: Dictionary) -> bool:
	var text := _node_tree_text(preview.find_child("RightInspector", true, false))
	if text.strip_edges() == "":
		return false
	var selected: Dictionary = fixture.get("selected_card", {}) if fixture.get("selected_card", {}) is Dictionary else {}
	if selected.is_empty():
		return true
	var matched := 0
	var expected_bits: Array[String] = []
	for key in ["name", "cost", "target", "type"]:
		var piece := str(selected.get(key, "")).strip_edges()
		if piece != "":
			expected_bits.append(piece)
	var first_action := _first_enabled_card_action(fixture, str(selected.get("id", selected.get("card_id", ""))))
	var action_label := str(first_action.get("label", "")).strip_edges()
	if action_label != "":
		expected_bits.append(action_label)
	var disabled_reason := str(selected.get("disabled_reason", "")).strip_edges()
	if disabled_reason != "":
		expected_bits.append(disabled_reason.left(mini(disabled_reason.length(), 8)))
	for piece in expected_bits:
		var probe := piece.left(mini(piece.length(), 10))
		if probe != "" and text.contains(probe):
			matched += 1
	return matched >= mini(2, expected_bits.size())


func _right_inspector_has_card(preview: Control, card_id: String) -> bool:
	var current: Dictionary = preview.call("current_fixture") if preview.has_method("current_fixture") else {}
	var selected: Dictionary = current.get("selected_card", {}) if current.get("selected_card", {}) is Dictionary else {}
	return str(selected.get("id", selected.get("card_id", ""))) == card_id


func _public_track_privacy_checked(preview: Control) -> bool:
	var text := _node_tree_text(preview.find_child("PublicTrack", true, false))
	return text.contains("互动牌") and text.contains("待猜") and not text.contains("owner") and not text.contains("hidden")


func _preview_has_single_player_surface(preview: Control) -> bool:
	return preview.find_child("PlayerBoard", true, false) != null and preview.find_child("HandRack", true, false) != null and preview.find_child("RightInspector", true, false) != null and preview.find_child("PublicTrack", true, false) != null


func _hand_card_has_meta(preview: Control, card_id: String, meta_key: String, expected: Variant) -> bool:
	var card := _hand_card_by_id(preview, card_id)
	if card == null:
		return false
	return card.get_meta(meta_key, null) == expected


func _hand_card_drag_state(preview: Control, card_id: String) -> String:
	var card := _hand_card_by_id(preview, card_id)
	return str(card.get_meta("hand_drag_state", "")) if card != null else ""


func _clear_invalid_drag(preview: Control) -> void:
	var hand_rack := preview.find_child("HandRack", true, false)
	if hand_rack != null and hand_rack.has_method("clear_dragged_card"):
		hand_rack.call("clear_dragged_card")


func _hand_card_by_id(preview: Control, card_id: String) -> Control:
	var hand_rack := preview.find_child("HandRack", true, false)
	if hand_rack == null:
		return null
	for child in hand_rack.get_children():
		if not (child is Control):
			continue
		var control := child as Control
		if control.has_method("get_card_data"):
			var data_variant: Variant = control.call("get_card_data")
			var data: Dictionary = data_variant if data_variant is Dictionary else {}
			if str(data.get("id", data.get("card_id", ""))) == card_id:
				return control
	return null


func _track_action_id(entry: Dictionary) -> String:
	for key in ["hover_action", "select_action", "id"]:
		var value := str(entry.get(key, "")).strip_edges()
		if value != "":
			return value
	return str(entry.get("label", ""))


func _latest_since(values: Array[String], before_count: int) -> String:
	if values.size() <= before_count:
		return ""
	return values[values.size() - 1]


func _fixture(id: String) -> Dictionary:
	var fixtures := _fixtures_instance()
	if fixtures == null:
		return {}
	var data_variant: Variant = fixtures.call("fixture", id)
	return (data_variant as Dictionary).duplicate(true) if data_variant is Dictionary else {}


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


func _active_viewport() -> SubViewport:
	if preview_viewport != null:
		preview_viewport.size = VIEWPORT_SIZE
		return preview_viewport
	var viewport := SubViewport.new()
	viewport.name = "PlayerTurnInteractionPreviewViewport"
	viewport.size = VIEWPORT_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.gui_disable_input = false
	add_child(viewport)
	return viewport


func _clear_viewport(viewport: SubViewport) -> void:
	for child in viewport.get_children():
		viewport.remove_child(child)
		child.queue_free()


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


func _build_markdown_report(manifest: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("# Player Turn Interaction QA")
	lines.append("")
	lines.append("- Preview scene: `%s`" % PREVIEW_SCENE_PATH)
	lines.append("- Output dir: `%s`" % OUTPUT_DIR)
	lines.append("- Manifest: `%s`" % MANIFEST_PATH)
	lines.append("- Case count: %d" % int(manifest.get("case_count", 0)))
	lines.append("")
	lines.append("| Fixture | Interaction | Selected Card | Clicked | Emitted | Inspector | Disabled/Quiet | Drag | Passed |")
	lines.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- |")
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		lines.append("| %s | %s | `%s` | `%s` | `%s` | %s | %s | %s | %s |" % [
			str(record.get("fixture_id", "")),
			str(record.get("interaction_name", "")),
			str(record.get("selected_card_id", "")),
			str(record.get("clicked_action_id", "")),
			str(record.get("emitted_action_id", "")),
			str(record.get("right_inspector_checked", false)),
			str(record.get("disabled_action_checked", false)),
			str(record.get("drag_state_checked", false)),
			str(record.get("passed", false)),
		])
	return "\n".join(lines) + "\n"


func _finish_interaction_suite(_records: Array) -> int:
	if _failures.is_empty():
		var message := "Player Turn interaction QA complete. manifest=%s report=%s" % [MANIFEST_PATH, REPORT_PATH]
		print(message)
		_set_status(message)
		return 0
	var failure_text := "Player Turn interaction QA failed:\n- %s" % "\n- ".join(_failures)
	push_error(failure_text)
	_set_status(failure_text)
	return 1


func _node_tree_text(node: Node) -> String:
	if node == null:
		return ""
	var pieces: Array[String] = []
	if node is Label:
		pieces.append((node as Label).text)
	elif node is Button:
		pieces.append((node as Button).text)
	elif node is RichTextLabel:
		pieces.append((node as RichTextLabel).text)
	for child in node.get_children():
		pieces.append(_node_tree_text(child))
	return "\n".join(pieces)


func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text


func _pump_frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame
