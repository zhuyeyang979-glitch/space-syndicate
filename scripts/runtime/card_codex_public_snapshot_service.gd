@tool
extends Node
class_name CardCodexPublicSnapshotService

const BrowserSnapshotScript := preload(
	"res://scripts/viewmodels/card_codex_browser_snapshot.gd"
)
const DetailSnapshotScript := preload(
	"res://scripts/viewmodels/card_codex_detail_snapshot.gd"
)

var _configured := false
var _browser_compose_count := 0
var _detail_compose_count := 0


func configure(_config: Dictionary = {}) -> void:
	_configured = true


func compose_browser(source: Dictionary) -> Dictionary:
	_browser_compose_count += 1
	var names := source.get("names", []) as Array
	var card_sources: Array = []
	for card_variant in source.get("cards", []) as Array:
		if card_variant is Dictionary:
			card_sources.append(_browser_card_source(card_variant as Dictionary))
	var preview := _browser_preview_source(
		_dictionary(source.get("preview_card", {}))
	)
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
	var display_name := str(source.get("display_name", "卡牌"))
	var accent := _color(
		source.get("accent", Color("#38bdf8")),
		Color("#38bdf8")
	)
	var effect_steps := source.get("effect_step_texts", []) as Array
	var summary_text := "卡牌详情｜第%d/%d张｜%s %s\n%s｜%s｜%s｜%s\n时机：%s｜目标：%s" % [
		int(source.get("index", 0)) + 1,
		maxi(1, int(source.get("total", 1))),
		str(source.get("icon", "◇")),
		display_name,
		str(source.get("category_label", "卡牌")),
		str(source.get("industry_label", "通用")),
		str(source.get("acquisition_cost_text", "获取费用未公开")),
		str(source.get("activation_cost_text", "打出费用未公开")),
		str(source.get("timing_text", "语义信息不可用")),
		str(source.get("target_text", "语义信息不可用")),
	]
	var detail_source := {
		"accent": accent,
		"tooltip": _detail_tooltip(source),
		"face_note": "同名同级牌可主动合并升级；费用按等级分别展示。",
		"face_note_tooltip": "资料库只展示公开卡面和公开规则，不展示隐藏牌主。",
		"card_face": {
			"name": "%s %s" % [str(source.get("icon", "◇")), display_name],
			"cost": "%s｜%s" % [
				str(source.get("acquisition_cost_text", "")),
				str(source.get("activation_cost_text", "")),
			],
			"effect": str(source.get("full_effect_text", "")),
			"type": "%s｜%s" % [
				str(source.get("category_label", "卡牌")),
				str(source.get("industry_label", "通用")),
			],
			"rank": str(source.get("rank_label", "I")),
			"accent": accent,
			"illustration_key": str(source.get("illustration_key", "")),
			"presentation": "codex_full",
			"minimum_width": 230.0,
			"minimum_height": 300.0,
		},
		"summary": {
			"title": "规则摘要",
			"title_tooltip": "分别显示获取费用与打出费用。",
			"tooltip": "依次查看费用、时机、目标、条件与效果步骤。",
			"header_chips": [
				{
					"text": str(source.get("category_label", "卡牌")),
					"accent": accent,
					"tooltip": "卡牌类别",
				},
				{
					"text": str(source.get("industry_label", "通用")),
					"accent": Color("#93c5fd"),
					"tooltip": "产业",
				},
			],
			"chips": _read_chips(
				source.get("keyword_chips", []) as Array,
				accent
			),
			"effect": _short_text(
				str(source.get("short_effect_text", "")),
				96
			),
			"effect_tooltip": str(source.get("full_effect_text", "")),
			"read_order": "读法：获取费用 → 打出费用 → 时机 → 目标 → 条件 → 效果步骤",
			"accent": accent,
		},
		"tactical": {
			"title": "规则结构｜时机、目标与条件",
			"title_tooltip": "按顺序查看时机、目标、条件与效果。",
			"tooltip": "不根据卡名、类别或文案推测战术用途。",
			"entries": _structured_rule_entries(source, accent),
			"accent": accent,
		},
		"facts": _fact_cards(source, effect_steps, accent),
		"upgrades": _upgrade_cards(source.get("upgrades", []) as Array),
		"resolution": {
			"title": "◇ 反制与信息范围",
			"body": str(source.get("counterability_text", "语义信息不可用")),
			"meta": str(source.get("information_scope_text", "语义信息不可用")),
			"accent": Color("#fb7185"),
		},
	}
	var detail: Dictionary = DetailSnapshotScript.new() \
		.apply_dictionary(detail_source) \
		.to_ui_dictionary()
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
		"infers_tactical_advice": false,
		"reads_runtime_nodes": false,
		"legacy_main_formatter_active": false,
	}


