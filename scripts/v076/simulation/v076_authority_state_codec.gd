@tool
extends RefCounted
class_name V076AuthorityStateCodec

## Closed-data codec for v0.7.6 gameplay authority.
## Authority bytes may contain only nil, bool, int, String, Array, and
## String-keyed Dictionary values. Presentation data is deliberately excluded.

const SCHEMA_VERSION := 1
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const FORBIDDEN_PRESENTATION_KEYS := {
	"animation": true,
	"camera": true,
	"engine_frame": true,
	"frame_delta": true,
	"presentation": true,
	"render": true,
	"screen": true,
	"ui": true,
	"visual": true,
}


static func validate(value: Variant, path: String = "$") -> Dictionary:
	var failure := _find_failure(value, path)
	return {
		"valid": failure.is_empty(),
		"reason": str(failure.get("reason", "")),
		"path": str(failure.get("path", "")),
		"type": str(failure.get("type", "")),
	}


static func canonicalize(value: Variant) -> Variant:
	var validation := validate(value)
	if not bool(validation.get("valid", false)):
		return null
	return _canonicalize_valid(value)


static func serialize(value: Variant) -> Dictionary:
	var validation := validate(value)
	if not bool(validation.get("valid", false)):
		return {
			"valid": false,
			"reason": str(validation.get("reason", "")),
			"path": str(validation.get("path", "")),
			"serialized": "",
			"sha256": "",
		}
	var serialized := JSON.stringify(_canonicalize_valid(value))
	return {
		"valid": true,
		"reason": "",
		"path": "",
		"serialized": serialized,
		"sha256": serialized.sha256_text(),
	}


static func fingerprint(value: Variant) -> String:
	var result := serialize(value)
	return str(result.get("sha256", "")) if bool(result.get("valid", false)) else ""


static func deserialize(serialized: String, expected_sha256: String) -> Dictionary:
	if expected_sha256.is_empty() or serialized.sha256_text() != expected_sha256:
		return {"valid": false, "reason": "serialized_authority_hash_mismatch", "path": "$", "value": {}}
	var parsed: Variant = JSON.parse_string(serialized)
	if parsed == null and serialized != "null":
		return {"valid": false, "reason": "serialized_authority_json_invalid", "path": "$", "value": {}}
	var restored := _restore_json_integers(parsed, "$")
	if not bool(restored.get("valid", false)):
		return restored
	var value: Variant = restored.get("value")
	var validation := validate(value)
	if not bool(validation.get("valid", false)):
		return {"valid": false, "reason": str(validation.get("reason", "authority_invalid")), "path": str(validation.get("path", "$")), "value": {}}
	var canonical := serialize(value)
	if not bool(canonical.get("valid", false)) or str(canonical.get("serialized", "")) != serialized:
		return {"valid": false, "reason": "serialized_authority_not_canonical", "path": "$", "value": {}}
	return {"valid": true, "reason": "", "path": "", "value": value}


static func count_float_fields(value: Variant) -> int:
	return _count_type(value, TYPE_FLOAT)


static func _find_failure(value: Variant, path: String) -> Dictionary:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_STRING:
			return {}
		TYPE_INT:
			var integer := int(value)
			if integer < -MAX_SAFE_INTEGER or integer > MAX_SAFE_INTEGER:
				return {"reason": "authority_integer_outside_canonical_json_range", "path": path, "type": "int"}
			return {}
		TYPE_ARRAY:
			var array := value as Array
			for index in range(array.size()):
				var failure := _find_failure(array[index], "%s[%d]" % [path, index])
				if not failure.is_empty():
					return failure
			return {}
		TYPE_DICTIONARY:
			var dictionary := value as Dictionary
			for key_variant in dictionary.keys():
				if typeof(key_variant) != TYPE_STRING:
					return {
						"reason": "authority_dictionary_key_not_string",
						"path": path,
						"type": type_string(typeof(key_variant)),
					}
				var key := str(key_variant)
				if _presentation_key_forbidden(key):
					return {
						"reason": "presentation_field_forbidden_in_authority",
						"path": _child_path(path, key),
						"type": "String",
					}
				var failure := _find_failure(dictionary[key_variant], _child_path(path, key))
				if not failure.is_empty():
					return failure
			return {}
		_:
			return {
				"reason": "authority_type_forbidden",
				"path": path,
				"type": type_string(typeof(value)),
			}


static func _canonicalize_valid(value: Variant) -> Variant:
	if value is Dictionary:
		var source := value as Dictionary
		var keys: Array = source.keys()
		keys.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
		var canonical := {}
		for key_variant in keys:
			canonical[str(key_variant)] = _canonicalize_valid(source[key_variant])
		return canonical
	if value is Array:
		var canonical_array: Array = []
		for item in value as Array:
			canonical_array.append(_canonicalize_valid(item))
		return canonical_array
	return value


static func _count_type(value: Variant, target_type: int) -> int:
	var count := 1 if typeof(value) == target_type else 0
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			count += _count_type(key_variant, target_type)
			count += _count_type((value as Dictionary)[key_variant], target_type)
	elif value is Array:
		for item in value as Array:
			count += _count_type(item, target_type)
	return count


static func _presentation_key_forbidden(key: String) -> bool:
	var expanded := ""
	for index in range(key.length()):
		var character := key.substr(index, 1)
		var is_upper := character >= "A" and character <= "Z"
		var previous_is_lower := index > 0 and key.substr(index - 1, 1) >= "a" and key.substr(index - 1, 1) <= "z"
		var next_is_lower := index + 1 < key.length() and key.substr(index + 1, 1) >= "a" and key.substr(index + 1, 1) <= "z"
		if is_upper and index > 0 and (previous_is_lower or next_is_lower):
			expanded += "_"
		expanded += character.to_lower()
	var normalized := expanded
	for separator in [".", "-", "/", "[", "]", " "]:
		normalized = normalized.replace(separator, "_")
	for token in normalized.split("_", false):
		if FORBIDDEN_PRESENTATION_KEYS.has(token):
			return true
	return false


static func _child_path(parent_path: String, key: String) -> String:
	return "%s[%s]" % [parent_path, JSON.stringify(key)]


static func _restore_json_integers(value: Variant, path: String) -> Dictionary:
	match typeof(value):
		TYPE_FLOAT:
			var numeric := float(value)
			if not is_finite(numeric) or numeric != floor(numeric) or abs(numeric) > float(MAX_SAFE_INTEGER):
				return {"valid": false, "reason": "serialized_authority_number_not_safe_integer", "path": path, "value": {}}
			return {"valid": true, "reason": "", "path": "", "value": int(numeric)}
		TYPE_ARRAY:
			var result_array: Array = []
			var source_array := value as Array
			for index in range(source_array.size()):
				var restored := _restore_json_integers(source_array[index], "%s[%d]" % [path, index])
				if not bool(restored.get("valid", false)):
					return restored
				result_array.append(restored.get("value"))
			return {"valid": true, "reason": "", "path": "", "value": result_array}
		TYPE_DICTIONARY:
			var result_dictionary := {}
			for key_variant in (value as Dictionary).keys():
				if typeof(key_variant) != TYPE_STRING:
					return {"valid": false, "reason": "serialized_authority_key_not_string", "path": path, "value": {}}
				var key := str(key_variant)
				var restored := _restore_json_integers((value as Dictionary)[key_variant], _child_path(path, key))
				if not bool(restored.get("valid", false)):
					return restored
				result_dictionary[key] = restored.get("value")
			return {"valid": true, "reason": "", "path": "", "value": result_dictionary}
		_:
			return {"valid": true, "reason": "", "path": "", "value": value}
