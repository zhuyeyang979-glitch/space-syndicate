extends SceneTree

const PORT_SOURCES := [
	"res://scripts/runtime/runtime_lifecycle_port.gd",
	"res://scripts/runtime/runtime_card_port.gd",
	"res://scripts/runtime/runtime_economy_port.gd",
	"res://scripts/runtime/runtime_actor_port.gd",
	"res://scripts/runtime/runtime_monster_port.gd",
	"res://scripts/runtime/runtime_presentation_port.gd",
	"res://scripts/runtime/runtime_victory_port.gd",
]

var checks := 0
var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_architecture_gate()
	_test_port_contracts()
	_test_mutation_boundary()
	_test_lifecycle_clock_contract()
	print("typed_world_ports_boundary_test: %s %d/%d" % ["PASS" if failures.is_empty() else "FAIL", checks - failures.size(), checks])
	if not failures.is_empty():
		push_error("\n- ".join(failures))
	quit(0 if failures.is_empty() else 1)


func _test_architecture_gate() -> void:
	var loop_source := FileAccess.get_file_as_string("res://scripts/runtime/runtime_loop.gd")
	_check(not loop_source.contains("get_node") and not loop_source.contains("get_parent") and not loop_source.contains("GameRuntimeCoordinator"), "RuntimeLoop has no scene traversal or coordinator dependency")
	_check(loop_source.contains("var _phase_coordinator: RuntimePhaseCoordinator") and loop_source.contains("func bind_phase_coordinator"), "RuntimeLoop receives one explicit phase coordinator")
	_check(not loop_source.contains("RuntimeWorldPorts") and not loop_source.contains(".card") and not loop_source.contains(".economy") and not loop_source.contains(".monster"), "RuntimeLoop has no concrete typed-port or gameplay-system knowledge")
	_check(not FileAccess.file_exists("res://scripts/runtime/authoritative_runtime_frame_port.gd") and not FileAccess.file_exists("res://scenes/runtime/AuthoritativeRuntimeFramePort.tscn"), "broad implicit frame adapter is physically retired")
	for path in PORT_SOURCES:
		var source := FileAccess.get_file_as_string(path)
		_check(not source.contains("Main") and not source.contains("current_scene") and not source.contains("/root/"), "%s has no root or Main dependency" % path.get_file())
		_check(not source.contains(".call(") and not source.contains(".callv(") and not source.contains("has_method("), "%s uses typed owner calls only" % path.get_file())
	var scene_source := FileAccess.get_file_as_string("res://scenes/runtime/RuntimeWorldPorts.tscn")
	_check(scene_source.count("[node name=\"Runtime") == 8, "port scene contains one root plus seven explicit port nodes")
	var coordinator_scene := FileAccess.get_file_as_string("res://scenes/runtime/GameRuntimeCoordinator.tscn")
	_check(coordinator_scene.count("RuntimeWorldPorts.tscn") == 1 and coordinator_scene.count("[node name=\"RuntimeWorldPorts\"") == 1, "production composition contains one port set")
	_check(coordinator_scene.count("RuntimePhaseCoordinator.tscn") == 1 and coordinator_scene.count("[node name=\"RuntimePhaseCoordinator\"") == 1, "production composition contains one explicit phase graph")


func _test_port_contracts() -> void:
	var packed := load("res://scenes/runtime/RuntimeWorldPorts.tscn") as PackedScene
	var ports := packed.instantiate() as RuntimeWorldPorts
	_check(ports != null and ports.get_child_count() == 7, "all seven typed ports reconstruct from the production scene")
	var required := {
		"RuntimeLifecyclePort": ["session_is_finished", "session_is_paused", "synchronize_forced_decisions", "blocks_global_time", "allows_card_resolution_progress", "advance_world_time"],
		"RuntimeCardPort": ["advance_card_resolution_frame", "tick_contract_runtime", "advance_card_cooldowns"],
		"RuntimeEconomyPort": ["advance_city_gdp_derivative_timers", "advance_product_futures_timers", "advance_economic_boons", "advance_commodity_flow", "advance_runtime_commodity_flow", "tick_product_market_cycle"],
		"RuntimeActorPort": ["tick_weather", "tick_ai", "tick_military"],
		"RuntimeMonsterPort": ["tick_wagers", "tick_motion", "tick_actions", "tick_durations", "tick_revivals"],
		"RuntimePresentationPort": ["advance_visual_cues", "advance_table_presentation"],
		"RuntimeVictoryPort": ["advance_victory_control"],
	}
	for child in ports.get_children():
		var expected: Array = required.get(child.get_class(), [])
		if expected.is_empty():
			expected = required.get(str(child.name), [])
		_check(not expected.is_empty(), "%s is an approved narrow port" % child.name)
		for method_name in expected:
			_check(child.has_method(method_name), "%s exposes %s" % [child.name, method_name])
		var snapshot: Dictionary = child.debug_snapshot()
		_check(int(snapshot.get("operation_count", 99)) <= 7, "%s stays below the seven-operation budget" % child.name)
	ports.free()


func _test_mutation_boundary() -> void:
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	for marker in ["ports.lifecycle", "ports.card", "ports.economy", "ports.actors", "ports.monster", "ports.presentation", "ports.victory"]:
		_check(coordinator_source.contains(marker), "Coordinator delegates migrated frame intent through %s" % marker)
	var audit := RuntimeAuthorityAudit.new()
	for domain in ["runtime_lifecycle", "runtime_card", "runtime_economy", "runtime_actors", "runtime_monster", "runtime_presentation", "runtime_victory"]:
		_check(audit.register_authority(StringName(domain), &"mutation_path", NodePath("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/RuntimeWorldPorts/%s" % domain), 1), "%s mutation path registers" % domain)
	var result := audit.audit_snapshot()
	_check(bool(result.get("ok", false)) and int(result.get("duplicate_mutation_path_count", -1)) == 0, "typed ports produce no duplicate mutation path")
	audit.free()


func _test_lifecycle_clock_contract() -> void:
	var session := GameSessionRuntimeController.new()
	var scheduler := ForcedDecisionRuntimeScheduler.new()
	var sources := ForcedDecisionCandidateSources.new()
	var clock := WorldEffectiveClockRuntimeController.new()
	var state := WorldSessionState.new()
	clock.configure({})
	var port := RuntimeLifecyclePort.new()
	port.bind_dependencies(session, scheduler, sources, clock, state)
	port.set_composition_ready(true)
	_check(port.is_ready(), "a fake-owned lifecycle boundary can drive a runtime test without a scene root")
	var receipt := port.advance_world_time(0.25)
	_check(is_equal_approx(float(receipt.get("world_effective_seconds", -1.0)), 0.25), "typed lifecycle port advances the existing clock once")
	_check(is_equal_approx(state.game_time, 0.25), "typed lifecycle port projects the same clock value to WorldSessionState")
	port.free(); session.free(); scheduler.free(); sources.free(); clock.free(); state.free()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
