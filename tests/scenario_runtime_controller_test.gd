extends SceneTree

const CONTROLLER_SCENE := preload("res://scenes/runtime/ScenarioRuntimeController.tscn")
const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")
const RULESET_SCENE := preload("res://scenes/runtime/RulesetRuntimeBridge.tscn")
const FIRST_TABLE_SIGNALS := [
	"district_selected",
	"monster_summoned",
	"rack_opened",
	"card_bought",
	"card_played",
	"city_development_resolved",
	"economy_checked",
	"followup_card_bought",
	"followup_card_played",
	"track_selected",
	"ai_public_action_observed",
	"public_clue_read",
	"monster_pressure_observed",
	"route_chosen",
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var standalone := CONTROLLER_SCENE.instantiate()
	get_root().add_child(standalone)
	standalone.call("configure", {})
	_check_required_api(standalone)
	_expect((standalone.call("scenario_catalog") as Array).size() == 8, "controller exposes the real eight-entry scenario catalog")
	var started: Dictionary = standalone.call("start_scenario", "first_table", 10.0)
	_expect(bool(started.get("started", false)), "controller starts first_table")
	var progress: Dictionary = standalone.call("progress_snapshot", 10.0)
	_expect(str(_phase(progress).get("id", "")) == "select_district", "first_table starts at select_district")
	var out_of_order: Dictionary = standalone.call("complete_signal", "monster_summoned", _event("monster_summoned", "after_summon"), 11.0)
	_expect(not bool(out_of_order.get("accepted", true)) and str(out_of_order.get("reason", "")) == "out_of_order_signal", "out-of-order signals are rejected")
	var accepted: Dictionary = standalone.call("complete_signal", "district_selected", _event("district_selected", "after_select"), 12.0)
	_expect(bool(accepted.get("accepted", false)) and str(accepted.get("current_phase_id", "")) == "first_summon", "expected signal advances one phase")
	var timed_state: Dictionary = standalone.call("runtime_state_snapshot", 12.0)
	_expect(float(timed_state.get("scenario_started_at", -1.0)) == 10.0 and float((timed_state.get("completed_signal_times", {}) as Dictionary).get("district_selected", -1.0)) == 12.0 and float(timed_state.get("elapsed_seconds", -1.0)) == 2.0, "controller records real scenario-game-time milestone telemetry")
	var duplicate: Dictionary = standalone.call("complete_signal", "district_selected", _event("district_selected", "after_select"), 13.0)
	_expect(not bool(duplicate.get("accepted", true)) and bool(duplicate.get("duplicate", false)), "duplicate signal is idempotent")
	standalone.call("record_action", _log_entry("privacy", "public", "owner-only", "true_owner=player3", 0))
	var owner_log: Array = standalone.call("viewer_action_log", 0, false)
	var rival_log: Array = standalone.call("viewer_action_log", 2, false)
	_expect(JSON.stringify(owner_log).contains("owner-only") and not JSON.stringify(rival_log).contains("owner-only"), "viewer-safe log filters private text")
	_expect(not JSON.stringify(owner_log).contains("true_owner"), "player log hides developer diagnostics")
	var visual_request: Dictionary = standalone.call("build_visual_event_request", "first_table", "after_select", "district_selected")
	_expect(_is_data_only(visual_request) and not JSON.stringify(visual_request).contains("true_owner"), "visual event request is privacy-safe pure data")
	standalone.call("start_scenario", "first_table", 0.0)
	var final_result := {}
	for index in range(FIRST_TABLE_SIGNALS.size()):
		var signal_id := str(FIRST_TABLE_SIGNALS[index])
		final_result = standalone.call("complete_signal", signal_id, _event(signal_id, "phase_%d" % index), float(index + 1))
	progress = standalone.call("progress_snapshot", 15.0)
	_expect(bool(progress.get("completed", false)) and bool(final_result.get("completion_first_report", false)), "fourteen ordered signals complete first_table once")
	var state: Dictionary = standalone.call("state_snapshot")
	_expect(_is_data_only(state) and (state.get("completed_signals", {}) as Dictionary).size() == 14 and (state.get("completed_signal_times", {}) as Dictionary).size() == 14, "state snapshot keeps fourteen pure-data milestone timestamps")
	standalone.queue_free()
	await process_frame
	await _check_coordinator_composition()
	_check_main_deletion_gate()
	if _failures.is_empty():
		print("Scenario runtime controller test passed.")
	else:
		push_error("Scenario runtime controller test failed:\n- " + "\n- ".join(_failures))
	quit(_failures.size())


func _check_required_api(controller: Node) -> void:
	for method_name in ["configure", "start_scenario", "clear_scenario", "active_scenario_id", "active_snapshot_key", "progress_snapshot", "complete_signal", "record_action", "record_failed_attempt", "set_coach_closed", "set_snapshot_key", "viewer_action_log", "state_snapshot", "debug_snapshot"]:
		_expect(controller.has_method(method_name), "controller exposes %s" % method_name)


func _check_coordinator_composition() -> void:
	var ruleset := RULESET_SCENE.instantiate()
	var coordinator := COORDINATOR_SCENE.instantiate()
	get_root().add_child(ruleset)
	get_root().add_child(coordinator)
	coordinator.call("configure", ruleset.call("debug_snapshot"))
	var controller := coordinator.get_node_or_null("ScenarioRuntimeController")
	var debug: Dictionary = coordinator.call("debug_snapshot")
	var scenario_debug: Dictionary = debug.get("scenario_runtime", {}) if debug.get("scenario_runtime", {}) is Dictionary else {}
	_expect(controller != null and controller.scene_file_path == "res://scenes/runtime/ScenarioRuntimeController.tscn", "GameRuntimeCoordinator composes the scene-owned controller")
	_expect(bool(scenario_debug.get("controller_ready", false)) and bool(scenario_debug.get("controller_authoritative", false)), "coordinator reports scenario authority")
	coordinator.call("start_runtime_scenario", "first_table", 0.0)
	coordinator.call("reset_state")
	_expect(str(coordinator.call("active_runtime_scenario_id")) == "first_table", "generic coordinator reset preserves a pre-activated scenario")
	coordinator.call("clear_runtime_scenario")
	_expect(str(coordinator.call("active_runtime_scenario_id")) == "", "explicit clear removes a free-run scenario")
	coordinator.queue_free()
	ruleset.queue_free()
	await process_frame


func _check_main_deletion_gate() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/main.gd")
	for token in ["var active_scenario_id", "var active_scenario_snapshot_key", "var scenario_completed_signals", "var scenario_phase_failed_attempts", "var scenario_phase_started_at", "var scenario_coach_closed", "var scenario_action_log_entries", "ScenarioLoaderScript", "ScenarioProgressScript", "SCENARIO_VISUAL_EVENT_FORBIDDEN_KEYS"]:
		_expect(not source.contains(token), "main no longer owns %s" % token)
	_expect(source.contains("complete_runtime_scenario_signal") and source.contains("runtime_scenario_progress"), "main compatibility entries delegate through GameRuntimeCoordinator")


func _phase(progress: Dictionary) -> Dictionary:
	var value: Variant = progress.get("current_phase", {})
	return value as Dictionary if value is Dictionary else {}


func _event(signal_id: String, snapshot_key: String) -> Dictionary:
	return {"time": "00:01", "public_text": signal_id, "private_text": "", "developer_text": "signal:%s" % signal_id, "viewer_index": 0, "snapshot_key": snapshot_key, "focus_target": "scenario_coach"}


func _log_entry(phase_id: String, public_text: String, private_text: String, developer_text: String, viewer_index: int) -> Dictionary:
	return {"time": "00:01", "phase_id": phase_id, "public_text": public_text, "private_text": private_text, "developer_text": developer_text, "viewer_index": viewer_index, "snapshot_key": "start", "focus_target": "scenario_coach"}


func _is_data_only(value: Variant) -> bool:
	if value == null or value is String or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item in value:
			if not _is_data_only(item):
				return false
		return true
	if value is Dictionary:
		for key in value.keys():
			if not _is_data_only(key) or not _is_data_only(value[key]):
				return false
		return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error(message)
