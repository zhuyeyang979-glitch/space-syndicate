extends RefCounted
class_name Alpha04CV6RegistryBindingReplay

const DiagnosticScenarioIdentity := preload("res://scripts/tools/diagnostic_scenario_identity_v1.gd")
const ProductionRegistryComposition := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")
const SaveRegistry := preload("res://scripts/runtime/v06_save_owner_registry.gd")

const REPLAY_ID := "Alpha04CV6RegistryBindingReplayV1"
const REGISTRY_PORT := "registry_binding_contract_v1"
const EXPECTED_LEDGER_SHA256 := "fe843a4a924a12af5553afcb38a579f68a59acdeab0a4c5e5efb006c31e25c60"
const EXPECTED_RUN_ID := "alpha04c-owner-capture-diagnostic-v6-launch-context-7f2d7a31a0f0"
const EXPECTED_AUTHORIZATION_ID := "alpha04c-targeted-owner-capture-diagnostic-v6-launch-context"
const EXPECTED_REPOSITORY_HEAD := "7f2d7a31a0f0ffbd662526ad26122ea66fa59a56"
const EXPECTED_FAILURE_REASON := "diagnostic_registry_binding_contract_mismatch"
const EXPECTED_FIRST_MISMATCH_SECTION := "region_infrastructure"
const EXPECTED_FIRST_MISMATCH_OWNER := "public_facility_region"
const EXPECTED_FIRST_MISMATCH_FIELD := "checkpoint_method"
const EXPECTED_BINDING_COUNT := 19
const EXPECTED_OMITTED_CHECKPOINT_COUNT := 11

const STRATEGY_EXPLICIT := SaveRegistry.CHECKPOINT_STRATEGY_EXPLICIT_OWNER_METHOD
const STRATEGY_REGISTRY_MANAGED := SaveRegistry.CHECKPOINT_STRATEGY_REGISTRY_MANAGED
const STRATEGY_OWNER_INTERNAL := SaveRegistry.CHECKPOINT_STRATEGY_OWNER_INTERNAL


