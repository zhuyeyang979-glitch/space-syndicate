@tool
extends Node
class_name SimulationMutationAuthority

const MAX_RECENT_MUTATIONS := 32

var _identity: SimulationStateIdentity
var _audit: SimulationDeterminismAudit
var _active_step_index := 0
var _active := false
var _recent_authorizations: Array[Dictionary] = []
var _rejected_count := 0


func bind_diagnostics(identity: SimulationStateIdentity, audit: SimulationDeterminismAudit) -> void:
	_identity = identity
	_audit = audit


func begin_step(step_index: int) -> Dictionary:
	if _active:
		_rejected_count += 1
		return {"opened": false, "reason": "simulation_step_already_active"}
	if step_index <= 0:
		_rejected_count += 1
		return {"opened": false, "reason": "simulation_step_index_invalid"}
	_active_step_index = step_index
	_active = true
	return {"opened": true, "step_index": step_index}


func end_step() -> Dictionary:
	var receipt := {"closed": _active, "step_index": _active_step_index}
	_active = false
	return receipt


func is_active() -> bool:
	return _active


func current_step_index() -> int:
	return _active_step_index


func authorize_mutation(command: Dictionary) -> Dictionary:
	if not _active:
		_rejected_count += 1
		return _reject("simulation_mutation_outside_active_step")
	if not _is_pure_data(command):
		_rejected_count += 1
		return _reject("simulation_mutation_command_runtime_object")
	var command_type := str(command.get("command_type", "")).strip_edges()
	var command_id := str(command.get("command_id", "")).strip_edges()
	var source := str(command.get("source", "")).strip_edges()
	if command_type.is_empty() or command_id.is_empty() or source.is_empty():
		_rejected_count += 1
		return _reject("simulation_mutation_command_identity_missing")
	var authorization := {
		"authorized": true,
		"step_index": _active_step_index,
		"command_type": command_type,
		"command_id": command_id,
		"source": source,
	}
	_recent_authorizations.append(authorization.duplicate(true))
	while _recent_authorizations.size() > MAX_RECENT_MUTATIONS:
		_recent_authorizations.pop_front()
	return authorization


func record_mutation(
	command: Dictionary,
	state_before: Dictionary,
	state_after: Dictionary,
	summary: Dictionary = {}
) -> Dictionary:
	if not _active:
		return _reject("simulation_mutation_record_outside_active_step")
	if _identity == null or _audit == null:
		return _reject("simulation_mutation_diagnostics_unavailable")
	var before := _identity.identify(state_before)
	var after := _identity.identify(state_after)
	if not bool(before.get("valid", false)) or not bool(after.get("valid", false)):
		return _reject("simulation_mutation_projection_invalid")
	var receipt := _audit.record_mutation(
		_active_step_index,
		str(command.get("source", "")),
		str(command.get("command_id", "")),
		str(command.get("command_type", "")),
		str(before.get("fingerprint", "")),
		str(after.get("fingerprint", "")),
		summary
	)
	if bool(receipt.get("recorded", false)):
		return receipt
	return _reject(str(receipt.get("reason", "simulation_mutation_audit_rejected")))


func recent_authorizations() -> Array:
	return _recent_authorizations.duplicate(true)


func debug_snapshot() -> Dictionary:
	return {
		"ready": _identity != null and _audit != null,
		"active": _active,
		"active_step_index": _active_step_index,
		"rejected_count": _rejected_count,
		"recent_authorization_count": _recent_authorizations.size(),
		"owns_world_state": false,
		"owns_clock": false,
		"owns_save_format": false,
	}


func _reject(reason: String) -> Dictionary:
	if _audit != null:
		_audit.record_violation("authority:%s" % reason)
	return {"authorized": false, "recorded": false, "reason": reason, "step_index": _active_step_index}


func _is_pure_data(value: Variant) -> bool:
	if value is Object or value is Callable:
		return false
	if value is Dictionary:
		for key in (value as Dictionary).keys():
			if not _is_pure_data(key) or not _is_pure_data((value as Dictionary).get(key)):
				return false
	elif value is Array:
		for item in value as Array:
			if not _is_pure_data(item):
				return false
	return true
