extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const CLAIM_REQUEST := preload("res://scripts/runtime/commodity_sushi_track_claim_request.gd")
const GAME_ACTION_INTENT := preload("res://scripts/semantic/game_action_intent_v1.gd")

const FORMAL_FULL_RUN := false
const EXECUTION_READY := false
const SCHEMA_VERSION := 2
const PROCESS_ROLES := ["producer", "consumer", "validator"]
const INDUSTRY_IDS := ["life", "energy", "industry", "technology", "commerce", "shipping"]
const QUEUE_CARD_IDS := ["supply_demand.near_land_supply.rank_1", "supply_demand.remote_sea_order.rank_1"]
const MAX_SUPPLY_CHURN := 40
const MAX_SALE_SECONDS := 180
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


func _init() -> void:
	call_deferred("_run_entry")


func _run_entry() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--cold-restore-contract-only"):
		print(JSON.stringify(contract_snapshot()))
		quit(0)
		return
	var parsed := _parse_options(args)
	var validation := validate_options(parsed)
	if not bool(validation.get("valid", false)):
		push_error("Cold restore options rejected: %s" % str(validation.get("reason_code", "options_invalid")))
		quit(2)
		return
	var started_ms := Time.get_ticks_msec()
	var result: Dictionary = await _run_role(validation, str(parsed.get("head_sha", "")))
	result["elapsed_ms"] = maxi(0, Time.get_ticks_msec() - started_ms)
	var manifest := sanitize_public_manifest(result)
	_write_public_manifest(str(validation.get("run_id", "")), str(validation.get("process_role", "")), manifest)
	print("COLD_RESTORE_MANIFEST|%s" % JSON.stringify(manifest))
	quit(0 if bool(manifest.get("success", false)) else 1)


static func contract_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"driver_id": "alpha04c_cold_restore_vertical_slice_v2",
		"formal_full_run": FORMAL_FULL_RUN,
		"cold_restore_vertical_slice": true,
		"execution_ready": EXECUTION_READY,
		"process_sequence": ["producer_exit", "consumer_exit", "validator_start", "orchestrator_compare"],
		"process_roles": PROCESS_ROLES.duplicate(),
		"qa_save_root": SaveSlotPolicyV06.QA_ROOT,
		"production_slot_id": String(SaveSlotPolicyV06.PRODUCTION_SLOT_ID),
		"shares_gameplay_process_memory": false,
		"raw_envelope_in_evidence": false,
		"runtime_loop_frozen_until_restore_commit": true,
		"minimum_post_restore_ticks": 1,
		"terminal_quiescent_frames": 8,
	}


static func validate_options(options: Dictionary) -> Dictionary:
	var run_id := str(options.get("run_id", ""))
	var process_role := str(options.get("process_role", ""))
	if process_role not in PROCESS_ROLES:
		return {"valid": false, "reason_code": "process_role_invalid"}
	var qa_path := SaveSlotPolicyV06.qa_path(run_id, "current_run")
	if qa_path.is_empty():
		return {"valid": false, "reason_code": "run_id_invalid"}
	return {
		"valid": true,
		"reason_code": "ok",
		"run_id": run_id,
		"process_role": process_role,
		"qa_evidence_path": qa_path,
		"save_path": SaveSlotPolicyV06.PRODUCTION_PATH,
	}


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
	for field in ["run_id", "head_sha", "source_sections_digest", "saved_sections_digest", "restored_sections_digest", "source_write_id", "write_id", "source_write_fingerprint", "write_fingerprint", "failure_code"]:
		if str(manifest.get(field, "")).length() > 128:
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


