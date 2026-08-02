extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const INSPECTOR := preload("res://scripts/tools/remaining_owner_closed_data_inspector_v1.gd")
const REGISTRY_VALIDATOR := preload("res://scripts/tools/alpha04c_registry_binding_contract_validator_v1.gd")
const SCENARIO_IDENTITY := preload("res://scripts/tools/card_inventory_owner_replay_scenario_identity_v1.gd")

const FIRST_OWNER_INDEX := 8
const LAST_OWNER_INDEX := 18
const EXPECTED_OWNER_COUNT := 11
const FIXED_SEED := SCENARIO_IDENTITY.RUN_SEED
const FIXED_CHALLENGE_DEPTH := SCENARIO_IDENTITY.CHALLENGE_DEPTH
const FIXED_LOCAL_PLAYER_COUNT := SCENARIO_IDENTITY.LOCAL_PLAYER_COUNT
const FIXED_AI_PLAYER_COUNT := SCENARIO_IDENTITY.AI_PLAYER_COUNT
const OUTPUT_PATH := "res://reports/handoffs/alpha04c_remaining_11_owner_closed_data_preflight.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_path := _argument_value("--evidence-output=")
	var repository_head := _argument_value("--repository-head=").to_lower()
	var result := _base_result(repository_head)
	var expected_output := _normalize_absolute_path(ProjectSettings.globalize_path(OUTPUT_PATH))
	if _normalize_absolute_path(output_path) != expected_output or FileAccess.file_exists(expected_output):
		_finish(result, "remaining_owner_preflight_evidence_path_invalid", 1)
		return
	if not _lower_hex(repository_head, 40):
		_finish(result, "remaining_owner_preflight_repository_head_invalid", 1)
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
		_finish(result, "remaining_owner_preflight_production_composition_unavailable", 1)
		return

	var started := _start_fixed_session(context)
	result["challenge_depth"] = int(started.get("challenge_depth", -1))
	result["run_seed"] = int(started.get("seed", 0))
	result["local_player_count"] = int(started.get("local_player_count", -1))
	result["ai_player_count"] = int(started.get("ai_player_count", -1))
	if not bool(started.get("applied", false)):
		main.queue_free()
		await process_frame
		_finish(result, str(started.get("reason_code", "remaining_owner_preflight_session_start_failed")), 1)
		return
	main.process_mode = Node.PROCESS_MODE_DISABLED

	var session: Node = context.get("session")
	var registry: Node = context.get("registry")
	var ruleset_owner := session.get_node_or_null("RulesetSaveAttestationOwner")
	var ruleset_state: Dictionary = ruleset_owner.call("to_save_data") \
			if ruleset_owner != null and ruleset_owner.has_method("to_save_data") else {}
	var production_ruleset_id := str(ruleset_state.get("ruleset_id", ""))
	var scenario_attested := production_ruleset_id == SCENARIO_IDENTITY.PRODUCTION_RUNTIME_RULESET_ID
	result["production_runtime_ruleset_id"] = production_ruleset_id
	result["scenario_identity_attested"] = scenario_attested
	if not scenario_attested:
		main.queue_free()
		await process_frame
		_finish(result, "remaining_owner_preflight_ruleset_identity_mismatch", 1)
		return

	var contract: Dictionary = registry.call("registry_binding_contract_v1")
	var registry_report := REGISTRY_VALIDATOR.validate(contract, registry, 19)
	var rows: Array = contract.get("bindings", []) if contract.get("bindings") is Array else []
	var registry_attested := bool(registry_report.get("valid", false)) and rows.size() == 19
	result["registry_binding_attested"] = registry_attested
	if not registry_attested:
		main.queue_free()
		await process_frame
		_finish(result, str(registry_report.get("reason_code", "remaining_owner_preflight_registry_invalid")), 1)
		return

	var owner_results: Array[Dictionary] = []
	var green_count := 0
	var non_closed_count := 0
	var mutation_count := 0
	var first_failure_index := -1
	var first_failure_id := "none"
	var first_failure_reason := "none"
	for owner_index in range(FIRST_OWNER_INDEX, LAST_OWNER_INDEX + 1):
		var binding: Dictionary = rows[owner_index] if rows[owner_index] is Dictionary else {}
		var owner_result := _preflight_owner(context, registry, binding, owner_index, production_ruleset_id)
		owner_results.append(owner_result)
		non_closed_count += int(owner_result.get("non_closed_leaf_count", 0))
		mutation_count += int(owner_result.get("capture_mutation_count", 0))
		if str(owner_result.get("reason_code", "none")) != "none":
			first_failure_index = owner_index
			first_failure_id = str(owner_result.get("owner_id", "unknown"))
			first_failure_reason = str(owner_result.get("reason_code", "owner_preflight_failed"))
			break
		green_count += 1

	var success := owner_results.size() == EXPECTED_OWNER_COUNT \
			and green_count == EXPECTED_OWNER_COUNT \
			and non_closed_count == 0 and mutation_count == 0
	result.merge({
		"status": "GREEN" if success else "BLOCKED",
		"success": success,
		"reason_code": "remaining_owner_preflight_green" if success else first_failure_reason,
		"remaining_owner_preflight_count": owner_results.size(),
		"remaining_owner_preflight_green_count": green_count,
		"remaining_owner_non_closed_leaf_count": non_closed_count,
		"remaining_owner_capture_mutation_count": mutation_count,
		"first_remaining_owner_failure_index": first_failure_index,
		"first_remaining_owner_failure_id": first_failure_id,
		"first_remaining_owner_failure_reason": first_failure_reason,
		"owner_results": owner_results,
	}, true)
	main.queue_free()
	await process_frame
	_write_result(result)
	_print_result(result)
	quit(0 if success else 2)


