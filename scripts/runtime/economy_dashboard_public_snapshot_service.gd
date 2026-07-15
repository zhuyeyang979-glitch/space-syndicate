@tool
extends Node
class_name EconomyDashboardPublicSnapshotService

var _configured := false
var _compose_count := 0


func configure(_config: Dictionary = {}) -> void:
	_configured = true


func compose(source: Dictionary) -> Dictionary:
	_compose_count += 1
	if not bool(source.get("valid", false)):
		return _empty_snapshot()
	var products := _dictionary_array(source.get("product_entries", []), 64)
	var cold_products := products.duplicate(true)
	cold_products.sort_custom(Callable(self, "_sort_cold_product"))
	var cities := _dictionary_array(source.get("city_entries", []), 64)
	var aftermath := _dictionary_array(source.get("card_aftermath_entries", []), 8)
	var city_clues := _dictionary_array(source.get("city_clue_entries", []), 8)
	var monster_clues := _dictionary_array(source.get("monster_clue_entries", []), 8)
	var warehouses := _dictionary_array(source.get("warehouse_entries", []), 8)
	var cash_entries := _dictionary_array(source.get("player_cash_entries", []), 8)
	var inference_lines := _string_array(source.get("inference_lines", []), 12)
	var public_summary := _public_situation_summary(source, aftermath, city_clues, monster_clues, warehouses)
	return {
		"summary_text": _summary_text(source, products, cold_products, cities, aftermath, city_clues, monster_clues, warehouses, cash_entries, inference_lines, public_summary),
		"overview_cards": _overview_cards(public_summary),
		"dashboard": _dashboard_snapshot(source, products, cold_products, cities, aftermath, monster_clues, warehouses, public_summary),
	}


func debug_snapshot() -> Dictionary:
	return {
		"service_ready": _configured,
		"service_authoritative": _configured,
		"supported_domain": "economy_dashboard_public_presentation",
		"compose_count": _compose_count,
		"calculates_product_prices": false,
		"calculates_city_income": false,
		"calculates_cashflow": false,
		"evaluates_private_truth": false,
		"reads_runtime_nodes": false,
		"bounded_input_lists": true,
		"legacy_main_formatter_active": false,
	}


func _empty_snapshot() -> Dictionary:
	return {
		"summary_text": "还没有当前局经济数据。开始新局并建城后，这里会显示GDP、商品、商路和公开线索。",
		"overview_cards": [
			{"title": "暂无经济数据", "body": "开始新局并建造城市后，这里会显示GDP、商品、商路和线索摘要。", "accent": Color("#38bdf8"), "tooltip": "经济事实尚未初始化。"},
		],
		"dashboard": {
			"title": "经济仪表板",
			"accent": Color("#4ade80"),
			"chips": [],
			"kpis": [],
			"decisions": [],
			"lanes": [],
		},
	}


