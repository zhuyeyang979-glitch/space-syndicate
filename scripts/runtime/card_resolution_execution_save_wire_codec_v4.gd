extends RefCounted
class_name CardResolutionExecutionSaveWireCodecV4

const CLOSED_SCALAR_CODEC := preload("res://scripts/runtime/closed_save_scalar_codec_v1.gd")
const SEMANTIC_WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")

const SAVE_SCHEMA_VERSION := 4
const EXECUTION_WIRE_VERSION := 1
const TRANSITION_STATE_WIRE_VERSION := 2
const FINGERPRINT_FIELD := "execution_wire_fingerprint"
const TAG_KEY := "codec"
const INT64_CODEC_ID := "execution_int64_decimal_v1"
const NULL_CODEC_ID := "NullV1"
const INT64_FIELDS := [TAG_KEY, "value"]
const NULL_FIELDS := [TAG_KEY]
const RUNTIME_ROOT_FIELDS := [
	"schema_version",
	"execution_wire_version",
	"ruleset_id",
	"transaction_sequence",
	"completed_resolution_ids",
	"inflight_resolution_ids",
	"inflight_execution_transactions",
	"pending_settlements",
	"transition_controller",
]
const WIRE_ROOT_FIELDS := [
	"schema_version",
	"execution_wire_version",
	"ruleset_id",
	"transaction_sequence",
	"completed_resolution_ids",
	"inflight_resolution_ids",
	"inflight_execution_transactions",
	"pending_settlements",
	"transition_controller",
	FINGERPRINT_FIELD,
]


static func encode_save_state(runtime_state: Dictionary) -> Dictionary:
	if not _has_exact_keys(runtime_state, RUNTIME_ROOT_FIELDS):
		return _failure("execution_save_v4_runtime_shape_invalid", "$")
	var encoded := _encode_value(runtime_state, "$")
	if not bool(encoded.get("ok", false)) or not (encoded.get("value") is Dictionary):
		return encoded
	var wire_state := (encoded.get("value") as Dictionary).duplicate(true)
	if wire_state.has(FINGERPRINT_FIELD):
		return _failure("execution_save_v4_fingerprint_collision", "$")
	wire_state[FINGERPRINT_FIELD] = SEMANTIC_WIRE.fingerprint(wire_state)
	if not SEMANTIC_WIRE.is_fingerprint(wire_state.get(FINGERPRINT_FIELD)):
		return _failure("execution_save_v4_fingerprint_failed", "$")
	if not SEMANTIC_WIRE.is_closed_data(wire_state):
		return _failure("execution_save_v4_wire_not_closed_data", "$")
	return {"ok": true, "value": wire_state}


static func decode_save_state(wire_state: Dictionary) -> Dictionary:
	if not _has_exact_keys(wire_state, WIRE_ROOT_FIELDS):
		return _failure("execution_save_v4_wire_shape_invalid", "$")
	if not SEMANTIC_WIRE.is_closed_data(wire_state):
		return _failure("execution_save_v4_wire_not_closed_data", "$")
	var authored_fingerprint: Variant = wire_state.get(FINGERPRINT_FIELD)
	if not SEMANTIC_WIRE.is_fingerprint(authored_fingerprint) \
			or str(authored_fingerprint) != SEMANTIC_WIRE.fingerprint(wire_state, FINGERPRINT_FIELD):
		return _failure("execution_save_v4_fingerprint_invalid", "$")
	var encoded_runtime := wire_state.duplicate(true)
	encoded_runtime.erase(FINGERPRINT_FIELD)
	var decoded := _decode_value(encoded_runtime, "$")
	if not bool(decoded.get("ok", false)) or not (decoded.get("value") is Dictionary):
		return decoded
	var runtime_state := (decoded.get("value") as Dictionary).duplicate(true)
	if not _has_exact_keys(runtime_state, RUNTIME_ROOT_FIELDS):
		return _failure("execution_save_v4_runtime_shape_invalid", "$")
	return {
		"ok": true,
		"value": runtime_state,
		"execution_wire_fingerprint": str(authored_fingerprint),
	}


static func wire_fingerprint(wire_state: Dictionary) -> String:
	return SEMANTIC_WIRE.fingerprint(wire_state, FINGERPRINT_FIELD) \
			if wire_state.has(FINGERPRINT_FIELD) else ""


