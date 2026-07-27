extends RefCounted
class_name FullRunAuthoritativeRuntimeStepper

const CONTRACT_ID := "full_run_authoritative_runtime_stepper_v1"
const MAX_STEP_SECONDS := 1.0
const ACTIVE_PHASE_TRACE: Array[StringName] = [
	&"lifecycle_begin",
	&"command",
	&"simulation",
	&"resolution",
	&"lifecycle_post_flow",
	&"state_commit",
	&"lifecycle_post_victory",
]
const PRESENTATION_PHASE := &"presentation_frame_end"
const BLOCKED_REALTIME_PHASE_TRACE: Array[StringName] = [
	&"lifecycle_blocked_realtime_probe",
	&"simulation_blocked_realtime",
	&"presentation_blocked_realtime",
]
const TERMINAL_PENDING_PHASE_TRACE: Array[StringName] = [&"terminal_presentation_retry"]


static func advance_bounded(runtime_loop: RuntimeLoop, step_seconds: float, max_steps: int) -> Dictionary:
	return _advance_bounded(runtime_loop, step_seconds, max_steps, RuntimeLoop.TEST_ADVANCE_MODE_FULL)


static func advance_blocked_realtime_bounded(runtime_loop: RuntimeLoop, step_seconds: float, max_steps: int) -> Dictionary:
	return _advance_bounded(runtime_loop, step_seconds, max_steps, RuntimeLoop.TEST_ADVANCE_MODE_BLOCKED_REALTIME_ONLY)


