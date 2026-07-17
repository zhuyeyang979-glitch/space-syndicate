extends SceneTree

class TraceState extends RefCounted:
	var calls: Array[StringName] = []
	var finished := false
	var paused := false
	var globally_blocked := false
	var card_progress := true
	var flow_finalized := true
	var finish_after_flow := false
	var finish_after_victory := false
	var _flow_called := false
	var _victory_called := false
	var deltas: Dictionary = {}

	func _record(call_name: StringName, delta: float = -1.0) -> void:
		calls.append(call_name)
		if delta >= 0.0:
			deltas[str(call_name)] = delta


class FakeLifecyclePort extends RuntimeLifecyclePort:
	var state: TraceState
	func _init(value: TraceState) -> void: state = value
	func is_ready() -> bool: return true
	func session_is_finished() -> bool:
		state._record(&"session_is_finished")
		return state.finished or (state.finish_after_flow and state._flow_called) or (state.finish_after_victory and state._victory_called)

	func session_is_paused() -> bool:
		state._record(&"session_is_paused")
		return state.paused

	func synchronize_forced_decisions() -> Dictionary:
		state._record(&"synchronize_forced_decisions")
		return {"synchronized": true}
	func blocks_global_time() -> bool:
		state._record(&"blocks_global_time")
		return state.globally_blocked
	func advance_world_time(delta_seconds: float) -> Dictionary:
		state._record(&"advance_world_time", delta_seconds)
		return {"advanced": true}
	func allows_card_resolution_progress() -> bool:
		state._record(&"allows_card_resolution_progress")
		return state.card_progress

class FakeCardPort extends RuntimeCardPort:
	var state: TraceState
	func _init(value: TraceState) -> void: state = value
	func is_ready() -> bool: return true
	func advance_card_resolution_frame(delta_seconds: float) -> Dictionary:
		state._record(&"advance_card_resolution_frame", delta_seconds); return {}
	func tick_contract_runtime(delta_seconds: float) -> Dictionary:
		state._record(&"tick_contract_runtime", delta_seconds); return {}
	func advance_card_cooldowns(delta_seconds: float) -> Dictionary:
		state._record(&"advance_card_cooldowns", delta_seconds); return {}

class FakeEconomyPort extends RuntimeEconomyPort:
	var state: TraceState
	func _init(value: TraceState) -> void: state = value
	func is_ready() -> bool: return true
	func advance_city_gdp_derivative_timers() -> Dictionary:
		state._record(&"advance_city_gdp_derivative_timers"); return {}
	func advance_product_futures_timers() -> void: state._record(&"advance_product_futures_timers")
	func advance_economic_boons(delta_seconds: float) -> void: state._record(&"advance_economic_boons", delta_seconds)
	func advance_runtime_commodity_flow(delta_seconds: float) -> bool:
		state._record(&"advance_commodity_flow", delta_seconds)
		state._flow_called = true
		return state.flow_finalized
	func tick_product_market_cycle(delta_seconds: float) -> Dictionary:
		state._record(&"tick_product_market_cycle", delta_seconds); return {}

class FakeActorPort extends RuntimeActorPort:
	var state: TraceState
	func _init(value: TraceState) -> void: state = value
	func is_ready() -> bool: return true
	func tick_weather(delta_seconds: float) -> void: state._record(&"tick_weather", delta_seconds)
	func tick_ai(delta_seconds: float) -> void: state._record(&"tick_ai", delta_seconds)
	func tick_military(delta_seconds: float) -> void: state._record(&"tick_military", delta_seconds)

class FakeMonsterPort extends RuntimeMonsterPort:
	var state: TraceState
	func _init(value: TraceState) -> void: state = value
	func is_ready() -> bool: return true
	func tick_wagers(delta_seconds: float) -> void: state._record(&"tick_monster_wagers", delta_seconds)
	func tick_motion(delta_seconds: float) -> void: state._record(&"tick_monster_motion", delta_seconds)
	func tick_actions(delta_seconds: float) -> void: state._record(&"tick_monster_actions", delta_seconds)
	func tick_durations(delta_seconds: float) -> void: state._record(&"tick_monster_durations", delta_seconds)
	func tick_revivals(delta_seconds: float) -> void: state._record(&"tick_monster_revivals", delta_seconds)

