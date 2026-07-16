extends SceneTree

const FullRunQualitySnapshotScript := preload("res://scripts/viewmodels/full_run_quality_snapshot.gd")

const DRIVER_SCHEMA := 2
const DRIVER_ID := "full_run_quality_driver_v2"
const SEED_ALGORITHM := "space-syndicate-full-run-quality-v1:sha256-positive31"
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const COORDINATOR_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator"
const SESSION_PATH := "GameSessionRuntimeController"
const REGISTRY_PATH := "V06SaveOwnerRegistry"
const SAVE_COORDINATOR_PATH := "GameSaveRuntimeCoordinator"
const SETTLEMENT_PATH := "RuntimeServices/FinalSettlementRuntimeComposition"
const RUNTIME_SCREEN_PATH := "RuntimeGameScreen"
const QA_SAVE_ROOT := "user://test_runs/full_run_quality/"
const REQUIRED_SECTION_COUNT := 18
const SCRIPTED_PLAYER_INDEX := 0
const RECOMMENDED_PLAYER_COUNT := 4
const RECOMMENDED_AI_COUNT := 3
const HEARTBEAT_INTERVAL_SECONDS := 2.0
const ACTION_PROGRESS_TIMEOUT_SECONDS := 3.0
const NO_ACTION_TIMEOUT_SECONDS := 1.5
const DEFAULT_OBSERVATION_SECONDS := 12
const DEFAULT_MAX_WALL_SECONDS := 30
const SIMULATION_TIME_SCALE := 16.0
const WAIT_SIMULATION_TIME_SCALE := 128.0
const ACTION_ENGINE_TIME_SCALE := 2.0
const SUPPLY_WAIT_ENGINE_TIME_SCALE := 8.0
const GDP_WAIT_ENGINE_TIME_SCALE := 8.0
const SUPPLY_QUOTE_REFRESH_INTERVAL_MSEC := 1000
const EXIT_INVALID_ARGUMENTS := 2
const EXIT_CAPABILITY_INCOMPLETE := 3
const EXIT_OBSERVATION_INCOMPLETE := 4
const EXIT_RUNTIME_COMPOSITION_UNAVAILABLE := 5
const EXIT_NONFINITE := 6

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
]

var _started_msec := 0
var _heartbeat_sequence := 0
var _last_event := "driver_started"
var _last_progress_feedback := ""
var _action_stats := {
	"attempted": 0,
	"progressed": 0,
	"rejected_invalid": 0,
	"supply_quote_refreshes": 0,
	"reason_codes": {},
}


func _init() -> void:
	_started_msec = Time.get_ticks_msec()
	call_deferred("_run")


