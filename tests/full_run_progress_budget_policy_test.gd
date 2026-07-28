extends SceneTree

const DriverScript := preload("res://scripts/tools/full_run_quality_driver.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var within_base := DriverScript.authoritative_progress_budget_decision(120, 40, 120.0)
	_expect(bool(within_base.get("allowed", false)) and not bool(within_base.get("extension_active", true)), "the base budget remains available while deterministic progress is recent")
	var leased_extension := DriverScript.authoritative_progress_budget_decision(360, 300, 360.0)
	_expect(bool(leased_extension.get("allowed", false)) and bool(leased_extension.get("extension_active", false)) and str(leased_extension.get("reason_id", "")) == "progress_extension", "recent progress leases the bounded extension at the base boundary")
	var before_stall := DriverScript.authoritative_progress_budget_decision(109, 20, 109.0)
	var at_stall := DriverScript.authoritative_progress_budget_decision(110, 20, 110.0)
	_expect(bool(before_stall.get("allowed", false)) and not bool(at_stall.get("allowed", true)) and str(at_stall.get("reason_id", "")) == "authoritative_runtime_progress_stalled", "89 steps remain legal and the exact 90-step stall boundary fails early")
	var same_step_later_world := DriverScript.authoritative_progress_budget_decision(110, 20, 200.0)
	_expect(str(same_step_later_world.get("reason_id", "")) == "authoritative_runtime_progress_stalled", "world-time passage alone cannot renew the deterministic progress lease")
	var hard_step_cap := DriverScript.authoritative_progress_budget_decision(480, 479, 400.0)
	_expect(not bool(hard_step_cap.get("allowed", true)) and str(hard_step_cap.get("reason_id", "")) == "authoritative_runtime_max_step_budget_exhausted", "the maximum authoritative step budget is unconditional")
	var world_cap := DriverScript.authoritative_progress_budget_decision(300, 299, 420.0)
	_expect(not bool(world_cap.get("allowed", true)) and str(world_cap.get("reason_id", "")) == "authoritative_world_time_budget_exhausted", "world-effective time has an independent hard cap")
	_expect(DriverScript.monotonic_progress_advanced(10, 11), "a new monotonic Sale Receipt revision or high-water fact counts as progress")
	_expect(not DriverScript.monotonic_progress_advanced(10, 10) and not DriverScript.monotonic_progress_advanced(10, 9), "duplicate and stale receipts or a rolling GDP decline never renew the lease")
	var timer_previous := {"world_effective_us": 10_000_000, "audit_remaining_us": 120_000_000}
	var timer_progressed := {"world_effective_us": 11_000_000, "audit_remaining_us": 119_000_000}
	var timer_frozen := {"world_effective_us": 12_000_000, "audit_remaining_us": 119_000_000}
	_expect(DriverScript.terminal_timer_sample_progressed(timer_previous, timer_progressed, "audit_remaining_us"), "a one-second authoritative audit countdown is deterministic progress")
	_expect(not DriverScript.terminal_timer_sample_progressed(timer_progressed, timer_frozen, "audit_remaining_us"), "world advancement without terminal countdown advancement is a timer stall")
	_expect(DriverScript.AUTHORITATIVE_WAIT_STEP_SECONDS == 1.0 and DriverScript.AUTHORITATIVE_WAIT_STEPS_PER_RENDER_FRAME == 1, "progress policy preserves one authoritative second per unbatched frame")
	_finish()


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	for failure in _failures:
		push_error("FULL_RUN_PROGRESS_BUDGET_POLICY: %s" % failure)
	print("FULL_RUN_PROGRESS_BUDGET_POLICY|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	quit(_failures.size())
