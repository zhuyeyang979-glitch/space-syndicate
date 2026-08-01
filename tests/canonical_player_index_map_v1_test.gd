extends SceneTree

const CODEC := preload("res://scripts/runtime/canonical_player_index_map_v1.gd")
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const HANDSHAKE := preload("res://scripts/runtime/ruleset_save_handshake_service.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var handshake := HANDSHAKE.new() as RulesetSaveHandshakeService
	for player_count in [3, 4, 6, 8]:
		var source := {player_count - 1: {"state": "active"}, 0: {"state": "pending"}}
		var encoded := CODEC.encode(source, player_count)
		var wire := encoded.get("value", {}) as Dictionary
		var disk_encoded := handshake.encode_codec_value(wire)
		var parsed: Variant = JSON.parse_string(JSON.stringify(disk_encoded.get("value")))
		var disk_decoded := handshake.decode_codec_value(parsed)
		var decoded := CODEC.decode(disk_decoded.get("value"), player_count)
		_expect(bool(encoded.get("ok", false)) and WIRE.is_closed_data(wire), "player map wire is closed for %d seats" % player_count)
		_expect(bool(decoded.get("ok", false)), "player map JSON wire decodes for %d seats: %s" % [player_count, str(decoded.get("reason_code", ""))])
		_expect(decoded.get("value") == source, "player map runtime state is exact for %d seats" % player_count)
		_expect(decoded.get("normalized_wire") == wire, "player map canonical wire is exact for %d seats" % player_count)
	var invalid_keys := ["", "+1", "-1", " 1", "1 ", "1.0", "1e0", "one"]
	for key in invalid_keys:
		_expect(_decode_reason({key: {}}, 4) == "player_index_key_invalid", "invalid player key form is rejected")
	_expect(_decode_reason({"01": {}}, 4) == "player_index_key_noncanonical", "leading zero is rejected as noncanonical")
	_expect(_decode_reason({"1": {}, "01": {}}, 4) == "player_index_numeric_collision", "numeric collision wins over noncanonical reason")
	_expect(_decode_reason({"4": {}}, 4) == "player_index_out_of_range", "player index upper bound is enforced")
	_expect(_decode_reason({"0": 1.5}, 4) == "player_index_map_value_not_closed", "map values must already be closed")
	_expect(bool(CODEC.encode({}, 0).get("ok", false)) and bool(CODEC.decode(CODEC.encode({}, 0).get("value"), 0).get("ok", false)), "empty no-session map is canonical")
	handshake.free()
	_finish()


func _decode_reason(entries: Dictionary, player_count: int) -> String:
	var result := CODEC.decode({
		"schema_version": 1,
		"key_codec": CODEC.KEY_CODEC_ID,
		"entries": entries,
	}, player_count)
	return str(result.get("reason_code", ""))


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("CANONICAL_PLAYER_INDEX_MAP_V1_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	if not _failures.is_empty():
		push_error("Canonical player-index map failures:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)
