extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const INSPECTOR := preload("res://scripts/tools/card_resolution_execution_full_state_inspector_v1.gd")
const CODEC := preload("res://scripts/runtime/card_resolution_execution_save_wire_codec_v4.gd")
const SCALAR := preload("res://scripts/runtime/closed_save_scalar_codec_v1.gd")
const REGISTRY_VALIDATOR := preload("res://scripts/tools/alpha04c_registry_binding_contract_validator_v1.gd")
const REPLAY_IDENTITY := preload("res://scripts/tools/card_resolution_execution_owner_replay_scenario_identity_v2.gd")
const PROJECTION := preload("res://scripts/tools/execution_authoritative_restore_projection_v1.gd")
const EXACT_ONCE_PROBE := preload("res://scripts/tools/execution_restore_exact_once_probe_v1.gd")

const TARGET_OWNER_INDEX := REPLAY_IDENTITY.OWNER_INDEX
const TARGET_SECTION_ID := REPLAY_IDENTITY.SECTION_ID
const TARGET_OWNER_ID := REPLAY_IDENTITY.OWNER_ID
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
	"replay_v1_evidence_preserved",
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
		_finish(result, output_path, "execution_replay_v2_authorization_invalid")
		return
	var expected_output_path := _normalize_absolute_path(ProjectSettings.globalize_path(
		"res://reports/handoffs/alpha04c_card_resolution_execution_replay_v2_authoritative_parity.json"
	))
	if output_path.is_empty() or output_path.contains("current_run.save") \
			or _normalize_absolute_path(output_path) != expected_output_path \
			or FileAccess.file_exists(expected_output_path):
		_finish(result, "", "execution_replay_v2_evidence_path_invalid")
		return
	if not _lower_hex(repository_head, 40, 40):
		_finish(result, output_path, "execution_replay_v2_repository_head_invalid")
		return
	var admission := _consume_replay_admission(repository_head, authorization)
	result["replay_claim_sha256"] = str(admission.get("claim_sha256", ""))
	result["replay_admission_consumed"] = bool(admission.get("accepted", false))
	if not bool(admission.get("accepted", false)):
		_finish(result, output_path, str(admission.get("reason_code", "execution_replay_v2_admission_invalid")))
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
		main.queue_free()
		await process_frame
		_finish(result, output_path, "execution_replay_v2_production_composition_unavailable")
		return
	var started := _start_fixed_session(context, replay_run_id)
	result["challenge_depth"] = int(started.get("challenge_depth", -1))
	result["seed"] = int(started.get("seed", 0))
	result["local_player_count"] = int(started.get("local_player_count", -1))
	result["ai_player_count"] = int(started.get("ai_player_count", -1))
	if not bool(started.get("applied", false)):
		main.queue_free()
		await process_frame
		_finish(result, output_path, str(started.get("reason_code", "execution_replay_v2_session_start_failed")))
		return
	main.process_mode = Node.PROCESS_MODE_DISABLED

	var identity_bundle := _build_scenario_identity(context, started, repository_head, replay_run_id)
	var identity := identity_bundle.get("identity", {}) as Dictionary
	var identity_report := identity_bundle.get("report", {}) as Dictionary
	var identity_green := bool(identity_report.get("valid", false))
	result["execution_replay_v2_scenario_identity_attested"] = identity_green
	result["execution_replay_v2_scenario_identity_green"] = identity_green
	result["scenario_identity_fingerprint"] = str(identity.get("identity_fingerprint", ""))
	result["production_runtime_ruleset_id"] = str(identity.get("production_runtime_ruleset_id", ""))
	result["highest_target_ruleset_id"] = str(identity.get("highest_target_ruleset_id", ""))
	result["highest_target_ruleset_used_as_runtime_identity"] = bool(identity.get("highest_target_ruleset_used_as_runtime_identity", true))
	if not identity_green:
		main.queue_free()
		await process_frame
		_finish(result, output_path, str(identity_report.get("reason_code", "execution_replay_v2_scenario_identity_invalid")))
		return

	var registry: Node = context.get("registry")
	var owner: Node = context.get("owner")
	var transition: Node = context.get("transition")
	var contract: Dictionary = registry.call("registry_binding_contract_v1")
	var registry_report := REGISTRY_VALIDATOR.validate(contract, registry, 19)
	var target_binding := _target_binding(contract)
	var bound_owner := registry.get_node_or_null(NodePath(str(target_binding.get("owner_path", "")))) \
			if not target_binding.is_empty() else null
	var binding_green := bool(registry_report.get("valid", false)) \
			and int(target_binding.get("section_index", -1)) == TARGET_OWNER_INDEX \
			and str(target_binding.get("section_id", "")) == TARGET_SECTION_ID \
			and str(target_binding.get("owner_id", "")) == TARGET_OWNER_ID \
			and int(target_binding.get("state_version", 0)) == REPLAY_IDENTITY.REGISTRY_STATE_VERSION \
			and str(target_binding.get("capture_method", "")) == "to_save_data" \
			and str(target_binding.get("preflight_method", "")) == "preflight_save_data" \
			and str(target_binding.get("checkpoint_method", "")) == "" \
			and str(target_binding.get("apply_method", "")) == "apply_save_data" \
			and str(target_binding.get("rollback_method", "")) == "apply_save_data" \
			and not owner.has_method("capture_runtime_checkpoint") \
			and not owner.has_method("restore_runtime_checkpoint") \
			and bound_owner == owner
	result["execution_replay_v2_registry_binding_attested"] = binding_green
	result["execution_replay_v2_registry_binding_green"] = binding_green
	result["registry_binding_count"] = int(registry_report.get("binding_count", 0))
	result["target_owner_index"] = TARGET_OWNER_INDEX
	result["target_section_id"] = TARGET_SECTION_ID
	result["target_owner_id"] = TARGET_OWNER_ID
	result["execution_checkpoint_strategy"] = REPLAY_IDENTITY.CHECKPOINT_STRATEGY
	if not binding_green:
		main.queue_free()
		await process_frame
		_finish(result, output_path, "execution_replay_v2_registry_binding_invalid")
		return

	var before_capture := _observation(context)
	var save_a: Dictionary = owner.call("to_save_data")
	var projection_a := PROJECTION.capture(owner, transition)
	var after_capture := _observation(context)
	var capture_mutation_count := 0 if before_capture == after_capture else 1
	var wire_report := INSPECTOR.inspect(save_a)
	var raw_a_result := CODEC.decode_save_state(save_a)
	var raw_a := raw_a_result.get("value", {}) as Dictionary
	var transition_a := raw_a.get("transition_controller", {}) as Dictionary
	var handshake: Node = context.get("handshake")
	var envelope_encoded: Dictionary = handshake.call("encode_codec_value", save_a)
	var parsed_encoded: Variant = JSON.parse_string(JSON.stringify(envelope_encoded.get("value")))
	var envelope_decoded: Dictionary = handshake.call("decode_codec_value", parsed_encoded)
	var decoded_wire := envelope_decoded.get("value", {}) as Dictionary
	var preflight: Dictionary = owner.call("preflight_save_data", decoded_wire)

	var applied_b: Dictionary = owner.call("apply_save_data", decoded_wire)
	var save_b: Dictionary = owner.call("to_save_data")
	var projection_b := PROJECTION.capture(owner, transition)
	var diagnostics_b := PROJECTION.diagnostic_canonicalization(owner)
	var applied_c: Dictionary = owner.call("apply_save_data", save_a)
	var save_c: Dictionary = owner.call("to_save_data")
	var projection_c := PROJECTION.capture(owner, transition)
	var diagnostics_c := PROJECTION.diagnostic_canonicalization(owner)
	var raw_c_result := CODEC.decode_save_state(save_c)
	var raw_c := raw_c_result.get("value", {}) as Dictionary
	var transition_c := raw_c.get("transition_controller", {}) as Dictionary
	var comparison_b := PROJECTION.compare(projection_a, projection_b)
	var comparison_c := PROJECTION.compare(projection_a, projection_c)
	var exact_once := EXACT_ONCE_PROBE.run(self)
	var redacted := PROJECTION.redacted_evidence(
		projection_a, projection_c, comparison_c, diagnostics_c, exact_once
	)
	var redacted_green := _redacted_evidence_is_safe(redacted)

	var save_closed := bool(raw_a_result.get("ok", false)) \
			and int(raw_a.get("schema_version", -1)) == REPLAY_IDENTITY.SAVE_SCHEMA_VERSION \
			and int(raw_a.get("execution_wire_version", -1)) == REPLAY_IDENTITY.EXECUTION_WIRE_VERSION \
			and str(raw_a.get("ruleset_id", "")) == REPLAY_IDENTITY.PRODUCTION_RUNTIME_RULESET_ID \
			and int(transition_a.get("transition_state_wire_version", -1)) == REPLAY_IDENTITY.TRANSITION_STATE_WIRE_VERSION \
			and WIRE.is_closed_data(save_a) \
			and int(wire_report.get("non_closed_leaf_count", -1)) == 0
	var envelope_roundtrip := bool(envelope_encoded.get("ok", false)) \
			and bool(envelope_decoded.get("ok", false)) \
			and decoded_wire == save_a
	var save_wire_parity := bool(preflight.get("accepted", false)) \
			and bool(applied_b.get("applied", false)) \
			and bool(applied_c.get("applied", false)) \
			and save_a == save_b and save_a == save_c \
			and bool(raw_c_result.get("ok", false)) and raw_a == raw_c
	var authoritative_parity := bool(comparison_b.get("green", false)) \
			and bool(comparison_c.get("green", false))
	var diagnostics_green := bool(diagnostics_b.get("ok", false)) \
			and bool(diagnostics_c.get("ok", false))
	var timer_bits_parity := _float_fields_bits_equal(transition_a, transition_c, [
		"card_resolution_timer",
		"card_resolution_counter_timer",
		"card_resolution_simultaneous_timer",
		"card_resolution_auction_timer",
	])
	var cadence_bits_parity := _float_fields_bits_equal(
		transition_a.get("card_group_cadence", {}) as Dictionary,
		transition_c.get("card_group_cadence", {}) as Dictionary,
		["total_seconds", "planning_seconds", "public_bid_seconds", "lock_seconds"]
	)
	var transaction_parity: bool = raw_a.get("inflight_execution_transactions") == raw_c.get("inflight_execution_transactions")
	var pending_parity: bool = raw_a.get("pending_settlements") == raw_c.get("pending_settlements")
	var lineage_parity: bool = transition_a.get("card_transition_applied_lineage") == transition_c.get("card_transition_applied_lineage")

	result.merge({
		"execution_save_schema_version": int(raw_a.get("schema_version", -1)),
		"execution_wire_version": int(raw_a.get("execution_wire_version", -1)),
		"transition_state_wire_version": int(transition_a.get("transition_state_wire_version", -1)),
		"execution_registry_state_version": int(target_binding.get("state_version", -1)),
		"execution_save_leaf_count": int(wire_report.get("leaf_count", 0)),
		"execution_save_non_closed_leaf_count_after": int(wire_report.get("non_closed_leaf_count", -1)),
		"execution_replay_v2_payload_closed": save_closed,
		"execution_payload_closed": save_closed,
		"execution_envelope_roundtrip_green": envelope_roundtrip,
		"execution_replay_v2_save_wire_parity": save_wire_parity,
		"execution_replay_v2_authoritative_restore_parity": authoritative_parity,
		"execution_replay_v2_exact_once_green": bool(exact_once.get("green", false)),
		"execution_replay_v2_diagnostic_canonicalization_green": diagnostics_green,
		"execution_replay_v2_capture_mutation_count": capture_mutation_count,
		"execution_restore_parity_authority_source": REPLAY_IDENTITY.AUTHORITY_SOURCE,
		"debug_snapshot_used_as_restore_authority": false,
		"execution_authoritative_projection_field_coverage_percent": int(projection_c.get("field_coverage_percent", 0)),
		"execution_save_v4_field_omission_count": int(projection_c.get("save_v4_field_omission_count", -1)),
		"execution_exact_once_field_omission_count": int(projection_c.get("exact_once_field_omission_count", -1)),
		"execution_typed_authoritative_query_parity": bool(projection_c.get("typed_authoritative_query_parity", false)),
		"execution_timer_bits_parity": timer_bits_parity,
		"execution_cadence_bits_parity": cadence_bits_parity,
		"inflight_transaction_parity": transaction_parity,
		"pending_settlement_parity": pending_parity,
		"transition_lineage_parity": lineage_parity,
		"post_restore_diagnostic_phase_canonical": bool(diagnostics_c.get("post_restore_diagnostic_phase_canonical", false)),
		"post_restore_diagnostic_reason_canonical": bool(diagnostics_c.get("post_restore_diagnostic_reason_canonical", false)),
		"post_restore_diagnostic_summary_canonical": bool(diagnostics_c.get("post_restore_diagnostic_summary_canonical", false)),
		"diagnostic_fields_persisted_to_save_count": int(diagnostics_c.get("diagnostic_fields_persisted_to_save_count", -1)),
		"duplicate_effect_dispatch_count": int(exact_once.get("duplicate_effect_dispatch_count", -1)),
		"duplicate_card_commitment_count": int(exact_once.get("duplicate_card_commitment_count", -1)),
		"duplicate_history_append_count": int(exact_once.get("duplicate_history_append_count", -1)),
		"duplicate_settlement_count": int(exact_once.get("duplicate_settlement_count", -1)),
		"duplicate_transition_command_apply_count": int(exact_once.get("duplicate_transition_command_apply_count", -1)),
		"redacted_projection_evidence_schema_green": redacted_green,
		"redacted_projection_evidence": redacted,
		"capture_rng_draw_delta": _delta(before_capture, after_capture, "rng_draw_invocation_count"),
		"capture_world_time_delta": _delta(before_capture, after_capture, "world_clock_advance_count"),
		"capture_public_log_delta": _delta(before_capture, after_capture, "public_log_revision"),
		"capture_private_feedback_delta": _delta(before_capture, after_capture, "private_feedback_revision"),
		"capture_presentation_revision_delta": _delta(before_capture, after_capture, "presentation_revision"),
	}, true)
	var green := identity_green and binding_green and save_closed and envelope_roundtrip \
			and save_wire_parity and authoritative_parity and diagnostics_green \
			and bool(exact_once.get("green", false)) and redacted_green \
			and timer_bits_parity and cadence_bits_parity \
			and transaction_parity and pending_parity and lineage_parity \
			and int(projection_c.get("field_coverage_percent", 0)) == 100 \
			and int(projection_c.get("save_v4_field_omission_count", -1)) == 0 \
			and int(projection_c.get("exact_once_field_omission_count", -1)) == 0 \
			and capture_mutation_count == 0 \
			and int(result.get("capture_rng_draw_delta", -1)) == 0 \
			and int(result.get("capture_world_time_delta", -1)) == 0 \
			and int(result.get("capture_public_log_delta", -1)) == 0 \
			and int(result.get("capture_private_feedback_delta", -1)) == 0 \
			and int(result.get("capture_presentation_revision_delta", -1)) == 0
	result["execution_save_v4_replay_green"] = green
	result["success"] = green
	result["status"] = "GREEN" if green else "BLOCKED"
	result["reason_code"] = "execution_nonconsuming_replay_v2_authoritative_parity_green" \
			if green else "execution_nonconsuming_replay_v2_authoritative_parity_failed"
	main.queue_free()
	await process_frame
	_write_result(output_path, result)
	_print_result(result)
	quit(0 if green else 1)


