@tool
extends Node
class_name FinalSettlementPublicSnapshotService

const CASH_PRIVACY_COPY := "现金为最终并列判定项，数值保密"
const PRIVATE_CASH_KEYS := [
	"cash",
	"cash_cents",
	"cash_ledger_cents",
	"available",
	"available_cents",
	"escrow",
	"escrow_cents",
]
const PRIVATE_CASH_TEXT_PATTERN := "(?i)(准确现金(?:总账)?|现金(?:总账)?|账本|可用(?:现金)?|托管(?:现金)?|cash(?:_ledger(?:_cents)?)?|available(?:_cents)?|escrow(?:_cents)?)\\s*[:=：｜]?\\s*[¥￥$]?\\s*-?[0-9][0-9,]*(?:\\.[0-9]+)?"

var _configured := false
var _compose_count := 0


func configure(_config: Dictionary = {}) -> void:
	_configured = true


func compose(source: Dictionary) -> Dictionary:
	_compose_count += 1
	var private_cash_tokens := _private_cash_text_tokens(source)
	var snapshot: Dictionary
	if not bool(source.get("valid", false)):
		snapshot = _empty_snapshot(source)
		return _sanitize_public_snapshot(snapshot, private_cash_tokens, {})
	var receipt: Dictionary = source.get("outcome_receipt", {}) if source.get("outcome_receipt", {}) is Dictionary else {}
	if receipt.is_empty() or str(receipt.get("outcome_id", "")).is_empty():
		snapshot = _empty_snapshot({"reason": "缺少版本化胜利结果。"})
		return _sanitize_public_snapshot(snapshot, private_cash_tokens, {})
	var comparison_entries := _dictionary_array(source.get("money_source_entries", []), 8)
	var rank_entries := _dictionary_array(source.get("rank_entries", []), 8)
	var public_audit_cash_by_player := _public_audit_cash_by_player(source, rank_entries)
	snapshot = {
		"summary_text": _summary_text(source, receipt, not public_audit_cash_by_player.is_empty()),
		"board": _board_snapshot(source, receipt, comparison_entries, rank_entries, public_audit_cash_by_player),
	}
	return _sanitize_public_snapshot(snapshot, private_cash_tokens, public_audit_cash_by_player)


func debug_snapshot() -> Dictionary:
	return {
		"service_ready": _configured,
		"service_authoritative": _configured,
		"supported_domain": "victory_outcome_public_presentation_v06",
		"compose_count": _compose_count,
		"consumes_outcome_receipt": true,
		"calculates_final_score": false,
		"sorts_final_rankings": false,
		"calculates_city_clearance": false,
		"calculates_intel_cash": false,
		"protects_private_cash": true,
		"recursively_sanitizes_public_output": true,
		"cash_visibility_policy": "authoritative_public_audit_allowlist",
		"cash_disclosure_fail_closed": true,
		"supports_authorized_public_audit_cash": true,
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


func _summary_text(source: Dictionary, receipt: Dictionary, has_public_audit_cash: bool) -> String:
	var names := _winner_names(source)
	return "\n".join([
		"游戏结束：%s" % str(source.get("reason", _reason_label(str(receipt.get("reason_code", ""))))),
		"胜者：%s%s。" % ["、".join(names) if not names.is_empty() else "无人", "（共同胜利）" if bool(receipt.get("co_victory", false)) else ""],
		"排名只采用outcome receipt公开比较顺序：%s；完全相同则共同胜利。" % _public_comparison_order(receipt, has_public_audit_cash),
		"复盘只展示已授权的公开/终局数据，不重新打开手牌内容、私人情报或电脑对手计划。",
	])


func _board_snapshot(source: Dictionary, receipt: Dictionary, comparison_entries: Array, rank_entries: Array, public_audit_cash_by_player: Dictionary) -> Dictionary:
	var names := _winner_names(source)
	var first_rank: Dictionary = rank_entries[0] if not rank_entries.is_empty() and rank_entries[0] is Dictionary else {}
	var map_facts: Dictionary = source.get("map_facts", {}) if source.get("map_facts", {}) is Dictionary else {}
	var first_rank_cash_is_public := _entry_has_public_audit_cash(first_rank, public_audit_cash_by_player)
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
			{"text": "Top-K %d/min" % int(source.get("required_top_n_gdp_per_minute", 0)), "accent": Color("#bfdbfe"), "tooltip": "本局胜利门槛。"},
		],
		"kpis": [
			{"title": "胜利结果", "body": "%s%s" % ["、".join(names), "共同胜利" if bool(receipt.get("co_victory", false)) else "胜利"], "meta": _reason_label(str(receipt.get("reason_code", ""))), "accent": Color("#facc15")},
			{"title": "Top-K归属GDP", "body": "%d GDP/min" % int(first_rank.get("top_n_gdp_per_minute", 0)), "meta": "第一比较项", "accent": Color("#38bdf8")},
			{"title": "控制区域", "body": "%d区" % int(first_rank.get("controlled_region_count", 0)), "meta": "第二比较项", "accent": Color("#4ade80")},
			{"title": "准确现金（审计公开）" if first_rank_cash_is_public else "现金并列判定", "body": _cash_disclosure_marker(first_rank, public_audit_cash_by_player, "kpi"), "meta": "Victory权威审计名单公开" if first_rank_cash_is_public else "无权威公开资格；数值保密", "accent": Color("#fef3c7")},
		],
		"money_title": "审计比较｜版本化结果",
		"money_sources": _comparison_snapshots(comparison_entries, public_audit_cash_by_player),
		"event_title": "公开事件｜牌轨与地图",
		"event_lines": _event_lines(source, map_facts),
		"rank_title": "排名轨｜%s" % _public_comparison_order(receipt, not public_audit_cash_by_player.is_empty()),
		"ranks": _rank_snapshots(rank_entries, public_audit_cash_by_player),
		"action_title": "赛后入口｜查原因或再开一桌",
		"actions": _after_actions(),
	}


