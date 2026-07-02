extends RefCounted
class_name CampaignBriefingSnapshot

var ui: Dictionary = {}


func apply_dictionary(data: Dictionary) -> RefCounted:
	var campaign: Dictionary = data.get("campaign", {}) if data.get("campaign", {}) is Dictionary else {}
	var chapter: Dictionary = data.get("chapter", {}) if data.get("chapter", {}) is Dictionary else {}
	var chapter_id := str(chapter.get("id", "")).strip_edges()
	ui = {
		"title": str(chapter.get("title", "关卡说明")),
		"subtitle": str(chapter.get("subtitle", "")),
		"campaign_title": str(campaign.get("title", "新手战役")),
		"briefing": str(chapter.get("briefing", "")),
		"estimated_time": "约%d分钟" % int(chapter.get("estimated_minutes", 5)),
		"difficulty": str(chapter.get("difficulty", "intro")),
		"objectives": _string_array(chapter.get("objectives", []), 5),
		"allowed_actions": _string_array(chapter.get("allowed_actions", []), 5),
		"teaches": _string_array(chapter.get("teaches", []), 5),
		"reward_text": _reward_text(chapter.get("reward", {})),
		"primary_action": {"id": "campaign_start_%s" % chapter_id, "label": "开始本关", "disabled": chapter_id == ""},
		"secondary_actions": [
			{"id": "campaign_menu", "label": "返回战役"},
			{"id": "campaign_settings", "label": "设置"},
		],
	}
	return self


func to_ui_dictionary() -> Dictionary:
	return ui.duplicate(true)


func _reward_text(value: Variant) -> String:
	var reward: Dictionary = value if value is Dictionary else {}
	var badge := str(reward.get("badge", "完成奖励"))
	var unlock := str(reward.get("unlock_chapter", "")).strip_edges()
	return "%s%s" % [badge, "｜解锁下一关" if unlock != "" else ""]


func _string_array(value: Variant, limit: int) -> Array:
	var result: Array = []
	if value is Array:
		for item in value:
			var text := str(item).strip_edges()
			if text != "":
				result.append(text)
			if result.size() >= limit:
				break
	return result