func _runtime_context(main: Node) -> Dictionary:
	var services := main.get_node_or_null("RuntimeServices")
	var coordinator := services.get_node_or_null("RuntimeControllerHost/GameRuntimeCoordinator") if services != null else null
	var session := coordinator.get_node_or_null("GameSessionRuntimeController") if coordinator != null else null
	var registry := session.get_node_or_null("V06SaveOwnerRegistry") if session != null else null
	var save := session.get_node_or_null("GameSaveRuntimeCoordinator") if session != null else null
	var handshake := save.get_node_or_null("RulesetSaveHandshakeService") if save != null else null
	var owner := coordinator.get_node_or_null("CardResolutionExecutionRuntimeService") if coordinator != null else null
	var transition := coordinator.get_node_or_null("CardResolutionRuntimeController") if coordinator != null else null
	return {
		"ready": services != null and coordinator != null and session != null and registry != null \
				and save != null and handshake != null and owner != null and transition != null,
		"services": services,
		"coordinator": coordinator,
		"session": session,
		"registry": registry,
		"save": save,
		"handshake": handshake,
		"owner": owner,
		"transition": transition,
	}


func _start_fixed_session(context: Dictionary, replay_run_id: String) -> Dictionary:
	var services: Node = context.get("services")
	var coordinator: GameRuntimeCoordinator = context.get("coordinator")
	var session: GameSessionRuntimeController = context.get("session")
	var draft := services.get_node_or_null("NewGameSetupDraftService") as NewGameSetupDraftService
	var transaction := services.get_node_or_null("SessionStartTransactionCoordinator") as SessionStartTransactionCoordinator
	var rng := coordinator.run_rng_service() if coordinator != null else null
	if draft == null or transaction == null or session == null or rng == null:
		return {"applied": false, "reason_code": "execution_replay_v2_session_start_dependency_missing"}
	draft.reset_to_defaults()
	rng.set_seed(REPLAY_IDENTITY.RUN_SEED)
	var setup := draft.draft_snapshot()
	if int(setup.get("challenge_depth", -1)) != REPLAY_IDENTITY.CHALLENGE_DEPTH \
			or int(setup.get("player_count", -1)) != REPLAY_IDENTITY.LOCAL_PLAYER_COUNT + REPLAY_IDENTITY.AI_PLAYER_COUNT \
			or int(setup.get("ai_player_count", -1)) != REPLAY_IDENTITY.AI_PLAYER_COUNT:
		return {"applied": false, "reason_code": "execution_replay_v2_fixed_setup_mismatch"}
	var request := SessionStartRequest.create(replay_run_id, setup, session.session_start_revision(), "quality_driver")
	var receipt := transaction.start_session(request)
	var summary := session.session_summary()
	var organization := coordinator.get_node_or_null("PlayerOrganizationRuntimeController")
	var organization_debug: Dictionary = organization.debug_snapshot() if organization != null else {}
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController
	var ai_debug := ai.debug_snapshot() if ai != null else {}
	var player_count := int(organization_debug.get("actor_count", 0))
	var ai_count := int(ai_debug.get("ai_player_count", 0))
	return {
		"applied": receipt != null and receipt.applied,
		"reason_code": receipt.reason_code if receipt != null else "execution_replay_v2_session_start_receipt_missing",
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
	var ruleset_state: Dictionary = ruleset_owner.call("to_save_data") if ruleset_owner != null else {}
	var registry_snapshot: Dictionary = registry.call("registry_snapshot")
	var target_binding := _target_binding(registry.call("registry_binding_contract_v1"))
	var owner_script := owner.get_script() as Script
	var owner_constants := owner_script.get_script_constant_map() if owner_script != null else {}
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
		"execution_save_schema_version": int(owner_constants.get("SAVE_SCHEMA_VERSION", -1)),
		"execution_wire_version": int(owner_constants.get("EXECUTION_WIRE_VERSION", -1)),
		"transition_state_wire_version": int(owner_constants.get("TRANSITION_STATE_WIRE_VERSION", -1)),
		"execution_registry_state_version": int(target_binding.get("state_version", -1)),
		"execution_checkpoint_strategy": REPLAY_IDENTITY.CHECKPOINT_STRATEGY,
	})
	return {"identity": identity, "report": REPLAY_IDENTITY.validation_report(identity, repository_head)}


