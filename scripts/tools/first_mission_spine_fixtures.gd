extends RefCounted
class_name FirstMissionSpineFixtures

const PLAYER_TURN_FIXTURE_SCRIPT_PATH := "res://scripts/tools/player_turn_mcp_preview_fixtures.gd"
const TEMPORARY_DECISION_ACTION_ID := "temporary_decision:target:player_1"
const MISSION_COMPLETE_ACTION_ID := "mission:first_goal_complete"

var _player_fixtures: RefCounted = null


func mission_steps() -> Array:
	return [
		_step("boot_first_mission", "selected_enabled_card", "mission_briefing", "", "Boot the real table into a readable first mission state."),
		_step("inspect_first_card", "normal_hand", "hand_to_inspector", "", "Pick the first playable card and confirm RightInspector explains it."),
		_step("execute_first_action", "selected_enabled_card", "action_feedback", "play:shadow_contract", "Submit the first enabled action through the existing GameScreen signal path."),
		_step("read_public_track", "public_track_selection", "public_track", "track:contract_a", "Read a public clue without exposing hidden source fields."),
		_step("temporary_decision_if_present", "temporary_decision_pending_hint", "temporary_decision_overlay", TEMPORARY_DECISION_ACTION_ID, "Use the real OverlayLayer for a pending temporary decision."),
		_step("end_turn", "selected_enabled_card", "turn_advance", "end_turn", "End Turn stays visible and leaves clear pending feedback."),
		_step("mission_step_feedback", "selected_enabled_card", "mission_complete_feedback", MISSION_COMPLETE_ACTION_ID, "Complete the first objective through coach-driven UI feedback."),
	]


func mission_step_ids() -> Array[String]:
	var ids: Array[String] = []
	for step_variant in mission_steps():
		var step_data: Dictionary = step_variant if step_variant is Dictionary else {}
		ids.append(str(step_data.get("step_id", "")))
	return ids


func step(step_id: String) -> Dictionary:
	for step_variant in mission_steps():
		var step_data: Dictionary = step_variant if step_variant is Dictionary else {}
		if str(step_data.get("step_id", "")) == step_id:
			return step_data.duplicate(true)
	return {}


func player_fixture(fixture_id: String) -> Dictionary:
	var fixtures := _player_fixture_source()
	if fixtures == null:
		return {}
	var value: Variant = fixtures.call("fixture", fixture_id)
	return value.duplicate(true) if value is Dictionary else {}


func table_state_for_step(step_id: String) -> Dictionary:
	var step_data := step(step_id)
	if step_data.is_empty():
		return {}
	var fixture := player_fixture(str(step_data.get("fixture_id", "normal_hand")))
	return _table_state_from_fixture(fixture, step_data)


func temporary_decision_payload() -> Dictionary:
	return {
		"id": "first_mission_spine_player_target",
		"kind": "player_target_choice",
		"title": "选择第一局合约目标",
		"summary": "第一局任务正在等待你完成一次目标选择。",
		"body": "这个 payload 只用于 FirstMissionSpineBench，不调用规则函数。",
		"chips": [{"text": "私密选择"}, {"text": "公开线索"}, {"text": "任务推进"}],
		"actions": [
			{"id": TEMPORARY_DECISION_ACTION_ID, "label": "玩家 1", "disabled": false},
			{"id": "temporary_decision:cancel", "label": "取消", "disabled": false},
		],
		"choice": {
			"mode": "player_target",
			"summary": "选择目标后回到主游戏表面。",
			"privacy": "目标选择保持私密。",
			"public_after": "只公开线索结果，不公开隐藏归属字段。",
		},
	}


func _step(step_id: String, fixture_id: String, expected_surface: String, expected_action_id: String, notes: String) -> Dictionary:
	return {
		"step_id": step_id,
		"fixture_id": fixture_id,
		"expected_surface": expected_surface,
		"expected_action_id": expected_action_id,
		"notes": notes,
	}


