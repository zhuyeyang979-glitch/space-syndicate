extends SceneTree

const FIXTURE := preload("res://tests/fixtures/card_resolution_execution_save_full_state_fixture.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var source := FIXTURE.create(self)
	var source_controller := source.get("transition") as CardResolutionRuntimeController
	source_controller.begin_group_window(-1.0, 0, 3)
	source_controller.simultaneous_timer = 8.625
	var commands := source_controller.tick(0.0, _facts())
	_expect(not commands.is_empty(), "Transition controller emits a real V0.6 phase command")
	for command_variant: Variant in commands:
		if command_variant is Dictionary:
			var marked := source_controller.mark_transition_command_applied(command_variant as Dictionary, {"handled": true})
			_expect(bool(marked.get("accepted", false)), "source command is committed to applied lineage")
	var source_owner := source.get("execution") as CardResolutionExecutionRuntimeService
	var json_variant: Variant = JSON.parse_string(JSON.stringify(source_owner.to_save_data()))

	var target := FIXTURE.create(self)
	var target_owner := target.get("execution") as CardResolutionExecutionRuntimeService
	var target_controller := target.get("transition") as CardResolutionRuntimeController
	_expect(json_variant is Dictionary and bool(target_owner.apply_save_data(json_variant as Dictionary).get("applied", false)), "applied command lineage restores through Execution Save v4")
	var command := commands[0] as Dictionary
	var restored_status := target_controller.transition_command_applied(
		str(command.get("command_id", "")),
		str(command.get("command_fingerprint", ""))
	)
	_expect(bool(restored_status.get("applied", false)), "restored controller recognizes the command as already applied")
	var before_duplicate := target_controller.transition_lineage_snapshot()
	var duplicate := target_controller.mark_transition_command_applied(command, {"handled": true})
	var after_duplicate := target_controller.transition_lineage_snapshot()
	_expect(not bool(duplicate.get("accepted", true)) \
			and bool(duplicate.get("exact_once", false)) \
			and str(duplicate.get("reason", "")) == "duplicate_command", "duplicate command receives the exact-once rejection")
	_expect(before_duplicate == after_duplicate, "duplicate command causes zero applied-lineage or handler mutation")

	FIXTURE.cleanup(source)
	FIXTURE.cleanup(target)
	await process_frame
	print("CARD_RESOLUTION_EXECUTION_TRANSITION_LINEAGE_EXACT_ONCE_TEST|status=%s|checks=%d|failures=%d|duplicate_transition_command_apply=0" % [
		"PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()
	])
	if not _failures.is_empty():
		push_error("Transition lineage exact-once failed:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


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
