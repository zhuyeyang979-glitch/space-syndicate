extends RefCounted
class_name RemainingOwnerClosedDataInspectorV1

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const PUBLIC_FIELD_NAMES := [
	"schema_version",
	"state_version",
	"ruleset_id",
	"monster_timer",
	"special_monster_timer",
]


static func inspect(payload: Variant) -> Dictionary:
	var state := {
		"leaf_count": 0,
		"non_closed_leaves": [],
		"type_counts": {},
	}
	_walk(payload, "$", state)
	var leaves: Array = state.get("non_closed_leaves", []) as Array
	leaves.sort_custom(func(left_variant: Variant, right_variant: Variant) -> bool:
		var left := left_variant as Dictionary
		var right := right_variant as Dictionary
		return str(left.get("json_path", "")) < str(right.get("json_path", ""))
	)
	var paths: Array[String] = []
	for record_variant in leaves:
		paths.append(str((record_variant as Dictionary).get("json_path", "$")))
	var first: Dictionary = (leaves[0] as Dictionary).duplicate(true) if not leaves.is_empty() else {}
	return {
		"schema_version": 1,
		"inspector_id": "remaining_owner_closed_data_inspector_v1",
		"leaf_count": int(state.get("leaf_count", 0)),
		"closed_data": WIRE.is_closed_data(payload),
		"non_closed_leaf_count": leaves.size(),
		"non_closed_type_counts": (state.get("type_counts", {}) as Dictionary).duplicate(true),
		"first_non_closed_path": str(first.get("json_path", "")),
		"first_non_closed_type": str(first.get("variant_type", "")),
		"first_non_closed_reason": str(first.get("reason_code", "")),
		"all_non_closed_paths": paths,
		"non_closed_leaves": leaves.duplicate(true),
	}


static func _walk(value: Variant, path: String, state: Dictionary) -> void:
	if value is Dictionary:
		var dictionary := value as Dictionary
		var keys: Array = dictionary.keys()
		keys.sort_custom(func(left: Variant, right: Variant) -> bool:
			return str(left) < str(right)
		)
		for key_variant in keys:
			var child_path := _dictionary_path(path, key_variant)
			if not (key_variant is String):
				_record(key_variant, child_path, state, "dictionary_key_not_string")
			_walk(dictionary.get(key_variant), child_path, state)
		return
	if value is Array:
		var array := value as Array
		for index in range(array.size()):
			_walk(array[index], "%s[%d]" % [path, index], state)
		return
	state["leaf_count"] = int(state.get("leaf_count", 0)) + 1
	if not WIRE.is_closed_data(value):
		_record(value, path, state, _reason_for(value, path))


static func _record(value: Variant, path: String, state: Dictionary, reason_code: String) -> void:
	var variant_name := type_string(typeof(value))
	(state.get("non_closed_leaves", []) as Array).append({
		"json_path": path,
		"variant_type": variant_name,
		"reason_code": reason_code,
		"redacted_fingerprint": JSON.stringify({
			"json_path": path,
			"variant_type": variant_name,
			"reason_code": reason_code,
		}).sha256_text().to_lower(),
	})
	var counts := state.get("type_counts", {}) as Dictionary
	counts[variant_name] = int(counts.get(variant_name, 0)) + 1


static func _reason_for(value: Variant, path: String) -> String:
	if value == null:
		return "raw_null_not_closed_data"
	if value is float:
		if not is_finite(float(value)):
			return "nonfinite_float_not_closed_data"
		if path.ends_with(".monster_timer") or path.ends_with(".special_monster_timer"):
			return "raw_float_timer_not_closed_data"
		return "raw_float_not_closed_data"
	if value is int and not WIRE.is_safe_integer(value):
		return "unsafe_integer_not_closed_data"
	if value is StringName:
		return "string_name_not_closed_data"
	return "variant_type_not_closed_data"


static func _dictionary_path(parent: String, key_variant: Variant) -> String:
	if not (key_variant is String):
		return "%s.<non_string_key:%s>" % [parent, type_string(typeof(key_variant))]
	var key := key_variant as String
	if key in PUBLIC_FIELD_NAMES:
		return "%s.%s" % [parent, key]
	return "%s.<redacted:%s>" % [parent, ("remaining_owner_key|%d|%s" % [
		key.length(),
		key.sha256_text().to_lower(),
	]).sha256_text().substr(0, 12)]
