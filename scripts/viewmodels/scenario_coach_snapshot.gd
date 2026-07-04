extends RefCounted
class_name ScenarioCoachSnapshot

var ui: Dictionary = {}


func apply_dictionary(data: Dictionary) -> RefCounted:
	var phase: Dictionary = data.get("current_phase", {}) if data.get("current_phase", {}) is Dictionary else {}
	var scenario_id := str(data.get("scenario_id", "")).strip_edges()
	var title_text := str(data.get("title", "")).strip_edges()
	var completed := bool(data.get("completed", false))
	var has_scenario := scenario_id != "" or title_text != "" or not phase.is_empty() or completed
	if not has_scenario:
		ui = {
			"visible": false,
			"collapsed": true,
			"scenario_id": "",
			"title": "",
			"phase_id": "",
			"phase_label": "",
			"goal": "",
			"detail": "",
			"progress_text": "",
			"help_visible": false,
			"help_text": "",
			"focus_target": "",
			"failed_attempts": 0,
			"stuck_seconds": 0.0,
			"primary_action": {"id": "", "label": "", "disabled": true, "tooltip": ""},
			"secondary_actions": [],
			"font_scale_percent": int(data.get("font_scale_percent", 100)),
			"campaign_focus_mode": bool(data.get("campaign_focus_mode", data.get("compact", false))),
		}
		return self
	var closed_to_chip := bool(data.get("closed_to_chip", false))
	var index := int(data.get("current_index", 0))
	var total := maxi(1, int(data.get("total", 1)))
	var action_id := str(data.get("primary_action_id", "scenario_step_%s" % str(phase.get("id", "next"))))
	var failed_attempts := maxi(0, int(data.get("failed_attempts", 0)))
	var stuck_seconds := maxf(0.0, float(data.get("stuck_seconds", 0.0)))
	var strong_stuck := failed_attempts >= 2 or stuck_seconds >= 30.0
	var campaign_focus_mode := bool(data.get("campaign_focus_mode", data.get("compact", false)))
	var focus_target := str(phase.get("focus_target", data.get("focus_target", "scenario_coach"))).strip_edges()
	if focus_target == "":
		focus_target = "scenario_coach"
	var fallback_goal := "按桌边提示完成下一步。"
	var fallback_detail := "看高亮区域或底部行动条，完成当前桌边动作。"
	var help_text := str(phase.get("stuck_hint", phase.get("detail", phase.get("goal", fallback_detail)))).strip_edges()
	var help_visible := not completed and (failed_attempts >= 1 or stuck_seconds >= 20.0)
	var shortest_action_text := _shortest_action_text(phase, focus_target)
	var primary_label := str(phase.get("primary_action_hint", "定位下一步")) if not completed else "已完成"
	var goal_text := _compact_phase_goal(phase, fallback_goal) if campaign_focus_mode else str(phase.get("goal", fallback_goal))
	if help_visible:
		primary_label = "定位下一步"
		action_id = "scenario_focus_target"
	ui = {
		"visible": bool(data.get("visible", true)),
		"collapsed": closed_to_chip or completed,
		"scenario_id": scenario_id,
		"title": title_text if title_text != "" else "试玩剧本",
		"phase_id": str(phase.get("id", "")),
		"phase_label": str(phase.get("label", "目标")),
		"goal": goal_text if not completed else "剧本目标完成。",
		"detail": str(phase.get("detail", phase.get("goal", fallback_detail))),
		"progress_text": "%d/%d" % [mini(index + 1, total), total] if not completed else "%d/%d" % [total, total],
		"help_visible": help_visible,
		"help_text": help_text,
		"stuck_state": "strong" if strong_stuck and help_visible else ("hint" if help_visible else "none"),
		"pulse_focus": strong_stuck and help_visible,
		"shortest_action_text": shortest_action_text,
		"focus_target": focus_target,
		"failed_attempts": failed_attempts,
		"stuck_seconds": stuck_seconds,
		"primary_action": {
			"id": action_id,
			"label": primary_label,
			"disabled": completed,
			"tooltip": help_text if help_visible else str(phase.get("detail", phase.get("goal", ""))),
		},
		"secondary_actions": [
			{"id": "scenario_hint", "label": "提示"},
			{"id": "scenario_close_coach", "label": "收起"},
		] if campaign_focus_mode else [
			{"id": "scenario_close_coach", "label": "收起"},
			{"id": "scenario_hint", "label": "提示"},
			{"id": "scenario_focus_target", "label": "定位"},
			{"id": "scenario_restart", "label": "重开"},
		],
		"font_scale_percent": int(data.get("font_scale_percent", 92 if campaign_focus_mode else 100)),
		"campaign_focus_mode": campaign_focus_mode,
	}
	return self


