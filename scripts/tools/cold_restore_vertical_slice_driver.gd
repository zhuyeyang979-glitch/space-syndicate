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
const PROCESS_A_TIMELINE := preload("res://scripts/tools/cold_restore_process_a_phase_timeline.gd")
const CAPTURE_FAILURE := preload("res://scripts/runtime/save_owner_capture_failure_v1.gd")
const DIAGNOSTIC_SCENARIO_IDENTITY := preload("res://scripts/tools/diagnostic_scenario_identity_v1.gd")
const TARGETED_OWNER_DIAGNOSTIC := preload("res://scripts/tools/targeted_owner_capture_diagnostic_v2.gd")
const ROLE_PROGRESS_HEARTBEAT := preload("res://scripts/tools/cold_restore_role_progress_heartbeat.gd")
const PROCESS_A_REHEARSAL_COMPLETION := preload("res://scripts/tools/process_a_rehearsal_completion_v1.gd")
const TARGETED_LEDGER_BINDING_VALIDATOR := preload(
	"res://scripts/tools/cold_restore_targeted_ledger_binding_validator_v1.gd"
)
const AUTHORIZATION_CONTRACT := preload(
	"res://scripts/tools/cold_restore_authorization_contract_v1.gd"
)

const FORMAL_FULL_RUN := false
const EXECUTION_READY := true
const ACCEPTANCE_SEED := 900626424
const ACCEPTANCE_CHALLENGE_DEPTH := 1
const ACCEPTANCE_LOCAL_PLAYER_COUNT := 1
const ACCEPTANCE_AI_PLAYER_COUNT := 3
const TARGETED_OWNER_CAPTURE_SCENARIO_FINGERPRINT := "0bccef8426345e2ea1fd8ae7d6187d282d52d44bc73d6fb3d1ed3375dc20b7bf"
const SCHEMA_VERSION := 4
const OFFICIAL_CLAIM_SCHEMA_VERSION := 2
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
const PROCESS_A_SAVE_QUIET_FIELDS := [
	"rng_draw_invocation_count",
	"world_clock_advance_count",
	"sale_receipt_emission_count",
	"public_log_entry_count",
	"public_log_revision",
	"private_feedback_revision",
	"notification_count",
	"human_action_submission_count",
	"ai_action_submission_count",
	"economic_reward_count",
	"presentation_revision",
]
const TARGETED_OWNER_CAPTURE_PHASES := [
	"session_started",
	"real_commodity_claim_complete",
	"real_normal_card_purchase_complete",
	"real_facility_economy_complete",
	"first_sale_receipt_complete",
	"ai_nondefault_state_complete",
	"queue_entry_committed",
	"restore_barrier_entered",
]
const SAVE_SECTION_ORDER := [
	"ruleset", "region_infrastructure", "region_supply", "commodity_flow",
	"routes", "player_mana", "commodity_belt_visibility", "card_inventory",
	"player_organization", "monsters", "military", "weather",
	"card_resolution_queue", "card_resolution_execution", "card_resolution_history",
	"ai", "bankruptcy_neutral_estate", "victory_control", "session",
]
const SAVE_OWNER_ORDER := [
	"ruleset_runtime", "public_facility_region", "region_supply", "commodity_flow",
	"route_network", "player_mana", "commodity_belt_visibility", "card_inventory",
	"player_organization", "monster_runtime", "military_runtime", "weather_runtime",
	"card_resolution_queue", "card_resolution_execution", "card_resolution_history",
	"ai_runtime", "bankruptcy_neutral_estate", "victory_control", "game_session",
]
const SAVE_STATE_VERSION_ORDER := [
	1, 1, 1, 2, 2, 1, 1, 3, 1, 1, 2, 1, 2, 1, 1, 2, 1, 1, 3,
]
const WORLD_FINGERPRINT_SECTION_IDS := [
	"region_infrastructure", "region_supply", "commodity_flow", "routes",
	"monsters", "military", "weather", "bankruptcy_neutral_estate",
	"victory_control", "session",
]
const RNG_CURSOR_SECTION_IDS := ["region_supply", "weather", "session"]
const AI_STATE_SECTION_IDS := ["ai"]
const CARD_INVENTORY_SECTION_IDS := ["card_inventory"]
const QUEUE_SECTION_IDS := [
	"card_resolution_queue", "card_resolution_execution", "card_resolution_history",
]
const PUBLIC_MANIFEST_FIELDS := [
	"schema_version",
	"visibility_scope",
	"run_id",
	"process_role",
	"process_id",
	"head_sha",
	"scenario_fingerprint",
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
	"registry_commit_count",
	"registry_rebind_count",
	"partial_restore_state_count",
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
	"restore_private_feedback_delta",
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
	"duplicate_queue_entry_count",
	"duplicate_facility_creation_count",
	"duplicate_card_consumption_count",
	"duplicate_cost_consumption_count",
	"duplicate_sale_receipt_count",
	"world_fingerprint_match",
	"rng_cursor_match",
	"ai_state_fingerprint_match",
	"card_inventory_fingerprint_match",
	"queue_fingerprint_match",
	"generation_2_recapture_fingerprint_match",
	"generation_2_rng_cursor_match",
	"generation_2_duplicate_transaction_count",
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
	"save_readback_green",
	"save_fingerprint_parity",
	"write_fingerprint",
	"elapsed_ms",
	"success",
	"failure_code",
]
const OFFICIAL_CLAIM_FIELDS := [
	"schema_version", "claim_id", "attempt_number", "authorization_id", "created_at_utc",
	"run_id", "source_head", "rehearsal_green_head", "scenario_fingerprint",
	"challenge_depth", "seed", "local_player_count", "ai_player_count",
	"timeout_policy_sha256", "prerequisite_evidence_fingerprint",
	"preclaim_runtime_freeze_fingerprint", "process_role_timeouts", "rehearsal_run_id",
	"rehearsal_evidence_fingerprint", "rehearsal_outcome_sha256",
	"rehearsal_admission_sha256", "rehearsal_launch_sha256",
	"rehearsal_completion_sha256", "rehearsal_child_attestation_sha256",
	"rehearsal_parent_attestation_sha256", "attempt_1_claim_relative_path",
	"attempt_1_claim_sha256", "orchestrator_id", "orchestrator_schema_version",
	"orchestrator_script_sha256", "orchestrator_process_id",
	"orchestrator_creation_time_utc_ticks", "claim_nonce", "status",
	"authorized_official_count", "official_count_before", "official_count_after",
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
const REHEARSAL_LEDGER_FIELDS := [
	"schema_version", "ledger_id", "contract_id", "authorization_id", "status",
	"created_at_utc", "run_id", "repository_head", "scenario_fingerprint",
	"timeout_policy_fingerprint", "prerequisite_evidence_fingerprint",
	"challenge_depth", "seed", "local_player_count",
	"ai_player_count", "rehearsal_only", "nonofficial", "official", "formal",
	"official_authorization_consumed", "authorized_rehearsal_count",
	"rehearsal_count_before", "rehearsal_count_after", "admission_evidence_id",
	"admission_evidence_run_id", "admission_evidence_sha256",
	"admission_evidence_fingerprint", "admission_evidence_green",
	"diagnostic_quota_ledger_sha256", "diagnostic_launch_attestation_sha256",
	"diagnostic_manifest_sha256", "diagnostic_engine_process_id",
	"diagnostic_engine_creation_time_utc_ticks", "diagnostic_child_attestation_sha256",
	"diagnostic_child_attestation_fingerprint", "diagnostic_parent_attestation_sha256",
	"diagnostic_stdout_sha256", "diagnostic_stderr_sha256",
	"diagnostic_bootstrap_admission_sha256", "diagnostic_bootstrap_admission_fingerprint",
	"diagnostic_prequota_attestation_sha256", "diagnostic_prequota_attestation_fingerprint",
	"official_attempt_1_claim_relative_path", "official_attempt_1_claim_sha256",
	"official_attempt_1_claim_immutable", "official_attempt_2_claim_absent",
	"official_claim_inventory_count", "official_claim_inventory_fingerprint",
	"process_role", "orchestrator_process_id", "orchestrator_creation_time_utc_ticks",
	"claim_nonce", "launch_nonce", "ledger_fingerprint",
]
var _district_supply_request_revision := 0
var _process_started_monotonic_ms := 0
var _process_a_timeline: RefCounted
var _process_a_timeline_failure := ""
var _active_main: Node
var _targeted_owner_capture_diagnostic := false
var _process_a_rehearsal := false
var _targeted_owner_capture_audits: Array[Dictionary] = []
var _targeted_owner_capture_first_failure: Dictionary = {}
var _targeted_owner_capture_first_phase := ""
var _targeted_owner_capture_observed_scenario: Dictionary = {}
var _targeted_diagnostic_timeline: Dictionary = {}
var _targeted_diagnostic_identity: Dictionary = {}
var _targeted_diagnostic_pre_owner_failure: Dictionary = {}
var _targeted_diagnostic_capture: Dictionary = {}
var _targeted_diagnostic_context: Dictionary = {}
var _targeted_diagnostic_options: Dictionary = {}
var _targeted_diagnostic_written := false
var _targeted_diagnostic_phase_failure := ""
var _role_heartbeat: RefCounted
var _role_heartbeat_failure := ""
var _role_id := ""
var _heartbeat_owner_index := -1


func _init() -> void:
	_process_started_monotonic_ms = Time.get_ticks_msec()
	call_deferred("_run_entry")


func _record_timeline_result(result: Dictionary) -> void:
	if bool(result.get("valid", false)):
		return
	_process_a_timeline_failure = str(result.get("reason_code", "phase_timeline_update_failed"))
	push_error("Process A phase timeline failed: %s" % _process_a_timeline_failure)


func _enter_process_a_phase(phase_id: String) -> void:
	if _process_a_timeline == null or not _process_a_timeline_failure.is_empty():
		return
	_record_timeline_result(_process_a_timeline.call("enter_phase", phase_id))
	var save_phase := phase_id if phase_id in [
		"restore_barrier_entered", "save_intent_submitted", "save_capture_complete",
		"envelope_encode_complete", "atomic_write_complete", "save_readback_complete",
		"allowlisted_manifest_complete", "child_completion_attestation_complete",
	] else "runtime"
	_emit_role_heartbeat(phase_id, save_phase)


func _complete_process_a_phase(
	phase_id: String,
	evidence: Dictionary = {},
	reason_code: String = "ok"
) -> void:
	if _process_a_timeline == null or not _process_a_timeline_failure.is_empty():
		return
	_record_timeline_result(_process_a_timeline.call(
		"complete_phase",
		phase_id,
		true,
		reason_code,
		evidence
	))


func _close_process_a_failure_phases(result: Dictionary) -> void:
	if _process_a_timeline == null or bool(result.get("success", false)) \
			or not _process_a_timeline_failure.is_empty():
		return
	var failure_code := _safe_reason_code(str(result.get("failure_code", "role_failed")))
	var skipped_reason := "not_applicable_targeted_diagnostic" \
			if _targeted_owner_capture_diagnostic else "skipped_after_role_failure"
	var snapshot: Dictionary = _process_a_timeline.call("snapshot")
	var current_phase := str(snapshot.get("current_phase", ""))
	if not current_phase.is_empty():
		_record_timeline_result(_process_a_timeline.call(
			"complete_phase",
			current_phase,
			false,
			failure_code,
			{"failure_code": failure_code}
		))
	while _process_a_timeline_failure.is_empty():
		snapshot = _process_a_timeline.call("snapshot")
		var rows: Array = snapshot.get("phase_rows", [])
		var manifest_index := PROCESS_A_TIMELINE.PHASE_IDS.find("allowlisted_manifest_complete")
		if rows.size() >= manifest_index:
			break
		var skipped_phase := str(PROCESS_A_TIMELINE.PHASE_IDS[rows.size()])
		_record_timeline_result(_process_a_timeline.call("enter_phase", skipped_phase))
		if not _process_a_timeline_failure.is_empty():
			break
		_record_timeline_result(_process_a_timeline.call(
			"complete_phase",
			skipped_phase,
			false,
			skipped_reason,
			{"failure_code": failure_code}
		))


func _mark_process_a_timeline(method_name: String) -> void:
	if _process_a_timeline == null or not _process_a_timeline_failure.is_empty():
		return
	_record_timeline_result(_process_a_timeline.call(method_name))


func _update_process_a_save_timeline(save_path: String) -> void:
	if _process_a_timeline == null or not _process_a_timeline_failure.is_empty():
		return
	_record_timeline_result(_process_a_timeline.call("update_save_file", save_path))


func _emit_role_heartbeat(phase_id: String, save_phase: String = "runtime") -> void:
	if _role_heartbeat == null or not _role_heartbeat_failure.is_empty():
		return
	var context := _targeted_diagnostic_context
	if context.is_empty() and _active_main != null and is_instance_valid(_active_main):
		context = _runtime_context(_active_main)
	var world_time := 0
	var queue_revision := 0
	var coordinator := context.get("coordinator") as GameRuntimeCoordinator if not context.is_empty() else null
	if coordinator != null:
		var world := coordinator.world_session_state()
		world_time = maxi(0, int(round(world.game_time * 1000.0))) if world != null else 0
		var queue := coordinator.get_node_or_null("CardResolutionQueueRuntimeService")
		var queue_state: Dictionary = queue.call("queue_state_snapshot") \
				if queue != null and queue.has_method("queue_state_snapshot") else {}
		queue_revision = maxi(0, int(queue_state.get("revision", 0)))
	var write: Dictionary = _role_heartbeat.call("emit", {
		"phase": _safe_reason_code(phase_id),
		"world_time": world_time,
		"owner_index": _heartbeat_owner_index,
		"queue_revision": queue_revision,
		"save_phase": _safe_reason_code(save_phase),
	})
	if not bool(write.get("valid", false)):
		_role_heartbeat_failure = str(write.get("reason_code", "heartbeat_write_failed"))


func _advance_targeted_diagnostic_phase(
	phase_id: String,
	owner_index: int = -1,
	success: bool = true,
	reason_code: String = "ok"
) -> bool:
	if not _targeted_owner_capture_diagnostic or not _targeted_diagnostic_phase_failure.is_empty():
		return not _targeted_owner_capture_diagnostic
	var advanced := TARGETED_OWNER_DIAGNOSTIC.advance(
		_targeted_diagnostic_timeline,
		phase_id,
		owner_index,
		success,
		reason_code
	)
	if not bool(advanced.get("advanced", false)):
		_targeted_diagnostic_phase_failure = str(advanced.get("reason_code", "diagnostic_phase_transition_invalid"))
		return false
	_targeted_diagnostic_timeline = (advanced.get("timeline", {}) as Dictionary).duplicate(true)
	var sequence := (_targeted_diagnostic_timeline.get("phase_rows", []) as Array).size()
	var write := CHILD_ATTESTATION.write_owner_capture_phase_snapshot(
		str(_targeted_diagnostic_options.get("run_id", "")),
		sequence,
		_targeted_diagnostic_timeline
	)
	if not bool(write.get("valid", false)):
		_targeted_diagnostic_phase_failure = str(write.get("reason_code", "diagnostic_progress_sink_failed"))
		return false
	return true


func capture_owner_diagnostic_snapshot() -> Dictionary:
	return _safety_observation(_targeted_diagnostic_context) \
			if _targeted_owner_capture_diagnostic and not _targeted_diagnostic_context.is_empty() else {}


func record_owner_capture_progress(
	owner_index: int,
	_section_id: String,
	_owner_id: String,
	result_kind: String,
	reason_code: String
) -> void:
	if not _targeted_owner_capture_diagnostic:
		return
	_heartbeat_owner_index = owner_index
	_emit_role_heartbeat(
		"owner_capture_%s" % result_kind.to_lower(),
		"owner_capture"
	)
	match result_kind:
		"STARTED":
			_advance_targeted_diagnostic_phase("owner_capture_started", owner_index, true, "owner_capture_started")
		"CAPTURED":
			_advance_targeted_diagnostic_phase("owner_capture_succeeded", owner_index, true, "owner_capture_valid")
		"FAILED":
			_advance_targeted_diagnostic_phase(
				"owner_capture_failed",
				owner_index,
				true,
				_safe_owner_capture_reason_code(reason_code)
			)


func _diagnostic_pre_owner_failure(field: String, reason_code: String, expected: String, actual: String) -> Dictionary:
	return {
		"schema_version": 1,
		"failure_field": field.left(64),
		"reason_code": _safe_reason_code(reason_code),
		"expected_summary": expected.left(96),
		"actual_summary": actual.left(96),
		"private_payload_redacted": true,
	}


func _cleanup_active_runtime() -> bool:
	if _active_main == null or not is_instance_valid(_active_main):
		_active_main = null
		return true
	var runtime_to_release := _active_main
	runtime_to_release.queue_free()
	await process_frame
	await process_frame
	var released := not is_instance_valid(runtime_to_release)
	if released:
		_active_main = null
	return released


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
	_role_id = "targeted_owner_diagnostic" if bool(validation.get("targeted_owner_capture_diagnostic", false)) \
			else ("process_a" if str(validation.get("process_role", "")) == "producer" \
			else ("process_b" if str(validation.get("process_role", "")) == "consumer" else "process_c"))
	_role_heartbeat = ROLE_PROGRESS_HEARTBEAT.new()
	var heartbeat_init: Dictionary = _role_heartbeat.call(
		"initialize",
		str(validation.get("run_id", "")),
		_role_id,
		str(parsed.get("head_sha", "")),
		str(validation.get("timeout_policy_fingerprint", ""))
	)
	if not bool(heartbeat_init.get("valid", false)):
		push_error("Cold restore heartbeat initialization failed: %s" % str(heartbeat_init.get("reason_code", "heartbeat_identity_invalid")))
		quit(18)
		return
	if str(validation.get("process_role", "")) == "producer":
		_targeted_owner_capture_diagnostic = bool(validation.get("targeted_owner_capture_diagnostic", false))
		_process_a_rehearsal = bool(validation.get("process_a_rehearsal", false))
		if _targeted_owner_capture_diagnostic:
			_targeted_diagnostic_options = validation.duplicate(true)
			_targeted_diagnostic_options["repository_head"] = str(parsed.get("head_sha", ""))
			_targeted_diagnostic_timeline = TARGETED_OWNER_DIAGNOSTIC.new_timeline(
				str(validation.get("run_id", "")),
				str(parsed.get("head_sha", ""))
			)
			if not _advance_targeted_diagnostic_phase("diagnostic_started"):
				push_error("Targeted Owner diagnostic phase initialization failed: %s" % _targeted_diagnostic_phase_failure)
				quit(18)
				return
		_process_a_timeline = PROCESS_A_TIMELINE.new()
		_record_timeline_result(_process_a_timeline.call(
			"initialize",
			str(validation.get("run_id", "")),
			str(parsed.get("head_sha", "")),
			str(validation.get("scenario_fingerprint", "")),
			bool(validation.get("official", false)),
			_process_started_monotonic_ms
		))
		if not _process_a_timeline_failure.is_empty():
			quit(18)
			return
	_emit_role_heartbeat("child_bootstrap", "bootstrap")
	if not _role_heartbeat_failure.is_empty():
		push_error("Cold restore heartbeat write failed: %s" % _role_heartbeat_failure)
		quit(18)
		return
	if bool(validation.get("official", false)):
		var launch_authorization := await _authorize_official_launch(validation, str(parsed.get("head_sha", "")))
		if not bool(launch_authorization.get("authorized", false)):
			push_error("Cold restore launch rejected: %s" % str(launch_authorization.get("reason_code", "official_launch_unauthorized")))
			quit(2)
			return
		validation["official_count_consumed"] = true
	else:
		validation["official_count_consumed"] = false
		if bool(validation.get("targeted_owner_capture_diagnostic", false)):
			var diagnostic_authorization := await _authorize_targeted_owner_capture_diagnostic(validation, str(parsed.get("head_sha", "")))
			if not bool(diagnostic_authorization.get("authorized", false)):
				var private_binding_details := {
					"reason_code": str(diagnostic_authorization.get("reason_code", "targeted_owner_capture_unauthorized")),
					"failing_field": str(diagnostic_authorization.get("failing_field", "")),
					"field_reason": str(diagnostic_authorization.get("field_reason", "")),
					"expected_type": str(diagnostic_authorization.get("expected_type", "")),
					"actual_type": str(diagnostic_authorization.get("actual_type", "")),
					"safe_expected_fingerprint": str(diagnostic_authorization.get("safe_expected_fingerprint", "")),
					"safe_actual_fingerprint": str(diagnostic_authorization.get("safe_actual_fingerprint", "")),
				}
				push_error("Targeted Owner diagnostic launch rejected: %s" % JSON.stringify(private_binding_details))
				quit(2)
				return
		elif bool(validation.get("process_a_rehearsal", false)):
			var rehearsal_authorization := await _authorize_process_a_rehearsal(validation, str(parsed.get("head_sha", "")))
			if not bool(rehearsal_authorization.get("authorized", false)):
				push_error("Process A rehearsal launch rejected: %s" % str(rehearsal_authorization.get("reason_code", "process_a_rehearsal_unauthorized")))
				quit(2)
				return
	_complete_process_a_phase("child_bootstrap", {"official": bool(validation.get("official", false))})
	var started_ms := Time.get_ticks_msec()
	var result: Dictionary = await _run_role(validation, str(parsed.get("head_sha", "")))
	result["elapsed_ms"] = maxi(0, Time.get_ticks_msec() - started_ms)
	_close_process_a_failure_phases(result)
	_enter_process_a_phase("allowlisted_manifest_complete")
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
	_mark_process_a_timeline("mark_allowlisted_manifest_written")
	_complete_process_a_phase("allowlisted_manifest_complete", {
		"manifest_sha256": str(manifest_write.get("sha256", "")),
	})
	_enter_process_a_phase("child_completion_attestation_complete")
	var role_success := bool(manifest.get("success", false))
	var diagnostic_sha256 := str(result.get("_targeted_owner_capture_diagnostic_sha256", ""))
	var rehearsal_completion_sha256 := str(result.get("_process_a_rehearsal_completion_sha256", ""))
	var role_product_blocker := "TARGETED_OWNER_CAPTURE_DIAGNOSTIC_SHA256:%s" % diagnostic_sha256 \
			if _targeted_owner_capture_diagnostic and _is_lower_sha256(diagnostic_sha256) \
			else _product_blocker(
				role_success,
				int(manifest.get("queue_entry_count", 0)),
				str(manifest.get("failure_code", "role_failed"))
			)
	var role_attestation := CHILD_ATTESTATION.build({
		"run_id": str(validation.get("run_id", "")),
		"role": str(validation.get("process_role", "")),
		"repository_head": str(parsed.get("head_sha", "")),
		"scenario_fingerprint": str(validation.get("scenario_fingerprint", "")),
		"official": bool(validation.get("official", false)),
		"formal": false,
		"qualification_completed": true,
		"qualification_green": role_success,
		"product_blocker": role_product_blocker,
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
		"final_reason_code": "targeted_owner_capture_diagnostic_sha256_%s" % diagnostic_sha256 \
				if _targeted_owner_capture_diagnostic and _is_lower_sha256(diagnostic_sha256) \
				else ("process_a_rehearsal_completion_sha256_%s" % rehearsal_completion_sha256 \
						if _process_a_rehearsal and _is_lower_sha256(rehearsal_completion_sha256) \
						else ("role_completed" if role_success else str(manifest.get("failure_code", "role_failed")))),
		"child_ready_to_exit": true,
	})
	var role_attestation_write := CHILD_ATTESTATION.write_completion(role_attestation)
	if not bool(role_attestation_write.get("valid", false)):
		push_error("Cold restore role attestation failed: %s" % str(role_attestation_write.get("reason_code", "child_attestation_write_failed")))
		quit(_evidence_exit_code(role_attestation_write))
		return
	_mark_process_a_timeline("mark_child_completion_written")
	_complete_process_a_phase("child_completion_attestation_complete", {
		"attestation_sha256": str(role_attestation_write.get("sha256", "")),
	})
	_enter_process_a_phase("runtime_cleanup_complete")
	var runtime_cleanup_green := await _cleanup_active_runtime()
	_complete_process_a_phase("runtime_cleanup_complete", {"active_main_released": runtime_cleanup_green})
	if not runtime_cleanup_green:
		push_error("Cold restore runtime cleanup did not release the task-owned main scene")
		quit(19)
		return
	_enter_process_a_phase("quit_requested")
	_mark_process_a_timeline("mark_quit_requested")
	_complete_process_a_phase("quit_requested", {"exit_code": 0})
	print("COLD_RESTORE_MANIFEST|%s" % JSON.stringify(manifest))
	quit(0)


static func contract_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"driver_id": "alpha04c_cold_restore_vertical_slice_v4",
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
		"targeted_owner_capture_diagnostic": true,
		"targeted_owner_capture_diagnostic_writes_save": false,
		"targeted_owner_capture_diagnostic_touches_official_claim": false,
		"targeted_owner_capture_phase_count": TARGETED_OWNER_CAPTURE_PHASES.size(),
		"targeted_owner_capture_diagnostic_phase_count": TARGETED_OWNER_DIAGNOSTIC.PHASES.size(),
		"role_timeout_policy_id": "ColdRestoreRoleTimeoutPolicyV1",
		"process_a_rehearsal_exact_once": true,
		"process_a_rehearsal_official_claim_created": false,
		"caller_boolean_authorization_accepted": false,
	}


