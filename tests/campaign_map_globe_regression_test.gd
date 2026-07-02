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
	root.remove_child(main)
	main.queue_free()
	await _wait_frames(1)
	_finish()


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
		print("Campaign map globe regression test passed.")
	else:
		push_error("Campaign map globe regression test failed:\n- " + "\n- ".join(_failures))
	quit(_failures.size())
