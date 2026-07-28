extends SceneTree

const SURFACE_SCENE := preload("res://scenes/ui/v07/V07ContextualTableSurface.tscn")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var surface_scene := FileAccess.get_file_as_string("res://scenes/ui/v07/V07ContextualTableSurface.tscn")
	var stage_scene := FileAccess.get_file_as_string("res://scenes/ui/v07/V07ReferencePlanetStage.tscn")
	var map_scene := FileAccess.get_file_as_string("res://scenes/ui/v07/V07ReferencePlanetMapView.tscn")
	_expect(not surface_scene.contains("res://scenes/ui/PlanetBoard.tscn"), "reference surface has no production PlanetBoard dependency")
	_expect(not stage_scene.contains("RoleSeatLayerHost") and not map_scene.contains("RoleSeatLayerHost"), "reference planet composition has no production player-position host")
	_expect(not map_scene.contains("BackSeatLayer") and not map_scene.contains("FrontSeatLayer"), "reference planet composition has no rear or front player-position layers")
	_expect(map_scene.contains("sceneized_visual_cutover_enabled = true") and map_scene.contains("legacy_draw_fallback_enabled = false"), "reference map locks the sceneized path and disables legacy drawing")

	for viewport_size in [Vector2i(1366, 768), Vector2i(1920, 1080)]:
		await _verify_runtime_surface(viewport_size)

	_finish()