static func run(evidence_root_override := "") -> Dictionary:
	var result := _base_result()
	var evidence_root := evidence_root_override.strip_edges()
	if evidence_root.is_empty():
		evidence_root = locate_retained_v6_evidence_root()
	if evidence_root.is_empty() or not DirAccess.dir_exists_absolute(evidence_root):
		return _blocked(result, "retained_v6_evidence_root_missing")

	var evidence_before := _directory_fingerprint(evidence_root)
	if evidence_before.is_empty():
		return _blocked(result, "retained_v6_evidence_unreadable")
	var evidence := _validate_retained_evidence(evidence_root)
	result.merge(evidence, true)
	if not bool(evidence.get("valid", false)):
		result["evidence_tree_fingerprint_before"] = evidence_before
		result["evidence_tree_fingerprint_after"] = _directory_fingerprint(evidence_root)
		return _blocked(result, str(evidence.get("reason_code", "retained_v6_evidence_invalid")))

	var composition := ProductionRegistryComposition.instantiate()
	if composition == null:
		return _blocked(result, "production_registry_composition_unavailable")
	var session := composition.get_node_or_null("GameSessionRuntimeController")
	var registry := composition.get_node_or_null(
		"GameSessionRuntimeController/V06SaveOwnerRegistry"
	)
	if session == null or registry == null:
		composition.free()
		return _blocked(result, "production_registry_node_unavailable")
	if not session.has_method("session_state") or str(session.call("session_state")) != "idle":
		composition.free()
		return _blocked(result, "read_only_registry_composition_not_idle")

	var legacy_snapshot: Dictionary = registry.call("registry_snapshot") \
			if registry.has_method("registry_snapshot") else {}
	var legacy := characterize_legacy_snapshot(legacy_snapshot)
	result.merge(legacy, true)
	var retained_identity: Dictionary = evidence.get("scenario_identity", {})
	var replayed_registry_fingerprint := _legacy_registry_fingerprint(legacy_snapshot)
	result["retained_registry_fingerprint_match"] = not replayed_registry_fingerprint.is_empty() \
			and replayed_registry_fingerprint == str(retained_identity.get("save_registry_fingerprint", ""))
	if not bool(legacy.get("pre_fix_characterized", false)) \
			or not bool(result.get("retained_registry_fingerprint_match", false)):
		composition.free()
		return _blocked(result, "retained_v6_registry_projection_not_reconstructable")

	if not registry.has_method(REGISTRY_PORT):
		composition.free()
		return _blocked(result, "canonical_registry_binding_port_missing")
	var contract_variant: Variant = registry.call(REGISTRY_PORT)
	if not (contract_variant is Dictionary):
		composition.free()
		return _blocked(result, "canonical_registry_binding_contract_wrong_type")
	var contract := (contract_variant as Dictionary).duplicate(true)
	var validation := validate_registry_binding_contract(contract, registry)
	result["registry_validation"] = validation.duplicate(true)
	if not bool(validation.get("valid", false)):
		composition.free()
		return _blocked(result, str(validation.get("typed_reason", "canonical_registry_binding_contract_invalid")))

	result["registry_binding_count"] = int(validation.get("binding_count", 0))
	result["registry_binding_with_explicit_checkpoint_count"] = int(validation.get("explicit_checkpoint_count", 0))
	result["registry_binding_with_registry_managed_checkpoint_count"] = int(validation.get("registry_managed_checkpoint_count", 0))
	result["registry_binding_with_owner_internal_checkpoint_count"] = int(validation.get("owner_internal_checkpoint_count", 0))
	result["registry_binding_with_omitted_checkpoint_method_count"] = int(validation.get("omitted_checkpoint_method_count", 0))
	result["owner_without_checkpoint_or_rollback_semantics_count"] = int(validation.get("owner_without_transaction_semantics_count", -1))
	result["registry_binding_contract_source_count"] = 1
	result["duplicate_binding_required_field_list_count"] = 0
	result["diagnostic_hardcoded_checkpoint_requirement_count"] = 0
	result["v6_registry_binding_replay_green"] = int(validation.get("binding_count", 0)) == EXPECTED_BINDING_COUNT \
			and int(validation.get("omitted_checkpoint_method_count", 0)) == EXPECTED_OMITTED_CHECKPOINT_COUNT \
			and int(validation.get("owner_without_transaction_semantics_count", -1)) == 0
	result["v6_replay_binding_count"] = "%d/%d" % [
		int(validation.get("binding_count", 0)) if bool(result["v6_registry_binding_replay_green"]) else 0,
		EXPECTED_BINDING_COUNT,
	]
	composition.free()

	var evidence_after := _directory_fingerprint(evidence_root)
	result["evidence_tree_fingerprint_before"] = evidence_before
	result["evidence_tree_fingerprint_after"] = evidence_after
	result["retained_evidence_bytes_unchanged"] = evidence_before == evidence_after
	result["v6_retained_ledger_replay_green"] = bool(evidence.get("ledger_green", false)) \
			and bool(result.get("retained_evidence_bytes_unchanged", false))
	result["v6_scenario_identity_replay_green"] = bool(evidence.get("scenario_identity_green", false))
	result["valid"] = bool(result["v6_retained_ledger_replay_green"]) \
			and bool(result["v6_scenario_identity_replay_green"]) \
			and bool(result["v6_registry_binding_replay_green"])
	result["status"] = "GREEN" if bool(result["valid"]) else "BLOCKED"
	result["reason_code"] = "v6_registry_binding_replay_green" \
			if bool(result["valid"]) else "v6_registry_binding_replay_not_green"
	result.erase("scenario_identity")
	return result


static func locate_retained_v6_evidence_root() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--v6-evidence-root="):
			return argument.trim_prefix("--v6-evidence-root=").simplify_path()
	var environment_path := OS.get_environment("ALPHA04C_V6_EVIDENCE_ROOT").strip_edges()
	if not environment_path.is_empty():
		return environment_path.simplify_path()
	var project_root := ProjectSettings.globalize_path("res://").trim_suffix("/").trim_suffix("\\")
	var common_directory := _resolve_git_common_directory(project_root)
	if common_directory.is_empty():
		return ""
	return common_directory.path_join(
		"codex/cold_restore_v3/non-official-alpha04c-owner-capture-diagnostic-v6-launch-context"
	).simplify_path()


static func read_only_registry_fixture() -> Dictionary:
	var composition := ProductionRegistryComposition.instantiate()
	if composition == null:
		return {"ready": false, "reason_code": "production_registry_composition_unavailable"}
	var session := composition.get_node_or_null("GameSessionRuntimeController")
	var registry := composition.get_node_or_null("GameSessionRuntimeController/V06SaveOwnerRegistry")
	if session == null or registry == null:
		composition.free()
		return {"ready": false, "reason_code": "production_registry_node_unavailable"}
	if not session.has_method("session_state") or str(session.call("session_state")) != "idle":
		composition.free()
		return {"ready": false, "reason_code": "read_only_registry_composition_not_idle"}
	if not registry.has_method(REGISTRY_PORT):
		composition.free()
		return {"ready": false, "reason_code": "canonical_registry_binding_port_missing"}
	var contract_variant: Variant = registry.call(REGISTRY_PORT)
	if not (contract_variant is Dictionary):
		composition.free()
		return {"ready": false, "reason_code": "canonical_registry_binding_contract_wrong_type"}
	return {
		"ready": true,
		"composition": composition,
		"session": session,
		"registry": registry,
		"contract": (contract_variant as Dictionary).duplicate(true),
	}


