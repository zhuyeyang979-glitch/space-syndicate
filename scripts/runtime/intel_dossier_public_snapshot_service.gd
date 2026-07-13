@tool
extends Node
class_name IntelDossierPublicSnapshotService

const MAX_CITY_ENTRIES := 8
const MAX_CARD_ENTRIES := 8
const MAX_CLUE_ENTRIES := 8
const MAX_CONTROL_CITIES := 2
const MAX_LINKS := 10

var _configured := false
var _compose_count := 0


func configure(_config: Dictionary = {}) -> void:
	_configured = true


func compose(source: Dictionary) -> Dictionary:
	_compose_count += 1
	if not bool(source.get("valid", false)):
		return _empty_snapshot(str(source.get("reason", "暂无当前局情报")))
	var city_entries := _dictionary_array(source.get("city_entries", []), MAX_CITY_ENTRIES)
	var card_entries := _dictionary_array(source.get("card_entries", []), MAX_CARD_ENTRIES)
	var monster_entries := _dictionary_array(source.get("monster_entries", []), MAX_CLUE_ENTRIES)
	var warehouse_entries := _dictionary_array(source.get("warehouse_entries", []), MAX_CLUE_ENTRIES)
	var city_clue_entries := _dictionary_array(source.get("city_clue_entries", []), MAX_CLUE_ENTRIES)
	var focused_card := _focused_card(card_entries)
	var controls := _control_groups(source, city_entries)
	var links := _link_actions(city_entries, card_entries, monster_entries, city_clue_entries)
	return {
		"summary_text": _summary_text(source, city_entries, card_entries, monster_entries, warehouse_entries, city_clue_entries),
		"board": _board_snapshot(source, city_entries, card_entries, monster_entries, warehouse_entries, city_clue_entries, focused_card, controls, links),
	}


func debug_snapshot() -> Dictionary:
	return {
		"service_ready": _configured,
		"service_authoritative": _configured,
		"supported_domain": "intel_dossier_public_presentation_and_action_intents",
		"compose_count": _compose_count,
		"mutates_city_guesses": false,
		"settles_intel_cash": false,
		"reveals_city_owner_truth": false,
		"reveals_card_owner_truth": false,
		"reads_private_hands": false,
		"navigates_runtime_nodes": false,
		"emits_callable_controls": false,
		"action_id_controls": true,
		"bounded_input_lists": true,
		"legacy_main_formatter_active": false,
	}


func _empty_snapshot(reason: String) -> Dictionary:
	var safe_reason := reason if reason.strip_edges() != "" else "暂无当前局情报"
	return {
		"summary_text": "还没有当前局情报。%s；开始新局并城市化、出牌、竞猜或制造怪兽冲突后再查看。" % safe_reason,
		"board": {
			"title": "情报侦探板",
			"accent": Color("#c084fc"),
			"chips": [],
			"kpis": [],
			"actions": [],
			"clues": [{"title": "暂无情报", "lines": [safe_reason], "accent": Color("#94a3b8")}],
			"control_groups": [],
			"links": [{"id": "intel_open_economy", "label": "打开经济总览", "accent": Color("#4ade80"), "tooltip": "查看公开经济事实。"}],
		},
	}


