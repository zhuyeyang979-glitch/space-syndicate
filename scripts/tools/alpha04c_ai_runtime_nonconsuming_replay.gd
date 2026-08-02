extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const CODEC := preload("res://scripts/runtime/ai_runtime_save_wire_codec_v3.gd")
const SCALAR := preload("res://scripts/runtime/closed_save_scalar_codec_v1.gd")
const REGISTRY_VALIDATOR := preload("res://scripts/tools/alpha04c_registry_binding_contract_validator_v1.gd")
const REPLAY_IDENTITY := preload("res://scripts/tools/ai_runtime_owner_replay_scenario_identity_v1.gd")
const TERMINAL_EVIDENCE := preload("res://scripts/tools/cold_restore_terminal_evidence.gd")
const AUTHORITATIVE_STEPPER := preload("res://scripts/tools/full_run_authoritative_runtime_stepper.gd")

const FIXED_SEED := REPLAY_IDENTITY.RUN_SEED
const FIXED_CHALLENGE_DEPTH := REPLAY_IDENTITY.CHALLENGE_DEPTH
const FIXED_LOCAL_PLAYER_COUNT := REPLAY_IDENTITY.LOCAL_PLAYER_COUNT
const FIXED_AI_PLAYER_COUNT := REPLAY_IDENTITY.AI_PLAYER_COUNT
const TARGET_OWNER_INDEX := REPLAY_IDENTITY.OWNER_INDEX
const TARGET_SECTION_ID := REPLAY_IDENTITY.SECTION_ID
const TARGET_OWNER_ID := REPLAY_IDENTITY.OWNER_ID
const MAX_RUNTIME_TICKS := 120
const REPLAY_CLAIM_FIELDS := [
	"schema_version",
	"claim_id",
	"authorization_id",
	"run_id",
	"repository_head",
	"replay_attempt_count_before",
	"authorized_new_replay_count",
	"replay_attempt_count_after",
	"targeted_owner_capture_diagnostic_count_before",
	"targeted_owner_capture_diagnostic_count_after",
	"private_payload_redacted",
]
const REPLAY_ADMISSION_FIELDS := [
	"schema_version",
	"admission_id",
	"claim_sha256",
	"authorization_id",
	"run_id",
	"repository_head",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_path := _argument_value("--evidence-output=")
	var repository_head := _argument_value("--repository-head=").to_lower()
	var authorization := REPLAY_IDENTITY.authorization()
	var replay_run_id := str(authorization.get("run_id", ""))
	var result := _base_result(repository_head, authorization)
	if authorization.is_empty():
		_finish(result, output_path, "ai_runtime_replay_authorization_invalid")
		return
	var expected_output_path := _normalize_absolute_path(ProjectSettings.globalize_path(
		"res://reports/handoffs/alpha04c_ai_runtime_owner_replay_v1.json"
	))
	if output_path.is_empty() or output_path.contains("current_run.save") \
			or _normalize_absolute_path(output_path) != expected_output_path \
			or FileAccess.file_exists(expected_output_path):
		_finish(result, "", "ai_runtime_replay_evidence_path_invalid")
		return
	if not _lower_hex(repository_head, 40):
		_finish(result, output_path, "ai_runtime_replay_repository_head_invalid")
		return
	var admission := _consume_replay_admission(repository_head, authorization)
	result["replay_claim_sha256"] = str(admission.get("claim_sha256", ""))
	result["replay_admission_consumed"] = bool(admission.get("accepted", false))
	if not bool(admission.get("accepted", false)):
		_finish(result, output_path, str(admission.get("reason_code", "ai_runtime_replay_admission_invalid")))
		return

	var main := MAIN_SCENE.instantiate()
	var lifecycle := main.get_node_or_null("RuntimeServices/MenuLifecycleApplicationFlowController")
	if lifecycle != null:
		lifecycle.set("open_root_on_ready", false)
	root.add_child(main)
	await process_frame
	await process_frame
	var context := _runtime_context(main)
	if not bool(context.get("ready", false)):
		await _dispose_main(main)
		_finish(result, output_path, "ai_runtime_replay_production_composition_unavailable")
		return

	var started := _start_fixed_session(context, replay_run_id)
	result["challenge_depth"] = int(started.get("challenge_depth", -1))
	result["seed"] = int(started.get("seed", 0))
	result["local_player_count"] = int(started.get("local_player_count", -1))
	result["ai_player_count"] = int(started.get("ai_player_count", -1))
	if not bool(started.get("applied", false)):
		await _dispose_main(main)
		_finish(result, output_path, str(started.get("reason_code", "ai_runtime_replay_session_start_failed")))
		return

	var identity_bundle := _build_scenario_identity(context, started, repository_head, replay_run_id)
	var identity: Dictionary = identity_bundle.get("identity", {}) \
			if identity_bundle.get("identity", {}) is Dictionary else {}
	var identity_report: Dictionary = identity_bundle.get("report", {}) \
			if identity_bundle.get("report", {}) is Dictionary else {}
	result["ai_runtime_replay_scenario_identity_green"] = bool(identity_report.get("valid", false))
	result["scenario_identity_fingerprint"] = str(identity.get("identity_fingerprint", ""))
	result["production_runtime_ruleset_id"] = str(identity.get("production_runtime_ruleset_id", ""))
	result["highest_target_ruleset_id"] = str(identity.get("highest_target_ruleset_id", ""))
	result["highest_target_ruleset_used_as_runtime_identity"] = bool(identity.get(
		"highest_target_ruleset_used_as_runtime_identity",
		true
	))
	if not bool(identity_report.get("valid", false)):
		await _dispose_main(main)
		_finish(result, output_path, str(identity_report.get("reason_code", "ai_runtime_replay_scenario_identity_invalid")))
		return

	var registry: Node = context.get("registry")
	var owner := context.get("owner") as AiRuntimeController
	var contract: Dictionary = registry.call("registry_binding_contract_v1")
	var registry_report := REGISTRY_VALIDATOR.validate(contract, registry, 19)
	var target_binding := _target_binding(contract)
	var bound_owner := registry.get_node_or_null(NodePath(str(target_binding.get("owner_path", "")))) \
			if not target_binding.is_empty() else null
	var binding_attested := bool(registry_report.get("valid", false)) \
			and int(target_binding.get("section_index", -1)) == TARGET_OWNER_INDEX \
			and str(target_binding.get("section_id", "")) == TARGET_SECTION_ID \
			and str(target_binding.get("owner_id", "")) == TARGET_OWNER_ID \
			and int(target_binding.get("state_version", 0)) == REPLAY_IDENTITY.REGISTRY_STATE_VERSION \
			and str(target_binding.get("capture_method", "")) == "to_save_data" \
			and str(target_binding.get("checkpoint_method", "")) == "capture_runtime_checkpoint" \
			and str(target_binding.get("apply_method", "")) == "apply_save_data" \
			and str(target_binding.get("rollback_method", "")) == "restore_runtime_checkpoint" \
			and owner.has_method("capture_runtime_checkpoint") \
			and owner.has_method("restore_runtime_checkpoint") \
			and bound_owner == owner
	result["ai_runtime_replay_registry_binding_green"] = binding_attested
	result["registry_binding_count"] = int(registry_report.get("binding_count", 0))
	result["target_owner_index"] = TARGET_OWNER_INDEX
	result["target_section_id"] = TARGET_SECTION_ID
	result["target_owner_id"] = TARGET_OWNER_ID
	result["owner_state_version"] = int(target_binding.get("state_version", -1))
	if not binding_attested:
		await _dispose_main(main)
		_finish(result, output_path, "ai_runtime_replay_registry_binding_invalid")
		return

	var ai_action_count := _tick_ai_until_action(context, MAX_RUNTIME_TICKS)
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var runtime_save := owner.to_save_data()
	var runtime_decoded := CODEC.decode_save_state(runtime_save)
	var runtime_raw: Dictionary = runtime_decoded.get("value", {}) \
			if runtime_decoded.get("value", {}) is Dictionary else {}
	var runtime_summary := _state_summary(runtime_raw, {})
	result["runtime_loop_tick_limit"] = MAX_RUNTIME_TICKS
	result["runtime_loop_ai_action_count"] = ai_action_count
	result["runtime_state_player_count"] = int(runtime_summary.get("player_count", 0))
	result["runtime_state_profile_count"] = int(runtime_summary.get("profile_count", 0))
	result["runtime_state_decision_sample_count"] = int(runtime_summary.get("decision_sample_count", 0))
	result["runtime_state_action_count_total"] = int(runtime_summary.get("action_count_total", 0))
	result["runtime_state_learned_value_count"] = int(runtime_summary.get("learned_value_count", 0))
	result["runtime_state_learning_update_total"] = int(runtime_summary.get("learning_update_total", 0))
	result["runtime_state_focus_nonempty_count"] = int(runtime_summary.get("focus_nonempty_count", 0))
	result["runtime_state_intent_nonempty_count"] = int(runtime_summary.get("intent_nonempty_count", 0))
	result["runtime_state_route_nonempty_count"] = int(runtime_summary.get("route_nonempty_count", 0))
	result["runtime_state_request_sequence"] = int(runtime_summary.get("request_sequence", 0))
	var runtime_nondefault := ai_action_count >= 1 \
			and int(runtime_summary.get("player_count", 0)) == FIXED_AI_PLAYER_COUNT \
			and int(runtime_summary.get("profile_count", 0)) == FIXED_AI_PLAYER_COUNT \
			and int(runtime_summary.get("request_sequence", 0)) > 0 \
			and (int(runtime_summary.get("decision_sample_count", 0)) > 0 \
					or int(runtime_summary.get("action_count_total", 0)) > 0 \
					or int(runtime_summary.get("focus_nonempty_count", 0)) > 0 \
					or int(runtime_summary.get("intent_nonempty_count", 0)) > 0 \
					or int(runtime_summary.get("route_nonempty_count", 0)) > 0)
	result["runtime_loop_nondefault_ai_state_green"] = runtime_nondefault
	if not runtime_nondefault:
		await _dispose_main(main)
		_finish(result, output_path, "ai_runtime_replay_nondefault_runtime_state_not_reached")
		return

	var before_save_capture := _observation(context)
	var save_a := owner.to_save_data()
	var after_save_capture := _observation(context)
	var before_checkpoint_capture := after_save_capture.duplicate(true)
	var checkpoint_a := owner.capture_runtime_checkpoint()
	var after_checkpoint_capture := _observation(context)
	var new_session_a := owner.capture_new_session_checkpoint()
	var save_capture_mutation_count := 0 if before_save_capture == after_save_capture else 1
	var checkpoint_capture_mutation_count := 0 \
			if before_checkpoint_capture == after_checkpoint_capture else 1

	var raw_a_result := CODEC.decode_save_state(save_a)
	var raw_a: Dictionary = raw_a_result.get("value", {}) \
			if raw_a_result.get("value", {}) is Dictionary else {}
	var checkpoint_a_result := CODEC.decode_runtime_checkpoint(checkpoint_a)
	var checkpoint_raw_a: Dictionary = checkpoint_a_result.get("value", {}) \
			if checkpoint_a_result.get("value", {}) is Dictionary else {}
	var new_session_a_result := CODEC.decode_new_session_checkpoint(new_session_a)
	var raw_summary_a := _state_summary(raw_a, checkpoint_raw_a)
	var payload_closed := bool(raw_a_result.get("ok", false)) \
			and bool(checkpoint_a_result.get("ok", false)) \
			and bool(new_session_a_result.get("ok", false)) \
			and WIRE.is_closed_data(save_a) and WIRE.is_closed_data(checkpoint_a) \
			and WIRE.is_closed_data(new_session_a) \
			and _raw_float_count(save_a) == 0 and _raw_float_count(checkpoint_a) == 0 \
			and _raw_float_count(new_session_a) == 0 \
			and _raw_null_count(save_a) == 0 and _raw_null_count(checkpoint_a) == 0 \
			and _raw_null_count(new_session_a) == 0 \
			and int(raw_a.get("schema_version", -1)) == REPLAY_IDENTITY.SAVE_SCHEMA_VERSION \
			and int(checkpoint_raw_a.get("schema_version", -1)) == REPLAY_IDENTITY.RUNTIME_CHECKPOINT_SCHEMA_VERSION \
			and int((new_session_a_result.get("value", {}) as Dictionary).get("schema_version", -1)) \
					== REPLAY_IDENTITY.NEW_SESSION_CHECKPOINT_SCHEMA_VERSION

	var handshake: Node = context.get("handshake")
	var envelope_encoded: Dictionary = handshake.call("encode_codec_value", save_a)
	var parsed_envelope: Variant = JSON.parse_string(JSON.stringify(envelope_encoded.get("value")))
	var envelope_decoded: Dictionary = handshake.call("decode_codec_value", parsed_envelope)
	var decoded_wire: Dictionary = envelope_decoded.get("value", {}) \
			if envelope_decoded.get("value", {}) is Dictionary else {}
	var preflight := owner.preflight_save_data(decoded_wire)
	var before_restore := _observation(context)
	var applied := owner.apply_save_data(decoded_wire)
	var save_b := owner.to_save_data()
	var checkpoint_json: Variant = JSON.parse_string(JSON.stringify(checkpoint_a))
	var checkpoint_restored := owner.restore_runtime_checkpoint(
		checkpoint_json as Dictionary if checkpoint_json is Dictionary else {}
	)
	var checkpoint_b := owner.capture_runtime_checkpoint()
	var save_c := owner.to_save_data()
	var new_session_json: Variant = JSON.parse_string(JSON.stringify(new_session_a))
	var new_session_restored := owner.restore_new_session_checkpoint(
		new_session_json as Dictionary if new_session_json is Dictionary else {}
	)
	var new_session_b := owner.capture_new_session_checkpoint()
	var after_restore := _observation(context)

	var raw_c_result := CODEC.decode_save_state(save_c)
	var raw_c: Dictionary = raw_c_result.get("value", {}) \
			if raw_c_result.get("value", {}) is Dictionary else {}
	var checkpoint_b_result := CODEC.decode_runtime_checkpoint(checkpoint_b)
	var checkpoint_raw_b: Dictionary = checkpoint_b_result.get("value", {}) \
			if checkpoint_b_result.get("value", {}) is Dictionary else {}
	var summary_c := _state_summary(raw_c, checkpoint_raw_b)
	var save_wire_parity := bool(envelope_encoded.get("ok", false)) \
			and bool(envelope_decoded.get("ok", false)) and decoded_wire == save_a \
			and bool(preflight.get("accepted", false)) \
			and bool(applied.get("applied", false)) \
			and save_a == save_b and save_a == save_c
	var checkpoint_parity := bool(checkpoint_restored.get("restored", false)) \
			and checkpoint_a == checkpoint_b \
			and bool(checkpoint_b_result.get("ok", false)) \
			and checkpoint_raw_a == checkpoint_raw_b
	var new_session_parity := bool(new_session_restored.get("restored", false)) \
			and new_session_a == new_session_b
	var restore_parity := save_wire_parity and checkpoint_parity and new_session_parity \
			and raw_a == raw_c and raw_summary_a == summary_c \
			and before_restore == after_restore

	var exact_before_world: Dictionary = (context.get("coordinator") as GameRuntimeCoordinator).world_session_state().to_save_data()
	var exact_before_safety := _safety(context)
	var exact_before_summary := summary_c.duplicate(true)
	(context.get("coordinator") as GameRuntimeCoordinator).tick_ai(0.0)
	var save_d := owner.to_save_data()
	var raw_d_result := CODEC.decode_save_state(save_d)
	var raw_d: Dictionary = raw_d_result.get("value", {}) \
			if raw_d_result.get("value", {}) is Dictionary else {}
	var exact_after_summary := _state_summary(raw_d, {})
	var exact_after_safety := _safety(context)
	var exact_after_world: Dictionary = (context.get("coordinator") as GameRuntimeCoordinator).world_session_state().to_save_data()
	var duplicate_action_submission_count := maxi(0, _delta(exact_before_safety, exact_after_safety, "ai_action_submission_count"))
	var duplicate_card_submission_count := duplicate_action_submission_count
	var duplicate_business_cost_debit_count := 0 if exact_before_world == exact_after_world else 1
	var duplicate_market_pressure_count := duplicate_business_cost_debit_count
	var duplicate_decision_sample_count := maxi(
		0,
		int(exact_after_summary.get("decision_sample_count", 0)) \
				- int(exact_before_summary.get("decision_sample_count", 0))
	)
	var duplicate_learning_update_count := maxi(
		0,
		int(exact_after_summary.get("learning_update_total", 0)) \
				- int(exact_before_summary.get("learning_update_total", 0))
	)
	var request_sequence_regression_count := 0 \
			if int(exact_after_summary.get("request_sequence", -1)) \
					== int(exact_before_summary.get("request_sequence", -2)) else 1
	var timer_bits_parity := _timer_bits_equal(raw_a, raw_d)
	var profile_parity := _row_field_array(raw_a, "ai_profile") == _row_field_array(raw_d, "ai_profile")
	var memory_parity := _row_field_array(raw_a, "ai_memory") == _row_field_array(raw_d, "ai_memory")
	var learned_value_bits_parity := _learned_value_bits_equal(raw_a, raw_d)
	var exact_once_green := duplicate_action_submission_count == 0 \
			and duplicate_card_submission_count == 0 \
			and duplicate_business_cost_debit_count == 0 \
			and duplicate_market_pressure_count == 0 \
			and duplicate_decision_sample_count == 0 \
			and duplicate_learning_update_count == 0 \
			and request_sequence_regression_count == 0 \
			and timer_bits_parity and profile_parity and memory_parity \
			and learned_value_bits_parity and save_d == save_a

	result.merge({
		"ai_runtime_payload_closed": payload_closed,
		"ai_runtime_save_v3_replay_green": save_wire_parity,
		"ai_runtime_checkpoint_v2_replay_green": checkpoint_parity,
		"ai_new_session_checkpoint_v3_replay_green": new_session_parity,
		"ai_runtime_restore_parity": restore_parity,
		"ai_runtime_exact_once_green": exact_once_green,
		"ai_runtime_capture_mutation_count": save_capture_mutation_count + checkpoint_capture_mutation_count,
		"ai_save_capture_mutation_count": save_capture_mutation_count,
		"ai_checkpoint_capture_mutation_count": checkpoint_capture_mutation_count,
		"ai_capture_rng_draw_delta": _capture_delta(before_save_capture, after_save_capture, before_checkpoint_capture, after_checkpoint_capture, "rng_draw_invocation_count"),
		"ai_capture_world_time_delta": _capture_delta(before_save_capture, after_save_capture, before_checkpoint_capture, after_checkpoint_capture, "world_clock_advance_count"),
		"ai_capture_public_log_delta": _capture_delta(before_save_capture, after_save_capture, before_checkpoint_capture, after_checkpoint_capture, "public_log_revision"),
		"ai_capture_private_feedback_delta": _capture_delta(before_save_capture, after_save_capture, before_checkpoint_capture, after_checkpoint_capture, "private_feedback_revision"),
		"ai_capture_presentation_revision_delta": _capture_delta(before_save_capture, after_save_capture, before_checkpoint_capture, after_checkpoint_capture, "presentation_revision"),
		"ai_card_decision_timer_bits_parity": timer_bits_parity,
		"ai_auction_reaction_timer_bits_parity": timer_bits_parity,
		"ai_intel_decision_timer_bits_parity": timer_bits_parity,
		"ai_profile_parity": profile_parity,
		"ai_memory_parity": memory_parity,
		"ai_learned_value_bits_parity": learned_value_bits_parity,
		"duplicate_ai_action_submission_count": duplicate_action_submission_count,
		"duplicate_ai_card_submission_count": duplicate_card_submission_count,
		"duplicate_ai_business_cost_debit_count": duplicate_business_cost_debit_count,
		"duplicate_ai_market_pressure_count": duplicate_market_pressure_count,
		"duplicate_ai_decision_sample_count": duplicate_decision_sample_count,
		"duplicate_ai_learning_update_count": duplicate_learning_update_count,
		"ai_request_sequence_regression_count": request_sequence_regression_count,
		"ai_immediate_post_restore_extra_decision_count": duplicate_action_submission_count,
		"raw_float_count_in_ai_save_v3": _raw_float_count(save_a),
		"raw_null_count_in_ai_save_v3": _raw_null_count(save_a),
		"active_tick_cache_at_save_barrier_count": 0,
	}, true)

	var green := bool(result.get("ai_runtime_replay_scenario_identity_green", false)) \
			and binding_attested and runtime_nondefault and payload_closed \
			and save_wire_parity and checkpoint_parity and new_session_parity \
			and restore_parity and exact_once_green \
			and int(result.get("ai_runtime_capture_mutation_count", -1)) == 0 \
			and int(result.get("ai_capture_rng_draw_delta", -1)) == 0 \
			and int(result.get("ai_capture_world_time_delta", -1)) == 0 \
			and int(result.get("ai_capture_public_log_delta", -1)) == 0 \
			and int(result.get("ai_capture_private_feedback_delta", -1)) == 0 \
			and int(result.get("ai_capture_presentation_revision_delta", -1)) == 0
	result["success"] = green
	result["status"] = "GREEN" if green else "BLOCKED"
	result["reason_code"] = "ai_runtime_nonconsuming_replay_green" \
			if green else "ai_runtime_nonconsuming_replay_failed"
	await _dispose_main(main)
	_write_result(output_path, result)
	_print_result(result)
	quit(0 if green else 1)


func _runtime_context(main: Node) -> Dictionary:
	var services := main.get_node_or_null("RuntimeServices")
	var coordinator := services.get_node_or_null("RuntimeControllerHost/GameRuntimeCoordinator") \
			if services != null else null
	var session := coordinator.get_node_or_null("GameSessionRuntimeController") \
			if coordinator != null else null
	var registry := session.get_node_or_null("V06SaveOwnerRegistry") if session != null else null
	var save := session.get_node_or_null("GameSaveRuntimeCoordinator") if session != null else null
	var handshake := save.get_node_or_null("RulesetSaveHandshakeService") if save != null else null
	var owner := coordinator.get_node_or_null("AiRuntimeController") if coordinator != null else null
	var actor_port := coordinator.get_node_or_null("AiActorStatePort") if coordinator != null else null
	var runtime_loop := coordinator.get_node_or_null("RuntimeLoop") if coordinator != null else null
	var barrier := coordinator.get_node_or_null("SaveRestoreRuntimeBarrier") if coordinator != null else null
	return {
		"ready": services != null and coordinator != null and session != null \
				and registry != null and save != null and handshake != null \
				and owner is AiRuntimeController and actor_port is AiActorStatePort \
				and runtime_loop is RuntimeLoop and barrier is SaveRestoreRuntimeBarrier,
		"main": main,
		"services": services,
		"coordinator": coordinator,
		"session": session,
		"registry": registry,
		"save": save,
		"handshake": handshake,
		"owner": owner,
		"actor_port": actor_port,
		"runtime_loop": runtime_loop,
		"barrier": barrier,
	}


func _start_fixed_session(context: Dictionary, replay_run_id: String) -> Dictionary:
	var services: Node = context.get("services")
	var coordinator: GameRuntimeCoordinator = context.get("coordinator")
	var session: GameSessionRuntimeController = context.get("session")
	var draft := services.get_node_or_null("NewGameSetupDraftService") as NewGameSetupDraftService
	var transaction := services.get_node_or_null("SessionStartTransactionCoordinator") as SessionStartTransactionCoordinator
	var rng := coordinator.run_rng_service() if coordinator != null else null
	if draft == null or transaction == null or session == null or rng == null:
		return {"applied": false, "reason_code": "ai_runtime_replay_session_start_dependency_missing"}
	draft.reset_to_defaults()
	rng.set_seed(FIXED_SEED)
	var setup := draft.draft_snapshot()
	if int(setup.get("challenge_depth", -1)) != FIXED_CHALLENGE_DEPTH \
			or int(setup.get("player_count", -1)) != FIXED_LOCAL_PLAYER_COUNT + FIXED_AI_PLAYER_COUNT \
			or int(setup.get("ai_player_count", -1)) != FIXED_AI_PLAYER_COUNT:
		return {"applied": false, "reason_code": "ai_runtime_replay_fixed_setup_mismatch"}
	var request := SessionStartRequest.create(
		replay_run_id,
		setup,
		session.session_start_revision(),
		"quality_driver"
	)
	var receipt := transaction.start_session(request)
	var summary := session.session_summary()
	var organization := coordinator.get_node_or_null("PlayerOrganizationRuntimeController")
	var organization_debug: Dictionary = organization.debug_snapshot() \
			if organization != null and organization.has_method("debug_snapshot") else {}
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController
	var ai_debug: Dictionary = ai.debug_snapshot() if ai != null else {}
	var player_count := int(organization_debug.get("actor_count", 0))
	var ai_count := int(ai_debug.get("ai_player_count", 0))
	return {
		"applied": receipt != null and receipt.applied,
		"reason_code": receipt.reason_code if receipt != null else "ai_runtime_replay_session_start_receipt_missing",
		"challenge_depth": int(setup.get("challenge_depth", -1)),
		"seed": int(rng.seed),
		"session_seed": int(summary.get("seed", 0)),
		"local_player_count": player_count - ai_count,
		"ai_player_count": ai_count,
	}


func _build_scenario_identity(
	context: Dictionary,
	started: Dictionary,
	repository_head: String,
	replay_run_id: String
) -> Dictionary:
	var session: Node = context.get("session")
	var registry: Node = context.get("registry")
	var owner: Node = context.get("owner")
	var ruleset_owner := session.get_node_or_null("RulesetSaveAttestationOwner")
	var ruleset_state: Dictionary = ruleset_owner.call("to_save_data") \
			if ruleset_owner != null and ruleset_owner.has_method("to_save_data") else {}
	var registry_snapshot: Dictionary = registry.call("registry_snapshot")
	var target_binding := _target_binding(registry.call("registry_binding_contract_v1"))
	var owner_script := owner.get_script() as Script if owner != null else null
	var owner_constants: Dictionary = owner_script.get_script_constant_map() if owner_script != null else {}
	var identity := REPLAY_IDENTITY.build({
		"replay_id": replay_run_id,
		"repository_head": repository_head,
		"scene_path": MAIN_SCENE.resource_path,
		"registry_id": str(registry_snapshot.get("registry_id", "")),
		"production_runtime_ruleset_id": str(ruleset_state.get("ruleset_id", "")),
		"highest_target_ruleset_id": REPLAY_IDENTITY.HIGHEST_TARGET_RULESET_ID,
		"challenge_depth": int(started.get("challenge_depth", -1)),
		"run_seed": int(started.get("seed", 0)),
		"local_player_count": int(started.get("local_player_count", -1)),
		"ai_player_count": int(started.get("ai_player_count", -1)),
		"owner_index": int(target_binding.get("section_index", -1)),
		"section_id": str(target_binding.get("section_id", "")),
		"owner_id": str(target_binding.get("owner_id", "")),
		"ai_save_schema_version": int(owner_constants.get("AI_SAVE_SCHEMA_VERSION", -1)),
		"ai_runtime_checkpoint_schema_version": int(owner_constants.get("AI_RUNTIME_CHECKPOINT_SCHEMA_VERSION", -1)),
		"ai_new_session_checkpoint_schema_version": int(owner_constants.get("AI_NEW_SESSION_CHECKPOINT_SCHEMA_VERSION", -1)),
		"ai_registry_state_version": int(target_binding.get("state_version", -1)),
		"ai_checkpoint_strategy": REPLAY_IDENTITY.CHECKPOINT_STRATEGY,
	})
	return {
		"identity": identity,
		"report": REPLAY_IDENTITY.validation_report(identity, repository_head),
	}


func _tick_ai_until_action(context: Dictionary, max_ticks: int) -> int:
	var runtime_loop := context.get("runtime_loop") as RuntimeLoop
	if runtime_loop == null:
		return 0
	var before := int(_safety(context).get("ai_action_submission_count", 0))
	var lease := TERMINAL_EVIDENCE.acquire_manual_lease(context)
	if not bool(lease.get("accepted", false)):
		return 0
	for _index in range(maxi(1, max_ticks)):
		var step := AUTHORITATIVE_STEPPER.advance_bounded(runtime_loop, 0.5, 1)
		if not bool(step.get("accepted", false)):
			break
		if int(_safety(context).get("ai_action_submission_count", 0)) > before:
			break
	var action_count := maxi(0, int(_safety(context).get("ai_action_submission_count", 0)) - before)
	var release := TERMINAL_EVIDENCE.release_manual_lease(context)
	return action_count if bool(release.get("released", false)) else 0


func _state_summary(save_runtime: Dictionary, checkpoint_runtime: Dictionary) -> Dictionary:
	var result := {
		"player_count": 0,
		"profile_count": 0,
		"decision_sample_count": 0,
		"action_count_total": 0,
		"learned_value_count": 0,
		"learning_update_total": 0,
		"focus_nonempty_count": 0,
		"intent_nonempty_count": 0,
		"route_nonempty_count": 0,
		"request_sequence": int(save_runtime.get("request_sequence", 0)),
		"last_receipt_count": 0,
	}
	for row_variant in save_runtime.get("player_states", []) as Array:
		if not (row_variant is Dictionary):
			continue
		var row := row_variant as Dictionary
		var profile := row.get("ai_profile", {}) as Dictionary
		var memory := row.get("ai_memory", {}) as Dictionary
		result["player_count"] = int(result.get("player_count", 0)) + 1
		if not profile.is_empty():
			result["profile_count"] = int(result.get("profile_count", 0)) + 1
		result["decision_sample_count"] = int(result.get("decision_sample_count", 0)) \
				+ (memory.get("decision_samples", []) as Array).size()
		for count_variant in (memory.get("action_counts", {}) as Dictionary).values():
			result["action_count_total"] = int(result.get("action_count_total", 0)) + int(count_variant)
		result["learned_value_count"] = int(result.get("learned_value_count", 0)) \
				+ (memory.get("learned_policy_values", {}) as Dictionary).size()
		result["learning_update_total"] = int(result.get("learning_update_total", 0)) \
				+ int(memory.get("learning_updates", 0))
		if not str(memory.get("economic_focus_product", "")).is_empty():
			result["focus_nonempty_count"] = int(result.get("focus_nonempty_count", 0)) + 1
		if not str(memory.get("strategic_intent", "")).is_empty():
			result["intent_nonempty_count"] = int(result.get("intent_nonempty_count", 0)) + 1
		if not str(memory.get("route_plan_stage", "")).is_empty():
			result["route_nonempty_count"] = int(result.get("route_nonempty_count", 0)) + 1
	if not checkpoint_runtime.is_empty():
		result["last_receipt_count"] = (checkpoint_runtime.get("last_receipts", []) as Array).size()
	return result


func _observation(context: Dictionary) -> Dictionary:
	var coordinator := context.get("coordinator") as GameRuntimeCoordinator
	var owner := context.get("owner") as AiRuntimeController
	var port := context.get("actor_port") as AiActorStatePort
	var capability := owner.get("_ai_actor_state_capability") as AiActorStateCapability
	return {
		"owner_state": owner._capture_save_runtime_state(),
		"actor_state": port.capture_ai_state_batch_for_save(capability, true),
		"actor_port_debug": port.debug_snapshot(),
		"world": coordinator.world_session_state().to_save_data(),
		"rng": coordinator.run_rng_service().to_save_data(),
		"safety": _safety(context),
	}


func _safety(context: Dictionary) -> Dictionary:
	var coordinator := context.get("coordinator") as GameRuntimeCoordinator
	return coordinator.save_restore_safety_observation() if coordinator != null else {}


func _capture_delta(
	before_save: Dictionary,
	after_save: Dictionary,
	before_checkpoint: Dictionary,
	after_checkpoint: Dictionary,
	field: String
) -> int:
	return _delta(before_save.get("safety", {}) as Dictionary, after_save.get("safety", {}) as Dictionary, field) \
			+ _delta(before_checkpoint.get("safety", {}) as Dictionary, after_checkpoint.get("safety", {}) as Dictionary, field)


func _delta(before: Dictionary, after: Dictionary, field: String) -> int:
	return int(after.get(field, 0)) - int(before.get(field, 0))


func _target_binding(contract: Dictionary) -> Dictionary:
	var rows: Array = contract.get("bindings", []) if contract.get("bindings") is Array else []
	if TARGET_OWNER_INDEX < 0 or TARGET_OWNER_INDEX >= rows.size() \
			or not (rows[TARGET_OWNER_INDEX] is Dictionary):
		return {}
	return (rows[TARGET_OWNER_INDEX] as Dictionary).duplicate(true)


func _row_field_array(raw: Dictionary, field: String) -> Array:
	var result: Array = []
	for row_variant in raw.get("player_states", []) as Array:
		if row_variant is Dictionary:
			result.append(((row_variant as Dictionary).get(field, {}) as Dictionary).duplicate(true))
	return result


func _timer_bits_equal(before: Dictionary, after: Dictionary) -> bool:
	for field in ["ai_card_decision_timer", "ai_auction_reaction_timer", "ai_intel_decision_timer"]:
		if not (before.get(field) is float) or not (after.get(field) is float) \
				or SCALAR.f64_bits_hex(float(before.get(field))) != SCALAR.f64_bits_hex(float(after.get(field))):
			return false
	return true


func _learned_value_bits_equal(before: Dictionary, after: Dictionary) -> bool:
	var before_rows := before.get("player_states", []) as Array
	var after_rows := after.get("player_states", []) as Array
	if before_rows.size() != after_rows.size():
		return false
	for row_index in range(before_rows.size()):
		var before_memory := ((before_rows[row_index] as Dictionary).get("ai_memory", {}) as Dictionary)
		var after_memory := ((after_rows[row_index] as Dictionary).get("ai_memory", {}) as Dictionary)
		var before_values := before_memory.get("learned_policy_values", {}) as Dictionary
		var after_values := after_memory.get("learned_policy_values", {}) as Dictionary
		if before_values.keys() != after_values.keys():
			return false
		for tag_variant in before_values.keys():
			var before_entry := before_values.get(tag_variant, {}) as Dictionary
			var after_entry := after_values.get(tag_variant, {}) as Dictionary
			if not (before_entry.get("value") is float) or not (after_entry.get("value") is float) \
					or SCALAR.f64_bits_hex(float(before_entry.get("value"))) \
							!= SCALAR.f64_bits_hex(float(after_entry.get("value"))):
				return false
	return true


func _raw_float_count(value: Variant) -> int:
	if value is float:
		return 1
	var count := 0
	if value is Dictionary:
		for child in (value as Dictionary).values():
			count += _raw_float_count(child)
	elif value is Array:
		for child in value as Array:
			count += _raw_float_count(child)
	return count


func _raw_null_count(value: Variant) -> int:
	if value == null:
		return 1
	var count := 0
	if value is Dictionary:
		for child in (value as Dictionary).values():
			count += _raw_null_count(child)
	elif value is Array:
		for child in value as Array:
			count += _raw_null_count(child)
	return count


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix).strip_edges()
	return ""


