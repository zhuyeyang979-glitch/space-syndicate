extends RefCounted
class_name SpaceSyndicateRuntimeCardResolutionTrackFlowFixtures

const CASE_IDS := [
	"runtime_public_track_loads",
	"select_runtime_queued_card",
	"open_runtime_active_card",
	"runtime_auction_response_action",
	"runtime_disabled_response_action",
	"runtime_counter_response_window",
	"runtime_resolved_history_readonly",
	"runtime_long_queue_layout",
	"runtime_empty_track_safe_state",
	"runtime_privacy_boundary",
	"runtime_group_organize_window",
	"runtime_group_lock_window",
	"runtime_group_contiguous_order",
	"runtime_group_wager_pool_privacy",
]


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
		"runtime_public_track_loads":
			return _case("runtime_public_track_loads", "runtime_queue", "load_track", "", "", "匿名融资", _runtime_queue_track_state())
		"select_runtime_queued_card":
			return _case("select_runtime_queued_card", "runtime_queue", "select_slot", "runtime_track_1001", "runtime_track_select_1001", "匿名融资", _runtime_queue_track_state())
		"open_runtime_active_card":
			return _case("open_runtime_active_card", "runtime_active", "open_slot", "runtime_track_1010", "runtime_track_open_storm_credit", "风暴借贷", _runtime_active_track_state())
		"runtime_auction_response_action":
			return _case("runtime_auction_response_action", "runtime_auction", "response_action", "", "runtime_track_bid_1020", "公开报价沙漏", _runtime_auction_track_state())
		"runtime_disabled_response_action":
			return _case("runtime_disabled_response_action", "runtime_counter", "disabled_response_action", "", "runtime_track_force_counter", "能量不足", _runtime_counter_track_state())
		"runtime_counter_response_window":
			return _case("runtime_counter_response_window", "runtime_counter", "response_action", "", "runtime_track_counter_phase_lock", "相位响应窗口", _runtime_counter_track_state())
		"runtime_resolved_history_readonly":
			return _case("runtime_resolved_history_readonly", "runtime_history", "readonly_history", "runtime_track_1037", "", "风暴公告", _runtime_history_track_state())
		"runtime_long_queue_layout":
			return _case("runtime_long_queue_layout", "runtime_long_queue", "select_slot", "runtime_track_1041", "runtime_track_select_1041", "长队列测试", _runtime_long_queue_track_state())
		"runtime_empty_track_safe_state":
			return _case("runtime_empty_track_safe_state", "runtime_empty", "empty_safe", "empty_track", "", "等待出牌", _runtime_empty_track_state())
		"runtime_privacy_boundary":
			return _case("runtime_privacy_boundary", "runtime_privacy", "select_slot", "runtime_track_1050", "runtime_track_select_1050", "隐私边界", _runtime_privacy_track_state())
		"runtime_group_organize_window":
			return _case("runtime_group_organize_window", "group_organize", "load_track", "", "", "6秒组织", _runtime_group_organize_track_state())
		"runtime_group_lock_window":
			return _case("runtime_group_lock_window", "group_lock", "disabled_response_action", "", "runtime_group_bid_locked", "最后2秒锁牌", _runtime_group_lock_track_state())
		"runtime_group_contiguous_order":
			return _case("runtime_group_contiguous_order", "group_order", "select_slot", "runtime_track_1061", "runtime_track_select_1061", "同源组 2/2", _runtime_group_order_track_state())
		"runtime_group_wager_pool_privacy":
			return _case("runtime_group_wager_pool_privacy", "group_wager_pool", "select_slot", "runtime_track_1070", "runtime_track_select_1070", "棱镜融资", _runtime_group_wager_pool_track_state())
	return _case("runtime_public_track_loads", "runtime_queue", "load_track", "", "", "匿名融资", _runtime_queue_track_state())


