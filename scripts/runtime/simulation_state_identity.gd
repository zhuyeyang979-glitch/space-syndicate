@tool
extends Node
class_name SimulationStateIdentity

const SCHEMA_VERSION := 1

var _identity_count := 0
var _rejected_identity_count := 0
var _last_identity: Dictionary = {}


func identify(simulation_projection: Dictionary, command_trace: Array = []) -> Dictionary:
	if not _is_pure_data(simulation_projection) or not _is_pure_data(command_trace):
		_rejected_identity_count += 1
		_last_identity = {
			"valid": false,
			"reason": "simulation_state_contains_runtime_object",
			"schema_version": SCHEMA_VERSION,
			"fingerprint": "",
		}
		return _last_identity.duplicate(true)
	var canonical_state: Variant = _canonicalize(simulation_projection)
	var canonical_commands: Variant = _canonicalize(command_trace)
	var canonical_payload := {
		"schema_version": SCHEMA_VERSION,
		"simulation_state": canonical_state,
		"command_trace": canonical_commands,
	}
	var canonical_json := JSON.stringify(canonical_payload)
	_identity_count += 1
	_last_identity = {
		"valid": true,
		"reason": "",
		"schema_version": SCHEMA_VERSION,
		"fingerprint": canonical_json.sha256_text(),
		"command_sequence_fingerprint": JSON.stringify(canonical_commands).sha256_text(),
		"canonical_byte_count": canonical_json.to_utf8_buffer().size(),
	}
	return _last_identity.duplicate(true)


func stable_serialize(pure_data: Variant) -> Dictionary:
	if not _is_pure_data(pure_data):
		return {"valid": false, "reason": "simulation_state_contains_runtime_object", "serialized": "", "fingerprint": ""}
	var serialized := JSON.stringify(_canonicalize(pure_data))
	return {
		"valid": true,
		"reason": "",
		"serialized": serialized,
		"fingerprint": serialized.sha256_text(),
	}


func debug_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"identity_method": "sorted_dictionary_keys_ordered_arrays_sha256",
		"identity_count": _identity_count,
		"rejected_identity_count": _rejected_identity_count,
		"accepts_runtime_objects": false,
		"owns_world_state": false,
		"presentation_source": false,
		"last_identity": _last_identity.duplicate(true),
	}


func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var dictionary := value as Dictionary
		var keys: Array = dictionary.keys()
		keys.sort_custom(func(left: Variant, right: Variant) -> bool: return _canonical_key(left) < _canonical_key(right))
		var result := {}
		for key in keys:
			result[_canonical_key(key)] = _canonicalize(dictionary.get(key))
		return result
	if value is Array:
		var result: Array = []
		for item in value as Array:
			result.append(_canonicalize(item))
		return result
	if value is StringName:
		return {"@type": "StringName", "value": String(value)}
	if value is Vector2:
		return {"@type": "Vector2", "x": value.x, "y": value.y}
	if value is Vector2i:
		return {"@type": "Vector2i", "x": value.x, "y": value.y}
	if value is Vector3:
		return {"@type": "Vector3", "x": value.x, "y": value.y, "z": value.z}
	if value is Vector3i:
		return {"@type": "Vector3i", "x": value.x, "y": value.y, "z": value.z}
	if value is Rect2:
		return {"@type": "Rect2", "position": _canonicalize(value.position), "size": _canonicalize(value.size)}
	if value is Rect2i:
		return {"@type": "Rect2i", "position": _canonicalize(value.position), "size": _canonicalize(value.size)}
	if value is Color:
		return {"@type": "Color", "r": value.r, "g": value.g, "b": value.b, "a": value.a}
	return value


func _is_pure_data(value: Variant) -> bool:
	if value is Callable or value is Object:
		return false
	if value is Dictionary:
		for key in (value as Dictionary).keys():
			if not _is_pure_data(key) or not _is_pure_data((value as Dictionary).get(key)):
				return false
		return true
	elif value is Array:
		for item in value as Array:
			if not _is_pure_data(item):
				return false
		return true
	return typeof(value) in [
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME,
		TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I,
		TYPE_RECT2, TYPE_RECT2I, TYPE_COLOR,
	]


func _canonical_key(value: Variant) -> String:
	match typeof(value):
		TYPE_STRING:
			return "string:%s" % String(value)
		TYPE_STRING_NAME:
			return "string_name:%s" % String(value)
		TYPE_INT:
			return "int:%d" % int(value)
		TYPE_FLOAT:
			return "float:%s" % String.num(float(value), 17)
		TYPE_BOOL:
			return "bool:%s" % str(value)
		TYPE_NIL:
			return "nil"
	return "variant:%s" % JSON.stringify(_canonicalize(value))