func _run_producer(context: Dictionary, options: Dictionary, base: Dictionary) -> Dictionary:
	var save_path := str(options.get("save_path", ""))
	if FileAccess.file_exists(save_path):
		return _fail(base, "producer_slot_must_start_empty")
	var started := _start_default_session(context, str(options.get("run_id", "")))
	if not bool(started.get("applied", false)):
		return _fail(base, str(started.get("reason_code", "session_start_failed")))
	var human := _submit_human_selection(context, "producer-human", 1)
	var legal_checkpoint: Dictionary = await _prepare_legal_checkpoint(context)
	if not bool(legal_checkpoint.get("ready", false)):
		return _fail(base, str(legal_checkpoint.get("reason_code", "legal_checkpoint_failed")))
	var initial_sales: Dictionary = legal_checkpoint.get("sales", {}) \
		if legal_checkpoint.get("sales", {}) is Dictionary else {}
	(context.get("coordinator") as GameRuntimeCoordinator).resume_session()
	var ai_actions := await _tick_ai_until_action(context, 120)
	(context.get("coordinator") as GameRuntimeCoordinator).pause_session()
	var queue_submission := _submit_prepared_queue_card(context, legal_checkpoint)
	if not bool(queue_submission.get("accepted", false)) \
			or not bool(queue_submission.get("queued", false)) \
			or str(queue_submission.get("reason", "")) != "queued" \
			or int(queue_submission.get("resolution_id", -1)) <= 0:
		return _fail(base, "legal_queue_submission_failed")
	var checkpoint := _checkpoint_summary(context)
	var save := _save_via_player_flow(context, save_path, false)
	if not bool(save.get("ok", false)):
		return _fail(base, str(save.get("reason_code", "producer_save_failed")))
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
		"sale_receipt_count": int(initial_sales.get("sale_receipt_count", 0)),
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
		"success": bool(human.get("accepted", false)) and ai_actions > 0 and int(initial_sales.get("sale_receipt_count", 0)) > 0 and _checkpoint_ready(checkpoint),
		"failure_code": "" if bool(human.get("accepted", false)) and ai_actions > 0 and int(initial_sales.get("sale_receipt_count", 0)) > 0 and _checkpoint_ready(checkpoint) else "producer_checkpoint_incomplete",
	}, true)
	return base


func _run_consumer(context: Dictionary, options: Dictionary, base: Dictionary) -> Dictionary:
	var save_path := str(options.get("save_path", ""))
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
	(context.get("coordinator") as GameRuntimeCoordinator).resume_session()
	var human := _submit_human_selection(context, "consumer-human", 2)
	var commodity_action := _claim_first_visible_commodity(context, maxi(1, Time.get_ticks_msec()))
	var ai_actions := await _tick_ai_until_action(context, 120)
	var post_sales := _advance_sale(context, 60.0)
	if not bool(human.get("accepted", false)) or ai_actions <= 0 \
			or not bool(commodity_action.get("success", false)) \
			or int(post_sales.get("sale_receipt_count", 0)) <= 0:
		return _fail(base, "post_restore_continuation_failed")
	var checkpoint := _checkpoint_summary(context)
	var generation_two := _save_via_player_flow(context, save_path, true)
	if not bool(generation_two.get("ok", false)):
		return _fail(base, str(generation_two.get("reason_code", "generation_two_save_failed")))
	var terminal := await _finish_to_settlement(context)
	if not bool(terminal.get("settled", false)):
		return _fail(base, "post_restore_settlement_failed")
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
	return base


