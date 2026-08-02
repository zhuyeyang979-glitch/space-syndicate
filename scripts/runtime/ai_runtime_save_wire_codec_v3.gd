extends RefCounted
class_name AiRuntimeSaveWireCodecV3

const CLOSED_SCALAR_CODEC := preload("res://scripts/runtime/closed_save_scalar_codec_v1.gd")
const SEMANTIC_WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")

const SAVE_SCHEMA_VERSION := 3
const RUNTIME_CHECKPOINT_SCHEMA_VERSION := 2
const NEW_SESSION_CHECKPOINT_SCHEMA_VERSION := 3
const TAG_KEY := "codec"
const INT64_CODEC_ID := "ai_int64_decimal_v1"
const INT64_FIELDS := [TAG_KEY, "value"]

const SAVE_FIELDS := [
	"schema_version",
	"ruleset_id",
	"policy_profile_id",
	"policy_fingerprint",
	"request_sequence",
	"ai_card_decision_timer",
	"ai_auction_reaction_timer",
	"ai_intel_decision_timer",
	"ai_card_decision_enabled",
	"player_states",
]
const RUNTIME_CHECKPOINT_FIELDS := [
	"schema_version",
	"save_state",
	"last_receipts",
	"card_target_pre_submit_rejection_count",
	"tick_timing_count",
	"tick_timing_total_usec",
	"tick_timing_max_usec",
	"actor_state_tick_cache",
	"actor_state_tick_cache_active",
	"actor_state_tick_cache_hit_count",
	"actor_state_tick_cache_miss_count",
]
const NEW_SESSION_CHECKPOINT_FIELDS := [
	"schema_version",
	"request_sequence",
	"ai_card_decision_timer",
	"ai_auction_reaction_timer",
	"ai_intel_decision_timer",
	"ai_card_decision_enabled",
	"last_receipts",
]


static func encode_save_state(runtime_state: Dictionary) -> Dictionary:
	if not _has_exact_keys(runtime_state, SAVE_FIELDS) \
			or not (runtime_state.get("schema_version") is int) \
			or int(runtime_state.get("schema_version", 0)) != SAVE_SCHEMA_VERSION:
		return _failure("ai_save_v3_runtime_shape_invalid")
	return _encode_tree(runtime_state, "ai_save_v3_wire_encode_failed")


static func decode_save_state(wire_state: Dictionary) -> Dictionary:
	var decoded := _decode_tree(wire_state, SAVE_FIELDS, "ai_save_v3_wire_invalid")
	if not bool(decoded.get("ok", false)):
		return decoded
	var runtime_state := decoded.get("value", {}) as Dictionary
	if not (runtime_state.get("schema_version") is int) \
			or int(runtime_state.get("schema_version", 0)) != SAVE_SCHEMA_VERSION:
		return _failure("ai_save_v3_runtime_shape_invalid")
	return decoded


static func encode_runtime_checkpoint(runtime_checkpoint: Dictionary) -> Dictionary:
	if not _has_exact_keys(runtime_checkpoint, RUNTIME_CHECKPOINT_FIELDS) \
			or not (runtime_checkpoint.get("schema_version") is int) \
			or int(runtime_checkpoint.get("schema_version", 0)) != RUNTIME_CHECKPOINT_SCHEMA_VERSION \
			or not (runtime_checkpoint.get("save_state") is Dictionary) \
			or not _has_exact_keys(runtime_checkpoint.get("save_state", {}) as Dictionary, SAVE_FIELDS) \
			or int((runtime_checkpoint.get("save_state", {}) as Dictionary).get("schema_version", 0)) != SAVE_SCHEMA_VERSION:
		return _failure("ai_runtime_checkpoint_v2_shape_invalid")
	return _encode_tree(runtime_checkpoint, "ai_runtime_checkpoint_v2_wire_encode_failed")


