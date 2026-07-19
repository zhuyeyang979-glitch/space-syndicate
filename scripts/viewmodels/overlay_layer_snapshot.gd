extends RefCounted
class_name OverlayLayerSnapshot

const ACTION_DOCK_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/action_dock_snapshot.gd")

var side_drawer: Dictionary = {}


func apply_side_drawer(action_id: String, inspector: Dictionary) -> RefCounted:
	var district: Dictionary = inspector.get("district", {}) if inspector.get("district", {}) is Dictionary else {}
	var body_lines := _side_drawer_body_lines(inspector, district)
	var chips: Array = []
	_append_drawer_chips(chips, district.get("chips", []))
	_append_drawer_chips(chips, inspector.get("requirements", []))
	var sections := _side_drawer_sections(inspector, district)
	side_drawer = {
		"title": _drawer_title_for_action(action_id, inspector, district),
		"body": "\n\n".join(body_lines),
		"sections": sections,
		"chips": chips,
		"actions": ACTION_DOCK_SNAPSHOT_SCRIPT.new().apply_actions(_drawer_codex_links(action_id, inspector), "").to_action_array(),
	}
	return self


func apply_side_drawer_dictionary(data: Dictionary) -> RefCounted:
	side_drawer = {
		"title": _first_text(data, ["title", "heading"], "详情抽屉"),
		"body": _first_text(data, ["body", "summary", "detail"], ""),
		"sections": _normalize_sections(data.get("sections", [])),
		"chips": _normalize_chips(data.get("chips", [])),
		"actions": ACTION_DOCK_SNAPSHOT_SCRIPT.new().apply_actions(data.get("actions", data.get("links", [])), "").to_action_array(),
	}
	return self


func to_side_drawer_dictionary() -> Dictionary:
	return side_drawer.duplicate(true)


func _side_drawer_body_lines(inspector: Dictionary, district: Dictionary) -> Array[String]:
	var body_lines: Array[String] = []
	var district_title := str(district.get("title", "")).strip_edges()
	var district_summary := str(district.get("summary", "")).strip_edges()
	var district_detail := str(district.get("full_detail", district.get("detail", ""))).strip_edges()
	var why := str(inspector.get("why", "")).strip_edges()
	if district_title != "":
		body_lines.append(district_title)
	if why != "":
		body_lines.append("原因：%s" % why)
	if district_summary != "" and district_summary != district_detail:
		body_lines.append(district_summary)
	if district_detail != "":
		body_lines.append(district_detail)
	var logs: Array = inspector.get("logs", []) if inspector.get("logs", []) is Array else []
	if not logs.is_empty():
		var log_lines: Array[String] = []
		for log_variant in logs.slice(maxi(0, logs.size() - 4), logs.size()):
			log_lines.append("- %s" % str(log_variant))
		body_lines.append("公开日志：\n%s" % "\n".join(log_lines))
	return body_lines


func _side_drawer_sections(inspector: Dictionary, district: Dictionary) -> Array:
	var result: Array = []
	var district_title := str(district.get("title", "")).strip_edges()
	var district_summary := str(district.get("summary", "")).strip_edges()
	var district_detail := str(district.get("full_detail", district.get("detail", ""))).strip_edges()
	var why := str(inspector.get("why", "")).strip_edges()
	if district_title != "":
		result.append({"title": "对象", "body": district_title, "accent": Color("#38bdf8")})
	if why != "":
		result.append({"title": "原因", "body": why, "accent": Color("#facc15")})
	if district_summary != "" and district_summary != district_detail:
		result.append({"title": "桌面摘要", "body": district_summary, "accent": Color("#22c55e")})
	if district_detail != "":
		result.append({"title": "完整详情", "body": district_detail, "accent": Color("#c084fc")})
	var logs: Array = inspector.get("logs", []) if inspector.get("logs", []) is Array else []
	if not logs.is_empty():
		var log_lines: Array[String] = []
		for log_variant in logs.slice(maxi(0, logs.size() - 4), logs.size()):
			log_lines.append("- %s" % str(log_variant))
		result.append({"title": "公开日志", "body": "\n".join(log_lines), "accent": Color("#94a3b8")})
	return result


