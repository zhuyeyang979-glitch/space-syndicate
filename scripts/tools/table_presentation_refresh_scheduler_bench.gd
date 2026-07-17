extends Node

var _checks := 0
var _failures: Array[String] = []


func _ready() -> void:
	var coordinator := get_node("GameRuntimeCoordinator") as GameRuntimeCoordinator
	_check(coordinator != null, "production coordinator is present")
	var initial := coordinator.advance_presentation_refresh_cadence(0.0, false)
	_check(initial.get("due", []) == [&"live", &"map", &"full"], "initial ordered table cadence")
	coordinator.reset_presentation_refresh_cadence()
	_check((coordinator.advance_presentation_refresh_cadence(0.10, false).get("due", []) as Array).is_empty(), "no premature cadence")
	_check(coordinator.advance_presentation_refresh_cadence(0.06, false).get("due", []) == [&"map"], "map cadence uses real time")
	_check(coordinator.advance_presentation_refresh_cadence(0.02, false).get("due", []) == [&"live"], "live cadence uses real time")
	coordinator.request_immediate_presentation_refresh(&"developer")
	_check(not (coordinator.advance_presentation_refresh_cadence(0.0, false).get("due", []) as Array).has(&"developer"), "hidden developer cadence remains frozen")
	_check((coordinator.advance_presentation_refresh_cadence(0.0, true).get("due", []) as Array).has(&"developer"), "visible developer cadence resumes")
	if _failures.is_empty():
		print("TablePresentationRefreshSchedulerBench: PASS %d/%d" % [_checks, _checks])
	else:
		for failure in _failures:
			push_error(failure)
		print("TablePresentationRefreshSchedulerBench: FAIL %d/%d" % [_checks - _failures.size(), _checks])
	await get_tree().create_timer(2.0).timeout
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
