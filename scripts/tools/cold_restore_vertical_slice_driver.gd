extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const CLAIM_REQUEST := preload("res://scripts/runtime/commodity_sushi_track_claim_request.gd")
const DISTRICT_SUPPLY_ACTION_INTENT := preload("res://scripts/runtime/district_supply_action_intent.gd")
const GAME_ACTION_INTENT := preload("res://scripts/semantic/game_action_intent_v1.gd")
const GAME_ACTION_OFFER := preload("res://scripts/semantic/game_action_offer_v1.gd")
const GAME_ACTION_RECEIPT := preload("res://scripts/semantic/game_action_receipt_v1.gd")
const SEMANTIC_WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const ALPHA_CONTENT_LOADER := preload("res://scripts/runtime/alpha01_content_manifest_loader.gd")
const TERMINAL_EVIDENCE := preload("res://scripts/tools/cold_restore_terminal_evidence.gd")
const AUTHORITATIVE_STEPPER := preload("res://scripts/tools/full_run_authoritative_runtime_stepper.gd")
const CHILD_ATTESTATION := preload("res://scripts/tools/cold_restore_child_completion_attestation.gd")

const FORMAL_FULL_RUN := false
const EXECUTION_READY := true
const ACCEPTANCE_SEED := 900626424
const ACCEPTANCE_CHALLENGE_DEPTH := 1
const SCHEMA_VERSION := 3
const OFFICIAL_CLAIM_SCHEMA_VERSION := 1
const OFFICIAL_AUTHORIZATION_ID := "alpha04c-p0-cold-restore-depth1-seed900626424-v1"
const OFFICIAL_CLAIM_RELATIVE_PATH := "codex/cold_restore_v3/official-alpha04c-depth1-seed900626424/official_claim_ledger.json"
const LAUNCH_ATTESTATION_SCHEMA_VERSION := 1
const PROCESS_ROLES := ["producer", "consumer", "validator"]
const INDUSTRY_IDS := ["life", "energy", "industry", "technology", "commerce", "shipping"]
const QUEUE_EFFECT_KINDS := [
	"build_upgrade_or_repair_facility",
	"global_order_budget",
	"global_supply_spawn",
]
const MAX_SUPPLY_CHURN := 40
const MAX_SALE_SECONDS := 180
const MAX_QUEUE_ASSET_SECONDS := 30
const MAX_QUEUE_PURCHASE_FUNDING_CYCLES := 4
const PUBLIC_MANIFEST_FIELDS := [
	"schema_version",
	"visibility_scope",
	"run_id",
	"process_role",
	"process_id",
	"head_sha",
	"slot_id",
	"slot_state",
	"source_sections_digest",
	"saved_sections_digest",
	"restored_sections_digest",
	"source_write_id",
	"write_id",
	"source_write_fingerprint",
	"section_count",
	"preflight_count",
	"owner_apply_count",
	"registry_apply_count",
	"save_capture_world_delta",
	"save_capture_rng_delta",
	"save_capture_log_delta",
	"rng_draw_count_before",
	"rng_draw_count_after",
	"restore_rng_draw_delta",
	"restore_world_time_delta",
	"restore_public_log_delta",
	"restore_sale_receipt_delta",
	"restore_economic_reward_delta",
	"restore_ai_action_delta",
	"restore_player_action_delta",
	"restore_notification_delta",
	"human_action_count",
	"commodity_action_count",
	"ai_action_count",
	"sale_receipt_count",
	"normal_card_count",
	"commodity_card_count",
	"commodity_claim_count",
	"facility_count",
	"route_count",
	"military_unit_count",
	"queue_entry_count",
	"weather_region_count",
	"ai_nondefault_state_count",
	"queue_trigger_resolution_id",
	"queue_trigger_stable_target_fingerprint",
	"queue_target_pending_before_resume",
	"queue_target_pending_after_resume",
	"queue_target_completed_before_resume",
	"queue_target_completed_after_resume",
	"queue_target_history_before_resume",
	"queue_target_history_after_resume",
	"queue_target_execution_finalize_delta",
	"queue_target_history_append_delta",
	"queue_target_history_duplicate_delta",
	"queue_target_transition_duplicate_delta",
	"queue_target_inventory_queue_commit_delta",
	"queue_target_public_log_duplicate_delta",
	"queue_target_public_log_collision_delta",
	"victory_unresolved_before_save",
	"production_surface_ready",
	"victory_state_sequence",
	"final_settlement_count",
	"final_settlement_presentation_count",
	"final_settlement_public_log_count",
	"terminal_quiescent_frames",
	"terminal_world_delta",
	"terminal_rng_draw_delta",
	"generation",
	"backup_created",
	"write_fingerprint",
	"elapsed_ms",
	"success",
	"failure_code",
]
const OFFICIAL_CLAIM_FIELDS := [
	"schema_version",
	"authorization_id",
	"created_at_utc",
	"run_id",
	"source_head_sha",
	"challenge_depth",
	"seed",
	"scenario_fingerprint",
	"qualification_child_attestation_fingerprint",
	"qualification_parent_attestation_sha256",
	"qualification_result_sha256",
	"orchestrator_id",
	"orchestrator_schema_version",
	"orchestrator_script_sha256",
	"orchestrator_process_id",
	"orchestrator_creation_time_utc_ticks",
	"claim_nonce",
	"status",
	"authorized_official_count",
	"official_count_before",
	"official_count_after",
]
const LAUNCH_ATTESTATION_FIELDS := [
	"schema_version",
	"authorization_id",
	"claim_fingerprint",
	"claim_nonce",
	"source_head_sha",
	"scenario_fingerprint",
	"run_id",
	"process_role",
	"launch_nonce",
	"orchestrator_process_id",
	"orchestrator_creation_time_utc_ticks",
	"wrapper_process_id",
	"wrapper_parent_process_id",
	"wrapper_creation_time_utc_ticks",
	"engine_process_id",
	"engine_parent_process_id",
	"engine_creation_time_utc_ticks",
	"status",
]
var _district_supply_request_revision := 0


func _init() -> void:
	call_deferred("_run_entry")


func _run_entry() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--cold-restore-contract-only"):
		print(JSON.stringify(contract_snapshot()))
		quit(0)
		return
	var parsed := _parse_options(args)
	if args.has("--cold-restore-qualification-probe"):
		var qualification_validation := validate_qualification_options(parsed)
		if not bool(qualification_validation.get("valid", false)):
			push_error("Cold restore qualification rejected: %s" % str(qualification_validation.get("reason_code", "options_invalid")))
			quit(10)
			return
		var qualification_run_id := str(qualification_validation.get("run_id", ""))
		var qualification := await _run_qualification_probe(qualification_run_id)
		qualification["product_blocker"] = _product_blocker(
			bool(qualification.get("success", false)),
			int(qualification.get("queue_count", 0)),
			str(qualification.get("failure_code", "qualification_incomplete"))
		)
		var qualification_result_write := CHILD_ATTESTATION.write_result(
			qualification_run_id,
			"qualification",
			qualification
		)
		if not bool(qualification_result_write.get("valid", false)):
			push_error("Cold restore qualification result write failed: %s" % str(qualification_result_write.get("reason_code", "child_result_write_failed")))
			quit(_evidence_exit_code(qualification_result_write))
			return
		var qualification_attestation := CHILD_ATTESTATION.build({
			"run_id": qualification_run_id,
			"role": "qualification",
			"repository_head": str(qualification_validation.get("head_sha", "")),
			"scenario_fingerprint": str(qualification.get("scenario_fingerprint", "")),
			"official": false,
			"formal": false,
			"qualification_completed": true,
			"qualification_green": bool(qualification.get("success", false)),
			"product_blocker": str(qualification.get("product_blocker", "")),
			"queue_count": int(qualification.get("queue_count", 0)),
			"queue_revision": int(qualification.get("queue_revision", 0)),
			"queue_trigger_actor": str(qualification.get("queue_trigger_actor", "none")),
			"queue_trigger_semantic_action_id": str(qualification.get("queue_trigger_semantic_action_id", "")),
			"queue_trigger_card_semantic_id": str(qualification.get("queue_trigger_card_semantic_id", "")),
			"queue_trigger_target_fingerprint": str(qualification.get("queue_trigger_target_fingerprint", "")),
			"save_written": false,
			"official_count_consumed": false,
			"product_mutation_count": int(qualification.get("human_action_count", 0)) \
				+ int(qualification.get("ai_action_count", 0)) \
				+ int(qualification.get("sale_receipt_count", 0)),
			"direct_authority_mutation_count": 0,
			"queue_injection_count": 0,
			"final_reason_code": "qualification_green" if bool(qualification.get("success", false)) \
				else str(qualification.get("product_blocker", "")),
			"child_ready_to_exit": true,
		})
		var qualification_attestation_write := CHILD_ATTESTATION.write_completion(qualification_attestation)
		if not bool(qualification_attestation_write.get("valid", false)):
			push_error("Cold restore qualification attestation failed: %s" % str(qualification_attestation_write.get("reason_code", "child_attestation_write_failed")))
			quit(_evidence_exit_code(qualification_attestation_write))
			return
		print("COLD_RESTORE_QUALIFICATION|%s" % JSON.stringify(qualification))
		quit(0)
		return
	var validation := validate_options(parsed)
	if not bool(validation.get("valid", false)):
		push_error("Cold restore options rejected: %s" % str(validation.get("reason_code", "options_invalid")))
		quit(10)
		return
	var launch_authorization := await _authorize_official_launch(validation, str(parsed.get("head_sha", "")))
	if not bool(launch_authorization.get("authorized", false)):
		push_error("Cold restore launch rejected: %s" % str(launch_authorization.get("reason_code", "official_launch_unauthorized")))
		quit(2)
		return
	validation["official_count_consumed"] = true
	var started_ms := Time.get_ticks_msec()
	var result: Dictionary = await _run_role(validation, str(parsed.get("head_sha", "")))
	result["elapsed_ms"] = maxi(0, Time.get_ticks_msec() - started_ms)
	var manifest := sanitize_public_manifest(result)
	if manifest.is_empty():
		push_error("Cold restore public manifest sanitization failed")
		quit(12)
		return
	var manifest_write := _write_public_manifest(
		str(validation.get("run_id", "")),
		str(validation.get("process_role", "")),
		manifest
	)
	if not bool(manifest_write.get("valid", false)):
		push_error("Cold restore public manifest write failed: %s" % str(manifest_write.get("reason_code", "child_result_write_failed")))
		quit(_evidence_exit_code(manifest_write))
		return
	var role_success := bool(manifest.get("success", false))
	var role_attestation := CHILD_ATTESTATION.build({
		"run_id": str(validation.get("run_id", "")),
		"role": str(validation.get("process_role", "")),
		"repository_head": str(parsed.get("head_sha", "")),
		"scenario_fingerprint": str(validation.get("scenario_fingerprint", "")),
		"official": true,
		"formal": false,
		"qualification_completed": true,
		"qualification_green": role_success,
		"product_blocker": _product_blocker(
			role_success,
			int(manifest.get("queue_entry_count", 0)),
			str(manifest.get("failure_code", "role_failed"))
		),
		"queue_count": int(manifest.get("queue_entry_count", 0)),
		"queue_revision": int(result.get("_attestation_queue_revision", 0)),
		"queue_trigger_actor": str(result.get("_attestation_queue_trigger_actor", "none")),
		"queue_trigger_semantic_action_id": str(result.get("_attestation_queue_trigger_semantic_action_id", "")),
		"queue_trigger_card_semantic_id": str(result.get("_attestation_queue_trigger_card_semantic_id", "")),
		"queue_trigger_target_fingerprint": str(manifest.get("queue_trigger_stable_target_fingerprint", "")),
		"save_written": role_success and int(manifest.get("generation", 0)) in [1, 2] \
			and str(validation.get("process_role", "")) in ["producer", "consumer"],
		"official_count_consumed": bool(validation.get("official_count_consumed", false)),
		"product_mutation_count": int(manifest.get("human_action_count", 0)) \
			+ int(manifest.get("commodity_action_count", 0)) \
			+ int(manifest.get("ai_action_count", 0)) \
			+ int(manifest.get("sale_receipt_count", 0)),
		"direct_authority_mutation_count": 0,
		"queue_injection_count": 0,
		"final_reason_code": "role_completed" if role_success else str(manifest.get("failure_code", "role_failed")),
		"child_ready_to_exit": true,
	})
	var role_attestation_write := CHILD_ATTESTATION.write_completion(role_attestation)
	if not bool(role_attestation_write.get("valid", false)):
		push_error("Cold restore role attestation failed: %s" % str(role_attestation_write.get("reason_code", "child_attestation_write_failed")))
		quit(_evidence_exit_code(role_attestation_write))
		return
	print("COLD_RESTORE_MANIFEST|%s" % JSON.stringify(manifest))
	quit(0)


static func contract_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"driver_id": "alpha04c_cold_restore_vertical_slice_v3",
		"formal_full_run": FORMAL_FULL_RUN,
		"cold_restore_vertical_slice": true,
		"execution_ready": EXECUTION_READY,
		"process_sequence": ["atomic_result", "child_completion_attestation", "child_ready_to_exit", "parent_exit_attestation"],
		"process_roles": PROCESS_ROLES.duplicate(),
		"qa_save_root": SaveSlotPolicyV06.QA_ROOT,
		"production_slot_id": String(SaveSlotPolicyV06.PRODUCTION_SLOT_ID),
		"shares_gameplay_process_memory": false,
		"raw_envelope_in_evidence": false,
		"runtime_loop_frozen_until_restore_commit": true,
		"minimum_post_restore_ticks": 1,
		"terminal_quiescent_frames": 8,
		"official_ledger_required": true,
		"launch_attestation_required": true,
		"caller_boolean_authorization_accepted": false,
	}


static func validate_options(options: Dictionary) -> Dictionary:
	var run_id := str(options.get("run_id", ""))
	var process_role := str(options.get("process_role", ""))
	if not str(options.get("parse_error", "")).is_empty():
		return {"valid": false, "reason_code": str(options.get("parse_error", "options_parse_invalid"))}
	if process_role not in PROCESS_ROLES:
		return {"valid": false, "reason_code": "process_role_invalid"}
	var qa_path := SaveSlotPolicyV06.qa_path(run_id, "current_run")
	if qa_path.is_empty():
		return {"valid": false, "reason_code": "run_id_invalid"}
	var head_sha := str(options.get("head_sha", ""))
	if head_sha.length() < 7 or head_sha.length() > 64 or not _is_lower_hex(head_sha):
		return {"valid": false, "reason_code": "head_sha_invalid"}
	var artifact_root := str(options.get("artifact_root", ""))
	var expected_artifact_root := "user://test_runs/alpha04c/%s/evidence" % run_id
	if artifact_root != expected_artifact_root:
		return {"valid": false, "reason_code": "artifact_root_invalid"}
	var official_claim_path := str(options.get("official_claim_path", ""))
	if official_claim_path.is_empty() or not official_claim_path.is_absolute_path():
		return {"valid": false, "reason_code": "official_claim_path_invalid"}
	var launch_attestation_path := str(options.get("launch_attestation_path", ""))
	if launch_attestation_path.is_empty() or not launch_attestation_path.is_absolute_path():
		return {"valid": false, "reason_code": "launch_attestation_path_invalid"}
	var launch_nonce := str(options.get("launch_nonce", ""))
	if launch_nonce.length() != 32 or not _is_lower_hex(launch_nonce):
		return {"valid": false, "reason_code": "launch_nonce_invalid"}
	var expected_resolution_id := int(options.get("expected_queue_resolution_id", 0))
	var expected_stable_fingerprint := str(options.get("expected_queue_stable_target_fingerprint", ""))
	if process_role == "producer":
		if expected_resolution_id != 0 or not expected_stable_fingerprint.is_empty():
			return {"valid": false, "reason_code": "producer_expected_queue_identity_forbidden"}
	elif expected_resolution_id <= 0 or not _is_lower_sha256(expected_stable_fingerprint):
		return {"valid": false, "reason_code": "expected_queue_identity_invalid"}
	var scenario_fingerprint := str(options.get("scenario_fingerprint", ""))
	if not _is_lower_sha256(scenario_fingerprint):
		return {"valid": false, "reason_code": "scenario_fingerprint_invalid"}
	return {
		"valid": true,
		"reason_code": "ok",
		"run_id": run_id,
		"process_role": process_role,
		"qa_evidence_path": qa_path,
		"save_path": SaveSlotPolicyV06.PRODUCTION_PATH,
		"artifact_root": artifact_root,
		"official_claim_path": official_claim_path,
		"launch_attestation_path": launch_attestation_path,
		"launch_nonce": launch_nonce,
		"expected_queue_resolution_id": expected_resolution_id,
		"expected_queue_stable_target_fingerprint": expected_stable_fingerprint,
		"scenario_fingerprint": scenario_fingerprint,
		"official_count_consumed": false,
	}


static func validate_qualification_options(options: Dictionary) -> Dictionary:
	if not str(options.get("parse_error", "")).is_empty():
		return {"valid": false, "reason_code": str(options.get("parse_error", "options_parse_invalid"))}
	var run_id := str(options.get("run_id", ""))
	if SaveSlotPolicyV06.qa_path(run_id, "qualification").is_empty():
		return {"valid": false, "reason_code": "run_id_invalid"}
	if str(options.get("process_role", "")) != "qualification":
		return {"valid": false, "reason_code": "qualification_role_invalid"}
	var head_sha := str(options.get("head_sha", ""))
	if head_sha.length() < 7 or head_sha.length() > 64 or not _is_lower_hex(head_sha):
		return {"valid": false, "reason_code": "head_sha_invalid"}
	var expected_artifact_root := "user://test_runs/alpha04c/%s/evidence" % run_id
	if str(options.get("artifact_root", "")) != expected_artifact_root:
		return {"valid": false, "reason_code": "artifact_root_invalid"}
	if int(options.get("expected_queue_resolution_id", 0)) != 0 \
			or not str(options.get("expected_queue_stable_target_fingerprint", "")).is_empty() \
			or not str(options.get("scenario_fingerprint", "")).is_empty() \
			or not str(options.get("official_claim_path", "")).is_empty() \
			or not str(options.get("launch_attestation_path", "")).is_empty() \
			or not str(options.get("launch_nonce", "")).is_empty():
		return {"valid": false, "reason_code": "qualification_official_state_forbidden"}
	return {
		"valid": true,
		"reason_code": "ok",
		"run_id": run_id,
		"head_sha": head_sha,
		"artifact_root": expected_artifact_root,
	}


static func _is_lower_hex(value: String) -> bool:
	if value.is_empty():
		return false
	for index in range(value.length()):
		if not "0123456789abcdef".contains(value.substr(index, 1)):
			return false
	return true


static func _is_lower_sha256(value: String) -> bool:
	return value.length() == 64 and _is_lower_hex(value)


func _authorize_official_launch(options: Dictionary, head_sha: String) -> Dictionary:
	var claim_path := _normalize_absolute_path(str(options.get("official_claim_path", "")))
	var expected_claim_path := _resolve_official_claim_path()
	if claim_path.is_empty() or expected_claim_path.is_empty() \
			or claim_path.to_lower() != expected_claim_path.to_lower():
		return {"authorized": false, "reason_code": "official_claim_path_mismatch"}
	if not FileAccess.file_exists(claim_path):
		return {"authorized": false, "reason_code": "official_claim_missing"}
	var claim_text := FileAccess.get_file_as_string(claim_path)
	var claim_variant: Variant = JSON.parse_string(claim_text)
	if not (claim_variant is Dictionary):
		return {"authorized": false, "reason_code": "official_claim_invalid"}
	var claim := claim_variant as Dictionary
	if not _has_exact_fields(claim, OFFICIAL_CLAIM_FIELDS):
		return {"authorized": false, "reason_code": "official_claim_field_set_invalid"}
	if int(claim.get("schema_version", 0)) != OFFICIAL_CLAIM_SCHEMA_VERSION \
			or str(claim.get("authorization_id", "")) != OFFICIAL_AUTHORIZATION_ID \
			or str(claim.get("run_id", "")) != str(options.get("run_id", "")) \
			or str(claim.get("source_head_sha", "")) != head_sha \
			or int(claim.get("challenge_depth", 0)) != ACCEPTANCE_CHALLENGE_DEPTH \
			or int(claim.get("seed", 0)) != ACCEPTANCE_SEED \
			or str(claim.get("scenario_fingerprint", "")) != str(options.get("scenario_fingerprint", "")) \
			or not _is_lower_sha256(str(claim.get("qualification_child_attestation_fingerprint", ""))) \
			or not _is_lower_sha256(str(claim.get("qualification_parent_attestation_sha256", ""))) \
			or not _is_lower_sha256(str(claim.get("qualification_result_sha256", ""))) \
			or str(claim.get("orchestrator_id", "")) != "alpha04c_cold_restore_vertical_slice_orchestrator_v3" \
			or int(claim.get("orchestrator_schema_version", 0)) != SCHEMA_VERSION \
			or not _is_lower_sha256(str(claim.get("orchestrator_script_sha256", ""))) \
			or str(claim.get("claim_nonce", "")).length() != 32 \
			or not _is_lower_hex(str(claim.get("claim_nonce", ""))) \
			or int(claim.get("orchestrator_process_id", 0)) <= 0 \
			or not _is_positive_decimal(str(claim.get("orchestrator_creation_time_utc_ticks", ""))) \
			or str(claim.get("status", "")) != "consumed" \
			or int(claim.get("authorized_official_count", 0)) != 1 \
			or int(claim.get("official_count_before", -1)) != 0 \
			or int(claim.get("official_count_after", 0)) != 1:
		return {"authorized": false, "reason_code": "official_claim_binding_invalid"}
	var claim_fingerprint := claim_text.sha256_text()
	var attestation_path := _normalize_absolute_path(str(options.get("launch_attestation_path", "")))
	var deadline_ms := Time.get_ticks_msec() + 10000
	while not FileAccess.file_exists(attestation_path) and Time.get_ticks_msec() < deadline_ms:
		await create_timer(0.025).timeout
	if not FileAccess.file_exists(attestation_path):
		return {"authorized": false, "reason_code": "launch_attestation_missing"}
	var attestation_variant: Variant = JSON.parse_string(FileAccess.get_file_as_string(attestation_path))
	if not (attestation_variant is Dictionary):
		return {"authorized": false, "reason_code": "launch_attestation_invalid"}
	var attestation := attestation_variant as Dictionary
	if not _has_exact_fields(attestation, LAUNCH_ATTESTATION_FIELDS):
		return {"authorized": false, "reason_code": "launch_attestation_field_set_invalid"}
	var orchestrator_process_id := int(attestation.get("orchestrator_process_id", 0))
	var wrapper_process_id := int(attestation.get("wrapper_process_id", 0))
	var wrapper_parent_process_id := int(attestation.get("wrapper_parent_process_id", 0))
	var engine_process_id := int(attestation.get("engine_process_id", 0))
	var engine_parent_process_id := int(attestation.get("engine_parent_process_id", 0))
	var process_relation_valid := wrapper_parent_process_id == orchestrator_process_id
	if engine_process_id == wrapper_process_id:
		process_relation_valid = process_relation_valid \
				and engine_parent_process_id == orchestrator_process_id \
				and str(attestation.get("engine_creation_time_utc_ticks", "")) \
					== str(attestation.get("wrapper_creation_time_utc_ticks", ""))
	else:
		process_relation_valid = process_relation_valid and engine_parent_process_id == wrapper_process_id
	var expected_attestation_path := _expected_launch_attestation_path(
		str(options.get("run_id", "")),
		str(options.get("process_role", "")),
		orchestrator_process_id
	)
	if int(attestation.get("schema_version", 0)) != LAUNCH_ATTESTATION_SCHEMA_VERSION \
			or str(attestation.get("authorization_id", "")) != OFFICIAL_AUTHORIZATION_ID \
			or str(attestation.get("claim_fingerprint", "")) != claim_fingerprint \
			or str(attestation.get("claim_nonce", "")) != str(claim.get("claim_nonce", "")) \
			or str(attestation.get("source_head_sha", "")) != head_sha \
			or str(attestation.get("scenario_fingerprint", "")) != str(options.get("scenario_fingerprint", "")) \
			or str(attestation.get("run_id", "")) != str(options.get("run_id", "")) \
			or str(attestation.get("process_role", "")) != str(options.get("process_role", "")) \
			or str(attestation.get("launch_nonce", "")) != str(options.get("launch_nonce", "")) \
			or str(attestation.get("status", "")) != "authorized" \
			or orchestrator_process_id != int(claim.get("orchestrator_process_id", 0)) \
			or str(attestation.get("orchestrator_creation_time_utc_ticks", "")) \
				!= str(claim.get("orchestrator_creation_time_utc_ticks", "")) \
			or wrapper_process_id <= 0 \
			or engine_process_id != OS.get_process_id() \
			or not process_relation_valid \
			or expected_attestation_path.is_empty() \
			or attestation_path.to_lower() != expected_attestation_path.to_lower():
		return {"authorized": false, "reason_code": "launch_attestation_binding_invalid"}
	for ticks_field in [
		"orchestrator_creation_time_utc_ticks",
		"wrapper_creation_time_utc_ticks",
		"engine_creation_time_utc_ticks",
	]:
		if not _is_positive_decimal(str(attestation.get(ticks_field, ""))):
			return {"authorized": false, "reason_code": "launch_attestation_creation_time_invalid"}
	return {"authorized": true, "reason_code": "ok"}


static func _has_exact_fields(value: Dictionary, expected_fields: Array) -> bool:
	if value.size() != expected_fields.size():
		return false
	for field_variant in expected_fields:
		if not value.has(str(field_variant)):
			return false
	return true


static func _is_positive_decimal(value: String) -> bool:
	if value.is_empty() or value.length() > 19 or value.begins_with("0"):
		return false
	for index in range(value.length()):
		if not "0123456789".contains(value.substr(index, 1)):
			return false
	return true


static func _normalize_absolute_path(value: String) -> String:
	if value.is_empty() or not value.is_absolute_path():
		return ""
	return value.replace("\\", "/").simplify_path().trim_suffix("/")


static func _resolve_official_claim_path() -> String:
	var common_dir := _resolve_git_common_dir()
	if common_dir.is_empty():
		return ""
	return _normalize_absolute_path(common_dir.path_join(OFFICIAL_CLAIM_RELATIVE_PATH))


static func _resolve_git_common_dir() -> String:
	var project_root := _normalize_absolute_path(ProjectSettings.globalize_path("res://"))
	if project_root.is_empty():
		return ""
	var git_marker := project_root.path_join(".git")
	if DirAccess.dir_exists_absolute(git_marker):
		return _normalize_absolute_path(git_marker)
	if not FileAccess.file_exists(git_marker):
		return ""
	var marker_text := FileAccess.get_file_as_string(git_marker).strip_edges()
	if not marker_text.begins_with("gitdir:"):
		return ""
	var git_dir := marker_text.trim_prefix("gitdir:").strip_edges()
	if not git_dir.is_absolute_path():
		git_dir = project_root.path_join(git_dir)
	git_dir = _normalize_absolute_path(git_dir)
	if git_dir.is_empty():
		return ""
	var common_dir_path := git_dir.path_join("commondir")
	if not FileAccess.file_exists(common_dir_path):
		return git_dir
	var common_dir := FileAccess.get_file_as_string(common_dir_path).strip_edges()
	if not common_dir.is_absolute_path():
		common_dir = git_dir.path_join(common_dir)
	return _normalize_absolute_path(common_dir)


static func _expected_launch_attestation_path(run_id: String, role: String, orchestrator_process_id: int) -> String:
	if run_id.is_empty() or role not in PROCESS_ROLES or orchestrator_process_id <= 0:
		return ""
	var project_root := _normalize_absolute_path(ProjectSettings.globalize_path("res://"))
	return _normalize_absolute_path(project_root.path_join(
		".godot/cold_restore_attestation_v1/%s/launch/orchestrator-%d/%s.authorized.json" \
			% [run_id, orchestrator_process_id, role]
	))