func table_state_for_case(flow_case: Dictionary) -> Dictionary:
	var track_state: Dictionary = flow_case.get("track_state", {}) if flow_case.get("track_state", {}) is Dictionary else {}
	var entries: Array = track_state.get("entries", []) if track_state.get("entries", []) is Array else []
	return {
		"top_bar": {
			"phase": "牌轨运行 QA",
			"turn": "Sprint 3",
			"identity": "你",
			"cash_text": "¥180",
			"gdp_text": "GDP 7",
			"goal_text": "目标: 读懂公共结算轨",
			"selected_district": "赤港",
			"primary_action": "检查牌轨",
		},
		"card_track": entries,
		"card_resolution_track": track_state,
		"planet": {
			"title": "真实主界面牌轨 QA",
			"hint": "GameScreen / PublicTrack / RightInspector / PlayerBoard",
			"table_lanes": [
				{"title": "公共轨", "detail": "只显示公开线索和响应窗口。"},
				{"title": "隐私边界", "detail": "隐藏归属不进入可见文本。"},
			],
		},
		"right_inspector": {
			"title": "牌轨详情",
			"why": "选择公共牌轨槽位查看公开线索；响应按钮走 GameScreen action_requested。",
			"district": {
				"title": "公共结算轨",
				"summary": "等待选择一个公开槽位。",
				"detail": "公共区只显示报价、状态、公开标签和匿名来源。",
				"full_detail": "公共区只显示报价、状态、公开标签和匿名来源。",
				"chips": [{"text": "公开"}, {"text": "匿名"}],
			},
			"actions": [],
			"logs": ["牌轨 QA fixture 已加载。"],
		},
		"player_board": {
			"title": "玩家板｜牌轨运行 QA",
			"identity": "你",
			"cash_text": "¥180",
			"gdp_text": "GDP 7",
			"goal_text": "验证公共结算轨",
			"selected_district_summary": "赤港",
			"primary_action": "查看牌轨",
			"hand_cards": [],
			"quick_actions": [],
			"actions": [],
		},
	}


func _case(case_id: String, fixture_id: String, interaction: String, clicked_slot_id: String, expected_action_id: String, inspector_text: String, track_state: Dictionary) -> Dictionary:
	return {
		"case_id": case_id,
		"fixture_id": fixture_id,
		"interaction": interaction,
		"clicked_slot_id": clicked_slot_id,
		"expected_action_id": expected_action_id,
		"expected_inspector_text": inspector_text,
		"track_state": track_state,
		"notes": "Runtime GameScreen integration gate for CardResolutionTrack.",
	}


func _runtime_queue_track_state() -> Dictionary:
	return _track_state("候补", "三张匿名牌进入真实 GameScreen 顶部公共结算轨。", [
		_entry(1001, "+1", "匿名融资", "待定1", "待猜", "¥80", "#38bdf8", ["现金"], "runtime_track_select_1001", "runtime_track_open_orbital_finance"),
		_entry(1002, "+2", "雾港合约", "待定2", "待猜", "¥60", "#22c55e", ["合约"], "runtime_track_select_1002", "runtime_track_open_fog_contract"),
		_entry(1003, "+3", "补给黑客", "待定3", "待猜", "¥40", "#a855f7", ["干扰"], "runtime_track_select_1003", "runtime_track_open_supply_hack"),
	])


func _runtime_active_track_state() -> Dictionary:
	var active := _entry(1010, "0", "风暴借贷", "当前展示", "待猜", "¥120", "#facc15", ["展示"], "runtime_track_select_1010", "runtime_track_open_storm_credit")
	active["active"] = true
	return _track_state("展示中", "当前展示牌保留在真实 GameScreen 的公共牌轨。", [
		_entry(1009, "✓", "旧债清算", "已结算", "公开", "¥30", "#64748b", ["历史"], "runtime_track_select_1009", "runtime_track_open_old_debt"),
		active,
		_entry(1011, "+1", "冷链航线", "锁定1", "待猜", "¥70", "#06b6d4", ["候补"], "runtime_track_select_1011", "runtime_track_open_cold_route"),
	])


func _runtime_auction_track_state() -> Dictionary:
	var state := _track_state("竞价", "公开报价沙漏开启；最高报价领跑。", [
		_entry(1020, "+1", "拍卖一号", "竞拍1", "待猜", "¥110", "#fb7185", ["领跑"], "runtime_track_select_1020", "runtime_track_open_auction_one"),
		_entry(1021, "+2", "拍卖二号", "竞拍2", "待猜", "¥90", "#f97316", ["加价"], "runtime_track_select_1021", "runtime_track_open_auction_two"),
	])
	state["auction_open"] = true
	state["auction_response"] = {
		"active": true,
		"summary": "公开报价沙漏开启；响应按钮必须通过 GameScreen action_requested。",
		"actions": [
			{"id": "runtime_track_bid_1020", "label": "加价 ¥20", "disabled": false, "tooltip": "公开提高当前匿名牌报价。"},
			{"id": "runtime_track_pass_1020", "label": "观望", "disabled": false, "tooltip": "保留资源。"},
		],
	}
	return state


func _runtime_counter_track_state() -> Dictionary:
	var active := _entry(1030, "0", "相位封锁", "当前展示", "待猜", "¥100", "#e879f9", ["响应"], "runtime_track_select_1030", "runtime_track_open_phase_lock")
	active["active"] = true
	var state := _track_state("响应", "相位响应窗口开启；只显示公开响应信息。", [active])
	state["auction_response"] = {
		"active": true,
		"summary": "相位响应窗口开启；可用相位否决类效果回应。",
		"actions": [
			{"id": "runtime_track_counter_phase_lock", "label": "相位否决", "disabled": false, "tooltip": "公开响应当前展示牌。"},
			{"id": "runtime_track_force_counter", "label": "强制反制", "disabled": true, "reason": "能量不足，不能强制反制。", "tooltip": "禁用按钮必须显示但不可触发。"},
		],
	}
	return state


