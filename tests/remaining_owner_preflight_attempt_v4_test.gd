extends SceneTree

const ATTEMPT := preload("res://scripts/tools/remaining_owner_closed_data_preflight_attempt_v4.gd")
const CHILD_SCRIPT := preload("res://scripts/tools/alpha04c_remaining_index_18_owner_closed_data_preflight_v4.gd")
const CHILD_PATH := "res://scripts/tools/alpha04c_remaining_index_18_owner_closed_data_preflight_v4.gd"
const WRAPPER_PATH := "res://scripts/tools/run_alpha04c_remaining_index_18_owner_closed_data_preflight_v4.ps1"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var authorization := ATTEMPT.authorization()
	var child := FileAccess.get_file_as_string(CHILD_PATH)
	var wrapper := FileAccess.get_file_as_string(WRAPPER_PATH)
	_expect(CHILD_SCRIPT != null and not child.is_empty() and not wrapper.is_empty(), "Attempt V4 child and parent parse and are present")
	_expect(not authorization.is_empty() \
			and str(authorization.get("attempt_id", "")) == ATTEMPT.ATTEMPT_ID, "Attempt V4 authorization binds immutable prerequisite hashes")
	_expect(int(authorization.get("attempt_count_before", -1)) == 0 \
			and int(authorization.get("authorized_new_attempt_count", -1)) == 1 \
			and int(authorization.get("attempt_count_after", -1)) == 1, "authorization permits one atomic Attempt V4")
	_expect(ATTEMPT.START_INDEX == 18 and ATTEMPT.END_INDEX == 18 \
			and ATTEMPT.QUALIFIED_PRIOR_OWNER_COUNT == 10, "Attempt V4 targets only final Owner index 18")
	_expect(child.contains("NEW_EXPECTED_OWNER_COUNT := 1") \
			and child.contains("QUALIFIED_PRIOR_OWNER_COUNT := 10") \
			and child.contains('EXPECTED_OWNER_ID := "game_session"'), "child can reach exactly 11/11 with game_session only")
	_expect(child.contains('EXPECTED_CAPTURE_METHOD := "to_save_data"') \
			and child.contains('EXPECTED_CHECKPOINT_METHOD := "capture_runtime_checkpoint"') \
			and child.contains("owner_result[\"checkpoint_method\"]"), "child records the Session capture and checkpoint methods")
	_expect(child.contains('"total_remaining_owner_preflight_count"') \
			and child.contains('"total_remaining_owner_preflight_green_count"') \
			and child.contains('"final_session_owner_preflight_green"'), "child reports the final 11/11 gate")
	_expect(wrapper.contains("[IO.FileMode]::CreateNew") \
			and wrapper.contains("remaining_owner_preflight_attempt_ledger.json") \
			and wrapper.contains("remaining_owner_preflight_attempt_v4_already_claimed"), "parent owns one exclusive Attempt V4 ledger")
	_expect(wrapper.contains("scenario_identity_fingerprint") \
			and wrapper.contains("registry_binding_fingerprint") \
			and wrapper.contains("child_completion_sha256") \
			and wrapper.contains("parent_exit_sha256") \
			and wrapper.contains("started_at") \
			and wrapper.contains("completed_at") \
			and wrapper.contains("first_failure"), "ledger records every required atomic attestation field")
	_expect(wrapper.contains("victory_control_replay_v1_not_green") \
			and wrapper.contains("victory_replay_evidence_not_ancestor") \
			and wrapper.contains("pr77_victory_merge_not_ancestor"), "Victory replay and PR77 merge lineage are hard prerequisites")
	_expect(child.contains('"preflight_quota_claim_count": 0') \
			and child.contains('"preflight_full_owner_audit_count": 0') \
			and child.contains('"preflight_process_a_count": 0') \
			and child.contains('"v8_authorization_created": false'), "Attempt V4 cannot become V8, Process A, or diagnostic quota")
	_expect(wrapper.contains("preflight_production_fixed_slot_write_count") \
			and wrapper.contains('*.save*') \
			and wrapper.contains('*.backup*'), "parent independently rejects fixed-slot Save artifacts")
	_expect(not child.contains("capture_all_sections_detailed") \
			and not child.contains("capture_resume_envelope") \
			and not wrapper.contains("targeted_owner_capture_diagnostic_v2.gd") \
			and not wrapper.contains("process_a_rehearsal_completion_v1.gd"), "Attempt V4 remains one read-only Owner preflight")
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("REMAINING_OWNER_PREFLIGHT_ATTEMPT_V4_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	if not _failures.is_empty():
		push_error("Remaining Owner preflight Attempt V4 contract failed:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)
