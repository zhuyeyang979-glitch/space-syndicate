extends SceneTree

const GAME_SCREEN_SCENE := preload("res://scenes/ui/GameScreen.tscn")
const SEAT_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/public_player_seat_snapshot.gd")
const SEAT_SOURCE_SERVICE_SCRIPT := preload("res://scripts/runtime/player_seat_public_source_service.gd")
const STABLE_SEAT_POSITIONS := [
	&"left_low", &"right_low", &"left_mid_low", &"right_mid_low",
	&"left_mid_high", &"right_mid_high", &"left_high", &"right_high",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var screen := GAME_SCREEN_SCENE.instantiate() as Control
	get_root().add_child(screen)
	await process_frame
	await process_frame
	var planet_board := screen.find_child("PlanetBoard", true, false) as Control
	var host := screen.find_child("RoleSeatLayerHost", true, false)
	var map_host := screen.find_child("MapHost", true, false) as Control
	var map_view := screen.find_child("PlanetMapView", true, false) as Control
	var stage_viewport := screen.find_child("PlanetStageViewport", true, false) as Control
	var top_track := screen.find_child("TopCommoditySushiTrack", true, false) as Control
	var right_inspector := screen.find_child("RightInspector", true, false) as Control
	var player_board := screen.find_child("PlayerBoard", true, false) as Control
	_expect(planet_board != null and host != null and map_host != null, "production GameScreen loads PlanetBoard, map and RoleSeatLayerHost")
	if planet_board == null or host == null or map_host == null:
		_finish()
		return
	screen.call("apply_state", {
		"planet": {"public_player_seat_sources": _sources(3)},
		"player_board": {"identity": "本地玩家", "hand_cards": []},
	})
	await process_frame
	await process_frame
	var original_map_size := map_host.size
	for seat_count in [3, 4, 5, 6, 7, 8]:
		screen.call("apply_state", {
			"planet": {"public_player_seat_sources": _sources(seat_count)},
			"player_board": {"identity": "本地玩家", "hand_cards": []},
		})
		await process_frame
		await process_frame
		var snapshot: Dictionary = host.call("layout_debug_snapshot")
		var seats: Array = snapshot.get("seats", []) if snapshot.get("seats", []) is Array else []
		_expect(seats.size() == seat_count, "%d-player production host creates exactly %d seats" % [seat_count, seat_count])
		_expect(_unique_player_count(seats) == seat_count, "%d-player production host never duplicates a player" % seat_count)
		_expect(_seat(seats, 2).get("seat_position", &"") == &"left_low", "%d-player local player is fixed at left_low" % seat_count)
		_expect(int(_seat(seats, 2).get("seat_index", -1)) == 0, "%d-player local player owns stable seat zero" % seat_count)
		_expect(_stable_slot_mapping(seats, seat_count), "%d-player seats retain the stable alternating side-slot mapping" % seat_count)
		_expect(_right_seats_fit(seats, snapshot.get("host_global_rect", Rect2()) as Rect2), "%d-player right seats stay inside PlanetStageViewport" % seat_count)
		_expect(_seat_rects_are_bounded(seats), "%d-player seat fallback rects stay compact" % seat_count)
		_expect(_column_count(seats, &"left") == _expected_left_count(seat_count), "%d-player semantic positions resolve into the left side column" % seat_count)
		_expect(_column_count(seats, &"right") == seat_count - _expected_left_count(seat_count), "%d-player semantic positions resolve into the right side column" % seat_count)
		_expect(_seat_display_rects_do_not_overlap(seats), "%d-player side cards do not overlap one another" % seat_count)
		_expect(_seats_stay_outside_map(seats, _control_rect_in(stage_viewport, map_view)), "%d-player side cards do not cover the planet" % seat_count)
		_expect(_resolved_directions_face_inward(seats), "%d-player portraits face inward from both side columns" % seat_count)
		_expect(_all_ignore_mouse(seats), "%d-player seat surfaces ignore map input" % seat_count)
		_expect(_all_front_layer(seats), "%d-player side seats all render in the front presentation layer" % seat_count)
		_expect(_top_full_portrait_count(seats) == 0, "%d-player table keeps full portraits out of the top track" % seat_count)
		_expect(_local_player_scale_is_ten_percent(seats), "%d-player local portrait is enlarged by ten percent" % seat_count)
		_expect(_local_player_is_lowest_left_seat(seats), "%d-player local portrait remains the lowest left seat" % seat_count)
		_expect(_left_variants_are_inward(seats), "%d-player left seats use side_inward portraits" % seat_count)
		_expect(_right_seats_are_mirrored(seats), "%d-player right seats request horizontal mirroring" % seat_count)
		_expect(map_host.size.is_equal_approx(original_map_size), "%d-player host does not shrink the central planet" % seat_count)
		_expect(_side_utilities_are_suppressed(screen), "%d-player side columns do not overlap utility rails or FlowCompass" % seat_count)
		_expect(_seats_do_not_overlap_control(seats, top_track), "%d-player seats stay below the commodity sushi track" % seat_count)
		_expect(_seats_do_not_overlap_control(seats, right_inspector), "%d-player seats stay clear of RightInspector" % seat_count)
		_expect(_seats_do_not_overlap_control(seats, player_board), "%d-player seats stay above PlayerBoard" % seat_count)
		if seat_count in [5, 7]:
			_expect(_column_visual_centers_are_balanced(seats), "%d-player odd side columns keep a balanced visual center" % seat_count)
	_expect(_full_portrait_descendant_count(player_board) == 0, "bottom PlayerBoard does not duplicate the local full portrait")
	if screen.get_parent() == get_root():
		for resolution in [Vector2(1280, 720), Vector2(1600, 960), Vector2(1920, 1080)]:
			screen.size = resolution
			for seat_count in [3, 4, 5, 6, 7, 8]:
				screen.call("apply_state", {
					"planet": {"public_player_seat_sources": _sources(seat_count)},
					"player_board": {"identity": "本地玩家", "hand_cards": []},
				})
				await process_frame
				await process_frame
				var resolution_snapshot: Dictionary = host.call("layout_debug_snapshot")
				var resolution_seats: Array = resolution_snapshot.get("seats", []) if resolution_snapshot.get("seats", []) is Array else []
				var label := "%dx%d/%dp" % [int(resolution.x), int(resolution.y), seat_count]
				_expect(resolution_seats.size() == seat_count, "%s renders every side seat" % label)
				_expect(_seat_display_rects_do_not_overlap(resolution_seats), "%s keeps side seats separated" % label)
				_expect(_seats_stay_outside_map(resolution_seats, _control_rect_in(stage_viewport, map_view)), "%s preserves planet input area" % label)
				_expect(_seats_do_not_overlap_control(resolution_seats, top_track), "%s stays below commodity track" % label)
				_expect(_seats_do_not_overlap_control(resolution_seats, right_inspector), "%s stays clear of RightInspector" % label)
				_expect(_seats_do_not_overlap_control(resolution_seats, player_board), "%s stays above PlayerBoard" % label)
	var privacy_sources := _sources(3)
	(privacy_sources[1] as Dictionary).merge({
		"true_owner": 1,
		"hidden_owner": 1,
		"cash": 999999,
		"hand_size": 7,
		"ai_plan": "secret",
		"is_publicly_active": true,
		"public_activity_is_anonymous": true,
	}, true)
	var privacy_descriptors: Array = SEAT_SNAPSHOT_SCRIPT.new().compose(privacy_sources)
	var encoded := JSON.stringify(privacy_descriptors)
	_expect(not encoded.contains("true_owner") and not encoded.contains("hidden_owner") and not encoded.contains("cash") and not encoded.contains("hand") and not encoded.contains("ai_plan"), "seat descriptors strip private and hidden fields")
	_expect(not bool(_seat(privacy_descriptors, 1).get("is_publicly_active", true)), "anonymous card activity cannot reveal the true actor through seat highlight")
	_expect(ResourceLoader.exists("res://scenes/ui/player_seat/PlayerSeatPortraitSkin.tscn"), "merged production includes the reusable player seat Skin resource")
	screen.call("apply_state", {
		"planet": {"public_player_seat_sources": privacy_sources},
		"player_board": {"identity": "本地玩家", "hand_cards": []},
	})
	await process_frame
	await process_frame
	var fallback_count := 0
	for seat_variant in (host.call("layout_debug_snapshot") as Dictionary).get("seats", []):
		if seat_variant is Dictionary and not bool((seat_variant as Dictionary).get("using_skin", true)):
			fallback_count += 1
	_expect(fallback_count == 3, "unmatched portrait roles keep one independent fallback visual per active seat")
	var fallback_snapshot: Dictionary = host.call("layout_debug_snapshot")
	_expect(_visible_decoration_count(fallback_snapshot) == 0, "side-column fallback cards retire the old orbit seat decorations")
	host.set("skin_scene_path", "res://tests/fixtures/player_seat_host/FakeMissingPortraitPlayerSeatSkin.tscn")
	host.call("set_seat_descriptors", privacy_descriptors)
	await process_frame
	var missing_portrait_snapshot: Dictionary = host.call("layout_debug_snapshot")
	_expect(_using_skin_count(missing_portrait_snapshot) == 0 and _visible_decoration_count(missing_portrait_snapshot) == 0, "existing Skin scene with missing portrait falls back in the side column")
	host.set("skin_scene_path", "res://tests/fixtures/player_seat_host/InvalidPlayerSeatSkin.tscn")
	host.call("set_seat_descriptors", privacy_descriptors)
	await process_frame
	var invalid_skin_snapshot: Dictionary = host.call("layout_debug_snapshot")
	_expect(_using_skin_count(invalid_skin_snapshot) == 0 and _visible_decoration_count(invalid_skin_snapshot) == 0, "Skin scene load/type failure falls back in the side column")
	host.set("skin_scene_path", "res://tests/fixtures/player_seat_host/FakeAvailablePlayerSeatSkin.tscn")
	host.call("set_seat_descriptors", privacy_descriptors)
	await process_frame
	var available_skin_snapshot: Dictionary = host.call("layout_debug_snapshot")
	_expect(_using_skin_count(available_skin_snapshot) == 3 and _visible_decoration_count(available_skin_snapshot) == 0, "descriptor adapter enables Skin only after apply_public_view_model succeeds")
	var skin_node := screen.find_child("PlayerSeat_2", true, false)
	var received: Dictionary = skin_node.get_meta("received_view_model", {}) if skin_node != null else {}
	_expect(_skin_view_model_contract_is_safe(received), "descriptor adapter supplies the Skin public field contract without hidden data")
	host.set("skin_scene_path", "res://scenes/ui/player_seat/PlayerSeatPortraitSkin.tscn")
	host.call("set_seat_descriptors", privacy_descriptors)
	await process_frame
	var back_layer := screen.find_child("BackSeatLayer", true, false) as Control
	var front_layer := screen.find_child("FrontSeatLayer", true, false) as Control
	_expect(back_layer != null and front_layer != null and back_layer.mouse_filter == Control.MOUSE_FILTER_IGNORE and front_layer.mouse_filter == Control.MOUSE_FILTER_IGNORE, "both production seat layers ignore pointer input")
	var source_service := SEAT_SOURCE_SERVICE_SCRIPT.new()
	var empty_projection := WorldSessionPublicProjection.new()
	_expect(source_service.compose_sources(empty_projection, -1).is_empty(), "formal public source service allows zero pre-session seats")
	var public_projection := WorldSessionPublicProjection.new()
	public_projection.revision = 1
	public_projection.players = _sources(4)
	var public_sources: Array = source_service.compose_sources(public_projection, 2)
	_expect(public_sources.size() == 4 and bool((public_sources[2] as Dictionary).get("is_local_player", false)), "formal public source service reads the authoritative public session projection")
	var source_text := JSON.stringify(public_sources)
	_expect(not source_text.contains("private_plan") and not source_text.contains("cash") and not source_text.contains("hand"), "formal public source service does not forward private player state")
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	var service_source := FileAccess.get_file_as_string("res://scripts/runtime/player_seat_public_source_service.gd")
	_expect(not service_source.contains("bind_world") and not service_source.contains("_safe_world_call") and not service_source.contains("_player_role_card_for_index"), "public seat service has no dynamic Main world or role lookup")
	_expect(coordinator_source.contains("_player_seat_public_source_node() as PlayerSeatPublicSourceService"), "Coordinator injects the scene-owned seat source into the real presentation query")
	source_service.free()
	screen.queue_free()
	await process_frame
	_finish()


func _sources(count: int) -> Array:
	var entries: Array = []
	for index in range(count):
		entries.append({
			"player_index": index,
			"public_player_name": "玩家%d" % (index + 1),
			"role_name": "公开角色%d" % (index + 1),
			"player_color": Color.from_hsv(float(index) / float(count), 0.65, 0.95),
			"is_local_player": index == 2,
			"public_status": &"ready",
			"is_publicly_active": false,
		})
	return entries


func _seat(seats: Array, player_index: int) -> Dictionary:
	for seat_variant in seats:
		if seat_variant is Dictionary and int((seat_variant as Dictionary).get("player_index", -1)) == player_index:
			return seat_variant as Dictionary
	return {}


func _seat_by_position(seats: Array, position: StringName) -> Dictionary:
	for seat_variant in seats:
		if seat_variant is Dictionary and StringName((seat_variant as Dictionary).get("seat_position", &"")) == position:
			return seat_variant as Dictionary
	return {}


func _unique_player_count(seats: Array) -> int:
	var seen := {}
	for seat_variant in seats:
		if seat_variant is Dictionary:
			seen[int((seat_variant as Dictionary).get("player_index", -1))] = true
	return seen.size()


func _stable_slot_mapping(seats: Array, seat_count: int) -> bool:
	if seats.size() != seat_count:
		return false
	for seat_index in range(seat_count):
		var seat: Dictionary = seats[seat_index] if seats[seat_index] is Dictionary else {}
		if int(seat.get("seat_index", -1)) != seat_index \
				or StringName(seat.get("seat_position", &"")) != STABLE_SEAT_POSITIONS[seat_index]:
			return false
	return true


func _all_front_layer(seats: Array) -> bool:
	for seat_variant in seats:
		if str((seat_variant as Dictionary).get("render_layer", "")) != "FrontSeatLayer":
			return false
	return true


func _top_full_portrait_count(seats: Array) -> int:
	var count := 0
	for seat_variant in seats:
		var position := str((seat_variant as Dictionary).get("seat_position", ""))
		if position == "top" or position.begins_with("top_"):
			count += 1
	return count


func _local_player_scale_is_ten_percent(seats: Array) -> bool:
	for seat_variant in seats:
		var seat: Dictionary = seat_variant
		if bool(seat.get("is_local_player", false)):
			return is_equal_approx(float(seat.get("visual_scale", 0.0)), 1.10)
	return false


func _local_player_is_lowest_left_seat(seats: Array) -> bool:
	var local_row := -1
	var highest_row := -1
	for seat_variant in seats:
		var seat: Dictionary = seat_variant
		if StringName(seat.get("column", &"")) != &"left":
			continue
		var row := int(seat.get("column_row", -1))
		highest_row = maxi(highest_row, row)
		if bool(seat.get("is_local_player", false)):
			local_row = row
	return local_row >= 0 and local_row == highest_row


func _seats_do_not_overlap_control(seats: Array, control: Control) -> bool:
	if control == null or not control.visible:
		return true
	var control_rect := control.get_global_rect()
	for seat_variant in seats:
		var seat_rect: Rect2 = (seat_variant as Dictionary).get("global_rect", Rect2()) as Rect2
		if seat_rect.intersects(control_rect):
			return false
	return true


func _column_visual_centers_are_balanced(seats: Array) -> bool:
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


func _right_seats_fit(seats: Array, host_rect: Rect2) -> bool:
	for seat_variant in seats:
		var seat: Dictionary = seat_variant if seat_variant is Dictionary else {}
		if not str(seat.get("seat_position", "")).begins_with("right_"):
			continue
		var rect: Rect2 = seat.get("global_rect", Rect2()) as Rect2
		if rect.end.x > host_rect.end.x + 0.5:
			return false
	return true


func _all_ignore_mouse(seats: Array) -> bool:
	for seat_variant in seats:
		if int((seat_variant as Dictionary).get("mouse_filter", -1)) != Control.MOUSE_FILTER_IGNORE:
			return false
	return true


func _seat_rects_are_bounded(seats: Array) -> bool:
	for seat_variant in seats:
		var rect: Rect2 = (seat_variant as Dictionary).get("rect", Rect2()) as Rect2
		var display_rect: Rect2 = (seat_variant as Dictionary).get("display_rect", Rect2()) as Rect2
		if rect.size.x > 132.0 or rect.size.y > 92.0 or display_rect.size.x > 132.5 or display_rect.size.y > 92.5:
			print("UNBOUNDED_SEAT: ", seat_variant)
			return false
	return true


func _expected_left_count(seat_count: int) -> int:
	match seat_count:
		3, 4:
			return 2
		6:
			return 3
		8:
			return 4
	return int(ceil(float(seat_count) * 0.5))


func _column_count(seats: Array, column: StringName) -> int:
	var count := 0
	for seat_variant in seats:
		if StringName((seat_variant as Dictionary).get("column", &"")) == column:
			count += 1
	return count


func _seat_display_rects_do_not_overlap(seats: Array) -> bool:
	for first_index in range(seats.size()):
		var first_rect: Rect2 = (seats[first_index] as Dictionary).get("display_rect", Rect2()) as Rect2
		for second_index in range(first_index + 1, seats.size()):
			var second_rect: Rect2 = (seats[second_index] as Dictionary).get("display_rect", Rect2()) as Rect2
			if first_rect.intersects(second_rect):
				return false
	return true


func _seats_stay_outside_map(seats: Array, map_rect: Rect2) -> bool:
	for seat_variant in seats:
		var seat: Dictionary = seat_variant
		var rect: Rect2 = seat.get("display_rect", Rect2()) as Rect2
		if rect.intersects(map_rect):
			return false
	return true


func _control_rect_in(ancestor: Control, child: Control) -> Rect2:
	if ancestor == null or child == null:
		return Rect2()
	return Rect2(child.global_position - ancestor.global_position, child.size * child.scale)


func _resolved_directions_face_inward(seats: Array) -> bool:
	for seat_variant in seats:
		var seat: Dictionary = seat_variant
		var column := StringName(seat.get("column", &""))
		var direction := str(seat.get("resolved_inward_direction", ""))
		if direction != ("left" if column == &"left" else "right"):
			return false
	return true


func _side_utilities_are_suppressed(screen: Node) -> bool:
	for node_name in ["PlaytestFlowCompass", "PlanetLeftSpaceRail", "PlanetRightSpaceRail"]:
		var utility := screen.find_child(node_name, true, false) as Control
		if utility == null or utility.visible or not bool(utility.get_meta("suppressed_for_player_side_columns", false)):
			return false
	return true


func _left_variants_are_inward(seats: Array) -> bool:
	for seat_variant in seats:
		var seat: Dictionary = seat_variant
		if str(seat.get("seat_position", "")).begins_with("left_") and StringName(seat.get("portrait_variant", &"")) != &"side_inward":
			return false
	return true


func _right_seats_are_mirrored(seats: Array) -> bool:
	for seat_variant in seats:
		var seat: Dictionary = seat_variant
		if str(seat.get("seat_position", "")).begins_with("right_") and not bool(seat.get("mirror_h", false)):
			return false
	return true


func _using_skin_count(snapshot: Dictionary) -> int:
	var count := 0
	for seat_variant in snapshot.get("seats", []):
		if seat_variant is Dictionary and bool((seat_variant as Dictionary).get("using_skin", false)):
			count += 1
	return count


func _visible_decoration_count(snapshot: Dictionary) -> int:
	var count := 0
	var visibility: Dictionary = snapshot.get("fallback_decoration_visibility", {}) if snapshot.get("fallback_decoration_visibility", {}) is Dictionary else {}
	for value in visibility.values():
		if bool(value):
			count += 1
	return count


func _skin_view_model_contract_is_safe(view_model: Dictionary) -> bool:
	var required := [
		"seat_index", "player_display_name", "public_role_name", "player_color",
		"is_local_player", "is_publicly_active", "is_bankrupt", "is_disconnected",
		"public_status", "inward_direction", "depth_class", "anonymous_action_active",
	]
	for key in required:
		if not view_model.has(key):
			return false
	var encoded := JSON.stringify(view_model)
	for forbidden in ["cash", "hand", "true_owner", "hidden_owner", "ai_plan"]:
		if encoded.contains(forbidden):
			return false
	return true


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % label)
	else:
		_failures.append(label)
		push_error("FAIL: %s" % label)


func _finish() -> void:
	print("PLAYER_SEAT_HOST_PRODUCTION_TEST checks=%d failures=%d" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