static func _advance_bounded(runtime_loop: RuntimeLoop, step_seconds: float, max_steps: int, mode: StringName) -> Dictionary:
	var result := {
		"accepted": false,
		"reason_id": "runtime_loop_unavailable",
		"attempted_steps": 0,
		"active_steps": 0,
		"world_seconds": 0.0,
		"blocked_realtime_steps": 0,
		"blocked_realtime_seconds": 0.0,
		"blocked_realtime_precondition_ended": false,
		"last_path": "unavailable",
		"last_stopped_reason": "runtime_loop_unavailable",
		"terminal_observed": false,
		"yield_required": true,
		"frame_index_before": 0,
		"frame_index_after": 0,
	}
	if runtime_loop == null:
		return result
	if runtime_loop.is_processing():
		result["reason_id"] = "automatic_frame_owner_still_active"
		return result
	if not is_finite(step_seconds) or step_seconds <= 0.0 or step_seconds > MAX_STEP_SECONDS:
		result["reason_id"] = "step_seconds_invalid"
		return result
	if max_steps <= 0 or max_steps > 64:
		result["reason_id"] = "step_count_invalid"
		return result

	var before := runtime_loop.debug_snapshot()
	var frame_index_before := int(before.get("frame_index", -1))
	if frame_index_before < 0 or not bool(before.get("frame_owner", false)) or not bool(before.get("phase_ready", false)):
		result["reason_id"] = "runtime_loop_not_ready"
		return result
	result["frame_index_before"] = frame_index_before
	result["frame_index_after"] = frame_index_before
	result["accepted"] = true
	result["reason_id"] = "step_budget_completed"
	result["yield_required"] = false

	for _step_index in range(max_steps):
		var receipt := runtime_loop.advance_frame_for_test(step_seconds, mode)
		result["attempted_steps"] = int(result.get("attempted_steps", 0)) + 1
		result["frame_index_after"] = int(receipt.get("frame_index", -1))
		result["last_path"] = str(receipt.get("path", "unavailable"))
		result["last_stopped_reason"] = str(receipt.get("stopped_reason", "runtime_step_unavailable"))
		if int(result.get("frame_index_after", -1)) != frame_index_before + int(result.get("attempted_steps", 0)):
			result["accepted"] = false
			result["reason_id"] = "runtime_frame_index_discontinuity"
			result["yield_required"] = true
			break

		var path := str(result.get("last_path", ""))
		var stopped_reason := str(result.get("last_stopped_reason", ""))
		if mode == RuntimeLoop.TEST_ADVANCE_MODE_BLOCKED_REALTIME_ONLY:
			if not is_equal_approx(float(receipt.get("real_delta", -1.0)), step_seconds) \
					or not is_zero_approx(float(receipt.get("world_delta", -1.0))):
				result["accepted"] = false
				result["reason_id"] = "blocked_realtime_delta_mismatch"
				result["yield_required"] = true
				break
			if path == "global_blocked":
				if not _valid_exact_phase_trace(receipt, BLOCKED_REALTIME_PHASE_TRACE) \
						or stopped_reason != "global_time_blocked":
					result["accepted"] = false
					result["reason_id"] = "blocked_realtime_phase_trace_invalid"
					result["yield_required"] = true
					break
				result["blocked_realtime_steps"] = int(result.get("blocked_realtime_steps", 0)) + 1
				result["blocked_realtime_seconds"] = float(result.get("blocked_realtime_seconds", 0.0)) + step_seconds
				result["reason_id"] = "blocked_realtime_step_completed"
				continue
			if path == "blocked_realtime_unavailable":
				result["blocked_realtime_precondition_ended"] = true
				result["reason_id"] = "blocked_realtime_precondition_ended:%s" % stopped_reason
				result["yield_required"] = true
				break
			if path == "terminal_pending":
				if not _valid_exact_phase_trace(receipt, TERMINAL_PENDING_PHASE_TRACE):
					result["accepted"] = false
					result["reason_id"] = "terminal_pending_phase_trace_invalid"
				else:
					result["reason_id"] = "terminal_presentation_pending"
				result["yield_required"] = true
				break
			if path == "finished":
				result["reason_id"] = "session_already_finished"
				result["terminal_observed"] = true
				result["yield_required"] = true
				break
			result["accepted"] = false
			result["reason_id"] = "blocked_realtime_path_not_advanceable:%s" % path
			result["yield_required"] = true
			break
		if path == "active":
			if not _valid_active_phase_trace(receipt, stopped_reason):
				result["accepted"] = false
				result["reason_id"] = "runtime_phase_trace_invalid"
				result["yield_required"] = true
				break
			if not is_equal_approx(float(receipt.get("real_delta", -1.0)), step_seconds) \
					or not is_equal_approx(float(receipt.get("world_delta", -1.0)), step_seconds):
				result["accepted"] = false
				result["reason_id"] = "runtime_world_delta_mismatch"
				result["yield_required"] = true
				break
			result["active_steps"] = int(result.get("active_steps", 0)) + 1
			result["world_seconds"] = float(result.get("world_seconds", 0.0)) + maxf(0.0, float(receipt.get("world_delta", 0.0)))
			if stopped_reason == "completed":
				var simulation_receipt: Dictionary = receipt.get("simulation_step_receipt", {}) \
					if receipt.get("simulation_step_receipt", {}) is Dictionary else {}
				if not bool(simulation_receipt.get("completed", false)):
					result["accepted"] = false
					result["reason_id"] = "simulation_step_not_completed"
					result["yield_required"] = true
					break
				continue
			if stopped_reason == "session_finished_after_victory":
				result["reason_id"] = "terminal_frame_completed"
				result["terminal_observed"] = true
				result["yield_required"] = true
				break
			result["reason_id"] = "active_frame_yield:%s" % stopped_reason
			result["yield_required"] = true
			break
		if path == "finished":
			result["reason_id"] = "session_already_finished"
			result["terminal_observed"] = true
			result["yield_required"] = true
			break
		if path == "terminal_pending":
			if not is_zero_approx(float(receipt.get("world_delta", -1.0))) \
					or not _valid_exact_phase_trace(receipt, TERMINAL_PENDING_PHASE_TRACE):
				result["accepted"] = false
				result["reason_id"] = "terminal_pending_receipt_invalid"
			else:
				result["reason_id"] = "terminal_presentation_pending"
			result["yield_required"] = true
			break
		if path in ["global_blocked", "paused", "postcommit_recovery"]:
			result["reason_id"] = "runtime_wait_yield:%s" % path
			result["yield_required"] = true
			break
		result["accepted"] = false
		result["reason_id"] = "runtime_path_not_advanceable:%s" % path
		result["yield_required"] = true
		break
	return result


static func _valid_active_phase_trace(receipt: Dictionary, stopped_reason: String) -> bool:
	var trace: Array = receipt.get("phase_trace", []) if receipt.get("phase_trace", []) is Array else []
	if trace.size() < ACTIVE_PHASE_TRACE.size():
		return false
	for index in range(ACTIVE_PHASE_TRACE.size()):
		if StringName(str(trace[index])) != ACTIVE_PHASE_TRACE[index]:
			return false
	if stopped_reason == "completed":
		return trace.size() == ACTIVE_PHASE_TRACE.size() + 1 \
			and StringName(str(trace[-1])) == PRESENTATION_PHASE
	return stopped_reason == "session_finished_after_victory" \
		and trace.size() == ACTIVE_PHASE_TRACE.size()


static func _valid_exact_phase_trace(receipt: Dictionary, expected: Array[StringName]) -> bool:
	var trace: Array = receipt.get("phase_trace", []) if receipt.get("phase_trace", []) is Array else []
	if trace.size() != expected.size():
		return false
	for index in range(expected.size()):
		if StringName(str(trace[index])) != expected[index]:
			return false
	return true
