extends RefCounted
class_name Alpha04CV6RegistryBindingReplay

const DiagnosticScenarioIdentity := preload("res://scripts/tools/diagnostic_scenario_identity_v1.gd")
const ProductionRegistryComposition := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")
const SaveRegistry := preload("res://scripts/runtime/v06_save_owner_registry.gd")
const RegistryBindingValidator := preload(
	"res://scripts/tools/alpha04c_registry_binding_contract_validator_v1.gd"
)

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
	return RegistryBindingValidator.validate(contract, registry, EXPECTED_BINDING_COUNT)


static func validate_registry_projection(
	canonical_contract: Dictionary,
	observed_projection: Dictionary,
	registry: Node
) -> Dictionary:
	return RegistryBindingValidator.validate_projection(
		canonical_contract, observed_projection, registry, EXPECTED_BINDING_COUNT
	)


static func reseal_contract(contract: Dictionary) -> Dictionary:
	return RegistryBindingValidator.reseal_contract(contract)


static func binding_contract_fingerprint(row: Dictionary) -> String:
	return RegistryBindingValidator.binding_contract_fingerprint(row)


static func registry_contract_fingerprint(contract: Dictionary) -> String:
	return RegistryBindingValidator.registry_contract_fingerprint(contract)


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
	var relative_paths: Array[String] = []
	if not _collect_evidence_files(root_path, "", relative_paths):
		return _windows_long_path_directory_fingerprint(root_path)
	relative_paths.sort()
	var rows: Array[Dictionary] = []
	for relative_path in relative_paths:
		var absolute_path := root_path.path_join(relative_path)
		if not FileAccess.file_exists(absolute_path):
			return _windows_long_path_directory_fingerprint(root_path)
		var file_bytes := FileAccess.get_file_as_bytes(absolute_path)
		var file_sha256 := _sha256_file(absolute_path)
		if file_sha256.is_empty():
			return _windows_long_path_directory_fingerprint(root_path)
		rows.append({
			"relative_path": relative_path,
			"size": file_bytes.size(),
			"sha256": file_sha256,
		})
	if rows.is_empty():
		return _windows_long_path_directory_fingerprint(root_path)
	return JSON.stringify(rows, "", true, true).sha256_text().to_lower()


static func _windows_long_path_directory_fingerprint(root_path: String) -> String:
	if OS.get_name() != "Windows":
		return ""
	var encoded_root := Marshalls.raw_to_base64(root_path.to_utf8_buffer())
	var script := (
		("$root=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('%s'));" \
				% encoded_root)
		+ "$rows=@(Get-ChildItem -LiteralPath $root -Recurse -File | ForEach-Object {"
		+ "[pscustomobject][ordered]@{"
		+ "relative_path=[IO.Path]::GetRelativePath($root,$_.FullName).Replace('\\','/');"
		+ "size=[int64]$_.Length;"
		+ "sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()"
		+ "}} | Sort-Object relative_path);"
		+ "if($rows.Count -eq 0){exit 2};"
		+ "[Console]::Out.Write(($rows | ConvertTo-Json -Compress -Depth 4 -AsArray))"
	)
	var output: Array = []
	var exit_code := OS.execute(
		"pwsh.exe",
		PackedStringArray([
			"-NoLogo", "-NoProfile", "-NonInteractive", "-Command", script,
		]),
		output,
		false
	)
	if exit_code != 0:
		return ""
	var manifest_text := "".join(output).strip_edges()
	var parsed: Variant = JSON.parse_string(manifest_text)
	if not (parsed is Array) or (parsed as Array).is_empty():
		return ""
	return manifest_text.sha256_text().to_lower()


static func _collect_evidence_files(
	root_path: String,
	relative_directory: String,
	result: Array[String]
) -> bool:
	var absolute_directory := root_path \
			if relative_directory.is_empty() else root_path.path_join(relative_directory)
	var directory := DirAccess.open(absolute_directory)
	if directory == null:
		return false
	var files := directory.get_files()
	files.sort()
	for file_name in files:
		result.append(
			str(file_name) if relative_directory.is_empty() \
			else relative_directory.path_join(str(file_name)).replace("\\", "/")
		)
	var directories := directory.get_directories()
	directories.sort()
	for directory_name in directories:
		var child_relative := str(directory_name) if relative_directory.is_empty() \
				else relative_directory.path_join(str(directory_name)).replace("\\", "/")
		if not _collect_evidence_files(root_path, child_relative, result):
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
