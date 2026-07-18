extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const OUTPUT_DIR := "res://docs/ui_qa/player_seat_side_columns"
const RESULT_PATH := OUTPUT_DIR + "/player_seat_side_columns_result.json"
const CAPTURE_SIZE := Vector2i(1600, 960)
const PLAYER_DEFAULT_SAVE_PATH := "user://space_syndicate_current_run.save"
const SAVE_COORDINATOR_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController/GameSaveRuntimeCoordinator"
const STABLE_SEAT_POSITIONS := [
	&"left_low", &"right_low", &"left_mid_low", &"right_mid_low",
	&"left_mid_high", &"right_mid_high", &"left_high", &"right_high",
]
const PUBLIC_ROLE_NAMES := [
	"环港走私议会", "重力矿联董事会", "光合修复会", "星鲸餐饮垄断",
	"幽幕播报社", "赤环航运托拉斯", "黑潮风险基金", "暗礁公证黑市",
]

var _checks := 0
var _failures: Array[String] = []
var _captures: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	DisplayServer.window_set_size(CAPTURE_SIZE)
	root.size = CAPTURE_SIZE
	var default_save_before := _save_file_snapshot(PLAYER_DEFAULT_SAVE_PATH)
	for player_count in [3, 4, 5, 6, 7, 8]:
		await _capture_formal_session(player_count)
	var default_save_after := _save_file_snapshot(PLAYER_DEFAULT_SAVE_PATH)
	_check(default_save_before == default_save_after, "player_default_save_unchanged")
	_write_result(default_save_before, default_save_after)
	print("PLAYER_SEAT_FORMAL_CAPTURE|status=%s|checks=%d|failures=%d|captures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
		_captures.size(),
	])
	quit(0 if _failures.is_empty() else 1)


