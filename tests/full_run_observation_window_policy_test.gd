extends SceneTree

const DriverScript := preload("res://scripts/tools/full_run_quality_driver.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var pending := {
		"id": "district_supply_preview_card",
		"phase": "play.supply.preview.unit.monster.oasis_repairer.rank_1",
		"requested_msec": 44_990,
	}
	_expect(
		DriverScript.observation_action_policy(0, 45_000, 44_999, {}) == DriverScript.OBSERVATION_ACTION_OPEN,
		"a clear frame before the deadline may admit the next visible action"
	)
	_expect(
		DriverScript.observation_action_policy(0, 45_000, 44_999, pending) == DriverScript.OBSERVATION_ACTION_OPEN,
		"an already pending action remains under the ordinary progress policy before the deadline"
	)
	_expect(
		DriverScript.observation_action_policy(0, 45_000, 45_000, {}) == DriverScript.OBSERVATION_ACTION_CLOSED,
		"the exact deadline closes new action admission"
	)
	_expect(
		DriverScript.observation_action_policy(0, 45_000, 55_674, {}) == DriverScript.OBSERVATION_ACTION_CLOSED,
		"a coarse frame that overshoots the deadline cannot submit a fresh action"
	)
	_expect(
		DriverScript.observation_action_policy(0, 45_000, 45_000, pending) == DriverScript.OBSERVATION_ACTION_DRAIN,
		"an action accepted before the deadline may drain through the existing bounded progress check"
	)
	_expect(
		DriverScript.observation_action_policy(10_000, 45_000, 55_000, pending) == DriverScript.OBSERVATION_ACTION_DRAIN,
		"the policy uses the observation start rather than absolute process uptime"
	)
	_expect(
		DriverScript.observation_action_policy(10_000, 45_000, 55_000, {}) == DriverScript.OBSERVATION_ACTION_CLOSED,
		"once the pending action clears, the same closed frame cannot admit another action"
	)
	_expect(
		DriverScript.observation_action_policy(0, -1, 0, {}) == DriverScript.OBSERVATION_ACTION_CLOSED,
		"invalid negative observation limits fail closed"
	)
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	printerr("FAIL: %s" % message)


func _finish() -> void:
	print("Full-run observation-window policy checks: %d" % _checks)
	if _failures.is_empty():
		print("FULL_RUN_OBSERVATION_WINDOW_POLICY_TEST_COMPLETE")
		quit(0)
		return
	printerr("Full-run observation-window policy failures: %s" % ", ".join(_failures))
	quit(1)
