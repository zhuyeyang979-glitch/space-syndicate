extends Control
class_name FirstPlayableLoopBench

const GAME_SCREEN_SCENE_PATH := "res://scenes/ui/GameScreen.tscn"
const FIRST_PLAYABLE_FIXTURE_SCRIPT_PATH := "res://scripts/tools/first_playable_loop_fixtures.gd"
const OUTPUT_DIR := "user://space_syndicate_design_qa/first_playable_loop/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/first_playable_loop_sprint_1.png"
const VIEWPORT_SIZE := Vector2i(1600, 960)

@export var auto_run_on_ready := true
@export var quit_when_complete := true
@export_range(0.0, 20.0, 0.5) var quit_delay_seconds := 8.0

@onready var status_label: Label = %FirstPlayableLoopStatusLabel
@onready var summary_label: Label = %FirstPlayableLoopSummaryLabel
@onready var preview_viewport: SubViewport = %FirstPlayableLoopPreviewViewport

var _fixtures: RefCounted = null
var _failures: Array[String] = []


func _ready() -> void:
	if preview_viewport != null:
		preview_viewport.size = VIEWPORT_SIZE
		preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		preview_viewport.gui_disable_input = false
	if auto_run_on_ready:
		call_deferred("_run_loop_suite_and_maybe_quit")


func output_dir() -> String:
	return OUTPUT_DIR


func loop_steps() -> Array:
	var fixtures := _fixtures_instance()
	if fixtures == null or not fixtures.has_method("loop_steps"):
		return []
	var value: Variant = fixtures.call("loop_steps")
	return value if value is Array else []


func build_loop_manifest_preview() -> Dictionary:
	var records: Array = []
	for step_variant in loop_steps():
		var step_data: Dictionary = step_variant if step_variant is Dictionary else {}
		records.append(_preview_manifest_record(step_data))
	return {
		"version": "first-playable-loop-v1",
		"output_dir": OUTPUT_DIR,
		"game_screen_scene": GAME_SCREEN_SCENE_PATH,
		"case_count": records.size(),
		"records": records,
	}


func run_loop_suite() -> void:
	await _run_loop_suite_internal()


func _run_loop_suite_and_maybe_quit() -> void:
	var exit_code := await _run_loop_suite_internal()
	if quit_when_complete and get_tree() != null:
		if quit_delay_seconds > 0.0:
			await get_tree().create_timer(quit_delay_seconds).timeout
		get_tree().quit(exit_code)


