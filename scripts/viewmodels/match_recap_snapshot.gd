extends RefCounted
class_name MatchRecapSnapshot

var ui: Dictionary = {}


func apply_dictionary(data: Dictionary) -> RefCounted:
	var learned := _string_array(data.get("learned", []), 6)
	var key_actions := _string_array(data.get("key_actions", []), 8)
	var suggestions := _string_array(data.get("suggestions", []), 5)
	var checkpoint_actions := _action_array(data.get("checkpoint_actions", []))
	ui = {
		"title": str(data.get("title", "本关复盘")),
		"summary_cards": _summary_cards(key_actions, learned, suggestions, checkpoint_actions),
		"learned": learned,
		"key_actions": key_actions,
		"suggestions": suggestions,
		"checkpoint_actions": checkpoint_actions,
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


func _summary_cards(key_actions: Array, learned: Array, suggestions: Array, checkpoint_actions: Array) -> Array:
	var first_action := _first_text(key_actions, "完成了关键桌面动作。")
	var first_learned := _first_text(learned, "看目标、看地图、再行动。")
	var first_suggestion := _first_text(suggestions, "下一局先建立稳定现金流。")
	var replay_label := _first_action_label(checkpoint_actions, "回看关键节点")
	return [
		{
			"kind": "action",
			"kicker": "关键行动",
			"title": _short_text(first_action, 18),
			"detail": "这一步改变了桌面状态。",
		},
		{
			"kind": "learned",
			"kicker": "学到",
			"title": _short_text(first_learned, 18),
			"detail": "下次看到同类局面先扫这里。",
		},
		{
			"kind": "next",
			"kicker": "下次建议",
			"title": _short_text(first_suggestion, 18),
			"detail": "建议会随提示和失败记录变化。",
		},
		{
			"kind": "replay",
			"kicker": "回看",
			"title": _short_text(replay_label, 18),
			"detail": "需要时再看完整行动日志。",
		},
	]


func _first_text(entries: Array, fallback: String) -> String:
	for entry in entries:
		var text := str(entry).strip_edges()
		if text != "":
			return text
	return fallback


func _first_action_label(actions: Array, fallback: String) -> String:
	for action_variant in actions:
		if not (action_variant is Dictionary):
			continue
		var label := str((action_variant as Dictionary).get("label", "")).strip_edges()
		if label != "":
			return label
	return fallback


func _short_text(value: String, limit: int) -> String:
	var text := value.strip_edges()
	if text.length() <= limit:
		return text
	return "%s…" % text.left(maxi(1, limit - 1))


func _action_array(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for item in value:
			if item is Dictionary:
				result.append((item as Dictionary).duplicate(true))
	return result