func _runtime_context(main: Node) -> Dictionary:
	var services := main.get_node_or_null("RuntimeServices")
	var coordinator := services.get_node_or_null("RuntimeControllerHost/GameRuntimeCoordinator") if services != null else null
	var session := coordinator.get_node_or_null("GameSessionRuntimeController") if coordinator != null else null
	var registry := session.get_node_or_null("V06SaveOwnerRegistry") if session != null else null
	return {
		"ready": services != null and coordinator != null and session != null and registry != null,
		"services": services,
		"coordinator": coordinator,
		"session": session,
		"registry": registry,
	}


func _start_fixed_session(context: Dictionary) -> Dictionary:
	var services: Node = context.get("services")
	var coordinator: GameRuntimeCoordinator = context.get("coordinator")
	var session: GameSessionRuntimeController = context.get("session")
	var draft := services.get_node_or_null("NewGameSetupDraftService") as NewGameSetupDraftService
	var transaction := services.get_node_or_null("SessionStartTransactionCoordinator") as SessionStartTransactionCoordinator
	var rng := coordinator.run_rng_service() if coordinator != null else null
	if draft == null or transaction == null or session == null or rng == null:
		return {"applied": false, "reason_code": "remaining_owner_preflight_session_dependency_missing"}
	draft.reset_to_defaults()
	rng.set_seed(FIXED_SEED)
	var setup := draft.draft_snapshot()
	if int(setup.get("challenge_depth", -1)) != FIXED_CHALLENGE_DEPTH \
			or int(setup.get("player_count", -1)) != FIXED_LOCAL_PLAYER_COUNT + FIXED_AI_PLAYER_COUNT \
			or int(setup.get("ai_player_count", -1)) != FIXED_AI_PLAYER_COUNT:
		return {"applied": false, "reason_code": "remaining_owner_preflight_fixed_setup_mismatch"}
	var request := SessionStartRequest.create(
		"alpha04c-remaining-owner-closed-data-preflight",
		setup,
		session.session_start_revision(),
		"quality_driver"
	)
	var receipt := transaction.start_session(request)
	var organization := coordinator.get_node_or_null("PlayerOrganizationRuntimeController")
	var organization_debug: Dictionary = organization.debug_snapshot() \
			if organization != null and organization.has_method("debug_snapshot") else {}
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController
	var ai_debug: Dictionary = ai.debug_snapshot() if ai != null else {}
	var player_count := int(organization_debug.get("actor_count", 0))
	var ai_count := int(ai_debug.get("ai_player_count", 0))
	return {
		"applied": receipt != null and receipt.applied,
		"reason_code": receipt.reason_code if receipt != null else "remaining_owner_preflight_session_receipt_missing",
		"challenge_depth": int(setup.get("challenge_depth", -1)),
		"seed": int(rng.seed),
		"local_player_count": player_count - ai_count,
		"ai_player_count": ai_count,
	}


