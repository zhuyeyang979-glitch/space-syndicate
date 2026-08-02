extends SceneTree

const CODEC := preload("res://scripts/runtime/closed_save_scalar_codec_v1.gd")
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var samples: Array[float] = [
		0.0, -0.0, 1.0, -1.0, 0.1, 0.5, 1.5, 3.0, 29.999, 30.0,
		2.2250738585072014e-308,
		4.9406564584124654e-324,
		1.7976931348623157e308,
		7.875,
		1.125,
	]
	for sample in samples:
		var encoded := CODEC.encode_f64(sample)
		var tag := encoded.get("value", {}) as Dictionary
		var parsed: Variant = JSON.parse_string(JSON.stringify(tag))
		var decoded := CODEC.decode_f64(parsed)
		var reencoded := CODEC.encode_f64(decoded.get("value"))
		_expect(bool(encoded.get("ok", false)) and WIRE.is_closed_data(tag), "F64 tag is closed for %s" % str(sample))
		_expect(bool(decoded.get("ok", false)) and reencoded.get("value") == tag, "F64 JSON roundtrip preserves bits for %s" % str(sample))
	var positive_zero := CODEC.encode_f64(0.0).get("value", {}) as Dictionary
	var decoded_negative_zero := CODEC.decode_f64_bits_hex("8000000000000000")
	var negative_zero := CODEC.encode_f64(decoded_negative_zero.get("value")).get("value", {}) as Dictionary
	_expect(positive_zero.get("bits") != negative_zero.get("bits"), "positive and negative zero remain bit-distinct")
	for rejected in [NAN, INF, -INF]:
		_expect(str(CODEC.encode_f64(rejected).get("reason_code", "")) == "f64_nonfinite_rejected", "nonfinite F64 encode is rejected")
	var invalid_tags := [
		{"codec": CODEC.F64_CODEC_ID},
		{"codec": CODEC.F64_CODEC_ID, "bits": "000000000000000G"},
		{"codec": CODEC.F64_CODEC_ID, "bits": "000000000000000A"},
		{"codec": CODEC.F64_CODEC_ID, "bits": "0000"},
		{"codec": CODEC.F64_CODEC_ID, "bits": "0000000000000000", "extra": true},
	]
	for invalid in invalid_tags:
		_expect(not bool(CODEC.decode_f64(invalid).get("ok", false)), "malformed F64 tag is rejected")
	var tree := {
		"timer": -0.0,
		"growth": 1.125,
		"cursor": 9223372036854775807,
		"nested": [0.1, true, "stable"],
	}
	var encoded_tree := CODEC.encode_tree(tree)
	var wire: Variant = encoded_tree.get("value", {})
	var parsed_tree: Variant = JSON.parse_string(JSON.stringify(wire))
	var decoded_tree := CODEC.decode_tree(parsed_tree)
	var reencoded_tree := CODEC.encode_tree(decoded_tree.get("value"))
	_expect(bool(encoded_tree.get("ok", false)) and WIRE.is_closed_data(wire), "recursive codec closes floats and unsafe Int64")
	_expect(bool(decoded_tree.get("ok", false)) and reencoded_tree.get("value") == wire, "recursive codec roundtrip is canonical")
	_expect(str(CODEC.decode_tree({"raw": 1.25}).get("reason_code", "")) == "closed_save_raw_float_rejected", "recursive decoder rejects raw float")
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("CLOSED_SAVE_SCALAR_CODEC_V1_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	if not _failures.is_empty():
		push_error("Closed Save scalar codec failures:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)
