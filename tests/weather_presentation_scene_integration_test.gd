extends SceneTree

const PLANET_BOARD_SCENE := preload("res://scenes/ui/PlanetBoard.tscn")
const FORECAST_VIEW_MODEL := preload("res://scripts/viewmodels/weather_forecast_view_model.gd")
const OVERLAY_VIEW_MODEL := preload("res://scripts/viewmodels/weather_map_overlay_view_model.gd")
const WEATHER_BENCH := preload("res://scripts/tools/weather_presentation_v1_bench.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	root.add_child(viewport)
	var board := PLANET_BOARD_SCENE.instantiate() as Control
	viewport.add_child(board)
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame

	var map_view := board.find_child("PlanetMapView", true, false) as Control
	var forecast_strip := board.find_child("WeatherForecastStrip", true, false) as Control
	var weather_layer := board.find_child("WeatherLayer", true, false) as Control
	_expect(map_view != null and forecast_strip != null and weather_layer != null, "PlanetBoard statically owns forecast strip, map, and weather layer")
	_expect(weather_layer != null and weather_layer.get_parent() == map_view, "weather overlay is scene-owned by PlanetMapView")
	_expect(forecast_strip != null and forecast_strip.has_method("set_view_model") and forecast_strip.has_signal("region_jump_requested"), "forecast strip exposes pure view-model and jump contract")
	_expect(map_view != null and map_view.has_method("set_weather_overlay_view_model") and map_view.has_method("weather_overlay_debug_snapshot"), "PlanetMapView exposes weather presentation-only API")

	if map_view != null:
		map_view.call("set_map", _districts(), 1400.0, 950.0, 0, [Color("#0ea5e9"), Color("#22c55e"), Color("#f59e0b"), Color("#a855f7")])
	await process_frame
	await process_frame

	var forecast := FORECAST_VIEW_MODEL.new().compose(WEATHER_BENCH.fixture_source("full"))
	var overlay := OVERLAY_VIEW_MODEL.new().compose(forecast)
	_expect(not forecast.is_empty() and not overlay.is_empty(), "focused fixture composes valid public weather view models")
	if not forecast.is_empty() and not overlay.is_empty():
		board.call("set_weather_presentation", forecast, overlay, "reduced")
	await process_frame

	var strip_debug: Dictionary = forecast_strip.call("debug_snapshot") as Dictionary if forecast_strip != null else {}
	var overlay_debug: Dictionary = map_view.call("weather_overlay_debug_snapshot") as Dictionary if map_view != null else {}
	_expect(bool(strip_debug.get("visible", false)) and bool(strip_debug.get("compact_mode", false)), "embedded forecast strip remains visible in compact table mode")
	_expect(str(strip_debug.get("motion_mode", "")) == "reduced" and not bool(strip_debug.get("animated", true)), "reduced motion keeps the strip readable without continuous animation")
	_expect(bool(overlay_debug.get("visible", false)) and int(overlay_debug.get("layout_count", 0)) == 4, "weather overlay receives all region geometry from the map")
	_expect(str(overlay_debug.get("motion_mode", "")) == "reduced", "map overlay follows the same motion policy")

	var focused_region := [-1]
	if map_view != null:
		map_view.connect("district_selected", func(region_index: int) -> void: focused_region[0] = region_index)
	if forecast_strip != null:
		forecast_strip.emit_signal("region_jump_requested", 1)
	await process_frame
	_expect(focused_region[0] == 1, "forecast region action focuses and selects the matching map region")

	var serialized := JSON.stringify({"forecast": forecast, "overlay": overlay, "strip": strip_debug, "layer": overlay_debug})
	_expect(not serialized.contains("cash") and not serialized.contains("hand") and not serialized.contains("owner") and not serialized.contains("ai_"), "scene presentation remains free of private player state")
	_expect(forecast_strip != null and forecast_strip.get_global_rect().end.y <= board.get_global_rect().end.y + 1.0, "compact forecast strip stays inside the board")

	print("WEATHER_PRESENTATION_SCENE_INTEGRATION_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	viewport.queue_free()
	await process_frame
	quit(0 if _failures.is_empty() else 1)


func _districts() -> Array:
	return [
		{"name": "寒冠洋", "terrain": "ocean", "center": Vector2(360, 260), "radius_m": 84.0, "hp": 18, "products": ["ice"], "polygon": [Vector2(210, 160), Vector2(520, 180), Vector2(500, 340), Vector2(240, 360)]},
		{"name": "雾港城", "terrain": "land", "center": Vector2(760, 310), "radius_m": 78.0, "hp": 20, "products": ["ore"], "polygon": [Vector2(620, 220), Vector2(890, 210), Vector2(930, 390), Vector2(650, 420)]},
		{"name": "商路中继", "terrain": "ocean", "center": Vector2(520, 610), "radius_m": 68.0, "hp": 16, "products": ["water"], "polygon": [Vector2(360, 500), Vector2(620, 500), Vector2(640, 700), Vector2(390, 720)]},
		{"name": "试玩罗盘", "terrain": "land", "center": Vector2(930, 650), "radius_m": 92.0, "hp": 22, "products": ["crystal"], "polygon": [Vector2(760, 500), Vector2(1110, 520), Vector2(1080, 780), Vector2(790, 760)]},
	]


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error("WEATHER PRESENTATION SCENE: %s" % label)