func _verify_runtime_surface(viewport_size: Vector2i) -> void:
	root.size = viewport_size
	var surface := SURFACE_SCENE.instantiate() as V07ContextualTableSurface
	root.add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	surface.position = Vector2.ZERO
	surface.size = Vector2(viewport_size)
	await process_frame
	await process_frame

	for count in [3, 4, 5, 6, 8]:
		_expect(surface.apply_player_roster({"players": _players(count)}), "%d-player authorized roster applies at %s" % [count, viewport_size])
		_expect(int(surface.debug_snapshot().get("roster_columns", 0)) == (1 if count <= 4 else 2), "%d-player roster uses its responsive column rule at %s" % [count, viewport_size])

	var reversed := _players(8)
	reversed.reverse()
	_expect(surface.apply_player_roster({"players": reversed}), "reordered delivery remains a valid authorized roster at %s" % viewport_size)
	var snapshot := surface.debug_snapshot()
	_expect(snapshot.get("roster_player_ids", []) == ["player-0", "player-1", "player-2", "player-3", "player-4", "player-5", "player-6", "player-7"], "public authority order is stable at %s" % viewport_size)
	_expect(str(snapshot.get("viewer_player_id", "")) == "player-7" and int(snapshot.get("viewer_marker_count", -1)) == 1, "viewer marker is unique and does not rotate public order at %s" % viewport_size)
	_expect(int(snapshot.get("reference_player_roster_source_count", -1)) == 1, "one roster source owns player placement at %s" % viewport_size)
	_expect(int(snapshot.get("orbit_player_marker_count", -1)) == 0, "orbit player marker count is zero at %s" % viewport_size)
	_expect(int(snapshot.get("orbit_radial_spoke_count", -1)) == 0, "positional radial spoke count is zero at %s" % viewport_size)
	_expect(int(snapshot.get("left_right_seat_layer_count", -1)) == 0, "left/right player-position layer count is zero at %s" % viewport_size)
	_expect(bool(snapshot.get("roster_focus_links_valid", false)), "keyboard focus graph is complete at %s" % viewport_size)

	var inspected: Array[String] = []
	surface.player_inspection_requested.connect(func(player_id: String) -> void:
		inspected.append(player_id)
	)
	_expect(surface.request_player_inspection("player-3"), "public roster inspection is available at %s" % viewport_size)
	_expect(inspected == ["player-3"], "roster inspection emits only one public player id at %s" % viewport_size)
	_expect(int(surface.debug_snapshot().get("inspected_roster_button_count", -1)) == 1, "inspected roster entry has one persistent visual selection at %s" % viewport_size)
	var keyboard_button := _roster_button(surface, "player-5")
	_expect(keyboard_button != null, "authorized roster entry exposes a focusable button at %s" % viewport_size)
	if keyboard_button != null:
		keyboard_button.grab_focus()
		await process_frame
		var pressed := InputEventKey.new()
		pressed.keycode = KEY_ENTER
		pressed.pressed = true
		Input.parse_input_event(pressed)
		await process_frame
		var released := InputEventKey.new()
		released.keycode = KEY_ENTER
		released.pressed = false
		Input.parse_input_event(released)
		await process_frame
	_expect(inspected == ["player-3", "player-5"], "focused Enter activates public roster inspection at %s" % viewport_size)
	_expect(str(surface.debug_snapshot().get("last_inspected_player_id", "")) == "player-5" and int(surface.debug_snapshot().get("inspected_roster_button_count", -1)) == 1, "keyboard inspection moves the single visual selection at %s" % viewport_size)
	_expect(not surface.request_player_inspection("private-player"), "unknown/private player inspection fails closed at %s" % viewport_size)

	var missing_order := _players(3)
	(missing_order[0] as Dictionary).erase("public_order_index")
	_expect(not surface.apply_player_roster({"players": missing_order}), "display layer refuses to infer missing player order at %s" % viewport_size)
	var duplicate_order := _players(3)
	(duplicate_order[1] as Dictionary)["public_order_index"] = 0
	_expect(not surface.apply_player_roster({"players": duplicate_order}), "duplicate public order fails closed at %s" % viewport_size)
	var missing_viewer := _players(3)
	for player_variant in missing_viewer:
		(player_variant as Dictionary)["is_viewer"] = false
	_expect(not surface.apply_player_roster({"players": missing_viewer}), "missing viewer binding fails closed at %s" % viewport_size)
	var duplicate_viewer := _players(3)
	(duplicate_viewer[0] as Dictionary)["is_viewer"] = true
	_expect(not surface.apply_player_roster({"players": duplicate_viewer}), "duplicate viewer binding fails closed at %s" % viewport_size)
	var hostile := _players(3)
	(hostile[0] as Dictionary)["hidden_hand"] = ["secret-card"]
	_expect(not surface.apply_player_roster({"players": hostile}), "private roster data fails closed at %s" % viewport_size)

	var stage := surface.get_node_or_null("ReferencePlanetStage") as Control
	var roster := surface.get_node_or_null("PlayerRosterPanel") as Control
	var mode_label := surface.get_node_or_null("MapModeLabel") as Control
	var dock := surface.get_node_or_null("PlayerCardDock") as Control
	_expect(_inside_viewport(stage, viewport_size), "reference planet stage stays inside %s" % viewport_size)
	_expect(_inside_viewport(roster, viewport_size), "player roster stays inside %s" % viewport_size)
	_expect(_inside_viewport(mode_label, viewport_size), "context hint stays inside %s" % viewport_size)
	_expect(_inside_viewport(dock, viewport_size), "card dock stays inside %s" % viewport_size)
	_expect(not _controls_overlap(stage, roster), "single-side roster never covers the planet stage at %s" % viewport_size)
	_expect(not _controls_overlap(mode_label, stage) and not _controls_overlap(mode_label, roster), "context hint has a dedicated non-overlapping top lane at %s" % viewport_size)

	var map_view := surface.planet_map_view()
	_expect(map_view != null and map_view.has_method("get_projection_debug_snapshot"), "reference stage preserves real map interaction at %s" % viewport_size)
	if map_view != null and map_view.has_method("get_projection_debug_snapshot"):
		_expect(_inside_control(map_view, stage), "embedded map remains clipped to the responsive reference stage at %s" % viewport_size)
		map_view.set("legacy_draw_fallback_enabled", true)
		map_view.set("sceneized_visual_cutover_enabled", false)
		await process_frame
		_expect(not bool(map_view.get("legacy_draw_fallback_enabled")) and bool(map_view.get("sceneized_visual_cutover_enabled")), "reference map rejects runtime attempts to revive the legacy visual path at %s" % viewport_size)
		_expect(_named_descendant_count(stage, ["RoleSeatLayerHost", "BackSeatLayer", "FrontSeatLayer"]) == 0, "instantiated reference tree has no production position layers at %s" % viewport_size)
		var backdrop := map_view.get_node_or_null("BackdropLayer/PlanetGlobeBackdrop")
		var guide := map_view.get_node_or_null("OrbitLayer/PlanetOrbitGuide")
		_expect(_script_path(backdrop) == "res://scripts/ui/v07/v07_reference_planet_backdrop.gd", "instantiated map uses the neutral V0.7 backdrop at %s" % viewport_size)
		_expect(_script_path(guide) == "res://scripts/ui/v07/v07_reference_planet_guide.gd", "instantiated map uses the neutral V0.7 guide at %s" % viewport_size)
		var before: Dictionary = map_view.call("get_projection_debug_snapshot")
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		map_view.call("_gui_input", wheel)
		var after: Dictionary = map_view.call("get_projection_debug_snapshot")
		_expect(float(after.get("target_view_zoom", 0.0)) > float(before.get("target_view_zoom", 0.0)), "map wheel zoom remains active at %s" % viewport_size)

	surface.queue_free()
	await process_frame