func _board_snapshot(source: Dictionary, city_entries: Array, card_entries: Array, monster_entries: Array, warehouse_entries: Array, city_clue_entries: Array, focused_card: Dictionary, controls: Array, links: Array) -> Dictionary:
	var chips := [
		{"text": "终局揭晓", "accent": Color("#fef3c7"), "tooltip": "城市业主标注只在终局结算正误。"},
		{"text": "即时竞猜¥%d" % int(source.get("card_guess_stake", 0)), "accent": Color("#c4b5fd"), "tooltip": "卡牌归属竞猜猜中后才公开该牌牌主标签。"},
		{"text": "不看对手现金", "accent": Color("#94a3b8"), "tooltip": "情报页只整理公开证据和当前玩家自己的推理。"},
	]
	if not focused_card.is_empty():
		chips.push_front({
			"text": "已选牌轨:%s" % _short_text(str(focused_card.get("card", "匿名牌")), 8),
			"accent": Color("#f472b6"),
			"tooltip": "从公开牌轨带入的当前匿名牌。",
		})
	var clues: Array = []
	if not focused_card.is_empty():
		clues.append(_focused_evidence_card(focused_card))
	clues.append_array([
		{"title": "城市嫌疑", "lines": _city_lines(city_entries), "accent": Color("#38bdf8"), "tooltip": "优先标注高GDP、低置信、仓储或有公开线索的城市。"},
		{"title": "匿名牌轨", "lines": _card_lines(card_entries), "accent": Color("#f472b6"), "tooltip": "看匿名牌条件、目标和公开报价，再决定是否竞猜。"},
		{"title": "怪兽资金", "lines": _monster_lines(monster_entries), "accent": Color("#fb7185"), "tooltip": "怪兽受伤形成公开资金压力线索。"},
		{"title": "仓储/做空靶标", "lines": _warehouse_lines(warehouse_entries), "accent": Color("#fb923c"), "tooltip": "匿名仓储会把期货收益绑定到可被攻击的城市。"},
		{"title": "城市公开线索", "lines": _public_city_lines(city_clue_entries), "accent": Color("#4ade80"), "tooltip": "合约、经营改造、供需变化和新闻留下的公开线索。"},
		{"title": "下一步查证", "lines": ["先标：高GDP、仓储、低置信城市。", "再查：匿名牌条件、目标和报价。", "验证：怪兽资金损失与商品受益方。", "兑现：终局城市标注，牌轨即时竞猜。"], "accent": Color("#a78bfa"), "tooltip": "从公开证据到私人判断的推荐顺序。"},
	])
	return {
		"title": "情报侦探板",
		"title_tooltip": "先扫线索类别，再标注城市或跳到公开资料查证。",
		"tooltip": "场景化情报板：展示公开证据和当前玩家自己的推理，不读取隐藏真相。",
		"accent": Color("#c084fc"),
		"kpi_columns": clampi(int(source.get("kpi_columns", 4)), 1, 4),
		"clue_columns": clampi(int(source.get("clue_columns", 3)), 1, 3),
		"control_columns": clampi(int(source.get("control_columns", 1)), 1, 2),
		"link_columns": clampi(int(source.get("link_columns", 2)), 1, 3),
		"chips": chips,
		"kpis": _kpis(source, card_entries, monster_entries, warehouse_entries),
		"actions": _focused_actions(focused_card),
		"clues": clues,
		"control_title": "私人推理控制｜只修改当前玩家自己的标注",
		"control_groups": controls,
		"link_title": "公开资料跳转｜只打开可见线索",
		"links": links,
	}


func _summary_text(source: Dictionary, city_entries: Array, card_entries: Array, monster_entries: Array, warehouse_entries: Array, city_clue_entries: Array) -> String:
	var stats := source.get("stats", {}) as Dictionary if source.get("stats", {}) is Dictionary else {}
	var city_lines := _city_detail_lines(city_entries)
	var card_lines := _card_detail_lines(card_entries)
	var monster_lines := _monster_lines(monster_entries)
	var warehouse_lines := _warehouse_lines(warehouse_entries)
	var public_city_lines := _public_city_lines(city_clue_entries)
	return "\n".join([
		"情报档案",
		"城市标注、匿名牌轨、怪兽资金和仓储风险集中管理；当前玩家：%s｜刷新%d｜当前不揭示正误，不扫描对手现金/手牌。" % [str(source.get("viewer_name", "无当前玩家")), int(source.get("business_cycle_count", 0))],
		"情报换钱｜城市私标只在终局范围结算：猜对+¥%d，猜错-¥%d；卡牌归属押注¥%d，猜中才公开牌主。" % [int(source.get("correct_guess_cash", 0)), int(source.get("wrong_guess_cost", 0)), int(source.get("card_guess_stake", 0))],
		"城市业主情报｜终局范围｜%s" % _joined_or(city_lines, "暂无陌生城市；先城市化或观察公开线索。"),
		"卡牌归属档案｜押注｜%s" % _joined_or(card_lines, "暂无可押注匿名牌。"),
		"怪兽资金档案｜受伤按最大生命比例掉钱并形成公开线索｜%s" % _joined_or(monster_lines, "暂无怪兽受伤资金线索。"),
		"仓储风险线索｜匿名仓储会暴露可被做空、齐射、驻军或引怪的城市压力｜%s" % _joined_or(warehouse_lines, "暂无仓储风险线索。"),
		"城市公开线索档案｜类型、商品和收入变化可辅助城市业主判断｜%s" % _joined_or(public_city_lines, "暂无城市公开线索。"),
		"调查优先级｜优先级越高越值得先标注；先看高GDP、仓储风险、怪兽冲突和匿名牌轨。",
		"置信分布：高%d / 中%d / 低%d｜理由分布：%s｜胜利由区域控制、Top-N归属GDP和公开审计决定；情报不会建立第二套终局分数。" % [_confidence_count(city_entries, 3), _confidence_count(city_entries, 2), _confidence_count(city_entries, 1), _reason_summary(city_entries, source.get("reason_options", []) as Array if source.get("reason_options", []) is Array else [])],
		"城市标注：%d/%d｜待查%d｜全对%s｜全错%s" % [int(stats.get("guessed", 0)), int(stats.get("total_foreign", 0)), int(stats.get("unmarked", 0)), _signed_int(int(stats.get("best_cash", 0))), _signed_int(int(stats.get("worst_cash", 0)))],
	])


