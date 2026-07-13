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
		{"text": "首召独立", "accent": Color("#bfdbfe"), "tooltip": "首召怪兽在开局准备独立选择，不由角色绑定。"},
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
			{"title": "控制", "value": _short_text(control_line, 34), "meta": "购牌范围、合约、单位或反制", "accent": Color("#93c5fd")},
			{"title": "开局", "value": _short_text(opening_hint, 34), "meta": "第一局建议动作", "accent": Color("#facc15")},
		],
		"routes": [
			{"title": "被动能力", "body": _short_text(passive_text, 92), "tooltip": passive_text, "accent": Color("#fde68a")},
			{"title": "角色特征", "body": _short_text(str(role_card.get("trait", "暂无特征")), 92), "tooltip": str(role_card.get("trait", "暂无特征")), "accent": accent},
			{"title": "信息边界", "body": privacy_line, "tooltip": privacy_line, "accent": Color("#f0abfc")},
			{"title": "开局打法", "body": _short_text(opening_hint, 92), "tooltip": opening_hint, "accent": Color("#4ade80")},
			{"title": "选择提醒", "body": "选角色不选怪兽；怪兽归属要靠场上线索推理。", "tooltip": "角色公开、首召怪兽独立、起始怪兽牌属性只看怪兽牌。", "accent": Color("#38bdf8")},
			{"title": "风味", "body": _short_text(str(role_card.get("flavor", "暂无设定")), 92), "tooltip": str(role_card.get("flavor", "暂无设定")), "accent": Color("#fb923c")},
		],
	}
	var summary_text := "角色卡｜第%d/%d张｜%s｜%s\n特征：%s\n被动：%s\n看下方公开身份牌；角色卡公开；怪兽归属仍靠场上线索推理。\n首召怪兽独立选择；角色公开，不暴露怪兽归属。" % [
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
	var city_status := _region_city_status(source)
	var accent := _region_accent(source)
	var icon := _region_icon(source)
	var income_preview := _region_income_preview(source, city_status)
	var monster_attraction := _region_monster_attraction(source.get("monster_entries", []) as Array)
	var hp_total := int(source.get("hp_total", 0))
	var hp_now := maxi(0, int(source.get("hp_now", hp_total)))
	var low_hp := hp_total > 0 and hp_now <= int(float(hp_total) / 2.0)
	var hp_color := Color("#fecaca") if low_hp else Color("#bbf7d0")
	var chips: Array = [
		{"text": "HP %d/%d" % [hp_now, hp_total], "fg": hp_color, "accent": hp_color, "bg": Color("#020617"), "tooltip": "区域耐久；破坏会影响城市、商路和部分牌效。"},
		{"text": "热度 %d" % int(source.get("panic", 0)), "fg": Color("#fef3c7"), "accent": Color("#fef3c7"), "bg": Color("#020617"), "tooltip": "热度会影响怪兽、新闻和部分经济线索。"},
		{"text": "交通×%.2f" % float(source.get("transport_speed", 1.0)), "fg": Color("#bfdbfe"), "accent": Color("#bfdbfe"), "bg": Color("#020617"), "tooltip": "交通影响流通速度和城市收入。"},
		{"text": "商路 %d" % int(source.get("trade_route_load", 0)), "fg": Color("#c4b5fd"), "accent": Color("#c4b5fd"), "bg": Color("#020617"), "tooltip": "途经或使用该区域的商路数量。"},
		{"text": "牌架 %d" % int(source.get("card_count", 0)), "fg": Color("#a7f3d0"), "accent": Color("#a7f3d0"), "bg": Color("#020617"), "tooltip": "区域牌架可浏览；购买按打开瞬间资格。"},
	]
	if bool(source.get("selected", false)):
		chips.append({"text": "当前选中", "fg": Color("#fde68a"), "accent": Color("#fde68a"), "bg": Color("#020617"), "tooltip": "这个区域也是主桌当前选区。"})
	var kpis := [
		{"title": "城市", "value": city_status, "meta": income_preview, "accent": Color("#facc15")},
		{"title": "供给", "value": _short_text(str(source.get("supply_text", "无")), 32), "meta": "生产/商品价格线索", "accent": Color("#4ade80")},
		{"title": "需求", "value": _short_text(str(source.get("demand_text", "无")), 32), "meta": "需求会抬高商品价格", "accent": Color("#fb7185")},
		{"title": "天气", "value": _short_text(str(source.get("weather_text", "暂无")), 32), "meta": "影响产/交/消", "accent": Color("#38bdf8")},
	]
	var trade_route_load := int(source.get("trade_route_load", 0))
	var connection_summary := str(source.get("connection_summary", "暂无"))
	var clues := [
		{"title": "商路", "body": "途经/使用 %d条｜毁坏会拖累相关城市GDP" % trade_route_load, "tooltip": connection_summary, "accent": Color("#93c5fd")},
		{"title": "牌架", "body": _short_text(str(source.get("card_choice_summary", "无")), 76), "tooltip": "双击地图区域可打开牌架；查看不限，购买按打开瞬间资格。", "accent": Color("#a78bfa")},
		{"title": "怪兽吸引", "body": _short_text(monster_attraction, 76), "tooltip": "怪兽会按资源、热度、城市和仓储压力自动选择目标。", "accent": Color("#fb923c")},
		{"title": "公开线索", "body": _short_text(str(source.get("public_clue", "暂无")), 76), "tooltip": "这是可见证据，不等于真实业主。", "accent": Color("#f0abfc")},
		{"title": "邻接", "body": _short_text(connection_summary, 76), "tooltip": "购牌、怪兽移动和商路都依赖邻接关系。", "accent": Color("#67e8f9")},
		{"title": "读法", "body": "先看城市GDP，再看供需/商路/怪兽，最后决定建城、买牌或标注。", "tooltip": "区域页只显示公开信息和当前玩家自己的标注，不提前揭示他人隐私。", "accent": Color("#fde68a")},
	]
	var detail := {
		"icon": icon,
		"icon_tooltip": "地块符号：⬡陆地/≈海域/▣城市/✕废墟。",
		"title": "%s｜第%d/%d区" % [region_name, index + 1, total],
		"subtitle": "%s｜%s｜%s" % [terrain_label, economic_focus_label, city_status],
		"chips": chips,
		"kpis": kpis,
		"clues": clues,
		"accent": accent,
		"tooltip": "区域地块板：像读桌游地图板块一样，先扫HP、城市、供需、商路、牌架和公开线索。",
	}
	var state_text := "已破坏" if bool(source.get("destroyed", false)) else "未破坏"
	var selected_text := "｜当前选中" if bool(source.get("selected", false)) else ""
	var lines := [
		"第%d/%d区｜%s｜%s｜%s%s" % [index + 1, total, region_name, terrain_label, state_text, selected_text],
		"看下方区域地块板：城市/GDP、供给、需求、天气、商路、牌架、怪兽吸引和公开线索。",
		"真实业主不公开；现金和手牌也不在这里直接揭示，结合牌轨、怪兽受伤、合约和商品变化推理。",
		"区域可提供卡牌：%s。" % _limited_names(source.get("card_names", []) as Array, 5, "暂无"),
	]
	if bool(source.get("city_active", false)):
		lines.append("流通加速：%s｜合约:%s｜GDP趋势:%s" % [str(source.get("route_flow_status", "暂无")), str(source.get("contract_status", "暂无")), _short_text(str(source.get("gdp_trend", "暂无")), 64)])
		for detail_variant in source.get("income_detail_lines", []) as Array:
			lines.append(str(detail_variant))
	else:
		lines.append("流通加速：无城市｜收入拆解：待城市化｜生产明细：%s｜GDP趋势：暂无。" % _limited_names(source.get("products", []) as Array, 4, "暂无"))
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
	if bool(source.get("city_active", false)):
		return "▣"
	return "≈" if str(source.get("terrain", "land")) == "ocean" else "⬡"


func _region_city_status(source: Dictionary) -> String:
	if bool(source.get("city_active", false)):
		return "城市Lv.%d｜GDP/min %d" % [int(source.get("city_level", 1)), int(source.get("city_last_income", 0))]
	return "城市废墟" if bool(source.get("city_present", false)) else "未城市化"


func _region_income_preview(source: Dictionary, city_status: String) -> String:
	if not bool(source.get("city_active", false)):
		return city_status
	var detail_lines: Array = source.get("income_detail_lines", []) if source.get("income_detail_lines", []) is Array else []
	if detail_lines.is_empty():
		return "GDP/min %d｜暂无拆解" % int(source.get("city_last_income", 0))
	var compact := []
	for i in range(mini(2, detail_lines.size())):
		compact.append(_short_text(str(detail_lines[i]).replace("\n", " / "), 52))
	return " / ".join(compact)


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
	if int(role_card.get("intel_city_reveal_charges", 0)) > 0 or int(role_card.get("intel_card_trace_charges", 0)) > 0 or int(role_card.get("intel_contract_trace_charges", 0)) > 0 or int(role_card.get("card_owner_guess_discount", 0)) > 0 or int(role_card.get("card_owner_guess_bonus", 0)) > 0 or int(role_card.get("city_guess_reward_bonus", 0)) > 0: tags.append("情报推理")
	if int(role_card.get("contract_flow_discount", 0)) > 0: tags.append("合约商路")
	if int(role_card.get("card_access_extra_hops", 0)) > 0 or bool(role_card.get("card_access_global", false)): tags.append("远程补给")
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
		["intel_city_reveal_charges", "查城市%d次"], ["intel_card_trace_charges", "追牌%d次"],
		["intel_contract_trace_charges", "查合约%d次"], ["card_owner_guess_discount", "猜牌-¥%d"],
		["card_owner_guess_bonus", "猜中+¥%d"], ["city_guess_reward_bonus", "城市标注+¥%d"],
	]
	for field_variant in fields:
		var field: Array = field_variant
		var value := int(role_card.get(str(field[0]), 0))
		if value > 0: parts.append(str(field[1]) % value)
	return " / ".join(parts) if not parts.is_empty() else "无主动侦测；靠公开线索判断"


