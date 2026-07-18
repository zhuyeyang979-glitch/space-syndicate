@tool
extends Node
class_name CardCodexPublicSnapshotService

const BrowserSnapshotScript := preload("res://scripts/viewmodels/card_codex_browser_snapshot.gd")
const DetailSnapshotScript := preload("res://scripts/viewmodels/card_codex_detail_snapshot.gd")

var _configured := false
var _browser_compose_count := 0
var _detail_compose_count := 0


func configure(_config: Dictionary = {}) -> void:
	_configured = true


func compose_browser(source: Dictionary) -> Dictionary:
	_browser_compose_count += 1
	var names := source.get("names", []) as Array
	var card_sources := []
	for card_variant: Variant in source.get("cards", []) as Array:
		if card_variant is Dictionary:
			card_sources.append(_browser_card_source(card_variant as Dictionary))
	var preview := _browser_preview_source(_dictionary(source.get("preview_card", {})))
	var browser: Dictionary = BrowserSnapshotScript.new().apply_dictionary({
		"names": names,
		"columns": int(source.get("columns", 3)),
		"rows": int(source.get("rows", 1)),
		"page_index": int(source.get("page_index", 0)),
		"filter_id": str(source.get("filter_id", "all")),
		"selected_card": str(source.get("selected_card", "")),
		"icon_legend": str(source.get("icon_legend", "")),
		"filters": (source.get("filters", []) as Array).duplicate(true),
		"cards": card_sources,
		"preview": preview,
	}).to_ui_dictionary()
	var page_count := maxi(1, int(browser.get("page_count", 1)))
	var filter_label := str(source.get("filter_label", "全部牌"))
	browser["summary_text"] = "卡牌图鉴｜%s｜第%d/%d页\n本局牌池%d张｜区域补给%d张。悬停预览，双击看详情。" % [
		filter_label,
		int(browser.get("page_index", 0)) + 1,
		page_count,
		int(source.get("run_pool_count", 0)),
		int(source.get("district_supply_count", 0)),
	]
	return browser


func compose_detail(source: Dictionary) -> Dictionary:
	_detail_compose_count += 1
	if not bool(source.get("valid", false)):
		return {"summary_text": "", "detail": {}}
	var card_name := str(source.get("card_name", "卡牌"))
	var display_name := str(source.get("display_name", card_name))
	var accent := _color(source.get("accent", Color("#38bdf8")), Color("#38bdf8"))
	var key_facts := source.get("key_rule_facts", []) as Array
	var scanline := _limited_names(key_facts, 3, str(source.get("art_stats", "")), "｜")
	var summary_text := "卡牌详情｜第%d/%d张｜%s %s\n%s｜%s｜%s｜%s｜%s\n%s" % [
		int(source.get("index", 0)) + 1,
		maxi(1, int(source.get("total", 1))),
		str(source.get("icon", "◇")),
		display_name,
		str(source.get("category_label", "卡牌")),
		str(source.get("icon_route_label", "通用路线")),
		str(source.get("purchase_cost_text", "购买费用未公开")),
		str(source.get("play_cost_text", "打出费用未公开")),
		"需要选择目标" if bool(source.get("requires_target", false)) else "按卡面自动确定目标",
		_short_text(scanline, 86),
	]
	var detail_source := {
		"accent": accent,
		"tooltip": str(source.get("detail_tooltip", "")),
		"face_note": "同名同级牌可主动合并升级；价格看I级。",
		"face_note_tooltip": "资料库只展示公开卡面和公开规则，不展示隐藏牌主。",
		"card_face": {
			"name": "%s %s" % [str(source.get("icon", "◇")), display_name],
			"cost": "%s｜%s" % [str(source.get("purchase_cost_text", "")), str(source.get("play_cost_text", ""))],
			"effect": str(source.get("quick_effect_full", "")),
			"type": str(source.get("face_route_text", "")),
			"rank": str(source.get("rank_label", "I")),
			"accent": accent,
			"minimum_width": 230.0,
			"minimum_height": 300.0,
		},
		"summary": {
			"header_chips": [
				{"text": str(source.get("type_label", "卡牌")), "accent": accent, "tooltip": "卡牌类型"},
				{"text": str(source.get("icon_route_label", "通用路线")), "accent": Color("#c084fc"), "tooltip": "策略路线"},
				{"text": str(source.get("subtype_label", "通用")), "accent": Color("#93c5fd"), "tooltip": "子类型"},
			],
			"chips": _read_chips(source.get("read_chips", []) as Array, accent),
			"effect": "速读：%s｜%s" % [_short_text(str(source.get("strategy_use_text", "")), 38), _short_text(str(source.get("art_stats", "")), 44)],
			"effect_tooltip": str(source.get("full_effect_text", "")),
			"accent": accent,
		},
		"tactical_entries": _tactical_entries(source, accent, display_name),
		"facts": _fact_cards(source, accent),
		"upgrades": _upgrade_cards(source.get("upgrades", []) as Array),
		"resolution": {
			"title": "◇ 公开结算",
			"body": _short_text(str(source.get("resolution_animation_text", "")), 140),
			"meta": str(source.get("visibility_text", "卡面与合法公开回执可见；私密信息不进入资料库。")),
			"accent": Color("#fb7185"),
		},
	}
	var detail: Dictionary = DetailSnapshotScript.new().apply_dictionary(detail_source).to_ui_dictionary()
	return {"summary_text": summary_text, "detail": detail}


