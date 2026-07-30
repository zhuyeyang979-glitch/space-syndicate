extends SceneTree

const ATTESTATION := preload("res://scripts/tools/cold_restore_child_completion_attestation.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var run_id := "child-attestation-%d" % Time.get_ticks_msec()
	var source := {
		"run_id": run_id,
		"role": "qualification",
		"repository_head": "d".repeat(40),
		"scenario_fingerprint": "a".repeat(64),
		"official": false,
		"formal": false,
		"qualification_completed": true,
		"qualification_green": true,
		"product_blocker": "",
		"queue_count": 1,
		"queue_revision": 2,
		"queue_trigger_actor": "local",
		"queue_trigger_semantic_action_id": "card.play",
		"queue_trigger_card_semantic_id": "fixture.card",
		"queue_trigger_target_fingerprint": "b".repeat(64),
		"save_written": false,
		"official_count_consumed": false,
		"product_mutation_count": 0,
		"direct_authority_mutation_count": 0,
		"queue_injection_count": 0,
		"final_reason_code": "qualification_green",
		"child_ready_to_exit": true,
	}
	var sealed := ATTESTATION.build(source)
	_expect(sealed.size() == ATTESTATION.FIELDS.size(), "ChildCompletionAttestationV1 is closed")
	_expect(bool(ATTESTATION.validation_report(sealed).get("valid", false)), "sealed green attestation validates")
	var write := ATTESTATION.write_completion(sealed)
	_expect(bool(write.get("valid", false)), "completion is atomically written and read back: %s" % JSON.stringify(write))
	var result_write := ATTESTATION.write_result(run_id, "qualification", {
		"qualification_green": true,
		"queue_count": 1,
	})
	_expect(bool(result_write.get("valid", false)), "closed qualification result is atomically written: %s" % JSON.stringify(result_write))
	var duplicate := ATTESTATION.write_completion(sealed)
	_expect(not bool(duplicate.get("valid", true)) and str(duplicate.get("reason_code", "")) == "child_evidence_collision", "duplicate final attestation fails closed")
	var mutated := sealed.duplicate(true)
	mutated["queue_count"] = 2
	_expect(str(ATTESTATION.validation_report(mutated).get("reason_code", "")) == "child_attestation_fingerprint_invalid", "same-ID mutation breaks the evidence fingerprint")
	var blocked_source := source.duplicate(true)
	blocked_source.merge({
		"qualification_green": false,
		"product_blocker": "BLOCKED_BY_NO_LEGAL_QUEUE_ACCEPTANCE_SCENARIO",
		"queue_count": 0,
		"queue_revision": 0,
		"queue_trigger_actor": "none",
		"queue_trigger_semantic_action_id": "",
		"queue_trigger_card_semantic_id": "",
		"queue_trigger_target_fingerprint": "",
		"final_reason_code": "BLOCKED_BY_NO_LEGAL_QUEUE_ACCEPTANCE_SCENARIO",
	}, true)
	var blocked := ATTESTATION.build(blocked_source)
	_expect(bool(ATTESTATION.validation_report(blocked).get("valid", false)), "Queue zero is a valid blocked product attestation")
	_expect(not bool(blocked.get("qualification_green", true)) and str(blocked.get("product_blocker", "")).begins_with("BLOCKED_BY_"), "product blocker remains separate from Harness readiness")
	_cleanup(run_id)
	if _failures.is_empty():
		print("CHILD COMPLETION ATTESTATION PASS %d checks" % _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error("CHILD COMPLETION ATTESTATION FAILURE: %s" % failure)
		quit(1)


func _cleanup(run_id: String) -> void:
	for path in [
		ATTESTATION.completion_path(run_id, "qualification"),
		ATTESTATION.result_path(run_id, "qualification"),
	]:
		var absolute_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