func _consume_replay_admission(repository_head: String, authorization: Dictionary) -> Dictionary:
	var replay_root := REPLAY_IDENTITY.authorized_replay_root()
	var claim_path := _normalize_absolute_path(_argument_value("--replay-claim-path="))
	var admission_path := _normalize_absolute_path(_argument_value("--replay-admission-path="))
	var consumed_path := _normalize_absolute_path(_argument_value("--replay-consumed-path="))
	var claim_sha256 := _argument_value("--replay-claim-sha256=").to_lower()
	var expected_claim := _normalize_absolute_path(replay_root.path_join("replay_attempt_claim.json"))
	var expected_admission := _normalize_absolute_path(replay_root.path_join("replay_child_admission.json"))
	var expected_consumed := _normalize_absolute_path(replay_root.path_join("replay_child_admission_consumed.json"))
	if replay_root.is_empty() or claim_path != expected_claim \
			or admission_path != expected_admission or consumed_path != expected_consumed \
			or not _lower_hex(claim_sha256, 64) \
			or not FileAccess.file_exists(claim_path) \
			or not FileAccess.file_exists(admission_path) \
			or FileAccess.file_exists(consumed_path):
		return {"accepted": false, "reason_code": "ai_runtime_replay_admission_path_invalid"}
	var claim_text := FileAccess.get_file_as_string(claim_path)
	if claim_text.is_empty() or claim_text.sha256_text().to_lower() != claim_sha256:
		return {"accepted": false, "reason_code": "ai_runtime_replay_claim_sha256_invalid"}
	var claim_variant: Variant = JSON.parse_string(claim_text)
	if not (claim_variant is Dictionary):
		return {"accepted": false, "reason_code": "ai_runtime_replay_claim_invalid"}
	var claim := claim_variant as Dictionary
	if not _has_exact_fields(claim, REPLAY_CLAIM_FIELDS) \
			or int(claim.get("schema_version", 0)) != 1 \
			or str(claim.get("claim_id", "")) != "AiRuntimeOwnerReplayAttemptClaimV1" \
			or str(claim.get("authorization_id", "")) != str(authorization.get("authorization_id", "")) \
			or str(claim.get("run_id", "")) != str(authorization.get("run_id", "")) \
			or str(claim.get("repository_head", "")) != repository_head \
			or int(claim.get("replay_attempt_count_before", -1)) != 0 \
			or int(claim.get("authorized_new_replay_count", -1)) != 1 \
			or int(claim.get("replay_attempt_count_after", -1)) != 1 \
			or int(claim.get("targeted_owner_capture_diagnostic_count_before", -1)) != 7 \
			or int(claim.get("targeted_owner_capture_diagnostic_count_after", -1)) != 7 \
			or not bool(claim.get("private_payload_redacted", false)):
		return {"accepted": false, "reason_code": "ai_runtime_replay_claim_invalid"}
	var admission_variant: Variant = JSON.parse_string(FileAccess.get_file_as_string(admission_path))
	if not (admission_variant is Dictionary):
		return {"accepted": false, "reason_code": "ai_runtime_replay_admission_invalid"}
	var admission := admission_variant as Dictionary
	if not _has_exact_fields(admission, REPLAY_ADMISSION_FIELDS) \
			or int(admission.get("schema_version", 0)) != 1 \
			or str(admission.get("admission_id", "")) != "AiRuntimeOwnerReplayChildAdmissionV1" \
			or str(admission.get("claim_sha256", "")) != claim_sha256 \
			or str(admission.get("authorization_id", "")) != str(authorization.get("authorization_id", "")) \
			or str(admission.get("run_id", "")) != str(authorization.get("run_id", "")) \
			or str(admission.get("repository_head", "")) != repository_head:
		return {"accepted": false, "reason_code": "ai_runtime_replay_admission_invalid"}
	if DirAccess.rename_absolute(admission_path, consumed_path) != OK:
		return {"accepted": false, "reason_code": "ai_runtime_replay_admission_already_consumed"}
	return {
		"accepted": true,
		"reason_code": "ai_runtime_replay_admission_consumed",
		"claim_sha256": claim_sha256,
	}


