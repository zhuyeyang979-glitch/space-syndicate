extends RefCounted
class_name ScenarioCoachSnapshot

var ui: Dictionary = {}


func apply_dictionary(data: Dictionary) -> RefCounted:
	var phase: Dictionary = data.get("current_phase", {}) if data.get("current_phase", {}) is Dictionary else {}
	var completed := bool(data.get("completed", false))
	var closed_to_chip := bool(data.get("closed_to_chip", false))
	var index := int(data.get("current_index", 0))
	var total := maxi(1, int(data.get("total", 1)))
	var action_id := str(data.get("primary_action_id", "scenario_step_%s" % str(phase.get("id", "next"))))
	ui = {
		"visible": bool(data.get("visible", true)),
		"collapsed": closed_to_chip or completed,
		"scenario_id": str(data.get("scenario_id", "")),
		"title": str(data.get("title", "试玩剧本")),
		"phase_id": str(phase.get("id", "")),
		"phase_label": str(phase.get("label", "目标")),
		"goal": str(phase.get("goal", "完成当前目标。")) if not completed else "剧本目标完成。",
		"detail": str(phase.get("detail", phase.get("goal", ""))),
		"progress_text": "%d/%d" % [mini(index + 1, total), total] if not completed else "%d/%d" % [total, total],
		"primary_action": {
			"id": action_id,
			"label": str(phase.get("primary_action_hint", "下一步")) if not completed else "已完成",
			"disabled": completed,
			"tooltip": str(phase.get("detail", phase.get("goal", ""))),
		},
		"secondary_actions": [
			{"id": "scenario_close_coach", "label": "收起"},
			{"id": "scenario_hint", "label": "提示"},
			{"id": "scenario_skip_step", "label": "跳过"},
			{"id": "scenario_restart", "label": "重开"},
		],
		"font_scale_percent": int(data.get("font_scale_percent", 100)),
	}
	return self


func to_ui_dictionary() -> Dictionary:
	return ui.duplicate(true)
