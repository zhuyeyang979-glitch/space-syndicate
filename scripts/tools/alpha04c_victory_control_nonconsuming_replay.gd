extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const CODEC := preload("res://scripts/runtime/victory_control_save_wire_codec_v3.gd")
const SCALAR := preload("res://scripts/runtime/closed_save_scalar_codec_v1.gd")
const PROJECTION := preload("res://scripts/tools/victory_authoritative_restore_projection_v1.gd")
const REGISTRY_VALIDATOR := preload("res://scripts/tools/alpha04c_registry_binding_contract_validator_v1.gd")
const REPLAY_IDENTITY := preload("res://scripts/tools/victory_control_owner_replay_scenario_identity_v1.gd")

const FIXED_SEED := REPLAY_IDENTITY.RUN_SEED
const FIXED_CHALLENGE_DEPTH := REPLAY_IDENTITY.CHALLENGE_DEPTH
const FIXED_LOCAL_PLAYER_COUNT := REPLAY_IDENTITY.LOCAL_PLAYER_COUNT
const FIXED_AI_PLAYER_COUNT := REPLAY_IDENTITY.AI_PLAYER_COUNT
const TARGET_OWNER_INDEX := REPLAY_IDENTITY.OWNER_INDEX
const TARGET_SECTION_ID := REPLAY_IDENTITY.SECTION_ID
const TARGET_OWNER_ID := REPLAY_IDENTITY.OWNER_ID
const POST_SETTLEMENT_CHECKPOINT := "post_world_settlement"
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
		_finish(result, output_path, "victory_replay_authorization_invalid")
		return
	var expected_output_path := _normalize_absolute_path(ProjectSettings.globalize_path(
		"res://reports/handoffs/alpha04c_victory_control_owner_replay_v1.json"
	))
	if output_path.is_empty() or output_path.contains("current_run.save") \
			or _normalize_absolute_path(output_path) != expected_output_path \
			or FileAccess.file_exists(expected_output_path):
		_finish(result, "", "victory_replay_evidence_path_invalid")
		return
	if not _lower_hex(repository_head, 40):
		_finish(result, output_path, "victory_replay_repository_head_invalid")
		return
	var admission := _consume_replay_admission(repository_head, authorization)
	result["replay_claim_sha256"] = str(admission.get("claim_sha256", ""))
	result["replay_admission_consumed"] = bool(admission.get("accepted", false))
	if not bool(admission.get("accepted", false)):
		_finish(result, output_path, str(admission.get("reason_code", "victory_replay_admission_invalid")))
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
		_finish(result, output_path, "victory_replay_production_composition_unavailable")
		return

	var started := _start_fixed_session(context, replay_run_id)
	result["challenge_depth"] = int(started.get("challenge_depth", -1))
	result["seed"] = int(started.get("seed", 0))
	result["local_player_count"] = int(started.get("local_player_count", -1))
	result["ai_player_count"] = int(started.get("ai_player_count", -1))
	if not bool(started.get("applied", false)):
		await _dispose_main(main)
		_finish(result, output_path, str(started.get("reason_code", "victory_replay_session_start_failed")))
		return
	main.process_mode = Node.PROCESS_MODE_DISABLED

	var identity_bundle := _build_scenario_identity(context, started, repository_head, replay_run_id)
	var identity: Dictionary = identity_bundle.get("identity", {}) \
			if identity_bundle.get("identity", {}) is Dictionary else {}
	var identity_report: Dictionary = identity_bundle.get("report", {}) \
			if identity_bundle.get("report", {}) is Dictionary else {}
	result["victory_replay_scenario_identity_green"] = bool(identity_report.get("valid", false))
	result["scenario_identity_fingerprint"] = str(identity.get("identity_fingerprint", ""))
	result["production_runtime_ruleset_id"] = str(identity.get("production_runtime_ruleset_id", ""))
	result["highest_target_ruleset_id"] = str(identity.get("highest_target_ruleset_id", ""))
	result["highest_target_ruleset_used_as_runtime_identity"] = bool(identity.get(
		"highest_target_ruleset_used_as_runtime_identity",
		true
	))
	if not bool(identity_report.get("valid", false)):
		await _dispose_main(main)
		_finish(result, output_path, str(identity_report.get("reason_code", "victory_replay_scenario_identity_invalid")))
		return

	var registry: Node = context.get("registry")
	var owner := context.get("owner") as VictoryControlRuntimeController
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
			and str(target_binding.get("checkpoint_method", "")) == "" \
			and str(target_binding.get("apply_method", "")) == "apply_save_data" \
			and str(target_binding.get("rollback_method", "")) == "apply_save_data" \
			and not owner.has_method("capture_runtime_checkpoint") \
			and not owner.has_method("restore_runtime_checkpoint") \
			and bound_owner == owner
	result["victory_replay_registry_binding_green"] = binding_attested
	result["registry_binding_count"] = int(registry_report.get("binding_count", 0))
	result["target_owner_index"] = TARGET_OWNER_INDEX
	result["target_section_id"] = TARGET_SECTION_ID
	result["target_owner_id"] = TARGET_OWNER_ID
	result["owner_state_version"] = int(target_binding.get("state_version", -1))
	result["victory_checkpoint_strategy"] = REPLAY_IDENTITY.CHECKPOINT_STRATEGY
	if not binding_attested:
		await _dispose_main(main)
		_finish(result, output_path, "victory_replay_registry_binding_invalid")
		return

	var first_world := _typed_world(false)
	var joint_world := _typed_world(true)
	var first_advance := owner.advance_world_effective(2.125, first_world)
	var second_advance := owner.advance_world_effective(3.25, joint_world)
	var formed_wire := owner.to_save_data()
	var formed_projection := PROJECTION.project(formed_wire)
	var formed_state: Dictionary = formed_projection.get("value", {}) \
			if formed_projection.get("value", {}) is Dictionary else {}
	var qualification_map: Dictionary = formed_state.get("qualification_elapsed_by_player", {}) \
			if formed_state.get("qualification_elapsed_by_player", {}) is Dictionary else {}
	var nontrivial_formed := bool(first_advance.get("valid", false)) \
			and bool(second_advance.get("valid", false)) \
			and str(formed_state.get("state", "")) == "qualification" \
			and qualification_map.size() >= 2
	result["runtime_state_source"] = "legal_typed_world_facts_and_advance_world_effective"
	result["runtime_state_injected"] = false
	result["runtime_state_nontrivial_green"] = nontrivial_formed
	result["victory_state_at_capture"] = str(formed_state.get("state", ""))
	result["qualification_player_count_at_capture"] = qualification_map.size()
	if not nontrivial_formed:
		await _dispose_main(main)
		_finish(result, output_path, "victory_replay_nontrivial_state_not_reached")
		return

	var before_capture := _observation(context)
	var save_a := owner.to_save_data()
	var after_capture := _observation(context)
	var capture_mutation_count := 0 if before_capture == after_capture else 1
	var decoded_a := CODEC.decode_save_state(save_a)
	var raw_a: Dictionary = decoded_a.get("value", {}) \
			if decoded_a.get("value", {}) is Dictionary else {}
	var payload_a: Dictionary = raw_a.get("victory_control_runtime", {}) \
			if raw_a.get("victory_control_runtime", {}) is Dictionary else {}
	var payload_closed := bool(decoded_a.get("ok", false)) \
			and WIRE.is_closed_data(save_a) \
			and _raw_float_count(save_a) == 0 \
			and _raw_null_count(save_a) == 0 \
			and _f64_tag_count(save_a) >= 3 \
			and int(payload_a.get("schema_version", -1)) == REPLAY_IDENTITY.SAVE_SCHEMA_VERSION \
			and str(payload_a.get("ruleset_id", "")) == REPLAY_IDENTITY.PRODUCTION_RUNTIME_RULESET_ID

	var handshake: Node = context.get("handshake")
	var envelope_encoded: Dictionary = handshake.call("encode_codec_value", save_a)
	var parsed_encoded: Variant = JSON.parse_string(JSON.stringify(envelope_encoded.get("value")))
	var envelope_decoded: Dictionary = handshake.call("decode_codec_value", parsed_encoded)
	var decoded_wire: Dictionary = envelope_decoded.get("value", {}) \
			if envelope_decoded.get("value", {}) is Dictionary else {}
	var preflight := owner.preflight_save_data(decoded_wire)
	var mutation_advance := owner.advance_world_effective(0.5, joint_world)
	var mutated_save := owner.to_save_data()
	var applied := owner.apply_save_data(decoded_wire)
	var save_b := owner.to_save_data()
	var rolled_back := owner.apply_save_data(save_a)
	var save_c := owner.to_save_data()
	var decoded_b := CODEC.decode_save_state(save_b)
	var raw_b: Dictionary = decoded_b.get("value", {}) \
			if decoded_b.get("value", {}) is Dictionary else {}
	var projection_a := PROJECTION.project(save_a)
	var projection_b := PROJECTION.project(save_b)
	var projection_c := PROJECTION.project(save_c)
	var envelope_roundtrip := bool(envelope_encoded.get("ok", false)) \
			and bool(envelope_decoded.get("ok", false)) \
			and decoded_wire == save_a
	var restore_parity := bool(preflight.get("accepted", false)) \
			and bool(mutation_advance.get("valid", false)) \
			and mutated_save != save_a \
			and bool(applied.get("applied", false)) \
			and bool(rolled_back.get("applied", false)) \
			and save_a == save_b and save_a == save_c \
			and bool(decoded_b.get("ok", false)) and raw_a == raw_b \
			and bool(projection_a.get("ok", false)) \
			and projection_a == projection_b and projection_a == projection_c
	var qualification_timer_bits_parity := _qualification_bits_equal(payload_a, raw_b.get("victory_control_runtime", {}) as Dictionary)
	var audit_timer_bits_parity := _audit_bits_equal(payload_a, raw_b.get("victory_control_runtime", {}) as Dictionary)
	var fingerprint_parity := WIRE.fingerprint(save_a) == WIRE.fingerprint(save_b) \
			and WIRE.fingerprint(save_a) == WIRE.fingerprint(save_c)

	var public_before_fresh := owner.public_snapshot()
	var private_before_fresh := owner.private_snapshot(0)
	var save_before_stale := owner.to_save_data()
	var stale_attempt := owner.advance_world_effective(0.0, joint_world)
	var save_after_stale := owner.to_save_data()
	var bridge := context.get("world_bridge") as VictoryControlWorldBridge
	var fresh_world := bridge.capture_world_snapshot({}, "read_only") if bridge != null else {}
	var fresh_attempt := owner.advance_world_effective(0.0, fresh_world)
	var fresh_debug := owner.debug_snapshot()
	var fresh_gate_green := str(stale_attempt.get("reason", "")) == "awaiting_fresh_world_facts_after_restore" \
			and save_before_stale == save_after_stale \
			and not fresh_world.is_empty() \
			and bool(fresh_attempt.get("valid", false)) \
			and str(fresh_attempt.get("reason", "")) != "awaiting_fresh_world_facts_after_restore" \
			and not bool(fresh_debug.get("fresh_world_facts_required", true)) \
			and not _contains_key_recursive(public_before_fresh, "cash_ledger_cents") \
			and not _contains_key_recursive(private_before_fresh, "cash_ledger_cents") \
			and (private_before_fresh.get("own_candidate", {}) as Dictionary).is_empty() \
			and (private_before_fresh.get("own_economic_assets", {}) as Dictionary).is_empty() \
			and (public_before_fresh.get("victory_rule", {}) as Dictionary).is_empty() \
			and str(public_before_fresh.get("settlement_checkpoint", "")).is_empty()

	var audit_advance := owner.advance_world_effective(10.0, joint_world)
	var resolve_advance := owner.advance_world_effective(120.0, joint_world)
	var resolved_save := owner.to_save_data()
	var resolved_decoded := CODEC.decode_save_state(resolved_save)
	var resolved_raw: Dictionary = resolved_decoded.get("value", {}) \
			if resolved_decoded.get("value", {}) is Dictionary else {}
	var resolved_payload: Dictionary = resolved_raw.get("victory_control_runtime", {}) \
			if resolved_raw.get("victory_control_runtime", {}) is Dictionary else {}
	var resolved_receipt: Dictionary = resolved_payload.get("outcome_receipt", {}) \
			if resolved_payload.get("outcome_receipt", {}) is Dictionary else {}
	var resolved_formed := bool(audit_advance.get("valid", false)) \
			and bool(resolve_advance.get("valid", false)) \
			and str(resolved_payload.get("state", "")) == "resolved" \
			and int(resolved_payload.get("outcome_sequence", 0)) > 0 \
			and not resolved_receipt.is_empty()
	var resolved_applied := owner.apply_save_data(resolved_save)
	var exact_before_safety := _safety(context)
	var exact_before_save := owner.to_save_data()
	var stale_resolved_attempt := owner.advance_world_effective(0.0, joint_world)
	var stale_special_receipt := owner.resolve_special_outcome("last_survivor", joint_world)
	var fresh_resolved_world := bridge.capture_world_snapshot({}, "read_only") if bridge != null else {}
	var fresh_resolved_attempt := owner.advance_world_effective(0.0, fresh_resolved_world)
	var fresh_special_receipt := owner.resolve_special_outcome("last_survivor", fresh_resolved_world)
	var exact_after_save := owner.to_save_data()
	var exact_after_safety := _safety(context)
	var exact_after_decoded := CODEC.decode_save_state(exact_after_save)
	var exact_after_raw: Dictionary = exact_after_decoded.get("value", {}) \
			if exact_after_decoded.get("value", {}) is Dictionary else {}
	var exact_after_payload: Dictionary = exact_after_raw.get("victory_control_runtime", {}) \
			if exact_after_raw.get("victory_control_runtime", {}) is Dictionary else {}
	var duplicate_outcome_count := 0 \
			if int(exact_after_payload.get("outcome_sequence", -1)) == int(resolved_payload.get("outcome_sequence", -2)) \
			and exact_after_payload.get("outcome_receipt", {}) == resolved_receipt else 1
	var public_log_delta := _delta(exact_before_safety, exact_after_safety, "public_log_revision")
	var presentation_delta := _delta(exact_before_safety, exact_after_safety, "presentation_revision")
	var duplicate_final_settlement_count := 0 if exact_before_safety == exact_after_safety else 1
	var exact_once_green := resolved_formed \
			and bool(resolved_applied.get("applied", false)) \
			and str(stale_resolved_attempt.get("reason", "")) == "awaiting_fresh_world_facts_after_restore" \
			and stale_special_receipt.is_empty() \
			and bool(fresh_resolved_attempt.get("valid", false)) \
			and (fresh_resolved_attempt.get("outcome_receipt", {}) as Dictionary).is_empty() \
			and fresh_special_receipt.is_empty() \
			and exact_before_save == resolved_save \
			and exact_after_save == resolved_save \
			and duplicate_outcome_count == 0 \
			and duplicate_final_settlement_count == 0 \
			and public_log_delta == 0 and presentation_delta == 0

	result.merge({
		"victory_save_schema_version": int(payload_a.get("schema_version", -1)),
		"victory_registry_state_version": int(target_binding.get("state_version", -1)),
		"victory_payload_closed": payload_closed,
		"victory_envelope_roundtrip_green": envelope_roundtrip,
		"victory_save_v3_replay_green": payload_closed and envelope_roundtrip and restore_parity and fingerprint_parity,
		"victory_restore_parity": restore_parity,
		"victory_registry_checkpoint_a_equals_b": save_a == save_b,
		"victory_save_v3_fingerprint_parity": fingerprint_parity,
		"qualification_timer_bits_parity": qualification_timer_bits_parity,
		"audit_timer_bits_parity": audit_timer_bits_parity,
		"victory_fresh_world_facts_gate_green": fresh_gate_green,
		"victory_exact_once_green": exact_once_green,
		"victory_capture_mutation_count": capture_mutation_count,
		"victory_save_capture_rng_draw_delta": _delta(before_capture, after_capture, "rng_draw_invocation_count"),
		"victory_save_capture_world_time_delta": _delta(before_capture, after_capture, "world_clock_advance_count"),
		"victory_save_capture_public_log_delta": _delta(before_capture, after_capture, "public_log_revision"),
		"victory_save_capture_private_feedback_delta": _delta(before_capture, after_capture, "private_feedback_revision"),
		"victory_save_capture_presentation_revision_delta": _delta(before_capture, after_capture, "presentation_revision"),
		"stale_candidate_reuse_count": 0 if fresh_gate_green else 1,
		"stale_private_asset_reuse_count": 0 if fresh_gate_green else 1,
		"stale_settlement_checkpoint_reuse_count": 0 if fresh_gate_green else 1,
		"public_cash_disclosure_before_fresh_facts_count": 0 if fresh_gate_green else 1,
		"duplicate_victory_outcome_count": duplicate_outcome_count,
		"duplicate_outcome_sequence_increment_count": duplicate_outcome_count,
		"duplicate_final_settlement_count": duplicate_final_settlement_count,
		"duplicate_final_settlement_presentation_count": presentation_delta,
		"duplicate_final_settlement_public_log_count": public_log_delta,
		"raw_float_count_in_victory_save_v3": _raw_float_count(save_a),
		"raw_null_count_in_victory_save_v3": _raw_null_count(save_a),
		"f64_tag_count_in_victory_save_v3": _f64_tag_count(save_a),
		"save_fingerprint": WIRE.fingerprint(save_a),
		"resolved_save_fingerprint": WIRE.fingerprint(resolved_save),
	}, true)

	var green := bool(result.get("victory_replay_scenario_identity_green", false)) \
			and binding_attested and nontrivial_formed and payload_closed \
			and envelope_roundtrip and restore_parity and fingerprint_parity \
			and qualification_timer_bits_parity and audit_timer_bits_parity \
			and fresh_gate_green and exact_once_green \
			and capture_mutation_count == 0 \
			and int(result.get("victory_save_capture_rng_draw_delta", -1)) == 0 \
			and int(result.get("victory_save_capture_world_time_delta", -1)) == 0 \
			and int(result.get("victory_save_capture_public_log_delta", -1)) == 0 \
			and int(result.get("victory_save_capture_private_feedback_delta", -1)) == 0 \
			and int(result.get("victory_save_capture_presentation_revision_delta", -1)) == 0
	result["success"] = green
	result["status"] = "GREEN" if green else "BLOCKED"
	result["reason_code"] = "victory_control_nonconsuming_replay_green" \
			if green else "victory_control_nonconsuming_replay_failed"

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
	var owner := coordinator.get_node_or_null("VictoryControlRuntimeController") if coordinator != null else null
	var world_bridge := coordinator.get_node_or_null("VictoryControlWorldBridge") if coordinator != null else null
	return {
		"ready": services != null and coordinator != null and session != null \
				and registry != null and save != null and handshake != null \
				and owner is VictoryControlRuntimeController \
				and world_bridge is VictoryControlWorldBridge,
		"main": main,
		"services": services,
		"coordinator": coordinator,
		"session": session,
		"registry": registry,
		"save": save,
		"handshake": handshake,
		"owner": owner,
		"world_bridge": world_bridge,
	}


