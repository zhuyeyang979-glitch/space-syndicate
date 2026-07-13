extends PanelContainer
class_name SpaceSyndicateCodexBrowserSummaryCard

@onready var title_label: Label = %CodexBrowserSummaryTitle
@onready var body_label: Label = %CodexBrowserSummaryBody
@onready var meta_label: Label = %CodexBrowserSummaryMeta


func set_summary(data: Dictionary) -> void:
	var accent := _dictionary_color(data, "accent", Color("#38bdf8"))
	add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.09)))
	tooltip_text = str(data.get("tooltip", data.get("meta", data.get("body", ""))))
	title_label.text = str(data.get("title", "Overview"))
	title_label.add_theme_color_override("font_color", accent.lightened(0.16))
	body_label.text = str(data.get("body", ""))
	meta_label.text = str(data.get("meta", ""))
	meta_label.visible = not meta_label.text.strip_edges().is_empty()


func _card_style(accent: Color, fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = accent
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	return style


func _dictionary_color(data: Dictionary, key: String, fallback: Color) -> Color:
	var value: Variant = data.get(key, fallback)
	if value is Color:
		return value as Color
	var color_text := str(value)
	return Color(color_text) if Color.html_is_valid(color_text) else fallback
