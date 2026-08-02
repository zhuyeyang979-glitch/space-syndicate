extends SceneTree

const ATTEMPT := preload("res://scripts/tools/remaining_owner_closed_data_preflight_attempt_v2.gd")
const CHILD_PATH := "res://scripts/tools/alpha04c_remaining_index_14_18_owner_closed_data_preflight_v2.gd"
const WRAPPER_PATH := "res://scripts/tools/run_alpha04c_remaining_index_14_18_owner_closed_data_preflight_v2.ps1"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var authorization := ATTEMPT.authorization()
	var child := FileAccess.get_file_as_string(CHILD_PATH)
	var wrapper := FileAccess.get_file_as_string(WRAPPER_PATH)
	_expect(not authorization.is_empty() \
			and str(authorization.get("attempt_id", "")) == ATTEMPT.ATTEMPT_ID, "attempt v2 authorization is exact")
	_expect(int(authorization.get("attempt_count_before", -1)) == 0 \
			and int(authorization.get("authorized_new_attempt_count", -1)) == 1 \
			and int(authorization.get("attempt_count_after", -1)) == 1, "authorization permits one atomic attempt")
	_expect(ATTEMPT.START_INDEX == 14 and ATTEMPT.END_INDEX == 18, "attempt range is exactly 14 through 18")
	_expect(child.contains("ATTEMPT.consume_child_admission") \
			and child.contains("break") \
			and child.contains("remaining_owner_preflight_concurrent_execution_count"), "child consumes one admission and stops at first failure")
	_expect(wrapper.contains("FileMode]::CreateNew") \
			and wrapper.contains("remaining_owner_preflight_attempt_ledger.json") \
			and wrapper.contains("remaining_owner_preflight_attempt_v2_already_claimed"), "parent owns an exclusive attempt ledger")
	_expect(wrapper.contains("scenario_identity_fingerprint") \
			and wrapper.contains("registry_binding_fingerprint") \
			and wrapper.contains("child_completion_sha256") \
			and wrapper.contains("parent_exit_sha256") \
			and wrapper.contains("started_at") \
			and wrapper.contains("completed_at") \
			and wrapper.contains("first_failure"), "ledger records all required attestation fields")
	_expect(wrapper.contains("execution_replay_v2_not_green") \
			and wrapper.contains("execution_replay_v2_evidence_not_ancestor"), "Execution replay v2 GREEN is a hard prerequisite")
	_expect(child.contains('"preflight_quota_claim_count": 0') \
			and child.contains('"preflight_full_owner_audit_count": 0') \
			and child.contains('"preflight_process_a_count": 0') \
			and child.contains('"v8_authorization_created": false'), "attempt cannot become V8, Process A, or diagnostic quota")
	_expect(not child.contains("capture_all_sections_detailed") \
			and not child.contains("capture_resume_envelope") \
			and not wrapper.contains("targeted_owner_capture_diagnostic_v2.gd") \
			and not wrapper.contains("process_a_rehearsal_completion_v1.gd"), "attempt remains a five-Owner read-only preflight")
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("REMAINING_OWNER_PREFLIGHT_ATTEMPT_V2_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size(),
	])
	if not _failures.is_empty():
		push_error("Remaining Owner preflight attempt v2 contract failed:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)
