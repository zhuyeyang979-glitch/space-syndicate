extends RefCounted
class_name CampaignReward

var ui: Dictionary = {}


func apply_dictionary(data: Dictionary) -> RefCounted:
	ui = {
		"campaign_id": str(data.get("campaign_id", "")),
		"chapter_id": str(data.get("chapter_id", "")),
		"title": str(data.get("title", "关卡完成")),
		"badge": str(data.get("badge", "完成")),
		"score": int(data.get("score", 3)),
		"time_text": str(data.get("time_text", "--:--")),
		"objectives_completed": int(data.get("objectives_completed", 0)),
		"objectives_total": int(data.get("objectives_total", 0)),
		"errors": int(data.get("errors", 0)),
		"hints": int(data.get("hints", 0)),
		"unlocks": _unlock_array(data.get("unlocks", [])),
		"next_chapter_id": str(data.get("next_chapter_id", "")),
		"next_label": str(data.get("next_label", "下一关")),
	}
	return self


func to_dictionary() -> Dictionary:
	return ui.duplicate(true)


func _unlock_array(value: Variant) -> Array:
	var result: Array = []
	if not (value is Array):
		return result
	for item in value:
		if item is Dictionary:
			var entry: Dictionary = item
			result.append({
				"kind": str(entry.get("kind", "unlock")),
				"id": str(entry.get("id", "")),
				"label": str(entry.get("label", entry.get("id", ""))),
			})
		else:
			var text := str(item).strip_edges()
			if text != "":
				result.append({"kind": "unlock", "id": text, "label": text})
	return result
