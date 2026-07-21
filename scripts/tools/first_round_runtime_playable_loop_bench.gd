extends Control
class_name FirstRoundRuntimePlayableLoopBench

const GAME_SCREEN_SCENE_PATH := "res://scenes/ui/GameScreen.tscn"
const FIXTURE_SCRIPT_PATH := "res://scripts/tools/first_round_runtime_playable_loop_fixtures.gd"
const OUTPUT_DIR := "user://space_syndicate_design_qa/first_round_runtime_playable_loop/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/first_round_runtime_playable_loop_sprint_1.png"
const VIEWPORT_SIZE := Vector2i(1600, 960)
const PRIVATE_TOKENS := ["hidden_owner", "private_owner", "private_target", "private_discard", "owner_secret", "secret_owner", "player_index"]

@export var auto_run_on_ready := true
@export var quit_when_complete := true
@export_range(0.0, 20.0, 0.5) var quit_delay_seconds := 8.0

@onready var status_label: Label = %FirstRoundRuntimePlayableLoopStatusLabel
@onready var summary_label: Label = %FirstRoundRuntimePlayableLoopSummaryLabel
@onready var preview_viewport: SubViewport = %FirstRoundRuntimePlayableLoopPreviewViewport

var _fixtures: RefCounted = null
var _failures: Array[String] = []
var _emitted_action_ids: Array[String] = []
var _end_turn_ids: Array[String] = []
var _overlay_action_ids: Array[String] = []
var _track_action_ids: Array[String] = []
var _district_selected_indices: Array[int] = []
var _district_double_clicked_indices: Array[int] = []
var _connected_screen: Node = null
var _connected_track: Node = null
var _connected_overlay: Node = null
var _connected_map: Node = null


func _ready() -> void:
	if preview_viewport != null:
		preview_viewport.size = VIEWPORT_SIZE
		preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		preview_viewport.gui_disable_input = false
	if auto_run_on_ready:
		call_deferred("_run_flow_suite_and_maybe_quit")


func output_dir() -> String:
	return OUTPUT_DIR


func screenshot_path() -> String:
	return SCREENSHOT_PATH


func flow_cases() -> Array:
	var fixtures := _fixtures_instance()
	if fixtures == null or not fixtures.has_method("cases"):
		return []
	var value: Variant = fixtures.call("cases")
	return (value as Array).duplicate(true) if value is Array else []


func build_flow_manifest_preview() -> Dictionary:
	var records: Array = []
	for flow_case_variant in flow_cases():
		var flow_case: Dictionary = flow_case_variant if flow_case_variant is Dictionary else {}
		records.append(_preview_record(flow_case))
	return {
		"version": "first-round-runtime-playable-loop-v1",
		"output_dir": OUTPUT_DIR,
		"game_screen_scene": GAME_SCREEN_SCENE_PATH,
		"screenshot_path": SCREENSHOT_PATH,
		"case_count": records.size(),
		"records": records,
	}


func run_flow_suite() -> void:
	await _run_flow_suite_internal()


func _run_flow_suite_and_maybe_quit() -> void:
	var exit_code := await _run_flow_suite_internal()
	if quit_when_complete and get_tree() != null:
		if quit_delay_seconds > 0.0:
			await get_tree().create_timer(quit_delay_seconds).timeout
		get_tree().quit(exit_code)


