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
	_expect(int(started.get("focus_target_district", -1)) == 1, "focus_district records which region the planet is rotating toward")
	_expect((started.get("focus_target_center_m", Vector2.ZERO) as Vector2).distance_to(target) <= 1.0, "focus_district records the target region center")
	_expect((started.get("view_center_m", Vector2.ZERO) as Vector2).distance_to(target) > 50.0, "focus_district does not silently snap to the target on the same frame")
	for _frame in range(60):
		await process_frame
	var finished := _snapshot(map_view)
	_expect(not bool(finished.get("focus_rotation_active", false)), "focus_district finishes the planet rotation")
	_expect((finished.get("view_center_m", Vector2.ZERO) as Vector2).distance_to(target) <= 1.0, "focus_district ends with the target region facing the player")
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


func _rect_polygon(center: Vector2) -> Array:
	return [
		center + Vector2(-50.0, -50.0),
		center + Vector2(50.0, -50.0),
		center + Vector2(50.0, 50.0),
		center + Vector2(-50.0, 50.0),
	]


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
