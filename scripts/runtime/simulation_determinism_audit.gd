@tool
extends Node
class_name SimulationDeterminismAudit

const MAX_TRACE_COUNT := 32
const MAX_VIOLATION_COUNT := 32

var _identity: SimulationStateIdentity
var _recent_traces: Array[Dictionary] = []
var _violations: Array[Dictionary] = []
var _recent_mutations: Array[Dictionary] = []
var _current_identity: Dictionary = {}
var _current_step_index := 0
var _record_count := 0
var _rejected_trace_count := 0


func bind_identity(identity: SimulationStateIdentity) -> void:
	_identity = identity


func is_ready() -> bool:
	return _identity != null


func record_step(
	step_index: int,
	command_sequence: Array,
	command_results: Array,
	phase_transition: Array,
	state_fingerprint_before: String,
	state_fingerprint_after: String,
	mutation_summary: Array,
	completed: bool,
	stopped_reason: String = ""
) -> Dictionary:
	if not is_ready():
		return _reject_trace("simulation_audit_identity_unavailable")
	var trace := SimulationTraceContract.build(
		step_index,
		command_sequence,
		command_results,
		phase_transition,
		state_fingerprint_before,
		state_fingerprint_after,
		mutation_summary,
		completed,
		stopped_reason
	)
	var validation := SimulationTraceContract.validate(trace)
	if not bool(validation.get("valid", false)):
		return _reject_trace(str(validation.get("reason", "simulation_trace_invalid")))
	var trace_identity := _identity.identify(trace)
	if not bool(trace_identity.get("valid", false)):
		return _reject_trace(str(trace_identity.get("reason", "simulation_trace_identity_invalid")))
	trace["trace_fingerprint"] = str(trace_identity.get("fingerprint", ""))
	_recent_traces.append(trace.duplicate(true))
	while _recent_traces.size() > MAX_TRACE_COUNT:
		_recent_traces.pop_front()
	_current_step_index = step_index
	_current_identity = {
		"valid": true,
		"simulation_step_index": step_index,
		"fingerprint": state_fingerprint_after,
		"trace_fingerprint": str(trace.get("trace_fingerprint", "")),
	}
	_record_count += 1
	return {
		"recorded": true,
		"reason": "",
		"simulation_step_index": step_index,
		"state_fingerprint": state_fingerprint_after,
		"trace_fingerprint": str(trace.get("trace_fingerprint", "")),
	}


func record_violation(code: String, details: Dictionary = {}) -> Dictionary:
	var normalized_code := code.strip_edges()
	if normalized_code.is_empty():
		normalized_code = "deterministic_violation_unspecified"
	var details_identity := _identity.identify(details) if is_ready() else {"valid": false, "fingerprint": ""}
	var violation := {
		"code": normalized_code,
		"simulation_step_index": _current_step_index,
		"details_fingerprint": str(details_identity.get("fingerprint", "")) if bool(details_identity.get("valid", false)) else "",
	}
	_violations.append(violation)
	while _violations.size() > MAX_VIOLATION_COUNT:
		_violations.pop_front()
	return violation.duplicate(true)


func record_mutation(
	step_index: int,
	mutation_source: String,
	command_id: String,
	command_type: String,
	state_fingerprint_before: String,
	state_fingerprint_after: String,
	summary: Dictionary = {}
) -> Dictionary:
	if step_index <= 0 or mutation_source.strip_edges().is_empty() or command_id.strip_edges().is_empty() or command_type.strip_edges().is_empty():
		return {"recorded": false, "reason": "mutation_identity_invalid"}
	if not _is_sha256(state_fingerprint_before) or not _is_sha256(state_fingerprint_after):
		return {"recorded": false, "reason": "mutation_state_fingerprint_invalid"}
	if not SimulationTraceContract._is_pure_data(summary):
		return {"recorded": false, "reason": "mutation_summary_runtime_object"}
	var mutation := {
		"simulation_step_index": step_index,
		"mutation_source": mutation_source,
		"command_id": command_id,
		"command_type": command_type,
		"state_fingerprint_before": state_fingerprint_before,
		"state_fingerprint_after": state_fingerprint_after,
		"summary_fingerprint": str(_identity.identify(summary).get("fingerprint", "")) if is_ready() else "",
	}
	_recent_mutations.append(mutation)
	while _recent_mutations.size() > MAX_TRACE_COUNT:
		_recent_mutations.pop_front()
	return {"recorded": true, "reason": "", "mutation": mutation.duplicate(true)}


func current_simulation_identity() -> Dictionary:
	return _current_identity.duplicate(true)


func current_step_index() -> int:
	return _current_step_index


func recent_deterministic_trace() -> Dictionary:
	return _recent_traces[-1].duplicate(true) if not _recent_traces.is_empty() else {}


func recent_deterministic_traces(limit: int = MAX_TRACE_COUNT) -> Array:
	var count := mini(maxi(0, limit), _recent_traces.size())
	return _recent_traces.slice(_recent_traces.size() - count).duplicate(true) if count > 0 else []


func deterministic_violations() -> Array:
	return _violations.duplicate(true)


func recent_mutations(limit: int = MAX_TRACE_COUNT) -> Array:
	var count := mini(maxi(0, limit), _recent_mutations.size())
	return _recent_mutations.slice(_recent_mutations.size() - count).duplicate(true) if count > 0 else []


func clear_development_diagnostics() -> void:
	_recent_traces.clear()
	_recent_mutations.clear()
	_violations.clear()
	_current_identity.clear()
	_current_step_index = 0


func debug_snapshot() -> Dictionary:
	return {
		"development_only": true,
		"ready": is_ready(),
		"record_count": _record_count,
		"rejected_trace_count": _rejected_trace_count,
		"recent_trace_count": _recent_traces.size(),
		"violation_count": _violations.size(),
		"recent_mutation_count": _recent_mutations.size(),
		"current_step_index": _current_step_index,
		"current_identity": _current_identity.duplicate(true),
		"owns_world_state": false,
		"save_owner": false,
		"presentation_source": false,
}


func _is_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for index in range(value.length()):
		if value.substr(index, 1) not in "0123456789abcdef":
			return false
	return true


func _reject_trace(reason: String) -> Dictionary:
	_rejected_trace_count += 1
	record_violation(reason)
	return {"recorded": false, "reason": reason}