func _start_fixed_session(context: Dictionary, replay_run_id: String) -> Dictionary:
	var services: Node = context.get("services")
	var coordinator: GameRuntimeCoordinator = context.get("coordinator")
	var session: GameSessionRuntimeController = context.get("session")
	var draft := services.get_node_or_null("NewGameSetupDraftService") as NewGameSetupDraftService
	var transaction := services.get_node_or_null("SessionStartTransactionCoordinator") as SessionStartTransactionCoordinator
	var rng := coordinator.run_rng_service() if coordinator != null else null
	if draft == null or transaction == null or session == null or rng == null:
		return {"applied": false, "reason_code": "victory_replay_session_start_dependency_missing"}
	draft.reset_to_defaults()
	rng.set_seed(FIXED_SEED)
	var setup := draft.draft_snapshot()
	if int(setup.get("challenge_depth", -1)) != FIXED_CHALLENGE_DEPTH \
			or int(setup.get("player_count", -1)) != FIXED_LOCAL_PLAYER_COUNT + FIXED_AI_PLAYER_COUNT \
			or int(setup.get("ai_player_count", -1)) != FIXED_AI_PLAYER_COUNT:
		return {"applied": false, "reason_code": "victory_replay_fixed_setup_mismatch"}
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
		"reason_code": receipt.reason_code if receipt != null else "victory_replay_session_start_receipt_missing",
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
	var clock_registry: Resource = owner.get("clock_domain_registry") as Resource if owner != null else null
	var clock_debug: Dictionary = clock_registry.call("debug_snapshot") \
			if clock_registry != null and clock_registry.has_method("debug_snapshot") else {}
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
		"victory_save_schema_version": int(owner_constants.get("SAVE_SCHEMA_VERSION", -1)),
		"victory_registry_state_version": int(target_binding.get("state_version", -1)),
		"victory_checkpoint_strategy": REPLAY_IDENTITY.CHECKPOINT_STRATEGY,
		"clock_domain_ruleset_id": str(clock_debug.get("ruleset_id", "")),
		"qualification_duration_seconds": _timer_duration(clock_debug, "victory_qualification"),
		"public_audit_duration_seconds": _timer_duration(clock_debug, "public_audit"),
	})
	return {
		"identity": identity,
		"report": REPLAY_IDENTITY.validation_report(identity, repository_head),
	}


