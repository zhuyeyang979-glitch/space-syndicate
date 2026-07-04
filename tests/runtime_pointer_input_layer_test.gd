extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1600, 960)
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	_expect(packed != null, "main.tscn loads for runtime pointer input layer test")
	if packed == null:
		_finish()
		return
	var main := packed.instantiate()
	root.add_child(main)
	await _wait_frames(8)
	if main.has_method("_new_game"):
		main.call("_new_game")
		await _wait_frames(8)
	if main.has_method("_close_menu"):
		main.call("_close_menu")
		await _wait_frames(3)
	if main.has_method("_sync_runtime_game_screen"):
		main.call("_sync_runtime_game_screen", true)
		await _wait_frames(3)

	var runtime_screen := main.get("runtime_game_screen") as Control
	var map_view := main.get("map_view") as Control
	var map_host := main.find_child("MapHost", true, false) as Control
	var hand_rack := main.find_child("HandRack", true, false) as Control
	_expect(runtime_screen != null, "runtime GameScreen exists for pointer dispatch")
	_expect(map_view != null and map_host != null and map_view.get_parent() == map_host, "runtime MapView is mounted inside MapHost")
	_expect(hand_rack != null, "runtime HandRack exists for card pointer dispatch")

	_check_passthrough_controls(runtime_screen)
	await _check_viewport_mouse_reaches_map(main, map_view)
	await _check_viewport_mouse_reaches_hand_card(main, hand_rack)

	root.remove_child(main)
	main.queue_free()
	await _wait_frames(2)
	_finish()


