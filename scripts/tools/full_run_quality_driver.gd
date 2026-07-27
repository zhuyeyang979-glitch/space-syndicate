extends SceneTree

const FullRunQualitySnapshotScript := preload("res://scripts/viewmodels/full_run_quality_snapshot.gd")
const AuthoritativeRuntimeStepperScript := preload("res://scripts/tools/full_run_authoritative_runtime_stepper.gd")

const DRIVER_SCHEMA := 3
const DRIVER_ID := "full_run_quality_driver_v2"
const SEED_ALGORITHM := "space-syndicate-full-run-quality-v1:sha256-positive31"
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const COORDINATOR_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator"
const RUNTIME_LOOP_PATH := "RuntimeLoop"
const MONSTER_WAGER_RESPONSE_SINK_PATH := "MonsterWagerResponseSink"
const SETUP_DRAFT_PATH := "RuntimeServices/NewGameSetupDraftService"
const SESSION_START_TRANSACTION_PATH := "RuntimeServices/SessionStartTransactionCoordinator"
const SESSION_PATH := "GameSessionRuntimeController"
const REGISTRY_PATH := "V06SaveOwnerRegistry"
const SAVE_COORDINATOR_PATH := "GameSaveRuntimeCoordinator"
const SETTLEMENT_PATH := "RuntimeServices/FinalSettlementRuntimeComposition"
const STANDINGS_QUERY_PATH := "RuntimeServices/StandingsPublicQueryPort"
const RUNTIME_SCREEN_PATH := "RuntimeGameScreen"
const QA_SAVE_ROOT := "user://test_runs/full_run_quality/"
const REQUIRED_SECTION_COUNT := 19
const SCRIPTED_PLAYER_INDEX := 0
const RECOMMENDED_PLAYER_COUNT := 4
const RECOMMENDED_AI_COUNT := 3
const TARGET_PRODUCTION_INSTALLATION_COUNT := 3
const HEARTBEAT_INTERVAL_SECONDS := 2.0
const TELEMETRY_REFRESH_INTERVAL_MSEC := 100
const ACTION_PROGRESS_TIMEOUT_SECONDS := 3.0
const NO_ACTION_TIMEOUT_SECONDS := 1.5
const DEFAULT_OBSERVATION_SECONDS := 12
const DEFAULT_MAX_WALL_SECONDS := 30
const OBSERVATION_ACTION_OPEN := &"open"
const OBSERVATION_ACTION_DRAIN := &"drain"
const OBSERVATION_ACTION_CLOSED := &"closed"
# Keep every authoritative frame at human-scale time. The driver probes typed
# actions after every complete RuntimeLoop step so a newly opened decision never
# inherits extra world, AI, market, or RNG advancement from a hidden batch.
const ACTION_ENGINE_TIME_SCALE := 1.0
const AUTHORITATIVE_WAIT_STEP_SECONDS := 1.0
const AUTHORITATIVE_WAIT_STEPS_PER_RENDER_FRAME := 1
const AUTHORITATIVE_WAIT_TOTAL_STEP_LIMIT := 360
const BLOCKED_REALTIME_TOTAL_STEP_LIMIT := 360
const TIMER_TRACE_SAMPLE_LIMIT := 512
const TIMER_DELTA_TOLERANCE_US := 8
const TERMINAL_QUIESCENCE_FRAME_COUNT := 8
const SUPPLY_QUOTE_REFRESH_INTERVAL_MSEC := 250
const SUPPLY_QUOTE_REFRESH_ATTEMPTS_PER_RACK := 1
const SUPPLY_RACK_ROTATION_LIMIT := 8
const SUPPLY_RESCAN_WORLD_SECONDS := 15.0
const EXIT_INVALID_ARGUMENTS := 2
const EXIT_CAPABILITY_INCOMPLETE := 3
const EXIT_OBSERVATION_INCOMPLETE := 4
const EXIT_RUNTIME_COMPOSITION_UNAVAILABLE := 5
const EXIT_NONFINITE := 6
const VICTORY_STATE_IDS := ["idle", "qualification", "audit", "cooldown", "resolved"]
const TYPED_RACK_ACTION_IDS := [
	"rack",
	"buy",
	"district_open_rack",
	"primary_open_development_rack",
	"primary_open_rack",
	"primary_review_rack",
	"strategy_build_gdp_source",
]
const FACILITY_TARGET_RETRY_REASON_IDS := [
	"public_facility_target_unavailable",
	"public_facility_slot_occupied",
	"public_facility_slot_incompatible",
	"public_facility_product_unavailable",
]

const FIXED_SEEDS: Array[int] = [
	900626424,
	865984508,
	1419123495,
	1471257297,
	2038431333,
	948459684,
	1635321996,
	1280235321,
	899123644,
	43885519,
	950436207,
	102090361,
	124449428,
	545676743,
	1471036570,
	1968730869,
	1969748911,
	853285161,
	1765914414,
	1515999483,
]

const SUMMARY_PUBLIC_KEYS := [
	"type",
	"schema",
	"driver",
	"algorithm",
	"run_id",
	"run_count",
	"seed_index",
	"seed",
	"completed",
	"status",
	"failure_code",
	"qa_save_scope",
	"capability",
	"save",
	"actions",
	"milestones",
	"performance",
	"determinism",
	"phase",
	"elapsed",
	"progress",
	"decision_window",
	"settlement",
	"invalid_actions",
	"nonfinite",
	"last_event",
	"wall_ms",
]
const CAPABILITY_PUBLIC_KEYS := [
	"fresh_run_ready",
	"scripted_ui_port_ready",
	"clock_ready",
	"victory_ready",
	"session_ready",
	"settlement_ready",
	"registry_valid",
	"required_sections",
	"transactional_sections",
	"unsupported_sections",
	"resume_ready",
	"capture_fail_closed",
	"district_supply_query_ready",
	"facility_target_query_ready",
	"table_selection_receipt_ready",
	"standings_query_ready",
	"public_sale_receipt_query_ready",
	"authoritative_runtime_step_ready",
	"monster_wager_receipt_ready",
]

var _started_msec := 0
var _heartbeat_sequence := 0
var _last_event := "driver_started"
var _last_progress_feedback := ""
var _district_supply_receipt_sequence := 0
var _last_district_supply_receipt: Dictionary = {}
var _table_selection_receipt_sequence := 0
var _last_table_selection_receipt: Dictionary = {}
var _monster_wager_receipt_sequence := 0
var _last_monster_wager_receipt: Dictionary = {}
var _current_forced_decision_binding: Dictionary = {}
var _runtime_simulation_timing: Dictionary = {}
var _district_supply_query_port: DistrictSupplyViewerQueryPort
var _table_presentation_query_ports: TablePresentationQueryPorts
var _telemetry_collect_count := 0
var _action_projection_count := 0
var _district_supply_query_count := 0
var _standings_progress_query_count := 0
var _economic_source_query_count := 0
var _rng_checkpoints: Dictionary = {}
var _victory_state_sequence: Array[String] = []
var _victory_timer_trace: Array[Dictionary] = []
var _victory_timer_trace_overflow := false
var _authoritative_observation_sequence := 0
var _first_sale_observation: Dictionary = {}
var _authorized_timer_contract: Dictionary = {}
var _authorized_timer_contract_error := "timer_contract_unavailable"
var _authorized_timer_contract_rejected := false
var _terminal_quiescence := {
	"verified": false,
	"frame_count": 0,
	"fingerprint": "",
	"reason_id": "not_observed",
	"rng_verified": false,
	"rng_draw_delta": -1,
}
var _authoritative_step_batch_count := 0
var _authoritative_step_attempt_count := 0
var _authoritative_step_active_count := 0
var _authoritative_step_world_seconds := 0.0
var _authoritative_step_wall_msec_total := 0
var _authoritative_step_wall_msec_max := 0
var _authoritative_slowest_step_path := ""
var _authoritative_slowest_step_reason := ""
var _blocked_realtime_step_batch_count := 0
var _blocked_realtime_step_attempt_count := 0
var _blocked_realtime_step_count := 0
var _blocked_realtime_seconds := 0.0
var _blocked_realtime_precondition_end_count := 0
var _blocked_realtime_invariant_failure_count := 0
var _blocked_realtime_wall_msec_total := 0
var _blocked_realtime_wall_msec_max := 0
var _runtime_loop_manual_mode := false
var _runtime_loop_manual_mode_transition_count := 0
var _runtime_loop_manual_expected_frame_index := -1
var _exhausted_map_districts := {}
var _exhausted_facility_card_signatures := {}
var _facility_candidate_attempts := {}
var _peak_production_installation_count := 0
var _session_started_msec := 0
var _milestones := {
	"clock": "wall_seconds_from_session_start",
	"time_to_first_rack": -1.0,
	"time_to_first_quote": -1.0,
	"time_to_first_purchase": -1.0,
}
var _action_stats := {
	"attempted": 0,
	"progressed": 0,
	"rejected_invalid": 0,
	"supply_quote_refreshes": 0,
	"supply_rack_rotations": 0,
	"reason_codes": {},
}


func _init() -> void:
	_started_msec = Time.get_ticks_msec()
	call_deferred("_run")


