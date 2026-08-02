extends "res://scripts/tools/alpha04c_remaining_owner_closed_data_preflight.gd"

const ATTEMPT := preload("res://scripts/tools/remaining_owner_closed_data_preflight_attempt_v3.gd")

const NEW_FIRST_OWNER_INDEX := 16
const NEW_LAST_OWNER_INDEX := 18
const NEW_EXPECTED_OWNER_COUNT := 3
const QUALIFIED_PRIOR_OWNER_COUNT := 8
const NEW_OUTPUT_PATH := "res://reports/handoffs/alpha04c_remaining_owner_preflight_index16_18_attempt_v3.json"


func _run() -> void:
	var output_path := _argument_value("--evidence-output=")
	var repository_head := _argument_value("--repository-head=").to_lower()
	var result := _base_result(repository_head)
	var expected_output := _normalize_absolute_path(ProjectSettings.globalize_path(NEW_OUTPUT_PATH))
	if _normalize_absolute_path(output_path) != expected_output or FileAccess.file_exists(expected_output):
		_finish_attempt(result, "remaining_index_16_18_preflight_v3_evidence_path_invalid", 1)
		return
	if not _lower_hex(repository_head, 40) or ATTEMPT.authorization().is_empty():
		_finish_attempt(result, "remaining_index_16_18_preflight_v3_authorization_invalid", 1)
		return
	var admission := ATTEMPT.consume_child_admission(
		repository_head,
		_argument_value("--preflight-claim-path="),
		_argument_value("--preflight-claim-sha256=").to_lower(),
		_argument_value("--preflight-admission-path="),
		_argument_value("--preflight-consumed-path=")
	)
	result["attempt_claim_sha256"] = str(admission.get("claim_sha256", ""))
	result["attempt_child_admission_consumed"] = bool(admission.get("accepted", false))
	if not bool(admission.get("accepted", false)):
		_finish_attempt(result, str(admission.get("reason_code", "remaining_index_16_18_preflight_v3_admission_invalid")), 1)
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
		_finish_attempt(result, "remaining_index_16_18_preflight_v3_production_composition_unavailable", 1)
		return

	var started := _start_fixed_session(context)
	result["challenge_depth"] = int(started.get("challenge_depth", -1))
	result["run_seed"] = int(started.get("seed", 0))
	result["local_player_count"] = int(started.get("local_player_count", -1))
	result["ai_player_count"] = int(started.get("ai_player_count", -1))
	if not bool(started.get("applied", false)):
		main.queue_free()
		await process_frame
		_finish_attempt(result, str(started.get("reason_code", "remaining_index_16_18_preflight_v3_session_start_failed")), 1)
		return
	main.process_mode = Node.PROCESS_MODE_DISABLED

	var session: Node = context.get("session")
	var registry: Node = context.get("registry")
	var ruleset_owner := session.get_node_or_null("RulesetSaveAttestationOwner")
	var ruleset_state: Dictionary = ruleset_owner.call("to_save_data") \
			if ruleset_owner != null and ruleset_owner.has_method("to_save_data") else {}
	var production_ruleset_id := str(ruleset_state.get("ruleset_id", ""))
	var scenario_identity := WIRE.sealed_copy({
		"schema_version": 1,
		"scene_path": MAIN_SCENE.resource_path,
		"production_runtime_ruleset_id": production_ruleset_id,
		"highest_target_ruleset_id": "v0.7.3",
		"highest_target_ruleset_used_as_runtime_identity": false,
		"challenge_depth": int(started.get("challenge_depth", -1)),
		"run_seed": int(started.get("seed", 0)),
		"local_player_count": int(started.get("local_player_count", -1)),
		"ai_player_count": int(started.get("ai_player_count", -1)),
	}, "identity_fingerprint")
	var scenario_attested := production_ruleset_id == SCENARIO_IDENTITY.PRODUCTION_RUNTIME_RULESET_ID \
			and int(started.get("challenge_depth", -1)) == FIXED_CHALLENGE_DEPTH \
			and int(started.get("seed", 0)) == FIXED_SEED \
			and int(started.get("local_player_count", -1)) == FIXED_LOCAL_PLAYER_COUNT \
			and int(started.get("ai_player_count", -1)) == FIXED_AI_PLAYER_COUNT
	result["production_runtime_ruleset_id"] = production_ruleset_id
	result["scenario_identity_attested"] = scenario_attested
	result["scenario_identity_fingerprint"] = str(scenario_identity.get("identity_fingerprint", ""))
	if not scenario_attested:
		main.queue_free()
		await process_frame
		_finish_attempt(result, "remaining_index_16_18_preflight_v3_scenario_identity_mismatch", 1)
		return

	var contract: Dictionary = registry.call("registry_binding_contract_v1")
	var registry_report := REGISTRY_VALIDATOR.validate(contract, registry, 19)
	var rows: Array = contract.get("bindings", []) if contract.get("bindings") is Array else []
	var registry_attested := bool(registry_report.get("valid", false)) and rows.size() == 19
	result["registry_binding_attested"] = registry_attested
	result["registry_binding_fingerprint"] = WIRE.fingerprint(contract)
	if not registry_attested:
		main.queue_free()
		await process_frame
		_finish_attempt(result, str(registry_report.get("reason_code", "remaining_index_16_18_preflight_v3_registry_invalid")), 1)
		return

	var owner_results: Array[Dictionary] = []
	var green_count := 0
	var non_closed_count := 0
	var mutation_count := 0
	var first_failure_index := -1
	var first_failure_id := "none"
	var first_failure_reason := "none"
	for owner_index in range(NEW_FIRST_OWNER_INDEX, NEW_LAST_OWNER_INDEX + 1):
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

	var success := owner_results.size() == NEW_EXPECTED_OWNER_COUNT \
			and green_count == NEW_EXPECTED_OWNER_COUNT \
			and non_closed_count == 0 and mutation_count == 0
	result.merge({
		"status": "GREEN" if success else "BLOCKED",
		"success": success,
		"reason_code": "remaining_index_16_18_preflight_v3_green" if success else first_failure_reason,
		"new_remaining_owner_preflight_count": owner_results.size(),
		"new_remaining_owner_preflight_green_count": green_count,
		"total_remaining_owner_preflight_count": QUALIFIED_PRIOR_OWNER_COUNT + owner_results.size(),
		"total_remaining_owner_preflight_green_count": QUALIFIED_PRIOR_OWNER_COUNT + green_count,
		"remaining_owner_non_closed_leaf_count": non_closed_count,
		"remaining_owner_capture_mutation_count": mutation_count,
		"first_remaining_owner_failure_index": first_failure_index,
		"first_remaining_owner_failure_id": first_failure_id,
		"first_remaining_owner_failure_reason": first_failure_reason,
		"owner_results": owner_results,
		"remaining_owner_preflight_child_attestation_green": true,
	}, true)
	main.queue_free()
	await process_frame
	_write_result(result)
	_print_result(result)
	quit(0 if success else 2)


