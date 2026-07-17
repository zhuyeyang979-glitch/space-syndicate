extends RefCounted
class_name RuntimePhaseFrameContext

var real_delta := 0.0
var world_delta := 0.0
var path: StringName = &"unavailable"
var stopped_reason: StringName = &"runtime_phase_coordinator_unavailable"
var trace: Array[StringName] = []
var phase_trace: Array[StringName] = []
var simulation_step_index := 0
var simulation_step_receipt: Dictionary = {}


func _init(delta_seconds := 0.0) -> void:
	real_delta = maxf(0.0, delta_seconds)


func enter_phase(phase_name: StringName) -> void:
	phase_trace.append(phase_name)


func append_step(step_name: StringName) -> void:
	trace.append(step_name)


func receipt() -> Dictionary:
	return {
		"real_delta": real_delta,
		"world_delta": world_delta,
		"path": path,
		"stopped_reason": stopped_reason,
		"trace": trace.duplicate(),
		"phase_trace": phase_trace.duplicate(),
		"simulation_step_index": simulation_step_index,
		"simulation_step_receipt": simulation_step_receipt.duplicate(true),
	}