func _comparison_snapshots(entries: Array, public_audit_cash_by_player: Dictionary) -> Array:
	var snapshots := []
	for entry_variant in entries:
		var entry := entry_variant as Dictionary
		var rank := int(entry.get("rank", snapshots.size()))
		snapshots.append({
			"title": "#%d %s%s" % [rank + 1, str(entry.get("name", "玩家")), "｜胜者" if bool(entry.get("winner", rank == 0)) else ""],
			"start_line": "Top-K归属GDP %d/min" % int(entry.get("top_n_gdp_per_minute", 0)),
			"settlement_line": _cash_disclosure_marker(entry, public_audit_cash_by_player, "settlement"),
			"income_line": "城市经营¥%d｜卡牌收益¥%d｜角色收益¥%d" % [int(entry.get("city_income", 0)), int(entry.get("card_income", 0)), int(entry.get("role_income", 0))],
			"status_line": "GDP/min %d｜%s" % [int(entry.get("gdp_per_minute", 0)), "已淘汰" if bool(entry.get("eliminated", false)) else "终点有效"],
			"tooltip": "排名、Top-K GDP与控区直接来自公开结果；收入字段只用于赛后解释，不参与胜负重算。",
			"accent": Color("#facc15") if bool(entry.get("winner", rank == 0)) else _seat_accent(int(entry.get("player_index", rank))),
		})
	return snapshots


