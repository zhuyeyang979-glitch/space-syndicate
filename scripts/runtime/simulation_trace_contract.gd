@tool
extends RefCounted
class_name SimulationTraceContract

const SCHEMA_VERSION := 1
const COMMAND_FIELDS := [
	"schema_version", "command_type", "command_id", "producer_revision",
	"order_index", "payload_fingerprint", "envelope_fingerprint",
]
const RESULT_FIELDS := ["command_id", "accepted", "reason", "result_fingerprint"]
const MUTATION_FIELDS := ["domain", "mutation_kind", "target_key", "outcome", "summary_fingerprint"]
const FORBIDDEN_KEYS := [
	"engine_frame", "engine_time", "frame_delta", "real_delta", "world_delta",
	"ui_state", "presentation_state", "node", "node_path", "object",
	"callable", "resource", "scene", "viewport",
]


static func build(
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
	return {
		"schema_version": SCHEMA_VERSION,
		"simulation_step_index": step_index,
		"command_sequence": _allowlisted_rows(command_sequence, COMMAND_FIELDS),
		"command_results": _allowlisted_rows(command_results, RESULT_FIELDS),
		"phase_transition": _string_array(phase_transition),
		"state_fingerprint_before": state_fingerprint_before,
		"state_fingerprint_after": state_fingerprint_after,
		"deterministic_mutation_summary": _allowlisted_rows(mutation_summary, MUTATION_FIELDS),
		"completed": completed,
		"stopped_reason": stopped_reason,
	}


static func validate(trace: Dictionary) -> Dictionary:
	if int(trace.get("schema_version", -1)) != SCHEMA_VERSION:
		return _invalid("simulation_trace_schema_unsupported")
	if int(trace.get("simulation_step_index", 0)) <= 0:
		return _invalid("simulation_trace_step_invalid")
	for fingerprint_key in ["state_fingerprint_before", "state_fingerprint_after"]:
		if not _is_sha256(str(trace.get(fingerprint_key, ""))):
			return _invalid("simulation_trace_state_fingerprint_invalid")
	for array_key in ["command_sequence", "command_results", "phase_transition", "deterministic_mutation_summary"]:
		if not (trace.get(array_key, null) is Array):
			return _invalid("simulation_trace_array_invalid")
	if (trace.get("command_sequence", []) as Array).size() != (trace.get("command_results", []) as Array).size():
		return _invalid("simulation_trace_command_result_count_mismatch")
	if _contains_runtime_object(trace):
		return _invalid("simulation_trace_runtime_object_forbidden")
	var forbidden_key := _first_forbidden_key(trace)
	if not forbidden_key.is_empty():
		return _invalid("simulation_trace_forbidden_key:%s" % forbidden_key)
	return {"valid": true, "reason": ""}


static func _allowlisted_rows(rows: Array, fields: Array) -> Array:
	var result: Array = []
	for row_variant in rows:
		if not (row_variant is Dictionary):
			continue
		var row := row_variant as Dictionary
		var projected := {}
		for field_variant in fields:
			var field := str(field_variant)
			if row.has(field):
				projected[field] = row.get(field)
		result.append(projected)
	return result


static func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result


static func _contains_runtime_object(value: Variant) -> bool:
	if value is Object or value is Callable:
		return true
	if value is Dictionary:
		for key in (value as Dictionary).keys():
			if _contains_runtime_object(key) or _contains_runtime_object((value as Dictionary).get(key)):
				return true
	elif value is Array:
		for item in value as Array:
			if _contains_runtime_object(item):
				return true
	return false


static func _is_pure_data(value: Variant) -> bool:
	return not _contains_runtime_object(value)


static func _first_forbidden_key(value: Variant) -> String:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant)
			if key.to_lower() in FORBIDDEN_KEYS:
				return key
			var nested := _first_forbidden_key((value as Dictionary).get(key_variant))
			if not nested.is_empty():
				return nested
	elif value is Array:
		for item in value as Array:
			var nested := _first_forbidden_key(item)
			if not nested.is_empty():
				return nested
	return ""


static func _is_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for index in range(value.length()):
		var character := value.substr(index, 1)
		if not character in "0123456789abcdef":
			return false
	return true


static func _invalid(reason: String) -> Dictionary:
	return {"valid": false, "reason": reason}
