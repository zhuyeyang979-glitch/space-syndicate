extends RefCounted
class_name PlayerTurnMcpPreviewFixtures

const PREVIEW_IDS := [
	"empty_hand",
	"normal_hand",
	"selected_enabled_card",
	"selected_disabled_card",
	"hovered_card",
	"drag_preview",
	"right_inspector_card_detail",
	"public_track_selection",
	"temporary_decision_pending_hint",
]


func preview_ids() -> Array[String]:
	var result: Array[String] = []
	for id in PREVIEW_IDS:
		result.append(str(id))
	return result


func preview_label(id: String) -> String:
	var labels := {
		"empty_hand": "Empty Hand",
		"normal_hand": "Normal Hand",
		"selected_enabled_card": "Selected Enabled",
		"selected_disabled_card": "Selected Disabled",
		"hovered_card": "Hovered Card",
		"drag_preview": "Invalid Drop",
		"right_inspector_card_detail": "Inspector Detail",
		"public_track_selection": "Public Track",
		"temporary_decision_pending_hint": "Decision Pending",
	}
	return str(labels.get(id, id))


func fixture(id: String) -> Dictionary:
	match id:
		"empty_hand":
			return _fixture_empty_hand()
		"normal_hand":
			return _fixture_normal_hand()
		"selected_enabled_card":
			return _fixture_selected_enabled_card()
		"selected_disabled_card":
			return _fixture_selected_disabled_card()
		"hovered_card":
			return _fixture_hovered_card()
		"drag_preview":
			return _fixture_drag_preview()
		"right_inspector_card_detail":
			return _fixture_right_inspector_card_detail()
		"public_track_selection":
			return _fixture_public_track_selection()
		"temporary_decision_pending_hint":
			return _fixture_temporary_decision_pending_hint()
	return _fixture_normal_hand()


func all_fixtures() -> Array:
	var result: Array = []
	for id in PREVIEW_IDS:
		result.append(fixture(id))
	return result


func _fixture_empty_hand() -> Dictionary:
	return _base_fixture("empty_hand", {
		"title": "空手牌状态",
		"status": "HandRack keeps its empty affordance and action dock stays readable.",
		"hand_cards": [],
		"selected_card_id": "",
		"selected_card": {},
		"disabled_reason": "",
		"hand_focus": "none",
		"player_overrides": {
			"hint": "暂无手牌；玩家仍能看资源、牌架和公共轨道。",
			"primary_action": "查看牌架",
			"actions": [
				{"id": "rack:open", "label": "查看牌架", "disabled": false, "tooltip": "打开当前选区牌架。"},
				{"id": "play:none", "label": "出牌", "disabled": true, "tooltip": "没有手牌可出。"},
			],
			"quick_actions": [
				{"id": "build", "label": "建城", "state": "就绪", "active": true, "shortcut": "1"},
				{"id": "rack", "label": "牌架", "state": "可看", "active": true, "shortcut": "2"},
				{"id": "buy", "label": "买牌", "state": "--", "disabled": true, "shortcut": "3"},
				{"id": "play", "label": "出牌", "state": "--", "disabled": true, "shortcut": "4"},
			],
		},
		"inspector": _district_context("当前选区", "没有手牌时，右侧仍解释可用的桌面行动。", []),
	})


func _fixture_normal_hand() -> Dictionary:
	var cards := _base_cards()
	return _base_fixture("normal_hand", {
		"title": "普通手牌",
		"status": "A normal hand shows scan-first cards, quick actions, and public track context.",
		"hand_cards": cards,
		"selected_card_id": "",
		"selected_card": cards[0],
		"hand_focus": "none",
		"inspector": _district_context("中央贸易区", "选择一张手牌后，右侧会切换到卡牌详情。", []),
	})