func _run() -> void:
	var options := parse_command_line_options(OS.get_cmdline_user_args(), OS.get_cmdline_args())
	if not bool(options.get("valid", false)):
		var invalid_telemetry := _empty_telemetry(int(options.get("seed_index", 0)), "blocked", "invalid_arguments")
		_emit_summary(_summary(options, invalid_telemetry, "invalid_arguments", "invalid_arguments", {}, {}))
		quit(EXIT_INVALID_ARGUMENTS)
		return

	var seed_index := int(options.get("seed_index", 0))
	var run_seed := FIXED_SEEDS[seed_index]
	var qa_scope := qa_save_directory(_head_token(), run_seed)
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		var missing_scene := _empty_telemetry(seed_index, "blocked", "main_scene_unavailable")
		_emit_summary(_summary(options, missing_scene, "blocked_by_capability", "runtime_composition_unavailable", {}, {}))
		quit(EXIT_RUNTIME_COMPOSITION_UNAVAILABLE)
		return
	var main_instance := packed.instantiate()
	if main_instance == null:
		var missing_instance := _empty_telemetry(seed_index, "blocked", "main_instance_unavailable")
		_emit_summary(_summary(options, missing_instance, "blocked_by_capability", "runtime_composition_unavailable", {}, {}))
		quit(EXIT_RUNTIME_COMPOSITION_UNAVAILABLE)
		return
	if main_instance is CanvasItem:
		(main_instance as CanvasItem).visible = false

	var coordinator := main_instance.get_node_or_null(COORDINATOR_PATH)
	var session := coordinator.get_node_or_null(SESSION_PATH) if coordinator != null else null
	var save_coordinator := session.get_node_or_null(SAVE_COORDINATOR_PATH) if session != null else null
	var qa_save_file := "%srun.save" % qa_scope
	var qa_path_ready := save_coordinator != null \
		and save_coordinator.has_method("set_qa_default_save_path_override") \
		and bool(save_coordinator.call("set_qa_default_save_path_override", qa_save_file))
	root.add_child(main_instance)
	await _wait_frames(6)

	coordinator = main_instance.get_node_or_null(COORDINATOR_PATH)
	session = coordinator.get_node_or_null(SESSION_PATH) if coordinator != null else null
	var runtime_loop := coordinator.get_node_or_null(RUNTIME_LOOP_PATH) as RuntimeLoop if coordinator != null else null
	var district_supply_port := (coordinator as GameRuntimeCoordinator).district_supply_action_port() if coordinator is GameRuntimeCoordinator else null
	var table_selection_port := coordinator.get_node_or_null("TableSelectionIntentPort") as TableSelectionIntentPort \
		if coordinator != null else null
	_district_supply_query_port = coordinator.get_node_or_null("DistrictSupplyViewerQueryPort") as DistrictSupplyViewerQueryPort \
		if coordinator != null else null
	_table_presentation_query_ports = (coordinator as GameRuntimeCoordinator).table_presentation_query_ports() \
		if coordinator is GameRuntimeCoordinator else null
	if district_supply_port != null and not district_supply_port.receipt_ready.is_connected(_on_district_supply_action_receipt):
		district_supply_port.receipt_ready.connect(_on_district_supply_action_receipt)
	if table_selection_port != null and not table_selection_port.receipt_ready.is_connected(_on_table_selection_receipt):
		table_selection_port.receipt_ready.connect(_on_table_selection_receipt)
	var monster_wager_response_sink := coordinator.get_node_or_null(MONSTER_WAGER_RESPONSE_SINK_PATH) as MonsterWagerResponseSink \
		if coordinator != null else null
	if monster_wager_response_sink != null \
			and not monster_wager_response_sink.receipt_ready.is_connected(_on_monster_wager_response_receipt):
		monster_wager_response_sink.receipt_ready.connect(_on_monster_wager_response_receipt)
	var registry := session.get_node_or_null(REGISTRY_PATH) if session != null else null
	var runtime_screen := main_instance.get_node_or_null(RUNTIME_SCREEN_PATH)
	var settlement_composition := main_instance.get_node_or_null(SETTLEMENT_PATH)
	var standings_query_port := main_instance.get_node_or_null(STANDINGS_QUERY_PATH) as StandingsPublicQueryPort
	var capability := _capability_preflight(main_instance, coordinator, session, registry, runtime_screen, settlement_composition, standings_query_port, qa_path_ready)
	var public_capability: Dictionary = capability.get("public", {}) if capability.get("public", {}) is Dictionary else {}
	var preflight_telemetry := _collect_telemetry(
		run_seed,
		coordinator,
		session,
		settlement_composition,
		standings_query_port,
		runtime_screen,
		_started_msec,
		"capability_preflight"
	)
	_emit_heartbeat(seed_index, preflight_telemetry, "ready" if bool(capability.get("fresh_run_ready", false)) else "blocked_by_capability")

	if not bool(capability.get("fresh_run_ready", false)):
		_cleanup_main(main_instance, save_coordinator)
		_emit_summary(_summary(options, preflight_telemetry, "blocked_by_capability", "fresh_run_capability_incomplete", public_capability, _save_status(public_capability)))
		quit(EXIT_CAPABILITY_INCOMPLETE)
		return
	if bool(options.get("preflight_only", false)):
		_cleanup_main(main_instance, save_coordinator)
		_emit_summary(_summary(options, preflight_telemetry, "fresh_run_preflight_ready", "", public_capability, _save_status(public_capability)))
		quit(0)
		return

	var start_result := await _start_fixed_seed_run(main_instance, session, run_seed)
	if not bool(start_result.get("started", false)):
		_action_stats["rejected_invalid"] = int(_action_stats.get("rejected_invalid", 0)) + 1
		_record_reason(str(start_result.get("reason_code", "session_start_failed")))
		_last_event = "blocked:%s" % str(start_result.get("reason_code", "session_start_failed"))
		var start_failed := _collect_telemetry(run_seed, coordinator, session, settlement_composition, standings_query_port, runtime_screen, _started_msec, _last_event)
		_cleanup_main(main_instance, save_coordinator)
		_emit_summary(_summary(options, start_failed, "blocked_by_capability", str(start_result.get("reason_code", "session_start_failed")), public_capability, _save_status(public_capability)))
		quit(EXIT_CAPABILITY_INCOMPLETE)
		return

	_last_event = "session_started"
	_session_started_msec = Time.get_ticks_msec()
	_record_rng_checkpoint("setup", coordinator)
	var observation_started_msec := Time.get_ticks_msec()
	var observation_limit_msec := int(options.get("observation_seconds", DEFAULT_OBSERVATION_SECONDS)) * 1000
	var max_wall_msec := int(options.get("max_wall_seconds", DEFAULT_MAX_WALL_SECONDS)) * 1000
	var last_heartbeat_msec := observation_started_msec
	var last_telemetry_refresh_msec := observation_started_msec
	var no_action_since_msec := observation_started_msec
	var pending_action: Dictionary = {}
	var exhausted_navigation_actions: Dictionary = {}
	var supply_rotation_state := _new_supply_rotation_state()
	var observed_owned_facility_count := 0
	var last_supply_quote_refresh_msec := 0
	var final_status := "incomplete"
	var failure_code := "observation_window_elapsed_before_settlement"
	var final_telemetry := _collect_telemetry(run_seed, coordinator, session, settlement_composition, standings_query_port, runtime_screen, observation_started_msec, _last_event)
	var cached_ui_action := _scripted_ui_action(
		runtime_screen,
		exhausted_navigation_actions,
		final_telemetry.get("progress", {}) as Dictionary,
		supply_rotation_state,
		final_telemetry.get("sale_receipt", {}) as Dictionary
	)

	while true:
		await process_frame
		var now_msec := Time.get_ticks_msec()
		var public_progress: Dictionary = final_telemetry.get("progress", {}) if final_telemetry.get("progress", {}) is Dictionary else {}
		var sale_receipt: Dictionary = final_telemetry.get("sale_receipt", {}) if final_telemetry.get("sale_receipt", {}) is Dictionary else {}
		var ui_action := cached_ui_action
		if _session_state(session) == "running":
			Engine.time_scale = ACTION_ENGINE_TIME_SCALE
		if now_msec - last_telemetry_refresh_msec >= TELEMETRY_REFRESH_INTERVAL_MSEC:
			final_telemetry = _collect_telemetry(run_seed, coordinator, session, settlement_composition, standings_query_port, runtime_screen, observation_started_msec, _last_event, cached_ui_action)
			last_telemetry_refresh_msec = now_msec
			public_progress = final_telemetry.get("progress", {}) as Dictionary
			sale_receipt = final_telemetry.get("sale_receipt", {}) as Dictionary
			cached_ui_action = _scripted_ui_action(runtime_screen, exhausted_navigation_actions, public_progress, supply_rotation_state, sale_receipt)
			ui_action = cached_ui_action
		var current_progress: Dictionary = final_telemetry.get("progress", {}) \
			if final_telemetry.get("progress", {}) is Dictionary else {}
		var current_facility_count := int(current_progress.get("owned_facility_count", 0))
		if current_facility_count > observed_owned_facility_count:
			observed_owned_facility_count = current_facility_count
			_exhausted_map_districts.clear()
			_exhausted_facility_card_signatures.clear()
			_facility_candidate_attempts.clear()
			supply_rotation_state = _new_supply_rotation_state()
			public_progress = current_progress
			ui_action = _scripted_ui_action(runtime_screen, exhausted_navigation_actions, public_progress, supply_rotation_state, sale_receipt)
			cached_ui_action = ui_action
			_last_event = "facility_progress_observed:%d" % current_facility_count
		elif str(supply_rotation_state.get("phase", "")) == "exhausted" and pending_action.is_empty():
			var current_world_seconds := float((final_telemetry.get("elapsed", {}) as Dictionary).get("world_seconds", 0.0)) \
				if final_telemetry.get("elapsed", {}) is Dictionary else 0.0
			var exhausted_world_seconds := float(supply_rotation_state.get("exhausted_world_seconds", -1.0))
			if exhausted_world_seconds < 0.0:
				supply_rotation_state["exhausted_world_seconds"] = current_world_seconds
			elif current_world_seconds - exhausted_world_seconds >= SUPPLY_RESCAN_WORLD_SECONDS:
				supply_rotation_state = _new_supply_rotation_state()
				public_progress = current_progress
				ui_action = _scripted_ui_action(runtime_screen, exhausted_navigation_actions, public_progress, supply_rotation_state, sale_receipt)
				cached_ui_action = ui_action
				_last_event = "supply_public_rescan_started"
		if int((final_telemetry.get("nonfinite", {}) as Dictionary).get("count", 0)) > 0:
			final_status = "failed"
			failure_code = "nonfinite_public_runtime_fact"
			_last_event = "blocked:nonfinite_public_runtime_fact"
			break
		if bool((final_telemetry.get("settlement", {}) as Dictionary).get("completed", false)):
			_leave_runtime_loop_manual_mode(runtime_loop)
			_record_rng_checkpoint("terminal", coordinator)
			var quiescence := await _verify_terminal_quiescence(
				final_telemetry,
				coordinator,
				runtime_loop,
				session,
				settlement_composition,
				standings_query_port,
				runtime_screen,
				observation_started_msec
			)
			final_telemetry = quiescence.get("telemetry", final_telemetry) as Dictionary
			if bool(quiescence.get("verified", false)) and _victory_transition_sequence_complete():
				final_status = "settled"
				failure_code = ""
				_last_event = "settlement_completed_and_quiescent"
			else:
				final_status = "failed"
				failure_code = str(quiescence.get("reason_id", "terminal_quiescence_failed")) \
					if not bool(quiescence.get("verified", false)) else "victory_transition_sequence_incomplete"
				_last_event = "blocked:%s" % failure_code
			break
		var settlement_observation: Dictionary = final_telemetry.get("settlement", {}) \
			if final_telemetry.get("settlement", {}) is Dictionary else {}
		if terminal_presentation_drain_policy(pending_action, settlement_observation):
			_leave_runtime_loop_manual_mode(runtime_loop)
			if now_msec - _started_msec >= max_wall_msec:
				final_status = "failed"
				failure_code = "terminal_presentation_drain_timeout"
				_last_event = "blocked:%s" % failure_code
				break
			_last_event = "waiting:terminal_presentation_commit"
			continue

		var decision_window: Dictionary = final_telemetry.get("decision_window", {}) \
			if final_telemetry.get("decision_window", {}) is Dictionary else {}
		var blocked_realtime_wait_requested := blocked_realtime_wait_policy(
			pending_action,
			_current_forced_decision_binding,
			_last_monster_wager_receipt,
			_session_state(session)
		) and now_msec - _started_msec < max_wall_msec
		if blocked_realtime_wait_requested:
			Engine.time_scale = ACTION_ENGINE_TIME_SCALE
			if not _enter_runtime_loop_manual_mode(runtime_loop):
				final_status = "blocked"
				failure_code = "blocked_realtime_manual_mode_unavailable"
				_last_event = "blocked:%s" % failure_code
				break
			var remaining_blocked_steps := BLOCKED_REALTIME_TOTAL_STEP_LIMIT - _blocked_realtime_step_attempt_count
			if remaining_blocked_steps <= 0:
				final_status = "blocked"
				failure_code = "blocked_realtime_step_budget_exhausted"
				_last_event = "blocked:%s" % failure_code
				break
			var blocked_world_before := _capture_world_clock_checkpoint(coordinator)
			var blocked_rng_before := _capture_rng_checkpoint(coordinator)
			var blocked_step_started_msec := Time.get_ticks_msec()
			var blocked_step_result: Dictionary = AuthoritativeRuntimeStepperScript.advance_blocked_realtime_bounded(
				runtime_loop,
				AUTHORITATIVE_WAIT_STEP_SECONDS,
				mini(AUTHORITATIVE_WAIT_STEPS_PER_RENDER_FRAME, remaining_blocked_steps)
			)
			var blocked_step_wall_msec := maxi(0, Time.get_ticks_msec() - blocked_step_started_msec)
			_blocked_realtime_wall_msec_total += blocked_step_wall_msec
			_blocked_realtime_wall_msec_max = maxi(_blocked_realtime_wall_msec_max, blocked_step_wall_msec)
			if _runtime_loop_manual_expected_frame_index >= 0 \
					and int(blocked_step_result.get("frame_index_before", -1)) != _runtime_loop_manual_expected_frame_index:
				blocked_step_result["accepted"] = false
				blocked_step_result["reason_id"] = "runtime_manual_lease_frame_discontinuity"
			_runtime_loop_manual_expected_frame_index = int(blocked_step_result.get("frame_index_after", -1))
			var blocked_world_after := _capture_world_clock_checkpoint(coordinator)
			var blocked_rng_after := _capture_rng_checkpoint(coordinator)
			var blocked_evidence := blocked_realtime_step_evidence(
				blocked_step_result,
				blocked_world_before,
				blocked_world_after,
				blocked_rng_before,
				blocked_rng_after
			)
			_blocked_realtime_step_batch_count += 1
			_blocked_realtime_step_attempt_count += int(blocked_step_result.get("attempted_steps", 0))
			_blocked_realtime_step_count += int(blocked_step_result.get("blocked_realtime_steps", 0))
			_blocked_realtime_seconds += float(blocked_step_result.get("blocked_realtime_seconds", 0.0))
			_blocked_realtime_precondition_end_count += 1 \
				if bool(blocked_step_result.get("blocked_realtime_precondition_ended", false)) else 0
			_record_authoritative_timeline_from_public_snapshot(coordinator)
			last_telemetry_refresh_msec = 0
			_last_event = "blocked_realtime_wait:%s" % str(blocked_evidence.get("reason_id", "unknown"))
			if not bool(blocked_evidence.get("verified", false)):
				_blocked_realtime_invariant_failure_count += 1
				final_status = "blocked"
				failure_code = "blocked_realtime_step_rejected:%s" % str(blocked_evidence.get("reason_id", "unknown"))
				_last_event = "blocked:%s" % failure_code
				break
			continue

		var manual_wait_requested := authoritative_manual_wait_policy(
			pending_action,
			_session_state(session),
			decision_window,
			ui_action,
			supply_rotation_state
		) and now_msec - _started_msec < max_wall_msec
		if manual_wait_requested:
			Engine.time_scale = ACTION_ENGINE_TIME_SCALE
			if not _enter_runtime_loop_manual_mode(runtime_loop):
				final_status = "blocked"
				failure_code = "authoritative_runtime_manual_mode_unavailable"
				_last_event = "blocked:%s" % failure_code
				break
			var remaining_steps := AUTHORITATIVE_WAIT_TOTAL_STEP_LIMIT - _authoritative_step_attempt_count
			if remaining_steps <= 0:
				final_status = "blocked"
				failure_code = "authoritative_runtime_step_budget_exhausted"
				_last_event = "blocked:%s" % failure_code
				break
			var step_started_msec := Time.get_ticks_msec()
			var step_result: Dictionary = AuthoritativeRuntimeStepperScript.advance_bounded(
				runtime_loop,
				AUTHORITATIVE_WAIT_STEP_SECONDS,
				mini(AUTHORITATIVE_WAIT_STEPS_PER_RENDER_FRAME, remaining_steps)
			)
			var step_wall_msec := maxi(0, Time.get_ticks_msec() - step_started_msec)
			_authoritative_step_wall_msec_total += step_wall_msec
			if step_wall_msec > _authoritative_step_wall_msec_max:
				_authoritative_step_wall_msec_max = step_wall_msec
				_authoritative_slowest_step_path = str(step_result.get("last_path", ""))
				_authoritative_slowest_step_reason = str(step_result.get("last_stopped_reason", ""))
			if _runtime_loop_manual_expected_frame_index >= 0 \
					and int(step_result.get("frame_index_before", -1)) != _runtime_loop_manual_expected_frame_index:
				step_result["accepted"] = false
				step_result["reason_id"] = "runtime_manual_lease_frame_discontinuity"
			_runtime_loop_manual_expected_frame_index = int(step_result.get("frame_index_after", -1))
			_authoritative_step_batch_count += 1
			_authoritative_step_attempt_count += int(step_result.get("attempted_steps", 0))
			_authoritative_step_active_count += int(step_result.get("active_steps", 0))
			_authoritative_step_world_seconds += float(step_result.get("world_seconds", 0.0))
			_record_authoritative_timeline_from_public_snapshot(coordinator)
			last_telemetry_refresh_msec = 0
			_last_event = "authoritative_runtime_wait:%s" % str(step_result.get("reason_id", "unknown"))
			if not bool(step_result.get("accepted", false)):
				final_status = "blocked"
				failure_code = "authoritative_runtime_step_rejected:%s" % str(step_result.get("reason_id", "unknown"))
				_last_event = "blocked:%s" % failure_code
				break
			continue
		_leave_runtime_loop_manual_mode(runtime_loop)

		if not pending_action.is_empty():
			var pending_id := str(pending_action.get("id", ""))
			var pending_phase := str(pending_action.get("phase", ""))
			var supply_receipt_arrived := str(pending_action.get("origin", "")) in ["district_supply", "district_supply_rotation"] \
				and _district_supply_receipt_sequence > int(pending_action.get("supply_receipt_sequence", -1))
			var selection_receipt_arrived := str(pending_action.get("origin", "")) == "planet_map" \
				and _table_selection_receipt_sequence > int(pending_action.get("selection_receipt_sequence", -1))
			if supply_receipt_arrived and not bool(_last_district_supply_receipt.get("accepted", false)):
				var receipt_reason := str(_last_district_supply_receipt.get("reason_code", "district_supply_rejected"))
				if str(pending_action.get("origin", "")) == "district_supply_rotation" \
						and pending_id == "district_supply_rotation_open" \
						and receipt_reason in ["purchase_window_unavailable", "district_unavailable"] \
						and _advance_supply_rotation_after_unavailable_open(
							runtime_screen,
							supply_rotation_state,
							int(pending_action.get("district_index", -1))
						):
					_record_reason("district_supply_rotation_unavailable")
					_action_stats["supply_rack_rotations"] = int(_action_stats.get("supply_rack_rotations", 0)) + 1
					_last_event = "rotation_skipped_unavailable_district:%d:%s" % [
						int(pending_action.get("district_index", -1)),
						receipt_reason,
					]
					pending_action = {}
					no_action_since_msec = now_msec
					continue
				if recoverable_supply_receipt_reason(receipt_reason):
					_record_reason("district_supply_retryable_receipt")
					_last_event = "retrying_typed_receipt:%s" % receipt_reason
					if receipt_reason in ["source_region_dark", "card_not_in_supply"] \
							and _begin_supply_rack_rotation(supply_rotation_state, _public_supply_wait_facts(runtime_screen)):
						_action_stats["supply_rack_rotations"] = int(_action_stats.get("supply_rack_rotations", 0)) + 1
					pending_action = {}
					no_action_since_msec = now_msec
					continue
				_action_stats["rejected_invalid"] = int(_action_stats.get("rejected_invalid", 0)) + 1
				failure_code = "scripted_ui_action_rejected:%s:%s" % [pending_id, receipt_reason]
				_record_reason("scripted_ui_action_rejected")
				_last_event = "blocked_typed_receipt:%s" % receipt_reason
				final_status = "blocked"
				break
			if selection_receipt_arrived and not bool(_last_table_selection_receipt.get("accepted", false)):
				var exhausted_district := int(pending_action.get("district_index", -1))
				if exhausted_district >= 0:
					_exhausted_map_districts[exhausted_district] = true
				_record_reason("map_selection_typed_rejection")
				_last_event = "map_target_rejected:%d:%s" % [
					exhausted_district,
					str(_last_table_selection_receipt.get("reason_code", "selection_rejected")),
				]
				pending_action = {}
				last_telemetry_refresh_msec = 0
				no_action_since_msec = now_msec
				continue
			var supply_receipt_progressed := supply_receipt_confirms_progress(
				pending_action,
				_district_supply_receipt_sequence,
				_last_district_supply_receipt
			)
			var selection_receipt_progressed := selection_receipt_confirms_progress(
				pending_action,
				_table_selection_receipt_sequence,
				_last_table_selection_receipt
			)
			var action_progressed := supply_receipt_progressed \
				or selection_receipt_progressed \
				or str(ui_action.get("id", "")) != pending_id \
				or str(ui_action.get("phase", "")) != pending_phase
			if action_progressed:
				_action_stats["progressed"] = int(_action_stats.get("progressed", 0)) + 1
				if str(pending_action.get("origin", "")) == "board_primary" and pending_id != "strategy_expand_gdp":
					var progressed_signature := str(pending_action.get("signature", ""))
					if not progressed_signature.is_empty():
						exhausted_navigation_actions[progressed_signature] = true
				var feedback := _runtime_action_feedback(runtime_screen)
				_last_progress_feedback = "%s:%s:%s" % [pending_id, str(feedback.get("state", "none")), str(feedback.get("detail", "")).left(96)]
				_last_event = "action_progressed:%s" % _last_progress_feedback
				pending_action = {}
				if supply_receipt_progressed or selection_receipt_progressed:
					last_telemetry_refresh_msec = 0
				no_action_since_msec = now_msec
			elif now_msec - int(pending_action.get("requested_msec", now_msec)) >= int(ACTION_PROGRESS_TIMEOUT_SECONDS * 1000.0):
				if str(pending_action.get("origin", "")) == "board_primary":
					var navigation_signature := str(pending_action.get("signature", ""))
					if not navigation_signature.is_empty():
						exhausted_navigation_actions[navigation_signature] = true
					_record_reason("navigation_no_state_change")
					_last_event = "navigation_exhausted:%s" % pending_id
					pending_action = {}
					no_action_since_msec = now_msec
					continue
				if str(pending_action.get("origin", "")) == "planet_map":
					var exhausted_district := int(pending_action.get("district_index", -1))
					if exhausted_district >= 0:
						_exhausted_map_districts[exhausted_district] = true
					_record_reason("map_selection_no_state_change")
					_last_event = "map_target_exhausted:%d" % exhausted_district
					pending_action = {}
					no_action_since_msec = now_msec
					continue
				_action_stats["rejected_invalid"] = int(_action_stats.get("rejected_invalid", 0)) + 1
				failure_code = "scripted_ui_action_no_progress:%s" % pending_id
				_record_reason("scripted_ui_action_no_progress")
				var failure_feedback := _runtime_action_feedback(runtime_screen)
				_last_progress_feedback = "%s:%s:%s" % [
					pending_id,
					str(failure_feedback.get("state", "none")),
					str(failure_feedback.get("detail", "")).left(96),
				]
				_last_event = "blocked_feedback:%s:%s" % [
					str(failure_feedback.get("state", "none")),
					str(failure_feedback.get("detail", "")).left(96),
				]
				final_status = "blocked"
				break

		var observation_policy := observation_action_policy(
			observation_started_msec,
			observation_limit_msec,
			now_msec,
			pending_action
		)
		if observation_policy == OBSERVATION_ACTION_CLOSED:
			var lifecycle_settlement: Dictionary = final_telemetry.get("settlement", {}) \
				if final_telemetry.get("settlement", {}) is Dictionary else {}
			if terminal_lifecycle_drain_policy(
				pending_action,
				lifecycle_settlement,
				now_msec - _started_msec,
				max_wall_msec
			):
				_last_event = "waiting:terminal_lifecycle_drain"
				continue
			failure_code = "observation_window_elapsed_before_settlement"
			_last_event = "blocked:%s" % failure_code
			break

		if pending_action.is_empty() and observation_policy == OBSERVATION_ACTION_OPEN:
			var action_id := str(ui_action.get("id", ""))
			if _apply_driver_planning_transition(ui_action):
				public_progress = current_progress
				cached_ui_action = _scripted_ui_action(
					runtime_screen,
					exhausted_navigation_actions,
					public_progress,
					supply_rotation_state,
					sale_receipt
				)
				_last_event = "driver_planning_transition:%s" % action_id
				continue
			if not action_id.is_empty() and not bool(ui_action.get("disabled", false)):
				var supply_receipt_sequence_before_submission := _district_supply_receipt_sequence
				var selection_receipt_sequence_before_submission := _table_selection_receipt_sequence
				var wager_receipt_sequence_before_submission := _monster_wager_receipt_sequence
				var forced_decision_binding_before_submission := _current_forced_decision_binding.duplicate(true)
				if not _submit_scripted_ui_action(runtime_screen, ui_action):
					_action_stats["attempted"] = int(_action_stats.get("attempted", 0)) + 1
					_action_stats["rejected_invalid"] = int(_action_stats.get("rejected_invalid", 0)) + 1
					failure_code = "scripted_ui_action_submission_rejected:%s" % action_id
					_record_reason("scripted_ui_action_submission_rejected")
					_last_event = "blocked:%s" % failure_code
					final_status = "blocked"
					break
				_action_stats["attempted"] = int(_action_stats.get("attempted", 0)) + 1
				_last_event = "action_requested:%s:after:%s" % [action_id, _last_progress_feedback]
				pending_action = {
					"id": action_id,
					"phase": str(ui_action.get("phase", "play")),
					"origin": str(ui_action.get("origin", "")),
					"signature": str(ui_action.get("signature", "")),
					"requested_msec": now_msec,
					"supply_receipt_sequence": supply_receipt_sequence_before_submission,
					"selection_receipt_sequence": selection_receipt_sequence_before_submission,
					"wager_receipt_sequence": wager_receipt_sequence_before_submission,
					"decision_id": str(forced_decision_binding_before_submission.get("decision_id", "")),
					"decision_kind": str(forced_decision_binding_before_submission.get("decision_kind", "")),
					"decision_revision": int(forced_decision_binding_before_submission.get("decision_revision", 0)),
					"district_index": int(ui_action.get("district_index", -1)),
				}
				no_action_since_msec = now_msec
			elif action_id in ["district_supply_wait", "facility_play_wait", "gdp_accumulation_wait"] and bool(ui_action.get("disabled", false)):
				if action_id == "district_supply_wait" and now_msec - last_supply_quote_refresh_msec >= SUPPLY_QUOTE_REFRESH_INTERVAL_MSEC:
					var wait_facts := _public_supply_wait_facts(runtime_screen)
					var rack_signature := str(wait_facts.get("rack_signature", ""))
					var attempts_by_signature: Dictionary = supply_rotation_state.get("refresh_attempts_by_signature", {}) \
						if supply_rotation_state.get("refresh_attempts_by_signature", {}) is Dictionary else {}
					var attempts := int(attempts_by_signature.get(rack_signature, 0))
					var exhausted_signatures: Dictionary = supply_rotation_state.get("exhausted_signatures", {}) \
						if supply_rotation_state.get("exhausted_signatures", {}) is Dictionary else {}
					if not rack_signature.is_empty() and (not bool(wait_facts.get("has_visible_production_facility", false)) \
							or bool(exhausted_signatures.get(rack_signature, false)) \
							or attempts >= SUPPLY_QUOTE_REFRESH_ATTEMPTS_PER_RACK):
						exhausted_signatures[rack_signature] = true
						supply_rotation_state["exhausted_signatures"] = exhausted_signatures
						if _begin_supply_rack_rotation(supply_rotation_state, wait_facts):
							_action_stats["supply_rack_rotations"] = int(_action_stats.get("supply_rack_rotations", 0)) + 1
							_last_event = "supply_rack_rotation_started:%d" % int(supply_rotation_state.get("target_district", -1))
					elif _refresh_visible_supply_quote(runtime_screen):
						_action_stats["supply_quote_refreshes"] = int(_action_stats.get("supply_quote_refreshes", 0)) + 1
						if not rack_signature.is_empty():
							attempts_by_signature[rack_signature] = attempts + 1
							supply_rotation_state["refresh_attempts_by_signature"] = attempts_by_signature
					elif not rack_signature.is_empty():
						exhausted_signatures[rack_signature] = true
						supply_rotation_state["exhausted_signatures"] = exhausted_signatures
						if _begin_supply_rack_rotation(supply_rotation_state, wait_facts):
							_action_stats["supply_rack_rotations"] = int(_action_stats.get("supply_rack_rotations", 0)) + 1
					last_supply_quote_refresh_msec = now_msec
				_last_event = ("waiting:district_supply_facility_visibility" if str(ui_action.get("phase", "")).contains("facility_not_visible") else "waiting:district_supply_quote_availability") \
					if action_id == "district_supply_wait" else ("waiting:facility_play_eligibility" if action_id == "facility_play_wait" else "waiting:gdp_accumulation_and_victory_qualification")
				no_action_since_msec = now_msec
			elif now_msec - no_action_since_msec >= int(NO_ACTION_TIMEOUT_SECONDS * 1000.0):
				var exact_phase := str(final_telemetry.get("phase", "play"))
				var decision: Dictionary = final_telemetry.get("decision_window", {}) if final_telemetry.get("decision_window", {}) is Dictionary else {}
				if not action_id.is_empty() and bool(ui_action.get("disabled", false)):
					failure_code = "scripted_ui_action_disabled:%s" % action_id
					_record_reason("scripted_ui_action_disabled")
				elif bool(decision.get("active", false)) and bool(decision.get("blocks_global_time", false)):
					failure_code = "forced_decision_has_no_visible_action"
				elif exact_phase == "play" or exact_phase == "finished":
					failure_code = "scripted_guidance_exhausted_before_settlement"
				else:
					failure_code = "scripted_ui_action_unavailable:%s" % exact_phase
				_last_event = "blocked:%s" % failure_code
				final_status = "blocked"
				break

		if now_msec - last_heartbeat_msec >= int(HEARTBEAT_INTERVAL_SECONDS * 1000.0):
			_emit_heartbeat(seed_index, final_telemetry, "running")
			last_heartbeat_msec = now_msec
		if now_msec - _started_msec >= max_wall_msec:
			failure_code = "driver_wall_timeout"
			_last_event = "blocked:driver_wall_timeout"
			break

	_leave_runtime_loop_manual_mode(runtime_loop)
	final_telemetry = _collect_telemetry(run_seed, coordinator, session, settlement_composition, standings_query_port, runtime_screen, observation_started_msec, _last_event, cached_ui_action)
	_emit_heartbeat(seed_index, final_telemetry, final_status)
	_cleanup_main(main_instance, save_coordinator)
	_emit_summary(_summary(options, final_telemetry, final_status, failure_code, public_capability, _save_status(public_capability)))
	if final_status == "settled":
		quit(0)
	elif failure_code == "nonfinite_public_runtime_fact":
		quit(EXIT_NONFINITE)
	else:
		quit(EXIT_OBSERVATION_INCOMPLETE)


static func authoritative_manual_wait_policy(
	pending_action: Dictionary,
	session_state: String,
	decision_window: Dictionary,
	ui_action: Dictionary,
	supply_rotation_state: Dictionary
) -> bool:
	if not pending_action.is_empty() \
			or session_state != "running" \
			or bool(decision_window.get("active", false)) \
			or not bool(ui_action.get("disabled", false)):
		return false
	var action_id := str(ui_action.get("id", ""))
	if action_id == "gdp_accumulation_wait":
		return true
	return action_id == "district_supply_wait" \
		and str(supply_rotation_state.get("phase", "")) == "exhausted"


static func terminal_presentation_drain_policy(
	pending_action: Dictionary,
	settlement: Dictionary
) -> bool:
	return pending_action.is_empty() \
		and str(settlement.get("state", "")) == "resolved" \
		and not bool(settlement.get("completed", false))


static func terminal_lifecycle_drain_policy(
	pending_action: Dictionary,
	settlement: Dictionary,
	elapsed_wall_msec: int,
	max_wall_msec: int
) -> bool:
	return pending_action.is_empty() \
		and str(settlement.get("state", "")) in ["qualification", "audit"] \
		and elapsed_wall_msec < max_wall_msec


