extends Control
class_name CardResolutionTrackInteractionBench

const OUTPUT_DIR := "user://space_syndicate_design_qa/card_resolution_track_interactions/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/card_resolution_track_interaction_sprint_2.png"
const PREVIEW_SCENE := preload("res://scenes/tools/CardResolutionTrackMcpPreview.tscn")

@export var auto_run := true
@export var auto_quit_after_suite := false

@onready var status_label: Label = %CardResolutionTrackInteractionStatusLabel
@onready var preview_host: Control = %CardResolutionTrackInteractionPreviewHost
@onready var summary_label: Label = %CardResolutionTrackInteractionSummaryLabel

var _suite_running := false
var _signals_connected_to: Node = null
var _selected_entries: Array = []
var _opened_entries: Array = []
var _requested_actions: Array[String] = []
var _selected_slot_ids: Array[String] = []


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_interaction_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func screenshot_path() -> String:
	return SCREENSHOT_PATH


func interaction_cases() -> Array:
	return [
		{"case_id": "select_queued_card", "fixture_id": "queued_anonymous_cards", "clicked_slot_id": "track_9101", "expected_action_id": "track_select_9101", "interaction": "select_slot"},
		{"case_id": "open_active_card", "fixture_id": "active_reveal", "clicked_slot_id": "track_9110", "expected_action_id": "track_open_storm_credit", "interaction": "open_slot"},
		{"case_id": "auction_response_action", "fixture_id": "auction_window", "clicked_slot_id": "", "expected_action_id": "track_auction_bid_9120", "interaction": "response_action"},
		{"case_id": "disabled_response_action", "fixture_id": "counter_response_window", "clicked_slot_id": "", "expected_action_id": "track_counter_no_energy", "interaction": "disabled_response_action"},
		{"case_id": "counter_response_window", "fixture_id": "counter_response_window", "clicked_slot_id": "track_9130", "expected_action_id": "track_counter_phase_lock", "interaction": "counter_window"},
		{"case_id": "resolved_history", "fixture_id": "resolved_history", "clicked_slot_id": "track_9151", "expected_action_id": "", "interaction": "readonly_history_slot"},
		{"case_id": "long_queue_overflow", "fixture_id": "long_queue_overflow", "clicked_slot_id": "track_9173", "expected_action_id": "track_select_9173", "interaction": "long_queue_slot"},
		{"case_id": "empty_track_safe_state", "fixture_id": "empty_track", "clicked_slot_id": "empty_track", "expected_action_id": "", "interaction": "empty_disabled_slot"},
	]


func build_interaction_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_variant in interaction_cases():
		var case: Dictionary = case_variant if case_variant is Dictionary else {}
		records.append({
			"case_id": str(case.get("case_id", "")),
			"fixture_id": str(case.get("fixture_id", "")),
			"clicked_slot_id": str(case.get("clicked_slot_id", "")),
			"emitted_signal": "",
			"emitted_action_id": "",
			"selected_checked": false,
			"disabled_checked": false,
			"privacy_checked": false,
			"layout_checked": false,
			"passed": false,
			"notes": "Preview manifest only; run_interaction_suite records live results.",
		})
	return {
		"suite": "card_resolution_track_interactions",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"record_count": records.size(),
		"records": records,
	}


