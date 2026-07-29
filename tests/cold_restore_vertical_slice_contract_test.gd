extends SceneTree

const DRIVER := preload("res://scripts/tools/cold_restore_vertical_slice_driver.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var contract: Dictionary = DRIVER.contract_snapshot()
	_expect(not bool(contract.get("formal_full_run", true)) and not bool(contract.get("execution_ready", true)), "cold restore skeleton explicitly disables Formal/full-run execution")
	_expect((contract.get("process_sequence", []) as Array) == ["producer_exit", "consumer_start", "orchestrator_compare"], "contract enforces producer exit before consumer start")
	_expect(not bool(contract.get("shares_gameplay_process_memory", true)) and bool(contract.get("runtime_loop_frozen_until_restore_commit", false)), "A/B share no gameplay memory and restore completes before the loop resumes")
	_expect(str(contract.get("qa_save_root", "")) == "user://test_runs/alpha04c/", "driver uses the isolated ALPHA_0_4_C QA root")

	var producer_validation: Dictionary = DRIVER.validate_options({"run_id": "run-42", "process_role": "producer"})
	var consumer_validation: Dictionary = DRIVER.validate_options({"run_id": "run-42", "process_role": "consumer"})
	_expect(bool(producer_validation.get("valid", false)) and bool(consumer_validation.get("valid", false)), "producer and consumer roles accept the same safe run id")
	_expect(not bool(DRIVER.validate_options({"run_id": "../escape", "process_role": "producer"}).get("valid", true)), "unsafe run id fails closed")
	_expect(not bool(DRIVER.validate_options({"run_id": "run-42", "process_role": "combined"}).get("valid", true)), "combined in-process role is forbidden")

	var sanitized: Dictionary = DRIVER.sanitize_public_manifest({
		"run_id": "run-42",
		"process_role": "producer",
		"process_id": 123,
		"head_sha": "51248e6",
		"slot_state": "ready",
		"viewer_safe_state_digest": "public-digest",
		"rng_draw_count": 17,
		"action_receipt_count": 9,
		"duplicate_settlement_count": 0,
		"elapsed_ms": 44,
		"success": true,
		"failure_code": "",
		"path": "user://private.save",
		"envelope": {"sections": {"ai": {"private": true}}},
		"rng_state": 999,
	})
	var serialized := JSON.stringify(sanitized).to_lower()
	_expect(sanitized.size() == DRIVER.PUBLIC_MANIFEST_FIELDS.size(), "QA evidence has one closed allowlist")
	_expect(not serialized.contains("path") and not serialized.contains("envelope") and not serialized.contains("rng_state") and not serialized.contains("private"), "QA evidence strips path, envelope, raw RNG, and private fields")

	var orchestrator_source := FileAccess.get_file_as_string("res://scripts/tools/cold_restore_vertical_slice_orchestrator.ps1")
	_expect(orchestrator_source.contains("$FORMAL_FULL_RUN = $false") and orchestrator_source.contains("$DriverExecutionReady = $false"), "orchestrator is explicitly non-Formal and fail-closed")
	_expect(orchestrator_source.contains("-PassThru -Wait -WindowStyle Hidden") and orchestrator_source.find('Role "producer"') < orchestrator_source.find('Role "consumer"'), "orchestrator waits for hidden Process A before Process B")
	_expect(orchestrator_source.contains("qa_allowlisted_manifests_only") and orchestrator_source.contains("Raw save envelopes are forbidden"), "Process C compares only sanitized manifests")

	if _failures.is_empty():
		print("Cold restore vertical-slice contract test passed (%d checks)." % _checks)
		quit(0)
		return
	push_error("Cold restore vertical-slice contract test failed:\n- " + "\n- ".join(_failures))
	quit(1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
