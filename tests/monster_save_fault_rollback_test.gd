extends SceneTree

const FIXTURE := preload("res://tests/fixtures/monster_save_full_state_fixture.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture := FIXTURE.create(self)
	var owner = fixture.get("owner")
	var built := FIXTURE.build_nontrivial_state(fixture)
	_expect(bool(built.get("ok", false)), "fault rollback fixture is nontrivial")
	var checkpoint_a: Dictionary = owner.call("to_save_data")

	var alternate_fixture := FIXTURE.create(self)
	var alternate_owner = alternate_fixture.get("owner")
	var alternate_save: Dictionary = alternate_owner.call("to_save_data")
	var touched: Dictionary = owner.call("apply_save_data", alternate_save)
	var touched_state: Dictionary = owner.call("to_save_data")
	_expect(bool(touched.get("applied", false)) and touched_state != checkpoint_a, "registry transaction touches Monster state before a later fault")

	var corrupt := checkpoint_a.duplicate(true)
	corrupt["unattested_fault_field"] = true
	var rejected: Dictionary = owner.call("apply_save_data", corrupt)
	var after_rejection: Dictionary = owner.call("to_save_data")
	_expect(not bool(rejected.get("applied", true)) and after_rejection == touched_state, "faulting payload causes zero partial Monster mutation")

	var rollback: Dictionary = owner.call("apply_save_data", checkpoint_a)
	var checkpoint_b: Dictionary = owner.call("to_save_data")
	_expect(bool(rollback.get("applied", false)) and checkpoint_a == checkpoint_b, "registry-managed rollback restores the exact pre-transaction checkpoint")

	FIXTURE.cleanup(fixture)
	FIXTURE.cleanup(alternate_fixture)
	await process_frame
	print("MONSTER_SAVE_FAULT_ROLLBACK_TEST|status=%s|checks=%d|failures=%d|registry_fault_rollback_green=%s|partial_mutation_count=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
		str(checkpoint_a == checkpoint_b).to_lower(),
		0 if after_rejection == touched_state else 1,
	])
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)
