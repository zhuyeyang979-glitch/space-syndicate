@tool
extends Node
class_name GameTableViewModelRuntimeService

const TABLE_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/table_snapshot.gd")

var _configured := false
var _card_presentation_service: Node = null
var _table_compose_count := 0
var _surface_compose_count := 0


func configure(card_presentation_service: Node = null) -> void:
	_card_presentation_service = card_presentation_service
	_configured = _card_presentation_service != null


func compose_table_source(source: Dictionary) -> Dictionary:
	_table_compose_count += 1
	var table_source := _dictionary(source.get("table_source", {}))
	var surfaces := compose_card_surfaces(_dictionary(source.get("card_surfaces", {})))
	table_source["card_track"] = _array(surfaces.get("card_track", []))
	table_source["card_resolution_track"] = _dictionary(surfaces.get("card_resolution_track", {}))
	var player_board := _dictionary(table_source.get("player_board", {}))
	player_board["hand_cards"] = _array(surfaces.get("hand_cards", []))
	table_source["player_board"] = player_board
	table_source["right_inspector"] = _dictionary(surfaces.get("right_inspector", {}))
	return table_source


func compose_table(source: Dictionary) -> Dictionary:
	var table_source := compose_table_source(source)
	var snapshot: Variant = TABLE_SNAPSHOT_SCRIPT.new().apply_dictionary(table_source)
	return snapshot.to_ui_dictionary()


func compose_card_surfaces(source: Dictionary) -> Dictionary:
	_surface_compose_count += 1
	var hand_cards := _compose_hand_cards(_array(source.get("hand_cards", [])))
	var track_snapshot := _compose_track(_dictionary(source.get("track", {})))
	var card_track := _array(track_snapshot.get("entries", []))
	var right_inspector := _compose_right_inspector(source, hand_cards, card_track)
	return {
		"hand_cards": hand_cards,
		"card_track": card_track,
		"card_resolution_track": _dictionary(track_snapshot.get("resolution_track", {})),
		"right_inspector": right_inspector,
	}


func compose_resolution_overlay_badges(source: Dictionary) -> Array:
	var entry := _dictionary(source.get("entry", {}))
	if entry.is_empty():
		return []
	var badge_texts: Array = []
	if bool(entry.get("public_owner_revealed", false)):
		badge_texts.append("公开归属标签｜%s" % str(entry.get("public_owner_label", "归属：已公开")).replace("归属：", ""))
	elif bool(entry.get("is_viewer_card", false)):
		badge_texts.append("我的展示牌")
	else:
		badge_texts.append("归属待猜")
	var requirement_text := str(source.get("requirement_text", ""))
	if requirement_text != "":
		badge_texts.append("出牌条件｜%s" % _short_text(requirement_text.replace("打出条件：", "").replace("条件：", ""), 22))
	if bool(source.get("is_contract", false)):
		match str(source.get("contract_state", "result")):
			"active": badge_texts.append("合约展示｜随后签约")
			"pending": badge_texts.append("合约待签｜看底部沙漏")
			_: badge_texts.append("合约结果｜%s" % str(source.get("contract_response_label", "待公开")))
	var bid := int(entry.get("winning_bid", entry.get("tip", 0)))
	if bid > 0:
		badge_texts.append("成交小费¥%d｜%s" % [bid, "已私密支付" if bool(entry.get("tip_paid", false)) else "锁定"])
	var tip_clue := str(source.get("tip_clue", ""))
	if tip_clue != "":
		badge_texts.append("竞价线索｜%s" % _short_text(tip_clue, 20))
	var current_queue_count := maxi(0, int(source.get("current_queue_count", 0)))
	var next_queue_count := maxi(0, int(source.get("next_queue_count", 0)))
	if current_queue_count > 0:
		badge_texts.append("锁定候补%d" % current_queue_count)
	if next_queue_count > 0:
		badge_texts.append("下批等待%d" % next_queue_count)
	var result: Array = []
	for text_variant in badge_texts:
		var badge_text := str(text_variant)
		var text_color := _resolution_badge_color(badge_text)
		result.append({
			"text": badge_text,
			"text_color": text_color,
			"background_color": Color("#020617").lerp(text_color, 0.24),
		})
	return result


