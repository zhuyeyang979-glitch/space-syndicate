@tool
extends Node
class_name FinalSettlementPublicSnapshotService

var _configured := false
var _compose_count := 0


func configure(_config: Dictionary = {}) -> void:
	_configured = true


func compose(source: Dictionary) -> Dictionary:
	_compose_count += 1
	if not bool(source.get("valid", false)):
		return _empty_snapshot(source)
	var receipt: Dictionary = source.get("outcome_receipt", {}) if source.get("outcome_receipt", {}) is Dictionary else {}
	if receipt.is_empty() or str(receipt.get("outcome_id", "")).is_empty():
		return _empty_snapshot({"reason": "缺少版本化胜利结果。"})
	var comparison_entries := _dictionary_array(source.get("money_source_entries", []), 8)
	var rank_entries := _dictionary_array(source.get("rank_entries", []), 8)
	return {
		"summary_text": _summary_text(source, receipt),
		"board": _board_snapshot(source, receipt, comparison_entries, rank_entries),
	}


func debug_snapshot() -> Dictionary:
	return {
		"service_ready": _configured,
		"service_authoritative": _configured,
		"supported_domain": "victory_outcome_public_presentation_v05",
		"compose_count": _compose_count,
		"consumes_outcome_receipt": true,
		"calculates_final_score": false,
		"sorts_final_rankings": false,
		"calculates_city_clearance": false,
		"calculates_intel_cash": false,
		"reads_private_hands": false,
		"reads_runtime_nodes": false,
		"legacy_cash_goal_presentation_active": false,
	}


func _empty_snapshot(source: Dictionary) -> Dictionary:
	var reason := str(source.get("reason", "没有可用胜利结果。"))
	return {
		"summary_text": "游戏结束：%s" % reason,
		"board": {"title": "终局审计｜赛后记分板", "accent": Color("#facc15"), "chips": [], "kpis": [{"title": "结果不可用", "body": reason, "meta": "没有重新计算或猜测排名。", "accent": Color("#facc15")}], "money_sources": [], "event_lines": [], "ranks": [], "actions": _after_actions()},
	}


func _summary_text(source: Dictionary, receipt: Dictionary) -> String:
	var names := _winner_names(source)
	return "\n".join([
		"游戏结束：%s" % str(source.get("reason", _reason_label(str(receipt.get("reason_code", ""))))),
		"胜者：%s%s。" % ["、".join(names) if not names.is_empty() else "无人", "（共同胜利）" if bool(receipt.get("co_victory", false)) else ""],
		"排名只采用outcome receipt：Top-N个人归属GDP、控制区域总数、准确现金总账；完全相同则共同胜利。",
		"复盘只展示已授权的公开/终局数据，不重新打开手牌内容、私人情报或电脑对手计划。",
	])


func _board_snapshot(source: Dictionary, receipt: Dictionary, comparison_entries: Array, rank_entries: Array) -> Dictionary:
	var names := _winner_names(source)
	var first_rank: Dictionary = rank_entries[0] if not rank_entries.is_empty() and rank_entries[0] is Dictionary else {}
	var map_facts: Dictionary = source.get("map_facts", {}) if source.get("map_facts", {}) is Dictionary else {}
	return {
		"title": "终局审计｜赛后记分板",
		"title_tooltip": "本面板只展示VictoryControl的版本化outcome receipt。",
		"tooltip": "胜利结果已经确认；展示层不重新排序或计算分数。",
		"accent": Color("#facc15"),
		"kpi_columns": clampi(int(source.get("kpi_columns", 4)), 1, 4),
		"money_columns": clampi(int(source.get("money_columns", 4)), 1, 4),
		"rank_columns": clampi(int(source.get("rank_columns", 4)), 1, 4),
		"action_columns": 3,
		"chips": [
			{"text": "胜者:%s" % _short_text("、".join(names), 18), "accent": Color("#facc15"), "tooltip": "来自outcome receipt的胜者集合。"},
			{"text": "控区%d" % int(source.get("required_controlled_region_count", 0)), "accent": Color("#bbf7d0"), "tooltip": "本局胜利门槛。"},
			{"text": "Top-N %d/min" % int(source.get("required_top_n_gdp_per_minute", 0)), "accent": Color("#bfdbfe"), "tooltip": "本局胜利门槛。"},
		],
		"kpis": [
			{"title": "胜利结果", "body": "%s%s" % ["、".join(names), "共同胜利" if bool(receipt.get("co_victory", false)) else "胜利"], "meta": _reason_label(str(receipt.get("reason_code", ""))), "accent": Color("#facc15")},
			{"title": "Top-N归属GDP", "body": "%d GDP/min" % int(first_rank.get("top_n_gdp_per_minute", 0)), "meta": "第一比较项", "accent": Color("#38bdf8")},
			{"title": "控制区域", "body": "%d区" % int(first_rank.get("controlled_region_count", 0)), "meta": "第二比较项", "accent": Color("#4ade80")},
			{"title": "准确现金总账", "body": "¥%.2f" % (float(int(first_rank.get("cash_ledger_cents", 0))) / 100.0), "meta": "可用现金+托管现金", "accent": Color("#fef3c7")},
		],
		"money_title": "审计比较｜版本化结果",
		"money_sources": _comparison_snapshots(comparison_entries),
		"event_title": "公开事件｜牌轨与地图",
		"event_lines": _event_lines(source, map_facts),
		"rank_title": "排名轨｜Top-N GDP → 控区 → 现金总账",
		"ranks": _rank_snapshots(rank_entries),
		"action_title": "赛后入口｜查原因或再开一桌",
		"actions": _after_actions(),
	}


