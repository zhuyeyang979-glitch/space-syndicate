extends SceneTree

const IDENTITY := preload("res://scripts/tools/ai_runtime_owner_replay_scenario_identity_v1.gd")

const CHILD_PATH := "res://scripts/tools/alpha04c_ai_runtime_nonconsuming_replay.gd"
const WRAPPER_PATH := "res://scripts/tools/run_alpha04c_ai_runtime_nonconsuming_replay.ps1"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var authorization := IDENTITY.authorization()
	_expect(not authorization.is_empty(), "AI replay authorization is valid and evidence hashes match")
	_expect(int(authorization.get("replay_attempt_count_before", -1)) == 0 \
			and int(authorization.get("authorized_new_replay_count", -1)) == 1 \
			and int(authorization.get("replay_attempt_count_after", -1)) == 1, "authorization permits exactly one AI replay")
	_expect(int(authorization.get("targeted_owner_capture_diagnostic_count_before", -1)) == 7 \
			and int(authorization.get("targeted_owner_capture_diagnostic_count_after", -1)) == 7, "AI replay cannot consume diagnostic quota")

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
		"ai_save_schema_version": IDENTITY.SAVE_SCHEMA_VERSION,
		"ai_runtime_checkpoint_schema_version": IDENTITY.RUNTIME_CHECKPOINT_SCHEMA_VERSION,
		"ai_new_session_checkpoint_schema_version": IDENTITY.NEW_SESSION_CHECKPOINT_SCHEMA_VERSION,
		"ai_registry_state_version": IDENTITY.REGISTRY_STATE_VERSION,
		"ai_checkpoint_strategy": IDENTITY.CHECKPOINT_STRATEGY,
	})
	_expect(bool(IDENTITY.validation_report(identity, "a".repeat(40)).get("valid", false)), "scenario identity validates exact production configuration")
	_expect(str(identity.get("runtime_state_source", "")) == "production_runtime_loop_only" \
			and bool(identity.get("strict_semantic_wire_required", false)) \
			and not bool(identity.get("highest_target_ruleset_used_as_runtime_identity", true)), "identity binds RuntimeLoop, strict wire, and v0.6 runtime authority")
	_expect(int(identity.get("ai_save_schema_version", -1)) == 3 \
			and int(identity.get("ai_runtime_checkpoint_schema_version", -1)) == 2 \
			and int(identity.get("ai_new_session_checkpoint_schema_version", -1)) == 3 \
			and int(identity.get("ai_registry_state_version", -1)) == 3, "identity binds all upgraded AI versions")

	var child := FileAccess.get_file_as_string(CHILD_PATH)
	var wrapper := FileAccess.get_file_as_string(WRAPPER_PATH)
	_expect(not child.is_empty() and not wrapper.is_empty(), "AI replay child and parent are present")
	_expect(child.contains("AUTHORITATIVE_STEPPER.advance_bounded(runtime_loop, 0.5, 1)") \
			and child.contains("TERMINAL_EVIDENCE.acquire_manual_lease(context)") \
			and child.contains("runtime_loop_ai_action_count"), "child forms nondefault state through bounded production RuntimeLoop")
	_expect(child.contains('"runtime_memory_injected": false') \
			and child.contains('"runtime_action_injected": false') \
			and not child.contains("apply_ai_state_batch_for_restore"), "replay neither injects memory nor actor state")
	_expect(child.contains("owner.capture_runtime_checkpoint()") \
			and child.contains("owner.restore_runtime_checkpoint(") \
			and child.contains("checkpoint_a == checkpoint_b"), "checkpoint v2 performs an exact roundtrip")
	_expect(child.contains("save_a == save_b and save_a == save_c") \
			and child.contains("WIRE.is_closed_data(save_a)") \
			and child.contains("_raw_float_count(save_a) == 0"), "Save v3 remains strict closed wire with exact parity")
	_expect(child.contains('"duplicate_ai_action_submission_count"') \
			and child.contains('"duplicate_ai_business_cost_debit_count"') \
			and child.contains('"duplicate_ai_decision_sample_count"') \
			and child.contains('"duplicate_ai_learning_update_count"'), "replay records all exact-once deltas")
	_expect(child.contains('"replay_diagnostic_count_delta": 0') \
			and child.contains('"replay_quota_claim_count": 0') \
			and child.contains('"replay_full_owner_audit_count": 0') \
			and child.contains('"replay_production_fixed_slot_write_count": 0') \
			and child.contains('"replay_process_a_count": 0'), "replay cannot become V8, fixed-slot Save, or Process A")
	_expect(wrapper.contains("[IO.FileMode]::CreateNew") \
			and wrapper.contains("ai_runtime_replay_attempt_already_claimed") \
			and wrapper.contains("replay_child_admission_consumed.json"), "parent provides one atomic attempt and child admission")
	_expect(wrapper.contains("status --porcelain") \
			and wrapper.contains("ai_runtime_replay_remote_checkpoint_mismatch") \
			and wrapper.contains("WaitForExit(180000)"), "parent requires a clean pushed checkpoint and bounded child")
	_expect(wrapper.contains("immutable_v7_evidence_preserved") \
			and wrapper.contains("remaining_owner_attempt_v3_root_created") \
			and wrapper.contains("v8_root_created"), "parent preserves V7 and proves no later phase started")
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
	print("AI_RUNTIME_NONCONSUMING_REPLAY_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	if not _failures.is_empty():
		push_error("AI runtime replay contract failed:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)