static func decode_runtime_checkpoint(wire_checkpoint: Dictionary) -> Dictionary:
	var decoded := _decode_tree(
		wire_checkpoint,
		RUNTIME_CHECKPOINT_FIELDS,
		"ai_runtime_checkpoint_v2_wire_invalid"
	)
	if not bool(decoded.get("ok", false)):
		return decoded
	var runtime_checkpoint := decoded.get("value", {}) as Dictionary
	var save_state: Variant = runtime_checkpoint.get("save_state")
	if not (runtime_checkpoint.get("schema_version") is int) \
			or int(runtime_checkpoint.get("schema_version", 0)) != RUNTIME_CHECKPOINT_SCHEMA_VERSION \
			or not (save_state is Dictionary) \
			or not _has_exact_keys(save_state as Dictionary, SAVE_FIELDS) \
			or int((save_state as Dictionary).get("schema_version", 0)) != SAVE_SCHEMA_VERSION:
		return _failure("ai_runtime_checkpoint_v2_shape_invalid")
	return decoded


static func encode_new_session_checkpoint(runtime_checkpoint: Dictionary) -> Dictionary:
	if not _has_exact_keys(runtime_checkpoint, NEW_SESSION_CHECKPOINT_FIELDS) \
			or not (runtime_checkpoint.get("schema_version") is int) \
			or int(runtime_checkpoint.get("schema_version", 0)) != NEW_SESSION_CHECKPOINT_SCHEMA_VERSION:
		return _failure("ai_new_session_checkpoint_v3_shape_invalid")
	return _encode_tree(runtime_checkpoint, "ai_new_session_checkpoint_v3_wire_encode_failed")


static func decode_new_session_checkpoint(wire_checkpoint: Dictionary) -> Dictionary:
	var decoded := _decode_tree(
		wire_checkpoint,
		NEW_SESSION_CHECKPOINT_FIELDS,
		"ai_new_session_checkpoint_v3_wire_invalid"
	)
	if not bool(decoded.get("ok", false)):
		return decoded
	var runtime_checkpoint := decoded.get("value", {}) as Dictionary
	if not (runtime_checkpoint.get("schema_version") is int) \
			or int(runtime_checkpoint.get("schema_version", 0)) != NEW_SESSION_CHECKPOINT_SCHEMA_VERSION:
		return _failure("ai_new_session_checkpoint_v3_shape_invalid")
	return decoded


static func _encode_tree(runtime_value: Dictionary, fallback_reason: String) -> Dictionary:
	if _contains_reserved_codec_key(runtime_value):
		return _failure("ai_save_v3_reserved_codec_key_collision")
	var encoded := _encode_value(runtime_value)
	if not bool(encoded.get("ok", false)) or not (encoded.get("value") is Dictionary):
		return _failure(str(encoded.get("reason_code", fallback_reason)))
	var wire_value := (encoded.get("value") as Dictionary).duplicate(true)
	if not SEMANTIC_WIRE.is_closed_data(wire_value):
		return _failure(fallback_reason)
	return {"ok": true, "value": wire_value}


static func _decode_tree(wire_value: Dictionary, fields: Array, fallback_reason: String) -> Dictionary:
	if not _has_exact_keys(wire_value, fields) or not SEMANTIC_WIRE.is_closed_data(wire_value):
		return _failure(fallback_reason)
	var decoded := _decode_value(wire_value)
	if not bool(decoded.get("ok", false)) or not (decoded.get("value") is Dictionary):
		return _failure(str(decoded.get("reason_code", fallback_reason)))
	var runtime_value := (decoded.get("value") as Dictionary).duplicate(true)
	if not _has_exact_keys(runtime_value, fields):
		return _failure(fallback_reason)
	var canonical := _encode_tree(runtime_value, fallback_reason)
	if not bool(canonical.get("ok", false)) or canonical.get("value") != wire_value:
		return _failure("ai_save_v3_wire_noncanonical")
	return {"ok": true, "value": runtime_value}


static func _encode_value(value: Variant) -> Dictionary:
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
		return CLOSED_SCALAR_CODEC.encode_f64(value)
	if value is Array:
		var encoded_array: Array = []
		for child in value as Array:
			var encoded_child := _encode_value(child)
			if not bool(encoded_child.get("ok", false)):
				return encoded_child
			encoded_array.append(encoded_child.get("value"))
		return {"ok": true, "value": encoded_array}
	if value is Dictionary:
		var dictionary := value as Dictionary
		if dictionary.has(TAG_KEY) or dictionary.has(CLOSED_SCALAR_CODEC.INT64_CODEC_KEY):
			return _failure("ai_save_v3_reserved_codec_key_collision")
		var keys: Array[String] = []
		for key_variant in dictionary.keys():
			if not (key_variant is String):
				return _failure("ai_save_v3_dictionary_key_not_string")
			keys.append(str(key_variant))
		keys.sort()
		var encoded_dictionary: Dictionary = {}
		for key in keys:
			var encoded_child := _encode_value(dictionary.get(key))
			if not bool(encoded_child.get("ok", false)):
				return encoded_child
			encoded_dictionary[key] = encoded_child.get("value")
		return {"ok": true, "value": encoded_dictionary}
	if value == null:
		return _failure("ai_save_v3_null_not_authorized")
	if value is StringName:
		return _failure("ai_save_v3_string_name_not_authorized")
	return _failure("ai_save_v3_variant_type_not_authorized")


