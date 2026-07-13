extends RefCounted
class_name FirstRoundRuntimePlayableLoopFixtures

const PLAYER_TURN_FIXTURE_SCRIPT_PATH := "res://scripts/tools/player_turn_mcp_preview_fixtures.gd"
const TEMPORARY_DECISION_ACTION_ID := "first_round:temporary:choose_player_1"

const CASE_IDS := [
	"boot_to_first_player_turn",
	"inspect_opening_hand_card",
	"execute_enabled_card_action",
	"disabled_action_guard",
	"public_track_after_action_feedback",
	"planet_map_after_action_feedback",
	"temporary_decision_pending_flow",
	"end_turn_or_advance_step",
	"privacy_boundary_runtime",
	"recovery_after_action_sequence",
]

var _player_fixtures: RefCounted = null


func case_ids() -> Array[String]:
	var result: Array[String] = []
	for id in CASE_IDS:
		result.append(str(id))
	return result


func cases() -> Array:
	var result: Array = []
	for id in CASE_IDS:
		result.append(case_data(str(id)))
	return result


func case_data(case_id: String) -> Dictionary:
	match case_id:
		"boot_to_first_player_turn":
			return _case(case_id, "normal_hand", "boot", "card_orbital_finance", "", "玩家回合", "Boot the real GameScreen into a readable first player turn.")
		"inspect_opening_hand_card":
			return _case(case_id, "normal_hand", "inspect_card", "card_orbital_finance", "", "轨道融资", "Click an opening hand card and read it in RightInspector.")
		"execute_enabled_card_action":
			return _case(case_id, "selected_enabled_card", "execute_card_action", "card_shadow_contract", "play:shadow_contract", "影子合约", "Execute an enabled card action through GameScreen.action_requested.")
		"disabled_action_guard":
			return _case(case_id, "selected_disabled_card", "disabled_action_guard", "card_monster_tip_blocked", "play:monster_tip", "怪兽赌局尚未开启", "Disabled action remains visible but silent.")
		"public_track_after_action_feedback":
			return _case(case_id, "public_track_selection", "public_track_response", "card_orbital_finance", "first_round:track:bid", "公开报价", "Public track slot selection and response action bridge through GameScreen.")
		"planet_map_after_action_feedback":
			return _case(case_id, "selected_enabled_card", "planet_map_action", "card_shadow_contract", "", "雾港城", "PlanetMapView selection, double-click, focus, and sceneized cutover stay live.")
		"temporary_decision_pending_flow":
			return _case(case_id, "temporary_decision_pending_hint", "temporary_decision", "card_shadow_contract", TEMPORARY_DECISION_ACTION_ID, "选择合约目标", "Temporary decision overlay emits through the existing action flow.")
		"end_turn_or_advance_step":
			return _case(case_id, "selected_enabled_card", "end_turn", "card_shadow_contract", "end_turn_requested", "第一轮", "End Turn emits the compatible signal and keeps table context.")
		"privacy_boundary_runtime":
			return _case(case_id, "public_track_selection", "privacy_boundary", "card_orbital_finance", "", "匿名", "Visible UI and QA payload stay free of private owner tokens.")
		"recovery_after_action_sequence":
			return _case(case_id, "temporary_decision_pending_hint", "recovery_sequence", "card_shadow_contract", "end_turn_requested", "第一轮", "Select card, inspect map, read track, resolve overlay, and end turn without stale UI.")
	return _case("boot_to_first_player_turn", "normal_hand", "boot", "card_orbital_finance", "", "玩家回合", "Fallback first-round boot case.")


func table_state_for_case(flow_case: Dictionary) -> Dictionary:
	var fixture := player_fixture(str(flow_case.get("fixture_id", "normal_hand")))
	return _table_state_from_fixture(fixture, flow_case)


func player_fixture(fixture_id: String) -> Dictionary:
	var source := _player_fixture_source()
	if source == null:
		return {}
	var value: Variant = source.call("fixture", fixture_id)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func temporary_decision_payload() -> Dictionary:
	return {
		"id": "first_round_player_target_choice",
		"kind": "player_target_choice",
		"title": "选择合约目标",
		"summary": "第一轮合约行动正在等待目标选择。",
		"body": "这个 payload 只用于 FirstRoundRuntimePlayableLoopBench，不调用规则函数。",
		"chips": [{"text": "私密目标"}, {"text": "公开后结算"}],
		"actions": [
			{"id": TEMPORARY_DECISION_ACTION_ID, "label": "玩家 1", "disabled": false},
			{"id": "first_round:temporary:cancel", "label": "取消", "disabled": false},
		],
		"choice": {
			"mode": "player_target",
			"summary": "选择目标后才进入公开线索。",
			"privacy": "目标选择保持私密。",
			"public_after": "只公开合约已回应，不公开隐藏归属字段。",
		},
	}