func _kpis(source: Dictionary, card_entries: Array, monster_entries: Array, warehouse_entries: Array) -> Array:
	var stats := source.get("stats", {}) as Dictionary if source.get("stats", {}) is Dictionary else {}
	return [
		{"title": "城市标注", "value": "%d/%d" % [int(stats.get("guessed", 0)), int(stats.get("total_foreign", 0))], "meta": "全对%s｜全错%s" % [_signed_int(int(stats.get("best_cash", 0))), _signed_int(int(stats.get("worst_cash", 0)))], "accent": Color("#38bdf8"), "tooltip": "陌生城市业主标注只在终局结算。"},
		{"title": "待查城市", "value": "%d" % int(stats.get("unmarked", 0)), "meta": "优先看高GDP/仓储/断路", "accent": Color("#facc15"), "tooltip": "未标注、高价值或有公开线索的城市更值得查。"},
		{"title": "待猜牌", "value": "%d" % card_entries.size(), "meta": "牌轨归属/条件", "accent": Color("#f472b6"), "tooltip": "卡牌可通过商品门槛、目标、报价和结果反推。"},
		{"title": "公开资金线索", "value": "%d" % monster_entries.size(), "meta": "怪兽受伤/仓储风险%d" % warehouse_entries.size(), "accent": Color("#fb7185"), "tooltip": "怪兽资金损失和仓储城市会暴露经济压力。"},
	]


func _focused_actions(entry: Dictionary) -> Array:
	if entry.is_empty():
		return []
	var resolution_id := int(entry.get("resolution_id", -1))
	if resolution_id < 0:
		return []
	var actions: Array = [
		{"id": "track_return_%d" % resolution_id, "label": "回到牌轨", "accent": Color("#38bdf8"), "tooltip": "关闭情报档案并保持这张牌为已选牌轨。"},
		{"id": "track_guess_%d" % resolution_id, "label": "竞猜", "accent": Color("#c084fc"), "tooltip": "回到主桌的归属竞猜面板。"},
	]
	var card_name := str(entry.get("card_name", "")).strip_edges()
	if card_name != "":
		actions.append({"id": "track_open_%s" % card_name, "label": "卡牌详情", "accent": Color("#f472b6"), "tooltip": "打开对应卡牌详情。"})
	return actions


