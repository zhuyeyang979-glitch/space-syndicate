extends RefCounted
class_name CardInventoryCheckpointPurityInspectorV1

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const CHILD_IDS := ["commodity_card_inventory", "product_market", "district_purchase"]
const PUBLIC_SCHEMA_FIELD_NAMES := [
	"captured",
	"schema_version",
	"ruleset_id",
	"children",
	"modes",
	"commodity_card_inventory",
	"product_market",
	"district_purchase",
	"windows_by_player",
	"decision_sequence",
	"quote_checkpoint",
	"quote_checkpoint_supported",
	"business_cycle_count",
	"market_timer",
	"futures_position_sequence",
	"growth_multiplier",
	"district_purchase_runtime",
	"next_quote_sequence",
	"sessions",
]


static func inspect(checkpoint: Variant, source_capture_methods: Dictionary = {}) -> Dictionary:
	var state := {
		"leaf_count": 0,
		"v7_non_pure_leaves": [],
		"strict_non_closed_leaves": [],
		"v7_type_counts": {},
		"strict_type_counts": {},
		"containers": [],
		"source_capture_methods": source_capture_methods.duplicate(true),
	}
	_walk(checkpoint, "$", "card_inventory", state)
	var non_pure: Array = state.get("v7_non_pure_leaves", []) as Array
	var strict_non_closed: Array = state.get("strict_non_closed_leaves", []) as Array
	var paths: Array[String] = []
	for record_variant in non_pure:
		var record := record_variant as Dictionary
		paths.append(str(record.get("json_path", "$")))
	var first: Dictionary = (non_pure[0] as Dictionary).duplicate(true) if not non_pure.is_empty() else {}
	return {
		"schema_version": 1,
		"inspector_id": "card_inventory_checkpoint_purity_inspector_v1",
		"checkpoint_leaf_count": int(state.get("leaf_count", 0)),
		"non_pure_leaf_count": non_pure.size(),
		"strict_non_closed_leaf_count": strict_non_closed.size(),
		"payload_pure_data": _v7_owner_codec_allowed(checkpoint),
		"strict_closed_data": WIRE.is_closed_data(checkpoint),
		"first_non_pure_child_id": str(first.get("source_child_id", "")),
		"first_non_pure_path": str(first.get("json_path", "")),
		"first_non_pure_variant_type": str(first.get("variant_type", "")),
		"first_non_pure_reason": str(first.get("reason_code", "")),
		"non_pure_type_counts": (state.get("v7_type_counts", {}) as Dictionary).duplicate(true),
		"strict_non_closed_type_counts": (state.get("strict_type_counts", {}) as Dictionary).duplicate(true),
		"all_non_pure_paths": paths,
		"non_pure_leaves": non_pure.duplicate(true),
		"strict_non_closed_leaves": strict_non_closed.duplicate(true),
		"containers": (state.get("containers", []) as Array).duplicate(true),
	}


static func _walk(value: Variant, path: String, source_child_id: String, state: Dictionary) -> void:
	if value is Dictionary:
		var dictionary := value as Dictionary
		(state.get("containers", []) as Array).append({
			"json_path": path,
			"variant_type": "Dictionary",
			"length": dictionary.size(),
			"source_child_id": source_child_id,
		})
		for key_variant in dictionary.keys():
			var key_path := _dictionary_path(path, key_variant)
			if not (key_variant is String):
				_record_leaf(key_variant, key_path, source_child_id, state, true)
			var child_id := source_child_id
			if (path == "$.children" or path == "$") \
					and key_variant is String and str(key_variant) in CHILD_IDS:
				child_id = str(key_variant)
			_walk(dictionary.get(key_variant), key_path, child_id, state)
		return
	if value is Array:
		var array := value as Array
		(state.get("containers", []) as Array).append({
			"json_path": path,
			"variant_type": "Array",
			"length": array.size(),
			"source_child_id": source_child_id,
		})
		for index in range(array.size()):
			_walk(array[index], "%s[%d]" % [path, index], source_child_id, state)
		return
	_record_leaf(value, path, source_child_id, state, false)