static func _decode_value(value: Variant) -> Dictionary:
	if value is String or value is bool:
		return {"ok": true, "value": value}
	if value is int:
		return _failure("ai_save_v3_raw_integer_rejected")
	if value is float:
		return _failure("ai_save_v3_raw_float_rejected")
	if value is Array:
		var decoded_array: Array = []
		for child in value as Array:
			var decoded_child := _decode_value(child)
			if not bool(decoded_child.get("ok", false)):
				return decoded_child
			decoded_array.append(decoded_child.get("value"))
		return {"ok": true, "value": decoded_array}
	if value is Dictionary:
		var dictionary := value as Dictionary
		if dictionary.has(CLOSED_SCALAR_CODEC.INT64_CODEC_KEY):
			return _failure("ai_save_v3_unknown_codec_tag")
		if dictionary.has(TAG_KEY):
			if not (dictionary.get(TAG_KEY) is String):
				return _failure("ai_save_v3_unknown_codec_tag")
			var codec_id := str(dictionary.get(TAG_KEY, ""))
			if codec_id == CLOSED_SCALAR_CODEC.F64_CODEC_ID:
				return CLOSED_SCALAR_CODEC.decode_f64(dictionary)
			if codec_id == INT64_CODEC_ID:
				return _decode_int64(dictionary)
			return _failure("ai_save_v3_unknown_codec_tag")
		var keys: Array[String] = []
		for key_variant in dictionary.keys():
			if not (key_variant is String):
				return _failure("ai_save_v3_dictionary_key_not_string")
			keys.append(str(key_variant))
		keys.sort()
		var decoded_dictionary: Dictionary = {}
		for key in keys:
			var decoded_child := _decode_value(dictionary.get(key))
			if not bool(decoded_child.get("ok", false)):
				return decoded_child
			decoded_dictionary[key] = decoded_child.get("value")
		return {"ok": true, "value": decoded_dictionary}
	return _failure("ai_save_v3_wire_variant_forbidden")


static func _decode_int64(tag: Dictionary) -> Dictionary:
	if not _has_exact_keys(tag, INT64_FIELDS) or not (tag.get("value") is String):
		return _failure("ai_save_v3_int64_tag_invalid")
	var shared_tag := {
		CLOSED_SCALAR_CODEC.INT64_CODEC_KEY: CLOSED_SCALAR_CODEC.INT64_CODEC_ID,
		"value": str(tag.get("value", "")),
	}
	var decoded := CLOSED_SCALAR_CODEC.decode_tree(shared_tag)
	if not bool(decoded.get("ok", false)) or not (decoded.get("value") is int):
		return _failure(str(decoded.get("reason_code", "ai_save_v3_int64_tag_invalid")))
	var decoded_value := int(decoded.get("value"))
	if _encode_value(decoded_value).get("value") != tag:
		return _failure("ai_save_v3_int64_tag_invalid")
	return {"ok": true, "value": decoded_value}


static func _contains_reserved_codec_key(value: Variant) -> bool:
	if value is Dictionary:
		var dictionary := value as Dictionary
		if dictionary.has("codec") or dictionary.has(CLOSED_SCALAR_CODEC.INT64_CODEC_KEY):
			return true
		for child in dictionary.values():
			if _contains_reserved_codec_key(child):
				return true
	elif value is Array:
		for child in value as Array:
			if _contains_reserved_codec_key(child):
				return true
	return false


static func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key_variant in expected:
		if not value.has(str(key_variant)):
			return false
	return true


static func _failure(reason_code: String) -> Dictionary:
	return {"ok": false, "reason_code": reason_code}