func _run() -> void:
	var options := _parse_options(_driver_arguments(OS.get_cmdline_args()))
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
	var registry := session.get_node_or_null(REGISTRY_PATH) if session != null else null
	var runtime_screen := main_instance.get_node_or_null(RUNTIME_SCREEN_PATH)
	var settlement_composition := main_instance.get_node_or_null(SETTLEMENT_PATH)
	var capability := _capability_preflight(main_instance, coordinator, session, registry, runtime_screen, settlement_composition, qa_path_ready)
	var public_capability: Dictionary = capability.get("public", {}) if capability.get("public", {}) is Dictionary else {}
	var preflight_telemetry := _collect_telemetry(
		run_seed,
		coordinator,
		session,
		settlement_composition,
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
		var start_failed := _collect_telemetry(run_seed, coordinator, session, settlement_composition, runtime_screen, _started_msec, _last_event)
		_cleanup_main(main_instance, save_coordinator)
		_emit_summary(_summary(options, start_failed, "blocked_by_capability", str(start_result.get("reason_code", "session_start_failed")), public_capability, _save_status(public_capability)))
		quit(EXIT_CAPABILITY_INCOMPLETE)
		return

	_last_event = "session_started"
	main_instance.set("time_scale", SIMULATION_TIME_SCALE)
	var observation_started_msec := Time.get_ticks_msec()
	var observation_limit_msec := int(options.get("observation_seconds", DEFAULT_OBSERVATION_SECONDS)) * 1000
	var max_wall_msec := int(options.get("max_wall_seconds", DEFAULT_MAX_WALL_SECONDS)) * 1000
	var last_heartbeat_msec := observation_started_msec
	var no_action_since_msec := observation_started_msec
	var pending_action: Dictionary = {}
	var exhausted_navigation_actions: Dictionary = {}
	var last_supply_quote_refresh_msec := 0
	var final_status := "incomplete"
	var failure_code := "observation_window_elapsed_before_settlement"
	var final_telemetry := _collect_telemetry(run_seed, coordinator, session, settlement_composition, runtime_screen, observation_started_msec, _last_event)

	while true:
		await process_frame
		var now_msec := Time.get_ticks_msec()
		var public_progress: Dictionary = final_telemetry.get("progress", {}) if final_telemetry.get("progress", {}) is Dictionary else {}
		var ui_action := _scripted_ui_action(runtime_screen, exhausted_navigation_actions, public_progress)
		if _session_state(session) == "running":
			var waiting_action_id := str(ui_action.get("id", "")) if bool(ui_action.get("disabled", false)) else ""
			var waiting_for_world := waiting_action_id in ["district_supply_wait", "gdp_accumulation_wait"]
			main_instance.set("time_scale", WAIT_SIMULATION_TIME_SCALE if waiting_for_world else SIMULATION_TIME_SCALE)
			Engine.time_scale = GDP_WAIT_ENGINE_TIME_SCALE if waiting_action_id == "gdp_accumulation_wait" else (SUPPLY_WAIT_ENGINE_TIME_SCALE if waiting_action_id == "district_supply_wait" else ACTION_ENGINE_TIME_SCALE)
		final_telemetry = _collect_telemetry(run_seed, coordinator, session, settlement_composition, runtime_screen, observation_started_msec, _last_event)
		if int((final_telemetry.get("nonfinite", {}) as Dictionary).get("count", 0)) > 0:
			final_status = "failed"
			failure_code = "nonfinite_public_runtime_fact"
			_last_event = "blocked:nonfinite_public_runtime_fact"
			break
		if bool((final_telemetry.get("settlement", {}) as Dictionary).get("completed", false)):
			final_status = "settled"
			failure_code = ""
			_last_event = "settlement_completed"
			break

		if not pending_action.is_empty():
			var pending_id := str(pending_action.get("id", ""))
			var pending_phase := str(pending_action.get("phase", ""))
			var action_progressed := str(ui_action.get("id", "")) != pending_id or str(ui_action.get("phase", "")) != pending_phase
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
				_action_stats["rejected_invalid"] = int(_action_stats.get("rejected_invalid", 0)) + 1
				failure_code = "scripted_ui_action_no_progress:%s" % pending_id
				_record_reason("scripted_ui_action_no_progress")
				_last_event = "blocked:%s" % failure_code
				final_status = "blocked"
				break

		if pending_action.is_empty():
			var action_id := str(ui_action.get("id", ""))
			if not action_id.is_empty() and not bool(ui_action.get("disabled", false)):
				_submit_scripted_ui_action(runtime_screen, ui_action)
				_action_stats["attempted"] = int(_action_stats.get("attempted", 0)) + 1
				_last_event = "action_requested:%s:after:%s" % [action_id, _last_progress_feedback]
				pending_action = {
					"id": action_id,
					"phase": str(ui_action.get("phase", "play")),
					"origin": str(ui_action.get("origin", "")),
					"signature": str(ui_action.get("signature", "")),
					"requested_msec": now_msec,
				}
				no_action_since_msec = now_msec
			elif action_id in ["district_supply_wait", "gdp_accumulation_wait"] and bool(ui_action.get("disabled", false)):
				if action_id == "district_supply_wait" and now_msec - last_supply_quote_refresh_msec >= SUPPLY_QUOTE_REFRESH_INTERVAL_MSEC:
					if _refresh_visible_supply_quote(runtime_screen):
						_action_stats["supply_quote_refreshes"] = int(_action_stats.get("supply_quote_refreshes", 0)) + 1
					last_supply_quote_refresh_msec = now_msec
				_last_event = "waiting:district_supply_quote_availability" if action_id == "district_supply_wait" else "waiting:gdp_accumulation_and_victory_qualification"
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
		if now_msec - observation_started_msec >= observation_limit_msec:
			failure_code = "observation_window_elapsed_during_action" if not pending_action.is_empty() else "observation_window_elapsed_before_settlement"
			_last_event = "blocked:%s" % failure_code
			break
		if now_msec - _started_msec >= max_wall_msec:
			failure_code = "driver_wall_timeout"
			_last_event = "blocked:driver_wall_timeout"
			break

	final_telemetry = _collect_telemetry(run_seed, coordinator, session, settlement_composition, runtime_screen, observation_started_msec, _last_event)
	_emit_heartbeat(seed_index, final_telemetry, final_status)
	_cleanup_main(main_instance, save_coordinator)
	_emit_summary(_summary(options, final_telemetry, final_status, failure_code, public_capability, _save_status(public_capability)))
	if final_status == "settled":
		quit(0)
	elif failure_code == "nonfinite_public_runtime_fact":
		quit(EXIT_NONFINITE)
	else:
		quit(EXIT_OBSERVATION_INCOMPLETE)


func _start_fixed_seed_run(main_instance: Node, session: Node, run_seed: int) -> Dictionary:
	if not main_instance.has_method("_confirm_start_new_run_from_setup"):
		return {"started": false, "reason_code": "main_setup_api_unavailable"}
	main_instance.set("configured_player_count", RECOMMENDED_PLAYER_COUNT)
	main_instance.set("configured_ai_player_count", RECOMMENDED_AI_COUNT)
	main_instance.set("configured_roguelike_depth", 1)
	main_instance.set("configured_role_indices", [0, 1, 2, 3])
	main_instance.set("configured_starter_monster_indices", [0, 1, 2, 3])
	var rng_variant: Variant = main_instance.get("rng")
	if not (rng_variant is RandomNumberGenerator):
		return {"started": false, "reason_code": "main_rng_unavailable"}
	(rng_variant as RandomNumberGenerator).seed = run_seed
	main_instance.call("_confirm_start_new_run_from_setup")
	await _wait_frames(10)
	var players_variant: Variant = main_instance.get("players")
	var players: Array = players_variant if players_variant is Array else []
	var ai_count := 0
	for player_variant in players:
		if player_variant is Dictionary and bool((player_variant as Dictionary).get("is_ai", false)):
			ai_count += 1
	var session_state := _session_state(session)
	return {
		"started": players.size() == RECOMMENDED_PLAYER_COUNT and ai_count == RECOMMENDED_AI_COUNT and session_state == "running",
		"reason_code": "" if players.size() == RECOMMENDED_PLAYER_COUNT and ai_count == RECOMMENDED_AI_COUNT and session_state == "running" else "normal_session_not_running",
	}


func _capability_preflight(main_instance: Node, coordinator: Node, session: Node, registry: Node, runtime_screen: Node, settlement_composition: Node, qa_path_ready: bool) -> Dictionary:
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
	var scripted_ui_port_ready := runtime_screen != null and runtime_screen.has_signal("action_requested")
	var setup_ready := main_instance.has_method("_confirm_start_new_run_from_setup")
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
		},
	}