func _check_passthrough_controls(runtime_screen: Control) -> void:
	if runtime_screen == null:
		return
	for node_name in [
		"Background",
		"FirstRunCoachHost",
		"ScenarioCoachHost",
		"HandHoverPreviewHost",
		"FocusGuideLayer",
		"RuntimeVisualEventLayer",
		"PlaytestFlowCompass",
		"PlanetLeftSpaceRail",
		"PlanetRightSpaceRail",
		"WeatherForecastBar",
	]:
		var node := runtime_screen.find_child(node_name, true, false) as Control
		_expect(node == null or node.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s does not intercept runtime pointer input" % node_name)
	for node_name in ["PlaytestFlowCompass", "PlanetLeftSpaceRail", "PlanetRightSpaceRail", "WeatherForecastBar"]:
		var node := runtime_screen.find_child(node_name, true, false)
		if node != null:
			_expect(_all_control_descendants_ignore_mouse(node), "%s descendants are also pointer-transparent decorations" % node_name)
	var map_host := runtime_screen.find_child("MapHost", true, false) as Control
	_expect(map_host != null and map_host.mouse_filter == Control.MOUSE_FILTER_PASS, "MapHost passes pointer input through to RuntimeMapView")


func _check_viewport_mouse_reaches_map(main: Node, map_view: Control) -> void:
	if map_view == null or not map_view.has_method("get_projection_debug_snapshot"):
		return
	await _wait_frames(8)
	var before: Dictionary = map_view.call("get_projection_debug_snapshot") as Dictionary
	_expect(int(before.get("district_count", 0)) > 0, "runtime planet map keeps generated districts mounted")
	_expect(not bool(before.get("complex_polygon_fill_in_globe", true)), "runtime globe projection avoids heavy polygon fills that can become edge color blocks")
	_expect(String(before.get("globe_region_outline_policy", "")) == "always_lightweight_during_interaction", "runtime globe projection keeps district boundary skeleton visible during drag/zoom")
	var zoom_before := float(before.get("target_view_zoom", 0.0))
	var map_center := map_view.get_global_rect().get_center()
	_push_mouse_button(MOUSE_BUTTON_WHEEL_UP, map_center, true, false)
	await _wait_frames(5)
	var after_zoom: Dictionary = map_view.call("get_projection_debug_snapshot") as Dictionary
	if not (float(after_zoom.get("target_view_zoom", 0.0)) > zoom_before):
		print("DEBUG map center blockers: %s" % str(_controls_under_point(root, map_center)))
		print("DEBUG viewport hovered after wheel: %s" % _control_debug_name(root.gui_get_hovered_control()))
	_expect(float(after_zoom.get("target_view_zoom", 0.0)) > zoom_before, "real viewport mouse wheel reaches RuntimeMapView zoom path")

	var center_before: Vector2 = after_zoom.get("view_center_m", Vector2.ZERO)
	var drag_start := map_center
	var drag_end := map_center + Vector2(104.0, 44.0)
	_push_mouse_button(MOUSE_BUTTON_LEFT, drag_start, true, false)
	_push_mouse_motion(drag_end, drag_end - drag_start)
	_push_mouse_button(MOUSE_BUTTON_LEFT, drag_end, false, false)
	await _wait_frames(5)
	var after_drag: Dictionary = map_view.call("get_projection_debug_snapshot") as Dictionary
	var center_after: Vector2 = after_drag.get("view_center_m", Vector2.ZERO)
	if not (center_after.distance_to(center_before) > 0.05):
		print("DEBUG map drag blockers: %s" % str(_controls_under_point(root, drag_end)))
		print("DEBUG viewport hovered after drag: %s" % _control_debug_name(root.gui_get_hovered_control()))
	_expect(center_after.distance_to(center_before) > 0.05, "real viewport mouse drag reaches RuntimeMapView rotation/pan path")
	_expect(int(main.get("selected_district")) >= -1, "runtime map pointer path keeps gameplay district state accessible")


func _check_viewport_mouse_reaches_hand_card(main: Node, hand_rack: Control) -> void:
	if hand_rack == null:
		return
	main.set("selected_runtime_card_slot", -1)
	if main.has_method("_sync_runtime_game_screen"):
		main.call("_sync_runtime_game_screen", true)
	await _wait_frames(3)
	hand_rack = main.find_child("HandRack", true, false) as Control
	_expect(hand_rack != null, "runtime HandRack remains available after selection refresh")
	if hand_rack == null:
		return
	var hand_card := _first_hand_card_control(hand_rack)
	_expect(hand_card != null, "runtime hand rack renders at least one clickable CardFace")
	if hand_card == null:
		return
	_expect(hand_card.mouse_filter == Control.MOUSE_FILTER_STOP, "CardFace root receives pointer input")
	_expect(_all_control_descendants_ignore_mouse(hand_card, hand_card), "CardFace internal labels/art panels do not steal pointer input from the root card")
	var signal_counts := {"card_face": 0, "hand_rack": 0, "player_board": 0, "runtime_screen": 0}
	if hand_card.has_signal("card_clicked"):
		hand_card.connect("card_clicked", func(_data: Dictionary) -> void:
			signal_counts["card_face"] = int(signal_counts["card_face"]) + 1
		)
	if hand_rack.has_signal("card_selected"):
		hand_rack.connect("card_selected", func(_data: Dictionary) -> void:
			signal_counts["hand_rack"] = int(signal_counts["hand_rack"]) + 1
		)
	var player_board := hand_rack
	while player_board != null and str(player_board.name) != "PlayerBoard":
		player_board = player_board.get_parent() as Control
	if player_board != null and player_board.has_signal("card_selected"):
		player_board.connect("card_selected", func(_data: Dictionary) -> void:
			signal_counts["player_board"] = int(signal_counts["player_board"]) + 1
		)
	var runtime_screen := main.get("runtime_game_screen") as Control
	if runtime_screen != null and runtime_screen.has_signal("card_selected"):
		runtime_screen.connect("card_selected", func(_data: Dictionary) -> void:
			signal_counts["runtime_screen"] = int(signal_counts["runtime_screen"]) + 1
		)
	var card_center := hand_card.get_global_rect().get_center()
	_push_mouse_motion(card_center, Vector2.ZERO)
	await _wait_frames(2)
	_push_mouse_button(MOUSE_BUTTON_LEFT, card_center, true, false)
	_push_mouse_button(MOUSE_BUTTON_LEFT, card_center, false, false)
	await _wait_frames(4)
	if not (int(main.get("selected_runtime_card_slot")) >= 0):
		print("DEBUG hand signal counts: %s" % str(signal_counts))
		print("DEBUG hand card center blockers: %s" % str(_controls_under_point(root, card_center)))
		print("DEBUG viewport hovered after card click: %s" % _control_debug_name(root.gui_get_hovered_control()))
	_expect(int(main.get("selected_runtime_card_slot")) >= 0, "real viewport mouse click reaches hand CardFace and selects a runtime card")


func _first_hand_card_control(hand_rack: Control) -> Control:
	for child in hand_rack.get_children():
		if child is Control and (child as Control).has_method("get_card_data"):
			return child as Control
	return null


func _all_control_descendants_ignore_mouse(node: Node, except_node: Node = null) -> bool:
	for child in node.get_children():
		if child is Control and child != except_node:
			var control := child as Control
			if control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				return false
		if not _all_control_descendants_ignore_mouse(child, except_node):
			return false
	return true


func _controls_under_point(node: Node, point: Vector2, result: Array[String] = []) -> Array[String]:
	for child in node.get_children():
		if child is Control:
			var control := child as Control
			if control.is_visible_in_tree() and control.get_global_rect().has_point(point) and control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				result.append(_control_debug_name(control))
		_controls_under_point(child, point, result)
	return result


func _control_debug_name(control: Control) -> String:
	if control == null:
		return "<none>"
	var rect := control.get_global_rect()
	return "%s filter=%d visible=%s rect=%s" % [control.get_path(), control.mouse_filter, control.visible, rect]


func _push_mouse_button(button_index: int, position: Vector2, pressed: bool, double_click: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = pressed
	event.double_click = double_click
	event.position = position
	event.global_position = position
	Input.parse_input_event(event)


func _push_mouse_motion(position: Vector2, relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = relative
	Input.parse_input_event(event)


func _wait_frames(count: int) -> void:
	for _i in range(maxi(1, count)):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Runtime pointer input layer test passed.")
	else:
		push_error("Runtime pointer input layer test failed:\n- " + "\n- ".join(_failures))
	quit(_failures.size())
