extends SceneTree

const FullRunQualitySnapshotScript := preload("res://scripts/viewmodels/full_run_quality_snapshot.gd")
const AuthoritativeRuntimeStepperScript := preload("res://scripts/tools/full_run_authoritative_runtime_stepper.gd")
const EconomyContinuationPlannerScript := preload("res://scripts/tools/full_run_economy_continuation_planner.gd")
const PublicEconomyContinuationObservationScript := preload("res://scripts/viewmodels/public_economy_continuation_observation_v1.gd")

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
const HEARTBEAT_INTERVAL_SECONDS := 2.0
const TELEMETRY_REFRESH_INTERVAL_MSEC := 100
const ACTION_PROGRESS_TIMEOUT_SECONDS := 3.0
const NO_ACTION_TIMEOUT_SECONDS := 1.5
const DEFAULT_OBSERVATION_SECONDS := 12
const DEFAULT_MAX_WALL_SECONDS := 30
const MAX_WALL_SECONDS_LIMIT := 180
const OBSERVATION_ACTION_OPEN := &"open"
const OBSERVATION_ACTION_DRAIN := &"drain"
const OBSERVATION_ACTION_CLOSED := &"closed"
# Keep every authoritative frame at human-scale time. The driver probes typed
# actions after every complete RuntimeLoop step so a newly opened decision never
# inherits extra world, AI, market, or RNG advancement from a hidden batch.
const ACTION_ENGINE_TIME_SCALE := 1.0
const AUTHORITATIVE_WAIT_STEP_SECONDS := 1.0
const AUTHORITATIVE_WAIT_STEPS_PER_RENDER_FRAME := 1
const AUTHORITATIVE_WAIT_BASE_STEP_LIMIT := 360
const AUTHORITATIVE_WAIT_MAX_STEP_LIMIT := 480
const AUTHORITATIVE_PROGRESS_STALL_WINDOW_STEPS := 90
const AUTHORITATIVE_WORLD_EFFECTIVE_TIME_LIMIT_SECONDS := 420.0
const AUTHORITATIVE_ZERO_WORLD_STEP_LIMIT := 3
const AUTHORITATIVE_TERMINAL_TIMER_STALL_STEP_LIMIT := 3
const PROGRESS_CHECKPOINT_INTERVAL_STEPS := 30
const PRODUCTION_MATURITY_WORLD_SECONDS := 30.0
const PRODUCTION_MATURITY_SALE_RECEIPT_COUNT := 2
const BLOCKED_REALTIME_TOTAL_STEP_LIMIT := 360
const TIMER_TRACE_SAMPLE_LIMIT := 512
const TIMER_DELTA_TOLERANCE_US := 8
const TERMINAL_QUIESCENCE_FRAME_COUNT := 8
const SUPPLY_QUOTE_REFRESH_INTERVAL_MSEC := 250
const SUPPLY_QUOTE_REFRESH_ATTEMPTS_PER_RACK := 1
const SUPPLY_RACK_ROTATION_LIMIT := 8
const SUPPLY_RESCAN_WORLD_SECONDS := 15.0
const SUPPLY_EVALUATED_RACK_SIGNATURE_LIMIT := 64
const SUPPLY_FACILITY_RACK_HINT_LIMIT := 64
const FACILITY_CANDIDATE_ATTEMPT_LIMIT := 128
const SUPPLY_RACK_ADVANCEMENT_PURCHASE_LIMIT := SUPPLY_RACK_ROTATION_LIMIT
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
const PROGRESS_CHECKPOINT_PUBLIC_KEYS := [
	"type",
	"schema",
	"driver",
	"run_id",
	"step",
	"world_time",
	"facilities",
	"production",
	"demand",
	"transport",
	"waste",
	"sale_receipts",
	"top_k_gdp",
	"victory_state",
	"last_successful_action",
	"steps_since_progress",
	"rng_draw_count",
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
	"economy_continuation",
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
	"game_action_receipt_ready",
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
var _game_action_receipt_sequence := 0
var _last_game_action_receipt: Dictionary = {}
var _monster_wager_receipt_sequence := 0
var _last_monster_wager_receipt: Dictionary = {}
var _current_forced_decision_binding: Dictionary = {}
var _runtime_simulation_timing: Dictionary = {}
var _district_supply_query_port: DistrictSupplyViewerQueryPort
var _table_presentation_query_ports: TablePresentationQueryPorts
var _game_action_application_flow: TablePlayerActionApplicationFlowController
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
var _authoritative_last_progress_step := 0
var _authoritative_last_progress_reason := "session_started"
var _authoritative_progress_high_water := {
	"production_installation_count": 0,
	"sale_receipt_revision": 0,
	"top_k_gdp_per_minute": 0,
	"controlled_region_count": 0,
	"eligible": false,
	"victory_state_rank": 0,
}
var _authoritative_zero_world_step_count := 0
var _authoritative_terminal_timer_stall_count := 0
var _authoritative_last_terminal_timer_sample: Dictionary = {}
var _authoritative_progress_checkpoints: Array[Dictionary] = []
var _next_progress_checkpoint_step := PROGRESS_CHECKPOINT_INTERVAL_STEPS
var _last_successful_action_id := ""
var _production_maturity_checkpoint: Dictionary = {}
var _latest_public_world_seconds := 0.0
var _latest_economy_continuation_observation: Dictionary = {}
var _latest_economy_continuation_plan: Dictionary = {}
var _matched_economy_chain_evidence := {
	"observed": false,
	"matched_commodity_count": 0,
	"settled_matched_commodity_count": 0,
	"fingerprint": "",
}
var _economy_plan_override_signature := ""
var _exhausted_economy_plan_signatures := {}
var _rack_advancement_purchase_count := 0
var _pending_rack_advancement_discard: Dictionary = {}
var _rack_advancement_reset_requested := false
var _eligibility_locked_production_installation_count := -1
var _post_eligibility_production_installation_delta := 0
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
	"supply_rack_advancement_purchases": 0,
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
	_game_action_application_flow = coordinator.get_node_or_null("TablePlayerActionApplicationFlowController") \
		as TablePlayerActionApplicationFlowController if coordinator != null else null
	_district_supply_query_port = coordinator.get_node_or_null("DistrictSupplyViewerQueryPort") as DistrictSupplyViewerQueryPort \
		if coordinator != null else null
	_table_presentation_query_ports = (coordinator as GameRuntimeCoordinator).table_presentation_query_ports() \
		if coordinator is GameRuntimeCoordinator else null
	if district_supply_port != null and not district_supply_port.receipt_ready.is_connected(_on_district_supply_action_receipt):
		district_supply_port.receipt_ready.connect(_on_district_supply_action_receipt)
	if table_selection_port != null and not table_selection_port.receipt_ready.is_connected(_on_table_selection_receipt):
		table_selection_port.receipt_ready.connect(_on_table_selection_receipt)
	if _game_action_application_flow != null \
			and not _game_action_application_flow.receipt_ready.is_connected(_on_game_action_receipt):
		_game_action_application_flow.receipt_ready.connect(_on_game_action_receipt)
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
	_observe_authoritative_progress(final_telemetry)
	var cached_ui_action := _scripted_ui_action(
		runtime_screen,
		exhausted_navigation_actions,
		final_telemetry.get("progress", {}) as Dictionary,
		supply_rotation_state,
		final_telemetry.get("sale_receipt", {}) as Dictionary,
		_latest_economy_continuation_plan
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
			_observe_authoritative_progress(final_telemetry)
			_emit_authoritative_progress_checkpoints(seed_index, final_telemetry, coordinator)
			last_telemetry_refresh_msec = now_msec
			public_progress = final_telemetry.get("progress", {}) as Dictionary
			sale_receipt = final_telemetry.get("sale_receipt", {}) as Dictionary
			cached_ui_action = _scripted_ui_action(
				runtime_screen,
				exhausted_navigation_actions,
				public_progress,
				supply_rotation_state,
				sale_receipt,
				_latest_economy_continuation_plan
			)
			ui_action = cached_ui_action
		var current_progress: Dictionary = final_telemetry.get("progress", {}) \
			if final_telemetry.get("progress", {}) is Dictionary else {}
		if _rack_advancement_reset_requested and pending_action.is_empty():
			supply_rotation_state = reset_supply_rotation_after_advancement(
				supply_rotation_state
			)
			_rack_advancement_reset_requested = false
			public_progress = current_progress
			ui_action = _scripted_ui_action(
				runtime_screen,
				exhausted_navigation_actions,
				public_progress,
				supply_rotation_state,
				sale_receipt,
				_latest_economy_continuation_plan
			)
			cached_ui_action = ui_action
			_last_event = "supply_rack_advancement_committed:%d" \
				% _rack_advancement_purchase_count
		var current_facility_count := int(current_progress.get("owned_facility_count", 0))
		if current_facility_count > observed_owned_facility_count:
			var preserved_facility_rack_hints: Dictionary = supply_rotation_state.get(
				"facility_rack_hints",
				{}
			) if supply_rotation_state.get("facility_rack_hints", {}) is Dictionary else {}
			observed_owned_facility_count = current_facility_count
			_exhausted_map_districts.clear()
			_facility_candidate_attempts.clear()
			_exhausted_economy_plan_signatures.clear()
			_economy_plan_override_signature = ""
			supply_rotation_state = _new_supply_rotation_state(
				{},
				"",
				preserved_facility_rack_hints
			)
			public_progress = current_progress
			ui_action = _scripted_ui_action(
				runtime_screen,
				exhausted_navigation_actions,
				public_progress,
				supply_rotation_state,
				sale_receipt,
				_latest_economy_continuation_plan
			)
			cached_ui_action = ui_action
			_last_event = "facility_progress_observed:%d" % current_facility_count
		elif str(supply_rotation_state.get("phase", "")) == "exhausted" and pending_action.is_empty():
			var current_world_seconds := float((final_telemetry.get("elapsed", {}) as Dictionary).get("world_seconds", 0.0)) \
				if final_telemetry.get("elapsed", {}) is Dictionary else 0.0
			var exhausted_world_seconds := float(supply_rotation_state.get("exhausted_world_seconds", -1.0))
			if exhausted_world_seconds < 0.0:
				supply_rotation_state["exhausted_world_seconds"] = current_world_seconds
			elif current_world_seconds - exhausted_world_seconds >= SUPPLY_RESCAN_WORLD_SECONDS:
				supply_rotation_state = _new_supply_rotation_state(
					supply_rotation_state.get("evaluated_rack_plan_signatures", {}) as Dictionary,
					str(supply_rotation_state.get("active_plan_signature", ""))
				)
				public_progress = current_progress
				ui_action = _scripted_ui_action(
					runtime_screen,
					exhausted_navigation_actions,
					public_progress,
					supply_rotation_state,
					sale_receipt,
					_latest_economy_continuation_plan
				)
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
			var current_world_seconds := float((final_telemetry.get("elapsed", {}) as Dictionary).get("world_seconds", 0.0)) \
				if final_telemetry.get("elapsed", {}) is Dictionary else 0.0
			var budget_decision := authoritative_progress_budget_decision(
				_authoritative_step_attempt_count,
				_authoritative_last_progress_step,
				current_world_seconds
			)
			if not bool(budget_decision.get("allowed", false)):
				final_status = "blocked"
				failure_code = str(budget_decision.get("reason_id", "authoritative_runtime_step_budget_exhausted"))
				_last_event = "blocked:%s" % failure_code
				break
			var remaining_steps := AUTHORITATIVE_WAIT_MAX_STEP_LIMIT - _authoritative_step_attempt_count
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
			var advanced_world_seconds := float(step_result.get("world_seconds", 0.0))
			_authoritative_step_world_seconds += advanced_world_seconds
			_authoritative_zero_world_step_count = 0 \
				if advanced_world_seconds > 0.0 else _authoritative_zero_world_step_count + 1
			_record_authoritative_timeline_from_public_snapshot(coordinator)
			_observe_terminal_timer_step_progress()
			last_telemetry_refresh_msec = 0
			_last_event = "authoritative_runtime_wait:%s" % str(step_result.get("reason_id", "unknown"))
			if not bool(step_result.get("accepted", false)):
				final_status = "blocked"
				failure_code = "authoritative_runtime_step_rejected:%s" % str(step_result.get("reason_id", "unknown"))
				_last_event = "blocked:%s" % failure_code
				break
			if _authoritative_zero_world_step_count >= AUTHORITATIVE_ZERO_WORLD_STEP_LIMIT:
				final_status = "blocked"
				failure_code = "authoritative_zero_world_step_stall"
				_last_event = "blocked:%s" % failure_code
				break
			if _authoritative_terminal_timer_stall_count >= AUTHORITATIVE_TERMINAL_TIMER_STALL_STEP_LIMIT:
				final_status = "blocked"
				failure_code = "authoritative_terminal_timer_stalled"
				_last_event = "blocked:%s" % failure_code
				break
			continue
		_leave_runtime_loop_manual_mode(runtime_loop)

		if not pending_action.is_empty():
			var pending_id := str(pending_action.get("id", ""))
			var pending_phase := str(pending_action.get("phase", ""))
			var game_action_required := bool(pending_action.get("game_action_required", false))
			var game_action_receipt_arrived := game_action_required \
				and _game_action_receipt_sequence \
					> int(pending_action.get("game_action_receipt_sequence", -1))
			var supply_receipt_arrived := str(pending_action.get("origin", "")) in ["district_supply", "district_supply_rotation"] \
				and _district_supply_receipt_sequence > int(pending_action.get("supply_receipt_sequence", -1))
			var selection_receipt_arrived := str(pending_action.get("origin", "")) == "planet_map" \
				and _table_selection_receipt_sequence > int(pending_action.get("selection_receipt_sequence", -1))
			if game_action_receipt_arrived and not bool(_last_game_action_receipt.get("accepted", false)) \
					and not supply_receipt_arrived and not selection_receipt_arrived:
				var game_action_reason := str(
					_last_game_action_receipt.get("reason_id", "game-action-rejected")
				).replace("-", "_")
				if game_action_reason == "source_revision_stale":
					_record_reason("game_action_source_revision_stale")
					_last_event = "retrying_game_action_receipt:%s" % game_action_reason
					pending_action = {}
					last_telemetry_refresh_msec = 0
					no_action_since_msec = now_msec
					continue
				_action_stats["rejected_invalid"] = int(_action_stats.get("rejected_invalid", 0)) + 1
				failure_code = "game_action_rejected:%s:%s" % [pending_id, game_action_reason]
				_record_reason("game_action_receipt_rejected")
				_last_event = "blocked_game_action_receipt:%s" % game_action_reason
				final_status = "blocked"
				break
			if supply_receipt_arrived \
					and bool(_last_district_supply_receipt.get("accepted", false)) \
					and bool(_last_district_supply_receipt.get("applied", false)) \
					and bool(_last_district_supply_receipt.get("requires_discard", false)) \
					and game_action_receipt_arrived \
				and bool(_last_game_action_receipt.get("accepted", false)):
				if bool(pending_action.get("rack_advancement", false)):
					var pending_discard_binding := {
						"actor_player_index": int(
							_last_district_supply_receipt.get("actor_player_index", -1)
						),
						"card_id": str(
							_last_district_supply_receipt.get(
								"card_id",
								pending_action.get("rack_advancement_card_id", "")
							)
						),
						"quote_id": str(
							_last_district_supply_receipt.get("quote_id", "")
						),
					}
					if int(pending_discard_binding.get("actor_player_index", -1)) >= 0 \
							and not str(pending_discard_binding.get("card_id", "")).is_empty() \
							and not str(pending_discard_binding.get("quote_id", "")).is_empty():
						_pending_rack_advancement_discard = pending_discard_binding
				_action_stats["progressed"] = int(_action_stats.get("progressed", 0)) + 1
				_record_reason("district_supply_pending_discard")
				_last_event = "action_progressed:district_supply_pending_discard"
				pending_action = {}
				last_telemetry_refresh_msec = 0
				no_action_since_msec = now_msec
				continue
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
					if bool(pending_action.get("rack_advancement", false)):
						advance_rack_advancement_after_retryable_failure(
							supply_rotation_state
						)
					elif receipt_reason in ["source_region_dark", "card_not_in_supply"] \
							and _begin_supply_rack_rotation(
								supply_rotation_state,
								_public_supply_wait_facts(runtime_screen, _latest_economy_continuation_plan)
							):
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
				var selection_reason := str(
					_last_table_selection_receipt.get("reason_code", "selection_rejected")
				)
				var retryable_selection := recoverable_selection_receipt_reason(selection_reason)
				if exhausted_district >= 0 and not retryable_selection:
					_exhausted_map_districts[exhausted_district] = true
				_record_reason(
					"map_selection_retryable_receipt" if retryable_selection \
					else "map_selection_typed_rejection"
				)
				_last_event = "map_target_rejected:%d:%s" % [
					exhausted_district,
					selection_reason,
				]
				pending_action = {}
				last_telemetry_refresh_msec = 0
				no_action_since_msec = now_msec
				continue
			if selection_receipt_arrived \
					and bool(_last_table_selection_receipt.get("accepted", false)) \
					and not bool(_last_table_selection_receipt.get("changed", false)):
				_record_reason("map_selection_unchanged")
				_last_event = "map_target_already_selected:%d" % int(
					pending_action.get("district_index", -1)
				)
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
			var game_action_progressed := game_action_receipt_confirms_progress(
				pending_action,
				_game_action_receipt_sequence,
				_last_game_action_receipt
			)
			var action_progressed := game_action_progressed if game_action_required else (
				supply_receipt_progressed \
				or selection_receipt_progressed \
				or str(ui_action.get("id", "")) != pending_id \
				or str(ui_action.get("phase", "")) != pending_phase
			)
			if action_progressed:
				_action_stats["progressed"] = int(_action_stats.get("progressed", 0)) + 1
				if rack_advancement_purchase_committed(
					pending_action,
					game_action_progressed,
					_last_game_action_receipt
				):
					_record_rack_advancement_purchase()
				if action_records_economic_success(
					pending_action,
					game_action_progressed,
					_last_game_action_receipt
				):
					_last_successful_action_id = _safe_progress_token(pending_id)
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
					sale_receipt,
					_latest_economy_continuation_plan
				)
				_last_event = "driver_planning_transition:%s" % action_id
				continue
			if not action_id.is_empty() and not bool(ui_action.get("disabled", false)):
				if economy_growth_action(ui_action) \
						and not _economy_growth_submission_allowed_now(
							coordinator,
							standings_query_port
						):
					_record_reason("victory_growth_submission_guard")
					_last_event = "growth_submission_cancelled:victory_lifecycle"
					cached_ui_action = {}
					last_telemetry_refresh_msec = 0
					continue
				var supply_receipt_sequence_before_submission := _district_supply_receipt_sequence
				var selection_receipt_sequence_before_submission := _table_selection_receipt_sequence
				var game_action_receipt_sequence_before_submission := _game_action_receipt_sequence
				var game_action_revision_before_submission := int(
					_last_game_action_receipt.get("authoritative_revision", 0)
				)
				var wager_receipt_sequence_before_submission := _monster_wager_receipt_sequence
				var forced_decision_binding_before_submission := _current_forced_decision_binding.duplicate(true)
				if not _submit_scripted_ui_action(runtime_screen, ui_action):
					_action_stats["attempted"] = int(_action_stats.get("attempted", 0)) + 1
					_action_stats["rejected_invalid"] = int(_action_stats.get("rejected_invalid", 0)) + 1
					failure_code = "scripted_ui_action_submission_rejected:%s:%s" % [
						action_id,
						_scripted_ui_action_rejection_reason(runtime_screen, ui_action),
					]
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
					"game_action_receipt_sequence": game_action_receipt_sequence_before_submission,
					"game_action_revision_before": game_action_revision_before_submission,
					"game_action_required": bool(ui_action.get("game_action_required", false)) \
						or ui_action.get("game_action_offer", {}) is Dictionary \
						and not (ui_action.get("game_action_offer", {}) as Dictionary).is_empty(),
					"game_action_request_id": str(_last_game_action_receipt.get("request_id", "")) \
						if _game_action_receipt_sequence > game_action_receipt_sequence_before_submission else "",
					"game_action_request_fingerprint": str(_last_game_action_receipt.get("request_fingerprint", "")) \
						if _game_action_receipt_sequence > game_action_receipt_sequence_before_submission else "",
					"game_action_semantic_action_id": str(
						(ui_action.get("game_action_offer", {}) as Dictionary).get("semantic_action_id", "")
					) if ui_action.get("game_action_offer", {}) is Dictionary else "",
					"wager_receipt_sequence": wager_receipt_sequence_before_submission,
					"decision_id": str(forced_decision_binding_before_submission.get("decision_id", "")),
					"decision_kind": str(forced_decision_binding_before_submission.get("decision_kind", "")),
					"decision_revision": int(forced_decision_binding_before_submission.get("decision_revision", 0)),
					"district_index": int(ui_action.get("district_index", -1)),
					"rack_advancement": bool(ui_action.get("rack_advancement", false)),
					"rack_advancement_card_id": str(
						ui_action.get("rack_advancement_card_id", "")
					),
				}
				no_action_since_msec = now_msec
			elif action_id in ["district_supply_wait", "facility_play_wait", "gdp_accumulation_wait"] and bool(ui_action.get("disabled", false)):
				if action_id == "district_supply_wait" and now_msec - last_supply_quote_refresh_msec >= SUPPLY_QUOTE_REFRESH_INTERVAL_MSEC:
					var wait_facts := _public_supply_wait_facts(
						runtime_screen,
						_latest_economy_continuation_plan
					)
					var rack_signature := str(wait_facts.get("rack_signature", ""))
					var attempts_by_signature: Dictionary = supply_rotation_state.get("refresh_attempts_by_signature", {}) \
						if supply_rotation_state.get("refresh_attempts_by_signature", {}) is Dictionary else {}
					var attempts := int(attempts_by_signature.get(rack_signature, 0))
					var exhausted_signatures: Dictionary = supply_rotation_state.get("exhausted_signatures", {}) \
						if supply_rotation_state.get("exhausted_signatures", {}) is Dictionary else {}
					var evaluated_signatures: Dictionary = supply_rotation_state.get("evaluated_rack_plan_signatures", {}) \
						if supply_rotation_state.get("evaluated_rack_plan_signatures", {}) is Dictionary else {}
					var rack_already_evaluated := bool(evaluated_signatures.get(rack_signature, false))
					if not rack_signature.is_empty() and (rack_already_evaluated \
							or not bool(wait_facts.get("has_visible_matching_facility", false)) \
							or not bool(wait_facts.get("has_visible_matching_target", false)) \
							or bool(exhausted_signatures.get(rack_signature, false)) \
							or attempts >= SUPPLY_QUOTE_REFRESH_ATTEMPTS_PER_RACK):
						exhausted_signatures[rack_signature] = true
						supply_rotation_state["exhausted_signatures"] = exhausted_signatures
						_remember_supply_rack_evaluation(supply_rotation_state, rack_signature)
						if _begin_supply_rack_rotation(supply_rotation_state, wait_facts):
							_action_stats["supply_rack_rotations"] = int(_action_stats.get("supply_rack_rotations", 0)) + 1
							_last_event = "supply_rack_rotation_started:%d" % int(supply_rotation_state.get("target_district", -1))
					elif not rack_signature.is_empty():
						exhausted_signatures[rack_signature] = true
						supply_rotation_state["exhausted_signatures"] = exhausted_signatures
						_remember_supply_rack_evaluation(supply_rotation_state, rack_signature)
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
	_observe_authoritative_progress(final_telemetry)
	_emit_authoritative_progress_checkpoints(seed_index, final_telemetry, coordinator)
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
		and runtime_screen.has_signal("game_action_intent_requested") \
		and runtime_screen.has_method("submit_game_action_offer") \
		and runtime_screen.has_method("game_action_actor_authorization") \
		and _temporary_decision_overlay(runtime_screen) != null
	var setup_ready := main_instance.get_node_or_null(SETUP_DRAFT_PATH) is NewGameSetupDraftService \
		and main_instance.get_node_or_null(SESSION_START_TRANSACTION_PATH) is SessionStartTransactionCoordinator
	var district_supply_query_ready := _district_supply_query_port != null \
		and _district_supply_query_port.has_method("snapshot_for_viewer")
	var facility_target_query_ready := _table_presentation_query_ports != null \
		and _table_presentation_query_ports.has_method("public_new_facility_target_candidates")
	var game_action_receipt_ready := _game_action_application_flow != null \
		and _game_action_application_flow.has_signal("receipt_ready") \
		and _game_action_application_flow.receipt_ready.is_connected(_on_game_action_receipt)
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
		and game_action_receipt_ready \
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
			"game_action_receipt_ready": game_action_receipt_ready,
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
	var continuation_progress := public_progress.duplicate(true)
	continuation_progress["victory_state"] = str(victory.get("state", "idle"))
	_latest_economy_continuation_observation = _public_economy_continuation_observation(
		coordinator,
		continuation_progress
	)
	var matched_chain_evidence := EconomyContinuationPlannerScript.matched_chain_evidence(
		_latest_economy_continuation_observation
	)
	if bool(matched_chain_evidence.get("observed", false)) \
			and (
				not bool(_matched_economy_chain_evidence.get("observed", false)) \
				or int(matched_chain_evidence.get("matched_commodity_count", 0)) \
					> int(_matched_economy_chain_evidence.get("matched_commodity_count", 0)) \
				or int(matched_chain_evidence.get("settled_matched_commodity_count", 0)) \
					> int(_matched_economy_chain_evidence.get("settled_matched_commodity_count", 0))
			):
		_matched_economy_chain_evidence = matched_chain_evidence.duplicate(true)
	_latest_economy_continuation_plan = _select_economy_continuation_plan(
		_latest_economy_continuation_observation
	)
	_peak_production_installation_count = maxi(
		_peak_production_installation_count,
		int(public_progress.get("production_installation_count", 0))
	)
	public_progress["peak_production_installation_count"] = _peak_production_installation_count
	var world_seconds := maxf(0.0, float(clock.get("world_effective_seconds", 0.0)))
	_latest_public_world_seconds = world_seconds
	_observe_production_maturity_checkpoint(public_progress, sale_receipt, world_seconds)
	var ui_action: Dictionary = (ui_action_override as Dictionary) if ui_action_override is Dictionary \
		else _scripted_ui_action(
			runtime_screen,
			{},
			public_progress,
			{},
			sale_receipt,
			_latest_economy_continuation_plan
		)
	var session_summary := _session_summary(session)
	var session_state := str(session_summary.get("session_state", "unavailable"))
	var outcome: Dictionary = victory.get("outcome_receipt", {}) if victory.get("outcome_receipt", {}) is Dictionary else {}
	var final_settlement_log := _public_final_settlement_log_observation(coordinator, str(outcome.get("outcome_id", "")))
	var settlement := _settlement_snapshot(victory, settlement_composition, session_summary, final_settlement_log, sale_receipt)
	var phase := _phase_for(session_state, victory, decision, ui_action, settlement)
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
		"terminal_world_delta": float(_terminal_quiescence.get("world_delta", -1.0)),
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
	sale_receipt: Dictionary = {},
	continuation_plan: Dictionary = {}
) -> Dictionary:
	_action_projection_count += 1
	if runtime_screen == null:
		return {"id": "", "phase": "play", "disabled": true}
	var ui_variant: Variant = runtime_screen.get("current_ui_data")
	var ui: Dictionary = ui_variant if ui_variant is Dictionary else {}
	var player_board: Dictionary = ui.get("player_board", {}) if ui.get("player_board", {}) is Dictionary else {}
	var player_card_dock: Dictionary = ui.get("player_card_dock", {}) if ui.get("player_card_dock", {}) is Dictionary else {}
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
	var menu_action := _menu_overlay_ui_action(runtime_screen)
	if not menu_action.is_empty():
		return menu_action
	var matched_chain_established := bool(_matched_economy_chain_evidence.get("observed", false))
	var own_victory_eligible := bool(public_progress.get("eligible", false))
	var victory_state := str(_victory_state_sequence[-1]) if not _victory_state_sequence.is_empty() else "idle"
	var victory_countdown_active := victory_state in ["qualification", "audit", "resolved"]
	# Victory owns the lifecycle before any economic continuation decision. A
	# rolling GDP dip must not reopen hand, rack, or strategy growth.
	if own_victory_eligible or victory_countdown_active:
		if str(supply_rotation_state.get("phase", "")) == "advancement_recheck":
			supply_rotation_state["phase"] = ""
			supply_rotation_state["advancement_epoch_active"] = false
		return {
			"id": "gdp_accumulation_wait",
			"phase": "play.victory_qualification",
			"disabled": true,
			"origin": "economic_wait",
		}
	var growth_progress := public_progress.duplicate(true)
	growth_progress["matched_economy_chain_observed"] = matched_chain_established
	var growth_policy := production_growth_policy(
		growth_progress,
		sale_receipt,
		_latest_public_world_seconds,
		_production_maturity_checkpoint,
		victory_state
	)
	var production_maturation_is_pending := str(growth_policy.get("reason_id", "")) == "production_maturation_pending"
	# Once a real production/demand pair exists, its first typed Sale Receipt is
	# the acceptance signal. Facility count is not a V0.6 Victory rule and cannot
	# delay an otherwise authoritative qualification lifecycle.
	if matched_chain_established and not bool(sale_receipt.get("observed", false)):
		return {
			"id": "gdp_accumulation_wait",
			"phase": "play.gdp_first_receipt",
			"disabled": true,
			"origin": "economic_wait",
		}
	if production_maturation_is_pending:
		return {
			"id": "gdp_accumulation_wait",
			"phase": "play.production_maturation",
			"disabled": true,
			"origin": "economic_wait",
		}
	var normalized_plan := continuation_plan.duplicate(true)
	if normalized_plan.is_empty():
		normalized_plan = _latest_economy_continuation_plan.duplicate(true)
	if not bool(normalized_plan.get("ready", false)):
		return {
			"id": "facility_play_wait",
			"phase": "play.economy_continuation.observation_unavailable",
			"disabled": true,
			"origin": "economic_wait",
		}
	if bool(normalized_plan.get("stop", false)):
		return {
			"id": "gdp_accumulation_wait",
			"phase": "play.gdp_accumulation.%s" % str(normalized_plan.get("reason_id", "no_complementary_growth_required")),
			"disabled": true,
			"origin": "economic_wait",
		}
	_sync_supply_rotation_plan(supply_rotation_state, normalized_plan)
	var hand_cards := _facility_cards_with_stable_identity(
		player_card_dock.get("normal_cards", []) if player_card_dock.get("normal_cards", []) is Array else []
	)
	var matching_hand_card := EconomyContinuationPlannerScript.first_matching_facility(
		hand_cards,
		normalized_plan,
		true
	)
	var facility_hand_action := _enabled_card_action_request(matching_hand_card)
	if not facility_hand_action.is_empty():
		return facility_hand_action
	for blocked_facility in matching_facility_cards(hand_cards, normalized_plan, false):
		if bool(blocked_facility.get("actionable", false)):
			continue
		var play_reason_id := str(blocked_facility.get("play_reason_id", "invalid_payload"))
		if play_reason_id in FACILITY_TARGET_RETRY_REASON_IDS:
			var target_retry := _next_typed_facility_map_action(
				runtime_screen,
				blocked_facility,
				normalized_plan,
				play_reason_id
			)
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
	var facility_hint_action := _facility_rack_hint_ui_action(
		runtime_screen,
		supply_rotation_state,
		normalized_plan
	)
	if not facility_hint_action.is_empty():
		return facility_hint_action
	var exhausted_visible_supply_action: Dictionary = {}
	var rotation_phase := str(supply_rotation_state.get("phase", ""))
	if rotation_phase in ["exhausted", "advancement_recheck"]:
		exhausted_visible_supply_action = _district_supply_ui_action(
			runtime_screen,
			normalized_plan
		)
		if not exhausted_visible_supply_action.is_empty() \
				and not bool(exhausted_visible_supply_action.get("disabled", false)):
			return exhausted_visible_supply_action
	if exhausted_matching_facility_wait_required(supply_rotation_state):
		return _supply_rotation_action(runtime_screen, supply_rotation_state)
	if rotation_phase == "exhausted":
		var visible_alternative_plan := _next_visible_economy_continuation_plan(
			supply_rotation_state,
			normalized_plan
		)
		if not visible_alternative_plan.is_empty():
			return {
				"id": "economy_plan_exhausted",
				"phase": "driver.economy_plan_exhausted.%s" \
					% str(normalized_plan.get("reason_id", "unknown")),
				"disabled": false,
				"origin": "driver_planning",
				"exhausted_plan_signature": continuation_plan_signature(
					normalized_plan
				),
				"next_plan": visible_alternative_plan,
			}
	# A rack may advance only after the complete public search is exhausted. Buy
	# one typed non-facility listing through the same quote/purchase Action Spine
	# used by a human; never consume an off-plan facility merely to reveal a slot.
	var advancement_allowed := rack_advancement_allowed(
		supply_rotation_state,
		_rack_advancement_purchase_count
	)
	var rack_advancement := _district_supply_advancement_ui_action(
		runtime_screen,
		supply_rotation_state
	) \
		if advancement_allowed else {}
	if advancement_allowed and rotation_phase == "advancement_recheck" \
			and _begin_supply_advancement_reposition(
				runtime_screen,
				supply_rotation_state
			):
		var recheck_reposition := _supply_rotation_action(
			runtime_screen,
			supply_rotation_state
		)
		if not recheck_reposition.is_empty():
			return recheck_reposition
	if not rack_advancement.is_empty():
		return rack_advancement
	if advancement_allowed and rotation_phase == "exhausted" \
			and _begin_supply_advancement_reposition(
				runtime_screen,
				supply_rotation_state
			):
		var exhausted_reposition := _supply_rotation_action(
			runtime_screen,
			supply_rotation_state
		)
		if not exhausted_reposition.is_empty():
			return exhausted_reposition
	if rotation_phase == "advancement_recheck":
		# The replacement slot was inspected and yielded neither a matching
		# facility nor another legal bounded purchase. The carried exhaustion
		# proof ends here; subsequent work must perform a new complete scan.
		supply_rotation_state["phase"] = ""
		supply_rotation_state["advancement_epoch_active"] = false
	# Finish an already-started bounded rotation only after the authorized hand
	# projection proves there is no matching facility waiting to be played.
	var supply_rotation_action := _supply_rotation_action(runtime_screen, supply_rotation_state)
	if not supply_rotation_action.is_empty():
		return supply_rotation_action
	var visible_supply_action := exhausted_visible_supply_action \
		if not exhausted_visible_supply_action.is_empty() \
		else _district_supply_ui_action(runtime_screen, normalized_plan)
	if not visible_supply_action.is_empty():
		return visible_supply_action
	# Strategy buttons may open the real player-facing rack, but never choose the
	# facility semantics. The complementary typed plan remains the sole selector.
	for strategy_kind in ["expand_economic_source", "build_economic_source"]:
		var strategy_action := _first_enabled_action_by_kind(player_board.get("actions", []), strategy_kind)
		if strategy_action.is_empty():
			continue
		var strategy_signature := "strategy:%s:%d" % [str(strategy_action.get("id", "strategy")), int(strategy_action.get("source_revision", 0))]
		if not bool(exhausted_navigation_actions.get(strategy_signature, false)):
			return _board_action_request(strategy_action, player_board, strategy_signature)
	if _begin_supply_rack_discovery(runtime_screen, supply_rotation_state):
		var discovery_action := _supply_rotation_action(runtime_screen, supply_rotation_state)
		if not discovery_action.is_empty():
			return discovery_action
	var map_action := _next_public_map_action(runtime_screen)
	if not map_action.is_empty():
		return map_action
	return {
		"id": "district_supply_wait",
		"phase": "play.economy_continuation.wait.%s" % str(normalized_plan.get("reason_id", "no_legal_matching_facility")),
		"disabled": true,
		"origin": "economic_wait",
	}