func _dashboard_snapshot(source: Dictionary, products: Array, cold_products: Array, cities: Array, aftermath: Array, monster_clues: Array, warehouses: Array, public_summary: String) -> Dictionary:
	var selected_name := str(source.get("selected_name", "当前玩家"))
	var clue_count := int(source.get("clue_count", 0))
	return {
		"title": "经济仪表板",
		"title_tooltip": "先看现金流、商品、城市、线索四块；细节用悬停查看。",
		"tooltip": "经济仪表板：看三件事：钱从哪座城来、哪种商品变热、公开线索指向哪里。",
		"accent": Color("#4ade80"),
		"kpi_columns": clampi(int(source.get("kpi_columns", 4)), 1, 4),
		"lane_columns": clampi(int(source.get("lane_columns", 3)), 1, 3),
		"overview_columns": clampi(int(source.get("overview_columns", 4)), 1, 4),
		"overview_cards": _overview_cards(public_summary),
		"chips": [
			{"text": "刷新%d" % int(source.get("business_cycle_count", 0)), "accent": Color("#86efac"), "tooltip": "公开供需、天气和市场类信息按全局刷新节奏更新。"},
			{"text": "怪兽%d" % int(source.get("monster_count", 0)), "accent": Color("#fb7185"), "tooltip": "怪兽落点会影响购牌来源、破坏、赌局和资源吸引。"},
			{"text": _short_text(str(source.get("weather_text", "天气稳定")), 14), "accent": Color("#38bdf8"), "tooltip": "天气会影响受波及区域的生产、交通和消费。"},
		],
		"kpis": [
			{"title": "GDP/min", "value": "%d" % int(source.get("selected_gdp_per_minute", 0)), "meta": selected_name, "accent": Color("#4ade80"), "tooltip": "当前玩家可见城市现金流，按秒进入现金。"},
			{"title": "商品热度", "value": _top_product_value(products), "meta": "价格/供需/趋势", "accent": Color("#facc15"), "tooltip": "供给压价；需求、合约和天气可能抬价。"},
			{"title": "城市前景", "value": _top_city_value(cities), "meta": "收入/断路/业主视角", "accent": Color("#38bdf8"), "tooltip": "城市GDP受生产、需求、交通、损伤、竞争和商路影响。"},
			{"title": "公开线索", "value": "%d" % clue_count, "meta": "卡牌/城市/怪兽", "accent": Color("#c084fc"), "tooltip": "只汇总公开证据，不揭示隐藏现金、手牌或真实业主。"},
		],
		"decisions": _decision_cards(products, cities, clue_count),
		"lanes": [
			{"title": "商品热榜", "lines": _compact_product_lines(products, false), "accent": Color("#facc15"), "tooltip": "哪些商品正在变贵、变热或被需求拉动。"},
			{"title": "低价机会", "lines": _compact_product_lines(cold_products, true), "accent": Color("#93c5fd"), "tooltip": "供给过剩或价格受压的商品，适合买低、改需求或布局期货。"},
			{"title": "城市现金流", "lines": _compact_city_lines(cities), "accent": Color("#4ade80"), "tooltip": "可见城市收入前景；真实业主仍按情报规则隐藏。"},
			{"title": "匿名余波", "lines": _card_aftermath_lines(aftermath, 4), "accent": Color("#f472b6"), "tooltip": "匿名出牌后的公开结果，是猜牌主和经济反推的素材。"},
			{"title": "怪兽/仓储风险", "lines": _risk_lines(monster_clues, warehouses), "accent": Color("#fb7185"), "tooltip": "怪兽资金损失、仓储靶标和可被做空的经济点。"},
			{"title": "下一步读法", "lines": ["热商品：扩需求、保运输、买涨。", "高GDP城：保护、保险、修商路。", "可疑异动：对照牌轨、天气、怪兽落点。", "落后时：做空、断路、引怪兽压领先城。"], "accent": Color("#a78bfa"), "tooltip": "先看热商品，再看高GDP城市，最后用牌轨和地图结果找匿名线索。"},
		],
	}


func _overview_cards(public_summary: String) -> Array:
	var summary := public_summary
	if summary == "":
		summary = "公开异动：暂无明显场面结果；继续观察商品价格、城市GDP、怪兽落点和匿名卡牌轨道。"
	return [
		{"title": "经济速览", "body": "GDP/min按秒进钱；城市受商品、商路、天气、合约和破坏影响。", "accent": Color("#4ade80"), "tooltip": "先看现金流。"},
		{"title": "商品热榜", "body": "高价商品适合扩需求或做多；低价/供给压制适合买低、转产或做空。", "accent": Color("#facc15"), "tooltip": "供需决定价格。"},
		{"title": "公开异动", "body": summary, "accent": Color("#f472b6"), "tooltip": "只显示场面结果。"},
		{"title": "匿名线索", "body": "牌轨条件、怪兽受伤、城市GDP跳变、合约签拒和仓储暴露都可反推身份。", "accent": Color("#c084fc"), "tooltip": "不揭示隐藏真相。"},
	]


func _decision_cards(products: Array, cities: Array, clue_count: int) -> Array:
	var top_product := "热商品"
	if not products.is_empty():
		top_product = _short_text(str((products[0] as Dictionary).get("name", top_product)), 8)
	var top_city := "高GDP城"
	if not cities.is_empty():
		top_city = _short_text(str((cities[0] as Dictionary).get("name", top_city)), 7)
	var clue_text := "%d条公开线索" % clue_count if clue_count > 0 else "牌轨/地图"
	return [
		{"title": "扩GDP", "body": "围绕%s补生产/需求/交通。" % top_product, "keyword": "建城｜产业｜合约", "accent": Color("#4ade80"), "tooltip": "赚钱路线：让一个商品从生产、需求、交通三端流起来，GDP才会按秒变成钱。"},
		{"title": "护商路", "body": "保护%s，修断路或买保险。" % top_city, "keyword": "修复｜保险｜防卫", "accent": Color("#38bdf8"), "tooltip": "防守路线：高收入城市和运输节点被破坏后，GDP会下滑；先保住现金流。"},
		{"title": "压竞争", "body": "用%s找目标，做空或引怪。" % clue_text, "keyword": "情报｜做空｜怪兽", "accent": Color("#f472b6"), "tooltip": "进攻路线：只根据公开牌轨、城市变化、怪兽落点和商品条件反推，不显示隐藏业主。"},
	]