func _timer_duration(clock_debug: Dictionary, timer_id: String) -> int:
	for timer_variant in clock_debug.get("timers", []) as Array:
		if timer_variant is Dictionary and str((timer_variant as Dictionary).get("timer_id", "")) == timer_id:
			return int((timer_variant as Dictionary).get("duration_seconds", -1))
	return -1


func _typed_world(include_second_candidate: bool) -> Dictionary:
	var regions: Array = []
	regions.append(_region(0, 7200, {"0": 3600}))
	regions.append(_region(1, 7200, {"0": 3600}))
	if include_second_candidate:
		regions.append(_region(2, 7200, {"1": 3600}))
		regions.append(_region(3, 7200, {"1": 3600}))
	while regions.size() < 5:
		regions.append(_region(regions.size(), 0, {}))
	return {
		"schema_version": "v0.6.victory-world.2",
		"players": [
			_player(0, 10000),
			_player(1, 10000),
			_player(2, 8000),
			_player(3, 7000),
		],
		"regions": regions,
		"clock_pause": {},
		"settlement_checkpoint": POST_SETTLEMENT_CHECKPOINT,
		"ordering_receipt": {
			"checkpoint": POST_SETTLEMENT_CHECKPOINT,
			"capture_sequence": 0,
			"region_revision": 1,
			"flow_revision": 1,
			"captured_at_game_time": 0.0,
			"victory_reads_after": [],
		},
		"visibility_scope": "controller_private",
	}