func debug_snapshot() -> Dictionary:
	return {
		"service_ready": _configured,
		"service_authoritative": _configured,
		"table_compose_count": _table_compose_count,
		"surface_compose_count": _surface_compose_count,
		"owns_table_snapshot_normalization": true,
		"owns_hand_card_viewmodels": true,
		"owns_public_track_viewmodels": true,
		"owns_right_inspector_assembly": true,
		"owns_resolution_overlay_badges": true,
		"uses_existing_table_snapshot": true,
		"calculates_play_legality": false,
		"mutates_game_state": false,
		"reads_runtime_nodes": false,
		"legacy_main_snapshot_assembly_active": false,
	}


func _compose_hand_cards(sources: Array) -> Array:
	var result := []
	if _card_presentation_service == null or not _card_presentation_service.has_method("compose_hand_card"):
		return result
	for source_variant in sources:
		if not (source_variant is Dictionary): continue
		var snapshot: Variant = _card_presentation_service.call("compose_hand_card", source_variant)
		if snapshot is Dictionary: result.append((snapshot as Dictionary).duplicate(true))
	return result


func _compose_track(source: Dictionary) -> Dictionary:
	var entries := []
	var selected_resolution_id := int(source.get("selected_resolution_id", -1))
	var included := {}
	var history := _array(source.get("history", []))
	var history_start := maxi(0, history.size() - maxi(1, int(source.get("history_window", 10))))
	for index in range(history_start, history.size()):
		var snapshot := _compose_track_entry(_dictionary(history[index]), "已结算", source)
		entries.append(snapshot)
		included[int(snapshot.get("resolution_id", -1))] = true
	if selected_resolution_id >= 0 and not bool(included.get(selected_resolution_id, false)):
		for history_variant in history:
			var history_source := _dictionary(history_variant)
			var entry := _dictionary(history_source.get("entry", {}))
			if _resolution_id(entry) == selected_resolution_id:
				entries.insert(0, _compose_track_entry(history_source, "已结算", source))
				break
	var active := _dictionary(source.get("active", {}))
	if not active.is_empty(): entries.append(_compose_track_entry(active, "当前展示", source))
	var queue := _array(source.get("queue", []))
	for index in range(queue.size()):
		var queue_source := _dictionary(queue[index])
		var queue_entry := _dictionary(queue_source.get("entry", {}))
		var group_position := maxi(1, int(queue_entry.get("group_position", index + 1)))
		var group_order := maxi(1, int(queue_entry.get("group_order", 1)))
		var group_size := maxi(1, int(queue_entry.get("group_size", 1)))
		var state_text := "组织组%d·%d/%d" % [group_position, group_order, group_size]
		if bool(source.get("auction_open", false)): state_text = "竞拍组%d·%d/%d" % [group_position, group_order, group_size]
		elif bool(source.get("batch_locked", false)) or not active.is_empty(): state_text = "锁定组%d·%d/%d" % [group_position, group_order, group_size]
		entries.append(_compose_track_entry(queue_source, state_text, source))
	var next_queue := _array(source.get("next_queue", []))
	for index in range(next_queue.size()): entries.append(_compose_track_entry(_dictionary(next_queue[index]), "下批等待%d" % (index + 1), source))
	for event_variant in _array(source.get("events", [])):
		var event_snapshot := _compose_event(_dictionary(event_variant), entries.size())
		if not event_snapshot.is_empty(): entries.append(event_snapshot)
	var demo := _dictionary(source.get("scenario_demo", {}))
	if bool(source.get("needs_scenario_demo", false)) and _real_track_count(entries) == 0 and not demo.is_empty():
		entries.append(_compose_track_entry(demo, str(demo.get("state_text", "已公开")), source))
	if entries.is_empty(): entries.append({"label":"牌轨空闲", "state":"等待", "slot":"--", "owner_hint":"待猜", "tooltip":str(source.get("status_text", "等待玩家出牌。"))})
	var resolution_track := {
		"title": "公共结算轨",
		"phase": _track_phase(source),
		"summary": _track_summary(source, entries),
		"privacy_hint": "匿名牌只显示公开线索；隐藏归属、私密目标和弃牌不会进入公共轨。",
		"empty_text": str(source.get("status_text", "等待玩家出牌。")),
		"auction_open": bool(source.get("auction_open", false)),
		"auction_response": {
			"active": bool(source.get("bidding_open", false)) or bool(source.get("counter_window_active", false)) or bool(source.get("pending_decision", false)),
			"summary": _track_response_text(source),
		},
		"entries": entries,
	}
	return {"entries": entries, "resolution_track": resolution_track}