static func continuation_plan_signature(continuation_plan: Dictionary) -> String:
	return JSON.stringify({
		"ready": bool(continuation_plan.get("ready", false)),
		"stop": bool(continuation_plan.get("stop", true)),
		"reason_id": str(continuation_plan.get("reason_id", "")),
		"desired_facility_kind": str(continuation_plan.get("desired_facility_kind", "")),
		"desired_direction": str(continuation_plan.get("desired_direction", "")),
		"commodity_id": str(continuation_plan.get("commodity_id", "")),
		"industry_id": str(continuation_plan.get("industry_id", "")),
	}).sha256_text()


func _select_economy_continuation_plan(observation: Dictionary) -> Dictionary:
	var ranked: Array = EconomyContinuationPlannerScript.ranked_plans(observation)
	if ranked.is_empty():
		return {}
	if not _economy_plan_override_signature.is_empty():
		for plan_variant in ranked:
			if plan_variant is Dictionary \
					and continuation_plan_signature(plan_variant as Dictionary) \
						== _economy_plan_override_signature:
				return (plan_variant as Dictionary).duplicate(true)
		_economy_plan_override_signature = ""
		_exhausted_economy_plan_signatures.clear()
	return (ranked[0] as Dictionary).duplicate(true)


func _next_visible_economy_continuation_plan(
	rotation_state: Dictionary,
	current_plan: Dictionary
) -> Dictionary:
	var visible_keys: Dictionary = rotation_state.get("visible_facility_plan_keys", {}) \
		if rotation_state.get("visible_facility_plan_keys", {}) is Dictionary else {}
	if visible_keys.is_empty():
		return {}
	var ranked: Array = EconomyContinuationPlannerScript.ranked_plans(
		_latest_economy_continuation_observation
	)
	return first_visible_alternative_plan(
		ranked,
		current_plan,
		_exhausted_economy_plan_signatures,
		visible_keys
	)


