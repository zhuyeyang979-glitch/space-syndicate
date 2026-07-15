extends SceneTree

const WEATHER_SCENE := preload("res://scenes/runtime/WeatherRuntimeController.tscn")
const BRIDGE_SCENE := preload("res://scenes/runtime/WeatherRuntimeWorldBridge.tscn")
const CLOCK_SCENE := preload("res://scenes/runtime/WorldEffectiveClockRuntimeController.tscn")
const TELEMETRY_SCENE := preload("res://scenes/runtime/WeatherTelemetryRuntimeService.tscn")
const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")

var _checks := 0
var _failures: Array[String] = []


class FakeWorld:
	extends Node
	var rng := RandomNumberGenerator.new()
	var districts: Array = [
		{"name": "测试区", "destroyed": false, "terrain": "land", "neighbors": [], "city": {"active": true}},
	]
	var callouts: Array = []

	func _init() -> void:
		rng.seed = 20260715

	func weather_public_live_monster_counts_by_region() -> Dictionary:
		return {0: 1}

	func _duration_short_text(seconds: float) -> String:
		return "%d秒" % ceili(seconds)

	func _district_center(index: int) -> Vector2:
		return Vector2(float(index) * 100.0, 50.0)

	func _log(_message: String) -> void:
		pass

	func _add_action_callout(source: String, title: String, detail: String, _accent: Color, _position: Vector2, _duration: float) -> void:
		callouts.append({"source": source, "title": title, "detail": detail})


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := FakeWorld.new()
	var clock := CLOCK_SCENE.instantiate()
	var bridge := BRIDGE_SCENE.instantiate()
	var weather := WEATHER_SCENE.instantiate()
	var telemetry := TELEMETRY_SCENE.instantiate()
	root.add_child(world)
	root.add_child(clock)
	root.add_child(bridge)
	root.add_child(telemetry)
	root.add_child(weather)
	clock.call("configure", {})
	bridge.call("bind_world", world)
	weather.call("set_world_bridge", bridge)
	weather.call("set_world_effective_clock", clock)
	weather.call("set_weather_telemetry_runtime_service", telemetry)
	weather.call("configure", {"ruleset_id": "v0.6"})
	weather.call("set_new_forecasts_allowed", false)

	_expect(bool(weather.call("schedule_forecast", "ion_storm", 0, 1, 30.0, 45.0, "natural", false)), "real weather owner schedules forecast")
	_expect(_event_types(telemetry) == ["forecast"], "forecast starts one anonymous telemetry session")
	_expect((world.callouts as Array).size() == 1 and str((world.callouts[0] as Dictionary).get("source", "")) == "气象台", "forecast emits one non-blocking weather callout")
	_expect(int(telemetry.call("record_public_response", 0, "buy_after_forecast")) == 1, "forecast response records category without player identity")

	clock.call("advance", 30.0)
	weather.call("tick", 30.0)
	_expect(_event_types(telemetry) == ["forecast", "activation"], "world-effective boundary activates telemetry lifecycle")
	_expect(bool(telemetry.call("observe_public_metric", 1, "product_price_growth_delta_percent", 25.0)) \
		and bool(telemetry.call("observe_public_metric", 1, "route_efficiency_delta_percent", 20.0)) \
		and bool(telemetry.call("mark_monster_target_weather_influenced", 1)), "public owner observations join the active weather session with honest metric semantics")

	clock.call("advance", 55.0)
	weather.call("tick", 55.0)
	_expect(_event_types(telemetry) == ["forecast", "activation", "end"], "active and fading periods finish with one end record")
	var aggregate := telemetry.call("aggregate_snapshot") as Dictionary
	var ion := (aggregate.get("definitions", []) as Array)[0] as Dictionary
	_expect(int(ion.get("event_count", 0)) == 1 \
		and is_equal_approx(float(ion.get("average_product_price_growth_delta_percent", 0.0)), 25.0) \
		and is_equal_approx(float(ion.get("average_route_efficiency_delta_percent", 0.0)), 20.0) \
		and int(ion.get("monster_target_weather_influenced_count", 0)) == 1 \
		and int((ion.get("player_response_counts", {}) as Dictionary).get("buy_after_forecast", 0)) == 1, "completed telemetry preserves only aggregate weather outcomes")
	var encoded := JSON.stringify(telemetry.call("recent_events_snapshot"))
	_expect(not encoded.contains("player_index") and not encoded.contains("cash") and not encoded.contains("hand") and not encoded.contains("owner") and not encoded.contains("target_weights"), "production telemetry log contains no private state")

	var coordinator := COORDINATOR_SCENE.instantiate()
	root.add_child(coordinator)
	var telemetry_nodes := coordinator.find_children("WeatherTelemetryRuntimeService", "Node", true, false)
	_expect(telemetry_nodes.size() == 1 and coordinator.has_method("weather_telemetry_aggregate_snapshot") and coordinator.has_method("record_weather_public_response"), "Coordinator scene owns one telemetry service and thin APIs")
	var telemetry_node := telemetry_nodes[0] as Node
	_expect(not telemetry_node.has_method("to_save_data") and not telemetry_node.has_method("apply_save_data"), "telemetry service is not a nineteenth save owner")
	_expect(_production_observer_tokens_present(), "product, route, monster and coordinator sources contain one-way telemetry observer hooks")

	weather.call("reset_state")
	_expect(int((telemetry.call("recent_events_snapshot") as Dictionary).get("count", -1)) == 0, "new run reset clears local telemetry")

	print("WEATHER_TELEMETRY_PRODUCTION_INTEGRATION_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _event_types(telemetry: Node) -> Array:
	var result: Array = []
	for event_variant in (telemetry.call("recent_events_snapshot") as Dictionary).get("events", []):
		result.append(str((event_variant as Dictionary).get("event_type", "")))
	return result


func _production_observer_tokens_present() -> bool:
	var sources := {
		"res://scripts/runtime/product_market_runtime_controller.gd": ["set_weather_telemetry_runtime_service", "product_price_growth_delta_percent"],
		"res://scripts/runtime/route_network_runtime_controller.gd": ["set_weather_telemetry_runtime_service", "route_efficiency_delta_percent"],
		"res://scripts/runtime/monster_runtime_controller.gd": ["set_weather_telemetry_runtime_service", "mark_monster_target_weather_influenced"],
		"res://scripts/runtime/game_runtime_coordinator.gd": ["record_weather_public_response", "WeatherTelemetryRuntimeService"],
	}
	for path in sources:
		var source := FileAccess.get_file_as_string(path)
		for token in sources[path]:
			if not source.contains(str(token)):
				return false
	return true


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(label)
	push_error("WEATHER TELEMETRY PRODUCTION: %s" % label)
