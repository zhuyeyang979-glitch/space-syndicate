extends RefCounted
class_name ScenarioBrowserSnapshot

var ui: Dictionary = {}


func apply_dictionary(data: Dictionary) -> RefCounted:
	var scenarios: Array = data.get("scenarios", []) if data.get("scenarios", []) is Array else []
	var selected_id := str(data.get("selected_id", "first_table")).strip_edges()
	var cards: Array = []
	var categories := {}
	for scenario_variant in scenarios:
		if not (scenario_variant is Dictionary):
			continue
		var scenario: Dictionary = scenario_variant
		var id := str(scenario.get("id", "")).strip_edges()
		if id == "":
			continue
		var category := str(scenario.get("category", "试玩剧本"))
		categories[category] = true
		cards.append({
			"id": id,
			"title": str(scenario.get("title", id)),
			"category": category,
			"summary": _short_text(str(scenario.get("summary", "")), 64),
			"duration_label": str(scenario.get("duration_label", "")),
			"recommended_for": str(scenario.get("recommended_for", "")),
			"core_system": str(scenario.get("core_system", "")),
			"selected": id == selected_id,
			"action_id": "scenario_select_%s" % id,
		})
	ui = {
		"visible": bool(data.get("visible", true)),
		"title": str(data.get("title", "试玩剧本")),
		"subtitle": str(data.get("subtitle", "选择一个固定局面，练习一段核心系统。")),
		"selected_id": selected_id,
		"cards": cards,
		"categories": categories.keys(),
		"primary_action": {"id": "scenario_start_%s" % selected_id, "label": "开始剧本", "disabled": selected_id == ""},
		"secondary_actions": [
			{"id": "scenario_settings", "label": "教学设置"},
			{"id": "scenario_restart_last", "label": "重开上个"},
			{"id": "scenario_back", "label": "返回大厅"},
		],
	}
	return self


func to_ui_dictionary() -> Dictionary:
	return ui.duplicate(true)


func _short_text(value: String, limit: int) -> String:
	var text := value.strip_edges()
	if text.length() <= limit:
		return text
	return "%s…" % text.left(maxi(1, limit - 1))