func _run_flow_suite_internal() -> int:
	_failures.clear()
	_set_status("Preparing First Round Runtime Playable Loop bench...")
	if not _prepare_output_dir():
		return _finish_flow_suite([])
	var packed := load(GAME_SCREEN_SCENE_PATH) as PackedScene
	if packed == null:
		_failures.append("GameScreen scene could not load: %s" % GAME_SCREEN_SCENE_PATH)
		return _finish_flow_suite([])
	var viewport := _active_viewport()
	_clear_viewport(viewport)
	var screen := packed.instantiate() as Control
	if screen == null:
		_failures.append("GameScreen root was not Control.")
		return _finish_flow_suite([])
	screen.name = "FirstRoundRuntimePlayableLoopGameScreen"
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(screen)
	await _pump_frames(8)
	_connect_game_screen_signals(screen)
	var records: Array = []
	for flow_case_variant in flow_cases():
		var flow_case: Dictionary = flow_case_variant if flow_case_variant is Dictionary else {}
		var record := await _run_case(viewport, screen, flow_case)
		records.append(record)
	_save_viewport_screenshot(viewport, SCREENSHOT_PATH)
	var manifest := {
		"version": "first-round-runtime-playable-loop-v1",
		"output_dir": OUTPUT_DIR,
		"game_screen_scene": GAME_SCREEN_SCENE_PATH,
		"screenshot_path": SCREENSHOT_PATH,
		"case_count": records.size(),
		"passed_count": _passed_count(records),
		"records": records,
	}
	_write_text_file(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text_file(REPORT_PATH, _build_markdown_report(manifest))
	return _finish_flow_suite(records)


func _run_case(viewport: SubViewport, screen: Control, flow_case: Dictionary) -> Dictionary:
	var case_id := str(flow_case.get("case_id", ""))
	var fixture_id := str(flow_case.get("fixture_id", ""))
	var interaction := str(flow_case.get("interaction", ""))
	var selected_card_id := str(flow_case.get("selected_card_id", ""))
	var expected_action_id := str(flow_case.get("expected_action_id", ""))
	var expected_text := str(flow_case.get("expected_inspector_text", ""))
	_set_status("Running first-round case: %s / %s..." % [case_id, interaction])
	var table_state := _table_state_for_case(flow_case)
	if screen.has_method("apply_state"):
		screen.call("apply_state", table_state)
	await _pump_frames(8)
	_apply_map_payload(screen, _map_payload_for_case(flow_case))
	await _pump_frames(8)
	var track := _public_track(screen)
	var overlay := _overlay_layer(screen)
	var map_view := _map_view(screen)
	_connect_track_signals(track)
	_connect_overlay_signals(overlay)
	_connect_map_signals(map_view)
	_clear_observed_case_signals()
	var clicked_action_id := expected_action_id
	var emitted_action_id := ""
	var selected_card_checked := _selected_card_ok_for_case(screen, selected_card_id, interaction)
	var inspector_checked := _inspector_contains(screen, expected_text)
	var player_board_feedback_checked := _player_board_readable(screen)
	var public_track_checked := _public_track_base_checked(track)
	var planet_map_checked := _planet_map_base_checked(map_view)
	var overlay_checked := _overlay_base_checked(overlay)
	var privacy_checked := _privacy_checked(screen, table_state, flow_case)
	match interaction:
		"boot":
			clicked_action_id = ""
			selected_card_checked = _hand_has_cards(screen)
			inspector_checked = _core_surface_present(screen) and _top_bar_mentions_first_turn(screen)
			player_board_feedback_checked = _player_board_readable(screen)
			public_track_checked = _public_track_base_checked(track)
			planet_map_checked = _planet_map_base_checked(map_view)
			overlay_checked = overlay != null
		"inspect_card":
			clicked_action_id = ""
			await _click_hand_card(viewport, screen, selected_card_id)
			await _pump_frames(6)
			selected_card_checked = _selected_card_visual_stable(screen, selected_card_id)
			inspector_checked = _right_inspector_has_card(screen, selected_card_id)
			player_board_feedback_checked = selected_card_checked and _node_tree_text(screen.find_child("PlayerBoard", true, false)).contains("手牌")
		"execute_card_action":
			await _click_hand_card(viewport, screen, selected_card_id)
			await _pump_frames(4)
			clicked_action_id = expected_action_id
			_click_card_action(screen, selected_card_id, expected_action_id, false)
			await _pump_frames(6)
			emitted_action_id = _latest_string(_emitted_action_ids)
			selected_card_checked = _selected_card_visual_stable(screen, selected_card_id)
			inspector_checked = _right_inspector_has_card(screen, selected_card_id)
			player_board_feedback_checked = _player_feedback_contains(screen, expected_action_id)
		"disabled_action_guard":
			await _click_hand_card(viewport, screen, selected_card_id)
			await _pump_frames(4)
			clicked_action_id = expected_action_id
			var before_disabled_count := _emitted_action_ids.size()
			var disabled_guarded := _click_card_action(screen, selected_card_id, expected_action_id, true)
			await _pump_frames(4)
			emitted_action_id = _latest_since(_emitted_action_ids, before_disabled_count)
			selected_card_checked = _selected_card_visual_stable(screen, selected_card_id)
			inspector_checked = _inspector_contains(screen, expected_text)
			player_board_feedback_checked = disabled_guarded and emitted_action_id == ""
		"public_track_response":
			_press_public_track_slot(track, "first_round_track_contract", false)
			await _pump_frames(5)
			var before_track_count := _emitted_action_ids.size()
			clicked_action_id = _press_response_action(track, expected_action_id)
			await _pump_frames(5)
			emitted_action_id = _latest_since(_emitted_action_ids, before_track_count)
			inspector_checked = _inspector_contains(screen, "匿名合约")
			player_board_feedback_checked = _player_feedback_contains(screen, expected_action_id)
			public_track_checked = _public_track_response_checked(track)
		"planet_map_action":
			clicked_action_id = ""
			var district_click_ok := await _click_map_district(map_view, 1, false)
			var district_double_ok := await _click_map_district(map_view, 1, true)
			if map_view != null and map_view.has_method("focus_district"):
				map_view.call("focus_district", 1)
			await _pump_frames(8)
			planet_map_checked = district_click_ok and district_double_ok and _planet_map_focus_checked(map_view, 1)
			inspector_checked = _inspector_contains(screen, "影子合约") or _inspector_contains(screen, expected_text)
		"temporary_decision":
			overlay_checked = _temporary_overlay_visible(screen)
			player_board_feedback_checked = _temporary_feedback_visible(screen)
			clicked_action_id = expected_action_id
			_click_temporary_decision_action(screen, expected_action_id)
			await _pump_frames(6)
			emitted_action_id = _latest_string(_emitted_action_ids)
			overlay_checked = overlay_checked and _latest_string(_overlay_action_ids) == expected_action_id
			_hide_overlay(overlay)
			await _pump_frames(2)
			overlay_checked = overlay_checked and _overlay_hidden(screen)
			player_board_feedback_checked = player_board_feedback_checked and _player_feedback_contains(screen, expected_action_id)
		"end_turn":
			clicked_action_id = "end_turn"
			_click_end_turn(screen)
			await _pump_frames(6)
			emitted_action_id = _latest_string(_end_turn_ids)
			player_board_feedback_checked = emitted_action_id == "end_turn_requested"
			inspector_checked = _top_bar_mentions_first_turn(screen)
		"privacy_boundary":
			clicked_action_id = ""
			privacy_checked = _privacy_checked(screen, table_state, flow_case)
			inspector_checked = _inspector_contains(screen, expected_text)
			public_track_checked = _public_track_base_checked(track)
		"recovery_sequence":
			await _click_hand_card(viewport, screen, selected_card_id)
			await _pump_frames(4)
			_press_public_track_slot(track, "first_round_track_contract", false)
			await _pump_frames(3)
			if map_view != null and map_view.has_method("focus_district"):
				map_view.call("focus_district", 1)
			await _pump_frames(3)
			_click_temporary_decision_action(screen, "first_round:temporary:choose_player_1")
			await _pump_frames(4)
			_hide_overlay(overlay)
			await _pump_frames(2)
			_click_end_turn(screen)
			await _pump_frames(5)
			clicked_action_id = "end_turn"
			emitted_action_id = _latest_string(_end_turn_ids)
			selected_card_checked = _selected_card_visual_stable(screen, selected_card_id)
			inspector_checked = _node_tree_text(screen.find_child("RightInspector", true, false)).strip_edges() != ""
			player_board_feedback_checked = emitted_action_id == "end_turn_requested"
			public_track_checked = _public_track_base_checked(track)
			planet_map_checked = _planet_map_focus_checked(map_view, 1)
			overlay_checked = _overlay_hidden(screen)
		_:
			_failures.append("Unknown first-round runtime interaction: %s" % interaction)
	var signal_checked := _signal_checked(interaction, expected_action_id, emitted_action_id)
	var passed := selected_card_checked and inspector_checked and player_board_feedback_checked and public_track_checked and planet_map_checked and overlay_checked and privacy_checked and signal_checked
	var notes := "first-round runtime playable loop ok"
	if not passed:
		notes = "selected=%s inspector=%s player=%s track=%s planet=%s overlay=%s privacy=%s signal=%s clicked=%s emitted=%s expected=%s" % [
			str(selected_card_checked),
			str(inspector_checked),
			str(player_board_feedback_checked),
			str(public_track_checked),
			str(planet_map_checked),
			str(overlay_checked),
			str(privacy_checked),
			str(signal_checked),
			clicked_action_id,
			emitted_action_id,
			expected_action_id,
		]
		_failures.append("%s failed: %s" % [case_id, notes])
	var record := {
		"case_id": case_id,
		"fixture_id": fixture_id,
		"clicked_action_id": clicked_action_id,
		"emitted_action_id": emitted_action_id,
		"selected_card_checked": selected_card_checked,
		"inspector_checked": inspector_checked,
		"player_board_feedback_checked": player_board_feedback_checked,
		"public_track_checked": public_track_checked,
		"planet_map_checked": planet_map_checked,
		"overlay_checked": overlay_checked,
		"privacy_checked": privacy_checked,
		"passed": passed,
		"notes": notes,
	}
	_append_summary("%s: %s" % [case_id, "PASS" if passed else "FAIL"])
	return record


func _preview_record(flow_case: Dictionary) -> Dictionary:
	return {
		"case_id": str(flow_case.get("case_id", "")),
		"fixture_id": str(flow_case.get("fixture_id", "")),
		"clicked_action_id": str(flow_case.get("expected_action_id", "")),
		"emitted_action_id": "",
		"selected_card_checked": false,
		"inspector_checked": false,
		"player_board_feedback_checked": false,
		"public_track_checked": false,
		"planet_map_checked": false,
		"overlay_checked": false,
		"privacy_checked": false,
		"passed": false,
		"notes": str(flow_case.get("notes", "")),
	}


func _table_state_for_case(flow_case: Dictionary) -> Dictionary:
	var fixtures := _fixtures_instance()
	if fixtures != null and fixtures.has_method("table_state_for_case"):
		var value: Variant = fixtures.call("table_state_for_case", flow_case)
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {}


func _map_payload_for_case(flow_case: Dictionary) -> Dictionary:
	var fixtures := _fixtures_instance()
	if fixtures != null and fixtures.has_method("map_payload_for_case"):
		var value: Variant = fixtures.call("map_payload_for_case", flow_case)
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {}


func _connect_game_screen_signals(screen: Node) -> void:
	if screen == null or _connected_screen == screen:
		return
	_connected_screen = screen
	if screen.has_signal("action_requested"):
		screen.connect("action_requested", Callable(self, "_on_game_screen_action_requested"))
	if screen.has_signal("end_turn_requested"):
		screen.connect("end_turn_requested", Callable(self, "_on_end_turn_requested"))


func _connect_track_signals(track: Node) -> void:
	if track == null or _connected_track == track:
		return
	_connected_track = track
	if track.has_signal("track_action_requested"):
		track.connect("track_action_requested", Callable(self, "_on_track_action_requested"))


func _connect_overlay_signals(overlay: Node) -> void:
	if overlay == null or _connected_overlay == overlay:
		return
	_connected_overlay = overlay
	if overlay.has_signal("temporary_decision_action_requested"):
		overlay.connect("temporary_decision_action_requested", Callable(self, "_on_overlay_action_requested"))


func _connect_map_signals(map_view: Node) -> void:
	if map_view == null or _connected_map == map_view:
		return
	_connected_map = map_view
	if map_view.has_signal("district_selected"):
		map_view.connect("district_selected", Callable(self, "_on_map_district_selected"))
	if map_view.has_signal("district_double_clicked"):
		map_view.connect("district_double_clicked", Callable(self, "_on_map_district_double_clicked"))


func _clear_observed_case_signals() -> void:
	_emitted_action_ids.clear()
	_end_turn_ids.clear()
	_overlay_action_ids.clear()
	_track_action_ids.clear()
	_district_selected_indices.clear()
	_district_double_clicked_indices.clear()


func _on_game_screen_action_requested(action_id: String) -> void:
	_emitted_action_ids.append(action_id)


func _on_end_turn_requested() -> void:
	_end_turn_ids.append("end_turn_requested")


func _on_overlay_action_requested(action_id: String) -> void:
	_overlay_action_ids.append(action_id)


func _on_track_action_requested(action_id: String) -> void:
	_track_action_ids.append(action_id)


func _on_map_district_selected(index: int) -> void:
	_district_selected_indices.append(index)


func _on_map_district_double_clicked(index: int) -> void:
	_district_double_clicked_indices.append(index)


func _apply_map_payload(screen: Control, payload: Dictionary) -> void:
	var map_view := _map_view(screen)
	if map_view == null or not map_view.has_method("set_map"):
		return
	map_view.call(
		"set_map",
		_convert_districts(payload.get("districts", [])),
		float(payload.get("map_width_m", 1400.0)),
		float(payload.get("map_height_m", 950.0)),
		int(payload.get("selected", 0)),
		_convert_colors(payload.get("palette", [])),
		_convert_vector_entries(payload.get("movement_trails", []), ["from", "to"]),
		_convert_vector_entries(payload.get("action_callouts", []), ["position"]),
		_convert_color_entries(_convert_vector_entries(payload.get("map_event_effects", []), ["from", "to", "position"]), ["color"]),
		_convert_vector_entries(payload.get("monster_markers", []), ["position"]),
		_convert_vector_entries(payload.get("city_markers", []), ["position"]),
		_convert_route_markers(payload.get("trade_routes", [])),
		str(payload.get("trade_product", "")),
		str(payload.get("visual_layer_focus", "all"))
	)
	if map_view.has_method("set_preview_note"):
		map_view.call("set_preview_note", str(payload.get("hint", "")))
	if str(payload.get("projection", "globe")) == "local" and map_view.has_method("zoom_to_local_projection"):
		map_view.call("zoom_to_local_projection")
	elif map_view.has_method("reset_to_planet_overview"):
		map_view.call("reset_to_planet_overview")
	var focus_index := int(payload.get("selected", -1))
	if focus_index >= 0 and map_view.has_method("focus_district"):
		map_view.call("focus_district", focus_index)


func _click_hand_card(viewport: SubViewport, screen: Control, card_id: String) -> void:
	var card := _hand_card_by_id(screen, card_id)
	if card == null:
		_failures.append("hand card not found: %s" % card_id)
		return
	await _click_control(viewport, card)
	if card.has_signal("card_clicked") and card.has_method("get_card_data"):
		card.emit_signal("card_clicked", card.call("get_card_data"))
	await _pump_frames(4)


func _click_card_action(screen: Control, card_id: String, action_id: String, expect_disabled: bool) -> bool:
	var card := _hand_card_by_id(screen, card_id)
	var action := _card_action(card, action_id)
	var button := _button_for_action(screen.find_child("RightInspector", true, false), action)
	if button == null:
		_failures.append("card action button not found: %s" % action_id)
		return false
	var before_count := _emitted_action_ids.size()
	if not button.disabled:
		button.emit_signal("pressed")
	if expect_disabled:
		return button.disabled and _emitted_action_ids.size() == before_count and _node_tree_text(screen).contains(str(action.get("tooltip", action.get("reason", ""))).left(8))
	return not button.disabled


func _press_public_track_slot(track: Control, slot_id: String, double_click: bool) -> void:
	var slot := _slot_by_entry_id(track, slot_id)
	if slot != null and slot.has_method("debug_press"):
		slot.call("debug_press", double_click)


func _press_response_action(track: Control, action_id: String) -> String:
	var button := _response_action_button(track, action_id)
	if button != null and not button.disabled:
		button.emit_signal("pressed")
	return action_id


func _click_temporary_decision_action(screen: Control, action_id: String) -> void:
	var overlay := _overlay_layer(screen)
	var button := _temporary_action_button(overlay, action_id)
	if button == null:
		_failures.append("temporary decision action button not found: %s" % action_id)
		return
	if not button.disabled:
		button.emit_signal("pressed")


func _click_end_turn(screen: Control) -> void:
	var button := screen.find_child("EndTurnButton", true, false) as Button
	if button != null and not button.disabled:
		button.emit_signal("pressed")


func _click_map_district(map_view: Control, district_index: int, double_click: bool) -> bool:
	if map_view == null or not map_view.has_method("get_district_control_position"):
		return false
	var local_position: Variant = map_view.call("get_district_control_position", district_index)
	if not (local_position is Vector2):
		return false
	var local_vec := local_position as Vector2
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = local_vec
	press.global_position = map_view.global_position + local_vec
	press.pressed = true
	press.double_click = double_click
	map_view.call("_gui_input", press)
	await _pump_frames(1)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = local_vec
	release.global_position = map_view.global_position + local_vec
	release.pressed = false
	map_view.call("_gui_input", release)
	await _pump_frames(3)
	if double_click:
		return _district_double_clicked_indices.has(district_index)
	return _district_selected_indices.has(district_index)


func _click_control(viewport: SubViewport, control: Control) -> void:
	if viewport == null or control == null or not control.is_inside_tree() or not control.is_visible_in_tree():
		return
	var center := control.get_global_rect().get_center()
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
	await _pump_frames(3)


func _public_track(screen: Control) -> Control:
	if screen == null:
		return null
	return screen.find_child("PublicTrack", true, false) as Control


func _overlay_layer(screen: Control) -> Node:
	if screen == null:
		return null
	return screen.find_child("OverlayLayer", true, false)


func _map_view(screen: Control) -> Control:
	if screen != null and screen.has_method("get_embedded_map_view"):
		var value: Variant = screen.call("get_embedded_map_view")
		if value is Control:
			return value as Control
	if screen == null:
		return null
	return screen.find_child("PlanetMapView", true, false) as Control


func _hand_card_by_id(screen: Control, card_id: String) -> Control:
	var hand_rack := screen.find_child("HandRack", true, false) if screen != null else null
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


func _card_action(card: Control, action_id: String) -> Dictionary:
	if card == null or not card.has_method("get_card_data"):
		return {"id": action_id, "label": action_id}
	var value: Variant = card.call("get_card_data")
	var data: Dictionary = value if value is Dictionary else {}
	var actions: Array = data.get("actions", []) if data.get("actions", []) is Array else []
	for action_variant in actions:
		if action_variant is Dictionary and str((action_variant as Dictionary).get("id", "")) == action_id:
			return (action_variant as Dictionary).duplicate(true)
	return {"id": action_id, "label": action_id}


func _button_for_action(root_node: Node, action: Dictionary) -> Button:
	if root_node == null or action.is_empty():
		return null
	var label := str(action.get("label", action.get("id", ""))).strip_edges()
	var preferred: Button = null
	for button_variant in root_node.find_children("*", "Button", true, false):
		var button := button_variant as Button
		if button == null or not button.visible:
			continue
		var text := button.text.replace("\n", " ").strip_edges()
		if label != "" and (text == label or text.contains(label) or label.contains(text)):
			return button
		if preferred == null and button.disabled == bool(action.get("disabled", false)):
			preferred = button
	return preferred


func _temporary_action_button(overlay: Node, action_id: String) -> Button:
	if overlay == null:
		return null
	for button_variant in overlay.find_children("*", "Button", true, false):
		var button := button_variant as Button
		if button == null or not button.visible:
			continue
		if str(button.get_meta("temporary_decision_action_id", "")) == action_id or button.tooltip_text.contains(action_id):
			return button
		if button.text.contains("玩家 1") and action_id.contains("choose_player_1"):
			return button
	return null


func _slot_by_entry_id(track: Control, slot_id: String) -> Control:
	if track == null:
		return null
	for node_variant in track.find_children("*", "Control", true, false):
		var node := node_variant as Control
		if node != null and node.has_method("track_entry"):
			var value: Variant = node.call("track_entry")
			var entry: Dictionary = value if value is Dictionary else {}
			if str(entry.get("id", entry.get("resolution_id", ""))) == slot_id:
				return node
	return null


func _response_action_button(track: Control, action_id: String) -> Button:
	if track == null:
		return null
	for node_variant in track.find_children("*", "Button", true, false):
		var button := node_variant as Button
		if button != null and str(button.get_meta("track_action_id", "")) == action_id:
			return button
	return null


func _core_surface_present(screen: Control) -> bool:
	for node_name in ["TopBar", "PlayerBoard", "HandRack", "RightInspector", "PublicTrack", "PlanetBoard", "PlanetMapView", "OverlayLayer"]:
		if screen.find_child(node_name, true, false) == null:
			return false
	return true


func _top_bar_mentions_first_turn(screen: Control) -> bool:
	var text := _node_tree_text(screen.find_child("TopBar", true, false))
	return text.contains("玩家回合") and text.contains("第一轮")


func _hand_has_cards(screen: Control) -> bool:
	var hand_rack := screen.find_child("HandRack", true, false) if screen != null else null
	if hand_rack == null:
		return false
	for child in hand_rack.get_children():
		if child is Control and (child as Control).has_method("get_card_data"):
			return true
	return false


func _selected_card_ok_for_case(screen: Control, selected_card_id: String, interaction: String) -> bool:
	if selected_card_id == "" or interaction in ["boot", "public_track_response", "planet_map_action", "privacy_boundary"]:
		return true
	return _hand_card_by_id(screen, selected_card_id) != null


func _selected_card_visual_stable(screen: Control, card_id: String) -> bool:
	var hand_rack := screen.find_child("HandRack", true, false) if screen != null else null
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


func _right_inspector_has_card(screen: Control, card_id: String) -> bool:
	var card := _hand_card_by_id(screen, card_id)
	if card == null or not card.has_method("get_card_data"):
		return false
	var value: Variant = card.call("get_card_data")
	var data: Dictionary = value if value is Dictionary else {}
	var text := _node_tree_text(screen.find_child("RightInspector", true, false))
	var matched := 0
	for key in ["name", "target", "type", "effect"]:
		var piece := str(data.get(key, "")).strip_edges()
		if piece != "" and text.contains(piece.left(mini(piece.length(), 8))):
			matched += 1
	return matched >= 2


func _inspector_contains(screen: Control, expected_text: String) -> bool:
	if expected_text.strip_edges() == "":
		return true
	return _node_tree_text(screen.find_child("RightInspector", true, false)).contains(expected_text.left(mini(expected_text.length(), 10))) or _node_tree_text(screen).contains(expected_text.left(mini(expected_text.length(), 10)))


func _player_board_readable(screen: Control) -> bool:
	var text := _node_tree_text(screen.find_child("PlayerBoard", true, false))
	return text.contains("手牌") and text.contains("下一步")


func _player_feedback_contains(screen: Control, action_id: String) -> bool:
	var feedback := _runtime_feedback(screen)
	var board_feedback := _player_board_feedback(screen)
	return str(feedback.get("action_id", "")).contains(action_id) and str(board_feedback.get("action_id", "")).contains(action_id)


func _temporary_feedback_visible(screen: Control) -> bool:
	var text := _node_tree_text(screen.find_child("PlayerBoard", true, false))
	return text.contains("Overlay") or text.contains("待选") or text.contains("选择目标")


func _runtime_feedback(screen: Control) -> Dictionary:
	if screen != null and screen.has_method("get_runtime_player_feedback_snapshot"):
		var value: Variant = screen.call("get_runtime_player_feedback_snapshot")
		return value if value is Dictionary else {}
	return {}


func _player_board_feedback(screen: Control) -> Dictionary:
	var board := screen.find_child("PlayerBoard", true, false) if screen != null else null
	if board != null and board.has_method("get_runtime_feedback_snapshot"):
		var value: Variant = board.call("get_runtime_feedback_snapshot")
		return value if value is Dictionary else {}
	return {}


func _public_track_base_checked(track: Control) -> bool:
	if track == null or not track.visible:
		return false
	if not track.has_method("get_debug_snapshot"):
		return false
	var snapshot: Dictionary = track.call("get_debug_snapshot")
	return bool(snapshot.get("exposes_sceneized_resolution_track", false)) and not bool(snapshot.get("has_private_text", false))


func _public_track_response_checked(track: Control) -> bool:
	if not _public_track_base_checked(track):
		return false
	var snapshot: Dictionary = track.call("get_debug_snapshot")
	return bool(snapshot.get("auction_visible", false)) and int(snapshot.get("response_action_count", 0)) >= 1 and _track_action_ids.has("first_round:track:bid")


func _planet_map_base_checked(map_view: Control) -> bool:
	if map_view == null or not map_view.visible or not map_view.has_method("get_sceneization_debug_snapshot"):
		return false
	var snapshot: Dictionary = map_view.call("get_sceneization_debug_snapshot")
	return bool(snapshot.get("sceneized_visual_cutover_enabled", false)) and not bool(snapshot.get("legacy_draw_fallback_used", true)) and int(snapshot.get("district_count", 0)) >= 1


func _planet_map_focus_checked(map_view: Control, district_index: int) -> bool:
	if not _planet_map_base_checked(map_view):
		return false
	var snapshot: Dictionary = map_view.call("get_sceneization_debug_snapshot")
	return int(snapshot.get("selected_district", -1)) == district_index and bool(snapshot.get("selected_marker_visible", false))


func _overlay_base_checked(overlay: Node) -> bool:
	return overlay != null and overlay.has_signal("temporary_decision_action_requested")


func _temporary_overlay_visible(screen: Control) -> bool:
	var overlay := _overlay_layer(screen)
	if overlay == null:
		return false
	var panel := overlay.find_child("TemporaryChoiceDecisionPanel", true, false) as Control
	return panel != null and panel.visible and _node_tree_text(panel).contains("选择合约目标")


func _hide_overlay(overlay: Node) -> void:
	if overlay != null and overlay.has_method("hide_confirm"):
		overlay.call("hide_confirm")


func _overlay_hidden(screen: Control) -> bool:
	var overlay := _overlay_layer(screen)
	if overlay == null:
		return false
	for panel_name in ["MonsterWagerDecisionPanel", "TemporaryChoiceDecisionPanel", "ConfirmPanel"]:
		var panel := overlay.find_child(panel_name, true, false) as Control
		if panel != null and panel.visible:
			return false
	return true


func _privacy_checked(screen: Control, table_state: Dictionary, flow_case: Dictionary) -> bool:
	var text := _node_tree_text(screen).to_lower()
	for token in PRIVATE_TOKENS:
		if text.contains(token):
			return false
	var probe := JSON.stringify({"table": table_state, "case": flow_case}).to_lower()
	for token in PRIVATE_TOKENS:
		if probe.contains(token):
			return false
	return true


func _signal_checked(interaction: String, expected_action_id: String, emitted_action_id: String) -> bool:
	match interaction:
		"execute_card_action", "public_track_response", "temporary_decision":
			return emitted_action_id == expected_action_id
		"disabled_action_guard":
			return emitted_action_id == ""
		"end_turn", "recovery_sequence":
			return emitted_action_id == "end_turn_requested"
	return true


func _latest_string(values: Array[String]) -> String:
	if values.is_empty():
		return ""
	return values[values.size() - 1]


func _latest_since(values: Array[String], before_count: int) -> String:
	if values.size() <= before_count:
		return ""
	return values[values.size() - 1]


func _fixtures_instance() -> RefCounted:
	if _fixtures != null:
		return _fixtures
	var script := load(FIXTURE_SCRIPT_PATH)
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
	viewport.name = "FirstRoundRuntimePlayableLoopPreviewViewport"
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
	lines.append("# First Round Runtime Playable Loop QA")
	lines.append("")
	lines.append("- GameScreen scene: `%s`" % GAME_SCREEN_SCENE_PATH)
	lines.append("- Output dir: `%s`" % OUTPUT_DIR)
	lines.append("- Manifest: `%s`" % MANIFEST_PATH)
	lines.append("- Screenshot: `%s`" % SCREENSHOT_PATH)
	lines.append("- Case count: %d" % int(manifest.get("case_count", 0)))
	lines.append("- Passed: %d" % int(manifest.get("passed_count", 0)))
	lines.append("")
	lines.append("| Case | Fixture | Clicked | Emitted | Card | Inspector | Player | Track | Map | Overlay | Privacy | Passed |")
	lines.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		lines.append("| %s | %s | `%s` | `%s` | %s | %s | %s | %s | %s | %s | %s | %s |" % [
			str(record.get("case_id", "")),
			str(record.get("fixture_id", "")),
			str(record.get("clicked_action_id", "")),
			str(record.get("emitted_action_id", "")),
			str(record.get("selected_card_checked", false)),
			str(record.get("inspector_checked", false)),
			str(record.get("player_board_feedback_checked", false)),
			str(record.get("public_track_checked", false)),
			str(record.get("planet_map_checked", false)),
			str(record.get("overlay_checked", false)),
			str(record.get("privacy_checked", false)),
			str(record.get("passed", false)),
		])
	return "\n".join(lines) + "\n"


func _finish_flow_suite(records: Array) -> int:
	if _failures.is_empty():
		var message := "First Round Runtime Playable Loop QA complete: %d/%d passed. manifest=%s report=%s screenshot=%s" % [_passed_count(records), records.size(), MANIFEST_PATH, REPORT_PATH, SCREENSHOT_PATH]
		print(message)
		_set_status(message)
		return 0
	var failure_text := "First Round Runtime Playable Loop QA failed:\n- %s" % "\n- ".join(_failures)
	push_error(failure_text)
	_set_status(failure_text)
	return 1


func _passed_count(records: Array) -> int:
	var total := 0
	for record_variant in records:
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		if bool(record.get("passed", false)):
			total += 1
	return total


func _append_summary(line: String) -> void:
	if summary_label == null:
		return
	if summary_label.text.strip_edges() == "" or summary_label.text == "First-round runtime playable loop results will appear here.":
		summary_label.text = line
	else:
		summary_label.text = "%s\n%s" % [summary_label.text, line]


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


func _convert_districts(source: Variant) -> Array:
	var result: Array = []
	if not (source is Array):
		return result
	for entry_variant in source:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = (entry_variant as Dictionary).duplicate(true)
		entry["center"] = _array_to_vector2(entry.get("center", [0, 0]))
		entry["polygon"] = _point_array(entry.get("polygon", []))
		result.append(entry)
	return result


func _convert_route_markers(source: Variant) -> Array:
	var result: Array = []
	if not (source is Array):
		return result
	for route_variant in source:
		if not (route_variant is Dictionary):
			continue
		var route: Dictionary = (route_variant as Dictionary).duplicate(true)
		route["points"] = _point_array(route.get("points", []))
		result.append(route)
	return result


func _convert_vector_entries(source: Variant, fields: Array) -> Array:
	var result: Array = []
	if not (source is Array):
		return result
	for entry_variant in source:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = (entry_variant as Dictionary).duplicate(true)
		for field_variant in fields:
			var field := str(field_variant)
			if entry.has(field):
				entry[field] = _array_to_vector2(entry.get(field, [0, 0]))
		result.append(entry)
	return result


func _convert_color_entries(source: Variant, fields: Array) -> Array:
	var result: Array = []
	if not (source is Array):
		return result
	for entry_variant in source:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = (entry_variant as Dictionary).duplicate(true)
		for field_variant in fields:
			var field := str(field_variant)
			if entry.has(field):
				entry[field] = Color(str(entry.get(field, "#ffffff")))
		result.append(entry)
	return result


func _convert_colors(source: Variant) -> Array:
	var result: Array = []
	if not (source is Array):
		return result
	for value in source:
		result.append(Color(str(value)))
	return result


func _point_array(source: Variant) -> Array:
	var result: Array = []
	if not (source is Array):
		return result
	for value in source:
		result.append(_array_to_vector2(value))
	return result


func _array_to_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value as Vector2
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	return Vector2.ZERO
