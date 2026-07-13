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
		"supported_domain": "victory_control_public_presentation_v05",
		"compose_count": _compose_count,
		"calculates_region_control": false,
		"calculates_top_n_gdp": false,
		"sorts_final_rankings": false,
		"evaluates_private_truth": false,
		"reads_runtime_nodes": false,
		"consumes_victory_snapshot": true,
		"legacy_cash_goal_presentation_active": false,
	}


func _empty_snapshot() -> Dictionary:
	var overview := [{"title": "暂无局势", "body": "开始新局后显示区域控制、Top-N归属GDP和公开审计。", "accent": Color("#facc15"), "tooltip": "胜利控制事实尚未初始化。"}]
	return {
		"summary_text": "还没有可用玩家数据。",
		"overview_cards": overview,
		"scoreboard": {"title": "局势记分板", "accent": Color("#facc15"), "overview_cards": overview, "chips": [], "kpis": [], "seats": [], "hint": "开始新局后显示审计进度。"},
	}


func _summary_text(source: Dictionary) -> String:
	var victory := _victory_snapshot(source)
	var lines := [
		"局势排名",
		"常规胜利需要控制%d个区域，并让其中Top-N个人归属GDP达到%d/min。" % [_required_regions(source), _required_gdp(source)],
		_state_explanation(victory),
		"资格保持10个有效游戏秒后启动120秒公开审计；终点依次比较Top-N归属GDP、控制区域总数和准确现金总账。",
		"未进入审计名单的对手资产继续保密；名单席位公开准确经济资产，但手牌内容、私人情报和电脑对手计划仍不公开。",
	]
	if bool(source.get("selected_available", false)):
		lines.append("我的进度：Top-N GDP %d/%d｜控制区域 %d/%d｜%s。" % [
			int(source.get("selected_top_n_gdp_per_minute", 0)), _required_gdp(source),
			int(source.get("selected_controlled_region_count", 0)), _required_regions(source),
			_short_text(str(source.get("countdown_text", "")), 36),
		])
	var final_summary := str(source.get("final_summary_text", "")).strip_edges()
	if bool(source.get("game_over", false)) and not final_summary.is_empty():
		lines.append("")
		lines.append(final_summary)
	return "\n".join(lines)


func _overview_cards(source: Dictionary) -> Array:
	var victory := _victory_snapshot(source)
	return [
		{"title": "区域控制", "body": "唯一最高且个人归属占比至少30%；平局时无人控制。", "accent": Color("#38bdf8"), "tooltip": "区域毁灭或GDP为0时也无人控制。"},
		{"title": "胜利门槛", "body": "控制%d区｜Top-N GDP %d/min" % [_required_regions(source), _required_gdp(source)], "accent": Color("#4ade80"), "tooltip": "系统自动选择个人归属GDP最高的N个受控区域。"},
		{"title": "审计状态", "body": _short_text(_state_explanation(victory), 72), "accent": Color("#fb923c"), "tooltip": str(source.get("countdown_text", "等待胜利资格"))},
	]


func _scoreboard_snapshot(source: Dictionary, seats: Array, overview_cards: Array) -> Dictionary:
	var own_gdp := int(source.get("selected_top_n_gdp_per_minute", 0))
	var own_regions := int(source.get("selected_controlled_region_count", 0))
	return {
		"title": "局势记分板",
		"title_tooltip": "只展示VictoryControl授权的胜利进度和审计资产。",
		"tooltip": "先看控制区域和Top-N GDP，再看资格、审计名单与剩余时间。",
		"accent": Color("#facc15"),
		"overview_columns": clampi(int(source.get("overview_columns", 3)), 1, 3),
		"kpi_columns": clampi(int(source.get("kpi_columns", 4)), 1, 4),
		"seat_columns": clampi(int(source.get("seat_columns", 4)), 1, 4),
		"overview_cards": overview_cards,
		"chips": _chip_snapshots(source),
		"kpis": [
			{"title": "我的Top-N GDP", "value": "%d/%d" % [own_gdp, _required_gdp(source)], "meta": "还差%d GDP/min" % maxi(0, _required_gdp(source) - own_gdp), "accent": Color("#38bdf8"), "tooltip": "只统计受控区域中的个人归属GDP。"},
			{"title": "我的控制区域", "value": "%d/%d区" % [own_regions, _required_regions(source)], "meta": "还差%d区" % maxi(0, _required_regions(source) - own_regions), "accent": Color("#4ade80"), "tooltip": "30%且唯一最高才计为控制。"},
			{"title": "审计名单", "value": "%d席" % int((_victory_snapshot(source).get("audit_roster", []) as Array).size()), "meta": _state_label(str(_victory_snapshot(source).get("state", "idle"))), "accent": Color("#fb923c"), "tooltip": "加入后本次审计内持续公开经济资产。"},
			{"title": "公开异动", "value": "%d条" % int(source.get("public_shift_count", 0)), "meta": "牌轨/地图/怪兽", "accent": Color("#c084fc"), "tooltip": "公开结果帮助判断GDP与控制变化。"},
		],
		"seats": _seat_snapshots(source, seats),
		"hint": "审计名单席位显示准确经济资产；其他对手只显示公开状态。",
	}


