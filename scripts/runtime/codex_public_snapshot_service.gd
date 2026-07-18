@tool
extends Node
class_name CodexPublicSnapshotService

var _configured := false
var _compose_counts := {"role": 0, "region": 0}


func configure(_config: Dictionary = {}) -> void:
	_configured = true


func compose_role(source: Dictionary) -> Dictionary:
	_compose_counts["role"] = int(_compose_counts.get("role", 0)) + 1
	var role_card: Dictionary = source.get("role_card", {}) if source.get("role_card", {}) is Dictionary else {}
	if role_card.is_empty():
		return {"summary_text": "", "route_label": "通用经营", "economy_line": "", "control_line": "", "board": {}}
	var index := int(source.get("index", 0))
	var total := maxi(1, int(source.get("total", 1)))
	var passive_text := str(source.get("passive_text", "暂无被动"))
	var starting_cash_delta := int(source.get("starting_cash_delta", 0))
	var accent: Color = source.get("accent", Color("#38bdf8")) as Color
	var tags := _role_route_tags(role_card, starting_cash_delta)
	var route_label := _limited_names(tags, 4, "通用经营")
	var economy_line := _role_economy_line(role_card, starting_cash_delta)
	var intel_line := _role_intel_line(role_card)
	var control_line := _role_control_line(role_card)
	var opening_hint := _role_opening_hint(role_card, tags)
	var privacy_line := _role_privacy_line(role_card)
	var face: Dictionary = (source.get("face", {}) as Dictionary).duplicate(true) if source.get("face", {}) is Dictionary else {}
	face["minimum_width"] = 230.0
	face["minimum_height"] = 270.0
	face["effect"] = str(source.get("face_effect", face.get("effect", "")))
	face["rank"] = _short_text(str(role_card.get("species", "角色")), 10)
	var chips: Array = [
		{"text": "公开角色", "accent": Color("#fde68a"), "tooltip": "角色身份是公开信息。"},
		{"text": "召唤可选", "accent": Color("#bfdbfe"), "tooltip": "每席持有起始怪兽牌；召唤完全自愿，不由角色绑定。"},
	]
	for tag_variant in _first_entries(tags, 4):
		chips.append({"text": str(tag_variant), "accent": accent.lightened(0.10), "tooltip": "这个角色的主要牌路定位。"})
	var board := {
		"title": "%s｜第%d/%d张" % [str(role_card.get("name", "外星辛迪加")), index + 1, total],
		"title_tooltip": "公开身份牌：先看牌路、能力、信息边界和开局打法，再决定是否选择这个角色。",
		"subtitle": "%s｜%s" % [str(role_card.get("species", "未知外星人")), route_label],
		"tooltip": "公开身份牌：先看牌路、能力、信息边界和开局打法，再决定是否选择这个角色。",
		"accent": accent,
		"kpi_columns": clampi(int(source.get("kpi_columns", 1)), 1, 4),
		"route_columns": clampi(int(source.get("route_columns", 1)), 1, 3),
		"face": face,
		"chips": chips,
		"kpis": [
			{"title": "经济", "value": _short_text(economy_line, 34), "meta": "现金/商品/购牌收益", "accent": Color("#bbf7d0")},
			{"title": "情报", "value": _short_text(intel_line, 34), "meta": "侦测、追溯和竞猜优势", "accent": Color("#c4b5fd")},
			{"title": "控制", "value": _short_text(control_line, 34), "meta": "日照市场、合约、单位或反制", "accent": Color("#93c5fd")},
			{"title": "开局", "value": _short_text(opening_hint, 34), "meta": "第一局建议动作", "accent": Color("#facc15")},
		],
		"routes": [
			{"title": "被动能力", "body": _short_text(passive_text, 92), "tooltip": passive_text, "accent": Color("#fde68a")},
			{"title": "角色特征", "body": _short_text(str(role_card.get("trait", "暂无特征")), 92), "tooltip": str(role_card.get("trait", "暂无特征")), "accent": accent},
			{"title": "信息边界", "body": privacy_line, "tooltip": privacy_line, "accent": Color("#f0abfc")},
			{"title": "开局打法", "body": _short_text(opening_hint, 92), "tooltip": opening_hint, "accent": Color("#4ade80")},
			{"title": "选择提醒", "body": "角色与起始怪兽牌分别选择；怪兽归属不会由图鉴披露。", "tooltip": "角色公开、召唤自愿、起始怪兽牌属性只看怪兽牌。", "accent": Color("#38bdf8")},
			{"title": "风味", "body": _short_text(str(role_card.get("flavor", "暂无设定")), 92), "tooltip": str(role_card.get("flavor", "暂无设定")), "accent": Color("#fb923c")},
		],
	}
	var summary_text := "角色卡｜第%d/%d张｜%s｜%s\n特征：%s\n被动：%s\n看下方公开身份牌；角色卡公开，怪兽归属不由图鉴披露。\n起始怪兽牌独立持有；召唤自愿。" % [
		index + 1,
		total,
		str(role_card.get("name", "外星辛迪加")),
		str(role_card.get("species", "未知外星人")),
		_short_text(str(role_card.get("trait", "公开身份")), 72),
		_short_text(passive_text, 88),
	]
	return {"summary_text": summary_text, "route_label": route_label, "economy_line": economy_line, "control_line": control_line, "board": board}