func _start_fixed_seed_run(main_instance: Node, session: Node, run_seed: int) -> Dictionary:
	var draft := main_instance.get_node_or_null(SETUP_DRAFT_PATH) as NewGameSetupDraftService
	var transaction := main_instance.get_node_or_null(SESSION_START_TRANSACTION_PATH) as SessionStartTransactionCoordinator
	if draft == null or transaction == null or not (session is GameSessionRuntimeController):
		return {"started": false, "reason_code": "session_start_transaction_unavailable"}
	draft.reset_to_defaults()
	var runtime_coordinator := main_instance.get_node_or_null(COORDINATOR_PATH) as GameRuntimeCoordinator
	var runtime_rng := runtime_coordinator.run_rng_service() if runtime_coordinator != null else null
	if runtime_rng == null:
		return {"started": false, "reason_code": "run_rng_service_unavailable"}
	runtime_rng.seed = run_seed
	var request := SessionStartRequest.create(
		"full-run:%d" % run_seed,
		draft.draft_snapshot(),
		(session as GameSessionRuntimeController).session_start_revision(),
		"quality_driver"
	)
	var receipt := transaction.start_session(request)
	if receipt == null or not receipt.applied:
		return {"started": false, "reason_code": receipt.reason_code if receipt != null else "session_start_receipt_missing"}
	await _wait_frames(10)
	var session_summary := (session as GameSessionRuntimeController).session_summary()
	var setup: Dictionary = session_summary.get("setup", {}) if session_summary.get("setup", {}) is Dictionary else {}
	var player_count := int(setup.get("player_count", 0))
	var ai_player_count := int(setup.get("ai_player_count", 0))
	var session_state := str(session_summary.get("session_state", "unavailable"))
	var started := player_count == RECOMMENDED_PLAYER_COUNT and ai_player_count == RECOMMENDED_AI_COUNT and session_state == "running"
	return {
		"started": started,
		"reason_code": "" if started else "normal_session_not_running",
	}


func _capability_preflight(main_instance: Node, coordinator: Node, session: Node, registry: Node, runtime_screen: Node, settlement_composition: Node, standings_query_port: StandingsPublicQueryPort, qa_path_ready: bool) -> Dictionary:
	var registry_snapshot: Dictionary = {}
	var capture_probe: Dictionary = {}
	if registry != null and registry.has_method("registry_snapshot"):
		var registry_variant: Variant = registry.call("registry_snapshot")
		if registry_variant is Dictionary:
			registry_snapshot = (registry_variant as Dictionary).duplicate(true)
	if registry != null and registry.has_method("capture_resume_envelope"):
		var capture_variant: Variant = registry.call("capture_resume_envelope", {
			"envelope_id": "full-run-capability-probe",
			"write_id": "full-run-capability-probe",
		})
		if capture_variant is Dictionary:
			capture_probe = capture_variant as Dictionary
	var clock_ready := coordinator != null and coordinator.has_method("world_effective_clock_snapshot")
	var victory_ready := coordinator != null and coordinator.has_method("victory_control_public_snapshot")
	var session_ready := session != null and session.has_method("session_summary")
	var settlement_ready := settlement_composition != null and settlement_composition.has_method("debug_snapshot") and settlement_composition.has_method("last_public_snapshot")
	var scripted_ui_port_ready := runtime_screen is SpaceSyndicateGameScreen \
		and runtime_screen.has_signal("action_requested") \
		and runtime_screen.has_method("request_district_selection") \
		and runtime_screen.has_method("request_district_supply_open") \
		and runtime_screen.has_method("request_district_supply_close") \
		and runtime_screen.has_method("request_selected_district_supply_purchase") \
		and _temporary_decision_overlay(runtime_screen) != null
	var setup_ready := main_instance.get_node_or_null(SETUP_DRAFT_PATH) is NewGameSetupDraftService \
		and main_instance.get_node_or_null(SESSION_START_TRANSACTION_PATH) is SessionStartTransactionCoordinator
	var district_supply_query_ready := _district_supply_query_port != null \
		and _district_supply_query_port.has_method("snapshot_for_viewer")
	var facility_target_query_ready := _table_presentation_query_ports != null \
		and _table_presentation_query_ports.has_method("public_new_facility_target_candidates")
	var table_selection_receipt_ready := coordinator != null \
		and coordinator.get_node_or_null("TableSelectionIntentPort") is TableSelectionIntentPort
	var standings_query_ready := standings_query_port != null \
		and standings_query_port.has_method("snapshot_for_authorized_viewer") \
		and standings_query_port.has_method("victory_progress_for_authorized_viewer")
	var public_sale_receipt_query_ready := coordinator != null \
		and coordinator.has_method("presentation_recent_public_log_entries")
	var monster_wager_response_sink := coordinator.get_node_or_null(MONSTER_WAGER_RESPONSE_SINK_PATH) as MonsterWagerResponseSink \
		if coordinator != null else null
	var monster_wager_receipt_ready := monster_wager_response_sink != null \
		and monster_wager_response_sink.has_signal("receipt_ready") \
		and monster_wager_response_sink.receipt_ready.is_connected(_on_monster_wager_response_receipt)
	var runtime_loop := coordinator.get_node_or_null(RUNTIME_LOOP_PATH) as RuntimeLoop if coordinator != null else null
	var runtime_loop_debug := runtime_loop.debug_snapshot() if runtime_loop != null else {}
	var runtime_loop_count := 0
	if coordinator != null:
		for child in coordinator.get_children():
			if child is RuntimeLoop:
				runtime_loop_count += 1
	var authoritative_runtime_step_ready := runtime_loop != null \
		and runtime_loop.has_method("advance_frame_for_test") \
		and runtime_loop.get_parent() == coordinator \
		and runtime_loop.is_inside_tree() \
		and runtime_loop_count == 1 \
		and bool(runtime_loop_debug.get("frame_owner", false))
	var registry_valid := bool(registry_snapshot.get("valid", false)) and qa_path_ready
	var required_sections := int(registry_snapshot.get("required_section_count", 0))
	var transactional_sections := int(registry_snapshot.get("transactional_section_count", 0))
	var unsupported_sections := int(registry_snapshot.get("unsupported_section_count", REQUIRED_SECTION_COUNT))
	var resume_ready := bool(registry_snapshot.get("resume_ready", false))
	var capture_fail_closed := not bool(capture_probe.get("ok", true)) \
		and str(capture_probe.get("reason_code", "")) == "restore_capability_incomplete" \
		and not capture_probe.has("envelope")
	var fresh_run_ready := registry_valid \
		and required_sections == REQUIRED_SECTION_COUNT \
		and clock_ready \
		and victory_ready \
		and session_ready \
		and settlement_ready \
		and scripted_ui_port_ready \
		and district_supply_query_ready \
		and facility_target_query_ready \
		and table_selection_receipt_ready \
		and standings_query_ready \
		and public_sale_receipt_query_ready \
		and monster_wager_receipt_ready \
		and authoritative_runtime_step_ready \
		and setup_ready
	return {
		"fresh_run_ready": fresh_run_ready,
		"public": {
			"fresh_run_ready": fresh_run_ready,
			"scripted_ui_port_ready": scripted_ui_port_ready,
			"clock_ready": clock_ready,
			"victory_ready": victory_ready,
			"session_ready": session_ready,
			"settlement_ready": settlement_ready,
			"registry_valid": registry_valid,
			"required_sections": maxi(0, required_sections),
			"transactional_sections": maxi(0, transactional_sections),
			"unsupported_sections": maxi(0, unsupported_sections),
			"resume_ready": resume_ready,
			"capture_fail_closed": capture_fail_closed,
			"district_supply_query_ready": district_supply_query_ready,
			"facility_target_query_ready": facility_target_query_ready,
			"table_selection_receipt_ready": table_selection_receipt_ready,
			"standings_query_ready": standings_query_ready,
			"public_sale_receipt_query_ready": public_sale_receipt_query_ready,
			"monster_wager_receipt_ready": monster_wager_receipt_ready,
			"authoritative_runtime_step_ready": authoritative_runtime_step_ready,
		},
	}


func _collect_telemetry(run_seed: int, coordinator: Node, session: Node, settlement_composition: Node, standings_query_port: StandingsPublicQueryPort, runtime_screen: Node, run_started_msec: int, last_event: String, ui_action_override: Variant = null) -> Dictionary:
	_telemetry_collect_count += 1
	_record_runtime_simulation_timing(coordinator)
	var clock: Dictionary = {}
	var victory: Dictionary = {}
	var decision: Dictionary = {}
	var standings_progress: Dictionary = {}
	var economic_source: Dictionary = {}
	if coordinator != null and coordinator.has_method("world_effective_clock_snapshot"):
		var clock_variant: Variant = coordinator.call("world_effective_clock_snapshot")
		clock = (clock_variant as Dictionary).duplicate(true) if clock_variant is Dictionary else {}
	var sale_receipt := _public_sale_receipt_observation(coordinator)
	if bool(sale_receipt.get("observed", false)) and not _rng_checkpoints.has("first_sale_receipt"):
		_record_rng_checkpoint("first_sale_receipt", coordinator)
	if coordinator != null and coordinator.has_method("victory_control_public_snapshot"):
		var victory_variant: Variant = coordinator.call("victory_control_public_snapshot", -1)
		victory = (victory_variant as Dictionary).duplicate(true) if victory_variant is Dictionary else {}
		_record_authoritative_timeline_observation(victory, clock, sale_receipt)
	if coordinator != null and coordinator.has_method("active_forced_decision"):
		var decision_variant: Variant = coordinator.call("active_forced_decision", SCRIPTED_PLAYER_INDEX)
		decision = (decision_variant as Dictionary).duplicate(true) if decision_variant is Dictionary else {}
	_current_forced_decision_binding = _forced_decision_binding(decision)
	if standings_query_port != null and standings_query_port.has_method("victory_progress_for_authorized_viewer"):
		_standings_progress_query_count += 1
		var standings_variant: Variant = standings_query_port.call("victory_progress_for_authorized_viewer")
		var progress_candidate: Dictionary = (standings_variant as Dictionary).duplicate(true) \
			if standings_variant is Dictionary else {}
		if bool(progress_candidate.get("valid", false)):
			standings_progress = progress_candidate
			_record_authorized_timer_contract(progress_candidate)
	if coordinator != null and coordinator.has_method("actor_id_for_player_index") and coordinator.has_method("economic_source_snapshot"):
		var actor_binding_variant: Variant = coordinator.call("actor_id_for_player_index", SCRIPTED_PLAYER_INDEX)
		var actor_binding: Dictionary = actor_binding_variant if actor_binding_variant is Dictionary else {}
		if bool(actor_binding.get("available", false)):
			_economic_source_query_count += 1
			var source_variant: Variant = coordinator.call("economic_source_snapshot", str(actor_binding.get("actor_id", "")))
			economic_source = source_variant if source_variant is Dictionary else {}
	var public_progress := {
		"controlled_region_count": int(standings_progress.get("selected_controlled_region_count", 0)),
		"required_region_count": int(standings_progress.get("required_controlled_region_count", 0)),
		"top_k_gdp_per_minute": int(standings_progress.get("selected_top_k_gdp_per_minute", 0)),
		"required_top_k_gdp_per_minute": int(standings_progress.get("required_top_k_gdp_per_minute", 0)),
		"owned_facility_count": int(economic_source.get("owned_facility_count", 0)),
		"production_installation_count": int(economic_source.get("production_installation_count", 0)),
		"eligible": bool(standings_progress.get("eligible", false)),
	}
	_peak_production_installation_count = maxi(
		_peak_production_installation_count,
		int(public_progress.get("production_installation_count", 0))
	)
	public_progress["peak_production_installation_count"] = _peak_production_installation_count
	var ui_action: Dictionary = (ui_action_override as Dictionary) if ui_action_override is Dictionary \
		else _scripted_ui_action(runtime_screen, {}, public_progress, {}, sale_receipt)
	var session_summary := _session_summary(session)
	var session_state := str(session_summary.get("session_state", "unavailable"))
	var outcome: Dictionary = victory.get("outcome_receipt", {}) if victory.get("outcome_receipt", {}) is Dictionary else {}
	var final_settlement_log := _public_final_settlement_log_observation(coordinator, str(outcome.get("outcome_id", "")))
	var settlement := _settlement_snapshot(victory, settlement_composition, session_summary, final_settlement_log, sale_receipt)
	var phase := _phase_for(session_state, victory, decision, ui_action, settlement)
	var world_seconds := maxf(0.0, float(clock.get("world_effective_seconds", 0.0)))
	return FullRunQualitySnapshotScript.compose({
		"seed": run_seed,
		"phase": phase,
		"elapsed": {
			"wall_seconds": maxf(0.0, float(Time.get_ticks_msec() - run_started_msec) / 1000.0),
			"world_seconds": world_seconds,
		},
		"progress": public_progress,
		"sale_receipt": sale_receipt,
		"decision_window": {
			"active": not decision.is_empty(),
			"kind": str(decision.get("kind", "none")),
			"priority_group": str(decision.get("priority_group", "")),
			"blocks_global_time": bool(decision.get("blocks_global_time", false)),
			"blocks_player_actions": bool(decision.get("blocks_player_actions", false)),
			"visible_to_scripted_player": bool(decision.get("visible_to_viewer", true)),
		},
		"settlement": settlement,
		"invalid_actions": {
			"count": int(_action_stats.get("rejected_invalid", 0)),
			"last_reason_code": _last_reason_code(),
		},
		"nonfinite": {},
		"last_event": last_event,
		"observed_public_facts": {
			"clock": {"world_effective_seconds": world_seconds},
			"victory": {
				"qualification_remaining_seconds": float(victory.get("qualification_remaining_seconds", 0.0)),
				"audit_remaining_seconds": float(victory.get("audit_remaining_seconds", 0.0)),
				"qualification_duration_seconds": float(standings_progress.get("qualification_duration_seconds", 0.0)),
				"audit_duration_seconds": float(standings_progress.get("audit_duration_seconds", 0.0)),
			},
			"progress": {
				"controlled_region_count": float(public_progress.get("controlled_region_count", 0)),
				"top_k_gdp_per_minute": float(public_progress.get("top_k_gdp_per_minute", 0)),
			},
			"sale_receipt": {
				"public_event_count": float(sale_receipt.get("public_event_count", 0)),
				"latest_source_revision": float(sale_receipt.get("latest_source_revision", 0)),
			},
			"decision": {"opened_sequence": float(decision.get("opened_sequence", 0.0))},
		},
	})


func _settlement_snapshot(
	victory: Dictionary,
	settlement_composition: Node,
	session_summary: Dictionary,
	final_settlement_log: Dictionary = {},
	sale_receipt: Dictionary = {}
) -> Dictionary:
	var outcome: Dictionary = victory.get("outcome_receipt", {}) if victory.get("outcome_receipt", {}) is Dictionary else {}
	var session_outcome: Dictionary = session_summary.get("outcome_receipt", {}) \
		if session_summary.get("outcome_receipt", {}) is Dictionary else {}
	var outcome_identity := outcome_identity_evidence(outcome, session_outcome)
	var timer_evidence := timer_traversal_evidence(
		_victory_timer_trace,
		_first_sale_observation,
		_authorized_timer_contract,
		_authorized_timer_contract_error,
		_victory_timer_trace_overflow
	)
	var debug: Dictionary = {}
	var public_snapshot: Dictionary = {}
	if settlement_composition != null and settlement_composition.has_method("debug_snapshot"):
		var debug_variant: Variant = settlement_composition.call("debug_snapshot")
		debug = (debug_variant as Dictionary).duplicate(true) if debug_variant is Dictionary else {}
	if settlement_composition != null and settlement_composition.has_method("last_public_snapshot"):
		var public_variant: Variant = settlement_composition.call("last_public_snapshot")
		public_snapshot = (public_variant as Dictionary).duplicate(true) if public_variant is Dictionary else {}
	var outcome_id := str(outcome.get("outcome_id", ""))
	var present_count := int(debug.get("present_count", 0))
	var presented_outcome_count := int(debug.get("presented_outcome_count", 0))
	var logged_outcome_count := int(debug.get("logged_outcome_count", 0))
	var last_presented_outcome_id := str(debug.get("last_presented_outcome_id", ""))
	var public_snapshot_fingerprint := str(debug.get("last_public_snapshot_fingerprint", ""))
	var winner_count := (outcome.get("winner_player_indices", []) as Array).size() if outcome.get("winner_player_indices", []) is Array else 0
	var reason_code := str(outcome.get("reason_code", ""))
	var final_log_ready := int(final_settlement_log.get("public_entry_count", 0)) == 1 \
		and str(final_settlement_log.get("outcome_id", "")) == outcome_id \
		and str(final_settlement_log.get("public_fingerprint", "")).length() == 64
	var presentation_ready := not outcome_id.is_empty() \
		and present_count == 1 \
		and presented_outcome_count == 1 \
		and logged_outcome_count == 1 \
		and last_presented_outcome_id == outcome_id \
		and public_snapshot_fingerprint.length() == 64 \
		and not public_snapshot.is_empty() \
		and bool(outcome_identity.get("verified", false)) \
		and final_log_ready
	var timer_ready := bool(timer_evidence.get("verified", false)) \
		and bool(timer_evidence.get("sale_before_qualification", false)) \
		and bool(sale_receipt.get("observed", false))
	var session_state := str(session_summary.get("session_state", "unavailable"))
	return {
		"state": str(victory.get("state", "idle")),
		"completed": str(victory.get("state", "")) == "resolved" \
			and not outcome_id.is_empty() \
			and reason_code == "public_audit_complete" \
			and winner_count > 0 \
			and session_state == "finished" \
			and presentation_ready \
			and timer_ready,
		"outcome_id": outcome_id,
		"session_outcome_id": str(outcome_identity.get("session_outcome_id", "")),
		"outcome_identity_matches": bool(outcome_identity.get("verified", false)),
		"public_outcome_identity_fingerprint": str(outcome_identity.get("public_fingerprint", "")),
		"session_outcome_identity_fingerprint": str(outcome_identity.get("session_fingerprint", "")),
		"reason_code": reason_code,
		"winner_count": winner_count,
		"presentation_ready": presentation_ready,
		"present_count": present_count,
		"presented_outcome_count": presented_outcome_count,
		"logged_outcome_count": logged_outcome_count,
		"last_presented_outcome_id": last_presented_outcome_id,
		"public_snapshot_fingerprint": public_snapshot_fingerprint,
		"state_sequence": _victory_state_sequence.duplicate(),
		"transition_sequence_complete": _victory_transition_sequence_complete(),
		"quiescence_verified": bool(_terminal_quiescence.get("verified", false)),
		"quiescence_frame_count": int(_terminal_quiescence.get("frame_count", 0)),
		"quiescence_fingerprint": str(_terminal_quiescence.get("fingerprint", "")),
		"quiescence_reason_id": str(_terminal_quiescence.get("reason_id", "not_observed")),
		"rng_quiescence_verified": bool(_terminal_quiescence.get("rng_verified", false)),
		"rng_draw_delta": int(_terminal_quiescence.get("rng_draw_delta", -1)),
		"public_log_entry_count": int(final_settlement_log.get("public_entry_count", 0)),
		"public_log_fingerprint": str(final_settlement_log.get("public_fingerprint", "")),
		"timer_evidence": timer_evidence,
	}


func _public_sale_receipt_observation(coordinator: Node) -> Dictionary:
	var rows: Array = []
	if coordinator != null and coordinator.has_method("presentation_recent_public_log_entries"):
		var entries_variant: Variant = coordinator.call("presentation_recent_public_log_entries", 90)
		var entries: Array = entries_variant if entries_variant is Array else []
		for entry_variant in entries:
			if not (entry_variant is Dictionary):
				continue
			var entry := entry_variant as Dictionary
			if str(entry.get("event_kind", "")) != CommodityFlowPostCommitPublicReceipt.EVENT_KIND:
				continue
			var public_values: Dictionary = entry.get("public_values", {}) if entry.get("public_values", {}) is Dictionary else {}
			if str(public_values.get("result", "")) != "committed" \
					or str(public_values.get("public_status", "")) != "sale_receipt":
				continue
			rows.append({
				"source_revision": maxi(0, int(entry.get("source_revision", 0))),
				"world_time": maxf(0.0, float(entry.get("world_time", 0.0))),
				"value_band": str(public_values.get("value_band", "")),
			})
	var first_world_seconds := 0.0
	var latest_source_revision := 0
	if not rows.is_empty():
		first_world_seconds = float((rows[0] as Dictionary).get("world_time", 0.0))
		for row_variant in rows:
			var row := row_variant as Dictionary
			first_world_seconds = minf(first_world_seconds, float(row.get("world_time", first_world_seconds)))
			latest_source_revision = maxi(latest_source_revision, int(row.get("source_revision", 0)))
	return {
		"observed": not rows.is_empty(),
		"public_event_count": rows.size(),
		"first_world_seconds": first_world_seconds,
		"latest_source_revision": latest_source_revision,
		"public_fingerprint": JSON.stringify(rows).sha256_text() if not rows.is_empty() else "",
	}