func _chip_snapshots(source: Dictionary) -> Array:
	var victory := _victory_snapshot(source)
	return [
		{"text": "控区%d" % _required_regions(source), "accent": Color("#bbf7d0"), "tooltip": "本局要求的控制区域数量。"},
		{"text": "Top-N %d/min" % _required_gdp(source), "accent": Color("#bfdbfe"), "tooltip": "本局要求的Top-N个人归属GDP。"},
		{"text": _short_text(str(source.get("countdown_text", "等待资格")), 26), "accent": Color("#fed7aa"), "tooltip": _state_explanation(victory)},
		{"text": "名单明牌", "accent": Color("#c4b5fd"), "tooltip": "名单玩家公开经济资产；私人手牌内容与情报不公开。"},
	]


func _seat_snapshots(source: Dictionary, seats: Array) -> Array:
	var result := []
	for seat_index in range(seats.size()):
		var entry := seats[seat_index] as Dictionary
		var player_index := int(entry.get("player_index", seat_index))
		var eliminated := bool(entry.get("eliminated", false))
		var audit := _audit_entry(source, player_index)
		var can_view_private := bool(entry.get("can_view_private", false))
		var publicly_audited := not audit.is_empty()
		var top_n_gdp := int(audit.get("top_n_gdp_per_minute", entry.get("top_n_gdp_per_minute", 0)))
		var controlled_regions := int(audit.get("controlled_region_count", entry.get("controlled_region_count", 0)))
		var assets: Dictionary = audit.get("economic_assets", {}) if audit.get("economic_assets", {}) is Dictionary else {}
		var chips := []
		if eliminated:
			chips.append({"text": "已淘汰", "accent": Color("#fecdd3"), "tooltip": "该席位不能进入审计终点排名。"})
		elif publicly_audited:
			chips.append({"text": "Top-N %d" % top_n_gdp, "accent": Color("#bfdbfe"), "tooltip": "审计公开的Top-N归属GDP/min。"})
			chips.append({"text": "控区%d" % controlled_regions, "accent": Color("#bbf7d0"), "tooltip": "审计公开的控制区域数量。"})
			chips.append({"text": "账本¥%.2f" % (float(int(audit.get("cash_ledger_cents", 0))) / 100.0), "accent": Color("#fef3c7"), "tooltip": "准确现金总账=可用现金+托管现金。"})
			chips.append({"text": "项目%d/合约%d/仓储%d/金融%d" % [_array_size(assets.get("project_positions", [])), _array_size(assets.get("contracts", [])), _array_size(assets.get("warehouses", [])), _array_size(assets.get("financial_positions", []))], "accent": Color("#c4b5fd"), "tooltip": "审计名单的经济资产明牌。"})
		elif can_view_private:
			chips.append({"text": "Top-N %d" % top_n_gdp, "accent": Color("#bfdbfe"), "tooltip": "你的精确Top-N归属GDP/min。"})
			chips.append({"text": "控区%d" % controlled_regions, "accent": Color("#bbf7d0"), "tooltip": "你的精确控制区域数量。"})
			chips.append({"text": "现金¥%d" % int(entry.get("cash", 0)), "accent": Color("#fef3c7"), "tooltip": "你的可用现金。"})
		else:
			chips.append({"text": "未入审计", "accent": Color("#94a3b8"), "tooltip": "该席位的准确经济资产仍保持隐藏。"})
			chips.append({"text": "看公开线索", "accent": Color("#c4b5fd"), "tooltip": "从牌轨、地图和公开事件推理。"})
		result.append({
			"name": "P%d｜%s" % [player_index + 1, _short_text(str(entry.get("name", "玩家")), 10)],
			"rank": "名单" if publicly_audited else ("出局" if eliminated else "在局"),
			"rank_tooltip": "审计名单不是最终排名；终点会重新核验资格。",
			"score": "Top-N %d" % top_n_gdp if (publicly_audited or can_view_private) else "进度隐藏",
			"score_color": Color("#fb7185") if eliminated else (Color("#fef3c7") if publicly_audited or can_view_private else Color("#94a3b8")),
			"score_tooltip": "胜利进度来自VictoryControl快照。" if publicly_audited or can_view_private else "未获授权的对手精确进度不显示。",
			"chips": chips,
			"meta": "审计资产公开" if publicly_audited else ("已淘汰" if eliminated else "经济资产保密"),
			"tooltip": "手牌内容、私人情报、隐藏怪兽关系和电脑对手计划始终不在该快照中。",
			"eliminated": eliminated,
			"accent": Color("#64748b") if eliminated else _seat_accent(player_index),
		})
	return result