static func characterize_legacy_snapshot(snapshot: Dictionary) -> Dictionary:
	var contracts: Array = snapshot.get("contracts", []) if snapshot.get("contracts", []) is Array else []
	var omitted_count := 0
	var first_index := -1
	var first_section := ""
	var first_owner := ""
	for index in range(contracts.size()):
		if not (contracts[index] is Dictionary):
			continue
		var row := contracts[index] as Dictionary
		if str(row.get("checkpoint_method", "")).is_empty():
			omitted_count += 1
			if first_index < 0:
				first_index = index
				first_section = str(row.get("section_id", ""))
				first_owner = str(row.get("owner_id", ""))
	return {
		"pre_fix_characterized": contracts.size() == EXPECTED_BINDING_COUNT \
				and omitted_count == EXPECTED_OMITTED_CHECKPOINT_COUNT \
				and first_index == 1 \
				and first_section == EXPECTED_FIRST_MISMATCH_SECTION \
				and first_owner == EXPECTED_FIRST_MISMATCH_OWNER,
		"v6_replay_pre_fix_mismatch_field": EXPECTED_FIRST_MISMATCH_FIELD,
		"v6_replay_pre_fix_omitted_row_count": omitted_count,
		"v6_replay_pre_fix_first_mismatch_index": first_index,
		"v6_replay_pre_fix_first_mismatch_section": first_section,
		"v6_replay_pre_fix_first_mismatch_owner": first_owner,
		"legacy_validator_required_every_checkpoint_method": true,
	}