static func first_visible_alternative_plan(
	ranked: Array,
	current_plan: Dictionary,
	exhausted_signatures: Dictionary,
	visible_facility_plan_keys: Dictionary
) -> Dictionary:
	var current_signature := continuation_plan_signature(current_plan)
	for plan_variant in ranked:
		if not (plan_variant is Dictionary):
			continue
		var plan := plan_variant as Dictionary
		var signature := continuation_plan_signature(plan)
		var facility_key := "%s|%s" % [
			str(plan.get("desired_facility_kind", "")),
			str(plan.get("industry_id", "")),
		]
		if signature.is_empty() or signature == current_signature \
				or bool(exhausted_signatures.get(signature, false)) \
				or not bool(visible_facility_plan_keys.get(facility_key, false)):
			continue
		return plan.duplicate(true)
	return {}


static func first_public_facility_rack_hint_for_plan(
	facility_rack_hints: Dictionary,
	continuation_plan: Dictionary
) -> Dictionary:
	var ordered: Array[Dictionary] = []
	for hint_variant in facility_rack_hints.values():
		if not (hint_variant is Dictionary):
			continue
		var hint := hint_variant as Dictionary
		if not _facility_rack_hint_matches_plan(hint, continuation_plan):
			continue
		ordered.append(hint.duplicate(true))
	ordered.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return "%06d|%s|%s|%s" % [
			int(left.get("district_index", -1)),
			str(left.get("region_id", "")),
			str(left.get("card_id", "")),
			str(left.get("rack_source_revision", "")),
		] < "%06d|%s|%s|%s" % [
			int(right.get("district_index", -1)),
			str(right.get("region_id", "")),
			str(right.get("card_id", "")),
			str(right.get("rack_source_revision", "")),
		]
	)
	return ordered[0].duplicate(true) if not ordered.is_empty() else {}


static func facility_rack_hint_matches_snapshot(
	hint: Dictionary,
	snapshot: Dictionary,
	continuation_plan: Dictionary
) -> bool:
	if not _facility_rack_hint_matches_plan(hint, continuation_plan) \
			or str(snapshot.get("visibility_scope", "")) != "viewer_private" \
			or int(snapshot.get("district_index", -1)) != int(hint.get("district_index", -1)) \
			or str(snapshot.get("region_id", "")) != str(hint.get("region_id", "")) \
			or str(snapshot.get("rack_source_revision", "")).is_empty() \
			or str(snapshot.get("rack_source_revision", "")) \
				!= str(hint.get("rack_source_revision", "")):
		return false
	var expected_card_id := str(hint.get("card_id", "")).strip_edges()
	for card_variant in snapshot.get("cards", []) as Array:
		if not (card_variant is Dictionary):
			continue
		var card := card_variant as Dictionary
		if str(card.get("card_id", card.get("card_name", ""))) == expected_card_id \
				and _is_supply_facility_kind(str(card.get("kind", ""))) \
				and EconomyContinuationPlannerScript.facility_matches_plan(
					card,
					continuation_plan
				) and bool(card.get(
					"continuation_target_available",
					card.get("new_target_available", false)
				)):
			return true
	return false


static func _facility_rack_hint_matches_plan(
	hint: Dictionary,
	continuation_plan: Dictionary
) -> bool:
	var bound_plan_signature := str(
		hint.get("active_plan_signature", "")
	).strip_edges()
	var desired_facility_kind := str(
		continuation_plan.get("desired_facility_kind", "")
	)
	var desired_industry_id := str(continuation_plan.get("industry_id", ""))
	return int(hint.get("schema_version", 0)) == 1 \
		and int(hint.get("district_index", -1)) >= 0 \
		and not str(hint.get("region_id", "")).strip_edges().is_empty() \
		and not str(hint.get("rack_source_revision", "")).strip_edges().is_empty() \
		and not str(hint.get("card_id", "")).strip_edges().is_empty() \
		and str(hint.get("facility_kind", "")) == desired_facility_kind \
		and (desired_industry_id.is_empty() \
			or str(hint.get("industry_id", "")) == desired_industry_id) \
		and (bound_plan_signature.is_empty() \
			or bound_plan_signature == continuation_plan_signature(continuation_plan))


static func _facility_rack_hint_key(hint: Dictionary) -> String:
	if int(hint.get("schema_version", 0)) != 1:
		return ""
	return JSON.stringify({
		"district_index": int(hint.get("district_index", -1)),
		"region_id": str(hint.get("region_id", "")),
		"rack_source_revision": str(hint.get("rack_source_revision", "")),
		"card_id": str(hint.get("card_id", "")),
		"facility_kind": str(hint.get("facility_kind", "")),
		"industry_id": str(hint.get("industry_id", "")),
	}).sha256_text()


func _sync_supply_rotation_plan(rotation_state: Dictionary, continuation_plan: Dictionary) -> void:
	if rotation_state.is_empty():
		return
	var plan_signature := continuation_plan_signature(continuation_plan)
	if str(rotation_state.get("active_plan_signature", "")) == plan_signature:
		return
	var facility_hints: Dictionary = rotation_state.get("facility_rack_hints", {}) \
		if rotation_state.get("facility_rack_hints", {}) is Dictionary else {}
	var matching_hint := first_public_facility_rack_hint_for_plan(
		facility_hints,
		continuation_plan
	)
	if not matching_hint.is_empty():
		matching_hint["active_plan_signature"] = plan_signature
	rotation_state["phase"] = ""
	rotation_state["target_district"] = -1
	rotation_state["source_rack_signature"] = ""
	rotation_state["source_selection_revision"] = -1
	rotation_state["rotation_count"] = 0
	rotation_state["exhausted_world_seconds"] = -1.0
	rotation_state["refresh_attempts_by_signature"] = {}
	rotation_state["exhausted_signatures"] = {}
	rotation_state["visited_districts"] = {}
	rotation_state["advancement_candidate_districts"] = {}
	rotation_state["pending_advancement_candidate"] = {}
	rotation_state["visible_facility_plan_keys"] = {}
	rotation_state["facility_rack_hints"] = facility_hints.duplicate(true)
	rotation_state["pending_facility_rack_hint"] = matching_hint.duplicate(true)
	rotation_state["matching_facility_seen"] = false
	rotation_state["matching_target_seen"] = false
	rotation_state["current_district"] = -1
	rotation_state["advancement_reposition"] = false
	rotation_state["facility_hint_reposition"] = false
	rotation_state["evaluated_rack_plan_signatures"] = {}
	rotation_state["active_plan_signature"] = plan_signature
	rotation_state["advancement_epoch_active"] = false
	if not matching_hint.is_empty():
		rotation_state["phase"] = "facility_hint_pending"
	_facility_candidate_attempts.clear()


static func _facility_cards_with_stable_identity(cards: Array) -> Array:
	var result: Array = []
	for card_variant in cards:
		if not (card_variant is Dictionary):
			continue
		var card := (card_variant as Dictionary).duplicate(true)
		if str(card.get("category_id", "")) not in ["facility", "facility-v06"]:
			continue
		var offer: Dictionary = card.get("game_action_offer", {}) \
			if card.get("game_action_offer", {}) is Dictionary else {}
		if not bool(GameActionOfferV1.validation_report(offer).get("valid", false)):
			continue
		var target_ids := GameActionOfferV1.target_ids(offer) if not offer.is_empty() else {}
		var offered_instance_ref := str(target_ids.get("card_instance_id", ""))
		var projected_instance_ref := str(card.get("card_instance_id", ""))
		var offered_source_revision := maxi(0, int(offer.get("source_revision", 0)))
		var projected_source_revision := maxi(0, int(card.get("source_revision", 0)))
		if (not projected_instance_ref.is_empty() \
				and projected_instance_ref != offered_instance_ref) \
				or (projected_source_revision > 0 \
				and projected_source_revision != offered_source_revision):
			continue
		card["card_id"] = str(card.get("card_semantic_id", ""))
		card["card_instance_ref"] = offered_instance_ref
		card["source_revision"] = offered_source_revision
		card["kind"] = "facility_v06"
		card["actionable"] = str(card.get("play_state", "disabled")) == "available"
		# PlayerCardDock exposes wire-safe stable IDs with hyphens. The driver keeps
		# its established domain reason enum in snake_case before matching retry
		# classes; this is presentation adaptation, not a second gameplay rule.
		card["play_reason_id"] = str(
			card.get("disabled_reason_id", "action-disabled")
		).replace("-", "_")
		if not str(card.get("card_id", "")).is_empty() \
				and not str(card.get("card_instance_ref", "")).is_empty():
			result.append(card)
	return result


static func matching_facility_cards(
	cards: Array,
	continuation_plan: Dictionary,
	actionable_only := false
) -> Array:
	var result: Array[Dictionary] = []
	for card_variant in cards:
		if not (card_variant is Dictionary):
			continue
		var card := card_variant as Dictionary
		if str(card.get("kind", "")) not in ["facility", "facility_v06", "public_facility"] \
				or not EconomyContinuationPlannerScript.facility_matches_plan(card, continuation_plan) \
				or actionable_only and not bool(card.get("actionable", false)):
			continue
		result.append(card.duplicate(true))
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return "%s|%s|%06d" % [str(left.get("card_id", "")), str(left.get("card_instance_ref", left.get("id", ""))), int(left.get("slot", -1))] \
			< "%s|%s|%06d" % [str(right.get("card_id", "")), str(right.get("card_instance_ref", right.get("id", ""))), int(right.get("slot", -1))]
	)
	return result


static func _enabled_card_action_request(card: Dictionary) -> Dictionary:
	if card.is_empty():
		return {}
	var offer: Dictionary = card.get("game_action_offer", {}) \
		if card.get("game_action_offer", {}) is Dictionary else {}
	if not bool(GameActionOfferV1.validation_report(offer).get("valid", false)) \
			or str(offer.get("legality_state", "")) != "available" \
			or not bool(card.get("actionable", false)):
		return {}
	var request := {
		"id": "card.play.%s" % str(card.get("card_instance_ref", "unknown")),
		"phase": "play.hand.facility_v06.%s" % str(card.get("action_state", card.get("play_state", "ready"))),
		"disabled": false,
		"origin": "game_action",
	}
	request["game_action_offer"] = offer.duplicate(true)
	request["game_action_required"] = true
	return request