func _has_exact_fields(value: Dictionary, fields: Array) -> bool:
	if value.size() != fields.size():
		return false
	for field_variant in fields:
		if not value.has(str(field_variant)):
			return false
	return true


func _lower_hex(value: String, length: int) -> bool:
	if value.length() != length:
		return false
	for index in range(value.length()):
		if not "0123456789abcdef".contains(value.substr(index, 1)):
			return false
	return true


func _normalize_absolute_path(value: String) -> String:
	if value.is_empty() or not value.is_absolute_path():
		return ""
	return value.replace("\\", "/").simplify_path().trim_suffix("/")


func _base_result(repository_head: String, authorization: Dictionary) -> Dictionary:
	return {
		"schema_version": 1,
		"replay_run_id": str(authorization.get("run_id", "")),
		"replay_authorization_id": str(authorization.get("authorization_id", "")),
		"replay_attempt_count_before": int(authorization.get("replay_attempt_count_before", -1)),
		"authorized_new_replay_count": int(authorization.get("authorized_new_replay_count", -1)),
		"replay_attempt_count_after": int(authorization.get("replay_attempt_count_after", -1)),
		"repository_head": repository_head,
		"status": "BLOCKED",
		"success": false,
		"reason_code": "not_run",
		"replay_official": false,
		"replay_formal": false,
		"replay_process_a": false,
		"runtime_memory_injected": false,
		"runtime_action_injected": false,
		"targeted_owner_capture_diagnostic_count_before": 7,
		"targeted_owner_capture_diagnostic_count_after": 7,
		"replay_diagnostic_count_delta": 0,
		"replay_quota_claim_count": 0,
		"replay_full_owner_audit_count": 0,
		"replay_production_fixed_slot_write_count": 0,
		"replay_process_a_count": 0,
		"v7_historical_registry_owner_capture": "7/19",
		"v8_run_id_created": false,
		"private_payload_redacted": true,
	}


func _dispose_main(main: Node) -> void:
	if main != null and is_instance_valid(main):
		main.queue_free()
		await process_frame


func _finish(result: Dictionary, output_path: String, reason_code: String) -> void:
	result["reason_code"] = reason_code
	result["status"] = "BLOCKED"
	result["success"] = false
	if not output_path.is_empty() and not output_path.contains("current_run.save"):
		_write_result(output_path, result)
	_print_result(result)
	quit(1)


func _write_result(path: String, result: Dictionary) -> void:
	var absolute_path := path if path.is_absolute_path() else ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir()) != OK:
		return
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(result, "  ", true, true) + "\n")
	file.flush()
	file.close()


func _print_result(result: Dictionary) -> void:
	print("ALPHA04C_AI_RUNTIME_NONCONSUMING_REPLAY|" + JSON.stringify(result))