func _table_state_from_fixture(fixture: Dictionary, step_data: Dictionary) -> Dictionary:
	var player_state: Dictionary = fixture.get("player_state", {}) if fixture.get("player_state", {}) is Dictionary else {}
	var inspector: Dictionary = fixture.get("inspector", {}) if fixture.get("inspector", {}) is Dictionary else {}
	var public_track: Array = fixture.get("public_track", []) if fixture.get("public_track", []) is Array else []
	var step_id := str(step_data.get("step_id", ""))
	return {
		"top_bar": _top_bar_for_step(step_id, player_state),
		"card_track": _public_track_for_runtime(public_track),
		"planet": _planet_for_step(step_id),
		"right_inspector": inspector,
		"player_board": _player_board_for_step(step_id, player_state),
		"first_run_coach": _first_run_coach_for_step(step_id),
		"scenario_coach": _scenario_coach_for_step(step_id),
		"temporary_decision": temporary_decision_payload() if step_id == "temporary_decision_if_present" else {},
	}


func _top_bar_for_step(step_id: String, player_state: Dictionary) -> Dictionary:
	return {
		"phase": "第一局任务",
		"turn": "第一轮",
		"identity": str(player_state.get("identity", "你｜走私商")),
		"cash_text": str(player_state.get("cash_text", "$18")),
		"gdp_text": str(player_state.get("gdp_text", "+4/min")),
		"goal_text": str(player_state.get("goal_text", "声望 6/10")),
		"selected_district": str(player_state.get("selected_district_summary", "中央贸易区")),
		"primary_action": _primary_action_for_step(step_id),
		"weather": "天气:无影响｜预报:稳定开局",
		"show_end_turn": true,
		"end_turn_label": "结束回合",
		"end_turn_tooltip": "提交第一局任务的本轮行动，进入下一阶段。",
	}


func _player_board_for_step(step_id: String, player_state: Dictionary) -> Dictionary:
	var result := player_state.duplicate(true)
	result["title"] = "第一局任务｜玩家回合"
	result["hint"] = _hint_for_step(step_id)
	result["primary_action"] = _primary_action_for_step(step_id)
	result["progress_path"] = [
		{"text": "目标", "active": true},
		{"text": "选牌", "active": step_id != "boot_first_mission"},
		{"text": "执行", "active": ["execute_first_action", "read_public_track", "temporary_decision_if_present", "end_turn", "mission_step_feedback"].has(step_id)},
		{"text": "收束", "active": ["end_turn", "mission_step_feedback"].has(step_id)},
	]
	result["readiness_chips"] = [
		{"text": "首局目标", "active": true},
		{"text": "可用手牌", "active": step_id != "temporary_decision_if_present"},
		{"text": "Overlay 待处理", "active": step_id == "temporary_decision_if_present"},
	]
	result["actions"] = [
		{"id": "inspect:selected", "label": "查看详情", "disabled": false, "tooltip": "在右侧查看当前对象。"},
		{"id": MISSION_COMPLETE_ACTION_ID, "label": "完成第一目标", "disabled": step_id != "mission_step_feedback", "tooltip": "完成选牌、详情和行动提交后可用。"},
	]
	return result


func _first_run_coach_for_step(step_id: String) -> Dictionary:
	return {
		"visible": true,
		"collapsed": false,
		"stage": "first_mission_spine",
		"phase_label": "第一局",
		"title": "第一目标",
		"body": _hint_for_step(step_id),
		"progress_text": _progress_text_for_step(step_id),
		"primary_action": {
			"id": MISSION_COMPLETE_ACTION_ID if step_id == "mission_step_feedback" else "mission:next_step",
			"label": "完成目标" if step_id == "mission_step_feedback" else _primary_action_for_step(step_id),
			"tooltip": "第一局任务只推进 UI 指引，不调用规则函数。",
			"accent": "#38bdf8",
			"disabled": false,
		},
		"chips": [
			{"text": "选牌"},
			{"text": "看详情"},
			{"text": "行动"},
			{"text": "回合"},
		],
	}


