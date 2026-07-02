extends RefCounted
class_name ScenarioGoal

var id := ""
var label := ""
var goal := ""
var primary_action_hint := ""
var success_signal := ""
var allowed_actions: Array = []
var snapshot_key := ""
var detail := ""
var focus_target := ""
var stuck_hint := ""


func apply_dictionary(data: Dictionary) -> RefCounted:
	id = str(data.get("id", "")).strip_edges()
	label = str(data.get("label", id)).strip_edges()
	goal = str(data.get("goal", "")).strip_edges()
	primary_action_hint = str(data.get("primary_action_hint", "")).strip_edges()
	success_signal = str(data.get("success_signal", id)).strip_edges()
	allowed_actions = (data.get("allowed_actions", []) as Array).duplicate(true) if data.get("allowed_actions", []) is Array else []
	snapshot_key = str(data.get("snapshot_key", id)).strip_edges()
	detail = str(data.get("detail", goal)).strip_edges()
	focus_target = str(data.get("focus_target", "scenario_coach")).strip_edges()
	stuck_hint = str(data.get("stuck_hint", detail)).strip_edges()
	return self


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"label": label,
		"goal": goal,
		"primary_action_hint": primary_action_hint,
		"success_signal": success_signal,
		"allowed_actions": allowed_actions.duplicate(true),
		"snapshot_key": snapshot_key,
		"detail": detail,
		"focus_target": focus_target,
		"stuck_hint": stuck_hint,
	}
