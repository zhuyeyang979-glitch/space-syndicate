extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	_expect(packed != null, "main.tscn loads for campaign globe regression")
	if packed == null:
		_finish()
		return
	root.size = Vector2i(1600, 960)
	var main := packed.instantiate()
	root.add_child(main)
	await _wait_frames(6)
	main.call("_start_campaign_chapter", "00_tavern_entry")
	await _wait_frames(8)
	var map_view := main.get("map_view") as Control
	var map_host := main.find_child("MapHost", true, false) as Control
	_expect(map_view != null, "campaign runtime owns a real MapView")
	_expect(map_host != null and map_view != null and map_view.get_parent() == map_host, "campaign runtime mounts MapView inside PlanetBoard MapHost")
	_expect(not (map_view is ColorRect), "campaign MapView is not a ColorRect placeholder")
	var snapshot: Dictionary = {}
	if map_view != null and map_view.has_method("get_projection_debug_snapshot"):
		snapshot = map_view.call("get_projection_debug_snapshot") as Dictionary
	_expect(str(snapshot.get("mode", "")) == "globe" and bool(snapshot.get("globe_mode", false)), "campaign runtime defaults to globe overview")
	_expect(float(snapshot.get("globe_blend", 0.0)) >= 0.95, "campaign runtime globe blend stays near full globe")
	_expect(_campaign_focus_ui_is_readable(main), "campaign runtime uses a low-density focus layout around the central planet")
	if map_view != null:
		var zoom_before := float(snapshot.get("target_view_zoom", 0.0))
		_send_wheel(map_view, MOUSE_BUTTON_WHEEL_UP)
		await _wait_frames(3)
		var zoom_after: Dictionary = map_view.call("get_projection_debug_snapshot") as Dictionary
		_expect(float(zoom_after.get("target_view_zoom", 0.0)) > zoom_before, "campaign central planet responds to mouse-wheel zoom")
		var center_before: Vector2 = zoom_after.get("view_center_m", Vector2.ZERO)
		_send_drag(map_view, map_view.size * 0.5, map_view.size * 0.5 + Vector2(96, 42))
		await _wait_frames(3)
		var drag_after: Dictionary = map_view.call("get_projection_debug_snapshot") as Dictionary
		var center_after: Vector2 = drag_after.get("view_center_m", Vector2.ZERO)
		_expect(center_after.distance_to(center_before) > 0.1, "campaign central planet responds to drag rotation")
	root.remove_child(main)
	main.queue_free()
	await _wait_frames(1)
	_finish()


func _wait_frames(count: int) -> void:
	for _i in range(maxi(1, count)):
		await process_frame


func _send_wheel(map_view: Control, button_index: int) -> void:
	var wheel := InputEventMouseButton.new()
	wheel.button_index = button_index
	wheel.pressed = true
	wheel.position = map_view.size * 0.5
	map_view.call("_gui_input", wheel)


func _send_drag(map_view: Control, start_position: Vector2, end_position: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start_position
	map_view.call("_gui_input", press)
	var motion := InputEventMouseMotion.new()
	motion.position = end_position
	map_view.call("_gui_input", motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = end_position
	map_view.call("_gui_input", release)


func _campaign_focus_ui_is_readable(main: Node) -> bool:
	var source: Dictionary = main.call("_runtime_table_snapshot_source") as Dictionary
	if not bool(source.get("campaign_focus_mode", false)):
		return false
	var left_rail := main.find_child("PlanetLeftSpaceRail", true, false) as Control
	var right_rail := main.find_child("PlanetRightSpaceRail", true, false) as Control
	var compass := main.find_child("PlaytestFlowCompass", true, false) as Control
	var inspector := main.find_child("RightInspector", true, false) as Control
	var secondary_row := main.find_child("ScenarioCoachSecondaryRow", true, false) as Control
	var rails_hidden := (left_rail == null or not left_rail.visible) and (right_rail == null or not right_rail.visible)
	var compass_hidden := compass == null or not compass.visible
	var inspector_compact := inspector != null and inspector.custom_minimum_size.x <= 240.0
	var secondary_count_ok := secondary_row == null or secondary_row.get_child_count() <= 2
	return rails_hidden and compass_hidden and inspector_compact and secondary_count_ok


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Campaign map globe regression test passed.")
	else:
		push_error("Campaign map globe regression test failed:\n- " + "\n- ".join(_failures))
	quit(_failures.size())