static func sanitize_public_manifest(source: Dictionary) -> Dictionary:
	var result := {
		"schema_version": SCHEMA_VERSION,
		"visibility_scope": "qa_allowlisted",
		"run_id": str(source.get("run_id", "")),
		"process_role": str(source.get("process_role", "")),
		"process_id": maxi(0, int(source.get("process_id", 0))),
		"head_sha": str(source.get("head_sha", "")),
		"slot_id": String(SaveSlotPolicyV06.PRODUCTION_SLOT_ID),
		"slot_state": str(source.get("slot_state", "failed")),
		"source_sections_digest": str(source.get("source_sections_digest", "")),
		"saved_sections_digest": str(source.get("saved_sections_digest", "")),
		"restored_sections_digest": str(source.get("restored_sections_digest", "")),
		"source_write_id": str(source.get("source_write_id", "")),
		"write_id": str(source.get("write_id", "")),
		"source_write_fingerprint": str(source.get("source_write_fingerprint", "")),
		"section_count": maxi(0, int(source.get("section_count", 0))),
		"preflight_count": maxi(0, int(source.get("preflight_count", 0))),
		"owner_apply_count": maxi(0, int(source.get("owner_apply_count", 0))),
		"registry_apply_count": maxi(0, int(source.get("registry_apply_count", 0))),
		"save_capture_world_delta": int(source.get("save_capture_world_delta", 0)),
		"save_capture_rng_delta": int(source.get("save_capture_rng_delta", 0)),
		"save_capture_log_delta": int(source.get("save_capture_log_delta", 0)),
		"rng_draw_count_before": maxi(0, int(source.get("rng_draw_count_before", 0))),
		"rng_draw_count_after": maxi(0, int(source.get("rng_draw_count_after", 0))),
		"restore_rng_draw_delta": int(source.get("restore_rng_draw_delta", 0)),
		"restore_world_time_delta": int(source.get("restore_world_time_delta", 0)),
		"restore_public_log_delta": int(source.get("restore_public_log_delta", 0)),
		"restore_sale_receipt_delta": int(source.get("restore_sale_receipt_delta", 0)),
		"restore_economic_reward_delta": int(source.get("restore_economic_reward_delta", 0)),
		"restore_ai_action_delta": int(source.get("restore_ai_action_delta", 0)),
		"restore_player_action_delta": int(source.get("restore_player_action_delta", 0)),
		"restore_notification_delta": int(source.get("restore_notification_delta", 0)),
		"human_action_count": maxi(0, int(source.get("human_action_count", 0))),
		"commodity_action_count": maxi(0, int(source.get("commodity_action_count", 0))),
		"ai_action_count": maxi(0, int(source.get("ai_action_count", 0))),
		"sale_receipt_count": maxi(0, int(source.get("sale_receipt_count", 0))),
		"normal_card_count": maxi(0, int(source.get("normal_card_count", 0))),
		"commodity_card_count": maxi(0, int(source.get("commodity_card_count", 0))),
		"commodity_claim_count": maxi(0, int(source.get("commodity_claim_count", 0))),
		"facility_count": maxi(0, int(source.get("facility_count", 0))),
		"route_count": maxi(0, int(source.get("route_count", 0))),
		"military_unit_count": maxi(0, int(source.get("military_unit_count", 0))),
		"queue_entry_count": maxi(0, int(source.get("queue_entry_count", 0))),
		"weather_region_count": maxi(0, int(source.get("weather_region_count", 0))),
		"ai_nondefault_state_count": maxi(0, int(source.get("ai_nondefault_state_count", 0))),
		"queue_trigger_resolution_id": maxi(0, int(source.get("queue_trigger_resolution_id", 0))),
		"queue_trigger_stable_target_fingerprint": str(source.get("queue_trigger_stable_target_fingerprint", "")),
		"queue_target_pending_before_resume": maxi(0, int(source.get("queue_target_pending_before_resume", 0))),
		"queue_target_pending_after_resume": maxi(0, int(source.get("queue_target_pending_after_resume", 0))),
		"queue_target_completed_before_resume": maxi(0, int(source.get("queue_target_completed_before_resume", 0))),
		"queue_target_completed_after_resume": maxi(0, int(source.get("queue_target_completed_after_resume", 0))),
		"queue_target_history_before_resume": maxi(0, int(source.get("queue_target_history_before_resume", 0))),
		"queue_target_history_after_resume": maxi(0, int(source.get("queue_target_history_after_resume", 0))),
		"queue_target_execution_finalize_delta": maxi(0, int(source.get("queue_target_execution_finalize_delta", 0))),
		"queue_target_history_append_delta": maxi(0, int(source.get("queue_target_history_append_delta", 0))),
		"queue_target_history_duplicate_delta": maxi(0, int(source.get("queue_target_history_duplicate_delta", 0))),
		"queue_target_transition_duplicate_delta": maxi(0, int(source.get("queue_target_transition_duplicate_delta", 0))),
		"queue_target_inventory_queue_commit_delta": maxi(0, int(source.get("queue_target_inventory_queue_commit_delta", 0))),
		"queue_target_public_log_duplicate_delta": maxi(0, int(source.get("queue_target_public_log_duplicate_delta", 0))),
		"queue_target_public_log_collision_delta": maxi(0, int(source.get("queue_target_public_log_collision_delta", 0))),
		"victory_unresolved_before_save": bool(source.get("victory_unresolved_before_save", false)),
		"production_surface_ready": bool(source.get("production_surface_ready", false)),
		"victory_state_sequence": (source.get("victory_state_sequence", []) as Array).duplicate() if source.get("victory_state_sequence") is Array else [],
		"final_settlement_count": maxi(0, int(source.get("final_settlement_count", 0))),
		"final_settlement_presentation_count": maxi(0, int(source.get("final_settlement_presentation_count", 0))),
		"final_settlement_public_log_count": maxi(0, int(source.get("final_settlement_public_log_count", 0))),
		"terminal_quiescent_frames": maxi(0, int(source.get("terminal_quiescent_frames", 0))),
		"terminal_world_delta": int(source.get("terminal_world_delta", 0)),
		"terminal_rng_draw_delta": int(source.get("terminal_rng_draw_delta", 0)),
		"generation": maxi(0, int(source.get("generation", 0))),
		"backup_created": bool(source.get("backup_created", false)),
		"write_fingerprint": str(source.get("write_fingerprint", "")),
		"elapsed_ms": maxi(0, int(source.get("elapsed_ms", 0))),
		"success": bool(source.get("success", false)),
		"failure_code": str(source.get("failure_code", "")),
	}
	return result if _manifest_shape_valid(result) else {}


static func _manifest_shape_valid(manifest: Dictionary) -> bool:
	if manifest.size() != PUBLIC_MANIFEST_FIELDS.size():
		return false
	for field_variant in PUBLIC_MANIFEST_FIELDS:
		if not manifest.has(str(field_variant)):
			return false
	if str(manifest.get("visibility_scope", "")) != "qa_allowlisted" \
			or str(manifest.get("process_role", "")) not in PROCESS_ROLES \
			or str(manifest.get("slot_state", "")) not in ["ready", "restored", "validated", "failed"]:
		return false
	if (manifest.get("victory_state_sequence", []) as Array).size() > 12:
		return false
	for field in ["run_id", "head_sha", "source_sections_digest", "saved_sections_digest", "restored_sections_digest", "source_write_id", "write_id", "source_write_fingerprint", "write_fingerprint", "queue_trigger_stable_target_fingerprint", "failure_code"]:
		if str(manifest.get(field, "")).length() > 128:
			return false
	var queue_target_fingerprint := str(manifest.get("queue_trigger_stable_target_fingerprint", ""))
	if not queue_target_fingerprint.is_empty() and not _is_lower_sha256(queue_target_fingerprint):
		return false
	return true


func _run_role(options: Dictionary, head_sha: String) -> Dictionary:
	var role := str(options.get("process_role", ""))
	var base := _manifest_base(str(options.get("run_id", "")), role, head_sha)
	var main := MAIN_SCENE.instantiate()
	var lifecycle := main.get_node_or_null("RuntimeServices/MenuLifecycleApplicationFlowController")
	if lifecycle != null:
		lifecycle.set("open_root_on_ready", false)
	root.add_child(main)
	await process_frame
	await process_frame
	var context := _runtime_context(main)
	if not bool(context.get("ready", false)):
		return _fail(base, "runtime_context_unavailable")
	var registry: Node = context.get("registry")
	var registry_snapshot: Dictionary = registry.call("registry_snapshot")
	if not bool(registry_snapshot.get("resume_ready", false)) \
			or int(registry_snapshot.get("transactional_section_count", 0)) != 19 \
			or int(registry_snapshot.get("unsupported_section_count", -1)) != 0 \
			or not bool(registry_snapshot.get("restore_barrier_ready", false)):
		return _fail(base, "registry_not_resume_ready")
	var result: Dictionary
	match role:
		"producer":
			result = await _run_producer(context, options, base)
		"consumer":
			result = await _run_consumer(context, options, base)
		"validator":
			result = await _run_validator(context, options, base)
		_:
			result = _fail(base, "process_role_invalid")
	main.queue_free()
	await process_frame
	return result


func _run_qualification_probe(run_id: String) -> Dictionary:
	var result := {
		"schema_version": 1,
		"qualification_probe": true,
		"official_cold_restore_vertical_slice": false,
		"formal_full_run": false,
		"run_id": run_id,
		"challenge_depth": 0,
		"seed": 0,
		"scenario_fingerprint": "",
		"human_action_count": 0,
		"commodity_action_count": 0,
		"normal_card_purchase_count": 0,
		"facility_action_count": 0,
		"sale_receipt_count": 0,
		"ai_action_count": 0,
		"ai_state_fingerprint_changed": false,
		"queue_trigger_actor": "none",
		"queue_trigger_semantic_action_id": "",
		"queue_trigger_card_semantic_id": "",
		"queue_trigger_target_fingerprint": "",
		"queue_count": 0,
		"queue_revision": 0,
		"offer_audit": {
			"legal_offers": [],
			"queue_capable_offers": [],
			"rejected_offers": [],
		},
		"card_resolution_advance_after_trigger": -1,
		"world_advance_after_trigger": -1,
		"rng_draw_after_trigger": -1,
		"normal_card_count": 0,
		"commodity_card_count": 0,
		"commodity_claim_count": 0,
		"facility_count": 0,
		"route_count": 0,
		"weather_region_count": 0,
		"ai_nondefault_state_count": 0,
		"production_surface_ready": false,
		"save_written": false,
		"success": false,
		"failure_code": "qualification_not_started",
	}
	var main := MAIN_SCENE.instantiate()
	var lifecycle := main.get_node_or_null("RuntimeServices/MenuLifecycleApplicationFlowController")
	if lifecycle != null:
		lifecycle.set("open_root_on_ready", false)
	root.add_child(main)
	await process_frame
	await process_frame
	var context := _runtime_context(main)
	if not bool(context.get("ready", false)):
		result["failure_code"] = "runtime_context_unavailable"
		main.queue_free()
		await process_frame
		return result
	var registry := context.get("registry") as Node
	var registry_snapshot: Dictionary = registry.call("registry_snapshot")
	if not bool(registry_snapshot.get("resume_ready", false)) \
			or int(registry_snapshot.get("transactional_section_count", 0)) != 19 \
			or int(registry_snapshot.get("unsupported_section_count", -1)) != 0:
		result["failure_code"] = "registry_not_resume_ready"
		main.queue_free()
		await process_frame
		return result
	var started := _start_default_session(context, run_id)
	if not bool(started.get("applied", false)):
		result["failure_code"] = str(started.get("reason_code", "session_start_failed"))
		main.queue_free()
		await process_frame
		return result
	result["challenge_depth"] = int(started.get("challenge_depth", 0))
	result["seed"] = int(started.get("seed", 0))
	result["scenario_fingerprint"] = str(started.get("scenario_fingerprint", ""))
	var initial_ai_digest := _ai_state_digest(context)
	var human := _submit_human_selection(context, "qualification-human", 1)
	var legal: Dictionary = await _prepare_facility_queue_checkpoint(context)
	if not bool(legal.get("ready", false)):
		result["failure_code"] = str(legal.get("reason_code", "legal_checkpoint_failed"))
		result["offer_audit"] = _qualification_offer_audit(legal, {})
		print("COLD_RESTORE_QUALIFICATION_DIAGNOSTIC|" + JSON.stringify({
			"run_id": run_id,
			"failure_code": result["failure_code"],
			"details": legal.get("diagnostics", {}),
		}))
		main.queue_free()
		await process_frame
		return result
	var coordinator := context.get("coordinator") as GameRuntimeCoordinator
	coordinator.resume_session()
	var ai_actions := _tick_ai_until_action(context, 120)
	var final_ai_digest := _ai_state_digest(context)
	var drain := _drain_pending_queue(context, 120)
	if not bool(drain.get("drained", false)):
		result["failure_code"] = "pre_trigger_queue_not_empty"
		main.queue_free()
		await process_frame
		return result
	var queue_capability := {
		"ready": true,
		"reason_code": "facility_queue_capability_ready",
		"sale_receipt_count": 0,
	}
	coordinator.resume_session()
	coordinator.request_table_presentation_refresh(&"full", &"cold_restore_qualification_offer_sync")
	await process_frame
	await process_frame
	var trigger := _submit_first_formal_queue_offer(
		context,
		str(legal.get("queue_facility_card_id", "")),
		str(legal.get("queue_facility_region_id", ""))
	)
	if not bool(trigger.get("accepted", false)) or not bool(trigger.get("queued", false)):
		result["failure_code"] = str(trigger.get("reason_code", "legal_queue_offer_missing"))
		result["queue_count"] = int(trigger.get("queue_count", 0))
		result["queue_revision"] = int(trigger.get("queue_revision", 0))
		result["offer_audit"] = _qualification_offer_audit(legal, trigger)
		print("COLD_RESTORE_QUALIFICATION_DIAGNOSTIC|" + JSON.stringify({
			"run_id": run_id,
			"failure_code": result["failure_code"],
			"local_queue_capability": queue_capability,
			"trigger": trigger.get("reason_diagnostics", {}),
		}))
		main.queue_free()
		await process_frame
		return result
	coordinator.request_table_presentation_refresh(
		&"full",
		&"cold_restore_qualification_checkpoint_sync"
	)
	await process_frame
	await process_frame
	var checkpoint := _checkpoint_summary(context)
	result.merge({
		"human_action_count": int(legal.get("human_action_count", 0)) + (1 if bool(human.get("accepted", false)) else 0) + (1 if bool(trigger.get("accepted", false)) else 0),
		"commodity_action_count": int(legal.get("commodity_action_count", 0)),
		"normal_card_purchase_count": int(legal.get("normal_card_purchase_count", 0)),
		"facility_action_count": int(legal.get("facility_action_count", 0)),
		"sale_receipt_count": int((legal.get("sales", {}) as Dictionary).get("sale_receipt_count", 0)) \
			+ int(queue_capability.get("sale_receipt_count", 0)),
		"ai_action_count": ai_actions,
		"ai_state_fingerprint_changed": not initial_ai_digest.is_empty() and final_ai_digest != initial_ai_digest,
		"queue_trigger_actor": str(trigger.get("actor", "none")),
		"queue_trigger_semantic_action_id": str(trigger.get("semantic_action_id", "")),
		"queue_trigger_card_semantic_id": str(trigger.get("card_semantic_id", "")),
		"queue_trigger_target_fingerprint": str(trigger.get("target_fingerprint", "")),
		"queue_count": int(trigger.get("queue_count", 0)),
		"queue_revision": int(trigger.get("queue_revision", 0)),
		"offer_audit": _qualification_offer_audit(legal, trigger),
		"card_resolution_advance_after_trigger": int(trigger.get("card_resolution_advance_after_trigger", -1)),
		"world_advance_after_trigger": int(trigger.get("world_advance_after_trigger", -1)),
		"rng_draw_after_trigger": int(trigger.get("rng_draw_after_trigger", -1)),
		"normal_card_count": int(checkpoint.get("normal_card_count", 0)),
		"commodity_card_count": int(checkpoint.get("commodity_card_count", 0)),
		"commodity_claim_count": int(checkpoint.get("commodity_claim_count", 0)),
		"facility_count": int(checkpoint.get("facility_count", 0)),
		"route_count": int(checkpoint.get("route_count", 0)),
		"weather_region_count": int(checkpoint.get("weather_region_count", 0)),
		"ai_nondefault_state_count": int(checkpoint.get("ai_nondefault_state_count", 0)),
		"production_surface_ready": bool(checkpoint.get("production_surface_ready", false)),
	}, true)
	var success := bool(human.get("accepted", false)) \
		and int(result.get("normal_card_purchase_count", 0)) >= 1 \
		and int(result.get("facility_action_count", 0)) >= 1 \
		and int(result.get("commodity_action_count", 0)) >= 1 \
		and int(result.get("sale_receipt_count", 0)) >= 1 \
		and ai_actions >= 1 and bool(result.get("ai_state_fingerprint_changed", false)) \
		and bool(trigger.get("accepted", false)) and bool(trigger.get("queued", false)) \
		and int(result.get("queue_count", 0)) >= 1 \
		and int(result.get("card_resolution_advance_after_trigger", -1)) == 0 \
		and int(result.get("world_advance_after_trigger", -1)) == 0 \
		and int(result.get("rng_draw_after_trigger", -1)) == 0 \
		and _checkpoint_ready(checkpoint)
	result["success"] = success
	result["failure_code"] = "" if success else str(trigger.get("reason_code", "qualification_incomplete"))
	if not success:
		print("COLD_RESTORE_QUALIFICATION_DIAGNOSTIC|" + JSON.stringify({
			"run_id": run_id,
			"failure_code": result["failure_code"],
			"trigger": trigger.get("reason_diagnostics", {}),
			"checkpoint": checkpoint,
		}))
	main.queue_free()
	await process_frame
	return result


func _qualification_offer_audit(legal: Dictionary, trigger: Dictionary) -> Dictionary:
	var legal_offers: Array[Dictionary] = []
	var queue_capable_offers: Array[Dictionary] = []
	var rejected_offers: Array[Dictionary] = []
	var reason_diagnostics: Dictionary = trigger.get("reason_diagnostics", {}) \
		if trigger.get("reason_diagnostics", {}) is Dictionary else {}
	if not trigger.is_empty():
		var entry := {
			"actor": str(trigger.get("actor", "none")),
			"source_revision": maxi(0, int(reason_diagnostics.get("dock_source_revision", 0))),
			"semantic_action_id": str(trigger.get("semantic_action_id", "")),
			"card_semantic_id": str(trigger.get("card_semantic_id", "")),
			"offer_fingerprint": str(trigger.get("offer_fingerprint", "")),
			"target_fingerprint": str(trigger.get("target_fingerprint", "")),
			"reason_code": str(trigger.get("reason_code", "")),
		}
		if bool(trigger.get("accepted", false)):
			legal_offers.append(entry.duplicate(true))
		if bool(trigger.get("queued", false)):
			queue_capable_offers.append(entry.duplicate(true))
		if not bool(trigger.get("accepted", false)) or not bool(trigger.get("queued", false)):
			rejected_offers.append(entry.duplicate(true))
	if not bool(legal.get("ready", false)):
		var diagnostics: Dictionary = legal.get("diagnostics", {}) \
			if legal.get("diagnostics", {}) is Dictionary else {}
		var plans: Array = diagnostics.get("queue_plans", []) \
			if diagnostics.get("queue_plans", []) is Array else []
		for plan_variant in plans:
			if not (plan_variant is Dictionary):
				continue
			var plan := plan_variant as Dictionary
			rejected_offers.append({
				"actor": "local",
				"source_revision": 0,
				"semantic_action_id": GAME_ACTION_INTENT.ACTION_CARD_PLAY,
				"card_semantic_id": str(plan.get("queue_card_id", "")),
				"offer_fingerprint": "",
				"target_fingerprint": SEMANTIC_WIRE.fingerprint(plan),
				"reason_code": str(legal.get("reason_code", "legal_checkpoint_failed")),
			})
	return {
		"legal_offers": legal_offers,
		"queue_capable_offers": queue_capable_offers,
		"rejected_offers": rejected_offers,
	}


static func _product_blocker(success: bool, queue_count: int, reason_code: String) -> String:
	if success:
		return ""
	if queue_count <= 0 and reason_code in [
		"legal_factory_market_queue_target_missing",
		"legal_queue_offer_missing",
		"queue_capability_not_reached",
		"ai_legal_queue_offer_missing",
	]:
		return "BLOCKED_BY_NO_LEGAL_QUEUE_ACCEPTANCE_SCENARIO"
	var normalized := reason_code.to_upper()
	for character in ["-", ".", ":", "/", " "]:
		normalized = normalized.replace(character, "_")
	return "BLOCKED_BY_%s" % (normalized if not normalized.is_empty() else "PRODUCT_QUALIFICATION_INCOMPLETE")


static func _evidence_exit_code(write_result: Dictionary) -> int:
	var reason_code := str(write_result.get("reason_code", ""))
	if reason_code.contains("collision"):
		return 17
	if reason_code.contains("readback"):
		return 14
	return 13


func _run_producer(context: Dictionary, options: Dictionary, base: Dictionary) -> Dictionary:
	var save_path := str(options.get("save_path", ""))
	if FileAccess.file_exists(save_path):
		return _fail(base, "producer_slot_must_start_empty")
	var started := _start_default_session(context, str(options.get("run_id", "")))
	if not bool(started.get("applied", false)):
		return _fail(base, str(started.get("reason_code", "session_start_failed")))
	var initial_ai_digest := _ai_state_digest(context)
	var human := _submit_human_selection(context, "producer-human", 1)
	var legal_checkpoint: Dictionary = await _prepare_facility_queue_checkpoint(context)
	if not bool(legal_checkpoint.get("ready", false)):
		return _fail(base, str(legal_checkpoint.get("reason_code", "legal_checkpoint_failed")))
	var initial_sales: Dictionary = legal_checkpoint.get("sales", {}) \
		if legal_checkpoint.get("sales", {}) is Dictionary else {}
	(context.get("coordinator") as GameRuntimeCoordinator).resume_session()
	var ai_actions := _tick_ai_until_action(context, 120)
	var final_ai_digest := _ai_state_digest(context)
	var drain := _drain_pending_queue(context, 120)
	if not bool(drain.get("drained", false)):
		return _fail(base, "pre_trigger_queue_not_empty")
	var queue_capability := {
		"ready": true,
		"reason_code": "facility_queue_capability_ready",
		"sale_receipt_count": 0,
	}
	(context.get("coordinator") as GameRuntimeCoordinator).resume_session()
	(context.get("coordinator") as GameRuntimeCoordinator).request_table_presentation_refresh(&"full", &"cold_restore_queue_offer_sync")
	await process_frame
	await process_frame
	var queue_submission := _submit_first_formal_queue_offer(
		context,
		str(legal_checkpoint.get("queue_facility_card_id", "")),
		str(legal_checkpoint.get("queue_facility_region_id", ""))
	)
	if not bool(queue_submission.get("accepted", false)) \
			or not bool(queue_submission.get("queued", false)):
		return _fail(base, "legal_queue_submission_failed")
	var queue_target_resolution_id := int(queue_submission.get("queue_resolution_id", -1))
	var queue_target_fingerprint := str(queue_submission.get("stable_target_envelope_fingerprint", ""))
	base["queue_trigger_resolution_id"] = maxi(0, queue_target_resolution_id)
	base["queue_trigger_stable_target_fingerprint"] = queue_target_fingerprint
	base["_attestation_queue_revision"] = maxi(0, int(queue_submission.get("queue_revision", 0)))
	base["_attestation_queue_trigger_actor"] = str(queue_submission.get("actor", "none"))
	base["_attestation_queue_trigger_semantic_action_id"] = str(queue_submission.get("semantic_action_id", ""))
	base["_attestation_queue_trigger_card_semantic_id"] = str(queue_submission.get("card_semantic_id", ""))
	var queue_target_before := _queue_target_observation(context, queue_target_resolution_id)
	if _queue_entry_count(context) != 1 \
			or not bool(queue_target_before.get("valid", false)) \
			or int(queue_target_before.get("pending_count", -1)) != 1 \
			or int(queue_target_before.get("completed_count", -1)) != 0 \
			or int(queue_target_before.get("history_count", -1)) != 0 \
			or str(queue_target_before.get("stable_target_fingerprint", "")) != queue_target_fingerprint:
		return _fail(base, "producer_queue_target_before_save_invalid")
	var checkpoint := _checkpoint_summary(context)
	var save := _save_via_player_flow(context, save_path, false)
	if not bool(save.get("ok", false)):
		return _fail(base, str(save.get("reason_code", "producer_save_failed")))
	var queue_target_after := _queue_target_observation(context, queue_target_resolution_id)
	var queue_target_evidence := _queue_target_manifest_evidence(
		queue_target_resolution_id,
		queue_target_fingerprint,
		queue_target_before,
		queue_target_after
	)
	if _queue_entry_count(context) != 1 or not _queue_target_role_evidence_valid(
		"producer",
		queue_target_fingerprint,
		queue_target_before,
		queue_target_after,
		queue_target_evidence
	):
		base.merge(queue_target_evidence, true)
		return _fail(base, "producer_queue_target_save_boundary_invalid")
	base.merge({
		"slot_state": "ready",
		"source_sections_digest": "",
		"saved_sections_digest": str(save.get("sections_digest", "")),
		"restored_sections_digest": "",
		"source_write_id": "",
		"write_id": str(save.get("write_id", "")),
		"source_write_fingerprint": "",
		"section_count": int(save.get("section_count", 0)),
		"preflight_count": int(save.get("preflight_count", 0)),
		"save_capture_world_delta": int(save.get("save_capture_world_delta", -1)),
		"save_capture_rng_delta": int(save.get("save_capture_rng_delta", -1)),
		"save_capture_log_delta": int(save.get("save_capture_log_delta", -1)),
		"human_action_count": int(legal_checkpoint.get("human_action_count", 0)) + (1 if bool(human.get("accepted", false)) else 0) + 1,
		"commodity_action_count": int(legal_checkpoint.get("commodity_action_count", 0)),
		"ai_action_count": ai_actions,
		"sale_receipt_count": int(initial_sales.get("sale_receipt_count", 0)) \
			+ int(queue_capability.get("sale_receipt_count", 0)),
		"normal_card_count": int(checkpoint.get("normal_card_count", 0)),
		"commodity_card_count": int(checkpoint.get("commodity_card_count", 0)),
		"commodity_claim_count": int(checkpoint.get("commodity_claim_count", 0)),
		"facility_count": int(checkpoint.get("facility_count", 0)),
		"route_count": int(checkpoint.get("route_count", 0)),
		"military_unit_count": int(checkpoint.get("military_unit_count", 0)),
		"queue_entry_count": int(checkpoint.get("queue_entry_count", 0)),
		"weather_region_count": int(checkpoint.get("weather_region_count", 0)),
		"ai_nondefault_state_count": int(checkpoint.get("ai_nondefault_state_count", 0)),
		"victory_unresolved_before_save": bool(checkpoint.get("victory_unresolved", false)),
		"production_surface_ready": bool(checkpoint.get("production_surface_ready", false)),
		"generation": 1,
		"backup_created": bool(save.get("backup_created", false)),
		"write_fingerprint": str(save.get("write_fingerprint", "")),
		"rng_draw_count_before": int(save.get("rng_draw_count", 0)),
		"rng_draw_count_after": int(save.get("rng_draw_count", 0)),
		"success": bool(human.get("accepted", false)) and ai_actions > 0 \
			and not initial_ai_digest.is_empty() and final_ai_digest != initial_ai_digest \
			and int(initial_sales.get("sale_receipt_count", 0)) \
				+ int(queue_capability.get("sale_receipt_count", 0)) > 0 and _checkpoint_ready(checkpoint),
		"failure_code": "" if bool(human.get("accepted", false)) and ai_actions > 0 \
			and not initial_ai_digest.is_empty() and final_ai_digest != initial_ai_digest \
			and int(initial_sales.get("sale_receipt_count", 0)) \
				+ int(queue_capability.get("sale_receipt_count", 0)) > 0 \
			and _checkpoint_ready(checkpoint) else "producer_checkpoint_incomplete",
	}, true)
	base.merge(queue_target_evidence, true)
	return base


