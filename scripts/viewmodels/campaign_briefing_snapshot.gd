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
		"quick_cards": _quick_cards(chapter),
		"primary_action": {"id": "campaign_start_%s" % chapter_id, "label": "开始本关", "disabled": chapter_id == ""},
		"secondary_actions": [
			{"id": "campaign_menu", "label": "返回战役"},
			{"id": "campaign_settings", "label": "设置"},
		],
	}
	return self


func to_ui_dictionary() -> Dictionary:
	return ui.duplicate(true)


func _quick_cards(chapter: Dictionary) -> Array:
	var objectives := _string_array(chapter.get("objectives", []), 1)
	var allowed := _string_array(chapter.get("allowed_actions", []), 1)
	var teaches := _string_array(chapter.get("teaches", []), 1)
	return [
		{
			"kind": "goal",
			"kicker": "目标",
			"title": _short_text(str(objectives[0]) if not objectives.is_empty() else str(chapter.get("subtitle", "完成本关")), 18),
			"detail": "只盯一个主目标",
		},
		{
			"kind": "action",
			"kicker": "能做",
			"title": _short_text(str(allowed[0]) if not allowed.is_empty() else "跟随桌面提示", 18),
			"detail": "按钮会带你进桌",
		},
		{
			"kind": "reward",
			"kicker": "收获",
			"title": _short_text(_reward_text(chapter.get("reward", {})), 18),
			"detail": _short_text(str(teaches[0]) if not teaches.is_empty() else "解锁下一步", 18),
		},
	]


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


func _short_text(value: String, limit: int) -> String:
	var text := value.replace("\n", " ").strip_edges()
	if text.length() <= limit:
		return text
	return "%s…" % text.left(maxi(1, limit - 1))