func _capture_formal_session(player_count: int) -> void:
	var qa_save_path := "user://test_runs/player_seat_side_columns_%dp.save" % player_count
	_cleanup_save_artifacts(qa_save_path)
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	_check(packed != null, "%dp_formal_main_loads" % player_count)
	if packed == null:
		return
	var main := packed.instantiate()
	var save_coordinator := main.get_node_or_null(SAVE_COORDINATOR_PATH)
	var save_override_ready := save_coordinator != null \
		and save_coordinator.has_method("set_qa_default_save_path_override") \
		and bool(save_coordinator.call("set_qa_default_save_path_override", qa_save_path))
	_check(save_override_ready, "%dp_qa_save_override_before_tree" % player_count)
	if not save_override_ready:
		main.free()
		return
	root.add_child(main)
	await _pump_frames(12)
	main.set("configured_player_count", player_count)
	main.set("configured_ai_player_count", player_count - 1)
	main.set("configured_role_indices", _indices(player_count))
	main.set("configured_starter_monster_indices", _indices(player_count))
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	if coordinator != null and coordinator.has_method("clear_runtime_scenario"):
		coordinator.call("clear_runtime_scenario")
	main.call("_new_game")
	main.call("_close_menu")
	var host := main.find_child("RoleSeatLayerHost", true, false)
	var ready := await _wait_for_seat_count(host, player_count, 180)
	_check(ready, "%dp_formal_session_renders_all_seats" % player_count)
	if main.has_method("_sync_runtime_game_screen"):
		main.call("_sync_runtime_game_screen", true)
	await _pump_frames(12)
	var snapshot: Dictionary = host.call("layout_debug_snapshot") if host != null else {}
	var seats: Array = snapshot.get("seats", []) if snapshot.get("seats", []) is Array else []
	var screen := main.find_child("RuntimeGameScreen", true, false) as Control
	var map_view := main.find_child("PlanetMapView", true, false) as Control
	var stage := main.find_child("PlanetStageViewport", true, false) as Control
	var top_track := main.find_child("TopCommoditySushiTrack", true, false) as Control
	var inspector := main.find_child("RightInspector", true, false) as Control
	var player_board := main.find_child("PlayerBoard", true, false) as Control
	_check(main.scene_file_path == MAIN_SCENE_PATH and screen != null, "%dp_uses_formal_main_scene" % player_count)
	_check(seats.size() == player_count, "%dp_exact_seat_count" % player_count)
	_check(_unique_player_count(seats) == player_count, "%dp_unique_player_indices" % player_count)
	_check(_local_count(seats) == 1, "%dp_exactly_one_local_player" % player_count)
	_check(_stable_mapping(seats, player_count), "%dp_stable_side_slot_mapping" % player_count)
	_check(_column_count(seats, &"left") == int(ceil(float(player_count) * 0.5)), "%dp_left_column_count" % player_count)
	_check(_column_count(seats, &"right") == int(floor(float(player_count) * 0.5)), "%dp_right_column_count" % player_count)
	_check(_local_is_left_low(seats), "%dp_local_player_left_low" % player_count)
	_check(_skin_fallback_mutually_exclusive(main, seats), "%dp_skin_fallback_mutually_exclusive" % player_count)
	_check(bool(_local_seat(seats).get("using_skin", false)), "%dp_local_player_uses_role_portrait_skin" % player_count)
	_check(_local_marker_visible(main), "%dp_local_player_you_marker" % player_count)
	_check(_private_tokens_absent(snapshot), "%dp_private_field_leak_zero" % player_count)
	_check(_seat_rects_do_not_overlap(seats), "%dp_seat_overlap_zero" % player_count)
	_check(_outside_map(seats, _control_rect_in(stage, map_view)), "%dp_planet_input_area_clear" % player_count)
	_check(_seats_do_not_overlap_control(seats, top_track), "%dp_commodity_track_overlap_zero" % player_count)
	_check(_seats_do_not_overlap_control(seats, inspector), "%dp_right_inspector_overlap_zero" % player_count)
	_check(_seats_do_not_overlap_control(seats, player_board), "%dp_player_board_overlap_zero" % player_count)
	_check(_full_portrait_descendant_count(player_board) == 0, "%dp_player_board_full_portrait_duplicate_zero" % player_count)
	_check(_all_mouse_ignore(seats), "%dp_map_input_block_zero" % player_count)
	_check(_visible_text_is_clean(main), "%dp_visible_text_has_no_qa_or_missing_marker" % player_count)
	if player_count in [5, 7]:
		_check(_column_centers_balanced(seats), "%dp_odd_column_visual_balance" % player_count)
	var capture := await _save_capture(player_count)
	_check(bool(capture.get("saved", false)), "%dp_formal_png_saved" % player_count)
	_check(bool(capture.get("pixel_complete", false)), "%dp_formal_png_pixel_complete" % player_count)
	_captures.append({
		"player_count": player_count,
		"scene": MAIN_SCENE_PATH,
		"seat_count": seats.size(),
		"left_count": _column_count(seats, &"left"),
		"right_count": _column_count(seats, &"right"),
		"local_slot": str(_local_seat(seats).get("seat_position", "")),
		"local_player_index": int(_local_seat(seats).get("player_index", -1)),
		"capture": capture,
	})
	main.queue_free()
	await _pump_frames(6)
	_cleanup_save_artifacts(qa_save_path)
	_check(_save_artifacts(qa_save_path).is_empty(), "%dp_qa_save_artifacts_cleaned" % player_count)


func _indices(count: int) -> Array[int]:
	var result: Array[int] = []
	for index in range(count):
		result.append(index)
	return result


func _wait_for_seat_count(host: Node, expected: int, max_frames: int) -> bool:
	for _frame in range(max_frames):
		if host != null and host.has_method("layout_debug_snapshot"):
			var snapshot: Dictionary = host.call("layout_debug_snapshot")
			if int(snapshot.get("seat_count", -1)) == expected:
				return true
		await process_frame
	return false


func _pump_frames(count: int) -> void:
	for _frame in range(count):
		await process_frame


func _stable_mapping(seats: Array, count: int) -> bool:
	if seats.size() != count:
		return false
	for seat_index in range(count):
		var seat: Dictionary = seats[seat_index] if seats[seat_index] is Dictionary else {}
		if int(seat.get("seat_index", -1)) != seat_index \
				or StringName(seat.get("seat_position", &"")) != STABLE_SEAT_POSITIONS[seat_index]:
			return false
	return true