func _run_loop_suite_internal() -> int:
	_failures.clear()
	_set_status("Preparing First Playable Loop bench...")
	if not _prepare_output_dir():
		return _finish_loop_suite([])
	var packed := load(GAME_SCREEN_SCENE_PATH) as PackedScene
	if packed == null:
		_failures.append("GameScreen scene could not load: %s" % GAME_SCREEN_SCENE_PATH)
		return _finish_loop_suite([])
	var viewport := _active_viewport()
	_clear_viewport(viewport)
	var screen := packed.instantiate() as Control
	if screen == null:
		_failures.append("GameScreen root was not Control")
		return _finish_loop_suite([])
	screen.name = "FirstPlayableLoopGameScreen"
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(screen)
	await _pump_frames(8)
	var emitted_action_ids: Array[String] = []
	var emitted_end_turns: Array[String] = []
	var overlay_action_ids: Array[String] = []
	_connect_game_screen_signals(screen, emitted_action_ids, emitted_end_turns, overlay_action_ids)
	var records: Array = []
	for step_variant in loop_steps():
		var step_data: Dictionary = step_variant if step_variant is Dictionary else {}
		var record := await _run_step(viewport, screen, step_data, emitted_action_ids, emitted_end_turns, overlay_action_ids)
		records.append(record)
	_save_viewport_screenshot(viewport, SCREENSHOT_PATH)
	var manifest := {
		"version": "first-playable-loop-v1",
		"output_dir": OUTPUT_DIR,
		"game_screen_scene": GAME_SCREEN_SCENE_PATH,
		"screenshot_path": SCREENSHOT_PATH,
		"case_count": records.size(),
		"records": records,
	}
	_write_text_file(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text_file(REPORT_PATH, _build_markdown_report(manifest))
	return _finish_loop_suite(records)


func _run_step(viewport: SubViewport, screen: Control, step_data: Dictionary, emitted_action_ids: Array[String], emitted_end_turns: Array[String], overlay_action_ids: Array[String]) -> Dictionary:
	var step_id := str(step_data.get("step_id", ""))
	var fixture_id := str(step_data.get("fixture_id", ""))
	var expected_surface := str(step_data.get("expected_surface", ""))
	var expected_action_id := str(step_data.get("expected_action_id", ""))
	_set_status("Running first playable step: %s..." % step_id)
	var table_state := _table_state_for_step(step_id)
	if screen.has_method("apply_state"):
		screen.call("apply_state", table_state)
	await _pump_frames(10)
	var fixture := _player_fixture(fixture_id)
	var selected_card_id := str(fixture.get("selected_card_id", ""))
	if selected_card_id == "" and fixture.get("selected_card", {}) is Dictionary:
		selected_card_id = str((fixture.get("selected_card", {}) as Dictionary).get("id", ""))
	var before_action_count := emitted_action_ids.size()
	var before_end_turn_count := emitted_end_turns.size()
	var before_overlay_count := overlay_action_ids.size()
	var clicked_action_id := ""
	var emitted_action_id := ""
	var right_inspector_checked := _right_inspector_has_expected_detail(screen, fixture)
	var player_feedback_checked := true
	var overlay_checked := _overlay_idle_or_visible(screen)
	var privacy_checked := _privacy_surface_safe(screen)
	match step_id:
		"boot_to_player_turn":
			right_inspector_checked = _core_surface_present(screen) and _top_bar_mentions_player_turn(screen) and _hand_has_cards(screen)
			player_feedback_checked = _player_board_readable(screen)
			overlay_checked = _overlay_node_present(screen)
		"inspect_first_card":
			selected_card_id = str(step_data.get("selected_card_id", "card_orbital_finance"))
			await _click_hand_card(viewport, screen, selected_card_id)
			await _pump_frames(6)
			right_inspector_checked = _right_inspector_has_card(screen, selected_card_id)
			player_feedback_checked = _selected_card_visual_stable(screen, selected_card_id)
		"execute_enabled_action":
			await _click_hand_card(viewport, screen, selected_card_id)
			await _pump_frames(4)
			clicked_action_id = expected_action_id
			await _click_card_action(viewport, screen, fixture, selected_card_id, false, emitted_action_ids)
			emitted_action_id = _latest_since(emitted_action_ids, before_action_count)
			right_inspector_checked = _right_inspector_has_card(screen, selected_card_id)
			player_feedback_checked = _player_feedback_contains(screen, expected_action_id, "action")
		"disabled_action_guard":
			await _click_hand_card(viewport, screen, selected_card_id)
			await _pump_frames(4)
			clicked_action_id = expected_action_id
			var guarded := await _click_card_action(viewport, screen, fixture, selected_card_id, true, emitted_action_ids)
			emitted_action_id = _latest_since(emitted_action_ids, before_action_count)
			right_inspector_checked = _right_inspector_has_card(screen, selected_card_id) and _disabled_reason_visible(screen, fixture)
			player_feedback_checked = guarded and emitted_action_id == ""
		"public_track_safe_read":
			clicked_action_id = expected_action_id
			await _click_public_track_slot(viewport, screen)
			emitted_action_id = _latest_since(emitted_action_ids, before_action_count)
			right_inspector_checked = _node_tree_text(screen.find_child("RightInspector", true, false)).contains("匿名合约")
			player_feedback_checked = _player_feedback_contains(screen, expected_action_id, "action")
		"temporary_decision_roundtrip":
			overlay_checked = _temporary_decision_overlay_visible(screen)
			player_feedback_checked = _temporary_decision_feedback_visible(screen)
			clicked_action_id = expected_action_id
			await _click_temporary_decision_action(viewport, screen, expected_action_id)
			emitted_action_id = _latest_since(emitted_action_ids, before_action_count)
			var overlay_emitted := _latest_since(overlay_action_ids, before_overlay_count)
			right_inspector_checked = true
			overlay_checked = overlay_checked and overlay_emitted == expected_action_id
			player_feedback_checked = player_feedback_checked and _player_feedback_contains(screen, expected_action_id, "action")
		"end_turn_feedback":
			clicked_action_id = "end_turn"
			await _click_end_turn(viewport, screen)
			emitted_action_id = _latest_since(emitted_end_turns, before_end_turn_count)
			right_inspector_checked = _top_bar_mentions_player_turn(screen)
			player_feedback_checked = _player_feedback_contains(screen, "end_turn", "action")
			overlay_checked = _overlay_node_present(screen)
		_:
			_failures.append("unknown playable loop step: %s" % step_id)
	var emit_ok := true
	match step_id:
		"execute_enabled_action", "public_track_safe_read", "temporary_decision_roundtrip":
			emit_ok = emitted_action_id == expected_action_id
		"disabled_action_guard":
			emit_ok = emitted_action_id == ""
		"end_turn_feedback":
			emit_ok = emitted_action_id == "end_turn_requested"
		_:
			emit_ok = true
	var passed := right_inspector_checked and player_feedback_checked and overlay_checked and privacy_checked and emit_ok
	if not passed:
		_failures.append("%s failed: fixture=%s clicked=%s emitted=%s expected=%s inspector=%s feedback=%s overlay=%s privacy=%s" % [
			step_id,
			fixture_id,
			clicked_action_id,
			emitted_action_id,
			expected_action_id,
			str(right_inspector_checked),
			str(player_feedback_checked),
			str(overlay_checked),
			str(privacy_checked),
		])
	var record := {
		"step_id": step_id,
		"fixture_id": fixture_id,
		"expected_surface": expected_surface,
		"clicked_action_id": clicked_action_id,
		"emitted_action_id": emitted_action_id,
		"right_inspector_checked": right_inspector_checked,
		"player_feedback_checked": player_feedback_checked,
		"overlay_checked": overlay_checked,
		"privacy_checked": privacy_checked,
		"passed": passed,
		"notes": str(step_data.get("notes", "")),
	}
	if summary_label != null:
		summary_label.text = "%s\n%s: %s" % [summary_label.text, step_id, "PASS" if passed else "FAIL"]
	return record


func _preview_manifest_record(step_data: Dictionary) -> Dictionary:
	return {
		"step_id": str(step_data.get("step_id", "")),
		"fixture_id": str(step_data.get("fixture_id", "")),
		"expected_surface": str(step_data.get("expected_surface", "")),
		"clicked_action_id": str(step_data.get("expected_action_id", "")),
		"emitted_action_id": "",
		"right_inspector_checked": false,
		"player_feedback_checked": false,
		"overlay_checked": false,
		"privacy_checked": false,
		"passed": false,
		"notes": str(step_data.get("notes", "")),
	}


func _connect_game_screen_signals(screen: Control, emitted_action_ids: Array[String], emitted_end_turns: Array[String], overlay_action_ids: Array[String]) -> void:
	if screen.has_signal("action_requested"):
		screen.connect("action_requested", func(action_id: String) -> void:
			emitted_action_ids.append(action_id)
		)
	if screen.has_signal("end_turn_requested"):
		screen.connect("end_turn_requested", func() -> void:
			emitted_end_turns.append("end_turn_requested")
		)
	var overlay := screen.find_child("OverlayLayer", true, false)
	if overlay != null and overlay.has_signal("temporary_decision_action_requested"):
		overlay.connect("temporary_decision_action_requested", func(action_id: String) -> void:
			overlay_action_ids.append(action_id)
		)


func _table_state_for_step(step_id: String) -> Dictionary:
	var fixtures := _fixtures_instance()
	if fixtures == null or not fixtures.has_method("table_state_for_step"):
		return {}
	var value: Variant = fixtures.call("table_state_for_step", step_id)
	return value.duplicate(true) if value is Dictionary else {}


func _player_fixture(fixture_id: String) -> Dictionary:
	var fixtures := _fixtures_instance()
	if fixtures == null or not fixtures.has_method("player_fixture"):
		return {}
	var value: Variant = fixtures.call("player_fixture", fixture_id)
	return value.duplicate(true) if value is Dictionary else {}


func _click_hand_card(viewport: SubViewport, screen: Control, card_id: String) -> void:
	var card := _hand_card_by_id(screen, card_id)
	if card == null:
		_failures.append("hand card not found: %s" % card_id)
		return
	await _click_control(viewport, card)
	var selected_snapshot: Dictionary = screen.call("get_runtime_player_feedback_snapshot") if screen.has_method("get_runtime_player_feedback_snapshot") else {}
	if card.has_signal("card_clicked") and card.has_method("get_card_data") and str(selected_snapshot.get("action_id", "")) == "":
		card.emit_signal("card_clicked", card.call("get_card_data"))
		await _pump_frames(4)


func _click_card_action(viewport: SubViewport, screen: Control, fixture: Dictionary, card_id: String, disabled: bool, emitted_action_ids: Array[String]) -> bool:
	var action := _first_card_action(fixture, card_id, disabled)
	if action.is_empty():
		return false
	var button := _button_for_action(screen.find_child("RightInspector", true, false), action)
	if button == null:
		_failures.append("action button not found: %s" % str(action.get("id", "")))
		return false
	var before_count := emitted_action_ids.size()
	await _click_control(viewport, button)
	if not disabled and emitted_action_ids.size() == before_count and not button.disabled:
		button.emit_signal("pressed")
		await _pump_frames(4)
	if disabled:
		return button.disabled and emitted_action_ids.size() == before_count and _disabled_reason_visible(screen, fixture)
	return emitted_action_ids.size() > before_count


func _click_public_track_slot(viewport: SubViewport, screen: Control) -> void:
	var public_track := screen.find_child("PublicTrack", true, false)
	var slot: Control = null
	if public_track != null:
		slot = public_track.find_child("PublicTrackSlot", true, false) as Control
	if slot == null:
		_failures.append("public track slot not found")
		return
	await _click_control(viewport, slot)


func _click_temporary_decision_action(viewport: SubViewport, screen: Control, action_id: String) -> void:
	var action := _temporary_decision_action(action_id)
	var overlay := screen.find_child("OverlayLayer", true, false)
	var button := _button_for_action(overlay, action)
	if button == null:
		_failures.append("temporary decision action button not found: %s" % action_id)
		return
	await _click_control(viewport, button)
	if not button.disabled:
		button.emit_signal("pressed")
		await _pump_frames(4)


func _click_end_turn(viewport: SubViewport, screen: Control) -> void:
	var button := screen.find_child("EndTurnButton", true, false) as Button
	if button == null:
		_failures.append("EndTurnButton not found")
		return
	await _click_control(viewport, button)
	if not button.disabled:
		button.emit_signal("pressed")
		await _pump_frames(4)


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


func _core_surface_present(screen: Control) -> bool:
	for node_name in ["TopBar", "PlayerBoard", "HandRack", "RightInspector", "PublicTrack", "PlanetBoard", "OverlayLayer"]:
		if screen.find_child(node_name, true, false) == null:
			return false
	return true


func _top_bar_mentions_player_turn(screen: Control) -> bool:
	var text := _node_tree_text(screen.find_child("TopBar", true, false))
	return text.contains("玩家回合") or text.contains("第一轮") or text.contains("结束回合")


func _player_board_readable(screen: Control) -> bool:
	var text := _node_tree_text(screen.find_child("PlayerBoard", true, false))
	return text.contains("手牌") and text.contains("目标") and text.contains("下一步")


func _hand_has_cards(screen: Control) -> bool:
	var hand_rack := screen.find_child("HandRack", true, false)
	if hand_rack == null:
		return false
	for child in hand_rack.get_children():
		if child is Control and (child as Control).has_method("get_card_data"):
			return true
	return false


func _overlay_node_present(screen: Control) -> bool:
	return screen.find_child("OverlayLayer", true, false) != null


func _overlay_idle_or_visible(screen: Control) -> bool:
	var overlay := screen.find_child("OverlayLayer", true, false)
	return overlay != null


func _temporary_decision_overlay_visible(screen: Control) -> bool:
	var overlay := screen.find_child("OverlayLayer", true, false)
	if overlay == null:
		return false
	var text := _node_tree_text(overlay)
	var panel := screen.find_child("TemporaryChoiceDecisionPanel", true, false) as Control
	return panel != null and panel.visible and text.contains("选择合约目标")


func _temporary_decision_feedback_visible(screen: Control) -> bool:
	var feedback := _runtime_feedback(screen)
	var board_feedback := _player_board_feedback(screen)
	var text := str(feedback.get("label", "")) + "\n" + str(feedback.get("detail", ""))
	return text.contains("等待决策") and str(board_feedback.get("kind", "")) == "temporary_decision"


func _player_feedback_contains(screen: Control, action_id: String, kind: String) -> bool:
	var feedback := _runtime_feedback(screen)
	var board_feedback := _player_board_feedback(screen)
	return str(feedback.get("kind", "")) == kind and str(feedback.get("action_id", "")).contains(action_id) and str(board_feedback.get("action_id", "")).contains(action_id)


func _runtime_feedback(screen: Control) -> Dictionary:
	if screen != null and screen.has_method("get_runtime_player_feedback_snapshot"):
		var value: Variant = screen.call("get_runtime_player_feedback_snapshot")
		return value if value is Dictionary else {}
	return {}


func _player_board_feedback(screen: Control) -> Dictionary:
	var board := screen.find_child("PlayerBoard", true, false)
	if board != null and board.has_method("get_runtime_feedback_snapshot"):
		var value: Variant = board.call("get_runtime_feedback_snapshot")
		return value if value is Dictionary else {}
	return {}


func _right_inspector_has_expected_detail(screen: Control, fixture: Dictionary) -> bool:
	var selected: Dictionary = fixture.get("selected_card", {}) if fixture.get("selected_card", {}) is Dictionary else {}
	if selected.is_empty():
		return true
	return _right_inspector_text_matches(screen, selected)


func _right_inspector_has_card(screen: Control, card_id: String) -> bool:
	var card := _hand_card_by_id(screen, card_id)
	if card == null or not card.has_method("get_card_data"):
		return false
	var value: Variant = card.call("get_card_data")
	var card_data: Dictionary = value if value is Dictionary else {}
	return _right_inspector_text_matches(screen, card_data)


func _right_inspector_text_matches(screen: Control, card_data: Dictionary) -> bool:
	var text := _node_tree_text(screen.find_child("RightInspector", true, false))
	var matched := 0
	for key in ["name", "target", "type"]:
		var value := str(card_data.get(key, "")).strip_edges()
		if value != "" and text.contains(value.left(mini(value.length(), 8))):
			matched += 1
	var action := _first_card_action({"hand_cards": [card_data], "selected_card": card_data}, str(card_data.get("id", "")), false)
	var action_label := str(action.get("label", "")).strip_edges()
	if action_label != "" and text.contains(action_label.left(mini(action_label.length(), 8))):
		matched += 1
	var disabled_reason := str(card_data.get("disabled_reason", "")).strip_edges()
	if disabled_reason != "" and text.contains(disabled_reason.left(mini(disabled_reason.length(), 8))):
		matched += 1
	return matched >= 2


func _selected_card_visual_stable(screen: Control, card_id: String) -> bool:
	var hand_rack := screen.find_child("HandRack", true, false)
	if hand_rack == null or not hand_rack.has_method("get_selected_card"):
		return false
	var selected: Variant = hand_rack.call("get_selected_card")
	if not (selected is Control):
		return false
	var control := selected as Control
	if not control.has_method("get_card_data"):
		return false
	var value: Variant = control.call("get_card_data")
	var data: Dictionary = value if value is Dictionary else {}
	return str(data.get("id", data.get("card_id", ""))) == card_id


func _disabled_reason_visible(screen: Control, fixture: Dictionary) -> bool:
	var selected: Dictionary = fixture.get("selected_card", {}) if fixture.get("selected_card", {}) is Dictionary else {}
	var reason := str(selected.get("disabled_reason", fixture.get("disabled_reason", ""))).strip_edges()
	if reason == "":
		return true
	return _node_tree_text(screen).contains(reason.left(mini(reason.length(), 10)))


func _privacy_surface_safe(screen: Control) -> bool:
	var text := _node_tree_text(screen)
	for forbidden in ["hidden", "owner", "player_index", "secret_owner", "private_owner"]:
		if text.contains(forbidden):
			return false
	return true


func _hand_card_by_id(screen: Control, card_id: String) -> Control:
	var hand_rack := screen.find_child("HandRack", true, false)
	if hand_rack == null:
		return null
	for child in hand_rack.get_children():
		if not (child is Control):
			continue
		var control := child as Control
		if control.has_method("get_card_data"):
			var value: Variant = control.call("get_card_data")
			var data: Dictionary = value if value is Dictionary else {}
			if str(data.get("id", data.get("card_id", ""))) == card_id:
				return control
	return null


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
		if preferred == null and button.disabled == bool(action.get("disabled", false)):
			preferred = button
	return preferred


func _temporary_decision_action(action_id: String) -> Dictionary:
	var fixtures := _fixtures_instance()
	if fixtures != null and fixtures.has_method("temporary_decision_payload"):
		var payload_value: Variant = fixtures.call("temporary_decision_payload")
		var payload: Dictionary = payload_value if payload_value is Dictionary else {}
		var actions: Array = payload.get("actions", []) if payload.get("actions", []) is Array else []
		for action_variant in actions:
			if action_variant is Dictionary and str((action_variant as Dictionary).get("id", "")) == action_id:
				return (action_variant as Dictionary).duplicate(true)
	return {"id": action_id, "label": action_id, "disabled": false}


func _latest_since(values: Array[String], before_count: int) -> String:
	if values.size() <= before_count:
		return ""
	return values[values.size() - 1]


func _fixtures_instance() -> RefCounted:
	if _fixtures != null:
		return _fixtures
	var script := load(FIRST_PLAYABLE_FIXTURE_SCRIPT_PATH)
	if script == null:
		return null
	var instance: Variant = script.new()
	if instance is RefCounted:
		_fixtures = instance
	return _fixtures


func _active_viewport() -> SubViewport:
	if preview_viewport != null:
		preview_viewport.size = VIEWPORT_SIZE
		return preview_viewport
	var viewport := SubViewport.new()
	viewport.name = "FirstPlayableLoopPreviewViewport"
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


func _save_viewport_screenshot(viewport: SubViewport, path: String) -> void:
	if viewport == null:
		return
	var absolute_path := ProjectSettings.globalize_path(path)
	var dir := absolute_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var image: Image = null
	if DisplayServer.get_name().to_lower() == "headless":
		image = Image.create_empty(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, false, Image.FORMAT_RGBA8)
		image.fill(Color("#020617"))
	else:
		image = viewport.get_texture().get_image()
	if image == null:
		return
	var err := image.save_png(absolute_path)
	if err != OK:
		_failures.append("failed to save screenshot %s: %s" % [path, str(err)])


func _write_text_file(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures.append("failed to write %s: %s" % [path, str(FileAccess.get_open_error())])
		return
	file.store_string(text)


func _build_markdown_report(manifest: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("# First Playable Loop QA")
	lines.append("")
	lines.append("- GameScreen scene: `%s`" % GAME_SCREEN_SCENE_PATH)
	lines.append("- Output dir: `%s`" % OUTPUT_DIR)
	lines.append("- Manifest: `%s`" % MANIFEST_PATH)
	lines.append("- Screenshot: `%s`" % SCREENSHOT_PATH)
	lines.append("- Case count: %d" % int(manifest.get("case_count", 0)))
	lines.append("")
	lines.append("| Step | Fixture | Surface | Clicked | Emitted | Inspector | Feedback | Overlay | Privacy | Passed |")
	lines.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		lines.append("| %s | %s | %s | `%s` | `%s` | %s | %s | %s | %s | %s |" % [
			str(record.get("step_id", "")),
			str(record.get("fixture_id", "")),
			str(record.get("expected_surface", "")),
			str(record.get("clicked_action_id", "")),
			str(record.get("emitted_action_id", "")),
			str(record.get("right_inspector_checked", false)),
			str(record.get("player_feedback_checked", false)),
			str(record.get("overlay_checked", false)),
			str(record.get("privacy_checked", false)),
			str(record.get("passed", false)),
		])
	return "\n".join(lines) + "\n"


func _finish_loop_suite(_records: Array) -> int:
	if _failures.is_empty():
		var message := "First Playable Loop QA complete. manifest=%s report=%s screenshot=%s" % [MANIFEST_PATH, REPORT_PATH, SCREENSHOT_PATH]
		print(message)
		_set_status(message)
		return 0
	var failure_text := "First Playable Loop QA failed:\n- %s" % "\n- ".join(_failures)
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
