extends SceneTree

const ATTESTATION := preload("res://scripts/tools/cold_restore_child_completion_attestation.gd")
const TARGETED_DIAGNOSTIC_V2 := preload("res://scripts/tools/targeted_owner_capture_diagnostic_v2.gd")
const DIAGNOSTIC_IDENTITY := preload("res://scripts/tools/diagnostic_scenario_identity_v1.gd")
const SEMANTIC_WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const AUTHORIZATION_CONTRACT := preload("res://scripts/tools/cold_restore_authorization_contract_v1.gd")

var _checks := 0
var _failures: Array[String] = []
var _targeted_test_root := ""


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
	_targeted_test_root = ProjectSettings.globalize_path(
		"user://cold_restore_child_completion_attestation/%d" % Time.get_ticks_usec()
	)
	OS.set_environment("SPACE_SYNDICATE_COLD_RESTORE_TEST_EVIDENCE_ROOT", _targeted_test_root)
	_test_targeted_owner_capture_diagnostic_contract()
	_test_targeted_owner_capture_v1_write_compatibility()
	_test_targeted_owner_capture_v2_child_binding()
	_cleanup(run_id)
	OS.unset_environment("SPACE_SYNDICATE_COLD_RESTORE_TEST_EVIDENCE_ROOT")
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
	wrong_head_binding["run_id"] = _targeted_run_id("b".repeat(40))
	_expect(not ATTESTATION._valid_owner_capture_diagnostic(wrong_head_binding), "targeted run id must match the repository HEAD prefix")
	var unknown_reason := diagnostic.duplicate(true)
	var unknown_audits := unknown_reason.get("phase_audits", []) as Array
	var unknown_results := (unknown_audits[0] as Dictionary).get("section_results", []) as Array
	(unknown_results[0] as Dictionary)["reason_code"] = "private_future_identity_900626424"
	_expect(not ATTESTATION._valid_owner_capture_diagnostic(unknown_reason), "unknown lower-snake Owner reason cannot cross the public evidence boundary")
	var first_failure := _valid_targeted_diagnostic(7)
	_expect(ATTESTATION._valid_owner_capture_diagnostic(first_failure), "first failing section is bound to its phase, index, owner, row, and reason")
	_expect(
		_same_string_set(
			ATTESTATION.OWNER_CAPTURE_FAILURE_FIELDS,
			ATTESTATION.CAPTURE_FAILURE.build({}).keys()
		),
		"Child failure fields exactly match the full SaveOwnerCaptureFailureV1 contract"
	)
	var reduced_failure := first_failure.duplicate(true)
	(reduced_failure.get("first_failure", {}) as Dictionary).erase("owner_node_path")
	var reduced_audits := reduced_failure.get("phase_audits", []) as Array
	for audit_variant in reduced_audits:
		var audit := audit_variant as Dictionary
		if not (audit.get("first_failure", {}) as Dictionary).is_empty():
			(audit.get("first_failure", {}) as Dictionary).erase("owner_node_path")
	_expect(
		not ATTESTATION._valid_owner_capture_diagnostic(reduced_failure),
		"a reduced failure copy cannot masquerade as the full SaveOwnerCaptureFailureV1 contract"
	)
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


func _test_targeted_owner_capture_v1_write_compatibility() -> void:
	var repository_head := _unique_repository_head("legacy-v1")
	var run_id := _targeted_run_id(repository_head)
	var diagnostic := _valid_targeted_diagnostic()
	diagnostic["run_id"] = run_id
	diagnostic["repository_head"] = repository_head
	var wrong_run_id := _targeted_run_id(_unique_repository_head("legacy-v1-wrong"))
	var rejected := ATTESTATION.write_owner_capture_diagnostic(wrong_run_id, diagnostic)
	_expect(
		str(rejected.get("reason_code", "")) == "child_diagnostic_run_id_mismatch",
		"V1 write rejects an argument run_id that differs from the payload"
	)
	var write := ATTESTATION.write_owner_capture_diagnostic(
		run_id, diagnostic, "", "", _targeted_test_root
	)
	_expect(
		bool(write.get("valid", false)) and not write.has("artifact_binding"),
		"legacy V1 retains its two-argument atomic write contract"
	)
	_cleanup_diagnostic(run_id)


