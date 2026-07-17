extends SceneTree

const PHASE_SOURCES := [
	"res://scripts/runtime/runtime_lifecycle_phase_coordinator.gd",
	"res://scripts/runtime/runtime_command_phase_coordinator.gd",
	"res://scripts/runtime/runtime_simulation_phase_coordinator.gd",
	"res://scripts/runtime/runtime_resolution_phase_coordinator.gd",
	"res://scripts/runtime/runtime_state_commit_coordinator.gd",
	"res://scripts/runtime/runtime_presentation_schedule_coordinator.gd",
]

class PhaseTraceState extends RefCounted:
	var phases: Array[StringName] = []
	var deltas: Array[float] = []

	func record(phase: StringName, delta: float) -> void:
		phases.append(phase)
		deltas.append(delta)

class FakeLifecyclePhase extends RuntimeLifecyclePhaseCoordinator:
	var state: PhaseTraceState
	func _init(value: PhaseTraceState) -> void: state = value
	func is_ready() -> bool: return true
	func begin_frame(context: RuntimePhaseFrameContext) -> StringName:
		context.enter_phase(&"lifecycle_begin")
		context.path = &"active"
		context.stopped_reason = &"completed"
		context.world_delta = context.real_delta
		state.record(&"lifecycle_begin", context.real_delta)
		return &"active"
	func allow_after_flow(context: RuntimePhaseFrameContext) -> bool:
		context.enter_phase(&"lifecycle_post_flow")
		state.record(&"lifecycle_post_flow", context.world_delta)
		return true
	func allow_after_victory(context: RuntimePhaseFrameContext) -> bool:
		context.enter_phase(&"lifecycle_post_victory")
		state.record(&"lifecycle_post_victory", context.world_delta)
		return true

class FakeCommandPhase extends RuntimeCommandPhaseCoordinator:
	var state: PhaseTraceState
	func _init(value: PhaseTraceState) -> void: state = value
	func is_ready() -> bool: return true
	func advance_active(context: RuntimePhaseFrameContext) -> void:
		context.enter_phase(&"command")
		state.record(&"command", context.world_delta)

class FakeSimulationPhase extends RuntimeSimulationPhaseCoordinator:
	var state: PhaseTraceState
	func _init(value: PhaseTraceState) -> void: state = value
	func is_ready() -> bool: return true
	func advance_active(context: RuntimePhaseFrameContext) -> void:
		context.enter_phase(&"simulation")
		state.record(&"simulation", context.world_delta)

class FakeResolutionPhase extends RuntimeResolutionPhaseCoordinator:
	var state: PhaseTraceState
	func _init(value: PhaseTraceState) -> void: state = value
	func is_ready() -> bool: return true
	func advance_active(context: RuntimePhaseFrameContext) -> bool:
		context.enter_phase(&"resolution")
		state.record(&"resolution", context.world_delta)
		return true

class FakeStateCommitPhase extends RuntimeStateCommitCoordinator:
	var state: PhaseTraceState
	func _init(value: PhaseTraceState) -> void: state = value
	func is_ready() -> bool: return true
	func advance_active(context: RuntimePhaseFrameContext) -> void:
		context.enter_phase(&"state_commit")
		state.record(&"state_commit", context.world_delta)

class FakePresentationPhase extends RuntimePresentationScheduleCoordinator:
	var state: PhaseTraceState
	func _init(value: PhaseTraceState) -> void: state = value
	func is_ready() -> bool: return true
	func advance_frame_end(context: RuntimePhaseFrameContext) -> void:
		context.enter_phase(&"presentation_frame_end")
		state.record(&"presentation_frame_end", context.real_delta)

var checks := 0
var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_phase_ownership_gate()
	_test_phase_trace_and_delta_propagation()
	_test_deterministic_phase_replay()
	_test_coordinator_boundary()
	print("runtime_coordination_phase_decomposition_test: %s %d/%d" % ["PASS" if failures.is_empty() else "FAIL", checks - failures.size(), checks])
	if not failures.is_empty():
		push_error("\n- ".join(failures))
	quit(0 if failures.is_empty() else 1)


func _test_phase_ownership_gate() -> void:
	var loop_source := FileAccess.get_file_as_string("res://scripts/runtime/runtime_loop.gd")
	var root_source := FileAccess.get_file_as_string("res://scripts/runtime/runtime_phase_coordinator.gd")
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	var scene_source := FileAccess.get_file_as_string("res://scenes/runtime/GameRuntimeCoordinator.tscn")
	_check(loop_source.count("func _process(") == 1, "RuntimeLoop remains the single engine frame owner")
	_check(loop_source.count("_phase_coordinator.advance_frame(real_delta)") == 1, "RuntimeLoop invokes one phase boundary per frame")
	for concrete_marker in ["tick_weather", "tick_ai", "tick_monster", "advance_commodity", "advance_victory", "advance_card"]:
		_check(not loop_source.contains(concrete_marker), "RuntimeLoop does not know concrete system marker %s" % concrete_marker)
	_check(root_source.contains("class_name RuntimePhaseCoordinator") and root_source.contains("phase_count\": 6"), "one RuntimePhaseCoordinator owns the six-phase graph")
	_check(scene_source.count("RuntimePhaseCoordinator.tscn") == 1 and scene_source.count("[node name=\"RuntimePhaseCoordinator\"") == 1, "production composition has one phase coordinator")
	_check(not coordinator_source.contains("func _advance_authoritative_frame") and not coordinator_source.contains("phase_trace.append"), "GameRuntimeCoordinator owns no frame or phase-order switch")