func map_payload_for_case(flow_case: Dictionary) -> Dictionary:
	var case_id := str(flow_case.get("case_id", ""))
	var payload := _base_map_payload()
	match case_id:
		"planet_map_after_action_feedback", "recovery_after_action_sequence":
			payload["selected"] = 1
			payload["projection"] = "local"
			payload["hint"] = "第一轮行动聚焦雾港城，路线和 callout 均由 sceneized 地图组件显示。"
			payload["movement_trails"] = [
				{"from": [760, 310], "to": [1035, 560], "accent": "#38bdf8", "label": "合约路径"},
			]
			payload["action_callouts"] = [
				{"title": "首轮行动", "detail": "影子合约已指向雾港城。", "position": [760, 310], "accent": "#facc15"},
			]
			payload["map_event_effects"] = [
				{"position": [760, 310], "label": "反馈", "color": "#a78bfa"},
			]
	return payload


func _case(case_id: String, fixture_id: String, interaction: String, selected_card_id: String, expected_action_id: String, expected_text: String, notes: String) -> Dictionary:
	return {
		"case_id": case_id,
		"fixture_id": fixture_id,
		"interaction": interaction,
		"selected_card_id": selected_card_id,
		"expected_action_id": expected_action_id,
		"expected_inspector_text": expected_text,
		"notes": notes,
	}


func _table_state_from_fixture(fixture: Dictionary, flow_case: Dictionary) -> Dictionary:
	var case_id := str(flow_case.get("case_id", ""))
	var player_state: Dictionary = fixture.get("player_state", {}) if fixture.get("player_state", {}) is Dictionary else {}
	var inspector: Dictionary = fixture.get("inspector", {}) if fixture.get("inspector", {}) is Dictionary else {}
	var selected_card: Dictionary = fixture.get("selected_card", {}) if fixture.get("selected_card", {}) is Dictionary else {}
	player_state = player_state.duplicate(true)
	player_state["hint"] = _player_hint_for_case(case_id)
	player_state["primary_action"] = _primary_action_for_case(case_id)
	player_state["readiness_chips"] = _readiness_for_case(case_id)
	player_state["progress_path"] = _progress_for_case(case_id)
	player_state["runtime_feedback"] = {
		"kind": "first_round",
		"action_id": str(flow_case.get("expected_action_id", "")),
		"label": _primary_action_for_case(case_id),
		"detail": _player_hint_for_case(case_id),
	}
	if not selected_card.is_empty():
		player_state["selected_card"] = selected_card
	return {
		"top_bar": _top_bar_for_case(case_id, player_state),
		"card_track": _public_track_entries_for_case(case_id),
		"card_resolution_track": _card_resolution_track_state_for_case(case_id),
		"planet": _planet_panel_state_for_case(case_id),
		"right_inspector": inspector,
		"player_board": player_state,
		"first_run_coach": _coach_for_case(case_id),
		"temporary_decision": temporary_decision_payload() if case_id in ["temporary_decision_pending_flow", "recovery_after_action_sequence"] else {},
	}


func _top_bar_for_case(case_id: String, player_state: Dictionary) -> Dictionary:
	return {
		"phase": "玩家回合",
		"turn": "第一轮",
		"identity": str(player_state.get("identity", "你｜走私商")),
		"cash_text": str(player_state.get("cash_text", "$18")),
		"gdp_text": str(player_state.get("gdp_text", "+4/min")),
		"goal_text": str(player_state.get("goal_text", "声望 6/10")),
		"selected_district": "雾港城",
		"primary_action": _primary_action_for_case(case_id),
		"weather": "天气:无影响｜预报:开局稳定",
		"show_end_turn": true,
		"end_turn_label": "结束回合",
		"end_turn_tooltip": "提交第一轮核心行动，进入下一阶段。",
	}


