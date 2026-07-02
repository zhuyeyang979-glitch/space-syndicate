extends RefCounted
class_name ScenarioDefinition

const GOAL_SCRIPT := preload("res://scripts/scenarios/scenario_goal.gd")

var id := ""
var title := ""
var category := ""
var difficulty := ""
var duration_label := ""
var player_count := 4
var ai_count := 3
var summary := ""
var recommended_for := ""
var core_system := ""
var allowed_private_information := "current_player_only"
var phases: Array = []
var replay_snapshots: Array = []
var fixture: Dictionary = {}


func apply_dictionary(data: Dictionary) -> RefCounted:
	id = str(data.get("id", "")).strip_edges()
	title = str(data.get("title", id)).strip_edges()
	category = str(data.get("category", "试玩剧本")).strip_edges()
	difficulty = str(data.get("difficulty", "intro")).strip_edges()
	duration_label = str(data.get("duration_label", "5-10分钟")).strip_edges()
	player_count = int(data.get("player_count", 4))
	ai_count = int(data.get("ai_count", 3))
	summary = str(data.get("summary", "")).strip_edges()
	recommended_for = str(data.get("recommended_for", "第一次试玩")).strip_edges()
	core_system = str(data.get("core_system", category)).strip_edges()
	allowed_private_information = str(data.get("allowed_private_information", "current_player_only")).strip_edges()
	fixture = (data.get("fixture", {}) as Dictionary).duplicate(true) if data.get("fixture", {}) is Dictionary else {}
	replay_snapshots = (data.get("replay_snapshots", []) as Array).duplicate(true) if data.get("replay_snapshots", []) is Array else []
	phases = []
	var raw_phases: Array = data.get("phases", []) if data.get("phases", []) is Array else []
	for phase_variant in raw_phases:
		if phase_variant is Dictionary:
			phases.append(GOAL_SCRIPT.new().apply_dictionary(phase_variant as Dictionary).to_dictionary())
	return self


func is_valid() -> bool:
	return id != "" and title != "" and not phases.is_empty()


func first_phase() -> Dictionary:
	return phases[0] if not phases.is_empty() and phases[0] is Dictionary else {}


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"title": title,
		"category": category,
		"difficulty": difficulty,
		"duration_label": duration_label,
		"player_count": player_count,
		"ai_count": ai_count,
		"summary": summary,
		"recommended_for": recommended_for,
		"core_system": core_system,
		"allowed_private_information": allowed_private_information,
		"phases": phases.duplicate(true),
		"replay_snapshots": replay_snapshots.duplicate(true),
		"fixture": fixture.duplicate(true),
	}
