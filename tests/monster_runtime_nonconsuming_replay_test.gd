extends SceneTree

const CONTRACT := preload("res://scripts/tools/monster_runtime_owner_replay_scenario_identity_v1.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var child := FileAccess.get_file_as_string("res://scripts/tools/alpha04c_monster_runtime_nonconsuming_replay.gd")
	var wrapper := FileAccess.get_file_as_string("res://scripts/tools/run_alpha04c_monster_runtime_nonconsuming_replay.ps1")
	_expect(not child.is_empty() and not wrapper.is_empty(), "Monster replay child and parent are present")
	_expect(int(CONTRACT.authorization().get("authorized_new_replay_count", -1)) == 1, "one replay is authorized")
	_expect(child.contains("TARGET_OWNER_INDEX := REPLAY_IDENTITY.OWNER_INDEX") \
			and child.contains("TARGET_SECTION_ID := REPLAY_IDENTITY.SECTION_ID") \
			and child.contains("TARGET_OWNER_ID := REPLAY_IDENTITY.OWNER_ID"), "target identity has one source")
	_expect(child.contains('str(target_binding.get("checkpoint_method", "")) == ""') \
			and child.contains('str(target_binding.get("rollback_method", "")) == "apply_save_data"') \
			and not child.contains('owner.call("capture_runtime_checkpoint")'), "Monster replay enforces registry-managed checkpoint")
	_expect(child.contains('"replay_diagnostic_count_delta": 0') \
			and child.contains('"replay_quota_claim_count": 0') \
			and child.contains('"replay_full_owner_audit_count": 0') \
			and child.contains('"replay_production_fixed_slot_write_count": 0') \
			and child.contains('"replay_process_a_count": 0'), "child cannot claim diagnostics, audit Owners, write a fixed slot, or run Process A")
	_expect(wrapper.contains("FileMode]::CreateNew") \
			and wrapper.contains("monster_replay_attempt_already_claimed") \
			and wrapper.contains("replay_child_admission_consumed.json"), "parent provides an exclusive single-use attempt")
	_expect(wrapper.contains("immutable_v7_evidence_preserved") \
			and wrapper.contains("v8_root_created") \
			and wrapper.contains("isolated_appdata") \
			and wrapper.contains("isolated_localappdata"), "parent attests V7 immutability, no V8 root, and isolated user data")
	_expect(not child.contains("targeted_owner_diagnostic") \
			and not child.contains('FileAccess.open("user://current_run.save"'), "child is not a targeted diagnostic or production Save writer")
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("MONSTER_RUNTIME_NONCONSUMING_REPLAY_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	if not _failures.is_empty():
		push_error("Monster replay contract failures:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)