static func production_growth_required(
	public_progress: Dictionary,
	sale_receipt: Dictionary,
	victory_state := "idle",
	current_world_seconds := 0.0,
	maturity_checkpoint: Dictionary = {}
) -> bool:
	return bool(production_growth_policy(
		public_progress,
		sale_receipt,
		current_world_seconds,
		maturity_checkpoint,
		victory_state
	).get("growth_required", false))


static func production_growth_policy(
	public_progress: Dictionary,
	sale_receipt: Dictionary,
	current_world_seconds: float,
	maturity_checkpoint: Dictionary,
	victory_state: String
) -> Dictionary:
	if victory_state in ["qualification", "audit", "resolved"]:
		return {"growth_required": false, "reason_id": "victory_lifecycle_locked"}
	if bool(public_progress.get("eligible", false)):
		return {"growth_required": false, "reason_id": "victory_eligible"}
	if not bool(public_progress.get("matched_economy_chain_observed", false)):
		return {"growth_required": true, "reason_id": "matched_economy_chain_incomplete"}
	if not bool(sale_receipt.get("observed", false)):
		return {"growth_required": false, "reason_id": "first_sale_pending"}
	var required_top_k := maxi(
		0,
		int(public_progress.get("required_top_k_gdp_per_minute", 0))
	)
	if required_top_k <= 0:
		return {"growth_required": false, "reason_id": "victory_threshold_unavailable"}
	if int(public_progress.get("top_k_gdp_per_minute", 0)) >= required_top_k:
		return {"growth_required": false, "reason_id": "gdp_threshold_met"}
	if production_maturation_pending(
		public_progress,
		sale_receipt,
		current_world_seconds,
		maturity_checkpoint
	):
		return {"growth_required": false, "reason_id": "production_maturation_pending"}
	return {"growth_required": true, "reason_id": "gdp_capacity_below_threshold"}


static func production_maturation_pending(
	public_progress: Dictionary,
	sale_receipt: Dictionary,
	current_world_seconds: float,
	maturity_checkpoint: Dictionary
) -> bool:
	var installation_count := maxi(0, int(public_progress.get("production_installation_count", 0)))
	if not bool(public_progress.get("matched_economy_chain_observed", false)) \
			or not bool(sale_receipt.get("observed", false)):
		return false
	if int(maturity_checkpoint.get("installation_count", -1)) != installation_count:
		return true
	var receipt_delta := maxi(
		0,
		int(sale_receipt.get("public_event_count", 0))
			- int(maturity_checkpoint.get("sale_receipt_count", 0))
	)
	var elapsed_world_seconds := maxf(
		0.0,
		current_world_seconds - float(maturity_checkpoint.get("observed_world_seconds", current_world_seconds))
	)
	return receipt_delta < PRODUCTION_MATURITY_SALE_RECEIPT_COUNT \
		and elapsed_world_seconds < PRODUCTION_MATURITY_WORLD_SECONDS


func _observe_production_maturity_checkpoint(
	public_progress: Dictionary,
	sale_receipt: Dictionary,
	world_seconds: float
) -> void:
	var installation_count := maxi(0, int(public_progress.get("production_installation_count", 0)))
	if not _production_maturity_checkpoint.is_empty() \
			and int(_production_maturity_checkpoint.get("installation_count", -1)) == installation_count:
		return
	_production_maturity_checkpoint = {
		"installation_count": installation_count,
		"sale_receipt_count": maxi(0, int(sale_receipt.get("public_event_count", 0))),
		"sale_receipt_revision": maxi(0, int(sale_receipt.get("latest_source_revision", 0))),
		"observed_world_seconds": maxf(0.0, world_seconds),
	}


static func authoritative_progress_budget_decision(
	authoritative_step_count: int,
	last_progress_step: int,
	world_effective_seconds: float
) -> Dictionary:
	var safe_step_count := maxi(0, authoritative_step_count)
	var steps_since_progress := maxi(0, safe_step_count - maxi(0, last_progress_step))
	if world_effective_seconds >= AUTHORITATIVE_WORLD_EFFECTIVE_TIME_LIMIT_SECONDS:
		return {"allowed": false, "reason_id": "authoritative_world_time_budget_exhausted", "steps_since_progress": steps_since_progress, "extension_active": safe_step_count >= AUTHORITATIVE_WAIT_BASE_STEP_LIMIT}
	if safe_step_count >= AUTHORITATIVE_WAIT_MAX_STEP_LIMIT:
		return {"allowed": false, "reason_id": "authoritative_runtime_max_step_budget_exhausted", "steps_since_progress": steps_since_progress, "extension_active": true}
	if steps_since_progress >= AUTHORITATIVE_PROGRESS_STALL_WINDOW_STEPS:
		return {"allowed": false, "reason_id": "authoritative_runtime_progress_stalled", "steps_since_progress": steps_since_progress, "extension_active": safe_step_count >= AUTHORITATIVE_WAIT_BASE_STEP_LIMIT}
	return {
		"allowed": true,
		"reason_id": "progress_extension" if safe_step_count >= AUTHORITATIVE_WAIT_BASE_STEP_LIMIT else "base_budget",
		"steps_since_progress": steps_since_progress,
		"extension_active": safe_step_count >= AUTHORITATIVE_WAIT_BASE_STEP_LIMIT,
	}


func _observe_authoritative_progress(telemetry: Dictionary) -> void:
	var progress: Dictionary = telemetry.get("progress", {}) if telemetry.get("progress", {}) is Dictionary else {}
	var sale_receipt: Dictionary = telemetry.get("sale_receipt", {}) if telemetry.get("sale_receipt", {}) is Dictionary else {}
	var settlement: Dictionary = telemetry.get("settlement", {}) if telemetry.get("settlement", {}) is Dictionary else {}
	var reasons: Array[String] = []
	_observe_progress_high_water("production_installation_count", int(progress.get("production_installation_count", 0)), "production_installation", reasons)
	_observe_progress_high_water("sale_receipt_revision", int(sale_receipt.get("latest_source_revision", 0)), "sale_receipt", reasons)
	_observe_progress_high_water("top_k_gdp_per_minute", int(progress.get("top_k_gdp_per_minute", 0)), "top_k_gdp", reasons)
	_observe_progress_high_water("controlled_region_count", int(progress.get("controlled_region_count", 0)), "controlled_region", reasons)
	if bool(progress.get("eligible", false)) and not bool(_authoritative_progress_high_water.get("eligible", false)):
		_authoritative_progress_high_water["eligible"] = true
		reasons.append("victory_eligible")
	var victory_state := str(settlement.get("state", "idle"))
	var victory_rank := _victory_state_progress_rank(victory_state)
	if victory_rank > int(_authoritative_progress_high_water.get("victory_state_rank", 0)):
		_authoritative_progress_high_water["victory_state_rank"] = victory_rank
		reasons.append("victory_%s" % victory_state)
	var installation_count := maxi(0, int(progress.get("production_installation_count", 0)))
	if bool(progress.get("eligible", false)) \
			or victory_state in ["qualification", "audit", "resolved"]:
		if _eligibility_locked_production_installation_count < 0:
			_eligibility_locked_production_installation_count = installation_count
		_post_eligibility_production_installation_delta = post_eligibility_installation_delta(
			_post_eligibility_production_installation_delta,
			_eligibility_locked_production_installation_count,
			installation_count
		)
	else:
		_eligibility_locked_production_installation_count = -1
		_post_eligibility_production_installation_delta = 0
	if bool(settlement.get("completed", false)):
		reasons.append("settlement_completed")
	if not reasons.is_empty():
		_mark_authoritative_progress("+".join(reasons))


static func post_eligibility_installation_delta(
	previous_delta: int,
	locked_installation_count: int,
	current_installation_count: int
) -> int:
	if locked_installation_count < 0:
		return 0
	return maxi(
		maxi(0, previous_delta),
		maxi(0, current_installation_count - locked_installation_count)
	)


func _observe_progress_high_water(key: String, value: int, reason_id: String, reasons: Array[String]) -> void:
	var safe_value := maxi(0, value)
	if not monotonic_progress_advanced(int(_authoritative_progress_high_water.get(key, 0)), safe_value):
		return
	_authoritative_progress_high_water[key] = safe_value
	reasons.append(reason_id)


func _mark_authoritative_progress(reason_id: String) -> void:
	_authoritative_last_progress_step = _authoritative_step_attempt_count
	_authoritative_last_progress_reason = _safe_progress_token(reason_id)


func _observe_terminal_timer_step_progress() -> void:
	if _victory_timer_trace.is_empty():
		_authoritative_last_terminal_timer_sample = {}
		_authoritative_terminal_timer_stall_count = 0
		return
	var current := (_victory_timer_trace[-1] as Dictionary).duplicate(true)
	var state_id := str(current.get("state", ""))
	if state_id not in ["qualification", "audit"]:
		_authoritative_last_terminal_timer_sample = current
		_authoritative_terminal_timer_stall_count = 0
		return
	if _authoritative_last_terminal_timer_sample.is_empty() or str(_authoritative_last_terminal_timer_sample.get("state", "")) != state_id:
		_authoritative_last_terminal_timer_sample = current
		_authoritative_terminal_timer_stall_count = 0
		_mark_authoritative_progress("victory_timer_%s" % state_id)
		return
	var remaining_key := "qualification_remaining_us" if state_id == "qualification" else "audit_remaining_us"
	if terminal_timer_sample_progressed(_authoritative_last_terminal_timer_sample, current, remaining_key):
		_authoritative_terminal_timer_stall_count = 0
		_mark_authoritative_progress("victory_timer_%s" % state_id)
	else:
		_authoritative_terminal_timer_stall_count += 1
	_authoritative_last_terminal_timer_sample = current


static func monotonic_progress_advanced(previous_value: int, current_value: int) -> bool:
	return current_value > previous_value


static func terminal_timer_sample_progressed(previous: Dictionary, current: Dictionary, remaining_key: String) -> bool:
	var previous_remaining := int(previous.get(remaining_key, -1))
	var current_remaining := int(current.get(remaining_key, -1))
	return int(current.get("world_effective_us", -1)) > int(previous.get("world_effective_us", -1)) \
		and current_remaining >= 0 \
		and previous_remaining > current_remaining


static func _victory_state_progress_rank(state_id: String) -> int:
	match state_id:
		"qualification":
			return 1
		"audit":
			return 2
		"resolved":
			return 3
	return 0


func _emit_authoritative_progress_checkpoints(seed_index: int, telemetry: Dictionary, coordinator: Node) -> void:
	while _authoritative_step_attempt_count >= _next_progress_checkpoint_step:
		var progress: Dictionary = telemetry.get("progress", {}) if telemetry.get("progress", {}) is Dictionary else {}
		var sale_receipt: Dictionary = telemetry.get("sale_receipt", {}) if telemetry.get("sale_receipt", {}) is Dictionary else {}
		var settlement: Dictionary = telemetry.get("settlement", {}) if telemetry.get("settlement", {}) is Dictionary else {}
		var elapsed: Dictionary = telemetry.get("elapsed", {}) if telemetry.get("elapsed", {}) is Dictionary else {}
		var economy := _public_economy_progress_observation(coordinator)
		var rng := _capture_rng_checkpoint(coordinator)
		var checkpoint := progress_checkpoint_snapshot({
			"run_id": "seed-%02d" % seed_index,
			"step": _next_progress_checkpoint_step,
			"world_time": maxf(0.0, float(elapsed.get("world_seconds", 0.0))),
			"facilities": maxi(0, int(progress.get("production_installation_count", 0))),
			"production": economy.get("production", {}),
			"demand": economy.get("demand", {}),
			"transport": economy.get("transport", {}),
			"waste": economy.get("waste", {}),
			"sale_receipts": maxi(0, int(sale_receipt.get("public_event_count", 0))),
			"top_k_gdp": maxi(0, int(progress.get("top_k_gdp_per_minute", 0))),
			"victory_state": str(settlement.get("state", "idle")),
			"last_successful_action": _last_successful_action_id,
			"steps_since_progress": maxi(0, _next_progress_checkpoint_step - _authoritative_last_progress_step),
			"rng_draw_count": maxi(0, int(rng.get("draw_count", 0))),
		})
		_authoritative_progress_checkpoints.append(checkpoint.duplicate(true))
		_emit_ndjson(checkpoint)
		_next_progress_checkpoint_step += PROGRESS_CHECKPOINT_INTERVAL_STEPS


static func progress_checkpoint_snapshot(source: Dictionary) -> Dictionary:
	var production: Dictionary = source.get("production", {}) if source.get("production", {}) is Dictionary else {}
	var demand: Dictionary = source.get("demand", {}) if source.get("demand", {}) is Dictionary else {}
	var transport: Dictionary = source.get("transport", {}) if source.get("transport", {}) is Dictionary else {}
	var waste: Dictionary = source.get("waste", {}) if source.get("waste", {}) is Dictionary else {}
	return {
		"type": "progress_checkpoint",
		"schema": 1,
		"driver": DRIVER_ID,
		"run_id": _safe_progress_run_id(str(source.get("run_id", ""))),
		"step": maxi(0, int(source.get("step", 0))),
		"world_time": maxf(0.0, float(source.get("world_time", 0.0))),
		"facilities": maxi(0, int(source.get("facilities", 0))),
		"production": {"capacity_units_per_minute": maxi(0, int(production.get("capacity_units_per_minute", 0))), "settled_units": maxi(0, int(production.get("settled_units", 0)))},
		"demand": {"capacity_units_per_minute": maxi(0, int(demand.get("capacity_units_per_minute", 0))), "settled_units": maxi(0, int(demand.get("settled_units", 0)))},
		"transport": {"settled_units": maxi(0, int(transport.get("settled_units", 0)))},
		"waste": {"cumulative_units": maxf(0.0, float(waste.get("cumulative_units", 0.0)))},
		"sale_receipts": maxi(0, int(source.get("sale_receipts", 0))),
		"top_k_gdp": maxi(0, int(source.get("top_k_gdp", 0))),
		"victory_state": _safe_progress_token(str(source.get("victory_state", "idle"))),
		"last_successful_action": _safe_progress_token(str(source.get("last_successful_action", ""))),
		"steps_since_progress": maxi(0, int(source.get("steps_since_progress", 0))),
		"rng_draw_count": maxi(0, int(source.get("rng_draw_count", 0))),
	}


func _public_economy_continuation_observation(
	coordinator: Node,
	public_progress: Dictionary
) -> Dictionary:
	if coordinator == null:
		return {}
	var flow := coordinator.get_node_or_null("CommodityFlowRuntimeController")
	var infrastructure := coordinator.get_node_or_null("RegionInfrastructureRuntimeController")
	if flow == null or infrastructure == null \
			or not flow.has_method("public_installations_snapshot") \
			or not flow.has_method("recent_sale_receipts_snapshot") \
			or not flow.has_method("public_waste_summary_snapshot") \
			or not infrastructure.has_method("public_economy_snapshot"):
		return {}
	var infrastructure_variant: Variant = infrastructure.call("public_economy_snapshot")
	var installations_variant: Variant = flow.call("public_installations_snapshot")
	var receipts_variant: Variant = flow.call("recent_sale_receipts_snapshot", SCRIPTED_PLAYER_INDEX)
	var waste_variant: Variant = flow.call("public_waste_summary_snapshot")
	var observation := EconomyContinuationPlannerScript.observation_from_public_sources({
		"viewer_index": SCRIPTED_PLAYER_INDEX,
		"infrastructure": (infrastructure_variant as Dictionary).duplicate(true) \
			if infrastructure_variant is Dictionary else {},
		"installations": (installations_variant as Array).duplicate(true) \
			if installations_variant is Array else [],
		"own_receipts": (receipts_variant as Array).duplicate(true) \
			if receipts_variant is Array else [],
		"waste": (waste_variant as Dictionary).duplicate(true) \
			if waste_variant is Dictionary else {},
		"public_progress": public_progress.duplicate(true),
	})
	return PublicEconomyContinuationObservationScript.detached_copy(observation)