func _browser_card_source(source: Dictionary) -> Dictionary:
	var display_name := str(source.get("display_name", ""))
	var accent := _color(
		source.get("accent", Color("#94a3b8")),
		Color("#94a3b8")
	)
	var route_label := "%s｜%s" % [
		str(source.get("category_label", "卡牌")),
		str(source.get("industry_label", "通用")),
	]
	return {
		"card_name": str(source.get("card_name", "")),
		"display_name": display_name,
		"title": "%s %s" % [str(source.get("icon", "◇")), display_name],
		"title_tooltip": display_name,
		"art_text": "%s\n%s" % [display_name, route_label],
		"kind": str(source.get("category_id", "")),
		"rank": str(source.get("rank_label", "I")),
		"rank_number": clampi(int(source.get("rank", 1)), 1, 4),
		"card_art_stats": "%s｜%s" % [
			str(source.get("timing_text", "")),
			str(source.get("duration_text", "")),
		],
		"chips": _read_chips(
			source.get("keyword_chips", []) as Array,
			accent
		).slice(0, 4),
		"route": _short_text(route_label, 22),
		"route_tooltip": route_label,
		"effect": _short_text(str(source.get("short_effect_text", "")), 36),
		"effect_tooltip": str(source.get("full_effect_text", "")),
		"hint": "悬停预览｜双击详情",
		"tooltip": _detail_tooltip(source),
		"accent": accent,
		"illustration_key": str(source.get("illustration_key", "")),
		"index": int(source.get("index", 0)),
	}


func _browser_preview_source(source: Dictionary) -> Dictionary:
	if source.is_empty():
		return {}
	var ladder_text := _family_ladder_preview(
		source.get("family_ladder", []) as Array
	)
	var body_lines: Array[String] = [
		"%s｜%s" % [
			str(source.get("acquisition_cost_text", "")),
			str(source.get("activation_cost_text", "")),
		],
		"时机：%s｜目标：%s" % [
			str(source.get("timing_text", "")),
			str(source.get("target_text", "")),
		],
		str(source.get("short_effect_text", "")),
	]
	if not ladder_text.is_empty():
		body_lines.append("I→IV：%s" % ladder_text)
	return {
		"title": "悬停预览：%s %s" % [
			str(source.get("icon", "◇")),
			str(source.get("display_name", "卡牌")),
		],
		"body": "\n".join(body_lines),
		"accent": _color(
			source.get("accent", Color("#38bdf8")),
			Color("#38bdf8")
		),
	}


func _structured_rule_entries(source: Dictionary, accent: Color) -> Array:
	var conditions := source.get("condition_texts", []) as Array
	return [
		{
			"title": "出牌时机",
			"body": str(source.get("timing_text", "语义信息不可用")),
			"accent": accent,
			"tooltip": "此卡允许使用的出牌窗口。",
		},
		{
			"title": "目标",
			"body": str(source.get("target_text", "语义信息不可用")),
			"accent": Color("#38bdf8"),
			"tooltip": "此卡生效时可以选择的对象。",
		},
		{
			"title": "条件",
			"body": _limited_names(conditions, 4, "无额外条件", "；"),
			"accent": Color("#f472b6"),
			"tooltip": "使用或结算此卡必须满足的条件。",
		},
	]


func _fact_cards(source: Dictionary, effect_steps: Array, accent: Color) -> Array:
	return [
		{
			"title": "¥ 获取与打出",
			"body": "%s｜%s" % [
				str(source.get("acquisition_cost_text", "")),
				str(source.get("activation_cost_text", "")),
			],
			"meta": "费用始终分开显示。",
			"accent": Color("#facc15"),
		},
		{
			"title": "✦ 按序效果",
			"body": _ordered_steps_text(effect_steps, 5),
			"body_tooltip": _ordered_steps_text(effect_steps, effect_steps.size()),
			"meta": "%d 个效果步骤" % effect_steps.size(),
			"accent": accent.lightened(0.12),
		},
		{
			"title": "◷ 持续与反制",
			"body": "%s｜%s" % [
				str(source.get("duration_text", "")),
				str(source.get("counterability_text", "")),
			],
			"meta": "同时列出持续时间与可反制状态。",
			"accent": Color("#38bdf8"),
		},
		{
			"title": "◈ 信息范围",
			"body": str(source.get("information_scope_text", "")),
			"meta": "说明此卡打出后会公开哪些信息。",
			"accent": Color("#fb7185"),
		},
	]