func _test_targeted_owner_capture_v2_child_binding() -> void:
	var repository_head := _unique_repository_head("targeted-v2")
	var scenario_fingerprint := "b".repeat(64)
	var run_id := _targeted_run_id(repository_head)
	var diagnostic := _valid_targeted_diagnostic_v2(repository_head, scenario_fingerprint, true, true)
	_expect(
		bool(TARGETED_DIAGNOSTIC_V2.validation_report(
			diagnostic, run_id, repository_head, scenario_fingerprint
		).get("valid", false)),
		"V2 fixture satisfies its source schema before Child binding is applied"
	)
	_expect(
		not ATTESTATION._valid_owner_capture_diagnostic(diagnostic),
		"V2 cannot self-supply the external repository and scenario expectations"
	)
	_expect(
		ATTESTATION._valid_owner_capture_diagnostic(
			diagnostic, run_id, repository_head, scenario_fingerprint
		),
		"V2 validates when all external bindings are independently supplied"
	)
	var missing_bindings := ATTESTATION.write_owner_capture_diagnostic(run_id, diagnostic)
	_expect(
		str(missing_bindings.get("reason_code", "")) == "child_diagnostic_expected_repository_head_missing" \
				and bool(missing_bindings.get("private_payload_redacted", false)),
		"V2 write fails closed and redacted when external bindings are absent"
	)
	var wrong_argument_run_id := _targeted_run_id(
		_unique_repository_head("targeted-v2-wrong-run")
	)
	var wrong_run := ATTESTATION.write_owner_capture_diagnostic(
		wrong_argument_run_id, diagnostic, repository_head, scenario_fingerprint
	)
	_expect(
		str(wrong_run.get("reason_code", "")) == "child_diagnostic_run_id_mismatch",
		"V2 argument run_id must equal payload run_id"
	)
	var wrong_head := ATTESTATION.write_owner_capture_diagnostic(
		run_id, diagnostic, _unique_repository_head("targeted-v2-wrong-head"), scenario_fingerprint
	)
	_expect(
		str(wrong_head.get("reason_code", "")) == "child_diagnostic_repository_head_mismatch",
		"V2 rejects a repository HEAD that differs from the external expectation"
	)
	var wrong_scenario := ATTESTATION.write_owner_capture_diagnostic(
		run_id, diagnostic, repository_head, "c".repeat(64)
	)
	_expect(
		str(wrong_scenario.get("reason_code", "")) == "targeted_diagnostic_identity_binding_invalid",
		"V2 rejects a scenario fingerprint that differs from the external expectation"
	)
	var timeline_run_mismatch := diagnostic.duplicate(true)
	var rebound_run_timeline := (timeline_run_mismatch.get("diagnostic_phase_timeline", {}) as Dictionary).duplicate(true)
	rebound_run_timeline["run_id"] = wrong_argument_run_id
	timeline_run_mismatch["diagnostic_phase_timeline"] = _reseal(rebound_run_timeline, "evidence_fingerprint")
	timeline_run_mismatch = _reseal(timeline_run_mismatch, "evidence_fingerprint")
	_expect(
		str(ATTESTATION._owner_capture_diagnostic_binding_report(
					run_id, timeline_run_mismatch, repository_head, scenario_fingerprint
				).get("reason_code", "")) == "child_diagnostic_timeline_run_id_mismatch",
		"Child explicitly binds the embedded V2 timeline to the argument run_id"
	)
	var timeline_head_mismatch := diagnostic.duplicate(true)
	var rebound_head_timeline := (timeline_head_mismatch.get("diagnostic_phase_timeline", {}) as Dictionary).duplicate(true)
	rebound_head_timeline["repository_head"] = _unique_repository_head("targeted-v2-timeline-head")
	timeline_head_mismatch["diagnostic_phase_timeline"] = _reseal(rebound_head_timeline, "evidence_fingerprint")
	timeline_head_mismatch = _reseal(timeline_head_mismatch, "evidence_fingerprint")
	_expect(
		str(ATTESTATION._owner_capture_diagnostic_binding_report(
					run_id, timeline_head_mismatch, repository_head, scenario_fingerprint
				).get("reason_code", "")) == "child_diagnostic_timeline_repository_head_mismatch",
		"Child explicitly binds the embedded V2 timeline to the expected repository HEAD"
	)
	var nonterminal := _valid_targeted_diagnostic_v2(repository_head, scenario_fingerprint, false, true)
	_expect(
		str(ATTESTATION._owner_capture_diagnostic_binding_report(
					run_id, nonterminal, repository_head, scenario_fingerprint
				).get("reason_code", "")) == "child_diagnostic_terminal_timeline_invalid",
		"a schema-valid but nonterminal V2 timeline cannot become a final Child artifact"
	)
	var unredacted := _valid_targeted_diagnostic_v2(repository_head, scenario_fingerprint, true, false)
	var redaction_rejection := ATTESTATION._owner_capture_diagnostic_binding_report(
		run_id, unredacted, repository_head, scenario_fingerprint
	)
	_expect(
		str(redaction_rejection.get("reason_code", "")) == "child_diagnostic_redaction_invalid" \
				and bool(redaction_rejection.get("private_payload_redacted", false)),
		"V2 failure metadata cannot disable private-payload redaction"
	)
	var write := ATTESTATION.write_owner_capture_diagnostic(
		run_id, diagnostic, repository_head, scenario_fingerprint, _targeted_test_root
	)
	var binding: Dictionary = write.get("artifact_binding", {}) \
			if write.get("artifact_binding", {}) is Dictionary else {}
	_expect(bool(write.get("valid", false)), "fully bound terminal V2 evidence is atomically written")
	_expect(
		_same_string_set(binding.keys(), ATTESTATION.TARGETED_DIAGNOSTIC_ARTIFACT_BINDING_FIELDS) \
				and str(binding.get("binding_id", "")) == ATTESTATION.TARGETED_DIAGNOSTIC_ARTIFACT_BINDING_ID \
				and str(binding.get("diagnostic_artifact_sha256", "")) == str(write.get("sha256", "")) \
				and str(binding.get("terminal_phase", "")) == "diagnostic_completed" \
				and bool(binding.get("private_payload_redacted", false)) \
				and str(binding.get("binding_fingerprint", "")) == SEMANTIC_WIRE.fingerprint(binding, "binding_fingerprint"),
		"V2 write returns an explicit, fingerprinted terminal/timeline artifact binding"
	)
	_expect(
		not binding.has("owner_capture_rows") \
				and not binding.has("scenario_identity") \
				and not JSON.stringify(binding).contains("PRIVATE_SESSION_SENTINEL"),
		"V2 artifact binding exposes hashes and terminal metadata without diagnostic payloads"
	)
	_cleanup_diagnostic(run_id)


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
		"run_id": _targeted_run_id(repository_head),
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
		"owner_node_path": "../CardInventorySaveOwner",
		"owner_script_path": "res://scripts/runtime/card_inventory_save_owner.gd",
		"capture_method": "capture_save_state",
		"failure_class": "REGISTRY_INTERNAL_ERROR",
		"reason_code": "card_inventory_v2_invalid",
		"method_missing": false,
		"method_exception": false,
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


