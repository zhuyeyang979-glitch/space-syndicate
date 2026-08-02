extends SceneTree

const FIXTURE := preload("res://tests/fixtures/card_resolution_execution_save_full_state_fixture.gd")
const CODEC := preload("res://scripts/runtime/card_resolution_execution_save_wire_codec_v4.gd")
const SCALAR := preload("res://scripts/runtime/closed_save_scalar_codec_v1.gd")
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const INSPECTOR := preload("res://scripts/tools/card_resolution_execution_full_state_inspector_v1.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture := FIXTURE.create(self)
	var result := FIXTURE.build_nontrivial_state(fixture)
	var wire := result.get("save", {}) as Dictionary
	var decoded := CODEC.decode_save_state(wire)
	_expect(bool(result.get("ok", false)) and bool(decoded.get("ok", false)), "nontrivial runtime tree encodes and decodes")
	var runtime := decoded.get("value", {}) as Dictionary
	_expect(int(runtime.get("schema_version", -1)) == 4 and int(runtime.get("execution_wire_version", -1)) == 1, "logical v4 and wire v1 versions survive tagged transport")
	_expect(int((runtime.get("transition_controller", {}) as Dictionary).get("transition_state_wire_version", -1)) == 2, "nested Transition state wire v2 is explicit")
	_expect(WIRE.is_closed_data(wire) and int(INSPECTOR.inspect(wire).get("non_closed_leaf_count", -1)) == 0, "encoded tree is strict SemanticWire closed data")
	_expect(_count_codec(wire, SCALAR.F64_CODEC_ID) > 8, "F64 codec covers nested transaction values beyond the idle timers")
	_expect(_count_codec(wire, CODEC.NULL_CODEC_ID) > 0, "characterized null values use explicit NullV1 tags")
	_expect(_count_codec(wire, CODEC.INT64_CODEC_ID) > 0, "integers use a JSON type-stable transport tag")
	var json_variant: Variant = JSON.parse_string(JSON.stringify(wire))
	_expect(json_variant is Dictionary and CODEC.decode_save_state(json_variant as Dictionary).get("value") == runtime, "JSON roundtrip preserves every decoded Variant type")

	var transition_wire := wire.get("transition_controller", {}) as Dictionary
	var timer_tag := transition_wire.get("card_resolution_timer", {}) as Dictionary
	_expect(str(timer_tag.get("codec", "")) == SCALAR.F64_CODEC_ID \
			and str(timer_tag.get("bits", "")).length() == 16 \
			and str(timer_tag.get("bits", "")) == str(timer_tag.get("bits", "")).to_lower(), "F64 tag uses canonical lowercase 16-hex bits")

	var malformed_bits := wire.duplicate(true)
	var malformed_transition := malformed_bits.get("transition_controller") as Dictionary
	var malformed_timer := (malformed_transition.get("card_resolution_timer") as Dictionary).duplicate(true)
	malformed_timer["bits"] = "000000000000000A"
	malformed_transition["card_resolution_timer"] = malformed_timer
	malformed_bits["transition_controller"] = malformed_transition
	_reseal(malformed_bits)
	_expect(not bool(CODEC.decode_save_state(malformed_bits).get("ok", true)), "uppercase F64 bits fail closed")

	var extra_tag_field := wire.duplicate(true)
	var extra_transition := extra_tag_field.get("transition_controller") as Dictionary
	var extra_timer := (extra_transition.get("card_resolution_counter_timer") as Dictionary).duplicate(true)
	extra_timer["extra"] = true
	extra_transition["card_resolution_counter_timer"] = extra_timer
	extra_tag_field["transition_controller"] = extra_transition
	_reseal(extra_tag_field)
	_expect(not bool(CODEC.decode_save_state(extra_tag_field).get("ok", true)), "F64 tags reject extra fields")

	var unknown_tag := wire.duplicate(true)
	var unknown_transition := unknown_tag.get("transition_controller") as Dictionary
	unknown_transition["card_resolution_timer"] = {"codec": "UnknownExecutionCodecV1"}
	unknown_tag["transition_controller"] = unknown_transition
	_reseal(unknown_tag)
	_expect(not bool(CODEC.decode_save_state(unknown_tag).get("ok", true)), "unknown domain tags fail closed")

	var raw_float := wire.duplicate(true)
	(raw_float.get("transition_controller") as Dictionary)["card_resolution_timer"] = 1.25
	_expect(not bool(CODEC.decode_save_state(raw_float).get("ok", true)), "raw floats are never accepted on the v4 wire")
	var raw_null := wire.duplicate(true)
	(raw_null.get("transition_controller") as Dictionary)["card_resolution_timer"] = null
	_expect(not bool(CODEC.decode_save_state(raw_null).get("ok", true)), "raw null is never accepted on the v4 wire")
	var raw_integer := wire.duplicate(true)
	raw_integer["schema_version"] = 4
	_reseal(raw_integer)
	_expect(not bool(CODEC.decode_save_state(raw_integer).get("ok", true)), "untagged integers cannot lose their Variant type through JSON")
	var bad_fingerprint := wire.duplicate(true)
	bad_fingerprint["execution_wire_fingerprint"] = "0".repeat(64)
	_expect(not bool(CODEC.decode_save_state(bad_fingerprint).get("ok", true)), "wire fingerprint mismatch fails closed")

	for forbidden_case in [
		{"value": Vector2(1.0, 2.0), "reason": "execution_save_v4_vector2_not_authorized"},
		{"value": Color(0.1, 0.2, 0.3, 1.0), "reason": "execution_save_v4_color_not_authorized"},
		{"value": StringName("runtime-name"), "reason": "execution_save_v4_string_name_not_authorized"},
	]:
		var forbidden_runtime := runtime.duplicate(true)
		(forbidden_runtime.get("transition_controller") as Dictionary)["characterization_probe"] = forbidden_case.get("value")
		var forbidden_result := CODEC.encode_save_state(forbidden_runtime)
		_expect(not bool(forbidden_result.get("ok", true)) \
				and str(forbidden_result.get("reason_code", "")) == str(forbidden_case.get("reason", "")), "unauthorized composite Variant is rejected")

	FIXTURE.cleanup(fixture)
	await process_frame
	print("CARD_RESOLUTION_EXECUTION_SAVE_WIRE_V4_CODEC_TEST|status=%s|checks=%d|failures=%d|f64_tags=%d|null_tags=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
		_count_codec(wire, SCALAR.F64_CODEC_ID),
		_count_codec(wire, CODEC.NULL_CODEC_ID),
	])
	if not _failures.is_empty():
		push_error("Execution Save Wire v4 codec failed:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _reseal(value: Dictionary) -> void:
	value["execution_wire_fingerprint"] = WIRE.fingerprint(value, "execution_wire_fingerprint")


func _count_codec(value: Variant, codec_id: String) -> int:
	if value is Array:
		var total := 0
		for child_variant: Variant in value as Array:
			total += _count_codec(child_variant, codec_id)
		return total
	if value is Dictionary:
		var source := value as Dictionary
		var total := 1 if str(source.get("codec", "")) == codec_id else 0
		for child_variant: Variant in source.values():
			total += _count_codec(child_variant, codec_id)
		return total
	return 0


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