func _upgrade_cards(entries: Array) -> Array:
	var result: Array = []
	for entry_variant in entries:
		var entry := _dictionary(entry_variant)
		if entry.is_empty():
			continue
		var effect_steps := entry.get("effect_step_texts", []) as Array
		var activation_text := str(entry.get("activation_cost_text", ""))
		result.append({
			"roman": str(entry.get("rank_label", "")),
			"price": str(entry.get("acquisition_cost_text", "")),
			"price_tooltip": "打出费用：%s" % activation_text,
			"band": "%s｜目标：%s" % [
				str(entry.get("duration_text", "")),
				str(entry.get("target_text", "")),
			],
			"body": _ordered_steps_text(effect_steps, 3),
			"body_tooltip": _ordered_steps_text(effect_steps, effect_steps.size()),
			"tooltip": "%s\n%s\n%s" % [
				str(entry.get("display_name", "卡牌")),
				activation_text,
				str(entry.get("full_effect_text", "")),
			],
			"accent": _color(
				entry.get("accent", Color("#38bdf8")),
				Color("#38bdf8")
			),
			"fill_weight": 0.10 + 0.03 * float(
				clampi(int(entry.get("rank", 1)), 1, 4) - 1
			),
		})
	return result


func _read_chips(entries: Array, fallback_accent: Color) -> Array:
	var chips: Array = []
	for entry_variant in entries:
		var entry := _dictionary(entry_variant)
		var text_value := str(entry.get("text", ""))
		if text_value == "":
			continue
		var accent := _color(entry.get("accent", fallback_accent), fallback_accent)
		chips.append({
			"text": text_value,
			"tooltip": str(entry.get("tooltip", "")),
			"fg": _color(entry.get("fg", accent), accent),
			"bg": _color(
				entry.get("bg", Color("#020617").lerp(accent, 0.16)),
				Color("#020617").lerp(accent, 0.16)
			),
			"accent": accent,
		})
	return chips


func _family_ladder_preview(entries: Array) -> String:
	var rows: Array[String] = []
	for entry_variant in entries:
		var entry := _dictionary(entry_variant)
		if entry.is_empty():
			continue
		rows.append("%s %s" % [
			str(entry.get("rank_label", "")),
			str(entry.get("acquisition_cost_text", "")),
		])
	return " / ".join(rows)


func _detail_tooltip(source: Dictionary) -> String:
	return "%s\n%s｜%s\n时机：%s\n目标：%s\n%s" % [
		str(source.get("display_name", "卡牌")),
		str(source.get("acquisition_cost_text", "")),
		str(source.get("activation_cost_text", "")),
		str(source.get("timing_text", "")),
		str(source.get("target_text", "")),
		str(source.get("full_effect_text", "")),
	]


func _ordered_steps_text(values: Array, limit: int) -> String:
	var rows: Array[String] = []
	var row_limit := mini(values.size(), maxi(0, limit))
	for index in range(row_limit):
		rows.append("%d. %s" % [index + 1, str(values[index])])
	return "\n".join(rows) if not rows.is_empty() else "语义信息不可用"


func _limited_names(
	values: Array,
	limit: int,
	empty_text: String,
	separator: String = "、"
) -> String:
	var names: Array[String] = []
	for value in values:
		var text_value := str(value)
		if text_value != "":
			names.append(text_value)
		if names.size() >= maxi(1, limit):
			break
	return separator.join(names) if not names.is_empty() else empty_text


func _short_text(value: String, limit: int) -> String:
	if limit <= 0 or value.length() <= limit:
		return value
	return value.substr(0, maxi(0, limit - 1)) + "…"


func _dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


func _color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value as Color
	if value is String and str(value).begins_with("#"):
		return Color(str(value))
	return fallback
