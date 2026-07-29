extends Node
class_name RuntimeLoop

signal frame_advanced(receipt: Dictionary)

const TEST_ADVANCE_MODE_FULL := &"full"
const TEST_ADVANCE_MODE_BLOCKED_REALTIME_ONLY := &"blocked_realtime_only"

var _phase_coordinator: RuntimePhaseCoordinator
var _frame_index := 0
var _last_frame_receipt: Dictionary = {}
var _session_start_barrier_id := ""
var _restore_barrier_id := ""


func _process(real_delta: float) -> void:
	_advance_authoritative_frame(real_delta)


func bind_phase_coordinator(coordinator: RuntimePhaseCoordinator) -> void:
	_phase_coordinator = coordinator


func advance_frame_for_test(real_delta: float, mode: StringName = TEST_ADVANCE_MODE_FULL) -> Dictionary:
	match mode:
		TEST_ADVANCE_MODE_FULL:
			return _advance_authoritative_frame(real_delta)
		TEST_ADVANCE_MODE_BLOCKED_REALTIME_ONLY:
			return _advance_blocked_realtime_frame(real_delta)
	return _finish_frame({
		"real_delta": maxf(0.0, real_delta),
		"world_delta": 0.0,
		"path": &"unavailable",
		"stopped_reason": &"test_advance_mode_invalid",
		"trace": [] as Array[StringName],
		"phase_trace": [] as Array[StringName],
	})


func last_frame_receipt() -> Dictionary:
	return _last_frame_receipt.duplicate(true)


func debug_snapshot() -> Dictionary:
	return {
		"frame_owner": true,
		"frame_index": _frame_index,
		"phase_ready": _phase_coordinator != null and _phase_coordinator.is_ready(),
		"phase_count": 6,
		"last_frame_receipt": _last_frame_receipt.duplicate(true),
		"phase": _phase_coordinator.debug_snapshot() if _phase_coordinator != null else {},
		"session_start_barrier_held": not _session_start_barrier_id.is_empty(),
		"restore_barrier_held": not _restore_barrier_id.is_empty(),
		"restore_barrier_id": _restore_barrier_id,
	}


func acquire_session_start_barrier(request_id: String) -> Dictionary:
	var normalized := request_id.strip_edges()
	if normalized.is_empty():
		return {"acquired": false, "reason_code": "session_start_barrier_id_missing"}
	if not _session_start_barrier_id.is_empty():
		return {"acquired": _session_start_barrier_id == normalized, "reason_code": "session_start_barrier_replayed" if _session_start_barrier_id == normalized else "session_start_barrier_busy"}
	_session_start_barrier_id = normalized
	return {"acquired": true, "reason_code": "session_start_barrier_acquired"}


func release_session_start_barrier(request_id: String) -> Dictionary:
	if _session_start_barrier_id != request_id.strip_edges():
		return {"released": false, "reason_code": "session_start_barrier_not_owned"}
	_session_start_barrier_id = ""
	return {"released": true, "reason_code": "session_start_barrier_released"}


func acquire_restore_barrier(operation_id: String) -> Dictionary:
	var normalized := operation_id.strip_edges()
	if normalized.is_empty():
		return {"acquired": false, "reason_code": "restore_barrier_id_missing"}
	if not _session_start_barrier_id.is_empty():
		return {"acquired": false, "reason_code": "session_start_barrier_busy"}
	if not _restore_barrier_id.is_empty():
		return {
			"acquired": _restore_barrier_id == normalized,
			"reason_code": "restore_barrier_replayed" if _restore_barrier_id == normalized else "restore_barrier_busy",
		}
	_restore_barrier_id = normalized
	return {"acquired": true, "reason_code": "restore_barrier_acquired"}


func release_restore_barrier(operation_id: String) -> Dictionary:
	if _restore_barrier_id != operation_id.strip_edges():
		return {"released": false, "reason_code": "restore_barrier_not_owned"}
	_restore_barrier_id = ""
	return {"released": true, "reason_code": "restore_barrier_released"}


func capture_runtime_checkpoint() -> Dictionary:
	return {
		"schema_version": 1,
		"frame_index": _frame_index,
		"last_frame_receipt": _last_frame_receipt.duplicate(true),
		"session_start_barrier_id": _session_start_barrier_id,
		"restore_barrier_id": _restore_barrier_id,
	}


