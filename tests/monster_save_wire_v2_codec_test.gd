extends SceneTree

const CODEC := preload("res://scripts/runtime/monster_save_wire_codec_v2.gd")
const SCALAR := preload("res://scripts/runtime/closed_save_scalar_codec_v1.gd")
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const ENVELOPE_CODEC := preload("res://scripts/runtime/ruleset_save_handshake_service.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var scalar_samples: Array[float] = [
		0.0,
		-0.0,
		1.0,
		-1.0,
		0.1,
		1.125,
		7.875,
		29.999,
		2.2250738585072014e-308,
		4.9406564584124654e-324,
		1.7976931348623157e308,
	]
	for index in range(scalar_samples.size()):
		var sample := scalar_samples[index]
		var source := {"timer": sample}
		var encoded := CODEC.encode_save_state(source)
		var wire: Dictionary = encoded.get("value", {}) if encoded.get("value", {}) is Dictionary else {}
		var parsed: Variant = JSON.parse_string(JSON.stringify(wire))
		var decoded := CODEC.decode_save_state(parsed as Dictionary if parsed is Dictionary else {})
		var decoded_state: Dictionary = decoded.get("value", {}) if decoded.get("value", {}) is Dictionary else {}
		_expect(bool(encoded.get("ok", false)) and WIRE.is_closed_data(wire), "scalar sample %d encodes as closed wire" % index)
		_expect(bool(decoded.get("ok", false)) and SCALAR.f64_bits_hex(float(decoded_state.get("timer"))) == SCALAR.f64_bits_hex(sample), "scalar sample %d preserves F64 bits" % index)
		_expect(CODEC.encode_save_state(decoded_state).get("value") == wire, "scalar sample %d re-encodes canonically" % index)

	var vector_samples := [
		Vector2(12.5, 34.25),
		Vector2(-0.0, 0.0),
		Vector2(4.9406564584124654e-324, -2.2250738585072014e-308),
		Vector2(3.402823466e38, -3.402823466e38),
	]
	for index in range(vector_samples.size()):
		var sample: Vector2 = vector_samples[index]
		var encoded := CODEC.encode_save_state({"position": sample})
		var wire: Dictionary = encoded.get("value", {}) if encoded.get("value", {}) is Dictionary else {}
		var parsed: Variant = JSON.parse_string(JSON.stringify(wire))
		var decoded := CODEC.decode_save_state(parsed as Dictionary if parsed is Dictionary else {})
		var decoded_state: Dictionary = decoded.get("value", {}) if decoded.get("value", {}) is Dictionary else {}
		var restored: Vector2 = decoded_state.get("position", Vector2.ZERO)
		_expect(bool(encoded.get("ok", false)) and WIRE.is_closed_data(wire), "Vector2 sample %d encodes as closed wire" % index)
		_expect(bool(decoded.get("ok", false)) and SCALAR.f64_bits_hex(restored.x) == SCALAR.f64_bits_hex(sample.x) and SCALAR.f64_bits_hex(restored.y) == SCALAR.f64_bits_hex(sample.y), "Vector2 sample %d preserves both component bit patterns" % index)
		_expect(CODEC.encode_save_state(decoded_state).get("value") == wire, "Vector2 sample %d re-encodes canonically" % index)

	var mixed := {
		"safe": 7,
		"unsafe": 9223372036854775807,
		"nested": [{"position": Vector2(3.125, -4.75), "timer": -0.0}, true, "stable"],
	}
	var mixed_encoded := CODEC.encode_save_state(mixed)
	var mixed_wire: Dictionary = mixed_encoded.get("value", {}) if mixed_encoded.get("value", {}) is Dictionary else {}
	var mixed_parsed: Variant = JSON.parse_string(JSON.stringify(mixed_wire))
	var mixed_decoded := CODEC.decode_save_state(mixed_parsed as Dictionary if mixed_parsed is Dictionary else {})
	_expect(bool(mixed_encoded.get("ok", false)) and WIRE.is_closed_data(mixed_wire), "mixed tree closes F64, Vector2, and unsafe Int64")
	_expect(bool(mixed_decoded.get("ok", false)) and int((mixed_decoded.get("value", {}) as Dictionary).get("unsafe", 0)) == 9223372036854775807, "mixed tree restores unsafe Int64 exactly")
	_expect(CODEC.encode_save_state(mixed_decoded.get("value", {}) as Dictionary).get("value") == mixed_wire, "mixed tree JSON roundtrip is canonical")
	var envelope_codec = ENVELOPE_CODEC.new()
	var outer_encoded: Dictionary = envelope_codec.encode_codec_value(mixed_wire)
	var outer_decoded: Dictionary = envelope_codec.decode_codec_value(outer_encoded.get("value"))
	_expect(bool(outer_encoded.get("ok", false)) and bool(outer_decoded.get("ok", false)) and outer_decoded.get("value") == mixed_wire, "Monster tags survive the outer Save Envelope codec without collision")
	envelope_codec.free()

	for rejected in [
		{"value": NAN},
		{"value": INF},
		{"value": Vector2(INF, 0.0)},
		{"value": Color(0.1, 0.2, 0.3, 1.0)},
		{"value": &"string-name"},
		{"value": null},
		{1: "integer-key"},
		{"$codec": "runtime-collision"},
		{"codec": SCALAR.F64_CODEC_ID, "bits": "runtime-collision"},
	]:
		_expect(not bool(CODEC.encode_save_state(rejected).get("ok", false)), "unauthorized runtime shape is rejected")

	var invalid_wire := [
		{"value": 1.25},
		{"value": {"codec": "UnknownV1"}},
		{"value": {"codec": CODEC.VECTOR2_CODEC_ID, "x": SCALAR.encode_f64(1.0).get("value")}},
		{"value": {"codec": CODEC.VECTOR2_CODEC_ID, "x": SCALAR.encode_f64(1.0).get("value"), "y": SCALAR.encode_f64(2.0).get("value"), "extra": true}},
		{"value": {"codec": CODEC.VECTOR2_CODEC_ID, "x": {"codec": SCALAR.F64_CODEC_ID, "bits": "000000000000000A"}, "y": SCALAR.encode_f64(2.0).get("value")}},
		{"value": {"codec": CODEC.INT64_CODEC_ID, "value": "01"}},
		{"value": {"codec": SCALAR.F64_CODEC_ID, "bits": "000000000000000A"}},
	]
	for rejected in invalid_wire:
		_expect(not bool(CODEC.decode_save_state(rejected).get("ok", false)), "malformed or noncanonical wire tag is rejected")

	print("MONSTER_SAVE_WIRE_V2_CODEC_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	if not _failures.is_empty():
		push_error("Monster Save Wire v2 codec failures:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
