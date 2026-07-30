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
	_test_targeted_owner_capture_diagnostic_contract()
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


func _test_targeted_owner_capture_diagnostic_contract() -> void:
	var diagnostic := _valid_targeted_diagnostic()
	_expect(ATTESTATION._valid_owner_capture_diagnostic(diagnostic), "complete ordered 19-Owner diagnostic evidence validates")
	var truncated := diagnostic.duplicate(true)
	(truncated.get("phase_audits", []) as Array).resize(7)
	truncated["audit_count"] = 7
	_expect(not ATTESTATION._valid_owner_capture_diagnostic(truncated), "truncated phase evidence fails closed")
	var contradictory := diagnostic.duplicate(true)
	var contradiction_audits := contradictory.get("phase_audits", []) as Array
	(contradiction_audits[0] as Dictionary)["captured"] = true
	(contradiction_audits[0] as Dictionary)["section_count"] = 19
	(contradiction_audits[0] as Dictionary)["section_results"] = []
	_expect(not ATTESTATION._valid_owner_capture_diagnostic(contradictory), "captured=true with missing section rows fails closed")
	var wrong_head_binding := diagnostic.duplicate(true)
	wrong_head_binding["run_id"] = "alpha04c-owner-capture-diagnostic-bbbbbbbbbbbb"
	_expect(not ATTESTATION._valid_owner_capture_diagnostic(wrong_head_binding), "targeted run id must match the repository HEAD prefix")
	var unknown_reason := diagnostic.duplicate(true)
	var unknown_audits := unknown_reason.get("phase_audits", []) as Array
	var unknown_results := (unknown_audits[0] as Dictionary).get("section_results", []) as Array
	(unknown_results[0] as Dictionary)["reason_code"] = "private_future_identity_900626424"
	_expect(not ATTESTATION._valid_owner_capture_diagnostic(unknown_reason), "unknown lower-snake Owner reason cannot cross the public evidence boundary")
	var first_failure := _valid_targeted_diagnostic(7)
	_expect(ATTESTATION._valid_owner_capture_diagnostic(first_failure), "first failing section is bound to its phase, index, owner, row, and reason")
	var rebound_failure := first_failure.duplicate(true)
	rebound_failure["first_phase_with_capture_failure"] = "session_started"
	_expect(not ATTESTATION._valid_owner_capture_diagnostic(rebound_failure), "top-level first failure cannot be rebound to a different phase")
	var zero_ai_actions := diagnostic.duplicate(true)
	zero_ai_actions["ai_action_count"] = 0
	_expect(not ATTESTATION._valid_owner_capture_diagnostic(zero_ai_actions), "zero observed AI actions fail the targeted scenario contract")
	var unchanged_ai := diagnostic.duplicate(true)
	unchanged_ai["ai_state_digest_changed"] = false
	_expect(not ATTESTATION._valid_owner_capture_diagnostic(unchanged_ai), "unchanged AI runtime state fails the targeted scenario contract")
	var missing_ai_evidence := diagnostic.duplicate(true)
	missing_ai_evidence.erase("ai_action_count")
	_expect(not ATTESTATION._valid_owner_capture_diagnostic(missing_ai_evidence), "missing AI completion evidence fails the exact field contract")
	var mistyped_ai_evidence := diagnostic.duplicate(true)
	mistyped_ai_evidence["ai_state_digest_changed"] = 1
	_expect(not ATTESTATION._valid_owner_capture_diagnostic(mistyped_ai_evidence), "mistyped AI completion evidence fails closed")


func _valid_targeted_diagnostic(failing_section_index := -1) -> Dictionary:
	var repository_head := "a".repeat(40)
	var failure := _owner_capture_failure(failing_section_index) if failing_section_index >= 0 else {}
	var audits: Array[Dictionary] = []
	for phase_index in range(ATTESTATION.TARGETED_OWNER_CAPTURE_PHASES.size()):
		var phase_failure := failure.duplicate(true) if failing_section_index >= 0 and phase_index >= 3 else {}
		audits.append(_owner_capture_audit(
			str(ATTESTATION.TARGETED_OWNER_CAPTURE_PHASES[phase_index]),
			failing_section_index,
			phase_failure
		))
	return {
		"schema_version": 1,
		"diagnostic_id": "TargetedOwnerCaptureDiagnosticV1",
		"run_id": "alpha04c-owner-capture-diagnostic-%s" % repository_head.left(12),
		"repository_head": repository_head,
		"scenario_fingerprint": ATTESTATION.TARGETED_OWNER_CAPTURE_SCENARIO_FINGERPRINT,
		"official": false,
		"formal": false,
		"challenge_depth": 1,
		"seed": 900626424,
		"local_player_count": 1,
		"ai_player_count": 3,
		"ai_action_count": 3,
		"ai_state_digest_changed": true,
		"audit_count": audits.size(),
		"phase_audits": audits,
		"first_phase_with_capture_failure": str(ATTESTATION.TARGETED_OWNER_CAPTURE_PHASES[3]) if failing_section_index >= 0 else "none",
		"first_failure": failure,
		"safety_green": true,
		"save_file_exists": false,
		"official_claim_path_present": false,
	}


func _owner_capture_audit(phase_id: String, failing_section_index: int, failure: Dictionary) -> Dictionary:
	var results: Array[Dictionary] = []
	var successful_count := ATTESTATION.SAVE_SECTION_ORDER.size() \
			if failure.is_empty() else failing_section_index
	var result_count := successful_count if failure.is_empty() else successful_count + 1
	for section_index in range(result_count):
		var captured := failure.is_empty() or section_index < failing_section_index
		results.append({
			"section_id": str(ATTESTATION.SAVE_SECTION_ORDER[section_index]),
			"owner_id": str(ATTESTATION.SAVE_OWNER_ORDER[section_index]),
			"captured": captured,
			"reason_code": "owner_capture_valid" if captured else str(failure.get("reason_code", "")),
			"state_version": 1,
			"payload_fingerprint": ("payload-%s-%d" % [phase_id, section_index]).sha256_text() if captured else "",
		})
	return {
		"phase_id": phase_id,
		"captured": failure.is_empty(),
		"section_count": successful_count,
		"section_results": results,
		"first_failure": failure.duplicate(true),
		"world_fingerprint_match": true,
		"safety_observation_match": true,
		"world_advance_delta": 0,
		"rng_draw_delta": 0,
		"public_log_delta": 0,
		"private_feedback_delta": 0,
		"sale_receipt_delta": 0,
		"human_action_delta": 0,
		"ai_action_delta": 0,
		"notification_delta": 0,
		"safety_green": true,
	}


func _owner_capture_failure(section_index: int) -> Dictionary:
	return {
		"schema_version": 1,
		"registry_operation_id": "capture-17",
		"capture_sequence": 17,
		"section_index": section_index,
		"section_id": str(ATTESTATION.SAVE_SECTION_ORDER[section_index]),
		"owner_id": str(ATTESTATION.SAVE_OWNER_ORDER[section_index]),
		"failure_class": "REGISTRY_INTERNAL_ERROR",
		"reason_code": "card_inventory_v2_invalid",
		"result_empty": false,
		"result_not_dictionary": false,
		"result_not_pure_data": false,
		"result_header_invalid": false,
		"result_version_invalid": false,
		"result_ruleset_invalid": false,
		"state_version_observed": 2,
		"ruleset_id_observed": "v0.6",
		"live_state_mutated_during_capture": false,
		"private_payload_redacted": true,
	}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