func _scenario_coach_for_step(step_id: String) -> Dictionary:
	var phase := {
		"id": step_id,
		"label": _primary_action_for_step(step_id),
		"goal": _hint_for_step(step_id),
		"detail": "完成第一张可用牌、读取公开线索、处理临时决策，然后结束回合。",
		"primary_action_hint": "完成第一目标" if step_id == "mission_step_feedback" else "看提示",
		"stuck_hint": "从底部手牌开始；右侧详情会说明条件、目标和效果。",
		"focus_target": "player_hand" if ["inspect_first_card", "execute_first_action"].has(step_id) else "scenario_coach",
	}
	return {
		"scenario_id": "first_mission_spine",
		"visible": true,
		"collapsed": false,
		"title": "第一局任务",
		"current_phase": phase,
		"current_index": mission_step_ids().find(step_id),
		"total": mission_step_ids().size(),
		"primary_action_id": MISSION_COMPLETE_ACTION_ID if step_id == "mission_step_feedback" else "mission:show_hint",
		"failed_attempts": 0,
		"stuck_seconds": 0.0,
		"secondary_actions": [
			{"id": "mission:next_step", "label": "下一步"},
		],
	}


func _planet_for_step(step_id: String) -> Dictionary:
	return {
		"title": "第一局任务骨架",
		"hint": "目标：开局 -> 选牌 -> 执行 -> 读线索 -> 决策 -> 结束回合",
		"weather": {"active": "无天气", "forecast": "稳定开局", "impact": "无负面影响"},
		"table_lanes": [
			{"title": "当前目标", "detail": _primary_action_for_step(step_id)},
			{"title": "任务反馈", "detail": _hint_for_step(step_id)},
		],
	}


func _primary_action_for_step(step_id: String) -> String:
	match step_id:
		"boot_first_mission":
			return "看第一目标"
		"inspect_first_card":
			return "选择手牌"
		"execute_first_action":
			return "执行卡牌"
		"read_public_track":
			return "读取线索"
		"temporary_decision_if_present":
			return "完成决策"
		"end_turn":
			return "结束回合"
		"mission_step_feedback":
			return "完成第一目标"
	return "第一局行动"


func _hint_for_step(step_id: String) -> String:
	match step_id:
		"boot_first_mission":
			return "先确认身份、资金、目标声望和第一张可用手牌。"
		"inspect_first_card":
			return "点击底部手牌，右侧会显示用途、目标、条件和效果。"
		"execute_first_action":
			return "执行一张可用牌，动作仍走现有信号流。"
		"read_public_track":
			return "读取公共线索；只看公开信息，不泄露私密来源。"
		"temporary_decision_if_present":
			return "Overlay 正在等待目标选择；完成后回到桌面。"
		"end_turn":
			return "结束回合后留下 pending 反馈，等待下一阶段。"
		"mission_step_feedback":
			return "第一目标完成：你已经完成一次核心行动闭环。"
	return "完成当前第一局任务步骤。"


func _progress_text_for_step(step_id: String) -> String:
	var ids := mission_step_ids()
	var index := ids.find(step_id)
	return "%d/%d" % [maxi(1, index + 1), ids.size()]


func _public_track_for_runtime(entries: Array) -> Array:
	var result: Array = []
	for entry_variant in entries:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = (entry_variant as Dictionary).duplicate(true)
		if str(entry.get("select_action", "")).strip_edges() == "":
			var fallback_action := str(entry.get("hover_action", entry.get("id", ""))).strip_edges()
			if fallback_action != "":
				entry["select_action"] = fallback_action
		result.append(entry)
	return result


func _player_fixture_source() -> RefCounted:
	if _player_fixtures != null:
		return _player_fixtures
	var script := load(PLAYER_TURN_FIXTURE_SCRIPT_PATH)
	if script == null:
		return null
	var instance: Variant = script.new()
	if instance is RefCounted:
		_player_fixtures = instance
	return _player_fixtures