func _summary_text(source: Dictionary, products: Array, cold_products: Array, cities: Array, aftermath: Array, city_clues: Array, monster_clues: Array, warehouses: Array, cash_entries: Array, inference_lines: Array, public_summary: String) -> String:
	var lines := [
		"经济总览",
		"看三件事：钱从哪座城来，哪个商品在变贵，哪些公开动作留下线索。",
		"城市现金按秒进账；商品供需、天气和商路会改变GDP/min；对手现金、手牌和私密推理保持隐藏。",
		"情报现金只在终局兑现；当前页只整理公开证据和当前玩家自己的经济流水，不验证隐藏真相。",
		"经济天气:%s｜卡牌余波:%d条｜城市线索商品:%s｜怪兽资金线索:%d条。" % [
			_short_text(str(source.get("weather_text", "天气稳定")), 28),
			aftermath.size(),
			_limited_names(source.get("current_product_names", []) as Array, 3, "暂无"),
			monster_clues.size(),
		],
		"商品热榜｜%s" % _joined_or(_product_detail_lines(products, 3), "暂无商品价格；先等待市场刷新或建城生产。"),
		"低价/供给压制｜%s" % _joined_or(_product_detail_lines(cold_products, 2), "暂无低价商品。"),
		"商路收入前景｜玩家经济隐私：对手现金、手牌和私密流水不公开｜%s" % _joined_or(_city_detail_lines(cities, 3), "暂无城市；先城市化陆地。"),
		public_summary,
		"最近卡牌余波｜%s" % _joined_or(_card_aftermath_lines(aftermath, 5), "暂无匿名卡余波；看顶部牌轨等待公开结果。"),
		"最近城市公开线索｜%s" % _joined_or(_city_clue_lines(city_clues, 4), "类型:暂无｜线索商品:暂无｜等待城市公开线索。"),
		"最近怪兽资金线索｜最大生命比例决定归属方掉钱幅度｜%s" % _joined_or(_monster_clue_lines(monster_clues, 4), "暂无伤害资金线索。"),
		"仓储靶标｜匿名仓储会把期货收益绑定到可被攻击的城市｜%s" % _joined_or(_warehouse_lines(warehouses, 3), "暂无匿名仓储靶标。"),
		"当前玩家推理板",
	]
	for inference_line: String in inference_lines:
		lines.append(inference_line)
	lines.append("玩家经济流水｜%s" % _joined_or(_player_cash_lines(cash_entries), "暂无玩家经济流水。"))
	lines.append("下方仪表板只显示可扫读信息；悬停每一行可看完整证据。")
	lines.append("刷新%d｜当前玩家：%s｜怪兽%d只｜%s" % [int(source.get("business_cycle_count", 0)), str(source.get("selected_name", "无")), int(source.get("monster_count", 0)), _short_text(str(source.get("weather_text", "天气稳定")), 24)])
	return "\n".join(lines)


func _public_situation_summary(source: Dictionary, aftermath: Array, city_clues: Array, monster_clues: Array, warehouses: Array) -> String:
	var pieces := []
	if not aftermath.is_empty(): pieces.append("匿名卡牌余波%d条" % aftermath.size())
	if not city_clues.is_empty(): pieces.append("城市公开线索%d条" % city_clues.size())
	if not monster_clues.is_empty(): pieces.append("怪兽资金线索%d条" % monster_clues.size())
	if not warehouses.is_empty(): pieces.append("匿名仓储%d城" % warehouses.size())
	var monster_count := int(source.get("monster_count", 0))
	if monster_count > 0: pieces.append("场上怪兽%d只" % monster_count)
	var weather_text := _short_text(str(source.get("weather_text", "")), 32)
	if weather_text != "": pieces.append("天气:%s" % weather_text)
	if pieces.is_empty():
		return "公开异动：暂无明显场面结果；继续观察商品价格、城市GDP、怪兽落点和匿名卡牌轨道。"
	return "公开异动：%s。页面只汇总场面结果；对手现金、手牌和私密推理保持隐藏。" % "；".join(pieces)


