extends SceneTree

const MAP_VIEW_SCRIPT := preload("res://scripts/map_view.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var map_view := MAP_VIEW_SCRIPT.new() as Control
	root.add_child(map_view)
	map_view.size = Vector2(720, 720)
	await process_frame
	var snapshot: Dictionary = {}
	if map_view.has_method("get_projection_debug_snapshot"):
		snapshot = map_view.call("get_projection_debug_snapshot") as Dictionary
	_expect(str(snapshot.get("mode", "")) == "globe", "MapView defaults to globe mode")
	_expect(float(snapshot.get("globe_blend", 0.0)) >= 0.95, "MapView default globe blend is not a flat color-block projection")
	root.remove_child(map_view)
	map_view.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("MapView globe default test passed.")
	else:
		push_error("MapView globe default test failed:\n- " + "\n- ".join(_failures))
	quit(_failures.size())