func _rank_snapshots(entries: Array, public_audit_cash_by_player: Dictionary) -> Array:
	var snapshots := []
	for rank in range(entries.size()):
		var entry := entries[rank] as Dictionary
		snapshots.append({
			"title": "#%d｜%s%s" % [rank + 1, str(entry.get("name", "玩家")), "｜共同胜利" if bool(entry.get("winner", false)) else ""],
			"score": "%d GDP/min" % int(entry.get("top_n_gdp_per_minute", 0)),
			"stats": _cash_disclosure_marker(entry, public_audit_cash_by_player, "rank_stats"),
			"income": "全域GDP/min %d" % int(entry.get("gdp_per_minute", 0)),
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
	return {"public_audit_complete": "120秒公开审计完成", "last_survivor": "仅剩一名未淘汰玩家", "planet_destroyed": "星球毁灭结算"}.get(reason_code, "胜利结果已确认") as String


func _public_comparison_order(receipt: Dictionary, has_public_audit_cash: bool) -> String:
	var labels: Array[String] = []
	var cash_label := "准确现金（仅权威审计名单公开）" if has_public_audit_cash else CASH_PRIVACY_COPY
	var order_variant: Variant = receipt.get("comparison_order", [])
	if order_variant is Array:
		for key_variant in order_variant:
			var key := str(key_variant).to_lower()
			var label := ""
			match key:
				"top_n_gdp_per_minute", "top_k_gdp_per_minute", "top_k_gdp_per_minute_cents":
					label = "Top-K个人归属GDP"
				"controlled_region_count":
					label = "控制区域总数"
				"cash", "cash_cents", "cash_ledger_cents", "available", "available_cents", "escrow", "escrow_cents":
					label = cash_label
			if not label.is_empty() and not labels.has(label):
				labels.append(label)
	if labels.is_empty():
		labels = ["Top-K个人归属GDP", "控制区域总数", cash_label]
	elif not labels.has(cash_label):
		labels.append(cash_label)
	return " → ".join(labels)


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


func _public_audit_cash_by_player(source: Dictionary, rank_entries: Array) -> Dictionary:
	if str(source.get("cash_visibility", "")) != "public_audit":
		return {}
	var revealed_variant: Variant = source.get("audit_revealed_player_indices", null)
	if not revealed_variant is Array:
		return {}
	var revealed := {}
	for player_index_variant in revealed_variant:
		if typeof(player_index_variant) == TYPE_INT and int(player_index_variant) >= 0:
			revealed[str(int(player_index_variant))] = true
	if revealed.is_empty():
		return {}
	var result := {}
	var conflicted := {}
	for entry_variant in rank_entries:
		var entry := entry_variant as Dictionary
		var player_index_variant: Variant = entry.get("player_index", null)
		var cash_cents_variant: Variant = entry.get("cash_ledger_cents", null)
		if typeof(player_index_variant) != TYPE_INT or typeof(cash_cents_variant) != TYPE_INT:
			continue
		var player_key := str(int(player_index_variant))
		if not revealed.has(player_key) or conflicted.has(player_key):
			continue
		var cash_cents := int(cash_cents_variant)
		if result.has(player_key) and int(result[player_key]) != cash_cents:
			result.erase(player_key)
			conflicted[player_key] = true
			continue
		result[player_key] = cash_cents
	return result


func _entry_has_public_audit_cash(entry: Dictionary, public_audit_cash_by_player: Dictionary) -> bool:
	var player_index_variant: Variant = entry.get("player_index", null)
	return typeof(player_index_variant) == TYPE_INT and public_audit_cash_by_player.has(str(int(player_index_variant)))


func _cash_disclosure_marker(entry: Dictionary, public_audit_cash_by_player: Dictionary, kind: String) -> Variant:
	if _entry_has_public_audit_cash(entry, public_audit_cash_by_player):
		return {
			"__public_audit_cash_disclosure__": true,
			"player_index": int(entry.get("player_index", -1)),
			"kind": kind,
			"controlled_region_count": int(entry.get("controlled_region_count", 0)),
		}
	match kind:
		"settlement":
			return "控制区域%d｜%s" % [int(entry.get("controlled_region_count", 0)), CASH_PRIVACY_COPY]
		"rank_stats":
			return "控区%d｜%s" % [int(entry.get("controlled_region_count", 0)), CASH_PRIVACY_COPY]
	return CASH_PRIVACY_COPY


func _restore_public_audit_cash_disclosures(value: Variant, public_audit_cash_by_player: Dictionary) -> Variant:
	if value is Dictionary:
		var dictionary := value as Dictionary
		if bool(dictionary.get("__public_audit_cash_disclosure__", false)):
			var player_key := str(int(dictionary.get("player_index", -1)))
			if not public_audit_cash_by_player.has(player_key):
				return CASH_PRIVACY_COPY
			var cash_text := _format_cash_cents(int(public_audit_cash_by_player[player_key]))
			match str(dictionary.get("kind", "")):
				"settlement":
					return "控制区域%d｜准确现金%s（审计公开）" % [int(dictionary.get("controlled_region_count", 0)), cash_text]
				"rank_stats":
					return "控区%d｜准确现金%s（审计公开）" % [int(dictionary.get("controlled_region_count", 0)), cash_text]
			return cash_text
		var restored_dictionary := {}
		for key_variant in dictionary.keys():
			restored_dictionary[key_variant] = _restore_public_audit_cash_disclosures(dictionary[key_variant], public_audit_cash_by_player)
		return restored_dictionary
	if value is Array:
		var restored_array := []
		for item_variant in value:
			restored_array.append(_restore_public_audit_cash_disclosures(item_variant, public_audit_cash_by_player))
		return restored_array
	return value


func _format_cash_cents(cash_cents: int) -> String:
	return "¥%.2f" % (float(cash_cents) / 100.0)


func _sanitize_public_snapshot(snapshot: Dictionary, private_cash_tokens: Array[String], public_audit_cash_by_player: Dictionary) -> Dictionary:
	var sanitized: Variant = _sanitize_public_value(snapshot, private_cash_tokens)
	var restored: Variant = _restore_public_audit_cash_disclosures(sanitized, public_audit_cash_by_player)
	return restored as Dictionary if restored is Dictionary else {}


func _sanitize_public_value(value: Variant, private_cash_tokens: Array[String]) -> Variant:
	if value is Dictionary:
		var sanitized_dictionary := {}
		for key_variant in value.keys():
			var key := str(key_variant)
			if _is_private_cash_key(key):
				continue
			sanitized_dictionary[key_variant] = _sanitize_public_value(value[key_variant], private_cash_tokens)
		return sanitized_dictionary
	if value is Array:
		var sanitized_array := []
		for item_variant in value:
			sanitized_array.append(_sanitize_public_value(item_variant, private_cash_tokens))
		return sanitized_array
	if value is String or value is StringName:
		return _sanitize_public_text(str(value), private_cash_tokens)
	return value


func _sanitize_public_text(value: String, private_cash_tokens: Array[String]) -> String:
	var result := value
	var cash_pattern := RegEx.new()
	if cash_pattern.compile(PRIVATE_CASH_TEXT_PATTERN) == OK:
		result = cash_pattern.sub(result, CASH_PRIVACY_COPY, true)
	for token in private_cash_tokens:
		if token.length() >= 6 or token.contains("."):
			result = result.replace(token, "数值保密")
	return result


func _private_cash_text_tokens(source: Dictionary) -> Array[String]:
	var tokens: Array[String] = []
	_collect_private_cash_text_tokens(source, "", false, tokens)
	tokens.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	return tokens


func _collect_private_cash_text_tokens(value: Variant, key: String, private_context: bool, tokens: Array[String]) -> void:
	var is_private_context := private_context or _is_private_cash_key(key)
	if value is Dictionary:
		for child_key_variant in value.keys():
			var child_key := str(child_key_variant)
			_collect_private_cash_text_tokens(value[child_key_variant], child_key, is_private_context, tokens)
		return
	if value is Array:
		for item_variant in value:
			_collect_private_cash_text_tokens(item_variant, key, is_private_context, tokens)
		return
	if not is_private_context:
		return
	if value is int or value is float:
		_append_unique_token(tokens, str(value))
		if key.to_lower().contains("cent"):
			_append_unique_token(tokens, "%.2f" % (float(value) / 100.0))
		else:
			_append_unique_token(tokens, "%.2f" % float(value))
	elif value is String or value is StringName:
		_append_unique_token(tokens, str(value).strip_edges())


func _append_unique_token(tokens: Array[String], token: String) -> void:
	if not token.is_empty() and not tokens.has(token):
		tokens.append(token)


func _is_private_cash_key(key: String) -> bool:
	var normalized := key.to_lower()
	if PRIVATE_CASH_KEYS.has(normalized):
		return true
	return normalized.begins_with("cash_") or normalized.ends_with("_cash") or normalized.contains("cash_ledger") or normalized.begins_with("available_") or normalized.ends_with("_available") or normalized.begins_with("escrow_") or normalized.ends_with("_escrow")


func _short_text(value: String, limit: int) -> String:
	return value if limit <= 0 or value.length() <= limit else value.substr(0, maxi(0, limit - 1)) + "…"
