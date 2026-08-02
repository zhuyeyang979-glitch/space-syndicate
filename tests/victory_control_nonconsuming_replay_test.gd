extends SceneTree

const IDENTITY := preload("res://scripts/tools/victory_control_owner_replay_scenario_identity_v1.gd")
const CHILD_SCRIPT := preload("res://scripts/tools/alpha04c_victory_control_nonconsuming_replay.gd")

const CHILD_PATH := "res://scripts/tools/alpha04c_victory_control_nonconsuming_replay.gd"
const WRAPPER_PATH := "res://scripts/tools/run_alpha04c_victory_control_nonconsuming_replay.ps1"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var authorization := IDENTITY.authorization()
	_expect(not authorization.is_empty(), "Victory replay authorization and evidence hashes are valid")
	_expect(int(authorization.get("replay_attempt_count_before", -1)) == 0 \
			and int(authorization.get("authorized_new_replay_count", -1)) == 1 \
			and int(authorization.get("replay_attempt_count_after", -1)) == 1, "authorization permits exactly one Victory replay")
	_expect(int(authorization.get("targeted_owner_capture_diagnostic_count_before", -1)) == 7 \
			and int(authorization.get("targeted_owner_capture_diagnostic_count_after", -1)) == 7, "Victory replay cannot consume targeted diagnostic quota")

	var identity := IDENTITY.build({
		"replay_id": IDENTITY.RUN_ID,
		"repository_head": "a".repeat(40),
		"scene_path": IDENTITY.SCENE_PATH,
		"registry_id": IDENTITY.REGISTRY_ID,
		"production_runtime_ruleset_id": IDENTITY.PRODUCTION_RUNTIME_RULESET_ID,
		"highest_target_ruleset_id": IDENTITY.HIGHEST_TARGET_RULESET_ID,
		"challenge_depth": IDENTITY.CHALLENGE_DEPTH,
		"run_seed": IDENTITY.RUN_SEED,
		"local_player_count": IDENTITY.LOCAL_PLAYER_COUNT,
		"ai_player_count": IDENTITY.AI_PLAYER_COUNT,
		"owner_index": IDENTITY.OWNER_INDEX,
		"section_id": IDENTITY.SECTION_ID,
		"owner_id": IDENTITY.OWNER_ID,
		"victory_save_schema_version": IDENTITY.SAVE_SCHEMA_VERSION,
		"victory_registry_state_version": IDENTITY.REGISTRY_STATE_VERSION,
		"victory_checkpoint_strategy": IDENTITY.CHECKPOINT_STRATEGY,
		"clock_domain_ruleset_id": IDENTITY.PRODUCTION_RUNTIME_RULESET_ID,
		"qualification_duration_seconds": IDENTITY.QUALIFICATION_DURATION_SECONDS,
		"public_audit_duration_seconds": IDENTITY.PUBLIC_AUDIT_DURATION_SECONDS,
	})
	_expect(bool(IDENTITY.validation_report(identity, "a".repeat(40)).get("valid", false)), "scenario identity validates the exact production configuration")
	_expect(int(identity.get("owner_index", -1)) == 17 \
			and str(identity.get("section_id", "")) == "victory_control" \
			and str(identity.get("owner_id", "")) == "victory_control", "identity binds only Owner index 17")
	_expect(int(identity.get("victory_save_schema_version", -1)) == 3 \
			and int(identity.get("victory_registry_state_version", -1)) == 2 \
			and str(identity.get("victory_checkpoint_strategy", "")) == "registry_managed_checkpoint", "identity binds Save v3, state v2, and Registry-managed checkpoint")
	_expect(str(identity.get("clock_domain_ruleset_id", "")) == "v0.6" \
			and int(identity.get("qualification_duration_seconds", -1)) == 10 \
			and int(identity.get("public_audit_duration_seconds", -1)) == 120 \
			and int(identity.get("timer_boundary_epsilon_micros", -1)) == 1, "identity preserves the v0.6 timer contract")
	_expect(not bool(identity.get("highest_target_ruleset_used_as_runtime_identity", true)) \
			and bool(identity.get("strict_semantic_wire_required", false)) \
			and str(identity.get("runtime_state_source", "")) == "legal_typed_world_facts_and_advance_world_effective", "identity keeps v0.6 runtime authority and typed state formation")

	var child := FileAccess.get_file_as_string(CHILD_PATH)
	var wrapper := FileAccess.get_file_as_string(WRAPPER_PATH)
	_expect(CHILD_SCRIPT != null and not child.is_empty() and not wrapper.is_empty(), "Victory replay child and parent parse and are present")
	_expect(child.contains("owner.advance_world_effective(2.125, first_world)") \
			and child.contains("owner.advance_world_effective(3.25, joint_world)") \
			and child.contains('"runtime_state_injected": false'), "child forms qualification only through legal typed facts")
	_expect(child.contains('str(target_binding.get("checkpoint_method", "")) == ""') \
			and child.contains('str(target_binding.get("rollback_method", "")) == "apply_save_data"') \
			and not child.contains('owner.capture_runtime_checkpoint()'), "child enforces the Registry-managed checkpoint strategy")
	_expect(child.contains("WIRE.is_closed_data(save_a)") \
			and child.contains("_raw_float_count(save_a) == 0") \
			and child.contains("save_a == save_b and save_a == save_c"), "child proves closed Save v3 and exact authoritative restore")
	_expect(child.contains('"victory_fresh_world_facts_gate_green"') \
			and child.contains('"duplicate_victory_outcome_count"') \
			and child.contains('"duplicate_final_settlement_count"'), "child proves fresh-facts and terminal exact-once boundaries")
	_expect(child.contains('"replay_diagnostic_count_delta": 0') \
			and child.contains('"replay_quota_claim_count": 0') \
			and child.contains('"replay_full_owner_audit_count": 0') \
			and child.contains('"replay_production_fixed_slot_write_count": 0') \
			and child.contains('"replay_process_a_count": 0'), "child cannot become V8, a fixed-slot Save, or Process A")
	_expect(wrapper.contains("[IO.FileMode]::CreateNew") \
			and wrapper.contains("victory_replay_attempt_already_claimed") \
			and wrapper.contains("replay_child_admission_consumed.json"), "parent provides one atomic replay admission")
	_expect(wrapper.contains("status --porcelain") \
			and wrapper.contains("victory_replay_remote_checkpoint_mismatch") \
			and wrapper.contains("WaitForExit(180000)"), "parent requires a clean pushed checkpoint and bounded child")
	_expect(wrapper.contains("immutable_v7_evidence_preserved") \
			and wrapper.contains("immutable_attempt_v3_evidence_preserved") \
			and wrapper.contains("remaining_owner_attempt_v4_root_created") \
			and wrapper.contains("v8_root_created"), "parent preserves earlier evidence and proves later phases did not start")
	_expect(not child.contains("targeted_owner_diagnostic") \
			and not child.contains("cold_restore_vertical_slice_orchestrator") \
			and not child.contains('FileAccess.open("user://saves/v06/current_run.save"'), "child is neither V8 nor a production Save writer")
	_expect(not wrapper.contains("[string]$EvidenceOutput") \
			and not wrapper.contains("[string]$ParentOutput"), "canonical replay evidence paths cannot be redirected")
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("VICTORY_CONTROL_NONCONSUMING_REPLAY_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	if not _failures.is_empty():
		push_error("Victory replay contract failed:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)