func _target_binding(contract: Dictionary) -> Dictionary:
	var rows: Array = contract.get("bindings", []) if contract.get("bindings") is Array else []
	return (rows[TARGET_OWNER_INDEX] as Dictionary).duplicate(true) \
			if TARGET_OWNER_INDEX >= 0 and TARGET_OWNER_INDEX < rows.size() \
			and rows[TARGET_OWNER_INDEX] is Dictionary else {}


func _observation(context: Dictionary) -> Dictionary:
	var coordinator: GameRuntimeCoordinator = context.get("coordinator")
	var owner: Node = context.get("owner")
	var transition: Node = context.get("transition")
	var world := coordinator.world_session_state()
	var rng := coordinator.run_rng_service()
	var safety := coordinator.save_restore_safety_observation()
	return {
		"owner_debug": owner.call("debug_snapshot"),
		"transition_debug": transition.call("debug_snapshot"),
		"world": world.to_save_data(),
		"rng": rng.to_save_data(),
		"rng_draw_invocation_count": int(safety.get("rng_draw_invocation_count", 0)),
		"world_clock_advance_count": int(safety.get("world_clock_advance_count", 0)),
		"public_log_revision": int(safety.get("public_log_revision", 0)),
		"private_feedback_revision": int(safety.get("private_feedback_revision", 0)),
		"presentation_revision": int(safety.get("presentation_revision", 0)),
	}


