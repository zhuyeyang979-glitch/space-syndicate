extends RefCounted
class_name MonsterSaveWireCodecV2

const CLOSED_SCALAR_CODEC := preload("res://scripts/runtime/closed_save_scalar_codec_v1.gd")
const SEMANTIC_WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")

const TAG_KEY := "codec"
const INT64_CODEC_ID := "monster_int64_decimal_v1"
const VECTOR2_CODEC_ID := "Vector2F64V1"
const INT64_FIELDS := [TAG_KEY, "value"]
const VECTOR2_FIELDS := [TAG_KEY, "x", "y"]


static func encode_save_state(runtime_state: Dictionary) -> Dictionary:
	var encoded := _encode_value(runtime_state, "$")
	if not bool(encoded.get("ok", false)) or not (encoded.get("value") is Dictionary):
		return encoded
	if not SEMANTIC_WIRE.is_closed_data(encoded.get("value")):
		return _failure("monster_save_wire_not_closed_data", "$")
	return {"ok": true, "value": (encoded.get("value") as Dictionary).duplicate(true)}


static func decode_save_state(wire_state: Dictionary) -> Dictionary:
	if not SEMANTIC_WIRE.is_closed_data(wire_state):
		return _failure("monster_save_wire_not_closed_data", "$")
	var decoded := _decode_value(wire_state, "$")
	if not bool(decoded.get("ok", false)) or not (decoded.get("value") is Dictionary):
		return decoded
	return {"ok": true, "value": (decoded.get("value") as Dictionary).duplicate(true)}


static func _encode_value(value: Variant, path: String) -> Dictionary:
	if value is String or value is bool:
		return {"ok": true, "value": value}
	if value is int:
		# Godot's JSON parser returns every JSON number as float. Tagging every
		# integer, including the SemanticWire-safe range, preserves Variant type
		# without colliding with the Save Envelope's reserved `$codec` key.
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
			str(encoded_float.get("reason_code", "monster_save_float_encode_failed")),
			path
		)
	if value is Vector2:
		var vector := value as Vector2
		var encoded_x := CLOSED_SCALAR_CODEC.encode_f64(vector.x)
		var encoded_y := CLOSED_SCALAR_CODEC.encode_f64(vector.y)
		if not bool(encoded_x.get("ok", false)) or not bool(encoded_y.get("ok", false)):
			return _failure("monster_save_vector2_nonfinite_rejected", path)
		return {
			"ok": true,
			"value": {
				TAG_KEY: VECTOR2_CODEC_ID,
				"x": encoded_x.get("value"),
				"y": encoded_y.get("value"),
			},
		}
	if value is Array:
		var encoded_array: Array = []
		var array := value as Array
		for index in range(array.size()):
			var encoded_item := _encode_value(array[index], "%s[%d]" % [path, index])
			if not bool(encoded_item.get("ok", false)):
				return encoded_item
			encoded_array.append(encoded_item.get("value"))
		return {"ok": true, "value": encoded_array}
	if value is Dictionary:
		var source := value as Dictionary
		if source.has(TAG_KEY) or source.has(CLOSED_SCALAR_CODEC.INT64_CODEC_KEY):
			return _failure("monster_save_wire_reserved_tag_collision", path)
		var keys: Array[String] = []
		for key_variant: Variant in source.keys():
			if not (key_variant is String):
				return _failure("monster_save_dictionary_key_not_string", path)
			keys.append(str(key_variant))
		keys.sort()
		var encoded_dictionary: Dictionary = {}
		for key in keys:
			var encoded_item := _encode_value(source.get(key), _child_path(path, key))
			if not bool(encoded_item.get("ok", false)):
				return encoded_item
			encoded_dictionary[key] = encoded_item.get("value")
		return {"ok": true, "value": encoded_dictionary}
	if value == null:
		return _failure("monster_save_null_not_authorized", path)
	if value is StringName:
		return _failure("monster_save_string_name_not_authorized", path)
	if value is Color:
		return _failure("monster_save_color_not_authorized", path)
	return _failure("monster_save_variant_type_not_authorized", path)


