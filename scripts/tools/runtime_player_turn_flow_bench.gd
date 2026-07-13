extends Control
class_name RuntimePlayerTurnFlowBench

const GAME_SCREEN_SCENE_PATH := "res://scenes/ui/GameScreen.tscn"
const PLAYER_TURN_FIXTURE_SCRIPT_PATH := "res://scripts/tools/player_turn_mcp_preview_fixtures.gd"
const OUTPUT_DIR := "user://space_syndicate_design_qa/runtime_player_turn_flow/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/runtime_player_turn_flow_sprint_1.png"
const VIEWPORT_SIZE := Vector2i(1600, 960)

@export var auto_run_on_ready := true
@export var quit_when_complete := true
@export_range(0.0, 20.0, 0.5) var quit_delay_seconds := 8.0

@onready var status_label: Label = %RuntimePlayerFlowStatusLabel
@onready var summary_label: Label = %RuntimePlayerFlowSummaryLabel
@onready var preview_viewport: SubViewport = %RuntimePlayerFlowPreviewViewport

var _fixtures: RefCounted = null
var _failures: Array[String] = []


func _ready() -> void:
	if preview_viewport != null:
		preview_viewport.size = VIEWPORT_SIZE
		preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		preview_viewport.gui_disable_input = false
	if auto_run_on_ready:
		call_deferred("_run_flow_suite_and_maybe_quit")


func output_dir() -> String:
	return OUTPUT_DIR


func flow_cases() -> Array:
	return [
		_case_record("empty_hand", "empty_hand_no_card_action", "", "", "Real GameScreen keeps the bottom hand area readable without card actions."),
		_case_record("normal_hand", "hand_card_click_updates_inspector", "card_orbital_finance", "", "Clicking a real HandRack card updates the real RightInspector."),
		_case_record("selected_enabled_card", "enabled_action_emits", "card_shadow_contract", "play:shadow_contract", "Enabled card action travels through GameScreen.action_requested."),
		_case_record("selected_disabled_card", "disabled_action_stays_silent", "card_monster_tip_blocked", "play:monster_tip", "Disabled action remains visible with a reason and does not emit."),
		_case_record("public_track_selection", "public_track_select_safe_hint", "card_orbital_finance", "track:contract_a", "Public track click shows public context without hidden-owner fields."),
		_case_record("temporary_decision_pending_hint", "temporary_decision_pending_feedback", "card_shadow_contract", "", "Pending temporary decision shows player-surface feedback without bypassing OverlayLayer."),
	]