static func validate_registry_binding_contract(contract: Dictionary, registry: Node) -> Dictionary:
	if registry == null:
		return _contract_rejection({}, "save_registry", "", "registry", "registry_missing")
	if not (contract.get("schema_version") is int) or int(contract.get("schema_version", 0)) != 1:
		return _contract_rejection({}, "schema_version", "", "registry", "value_mismatch")
	if str(contract.get("contract_id", "")).is_empty():
		return _contract_rejection({}, "contract_id", "", "registry", "missing")
	if str(contract.get("registry_id", "")) != "v06_save_owner_registry":
		return _contract_rejection({}, "registry_id", "", "registry", "value_mismatch")
	if not (contract.get("registry_version") is int) or int(contract.get("registry_version", 0)) < 1:
		return _contract_rejection({}, "registry_version", "", "registry", "wrong_type_or_range")
	if not (contract.get("fixed_section_order") is Array):
		return _contract_rejection({}, "fixed_section_order", "", "registry", "wrong_type")
	if not (contract.get("bindings") is Array):
		return _contract_rejection({}, "bindings", "", "registry", "wrong_type")
	var order := contract.get("fixed_section_order", []) as Array
	var rows := contract.get("bindings", []) as Array
	var allowed_strategies := contract.get("checkpoint_strategies", []) as Array
	if rows.size() != EXPECTED_BINDING_COUNT or order.size() != EXPECTED_BINDING_COUNT:
		return _contract_rejection({}, "binding_count", "", "registry", "value_mismatch")
	if contract.has("binding_count") \
			and (not (contract.get("binding_count") is int) \
			or int(contract.get("binding_count", -1)) != rows.size()):
		return _contract_rejection({}, "binding_count", "", "registry", "value_mismatch")

	var section_ids: Dictionary = {}
	var owner_ids: Dictionary = {}
	var restore_dag_report := _validate_restore_dag(contract)
	if not bool(restore_dag_report.get("valid", false)):
		return restore_dag_report
	var restore_node_ids: Dictionary = restore_dag_report.get("node_ids", {})
	var explicit_count := 0
	var registry_managed_count := 0
	var owner_internal_count := 0
	var omitted_count := 0
	var owner_without_semantics_count := 0
	for index in range(rows.size()):
		if not (rows[index] is Dictionary):
			return _contract_rejection({}, "bindings", "", "registry", "row_wrong_type")
		var row := rows[index] as Dictionary
		var section_id := str(row.get("section_id", ""))
		var owner_id := str(row.get("owner_id", ""))
		var strategy := str(row.get("checkpoint_strategy", ""))
		if not (row.get("section_index") is int) or int(row.get("section_index", -1)) != index:
			return _contract_rejection(row, "section_index", strategy, "registry", "registration_order_mismatch")
		if section_id.is_empty() or str(order[index]) != section_id:
			return _contract_rejection(row, "section_id", strategy, "registry", "registration_order_mismatch")
		if section_ids.has(section_id):
			return _contract_rejection(row, "section_id", strategy, "registry", "duplicate")
		if owner_id.is_empty() or owner_ids.has(owner_id):
			return _contract_rejection(row, "owner_id", strategy, "registry", "duplicate" if not owner_id.is_empty() else "missing")
		section_ids[section_id] = true
		owner_ids[owner_id] = true
		if not (row.get("state_version") is int) or int(row.get("state_version", 0)) < 1:
			return _contract_rejection(row, "state_version", strategy, "registry", "wrong_type_or_range")
		if not (row.get("checkpoint_method_present") is bool):
			return _contract_rejection(row, "checkpoint_method_present", strategy, "registry", "wrong_type")
		var checkpoint_method := str(row.get("checkpoint_method", ""))
		var checkpoint_present := bool(row.get("checkpoint_method_present", false))
		if checkpoint_present != not checkpoint_method.is_empty():
			return _contract_rejection(row, "checkpoint_method", strategy, "registry", "presence_value_conflict")
		if not checkpoint_present:
			omitted_count += 1
		if strategy not in allowed_strategies:
			owner_without_semantics_count += 1
			return _contract_rejection(row, "checkpoint_strategy", strategy, "registry", "unknown_or_none")
		var owner_path_text := str(row.get("owner_path", ""))
		if owner_path_text.is_empty():
			return _contract_rejection(row, "owner_path", strategy, "registry", "missing")
		var owner := registry.get_node_or_null(NodePath(owner_path_text))
		if owner == null:
			return _contract_rejection(row, "owner_path", strategy, "registry", "owner_node_missing")
		for method_field in ["capture_method", "preflight_method", "apply_method", "rollback_method"]:
			var method_name := str(row.get(method_field, ""))
			if method_name.is_empty():
				if method_field == "rollback_method":
					owner_without_semantics_count += 1
				return _contract_rejection(row, method_field, strategy, "owner_api", "missing")
			if not owner.has_method(method_name):
				if method_field == "rollback_method":
					owner_without_semantics_count += 1
				return _contract_rejection(row, method_field, strategy, "owner_api", "method_missing")
		if str(row.get("method_contract_source", "")).is_empty():
			return _contract_rejection(row, "method_contract_source", strategy, "registry", "missing")
		match strategy:
			STRATEGY_EXPLICIT:
				explicit_count += 1
				if not checkpoint_present:
					return _contract_rejection(row, "checkpoint_method", strategy, "owner_api", "missing")
				if not owner.has_method(checkpoint_method):
					return _contract_rejection(row, "checkpoint_method", strategy, "owner_api", "method_missing")
			STRATEGY_REGISTRY_MANAGED:
				registry_managed_count += 1
				if checkpoint_present:
					return _contract_rejection(row, "checkpoint_method", strategy, "registry", "strategy_field_conflict")
			STRATEGY_OWNER_INTERNAL:
				owner_internal_count += 1
				if checkpoint_present:
					return _contract_rejection(row, "checkpoint_method", strategy, "owner_api", "strategy_field_conflict")
		if not (row.get("dependencies") is Array):
			return _contract_rejection(row, "dependencies", strategy, "registry", "wrong_type")
		var dependencies: Array = row.get("dependencies", [])
		for dependency in dependencies:
			if not (dependency is String or dependency is StringName) or str(dependency).is_empty():
				return _contract_rejection(row, "dependencies", strategy, "registry", "invalid_dependency")
		for dependency in dependencies:
			if not restore_node_ids.has(str(dependency)):
				return _contract_rejection(row, "dependencies", strategy, "registry", "missing_dependency")
		var expected_fingerprint := binding_contract_fingerprint(row)
		if not _lower_sha256(str(row.get("binding_contract_fingerprint", ""))) \
				or str(row.get("binding_contract_fingerprint", "")) != expected_fingerprint:
			return _contract_rejection(row, "binding_contract_fingerprint", strategy, "registry", "value_mismatch")

	if contract.has("contract_fingerprint") \
			and (not _lower_sha256(str(contract.get("contract_fingerprint", ""))) \
			or str(contract.get("contract_fingerprint", "")) != registry_contract_fingerprint(contract)):
		return _contract_rejection({}, "contract_fingerprint", "", "registry", "value_mismatch")
	return {
		"valid": true,
		"reason_code": "registry_binding_contract_valid",
		"binding_count": rows.size(),
		"explicit_checkpoint_count": explicit_count,
		"registry_managed_checkpoint_count": registry_managed_count,
		"owner_internal_checkpoint_count": owner_internal_count,
		"omitted_checkpoint_method_count": omitted_count,
		"owner_without_transaction_semantics_count": owner_without_semantics_count,
	}


