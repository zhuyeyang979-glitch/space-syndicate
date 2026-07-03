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
		"subtitle": _short_text(str(campaign.get("subtitle", "从第一桌开始")), 34),
		"summary": _short_text(str(campaign.get("summary", "")), 84),
		"progress_text": "%d/%d｜%d%%" % [
			int(progress.get("completed_count", 0)),
			maxi(1, int(progress.get("total_chapters", 1))),
			int(progress.get("completion_percent", 0)),
		],
		"next_chapter_id": current_id,
		"next_chapter_title": _chapter_title(progress.get("chapter_statuses", []), current_id),
		"path_steps": _path_steps(progress),
		"chapters": _chapter_cards(progress.get("chapter_statuses", []), current_id),
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


func _chapter_cards(value: Variant, current_id: String = "") -> Array:
	var source: Array = value if value is Array else []
	var result: Array = []
	var added_ids := {}
	var ordered_source := _prioritized_chapters(source, current_id)
	for item in ordered_source:
		if not (item is Dictionary):
			continue
		var chapter: Dictionary = item
		var id := str(chapter.get("id", "")).strip_edges()
		if id == "" or added_ids.has(id):
			continue
		added_ids[id] = true
		var locked := not bool(chapter.get("unlocked", false))
		result.append({
			"id": id,
			"title": _short_text(str(chapter.get("title", id)), 18),
			"subtitle": _short_text(str(chapter.get("subtitle", "")), 24),
			"meta": "%s｜约%d分钟" % [str(chapter.get("difficulty", "intro")), int(chapter.get("estimated_minutes", 5))],
			"completed": bool(chapter.get("completed", false)),
			"locked": locked,
			"current": bool(chapter.get("current", false)),
			"action_id": "campaign_chapter_%s" % id,
		})
		if result.size() >= 4:
			break
	return result


func _prioritized_chapters(source: Array, current_id: String) -> Array:
	var current: Array = []
	var playable: Array = []
	var completed: Array = []
	var locked: Array = []
	for item in source:
		if not (item is Dictionary):
			continue
		var chapter: Dictionary = item
		var id := str(chapter.get("id", "")).strip_edges()
		if id == current_id or bool(chapter.get("current", false)):
			current.append(chapter)
		elif bool(chapter.get("unlocked", false)) and not bool(chapter.get("completed", false)):
			playable.append(chapter)
		elif bool(chapter.get("completed", false)):
			completed.append(chapter)
		else:
			locked.append(chapter)
	var ordered: Array = []
	ordered.append_array(current)
	ordered.append_array(playable)
	ordered.append_array(completed)
	ordered.append_array(locked)
	return ordered


func _path_steps(progress: Dictionary) -> Array:
	var completed_count := int(progress.get("completed_count", 0))
	var total := maxi(1, int(progress.get("total_chapters", 10)))
	var completion_percent := int(progress.get("completion_percent", 0))
	var halfway := maxi(2, int(ceil(float(total) * 0.5)))
	return [
		{
			"index": "01",
			"label": "开桌",
			"state": "完成" if completed_count > 0 else "现在",
			"current": completed_count == 0,
			"completed": completed_count > 0,
			"tooltip": "进入第一桌，知道该看哪里。",
		},
		{
			"index": "02",
			"label": "练流程",
			"state": "完成" if completed_count >= halfway else ("现在" if completed_count > 0 else "稍后"),
			"current": completed_count > 0 and completed_count < halfway,
			"completed": completed_count >= halfway,
			"tooltip": "点区、首召、建城、买牌、出牌、牌轨、经济、路线。",
		},
		{
			"index": "03",
			"label": "完整局",
			"state": "完成" if completion_percent >= 100 else ("%d%%" % completion_percent if completed_count >= halfway else "稍后"),
			"current": completed_count >= halfway and completion_percent < 100,
			"completed": completion_percent >= 100,
			"tooltip": "跑到结算复盘，知道为什么赢或输。",
		},
	]


func _preset_cards(value: Variant) -> Array:
	var source: Array = value if value is Array else []
	var result: Array = []
	for item in source:
		if not (item is Dictionary):
			continue
		var preset: Dictionary = item
		result.append({
			"id": str(preset.get("id", "")),
			"title": _short_text(str(preset.get("title", "")), 8),
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