func _control_groups(source: Dictionary, city_entries: Array) -> Array:
	var ordered := []
	for entry_variant in city_entries:
		if bool((entry_variant as Dictionary).get("marked", false)):
			ordered.append(entry_variant)
	for entry_variant in city_entries:
		if not bool((entry_variant as Dictionary).get("marked", false)):
			ordered.append(entry_variant)
	var player_options := _dictionary_array(source.get("player_options", []), 8)
	var confidence_options := _dictionary_array(source.get("confidence_options", []), 3)
	var reason_options := _dictionary_array(source.get("reason_options", []), 8)
	var groups: Array = []
	for entry_variant in ordered.slice(0, mini(MAX_CONTROL_CITIES, ordered.size())):
		var entry := entry_variant as Dictionary
		var district_index := int(entry.get("district_index", -1))
		if district_index < 0:
			continue
		var city_name := str(entry.get("name", "城市"))
		var actions: Array = []
		for option_variant in player_options:
			var option := option_variant as Dictionary
			var player_index := int(option.get("player_index", -1))
			if player_index >= 0:
				actions.append({"id": "intel_city_mark_%d_%d" % [district_index, player_index], "label": str(option.get("label", "标玩家%d" % (player_index + 1))), "accent": Color("#38bdf8"), "tooltip": "把%s私密标注为该玩家的城市；终局才结算正误。" % city_name})
		if bool(entry.get("marked", false)):
			for option_variant in confidence_options:
				var option := option_variant as Dictionary
				var value := int(option.get("value", 0))
				if value > 0:
					actions.append({"id": "intel_city_confidence_%d_%d" % [district_index, value], "label": "置信:%s" % str(option.get("label", value)), "accent": Color("#7dd3fc"), "tooltip": "只调整当前玩家自己的推理置信度。"})
			for option_variant in reason_options:
				var option := option_variant as Dictionary
				var reason_id := str(option.get("id", "")).strip_edges()
				if reason_id != "":
					actions.append({"id": "intel_city_reason_%d_%s" % [district_index, reason_id], "label": str(option.get("label", reason_id)), "accent": Color("#4ade80"), "tooltip": "记录当前玩家自己的推理理由；不验证正误。"})
		actions.append({"id": "intel_city_clear_%d" % district_index, "label": "清除", "accent": Color("#94a3b8"), "tooltip": "清除当前玩家对%s的私人城市归属标注。" % city_name})
		groups.append({
			"id": "city_%d" % district_index,
			"title": "标注城市：%s" % city_name,
			"meta": "优先%d｜%s｜%s" % [int(entry.get("priority", 0)), _guess_label(entry), _short_text(str(entry.get("latest_clue", "暂无公开线索")), 32)],
			"accent": Color("#38bdf8") if not bool(entry.get("marked", false)) else Color("#c084fc"),
			"actions": actions,
		})
	return groups


func _link_actions(city_entries: Array, card_entries: Array, monster_entries: Array, city_clue_entries: Array) -> Array:
	var links: Array = []
	for entry_variant in city_entries.slice(0, mini(2, city_entries.size())):
		var entry := entry_variant as Dictionary
		var district_index := int(entry.get("district_index", -1))
		if district_index >= 0:
			links.append({"id": "intel_open_region_%d" % district_index, "label": "查看区域线索：%s" % str(entry.get("name", "城市")), "accent": Color("#38bdf8"), "tooltip": "查看公开供需、收入拆解和城市线索。"})
	for entry_variant in card_entries.slice(0, mini(2, card_entries.size())):
		var entry := entry_variant as Dictionary
		var card_name := str(entry.get("card_name", "")).strip_edges()
		if card_name != "":
			links.append({"id": "intel_open_card_%s" % card_name, "label": "%s：%s" % ["查看卡牌线索｜已选牌轨" if bool(entry.get("focused", false)) else "查看卡牌线索", str(entry.get("card", card_name))], "accent": Color("#f472b6"), "tooltip": "查看该匿名卡的公开目标、条件、价格带和结算演出。"})
	for entry_variant in monster_entries.slice(0, mini(2, monster_entries.size())):
		var entry := entry_variant as Dictionary
		var catalog_index := int(entry.get("catalog_index", -1))
		if catalog_index >= 0:
			links.append({"id": "intel_open_monster_%d" % catalog_index, "label": "查看怪兽线索：怪%d·%s" % [int(entry.get("slot", 0)) + 1, str(entry.get("name", "怪兽"))], "accent": Color("#fb7185"), "tooltip": "查看怪兽行动概率、资源偏好和伤害数据。"})
	var linked_products := {}
	for entry_variant in city_clue_entries:
		var product_name := str((entry_variant as Dictionary).get("linked_product", "")).strip_edges()
		if product_name != "" and not linked_products.has(product_name):
			linked_products[product_name] = true
			links.append({"id": "intel_open_product_%s" % product_name, "label": "查看商品线索：%s" % product_name, "accent": Color("#4ade80"), "tooltip": "查看商品价格、供需、商路断损和相关城市线索。"})
			if linked_products.size() >= 2:
				break
	links.append({"id": "intel_open_economy", "label": "打开经济总览", "accent": Color("#facc15"), "tooltip": "查看商品热榜、商路收入前景和当前玩家经济流水。"})
	return links.slice(0, mini(MAX_LINKS, links.size()))