func _top_product_value(entries: Array) -> String:
	if entries.is_empty(): return "—"
	var entry := entries[0] as Dictionary
	return "%s ¥%d" % [_short_text(str(entry.get("name", "商品")), 8), int(entry.get("price", 0))]


func _top_city_value(entries: Array) -> String:
	if entries.is_empty(): return "—"
	var entry := entries[0] as Dictionary
	return "%s +%d" % [_short_text(str(entry.get("name", "城市")), 7), int(entry.get("income", 0))]


func _compact_product_lines(entries: Array, cold: bool) -> Array:
	var lines := []
	for entry_variant: Variant in entries.slice(0, mini(4, entries.size())):
		var entry := entry_variant as Dictionary
		var weather := str(entry.get("weather", "无"))
		lines.append("%s ¥%d｜供%d/需%d｜%s%s｜天气%s" % [str(entry.get("name", "商品")), int(entry.get("price", 0)), int(entry.get("supply", 0)), int(entry.get("demand", 0)), "受压" if cold else "趋势", _signed_int(int(entry.get("trend", 0))), weather])
	return lines


func _compact_city_lines(entries: Array) -> Array:
	var lines := []
	for entry_variant: Variant in entries.slice(0, mini(4, entries.size())):
		var entry := entry_variant as Dictionary
		lines.append("%s｜%s｜收入%d｜断%d｜天气%s" % [str(entry.get("name", "城市")), str(entry.get("owner_view", "未知业主")), int(entry.get("income", 0)), int(entry.get("disrupted", 0)), _weather_income_contribution_text(entry.get("weather_contributions", []))])
	if lines.is_empty(): lines.append("暂无城市；先城市化陆地。")
	return lines


func _product_detail_lines(entries: Array, limit: int) -> Array:
	var lines := []
	for entry_variant: Variant in entries.slice(0, mini(limit, entries.size())):
		var entry := entry_variant as Dictionary
		var weather := str(entry.get("weather", "无"))
		weather = "天气无" if weather == "无" else "天气%s" % weather
		lines.append("%s ¥%d（%s｜偏离%s｜趋势%s｜供%d/需%d/断%d｜波%d｜%s｜公开状态%s｜路径%s）" % [str(entry.get("name", "商品")), int(entry.get("price", 0)), str(entry.get("tier", "未定价")), _signed_int(int(entry.get("gap", 0))), _signed_int(int(entry.get("trend", 0))), int(entry.get("supply", 0)), int(entry.get("demand", 0)), int(entry.get("disrupted", 0)), int(entry.get("volatility", 0)), weather, _status_text(entry.get("status_tags", []) as Array), str(entry.get("path", ""))])
	return lines


func _city_detail_lines(entries: Array, limit: int) -> Array:
	var lines := []
	for entry_variant: Variant in entries.slice(0, mini(limit, entries.size())):
		var entry := entry_variant as Dictionary
		lines.append("%s｜%s｜%s｜潜在收入%d｜上次%d｜%s｜收入拆解%s｜天气%s｜公开状态%s｜合约%s｜供给%d/%d｜断路%d｜竞争%d｜流通%s｜生产%s｜需求%s" % [str(entry.get("name", "城市")), str(entry.get("owner_view", "未知业主")), str(entry.get("intel_hint", "情报：无")), int(entry.get("income", 0)), int(entry.get("last_income", 0)), str(entry.get("gdp_trend", "GDP趋势：暂无历史")), str(entry.get("breakdown", "")), _weather_income_contribution_text(entry.get("weather_contributions", [])), _status_text(entry.get("status_tags", []) as Array), str(entry.get("contract", "无")), int(entry.get("supplied", 0)), int(entry.get("demand_count", 0)), int(entry.get("disrupted", 0)), int(entry.get("competition", 0)), str(entry.get("flow", "无")), _limited_names(entry.get("products", []) as Array, 3, "无"), _limited_names(entry.get("demands", []) as Array, 3, "无")])
	return lines


