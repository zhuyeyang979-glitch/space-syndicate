extends RefCounted
class_name CanonicalPlayerIndexMapV1

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const SCHEMA_VERSION := 1
const KEY_CODEC_ID := "nonnegative_decimal_string_v1"
const ROOT_FIELDS := ["schema_version", "key_codec", "entries"]
const MIN_ACTIVE_PLAYER_COUNT := 3
const MAX_ACTIVE_PLAYER_COUNT := 8


static func encode(source: Dictionary, player_count: int) -> Dictionary:
	if not _valid_player_count(player_count):
		return _failure("player_index_out_of_range")
	if player_count == 0 and not source.is_empty():
		return _failure("player_index_out_of_range")
	var indices: Array[int] = []
	for key_variant in source.keys():
		if not (key_variant is int) or not WIRE.is_safe_integer(key_variant):
			return _failure("player_index_key_invalid")
		var index := int(key_variant)
		if index < 0 or index >= player_count:
			return _failure("player_index_out_of_range")
		if not WIRE.is_closed_data(source.get(key_variant)):
			return _failure("player_index_map_value_not_closed")
		indices.append(index)
	indices.sort()
	var entries: Dictionary = {}
	for index in indices:
		entries[str(index)] = WIRE.detached_copy(source.get(index))
	return {"ok": true, "value": {
		"schema_version": SCHEMA_VERSION,
		"key_codec": KEY_CODEC_ID,
		"entries": entries,
	}}


static func decode(value: Variant, player_count: int) -> Dictionary:
	if not _valid_player_count(player_count) or not (value is Dictionary):
		return _failure("player_index_out_of_range")
	var wire := value as Dictionary
	if not _has_exact_keys(wire, ROOT_FIELDS) \
			or not (wire.get("schema_version") is int) \
			or int(wire.get("schema_version", 0)) != SCHEMA_VERSION \
			or not (wire.get("key_codec") is String) \
			or str(wire.get("key_codec", "")) != KEY_CODEC_ID \
			or not (wire.get("entries") is Dictionary):
		return _failure("player_index_map_shape_invalid")
	var entries := wire.get("entries", {}) as Dictionary
	if player_count == 0 and not entries.is_empty():
		return _failure("player_index_out_of_range")
	var parsed_by_key: Dictionary = {}
	var keys_by_index: Dictionary = {}
	var noncanonical_keys: Array[String] = []
	for key_variant in entries.keys():
		if not (key_variant is String):
			return _failure("player_index_key_invalid")
		var key := str(key_variant)
		var parsed := _parse_decimal_key(key)
		if not bool(parsed.get("valid", false)):
			return _failure("player_index_key_invalid")
		var index := int(parsed.get("value", -1))
		if keys_by_index.has(index):
			return _failure("player_index_numeric_collision")
		keys_by_index[index] = key
		parsed_by_key[key] = index
		if not bool(parsed.get("canonical", false)):
			noncanonical_keys.append(key)
	if not noncanonical_keys.is_empty():
		return _failure("player_index_key_noncanonical")
	var indices: Array[int] = []
	for key_variant in parsed_by_key.keys():
		var key := str(key_variant)
		var index := int(parsed_by_key.get(key, -1))
		if index < 0 or index >= player_count:
			return _failure("player_index_out_of_range")
		if not WIRE.is_closed_data(entries.get(key)):
			return _failure("player_index_map_value_not_closed")
		indices.append(index)
	indices.sort()
	var decoded: Dictionary = {}
	for index in indices:
		decoded[index] = WIRE.detached_copy(entries.get(str(index)))
	var normalized := encode(decoded, player_count)
	if not bool(normalized.get("ok", false)):
		return normalized
	return {
		"ok": true,
		"value": decoded,
		"normalized_wire": (normalized.get("value", {}) as Dictionary).duplicate(true),
	}


static func _parse_decimal_key(text: String) -> Dictionary:
	if text.is_empty():
		return {"valid": false}
	var value := 0
	for index in range(text.length()):
		var code := text.unicode_at(index)
		if code < 48 or code > 57:
			return {"valid": false}
		var digit := code - 48
		if value > int((WIRE.MAX_SAFE_INTEGER - digit) / 10):
			return {"valid": false}
		value = value * 10 + digit
	return {
		"valid": true,
		"canonical": text == "0" or not text.begins_with("0"),
		"value": value,
	}


static func _valid_player_count(player_count: int) -> bool:
	return player_count == 0 \
			or (player_count >= MIN_ACTIVE_PLAYER_COUNT and player_count <= MAX_ACTIVE_PLAYER_COUNT)


static func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key_variant in expected:
		if not value.has(str(key_variant)):
			return false
	return true


static func _failure(reason_code: String) -> Dictionary:
	return {"ok": false, "reason_code": reason_code}