func role_route_label(role_card: Dictionary, starting_cash_delta: int = 0) -> String:
	return _limited_names(_role_route_tags(role_card, starting_cash_delta), 4, "通用经营")


func compose_region(source: Dictionary) -> Dictionary:
	_compose_counts["region"] = int(_compose_counts.get("region", 0)) + 1
	if not bool(source.get("valid", false)):
		return {"summary_text": "区域不存在。", "detail": {}}
	var index := int(source.get("index", 0))
	var total := maxi(1, int(source.get("total", 1)))
	var region_name := str(source.get("name", "区域"))
	var terrain_label := str(source.get("terrain_label", "区域"))
	var economic_focus_label := str(source.get("economic_focus_label", "均衡"))
	var development_status := _region_development_status(source)
	var accent := _region_accent(source)
	var icon := _region_icon(source)
	var facility_summary := _region_facility_summary(source)
	var monster_attraction := _region_monster_attraction(source.get("monster_entries", []) as Array)
	var hp_total := int(source.get("hp_total", 0))
	var hp_now := maxi(0, int(source.get("hp_now", hp_total)))
	var low_hp := hp_total > 0 and hp_now <= int(float(hp_total) / 2.0)
	var hp_color := Color("#fecaca") if low_hp else Color("#bbf7d0")
	var chips: Array = [
		{"text": "完整度 %d/%d" % [hp_now, hp_total], "fg": hp_color, "accent": hp_color, "bg": Color("#020617"), "tooltip": "所有玩家共享同一块区域生命；归零后区域成为废墟并清除本地设施。"},
		{"text": "公开资料", "fg": Color("#fef3c7"), "accent": Color("#fef3c7"), "bg": Color("#020617"), "tooltip": "区域图鉴只消费公开区域事实；玩家私有标注留在情报档案。"},
		{"text": "设施 %d" % int(source.get("facility_count", 0)), "fg": Color("#fde68a"), "accent": Color("#fde68a"), "bg": Color("#020617"), "tooltip": "设施类型、等级和所有者均为公开信息。"},
		{"text": "吞吐关联 %d" % int(source.get("trade_route_load", 0)), "fg": Color("#c4b5fd"), "accent": Color("#c4b5fd"), "bg": Color("#020617"), "tooltip": "该数字表示公开物流关联，不是可受损的抽象路线生命。"},
		{"text": "牌架 %d" % int(source.get("card_count", 0)), "fg": Color("#a7f3d0"), "accent": Color("#a7f3d0"), "bg": Color("#020617"), "tooltip": "普通牌全局可浏览；来源区域受光时才能锁定报价。"},
		{"text": "公开市场", "fg": Color("#67e8f9"), "accent": Color("#67e8f9"), "bg": Color("#020617"), "tooltip": "区域页只列公开牌源，不读取现金、手牌或私密库存。"},
	]
	var kpis := [
		{"title": "设施", "value": development_status, "meta": facility_summary, "accent": Color("#facc15")},
		{"title": "供给", "value": _short_text(str(source.get("supply_text", "无")), 32), "meta": "生产/商品价格线索", "accent": Color("#4ade80")},
		{"title": "需求", "value": _short_text(str(source.get("demand_text", "无")), 32), "meta": "需求会抬高商品价格", "accent": Color("#fb7185")},
		{"title": "天气", "value": _short_text(str(source.get("weather_text", "暂无")), 32), "meta": "影响产/交/消", "accent": Color("#38bdf8")},
	]
	var trade_route_load := int(source.get("trade_route_load", 0))
	var connection_summary := str(source.get("connection_summary", "暂无"))
	var clues := [
		{"title": "运输吞吐", "body": "当前关联 %d条公开物流记录" % trade_route_load, "tooltip": "%s；显示物流事实，不创建抽象路线生命。" % connection_summary, "accent": Color("#93c5fd")},
		{"title": "牌架", "body": _short_text(str(source.get("card_choice_summary", "无")), 76), "tooltip": "双击地图区域可浏览牌架；来源区域受光时可显式锁定5秒报价。", "accent": Color("#a78bfa")},
		{"title": "怪兽吸引", "body": _short_text(monster_attraction, 76), "tooltip": "这里只显示非数值公开因素；内部权重、随机签和预选目标保持隐藏。", "accent": Color("#fb923c")},
		{"title": "公开事件", "body": _short_text(str(source.get("public_clue", "暂无")), 76), "tooltip": "这里只显示公开事件与结算结果；私密调查不会进入区域图鉴。", "accent": Color("#f0abfc")},
		{"title": "邻接", "body": _short_text(connection_summary, 76), "tooltip": "购牌、怪兽移动和商路都依赖邻接关系。", "accent": Color("#67e8f9")},
		{"title": "读法", "body": "先看共享完整度和设施，再比较供需、天气、吞吐与怪兽压力。", "tooltip": "设施所有者公开；当前玩家的私有调查只在情报档案中显示。", "accent": Color("#fde68a")},
	]
	var detail := {
		"icon": icon,
		"icon_tooltip": "地块符号：⬡陆地/≈海域/▣城市/✕废墟。",
		"title": "%s｜第%d/%d区" % [region_name, index + 1, total],
		"subtitle": "%s｜%s｜%s" % [terrain_label, economic_focus_label, development_status],
		"chips": chips,
		"kpis": kpis,
		"clues": clues,
		"accent": accent,
		"tooltip": "区域地块板：先扫共享完整度、公开设施、供需、天气、运输吞吐、牌架与怪兽压力。",
	}
	var state_text := "已破坏" if bool(source.get("destroyed", false)) else "未破坏"
	var lines := [
		"第%d/%d区｜%s｜%s｜%s" % [index + 1, total, region_name, terrain_label, state_text],
		"看下方区域地块板：共享完整度、公开设施与所有者、供给、需求、天气、吞吐、牌架和怪兽压力。",
		"设施所有权、类型和等级公开；现金、手牌、私密库存、怪兽归属与内部权重不在这里披露。",
		"区域可提供卡牌：%s。" % _limited_names(source.get("card_names", []) as Array, 5, "暂无"),
	]
	if int(source.get("facility_count", 0)) > 0:
		lines.append("公开设施：%s｜区域GDP公开汇总:%d/min" % [facility_summary, int(source.get("city_last_income", 0))])
		for detail_variant in source.get("income_detail_lines", []) as Array:
			lines.append(str(detail_variant))
	else:
		lines.append("公开设施：暂无｜生产资源：%s｜区域GDP公开汇总：暂无。" % _limited_names(source.get("products", []) as Array, 4, "暂无"))
	return {"summary_text": "\n".join(lines), "detail": detail}