func _run_validator(context: Dictionary, options: Dictionary, base: Dictionary) -> Dictionary:
	var save_path := str(options.get("save_path", ""))
	var before_observation := _safety_observation(context)
	var read := _read_slot(context, save_path)
	if not bool(read.get("ok", false)):
		return _fail(base, str(read.get("reason_code", "validator_read_failed")))
	var source_digest := str(read.get("sections_digest", ""))
	var load := _resume_via_player_flow(context, save_path)
	var after_observation := _safety_observation(context)
	var recapture := _capture_sections(context, "validator-recapture")
	var exact := bool(load.get("ok", false)) and bool(recapture.get("ok", false)) \
		and str(recapture.get("sections_digest", "")) == source_digest
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
		"failure_code": "" if exact else "validator_exact_recapture_mismatch",
	}, true)
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
	var command_port := services.get_node_or_null("SetupDraftCommandPort") as SetupDraftCommandPort
	var transaction := services.get_node_or_null("SessionStartTransactionCoordinator") as SessionStartTransactionCoordinator
	var session := context.get("session") as GameSessionRuntimeController
	if draft == null or command_port == null or transaction == null or session == null:
		return {"applied": false, "reason_code": "session_start_dependency_missing"}
	draft.reset_to_defaults()
	var challenge_depth := 1
	if run_id.begins_with("alpha04c-depth-probe-"):
		challenge_depth = clampi(int(run_id.trim_prefix("alpha04c-depth-probe-")), 1, 6)
	if challenge_depth != 1:
		var command := SetupDraftCommand.create(
			"cold-restore:%s:set-depth" % run_id,
			SetupDraftCommand.KIND_SET_CHALLENGE_DEPTH,
			int(draft.draft_snapshot().get("draft_revision", -1)),
			challenge_depth,
			-1,
			"quality_driver"
		)
		var command_receipt := command_port.submit_command(command)
		if command_receipt == null or not command_receipt.applied:
			return {"applied": false, "reason_code": "session_challenge_depth_failed"}
	var request := SessionStartRequest.create(
		"cold-restore-%s-producer" % run_id,
		draft.draft_snapshot(),
		session.session_start_revision(),
		"quality_driver"
	)
	var receipt := transaction.start_session(request)
	return {
		"applied": receipt != null and receipt.applied,
		"reason_code": receipt.reason_code if receipt != null else "session_start_receipt_missing",
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
			or queue_card_id.is_empty() or asset_color not in ["industry", "shipping"]:
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
	var asset_play := _play_facility_through_formal_submission(
		coordinator,
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
		var supply_play := _play_facility_through_formal_submission(
			coordinator,
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
		"human_action_count": int(asset_purchase.get("purchase_count", 0)) \
			+ supply_purchase_count + int(queue_purchase.get("purchase_count", 0)) + (1 if same_factory else 2),
		"sales": sales.duplicate(true),
	}


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
	var near_candidates: Array[Dictionary] = []
	var remote_candidates: Array[Dictionary] = []
	var asset_candidates_by_color := {"industry": [], "shipping": []}
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
			if _public_demand_route_exists(flow, routes, product_id, region_id, "land", "near_lte_2"):
				var near := target.duplicate(true)
				near["queue_card_id"] = "supply_demand.near_land_supply.rank_1"
				near["asset_color"] = "industry"
				near_candidates.append(near)
			if _public_demand_route_exists(flow, routes, product_id, region_id, "sea", "remote_gt_2"):
				var remote := target.duplicate(true)
				remote["queue_card_id"] = "supply_demand.remote_sea_order.rank_1"
				remote["asset_color"] = "shipping"
				remote_candidates.append(remote)
			if asset_candidates_by_color.has(industry_id) \
					and _public_demand_route_exists(flow, routes, product_id, region_id, "", "any"):
				(asset_candidates_by_color[industry_id] as Array).append(target.duplicate(true))
	_sort_targets(near_candidates)
	_sort_targets(remote_candidates)
	_sort_targets(asset_candidates_by_color["industry"] as Array[Dictionary])
	_sort_targets(asset_candidates_by_color["shipping"] as Array[Dictionary])
	var supply_candidates: Array[Dictionary] = near_candidates if not near_candidates.is_empty() else remote_candidates
	if supply_candidates.is_empty():
		return {"ready": false, "reason_code": "legal_supply_demand_factory_target_missing"}
	var supply_target := supply_candidates[0]
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


func _matching_sale_target_pair(
	routes: RouteNetworkRuntimeController,
	product_id: String,
	factory_targets: Array[Dictionary],
	market_targets: Array[Dictionary]
) -> Dictionary:
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
				if int(route.get("shortest_legal_distance", -1)) >= 0 \
						and int(route.get("bottleneck_units_per_minute", 0)) > 0:
					return {
						"factory_target": factory_target.duplicate(true),
						"market_target": market_target.duplicate(true),
					}
	return {}


func _matching_specific_target_pair(
	routes: RouteNetworkRuntimeController,
	product_id: String,
	factory_targets: Array[Dictionary],
	market_targets: Array[Dictionary],
	required_mode: String,
	distance_rule: String
) -> Dictionary:
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
				var distance_matches := distance > 2 if distance_rule == "remote_gt_2" else distance >= 0 and distance <= 2
				if distance_matches and (route.get("mode_tags", []) as Array).has(required_mode) \
						and int(route.get("bottleneck_units_per_minute", 0)) > 0:
					return {
						"factory_target": factory_target.duplicate(true),
						"market_target": market_target.duplicate(true),
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


func _region_has_colored_flow_facility(
	infrastructure: RegionInfrastructureRuntimeController,
	region_id: String,
	industry_id: String
) -> bool:
	for facility_variant in infrastructure.facilities_snapshot(false):
		if not (facility_variant is Dictionary):
			continue
		var facility := facility_variant as Dictionary
		if bool(facility.get("active", false)) \
				and str(facility.get("region_id", "")) == region_id \
				and str(facility.get("industry_id", "")) == industry_id \
				and str(facility.get("facility_type", "")) in ["factory", "market"]:
			return true
	return false


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


func _sort_targets(targets: Array[Dictionary]) -> void:
	targets.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_score := 1 if bool(left.get("public_candidate", false)) else 0
		var right_score := 1 if bool(right.get("public_candidate", false)) else 0
		if left_score != right_score:
			return left_score > right_score
		var left_index := int(left.get("public_index", -1))
		var right_index := int(right.get("public_index", -1))
		return left_index < right_index if left_index != right_index \
			else str(left.get("region_id", "")) < str(right.get("region_id", ""))
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
	protected_card_ids: Array
) -> Dictionary:
	var purchase_count := 0
	for _attempt in range(MAX_SUPPLY_CHURN):
		var player := coordinator.v06_card_player_snapshot(actor_id)
		if _inventory_has_card(player, target_card_id):
			return {"completed": true, "reason_code": "target_already_owned", "purchase_count": purchase_count}
		var visible_target_district := _purchasable_listing_district(coordinator, world, target_card_id, -1)
		var purchase_card_id := target_card_id
		if visible_target_district < 0:
			purchase_card_id = _first_visible_purchasable_filler(coordinator, world, protected_card_ids)
		if purchase_card_id.is_empty():
			return {"completed": false, "reason_code": "legal_supply_churn_exhausted", "purchase_count": purchase_count}
		var discard_slot := -1
		if _inventory_card_count(player) >= CardFlowPolicyV06.HAND_LIMIT:
			discard_slot = _first_disposable_inventory_slot(player, protected_card_ids)
			if discard_slot < 0:
				return {"completed": false, "reason_code": "legal_supply_discard_unavailable", "purchase_count": purchase_count}
		var purchase: Dictionary = await _purchase_from_region_supply_popup(
			coordinator,
			world,
			screen,
			overlay,
			popup,
			viewmodel_query,
			port,
			receipts,
			purchase_card_id,
			discard_slot,
			visible_target_district
		)
		if not bool(purchase.get("completed", false)):
			return {
				"completed": false,
				"reason_code": str(purchase.get("failure", "legal_supply_purchase_failed")),
				"purchase_count": purchase_count,
			}
		purchase_count += 1
	return {
		"completed": _inventory_has_card(coordinator.v06_card_player_snapshot(actor_id), target_card_id),
		"reason_code": "legal_supply_target_found" if _inventory_has_card(coordinator.v06_card_player_snapshot(actor_id), target_card_id) else "legal_supply_churn_limit",
		"purchase_count": purchase_count,
	}


func _first_visible_purchasable_filler(
	coordinator: GameRuntimeCoordinator,
	world: WorldSessionState,
	protected_card_ids: Array
) -> String:
	for district_index in range(world.districts.size()):
		if not (world.districts[district_index] is Dictionary) \
				or not bool(coordinator.card_market_listing_availability(district_index).get("purchasable", false)):
			continue
		var region_id := str((world.districts[district_index] as Dictionary).get("region_id", ""))
		for card_id_variant in coordinator.region_supply_card_ids(region_id):
			var card_id := str(card_id_variant)
			if not card_id.is_empty() and not protected_card_ids.has(card_id):
				return card_id
	return ""


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


func _purchase_from_region_supply_popup(
	coordinator: GameRuntimeCoordinator,
	world: WorldSessionState,
	screen: SpaceSyndicateGameScreen,
	overlay: SpaceSyndicateOverlayLayer,
	region_popup: SpaceSyndicateRegionSupplyPopup,
	viewmodel_query: TablePresentationViewModelQuery,
	port: DistrictSupplyActionPort,
	receipts: Array[DistrictSupplyActionReceipt],
	card_id: String,
	discard_slot: int,
	preferred_district: int
) -> Dictionary:
	var result := {"completed": false, "failure": "purchase_not_started"}
	var district_index := _purchasable_listing_district(coordinator, world, card_id, preferred_district)
	coordinator.request_table_presentation_refresh(&"full", &"cold_restore_supply_open_sync")
	await process_frame
	var open_receipt_start := receipts.size()
	if district_index < 0 or not screen.request_district_supply_open(district_index, &"qa_driver"):
		result["failure"] = "purchasable_listing_or_selection_missing"
		return result
	await process_frame
	if receipts.size() <= open_receipt_start or not receipts[open_receipt_start].accepted:
		result["failure"] = "typed_region_supply_open_rejected"
		return result
	var receipt_start := receipts.size()
	var quote_state := viewmodel_query.compose_table_state(0, true)
	var quote_projection: Dictionary = quote_state.get("region_supply_popup", {}) \
		if quote_state.get("region_supply_popup", {}) is Dictionary else {}
	if quote_projection.is_empty() or not region_popup.apply_projection(quote_projection):
		result["failure"] = "quote_surface_unavailable"
		return result
	var quote_offer := region_popup.action_offer_for_card(card_id, GAME_ACTION_INTENT.ACTION_DISTRICT_SUPPLY_QUOTE)
	if quote_offer.is_empty() or not screen.submit_game_action_offer(quote_offer, "human_click", {}, {}):
		result["failure"] = "quote_surface_unavailable"
		return result
	await process_frame
	if receipts.size() <= receipt_start or not receipts[receipt_start].accepted \
			or receipts[receipt_start].reason_code != "quote_locked":
		result["failure"] = "quote_rejected"
		return result
	var purchase_state := viewmodel_query.compose_table_state(0, true)
	var purchase_projection: Dictionary = purchase_state.get("region_supply_popup", {}) \
		if purchase_state.get("region_supply_popup", {}) is Dictionary else {}
	if purchase_projection.is_empty() or not region_popup.apply_projection(purchase_projection):
		result["failure"] = "purchase_surface_unavailable"
		return result
	var purchase_offer := region_popup.action_offer_for_card(card_id, GAME_ACTION_INTENT.ACTION_DISTRICT_SUPPLY_PURCHASE)
	if purchase_offer.is_empty() or not screen.submit_game_action_offer(purchase_offer, "human_click", {}, {}):
		result["failure"] = "purchase_surface_unavailable"
		return result
	await process_frame
	if receipts.size() <= receipt_start + 1:
		result["failure"] = "purchase_receipt_missing"
		return result
	var purchase_receipt := receipts[receipt_start + 1]
	if purchase_receipt.requires_discard:
		if discard_slot < 0:
			result["failure"] = "discard_slot_missing"
			return result
		overlay.temporary_decision_action_requested.emit("discard_purchase_%d" % discard_slot)
		await process_frame
	if receipts.size() <= receipt_start + (2 if purchase_receipt.requires_discard else 1):
		result["failure"] = "terminal_purchase_receipt_missing"
		return result
	var terminal_receipt := receipts[-1]
	result["completed"] = terminal_receipt.accepted and terminal_receipt.applied \
		and terminal_receipt.reason_code == "purchase_committed"
	result["failure"] = "" if bool(result.get("completed", false)) else terminal_receipt.reason_code
	return result


func _purchasable_listing_district(
	coordinator: GameRuntimeCoordinator,
	world: WorldSessionState,
	card_id: String,
	preferred_district: int
) -> int:
	var ordered: Array[int] = []
	if preferred_district >= 0:
		ordered.append(preferred_district)
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
	coordinator: GameRuntimeCoordinator,
	actor_id: String,
	card_id: String,
	region_id: String
) -> Dictionary:
	var submission := coordinator.card_play_submission_controller()
	var before := submission.debug_snapshot()
	var public_result := coordinator.execute_v06_facility_play_action(actor_id, card_id, region_id)
	var after := submission.debug_snapshot()
	var receipt: Dictionary = after.get("last_receipt", {}) if after.get("last_receipt", {}) is Dictionary else {}
	var v06_receipt: Dictionary = receipt.get("v06_receipt", {}) if receipt.get("v06_receipt", {}) is Dictionary else {}
	var finalization: Dictionary = v06_receipt.get("effect_finalization", {}) \
		if v06_receipt.get("effect_finalization", {}) is Dictionary else {}
	return {
		"success": bool(public_result.get("success", false)) \
			and int(after.get("submission_count", 0)) == int(before.get("submission_count", 0)) + 1 \
			and int(after.get("accepted_count", 0)) == int(before.get("accepted_count", 0)) + 1 \
			and bool(receipt.get("accepted", false)) \
			and bool(v06_receipt.get("committed", false)) \
			and bool(finalization.get("finalized", v06_receipt.get("finalized", false))),
		"public_result": public_result,
		"receipt": receipt,
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


func _submit_prepared_queue_card(context: Dictionary, prepared: Dictionary) -> Dictionary:
	var coordinator := context.get("coordinator") as GameRuntimeCoordinator
	var actor_id := str(prepared.get("actor_id", ""))
	var queue_card_id := str(prepared.get("queue_card_id", ""))
	var player := coordinator.v06_card_player_snapshot(actor_id)
	var slot_index := _inventory_slot_for_card(player, queue_card_id)
	if slot_index < 0:
		return {"accepted": false, "queued": false, "reason": "queue_card_missing"}
	var card := _inventory_card_at(player, slot_index)
	var preflight := coordinator.preflight_v06_automatic_supply_demand(actor_id, card)
	if not bool(preflight.get("ready", false)):
		return {"accepted": false, "queued": false, "reason": str(preflight.get("reason_code", "queue_preflight_failed"))}
	return coordinator.card_play_submission_controller().request_hand_play({
		"player_index": 0,
		"slot_index": slot_index,
		"submission_source": "cold_restore_vertical_slice",
	})


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
	var coordinator: GameRuntimeCoordinator = context.get("coordinator")
	var before := int(_safety_observation(context).get("ai_action_submission_count", 0))
	for _index in range(max_ticks):
		coordinator.tick_ai(0.5)
		if int(_safety_observation(context).get("ai_action_submission_count", 0)) > before:
			break
		await process_frame
	return maxi(0, int(_safety_observation(context).get("ai_action_submission_count", 0)) - before)


func _tick_ai_until_nontrivial_queue(context: Dictionary, max_ticks: int) -> Dictionary:
	var coordinator := context.get("coordinator") as GameRuntimeCoordinator
	var queue := coordinator.get_node_or_null("CardResolutionQueueRuntimeService") as CardResolutionQueueRuntimeService
	var before := int(_safety_observation(context).get("ai_action_submission_count", 0))
	if queue == null:
		return {"queue_ready": false, "action_count": 0}
	for _index in range(max_ticks):
		coordinator.tick_ai(0.5)
		var snapshot := queue.public_snapshot()
		var state := queue.queue_state_snapshot()
		var entry_count := int(snapshot.get("current_count", 0)) + int(snapshot.get("next_count", 0)) \
			+ (1 if bool(snapshot.get("active_present", false)) else 0)
		var lineage_count := 1 if int(state.get("resolution_sequence", 0)) > 0 \
			or int(state.get("last_group_window_sequence", -1)) >= 0 else 0
		var action_count := maxi(0, int(_safety_observation(context).get("ai_action_submission_count", 0)) - before)
		if action_count > 0 and entry_count + lineage_count > 0:
			coordinator.pause_session()
			return {
				"queue_ready": true,
				"queue_count": entry_count + lineage_count,
				"action_count": action_count,
			}
		await process_frame
	coordinator.pause_session()
	return {
		"queue_ready": false,
		"queue_count": 0,
		"action_count": maxi(0, int(_safety_observation(context).get("ai_action_submission_count", 0)) - before),
	}


func _finish_to_settlement(context: Dictionary) -> Dictionary:
	var coordinator: GameRuntimeCoordinator = context.get("coordinator")
	var services: Node = context.get("services")
	var world := coordinator.world_session_state()
	var sequence: Array = ["restored_running"]
	var players := world.players.duplicate(true)
	for index in range(1, players.size()):
		if players[index] is Dictionary:
			(players[index] as Dictionary)["eliminated"] = true
	world.players = players
	coordinator.mark_session_dirty("cold_restore_terminal_fixture")
	sequence.append("last_survivor")
	var outcome := coordinator.resolve_victory_outcome("last_survivor")
	await process_frame
	var session: GameSessionRuntimeController = context.get("session")
	var composition := services.get_node_or_null("FinalSettlementRuntimeComposition")
	var settlement_debug: Dictionary = composition.debug_snapshot() if composition != null else {}
	if not outcome.is_empty():
		sequence.append("resolved")
	if int(settlement_debug.get("present_count", 0)) == 1:
		sequence.append("final_settlement")
	var world_before := _world_digest(context)
	var rng_before := int(_safety_observation(context).get("rng_draw_invocation_count", 0))
	for _frame in range(8):
		await process_frame
	var world_after := _world_digest(context)
	var rng_after := int(_safety_observation(context).get("rng_draw_invocation_count", 0))
	if world_before == world_after and rng_before == rng_after:
		sequence.append("quiescent")
	return {
		"settled": session != null and session.is_finished() and int(settlement_debug.get("present_count", 0)) == 1,
		"victory_state_sequence": sequence,
		"settlement_count": 1 if session != null and session.is_finished() else 0,
		"presentation_count": int(settlement_debug.get("present_count", 0)),
		"public_log_count": int(settlement_debug.get("logged_outcome_count", 0)),
		"quiet_frames": 8,
		"world_delta": 0 if world_before == world_after else 1,
		"rng_delta": rng_after - rng_before,
	}


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
	var queue_state: Dictionary = queue.queue_state_snapshot() if queue != null else {}
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
	if queue_count <= 0 and (int(queue_state.get("resolution_sequence", 0)) > 0 \
			or int(queue_state.get("last_group_window_sequence", -1)) >= 0):
		queue_count = 1
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
		and int(checkpoint.get("facility_count", 0)) >= 2 \
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
	var result := {"run_id": "", "process_role": "", "head_sha": ""}
	for argument in args:
		var text := str(argument)
		if text.begins_with("--cold-restore-role="):
			result["process_role"] = text.trim_prefix("--cold-restore-role=")
		elif text.begins_with("--cold-restore-run-id="):
			result["run_id"] = text.trim_prefix("--cold-restore-run-id=")
		elif text.begins_with("--cold-restore-head-sha="):
			result["head_sha"] = text.trim_prefix("--cold-restore-head-sha=")
	return result


func _write_public_manifest(run_id: String, role: String, manifest: Dictionary) -> void:
	var path := "%s%s/evidence/%s.json" % [SaveSlotPolicyV06.QA_ROOT, run_id, role]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(manifest))
		file.flush()
		file.close()


func _cleanup_qa_slot(path: String) -> void:
	if not SaveSlotPolicyV06.is_qa_path(path):
		return
	var directory := DirAccess.open(path.get_base_dir())
	if directory == null:
		return
	var prefix := path.get_file()
	for file_name in directory.get_files():
		var normalized := str(file_name)
		if normalized == prefix or normalized.begins_with("%s." % prefix) or normalized.begins_with("%s.tmp-" % prefix) or normalized.begins_with("%s.swap-" % prefix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path.get_base_dir().path_join(normalized)))
