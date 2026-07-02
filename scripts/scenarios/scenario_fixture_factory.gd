extends RefCounted
class_name ScenarioFixtureFactory

const LOADER_SCRIPT := preload("res://scripts/scenarios/scenario_loader.gd")


func make_fixture(scenario_id: String, snapshot_key: String = "start") -> Dictionary:
	var scenario := LOADER_SCRIPT.new().load_by_id(scenario_id)
	if scenario.is_empty():
		return {}
	var fixture: Dictionary = scenario.get("fixture", {}) if scenario.get("fixture", {}) is Dictionary else {}
	return {
		"scenario_id": scenario_id,
		"snapshot_key": snapshot_key,
		"scenario": scenario,
		"coach": _coach_fixture(scenario, snapshot_key),
		"action_log": _log_fixture(scenario, snapshot_key),
		"table_state": _table_state_fixture(scenario_id, fixture, snapshot_key),
		"replay": _replay_fixture(scenario, snapshot_key),
	}


func _coach_fixture(scenario: Dictionary, snapshot_key: String) -> Dictionary:
	var phases: Array = scenario.get("phases", []) if scenario.get("phases", []) is Array else []
	var index := 0
	for i in range(phases.size()):
		var phase: Dictionary = phases[i] if phases[i] is Dictionary else {}
		if str(phase.get("snapshot_key", phase.get("id", ""))) == snapshot_key:
			index = i
			break
	var phase_data: Dictionary = phases[index] if index >= 0 and index < phases.size() and phases[index] is Dictionary else {}
	return {
		"scenario_id": str(scenario.get("id", "")),
		"title": str(scenario.get("title", "")),
		"current_index": index,
		"total": phases.size(),
		"current_phase": phase_data,
		"completed": false,
		"closed_to_chip": false,
	}


func _log_fixture(scenario: Dictionary, snapshot_key: String) -> Dictionary:
	var title := str(scenario.get("title", "试玩剧本"))
	return {
		"scenario_id": str(scenario.get("id", "")),
		"title": "%s｜行动日志" % title,
		"entries": [
			{"time": "00:00", "phase_id": "start", "public_text": "开始剧本：%s" % title, "private_text": "", "developer_text": "fixture:%s" % snapshot_key, "snapshot_key": "start", "focus_target": "scenario_coach"},
		],
	}


func _table_state_fixture(scenario_id: String, fixture: Dictionary, snapshot_key: String) -> Dictionary:
	return {
		"id": scenario_id,
		"snapshot_key": snapshot_key,
		"privacy": "current_player_only",
		"public_summary": str(fixture.get("public_summary", "")),
		"focus": str(fixture.get("focus", scenario_id)),
		"has_public_track": bool(fixture.get("has_public_track", scenario_id in ["public_track_intro", "bid_practice", "intel_guess"])),
		"has_bid_board": bool(fixture.get("has_bid_board", scenario_id == "bid_practice")),
		"has_monster_pressure": bool(fixture.get("has_monster_pressure", scenario_id == "monster_pressure")),
		"has_final_countdown": bool(fixture.get("has_final_countdown", scenario_id == "final_countdown")),
	}


func _replay_fixture(scenario: Dictionary, snapshot_key: String) -> Dictionary:
	var snapshots: Array = scenario.get("replay_snapshots", []) if scenario.get("replay_snapshots", []) is Array else []
	return {
		"scenario_id": str(scenario.get("id", "")),
		"title": str(scenario.get("title", "")),
		"current_snapshot": snapshot_key,
		"snapshots": snapshots,
	}
