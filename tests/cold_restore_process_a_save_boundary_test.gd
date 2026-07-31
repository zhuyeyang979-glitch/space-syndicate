extends SceneTree

const DRIVER := preload("res://scripts/tools/cold_restore_vertical_slice_driver.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var before := _safety_observation()
	var receipt := {
		"operation_id": "save-op-1",
		"world_digest": "world-1",
		"safety_observation": before.duplicate(true),
	}
	var green := DRIVER._evaluate_process_a_quiet_window(
		"save-op-1",
		receipt,
		before.duplicate(true),
		"world-1"
	)
	_expect(bool(green.get("quiet", false)), "exact operation, world, and eleven-field observation is quiet")
	_expect(
		(green.get("quiet_deltas", {}) as Dictionary).size()
			== DRIVER.PROCESS_A_SAVE_QUIET_FIELDS.size(),
		"quiet report covers all eleven authorized fields"
	)

	var operation_mismatch := DRIVER._evaluate_process_a_quiet_window(
		"save-op-other",
		receipt,
		before.duplicate(true),
		"world-1"
	)
	_expect(
		str(operation_mismatch.get("reason_code", ""))
			== "process_a_save_barrier_operation_mismatch",
		"operation mismatch fails closed"
	)

	var world_drift := DRIVER._evaluate_process_a_quiet_window(
		"save-op-1",
		receipt,
		before.duplicate(true),
		"world-2"
	)
	_expect(
		str(world_drift.get("reason_code", "")) == "process_a_save_barrier_world_drift",
		"world digest drift fails closed"
	)

	for field_variant in DRIVER.PROCESS_A_SAVE_QUIET_FIELDS:
		var field := str(field_variant)
		var missing := before.duplicate(true)
		missing.erase(field)
		var missing_report := DRIVER._evaluate_process_a_quiet_window(
			"save-op-1", receipt, missing, "world-1"
		)
		_expect(
			str(missing_report.get("reason_code", ""))
				== "process_a_save_barrier_observation_invalid",
			"missing %s fails closed" % field
		)

		var wrong_type := before.duplicate(true)
		wrong_type[field] = "0"
		var type_report := DRIVER._evaluate_process_a_quiet_window(
			"save-op-1", receipt, wrong_type, "world-1"
		)
		_expect(
			str(type_report.get("reason_code", ""))
				== "process_a_save_barrier_observation_invalid",
			"wrong-typed %s fails closed" % field
		)

		var advanced := before.duplicate(true)
		advanced[field] = int(advanced.get(field)) + 1
		var delta_report := DRIVER._evaluate_process_a_quiet_window(
			"save-op-1", receipt, advanced, "world-1"
		)
		_expect(
			str(delta_report.get("reason_code", ""))
				== "process_a_save_barrier_quiet_window_violated"
				and int((delta_report.get("quiet_deltas", {}) as Dictionary).get(field, 0)) == 1,
			"nonzero %s delta fails closed" % field
		)

	var save_and_cleanup := DRIVER._ordered_process_a_boundary_failures(
		"owner_capture_failed",
		{
			"released": false,
			"reason_code": "process_a_save_barrier_world_drift",
			"secondary_failure_codes": ["process_a_save_manual_lease_release_failed"],
		}
	)
	_expect(
		str(save_and_cleanup.get("primary_failure_code", "")) == "owner_capture_failed",
		"Save failure remains primary when cleanup also fails"
	)
	_expect(
		(save_and_cleanup.get("secondary_failure_codes", []) as Array) == [
			"process_a_save_barrier_world_drift",
			"process_a_save_manual_lease_release_failed",
		],
		"cleanup failures remain ordered secondary evidence"
	)

	var cleanup_only := DRIVER._ordered_process_a_boundary_failures(
		"",
		{
			"released": false,
			"reason_code": "process_a_save_barrier_quiet_window_violated",
			"secondary_failure_codes": [
				"process_a_save_barrier_frame_advanced",
				"process_a_save_manual_lease_release_failed",
			],
		}
	)
	_expect(
		str(cleanup_only.get("primary_failure_code", ""))
			== "process_a_save_barrier_quiet_window_violated",
		"quiet failure precedes later frame and release failures"
	)

	var deduplicated := DRIVER._ordered_process_a_boundary_failures(
		"owner_capture_failed",
		{
			"released": false,
			"reason_code": "owner_capture_failed",
			"secondary_failure_codes": ["owner_capture_failed"],
		}
	)
	_expect(
		str(deduplicated.get("primary_failure_code", "")) == "owner_capture_failed"
			and (deduplicated.get("secondary_failure_codes", []) as Array).is_empty(),
		"same-code boundary failures are deduplicated without replacing primary"
	)

	if _failures.is_empty():
		print("COLD_RESTORE_PROCESS_A_SAVE_BOUNDARY_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	push_error("Process A Save boundary test failed:\n- " + "\n- ".join(_failures))
	quit(1)


func _safety_observation() -> Dictionary:
	var result := {}
	for field_variant in DRIVER.PROCESS_A_SAVE_QUIET_FIELDS:
		result[str(field_variant)] = 10
	return result


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