func _fixture_selected_enabled_card() -> Dictionary:
	var cards := _base_cards()
	cards[1]["selected"] = true
	var selected: Dictionary = cards[1].duplicate(true)
	return _base_fixture("selected_enabled_card", {
		"title": "选中可出牌",
		"status": "Selected card exposes an enabled play action and matching inspector detail.",
		"hand_cards": cards,
		"selected_card_id": str(selected.get("id", "")),
		"selected_card": selected,
		"hand_focus": "selected",
		"inspector_mode": "card",
		"inspector": _card_inspector_context(selected),
	})


func _fixture_selected_disabled_card() -> Dictionary:
	var cards := _base_cards()
	var disabled := _disabled_card()
	disabled["selected"] = true
	cards[2] = disabled
	return _base_fixture("selected_disabled_card", {
		"title": "选中但不可出",
		"status": "Disabled reason stays visible before the player tries to act.",
		"hand_cards": cards,
		"selected_card_id": str(disabled.get("id", "")),
		"selected_card": disabled,
		"disabled_reason": str(disabled.get("disabled_reason", "")),
		"hand_focus": "selected",
		"inspector_mode": "card",
		"inspector": _card_inspector_context(disabled),
	})


func _fixture_hovered_card() -> Dictionary:
	var cards := _base_cards()
	var hovered: Dictionary = cards[0].duplicate(true)
	return _base_fixture("hovered_card", {
		"title": "悬停手牌",
		"status": "Hover state lifts the focused hand card while preserving rack layout.",
		"hand_cards": cards,
		"selected_card_id": str(hovered.get("id", "")),
		"selected_card": hovered,
		"hand_focus": "hovered",
		"inspector_mode": "card",
		"inspector": _card_inspector_context(hovered),
	})


func _fixture_drag_preview() -> Dictionary:
	var cards := _base_cards()
	var dragged := _disabled_card()
	dragged["id"] = "card_signal_jammer"
	dragged["name"] = "信号干扰器"
	dragged["selected"] = true
	dragged["drop_enabled"] = false
	dragged["disabled_reason"] = "目标不是可干扰玩家；拖放会显示 invalid_drop。"
	cards[2] = dragged
	return _base_fixture("drag_preview", {
		"title": "拖放无效预览",
		"status": "Invalid drag/drop state is visible without invoking rule settlement.",
		"hand_cards": cards,
		"selected_card_id": str(dragged.get("id", "")),
		"selected_card": dragged,
		"disabled_reason": str(dragged.get("disabled_reason", "")),
		"hand_focus": "drag_invalid",
		"inspector_mode": "card",
		"inspector": _card_inspector_context(dragged),
	})


func _fixture_right_inspector_card_detail() -> Dictionary:
	var cards := _base_cards()
	var selected := _detail_card()
	selected["selected"] = true
	cards[0] = selected
	return _base_fixture("right_inspector_card_detail", {
		"title": "右侧卡牌详情",
		"status": "RightInspector shows use-case, requirements, actions, and deep links for a selected card.",
		"hand_cards": cards,
		"selected_card_id": str(selected.get("id", "")),
		"selected_card": selected,
		"hand_focus": "selected",
		"inspector_mode": "card",
		"inspector": _card_inspector_context(selected),
	})


func _fixture_public_track_selection() -> Dictionary:
	var cards := _base_cards()
	var selected: Dictionary = cards[0].duplicate(true)
	return _base_fixture("public_track_selection", {
		"title": "公共轨道选择",
		"status": "PublicTrack selected state is visible and linked to the right-side context.",
		"hand_cards": cards,
		"selected_card_id": str(selected.get("id", "")),
		"selected_card": selected,
		"hand_focus": "none",
		"public_track": [
			{"slot": "#1", "label": "互动牌", "state": "反制窗", "owner_hint": "待猜", "selected": true, "active": true, "hover_action": "track:interaction_a", "badges": ["公开"], "tooltip": "公开线索：匿名互动牌正在等待一层反制。"},
			{"slot": "#2", "label": "怪兽赌局", "state": "下注中", "owner_hint": "公开", "active": true, "hover_action": "track:wager_b", "badges": ["倒计时"], "tooltip": "公开线索：怪兽赌局正在收集押注。"},
		],
		"inspector": _public_track_context(),
	})