func _redacted_evidence_is_safe(evidence: Dictionary) -> bool:
	if not _has_exact_fields(evidence, PROJECTION.REDACTED_EVIDENCE_FIELDS) \
			or not WIRE.is_closed_data(evidence) \
			or not bool(evidence.get("private_payload_redacted", false)):
		return false
	var serialized := JSON.stringify(evidence)
	for forbidden in [
		'"projection":',
		'"decoded_runtime":',
		'"skill":',
		'"selection_context":',
		'"active_entry":',
		'"target_binding":',
		'"inflight_execution_transactions":',
		'"pending_settlements":',
	]:
		if serialized.contains(forbidden):
			return false
	return true


func _float_fields_bits_equal(left: Dictionary, right: Dictionary, fields: Array) -> bool:
	for field_variant: Variant in fields:
		var field := str(field_variant)
		if not (left.get(field) is float) or not (right.get(field) is float) \
				or SCALAR.f64_bits_hex(float(left.get(field))) != SCALAR.f64_bits_hex(float(right.get(field))):
			return false
	return true


func _delta(before: Dictionary, after: Dictionary, field: String) -> int:
	return int(after.get(field, 0)) - int(before.get(field, 0))


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
	if replay_root.is_empty() or claim_path != expected_claim or admission_path != expected_admission \
			or consumed_path != expected_consumed or not _lower_hex(claim_sha256, 64, 64) \
			or not FileAccess.file_exists(claim_path) or not FileAccess.file_exists(admission_path) \
			or FileAccess.file_exists(consumed_path):
		return {"accepted": false, "reason_code": "execution_replay_v2_admission_path_invalid"}
	var claim_text := FileAccess.get_file_as_string(claim_path)
	if claim_text.is_empty() or claim_text.sha256_text().to_lower() != claim_sha256:
		return {"accepted": false, "reason_code": "execution_replay_v2_claim_sha256_invalid"}
	var claim_variant: Variant = JSON.parse_string(claim_text)
	var admission_variant: Variant = JSON.parse_string(FileAccess.get_file_as_string(admission_path))
	if not (claim_variant is Dictionary) or not (admission_variant is Dictionary):
		return {"accepted": false, "reason_code": "execution_replay_v2_admission_invalid"}
	var claim := claim_variant as Dictionary
	var admission := admission_variant as Dictionary
	if not _has_exact_fields(claim, REPLAY_CLAIM_FIELDS) \
			or int(claim.get("schema_version", 0)) != 1 \
			or str(claim.get("claim_id", "")) != "CardResolutionExecutionOwnerReplayAttemptClaimV2" \
			or str(claim.get("authorization_id", "")) != str(authorization.get("authorization_id", "")) \
			or str(claim.get("run_id", "")) != str(authorization.get("run_id", "")) \
			or str(claim.get("repository_head", "")) != repository_head \
			or int(claim.get("replay_attempt_count_before", -1)) != 1 \
			or int(claim.get("authorized_new_replay_count", -1)) != 1 \
			or int(claim.get("replay_attempt_count_after", -1)) != 2 \
			or int(claim.get("targeted_owner_capture_diagnostic_count_before", -1)) != 7 \
			or int(claim.get("targeted_owner_capture_diagnostic_count_after", -1)) != 7 \
			or not bool(claim.get("replay_v1_evidence_preserved", false)) \
			or not bool(claim.get("private_payload_redacted", false)):
		return {"accepted": false, "reason_code": "execution_replay_v2_claim_invalid"}
	if not _has_exact_fields(admission, REPLAY_ADMISSION_FIELDS) \
			or int(admission.get("schema_version", 0)) != 1 \
			or str(admission.get("admission_id", "")) != "CardResolutionExecutionOwnerReplayChildAdmissionV2" \
			or str(admission.get("claim_sha256", "")) != claim_sha256 \
			or str(admission.get("authorization_id", "")) != str(authorization.get("authorization_id", "")) \
			or str(admission.get("run_id", "")) != str(authorization.get("run_id", "")) \
			or str(admission.get("repository_head", "")) != repository_head:
		return {"accepted": false, "reason_code": "execution_replay_v2_admission_invalid"}
	if DirAccess.rename_absolute(admission_path, consumed_path) != OK:
		return {"accepted": false, "reason_code": "execution_replay_v2_admission_already_consumed"}
	return {"accepted": true, "reason_code": "execution_replay_v2_admission_consumed", "claim_sha256": claim_sha256}


func _has_exact_fields(value: Dictionary, fields: Array) -> bool:
	if value.size() != fields.size():
		return false
	for field_variant: Variant in fields:
		if not value.has(str(field_variant)):
			return false
	return true


func _normalize_absolute_path(value: String) -> String:
	return "" if value.is_empty() or not value.is_absolute_path() \
			else value.replace("\\", "/").simplify_path().trim_suffix("/")


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
	print("ALPHA04C_CARD_RESOLUTION_EXECUTION_NONCONSUMING_REPLAY_V2|%s" % JSON.stringify(result))


func _lower_hex(value: String, minimum: int, maximum: int) -> bool:
	if value.length() < minimum or value.length() > maximum:
		return false
	for index in range(value.length()):
		if not "0123456789abcdef".contains(value.substr(index, 1)):
			return false
	return true
