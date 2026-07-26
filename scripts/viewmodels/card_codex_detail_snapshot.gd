extends RefCounted
class_name CardCodexDetailSnapshot

var detail: Dictionary = {}


func apply_dictionary(data: Dictionary) -> RefCounted:
	var accent: Color = data.get("accent", Color("#38bdf8")) if data.get("accent", Color("#38bdf8")) is Color else Color("#38bdf8")
	detail = {
		"accent": accent,
		"tooltip": _text(data, "tooltip", ""),
		"face_note": _text(data, "face_note", "同名同级牌可主动合并升级；费用按等级分别展示。"),
		"face_note_tooltip": _text(data, "face_note_tooltip", "资料库只展示公开卡面和公开规则，不展示隐藏牌主。"),
		"card_face": _normalize_card_face(data.get("card_face", {}), accent),
		"summary": _normalize_summary(data.get("summary", {}), accent),
		"tactical": _normalize_tactical(data.get("tactical", {}), accent),
		"facts": _normalize_info_cards(data.get("facts", []), accent),
		"upgrade_title": _text(data, "upgrade_title", "I→IV 强化"),
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
		"name": _text(entry, "name", "未命名卡牌"),
		"cost": _text(entry, "cost", ""),
		"effect": _text(entry, "effect", ""),
		"type": _text(entry, "type", ""),
		"rank": _text(entry, "rank", ""),
		"accent": accent,
		"illustration_key": _text(entry, "illustration_key", ""),
		"presentation": _text(entry, "presentation", "codex_full"),
		"minimum_width": float(entry.get("minimum_width", 292.0)),
		"minimum_height": float(entry.get("minimum_height", 390.0)),
	}


func _normalize_summary(summary_variant: Variant, fallback_accent: Color) -> Dictionary:
	var summary: Dictionary = summary_variant if summary_variant is Dictionary else {}
	var accent: Color = summary.get("accent", fallback_accent) if summary.get("accent", fallback_accent) is Color else fallback_accent
	return {
		"title": _text(summary, "title", "规则摘要"),
		"title_tooltip": _text(summary, "title_tooltip", "分别显示获取费用与打出费用。"),
		"tooltip": _text(summary, "tooltip", "依次查看费用、时机、目标、条件与效果步骤。"),
		"header_chips": _normalize_chips(summary.get("header_chips", []), accent),
		"chips": _normalize_chips(summary.get("chips", []), accent),
		"effect": _text(summary, "effect", ""),
		"effect_tooltip": _text(summary, "effect_tooltip", ""),
		"read_order": _text(summary, "read_order", "读法：获取费用 → 打出费用 → 时机 → 目标 → 条件 → 效果步骤"),
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
		"title": _text(tactical, "title", "规则结构｜时机、目标与条件"),
		"title_tooltip": _text(tactical, "title_tooltip", "按顺序查看时机、目标、条件与效果。"),
		"tooltip": _text(tactical, "tooltip", "不根据卡名、类别或文案推测战术用途。"),
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
			"roman": _text(entry, "roman", ""),
			"price": _text(entry, "price", ""),
			"price_tooltip": _text(entry, "price_tooltip", "获取费用与打出费用按当前等级分别展示。"),
			"band": _text(entry, "band", ""),
			"body": _text(entry, "body", ""),
			"body_tooltip": _text(entry, "body_tooltip", _text(entry, "body", "")),
			"tooltip": _text(entry, "tooltip", ""),
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
		"title": _text(entry, "title", ""),
		"body": _text(entry, "body", ""),
		"body_tooltip": _text(entry, "body_tooltip", ""),
		"meta": _text(entry, "meta", ""),
		"tooltip": _text(entry, "tooltip", _text(entry, "meta", "")),
		"accent": accent,
	}


func _normalize_chips(entries_variant: Variant, fallback_accent: Color) -> Array:
	var entries: Array = entries_variant if entries_variant is Array else []
	var result: Array = []
	for entry_variant in entries:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var text := _text(entry, "text", "")
		if text == "":
			continue
		var accent: Color = entry.get("accent", fallback_accent) if entry.get("accent", fallback_accent) is Color else fallback_accent
		result.append({
			"text": text,
			"tooltip": _text(entry, "tooltip", ""),
			"fg": entry.get("fg", accent.lightened(0.16)),
			"bg": entry.get("bg", Color("#020617").lerp(accent, 0.16)),
			"accent": accent,
		})
	return result


func _text(data: Dictionary, key: String, fallback: String) -> String:
	var value := str(data.get(key, "")).strip_edges()
	return value if value != "" else fallback
