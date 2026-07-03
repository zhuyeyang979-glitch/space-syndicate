extends RefCounted
class_name RightInspectorSnapshot

const ACTION_DOCK_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/action_dock_snapshot.gd")
const WHY_TEXT_CHAR_LIMIT := 48
const DETAIL_SUMMARY_CHAR_LIMIT := 44

var title: String = ""
var why_text: String = ""
var district: Dictionary = {}
var requirements: Array = []
var actions: Array = []
var logs: Array = []
var deep_links: Array = []


func apply_dictionary(data: Dictionary) -> RefCounted:
	title = str(data.get("title", data.get("mode", "桌边详情")))
	why_text = _summary_line(str(data.get("why", data.get("explanation", "选区后看用途、条件和下一步。"))), WHY_TEXT_CHAR_LIMIT)
	district = _normalize_context_panel(data.get("district", {}))
	requirements = _normalize_label_array(data.get("requirements", data.get("requirement_chips", [])), "条件")
	actions = ACTION_DOCK_SNAPSHOT_SCRIPT.new().apply_actions(data.get("actions", []), "行动").to_action_array()
	logs = data.get("logs", []) if data.get("logs", []) is Array else []
	deep_links = ACTION_DOCK_SNAPSHOT_SCRIPT.new().apply_actions(data.get("deep_links", data.get("details", [])), "详情").to_action_array()
	return self


func to_ui_dictionary() -> Dictionary:
	return {
		"title": title,
		"why": why_text,
		"district": district,
		"requirements": requirements,
		"actions": actions,
		"logs": logs,
		"deep_links": deep_links,
	}


func _normalize_label_array(value: Variant, fallback_label: String) -> Array:
	var source: Array = value if value is Array else []
	var result: Array = []
	for item in source:
		if item is Dictionary:
			result.append(item)
		else:
			result.append({"text": str(item)})
	if result.is_empty():
		result.append({"text": fallback_label})
	return result


func _normalize_context_panel(value: Variant) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var result := source.duplicate(true)
	var title_text := _first_nonempty(source, ["title", "name", "label"], "当前选区")
	var full_detail := _first_nonempty(source, ["full_detail", "body", "description", "detail", "summary"], "区域短说明会显示在这里。")
	var summary := _first_nonempty(source, ["summary", "short_detail", "headline"], "")
	if summary == "":
		summary = _summary_line(full_detail, DETAIL_SUMMARY_CHAR_LIMIT)
	result["title"] = title_text
	result["summary"] = summary
	result["detail"] = summary
	result["full_detail"] = full_detail
	result["detail_level"] = "summary"
	result["chips"] = source.get("chips", []) if source.get("chips", []) is Array else []
	return result


func _first_nonempty(source: Dictionary, keys: Array, fallback: String) -> String:
	for key_variant in keys:
		var key := String(key_variant)
		if source.has(key):
			var text := str(source[key]).replace("\n", " ").strip_edges()
			if text != "":
				return text
	return fallback


func _summary_line(value: String, max_chars: int) -> String:
	var clean := value.replace("\n", " ").strip_edges()
	if clean.length() <= max_chars:
		return clean
	return "%s..." % clean.substr(0, maxi(0, max_chars - 3))