func _fixture_temporary_decision_pending_hint() -> Dictionary:
	var cards := _base_cards()
	cards[1]["selected"] = true
	var selected: Dictionary = cards[1].duplicate(true)
	return _base_fixture("temporary_decision_pending_hint", {
		"title": "等待临时决策",
		"status": "Player surface clearly hints that a temporary decision overlay is pending.",
		"hand_cards": cards,
		"selected_card_id": str(selected.get("id", "")),
		"selected_card": selected,
		"hand_focus": "selected",
		"temporary_decision_pending": true,
		"player_overrides": {
			"hint": "已打出卡牌；等待目标选择 Overlay。",
			"primary_action": "选择目标",
			"readiness_chips": [
				{"text": "Overlay 待选", "active": true, "tooltip": "需要在临时决策面板里选择目标。"},
				{"text": "公开后结算", "active": false, "tooltip": "目标选择后才会公开影响。"},
			],
			"actions": [
				{"id": "temporary_decision:resume", "label": "继续选择", "disabled": false, "tooltip": "回到临时决策 Overlay。"},
			],
		},
		"inspector": {
			"title": "等待目标选择",
			"why": "卡牌已提交，当前需要在 Overlay 中选择目标。",
			"district": {
				"title": "临时决策",
				"summary": "选择目标后才会进入公开线索。",
				"full_detail": "这不是规则结算，只是玩家回合表面的 pending 状态预览。",
				"chips": [{"text": "私密选择"}, {"text": "公开线索"}],
			},
			"requirements": [{"text": "选择目标"}, {"text": "保持匿名"}],
			"actions": [{"id": "temporary_decision:resume", "label": "继续选择", "disabled": false}],
			"deep_links": [{"id": "overlay_preview", "label": "Overlay"}],
			"logs": ["等待当前玩家选择目标。"],
		},
	})


func _base_fixture(id: String, data: Dictionary) -> Dictionary:
	var cards: Array = data.get("hand_cards", []) if data.get("hand_cards", []) is Array else _base_cards()
	var selected_card: Dictionary = data.get("selected_card", {}) if data.get("selected_card", {}) is Dictionary else {}
	var player_overrides: Dictionary = data.get("player_overrides", {}) if data.get("player_overrides", {}) is Dictionary else {}
	var player_state := _base_player_state(cards)
	player_state.merge(player_overrides, true)
	if player_overrides.has("actions"):
		player_state["actions"] = player_overrides["actions"]
	if player_overrides.has("quick_actions"):
		player_state["quick_actions"] = player_overrides["quick_actions"]
	if player_overrides.has("readiness_chips"):
		player_state["readiness_chips"] = player_overrides["readiness_chips"]
	var public_track: Array = data.get("public_track", []) if data.get("public_track", []) is Array else _base_public_track()
	return {
		"id": id,
		"label": preview_label(id),
		"title": str(data.get("title", preview_label(id))),
		"status": str(data.get("status", "")),
		"player_state": player_state,
		"hand_cards": cards,
		"selected_card_id": str(data.get("selected_card_id", selected_card.get("id", ""))),
		"selected_card": selected_card,
		"disabled_reason": str(data.get("disabled_reason", selected_card.get("disabled_reason", ""))),
		"hand_focus": str(data.get("hand_focus", "none")),
		"public_track": public_track,
		"inspector_mode": str(data.get("inspector_mode", "context")),
		"inspector": data.get("inspector", _district_context("当前选区", "选择对象后显示上下文。", [])),
		"temporary_decision_pending": bool(data.get("temporary_decision_pending", false)),
	}


