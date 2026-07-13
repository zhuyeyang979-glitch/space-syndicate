@tool
extends Node
class_name StandingsPublicSnapshotService

var _configured := false
var _compose_count := 0


func configure(_config: Dictionary = {}) -> void:
	_configured = true


func compose(source: Dictionary) -> Dictionary:
	_compose_count += 1
	if not bool(source.get("valid", false)):
		return _empty_snapshot()
	var seats := _dictionary_array(source.get("seat_entries", []), 8)
	var overview_cards := _overview_cards(source)
	return {
		"summary_text": _summary_text(source),
		"overview_cards": overview_cards,
		"scoreboard": _scoreboard_snapshot(source, seats, overview_cards),
	}


func debug_snapshot() -> Dictionary:
	return {
		"service_ready": _configured,
		"service_authoritative": _configured,
		"supported_domain": "standings_public_presentation",
		"compose_count": _compose_count,
		"calculates_settlement_score": false,
		"calculates_city_income": false,
		"sorts_final_rankings": false,
		"evaluates_private_truth": false,
		"reads_runtime_nodes": false,
		"bounded_seat_input": true,
		"legacy_main_formatter_active": false,
	}


func _empty_snapshot() -> Dictionary:
	var overview := [
		{"title": "暂无局势", "body": "开始新局后，这里会显示现金目标、终局倒计时和玩家记分板。", "accent": Color("#facc15"), "tooltip": "局势事实尚未初始化。"},
	]
	return {
		"summary_text": "还没有可用玩家数据。开始新局后会显示当前资金、存活城市、情报标注和预估结算资金。",
		"overview_cards": overview,
		"scoreboard": {
			"title": "局势记分板",
			"accent": Color("#facc15"),
			"overview_cards": overview,
			"chips": [],
			"kpis": [],
			"seats": [],
			"hint": "开始新局后显示当前玩家可见资金与对手公开状态。",
		},
	}


func _summary_text(source: Dictionary) -> String:
	var goal := int(source.get("cash_goal", 0))
	var city_value := int(source.get("city_final_value", 0))
	var lines := [
		"局势排名",
		"目标¥%d；达到后进入终局沙漏，结束按钱最多排名。" % goal,
		"当前只精确显示你的现金、城市和公开资产；对手资金、手牌和私密推理保持隐藏。",
		"预估结算资金 = 当前现金 + 存活城市清算 + 情报待结算；对手现金、手牌和私密推理保持隐藏。",
		"计分 = 现金 + 存活城市×%d + 情报现金；猜对+¥%d，猜错-¥%d。" % [city_value, int(source.get("intel_correct_reward", 0)), int(source.get("intel_wrong_cost", 0))],
	]
	if bool(source.get("selected_available", false)):
		lines.append("我的资产：存活城市%d×¥%d｜现金¥%d｜%s｜%s。" % [int(source.get("selected_city_count", 0)), city_value, int(source.get("selected_cash", 0)), str(source.get("selected_intel_summary", "情报待结算")), _short_text(str(source.get("countdown_text", "")), 24)])
	lines.append("公开异动看牌轨、城市GDP、怪兽受伤、合约和商品价格；下方记分板只精确显示当前玩家，对手真实资产靠线索推理。")
	var final_summary := str(source.get("final_summary_text", "")).strip_edges()
	if bool(source.get("game_over", false)) and final_summary != "":
		lines.append("")
		lines.append(final_summary)
	return "\n".join(lines)


