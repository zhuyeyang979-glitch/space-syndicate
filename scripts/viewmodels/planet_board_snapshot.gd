extends RefCounted
class_name PlanetBoardSnapshot

const DEFAULT_LEFT_TITLE := "地表情报"
const DEFAULT_RIGHT_TITLE := "外围压力"

const DEFAULT_LEFT_ENTRIES := [
	{"label": "星区", "value": "未扫描", "active": false, "accent": Color("#38bdf8"), "tooltip": "开局后显示公开星区数量。"},
	{"label": "选区", "value": "未选区", "active": false, "accent": Color("#facc15"), "tooltip": "点选中央星球区域后显示当前选区。"},
	{"label": "牌架", "value": "待查看", "active": false, "accent": Color("#c084fc"), "tooltip": "当前选区的公开牌架状态。"},
]

const DEFAULT_RIGHT_ENTRIES := [
	{"label": "怪兽", "value": "0", "active": false, "accent": Color("#fb7185"), "tooltip": "公开怪兽压力。"},
	{"label": "天气", "value": "平稳", "active": false, "accent": Color("#38bdf8"), "tooltip": "公开天气预报与当前天气。"},
	{"label": "牌轨", "value": "空闲", "active": false, "accent": Color("#f59e0b"), "tooltip": "公共牌轨和竞价节奏。"},
]

var title: String = ""
var hint: String = ""
var left_rail: Dictionary = {}
var right_rail: Dictionary = {}
var weather: Dictionary = {}
var flow_compass: Dictionary = {}


func apply_dictionary(data: Dictionary) -> RefCounted:
	title = _first_text(data, ["title", "name", "label"], "星球牌桌")
	hint = _first_text(data, ["hint", "summary", "subtitle"], "轨道外圈显示公开局势。")
	left_rail = _normalized_rail(
		_left_rail_source(data),
		DEFAULT_LEFT_TITLE,
		DEFAULT_LEFT_ENTRIES,
		Color("#38bdf8")
	)
	right_rail = _normalized_rail(
		_right_rail_source(data),
		DEFAULT_RIGHT_TITLE,
		DEFAULT_RIGHT_ENTRIES,
		Color("#f59e0b")
	)
	weather = _weather_source(data)
	flow_compass = _flow_compass_source(data)
	return self


func to_ui_dictionary() -> Dictionary:
	return {
		"title": title,
		"hint": hint,
		"left_rail": left_rail.duplicate(true),
		"right_rail": right_rail.duplicate(true),
		"weather": weather.duplicate(true),
		"flow_compass": flow_compass.duplicate(true),
	}


func _weather_source(data: Dictionary) -> Dictionary:
	var source: Dictionary = data.get("weather", {}) if data.get("weather", {}) is Dictionary else {}
	return {
		"active": _first_text(source, ["active", "active_text"], "现在：无天气"),
		"forecast": _first_text(source, ["forecast", "forecast_text"], "预报：开局后生成"),
		"impact": _first_text(source, ["impact", "impact_text"], "影响：产/交/消"),
		"tooltip": _first_text(source, ["tooltip", "hint"], ""),
	}


func _flow_compass_source(data: Dictionary) -> Dictionary:
	var source: Dictionary = data.get("flow_compass", {}) if data.get("flow_compass", {}) is Dictionary else {}
	var steps: Array = source.get("steps", ["点区", "首召", "建城", "买牌", "出牌"]) if source.get("steps", []) is Array else ["点区", "首召", "建城", "买牌", "出牌"]
	return {
		"title": _first_text(source, ["title", "label"], "试玩 罗盘"),
		"steps": steps,
		"tooltip": _first_text(source, ["tooltip", "hint"], "第一局只要顺着这条小轨走：点区、首召、建城、买牌、出牌。"),
	}


func _left_rail_source(data: Dictionary) -> Dictionary:
	var source := _first_rail_dictionary(data, ["left_rail", "public_intel_rail", "surface_rail"])
	if not source.is_empty():
		return source
	return {
		"title": DEFAULT_LEFT_TITLE,
		"entries": _first_rail_entries(data, ["left_entries", "public_intel", "surface_entries"], DEFAULT_LEFT_ENTRIES),
	}


func _right_rail_source(data: Dictionary) -> Dictionary:
	var source := _first_rail_dictionary(data, ["right_rail", "outer_pressure_rail", "space_rail"])
	if not source.is_empty():
		return source
	return {
		"title": DEFAULT_RIGHT_TITLE,
		"entries": _first_rail_entries(data, ["right_entries", "outer_pressure", "space_entries"], DEFAULT_RIGHT_ENTRIES),
	}


func _normalized_rail(source: Dictionary, fallback_title: String, fallback_entries: Array, fallback_accent: Color) -> Dictionary:
	var entries_source: Array = source.get("entries", source.get("items", [])) if source.get("entries", source.get("items", [])) is Array else []
	if entries_source.is_empty():
		entries_source = fallback_entries
	var entries: Array = []
	var index := 0
	for entry_variant in entries_source:
		index += 1
		entries.append(_normalized_entry(entry_variant, index, fallback_accent))
	return {
		"title": _first_text(source, ["title", "heading", "label"], fallback_title),
		"entries": entries,
	}


func _normalized_entry(entry_variant: Variant, index: int, fallback_accent: Color) -> Dictionary:
	var source: Dictionary = entry_variant if entry_variant is Dictionary else {}
	var fallback_label := str(entry_variant).strip_edges() if not (entry_variant is Dictionary) else "情报%d" % index
	if fallback_label == "" or fallback_label == "<null>":
		fallback_label = "情报%d" % index
	var value_text := _first_text(source, ["value", "state", "summary", "count"], "")
	return {
		"label": _short_text(_first_text(source, ["label", "title", "name", "text"], fallback_label), 8),
		"value": _short_text(value_text, 14),
		"active": bool(source.get("active", value_text.strip_edges() != "")),
		"accent": _accent_color(source, fallback_accent),
		"tooltip": _first_text(source, ["tooltip", "hint", "tip"], ""),
	}


func _first_rail_dictionary(data: Dictionary, keys: Array) -> Dictionary:
	for key_variant in keys:
		var key := String(key_variant)
		if not data.has(key):
			continue
		var value: Variant = data.get(key)
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {}


func _first_rail_entries(data: Dictionary, keys: Array, fallback: Array) -> Array:
	for key_variant in keys:
		var key := String(key_variant)
		if not data.has(key):
			continue
		var value: Variant = data.get(key)
		if value is Array:
			return value
	return fallback


func _first_text(data: Dictionary, keys: Array, fallback: String) -> String:
	for key_variant in keys:
		var key := String(key_variant)
		if data.has(key):
			var value := str(data.get(key, "")).replace("\n", " ").strip_edges()
			if value != "":
				return value
	return fallback


func _accent_color(entry: Dictionary, fallback: Color) -> Color:
	var accent_variant: Variant = entry.get("accent", null)
	if accent_variant is Color:
		return accent_variant
	if accent_variant is String:
		var accent_text := String(accent_variant).strip_edges()
		if accent_text.begins_with("#"):
			return Color(accent_text)
	return fallback


func _short_text(text: String, max_length: int) -> String:
	var value := text.strip_edges()
	if value.length() <= max_length:
		return value
	return "%s…" % value.substr(0, maxi(1, max_length - 1))