func _unique_player_count(seats: Array) -> int:
	var seen := {}
	for seat_variant in seats:
		seen[int((seat_variant as Dictionary).get("player_index", -1))] = true
	return seen.size()


func _local_count(seats: Array) -> int:
	var count := 0
	for seat_variant in seats:
		if bool((seat_variant as Dictionary).get("is_local_player", false)):
			count += 1
	return count


func _local_seat(seats: Array) -> Dictionary:
	for seat_variant in seats:
		if bool((seat_variant as Dictionary).get("is_local_player", false)):
			return seat_variant as Dictionary
	return {}


func _local_is_left_low(seats: Array) -> bool:
	var local := _local_seat(seats)
	return int(local.get("seat_index", -1)) == 0 \
		and StringName(local.get("seat_position", &"")) == &"left_low" \
		and is_equal_approx(float(local.get("visual_scale", 0.0)), 1.10)


func _column_count(seats: Array, column: StringName) -> int:
	var count := 0
	for seat_variant in seats:
		if StringName((seat_variant as Dictionary).get("column", &"")) == column:
			count += 1
	return count


func _skin_fallback_mutually_exclusive(main: Node, seats: Array) -> bool:
	for seat_variant in seats:
		var seat: Dictionary = seat_variant
		var node := main.find_child("PlayerSeat_%d" % int(seat.get("player_index", -1)), true, false)
		if node == null:
			return false
		var reports_skin := bool(seat.get("using_skin", false))
		var is_skin_node := node.has_method("apply_public_view_model")
		var is_fallback_node := node.has_method("set_seat_descriptor")
		if is_skin_node == is_fallback_node or reports_skin != is_skin_node:
			return false
	return true


func _local_marker_visible(main: Node) -> bool:
	var local := main.find_child("PlayerSeat_0", true, false)
	if local == null or not local.has_method("public_debug_snapshot"):
		return false
	return bool((local.call("public_debug_snapshot") as Dictionary).get("local_marker_visible", false))


func _private_tokens_absent(value: Variant) -> bool:
	var encoded := JSON.stringify(value).to_lower()
	for token in ["cash", "hand", "discard", "hidden_owner", "private_intel", "private_plan", "ai_plan"]:
		if encoded.contains(token):
			return false
	return true


func _seat_rects_do_not_overlap(seats: Array) -> bool:
	for first_index in range(seats.size()):
		var first: Rect2 = (seats[first_index] as Dictionary).get("global_rect", Rect2()) as Rect2
		for second_index in range(first_index + 1, seats.size()):
			var second: Rect2 = (seats[second_index] as Dictionary).get("global_rect", Rect2()) as Rect2
			if first.intersects(second):
				return false
	return true


func _outside_map(seats: Array, map_rect: Rect2) -> bool:
	for seat_variant in seats:
		var rect: Rect2 = (seat_variant as Dictionary).get("display_rect", Rect2()) as Rect2
		if rect.intersects(map_rect):
			return false
	return true


func _control_rect_in(ancestor: Control, child: Control) -> Rect2:
	if ancestor == null or child == null:
		return Rect2()
	return Rect2(child.global_position - ancestor.global_position, child.size * child.scale)


func _seats_do_not_overlap_control(seats: Array, control: Control) -> bool:
	if control == null or not control.visible:
		return true
	var rect := control.get_global_rect()
	for seat_variant in seats:
		if ((seat_variant as Dictionary).get("global_rect", Rect2()) as Rect2).intersects(rect):
			return false
	return true


func _all_mouse_ignore(seats: Array) -> bool:
	for seat_variant in seats:
		if int((seat_variant as Dictionary).get("mouse_filter", -1)) != Control.MOUSE_FILTER_IGNORE:
			return false
	return true


func _column_centers_balanced(seats: Array) -> bool:
	var left := _column_bounds(seats, &"left")
	var right := _column_bounds(seats, &"right")
	return left.size.y > 0.0 and right.size.y > 0.0 and absf(left.get_center().y - right.get_center().y) <= 2.0