func _run_consumer(context: Dictionary, options: Dictionary, base: Dictionary) -> Dictionary:
	var save_path := str(options.get("save_path", ""))
	var queue_target_resolution_id := int(options.get("expected_queue_resolution_id", 0))
	var queue_target_fingerprint := str(options.get("expected_queue_stable_target_fingerprint", ""))
	base["queue_trigger_resolution_id"] = queue_target_resolution_id
	base["queue_trigger_stable_target_fingerprint"] = queue_target_fingerprint
	var before_observation := _safety_observation(context)
	var read := _read_slot(context, save_path)
	if not bool(read.get("ok", false)):
		return _fail(base, str(read.get("reason_code", "consumer_read_failed")))
	var source_digest := str(read.get("sections_digest", ""))
	var load := _resume_via_player_flow(context, save_path)
	if not bool(load.get("ok", false)):
		return _fail(base, str(load.get("reason_code", "consumer_restore_failed")))
	var after_observation := _safety_observation(context)
	var recapture := _capture_sections(context, "consumer-recapture")
	if not bool(recapture.get("ok", false)) or str(recapture.get("sections_digest", "")) != source_digest:
		return _fail(base, "consumer_exact_recapture_mismatch")
	# The restored target is inspected and drained synchronously before any
	# post-restore human, AI, economy, render-frame, or RuntimeLoop continuation.
	var queue_target_before := _queue_target_observation(context, queue_target_resolution_id)
	var queue_target_failure_evidence := _queue_target_manifest_evidence(
		queue_target_resolution_id,
		queue_target_fingerprint,
		queue_target_before,
		queue_target_before
	)
	if not bool(queue_target_before.get("valid", false)) \
			or int(queue_target_before.get("pending_count", -1)) != 1 \
			or int(queue_target_before.get("completed_count", -1)) != 0 \
			or int(queue_target_before.get("history_count", -1)) != 0 \
			or str(queue_target_before.get("stable_target_fingerprint", "")) != queue_target_fingerprint:
		base.merge(queue_target_failure_evidence, true)
		return _fail(base, "consumer_restored_queue_target_identity_invalid")
	var target_drain := _drain_target_resolution(context, queue_target_resolution_id, 120)
	var queue_target_after: Dictionary = target_drain.get("observation", {}) \
		if target_drain.get("observation", {}) is Dictionary else {}
	var queue_target_evidence := _queue_target_manifest_evidence(
		queue_target_resolution_id,
		queue_target_fingerprint,
		queue_target_before,
		queue_target_after
	)
	if not bool(target_drain.get("drained", false)) or not _queue_target_role_evidence_valid(
		"consumer",
		queue_target_fingerprint,
		queue_target_before,
		queue_target_after,
		queue_target_evidence
	):
		base.merge(queue_target_evidence, true)
		return _fail(base, "consumer_queue_target_exact_once_invalid")
	(context.get("coordinator") as GameRuntimeCoordinator).resume_session()
	var human := _submit_human_selection(context, "consumer-human", 2)
	var commodity_action := _claim_first_visible_commodity(context, maxi(1, Time.get_ticks_msec()))
	var ai_actions := _tick_ai_until_action(context, 120)
	var post_sales := _advance_sale(context, 60.0)
	if not bool(human.get("accepted", false)) or ai_actions <= 0 \
			or not bool(commodity_action.get("success", false)) \
			or int(post_sales.get("sale_receipt_count", 0)) <= 0:
		return _fail(base, "post_restore_continuation_failed")
	var sale_binding_capture := TERMINAL_EVIDENCE.capture_public_sale_binding(context)
	if not bool(sale_binding_capture.get("accepted", false)):
		return _fail(
			base,
			str(sale_binding_capture.get(
				"reason_code",
				"generation_two_public_sale_binding_capture_failed"
			))
		)
	var checkpoint := _checkpoint_summary(context)
	var generation_two := _save_via_player_flow(context, save_path, true)
	if not bool(generation_two.get("ok", false)):
		return _fail(base, str(generation_two.get("reason_code", "generation_two_save_failed")))
	var terminal_context := context.duplicate()
	var generation_two_sale_binding: Dictionary = sale_binding_capture.get("binding", {}) \
		if sale_binding_capture.get("binding", {}) is Dictionary else {}
	terminal_context["generation_two_sale_binding"] = generation_two_sale_binding.duplicate(true)
	var terminal := await _finish_to_settlement(terminal_context)
	if not bool(terminal.get("settled", false)):
		return _fail(
			base,
			str(terminal.get("failure_code", "post_restore_settlement_failed"))
		)
	var quiet: Dictionary = load.get("quiet_deltas", {}) if load.get("quiet_deltas", {}) is Dictionary else {}
	base.merge({
		"slot_state": "restored",
		"source_sections_digest": source_digest,
		"saved_sections_digest": str(generation_two.get("sections_digest", "")),
		"restored_sections_digest": str(recapture.get("sections_digest", "")),
		"source_write_id": str(read.get("write_id", "")),
		"write_id": str(generation_two.get("write_id", "")),
		"source_write_fingerprint": str(read.get("write_fingerprint", "")),
		"section_count": int(recapture.get("section_count", 0)),
		"preflight_count": int(load.get("preflight_count", 0)),
		"owner_apply_count": int(load.get("apply_count", 0)),
		"registry_apply_count": int(load.get("registry_apply_count", 0)),
		"save_capture_world_delta": int(generation_two.get("save_capture_world_delta", -1)),
		"save_capture_rng_delta": int(generation_two.get("save_capture_rng_delta", -1)),
		"save_capture_log_delta": int(generation_two.get("save_capture_log_delta", -1)),
		"rng_draw_count_before": int(before_observation.get("rng_draw_invocation_count", 0)),
		"rng_draw_count_after": int(after_observation.get("rng_draw_invocation_count", 0)),
		"restore_rng_draw_delta": int(quiet.get("rng_draw_invocation_count", -1)),
		"restore_world_time_delta": int(quiet.get("world_clock_advance_count", -1)),
		"restore_public_log_delta": int(quiet.get("public_log_entry_count", -1)),
		"restore_sale_receipt_delta": int(quiet.get("sale_receipt_emission_count", -1)),
		"restore_economic_reward_delta": int(quiet.get("economic_reward_count", -1)),
		"restore_ai_action_delta": int(quiet.get("ai_action_submission_count", -1)),
		"restore_player_action_delta": int(quiet.get("human_action_submission_count", -1)),
		"restore_notification_delta": int(quiet.get("notification_count", -1)),
		"human_action_count": 1,
		"commodity_action_count": 1 if bool(commodity_action.get("success", false)) else 0,
		"ai_action_count": ai_actions,
		"sale_receipt_count": int(post_sales.get("sale_receipt_count", 0)),
		"normal_card_count": int(checkpoint.get("normal_card_count", 0)),
		"commodity_card_count": int(checkpoint.get("commodity_card_count", 0)),
		"commodity_claim_count": int(checkpoint.get("commodity_claim_count", 0)),
		"facility_count": int(checkpoint.get("facility_count", 0)),
		"route_count": int(checkpoint.get("route_count", 0)),
		"military_unit_count": int(checkpoint.get("military_unit_count", 0)),
		"queue_entry_count": int(checkpoint.get("queue_entry_count", 0)),
		"weather_region_count": int(checkpoint.get("weather_region_count", 0)),
		"ai_nondefault_state_count": int(checkpoint.get("ai_nondefault_state_count", 0)),
		"victory_unresolved_before_save": true,
		"production_surface_ready": bool(checkpoint.get("production_surface_ready", false)),
		"victory_state_sequence": terminal.get("victory_state_sequence", []),
		"final_settlement_count": int(terminal.get("settlement_count", 0)),
		"final_settlement_presentation_count": int(terminal.get("presentation_count", 0)),
		"final_settlement_public_log_count": int(terminal.get("public_log_count", 0)),
		"terminal_quiescent_frames": int(terminal.get("quiet_frames", 0)),
		"terminal_world_delta": int(terminal.get("world_delta", 0)),
		"terminal_rng_draw_delta": int(terminal.get("rng_delta", 0)),
		"generation": 2,
		"backup_created": bool(generation_two.get("backup_created", false)),
		"write_fingerprint": str(generation_two.get("write_fingerprint", "")),
		"success": true,
		"failure_code": "",
	}, true)
	base.merge(queue_target_evidence, true)
	return base


func _run_validator(context: Dictionary, options: Dictionary, base: Dictionary) -> Dictionary:
	var save_path := str(options.get("save_path", ""))
	var queue_target_resolution_id := int(options.get("expected_queue_resolution_id", 0))
	var queue_target_fingerprint := str(options.get("expected_queue_stable_target_fingerprint", ""))
	base["queue_trigger_resolution_id"] = queue_target_resolution_id
	base["queue_trigger_stable_target_fingerprint"] = queue_target_fingerprint
	var before_observation := _safety_observation(context)
	var read := _read_slot(context, save_path)
	if not bool(read.get("ok", false)):
		return _fail(base, str(read.get("reason_code", "validator_read_failed")))
	var source_digest := str(read.get("sections_digest", ""))
	var load := _resume_via_player_flow(context, save_path)
	var after_observation := _safety_observation(context)
	var recapture := _capture_sections(context, "validator-recapture")
	var queue_target_before := _queue_target_observation(context, queue_target_resolution_id)
	# No continuation is permitted in Process C.  The second observation proves
	# restore itself did not replay the completed Generation-2 resolution.
	var queue_target_after := _queue_target_observation(context, queue_target_resolution_id)
	var queue_target_evidence := _queue_target_manifest_evidence(
		queue_target_resolution_id,
		queue_target_fingerprint,
		queue_target_before,
		queue_target_after
	)
	var queue_target_exact := _queue_target_role_evidence_valid(
		"validator",
		queue_target_fingerprint,
		queue_target_before,
		queue_target_after,
		queue_target_evidence
	)
	var exact := bool(load.get("ok", false)) and bool(recapture.get("ok", false)) \
		and str(recapture.get("sections_digest", "")) == source_digest and queue_target_exact
	var quiet: Dictionary = load.get("quiet_deltas", {}) if load.get("quiet_deltas", {}) is Dictionary else {}
	base.merge({
		"slot_state": "validated" if exact else "failed",
		"source_sections_digest": source_digest,
		"saved_sections_digest": "",
		"restored_sections_digest": str(recapture.get("sections_digest", "")),
		"source_write_id": str(read.get("write_id", "")),
		"write_id": "",
		"source_write_fingerprint": str(read.get("write_fingerprint", "")),
		"write_fingerprint": "",
		"section_count": int(recapture.get("section_count", 0)),
		"preflight_count": int(load.get("preflight_count", 0)),
		"owner_apply_count": int(load.get("apply_count", 0)),
		"registry_apply_count": int(load.get("registry_apply_count", 0)),
		"rng_draw_count_before": int(before_observation.get("rng_draw_invocation_count", 0)),
		"rng_draw_count_after": int(after_observation.get("rng_draw_invocation_count", 0)),
		"restore_rng_draw_delta": int(quiet.get("rng_draw_invocation_count", -1)),
		"restore_world_time_delta": int(quiet.get("world_clock_advance_count", -1)),
		"restore_public_log_delta": int(quiet.get("public_log_entry_count", -1)),
		"restore_sale_receipt_delta": int(quiet.get("sale_receipt_emission_count", -1)),
		"restore_economic_reward_delta": int(quiet.get("economic_reward_count", -1)),
		"restore_ai_action_delta": int(quiet.get("ai_action_submission_count", -1)),
		"restore_player_action_delta": int(quiet.get("human_action_submission_count", -1)),
		"restore_notification_delta": int(quiet.get("notification_count", -1)),
		"generation": 2,
		"success": exact,
		"failure_code": "" if exact else (
			"validator_queue_target_lineage_invalid" if not queue_target_exact \
			else "validator_exact_recapture_mismatch"
		),
	}, true)
	base.merge(queue_target_evidence, true)
	return base


func _runtime_context(main: Node) -> Dictionary:
	var services := main.get_node_or_null("RuntimeServices")
	var coordinator := services.get_node_or_null("RuntimeControllerHost/GameRuntimeCoordinator") if services != null else null
	var session := coordinator.get_node_or_null("GameSessionRuntimeController") if coordinator != null else null
	var registry := session.get_node_or_null("V06SaveOwnerRegistry") if session != null else null
	var save := session.get_node_or_null("GameSaveRuntimeCoordinator") if session != null else null
	var handshake := save.get_node_or_null("RulesetSaveHandshakeService") if save != null else null
	var flow := services.get_node_or_null("SaveResumeApplicationFlowController") if services != null else null
	var barrier := coordinator.get_node_or_null("SaveRestoreRuntimeBarrier") if coordinator != null else null
	return {
		"ready": services != null and coordinator != null and session != null and registry != null and save != null and handshake != null and flow != null and barrier != null,
		"main": main,
		"services": services,
		"coordinator": coordinator,
		"session": session,
		"registry": registry,
		"save": save,
		"handshake": handshake,
		"flow": flow,
		"barrier": barrier,
	}


func _start_default_session(context: Dictionary, run_id: String) -> Dictionary:
	var services: Node = context.get("services")
	var draft := services.get_node_or_null("NewGameSetupDraftService") as NewGameSetupDraftService
	var transaction := services.get_node_or_null("SessionStartTransactionCoordinator") as SessionStartTransactionCoordinator
	var session := context.get("session") as GameSessionRuntimeController
	var coordinator := context.get("coordinator") as GameRuntimeCoordinator
	var runtime_rng := coordinator.run_rng_service() if coordinator != null else null
	if draft == null or transaction == null or session == null or runtime_rng == null:
		return {"applied": false, "reason_code": "session_start_dependency_missing"}
	draft.reset_to_defaults()
	# Match the production FullRun harness's lawful fixed-seed session-start
	# boundary.  The default setup (including challenge depth) remains unchanged.
	runtime_rng.set_seed(ACCEPTANCE_SEED)
	var setup := draft.draft_snapshot()
	var challenge_depth := int(setup.get("challenge_depth", 0))
	if challenge_depth != ACCEPTANCE_CHALLENGE_DEPTH:
		return {
			"applied": false,
			"reason_code": "acceptance_challenge_depth_mismatch",
			"challenge_depth": challenge_depth,
			"expected_challenge_depth": ACCEPTANCE_CHALLENGE_DEPTH,
			"seed": ACCEPTANCE_SEED,
		}
	var request := SessionStartRequest.create(
		"cold-restore-%s-producer" % run_id,
		setup,
		session.session_start_revision(),
		"quality_driver"
	)
	var receipt := transaction.start_session(request)
	var summary := session.session_summary()
	var session_seed := int(summary.get("seed", 0))
	return {
		"applied": receipt != null and receipt.applied,
		"reason_code": receipt.reason_code if receipt != null else "session_start_receipt_missing",
		"challenge_depth": challenge_depth,
		"seed": ACCEPTANCE_SEED,
		"session_seed": session_seed,
		"scenario_fingerprint": SEMANTIC_WIRE.fingerprint({
			"challenge_depth": challenge_depth,
			"run_seed": ACCEPTANCE_SEED,
			# The derived session seed may be an Int64 outside JSON's exact
			# integer range; represent it textually in this QA-only identity.
			"session_seed": str(session_seed),
			"player_count": int(setup.get("player_count", 0)),
			"ai_player_count": int(setup.get("ai_player_count", 0)),
		}),
	}


func _capture_sections(context: Dictionary, suffix: String) -> Dictionary:
	var registry: Node = context.get("registry")
	var handshake: Node = context.get("handshake")
	var token := "%s-%d-%d" % [suffix, OS.get_process_id(), Time.get_ticks_usec()]
	var capture: Dictionary = registry.call("capture_resume_envelope", {
		"envelope_id": token,
		"write_id": "%s-write" % token,
	})
	var envelope: Dictionary = capture.get("envelope", {}) if capture.get("envelope") is Dictionary else {}
	var sections: Dictionary = envelope.get("sections", {}) if envelope.get("sections") is Dictionary else {}
	var canonical := str(handshake.call("canonical_json", sections)) if handshake != null else ""
	return {
		"ok": bool(capture.get("ok", false)) and sections.size() == 19 and not canonical.is_empty(),
		"reason_code": str(capture.get("reason_code", "capture_failed")),
		"envelope": envelope,
		"sections_digest": canonical.sha256_text() if not canonical.is_empty() else "",
		"section_count": sections.size(),
	}


func _save_via_player_flow(context: Dictionary, save_path: String, destructive_confirmed: bool) -> Dictionary:
	if save_path != SaveSlotPolicyV06.PRODUCTION_PATH:
		return {"ok": false, "reason_code": "production_slot_path_required"}
	var flow := context.get("flow") as SaveResumeApplicationFlowController
	if flow == null:
		return {"ok": false, "reason_code": "save_resume_flow_missing"}
	var before_observation := _safety_observation(context)
	var before_world := _world_digest(context)
	var receipt := flow.request_save_game(&"pause_menu", destructive_confirmed)
	var after_observation := _safety_observation(context)
	var after_world := _world_digest(context)
	if receipt == null or not receipt.accepted or not receipt.applied:
		var save_debug: Dictionary = (context.get("save") as Node).call("debug_snapshot")
		var internal_reason := str(save_debug.get("last_readback_validation_reason", ""))
		var mismatch_sections: Array = save_debug.get("last_readback_mismatch_sections", []) if save_debug.get("last_readback_mismatch_sections", []) is Array else []
		if not bool(save_debug.get("last_readback_fingerprint_match", true)):
			var first_mismatch: Dictionary = save_debug.get("last_readback_first_mismatch", {}) if save_debug.get("last_readback_first_mismatch", {}) is Dictionary else {}
			internal_reason = "readback:%s:%s:%s>%s:%s>%s" % [
				",".join(mismatch_sections),
				str(first_mismatch.get("path", "")).trim_prefix("root.sections."),
				str(first_mismatch.get("left_type", "")),
				str(first_mismatch.get("right_type", "")),
				str(first_mismatch.get("left_scalar", "")),
				str(first_mismatch.get("right_scalar", "")),
			]
			internal_reason = internal_reason.substr(0, 120)
		return {
			"ok": false,
			"reason_code": internal_reason if not internal_reason.is_empty() and internal_reason != "ok" else (receipt.reason_code if receipt != null else "save_receipt_missing"),
		}
	var read := _read_slot(context, save_path)
	if not bool(read.get("ok", false)):
		return read
	var registry: Node = context.get("registry")
	var envelope: Dictionary = read.get("envelope", {}) if read.get("envelope") is Dictionary else {}
	var preflight: Dictionary = registry.call("preflight_envelope", envelope)
	if not bool(preflight.get("ok", false)):
		var registry_debug: Dictionary = registry.call("debug_snapshot")
		return {
			"ok": false,
			"reason_code": "%s:%s" % [
				str(registry_debug.get("last_internal_preflight_failure_section", "preflight")),
				str(registry_debug.get("last_internal_preflight_failure_reason", preflight.get("reason_code", "preflight_failed"))),
			],
		}
	return {
		"ok": true,
		"reason_code": receipt.reason_code,
		"sections_digest": str(read.get("sections_digest", "")),
		"section_count": int(read.get("section_count", 0)),
		"preflight_count": int(preflight.get("preflight_count", 0)),
		"write_id": str(read.get("write_id", "")),
		"write_fingerprint": str(read.get("write_fingerprint", "")),
		"backup_created": bool(read.get("backup_available", false)),
		"save_capture_world_delta": 0 if before_world == after_world else 1,
		"save_capture_rng_delta": _delta(before_observation, after_observation, "rng_draw_invocation_count"),
		"save_capture_log_delta": _delta(before_observation, after_observation, "public_log_entry_count"),
		"rng_draw_count": int(after_observation.get("rng_draw_invocation_count", 0)),
	}


func _read_slot(context: Dictionary, save_path: String) -> Dictionary:
	var save: Node = context.get("save")
	var handshake: Node = context.get("handshake")
	var read: Dictionary = save.call("read_and_validate", save_path)
	var envelope: Dictionary = read.get("envelope", {}) if read.get("envelope") is Dictionary else {}
	var sections: Dictionary = envelope.get("sections", {}) if envelope.get("sections") is Dictionary else {}
	var canonical := str(handshake.call("canonical_json", sections)) if handshake != null else ""
	return {
		"ok": bool(read.get("ok", false)) and sections.size() == 19 and not canonical.is_empty(),
		"reason_code": str(read.get("reason_code", "read_failed")),
		"envelope": envelope,
		"sections_digest": canonical.sha256_text() if not canonical.is_empty() else "",
		"section_count": sections.size(),
		"write_id": str(read.get("write_id", envelope.get("write_id", ""))),
		"write_fingerprint": str(read.get("fingerprint", "")),
		"backup_available": _backup_available(save_path),
	}


func _resume_via_player_flow(context: Dictionary, save_path: String) -> Dictionary:
	if save_path != SaveSlotPolicyV06.PRODUCTION_PATH:
		return {"ok": false, "reason_code": "production_slot_path_required"}
	var flow := context.get("flow") as SaveResumeApplicationFlowController
	var registry := context.get("registry") as Node
	var barrier := context.get("barrier") as SaveRestoreRuntimeBarrier
	if flow == null or registry == null or barrier == null:
		return {"ok": false, "reason_code": "resume_flow_dependency_missing"}
	var inspection := flow.inspect_slot(&"root_menu")
	if inspection == null or not inspection.accepted or not inspection.can_resume:
		return {"ok": false, "reason_code": inspection.reason_code if inspection != null else "slot_inspection_failed"}
	var debug_before: Dictionary = registry.call("debug_snapshot")
	var receipt := flow.request_resume_game(&"root_menu", false)
	var debug_after: Dictionary = registry.call("debug_snapshot")
	var barrier_debug := barrier.debug_snapshot()
	var quiet: Dictionary = barrier_debug.get("last_quiet_deltas", {}) if barrier_debug.get("last_quiet_deltas", {}) is Dictionary else {}
	var ok := receipt != null and receipt.accepted and receipt.applied
	return {
		"ok": ok,
		"reason_code": receipt.reason_code if receipt != null else "resume_receipt_missing",
		"preflight_count": 19 if ok else 0,
		"apply_count": int(debug_after.get("last_owner_apply_count", 0)),
		"registry_apply_count": int(debug_after.get("restore_commit_count", 0)) - int(debug_before.get("restore_commit_count", 0)),
		"post_restore_rebind_count": int(debug_after.get("post_restore_rebind_count", 0)) - int(debug_before.get("post_restore_rebind_count", 0)),
		"partial_restore_state_count": int(debug_after.get("partial_restore_state_count", -1)),
		"quiet_deltas": quiet,
	}


func _backup_available(save_path: String) -> bool:
	var directory := DirAccess.open(save_path.get_base_dir())
	if directory == null:
		return false
	for file_name in directory.get_files():
		if str(file_name).begins_with("%s.backup-" % save_path.get_file()):
			return true
	return false


func _submit_human_selection(context: Dictionary, request_suffix: String, preferred_district: int) -> Dictionary:
	var coordinator: GameRuntimeCoordinator = context.get("coordinator")
	var session: GameSessionRuntimeController = context.get("session")
	var world := coordinator.world_session_state()
	var port := coordinator.get_node_or_null("TableSelectionIntentPort") as TableSelectionIntentPort
	var selection := coordinator.table_selection_state()
	var authorization := coordinator.gameplay_actor_authorization_context(&"qa_driver")
	if port == null or selection == null or world == null or world.districts.is_empty():
		return {"accepted": false, "reason_code": "selection_dependency_missing"}
	var target := clampi(preferred_district, 0, world.districts.size() - 1)
	if target == selection.selected_district and world.districts.size() > 1:
		target = (target + 1) % world.districts.size()
	var intent := TableSelectionIntent.new()
	intent.request_id = "cold-restore:%s:%d" % [request_suffix, OS.get_process_id()]
	intent.selection_kind = TableSelectionIntent.KIND_SELECT_DISTRICT
	intent.viewer_index = 0
	intent.authorization_revision = authorization.authorization_revision
	intent.session_id = str(session.session_summary().get("session_id", ""))
	intent.session_revision = session.session_start_revision()
	intent.expected_selection_revision = int(selection.snapshot().get("revision", -1))
	intent.target_district_index = target
	intent.source_surface = &"qa_driver"
	intent.request_revision = maxi(1, Time.get_ticks_msec())
	var receipt := port.submit_intent(intent)
	return {"accepted": receipt != null and receipt.accepted and receipt.applied, "reason_code": receipt.reason_code if receipt != null else "selection_receipt_missing"}


func _select_exact_region(context: Dictionary, region_id: String, request_suffix: String) -> bool:
	var coordinator := context.get("coordinator") as GameRuntimeCoordinator
	var world := coordinator.world_session_state() if coordinator != null else null
	var selection := coordinator.table_selection_state() if coordinator != null else null
	if world == null or selection == null or region_id.is_empty():
		return false
	var district_index := -1
	for index in range(world.districts.size()):
		if world.districts[index] is Dictionary \
				and str((world.districts[index] as Dictionary).get("region_id", "")) == region_id:
			district_index = index
			break
	if district_index < 0:
		return false
	if int(selection.snapshot().get("selected_district", -1)) == district_index:
		return true
	var receipt := _submit_human_selection(context, request_suffix, district_index)
	return bool(receipt.get("accepted", false)) \
		and int(selection.snapshot().get("selected_district", -1)) == district_index


