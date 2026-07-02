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