func _compose_track_entry(source: Dictionary, state_text: String, track: Dictionary) -> Dictionary:
	var entry := _dictionary(source.get("entry", {}))
	var card_source := _dictionary(source.get("card", {}))
	var presentation := _compose_card(card_source)
	var resolution_id := _resolution_id(entry)
	var selected := resolution_id >= 0 and resolution_id == int(track.get("selected_resolution_id", -1))
	var owner_revealed := bool(entry.get("public_owner_revealed", false))
	var owner_text := "待猜"
	if owner_revealed: owner_text = str(entry.get("public_owner_label", source.get("public_owner_label", "已公开"))).replace("归属：", "").replace("归属:", "")
	var bid := int(entry.get("winning_bid", 0))
	if bid <= 0: bid = int(entry.get("tip", 0))
	var cost_text := "¥%d" % bid if bid > 0 else ""
	var card_label := str(source.get("card_label", presentation.get("display_name", "公开牌")))
	var requirement_text := str(source.get("requirement_text", card_source.get("play_requirement_text", "")))
	var target_text := str(source.get("target_text", ""))
	var badges := _visible_badges(entry, state_text, bid, track, selected)
	var tooltip := _track_tooltip(source, presentation, state_text, requirement_text, target_text, badges)
	var requirements := [
		{"text":state_text, "tooltip":"这张牌在公共牌轨中的位置。"},
		{"text":"归属:%s" % owner_text, "tooltip":"未公开前只能从报价、目标和余波推理。"},
	]
	if cost_text != "": requirements.append({"text":"报价%s" % cost_text, "tooltip":"公开报价/成交小费，是来源推理线索。"})
	if requirement_text != "": requirements.append({"text":_short_text(requirement_text.replace("打出条件：", "").replace("条件：", ""), 18), "tooltip":requirement_text})
	if target_text != "": requirements.append({"text":"目标:%s" % _short_text(target_text, 12), "tooltip":target_text})
	if str(_dictionary(card_source.get("skill", {})).get("kind", "")) == "city_development":
		requirements.append({"text":str(source.get("project_label", "商品项目")), "tooltip":"公开牌轨显示商品、发展方向与目标区域，但不显示出牌者或项目份额。"})
	var actions := []
	var deep_links := []
	if resolution_id >= 0:
		actions.append({"id":"track_select_%d" % resolution_id, "label":"选中竞猜", "disabled":owner_revealed, "tooltip":"把这张牌设为当前归属竞猜对象。" if not owner_revealed else "归属已公开，无需竞猜。"})
		actions.append({"id":"track_intel_%d" % resolution_id, "label":"线索档案", "tooltip":"打开情报档案，并把这张牌的条件、目标、报价和余波线索置顶。"})
		deep_links.append({"id":"track_intel_%d" % resolution_id, "label":"线索档案", "tooltip":"打开情报档案并置顶这张牌。"})
		var group_size := maxi(1, int(entry.get("group_size", 1)))
		var group_order := clampi(int(entry.get("group_order", 1)), 1, group_size)
		if bool(source.get("can_reorder", false)) and group_size > 1:
			actions.append({"id":"group_order_up_%d" % resolution_id, "label":"组内前移", "disabled":group_order <= 1, "tooltip":"只调整自己卡牌组的连续结算顺序，不改变组报价。"})
			actions.append({"id":"group_order_down_%d" % resolution_id, "label":"组内后移", "disabled":group_order >= group_size, "tooltip":"只调整自己卡牌组的连续结算顺序，不改变组报价。"})
	var card_name := str(card_source.get("card_name", _dictionary(card_source.get("skill", {})).get("name", "")))
	if card_name != "":
		actions.append({"id":"track_open_%s" % card_name, "label":"卡牌详情", "tooltip":"打开这张牌的图鉴详情。"})
		deep_links.append({"id":"track_open_%s" % card_name, "label":"卡牌详情"})
	return {
		"id":"track_%d" % resolution_id, "resolution_id":resolution_id,
		"group_id":str(entry.get("group_id", "")), "group_position":int(entry.get("group_position", 0)), "group_order":int(entry.get("group_order", 1)), "group_size":int(entry.get("group_size", 1)), "group_bid":bid,
		"card_name":card_name, "label":"%s %s" % [state_text, _short_text(card_label, 8)], "slot":_slot_text(state_text), "state":state_text, "kind":_track_kind(state_text), "cost":cost_text,
		"owner_hint":owner_text, "badges":badges, "active":selected or state_text.begins_with("当前展示") or state_text.begins_with("竞拍组1") or state_text.begins_with("锁定组1"), "selected":selected,
		"accent":presentation.get("accent", Color("#94a3b8")), "tooltip":tooltip, "title":"牌轨详情", "summary":"%s｜%s｜归属:%s" % [state_text, _short_text(card_label, 10), owner_text],
		"detail":_short_text(tooltip, 64), "full_detail":tooltip, "why":"看报价、目标、余波猜来源。", "requirements":requirements, "actions":actions, "deep_links":deep_links,
		"select_action":"track_select_%d" % resolution_id if resolution_id >= 0 else "", "open_action":"track_open_%s" % card_name if card_name != "" else "",
	}