func _base_result(repository_head: String) -> Dictionary:
	return {
		"schema_version": 1,
		"contract_id": ATTEMPT.CONTRACT_ID,
		"attempt_id": ATTEMPT.ATTEMPT_ID,
		"preflight_id": "alpha04c_remaining_index_16_18_owner_closed_data_preflight_v3",
		"repository_head": repository_head,
		"start_index": NEW_FIRST_OWNER_INDEX,
		"end_index": NEW_LAST_OWNER_INDEX,
		"status": "BLOCKED",
		"success": false,
		"reason_code": "not_run",
		"official": false,
		"formal": false,
		"process_a_rehearsal": false,
		"scenario_identity_attested": false,
		"registry_binding_attested": false,
		"execution_replay_v2_green": true,
		"ai_runtime_replay_v1_green": true,
		"qualified_prior_owner_count": QUALIFIED_PRIOR_OWNER_COUNT,
		"preflight_attempt_count_before": 0,
		"authorized_new_preflight_attempt_count": 1,
		"preflight_attempt_count_after": 1,
		"remaining_owner_preflight_attempt_count_delta": 1,
		"remaining_owner_preflight_concurrent_execution_count": 1,
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


func _finish_attempt(result: Dictionary, reason_code: String, exit_code: int) -> void:
	result["reason_code"] = reason_code
	result["status"] = "BLOCKED"
	result["success"] = false
	_write_result(result)
	_print_result(result)
	quit(exit_code)


func _write_result(result: Dictionary) -> void:
	if not WIRE.is_closed_data(result):
		return
	var absolute_path := ProjectSettings.globalize_path(NEW_OUTPUT_PATH)
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
	print("ALPHA04C_REMAINING_INDEX_16_18_OWNER_PREFLIGHT_V3|%s" % JSON.stringify(result))