func _public_final_settlement_log_observation(coordinator: Node, expected_outcome_id := "") -> Dictionary:
	var rows: Array[Dictionary] = []
	if coordinator != null and coordinator.has_method("presentation_recent_public_log_entries"):
		var entries_variant: Variant = coordinator.call("presentation_recent_public_log_entries", 90)
		var entries: Array = entries_variant if entries_variant is Array else []
		for entry_variant in entries:
			if not (entry_variant is Dictionary):
				continue
			var entry := entry_variant as Dictionary
			var public_values: Dictionary = entry.get("public_values", {}) if entry.get("public_values", {}) is Dictionary else {}
			var outcome_id := str(public_values.get("outcome_id", "")).strip_edges()
			var winner_indices: Array = public_values.get("winner_player_indices", []) \
				if public_values.get("winner_player_indices", []) is Array else []
			if str(entry.get("event_kind", "")) != "final_settlement" \
					or str(entry.get("localization_key", "")) != "victory.public.final_settlement" \
					or str(public_values.get("public_status", "")) != "settled" \
					or str(public_values.get("reason_code", "")) != "public_audit_complete" \
					or outcome_id.is_empty() or winner_indices.is_empty() \
					or not expected_outcome_id.is_empty() and outcome_id != expected_outcome_id:
				continue
			rows.append({
				"outcome_id": outcome_id,
				"source_revision": maxi(0, int(entry.get("source_revision", 0))),
				"winner_count": winner_indices.size(),
			})
	return {
		"public_entry_count": rows.size(),
		"outcome_id": str((rows[0] as Dictionary).get("outcome_id", "")) if rows.size() == 1 else "",
		"public_fingerprint": JSON.stringify(rows).sha256_text() if not rows.is_empty() else "",
	}


func _scripted_ui_action(
	runtime_screen: Node,
	exhausted_navigation_actions: Dictionary = {},
	public_progress: Dictionary = {},
	supply_rotation_state: Dictionary = {},
	sale_receipt: Dictionary = {}
) -> Dictionary:
	_action_projection_count += 1
	if runtime_screen == null:
		return {"id": "", "phase": "play", "disabled": true}
	var menu_action := _menu_overlay_ui_action(runtime_screen)
	if not menu_action.is_empty():
		return menu_action
	var ui_variant: Variant = runtime_screen.get("current_ui_data")
	var ui: Dictionary = ui_variant if ui_variant is Dictionary else {}
	var player_board: Dictionary = ui.get("player_board", {}) if ui.get("player_board", {}) is Dictionary else {}
	var hand_cards: Array = player_board.get("hand_cards", []) if player_board.get("hand_cards", []) is Array else []
	var temporary: Dictionary = ui.get("temporary_decision", {}) if ui.get("temporary_decision", {}) is Dictionary else {}
	if not temporary.is_empty():
		var temporary_action := _first_enabled_action(temporary.get("actions", []))
		if not temporary_action.is_empty():
			return {
				"id": str(temporary_action.get("id", "")),
				"phase": "decision_window.%s" % str(temporary.get("kind", "choice")),
				"disabled": bool(temporary_action.get("disabled", false)),
				"origin": "temporary_decision",
			}
	var source_established := false
	var production_installation_count := int(public_progress.get("production_installation_count", 0))
	var production_source_established := production_installation_count >= 1
	var production_chain_incomplete := production_installation_count < TARGET_PRODUCTION_INSTALLATION_COUNT
	var own_victory_eligible := bool(public_progress.get("eligible", false))
	var victory_countdown_active := not _victory_state_sequence.is_empty() \
		and _victory_state_sequence[-1] in ["qualification", "audit", "resolved"]
	var strategy_actions: Array[Dictionary] = []
	for strategy_kind in ["expand_economic_source", "protect_route", "pressure_competition"]:
		var strategy_action := _first_enabled_action_by_kind(player_board.get("actions", []), strategy_kind)
		if strategy_action.is_empty():
			continue
		source_established = true
		strategy_actions.append(strategy_action)
	# Once the production Owner confirms a real installation, stop manufacturing
	# clicks and let CommodityFlow produce the first typed Sale Receipt.
	if production_source_established and not bool(sale_receipt.get("observed", false)):
		return {
			"id": "gdp_accumulation_wait",
			"phase": "play.gdp_first_receipt",
			"disabled": true,
			"origin": "economic_wait",
		}
	if bool(sale_receipt.get("observed", false)) \
			and not production_chain_incomplete \
			and (own_victory_eligible or victory_countdown_active):
		return {
			"id": "gdp_accumulation_wait",
			"phase": "play.victory_qualification",
			"disabled": true,
			"origin": "economic_wait",
		}
	# Once the acceptance slice owns three real production installations, use
	# only the existing typed board strategy actions to recover/raise public GDP.
	# Do not keep buying cards or manufacture a driver-only economy shortcut.
	if bool(sale_receipt.get("observed", false)) and not production_chain_incomplete:
		for strategy_action in strategy_actions:
			var strategy_signature := "strategy:%s:%d" % [str(strategy_action.get("id", "strategy")), int(strategy_action.get("source_revision", 0))]
			if not bool(exhausted_navigation_actions.get(strategy_signature, false)):
				return _board_action_request(strategy_action, player_board, strategy_signature)
		return {
			"id": "gdp_accumulation_wait",
			"phase": "play.victory_qualification",
			"disabled": true,
			"origin": "economic_wait",
		}
	var required_facility_kind := "factory" if production_chain_incomplete else ""
	var facility_hand_action := _first_enabled_card_action_by_kind(
		hand_cards,
		"facility_v06",
		required_facility_kind
	)
	if not facility_hand_action.is_empty():
		return facility_hand_action
	var blocked_facility := first_unexhausted_card_by_kind(
		hand_cards,
		"facility_v06",
		_exhausted_facility_card_signatures,
		required_facility_kind
	)
	if not blocked_facility.is_empty():
		var play_reason_id := str(blocked_facility.get("play_reason_id", "invalid_payload"))
		if play_reason_id in FACILITY_TARGET_RETRY_REASON_IDS:
			var target_retry := _next_typed_facility_map_action(runtime_screen, blocked_facility)
			if not target_retry.is_empty():
				target_retry["phase"] = "play.hand.facility_v06.retarget.%s" % play_reason_id
				return target_retry
		else:
			return {
				"id": "facility_play_wait",
				"phase": "play.hand.facility_v06.wait.%s" % play_reason_id,
				"disabled": true,
				"origin": "economic_wait",
			}
	# A bought facility is a stronger continuation than rotating the public rack.
	# Rotation remains available only after the authorized hand projection proves
	# there is no facility card waiting to be played.
	var supply_rotation_action := _supply_rotation_action(runtime_screen, supply_rotation_state)
	if not supply_rotation_action.is_empty():
		return supply_rotation_action
	var visible_supply_action := _district_supply_ui_action(runtime_screen, production_chain_incomplete)
	if not visible_supply_action.is_empty():
		return visible_supply_action
	for strategy_action in strategy_actions:
		var strategy_signature := "strategy:%s:%d" % [str(strategy_action.get("id", "strategy")), int(strategy_action.get("source_revision", 0))]
		if not bool(exhausted_navigation_actions.get(strategy_signature, false)):
			return _board_action_request(strategy_action, player_board, strategy_signature)
	if source_established:
		return {
			"id": "gdp_accumulation_wait",
			"phase": "play.gdp_accumulation" if int(public_progress.get("top_k_gdp_per_minute", 0)) > 0 else "play.gdp_first_receipt",
			"disabled": true,
			"origin": "economic_wait",
		}
	var supply_action := _district_supply_ui_action(runtime_screen, production_chain_incomplete)
	if not supply_action.is_empty():
		return supply_action
	var build_source_action := _first_enabled_action_by_kind(player_board.get("actions", []), "build_economic_source")
	if not build_source_action.is_empty():
		return _board_action_request(build_source_action, player_board)
	for card_variant in hand_cards:
		if not (card_variant is Dictionary):
			continue
		var card: Dictionary = card_variant
		var card_action := _first_enabled_action(card.get("actions", []))
		if not card_action.is_empty():
			return {
				"id": str(card_action.get("id", "")),
				"phase": "play.hand.%s.%s" % [str(card.get("id", "card")), str(card.get("action_state", card.get("play_state", "ready")))],
				"disabled": false,
			}
	var board_action := _first_enabled_action(player_board.get("actions", []))
	var board_signature := ""
	if not board_action.is_empty():
		board_signature = _board_action_signature(board_action, player_board)
		if bool(exhausted_navigation_actions.get(board_signature, false)):
			board_action = _first_enabled_board_action(player_board, exhausted_navigation_actions)
			board_signature = _board_action_signature(board_action, player_board)
	if not board_action.is_empty():
		return _board_action_request(board_action, player_board, board_signature)
	var map_action := _next_public_map_action(runtime_screen)
	if not map_action.is_empty():
		return map_action
	return {"id": "", "phase": "play", "disabled": true}


func _district_supply_ui_action(runtime_screen: Node, production_chain_incomplete := false) -> Dictionary:
	var drawer := _district_supply_drawer(runtime_screen)
	if drawer == null or not drawer.visible or not drawer.has_signal("supply_action_requested"):
		return {}
	var snapshot := _annotate_new_facility_target_availability(_district_supply_view_snapshot())
	return district_supply_action_from_snapshot(snapshot, production_chain_incomplete)


func _district_supply_view_snapshot() -> Dictionary:
	if _district_supply_query_port == null:
		return {}
	_district_supply_query_count += 1
	var surface := _district_supply_query_port.snapshot_for_viewer(SCRIPTED_PLAYER_INDEX)
	if not bool(surface.get("visible", false)) or not (surface.get("snapshot", {}) is Dictionary):
		return {}
	return (surface.get("snapshot", {}) as Dictionary).duplicate(true)


func _annotate_new_facility_target_availability(snapshot: Dictionary) -> Dictionary:
	var result := snapshot.duplicate(true)
	if _table_presentation_query_ports == null:
		return result
	var cards: Array = result.get("cards", []) if result.get("cards", []) is Array else []
	var target_by_card_name := {}
	for card_index in range(cards.size()):
		if not (cards[card_index] is Dictionary):
			continue
		var card := (cards[card_index] as Dictionary).duplicate(true)
		if not _is_supply_facility_kind(str(card.get("kind", ""))):
			continue
		var target_snapshot := _table_presentation_query_ports.public_new_facility_target_candidates(
			StringName(str(card.get("facility_kind", ""))),
			StringName(str(card.get("industry_id", "")))
		)
		var target := target_snapshot.to_dictionary() if target_snapshot != null else {}
		var target_available := bool(target.get("available", false)) \
			and not (target.get("candidates", []) as Array).is_empty()
		card["new_target_available"] = target_available
		card["target_source_revision"] = int(target.get("source_revision", 0))
		card["target_reason_code"] = str(target.get("reason_code", "public_new_facility_target_query_unavailable"))
		cards[card_index] = card
		target_by_card_name[str(card.get("card_name", ""))] = {
			"new_target_available": target_available,
			"target_source_revision": int(card.get("target_source_revision", 0)),
			"target_reason_code": str(card.get("target_reason_code", "")),
		}
	result["cards"] = cards
	var preview: Dictionary = result.get("preview", {}) if result.get("preview", {}) is Dictionary else {}
	var preview_target: Dictionary = target_by_card_name.get(str(preview.get("card_name", "")), {}) \
		if target_by_card_name.get(str(preview.get("card_name", "")), {}) is Dictionary else {}
	if not preview_target.is_empty():
		preview = preview.duplicate(true)
		preview.merge(preview_target, true)
		result["preview"] = preview
	return result


static func district_supply_action_from_snapshot(snapshot: Dictionary, production_chain_incomplete := false) -> Dictionary:
	var preview: Dictionary = snapshot.get("preview", {}) if snapshot.get("preview", {}) is Dictionary else {}
	var preview_card_name := str(preview.get("card_name", ""))
	var primary_action_id := str(preview.get("primary_action_id", ""))
	var cards: Array = snapshot.get("cards", []) if snapshot.get("cards", []) is Array else []
	var preview_kind := _supply_card_kind(cards, preview_card_name)
	var preview_facility_kind := _supply_facility_kind(cards, preview_card_name)
	if not preview_card_name.is_empty() \
			and bool(preview.get("buy_enabled", false)) \
			and primary_action_id in ["district_supply_preview_card", "district_supply_purchase_card"] \
			and (not production_chain_incomplete \
				or (preview_facility_kind == "factory" \
					and _supply_new_target_available(cards, preview_card_name))):
		var action_phase := "quote" if primary_action_id == "district_supply_preview_card" else "purchase"
		return {
			"id": primary_action_id,
			"phase": "play.supply.%s.%s" % [action_phase, preview_card_name],
			"disabled": false,
			"origin": "district_supply",
			"payload": {"card_name": preview_card_name, "source": "full_run_visible_preview"},
		}
	var retry_next_facility := str(preview.get("action_reason_code", "")) in [
		"source_region_dark",
		"source_region_destroyed",
		"market_listing_changed",
		"market_quote_unavailable",
		"quote_expired",
	]
	var required_facility_kind := "factory" if production_chain_incomplete else ""
	var facility_card := _next_supply_facility_card(
		cards,
		preview_card_name if retry_next_facility else "",
		required_facility_kind
	)
	if not facility_card.is_empty():
		var facility_name := str(facility_card.get("card_name", ""))
		if preview_card_name != facility_name:
			return {
				"id": "district_supply_preview_card",
				"phase": "play.supply.preview_facility.%s" % facility_name,
				"disabled": false,
				"origin": "district_supply",
				"payload": {"card_name": facility_name, "source": "full_run_gdp_strategy"},
			}
	if production_chain_incomplete:
		var visible_facility := _next_visible_supply_facility_card(
			cards,
			preview_card_name,
			required_facility_kind
		)
		if not visible_facility.is_empty() and not _is_supply_facility_kind(preview_kind):
			var visible_facility_name := str(visible_facility.get("card_name", ""))
			return {
				"id": "district_supply_preview_card",
				"phase": "play.supply.preview_facility.%s" % visible_facility_name,
				"disabled": false,
				"origin": "district_supply",
				"payload": {"card_name": visible_facility_name, "source": "full_run_gdp_strategy"},
			}
		var wait_reason := str(preview.get("action_reason_code", "facility_not_visible")) \
			if _is_supply_facility_kind(preview_kind) else "facility_not_visible"
		return {
			"id": "district_supply_wait",
			"phase": "play.supply.wait.cards_%d.preview_%s.reason_%s" % [cards.size(), preview_card_name if not preview_card_name.is_empty() else "none", wait_reason],
			"disabled": true,
			"origin": "district_supply",
		}
	for card_variant in cards:
		if not (card_variant is Dictionary):
			continue
		var card: Dictionary = card_variant
		var card_name := str(card.get("card_name", ""))
		if card_name.is_empty() or not bool(card.get("actionable", true)):
			continue
		return {
			"id": "district_supply_preview_card",
			"phase": "play.supply.preview.%s" % card_name,
			"disabled": false,
			"origin": "district_supply",
			"payload": {"card_name": card_name, "source": "full_run_visible_card"},
		}
	return {
		"id": "district_supply_wait",
		"phase": "play.supply.wait.cards_%d.preview_%s.reason_%s" % [cards.size(), preview_card_name if not preview_card_name.is_empty() else "none", str(preview.get("action_reason_code", "purchase_unavailable"))],
		"disabled": true,
		"origin": "district_supply",
	}


func _refresh_visible_supply_quote(runtime_screen: Node) -> bool:
	var drawer := _district_supply_drawer(runtime_screen)
	if drawer == null or not drawer.visible or not drawer.has_signal("supply_action_requested"):
		return false
	var snapshot := _district_supply_view_snapshot()
	var preview: Dictionary = snapshot.get("preview", {}) if snapshot.get("preview", {}) is Dictionary else {}
	var card_name := str(preview.get("card_name", "")).strip_edges()
	if card_name.is_empty() or bool(preview.get("buy_enabled", false)):
		return false
	drawer.emit_signal("supply_action_requested", "district_supply_preview_card", {"card_name": card_name, "source": "full_run_quote_refresh"})
	return true


func _new_supply_rotation_state() -> Dictionary:
	return {
		"phase": "",
		"target_district": -1,
		"source_rack_signature": "",
		"source_selection_revision": -1,
		"rotation_count": 0,
		"exhausted_world_seconds": -1.0,
		"refresh_attempts_by_signature": {},
		"exhausted_signatures": {},
		"visited_districts": {},
	}


func _public_supply_wait_facts(runtime_screen: Node) -> Dictionary:
	var screen := runtime_screen as SpaceSyndicateGameScreen
	var drawer := _district_supply_drawer(runtime_screen)
	if screen == null or drawer == null or not drawer.visible:
		return {}
	var drawer_snapshot := _annotate_new_facility_target_availability(_district_supply_view_snapshot())
	var ui: Dictionary = screen.current_ui_data if screen.current_ui_data is Dictionary else {}
	var selection: Dictionary = ui.get("selection_context", {}) if ui.get("selection_context", {}) is Dictionary else {}
	var district_index := int(selection.get("selected_district", -1))
	var district_count := int(selection.get("district_count", 0))
	var card_signature_rows: Array[String] = []
	var has_visible_facility := false
	var has_visible_production_facility := false
	var cards: Array = drawer_snapshot.get("cards", []) if drawer_snapshot.get("cards", []) is Array else []
	for card_variant in cards:
		if not (card_variant is Dictionary):
			continue
		var card := card_variant as Dictionary
		has_visible_facility = has_visible_facility or _is_supply_facility_kind(str(card.get("kind", "")))
		has_visible_production_facility = has_visible_production_facility \
			or (str(card.get("facility_kind", "")) == "factory" \
				and bool(card.get("new_target_available", false)))
		card_signature_rows.append("%s|%s" % [
			str(card.get("card_name", "")),
			"%s|%s|%s" % [
				str(card.get("kind", "")),
				str(card.get("facility_kind", "")),
				str(card.get("industry_id", "")),
			],
		])
	var signature_source := {
		"district_index": district_index,
		"cards": card_signature_rows,
	}
	return {
		"valid": district_index >= 0 and district_count > 1,
		"district_index": district_index,
		"district_count": district_count,
		"selection_revision": int(selection.get("revision", -1)),
		"rack_signature": JSON.stringify(signature_source).sha256_text(),
		"has_visible_facility": has_visible_facility,
		"has_visible_production_facility": has_visible_production_facility,
	}


func _begin_supply_rack_rotation(rotation_state: Dictionary, wait_facts: Dictionary) -> bool:
	if rotation_state.is_empty() or not bool(wait_facts.get("valid", false)) \
			or not str(rotation_state.get("phase", "")).is_empty():
		return false
	if int(rotation_state.get("rotation_count", 0)) >= SUPPLY_RACK_ROTATION_LIMIT:
		rotation_state["phase"] = "exhausted"
		return false
	var selected_district := int(wait_facts.get("district_index", -1))
	var district_count := int(wait_facts.get("district_count", 0))
	var visited: Dictionary = rotation_state.get("visited_districts", {}) \
		if rotation_state.get("visited_districts", {}) is Dictionary else {}
	visited[selected_district] = true
	var target_district := -1
	for offset in range(1, district_count + 1):
		var candidate := wrapi(selected_district + offset, 0, district_count)
		if not bool(visited.get(candidate, false)):
			target_district = candidate
			break
	rotation_state["visited_districts"] = visited
	if target_district < 0:
		rotation_state["phase"] = "exhausted"
		return false
	rotation_state["phase"] = "close"
	rotation_state["target_district"] = target_district
	rotation_state["source_rack_signature"] = str(wait_facts.get("rack_signature", ""))
	rotation_state["source_selection_revision"] = int(wait_facts.get("selection_revision", -1))
	rotation_state["rotation_count"] = int(rotation_state.get("rotation_count", 0)) + 1
	return true


func _supply_rotation_action(runtime_screen: Node, rotation_state: Dictionary) -> Dictionary:
	if runtime_screen == null or rotation_state.is_empty():
		return {}
	var phase := str(rotation_state.get("phase", ""))
	if phase.is_empty():
		return {}
	if phase == "exhausted":
		return {
			"id": "district_supply_wait",
			"phase": "play.supply.rotation_exhausted_wait.%d" % int(rotation_state.get("rotation_count", 0)),
			"disabled": true,
			"origin": "economic_wait",
		}
	var drawer := _district_supply_drawer(runtime_screen)
	var screen := runtime_screen as SpaceSyndicateGameScreen
	if screen == null:
		return {}
	var ui: Dictionary = screen.current_ui_data if screen.current_ui_data is Dictionary else {}
	var selection: Dictionary = ui.get("selection_context", {}) if ui.get("selection_context", {}) is Dictionary else {}
	var selected_district := int(selection.get("selected_district", -1))
	var selection_revision := int(selection.get("revision", -1))
	var target_district := int(rotation_state.get("target_district", -1))
	if phase == "close":
		if drawer != null and drawer.visible:
			return {
				"id": "district_supply_rotation_close",
				"phase": "play.supply.rotation_close.%d" % int(rotation_state.get("source_selection_revision", -1)),
				"disabled": false,
				"origin": "district_supply_rotation",
			}
		rotation_state["phase"] = "select"
		phase = "select"
	if phase == "select":
		if selected_district != target_district:
			return {
				"id": "map_select_%d" % target_district,
				"phase": "play.supply.rotation_select.%d.%d" % [selection_revision, target_district],
				"disabled": false,
				"origin": "planet_map",
				"district_index": target_district,
			}
		rotation_state["phase"] = "open"
		phase = "open"
	if phase == "open":
		if drawer != null and drawer.visible:
			rotation_state["phase"] = ""
			rotation_state["target_district"] = -1
			return {}
		return {
			"id": "district_supply_rotation_open",
			"phase": "play.supply.rotation_open.%d.%d" % [selection_revision, target_district],
			"disabled": false,
			"origin": "district_supply_rotation",
			"district_index": target_district,
		}
	return {}


