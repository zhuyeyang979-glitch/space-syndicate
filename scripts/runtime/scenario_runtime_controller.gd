@tool
extends Node
class_name ScenarioRuntimeController

const ScenarioLoaderScript := preload("res://scripts/scenarios/scenario_loader.gd")
const ScenarioProgressScript := preload("res://scripts/scenarios/scenario_progress.gd")
const ScenarioActionLogScript := preload("res://scripts/scenarios/scenario_action_log.gd")
const ScenarioFixtureFactoryScript := preload("res://scripts/scenarios/scenario_fixture_factory.gd")
const VISUAL_EVENT_FORBIDDEN_KEYS := [
	"true_owner",
	"hidden_owner",
	"owner_truth",
	"private_cash",
	"opponent_hand",
	"opponent_discard",
	"ai_score",
	"ai_reason",
]

@export var default_scenario_id := "first_table"

var _configured := false
var _active_scenario_id := ""
var _active_snapshot_key := "start"
var _completed_signals: Dictionary = {}
var _completed_signal_times: Dictionary = {}
var _phase_failed_attempts: Dictionary = {}
var _scenario_started_at := 0.0
var _phase_started_at := 0.0
var _coach_closed := false
var _completion_reported := false
var _action_log: RefCounted = ScenarioActionLogScript.new()


func configure(_config: Dictionary = {}) -> void:
	var loader := ScenarioLoaderScript.new()
	var catalog: Array = loader.load_all()
	_configured = not catalog.is_empty() and not loader.load_by_id(default_scenario_id).is_empty()


func clear_scenario() -> void:
	_active_scenario_id = ""
	_active_snapshot_key = "start"
	_completed_signals.clear()
	_completed_signal_times.clear()
	_phase_failed_attempts.clear()
	_scenario_started_at = 0.0
	_phase_started_at = 0.0
	_coach_closed = false
	_completion_reported = false
	_action_log = ScenarioActionLogScript.new()


func start_scenario(scenario_id: String, now_seconds: float) -> Dictionary:
	var clean_id := scenario_id.strip_edges()
	var definition := scenario_definition(clean_id)
	if not _configured or definition.is_empty():
		return {"started": false, "scenario_id": clean_id, "reason": "scenario_not_found", "scenario": {}, "progress": {}}
	clear_scenario()
	_active_scenario_id = clean_id
	_scenario_started_at = maxf(0.0, now_seconds)
	_phase_started_at = _scenario_started_at
	return {
		"started": true,
		"scenario_id": clean_id,
		"reason": "",
		"scenario": definition,
		"progress": progress_snapshot(now_seconds),
	}


func scenario_catalog() -> Array:
	var catalog: Array = ScenarioLoaderScript.new().load_all() if _configured else []
	return catalog.duplicate(true)


func scenario_definition(scenario_id: String) -> Dictionary:
	if not _configured and not Engine.is_editor_hint():
		return {}
	var value: Variant = ScenarioLoaderScript.new().load_by_id(scenario_id.strip_edges())
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func active_scenario_id() -> String:
	return _active_scenario_id


func active_snapshot_key() -> String:
	return _active_snapshot_key


func completed_signal(signal_id: String) -> bool:
	return bool(_completed_signals.get(signal_id.strip_edges(), false))