func _drawer_title_for_action(action_id: String, inspector: Dictionary, district: Dictionary) -> String:
	match action_id:
		"codex_region", "detail_region":
			return "区域详情"
		"codex_cards", "codex_card", "detail_cards", "detail_card":
			return "卡牌详情"
		"inspect":
			return "桌面详情"
	var inspector_title := _first_text(inspector, ["title"], "详情抽屉")
	var district_title := _first_text(district, ["title"], "")
	if district_title != "":
		return "%s | %s" % [inspector_title, district_title]
	return inspector_title


func _drawer_codex_links(action_id: String, inspector: Dictionary) -> Array:
	match action_id:
		"detail_region", "codex_region":
			return [{"id": "codex_region", "label": "打开区域图鉴"}]
		"detail_cards", "detail_card", "codex_cards", "codex_card":
			return [{"id": "codex_cards", "label": "打开卡牌图鉴"}]
	var links: Array = inspector.get("deep_links", []) if inspector.get("deep_links", []) is Array else []
	var result: Array = []
	for link_variant in links:
		if not (link_variant is Dictionary):
			continue
		var link: Dictionary = link_variant
		var link_id := str(link.get("id", ""))
		match link_id:
			"detail_region":
				result.append({"id": "codex_region", "label": "打开区域图鉴"})
			"detail_cards", "detail_card":
				result.append({"id": "codex_cards", "label": "打开卡牌图鉴"})
			_:
				if link_id.begins_with("codex"):
					result.append(link)
	if result.is_empty():
		result = [
			{"id": "codex_region", "label": "打开区域图鉴"},
			{"id": "codex_cards", "label": "打开卡牌图鉴"},
		]
	return result


func _append_drawer_chips(target: Array, entries_variant: Variant) -> void:
	for chip in _normalize_chips(entries_variant):
		target.append(chip)


func _normalize_chips(entries_variant: Variant) -> Array:
	var entries: Array = entries_variant if entries_variant is Array else []
	var result: Array = []
	for entry_variant in entries:
		if entry_variant is Dictionary:
			var entry: Dictionary = entry_variant
			var text := _first_text(entry, ["text", "label", "title"], "")
			if text != "":
				result.append({"text": text, "tooltip": _first_text(entry, ["tooltip", "hint"], "")})
		else:
			var value := str(entry_variant).strip_edges()
			if value != "":
				result.append({"text": value, "tooltip": ""})
	return result


func _normalize_sections(entries_variant: Variant) -> Array:
	var entries: Array = entries_variant if entries_variant is Array else []
	var result: Array = []
	for entry_variant in entries:
		if entry_variant is Dictionary:
			var entry: Dictionary = entry_variant
			var body := _first_text(entry, ["body", "text", "detail", "summary"], "")
			if body != "":
				result.append({
					"title": _first_text(entry, ["title", "label"], ""),
					"body": body,
					"tooltip": _first_text(entry, ["tooltip", "hint"], ""),
					"accent": _entry_color(entry, Color("#38bdf8")),
				})
		else:
			var value := str(entry_variant).strip_edges()
			if value != "":
				result.append({"title": "", "body": value, "tooltip": "", "accent": Color("#38bdf8")})
	return result


func _entry_color(entry: Dictionary, fallback: Color) -> Color:
	var value: Variant = entry.get("accent", entry.get("color", fallback))
	if value is Color:
		return value as Color
	if value is String and str(value).begins_with("#"):
		return Color(str(value))
	return fallback


func _first_text(data: Dictionary, keys: Array, fallback: String) -> String:
	for key_variant in keys:
		var key := String(key_variant)
		if data.has(key):
			var value := str(data.get(key, "")).replace("\n", " ").strip_edges()
			if value != "":
				return value
	return fallback