func _public_economy_progress_observation(coordinator: Node) -> Dictionary:
	var flow := coordinator.get_node_or_null("CommodityFlowRuntimeController") if coordinator != null else null
	if flow == null or not flow.has_method("public_installations_snapshot") or not flow.has_method("recent_sale_receipts_snapshot") or not flow.has_method("public_waste_summary_snapshot"):
		return {"production": {"capacity_units_per_minute": 0}, "demand": {"capacity_units_per_minute": 0}, "transport": {"settled_units": 0}, "waste": {"cumulative_units": 0.0}}
	var production_capacity := 0
	var demand_capacity := 0
	var installations_variant: Variant = flow.call("public_installations_snapshot")
	var installations: Array = installations_variant if installations_variant is Array else []
	for installation_variant in installations:
		if not (installation_variant is Dictionary):
			continue
		var installation := installation_variant as Dictionary
		if not bool(installation.get("active", false)):
			continue
		var base_rate := maxi(0, int(installation.get("base_units_per_minute", 0)))
		if str(installation.get("direction", "")) == "production":
			production_capacity += base_rate
		elif str(installation.get("direction", "")) == "demand":
			demand_capacity += base_rate
	var settled_units := 0
	var transported_units := 0
	var receipts_variant: Variant = flow.call("recent_sale_receipts_snapshot", -1)
	var receipts: Array = receipts_variant if receipts_variant is Array else []
	for receipt_variant in receipts:
		if receipt_variant is Dictionary:
			var receipt := receipt_variant as Dictionary
			var units := maxi(0, int(receipt.get("units", 0)))
			settled_units += units
			if not str(receipt.get("route_id", "")).is_empty():
				transported_units += units
	var cumulative_waste := 0.0
	var waste_variant: Variant = flow.call("public_waste_summary_snapshot")
	var waste: Dictionary = waste_variant if waste_variant is Dictionary else {}
	for row_variant in waste.get("commodity_rows", []):
		if row_variant is Dictionary:
			cumulative_waste += maxf(0.0, float((row_variant as Dictionary).get("cumulative_wasted_units", 0.0)))
	return {
		"production": {"capacity_units_per_minute": production_capacity, "settled_units": settled_units},
		"demand": {"capacity_units_per_minute": demand_capacity, "settled_units": settled_units},
		"transport": {"settled_units": transported_units},
		"waste": {"cumulative_units": snappedf(cumulative_waste, 0.001)},
	}


static func _safe_progress_token(value: String) -> String:
	var normalized := value.strip_edges().left(96)
	var result := ""
	for index in range(normalized.length()):
		var code := normalized.unicode_at(index)
		if (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or code in [43, 45, 46, 47, 58, 95]:
			result += String.chr(code)
	return result


static func _safe_progress_run_id(value: String) -> String:
	var normalized := value.strip_edges()
	if normalized.length() != 7 or not normalized.begins_with("seed-"):
		return ""
	var index_text := normalized.substr(5, 2)
	if not index_text.is_valid_int():
		return ""
	var seed_index := int(index_text)
	return normalized if seed_index >= 0 and seed_index < FIXED_SEEDS.size() else ""

func _district_supply_ui_action(runtime_screen: Node, continuation_plan: Dictionary) -> Dictionary:
	var drawer := _region_supply_popup(runtime_screen)
	if drawer == null or not drawer.visible or not drawer.has_signal("game_action_offer_requested"):
		return {}
	var snapshot := _annotate_new_facility_target_availability(
		_district_supply_view_snapshot(),
		continuation_plan
	)
	var request := district_supply_action_from_snapshot(snapshot, continuation_plan)
	var action_id := str(request.get("id", ""))
	var region_id := str(snapshot.get("region_id", ""))
	var payload: Dictionary = request.get("payload", {}) \
		if request.get("payload", {}) is Dictionary else {}
	var card_id := str(payload.get("card_name", ""))
	if action_id == "district_supply_preview_card":
		return _request_with_surface_offer(
			request,
			GameActionIntentV1.ACTION_DISTRICT_SUPPLY_QUOTE,
			{"region_id": region_id, "card_id": card_id}
		)
	if action_id == "district_supply_purchase_card":
		return _request_with_surface_offer(
			request,
			GameActionIntentV1.ACTION_DISTRICT_SUPPLY_PURCHASE,
			{"region_id": region_id, "card_id": card_id}
		)
	return request


func _district_supply_advancement_ui_action(
	runtime_screen: Node,
	rotation_state: Dictionary
) -> Dictionary:
	var drawer := _region_supply_popup(runtime_screen)
	if drawer == null or not drawer.visible or not drawer.has_signal("game_action_offer_requested"):
		return {}
	var snapshot := _district_supply_view_snapshot()
	var pending_candidate: Dictionary = rotation_state.get(
		"pending_advancement_candidate",
		{}
	) if rotation_state.get("pending_advancement_candidate", {}) is Dictionary else {}
	if not pending_candidate.is_empty() and not rack_advancement_candidate_matches_snapshot(
		pending_candidate,
		snapshot,
		str(rotation_state.get("active_plan_signature", ""))
	):
		advance_rack_advancement_after_retryable_failure(rotation_state)
		return {}
	var request := district_supply_advancement_action_from_snapshot(
		snapshot,
		str(pending_candidate.get("card_id", ""))
	)
	var action_id := str(request.get("id", ""))
	if action_id not in [
		"district_supply_preview_card",
		"district_supply_purchase_card",
	]:
		return {}
	var payload: Dictionary = request.get("payload", {}) \
		if request.get("payload", {}) is Dictionary else {}
	var card_id := str(payload.get("card_name", "")).strip_edges()
	var region_id := str(snapshot.get("region_id", "")).strip_edges()
	if card_id.is_empty() or region_id.is_empty():
		return {}
	return _request_with_surface_offer(
		request,
		GameActionIntentV1.ACTION_DISTRICT_SUPPLY_QUOTE \
			if action_id == "district_supply_preview_card" \
			else GameActionIntentV1.ACTION_DISTRICT_SUPPLY_PURCHASE,
		{"region_id": region_id, "card_id": card_id}
	)


static func rack_advancement_candidate_matches_snapshot(
	candidate: Dictionary,
	snapshot: Dictionary,
	active_plan_signature: String
) -> bool:
	var card_id := str(candidate.get("card_id", "")).strip_edges()
	return not card_id.is_empty() \
		and str(snapshot.get("visibility_scope", "")) == "viewer_private" \
		and int(candidate.get("district_index", -1)) \
			== int(snapshot.get("district_index", -1)) \
		and not str(candidate.get("rack_source_revision", "")).is_empty() \
		and str(candidate.get("rack_source_revision", "")) \
			== str(snapshot.get("rack_source_revision", "")) \
		and not active_plan_signature.is_empty() \
		and str(candidate.get("active_plan_signature", "")) == active_plan_signature \
		and not district_supply_advancement_action_from_snapshot(snapshot, card_id).is_empty()


static func district_supply_advancement_action_from_snapshot(
	snapshot: Dictionary,
	expected_card_id := ""
) -> Dictionary:
	if str(snapshot.get("visibility_scope", "")) != "viewer_private":
		return {}
	var cards: Array = snapshot.get("cards", []) if snapshot.get("cards", []) is Array else []
	var ordered: Array[Dictionary] = []
	for card_variant in cards:
		if not (card_variant is Dictionary):
			continue
		var card := card_variant as Dictionary
		var card_id := str(card.get("card_id", card.get("card_name", ""))).strip_edges()
		var card_kind := str(card.get("kind", "")).strip_edges()
		var card_preview: Dictionary = card.get("preview", {}) \
			if card.get("preview", {}) is Dictionary else {}
		var primary_action_id := str(card_preview.get("primary_action_id", ""))
		if card_id.is_empty() or not expected_card_id.is_empty() and card_id != expected_card_id \
				or card_kind.is_empty() \
				or _is_supply_facility_kind(card_kind) \
				or not str(card.get("facility_kind", "")).strip_edges().is_empty() \
				or primary_action_id not in [
					"district_supply_preview_card",
					"district_supply_purchase_card",
				] or not bool(card_preview.get("buy_enabled", false)):
			continue
		var candidate := card.duplicate(true)
		candidate["rack_advancement_action_id"] = primary_action_id
		ordered.append(candidate)
	ordered.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return "%01d|%012d|%s" % [
			0 if str(left.get("rack_advancement_action_id", "")) \
				== "district_supply_purchase_card" else 1,
			maxi(0, int(left.get("price", 0))),
			str(left.get("card_id", left.get("card_name", ""))),
		] < "%01d|%012d|%s" % [
			0 if str(right.get("rack_advancement_action_id", "")) \
				== "district_supply_purchase_card" else 1,
			maxi(0, int(right.get("price", 0))),
			str(right.get("card_id", right.get("card_name", ""))),
		]
	)
	if ordered.is_empty():
		return {}
	var selected := ordered[0]
	var selected_card_id := str(
		selected.get("card_id", selected.get("card_name", ""))
	).strip_edges()
	var action_id := str(selected.get("rack_advancement_action_id", ""))
	return {
		"id": action_id,
		"phase": "play.supply.rack_advancement.%s.%s" % [
			"purchase" if action_id == "district_supply_purchase_card" else "quote",
			selected_card_id,
		],
		"disabled": false,
		"origin": "district_supply",
		"rack_advancement": true,
		"rack_advancement_card_id": selected_card_id,
		"payload": {
			"card_name": selected_card_id,
			"source": "full_run_bounded_rack_advancement",
		},
	}


func _district_supply_view_snapshot() -> Dictionary:
	if _district_supply_query_port == null:
		return {}
	_district_supply_query_count += 1
	var surface := _district_supply_query_port.snapshot_for_viewer(SCRIPTED_PLAYER_INDEX)
	if not bool(surface.get("visible", false)) or not (surface.get("snapshot", {}) is Dictionary):
		return {}
	var result := (surface.get("snapshot", {}) as Dictionary).duplicate(true)
	var district_index := int(surface.get("district_index", -1))
	result["district_index"] = district_index
	result["region_id"] = _public_region_id_for_district(district_index)
	result["rack_source_revision"] = str(
		surface.get("rack_source_revision", "")
	).strip_edges()
	return result


func _public_region_id_for_district(district_index: int) -> String:
	if _table_presentation_query_ports == null or district_index < 0:
		return ""
	var public_world := _table_presentation_query_ports.public_world_projection().to_dictionary()
	var districts: Array = public_world.get("districts", []) \
		if public_world.get("districts", []) is Array else []
	if district_index >= districts.size() or not (districts[district_index] is Dictionary):
		return ""
	return str((districts[district_index] as Dictionary).get("region_id", "")).strip_edges()


func _public_region_commodity_facts() -> Array:
	if _table_presentation_query_ports == null:
		return []
	var query := _table_presentation_query_ports.region_infrastructure_public_query
	if query == null or not query.has_method("public_commodity_region_facts"):
		return []
	var value: Variant = query.call("public_commodity_region_facts")
	return (value as Array).duplicate(true) if value is Array else []


func _annotate_new_facility_target_availability(
	snapshot: Dictionary,
	continuation_plan: Dictionary
) -> Dictionary:
	var result := snapshot.duplicate(true)
	if _table_presentation_query_ports == null:
		return result
	var cards: Array = result.get("cards", []) if result.get("cards", []) is Array else []
	var target_by_card_id := {}
	var region_facts := _public_region_commodity_facts()
	for card_index in range(cards.size()):
		if not (cards[card_index] is Dictionary):
			continue
		var card := (cards[card_index] as Dictionary).duplicate(true)
		var card_id := str(card.get("card_id", card.get("card_name", ""))).strip_edges()
		card["card_id"] = card_id
		if not _is_supply_facility_kind(str(card.get("kind", ""))):
			cards[card_index] = card
			continue
		var target_snapshot := _table_presentation_query_ports.public_new_facility_target_candidates(
			StringName(str(card.get("facility_kind", ""))),
			StringName(str(card.get("industry_id", "")))
		)
		var target := target_snapshot.to_dictionary() if target_snapshot != null else {}
		var matching_candidates := EconomyContinuationPlannerScript.matching_target_candidates(
			target.get("candidates", []) as Array,
			region_facts,
			continuation_plan
		)
		var target_available := bool(target.get("available", false)) \
			and not (target.get("candidates", []) as Array).is_empty()
		var continuation_target_available := target_available \
			and not matching_candidates.is_empty()
		card["new_target_available"] = target_available
		card["continuation_target_available"] = continuation_target_available
		card["target_source_revision"] = int(target.get("source_revision", 0))
		card["target_reason_code"] = str(target.get("reason_code", "public_new_facility_target_query_unavailable"))
		cards[card_index] = card
		target_by_card_id[card_id] = {
			"new_target_available": target_available,
			"continuation_target_available": continuation_target_available,
			"target_source_revision": int(card.get("target_source_revision", 0)),
			"target_reason_code": str(card.get("target_reason_code", "")),
		}
	result["cards"] = cards
	var preview: Dictionary = result.get("preview", {}) if result.get("preview", {}) is Dictionary else {}
	var preview_card_id := str(preview.get("card_id", preview.get("card_name", ""))).strip_edges()
	var preview_target: Dictionary = target_by_card_id.get(preview_card_id, {}) \
		if target_by_card_id.get(preview_card_id, {}) is Dictionary else {}
	if not preview_target.is_empty():
		preview = preview.duplicate(true)
		preview["card_id"] = preview_card_id
		preview.merge(preview_target, true)
		result["preview"] = preview
	return result


static func district_supply_action_from_snapshot(
	snapshot: Dictionary,
	continuation_plan: Dictionary
) -> Dictionary:
	var preview: Dictionary = snapshot.get("preview", {}) if snapshot.get("preview", {}) is Dictionary else {}
	var preview_card_id := str(preview.get("card_id", preview.get("card_name", "")))
	var primary_action_id := str(preview.get("primary_action_id", ""))
	var cards: Array = snapshot.get("cards", []) if snapshot.get("cards", []) is Array else []
	var preview_card := _supply_card_by_stable_id(cards, preview_card_id)
	var preview_matches := not preview_card.is_empty() \
		and EconomyContinuationPlannerScript.facility_matches_plan(preview_card, continuation_plan) \
		and bool(preview_card.get("continuation_target_available", false))
	var preview_reason := str(preview.get("action_reason_code", ""))
	var quote_retry_allowed := primary_action_id == "district_supply_preview_card" \
		and preview_reason not in ["source_region_dark", "source_region_destroyed", "card_not_in_supply"]
	var purchase_ready := primary_action_id == "district_supply_purchase_card" \
		and bool(preview.get("buy_enabled", false))
	if not preview_card_id.is_empty() \
			and preview_matches \
			and (quote_retry_allowed or purchase_ready):
		var action_phase := "quote" if primary_action_id == "district_supply_preview_card" else "purchase"
		return {
			"id": primary_action_id,
			"phase": "play.supply.%s.%s" % [action_phase, preview_card_id],
			"disabled": false,
			"origin": "district_supply",
			"payload": {"card_name": preview_card_id, "source": "full_run_visible_preview"},
		}
	var retry_next_facility := str(preview.get("action_reason_code", "")) in [
		"source_region_dark",
		"source_region_destroyed",
		"market_listing_changed",
		"market_quote_unavailable",
		"quote_expired",
	]
	var facility_card := _next_matching_supply_facility_card(
		cards,
		continuation_plan,
		preview_card_id if retry_next_facility else "",
		true
	)
	if not facility_card.is_empty():
		var facility_id := str(facility_card.get("card_id", facility_card.get("card_name", "")))
		if preview_card_id != facility_id:
			return {
				"id": "district_supply_preview_card",
				"phase": "play.supply.preview_facility.%s" % facility_id,
				"disabled": false,
				"origin": "district_supply",
				"payload": {"card_name": facility_id, "source": "full_run_economy_continuation"},
			}
	var visible_facility := _next_matching_supply_facility_card(
		cards,
		continuation_plan,
		preview_card_id,
		false
	)
	if not visible_facility.is_empty():
		var visible_facility_id := str(visible_facility.get("card_id", visible_facility.get("card_name", "")))
		if preview_card_id != visible_facility_id:
			return {
				"id": "district_supply_preview_card",
				"phase": "play.supply.preview_facility.%s" % visible_facility_id,
				"disabled": false,
				"origin": "district_supply",
				"payload": {"card_name": visible_facility_id, "source": "full_run_economy_continuation"},
			}
	var wait_reason := str(preview.get("action_reason_code", "facility_not_visible")) \
		if preview_matches else "facility_not_visible"
	return {
		"id": "district_supply_wait",
		"phase": "play.supply.wait.cards_%d.preview_%s.reason_%s" % [
			cards.size(),
			preview_card_id if not preview_card_id.is_empty() else "none",
			wait_reason,
		],
		"disabled": true,
		"origin": "district_supply",
	}