func _base_player_state(cards: Array) -> Dictionary:
	return {
		"title": "玩家板｜当前回合",
		"hint": "选择手牌，右侧会解释能做什么。",
		"identity": "你｜走私商",
		"cash_text": "$18",
		"gdp_text": "+4/min",
		"goal_text": "声望 6/10",
		"goal_ratio": 0.6,
		"selected_district_summary": "中央贸易区",
		"primary_action": "出牌",
		"hand_limit": 5,
		"hand_cards": cards,
		"actions": [
			{"id": "play:selected", "label": "打出选中牌", "disabled": false, "tooltip": "执行当前选中卡牌的主行动。"},
			{"id": "inspect:selected", "label": "查看详情", "disabled": false, "tooltip": "在右侧显示完整卡牌详情。"},
		],
		"quick_actions": [
			{"id": "build", "label": "建城", "state": "就绪", "active": true, "shortcut": "1"},
			{"id": "rack", "label": "牌架", "state": "可看", "active": true, "shortcut": "2"},
			{"id": "buy", "label": "买牌", "state": "就绪", "active": true, "shortcut": "3"},
			{"id": "play", "label": "出牌", "state": "就绪", "active": true, "shortcut": "4"},
		],
		"table_state_lamps": [
			{"text": "回合", "state": "行动", "active": true},
			{"text": "怪兽", "state": "低压", "active": false},
		],
		"readiness_chips": [
			{"text": "有可用牌", "active": true},
			{"text": "目标可选", "active": true},
		],
		"progress_path": [
			{"text": "选牌", "active": true},
			{"text": "看详情", "active": true},
			{"text": "执行", "active": false},
		],
		"bid_board": {
			"title": "公共线索",
			"phase": "下注窗口",
			"chips": [{"text": "匿名"}, {"text": "2 条线索"}],
			"track_links": [{"id": "track:wager_b", "label": "怪兽赌局", "active": true}],
			"actions": [{"id": "track:inspect", "label": "查看轨道", "disabled": false}],
			"status": "公共轨道有 2 条线索。",
		},
	}


func _base_cards() -> Array:
	return [
		{
			"id": "card_orbital_finance",
			"name": "轨道融资",
			"cost": "3",
			"type": "金融",
			"rank": "I",
			"target": "一座城市",
			"use_case": "把现金变成持续收益",
			"effect": "选择一座城市，获得现金流提升，并在公共轨道留下融资线索。",
			"requirement": "需要已选择城市区域。",
			"presentation": "mini_hand",
			"accent": "#38bdf8",
			"drop_enabled": true,
			"actions": [
				{"id": "play:orbital_finance", "label": "打出", "disabled": false, "tooltip": "支付 3 现金并选择城市。"},
				{"id": "inspect:orbital_finance", "label": "详情", "disabled": false},
			],
		},
		{
			"id": "card_shadow_disruption",
			"name": "影仓牵引",
			"cost": "2",
			"type": "互动",
			"rank": "II",
			"target": "一名玩家",
			"use_case": "制造可反制的公开压力",
			"effect": "选择目标后进入公共结算轨；目标无需同意，其他玩家可在反制窗提交一层反制。",
			"requirement": "至少一名可选目标玩家。",
			"presentation": "mini_hand",
			"accent": "#a78bfa",
			"drop_enabled": true,
			"actions": [
				{"id": "play:shadow_disruption", "label": "选择目标", "disabled": false, "tooltip": "目标选择后进入公共结算轨；不请求目标同意。"},
				{"id": "inspect:shadow_disruption", "label": "详情", "disabled": false},
			],
		},
		{
			"id": "card_monster_tip",
			"name": "怪兽内幕",
			"cost": "1",
			"type": "情报",
			"rank": "I",
			"target": "怪兽赌局",
			"use_case": "读取怪兽压力",
			"effect": "查看怪兽倾向，并允许你在公开下注前调整判断。",
			"requirement": "需要怪兽赌局窗口开启。",
			"presentation": "mini_hand",
			"accent": "#f59e0b",
			"drop_enabled": true,
			"actions": [
				{"id": "play:monster_tip", "label": "读取", "disabled": false, "tooltip": "打开怪兽赌局信息。"},
				{"id": "inspect:monster_tip", "label": "详情", "disabled": false},
			],
		},
	]


