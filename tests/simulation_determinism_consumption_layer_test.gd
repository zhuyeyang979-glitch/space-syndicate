extends SceneTree

const STEP_SCENE := preload("res://scenes/runtime/RuntimeSimulationStep.tscn")


class TraceSink extends CardResolutionTransitionSink:
	var state: Dictionary
	var mutations: Array[String] = []

	func _init(initial: Dictionary) -> void:
		state = initial.duplicate(true)

	func apply_transition_batch(commands: Array) -> Dictionary:
		for command_variant in commands:
			var command := command_variant as Dictionary
			var effect := str(command.get("effect", ""))
			var amount := int(command.get("amount", 0))
			if effect == "reject":
				return {"handled": false, "reason": "synthetic_rejection"}
			if effect == "add":
				state["value"] = int(state.get("value", 0)) + amount
			elif effect == "multiply":
				state["value"] = int(state.get("value", 0)) * amount
			mutations.append("%s:%d" % [effect, amount])
		return {"handled": true, "reason": "", "command_count": commands.size()}


class TraceCommandPhase extends RuntimeCommandPhaseCoordinator:
	var pipeline: RuntimeCommandPipeline
	var pending: Array
	var last_receipt: Dictionary = {}
	var dispatched := false

	func _init(value: RuntimeCommandPipeline, commands: Array) -> void:
		pipeline = value
		pending = commands.duplicate(true)

	func is_ready() -> bool: return pipeline != null and pipeline.is_ready()

	func advance_active(context: RuntimePhaseFrameContext) -> void:
		context.enter_phase(&"command")
		context.append_step(&"consume_ordered_commands")
		if not dispatched:
			last_receipt = pipeline.dispatch_card_transition_batch(pending)
			dispatched = true


class TraceSimulationPhase extends RuntimeSimulationPhaseCoordinator:
	var state: Dictionary
	func _init(value: Dictionary) -> void: state = value
	func is_ready() -> bool: return true
	func advance_active(context: RuntimePhaseFrameContext) -> void:
		context.enter_phase(&"simulation")
		context.append_step(&"advance_synthetic_world")
		state["ticks"] = int(state.get("ticks", 0)) + 1


class TraceResolutionPhase extends RuntimeResolutionPhaseCoordinator:
	var fail := false
	func _init(value := false) -> void: fail = value
	func is_ready() -> bool: return true
	func advance_active(context: RuntimePhaseFrameContext) -> bool:
		context.enter_phase(&"resolution")
		context.append_step(&"resolve_synthetic_world")
		if fail:
			context.stopped_reason = &"synthetic_resolution_failed"
		return not fail


class TraceLifecyclePhase extends RuntimeLifecyclePhaseCoordinator:
	func is_ready() -> bool: return true
	func allow_after_flow(context: RuntimePhaseFrameContext) -> bool:
		context.enter_phase(&"lifecycle_post_flow")
		context.append_step(&"post_flow_gate")
		return true
	func allow_after_victory(context: RuntimePhaseFrameContext) -> bool:
		context.enter_phase(&"lifecycle_post_victory")
		context.append_step(&"post_victory_gate")
		return true


class TraceCommitPhase extends RuntimeStateCommitCoordinator:
	var state: Dictionary
	func _init(value: Dictionary) -> void: state = value
	func is_ready() -> bool: return true
	func advance_active(context: RuntimePhaseFrameContext) -> void:
		context.enter_phase(&"state_commit")
		context.append_step(&"commit_synthetic_world")
		state["commits"] = int(state.get("commits", 0)) + 1


