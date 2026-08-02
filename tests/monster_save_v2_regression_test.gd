extends SceneTree

const FIXTURE := preload("res://tests/fixtures/monster_save_full_state_fixture.gd")
const CODEC := preload("res://scripts/runtime/monster_save_wire_codec_v2.gd")
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var source := FIXTURE.create(self)
	var rich := FIXTURE.build_nontrivial_state(source)
	var save_a := rich.get("save", {}) as Dictionary
	var parsed: Variant = JSON.parse_string(JSON.stringify(save_a))
	var target := FIXTURE.create(self)
	var target_owner: Node = target.get("owner")
	var applied: Dictionary = target_owner.call(
		"apply_save_data",
		parsed as Dictionary if parsed is Dictionary else {}
	)
	var save_b: Dictionary = target_owner.call("to_save_data")
	var decoded := CODEC.decode_save_state(save_b)
	var runtime := decoded.get("value", {}) as Dictionary
	var green := bool(rich.get("ok", false)) \
			and WIRE.is_closed_data(save_a) \
			and bool(applied.get("applied", false)) \
			and save_a == save_b \
			and bool(decoded.get("ok", false)) \
			and int(runtime.get("monster_save_schema_version", -1)) == 2
	FIXTURE.cleanup(source)
	FIXTURE.cleanup(target)
	await process_frame
	print("MONSTER_SAVE_V2_REGRESSION_TEST|status=%s|checks=6|failures=%d" % [
		"PASS" if green else "FAIL",
		0 if green else 1,
	])
	if not green:
		push_error("Monster Save v2 regression failed")
	quit(0 if green else 1)
