extends SceneTree

const FIXTURE := preload("res://tests/fixtures/card_resolution_execution_save_full_state_fixture.gd")
const SAVE_CODEC := preload("res://scripts/runtime/card_resolution_execution_save_wire_codec_v4.gd")
const SCALAR_CODEC := preload("res://scripts/runtime/closed_save_scalar_codec_v1.gd")
const SEMANTIC_WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const INSPECTOR := preload("res://scripts/tools/card_resolution_execution_full_state_inspector_v1.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var source := FIXTURE.create(self)
	var source_result := FIXTURE.build_nontrivial_state(source)
	_expect(bool(source_result.get("ok", false)), "nontrivial source state is constructed through Execution APIs")
	var save_a := source_result.get("save", {}) as Dictionary
	_expect(SEMANTIC_WIRE.is_closed_data(save_a), "Save A is strict closed data")
	var report_a := INSPECTOR.inspect(save_a)
	_expect(int(report_a.get("non_closed_leaf_count", -1)) == 0, "Save A contains no raw float, null, or non-string key")
	var json_text := JSON.stringify(save_a)
	var parsed_variant: Variant = JSON.parse_string(json_text)
	_expect(parsed_variant is Dictionary, "Save A survives JSON encode/decode as a Dictionary")
	var json_save := parsed_variant as Dictionary if parsed_variant is Dictionary else {}
	var source_decode := SAVE_CODEC.decode_save_state(save_a)
	var json_decode := SAVE_CODEC.decode_save_state(json_save)
	_expect(bool(source_decode.get("ok", false)) and bool(json_decode.get("ok", false)), "both direct and JSON wires decode canonically")

	var target := FIXTURE.create(self)
	var target_owner := target.get("execution") as CardResolutionExecutionRuntimeService
	var preflight := target_owner.preflight_save_data(json_save)
	_expect(bool(preflight.get("accepted", false)), "JSON wire passes strict decode-before-mutation preflight")
	var applied := target_owner.apply_save_data(json_save)
	_expect(bool(applied.get("applied", false)), "JSON wire applies to an isolated equivalent owner")
	var save_b := target_owner.to_save_data()
	_expect(save_b == save_a and save_b == json_save, "Save A equals Save B after JSON roundtrip")
	_expect(str(save_a.get("execution_wire_fingerprint", "")) == str(save_b.get("execution_wire_fingerprint", "")), "Execution wire fingerprint has exact parity")

	var raw_a := source_decode.get("value", {}) as Dictionary
	var raw_b_decode := SAVE_CODEC.decode_save_state(save_b)
	var raw_b := raw_b_decode.get("value", {}) as Dictionary
	_expect(raw_a.get("inflight_execution_transactions") == raw_b.get("inflight_execution_transactions"), "inflight transaction tree restores exactly")
	_expect(raw_a.get("pending_settlements") == raw_b.get("pending_settlements"), "pending settlement tree restores exactly")
	_expect(int(raw_a.get("transaction_sequence", -1)) == int(raw_b.get("transaction_sequence", -2)), "transaction sequence restores exactly")
	var transition_a := raw_a.get("transition_controller", {}) as Dictionary
	var transition_b := raw_b.get("transition_controller", {}) as Dictionary
	_expect(transition_a.get("card_transition_applied_lineage") == transition_b.get("card_transition_applied_lineage"), "transition command lineage restores exactly")
	_expect(_timer_bits_equal(transition_a, transition_b), "all four runtime timer bit patterns restore exactly")
	_expect(_cadence_bits_equal(transition_a, transition_b), "all four cadence bit patterns restore exactly")

	FIXTURE.cleanup(source)
	FIXTURE.cleanup(target)
	await process_frame
	print("CARD_RESOLUTION_EXECUTION_NONTRIVIAL_ROUNDTRIP_TEST|status=%s|checks=%d|failures=%d|inflight=%d|pending=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
		(raw_a.get("inflight_execution_transactions", []) as Array).size(),
		(raw_a.get("pending_settlements", []) as Array).size(),
	])
	if not _failures.is_empty():
		push_error("Execution nontrivial roundtrip failed:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _timer_bits_equal(left: Dictionary, right: Dictionary) -> bool:
	for field_id in [
		"card_resolution_timer",
		"card_resolution_counter_timer",
		"card_resolution_simultaneous_timer",
		"card_resolution_auction_timer",
	]:
		if not _f64_bits_equal(left.get(field_id), right.get(field_id)):
			return false
	return true


func _cadence_bits_equal(left: Dictionary, right: Dictionary) -> bool:
	var left_cadence := left.get("card_group_cadence", {}) as Dictionary
	var right_cadence := right.get("card_group_cadence", {}) as Dictionary
	for field_id in ["total_seconds", "planning_seconds", "public_bid_seconds", "lock_seconds"]:
		if not _f64_bits_equal(left_cadence.get(field_id), right_cadence.get(field_id)):
			return false
	return true


func _f64_bits_equal(left: Variant, right: Variant) -> bool:
	return left is float and right is float \
			and SCALAR_CODEC.f64_bits_hex(float(left)) == SCALAR_CODEC.f64_bits_hex(float(right))


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