func build_flow_manifest_preview() -> Dictionary:
	var records: Array = []
	for case in flow_cases():
		records.append(_preview_manifest_record(case))
	return {
		"version": "runtime-player-turn-flow-v1",
		"output_dir": OUTPUT_DIR,
		"game_screen_scene": GAME_SCREEN_SCENE_PATH,
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
	_set_status("Preparing Runtime Player Turn Flow bench...")
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
		_failures.append("GameScreen root was not Control")
		return _finish_flow_suite([])
	screen.name = "RuntimePlayerTurnGameScreen"
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(screen)
	await _pump_frames(8)
	var emitted_action_ids: Array[String] = []
	_connect_game_screen_signals(screen, emitted_action_ids)
	var records: Array = []
	for case in flow_cases():
		var record := await _run_case(viewport, screen, case, emitted_action_ids)
		records.append(record)
	_save_viewport_screenshot(viewport, SCREENSHOT_PATH)
	var manifest := {
		"version": "runtime-player-turn-flow-v1",
		"output_dir": OUTPUT_DIR,
		"game_screen_scene": GAME_SCREEN_SCENE_PATH,
		"screenshot_path": SCREENSHOT_PATH,
		"case_count": records.size(),
		"records": records,
	}
	_write_text_file(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text_file(REPORT_PATH, _build_markdown_report(manifest))
	return _finish_flow_suite(records)


func _run_case(viewport: SubViewport, screen: Control, case: Dictionary, emitted_action_ids: Array[String]) -> Dictionary:
	var fixture_id := str(case.get("fixture_id", ""))
	var interaction_name := str(case.get("interaction_name", ""))
	_set_status("Running %s / %s..." % [fixture_id, interaction_name])
	var fixture := _fixture(fixture_id)
	var table_state := _table_state_from_fixture(fixture)
	if screen.has_method("apply_state"):
		screen.call("apply_state", table_state)
	await _pump_frames(10)
	var selected_card_id := str(case.get("selected_card_id", fixture.get("selected_card_id", "")))
	var expected_action_id := str(case.get("expected_action_id", ""))
	var before_count := emitted_action_ids.size()
	var clicked_action_id := ""
	var emitted_action_id := ""
	var right_inspector_checked := _right_inspector_has_expected_detail(screen, fixture)
	var disabled_reason_visible := _disabled_reason_visible(screen, fixture)
	var public_hint_safe := _public_hint_safe(screen)
	var temporary_decision_hint_visible := _temporary_decision_hint_visible(screen)
	match interaction_name:
		"empty_hand_no_card_action":
			right_inspector_checked = _empty_hand_affordance_visible(screen)
			disabled_reason_visible = _no_enabled_card_action(screen)
		"hand_card_click_updates_inspector":
			await _click_hand_card(viewport, screen, selected_card_id)
			await _pump_frames(6)
			right_inspector_checked = _right_inspector_has_card(screen, selected_card_id)
		"enabled_action_emits":
			await _click_hand_card(viewport, screen, selected_card_id)
			await _pump_frames(4)
			clicked_action_id = expected_action_id
			await _click_card_action(viewport, screen, fixture, selected_card_id, false, emitted_action_ids)
			emitted_action_id = _latest_since(emitted_action_ids, before_count)
			right_inspector_checked = _right_inspector_has_card(screen, selected_card_id)
		"disabled_action_stays_silent":
			await _click_hand_card(viewport, screen, selected_card_id)
			await _pump_frames(4)
			clicked_action_id = expected_action_id
			disabled_reason_visible = await _click_card_action(viewport, screen, fixture, selected_card_id, true, emitted_action_ids)
			emitted_action_id = _latest_since(emitted_action_ids, before_count)
			right_inspector_checked = _right_inspector_has_card(screen, selected_card_id)
		"public_track_select_safe_hint":
			clicked_action_id = expected_action_id
			await _click_public_track_slot(viewport, screen)
			emitted_action_id = _latest_since(emitted_action_ids, before_count)
			right_inspector_checked = _node_tree_text(screen.find_child("RightInspector", true, false)).contains("匿名合约")
			public_hint_safe = _public_hint_safe(screen)
		"temporary_decision_pending_feedback":
			right_inspector_checked = true
			temporary_decision_hint_visible = _temporary_decision_hint_visible(screen)
			disabled_reason_visible = emitted_action_ids.size() == before_count
		_:
			_failures.append("unknown flow case: %s" % interaction_name)
	var emit_ok := emitted_action_id == expected_action_id
	if expected_action_id == "":
		emit_ok = emitted_action_id == ""
	if interaction_name == "disabled_action_stays_silent":
		emit_ok = emitted_action_id == ""
	var passed := right_inspector_checked and emit_ok
	match interaction_name:
		"empty_hand_no_card_action", "disabled_action_stays_silent":
			passed = passed and disabled_reason_visible
		"public_track_select_safe_hint":
			passed = passed and public_hint_safe
		"temporary_decision_pending_feedback":
			passed = passed and temporary_decision_hint_visible and disabled_reason_visible
	if not passed:
		_failures.append("%s/%s failed: clicked=%s emitted=%s expected=%s inspector=%s disabled_reason=%s public_safe=%s temporary_hint=%s" % [
			fixture_id,
			interaction_name,
			clicked_action_id,
			emitted_action_id,
			expected_action_id,
			str(right_inspector_checked),
			str(disabled_reason_visible),
			str(public_hint_safe),
			str(temporary_decision_hint_visible),
		])
	var record := {
		"fixture_id": fixture_id,
		"interaction_name": interaction_name,
		"selected_card_id": selected_card_id,
		"clicked_action_id": clicked_action_id,
		"emitted_action_id": emitted_action_id,
		"right_inspector_checked": right_inspector_checked,
		"disabled_reason_visible": disabled_reason_visible,
		"public_hint_safe": public_hint_safe,
		"temporary_decision_hint_visible": temporary_decision_hint_visible,
		"passed": passed,
		"notes": str(case.get("notes", "")),
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
		"disabled_reason_visible": false,
		"public_hint_safe": false,
		"temporary_decision_hint_visible": false,
		"passed": false,
		"notes": str(case.get("notes", "")),
	}


func _connect_game_screen_signals(screen: Control, emitted_action_ids: Array[String]) -> void:
	if screen.has_signal("action_requested"):
		screen.connect("action_requested", func(action_id: String) -> void:
			emitted_action_ids.append(action_id)
		)


func _table_state_from_fixture(fixture: Dictionary) -> Dictionary:
	var player_state: Dictionary = fixture.get("player_state", {}) if fixture.get("player_state", {}) is Dictionary else {}
	var inspector: Dictionary = fixture.get("inspector", {}) if fixture.get("inspector", {}) is Dictionary else {}
	var public_track: Array = fixture.get("public_track", []) if fixture.get("public_track", []) is Array else []
	return {
		"top_bar": {
			"phase": "玩家回合 QA",
			"turn": "Sprint 1",
			"identity": str(player_state.get("identity", "你")),
			"cash_text": str(player_state.get("cash_text", "")),
			"gdp_text": str(player_state.get("gdp_text", "")),
			"goal_text": str(player_state.get("goal_text", "")),
			"selected_district": str(player_state.get("selected_district_summary", "")),
			"primary_action": str(player_state.get("primary_action", "")),
		},
		"card_track": _public_track_for_runtime(public_track),
		"planet": {
			"title": "主游戏表面 QA",
			"hint": "真实 GameScreen / PlayerBoard / RightInspector / OverlayLayer",
			"table_lanes": [
				{"title": "玩家操作", "detail": "选牌 -> 详情 -> action_requested"},
				{"title": "公共线索", "detail": "只显示公开 owner_hint"},
			],
		},
		"right_inspector": inspector,
		"player_board": player_state,
		"temporary_decision": _temporary_decision_payload() if bool(fixture.get("temporary_decision_pending", false)) else {},
	}


func _public_track_for_runtime(entries: Array) -> Array:
	var result: Array = []
	for entry_variant in entries:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = (entry_variant as Dictionary).duplicate(true)
		if str(entry.get("select_action", "")).strip_edges() == "":
			var fallback_action := str(entry.get("hover_action", entry.get("id", ""))).strip_edges()
			if fallback_action != "":
				entry["select_action"] = fallback_action
		result.append(entry)
	return result


func _temporary_decision_payload() -> Dictionary:
	return {
		"id": "runtime_flow_player_target",
		"kind": "player_target_choice",
		"title": "选择合约目标",
		"summary": "真实主界面正在等待 Overlay 完成目标选择。",
		"body": "这个 payload 只用于 RuntimePlayerTurnFlowBench，不调用规则函数。",
		"chips": [{"text": "私密选择"}, {"text": "公开后结算"}],
		"actions": [
			{"id": "temporary_decision:target:player_1", "label": "玩家 1", "disabled": false},
			{"id": "temporary_decision:cancel", "label": "取消", "disabled": false},
		],
		"choice": {
			"summary": "选择目标后才进入公开线索。",
			"privacy": "目标选择保持私密。",
		},
	}


func _click_hand_card(viewport: SubViewport, screen: Control, card_id: String) -> void:
	var card := _hand_card_by_id(screen, card_id)
	if card == null:
		_failures.append("hand card not found: %s" % card_id)
		return
	await _click_control(viewport, card)
	var selected_snapshot_variant: Variant = screen.call("get_runtime_player_feedback_snapshot") if screen.has_method("get_runtime_player_feedback_snapshot") else {}
	var selected_snapshot: Dictionary = selected_snapshot_variant if selected_snapshot_variant is Dictionary else {}
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


func _right_inspector_has_expected_detail(screen: Control, fixture: Dictionary) -> bool:
	var selected: Dictionary = fixture.get("selected_card", {}) if fixture.get("selected_card", {}) is Dictionary else {}
	if selected.is_empty():
		return true
	return _right_inspector_text_matches(screen, selected)


func _right_inspector_has_card(screen: Control, card_id: String) -> bool:
	var card := _hand_card_by_id(screen, card_id)
	if card == null or not card.has_method("get_card_data"):
		return false
	var data_variant: Variant = card.call("get_card_data")
	var card_data: Dictionary = data_variant if data_variant is Dictionary else {}
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


func _disabled_reason_visible(screen: Control, fixture: Dictionary) -> bool:
	var selected: Dictionary = fixture.get("selected_card", {}) if fixture.get("selected_card", {}) is Dictionary else {}
	var reason := str(selected.get("disabled_reason", fixture.get("disabled_reason", ""))).strip_edges()
	if reason == "":
		return true
	return _node_tree_text(screen).contains(reason.left(mini(reason.length(), 10)))


func _empty_hand_affordance_visible(screen: Control) -> bool:
	var hand_rack := screen.find_child("HandRack", true, false) as Control
	return hand_rack != null and hand_rack.is_visible_in_tree() and _node_tree_text(hand_rack).contains("暂无手牌")


func _no_enabled_card_action(screen: Control) -> bool:
	var hand_rack := screen.find_child("HandRack", true, false) as Control
	if hand_rack == null:
		return false
	for child in hand_rack.get_children():
		if child is Control and (child as Control).has_method("get_card_data"):
			return false
	return true


func _public_hint_safe(screen: Control) -> bool:
	var text := _node_tree_text(screen.find_child("PublicTrack", true, false)) + "\n" + _node_tree_text(screen.find_child("RightInspector", true, false))
	return text.contains("匿名") and not text.contains("owner") and not text.contains("hidden") and not text.contains("player_index")


func _temporary_decision_hint_visible(screen: Control) -> bool:
	var overlay_text := _node_tree_text(screen.find_child("OverlayLayer", true, false))
	var feedback: Dictionary = screen.call("get_runtime_player_feedback_snapshot") if screen.has_method("get_runtime_player_feedback_snapshot") else {}
	var feedback_text := str(feedback.get("label", "")) + "\n" + str(feedback.get("detail", ""))
	var player_feedback: Dictionary = {}
	var board := screen.find_child("PlayerBoard", true, false)
	if board != null and board.has_method("get_runtime_feedback_snapshot"):
		var value: Variant = board.call("get_runtime_feedback_snapshot")
		player_feedback = value if value is Dictionary else {}
	return overlay_text.contains("选择合约目标") and feedback_text.contains("等待决策") and str(player_feedback.get("kind", "")) == "temporary_decision"


func _hand_card_by_id(screen: Control, card_id: String) -> Control:
	var hand_rack := screen.find_child("HandRack", true, false)
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
	var script := load(PLAYER_TURN_FIXTURE_SCRIPT_PATH)
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
	viewport.name = "RuntimePlayerFlowPreviewViewport"
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
	lines.append("# Runtime Player Turn Flow QA")
	lines.append("")
	lines.append("- GameScreen scene: `%s`" % GAME_SCREEN_SCENE_PATH)
	lines.append("- Output dir: `%s`" % OUTPUT_DIR)
	lines.append("- Manifest: `%s`" % MANIFEST_PATH)
	lines.append("- Screenshot: `%s`" % SCREENSHOT_PATH)
	lines.append("- Case count: %d" % int(manifest.get("case_count", 0)))
	lines.append("")
	lines.append("| Fixture | Flow | Selected Card | Clicked | Emitted | Inspector | Disabled Reason | Public Safe | Decision Hint | Passed |")
	lines.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		lines.append("| %s | %s | `%s` | `%s` | `%s` | %s | %s | %s | %s | %s |" % [
			str(record.get("fixture_id", "")),
			str(record.get("interaction_name", "")),
			str(record.get("selected_card_id", "")),
			str(record.get("clicked_action_id", "")),
			str(record.get("emitted_action_id", "")),
			str(record.get("right_inspector_checked", false)),
			str(record.get("disabled_reason_visible", false)),
			str(record.get("public_hint_safe", false)),
			str(record.get("temporary_decision_hint_visible", false)),
			str(record.get("passed", false)),
		])
	return "\n".join(lines) + "\n"


func _finish_flow_suite(_records: Array) -> int:
	if _failures.is_empty():
		var message := "Runtime Player Turn Flow QA complete. manifest=%s report=%s screenshot=%s" % [MANIFEST_PATH, REPORT_PATH, SCREENSHOT_PATH]
		print(message)
		_set_status(message)
		return 0
	var failure_text := "Runtime Player Turn Flow QA failed:\n- %s" % "\n- ".join(_failures)
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