func _player(player_index: int, cash_cents: int) -> Dictionary:
	return {
		"player_index": player_index,
		"eliminated": false,
		"cash_ledger_cents": cash_cents,
		"audit_assets": {
			"available_cents": cash_cents,
			"escrow_cents": 0,
			"cash_ledger_cents": cash_cents,
			"ordinary_hand": [],
			"facilities": [],
			"installations": [],
			"commodity_inventory": [],
			"color_gdp": {},
			"units": [],
			"financial_positions": [],
		},
	}


func _region(index: int, total_cents: int, by_player: Dictionary) -> Dictionary:
	return {
		"region_id": "region.%04d" % index,
		"district_index": index,
		"lifecycle_state": "active",
		"destroyed": false,
		"region_gdp_per_minute_cents": total_cents,
		"player_gdp_by_index": by_player.duplicate(true),
	}


func _observation(context: Dictionary) -> Dictionary:
	var coordinator := context.get("coordinator") as GameRuntimeCoordinator
	var owner := context.get("owner") as VictoryControlRuntimeController
	var bridge := context.get("world_bridge") as VictoryControlWorldBridge
	var safety := _safety(context)
	return {
		"owner_save": owner.to_save_data(),
		"owner_debug": owner.debug_snapshot(),
		"world_bridge_debug": bridge.debug_snapshot(),
		"world": coordinator.world_session_state().to_save_data(),
		"rng": coordinator.run_rng_service().to_save_data(),
		"rng_draw_invocation_count": int(safety.get("rng_draw_invocation_count", 0)),
		"world_clock_advance_count": int(safety.get("world_clock_advance_count", 0)),
		"public_log_revision": int(safety.get("public_log_revision", 0)),
		"private_feedback_revision": int(safety.get("private_feedback_revision", 0)),
		"presentation_revision": int(safety.get("presentation_revision", 0)),
	}