func debug_snapshot() -> Dictionary:
	return {
		"service_ready": _configured,
		"service_authoritative": _configured,
		"supported_domains": ["role", "region"],
		"compose_counts": _compose_counts.duplicate(true),
		"reads_runtime_nodes": false,
		"legacy_main_formatter_active": false,
	}


func _region_accent(source: Dictionary) -> Color:
	if bool(source.get("destroyed", false)):
		return Color("#fb7185")
	match str(source.get("terrain", "land")):
		"ocean":
			return Color("#38bdf8")
		"volcanic":
			return Color("#fb923c")
		"ice":
			return Color("#a5f3fc")
		"desert":
			return Color("#facc15")
	return Color("#4ade80")


func _region_icon(source: Dictionary) -> String:
	if bool(source.get("destroyed", false)):
		return "✕"
	if int(source.get("facility_count", 0)) > 0:
		return "▣"
	return "≈" if str(source.get("terrain", "land")) == "ocean" else "⬡"


func _region_development_status(source: Dictionary) -> String:
	if bool(source.get("destroyed", false)):
		return "区域废墟"
	var facility_count := maxi(0, int(source.get("facility_count", 0)))
	return "%d处公开设施" % facility_count if facility_count > 0 else "暂无设施"


func _region_facility_summary(source: Dictionary) -> String:
	var pieces: Array[String] = []
	for facility_variant: Variant in source.get("facility_entries", []) as Array:
		if not (facility_variant is Dictionary):
			continue
		var facility := facility_variant as Dictionary
		var owner_text := "玩家%d" % (int(facility.get("owner_player_index", -1)) + 1) if str(facility.get("owner_kind", "neutral")) == "player" else "中立"
		pieces.append("%s·%s·Lv.%d" % [owner_text, str(facility.get("facility_type", "设施")), int(facility.get("rank", 1))])
	return _limited_names(pieces, 3, "暂无公开设施")