func progress_snapshot(now_seconds: float) -> Dictionary:
	var definition := scenario_definition(_active_scenario_id)
	if definition.is_empty():
		return {}
	var progress: Variant = ScenarioProgressScript.new().apply_state(
		definition,
		_completed_signals,
		false,
		_coach_closed,
		_phase_failed_attempts,
		_phase_started_at,
		maxf(0.0, now_seconds)
	)
	var value: Variant = progress.call("to_dictionary") if progress != null and progress.has_method("to_dictionary") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func complete_signal(signal_id: String, event_snapshot: Dictionary, now_seconds: float) -> Dictionary:
	var clean_signal := signal_id.strip_edges()
	var progress_before := progress_snapshot(now_seconds)
	var phase_before: Dictionary = progress_before.get("current_phase", {}) if progress_before.get("current_phase", {}) is Dictionary else {}
	var phase_before_id := str(phase_before.get("id", ""))
	var base := {
		"accepted": false,
		"duplicate": false,
		"reason": "",
		"scenario_id": _active_scenario_id,
		"submitted_signal": clean_signal,
		"expected_signal": str(phase_before.get("success_signal", phase_before.get("id", ""))).strip_edges(),
		"previous_phase_id": phase_before_id,
		"current_phase_id": phase_before_id,
		"snapshot_key": _active_snapshot_key,
		"scenario_completed": bool(progress_before.get("completed", false)),
		"completion_first_report": false,
		"completed_at_seconds": -1.0,
		"action_log_entry": {},
		"visual_event_request": {},
	}
	if not _configured or _active_scenario_id == "":
		base["reason"] = "scenario_inactive"
		return base
	if clean_signal == "" or not _is_data_only(event_snapshot):
		base["reason"] = "invalid_event"
		return base
	if completed_signal(clean_signal):
		base["duplicate"] = true
		base["reason"] = "duplicate_signal"
		return base
	if bool(progress_before.get("completed", false)):
		base["reason"] = "scenario_complete"
		return base
	if str(base["expected_signal"]) != clean_signal:
		base["reason"] = "out_of_order_signal"
		return base
	_completed_signals[clean_signal] = true
	_completed_signal_times[clean_signal] = maxf(0.0, now_seconds)
	_phase_failed_attempts.clear()
	_phase_started_at = maxf(0.0, now_seconds)
	var requested_key := str(event_snapshot.get("snapshot_key", "")).strip_edges()
	_active_snapshot_key = requested_key if requested_key != "" else str(phase_before.get("snapshot_key", _active_snapshot_key))
	var public_text := str(event_snapshot.get("public_text", "")).strip_edges()
	if public_text == "":
		public_text = "Completed scenario goal: %s" % str(phase_before.get("label", phase_before_id))
	var entry := record_action({
		"time": str(event_snapshot.get("time", "00:00")),
		"phase_id": phase_before_id if phase_before_id != "" else clean_signal,
		"public_text": public_text,
		"private_text": str(event_snapshot.get("private_text", "")),
		"developer_text": str(event_snapshot.get("developer_text", "signal:%s" % clean_signal)),
		"viewer_index": int(event_snapshot.get("viewer_index", 0)),
		"snapshot_key": _active_snapshot_key,
		"focus_target": str(event_snapshot.get("focus_target", phase_before.get("focus_target", ""))),
	})
	var progress_after := progress_snapshot(now_seconds)
	var phase_after: Dictionary = progress_after.get("current_phase", {}) if progress_after.get("current_phase", {}) is Dictionary else {}
	var completed := bool(progress_after.get("completed", false))
	var first_report := completed and not _completion_reported
	if first_report:
		_completion_reported = true
	base["accepted"] = true
	base["reason"] = ""
	base["current_phase_id"] = str(phase_after.get("id", "done" if completed else ""))
	base["snapshot_key"] = _active_snapshot_key
	base["scenario_completed"] = completed
	base["completion_first_report"] = first_report
	base["completed_at_seconds"] = float(_completed_signal_times.get(clean_signal, now_seconds))
	base["action_log_entry"] = entry
	base["visual_event_request"] = build_visual_event_request(_active_scenario_id, _active_snapshot_key, clean_signal)
	return base


func record_action(entry_snapshot: Dictionary) -> Dictionary:
	if not _configured or _active_scenario_id == "" or not _is_data_only(entry_snapshot):
		return {}
	_action_log.call("add_entry", entry_snapshot)
	var state_variant: Variant = _action_log.call("to_test_dictionary")
	var state: Dictionary = state_variant if state_variant is Dictionary else {}
	var entries: Array = state.get("entries", []) if state.get("entries", []) is Array else []
	return (entries[-1] as Dictionary).duplicate(true) if not entries.is_empty() and entries[-1] is Dictionary else {}


func record_failed_attempt(phase_id: String, entry_snapshot: Dictionary, now_seconds: float) -> Dictionary:
	var clean_phase := phase_id.strip_edges()
	if clean_phase == "" or not _is_data_only(entry_snapshot):
		return {}
	_phase_failed_attempts[clean_phase] = maxi(0, int(_phase_failed_attempts.get(clean_phase, 0))) + 1
	_phase_started_at = minf(_phase_started_at, maxf(0.0, now_seconds))
	var requested_key := str(entry_snapshot.get("snapshot_key", "")).strip_edges()
	if requested_key != "":
		_active_snapshot_key = requested_key
	var entry := entry_snapshot.duplicate(true)
	entry["phase_id"] = clean_phase
	entry["snapshot_key"] = _active_snapshot_key
	return record_action(entry)


