extends SceneTree

const CONTROLLER_SCENE := preload("res://scenes/runtime/WeatherRuntimeController.tscn")
const BRIDGE_SCENE := preload("res://scenes/runtime/WeatherRuntimeWorldBridge.tscn")
const PRESENTATION_SCENE := preload("res://scenes/runtime/WeatherPresentationRuntimeService.tscn")

var _checks := 0
var _failures: Array[String] = []


class FakeClock:
	extends Node
	var world_us := 90_000_000

	func world_effective_micros() -> int:
		return world_us


class FakeWorld:
	extends Node
	var rng := RandomNumberGenerator.new()
	var districts := [
		{"name": "晨港", "destroyed": false, "terrain": "land", "neighbors": [1], "city": {"active": true}, "trade_volume_bucket": 2},
		{"name": "云廊", "destroyed": false, "terrain": "air", "neighbors": [0], "city": {"active": true}, "trade_volume_bucket": 3},
	]
	var players := [{"cash": 987654321, "hand": ["private_sentinel"]}]

	func _init() -> void:
		rng.seed = 81

	func _duration_short_text(seconds: float) -> String:
		return "%d秒" % ceili(seconds)

	func _district_center(index: int) -> Vector2:
		return Vector2(index * 10.0, 0.0)

	func _log(_message: String) -> void:
		pass

	func _add_action_callout(_source: String, _title: String, _detail: String, _accent: Color, _position: Vector2, _duration: float = 5.0) -> void:
		pass


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := FakeWorld.new()
	var clock := FakeClock.new()
	var bridge := BRIDGE_SCENE.instantiate() as WeatherRuntimeWorldBridge
	var controller := CONTROLLER_SCENE.instantiate() as WeatherRuntimeController
	var presentation: Node = PRESENTATION_SCENE.instantiate()
	root.add_child(world)
	root.add_child(clock)
	root.add_child(bridge)
	root.add_child(controller)
	root.add_child(presentation)
	bridge.bind_world(world)
	controller.set_world_bridge(bridge)
	controller.set_world_effective_clock(clock)
	controller.configure({"ruleset_id": "v0.6"})
	presentation.call("configure", controller)
	_expect(controller.schedule_forecast("ion_storm", 1, 1, 30.0, 45.0, "card", true), "card forecast scheduled")

	var runtime: Dictionary = presentation.call("runtime_public_projection") as Dictionary
	var definitions: Dictionary = presentation.call("definitions_public_projection") as Dictionary
	var forecast: Dictionary = presentation.call("forecast_view_model") as Dictionary
	var overlay: Dictionary = presentation.call("map_overlay_view_model") as Dictionary
	var detail: Dictionary = presentation.call("region_detail_snapshot", 1) as Dictionary
	_expect(runtime.keys().size() == 6 and runtime.has("events") and not runtime.has("forecast") and not runtime.has("timing"), "runtime projection is exact and narrow")
	_expect((definitions.get("definitions", []) as Array).size() == 6, "six definitions projected")
	_expect(str(forecast.get("schema_version", "")) == "weather_forecast_view_model.v1" and str(forecast.get("state", "")) == "forecast", "forecast view model composed from real runtime")
	_expect(str(overlay.get("schema_version", "")) == "weather_map_overlay_view_model.v1" and (overlay.get("regions", []) as Array).size() == 1, "map overlay composed from real runtime")
	_expect(str(detail.get("definition_id", "")) == "ion_storm" and str(detail.get("phase", "")) == "forecast" and (detail.get("effects", []) as Array).size() == 3, "region detail carries phase, time, and three effects")
	_expect(int(detail.get("remaining_us", 0)) > 0 and str(detail.get("exploitation_hint", "")).strip_edges() != "" and str(detail.get("counterplay_hint", "")).strip_edges() != "", "region detail explains remaining time, exploitation, and counterplay")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	_expect(main_source.contains("weather_region_detail_snapshot(selected_district)") and main_source.contains("天气影响：") and main_source.contains("正在消退"), "selected-region inspector consumes the public weather detail without owning weather rules")
	var serialized := JSON.stringify({"runtime": runtime, "definitions": definitions, "forecast": forecast, "overlay": overlay, "detail": detail})
	_expect(not serialized.contains("private_sentinel") and not serialized.contains("987654321") and not serialized.contains("players"), "presentation excludes private world state")
	var debug: Dictionary = presentation.call("debug_snapshot") as Dictionary
	_expect(bool(debug.get("service_ready", false)) and not bool(debug.get("service_authoritative", true)), "presentation service is ready and non-authoritative")

	print("WEATHER_PRESENTATION_RUNTIME_SERVICE_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	for node in [presentation, controller, bridge, clock, world]:
		node.queue_free()
	await process_frame
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error("WEATHER PRESENTATION SERVICE: %s" % label)
