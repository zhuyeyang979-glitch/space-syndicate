extends SceneTree

const CONTRACT := preload("res://scripts/tools/card_resolution_execution_owner_replay_scenario_identity_v1.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var child := FileAccess.get_file_as_string("res://scripts/tools/alpha04c_card_resolution_execution_nonconsuming_replay.gd")
	var wrapper := FileAccess.get_file_as_string("res://scripts/tools/run_alpha04c_card_resolution_execution_nonconsuming_replay.ps1")
	_expect(not child.is_empty() and not wrapper.is_empty(), "Execution replay child and parent are present")
	_expect(int(CONTRACT.authorization().get("authorized_new_replay_count", -1)) == 1, "one replay is authorized")
	_expect(child.contains("TARGET_OWNER_INDEX := REPLAY_IDENTITY.OWNER_INDEX") \
			and child.contains("TARGET_SECTION_ID := REPLAY_IDENTITY.SECTION_ID") \
			and child.contains("TARGET_OWNER_ID := REPLAY_IDENTITY.OWNER_ID"), "target identity has one source")
	_expect(child.contains('str(target_binding.get("preflight_method", "")) == "preflight_save_data"') \
			and child.contains('str(target_binding.get("checkpoint_method", "")) == ""') \
			and child.contains('str(target_binding.get("rollback_method", "")) == "apply_save_data"') \
			and not child.contains('owner.call("capture_runtime_checkpoint")'), "Execution replay enforces registry-managed checkpoint")
	_expect(child.contains('WIRE.is_closed_data(save_a)') \
			and child.contains('CODEC.decode_save_state(save_a)') \
			and child.contains('owner.call("preflight_save_data", decoded_wire)') \
			and child.contains('owner.call("apply_save_data", decoded_wire)'), "replay uses strict wire and real preflight/apply boundaries")
	_expect(child.contains('"execution_timer_bits_parity"') \
			and child.contains('"execution_cadence_bits_parity"') \
			and child.contains('"inflight_transaction_parity"') \
			and child.contains('"pending_settlement_parity"') \
			and child.contains('"transition_lineage_parity"'), "replay attests timers, cadence, transactions, settlements, and lineage")
	_expect(child.contains('"replay_diagnostic_count_delta": 0') \
			and child.contains('"replay_quota_claim_count": 0') \
			and child.contains('"replay_full_owner_audit_count": 0') \
			and child.contains('"replay_production_fixed_slot_write_count": 0') \
			and child.contains('"replay_process_a_count": 0'), "child cannot claim diagnostics, audit Owners, write a fixed slot, or run Process A")
	_expect(wrapper.contains("FileMode]::CreateNew") \
			and wrapper.contains("execution_replay_attempt_already_claimed") \
			and wrapper.contains("replay_child_admission_consumed.json"), "parent provides an exclusive single-use attempt")
	_expect(wrapper.contains("immutable_v7_evidence_preserved") \
			and wrapper.contains("v8_root_created") \
			and wrapper.contains("isolated_appdata") \
			and wrapper.contains("isolated_localappdata"), "parent attests V7 immutability, no V8 root, and isolated user data")
	_expect(wrapper.contains("status --porcelain") \
			and wrapper.contains("execution_replay_remote_checkpoint_mismatch") \
			and wrapper.contains("pr77_execution_repair_baseline_not_ancestor"), "wrapper requires a clean pushed descendant of PR77")
	_expect(wrapper.contains("WaitForExit(120000)") \
			and wrapper.contains("Kill($true)") \
			and wrapper.contains("if (-not $process.HasExited)"), "wrapper bounds runtime and terminates only its process tree")
	_expect(not child.contains("targeted_owner_diagnostic") \
			and not child.contains('FileAccess.open("user://current_run.save"') \
			and not wrapper.contains("cold_restore_vertical_slice_orchestrator.ps1"), "replay is not V8, a production Save writer, or Process A")
	_expect(not wrapper.contains("[string]$EvidenceOutput") \
			and not wrapper.contains("[string]$ParentOutput"), "canonical evidence paths cannot be redirected")
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("CARD_RESOLUTION_EXECUTION_NONCONSUMING_REPLAY_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	if not _failures.is_empty():
		push_error("Execution replay contract failures:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)