func to_ui_dictionary() -> Dictionary:
	return ui.duplicate(true)


func _compact_phase_goal(phase: Dictionary, fallback: String) -> String:
	var phase_id := str(phase.get("id", "")).strip_edges()
	match phase_id:
		"select_district":
			return "选择一个陆地区域。"
		"first_summon":
			return "打出起始怪兽。"
		"build_city":
			return "建第一座城市。"
		"open_rack":
			return "双击亮起区域。"
		"compare_cards":
			return "悬停牌看用途。"
		"buy_pressure":
			return "点右下可买牌。"
		"discard_private":
			return "私密选旧牌。"
		"buy_card":
			return "买一张牌。"
		"play_card":
			return "打出一张手牌。"
		"select_track_card":
			return "点选顶部牌轨。"
		"read_inspector":
			return "查看右侧详情。"
		"open_card_detail":
			return "打开卡牌详情。"
		"read_bid_board":
			return "查看牌桌竞价。"
		"raise_bid":
			return "加价一次。"
		"reset_bid":
			return "清空预设报价。"
		"inspect_monster":
			return "查看怪兽压力。"
		"inspect_city_gdp":
			return "查看城市 GDP。"
		"open_economy":
			return "打开经济总览。"
		"inspect_goods":
			return "查看商品路线。"
		"offer_contract":
			return "发起一份合约。"
		"route_delta":
			return "查看商路变化。"
		"select_anonymous_card":
			return "选择一张公开牌。"
		"open_intel":
			return "打开情报档案。"
		"mark_guess":
			return "标记一次推测。"
		"read_goal":
			return "查看现金目标。"
		"open_standings":
			return "打开排名面板。"
		"open_settlement":
			return "查看结算复盘。"
	var goal := str(phase.get("goal", fallback)).strip_edges()
	if goal.length() <= 14:
		return goal
	if str(phase.get("label", "")).strip_edges() != "":
		return "%s：下一步。" % str(phase.get("label", "")).strip_edges()
	return fallback


func _shortest_action_text(phase: Dictionary, focus_target: String) -> String:
	var phase_id := str(phase.get("id", "")).strip_edges()
	match phase_id:
		"select_district":
			return "按定位，让星球转到推荐区。"
		"first_summon":
			return "看手牌，打出起始怪兽。"
		"build_city":
			return "看行动区，点城市化。"
		"open_rack":
			return "双击亮起区域。"
		"compare_cards":
			return "悬停牌看用途。"
		"buy_pressure", "buy_card":
			return "点右下可买牌。"
		"discard_private":
			return "私密选旧牌。"
		"play_card":
			return "看手牌，打出可用牌。"
		"select_track_card", "select_anonymous_card":
			return "看顶部牌轨，选一张牌。"
		"read_inspector":
			return "看右侧详情。"
		"open_card_detail":
			return "在右侧打开卡牌详情。"
		"read_bid_board":
			return "看底部竞价板。"
		"raise_bid":
			return "在竞价板加价一次。"
		"reset_bid":
			return "在竞价板清空报价。"
		"inspect_monster":
			return "看星球上的怪兽标记。"
		"inspect_city_gdp":
			return "看右侧 GDP 变化。"
		"open_economy":
			return "打开经济总览。"
		"inspect_goods":
			return "看商品路线信息。"
		"offer_contract":
			return "看商路，发起合约。"
		"route_delta":
			return "看商路高亮变化。"
		"open_intel":
			return "打开情报档案。"
		"mark_guess":
			return "在情报档案做一次标记。"
		"read_goal":
			return "看顶部现金目标。"
		"open_standings":
			return "打开排名面板。"
		"open_settlement":
			return "打开结算复盘。"
	match focus_target:
		"planet", "route_layer":
			return "看中央星球高亮。"
		"district_supply":
			return "看区域牌架。"
		"player_hand":
			return "看底部手牌。"
		"public_track":
			return "看顶部牌轨。"
		"right_inspector":
			return "看右侧详情。"
		"bid_board":
			return "看底部竞价板。"
		"economy_overview":
			return "打开经济总览。"
		"intel_dossier":
			return "打开情报档案。"
	return "按定位下一步。"