func _runtime_history_track_state() -> Dictionary:
	var event := _entry(1037, "✓2", "风暴公告", "公共事件", "只读", "", "#a78bfa", ["只读"], "", "")
	event["kind"] = "event"
	return _track_state("历史", "已结算历史只用于查看，不触发现行响应。", [
		_entry(1036, "✓1", "城市补贴", "已结算", "赤港", "¥20", "#64748b", ["收益"], "runtime_track_select_1036", "runtime_track_open_city_grant"),
		event,
	])


func _runtime_long_queue_track_state() -> Dictionary:
	var entries: Array = []
	for i in range(12):
		entries.append(_entry(
			1040 + i,
			"+%d" % (i + 1),
			"长队列测试%d号匿名公共牌" % (i + 1),
			"竞拍%d" % (i + 1),
			"待猜",
			"¥%d" % (45 + i * 5),
			"#38bdf8" if i % 3 == 0 else ("#f97316" if i % 3 == 1 else "#22c55e"),
			["溢出"],
			"runtime_track_select_%d" % (1040 + i),
			"runtime_track_open_long_queue_%d" % (i + 1)
		))
	return _track_state("长队列", "大量匿名牌进入真实公共轨，验证布局和 slot id。", entries)


func _runtime_empty_track_state() -> Dictionary:
	return _track_state("等待", "没有正在结算的公开牌。", [])


func _runtime_privacy_track_state() -> Dictionary:
	var entry := _entry(1050, "+P", "隐私边界", "待定1", "hidden_owner", "¥75", "#14b8a6", ["隐私"], "runtime_track_select_1050", "runtime_track_open_privacy_case")
	entry["hidden_owner"] = "Player 2 Secret"
	entry["private_target"] = "Hidden District 4"
	entry["private_discard"] = "Secret discarded card"
	entry["tooltip"] = "This tooltip contains hidden_owner and private_target and must be sanitized by the UI."
	var state := _track_state("隐私 QA", "hidden_owner / private_target 字段进入真实 GameScreen 前必须被清理。", [entry])
	state["privacy_hint"] = "private_owner and private_discard are replaced by safe public wording."
	return state


func _runtime_group_organize_track_state() -> Dictionary:
	var entries := [
		_group_entry(1060, "组织组1·1/2", "轨道融资 I", "window_12_group_0", 1, 2, 100),
		_group_entry(1061, "组织组1·2/2", "城市融资 I", "window_12_group_0", 2, 2, 100),
		_group_entry(1063, "组织组2·1/1", "相位新闻 I", "window_12_group_1", 1, 1, 50),
	]
	var state := _track_state("组织", "前6秒组织：标准局每人0-2张形成一个匿名组，并从¥0、¥50、¥100选择固定优先报价。", entries)
	state["window_phase"] = "organize"
	state["window_remaining"] = 5.0
	return state


func _runtime_group_lock_track_state() -> Dictionary:
	var state := _track_state("锁牌", "最后2秒锁牌：不能加入新卡或更改固定优先报价。", [
		_group_entry(1065, "锁定组1·1/2", "轨道融资 I", "window_12_group_0", 1, 2, 100),
		_group_entry(1066, "锁定组1·2/2", "城市融资 I", "window_12_group_0", 2, 2, 100),
		_group_entry(1067, "锁定组2·1/1", "相位新闻 I", "window_12_group_1", 1, 1, 50),
	])
	state["auction_open"] = true
	state["window_phase"] = "lock"
	state["window_remaining"] = 1.0
	state["auction_response"] = {
		"active": true,
		"summary": "最后2秒锁牌；组顺序和优先报价都已冻结。",
		"actions": [
			{"id": "runtime_group_bid_locked", "label": "优先报价已锁定", "disabled": true, "reason": "锁牌阶段不能更改优先报价。", "tooltip": "等待公共奖池 receipt。"},
			{"id": "runtime_group_add_card", "label": "加入卡牌", "disabled": true, "reason": "锁牌阶段不能加入新卡。", "tooltip": "卡牌保留在手牌等待下一窗口。"},
		],
	}
	return state