func _prepare_facility_queue_checkpoint(context: Dictionary) -> Dictionary:
	var coordinator := context.get("coordinator") as GameRuntimeCoordinator
	var main := context.get("main") as Node
	if coordinator == null or main == null:
		return {"ready": false, "reason_code": "facility_checkpoint_runtime_missing"}
	coordinator.pause_session()
	await process_frame
	var world := coordinator.world_session_state()
	var screen := main.find_child("RuntimeGameScreen", true, false) as SpaceSyndicateGameScreen
	var overlay := screen.get_node_or_null("OverlayLayer") as SpaceSyndicateOverlayLayer \
		if screen != null else null
	var popup := screen.get_region_supply_popup() as SpaceSyndicateRegionSupplyPopup \
		if screen != null else null
	var viewmodel_query := coordinator.get_node_or_null("TablePresentationViewModelQuery") \
		as TablePresentationViewModelQuery
	var query_ports := coordinator.get_node_or_null("TablePresentationQueryPorts") \
		as TablePresentationQueryPorts
	var district_port := coordinator.district_supply_action_port()
	var infrastructure := coordinator.get_node_or_null("RegionInfrastructureRuntimeController") \
		as RegionInfrastructureRuntimeController
	var flow := coordinator.commodity_flow_runtime_controller()
	var routes := coordinator.get_node_or_null("RouteNetworkRuntimeController") \
		as RouteNetworkRuntimeController
	if world == null or screen == null or overlay == null or popup == null \
			or viewmodel_query == null or query_ports == null or district_port == null \
			or infrastructure == null or flow == null or routes == null \
			or query_ports.region_infrastructure_public_query == null:
		return {"ready": false, "reason_code": "facility_checkpoint_dependency_missing"}
	var actor_binding := coordinator.actor_id_for_player_index(0)
	var actor_id := str(actor_binding.get("actor_id", ""))
	var identity := coordinator.get_node_or_null("PlayerIdentityAuthorizationBoundary") \
		as PlayerIdentityAuthorizationBoundary
	var actor_context := identity.current_actor_context(&"district_supply") if identity != null else null
	var viewer_context := query_ports.viewer_context()
	if not bool(actor_binding.get("available", false)) or actor_id.is_empty() \
			or actor_context == null or not actor_context.is_valid():
		return {"ready": false, "reason_code": "facility_checkpoint_actor_missing"}
	screen.bind_presentation_viewer(0, viewer_context.authorization_revision)
	screen.bind_gameplay_actor_authorization_context(actor_context)
	var facts_variant: Variant = query_ports.region_infrastructure_public_query.call(
		"public_commodity_region_facts"
	)
	var facts: Array = facts_variant if facts_variant is Array else []
	var facility_index := _active_rank_one_facility_card_index(coordinator)
	if facts.is_empty() or not bool(facility_index.get("valid", false)):
		return {"ready": false, "reason_code": "facility_checkpoint_catalog_or_facts_missing"}
	var selected_plan: Dictionary = {}
	var diagnostics: Array[Dictionary] = []
	for industry_id_variant in INDUSTRY_IDS:
		var industry_id := str(industry_id_variant)
		var rows := _legal_factory_and_market_targets(
			coordinator,
			query_ports,
			infrastructure,
			flow,
			routes,
			facts,
			facility_index.get("cards_by_industry", {}) as Dictionary,
			industry_id
		)
		var factory_targets: Array = rows.get("factory_targets", []) \
			if rows.get("factory_targets", []) is Array else []
		var market_targets: Array = rows.get("market_targets", []) \
			if rows.get("market_targets", []) is Array else []
		diagnostics.append({
			"industry_id": industry_id,
			"factory_target_count": factory_targets.size(),
			"market_target_count": market_targets.size(),
		})
		if selected_plan.is_empty() and factory_targets.size() >= 2:
			selected_plan = {
				"industry_id": industry_id,
				"first_card_id": str(rows.get("factory_card_id", "")),
				"queue_card_id": str(rows.get("factory_card_id", "")),
				"first_target": (factory_targets[0] as Dictionary).duplicate(true),
				"queue_target": (factory_targets[1] as Dictionary).duplicate(true),
				"product_id": str((factory_targets[0] as Dictionary).get("product_id", "")),
			}
	if selected_plan.is_empty() or str(selected_plan.get("first_card_id", "")).is_empty() \
			or str(selected_plan.get("queue_card_id", "")).is_empty() \
			or str(selected_plan.get("product_id", "")).is_empty():
		return {
			"ready": false,
			"reason_code": "facility_checkpoint_two_targets_missing",
			"diagnostics": {"targets_by_industry": diagnostics},
		}
	var claim := _claim_first_visible_commodity(context, maxi(1, Time.get_ticks_msec()))
	if not bool(claim.get("success", false)):
		return {"ready": false, "reason_code": "facility_checkpoint_commodity_claim_failed"}
	var protected_card_ids: Array = [
		str(claim.get("commodity_card_id", "")),
		str(selected_plan.get("first_card_id", "")),
		str(selected_plan.get("queue_card_id", "")),
	]
	var receipts: Array[DistrictSupplyActionReceipt] = []
	district_port.receipt_ready.connect(func(receipt: DistrictSupplyActionReceipt) -> void:
		receipts.append(receipt)
	)
	var first_purchase := await _purchase_with_legal_churn(
		coordinator,
		world,
		screen,
		overlay,
		popup,
		viewmodel_query,
		district_port,
		receipts,
		actor_id,
		str(selected_plan.get("first_card_id", "")),
		protected_card_ids
	)
	if not bool(first_purchase.get("completed", false)):
		return {
			"ready": false,
			"reason_code": "facility_checkpoint_first_purchase_failed",
			"diagnostics": {"first_purchase": first_purchase.duplicate(true)},
		}
	var first_target := selected_plan.get("first_target", {}) as Dictionary
	var first_play := await _play_facility_through_formal_submission(
		context,
		actor_id,
		str(selected_plan.get("first_card_id", "")),
		str(first_target.get("region_id", ""))
	)
	if not bool(first_play.get("success", false)):
		return {
			"ready": false,
			"reason_code": "facility_checkpoint_first_play_failed",
			"diagnostics": first_play.duplicate(true),
		}
	coordinator.resume_session()
	var sales := _advance_until_product_sale(context, str(selected_plan.get("product_id", "")))
	coordinator.pause_session()
	if int(sales.get("owned_sale_receipt_count", 0)) <= 0:
		return {
			"ready": false,
			"reason_code": str(sales.get("reason_code", "facility_checkpoint_sale_missing")),
			"diagnostics": {"sales": sales.duplicate(true)},
		}
	var queue_purchase: Dictionary = {}
	var queue_purchase_count := 0
	for funding_cycle in range(MAX_QUEUE_PURCHASE_FUNDING_CYCLES + 1):
		queue_purchase = await _purchase_with_legal_churn(
			coordinator,
			world,
			screen,
			overlay,
			popup,
			viewmodel_query,
			district_port,
			receipts,
			actor_id,
			str(selected_plan.get("queue_card_id", "")),
			protected_card_ids,
			int(first_purchase.get("source_district_index", -1)),
			true
		)
		queue_purchase_count += int(queue_purchase.get("purchase_count", 0))
		queue_purchase["purchase_count"] = queue_purchase_count
		if bool(queue_purchase.get("completed", false)):
			break
		if funding_cycle >= MAX_QUEUE_PURCHASE_FUNDING_CYCLES \
				or str(queue_purchase.get("reason_code", "")) not in [
					"legal_supply_churn_exhausted",
					"purchase_surface_unavailable",
				]:
			break
		coordinator.resume_session()
		var funding_sale := _advance_until_product_sale(
			context,
			str(selected_plan.get("product_id", "")),
			int(first_purchase.get("source_district_index", -1))
		)
		coordinator.pause_session()
		sales["advanced"] = bool(sales.get("advanced", false)) \
			or bool(funding_sale.get("advanced", false))
		sales["sale_receipt_count"] = int(sales.get("sale_receipt_count", 0)) \
			+ int(funding_sale.get("sale_receipt_count", 0))
		sales["owned_sale_receipt_count"] = int(sales.get("owned_sale_receipt_count", 0)) \
			+ int(funding_sale.get("owned_sale_receipt_count", 0))
		sales["funding_cycle_count"] = funding_cycle + 1
		if int(funding_sale.get("owned_sale_receipt_count", 0)) <= 0 \
				or not bool(funding_sale.get("market_purchasable", false)):
			queue_purchase["reason_code"] = str(funding_sale.get(
				"reason_code",
				"facility_checkpoint_funding_sale_missing"
			))
			break
	if not bool(queue_purchase.get("completed", false)):
		return {
			"ready": false,
			"reason_code": "facility_checkpoint_queue_purchase_failed",
			"diagnostics": {
				"first_purchase": first_purchase.duplicate(true),
				"queue_purchase": queue_purchase.duplicate(true),
				"sales": sales.duplicate(true),
			},
		}
	var queue_target := selected_plan.get("queue_target", {}) as Dictionary
	if not _select_exact_region(context, str(queue_target.get("region_id", "")), "facility-queue-target"):
		return {"ready": false, "reason_code": "facility_checkpoint_queue_target_selection_failed"}
	coordinator.request_table_presentation_refresh(&"full", &"facility_queue_checkpoint_ready")
	await process_frame
	await process_frame
	return {
		"ready": true,
		"reason_code": "facility_queue_checkpoint_ready",
		"actor_id": actor_id,
		"queue_facility_card_id": str(selected_plan.get("queue_card_id", "")),
		"queue_facility_region_id": str(queue_target.get("region_id", "")),
		"product_id": str(selected_plan.get("product_id", "")),
		"commodity_action_count": 1,
		"normal_card_purchase_count": int(first_purchase.get("purchase_count", 0)) \
			+ int(queue_purchase.get("purchase_count", 0)),
		"facility_action_count": 1,
		"invalid_action_count": 0,
		"direct_authority_mutation_count": 0,
		"human_action_count": int(first_purchase.get("purchase_count", 0)) \
			+ int(queue_purchase.get("purchase_count", 0)) + 1,
		"sales": sales.duplicate(true),
	}


func _prepare_generic_legal_checkpoint(context: Dictionary) -> Dictionary:
	var coordinator := context.get("coordinator") as GameRuntimeCoordinator
	var main := context.get("main") as Node
	if coordinator == null or main == null:
		return {"ready": false, "reason_code": "legal_checkpoint_runtime_missing"}
	coordinator.pause_session()
	await process_frame
	var world := coordinator.world_session_state()
	var screen := main.find_child("RuntimeGameScreen", true, false) as SpaceSyndicateGameScreen
	var overlay := screen.get_node_or_null("OverlayLayer") as SpaceSyndicateOverlayLayer if screen != null else null
	var popup := screen.get_region_supply_popup() as SpaceSyndicateRegionSupplyPopup if screen != null else null
	var viewmodel_query := coordinator.get_node_or_null("TablePresentationViewModelQuery") as TablePresentationViewModelQuery
	var query_ports := coordinator.get_node_or_null("TablePresentationQueryPorts") as TablePresentationQueryPorts
	var district_port := coordinator.district_supply_action_port()
	var sushi_service := coordinator.get_node_or_null("CommoditySushiTrackRuntimeService")
	var infrastructure := coordinator.get_node_or_null("RegionInfrastructureRuntimeController") as RegionInfrastructureRuntimeController
	var flow := coordinator.commodity_flow_runtime_controller()
	if world == null or screen == null or overlay == null or popup == null \
			or viewmodel_query == null or query_ports == null or district_port == null \
			or sushi_service == null or infrastructure == null or flow == null:
		return {"ready": false, "reason_code": "legal_checkpoint_dependency_missing"}
	var actor_binding := coordinator.actor_id_for_player_index(0)
	var actor_id := str(actor_binding.get("actor_id", ""))
	var identity := coordinator.get_node_or_null("PlayerIdentityAuthorizationBoundary") as PlayerIdentityAuthorizationBoundary
	var actor_context := identity.current_actor_context(&"district_supply") if identity != null else null
	var viewer_context := query_ports.viewer_context()
	if not bool(actor_binding.get("available", false)) or actor_id.is_empty() \
			or actor_context == null or not actor_context.is_valid():
		return {"ready": false, "reason_code": "legal_checkpoint_actor_missing"}
	screen.bind_presentation_viewer(0, viewer_context.authorization_revision)
	screen.bind_gameplay_actor_authorization_context(actor_context)
	var initial_player := coordinator.v06_card_player_snapshot(actor_id)
	var protected_card_ids := _inventory_card_ids(initial_player)
	var queue_plans := _queue_capable_card_plans(coordinator)
	if queue_plans.is_empty():
		return {"ready": false, "reason_code": "legal_queue_capability_catalog_empty"}
	var track_snapshot: CommoditySushiTrackSnapshot = sushi_service.public_snapshot(0)
	var candidate := _legal_factory_market_queue_plan(
		coordinator,
		query_ports,
		infrastructure,
		flow,
		track_snapshot,
		queue_plans
	)
	if not bool(candidate.get("ready", false)):
		return {
			"ready": false,
			"reason_code": str(candidate.get("reason_code", "legal_factory_market_queue_plan_missing")),
			"diagnostics": (candidate.get("diagnostics", {}) as Dictionary).duplicate(true) \
				if candidate.get("diagnostics", {}) is Dictionary else {},
		}
	var item := candidate.get("item") as CommoditySushiTrackItemSnapshot
	var commodity_card_id := str(item.commodity_card_id) if item != null else ""
	var asset_factory_card_id := str(candidate.get("asset_factory_card_id", ""))
	var factory_card_id := str(candidate.get("factory_card_id", ""))
	var market_card_id := str(candidate.get("market_card_id", ""))
	var queue_card_id := str(candidate.get("queue_card_id", ""))
	var asset_factory_target: Dictionary = candidate.get("asset_factory_target", {}) \
		if candidate.get("asset_factory_target", {}) is Dictionary else {}
	var factory_target: Dictionary = candidate.get("factory_target", {}) \
		if candidate.get("factory_target", {}) is Dictionary else {}
	var market_target: Dictionary = candidate.get("market_target", {}) \
		if candidate.get("market_target", {}) is Dictionary else {}
	var asset_product_id := str(candidate.get("asset_product_id", ""))
	var product_id := str(candidate.get("product_id", ""))
	if item == null or commodity_card_id.is_empty() or asset_factory_card_id.is_empty() \
			or asset_factory_target.is_empty() or asset_product_id.is_empty() \
			or factory_card_id.is_empty() \
			or market_card_id.is_empty() or queue_card_id.is_empty() \
			or factory_target.is_empty() or market_target.is_empty() or product_id.is_empty():
		return {"ready": false, "reason_code": "legal_factory_market_queue_plan_invalid"}
	var claim := _claim_track_item(sushi_service, track_snapshot, item, 1)
	if not bool(claim.get("success", false)):
		return {"ready": false, "reason_code": "legal_commodity_claim_failed"}
	for protected_id in [
		commodity_card_id,
		asset_factory_card_id,
		factory_card_id,
		market_card_id,
		queue_card_id,
	]:
		if not protected_card_ids.has(protected_id):
			protected_card_ids.append(protected_id)
	var receipts: Array[DistrictSupplyActionReceipt] = []
	district_port.receipt_ready.connect(func(receipt: DistrictSupplyActionReceipt) -> void:
		receipts.append(receipt)
	)
	var facility_specs: Array[Dictionary] = []
	var facility_spec_ids: Dictionary = {}
	for spec_variant in [
		{
			"role": "asset_factory",
			"facility_kind": "factory",
			"card_id": asset_factory_card_id,
			"target": asset_factory_target,
			"product_id": asset_product_id,
		},
		{
			"role": "queue_factory",
			"facility_kind": "factory",
			"card_id": factory_card_id,
			"target": factory_target,
			"product_id": product_id,
		},
		{
			"role": "queue_market",
			"facility_kind": "market",
			"card_id": market_card_id,
			"target": market_target,
			"product_id": product_id,
		},
	]:
		var spec := spec_variant as Dictionary
		var target := spec.get("target", {}) as Dictionary
		var spec_id := "%s|%s|%s" % [
			str(spec.get("facility_kind", "")),
			str(spec.get("card_id", "")),
			str(target.get("region_id", "")),
		]
		if facility_spec_ids.has(spec_id):
			continue
		facility_spec_ids[spec_id] = true
		facility_specs.append(spec.duplicate(true))
	var facility_purchase_count := 0
	var facility_action_count := 0
	var production_installation_ids: Array[String] = []
	for spec in facility_specs:
		var target: Dictionary = spec.get("target", {}) as Dictionary
		var purchase: Dictionary = await _purchase_with_legal_churn(
			coordinator,
			world,
			screen,
			overlay,
			popup,
			viewmodel_query,
			district_port,
			receipts,
			actor_id,
			str(spec.get("card_id", "")),
			protected_card_ids
		)
		if not bool(purchase.get("completed", false)) \
				or int(purchase.get("purchase_count", 0)) <= 0:
			return {
				"ready": false,
				"reason_code": "legal_%s_purchase_failed" % str(spec.get("role", "facility")),
				"diagnostics": {"facility_role": str(spec.get("role", ""))},
			}
		facility_purchase_count += int(purchase.get("purchase_count", 0))
		var play := await _play_facility_through_formal_submission(
			context,
			actor_id,
			str(spec.get("card_id", "")),
			str(target.get("region_id", ""))
		)
		if not bool(play.get("success", false)):
			return {
				"ready": false,
				"reason_code": "legal_%s_play_failed" % str(spec.get("role", "facility")),
				"diagnostics": {
					"facility_role": str(spec.get("role", "")),
					"public_failure_code": str((play.get("public_result", {}) as Dictionary).get("failure_code", "")),
					"receipt_reason": str((play.get("receipt", {}) as Dictionary).get("reason", "")),
				},
			}
		facility_action_count += 1
		if str(spec.get("facility_kind", "")) == "factory":
			var production := _matching_installation(
				flow,
				"production",
				str(spec.get("product_id", "")),
				str(target.get("region_id", "")),
				0
			)
			if production.is_empty():
				return {
					"ready": false,
					"reason_code": "legal_%s_production_missing" % str(spec.get("role", "factory")),
				}
			production_installation_ids.append(str(production.get("installation_id", "")))
	coordinator.resume_session()
	var sale_products: Array[String] = []
	for candidate_product_id in [asset_product_id, product_id]:
		if not candidate_product_id.is_empty() and not sale_products.has(candidate_product_id):
			sale_products.append(candidate_product_id)
	var sales := {
		"advanced": false,
		"sale_receipt_count": 0,
		"owned_sale_receipt_count": 0,
		"products": [],
	}
	for sale_product_id in sale_products:
		var product_sales := _advance_until_product_sale(context, sale_product_id)
		(sales.get("products", []) as Array).append({
			"product_id": sale_product_id,
			"sale_receipt_count": int(product_sales.get("sale_receipt_count", 0)),
			"owned_sale_receipt_count": int(product_sales.get("owned_sale_receipt_count", 0)),
			"reason_code": str(product_sales.get("reason_code", "")),
		})
		sales["advanced"] = bool(sales.get("advanced", false)) or bool(product_sales.get("advanced", false))
		sales["sale_receipt_count"] = int(sales.get("sale_receipt_count", 0)) \
			+ int(product_sales.get("sale_receipt_count", 0))
		sales["owned_sale_receipt_count"] = int(sales.get("owned_sale_receipt_count", 0)) \
			+ int(product_sales.get("owned_sale_receipt_count", 0))
		if int(product_sales.get("owned_sale_receipt_count", 0)) <= 0:
			coordinator.pause_session()
			return {
				"ready": false,
				"reason_code": str(product_sales.get("reason_code", "legal_sale_missing")),
				"diagnostics": {"sales": sales.duplicate(true)},
			}
	coordinator.pause_session()
	var queue_purchase: Dictionary = await _purchase_with_legal_churn(
		coordinator,
		world,
		screen,
		overlay,
		popup,
		viewmodel_query,
		district_port,
		receipts,
		actor_id,
		queue_card_id,
		protected_card_ids
	)
	if not bool(queue_purchase.get("completed", false)):
		return {
			"ready": false,
			"reason_code": "legal_queue_capability_purchase_failed",
			"diagnostics": {"queue_card_id": queue_card_id},
		}
	coordinator.request_table_presentation_refresh(&"full", &"cold_restore_legal_checkpoint")
	await process_frame
	await process_frame
	return {
		"ready": true,
		"reason_code": "legal_checkpoint_ready",
		"actor_id": actor_id,
		"product_id": product_id,
		"queue_card_ids": [queue_card_id],
		"queue_plan": (candidate.get("queue_plan", {}) as Dictionary).duplicate(true),
		"queue_route": (candidate.get("route", {}) as Dictionary).duplicate(true),
		"asset_product_id": asset_product_id,
		"asset_factory_region_id": str(asset_factory_target.get("region_id", "")),
		"factory_region_id": str(factory_target.get("region_id", "")),
		"market_region_id": str(market_target.get("region_id", "")),
		"production_installation_ids": production_installation_ids.duplicate(),
		"commodity_action_count": 1,
		"normal_card_purchase_count": facility_purchase_count \
			+ int(queue_purchase.get("purchase_count", 0)),
		"facility_action_count": facility_action_count,
		"invalid_action_count": 0,
		"direct_authority_mutation_count": 0,
		"human_action_count": facility_purchase_count \
			+ int(queue_purchase.get("purchase_count", 0)) + facility_action_count,
		"sales": sales.duplicate(true),
	}


func _legal_factory_market_queue_plan(
	coordinator: GameRuntimeCoordinator,
	query_ports: TablePresentationQueryPorts,
	infrastructure: RegionInfrastructureRuntimeController,
	flow: Object,
	track_snapshot: CommoditySushiTrackSnapshot,
	queue_plans: Array[Dictionary]
) -> Dictionary:
	if coordinator == null or query_ports == null or infrastructure == null or flow == null \
			or track_snapshot == null or not track_snapshot.is_valid() \
			or query_ports.region_infrastructure_public_query == null or queue_plans.is_empty():
		return {"ready": false, "reason_code": "legal_factory_market_queue_plan_dependency_missing"}
	var claim_item: CommoditySushiTrackItemSnapshot = null
	for item_variant in track_snapshot.items:
		var item := item_variant as CommoditySushiTrackItemSnapshot
		if item != null and item.claimable:
			claim_item = item
			break
	if claim_item == null:
		return {"ready": false, "reason_code": "legal_commodity_claim_item_missing"}
	var facts_variant: Variant = query_ports.region_infrastructure_public_query.call("public_commodity_region_facts")
	var facts: Array = facts_variant if facts_variant is Array else []
	var routes := coordinator.get_node_or_null("RouteNetworkRuntimeController") as RouteNetworkRuntimeController
	if facts.is_empty() or routes == null:
		return {"ready": false, "reason_code": "legal_route_or_region_facts_missing"}
	var facility_card_index := _active_rank_one_facility_card_index(coordinator)
	if not bool(facility_card_index.get("valid", false)):
		return {
			"ready": false,
			"reason_code": str(facility_card_index.get("reason_code", "active_facility_catalog_invalid")),
		}
	var diagnostics: Array[Dictionary] = []
	for queue_plan in queue_plans:
		var asset_color := str(queue_plan.get("asset_color", ""))
		var required_mode := str(queue_plan.get("required_route_tag", ""))
		var distance_rule := str(queue_plan.get("distance_rule", ""))
		if not INDUSTRY_IDS.has(asset_color) or required_mode.is_empty() \
				or distance_rule not in ["near_lte_2", "remote_gt_2"]:
			continue
		var targets_by_industry: Dictionary = {}
		for industry_id_variant in INDUSTRY_IDS:
			var industry_id := str(industry_id_variant)
			var target_rows := _legal_factory_and_market_targets(
				coordinator,
				query_ports,
				infrastructure,
				flow,
				routes,
				facts,
				facility_card_index.get("cards_by_industry", {}) as Dictionary,
				industry_id
			)
			targets_by_industry[industry_id] = target_rows
		var asset_rows: Dictionary = targets_by_industry.get(asset_color, {}) \
			if targets_by_industry.get(asset_color, {}) is Dictionary else {}
		var asset_targets: Array = asset_rows.get("factory_targets", []) \
			if asset_rows.get("factory_targets", []) is Array else []
		var selected_pair: Dictionary = {}
		var selected_pair_industry := ""
		for industry_id_variant in INDUSTRY_IDS:
			var industry_id := str(industry_id_variant)
			var target_rows: Dictionary = targets_by_industry.get(industry_id, {}) \
				if targets_by_industry.get(industry_id, {}) is Dictionary else {}
			var factory_targets: Array = target_rows.get("factory_targets", []) \
				if target_rows.get("factory_targets", []) is Array else []
			var market_targets: Array = target_rows.get("market_targets", []) \
				if target_rows.get("market_targets", []) is Array else []
			for factory_target_variant in factory_targets:
				var factory_target := factory_target_variant as Dictionary
				var pair := _matching_specific_target_pair(
					routes,
					str(factory_target.get("product_id", "")),
					[factory_target],
					market_targets,
					required_mode,
					distance_rule
				)
				if not pair.is_empty():
					selected_pair = pair
					selected_pair_industry = industry_id
					break
			if not selected_pair.is_empty():
				break
		var selected_asset_target: Dictionary = {}
		if not selected_pair.is_empty() and selected_pair_industry == asset_color:
			selected_asset_target = (selected_pair.get("factory_target", {}) as Dictionary).duplicate(true)
		elif not asset_targets.is_empty() and asset_targets[0] is Dictionary:
			selected_asset_target = (asset_targets[0] as Dictionary).duplicate(true)
		if not selected_pair.is_empty() and not selected_asset_target.is_empty():
			var pair_rows: Dictionary = targets_by_industry.get(selected_pair_industry, {}) \
				if targets_by_industry.get(selected_pair_industry, {}) is Dictionary else {}
			return {
				"ready": true,
				"reason_code": "legal_factory_market_queue_plan_ready",
				"item": claim_item,
				"asset_factory_card_id": str(asset_rows.get("factory_card_id", "")),
				"asset_factory_target": selected_asset_target,
				"asset_product_id": str(selected_asset_target.get("product_id", "")),
				"factory_card_id": str(pair_rows.get("factory_card_id", "")),
				"market_card_id": str(pair_rows.get("market_card_id", "")),
				"queue_card_id": str(queue_plan.get("card_id", "")),
				"factory_target": (selected_pair.get("factory_target", {}) as Dictionary).duplicate(true),
				"market_target": (selected_pair.get("market_target", {}) as Dictionary).duplicate(true),
				"product_id": str((selected_pair.get("factory_target", {}) as Dictionary).get("product_id", "")),
				"route": (selected_pair.get("route", {}) as Dictionary).duplicate(true),
				"queue_plan": queue_plan.duplicate(true),
			}
		var per_industry: Array[Dictionary] = []
		for industry_id_variant in INDUSTRY_IDS:
			var industry_id := str(industry_id_variant)
			var target_rows: Dictionary = targets_by_industry.get(industry_id, {}) \
				if targets_by_industry.get(industry_id, {}) is Dictionary else {}
			per_industry.append({
				"industry_id": industry_id,
				"factory_target_count": (target_rows.get("factory_targets", []) as Array).size() \
					if target_rows.get("factory_targets", []) is Array else 0,
				"market_target_count": (target_rows.get("market_targets", []) as Array).size() \
					if target_rows.get("market_targets", []) is Array else 0,
			})
		diagnostics.append({
			"queue_card_id": str(queue_plan.get("card_id", "")),
			"asset_color": asset_color,
			"required_route_tag": required_mode,
			"distance_rule": distance_rule,
			"asset_factory_target_count": asset_targets.size(),
			"route_pair_found": not selected_pair.is_empty(),
			"route_pair_industry": selected_pair_industry,
			"targets_by_industry": per_industry,
		})
	return {
		"ready": false,
		"reason_code": "legal_factory_market_queue_target_missing",
		"diagnostics": {"queue_plans": diagnostics},
	}


func _legal_factory_and_market_targets(
	coordinator: GameRuntimeCoordinator,
	query_ports: TablePresentationQueryPorts,
	infrastructure: RegionInfrastructureRuntimeController,
	flow: Object,
	routes: RouteNetworkRuntimeController,
	facts: Array,
	facility_cards_by_industry: Dictionary,
	industry_id: String
) -> Dictionary:
	var card_pair: Dictionary = facility_cards_by_industry.get(industry_id, {}) \
		if facility_cards_by_industry.get(industry_id, {}) is Dictionary else {}
	var factory_card_id := str(card_pair.get("factory", ""))
	var market_card_id := str(card_pair.get("market", ""))
	if factory_card_id.is_empty() or market_card_id.is_empty():
		return {
			"factory_card_id": factory_card_id,
			"market_card_id": market_card_id,
			"factory_targets": [],
			"market_targets": [],
		}
	var factory_allowed := _facility_allowed_states(coordinator.v06_card_definition(factory_card_id))
	var market_allowed := _facility_allowed_states(coordinator.v06_card_definition(market_card_id))
	var public_factory := query_ports.public_new_facility_target_candidates(
		&"factory",
		StringName(industry_id)
	).to_dictionary()
	var public_market := query_ports.public_new_facility_target_candidates(
		&"market",
		StringName(industry_id)
	).to_dictionary()
	var public_factory_regions := _candidate_region_set(public_factory.get("candidates", []) as Array)
	var public_market_regions := _candidate_region_set(public_market.get("candidates", []) as Array)
	var factory_targets: Array[Dictionary] = []
	var market_targets: Array[Dictionary] = []
	for facts_row_variant in facts:
		if not (facts_row_variant is Dictionary):
			continue
		var facts_row := facts_row_variant as Dictionary
		var region_id := str(facts_row.get("region_id", ""))
		var product_id := _predicted_factory_product(facts_row, industry_id, flow)
		if region_id.is_empty():
			continue
		if not product_id.is_empty() \
				and bool(public_factory_regions.get(region_id, false)) \
				and _region_hosts_facility(
					infrastructure,
					region_id,
					"factory",
					industry_id,
					factory_allowed
				) \
				and _public_demand_route_exists(flow, routes, product_id, region_id, "", "any"):
			factory_targets.append({
				"region_id": region_id,
				"public_index": int(facts_row.get("legacy_index", -1)),
				"region_revision": int(facts_row.get("region_revision", 0)),
				"public_candidate": true,
				"industry_id": industry_id,
				"product_id": product_id,
			})
		if bool(public_market_regions.get(region_id, false)) \
				and _region_hosts_facility(
					infrastructure,
					region_id,
					"market",
					industry_id,
					market_allowed
				):
			market_targets.append({
				"region_id": region_id,
				"public_index": int(facts_row.get("legacy_index", -1)),
				"region_revision": int(facts_row.get("region_revision", 0)),
				"public_candidate": true,
				"industry_id": industry_id,
			})
	_sort_targets(factory_targets)
	_sort_targets(market_targets)
	return {
		"factory_card_id": factory_card_id,
		"market_card_id": market_card_id,
		"factory_targets": factory_targets,
		"market_targets": market_targets,
	}