static func _next_matching_supply_facility_card(
	cards: Array,
	continuation_plan: Dictionary,
	after_card_id := "",
	actionable_only := false
) -> Dictionary:
	var matching: Array[Dictionary] = []
	for card in matching_facility_cards(cards, continuation_plan, actionable_only):
		if bool(card.get("continuation_target_available", false)):
			matching.append(card)
	if matching.is_empty():
		return {}
	if after_card_id.is_empty():
		return matching[0].duplicate(true)
	for index in range(matching.size()):
		var card_id := str(matching[index].get("card_id", matching[index].get("card_name", "")))
		if card_id == after_card_id:
			return matching[wrapi(index + 1, 0, matching.size())].duplicate(true)
	return matching[0].duplicate(true)


static func _supply_card_by_stable_id(cards: Array, card_id: String) -> Dictionary:
	if card_id.is_empty():
		return {}
	for card_variant in cards:
		if not (card_variant is Dictionary):
			continue
		var card := card_variant as Dictionary
		if str(card.get("card_id", card.get("card_name", ""))) == card_id:
			return card.duplicate(true)
	return {}


static func _new_supply_rotation_state(
	preserved_evaluated_rack_plan_signatures: Dictionary = {},
	active_plan_signature := "",
	preserved_facility_rack_hints: Dictionary = {}
) -> Dictionary:
	var preserved := preserved_evaluated_rack_plan_signatures.duplicate(true)
	while preserved.size() > SUPPLY_EVALUATED_RACK_SIGNATURE_LIMIT:
		preserved.erase(preserved.keys()[0])
	var facility_hints := preserved_facility_rack_hints.duplicate(true)
	while facility_hints.size() > SUPPLY_FACILITY_RACK_HINT_LIMIT:
		facility_hints.erase(facility_hints.keys()[0])
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
		"advancement_candidate_districts": {},
		"pending_advancement_candidate": {},
		"visible_facility_plan_keys": {},
		"facility_rack_hints": facility_hints,
		"pending_facility_rack_hint": {},
		"matching_facility_seen": false,
		"matching_target_seen": false,
		"current_district": -1,
		"advancement_reposition": false,
		"facility_hint_reposition": false,
		"evaluated_rack_plan_signatures": preserved,
		"active_plan_signature": active_plan_signature,
		"advancement_epoch_active": false,
	}


static func rack_advancement_allowed(
	rotation_state: Dictionary,
	committed_purchase_count: int
) -> bool:
	var phase := str(rotation_state.get("phase", ""))
	var exhaustion_proven := phase == "exhausted" \
		or phase == "advancement_recheck" \
			and bool(rotation_state.get("advancement_epoch_active", false))
	return exhaustion_proven \
		and committed_purchase_count >= 0 \
		and committed_purchase_count < SUPPLY_RACK_ADVANCEMENT_PURCHASE_LIMIT


static func exhausted_matching_facility_wait_required(
	rotation_state: Dictionary
) -> bool:
	return str(rotation_state.get("phase", "")) == "exhausted" \
		and bool(rotation_state.get("matching_facility_seen", false)) \
		and bool(rotation_state.get("matching_target_seen", false))


static func reset_supply_rotation_after_advancement(
	rotation_state: Dictionary
) -> Dictionary:
	var preserved_facility_hints: Dictionary = rotation_state.get("facility_rack_hints", {}) \
		if rotation_state.get("facility_rack_hints", {}) is Dictionary else {}
	preserved_facility_hints = preserved_facility_hints.duplicate(true)
	var current_district := int(rotation_state.get("current_district", -1))
	_remove_facility_rack_hints_for_district(
		preserved_facility_hints,
		current_district
	)
	var result := _new_supply_rotation_state(
		rotation_state.get("evaluated_rack_plan_signatures", {}) as Dictionary \
			if rotation_state.get("evaluated_rack_plan_signatures", {}) is Dictionary else {},
		str(rotation_state.get("active_plan_signature", "")),
		preserved_facility_hints
	)
	var candidates: Dictionary = rotation_state.get("advancement_candidate_districts", {}) \
		if rotation_state.get("advancement_candidate_districts", {}) is Dictionary else {}
	candidates = candidates.duplicate(true)
	candidates.erase(current_district)
	# The committed purchase changed only the current public rack. Keep the
	# completed-search lineage just long enough to inspect that replacement slot;
	# any non-actionable result exits this epoch and starts a new full scan.
	result["phase"] = "advancement_recheck"
	result["advancement_epoch_active"] = true
	result["advancement_candidate_districts"] = candidates
	result["current_district"] = current_district
	return result


func _public_supply_wait_facts(
	runtime_screen: Node,
	continuation_plan: Dictionary
) -> Dictionary:
	var screen := runtime_screen as SpaceSyndicateGameScreen
	var drawer := _region_supply_popup(runtime_screen)
	if screen == null or drawer == null or not drawer.visible:
		return {}
	var drawer_snapshot := _annotate_new_facility_target_availability(
		_district_supply_view_snapshot(),
		continuation_plan
	)
	var ui: Dictionary = screen.current_ui_data if screen.current_ui_data is Dictionary else {}
	var selection: Dictionary = ui.get("selection_context", {}) if ui.get("selection_context", {}) is Dictionary else {}
	var district_index := int(selection.get("selected_district", -1))
	var district_count := int(selection.get("district_count", 0))
	var has_visible_facility := false
	var has_visible_matching_facility := false
	var has_visible_matching_target := false
	var has_actionable_matching_facility := false
	var visible_facility_plan_keys: Array[String] = []
	var facility_rack_hints: Array[Dictionary] = []
	var rack_source_revision := str(
		drawer_snapshot.get("rack_source_revision", "")
	).strip_edges()
	var region_id := str(drawer_snapshot.get("region_id", "")).strip_edges()
	var cards: Array = drawer_snapshot.get("cards", []) if drawer_snapshot.get("cards", []) is Array else []
	for card_variant in cards:
		if not (card_variant is Dictionary):
			continue
		var card := card_variant as Dictionary
		var facility_kind := str(card.get("facility_kind", "")).strip_edges()
		var industry_id := str(card.get("industry_id", "")).strip_edges()
		var is_facility := _is_supply_facility_kind(str(card.get("kind", "")))
		has_visible_facility = has_visible_facility or is_facility
		if is_facility and not facility_kind.is_empty() and not industry_id.is_empty():
			if bool(card.get("new_target_available", false)):
				var facility_plan_key := "%s|%s" % [facility_kind, industry_id]
				if not visible_facility_plan_keys.has(facility_plan_key):
					visible_facility_plan_keys.append(facility_plan_key)
			var card_id := str(
				card.get("card_id", card.get("card_name", ""))
			).strip_edges()
			if district_index >= 0 and not region_id.is_empty() \
					and not rack_source_revision.is_empty() and not card_id.is_empty():
				facility_rack_hints.append({
					"schema_version": 1,
					"district_index": district_index,
					"region_id": region_id,
					"rack_source_revision": rack_source_revision,
					"card_id": card_id,
					"facility_kind": facility_kind,
					"industry_id": industry_id,
				})
		if not EconomyContinuationPlannerScript.facility_matches_plan(card, continuation_plan):
			continue
		has_visible_matching_facility = true
		var matching_target := bool(card.get("continuation_target_available", false))
		has_visible_matching_target = has_visible_matching_target or matching_target
		has_actionable_matching_facility = has_actionable_matching_facility \
			or (matching_target and bool(card.get("actionable", false)))
	var rack_signature := EconomyContinuationPlannerScript.rack_plan_signature(
		drawer_snapshot,
		continuation_plan
	)
	for hint in facility_rack_hints:
		hint["rack_signature"] = rack_signature
	var advancement_action := district_supply_advancement_action_from_snapshot(
		drawer_snapshot
	)
	visible_facility_plan_keys.sort()
	return {
		"valid": district_index >= 0 and district_count > 1,
		"district_index": district_index,
		"district_count": district_count,
		"selection_revision": int(selection.get("revision", -1)),
		"rack_source_revision": rack_source_revision,
		"rack_signature": rack_signature,
		"rack_content_plan_signature": rack_signature,
		"has_visible_facility": has_visible_facility,
		"has_visible_matching_facility": has_visible_matching_facility,
		"has_visible_matching_target": has_visible_matching_target,
		"has_actionable_matching_facility": has_actionable_matching_facility,
		"has_legal_advancement_candidate": not advancement_action.is_empty(),
		"advancement_card_id": str(
			advancement_action.get("rack_advancement_card_id", "")
		),
		"visible_facility_plan_keys": visible_facility_plan_keys,
		"facility_rack_hints": facility_rack_hints,
	}


static func _remember_supply_rack_evaluation(rotation_state: Dictionary, rack_signature: String) -> void:
	if rotation_state.is_empty() or rack_signature.is_empty():
		return
	var evaluated: Dictionary = rotation_state.get("evaluated_rack_plan_signatures", {}) \
		if rotation_state.get("evaluated_rack_plan_signatures", {}) is Dictionary else {}
	_remember_bounded_signature(
		evaluated,
		rack_signature,
		SUPPLY_EVALUATED_RACK_SIGNATURE_LIMIT
	)
	rotation_state["evaluated_rack_plan_signatures"] = evaluated


static func _remember_bounded_signature(
	signatures: Dictionary,
	signature: String,
	limit: int
) -> void:
	if signature.is_empty() or limit <= 0:
		return
	if signatures.has(signature):
		signatures.erase(signature)
	while signatures.size() >= limit:
		signatures.erase(signatures.keys()[0])
	signatures[signature] = true


static func _begin_supply_rack_rotation(rotation_state: Dictionary, wait_facts: Dictionary) -> bool:
	if rotation_state.is_empty() or not bool(wait_facts.get("valid", false)) \
			or not str(rotation_state.get("phase", "")).is_empty():
		return false
	_remember_supply_advancement_candidate(rotation_state, wait_facts)
	if int(rotation_state.get("rotation_count", 0)) >= SUPPLY_RACK_ROTATION_LIMIT:
		rotation_state["phase"] = "exhausted"
		return false
	_remember_supply_rack_evaluation(rotation_state, str(wait_facts.get("rack_signature", "")))
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
	rotation_state["advancement_reposition"] = false
	return true


static func _remember_supply_advancement_candidate(
	rotation_state: Dictionary,
	wait_facts: Dictionary
) -> void:
	if rotation_state.is_empty() or not bool(wait_facts.get("valid", false)):
		return
	var district_index := int(wait_facts.get("district_index", -1))
	if district_index < 0:
		return
	rotation_state["current_district"] = district_index
	var candidates: Dictionary = rotation_state.get("advancement_candidate_districts", {}) \
		if rotation_state.get("advancement_candidate_districts", {}) is Dictionary else {}
	if bool(wait_facts.get("has_legal_advancement_candidate", false)) \
			and not str(wait_facts.get("rack_source_revision", "")).is_empty():
		candidates[district_index] = {
			"rack_signature": str(wait_facts.get("rack_signature", "")),
			"rack_source_revision": str(wait_facts.get("rack_source_revision", "")),
			"active_plan_signature": str(rotation_state.get("active_plan_signature", "")),
			"card_id": str(wait_facts.get("advancement_card_id", "")),
			"district_index": district_index,
		}
	else:
		candidates.erase(district_index)
	rotation_state["advancement_candidate_districts"] = candidates
	var visible_keys: Dictionary = rotation_state.get("visible_facility_plan_keys", {}) \
		if rotation_state.get("visible_facility_plan_keys", {}) is Dictionary else {}
	for key_variant in wait_facts.get("visible_facility_plan_keys", []) as Array:
		var key := str(key_variant).strip_edges()
		if not key.is_empty():
			visible_keys[key] = true
	rotation_state["visible_facility_plan_keys"] = visible_keys
	rotation_state["matching_facility_seen"] = bool(
		rotation_state.get("matching_facility_seen", false)
	) or bool(wait_facts.get("has_visible_matching_facility", false))
	rotation_state["matching_target_seen"] = bool(
		rotation_state.get("matching_target_seen", false)
	) or bool(wait_facts.get("has_visible_matching_target", false))
	_remember_supply_facility_rack_hints(rotation_state, wait_facts)


static func _remember_supply_facility_rack_hints(
	rotation_state: Dictionary,
	wait_facts: Dictionary
) -> void:
	var district_index := int(wait_facts.get("district_index", -1))
	var rack_source_revision := str(
		wait_facts.get("rack_source_revision", "")
	).strip_edges()
	if rotation_state.is_empty() or district_index < 0 or rack_source_revision.is_empty():
		return
	var hints: Dictionary = rotation_state.get("facility_rack_hints", {}) \
		if rotation_state.get("facility_rack_hints", {}) is Dictionary else {}
	hints = hints.duplicate(true)
	_remove_facility_rack_hints_for_district(hints, district_index)
	for hint_variant in wait_facts.get("facility_rack_hints", []) as Array:
		if not (hint_variant is Dictionary):
			continue
		var hint := (hint_variant as Dictionary).duplicate(true)
		if int(hint.get("district_index", -1)) != district_index \
				or str(hint.get("rack_source_revision", "")) != rack_source_revision:
			continue
		var hint_key := _facility_rack_hint_key(hint)
		if hint_key.is_empty():
			continue
		_remember_bounded_dictionary(
			hints,
			hint_key,
			hint,
			SUPPLY_FACILITY_RACK_HINT_LIMIT
		)
	rotation_state["facility_rack_hints"] = hints


static func _remove_facility_rack_hints_for_district(
	hints: Dictionary,
	district_index: int
) -> void:
	for key_variant in hints.keys():
		var hint_variant: Variant = hints.get(key_variant, {})
		if hint_variant is Dictionary \
				and int((hint_variant as Dictionary).get("district_index", -1)) == district_index:
			hints.erase(key_variant)


static func _remember_bounded_dictionary(
	values: Dictionary,
	key: String,
	value: Dictionary,
	limit: int
) -> void:
	if key.is_empty() or value.is_empty() or limit <= 0:
		return
	if values.has(key):
		values.erase(key)
	while values.size() >= limit:
		values.erase(values.keys()[0])
	values[key] = value.duplicate(true)


