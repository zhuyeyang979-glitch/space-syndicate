extends SceneTree

const PROBE := preload("res://scripts/tools/execution_restore_exact_once_probe_v1.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := PROBE.run(self)
	var checks := 0
	var failures: Array[String] = []
	for field in [
		"retryable_commitment_green",
		"retryable_history_green",
		"pending_settlement_green",
		"transition_lineage_green",
		"facility_commitment_retry_green",
	]:
		checks += 1
		if not bool(result.get(field, false)):
			failures.append("%s must be green" % field)
	for field in [
		"duplicate_effect_dispatch_count",
		"duplicate_card_commitment_count",
		"duplicate_history_append_count",
		"duplicate_settlement_count",
		"duplicate_transition_command_apply_count",
	]:
		checks += 1
		if int(result.get(field, -1)) != 0:
			failures.append("%s must be zero" % field)
	checks += 1
	if not bool(result.get("green", false)) or not bool(result.get("private_payload_redacted", false)):
		failures.append("aggregate exact-once evidence must be green and redacted")
	await process_frame
	print("CARD_RESOLUTION_EXECUTION_RESTORE_EXACT_ONCE_PROBE_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if failures.is_empty() else "FAIL",
		checks,
		failures.size(),
	])
	if not failures.is_empty():
		push_error("Execution restore exact-once probe failed:\n- " + "\n- ".join(failures))
	quit(0 if failures.is_empty() else 1)