func _collect_telemetry(run_seed: int, coordinator: Node, session: Node, settlement_composition: Node, runtime_screen: Node, run_started_msec: int, last_event: String) -> Dictionary:
	var clock: Dictionary = {}
	var victory: Dictionary = {}
	var decision: Dictionary = {}
	var own_candidate: Dictionary = {}
	var victory_rule: Dictionary = {}
	var economic_source: Dictionary = {}
	if coordinator != null and coordinator.has_method("world_effective_clock_snapshot"):
		var clock_variant: Variant = coordinator.call("world_effective_clock_snapshot")
		clock = (clock_variant as Dictionary).duplicate(true) if clock_variant is Dictionary else {}
	if coordinator != null and coordinator.has_method("victory_control_public_snapshot"):
		var victory_variant: Variant = coordinator.call("victory_control_public_snapshot", -1)
		victory = (victory_variant as Dictionary).duplicate(true) if victory_variant is Dictionary else {}
	if coordinator != null and coordinator.has_method("active_forced_decision"):
		var decision_variant: Variant = coordinator.call("active_forced_decision", SCRIPTED_PLAYER_INDEX)
		decision = (decision_variant as Dictionary).duplicate(true) if decision_variant is Dictionary else {}
	if coordinator != null and coordinator.has_method("victory_control_private_snapshot"):
		var private_victory_variant: Variant = coordinator.call("victory_control_private_snapshot", SCRIPTED_PLAYER_INDEX)
		var private_victory: Dictionary = private_victory_variant if private_victory_variant is Dictionary else {}
		own_candidate = (private_victory.get("own_candidate", {}) as Dictionary).duplicate(true) if private_victory.get("own_candidate", {}) is Dictionary else {}
		victory_rule = (private_victory.get("victory_rule", {}) as Dictionary).duplicate(true) if private_victory.get("victory_rule", {}) is Dictionary else {}
	if victory_rule.is_empty() and victory.get("victory_rule", {}) is Dictionary:
		victory_rule = (victory.get("victory_rule", {}) as Dictionary).duplicate(true)
	if coordinator != null and coordinator.has_method("actor_id_for_player_index") and coordinator.has_method("economic_source_snapshot"):
		var actor_binding_variant: Variant = coordinator.call("actor_id_for_player_index", SCRIPTED_PLAYER_INDEX)
		var actor_binding: Dictionary = actor_binding_variant if actor_binding_variant is Dictionary else {}
		if bool(actor_binding.get("available", false)):
			var source_variant: Variant = coordinator.call("economic_source_snapshot", str(actor_binding.get("actor_id", "")))
			economic_source = source_variant if source_variant is Dictionary else {}
	var public_progress := {
		"controlled_region_count": int(own_candidate.get("controlled_region_count", 0)),
		"required_region_count": int(victory_rule.get("required_region_count", 0)),
		"top_k_gdp_per_minute": int(own_candidate.get("top_k_gdp_per_minute", 0)),
		"required_top_k_gdp_per_minute": int(victory_rule.get("required_top_k_gdp_per_minute", 0)),
		"owned_facility_count": int(economic_source.get("owned_facility_count", 0)),
		"eligible": bool(own_candidate.get("eligible", false)),
	}
	var ui_action := _scripted_ui_action(runtime_screen, {}, public_progress)
	var session_state := _session_state(session)
	var settlement := _settlement_snapshot(victory, settlement_composition, session_state)
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
			},
			"progress": {
				"controlled_region_count": float(own_candidate.get("controlled_region_count", 0)),
				"top_k_gdp_per_minute": float(own_candidate.get("top_k_gdp_per_minute", 0)),
			},
			"decision": {"opened_sequence": float(decision.get("opened_sequence", 0.0))},
		},
	})