func run_interaction_suite() -> void:
	if _suite_running:
		return
	_suite_running = true
	_set_status("Running CardResolutionTrack interaction ownership suite...")
	_prepare_output_dir()
	var preview := _ensure_preview()
	var records: Array = []
	var all_passed := preview != null
	if preview == null:
		push_error("CardResolutionTrackInteractionBench could not instantiate CardResolutionTrackMcpPreview.")
	else:
		for case_variant in interaction_cases():
			var case: Dictionary = case_variant if case_variant is Dictionary else {}
			var record := await _run_interaction_case(preview, case)
			records.append(record)
			all_passed = all_passed and bool(record.get("passed", false))
	var manifest := {
		"suite": "card_resolution_track_interactions",
		"output_dir": OUTPUT_DIR,
		"preview_scene": "res://scenes/tools/CardResolutionTrackMcpPreview.tscn",
		"screenshot_path": SCREENSHOT_PATH,
		"record_count": records.size(),
		"passed_count": _passed_count(records),
		"records": records,
	}
	_write_text_file(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text_file(REPORT_PATH, _build_report(manifest))
	await _settle_frames(2)
	await _write_screenshot()
	print("CardResolutionTrackInteractionBench manifest: %s" % MANIFEST_PATH)
	print("CardResolutionTrackInteractionBench report: %s" % REPORT_PATH)
	print("CardResolutionTrackInteractionBench screenshot: %s" % SCREENSHOT_PATH)
	if all_passed:
		_set_status("Card resolution interactions passed: %d/%d | %s" % [_passed_count(records), records.size(), MANIFEST_PATH])
	else:
		_set_status("Card resolution interactions failed: %d/%d | %s" % [_passed_count(records), records.size(), MANIFEST_PATH])
		push_error("CardResolutionTrackInteractionBench failed. See %s" % MANIFEST_PATH)
	_suite_running = false
	if auto_quit_after_suite:
		await get_tree().create_timer(0.25).timeout
		get_tree().quit(0 if all_passed else 1)


func _ensure_preview() -> Control:
	if preview_host == null:
		return null
	var existing := preview_host.find_child("CardResolutionTrackMcpPreview", true, false) as Control
	if existing != null:
		return existing
	var preview := PREVIEW_SCENE.instantiate() as Control
	if preview == null:
		return null
	preview.name = "CardResolutionTrackMcpPreview"
	preview_host.add_child(preview)
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return preview


func _run_interaction_case(preview: Control, case: Dictionary) -> Dictionary:
	var case_id := str(case.get("case_id", ""))
	var fixture_id := str(case.get("fixture_id", ""))
	var clicked_slot_id := str(case.get("clicked_slot_id", ""))
	var expected_action_id := str(case.get("expected_action_id", ""))
	var interaction := str(case.get("interaction", ""))
	_set_status("Running %s / %s..." % [case_id, fixture_id])
	var applied := bool(preview.call("apply_fixture", fixture_id)) if preview.has_method("apply_fixture") else false
	await _settle_frames(5)
	var track := _card_resolution_track(preview)
	_connect_track_signals(track)
	_clear_observed_signals()
	var clicked_action_id := ""
	var disabled_checked := false
	var selected_checked := false
	var emitted_signal := ""
	match interaction:
		"select_slot":
			_click_slot(track, clicked_slot_id, false)
			await _settle_frames(3)
			selected_checked = _selected_slot_checked(track, clicked_slot_id)
			clicked_action_id = expected_action_id
		"open_slot":
			_click_slot(track, clicked_slot_id, true)
			await _settle_frames(3)
			selected_checked = _opened_entry_ids().has(clicked_slot_id)
			clicked_action_id = expected_action_id
		"response_action":
			clicked_action_id = _click_response_action(track, expected_action_id)
			await _settle_frames(3)
			selected_checked = _requested_actions.has(expected_action_id)
		"disabled_response_action":
			clicked_action_id = _try_disabled_response_action(track, expected_action_id)
			await _settle_frames(3)
			disabled_checked = _disabled_response_checked(track, expected_action_id) and not _requested_actions.has(expected_action_id)
			selected_checked = disabled_checked
		"counter_window":
			clicked_action_id = _click_response_action(track, expected_action_id)
			await _settle_frames(3)
			selected_checked = _response_layer_visible(track) and _requested_actions.has(expected_action_id)
		"readonly_history_slot":
			_click_slot(track, clicked_slot_id, false)
			await _settle_frames(3)
			selected_checked = _selected_entry_ids().has(clicked_slot_id) and _requested_actions.is_empty()
			disabled_checked = true
		"long_queue_slot":
			_click_slot(track, clicked_slot_id, false)
			await _settle_frames(3)
			selected_checked = _selected_entry_ids().has(clicked_slot_id) and _selected_slot_checked(track, clicked_slot_id)
			clicked_action_id = expected_action_id
		"empty_disabled_slot":
			_click_slot(track, clicked_slot_id, false)
			await _settle_frames(3)
			selected_checked = _selected_entries.is_empty() and _requested_actions.is_empty()
			disabled_checked = selected_checked
		_:
			selected_checked = false
	var emitted_action_id := _latest_action()
	if emitted_signal == "":
		emitted_signal = _emitted_signal_summary()
	var snapshot := _debug_snapshot(track)
	var layout_checked := _layout_checked(track, snapshot, case_id)
	var privacy_checked := not _text_contains_private_tokens(preview)
	if not disabled_checked and case_id != "disabled_response_action":
		disabled_checked = true
	var expected_action_ok := _expected_action_ok(case_id, expected_action_id, emitted_action_id)
	var passed := applied and track != null and selected_checked and disabled_checked and privacy_checked and layout_checked and expected_action_ok
	var notes := "interaction ownership ok"
	if not passed:
		notes = "applied=%s track=%s selected=%s disabled=%s privacy=%s layout=%s expected_action=%s emitted=%s actions=%s selected_entries=%s opened=%s selected_slots=%s" % [
			str(applied),
			str(track != null),
			str(selected_checked),
			str(disabled_checked),
			str(privacy_checked),
			str(layout_checked),
			str(expected_action_ok),
			emitted_action_id,
			str(_requested_actions),
			str(_selected_entry_ids()),
			str(_opened_entry_ids()),
			str(_selected_slot_ids),
		]
	var record := {
		"case_id": case_id,
		"fixture_id": fixture_id,
		"clicked_slot_id": clicked_slot_id,
		"clicked_action_id": clicked_action_id,
		"emitted_signal": emitted_signal,
		"emitted_action_id": emitted_action_id,
		"selected_checked": selected_checked,
		"disabled_checked": disabled_checked,
		"privacy_checked": privacy_checked,
		"layout_checked": layout_checked,
		"passed": passed,
		"notes": notes,
	}
	_append_summary("%s: %s" % [case_id, "PASS" if passed else "FAIL"])
	return record


func _card_resolution_track(preview: Control) -> Control:
	if preview == null:
		return null
	return preview.find_child("CardResolutionTrack", true, false) as Control


func _connect_track_signals(track: Node) -> void:
	if track == null or _signals_connected_to == track:
		return
	_signals_connected_to = track
	if track.has_signal("track_entry_selected"):
		track.connect("track_entry_selected", Callable(self, "_on_track_entry_selected"))
	if track.has_signal("track_entry_opened"):
		track.connect("track_entry_opened", Callable(self, "_on_track_entry_opened"))
	if track.has_signal("track_action_requested"):
		track.connect("track_action_requested", Callable(self, "_on_track_action_requested"))
	if track.has_signal("card_slot_selected"):
		track.connect("card_slot_selected", Callable(self, "_on_card_slot_selected"))


func _clear_observed_signals() -> void:
	_selected_entries.clear()
	_opened_entries.clear()
	_requested_actions.clear()
	_selected_slot_ids.clear()


func _click_slot(track: Control, slot_id: String, double_click: bool) -> void:
	var slot := _slot_by_entry_id(track, slot_id)
	if slot != null and slot.has_method("debug_press"):
		slot.call("debug_press", double_click)


func _click_response_action(track: Control, action_id: String) -> String:
	var button := _response_action_button(track, action_id)
	if button == null or button.disabled:
		return action_id
	button.emit_signal("pressed")
	return action_id


func _try_disabled_response_action(track: Control, action_id: String) -> String:
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


func _selected_slot_checked(track: Control, slot_id: String) -> bool:
	if _selected_slot_ids.has(slot_id):
		return true
	var snapshot := _debug_snapshot(track)
	var ids: Array = snapshot.get("selected_slot_ids", []) if snapshot.get("selected_slot_ids", []) is Array else []
	return ids.has(slot_id)


func _disabled_response_checked(track: Control, action_id: String) -> bool:
	var button := _response_action_button(track, action_id)
	var reason_label := track.find_child("AuctionResponseDisabledReasonLabel", true, false) as Label if track != null else null
	return button != null and button.disabled and reason_label != null and reason_label.visible and reason_label.text.strip_edges() != ""


func _response_layer_visible(track: Control) -> bool:
	var layer := track.find_child("AuctionResponseLayer", true, false) as Control if track != null else null
	var row := track.find_child("AuctionResponseActionRow", true, false) as Control if track != null else null
	return layer != null and layer.visible and row != null and row.visible


func _layout_checked(track: Control, snapshot: Dictionary, case_id: String) -> bool:
	if track == null or not track.visible:
		return false
	var rect := track.get_global_rect()
	if rect.size.x < 200.0 or rect.size.y < 40.0:
		return false
	match case_id:
		"long_queue_overflow":
			return int(snapshot.get("queue_count", 0)) >= 10 and _slot_by_entry_id(track, "track_9173") != null
		"empty_track_safe_state":
			return bool(snapshot.get("empty_visible", false))
		"auction_response_action", "counter_response_window", "disabled_response_action":
			return bool(snapshot.get("auction_visible", false)) and int(snapshot.get("response_action_count", 0)) >= 1
	return int(snapshot.get("entry_count", 0)) >= 1


func _expected_action_ok(case_id: String, expected_action_id: String, emitted_action_id: String) -> bool:
	match case_id:
		"disabled_response_action", "resolved_history", "empty_track_safe_state":
			return emitted_action_id == ""
	return expected_action_id == "" or emitted_action_id == expected_action_id


func _debug_snapshot(track: Control) -> Dictionary:
	if track != null and track.has_method("get_debug_snapshot"):
		var snapshot_variant: Variant = track.call("get_debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _selected_entry_ids() -> Array[String]:
	var result: Array[String] = []
	for entry_variant in _selected_entries:
		var entry: Dictionary = entry_variant if entry_variant is Dictionary else {}
		result.append(str(entry.get("id", entry.get("resolution_id", ""))))
	return result


func _opened_entry_ids() -> Array[String]:
	var result: Array[String] = []
	for entry_variant in _opened_entries:
		var entry: Dictionary = entry_variant if entry_variant is Dictionary else {}
		result.append(str(entry.get("id", entry.get("resolution_id", ""))))
	return result


func _latest_action() -> String:
	if _requested_actions.is_empty():
		return ""
	return _requested_actions[_requested_actions.size() - 1]


func _emitted_signal_summary() -> String:
	var signals: Array[String] = []
	if not _selected_entries.is_empty():
		signals.append("track_entry_selected")
	if not _opened_entries.is_empty():
		signals.append("track_entry_opened")
	if not _requested_actions.is_empty():
		signals.append("track_action_requested")
	if not _selected_slot_ids.is_empty():
		signals.append("card_slot_selected")
	return ",".join(signals)


func _text_contains_private_tokens(node: Node) -> bool:
	var text := _node_text(node).to_lower()
	for token in ["hidden_owner", "private_target", "private_discard", "private_owner", "owner_secret", "secret_owner"]:
		if text.contains(token):
			return true
	return false


func _node_text(node: Node) -> String:
	if node == null:
		return ""
	var pieces: Array[String] = []
	if node is Label:
		pieces.append((node as Label).text)
	elif node is Button:
		pieces.append((node as Button).text)
	elif node is Control:
		var tooltip := (node as Control).tooltip_text.strip_edges()
		if tooltip != "":
			pieces.append(tooltip)
	for child in node.get_children():
		pieces.append(_node_text(child))
	return "\n".join(pieces)


func _prepare_output_dir() -> void:
	var absolute_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var dir := DirAccess.open(absolute_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and (file_name.ends_with(".json") or file_name.ends_with(".md")):
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


func _write_text_file(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)


func _write_screenshot() -> void:
	await _settle_frames(2)
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(SCREENSHOT_PATH)


func _build_report(manifest: Dictionary) -> String:
	var lines := [
		"# Card Resolution Track Interaction Ownership QA",
		"",
		"- Output dir: `%s`" % OUTPUT_DIR,
		"- Manifest: `%s`" % MANIFEST_PATH,
		"- Screenshot: `%s`" % SCREENSHOT_PATH,
		"",
		"| Case | Fixture | Slot | Signal | Clicked Action | Emitted Action | Selected | Disabled | Privacy | Layout | Passed | Notes |",
		"| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |",
	]
	var records: Array = manifest.get("records", []) if manifest.get("records", []) is Array else []
	for record_variant in records:
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		lines.append("| %s | %s | `%s` | %s | `%s` | `%s` | %s | %s | %s | %s | %s | %s |" % [
			str(record.get("case_id", "")),
			str(record.get("fixture_id", "")),
			str(record.get("clicked_slot_id", "")),
			str(record.get("emitted_signal", "")),
			str(record.get("clicked_action_id", "")),
			str(record.get("emitted_action_id", "")),
			str(record.get("selected_checked", false)),
			str(record.get("disabled_checked", false)),
			str(record.get("privacy_checked", false)),
			str(record.get("layout_checked", false)),
			str(record.get("passed", false)),
			str(record.get("notes", "")),
		])
	return "\n".join(lines) + "\n"


func _passed_count(records: Array) -> int:
	var count := 0
	for record_variant in records:
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		if bool(record.get("passed", false)):
			count += 1
	return count


func _append_summary(text: String) -> void:
	if summary_label != null:
		var prefix := summary_label.text.strip_edges()
		summary_label.text = text if prefix == "" or prefix == "No cases run yet." else "%s\n%s" % [prefix, text]


func _settle_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await get_tree().process_frame


func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text


func _on_track_entry_selected(entry: Dictionary) -> void:
	_selected_entries.append(entry.duplicate(true))


func _on_track_entry_opened(entry: Dictionary) -> void:
	_opened_entries.append(entry.duplicate(true))


func _on_track_action_requested(action_id: String) -> void:
	if action_id.strip_edges() != "":
		_requested_actions.append(action_id)


func _on_card_slot_selected(slot_id: String) -> void:
	if slot_id.strip_edges() != "":
		_selected_slot_ids.append(slot_id)
