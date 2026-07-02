extends RefCounted
class_name CampaignMenuSnapshot

var ui: Dictionary = {}


func apply_dictionary(data: Dictionary) -> RefCounted:
	var campaign: Dictionary = data.get("campaign", {}) if data.get("campaign", {}) is Dictionary else {}
	var progress: Dictionary = data.get("progress", {}) if data.get("progress", {}) is Dictionary else {}
	var recommendations: Dictionary = data.get("recommendations", {}) if data.get("recommendations", {}) is Dictionary else {}
	var current_id := str(progress.get("current_chapter_id", progress.get("next_chapter_id", ""))).strip_edges()
	ui = {
		"visible": bool(data.get("visible", true)),
		"title": str(campaign.get("title", "新手战役")),
		"subtitle": str(campaign.get("subtitle", "从第一桌开始")),
		"summary": _short_text(str(campaign.get("summary", "")), 84),
		"progress_text": "%d/%d｜%d%%" % [
			int(progress.get("completed_count", 0)),
			maxi(1, int(progress.get("total_chapters", 1))),
			int(progress.get("completion_percent", 0)),
		],
		"next_chapter_id": current_id,
		"next_chapter_title": _chapter_title(progress.get("chapter_statuses", []), current_id),
		"chapters": _chapter_cards(progress.get("chapter_statuses", [])),
		"primary_action": {"id": "campaign_continue_%s" % current_id, "label": "继续新手战役", "disabled": current_id == ""},
		"secondary_actions": [
			{"id": "campaign_quick_start", "label": "快速开局"},
			{"id": "campaign_settings", "label": "设置"},
			{"id": "campaign_reset_progress", "label": "重置教程"},
			{"id": "campaign_back", "label": "返回大厅"},
		],
		"presets": _preset_cards(recommendations.get("presets", [])),
	}
	return self


func to_ui_dictionary() -> Dictionary:
	return ui.duplicate(true)


func _chapter_cards(value: Variant) -> Array:
	var source: Array = value if value is Array else []
	var result: Array = []
	for item in source:
		if not (item is Dictionary):
			continue
		var chapter: Dictionary = item
		var id := str(chapter.get("id", "")).strip_edges()
		var locked := not bool(chapter.get("unlocked", false))
		result.append({
			"id": id,
			"title": str(chapter.get("title", id)),
			"subtitle": str(chapter.get("subtitle", "")),
			"meta": "%s｜约%d分钟" % [str(chapter.get("difficulty", "intro")), int(chapter.get("estimated_minutes", 5))],
			"completed": bool(chapter.get("completed", false)),
			"locked": locked,
			"current": bool(chapter.get("current", false)),
			"action_id": "campaign_chapter_%s" % id,
		})
	return result


func _preset_cards(value: Variant) -> Array:
	var source: Array = value if value is Array else []
	var result: Array = []
	for item in source:
		if not (item is Dictionary):
			continue
		var preset: Dictionary = item
		result.append({
			"id": str(preset.get("id", "")),
			"title": str(preset.get("title", "")),
			"detail": "%s｜%s" % [str(preset.get("recommended_for", "")), str(preset.get("learns", ""))],
			"meta": "%s｜约%d分钟" % [str(preset.get("difficulty", "intro")), int(preset.get("estimated_minutes", 10))],
			"action_id": "quick_preset_%s" % str(preset.get("id", "")),
		})
	return result


func _chapter_title(value: Variant, chapter_id: String) -> String:
	var source: Array = value if value is Array else []
	for item in source:
		if item is Dictionary and str((item as Dictionary).get("id", "")) == chapter_id:
			return str((item as Dictionary).get("title", chapter_id))
	return chapter_id


func _short_text(value: String, limit: int) -> String:
	var text := value.strip_edges()
	if text.length() <= limit:
		return text
	return "%s…" % text.left(maxi(1, limit - 1))
