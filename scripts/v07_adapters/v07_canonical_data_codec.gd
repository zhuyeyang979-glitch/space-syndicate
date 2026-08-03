extends RefCounted
class_name V07CanonicalDataCodec

const CANONICALIZATION_ID := "rfc8785_jcs_with_tagged_int64_v1"
const HASH_ALGORITHM_ID := "sha256"
const MAX_DEPTH := 96


static func is_pure_data(value: Variant, depth: int = 0) -> bool:
	if depth > MAX_DEPTH:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return true
		TYPE_FLOAT:
			return is_finite(float(value))
		TYPE_ARRAY:
			for item_variant in value as Array:
				if not is_pure_data(item_variant, depth + 1):
					return false
			return true
		TYPE_DICTIONARY:
			for key_variant in (value as Dictionary).keys():
				if not (key_variant is String) \
						or not is_pure_data(
							(value as Dictionary).get(key_variant), depth + 1
						):
					return false
			return true
		_:
			return false


static func canonical_json(value: Variant) -> String:
	if not is_pure_data(value):
		return ""
	return _canonical_json_unchecked(value)


static func _canonical_json_unchecked(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if bool(value) else "false"
		TYPE_INT:
			return str(int(value))
		TYPE_FLOAT:
			return _canonical_float(float(value))
		TYPE_STRING:
			return JSON.stringify(str(value))
		TYPE_ARRAY:
			var array_parts: Array[String] = []
			for item_variant in value as Array:
				array_parts.append(_canonical_json_unchecked(item_variant))
			return "[" + ",".join(array_parts) + "]"
		TYPE_DICTIONARY:
			var source := value as Dictionary
			var keys: Array[String] = []
			for key_variant in source.keys():
				keys.append(str(key_variant))
			keys.sort_custom(
				func(left: String, right: String) -> bool:
					return _utf16_less(left, right)
			)
			var members: Array[String] = []
			for key in keys:
				members.append(
					JSON.stringify(key) + ":" \
						+ _canonical_json_unchecked(source.get(key))
				)
			return "{" + ",".join(members) + "}"
		_:
			return ""


static func canonical_bytes(value: Variant) -> PackedByteArray:
	var encoded := canonical_json(value)
	return encoded.to_utf8_buffer() if not encoded.is_empty() else PackedByteArray()


static func fingerprint(value: Variant, excluded_field: String = "") -> String:
	if not is_pure_data(value):
		return ""
	var fingerprint_input: Variant = deep_copy(value)
	if fingerprint_input is Dictionary and not excluded_field.is_empty():
		(fingerprint_input as Dictionary).erase(excluded_field)
	var encoded := _canonical_json_unchecked(fingerprint_input)
	return encoded.sha256_text().to_lower() if not encoded.is_empty() else ""


static func seal(unsealed: Dictionary, fingerprint_field: String) -> Dictionary:
	if fingerprint_field.is_empty() or unsealed.has(fingerprint_field) \
			or not is_pure_data(unsealed):
		return {}
	var result := unsealed.duplicate(true)
	result[fingerprint_field] = fingerprint(result)
	return result


static func encode(value: Variant) -> Dictionary:
	var encoded := canonical_json(value)
	if encoded.is_empty():
		return _failure("canonical_value_invalid")
	return {
		"accepted": true,
		"reason_code": "canonical_value_encoded",
		"canonicalization_id": CANONICALIZATION_ID,
		"text": encoded,
		"byte_count": encoded.to_utf8_buffer().size(),
		"fingerprint": encoded.sha256_text().to_lower(),
	}


static func decode_text(text: String, require_canonical: bool = true) -> Dictionary:
	if text.is_empty():
		return _failure("canonical_text_invalid")
	var parser := JSON.new()
	var parse_error := parser.parse(text)
	if parse_error != OK:
		var failure := _failure("canonical_json_parse_failed")
		failure["error_line"] = parser.get_error_line()
		return failure
	var number_tokens := _json_number_tokens(text)
	var number_cursor: Array[int] = [0]
	var value: Variant = _restore_json_number_types(
		parser.data, number_tokens, number_cursor
	)
	if number_cursor[0] != number_tokens.size():
		return _failure("canonical_json_number_scan_mismatch")
	if not is_pure_data(value):
		return _failure("canonical_json_not_pure_data")
	var canonical := canonical_json(value)
	if canonical.is_empty():
		return _failure("canonical_json_reencode_failed")
	if require_canonical and canonical != text:
		return _failure("canonical_json_not_canonical")
	return {
		"accepted": true,
		"reason_code": "canonical_json_decoded",
		"canonical": canonical == text,
		"canonicalization_id": CANONICALIZATION_ID,
		"value": deep_copy(value),
		"text": canonical,
		"byte_count": canonical.to_utf8_buffer().size(),
		"fingerprint": canonical.sha256_text().to_lower(),
	}


static func decode_bytes(
	bytes: PackedByteArray,
	require_canonical: bool = true
) -> Dictionary:
	if bytes.is_empty():
		return _failure("canonical_bytes_empty")
	var text := bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes:
		return _failure("canonical_bytes_utf8_invalid")
	return decode_text(text, require_canonical)


static func exact_roundtrip(value: Variant) -> Dictionary:
	var encoded := encode(value)
	if not bool(encoded.get("accepted", false)):
		return encoded
	var decoded := decode_text(str(encoded.get("text", "")), true)
	if not bool(decoded.get("accepted", false)):
		return decoded
	var exact: bool = canonical_json(value) == str(decoded.get("text", "")) \
		and fingerprint(value) == str(decoded.get("fingerprint", ""))
	return {
		"accepted": exact,
		"exact": exact,
		"reason_code": (
			"canonical_roundtrip_exact"
			if exact
			else "canonical_roundtrip_mismatch"
		),
		"value": deep_copy(decoded.get("value")),
		"text": str(decoded.get("text", "")),
		"byte_count": int(decoded.get("byte_count", 0)),
		"fingerprint": str(decoded.get("fingerprint", "")),
	}


static func is_fingerprint(value: Variant) -> bool:
	if not (value is String) or str(value).length() != 64:
		return false
	for index in range(64):
		var code := str(value).unicode_at(index)
		if not ((code >= 48 and code <= 57) or (code >= 97 and code <= 102)):
			return false
	return true


static func is_tagged_int64(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var tagged := value as Dictionary
	if not has_exact_fields(tagged, ["type", "decimal"]) \
			or tagged.get("type") != "int64" \
			or not (tagged.get("decimal") is String):
		return false
	return _canonical_int64_decimal(str(tagged.get("decimal", "")))


static func has_exact_fields(value: Dictionary, fields: Array) -> bool:
	if value.size() != fields.size():
		return false
	for field_variant in fields:
		if not value.has(str(field_variant)):
			return false
	return true


static func deep_copy(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value


static func _canonical_float(value: float) -> String:
	if not is_finite(value):
		return ""
	if value == 0.0:
		return "0"
	var encoded := JSON.stringify(value).replace("E", "e")
	if encoded.ends_with(".0"):
		encoded = encoded.left(encoded.length() - 2)
	return encoded


static func _json_number_tokens(text: String) -> Array[String]:
	var tokens: Array[String] = []
	var in_string := false
	var escaped := false
	var index := 0
	while index < text.length():
		var code := text.unicode_at(index)
		if in_string:
			if escaped:
				escaped = false
			elif code == 92:
				escaped = true
			elif code == 34:
				in_string = false
			index += 1
			continue
		if code == 34:
			in_string = true
			index += 1
			continue
		if code == 45 or (code >= 48 and code <= 57):
			var start := index
			index += 1
			while index < text.length():
				var number_code := text.unicode_at(index)
				if not (
					(number_code >= 48 and number_code <= 57)
					or number_code in [43, 45, 46, 69, 101]
				):
					break
				index += 1
			tokens.append(text.substr(start, index - start))
			continue
		index += 1
	return tokens


static func _restore_json_number_types(
	value: Variant,
	tokens: Array[String],
	cursor: Array[int]
) -> Variant:
	if value is int or value is float:
		if cursor[0] >= tokens.size():
			cursor[0] = tokens.size() + 1
			return value
		var token := tokens[cursor[0]]
		cursor[0] += 1
		return token.to_float() \
			if token.contains(".") or token.contains("e") or token.contains("E") \
			else token.to_int()
	if value is Array:
		var restored_array: Array = []
		for item_variant in value as Array:
			restored_array.append(_restore_json_number_types(
				item_variant, tokens, cursor
			))
		return restored_array
	if value is Dictionary:
		var source := value as Dictionary
		var keys: Array[String] = []
		for key_variant in source.keys():
			keys.append(str(key_variant))
		keys.sort_custom(
			func(left: String, right: String) -> bool:
				return _utf16_less(left, right)
		)
		var restored_dictionary := {}
		for key in keys:
			restored_dictionary[key] = _restore_json_number_types(
				source.get(key), tokens, cursor
			)
		return restored_dictionary
	return value


static func _utf16_less(left: String, right: String) -> bool:
	var left_units := _utf16_units(left)
	var right_units := _utf16_units(right)
	var shared := mini(left_units.size(), right_units.size())
	for index in range(shared):
		if left_units[index] != right_units[index]:
			return int(left_units[index]) < int(right_units[index])
	return left_units.size() < right_units.size()


static func _utf16_units(value: String) -> Array[int]:
	var units: Array[int] = []
	for index in range(value.length()):
		var codepoint := value.unicode_at(index)
		if codepoint <= 0xffff:
			units.append(codepoint)
		else:
			var scalar := codepoint - 0x10000
			units.append(0xd800 + (scalar >> 10))
			units.append(0xdc00 + (scalar & 0x3ff))
	return units


static func _canonical_int64_decimal(decimal: String) -> bool:
	if decimal.is_empty():
		return false
	var negative := decimal.begins_with("-")
	var digits := decimal.substr(1) if negative else decimal
	if digits.is_empty() or (digits.length() > 1 and digits.begins_with("0")) \
			or (negative and digits == "0"):
		return false
	for index in range(digits.length()):
		var code := digits.unicode_at(index)
		if code < 48 or code > 57:
			return false
	var limit := "9223372036854775808" if negative else "9223372036854775807"
	if digits.length() != limit.length():
		return digits.length() < limit.length()
	return digits <= limit


static func _failure(reason_code: String) -> Dictionary:
	return {
		"accepted": false,
		"reason_code": reason_code,
		"canonicalization_id": CANONICALIZATION_ID,
	}
