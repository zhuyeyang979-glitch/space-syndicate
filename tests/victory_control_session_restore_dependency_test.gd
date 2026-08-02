extends SceneTree

const FIXTURE := preload("res://tests/victory_control_save_v3_fixture.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var resolved_owner: Node = FIXTURE.controller(self)
	_expect(resolved_owner != null, "resolved Victory fixture configures")
	if resolved_owner != null:
		var resolved_save: Dictionary = FIXTURE.resolved(resolved_owner)
		var outcome: Dictionary = FIXTURE.payload(resolved_save).get("outcome_receipt", {}) as Dictionary
		_expect(not outcome.is_empty(), "resolved Victory fixture has an authoritative outcome")
		_expect_dependency(
			resolved_owner,
			resolved_save,
			_session_sections("running", {}),
			false,
			"victory_session_outcome_dependency_mismatch",
			"resolved Victory rejects a running Session"
		)
		_expect_dependency(
			resolved_owner,
			resolved_save,
			_session_sections("finished", outcome),
			true,
			"victory_session_dependency_valid",
			"resolved Victory accepts the matching finished Session"
		)
		resolved_owner.queue_free()

	var nonresolved_owner: Node = FIXTURE.controller(self)
	_expect(nonresolved_owner != null, "nonresolved Victory fixture configures")
	if nonresolved_owner != null:
		var nonresolved_save: Dictionary = FIXTURE.qualification(nonresolved_owner)
		var finished_outcome := {
			"outcome_id": "victory.v06.cross-section.fixture",
		}
		_expect_dependency(
			nonresolved_owner,
			nonresolved_save,
			_session_sections("finished", finished_outcome),
			false,
			"victory_session_outcome_state_mismatch",
			"nonresolved Victory rejects a finished Session"
		)
		nonresolved_owner.queue_free()
	_finish()


func _session_sections(session_state: String, outcome: Dictionary) -> Dictionary:
	return {
		"session": {
			"game_session_runtime": {
				"session_state": session_state,
				"outcome_receipt": outcome.duplicate(true),
			}
		}
	}


func _expect_dependency(
	owner: Node,
	owner_state: Dictionary,
	all_sections: Dictionary,
	expected_accepted: bool,
	expected_reason: String,
	message: String
) -> void:
	var before_save: Dictionary = owner.call("to_save_data")
	var before_debug: Dictionary = owner.call("debug_snapshot")
	var result: Dictionary = owner.call(
		"preflight_restore_dependencies",
		owner_state.duplicate(true),
		all_sections.duplicate(true)
	)
	_expect(
		bool(result.get("accepted", not expected_accepted)) == expected_accepted
			and str(result.get("reason_code", "")) == expected_reason
			and owner.call("to_save_data") == before_save
			and owner.call("debug_snapshot") == before_debug,
		message
	)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	var passed := _failures.is_empty()
	print("VICTORY_SESSION_RESTORE_DEPENDENCY_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if passed else "FAIL",
		_checks,
		_failures.size(),
	])
	if not passed:
		push_error("Victory/Session dependency failures: %s" % JSON.stringify(_failures))
	quit(0 if passed else 1)
