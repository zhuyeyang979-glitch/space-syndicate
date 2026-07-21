extends RefCounted
class_name SpaceSyndicateCardResolutionTrackMcpPreviewFixtures

const PREVIEW_IDS := [
	"empty_track",
	"queued_anonymous_cards",
	"active_reveal",
	"auction_window",
	"counter_response_window",
	"temporary_decision_pending",
	"resolved_history",
	"long_queue_overflow",
	"privacy_owner_hidden",
]


func preview_ids() -> Array[String]:
	var result: Array[String] = []
	for id in PREVIEW_IDS:
		result.append(str(id))
	return result


func preview_label(id: String) -> String:
	var labels := {
		"empty_track": "Empty Track",
		"queued_anonymous_cards": "Queued Anonymous Cards",
		"active_reveal": "Active Reveal",
		"auction_window": "Auction Window",
		"counter_response_window": "Counter Response",
		"temporary_decision_pending": "Temporary Decision Pending",
		"resolved_history": "Resolved History",
		"long_queue_overflow": "Long Queue Overflow",
		"privacy_owner_hidden": "Privacy Owner Hidden",
	}
	return str(labels.get(id, id))


func fixture(id: String) -> Dictionary:
	match id:
		"empty_track":
			return _fixture_empty_track()
		"queued_anonymous_cards":
			return _fixture_queued_anonymous_cards()
		"active_reveal":
			return _fixture_active_reveal()
		"auction_window":
			return _fixture_auction_window()
		"counter_response_window":
			return _fixture_counter_response_window()
		"temporary_decision_pending":
			return _fixture_temporary_decision_pending()
		"resolved_history":
			return _fixture_resolved_history()
		"long_queue_overflow":
			return _fixture_long_queue_overflow()
		"privacy_owner_hidden":
			return _fixture_privacy_owner_hidden()
	return _fixture_empty_track()


func all_fixtures() -> Array:
	var result: Array = []
	for id in PREVIEW_IDS:
		result.append(fixture(id))
	return result


func _fixture_empty_track() -> Dictionary:
	return {
		"id": "empty_track",
		"label": "空牌轨",
		"description": "CardResolutionTrack keeps the full editable track shell visible even when there are no public cards.",
		"track_state": {
			"title": "公共结算轨",
			"phase": "等待",
			"summary": "等待玩家匿名出牌；轨道保持可编辑结构。",
			"privacy_hint": "未公开归属前只显示公开线索。",
			"empty_text": "没有正在结算的公开牌。",
			"entries": [],
		},
	}


func _fixture_queued_anonymous_cards() -> Dictionary:
	return _base_fixture("queued_anonymous_cards", "匿名队列", "Multiple anonymous cards queue without exposing owners.", {
		"title": "公共结算轨",
		"phase": "候补",
		"summary": "三张匿名牌等待进入展示窗口。",
		"privacy_hint": "只显示报价、目标和公开条件，不显示隐藏归属。",
		"entries": [
			_entry(9101, "+1", "轨道融资", "待定1", "待猜", "¥80", "#38bdf8", ["现金"], "track_select_9101", "track_open_orbital_finance"),
			_entry(9102, "+2", "雾港合约", "待定2", "待猜", "¥60", "#22c55e", ["合约"], "track_select_9102", "track_open_fog_contract"),
			_entry(9103, "+3", "补给黑客", "待定3", "待猜", "¥40", "#a855f7", ["干扰"], "track_select_9103", "track_open_supply_hack"),
		],
	})


func _fixture_active_reveal() -> Dictionary:
	var active := _entry(9110, "0", "风暴借贷", "当前展示", "待猜", "¥120", "#facc15", ["展示", "可响应"], "track_select_9110", "track_open_storm_credit")
	active["active"] = true
	return _base_fixture("active_reveal", "当前展示", "Active reveal is separated from queue and history.", {
		"title": "公共结算轨",
		"phase": "展示中",
		"summary": "一张匿名牌正在展示效果，其余线索仍公开。",
		"privacy_hint": "出牌者未公开；玩家只能从目标、报价和余波推理。",
		"entries": [
			_entry(9108, "✓", "旧债清算", "已结算", "已公开", "¥30", "#64748b", ["历史"], "track_select_9108", "track_open_old_debt"),
			active,
			_entry(9111, "+1", "冷链航线", "锁定1", "待猜", "¥70", "#06b6d4", ["候补"], "track_select_9111", "track_open_cold_route"),
		],
	})


func _fixture_auction_window() -> Dictionary:
	return _base_fixture("auction_window", "竞价窗口", "Auction response layer calls out a live public bid window.", {
		"title": "公共结算轨",
		"phase": "竞价",
		"summary": "复数匿名牌暂停结算，公开报价决定展示顺序。",
		"auction_open": true,
		"auction_response": {
			"active": true,
			"summary": "公开报价沙漏开启；最高报价领跑，平价按顺时针顺序。",
			"actions": [
				{"id": "track_auction_bid_9120", "label": "加价 ¥20", "disabled": false, "tooltip": "公开提高当前匿名牌报价。"},
				{"id": "track_auction_pass_9120", "label": "观望", "disabled": false, "tooltip": "保留资源，等待下一次响应窗口。"},
			],
		},
		"privacy_hint": "竞价只公开报价和线索，隐藏归属仍不可见。",
		"entries": [
			_entry(9120, "+1", "拍卖一号", "竞拍1", "待猜", "¥110", "#fb7185", ["领跑"], "track_select_9120", "track_open_auction_one"),
			_entry(9121, "+2", "拍卖二号", "竞拍2", "待猜", "¥90", "#f97316", ["加价"], "track_select_9121", "track_open_auction_two"),
			_entry(9122, "+3", "拍卖三号", "竞拍3", "待猜", "¥65", "#a855f7", ["观察"], "track_select_9122", "track_open_auction_three"),
		],
	})


