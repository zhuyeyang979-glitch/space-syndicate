extends SceneTree

const MAP_VIEW_SCRIPT := preload("res://scripts/map_view.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720, 720)
	root.add_child(viewport)
	var map_view := MAP_VIEW_SCRIPT.new() as Control
	_expect(map_view != null, "MapView instantiates for focus rotation")
	if map_view == null:
		root.remove_child(viewport)
		viewport.queue_free()
		_finish()
		return
	map_view.size = Vector2(720, 720)
	viewport.add_child(map_view)
	await process_frame
	map_view.call("set_map", _rotation_test_districts(), 1400.0, 950.0, 0, [Color("#0ea5e9"), Color("#f59e0b")])
	await process_frame
	var before := _snapshot(map_view)
	_expect((before.get("view_center_m", Vector2.ZERO) as Vector2).distance_to(Vector2(700.0, 475.0)) <= 1.0, "MapView starts from the planet overview center")
	map_view.call("focus_district", 1)
	var started := _snapshot(map_view)
	var target := Vector2(1200.0, 475.0)
	_expect(bool(started.get("focus_rotation_active", false)), "focus_district starts a visible planet rotation for a distant region")
	_expect(bool(started.get("focus_beacon_active", false)) and float(started.get("focus_beacon_alpha", 0.0)) > 0.5, "focus_district shows a visible target beacon while the planet rotates")
	_expect(int(started.get("focus_target_district", -1)) == 1, "focus_district records which region the planet is rotating toward")
	_expect((started.get("focus_target_center_m", Vector2.ZERO) as Vector2).distance_to(target) <= 1.0, "focus_district records the target region center")
	_expect((started.get("view_center_m", Vector2.ZERO) as Vector2).distance_to(target) > 50.0, "focus_district does not silently snap to the target on the same frame")
	for _frame in range(180):
		await process_frame
	var finished := _snapshot(map_view)
	_expect(not bool(finished.get("focus_rotation_active", false)), "focus_district finishes the planet rotation")
	_expect((finished.get("view_center_m", Vector2.ZERO) as Vector2).distance_to(target) <= 1.0, "focus_district ends with the target region facing the player")
	_expect(bool(finished.get("focus_beacon_active", false)), "focus_district keeps a short target beacon after rotation so humans can see the landed region")
	map_view.call("set_map", _rotation_test_districts(), 1400.0, 950.0, 0, [Color("#0ea5e9"), Color("#f59e0b")])
	await process_frame
	var data_jump_started := _snapshot(map_view)
	_expect(bool(data_jump_started.get("focus_rotation_active", false)), "set_map selected-district jump starts a visible planet rotation")
	_expect(bool(data_jump_started.get("focus_beacon_active", false)), "set_map selected-district jump shows the target beacon")
	_expect(int(data_jump_started.get("focus_target_district", -1)) == 0, "set_map selected-district jump records the target region")
	_expect((data_jump_started.get("view_center_m", Vector2.ZERO) as Vector2).distance_to(Vector2(700.0, 475.0)) > 50.0, "set_map selected-district jump does not silently snap to the new region")
	for _frame in range(180):
		await process_frame
	var data_jump_finished := _snapshot(map_view)
	_expect(not bool(data_jump_finished.get("focus_rotation_active", false)), "set_map selected-district jump finishes the planet rotation")
	_expect((data_jump_finished.get("view_center_m", Vector2.ZERO) as Vector2).distance_to(Vector2(700.0, 475.0)) <= 1.0, "set_map selected-district jump ends with the new region facing the player")
	var keyboard_selected: Array[int] = []
	var keyboard_opened: Array[int] = []
	map_view.district_selected.connect(func(index: int) -> void:
		keyboard_selected.append(index)
	)
	map_view.district_double_clicked.connect(func(index: int) -> void:
		keyboard_opened.append(index)
	)
	map_view.call("set_map", _keyboard_navigation_districts(), 1400.0, 950.0, 0, [
		Color("#0ea5e9"),
		Color("#f59e0b"),
		Color("#22c55e"),
		Color("#a855f7"),
		Color("#ef4444"),
	])
	await process_frame
	map_view.call("_gui_input", _action("ui_right"))
	await process_frame
	var keyboard_started := _snapshot(map_view)
	_expect(keyboard_selected == [1], "MapView ui_right selects the projected right-side district")
	_expect(bool(keyboard_started.get("focus_rotation_active", false)), "keyboard district navigation starts a visible planet rotation")
	_expect(int(keyboard_started.get("focus_target_district", -1)) == 1, "keyboard district navigation records the target region")
	map_view.call("_gui_input", _action("ui_accept"))
	await process_frame
	_expect(keyboard_opened == [1], "MapView ui_accept opens the currently focused district rack")
	map_view.call("set_programmatic_focus_animation_enabled", false)
	map_view.call("focus_district", 0)
	var fast_focus := _snapshot(map_view)
	_expect(not bool(fast_focus.get("programmatic_focus_animation_enabled", true)), "MapView exposes a test-only way to disable programmatic focus animation")
	_expect(not bool(fast_focus.get("focus_rotation_active", false)) and (fast_focus.get("view_center_m", Vector2.ZERO) as Vector2).distance_to(Vector2(700.0, 475.0)) <= 1.0, "disabled programmatic focus snaps only for background smoke tests")
	map_view.call("set_programmatic_focus_animation_enabled", true)
	viewport.remove_child(map_view)
	map_view.queue_free()
	root.remove_child(viewport)
	viewport.queue_free()
	_finish()


func _rotation_test_districts() -> Array:
	return [
		{
			"name": "中心港",
			"terrain": "land",
			"center": Vector2(700.0, 475.0),
			"radius_m": 70.0,
			"polygon": _rect_polygon(Vector2(700.0, 475.0)),
		},
		{
			"name": "远轨矿区",
			"terrain": "land",
			"center": Vector2(1200.0, 475.0),
			"radius_m": 70.0,
			"polygon": _rect_polygon(Vector2(1200.0, 475.0)),
		},
	]


func _keyboard_navigation_districts() -> Array:
	return [
		{
			"name": "中央赌桌港",
			"terrain": "land",
			"center": Vector2(700.0, 475.0),
			"radius_m": 70.0,
			"polygon": _rect_polygon(Vector2(700.0, 475.0)),
			"neighbors": [1, 2, 3, 4],
		},
		{
			"name": "右舷能源湾",
			"terrain": "land",
			"center": Vector2(1040.0, 475.0),
			"radius_m": 70.0,
			"polygon": _rect_polygon(Vector2(1040.0, 475.0)),
			"neighbors": [0],
		},
		{
			"name": "左舷鱼骨海",
			"terrain": "ocean",
			"center": Vector2(360.0, 475.0),
			"radius_m": 70.0,
			"polygon": _rect_polygon(Vector2(360.0, 475.0)),
			"neighbors": [0],
		},
		{
			"name": "北冠数据站",
			"terrain": "land",
			"center": Vector2(700.0, 245.0),
			"radius_m": 70.0,
			"polygon": _rect_polygon(Vector2(700.0, 245.0)),
			"neighbors": [0],
		},
		{
			"name": "南渊转运港",
			"terrain": "ocean",
			"center": Vector2(700.0, 705.0),
			"radius_m": 70.0,
			"polygon": _rect_polygon(Vector2(700.0, 705.0)),
			"neighbors": [0],
		},
	]


func _rect_polygon(center: Vector2) -> Array:
	return [
		center + Vector2(-50.0, -50.0),
		center + Vector2(50.0, -50.0),
		center + Vector2(50.0, 50.0),
		center + Vector2(-50.0, 50.0),
	]


func _action(action_name: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = true
	return event


func _snapshot(map_view: Node) -> Dictionary:
	var value: Variant = map_view.call("get_projection_debug_snapshot")
	return value if value is Dictionary else {}


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("MapView focus rotation test passed.")
	else:
		push_error("MapView focus rotation test failed:\n- " + "\n- ".join(_failures))
	quit(_failures.size())
