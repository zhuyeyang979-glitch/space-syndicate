extends RefCounted
class_name CampaignChapter

var id := ""
var order := 0
var title := ""
var subtitle := ""
var estimated_minutes := 5
var difficulty := "intro"
var unlocks: Array = []
var scenario_id := ""
var briefing := ""
var objectives: Array = []
var allowed_actions: Array = []
var success_conditions: Array = []
var failure_hints: Array = []
var reward: Dictionary = {}
var teaches: Array = []


func apply_dictionary(data: Dictionary) -> RefCounted:
	id = str(data.get("id", "")).strip_edges()
	order = int(data.get("order", 0))
	title = str(data.get("title", id)).strip_edges()
	subtitle = str(data.get("subtitle", "")).strip_edges()
	estimated_minutes = maxi(1, int(data.get("estimated_minutes", 5)))
	difficulty = str(data.get("difficulty", "intro")).strip_edges()
	unlocks = _string_array(data.get("unlocks", []))
	scenario_id = str(data.get("scenario_id", "")).strip_edges()
	briefing = str(data.get("briefing", "")).strip_edges()
	objectives = _string_array(data.get("objectives", []))
	allowed_actions = _string_array(data.get("allowed_actions", []))
	success_conditions = _string_array(data.get("success_conditions", []))
	failure_hints = _string_array(data.get("failure_hints", []))
	reward = (data.get("reward", {}) as Dictionary).duplicate(true) if data.get("reward", {}) is Dictionary else {}
	teaches = _string_array(data.get("teaches", []))
	return self


func is_valid() -> bool:
	return id != "" and title != "" and scenario_id != "" and not objectives.is_empty() and not success_conditions.is_empty()


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"order": order,
		"title": title,
		"subtitle": subtitle,
		"estimated_minutes": estimated_minutes,
		"difficulty": difficulty,
		"unlocks": unlocks.duplicate(true),
		"scenario_id": scenario_id,
		"briefing": briefing,
		"objectives": objectives.duplicate(true),
		"allowed_actions": allowed_actions.duplicate(true),
		"success_conditions": success_conditions.duplicate(true),
		"failure_hints": failure_hints.duplicate(true),
		"reward": reward.duplicate(true),
		"teaches": teaches.duplicate(true),
	}


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if not (value is Array):
		return result
	for item in value:
		var text := str(item).strip_edges()
		if text != "":
			result.append(text)
	return result
