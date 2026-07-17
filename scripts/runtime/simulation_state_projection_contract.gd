@tool
extends RefCounted
class_name SimulationStateProjectionContract

const SCHEMA_VERSION := 1
const REQUIRED_SECTIONS := [
	"authoritative_entities",
	"resources",
	"phase_state",
	"pending_commands",
	"deterministic_timers",
]
const FORBIDDEN_KEYS := [
	"node", "node_path", "object", "callable", "resource", "scene", "viewport",
	"ui_state", "presentation_state", "camera", "animation", "engine_frame",
	"engine_time", "frame_delta", "real_delta",
]


static func build(
	authoritative_entities: Variant,
	resources: Variant,
	phase_state: Variant,
	pending_commands: Variant,
	deterministic_timers: Variant,
	owner_revisions: Dictionary = {}
) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"authoritative_entities": _pure_copy(authoritative_entities),
		"resources": _pure_copy(resources),
		"phase_state": _pure_copy(phase_state),
		"pending_commands": _pure_copy(pending_commands),
		"deterministic_timers": _pure_copy(deterministic_timers),
		"owner_revisions": _pure_copy(owner_revisions),
	}


static func validate(projection: Dictionary) -> Dictionary:
	if int(projection.get("schema_version", -1)) != SCHEMA_VERSION:
		return {"valid": false, "reason": "simulation_projection_schema_unsupported"}
	for section in REQUIRED_SECTIONS:
		if not projection.has(section):
			return {"valid": false, "reason": "simulation_projection_section_missing:%s" % section}
	if _contains_runtime_object(projection):
		return {"valid": false, "reason": "simulation_projection_runtime_object_forbidden"}
	var forbidden_key := _first_forbidden_key(projection)
	if not forbidden_key.is_empty():
		return {"valid": false, "reason": "simulation_projection_forbidden_key:%s" % forbidden_key}
	return {"valid": true, "reason": "", "schema_version": SCHEMA_VERSION}


static func project_owner_sections(sections: Dictionary) -> Dictionary:
	return build(
		sections.get("authoritative_entities", {}),
		sections.get("resources", {}),
		sections.get("phase_state", {}),
		sections.get("pending_commands", []),
		sections.get("deterministic_timers", {}),
		sections.get("owner_revisions", {})
	)


static func _pure_copy(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key in (value as Dictionary).keys():
			result[key] = _pure_copy((value as Dictionary).get(key))
		return result
	if value is Array:
		var result: Array = []
		for item in value as Array:
			result.append(_pure_copy(item))
		return result
	return value


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


static func _first_forbidden_key(value: Variant) -> String:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant).to_lower()
			if key in FORBIDDEN_KEYS:
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
