extends SceneTree

const CHILD_PATH := "res://scripts/tools/alpha04c_card_resolution_execution_nonconsuming_replay_v2.gd"
const WRAPPER_PATH := "res://scripts/tools/run_alpha04c_card_resolution_execution_nonconsuming_replay_v2.ps1"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var child := FileAccess.get_file_as_string(CHILD_PATH)
	var wrapper := FileAccess.get_file_as_string(WRAPPER_PATH)
	_expect(not child.is_empty() and not wrapper.is_empty(), "replay v2 child and parent are present")
	_expect(child.contains("PROJECTION.capture(owner, transition)") \
			and child.contains("PROJECTION.compare(projection_a, projection_b)") \
			and child.contains("PROJECTION.diagnostic_canonicalization(owner)"), "authoritative parity and diagnostic canonicalization are separate gates")
	_expect(child.contains("EXACT_ONCE_PROBE.run(self)") \
			and child.contains('"duplicate_effect_dispatch_count"') \
			and child.contains('"duplicate_transition_command_apply_count"'), "replay v2 runs all exact-once probes")
	_expect(child.contains('"debug_snapshot_used_as_restore_authority": false') \
			and not child.contains("before_roundtrip == after_roundtrip"), "whole debug observation is not restore authority")
	_expect(child.contains("save_a == save_b and save_a == save_c") \
			and child.contains('int(projection_c.get("field_coverage_percent", 0)) == 100') \
			and child.contains('int(projection_c.get("save_v4_field_omission_count", -1)) == 0'), "Save wire and complete projection coverage remain mandatory")
	_expect(child.contains('str(target_binding.get("checkpoint_method", "")) == ""') \
			and not child.contains('owner.call("capture_runtime_checkpoint")'), "registry-managed checkpoint remains the only checkpoint strategy")
	_expect(wrapper.contains("FileMode]::CreateNew") \
			and wrapper.contains("execution_replay_v2_attempt_already_claimed") \
			and wrapper.contains("replay_child_admission_consumed.json"), "parent provides one atomic attempt and one child admission")
	_expect(wrapper.contains("execution_replay_v1_evidence_hash_mismatch") \
			and wrapper.contains("immutable_replay_v1_evidence_preserved") \
			and wrapper.contains("d9ceda8196dbc6aa4152c63cd7ec5c9ed0be98ed"), "parent preserves v1 evidence and repair lineage")
	_expect(wrapper.contains("status --porcelain") \
			and wrapper.contains("execution_replay_v2_remote_checkpoint_mismatch") \
			and wrapper.contains("WaitForExit(120000)"), "parent requires a clean pushed checkpoint and bounded process")
	_expect(child.contains('"replay_diagnostic_count_delta": 0') \
			and child.contains('"replay_quota_claim_count": 0') \
			and child.contains('"replay_full_owner_audit_count": 0') \
			and child.contains('"replay_process_a_count": 0'), "replay v2 cannot consume V8 quota, run full audit, or run Process A")
	_expect(not child.contains("targeted_owner_diagnostic") \
			and not child.contains('FileAccess.open("user://current_run.save"') \
			and not wrapper.contains("cold_restore_vertical_slice_orchestrator.ps1"), "replay v2 is neither V8 nor a production Save writer")
	_expect(not wrapper.contains("[string]$EvidenceOutput") \
			and not wrapper.contains("[string]$ParentOutput"), "canonical evidence paths cannot be redirected")
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("CARD_RESOLUTION_EXECUTION_NONCONSUMING_REPLAY_V2_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	if not _failures.is_empty():
		push_error("Execution replay v2 source contract failed:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)