func _settlement_snapshot(victory: Dictionary, settlement_composition: Node, session_state: String) -> Dictionary:
	var outcome: Dictionary = victory.get("outcome_receipt", {}) if victory.get("outcome_receipt", {}) is Dictionary else {}
	var debug: Dictionary = {}
	if settlement_composition != null and settlement_composition.has_method("debug_snapshot"):
		var debug_variant: Variant = settlement_composition.call("debug_snapshot")
		debug = (debug_variant as Dictionary).duplicate(true) if debug_variant is Dictionary else {}
	var outcome_id := str(outcome.get("outcome_id", ""))
	var presentation_ready := not outcome_id.is_empty() and int(debug.get("present_count", 0)) > 0
	return {
		"state": str(victory.get("state", "idle")),
		"completed": str(victory.get("state", "")) == "resolved" and not outcome_id.is_empty() and session_state == "finished" and presentation_ready,
		"outcome_id": outcome_id,
		"reason_code": str(outcome.get("reason_code", "")),
		"winner_count": (outcome.get("winner_player_indices", []) as Array).size() if outcome.get("winner_player_indices", []) is Array else 0,
		"presentation_ready": presentation_ready,
	}


func _scripted_ui_action(runtime_screen: Node, exhausted_navigation_actions: Dictionary = {}, public_progress: Dictionary = {}) -> Dictionary:
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
			}
	var source_established := false
	var strategy_actions: Array[Dictionary] = []
	for strategy_kind in ["expand_economic_source", "protect_route", "pressure_competition"]:
		var strategy_action := _first_enabled_action_by_kind(player_board.get("actions", []), strategy_kind)
		if strategy_action.is_empty():
			continue
		source_established = true
		strategy_actions.append(strategy_action)
	# Four canonical Rank-I listings complete the first factory/market pair. Let
	# CommodityFlow emit a real Sale Receipt before opening another purchase.
	if int(public_progress.get("owned_facility_count", 0)) >= 4 \
			and int(public_progress.get("top_k_gdp_per_minute", 0)) <= 0:
		return {
			"id": "gdp_accumulation_wait",
			"phase": "play.gdp_first_receipt",
			"disabled": true,
			"origin": "economic_wait",
		}
	var facility_hand_action := _first_enabled_card_action_by_kind(hand_cards, "facility_v06")
	if not facility_hand_action.is_empty():
		return facility_hand_action
	var visible_supply_action := _district_supply_ui_action(runtime_screen)
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
	var supply_action := _district_supply_ui_action(runtime_screen)
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


