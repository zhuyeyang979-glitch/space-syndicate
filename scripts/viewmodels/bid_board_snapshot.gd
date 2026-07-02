extends RefCounted
class_name BidBoardSnapshot

var title := ""
var phase := ""
var phase_tooltip := ""
var status := ""
var status_tooltip := ""
var active := false
var visible := true
var accent := Color("#f59e0b")
var chips: Array = []
var track_links: Array = []
var actions: Array = []


func apply_dictionary(data: Dictionary) -> RefCounted:
	title = _first_text(data, ["title", "name"], "公开竞价")
	phase = _first_text(data, ["phase", "state"], "预设")
	phase_tooltip = _first_text(data, ["phase_tooltip", "tooltip"], "")
	status = _first_text(data, ["status", "summary", "detail"], "下一张牌可预设报价。")
	status_tooltip = _first_text(data, ["status_tooltip", "tooltip"], status)
	active = bool(data.get("active", false))
	visible = bool(data.get("visible", true))
	accent = _entry_color(data, Color("#f59e0b"))
	chips = _normalize_chips(data.get("chips", []))
	track_links = _normalize_chips(data.get("track_links", data.get("track", [])))
	actions = _normalize_actions(data.get("actions", []))
	return self


func to_ui_dictionary() -> Dictionary:
	return {
		"title": title,
		"phase": phase,
		"phase_tooltip": phase_tooltip,
		"status": status,
		"status_tooltip": status_tooltip,
		"active": active,
		"visible": visible,
		"accent": accent,
		"chips": _duplicate_array(chips),
		"track_links": _duplicate_array(track_links),
		"actions": _duplicate_array(actions),
	}


func _normalize_chips(entries_variant: Variant) -> Array:
	var entries: Array = entries_variant if entries_variant is Array else []
	var result: Array = []
	for entry_variant in entries:
		var entry: Dictionary = entry_variant if entry_variant is Dictionary else {"text": str(entry_variant)}
		result.append({
			"id": _first_text(entry, ["id", "action_id", "key"], ""),
			"label": _first_text(entry, ["label", "text", "name"], "状态"),
			"state": _first_text(entry, ["state", "value", "status"], ""),
			"active": bool(entry.get("active", false)),
			"selected": bool(entry.get("selected", entry.get("focused", false))),
			"accent": _entry_color(entry, Color("#94a3b8")),
			"tooltip": _first_text(entry, ["tooltip", "tip", "why"], ""),
			"max_chars": int(entry.get("max_chars", 9)),
		})
	return result


func _normalize_actions(entries_variant: Variant) -> Array:
	var entries: Array = entries_variant if entries_variant is Array else []
	var result: Array = []
	for entry_variant in entries:
		var entry: Dictionary = entry_variant if entry_variant is Dictionary else {}
		var label := _first_text(entry, ["label", "text", "name"], "行动")
		result.append({
			"id": _first_text(entry, ["id", "action_id", "key"], label),
			"label": _short_text(label, 8),
			"disabled": bool(entry.get("disabled", false)),
			"active": bool(entry.get("active", not bool(entry.get("disabled", false)))),
			"accent": _entry_color(entry, Color("#fde68a")),
			"tooltip": _first_text(entry, ["tooltip", "tip", "why"], ""),
		})
	return result


func _first_text(data: Dictionary, keys: Array, fallback: String) -> String:
	for key_variant in keys:
		var key := String(key_variant)
		if data.has(key):
			var value := str(data.get(key, "")).replace("\n", " ").strip_edges()
			if value != "":
				return value
	return fallback


func _entry_color(entry: Dictionary, fallback: Color) -> Color:
	var value: Variant = entry.get("accent", fallback)
	if value is Color:
		return value
	if value is String and str(value).begins_with("#"):
		return Color(str(value))
	return fallback


func _short_text(value: String, limit: int) -> String:
	var text := value.strip_edges()
	if text.length() <= limit:
		return text
	return "%s..." % text.left(maxi(1, limit - 3))


func _duplicate_array(values: Array) -> Array:
	var result: Array = []
	for value in values:
		if value is Dictionary:
			result.append((value as Dictionary).duplicate(true))
		else:
			result.append(value)
	return result