func _weather_income_contribution_text(value: Variant) -> String:
	if not (value is Array) or (value as Array).is_empty():
		return "无"
	var parts: Array[String] = []
	for row_variant in value as Array:
		if not (row_variant is Dictionary):
			continue
		var row := row_variant as Dictionary
		var direction := "生产" if str(row.get("direction", "")) == "production" else "需求"
		var multiplier := float(row.get("multiplier", 1.0))
		parts.append("%s%s%+d%%" % [str(row.get("weather_id", "天气")), direction, int(round((multiplier - 1.0) * 100.0))])
		if parts.size() >= 3:
			break
	return "、".join(parts) if not parts.is_empty() else "无"


func _card_aftermath_lines(entries: Array, limit: int) -> Array:
	var lines := []
	for entry_variant: Variant in entries.slice(0, mini(limit, entries.size())):
		var entry := entry_variant as Dictionary
		var resolved_time := float(entry.get("resolved_time", -1.0))
		var time_text := "T+%.1fs" % resolved_time if resolved_time >= 0.0 else "时间未知"
		var owner_text := "归属已公开" if bool(entry.get("owner_known", false)) else "归属待猜"
		var tip_clue := str(entry.get("tip_clue", ""))
		var tip_text := "｜竞价:%s" % tip_clue if tip_clue != "" else ""
		lines.append("%s｜%s演出｜%s｜%s｜%s｜线索:%s%s" % [time_text, str(entry.get("style", "卡牌")), str(entry.get("card", "卡牌")), str(entry.get("target", "目标未知")), owner_text, str(entry.get("clue", "公开结果留下推理痕迹")), tip_text])
	return lines


func _city_clue_lines(entries: Array, limit: int) -> Array:
	var lines := []
	for entry_variant: Variant in entries.slice(0, mini(limit, entries.size())):
		var entry := entry_variant as Dictionary
		var time_value := float(entry.get("time", -1.0))
		var time_text := "T+%.0fs" % time_value if time_value >= 0.0 else "时间未知"
		lines.append("%s｜%s｜%s｜类型:%s｜线索商品:%s｜上次收入%d｜生产:%s｜需求:%s｜线索:%s" % [time_text, str(entry.get("district", "城市")), "己方城市" if bool(entry.get("owner_visible", false)) else "业主未知", str(entry.get("kind", "公开")), _limited_names(entry.get("clue_products", []) as Array, 3, "无"), int(entry.get("income", 0)), _limited_names(entry.get("products", []) as Array, 3, "无"), _limited_names(entry.get("demands", []) as Array, 3, "无"), str(entry.get("clue", ""))])
	return lines


func _monster_clue_lines(entries: Array, limit: int) -> Array:
	var lines := []
	for entry_variant: Variant in entries.slice(0, mini(limit, entries.size())):
		var entry := entry_variant as Dictionary
		var recent_time := float(entry.get("recent_time", -1.0))
		var time_text := "T+%.1fs" % recent_time if recent_time >= 0.0 else "等待伤害"
		var recent_loss := int(entry.get("recent_loss", 0))
		var recent_text := "最近未产生现金损失"
		if recent_loss > 0:
			recent_text = "最近损失¥%d/%d伤害" % [recent_loss, int(entry.get("recent_damage", 0))]
			if str(entry.get("recent_source", "")) != "": recent_text += "（%s）" % str(entry.get("recent_source", ""))
		lines.append("%s｜怪%d·%s%s｜%s｜%s｜累计损失¥%d｜资金池余¥%d/%d｜%s｜线索:%s" % [time_text, int(entry.get("slot", 0)) + 1, str(entry.get("name", "怪兽")), _roman(clampi(int(entry.get("rank", 1)), 1, 4)), str(entry.get("owner_text", "归属未公开")), recent_text, int(entry.get("total_lost", 0)), int(entry.get("cash_pool", 0)), int(entry.get("cash_total", 0)), "倒地" if bool(entry.get("down", false)) else "在场", str(entry.get("clue", "暂无公开资金线索"))])
	return lines