func _active_rank_one_facility_card_index(coordinator: GameRuntimeCoordinator) -> Dictionary:
	if coordinator == null:
		return {"valid": false, "reason_code": "active_facility_catalog_dependency_missing"}
	var selection := ALPHA_CONTENT_LOADER.load_active_selection()
	if selection == null or not selection.is_valid():
		return {"valid": false, "reason_code": "active_facility_catalog_selection_invalid"}
	var card_ids: Array[String] = []
	for card_id_variant in selection.region_supply_card_ids:
		card_ids.append(str(card_id_variant))
	card_ids.sort()
	var result: Dictionary = {}
	for card_id in card_ids:
		var definition := coordinator.v06_card_definition(card_id)
		var machine: Dictionary = definition.get("machine", {}) \
			if definition.get("machine", {}) is Dictionary else {}
		var payload: Dictionary = machine.get("effect_payload", {}) \
			if machine.get("effect_payload", {}) is Dictionary else {}
		var facility_kind := str(payload.get("facility_kind", ""))
		var industry_id := str(payload.get("industry_id", machine.get("industry_id", "")))
		if str(machine.get("effect_kind", "")) != "build_upgrade_or_repair_facility" \
				or int(machine.get("rank", 0)) != 1 \
				or facility_kind not in ["factory", "market"] \
				or not INDUSTRY_IDS.has(industry_id):
			continue
		var pair: Dictionary = result.get(industry_id, {}) \
			if result.get(industry_id, {}) is Dictionary else {}
		if pair.has(facility_kind):
			return {"valid": false, "reason_code": "active_facility_catalog_duplicate"}
		pair[facility_kind] = card_id
		result[industry_id] = pair
	for industry_id_variant in INDUSTRY_IDS:
		var pair: Dictionary = result.get(str(industry_id_variant), {}) \
			if result.get(str(industry_id_variant), {}) is Dictionary else {}
		if str(pair.get("factory", "")).is_empty() or str(pair.get("market", "")).is_empty():
			return {"valid": false, "reason_code": "active_facility_catalog_incomplete"}
	return {
		"valid": true,
		"reason_code": "active_facility_catalog_ready",
		"cards_by_industry": result,
	}


func _advance_until_product_sale(
	context: Dictionary,
	product_id: String,
	required_purchasable_district: int = -1
) -> Dictionary:
	var coordinator := context.get("coordinator") as GameRuntimeCoordinator
	# The public (-1) receipt view intentionally redacts commodity ownership and
	# owner cash.  The authorized player-0 view is required for the independent
	# "owned real sale" proof below.
	var baseline_ids := _sale_receipt_id_set(coordinator.commodity_flow_recent_receipts(0))
	var observed_new: Dictionary = {}
	var owned_sale_count := 0
	var any_advanced := false
	var last_reason := ""
	var last_advance: Dictionary = {}
	var market_purchasable := required_purchasable_district < 0
	for _second in range(MAX_SALE_SECONDS):
		coordinator.advance_runtime_world_time(1.0)
		var advanced := coordinator.advance_commodity_flow(1.0, {})
		last_advance = advanced.duplicate(true)
		any_advanced = any_advanced or bool(advanced.get("advanced", false))
		last_reason = str(advanced.get("reason", advanced.get("reason_code", "")))
		for receipt_variant in coordinator.commodity_flow_recent_receipts(0):
			if not (receipt_variant is Dictionary):
				continue
			var receipt := receipt_variant as Dictionary
			var receipt_id := str(receipt.get("receipt_id", ""))
			if not receipt_id.is_empty() and not baseline_ids.has(receipt_id):
				observed_new[receipt_id] = receipt.duplicate(true)
		owned_sale_count = _matching_sale_count(observed_new.values(), 0, product_id, 0)
		market_purchasable = required_purchasable_district < 0 \
			or bool(coordinator.card_market_listing_availability(
				required_purchasable_district
			).get("purchasable", false))
		if owned_sale_count > 0 and market_purchasable:
			break
	return {
		"advanced": any_advanced,
		"sale_receipt_count": observed_new.size(),
		"owned_sale_receipt_count": owned_sale_count,
		"market_purchasable": market_purchasable,
		"reason_code": "legal_product_sale_ready" if owned_sale_count > 0 and market_purchasable \
			else ("legal_flow_advance_blocked" if not any_advanced else "legal_product_sale_missing"),
		"internal_reason": last_reason,
		"last_advance": last_advance,
		"flow_debug": (coordinator.commodity_flow_runtime_controller().debug_snapshot() as Dictionary).duplicate(true),
	}


func _advance_until_any_queue_capability_ready(context: Dictionary) -> Dictionary:
	var coordinator := context.get("coordinator") as GameRuntimeCoordinator
	var mana := coordinator.get_node_or_null("PlayerManaRuntimeController") as PlayerManaRuntimeController \
		if coordinator != null else null
	var actor_binding := coordinator.actor_id_for_player_index(0) if coordinator != null else {}
	var actor_id := str(actor_binding.get("actor_id", ""))
	var plans := _queue_capable_card_plans(coordinator)
	if coordinator == null or mana == null or not bool(actor_binding.get("available", false)) \
			or actor_id.is_empty() or plans.is_empty():
		return {"ready": false, "reason_code": "queue_capability_dependency_missing"}
	var baseline_ids := _sale_receipt_id_set(coordinator.commodity_flow_recent_receipts(0))
	var observed_ids: Dictionary = {}
	var last_reason := "queue_capability_not_checked"
	for second in range(MAX_QUEUE_ASSET_SECONDS + 1):
		var player := coordinator.v06_card_player_snapshot(actor_id)
		var availability := mana.availability_snapshot(0)
		var assets: Dictionary = availability.get("assets", {}) \
			if availability.get("assets", {}) is Dictionary else {}
		for plan in plans:
			var card_id := str(plan.get("card_id", ""))
			var slot_index := _inventory_slot_for_card(player, card_id)
			if slot_index < 0:
				continue
			var preflight := coordinator.preflight_v06_automatic_supply_demand(
				actor_id,
				_inventory_card_at(player, slot_index)
			)
			var asset_color := str(plan.get("asset_color", ""))
			var asset_amount := int(plan.get("asset_amount", 0))
			last_reason = str(preflight.get("reason_code", "queue_capability_preflight_missing"))
			if bool(preflight.get("ready", false)) \
					and int(assets.get(asset_color, 0)) >= asset_amount:
				return {
					"ready": true,
					"reason_code": "queue_capability_ready",
					"queue_card_id": card_id,
					"asset_color": asset_color,
					"asset_amount": asset_amount,
					"sale_receipt_count": observed_ids.size(),
					"seconds_advanced": second,
				}
		if second >= MAX_QUEUE_ASSET_SECONDS:
			break
		coordinator.advance_runtime_world_time(1.0)
		coordinator.advance_commodity_flow(1.0, {})
		for receipt_variant in coordinator.commodity_flow_recent_receipts(0):
			if not (receipt_variant is Dictionary):
				continue
			var receipt_id := str((receipt_variant as Dictionary).get("receipt_id", ""))
			if not receipt_id.is_empty() and not baseline_ids.has(receipt_id):
				observed_ids[receipt_id] = true
	return {
		"ready": false,
		"reason_code": "queue_capability_not_reached",
		"internal_reason": last_reason,
		"sale_receipt_count": observed_ids.size(),
		"seconds_advanced": MAX_QUEUE_ASSET_SECONDS,
	}


func _tick_ai_until_formal_queue(context: Dictionary, max_ticks: int) -> Dictionary:
	var coordinator := context.get("coordinator") as GameRuntimeCoordinator
	var flow := coordinator.get_node_or_null("TablePlayerActionApplicationFlowController") \
		as TablePlayerActionApplicationFlowController if coordinator != null else null
	var queue := coordinator.get_node_or_null("CardResolutionQueueRuntimeService") \
		as CardResolutionQueueRuntimeService if coordinator != null else null
	var runtime_loop := coordinator.get_node_or_null("RuntimeLoop") as RuntimeLoop \
		if coordinator != null else null
	if coordinator == null or flow == null or queue == null or runtime_loop == null \
			or _queue_entry_count(context) != 0:
		return {"accepted": false, "queued": false, "reason_code": "ai_queue_dependency_or_precondition_invalid"}
	var receipts: Array[Dictionary] = []
	var trigger_boundaries: Dictionary = {}
	var capture_receipt := func(receipt: Dictionary) -> void:
		receipts.append(receipt.duplicate(true))
		if bool(GAME_ACTION_RECEIPT.validation_report(receipt).get("valid", false)) \
				and bool(receipt.get("accepted", false)) \
				and str(receipt.get("semantic_action_id", "")) == GAME_ACTION_INTENT.ACTION_CARD_PLAY \
				and str(receipt.get("request_id", "")).begins_with("ai-game-action.") \
				and _queue_entry_count(context) > 0:
			var request_id := str(receipt.get("request_id", ""))
			if not trigger_boundaries.has(request_id):
				trigger_boundaries[request_id] = {
					"observation": _safety_observation(context),
					"driver": coordinator.card_resolution_frame_driver_debug(),
					"engine_frame": Engine.get_process_frames(),
				}
			# The receipt is emitted only after the Action Spine committed the queue
			# entry.  Pause within that same RuntimeLoop call so no later logical
			# step can begin before the save boundary takes ownership.
			coordinator.pause_session()
	flow.receipt_ready.connect(capture_receipt)
	var flow_before := flow.debug_snapshot()
	var lease := TERMINAL_EVIDENCE.acquire_manual_lease(context)
	if not bool(lease.get("accepted", false)):
		if flow.receipt_ready.is_connected(capture_receipt):
			flow.receipt_ready.disconnect(capture_receipt)
		return {
			"accepted": false,
			"queued": false,
			"reason_code": str(lease.get("reason_code", "ai_runtime_loop_lease_rejected")),
		}
	var step_failure := ""
	for _tick_index in range(maxi(1, max_ticks)):
		var receipt_start := receipts.size()
		var step := AUTHORITATIVE_STEPPER.advance_bounded(runtime_loop, 0.5, 1)
		if not bool(step.get("accepted", false)):
			step_failure = str(step.get("reason_id", "ai_authoritative_runtime_step_rejected"))
			break
		if _queue_entry_count(context) <= 0:
			continue
		coordinator.pause_session()
		if flow.receipt_ready.is_connected(capture_receipt):
			flow.receipt_ready.disconnect(capture_receipt)
		var public_report := _formal_public_queue_resolution_report(queue.public_snapshot())
		var resolution_ids: Array[int] = []
		if bool(public_report.get("valid", false)):
			for id_variant in (public_report.get("resolution_ids", {}) as Dictionary).keys():
				resolution_ids.append(int(id_variant))
		resolution_ids.sort()
		var resolution_id := resolution_ids[0] if not resolution_ids.is_empty() else -1
		var entry := queue.entry_by_id(resolution_id) if resolution_id >= 0 else {}
		var target_validation := CardResolutionStableTargetEnvelope.validate_entry_binding(entry) \
			if not entry.is_empty() else {"valid": false, "reason_code": "stable_target_queue_entry_missing"}
		var accepted_receipts: Array[Dictionary] = []
		for receipt_index in range(receipt_start, receipts.size()):
			var receipt := receipts[receipt_index]
			if bool(GAME_ACTION_RECEIPT.validation_report(receipt).get("valid", false)) \
					and bool(receipt.get("accepted", false)) \
					and str(receipt.get("semantic_action_id", "")) == GAME_ACTION_INTENT.ACTION_CARD_PLAY \
					and str(receipt.get("request_id", "")).begins_with("ai-game-action."):
				accepted_receipts.append(receipt.duplicate(true))
		var boundary: Dictionary = {}
		if accepted_receipts.size() == 1:
			var request_id := str(accepted_receipts[0].get("request_id", ""))
			boundary = (trigger_boundaries.get(request_id, {}) as Dictionary).duplicate(true) \
				if trigger_boundaries.get(request_id, {}) is Dictionary else {}
		var flow_after := flow.debug_snapshot()
		var skill: Dictionary = entry.get("skill", {}) if entry.get("skill", {}) is Dictionary else {}
		var machine: Dictionary = skill.get("machine", {}) if skill.get("machine", {}) is Dictionary else {}
		var envelope: Dictionary = target_validation.get("envelope", {}) \
			if target_validation.get("envelope", {}) is Dictionary else {}
		var observation_at_trigger: Dictionary = boundary.get("observation", {}) \
			if boundary.get("observation", {}) is Dictionary else {}
		var driver_at_trigger: Dictionary = boundary.get("driver", {}) \
			if boundary.get("driver", {}) is Dictionary else {}
		var observation_after_trigger := _safety_observation(context)
		var driver_after_trigger := coordinator.card_resolution_frame_driver_debug()
		var same_logical_step := not boundary.is_empty() \
			and int(boundary.get("engine_frame", -1)) == Engine.get_process_frames()
		var resolution_advance_after_trigger := int(driver_after_trigger.get("tick_count", -1)) \
			- int(driver_at_trigger.get("tick_count", -1))
		var world_advance_after_trigger := _delta(
			observation_at_trigger,
			observation_after_trigger,
			"world_clock_advance_count"
		)
		var rng_draw_after_trigger := _delta(
			observation_at_trigger,
			observation_after_trigger,
			"rng_draw_invocation_count"
		)
		var release := TERMINAL_EVIDENCE.release_manual_lease(context)
		var accepted := bool(public_report.get("valid", false)) and resolution_ids.size() == 1 \
			and int(public_report.get("count", 0)) == 1 \
			and bool(target_validation.get("valid", false)) and accepted_receipts.size() == 1 \
			and int(flow_after.get("ai_submission_count", 0)) > int(flow_before.get("ai_submission_count", 0)) \
			and same_logical_step and resolution_advance_after_trigger == 0 \
			and world_advance_after_trigger == 0 and rng_draw_after_trigger == 0 \
			and bool(release.get("released", false))
		return {
			"accepted": accepted,
			"queued": accepted,
			"reason_code": "queued" if accepted else "ai_queue_same_step_evidence_invalid",
			"queue_count": int(public_report.get("count", 0)),
			"queue_revision": int(queue.queue_state_snapshot().get("revision", 0)),
			"new_queue_resolution_ids": resolution_ids.duplicate(),
			"queue_resolution_id": resolution_id,
			"ai_action_count": maxi(
				0,
				int(flow_after.get("ai_submission_count", 0)) - int(flow_before.get("ai_submission_count", 0))
			),
			"actor": "ai",
			"actor_index": int(entry.get("player_index", -1)),
			"semantic_action_id": GAME_ACTION_INTENT.ACTION_CARD_PLAY,
			"card_semantic_id": str(machine.get("card_id", skill.get("card_id", skill.get("name", "")))),
			"card_instance_id": str(skill.get("runtime_instance_id", entry.get("card_instance_id", ""))),
			"target_fingerprint": str(envelope.get("envelope_fingerprint", "")),
			"receipt_fingerprint": str(accepted_receipts[0].get("receipt_fingerprint", "")) \
				if not accepted_receipts.is_empty() else "",
			"stable_target_envelope_fingerprint": str(envelope.get("envelope_fingerprint", "")),
			"same_logical_step": same_logical_step,
			"card_resolution_advance_after_trigger": resolution_advance_after_trigger,
			"world_advance_after_trigger": world_advance_after_trigger,
			"rng_draw_after_trigger": rng_draw_after_trigger,
		}
	if flow.receipt_ready.is_connected(capture_receipt):
		flow.receipt_ready.disconnect(capture_receipt)
	coordinator.pause_session()
	var release := TERMINAL_EVIDENCE.release_manual_lease(context)
	return {
		"accepted": false,
		"queued": false,
		"reason_code": "ai_legal_queue_offer_missing" if step_failure.is_empty() \
			and bool(release.get("released", false)) else "ai_authoritative_runtime_step_failed",
		"runtime_step_reason": step_failure,
	}


func _queue_entry_count(context: Dictionary) -> int:
	var coordinator := context.get("coordinator") as GameRuntimeCoordinator
	var queue := coordinator.get_node_or_null("CardResolutionQueueRuntimeService") as CardResolutionQueueRuntimeService \
		if coordinator != null else null
	if queue == null:
		return -1
	var snapshot := queue.public_snapshot()
	return int(snapshot.get("current_count", 0)) + int(snapshot.get("next_count", 0)) \
		+ (1 if bool(snapshot.get("active_present", false)) else 0)


func _queue_target_observation(context: Dictionary, resolution_id: int) -> Dictionary:
	var coordinator := context.get("coordinator") as GameRuntimeCoordinator
	var queue := coordinator.get_node_or_null("CardResolutionQueueRuntimeService") \
		as CardResolutionQueueRuntimeService if coordinator != null else null
	var execution := coordinator.get_node_or_null("CardResolutionExecutionRuntimeService") \
		as CardResolutionExecutionRuntimeService if coordinator != null else null
	var history := coordinator.get_node_or_null("CardResolutionHistoryRuntimeService") \
		as CardResolutionHistoryRuntimeService if coordinator != null else null
	var transition := coordinator.get_node_or_null("CardResolutionTransitionSink") \
		as CardResolutionTransitionSink if coordinator != null else null
	var inventory := coordinator.get_node_or_null("CardInventoryRuntimeService") \
		as CardInventoryRuntimeService if coordinator != null else null
	var public_log := coordinator.get_node_or_null("TablePresentationQueryPorts/PublicLogPresentationOwner") \
		as PublicLogPresentationOwner if coordinator != null else null
	if resolution_id <= 0 or queue == null or execution == null or history == null \
			or transition == null or inventory == null or public_log == null:
		return {
			"valid": false,
			"reason_code": "queue_target_observation_dependency_missing",
			"resolution_id": resolution_id,
		}
	var queue_state := queue.queue_state_snapshot()
	var matching_entries: Array[Dictionary] = []
	for lane_field in ["current_queue", "next_queue"]:
		var lane: Array = queue_state.get(lane_field, []) \
			if queue_state.get(lane_field, []) is Array else []
		for entry_variant in lane:
			if entry_variant is Dictionary \
					and int((entry_variant as Dictionary).get("resolution_id", -1)) == resolution_id:
				matching_entries.append((entry_variant as Dictionary).duplicate(true))
	var active: Dictionary = queue_state.get("active_entry", {}) \
		if queue_state.get("active_entry", {}) is Dictionary else {}
	if int(active.get("resolution_id", -1)) == resolution_id:
		matching_entries.append(active.duplicate(true))
	var pending_count := matching_entries.size()
	var stable_target_fingerprint := ""
	var stable_target_valid := pending_count == 0
	if pending_count == 1:
		var target_validation := CardResolutionStableTargetEnvelope.validate_entry_binding(matching_entries[0])
		var envelope: Dictionary = target_validation.get("envelope", {}) \
			if target_validation.get("envelope", {}) is Dictionary else {}
		stable_target_valid = bool(target_validation.get("valid", false))
		stable_target_fingerprint = str(envelope.get("envelope_fingerprint", ""))
	var execution_state := execution.to_save_data()
	var completed_ids: Array = execution_state.get("completed_resolution_ids", []) \
		if execution_state.get("completed_resolution_ids", []) is Array else []
	var completed_count := _resolution_id_occurrence(completed_ids, resolution_id)
	var history_state := history.to_save_data()
	var history_rows: Array = history_state.get("history", []) \
		if history_state.get("history", []) is Array else []
	var history_lineage: Array = history_state.get("appended_resolution_ids", []) \
		if history_state.get("appended_resolution_ids", []) is Array else []
	var history_count := 0
	for row_variant in history_rows:
		if row_variant is Dictionary \
				and int((row_variant as Dictionary).get("resolution_id", -1)) == resolution_id:
			history_count += 1
	var history_lineage_count := _resolution_id_occurrence(history_lineage, resolution_id)
	var execution_debug := execution.debug_snapshot()
	var history_debug := history.debug_snapshot()
	var transition_debug := transition.debug_snapshot()
	var inventory_debug := inventory.debug_snapshot()
	var public_log_debug := public_log.debug_snapshot()
	var valid := pending_count <= 1 and completed_count <= 1 and history_count <= 1 \
		and history_lineage_count == history_count and stable_target_valid
	return {
		"valid": valid,
		"reason_code": "queue_target_observation_valid" if valid else "queue_target_observation_lineage_invalid",
		"resolution_id": resolution_id,
		"pending_count": pending_count,
		"completed_count": completed_count,
		"history_count": history_count,
		"history_lineage_count": history_lineage_count,
		"stable_target_valid": stable_target_valid,
		"stable_target_fingerprint": stable_target_fingerprint,
		"execution_finalize_count": int(execution_debug.get("finalized_count", -1)),
		"history_append_count": int(history_debug.get("append_count", -1)),
		"history_duplicate_count": int(history_debug.get("duplicate_append_count", -1)),
		"transition_duplicate_count": int(transition_debug.get("duplicate_count", -1)),
		"inventory_queue_commit_count": int(inventory_debug.get("queue_committed_count", -1)),
		"public_log_duplicate_count": int(public_log_debug.get("duplicate_receipt_count", -1)),
		"public_log_collision_count": int(public_log_debug.get("collision_receipt_count", -1)),
	}


func _resolution_id_occurrence(values: Array, resolution_id: int) -> int:
	var count := 0
	for value_variant in values:
		if typeof(value_variant) == TYPE_INT and int(value_variant) == resolution_id:
			count += 1
	return count


func _queue_target_manifest_evidence(
	resolution_id: int,
	stable_target_fingerprint: String,
	before: Dictionary,
	after: Dictionary
) -> Dictionary:
	return {
		"queue_trigger_resolution_id": resolution_id,
		"queue_trigger_stable_target_fingerprint": stable_target_fingerprint,
		"queue_target_pending_before_resume": int(before.get("pending_count", -1)),
		"queue_target_pending_after_resume": int(after.get("pending_count", -1)),
		"queue_target_completed_before_resume": int(before.get("completed_count", -1)),
		"queue_target_completed_after_resume": int(after.get("completed_count", -1)),
		"queue_target_history_before_resume": int(before.get("history_count", -1)),
		"queue_target_history_after_resume": int(after.get("history_count", -1)),
		"queue_target_execution_finalize_delta": _delta(before, after, "execution_finalize_count"),
		"queue_target_history_append_delta": _delta(before, after, "history_append_count"),
		"queue_target_history_duplicate_delta": _delta(before, after, "history_duplicate_count"),
		"queue_target_transition_duplicate_delta": _delta(before, after, "transition_duplicate_count"),
		"queue_target_inventory_queue_commit_delta": _delta(before, after, "inventory_queue_commit_count"),
		"queue_target_public_log_duplicate_delta": _delta(before, after, "public_log_duplicate_count"),
		"queue_target_public_log_collision_delta": _delta(before, after, "public_log_collision_count"),
	}


func _queue_target_role_evidence_valid(
	role: String,
	expected_stable_target_fingerprint: String,
	before: Dictionary,
	after: Dictionary,
	evidence: Dictionary
) -> bool:
	if not bool(before.get("valid", false)) or not bool(after.get("valid", false)) \
			or not _is_lower_sha256(expected_stable_target_fingerprint):
		return false
	for delta_field in [
		"queue_target_execution_finalize_delta",
		"queue_target_history_append_delta",
		"queue_target_history_duplicate_delta",
		"queue_target_transition_duplicate_delta",
		"queue_target_inventory_queue_commit_delta",
		"queue_target_public_log_duplicate_delta",
		"queue_target_public_log_collision_delta",
	]:
		if int(evidence.get(delta_field, -1)) < 0:
			return false
	for quiet_field in [
		"queue_target_history_duplicate_delta",
		"queue_target_transition_duplicate_delta",
		"queue_target_inventory_queue_commit_delta",
		"queue_target_public_log_duplicate_delta",
		"queue_target_public_log_collision_delta",
	]:
		if int(evidence.get(quiet_field, -1)) != 0:
			return false
	match role:
		"producer":
			return str(before.get("stable_target_fingerprint", "")) == expected_stable_target_fingerprint \
				and str(after.get("stable_target_fingerprint", "")) == expected_stable_target_fingerprint \
				and int(evidence.get("queue_target_pending_before_resume", -1)) == 1 \
				and int(evidence.get("queue_target_pending_after_resume", -1)) == 1 \
				and int(evidence.get("queue_target_completed_before_resume", -1)) == 0 \
				and int(evidence.get("queue_target_completed_after_resume", -1)) == 0 \
				and int(evidence.get("queue_target_history_before_resume", -1)) == 0 \
				and int(evidence.get("queue_target_history_after_resume", -1)) == 0 \
				and int(evidence.get("queue_target_execution_finalize_delta", -1)) == 0 \
				and int(evidence.get("queue_target_history_append_delta", -1)) == 0
		"consumer":
			return str(before.get("stable_target_fingerprint", "")) == expected_stable_target_fingerprint \
				and int(evidence.get("queue_target_pending_before_resume", -1)) == 1 \
				and int(evidence.get("queue_target_pending_after_resume", -1)) == 0 \
				and int(evidence.get("queue_target_completed_before_resume", -1)) == 0 \
				and int(evidence.get("queue_target_completed_after_resume", -1)) == 1 \
				and int(evidence.get("queue_target_history_before_resume", -1)) == 0 \
				and int(evidence.get("queue_target_history_after_resume", -1)) == 1 \
				and int(evidence.get("queue_target_execution_finalize_delta", -1)) == 1 \
				and int(evidence.get("queue_target_history_append_delta", -1)) == 1
		"validator":
			return int(evidence.get("queue_target_pending_before_resume", -1)) == 0 \
				and int(evidence.get("queue_target_pending_after_resume", -1)) == 0 \
				and int(evidence.get("queue_target_completed_before_resume", -1)) == 1 \
				and int(evidence.get("queue_target_completed_after_resume", -1)) == 1 \
				and int(evidence.get("queue_target_history_before_resume", -1)) == 1 \
				and int(evidence.get("queue_target_history_after_resume", -1)) == 1 \
				and int(evidence.get("queue_target_execution_finalize_delta", -1)) == 0 \
				and int(evidence.get("queue_target_history_append_delta", -1)) == 0
	return false


