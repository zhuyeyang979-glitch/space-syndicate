extends RefCounted
class_name CardCodexDetailSnapshot

var detail: Dictionary = {}


func apply_dictionary(data: Dictionary) -> RefCounted:
	var accent: Color = data.get("accent", Color("#38bdf8")) if data.get("accent", Color("#38bdf8")) is Color else Color("#38bdf8")
	detail = {
		"accent": accent,
		"tooltip": _first_text(data, ["tooltip"], ""),
		"face_note": _first_text(data, ["face_note"], "同名同级→主动合并；价格看I级。"),
		"face_note_tooltip": _first_text(data, ["face_note_tooltip"], "资料库只展示公开卡面和公开规则，不展示隐藏牌主。"),
		"card_face": _normalize_card_face(data.get("card_face", {}), accent),
		"summary": _normalize_summary(data.get("summary", {}), accent),
		"tactical": _normalize_tactical(data.get("tactical", data.get("tactical_entries", [])), accent),
		"facts": _normalize_info_cards(data.get("facts", []), accent),
		"upgrade_title": _first_text(data, ["upgrade_title"], "I→IV 强化"),
		"upgrades": _normalize_upgrades(data.get("upgrades", []), accent),
		"resolution": _normalize_info_card(data.get("resolution", {}), Color("#fb7185")),
	}
	return self


func to_ui_dictionary() -> Dictionary:
	return detail.duplicate(true)


func _normalize_card_face(entry_variant: Variant, fallback_accent: Color) -> Dictionary:
	if not (entry_variant is Dictionary):
		return {}
	var entry: Dictionary = entry_variant
	if entry.is_empty():
		return {}
	var accent: Color = entry.get("accent", fallback_accent) if entry.get("accent", fallback_accent) is Color else fallback_accent
	return {
		"name": _first_text(entry, ["name", "title"], "未命名卡牌"),
		"cost": _first_text(entry, ["cost", "price"], ""),
		"effect": _first_text(entry, ["effect", "body"], ""),
		"type": _first_text(entry, ["type", "route"], ""),
		"rank": _first_text(entry, ["rank", "level"], ""),
		"accent": accent,
		"presentation": _first_text(entry, ["presentation", "display_mode"], "codex_full"),
		"minimum_width": float(entry.get("minimum_width", 292.0)),
		"minimum_height": float(entry.get("minimum_height", 390.0)),
	}


func _normalize_summary(summary_variant: Variant, fallback_accent: Color) -> Dictionary:
	var summary: Dictionary = summary_variant if summary_variant is Dictionary else {}
	var accent: Color = summary.get("accent", fallback_accent) if summary.get("accent", fallback_accent) is Color else fallback_accent
	return {
		"title": _first_text(summary, ["title"], "扫牌顺序"),
		"title_tooltip": _first_text(summary, ["title_tooltip"], "卡牌详情页先扫摘要，不需要先读完整规则。"),
		"tooltip": _first_text(summary, ["tooltip"], "像读桌游/TCG卡牌一样：先看费用、等级、门槛、目标和去向，再看核心效果。"),
		"header_chips": _normalize_chips(summary.get("header_chips", []), accent),
		"chips": _normalize_chips(summary.get("chips", []), accent),
		"effect": _first_text(summary, ["effect"], ""),
		"effect_tooltip": _first_text(summary, ["effect_tooltip", "tooltip_detail"], ""),
		"read_order": _first_text(summary, ["read_order"], "读法：费用 → 门槛 → 目标 → 去向 → 效果 → I-IV等级"),
		"accent": accent,
	}


func _normalize_tactical(tactical_variant: Variant, fallback_accent: Color) -> Dictionary:
	var tactical: Dictionary = {}
	if tactical_variant is Dictionary:
		tactical = tactical_variant
	elif tactical_variant is Array:
		tactical = {"entries": tactical_variant}
	var accent: Color = tactical.get("accent", fallback_accent) if tactical.get("accent", fallback_accent) is Color else fallback_accent
	return {
		"title": _first_text(tactical, ["title"], "牌桌用途｜先看这三格"),
		"title_tooltip": _first_text(tactical, ["title_tooltip"], "像读桌游卡一样，先判断拿牌时机、配合路线和公开线索。"),
		"tooltip": _first_text(tactical, ["tooltip"], "牌桌用途条：从玩家决策角度读这张牌，不显示隐藏信息。"),
		"entries": _normalize_info_cards(tactical.get("entries", []), accent),
		"accent": accent,
	}


func _normalize_upgrades(entries_variant: Variant, fallback_accent: Color) -> Array:
	var entries: Array = entries_variant if entries_variant is Array else []
	var result: Array = []
	for entry_variant in entries:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var accent: Color = entry.get("accent", fallback_accent) if entry.get("accent", fallback_accent) is Color else fallback_accent
		result.append({
			"roman": _first_text(entry, ["roman", "level"], ""),
			"price": _first_text(entry, ["price", "cost"], ""),
			"price_tooltip": _first_text(entry, ["price_tooltip"], "购买仍按该系列I级价格体系展示；同名同级牌可主动合并升级。"),
			"band": _first_text(entry, ["band", "meta"], ""),
			"body": _first_text(entry, ["body", "effect"], ""),
			"body_tooltip": _first_text(entry, ["body_tooltip", "tooltip"], _first_text(entry, ["body", "effect"], "")),
			"tooltip": _first_text(entry, ["tooltip"], ""),
			"accent": accent,
			"fill_weight": float(entry.get("fill_weight", 0.10)),
		})
	return result


func _normalize_info_cards(entries_variant: Variant, fallback_accent: Color) -> Array:
	var entries: Array = entries_variant if entries_variant is Array else []
	var result: Array = []
	for entry_variant in entries:
		result.append(_normalize_info_card(entry_variant, fallback_accent))
	return result.filter(func(entry: Dictionary) -> bool:
		return not entry.is_empty()
	)


func _normalize_info_card(entry_variant: Variant, fallback_accent: Color) -> Dictionary:
	if not (entry_variant is Dictionary):
		return {}
	var entry: Dictionary = entry_variant
	if entry.is_empty():
		return {}
	var accent: Color = entry.get("accent", fallback_accent) if entry.get("accent", fallback_accent) is Color else fallback_accent
	return {
		"title": _first_text(entry, ["title"], ""),
		"body": _first_text(entry, ["body", "effect"], ""),
		"body_tooltip": _first_text(entry, ["body_tooltip"], ""),
		"meta": _first_text(entry, ["meta"], ""),
		"tooltip": _first_text(entry, ["tooltip", "tip"], _first_text(entry, ["meta"], "")),
		"accent": accent,
	}


func _normalize_chips(entries_variant: Variant, fallback_accent: Color) -> Array:
	var entries: Array = entries_variant if entries_variant is Array else []
	var result: Array = []
	for entry_variant in entries:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var text := _first_text(entry, ["text", "label", "title"], "")
		if text == "":
			continue
		var accent: Color = entry.get("accent", fallback_accent) if entry.get("accent", fallback_accent) is Color else fallback_accent
		result.append({
			"text": text,
			"tooltip": _first_text(entry, ["tooltip", "tip"], ""),
			"fg": entry.get("fg", accent.lightened(0.16)),
			"bg": entry.get("bg", Color("#020617").lerp(accent, 0.16)),
			"accent": accent,
		})
	return result


func _first_text(data: Dictionary, keys: Array, fallback: String) -> String:
	for key_variant in keys:
		var key := String(key_variant)
		if data.has(key):
			var value := str(data.get(key, "")).strip_edges()
			if value != "":
				return value
	return fallback