func _preflight_owner(
	context: Dictionary,
	registry: Node,
	binding: Dictionary,
	owner_index: int,
	production_ruleset_id: String
) -> Dictionary:
	var section_id := str(binding.get("section_id", ""))
	var owner_id := str(binding.get("owner_id", ""))
	var capture_method := str(binding.get("capture_method", ""))
	var owner := registry.get_node_or_null(NodePath(str(binding.get("owner_path", "")))) \
			if not binding.is_empty() else null
	if owner == null or capture_method.is_empty() or not owner.has_method(capture_method):
		return _owner_failure(owner_index, section_id, owner_id, capture_method, production_ruleset_id, "owner_capture_binding_invalid")
	var before := _observation(context, owner)
	var payload_variant: Variant = owner.call(capture_method)
	var after := _observation(context, owner)
	var payload: Dictionary = payload_variant if payload_variant is Dictionary else {}
	var report := INSPECTOR.inspect(payload_variant)
	var owner_mutation := 0 if str(before.get("owner_fingerprint", "")) == str(after.get("owner_fingerprint", "")) \
			and str(before.get("world_fingerprint", "")) == str(after.get("world_fingerprint", "")) else 1
	var rng_delta := int(after.get("rng_draw_invocation_count", 0)) - int(before.get("rng_draw_invocation_count", 0))
	var world_time_delta := int(after.get("world_clock_advance_count", 0)) - int(before.get("world_clock_advance_count", 0))
	var public_log_delta := int(after.get("public_log_revision", 0)) - int(before.get("public_log_revision", 0))
	var private_feedback_delta := int(after.get("private_feedback_revision", 0)) - int(before.get("private_feedback_revision", 0))
	var reason_code := "none"
	if not (payload_variant is Dictionary):
		reason_code = "owner_payload_not_dictionary"
	elif payload.is_empty():
		reason_code = "owner_payload_empty"
	elif not bool(report.get("closed_data", false)):
		reason_code = _non_closed_reason(report)
	elif owner_mutation != 0:
		reason_code = "owner_capture_mutated_state"
	elif rng_delta != 0:
		reason_code = "owner_capture_advanced_rng"
	elif world_time_delta != 0:
		reason_code = "owner_capture_advanced_world_time"
	elif public_log_delta != 0:
		reason_code = "owner_capture_changed_public_log"
	elif private_feedback_delta != 0:
		reason_code = "owner_capture_changed_private_feedback"
	return {
		"owner_index": owner_index,
		"section_id": section_id,
		"owner_id": owner_id,
		"capture_method": capture_method,
		"payload_present": payload_variant != null,
		"payload_dictionary": payload_variant is Dictionary,
		"payload_nonempty": not payload.is_empty(),
		"payload_closed_data": bool(report.get("closed_data", false)),
		"state_version": int(binding.get("state_version", -1)),
		"ruleset_id": production_ruleset_id,
		"leaf_count": int(report.get("leaf_count", 0)),
		"non_closed_leaf_count": int(report.get("non_closed_leaf_count", 0)),
		"non_closed_type_counts": (report.get("non_closed_type_counts", {}) as Dictionary).duplicate(true),
		"first_non_closed_path": str(report.get("first_non_closed_path", "")),
		"first_non_closed_type": str(report.get("first_non_closed_type", "")),
		"capture_mutation_count": owner_mutation,
		"rng_draw_delta": rng_delta,
		"world_time_delta": world_time_delta,
		"public_log_delta": public_log_delta,
		"private_feedback_delta": private_feedback_delta,
		"reason_code": reason_code,
	}