func _drain_target_resolution(context: Dictionary, resolution_id: int, maximum_steps: int) -> Dictionary:
	var coordinator := context.get("coordinator") as GameRuntimeCoordinator
	if coordinator == null or resolution_id <= 0:
		return {"drained": false, "step_count": 0, "reason_code": "queue_target_drain_dependency_missing"}
	var steps := 0
	var observation := _queue_target_observation(context, resolution_id)
	while bool(observation.get("valid", false)) \
			and int(observation.get("pending_count", 0)) == 1 \
			and steps < maximum_steps:
		coordinator.advance_card_resolution_frame(30.0)
		steps += 1
		observation = _queue_target_observation(context, resolution_id)
	var drained := bool(observation.get("valid", false)) \
		and int(observation.get("pending_count", -1)) == 0 \
		and int(observation.get("completed_count", -1)) == 1 \
		and int(observation.get("history_count", -1)) == 1
	return {
		"drained": drained,
		"step_count": steps,
		"reason_code": "queue_target_drained" if drained else "queue_target_drain_incomplete",
		"observation": observation.duplicate(true),
	}


func _drain_pending_queue(context: Dictionary, maximum_steps: int) -> Dictionary:
	var coordinator := context.get("coordinator") as GameRuntimeCoordinator
	if coordinator == null:
		return {"drained": false, "step_count": 0}
	var steps := 0
	while _queue_entry_count(context) > 0 and steps < maximum_steps:
		coordinator.advance_card_resolution_frame(30.0)
		steps += 1
	return {"drained": _queue_entry_count(context) == 0, "step_count": steps}


func _submit_first_formal_queue_offer(
	context: Dictionary,
	expected_card_semantic_id: String = "",
	expected_region_id: String = ""
) -> Dictionary:
	var coordinator := context.get("coordinator") as GameRuntimeCoordinator
	var main := context.get("main") as Node
	var screen := main.find_child("RuntimeGameScreen", true, false) as SpaceSyndicateGameScreen \
		if main != null else null
	var flow := coordinator.get_node_or_null("TablePlayerActionApplicationFlowController") \
		as TablePlayerActionApplicationFlowController if coordinator != null else null
	var queue := coordinator.get_node_or_null("CardResolutionQueueRuntimeService") \
		as CardResolutionQueueRuntimeService if coordinator != null else null
	if screen == null or flow == null or queue == null:
		return {"accepted": false, "queued": false, "reason_code": "queue_offer_dependency_missing"}
	var dock_variant: Variant = screen.current_ui_data.get("player_card_dock", {})
	if not (dock_variant is Dictionary):
		return {"accepted": false, "queued": false, "reason_code": "queue_offer_dock_missing"}
	var dock := dock_variant as Dictionary
	var reason_diagnostics := {
		"dock_projection_fingerprint": str(dock.get("projection_fingerprint", "")),
		"dock_source_revision": int(dock.get("source_revision", -1)),
		"pool_summary": _formal_dock_offer_pool_summary(dock),
	}
	var dock_validation := PlayerCardDockProjectionV1.validation_report(dock)
	if not bool(dock_validation.get("valid", false)):
		return {
			"accepted": false,
			"queued": false,
			"reason_code": str(dock_validation.get("reason_code", "queue_offer_dock_invalid")),
			"reason_diagnostics": reason_diagnostics,
		}
	var authorization := screen.game_action_actor_authorization("human_click")
	if authorization.is_empty() \
			or int(dock.get("viewer_index", -1)) != int(authorization.get("actor_index", -2)) \
			or str(dock.get("actor_id", "")) != str(authorization.get("actor_id", "")) \
			or int(dock.get("authorization_revision", 0)) != int(authorization.get("actor_revision", -1)):
		return {
			"accepted": false,
			"queued": false,
			"reason_code": "queue_offer_dock_authorization_stale",
			"reason_diagnostics": reason_diagnostics,
		}
	var candidates: Array[Dictionary] = []
	var pool_specs := [
		{
			"pool_id": "normal_cards",
			"instance_field": "card_instance_id",
			"semantic_field": "card_semantic_id",
			"slot_field": "slot_id",
			"availability_field": "play_state",
		},
		{
			"pool_id": "commodity_cards",
			"instance_field": "commodity_card_instance_id",
			"semantic_field": "card_semantic_id",
			"slot_field": "slot_id",
			"availability_field": "play_state",
		},
		{
			"pool_id": "bound_actions",
			"instance_field": "bound_action_instance_id",
			"semantic_field": "action_semantic_id",
			"slot_field": "",
			"availability_field": "enabled",
		},
	]
	for pool_order in range(pool_specs.size()):
		var pool_spec: Dictionary = pool_specs[pool_order]
		var pool_id := str(pool_spec.get("pool_id", ""))
		var rows: Array = dock.get(pool_id, []) if dock.get(pool_id, []) is Array else []
		for row_variant in rows:
			if not (row_variant is Dictionary):
				continue
			var row := row_variant as Dictionary
			var row_card_semantic_id := str(row.get(str(pool_spec.get("semantic_field", "")), ""))
			if not expected_card_semantic_id.is_empty() and row_card_semantic_id == expected_card_semantic_id:
				var diagnostic_offer: Dictionary = row.get("game_action_offer", {}) \
					if row.get("game_action_offer", {}) is Dictionary else {}
				var diagnostic_targets: Dictionary = diagnostic_offer.get("target_ids", {}) \
					if diagnostic_offer.get("target_ids", {}) is Dictionary else {}
				var matching_rows: Array = reason_diagnostics.get("expected_card_rows", []) \
					if reason_diagnostics.get("expected_card_rows", []) is Array else []
				matching_rows.append({
					"pool_id": pool_id,
					"card_semantic_id": row_card_semantic_id,
					"play_state": str(row.get("play_state", "")),
					"disabled_reason_id": str(row.get("disabled_reason_id", "")),
					"offer_legality_state": str(diagnostic_offer.get("legality_state", "")),
					"target_region_id": str(diagnostic_targets.get("region_id", "")),
				})
				reason_diagnostics["expected_card_rows"] = matching_rows
			var availability_field := str(pool_spec.get("availability_field", ""))
			var available := bool(row.get(availability_field, false)) \
				if availability_field == "enabled" else str(row.get(availability_field, "")) == "available"
			if not available:
				continue
			var offer: Dictionary = row.get("game_action_offer", {}) \
				if row.get("game_action_offer", {}) is Dictionary else {}
			if not bool(GAME_ACTION_OFFER.validation_report(offer).get("valid", false)) \
					or str(offer.get("legality_state", "")) != "available" \
					or str(offer.get("semantic_action_id", "")) != GAME_ACTION_INTENT.ACTION_CARD_PLAY:
				return {
					"accepted": false,
					"queued": false,
					"reason_code": "queue_offer_available_row_invalid",
					"reason_diagnostics": reason_diagnostics,
				}
			var targets := GAME_ACTION_OFFER.target_ids(offer)
			# A commodity dock row can be honestly "available" while its first
			# click still opens the typed facility-target selector.  That row is a
			# target-selection surface, not an immediate queue-submission offer, so
			# exclude it without submitting a deliberately rejected intent.
			if pool_id == "commodity_cards":
				reason_diagnostics["deferred_target_selection_offer_count"] = int(
					reason_diagnostics.get("deferred_target_selection_offer_count", 0)
				) + 1
				continue
			var hand_slot_id := str(targets.get("hand_slot_id", ""))
			var slot_index := _formal_hand_slot_index(hand_slot_id)
			var card_instance_id := str(targets.get("card_instance_id", ""))
			var projected_instance_id := str(row.get(str(pool_spec.get("instance_field", "")), ""))
			var slot_field := str(pool_spec.get("slot_field", ""))
			if slot_index < 0 or card_instance_id.is_empty() \
					or projected_instance_id != card_instance_id \
					or (not slot_field.is_empty() and str(row.get(slot_field, "")) != hand_slot_id) \
					or int(row.get("source_revision", -1)) != int(offer.get("source_revision", -2)):
				return {
					"accepted": false,
					"queued": false,
					"reason_code": "queue_offer_available_row_binding_invalid",
					"reason_diagnostics": reason_diagnostics,
				}
			var offer_fingerprint := str(offer.get("offer_fingerprint", ""))
			var semantic_action_id := str(offer.get("semantic_action_id", ""))
			var card_semantic_id := row_card_semantic_id
			if not expected_card_semantic_id.is_empty() \
					and card_semantic_id != expected_card_semantic_id:
				continue
			if not expected_region_id.is_empty() \
					and not str(targets.get("region_id", "")).is_empty() \
					and str(targets.get("region_id", "")) != expected_region_id:
				continue
			var definition := coordinator.v06_card_definition(card_semantic_id)
			var machine: Dictionary = definition.get("machine", {}) \
				if definition.get("machine", {}) is Dictionary else {}
			if not QUEUE_EFFECT_KINDS.has(str(machine.get("effect_kind", ""))):
				reason_diagnostics["non_queue_offer_count"] = int(
					reason_diagnostics.get("non_queue_offer_count", 0)
				) + 1
				continue
			var effective_targets := targets.duplicate(true)
			var target_overrides: Dictionary = {}
			if not expected_region_id.is_empty() and str(effective_targets.get("region_id", "")).is_empty():
				effective_targets["region_id"] = expected_region_id
				target_overrides["region_id"] = expected_region_id
			var target_fingerprint := SEMANTIC_WIRE.fingerprint(effective_targets)
			var stable_sort_key := "%s\u001f%s\u001f%s\u001f%s\u001f%010d\u001f%02d:%s\u001f%010d\u001f%s" % [
				semantic_action_id,
				card_semantic_id,
				card_instance_id,
				target_fingerprint,
				slot_index,
				pool_order,
				pool_id,
				int(offer.get("source_revision", 0)),
				offer_fingerprint,
			]
			candidates.append({
				"offer": offer.duplicate(true),
				"semantic_action_id": semantic_action_id,
				"card_semantic_id": card_semantic_id,
				"card_instance_id": card_instance_id,
				"hand_slot_id": hand_slot_id,
				"pool_id": pool_id,
				"stable_sort_key": stable_sort_key,
				"offer_fingerprint": offer_fingerprint,
				"target_fingerprint": target_fingerprint,
				"target_overrides": target_overrides.duplicate(true),
			})
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("stable_sort_key", "")) < str(right.get("stable_sort_key", ""))
	)
	reason_diagnostics["candidate_count"] = candidates.size()
	if candidates.is_empty():
		return {
			"accepted": false,
			"queued": false,
			"reason_code": "legal_queue_offer_missing",
			"reason_diagnostics": reason_diagnostics,
		}
	var before_public := queue.public_snapshot()
	var before_public_report := _formal_public_queue_resolution_report(before_public)
	if not bool(before_public_report.get("valid", false)):
		return {
			"accepted": false,
			"queued": false,
			"reason_code": "queue_public_snapshot_before_invalid",
			"reason_diagnostics": reason_diagnostics,
		}
	var before_count := int(before_public_report.get("count", -1))
	if before_count != 0:
		return {
			"accepted": false,
			"queued": false,
			"reason_code": "queue_not_empty_before_trigger",
			"reason_diagnostics": reason_diagnostics,
		}
	var before_state := queue.queue_state_snapshot()
	var before_observation := _safety_observation(context)
	var frame_before := Engine.get_process_frames()
	var driver_before := coordinator.card_resolution_frame_driver_debug()
	var intents: Array[Dictionary] = []
	var receipts: Array[Dictionary] = []
	var capture_intent := func(intent: Dictionary) -> void:
		intents.append(intent.duplicate(true))
	var capture_receipt := func(receipt: Dictionary) -> void:
		receipts.append(receipt.duplicate(true))
	screen.game_action_intent_requested.connect(capture_intent)
	flow.receipt_ready.connect(capture_receipt)
	var selected := candidates[0]
	var submitted := screen.submit_game_action_offer(
		selected.get("offer", {}) as Dictionary,
		"human_click",
		{},
		selected.get("target_overrides", {}) as Dictionary
	)
	coordinator.pause_session()
	if screen.game_action_intent_requested.is_connected(capture_intent):
		screen.game_action_intent_requested.disconnect(capture_intent)
	if flow.receipt_ready.is_connected(capture_receipt):
		flow.receipt_ready.disconnect(capture_receipt)
	var after_public := queue.public_snapshot()
	var after_public_report := _formal_public_queue_resolution_report(after_public)
	var after_count := int(after_public_report.get("count", -1))
	var after_state := queue.queue_state_snapshot()
	var after_observation := _safety_observation(context)
	var driver_after := coordinator.card_resolution_frame_driver_debug()
	var intent: Dictionary = intents[0] if intents.size() == 1 else {}
	var receipt: Dictionary = receipts[0] if receipts.size() == 1 else {}
	var intent_valid := bool(GAME_ACTION_INTENT.validation_report(intent).get("valid", false))
	var intent_offer_bound := intent_valid \
		and GAME_ACTION_OFFER.accepts_intent(selected.get("offer", {}) as Dictionary, intent) \
		and SEMANTIC_WIRE.fingerprint(intent.get("target_ids", {}) as Dictionary) \
		== str(selected.get("target_fingerprint", ""))
	var receipt_valid := bool(GAME_ACTION_RECEIPT.validation_report(receipt).get("valid", false))
	var receipt_request_bound := intent_valid and receipt_valid \
		and GAME_ACTION_RECEIPT.request_binding_matches(receipt, intent)
	var before_ids: Dictionary = before_public_report.get("resolution_ids", {}) \
		if before_public_report.get("resolution_ids", {}) is Dictionary else {}
	var after_ids: Dictionary = after_public_report.get("resolution_ids", {}) \
		if after_public_report.get("resolution_ids", {}) is Dictionary else {}
	var new_resolution_ids: Array[int] = []
	var removed_resolution_ids: Array[int] = []
	for resolution_id_variant in after_ids.keys():
		var resolution_id := int(resolution_id_variant)
		if not before_ids.has(resolution_id):
			new_resolution_ids.append(resolution_id)
	for resolution_id_variant in before_ids.keys():
		var resolution_id := int(resolution_id_variant)
		if not after_ids.has(resolution_id):
			removed_resolution_ids.append(resolution_id)
	new_resolution_ids.sort()
	removed_resolution_ids.sort()
	var public_queue_transition := bool(after_public_report.get("valid", false)) \
		and before_count == 0 and after_count > 0
	var exactly_one_new_entry := public_queue_transition \
		and new_resolution_ids.size() == 1 and removed_resolution_ids.is_empty() \
		and after_count == before_count + 1
	var new_resolution_id := new_resolution_ids[0] if exactly_one_new_entry else -1
	var queued_entry := queue.entry_by_id(new_resolution_id) if new_resolution_id >= 0 else {}
	var stable_target_validation := CardResolutionStableTargetEnvelope.validate_entry_binding(queued_entry) \
		if not queued_entry.is_empty() else {"valid": false, "reason_code": "stable_target_queue_entry_missing"}
	var stable_target_valid := bool(stable_target_validation.get("valid", false))
	var stable_target_envelope: Dictionary = stable_target_validation.get("envelope", {}) \
		if stable_target_validation.get("envelope", {}) is Dictionary else {}
	var same_step := Engine.get_process_frames() == frame_before \
		and int(driver_after.get("tick_count", -1)) == int(driver_before.get("tick_count", -2))
	var quiet := _delta(before_observation, after_observation, "world_clock_advance_count") == 0 \
		and _delta(before_observation, after_observation, "rng_draw_invocation_count") == 0
	var queued := exactly_one_new_entry and stable_target_valid \
		and int(after_state.get("revision", -1)) > int(before_state.get("revision", -1))
	var accepted := submitted and intents.size() == 1 and intent_offer_bound \
		and receipts.size() == 1 and receipt_request_bound and bool(receipt.get("accepted", false)) \
		and queued and same_step and quiet
	var reason_code := str(receipt.get("reason_id", "queue_offer_accepted")) if accepted else "queue_offer_rejected"
	if not submitted:
		reason_code = "queue_offer_not_emitted"
	elif intents.size() != 1 or not intent_valid:
		reason_code = "queue_offer_intent_capture_invalid"
	elif not intent_offer_bound:
		reason_code = "queue_offer_intent_binding_invalid"
	elif receipts.size() != 1 or not receipt_valid:
		reason_code = "queue_offer_receipt_capture_invalid"
	elif not receipt_request_bound:
		reason_code = "queue_offer_receipt_request_binding_invalid"
	elif not bool(receipt.get("accepted", false)):
		reason_code = str(receipt.get("reason_id", "queue_offer_rejected"))
	elif not public_queue_transition or not exactly_one_new_entry:
		reason_code = "queue_offer_public_queue_transition_invalid"
	elif not stable_target_valid:
		reason_code = str(stable_target_validation.get("reason_code", "queue_offer_stable_target_invalid"))
	elif int(after_state.get("revision", -1)) <= int(before_state.get("revision", -1)):
		reason_code = "queue_offer_revision_not_advanced"
	elif not same_step:
		reason_code = "queue_offer_same_step_freeze_lost"
	elif not quiet:
		reason_code = "queue_offer_submission_side_effect_not_quiet"
	return {
		"accepted": accepted,
		"queued": queued,
		"reason_code": reason_code,
		"reason_diagnostics": reason_diagnostics,
		"queue_count": after_count,
		"queue_revision": int(after_state.get("revision", 0)),
		"new_queue_resolution_ids": new_resolution_ids.duplicate(),
		"queue_resolution_id": new_resolution_id,
		"actor": "local",
		"semantic_action_id": str(selected.get("semantic_action_id", "")),
		"card_semantic_id": str(selected.get("card_semantic_id", "")),
		"card_instance_id": str(selected.get("card_instance_id", "")),
		"hand_slot_id": str(selected.get("hand_slot_id", "")),
		"offer_pool_id": str(selected.get("pool_id", "")),
		"offer_fingerprint": str(selected.get("offer_fingerprint", "")),
		"target_fingerprint": str(selected.get("target_fingerprint", "")),
		"intent_fingerprint": str(intent.get("intent_fingerprint", "")),
		"receipt_fingerprint": str(receipt.get("receipt_fingerprint", "")),
		"receipt_request_bound": receipt_request_bound,
		"public_queue_transition": public_queue_transition,
		"exactly_one_new_queue_entry": exactly_one_new_entry,
		"stable_target_envelope_fingerprint": str(stable_target_envelope.get("envelope_fingerprint", "")),
		"same_logical_step": same_step,
		"card_resolution_advance_after_trigger": int(driver_after.get("tick_count", 0)) - int(driver_before.get("tick_count", 0)),
		"world_advance_after_trigger": _delta(before_observation, after_observation, "world_clock_advance_count"),
		"rng_draw_after_trigger": _delta(before_observation, after_observation, "rng_draw_invocation_count"),
	}


func _formal_hand_slot_index(hand_slot_id: String) -> int:
	const PREFIX := "hand.slot."
	if not hand_slot_id.begins_with(PREFIX):
		return -1
	var suffix := hand_slot_id.substr(PREFIX.length())
	return int(suffix) if suffix.is_valid_int() and int(suffix) >= 0 else -1


func _formal_dock_offer_pool_summary(dock: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for pool_spec in [
		{"pool_id": "normal_cards", "availability_field": "play_state"},
		{"pool_id": "commodity_cards", "availability_field": "play_state"},
		{"pool_id": "bound_actions", "availability_field": "enabled"},
	]:
		var pool_id := str(pool_spec.get("pool_id", ""))
		var availability_field := str(pool_spec.get("availability_field", ""))
		var rows: Array = dock.get(pool_id, []) if dock.get(pool_id, []) is Array else []
		var summary := {
			"total_count": rows.size(),
			"available_count": 0,
			"disabled_count": 0,
			"valid_available_offer_count": 0,
			"invalid_row_count": 0,
			"disabled_reason_counts": {},
		}
		for row_variant in rows:
			if not (row_variant is Dictionary):
				summary["invalid_row_count"] = int(summary.get("invalid_row_count", 0)) + 1
				continue
			var row := row_variant as Dictionary
			var available := bool(row.get(availability_field, false)) \
				if availability_field == "enabled" else str(row.get(availability_field, "")) == "available"
			var offer: Dictionary = row.get("game_action_offer", {}) \
				if row.get("game_action_offer", {}) is Dictionary else {}
			if available:
				summary["available_count"] = int(summary.get("available_count", 0)) + 1
				if bool(GAME_ACTION_OFFER.validation_report(offer).get("valid", false)) \
						and str(offer.get("legality_state", "")) == "available" \
						and str(offer.get("semantic_action_id", "")) == GAME_ACTION_INTENT.ACTION_CARD_PLAY:
					summary["valid_available_offer_count"] = int(
						summary.get("valid_available_offer_count", 0)
					) + 1
				continue
			summary["disabled_count"] = int(summary.get("disabled_count", 0)) + 1
			var disabled_reason_id := str(row.get("disabled_reason_id", "unknown"))
			var disabled_reasons: Dictionary = summary.get("disabled_reason_counts", {}) \
				if summary.get("disabled_reason_counts", {}) is Dictionary else {}
			disabled_reasons[disabled_reason_id] = int(disabled_reasons.get(disabled_reason_id, 0)) + 1
			summary["disabled_reason_counts"] = disabled_reasons
		result[pool_id] = summary
	return result


func _formal_public_queue_resolution_report(snapshot: Dictionary) -> Dictionary:
	var fields := ["current", "active", "next", "current_count", "active_present", "next_count"]
	if snapshot.size() != fields.size():
		return {"valid": false, "reason_code": "public_queue_fields_invalid"}
	for field_variant in fields:
		if not snapshot.has(str(field_variant)):
			return {"valid": false, "reason_code": "public_queue_fields_invalid"}
	if not (snapshot.get("current") is Array) or not (snapshot.get("active") is Dictionary) \
			or not (snapshot.get("next") is Array) \
			or typeof(snapshot.get("current_count")) != TYPE_INT \
			or not (snapshot.get("active_present") is bool) \
			or typeof(snapshot.get("next_count")) != TYPE_INT:
		return {"valid": false, "reason_code": "public_queue_shape_invalid"}
	var current := snapshot.get("current") as Array
	var active := snapshot.get("active") as Dictionary
	var next := snapshot.get("next") as Array
	if int(snapshot.get("current_count", -1)) != current.size() \
			or int(snapshot.get("next_count", -1)) != next.size() \
			or bool(snapshot.get("active_present", false)) != not active.is_empty():
		return {"valid": false, "reason_code": "public_queue_count_mismatch"}
	var entries: Array = []
	entries.append_array(current)
	if not active.is_empty():
		entries.append(active)
	entries.append_array(next)
	var public_entry_fields := [
		"resolution_id",
		"card_name",
		"card_kind",
		"selected_district",
		"group_id",
		"group_order",
		"group_size",
		"group_position",
		"queued_behind_resolution",
	]
	var resolution_ids: Dictionary = {}
	for entry_variant in entries:
		if not (entry_variant is Dictionary):
			return {"valid": false, "reason_code": "public_queue_entry_shape_invalid"}
		var entry := entry_variant as Dictionary
		if entry.size() != public_entry_fields.size():
			return {"valid": false, "reason_code": "public_queue_entry_fields_invalid"}
		for field_variant in public_entry_fields:
			if not entry.has(str(field_variant)):
				return {"valid": false, "reason_code": "public_queue_entry_fields_invalid"}
		if typeof(entry.get("resolution_id")) != TYPE_INT:
			return {"valid": false, "reason_code": "public_queue_resolution_id_invalid"}
		var resolution_id := int(entry.get("resolution_id", -1))
		if resolution_id < 0 or resolution_ids.has(resolution_id):
			return {"valid": false, "reason_code": "public_queue_resolution_id_invalid"}
		resolution_ids[resolution_id] = true
	return {
		"valid": true,
		"reason_code": "public_queue_valid",
		"count": resolution_ids.size(),
		"resolution_ids": resolution_ids,
	}


func _ai_state_digest(context: Dictionary) -> String:
	var coordinator := context.get("coordinator") as GameRuntimeCoordinator
	var handshake := context.get("handshake") as Node
	var ai := coordinator.get_node_or_null("AiRuntimeController") if coordinator != null else null
	var state: Dictionary = ai.call("to_save_data") if ai != null and ai.has_method("to_save_data") else {}
	var canonical := str(handshake.call("canonical_json", state)) if handshake != null and not state.is_empty() else ""
	return canonical.sha256_text() if not canonical.is_empty() else ""


func _prepare_legal_checkpoint(context: Dictionary) -> Dictionary:
	var coordinator := context.get("coordinator") as GameRuntimeCoordinator
	var main := context.get("main") as Node
	if coordinator == null or main == null:
		return {"ready": false, "reason_code": "legal_checkpoint_runtime_missing"}
	coordinator.pause_session()
	await process_frame
	var world := coordinator.world_session_state()
	var screen := main.find_child("RuntimeGameScreen", true, false) as SpaceSyndicateGameScreen
	var overlay := screen.get_node_or_null("OverlayLayer") as SpaceSyndicateOverlayLayer if screen != null else null
	var popup := screen.get_region_supply_popup() as SpaceSyndicateRegionSupplyPopup if screen != null else null
	var viewmodel_query := coordinator.get_node_or_null("TablePresentationViewModelQuery") as TablePresentationViewModelQuery
	var query_ports := coordinator.get_node_or_null("TablePresentationQueryPorts") as TablePresentationQueryPorts
	var district_port := coordinator.district_supply_action_port()
	var sushi_service := coordinator.get_node_or_null("CommoditySushiTrackRuntimeService")
	var infrastructure := coordinator.get_node_or_null("RegionInfrastructureRuntimeController") as RegionInfrastructureRuntimeController
	var flow := coordinator.commodity_flow_runtime_controller()
	if world == null or screen == null or overlay == null or popup == null \
			or viewmodel_query == null or query_ports == null or district_port == null \
			or sushi_service == null or infrastructure == null or flow == null:
		return {"ready": false, "reason_code": "legal_checkpoint_dependency_missing"}
	var actor_binding := coordinator.actor_id_for_player_index(0)
	var actor_id := str(actor_binding.get("actor_id", ""))
	var identity := coordinator.get_node_or_null("PlayerIdentityAuthorizationBoundary") as PlayerIdentityAuthorizationBoundary
	var actor_context := identity.current_actor_context(&"district_supply") if identity != null else null
	var viewer_context := query_ports.viewer_context()
	if not bool(actor_binding.get("available", false)) or actor_id.is_empty() \
			or actor_context == null or not actor_context.is_valid():
		return {"ready": false, "reason_code": "legal_checkpoint_actor_missing"}
	screen.bind_presentation_viewer(0, viewer_context.authorization_revision)
	screen.bind_gameplay_actor_authorization_context(actor_context)
	var initial_player := coordinator.v06_card_player_snapshot(actor_id)
	var protected_card_ids := _inventory_card_ids(initial_player)
	var track_snapshot: CommoditySushiTrackSnapshot = sushi_service.public_snapshot(0)
	var candidate := _legal_factory_queue_plan(
		coordinator,
		query_ports,
		infrastructure,
		flow,
		track_snapshot
	)
	if not bool(candidate.get("ready", false)):
		return {"ready": false, "reason_code": str(candidate.get("reason_code", "legal_factory_queue_plan_missing"))}
	var item := candidate.get("item") as CommoditySushiTrackItemSnapshot
	var commodity_card_id := str(item.commodity_card_id) if item != null else ""
	var asset_factory_card_id := str(candidate.get("asset_factory_card_id", ""))
	var supply_factory_card_id := str(candidate.get("supply_factory_card_id", ""))
	var queue_card_id := str(candidate.get("queue_card_id", ""))
	var asset_color := str(candidate.get("asset_color", ""))
	var asset_target: Dictionary = candidate.get("asset_factory_target", {}) \
		if candidate.get("asset_factory_target", {}) is Dictionary else {}
	var supply_target: Dictionary = candidate.get("supply_factory_target", {}) \
		if candidate.get("supply_factory_target", {}) is Dictionary else {}
	var asset_product_id := str(candidate.get("asset_product_id", ""))
	var supply_product_id := str(candidate.get("supply_product_id", ""))
	if item == null or commodity_card_id.is_empty() or asset_factory_card_id.is_empty() \
			or supply_factory_card_id.is_empty() or asset_target.is_empty() or supply_target.is_empty() \
			or asset_product_id.is_empty() or supply_product_id.is_empty() \
			or queue_card_id.is_empty() or not INDUSTRY_IDS.has(asset_color):
		return {"ready": false, "reason_code": "legal_factory_queue_plan_invalid"}
	var claim := _claim_track_item(sushi_service, track_snapshot, item, 1)
	if not bool(claim.get("success", false)):
		return {"ready": false, "reason_code": "legal_commodity_claim_failed"}
	for protected_id in [commodity_card_id, asset_factory_card_id, supply_factory_card_id, queue_card_id]:
		if not protected_card_ids.has(protected_id):
			protected_card_ids.append(protected_id)
	var receipts: Array[DistrictSupplyActionReceipt] = []
	district_port.receipt_ready.connect(func(receipt: DistrictSupplyActionReceipt) -> void:
		receipts.append(receipt)
	)
	var asset_purchase: Dictionary = await _purchase_with_legal_churn(
		coordinator,
		world,
		screen,
		overlay,
		popup,
		viewmodel_query,
		district_port,
		receipts,
		actor_id,
		asset_factory_card_id,
		protected_card_ids
	)
	if not bool(asset_purchase.get("completed", false)):
		return {"ready": false, "reason_code": "legal_asset_factory_purchase_failed"}
	var asset_play := await _play_facility_through_formal_submission(
		context,
		actor_id,
		asset_factory_card_id,
		str(asset_target.get("region_id", ""))
	)
	var asset_production := _matching_installation(
		flow,
		"production",
		asset_product_id,
		str(asset_target.get("region_id", "")),
		0
	)
	if not bool(asset_play.get("success", false)) or asset_production.is_empty():
		return {"ready": false, "reason_code": "legal_asset_factory_play_failed"}
	var supply_purchase_count := 0
	var same_factory := asset_factory_card_id == supply_factory_card_id \
		and str(asset_target.get("region_id", "")) == str(supply_target.get("region_id", ""))
	if not same_factory:
		var supply_purchase: Dictionary = await _purchase_with_legal_churn(
			coordinator,
			world,
			screen,
			overlay,
			popup,
			viewmodel_query,
			district_port,
			receipts,
			actor_id,
			supply_factory_card_id,
			protected_card_ids
		)
		if not bool(supply_purchase.get("completed", false)):
			return {"ready": false, "reason_code": "legal_supply_factory_purchase_failed"}
		supply_purchase_count = int(supply_purchase.get("purchase_count", 0))
		var supply_play := await _play_facility_through_formal_submission(
			context,
			actor_id,
			supply_factory_card_id,
			str(supply_target.get("region_id", ""))
		)
		if not bool(supply_play.get("success", false)):
			return {"ready": false, "reason_code": "legal_supply_factory_play_failed"}
	var supply_production := _matching_installation(
		flow,
		"production",
		supply_product_id,
		str(supply_target.get("region_id", "")),
		0
	)
	if supply_production.is_empty():
		return {"ready": false, "reason_code": "legal_supply_production_missing"}
	var queue_purchase: Dictionary = await _purchase_with_legal_churn(
		coordinator,
		world,
		screen,
		overlay,
		popup,
		viewmodel_query,
		district_port,
		receipts,
		actor_id,
		queue_card_id,
		protected_card_ids
	)
	if not bool(queue_purchase.get("completed", false)):
		return {"ready": false, "reason_code": "legal_queue_card_purchase_failed"}
	coordinator.resume_session()
	var sales := _advance_until_queue_ready(context, actor_id, supply_product_id, queue_card_id, asset_color)
	coordinator.pause_session()
	if int(sales.get("sale_receipt_count", 0)) <= 0 or not bool(sales.get("queue_ready", false)):
		return {"ready": false, "reason_code": str(sales.get("reason_code", "legal_sale_or_queue_missing"))}
	coordinator.request_table_presentation_refresh(&"full", &"cold_restore_legal_checkpoint")
	await process_frame
	await process_frame
	return {
		"ready": true,
		"reason_code": "legal_checkpoint_ready",
		"actor_id": actor_id,
		"queue_card_id": queue_card_id,
		"product_id": supply_product_id,
		"commodity_action_count": 1,
		"normal_card_purchase_count": int(asset_purchase.get("purchase_count", 0)) \
			+ supply_purchase_count + int(queue_purchase.get("purchase_count", 0)),
		"facility_action_count": 1 if same_factory else 2,
		"invalid_action_count": 0,
		"direct_authority_mutation_count": 0,
		"human_action_count": int(asset_purchase.get("purchase_count", 0)) \
			+ supply_purchase_count + int(queue_purchase.get("purchase_count", 0)) + (1 if same_factory else 2),
		"sales": sales.duplicate(true),
	}


func _queue_capable_card_plans(coordinator: GameRuntimeCoordinator) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if coordinator == null:
		return result
	var selection := ALPHA_CONTENT_LOADER.load_active_selection()
	if selection == null or not selection.is_valid():
		return result
	for card_id_variant in selection.region_supply_card_ids:
		var card_id := str(card_id_variant)
		var definition := coordinator.v06_card_definition(card_id)
		var machine: Dictionary = definition.get("machine", {}) \
			if definition.get("machine", {}) is Dictionary else {}
		var effect_kind := str(machine.get("effect_kind", ""))
		if not QUEUE_EFFECT_KINDS.has(effect_kind):
			continue
		var asset_cost: Dictionary = machine.get("asset_cost", {}) \
			if machine.get("asset_cost", {}) is Dictionary else {}
		var asset_color := ""
		var asset_amount := 0
		for color_variant in INDUSTRY_IDS:
			var color := str(color_variant)
			if float(asset_cost.get(color, 0)) > 0.0:
				asset_color = color
				asset_amount = int(asset_cost.get(color, 0))
				break
		var payload: Dictionary = machine.get("effect_payload", {}) \
			if machine.get("effect_payload", {}) is Dictionary else {}
		var required_route_tag := str(payload.get("required_route_tag", ""))
		var distance_rule := str(payload.get("distance_rule", ""))
		if card_id.is_empty() or asset_color.is_empty() or asset_amount <= 0 or required_route_tag.is_empty() \
				or distance_rule not in ["near_lte_2", "remote_gt_2"]:
			continue
		result.append({
			"card_id": card_id,
			"effect_kind": effect_kind,
			"asset_color": asset_color,
			"asset_amount": asset_amount,
			"required_route_tag": required_route_tag,
			"distance_rule": distance_rule,
		})
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("card_id", "")) < str(right.get("card_id", ""))
	)
	return result