func _overview_cards(source: Dictionary) -> Array:
	return [
		{"title": "局势速览", "body": "看目标、倒计时、公开异动和当前玩家可见资金；对手细节保持隐藏。", "accent": Color("#facc15"), "tooltip": "公开异动用于推理。"},
		{"title": "终局条件", "body": "达到目标¥%d后进入终局沙漏，结束按钱最多排名。" % int(source.get("cash_goal", 0)), "accent": Color("#fb923c"), "tooltip": str(source.get("countdown_text", "尚未进入终局倒计时"))},
		{"title": "我的可见资金", "body": "预估¥%d｜现金¥%d｜存活城市%d×¥%d。" % [int(source.get("selected_score", 0)), int(source.get("selected_cash", 0)), int(source.get("selected_city_count", 0)), int(source.get("city_final_value", 0))], "accent": Color("#38bdf8"), "tooltip": str(source.get("selected_intel_summary", "情报待结算"))},
	]


func _scoreboard_snapshot(source: Dictionary, seats: Array, overview_cards: Array) -> Dictionary:
	var selected_score := int(source.get("selected_score", 0))
	var goal := int(source.get("cash_goal", 0))
	return {
		"title": "局势记分板",
		"title_tooltip": "进行中只显示当前玩家可见资金；对手现金、手牌和真实资产仍靠推理。",
		"tooltip": "桌游式局势记分板：先看目标、倒计时、自己的可见估值和对手隐私牌。",
		"accent": Color("#facc15"),
		"overview_columns": clampi(int(source.get("overview_columns", 3)), 1, 3),
		"kpi_columns": clampi(int(source.get("kpi_columns", 4)), 1, 4),
		"seat_columns": clampi(int(source.get("seat_columns", 4)), 1, 4),
		"overview_cards": overview_cards,
		"chips": _chip_snapshots(source),
		"kpis": [
			{"title": "我的终局距离", "value": "¥%d/%d" % [selected_score, goal], "meta": "差¥%d｜现金¥%d" % [maxi(0, goal - selected_score), int(source.get("selected_cash", 0))], "accent": Color("#38bdf8"), "tooltip": "当前玩家可见结算估值。"},
			{"title": "城市现金流", "value": "%d座" % int(source.get("selected_city_count", 0)), "meta": "GDP/min %d" % int(source.get("selected_gdp_per_minute", 0)), "accent": Color("#4ade80"), "tooltip": "稳定城市现金流是终局资金的主来源。"},
			{"title": "公开异动", "value": "%d条" % int(source.get("public_shift_count", 0)), "meta": "牌轨/怪兽/天气", "accent": Color("#c084fc"), "tooltip": "用公开异动判断谁可能受益。"},
			{"title": "反超方向", "value": "压领先", "meta": "做空/断路/引怪兽", "accent": Color("#fb7185"), "tooltip": "落后时压领先城市；领先时修路、保险、保护高GDP城市。"},
		],
		"seats": _seat_snapshots(source, seats),
		"hint": "读法：自己的牌看精确钱；对手牌看公开线索。想知道钱从哪里来，继续看经济总览和情报档案。",
	}


func _chip_snapshots(source: Dictionary) -> Array:
	return [
		{"text": "目标¥%d" % int(source.get("cash_goal", 0)), "accent": Color("#fef3c7"), "tooltip": "达到目标后进入终局倒计时。"},
		{"text": _short_text(str(source.get("countdown_text", "等待终局")), 22), "accent": Color("#fb923c"), "tooltip": "倒计时结束后按钱最多排名。"},
		{"text": "城市×%d" % int(source.get("city_final_value", 0)), "accent": Color("#4ade80"), "tooltip": "存活城市会在终局清算为现金。"},
		{"text": "对手隐私", "accent": Color("#94a3b8"), "tooltip": "进行中不显示对手现金、手牌、账本或真实资产归属。"},
	]