func _owner_failure(
	owner_index: int,
	section_id: String,
	owner_id: String,
	capture_method: String,
	ruleset_id: String,
	reason_code: String
) -> Dictionary:
	return {
		"owner_index": owner_index,
		"section_id": section_id,
		"owner_id": owner_id,
		"capture_method": capture_method,
		"payload_present": false,
		"payload_dictionary": false,
		"payload_nonempty": false,
		"payload_closed_data": false,
		"state_version": -1,
		"ruleset_id": ruleset_id,
		"leaf_count": 0,
		"non_closed_leaf_count": 0,
		"non_closed_type_counts": {},
		"first_non_closed_path": "",
		"first_non_closed_type": "",
		"capture_mutation_count": 0,
		"rng_draw_delta": 0,
		"world_time_delta": 0,
		"public_log_delta": 0,
		"private_feedback_delta": 0,
		"reason_code": reason_code,
	}


func _non_closed_reason(report: Dictionary) -> String:
	for record_variant in report.get("non_closed_leaves", []) as Array:
		var reason := str((record_variant as Dictionary).get("reason_code", ""))
		if reason == "raw_float_timer_not_closed_data":
			return reason
	var first_reason := str(report.get("first_non_closed_reason", ""))
	return first_reason if not first_reason.is_empty() else "owner_payload_not_closed_data"


func _observation(context: Dictionary, owner: Node) -> Dictionary:
	var coordinator: GameRuntimeCoordinator = context.get("coordinator")
	var world := coordinator.world_session_state()
	var safety := coordinator.save_restore_safety_observation()
	var owner_debug: Variant = owner.call("debug_snapshot") if owner.has_method("debug_snapshot") else {}
	return {
		"world_fingerprint": _fingerprint(world.to_save_data()),
		"owner_fingerprint": _fingerprint(owner_debug),
		"rng_draw_invocation_count": int(safety.get("rng_draw_invocation_count", 0)),
		"world_clock_advance_count": int(safety.get("world_clock_advance_count", 0)),
		"public_log_revision": int(safety.get("public_log_revision", 0)),
		"private_feedback_revision": int(safety.get("private_feedback_revision", 0)),
	}


func _base_result(repository_head: String) -> Dictionary:
	return {
		"schema_version": 1,
		"preflight_id": "alpha04c_remaining_owner_real_state_closed_data_preflight_v1",
		"repository_head": repository_head,
		"status": "BLOCKED",
		"success": false,
		"reason_code": "not_run",
		"official": false,
		"formal": false,
		"process_a_rehearsal": false,
		"scenario_identity_attested": false,
		"registry_binding_attested": false,
		"targeted_owner_capture_diagnostic_count_before": 7,
		"targeted_owner_capture_diagnostic_count_after": 7,
		"preflight_diagnostic_count_delta": 0,
		"preflight_quota_claim_count": 0,
		"preflight_full_owner_audit_count": 0,
		"preflight_production_fixed_slot_write_count": 0,
		"preflight_process_a_count": 0,
		"v7_historical_registry_owner_capture": "7/19",
		"v8_authorization_created": false,
		"v8_run_id_created": false,
		"private_payload_redacted": true,
	}


func _finish(result: Dictionary, reason_code: String, exit_code: int) -> void:
	result["reason_code"] = reason_code
	result["status"] = "BLOCKED"
	result["success"] = false
	_write_result(result)
	_print_result(result)
	quit(exit_code)


func _write_result(result: Dictionary) -> void:
	if not WIRE.is_closed_data(result):
		return
	var absolute_path := ProjectSettings.globalize_path(OUTPUT_PATH)
	if FileAccess.file_exists(absolute_path):
		return
	if DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir()) != OK:
		return
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(result, "  ", true, true) + "\n")
	file.flush()
	file.close()


func _print_result(result: Dictionary) -> void:
	print("ALPHA04C_REMAINING_OWNER_PREFLIGHT|%s" % JSON.stringify(result))


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix).strip_edges()
	return ""


func _normalize_absolute_path(value: String) -> String:
	if value.is_empty() or not value.is_absolute_path():
		return ""
	return value.replace("\\", "/").simplify_path().trim_suffix("/")


func _lower_hex(value: String, length: int) -> bool:
	if value.length() != length:
		return false
	for index in range(value.length()):
		if not "0123456789abcdef".contains(value.substr(index, 1)):
			return false
	return true


func _fingerprint(value: Variant) -> String:
	return JSON.stringify(value, "", true, true).sha256_text().to_lower()
