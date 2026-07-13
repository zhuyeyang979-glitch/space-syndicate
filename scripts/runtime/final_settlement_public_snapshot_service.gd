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
	var money_entries := _dictionary_array(source.get("money_source_entries", []), 4)
	var rank_entries := _dictionary_array(source.get("rank_entries", []), 8)
	return {
		"summary_text": _summary_text(source),
		"board": _board_snapshot(source, money_entries, rank_entries),
	}


func debug_snapshot() -> Dictionary:
	return {
		"service_ready": _configured,
		"service_authoritative": _configured,
		"supported_domain": "final_settlement_public_presentation",
		"compose_count": _compose_count,
		"calculates_final_score": false,
		"sorts_final_rankings": false,
		"calculates_city_clearance": false,
		"calculates_intel_cash": false,
		"reads_private_hands": false,
		"reads_runtime_nodes": false,
		"bounded_player_input": true,
		"legacy_main_formatter_active": false,
	}


func _empty_snapshot(source: Dictionary) -> Dictionary:
	var reason := str(source.get("reason", "没有可用玩家数据。"))
	return {
		"summary_text": "游戏结束：%s\n没有可用玩家数据。" % reason,
		"board": {
			"title": "终局速览｜赛后记分板",
			"accent": Color("#facc15"),
			"chips": [],
			"kpis": [{"title": "终局速览", "body": "没有可用玩家数据。", "meta": reason, "accent": Color("#facc15")}],
			"money_sources": [],
			"event_lines": [],
			"ranks": [],
			"actions": _after_actions(),
		},
	}


func _summary_text(source: Dictionary) -> String:
	return "\n".join([
		"游戏结束：%s" % str(source.get("reason", "终局结算")),
		"终局总结已整理成赛后板：按胜者、钱源、公开事件、排名轨和赛后入口拆开。",
		"复盘只使用公开/终局结算数据；隐藏手牌、私密推理和电脑对手路线不直接揭示。",
		"接下来可以继续看局势排名或经济总览，也可以直接回到开局准备再打一局。",
	])


func _board_snapshot(source: Dictionary, money_entries: Array, rank_entries: Array) -> Dictionary:
	var map_facts := source.get("map_facts", {}) as Dictionary
	var key_city := map_facts.get("key_city", {}) as Dictionary
	var city_body := "存活城市%d｜已毁区域%d｜怪兽%d/%d" % [int(map_facts.get("active_city_count", 0)), int(map_facts.get("destroyed_district_count", 0)), int(map_facts.get("active_monster_count", 0)), int(map_facts.get("monster_count", 0))]
	if bool(key_city.get("valid", false)):
		city_body = "%s｜%s｜末期GDP¥%d" % [str(key_city.get("name", "关键城市")), str(key_city.get("owner_name", "未知业主")), maxi(0, int(key_city.get("last_income", 0)))]
	return {
		"title": "终局速览｜赛后记分板",
		"title_tooltip": "像桌游电子版的赛后板：先扫最终排名，再决定查经济或再开一桌。",
		"tooltip": "终局复盘板：先看胜者、钱源、地图和关键影响，再打开详细排名或经济总览。",
		"accent": Color("#facc15"),
		"kpi_columns": clampi(int(source.get("kpi_columns", 4)), 1, 4),
		"money_columns": clampi(int(source.get("money_columns", 4)), 1, 4),
		"rank_columns": clampi(int(source.get("rank_columns", 4)), 1, 4),
		"action_columns": 3,
		"chips": [
			{"text": "胜者:%s" % _short_text(str(source.get("winner_name", "玩家")), 10), "accent": Color("#facc15"), "tooltip": "最终结算资金最高者。"},
			{"text": "目标¥%d" % int(source.get("cash_goal", 0)), "accent": Color("#fef3c7"), "tooltip": "本层现金目标。"},
			{"text": "城值¥%d" % int(source.get("city_final_value", 0)), "accent": Color("#4ade80"), "tooltip": "存活城市终局清算价值。"},
		],
		"kpis": [
			{"title": "胜者", "body": "%s｜结算资金¥%d" % [str(source.get("winner_name", "玩家")), int(source.get("winner_score", 0))], "meta": "游戏结束：%s" % str(source.get("reason", "终局结算")), "accent": Color("#facc15")},
			{"title": "钱从哪里来", "body": "城收:%s ¥%d｜卡牌:%s ¥%d｜角色:%s ¥%d" % [str(source.get("top_city_income_name", "玩家")), maxi(0, int(source.get("top_city_income_amount", 0))), str(source.get("top_card_income_name", "玩家")), maxi(0, int(source.get("top_card_income_amount", 0))), str(source.get("top_role_income_name", "玩家")), maxi(0, int(source.get("top_role_income_amount", 0)))], "meta": "情报现金和存活城市清算也进入最终排名。", "accent": Color("#4ade80")},
			{"title": "关键地图", "body": city_body, "meta": "破坏、商路损伤和天气最终都会落到GDP变化。", "accent": Color("#38bdf8")},
			{"title": "关键影响", "body": "%s｜%s" % [_short_text(str(source.get("top_card_impact", "无关键卡牌")).replace("关键卡牌：", ""), 44), _short_text(str(source.get("monster_impact", "无怪兽影响")).replace("怪兽影响：", ""), 44)], "meta": "只复盘公开卡牌、怪兽和地图影响；隐藏身份与私密手牌仍靠推理。", "accent": Color("#c084fc")},
		],
		"money_title": "胜因拆解｜资金来源",
		"money_sources": _money_source_snapshots(money_entries),
		"event_title": "公开事件｜牌轨与地图",
		"event_lines": _event_lines(source, map_facts),
		"rank_title": "排名轨｜结算资金",
		"ranks": _rank_snapshots(rank_entries),
		"action_title": "赛后入口｜查原因或再开一桌",
		"actions": _after_actions(),
	}