func _advance_supply_rotation_after_unavailable_open(
	runtime_screen: Node,
	rotation_state: Dictionary,
	failed_district: int
) -> bool:
	var screen := runtime_screen as SpaceSyndicateGameScreen
	if screen == null:
		return false
	var ui: Dictionary = screen.current_ui_data if screen.current_ui_data is Dictionary else {}
	var selection: Dictionary = ui.get("selection_context", {}) \
		if ui.get("selection_context", {}) is Dictionary else {}
	return advance_supply_rotation_after_unavailable_open(
		rotation_state,
		failed_district,
		int(selection.get("selected_district", -1)),
		int(selection.get("district_count", 0)),
		int(selection.get("revision", -1))
	)


static func advance_supply_rotation_after_unavailable_open(
	rotation_state: Dictionary,
	failed_district: int,
	selected_district: int,
	district_count: int,
	selection_revision: int
) -> bool:
	if rotation_state.is_empty() or str(rotation_state.get("phase", "")) != "open" \
			or failed_district < 0 or selected_district != failed_district \
			or district_count <= 1 or int(rotation_state.get("target_district", -1)) != failed_district:
		return false
	var visited: Dictionary = rotation_state.get("visited_districts", {}) \
		if rotation_state.get("visited_districts", {}) is Dictionary else {}
	visited[failed_district] = true
	rotation_state["visited_districts"] = visited
	rotation_state["source_rack_signature"] = ""
	rotation_state["source_selection_revision"] = selection_revision
	rotation_state["target_district"] = -1
	if int(rotation_state.get("rotation_count", 0)) >= SUPPLY_RACK_ROTATION_LIMIT:
		rotation_state["phase"] = "exhausted"
		return true
	var next_district := -1
	for offset in range(1, district_count + 1):
		var candidate := wrapi(failed_district + offset, 0, district_count)
		if not bool(visited.get(candidate, false)):
			next_district = candidate
			break
	if next_district < 0:
		rotation_state["phase"] = "exhausted"
		return true
	rotation_state["phase"] = "select"
	rotation_state["target_district"] = next_district
	rotation_state["rotation_count"] = int(rotation_state.get("rotation_count", 0)) + 1
	return true


static func _supply_card_kind(cards: Array, card_name: String) -> String:
	if card_name.is_empty():
		return ""
	for card_variant in cards:
		if card_variant is Dictionary and str((card_variant as Dictionary).get("card_name", "")) == card_name:
			return str((card_variant as Dictionary).get("kind", ""))
	return ""


static func _supply_facility_kind(cards: Array, card_name: String) -> String:
	if card_name.is_empty():
		return ""
	for card_variant in cards:
		if card_variant is Dictionary and str((card_variant as Dictionary).get("card_name", "")) == card_name:
			return str((card_variant as Dictionary).get("facility_kind", ""))
	return ""


static func _supply_new_target_available(cards: Array, card_name: String) -> bool:
	if card_name.is_empty():
		return false
	for card_variant in cards:
		if card_variant is Dictionary \
				and str((card_variant as Dictionary).get("card_name", "")) == card_name:
			return bool((card_variant as Dictionary).get("new_target_available", false))
	return false


static func _is_supply_facility_kind(kind: String) -> bool:
	# The public region-supply projection uses the v0.6 catalog category
	# (`facility`); hand presentation uses `facility_v06`. Accept both typed
	# projections without inferring card identity from its name.
	return kind in ["facility", "facility_v06", "public_facility"]


static func recoverable_supply_receipt_reason(reason_code: String) -> bool:
	# These outcomes are normal consequences of the public five-second quote and
	# rotating illumination. The UI clears/replaces the quote, so a human can
	# retry without any gameplay mutation having occurred.
	return reason_code in [
		"locked_quote_changed",
		"quote_unavailable",
		"source_region_dark",
		"card_not_in_supply",
		"forced_decision_blocks_district_supply",
	]


static func supply_receipt_confirms_progress(
	pending_action: Dictionary,
	receipt_sequence: int,
	receipt: Dictionary
) -> bool:
	return str(pending_action.get("origin", "")) in ["district_supply", "district_supply_rotation"] \
		and receipt_sequence > int(pending_action.get("supply_receipt_sequence", -1)) \
		and bool(receipt.get("accepted", false)) \
		and bool(receipt.get("applied", false))


static func selection_receipt_confirms_progress(
	pending_action: Dictionary,
	receipt_sequence: int,
	receipt: Dictionary
) -> bool:
	return str(pending_action.get("origin", "")) == "planet_map" \
		and receipt_sequence > int(pending_action.get("selection_receipt_sequence", -1)) \
		and bool(receipt.get("accepted", false)) \
		and bool(receipt.get("applied", false)) \
		and str(receipt.get("selection_kind", "")) == str(TableSelectionIntent.KIND_SELECT_DISTRICT) \
		and int(receipt.get("district_index", -1)) == int(pending_action.get("district_index", -2))


static func _next_supply_facility_card(
	cards: Array,
	after_card_name: String = "",
	required_facility_kind: String = ""
) -> Dictionary:
	var matching: Array[Dictionary] = []
	for card_variant in cards:
		if card_variant is Dictionary:
			var card := card_variant as Dictionary
			if _is_supply_facility_kind(str(card.get("kind", ""))) \
					and (required_facility_kind.is_empty() \
						or str(card.get("facility_kind", "")) == required_facility_kind) \
					and (required_facility_kind.is_empty() \
						or bool(card.get("new_target_available", false))) \
					and bool(card.get("actionable", false)):
				matching.append(card)
	if matching.is_empty():
		return {}
	if after_card_name.is_empty():
		return matching[0].duplicate(true)
	for index in range(matching.size()):
		if str(matching[index].get("card_name", "")) == after_card_name:
			return matching[wrapi(index + 1, 0, matching.size())].duplicate(true)
	return matching[0].duplicate(true)


static func _next_visible_supply_facility_card(
	cards: Array,
	after_card_name: String = "",
	required_facility_kind: String = ""
) -> Dictionary:
	var matching: Array[Dictionary] = []
	for card_variant in cards:
		if card_variant is Dictionary:
			var card := card_variant as Dictionary
			if _is_supply_facility_kind(str(card.get("kind", ""))) \
					and (required_facility_kind.is_empty() \
						or str(card.get("facility_kind", "")) == required_facility_kind) \
					and (required_facility_kind.is_empty() \
						or bool(card.get("new_target_available", false))):
				matching.append(card)
	if matching.is_empty():
		return {}
	if after_card_name.is_empty():
		return matching[0].duplicate(true)
	for index in range(matching.size()):
		if str(matching[index].get("card_name", "")) == after_card_name:
			return matching[wrapi(index + 1, 0, matching.size())].duplicate(true)
	return matching[0].duplicate(true)


static func _next_supply_card_of_kind(cards: Array, kind: String, after_card_name: String = "") -> Dictionary:
	var matching: Array[Dictionary] = []
	for card_variant in cards:
		if card_variant is Dictionary and str((card_variant as Dictionary).get("kind", "")) == kind:
			matching.append((card_variant as Dictionary).duplicate(true))
	if matching.is_empty():
		return {}
	for card in matching:
		if bool(card.get("actionable", false)):
			return card
	if after_card_name.is_empty():
		return matching[0]
	for index in range(matching.size()):
		if str(matching[index].get("card_name", "")) == after_card_name:
			return matching[wrapi(index + 1, 0, matching.size())]
	return matching[0]


func _first_enabled_action_by_kind(value: Variant, kind: String) -> Dictionary:
	if not (value is Array):
		return {}
	for action_variant in value as Array:
		if action_variant is Dictionary:
			var action: Dictionary = action_variant
			if str(action.get("kind", "")) == kind and not str(action.get("id", "")).is_empty() and not bool(action.get("disabled", false)):
				return action.duplicate(true)
	return {}


func _first_enabled_card_action_by_kind(
	cards: Array,
	kind: String,
	required_facility_kind: String = ""
) -> Dictionary:
	for card_variant in cards:
		if not (card_variant is Dictionary):
			continue
		var card: Dictionary = card_variant
		if str(card.get("kind", "")) != kind:
			continue
		if not required_facility_kind.is_empty() \
				and str(card.get("facility_kind", "")) != required_facility_kind:
			continue
		var action := _first_enabled_action(card.get("actions", []))
		if not action.is_empty():
			return {
				"id": str(action.get("id", "")),
				"phase": "play.hand.%s.%s" % [kind, str(card.get("action_state", card.get("play_state", "ready")))],
				"disabled": false,
			}
	return {}


func _first_card_by_kind(cards: Array, kind: String) -> Dictionary:
	for card_variant in cards:
		if card_variant is Dictionary and str((card_variant as Dictionary).get("kind", "")) == kind:
			return (card_variant as Dictionary).duplicate(true)
	return {}


static func facility_card_retry_signature(card: Dictionary) -> String:
	if card.is_empty():
		return ""
	return "%s|%d|%s|%s|%s" % [
		str(card.get("card_id", card.get("id", ""))),
		int(card.get("slot", -1)),
		str(card.get("name", "")),
		str(card.get("facility_kind", "")),
		str(card.get("industry_id", "")),
	]


static func first_unexhausted_card_by_kind(
	cards: Array,
	kind: String,
	exhausted: Dictionary,
	required_facility_kind: String = ""
) -> Dictionary:
	for card_variant in cards:
		if not (card_variant is Dictionary):
			continue
		var card := card_variant as Dictionary
		if str(card.get("kind", "")) != kind:
			continue
		if not required_facility_kind.is_empty() \
				and str(card.get("facility_kind", "")) != required_facility_kind:
			continue
		var signature := facility_card_retry_signature(card)
		if not signature.is_empty() and not bool(exhausted.get(signature, false)):
			return card.duplicate(true)
	return {}


func _board_action_request(action: Dictionary, player_board: Dictionary, signature: String = "") -> Dictionary:
	var action_signature := signature if not signature.is_empty() else _board_action_signature(action, player_board)
	return {
		"id": str(action.get("id", "")),
		"phase": "play.board.%s.%s" % [str(action.get("kind", "action")), str(action.get("state", "ready"))],
		"disabled": bool(action.get("disabled", false)),
		"origin": "board_primary" if str(action.get("kind", "")) in ["build_economic_source", "expand_economic_source", "open_rack", "summon_monster", "play_card", "review_economy", "protect_route", "pressure_competition"] else "board_action",
		"signature": action_signature,
	}


func _submit_scripted_ui_action(runtime_screen: Node, action: Dictionary) -> bool:
	var action_id := str(action.get("id", ""))
	if str(action.get("origin", "")) == "temporary_decision":
		var temporary_decision_overlay := _temporary_decision_overlay(runtime_screen)
		if temporary_decision_overlay == null or action_id.is_empty():
			return false
		temporary_decision_overlay.temporary_decision_action_requested.emit(action_id)
		return true
	if str(action.get("origin", "")) == "district_supply_rotation":
		var rotation_screen := runtime_screen as SpaceSyndicateGameScreen
		if rotation_screen == null:
			return false
		if action_id == "district_supply_rotation_close":
			return rotation_screen.request_district_supply_close(&"qa_driver")
		if action_id == "district_supply_rotation_open":
			return rotation_screen.request_district_supply_open(int(action.get("district_index", -1)), &"qa_driver")
		return false
	if action_id in TYPED_RACK_ACTION_IDS:
		var screen := runtime_screen as SpaceSyndicateGameScreen
		if screen == null:
			return false
		var ui: Dictionary = screen.current_ui_data if screen.current_ui_data is Dictionary else {}
		var selection_context: Dictionary = ui.get("selection_context", {}) if ui.get("selection_context", {}) is Dictionary else {}
		var selected_district := int(selection_context.get("selected_district", -1))
		return selected_district >= 0 and screen.request_district_supply_open(selected_district, &"qa_driver")
	if str(action.get("origin", "")) == "menu_overlay":
		var menu_overlay := _menu_overlay(runtime_screen)
		if menu_overlay != null and menu_overlay.has_signal("continue_requested"):
			menu_overlay.emit_signal("continue_requested")
			return true
		return false
	if str(action.get("origin", "")) == "district_supply":
		var supply_screen := runtime_screen as SpaceSyndicateGameScreen
		if action_id == "district_supply_purchase_card":
			return supply_screen != null and supply_screen.request_selected_district_supply_purchase(&"qa_driver")
		var drawer := _district_supply_drawer(runtime_screen)
		if drawer != null and drawer.has_signal("supply_action_requested"):
			drawer.emit_signal("supply_action_requested", str(action.get("id", "")), (action.get("payload", {}) as Dictionary).duplicate(true))
			return true
		return false
	if str(action.get("origin", "")) == "planet_map":
		var selection_screen := runtime_screen as SpaceSyndicateGameScreen
		return selection_screen != null \
			and selection_screen.request_district_selection(int(action.get("district_index", -1)), &"qa_driver")
	if runtime_screen == null or not runtime_screen.has_signal("action_requested") or action_id.is_empty():
		return false
	runtime_screen.emit_signal("action_requested", action_id)
	return true


func _temporary_decision_overlay(runtime_screen: Node) -> SpaceSyndicateOverlayLayer:
	var screen := runtime_screen as SpaceSyndicateGameScreen
	if screen == null:
		return null
	return screen.get_overlay_host() as SpaceSyndicateOverlayLayer


func _district_supply_drawer(runtime_screen: Node) -> Node:
	if runtime_screen == null:
		return null
	if runtime_screen.has_method("get_district_supply_drawer"):
		var owned_drawer: Variant = runtime_screen.call("get_district_supply_drawer")
		if owned_drawer is Node:
			return owned_drawer as Node
	var drawer := runtime_screen.get_node_or_null("OverlayLayer/RuntimeSurfaceLayer/DistrictSupplySideDrawerOverlay")
	if drawer == null:
		drawer = runtime_screen.find_child("DistrictSupplySideDrawerOverlay", true, false)
	return drawer


func _menu_overlay_ui_action(runtime_screen: Node) -> Dictionary:
	var menu_overlay := _menu_overlay(runtime_screen)
	if menu_overlay == null or not menu_overlay.visible or not menu_overlay.has_signal("continue_requested"):
		return {}
	return {
		"id": "menu_continue",
		"phase": "menu.close",
		"disabled": false,
		"origin": "menu_overlay",
	}


func _menu_overlay(runtime_screen: Node) -> Node:
	var main := runtime_screen.get_parent()
	if main == null:
		return null
	var direct := main.find_child("MenuModalOverlay", true, false)
	return direct if direct != null else main.find_child("MenuOverlay", true, false)


func _runtime_action_feedback(runtime_screen: Node) -> Dictionary:
	if runtime_screen == null or not runtime_screen.has_method("get_runtime_player_feedback_snapshot"):
		return {}
	var value: Variant = runtime_screen.call("get_runtime_player_feedback_snapshot")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _on_district_supply_action_receipt(receipt: DistrictSupplyActionReceipt) -> void:
	if receipt == null:
		return
	_district_supply_receipt_sequence += 1
	_last_district_supply_receipt = {
		"accepted": receipt.accepted,
		"applied": receipt.applied,
		"reason_code": receipt.reason_code,
		"action_kind": str(receipt.action_kind),
		"request_id": receipt.request_id,
	}
	if not receipt.accepted:
		return
	match receipt.action_kind:
		DistrictSupplyActionIntent.KIND_OPEN:
			_mark_milestone("time_to_first_rack")
		DistrictSupplyActionIntent.KIND_QUOTE:
			_mark_milestone("time_to_first_quote")
		DistrictSupplyActionIntent.KIND_PURCHASE:
			_mark_milestone("time_to_first_purchase")


func _on_table_selection_receipt(receipt: TableSelectionReceipt) -> void:
	if receipt == null:
		return
	_table_selection_receipt_sequence += 1
	_last_table_selection_receipt = {
		"accepted": receipt.accepted,
		"applied": receipt.applied,
		"reason_code": receipt.reason_code,
		"selection_kind": str(receipt.selection_kind),
		"district_index": receipt.district_index,
		"selection_revision_after": receipt.selection_revision_after,
	}


func _on_monster_wager_response_receipt(receipt: MonsterWagerResponseReceipt) -> void:
	if receipt == null:
		return
	_monster_wager_receipt_sequence += 1
	var detached := {
		"schema_version": receipt.schema_version,
		"sequence": _monster_wager_receipt_sequence,
		"decision_id": receipt.decision_id,
		"decision_revision": receipt.decision_revision,
		"wager_id": receipt.wager_id,
		"viewer_index": receipt.viewer_index,
		"player_index": receipt.player_index,
		"accepted": receipt.accepted,
		"applied": receipt.applied,
		"decision_closed": receipt.decision_closed,
		"reason_code": receipt.reason_code,
		"visibility_scope": str(receipt.visibility_scope),
	}
	detached["receipt_fingerprint"] = JSON.stringify(detached).sha256_text()
	_last_monster_wager_receipt = detached


func _mark_milestone(key: String) -> void:
	if _session_started_msec <= 0 or float(_milestones.get(key, -1.0)) >= 0.0:
		return
	_milestones[key] = snappedf(
		maxf(0.0, float(Time.get_ticks_msec() - _session_started_msec) / 1000.0),
		0.001
	)


func _apply_driver_planning_transition(action: Dictionary) -> bool:
	if str(action.get("origin", "")) != "driver_planning":
		return false
	match str(action.get("id", "")):
		"facility_candidate_rejected":
			var attempt_key := str(action.get("candidate_attempt_key", "")).strip_edges()
			var public_index := int(action.get("public_index", -1))
			if attempt_key.is_empty() or public_index < 0:
				return false
			var attempted: Dictionary = _facility_candidate_attempts.get(attempt_key, {}) \
				if _facility_candidate_attempts.get(attempt_key, {}) is Dictionary else {}
			attempted[public_index] = true
			_facility_candidate_attempts[attempt_key] = attempted
			return true
		"facility_target_search_exhausted":
			var signature := str(action.get("facility_card_signature", "")).strip_edges()
			if signature.is_empty():
				return false
			_exhausted_facility_card_signatures[signature] = true
			return true
	return false


func _next_typed_facility_map_action(runtime_screen: Node, card: Dictionary) -> Dictionary:
	var screen := runtime_screen as SpaceSyndicateGameScreen
	if screen == null or _table_presentation_query_ports == null:
		return {}
	var target_snapshot := _table_presentation_query_ports.public_new_facility_target_candidates(
		StringName(str(card.get("facility_kind", ""))),
		StringName(str(card.get("industry_id", "")))
	)
	var target := target_snapshot.to_dictionary() if target_snapshot != null else {}
	if not bool(target.get("available", false)):
		return {
			"id": "facility_play_wait",
			"phase": "play.hand.facility_v06.wait.%s" % str(target.get("reason_code", "target_query_unavailable")),
			"disabled": true,
			"origin": "economic_wait",
		}
	var ui: Dictionary = screen.current_ui_data if screen.current_ui_data is Dictionary else {}
	var selection: Dictionary = ui.get("selection_context", {}) \
		if ui.get("selection_context", {}) is Dictionary else {}
	var selected_district := int(selection.get("selected_district", -1))
	var candidates: Array = target.get("candidates", []) if target.get("candidates", []) is Array else []
	var card_signature := facility_card_retry_signature(card)
	var attempt_key := "%s|targets:%d" % [card_signature, int(target.get("source_revision", 0))]
	var attempted: Dictionary = _facility_candidate_attempts.get(attempt_key, {}) \
		if _facility_candidate_attempts.get(attempt_key, {}) is Dictionary else {}
	for candidate_variant in candidates:
		if candidate_variant is Dictionary \
				and int((candidate_variant as Dictionary).get("public_index", -1)) == selected_district \
				and not bool(attempted.get(selected_district, false)):
			return {
				"id": "facility_candidate_rejected",
				"phase": "driver.facility_candidate_rejected.%d" % selected_district,
				"disabled": false,
				"origin": "driver_planning",
				"candidate_attempt_key": attempt_key,
				"public_index": selected_district,
			}
	var candidate := next_public_facility_candidate(candidates, attempted)
	if candidate.is_empty():
		return {
			"id": "facility_target_search_exhausted",
			"phase": "driver.facility_target_search_exhausted",
			"disabled": false,
			"origin": "driver_planning",
			"facility_card_signature": card_signature,
		}
	var target_district := int(candidate.get("public_index", -1))
	return {
		"id": "map_select_%d" % target_district,
		"phase": "play.map.%d_to_%d" % [selected_district, target_district],
		"disabled": false,
		"origin": "planet_map",
		"district_index": target_district,
	}


static func next_public_facility_candidate(candidates: Array, attempted: Dictionary) -> Dictionary:
	for candidate_variant in candidates:
		if not (candidate_variant is Dictionary):
			continue
		var candidate := candidate_variant as Dictionary
		var public_index := int(candidate.get("public_index", -1))
		if public_index >= 0 and not bool(attempted.get(public_index, false)):
			return candidate.duplicate(true)
	return {}