func _region_monster_attraction(entries: Array) -> String:
	var lines := []
	for entry_variant in entries:
		var entry: Dictionary = entry_variant if entry_variant is Dictionary else {}
		if entry.is_empty():
			continue
		lines.append("怪%d·%s %s" % [int(entry.get("ordinal", lines.size() + 1)), str(entry.get("name", "怪兽")), str(entry.get("reason", ""))])
	return "；".join(lines) if not lines.is_empty() else "暂无怪兽压力"


func _role_route_tags(role_card: Dictionary, starting_cash_delta: int) -> Array:
	var tags := []
	if int(role_card.get("resource_cash_amount", 0)) > 0 or str(role_card.get("bonus_card_product", "")) != "": tags.append("商品经营")
	if int(role_card.get("intel_city_reveal_charges", 0)) > 0 or int(role_card.get("intel_contract_trace_charges", 0)) > 0 or int(role_card.get("card_history_residual_catalog_charges", 0)) > 0 or int(role_card.get("card_history_public_exclusion_charges", 0)) > 0 or int(role_card.get("city_guess_reward_bonus", 0)) > 0: tags.append("情报推理")
	if int(role_card.get("high_volatility_first_sale_bonus", 0)) > 0: tags.append("市场波动")
	if int(role_card.get("contract_flow_discount", 0)) > 0: tags.append("合约商路")
	if int(role_card.get("monster_upgrade_cash", 0)) > 0 or int(role_card.get("monster_control_limit_bonus", 0)) > 0: tags.append("怪兽路线")
	if int(role_card.get("military_control_limit_bonus", 0)) > 0: tags.append("军队路线")
	if bool(role_card.get("monster_cards_as_counter", false)): tags.append("相位防守")
	if starting_cash_delta != 0: tags.append("起手资金")
	return tags if not tags.is_empty() else ["通用经营"]


func _role_economy_line(role_card: Dictionary, starting_cash_delta: int) -> String:
	var parts := []
	if starting_cash_delta != 0: parts.append("开局¥%s" % _signed_int_text(starting_cash_delta))
	var product := str(role_card.get("resource_cash_product", ""))
	var amount := int(role_card.get("resource_cash_amount", 0))
	if product != "" and amount > 0: parts.append("%s城市+¥%d/min" % [product, amount])
	var bonus_product := str(role_card.get("bonus_card_product", ""))
	if bonus_product != "": parts.append("%s区域购牌+1" % bonus_product)
	var upgrade_cash := int(role_card.get("monster_upgrade_cash", 0))
	if upgrade_cash > 0: parts.append("升兽+¥%d" % upgrade_cash)
	return " / ".join(parts) if not parts.is_empty() else "无直接现金；靠能力转化优势"


