extends SceneTree

const CODEC := preload("res://scripts/runtime/closed_save_scalar_codec_v1.gd")


func _init() -> void:
	var failures: Array[String] = []
	for value in [0.0, -0.0, 3.125, 8.625, 30.0, -42.75, 1.0e-300, 1.0e300]:
		var encoded := CODEC.encode_f64(value)
		var decoded := CODEC.decode_f64(encoded.get("value"))
		if not bool(encoded.get("ok", false)) \
				or not bool(decoded.get("ok", false)) \
				or CODEC.f64_bits_hex(float(decoded.get("value", 0.0))) != CODEC.f64_bits_hex(value):
			failures.append("f64 bit roundtrip failed")
	var rejected := CODEC.encode_f64(INF)
	if bool(rejected.get("ok", true)):
		failures.append("nonfinite value must fail closed")
	print("CLOSED_SAVE_SCALAR_CODEC_V1_REGRESSION_TEST|status=%s|checks=9|failures=%d" % [
		"PASS" if failures.is_empty() else "FAIL",
		failures.size(),
	])
	if not failures.is_empty():
		push_error("Closed Save scalar codec regression failed")
	quit(0 if failures.is_empty() else 1)