func _next_public_map_action(runtime_screen: Node) -> Dictionary:
	var screen := runtime_screen as SpaceSyndicateGameScreen
	if screen == null:
		return {}
	var ui: Dictionary = screen.current_ui_data if screen.current_ui_data is Dictionary else {}
	var selection: Dictionary = ui.get("selection_context", {}) if ui.get("selection_context", {}) is Dictionary else {}
	var district_count := int(selection.get("district_count", 0))
	if district_count <= 1:
		return {}
	var selected_district := int(selection.get("selected_district", -1))
	var next_district := next_unexhausted_map_district(
		selected_district,
		district_count,
		_exhausted_map_districts
	)
	if next_district < 0:
		return {}
	return {
		"id": "map_select_%d" % next_district,
		"phase": "play.map.%d_to_%d" % [selected_district, next_district],
		"disabled": false,
		"origin": "planet_map",
		"district_index": next_district,
	}


static func next_unexhausted_map_district(
	selected_district: int,
	district_count: int,
	exhausted: Dictionary
) -> int:
	if district_count <= 1:
		return -1
	for offset in range(1, district_count + 1):
		var candidate := wrapi(selected_district + offset, 0, district_count)
		if not bool(exhausted.get(candidate, false)):
			return candidate
	return -1


func _first_enabled_board_action(player_board: Dictionary, exhausted_navigation_actions: Dictionary) -> Dictionary:
	var actions: Array = player_board.get("actions", []) if player_board.get("actions", []) is Array else []
	for action_variant in actions:
		if not (action_variant is Dictionary):
			continue
		var action: Dictionary = action_variant
		if str(action.get("id", "")).is_empty() or bool(action.get("disabled", false)):
			continue
		if not bool(exhausted_navigation_actions.get(_board_action_signature(action, player_board), false)):
			return action.duplicate(true)
	return {}


func _board_action_signature(action: Dictionary, player_board: Dictionary) -> String:
	if action.is_empty():
		return ""
	var actions: Array = player_board.get("actions", []) if player_board.get("actions", []) is Array else []
	var public_context := {
		"actions": actions,
		"selected_district_summary": str(player_board.get("selected_district_summary", "")),
	}
	return "%s:%s" % [str(action.get("id", "")), str(hash(var_to_str(public_context)))]


func _first_enabled_action(value: Variant) -> Dictionary:
	if not (value is Array):
		return {}
	for action_variant in value as Array:
		if action_variant is Dictionary:
			var action: Dictionary = action_variant
			if not str(action.get("id", "")).is_empty() and not bool(action.get("disabled", false)):
				return action.duplicate(true)
	return {}


func _phase_for(session_state: String, victory: Dictionary, decision: Dictionary, ui_action: Dictionary, settlement: Dictionary) -> String:
	if bool(settlement.get("completed", false)) or str(victory.get("state", "")) == "resolved":
		return "settlement"
	var victory_state := str(victory.get("state", "idle"))
	if victory_state == "audit":
		return "audit"
	if victory_state == "qualification":
		return "qualification"
	if not decision.is_empty():
		return "decision_window.%s" % str(decision.get("kind", "choice"))
	var ui_phase := str(ui_action.get("phase", ""))
	if not ui_phase.is_empty():
		return ui_phase
	if session_state == "finished":
		return "finished"
	if session_state == "running":
		return "play"
	return "setup"


func _session_state(session: Node) -> String:
	return str(_session_summary(session).get("session_state", "unavailable"))


func _session_summary(session: Node) -> Dictionary:
	if session == null or not session.has_method("session_summary"):
		return {}
	var summary_variant: Variant = session.call("session_summary")
	return (summary_variant as Dictionary).duplicate(true) if summary_variant is Dictionary else {}


func _empty_telemetry(seed_index: int, phase: String, event: String) -> Dictionary:
	var safe_index := clampi(seed_index, 0, FIXED_SEEDS.size() - 1)
	return FullRunQualitySnapshotScript.compose({
		"seed": FIXED_SEEDS[safe_index],
		"phase": phase,
		"elapsed": {"wall_seconds": _elapsed_seconds(), "world_seconds": 0.0},
		"decision_window": {},
		"settlement": {},
		"invalid_actions": {"count": 0, "last_reason_code": event},
		"last_event": event,
		"observed_public_facts": {},
	})


func _summary(options: Dictionary, telemetry: Dictionary, status: String, failure_code: String, capability: Dictionary, save_status: Dictionary) -> Dictionary:
	var seed_index := clampi(int(options.get("seed_index", 0)), 0, FIXED_SEEDS.size() - 1)
	var result := {
		"type": "summary",
		"schema": DRIVER_SCHEMA,
		"driver": DRIVER_ID,
		"algorithm": SEED_ALGORITHM,
		"run_id": "seed-%02d" % seed_index,
		"run_count": 1,
		"seed_index": seed_index,
		"seed": FIXED_SEEDS[seed_index],
		"completed": status == "settled" \
			and bool((telemetry.get("settlement", {}) as Dictionary).get("completed", false)) \
			and bool((telemetry.get("settlement", {}) as Dictionary).get("quiescence_verified", false)) \
			and bool((telemetry.get("settlement", {}) as Dictionary).get("rng_quiescence_verified", false)) \
			and bool((telemetry.get("settlement", {}) as Dictionary).get("transition_sequence_complete", false)),
		"status": status,
		"failure_code": failure_code,
		"qa_save_scope": qa_save_directory(_head_token(), FIXED_SEEDS[seed_index]),
		"capability": capability.duplicate(true),
		"save": save_status.duplicate(true),
		"actions": _action_stats.duplicate(true),
		"milestones": _milestones.duplicate(true),
		"performance": _performance_snapshot(),
		"determinism": {"rng_checkpoints": _rng_checkpoints.duplicate(true)},
		"wall_ms": maxi(0, Time.get_ticks_msec() - _started_msec),
	}
	for key_variant in FullRunQualitySnapshotScript.PUBLIC_KEYS:
		var key := str(key_variant)
		if key in ["schema", "seed"]:
			continue
		result[key] = telemetry.get(key)
	return result


func _performance_snapshot() -> Dictionary:
	return {
		"telemetry_collect_count": _telemetry_collect_count,
		"action_projection_count": _action_projection_count,
		"district_supply_query_count": _district_supply_query_count,
		"standings_progress_query_count": _standings_progress_query_count,
		"economic_source_query_count": _economic_source_query_count,
		"deep_copy_proxy_count": _district_supply_query_count + _standings_progress_query_count + _economic_source_query_count,
		"telemetry_refresh_interval_msec": TELEMETRY_REFRESH_INTERVAL_MSEC,
		"authoritative_step_batch_count": _authoritative_step_batch_count,
		"authoritative_step_attempt_count": _authoritative_step_attempt_count,
		"authoritative_step_active_count": _authoritative_step_active_count,
		"authoritative_step_world_seconds": _authoritative_step_world_seconds,
		"authoritative_step_wall_msec_total": _authoritative_step_wall_msec_total,
		"authoritative_step_wall_msec_max": _authoritative_step_wall_msec_max,
		"authoritative_step_wall_msec_average": float(_authoritative_step_wall_msec_total) \
			/ float(maxi(1, _authoritative_step_attempt_count)),
		"authoritative_slowest_step_path": _authoritative_slowest_step_path,
		"authoritative_slowest_step_reason": _authoritative_slowest_step_reason,
		"authoritative_step_seconds": AUTHORITATIVE_WAIT_STEP_SECONDS,
		"authoritative_step_limit": AUTHORITATIVE_WAIT_TOTAL_STEP_LIMIT,
		"blocked_realtime_step_batch_count": _blocked_realtime_step_batch_count,
		"blocked_realtime_step_attempt_count": _blocked_realtime_step_attempt_count,
		"blocked_realtime_step_count": _blocked_realtime_step_count,
		"blocked_realtime_seconds": _blocked_realtime_seconds,
		"blocked_realtime_step_limit": BLOCKED_REALTIME_TOTAL_STEP_LIMIT,
		"blocked_realtime_precondition_end_count": _blocked_realtime_precondition_end_count,
		"blocked_realtime_invariant_failure_count": _blocked_realtime_invariant_failure_count,
		"blocked_realtime_wall_msec_total": _blocked_realtime_wall_msec_total,
		"blocked_realtime_wall_msec_max": _blocked_realtime_wall_msec_max,
		"monster_wager_receipt_count": _monster_wager_receipt_sequence,
		"runtime_simulation_timing": _runtime_simulation_timing.duplicate(true),
		"runtime_loop_manual_mode_transition_count": _runtime_loop_manual_mode_transition_count,
		"timer_trace_sample_count": _victory_timer_trace.size(),
		"timer_trace_overflow": _victory_timer_trace_overflow,
		"authorized_timer_contract_ready": not _authorized_timer_contract.is_empty() \
			and _authorized_timer_contract_error.is_empty(),
		"authorized_timer_contract_fingerprint": JSON.stringify(_authorized_timer_contract).sha256_text() \
			if not _authorized_timer_contract.is_empty() else "",
	}


func _record_runtime_simulation_timing(coordinator: Node) -> void:
	var runtime_loop := coordinator.get_node_or_null(RUNTIME_LOOP_PATH) as RuntimeLoop if coordinator != null else null
	if runtime_loop == null:
		return
	var loop_debug := runtime_loop.debug_snapshot()
	var phase_debug: Dictionary = loop_debug.get("phase", {}) if loop_debug.get("phase", {}) is Dictionary else {}
	var simulation_debug: Dictionary = phase_debug.get("simulation", {}) if phase_debug.get("simulation", {}) is Dictionary else {}
	if simulation_debug.is_empty():
		return
	_runtime_simulation_timing = {
		"timing_count": (simulation_debug.get("timing_count", {}) as Dictionary).duplicate(true) \
			if simulation_debug.get("timing_count", {}) is Dictionary else {},
		"timing_total_usec": (simulation_debug.get("timing_total_usec", {}) as Dictionary).duplicate(true) \
			if simulation_debug.get("timing_total_usec", {}) is Dictionary else {},
		"timing_max_usec": (simulation_debug.get("timing_max_usec", {}) as Dictionary).duplicate(true) \
			if simulation_debug.get("timing_max_usec", {}) is Dictionary else {},
		"ai_tick_timing": (((simulation_debug.get("actor", {}) as Dictionary).get("ai_tick_timing", {}) as Dictionary).duplicate(true)) \
			if simulation_debug.get("actor", {}) is Dictionary \
			and (simulation_debug.get("actor", {}) as Dictionary).get("ai_tick_timing", {}) is Dictionary else {},
	}


func _record_rng_checkpoint(stage_id: String, coordinator: Node) -> void:
	if stage_id.is_empty() or _rng_checkpoints.has(stage_id):
		return
	var checkpoint := _capture_rng_checkpoint(coordinator)
	if checkpoint.is_empty():
		return
	_rng_checkpoints[stage_id] = checkpoint


func _capture_rng_checkpoint(coordinator: Node) -> Dictionary:
	if not (coordinator is GameRuntimeCoordinator):
		return {}
	var rng := (coordinator as GameRuntimeCoordinator).run_rng_service()
	if rng == null:
		return {}
	var checkpoint := rng.capture_plan_checkpoint()
	if int(checkpoint.get("schema_version", 0)) != 1 or int(checkpoint.get("draw_count", -1)) < 0:
		return {}
	return {
		"draw_count": int(checkpoint.get("draw_count", 0)),
		"checkpoint_fingerprint": JSON.stringify({
			"schema_version": 1,
			"rng_state": str(checkpoint.get("rng_state", 0)),
			"draw_count": int(checkpoint.get("draw_count", 0)),
		}).sha256_text(),
	}


func _capture_world_clock_checkpoint(coordinator: Node) -> Dictionary:
	if coordinator == null or not coordinator.has_method("world_effective_clock_snapshot"):
		return {}
	var value: Variant = coordinator.call("world_effective_clock_snapshot")
	if not (value is Dictionary):
		return {}
	var snapshot := value as Dictionary
	var world_effective_us := int(snapshot.get("world_effective_us", -1))
	if world_effective_us < 0:
		return {}
	return {
		"world_effective_us": world_effective_us,
		"checkpoint_fingerprint": JSON.stringify({
			"schema_version": 1,
			"world_effective_us": world_effective_us,
		}).sha256_text(),
	}


static func rng_quiescence_evidence(checkpoints: Dictionary) -> Dictionary:
	var terminal: Dictionary = checkpoints.get("terminal", {}) \
		if checkpoints.get("terminal", {}) is Dictionary else {}
	var quiescent: Dictionary = checkpoints.get("terminal_quiescent", {}) \
		if checkpoints.get("terminal_quiescent", {}) is Dictionary else {}
	if terminal.is_empty() or quiescent.is_empty():
		return {"verified": false, "reason_id": "terminal_rng_checkpoint_missing", "draw_delta": -1}
	var terminal_draw_count := int(terminal.get("draw_count", -1))
	var quiescent_draw_count := int(quiescent.get("draw_count", -1))
	var draw_delta := quiescent_draw_count - terminal_draw_count
	var verified := terminal_draw_count >= 0 \
		and quiescent_draw_count >= 0 \
		and draw_delta == 0 \
		and str(terminal.get("checkpoint_fingerprint", "")).length() == 64 \
		and str(terminal.get("checkpoint_fingerprint", "")) == str(quiescent.get("checkpoint_fingerprint", ""))
	return {
		"verified": verified,
		"reason_id": "terminal_rng_quiescent" if verified else "terminal_rng_delta_nonzero",
		"draw_delta": draw_delta,
		"terminal_draw_count": terminal_draw_count,
		"terminal_quiescent_draw_count": quiescent_draw_count,
	}


static func _rng_checkpoint_matches(left: Dictionary, right: Dictionary) -> bool:
	return not left.is_empty() \
		and int(left.get("draw_count", -1)) >= 0 \
		and int(left.get("draw_count", -1)) == int(right.get("draw_count", -2)) \
		and str(left.get("checkpoint_fingerprint", "")).length() == 64 \
		and str(left.get("checkpoint_fingerprint", "")) == str(right.get("checkpoint_fingerprint", ""))


static func blocked_realtime_step_evidence(
	step_result: Dictionary,
	world_before: Dictionary,
	world_after: Dictionary,
	rng_before: Dictionary,
	rng_after: Dictionary
) -> Dictionary:
	var result := {
		"verified": false,
		"reason_id": "blocked_realtime_step_rejected",
		"path": str(step_result.get("last_path", "unavailable")),
		"world_delta_us": -1,
		"rng_draw_delta": -1,
	}
	if not bool(step_result.get("accepted", false)):
		result["reason_id"] = str(step_result.get("reason_id", "blocked_realtime_step_rejected"))
		return result
	if int(step_result.get("attempted_steps", 0)) != 1:
		result["reason_id"] = "blocked_realtime_attempt_count_invalid"
		return result
	if int(step_result.get("active_steps", -1)) != 0 \
			or not is_zero_approx(float(step_result.get("world_seconds", -1.0))):
		result["reason_id"] = "blocked_realtime_active_world_leak"
		return result
	var path := str(step_result.get("last_path", ""))
	if path not in ["global_blocked", "blocked_realtime_unavailable", "terminal_pending", "finished"]:
		result["reason_id"] = "blocked_realtime_path_invalid:%s" % path
		return result
	if path == "global_blocked" and int(step_result.get("blocked_realtime_steps", 0)) != 1:
		result["reason_id"] = "blocked_realtime_step_count_invalid"
		return result
	if path == "blocked_realtime_unavailable" \
			and not bool(step_result.get("blocked_realtime_precondition_ended", false)):
		result["reason_id"] = "blocked_realtime_noop_unattested"
		return result
	if world_before.is_empty() or world_after.is_empty():
		result["reason_id"] = "blocked_realtime_world_checkpoint_missing"
		return result
	var world_delta_us := int(world_after.get("world_effective_us", -1)) \
		- int(world_before.get("world_effective_us", -1))
	result["world_delta_us"] = world_delta_us
	if world_delta_us != 0 \
			or str(world_before.get("checkpoint_fingerprint", "")) \
			!= str(world_after.get("checkpoint_fingerprint", "")):
		result["reason_id"] = "blocked_realtime_world_clock_changed"
		return result
	if rng_before.is_empty() or rng_after.is_empty():
		result["reason_id"] = "blocked_realtime_rng_checkpoint_missing"
		return result
	result["rng_draw_delta"] = int(rng_after.get("draw_count", -1)) - int(rng_before.get("draw_count", -1))
	if not _rng_checkpoint_matches(rng_before, rng_after):
		result["reason_id"] = "blocked_realtime_rng_changed"
		return result
	result["verified"] = true
	result["reason_id"] = "blocked_realtime_invariants_verified"
	return result


func _enter_runtime_loop_manual_mode(runtime_loop: RuntimeLoop) -> bool:
	if runtime_loop == null:
		return false
	if _runtime_loop_manual_mode:
		return not runtime_loop.is_processing()
	if not runtime_loop.is_processing():
		return false
	runtime_loop.set_process(false)
	if runtime_loop.is_processing():
		return false
	_runtime_loop_manual_mode = true
	_runtime_loop_manual_mode_transition_count += 1
	_runtime_loop_manual_expected_frame_index = int(runtime_loop.debug_snapshot().get("frame_index", -1))
	return true


func _leave_runtime_loop_manual_mode(runtime_loop: RuntimeLoop) -> void:
	if not _runtime_loop_manual_mode:
		return
	if runtime_loop != null:
		runtime_loop.set_process(true)
	_runtime_loop_manual_mode = false
	_runtime_loop_manual_mode_transition_count += 1
	_runtime_loop_manual_expected_frame_index = -1


func _record_authorized_timer_contract(progress: Dictionary) -> void:
	if _authorized_timer_contract_rejected:
		return
	var qualification_seconds_variant: Variant = progress.get("qualification_duration_seconds", null)
	var audit_seconds_variant: Variant = progress.get("audit_duration_seconds", null)
	if int(progress.get("schema_version", 0)) != 1 \
			or str(progress.get("visibility_scope", "")) != "viewer_private" \
			or int(progress.get("viewer_index", -1)) != SCRIPTED_PLAYER_INDEX \
			or typeof(qualification_seconds_variant) not in [TYPE_INT, TYPE_FLOAT] \
			or typeof(audit_seconds_variant) not in [TYPE_INT, TYPE_FLOAT]:
		_authorized_timer_contract_error = "timer_contract_shape_invalid"
		_authorized_timer_contract_rejected = true
		return
	var qualification_seconds := float(qualification_seconds_variant)
	var audit_seconds := float(audit_seconds_variant)
	if not is_finite(qualification_seconds) or qualification_seconds <= 0.0 \
			or not is_finite(audit_seconds) or audit_seconds <= 0.0:
		_authorized_timer_contract_error = "timer_contract_duration_invalid"
		_authorized_timer_contract_rejected = true
		return
	var candidate := {
		"schema_version": 1,
		"visibility_scope": "viewer_private",
		"viewer_index": SCRIPTED_PLAYER_INDEX,
		"qualification_duration_us": int(round(qualification_seconds * 1_000_000.0)),
		"audit_duration_us": int(round(audit_seconds * 1_000_000.0)),
	}
	if int(candidate.get("qualification_duration_us", 0)) <= 0 \
			or int(candidate.get("audit_duration_us", 0)) <= 0:
		_authorized_timer_contract_error = "timer_contract_precision_invalid"
		_authorized_timer_contract_rejected = true
		return
	if not _authorized_timer_contract.is_empty() and candidate != _authorized_timer_contract:
		_authorized_timer_contract_error = "timer_contract_changed_during_run"
		_authorized_timer_contract_rejected = true
		return
	_authorized_timer_contract = candidate
	_authorized_timer_contract_error = ""
	_attach_timer_contract_to_latest_trace()


func _attach_timer_contract_to_latest_trace() -> void:
	if _authorized_timer_contract.is_empty() or _victory_timer_trace.is_empty():
		return
	var latest := (_victory_timer_trace[-1] as Dictionary).duplicate(true)
	latest["qualification_duration_us"] = int(_authorized_timer_contract.get("qualification_duration_us", -1))
	latest["audit_duration_us"] = int(_authorized_timer_contract.get("audit_duration_us", -1))
	_victory_timer_trace[-1] = latest


func _record_authoritative_timeline_from_public_snapshot(coordinator: Node) -> void:
	if coordinator == null \
			or not coordinator.has_method("victory_control_public_snapshot") \
			or not coordinator.has_method("world_effective_clock_snapshot"):
		return
	var clock_variant: Variant = coordinator.call("world_effective_clock_snapshot")
	var victory_variant: Variant = coordinator.call("victory_control_public_snapshot", -1)
	if not (clock_variant is Dictionary) or not (victory_variant is Dictionary):
		return
	var sale_receipt := _public_sale_receipt_observation(coordinator)
	if bool(sale_receipt.get("observed", false)) and not _rng_checkpoints.has("first_sale_receipt"):
		_record_rng_checkpoint("first_sale_receipt", coordinator)
	_record_authoritative_timeline_observation(
		victory_variant as Dictionary,
		clock_variant as Dictionary,
		sale_receipt
	)


