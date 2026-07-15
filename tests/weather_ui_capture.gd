extends SceneTree

const VIEW_MODEL_TEST = preload("res://tests/weather_presentation_view_model_test.gd")
const PRIVACY_TEST = preload("res://tests/weather_presentation_privacy_test.gd")
const BENCH_SCENE = preload("res://scenes/tools/WeatherPresentationV1Bench.tscn")
const PLANET_MAP_PREVIEW_SCENE = preload("res://scenes/tools/PlanetMapMcpPreview.tscn")
const FORECAST_STRIP_SCENE = preload("res://scenes/ui/weather/WeatherForecastStrip.tscn")
const MAP_OVERLAY_SCENE = preload("res://scenes/ui/weather/WeatherMapOverlay.tscn")
const FORECAST_VIEW_MODEL = preload("res://scripts/viewmodels/weather_forecast_view_model.gd")
const OVERLAY_VIEW_MODEL = preload("res://scripts/viewmodels/weather_map_overlay_view_model.gd")
const BENCH = preload("res://scripts/tools/weather_presentation_v1_bench.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_failures.append_array(VIEW_MODEL_TEST.run_checks())
	_failures.append_array(PRIVACY_TEST.run_checks())
	DisplayServer.window_set_size(Vector2i(1280, 720))
	get_root().size = Vector2i(1280, 720)

	var bench := BENCH_SCENE.instantiate() as Control
	bench.set("auto_capture_on_ready", false)
	get_root().add_child(bench)
	await _pump_frames(3)
	var capture_result: Dictionary = await bench.call("run_capture_suite")
	_failures.append_array(capture_result["failures"])
	for path: String in capture_result["saved_paths"]:
		print("WEATHER_SCREENSHOT %s" % path)
	var planet_capture: Dictionary = await _capture_real_planet_board()
	_failures.append_array(planet_capture["failures"])
	if not str(planet_capture["saved_path"]).is_empty():
		print("WEATHER_SCREENSHOT %s" % planet_capture["saved_path"])
	await _run_ui_checks()

	get_root().remove_child(bench)
	bench.queue_free()
	await _pump_frames(2)
	if _failures.is_empty():
		print("WEATHER_UI_CAPTURE_PASS")
	else:
		for failure: String in _failures:
			push_error("WEATHER_CHECK: %s" % failure)
	quit(0 if _failures.is_empty() else 1)


func _capture_real_planet_board() -> Dictionary:
	var failures: Array[String] = []
	var capture_size := Vector2i(1600, 960)
	var viewport := SubViewport.new()
	viewport.name = "WeatherPlanetBoardCapture"
	viewport.size = capture_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.transparent_bg = false
	get_root().add_child(viewport)

	var preview := PLANET_MAP_PREVIEW_SCENE.instantiate() as Control
	viewport.add_child(preview)
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _pump_frames(4)
	if not bool(preview.call("apply_fixture", "render_cutover")):
		failures.append("real PlanetMap preview rejected render_cutover fixture")
	var board := preview.find_child("PlanetBoard", true, false) as Control
	var map_view := preview.find_child("PlanetMapView", true, false) as Control
	if board == null or map_view == null:
		failures.append("real PlanetBoard or PlanetMapView missing")
	else:
		var forecast := FORECAST_VIEW_MODEL.new().compose(BENCH.fixture_source("full"))
		var overlay := OVERLAY_VIEW_MODEL.new().compose(forecast)
		board.call("set_weather_presentation", forecast, overlay, "reduced")
		await _pump_frames(10)
		var overlay_debug := map_view.call("weather_overlay_debug_snapshot") as Dictionary
		if not bool(overlay_debug.get("visible", false)) or int(overlay_debug.get("layout_count", 0)) != 6 or (overlay_debug.get("region_indices", []) as Array).size() != 4:
			failures.append("real PlanetMap weather overlay did not map four affected markers onto six district positions")
		var weather_layer := map_view.get_node_or_null("WeatherLayer") as Control
		var district_layer := map_view.get_node_or_null("DistrictLayer") as Control
		var route_layer := map_view.get_node_or_null("RouteLayer") as Control
		var monster_layer := map_view.get_node_or_null("MonsterLayer") as Control
		if weather_layer == null or district_layer == null or route_layer == null or monster_layer == null:
			failures.append("real PlanetMap weather/district/route/monster layers missing")
		elif not (weather_layer.get_index() < district_layer.get_index() and district_layer.get_index() < route_layer.get_index() and route_layer.get_index() < monster_layer.get_index()):
			failures.append("real PlanetMap layer order could obscure districts, routes, or monsters")
		var strip := board.find_child("WeatherForecastStrip", true, false) as Control
		var strip_debug := strip.call("debug_snapshot") as Dictionary if strip != null else {}
		if not bool(strip_debug.get("visible", false)) or int(strip_debug.get("event_count", 0)) != 2 or int(strip_debug.get("other_event_count", 0)) != 1:
			failures.append("real PlanetBoard compact forecast strip did not acknowledge both concurrent events")

	var saved_path := ""
	var image := viewport.get_texture().get_image()
	if image.is_empty() or image.get_width() != capture_size.x or image.get_height() != capture_size.y:
		failures.append("real PlanetBoard capture dimensions invalid")
	else:
		var output_dir := "user://weather_presentation_v1"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
		var path := output_dir + "/weather_planet_board_v1_1600x960.png"
		var save_error := image.save_png(path)
		if save_error != OK:
			failures.append("real PlanetBoard screenshot save failed (%d)" % save_error)
		else:
			saved_path = ProjectSettings.globalize_path(path)

	viewport.remove_child(preview)
	preview.queue_free()
	get_root().remove_child(viewport)
	viewport.queue_free()
	await _pump_frames(2)
	return {"failures": failures, "saved_path": saved_path}


func _run_ui_checks() -> void:
	var forecast_vm := FORECAST_VIEW_MODEL.new()
	var overlay_vm := OVERLAY_VIEW_MODEL.new()
	var forecast := forecast_vm.compose(BENCH.fixture_source("full"))
	var overlay_view := overlay_vm.compose(forecast)

	var strip := FORECAST_STRIP_SCENE.instantiate() as Control
	strip.position = Vector2(20, 20)
	strip.size = Vector2(480, 190)
	get_root().add_child(strip)
	await process_frame
	_expect(bool(strip.call("set_view_model", forecast)), "forecast strip rejected valid view model")
	_expect(bool(strip.call("set_motion_mode", "reduced")), "forecast strip rejected reduced motion")
	var jump_indices: Array[int] = []
	strip.connect("region_jump_requested", func(region_index: int) -> void: jump_indices.append(region_index))
	strip.grab_focus()
	var accept := InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	strip.call("_gui_input", accept)
	await process_frame
	_expect(jump_indices == [0], "keyboard ui_accept did not emit region_jump_requested(0)")
	var strip_debug := strip.call("debug_snapshot") as Dictionary
	_expect(strip_debug["motion_mode"] == "reduced" and not strip_debug["animated"], "reduced strip was not static")
	var invalid_forecast := forecast.duplicate(true)
	invalid_forecast["camera"] = "private_sentinel"
	_expect(not bool(strip.call("set_view_model", invalid_forecast)) and not strip.visible, "forecast strip did not fail closed")
	get_root().remove_child(strip)
	strip.queue_free()

	var overlay := MAP_OVERLAY_SCENE.instantiate() as Control
	overlay.set_anchor(SIDE_RIGHT, 0.0)
	overlay.set_anchor(SIDE_BOTTOM, 0.0)
	overlay.position = Vector2(520, 20)
	overlay.size = Vector2(480, 300)
	get_root().add_child(overlay)
	await process_frame
	_expect(bool(overlay.call("set_overlay_view_model", overlay_view)), "map overlay rejected valid view model")
	_expect(bool(overlay.call("set_motion_mode", "off")), "map overlay rejected off motion")
	var overlay_debug := overlay.call("debug_snapshot") as Dictionary
	_expect(overlay_debug["motion_mode"] == "off" and not overlay_debug["animated"], "off overlay was not static")
	var invalid_overlay := overlay_view.duplicate(true)
	invalid_overlay["regions"][0]["position"] = Vector2.ZERO
	_expect(not bool(overlay.call("set_overlay_view_model", invalid_overlay)) and not overlay.visible, "map overlay did not fail closed")
	get_root().remove_child(overlay)
	overlay.queue_free()
	await _pump_frames(2)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _pump_frames(count: int) -> void:
	for _frame: int in range(count):
		await process_frame
		await RenderingServer.frame_post_draw