func _facility_rack_hint_ui_action(
	runtime_screen: Node,
	rotation_state: Dictionary,
	continuation_plan: Dictionary
) -> Dictionary:
	if runtime_screen == null or rotation_state.is_empty():
		return {}
	var hint: Dictionary = rotation_state.get("pending_facility_rack_hint", {}) \
		if rotation_state.get("pending_facility_rack_hint", {}) is Dictionary else {}
	var phase := str(rotation_state.get("phase", ""))
	if hint.is_empty() or phase not in [
		"facility_hint_pending",
		"facility_hint_recheck",
		"close",
		"select",
		"open",
	]:
		return {}
	if not _facility_rack_hint_matches_plan(hint, continuation_plan):
		_discard_pending_facility_rack_hint(rotation_state, hint)
		_promote_next_facility_rack_hint(rotation_state, continuation_plan)
		return {}
	var screen := runtime_screen as SpaceSyndicateGameScreen
	if screen == null:
		_discard_pending_facility_rack_hint(rotation_state, hint)
		_promote_next_facility_rack_hint(rotation_state, continuation_plan)
		return {}
	var ui: Dictionary = screen.current_ui_data if screen.current_ui_data is Dictionary else {}
	var selection: Dictionary = ui.get("selection_context", {}) \
		if ui.get("selection_context", {}) is Dictionary else {}
	var selected_district := int(selection.get("selected_district", -1))
	var target_district := int(hint.get("district_index", -1))
	var target_region_id := _public_region_id_for_district(target_district)
	if target_district < 0 or target_region_id.is_empty() \
			or target_region_id != str(hint.get("region_id", "")):
		_discard_pending_facility_rack_hint(rotation_state, hint)
		_promote_next_facility_rack_hint(rotation_state, continuation_plan)
		return {}
	var drawer := _region_supply_popup(runtime_screen)
	if phase == "facility_hint_pending":
		if selected_district == target_district and drawer != null and drawer.visible:
			rotation_state["phase"] = "facility_hint_recheck"
		else:
			rotation_state["target_district"] = target_district
			rotation_state["source_selection_revision"] = int(
				selection.get("revision", -1)
			)
			rotation_state["facility_hint_reposition"] = true
			rotation_state["phase"] = "close" if drawer != null and drawer.visible \
				else ("open" if selected_district == target_district else "select")
			var navigation := _supply_rotation_action(runtime_screen, rotation_state)
			if not navigation.is_empty():
				return navigation
		phase = str(rotation_state.get("phase", ""))
	elif phase in ["close", "select", "open"] \
			and bool(rotation_state.get("facility_hint_reposition", false)):
		var navigation := _supply_rotation_action(runtime_screen, rotation_state)
		if not navigation.is_empty():
			return navigation
		phase = str(rotation_state.get("phase", ""))
	if phase != "facility_hint_recheck":
		return {}
	var snapshot := _annotate_new_facility_target_availability(
		_district_supply_view_snapshot(),
		continuation_plan
	)
	var fresh := facility_rack_hint_matches_snapshot(
		hint,
		snapshot,
		continuation_plan
	)
	_discard_pending_facility_rack_hint(rotation_state, hint, not fresh)
	if not fresh:
		_promote_next_facility_rack_hint(rotation_state, continuation_plan)
	return _district_supply_ui_action(runtime_screen, continuation_plan) if fresh else {}


static func _discard_pending_facility_rack_hint(
	rotation_state: Dictionary,
	hint: Dictionary,
	remove_district_hints := true
) -> void:
	if remove_district_hints:
		var hints: Dictionary = rotation_state.get("facility_rack_hints", {}) \
			if rotation_state.get("facility_rack_hints", {}) is Dictionary else {}
		hints = hints.duplicate(true)
		_remove_facility_rack_hints_for_district(
			hints,
			int(hint.get("district_index", -1))
		)
		rotation_state["facility_rack_hints"] = hints
	rotation_state["pending_facility_rack_hint"] = {}
	rotation_state["facility_hint_reposition"] = false
	rotation_state["phase"] = ""
	rotation_state["target_district"] = -1


static func _promote_next_facility_rack_hint(
	rotation_state: Dictionary,
	continuation_plan: Dictionary
) -> void:
	var hints: Dictionary = rotation_state.get("facility_rack_hints", {}) \
		if rotation_state.get("facility_rack_hints", {}) is Dictionary else {}
	var next_hint := first_public_facility_rack_hint_for_plan(hints, continuation_plan)
	if next_hint.is_empty():
		return
	next_hint["active_plan_signature"] = continuation_plan_signature(
		continuation_plan
	)
	rotation_state["pending_facility_rack_hint"] = next_hint
	rotation_state["phase"] = "facility_hint_pending"


static func advance_rack_advancement_after_retryable_failure(
	rotation_state: Dictionary
) -> void:
	if rotation_state.is_empty():
		return
	var candidates: Dictionary = rotation_state.get("advancement_candidate_districts", {}) \
		if rotation_state.get("advancement_candidate_districts", {}) is Dictionary else {}
	rotation_state["target_district"] = -1
	rotation_state["advancement_reposition"] = false
	rotation_state["pending_advancement_candidate"] = {}
	if candidates.is_empty():
		rotation_state["phase"] = ""
		rotation_state["advancement_epoch_active"] = false
		return
	rotation_state["phase"] = "advancement_recheck"
	rotation_state["advancement_epoch_active"] = true


func _begin_supply_rack_discovery(runtime_screen: Node, rotation_state: Dictionary) -> bool:
	var screen := runtime_screen as SpaceSyndicateGameScreen
	var drawer := _region_supply_popup(runtime_screen)
	if screen == null or drawer == null or drawer.visible:
		return false
	var ui: Dictionary = screen.current_ui_data if screen.current_ui_data is Dictionary else {}
	var selection: Dictionary = ui.get("selection_context", {}) \
		if ui.get("selection_context", {}) is Dictionary else {}
	return begin_supply_rack_discovery(
		rotation_state,
		int(selection.get("selected_district", -1)),
		int(selection.get("district_count", 0)),
		int(selection.get("revision", -1))
	)


func _begin_supply_advancement_reposition(
	runtime_screen: Node,
	rotation_state: Dictionary
) -> bool:
	var screen := runtime_screen as SpaceSyndicateGameScreen
	if screen == null:
		return false
	var ui: Dictionary = screen.current_ui_data if screen.current_ui_data is Dictionary else {}
	var selection: Dictionary = ui.get("selection_context", {}) \
		if ui.get("selection_context", {}) is Dictionary else {}
	return begin_supply_advancement_reposition(
		rotation_state,
		int(selection.get("selected_district", -1)),
		int(selection.get("district_count", 0)),
		int(selection.get("revision", -1))
	)


static func begin_supply_advancement_reposition(
	rotation_state: Dictionary,
	selected_district: int,
	district_count: int,
	selection_revision: int
) -> bool:
	var phase := str(rotation_state.get("phase", ""))
	if rotation_state.is_empty() or phase not in ["exhausted", "advancement_recheck"] \
			or phase == "advancement_recheck" \
				and not bool(rotation_state.get("advancement_epoch_active", false)) \
			or selected_district < 0 or selected_district >= district_count \
			or selection_revision < 0:
		return false
	var candidates: Dictionary = rotation_state.get("advancement_candidate_districts", {}) \
		if rotation_state.get("advancement_candidate_districts", {}) is Dictionary else {}
	candidates = candidates.duplicate(true)
	candidates.erase(selected_district)
	var ordered: Array[int] = []
	for district_variant in candidates.keys():
		var district_index := int(district_variant)
		if district_index >= 0 and district_index < district_count:
			ordered.append(district_index)
	ordered.sort()
	if ordered.is_empty():
		rotation_state["advancement_candidate_districts"] = candidates
		return false
	var target_district := ordered[0]
	var selected_candidate: Dictionary = candidates.get(target_district, {}) \
		if candidates.get(target_district, {}) is Dictionary else {}
	candidates.erase(target_district)
	rotation_state["advancement_candidate_districts"] = candidates
	rotation_state["pending_advancement_candidate"] = selected_candidate.duplicate(true)
	rotation_state["phase"] = "close"
	rotation_state["target_district"] = target_district
	rotation_state["source_selection_revision"] = selection_revision
	rotation_state["advancement_reposition"] = true
	rotation_state["advancement_epoch_active"] = true
	return true


static func begin_supply_rack_discovery(
	rotation_state: Dictionary,
	selected_district: int,
	district_count: int,
	selection_revision: int
) -> bool:
	if rotation_state.is_empty() or not str(rotation_state.get("phase", "")).is_empty() \
			or selected_district < 0 or selected_district >= district_count \
			or district_count <= 0 or selection_revision < 0:
		return false
	if int(rotation_state.get("rotation_count", 0)) >= SUPPLY_RACK_ROTATION_LIMIT:
		rotation_state["phase"] = "exhausted"
		return false
	rotation_state["phase"] = "open"
	rotation_state["target_district"] = selected_district
	rotation_state["source_rack_signature"] = ""
	rotation_state["source_selection_revision"] = selection_revision
	rotation_state["rotation_count"] = int(rotation_state.get("rotation_count", 0)) + 1
	rotation_state["advancement_reposition"] = false
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
	var drawer := _region_supply_popup(runtime_screen)
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
			return _request_with_surface_offer({
				"id": "district_supply_rotation_close",
				"phase": "play.supply.rotation_close.%d" % int(rotation_state.get("source_selection_revision", -1)),
				"disabled": false,
				"origin": "district_supply_rotation",
			}, GameActionIntentV1.ACTION_DISTRICT_SUPPLY_CLOSE)
		rotation_state["phase"] = "select"
		phase = "select"
	if phase == "select":
		if selected_district != target_district:
			var target_region_id := _public_region_id_for_district(target_district)
			return _request_with_surface_offer({
				"id": "map_select_%d" % target_district,
				"phase": "play.supply.rotation_select.%d.%d" % [selection_revision, target_district],
				"disabled": false,
				"origin": "planet_map",
				"district_index": target_district,
			}, GameActionIntentV1.ACTION_DISTRICT_SELECT, {"region_id": target_region_id})
		rotation_state["phase"] = "open"
		phase = "open"
	if phase == "open":
		if drawer != null and drawer.visible:
			if bool(rotation_state.get("facility_hint_reposition", false)):
				rotation_state["phase"] = "facility_hint_recheck"
				rotation_state["current_district"] = selected_district
				rotation_state["facility_hint_reposition"] = false
			elif bool(rotation_state.get("advancement_reposition", false)):
				rotation_state["phase"] = "advancement_recheck"
				rotation_state["current_district"] = selected_district
				rotation_state["advancement_reposition"] = false
			else:
				rotation_state["phase"] = ""
				rotation_state["target_district"] = -1
			return {}
		var open_region_id := _public_region_id_for_district(target_district)
		return _request_with_surface_offer({
			"id": "district_supply_rotation_open",
			"phase": "play.supply.rotation_open.%d.%d" % [selection_revision, target_district],
			"disabled": false,
			"origin": "district_supply_rotation",
			"district_index": target_district,
		}, GameActionIntentV1.ACTION_DISTRICT_SUPPLY_OPEN, {"region_id": open_region_id})
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