func _focused_card(entries: Array) -> Dictionary:
	for entry_variant in entries:
		if bool((entry_variant as Dictionary).get("focused", false)):
			return (entry_variant as Dictionary).duplicate(true)
	return {}


func _focused_evidence_card(entry: Dictionary) -> Dictionary:
	var resolution_id := int(entry.get("resolution_id", -1))
	var tip := str(entry.get("tip", "")).strip_edges()
	var aftermath := str(entry.get("aftermath", "")).strip_edges()
	return {
		"title": "已选牌轨证据链",
		"lines": [
			"牌槽证据｜%s｜%s｜%s｜%s" % ["#%d" % resolution_id if resolution_id >= 0 else "#?", str(entry.get("track_state", "牌轨")), str(entry.get("card", "匿名卡")), _short_text(str(entry.get("status", "归属待猜")), 22)],
			"出牌条件｜%s" % str(entry.get("requirement", "条件未知")),
			"目标线索｜%s" % str(entry.get("target", "目标未知")),
			"出价记录｜%s" % (tip if tip != "" else "暂无公开报价/小费线索。"),
			"余波线索｜%s｜%s｜%s" % [str(entry.get("style", "卡牌")), _time_text(float(entry.get("time", -1.0))), aftermath if aftermath != "" else "尚未留下结算余波。"],
			"私人推理｜%s" % _private_note(entry),
		],
		"accent": Color("#f472b6"),
		"tooltip": "只整理该牌公开状态和当前玩家自己的推理。",
		"line_limit": 6,
	}


func _city_lines(entries: Array) -> Array:
	var lines := []
	for entry_variant in entries.slice(0, mini(4, entries.size())):
		var entry := entry_variant as Dictionary
		lines.append("%s｜优先%d｜%s｜GDP%d｜%s" % [str(entry.get("name", "城市")), int(entry.get("priority", 0)), _guess_label(entry), int(entry.get("potential_income", 0)), _short_text(str(entry.get("latest_clue", "暂无公开线索")), 18)])
	if lines.is_empty(): lines.append("暂无陌生存活城市。")
	return lines


func _card_lines(entries: Array) -> Array:
	var lines := []
	for entry_variant in entries.slice(0, mini(4, entries.size())):
		var entry := entry_variant as Dictionary
		var secondary := str(entry.get("tip", "")).strip_edges()
		if secondary == "": secondary = str(entry.get("target", "目标未知"))
		lines.append("%s%s｜%s｜%s｜%s" % ["已选牌轨｜" if bool(entry.get("focused", false)) else "", str(entry.get("card", "匿名卡")), _short_text(str(entry.get("status", "归属待猜")), 18), _short_text(str(entry.get("requirement", "条件未知")), 18), _short_text(secondary, 18)])
	if lines.is_empty(): lines.append("暂无待猜牌轨记录。")
	return lines


func _monster_lines(entries: Array) -> Array:
	var lines := []
	for entry_variant in entries.slice(0, mini(4, entries.size())):
		var entry := entry_variant as Dictionary
		lines.append("怪%d·%s｜%s｜最近损失¥%d｜累计¥%d｜资金池¥%d/%d｜%s" % [int(entry.get("slot", 0)) + 1, str(entry.get("name", "怪兽")), str(entry.get("owner_text", "归属未公开")), int(entry.get("recent_loss", 0)), int(entry.get("total_lost", 0)), int(entry.get("cash_pool", 0)), int(entry.get("cash_total", 0)), str(entry.get("clue", "暂无公开资金线索"))])
	return lines


func _warehouse_lines(entries: Array) -> Array:
	var lines := []
	for entry_variant in entries.slice(0, mini(4, entries.size())):
		var entry := entry_variant as Dictionary
		lines.append("%s｜%s｜仓储风险%d｜%d笔/%d单位｜商品:%s｜反制:做空/齐射/军队/引怪｜线索:%s" % [str(entry.get("name", "仓储城市")), str(entry.get("owner_view", "业主未知")), int(entry.get("pressure", 0)), int(entry.get("count", 0)), int(entry.get("units", 0)), _name_list(entry.get("products", []) as Array, 3, "未知商品"), str(entry.get("latest_clue", "暂无公开线索"))])
	return lines