func _planet_panel_state_for_case(case_id: String) -> Dictionary:
	return {
		"title": "第一轮星球局势",
		"hint": "选牌、看地图、读牌轨、处理 Overlay，然后结束回合。",
		"weather": {"active": "现在：稳定", "forecast": "预报：无天气", "impact": "影响：无"},
		"left_rail": {
			"title": "地表情报",
			"entries": [
				{"label": "选区", "value": "雾港城", "active": true, "accent": "#38bdf8"},
				{"label": "目标", "value": _primary_action_for_case(case_id), "active": true, "accent": "#facc15"},
				{"label": "路线", "value": "可追踪", "active": case_id == "planet_map_after_action_feedback", "accent": "#22c55e"},
			],
		},
		"right_rail": {
			"title": "外围压力",
			"entries": [
				{"label": "牌轨", "value": "响应窗", "active": true, "accent": "#f59e0b"},
				{"label": "怪兽", "value": "低压", "active": false, "accent": "#fb7185"},
				{"label": "决策", "value": "待选" if case_id == "temporary_decision_pending_flow" else "空闲", "active": case_id == "temporary_decision_pending_flow", "accent": "#a78bfa"},
			],
		},
		"flow_compass": {
			"title": "第一轮",
			"current_index": _flow_index_for_case(case_id),
			"steps": [
				{"label": "开局", "done": case_id != "boot_to_first_player_turn"},
				{"label": "选牌", "done": case_id in ["execute_enabled_card_action", "disabled_action_guard", "public_track_after_action_feedback", "planet_map_after_action_feedback", "temporary_decision_pending_flow", "end_turn_or_advance_step", "recovery_after_action_sequence"]},
				{"label": "出牌", "done": case_id in ["public_track_after_action_feedback", "planet_map_after_action_feedback", "temporary_decision_pending_flow", "end_turn_or_advance_step", "recovery_after_action_sequence"]},
				{"label": "牌轨", "done": case_id in ["temporary_decision_pending_flow", "end_turn_or_advance_step", "recovery_after_action_sequence"]},
				{"label": "结束", "done": false},
			],
			"next_text": _primary_action_for_case(case_id),
		},
	}


func _card_resolution_track_state_for_case(case_id: String) -> Dictionary:
	var state := {
		"title": "公共结算轨",
		"phase": "第一轮",
		"summary": "公开牌轨显示匿名线索、响应窗口和结算历史。",
		"privacy_hint": "未公开归属前只显示待猜线索。",
		"empty_text": "牌轨空闲，等待玩家出牌。",
		"entries": _public_track_entries_for_case(case_id),
	}
	if case_id in ["public_track_after_action_feedback", "recovery_after_action_sequence"]:
		state["phase"] = "公开报价"
		state["auction_response"] = {
			"active": true,
			"summary": "公开报价窗口开启；可用响应按钮必须走 GameScreen action_requested。",
			"actions": [
				{"id": "first_round:track:bid", "label": "公开报价", "disabled": false, "tooltip": "第一轮牌轨响应。"},
				{"id": "first_round:track:locked", "label": "强制反制", "disabled": true, "reason": "资源不足，不能强制反制。"},
			],
		}
	return state


func _public_track_entries_for_case(case_id: String) -> Array:
	var active := case_id in ["public_track_after_action_feedback", "recovery_after_action_sequence"]
	return [
		{
			"id": "first_round_track_contract",
			"resolution_id": 3101,
			"slot": "#1",
			"label": "匿名合约",
			"title": "匿名合约",
			"state": "待回应" if active else "队列",
			"kind": "queue",
			"owner_hint": "待猜",
			"cost": "$2",
			"accent": "#a78bfa",
			"badges": ["公开"],
			"select_action": "first_round:track:select_contract",
			"open_action": "first_round:track:open_contract",
			"active": active,
			"selected": active,
			"summary": "匿名合约进入公共结算轨。",
			"detail": "只展示公开标签、报价和状态。",
			"tooltip": "公开线索：匿名合约等待回应。",
		},
		{
			"id": "first_round_track_finance",
			"resolution_id": 3102,
			"slot": "#2",
			"label": "轨道融资",
			"title": "轨道融资",
			"state": "已排队",
			"kind": "queue",
			"owner_hint": "待猜",
			"cost": "$3",
			"accent": "#38bdf8",
			"badges": ["融资"],
			"select_action": "first_round:track:select_finance",
			"open_action": "first_round:track:open_finance",
			"active": false,
			"summary": "融资牌等待结算。",
			"detail": "公共区不公开来源。",
			"tooltip": "公开线索：融资牌进入队列。",
		},
	]