func _players(count: int) -> Array:
	var rows: Array = []
	for index in range(count):
		rows.append({
			"player_id": "player-%d" % index,
			"display_name": "玩家 %d" % (index + 1),
			"public_status": "已锁定" if index % 2 == 0 else "选择中",
			"public_order_index": index,
			"is_viewer": index == count - 1,
		})
	return rows


func _roster_button(surface: V07ContextualTableSurface, player_id: String) -> Button:
	var grid := surface.get_node_or_null("PlayerRosterPanel/RosterMargin/RosterRows/RosterScroll/RosterGrid")
	if grid == null:
		return null
	for child in grid.get_children():
		if child is Button and str(child.get_meta("public_player_id", "")) == player_id:
			return child as Button
	return null


func _named_descendant_count(root_node: Node, names: Array[String]) -> int:
	if root_node == null:
		return -1
	var count := 0
	for node in root_node.find_children("*", "", true, false):
		if node != null and node.name in names:
			count += 1
	return count


func _script_path(node: Node) -> String:
	if node == null:
		return ""
	var script := node.get_script() as Script
	return script.resource_path if script != null else ""


func _inside_viewport(control: Control, viewport_size: Vector2i) -> bool:
	if control == null or control.size.x <= 1.0 or control.size.y <= 1.0:
		return false
	var rect := control.get_global_rect()
	return rect.position.x >= -1.0 \
		and rect.position.y >= -1.0 \
		and rect.end.x <= float(viewport_size.x) + 1.0 \
		and rect.end.y <= float(viewport_size.y) + 1.0


func _inside_control(inner: Control, outer: Control) -> bool:
	if inner == null or outer == null:
		return false
	var inner_rect := inner.get_global_rect()
	var outer_rect := outer.get_global_rect()
	return inner_rect.position.x >= outer_rect.position.x - 1.0 \
		and inner_rect.position.y >= outer_rect.position.y - 1.0 \
		and inner_rect.end.x <= outer_rect.end.x + 1.0 \
		and inner_rect.end.y <= outer_rect.end.y + 1.0


func _controls_overlap(left: Control, right: Control) -> bool:
	return left != null and right != null and left.get_global_rect().intersects(right.get_global_rect())


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("V07_LEGACY_PLANET_ORBIT_SEAT_RETIREMENT_TEST|status=%s|checks=%d|failures=%d|V07_REFERENCE_PLAYER_ROSTER_SOURCE_COUNT=1|ORBIT_PLAYER_MARKER_COUNT=0|LEFT_RIGHT_SEAT_LAYER_COUNT=0" % [status, _checks, _failures.size()])
	for failure in _failures:
		push_error("V07_LEGACY_PLANET_ORBIT_SEAT_RETIREMENT_TEST: %s" % failure)
	quit(0 if _failures.is_empty() else 1)
