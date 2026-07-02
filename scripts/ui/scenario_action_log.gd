extends PanelContainer
class_name SpaceSyndicateScenarioActionLog

@onready var title_label: Label = %ScenarioActionLogTitle
@onready var entry_list: VBoxContainer = %ScenarioActionLogEntries


func _ready() -> void:
	add_theme_stylebox_override("panel", _panel_style(Color("#a78bfa")))


func set_log(data: Dictionary) -> void:
	visible = bool(data.get("visible", true))
	if not visible:
		return
	title_label.text = str(data.get("title", "剧本行动日志"))
	for child in entry_list.get_children():
		entry_list.remove_child(child)
		child.queue_free()
	var entries: Array = data.get("entries", []) if data.get("entries", []) is Array else []
	for entry_variant in entries:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var label := Label.new()
		label.name = "ScenarioActionLogEntry"
		label.text = "[%s] %s" % [str(entry.get("time", "00:00")), str(entry.get("text", ""))]
		label.tooltip_text = "快照：%s｜焦点：%s" % [str(entry.get("snapshot_key", "")), str(entry.get("focus_target", ""))]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", Color("#e2e8f0"))
		entry_list.add_child(label)


func _panel_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#020617").lerp(accent, 0.08)
	style.border_color = accent
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin(SIDE_LEFT, 8)
	style.set_content_margin(SIDE_TOP, 8)
	style.set_content_margin(SIDE_RIGHT, 8)
	style.set_content_margin(SIDE_BOTTOM, 8)
	return style