func _column_bounds(seats: Array, column: StringName) -> Rect2:
	var result := Rect2()
	var initialized := false
	for seat_variant in seats:
		var seat: Dictionary = seat_variant
		if StringName(seat.get("column", &"")) != column:
			continue
		var rect: Rect2 = seat.get("global_rect", Rect2()) as Rect2
		result = result.merge(rect) if initialized else rect
		initialized = true
	return result


func _full_portrait_descendant_count(node: Node) -> int:
	if node == null:
		return 0
	var count := 1 if node is PlayerSeatPortraitSkin else 0
	for child in node.get_children():
		count += _full_portrait_descendant_count(child)
	return count


func _visible_text_is_clean(node: Node) -> bool:
	if node is Control and not (node as Control).is_visible_in_tree():
		return true
	var values: Array[String] = []
	if node is Label:
		values.append((node as Label).text)
	elif node is Button:
		values.append((node as Button).text)
	if node is Control:
		values.append((node as Control).tooltip_text)
	for value in values:
		var normalized := value.to_lower()
		if normalized.contains("missing") or normalized.contains("res://") or normalized.contains("user://") or normalized.contains("qa_"):
			return false
	for child in node.get_children():
		if not _visible_text_is_clean(child):
			return false
	return true


func _save_capture(player_count: int) -> Dictionary:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		return {"saved": false, "pixel_complete": false, "reason": "empty_viewport"}
	var path := "%s/player_seat_side_columns_%dp.png" % [OUTPUT_DIR, player_count]
	var error := image.save_png(path)
	var pixel_metrics := _pixel_metrics(image)
	return {
		"saved": error == OK and FileAccess.file_exists(path),
		"pixel_complete": image.get_size() == CAPTURE_SIZE and float(pixel_metrics.get("nonblack_ratio", 0.0)) >= 0.95 and float(pixel_metrics.get("bright_ratio", 0.0)) >= 0.08,
		"path": ProjectSettings.globalize_path(path),
		"size": {"x": image.get_width(), "y": image.get_height()},
		"nonblack_ratio": pixel_metrics.get("nonblack_ratio", 0.0),
		"bright_ratio": pixel_metrics.get("bright_ratio", 0.0),
		"error": error,
	}


func _pixel_metrics(image: Image) -> Dictionary:
	var sampled := 0
	var nonblack := 0
	var bright := 0
	for y in range(0, image.get_height(), 8):
		for x in range(0, image.get_width(), 8):
			var color := image.get_pixel(x, y)
			sampled += 1
			if color.r + color.g + color.b > 0.025:
				nonblack += 1
			if maxf(color.r, maxf(color.g, color.b)) > 0.20:
				bright += 1
	return {
		"nonblack_ratio": float(nonblack) / float(maxi(1, sampled)),
		"bright_ratio": float(bright) / float(maxi(1, sampled)),
	}


func _save_file_snapshot(path: String) -> Dictionary:
	var absolute := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute):
		return {"exists": false}
	return {
		"exists": true,
		"size": FileAccess.get_file_as_bytes(absolute).size(),
		"modified": FileAccess.get_modified_time(absolute),
		"sha256": FileAccess.get_sha256(absolute),
	}


func _save_artifacts(path: String) -> Array[String]:
	var result: Array[String] = []
	for suffix in ["", ".bak", ".tmp", ".journal"]:
		var candidate := ProjectSettings.globalize_path(path + suffix)
		if FileAccess.file_exists(candidate):
			result.append(candidate)
	return result


func _cleanup_save_artifacts(path: String) -> void:
	for candidate in _save_artifacts(path):
		DirAccess.remove_absolute(candidate)


func _write_result(default_before: Dictionary, default_after: Dictionary) -> void:
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file == null:
		_failures.append("result_file_open_failed")
		return
	file.store_string(JSON.stringify({
		"status": "PASS" if _failures.is_empty() else "FAIL",
		"scene": MAIN_SCENE_PATH,
		"resolution": {"x": CAPTURE_SIZE.x, "y": CAPTURE_SIZE.y},
		"checks": _checks,
		"failures": _failures,
		"captures": _captures,
		"player_default_save_before": default_before,
		"player_default_save_after": default_after,
	}, "  "))
	file.close()


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(label)
	push_error("PLAYER_SEAT_FORMAL_CAPTURE_FAIL: %s" % label)