static func recoverable_selection_receipt_reason(reason_code: String) -> bool:
	return reason_code in [
		"forced_decision_blocks_selection",
		"selection_revision_stale",
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
		and bool(receipt.get("changed", false)) \
		and int(receipt.get("selection_revision_after", -1)) \
			> int(receipt.get("selection_revision_before", -1)) \
		and str(receipt.get("selection_kind", "")) == str(TableSelectionIntent.KIND_SELECT_DISTRICT) \
		and int(receipt.get("district_index", -1)) == int(pending_action.get("district_index", -2))


static func game_action_receipt_confirms_progress(
	pending_action: Dictionary,
	receipt_sequence: int,
	receipt: Dictionary
) -> bool:
	if not bool(pending_action.get("game_action_required", false)) \
			or receipt_sequence <= int(pending_action.get("game_action_receipt_sequence", -1)) \
			or not bool(GameActionReceiptV1.validation_report(receipt).get("valid", false)) \
			or not bool(receipt.get("accepted", false)) \
			or bool(receipt.get("idempotent_replay", false)) \
			or bool(receipt.get("request_id_collision", false)) \
			or int(receipt.get("authoritative_revision", 0)) \
				<= int(pending_action.get("game_action_revision_before", 0)):
		return false
	var expected_request_id := str(pending_action.get("game_action_request_id", ""))
	var expected_request_fingerprint := str(
		pending_action.get("game_action_request_fingerprint", "")
	)
	var expected_action_id := str(pending_action.get("game_action_semantic_action_id", ""))
	if expected_request_id.is_empty() \
			or expected_request_fingerprint.is_empty() \
			or expected_action_id.is_empty() \
			or str(receipt.get("request_id", "")) != expected_request_id \
			or str(receipt.get("request_fingerprint", "")) != expected_request_fingerprint \
			or str(receipt.get("semantic_action_id", "")) != expected_action_id:
		return false
	var effect_refs: Array = receipt.get("committed_effect_refs", []) \
		if receipt.get("committed_effect_refs", []) is Array else []
	return not effect_refs.is_empty()


static func action_records_economic_success(
	pending_action: Dictionary,
	game_action_progressed: bool,
	receipt: Dictionary = {}
) -> bool:
	if not game_action_progressed:
		return false
	if bool(pending_action.get("rack_advancement", false)):
		return false
	var action_id := str(pending_action.get("id", ""))
	var origin := str(pending_action.get("origin", ""))
	var effect_refs: Array = receipt.get("committed_effect_refs", []) \
		if receipt.get("committed_effect_refs", []) is Array else []
	if origin == "game_action":
		return effect_refs.any(func(effect_ref: Variant) -> bool:
			return str(effect_ref).begins_with("card.play.")
		)
	if origin == "district_supply" and action_id == "district_supply_purchase_card":
		return effect_refs.any(func(effect_ref: Variant) -> bool:
			var ref := str(effect_ref)
			return ref.begins_with("district.supply.purchase.") \
				and not ref.contains(".pending-discard.")
		)
	return false


static func rack_advancement_purchase_committed(
	pending_action: Dictionary,
	game_action_progressed: bool,
	receipt: Dictionary
) -> bool:
	if not bool(pending_action.get("rack_advancement", false)) \
			or str(pending_action.get("id", "")) != "district_supply_purchase_card" \
			or not game_action_progressed:
		return false
	var card_id := str(pending_action.get("rack_advancement_card_id", "")).strip_edges()
	if card_id.is_empty():
		return false
	var committed_effect_refs: Array = receipt.get("committed_effect_refs", []) \
		if receipt.get("committed_effect_refs", []) is Array else []
	return committed_effect_refs.has("district.supply.purchase.%s" % card_id)


static func rack_advancement_discard_receipt_committed(
	binding: Dictionary,
	receipt: Dictionary
) -> bool:
	var binding_actor := int(binding.get("actor_player_index", -1))
	var binding_card_id := str(binding.get("card_id", "")).strip_edges()
	var binding_quote_id := str(binding.get("quote_id", "")).strip_edges()
	if binding.is_empty() or binding_actor < 0 \
			or binding_card_id.is_empty() or binding_quote_id.is_empty() \
			or not bool(receipt.get("accepted", false)) \
			or not bool(receipt.get("applied", false)) \
			or bool(receipt.get("requires_discard", false)) \
			or str(receipt.get("action_kind", "")) \
				!= str(DistrictSupplyActionIntent.KIND_PURCHASE):
		return false
	return int(receipt.get("actor_player_index", -1)) == binding_actor \
		and str(receipt.get("card_id", "")) == binding_card_id \
		and str(receipt.get("quote_id", "")) == binding_quote_id


func _record_rack_advancement_purchase() -> void:
	if _rack_advancement_purchase_count >= SUPPLY_RACK_ADVANCEMENT_PURCHASE_LIMIT:
		return
	_rack_advancement_purchase_count += 1
	_action_stats["supply_rack_advancement_purchases"] = _rack_advancement_purchase_count
	_rack_advancement_reset_requested = true
	_record_reason("supply_rack_advancement_committed")


static func economy_growth_action(action: Dictionary) -> bool:
	var origin := str(action.get("origin", ""))
	var action_id := str(action.get("id", ""))
	return origin in ["district_supply", "district_supply_rotation", "planet_map"] \
		or (origin == "board_primary" and action_id.begins_with("strategy")) \
		or (origin == "game_action" \
			and str(action.get("phase", "")).begins_with("play.hand.facility_v06"))


static func economy_growth_submission_allowed(
	victory: Dictionary,
	standings_progress: Dictionary
) -> bool:
	if not bool(standings_progress.get("valid", false)):
		return false
	var victory_state := str(victory.get("state", ""))
	if victory_state not in VICTORY_STATE_IDS:
		return false
	return not bool(standings_progress.get("eligible", false)) \
		and victory_state not in ["qualification", "audit", "resolved"]


func _economy_growth_submission_allowed_now(
	coordinator: Node,
	standings_query_port: StandingsPublicQueryPort
) -> bool:
	if coordinator == null or standings_query_port == null \
			or not coordinator.has_method("victory_control_public_snapshot") \
			or not standings_query_port.has_method("victory_progress_for_authorized_viewer"):
		return false
	var victory_variant: Variant = coordinator.call("victory_control_public_snapshot", -1)
	var progress_variant: Variant = standings_query_port.call("victory_progress_for_authorized_viewer")
	_standings_progress_query_count += 1
	return economy_growth_submission_allowed(
		(victory_variant as Dictionary).duplicate(true) \
			if victory_variant is Dictionary else {},
		(progress_variant as Dictionary).duplicate(true) \
			if progress_variant is Dictionary else {}
	)


func _first_enabled_action_by_kind(value: Variant, kind: String) -> Dictionary:
	if not (value is Array):
		return {}
	for action_variant in value as Array:
		if action_variant is Dictionary:
			var action: Dictionary = action_variant
			if str(action.get("kind", "")) == kind and not str(action.get("id", "")).is_empty() and not bool(action.get("disabled", false)):
				return action.duplicate(true)
	return {}


static func facility_card_retry_signature(
	card: Dictionary,
	continuation_plan: Dictionary,
	target: Dictionary,
	failure_reason_id: String
) -> String:
	return EconomyContinuationPlannerScript.retry_signature(
		card,
		continuation_plan,
		target,
		failure_reason_id
	)


func _surface_game_action_offer(action_id: String, target_ids: Dictionary = {}) -> Dictionary:
	if _game_action_application_flow == null:
		return {}
	return _game_action_application_flow.human_surface_action_offer(
		action_id,
		target_ids,
		"full",
		["action.economy.continuation"]
	)


func _request_with_surface_offer(
	request: Dictionary,
	action_id: String,
	target_ids: Dictionary = {}
) -> Dictionary:
	if request.is_empty():
		return {}
	var offer := _surface_game_action_offer(action_id, target_ids)
	if offer.is_empty():
		return {}
	var result := request.duplicate(true)
	result["game_action_offer"] = offer
	result["game_action_required"] = true
	return result


func _board_action_request(action: Dictionary, player_board: Dictionary, signature: String = "") -> Dictionary:
	var action_signature := signature if not signature.is_empty() else _board_action_signature(action, player_board)
	var request := {
		"id": str(action.get("id", "")),
		"phase": "play.board.%s.%s" % [str(action.get("kind", "action")), str(action.get("state", "ready"))],
		"disabled": bool(action.get("disabled", false)),
		"origin": "board_primary" if str(action.get("kind", "")) in ["build_economic_source", "expand_economic_source", "open_rack", "summon_monster", "play_card", "review_economy", "protect_route", "pressure_competition"] else "board_action",
		"signature": action_signature,
	}
	var offer: Dictionary = action.get("game_action_offer", {}) \
		if action.get("game_action_offer", {}) is Dictionary else {}
	if not offer.is_empty():
		request["game_action_offer"] = offer.duplicate(true)
		request["game_action_required"] = true
	return request


func _submit_scripted_ui_action(runtime_screen: Node, action: Dictionary) -> bool:
	var action_id := str(action.get("id", ""))
	if str(action.get("origin", "")) == "temporary_decision":
		var temporary_decision_overlay := _temporary_decision_overlay(runtime_screen)
		if temporary_decision_overlay == null or action_id.is_empty():
			return false
		temporary_decision_overlay.temporary_decision_action_requested.emit(action_id)
		return true
	if str(action.get("origin", "")) == "menu_overlay":
		var menu_overlay := _menu_overlay(runtime_screen)
		if menu_overlay != null and menu_overlay.has_signal("continue_requested"):
			menu_overlay.emit_signal("continue_requested")
			return true
		return false
	var action_screen := runtime_screen as SpaceSyndicateGameScreen
	var offer: Dictionary = action.get("game_action_offer", {}) \
		if action.get("game_action_offer", {}) is Dictionary else {}
	if action_screen == null or action_id.is_empty() or offer.is_empty():
		return false
	return action_screen.submit_game_action_offer(offer, "human_click", {}, {})


func _scripted_ui_action_rejection_reason(runtime_screen: Node, action: Dictionary) -> String:
	var origin := str(action.get("origin", ""))
	if origin in ["temporary_decision", "menu_overlay"]:
		return "typed_adapter_rejected"
	var screen := runtime_screen as SpaceSyndicateGameScreen
	if screen == null:
		return "game_screen_missing"
	var offer: Dictionary = action.get("game_action_offer", {}) \
		if action.get("game_action_offer", {}) is Dictionary else {}
	if offer.is_empty():
		return "game_action_offer_missing"
	var validation := GameActionOfferV1.validation_report(offer)
	if not bool(validation.get("valid", false)):
		return "game_action_offer_%s" % str(validation.get("reason_code", "invalid"))
	if str(offer.get("legality_state", "")) != "available":
		return "game_action_offer_unavailable"
	var authorization := screen.game_action_actor_authorization("human_click")
	if authorization.is_empty():
		return "actor_authorization_missing"
	var probe_raw := {
		"schema_version": GameActionIntentV1.SCHEMA_VERSION,
		"request_id": "full-run-action-probe",
		"semantic_action_id": str(offer.get("semantic_action_id", "")),
		"source_revision": int(offer.get("source_revision", 0)),
		"actor_authorization": authorization,
		"target_ids": GameActionOfferV1.target_ids(offer),
		"parameters": {},
		"submission_kind": "human_click",
	}
	var probe := SemanticWireV1.sealed_copy(probe_raw, "intent_fingerprint")
	var intent_validation := GameActionIntentV1.validation_report(probe)
	if not bool(intent_validation.get("valid", false)):
		return str(intent_validation.get("reason_id", "game_action_intent_invalid"))
	if not GameActionOfferV1.accepts_intent(offer, probe):
		return "game_action_offer_intent_binding_rejected"
	return "game_action_adapter_rejected"


func _temporary_decision_overlay(runtime_screen: Node) -> SpaceSyndicateOverlayLayer:
	var screen := runtime_screen as SpaceSyndicateGameScreen
	if screen == null:
		return null
	return screen.get_overlay_host() as SpaceSyndicateOverlayLayer


func _region_supply_popup(runtime_screen: Node) -> Node:
	if runtime_screen == null:
		return null
	return runtime_screen.get_node_or_null("RegionSupplyPopup")


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


func _on_game_action_receipt(receipt: Dictionary) -> void:
	if not bool(GameActionReceiptV1.validation_report(receipt).get("valid", false)):
		return
	_game_action_receipt_sequence += 1
	_last_game_action_receipt = GameActionReceiptV1.detached_copy(receipt)


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
		"actor_player_index": receipt.actor_player_index,
		"district_index": receipt.district_index,
		"card_id": receipt.card_id,
		"quote_id": receipt.quote_id,
		"requires_discard": receipt.requires_discard,
	}
	if rack_advancement_discard_receipt_committed(
		_pending_rack_advancement_discard,
		_last_district_supply_receipt
	):
		_pending_rack_advancement_discard = {}
		_record_rack_advancement_purchase()
	elif not _pending_rack_advancement_discard.is_empty() \
			and str(receipt.action_kind) == str(DistrictSupplyActionIntent.KIND_DISCARD_CANCEL) \
			and receipt.accepted and receipt.applied:
		_pending_rack_advancement_discard = {}
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
		"changed": receipt.changed,
		"reason_code": receipt.reason_code,
		"selection_kind": str(receipt.selection_kind),
		"district_index": receipt.district_index,
		"selection_revision_before": receipt.selection_revision_before,
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
		"economy_plan_exhausted":
			var exhausted_signature := str(
				action.get("exhausted_plan_signature", "")
			).strip_edges()
			var next_plan: Dictionary = action.get("next_plan", {}) \
				if action.get("next_plan", {}) is Dictionary else {}
			var next_signature := continuation_plan_signature(next_plan)
			if exhausted_signature.is_empty() or next_signature.is_empty() \
					or not bool(next_plan.get("ready", false)) \
					or bool(next_plan.get("stop", true)):
				return false
			_remember_bounded_signature(
				_exhausted_economy_plan_signatures,
				exhausted_signature,
				SUPPLY_EVALUATED_RACK_SIGNATURE_LIMIT
			)
			_economy_plan_override_signature = next_signature
			_latest_economy_continuation_plan = next_plan.duplicate(true)
			return true
		"facility_candidate_rejected":
			var attempt_signature := str(action.get("candidate_attempt_signature", "")).strip_edges()
			if attempt_signature.is_empty():
				return false
			_remember_bounded_signature(
				_facility_candidate_attempts,
				attempt_signature,
				FACILITY_CANDIDATE_ATTEMPT_LIMIT
			)
			return true
	return false


func _next_typed_facility_map_action(
	runtime_screen: Node,
	card: Dictionary,
	continuation_plan: Dictionary,
	failure_reason_id: String
) -> Dictionary:
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
	var scoped_plan := continuation_plan.duplicate(true)
	scoped_plan["target_source_revision"] = maxi(0, int(target.get("source_revision", 0)))
	var candidates := EconomyContinuationPlannerScript.matching_target_candidates(
		target.get("candidates", []) as Array,
		_public_region_commodity_facts(),
		scoped_plan
	)
	if candidates.is_empty():
		return {
			"id": "facility_play_wait",
			"phase": "play.hand.facility_v06.wait.no_matching_public_target.%d" \
				% int(target.get("source_revision", 0)),
			"disabled": true,
			"origin": "economic_wait",
		}
	for candidate_variant in candidates:
		if not (candidate_variant is Dictionary):
			continue
		var selected_candidate := candidate_variant as Dictionary
		if int(selected_candidate.get("public_index", -1)) != selected_district:
			continue
		var selected_attempt_signature := facility_card_retry_signature(
			card,
			scoped_plan,
			selected_candidate,
			failure_reason_id
		)
		if not selected_attempt_signature.is_empty() \
				and not bool(_facility_candidate_attempts.get(selected_attempt_signature, false)):
			return {
				"id": "facility_candidate_rejected",
				"phase": "driver.facility_candidate_rejected.%d" % selected_district,
				"disabled": false,
				"origin": "driver_planning",
				"candidate_attempt_signature": selected_attempt_signature,
			}
	var candidate := next_public_facility_candidate(
		candidates,
		_facility_candidate_attempts,
		card,
		scoped_plan,
		failure_reason_id
	)
	if candidate.is_empty():
		return {
			"id": "facility_play_wait",
			"phase": "play.hand.facility_v06.wait.targets_exhausted.%d" \
				% int(target.get("source_revision", 0)),
			"disabled": true,
			"origin": "economic_wait",
		}
	var target_district := int(candidate.get("public_index", -1))
	return _request_with_surface_offer({
		"id": "map_select_%d" % target_district,
		"phase": "play.map.%d_to_%d" % [selected_district, target_district],
		"disabled": false,
		"origin": "planet_map",
		"district_index": target_district,
	}, GameActionIntentV1.ACTION_DISTRICT_SELECT, {
		"region_id": str(candidate.get("region_id", "")),
	})


static func next_public_facility_candidate(
	candidates: Array,
	attempted: Dictionary,
	card: Dictionary,
	continuation_plan: Dictionary,
	failure_reason_id: String
) -> Dictionary:
	for candidate_variant in candidates:
		if not (candidate_variant is Dictionary):
			continue
		var candidate := candidate_variant as Dictionary
		var public_index := int(candidate.get("public_index", -1))
		var attempt_signature := facility_card_retry_signature(
			card,
			continuation_plan,
			candidate,
			failure_reason_id
		)
		if public_index >= 0 and not attempt_signature.is_empty() \
				and not bool(attempted.get(attempt_signature, false)):
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
	return _request_with_surface_offer({
		"id": "map_select_%d" % next_district,
		"phase": "play.map.%d_to_%d" % [selected_district, next_district],
		"disabled": false,
		"origin": "planet_map",
		"district_index": next_district,
	}, GameActionIntentV1.ACTION_DISTRICT_SELECT, {
		"region_id": _public_region_id_for_district(next_district),
	})


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


static func _first_enabled_action(value: Variant) -> Dictionary:
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
			and is_zero_approx(float((telemetry.get("settlement", {}) as Dictionary).get("terminal_world_delta", -1.0))) \
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
		"economy_continuation": {
			"observation": PublicEconomyContinuationObservationScript.detached_copy(
				_latest_economy_continuation_observation
			),
			"plan": _latest_economy_continuation_plan.duplicate(true),
		},
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
		"authoritative_step_limit": AUTHORITATIVE_WAIT_MAX_STEP_LIMIT,
		"authoritative_base_step_limit": AUTHORITATIVE_WAIT_BASE_STEP_LIMIT,
		"authoritative_max_step_limit": AUTHORITATIVE_WAIT_MAX_STEP_LIMIT,
		"authoritative_progress_stall_window_steps": AUTHORITATIVE_PROGRESS_STALL_WINDOW_STEPS,
		"authoritative_world_effective_time_limit_seconds": AUTHORITATIVE_WORLD_EFFECTIVE_TIME_LIMIT_SECONDS,
		"authoritative_last_progress_step": _authoritative_last_progress_step,
		"authoritative_steps_since_progress": maxi(0, _authoritative_step_attempt_count - _authoritative_last_progress_step),
		"authoritative_last_progress_reason": _authoritative_last_progress_reason,
		"authoritative_progress_extension_used": _authoritative_step_attempt_count > AUTHORITATIVE_WAIT_BASE_STEP_LIMIT,
		"authoritative_progress_checkpoint_count": _authoritative_progress_checkpoints.size(),
		"authoritative_progress_checkpoint_fingerprint": JSON.stringify(_authoritative_progress_checkpoints).sha256_text() if not _authoritative_progress_checkpoints.is_empty() else "",
		"authoritative_last_progress_checkpoint": (_authoritative_progress_checkpoints[-1] as Dictionary).duplicate(true) if not _authoritative_progress_checkpoints.is_empty() else {},
		"production_maturity_checkpoint": _production_maturity_checkpoint.duplicate(true),
		"post_eligibility_production_installation_delta": _post_eligibility_production_installation_delta,
		"blocked_realtime_step_batch_count": _blocked_realtime_step_batch_count,
		"blocked_realtime_step_attempt_count": _blocked_realtime_step_attempt_count,
		"blocked_realtime_step_count": _blocked_realtime_step_count,
		"blocked_realtime_seconds": _blocked_realtime_seconds,
		"blocked_realtime_step_limit": BLOCKED_REALTIME_TOTAL_STEP_LIMIT,
		"blocked_realtime_precondition_end_count": _blocked_realtime_precondition_end_count,
		"blocked_realtime_invariant_failure_count": _blocked_realtime_invariant_failure_count,
		"blocked_realtime_wall_msec_total": _blocked_realtime_wall_msec_total,
		"blocked_realtime_wall_msec_max": _blocked_realtime_wall_msec_max,
		"game_action_receipt_count": _game_action_receipt_sequence,
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
		"world_delta": 0.0 if verified else -1.0,
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
			"matched_economy_chain": _matched_economy_chain_evidence.duplicate(true),
			"timer_evidence": timer_evidence,
			"actions": _action_stats.duplicate(true),
			"peak_production_installation_count": _peak_production_installation_count,
			"post_eligibility_production_installation_delta": _post_eligibility_production_installation_delta,
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
	var matched_chain: Dictionary = stable.get("matched_economy_chain", {}) if stable.get("matched_economy_chain", {}) is Dictionary else {}
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
		and bool(matched_chain.get("observed", false)) \
		and int(matched_chain.get("matched_commodity_count", 0)) > 0 \
		and int(matched_chain.get("settled_matched_commodity_count", 0)) > 0 \
		and str(matched_chain.get("fingerprint", "")).length() == 64 \
		and int(stable.get("post_eligibility_production_installation_delta", -1)) == 0 \
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
				accepted = _assign_integer_option(result, "max_wall_seconds", argument.trim_prefix("--max-wall-seconds="), 1, MAX_WALL_SECONDS_LIMIT)
			result["valid"] = bool(result.get("valid", true)) and accepted
		elif argument == "--max-wall-seconds":
			var accepted := _claim_option(seen_options, "max_wall_seconds")
			index += 1
			if index >= arguments.size():
				accepted = false
			elif accepted:
				accepted = _assign_integer_option(result, "max_wall_seconds", str(arguments[index]), 1, MAX_WALL_SECONDS_LIMIT)
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
