extends RefCounted
class_name MatchRecapSnapshot

var ui: Dictionary = {}


func apply_dictionary(data: Dictionary) -> RefCounted:
	ui = {
		"title": str(data.get("title", "本关复盘")),
		"learned": _string_array(data.get("learned", []), 6),
		"key_actions": _string_array(data.get("key_actions", []), 8),
		"suggestions": _string_array(data.get("suggestions", []), 5),
		"checkpoint_actions": _action_array(data.get("checkpoint_actions", [])),
		"secondary_actions": [
			{"id": "campaign_reward", "label": "返回奖励"},
			{"id": "campaign_menu", "label": "战役地图"},
		],
	}
	return self


func to_ui_dictionary() -> Dictionary:
	return ui.duplicate(true)


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


func _action_array(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for item in value:
			if item is Dictionary:
				result.append((item as Dictionary).duplicate(true))
	return result