var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_trace_contract_and_serialization()
	_test_step_by_step_determinism()
	_test_ordering_and_rejection_results()
	_test_error_lifecycle_is_stable()
	_test_audit_api_is_passive_and_bounded()
	_test_audit_history_limit()
	_test_random_source_gate()
	await _test_production_composition()
	print("simulation_determinism_consumption_layer_test: %s %d/%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks - _failures.size(), _checks])
	if not _failures.is_empty():
		push_error("\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _test_trace_contract_and_serialization() -> void:
	var identity := SimulationStateIdentity.new()
	var before := str(identity.identify({"value": 1}).get("fingerprint", ""))
	var after := str(identity.identify({"value": 3}).get("fingerprint", ""))
	var trace := SimulationTraceContract.build(
		1,
		[{"command_id": "c1", "command_type": "card_resolution_transition", "order_index": 0, "private_payload": "not copied"}],
		[{"command_id": "c1", "accepted": true, "reason": "", "private_receipt": "not copied"}],
		[&"command", &"simulation", &"state_commit"],
		before,
		after,
		[{"domain": "synthetic", "mutation_kind": "add", "target_key": "value", "outcome": "applied", "summary_fingerprint": after, "cash": 999}],
		true
	)
	_check(bool(SimulationTraceContract.validate(trace).get("valid", false)), "trace contract accepts the complete allowlisted pure-data shape")
	var encoded := identity.stable_serialize(trace)
	var reordered := trace.duplicate(true)
	var rebuilt := {}
	for key in ["completed", "state_fingerprint_after", "command_results", "schema_version", "phase_transition", "simulation_step_index", "state_fingerprint_before", "deterministic_mutation_summary", "stopped_reason", "command_sequence"]:
		rebuilt[key] = reordered.get(key)
	var reordered_encoded := identity.stable_serialize(rebuilt)
	_check(bool(encoded.get("valid", false)) and encoded.get("fingerprint") == reordered_encoded.get("fingerprint"), "trace serialization is stable across dictionary insertion order")
	var serialized := str(encoded.get("serialized", ""))
	_check(not serialized.contains("private_payload") and not serialized.contains("private_receipt") and not serialized.contains("cash"), "trace allowlists exclude unapproved payload, receipt and economic fields")
	var bad := trace.duplicate(true)
	bad["ui_state"] = {"hovered": true}
	_check(not bool(SimulationTraceContract.validate(bad).get("valid", true)), "trace validation rejects UI or engine-surface keys")
	var node := Node.new()
	bad = trace.duplicate(true)
	bad["runtime"] = node
	_check(not bool(SimulationTraceContract.validate(bad).get("valid", true)), "trace validation rejects Node/Object references")
	bad = trace.duplicate(true)
	bad["runtime"] = Resource.new()
	_check(not bool(SimulationTraceContract.validate(bad).get("valid", true)), "trace validation rejects Resource references")
	bad = trace.duplicate(true)
	bad["runtime"] = Callable(identity, "debug_snapshot")
	_check(not bool(SimulationTraceContract.validate(bad).get("valid", true)), "trace validation rejects Callable references")
	node.free(); identity.free()


func _test_step_by_step_determinism() -> void:
	var commands := _commands(["add", "multiply"])
	var left := _run_trace(commands, 3)
	var right := _run_trace(commands, 3)
	_check(left.final_fingerprint == right.final_fingerprint, "same initial state and command stream produce the same final fingerprint")
	_check(left.step_fingerprints == right.step_fingerprints and (left.step_fingerprints as Array).size() == 3, "every intermediate step fingerprint reproduces exactly")
	_check(left.phase_traces == right.phase_traces, "every simulation-step phase transition reproduces exactly")
	_check(left.mutation_traces == right.mutation_traces, "every deterministic mutation summary reproduces exactly")
	_check(left.traces == right.traces, "bounded trace consumer emits identical pure-data traces across independent runs")


func _test_ordering_and_rejection_results() -> void:
	var ordered := _run_trace(_commands(["add", "multiply"]), 1)
	var reversed := _run_trace(_commands(["multiply", "add"]), 1)
	_check(ordered.final_fingerprint != reversed.final_fingerprint, "order-dependent commands produce different final fingerprints")
	var rejected := _run_trace(_commands(["reject"]), 1)
	var result_rows: Array = (rejected.traces as Array)[0].get("command_results", [])
	_check(result_rows.size() == 1 and not bool((result_rows[0] as Dictionary).get("accepted", true)), "trace records rejected command result without hiding rejection")
	_check(str((result_rows[0] as Dictionary).get("reason", "")) == "synthetic_rejection", "rejected command trace preserves a stable reason code")


func _test_error_lifecycle_is_stable() -> void:
	var left := _run_trace([], 1, true)
	var right := _run_trace([], 1, true)
	var left_trace: Dictionary = (left.traces as Array)[0]
	_check(left.traces == right.traces and left.final_fingerprint == right.final_fingerprint, "identical error paths produce identical trace and state identity")
	_check(not bool(left_trace.get("completed", true)) and str(left_trace.get("stopped_reason", "")) == "synthetic_resolution_failed", "resolution failure is explicit and deterministic")
	_check(not (left_trace.get("phase_transition", []) as Array).has("state_commit"), "failed resolution never performs an implicit commit")


func _test_audit_api_is_passive_and_bounded() -> void:
	var run := _run_trace(_commands(["add"]), 2)
	var api: Dictionary = run.api
	_check(int(api.get("step_index", 0)) == 2 and str((api.get("identity", {}) as Dictionary).get("fingerprint", "")).length() == 64, "development API exposes current step and identity metadata")
	_check(not (api.get("recent_trace", {}) as Dictionary).is_empty(), "development API exposes the most recent deterministic trace")
	_check((api.get("violations", []) as Array).size() == 1 and str(((api.get("violations", []) as Array)[0] as Dictionary).get("code", "")) == "synthetic_audit_probe", "development API exposes fingerprint-only deterministic violations")
	var source := FileAccess.get_file_as_string("res://scripts/runtime/simulation_determinism_audit.gd")
	_check(not source.contains("func _process(") and not source.contains("to_save_data") and not source.contains("apply_save_data"), "audit consumer owns no tick and no save format")
	_check(not source.contains("GameScreen") and not source.contains("Control") and not source.contains("CanvasItem"), "audit consumer is not a presentation source")


func _test_audit_history_limit() -> void:
	var identity := SimulationStateIdentity.new()
	var audit := SimulationDeterminismAudit.new()
	audit.bind_identity(identity)
	var fingerprint := str(identity.identify({"bounded": true}).get("fingerprint", ""))
	for step_index in range(1, 41):
		audit.record_step(step_index, [], [], [&"command", &"state_commit"], fingerprint, fingerprint, [], true)
		audit.record_violation("bounded_probe", {"step": step_index})
	var traces := audit.recent_deterministic_traces(1000)
	var violations := audit.deterministic_violations()
	_check(traces.size() == SimulationDeterminismAudit.MAX_TRACE_COUNT and int((traces[0] as Dictionary).get("simulation_step_index", 0)) == 9, "trace history is bounded and evicts the oldest development record")
	_check(violations.size() == SimulationDeterminismAudit.MAX_VIOLATION_COUNT, "violation history is bounded and cannot become a permanent journal")
	audit.free(); identity.free()


func _test_random_source_gate() -> void:
	var direct_rng_files: Array[String] = []
	for path in _gd_files("res://scripts"):
		if path.begins_with("res://scripts/tools/"):
			continue
		var source := FileAccess.get_file_as_string(path)
		if source.contains("RandomNumberGenerator.new()"):
			direct_rng_files.append(path)
	direct_rng_files.sort()
	_check(direct_rng_files == ["res://scripts/runtime/run_rng_service.gd"], "RunRngService is the only production file allowed to construct an RNG")
	var region_supply_source := FileAccess.get_file_as_string("res://scripts/runtime/region_supply_runtime_controller.gd")
	_check(region_supply_source.contains("RunRngService.deterministic_weighted_shuffle") and not region_supply_source.contains("RandomNumberGenerator.new()"), "region supply consumes its restorable derived stream through RunRngService")
	var wiring := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	for marker in ["set_rng_service(service)", "_wire_run_rng_service"]:
		_check(wiring.contains(marker), "production gameplay RNG wiring retains %s" % marker)
	var boundary := SimulationRandomnessBoundary.new()
	var unauthorized := boundary.audit([{"source_id": "new_hidden_rng", "classification": "uncontrolled", "seedable": false, "reproducible": false, "can_mutate_world": true}])
	_check(not bool(unauthorized.get("valid", true)) and int(unauthorized.get("violation_count", 0)) == 1, "new uncontrolled simulation randomness is detected")
	boundary.free()


func _test_production_composition() -> void:
	var step := STEP_SCENE.instantiate() as RuntimeSimulationStep
	root.add_child(step)
	await process_frame
	_check(step.find_children("SimulationDeterminismAudit", "SimulationDeterminismAudit", true, false).size() == 1, "production SimulationStep composes exactly one development audit consumer")
	_check(step.determinism_audit != null and step.determinism_audit.is_ready(), "production audit binds the existing state-identity owner")
	_check(not bool(step.determinism_audit.debug_snapshot().get("save_owner", true)) and not bool(step.determinism_audit.debug_snapshot().get("presentation_source", true)), "production audit is neither save owner nor presentation source")
	step.queue_free()
	await process_frame


func _run_trace(commands: Array, step_count: int, resolution_fails := false) -> Dictionary:
	var initial := {"value": 1, "ticks": 0, "commits": 0}
	var sink := TraceSink.new(initial)
	var pipeline := RuntimeCommandPipeline.new()
	pipeline.bind_card_transition_sink(sink)
	var command := TraceCommandPhase.new(pipeline, commands)
	var simulation := TraceSimulationPhase.new(sink.state)
	var resolution := TraceResolutionPhase.new(resolution_fails)
	var lifecycle := TraceLifecyclePhase.new()
	var commit := TraceCommitPhase.new(sink.state)
	var step := RuntimeSimulationStep.new()
	step.state_identity = SimulationStateIdentity.new()
	step.randomness_boundary = SimulationRandomnessBoundary.new()
	step.determinism_audit = SimulationDeterminismAudit.new()
	step.determinism_audit.bind_identity(step.state_identity)
	step.bind_phases(command, simulation, resolution, lifecycle, commit)
	var traces: Array = []
	var step_fingerprints: Array = []
	var phase_traces: Array = []
	var mutation_traces: Array = []
	for index in range(step_count):
		var before := sink.state.duplicate(true)
		var context := RuntimePhaseFrameContext.new(0.25)
		context.path = &"active"
		context.world_delta = 0.25
		var receipt := step.advance_active(context)
		var sequence: Array = command.last_receipt.get("command_trace", []) if index == 0 else []
		var results := _command_results(sequence, command.last_receipt) if index == 0 else []
		var after_identity := step.identify_state(sink.state)
		var mutations := [{
			"domain": "synthetic",
			"mutation_kind": "step",
			"target_key": "world",
			"outcome": "committed" if bool(receipt.get("completed", false)) else "stopped",
			"summary_fingerprint": str(after_identity.get("fingerprint", "")),
		}]
		var recorded := step.record_deterministic_trace(before, sink.state, sequence, results, mutations)
		if not bool(recorded.get("recorded", false)):
			_failures.append("synthetic trace failed to record: %s" % str(recorded.get("reason", "")))
		var trace := step.recent_deterministic_trace()
		traces.append(trace)
		step_fingerprints.append(str(trace.get("state_fingerprint_after", "")))
		phase_traces.append((trace.get("phase_transition", []) as Array).duplicate())
		mutation_traces.append((trace.get("deterministic_mutation_summary", []) as Array).duplicate(true))
	step.record_deterministic_violation("synthetic_audit_probe", {"step": step.current_step_index()})
	var final_identity := step.identify_state(sink.state)
	var result := {
		"final_fingerprint": str(final_identity.get("fingerprint", "")),
		"step_fingerprints": step_fingerprints,
		"phase_traces": phase_traces,
		"mutation_traces": mutation_traces,
		"traces": traces,
		"api": {
			"step_index": step.current_step_index(),
			"identity": step.current_simulation_identity(),
			"recent_trace": step.recent_deterministic_trace(),
			"violations": step.deterministic_violations(),
		},
	}
	step.determinism_audit.free(); step.state_identity.free(); step.randomness_boundary.free(); step.free()
	command.free(); simulation.free(); resolution.free(); lifecycle.free(); commit.free(); pipeline.free(); sink.free()
	return result


func _command_results(sequence: Array, receipt: Dictionary) -> Array:
	var results: Array = []
	for entry_variant in sequence:
		var entry := entry_variant as Dictionary
		results.append({
			"command_id": str(entry.get("command_id", "")),
			"accepted": bool(receipt.get("handled", false)),
			"reason": str(receipt.get("reason", "")),
			"result_fingerprint": str(entry.get("envelope_fingerprint", "")),
		})
	return results


func _commands(order: Array[String]) -> Array:
	var result: Array = []
	for index in range(order.size()):
		var effect := order[index]
		var amount := 2 if effect == "add" else 3
		var payload := {
			"command_schema_version": 1,
			"transition": "trace_%s" % effect,
			"effect": effect,
			"amount": amount,
			"batch_revision": 17,
			"revision": 17,
			"order_index": index,
			"phase": "trace",
			"command_fingerprint": "trace:%d:%s:%d" % [index, effect, amount],
		}
		payload["command_id"] = "trace:%d:%s" % [index, effect]
		result.append(payload)
	return result


func _gd_files(root_path: String) -> Array[String]:
	var result: Array[String] = []
	var directory := DirAccess.open(root_path)
	if directory == null:
		return result
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if name != "." and name != "..":
			var path := root_path.path_join(name)
			if directory.current_is_dir():
				result.append_array(_gd_files(path))
			elif name.ends_with(".gd"):
				result.append(path)
		name = directory.get_next()
	directory.list_dir_end()
	return result


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