static func _encode_value(value: Variant, path: String) -> Dictionary:
	if value is String or value is bool:
		return {"ok": true, "value": value}
	if value is int:
		return {
			"ok": true,
			"value": {
				TAG_KEY: INT64_CODEC_ID,
				"value": str(value),
			},
		}
	if value is float:
		var encoded_float := CLOSED_SCALAR_CODEC.encode_f64(value)
		return encoded_float if bool(encoded_float.get("ok", false)) else _failure(
			str(encoded_float.get("reason_code", "execution_save_v4_float_encode_failed")),
			path
		)
	if value == null:
		return {"ok": true, "value": {TAG_KEY: NULL_CODEC_ID}}
	if value is Array:
		var encoded_array: Array = []
		var source_array := value as Array
		for index in range(source_array.size()):
			var encoded_item := _encode_value(source_array[index], "%s[%d]" % [path, index])
			if not bool(encoded_item.get("ok", false)):
				return encoded_item
			encoded_array.append(encoded_item.get("value"))
		return {"ok": true, "value": encoded_array}
	if value is Dictionary:
		var source := value as Dictionary
		if source.has(TAG_KEY) or source.has(CLOSED_SCALAR_CODEC.INT64_CODEC_KEY):
			return _failure("execution_save_v4_reserved_tag_collision", path)
		var encoded_dictionary: Dictionary = {}
		# Preserve authored insertion order. Entry fingerprints in the queue/execution
		# contract are defined over JSON.stringify(active_entry).
		for key_variant: Variant in source.keys():
			if not (key_variant is String):
				return _failure("execution_save_v4_dictionary_key_not_string", path)
			var key := str(key_variant)
			var encoded_item := _encode_value(source.get(key), _child_path(path, key))
			if not bool(encoded_item.get("ok", false)):
				return encoded_item
			encoded_dictionary[key] = encoded_item.get("value")
		return {"ok": true, "value": encoded_dictionary}
	if value is StringName:
		return _failure("execution_save_v4_string_name_not_authorized", path)
	if value is Vector2:
		return _failure("execution_save_v4_vector2_not_authorized", path)
	if value is Color:
		return _failure("execution_save_v4_color_not_authorized", path)
	return _failure("execution_save_v4_variant_type_not_authorized", path)


static func _decode_value(value: Variant, path: String) -> Dictionary:
	if value is String or value is bool:
		return {"ok": true, "value": value}
	if value is int:
		return _failure("execution_save_v4_raw_integer_rejected", path)
	if value is float:
		return _failure("execution_save_v4_raw_float_rejected", path)
	if value is Array:
		var decoded_array: Array = []
		var source_array := value as Array
		for index in range(source_array.size()):
			var decoded_item := _decode_value(source_array[index], "%s[%d]" % [path, index])
			if not bool(decoded_item.get("ok", false)):
				return decoded_item
			decoded_array.append(decoded_item.get("value"))
		return {"ok": true, "value": decoded_array}
	if value is Dictionary:
		var source := value as Dictionary
		if source.has(CLOSED_SCALAR_CODEC.INT64_CODEC_KEY):
			return _failure("execution_save_v4_unknown_codec_tag", path)
		if source.has(TAG_KEY):
			var codec_variant: Variant = source.get(TAG_KEY)
			if not (codec_variant is String):
				return _failure("execution_save_v4_unknown_codec_tag", path)
			var codec_id := str(codec_variant)
			if codec_id == CLOSED_SCALAR_CODEC.F64_CODEC_ID:
				var decoded_float := CLOSED_SCALAR_CODEC.decode_f64(source)
				return decoded_float if bool(decoded_float.get("ok", false)) else _failure(
					str(decoded_float.get("reason_code", "execution_save_v4_f64_tag_invalid")),
					path
				)
			if codec_id == INT64_CODEC_ID:
				return _decode_int64(source, path)
			if codec_id == NULL_CODEC_ID:
				return {"ok": true, "value": null} \
						if _has_exact_keys(source, NULL_FIELDS) else _failure(
							"execution_save_v4_null_tag_invalid", path
						)
			return _failure("execution_save_v4_unknown_codec_tag", path)
		var decoded_dictionary: Dictionary = {}
		for key_variant: Variant in source.keys():
			if not (key_variant is String):
				return _failure("execution_save_v4_dictionary_key_not_string", path)
			var key := str(key_variant)
			var decoded_item := _decode_value(source.get(key), _child_path(path, key))
			if not bool(decoded_item.get("ok", false)):
				return decoded_item
			decoded_dictionary[key] = decoded_item.get("value")
		return {"ok": true, "value": decoded_dictionary}
	return _failure("execution_save_v4_wire_variant_forbidden", path)


static func _decode_int64(tag: Dictionary, path: String) -> Dictionary:
	if not _has_exact_keys(tag, INT64_FIELDS) or not (tag.get("value") is String):
		return _failure("execution_save_v4_int64_tag_invalid", path)
	var shared_tag := {
		CLOSED_SCALAR_CODEC.INT64_CODEC_KEY: CLOSED_SCALAR_CODEC.INT64_CODEC_ID,
		"value": str(tag.get("value", "")),
	}
	var decoded := CLOSED_SCALAR_CODEC.decode_tree(shared_tag)
	if not bool(decoded.get("ok", false)) or not (decoded.get("value") is int):
		return _failure(str(decoded.get("reason_code", "execution_save_v4_int64_tag_invalid")), path)
	var decoded_value := int(decoded.get("value"))
	if _encode_value(decoded_value, path).get("value") != tag:
		return _failure("execution_save_v4_int64_tag_invalid", path)
	return {"ok": true, "value": decoded_value}


static func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key_variant: Variant in expected:
		if not value.has(str(key_variant)):
			return false
	return true


static func _child_path(parent: String, key: String) -> String:
	return "%s.<key:%s>" % [parent, ("execution_wire_key|%d|%s" % [
		key.length(),
		key.sha256_text().to_lower(),
	]).sha256_text().substr(0, 12)]


static func _failure(reason_code: String, path: String) -> Dictionary:
	return {
		"ok": false,
		"reason_code": reason_code,
		"redacted_path": path,
	}