func _base_map_payload() -> Dictionary:
	return {
		"id": "first_round_runtime_map",
		"title": "第一轮地图",
		"hint": "中心星球地图由 sceneized PlanetMapView 呈现。",
		"map_width_m": 1400,
		"map_height_m": 950,
		"selected": 0,
		"districts": [
			{"name": "寒冠洋", "terrain": "ocean", "center": [360, 260], "radius_m": 84, "hp": 18, "damage": 2, "panic": 16, "products": ["ice"], "polygon": [[210, 160], [520, 180], [500, 340], [240, 360]]},
			{"name": "雾港城", "terrain": "land", "center": [760, 310], "radius_m": 78, "hp": 20, "damage": 4, "panic": 35, "products": ["ore"], "city": {"level": 2}, "polygon": [[620, 220], [890, 210], [930, 390], [650, 420]]},
			{"name": "商路中继", "terrain": "ocean", "center": [520, 610], "radius_m": 68, "hp": 16, "damage": 1, "panic": 8, "products": ["water"], "polygon": [[360, 500], [620, 500], [640, 700], [390, 720]]},
			{"name": "轨道港", "terrain": "land", "center": [1160, 240], "radius_m": 64, "hp": 14, "damage": 0, "panic": 12, "products": ["fuel"], "polygon": [[1040, 130], [1300, 160], [1275, 335], [1055, 365]]},
		],
		"palette": ["#0ea5e9", "#22c55e", "#f59e0b", "#a855f7"],
		"projection": "globe",
		"monster_markers": [{"position": [1035, 560], "tag": "低压", "accent": "#fb7185"}],
		"city_markers": [{"position": [760, 310], "tag": "2", "level": 2, "products": ["ore"], "tag_color": "#38bdf8", "active": true}],
		"trade_routes": [{"points": [[760, 310], [1160, 240]], "label": "融资航线", "accent": "#38bdf8", "active": true}],
		"movement_trails": [],
		"action_callouts": [{"title": "第一轮", "detail": "选择区域并读右侧详情。", "position": [760, 310], "accent": "#facc15"}],
		"map_event_effects": [],
		"trade_product": "ore",
		"visual_layer_focus": "all",
	}


func _coach_for_case(case_id: String) -> Dictionary:
	return {
		"visible": true,
		"collapsed": false,
		"stage": "first_round_runtime_playable_loop",
		"title": "第一轮目标",
		"body": "按顺序完成选牌、看详情、执行、牌轨回应、地图反馈、临时决策和结束回合。",
		"progress": case_id,
		"primary_action": {"id": "first_round:%s" % case_id, "label": _primary_action_for_case(case_id), "accent": "#38bdf8"},
		"chips": [{"text": "选牌"}, {"text": "看详情"}, {"text": "执行"}, {"text": "结束"}],
	}


func _player_hint_for_case(case_id: String) -> String:
	match case_id:
		"boot_to_first_player_turn":
			return "第一轮已开始：先看目标，再选一张手牌。"
		"inspect_opening_hand_card":
			return "已选中手牌，右侧显示用途、目标、条件和效果。"
		"execute_enabled_card_action":
			return "行动已提交，等待公共反馈和可能的临时决策。"
		"disabled_action_guard":
			return "这个行动当前不可执行，原因必须可见。"
		"public_track_after_action_feedback":
			return "公共牌轨正在等待响应窗口处理。"
		"planet_map_after_action_feedback":
			return "地图聚焦本轮目标区域。"
		"temporary_decision_pending_flow":
			return "等待 Overlay 决策，主表面不绕过临时决策。"
		"end_turn_or_advance_step":
			return "结束本轮行动并进入下一阶段。"
		"privacy_boundary_runtime":
			return "只显示公开线索和待猜信息。"
		"recovery_after_action_sequence":
			return "连续操作后所有 UI 状态应恢复一致。"
	return "第一轮行动。"


func _primary_action_for_case(case_id: String) -> String:
	match case_id:
		"boot_to_first_player_turn":
			return "查看目标"
		"inspect_opening_hand_card":
			return "查看手牌"
		"execute_enabled_card_action":
			return "执行合约"
		"disabled_action_guard":
			return "查看原因"
		"public_track_after_action_feedback":
			return "处理牌轨"
		"planet_map_after_action_feedback":
			return "查看地图"
		"temporary_decision_pending_flow":
			return "选择目标"
		"end_turn_or_advance_step":
			return "结束回合"
		"privacy_boundary_runtime":
			return "检查隐私"
		"recovery_after_action_sequence":
			return "恢复状态"
	return "第一轮"


func _readiness_for_case(case_id: String) -> Array:
	return [
		{"text": "第一轮", "active": true},
		{"text": _primary_action_for_case(case_id), "active": true},
		{"text": "Overlay 待选", "active": case_id in ["temporary_decision_pending_flow", "recovery_after_action_sequence"]},
	]


func _progress_for_case(case_id: String) -> Array:
	return [
		{"text": "选牌", "active": true},
		{"text": "出牌", "active": case_id != "boot_to_first_player_turn"},
		{"text": "牌轨", "active": case_id in ["public_track_after_action_feedback", "recovery_after_action_sequence"]},
		{"text": "结束", "active": case_id == "end_turn_or_advance_step"},
	]


func _flow_index_for_case(case_id: String) -> int:
	match case_id:
		"boot_to_first_player_turn":
			return 0
		"inspect_opening_hand_card":
			return 1
		"execute_enabled_card_action", "disabled_action_guard":
			return 2
		"public_track_after_action_feedback", "planet_map_after_action_feedback":
			return 3
		"temporary_decision_pending_flow", "recovery_after_action_sequence":
			return 4
		"end_turn_or_advance_step":
			return 5
	return 1


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
