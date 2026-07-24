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
	coordinator.configure({"ruleset_id": "v0.6"})
	var service := coordinator.run_rng_service()
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController
	var ai_bridge := coordinator.get_node_or_null("AiRuntimeWorldBridge") as AiRuntimeWorldBridge
	var world := coordinator.world_session_state()
	var game_session := coordinator.get_node_or_null("GameSessionRuntimeController") as GameSessionRuntimeController
	var market := coordinator.get_node_or_null("ProductMarketRuntimeController") as ProductMarketRuntimeController
	_expect(
		service != null and ai != null and ai_bridge != null and world != null \
			and game_session != null and market != null,
		"production composition exposes the typed RNG owner and its direct AI consumer"
	)
	if service != null and ai != null:
		_expect(ai.rng == service, "AiRuntimeController receives the coordinator-owned RunRngService directly")
		service.set_seed(246813579)
		var sequence_checkpoint := service.capture_plan_checkpoint()
		var first := [
			ai.rng.randi_range(0, 999999),
			ai.rng.randf_range(-50.0, 50.0),
			ai.rng.randf(),
		]
		var first_terminal := service.capture_plan_checkpoint()
		service.restore_plan_checkpoint(sequence_checkpoint)
		var replay := [
			ai.rng.randi_range(0, 999999),
			ai.rng.randf_range(-50.0, 50.0),
			ai.rng.randf(),
		]
		var replay_terminal := service.capture_plan_checkpoint()
		_expect(
			first == replay and first_terminal == replay_terminal,
			"restoring the typed checkpoint reproduces the AI draw values and terminal state"
		)
		_expect(
			int(first_terminal.get("draw_count", -1)) - int(sequence_checkpoint.get("draw_count", 0)) == 3,
			"mixed AI RNG characterization consumes exactly three draws"
		)

		game_session.configure({"ruleset_id": "v0.6"}, {})
		game_session.begin_session({
			"session_id": "rng-cutover-characterization",
			"scenario_id": "focused",
			"seed": 8191,
			"player_count": 4,
		})
		world.restore({
			"players": [
				_player(0, false),
				_player(1, true),
				_player(2, true),
				_player(3, true),
			],
			"districts": [],
			"game_time": 0.0,
		}, true)
		coordinator._wire_ai_world_typed_ports()
		service.set_seed(8191)
		var order_checkpoint := service.capture_plan_checkpoint()
		var first_order := ai._rival_build_player_order()
		var order_terminal := service.capture_plan_checkpoint()
		service.restore_plan_checkpoint(order_checkpoint)
		var replay_order := ai._rival_build_player_order()
		var replay_order_terminal := service.capture_plan_checkpoint()
		_expect(
			first_order == [2, 1, 3] and replay_order == first_order,
			"fixed seed preserves the characterized AI seat order"
		)
		_expect(
			order_terminal == replay_order_terminal \
				and int(order_terminal.get("draw_count", -1)) - int(order_checkpoint.get("draw_count", 0)) == 3,
			"AI seat ordering preserves terminal RNG state and its three-draw order"
		)

		var cap_checkpoint := service.capture_plan_checkpoint()
		var city_caps: Array = []
		for cycle in [0, 2, 3, 5, 6, 8, 9, 18]:
			market.business_cycle_count = cycle
			city_caps.append(ai._rival_auto_city_cap())
		_expect(
			city_caps == [2, 2, 3, 3, 4, 4, 5, 5],
			"typed session facts preserve the characterized 2-to-5 AI city-cap progression"
		)
		_expect(
			service.capture_plan_checkpoint() == cap_checkpoint,
			"city-cap queries consume zero RNG"
		)

		var saved := service.to_save_data()
		service.set_seed(135792468)
		_expect(bool(service.apply_save_data(saved).get("applied", false)), "typed RNG save applies")
		_expect(service.state == int(saved.get("rng_state", 0)), "typed RNG save restores exact state")
		_expect(not bool(service.apply_save_data({"schema_version": 0, "rng_state": 1}).get("applied", true)), "invalid RNG save fails closed")

	for bridge_name in [
		"MonsterRuntimeWorldBridge",
		"WeatherRuntimeWorldBridge",
		"ProductMarketRuntimeWorldBridge",
	]:
		var bridge := coordinator.get_node_or_null(bridge_name)
		_expect(
			bridge != null and bridge.has_method("shared_rng") and bridge.call("shared_rng") == service,
			"%s consumes the typed RNG owner" % bridge_name
		)
	_expect(
		ai_bridge != null and not ai_bridge.has_method("shared_rng") and not ai_bridge.has_method("set_rng_service") \
			and not bool(ai_bridge.debug_snapshot().get("rng_service_ready", true)),
		"AiRuntimeWorldBridge exposes no RNG capability"
	)

	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var ai_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_runtime_controller.gd")
	var ai_bridge_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_runtime_world_bridge.gd")
	_expect(not main_source.contains("var rng :="), "Main no longer owns a RandomNumberGenerator")
	_expect(not main_source.contains("func _ai_runtime_rng_gateway("), "Main RNG compatibility gateway is physically deleted")
	_expect(not main_source.contains("_world.get(\"rng\")"), "Main does not provide an RNG compatibility property")
	_expect(
		ai_source.contains("func set_run_rng_service(") and ai_source.contains("return _run_rng_service") \
			and not ai_source.contains("RandomNumberGenerator.new"),
		"AI declares only the direct typed RNG dependency"
	)
	_expect(
		not ai_bridge_source.contains("RunRngService") and not ai_bridge_source.contains("shared_rng"),
		"AI bridge source contains no RNG owner or forwarding API"
	)
	var coordinator_scene_source := FileAccess.get_file_as_string("res://scenes/runtime/GameRuntimeCoordinator.tscn")
	_expect(coordinator_scene_source.count("RunRngService.tscn") == 1, "production composition contains exactly one RunRngService scene")
	for bridge_path in [
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


func _player(index: int, is_ai: bool) -> Dictionary:
	return {
		"id": "player:%d" % index,
		"actor_id": "actor:%d" % index,
		"name": "AI-%d" % index if is_ai else "Human",
		"seat_type": "ai" if is_ai else "human",
		"is_ai": is_ai,
		"eliminated": false,
		"ai_profile": {},
		"ai_memory": {},
	}


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