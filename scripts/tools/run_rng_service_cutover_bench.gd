extends Node

@onready var coordinator: GameRuntimeCoordinator = $GameRuntimeCoordinator


func _ready() -> void:
	var failures: Array[String] = []
	var checks := 0
	coordinator.configure({"ruleset_id": "v0.6"})
	var service := coordinator.run_rng_service()
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController
	var ai_bridge := coordinator.get_node_or_null("AiRuntimeWorldBridge") as AiRuntimeWorldBridge
	var world := coordinator.world_session_state()
	var game_session := coordinator.get_node_or_null("GameSessionRuntimeController") as GameSessionRuntimeController
	var market := coordinator.get_node_or_null("ProductMarketRuntimeController") as ProductMarketRuntimeController
	checks += 1
	if service == null or ai == null or ai_bridge == null or world == null or game_session == null or market == null:
		failures.append("typed_rng_composition_missing")
	else:
		checks += 1
		if ai.rng != service:
			failures.append("ai_direct_rng_identity_mismatch")
		service.set_seed(123456789)
		var checkpoint := service.capture_plan_checkpoint()
		var first := [ai.rng.randi_range(1, 100000), ai.rng.randi_range(1, 100000), ai.rng.randf()]
		var first_terminal := service.capture_plan_checkpoint()
		service.restore_plan_checkpoint(checkpoint)
		var replay := [ai.rng.randi_range(1, 100000), ai.rng.randi_range(1, 100000), ai.rng.randf()]
		checks += 1
		if first != replay or service.capture_plan_checkpoint() != first_terminal:
			failures.append("rng_checkpoint_replay_not_deterministic")

		game_session.configure({"ruleset_id": "v0.6"}, {})
		game_session.begin_session({
			"session_id": "rng-cutover-bench",
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
		checks += 1
		if first_order != [2, 1, 3] or replay_order != first_order or service.capture_plan_checkpoint() != order_terminal:
			failures.append("ai_seat_order_characterization_changed")
		checks += 1
		if int(order_terminal.get("draw_count", -1)) - int(order_checkpoint.get("draw_count", 0)) != 3:
			failures.append("ai_seat_order_draw_count_changed")

		var cap_checkpoint := service.capture_plan_checkpoint()
		var caps: Array = []
		for cycle in [0, 2, 3, 5, 6, 8, 9, 18]:
			market.business_cycle_count = cycle
			caps.append(ai._rival_auto_city_cap())
		checks += 1
		if caps != [2, 2, 3, 3, 4, 4, 5, 5]:
			failures.append("ai_city_cap_characterization_changed")
		checks += 1
		if service.capture_plan_checkpoint() != cap_checkpoint:
			failures.append("ai_city_cap_consumed_rng")

		var saved := service.to_save_data()
		service.set_seed(987654321)
		var restore := service.apply_save_data(saved)
		checks += 1
		if not bool(restore.get("applied", false)) or service.state != int(saved.get("rng_state", 0)):
			failures.append("rng_save_roundtrip_failed")

	for bridge_name in [
		"MonsterRuntimeWorldBridge",
		"WeatherRuntimeWorldBridge",
		"ProductMarketRuntimeWorldBridge",
	]:
		var bridge := coordinator.get_node_or_null(bridge_name)
		checks += 1
		if bridge == null or not bridge.has_method("shared_rng") or bridge.call("shared_rng") != service:
			failures.append("typed_rng_bridge_missing:%s" % bridge_name)
	checks += 1
	if ai_bridge == null or ai_bridge.has_method("shared_rng") or ai_bridge.has_method("set_rng_service") \
			or bool(ai_bridge.debug_snapshot().get("rng_service_ready", true)):
		failures.append("ai_bridge_still_exposes_rng")

	var snapshot := service.debug_snapshot() if service != null else {}
	checks += 1
	if not bool(snapshot.get("owns_rng_state", false)):
		failures.append("rng_authority_not_declared")
	var status := "PASS" if failures.is_empty() else "FAIL"
	print(
		"RUN_RNG_SERVICE_CUTOVER_BENCH|status=%s|checks=%d|failures=%d|notes=%s"
		% [status, checks, failures.size(), JSON.stringify(failures)]
	)
	if not failures.is_empty():
		push_error("Run RNG service cutover bench failed: %s" % failures)


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