func _runtime_group_order_track_state() -> Dictionary:
	return _track_state("组内连续", "同一来源的两张卡保持相邻，并按1/2、2/2连续结算。", [
		_group_entry(1060, "锁定组1·1/2", "轨道融资 I", "window_12_group_0", 1, 2, 100),
		_group_entry(1061, "锁定组1·2/2", "城市融资 I", "window_12_group_0", 2, 2, 100),
		_group_entry(1063, "锁定组2·1/1", "相位新闻 I", "window_12_group_1", 1, 1, 50),
	])


func _runtime_group_wager_pool_track_state() -> Dictionary:
	var first := _group_entry(1070, "已结算组1·1/2", "棱镜融资 I", "window_13_group_0", 1, 2, 100)
	first["badges"] = ["同源组 1/2", "固定报价¥100", "公共怪兽奖池"]
	first["detail"] = "本组固定优先报价进入下一场有效怪兽赌局公共奖池；来源身份保持匿名。"
	first["full_detail"] = first["detail"]
	first["hidden_owner"] = "Player 1 Secret"
	first["private_target"] = "Hidden District 2"
	var second := _group_entry(1071, "已结算组1·2/2", "轨道融资 I", "window_13_group_0", 2, 2, 100)
	second["badges"] = ["同源组 2/2", "连续结算"]
	var third := _group_entry(1072, "已结算组2·1/1", "城市融资 I", "window_13_group_1", 1, 1, 50)
	third["group_position"] = 2
	third["badges"] = ["组2", "公共怪兽奖池 +¥50"]
	var fourth := _group_entry(1073, "已结算组3·1/1", "冷链航线 I", "window_13_group_2", 1, 1, 0)
	fourth["group_position"] = 3
	fourth["badges"] = ["组3", "零报价"]
	return _track_state("公共奖池", "所有组固定报价合计¥150进入怪兽赌局公共奖池；不存在组间资金链，身份不公开。", [first, second, third, fourth])


func _group_entry(resolution_id: int, state: String, label: String, group_id: String, group_order: int, group_size: int, priority_bid_cash: int) -> Dictionary:
	var group_position := 1
	if group_id.contains("_group_"):
		group_position = maxi(1, int(group_id.get_slice("_group_", 1)) + 1)
	var entry := _entry(
		resolution_id,
		"G%d" % group_position,
		label,
		state,
		"待猜",
		"¥%d" % priority_bid_cash,
		"#f59e0b",
		["同源组 %d/%d" % [group_order, group_size]],
		"runtime_track_select_%d" % resolution_id,
		"runtime_track_open_group_%d" % resolution_id
	)
	entry["group_id"] = group_id
	entry["group_position"] = group_position
	entry["group_order"] = group_order
	entry["group_size"] = group_size
	entry["priority_bid"] = priority_bid_cash
	entry["priority_bid_cents"] = priority_bid_cash * 100
	entry["priority_bid_committed"] = true
	entry["summary"] = "%s｜同源组 %d/%d｜固定优先报价¥%d" % [label, group_order, group_size, priority_bid_cash]
	entry["detail"] = "%s｜同源组 %d/%d｜组内卡牌连续结算。" % [label, group_order, group_size]
	entry["full_detail"] = entry["detail"]
	return entry


func _track_state(phase: String, summary: String, entries: Array) -> Dictionary:
	return {
		"title": "公共结算轨",
		"phase": phase,
		"summary": summary,
		"privacy_hint": "未公开归属前只显示公开线索。",
		"empty_text": "牌轨空闲，等待玩家出牌。",
		"entries": entries,
	}


func _entry(resolution_id: int, slot: String, label: String, state: String, owner_hint: String, cost: String, accent: String, badges: Array, select_action: String, open_action: String) -> Dictionary:
	return {
		"id": "runtime_track_%d" % resolution_id,
		"resolution_id": resolution_id,
		"slot": slot,
		"label": label,
		"title": label,
		"state": state,
		"kind": _kind_for_state(state),
		"owner_hint": owner_hint,
		"cost": cost,
		"accent": accent,
		"badges": badges,
		"select_action": select_action,
		"open_action": open_action,
		"active": false,
		"selected": false,
		"summary": "%s｜%s｜报价 %s" % [label, state, cost],
		"detail": "%s 是公开结算轨上的匿名线索，只展示可公开信息。" % label,
		"full_detail": "%s 是公开结算轨上的匿名线索，只展示状态、报价、公开标签和安全来源提示。" % label,
		"tooltip": "%s | %s | %s | %s" % [label, state, owner_hint, cost],
		"actions": [{"id": select_action, "label": "选中线索", "disabled": select_action == ""}],
	}


func _kind_for_state(state: String) -> String:
	if state.contains("已") or state.contains("历史") or state.contains("事件"):
		return "history"
	if state.contains("当前"):
		return "active"
	if state.contains("下批"):
		return "next"
	if state.contains("竞"):
		return "auction"
	return "queue"
