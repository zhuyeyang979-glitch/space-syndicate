extends Node

@onready var coordinator: GameRuntimeCoordinator = $GameRuntimeCoordinator


func _ready() -> void:
	var failures: Array[String] = []
	var service := coordinator.run_rng_service()
	if service == null:
		failures.append("production_rng_service_missing")
	else:
		service.state = 123456789
		var before := service.state
		var first := [
			service.randi_range(1, 100000),
			service.randi_range(1, 100000),
			service.randf(),
		]
		service.state = before
		var replay := [
			service.randi_range(1, 100000),
			service.randi_range(1, 100000),
			service.randf(),
		]
		if first != replay:
			failures.append("rng_replay_not_deterministic")
		var saved := service.to_save_data()
		service.state = 987654321
		var restore := service.apply_save_data(saved)
		if not bool(restore.get("applied", false)) or service.state != int(saved.get("rng_state", 0)):
			failures.append("rng_save_roundtrip_failed")

	for bridge_name in [
		"AiRuntimeWorldBridge",
		"MonsterRuntimeWorldBridge",
		"WeatherRuntimeWorldBridge",
		"ProductMarketRuntimeWorldBridge",
	]:
		var bridge := coordinator.get_node_or_null(bridge_name)
		if bridge == null or not bridge.has_method("shared_rng") or bridge.call("shared_rng") != service:
			failures.append("typed_rng_bridge_missing:%s" % bridge_name)

	var snapshot := service.debug_snapshot() if service != null else {}
	if not bool(snapshot.get("owns_rng_state", false)):
		failures.append("rng_authority_not_declared")
	var status := "PASS" if failures.is_empty() else "FAIL"
	print(
		"RUN_RNG_SERVICE_CUTOVER_BENCH|status=%s|checks=9|failures=%d|notes=%s"
		% [status, failures.size(), JSON.stringify(failures)]
	)
	if not failures.is_empty():
		push_error("Run RNG service cutover bench failed: %s" % failures)
