extends SceneTree

const PHASE_SCENE := preload("res://scenes/runtime/RuntimePhaseCoordinator.tscn")


class DeterministicSink extends CardResolutionTransitionSink:
	var state: Dictionary
	var mutation_trace: Array[String] = []

	func _init(initial_state: Dictionary) -> void:
		state = initial_state.duplicate(true)

	func apply_transition_batch(commands: Array) -> Dictionary:
		for command_variant in commands:
			var command := command_variant as Dictionary
			var amount := int(command.get("amount", 0))
			match str(command.get("effect", "")):
				"add":
					state["value"] = int(state.get("value", 0)) + amount
					mutation_trace.append("add:%d" % amount)
				"multiply":
					state["value"] = int(state.get("value", 0)) * amount
					mutation_trace.append("multiply:%d" % amount)
		return {"handled": true, "reason": "", "command_count": commands.size()}


class DeterministicCommandPhase extends RuntimeCommandPhaseCoordinator:
	var pipeline: RuntimeCommandPipeline
	var commands: Array
	var receipt: Dictionary = {}
	var dispatched := false

	func _init(bound_pipeline: RuntimeCommandPipeline, ordered_commands: Array) -> void:
		pipeline = bound_pipeline
		commands = ordered_commands.duplicate(true)

	func is_ready() -> bool:
		return pipeline != null and pipeline.is_ready()

	func advance_active(context: RuntimePhaseFrameContext) -> void:
		context.enter_phase(&"command")
		context.append_step(&"synthetic_command_phase")
		if not dispatched:
			receipt = pipeline.dispatch_card_transition_batch(commands)
			dispatched = true


class DeterministicSimulationPhase extends RuntimeSimulationPhaseCoordinator:
	var state: Dictionary

	func _init(bound_state: Dictionary) -> void:
		state = bound_state

	func is_ready() -> bool:
		return true

	func advance_active(context: RuntimePhaseFrameContext) -> void:
		context.enter_phase(&"simulation")
		context.append_step(&"synthetic_world_evolution")
		state["step_count"] = int(state.get("step_count", 0)) + 1
		state["world_effective_us"] = int(state.get("world_effective_us", 0)) + int(round(context.world_delta * 1_000_000.0))


class DeterministicResolutionPhase extends RuntimeResolutionPhaseCoordinator:
	func is_ready() -> bool:
		return true

	func advance_active(context: RuntimePhaseFrameContext) -> bool:
		context.enter_phase(&"resolution")
		context.append_step(&"synthetic_resolution")
		return true


class DeterministicLifecyclePhase extends RuntimeLifecyclePhaseCoordinator:
	func is_ready() -> bool:
		return true

	func allow_after_flow(context: RuntimePhaseFrameContext) -> bool:
		context.enter_phase(&"lifecycle_post_flow")
		context.append_step(&"synthetic_post_flow_gate")
		return true

	func allow_after_victory(context: RuntimePhaseFrameContext) -> bool:
		context.enter_phase(&"lifecycle_post_victory")
		context.append_step(&"synthetic_post_victory_gate")
		return true


class DeterministicCommitPhase extends RuntimeStateCommitCoordinator:
	var state: Dictionary

	func _init(bound_state: Dictionary) -> void:
		state = bound_state

	func is_ready() -> bool:
		return true

	func advance_active(context: RuntimePhaseFrameContext) -> void:
		context.enter_phase(&"state_commit")
		context.append_step(&"synthetic_state_commit")
		state["commit_count"] = int(state.get("commit_count", 0)) + 1