static func _record_leaf(
	value: Variant,
	path: String,
	source_child_id: String,
	state: Dictionary,
	is_dictionary_key: bool
) -> void:
	state["leaf_count"] = int(state.get("leaf_count", 0)) + 1
	var strict_allowed := (value is String) if is_dictionary_key else WIRE.is_closed_data(value)
	var v7_allowed := (value is String or value is StringName) if is_dictionary_key else _v7_owner_codec_allowed(value)
	if strict_allowed and v7_allowed:
		return
	var variant_name := type_string(typeof(value))
	var record := {
		"json_path": path,
		"variant_type": variant_name,
		"closed_data_allowed": strict_allowed,
		"v7_owner_codec_allowed": v7_allowed,
		"safe_integer": WIRE.is_safe_integer(value) if value is int else false,
		"finite": is_finite(float(value)) if value is float else false,
		"dictionary_key_type_valid": not is_dictionary_key or value is String,
		"v7_dictionary_key_type_valid": not is_dictionary_key or value is String or value is StringName,
		"source_child_id": source_child_id,
		"source_capture_method": _source_capture_method(source_child_id, state),
		"reason_code": _v7_reason_for(value, is_dictionary_key),
		"strict_reason_code": _strict_reason_for(value, is_dictionary_key),
		"redacted_fingerprint": _structural_fingerprint(path, variant_name, _v7_reason_for(value, is_dictionary_key)),
	}
	if not v7_allowed:
		(state.get("v7_non_pure_leaves", []) as Array).append(record)
		var v7_counts := state.get("v7_type_counts", {}) as Dictionary
		v7_counts[variant_name] = int(v7_counts.get(variant_name, 0)) + 1
	if not strict_allowed:
		(state.get("strict_non_closed_leaves", []) as Array).append(record)
		var strict_counts := state.get("strict_type_counts", {}) as Dictionary
		strict_counts[variant_name] = int(strict_counts.get(variant_name, 0)) + 1


static func _strict_reason_for(value: Variant, is_dictionary_key: bool) -> String:
	if is_dictionary_key:
		return "dictionary_key_not_string"
	if value == null:
		return "raw_null_not_closed"
	if value is int:
		return "unsafe_integer" if not WIRE.is_safe_integer(value) else "none"
	if value is float:
		return "float_not_closed" if is_finite(float(value)) else "nonfinite_float"
	if value is StringName:
		return "string_name_not_closed"
	return "variant_type_not_closed"


static func _v7_reason_for(value: Variant, is_dictionary_key: bool) -> String:
	if is_dictionary_key:
		return "dictionary_key_not_owner_codec_compatible"
	if value is float and not is_finite(float(value)):
		return "nonfinite_float"
	return "variant_type_not_owner_codec_compatible"


static func _v7_owner_codec_allowed(value: Variant) -> bool:
	if value == null or value is String or value is bool or value is int \
			or value is Vector2 or value is Color:
		return true
	if value is float:
		return is_finite(float(value))
	if value is Array:
		for item in value as Array:
			if not _v7_owner_codec_allowed(item):
				return false
		return true
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if not (key_variant is String or key_variant is StringName) \
					or not _v7_owner_codec_allowed((value as Dictionary).get(key_variant)):
				return false
		return true
	return false


static func _source_capture_method(source_child_id: String, state: Dictionary) -> String:
	var methods := state.get("source_capture_methods", {}) as Dictionary
	return str(methods.get(source_child_id, "capture_runtime_checkpoint"))


static func _dictionary_path(parent: String, key_variant: Variant) -> String:
	if key_variant is String:
		var key := str(key_variant)
		if _is_schema_field_name(key):
			return "%s.%s" % [parent, key]
		return "%s.<redacted:%s>" % [parent, _redacted_key_fingerprint(key)]
	return "%s.<non_string_key:%s>" % [parent, type_string(typeof(key_variant))]


static func _is_schema_field_name(value: String) -> bool:
	return value in PUBLIC_SCHEMA_FIELD_NAMES


static func _redacted_key_fingerprint(value: String) -> String:
	return ("card_inventory_path_key|%d|%s" % [value.length(), value.sha256_text()]).sha256_text().substr(0, 12)


static func _structural_fingerprint(path: String, variant_name: String, reason_code: String) -> String:
	return JSON.stringify({
		"json_path": path,
		"variant_type": variant_name,
		"reason_code": reason_code,
	}).sha256_text()