class FakePresentationPort extends RuntimePresentationPort:
	var state: TraceState
	func _init(value: TraceState) -> void: state = value
	func is_ready() -> bool: return true
	func advance_visual_cues(delta_seconds: float) -> Dictionary:
		state._record(&"advance_visual_cues", delta_seconds); return {}
	func advance_table_presentation(delta_seconds: float) -> Array[TablePresentationApplyReceipt]:
		state._record(&"advance_table_presentation", delta_seconds); return [] as Array[TablePresentationApplyReceipt]

class FakeVictoryPort extends RuntimeVictoryPort:
	var state: TraceState
	func _init(value: TraceState) -> void: state = value
	func is_ready() -> bool: return true
	func advance_victory_control(delta_seconds: float, _clock_pause: Dictionary = {}) -> Dictionary:
		state._record(&"advance_victory_control", delta_seconds)
		state._victory_called = true
		return {}

class FakePorts extends RuntimeWorldPorts:
	var state: TraceState
	func _init(value: TraceState) -> void:
		state = value
		lifecycle = FakeLifecyclePort.new(state)
		lifecycle.name = "RuntimeLifecyclePort"; add_child(lifecycle)
		card = FakeCardPort.new(state)
		card.name = "RuntimeCardPort"; add_child(card)
		economy = FakeEconomyPort.new(state)
		economy.name = "RuntimeEconomyPort"; add_child(economy)
		actors = FakeActorPort.new(state)
		actors.name = "RuntimeActorPort"; add_child(actors)
		monster = FakeMonsterPort.new(state)
		monster.name = "RuntimeMonsterPort"; add_child(monster)
		presentation = FakePresentationPort.new(state)
		presentation.name = "RuntimePresentationPort"; add_child(presentation)
		victory = FakeVictoryPort.new(state)
		victory.name = "RuntimeVictoryPort"; add_child(victory)
	func is_ready() -> bool: return true


var failures: Array[String] = []
var checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_authority_structure()
	_test_active_trace()
	_test_blocked_pause_and_terminal_paths()
	_test_early_return_paths()
	_test_deterministic_port_replay()
	_test_scene_reconstruction()
	print("runtime_loop_cutover_test: %s %d/%d" % ["PASS" if failures.is_empty() else "FAIL", checks - failures.size(), checks])
	if not failures.is_empty():
		push_error("\n- ".join(failures))
	quit(0 if failures.is_empty() else 1)


func _test_authority_structure() -> void:
	var loop_source := FileAccess.get_file_as_string("res://scripts/runtime/runtime_loop.gd")
	var composition := FileAccess.get_file_as_string("res://scenes/runtime/GameRuntimeCoordinator.tscn")
	_check(loop_source.contains("func _process(real_delta: float)"), "RuntimeLoop owns the engine frame callback")
	_check(not loop_source.contains("/root/") and not loop_source.contains("current_scene"), "RuntimeLoop has no root-scene lookup or dependency")
	_check(composition.count("[node name=\"RuntimeLoop\"") == 1, "production coordinator composes exactly one RuntimeLoop")
	_check(composition.count("RuntimeLoop.tscn") == 1, "production coordinator has one RuntimeLoop resource")
	_check(loop_source.contains("var _phase_coordinator: RuntimePhaseCoordinator") and loop_source.contains("bind_phase_coordinator"), "RuntimeLoop depends on one explicit phase coordinator")
	_check(not loop_source.contains("RuntimeWorldPorts") and not loop_source.contains("tick_weather") and not loop_source.contains("tick_ai") and not loop_source.contains("advance_commodity_flow"), "RuntimeLoop knows no concrete gameplay system or port")
	_check(not loop_source.contains("GameScreen") and not loop_source.contains("PlanetBoard") and not loop_source.contains("receipt.kind"), "RuntimeLoop owns no concrete presentation target or receipt routing")
	_check(composition.count("RuntimePhaseCoordinator.tscn") == 1 and composition.count("[node name=\"RuntimePhaseCoordinator\"") == 1, "production coordinator composes exactly one phase graph")
	var audit := RuntimeAuthorityAudit.new()
	_check(audit.register_authority(&"runtime_loop", &"tick_owner", NodePath("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/RuntimeLoop"), 1), "runtime-loop tick authority registration is valid")
	var authority := audit.audit_snapshot()
	_check(bool(authority.get("ok", false)) and int(authority.get("duplicate_tick_count", -1)) == 0, "runtime-loop authority audit has no duplicate tick owner")
	_check(int(authority.get("duplicate_signal_count", -1)) == 0 and int(authority.get("duplicate_snapshot_count", -1)) == 0, "runtime-loop authority has no duplicate signal or snapshot owner")
	_check(int(authority.get("duplicate_save_writer_count", -1)) == 0 and int(authority.get("duplicate_mutation_path_count", -1)) == 0, "runtime-loop authority has no save or mutation ownership")
	audit.free()


