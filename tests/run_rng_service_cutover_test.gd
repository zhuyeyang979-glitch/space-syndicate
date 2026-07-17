extends SceneTree

const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var coordinator := COORDINATOR_SCENE.instantiate() as GameRuntimeCoordinator
	root.add_child(coordinator)
	await process_frame
	var service := coordinator.run_rng_service()
	_expect(service != null, "production coordinator owns RunRngService")
	if service != null:
		service.state = 246813579
		var initial_state := service.state
		var first := [
			service.randi_range(0, 999999),
			service.randf_range(-50.0, 50.0),
			service.randf(),
		]
		service.state = initial_state
		var replay := [
			service.randi_range(0, 999999),
			service.randf_range(-50.0, 50.0),
			service.randf(),
		]
		_expect(first == replay, "restoring state reproduces the same random sequence")
		var saved := service.to_save_data()
		service.state = 135792468
		_expect(bool(service.apply_save_data(saved).get("applied", false)), "typed RNG save applies")
		_expect(service.state == int(saved.get("rng_state", 0)), "typed RNG save restores exact state")
		_expect(not bool(service.apply_save_data({"schema_version": 0, "rng_state": 1}).get("applied", true)), "invalid RNG save fails closed")

	for bridge_name in [
		"AiRuntimeWorldBridge",
		"MonsterRuntimeWorldBridge",
		"WeatherRuntimeWorldBridge",
		"ProductMarketRuntimeWorldBridge",
	]:
		var bridge := coordinator.get_node_or_null(bridge_name)
		_expect(bridge != null and bridge.call("shared_rng") == service, "%s consumes the typed RNG owner" % bridge_name)

	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	_expect(not main_source.contains("var rng :="), "Main no longer owns a RandomNumberGenerator")
	_expect(not main_source.contains("func _ai_runtime_rng_gateway("), "Main RNG compatibility gateway is physically deleted")
	_expect(not main_source.contains("_world.get(\"rng\")"), "Main does not provide an RNG compatibility property")
	var coordinator_scene_source := FileAccess.get_file_as_string("res://scenes/runtime/GameRuntimeCoordinator.tscn")
	_expect(coordinator_scene_source.count("RunRngService.tscn") == 1, "production composition contains exactly one RunRngService scene")
	for bridge_path in [
		"res://scripts/runtime/ai_runtime_world_bridge.gd",
		"res://scripts/runtime/monster_runtime_world_bridge.gd",
		"res://scripts/runtime/weather_runtime_world_bridge.gd",
		"res://scripts/runtime/product_market_runtime_world_bridge.gd",
	]:
		var source := FileAccess.get_file_as_string(bridge_path)
		_expect(not source.contains("_world.get(\"rng\")"), "%s has no Main RNG fallback" % bridge_path)
		_expect(source.contains("RunRngService"), "%s declares the typed RNG dependency" % bridge_path)
	coordinator.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Run RNG service cutover passed (%d checks)." % _checks)
		quit(0)
		return
	push_error("Run RNG service cutover failed:\n- " + "\n- ".join(_failures))
	quit(1)