static func validate_registry_projection(
	canonical_contract: Dictionary,
	observed_projection: Dictionary,
	registry: Node
) -> Dictionary:
	var canonical_validation := validate_registry_binding_contract(canonical_contract, registry)
	if not bool(canonical_validation.get("valid", false)):
		return canonical_validation
	if not (observed_projection.get("bindings") is Array):
		return _contract_rejection({}, "bindings", "", "diagnostic_projection", "wrong_type")
	var canonical_rows := canonical_contract.get("bindings", []) as Array
	var observed_rows := observed_projection.get("bindings", []) as Array
	if observed_rows.size() != canonical_rows.size():
		return _contract_rejection({}, "binding_count", "", "diagnostic_projection", "value_mismatch")
	for index in range(canonical_rows.size()):
		if not (canonical_rows[index] is Dictionary) or not (observed_rows[index] is Dictionary):
			return _contract_rejection({}, "bindings", "", "diagnostic_projection", "row_wrong_type")
		var expected_row := canonical_rows[index] as Dictionary
		var actual_row := observed_rows[index] as Dictionary
		var expected_keys := expected_row.keys()
		var actual_keys := actual_row.keys()
		expected_keys.sort()
		actual_keys.sort()
		if expected_keys != actual_keys:
			return _contract_rejection(actual_row, "binding_fields", str(actual_row.get("checkpoint_strategy", "")), "diagnostic_projection", "shape_mismatch")
		for identity_field in ["section_index", "section_id", "owner_id"]:
			if actual_row.get(identity_field) != expected_row.get(identity_field):
				return _contract_rejection(actual_row, identity_field, str(actual_row.get("checkpoint_strategy", "")), "diagnostic_projection", "value_mismatch")
		for field in expected_keys:
			if str(field) in [
				"section_index",
				"section_id",
				"owner_id",
				"binding_contract_fingerprint",
			]:
				continue
			if actual_row.get(field) != expected_row.get(field):
				return _contract_rejection(actual_row, str(field), str(actual_row.get("checkpoint_strategy", "")), "diagnostic_projection", "value_mismatch")
		if actual_row.get("binding_contract_fingerprint") \
				!= expected_row.get("binding_contract_fingerprint"):
			return _contract_rejection(actual_row, "binding_contract_fingerprint", str(actual_row.get("checkpoint_strategy", "")), "diagnostic_projection", "value_mismatch")
	var expected_top_keys := canonical_contract.keys()
	var actual_top_keys := observed_projection.keys()
	expected_top_keys.sort()
	actual_top_keys.sort()
	if expected_top_keys != actual_top_keys:
		return _contract_rejection({}, "contract_fields", "", "diagnostic_projection", "shape_mismatch")
	for field in expected_top_keys:
		if str(field) == "bindings":
			continue
		if observed_projection.get(field) != canonical_contract.get(field):
			return _contract_rejection({}, str(field), "", "diagnostic_projection", "value_mismatch")
	if canonical_contract.has("contract_fingerprint") \
			and observed_projection.get("contract_fingerprint") != canonical_contract.get("contract_fingerprint"):
		return _contract_rejection({}, "contract_fingerprint", "", "diagnostic_projection", "value_mismatch")
	return canonical_validation


static func reseal_contract(contract: Dictionary) -> Dictionary:
	var sealed := contract.duplicate(true)
	var rows: Array = sealed.get("bindings", []) if sealed.get("bindings", []) is Array else []
	for index in range(rows.size()):
		if rows[index] is Dictionary:
			var row := (rows[index] as Dictionary).duplicate(true)
			row["binding_contract_fingerprint"] = binding_contract_fingerprint(row)
			rows[index] = row
	sealed["bindings"] = rows
	if sealed.has("contract_fingerprint"):
		sealed["contract_fingerprint"] = registry_contract_fingerprint(sealed)
	return sealed


static func binding_contract_fingerprint(row: Dictionary) -> String:
	var unsealed := row.duplicate(true)
	unsealed.erase("binding_contract_fingerprint")
	return JSON.stringify(unsealed, "", true, true).sha256_text().to_lower()


