extends RefCounted
class_name SpaceSyndicateCardTrackMcpPreviewFixtures

const PREVIEW_IDS := [
	"empty_track",
	"resolved_history",
	"active_reveal",
	"auction_batch",
	"next_batch",
	"public_event_readonly",
	"selected_guessable",
	"hovered_linked_action",
	"long_text_safe_state",
]


func preview_ids() -> Array[String]:
	var result: Array[String] = []
	for id in PREVIEW_IDS:
		result.append(str(id))
	return result


func preview_label(id: String) -> String:
	var labels := {
		"empty_track": "Empty Track",
		"resolved_history": "Resolved History",
		"active_reveal": "Active Reveal",
		"auction_batch": "Auction Batch",
		"next_batch": "Next Batch",
		"public_event_readonly": "Read-only Event",
		"selected_guessable": "Selected Guessable",
		"hovered_linked_action": "Hovered Link",
		"long_text_safe_state": "Long Text Safe",
	}
	return str(labels.get(id, id))


func fixture(id: String) -> Dictionary:
	match id:
		"empty_track":
			return _fixture_empty_track()
		"resolved_history":
			return _fixture_resolved_history()
		"active_reveal":
			return _fixture_active_reveal()
		"auction_batch":
			return _fixture_auction_batch()
		"next_batch":
			return _fixture_next_batch()
		"public_event_readonly":
			return _fixture_public_event_readonly()
		"selected_guessable":
			return _fixture_selected_guessable()
		"hovered_linked_action":
			return _fixture_hovered_linked_action()
		"long_text_safe_state":
			return _fixture_long_text_safe_state()
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
		"description": "CardTrack renders its built-in empty placeholder through CardTrackSlot.",
		"hover_action": "",
		"entries": [],
	}


func _fixture_resolved_history() -> Dictionary:
	return _base_fixture("resolved_history", "已结算历史", "History cards remain compact and readable.", [
		_entry(9001, "#1", "轨道融资", "已结算", "公开", "¥80", "#38bdf8", ["收益"], "track_select_9001", "track_open_orbital_finance_i"),
		_entry(9002, "#2", "雾港合约", "回应完毕", "匿名", "¥60", "#22c55e", ["合约"], "track_select_9002", "track_open_fog_contract"),
	])


func _fixture_active_reveal() -> Dictionary:
	var entries := [
		_entry(9010, "#A", "公开牌", "待猜", "待猜", "¥90", "#facc15", ["当前"], "track_select_9010", "track_open_active_reveal"),
		_entry(9011, "#B", "备用线索", "候补", "未知", "¥40", "#94a3b8", ["线索"], "track_select_9011", "track_open_backup_hint"),
	]
	entries[0]["active"] = true
	return _base_fixture("active_reveal", "当前揭示", "Active reveal slot shows a stronger surface state.", entries)


func _fixture_auction_batch() -> Dictionary:
	var entries := [
		_entry(9020, "#1", "拍卖一号", "竞价", "玩家?", "¥110", "#fb7185", ["领跑"], "track_select_9020", "track_open_auction_a"),
		_entry(9021, "#2", "拍卖二号", "竞价", "匿名", "¥70", "#f97316", ["加价"], "track_select_9021", "track_open_auction_b"),
		_entry(9022, "#3", "拍卖三号", "竞价", "未知", "¥55", "#a855f7", ["观察"], "track_select_9022", "track_open_auction_c"),
	]
	entries[0]["selected"] = true
	return _base_fixture("auction_batch", "竞价批次", "Multiple compact slots stay within a thin rail.", entries)


func _fixture_next_batch() -> Dictionary:
	return _base_fixture("next_batch", "下一批预告", "Upcoming public cards show safe public hints only.", [
		_entry(9030, "N1", "冷链航线", "下一批", "未公开", "?", "#06b6d4", ["预告"], "track_select_9030", "track_open_next_route"),
		_entry(9031, "N2", "工业承包", "下一批", "未公开", "?", "#84cc16", ["预告"], "track_select_9031", "track_open_next_contract"),
	])


func _fixture_public_event_readonly() -> Dictionary:
	var event := _entry(9040, "EV", "风暴公告", "事件", "公开", "", "#f59e0b", ["只读"], "", "")
	event["kind"] = "event"
	event["tooltip"] = "公开事件，只能查看，不产生竞猜 action。"
	return _base_fixture("public_event_readonly", "只读公开事件", "Read-only event slots do not pretend to be guess actions.", [event])


func _fixture_selected_guessable() -> Dictionary:
	var guessable := _entry(9050, "#G", "匿名合约", "待回应", "待猜", "¥120", "#22c55e", ["可猜"], "track_select_9050", "track_open_guessable_contract")
	guessable["selected"] = true
	return _base_fixture("selected_guessable", "选中可竞猜", "Selected marker remains discoverable for MCP and visual QA.", [guessable])


func _fixture_hovered_linked_action() -> Dictionary:
	return {
		"id": "hovered_linked_action",
		"label": "外部联动悬停",
		"description": "set_hovered_track_action highlights the matching public slot.",
		"hover_action": "track_select_9061",
		"entries": [
			_entry(9060, "#1", "星港订单", "公开", "公开", "¥50", "#38bdf8", ["普通"], "track_select_9060", "track_open_starport_order"),
			_entry(9061, "#2", "领跑合约", "领跑", "匿名", "¥130", "#facc15", ["领跑"], "track_select_9061", "track_open_leader_contract"),
		],
	}


func _fixture_long_text_safe_state() -> Dictionary:
	return _base_fixture("long_text_safe_state", "长文本安全态", "Slot labels trim long public clues without stretching the top rail.", [
		_entry(9070, "#LONG", "一张名字非常非常长的轨道金融合同需要被安全截断", "等待公开回应与进一步竞价", "隐藏持有者线索", "¥999", "#c084fc", ["长文本", "安全截断"], "track_select_9070", "track_open_long_text"),
	])


func _base_fixture(id: String, label: String, description: String, entries: Array) -> Dictionary:
	return {
		"id": id,
		"label": label,
		"description": description,
		"hover_action": "",
		"entries": entries,
	}


func _entry(resolution_id: int, slot: String, label: String, state: String, owner_hint: String, cost: String, accent: String, badges: Array, select_action: String, open_action: String) -> Dictionary:
	return {
		"resolution_id": resolution_id,
		"slot": slot,
		"label": label,
		"state": state,
		"owner_hint": owner_hint,
		"cost": cost,
		"accent": accent,
		"badges": badges,
		"select_action": select_action,
		"open_action": open_action,
		"active": false,
		"selected": false,
		"tooltip": "%s | %s | %s" % [label, state, owner_hint],
	}