func _disabled_card() -> Dictionary:
	var card: Dictionary = _base_cards()[2].duplicate(true)
	card["id"] = "card_monster_tip_blocked"
	card["name"] = "怪兽内幕"
	card["drop_enabled"] = false
	card["disabled_reason"] = "怪兽赌局尚未开启。"
	card["action_state"] = "blocked"
	card["actions"] = [
		{"id": "play:monster_tip", "label": "读取", "disabled": true, "tooltip": "怪兽赌局尚未开启。"},
		{"id": "inspect:monster_tip", "label": "详情", "disabled": false},
	]
	return card


func _detail_card() -> Dictionary:
	var card: Dictionary = _base_cards()[0].duplicate(true)
	card["summary"] = "把现金变成持续收益，并公开一条融资线索。"
	card["deep_links"] = [
		{"id": "codex:finance", "label": "金融牌"},
		{"id": "district:central", "label": "中央区"},
	]
	card["requirements"] = [
		{"text": "费用 3", "tooltip": "需要支付 3 现金。"},
		{"text": "目标 城市", "tooltip": "需要已选择城市区域。"},
	]
	return card


func _base_public_track() -> Array:
	return [
		{"slot": "#1", "label": "互动牌", "state": "反制窗", "owner_hint": "待猜", "active": false, "hover_action": "track:interaction_a", "badges": ["公开"], "tooltip": "一张匿名互动牌正在等待一层反制。"},
		{"slot": "#2", "label": "怪兽赌局", "state": "下注中", "owner_hint": "公开", "active": true, "hover_action": "track:wager_b", "badges": ["公开"], "tooltip": "怪兽赌局正在下注。"},
	]


func _district_context(title: String, why: String, actions: Array) -> Dictionary:
	return {
		"title": "桌边详情",
		"why": why,
		"district": {
			"title": title,
			"summary": "当前选区可用于建城、买牌或出牌。",
			"full_detail": "这是玩家回合预览 fixture，不调用 main.gd 规则函数。",
			"chips": [{"text": "城市"}, {"text": "贸易"}],
		},
		"requirements": [{"text": "选区"}, {"text": "手牌"}],
		"actions": actions,
		"deep_links": [{"id": "codex:district", "label": "选区详情"}],
		"logs": [],
	}


func _card_inspector_context(card: Dictionary) -> Dictionary:
	return {
		"title": "卡牌详情",
		"why": str(card.get("disabled_reason", card.get("use_case", "看用途、目标和下一步。"))),
		"district": {
			"title": str(card.get("name", "卡牌")),
			"summary": str(card.get("summary", card.get("effect", ""))),
			"full_detail": "用途｜%s\n目标｜%s\n条件｜%s\n效果｜%s" % [
				str(card.get("use_case", "看卡面效果")),
				str(card.get("target", "任意")),
				str(card.get("requirement", "无")),
				str(card.get("effect", "")),
			],
			"chips": [{"text": "费用 %s" % str(card.get("cost", "--"))}, {"text": str(card.get("type", "卡牌"))}],
		},
		"requirements": card.get("requirements", [{"text": "费用 %s" % str(card.get("cost", "--"))}, {"text": str(card.get("target", "任意"))}]),
		"actions": card.get("actions", []),
		"deep_links": card.get("deep_links", [{"id": "codex:card", "label": "卡牌详情"}]),
		"logs": [],
	}


func _public_track_context() -> Dictionary:
	return {
		"title": "公共轨道",
		"why": "选中的公共线索会改变玩家对匿名行动的判断。",
		"district": {
			"title": "匿名互动牌",
			"summary": "目标已经锁定；牌轨只公开反制时机，真实出牌者仍隐藏。",
			"full_detail": "公共轨道只展示可公开线索，不泄露私密来源。",
			"chips": [{"text": "公开线索"}, {"text": "匿名"}],
		},
		"requirements": [{"text": "只读"}, {"text": "可追踪"}],
		"actions": [{"id": "track:inspect", "label": "查看线索", "disabled": false}],
		"deep_links": [{"id": "codex:public_track", "label": "轨道说明"}],
		"logs": ["公开轨道：匿名互动牌进入一层反制窗口。"],
	}