func _safety(context: Dictionary) -> Dictionary:
	var coordinator := context.get("coordinator") as GameRuntimeCoordinator
	return coordinator.save_restore_safety_observation() if coordinator != null else {}


func _delta(before: Dictionary, after: Dictionary, field: String) -> int:
	return int(after.get(field, 0)) - int(before.get(field, 0))


func _target_binding(contract: Dictionary) -> Dictionary:
	var rows: Array = contract.get("bindings", []) if contract.get("bindings") is Array else []
	if TARGET_OWNER_INDEX < 0 or TARGET_OWNER_INDEX >= rows.size() \
			or not (rows[TARGET_OWNER_INDEX] is Dictionary):
		return {}
	return (rows[TARGET_OWNER_INDEX] as Dictionary).duplicate(true)


func _qualification_bits_equal(before: Dictionary, after: Dictionary) -> bool:
	var before_map: Dictionary = before.get("qualification_elapsed_by_player", {}) \
			if before.get("qualification_elapsed_by_player", {}) is Dictionary else {}
	var after_map: Dictionary = after.get("qualification_elapsed_by_player", {}) \
			if after.get("qualification_elapsed_by_player", {}) is Dictionary else {}
	if before_map.keys() != after_map.keys():
		return false
	for key_variant in before_map.keys():
		if not (before_map.get(key_variant) is float) or not (after_map.get(key_variant) is float) \
				or SCALAR.f64_bits_hex(float(before_map.get(key_variant))) \
						!= SCALAR.f64_bits_hex(float(after_map.get(key_variant))):
			return false
	return true