func _record_authoritative_timeline_observation(
	victory: Dictionary,
	clock: Dictionary,
	sale_receipt: Dictionary
) -> void:
	_authoritative_observation_sequence += 1
	var observation_sequence := _authoritative_observation_sequence
	if _first_sale_observation.is_empty() \
			and bool(sale_receipt.get("observed", false)) \
			and int(sale_receipt.get("public_event_count", 0)) > 0 \
			and str(sale_receipt.get("public_fingerprint", "")).length() == 64:
		var first_sale_world_seconds := float(sale_receipt.get("first_world_seconds", -1.0))
		if is_finite(first_sale_world_seconds) and first_sale_world_seconds >= 0.0:
			_first_sale_observation = {
				"observed": true,
				"first_observation_sequence": observation_sequence,
				"first_world_effective_us": int(round(first_sale_world_seconds * 1_000_000.0)),
				"public_event_count": int(sale_receipt.get("public_event_count", 0)),
				"public_fingerprint": str(sale_receipt.get("public_fingerprint", "")),
			}
	_record_victory_state(victory)
	var state_id := str(victory.get("state", "")).strip_edges()
	if str(victory.get("visibility_scope", "")) != "public" or state_id not in VICTORY_STATE_IDS:
		return
	var world_effective_us := int(clock.get(
		"world_effective_us",
		int(round(float(clock.get("world_effective_seconds", -1.0)) * 1_000_000.0))
	))
	var qualification_remaining := float(victory.get("qualification_remaining_seconds", -1.0))
	var audit_remaining := float(victory.get("audit_remaining_seconds", -1.0))
	if world_effective_us < 0 \
			or not is_finite(qualification_remaining) or qualification_remaining < 0.0 \
			or not is_finite(audit_remaining) or audit_remaining < 0.0:
		return
	var sample := {
		"observation_sequence": observation_sequence,
		"world_effective_us": world_effective_us,
		"state": state_id,
		"qualification_remaining_us": int(round(qualification_remaining * 1_000_000.0)),
		"audit_remaining_us": int(round(audit_remaining * 1_000_000.0)),
		"qualification_duration_us": int(_authorized_timer_contract.get("qualification_duration_us", -1)),
		"audit_duration_us": int(_authorized_timer_contract.get("audit_duration_us", -1)),
	}
	if not _victory_timer_trace.is_empty():
		var previous := _victory_timer_trace[-1] as Dictionary
		if state_id == "idle" and str(previous.get("state", "")) == "idle":
			_victory_timer_trace[-1] = sample
			return
		if state_id == "resolved" and str(previous.get("state", "")) == "resolved":
			return
		if int(previous.get("world_effective_us", -1)) == world_effective_us \
				and str(previous.get("state", "")) == state_id \
				and int(previous.get("qualification_remaining_us", -1)) == int(sample["qualification_remaining_us"]) \
				and int(previous.get("audit_remaining_us", -1)) == int(sample["audit_remaining_us"]):
			return
	if _victory_timer_trace.size() >= TIMER_TRACE_SAMPLE_LIMIT:
		_victory_timer_trace_overflow = true
		return
	_victory_timer_trace.append(sample)


func _record_victory_state(snapshot: Dictionary) -> void:
	var state_id := str(snapshot.get("state", "")).strip_edges()
	if str(snapshot.get("visibility_scope", "")) != "public" or not state_id in VICTORY_STATE_IDS:
		return
	if _victory_state_sequence.is_empty() or _victory_state_sequence[-1] != state_id:
		_victory_state_sequence.append(state_id)


static func timer_traversal_evidence(
	trace: Array,
	sale_observation: Dictionary,
	timer_contract: Dictionary,
	timer_contract_error := "",
	trace_overflow := false
) -> Dictionary:
	var qualification_duration_us := int(timer_contract.get("qualification_duration_us", -1))
	var audit_duration_us := int(timer_contract.get("audit_duration_us", -1))
	var result := {
		"verified": false,
		"reason_id": "timer_trace_incomplete",
		"sample_count": trace.size(),
		"trace_fingerprint": JSON.stringify(trace).sha256_text() if not trace.is_empty() else "",
		"sale_before_qualification": false,
		"sale_observation_sequence": int(sale_observation.get("first_observation_sequence", -1)),
		"qualification_observation_sequence": -1,
		"audit_observation_sequence": -1,
		"resolved_observation_sequence": -1,
		"qualification_authorized_duration_us": qualification_duration_us,
		"qualification_initial_remaining_us": -1,
		"qualification_entry_window_us": -1,
		"qualification_countdown_world_delta_us": -1,
		"qualification_total_world_delta_us": -1,
		"qualification_reset_count": 0,
		"audit_authorized_duration_us": audit_duration_us,
		"audit_initial_remaining_us": -1,
		"audit_countdown_world_delta_us": -1,
	}
	if not timer_contract_error.is_empty():
		return _timer_evidence_failure(result, timer_contract_error)
	if int(timer_contract.get("schema_version", 0)) != 1 \
			or str(timer_contract.get("visibility_scope", "")) != "viewer_private" \
			or int(timer_contract.get("viewer_index", -1)) != SCRIPTED_PLAYER_INDEX \
			or qualification_duration_us <= 0 or audit_duration_us <= 0:
		return _timer_evidence_failure(result, "timer_contract_unavailable")
	if trace_overflow:
		return _timer_evidence_failure(result, "timer_trace_overflow")
	if trace.size() < 4:
		return result
	var previous_sequence := -1
	var previous_world_us := -1
	var previous_state_rank := -1
	var qualification_reset_count := 0
	var state_ranks := {"idle": 0, "qualification": 1, "audit": 2, "resolved": 3}
	for index in range(trace.size()):
		if not (trace[index] is Dictionary):
			return _timer_evidence_failure(result, "timer_trace_sample_invalid")
		var sample := trace[index] as Dictionary
		var state_id := str(sample.get("state", ""))
		if not state_ranks.has(state_id):
			return _timer_evidence_failure(result, "timer_trace_state_invalid")
		var sequence := int(sample.get("observation_sequence", -1))
		var world_us := int(sample.get("world_effective_us", -1))
		var qualification_remaining_us := int(sample.get("qualification_remaining_us", -1))
		var audit_remaining_us := int(sample.get("audit_remaining_us", -1))
		if sequence <= previous_sequence or world_us < 0 or world_us < previous_world_us \
				or qualification_remaining_us < 0 or audit_remaining_us < 0 \
				or int(sample.get("qualification_duration_us", -1)) != qualification_duration_us \
				or int(sample.get("audit_duration_us", -1)) != audit_duration_us:
			return _timer_evidence_failure(result, "timer_trace_order_invalid")
		var state_rank := int(state_ranks[state_id])
		if state_rank < previous_state_rank:
			if state_id != "idle" or previous_state_rank == int(state_ranks["resolved"]):
				return _timer_evidence_failure(result, "timer_trace_state_regressed")
			qualification_reset_count += 1
		previous_sequence = sequence
		previous_world_us = world_us
		previous_state_rank = state_rank
	result["qualification_reset_count"] = qualification_reset_count
	var resolved_index := -1
	for index in range(trace.size() - 1, -1, -1):
		if str((trace[index] as Dictionary).get("state", "")) == "resolved":
			resolved_index = index
			break
	if resolved_index <= 0:
		return _timer_evidence_failure(result, "timer_trace_state_sequence_incomplete")
	var attempt_cursor := resolved_index - 1
	while attempt_cursor >= 0 \
			and str((trace[attempt_cursor] as Dictionary).get("state", "")) == "audit":
		attempt_cursor -= 1
	var audit_index := attempt_cursor + 1
	while attempt_cursor >= 0 \
			and str((trace[attempt_cursor] as Dictionary).get("state", "")) == "qualification":
		attempt_cursor -= 1
	var qualification_index := attempt_cursor + 1
	if qualification_index <= 0 or audit_index <= qualification_index or resolved_index <= audit_index:
		return _timer_evidence_failure(result, "timer_trace_state_sequence_incomplete")
	var idle_before := trace[qualification_index - 1] as Dictionary
	var first_qualification := trace[qualification_index] as Dictionary
	var first_audit := trace[audit_index] as Dictionary
	var first_resolved := trace[resolved_index] as Dictionary
	if str(idle_before.get("state", "")) != "idle" \
			or int(idle_before.get("qualification_remaining_us", -1)) != 0 \
			or int(idle_before.get("audit_remaining_us", -1)) != 0:
		return _timer_evidence_failure(result, "qualification_entry_baseline_missing")
	var entry_window_us := int(first_qualification.get("world_effective_us", -1)) \
		- int(idle_before.get("world_effective_us", -1))
	var qualification_initial_remaining_us := int(first_qualification.get("qualification_remaining_us", -1))
	var max_step_us := int(round(AUTHORITATIVE_WAIT_STEP_SECONDS * 1_000_000.0))
	if entry_window_us <= 0 or entry_window_us > max_step_us \
			or qualification_initial_remaining_us <= 0 \
			or qualification_initial_remaining_us > qualification_duration_us \
			or qualification_initial_remaining_us + entry_window_us < qualification_duration_us:
		return _timer_evidence_failure(result, "qualification_duration_entry_invalid")
	if int(first_qualification.get("audit_remaining_us", -1)) != 0:
		return _timer_evidence_failure(result, "qualification_audit_timer_overlap")
	for index in range(qualification_index + 1, audit_index):
		if not _timer_step_matches(trace[index - 1] as Dictionary, trace[index] as Dictionary, "qualification_remaining_us"):
			return _timer_evidence_failure(result, "qualification_timer_progression_invalid")
	var last_qualification := trace[audit_index - 1] as Dictionary
	if not _timer_transition_matches(last_qualification, first_audit, "qualification_remaining_us"):
		return _timer_evidence_failure(result, "qualification_timer_completion_invalid")
	var qualification_countdown_world_delta_us := int(first_audit.get("world_effective_us", -1)) \
		- int(first_qualification.get("world_effective_us", -1))
	if qualification_countdown_world_delta_us + TIMER_DELTA_TOLERANCE_US < qualification_initial_remaining_us \
			or qualification_countdown_world_delta_us - qualification_initial_remaining_us > max_step_us:
		return _timer_evidence_failure(result, "qualification_world_delta_invalid")
	var audit_initial_remaining_us := int(first_audit.get("audit_remaining_us", -1))
	if int(first_audit.get("qualification_remaining_us", -1)) != 0 \
			or audit_initial_remaining_us != audit_duration_us:
		return _timer_evidence_failure(result, "audit_duration_entry_invalid")
	for index in range(audit_index + 1, resolved_index):
		if not _timer_step_matches(trace[index - 1] as Dictionary, trace[index] as Dictionary, "audit_remaining_us"):
			return _timer_evidence_failure(result, "audit_timer_progression_invalid")
	var last_audit := trace[resolved_index - 1] as Dictionary
	if not _timer_transition_matches(last_audit, first_resolved, "audit_remaining_us"):
		return _timer_evidence_failure(result, "audit_timer_completion_invalid")
	if int(first_resolved.get("qualification_remaining_us", -1)) != 0 \
			or int(first_resolved.get("audit_remaining_us", -1)) != 0:
		return _timer_evidence_failure(result, "resolved_timer_state_invalid")
	var audit_countdown_world_delta_us := int(first_resolved.get("world_effective_us", -1)) \
		- int(first_audit.get("world_effective_us", -1))
	if audit_countdown_world_delta_us + TIMER_DELTA_TOLERANCE_US < audit_duration_us \
			or audit_countdown_world_delta_us - audit_duration_us > max_step_us:
		return _timer_evidence_failure(result, "audit_world_delta_invalid")
	var sale_sequence := int(sale_observation.get("first_observation_sequence", -1))
	var sale_world_us := int(sale_observation.get("first_world_effective_us", -1))
	var qualification_sequence := int(first_qualification.get("observation_sequence", -1))
	var sale_before_qualification := bool(sale_observation.get("observed", false)) \
		and int(sale_observation.get("public_event_count", 0)) > 0 \
		and str(sale_observation.get("public_fingerprint", "")).length() == 64 \
		and sale_sequence > 0 and sale_sequence < qualification_sequence \
		and sale_world_us >= 0 \
		and sale_world_us < int(first_qualification.get("world_effective_us", -1))
	if not sale_before_qualification:
		return _timer_evidence_failure(result, "sale_receipt_not_observed_before_qualification")
	result["verified"] = true
	result["reason_id"] = "timer_traversal_verified"
	result["sale_before_qualification"] = true
	result["qualification_observation_sequence"] = qualification_sequence
	result["audit_observation_sequence"] = int(first_audit.get("observation_sequence", -1))
	result["resolved_observation_sequence"] = int(first_resolved.get("observation_sequence", -1))
	result["qualification_initial_remaining_us"] = qualification_initial_remaining_us
	result["qualification_entry_window_us"] = entry_window_us
	result["qualification_countdown_world_delta_us"] = qualification_countdown_world_delta_us
	result["qualification_total_world_delta_us"] = int(first_audit.get("world_effective_us", -1)) \
		- int(idle_before.get("world_effective_us", -1))
	result["audit_initial_remaining_us"] = audit_initial_remaining_us
	result["audit_countdown_world_delta_us"] = audit_countdown_world_delta_us
	return result


static func outcome_identity_evidence(public_outcome: Dictionary, session_outcome: Dictionary) -> Dictionary:
	var public_identity := _outcome_identity(public_outcome)
	var session_identity := _outcome_identity(session_outcome)
	var public_fingerprint := JSON.stringify(public_identity).sha256_text() if not public_identity.is_empty() else ""
	var session_fingerprint := JSON.stringify(session_identity).sha256_text() if not session_identity.is_empty() else ""
	return {
		"verified": not public_identity.is_empty() \
			and public_identity == session_identity \
			and public_fingerprint == session_fingerprint,
		"public_outcome_id": str(public_identity.get("outcome_id", "")),
		"session_outcome_id": str(session_identity.get("outcome_id", "")),
		"public_fingerprint": public_fingerprint,
		"session_fingerprint": session_fingerprint,
	}


static func _outcome_identity(outcome: Dictionary) -> Dictionary:
	var outcome_id := str(outcome.get("outcome_id", "")).strip_edges()
	var reason_code := str(outcome.get("reason_code", "")).strip_edges()
	var schema_version := str(outcome.get("schema_version", "")).strip_edges()
	var ruleset_id := str(outcome.get("ruleset_id", "")).strip_edges()
	var winner_values: Variant = outcome.get("winner_player_indices", null)
	var comparison_values: Variant = outcome.get("comparison_order", null)
	var ranking_values: Variant = outcome.get("rankings", null)
	var audit_evidence := _normalized_outcome_audit_evidence(outcome)
	if outcome_id.is_empty() or reason_code.is_empty() or schema_version.is_empty() or ruleset_id.is_empty() \
			or not TablePresentationPureDataPolicy.is_pure_data(outcome) \
			or not (winner_values is Array) or (winner_values as Array).is_empty() \
			or not (comparison_values is Array) or (comparison_values as Array).is_empty() \
			or not (ranking_values is Array) or (ranking_values as Array).is_empty() \
			or audit_evidence.is_empty() \
			or (reason_code == "public_audit_complete" and (audit_evidence.get("audit_roster", []) as Array).is_empty()) \
			or (reason_code == "public_audit_complete" and str(audit_evidence.get("settlement_checkpoint", "")).is_empty()):
		return {}
	var winners: Array[int] = []
	for value in winner_values as Array:
		if typeof(value) != TYPE_INT or int(value) < 0 or winners.has(int(value)):
			return {}
		winners.append(int(value))
	var comparison_order: Array[String] = []
	for value in comparison_values as Array:
		var token := str(value).strip_edges()
		if token.is_empty():
			return {}
		comparison_order.append(token)
	var rankings: Array[Dictionary] = []
	var ranked_players := {}
	for ranking_variant in ranking_values as Array:
		if not (ranking_variant is Dictionary):
			return {}
		var ranking := ranking_variant as Dictionary
		var player_index := int(ranking.get("player_index", -1))
		if player_index < 0 or ranked_players.has(player_index):
			return {}
		ranked_players[player_index] = true
		rankings.append({
			"player_index": player_index,
			"top_k_gdp_per_minute_cents": int(ranking.get("top_k_gdp_per_minute_cents", 0)),
			"top_k_gdp_per_minute": int(ranking.get("top_k_gdp_per_minute", ranking.get("top_n_gdp_per_minute", 0))),
			"controlled_region_count": int(ranking.get("controlled_region_count", 0)),
			"winner": bool(ranking.get("winner", false)),
		})
	return {
		"outcome_id": outcome_id,
		"schema_version": schema_version,
		"ruleset_id": ruleset_id,
		"reason_code": reason_code,
		"winner_player_indices": winners,
		"co_victory": bool(outcome.get("co_victory", false)),
		"comparison_order": comparison_order,
		"rankings": rankings,
		"audit_evidence": audit_evidence,
	}


static func _normalized_outcome_audit_evidence(outcome: Dictionary) -> Dictionary:
	var evidence: Dictionary = outcome.get("audit_evidence", {}) \
		if outcome.get("audit_evidence", {}) is Dictionary else {}
	var victory_rule: Dictionary = evidence.get("victory_rule", {}) \
		if evidence.get("victory_rule", {}) is Dictionary else {}
	var roster_value: Variant = evidence.get("audit_roster", null)
	var roster_values: Array = roster_value if roster_value is Array else []
	var checkpoint_value: Variant = evidence.get("settlement_checkpoint", null)
	var settlement_checkpoint := str(checkpoint_value).strip_edges()
	if victory_rule.is_empty() or not (roster_value is Array) \
			or not (typeof(checkpoint_value) in [TYPE_STRING, TYPE_STRING_NAME]):
		return {}
	var audit_roster: Array[int] = []
	for value in roster_values:
		if typeof(value) != TYPE_INT or int(value) < 0 or audit_roster.has(int(value)):
			return {}
		audit_roster.append(int(value))
	return {
		"victory_rule": {
			"surviving_region_count": int(victory_rule.get("surviving_region_count", 0)),
			"coverage_basis_points": int(victory_rule.get("coverage_basis_points", 0)),
			"required_region_count": int(victory_rule.get("required_region_count", 0)),
			"gdp_per_required_region_per_minute": int(victory_rule.get("gdp_per_required_region_per_minute", 0)),
			"required_top_k_gdp_per_minute": int(victory_rule.get("required_top_k_gdp_per_minute", 0)),
			"required_top_k_gdp_per_minute_cents": int(victory_rule.get("required_top_k_gdp_per_minute_cents", 0)),
			"ordinary_victory_paused": bool(victory_rule.get("ordinary_victory_paused", false)),
		},
		"audit_roster": audit_roster,
		"settlement_checkpoint": settlement_checkpoint,
	}


static func _timer_step_matches(previous: Dictionary, current: Dictionary, remaining_key: String) -> bool:
	var world_delta_us := int(current.get("world_effective_us", -1)) - int(previous.get("world_effective_us", -1))
	var remaining_delta_us := int(previous.get(remaining_key, -1)) - int(current.get(remaining_key, -1))
	var max_step_us := int(round(AUTHORITATIVE_WAIT_STEP_SECONDS * 1_000_000.0))
	return str(previous.get("state", "")) == str(current.get("state", "")) \
		and world_delta_us > 0 and world_delta_us <= max_step_us \
		and remaining_delta_us > 0 \
		and abs(remaining_delta_us - world_delta_us) <= TIMER_DELTA_TOLERANCE_US


static func _timer_transition_matches(previous: Dictionary, current: Dictionary, remaining_key: String) -> bool:
	var world_delta_us := int(current.get("world_effective_us", -1)) - int(previous.get("world_effective_us", -1))
	var remaining_us := int(previous.get(remaining_key, -1))
	var max_step_us := int(round(AUTHORITATIVE_WAIT_STEP_SECONDS * 1_000_000.0))
	return remaining_us > 0 \
		and world_delta_us > 0 and world_delta_us <= max_step_us \
		and world_delta_us + TIMER_DELTA_TOLERANCE_US >= remaining_us


static func _timer_evidence_failure(result: Dictionary, reason_id: String) -> Dictionary:
	result["verified"] = false
	result["reason_id"] = reason_id
	return result


func _victory_transition_sequence_complete() -> bool:
	var qualification_index := _victory_state_sequence.find("qualification")
	var audit_index := _victory_state_sequence.find("audit", qualification_index + 1) if qualification_index >= 0 else -1
	var resolved_index := _victory_state_sequence.find("resolved", audit_index + 1) if audit_index >= 0 else -1
	return qualification_index >= 0 and audit_index > qualification_index and resolved_index > audit_index