func _valid_targeted_diagnostic_v2(
	repository_head: String,
	scenario_fingerprint: String,
	terminal: bool,
	private_payload_redacted: bool
) -> Dictionary:
	var run_id := _targeted_run_id(repository_head)
	var timeline := _targeted_diagnostic_v2_timeline(run_id, repository_head, terminal)
	var scenario_failure := {
		"schema_version": 1,
		"failure_field": "registry_binding",
		"reason_code": "diagnostic_registry_binding_invalid",
		"expected_summary": "19 ordered owners",
		"actual_summary": "binding unavailable",
		"private_payload_redacted": private_payload_redacted,
	} if terminal else {}
	return TARGETED_DIAGNOSTIC_V2.build({
		"run_id": run_id,
		"repository_head": repository_head,
		"scenario_identity": _targeted_diagnostic_v2_identity(
			run_id, repository_head, scenario_fingerprint
		),
		"scenario_identity_attested": true,
		"scenario_identity_failure": scenario_failure,
		"harness_or_scenario_failure_attested": terminal,
		"diagnostic_phase_timeline": timeline,
		"owner_audit_started": false,
		"owner_audit_completed": false,
		"first_owner_capture_index": -1,
		"last_completed_owner_capture_index": -1,
		"owner_capture_rows": [],
		"first_failure": {},
		"owner_capture_failure_attested": false,
		"post_capture_validation": "NOT_RUN",
		"post_capture_failure": {},
		"safety_green": true,
	})


