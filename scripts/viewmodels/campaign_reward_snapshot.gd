extends RefCounted
class_name CampaignRewardSnapshot

var ui: Dictionary = {}


func apply_dictionary(data: Dictionary) -> RefCounted:
	var unlocks: Array = data.get("unlocks", []) if data.get("unlocks", []) is Array else []
	ui = {
		"title": str(data.get("title", "关卡完成")),
		"badge": str(data.get("badge", "完成")),
		"score_text": "评分 %d/5" % int(data.get("score", 3)),
		"time_text": str(data.get("time_text", "--:--")),
		"objective_text": "目标 %d/%d" % [int(data.get("objectives_completed", 0)), maxi(1, int(data.get("objectives_total", 1)))],
		"errors_text": "失误 %d" % int(data.get("errors", 0)),
		"hints_text": "提示 %d" % int(data.get("hints", 0)),
		"unlocks": _unlock_labels(unlocks),
		"summary_cards": _summary_cards(data, unlocks),
		"next_chapter_id": str(data.get("next_chapter_id", "")),
		"primary_action": {"id": "campaign_next_%s" % str(data.get("next_chapter_id", "")), "label": str(data.get("next_label", "下一关"))},
		"secondary_actions": [
			{"id": "campaign_recap", "label": "查看复盘"},
			{"id": "campaign_menu", "label": "战役地图"},
		],
	}
	return self


func to_ui_dictionary() -> Dictionary:
	return ui.duplicate(true)


func _unlock_labels(unlocks: Array) -> Array:
	var result: Array = []
	for item in unlocks:
		if item is Dictionary:
			result.append(str((item as Dictionary).get("label", (item as Dictionary).get("id", ""))))
		else:
			result.append(str(item))
	return result


func _summary_cards(data: Dictionary, unlocks: Array) -> Array:
	var score := clampi(int(data.get("score", 3)), 0, 5)
	var completed := int(data.get("objectives_completed", 0))
	var total := maxi(1, int(data.get("objectives_total", 1)))
	var next_label := str(data.get("next_label", "下一关")).strip_edges()
	var next_id := str(data.get("next_chapter_id", "")).strip_edges()
	if next_label == "":
		next_label = "下一关" if next_id != "" else "回战役地图"
	return [
		{
			"kind": "score",
			"kicker": "表现",
			"title": "评分 %d/5" % score,
			"detail": _score_detail(score),
		},
		{
			"kind": "objective",
			"kicker": "目标",
			"title": "%d/%d 完成" % [completed, total],
			"detail": "本关关键动作已结算" if completed >= total else "还有动作可复练",
		},
		{
			"kind": "unlock",
			"kicker": "解锁",
			"title": _short_text(_first_unlock_label(unlocks), 14),
			"detail": "新内容已加入战役路径",
		},
		{
			"kind": "next",
			"kicker": "下一步",
			"title": _short_text(next_label, 14),
			"detail": "继续，不用重读规则",
		},
	]


func _score_detail(score: int) -> String:
	if score >= 5:
		return "漂亮开局"
	if score >= 4:
		return "可以继续"
	if score >= 3:
		return "已能上桌"
	return "建议复练"


func _first_unlock_label(unlocks: Array) -> String:
	for item in unlocks:
		if item is Dictionary:
			var label := str((item as Dictionary).get("label", (item as Dictionary).get("id", ""))).strip_edges()
			if label != "":
				return label
		else:
			var text := str(item).strip_edges()
			if text != "":
				return text
	return "继续战役"


func _short_text(value: String, limit: int) -> String:
	var text := value.replace("\n", " ").strip_edges()
	if text.length() <= limit:
		return text
	return "%s…" % text.left(maxi(1, limit - 1))