func _victory_snapshot(source: Dictionary) -> Dictionary:
	return (source.get("victory_control", {}) as Dictionary).duplicate(true) if source.get("victory_control", {}) is Dictionary else {}


func _audit_entry(source: Dictionary, player_index: int) -> Dictionary:
	for entry_variant in _victory_snapshot(source).get("audit_entries", []):
		if entry_variant is Dictionary and int((entry_variant as Dictionary).get("player_index", -1)) == player_index:
			return (entry_variant as Dictionary).duplicate(true)
	return {}


func _required_gdp(source: Dictionary) -> int:
	return maxi(0, int(source.get("required_top_n_gdp_per_minute", 0)))


func _required_regions(source: Dictionary) -> int:
	return maxi(0, int(source.get("required_controlled_region_count", 0)))


func _state_explanation(victory: Dictionary) -> String:
	match str(victory.get("state", "idle")):
		"qualification": return "资格保持中，剩余%.1f秒。" % float(victory.get("qualification_remaining_seconds", 0.0))
		"audit": return "公开审计进行中，剩余%.1f秒；倒计时不会因暂时失去资格而取消。" % float(victory.get("audit_remaining_seconds", 0.0))
		"cooldown": return "本次审计无人达标，冷却剩余%.1f秒。" % float(victory.get("cooldown_remaining_seconds", 0.0))
		"resolved": return "胜利结果已由版本化outcome receipt确认。"
	return "尚未有人持续满足胜利资格。"


func _state_label(state: String) -> String:
	return {"qualification": "资格保持", "audit": "公开审计", "cooldown": "审计冷却", "resolved": "已结算"}.get(state, "等待资格") as String


func _array_size(value: Variant) -> int:
	return (value as Array).size() if value is Array else 0


func _seat_accent(player_index: int) -> Color:
	var palette := [Color("#38bdf8"), Color("#f472b6"), Color("#4ade80"), Color("#facc15"), Color("#c084fc"), Color("#fb7185"), Color("#2dd4bf"), Color("#fb923c")]
	return palette[posmod(player_index, palette.size())]


func _dictionary_array(value: Variant, limit: int) -> Array:
	var result := []
	if value is Array:
		for entry_variant in value:
			if entry_variant is Dictionary:
				result.append((entry_variant as Dictionary).duplicate(true))
			if result.size() >= limit:
				break
	return result


func _short_text(value: String, limit: int) -> String:
	return value if limit <= 0 or value.length() <= limit else value.substr(0, maxi(0, limit - 1)) + "…"
