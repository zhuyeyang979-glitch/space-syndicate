extends RefCounted
class_name ScenarioActionLogSnapshot

const ACTION_LOG_SCRIPT := preload("res://scripts/scenarios/scenario_action_log.gd")

var ui: Dictionary = {}


func apply_dictionary(data: Dictionary) -> RefCounted:
	var viewer_index := int(data.get("viewer_index", 0))
	var include_developer := bool(data.get("include_developer", false))
	var log_model: Variant = ACTION_LOG_SCRIPT.new().apply_entries(data.get("entries", []))
	ui = {
		"visible": bool(data.get("visible", true)),
		"title": str(data.get("title", "剧本行动日志")),
		"scenario_id": str(data.get("scenario_id", "")),
		"entries": log_model.filtered_entries(viewer_index, include_developer),
		"viewer_index": viewer_index,
		"include_developer": include_developer,
	}
	return self


func to_ui_dictionary() -> Dictionary:
	return ui.duplicate(true)