static func validate_options(options: Dictionary) -> Dictionary:
	var run_id := str(options.get("run_id", ""))
	var process_role := str(options.get("process_role", ""))
	var non_official_process_a := bool(options.get("non_official_process_a", false))
	var targeted_owner_capture_diagnostic := bool(options.get("targeted_owner_capture_diagnostic", false))
	var process_a_rehearsal := bool(options.get("process_a_rehearsal", false))
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
	var launch_attestation_path := str(options.get("launch_attestation_path", ""))
	var launch_nonce := str(options.get("launch_nonce", ""))
	var targeted_diagnostic_ledger_path := str(options.get("targeted_diagnostic_ledger_path", ""))
	var targeted_diagnostic_ledger_fingerprint := str(options.get("targeted_diagnostic_ledger_fingerprint", ""))
	var rehearsal_ledger_path := str(options.get("rehearsal_ledger_path", ""))
	var rehearsal_ledger_fingerprint := str(options.get("rehearsal_ledger_fingerprint", ""))
	if non_official_process_a:
		if process_role != "producer" or not official_claim_path.is_empty():
			return {"valid": false, "reason_code": "non_official_process_a_authority_state_invalid"}
		if targeted_owner_capture_diagnostic and process_a_rehearsal:
			return {"valid": false, "reason_code": "non_official_process_a_mode_conflict"}
		if targeted_owner_capture_diagnostic and process_role != "producer":
			return {"valid": false, "reason_code": "targeted_owner_capture_role_invalid"}
		if targeted_owner_capture_diagnostic and not _is_targeted_owner_capture_run_id(run_id):
			return {"valid": false, "reason_code": "targeted_owner_capture_run_id_invalid"}
		if targeted_owner_capture_diagnostic \
				and run_id != _authorization_run_id(
					_targeted_authorization_name(), head_sha
				):
			return {"valid": false, "reason_code": "targeted_owner_capture_run_head_mismatch"}
		if targeted_owner_capture_diagnostic:
			if targeted_diagnostic_ledger_path.is_empty() \
					or not targeted_diagnostic_ledger_path.is_absolute_path() \
					or not _is_lower_sha256(targeted_diagnostic_ledger_fingerprint) \
					or launch_attestation_path.is_empty() \
					or not launch_attestation_path.is_absolute_path() \
					or launch_nonce.length() != 32 \
					or not _is_lower_hex(launch_nonce):
				return {"valid": false, "reason_code": "targeted_owner_capture_authorization_invalid"}
		if process_a_rehearsal:
			if run_id != _authorization_run_id(
				"process_a_save_completion_rehearsal_v1", head_sha
			):
				return {"valid": false, "reason_code": "process_a_rehearsal_run_head_mismatch"}
			if rehearsal_ledger_path.is_empty() or not rehearsal_ledger_path.is_absolute_path() \
					or not _is_lower_sha256(rehearsal_ledger_fingerprint) \
					or launch_attestation_path.is_empty() \
					or not launch_attestation_path.is_absolute_path() \
					or launch_nonce.length() != 32 \
					or not _is_lower_hex(launch_nonce) \
					or not targeted_diagnostic_ledger_path.is_empty() \
					or not targeted_diagnostic_ledger_fingerprint.is_empty():
				return {"valid": false, "reason_code": "process_a_rehearsal_authorization_invalid"}
		elif not rehearsal_ledger_path.is_empty() or not rehearsal_ledger_fingerprint.is_empty() \
				or (not targeted_owner_capture_diagnostic \
					and (not targeted_diagnostic_ledger_path.is_empty() \
						or not targeted_diagnostic_ledger_fingerprint.is_empty())) \
				or (not targeted_owner_capture_diagnostic \
					and (not launch_attestation_path.is_empty() or not launch_nonce.is_empty())):
			return {"valid": false, "reason_code": "process_a_rehearsal_authorization_forbidden"}
	else:
		if targeted_owner_capture_diagnostic or process_a_rehearsal \
				or not rehearsal_ledger_path.is_empty() or not rehearsal_ledger_fingerprint.is_empty() \
				or not targeted_diagnostic_ledger_path.is_empty() \
				or not targeted_diagnostic_ledger_fingerprint.is_empty():
			return {"valid": false, "reason_code": "targeted_owner_capture_official_forbidden"}
		if official_claim_path.is_empty() or not official_claim_path.is_absolute_path():
			return {"valid": false, "reason_code": "official_claim_path_invalid"}
		if launch_attestation_path.is_empty() or not launch_attestation_path.is_absolute_path():
			return {"valid": false, "reason_code": "launch_attestation_path_invalid"}
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
	if targeted_owner_capture_diagnostic \
			and scenario_fingerprint != TARGETED_OWNER_CAPTURE_SCENARIO_FINGERPRINT:
		return {"valid": false, "reason_code": "targeted_owner_capture_scenario_fingerprint_invalid"}
	if process_a_rehearsal and scenario_fingerprint != TARGETED_OWNER_CAPTURE_SCENARIO_FINGERPRINT:
		return {"valid": false, "reason_code": "process_a_rehearsal_scenario_fingerprint_invalid"}
	var timeout_policy_fingerprint := str(options.get("timeout_policy_fingerprint", ""))
	if not _is_lower_sha256(timeout_policy_fingerprint):
		return {"valid": false, "reason_code": "timeout_policy_fingerprint_invalid"}
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
		"targeted_diagnostic_ledger_path": targeted_diagnostic_ledger_path,
		"targeted_diagnostic_ledger_fingerprint": targeted_diagnostic_ledger_fingerprint,
		"rehearsal_ledger_path": rehearsal_ledger_path,
		"rehearsal_ledger_fingerprint": rehearsal_ledger_fingerprint,
		"expected_queue_resolution_id": expected_resolution_id,
		"expected_queue_stable_target_fingerprint": expected_stable_fingerprint,
		"scenario_fingerprint": scenario_fingerprint,
		"timeout_policy_fingerprint": timeout_policy_fingerprint,
		"official": not non_official_process_a,
		"non_official_process_a": non_official_process_a,
		"targeted_owner_capture_diagnostic": targeted_owner_capture_diagnostic,
		"process_a_rehearsal": process_a_rehearsal,
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
			or not str(options.get("launch_nonce", "")).is_empty() \
			or not str(options.get("targeted_diagnostic_ledger_path", "")).is_empty() \
			or not str(options.get("targeted_diagnostic_ledger_fingerprint", "")).is_empty() \
			or not str(options.get("rehearsal_ledger_path", "")).is_empty() \
			or not str(options.get("rehearsal_ledger_fingerprint", "")).is_empty() \
			or bool(options.get("process_a_rehearsal", false)) \
			or bool(options.get("non_official_process_a", false)):
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


static func _is_targeted_owner_capture_run_id(value: String) -> bool:
	var entry := _authorization_contract_entry(_targeted_authorization_name())
	var prefix := str(entry.get("run_id_prefix", ""))
	if prefix.is_empty() or not value.begins_with("%s-" % prefix):
		return false
	var suffix := value.trim_prefix("%s-" % prefix)
	return suffix.length() == 12 and _is_lower_hex(suffix)


func _authorize_official_launch(options: Dictionary, head_sha: String) -> Dictionary:
	var authorization := _authorization_contract_entry("official_attempt_2")
	if authorization.is_empty():
		return {"authorized": false, "reason_code": "authorization_contract_invalid"}
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
	for integer_field in [
		"schema_version", "attempt_number", "challenge_depth", "seed",
		"local_player_count", "ai_player_count", "orchestrator_schema_version",
		"orchestrator_process_id", "authorized_official_count",
		"official_count_before", "official_count_after",
	]:
		if typeof(claim.get(integer_field)) != TYPE_INT:
			return {"authorized": false, "reason_code": "official_claim_integer_type_invalid"}
	var timeout_entries := claim.get("process_role_timeouts", {}) as Dictionary
	var timeout_shape_valid := _has_exact_fields(timeout_entries, ["process_a", "process_b", "process_c"])
	if timeout_shape_valid:
		var expected_timeouts := {
			"process_a": [180, 60], "process_b": [360, 60], "process_c": [180, 30],
		}
		for timeout_role in ["process_a", "process_b", "process_c"]:
			var timeout_entry := timeout_entries.get(timeout_role, {}) as Dictionary
			if not _has_exact_fields(timeout_entry, ["absolute_timeout_seconds", "no_progress_timeout_seconds"]) \
					or typeof(timeout_entry.get("absolute_timeout_seconds")) != TYPE_INT \
					or typeof(timeout_entry.get("no_progress_timeout_seconds")) != TYPE_INT \
					or int(timeout_entry.get("absolute_timeout_seconds", 0)) != int(expected_timeouts[timeout_role][0]) \
					or int(timeout_entry.get("no_progress_timeout_seconds", 0)) != int(expected_timeouts[timeout_role][1]):
				timeout_shape_valid = false
				break
	var common_dir := _resolve_git_common_dir()
	var attempt_1_path := _normalize_absolute_path(common_dir.path_join(
		str(authorization.get("attempt_1_claim_relative_path", ""))
	))
	var attempt_1_green := not attempt_1_path.is_empty() and FileAccess.file_exists(attempt_1_path) \
			and FileAccess.get_file_as_string(attempt_1_path).sha256_text().to_lower() \
				== str(authorization.get("attempt_1_claim_sha256", ""))
	var orchestrator_script_sha256 := FileAccess.get_sha256(
		"res://scripts/tools/cold_restore_vertical_slice_orchestrator.ps1"
	).to_lower()
	if int(claim.get("schema_version", 0)) != OFFICIAL_CLAIM_SCHEMA_VERSION \
			or str(claim.get("claim_id", "")) != "OfficialAttemptClaimV2" \
			or int(claim.get("attempt_number", 0)) != 2 \
			or str(claim.get("authorization_id", "")) != str(authorization.get("authorization_id", "")) \
			or not _is_utc_timestamp(claim.get("created_at_utc")) \
			or str(claim.get("run_id", "")) != str(options.get("run_id", "")) \
			or str(claim.get("source_head", "")) != head_sha \
			or str(claim.get("rehearsal_green_head", "")) != head_sha \
			or int(claim.get("challenge_depth", 0)) != ACCEPTANCE_CHALLENGE_DEPTH \
			or int(claim.get("seed", 0)) != ACCEPTANCE_SEED \
			or int(claim.get("local_player_count", 0)) != ACCEPTANCE_LOCAL_PLAYER_COUNT \
			or int(claim.get("ai_player_count", 0)) != ACCEPTANCE_AI_PLAYER_COUNT \
			or str(claim.get("scenario_fingerprint", "")) != str(options.get("scenario_fingerprint", "")) \
			or str(claim.get("timeout_policy_sha256", "")) != str(options.get("timeout_policy_fingerprint", "")) \
			or not _is_lower_sha256(str(claim.get("prerequisite_evidence_fingerprint", ""))) \
			or not _is_lower_sha256(str(claim.get("preclaim_runtime_freeze_fingerprint", ""))) \
			or not timeout_shape_valid \
			or str(claim.get("rehearsal_run_id", "")) != _authorization_run_id(
				"process_a_save_completion_rehearsal_v1", head_sha
			) \
			or not _is_lower_sha256(str(claim.get("rehearsal_evidence_fingerprint", ""))) \
			or not _is_lower_sha256(str(claim.get("rehearsal_outcome_sha256", ""))) \
			or not _is_lower_sha256(str(claim.get("rehearsal_admission_sha256", ""))) \
			or not _is_lower_sha256(str(claim.get("rehearsal_launch_sha256", ""))) \
			or not _is_lower_sha256(str(claim.get("rehearsal_completion_sha256", ""))) \
			or not _is_lower_sha256(str(claim.get("rehearsal_child_attestation_sha256", ""))) \
			or not _is_lower_sha256(str(claim.get("rehearsal_parent_attestation_sha256", ""))) \
			or str(claim.get("attempt_1_claim_relative_path", "")) \
				!= str(authorization.get("attempt_1_claim_relative_path", "")).trim_prefix(
					"codex/cold_restore_v3/"
				) \
			or str(claim.get("attempt_1_claim_sha256", "")) \
				!= str(authorization.get("attempt_1_claim_sha256", "")) \
			or not attempt_1_green \
			or str(claim.get("orchestrator_id", "")) != "alpha04c_cold_restore_vertical_slice_orchestrator_v4" \
			or int(claim.get("orchestrator_schema_version", 0)) != SCHEMA_VERSION \
			or not _is_lower_sha256(orchestrator_script_sha256) \
			or str(claim.get("orchestrator_script_sha256", "")) != orchestrator_script_sha256 \
			or str(claim.get("claim_nonce", "")).length() != 32 \
			or not _is_lower_hex(str(claim.get("claim_nonce", ""))) \
			or int(claim.get("orchestrator_process_id", 0)) <= 0 \
			or not _is_positive_decimal(str(claim.get("orchestrator_creation_time_utc_ticks", ""))) \
			or str(claim.get("status", "")) != "consumed" \
			or int(claim.get("authorized_official_count", 0)) != 1 \
			or int(claim.get("official_count_before", -1)) != 1 \
			or int(claim.get("official_count_after", 0)) != 2:
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
			or str(attestation.get("authorization_id", "")) != str(authorization.get("authorization_id", "")) \
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


func _authorize_targeted_owner_capture_diagnostic(options: Dictionary, head_sha: String) -> Dictionary:
	var authorization := _authorization_contract_entry(_targeted_authorization_name())
	if authorization.is_empty():
		return {"authorized": false, "reason_code": "authorization_contract_invalid"}
	var ledger_path := _normalize_absolute_path(str(options.get("targeted_diagnostic_ledger_path", "")))
	var expected_path := _resolve_targeted_diagnostic_ledger_path()
	if ledger_path.is_empty() or expected_path.is_empty() \
			or ledger_path.to_lower() != expected_path.to_lower():
		return {"authorized": false, "reason_code": "targeted_owner_capture_ledger_path_mismatch"}
	if not FileAccess.file_exists(ledger_path):
		return {"authorized": false, "reason_code": "targeted_owner_capture_ledger_missing"}
	var ledger_text := FileAccess.get_file_as_string(ledger_path)
	var ledger_fingerprint := ledger_text.sha256_text().to_lower()
	var binding_result: Dictionary = TARGETED_LEDGER_BINDING_VALIDATOR.validate_ledger_text(
		ledger_text,
		options
	)
	if not bool(binding_result.get("valid", false)):
		return {
			"authorized": false,
			"reason_code": "targeted_owner_capture_ledger_binding_invalid",
			"failing_field": str(binding_result.get("failing_field", "unknown")),
			"field_reason": str(binding_result.get("field_reason", "binding_failed")),
			"expected_type": str(binding_result.get("expected_type", "")),
			"actual_type": str(binding_result.get("actual_type", "")),
			"safe_expected_fingerprint": str(binding_result.get("safe_expected_fingerprint", "")),
			"safe_actual_fingerprint": str(binding_result.get("safe_actual_fingerprint", "")),
		}
	var ledger_variant: Variant = JSON.parse_string(ledger_text)
	var ledger := ledger_variant as Dictionary
	var attestation_path := _normalize_absolute_path(str(options.get("launch_attestation_path", "")))
	var deadline_ms := Time.get_ticks_msec() + 10000
	while not FileAccess.file_exists(attestation_path) and Time.get_ticks_msec() < deadline_ms:
		await create_timer(0.025).timeout
	if not FileAccess.file_exists(attestation_path):
		return {"authorized": false, "reason_code": "targeted_owner_capture_launch_attestation_missing"}
	var attestation_variant: Variant = JSON.parse_string(FileAccess.get_file_as_string(attestation_path))
	if not (attestation_variant is Dictionary):
		return {"authorized": false, "reason_code": "targeted_owner_capture_launch_attestation_invalid"}
	var attestation := attestation_variant as Dictionary
	if not _has_exact_fields(attestation, LAUNCH_ATTESTATION_FIELDS):
		return {"authorized": false, "reason_code": "targeted_owner_capture_launch_attestation_field_set_invalid"}
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
		str(options.get("run_id", "")), "producer", int(ledger.get("orchestrator_process_id", 0))
	)
	if int(attestation.get("schema_version", 0)) != LAUNCH_ATTESTATION_SCHEMA_VERSION \
			or str(attestation.get("authorization_id", "")) != str(authorization.get("authorization_id", "")) \
			or str(attestation.get("claim_fingerprint", "")) != ledger_fingerprint \
			or str(attestation.get("claim_nonce", "")) != str(ledger.get("claim_nonce", "")) \
			or str(attestation.get("source_head_sha", "")) != head_sha \
			or str(attestation.get("scenario_fingerprint", "")) != str(options.get("scenario_fingerprint", "")) \
			or str(attestation.get("run_id", "")) != str(options.get("run_id", "")) \
			or str(attestation.get("process_role", "")) != "producer" \
			or str(attestation.get("launch_nonce", "")) != str(ledger.get("launch_nonce", "")) \
			or str(attestation.get("status", "")) != "authorized" \
			or orchestrator_process_id != int(ledger.get("orchestrator_process_id", 0)) \
			or str(attestation.get("orchestrator_creation_time_utc_ticks", "")) \
				!= str(ledger.get("orchestrator_creation_time_utc_ticks", "")) \
			or wrapper_process_id <= 0 or engine_process_id != OS.get_process_id() \
			or not process_relation_valid or expected_attestation_path.is_empty() \
			or attestation_path.to_lower() != expected_attestation_path.to_lower():
		return {"authorized": false, "reason_code": "targeted_owner_capture_launch_attestation_binding_invalid"}
	for ticks_field in [
		"orchestrator_creation_time_utc_ticks",
		"wrapper_creation_time_utc_ticks",
		"engine_creation_time_utc_ticks",
	]:
		if not _is_positive_decimal(str(attestation.get(ticks_field, ""))):
			return {"authorized": false, "reason_code": "targeted_owner_capture_launch_creation_time_invalid"}
	return {
		"authorized": true,
		"reason_code": "ok",
		"fingerprint": ledger_fingerprint,
		"binding_check_count": int(binding_result.get("check_count", 0)),
		"binding_pass_count": int(binding_result.get("pass_count", 0)),
	}