func _test_active_trace() -> void:
	var state := TraceState.new()
	var ports := FakePorts.new(state)
	var loop := RuntimeLoop.new()
	_bind_loop_to_phases(loop, ports)
	var first := loop.advance_frame_for_test(0.25)
	var expected: Array[StringName] = [
		&"session_is_finished", &"synchronize_forced_decisions", &"blocks_global_time", &"session_is_paused",
		&"advance_world_time", &"allows_card_resolution_progress", &"advance_card_resolution_frame",
		&"tick_contract_runtime", &"advance_card_cooldowns", &"advance_city_gdp_derivative_timers",
		&"advance_product_futures_timers", &"tick_weather", &"advance_economic_boons",
		&"tick_monster_wagers", &"tick_ai", &"tick_monster_motion", &"tick_military",
		&"tick_monster_actions", &"tick_monster_durations", &"advance_visual_cues",
		&"tick_monster_revivals", &"advance_commodity_flow", &"session_is_finished",
		&"tick_product_market_cycle", &"advance_victory_control", &"session_is_finished",
		&"advance_table_presentation",
	]
	_check(state.calls == expected, "active frame preserves the complete production order")
	_check(first.get("phase_trace", []) == [&"lifecycle_begin", &"command", &"simulation", &"resolution", &"lifecycle_post_flow", &"state_commit", &"lifecycle_post_victory", &"presentation_frame_end"], "active frame exposes the explicit deterministic phase order")
	_check(int(first.get("frame_index", 0)) == 1 and str(first.get("path", "")) == "active", "first active frame produces one receipt")
	_check(is_equal_approx(float(first.get("real_delta", 0.0)), 0.25) and is_equal_approx(float(first.get("world_delta", 0.0)), 0.25), "real and world deltas preserve active 1x semantics")
	_check(is_equal_approx(float(state.deltas.get("advance_world_time", 0.0)), 0.25), "world delta reaches the clock once")
	state.calls.clear()
	var second := loop.advance_frame_for_test(0.5)
	_check(state.calls == expected and int(second.get("frame_index", 0)) == 2, "second frame adds one ordered sequence without replay")
	loop.free()
	ports.free()


func _test_blocked_pause_and_terminal_paths() -> void:
	var blocked_state := TraceState.new()
	blocked_state.globally_blocked = true
	var blocked_ports := FakePorts.new(blocked_state)
	var blocked_loop := RuntimeLoop.new()
	_bind_loop_to_phases(blocked_loop, blocked_ports)
	var blocked := blocked_loop.advance_frame_for_test(0.4)
	_check(blocked_state.calls == [&"session_is_finished", &"synchronize_forced_decisions", &"blocks_global_time", &"tick_monster_wagers", &"advance_visual_cues", &"advance_table_presentation"], "global block advances only wager, visuals and presentation")
	_check(str(blocked.get("path", "")) == "global_blocked" and is_equal_approx(float(blocked_state.deltas.get("advance_table_presentation", 0.0)), 0.4), "global block uses real delta")
	blocked_loop.free(); blocked_ports.free()

	var paused_state := TraceState.new()
	paused_state.paused = true
	var paused_ports := FakePorts.new(paused_state)
	var paused_loop := RuntimeLoop.new()
	_bind_loop_to_phases(paused_loop, paused_ports)
	paused_loop.advance_frame_for_test(0.4)
	_check(paused_state.calls == [&"session_is_finished", &"synchronize_forced_decisions", &"blocks_global_time", &"session_is_paused"], "ordinary pause stops gameplay and presentation cadence")
	paused_loop.free(); paused_ports.free()

	var finished_state := TraceState.new()
	finished_state.finished = true
	var finished_ports := FakePorts.new(finished_state)
	var finished_loop := RuntimeLoop.new()
	_bind_loop_to_phases(finished_loop, finished_ports)
	finished_loop.advance_frame_for_test(0.4)
	_check(finished_state.calls == [&"session_is_finished"], "terminal session stops before synchronization")
	finished_loop.free(); finished_ports.free()


