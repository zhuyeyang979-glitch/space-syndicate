extends SceneTree

const FIXTURE := preload("res://tests/fixtures/card_resolution_execution_save_full_state_fixture.gd")
const CODEC := preload("res://scripts/runtime/card_resolution_execution_save_wire_codec_v4.gd")
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var source := FIXTURE.create(self)
	var rich := FIXTURE.build_nontrivial_state(source)
	var save_a := rich.get("save", {}) as Dictionary
	var parsed: Variant = JSON.parse_string(JSON.stringify(save_a))
	var target := FIXTURE.create(self)
	var owner := target.get("execution") as CardResolutionExecutionRuntimeService
	var applied := owner.apply_save_data(parsed as Dictionary if parsed is Dictionary else {})
	var save_b := owner.to_save_data()
	var decoded := CODEC.decode_save_state(save_b)
	var runtime := decoded.get("value", {}) as Dictionary
	if not bool(rich.get("ok", false)) or not WIRE.is_closed_data(save_a):
		failures.append("nontrivial Save v4 must be strict closed data")
	if not bool(applied.get("applied", false)) or save_a != save_b:
		failures.append("nontrivial Save v4 must restore and recapture exactly")
	if not bool(decoded.get("ok", false)) \
			or int(runtime.get("schema_version", -1)) != 4 \
			or int((runtime.get("transition_controller", {}) as Dictionary).get("transition_state_wire_version", -1)) != 2:
		failures.append("Execution v4 and Transition wire v2 identities must remain fixed")
	FIXTURE.cleanup(source)
	FIXTURE.cleanup(target)
	await process_frame
	print("CARD_RESOLUTION_EXECUTION_SAVE_V4_REGRESSION_TEST|status=%s|checks=3|failures=%d" % [
		"PASS" if failures.is_empty() else "FAIL",
		failures.size(),
	])
	if not failures.is_empty():
		push_error("Execution Save v4 regression failed:\n- " + "\n- ".join(failures))
	quit(0 if failures.is_empty() else 1)
