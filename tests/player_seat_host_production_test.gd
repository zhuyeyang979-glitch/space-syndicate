extends SceneTree

const GAME_SCREEN_SCENE := preload("res://scenes/ui/GameScreen.tscn")
const SEAT_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/public_player_seat_snapshot.gd")
const SEAT_SOURCE_SERVICE_SCRIPT := preload("res://scripts/runtime/player_seat_public_source_service.gd")
const FAKE_PUBLIC_WORLD_SCRIPT := preload("res://tests/fixtures/player_seat_host/fake_public_player_world.gd")

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
	for seat_count in [3, 4, 6, 8]:
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
		_expect(_seat(seats, 2).get("seat_position", &"") == &"bottom", "%d-player local player is fixed at bottom" % seat_count)
		_expect(_right_seats_fit(seats, snapshot.get("host_global_rect", Rect2()) as Rect2), "%d-player right seats stay inside PlanetStageViewport" % seat_count)
		_expect(_seat_rects_are_bounded(seats), "%d-player seat fallback rects stay compact" % seat_count)
		_expect(_all_ignore_mouse(seats), "%d-player seat surfaces ignore map input" % seat_count)
		if seat_count in [4, 6, 8]:
			var top := _seat_by_position(seats, &"top")
			_expect(str(top.get("depth_group", "")) == "back", "%d-player top seat is in BackSeatLayer" % seat_count)
		var bottom := _seat_by_position(seats, &"bottom")
		_expect(str(bottom.get("depth_group", "")) == "front", "%d-player bottom seat is in FrontSeatLayer" % seat_count)
		_expect(_left_variants_are_inward(seats), "%d-player left seats use side_inward portraits" % seat_count)
		_expect(_right_seats_are_mirrored(seats), "%d-player right seats request horizontal mirroring" % seat_count)
		_expect(map_host.size.is_equal_approx(original_map_size), "%d-player host does not shrink the central planet" % seat_count)
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
	_expect(not ResourceLoader.exists("res://scenes/ui/player_seat/PlayerSeatPortraitSkin.tscn"), "host test branch does not require the future Skin resource")
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
	_expect(fallback_count == 3, "missing Skin keeps one independent fallback visual per active seat")
	var fallback_snapshot: Dictionary = host.call("layout_debug_snapshot")
	_expect(_visible_decoration_count(fallback_snapshot) == 3, "missing Skin keeps fallback decoration visible per active seat, not globally")
	host.set("skin_scene_path", "res://tests/fixtures/player_seat_host/FakeMissingPortraitPlayerSeatSkin.tscn")
	host.call("set_seat_descriptors", privacy_descriptors)
	await process_frame
	var missing_portrait_snapshot: Dictionary = host.call("layout_debug_snapshot")
	_expect(_using_skin_count(missing_portrait_snapshot) == 0 and _visible_decoration_count(missing_portrait_snapshot) == 3, "existing Skin scene with missing portrait falls back per seat")
	host.set("skin_scene_path", "res://tests/fixtures/player_seat_host/InvalidPlayerSeatSkin.tscn")
	host.call("set_seat_descriptors", privacy_descriptors)
	await process_frame
	var invalid_skin_snapshot: Dictionary = host.call("layout_debug_snapshot")
	_expect(_using_skin_count(invalid_skin_snapshot) == 0 and _visible_decoration_count(invalid_skin_snapshot) == 3, "Skin scene load/type failure falls back per seat")
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
	var fake_world := FAKE_PUBLIC_WORLD_SCRIPT.new()
	get_root().add_child(fake_world)
	source_service.bind_world(fake_world)
	var public_sources: Array = source_service.compose_sources()
	_expect(public_sources.size() == 4 and bool((public_sources[2] as Dictionary).get("is_local_player", false)), "formal public source service reads authoritative public player accessors")
	var source_text := JSON.stringify(public_sources)
	_expect(not source_text.contains("private_plan") and not source_text.contains("cash") and not source_text.contains("hand"), "formal public source service does not forward private player state")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	_expect(not main_source.contains("func _runtime_public_player_seat_sources"), "main.gd no longer assembles player seat descriptors")
	_expect(not main_source.contains("public_player_seat_sources"), "main.gd no longer wires the production seat source")
	source_service.free()
	fake_world.queue_free()
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
		if rect.size.x > 160.0 or rect.size.y > 100.0:
			print("UNBOUNDED_SEAT: ", seat_variant)
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