func _test_early_return_paths() -> void:
	var flow_state := TraceState.new()
	flow_state.flow_finalized = false
	var flow_ports := FakePorts.new(flow_state)
	var flow_loop := RuntimeLoop.new()
	_bind_loop_to_phases(flow_loop, flow_ports)
	var flow_receipt := flow_loop.advance_frame_for_test(0.2)
	_check(str(flow_receipt.get("stopped_reason", "")) == "commodity_flow_not_finalized" and not flow_state.calls.has(&"tick_product_market_cycle"), "unfinalized commodity flow stops market and victory")
	flow_loop.free(); flow_ports.free()

	var victory_state := TraceState.new()
	victory_state.finish_after_victory = true
	var victory_ports := FakePorts.new(victory_state)
	var victory_loop := RuntimeLoop.new()
	_bind_loop_to_phases(victory_loop, victory_ports)
	var victory_receipt := victory_loop.advance_frame_for_test(0.2)
	_check(str(victory_receipt.get("stopped_reason", "")) == "session_finished_after_victory" and victory_state.calls.count(&"advance_table_presentation") == 0, "victory terminal state preserves the pre-cutover early return")
	victory_loop.free(); victory_ports.free()


func _test_deterministic_port_replay() -> void:
	var left_state := TraceState.new()
	var right_state := TraceState.new()
	var left_ports := FakePorts.new(left_state)
	var right_ports := FakePorts.new(right_state)
	var left_loop := RuntimeLoop.new()
	var right_loop := RuntimeLoop.new()
	_bind_loop_to_phases(left_loop, left_ports)
	_bind_loop_to_phases(right_loop, right_ports)
	var left_receipts: Array = []
	var right_receipts: Array = []
	for delta in [0.1, 0.25, 0.5]:
		left_receipts.append(left_loop.advance_frame_for_test(delta))
		right_receipts.append(right_loop.advance_frame_for_test(delta))
	_check(left_receipts == right_receipts, "identical delta sequences produce identical frame receipts")
	_check(left_state.calls == right_state.calls and left_state.deltas == right_state.deltas, "identical inputs produce the same ordered port mutation trace")
	left_loop.free(); right_loop.free(); left_ports.free(); right_ports.free()


func _test_scene_reconstruction() -> void:
	var packed := load("res://scenes/runtime/RuntimeLoop.tscn") as PackedScene
	var first := packed.instantiate() as RuntimeLoop
	var second := packed.instantiate() as RuntimeLoop
	_check(first != null and first.get_child_count() == 0, "RuntimeLoop scene reconstructs without hidden world children")
	_check(second != null and second.get_child_count() == 0, "a fresh reconstruction has no stale connection dependency")
	first.free(); second.free()


func _bind_loop_to_phases(loop: RuntimeLoop, ports: RuntimeWorldPorts) -> RuntimePhaseCoordinator:
	var packed := load("res://scenes/runtime/RuntimePhaseCoordinator.tscn") as PackedScene
	var phases := packed.instantiate() as RuntimePhaseCoordinator
	phases.lifecycle = phases.get_node("RuntimeLifecyclePhaseCoordinator") as RuntimeLifecyclePhaseCoordinator
	phases.command = phases.get_node("RuntimeCommandPhaseCoordinator") as RuntimeCommandPhaseCoordinator
	phases.simulation = phases.get_node("RuntimeSimulationPhaseCoordinator") as RuntimeSimulationPhaseCoordinator
	phases.resolution = phases.get_node("RuntimeResolutionPhaseCoordinator") as RuntimeResolutionPhaseCoordinator
	phases.state_commit = phases.get_node("RuntimeStateCommitCoordinator") as RuntimeStateCommitCoordinator
	phases.presentation_schedule = phases.get_node("RuntimePresentationScheduleCoordinator") as RuntimePresentationScheduleCoordinator
	phases.simulation_step = phases.get_node("RuntimeSimulationStep") as RuntimeSimulationStep
	phases.simulation_step.state_identity = phases.simulation_step.get_node("SimulationStateIdentity") as SimulationStateIdentity
	phases.simulation_step.randomness_boundary = phases.simulation_step.get_node("SimulationRandomnessBoundary") as SimulationRandomnessBoundary
	phases.bind_ports(ports)
	loop.add_child(phases)
	loop.bind_phase_coordinator(phases)
	return phases


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
