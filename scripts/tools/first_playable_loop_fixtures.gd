extends RefCounted
class_name FirstPlayableLoopFixtures

const PLAYER_TURN_FIXTURE_SCRIPT_PATH := "res://scripts/tools/player_turn_mcp_preview_fixtures.gd"
const TEMPORARY_DECISION_ACTION_ID := "temporary_decision:target:player_1"

var _player_fixtures: RefCounted = null


func loop_steps() -> Array:
	return [
		_step("boot_to_player_turn", "selected_enabled_card", "full_table", "", "Open the table into a readable first player turn."),
		_step("inspect_first_card", "normal_hand", "hand_to_inspector", "", "Click the first playable hand card and confirm the right inspector explains it."),
		_step("execute_enabled_action", "selected_enabled_card", "action_feedback", "play:shadow_contract", "Execute an enabled card action through the real GameScreen signal path."),
		_step("disabled_action_guard", "selected_disabled_card", "disabled_guard", "play:monster_tip", "Disabled card action stays visible with a reason and does not emit."),
		_step("public_track_safe_read", "public_track_selection", "public_track", "track:contract_a", "Public track selection shows public context without hidden owner leakage."),
		_step("temporary_decision_roundtrip", "temporary_decision_pending_hint", "temporary_decision_overlay", TEMPORARY_DECISION_ACTION_ID, "Temporary decision uses OverlayLayer and returns through its action signal."),
		_step("end_turn_feedback", "selected_enabled_card", "turn_advance", "end_turn", "End Turn remains a compatible signal and leaves clear player feedback."),
	]


func loop_step_ids() -> Array[String]:
	var ids: Array[String] = []
	for step_variant in loop_steps():
		var step_data: Dictionary = step_variant if step_variant is Dictionary else {}
		ids.append(str(step_data.get("step_id", "")))
	return ids


func step(step_id: String) -> Dictionary:
	for step_variant in loop_steps():
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
		"id": "first_playable_loop_player_target",
		"kind": "player_target_choice",
		"title": "选择合约目标",
		"summary": "第一轮竖切片正在等待玩家完成 Overlay 目标选择。",
		"body": "这个 payload 只用于 FirstPlayableLoopBench，不调用规则函数。",
		"chips": [{"text": "私密选择"}, {"text": "公开后结算"}],
		"actions": [
			{"id": TEMPORARY_DECISION_ACTION_ID, "label": "玩家 1", "disabled": false},
			{"id": "temporary_decision:cancel", "label": "取消", "disabled": false},
		],
		"choice": {
			"mode": "player_target",
			"summary": "选择目标后才进入公开线索。",
			"privacy": "目标选择保持私密。",
			"public_after": "只公开合约已回应，不公开隐藏归属字段。",
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
		"player_board": player_state,
		"first_run_coach": _coach_for_step(step_id),
		"temporary_decision": temporary_decision_payload() if step_id == "temporary_decision_roundtrip" else {},
	}


func _top_bar_for_step(step_id: String, player_state: Dictionary) -> Dictionary:
	return {
		"phase": "玩家回合",
		"turn": "第一轮",
		"identity": str(player_state.get("identity", "你｜走私商")),
		"cash_text": str(player_state.get("cash_text", "$18")),
		"gdp_text": str(player_state.get("gdp_text", "+4/min")),
		"goal_text": str(player_state.get("goal_text", "声望 6/10")),
		"selected_district": str(player_state.get("selected_district_summary", "中央贸易区")),
		"primary_action": _primary_action_for_step(step_id),
		"weather": "天气:无影响｜预报:开局稳定",
		"show_end_turn": true,
		"end_turn_label": "结束回合",
		"end_turn_tooltip": "提交第一轮核心行动，进入下一阶段。",
	}


func _primary_action_for_step(step_id: String) -> String:
	match step_id:
		"boot_to_player_turn":
			return "看目标"
		"inspect_first_card":
			return "选手牌"
		"execute_enabled_action":
			return "执行卡牌"
		"disabled_action_guard":
			return "查看原因"
		"public_track_safe_read":
			return "读公共线索"
		"temporary_decision_roundtrip":
			return "选择目标"
		"end_turn_feedback":
			return "结束回合"
	return "第一轮行动"


func _planet_for_step(step_id: String) -> Dictionary:
	return {
		"title": "第一轮可玩竖切片",
		"hint": "目标：选牌 -> 看详情 -> 执行 -> 处理临时决策 -> 结束回合",
		"weather": {"active": "无天气", "forecast": "开局稳定", "impact": "无负面影响"},
		"table_lanes": [
			{"title": "当前目标", "detail": _primary_action_for_step(step_id)},
			{"title": "玩家操作", "detail": "真实 GameScreen / PlayerBoard / OverlayLayer"},
		],
	}


func _coach_for_step(step_id: String) -> Dictionary:
	return {
		"visible": true,
		"collapsed": false,
		"stage": "first_playable_loop",
		"title": "第一轮目标",
		"body": "选择一张手牌，确认右侧详情，再执行一个行动。若出现临时决策，先完成 Overlay。",
		"progress": "Step %s" % step_id,
		"primary_action": {"id": "loop:%s" % step_id, "label": _primary_action_for_step(step_id), "accent": Color("#38bdf8")},
		"chips": [
			{"text": "选牌"},
			{"text": "看详情"},
			{"text": "执行"},
			{"text": "结束回合"},
		],
	}


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