func debug_snapshot() -> Dictionary:
	return {
		"service_ready": _configured,
		"service_authoritative": _configured,
		"supported_domain": "card",
		"browser_compose_count": _browser_compose_count,
		"detail_compose_count": _detail_compose_count,
		"uses_existing_browser_viewmodel": true,
		"uses_existing_detail_viewmodel": true,
		"calculates_card_price": false,
		"calculates_card_effects": false,
		"calculates_play_requirements": false,
		"reads_runtime_nodes": false,
		"legacy_main_formatter_active": false,
	}


func _browser_card_source(source: Dictionary) -> Dictionary:
	var card_name := str(source.get("card_name", ""))
	var display_name := str(source.get("display_name", card_name))
	var accent := _color(source.get("accent", Color("#94a3b8")), Color("#94a3b8"))
	return {
		"card_name": card_name,
		"display_name": display_name,
		"title": "%s %s｜%s" % [str(source.get("icon", "◇")), str(source.get("family", card_name)), str(source.get("rank_label", "I"))],
		"title_tooltip": display_name,
		"art_text": "%s\n%s" % [display_name, str(source.get("tag_text", ""))],
		"kind": str(source.get("kind", "")),
		"rank": str(source.get("rank_label", "I")),
		"rank_number": maxi(1, int(source.get("rank", 1))),
		"card_stats": str(source.get("art_stats", "")),
		"card_art_stats": str(source.get("art_stats", "")),
		"chips": _read_chips(source.get("read_chips", []) as Array, accent).slice(0, 4),
		"use_case": str(source.get("use_case", "")),
		"table_use": str(source.get("use_case", "")),
		"route": _short_text(str(source.get("strategy_route_label", "")), 18),
		"route_tooltip": str(source.get("strategy_summary", "")),
		"effect": _short_text(str(source.get("quick_effect_compact", "")), 30),
		"effect_tooltip": str(source.get("full_effect_text", "")),
		"hint": "悬停预览｜双击详情",
		"tooltip": str(source.get("detail_tooltip", "")),
		"accent": accent,
		"index": int(source.get("index", 0)),
	}


func _browser_preview_source(source: Dictionary) -> Dictionary:
	if source.is_empty():
		return {}
	return {
		"title": "悬停预览：%s %s" % [str(source.get("icon", "◇")), str(source.get("display_name", source.get("card_name", "卡牌")))],
		"body": "路线：%s｜%s\nI→IV：%s" % [str(source.get("strategy_route_label", "")), str(source.get("rules_text_compact", "")).replace("\n", "｜"), str(source.get("level_gradient_text", "")).replace("\n", " / ")],
		"accent": _color(source.get("accent", Color("#38bdf8")), Color("#38bdf8")),
	}


func _tactical_entries(source: Dictionary, accent: Color, display_name: String) -> Array:
	return [
		{"title": "何时拿", "body": _tactical_timing_text(str(source.get("strategy_route_label", ""))), "accent": accent, "tip": str(source.get("strategy_use_text", ""))},
		{"title": "怎么配", "body": _tactical_combo_text(str(source.get("kind", "")), str(source.get("strategy_route_label", ""))), "accent": Color("#38bdf8"), "tip": "这张牌在牌组路线里的常见配合。"},
		{"title": "会暴露", "body": _tactical_clue_text(source), "accent": Color("#f472b6"), "tip": "只描述公开线索，不揭示隐藏玩家。%s" % display_name},
	]