func _district_supply_ui_action(runtime_screen: Node) -> Dictionary:
	var drawer := _district_supply_drawer(runtime_screen)
	if drawer == null or not drawer.visible or not drawer.has_method("debug_snapshot") or not drawer.has_signal("supply_action_requested"):
		return {}
	var snapshot_variant: Variant = drawer.call("debug_snapshot")
	var snapshot: Dictionary = snapshot_variant if snapshot_variant is Dictionary else {}
	var preview: Dictionary = snapshot.get("preview", {}) if snapshot.get("preview", {}) is Dictionary else {}
	var preview_card_name := str(preview.get("card_name", ""))
	if not preview_card_name.is_empty() and bool(preview.get("buy_enabled", false)):
		return {
			"id": "district_supply_purchase_card",
			"phase": "play.supply.purchase.%s" % preview_card_name,
			"disabled": false,
			"origin": "district_supply",
			"payload": {"card_name": preview_card_name, "source": "full_run_visible_preview"},
		}
	var cards: Array = snapshot.get("cards", []) if snapshot.get("cards", []) is Array else []
	var retry_next_facility := str(preview.get("action_reason_code", "")) in [
		"source_region_dark",
		"source_region_destroyed",
		"market_listing_changed",
		"market_quote_unavailable",
		"quote_expired",
	]
	var facility_card := _next_supply_card_of_kind(cards, "facility_v06", preview_card_name if retry_next_facility else "")
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
	} if drawer.visible else {}


func _refresh_visible_supply_quote(runtime_screen: Node) -> bool:
	var drawer := _district_supply_drawer(runtime_screen)
	if drawer == null or not drawer.visible or not drawer.has_method("debug_snapshot") or not drawer.has_signal("supply_action_requested"):
		return false
	var snapshot_variant: Variant = drawer.call("debug_snapshot")
	var snapshot: Dictionary = snapshot_variant if snapshot_variant is Dictionary else {}
	var preview: Dictionary = snapshot.get("preview", {}) if snapshot.get("preview", {}) is Dictionary else {}
	var card_name := str(preview.get("card_name", "")).strip_edges()
	if card_name.is_empty() or bool(preview.get("buy_enabled", false)):
		return false
	drawer.emit_signal("supply_action_requested", "district_supply_preview_card", {"card_name": card_name, "source": "full_run_quote_refresh"})
	return true


func _next_supply_card_of_kind(cards: Array, kind: String, after_card_name: String = "") -> Dictionary:
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


func _first_enabled_card_action_by_kind(cards: Array, kind: String) -> Dictionary:
	for card_variant in cards:
		if not (card_variant is Dictionary):
			continue
		var card: Dictionary = card_variant
		if str(card.get("kind", "")) != kind:
			continue
		var action := _first_enabled_action(card.get("actions", []))
		if not action.is_empty():
			return {
				"id": str(action.get("id", "")),
				"phase": "play.hand.%s.%s" % [kind, str(card.get("action_state", card.get("play_state", "ready")))],
				"disabled": false,
			}
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


func _submit_scripted_ui_action(runtime_screen: Node, action: Dictionary) -> void:
	if str(action.get("origin", "")) == "menu_overlay":
		var menu_overlay := _menu_overlay(runtime_screen)
		if menu_overlay != null and menu_overlay.has_signal("continue_requested"):
			menu_overlay.emit_signal("continue_requested")
		return
	if str(action.get("origin", "")) == "district_supply":
		var drawer := _district_supply_drawer(runtime_screen)
		if drawer != null and drawer.has_signal("supply_action_requested"):
			drawer.emit_signal("supply_action_requested", str(action.get("id", "")), (action.get("payload", {}) as Dictionary).duplicate(true))
		return
	if str(action.get("origin", "")) == "planet_map":
		var map_view: Control = runtime_screen.call("get_embedded_map_view") if runtime_screen.has_method("get_embedded_map_view") else null
		if map_view != null and map_view.has_signal("district_selected"):
			map_view.emit_signal("district_selected", int(action.get("district_index", -1)))
		return
	runtime_screen.emit_signal("action_requested", str(action.get("id", "")))


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