static func registry_contract_fingerprint(contract: Dictionary) -> String:
	var unsealed := contract.duplicate(true)
	unsealed.erase("contract_fingerprint")
	return JSON.stringify(unsealed, "", true, true).sha256_text().to_lower()


static func _validate_retained_evidence(evidence_root: String) -> Dictionary:
	var ledger_path := evidence_root.path_join("targeted_owner_capture_quota_ledger.json")
	var ledger_sha := _sha256_file(ledger_path)
	if ledger_sha != EXPECTED_LEDGER_SHA256:
		return {"valid": false, "reason_code": "retained_v6_ledger_sha256_mismatch", "v6_ledger_sha256": ledger_sha}
	var ledger := _read_json_dictionary(ledger_path)
	if ledger.is_empty() \
			or str(ledger.get("authorization_id", "")) != EXPECTED_AUTHORIZATION_ID \
			or str(ledger.get("run_id", "")) != EXPECTED_RUN_ID \
			or str(ledger.get("repository_head", "")) != EXPECTED_REPOSITORY_HEAD \
			or int(ledger.get("diagnostic_count_before", -1)) != 5 \
			or int(ledger.get("diagnostic_count_after", -1)) != 6 \
			or str(ledger.get("status", "")) != "consumed":
		return {"valid": false, "reason_code": "retained_v6_ledger_context_invalid", "v6_ledger_sha256": ledger_sha}
	var orchestrator_id := int(ledger.get("orchestrator_process_id", -1))
	var launch_path := evidence_root.path_join(
		"evidence/launch/orchestrator-%d/producer.authorized.json" % orchestrator_id
	)
	var launch := _read_json_dictionary(launch_path)
	var audit := _read_json_dictionary(evidence_root.path_join("evidence/diagnostics/owner_capture_audit.json"))
	var child_result := _read_json_dictionary(evidence_root.path_join("evidence/child/producer.result.json"))
	var child_completion := _read_json_dictionary(evidence_root.path_join("evidence/child/producer.completion.json"))
	var parent_exit := _read_json_dictionary(evidence_root.path_join("evidence/parent/producer.exit.json"))
	if launch.is_empty() or audit.is_empty() or child_result.is_empty() \
			or child_completion.is_empty() or parent_exit.is_empty():
		return {"valid": false, "reason_code": "retained_v6_required_artifact_missing", "v6_ledger_sha256": ledger_sha}
	var context_green := str(launch.get("authorization_id", "")) == EXPECTED_AUTHORIZATION_ID \
			and str(launch.get("run_id", "")) == EXPECTED_RUN_ID \
			and str(launch.get("source_head_sha", "")) == EXPECTED_REPOSITORY_HEAD \
			and str(launch.get("claim_fingerprint", "")) == EXPECTED_LEDGER_SHA256 \
			and str(launch.get("scenario_fingerprint", "")) == str(ledger.get("scenario_fingerprint", ""))
	var scenario_identity: Dictionary = audit.get("scenario_identity", {}) \
			if audit.get("scenario_identity", {}) is Dictionary else {}
	scenario_identity = _normalize_scenario_identity_json_types(scenario_identity)
	var scenario_report := DiagnosticScenarioIdentity.validation_report(
		scenario_identity,
		EXPECTED_RUN_ID,
		EXPECTED_REPOSITORY_HEAD,
		str(ledger.get("scenario_fingerprint", ""))
	)
	var scenario_green := context_green \
			and bool(scenario_report.get("valid", false)) \
			and bool(audit.get("scenario_identity_attested", false)) \
			and not bool(audit.get("registry_binding_attested", true)) \
			and not bool(audit.get("owner_audit_started", true)) \
			and int(audit.get("owner_capture_attempted_count", -1)) == 0
	var registry_failure: Dictionary = audit.get("scenario_identity_failure", {}) \
			if audit.get("scenario_identity_failure", {}) is Dictionary else {}
	var historical_failure_green := str(child_result.get("failure_code", "")) == EXPECTED_FAILURE_REASON \
			and str(registry_failure.get("failure_field", "")) == "save_registry" \
			and str(registry_failure.get("reason_code", "")) == EXPECTED_FAILURE_REASON \
			and str(registry_failure.get("expected_summary", "")) == "contract_1" \
			and str(registry_failure.get("actual_summary", "")) == "mismatch_1"
	var completion_green := bool(child_completion.get("child_ready_to_exit", false)) \
			and not bool(child_completion.get("save_written", true)) \
			and str(child_completion.get("repository_head", "")) == EXPECTED_REPOSITORY_HEAD \
			and str(child_completion.get("run_id", "")) == EXPECTED_RUN_ID
	var parent_green := bool(parent_exit.get("child_attestation_valid", false)) \
			and int(parent_exit.get("exit_code", -1)) == 0 \
			and not bool(parent_exit.get("timed_out", true)) \
			and not bool(parent_exit.get("terminated_by_parent", true)) \
			and int(parent_exit.get("task_owned_process_count_after", -1)) == 0
	return {
		"valid": context_green and scenario_green and historical_failure_green \
				and completion_green and parent_green,
		"reason_code": "retained_v6_evidence_valid" if context_green and scenario_green \
				and historical_failure_green and completion_green and parent_green \
				else "retained_v6_evidence_invalid",
		"ledger_green": context_green,
		"scenario_identity_green": scenario_green,
		"scenario_identity_validation_reason_code": str(scenario_report.get("reason_code", "")),
		"scenario_identity_validation_failure": (scenario_report.get("failure", {}) as Dictionary).duplicate(true),
		"historical_failure_green": historical_failure_green,
		"child_completion_green": completion_green,
		"parent_exit_green": parent_green,
		"v6_ledger_sha256": ledger_sha,
		"v6_ledger_bytes_retained": true,
		"scenario_identity": scenario_identity.duplicate(true),
	}