func _compose_right_inspector(source: Dictionary, hand_cards: Array, track_entries: Array) -> Dictionary:
	var selected_slot := int(source.get("selected_hand_slot", -1))
	for card_variant in hand_cards:
		var card := _dictionary(card_variant)
		if int(card.get("slot", -1)) == selected_slot: return _hand_inspector(card, _array(source.get("logs", [])))
	var selected_resolution_id := int(source.get("selected_resolution_id", -1))
	if selected_resolution_id >= 0:
		for entry_variant in track_entries:
			var entry := _dictionary(entry_variant)
			if int(entry.get("resolution_id", -1)) == selected_resolution_id: return _track_inspector(entry, _array(source.get("logs", [])))
	return {
		"title":"右侧详情", "why":str(source.get("fallback_why", "先选择区域或卡牌。")), "district":_dictionary(source.get("district", {})),
		"requirements":_array(source.get("fallback_requirements", [])), "actions":_array(source.get("fallback_actions", [])), "deep_links":_array(source.get("fallback_deep_links", [])), "logs":_array(source.get("logs", [])),
	}


func _hand_inspector(card: Dictionary, logs: Array) -> Dictionary:
	var chips := []
	for key in ["rank", "type", "cost", "target"]:
		var value := str(card.get(key, ""))
		if value.strip_edges() != "": chips.append({"text":"%s %s" % [_card_fact_label(key), value]})
	var effect_text := str(card.get("effect", ""))
	var summary_text := str(card.get("summary", "")).strip_edges()
	if summary_text == "": summary_text = _short_text(effect_text, 56) if effect_text.strip_edges() != "" else "看费用、目标和当前选区条件。"
	var why_text := str(card.get("why", effect_text))
	if why_text.strip_edges() == "": why_text = "先看费用、目标和当前选区条件，再决定是否打出。"
	return {"title":"卡牌详情", "why":why_text, "district":{"id":str(card.get("id", "")), "title":str(card.get("name", "卡牌")), "summary":summary_text, "detail":summary_text, "full_detail":effect_text, "chips":chips}, "requirements":_array(card.get("requirements", [])), "actions":_array(card.get("actions", [])), "deep_links":[{"id":"detail_cards", "label":"卡牌详情"}, {"id":"detail_region", "label":"区域详情"}], "logs":logs}


func _track_inspector(entry: Dictionary, logs: Array) -> Dictionary:
	var chips := [{"text":"槽 %s" % str(entry.get("slot", "--"))}, {"text":str(entry.get("state", "等待"))}, {"text":"归属:%s" % str(entry.get("owner_hint", "匿名"))}]
	var cost_text := str(entry.get("cost", "")).strip_edges()
	if cost_text != "": chips.append({"text":"报价%s" % cost_text})
	for badge_variant in _array(entry.get("badges", [])):
		var badge_text := str(badge_variant).strip_edges()
		if badge_text != "": chips.append({"text":badge_text})
		if chips.size() >= 6: break
	var tooltip := str(entry.get("tooltip", ""))
	return {"title":str(entry.get("title", "牌轨详情")), "why":str(entry.get("why", tooltip)), "district":{"id":str(entry.get("id", "")), "title":str(entry.get("label", "公共牌槽")), "summary":str(entry.get("summary", tooltip)), "detail":str(entry.get("detail", tooltip)), "full_detail":str(entry.get("full_detail", tooltip)), "chips":chips}, "requirements":_array(entry.get("requirements", [])), "actions":_array(entry.get("actions", [])), "deep_links":_array(entry.get("deep_links", [])), "logs":logs}


