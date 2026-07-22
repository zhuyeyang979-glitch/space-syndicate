extends RefCounted
class_name CardCodexBrowserSnapshot

var browser: Dictionary = {}


func apply_dictionary(data: Dictionary) -> RefCounted:
	var names := _string_array(data.get("names", []))
	var total_count := names.size()
	var columns := clampi(int(data.get("columns", 3)), 1, 6)
	var rows := maxi(1, int(data.get("rows", 1)))
	var per_page := maxi(1, int(data.get("per_page", columns * rows)))
	var page_count := maxi(1, int(ceil(float(maxi(0, total_count)) / float(per_page))))
	var page_index := clampi(int(data.get("page_index", data.get("page", 0))), 0, max(0, page_count - 1))
	var start_index := page_index * per_page
	var end_index := mini(total_count, start_index + per_page)
	var selected_card := str(data.get("selected_card", data.get("preview_card", ""))).strip_edges()
	var selected_index := names.find(selected_card)
	if total_count > 0 and selected_index < 0:
		selected_index = clampi(start_index, 0, total_count - 1)
		selected_card = names[selected_index]
	elif total_count <= 0:
		selected_index = -1
		selected_card = ""
	var source_cards := _card_source_map(data.get("cards", []))
	var cards: Array = []
	for i in range(start_index, end_index):
		cards.append(_normalize_card(source_cards.get(names[i], {"card_name": names[i]}), i, selected_card))
	browser = {
		"legend": _legend_text(data),
		"legend_tooltip": _first_text(data, ["legend_tooltip"], "点筹码只看这一类牌；悬停卡牌看预览，双击进入详情。"),
		"columns": columns,
		"previous_text": _first_text(data, ["previous_text"], "缩略图上一页"),
		"next_text": _first_text(data, ["next_text"], "缩略图下一页"),
		"previous_disabled": page_count <= 1,
		"next_disabled": page_count <= 1,
		"page_text": "第%d/%d页｜%d张卡｜本页%d-%d" % [page_index + 1, page_count, total_count, start_index + 1 if total_count > 0 else 0, end_index],
		"filters": _normalize_filters(data.get("filters", []), str(data.get("filter_id", "all"))),
		"cards": cards,
		"preview": _normalize_preview(data.get("preview", {})),
		"tooltip": _first_text(data, ["tooltip"], "卡牌缩略图：筛选、悬停预览、双击详情。"),
		"page_index": page_index,
		"page_count": page_count,
		"selected_card": selected_card,
		"selected_index": selected_index,
	}
	return self


func to_ui_dictionary() -> Dictionary:
	return browser.duplicate(true)


func _legend_text(data: Dictionary) -> String:
	var explicit := _first_text(data, ["legend"], "")
	if explicit != "":
		return explicit
	var icon_legend := _first_text(data, ["icon_legend"], "")
	if icon_legend != "":
		return "牌型筛选｜%s" % icon_legend
	return "牌型筛选"


func _normalize_filters(entries_variant: Variant, active_filter_id: String) -> Array:
	var entries: Array = entries_variant if entries_variant is Array else []
	var result: Array = []
	for entry_variant in entries:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var filter_id := _first_text(entry, ["id", "filter_id"], "all")
		var label := _first_text(entry, ["label", "title"], filter_id)
		var short_label := _first_text(entry, ["short_label", "short", "text"], label)
		var icon := _first_text(entry, ["icon"], "")
		var count := int(entry.get("count", 0))
		var active := filter_id == active_filter_id or bool(entry.get("active", false))
		result.append({
			"id": filter_id,
			"text": "%s%s%s·%d" % ["●" if active else "", icon, short_label, count],
			"tooltip": "%s：%d张。点击后只看这一类。" % [label, count],
			"active": active,
			"disabled": count <= 0 or bool(entry.get("disabled", false)),
			"accent": entry.get("accent", Color("#93c5fd")),
		})
	return result


func _normalize_card(source_variant: Variant, card_index: int, selected_card: String) -> Dictionary:
	var source: Dictionary = source_variant if source_variant is Dictionary else {}
	var card_name := _first_text(source, ["card_name", "id", "name"], "")
	var rank_label := _first_text(source, ["rank", "stats", "level_text"], "I")
	var rank_number := _rank_number(source.get("rank_number", source.get("level", rank_label)))
	return {
		"card_name": card_name,
		"title": _first_text(source, ["title"], card_name),
		"title_tooltip": _first_text(source, ["title_tooltip", "display_name"], card_name),
		"display_name": _first_text(source, ["display_name", "title_tooltip"], card_name),
		"art_text": _first_text(source, ["art_text", "kind"], ""),
		"kind": _first_text(source, ["kind"], ""),
		"rank": rank_label,
		"rank_number": rank_number,
		"card_stats": _first_text(source, ["card_stats", "stats"], rank_label),
		"card_art_stats": _first_text(source, ["card_art_stats", "art_stats", "card_stats", "stats"], rank_label),
		"chips": _normalize_chips(source.get("chips", [])),
		"route": _first_text(source, ["route"], ""),
		"route_tooltip": _first_text(source, ["route_tooltip"], ""),
		"effect": _first_text(source, ["effect"], ""),
		"effect_tooltip": _first_text(source, ["effect_tooltip"], ""),
		"hint": _first_text(source, ["hint"], "悬停预览｜双击详情"),
		"tooltip": _first_text(source, ["tooltip"], ""),
		"accent": source.get("accent", Color("#94a3b8")),
		"illustration_key": _first_text(source, ["illustration_key"], ""),
		"selected": card_name == selected_card,
		"index": card_index,
	}


func _normalize_preview(preview_variant: Variant) -> Dictionary:
	if not (preview_variant is Dictionary):
		return {}
	var preview: Dictionary = preview_variant
	return {
		"title": _first_text(preview, ["title"], ""),
		"body": _first_text(preview, ["body", "detail"], ""),
		"accent": preview.get("accent", Color("#38bdf8")),
	}


func _normalize_chips(entries_variant: Variant) -> Array:
	var entries: Array = entries_variant if entries_variant is Array else []
	var result: Array = []
	for entry_variant in entries:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var text := _first_text(entry, ["text", "label"], "")
		if text == "":
			continue
		result.append({
			"text": text,
			"tooltip": _first_text(entry, ["tooltip", "tip"], ""),
			"fg": entry.get("fg", Color("#e2e8f0")),
			"accent": entry.get("accent", entry.get("fg", Color("#94a3b8"))),
		})
	return result


func _card_source_map(entries_variant: Variant) -> Dictionary:
	var entries: Array = entries_variant if entries_variant is Array else []
	var result := {}
	for entry_variant in entries:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var card_name := _first_text(entry, ["card_name", "id", "name"], "")
		if card_name != "":
			result[card_name] = entry
	return result


func _string_array(entries_variant: Variant) -> Array[String]:
	var entries: Array = entries_variant if entries_variant is Array else []
	var result: Array[String] = []
	for entry_variant in entries:
		var text := str(entry_variant).strip_edges()
		if text != "":
			result.append(text)
	return result


func _first_text(data: Dictionary, keys: Array, fallback: String) -> String:
	for key_variant in keys:
		var key := String(key_variant)
		if data.has(key):
			var value := str(data.get(key, "")).strip_edges()
			if value != "":
				return value
	return fallback


func _rank_number(value: Variant) -> int:
	if value is int or value is float:
		return maxi(1, int(value))
	var text := str(value).strip_edges().to_upper()
	match text:
		"I":
			return 1
		"II":
			return 2
		"III":
			return 3
		"IV":
			return 4
	return maxi(1, int(text))