func _role_intel_line(role_card: Dictionary) -> String:
	var parts := []
	var fields := [
		["intel_city_reveal_charges", "查城市%d次"], ["intel_contract_trace_charges", "查合约%d次"],
		["card_history_residual_catalog_charges", "残帧编目%d次"], ["card_history_public_exclusion_charges", "公开排除%d次"],
		["city_guess_reward_bonus", "城市标注+¥%d"], ["high_volatility_sale_threshold", "波动门槛%d"],
		["high_volatility_first_sale_bonus", "周期首售+¥%d"],
	]
	for field_variant in fields:
		var field: Array = field_variant
		var value := int(role_card.get(str(field[0]), 0))
		if value > 0: parts.append(str(field[1]) % value)
	return " / ".join(parts) if not parts.is_empty() else "无主动侦测；靠公开线索判断"


func _role_control_line(role_card: Dictionary) -> String:
	var parts := []
	if int(role_card.get("contract_flow_discount", 0)) > 0: parts.append("合约GDP-%d%%" % (int(role_card.get("contract_flow_discount", 0)) * 5))
	if int(role_card.get("monster_control_limit_bonus", 0)) > 0: parts.append("怪兽上限%d" % (1 + int(role_card.get("monster_control_limit_bonus", 0))))
	if int(role_card.get("military_control_limit_bonus", 0)) > 0: parts.append("军队上限%d" % (1 + int(role_card.get("military_control_limit_bonus", 0))))
	if bool(role_card.get("monster_cards_as_counter", false)): parts.append("怪兽牌可否决")
	return " / ".join(parts) if not parts.is_empty() else "标准购牌/合约/单位上限"


func _role_opening_hint(role_card: Dictionary, tags: Array) -> String:
	if tags.has("商品经营"):
		var product := str(role_card.get("resource_cash_product", role_card.get("bonus_card_product", "")))
		return "优先找%s相关区域建城或购牌；用商品线隐藏你的真实收益点。" % product if product != "" else "优先围绕加成商品建城，并保护供需路线。"
	if tags.has("情报推理"): return "先读匿名牌轨和城市异动，再用角色侦测降低关键猜测风险。"
	if tags.has("怪兽路线"): return "召唤完全自愿；活怪会抬高来源同区与邻区牌价，也会制造经济压力线索。"
	if tags.has("军队路线"): return "用短时军队保卫核心城市或压制领先者，不要让地图失控。"
	if tags.has("相位防守"): return "保留一张怪兽牌作为反制资源，等关键玩家互动牌翻面。"
	if tags.has("合约商路"): return "优先观察供需互补区域，用合约把城市GDP做成稳定现金流。"
	return "先查看受光挂牌、建立第一份收入；起始怪兽牌可在合适时机自愿召唤。"


func _role_privacy_line(role_card: Dictionary) -> String:
	if bool(role_card.get("monster_cards_as_counter", false)): return "角色公开；反制来源仍匿名，原怪兽牌不公开。"
	if int(role_card.get("intel_city_reveal_charges", 0)) > 0 or int(role_card.get("intel_contract_trace_charges", 0)) > 0 or int(role_card.get("card_history_residual_catalog_charges", 0)) > 0 or int(role_card.get("card_history_public_exclusion_charges", 0)) > 0: return "角色公开；私人标注只使用公开证据，不揭示匿名出牌者。"
	if int(role_card.get("monster_control_limit_bonus", 0)) > 0: return "角色公开；怪兽归属、内部权重和预选目标不由图鉴披露。"
	if int(role_card.get("military_control_limit_bonus", 0)) > 0: return "角色公开；军令来源不公开，军队行动结果公开。"
	return "角色与设施所有者公开；未召唤的起始怪兽牌、手牌、现金和私密调查不由图鉴披露。"


func _short_text(text: String, limit: int) -> String:
	var compact := text.replace("\n", " ").strip_edges()
	return compact if compact.length() <= limit else compact.left(maxi(1, limit - 1)) + "…"


func _limited_names(values: Array, limit: int, empty_text: String = "暂无") -> String:
	if values.is_empty(): return empty_text
	var pieces: Array[String] = []
	for i in range(mini(maxi(1, limit), values.size())): pieces.append(str(values[i]))
	if values.size() > limit: pieces.append("+%d" % (values.size() - limit))
	return "、".join(pieces)


func _first_entries(values: Array, limit: int) -> Array:
	return values.slice(0, mini(values.size(), maxi(0, limit)))


func _signed_int_text(value: int) -> String:
	return "+%d" % value if value > 0 else str(value)