static func _legacy_registry_fingerprint(snapshot: Dictionary) -> String:
	if snapshot.is_empty():
		return ""
	return JSON.stringify({
		"fixed_section_order": snapshot.get("fixed_capture_order", []),
		"contracts": snapshot.get("contracts", []),
		"transactional_section_count": snapshot.get("transactional_section_count", 0),
	}, "", true, true).sha256_text().to_lower()


static func _normalize_scenario_identity_json_types(source: Dictionary) -> Dictionary:
	var normalized := source.duplicate(true)
	for field in [
		"schema_version", "challenge_depth", "local_player_count", "ai_player_count",
		"session_generation", "world_revision",
	]:
		var value: Variant = normalized.get(field)
		if value is float and is_equal_approx(value, float(int(value))):
			normalized[field] = int(value)
	return normalized


static func _contract_rejection(
	row: Dictionary,
	failing_field: String,
	failing_strategy: String,
	failing_stage: String,
	typed_reason: String
) -> Dictionary:
	return {
		"valid": false,
		"reason_code": EXPECTED_FAILURE_REASON,
		"failing_stage": failing_stage,
		"failing_section_id": str(row.get("section_id", "save_registry")),
		"failing_owner_id": str(row.get("owner_id", "")),
		"failing_field": failing_field,
		"failing_strategy": failing_strategy,
		"typed_reason": typed_reason,
		"private_payload_redacted": true,
	}


static func _validate_restore_dag(contract: Dictionary) -> Dictionary:
	if not (contract.get("restore_dag") is Array) \
			or not (contract.get("restore_dag_node_order") is Array):
		return _contract_rejection({}, "restore_dag", "", "registry", "wrong_type")
	var restore_dag := contract.get("restore_dag", []) as Array
	var declared_order := contract.get("restore_dag_node_order", []) as Array
	if restore_dag.is_empty() or restore_dag.size() != declared_order.size():
		return _contract_rejection({}, "restore_dag", "", "registry", "value_mismatch")
	var node_ids: Dictionary = {}
	var dependencies_by_node: Dictionary = {}
	for node_index in range(restore_dag.size()):
		if not (restore_dag[node_index] is Dictionary):
			return _contract_rejection({}, "restore_dag", "", "registry", "row_wrong_type")
		var node := restore_dag[node_index] as Dictionary
		var node_id := str(node.get("node_id", ""))
		if not (node.get("node_index") is int) or int(node.get("node_index", -1)) != node_index:
			return _contract_rejection({}, "restore_dag.node_index", "", "registry", "registration_order_mismatch")
		if node_id.is_empty() or node_id != str(declared_order[node_index]):
			return _contract_rejection({}, "restore_dag.node_id", "", "registry", "registration_order_mismatch")
		if node_ids.has(node_id):
			return _contract_rejection({}, "restore_dag.node_id", "", "registry", "duplicate")
		if str(node.get("section_id", "")).is_empty():
			return _contract_rejection({}, "restore_dag.section_id", "", "registry", "missing")
		if not (node.get("dependencies") is Array):
			return _contract_rejection({}, "restore_dag.dependencies", "", "registry", "wrong_type")
		node_ids[node_id] = true
		dependencies_by_node[node_id] = (node.get("dependencies", []) as Array).duplicate()
	for node_id in dependencies_by_node:
		for dependency in dependencies_by_node[node_id] as Array:
			if not node_ids.has(str(dependency)):
				return _contract_rejection({}, "restore_dag.dependencies", "", "registry", "missing_dependency")
	var cyclic_node := _first_cyclic_node(dependencies_by_node)
	if not cyclic_node.is_empty():
		return _contract_rejection({}, "restore_dag.dependencies", "", "registry", "dependency_cycle")
	return {"valid": true, "node_ids": node_ids}


