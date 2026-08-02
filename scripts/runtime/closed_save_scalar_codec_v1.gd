extends RefCounted
class_name ClosedSaveScalarCodecV1

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const F64_CODEC_ID := "f64_bits_hex_v1"
const INT64_CODEC_KEY := "$codec"
const INT64_CODEC_ID := "Int64"
const F64_FIELDS := ["codec", "bits"]
const INT64_FIELDS := [INT64_CODEC_KEY, "value"]


static func encode_f64(value: Variant) -> Dictionary:
	if not (value is float) or not is_finite(float(value)):
		return _failure("f64_nonfinite_rejected")
	return {
		"ok": true,
		"value": {
			"codec": F64_CODEC_ID,
			"bits": f64_bits_hex(float(value)),
		},
	}


static func decode_f64(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return _failure("f64_tag_shape_invalid")
	var tag := value as Dictionary
	if not _has_exact_keys(tag, F64_FIELDS) \
			or not (tag.get("codec") is String) \
			or str(tag.get("codec", "")) != F64_CODEC_ID \
			or not (tag.get("bits") is String):
		return _failure("f64_tag_shape_invalid")
	return decode_f64_bits_hex(str(tag.get("bits", "")))


static func f64_bits_hex(value: float) -> String:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	return bytes.hex_encode()


static func decode_f64_bits_hex(bits: String) -> Dictionary:
	if not _is_lower_hex_16(bits):
		return _failure("f64_bits_invalid")
	var bytes := bits.hex_decode()
	if bytes.size() != 8 or bytes.hex_encode() != bits:
		return _failure("f64_bits_invalid")
	var decoded := bytes.decode_double(0)
	if not is_finite(decoded):
		return _failure("f64_nonfinite_rejected")
	if f64_bits_hex(decoded) != bits:
		return _failure("f64_bits_invalid")
	return {"ok": true, "value": decoded, "bits": bits}


static func encode_tree(value: Variant) -> Dictionary:
	if value is String or value is bool:
		return {"ok": true, "value": value}
	if value is int:
		if WIRE.is_safe_integer(value):
			return {"ok": true, "value": value}
		return {"ok": true, "value": {
			INT64_CODEC_KEY: INT64_CODEC_ID,
			"value": str(value),
		}}
	if value is float:
		return encode_f64(value)
	if value is Array:
		var encoded_array: Array = []
		for item in value as Array:
			var encoded_item := encode_tree(item)
			if not bool(encoded_item.get("ok", false)):
				return encoded_item
			encoded_array.append(encoded_item.get("value"))
		return {"ok": true, "value": encoded_array}
	if value is Dictionary:
		var source := value as Dictionary
		var keys: Array[String] = []
		for key_variant in source.keys():
			if not (key_variant is String):
				return _failure("closed_save_dictionary_key_invalid")
			keys.append(str(key_variant))
		keys.sort()
		var encoded_dictionary: Dictionary = {}
		for key in keys:
			var encoded_item := encode_tree(source.get(key))
			if not bool(encoded_item.get("ok", false)):
				return encoded_item
			encoded_dictionary[key] = encoded_item.get("value")
		return {"ok": true, "value": encoded_dictionary}
	if value == null:
		return _failure("closed_save_null_rejected")
	if value is StringName:
		return _failure("closed_save_string_name_requires_explicit_conversion")
	return _failure("closed_save_variant_type_forbidden")


static func decode_tree(value: Variant) -> Dictionary:
	if value is String or value is bool:
		return {"ok": true, "value": value}
	if value is int:
		return {"ok": true, "value": value} \
				if WIRE.is_safe_integer(value) else _failure("closed_save_unsafe_integer_untagged")
	if value is float:
		return _failure("closed_save_raw_float_rejected")
	if value is Array:
		var decoded_array: Array = []
		for item in value as Array:
			var decoded_item := decode_tree(item)
			if not bool(decoded_item.get("ok", false)):
				return decoded_item
			decoded_array.append(decoded_item.get("value"))
		return {"ok": true, "value": decoded_array}
	if value is Dictionary:
		var source := value as Dictionary
		if source.has("codec") and str(source.get("codec", "")) == F64_CODEC_ID:
			return decode_f64(source)
		if source.has(INT64_CODEC_KEY):
			return _decode_int64(source)
		var keys: Array[String] = []
		for key_variant in source.keys():
			if not (key_variant is String):
				return _failure("closed_save_dictionary_key_invalid")
			keys.append(str(key_variant))
		keys.sort()
		var decoded_dictionary: Dictionary = {}
		for key in keys:
			var decoded_item := decode_tree(source.get(key))
			if not bool(decoded_item.get("ok", false)):
				return decoded_item
			decoded_dictionary[key] = decoded_item.get("value")
		return {"ok": true, "value": decoded_dictionary}
	if value == null:
		return _failure("closed_save_null_rejected")
	return _failure("closed_save_variant_type_forbidden")


static func _decode_int64(tag: Dictionary) -> Dictionary:
	if not _has_exact_keys(tag, INT64_FIELDS) \
			or not (tag.get(INT64_CODEC_KEY) is String) \
			or str(tag.get(INT64_CODEC_KEY, "")) != INT64_CODEC_ID \
			or not (tag.get("value") is String):
		return _failure("closed_save_int64_tag_invalid")
	var text := str(tag.get("value", ""))
	if not _canonical_int64_decimal(text):
		return _failure("closed_save_int64_noncanonical")
	return {"ok": true, "value": text.to_int()}


static func _canonical_int64_decimal(text: String) -> bool:
	if text.is_empty():
		return false
	var offset := 1 if text.begins_with("-") else 0
	if offset == text.length():
		return false
	if text.length() - offset > 1 and text.substr(offset, 1) == "0":
		return false
	if offset == 1 and text.substr(offset) == "0":
		return false
	for index in range(offset, text.length()):
		var code := text.unicode_at(index)
		if code < 48 or code > 57:
			return false
	var parsed := text.to_int()
	return str(parsed) == text


static func _is_lower_hex_16(bits: String) -> bool:
	if bits.length() != 16:
		return false
	for index in range(bits.length()):
		var code := bits.unicode_at(index)
		if not ((code >= 48 and code <= 57) or (code >= 97 and code <= 102)):
			return false
	return true


static func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key_variant in expected:
		if not value.has(str(key_variant)):
			return false
	return true


static func _failure(reason_code: String) -> Dictionary:
	return {"ok": false, "reason_code": reason_code}