func _authorize_process_a_rehearsal(options: Dictionary, head_sha: String) -> Dictionary:
	var authorization := _authorization_contract_entry("process_a_save_completion_rehearsal_v1")
	var official_authorization := _authorization_contract_entry("official_attempt_2")
	if authorization.is_empty() or official_authorization.is_empty():
		return {"authorized": false, "reason_code": "authorization_contract_invalid"}
	var ledger_path := _normalize_absolute_path(str(options.get("rehearsal_ledger_path", "")))
	var expected_path := _resolve_rehearsal_ledger_path()
	if ledger_path.is_empty() or expected_path.is_empty() \
			or ledger_path.to_lower() != expected_path.to_lower():
		return {"authorized": false, "reason_code": "process_a_rehearsal_ledger_path_mismatch"}
	if not FileAccess.file_exists(ledger_path):
		return {"authorized": false, "reason_code": "process_a_rehearsal_ledger_missing"}
	var ledger_text := FileAccess.get_file_as_string(ledger_path)
	var ledger_variant: Variant = JSON.parse_string(ledger_text)
	if not (ledger_variant is Dictionary):
		return {"authorized": false, "reason_code": "process_a_rehearsal_ledger_invalid"}
	var ledger := ledger_variant as Dictionary
	if not _has_exact_fields(ledger, REHEARSAL_LEDGER_FIELDS):
		return {"authorized": false, "reason_code": "process_a_rehearsal_ledger_field_set_invalid"}
	var ledger_fingerprint := ledger_text.sha256_text().to_lower()
	if ledger_fingerprint != str(options.get("rehearsal_ledger_fingerprint", "")) \
			or typeof(ledger.get("schema_version")) != TYPE_INT \
			or int(ledger.get("schema_version", 0)) != 3 \
			or str(ledger.get("ledger_id", "")) != "ProcessARehearsalAdmissionLedgerV3" \
			or str(ledger.get("contract_id", "")) != "Alpha04C.ProcessARehearsalAdmissionContractV1" \
			or str(ledger.get("authorization_id", "")) != str(authorization.get("authorization_id", "")) \
			or str(ledger.get("status", "")) != "admitted" \
			or str(ledger.get("run_id", "")) != str(options.get("run_id", "")) \
			or str(ledger.get("repository_head", "")) != head_sha \
			or str(ledger.get("scenario_fingerprint", "")) != str(options.get("scenario_fingerprint", "")) \
			or str(ledger.get("timeout_policy_fingerprint", "")) != str(options.get("timeout_policy_fingerprint", "")) \
			or not _is_lower_sha256(str(ledger.get("prerequisite_evidence_fingerprint", ""))) \
			or typeof(ledger.get("challenge_depth")) != TYPE_INT \
			or int(ledger.get("challenge_depth", 0)) != ACCEPTANCE_CHALLENGE_DEPTH \
			or typeof(ledger.get("seed")) != TYPE_INT \
			or int(ledger.get("seed", 0)) != ACCEPTANCE_SEED \
			or typeof(ledger.get("local_player_count")) != TYPE_INT \
			or int(ledger.get("local_player_count", 0)) != 1 \
			or typeof(ledger.get("ai_player_count")) != TYPE_INT \
			or int(ledger.get("ai_player_count", 0)) != 3 \
			or typeof(ledger.get("rehearsal_only")) != TYPE_BOOL \
			or not bool(ledger.get("rehearsal_only", false)) \
			or typeof(ledger.get("nonofficial")) != TYPE_BOOL \
			or not bool(ledger.get("nonofficial", false)) \
			or typeof(ledger.get("official")) != TYPE_BOOL \
			or bool(ledger.get("official", true)) \
			or typeof(ledger.get("formal")) != TYPE_BOOL \
			or bool(ledger.get("formal", true)) \
			or typeof(ledger.get("official_authorization_consumed")) != TYPE_BOOL \
			or bool(ledger.get("official_authorization_consumed", true)) \
			or typeof(ledger.get("authorized_rehearsal_count")) != TYPE_INT \
			or int(ledger.get("authorized_rehearsal_count", 0)) != 1 \
			or typeof(ledger.get("rehearsal_count_before")) != TYPE_INT \
			or int(ledger.get("rehearsal_count_before", -1)) != 0 \
			or typeof(ledger.get("rehearsal_count_after")) != TYPE_INT \
			or int(ledger.get("rehearsal_count_after", 0)) != 1 \
			or str(ledger.get("admission_evidence_id", "")) != "TargetedOwnerCaptureDiagnosticV2" \
			or not _is_targeted_owner_capture_run_id(str(ledger.get("admission_evidence_run_id", ""))) \
			or not _is_lower_sha256(str(ledger.get("admission_evidence_sha256", ""))) \
			or not _is_lower_sha256(str(ledger.get("admission_evidence_fingerprint", ""))) \
			or typeof(ledger.get("admission_evidence_green")) != TYPE_BOOL \
			or not bool(ledger.get("admission_evidence_green", false)) \
			or not _is_lower_sha256(str(ledger.get("diagnostic_quota_ledger_sha256", ""))) \
			or not _is_lower_sha256(str(ledger.get("diagnostic_launch_attestation_sha256", ""))) \
			or not _is_lower_sha256(str(ledger.get("diagnostic_manifest_sha256", ""))) \
			or typeof(ledger.get("diagnostic_engine_process_id")) != TYPE_INT \
			or int(ledger.get("diagnostic_engine_process_id", 0)) <= 0 \
			or not _is_positive_decimal(str(ledger.get("diagnostic_engine_creation_time_utc_ticks", ""))) \
			or not _is_lower_sha256(str(ledger.get("diagnostic_child_attestation_sha256", ""))) \
			or not _is_lower_sha256(str(ledger.get("diagnostic_child_attestation_fingerprint", ""))) \
			or not _is_lower_sha256(str(ledger.get("diagnostic_parent_attestation_sha256", ""))) \
			or not _is_lower_sha256(str(ledger.get("diagnostic_stdout_sha256", ""))) \
			or not _is_lower_sha256(str(ledger.get("diagnostic_stderr_sha256", ""))) \
			or not _is_lower_sha256(str(ledger.get("diagnostic_bootstrap_admission_sha256", ""))) \
			or not _is_lower_sha256(str(ledger.get("diagnostic_bootstrap_admission_fingerprint", ""))) \
			or not _is_lower_sha256(str(ledger.get("diagnostic_prequota_attestation_sha256", ""))) \
			or not _is_lower_sha256(str(ledger.get("diagnostic_prequota_attestation_fingerprint", ""))) \
			or str(ledger.get("official_attempt_1_claim_sha256", "")) \
				!= str(official_authorization.get("attempt_1_claim_sha256", "")) \
			or typeof(ledger.get("official_attempt_1_claim_immutable")) != TYPE_BOOL \
			or not bool(ledger.get("official_attempt_1_claim_immutable", false)) \
			or typeof(ledger.get("official_attempt_2_claim_absent")) != TYPE_BOOL \
			or not bool(ledger.get("official_attempt_2_claim_absent", false)) \
			or typeof(ledger.get("official_claim_inventory_count")) != TYPE_INT \
			or int(ledger.get("official_claim_inventory_count", 0)) != 1 \
			or not _is_lower_sha256(str(ledger.get("official_claim_inventory_fingerprint", ""))) \
			or str(ledger.get("process_role", "")) != "producer" \
			or typeof(ledger.get("orchestrator_process_id")) != TYPE_INT \
			or int(ledger.get("orchestrator_process_id", 0)) <= 0 \
			or not _is_positive_decimal(str(ledger.get("orchestrator_creation_time_utc_ticks", ""))) \
			or str(ledger.get("claim_nonce", "")).length() != 32 \
			or not _is_lower_hex(str(ledger.get("claim_nonce", ""))) \
			or str(ledger.get("launch_nonce", "")) != str(options.get("launch_nonce", "")) \
			or not _is_lower_sha256(str(ledger.get("ledger_fingerprint", ""))):
		return {"authorized": false, "reason_code": "process_a_rehearsal_ledger_binding_invalid"}
	var attestation_path := _normalize_absolute_path(str(options.get("launch_attestation_path", "")))
	var deadline_ms := Time.get_ticks_msec() + 10000
	while not FileAccess.file_exists(attestation_path) and Time.get_ticks_msec() < deadline_ms:
		await create_timer(0.025).timeout
	if not FileAccess.file_exists(attestation_path):
		return {"authorized": false, "reason_code": "process_a_rehearsal_launch_attestation_missing"}
	var attestation_variant: Variant = JSON.parse_string(FileAccess.get_file_as_string(attestation_path))
	if not (attestation_variant is Dictionary):
		return {"authorized": false, "reason_code": "process_a_rehearsal_launch_attestation_invalid"}
	var attestation := attestation_variant as Dictionary
	if not _has_exact_fields(attestation, LAUNCH_ATTESTATION_FIELDS):
		return {"authorized": false, "reason_code": "process_a_rehearsal_launch_attestation_field_set_invalid"}
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
		str(options.get("run_id", "")), "producer", int(ledger.get("orchestrator_process_id", 0))
	)
	if int(attestation.get("schema_version", 0)) != LAUNCH_ATTESTATION_SCHEMA_VERSION \
			or str(attestation.get("authorization_id", "")) != str(authorization.get("authorization_id", "")) \
			or str(attestation.get("claim_fingerprint", "")) != ledger_fingerprint \
			or str(attestation.get("claim_nonce", "")) != str(ledger.get("claim_nonce", "")) \
			or str(attestation.get("source_head_sha", "")) != head_sha \
			or str(attestation.get("scenario_fingerprint", "")) != str(options.get("scenario_fingerprint", "")) \
			or str(attestation.get("run_id", "")) != str(options.get("run_id", "")) \
			or str(attestation.get("process_role", "")) != "producer" \
			or str(attestation.get("launch_nonce", "")) != str(ledger.get("launch_nonce", "")) \
			or str(attestation.get("status", "")) != "authorized" \
			or orchestrator_process_id != int(ledger.get("orchestrator_process_id", 0)) \
			or str(attestation.get("orchestrator_creation_time_utc_ticks", "")) \
				!= str(ledger.get("orchestrator_creation_time_utc_ticks", "")) \
			or wrapper_process_id <= 0 \
			or engine_process_id != OS.get_process_id() \
			or not process_relation_valid \
			or expected_attestation_path.is_empty() \
			or attestation_path.to_lower() != expected_attestation_path.to_lower():
		return {"authorized": false, "reason_code": "process_a_rehearsal_launch_attestation_binding_invalid"}
	for ticks_field in [
		"orchestrator_creation_time_utc_ticks",
		"wrapper_creation_time_utc_ticks",
		"engine_creation_time_utc_ticks",
	]:
		if not _is_positive_decimal(str(attestation.get(ticks_field, ""))):
			return {"authorized": false, "reason_code": "process_a_rehearsal_launch_creation_time_invalid"}
	return {"authorized": true, "reason_code": "ok", "fingerprint": ledger_fingerprint}


static func _authorization_contract_entry(entry_name: String) -> Dictionary:
	return AUTHORIZATION_CONTRACT.entry(entry_name)


static func _targeted_authorization_name() -> String:
	return AUTHORIZATION_CONTRACT.current_targeted_authorization_name()


static func _authorization_run_id(entry_name: String, repository_head: String) -> String:
	if repository_head.length() != 40 or not _is_lower_hex(repository_head):
		return ""
	var entry := _authorization_contract_entry(entry_name)
	var prefix := str(entry.get("run_id_prefix", ""))
	if prefix.is_empty():
		return ""
	return "%s-%s" % [prefix, repository_head.left(12)]


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


static func _is_utc_timestamp(value: Variant) -> bool:
	if not (value is String):
		return false
	var text := str(value)
	if not text.ends_with("Z") or text.length() < 20 or text.length() > 40:
		return false
	var regex := RegEx.new()
	if regex.compile("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]{1,7})?Z$") != OK:
		return false
	return regex.search(text) != null and Time.get_unix_time_from_datetime_string(text) > 0


static func _normalize_absolute_path(value: String) -> String:
	if value.is_empty() or not value.is_absolute_path():
		return ""
	return value.replace("\\", "/").simplify_path().trim_suffix("/")


static func _resolve_official_claim_path() -> String:
	var common_dir := _resolve_git_common_dir()
	var authorization := _authorization_contract_entry("official_attempt_2")
	if common_dir.is_empty() or authorization.is_empty():
		return ""
	return _normalize_absolute_path(common_dir.path_join(str(authorization.get("claim_path", ""))))


static func _resolve_rehearsal_ledger_path() -> String:
	var common_dir := _resolve_git_common_dir()
	var authorization := _authorization_contract_entry("process_a_save_completion_rehearsal_v1")
	if common_dir.is_empty() or authorization.is_empty():
		return ""
	return _normalize_absolute_path(common_dir.path_join(
		str(authorization.get("quota_ledger_relative_path", ""))
	))


static func _resolve_targeted_diagnostic_ledger_path() -> String:
	var common_dir := _resolve_git_common_dir()
	var authorization := _authorization_contract_entry(_targeted_authorization_name())
	if common_dir.is_empty() or authorization.is_empty():
		return ""
	return _normalize_absolute_path(common_dir.path_join(
		str(authorization.get("quota_ledger_relative_path", ""))
	))


static func _resolve_targeted_diagnostic_evidence_root() -> String:
	var common_dir := _resolve_git_common_dir()
	var authorization := _authorization_contract_entry(_targeted_authorization_name())
	if common_dir.is_empty() or authorization.is_empty():
		return ""
	return _normalize_absolute_path(common_dir.path_join(
		str(authorization.get("evidence_root_relative_path", ""))
	))


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
	var evidence_root := ""
	if _is_targeted_owner_capture_run_id(run_id):
		evidence_root = _resolve_targeted_diagnostic_evidence_root()
		var environment_root := _normalize_absolute_path(
			OS.get_environment("SPACE_SYNDICATE_COLD_RESTORE_EVIDENCE_ROOT")
		)
		if evidence_root.is_empty() or environment_root != evidence_root:
			return ""
	else:
		var project_root := _normalize_absolute_path(ProjectSettings.globalize_path("res://"))
		evidence_root = _normalize_absolute_path(project_root.path_join(
			".godot/cold_restore_attestation_v1/%s" % run_id
		))
	return _normalize_absolute_path(evidence_root.path_join(
		"launch/orchestrator-%d/%s.authorized.json" % [orchestrator_process_id, role]
	))




