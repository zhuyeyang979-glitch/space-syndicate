extends SceneTree

const StepperScript := preload("res://scripts/tools/full_run_authoritative_runtime_stepper.gd")

class FakePhases extends RuntimePhaseCoordinator:
	var mode := "active"
	var active_advance_count := 0
	var blocked_advance_count := 0

	func is_ready() -> bool:
		return true

	func advance_frame(real_delta: float) -> Dictionary:
		active_advance_count += 1
		if mode == "global_blocked":
			return {
				"real_delta": real_delta,
				"world_delta": 0.0,
				"path": &"global_blocked",
				"stopped_reason": &"global_time_blocked",
				"trace": [] as Array[StringName],
				"phase_trace": [&"lifecycle_begin", &"simulation", &"presentation_frame_end"] as Array[StringName],
			}
		var phase_trace: Array[StringName] = StepperScript.ACTIVE_PHASE_TRACE.duplicate()
		var stopped_reason := &"completed"
		if mode == "terminal":
			stopped_reason = &"session_finished_after_victory"
		else:
			phase_trace.append(StepperScript.PRESENTATION_PHASE)
		if mode == "invalid_phase":
			phase_trace[1] = &"unexpected_phase"
		return {
			"real_delta": real_delta,
			"world_delta": real_delta,
			"path": &"active",
			"stopped_reason": stopped_reason,
			"trace": [] as Array[StringName],
			"phase_trace": phase_trace,
			"simulation_step_receipt": {"completed": mode != "incomplete_simulation"},
		}

	func advance_blocked_realtime_frame(real_delta: float) -> Dictionary:
		blocked_advance_count += 1
		if mode == "stale_block":
			return {
				"real_delta": real_delta,
				"world_delta": 0.0,
				"path": &"blocked_realtime_unavailable",
				"stopped_reason": &"global_time_not_blocked",
				"trace": [] as Array[StringName],
				"phase_trace": [&"lifecycle_blocked_realtime_probe"] as Array[StringName],
			}
		if mode == "strict_active_bug":
			return {
				"real_delta": real_delta,
				"world_delta": real_delta,
				"path": &"active",
				"stopped_reason": &"completed",
				"trace": [] as Array[StringName],
				"phase_trace": StepperScript.ACTIVE_PHASE_TRACE.duplicate(),
			}
		return {
			"real_delta": real_delta,
			"world_delta": 0.0,
			"path": &"global_blocked",
			"stopped_reason": &"global_time_blocked",
			"trace": [] as Array[StringName],
			"phase_trace": StepperScript.BLOCKED_REALTIME_PHASE_TRACE.duplicate(),
		}

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var active_fixture := _fixture("active")
	var active_loop := active_fixture[0] as RuntimeLoop
	var active := StepperScript.advance_bounded(active_loop, 0.5, 3)
	_expect(bool(active.get("accepted", false)), "disabled unique RuntimeLoop accepts bounded test stepping")
	_expect(int(active.get("attempted_steps", 0)) == 3 and int(active.get("active_steps", 0)) == 3, "one bounded request advances the requested active frame count")
	_expect(is_equal_approx(float(active.get("world_seconds", 0.0)), 1.5), "active world delta is accumulated exactly once per RuntimeLoop frame")
	_expect(int(active.get("frame_index_after", -1)) - int(active.get("frame_index_before", -1)) == 3, "frame index proves one owner call per manual step")
	_free_fixture(active_fixture)

	var automatic_fixture := _fixture("active", true)
	var automatic := StepperScript.advance_bounded(automatic_fixture[0] as RuntimeLoop, 0.25, 1)
	_expect(not bool(automatic.get("accepted", true)) and str(automatic.get("reason_id", "")) == "automatic_frame_owner_still_active", "manual stepping fails closed while automatic processing remains enabled")
	_free_fixture(automatic_fixture)

	var blocked_fixture := _fixture("global_blocked")
	var blocked := StepperScript.advance_bounded(blocked_fixture[0] as RuntimeLoop, 1.0, 4)
	_expect(bool(blocked.get("accepted", false)) and int(blocked.get("attempted_steps", 0)) == 1 and bool(blocked.get("yield_required", false)), "global block yields after one owner frame without consuming world time")
	_free_fixture(blocked_fixture)

	var blocked_realtime_fixture := _fixture("global_blocked")
	var blocked_realtime := StepperScript.advance_blocked_realtime_bounded(blocked_realtime_fixture[0] as RuntimeLoop, 1.0, 4)
	var blocked_realtime_phases := blocked_realtime_fixture[1] as FakePhases
	_expect(bool(blocked_realtime.get("accepted", false)) and int(blocked_realtime.get("blocked_realtime_steps", 0)) == 4, "blocked-only stepping consumes the bounded real-time budget")
	_expect(is_zero_approx(float(blocked_realtime.get("world_seconds", -1.0))) and is_equal_approx(float(blocked_realtime.get("blocked_realtime_seconds", 0.0)), 4.0), "blocked-only stepping advances no world time")
	_expect(blocked_realtime_phases.active_advance_count == 0 and blocked_realtime_phases.blocked_advance_count == 4, "blocked-only stepping cannot call the active phase entry")
	_free_fixture(blocked_realtime_fixture)

	var stale_fixture := _fixture("stale_block")
	var stale := StepperScript.advance_blocked_realtime_bounded(stale_fixture[0] as RuntimeLoop, 1.0, 4)
	var stale_phases := stale_fixture[1] as FakePhases
	_expect(bool(stale.get("accepted", false)) and bool(stale.get("blocked_realtime_precondition_ended", false)) and int(stale.get("attempted_steps", 0)) == 1, "a stale blocked projection becomes one zero-world no-op")
	_expect(stale_phases.active_advance_count == 0 and stale_phases.blocked_advance_count == 1, "a stale blocked projection cannot fall through to an active frame")
	_free_fixture(stale_fixture)

	var strict_bug_fixture := _fixture("strict_active_bug")
	var strict_bug := StepperScript.advance_blocked_realtime_bounded(strict_bug_fixture[0] as RuntimeLoop, 1.0, 1)
	_expect(not bool(strict_bug.get("accepted", true)) and str(strict_bug.get("reason_id", "")) == "blocked_realtime_delta_mismatch", "a blocked-only implementation that leaks world delta fails closed")
	_free_fixture(strict_bug_fixture)

	var terminal_fixture := _fixture("terminal")
	var terminal := StepperScript.advance_bounded(terminal_fixture[0] as RuntimeLoop, 1.0, 2)
	_expect(bool(terminal.get("accepted", false)) and bool(terminal.get("terminal_observed", false)) and int(terminal.get("attempted_steps", 0)) == 1, "terminal victory frame stops the bounded batch immediately")
	_free_fixture(terminal_fixture)

	var invalid_phase_fixture := _fixture("invalid_phase")
	var invalid_phase := StepperScript.advance_bounded(invalid_phase_fixture[0] as RuntimeLoop, 1.0, 1)
	_expect(not bool(invalid_phase.get("accepted", true)) and str(invalid_phase.get("reason_id", "")) == "runtime_phase_trace_invalid", "phase-order mutation fails closed")
	_free_fixture(invalid_phase_fixture)

	var incomplete_fixture := _fixture("incomplete_simulation")
	var incomplete := StepperScript.advance_bounded(incomplete_fixture[0] as RuntimeLoop, 1.0, 1)
	_expect(not bool(incomplete.get("accepted", true)) and str(incomplete.get("reason_id", "")) == "simulation_step_not_completed", "incomplete production simulation receipt fails closed")
	_free_fixture(incomplete_fixture)

	var invalid_fixture := _fixture("active")
	_expect(str(StepperScript.advance_bounded(invalid_fixture[0] as RuntimeLoop, 1.001, 1).get("reason_id", "")) == "step_seconds_invalid", "every authoritative step is capped at one world second")
	_expect(str(StepperScript.advance_bounded(invalid_fixture[0] as RuntimeLoop, 1.0, 65).get("reason_id", "")) == "step_count_invalid", "batch size is bounded")
	_free_fixture(invalid_fixture)
	_finish()


func _fixture(mode: String, processing := false) -> Array:
	var loop := RuntimeLoop.new()
	var phases := FakePhases.new()
	phases.mode = mode
	loop.bind_phase_coordinator(phases)
	loop.set_process(processing)
	return [loop, phases]


func _free_fixture(fixture: Array) -> void:
	(fixture[0] as RuntimeLoop).free()
	(fixture[1] as FakePhases).free()


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	print("full_run_authoritative_runtime_stepper_test: %s %d/%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks - _failures.size(), _checks])
	for failure in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)