func _legal_factory_queue_plan(
	coordinator: GameRuntimeCoordinator,
	query_ports: TablePresentationQueryPorts,
	infrastructure: RegionInfrastructureRuntimeController,
	flow: Object,
	track_snapshot: CommoditySushiTrackSnapshot
) -> Dictionary:
	if coordinator == null or query_ports == null or infrastructure == null or flow == null \
			or track_snapshot == null or not track_snapshot.is_valid() \
			or query_ports.region_infrastructure_public_query == null:
		return {"ready": false, "reason_code": "legal_factory_queue_plan_dependency_missing"}
	var claim_item: CommoditySushiTrackItemSnapshot = null
	for item_variant in track_snapshot.items:
		var item := item_variant as CommoditySushiTrackItemSnapshot
		if item != null and item.claimable:
			claim_item = item
			break
	if claim_item == null:
		return {"ready": false, "reason_code": "legal_commodity_claim_item_missing"}
	var facts_variant: Variant = query_ports.region_infrastructure_public_query.call("public_commodity_region_facts")
	var facts: Array = facts_variant if facts_variant is Array else []
	var routes := coordinator.get_node_or_null("RouteNetworkRuntimeController") as RouteNetworkRuntimeController
	if facts.is_empty() or routes == null:
		return {"ready": false, "reason_code": "legal_route_or_region_facts_missing"}
	var queue_plans := _queue_capable_card_plans(coordinator)
	if queue_plans.is_empty():
		return {"ready": false, "reason_code": "legal_queue_capability_catalog_empty"}
	var queue_candidates: Array[Dictionary] = []
	var asset_candidates_by_color: Dictionary = {}
	for plan in queue_plans:
		asset_candidates_by_color[str(plan.get("asset_color", ""))] = []
	for industry_id_variant in INDUSTRY_IDS:
		var industry_id := str(industry_id_variant)
		var factory_card_id := "facility.factory.%s.rank_1" % industry_id
		var allowed := _facility_allowed_states(coordinator.v06_card_definition(factory_card_id))
		var public_factory := query_ports.public_new_facility_target_candidates(&"factory", StringName(industry_id)).to_dictionary()
		var public_regions := _candidate_region_set(public_factory.get("candidates", []) as Array)
		for facts_row_variant in facts:
			if not (facts_row_variant is Dictionary):
				continue
			var facts_row := facts_row_variant as Dictionary
			var region_id := str(facts_row.get("region_id", ""))
			var product_id := _predicted_factory_product(facts_row, industry_id, flow)
			if region_id.is_empty() or product_id.is_empty() \
					or not _region_hosts_facility(infrastructure, region_id, "factory", industry_id, allowed):
				continue
			var target := {
				"region_id": region_id,
				"public_index": int(facts_row.get("legacy_index", -1)),
				"region_revision": int(facts_row.get("region_revision", 0)),
				"public_candidate": bool(public_regions.get(region_id, false)),
				"industry_id": industry_id,
				"factory_card_id": factory_card_id,
				"product_id": product_id,
			}
			if asset_candidates_by_color.has(industry_id) \
					and _public_demand_route_exists(flow, routes, product_id, region_id, "", "any"):
				(asset_candidates_by_color[industry_id] as Array).append(target.duplicate(true))
			for queue_plan in queue_plans:
				if not _public_demand_route_exists(
					flow,
					routes,
					product_id,
					region_id,
					str(queue_plan.get("required_route_tag", "")),
					str(queue_plan.get("distance_rule", ""))
				):
					continue
				var queue_target := target.duplicate(true)
				queue_target["queue_card_id"] = str(queue_plan.get("card_id", ""))
				queue_target["queue_effect_kind"] = str(queue_plan.get("effect_kind", ""))
				queue_target["asset_color"] = str(queue_plan.get("asset_color", ""))
				queue_candidates.append(queue_target)
	_sort_targets(queue_candidates)
	for color_variant in asset_candidates_by_color.keys():
		_sort_targets(asset_candidates_by_color[color_variant] as Array)
	if queue_candidates.is_empty():
		return {"ready": false, "reason_code": "legal_supply_demand_factory_target_missing"}
	var supply_target := queue_candidates[0]
	var asset_color := str(supply_target.get("asset_color", ""))
	var asset_candidates: Array = asset_candidates_by_color.get(asset_color, []) \
		if asset_candidates_by_color.get(asset_color, []) is Array else []
	var asset_target: Dictionary = supply_target.duplicate(true) \
		if str(supply_target.get("industry_id", "")) == asset_color \
		else ((asset_candidates[0] as Dictionary).duplicate(true) if not asset_candidates.is_empty() else {})
	if asset_target.is_empty():
		return {"ready": false, "reason_code": "legal_queue_asset_factory_target_missing"}
	return {
		"ready": true,
		"reason_code": "legal_factory_queue_plan_ready",
		"item": claim_item,
		"asset_factory_card_id": str(asset_target.get("factory_card_id", "")),
		"asset_factory_target": asset_target.duplicate(true),
		"asset_product_id": str(asset_target.get("product_id", "")),
		"supply_factory_card_id": str(supply_target.get("factory_card_id", "")),
		"supply_factory_target": supply_target.duplicate(true),
		"supply_product_id": str(supply_target.get("product_id", "")),
		"queue_card_id": str(supply_target.get("queue_card_id", "")),
		"asset_color": asset_color,
	}


func _public_demand_route_exists(
	flow: Object,
	routes: RouteNetworkRuntimeController,
	product_id: String,
	source_region_id: String,
	required_mode: String,
	distance_rule: String
) -> bool:
	var installations_variant: Variant = flow.call("installations_snapshot", false)
	var installations: Array = installations_variant if installations_variant is Array else []
	for installation_variant in installations:
		if not (installation_variant is Dictionary):
			continue
		var demand := installation_variant as Dictionary
		if not bool(demand.get("active", false)) \
				or str(demand.get("direction", "")) != "demand" \
				or str(demand.get("commodity_id", "")) != product_id:
			continue
		for route_variant in routes.route_candidates_for_regions(
			product_id,
			source_region_id,
			str(demand.get("region_id", ""))
		):
			if not (route_variant is Dictionary):
				continue
			var route := route_variant as Dictionary
			var distance := int(route.get("shortest_legal_distance", -1))
			var distance_matches := distance >= 0 if distance_rule == "any" \
				else (distance > 2 if distance_rule == "remote_gt_2" else distance >= 0 and distance <= 2)
			var mode_matches := required_mode.is_empty() or (route.get("mode_tags", []) as Array).has(required_mode)
			if distance_matches and mode_matches and int(route.get("bottleneck_units_per_minute", 0)) > 0:
				return true
	return false


func _matching_specific_target_pair(
	routes: RouteNetworkRuntimeController,
	product_id: String,
	factory_targets: Array[Dictionary],
	market_targets: Array[Dictionary],
	required_mode: String,
	distance_rule: String
) -> Dictionary:
	if routes == null or product_id.is_empty() or required_mode.is_empty() \
			or distance_rule not in ["near_lte_2", "remote_gt_2"]:
		return {}
	for factory_target in factory_targets:
		for market_target in market_targets:
			var source_region_id := str(factory_target.get("region_id", ""))
			var market_region_id := str(market_target.get("region_id", ""))
			if source_region_id.is_empty() or market_region_id.is_empty() or source_region_id == market_region_id:
				continue
			for route_variant in routes.route_candidates_for_regions(product_id, source_region_id, market_region_id):
				if not (route_variant is Dictionary):
					continue
				var route := route_variant as Dictionary
				var distance := int(route.get("shortest_legal_distance", -1))
				var distance_matches := distance > 2 if distance_rule == "remote_gt_2" \
					else distance >= 0 and distance <= 2
				if distance_matches and (route.get("mode_tags", []) as Array).has(required_mode) \
						and int(route.get("bottleneck_units_per_minute", 0)) > 0:
					return {
						"factory_target": factory_target.duplicate(true),
						"market_target": market_target.duplicate(true),
						"route": {
							"route_id": str(route.get("route_id", "")),
							"mode_tags": (route.get("mode_tags", []) as Array).duplicate(),
							"shortest_legal_distance": distance,
							"topology_revision": str(route.get(
								"topology_revision",
								route.get("region_revision_fingerprint", "")
							)),
							"bottleneck_units_per_minute": int(route.get("bottleneck_units_per_minute", 0)),
						},
					}
	return {}


func _facility_allowed_states(definition: Dictionary) -> Array:
	var machine: Dictionary = definition.get("machine", {}) if definition.get("machine", {}) is Dictionary else {}
	var payload: Dictionary = machine.get("effect_payload", {}) if machine.get("effect_payload", {}) is Dictionary else {}
	return (payload.get("allowed_region_states", []) as Array).duplicate() \
		if payload.get("allowed_region_states", []) is Array else []


func _candidate_region_set(candidates: Array) -> Dictionary:
	var result := {}
	for candidate_variant in candidates:
		if candidate_variant is Dictionary:
			result[str((candidate_variant as Dictionary).get("region_id", ""))] = true
	return result


func _region_hosts_facility(
	infrastructure: RegionInfrastructureRuntimeController,
	region_id: String,
	facility_kind: String,
	industry_id: String,
	allowed_states: Array
) -> bool:
	var region := infrastructure.region_snapshot(region_id)
	var slot_id := infrastructure.slot_id(region_id, facility_kind, industry_id)
	if region.is_empty() or slot_id.is_empty() \
			or not allowed_states.has(str(region.get("lifecycle_state", ""))) \
			or not (region.get("facility_slot_ids", []) as Array).has(slot_id):
		return false
	for facility_variant in region.get("facilities", []) as Array:
		if facility_variant is Dictionary and bool((facility_variant as Dictionary).get("active", false)) \
				and str((facility_variant as Dictionary).get("slot_id", "")) == slot_id:
			return false
	return true


func _predicted_factory_product(region_facts: Dictionary, industry_id: String, flow: Object) -> String:
	var fallback := ""
	for product_variant in region_facts.get("production_products", []) as Array:
		if not (product_variant is Dictionary) or str((product_variant as Dictionary).get("industry_id", "")) != industry_id:
			continue
		var product_id := str((product_variant as Dictionary).get("product_id", ""))
		if product_id.is_empty():
			continue
		if fallback.is_empty():
			fallback = product_id
		if _active_public_demand_exists(flow, product_id):
			return product_id
	return fallback


func _active_public_demand_exists(flow: Object, product_id: String) -> bool:
	var installations_variant: Variant = flow.call("installations_snapshot", false)
	var installations: Array = installations_variant if installations_variant is Array else []
	for installation_variant in installations:
		if installation_variant is Dictionary:
			var installation := installation_variant as Dictionary
			if bool(installation.get("active", false)) \
					and str(installation.get("owner_kind", "")) == "public" \
					and str(installation.get("direction", "")) == "demand" \
					and str(installation.get("commodity_id", "")) == product_id:
				return true
	return false


func _sort_targets(targets: Array) -> void:
	targets.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_score := 1 if bool(left.get("public_candidate", false)) else 0
		var right_score := 1 if bool(right.get("public_candidate", false)) else 0
		if left_score != right_score:
			return left_score > right_score
		var left_index := int(left.get("public_index", -1))
		var right_index := int(right.get("public_index", -1))
		if left_index != right_index:
			return left_index < right_index
		var left_region := str(left.get("region_id", ""))
		var right_region := str(right.get("region_id", ""))
		return left_region < right_region if left_region != right_region \
			else str(left.get("queue_card_id", "")) < str(right.get("queue_card_id", ""))
	)


func _claim_track_item(
	sushi_service: Object,
	track_snapshot: CommoditySushiTrackSnapshot,
	item: CommoditySushiTrackItemSnapshot,
	request_revision: int
) -> Dictionary:
	if sushi_service == null or track_snapshot == null or item == null:
		return {"success": false, "reason_code": "claim_dependency_missing"}
	var request: CLAIM_REQUEST = CLAIM_REQUEST.new()
	request.viewer_index = 0
	request.commodity_slot_id = item.commodity_slot_id
	request.commodity_card_id = item.commodity_card_id
	request.snapshot_revision = track_snapshot.snapshot_revision
	request.belt_revision = track_snapshot.belt_revision
	request.visibility_revision = track_snapshot.visibility_revision
	request.request_revision = maxi(1, request_revision)
	var value_variant: Variant = sushi_service.call("claim", request)
	return (value_variant as Dictionary).duplicate(true) if value_variant is Dictionary else {
		"success": false,
		"reason_code": "claim_receipt_invalid",
	}


func _claim_first_visible_commodity(context: Dictionary, request_revision: int) -> Dictionary:
	var coordinator := context.get("coordinator") as GameRuntimeCoordinator
	var sushi_service := coordinator.get_node_or_null("CommoditySushiTrackRuntimeService") if coordinator != null else null
	var snapshot: CommoditySushiTrackSnapshot = sushi_service.public_snapshot(0) if sushi_service != null else null
	if snapshot == null or not snapshot.is_valid():
		return {"success": false, "reason_code": "commodity_track_unavailable"}
	for item_variant in snapshot.items:
		var item := item_variant as CommoditySushiTrackItemSnapshot
		if item != null and item.claimable:
			var result := _claim_track_item(sushi_service, snapshot, item, request_revision)
			result["commodity_card_id"] = str(item.commodity_card_id) if bool(result.get("success", false)) else ""
			return result
	return {"success": false, "reason_code": "commodity_track_empty"}


func _purchase_with_legal_churn(
	coordinator: GameRuntimeCoordinator,
	world: WorldSessionState,
	screen: SpaceSyndicateGameScreen,
	overlay: SpaceSyndicateOverlayLayer,
	popup: SpaceSyndicateRegionSupplyPopup,
	viewmodel_query: TablePresentationViewModelQuery,
	port: DistrictSupplyActionPort,
	receipts: Array[DistrictSupplyActionReceipt],
	actor_id: String,
	target_card_id: String,
	protected_card_ids: Array,
	preferred_churn_district: int = -1,
	strict_preferred_district: bool = false
) -> Dictionary:
	var purchase_count := 0
	for _attempt in range(MAX_SUPPLY_CHURN):
		var player := coordinator.v06_card_player_snapshot(actor_id)
		if _inventory_has_card(player, target_card_id):
			return {
				"completed": true,
				"reason_code": "target_already_owned",
				"purchase_count": purchase_count,
				"source_district_index": -1,
			}
		var visible_target_district := _purchasable_listing_district(
			coordinator,
			world,
			target_card_id,
			preferred_churn_district,
			strict_preferred_district
		)
		var purchase_card_id := target_card_id
		var purchase_district := visible_target_district
		if visible_target_district < 0:
			var filler := _lowest_visible_purchasable_filler(
				coordinator,
				world,
				protected_card_ids,
				preferred_churn_district
			)
			purchase_card_id = str(filler.get("card_id", ""))
			purchase_district = int(filler.get("district_index", -1))
		if purchase_card_id.is_empty():
			return {
				"completed": false,
				"reason_code": "legal_supply_churn_exhausted",
				"purchase_count": purchase_count,
				"source_district_index": -1,
			}
		var discard_slot := -1
		if _inventory_card_count(player) >= CardFlowPolicyV06.HAND_LIMIT:
			discard_slot = _first_disposable_inventory_slot(player, protected_card_ids)
			if discard_slot < 0:
				return {"completed": false, "reason_code": "legal_supply_discard_unavailable", "purchase_count": purchase_count}
		var purchase: Dictionary = await _purchase_from_authoritative_region_supply_port(
			coordinator,
			world,
			port,
			purchase_card_id,
			discard_slot,
			purchase_district
		)
		if not bool(purchase.get("completed", false)):
			return {
				"completed": false,
				"reason_code": str(purchase.get("failure", "legal_supply_purchase_failed")),
				"purchase_count": purchase_count,
			}
		purchase_count += 1
		if purchase_card_id == target_card_id:
			return {
				"completed": true,
				"reason_code": "legal_supply_target_found",
				"purchase_count": purchase_count,
				"source_district_index": purchase_district,
			}
	return {
		"completed": _inventory_has_card(coordinator.v06_card_player_snapshot(actor_id), target_card_id),
		"reason_code": "legal_supply_target_found" if _inventory_has_card(coordinator.v06_card_player_snapshot(actor_id), target_card_id) else "legal_supply_churn_limit",
		"purchase_count": purchase_count,
		"source_district_index": -1,
	}


func _lowest_visible_purchasable_filler(
	coordinator: GameRuntimeCoordinator,
	world: WorldSessionState,
	protected_card_ids: Array,
	preferred_district: int = -1
) -> Dictionary:
	if preferred_district < 0:
		for district_index in range(world.districts.size()):
			if not (world.districts[district_index] is Dictionary) \
					or not bool(coordinator.card_market_listing_availability(district_index).get("purchasable", false)):
				continue
			var region_id := str((world.districts[district_index] as Dictionary).get("region_id", ""))
			for card_id_variant in coordinator.region_supply_card_ids(region_id):
				var card_id := str(card_id_variant)
				if not card_id.is_empty() and not protected_card_ids.has(card_id):
					return {"card_id": card_id, "district_index": district_index}
		return {}
	var district_indices: Array[int] = []
	district_indices.append(preferred_district)
	var candidates: Array[Dictionary] = []
	for district_index in district_indices:
		if district_index < 0 or district_index >= world.districts.size():
			continue
		if not (world.districts[district_index] is Dictionary) \
				or not bool(coordinator.card_market_listing_availability(district_index).get("purchasable", false)):
			continue
		var region_id := str((world.districts[district_index] as Dictionary).get("region_id", ""))
		for card_id_variant in coordinator.region_supply_card_ids(region_id):
			var card_id := str(card_id_variant)
			if card_id.is_empty() or protected_card_ids.has(card_id):
				continue
			var listing := coordinator.region_supply_listing(region_id, card_id)
			if listing.is_empty():
				continue
			candidates.append({
				"card_id": card_id,
				"district_index": district_index,
				"price_cash": maxi(0, int(listing.get("price_cash", 0))),
			})
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_price := int(left.get("price_cash", 0))
		var right_price := int(right.get("price_cash", 0))
		if left_price != right_price:
			return left_price < right_price
		var left_card_id := str(left.get("card_id", ""))
		var right_card_id := str(right.get("card_id", ""))
		if left_card_id != right_card_id:
			return left_card_id < right_card_id
		return int(left.get("district_index", -1)) < int(right.get("district_index", -1))
	)
	return candidates[0].duplicate(true) if not candidates.is_empty() else {}


func _first_disposable_inventory_slot(player_snapshot: Dictionary, protected_card_ids: Array) -> int:
	var inventory: Dictionary = player_snapshot.get("inventory", {}) \
		if player_snapshot.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	for slot_index in range(slots.size()):
		if not (slots[slot_index] is Dictionary):
			continue
		var machine: Dictionary = (slots[slot_index] as Dictionary).get("machine", {}) \
			if (slots[slot_index] as Dictionary).get("machine", {}) is Dictionary else {}
		var card_id := str(machine.get("card_id", ""))
		if not card_id.is_empty() and not protected_card_ids.has(card_id):
			return slot_index
	return -1


func _purchase_from_authoritative_region_supply_port(
	coordinator: GameRuntimeCoordinator,
	world: WorldSessionState,
	port: DistrictSupplyActionPort,
	card_id: String,
	discard_slot: int,
	preferred_district: int
) -> Dictionary:
	var result := {"completed": false, "failure": "purchase_not_started"}
	var district_index := _purchasable_listing_district(
		coordinator,
		world,
		card_id,
		preferred_district,
		true
	)
	if district_index < 0 or port == null:
		result["failure"] = "purchasable_listing_or_selection_missing"
		return result
	var open_receipt := port.submit_current_actor_action(
		DISTRICT_SUPPLY_ACTION_INTENT.KIND_OPEN,
		district_index,
		"",
		-1,
		&"district_supply"
	)
	if open_receipt == null or not open_receipt.accepted:
		result["failure"] = "typed_region_supply_open_rejected"
		return result
	var quote_receipt := port.submit_current_actor_action(
		DISTRICT_SUPPLY_ACTION_INTENT.KIND_QUOTE,
		district_index,
		card_id,
		-1,
		&"district_supply"
	)
	if quote_receipt == null or not quote_receipt.accepted \
			or quote_receipt.reason_code != "quote_locked" \
			or quote_receipt.quote_id.is_empty():
		result["failure"] = "quote_rejected"
		return result
	var purchase_receipt := _submit_locked_region_supply_purchase(
		coordinator,
		port,
		district_index,
		card_id,
		quote_receipt.quote_id
	)
	if purchase_receipt == null:
		result["failure"] = "purchase_receipt_missing"
		return result
	var terminal_receipt := purchase_receipt
	if purchase_receipt.requires_discard:
		if discard_slot < 0:
			result["failure"] = "discard_slot_missing"
			return result
		terminal_receipt = port.submit_current_actor_action(
			DISTRICT_SUPPLY_ACTION_INTENT.KIND_DISCARD_CONFIRM,
			-1,
			"",
			discard_slot,
			&"district_supply"
		)
	if terminal_receipt == null:
		result["failure"] = "terminal_purchase_receipt_missing"
		return result
	result["completed"] = terminal_receipt.accepted and terminal_receipt.applied \
		and terminal_receipt.reason_code == "purchase_committed"
	result["failure"] = "" if bool(result.get("completed", false)) else terminal_receipt.reason_code
	return result