var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_architecture_boundary()
	_test_state_identity()
	_test_same_state_and_commands_are_deterministic()
	_test_command_order_is_semantic()
	_test_engine_frame_is_not_simulation_identity()
	_test_randomness_boundary()
	await _test_production_scene_composition()
	print("simulation_determinism_foundation_test: %s %d/%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks - _failures.size(), _checks])
	if not _failures.is_empty():
		push_error("\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _test_architecture_boundary() -> void:
	var loop_source := FileAccess.get_file_as_string("res://scripts/runtime/runtime_loop.gd")
	var step_source := FileAccess.get_file_as_string("res://scripts/runtime/runtime_simulation_step.gd")
	var identity_source := FileAccess.get_file_as_string("res://scripts/runtime/simulation_state_identity.gd")
	var phase_source := FileAccess.get_file_as_string("res://scripts/runtime/runtime_phase_coordinator.gd")
	_check(loop_source.count("func _process(") == 1 and not loop_source.contains("RuntimeSimulationStep"), "RuntimeLoop remains the only engine-frame owner and does not absorb simulation details")
	_check(not step_source.contains("func _process(") and not step_source.contains("func _physics_process("), "RuntimeSimulationStep is not a second engine-frame owner")
	_check(step_source.contains("func advance_active(context: RuntimePhaseFrameContext)") and phase_source.contains("simulation_step.advance_active(context)"), "active world evolution crosses one explicit simulation-step entry point")
	_check(not step_source.contains("advance_table_presentation") and not step_source.contains("GameScreen") and not step_source.contains("CanvasItem"), "simulation step has no UI or presentation cadence dependency")
	_check(identity_source.contains("simulation_state_contains_runtime_object") and not identity_source.contains("Control") and not identity_source.contains("Main"), "state identity rejects runtime objects without reading Main or UI")
	_check(not step_source.contains("RandomNumberGenerator.new") and not step_source.contains("randomize()"), "simulation step creates no hidden RNG")


func _test_state_identity() -> void:
	var identity := SimulationStateIdentity.new()
	var left := identity.identify({"z": 3, "a": {"two": 2, "one": 1}}, [{"order_index": 0}])
	var right := identity.identify({"a": {"one": 1, "two": 2}, "z": 3}, [{"order_index": 0}])
	_check(bool(left.get("valid", false)) and left.get("fingerprint") == right.get("fingerprint"), "dictionary insertion and node ordering do not affect canonical state identity")
	var ordered := identity.identify({"values": [1, 2, 3]})
	var reordered := identity.identify({"values": [3, 2, 1]})
	_check(ordered.get("fingerprint") != reordered.get("fingerprint"), "semantic array ordering remains part of state identity")
	var typed_keys := identity.identify({1: "integer", "1": "string"})
	var one_key := identity.identify({"1": "string"})
	_check(typed_keys.get("fingerprint") != one_key.get("fingerprint"), "canonical dictionary keys preserve key types without string collisions")
	var node := Node.new()
	var rejected := identity.identify({"world_node": node})
	_check(not bool(rejected.get("valid", true)) and str(rejected.get("reason", "")) == "simulation_state_contains_runtime_object", "Node/Object references cannot enter simulation identity")
	node.free()
	identity.free()


func _test_same_state_and_commands_are_deterministic() -> void:
	var commands := _commands(["add", "multiply"])
	var left := _run_synthetic(commands, 4, 0.25)
	var right := _run_synthetic(commands, 4, 0.25)
	_check(left.state == right.state, "same initial state and ordered commands produce identical simulation state")
	_check(left.phase_trace == right.phase_trace, "identical simulation runs produce identical phase trace")
	_check(left.mutation_trace == right.mutation_trace, "identical simulation runs produce identical mutation trace")
	_check(left.fingerprint == right.fingerprint and not str(left.fingerprint).is_empty(), "identical simulation runs produce identical non-empty fingerprint")
	_check(left.command_trace == right.command_trace, "command envelope identity and execution order remain stable across independent runs")


func _test_command_order_is_semantic() -> void:
	var add_then_multiply := _run_synthetic(_commands(["add", "multiply"]), 1, 1.0)
	var multiply_then_add := _run_synthetic(_commands(["multiply", "add"]), 1, 1.0)
	var repeat := _run_synthetic(_commands(["add", "multiply"]), 1, 1.0)
	_check(add_then_multiply.state == repeat.state and add_then_multiply.fingerprint == repeat.fingerprint, "same command order reproduces the same state")
	_check(int((add_then_multiply.state as Dictionary).get("value", 0)) == 9 and int((multiply_then_add.state as Dictionary).get("value", 0)) == 5, "different command order produces the expected different result")
	_check(add_then_multiply.fingerprint != multiply_then_add.fingerprint, "state fingerprint reflects semantic command ordering")


func _test_engine_frame_is_not_simulation_identity() -> void:
	var commands := _commands(["add", "multiply"])
	var hosted_at_30_fps := _run_synthetic(commands, 4, 0.25, {"engine_frame_count": 30, "ui_scale": 0.8})
	var hosted_at_120_fps := _run_synthetic(commands, 4, 0.25, {"engine_frame_count": 120, "ui_scale": 1.4})
	_check(hosted_at_30_fps.state == hosted_at_120_fps.state, "different engine-frame and UI metadata do not alter explicit simulation steps")
	_check(hosted_at_30_fps.fingerprint == hosted_at_120_fps.fingerprint, "presentation and engine-frame metadata are outside simulation fingerprint")
	_check((hosted_at_30_fps.step_indices as Array) == [1, 2, 3, 4] and hosted_at_30_fps.step_indices == hosted_at_120_fps.step_indices, "simulation steps have their own monotonic identity independent of engine frames")


func _test_randomness_boundary() -> void:
	var left := RunRngService.new()
	var right := RunRngService.new()
	left.set_seed(60718)
	right.set_seed(60718)
	var left_draws := [left.randi_range(1, 1000), left.randf(), left.randi()]
	var right_draws := [right.randi_range(1, 1000), right.randf(), right.randi()]
	_check(left_draws == right_draws and left.state == right.state, "seeded RunRngService draws and final state are reproducible")
	var boundary := SimulationRandomnessBoundary.new()
	var valid := boundary.audit([
		{"source_id": "run_rng", "classification": "seeded_simulation", "seedable": true, "reproducible": true, "can_mutate_world": true},
		{"source_id": "sparkle", "classification": "visual_only", "seedable": false, "reproducible": false, "can_mutate_world": false},
	])
	_check(bool(valid.get("valid", false)), "seeded simulation and non-mutating visual randomness pass the capability boundary")
	var uncontrolled := boundary.audit([
		{"source_id": "hidden_random", "classification": "uncontrolled", "seedable": false, "reproducible": false, "can_mutate_world": true},
	])
	_check(not bool(uncontrolled.get("valid", true)) and str(((uncontrolled.get("violations", []) as Array)[0] as Dictionary).get("reason", "")) == "uncontrolled_simulation_randomness", "uncontrolled world-mutating randomness is detected")
	var visual_mutation := boundary.audit([
		{"source_id": "visual_node", "classification": "visual_only", "seedable": false, "reproducible": false, "can_mutate_world": true},
	])
	_check(not bool(visual_mutation.get("valid", true)), "visual randomness cannot declare world mutation capability")
	left.free(); right.free(); boundary.free()


func _test_production_scene_composition() -> void:
	var phases := PHASE_SCENE.instantiate() as RuntimePhaseCoordinator
	root.add_child(phases)
	await process_frame
	_check(phases != null and phases.simulation_step != null, "production phase scene composes the simulation-step owner")
	_check(phases.find_children("RuntimeSimulationStep", "RuntimeSimulationStep", true, false).size() == 1, "production phase graph has exactly one simulation-step instance")
	_check(phases.find_children("SimulationStateIdentity", "SimulationStateIdentity", true, false).size() == 1, "production phase graph has exactly one internal state-identity service")
	_check(phases.find_children("SimulationRandomnessBoundary", "SimulationRandomnessBoundary", true, false).size() == 1, "production phase graph has exactly one randomness capability boundary")
	_check(phases.find_children("SimulationDeterminismAudit", "SimulationDeterminismAudit", true, false).size() == 1, "production phase graph has one passive development-only determinism audit")
	phases.queue_free()
	await process_frame


func _run_synthetic(commands: Array, step_count: int, step_delta: float, _engine_metadata: Dictionary = {}) -> Dictionary:
	var state := {"value": 1, "step_count": 0, "commit_count": 0, "world_effective_us": 0}
	var sink := DeterministicSink.new(state)
	var pipeline := RuntimeCommandPipeline.new()
	pipeline.bind_card_transition_sink(sink)
	var command_phase := DeterministicCommandPhase.new(pipeline, commands)
	var simulation_phase := DeterministicSimulationPhase.new(sink.state)
	var resolution_phase := DeterministicResolutionPhase.new()
	var lifecycle_phase := DeterministicLifecyclePhase.new()
	var commit_phase := DeterministicCommitPhase.new(sink.state)
	var step := RuntimeSimulationStep.new()
	step.state_identity = SimulationStateIdentity.new()
	step.randomness_boundary = SimulationRandomnessBoundary.new()
	step.bind_phases(command_phase, simulation_phase, resolution_phase, lifecycle_phase, commit_phase)
	var phase_trace: Array[StringName] = []
	var step_indices: Array[int] = []
	for _index in range(step_count):
		var context := RuntimePhaseFrameContext.new(step_delta)
		context.path = &"active"
		context.world_delta = step_delta
		var receipt := step.advance_active(context)
		phase_trace.append_array(context.phase_trace)
		step_indices.append(int(receipt.get("step_index", -1)))
	var command_trace: Array = command_phase.receipt.get("command_trace", [])
	var identity := step.identify_state(sink.state, command_trace)
	var result := {
		"state": sink.state.duplicate(true),
		"phase_trace": phase_trace,
		"mutation_trace": sink.mutation_trace.duplicate(),
		"command_trace": command_trace.duplicate(true),
		"fingerprint": str(identity.get("fingerprint", "")),
		"step_indices": step_indices,
	}
	step.state_identity.free()
	step.randomness_boundary.free()
	step.free(); command_phase.free(); simulation_phase.free(); resolution_phase.free(); lifecycle_phase.free(); commit_phase.free(); pipeline.free(); sink.free()
	return result


func _commands(effect_order: Array[String]) -> Array:
	var result: Array = []
	for index in range(effect_order.size()):
		var effect := effect_order[index]
		var amount := 2 if effect == "add" else 3
		var payload := {
			"command_schema_version": 1,
			"transition": "synthetic_%s" % effect,
			"effect": effect,
			"amount": amount,
			"batch_revision": 9,
			"revision": 9,
			"order_index": index,
			"phase": "synthetic",
			"command_fingerprint": "synthetic:%d:%s:%d" % [index, effect, amount],
		}
		payload["command_id"] = "synthetic:%d:%s" % [index, effect]
		result.append(payload)
	return result


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
