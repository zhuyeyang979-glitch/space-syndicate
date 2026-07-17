extends Node
class_name RuntimeLoop

signal frame_advanced(receipt: Dictionary)

var _phase_coordinator: RuntimePhaseCoordinator
var _frame_index := 0
var _last_frame_receipt: Dictionary = {}


func _process(real_delta: float) -> void:
	_advance_authoritative_frame(real_delta)


func bind_phase_coordinator(coordinator: RuntimePhaseCoordinator) -> void:
	_phase_coordinator = coordinator


func advance_frame_for_test(real_delta: float) -> Dictionary:
	return _advance_authoritative_frame(real_delta)


func last_frame_receipt() -> Dictionary:
	return _last_frame_receipt.duplicate(true)


func debug_snapshot() -> Dictionary:
	return {
		"frame_owner": true,
		"frame_index": _frame_index,
		"phase_ready": _phase_coordinator != null and _phase_coordinator.is_ready(),
		"phase_count": 6,
		"last_frame_receipt": _last_frame_receipt.duplicate(true),
	}


func _advance_authoritative_frame(real_delta: float) -> Dictionary:
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


func _finish_frame(receipt: Dictionary) -> Dictionary:
	_frame_index += 1
	receipt["frame_index"] = _frame_index
	receipt["trace"] = (receipt.get("trace", []) as Array).duplicate()
	receipt["phase_trace"] = (receipt.get("phase_trace", []) as Array).duplicate()
	_last_frame_receipt = receipt.duplicate(true)
	frame_advanced.emit(_last_frame_receipt.duplicate(true))
	return _last_frame_receipt.duplicate(true)
