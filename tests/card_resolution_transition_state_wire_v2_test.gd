extends SceneTree

const FIXTURE := preload("res://tests/fixtures/card_resolution_execution_save_full_state_fixture.gd")
const SAVE_CODEC := preload("res://scripts/runtime/card_resolution_execution_save_wire_codec_v4.gd")
const SCALAR := preload("res://scripts/runtime/closed_save_scalar_codec_v1.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var source := FIXTURE.create(self)
	var controller := source.get("transition") as CardResolutionRuntimeController
	controller.begin_group_window(-1.0, 0, 3)
	controller.simultaneous_timer = 8.625
	var commands := controller.tick(0.0, _facts())
	for command_variant: Variant in commands:
		if command_variant is Dictionary:
			controller.mark_transition_command_applied(command_variant as Dictionary, {"handled": true})
	controller.begin_active_display(3.125)
	controller.begin_counter(2.375)
	var owner := source.get("execution") as CardResolutionExecutionRuntimeService
	var save_a := owner.to_save_data()
	var decoded_a := SAVE_CODEC.decode_save_state(save_a)
	var raw_a := decoded_a.get("value", {}) as Dictionary
	var transition_a := raw_a.get("transition_controller", {}) as Dictionary
	_expect(bool(decoded_a.get("ok", false)), "non-idle Transition state decodes")
	_expect(int(transition_a.get("transition_state_wire_version", -1)) == 2, "Transition state wire version is 2")
	_expect(int(transition_a.get("card_transition_command_schema_version", -1)) == 1, "Transition command schema remains 1")
	_expect(int(transition_a.get("card_group_cadence_version", -1)) == 2, "cadence contract remains version 2")
	_expect(str(transition_a.get("card_group_window_phase", "")) == "public_bid" \
			and bool(transition_a.get("card_resolution_auction_open", false)), "V0.6 public-bid phase and auction-open state are preserved")
	_expect(_bits(transition_a.get("card_resolution_timer")) == _bits(3.125), "active display timer preserves its exact F64 bits")
	_expect(_bits(transition_a.get("card_resolution_counter_timer")) == _bits(2.375), "counter timer preserves its exact F64 bits")
	_expect(_bits(transition_a.get("card_resolution_simultaneous_timer")) == _bits(8.625), "simultaneous timer preserves its exact F64 bits")
	_expect(_bits(transition_a.get("card_resolution_auction_timer")) == _bits(3.625), "V0.6 auction timer preserves its exact F64 bits")
	var cadence_a := transition_a.get("card_group_cadence", {}) as Dictionary
	_expect(_bits(cadence_a.get("total_seconds")) == _bits(30.0) \
			and _bits(cadence_a.get("planning_seconds")) == _bits(20.0) \
			and _bits(cadence_a.get("public_bid_seconds")) == _bits(5.0) \
			and _bits(cadence_a.get("lock_seconds")) == _bits(5.0), "V0.6 30/20/5/5 cadence is preserved bit-exactly")

	var target := FIXTURE.create(self)
	var target_owner := target.get("execution") as CardResolutionExecutionRuntimeService
	_expect(bool(target_owner.apply_save_data(save_a).get("applied", false)), "strict Transition candidate applies only after full Execution preflight")
	var save_b := target_owner.to_save_data()
	var raw_b := SAVE_CODEC.decode_save_state(save_b).get("value", {}) as Dictionary
	var transition_b := raw_b.get("transition_controller", {}) as Dictionary
	_expect(_transition_bits_equal(transition_a, transition_b), "all timer and cadence fields retain exact bits after restore")
	_expect(transition_a.get("card_transition_applied_lineage") == transition_b.get("card_transition_applied_lineage"), "applied command lineage restores exactly")

	var opening := FIXTURE.create(self)
	var opening_controller := opening.get("transition") as CardResolutionRuntimeController
	opening_controller.begin_group_window(-1.0, 0, 0)
	var opening_save := (opening.get("execution") as CardResolutionExecutionRuntimeService).to_save_data()
	var opening_raw := SAVE_CODEC.decode_save_state(opening_save).get("value", {}) as Dictionary
	var opening_cadence := ((opening_raw.get("transition_controller", {}) as Dictionary).get("card_group_cadence", {}) as Dictionary)
	_expect(_bits(opening_cadence.get("total_seconds")) == _bits(45.0) \
			and _bits(opening_cadence.get("planning_seconds")) == _bits(35.0), "opening V0.6 45/35/5/5 cadence remains distinct")

	var invalid_runtime := raw_a.duplicate(true)
	var invalid_transition := invalid_runtime.get("transition_controller") as Dictionary
	var invalid_cadence := (invalid_transition.get("card_group_cadence") as Dictionary).duplicate(true)
	invalid_cadence["public_bid_seconds"] = 4.5
	invalid_transition["card_group_cadence"] = invalid_cadence
	invalid_runtime["transition_controller"] = invalid_transition
	var invalid_wire := SAVE_CODEC.encode_save_state(invalid_runtime).get("value", {}) as Dictionary
	var before_invalid := target_owner.to_save_data()
	var invalid_apply := target_owner.apply_save_data(invalid_wire)
	_expect(not bool(invalid_apply.get("applied", true)) and target_owner.to_save_data() == before_invalid, "cadence tampering fails before any owner mutation")

	FIXTURE.cleanup(source)
	FIXTURE.cleanup(target)
	FIXTURE.cleanup(opening)
	await process_frame
	print("CARD_RESOLUTION_TRANSITION_STATE_WIRE_V2_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()
	])
	if not _failures.is_empty():
		push_error("Transition state wire v2 failed:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _transition_bits_equal(left: Dictionary, right: Dictionary) -> bool:
	for field_id in [
		"card_resolution_timer",
		"card_resolution_counter_timer",
		"card_resolution_simultaneous_timer",
		"card_resolution_auction_timer",
	]:
		if _bits(left.get(field_id)) != _bits(right.get(field_id)):
			return false
	var left_cadence := left.get("card_group_cadence", {}) as Dictionary
	var right_cadence := right.get("card_group_cadence", {}) as Dictionary
	for field_id in ["total_seconds", "planning_seconds", "public_bid_seconds", "lock_seconds"]:
		if _bits(left_cadence.get(field_id)) != _bits(right_cadence.get(field_id)):
			return false
	return true


func _bits(value: Variant) -> String:
	return SCALAR.f64_bits_hex(float(value)) if value is float else ""


func _facts() -> Dictionary:
	return {
		"queue_empty": false,
		"active_present": false,
		"active_counterable": false,
		"active_id": "",
		"lock_duration": 5.0,
		"public_bid_duration": 5.0,
		"counter_duration": 5.0,
		"active_player_indices": [],
	}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