func _visible_badges(entry: Dictionary, state_text: String, bid: int, track: Dictionary, selected: bool) -> Array:
	var badges := []
	if selected: badges.append("已选")
	if str(entry.get("group_id", "")) != "": badges.append("同源组 %d/%d" % [clampi(int(entry.get("group_order", 1)), 1, maxi(1, int(entry.get("group_size", 1)))), maxi(1, int(entry.get("group_size", 1)))])
	if bool(entry.get("public_owner_revealed", false)): badges.append(_short_text(str(entry.get("public_owner_label", "已公开")).replace("归属：", ""), 6))
	elif bool(entry.get("is_viewer_card", false)): badges.append("我的牌")
	if bool(track.get("auction_open", false)) and state_text.begins_with("竞拍") and bid > 0 and bid == int(track.get("highest_bid", -1)): badges.append("最高价")
	if state_text.begins_with("当前展示"): badges.append("展示")
	elif state_text.begins_with("锁定组1") or state_text.begins_with("竞拍组1") or state_text.begins_with("组织组1"): badges.append("队首")
	elif state_text.begins_with("下批"): badges.append("下批")
	if state_text.begins_with("已结算") and str(entry.get("aftermath_clue", "")) != "": badges.append("余波")
	return badges.slice(0, 2)


func _resolution_badge_color(text: String) -> Color:
	if text.contains("我的"): return Color("#a7f3d0")
	if text.contains("余波线索"): return Color("#f0abfc")
	if text.contains("竞价线索") or text.contains("成交") or text.contains("小费") or text.contains("最高"): return Color("#fde68a")
	if text.contains("合约"): return Color("#fbbf24")
	if text.contains("出牌条件"): return Color("#bbf7d0")
	if text.contains("归属未知") or text.contains("归属待猜"): return Color("#94a3b8")
	if text.contains("公开归属"): return Color("#fef3c7")
	if text.contains("下一张") or text.contains("队首") or text.contains("候补") or text.contains("下批"): return Color("#bae6fd")
	if text.contains("展示"): return Color("#fda4af")
	return Color("#c4b5fd")


func _track_tooltip(source: Dictionary, presentation: Dictionary, state_text: String, requirement_text: String, target_text: String, badges: Array) -> String:
	var lines := ["%s｜%s" % [state_text, str(presentation.get("display_name", "公开牌"))], "效果：%s" % _short_text(str(source.get("effect_text", presentation.get("quick_effect_full", ""))), 68)]
	if requirement_text != "": lines.append(requirement_text)
	if target_text != "": lines.append("目标：%s" % _short_text(target_text, 48))
	var animation_text := str(source.get("animation_text", ""))
	if animation_text != "": lines.append("演出：%s" % _short_text(animation_text, 64))
	var tip_clue := str(source.get("tip_clue", ""))
	if tip_clue != "": lines.append("竞价：%s" % _short_text(tip_clue, 60))
	if not badges.is_empty(): lines.append("牌槽标记：%s" % " / ".join(badges))
	lines.append("单击竞猜归属；双击打开卡牌图鉴。")
	return "\n".join(lines)


func _compose_event(entry: Dictionary, index: int) -> Dictionary:
	if entry.is_empty(): return {}
	var text := str(entry.get("text", "公共事件"))
	var detail := str(entry.get("tooltip", text))
	return {"id":"event_%d" % index, "label":_short_text(text, 12), "slot":"事件", "state":"公共事件", "kind":"event", "owner_hint":"只读", "badges":["只读"], "active":false, "accent":entry.get("accent", Color("#a78bfa")), "tooltip":"公共事件：只读，不可竞猜｜%s" % detail, "title":"牌轨事件", "summary":_short_text(text, 36), "detail":detail, "why":"公共只读事件。", "requirements":[{"text":"只读"}, {"text":"公共事件"}], "deep_links":[{"id":"detail_intel", "label":"情报详情"}]}