static func _decode_value(value: Variant, path: String) -> Dictionary:
	if value is String or value is bool:
		return {"ok": true, "value": value}
	if value is int:
		return _failure("monster_save_raw_integer_rejected", path)
	if value is float:
		return _failure("monster_save_raw_float_rejected", path)
	if value is Array:
		var decoded_array: Array = []
		var array := value as Array
		for index in range(array.size()):
			var decoded_item := _decode_value(array[index], "%s[%d]" % [path, index])
			if not bool(decoded_item.get("ok", false)):
				return decoded_item
			decoded_array.append(decoded_item.get("value"))
		return {"ok": true, "value": decoded_array}
	if value is Dictionary:
		var source := value as Dictionary
		if source.has(CLOSED_SCALAR_CODEC.INT64_CODEC_KEY):
			return _failure("monster_save_unknown_codec_tag", path)
		if source.has(TAG_KEY):
			var codec_id_variant: Variant = source.get(TAG_KEY)
			if not (codec_id_variant is String):
				return _failure("monster_save_unknown_codec_tag", path)
			var codec_id := str(codec_id_variant)
			if codec_id == CLOSED_SCALAR_CODEC.F64_CODEC_ID:
				var decoded_float := CLOSED_SCALAR_CODEC.decode_f64(source)
				return decoded_float if bool(decoded_float.get("ok", false)) else _failure(
					str(decoded_float.get("reason_code", "monster_save_f64_tag_invalid")),
					path
				)
			if codec_id == INT64_CODEC_ID:
				return _decode_int64(source, path)
			if codec_id == VECTOR2_CODEC_ID:
				return _decode_vector2(source, path)
			return _failure("monster_save_unknown_codec_tag", path)
		var keys: Array[String] = []
		for key_variant: Variant in source.keys():
			if not (key_variant is String):
				return _failure("monster_save_dictionary_key_not_string", path)
			keys.append(str(key_variant))
		keys.sort()
		var decoded_dictionary: Dictionary = {}
		for key in keys:
			var decoded_item := _decode_value(source.get(key), _child_path(path, key))
			if not bool(decoded_item.get("ok", false)):
				return decoded_item
			decoded_dictionary[key] = decoded_item.get("value")
		return {"ok": true, "value": decoded_dictionary}
	return _failure("monster_save_wire_variant_forbidden", path)


static func _decode_vector2(tag: Dictionary, path: String) -> Dictionary:
	if not _has_exact_keys(tag, VECTOR2_FIELDS):
		return _failure("monster_save_vector2_tag_shape_invalid", path)
	var decoded_x := CLOSED_SCALAR_CODEC.decode_f64(tag.get("x"))
	var decoded_y := CLOSED_SCALAR_CODEC.decode_f64(tag.get("y"))
	if not bool(decoded_x.get("ok", false)) or not bool(decoded_y.get("ok", false)):
		return _failure("monster_save_vector2_component_invalid", path)
	var vector := Vector2(float(decoded_x.get("value")), float(decoded_y.get("value")))
	var encoded_x := CLOSED_SCALAR_CODEC.encode_f64(vector.x)
	var encoded_y := CLOSED_SCALAR_CODEC.encode_f64(vector.y)
	if encoded_x.get("value") != tag.get("x") or encoded_y.get("value") != tag.get("y"):
		return _failure("monster_save_vector2_tag_noncanonical", path)
	return {"ok": true, "value": vector}


static func _decode_int64(tag: Dictionary, path: String) -> Dictionary:
	if not _has_exact_keys(tag, INT64_FIELDS) or not (tag.get("value") is String):
		return _failure("monster_save_int64_tag_invalid", path)
	var shared_tag := {
		CLOSED_SCALAR_CODEC.INT64_CODEC_KEY: CLOSED_SCALAR_CODEC.INT64_CODEC_ID,
		"value": str(tag.get("value", "")),
	}
	var decoded := CLOSED_SCALAR_CODEC.decode_tree(shared_tag)
	if not bool(decoded.get("ok", false)) or not (decoded.get("value") is int):
		return _failure(str(decoded.get("reason_code", "monster_save_int64_tag_invalid")), path)
	var value := int(decoded.get("value"))
	if _encode_value(value, path).get("value") != tag:
		return _failure("monster_save_int64_tag_invalid", path)
	return {"ok": true, "value": value}


static func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key_variant: Variant in expected:
		if not value.has(str(key_variant)):
			return false
	return true


static func _child_path(parent: String, key: String) -> String:
	return "%s.%s" % [parent, ("monster_wire_key|%d|%s" % [
		key.length(),
		key.sha256_text().to_lower(),
	]).sha256_text().substr(0, 12)]


static func _failure(reason_code: String, path: String) -> Dictionary:
	return {
		"ok": false,
		"reason_code": reason_code,
		"redacted_path": path,
	}