func _verify_terminal_quiescence(
	baseline_telemetry: Dictionary,
	coordinator: Node,
	runtime_loop: RuntimeLoop,
	session: Node,
	settlement_composition: Node,
	standings_query_port: StandingsPublicQueryPort,
	runtime_screen: Node,
	run_started_msec: int
) -> Dictionary:
	Engine.time_scale = ACTION_ENGINE_TIME_SCALE
	var baseline_probe := _terminal_runtime_probe(coordinator, runtime_loop, session, settlement_composition)
	var baseline_stable: Dictionary = baseline_probe.get("stable", {}) \
		if baseline_probe.get("stable", {}) is Dictionary else {}
	var reason_id := "terminal_quiescence_verified"
	var verified := _terminal_baseline_valid(baseline_stable)
	if not verified:
		reason_id = "terminal_baseline_invalid"
	elif not _rng_checkpoint_matches(
		_rng_checkpoints.get("terminal", {}) as Dictionary \
			if _rng_checkpoints.get("terminal", {}) is Dictionary else {},
		baseline_stable.get("rng", {}) as Dictionary \
			if baseline_stable.get("rng", {}) is Dictionary else {}
	):
		verified = false
		reason_id = "terminal_rng_checkpoint_mismatch"
	var passed_frames := 0
	var expected_frame_index := int((baseline_probe.get("frame", {}) as Dictionary).get("frame_index", -1)) \
		if baseline_probe.get("frame", {}) is Dictionary else -1
	for _frame_index in range(TERMINAL_QUIESCENCE_FRAME_COUNT):
		if not verified:
			break
		await process_frame
		var probe := _terminal_runtime_probe(coordinator, runtime_loop, session, settlement_composition)
		var stable: Dictionary = probe.get("stable", {}) if probe.get("stable", {}) is Dictionary else {}
		var frame: Dictionary = probe.get("frame", {}) if probe.get("frame", {}) is Dictionary else {}
		expected_frame_index += 1
		if not _terminal_finished_frame_valid(frame, expected_frame_index):
			verified = false
			reason_id = "terminal_runtime_frame_not_quiescent"
			break
		if stable != baseline_stable:
			verified = false
			reason_id = "terminal_state_changed_during_quiescence"
			break
		passed_frames += 1
	if verified:
		_record_rng_checkpoint("terminal_quiescent", coordinator)
	var rng_evidence := rng_quiescence_evidence(_rng_checkpoints)
	if verified and not bool(rng_evidence.get("verified", false)):
		verified = false
		reason_id = str(rng_evidence.get("reason_id", "terminal_rng_delta_nonzero"))
	_terminal_quiescence = {
		"verified": verified,
		"frame_count": passed_frames,
		"fingerprint": JSON.stringify(baseline_stable).sha256_text() if verified else "",
		"reason_id": reason_id,
		"rng_verified": bool(rng_evidence.get("verified", false)),
		"rng_draw_delta": int(rng_evidence.get("draw_delta", -1)),
	}
	var after_telemetry := _collect_telemetry(
		int(baseline_telemetry.get("seed", 0)),
		coordinator,
		session,
		settlement_composition,
		standings_query_port,
		runtime_screen,
		run_started_msec,
		reason_id,
		{}
	)
	return {
		"verified": verified,
		"reason_id": reason_id,
		"telemetry": after_telemetry,
	}


func _terminal_runtime_probe(coordinator: Node, runtime_loop: RuntimeLoop, session: Node, settlement_composition: Node) -> Dictionary:
	var clock: Dictionary = coordinator.call("world_effective_clock_snapshot") \
		if coordinator != null and coordinator.has_method("world_effective_clock_snapshot") else {}
	var victory: Dictionary = coordinator.call("victory_control_public_snapshot", -1) \
		if coordinator != null and coordinator.has_method("victory_control_public_snapshot") else {}
	var outcome: Dictionary = victory.get("outcome_receipt", {}) if victory.get("outcome_receipt", {}) is Dictionary else {}
	var session_summary := _session_summary(session)
	var session_outcome: Dictionary = session_summary.get("outcome_receipt", {}) \
		if session_summary.get("outcome_receipt", {}) is Dictionary else {}
	var outcome_identity := outcome_identity_evidence(outcome, session_outcome)
	var settlement_debug: Dictionary = settlement_composition.call("debug_snapshot") \
		if settlement_composition != null and settlement_composition.has_method("debug_snapshot") else {}
	var sale_receipt := _public_sale_receipt_observation(coordinator)
	var final_log := _public_final_settlement_log_observation(coordinator, str(outcome.get("outcome_id", "")))
	var timer_evidence := timer_traversal_evidence(
		_victory_timer_trace,
		_first_sale_observation,
		_authorized_timer_contract,
		_authorized_timer_contract_error,
		_victory_timer_trace_overflow
	)
	var public_world_fingerprint := _public_world_fingerprint(coordinator)
	var runtime_debug := runtime_loop.debug_snapshot() if runtime_loop != null else {}
	var last_receipt: Dictionary = runtime_debug.get("last_frame_receipt", {}) \
		if runtime_debug.get("last_frame_receipt", {}) is Dictionary else {}
	var winner_count := (outcome.get("winner_player_indices", []) as Array).size() \
		if outcome.get("winner_player_indices", []) is Array else 0
	return {
		"stable": {
			"session_state": str(session_summary.get("session_state", "unavailable")),
			"world_effective_us": int(clock.get("world_effective_us", -1)),
			"public_world_fingerprint": public_world_fingerprint,
			"victory_state": str(victory.get("state", "")),
			"victory_visibility_scope": str(victory.get("visibility_scope", "")),
			"victory_settlement_checkpoint": str(victory.get("settlement_checkpoint", "")),
			"victory_public_fingerprint": JSON.stringify(victory).sha256_text(),
			"outcome_id": str(outcome.get("outcome_id", "")),
			"session_outcome_id": str(outcome_identity.get("session_outcome_id", "")),
			"outcome_identity_matches": bool(outcome_identity.get("verified", false)),
			"public_outcome_identity_fingerprint": str(outcome_identity.get("public_fingerprint", "")),
			"session_outcome_identity_fingerprint": str(outcome_identity.get("session_fingerprint", "")),
			"outcome_reason_code": str(outcome.get("reason_code", "")),
			"winner_count": winner_count,
			"present_count": int(settlement_debug.get("present_count", 0)),
			"presented_outcome_count": int(settlement_debug.get("presented_outcome_count", 0)),
			"logged_outcome_count": int(settlement_debug.get("logged_outcome_count", 0)),
			"last_presented_outcome_id": str(settlement_debug.get("last_presented_outcome_id", "")),
			"settlement_snapshot_fingerprint": str(settlement_debug.get("last_public_snapshot_fingerprint", "")),
			"settlement_action_emission_count": int(settlement_debug.get("action_emission_count", 0)),
			"final_public_log": final_log,
			"sale_receipt": sale_receipt,
			"timer_evidence": timer_evidence,
			"actions": _action_stats.duplicate(true),
			"peak_production_installation_count": _peak_production_installation_count,
			"rng": _capture_rng_checkpoint(coordinator),
		},
		"frame": {
			"frame_index": int(last_receipt.get("frame_index", -1)),
			"path": str(last_receipt.get("path", "")),
			"stopped_reason": str(last_receipt.get("stopped_reason", "")),
			"world_delta": float(last_receipt.get("world_delta", -1.0)),
			"phase_trace": (last_receipt.get("phase_trace", []) as Array).duplicate() \
				if last_receipt.get("phase_trace", []) is Array else [],
		},
	}


static func _terminal_baseline_valid(stable: Dictionary) -> bool:
	var final_log: Dictionary = stable.get("final_public_log", {}) if stable.get("final_public_log", {}) is Dictionary else {}
	var sale_receipt: Dictionary = stable.get("sale_receipt", {}) if stable.get("sale_receipt", {}) is Dictionary else {}
	var timer_evidence: Dictionary = stable.get("timer_evidence", {}) if stable.get("timer_evidence", {}) is Dictionary else {}
	var rng: Dictionary = stable.get("rng", {}) if stable.get("rng", {}) is Dictionary else {}
	return str(stable.get("session_state", "")) == "finished" \
		and int(stable.get("world_effective_us", -1)) >= 0 \
		and str(stable.get("public_world_fingerprint", "")).length() == 64 \
		and str(stable.get("victory_state", "")) == "resolved" \
		and str(stable.get("victory_visibility_scope", "")) == "public" \
		and str(stable.get("victory_settlement_checkpoint", "")) == "post_world_settlement" \
		and not str(stable.get("outcome_id", "")).is_empty() \
		and str(stable.get("session_outcome_id", "")) == str(stable.get("outcome_id", "")) \
		and bool(stable.get("outcome_identity_matches", false)) \
		and str(stable.get("public_outcome_identity_fingerprint", "")).length() == 64 \
		and str(stable.get("public_outcome_identity_fingerprint", "")) \
			== str(stable.get("session_outcome_identity_fingerprint", "")) \
		and str(stable.get("outcome_reason_code", "")) == "public_audit_complete" \
		and int(stable.get("winner_count", 0)) > 0 \
		and int(stable.get("peak_production_installation_count", 0)) >= TARGET_PRODUCTION_INSTALLATION_COUNT \
		and int(stable.get("present_count", 0)) == 1 \
		and int(stable.get("presented_outcome_count", 0)) == 1 \
		and int(stable.get("logged_outcome_count", 0)) == 1 \
		and str(stable.get("last_presented_outcome_id", "")) == str(stable.get("outcome_id", "")) \
		and str(stable.get("settlement_snapshot_fingerprint", "")).length() == 64 \
		and int(final_log.get("public_entry_count", 0)) == 1 \
		and str(final_log.get("outcome_id", "")) == str(stable.get("outcome_id", "")) \
		and str(final_log.get("public_fingerprint", "")).length() == 64 \
		and bool(sale_receipt.get("observed", false)) \
		and int(sale_receipt.get("public_event_count", 0)) > 0 \
		and str(sale_receipt.get("public_fingerprint", "")).length() == 64 \
		and bool(timer_evidence.get("verified", false)) \
		and bool(timer_evidence.get("sale_before_qualification", false)) \
		and int(rng.get("draw_count", -1)) >= 0 \
		and str(rng.get("checkpoint_fingerprint", "")).length() == 64


static func _terminal_finished_frame_valid(frame: Dictionary, expected_frame_index: int) -> bool:
	var phase_trace: Array = frame.get("phase_trace", []) if frame.get("phase_trace", []) is Array else []
	return int(frame.get("frame_index", -1)) == expected_frame_index \
		and str(frame.get("path", "")) == "finished" \
		and str(frame.get("stopped_reason", "")) == "session_finished" \
		and is_zero_approx(float(frame.get("world_delta", -1.0))) \
		and phase_trace.size() == 1 \
		and str(phase_trace[0]) == "lifecycle_begin"


func _public_world_fingerprint(coordinator: Node) -> String:
	if not (coordinator is GameRuntimeCoordinator):
		return ""
	var projection := (coordinator as GameRuntimeCoordinator).presentation_public_world_projection()
	if projection == null:
		return ""
	var public_world := projection.to_dictionary()
	if public_world.is_empty() or str(public_world.get("visibility_scope", "")) != "public":
		return ""
	return JSON.stringify(public_world).sha256_text()


func _save_status(capability: Dictionary) -> Dictionary:
	var ready := bool(capability.get("resume_ready", false))
	return {
		"supported": ready,
		"attempted": false,
		"reason_code": "not_requested" if ready else "restore_capability_incomplete",
	}


func _emit_heartbeat(seed_index: int, telemetry: Dictionary, status: String) -> void:
	_heartbeat_sequence += 1
	var payload := telemetry.duplicate(true)
	payload["type"] = "heartbeat"
	payload["driver"] = DRIVER_ID
	payload["run_id"] = "seed-%02d" % seed_index
	payload["seed_index"] = seed_index
	payload["seq"] = _heartbeat_sequence
	payload["status"] = status
	_emit_ndjson(payload)


func _emit_summary(summary: Dictionary) -> void:
	_emit_ndjson(summary)


func _emit_ndjson(payload: Dictionary) -> void:
	print(JSON.stringify(payload))


static func parse_command_line_options(user_arguments: PackedStringArray, engine_arguments: PackedStringArray) -> Dictionary:
	var legacy_arguments := _legacy_engine_driver_arguments(engine_arguments)
	if user_arguments.is_empty():
		return _parse_options(legacy_arguments)
	var result := _parse_options(user_arguments)
	if not legacy_arguments.is_empty():
		result["valid"] = false
	return result


static func _parse_options(arguments: PackedStringArray) -> Dictionary:
	var result := {
		"valid": true,
		"preflight_only": false,
		"seed_index": 0,
		"observation_seconds": DEFAULT_OBSERVATION_SECONDS,
		"max_wall_seconds": DEFAULT_MAX_WALL_SECONDS,
	}
	var seen_options := {}
	var index := 0
	while index < arguments.size():
		var argument := str(arguments[index])
		if argument == "--preflight-only":
			var accepted := _claim_option(seen_options, "preflight_only")
			result["preflight_only"] = true
			result["valid"] = bool(result.get("valid", true)) and accepted
		elif argument.begins_with("--seed-index="):
			var accepted := _claim_option(seen_options, "seed_index")
			if accepted:
				accepted = _assign_integer_option(result, "seed_index", argument.trim_prefix("--seed-index="), 0, FIXED_SEEDS.size() - 1)
			result["valid"] = bool(result.get("valid", true)) and accepted
		elif argument == "--seed-index":
			var accepted := _claim_option(seen_options, "seed_index")
			index += 1
			if index >= arguments.size():
				accepted = false
			elif accepted:
				accepted = _assign_integer_option(result, "seed_index", str(arguments[index]), 0, FIXED_SEEDS.size() - 1)
			result["valid"] = bool(result.get("valid", true)) and accepted
		elif argument.begins_with("--observation-seconds="):
			var accepted := _claim_option(seen_options, "observation_seconds")
			if accepted:
				accepted = _assign_integer_option(result, "observation_seconds", argument.trim_prefix("--observation-seconds="), 1, 3600)
			result["valid"] = bool(result.get("valid", true)) and accepted
		elif argument == "--observation-seconds":
			var accepted := _claim_option(seen_options, "observation_seconds")
			index += 1
			if index >= arguments.size():
				accepted = false
			elif accepted:
				accepted = _assign_integer_option(result, "observation_seconds", str(arguments[index]), 1, 3600)
			result["valid"] = bool(result.get("valid", true)) and accepted
		elif argument.begins_with("--max-wall-seconds="):
			var accepted := _claim_option(seen_options, "max_wall_seconds")
			if accepted:
				accepted = _assign_integer_option(result, "max_wall_seconds", argument.trim_prefix("--max-wall-seconds="), 1, 86400)
			result["valid"] = bool(result.get("valid", true)) and accepted
		elif argument == "--max-wall-seconds":
			var accepted := _claim_option(seen_options, "max_wall_seconds")
			index += 1
			if index >= arguments.size():
				accepted = false
			elif accepted:
				accepted = _assign_integer_option(result, "max_wall_seconds", str(arguments[index]), 1, 86400)
			result["valid"] = bool(result.get("valid", true)) and accepted
		else:
			result["valid"] = false
		index += 1
	if int(result.get("observation_seconds", 1)) >= int(result.get("max_wall_seconds", 1)):
		result["valid"] = false
	return result


static func _legacy_engine_driver_arguments(arguments: PackedStringArray) -> PackedStringArray:
	var result := PackedStringArray()
	var index := 0
	while index < arguments.size():
		var argument := str(arguments[index])
		if argument == "--preflight-only" or argument.begins_with("--seed-index=") or argument.begins_with("--observation-seconds=") or argument.begins_with("--max-wall-seconds="):
			result.append(argument)
		elif argument in ["--seed-index", "--observation-seconds", "--max-wall-seconds"]:
			result.append(argument)
			if index + 1 < arguments.size():
				index += 1
				result.append(str(arguments[index]))
		elif _has_reserved_driver_prefix(argument):
			result.append(argument)
		index += 1
	return result


static func _has_reserved_driver_prefix(argument: String) -> bool:
	return argument.begins_with("--preflight-only") \
		or argument.begins_with("--seed-index") \
		or argument.begins_with("--observation-seconds") \
		or argument.begins_with("--max-wall-seconds")


static func _claim_option(seen_options: Dictionary, key: String) -> bool:
	if seen_options.has(key):
		return false
	seen_options[key] = true
	return true


static func _assign_integer_option(target: Dictionary, key: String, text: String, minimum: int, maximum: int) -> bool:
	if not text.is_valid_int():
		return false
	var value := text.to_int()
	if value < minimum or value > maximum:
		return false
	target[key] = value
	return true


func _record_reason(reason_code: String) -> void:
	var reasons: Dictionary = _action_stats.get("reason_codes", {}) if _action_stats.get("reason_codes", {}) is Dictionary else {}
	reasons[reason_code] = int(reasons.get(reason_code, 0)) + 1
	_action_stats["reason_codes"] = reasons


func _last_reason_code() -> String:
	var reasons: Dictionary = _action_stats.get("reason_codes", {}) if _action_stats.get("reason_codes", {}) is Dictionary else {}
	if reasons.is_empty():
		return ""
	var keys := reasons.keys()
	keys.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
	return str(keys[-1])


func _cleanup_main(main_instance: Node, save_coordinator: Node) -> void:
	Engine.time_scale = 1.0
	if save_coordinator != null and save_coordinator.has_method("clear_qa_default_save_path_override"):
		save_coordinator.call("clear_qa_default_save_path_override")
	if main_instance == null:
		return
	if main_instance.get_parent() != null:
		main_instance.get_parent().remove_child(main_instance)
	main_instance.free()


func _wait_frames(count: int) -> void:
	for _index in range(maxi(0, count)):
		await process_frame


func _elapsed_seconds() -> float:
	return maxf(0.0, float(Time.get_ticks_msec() - _started_msec) / 1000.0)


func _head_token() -> String:
	var configured := OS.get_environment("SPACE_SYNDICATE_GIT_HEAD").strip_edges()
	return _safe_path_segment(configured if not configured.is_empty() else "local")


static func qa_save_directory(head: String, run_seed: int) -> String:
	return "%s%s/%d/" % [QA_SAVE_ROOT, _safe_path_segment(head), run_seed]


static func observation_action_policy(
	observation_started_msec: int,
	observation_limit_msec: int,
	now_msec: int,
	pending_action: Dictionary
) -> StringName:
	if now_msec - observation_started_msec < maxi(0, observation_limit_msec):
		return OBSERVATION_ACTION_OPEN
	return OBSERVATION_ACTION_DRAIN if not pending_action.is_empty() else OBSERVATION_ACTION_CLOSED


static func blocked_realtime_wait_policy(
	pending_action: Dictionary,
	current_decision: Dictionary,
	wager_receipt: Dictionary,
	session_state: String
) -> bool:
	if session_state != "running" \
			or str(pending_action.get("origin", "")) != "temporary_decision" \
			or str(pending_action.get("decision_kind", "")) != "monster_wager":
		return false
	var decision_id := str(pending_action.get("decision_id", ""))
	var decision_revision := int(pending_action.get("decision_revision", 0))
	if decision_id.is_empty() or decision_revision <= 0 \
			or str(current_decision.get("decision_id", "")) != decision_id \
			or str(current_decision.get("decision_kind", "")) != "monster_wager" \
			or int(current_decision.get("decision_revision", 0)) != decision_revision \
			or not bool(current_decision.get("blocks_global_time", false)) \
			or not bool(current_decision.get("visible_to_viewer", false)):
		return false
	if int(wager_receipt.get("sequence", 0)) <= int(pending_action.get("wager_receipt_sequence", 0)) \
			or int(wager_receipt.get("schema_version", 0)) != MonsterWagerResponseReceipt.SCHEMA_VERSION \
			or not bool(wager_receipt.get("accepted", false)) \
			or not bool(wager_receipt.get("applied", false)) \
			or bool(wager_receipt.get("decision_closed", false)) \
			or str(wager_receipt.get("decision_id", "")) != decision_id \
			or int(wager_receipt.get("decision_revision", 0)) != decision_revision \
			or int(wager_receipt.get("viewer_index", -1)) != SCRIPTED_PLAYER_INDEX \
			or int(wager_receipt.get("player_index", -1)) != SCRIPTED_PLAYER_INDEX \
			or str(wager_receipt.get("visibility_scope", "")) != "viewer_private" \
			or str(wager_receipt.get("receipt_fingerprint", "")).length() != 64:
		return false
	var receipt_body := wager_receipt.duplicate(true)
	var provided_fingerprint := str(receipt_body.get("receipt_fingerprint", ""))
	receipt_body.erase("receipt_fingerprint")
	if JSON.stringify(receipt_body).sha256_text() != provided_fingerprint:
		return false
	return true


static func _forced_decision_binding(decision: Dictionary) -> Dictionary:
	var decision_id := str(decision.get("id", "")).strip_edges()
	var decision_kind := str(decision.get("kind", "")).strip_edges()
	var decision_revision := int(decision.get("decision_revision", 0))
	if decision_id.is_empty() or decision_kind.is_empty() or decision_revision <= 0:
		return {}
	var result := {
		"decision_id": decision_id,
		"decision_kind": decision_kind,
		"decision_revision": decision_revision,
		"blocks_global_time": bool(decision.get("blocks_global_time", false)),
		"visible_to_viewer": bool(decision.get("visible_to_viewer", false)),
	}
	result["binding_fingerprint"] = JSON.stringify(result).sha256_text()
	return result


static func public_output_contract() -> Dictionary:
	return {
		"summary_keys": SUMMARY_PUBLIC_KEYS.duplicate(),
		"capability_keys": CAPABILITY_PUBLIC_KEYS.duplicate(),
		"telemetry": FullRunQualitySnapshotScript.public_contract(),
		"heartbeat_interval_seconds": HEARTBEAT_INTERVAL_SECONDS,
		"single_run_only": true,
	}


static func _safe_path_segment(value: String) -> String:
	var result := ""
	for index in range(value.length()):
		var code := value.unicode_at(index)
		var allowed := (code >= 48 and code <= 57) \
			or (code >= 65 and code <= 90) \
			or (code >= 97 and code <= 122) \
			or code in [45, 95]
		result += String.chr(code) if allowed else "_"
	result = result.strip_edges().trim_prefix("_").trim_suffix("_")
	return result.substr(0, 64) if not result.is_empty() else "local"