func _track_phase(source: Dictionary) -> String:
	if bool(source.get("counter_window_active", false)): return "响应"
	if bool(source.get("auction_open", false)): return "锁牌"
	if str(source.get("group_phase", "")) == "organize": return "组织"
	if not _dictionary(source.get("active", {})).is_empty(): return "展示中"
	if bool(source.get("batch_locked", false)): return "锁定"
	if not _array(source.get("queue", [])).is_empty(): return "候补"
	if not _array(source.get("next_queue", [])).is_empty(): return "下批"
	if not _array(source.get("history", [])).is_empty(): return "历史"
	return "等待"


func _track_summary(source: Dictionary, entries: Array) -> String:
	if bool(source.get("auction_open", false)): return "最后5秒锁牌：%d个匿名组只能提高组报价，不能再加入卡牌。" % maxi(1, int(source.get("group_count", 1)))
	if str(source.get("group_phase", "")) == "organize": return "前25秒组织：每人0-3张形成一个匿名组，可调组内顺序并提高组报价。"
	if bool(source.get("counter_window_active", false)): return "相位响应窗口开启；等待可用响应或倒计时结束。"
	if not _dictionary(source.get("active", {})).is_empty(): return "正在展示 1 张匿名牌；效果公开，归属仍靠线索推理。"
	var queue := _array(source.get("queue", [])); var next_queue := _array(source.get("next_queue", [])); var history := _array(source.get("history", []))
	if not queue.is_empty() or not next_queue.is_empty(): return "候补 %d 张｜下批 %d 张｜历史 %d 条。" % [queue.size(), next_queue.size(), history.size()]
	var real_count := _real_track_count(entries)
	return "最近公开线索 %d 条，可回看历史证据链。" % real_count if real_count > 0 else "没有正在结算的公开牌。"


func _track_response_text(source: Dictionary) -> String:
	if bool(source.get("auction_open", false)): return "锁牌阶段只允许加价；正报价档位唯一，最高组报价进入怪兽赌局公共奖池。"
	if str(source.get("group_phase", "")) == "organize": return "组织阶段可追加同组卡牌、调整组内顺序并提高组报价。"
	if bool(source.get("counter_window_active", false)): return "相位响应窗口开启；可用响应牌可以介入当前展示。"
	if bool(source.get("pending_decision", false)): return "临时决策 Overlay 正在等待选择；完成后继续结算。"
	return ""


func _slot_text(state_text: String) -> String:
	if state_text.begins_with("已结算"): return "✓"
	if state_text.begins_with("当前展示"): return "0"
	if state_text.contains("组"):
		var group_number := state_text.get_slice("组", 1).get_slice("·", 0)
		return "G%d" % maxi(1, int(group_number))
	if state_text.begins_with("下批"): return "N%d" % maxi(1, _state_number(state_text))
	return "·"


func _state_number(state_text: String) -> int:
	var digits := ""
	for index in range(state_text.length()):
		var character := state_text.substr(index, 1)
		if character.unicode_at(0) >= 48 and character.unicode_at(0) <= 57: digits += character
	return int(digits) if digits != "" else 0


func _track_kind(state_text: String) -> String:
	if state_text.begins_with("已结算"): return "history"
	if state_text.begins_with("当前展示"): return "active"
	if state_text.begins_with("下批等待"): return "next"
	if state_text.begins_with("竞拍"): return "auction"
	if state_text.begins_with("锁定"): return "locked"
	return "queue"


func _resolution_id(entry: Dictionary) -> int:
	return int(entry.get("resolution_id", entry.get("queued_order", -1)))


func _real_track_count(entries: Array) -> int:
	var count := 0
	for entry_variant in entries:
		if entry_variant is Dictionary and str((entry_variant as Dictionary).get("kind", "")) != "event": count += 1
	return count


func _card_fact_label(key: String) -> String:
	return str({"rank":"等级", "type":"类型", "cost":"费用", "target":"目标"}.get(key, key))


func _compose_card(source: Dictionary) -> Dictionary:
	if _card_presentation_service == null or not _card_presentation_service.has_method("compose_card"): return {}
	var value: Variant = _card_presentation_service.call("compose_card", source)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _short_text(value: String, limit: int) -> String:
	if limit <= 0 or value.length() <= limit: return value
	return value.substr(0, maxi(0, limit - 1)) + "…"


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if value is Array else []