func _test_phase_trace_and_delta_propagation() -> void:
	var state := PhaseTraceState.new()
	var phases := _fake_phase_graph(state)
	var receipt := phases.advance_frame(0.375)
	var expected: Array[StringName] = [
		&"lifecycle_begin", &"command", &"simulation", &"resolution",
		&"lifecycle_post_flow", &"state_commit", &"lifecycle_post_victory",
		&"presentation_frame_end",
	]
	_check(state.phases == expected, "one active frame executes every phase exactly once in authoritative order")
	_check(receipt.get("phase_trace", []) == expected, "phase receipt preserves the complete ordered phase trace")
	_check(state.deltas.size() == expected.size(), "every phase receives one delta")
	for delta in state.deltas:
		_check(is_equal_approx(delta, 0.375), "real/world delta propagation remains unchanged at 1x")
	phases.free()


func _test_deterministic_phase_replay() -> void:
	var left_state := PhaseTraceState.new()
	var right_state := PhaseTraceState.new()
	var left := _fake_phase_graph(left_state)
	var right := _fake_phase_graph(right_state)
	var left_receipts: Array = []
	var right_receipts: Array = []
	for delta in [0.1, 0.25, 0.5]:
		left_receipts.append(left.advance_frame(delta))
		right_receipts.append(right.advance_frame(delta))
	_check(left_receipts == right_receipts, "identical synthetic frames produce identical phase receipts")
	_check(left_state.phases == right_state.phases and left_state.deltas == right_state.deltas, "identical frames produce identical ordered phase execution")
	left.free(); right.free()


func _test_coordinator_boundary() -> void:
	for path in PHASE_SOURCES:
		var source := FileAccess.get_file_as_string(path)
		_check(not source.contains("func _process(") and not source.contains("Main") and not source.contains("current_scene") and not source.contains("/root/"), "%s owns no loop or root lookup" % path.get_file())
		_check(not source.contains("get_node(") and not source.contains("get_parent(") and not source.contains("find_child"), "%s performs no world traversal" % path.get_file())
		_check(not source.contains("cash") and not source.contains("damage") and not source.contains("price_delta") and not source.contains("production_delta"), "%s contains no gameplay formula fields" % path.get_file())
	var audit := RuntimeAuthorityAudit.new()
	_check(audit.register_authority(&"runtime_loop", &"tick_owner", NodePath("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/RuntimeLoop"), 1), "runtime tick authority registers once")
	for phase_name in ["lifecycle", "command", "simulation", "resolution", "state_commit", "presentation_schedule"]:
		_check(audit.register_authority(StringName("runtime_phase_%s" % phase_name), &"mutation_path", NodePath("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/RuntimePhaseCoordinator/%s" % phase_name), 1), "%s coordination path registers once" % phase_name)
	var result := audit.audit_snapshot()
	_check(bool(result.get("ok", false)) and int(result.get("duplicate_tick_count", -1)) == 0 and int(result.get("duplicate_mutation_path_count", -1)) == 0, "phase ownership adds no duplicate tick or mutation path")
	audit.free()


func _fake_phase_graph(state: PhaseTraceState) -> RuntimePhaseCoordinator:
	var phases := RuntimePhaseCoordinator.new()
	phases.lifecycle = FakeLifecyclePhase.new(state)
	phases.command = FakeCommandPhase.new(state)
	phases.simulation = FakeSimulationPhase.new(state)
	phases.resolution = FakeResolutionPhase.new(state)
	phases.state_commit = FakeStateCommitPhase.new(state)
	phases.presentation_schedule = FakePresentationPhase.new(state)
	phases.simulation_step = RuntimeSimulationStep.new()
	phases.simulation_step.state_identity = SimulationStateIdentity.new()
	phases.simulation_step.randomness_boundary = SimulationRandomnessBoundary.new()
	phases.add_child(phases.lifecycle)
	phases.add_child(phases.command)
	phases.add_child(phases.simulation)
	phases.add_child(phases.resolution)
	phases.add_child(phases.state_commit)
	phases.add_child(phases.presentation_schedule)
	phases.add_child(phases.simulation_step)
	phases.simulation_step.add_child(phases.simulation_step.state_identity)
	phases.simulation_step.add_child(phases.simulation_step.randomness_boundary)
	phases.simulation_step.bind_phases(phases.command, phases.simulation, phases.resolution, phases.lifecycle, phases.state_commit)
	return phases


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