func _public_city_lines(entries: Array) -> Array:
	var lines := []
	for entry_variant in entries.slice(0, mini(4, entries.size())):
		var entry := entry_variant as Dictionary
		lines.append("%s｜%s｜类型:%s｜线索商品:%s｜收入%d｜线索:%s" % [str(entry.get("district", "城市")), "己方城市" if bool(entry.get("owner_visible", false)) else "业主未知", str(entry.get("kind", "公开")), _name_list(entry.get("clue_products", []) as Array, 3, "无"), int(entry.get("income", 0)), str(entry.get("clue", ""))])
	return lines


func _city_detail_lines(entries: Array) -> Array:
	var lines := []
	for entry_variant in entries.slice(0, mini(4, entries.size())):
		var entry := entry_variant as Dictionary
		lines.append("%s｜优先级%d｜%s｜置信:%s｜理由:%s｜潜在GDP%d｜仓储风险%d｜最近线索:%s" % [str(entry.get("name", "城市")), int(entry.get("priority", 0)), _guess_label(entry), str(entry.get("confidence_label", "无")), str(entry.get("reason_label", "无")), int(entry.get("potential_income", 0)), int(entry.get("warehouse_pressure", 0)), str(entry.get("latest_clue", "暂无公开线索"))])
	return lines


func _card_detail_lines(entries: Array) -> Array:
	var lines := []
	for entry_variant in entries.slice(0, mini(4, entries.size())):
		var entry := entry_variant as Dictionary
		var tip := str(entry.get("tip", "")).strip_edges()
		lines.append("%s｜%s｜条件:%s｜目标:%s%s" % [str(entry.get("card", "匿名卡牌")), str(entry.get("status", "归属待猜")), str(entry.get("requirement", "未知")), str(entry.get("target", "目标未知")), "｜小费线索:%s" % tip if tip != "" else ""])
	return lines


func _guess_label(entry: Dictionary) -> String:
	var guess := int(entry.get("guess", -1))
	if guess < 0: return "未标注"
	return "标P%d/%s" % [guess + 1, str(entry.get("confidence_label", "中"))]


func _confidence_count(entries: Array, value: int) -> int:
	var count := 0
	for entry_variant in entries:
		var entry := entry_variant as Dictionary
		if bool(entry.get("marked", false)) and int(entry.get("confidence", 0)) == value: count += 1
	return count


func _reason_summary(entries: Array, options: Array) -> String:
	var counts := {}
	for entry_variant in entries:
		var entry := entry_variant as Dictionary
		if bool(entry.get("marked", false)):
			var reason_id := str(entry.get("reason", ""))
			counts[reason_id] = int(counts.get(reason_id, 0)) + 1
	var pieces := []
	for option_variant in options:
		var option := option_variant as Dictionary
		var reason_id := str(option.get("id", ""))
		var count := int(counts.get(reason_id, 0))
		if count > 0: pieces.append("%s%d" % [str(option.get("label", reason_id)), count])
	return " / ".join(pieces) if not pieces.is_empty() else "暂无"


func _private_note(entry: Dictionary) -> String:
	var status := str(entry.get("status", "归属待猜"))
	if status.contains("我已查明") or status.contains("我已押注") or status.contains("我打出的牌"):
		return "%s；仅当前玩家视角可见。" % status
	if bool(entry.get("revealed", false)):
		return "归属已经通过竞猜公开；可继续复盘余波和目标。"
	return "尚未押注或查明；结合条件、目标、报价和地图余波决定是否竞猜。"


func _time_text(value: float) -> String:
	return "时间未知" if value < 0.0 else "T+%.1fs" % value


func _dictionary_array(value: Variant, limit: int) -> Array:
	var result: Array = []
	if not (value is Array): return result
	for entry_variant in value:
		if entry_variant is Dictionary:
			result.append((entry_variant as Dictionary).duplicate(true))
			if result.size() >= limit: break
	return result


func _joined_or(lines: Array, fallback: String) -> String:
	return fallback if lines.is_empty() else "；".join(lines)


func _name_list(values: Array, limit: int, fallback: String) -> String:
	var names := []
	for value in values.slice(0, mini(limit, values.size())):
		if str(value).strip_edges() != "": names.append(str(value))
	return fallback if names.is_empty() else "/".join(names)


func _signed_int(value: int) -> String:
	return "+¥%d" % value if value >= 0 else "-¥%d" % abs(value)


func _short_text(value: String, limit: int) -> String:
	if limit <= 0 or value.length() <= limit: return value
	return value.substr(0, maxi(0, limit - 1)) + "…"