func _money_source_snapshots(entries: Array) -> Array:
	var snapshots := []
	for entry_variant: Variant in entries:
		var entry := entry_variant as Dictionary
		var rank := int(entry.get("rank", 0))
		var spend_total := int(entry.get("card_spend", 0)) + int(entry.get("build_spend", 0)) + int(entry.get("business_spend", 0))
		var status := "出局" if bool(entry.get("eliminated", false)) else "在局"
		snapshots.append({
			"title": "#%d %s｜¥%d" % [rank + 1, str(entry.get("name", "玩家")), int(entry.get("score", 0))],
			"start_line": "起手:基础¥%d + 角色%s = ¥%d" % [int(entry.get("base_start_cash", 0)), _signed_int(int(entry.get("role_start_bonus", 0))), int(entry.get("start_cash", 0))],
			"settlement_line": "现金¥%d｜城值¥%d｜情报%s" % [int(entry.get("cash", 0)), int(entry.get("city_clearance", 0)), _signed_int(int(entry.get("intel_cash", 0)))],
			"income_line": "城收¥%d｜卡牌¥%d｜角色¥%d" % [int(entry.get("city_income", 0)), int(entry.get("card_income", 0)), int(entry.get("role_income", 0))],
			"status_line": "支出¥%d｜城%d｜GDP/min %d｜%s" % [spend_total, int(entry.get("active_cities", 0)), int(entry.get("gdp_per_minute", 0)), status],
			"tooltip": "资金来源只使用公开/终局结算数据：基础资金、公开角色加成、现金、存活城市、情报结算和累计收支。",
			"accent": Color("#facc15") if rank == 0 else _seat_accent(int(entry.get("player_index", rank))),
		})
	return snapshots


func _rank_snapshots(entries: Array) -> Array:
	var snapshots := []
	for rank in range(entries.size()):
		var entry := entries[rank] as Dictionary
		snapshots.append({
			"title": "#%d｜%s" % [rank + 1, str(entry.get("name", "玩家"))],
			"score": "¥%d" % int(entry.get("score", 0)),
			"stats": "现金¥%d｜城%d｜GDP/min %d" % [int(entry.get("cash", 0)), int(entry.get("active_cities", 0)), int(entry.get("gdp_per_minute", 0))],
			"income": "城收¥%d｜卡牌¥%d｜情报%s" % [maxi(0, int(entry.get("city_income", 0))), maxi(0, int(entry.get("card_income", 0))), _signed_int(int(entry.get("intel_cash", 0)))],
			"identity": str(entry.get("identity", "公开角色与主要收入路线")),
			"tooltip": "终局排名：现金 + 存活城市清算 + 情报现金。",
			"accent": Color("#facc15") if rank == 0 else _seat_accent(int(entry.get("player_index", rank))),
		})
	return snapshots


func _event_lines(source: Dictionary, map_facts: Dictionary) -> Array:
	var lines := []
	var top_card := str(source.get("top_card_impact", "")).strip_edges()
	if top_card != "":
		lines.append(top_card)
	var monster := str(source.get("monster_impact", "")).strip_edges()
	if monster != "":
		lines.append(monster)
	var key_city := map_facts.get("key_city", {}) as Dictionary
	if bool(key_city.get("valid", false)):
		lines.append("关键城市：%s｜%s｜末期GDP¥%d。" % [str(key_city.get("name", "未知区域")), str(key_city.get("owner_name", "未知业主")), maxi(0, int(key_city.get("last_income", 0)))])
	lines.append("地图结局：存活城市%d座｜已毁区域%d个｜怪兽在场%d/%d。" % [int(map_facts.get("active_city_count", 0)), int(map_facts.get("destroyed_district_count", 0)), int(map_facts.get("active_monster_count", 0)), int(map_facts.get("monster_count", 0))])
	var resolved_count := int(source.get("resolved_card_count", 0))
	if resolved_count > 0:
		lines.append("牌轨记录：已结算%d张匿名牌；可在历史牌轨继续回看与猜归属。" % resolved_count)
	if lines.is_empty():
		lines.append("本局没有可复盘的公开事件。")
	return lines.slice(0, mini(5, lines.size()))


func _after_actions() -> Array:
	return [
		{"id": "standings", "title": "查看局势排名", "body": "逐席查看结算资金、现金/城市/情报拆解和终局玩家概览。", "accent": Color("#facc15")},
		{"id": "economy", "title": "打开经济总览", "body": "复查商品热榜、商路收入前景、城市 GDP 拆解和经济流水。", "accent": Color("#4ade80")},
		{"id": "new_run", "title": "开局准备", "body": "重新选择席位、电脑对手、挑战层级和外星角色，开始下一局。", "accent": Color("#67e8f9")},
	]


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


func _signed_int(value: int) -> String:
	return "+%d" % value if value > 0 else "%d" % value


func _short_text(value: String, limit: int) -> String:
	if limit <= 0 or value.length() <= limit:
		return value
	return value.substr(0, maxi(0, limit - 1)) + "…"
