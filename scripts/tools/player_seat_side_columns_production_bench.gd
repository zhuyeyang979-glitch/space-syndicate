extends Control
class_name PlayerSeatSideColumnsProductionBench

const SCREENSHOT_PATH := "res://docs/ui_qa/player_seat_side_columns/player_seat_side_columns_8p.png"
const PUBLIC_ROLE_NAMES := [
	"环港走私议会", "重力矿联董事会", "光合修复会", "星鲸餐饮垄断",
	"幽幕播报社", "赤环航运托拉斯", "黑潮风险基金", "暗礁公证黑市",
]

@export var auto_run := true
@export var quit_on_finish := false

var last_result: Dictionary = {}
var _checks := 0
var _failures: Array[String] = []
var _running := false


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("_run_auto")


func _run_auto() -> void:
	var result := await run_checks()
	if quit_on_finish or DisplayServer.get_name().to_lower() == "headless":
		get_tree().quit(0 if bool(result.get("passed", false)) else 1)


func run_checks() -> Dictionary:
	if _running:
		return last_result.duplicate(true)
	_running = true
	_checks = 0
	_failures.clear()
	var screen := %GameScreen as SpaceSyndicateGameScreen
	_check(screen != null, "real_game_screen_present")
	if screen == null:
		return _finish({})
	screen.apply_state({
		"planet": {"public_player_seat_sources": _public_seat_sources()},
		"player_board": {"identity": "本地玩家", "hand_cards": []},
	})
	for _frame in 6:
		await get_tree().process_frame
	var host := screen.find_child("RoleSeatLayerHost", true, false)
	var map_host := screen.find_child("MapHost", true, false) as Control
	var map_view := screen.find_child("PlanetMapView", true, false) as Control
	var stage_viewport := screen.find_child("PlanetStageViewport", true, false) as Control
	var planet_board := screen.find_child("PlanetBoard", true, false) as Control
	var snapshot: Dictionary = host.call("layout_debug_snapshot") if host != null else {}
	var seats: Array = snapshot.get("seats", []) if snapshot.get("seats", []) is Array else []
	_check(host != null and map_host != null and planet_board != null, "production_planet_seat_composition_present")
	_check(seats.size() == 8, "eight_public_seats_render")
	_check(_column_count(seats, &"left") == 4 and _column_count(seats, &"right") == 4, "eight_seats_split_four_by_four")
	_check(_using_skin_count(seats) == 8, "all_eight_roles_use_real_portrait_skins")
	_check(_no_overlaps(seats), "side_cards_do_not_overlap")
	_check(_outside_map(seats, _control_rect_in(stage_viewport, map_view)), "side_cards_leave_planet_input_clear")
	_check(_all_ignore_mouse(seats), "seat_surfaces_ignore_map_input")
	_check(_semantic_side_mapping(seats), "bottom_maps_left_and_top_maps_right")
	_check(_utilities_suppressed(screen), "utility_rails_and_flow_compass_do_not_overlap_columns")
	_check(map_host.size.x > 240.0 and map_host.size.y > 240.0 and planet_board.size.x > map_host.size.x, "planet_remains_primary_visual")
	_check(_private_tokens_absent(snapshot), "seat_debug_projection_contains_no_private_player_state")
	var screenshot := await _capture_screenshot()
	_check(bool(screenshot.get("passed", false)), "production_screenshot_captured")
	return _finish(screenshot)


func _public_seat_sources() -> Array:
	var result: Array = []
	for index in range(PUBLIC_ROLE_NAMES.size()):
		result.append({
			"player_index": index,
			"public_player_name": "玩家 %02d" % (index + 1),
			"role_name": PUBLIC_ROLE_NAMES[index],
			"player_color": Color.from_hsv(float(index) / float(PUBLIC_ROLE_NAMES.size()), 0.62, 0.96),
			"is_local_player": index == 2,
			"public_status": &"ready",
			"is_publicly_active": index == 4,
		})
	return result


func _column_count(seats: Array, column: StringName) -> int:
	var count := 0
	for seat_variant in seats:
		if StringName((seat_variant as Dictionary).get("column", &"")) == column:
			count += 1
	return count


func _using_skin_count(seats: Array) -> int:
	var count := 0
	for seat_variant in seats:
		if bool((seat_variant as Dictionary).get("using_skin", false)):
			count += 1
	return count


func _no_overlaps(seats: Array) -> bool:
	for first_index in range(seats.size()):
		var first: Rect2 = (seats[first_index] as Dictionary).get("display_rect", Rect2()) as Rect2
		for second_index in range(first_index + 1, seats.size()):
			var second: Rect2 = (seats[second_index] as Dictionary).get("display_rect", Rect2()) as Rect2
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


func _all_ignore_mouse(seats: Array) -> bool:
	for seat_variant in seats:
		if int((seat_variant as Dictionary).get("mouse_filter", -1)) != Control.MOUSE_FILTER_IGNORE:
			return false
	return true


func _semantic_side_mapping(seats: Array) -> bool:
	var bottom_column := ""
	var top_column := ""
	for seat_variant in seats:
		var seat: Dictionary = seat_variant
		match StringName(seat.get("seat_position", &"")):
			&"bottom":
				bottom_column = str(seat.get("column", ""))
			&"top":
				top_column = str(seat.get("column", ""))
	return bottom_column == "left" and top_column == "right"


func _utilities_suppressed(screen: Node) -> bool:
	for node_name in ["PlaytestFlowCompass", "PlanetLeftSpaceRail", "PlanetRightSpaceRail"]:
		var utility := screen.find_child(node_name, true, false) as Control
		if utility == null or utility.visible:
			return false
	return true


func _private_tokens_absent(value: Variant) -> bool:
	var encoded := JSON.stringify(value).to_lower()
	for token in ["cash", "hand", "discard", "hidden_owner", "private_plan", "ai_plan"]:
		if encoded.contains(token):
			return false
	return true


func _capture_screenshot() -> Dictionary:
	var display_name := DisplayServer.get_name().to_lower()
	var driver := RenderingServer.get_current_rendering_driver_name().to_lower()
	if display_name == "headless" or driver == "dummy":
		return {"passed": true, "mode": "dummy_renderer_skipped"}
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return {"passed": false, "reason": "viewport_image_unavailable"}
	var absolute_path := ProjectSettings.globalize_path(SCREENSHOT_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var error := image.save_png(absolute_path)
	return {"passed": error == OK and FileAccess.file_exists(absolute_path), "path": absolute_path, "error": error}


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish(screenshot: Dictionary) -> Dictionary:
	var result := {
		"passed": _failures.is_empty(),
		"checks": _checks,
		"failures": _failures.duplicate(),
		"screenshot": screenshot.duplicate(true),
	}
	last_result = result.duplicate(true)
	_running = false
	print("PLAYER_SEAT_SIDE_COLUMNS_PRODUCTION_BENCH|status=%s|checks=%d|failures=%d|details=%s" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size(), JSON.stringify(_failures)])
	return result