func set_coach_closed(closed: bool) -> void:
	_coach_closed = closed


func set_snapshot_key(snapshot_key: String) -> void:
	var clean_key := snapshot_key.strip_edges()
	if clean_key != "":
		_active_snapshot_key = clean_key


func viewer_action_log(viewer_index: int, include_developer: bool = false) -> Array:
	var value: Variant = _action_log.call("filtered_entries", viewer_index, include_developer)
	return (value as Array).duplicate(true) if value is Array else []


func runtime_state_snapshot(now_seconds: float = 0.0) -> Dictionary:
	var log_state_variant: Variant = _action_log.call("to_test_dictionary")
	var log_state: Dictionary = log_state_variant if log_state_variant is Dictionary else {}
	return {
		"active_scenario_id": _active_scenario_id,
		"active_snapshot_key": _active_snapshot_key,
		"completed_signals": _completed_signals.duplicate(true),
		"completed_signal_times": _completed_signal_times.duplicate(true),
		"phase_failed_attempts": _phase_failed_attempts.duplicate(true),
		"scenario_started_at": _scenario_started_at,
		"phase_started_at": _phase_started_at,
		"elapsed_seconds": maxf(0.0, now_seconds - _scenario_started_at) if _active_scenario_id != "" else 0.0,
		"coach_closed": _coach_closed,
		"completion_reported": _completion_reported,
		"action_log_entries": (log_state.get("entries", []) as Array).duplicate(true) if log_state.get("entries", []) is Array else [],
		"progress": progress_snapshot(now_seconds),
	}


func state_snapshot() -> Dictionary:
	return runtime_state_snapshot(_phase_started_at)


func build_visual_event_request(scenario_id: String, snapshot_key: String, trigger_id: String = "") -> Dictionary:
	var clean_id := scenario_id.strip_edges()
	if clean_id == "":
		return {}
	var clean_key := snapshot_key.strip_edges()
	if clean_key == "":
		clean_key = _active_snapshot_key
	var fixture: Dictionary = ScenarioFixtureFactoryScript.new().make_fixture(clean_id, clean_key)
	var events: Array = fixture.get("visual_events", []) if fixture.get("visual_events", []) is Array else []
	if events.is_empty():
		var start_fixture: Dictionary = ScenarioFixtureFactoryScript.new().make_fixture(clean_id, "start")
		events = start_fixture.get("visual_events", []) if start_fixture.get("visual_events", []) is Array else []
	var safe_events: Array = []
	for event_variant in events:
		if event_variant is Dictionary and not _contains_forbidden_key(event_variant as Dictionary):
			safe_events.append((event_variant as Dictionary).duplicate(true))
	return {
		"scenario_id": clean_id,
		"snapshot_key": clean_key,
		"trigger_id": trigger_id.strip_edges(),
		"events": safe_events,
	} if not safe_events.is_empty() else {}


func debug_snapshot() -> Dictionary:
	var progress := progress_snapshot(_phase_started_at)
	var phase: Dictionary = progress.get("current_phase", {}) if progress.get("current_phase", {}) is Dictionary else {}
	var runtime_state := runtime_state_snapshot(_phase_started_at)
	return {
		"controller_ready": _configured,
		"controller_authoritative": _configured,
		"catalog_count": scenario_catalog().size() if _configured else 0,
		"active_scenario_id": _active_scenario_id,
		"active_snapshot_key": _active_snapshot_key,
		"current_phase_id": str(phase.get("id", "")),
		"completed_signal_count": _completed_signals.size(),
		"timed_milestone_count": _completed_signal_times.size(),
		"scenario_started_at": _scenario_started_at,
		"action_log_entry_count": (runtime_state.get("action_log_entries", []) as Array).size(),
		"coach_closed": _coach_closed,
		"scenario_completed": bool(progress.get("completed", false)),
	}


func _contains_forbidden_key(value: Dictionary) -> bool:
	for key_variant in value.keys():
		var key_text := str(key_variant).strip_edges().to_lower()
		if VISUAL_EVENT_FORBIDDEN_KEYS.has(key_text):
			return true
		var nested: Variant = value[key_variant]
		if nested is Dictionary and _contains_forbidden_key(nested as Dictionary):
			return true
		if nested is Array:
			for item_variant in nested:
				if item_variant is Dictionary and _contains_forbidden_key(item_variant as Dictionary):
					return true
	return false


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