func _seat_snapshots(source: Dictionary, seats: Array) -> Array:
	var result := []
	var goal := int(source.get("cash_goal", 0))
	for rank in range(seats.size()):
		var entry := seats[rank] as Dictionary
		var player_index := int(entry.get("player_index", rank))
		var eliminated := bool(entry.get("eliminated", false))
		var can_view_private := bool(entry.get("can_view_private", false))
		var accent := Color("#64748b") if eliminated else _seat_accent(player_index)
		var score_text := "出局" if eliminated else ("¥%d" % int(entry.get("score", 0)) if can_view_private else "资金隐私")
		var score_color := Color("#fb7185") if eliminated else (Color("#fef3c7") if can_view_private else Color("#94a3b8"))
		var chips := []
		if eliminated:
			chips.append({"name": "StandingsBankruptBadge", "text": "破产出局", "accent": Color("#fecdd3"), "tooltip": "公开状态：现金归零，提前离桌，不能再行动。"})
			chips.append({"text": "现金0", "accent": Color("#fef3c7"), "tooltip": "公开破产资金。"})
			chips.append({"text": "GDP停流", "accent": Color("#94a3b8"), "tooltip": "破产后城市现金流停止。"})
		elif can_view_private:
			chips.append({"text": "现金¥%d" % int(entry.get("cash", 0)), "accent": Color("#fef3c7"), "tooltip": "当前可见现金。"})
			chips.append({"text": "城%d" % int(entry.get("active_cities", 0)), "accent": Color("#bbf7d0"), "tooltip": "存活城市数量。"})
			chips.append({"text": "GDP%d" % int(entry.get("gdp_per_minute", 0)), "accent": Color("#bfdbfe"), "tooltip": "当前GDP/min。"})
			chips.append({"text": str(entry.get("intel_summary", "情报待结算")), "accent": Color("#c4b5fd"), "tooltip": "当前玩家可见情报结算摘要。"})
		else:
			chips.append({"text": "现金隐藏", "accent": Color("#94a3b8"), "tooltip": "进行中不公开对手资金。"})
			chips.append({"text": "手牌隐藏", "accent": Color("#94a3b8"), "tooltip": "进行中不公开对手手牌或弃牌。"})
			chips.append({"text": "资产靠推理", "accent": Color("#c4b5fd"), "tooltip": "看城市、牌轨、怪兽和商品线索推测。"})
		var meta_text := "现金归零，提前退出本局。" if eliminated else ("离目标¥%d" % maxi(0, goal - int(entry.get("score", 0))) if can_view_private else "看城市、牌轨、怪兽和商品线索推测。")
		result.append({
			"name": "P%d｜%s" % [player_index + 1, _short_text(str(entry.get("name", "玩家")), 10)],
			"rank": "#%d" % (rank + 1),
			"rank_tooltip": "进行中对手名次不等于真实排名，只是座位/可见信息展示。",
			"score": score_text,
			"score_color": score_color,
			"score_tooltip": "现金归零提前失败；该席位结算分为0。" if eliminated else ("%s：%d" % [str(entry.get("score_label", "可见预估")), int(entry.get("score", 0))] if can_view_private else "对手资金与结算估值不公开。"),
			"chips": chips,
			"meta": meta_text,
			"tooltip": "破产出局是公开状态；对手历史手牌、弃牌和私密计划仍不公开。" if eliminated else ("进行中对手现金、手牌、账本和真实城市资产保持隐私。" if not can_view_private else "当前玩家/终局可见记分。"),
			"eliminated": eliminated,
			"accent": accent,
		})
	return result


func _seat_accent(player_index: int) -> Color:
	var palette := [Color("#38bdf8"), Color("#f472b6"), Color("#4ade80"), Color("#facc15"), Color("#c084fc"), Color("#fb7185"), Color("#2dd4bf"), Color("#fb923c")]
	return palette[posmod(player_index, palette.size())]


func _dictionary_array(value: Variant, limit: int) -> Array:
	var result := []
	if not (value is Array):
		return result
	for entry_variant: Variant in value:
		if entry_variant is Dictionary:
			result.append((entry_variant as Dictionary).duplicate(true))
		if result.size() >= limit:
			break
	return result


func _short_text(value: String, limit: int) -> String:
	if limit <= 0 or value.length() <= limit:
		return value
	return value.substr(0, maxi(0, limit - 1)) + "…"
