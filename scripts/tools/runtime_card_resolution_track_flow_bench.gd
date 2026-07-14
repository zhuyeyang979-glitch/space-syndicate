extends Control
class_name RuntimeCardResolutionTrackFlowBench

const GAME_SCREEN_SCENE_PATH := "res://scenes/ui/GameScreen.tscn"
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const CONTROLLER_NODE_PATH := "RuntimeServices/RuntimeControllerHost/CardResolutionRuntimeController"
const FIXTURE_SCRIPT_PATH := "res://scripts/tools/runtime_card_resolution_track_flow_fixtures.gd"
const OUTPUT_DIR := "user://space_syndicate_design_qa/runtime_card_resolution_track_flow/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/runtime_card_resolution_track_flow_sprint_3.png"
const VIEWPORT_SIZE := Vector2i(1600, 960)

@export var auto_run_on_ready := true
@export var quit_when_complete := true
@export_range(0.0, 20.0, 0.5) var quit_delay_seconds := 8.0

@onready var status_label: Label = %RuntimeCardResolutionTrackFlowStatusLabel
@onready var summary_label: Label = %RuntimeCardResolutionTrackFlowSummaryLabel
@onready var preview_viewport: SubViewport = %RuntimeCardResolutionTrackFlowPreviewViewport

var _fixtures: RefCounted = null
var _failures: Array[String] = []
var _emitted_action_ids: Array[String] = []
var _selected_entries: Array = []
var _opened_entries: Array = []
var _track_requested_actions: Array[String] = []
var _connected_screen: Node = null
var _connected_track: Node = null
var _controller_snapshot_cache: Dictionary = {}


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
	if fixtures == null:
		return []
	var value: Variant = fixtures.call("cases")
	return (value as Array).duplicate(true) if value is Array else []


