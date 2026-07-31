extends SceneTree

const DIAGNOSTIC := preload("res://scripts/tools/targeted_owner_capture_diagnostic_v2.gd")
const AUTHORIZATION_CONTRACT := preload("res://scripts/tools/cold_restore_authorization_contract_v1.gd")
const IDENTITY := preload("res://scripts/tools/diagnostic_scenario_identity_v1.gd")
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")

const HEAD := "0123456789abcdef0123456789abcdef01234567"
const SHA := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const PRIVATE_SENTINEL := "PRIVATE_OWNER_PAYLOAD_900626424"
const FAILURE_FIELDS_EXPECTED := [
	"schema_version", "registry_operation_id", "capture_sequence", "section_index",
	"section_id", "owner_id", "owner_node_path", "owner_script_path", "capture_method",
	"failure_class", "reason_code", "method_missing", "method_exception",
	"result_not_dictionary", "result_empty", "result_not_pure_data", "result_header_invalid",
	"result_version_invalid", "result_ruleset_invalid", "state_version_observed",
	"ruleset_id_observed", "live_state_mutated_during_capture", "private_payload_redacted",
]

var RUN_ID := AUTHORIZATION_CONTRACT.run_id(
	"targeted_owner_capture_diagnostic_v4_importchain", HEAD
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_full_next_expected_chain()
	_test_terminal_contract()
	_test_phase_success_semantics()
	_test_all_owners()
	_test_first_failure()
	_test_post_capture_failure()
	_test_first_and_post_capture_failure()
	_test_closed_failure_contract()
	_test_safety_binding_and_payload_redaction()
	_test_pre_owner_failure()
	print("TARGETED_OWNER_CAPTURE_DIAGNOSTIC_V2_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _test_full_next_expected_chain() -> void:
	var timeline := DIAGNOSTIC.new_timeline(RUN_ID, HEAD)
	_expect_timeline(timeline, "none", "diagnostic_started", "new timeline starts at the only legal first phase")
	var fixed_chain := [
		["diagnostic_started", "session_creating"],
		["session_creating", "session_started"],
		["session_started", "scenario_identity_attesting"],
		["scenario_identity_attesting", "scenario_identity_attested"],
		["scenario_identity_attested", "registry_binding_attesting"],
		["registry_binding_attesting", "registry_binding_attested"],
		["registry_binding_attested", "owner_audit_started"],
		["owner_audit_started", "owner_capture_started"],
	]
	for phase_and_next in fixed_chain:
		timeline = _advance(timeline, str(phase_and_next[0]))
		_expect_timeline(timeline, str(phase_and_next[0]), str(phase_and_next[1]), "%s advertises its exact successor" % str(phase_and_next[0]))
	for owner_index in range(19):
		timeline = _advance(timeline, "owner_capture_started", owner_index)
		_expect_timeline(timeline, "owner_capture_started", "owner_capture_succeeded_or_failed", "Owner %d start advertises the closed result pair" % owner_index)
		timeline = _advance(timeline, "owner_capture_succeeded", owner_index)
		_expect_timeline(
			timeline,
			"owner_capture_succeeded",
			"owner_capture_started" if owner_index < 18 else "owner_audit_completed",
			"Owner %d success advertises the exact next boundary" % owner_index
		)
	timeline = _advance(timeline, "owner_audit_completed")
	_expect_timeline(timeline, "owner_audit_completed", "diagnostic_completed", "completed audit advertises terminal closure")
	timeline = _advance(timeline, "diagnostic_completed")
	_expect_timeline(timeline, "diagnostic_completed", "none", "terminal diagnostic has no next phase")

	var wrong_next := timeline.duplicate(true)
	wrong_next["next_expected_phase"] = "diagnostic_completed"
	wrong_next = _seal_timeline(wrong_next)
	_expect(not bool(DIAGNOSTIC.timeline_validation_report(wrong_next).get("valid", true)), "re-sealed terminal next_expected tampering fails closed")


func _test_terminal_contract() -> void:
	var state := _all_owner_state(false)
	var preterminal_timeline := state.get("timeline", {}) as Dictionary
	var phase_rows := (preterminal_timeline.get("phase_rows", []) as Array).duplicate(true)
	phase_rows.pop_back()
	preterminal_timeline["phase_rows"] = phase_rows
	preterminal_timeline["last_completed_phase"] = "owner_audit_completed"
	preterminal_timeline["current_phase"] = "owner_audit_completed"
	preterminal_timeline["next_expected_phase"] = "diagnostic_completed"
	preterminal_timeline = _seal_timeline(preterminal_timeline)
	_expect(bool(DIAGNOSTIC.timeline_validation_report(preterminal_timeline).get("valid", false)), "in-progress snapshot remains a valid timeline")
	var preterminal := DIAGNOSTIC.build(_source(preterminal_timeline, state.get("rows", []) as Array))
	_expect(not bool(_validate(preterminal).get("valid", true)), "final diagnostic rejects a valid but nonterminal timeline")

	var valid := DIAGNOSTIC.build(_source(state.get("timeline", {}) as Dictionary, state.get("rows", []) as Array))
	var phase_flag_tamper := valid.duplicate(true)
	phase_flag_tamper["owner_audit_completed"] = false
	phase_flag_tamper = _seal_diagnostic(phase_flag_tamper)
	_expect(not bool(_validate(phase_flag_tamper).get("valid", true)), "root phase flags must match the terminal timeline")


func _test_phase_success_semantics() -> void:
	var timeline := DIAGNOSTIC.new_timeline(RUN_ID, HEAD)
	var rejected := DIAGNOSTIC.advance(timeline, "diagnostic_started", -1, false, "ok", 1)
	_expect(not bool(rejected.get("advanced", true)), "a failed phase write cannot enter the attested timeline")

	timeline = _timeline_to_owner_start()
	rejected = DIAGNOSTIC.advance(timeline, "owner_capture_started", 0, true, "ok", 100)
	_expect(not bool(rejected.get("advanced", true)), "Owner start requires its typed phase reason")
	timeline = _advance(timeline, "owner_capture_started", 0)
	rejected = DIAGNOSTIC.advance(timeline, "owner_capture_failed", 0, true, "future_private_reason", 101)
	_expect(not bool(rejected.get("advanced", true)), "Owner failure phase rejects a reason outside SaveOwnerCaptureFailureV1")

	var state := _all_owner_state(false)
	var tampered := (state.get("timeline", {}) as Dictionary).duplicate(true)
	var rows := (tampered.get("phase_rows", []) as Array).duplicate(true)
	var row := (rows[0] as Dictionary).duplicate(true)
	row["success"] = false
	rows[0] = _reseal(row, "evidence_fingerprint")
	tampered["phase_rows"] = rows
	tampered = _seal_timeline(tampered)
	_expect(not bool(DIAGNOSTIC.timeline_validation_report(tampered).get("valid", true)), "re-sealed false phase success cannot masquerade as completed evidence")


func _test_all_owners() -> void:
	var state := _all_owner_state()
	var diagnostic := DIAGNOSTIC.build(_source(state.get("timeline", {}) as Dictionary, state.get("rows", []) as Array))
	var report := _validate(diagnostic)
	_expect(bool(report.get("valid", false)), "19/19 diagnostic validates")
	_expect(bool(report.get("safety_green", false)), "19 zero-delta Owner rows derive safety green")
	_expect(str(diagnostic.get("last_completed_diagnostic_phase", "")) == "diagnostic_completed" \
			and str(diagnostic.get("next_expected_diagnostic_phase", "")) == "none", "final diagnostic exposes the terminal phase pair")

	var truncated := diagnostic.duplicate(true)
	(truncated.get("owner_capture_rows", []) as Array).pop_back()
	truncated = _seal_diagnostic(truncated)
	_expect(not bool(_validate(truncated).get("valid", true)), "truncated Owner rows fail closed")

	var wrong_order := diagnostic.duplicate(true)
	var owner_rows := (wrong_order.get("owner_capture_rows", []) as Array).duplicate(true)
	var bad_row := (owner_rows[8] as Dictionary).duplicate(true)
	bad_row["capture_result_kind"] = "NOT_ATTEMPTED_AFTER_FIRST_FAILURE"
	bad_row["capture_started"] = false
	bad_row["capture_completed"] = false
	bad_row["payload_schema_version"] = -1
	bad_row["payload_fingerprint"] = ""
	bad_row["payload_pure_data"] = false
	bad_row["elapsed_milliseconds"] = 0
	bad_row["reason_code"] = "not_attempted_after_first_failure"
	owner_rows[8] = _reseal(bad_row, "row_evidence_fingerprint")
	wrong_order["owner_capture_rows"] = owner_rows
	wrong_order["owner_capture_attempted_count"] = 18
	wrong_order["owner_capture_succeeded_count"] = 18
	wrong_order["owner_capture_skipped_count"] = 1
	wrong_order = _seal_diagnostic(wrong_order)
	_expect(not bool(_validate(wrong_order).get("valid", true)), "a skipped row before any first failure is rejected")


func _test_first_failure() -> void:
	var state := _failed_owner_state(7, "owner_capture_empty", "owner_capture_empty")
	var source := _source(state.get("timeline", {}) as Dictionary, state.get("rows", []) as Array)
	source["last_completed_owner_capture_index"] = 7
	source["first_failure"] = _capture_failure(7, "owner_capture_empty", "OWNER_CAPTURE_EMPTY")
	source["owner_capture_failure_attested"] = true
	source["post_capture_validation"] = "NOT_RUN_AFTER_OWNER_FAILURE"
	var diagnostic := DIAGNOSTIC.build(source)
	_expect(bool(_validate(diagnostic).get("valid", false)), "first Owner failure plus skipped suffix validates")

	var row_reason_tamper := diagnostic.duplicate(true)
	var owner_rows := (row_reason_tamper.get("owner_capture_rows", []) as Array).duplicate(true)
	var failed_row := (owner_rows[7] as Dictionary).duplicate(true)
	failed_row["reason_code"] = "allocator_cursor_regressed"
	owner_rows[7] = _reseal(failed_row, "row_evidence_fingerprint")
	row_reason_tamper["owner_capture_rows"] = owner_rows
	row_reason_tamper = _seal_diagnostic(row_reason_tamper)
	_expect(not bool(_validate(row_reason_tamper).get("valid", true)), "failed Owner row must bind to first_failure when no post failure exists")


func _test_post_capture_failure() -> void:
	var state := _all_owner_state(false)
	var source := _source(state.get("timeline", {}) as Dictionary, state.get("rows", []) as Array)
	source["post_capture_validation"] = "FAILED"
	source["post_capture_failure"] = _capture_failure(7, "allocator_cursor_regressed", "REGISTRY_INTERNAL_ERROR")
	var diagnostic := DIAGNOSTIC.build(source)
	_expect(bool(_validate(diagnostic).get("valid", false)), "typed post-capture failure remains distinct from 19 successful Owner captures")
	_expect((diagnostic.get("first_failure", {}) as Dictionary).is_empty() \
			and not bool(diagnostic.get("owner_capture_failure_attested", true)), "post-capture failure does not forge a first Owner failure")

	var wrong_class := diagnostic.duplicate(true)
	var post := (wrong_class.get("post_capture_failure", {}) as Dictionary).duplicate(true)
	post["failure_class"] = "OWNER_CAPTURE_EMPTY"
	post["result_empty"] = true
	wrong_class["post_capture_failure"] = post
	wrong_class = _seal_diagnostic(wrong_class)
	_expect(not bool(_validate(wrong_class).get("valid", true)), "post-capture failure rejects an Owner-local capture class")


func _test_first_and_post_capture_failure() -> void:
	var state := _failed_owner_state(7, "owner_capture_empty", "allocator_cursor_regressed")
	var source := _source(state.get("timeline", {}) as Dictionary, state.get("rows", []) as Array)
	source["last_completed_owner_capture_index"] = 7
	source["first_failure"] = _capture_failure(7, "owner_capture_empty", "OWNER_CAPTURE_EMPTY")
	source["owner_capture_failure_attested"] = true
	source["post_capture_validation"] = "FAILED"
	source["post_capture_failure"] = _capture_failure(7, "allocator_cursor_regressed", "REGISTRY_INTERNAL_ERROR")
	var diagnostic := DIAGNOSTIC.build(source)
	_expect(bool(_validate(diagnostic).get("valid", false)), "first_failure and typed post_capture_failure can coexist without identity conflation")

	var same_state := _failed_owner_state(7, "allocator_cursor_regressed", "allocator_cursor_regressed")
	var same_source := _source(same_state.get("timeline", {}) as Dictionary, same_state.get("rows", []) as Array)
	var same_failure := _capture_failure(7, "allocator_cursor_regressed", "REGISTRY_INTERNAL_ERROR")
	same_source["last_completed_owner_capture_index"] = 7
	same_source["first_failure"] = same_failure
	same_source["owner_capture_failure_attested"] = true
	same_source["post_capture_validation"] = "FAILED"
	same_source["post_capture_failure"] = same_failure.duplicate(true)
	_expect(not bool(_validate(DIAGNOSTIC.build(same_source)).get("valid", true)), "identical first and post failures are not accepted as two typed events")


func _test_closed_failure_contract() -> void:
	_expect(DIAGNOSTIC.FAILURE_FIELDS == FAILURE_FIELDS_EXPECTED \
			and DIAGNOSTIC.FAILURE_FIELDS.size() == 23, "diagnostic failure projection is the exact 23-field SaveOwnerCaptureFailureV1 shape")
	var state := _failed_owner_state(7, "owner_capture_empty", "owner_capture_empty")
	var source := _source(state.get("timeline", {}) as Dictionary, state.get("rows", []) as Array)
	source["last_completed_owner_capture_index"] = 7
	source["first_failure"] = _capture_failure(7, "owner_capture_empty", "OWNER_CAPTURE_EMPTY")
	source["owner_capture_failure_attested"] = true
	source["post_capture_validation"] = "NOT_RUN_AFTER_OWNER_FAILURE"
	var diagnostic := DIAGNOSTIC.build(source)

	var unknown_class := diagnostic.duplicate(true)
	var failure := (unknown_class.get("first_failure", {}) as Dictionary).duplicate(true)
	failure["failure_class"] = "OWNER_CAPTURE_TIMEOUT"
	unknown_class["first_failure"] = failure
	unknown_class = _seal_diagnostic(unknown_class)
	_expect(not bool(_validate(unknown_class).get("valid", true)), "failure class outside SaveOwnerCaptureFailureV1 fails closed")

	var unknown_reason := diagnostic.duplicate(true)
	failure = (unknown_reason.get("first_failure", {}) as Dictionary).duplicate(true)
	failure["reason_code"] = "future_private_reason_900626424"
	unknown_reason["first_failure"] = failure
	unknown_reason = _seal_diagnostic(unknown_reason)
	_expect(not bool(_validate(unknown_reason).get("valid", true)), "failure reason outside SaveOwnerCaptureFailureV1 fails closed")

	var wrong_flags := diagnostic.duplicate(true)
	failure = (wrong_flags.get("first_failure", {}) as Dictionary).duplicate(true)
	failure["result_empty"] = false
	wrong_flags["first_failure"] = failure
	wrong_flags = _seal_diagnostic(wrong_flags)
	_expect(not bool(_validate(wrong_flags).get("valid", true)), "typed failure class requires its matching shape flag")

	var exposed := diagnostic.duplicate(true)
	failure = (exposed.get("first_failure", {}) as Dictionary).duplicate(true)
	failure["payload"] = {"hand": PRIVATE_SENTINEL}
	exposed["first_failure"] = failure
	exposed = _seal_diagnostic(exposed)
	_expect(not bool(_validate(exposed).get("valid", true)), "failure evidence with an added payload field is rejected")


func _test_safety_binding_and_payload_redaction() -> void:
	var state := _all_owner_state(false)
	var diagnostic := DIAGNOSTIC.build(_source(state.get("timeline", {}) as Dictionary, state.get("rows", []) as Array))
	var false_claim := diagnostic.duplicate(true)
	false_claim["safety_green"] = false
	false_claim = _seal_diagnostic(false_claim)
	_expect(not bool(_validate(false_claim).get("valid", true)), "zero deltas cannot be paired with a false safety summary")

	var unsafe := diagnostic.duplicate(true)
	var owner_rows := (unsafe.get("owner_capture_rows", []) as Array).duplicate(true)
	var row := (owner_rows[4] as Dictionary).duplicate(true)
	row["rng_draw_delta"] = 1
	owner_rows[4] = _reseal(row, "row_evidence_fingerprint")
	unsafe["owner_capture_rows"] = owner_rows
	unsafe = _seal_diagnostic(unsafe)
	_expect(not bool(_validate(unsafe).get("valid", true)), "a nonzero safe delta cannot claim safety green")
	unsafe["safety_green"] = false
	unsafe = _seal_diagnostic(unsafe)
	var unsafe_report := _validate(unsafe)
	_expect(bool(unsafe_report.get("valid", false)) and not bool(unsafe_report.get("safety_green", true)), "red diagnostic evidence remains truthful when a safe delta is nonzero")

	var external_payload := diagnostic.duplicate(true)
	owner_rows = (external_payload.get("owner_capture_rows", []) as Array).duplicate(true)
	row = (owner_rows[0] as Dictionary).duplicate(true)
	row["payload"] = {"hand": PRIVATE_SENTINEL}
	owner_rows[0] = row
	external_payload["owner_capture_rows"] = owner_rows
	external_payload = _seal_diagnostic(external_payload)
	_expect(not bool(_validate(external_payload).get("valid", true)), "external Owner row payload expansion is rejected")

	var source_rows := (state.get("rows", []) as Array).duplicate(true)
	row = (source_rows[0] as Dictionary).duplicate(true)
	row["payload"] = {"hand": PRIVATE_SENTINEL}
	source_rows[0] = row
	var projected := DIAGNOSTIC.build(_source(state.get("timeline", {}) as Dictionary, source_rows))
	_expect(not JSON.stringify(projected).contains(PRIVATE_SENTINEL), "builder projects only public Owner row fields")
	_expect(bool(_validate(projected).get("valid", false)), "payload projection preserves otherwise valid public evidence")


func _test_pre_owner_failure() -> void:
	var timeline := DIAGNOSTIC.new_timeline(RUN_ID, HEAD)
	for phase in ["diagnostic_started", "session_creating", "session_started", "scenario_identity_attesting"]:
		timeline = _advance(timeline, phase)
	timeline = _advance(timeline, "diagnostic_completed", -1, "diagnostic_pre_owner_identity_mismatch")
	var identity_report := IDENTITY.validation_report({}, RUN_ID, HEAD, SHA)
	var source := _source(timeline, [])
	source["scenario_identity"] = {}
	source["scenario_identity_attested"] = false
	source["scenario_identity_failure"] = identity_report.get("failure", {})
	source["harness_or_scenario_failure_attested"] = true
	source["owner_audit_started"] = false
	source["owner_audit_completed"] = false
	source["first_owner_capture_index"] = -1
	source["last_completed_owner_capture_index"] = -1
	source["post_capture_validation"] = "NOT_RUN"
	var diagnostic := DIAGNOSTIC.build(source)
	_expect(bool(_validate(diagnostic).get("valid", false)), "pre-owner identity failure is valid diagnostic evidence")
	_expect((diagnostic.get("first_failure", {}) as Dictionary).is_empty(), "pre-owner failure does not forge Owner identity")
	_expect(str(diagnostic.get("next_expected_diagnostic_phase", "")) == "none", "pre-owner failure still closes at the terminal phase")


func _all_owner_state(report_advances := true) -> Dictionary:
	var timeline := _timeline_to_owner_start(report_advances)
	var rows: Array = []
	for index in range(19):
		timeline = _advance(timeline, "owner_capture_started", index, "", report_advances)
		timeline = _advance(timeline, "owner_capture_succeeded", index, "", report_advances)
		rows.append(_owner_row(index, "CAPTURED"))
	timeline = _advance(timeline, "owner_audit_completed", -1, "", report_advances)
	timeline = _advance(timeline, "diagnostic_completed", -1, "", report_advances)
	return {"timeline": timeline, "rows": rows}


func _failed_owner_state(failure_index: int, timeline_reason: String, row_reason: String) -> Dictionary:
	var timeline := _timeline_to_owner_start(false)
	var rows: Array = []
	for index in range(19):
		if index < failure_index:
			timeline = _advance(timeline, "owner_capture_started", index, "", false)
			timeline = _advance(timeline, "owner_capture_succeeded", index, "", false)
			rows.append(_owner_row(index, "CAPTURED"))
		elif index == failure_index:
			timeline = _advance(timeline, "owner_capture_started", index, "", false)
			timeline = _advance(timeline, "owner_capture_failed", index, timeline_reason, false)
			rows.append(_owner_row(index, "FAILED", row_reason))
		else:
			rows.append(_owner_row(index, "NOT_ATTEMPTED_AFTER_FIRST_FAILURE"))
	timeline = _advance(timeline, "owner_audit_completed", -1, "", false)
	timeline = _advance(timeline, "diagnostic_completed", -1, "", false)
	return {"timeline": timeline, "rows": rows}


func _timeline_to_owner_start(report_advances := true) -> Dictionary:
	var timeline := DIAGNOSTIC.new_timeline(RUN_ID, HEAD)
	for phase in [
		"diagnostic_started", "session_creating", "session_started",
		"scenario_identity_attesting", "scenario_identity_attested",
		"registry_binding_attesting", "registry_binding_attested", "owner_audit_started",
	]:
		timeline = _advance(timeline, phase, -1, "", report_advances)
	return timeline


func _advance(
	timeline: Dictionary,
	phase: String,
	owner_index: int = -1,
	reason: String = "",
	report := true
) -> Dictionary:
	var reason_code := reason if not reason.is_empty() else _default_phase_reason(phase)
	var advanced := DIAGNOSTIC.advance(timeline, phase, owner_index, true, reason_code)
	if report:
		_expect(bool(advanced.get("advanced", false)), "phase advances: %s[%d]" % [phase, owner_index])
	elif not bool(advanced.get("advanced", false)):
		_failures.append("fixture phase failed: %s[%d]" % [phase, owner_index])
	return (advanced.get("timeline", {}) as Dictionary).duplicate(true)


func _default_phase_reason(phase: String) -> String:
	match phase:
		"owner_capture_started":
			return "owner_capture_started"
		"owner_capture_succeeded":
			return "owner_capture_valid"
		"diagnostic_completed":
			return "diagnostic_owner_audit_completed"
	return "ok"


func _source(timeline: Dictionary, rows: Array) -> Dictionary:
	return {
		"run_id": RUN_ID,
		"repository_head": HEAD,
		"scenario_identity": _identity(),
		"scenario_identity_attested": true,
		"scenario_identity_failure": {},
		"harness_or_scenario_failure_attested": false,
		"diagnostic_phase_timeline": timeline,
		"owner_audit_started": true,
		"owner_audit_completed": true,
		"first_owner_capture_index": 0,
		"last_completed_owner_capture_index": 18,
		"owner_capture_rows": rows,
		"first_failure": {},
		"owner_capture_failure_attested": false,
		"post_capture_validation": "PASSED",
		"post_capture_failure": {},
		"safety_green": true,
	}


func _identity() -> Dictionary:
	return IDENTITY.build({
		"run_id": RUN_ID, "repository_head": HEAD, "ruleset_id": "v0.6",
		"ruleset_fingerprint": SHA, "challenge_depth": 1, "run_seed": 900626424,
		"session_seed": 42, "scenario_fingerprint": SHA, "local_player_count": 1,
		"ai_player_count": 3, "roster_fingerprint": SHA, "session_id": "session",
		"session_generation": 1, "session_plan_fingerprint": SHA, "world_revision": 1,
		"runtime_composition_fingerprint": SHA, "save_registry_fingerprint": SHA,
		"user_data_path_fingerprint": SHA,
	})


func _owner_row(index: int, kind: String, reason := "") -> Dictionary:
	var attempted := kind != "NOT_ATTEMPTED_AFTER_FIRST_FAILURE"
	var reason_code := str(reason)
	if reason_code.is_empty():
		reason_code = "owner_capture_valid" if kind == "CAPTURED" else (
			"owner_capture_empty" if kind == "FAILED" else "not_attempted_after_first_failure"
		)
	var unsealed := {
		"owner_index": index,
		"section_id": str(DIAGNOSTIC.SECTION_ORDER[index]),
		"owner_id": str(DIAGNOSTIC.OWNER_ORDER[index]),
		"owner_path": "../../Owner%d" % index,
		"capture_started": attempted,
		"capture_completed": attempted,
		"capture_result_kind": kind,
		"payload_schema_version": 1 if attempted else -1,
		"payload_fingerprint": SHA if kind == "CAPTURED" else "",
		"payload_pure_data": kind == "CAPTURED",
		"elapsed_milliseconds": 1 if attempted else 0,
		"mutation_count": 0,
		"rng_draw_delta": 0,
		"world_time_delta": 0,
		"public_log_delta": 0,
		"reason_code": reason_code,
		"private_payload_redacted": true,
	}
	return WIRE.sealed_copy(unsealed, "row_evidence_fingerprint")


func _capture_failure(index: int, reason_code: String, failure_class: String) -> Dictionary:
	return {
		"schema_version": 1,
		"registry_operation_id": "capture-1",
		"capture_sequence": 1,
		"section_index": index,
		"section_id": str(DIAGNOSTIC.SECTION_ORDER[index]),
		"owner_id": str(DIAGNOSTIC.OWNER_ORDER[index]),
		"owner_node_path": "../../Owner%d" % index,
		"owner_script_path": "res://scripts/runtime/owner_%d.gd" % index,
		"capture_method": "to_save_data",
		"failure_class": failure_class,
		"reason_code": reason_code,
		"method_missing": failure_class == "OWNER_METHOD_MISSING",
		"method_exception": failure_class == "OWNER_CAPTURE_EXCEPTION",
		"result_empty": failure_class == "OWNER_CAPTURE_EMPTY",
		"result_not_dictionary": failure_class == "OWNER_CAPTURE_WRONG_TYPE",
		"result_not_pure_data": failure_class == "OWNER_CAPTURE_NOT_PURE_DATA",
		"result_header_invalid": failure_class == "OWNER_CAPTURE_HEADER_INVALID",
		"result_version_invalid": failure_class == "OWNER_CAPTURE_VERSION_INVALID",
		"result_ruleset_invalid": failure_class == "OWNER_CAPTURE_RULESET_INVALID",
		"state_version_observed": 3,
		"ruleset_id_observed": "v0.6",
		"live_state_mutated_during_capture": failure_class == "OWNER_CAPTURE_MUTATED_RUNTIME",
		"private_payload_redacted": true,
	}


func _validate(diagnostic: Dictionary) -> Dictionary:
	return DIAGNOSTIC.validation_report(diagnostic, RUN_ID, HEAD, SHA)


func _seal_timeline(timeline: Dictionary) -> Dictionary:
	return _reseal(timeline, "evidence_fingerprint")


func _seal_diagnostic(diagnostic: Dictionary) -> Dictionary:
	return _reseal(diagnostic, "evidence_fingerprint")


func _reseal(value: Dictionary, fingerprint_field: String) -> Dictionary:
	var unsealed := value.duplicate(true)
	unsealed.erase(fingerprint_field)
	return WIRE.sealed_copy(unsealed, fingerprint_field)


func _expect_timeline(timeline: Dictionary, current: String, next_expected: String, message: String) -> void:
	_expect(
		bool(DIAGNOSTIC.timeline_validation_report(timeline).get("valid", false)) \
				and str(timeline.get("current_phase", "")) == current \
				and str(timeline.get("last_completed_phase", "")) == current \
				and str(timeline.get("next_expected_phase", "")) == next_expected,
		message
	)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)