func _warehouse_lines(entries: Array, limit: int) -> Array:
	var lines := []
	for entry_variant: Variant in entries.slice(0, mini(limit, entries.size())):
		var entry := entry_variant as Dictionary
		var seconds_left := float(entry.get("seconds_left", -1.0))
		var duration_text := "%ds" % ceili(seconds_left) if seconds_left >= 0.0 else "未知"
		lines.append("%s｜%s｜%s｜仓储风险%d｜%d笔/%d单位｜商品:%s｜到期:%s｜GDP/min %d｜反制:做空/齐射/军队/引怪｜线索:%s" % [str(entry.get("name", "仓储城市")), str(entry.get("owner_view", "业主未知")), str(entry.get("intel_hint", "情报：无")), int(entry.get("pressure", 0)), int(entry.get("count", 0)), int(entry.get("units", 0)), _limited_names(entry.get("products", []) as Array, 3, "未知商品"), duration_text, int(entry.get("potential_income", 0)), str(entry.get("latest_clue", "暂无公开线索"))])
	return lines


func _risk_lines(monster_entries: Array, warehouse_entries: Array) -> Array:
	var lines := _monster_clue_lines(monster_entries, 2)
	lines.append_array(_warehouse_lines(warehouse_entries, 2))
	if lines.is_empty(): lines.append("暂无高风险仓储或怪兽资金线索。")
	return lines


func _player_cash_lines(entries: Array) -> Array:
	var lines := []
	for entry_variant: Variant in entries:
		var entry := entry_variant as Dictionary
		var player_name := str(entry.get("name", "玩家"))
		if bool(entry.get("eliminated", false)):
			lines.append("%s｜破产出局：现金归零，停止行动和城市现金流；历史手牌、弃牌与私密计划仍不公开。" % player_name)
		elif bool(entry.get("private", false)):
			lines.append("%s｜现金、结算预估、城市资产、现金流、资金轨迹与流水均为私人信息；只能从公开行动自行推测。" % player_name)
		else:
			lines.append("%s｜%s%d｜现金%d｜城市%d｜%s｜实时现金流%s｜角色累计+%d｜潜在GDP/min %d｜最近%s｜窗口%s｜轨迹%s｜流水%s" % [player_name, str(entry.get("score_label", "可见预估")), int(entry.get("visible_score", 0)), int(entry.get("visible_cash", 0)), int(entry.get("city_count", 0)), str(entry.get("intel_summary", "")), _signed_int(int(entry.get("last_cycle", 0))), int(entry.get("role_income", 0)), int(entry.get("gdp_per_minute", 0)), _signed_int(int(entry.get("recent_delta", 0))), _signed_int(int(entry.get("window_delta", 0))), str(entry.get("path", "")), str(entry.get("ledger", "暂无"))])
	return lines


func _sort_cold_product(a: Dictionary, b: Dictionary) -> bool:
	var cold_a := int(a.get("cold_score", 0))
	var cold_b := int(b.get("cold_score", 0))
	if cold_a != cold_b: return cold_a > cold_b
	var price_a := int(a.get("price", 0))
	var price_b := int(b.get("price", 0))
	if price_a != price_b: return price_a < price_b
	return str(a.get("name", "")) < str(b.get("name", ""))


func _dictionary_array(value: Variant, limit: int) -> Array:
	var result := []
	if not (value is Array): return result
	for entry_variant: Variant in value:
		if entry_variant is Dictionary:
			result.append((entry_variant as Dictionary).duplicate(true))
		if result.size() >= limit: break
	return result


func _string_array(value: Variant, limit: int) -> Array:
	var result := []
	if not (value is Array): return result
	for entry_variant: Variant in value:
		var text := str(entry_variant).strip_edges()
		if text != "": result.append(text)
		if result.size() >= limit: break
	return result


func _joined_or(lines: Array, fallback: String) -> String:
	return "；".join(lines) if not lines.is_empty() else fallback


func _limited_names(values: Array, limit: int, fallback: String) -> String:
	var result := []
	for value_variant: Variant in values:
		var text := str(value_variant).strip_edges()
		if text != "": result.append(text)
		if result.size() >= limit: break
	return "、".join(result) if not result.is_empty() else fallback


func _status_text(values: Array) -> String:
	return _limited_names(values, 5, "无")


func _signed_int(value: int) -> String:
	return "+%d" % value if value > 0 else "%d" % value


func _roman(rank: int) -> String:
	return ["I", "II", "III", "IV"][clampi(rank, 1, 4) - 1]


func _short_text(value: String, limit: int) -> String:
	if limit <= 0 or value.length() <= limit: return value
	return value.substr(0, maxi(0, limit - 1)) + "…"