func _audit_bits_equal(before: Dictionary, after: Dictionary) -> bool:
	return before.get("audit_remaining_seconds") is float \
			and after.get("audit_remaining_seconds") is float \
			and SCALAR.f64_bits_hex(float(before.get("audit_remaining_seconds"))) \
					== SCALAR.f64_bits_hex(float(after.get("audit_remaining_seconds")))


func _contains_key_recursive(value: Variant, target: String) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if str(key_variant) == target \
					or _contains_key_recursive((value as Dictionary).get(key_variant), target):
				return true
	elif value is Array:
		for child in value as Array:
			if _contains_key_recursive(child, target):
				return true
	return false


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


func _f64_tag_count(value: Variant) -> int:
	var count := 0
	if value is Dictionary:
		var dictionary := value as Dictionary
		if str(dictionary.get("codec", "")) == SCALAR.F64_CODEC_ID \
				and dictionary.get("bits") is String:
			count += 1
		for child in dictionary.values():
			count += _f64_tag_count(child)
	elif value is Array:
		for child in value as Array:
			count += _f64_tag_count(child)
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
		return {"accepted": false, "reason_code": "victory_replay_admission_path_invalid"}
	var claim_text := FileAccess.get_file_as_string(claim_path)
	if claim_text.is_empty() or claim_text.sha256_text().to_lower() != claim_sha256:
		return {"accepted": false, "reason_code": "victory_replay_claim_sha256_invalid"}
	var claim_variant: Variant = JSON.parse_string(claim_text)
	if not (claim_variant is Dictionary):
		return {"accepted": false, "reason_code": "victory_replay_claim_invalid"}
	var claim := claim_variant as Dictionary
	if not _has_exact_fields(claim, REPLAY_CLAIM_FIELDS) \
			or int(claim.get("schema_version", 0)) != 1 \
			or str(claim.get("claim_id", "")) != "VictoryControlOwnerReplayAttemptClaimV1" \
			or str(claim.get("authorization_id", "")) != str(authorization.get("authorization_id", "")) \
			or str(claim.get("run_id", "")) != str(authorization.get("run_id", "")) \
			or str(claim.get("repository_head", "")) != repository_head \
			or int(claim.get("replay_attempt_count_before", -1)) != 0 \
			or int(claim.get("authorized_new_replay_count", -1)) != 1 \
			or int(claim.get("replay_attempt_count_after", -1)) != 1 \
			or int(claim.get("targeted_owner_capture_diagnostic_count_before", -1)) != 7 \
			or int(claim.get("targeted_owner_capture_diagnostic_count_after", -1)) != 7 \
			or not bool(claim.get("private_payload_redacted", false)):
		return {"accepted": false, "reason_code": "victory_replay_claim_invalid"}
	var admission_variant: Variant = JSON.parse_string(FileAccess.get_file_as_string(admission_path))
	if not (admission_variant is Dictionary):
		return {"accepted": false, "reason_code": "victory_replay_admission_invalid"}
	var admission := admission_variant as Dictionary
	if not _has_exact_fields(admission, REPLAY_ADMISSION_FIELDS) \
			or int(admission.get("schema_version", 0)) != 1 \
			or str(admission.get("admission_id", "")) != "VictoryControlOwnerReplayChildAdmissionV1" \
			or str(admission.get("claim_sha256", "")) != claim_sha256 \
			or str(admission.get("authorization_id", "")) != str(authorization.get("authorization_id", "")) \
			or str(admission.get("run_id", "")) != str(authorization.get("run_id", "")) \
			or str(admission.get("repository_head", "")) != repository_head:
		return {"accepted": false, "reason_code": "victory_replay_admission_invalid"}
	if DirAccess.rename_absolute(admission_path, consumed_path) != OK:
		return {"accepted": false, "reason_code": "victory_replay_admission_already_consumed"}
	return {
		"accepted": true,
		"reason_code": "victory_replay_admission_consumed",
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
		"runtime_state_injected": false,
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
	print("ALPHA04C_VICTORY_CONTROL_NONCONSUMING_REPLAY_V1|" + JSON.stringify(result))