func _targeted_diagnostic_v2_timeline(
	run_id: String,
	repository_head: String,
	terminal: bool
) -> Dictionary:
	var timeline := TARGETED_DIAGNOSTIC_V2.new_timeline(run_id, repository_head)
	var monotonic_ms := 100
	for phase_id in [
		"diagnostic_started",
		"session_creating",
		"session_started",
		"scenario_identity_attesting",
		"scenario_identity_attested",
		"registry_binding_attesting",
	]:
		var advanced := TARGETED_DIAGNOSTIC_V2.advance(
			timeline, phase_id, -1, true, "ok", monotonic_ms
		)
		timeline = (advanced.get("timeline", {}) as Dictionary).duplicate(true)
		monotonic_ms += 100
	if terminal:
		var completed := TARGETED_DIAGNOSTIC_V2.advance(
			timeline,
			"diagnostic_completed",
			-1,
			true,
			"diagnostic_pre_owner_registry_binding_failed",
			monotonic_ms
		)
		timeline = (completed.get("timeline", {}) as Dictionary).duplicate(true)
	return timeline


func _targeted_diagnostic_v2_identity(
	run_id: String,
	repository_head: String,
	scenario_fingerprint: String
) -> Dictionary:
	return DIAGNOSTIC_IDENTITY.build({
		"run_id": run_id,
		"repository_head": repository_head,
		"ruleset_id": "v0.6",
		"ruleset_fingerprint": "1".repeat(64),
		"challenge_depth": 1,
		"run_seed": 900626424,
		"session_seed": 900626424,
		"scenario_fingerprint": scenario_fingerprint,
		"local_player_count": 1,
		"ai_player_count": 3,
		"roster_fingerprint": "2".repeat(64),
		"session_id": "PRIVATE_SESSION_SENTINEL",
		"session_generation": 1,
		"session_plan_fingerprint": "3".repeat(64),
		"world_revision": 1,
		"runtime_composition_fingerprint": "4".repeat(64),
		"save_registry_fingerprint": "5".repeat(64),
		"user_data_path_fingerprint": "6".repeat(64),
		"diagnostic_role": "targeted_owner_diagnostic",
	})


func _unique_repository_head(label: String) -> String:
	return ("%s-%d-%d" % [label, Time.get_ticks_usec(), _checks]).sha256_text().left(40)


func _reseal(value: Dictionary, fingerprint_field: String) -> Dictionary:
	var unsealed := value.duplicate(true)
	unsealed.erase(fingerprint_field)
	return SEMANTIC_WIRE.sealed_copy(unsealed, fingerprint_field)


func _cleanup_diagnostic(run_id: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(
		ATTESTATION.diagnostic_path(run_id, "owner_capture_audit", _targeted_test_root)
	)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _targeted_run_id(repository_head: String) -> String:
	return AUTHORIZATION_CONTRACT.run_id(
		"targeted_owner_capture_diagnostic_v4_importchain", repository_head
	)


func _same_string_set(left: Array, right: Array) -> bool:
	if left.size() != right.size():
		return false
	var normalized_left: Array[String] = []
	var normalized_right: Array[String] = []
	for value in left:
		normalized_left.append(str(value))
	for value in right:
		normalized_right.append(str(value))
	normalized_left.sort()
	normalized_right.sort()
	return normalized_left == normalized_right


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