func _fixture_counter_response_window() -> Dictionary:
	var active := _entry(9130, "0", "相位封锁", "当前展示", "待猜", "¥100", "#e879f9", ["响应"], "track_select_9130", "track_open_phase_lock")
	active["active"] = true
	return _base_fixture("counter_response_window", "响应窗口", "Counter response state stays on the same sceneized track surface.", {
		"title": "公共结算轨",
		"phase": "响应",
		"summary": "直接互动牌进入可响应窗口。",
		"auction_response": {
			"active": true,
			"summary": "相位响应窗口开启；可用相位否决类效果回应。",
			"actions": [
				{"id": "track_counter_phase_lock", "label": "相位否决", "disabled": false, "tooltip": "公开响应当前展示牌。"},
				{"id": "track_counter_no_energy", "label": "强制反制", "disabled": true, "reason": "能量不足，不能强制反制。", "tooltip": "disabled action remains visible for QA."},
			],
		},
		"privacy_hint": "响应窗口不公开隐藏玩家身份。",
		"entries": [active],
	})


func _fixture_temporary_decision_pending() -> Dictionary:
	return _base_fixture("temporary_decision_pending", "Overlay 等待", "The track shows that resolution is blocked by an overlay decision without bypassing OverlayLayer.", {
		"title": "公共结算轨",
		"phase": "等待决策",
		"summary": "临时决策 Overlay 正在等待玩家选择。",
		"auction_response": {"active": true, "summary": "等待临时决策完成后继续结算。"},
		"privacy_hint": "私密弃牌和目标选择不写入公共牌轨。",
		"entries": [
			_entry(9140, "0", "怪兽赌局", "当前展示", "待猜", "¥50", "#f43f5e", ["Overlay"], "track_select_9140", "track_open_monster_wager"),
			_entry(9141, "N1", "选择目标", "下批等待1", "待猜", "¥70", "#22c55e", ["下批"], "track_select_9141", "track_open_target_choice"),
		],
	})


func _fixture_resolved_history() -> Dictionary:
	return _base_fixture("resolved_history", "结算历史", "Resolved history stays compact and scannable.", {
		"title": "公共结算轨",
		"phase": "历史",
		"summary": "已结算牌保留公开线索，便于回看证据链。",
		"privacy_hint": "历史只展示公开后的信息和公开线索。",
		"entries": [
			_entry(9150, "✓1", "城市补贴", "已结算", "赤港", "¥20", "#64748b", ["收益"], "track_select_9150", "track_open_city_grant"),
			_entry(9151, "✓2", "风暴公告", "公共事件", "只读", "", "#a78bfa", ["只读"], "", ""),
			_entry(9152, "✓3", "走私审计", "已结算", "蓝岭", "¥40", "#64748b", ["余波"], "track_select_9152", "track_open_smuggle_audit"),
		],
	})


func _fixture_long_queue_overflow() -> Dictionary:
	var entries: Array = []
	for i in range(14):
		entries.append(_entry(
			9160 + i,
			"+%d" % (i + 1),
			"长队列测试%d号匿名公共牌" % (i + 1),
			"竞拍%d" % (i + 1),
			"待猜",
			"¥%d" % (45 + i * 5),
			"#38bdf8" if i % 3 == 0 else ("#f97316" if i % 3 == 1 else "#22c55e"),
			["溢出", "可滚动"],
			"track_select_%d" % (9160 + i),
			"track_open_long_queue_%d" % (i + 1)
		))
	return _base_fixture("long_queue_overflow", "长队列", "Long queues remain horizontally scrollable without collapsing the panel.", {
		"title": "公共结算轨",
		"phase": "长队列",
		"summary": "大量匿名牌进入同一批次，用于验证横向滚动和截断。",
		"auction_open": true,
		"auction_response": {"active": true, "summary": "长队列压力测试；所有 slot 都必须可扫描。"},
		"privacy_hint": "长文本会截断，但隐藏归属不会泄露。",
		"entries": entries,
	})


func _fixture_privacy_owner_hidden() -> Dictionary:
	var entry := _entry(9180, "+P", "隐私边界测试", "待定1", "hidden_owner", "¥75", "#14b8a6", ["隐私"], "track_select_9180", "track_open_privacy_case")
	entry["hidden_owner"] = "Player 2 Secret"
	entry["private_target"] = "Hidden District 4"
	entry["private_discard"] = "Secret discarded card"
	entry["tooltip"] = "This tooltip contains hidden_owner and private_target and must be sanitized by the UI."
	return _base_fixture("privacy_owner_hidden", "隐私隐藏", "Private owner fields are present in fixture data but must not render in the track text.", {
		"title": "公共结算轨",
		"phase": "隐私 QA",
		"summary": "hidden_owner / private_target 字段进入 UI 前必须被清理。",
		"privacy_hint": "private_owner and private_discard are replaced by safe public wording.",
		"entries": [entry],
	})


func _base_fixture(id: String, label: String, description: String, track_state: Dictionary) -> Dictionary:
	return {
		"id": id,
		"label": label,
		"description": description,
		"track_state": track_state,
	}


func _entry(resolution_id: int, slot: String, label: String, state: String, owner_hint: String, cost: String, accent: String, badges: Array, select_action: String, open_action: String) -> Dictionary:
	return {
		"id": "track_%d" % resolution_id,
		"resolution_id": resolution_id,
		"slot": slot,
		"label": label,
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
		"tooltip": "%s | %s | %s | %s" % [label, state, owner_hint, cost],
		"actions": [{"id": select_action, "label": "选中竞猜", "disabled": select_action == ""}],
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