func restore_runtime_checkpoint(checkpoint: Dictionary) -> Dictionary:
	var expected := ["schema_version", "frame_index", "last_frame_receipt", "session_start_barrier_id", "restore_barrier_id"]
	if checkpoint.keys().size() != expected.size():
		return {"applied": false, "reason_code": "runtime_loop_checkpoint_invalid"}
	for key in expected:
		if not checkpoint.has(key):
			return {"applied": false, "reason_code": "runtime_loop_checkpoint_invalid"}
	if not (checkpoint.get("schema_version") is int) \
			or int(checkpoint.get("schema_version", 0)) != 1 \
			or not (checkpoint.get("frame_index") is int) \
			or int(checkpoint.get("frame_index", -1)) < 0 \
			or not (checkpoint.get("last_frame_receipt") is Dictionary) \
			or not (checkpoint.get("session_start_barrier_id") is String) \
			or not (checkpoint.get("restore_barrier_id") is String):
		return {"applied": false, "reason_code": "runtime_loop_checkpoint_invalid"}
	_frame_index = int(checkpoint.get("frame_index", 0))
	_last_frame_receipt = (checkpoint.get("last_frame_receipt", {}) as Dictionary).duplicate(true)
	_session_start_barrier_id = str(checkpoint.get("session_start_barrier_id", ""))
	_restore_barrier_id = str(checkpoint.get("restore_barrier_id", ""))
	return {"applied": true, "reason_code": "runtime_loop_checkpoint_restored"}


func _advance_authoritative_frame(real_delta: float) -> Dictionary:
	if not _restore_barrier_id.is_empty():
		return _restore_blocked_receipt(real_delta)
	if not _session_start_barrier_id.is_empty():
		return _finish_frame({"real_delta": maxf(0.0, real_delta), "world_delta": 0.0, "path": &"blocked", "stopped_reason": &"session_start_in_progress", "trace": [] as Array[StringName], "phase_trace": [] as Array[StringName]})
	if _phase_coordinator == null or not _phase_coordinator.is_ready():
		return _finish_frame({
			"real_delta": maxf(0.0, real_delta),
			"world_delta": 0.0,
			"path": &"unavailable",
			"stopped_reason": &"runtime_phase_coordinator_unavailable",
			"trace": [] as Array[StringName],
			"phase_trace": [] as Array[StringName],
		})
	return _finish_frame(_phase_coordinator.advance_frame(real_delta))


func _advance_blocked_realtime_frame(real_delta: float) -> Dictionary:
	if not _restore_barrier_id.is_empty():
		return _restore_blocked_receipt(real_delta)
	if not _session_start_barrier_id.is_empty():
		return _finish_frame({"real_delta": maxf(0.0, real_delta), "world_delta": 0.0, "path": &"blocked", "stopped_reason": &"session_start_in_progress", "trace": [] as Array[StringName], "phase_trace": [] as Array[StringName]})
	if _phase_coordinator == null or not _phase_coordinator.is_ready():
		return _finish_frame({
			"real_delta": maxf(0.0, real_delta),
			"world_delta": 0.0,
			"path": &"unavailable",
			"stopped_reason": &"runtime_phase_coordinator_unavailable",
			"trace": [] as Array[StringName],
			"phase_trace": [] as Array[StringName],
		})
	return _finish_frame(_phase_coordinator.advance_blocked_realtime_frame(real_delta))


func _restore_blocked_receipt(real_delta: float) -> Dictionary:
	return {
		"real_delta": maxf(0.0, real_delta),
		"world_delta": 0.0,
		"path": &"blocked",
		"stopped_reason": &"save_restore_in_progress",
		"trace": [] as Array[StringName],
		"phase_trace": [] as Array[StringName],
		"frame_index": _frame_index,
		"frame_advanced": false,
	}


func _finish_frame(receipt: Dictionary) -> Dictionary:
	_frame_index += 1
	receipt["frame_index"] = _frame_index
	receipt["trace"] = (receipt.get("trace", []) as Array).duplicate()
	receipt["phase_trace"] = (receipt.get("phase_trace", []) as Array).duplicate()
	_last_frame_receipt = receipt.duplicate(true)
	frame_advanced.emit(_last_frame_receipt.duplicate(true))
	return _last_frame_receipt.duplicate(true)