func _next_public_map_action(runtime_screen: Node) -> Dictionary:
	var map_view: Control = runtime_screen.call("get_embedded_map_view") if runtime_screen.has_method("get_embedded_map_view") else null
	if map_view == null or not map_view.has_method("get_sceneization_debug_snapshot") or not map_view.has_signal("district_selected"):
		return {}
	var snapshot_variant: Variant = map_view.call("get_sceneization_debug_snapshot")
	var snapshot: Dictionary = snapshot_variant if snapshot_variant is Dictionary else {}
	var district_count := int(snapshot.get("district_count", 0))
	if district_count <= 1:
		return {}
	var selected_district := int(snapshot.get("selected_district", -1))
	var next_district := wrapi(selected_district + 1, 0, district_count)
	return {
		"id": "map_select_%d" % next_district,
		"phase": "play.map.%d_to_%d" % [selected_district, next_district],
		"disabled": false,
		"origin": "planet_map",
		"district_index": next_district,
	}


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
	if session == null or not session.has_method("session_summary"):
		return "unavailable"
	var summary_variant: Variant = session.call("session_summary")
	var summary: Dictionary = summary_variant if summary_variant is Dictionary else {}
	return str(summary.get("session_state", "unavailable"))


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
		"completed": bool((telemetry.get("settlement", {}) as Dictionary).get("completed", false)),
		"status": status,
		"failure_code": failure_code,
		"qa_save_scope": qa_save_directory(_head_token(), FIXED_SEEDS[seed_index]),
		"capability": capability.duplicate(true),
		"save": save_status.duplicate(true),
		"actions": _action_stats.duplicate(true),
		"wall_ms": maxi(0, Time.get_ticks_msec() - _started_msec),
	}
	for key_variant in FullRunQualitySnapshotScript.PUBLIC_KEYS:
		var key := str(key_variant)
		if key in ["schema", "seed"]:
			continue
		result[key] = telemetry.get(key)
	return result


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


func _parse_options(arguments: PackedStringArray) -> Dictionary:
	var result := {
		"valid": true,
		"preflight_only": false,
		"seed_index": 0,
		"observation_seconds": DEFAULT_OBSERVATION_SECONDS,
		"max_wall_seconds": DEFAULT_MAX_WALL_SECONDS,
	}
	var index := 0
	while index < arguments.size():
		var argument := str(arguments[index])
		if argument == "--preflight-only":
			result["preflight_only"] = true
		elif argument.begins_with("--seed-index="):
			result["valid"] = _assign_integer_option(result, "seed_index", argument.trim_prefix("--seed-index="), 0, FIXED_SEEDS.size() - 1) and bool(result.get("valid", true))
		elif argument == "--seed-index":
			index += 1
			result["valid"] = index < arguments.size() and _assign_integer_option(result, "seed_index", str(arguments[index]), 0, FIXED_SEEDS.size() - 1) and bool(result.get("valid", true))
		elif argument.begins_with("--observation-seconds="):
			result["valid"] = _assign_integer_option(result, "observation_seconds", argument.trim_prefix("--observation-seconds="), 1, 3600) and bool(result.get("valid", true))
		elif argument == "--observation-seconds":
			index += 1
			result["valid"] = index < arguments.size() and _assign_integer_option(result, "observation_seconds", str(arguments[index]), 1, 3600) and bool(result.get("valid", true))
		elif argument.begins_with("--max-wall-seconds="):
			result["valid"] = _assign_integer_option(result, "max_wall_seconds", argument.trim_prefix("--max-wall-seconds="), 1, 86400) and bool(result.get("valid", true))
		elif argument == "--max-wall-seconds":
			index += 1
			result["valid"] = index < arguments.size() and _assign_integer_option(result, "max_wall_seconds", str(arguments[index]), 1, 86400) and bool(result.get("valid", true))
		else:
			result["valid"] = false
		index += 1
	if int(result.get("observation_seconds", 1)) >= int(result.get("max_wall_seconds", 1)):
		result["valid"] = false
	return result


func _driver_arguments(arguments: PackedStringArray) -> PackedStringArray:
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
		index += 1
	return result


func _assign_integer_option(target: Dictionary, key: String, text: String, minimum: int, maximum: int) -> bool:
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