func _submit_locked_region_supply_purchase(
	coordinator: GameRuntimeCoordinator,
	port: DistrictSupplyActionPort,
	district_index: int,
	card_id: String,
	quote_id: String
) -> DistrictSupplyActionReceipt:
	var identity := coordinator.get_node_or_null("PlayerIdentityAuthorizationBoundary") \
		as PlayerIdentityAuthorizationBoundary if coordinator != null else null
	var actor_context := identity.current_actor_context(&"district_supply") \
		if identity != null else null
	if port == null or actor_context == null or not actor_context.is_valid() \
			or district_index < 0 or card_id.is_empty() or quote_id.is_empty():
		return null
	_district_supply_request_revision += 1
	var intent := DISTRICT_SUPPLY_ACTION_INTENT.new()
	intent.request_id = "cold-restore-district-supply:%d:%d" % [
		actor_context.authorized_actor_player_index,
		_district_supply_request_revision,
	]
	intent.action_kind = DISTRICT_SUPPLY_ACTION_INTENT.KIND_PURCHASE
	intent.actor_player_index = actor_context.authorized_actor_player_index
	intent.authorization_revision = actor_context.authorization_revision
	intent.session_id = actor_context.session_id
	intent.session_revision = actor_context.session_revision
	intent.district_index = district_index
	intent.card_id = card_id
	intent.discard_slot = -1
	intent.locked_quote_id = quote_id
	intent.source_surface = &"district_supply"
	intent.request_revision = _district_supply_request_revision
	return port.submit_intent(intent)


func _purchasable_listing_district(
	coordinator: GameRuntimeCoordinator,
	world: WorldSessionState,
	card_id: String,
	preferred_district: int,
	strict_preferred_district: bool = false
) -> int:
	var ordered: Array[int] = []
	if preferred_district >= 0:
		ordered.append(preferred_district)
	if not strict_preferred_district or preferred_district < 0:
		for district_index in range(world.districts.size()):
			if not ordered.has(district_index):
				ordered.append(district_index)
	for district_index in ordered:
		if district_index < 0 or district_index >= world.districts.size() \
				or not (world.districts[district_index] is Dictionary):
			continue
		var region_id := str((world.districts[district_index] as Dictionary).get("region_id", ""))
		if not coordinator.region_supply_listing(region_id, card_id).is_empty() \
				and bool(coordinator.card_market_listing_availability(district_index).get("purchasable", false)):
			return district_index
	return -1


func _play_facility_through_formal_submission(
	context: Dictionary,
	actor_id: String,
	card_id: String,
	region_id: String
) -> Dictionary:
	var coordinator := context.get("coordinator") as GameRuntimeCoordinator
	if coordinator == null:
		return {"success": false, "reason_code": "facility_formal_coordinator_missing"}
	var actor_binding := coordinator.actor_id_for_player_index(0)
	if not bool(actor_binding.get("available", false)) \
			or str(actor_binding.get("actor_id", "")) != actor_id:
		return {"success": false, "reason_code": "facility_formal_actor_binding_changed"}
	var adapter := coordinator.facility_card_queue_adapter_v06()
	if adapter == null:
		return {"success": false, "reason_code": "facility_formal_queue_adapter_missing"}
	if not _select_exact_region(context, region_id, "facility-formal-target"):
		return {"success": false, "reason_code": "facility_formal_target_selection_failed"}
	coordinator.resume_session()
	coordinator.request_table_presentation_refresh(&"full", &"cold_restore_facility_offer_sync")
	await process_frame
	await process_frame
	var adapter_before := adapter.debug_snapshot()
	var queue_count_before := _queue_entry_count(context)
	var queued := _submit_first_formal_queue_offer(context, card_id, region_id)
	var queue := coordinator.get_node_or_null("CardResolutionQueueRuntimeService") \
		as CardResolutionQueueRuntimeService
	var queued_entry := queue.entry_by_id(int(queued.get("queue_resolution_id", -1))) \
		if queue != null and int(queued.get("queue_resolution_id", -1)) >= 0 else {}
	var queued_binding: Dictionary = queued_entry.get("v06_facility_action", {}) \
		if queued_entry.get("v06_facility_action", {}) is Dictionary else {}
	var queued_target: Dictionary = queued_binding.get("prebound_target", {}) \
		if queued_binding.get("prebound_target", {}) is Dictionary else {}
	var queued_ok := bool(queued.get("accepted", false)) \
		and bool(queued.get("queued", false)) \
		and int(queued.get("queue_resolution_id", -1)) >= 0 \
		and str(queued_target.get("region_id", "")) == region_id \
		and queue_count_before == 0 \
		and _queue_entry_count(context) == 1
	var resolution_step: Dictionary = {}
	if queued_ok:
		resolution_step = coordinator.advance_card_resolution_frame(0.0)
	var adapter_after := adapter.debug_snapshot()
	var resolved_once := int(adapter_after.get("resolution_count", 0)) \
		== int(adapter_before.get("resolution_count", 0)) + 1
	var queue_empty := _queue_entry_count(context) == 0
	return {
		"success": queued_ok and resolved_once and queue_empty,
		"reason_code": "facility_formal_queue_resolved" if queued_ok and resolved_once and queue_empty \
			else str(queued.get("reason_code", "facility_formal_queue_resolution_failed")),
		"public_result": {
			"success": queued_ok and resolved_once and queue_empty,
			"failure_code": "" if queued_ok and resolved_once and queue_empty \
				else str(queued.get("reason_code", "facility_formal_queue_resolution_failed")),
		},
		"receipt": queued.duplicate(true),
		"resolution_step": resolution_step.duplicate(true),
		"adapter_resolution_delta": int(adapter_after.get("resolution_count", 0)) \
			- int(adapter_before.get("resolution_count", 0)),
		"queue_count_before": queue_count_before,
		"queue_count_after": _queue_entry_count(context),
	}


func _matching_installation(
	flow: Object,
	direction: String,
	product_id: String,
	region_id: String,
	player_index: int
) -> Dictionary:
	var installations_variant: Variant = flow.call("installations_snapshot", false)
	var installations: Array = installations_variant if installations_variant is Array else []
	for installation_variant in installations:
		if not (installation_variant is Dictionary):
			continue
		var installation := installation_variant as Dictionary
		if bool(installation.get("active", false)) \
				and str(installation.get("direction", "")) == direction \
				and str(installation.get("commodity_id", "")) == product_id \
				and str(installation.get("region_id", "")) == region_id \
				and str(installation.get("owner_kind", "")) == "player" \
				and int(installation.get("installer_player_index", -1)) == player_index:
			return installation.duplicate(true)
	return {}


func _advance_until_queue_ready(
	context: Dictionary,
	actor_id: String,
	product_id: String,
	queue_card_id: String,
	asset_color: String
) -> Dictionary:
	var coordinator := context.get("coordinator") as GameRuntimeCoordinator
	var mana := coordinator.get_node_or_null("PlayerManaRuntimeController") as PlayerManaRuntimeController
	var before_receipts := coordinator.commodity_flow_recent_receipts(-1)
	var baseline_ids := _sale_receipt_id_set(before_receipts)
	var observed_new: Dictionary = {}
	var owned_sale_count := 0
	var any_advanced := false
	var last_reason := ""
	var queue_ready := false
	var available_queue_assets := 0
	for _second in range(MAX_SALE_SECONDS):
		coordinator.advance_runtime_world_time(1.0)
		var advanced := coordinator.advance_commodity_flow(1.0, {})
		any_advanced = any_advanced or bool(advanced.get("advanced", false))
		last_reason = str(advanced.get("reason", advanced.get("reason_code", "")))
		var receipts := coordinator.commodity_flow_recent_receipts(-1)
		for receipt_variant in receipts:
			if not (receipt_variant is Dictionary):
				continue
			var receipt := receipt_variant as Dictionary
			var receipt_id := str(receipt.get("receipt_id", ""))
			if not receipt_id.is_empty() and not baseline_ids.has(receipt_id):
				observed_new[receipt_id] = receipt.duplicate(true)
		owned_sale_count = _matching_sale_count(observed_new.values(), 0, product_id, 0)
		var player := coordinator.v06_card_player_snapshot(actor_id)
		var queue_slot := _inventory_slot_for_card(player, queue_card_id)
		if queue_slot >= 0:
			var card := _inventory_card_at(player, queue_slot)
			var preflight := coordinator.preflight_v06_automatic_supply_demand(actor_id, card)
			queue_ready = bool(preflight.get("ready", false))
			last_reason = str(preflight.get("reason_code", last_reason))
		var availability := mana.availability_snapshot(0) if mana != null else {}
		var assets: Dictionary = availability.get("assets", {}) if availability.get("assets", {}) is Dictionary else {}
		available_queue_assets = int(assets.get(asset_color, 0))
		if not observed_new.is_empty() and owned_sale_count > 0 and queue_ready and available_queue_assets >= 2:
			break
	return {
		"advanced": any_advanced,
		"sale_receipt_count": observed_new.size(),
		"owned_sale_receipt_count": owned_sale_count,
		"queue_ready": queue_ready and available_queue_assets >= 2 and owned_sale_count > 0,
		"available_queue_assets": available_queue_assets,
		"reason_code": "legal_sale_and_queue_ready" \
			if not observed_new.is_empty() and owned_sale_count > 0 and queue_ready and available_queue_assets >= 2 \
			else ("legal_flow_advance_blocked" if not any_advanced \
			else ("legal_sale_receipt_missing" if observed_new.is_empty() \
			else ("legal_supply_owned_gdp_missing" if owned_sale_count <= 0 \
			else ("legal_queue_assets_missing" if available_queue_assets < 2 else "legal_supply_preflight_missing")))),
		"internal_reason": last_reason,
	}


func _matching_sale_count(receipts: Array, start_index: int, product_id: String, player_index: int) -> int:
	var count := 0
	for index in range(maxi(0, start_index), receipts.size()):
		if receipts[index] is Dictionary \
				and str((receipts[index] as Dictionary).get("commodity_id", "")) == product_id \
				and int((receipts[index] as Dictionary).get("commodity_owner", -1)) == player_index \
				and int((receipts[index] as Dictionary).get("owner_net_cash", 0)) > 0:
			count += 1
	return count


func _advance_sale(context: Dictionary, seconds: float) -> Dictionary:
	var coordinator: GameRuntimeCoordinator = context.get("coordinator")
	var baseline_ids := _sale_receipt_id_set(coordinator.commodity_flow_recent_receipts(-1))
	var observed_ids: Dictionary = {}
	var advanced := {"advanced": false}
	for _second in range(maxi(1, ceili(seconds))):
		coordinator.advance_runtime_world_time(1.0)
		advanced = coordinator.advance_commodity_flow(1.0, {})
		for receipt_variant in coordinator.commodity_flow_recent_receipts(-1):
			if receipt_variant is Dictionary:
				var receipt_id := str((receipt_variant as Dictionary).get("receipt_id", ""))
				if not receipt_id.is_empty() and not baseline_ids.has(receipt_id):
					observed_ids[receipt_id] = true
	return {
		"advanced": bool(advanced.get("advanced", false)),
		"sale_receipt_count": observed_ids.size(),
	}


func _sale_receipt_id_set(receipts: Array) -> Dictionary:
	var result: Dictionary = {}
	for receipt_variant in receipts:
		if receipt_variant is Dictionary:
			var receipt_id := str((receipt_variant as Dictionary).get("receipt_id", ""))
			if not receipt_id.is_empty():
				result[receipt_id] = true
	return result


func _tick_ai_until_action(context: Dictionary, max_ticks: int) -> int:
	var coordinator := context.get("coordinator") as GameRuntimeCoordinator
	var runtime_loop := coordinator.get_node_or_null("RuntimeLoop") as RuntimeLoop \
		if coordinator != null else null
	if coordinator == null or runtime_loop == null:
		return 0
	var before := int(_safety_observation(context).get("ai_action_submission_count", 0))
	var lease := TERMINAL_EVIDENCE.acquire_manual_lease(context)
	if not bool(lease.get("accepted", false)):
		return 0
	for _index in range(maxi(1, max_ticks)):
		var step := AUTHORITATIVE_STEPPER.advance_bounded(runtime_loop, 0.5, 1)
		if not bool(step.get("accepted", false)):
			break
		if int(_safety_observation(context).get("ai_action_submission_count", 0)) > before:
			break
	var action_count := maxi(
		0,
		int(_safety_observation(context).get("ai_action_submission_count", 0)) - before
	)
	var release := TERMINAL_EVIDENCE.release_manual_lease(context)
	return action_count if bool(release.get("released", false)) else 0


func _finish_to_settlement(context: Dictionary) -> Dictionary:
	var lease := TERMINAL_EVIDENCE.acquire_manual_lease(context)
	if not bool(lease.get("accepted", false)):
		return {
			"settled": false,
			"failure_code": str(lease.get("reason_code", "terminal_manual_lease_rejected")),
			"victory_state_sequence": [],
			"settlement_count": 0,
			"presentation_count": 0,
			"public_log_count": 0,
			"quiet_frames": 0,
			"world_delta": -1,
			"rng_delta": -1,
		}
	var lease_frame := int(lease.get("frame_index", -1))
	var lifecycle_settle_limit := int(TERMINAL_EVIDENCE.contract_snapshot().get(
		"generation_two_lifecycle_settle_frame_limit",
		0
	))
	var idle_gate: Dictionary = {}
	for _settle_frame in range(lifecycle_settle_limit):
		# The manual lease keeps RuntimeLoop stopped while save observers finish
		# their call_deferred lifecycle checkpoint cleanup.
		await process_frame
		idle_gate = TERMINAL_EVIDENCE.generation_two_idle_gate(context, lease_frame)
		if bool(idle_gate.get("accepted", false)) \
				or str(idle_gate.get("reason_code", "")) \
				!= "generation_two_lifecycle_checkpoint_pending":
			break
	if not bool(idle_gate.get("accepted", false)):
		TERMINAL_EVIDENCE.release_manual_lease(context)
		return {
			"settled": false,
			"failure_code": str(idle_gate.get(
				"reason_code",
				"generation_two_idle_gate_rejected"
			)),
			"victory_state_sequence": [],
			"settlement_count": 0,
			"presentation_count": 0,
			"public_log_count": 0,
			"quiet_frames": 0,
			"world_delta": -1,
			"rng_delta": -1,
		}
	return await TERMINAL_EVIDENCE.finish_to_settlement(self, context, lease_frame)


func _checkpoint_summary(context: Dictionary) -> Dictionary:
	var main := context.get("main") as Node
	var coordinator := context.get("coordinator") as GameRuntimeCoordinator
	if main == null or coordinator == null:
		return {}
	var dock := main.get_node_or_null("RuntimeGameScreen/SafeArea/MainRows/PlayerCardDock")
	var roster := main.get_node_or_null("RuntimeGameScreen/SafeArea/MainRows/TableArea/PlayerRosterPanel")
	var map_view := main.get_node_or_null("RuntimeGameScreen/SafeArea/MainRows/TableArea/PlanetBoard/PlanetRows/PlanetStageViewport/MapHost/PlanetMapView")
	var dock_debug: Dictionary = dock.debug_snapshot() if dock != null and dock.has_method("debug_snapshot") else {}
	var roster_debug: Dictionary = roster.debug_snapshot() if roster != null and roster.has_method("debug_snapshot") else {}
	var map_debug: Dictionary = map_view.get_sceneization_debug_snapshot() if map_view != null and map_view.has_method("get_sceneization_debug_snapshot") else {}
	var infrastructure := coordinator.get_node_or_null("RegionInfrastructureRuntimeController") as RegionInfrastructureRuntimeController
	var routes := coordinator.get_node_or_null("RouteNetworkRuntimeController") as RouteNetworkRuntimeController
	var military := coordinator.get_node_or_null("MilitaryRuntimeController") as MilitaryRuntimeController
	var queue := coordinator.get_node_or_null("CardResolutionQueueRuntimeService") as CardResolutionQueueRuntimeService
	var weather := coordinator.get_node_or_null("WeatherRuntimeController") as WeatherRuntimeController
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController
	var victory := coordinator.get_node_or_null("VictoryControlRuntimeController") as VictoryControlRuntimeController
	var inventory := coordinator.commodity_card_inventory_runtime_controller()
	var route_snapshot: Dictionary = routes.public_cached_route_snapshot() if routes != null else {}
	var queue_snapshot: Dictionary = queue.public_snapshot() if queue != null else {}
	var weather_public: Dictionary = weather.public_snapshot() if weather != null else {}
	var ai_save: Dictionary = ai.to_save_data() if ai != null else {}
	var victory_debug: Dictionary = victory.debug_snapshot() if victory != null else {}
	var journal: Dictionary = inventory.transaction_journal_snapshot() if inventory != null else {}
	var claim_count := 0
	for record_variant in journal.values():
		if not (record_variant is Dictionary):
			continue
		var result_variant: Variant = (record_variant as Dictionary).get("result", {})
		if result_variant is Dictionary and str((result_variant as Dictionary).get("operation", "")) == "belt_claim" \
				and bool((result_variant as Dictionary).get("committed", false)):
			claim_count += 1
	var nondefault_ai := 0
	for player_variant in ai_save.get("player_states", []) as Array:
		if player_variant is Dictionary and _ai_memory_has_activity((player_variant as Dictionary).get("ai_memory", {}) as Dictionary):
			nondefault_ai += 1
	var queue_count := int(queue_snapshot.get("current_count", 0)) + int(queue_snapshot.get("next_count", 0)) \
		+ (1 if bool(queue_snapshot.get("active_present", false)) else 0)
	var weather_regions: Dictionary = {}
	for event_variant in weather_public.get("events", []) as Array:
		if not (event_variant is Dictionary):
			continue
		for region_variant in (event_variant as Dictionary).get("region_indices", []) as Array:
			var region_index := int(region_variant)
			if region_index >= 0:
				weather_regions[region_index] = true
	var dock_ready := int(dock_debug.get("apply_count", 0)) > 0 \
		and int(dock_debug.get("viewer_index", -1)) == 0 \
		and int(dock_debug.get("authorization_revision", 0)) > 0 \
		and int(dock_debug.get("source_revision", -1)) >= 0
	var roster_ready := int(roster_debug.get("player_count", 0)) == 4 \
		and int(roster_debug.get("column_count", 0)) == 1 \
		and int(roster_debug.get("viewer_index", -1)) == 0 \
		and int(roster_debug.get("authorization_revision", 0)) > 0 \
		and int(roster_debug.get("local_marker_count", 0)) == 1 \
		and int(roster_debug.get("render_count", 0)) > 0
	var map_ready := bool(map_debug.get("has_map_data", false)) \
		and int(map_debug.get("district_count", 0)) > 0 \
		and int(map_debug.get("district_polygon_count", -1)) == int(map_debug.get("district_count", 0)) \
		and int(map_debug.get("district_node_count", -1)) == int(map_debug.get("district_count", 0)) \
		and bool(map_debug.get("sceneized_visual_cutover_enabled", false)) \
		and not bool(map_debug.get("legacy_draw_fallback_used", true))
	return {
		"normal_card_count": int(dock_debug.get("normal_card_count", 0)),
		"commodity_card_count": int(dock_debug.get("commodity_card_count", 0)),
		"commodity_claim_count": claim_count,
		"facility_count": infrastructure.facilities_snapshot(false).size() if infrastructure != null else 0,
		"route_count": (route_snapshot.get("rows", []) as Array).size(),
		"military_unit_count": military.roster_snapshot(true).size() if military != null else 0,
		"queue_entry_count": queue_count,
		"weather_region_count": weather_regions.size(),
		"ai_nondefault_state_count": nondefault_ai,
		"victory_unresolved": bool(victory_debug.get("controller_ready", false)) \
			and str(victory_debug.get("state", "")) in ["idle", "qualification", "audit"] \
			and not bool(victory_debug.get("outcome_emitted", false)) \
			and int(victory_debug.get("outcome_sequence", -1)) == 0,
		"dock_ready": dock_ready,
		"roster_ready": roster_ready,
		"map_ready": map_ready,
		"map_diagnostics": {
			"map_node_present": map_view != null,
			"has_map_data": bool(map_debug.get("has_map_data", false)),
			"district_count": int(map_debug.get("district_count", 0)),
			"district_polygon_count": int(map_debug.get("district_polygon_count", -1)),
			"district_node_count": int(map_debug.get("district_node_count", -1)),
			"sceneized_visual_cutover_enabled": bool(map_debug.get(
				"sceneized_visual_cutover_enabled",
				false
			)),
			"legacy_draw_fallback_used": bool(map_debug.get("legacy_draw_fallback_used", true)),
		},
		"production_surface_ready": dock_ready and roster_ready and map_ready,
	}


func _ai_memory_has_activity(memory: Dictionary) -> bool:
	return not (memory.get("decision_samples", []) as Array).is_empty() \
		or not (memory.get("action_counts", {}) as Dictionary).is_empty() \
		or int(memory.get("economic_focus_cycle", -1)) >= 0 \
		or int(memory.get("strategic_intent_cycle", -1)) >= 0 \
		or int(memory.get("route_plan_cycle", -1)) >= 0 \
		or int(memory.get("learning_updates", 0)) > 0 \
		or int(memory.get("episode_learning_updates", 0)) > 0


func _checkpoint_ready(checkpoint: Dictionary) -> bool:
	return int(checkpoint.get("normal_card_count", 0)) > 0 \
		and int(checkpoint.get("commodity_card_count", 0)) > 0 \
		and int(checkpoint.get("commodity_claim_count", 0)) > 0 \
		and int(checkpoint.get("facility_count", 0)) >= 1 \
		and int(checkpoint.get("route_count", 0)) > 0 \
		and int(checkpoint.get("queue_entry_count", 0)) > 0 \
		and int(checkpoint.get("weather_region_count", 0)) > 0 \
		and int(checkpoint.get("ai_nondefault_state_count", 0)) > 0 \
		and bool(checkpoint.get("victory_unresolved", false)) \
		and bool(checkpoint.get("production_surface_ready", false))


func _safety_observation(context: Dictionary) -> Dictionary:
	var coordinator: GameRuntimeCoordinator = context.get("coordinator")
	return coordinator.save_restore_safety_observation() if coordinator != null else {}


func _world_digest(context: Dictionary) -> String:
	var coordinator: GameRuntimeCoordinator = context.get("coordinator")
	var world := coordinator.world_session_state()
	return JSON.stringify(world.to_save_data()).sha256_text() if world != null else ""


func _inventory_card_count(player_snapshot: Dictionary) -> int:
	var inventory: Dictionary = player_snapshot.get("inventory", {}) \
		if player_snapshot.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	var count := 0
	for slot_variant in slots:
		if slot_variant is Dictionary and not (slot_variant as Dictionary).is_empty():
			count += 1
	return count


func _inventory_card_ids(player_snapshot: Dictionary) -> Array:
	var result: Array = []
	var inventory: Dictionary = player_snapshot.get("inventory", {}) \
		if player_snapshot.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	for slot_variant in slots:
		if not (slot_variant is Dictionary):
			continue
		var machine: Dictionary = (slot_variant as Dictionary).get("machine", {}) \
			if (slot_variant as Dictionary).get("machine", {}) is Dictionary else {}
		var card_id := str(machine.get("card_id", ""))
		if not card_id.is_empty() and not result.has(card_id):
			result.append(card_id)
	return result


func _inventory_slot_for_card(player_snapshot: Dictionary, card_id: String) -> int:
	var inventory: Dictionary = player_snapshot.get("inventory", {}) \
		if player_snapshot.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	for slot_index in range(slots.size()):
		if not (slots[slot_index] is Dictionary):
			continue
		var machine: Dictionary = (slots[slot_index] as Dictionary).get("machine", {}) \
			if (slots[slot_index] as Dictionary).get("machine", {}) is Dictionary else {}
		if str(machine.get("card_id", "")) == card_id:
			return slot_index
	return -1


func _inventory_card_at(player_snapshot: Dictionary, slot_index: int) -> Dictionary:
	var inventory: Dictionary = player_snapshot.get("inventory", {}) \
		if player_snapshot.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	return (slots[slot_index] as Dictionary).duplicate(true) \
		if slot_index >= 0 and slot_index < slots.size() and slots[slot_index] is Dictionary else {}


func _inventory_has_card(player_snapshot: Dictionary, card_id: String) -> bool:
	return _inventory_slot_for_card(player_snapshot, card_id) >= 0


func _delta(before: Dictionary, after: Dictionary, field: String) -> int:
	return int(after.get(field, 0)) - int(before.get(field, 0))


func _manifest_base(run_id: String, role: String, head_sha: String) -> Dictionary:
	return {
		"run_id": run_id,
		"process_role": role,
		"process_id": OS.get_process_id(),
		"head_sha": head_sha,
		"slot_state": "failed",
		"success": false,
		"failure_code": "not_started",
	}


func _fail(base: Dictionary, reason_code: String) -> Dictionary:
	base["slot_state"] = "failed"
	base["success"] = false
	base["failure_code"] = reason_code
	return base


func _parse_options(args: PackedStringArray) -> Dictionary:
	var result := {
		"run_id": "",
		"process_role": "",
		"head_sha": "",
		"artifact_root": "",
		"official_claim_path": "",
		"launch_attestation_path": "",
		"launch_nonce": "",
		"expected_queue_resolution_id": 0,
		"expected_queue_stable_target_fingerprint": "",
		"scenario_fingerprint": "",
		"parse_error": "",
	}
	var seen: Dictionary = {}
	for argument in args:
		var text := str(argument)
		if text in ["--cold-restore-contract-only", "--cold-restore-qualification-probe"]:
			continue
		var option_key := ""
		var option_value: Variant = ""
		if text.begins_with("--cold-restore-role="):
			option_key = "process_role"
			option_value = text.trim_prefix("--cold-restore-role=")
		elif text.begins_with("--cold-restore-run-id="):
			option_key = "run_id"
			option_value = text.trim_prefix("--cold-restore-run-id=")
		elif text.begins_with("--cold-restore-head-sha="):
			option_key = "head_sha"
			option_value = text.trim_prefix("--cold-restore-head-sha=")
		elif text.begins_with("--cold-restore-artifact-root="):
			option_key = "artifact_root"
			option_value = text.trim_prefix("--cold-restore-artifact-root=")
		elif text.begins_with("--cold-restore-official-claim-path="):
			option_key = "official_claim_path"
			option_value = text.trim_prefix("--cold-restore-official-claim-path=")
		elif text.begins_with("--cold-restore-launch-attestation-path="):
			option_key = "launch_attestation_path"
			option_value = text.trim_prefix("--cold-restore-launch-attestation-path=")
		elif text.begins_with("--cold-restore-launch-nonce="):
			option_key = "launch_nonce"
			option_value = text.trim_prefix("--cold-restore-launch-nonce=")
		elif text.begins_with("--cold-restore-expected-queue-resolution-id="):
			option_key = "expected_queue_resolution_id"
			var resolution_text := text.trim_prefix("--cold-restore-expected-queue-resolution-id=")
			if not resolution_text.is_valid_int():
				result["parse_error"] = "expected_queue_resolution_id_invalid"
				continue
			option_value = int(resolution_text)
		elif text.begins_with("--cold-restore-expected-queue-stable-target-fingerprint="):
			option_key = "expected_queue_stable_target_fingerprint"
			option_value = text.trim_prefix("--cold-restore-expected-queue-stable-target-fingerprint=")
		elif text.begins_with("--cold-restore-scenario-fingerprint="):
			option_key = "scenario_fingerprint"
			option_value = text.trim_prefix("--cold-restore-scenario-fingerprint=")
		else:
			result["parse_error"] = "unknown_option"
			continue
		if seen.has(option_key):
			result["parse_error"] = "duplicate_option"
			continue
		seen[option_key] = true
		result[option_key] = option_value
	return result


func _write_public_manifest(run_id: String, role: String, manifest: Dictionary) -> Dictionary:
	return CHILD_ATTESTATION.write_result(run_id, role, manifest)