static func sanitize_public_manifest(source: Dictionary) -> Dictionary:
	var result := {
		"schema_version": SCHEMA_VERSION,
		"visibility_scope": "qa_allowlisted",
		"run_id": str(source.get("run_id", "")),
		"process_role": str(source.get("process_role", "")),
		"process_id": maxi(0, int(source.get("process_id", 0))),
		"head_sha": str(source.get("head_sha", "")),
		"scenario_fingerprint": str(source.get("scenario_fingerprint", "")),
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
		"registry_commit_count": maxi(0, int(source.get("registry_commit_count", 0))),
		"registry_rebind_count": maxi(0, int(source.get("registry_rebind_count", 0))),
		"partial_restore_state_count": maxi(0, int(source.get("partial_restore_state_count", 0))),
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
		"restore_private_feedback_delta": int(source.get("restore_private_feedback_delta", 0)),
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
		"duplicate_queue_entry_count": _required_duplicate_evidence(source, "duplicate_queue_entry_count"),
		"duplicate_facility_creation_count": _required_duplicate_evidence(source, "duplicate_facility_creation_count"),
		"duplicate_card_consumption_count": _required_duplicate_evidence(source, "duplicate_card_consumption_count"),
		"duplicate_cost_consumption_count": _required_duplicate_evidence(source, "duplicate_cost_consumption_count"),
		"duplicate_sale_receipt_count": _required_duplicate_evidence(source, "duplicate_sale_receipt_count"),
		"world_fingerprint_match": _required_boolean_evidence(source, "world_fingerprint_match"),
		"rng_cursor_match": _required_boolean_evidence(source, "rng_cursor_match"),
		"ai_state_fingerprint_match": _required_boolean_evidence(source, "ai_state_fingerprint_match"),
		"card_inventory_fingerprint_match": _required_boolean_evidence(source, "card_inventory_fingerprint_match"),
		"queue_fingerprint_match": _required_boolean_evidence(source, "queue_fingerprint_match"),
		"generation_2_recapture_fingerprint_match": _required_boolean_evidence(
			source,
			"generation_2_recapture_fingerprint_match"
		),
		"generation_2_rng_cursor_match": _required_boolean_evidence(
			source,
			"generation_2_rng_cursor_match"
		),
		"generation_2_duplicate_transaction_count": _required_integer_evidence(
			source,
			"generation_2_duplicate_transaction_count"
		),
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
		"save_readback_green": bool(source.get("save_readback_green", false)),
		"save_fingerprint_parity": bool(source.get("save_fingerprint_parity", false)),
		"write_fingerprint": str(source.get("write_fingerprint", "")),
		"elapsed_ms": maxi(0, int(source.get("elapsed_ms", 0))),
		"success": bool(source.get("success", false)),
		"failure_code": _safe_reason_code(str(source.get("failure_code", ""))),
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
	for field in ["run_id", "head_sha", "scenario_fingerprint", "source_sections_digest", "saved_sections_digest", "restored_sections_digest", "source_write_id", "write_id", "source_write_fingerprint", "write_fingerprint", "queue_trigger_stable_target_fingerprint", "failure_code"]:
		if str(manifest.get(field, "")).length() > 128:
			return false
	var scenario_fingerprint := str(manifest.get("scenario_fingerprint", ""))
	if not scenario_fingerprint.is_empty() and not _is_lower_sha256(scenario_fingerprint):
		return false
	var queue_target_fingerprint := str(manifest.get("queue_trigger_stable_target_fingerprint", ""))
	if not queue_target_fingerprint.is_empty() and not _is_lower_sha256(queue_target_fingerprint):
		return false
	if bool(manifest.get("success", false)):
		for field in [
			"duplicate_queue_entry_count",
			"duplicate_facility_creation_count",
			"duplicate_card_consumption_count",
			"duplicate_cost_consumption_count",
			"duplicate_sale_receipt_count",
			"generation_2_duplicate_transaction_count",
		]:
			if int(manifest.get(field, -1)) < 0:
				return false
	return true


static func _required_duplicate_evidence(source: Dictionary, field: String) -> int:
	if source.has(field) and typeof(source.get(field)) == TYPE_INT:
		return int(source.get(field))
	return -1 if bool(source.get("success", false)) else 0


static func _required_integer_evidence(source: Dictionary, field: String) -> int:
	if source.has(field) and typeof(source.get(field)) == TYPE_INT:
		return int(source.get(field))
	return -1 if bool(source.get("success", false)) else 0


static func _required_boolean_evidence(source: Dictionary, field: String) -> bool:
	return source.has(field) and typeof(source.get(field)) == TYPE_BOOL \
			and bool(source.get(field))


func _run_role(options: Dictionary, head_sha: String) -> Dictionary:
	var role := str(options.get("process_role", ""))
	var base := _manifest_base(str(options.get("run_id", "")), role, head_sha)
	base["scenario_fingerprint"] = str(options.get("scenario_fingerprint", ""))
	_enter_process_a_phase("scene_loaded")
	var main := MAIN_SCENE.instantiate()
	_active_main = main
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
	_complete_process_a_phase("scene_loaded", {"transactional_section_count": 19})
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
		"timeout_policy_fingerprint": "",
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


static func _safe_reason_code(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	var result := ""
	for index in range(normalized.length()):
		var character := normalized.substr(index, 1)
		if "abcdefghijklmnopqrstuvwxyz0123456789_".contains(character):
			result += character
		elif not result.ends_with("_"):
			result += "_"
	result = result.trim_prefix("_").trim_suffix("_")
	return (result if not result.is_empty() else "role_failed").left(128)


static func _safe_owner_capture_reason_code(value: Variant) -> String:
	return CAPTURE_FAILURE.sanitize_reason_code(value)


func _run_producer(context: Dictionary, options: Dictionary, base: Dictionary) -> Dictionary:
	var save_path := str(options.get("save_path", ""))
	if FileAccess.file_exists(save_path):
		return _fail(base, "producer_slot_must_start_empty")
	if _targeted_owner_capture_diagnostic:
		_targeted_diagnostic_context = context
		if not _advance_targeted_diagnostic_phase("session_creating"):
			return _fail(base, _targeted_diagnostic_phase_failure)
	_enter_process_a_phase("session_started")
	var started := _start_default_session(context, str(options.get("run_id", "")))
	if not bool(started.get("applied", false)):
		return _fail(base, str(started.get("reason_code", "session_start_failed")))
	if _targeted_owner_capture_diagnostic:
		if not _advance_targeted_diagnostic_phase("session_started") \
				or not _advance_targeted_diagnostic_phase("scenario_identity_attesting"):
			return _fail(base, _targeted_diagnostic_phase_failure)
		_targeted_diagnostic_identity = _build_targeted_scenario_identity(
			context,
			started,
			_targeted_diagnostic_options
		)
		var identity_report := DIAGNOSTIC_SCENARIO_IDENTITY.validation_report(
			_targeted_diagnostic_identity,
			str(options.get("run_id", "")),
			str(_targeted_diagnostic_options.get("repository_head", "")),
			str(options.get("scenario_fingerprint", ""))
		)
		if not bool(identity_report.get("valid", false)):
			_targeted_diagnostic_pre_owner_failure = (identity_report.get("failure", {}) as Dictionary).duplicate(true)
			_targeted_diagnostic_identity.clear()
			return _fail(base, str(identity_report.get("reason_code", "targeted_owner_capture_scenario_identity_failed")))
		if not _advance_targeted_diagnostic_phase("scenario_identity_attested") \
				or not _advance_targeted_diagnostic_phase("registry_binding_attesting"):
			return _fail(base, _targeted_diagnostic_phase_failure)
		var registry_binding := _attest_targeted_registry_binding(context)
		if not bool(registry_binding.get("attested", false)):
			_targeted_diagnostic_pre_owner_failure = (registry_binding.get("failure", {}) as Dictionary).duplicate(true)
			return _fail(base, str(_targeted_diagnostic_pre_owner_failure.get("reason_code", "diagnostic_registry_binding_not_ready")))
		if not _advance_targeted_diagnostic_phase("registry_binding_attested"):
			return _fail(base, _targeted_diagnostic_phase_failure)
	elif str(started.get("scenario_fingerprint", "")) != str(options.get("scenario_fingerprint", "")):
		return _fail(base, "producer_scenario_fingerprint_mismatch")
	_complete_process_a_phase("session_started", {"challenge_depth": ACCEPTANCE_CHALLENGE_DEPTH, "seed": ACCEPTANCE_SEED})
	var initial_ai_digest := _ai_state_digest(context)
	var human := _submit_human_selection(context, "producer-human", 1)
	_enter_process_a_phase("real_commodity_claim_complete")
	var legal_checkpoint: Dictionary = await _prepare_facility_queue_checkpoint(context)
	if not bool(legal_checkpoint.get("ready", false)):
		return _fail(base, str(legal_checkpoint.get("reason_code", "legal_checkpoint_failed")))
	var initial_sales: Dictionary = legal_checkpoint.get("sales", {}) \
		if legal_checkpoint.get("sales", {}) is Dictionary else {}
	(context.get("coordinator") as GameRuntimeCoordinator).resume_session()
	var ai_actions := _tick_ai_until_action(context, 120)
	var final_ai_digest := _ai_state_digest(context)
	if ai_actions < 1 or initial_ai_digest.is_empty() or final_ai_digest == initial_ai_digest:
		return _fail(base, "ai_nondefault_state_not_observed")
	if _targeted_owner_capture_diagnostic:
		_targeted_owner_capture_observed_scenario["ai_action_count"] = ai_actions
		_targeted_owner_capture_observed_scenario["ai_state_digest_changed"] = true
	_complete_process_a_phase("ai_nondefault_state_complete", {
		"ai_action_count": ai_actions,
		"ai_state_changed": not initial_ai_digest.is_empty() and final_ai_digest != initial_ai_digest,
	})
	_record_targeted_owner_capture_audit(context, "ai_nondefault_state_complete")
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
	_enter_process_a_phase("queue_entry_committed")
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
	var producer_duplicates := _authoritative_duplicate_observation(context)
	if not bool(producer_duplicates.get("valid", false)):
		return _fail(base, str(producer_duplicates.get(
			"reason_code",
			"producer_duplicate_observation_invalid"
		)))
	for duplicate_field in [
		"duplicate_queue_entry_count",
		"duplicate_facility_creation_count",
		"duplicate_card_consumption_count",
		"duplicate_cost_consumption_count",
		"duplicate_sale_receipt_count",
	]:
		base[duplicate_field] = int(producer_duplicates.get(duplicate_field, -1))
	_complete_process_a_phase("queue_entry_committed", {
		"queue_count": _queue_entry_count(context),
		"queue_resolution_id": queue_target_resolution_id,
		"stable_target_fingerprint": queue_target_fingerprint,
	})
	_record_targeted_owner_capture_audit(context, "queue_entry_committed")
	_enter_process_a_phase("restore_barrier_entered")
	if _targeted_owner_capture_diagnostic:
		var barrier := context.get("barrier") as SaveRestoreRuntimeBarrier
		var diagnostic_barrier_operation_id := "targeted-owner-capture-%s" % str(options.get("run_id", ""))
		var diagnostic_global_checkpoint := barrier.capture_global_checkpoint(diagnostic_barrier_operation_id) \
				if barrier != null else {"accepted": false, "reason_code": "restore_barrier_missing"}
		if not bool(diagnostic_global_checkpoint.get("accepted", false)):
			return _fail(base, str(diagnostic_global_checkpoint.get("reason_code", "restore_global_checkpoint_capture_failed")))
		var diagnostic_barrier_enter := barrier.enter_restore_barrier(
			diagnostic_barrier_operation_id,
			(diagnostic_global_checkpoint.get("checkpoint", {}) as Dictionary).duplicate(true)
		)
		if not bool(diagnostic_barrier_enter.get("acquired", false)):
			return _fail(base, str(diagnostic_barrier_enter.get("reason_code", "restore_barrier_acquire_failed")))
		_complete_process_a_phase("restore_barrier_entered", {
			"queue_pending_count": int(queue_target_before.get("pending_count", 0)),
		})
		if not _advance_targeted_diagnostic_phase("owner_audit_started"):
			var failed_phase_rollback := barrier.rollback_restore_barrier(diagnostic_barrier_operation_id)
			return _fail(base, _targeted_diagnostic_phase_failure if bool(failed_phase_rollback.get("applied", false)) else "targeted_owner_capture_restore_barrier_cleanup_failed")
		var registry: Node = context.get("registry")
		_targeted_diagnostic_capture = registry.call("capture_all_sections_detailed", self) \
				if registry != null and registry.has_method("capture_all_sections_detailed") else {}
		if not _advance_targeted_diagnostic_phase("owner_audit_completed"):
			var failed_audit_rollback := barrier.rollback_restore_barrier(diagnostic_barrier_operation_id)
			return _fail(base, _targeted_diagnostic_phase_failure if bool(failed_audit_rollback.get("applied", false)) else "targeted_owner_capture_restore_barrier_cleanup_failed")
		var diagnostic_quiet := barrier.verify_restore_quiet(diagnostic_barrier_operation_id)
		var diagnostic_barrier_rollback := barrier.rollback_restore_barrier(diagnostic_barrier_operation_id)
		var diagnostic_barrier_after := barrier.debug_snapshot()
		if not bool(diagnostic_quiet.get("accepted", false)) \
				or not bool(diagnostic_barrier_rollback.get("applied", false)) \
				or bool(diagnostic_barrier_after.get("active", true)):
			return _fail(base, "targeted_owner_capture_restore_barrier_cleanup_failed")
		var diagnostic_write := _write_targeted_owner_capture_diagnostic(options, base)
		if not bool(diagnostic_write.get("valid", false)):
			return _fail(base, str(diagnostic_write.get("reason_code", "targeted_owner_capture_diagnostic_write_failed")))
		_targeted_diagnostic_written = true
		base["_targeted_owner_capture_diagnostic_sha256"] = str(diagnostic_write.get("sha256", ""))
		var owner_failure: Dictionary = _targeted_diagnostic_capture.get("first_failure", {}) \
				if _targeted_diagnostic_capture.get("first_failure", {}) is Dictionary else {}
		var post_capture_failure: Dictionary = _targeted_diagnostic_capture.get("post_capture_failure", {}) \
				if _targeted_diagnostic_capture.get("post_capture_failure", {}) is Dictionary else {}
		return _fail(base, "targeted_owner_capture_diagnostic_complete" \
				if not owner_failure.is_empty() else (
					"targeted_owner_capture_post_validation_failed" \
					if not post_capture_failure.is_empty() else "targeted_owner_capture_all_owners_succeeded"
				))
	(context.get("coordinator") as GameRuntimeCoordinator).pause_session()
	var save_barrier_operation_id := "process-a-save-%s" % str(options.get("run_id", ""))
	var save_barrier_begin := _acquire_process_a_save_barrier(
		context,
		save_barrier_operation_id
	)
	if not bool(save_barrier_begin.get("acquired", false)):
		return _fail(base, str(save_barrier_begin.get("reason_code", "process_a_save_barrier_acquire_failed")))
	_complete_process_a_phase("restore_barrier_entered", {
		"queue_pending_count": int(queue_target_before.get("pending_count", 0)),
		"barrier_acquired": true,
		"restore_barrier_quiet": bool(save_barrier_begin.get("restore_barrier_quiet", false)),
		"restore_barrier_rolled_back": bool(save_barrier_begin.get("restore_barrier_rolled_back", false)),
		"save_barrier_kind": "authoritative_runtime_loop_manual_lease",
	})
	var checkpoint := _checkpoint_summary(context)
	_enter_process_a_phase("save_intent_submitted")
	_complete_process_a_phase("save_intent_submitted", {"source_surface": "pause_menu"})
	var save := _save_via_player_flow(context, save_path, false)
	var save_failure_code := "" if bool(save.get("ok", false)) \
			else str(save.get("reason_code", "producer_save_failed"))
	var save_barrier_release := _release_process_a_save_barrier(
		context,
		save_barrier_operation_id,
		save_barrier_begin
	)
	var boundary_failures := _ordered_process_a_boundary_failures(
		save_failure_code,
		save_barrier_release
	)
	if not str(boundary_failures.get("primary_failure_code", "")).is_empty():
		base["_secondary_failure_codes"] = boundary_failures.get("secondary_failure_codes", [])
		return _fail(base, str(boundary_failures.get("primary_failure_code")))
	var readback_phase_evidence: Dictionary = save.get("readback_phase_evidence", {}) \
			if save.get("readback_phase_evidence", {}) is Dictionary else {}
	readback_phase_evidence["restore_barrier_quiet"] = bool(save_barrier_release.get("quiet", false))
	readback_phase_evidence["full_quiet_window"] = true
	_complete_process_a_phase("save_readback_complete", readback_phase_evidence)
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
	save["restore_barrier_entered"] = true
	save["restore_barrier_quiet"] = bool(save_barrier_release.get("quiet", false))
	save["restore_barrier_released"] = true
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
		"owner_apply_count": 0,
		"registry_apply_count": 0,
		"registry_commit_count": 0,
		"registry_rebind_count": 0,
		"partial_restore_state_count": 0,
		"save_capture_world_delta": int(save.get("save_capture_world_delta", -1)),
		"save_capture_rng_delta": int(save.get("save_capture_rng_delta", -1)),
		"save_capture_log_delta": int(save.get("save_capture_log_delta", -1)),
		"restore_rng_draw_delta": 0,
		"restore_world_time_delta": 0,
		"restore_public_log_delta": 0,
		"restore_sale_receipt_delta": 0,
		"restore_economic_reward_delta": 0,
		"restore_ai_action_delta": 0,
		"restore_player_action_delta": 0,
		"restore_notification_delta": 0,
		"restore_private_feedback_delta": 0,
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
		"world_fingerprint_match": false,
		"rng_cursor_match": false,
		"ai_state_fingerprint_match": false,
		"card_inventory_fingerprint_match": false,
		"queue_fingerprint_match": false,
		"generation_2_recapture_fingerprint_match": false,
		"generation_2_rng_cursor_match": false,
		"generation_2_duplicate_transaction_count": 0,
		"victory_unresolved_before_save": bool(checkpoint.get("victory_unresolved", false)),
		"production_surface_ready": bool(checkpoint.get("production_surface_ready", false)),
		"victory_state_sequence": [],
		"final_settlement_count": 0,
		"final_settlement_presentation_count": 0,
		"final_settlement_public_log_count": 0,
		"terminal_quiescent_frames": 0,
		"terminal_world_delta": 0,
		"terminal_rng_draw_delta": 0,
		"generation": 1,
		"backup_created": bool(save.get("backup_created", false)),
		"save_readback_green": int(save.get("section_count", 0)) == 19 \
				and int(save.get("preflight_count", 0)) == 19 \
				and bool(save.get("readback_fingerprint_match", false)),
		"save_fingerprint_parity": bool(save.get("readback_fingerprint_match", false)),
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
	if _process_a_rehearsal and bool(base.get("success", false)):
		var save_file_metrics := _save_file_metrics(save_path)
		var envelope_encode_green := int(save.get("capture_section_count", 0)) == 19 \
				and _is_lower_sha256(str(save.get("capture_envelope_fingerprint", "")))
		var atomic_write_green := bool(save_file_metrics.get("exists", false)) \
				and int(save_file_metrics.get("bytes", 0)) > 0 \
				and _is_lower_sha256(str(save_file_metrics.get("sha256", "")))
		var save_readback_green := bool(save.get("ok", false)) \
				and int(save.get("section_count", 0)) == 19 \
				and int(save.get("preflight_count", 0)) == 19 \
				and bool(save.get("readback_fingerprint_match", false))
		var save_capture_quiet := int(save.get("save_capture_world_delta", -1)) == 0 \
				and int(save.get("save_capture_rng_delta", -1)) == 0 \
				and int(save.get("save_capture_log_delta", -1)) == 0
		if not envelope_encode_green or not atomic_write_green \
				or not save_readback_green or not save_capture_quiet:
			return _fail(base, "process_a_rehearsal_save_completion_evidence_invalid")
		var completion := PROCESS_A_REHEARSAL_COMPLETION.build({
			"run_id": str(options.get("run_id", "")),
			"repository_head": str(base.get("head_sha", "")),
			"scenario_fingerprint": str(options.get("scenario_fingerprint", "")),
			"authorization_fingerprint": str(options.get("rehearsal_ledger_fingerprint", "")),
			"timeout_policy_fingerprint": str(options.get("timeout_policy_fingerprint", "")),
			"restore_barrier_entered": bool(save.get("restore_barrier_entered", false)),
			"restore_barrier_quiet": bool(save.get("restore_barrier_quiet", false)),
			"restore_barrier_released": bool(save.get("restore_barrier_released", false)),
			"save_owner_capture_count": int(save.get("capture_section_count", 0)),
			"save_section_count": int(save.get("section_count", 0)),
			"save_preflight_count": int(save.get("preflight_count", 0)),
			"capture_operation_sequence": int(save.get("capture_operation_sequence", 0)),
			"captured_sections_fingerprint": str(save.get("capture_sections_fingerprint", "")),
			"readback_sections_fingerprint": str(save.get("sections_digest", "")),
			"save_capture_world_delta": int(save.get("save_capture_world_delta", -1)),
			"save_capture_rng_delta": int(save.get("save_capture_rng_delta", -1)),
			"save_capture_public_log_delta": int(save.get("save_capture_log_delta", -1)),
			"envelope_encode_green": envelope_encode_green,
			"atomic_write_green": atomic_write_green,
			"save_readback_green": save_readback_green,
			"save_capture_fingerprint": str(save.get("capture_envelope_fingerprint", "")),
			"save_readback_fingerprint": str(save.get("write_fingerprint", "")),
			"save_fingerprint_parity": bool(save.get("readback_fingerprint_match", false)),
			"save_file_bytes": int(save_file_metrics.get("bytes", 0)),
			"save_file_sha256": str(save_file_metrics.get("sha256", "")),
			"queue_entry_count": int(base.get("queue_entry_count", 0)),
		})
		var completion_report := PROCESS_A_REHEARSAL_COMPLETION.validation_report(
			completion,
			str(options.get("run_id", "")),
			str(base.get("head_sha", "")),
			str(options.get("scenario_fingerprint", "")),
			str(options.get("rehearsal_ledger_fingerprint", "")),
			str(options.get("timeout_policy_fingerprint", ""))
		)
		if not bool(completion_report.get("valid", false)):
			return _fail(base, str(completion_report.get("reason_code", "process_a_rehearsal_completion_invalid")))
		var completion_write := PROCESS_A_REHEARSAL_COMPLETION.write_atomic(
			str(options.get("run_id", "")),
			completion
		)
		if not bool(completion_write.get("valid", false)):
			return _fail(base, str(completion_write.get("reason_code", "process_a_rehearsal_completion_write_failed")))
		base["_process_a_rehearsal_completion_sha256"] = str(completion_write.get("sha256", ""))
	return base


func _run_consumer(context: Dictionary, options: Dictionary, base: Dictionary) -> Dictionary:
	_emit_role_heartbeat("process_b_read_generation_1", "readback")
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
	_emit_role_heartbeat("process_b_restore_generation_1", "restore")
	var load := _resume_via_player_flow(context, save_path)
	if not bool(load.get("ok", false)):
		return _fail(base, str(load.get("reason_code", "consumer_restore_failed")))
	var after_observation := _safety_observation(context)
	var recapture := _capture_sections(context, "consumer-recapture")
	if not bool(recapture.get("ok", false)) or str(recapture.get("sections_digest", "")) != source_digest:
		return _fail(base, "consumer_exact_recapture_mismatch")
	var restore_fingerprints := _restore_fingerprint_evidence(
		context,
		read.get("envelope", {}) as Dictionary,
		recapture.get("envelope", {}) as Dictionary
	)
	var restore_transaction_duplicate_count := _restore_transaction_duplicate_count(load)
	if not _restore_fingerprint_evidence_green(restore_fingerprints) \
			or restore_transaction_duplicate_count != 0:
		return _fail(base, "consumer_typed_restore_evidence_invalid")
	_emit_role_heartbeat("process_b_generation_1_recaptured", "restore")
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
	var target_entry: Dictionary = queue_target_before.get("facility_entry", {}) \
			if queue_target_before.get("facility_entry", {}) is Dictionary else {}
	var target_commitment_before := _facility_commitment_observation(context, target_entry)
	if not bool(target_commitment_before.get("valid", false)) \
			or bool(target_commitment_before.get("settled", true)):
		return _fail(base, "consumer_facility_commitment_before_invalid")
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
	# History is intentionally privacy-redacted, so the post-drain commitment
	# check uses the already validated in-process binding captured before drain.
	var target_commitment_after := _facility_commitment_observation(context, target_entry)
	if not bool(target_commitment_after.get("valid", false)) \
			or not bool(target_commitment_after.get("settled", false)) \
			or not bool(target_commitment_after.get("committed", false)) \
			or str(target_commitment_after.get("facility_lifecycle_state_id", "")) != "finalized" \
			or str(target_commitment_after.get("asset_outcome_id", "")) not in ["consumed", "not_required"]:
		return _fail(base, "consumer_facility_commitment_after_invalid")
	var duplicates_before_continuation := _authoritative_duplicate_observation(context)
	if not bool(duplicates_before_continuation.get("valid", false)) \
			or not _duplicate_observation_is_zero(duplicates_before_continuation):
		return _fail(base, "consumer_pre_continuation_duplicate_observation_invalid")
	_emit_role_heartbeat("process_b_queue_continued", "queue_continuation")
	(context.get("coordinator") as GameRuntimeCoordinator).resume_session()
	var human := _submit_human_selection(context, "consumer-human", 2)
	var commodity_action := _claim_first_visible_commodity(context, maxi(1, Time.get_ticks_msec()))
	var ai_actions := _tick_ai_until_action(context, 120)
	var post_sales := _advance_sale(context, 60.0)
	var post_duplicates := _authoritative_duplicate_observation(context)
	var new_sale_receipt_count := int(post_duplicates.get("sale_receipt_count", 0)) \
			- int(duplicates_before_continuation.get("sale_receipt_count", 0))
	if not bool(human.get("accepted", false)) or ai_actions <= 0 \
			or not bool(commodity_action.get("success", false)) \
			or int(post_sales.get("sale_receipt_count", 0)) <= 0 \
			or not bool(post_duplicates.get("valid", false)) \
			or not _duplicate_observation_is_zero(post_duplicates) \
			or new_sale_receipt_count <= 0:
		return _fail(base, "post_restore_continuation_failed")
	_emit_role_heartbeat("process_b_post_restore_actions_complete", "continuation")
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
	_emit_role_heartbeat("process_b_generation_2_save", "generation_2_save")
	var generation_two := _save_via_player_flow(context, save_path, true)
	if not bool(generation_two.get("ok", false)):
		return _fail(base, str(generation_two.get("reason_code", "generation_two_save_failed")))
	var generation_two_victory_unresolved := _readback_victory_unresolved(
		context,
		generation_two.get("readback_envelope", {}) as Dictionary \
				if generation_two.get("readback_envelope", {}) is Dictionary else {}
	)
	if not bool(checkpoint.get("victory_unresolved", false)) or not generation_two_victory_unresolved:
		return _fail(base, "generation_two_victory_checkpoint_invalid")
	var terminal_context := context.duplicate()
	var generation_two_sale_binding: Dictionary = sale_binding_capture.get("binding", {}) \
		if sale_binding_capture.get("binding", {}) is Dictionary else {}
	terminal_context["generation_two_sale_binding"] = generation_two_sale_binding.duplicate(true)
	_emit_role_heartbeat("process_b_settlement_continuation", "settlement")
	var terminal := await _finish_to_settlement(terminal_context)
	if not bool(terminal.get("settled", false)):
		return _fail(
			base,
			str(terminal.get("failure_code", "post_restore_settlement_failed"))
		)
	_emit_role_heartbeat("process_b_terminal_quiet", "settlement")
	var queue_target_final := _queue_target_observation(context, queue_target_resolution_id)
	var final_duplicates := _authoritative_duplicate_observation(context)
	if not _queue_target_post_continuation_quiet_valid(queue_target_after, queue_target_final) \
			or not bool(final_duplicates.get("valid", false)) \
			or not _duplicate_observation_is_zero(final_duplicates):
		return _fail(base, "consumer_post_continuation_exact_once_invalid")
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
		"registry_commit_count": int(load.get("registry_commit_count", 0)),
		"registry_rebind_count": int(load.get("post_restore_rebind_count", 0)),
		"partial_restore_state_count": int(load.get("partial_restore_state_count", 0)),
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
		"restore_private_feedback_delta": int(quiet.get("private_feedback_revision", -1)),
		"human_action_count": 1,
		"commodity_action_count": 1 if bool(commodity_action.get("success", false)) else 0,
		"ai_action_count": ai_actions,
		"sale_receipt_count": new_sale_receipt_count,
		"normal_card_count": int(checkpoint.get("normal_card_count", 0)),
		"commodity_card_count": int(checkpoint.get("commodity_card_count", 0)),
		"commodity_claim_count": int(checkpoint.get("commodity_claim_count", 0)),
		"facility_count": int(checkpoint.get("facility_count", 0)),
		"route_count": int(checkpoint.get("route_count", 0)),
		"military_unit_count": int(checkpoint.get("military_unit_count", 0)),
		"queue_entry_count": int(checkpoint.get("queue_entry_count", 0)),
		"weather_region_count": int(checkpoint.get("weather_region_count", 0)),
		"ai_nondefault_state_count": int(checkpoint.get("ai_nondefault_state_count", 0)),
		"victory_unresolved_before_save": generation_two_victory_unresolved,
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
		"save_readback_green": int(generation_two.get("section_count", 0)) == 19 \
				and int(generation_two.get("preflight_count", 0)) == 19 \
				and bool(generation_two.get("readback_fingerprint_match", false)),
		"save_fingerprint_parity": bool(generation_two.get("readback_fingerprint_match", false)),
		"write_fingerprint": str(generation_two.get("write_fingerprint", "")),
		"duplicate_queue_entry_count": int(final_duplicates.get("duplicate_queue_entry_count", -1)),
		"duplicate_facility_creation_count": int(final_duplicates.get("duplicate_facility_creation_count", -1)),
		"duplicate_card_consumption_count": int(final_duplicates.get("duplicate_card_consumption_count", -1)),
		"duplicate_cost_consumption_count": int(final_duplicates.get("duplicate_cost_consumption_count", -1)),
		"duplicate_sale_receipt_count": int(final_duplicates.get("duplicate_sale_receipt_count", -1)),
		"world_fingerprint_match": bool(restore_fingerprints.get("world_fingerprint_match", false)),
		"rng_cursor_match": bool(restore_fingerprints.get("rng_cursor_match", false)),
		"ai_state_fingerprint_match": bool(restore_fingerprints.get("ai_state_fingerprint_match", false)),
		"card_inventory_fingerprint_match": bool(restore_fingerprints.get("card_inventory_fingerprint_match", false)),
		"queue_fingerprint_match": bool(restore_fingerprints.get("queue_fingerprint_match", false)),
		"generation_2_recapture_fingerprint_match": false,
		"generation_2_rng_cursor_match": false,
		"generation_2_duplicate_transaction_count": 0,
		"success": true,
		"failure_code": "",
	}, true)
	base.merge(queue_target_evidence, true)
	return base