func _role_control_line(role_card: Dictionary) -> String:
	var parts := []
	var extra_hops := int(role_card.get("card_access_extra_hops", 0))
	if bool(role_card.get("card_access_global", false)): parts.append("全图购牌")
	elif extra_hops > 0: parts.append("购牌+%d跳" % extra_hops)
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
	if tags.has("远程补给"): return "首召后多看二跳区域牌架，用更大购牌范围补路线缺口。"
	if tags.has("怪兽路线"): return "尽快首召并考虑升级怪兽；用怪兽压力制造经济线索。"
	if tags.has("军队路线"): return "用短时军队保卫核心城市或压制领先者，不要让地图失控。"
	if tags.has("相位防守"): return "保留一张怪兽牌作为反制资源，等关键玩家互动牌翻面。"
	if tags.has("合约商路"): return "优先观察供需互补区域，用合约把城市GDP做成稳定现金流。"
	return "先首召怪兽、建第一城、围绕最早拿到的商品路线扩张。"


func _role_privacy_line(role_card: Dictionary) -> String:
	if bool(role_card.get("monster_cards_as_counter", false)): return "角色公开；反制来源仍匿名，原怪兽牌不公开。"
	if int(role_card.get("intel_city_reveal_charges", 0)) > 0 or int(role_card.get("intel_card_trace_charges", 0)) > 0 or int(role_card.get("intel_contract_trace_charges", 0)) > 0: return "角色公开；侦测结果进入私人情报，不自动公开。"
	if int(role_card.get("monster_control_limit_bonus", 0)) > 0: return "角色公开；怪兽归属仍等受伤资金线索暴露。"
	if int(role_card.get("military_control_limit_bonus", 0)) > 0: return "角色公开；军令来源不公开，军队行动结果公开。"
	return "角色公开；首召怪兽、手牌、现金和城市业主仍靠线索推理。"


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