func build_flow_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_variant in flow_cases():
		var case: Dictionary = case_variant if case_variant is Dictionary else {}
		records.append(_preview_record(case))
	return {
		"version": "runtime-card-resolution-track-flow-v3",
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
	_emitted_action_ids.clear()
	_selected_entries.clear()
	_opened_entries.clear()
	_track_requested_actions.clear()
	_controller_snapshot_cache = {}
	_set_status("Preparing Runtime Card Resolution Track Flow bench...")
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
	screen.name = "RuntimeCardResolutionTrackGameScreen"
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(screen)
	await _pump_frames(8)
	_connect_game_screen_signals(screen)
	var records: Array = []
	for case_variant in flow_cases():
		var case: Dictionary = case_variant if case_variant is Dictionary else {}
		var record := await _run_case(screen, case)
		records.append(record)
	_clear_viewport(viewport)
	await _pump_frames(4)
	var screenshot_screen := packed.instantiate() as Control
	if screenshot_screen == null:
		_failures.append("Fresh GameScreen could not be instantiated for screenshot capture.")
	else:
		screenshot_screen.name = "RuntimeCardResolutionTrackScreenshotGameScreen"
		screenshot_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		viewport.add_child(screenshot_screen)
		await _pump_frames(8)
	var screenshot_case := _flow_case_by_id("runtime_group_wager_pool_privacy")
	if screenshot_screen != null and not screenshot_case.is_empty() and screenshot_screen.has_method("apply_state"):
		screenshot_screen.call("apply_state", _table_state_for_case(screenshot_case))
		await _pump_frames(24)
	_save_viewport_screenshot(viewport, SCREENSHOT_PATH)
	var manifest := {
		"version": "runtime-card-resolution-track-flow-v3",
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


func _run_case(screen: Control, case: Dictionary) -> Dictionary:
	var case_id := str(case.get("case_id", ""))
	var fixture_id := str(case.get("fixture_id", ""))
	var clicked_slot_id := str(case.get("clicked_slot_id", ""))
	var expected_action_id := str(case.get("expected_action_id", ""))
	var interaction := str(case.get("interaction", ""))
	var expected_text := str(case.get("expected_inspector_text", ""))
	_set_status("Running %s / %s..." % [case_id, fixture_id])
	var table_state := _table_state_for_case(case)
	if screen.has_method("apply_state"):
		screen.call("apply_state", table_state)
	await _pump_frames(10)
	var track := _public_track(screen)
	_connect_track_signals(track)
	_clear_observed_case_signals()
	var before_count := _emitted_action_ids.size()
	var clicked_action_id := expected_action_id
	var disabled_checked := true
	match interaction:
		"load_track":
			clicked_action_id = ""
		"select_slot":
			_press_slot(track, clicked_slot_id, false)
		"open_slot":
			_press_slot(track, clicked_slot_id, true)
		"response_action":
			clicked_action_id = _press_response_action(track, expected_action_id)
		"disabled_response_action":
			clicked_action_id = expected_action_id
			disabled_checked = _disabled_response_checked(track, expected_action_id)
		"readonly_history":
			clicked_action_id = ""
			_press_slot(track, clicked_slot_id, false)
		"empty_safe":
			clicked_action_id = ""
			_press_slot(track, clicked_slot_id, false)
		_:
			_failures.append("Unknown runtime card-resolution interaction: %s" % interaction)
	await _pump_frames(5)
	var emitted_action_id := _latest_since(_emitted_action_ids, before_count)
	var inspector_checked := _inspector_checked(screen, expected_text, interaction)
	var privacy_checked := _privacy_checked(screen)
	var layout_checked := _layout_checked(track, case_id)
	var group_window_checked := _group_window_checked(case)
	var game_screen_signal_checked := _game_screen_signal_checked(expected_action_id, emitted_action_id, interaction)
	var controller_state := _controller_check_snapshot()
	var controller_checked := bool(controller_state.get("controller_checked", false))
	var controller_missing := bool(controller_state.get("controller_missing", true))
	var controller_authoritative := bool(controller_state.get("controller_authoritative", false))
	var legacy_state_fallback_used := bool(controller_state.get("legacy_state_fallback_used", true))
	if interaction == "disabled_response_action":
		disabled_checked = disabled_checked and emitted_action_id == ""
	var passed := track != null and inspector_checked and disabled_checked and privacy_checked and layout_checked and group_window_checked and game_screen_signal_checked and controller_checked and not controller_missing and controller_authoritative and not legacy_state_fallback_used
	var notes := "runtime GameScreen card-resolution flow ok"
	if not passed:
		notes = "track=%s inspector=%s disabled=%s privacy=%s layout=%s group_window=%s game_screen_signal=%s controller=%s missing=%s authoritative=%s fallback=%s expected=%s emitted=%s selected=%s opened=%s track_actions=%s" % [
			str(track != null),
			str(inspector_checked),
			str(disabled_checked),
			str(privacy_checked),
			str(layout_checked),
			str(group_window_checked),
			str(game_screen_signal_checked),
			str(controller_checked),
			str(controller_missing),
			str(controller_authoritative),
			str(legacy_state_fallback_used),
			expected_action_id,
			emitted_action_id,
			str(_entry_ids(_selected_entries)),
			str(_entry_ids(_opened_entries)),
			str(_track_requested_actions),
		]
		_failures.append("%s failed: %s" % [case_id, notes])
	var record := {
		"case_id": case_id,
		"fixture_id": fixture_id,
		"clicked_slot_id": clicked_slot_id,
		"clicked_action_id": clicked_action_id,
		"emitted_action_id": emitted_action_id,
		"inspector_checked": inspector_checked,
		"disabled_checked": disabled_checked,
		"privacy_checked": privacy_checked,
		"layout_checked": layout_checked,
		"group_window_checked": group_window_checked,
		"game_screen_signal_checked": game_screen_signal_checked,
		"controller_checked": controller_checked,
		"controller_missing": controller_missing,
		"controller_authoritative": controller_authoritative,
		"legacy_state_fallback_used": legacy_state_fallback_used,
		"passed": passed,
		"notes": notes,
	}
	_append_summary("%s: %s" % [case_id, "PASS" if passed else "FAIL"])
	return record


func _preview_record(case: Dictionary) -> Dictionary:
	var controller_state := _controller_check_snapshot()
	return {
		"case_id": str(case.get("case_id", "")),
		"fixture_id": str(case.get("fixture_id", "")),
		"clicked_slot_id": str(case.get("clicked_slot_id", "")),
		"clicked_action_id": str(case.get("expected_action_id", "")),
		"emitted_action_id": "",
		"inspector_checked": false,
		"disabled_checked": false,
		"privacy_checked": false,
		"layout_checked": false,
		"group_window_checked": false,
		"game_screen_signal_checked": false,
		"controller_checked": bool(controller_state.get("controller_checked", false)),
		"controller_missing": bool(controller_state.get("controller_missing", true)),
		"controller_authoritative": bool(controller_state.get("controller_authoritative", false)),
		"legacy_state_fallback_used": bool(controller_state.get("legacy_state_fallback_used", true)),
		"passed": false,
		"notes": str(case.get("notes", "")),
	}


func _controller_check_snapshot() -> Dictionary:
	if not _controller_snapshot_cache.is_empty():
		return _controller_snapshot_cache.duplicate(true)
	var result := {
		"controller_checked": false,
		"controller_missing": true,
		"controller_authoritative": false,
		"legacy_state_fallback_used": true,
	}
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		_controller_snapshot_cache = result
		return result.duplicate(true)
	var main := packed.instantiate()
	if main == null:
		_controller_snapshot_cache = result
		return result.duplicate(true)
	var controller := main.get_node_or_null(CONTROLLER_NODE_PATH)
	var composition: Dictionary = main.call("_runtime_composition_snapshot") if main.has_method("_runtime_composition_snapshot") else {}
	result["controller_checked"] = controller != null and controller.has_method("tick") and controller.has_method("debug_snapshot")
	result["controller_missing"] = bool(composition.get("controller_missing", controller == null))
	result["controller_authoritative"] = bool(composition.get("controller_authoritative", false))
	result["legacy_state_fallback_used"] = bool(composition.get("legacy_state_fallback_used", true))
	main.free()
	_controller_snapshot_cache = result
	return result.duplicate(true)


func _table_state_for_case(case: Dictionary) -> Dictionary:
	var fixtures := _fixtures_instance()
	if fixtures != null and fixtures.has_method("table_state_for_case"):
		var value: Variant = fixtures.call("table_state_for_case", case)
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {}


func _flow_case_by_id(case_id: String) -> Dictionary:
	for case_variant in flow_cases():
		if case_variant is Dictionary and str((case_variant as Dictionary).get("case_id", "")) == case_id:
			return (case_variant as Dictionary).duplicate(true)
	return {}


func _public_track(screen: Control) -> Control:
	if screen == null:
		return null
	return screen.find_child("PublicTrack", true, false) as Control


func _connect_game_screen_signals(screen: Node) -> void:
	if screen == null or _connected_screen == screen:
		return
	_connected_screen = screen
	if screen.has_signal("action_requested"):
		screen.connect("action_requested", Callable(self, "_on_game_screen_action_requested"))


func _connect_track_signals(track: Node) -> void:
	if track == null or _connected_track == track:
		return
	_connected_track = track
	if track.has_signal("track_entry_selected"):
		track.connect("track_entry_selected", Callable(self, "_on_track_entry_selected"))
	if track.has_signal("track_entry_opened"):
		track.connect("track_entry_opened", Callable(self, "_on_track_entry_opened"))
	if track.has_signal("track_action_requested"):
		track.connect("track_action_requested", Callable(self, "_on_track_action_requested"))


func _clear_observed_case_signals() -> void:
	_selected_entries.clear()
	_opened_entries.clear()
	_track_requested_actions.clear()


func _press_slot(track: Control, slot_id: String, double_click: bool) -> void:
	var slot := _slot_by_entry_id(track, slot_id)
	if slot != null and slot.has_method("debug_press"):
		slot.call("debug_press", double_click)


func _press_response_action(track: Control, action_id: String) -> String:
	var button := _response_action_button(track, action_id)
	if button != null and not button.disabled:
		button.emit_signal("pressed")
	return action_id


func _slot_by_entry_id(track: Control, slot_id: String) -> Control:
	if track == null:
		return null
	for node_variant in track.find_children("*", "Control", true, false):
		var node := node_variant as Control
		if node == null or not node.has_method("track_entry"):
			continue
		var entry_variant: Variant = node.call("track_entry")
		var entry: Dictionary = entry_variant if entry_variant is Dictionary else {}
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


func _disabled_response_checked(track: Control, action_id: String) -> bool:
	var button := _response_action_button(track, action_id)
	var reason_label := track.find_child("AuctionResponseDisabledReasonLabel", true, false) as Label if track != null else null
	return button != null and button.disabled and reason_label != null and reason_label.visible and reason_label.text.strip_edges() != ""


func _inspector_checked(screen: Control, expected_text: String, interaction: String) -> bool:
	if screen == null:
		return false
	if expected_text.strip_edges() == "":
		return true
	var text := _node_tree_text(screen.find_child("RightInspector", true, false))
	if interaction in ["response_action", "disabled_response_action", "load_track", "empty_safe"]:
		text = "%s\n%s" % [text, _node_tree_text(screen.find_child("PublicTrack", true, false))]
	return text.contains(expected_text.left(mini(expected_text.length(), 10)))


func _privacy_checked(screen: Control) -> bool:
	var text := _node_tree_text(screen).to_lower()
	for token in ["hidden_owner", "private_owner", "private_target", "private_discard", "owner_secret", "secret_owner", "player 2 secret", "hidden district"]:
		if text.contains(token):
			return false
	return true


func _layout_checked(track: Control, case_id: String) -> bool:
	if track == null or not track.visible or not track.is_visible_in_tree():
		return false
	var rect := track.get_global_rect()
	if rect.size.x < 300.0 or rect.size.y < 28.0:
		return false
	var snapshot := _debug_snapshot(track)
	match case_id:
		"runtime_public_track_loads":
			return bool(snapshot.get("exposes_sceneized_resolution_track", false)) and int(snapshot.get("queue_count", 0)) >= 1
		"runtime_auction_response_action", "runtime_counter_response_window", "runtime_disabled_response_action":
			return bool(snapshot.get("auction_visible", false)) and int(snapshot.get("response_action_count", 0)) >= 1
		"runtime_long_queue_layout":
			return int(snapshot.get("queue_count", 0)) >= 10 and _slot_by_entry_id(track, "runtime_track_1041") != null
		"runtime_empty_track_safe_state":
			return int(snapshot.get("entry_count", 0)) == 0 and int(snapshot.get("queue_count", 0)) >= 1
	return int(snapshot.get("entry_count", 0)) >= 1


func _group_window_checked(flow_case: Dictionary) -> bool:
	var case_id := str(flow_case.get("case_id", ""))
	if not case_id.begins_with("runtime_group_"):
		return true
	var track_state: Dictionary = flow_case.get("track_state", {}) if flow_case.get("track_state", {}) is Dictionary else {}
	var entries: Array = track_state.get("entries", []) if track_state.get("entries", []) is Array else []
	if entries.is_empty():
		return false
	match case_id:
		"runtime_group_organize_window":
			return str(track_state.get("window_phase", "")) == "organize" and _group_cards_are_contiguous(entries, "window_12_group_0", 2)
		"runtime_group_lock_window":
			return str(track_state.get("window_phase", "")) == "lock" and bool(track_state.get("auction_open", false))
		"runtime_group_contiguous_order":
			return _group_cards_are_contiguous(entries, "window_12_group_0", 2)
		"runtime_group_wager_pool_privacy":
			var first: Dictionary = entries[0] if entries[0] is Dictionary else {}
			return int(first.get("priority_bid_cents", 0)) == 10000 and str(track_state.get("summary", "")).contains("怪兽赌局公共奖池") and str(track_state.get("summary", "")).contains("不存在组间资金链")
	return false


func _group_cards_are_contiguous(entries: Array, group_id: String, expected_count: int) -> bool:
	var positions: Array[int] = []
	var orders: Array[int] = []
	for index in range(entries.size()):
		if not (entries[index] is Dictionary):
			continue
		var entry := entries[index] as Dictionary
		if str(entry.get("group_id", "")) != group_id:
			continue
		positions.append(index)
		orders.append(int(entry.get("group_order", 0)))
	if positions.size() != expected_count or orders.size() != expected_count:
		return false
	for index in range(expected_count):
		if positions[index] != positions[0] + index or orders[index] != index + 1:
			return false
	return true


func _game_screen_signal_checked(expected_action_id: String, emitted_action_id: String, interaction: String) -> bool:
	match interaction:
		"load_track", "disabled_response_action", "readonly_history", "empty_safe":
			return emitted_action_id == ""
	return expected_action_id == "" or emitted_action_id == expected_action_id


func _debug_snapshot(track: Control) -> Dictionary:
	if track != null and track.has_method("get_debug_snapshot"):
		var value: Variant = track.call("get_debug_snapshot")
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {}


func _latest_since(values: Array[String], before_count: int) -> String:
	if values.size() <= before_count:
		return ""
	return values[values.size() - 1]


func _entry_ids(entries: Array) -> Array[String]:
	var result: Array[String] = []
	for entry_variant in entries:
		var entry: Dictionary = entry_variant if entry_variant is Dictionary else {}
		result.append(str(entry.get("id", entry.get("resolution_id", ""))))
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


func _active_viewport() -> SubViewport:
	if preview_viewport != null:
		preview_viewport.size = VIEWPORT_SIZE
		return preview_viewport
	var viewport := SubViewport.new()
	viewport.name = "RuntimeCardResolutionTrackFlowPreviewViewport"
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
	lines.append("# Runtime Card Resolution Track Flow QA")
	lines.append("")
	lines.append("- GameScreen scene: `%s`" % GAME_SCREEN_SCENE_PATH)
	lines.append("- Output dir: `%s`" % OUTPUT_DIR)
	lines.append("- Manifest: `%s`" % MANIFEST_PATH)
	lines.append("- Screenshot: `%s`" % SCREENSHOT_PATH)
	lines.append("- Case count: %d" % int(manifest.get("case_count", 0)))
	lines.append("")
	lines.append("| Case | Fixture | Slot | Clicked Action | Emitted Action | Inspector | Disabled | Privacy | Layout | Group Window | GameScreen Signal | Controller | Missing | Authority | Fallback | Passed | Notes |")
	lines.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		lines.append("| %s | %s | `%s` | `%s` | `%s` | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |" % [
			str(record.get("case_id", "")),
			str(record.get("fixture_id", "")),
			str(record.get("clicked_slot_id", "")),
			str(record.get("clicked_action_id", "")),
			str(record.get("emitted_action_id", "")),
			str(record.get("inspector_checked", false)),
			str(record.get("disabled_checked", false)),
			str(record.get("privacy_checked", false)),
			str(record.get("layout_checked", false)),
			str(record.get("group_window_checked", false)),
			str(record.get("game_screen_signal_checked", false)),
			str(record.get("controller_checked", false)),
			str(record.get("controller_missing", true)),
			str(record.get("controller_authoritative", false)),
			str(record.get("legacy_state_fallback_used", true)),
			str(record.get("passed", false)),
			str(record.get("notes", "")),
		])
	return "\n".join(lines) + "\n"


func _finish_flow_suite(records: Array) -> int:
	var passed := _passed_count(records)
	if _failures.is_empty():
		var message := "Runtime Card Resolution Track Flow QA complete: %d/%d passed. manifest=%s report=%s screenshot=%s" % [passed, records.size(), MANIFEST_PATH, REPORT_PATH, SCREENSHOT_PATH]
		print(message)
		_set_status(message)
		return 0
	var failure_text := "Runtime Card Resolution Track Flow QA failed:\n- %s" % "\n- ".join(_failures)
	push_error(failure_text)
	_set_status(failure_text)
	return 1


func _passed_count(records: Array) -> int:
	var count := 0
	for record_variant in records:
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		if bool(record.get("passed", false)):
			count += 1
	return count


func _append_summary(text: String) -> void:
	if summary_label == null:
		return
	var prefix := summary_label.text.strip_edges()
	summary_label.text = text if prefix == "" or prefix == "Runtime card-resolution flow results will appear here." else "%s\n%s" % [prefix, text]


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
	elif node is Control:
		var tooltip := (node as Control).tooltip_text.strip_edges()
		if tooltip != "":
			pieces.append(tooltip)
	for child in node.get_children():
		pieces.append(_node_tree_text(child))
	return "\n".join(pieces)


func _pump_frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame


func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text


func _on_game_screen_action_requested(action_id: String) -> void:
	if action_id.strip_edges() != "":
		_emitted_action_ids.append(action_id)


func _on_track_entry_selected(entry: Dictionary) -> void:
	_selected_entries.append(entry.duplicate(true))


func _on_track_entry_opened(entry: Dictionary) -> void:
	_opened_entries.append(entry.duplicate(true))


func _on_track_action_requested(action_id: String) -> void:
	if action_id.strip_edges() != "":
		_track_requested_actions.append(action_id)