func _run_validator(context: Dictionary, options: Dictionary, base: Dictionary) -> Dictionary:
	_emit_role_heartbeat("process_c_read_generation_2", "readback")
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
	_emit_role_heartbeat("process_c_restore_generation_2", "restore")
	var load := _resume_via_player_flow(context, save_path)
	if not bool(load.get("ok", false)):
		return _fail(base, str(load.get("reason_code", "validator_restore_failed")))
	var after_observation := _safety_observation(context)
	var recapture := _capture_sections(context, "validator-recapture")
	_emit_role_heartbeat("process_c_generation_2_recaptured", "recapture")
	var checkpoint := _checkpoint_summary(context)
	var source_envelope: Dictionary = read.get("envelope", {}) \
			if read.get("envelope", {}) is Dictionary else {}
	var recaptured_envelope: Dictionary = recapture.get("envelope", {}) \
			if recapture.get("envelope", {}) is Dictionary else {}
	var restore_fingerprints := _restore_fingerprint_evidence(
		context,
		source_envelope,
		recaptured_envelope
	)
	var generation_two_recapture_match := bool(recapture.get("ok", false)) \
			and str(recapture.get("sections_digest", "")) == source_digest
	var generation_two_duplicate_transactions := _restore_transaction_duplicate_count(load)
	var source_victory_unresolved := _readback_victory_unresolved(context, source_envelope)
	var queue_target_before := _queue_target_observation(context, queue_target_resolution_id)
	var no_continuation := await _generation_two_no_continuation_evidence(context)
	# The second observation is deliberately after the bounded deferred-lifecycle
	# idle gate, so Process C proves the completed Generation-2 target stayed quiet.
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
	var validator_target_commitment := _facility_commitment_observation_by_resolution(
		context,
		queue_target_resolution_id
	)
	var validator_target_commitment_exact := bool(validator_target_commitment.get("valid", false)) \
			and bool(validator_target_commitment.get("settled", false)) \
			and bool(validator_target_commitment.get("committed", false)) \
			and str(validator_target_commitment.get("facility_lifecycle_state_id", "")) == "finalized"
	var duplicate_observation := _authoritative_duplicate_observation(context)
	var exact := bool(load.get("ok", false)) and generation_two_recapture_match \
		and _restore_fingerprint_evidence_green(restore_fingerprints) \
		and bool(restore_fingerprints.get("rng_cursor_match", false)) \
		and generation_two_duplicate_transactions == 0 \
		and source_victory_unresolved and bool(checkpoint.get("victory_unresolved", false)) \
		and bool(checkpoint.get("production_surface_ready", false)) \
		and queue_target_exact and validator_target_commitment_exact \
		and _duplicate_observation_is_zero(duplicate_observation) \
		and bool(no_continuation.get("accepted", false))
	var coordinator := context.get("coordinator") as GameRuntimeCoordinator
	if coordinator != null:
		coordinator.pause_session()
	var active_main := context.get("main") as Node
	if active_main != null:
		active_main.process_mode = Node.PROCESS_MODE_DISABLED
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
		"registry_commit_count": int(load.get("registry_commit_count", 0)),
		"registry_rebind_count": int(load.get("post_restore_rebind_count", 0)),
		"partial_restore_state_count": int(load.get("partial_restore_state_count", 0)),
		"save_capture_world_delta": 0,
		"save_capture_rng_delta": 0,
		"save_capture_log_delta": 0,
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
		"restore_private_feedback_delta": int(quiet.get("private_feedback_revision", -1)),
		"human_action_count": 0,
		"commodity_action_count": 0,
		"ai_action_count": 0,
		"sale_receipt_count": 0,
		"normal_card_count": int(checkpoint.get("normal_card_count", 0)),
		"commodity_card_count": int(checkpoint.get("commodity_card_count", 0)),
		"commodity_claim_count": int(checkpoint.get("commodity_claim_count", 0)),
		"facility_count": int(checkpoint.get("facility_count", 0)),
		"route_count": int(checkpoint.get("route_count", 0)),
		"military_unit_count": int(checkpoint.get("military_unit_count", 0)),
		"queue_entry_count": int(checkpoint.get("queue_entry_count", 0)),
		"weather_region_count": int(checkpoint.get("weather_region_count", 0)),
		"ai_nondefault_state_count": int(checkpoint.get("ai_nondefault_state_count", 0)),
		"victory_unresolved_before_save": source_victory_unresolved,
		"production_surface_ready": bool(checkpoint.get("production_surface_ready", false)),
		"generation": 2,
		"backup_created": false,
		"save_readback_green": bool(read.get("ok", false)) and exact,
		"save_fingerprint_parity": exact,
		"duplicate_queue_entry_count": int(duplicate_observation.get("duplicate_queue_entry_count", -1)),
		"duplicate_facility_creation_count": int(duplicate_observation.get("duplicate_facility_creation_count", -1)),
		"duplicate_card_consumption_count": int(duplicate_observation.get("duplicate_card_consumption_count", -1)),
		"duplicate_cost_consumption_count": int(duplicate_observation.get("duplicate_cost_consumption_count", -1)),
		"duplicate_sale_receipt_count": int(duplicate_observation.get("duplicate_sale_receipt_count", -1)),
		"world_fingerprint_match": bool(restore_fingerprints.get("world_fingerprint_match", false)),
		"rng_cursor_match": bool(restore_fingerprints.get("rng_cursor_match", false)),
		"ai_state_fingerprint_match": bool(restore_fingerprints.get("ai_state_fingerprint_match", false)),
		"card_inventory_fingerprint_match": bool(restore_fingerprints.get("card_inventory_fingerprint_match", false)),
		"queue_fingerprint_match": bool(restore_fingerprints.get("queue_fingerprint_match", false)),
		"generation_2_recapture_fingerprint_match": generation_two_recapture_match,
		"generation_2_rng_cursor_match": bool(restore_fingerprints.get("rng_cursor_match", false)),
		"generation_2_duplicate_transaction_count": generation_two_duplicate_transactions,
		"victory_state_sequence": no_continuation.get("victory_state_sequence", []),
		"final_settlement_count": int(no_continuation.get("settlement_count", -1)),
		"final_settlement_presentation_count": int(no_continuation.get("presentation_count", -1)),
		"final_settlement_public_log_count": int(no_continuation.get("public_log_count", -1)),
		"terminal_quiescent_frames": int(no_continuation.get("terminal_quiescent_frames", -1)),
		"terminal_world_delta": int(no_continuation.get("terminal_world_delta", -1)),
		"terminal_rng_draw_delta": int(no_continuation.get("terminal_rng_draw_delta", -1)),
		"success": exact,
		"failure_code": "" if exact else (
			"validator_queue_target_lineage_invalid" \
			if not queue_target_exact or not validator_target_commitment_exact \
			else (
				str(no_continuation.get("reason_code", "validator_no_continuation_evidence_invalid")) \
				if not bool(no_continuation.get("accepted", false)) \
				else "validator_exact_recapture_mismatch"
			)
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
	var runtime_loop := coordinator.get_node_or_null("RuntimeLoop") if coordinator != null else null
	return {
		"ready": services != null and coordinator != null and session != null and registry != null and save != null and handshake != null and flow != null and barrier != null and runtime_loop != null,
		"main": main,
		"services": services,
		"coordinator": coordinator,
		"session": session,
		"registry": registry,
		"save": save,
		"handshake": handshake,
		"flow": flow,
		"barrier": barrier,
		"runtime_loop": runtime_loop,
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
	var observed_run_seed := int(runtime_rng.seed)
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
	var organization := coordinator.get_node_or_null("PlayerOrganizationRuntimeController")
	var organization_debug: Dictionary = organization.debug_snapshot() \
			if organization != null and organization.has_method("debug_snapshot") else {}
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController
	var ai_debug: Dictionary = ai.debug_snapshot() if ai != null else {}
	var observed_player_count := int(organization_debug.get("actor_count", 0))
	var observed_ai_player_count := int(ai_debug.get("ai_player_count", 0))
	var observed_local_player_count := observed_player_count - observed_ai_player_count
	return {
		"applied": receipt != null and receipt.applied,
		"reason_code": receipt.reason_code if receipt != null else "session_start_receipt_missing",
		# SessionStartTransactionCoordinator validates and commits this exact
		# draft; GameSession's intentionally reduced setup summary omits depth.
		"challenge_depth": challenge_depth,
		"seed": observed_run_seed,
		"session_seed": session_seed,
		"session_id": str(summary.get("session_id", "")),
		"session_generation": int(receipt.operation_sequence) if receipt != null else -1,
		"session_plan_fingerprint": str(receipt.plan_fingerprint) if receipt != null else "",
		"local_player_count": observed_local_player_count,
		"ai_player_count": observed_ai_player_count,
		"scenario_fingerprint": SEMANTIC_WIRE.fingerprint({
			"challenge_depth": challenge_depth,
			"run_seed": observed_run_seed,
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


func _restore_fingerprint_evidence(
	context: Dictionary,
	source_envelope: Dictionary,
	recaptured_envelope: Dictionary
) -> Dictionary:
	return {
		"world_fingerprint_match": _section_group_fingerprint_match(
			context, source_envelope, recaptured_envelope, WORLD_FINGERPRINT_SECTION_IDS
		),
		"rng_cursor_match": _section_group_fingerprint_match(
			context, source_envelope, recaptured_envelope, RNG_CURSOR_SECTION_IDS
		),
		"ai_state_fingerprint_match": _section_group_fingerprint_match(
			context, source_envelope, recaptured_envelope, AI_STATE_SECTION_IDS
		),
		"card_inventory_fingerprint_match": _section_group_fingerprint_match(
			context, source_envelope, recaptured_envelope, CARD_INVENTORY_SECTION_IDS
		),
		"queue_fingerprint_match": _section_group_fingerprint_match(
			context, source_envelope, recaptured_envelope, QUEUE_SECTION_IDS
		),
	}


func _section_group_fingerprint_match(
	context: Dictionary,
	source_envelope: Dictionary,
	recaptured_envelope: Dictionary,
	section_ids: Array
) -> bool:
	var handshake: Node = context.get("handshake")
	var source_sections: Dictionary = source_envelope.get("sections", {}) \
			if source_envelope.get("sections", {}) is Dictionary else {}
	var recaptured_sections: Dictionary = recaptured_envelope.get("sections", {}) \
			if recaptured_envelope.get("sections", {}) is Dictionary else {}
	if handshake == null or not handshake.has_method("canonical_json") \
			or source_sections.is_empty() or recaptured_sections.is_empty():
		return false
	var source_group := {}
	var recaptured_group := {}
	for section_id_variant in section_ids:
		var section_id := str(section_id_variant)
		if not source_sections.has(section_id) or not recaptured_sections.has(section_id):
			return false
		source_group[section_id] = source_sections.get(section_id)
		recaptured_group[section_id] = recaptured_sections.get(section_id)
	var source_canonical := str(handshake.call("canonical_json", source_group))
	var recaptured_canonical := str(handshake.call("canonical_json", recaptured_group))
	return not source_canonical.is_empty() and source_canonical == recaptured_canonical


func _restore_fingerprint_evidence_green(evidence: Dictionary) -> bool:
	for field in [
		"world_fingerprint_match",
		"rng_cursor_match",
		"ai_state_fingerprint_match",
		"card_inventory_fingerprint_match",
		"queue_fingerprint_match",
	]:
		if not evidence.has(field) or not bool(evidence.get(field, false)):
			return false
	return true


func _restore_transaction_duplicate_count(load: Dictionary) -> int:
	var expected := {
		"apply_count": SAVE_SECTION_ORDER.size(),
		"registry_apply_count": 1,
		"registry_commit_count": 1,
		"post_restore_rebind_count": 1,
	}
	var duplicate_count := 0
	for field_variant in expected:
		var field := str(field_variant)
		if not load.has(field) or typeof(load.get(field)) != TYPE_INT:
			return -1
		var observed := int(load.get(field))
		var required := int(expected.get(field))
		if observed < required:
			return -1
		duplicate_count += observed - required
	if not load.has("partial_restore_state_count") \
			or typeof(load.get("partial_restore_state_count")) != TYPE_INT \
			or int(load.get("partial_restore_state_count")) != 0:
		return -1
	return duplicate_count


func _record_targeted_owner_capture_audit(_context: Dictionary, _phase_id: String) -> void:
	# V2 performs one 19-Owner audit at the real restore barrier. Earlier
	# product milestones are covered by the scenario identity and Process A timeline.
	return


func _safe_owner_capture_v2_rows(value: Variant) -> Array:
	var result: Array = []
	var source_fields: Array = TARGETED_OWNER_DIAGNOSTIC.OWNER_ROW_FIELDS.duplicate()
	var state_version_index := source_fields.find("state_version")
	if state_version_index < 0:
		return result
	source_fields[state_version_index] = "payload_schema_version"
	if not (value is Array) or (value as Array).size() != SAVE_SECTION_ORDER.size():
		return result
	for row_index in range((value as Array).size()):
		var row_variant: Variant = (value as Array)[row_index]
		if not (row_variant is Dictionary):
			return []
		var row := row_variant as Dictionary
		if not _has_exact_fields(row, source_fields) \
				or int(row.get("owner_index", -1)) != row_index \
				or str(row.get("section_id", "")) != str(SAVE_SECTION_ORDER[row_index]) \
				or str(row.get("owner_id", "")) != str(SAVE_OWNER_ORDER[row_index]) \
				or str(row.get("row_evidence_fingerprint", "")) != SEMANTIC_WIRE.fingerprint(row, "row_evidence_fingerprint"):
			return []
		var safe_row: Dictionary = {}
		for field_variant in TARGETED_OWNER_DIAGNOSTIC.OWNER_ROW_FIELDS:
			var field := str(field_variant)
			var source_field := "payload_schema_version" if field == "state_version" else field
			if not row.has(source_field):
				return []
			safe_row[field] = row.get(source_field)
		safe_row["row_evidence_fingerprint"] = ""
		result.append(SEMANTIC_WIRE.sealed_copy(safe_row, "row_evidence_fingerprint"))
	return result


func _safe_owner_capture_failure(value: Variant) -> Dictionary:
	if not (value is Dictionary) or (value as Dictionary).is_empty():
		return {}
	var source := value as Dictionary
	if not _has_exact_fields(source, TARGETED_OWNER_DIAGNOSTIC.FAILURE_FIELDS):
		return {}
	var section_index := int(source.get("section_index", -1)) \
			if typeof(source.get("section_index")) == TYPE_INT else -1
	if typeof(source.get("schema_version")) != TYPE_INT \
			or int(source.get("schema_version", 0)) != int(CAPTURE_FAILURE.SCHEMA_VERSION) \
			or not (source.get("registry_operation_id") is String or source.get("registry_operation_id") is StringName) \
			or str(source.get("registry_operation_id", "")).is_empty() \
			or typeof(source.get("capture_sequence")) != TYPE_INT \
			or int(source.get("capture_sequence", 0)) < 1 \
			or section_index < 0 or section_index >= SAVE_SECTION_ORDER.size() \
			or str(source.get("section_id", "")) != str(SAVE_SECTION_ORDER[section_index]) \
			or str(source.get("owner_id", "")) != str(SAVE_OWNER_ORDER[section_index]) \
			or not (source.get("owner_node_path") is String or source.get("owner_node_path") is StringName) \
			or not (source.get("owner_script_path") is String or source.get("owner_script_path") is StringName) \
			or not (source.get("capture_method") is String or source.get("capture_method") is StringName) \
			or not CAPTURE_FAILURE.is_failure_class(str(source.get("failure_class", ""))) \
			or not CAPTURE_FAILURE.is_reason_code(str(source.get("reason_code", ""))) \
			or typeof(source.get("state_version_observed")) != TYPE_INT \
			or int(source.get("state_version_observed", -2)) < -1 \
			or not (source.get("ruleset_id_observed") is String or source.get("ruleset_id_observed") is StringName) \
			or typeof(source.get("private_payload_redacted")) != TYPE_BOOL \
			or not bool(source.get("private_payload_redacted", false)):
		return {}
	for boolean_field in [
		"method_missing", "method_exception", "result_not_dictionary", "result_empty",
		"result_not_pure_data", "result_header_invalid", "result_version_invalid",
		"result_ruleset_invalid", "live_state_mutated_during_capture",
	]:
		if typeof(source.get(boolean_field)) != TYPE_BOOL:
			return {}
	var normalized := CAPTURE_FAILURE.build(source)
	if not _has_exact_fields(normalized, TARGETED_OWNER_DIAGNOSTIC.FAILURE_FIELDS):
		return {}
	for field_variant in TARGETED_OWNER_DIAGNOSTIC.FAILURE_FIELDS:
		var field := str(field_variant)
		if normalized.get(field) != source.get(field):
			return {}
	match str(source.get("failure_class", "")):
		"OWNER_METHOD_MISSING":
			if not bool(source.get("method_missing", false)):
				return {}
		"OWNER_CAPTURE_EXCEPTION":
			if not bool(source.get("method_exception", false)):
				return {}
		"OWNER_CAPTURE_WRONG_TYPE":
			if not bool(source.get("result_not_dictionary", false)):
				return {}
		"OWNER_CAPTURE_EMPTY":
			if not bool(source.get("result_empty", false)):
				return {}
		"OWNER_CAPTURE_NOT_PURE_DATA":
			if not bool(source.get("result_not_pure_data", false)):
				return {}
		"OWNER_CAPTURE_HEADER_INVALID":
			if not bool(source.get("result_header_invalid", false)):
				return {}
		"OWNER_CAPTURE_VERSION_INVALID":
			if not bool(source.get("result_version_invalid", false)):
				return {}
		"OWNER_CAPTURE_RULESET_INVALID":
			if not bool(source.get("result_ruleset_invalid", false)):
				return {}
		"OWNER_CAPTURE_MUTATED_RUNTIME":
			if not bool(source.get("live_state_mutated_during_capture", false)):
				return {}
	return normalized


func _write_targeted_owner_capture_diagnostic(options: Dictionary, base: Dictionary) -> Dictionary:
	if _targeted_diagnostic_written:
		return {"valid": false, "reason_code": "targeted_owner_capture_diagnostic_already_written"}
	var phase_rows: Array = _targeted_diagnostic_timeline.get("phase_rows", []) \
			if _targeted_diagnostic_timeline.get("phase_rows", []) is Array else []
	var owner_audit_started := false
	var owner_audit_completed := false
	for phase_row_variant in phase_rows:
		if not (phase_row_variant is Dictionary):
			continue
		var phase_id := str((phase_row_variant as Dictionary).get("phase_id", ""))
		owner_audit_started = owner_audit_started or phase_id == "owner_audit_started"
		owner_audit_completed = owner_audit_completed or phase_id == "owner_audit_completed"
	if str(_targeted_diagnostic_timeline.get("current_phase", "")) != "diagnostic_completed":
		var terminal_reason := "diagnostic_owner_audit_completed" if owner_audit_started \
				else "diagnostic_pre_owner_%s" % _safe_reason_code(str(base.get("failure_code", "harness_failure")))
		if not _advance_targeted_diagnostic_phase("diagnostic_completed", -1, true, terminal_reason):
			return {"valid": false, "reason_code": _targeted_diagnostic_phase_failure}
		phase_rows = _targeted_diagnostic_timeline.get("phase_rows", []) as Array
	var owner_rows := _safe_owner_capture_v2_rows(_targeted_diagnostic_capture.get("section_results", [])) \
			if owner_audit_started else []
	if owner_audit_started and owner_rows.size() != SAVE_SECTION_ORDER.size():
		return {"valid": false, "reason_code": "targeted_owner_capture_row_shape_invalid"}
	var first_failure := _safe_owner_capture_failure(_targeted_diagnostic_capture.get("first_failure", {}))
	var post_capture_failure := _safe_owner_capture_failure(_targeted_diagnostic_capture.get("post_capture_failure", {}))
	var last_completed_owner_index := -1
	var safety_green := _targeted_diagnostic_phase_failure.is_empty()
	for row_variant in owner_rows:
		var row := row_variant as Dictionary
		if str(row.get("capture_result_kind", "")) in ["CAPTURED", "FAILED"]:
			last_completed_owner_index = int(row.get("owner_index", -1))
		safety_green = safety_green \
				and int(row.get("mutation_count", 0)) == 0 \
				and int(row.get("rng_draw_delta", 0)) == 0 \
				and int(row.get("world_time_delta", 0)) == 0 \
				and int(row.get("public_log_delta", 0)) == 0
	var post_validation := "NOT_RUN"
	if owner_audit_started:
		post_validation = "FAILED" if not post_capture_failure.is_empty() \
				else ("PASSED" if bool(_targeted_diagnostic_capture.get("captured", false)) else "NOT_RUN_AFTER_OWNER_FAILURE")
	var diagnostic := TARGETED_OWNER_DIAGNOSTIC.build({
		"run_id": str(options.get("run_id", "")),
		"repository_head": str(base.get("head_sha", options.get("repository_head", ""))),
		"scenario_identity": _targeted_diagnostic_identity,
		"scenario_identity_attested": not _targeted_diagnostic_identity.is_empty(),
		"scenario_identity_failure": _targeted_diagnostic_pre_owner_failure,
		"harness_or_scenario_failure_attested": not owner_audit_started and not _targeted_diagnostic_pre_owner_failure.is_empty(),
		"diagnostic_phase_timeline": _targeted_diagnostic_timeline,
		"owner_audit_started": owner_audit_started,
		"owner_audit_completed": owner_audit_completed,
		"first_owner_capture_index": 0 if owner_audit_started else -1,
		"last_completed_owner_capture_index": last_completed_owner_index,
		"owner_capture_rows": owner_rows,
		"first_failure": first_failure,
		"owner_capture_failure_attested": not first_failure.is_empty(),
		"post_capture_validation": post_validation,
		"post_capture_failure": post_capture_failure,
		"safety_green": safety_green,
	})
	if diagnostic.is_empty():
		return {"valid": false, "reason_code": "targeted_owner_capture_diagnostic_build_failed"}
	return CHILD_ATTESTATION.write_owner_capture_diagnostic(
		str(options.get("run_id", "")),
		diagnostic,
		str(options.get("repository_head", base.get("head_sha", ""))),
		str(options.get("scenario_fingerprint", ""))
	)


func _build_targeted_scenario_identity(context: Dictionary, started: Dictionary, options: Dictionary) -> Dictionary:
	var registry: Node = context.get("registry")
	var registry_snapshot: Dictionary = registry.call("registry_snapshot") \
			if registry != null and registry.has_method("registry_snapshot") else {}
	var ruleset_owner := registry.get_node_or_null("../RulesetSaveAttestationOwner") \
			if registry != null else null
	var ruleset_attestation: Dictionary = ruleset_owner.call("debug_snapshot") \
			if ruleset_owner != null and ruleset_owner.has_method("debug_snapshot") else {}
	var coordinator := context.get("coordinator") as GameRuntimeCoordinator
	var world := coordinator.world_session_state() if coordinator != null else null
	var world_geometry: Dictionary = world.public_world_geometry_snapshot() if world != null else {}
	var world_lifecycle: Dictionary = world.public_lifecycle_snapshot() if world != null else {}
	var roster_identity: Array = []
	var actual_local_player_count := 0
	var actual_ai_player_count := 0
	if world != null:
		for player_index in range(world.players.size()):
			var player: Dictionary = world.players[player_index] if world.players[player_index] is Dictionary else {}
			if bool(player.get("is_ai", false)):
				actual_ai_player_count += 1
			else:
				actual_local_player_count += 1
			roster_identity.append({
				"player_index": player_index,
				"actor_id": str(player.get("actor_id", "player.%d" % player_index)),
				"is_ai": bool(player.get("is_ai", false)),
			})
	var composition_paths := [
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController/V06SaveOwnerRegistry",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController/GameSaveRuntimeCoordinator",
		"RuntimeServices/SaveResumeApplicationFlowController",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/FacilityCardQueueAdapterV06",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardResolutionQueueRuntimeService",
		"RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardResolutionExecutionRuntimeService",
	]
	var composition_presence: Array = []
	var composition_complete := true
	var main: Node = context.get("main")
	for path_variant in composition_paths:
		var path := str(path_variant)
		var node := main.get_node_or_null(path) if main != null else null
		composition_complete = composition_complete and node != null
		composition_presence.append({"path": path, "present": node != null, "class": node.get_class() if node != null else ""})
	var world_revision := int(world_geometry.get("revision", -1))
	if int(world_lifecycle.get("session_revision", -2)) != world_revision:
		world_revision = -1
	return DIAGNOSTIC_SCENARIO_IDENTITY.build({
		"run_id": str(options.get("run_id", "")),
		"repository_head": str(options.get("repository_head", "")),
		"ruleset_id": str(ruleset_attestation.get("ruleset_id", "")),
		"ruleset_fingerprint": _diagnostic_value_fingerprint(ruleset_attestation),
		"challenge_depth": int(started.get("challenge_depth", -1)),
		"run_seed": int(started.get("seed", 0)),
		"session_seed": int(started.get("session_seed", 0)),
		"scenario_fingerprint": str(started.get("scenario_fingerprint", "")),
		"local_player_count": actual_local_player_count,
		"ai_player_count": actual_ai_player_count,
		"roster_fingerprint": _diagnostic_value_fingerprint(roster_identity),
		"session_id": str(started.get("session_id", "")),
		"session_generation": int(started.get("session_generation", -1)),
		"session_plan_fingerprint": str(started.get("session_plan_fingerprint", "")),
		"world_revision": world_revision,
		"runtime_composition_fingerprint": _diagnostic_value_fingerprint(composition_presence) \
				if composition_complete else "",
		"save_registry_fingerprint": _diagnostic_value_fingerprint({
			"fixed_section_order": registry_snapshot.get("fixed_capture_order", []),
			"contracts": registry_snapshot.get("contracts", []),
			"transactional_section_count": registry_snapshot.get("transactional_section_count", 0),
		}),
		"user_data_path_fingerprint": OS.get_user_data_dir().sha256_text().to_lower(),
	})


func _diagnostic_value_fingerprint(value: Variant) -> String:
	var canonical := JSON.stringify(value, "", true, true)
	return canonical.sha256_text().to_lower() if not canonical.is_empty() else ""


func _attest_targeted_registry_binding(context: Dictionary) -> Dictionary:
	var registry: Node = context.get("registry")
	if registry == null or not registry.has_method("registry_snapshot") \
			or not registry.has_method("fixed_section_order"):
		return {"attested": false, "failure": _diagnostic_pre_owner_failure(
			"save_registry", "diagnostic_registry_binding_not_ready", "registry_ready", "missing"
		)}
	var snapshot: Dictionary = registry.call("registry_snapshot")
	var observed_order: Array = registry.call("fixed_section_order")
	if not bool(snapshot.get("resume_ready", false)) \
			or int(snapshot.get("transactional_section_count", 0)) != SAVE_SECTION_ORDER.size() \
			or int(snapshot.get("unsupported_section_count", -1)) != 0:
		return {"attested": false, "failure": _diagnostic_pre_owner_failure(
			"save_registry", "diagnostic_registry_binding_count_mismatch",
			"19_transactional_0_unsupported",
			"%d_transactional_%d_unsupported" % [int(snapshot.get("transactional_section_count", 0)), int(snapshot.get("unsupported_section_count", -1))]
		)}
	if observed_order != SAVE_SECTION_ORDER:
		return {"attested": false, "failure": _diagnostic_pre_owner_failure(
			"save_registry", "diagnostic_registry_binding_order_mismatch",
			SEMANTIC_WIRE.fingerprint(SAVE_SECTION_ORDER).left(12),
			SEMANTIC_WIRE.fingerprint(observed_order).left(12)
		)}
	var contracts: Array = snapshot.get("contracts", []) \
			if snapshot.get("contracts", []) is Array else []
	if contracts.size() != SAVE_SECTION_ORDER.size():
		return {"attested": false, "failure": _diagnostic_pre_owner_failure(
			"save_registry", "diagnostic_registry_binding_contract_mismatch",
			"19_contracts", "%d_contracts" % contracts.size()
		)}
	for contract_index in range(contracts.size()):
		if not (contracts[contract_index] is Dictionary):
			return {"attested": false, "failure": _diagnostic_pre_owner_failure(
				"save_registry", "diagnostic_registry_binding_contract_mismatch",
				"dictionary", "invalid_contract_%d" % contract_index
			)}
		var contract := contracts[contract_index] as Dictionary
		if str(contract.get("section_id", "")) != str(SAVE_SECTION_ORDER[contract_index]) \
				or str(contract.get("owner_id", "")) != str(SAVE_OWNER_ORDER[contract_index]) \
				or int(contract.get("state_version", 0)) != int(SAVE_STATE_VERSION_ORDER[contract_index]) \
				or str(contract.get("restore_mode", "")) != "transactional" \
				or str(contract.get("preflight_method", "")).is_empty() \
				or str(contract.get("checkpoint_method", "")).is_empty():
			return {"attested": false, "failure": _diagnostic_pre_owner_failure(
				"save_registry", "diagnostic_registry_binding_contract_mismatch",
				"contract_%d" % contract_index,
				"mismatch_%d" % contract_index
			)}
	return {"attested": true, "failure": {}}


func _acquire_process_a_save_barrier(context: Dictionary, operation_id: String) -> Dictionary:
	var barrier := context.get("barrier") as SaveRestoreRuntimeBarrier
	var runtime_loop := context.get("runtime_loop") as RuntimeLoop
	var session := context.get("session") as GameSessionRuntimeController
	if barrier == null or runtime_loop == null or session == null:
		return {"acquired": false, "reason_code": "process_a_save_barrier_missing"}
	if session.session_state() not in [
		GameSessionRuntimeController.STATE_RUNNING,
		GameSessionRuntimeController.STATE_PAUSED,
	]:
		return {"acquired": false, "reason_code": "process_a_save_session_state_invalid"}
	var lease := TERMINAL_EVIDENCE.acquire_manual_lease(context)
	if not bool(lease.get("accepted", false)):
		return {
			"acquired": false,
			"reason_code": str(lease.get("reason_code", "process_a_save_manual_lease_failed")),
		}
	var checkpoint := barrier.capture_global_checkpoint(operation_id)
	if not bool(checkpoint.get("accepted", false)):
		TERMINAL_EVIDENCE.release_manual_lease(context)
		return {
			"acquired": false,
			"reason_code": str(checkpoint.get("reason_code", "process_a_save_barrier_checkpoint_failed")),
		}
	var entered := barrier.enter_restore_barrier(
		operation_id,
		(checkpoint.get("checkpoint", {}) as Dictionary).duplicate(true)
	)
	if not bool(entered.get("acquired", false)):
		TERMINAL_EVIDENCE.release_manual_lease(context)
		return {
			"acquired": false,
			"reason_code": str(entered.get("reason_code", "process_a_save_barrier_acquire_failed")),
		}
	var quiet := barrier.verify_restore_quiet(operation_id)
	var rollback := barrier.rollback_restore_barrier(operation_id)
	var barrier_debug := barrier.debug_snapshot()
	var session_barrier := session.restore_barrier_snapshot()
	var loop_debug := runtime_loop.debug_snapshot()
	var restore_barrier_closed := bool(quiet.get("accepted", false)) \
			and bool(rollback.get("applied", false)) \
			and not bool(barrier_debug.get("active", true)) \
			and not bool(session_barrier.get("active", true)) \
			and not bool(loop_debug.get("restore_barrier_held", true)) \
			and not runtime_loop.is_processing() \
			and session.session_state() in [
				GameSessionRuntimeController.STATE_RUNNING,
				GameSessionRuntimeController.STATE_PAUSED,
			]
	if not restore_barrier_closed:
		var release_failed_lease := TERMINAL_EVIDENCE.release_manual_lease(context)
		return {
			"acquired": false,
			"reason_code": str(quiet.get("reason_code", "process_a_save_restore_quiet_failed")) \
					if not bool(quiet.get("accepted", false)) else (
						str(rollback.get("reason_code", "process_a_save_restore_rollback_failed")) \
						if not bool(rollback.get("applied", false)) else (
							"process_a_save_manual_lease_release_failed" \
							if not bool(release_failed_lease.get("released", false)) \
							else "process_a_save_restore_barrier_cleanup_failed"
						)
					),
		}
	var checkpoint_value: Dictionary = checkpoint.get("checkpoint", {}) \
			if checkpoint.get("checkpoint", {}) is Dictionary else {}
	return {
		"acquired": true,
		"reason_code": "process_a_save_barrier_acquired",
		"operation_id": operation_id,
		"safety_observation": (checkpoint_value.get("safety_observation", {}) as Dictionary).duplicate(true),
		"world_digest": _world_digest(context),
		"frame_index": int(lease.get("frame_index", -1)),
		"restore_barrier_quiet": true,
		"restore_barrier_rolled_back": true,
	}


func _release_process_a_save_barrier(
	context: Dictionary,
	operation_id: String,
	barrier_receipt: Dictionary
) -> Dictionary:
	var runtime_loop := context.get("runtime_loop") as RuntimeLoop
	if runtime_loop == null:
		return {"released": false, "quiet": false, "reason_code": "process_a_save_barrier_missing"}
	var before: Dictionary = barrier_receipt.get("safety_observation", {}) \
			if barrier_receipt.get("safety_observation", {}) is Dictionary else {}
	var after := _safety_observation(context)
	var world_digest_after := _world_digest(context)
	var quiet_report := _evaluate_process_a_quiet_window(
		operation_id,
		barrier_receipt,
		after,
		world_digest_after
	)
	var quiet := bool(quiet_report.get("quiet", false))
	var loop_debug_before_release := runtime_loop.debug_snapshot()
	var frame_unchanged := int(loop_debug_before_release.get("frame_index", -1)) \
			== int(barrier_receipt.get("frame_index", -2)) \
			and not runtime_loop.is_processing() \
			and not bool(loop_debug_before_release.get("restore_barrier_held", true))
	var release := TERMINAL_EVIDENCE.release_manual_lease(context)
	var loop_debug := runtime_loop.debug_snapshot()
	var barrier := context.get("barrier") as SaveRestoreRuntimeBarrier
	var session := context.get("session") as GameSessionRuntimeController
	var barrier_debug := barrier.debug_snapshot() if barrier != null else {}
	var session_barrier := session.restore_barrier_snapshot() if session != null else {}
	var cleanup_released := bool(release.get("released", false)) and runtime_loop.is_processing() \
			and not bool(loop_debug.get("restore_barrier_held", true)) \
			and barrier != null and not bool(barrier_debug.get("active", true)) \
			and session != null and not bool(session_barrier.get("active", true))
	var failure_codes: Array[String] = []
	if not quiet:
		failure_codes.append(str(quiet_report.get(
			"reason_code",
			"process_a_save_barrier_quiet_window_violated"
		)))
	if not frame_unchanged:
		failure_codes.append("process_a_save_barrier_frame_advanced")
	if not bool(release.get("released", false)):
		failure_codes.append(str(release.get(
			"reason_code",
			"process_a_save_manual_lease_release_failed"
		)))
	elif not cleanup_released:
		failure_codes.append("process_a_save_barrier_cleanup_failed")
	var ordered_failures := _unique_reason_codes(failure_codes)
	return {
		"released": ordered_failures.is_empty(),
		"quiet": quiet and frame_unchanged,
		"quiet_deltas": quiet_report.get("quiet_deltas", {}),
		"reason_code": "process_a_save_barrier_released" if ordered_failures.is_empty() \
				else ordered_failures[0],
		"secondary_failure_codes": ordered_failures.slice(1),
	}


static func _evaluate_process_a_quiet_window(
	operation_id: String,
	barrier_receipt: Dictionary,
	after: Dictionary,
	world_digest_after: String
) -> Dictionary:
	var before: Dictionary = barrier_receipt.get("safety_observation", {}) \
			if barrier_receipt.get("safety_observation", {}) is Dictionary else {}
	var quiet_deltas := {}
	var observation_valid := not before.is_empty() and not after.is_empty()
	var deltas_zero := observation_valid
	for field in PROCESS_A_SAVE_QUIET_FIELDS:
		var field_valid := before.has(field) and after.has(field) \
				and typeof(before.get(field)) == TYPE_INT and typeof(after.get(field)) == TYPE_INT
		var delta := int(after.get(field)) - int(before.get(field)) if field_valid else -1
		quiet_deltas[field] = delta
		observation_valid = observation_valid and field_valid
		deltas_zero = deltas_zero and field_valid and delta == 0
	var receipt_bound := not operation_id.is_empty() \
			and str(barrier_receipt.get("operation_id", "")) == operation_id
	var world_digest_before := str(barrier_receipt.get("world_digest", ""))
	var world_stable := not world_digest_before.is_empty() \
			and world_digest_before == world_digest_after
	var quiet := receipt_bound and observation_valid and world_stable and deltas_zero
	var reason_code := "process_a_save_barrier_quiet"
	if not receipt_bound:
		reason_code = "process_a_save_barrier_operation_mismatch"
	elif not observation_valid:
		reason_code = "process_a_save_barrier_observation_invalid"
	elif not world_stable:
		reason_code = "process_a_save_barrier_world_drift"
	elif not deltas_zero:
		reason_code = "process_a_save_barrier_quiet_window_violated"
	return {
		"quiet": quiet,
		"reason_code": reason_code,
		"quiet_deltas": quiet_deltas,
	}


static func _ordered_process_a_boundary_failures(
	save_failure_code: String,
	release_observation: Dictionary
) -> Dictionary:
	var failure_codes: Array[String] = []
	if not save_failure_code.is_empty():
		failure_codes.append(save_failure_code)
	if not bool(release_observation.get("released", false)):
		failure_codes.append(str(release_observation.get(
			"reason_code",
			"process_a_save_barrier_cleanup_failed"
		)))
		for secondary_variant in release_observation.get("secondary_failure_codes", []):
			failure_codes.append(str(secondary_variant))
	var ordered := _unique_reason_codes(failure_codes)
	return {
		"primary_failure_code": "" if ordered.is_empty() else ordered[0],
		"secondary_failure_codes": ordered.slice(1),
	}


static func _unique_reason_codes(values: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		if not value.is_empty() and not result.has(value):
			result.append(value)
	return result


func _save_file_metrics(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"exists": false, "bytes": 0, "sha256": ""}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"exists": false, "bytes": 0, "sha256": ""}
	var byte_count := file.get_length()
	file.close()
	var sha256 := FileAccess.get_sha256(path).to_lower()
	return {
		"exists": byte_count > 0 and _is_lower_sha256(sha256),
		"bytes": byte_count,
		"sha256": sha256,
	}


func _save_via_player_flow(context: Dictionary, save_path: String, destructive_confirmed: bool) -> Dictionary:
	if save_path != SaveSlotPolicyV06.PRODUCTION_PATH:
		return {"ok": false, "reason_code": "production_slot_path_required"}
	var flow := context.get("flow") as SaveResumeApplicationFlowController
	if flow == null:
		return {"ok": false, "reason_code": "save_resume_flow_missing"}
	var registry: Node = context.get("registry")
	var registry_before: Dictionary = registry.call("debug_snapshot") \
			if registry != null and registry.has_method("debug_snapshot") else {}
	var before_observation := _safety_observation(context)
	var before_world := _world_digest(context)
	_enter_process_a_phase("save_capture_complete")
	var receipt := flow.request_save_game(&"pause_menu", destructive_confirmed)
	var after_observation := _safety_observation(context)
	var after_world := _world_digest(context)
	if receipt == null or not receipt.accepted or not receipt.applied:
		var save_debug: Dictionary = (context.get("save") as Node).call("debug_snapshot")
		var internal_reason := str(save_debug.get("last_readback_validation_reason", ""))
		var mismatch_sections: Array = save_debug.get("last_readback_mismatch_sections", []) if save_debug.get("last_readback_mismatch_sections", []) is Array else []
		var registry_for_failure: Node = context.get("registry")
		var registry_debug: Dictionary = registry_for_failure.call("debug_snapshot") \
				if registry_for_failure != null and registry_for_failure.has_method("debug_snapshot") else {}
		var capture_section := str(registry_debug.get("last_internal_capture_failure_section", ""))
		var capture_reason := str(registry_debug.get("last_internal_capture_failure_reason", ""))
		if receipt != null and receipt.reason_code == "owner_capture_failed" \
				and not capture_section.is_empty() and not capture_reason.is_empty():
			internal_reason = "capture:%s:%s" % [capture_section, capture_reason]
		if not bool(save_debug.get("last_readback_fingerprint_match", true)):
			var first_mismatch: Dictionary = save_debug.get("last_readback_first_mismatch", {}) if save_debug.get("last_readback_first_mismatch", {}) is Dictionary else {}
			var mismatch_path_fingerprint := str(first_mismatch.get("path", "")).sha256_text().substr(0, 12)
			internal_reason = "readback:%s:path_%s:%s>%s:%s>%s" % [
				",".join(mismatch_sections),
				mismatch_path_fingerprint,
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
	_complete_process_a_phase("save_capture_complete", {
		"receipt_present": true,
		"accepted": true,
		"applied": true,
	})
	_enter_process_a_phase("envelope_encode_complete")
	_complete_process_a_phase("envelope_encode_complete", {
		"save_receipt_reason_code": receipt.reason_code,
		"observation_kind": "postcondition_projection",
	}, "postcondition_projection")
	_enter_process_a_phase("atomic_write_complete")
	_update_process_a_save_timeline(save_path)
	_complete_process_a_phase("atomic_write_complete", {
		"save_file_exists": FileAccess.file_exists(save_path),
		"observation_kind": "postcondition_projection",
	}, "postcondition_projection")
	_enter_process_a_phase("save_readback_complete")
	var read := _read_slot(context, save_path)
	if not bool(read.get("ok", false)):
		return read
	var save_runtime: Node = context.get("save")
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
	var save_debug_after: Dictionary = save_runtime.call("debug_snapshot") \
			if save_runtime != null and save_runtime.has_method("debug_snapshot") else {}
	var registry_after: Dictionary = registry.call("debug_snapshot") \
			if registry != null and registry.has_method("debug_snapshot") else {}
	var capture_operation_sequence := int(registry_after.get("last_capture_operation_sequence", 0))
	var capture_sections_fingerprint := str(registry_after.get("last_capture_sections_fingerprint", ""))
	var capture_envelope_fingerprint := str(registry_after.get("last_capture_envelope_fingerprint", ""))
	if capture_operation_sequence <= int(registry_before.get("operation_sequence", 0)) \
			or int(registry_after.get("last_capture_section_count", 0)) != 19 \
			or capture_sections_fingerprint != str(read.get("sections_digest", "")) \
			or capture_envelope_fingerprint != str(read.get("write_fingerprint", "")) \
			or str(registry_after.get("last_capture_write_id", "")) != str(read.get("write_id", "")):
		return {"ok": false, "reason_code": "save_capture_readback_attestation_mismatch"}
	return {
		"ok": true,
		"reason_code": receipt.reason_code,
		"sections_digest": str(read.get("sections_digest", "")),
		"section_count": int(read.get("section_count", 0)),
		"preflight_count": int(preflight.get("preflight_count", 0)),
		"write_id": str(read.get("write_id", "")),
		"write_fingerprint": str(read.get("write_fingerprint", "")),
		"capture_operation_sequence": capture_operation_sequence,
		"capture_section_count": int(registry_after.get("last_capture_section_count", 0)),
		"capture_sections_fingerprint": capture_sections_fingerprint,
		"capture_envelope_fingerprint": capture_envelope_fingerprint,
		"readback_fingerprint_match": bool(save_debug_after.get("last_readback_fingerprint_match", false)) \
			and str(save_debug_after.get("last_readback_validation_reason", "")).begins_with("valid_"),
		"backup_created": bool(read.get("backup_available", false)),
		"save_capture_world_delta": 0 if before_world == after_world else 1,
		"save_capture_rng_delta": _delta(before_observation, after_observation, "rng_draw_invocation_count"),
		"save_capture_log_delta": _delta(before_observation, after_observation, "public_log_entry_count"),
		"rng_draw_count": int(after_observation.get("rng_draw_invocation_count", 0)),
		"readback_envelope": envelope.duplicate(true),
		"readback_phase_evidence": {
			"section_count": int(read.get("section_count", 0)),
			"preflight_count": int(preflight.get("preflight_count", 0)),
		},
	}


func _readback_victory_unresolved(context: Dictionary, envelope: Dictionary) -> bool:
	var sections: Dictionary = envelope.get("sections", {}) \
			if envelope.get("sections", {}) is Dictionary else {}
	var wrapper: Dictionary = sections.get("victory_control", {}) \
			if sections.get("victory_control", {}) is Dictionary else {}
	var handshake: Node = context.get("handshake")
	if handshake == null or not handshake.has_method("decode_codec_value") \
			or not wrapper.has("owner_state"):
		return false
	var decoded_variant: Variant = handshake.call("decode_codec_value", wrapper.get("owner_state"))
	var decoded: Dictionary = decoded_variant if decoded_variant is Dictionary else {}
	var owner_state: Dictionary = decoded.get("value", {}) \
			if decoded.get("value", {}) is Dictionary else {}
	var runtime: Dictionary = owner_state.get("victory_control_runtime", {}) \
			if owner_state.get("victory_control_runtime", {}) is Dictionary else {}
	return bool(decoded.get("ok", false)) \
			and str(runtime.get("state", "")) in ["idle", "qualification", "audit"] \
			and int(runtime.get("outcome_sequence", -1)) == 0 \
			and runtime.get("outcome_receipt", {}) is Dictionary \
			and (runtime.get("outcome_receipt", {}) as Dictionary).is_empty()


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
	var coordinator := context.get("coordinator") as GameRuntimeCoordinator
	if flow == null or registry == null or barrier == null or coordinator == null:
		return {"ok": false, "reason_code": "resume_flow_dependency_missing"}
	var read := _read_slot(context, save_path)
	var envelope: Dictionary = read.get("envelope", {}) \
			if read.get("envelope", {}) is Dictionary else {}
	if not bool(read.get("ok", false)) or envelope.is_empty() \
			or not registry.has_method("preflight_envelope"):
		return {"ok": false, "reason_code": "resume_preflight_source_unavailable"}
	var preflight_variant: Variant = registry.call("preflight_envelope", envelope.duplicate(true))
	var preflight: Dictionary = preflight_variant if preflight_variant is Dictionary else {}
	if not bool(preflight.get("ok", false)) \
			or not bool(preflight.get("preflight_complete", false)) \
			or int(preflight.get("preflight_count", 0)) != SAVE_SECTION_ORDER.size():
		return {
			"ok": false,
			"reason_code": str(preflight.get("reason_code", "resume_preflight_failed")),
			"preflight_count": int(preflight.get("preflight_count", 0)),
		}
	var inspection := flow.inspect_slot(&"root_menu")
	if inspection == null or not inspection.accepted or not inspection.can_resume:
		return {"ok": false, "reason_code": inspection.reason_code if inspection != null else "slot_inspection_failed"}
	var debug_before: Dictionary = registry.call("debug_snapshot")
	var barrier_before := barrier.debug_snapshot()
	var coordinator_before := coordinator.capture_save_restore_runtime_checkpoint()
	var receipt := flow.request_resume_game(&"root_menu", false)
	var debug_after: Dictionary = registry.call("debug_snapshot")
	var barrier_after := barrier.debug_snapshot()
	var coordinator_after := coordinator.capture_save_restore_runtime_checkpoint()
	var barrier_debug := barrier.debug_snapshot()
	var quiet: Dictionary = barrier_debug.get("last_quiet_deltas", {}) if barrier_debug.get("last_quiet_deltas", {}) is Dictionary else {}
	var registry_commit_delta := int(debug_after.get("restore_commit_count", 0)) \
			- int(debug_before.get("restore_commit_count", 0))
	var registry_rebind_delta := int(debug_after.get("post_restore_rebind_count", 0)) \
			- int(debug_before.get("post_restore_rebind_count", 0))
	var registry_rollback_delta := int(debug_after.get("restore_rollback_count", 0)) \
			- int(debug_before.get("restore_rollback_count", 0))
	var barrier_enter_delta := int(barrier_after.get("enter_count", 0)) \
			- int(barrier_before.get("enter_count", 0))
	var barrier_commit_delta := int(barrier_after.get("commit_count", 0)) \
			- int(barrier_before.get("commit_count", 0))
	var barrier_rollback_delta := int(barrier_after.get("rollback_count", 0)) \
			- int(barrier_before.get("rollback_count", 0))
	var coordinator_rebind_delta := int(coordinator_after.get("rebind_count", 0)) \
			- int(coordinator_before.get("rebind_count", 0))
	var coordinator_generation_delta := int(coordinator_after.get("rebind_generation", 0)) \
			- int(coordinator_before.get("rebind_generation", 0))
	var coordinator_refresh_delta := int(coordinator_after.get("full_refresh_count", 0)) \
			- int(coordinator_before.get("full_refresh_count", 0))
	var registry_operation_delta := int(debug_after.get("operation_sequence", 0)) \
			- int(debug_before.get("operation_sequence", 0))
	var cross_owner_exact := registry_commit_delta == 1 and registry_rollback_delta == 0 \
			and barrier_enter_delta == 1 and barrier_commit_delta == 1 \
			and barrier_rollback_delta == 0 \
			and registry_rebind_delta == 1 and coordinator_rebind_delta == 1 \
			and coordinator_generation_delta == 1 and coordinator_refresh_delta == 1 \
			and registry_operation_delta == 1 \
			and int(debug_after.get("last_owner_apply_count", 0)) == SAVE_SECTION_ORDER.size() \
			and int(debug_after.get("last_registry_apply_count", 0)) == 1 \
			and int(debug_before.get("partial_restore_state_count", -1)) == 0 \
			and int(debug_after.get("partial_restore_state_count", -1)) == 0
	var ok := receipt != null and receipt.accepted and receipt.applied and cross_owner_exact
	return {
		"ok": ok,
		"reason_code": (
			receipt.reason_code if receipt != null and cross_owner_exact \
			else ("resume_cross_owner_commit_rebind_mismatch" if receipt != null \
			else "resume_receipt_missing")
		),
		"preflight_count": int(preflight.get("preflight_count", 0)),
		"apply_count": int(debug_after.get("last_owner_apply_count", 0)),
		"registry_apply_count": int(debug_after.get("last_registry_apply_count", 0)),
		"registry_commit_count": registry_commit_delta,
		"registry_rollback_count": registry_rollback_delta,
		"post_restore_rebind_count": registry_rebind_delta,
		"barrier_enter_count": barrier_enter_delta,
		"barrier_commit_count": barrier_commit_delta,
		"barrier_rollback_count": barrier_rollback_delta,
		"coordinator_rebind_count": coordinator_rebind_delta,
		"coordinator_rebind_generation_count": coordinator_generation_delta,
		"coordinator_full_refresh_count": coordinator_refresh_delta,
		"registry_operation_count": registry_operation_delta,
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
	_complete_process_a_phase("real_commodity_claim_complete", {
		"commodity_card_id": str(claim.get("commodity_card_id", "")),
	})
	_record_targeted_owner_capture_audit(context, "real_commodity_claim_complete")
	_enter_process_a_phase("real_normal_card_purchase_complete")
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
	_complete_process_a_phase("real_normal_card_purchase_complete", {
		"purchase_count": int(first_purchase.get("purchase_count", 0)),
		"card_id": str(selected_plan.get("first_card_id", "")),
	})
	_record_targeted_owner_capture_audit(context, "real_normal_card_purchase_complete")
	_enter_process_a_phase("real_facility_economy_complete")
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
	_complete_process_a_phase("real_facility_economy_complete", {
		"card_id": str(selected_plan.get("first_card_id", "")),
		"target_region_id": str(first_target.get("region_id", "")),
	})
	_record_targeted_owner_capture_audit(context, "real_facility_economy_complete")
	_enter_process_a_phase("first_sale_receipt_complete")
	coordinator.resume_session()
	var sales := _advance_until_product_sale(context, str(selected_plan.get("product_id", "")))
	coordinator.pause_session()
	if int(sales.get("owned_sale_receipt_count", 0)) <= 0:
		return {
			"ready": false,
			"reason_code": str(sales.get("reason_code", "facility_checkpoint_sale_missing")),
			"diagnostics": {"sales": sales.duplicate(true)},
		}
	_complete_process_a_phase("first_sale_receipt_complete", {
		"owned_sale_receipt_count": int(sales.get("owned_sale_receipt_count", 0)),
		"product_id": str(selected_plan.get("product_id", "")),
	})
	_record_targeted_owner_capture_audit(context, "first_sale_receipt_complete")
	_enter_process_a_phase("ai_nondefault_state_complete")
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
	var stable_target_valid := false
	var history_privacy_redacted := false
	var target_entry: Dictionary = {}
	if pending_count == 1:
		target_entry = matching_entries[0].duplicate(true)
		var target_validation := CardResolutionStableTargetEnvelope.validate_entry_binding(target_entry)
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
	var history_entry: Dictionary = {}
	for row_variant in history_rows:
		if row_variant is Dictionary \
				and int((row_variant as Dictionary).get("resolution_id", -1)) == resolution_id:
			history_count += 1
			history_entry = (row_variant as Dictionary).duplicate(true)
	if pending_count == 0 and history_count == 1:
		target_entry = history_entry.duplicate(true)
		history_privacy_redacted = not target_entry.has("stable_target_envelope") \
				and not target_entry.has("v06_facility_action")
	var history_lineage_count := _resolution_id_occurrence(history_lineage, resolution_id)
	var execution_debug := execution.debug_snapshot()
	var history_debug := history.debug_snapshot()
	var transition_debug := transition.debug_snapshot()
	var inventory_debug := inventory.debug_snapshot()
	var public_log_debug := public_log.debug_snapshot()
	var target_identity_valid := stable_target_valid if pending_count == 1 \
			else history_privacy_redacted if pending_count == 0 and history_count == 1 \
			else false
	var valid := pending_count <= 1 and completed_count <= 1 and history_count <= 1 \
		and history_lineage_count == history_count and target_identity_valid
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
		"history_privacy_redacted": history_privacy_redacted,
		"execution_finalize_count": int(execution_debug.get("finalized_count", -1)),
		"history_append_count": int(history_debug.get("append_count", -1)),
		"history_duplicate_count": int(history_debug.get("duplicate_append_count", -1)),
		"transition_duplicate_count": int(transition_debug.get("duplicate_count", -1)),
		"inventory_queue_commit_count": int(inventory_debug.get("queue_committed_count", -1)),
		"public_log_duplicate_count": int(public_log_debug.get("duplicate_receipt_count", -1)),
		"public_log_collision_count": int(public_log_debug.get("collision_receipt_count", -1)),
		"facility_entry": target_entry.duplicate(true) if target_entry.has("v06_facility_action") else {},
	}


func _facility_commitment_observation(context: Dictionary, entry: Dictionary) -> Dictionary:
	var coordinator := context.get("coordinator") as GameRuntimeCoordinator
	var adapter := coordinator.get_node_or_null("FacilityCardQueueAdapterV06") if coordinator != null else null
	if adapter == null or not adapter.has_method("commitment_status") \
			or not (entry.get("v06_facility_action", {}) is Dictionary):
		return {"valid": false, "reason_code": "facility_commitment_observation_missing"}
	var binding := entry.get("v06_facility_action", {}) as Dictionary
	if not bool(V06QueuedFacilityCardActionV1.validation_report(binding).get("valid", false)):
		return {"valid": false, "reason_code": "facility_commitment_binding_invalid"}
	var status_variant: Variant = adapter.call("commitment_status", entry.duplicate(true))
	var status: Dictionary = status_variant if status_variant is Dictionary else {}
	return {
		"valid": not status.is_empty(),
		"reason_code": str(status.get("reason_code", "facility_commitment_status_missing")),
		"settled": bool(status.get("settled", false)),
		"committed": bool(status.get("committed", false)),
		"released": bool(status.get("released", false)),
		"asset_outcome_id": str(status.get("asset_outcome_id", "")),
		"facility_lifecycle_state_id": str(status.get("facility_lifecycle_state_id", "")),
	}


func _facility_commitment_observation_by_resolution(
	context: Dictionary,
	resolution_id: int
) -> Dictionary:
	var coordinator := context.get("coordinator") as GameRuntimeCoordinator
	var infrastructure := coordinator.get_node_or_null("RegionInfrastructureRuntimeController") \
			if coordinator != null else null
	if resolution_id <= 0 or infrastructure == null \
			or not infrastructure.has_method("facility_action_lifecycle_snapshot"):
		return {"valid": false, "reason_code": "facility_resolution_lifecycle_missing"}
	var lifecycle_variant: Variant = infrastructure.call("facility_action_lifecycle_snapshot")
	var lifecycles: Dictionary = lifecycle_variant if lifecycle_variant is Dictionary else {}
	return _facility_commitment_observation_from_lifecycles(lifecycles, resolution_id)


static func _facility_commitment_observation_from_lifecycles(
	lifecycles: Dictionary,
	resolution_id: int
) -> Dictionary:
	if resolution_id <= 0:
		return {"valid": false, "reason_code": "facility_resolution_lifecycle_missing"}
	var prefix := "facility-resolution.%d." % resolution_id
	var matching_ids: Array[String] = []
	for transaction_id_variant in lifecycles.keys():
		var transaction_id := str(transaction_id_variant)
		if transaction_id.begins_with(prefix):
			matching_ids.append(transaction_id)
	matching_ids.sort()
	if matching_ids.size() != 1:
		return {
			"valid": false,
			"reason_code": "facility_resolution_lifecycle_ambiguous",
			"matching_lifecycle_count": matching_ids.size(),
		}
	var transaction_id := matching_ids[0]
	var lifecycle: Dictionary = lifecycles.get(transaction_id, {}) \
			if lifecycles.get(transaction_id, {}) is Dictionary else {}
	var terminal_receipt: Dictionary = lifecycle.get("terminal_receipt", {}) \
			if lifecycle.get("terminal_receipt", {}) is Dictionary else {}
	var valid := str(lifecycle.get("transaction_id", "")) == transaction_id \
			and str(lifecycle.get("state", "")) == "finalized" \
			and not bool(lifecycle.get("rollback_open", true)) \
			and str(terminal_receipt.get("transaction_id", "")) == transaction_id \
			and str(terminal_receipt.get("receipt_kind", "")) == "facility_action_finalize" \
			and bool(terminal_receipt.get("committed", false)) \
			and bool(terminal_receipt.get("finalized", false)) \
			and not bool(terminal_receipt.get("rolled_back", true)) \
			and not bool(terminal_receipt.get("duplicate", true))
	return {
		"valid": valid,
		"reason_code": "facility_resolution_lifecycle_finalized" if valid \
				else "facility_resolution_lifecycle_invalid",
		"settled": valid,
		"committed": valid,
		"released": false,
		"facility_lifecycle_state_id": str(lifecycle.get("state", "")),
		"matching_lifecycle_count": matching_ids.size(),
	}


static func _authoritative_duplicate_observation(context: Dictionary) -> Dictionary:
	var coordinator := context.get("coordinator") as GameRuntimeCoordinator
	if coordinator == null:
		return {"valid": false, "reason_code": "duplicate_observation_coordinator_missing"}
	var queue := coordinator.get_node_or_null("CardResolutionQueueRuntimeService") as CardResolutionQueueRuntimeService
	var execution := coordinator.get_node_or_null("CardResolutionExecutionRuntimeService") as CardResolutionExecutionRuntimeService
	var history := coordinator.get_node_or_null("CardResolutionHistoryRuntimeService") as CardResolutionHistoryRuntimeService
	var transition := coordinator.get_node_or_null("CardResolutionTransitionSink") as CardResolutionTransitionSink
	var inventory := coordinator.get_node_or_null("CardInventoryRuntimeService") as CardInventoryRuntimeService
	var public_log := coordinator.get_node_or_null("TablePresentationQueryPorts/PublicLogPresentationOwner") \
			as PublicLogPresentationOwner
	var infrastructure := coordinator.get_node_or_null("RegionInfrastructureRuntimeController")
	var mana := coordinator.get_node_or_null("PlayerManaRuntimeController")
	var commodity := coordinator.get_node_or_null("CommodityFlowRuntimeController")
	var world := coordinator.world_session_state()
	if queue == null or execution == null or history == null or transition == null \
			or inventory == null or public_log == null \
			or infrastructure == null or mana == null or commodity == null or world == null \
			or not infrastructure.has_method("to_save_data") \
			or not mana.has_method("to_save_data") \
			or not commodity.has_method("recent_sale_receipts_snapshot"):
		return {"valid": false, "reason_code": "duplicate_observation_owner_missing"}

	var queue_state := queue.queue_state_snapshot()
	var queue_shape_valid := queue_state.has("current_queue") \
			and queue_state.get("current_queue") is Array \
			and queue_state.has("next_queue") and queue_state.get("next_queue") is Array \
			and queue_state.has("active_entry") and queue_state.get("active_entry") is Dictionary
	var pending_resolution_ids: Array = []
	var pending_resolution_ids_typed := true
	for lane_field in ["current_queue", "next_queue"]:
		var lane: Array = queue_state.get(lane_field, []) \
				if queue_state.get(lane_field, []) is Array else []
		for entry_variant in lane:
			if entry_variant is Dictionary \
					and typeof((entry_variant as Dictionary).get("resolution_id")) == TYPE_INT:
				pending_resolution_ids.append(int((entry_variant as Dictionary).get("resolution_id")))
			else:
				pending_resolution_ids_typed = false
	var active: Dictionary = queue_state.get("active_entry", {}) \
			if queue_state.get("active_entry", {}) is Dictionary else {}
	if not active.is_empty():
		if typeof(active.get("resolution_id")) == TYPE_INT:
			pending_resolution_ids.append(int(active.get("resolution_id")))
		else:
			pending_resolution_ids_typed = false
	var execution_state := execution.to_save_data()
	var execution_shape_valid := execution_state.has("completed_resolution_ids") \
			and execution_state.get("completed_resolution_ids") is Array
	var completed_resolution_ids: Array = execution_state.get("completed_resolution_ids", []) \
			if execution_state.get("completed_resolution_ids", []) is Array else []
	var history_state := history.to_save_data()
	var history_shape_valid := history_state.has("appended_resolution_ids") \
			and history_state.get("appended_resolution_ids") is Array
	var history_resolution_ids: Array = history_state.get("appended_resolution_ids", []) \
			if history_state.get("appended_resolution_ids", []) is Array else []
	var duplicate_queue_count := _duplicate_occurrence_count(pending_resolution_ids) \
			+ _duplicate_occurrence_count(completed_resolution_ids) \
			+ _duplicate_occurrence_count(history_resolution_ids) \
			+ _intersection_occurrence_count(pending_resolution_ids, completed_resolution_ids)
	var history_debug := history.debug_snapshot()
	var transition_debug := transition.debug_snapshot()
	var inventory_debug := inventory.debug_snapshot()
	var public_log_debug := public_log.debug_snapshot()
	var duplicate_counter_shape_valid := typeof(history_debug.get("duplicate_append_count")) == TYPE_INT \
			and typeof(transition_debug.get("duplicate_count")) == TYPE_INT \
			and typeof(inventory_debug.get("queue_committed_count")) == TYPE_INT \
			and typeof(public_log_debug.get("duplicate_receipt_count")) == TYPE_INT \
			and typeof(public_log_debug.get("collision_receipt_count")) == TYPE_INT
	duplicate_queue_count += maxi(0, int(history_debug.get("duplicate_append_count", -1))) \
			+ maxi(0, int(transition_debug.get("duplicate_count", -1))) \
			+ maxi(0, int(public_log_debug.get("duplicate_receipt_count", -1))) \
			+ maxi(0, int(public_log_debug.get("collision_receipt_count", -1)))

	var infrastructure_state_variant: Variant = infrastructure.call("to_save_data")
	var infrastructure_state: Dictionary = infrastructure_state_variant \
			if infrastructure_state_variant is Dictionary else {}
	var infrastructure_shape_valid := infrastructure_state.has("facilities") \
			and infrastructure_state.get("facilities") is Array \
			and infrastructure_state.has("processed_transaction_ids") \
			and infrastructure_state.get("processed_transaction_ids") is Array \
			and infrastructure_state.has("finalized_facility_action_transaction_ids") \
			and infrastructure_state.get("finalized_facility_action_transaction_ids") is Array \
			and infrastructure_state.has("transaction_receipts") \
			and infrastructure_state.get("transaction_receipts") is Dictionary
	var facilities: Array = infrastructure_state.get("facilities", []) \
			if infrastructure_state.get("facilities", []) is Array else []
	var facility_ids: Array = []
	for facility_variant in facilities:
		if facility_variant is Dictionary:
			facility_ids.append(str((facility_variant as Dictionary).get("facility_id", "")))
	var processed_ids: Array = infrastructure_state.get("processed_transaction_ids", []) \
			if infrastructure_state.get("processed_transaction_ids", []) is Array else []
	var finalized_ids: Array = infrastructure_state.get("finalized_facility_action_transaction_ids", []) \
			if infrastructure_state.get("finalized_facility_action_transaction_ids", []) is Array else []
	var transaction_receipts: Dictionary = infrastructure_state.get("transaction_receipts", {}) \
			if infrastructure_state.get("transaction_receipts", {}) is Dictionary else {}
	var duplicate_facility_count := _duplicate_occurrence_count(facility_ids) \
			+ _duplicate_occurrence_count(processed_ids) \
			+ _duplicate_occurrence_count(finalized_ids)
	for receipt_variant in transaction_receipts.values():
		if receipt_variant is Dictionary:
			var receipt := receipt_variant as Dictionary
			duplicate_facility_count += 1 if bool(receipt.get("duplicate", false)) \
					or bool(receipt.get("replayed", false)) else 0

	var active_escrow_ids: Array = []
	var terminal_escrow_ids: Array = []
	var consumed_card_instance_ids: Array = []
	for player_variant in world.players:
		if not (player_variant is Dictionary):
			continue
		var player := player_variant as Dictionary
		var escrows: Dictionary = player.get("facility_card_escrows", {}) \
				if player.get("facility_card_escrows", {}) is Dictionary else {}
		var receipts: Dictionary = player.get("facility_card_escrow_receipts", {}) \
				if player.get("facility_card_escrow_receipts", {}) is Dictionary else {}
		active_escrow_ids.append_array(escrows.keys())
		terminal_escrow_ids.append_array(receipts.keys())
		for receipt_variant in receipts.values():
			if receipt_variant is Dictionary \
					and str((receipt_variant as Dictionary).get("state_id", "")) == "consumed_finalized":
				consumed_card_instance_ids.append(str((receipt_variant as Dictionary).get("runtime_instance_id", "")))
	var duplicate_card_count := _duplicate_occurrence_count(active_escrow_ids) \
			+ _duplicate_occurrence_count(terminal_escrow_ids) \
			+ _duplicate_occurrence_count(consumed_card_instance_ids) \
			+ _intersection_occurrence_count(active_escrow_ids, terminal_escrow_ids)

	var mana_state_variant: Variant = mana.call("to_save_data")
	var mana_state: Dictionary = mana_state_variant if mana_state_variant is Dictionary else {}
	var mana_shape_valid := mana_state.has("reservations") \
			and mana_state.get("reservations") is Dictionary \
			and mana_state.has("terminal_receipts") \
			and mana_state.get("terminal_receipts") is Dictionary
	var reservations: Dictionary = mana_state.get("reservations", {}) \
			if mana_state.get("reservations", {}) is Dictionary else {}
	var terminal_receipts: Dictionary = mana_state.get("terminal_receipts", {}) \
			if mana_state.get("terminal_receipts", {}) is Dictionary else {}
	var duplicate_cost_count := _intersection_occurrence_count(reservations.keys(), terminal_receipts.keys())
	for receipt_variant in terminal_receipts.values():
		if receipt_variant is Dictionary and bool((receipt_variant as Dictionary).get("duplicate", false)):
			duplicate_cost_count += 1

	var sale_receipts_variant: Variant = commodity.call("recent_sale_receipts_snapshot", -1)
	var sale_receipts: Array = sale_receipts_variant if sale_receipts_variant is Array else []
	var sale_shape_valid := sale_receipts_variant is Array
	var sale_receipt_ids: Array = []
	for receipt_variant in sale_receipts:
		if receipt_variant is Dictionary:
			sale_receipt_ids.append(str((receipt_variant as Dictionary).get("receipt_id", "")))
	var duplicate_sale_count := _duplicate_occurrence_count(sale_receipt_ids)
	var valid := queue_shape_valid and pending_resolution_ids_typed \
			and execution_shape_valid and history_shape_valid \
			and duplicate_counter_shape_valid \
			and infrastructure_shape_valid and mana_shape_valid and sale_shape_valid \
			and not infrastructure_state.is_empty() and not mana_state.is_empty() \
			and pending_resolution_ids.all(func(value: Variant) -> bool: return int(value) >= 0) \
			and completed_resolution_ids.all(func(value: Variant) -> bool: return typeof(value) == TYPE_INT and int(value) >= 0) \
			and history_resolution_ids.all(func(value: Variant) -> bool: return typeof(value) == TYPE_INT and int(value) >= 0) \
			and facility_ids.all(func(value: Variant) -> bool: return not str(value).is_empty()) \
			and sale_receipt_ids.all(func(value: Variant) -> bool: return not str(value).is_empty())
	return {
		"valid": valid,
		"reason_code": "authoritative_duplicate_observation_valid" if valid \
				else "authoritative_duplicate_observation_invalid",
		"duplicate_queue_entry_count": duplicate_queue_count,
		"duplicate_facility_creation_count": duplicate_facility_count,
		"duplicate_card_consumption_count": duplicate_card_count,
		"duplicate_cost_consumption_count": duplicate_cost_count,
		"duplicate_sale_receipt_count": duplicate_sale_count,
		"sale_receipt_count": sale_receipt_ids.size(),
		"sale_receipt_identity_fingerprint": SEMANTIC_WIRE.fingerprint({"receipt_ids": sale_receipt_ids}),
	}


static func _duplicate_occurrence_count(values: Array) -> int:
	var counts := {}
	var duplicates := 0
	for value_variant in values:
		var key := str(value_variant)
		counts[key] = int(counts.get(key, 0)) + 1
		if int(counts[key]) > 1:
			duplicates += 1
	return duplicates


static func _intersection_occurrence_count(left: Array, right: Array) -> int:
	var left_set := {}
	for value_variant in left:
		left_set[str(value_variant)] = true
	var count := 0
	for value_variant in right:
		if left_set.has(str(value_variant)):
			count += 1
	return count


static func _duplicate_observation_is_zero(observation: Dictionary) -> bool:
	if not bool(observation.get("valid", false)):
		return false
	for field in [
		"duplicate_queue_entry_count",
		"duplicate_facility_creation_count",
		"duplicate_card_consumption_count",
		"duplicate_cost_consumption_count",
		"duplicate_sale_receipt_count",
	]:
		if not observation.has(field) or int(observation.get(field, -1)) != 0:
			return false
	return true


func _resolution_id_occurrence(values: Array, resolution_id: int) -> int:
	var count := 0
	for value_variant in values:
		if typeof(value_variant) == TYPE_INT and int(value_variant) == resolution_id:
			count += 1
	return count


static func _queue_target_manifest_evidence(
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


static func _queue_target_role_evidence_valid(
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
			return bool(before.get("stable_target_valid", false)) \
				and bool(after.get("stable_target_valid", false)) \
				and not bool(before.get("history_privacy_redacted", true)) \
				and not bool(after.get("history_privacy_redacted", true)) \
				and str(before.get("stable_target_fingerprint", "")) == expected_stable_target_fingerprint \
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
			return bool(before.get("stable_target_valid", false)) \
				and not bool(before.get("history_privacy_redacted", true)) \
				and not bool(after.get("stable_target_valid", true)) \
				and bool(after.get("history_privacy_redacted", false)) \
				and str(before.get("stable_target_fingerprint", "")) == expected_stable_target_fingerprint \
				and str(after.get("stable_target_fingerprint", "")).is_empty() \
				and int(evidence.get("queue_target_pending_before_resume", -1)) == 1 \
				and int(evidence.get("queue_target_pending_after_resume", -1)) == 0 \
				and int(evidence.get("queue_target_completed_before_resume", -1)) == 0 \
				and int(evidence.get("queue_target_completed_after_resume", -1)) == 1 \
				and int(evidence.get("queue_target_history_before_resume", -1)) == 0 \
				and int(evidence.get("queue_target_history_after_resume", -1)) == 1 \
				and int(evidence.get("queue_target_execution_finalize_delta", -1)) == 1 \
				and int(evidence.get("queue_target_history_append_delta", -1)) == 1
		"validator":
			return not bool(before.get("stable_target_valid", true)) \
				and not bool(after.get("stable_target_valid", true)) \
				and bool(before.get("history_privacy_redacted", false)) \
				and bool(after.get("history_privacy_redacted", false)) \
				and str(before.get("stable_target_fingerprint", "")).is_empty() \
				and str(after.get("stable_target_fingerprint", "")).is_empty() \
				and int(evidence.get("queue_target_pending_before_resume", -1)) == 0 \
				and int(evidence.get("queue_target_pending_after_resume", -1)) == 0 \
				and int(evidence.get("queue_target_completed_before_resume", -1)) == 1 \
				and int(evidence.get("queue_target_completed_after_resume", -1)) == 1 \
				and int(evidence.get("queue_target_history_before_resume", -1)) == 1 \
				and int(evidence.get("queue_target_history_after_resume", -1)) == 1 \
				and int(evidence.get("queue_target_execution_finalize_delta", -1)) == 0 \
				and int(evidence.get("queue_target_history_append_delta", -1)) == 0
	return false


static func _queue_target_post_continuation_quiet_valid(
	before: Dictionary,
	after: Dictionary
) -> bool:
	if not bool(before.get("valid", false)) or not bool(after.get("valid", false)) \
			or int(before.get("resolution_id", -1)) <= 0 \
			or int(after.get("resolution_id", -2)) != int(before.get("resolution_id", -1)):
		return false
	for field in [
		"pending_count",
		"completed_count",
		"history_count",
		"history_lineage_count",
		"history_duplicate_count",
		"transition_duplicate_count",
		"public_log_duplicate_count",
		"public_log_collision_count",
	]:
		if not before.has(field) or not after.has(field) \
				or typeof(before.get(field)) != TYPE_INT \
				or typeof(after.get(field)) != TYPE_INT \
				or int(after.get(field)) != int(before.get(field)):
			return false
	return int(after.get("pending_count", -1)) == 0 \
			and int(after.get("completed_count", -1)) == 1 \
			and int(after.get("history_count", -1)) == 1 \
			and int(after.get("history_lineage_count", -1)) == 1 \
			and bool(after.get("history_privacy_redacted", false)) \
			and not bool(after.get("stable_target_valid", true)) \
			and str(after.get("stable_target_fingerprint", "")).is_empty()


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
	var ai := coordinator.get_node_or_null("AiRuntimeController") if coordinator != null else null
	var state: Dictionary = ai.call("debug_snapshot") \
			if ai != null and ai.has_method("debug_snapshot") else {}
	return Marshalls.raw_to_base64(var_to_bytes(state)).sha256_text() if not state.is_empty() else ""


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


func _generation_two_no_continuation_evidence(context: Dictionary) -> Dictionary:
	var sale_binding_capture := TERMINAL_EVIDENCE.capture_public_sale_binding(context)
	if not bool(sale_binding_capture.get("accepted", false)):
		return {
			"accepted": false,
			"reason_code": str(sale_binding_capture.get(
				"reason_code",
				"generation_two_public_sale_binding_capture_failed"
			)),
		}
	var gated_context := context.duplicate()
	gated_context["generation_two_sale_binding"] = (
		sale_binding_capture.get("binding", {}) as Dictionary
	).duplicate(true)
	var before := _safety_observation(context)
	var lease := TERMINAL_EVIDENCE.acquire_manual_lease(gated_context)
	if not bool(lease.get("accepted", false)):
		return {
			"accepted": false,
			"reason_code": str(lease.get("reason_code", "generation_two_manual_lease_rejected")),
		}
	var lease_frame := int(lease.get("frame_index", -1))
	var idle_gate: Dictionary = {}
	var settle_limit := int(TERMINAL_EVIDENCE.contract_snapshot().get(
		"generation_two_lifecycle_settle_frame_limit",
		0
	))
	for settle_index in range(settle_limit + 1):
		idle_gate = TERMINAL_EVIDENCE.generation_two_idle_gate(gated_context, lease_frame)
		if bool(idle_gate.get("accepted", false)) \
				or str(idle_gate.get("reason_code", "")) \
				!= "generation_two_lifecycle_checkpoint_pending":
			break
		if settle_index < settle_limit:
			await process_frame
	var after := _safety_observation(context)
	var release := TERMINAL_EVIDENCE.release_manual_lease(gated_context)
	var quiet := not before.is_empty() and not after.is_empty()
	for field in PROCESS_A_SAVE_QUIET_FIELDS:
		var field_valid := before.has(field) and after.has(field) \
				and typeof(before.get(field)) == TYPE_INT and typeof(after.get(field)) == TYPE_INT
		quiet = quiet and field_valid and int(after.get(field)) == int(before.get(field))
	var accepted := bool(idle_gate.get("accepted", false)) \
			and bool(release.get("released", false)) and quiet
	return {
		"accepted": accepted,
		"reason_code": "generation_two_no_continuation_attested" if accepted else (
			str(idle_gate.get("reason_code", "generation_two_idle_gate_rejected")) \
			if not bool(idle_gate.get("accepted", false)) else (
				"generation_two_no_continuation_quiet_failed" if not quiet \
				else str(release.get("reason_code", "generation_two_manual_lease_release_failed"))
			)
		),
		"victory_state_sequence": [],
		"settlement_count": 0,
		"presentation_count": 0,
		"public_log_count": 0,
		"terminal_quiescent_frames": 0,
		"terminal_world_delta": 0,
		"terminal_rng_draw_delta": 0,
	}


func _card_inventory_capture_probe(context: Dictionary) -> Dictionary:
	var coordinator := context.get("coordinator") as GameRuntimeCoordinator
	if coordinator == null:
		return {"captured": false, "reason_code": "coordinator_missing"}
	var owner := coordinator.get_node_or_null("CardInventorySaveOwner") as CardInventorySaveOwner
	var inventory := coordinator.commodity_card_inventory_runtime_controller()
	var state_port := coordinator.card_player_state_production_adapter_v06()
	var district_purchase := coordinator.get_node_or_null("DistrictPurchaseRuntimeController") \
		as DistrictPurchaseRuntimeController
	if owner == null or inventory == null or state_port == null or district_purchase == null:
		return {
			"captured": false,
			"reason_code": "card_inventory_probe_dependency_missing",
			"owner_present": owner != null,
			"inventory_present": inventory != null,
			"state_port_present": state_port != null,
			"district_purchase_present": district_purchase != null,
		}
	var capture := owner.capture_composite_state()
	return {
		"captured": bool(capture.get("captured", false)),
		"reason_code": str(capture.get("reason_code", "card_inventory_capture_unknown")),
		"owner": owner.debug_snapshot(),
		"commodity_checkpoint": inventory.checkpoint_status(),
		"state_port_checkpoint": state_port.checkpoint_status(),
		"district_purchase": _district_purchase_capture_probe(district_purchase),
	}


func _district_purchase_capture_probe(controller: DistrictPurchaseRuntimeController) -> Dictionary:
	var checkpoint := controller.capture_runtime_checkpoint()
	var windows: Dictionary = checkpoint.get("windows_by_player", {}) \
		if checkpoint.get("windows_by_player", {}) is Dictionary else {}
	var player_indices: Array = windows.keys()
	player_indices.sort()
	var sessions: Array = []
	var rows: Array = []
	for player_index_variant in player_indices:
		var player_index := int(player_index_variant)
		var snapshot := controller.to_legacy_save_snapshot(player_index)
		var single_preflight := controller.preflight_save_data({
			"district_purchase_runtime": {
				"schema_version": 2,
				"sessions": [snapshot.duplicate(true)] if not snapshot.is_empty() else [],
			},
		})
		if not snapshot.is_empty():
			sessions.append(snapshot.duplicate(true))
		rows.append({
			"player_index": player_index,
			"window": (windows.get(player_index_variant, {}) as Dictionary).duplicate(true) \
				if windows.get(player_index_variant, {}) is Dictionary else {},
			"snapshot": snapshot.duplicate(true),
			"snapshot_present": not snapshot.is_empty(),
			"preflight_accepted": bool(single_preflight.get("accepted", false)),
			"preflight_reason_code": str(single_preflight.get("reason_code", "")),
		})
	var combined_preflight := controller.preflight_save_data({
		"district_purchase_runtime": {
			"schema_version": 2,
			"sessions": sessions.duplicate(true),
		},
	})
	return {
		"debug": controller.debug_snapshot(),
		"window_count": windows.size(),
		"session_count": sessions.size(),
		"rows": rows,
		"combined_preflight_accepted": bool(combined_preflight.get("accepted", false)),
		"combined_preflight_reason_code": str(combined_preflight.get("reason_code", "")),
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


static func _delta(before: Dictionary, after: Dictionary, field: String) -> int:
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
	if _targeted_owner_capture_diagnostic and not _targeted_diagnostic_written \
			and not _targeted_diagnostic_options.is_empty():
		var diagnostic_rows: Array = _targeted_diagnostic_timeline.get("phase_rows", []) \
				if _targeted_diagnostic_timeline.get("phase_rows", []) is Array else []
		var owner_audit_started := false
		for row_variant in diagnostic_rows:
			if row_variant is Dictionary \
					and str((row_variant as Dictionary).get("phase_id", "")) == "owner_audit_started":
				owner_audit_started = true
				break
		if not owner_audit_started and _targeted_diagnostic_pre_owner_failure.is_empty():
			_targeted_diagnostic_pre_owner_failure = _diagnostic_pre_owner_failure(
				"harness",
				"diagnostic_pre_owner_%s" % _safe_reason_code(reason_code),
				"owner_audit_started",
				_safe_reason_code(reason_code)
			)
		base["failure_code"] = _safe_reason_code(reason_code)
		var diagnostic_write := _write_targeted_owner_capture_diagnostic(_targeted_diagnostic_options, base)
		if bool(diagnostic_write.get("valid", false)):
			_targeted_diagnostic_written = true
			base["_targeted_owner_capture_diagnostic_sha256"] = str(diagnostic_write.get("sha256", ""))
		else:
			reason_code = "targeted_owner_capture_evidence_write_failed"
	base["slot_state"] = "failed"
	base["success"] = false
	base["failure_code"] = _safe_reason_code(reason_code)
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
		"timeout_policy_fingerprint": "",
		"non_official_process_a": false,
		"targeted_owner_capture_diagnostic": false,
		"process_a_rehearsal": false,
		"targeted_diagnostic_ledger_path": "",
		"targeted_diagnostic_ledger_fingerprint": "",
		"rehearsal_ledger_path": "",
		"rehearsal_ledger_fingerprint": "",
		"parse_error": "",
	}
	var seen: Dictionary = {}
	for argument in args:
		var text := str(argument)
		if text in ["--cold-restore-contract-only", "--cold-restore-qualification-probe"]:
			continue
		if text == "--cold-restore-non-official-process-a":
			if seen.has("non_official_process_a"):
				result["parse_error"] = "duplicate_option"
			else:
				seen["non_official_process_a"] = true
				result["non_official_process_a"] = true
			continue
		if text == "--cold-restore-targeted-owner-capture-diagnostic":
			if seen.has("targeted_owner_capture_diagnostic"):
				result["parse_error"] = "duplicate_option"
			else:
				seen["targeted_owner_capture_diagnostic"] = true
				result["targeted_owner_capture_diagnostic"] = true
			continue
		if text == "--cold-restore-process-a-rehearsal":
			if seen.has("process_a_rehearsal"):
				result["parse_error"] = "duplicate_option"
			else:
				seen["process_a_rehearsal"] = true
				result["process_a_rehearsal"] = true
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
		elif text.begins_with("--cold-restore-timeout-policy-fingerprint="):
			option_key = "timeout_policy_fingerprint"
			option_value = text.trim_prefix("--cold-restore-timeout-policy-fingerprint=")
		elif text.begins_with("--cold-restore-targeted-diagnostic-ledger-path="):
			option_key = "targeted_diagnostic_ledger_path"
			option_value = text.trim_prefix("--cold-restore-targeted-diagnostic-ledger-path=")
		elif text.begins_with("--cold-restore-targeted-diagnostic-ledger-fingerprint="):
			option_key = "targeted_diagnostic_ledger_fingerprint"
			option_value = text.trim_prefix("--cold-restore-targeted-diagnostic-ledger-fingerprint=")
		elif text.begins_with("--cold-restore-rehearsal-ledger-path="):
			option_key = "rehearsal_ledger_path"
			option_value = text.trim_prefix("--cold-restore-rehearsal-ledger-path=")
		elif text.begins_with("--cold-restore-rehearsal-ledger-fingerprint="):
			option_key = "rehearsal_ledger_fingerprint"
			option_value = text.trim_prefix("--cold-restore-rehearsal-ledger-fingerprint=")
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