static func _first_cyclic_node(dependencies_by_node: Dictionary) -> String:
	var resolved: Dictionary = {}
	var remaining: Array[String] = []
	for node_id in dependencies_by_node:
		remaining.append(str(node_id))
	remaining.sort()
	while not remaining.is_empty():
		var progressed := false
		for node_id in remaining.duplicate():
			var dependencies := dependencies_by_node.get(node_id, []) as Array
			var dependencies_resolved := true
			for dependency in dependencies:
				if not resolved.has(str(dependency)):
					dependencies_resolved = false
					break
			if dependencies_resolved:
				resolved[node_id] = true
				remaining.erase(node_id)
				progressed = true
		if not progressed:
			return remaining[0]
	return ""


static func _find_row(rows: Array, section_id: String) -> Dictionary:
	for row_variant in rows:
		if row_variant is Dictionary \
				and str((row_variant as Dictionary).get("section_id", "")) == section_id:
			return (row_variant as Dictionary).duplicate(true)
	return {}


static func _resolve_git_common_directory(project_root: String) -> String:
	var dot_git := project_root.path_join(".git")
	if DirAccess.dir_exists_absolute(dot_git):
		return dot_git.simplify_path()
	if not FileAccess.file_exists(dot_git):
		return ""
	var pointer := FileAccess.get_file_as_string(dot_git).strip_edges()
	if not pointer.begins_with("gitdir: "):
		return ""
	var git_directory := pointer.trim_prefix("gitdir: ").strip_edges()
	if not git_directory.is_absolute_path():
		git_directory = project_root.path_join(git_directory)
	git_directory = git_directory.simplify_path()
	var common_file := git_directory.path_join("commondir")
	if not FileAccess.file_exists(common_file):
		return git_directory
	var common_relative := FileAccess.get_file_as_string(common_file).strip_edges()
	if common_relative.is_empty():
		return ""
	return git_directory.path_join(common_relative).simplify_path()


static func _read_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


static func _sha256_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(FileAccess.get_file_as_bytes(path)) != OK:
		return ""
	return context.finish().hex_encode().to_lower()


static func _directory_fingerprint(root_path: String) -> String:
	var rows: Array[Dictionary] = []
	for relative_path in [
		"targeted_owner_capture_quota_ledger.json",
		"evidence/launch/orchestrator-3004/producer.authorized.json",
		"evidence/diagnostics/owner_capture_audit.json",
		"evidence/diagnostics/producer.phase_timeline.json",
		"evidence/child/producer.result.json",
		"evidence/child/producer.completion.json",
		"evidence/parent/producer.exit.json",
		"evidence/parent/producer.stdout.log",
		"evidence/parent/producer.stderr.log",
	]:
		var absolute_path := root_path.path_join(relative_path)
		if not FileAccess.file_exists(absolute_path):
			return ""
		rows.append({
			"relative_path": relative_path,
			"size": FileAccess.get_file_as_bytes(absolute_path).size(),
			"sha256": _sha256_file(absolute_path),
		})
	if rows.is_empty():
		return ""
	return JSON.stringify(rows, "", true, true).sha256_text().to_lower()


static func _lower_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for index in range(value.length()):
		if not "0123456789abcdef".contains(value.substr(index, 1)):
			return false
	return true


static func _blocked(result: Dictionary, reason_code: String) -> Dictionary:
	result["valid"] = false
	result["status"] = "BLOCKED"
	result["reason_code"] = reason_code
	return result


static func _base_result() -> Dictionary:
	return {
		"schema_version": 1,
		"replay_id": REPLAY_ID,
		"valid": false,
		"status": "BLOCKED",
		"reason_code": "not_run",
		"targeted_owner_capture_diagnostic_count_before": 6,
		"targeted_owner_capture_diagnostic_count_after": 6,
		"replay_diagnostic_count_delta": 0,
		"replay_quota_claim_count": 0,
		"replay_production_session_create_count": 0,
		"replay_owner_capture_count": 0,
		"replay_save_write_count": 0,
		"new_diagnostic_authorization_created": false,
		"process_a_save_completion_rehearsal_count": 0,
		"official_attempt_2_claim_created": false,
		"process_b_started": false,
		"process_c_started": false,
	}