func _fact_cards(source: Dictionary, accent: Color) -> Array:
	var target_text := str(source.get("target_text", "按卡面确定目标"))
	var numeric_facts := source.get("key_rule_facts", []) as Array
	return [
		{"title": "◎ 牌面定位", "body": _short_text(str(source.get("strategy_use_text", "")), 64), "meta": "%s｜%s｜%s｜%s" % [str(source.get("type_label", "卡牌")), str(source.get("subtype_label", "通用")), str(source.get("source_type_label", "资料库")), str(source.get("supply_layer", "公开牌池"))], "accent": accent},
		{"title": "¥ 获取与打出", "body": "%s｜%s" % [str(source.get("purchase_cost_text", "")), str(source.get("play_cost_text", ""))], "meta": "%s｜目标:%s" % [_short_text(str(source.get("timing_text", "")), 52), target_text], "accent": Color("#facc15")},
		{"title": "✦ 核心效果", "body": _short_text(str(source.get("full_effect_text", "")), 78), "body_tooltip": str(source.get("full_effect_text", "")), "meta": "%s｜%s" % [str(source.get("duration_text", "立即结算")), str(source.get("visibility_text", "公开回执"))], "accent": accent.lightened(0.12)},
		{"title": "◈ 关键数值", "body": _limited_names(numeric_facts, 5, "按核心效果结算。", "｜"), "meta": "看这里判断收益、风险和目标。", "accent": Color("#38bdf8")},
	]


func _upgrade_cards(entries: Array) -> Array:
	var result := []
	for entry_variant: Variant in entries:
		var entry := _dictionary(entry_variant)
		if entry.is_empty():
			continue
		var preview := str(entry.get("preview", ""))
		result.append({
			"roman": str(entry.get("roman", "")),
			"price": str(entry.get("purchase_cost_text", "")),
			"price_tooltip": "%s；同名同级牌可主动合并升级。" % str(entry.get("play_cost_text", "")),
			"band": str(entry.get("strength_band", "")),
			"body": _short_text(preview, 62),
			"body_tooltip": preview,
			"tooltip": "%s\n%s" % [str(entry.get("display_name", "卡牌")), str(entry.get("full_effect_text", ""))],
			"accent": _color(entry.get("accent", Color("#38bdf8")), Color("#38bdf8")),
			"fill_weight": float(entry.get("fill_weight", 0.10)),
		})
	return result


func _read_chips(entries: Array, fallback_accent: Color) -> Array:
	var chips := []
	for entry_variant: Variant in entries:
		var entry := _dictionary(entry_variant)
		var text_value := str(entry.get("text", ""))
		if text_value == "":
			continue
		var accent := _color(entry.get("accent", entry.get("fg", fallback_accent)), fallback_accent)
		chips.append({"text": text_value, "tooltip": str(entry.get("tooltip", entry.get("tip", ""))), "fg": _color(entry.get("fg", accent), accent), "bg": _color(entry.get("bg", Color("#020617").lerp(accent, 0.16)), Color("#020617").lerp(accent, 0.16)), "accent": accent})
	return chips


func _tactical_timing_text(route_label: String) -> String:
	match route_label:
		"商品牌": return "有同色工厂或市场槽位时领取并安装。"
		"公共设施牌": return "比较区域共享生命、供需和设施唯一槽后再建造。"
		"条件式供需牌": return "真实节点、合法路线和容量能够匹配时使用。"
		"怪兽单位牌": return "需要部署压力或升级同名怪兽时使用。"
		"军队单位牌": return "需要保护设施或执行公开军事行动时使用。"
		"玩家互动与反制牌": return "目标和响应窗口明确时使用，避免无效提交。"
		"组织牌": return "长期经营轴明确且组织槽可用时安装。"
	return "先确认获取费用、打出资产、目标与公开回执。"


func _tactical_combo_text(kind: String, route_label: String) -> String:
	if kind == "install_commodity_rate": return "配合同色公开设施，形成持续生产或需求。"
	if kind.contains("facility"): return "配合区域设施唯一槽、租金和共享生命。"
	if kind.contains("monster"): return "配合公开怪兽位置、等级和合法部署目标。"
	if kind.contains("military"): return "配合公开单位档案与显式军事动作。"
	if route_label == "组织牌": return "同家族仅最高阶生效，围绕一个长期经营轴构筑。"
	return "配合同产业资产与合法目标形成I→IV梯度。"


func _tactical_clue_text(source: Dictionary) -> String:
	var visibility := str(source.get("visibility_text", "卡面与合法公开回执可见"))
	if bool(source.get("targets_player", false)):
		return "目标玩家与合法公开结果可见；秘密手牌内容只对合法查看者显示。"
	if bool(source.get("targets_monster", false)):
		return "目标怪兽、位置和公开结果可见；内部权重与预选目标保持隐藏。"
	return visibility


func _limited_names(values: Array, limit: int, empty_text: String, separator: String = "、") -> String:
	var names := []
	for value: Variant in values:
		var text_value := str(value)
		if text_value != "": names.append(text_value)
		if names.size() >= maxi(1, limit): break
	return separator.join(names) if not names.is_empty() else empty_text


func _short_text(value: String, limit: int) -> String:
	if limit <= 0 or value.length() <= limit: return value
	return value.substr(0, maxi(0, limit - 1)) + "…"


func _dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


func _color(value: Variant, fallback: Color) -> Color:
	if value is Color: return value as Color
	if value is String and str(value).begins_with("#"): return Color(str(value))
	return fallback