func _comparison_snapshots(entries: Array) -> Array:
	var snapshots := []
	for entry_variant in entries:
		var entry := entry_variant as Dictionary
		var rank := int(entry.get("rank", snapshots.size()))
		snapshots.append({
			"title": "#%d %s%s" % [rank + 1, str(entry.get("name", "玩家")), "｜胜者" if bool(entry.get("winner", rank == 0)) else ""],
			"start_line": "Top-N归属GDP %d/min" % int(entry.get("top_n_gdp_per_minute", 0)),
			"settlement_line": "控制区域%d｜现金总账¥%.2f" % [int(entry.get("controlled_region_count", 0)), float(int(entry.get("cash_ledger_cents", 0))) / 100.0],
			"income_line": "城市经营¥%d｜卡牌收益¥%d｜角色收益¥%d" % [int(entry.get("city_income", 0)), int(entry.get("card_income", 0)), int(entry.get("role_income", 0))],
			"status_line": "GDP/min %d｜%s" % [int(entry.get("gdp_per_minute", 0)), "已淘汰" if bool(entry.get("eliminated", false)) else "终点有效"],
			"tooltip": "前三项直接来自VictoryControl排名；收入字段只用于赛后解释，不参与胜负重算。",
			"accent": Color("#facc15") if bool(entry.get("winner", rank == 0)) else _seat_accent(int(entry.get("player_index", rank))),
		})
	return snapshots


func _rank_snapshots(entries: Array) -> Array:
	var snapshots := []
	for rank in range(entries.size()):
		var entry := entries[rank] as Dictionary
		snapshots.append({
			"title": "#%d｜%s%s" % [rank + 1, str(entry.get("name", "玩家")), "｜共同胜利" if bool(entry.get("winner", false)) else ""],
			"score": "%d GDP/min" % int(entry.get("top_n_gdp_per_minute", 0)),
			"stats": "控区%d｜账本¥%.2f" % [int(entry.get("controlled_region_count", 0)), float(int(entry.get("cash_ledger_cents", 0))) / 100.0],
			"income": "全域GDP/min %d｜现金¥%d" % [int(entry.get("gdp_per_minute", 0)), int(entry.get("cash", 0))],
			"identity": str(entry.get("identity", "公开角色与主要经济路线")),
			"tooltip": "顺序来自outcome receipt；展示层不重新排序。",
			"accent": Color("#facc15") if bool(entry.get("winner", false)) else _seat_accent(int(entry.get("player_index", rank))),
		})
	return snapshots


func _event_lines(source: Dictionary, map_facts: Dictionary) -> Array:
	var lines := []
	for text_key in ["top_card_impact", "monster_impact"]:
		var line := str(source.get(text_key, "")).strip_edges()
		if not line.is_empty():
			lines.append(line)
	lines.append("地图结局：存活城市%d座｜已毁区域%d个｜怪兽在场%d/%d。" % [int(map_facts.get("active_city_count", 0)), int(map_facts.get("destroyed_district_count", 0)), int(map_facts.get("active_monster_count", 0)), int(map_facts.get("monster_count", 0))])
	var resolved_count := int(source.get("resolved_card_count", 0))
	if resolved_count > 0:
		lines.append("牌轨记录：已结算%d张匿名牌。" % resolved_count)
	return lines.slice(0, mini(5, lines.size()))


func _winner_names(source: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for name_variant in source.get("winner_names", []):
		var player_name := str(name_variant).strip_edges()
		if not player_name.is_empty():
			result.append(player_name)
	return result


func _reason_label(reason_code: String) -> String:
	return {"public_audit_complete": "120秒公开审计完成", "last_survivor": "仅剩一名未淘汰玩家", "planet_destroyed": "星球毁灭现金结算"}.get(reason_code, "胜利结果已确认") as String


func _after_actions() -> Array:
	return [
		{"id": "standings", "title": "查看局势排名", "body": "逐席查看审计比较项和已授权经济资产。", "accent": Color("#facc15")},
		{"id": "economy", "title": "打开经济总览", "body": "复查项目GDP、商品、商路和公开经济流水。", "accent": Color("#4ade80")},
		{"id": "new_run", "title": "开局准备", "body": "重新设置席位和挑战深度，开始下一局。", "accent": Color("#67e8f9")},
	]


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
