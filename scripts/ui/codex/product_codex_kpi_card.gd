extends PanelContainer
class_name SpaceSyndicateProductCodexKpiCard

@onready var title_label: Label = %ProductCodexMarketKpiTitle
@onready var value_label: Label = %ProductCodexMarketKpiValue
@onready var meta_label: Label = %ProductCodexMarketKpiMeta


func set_kpi(data: Dictionary) -> void:
	var accent := _dictionary_color(data, "accent", Color("#22c55e"))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0, 82)
	tooltip_text = str(data.get("tooltip", "%s | %s | %s" % [data.get("title", ""), data.get("value", ""), data.get("meta", "")]))
	add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.10), 1, 8))
	title_label.text = str(data.get("title", ""))
	title_label.add_theme_color_override("font_color", accent.lightened(0.18))
	var value_text := str(data.get("value", ""))
	value_label.text = _short_text(value_text, 34)
	value_label.tooltip_text = value_text
	var meta_text := str(data.get("meta", ""))
	meta_label.text = _short_text(meta_text, 42)
	meta_label.tooltip_text = meta_text


func _card_style(accent: Color, fill: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = accent
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func _dictionary_color(data: Dictionary, key: String, fallback: Color) -> Color:
	var value: Variant = data.get(key, fallback)
	if value is Color:
		return value as Color
	if value is String:
		var text_value := str(value)
		if text_value.begins_with("#"):
			return Color(text_value)
	return fallback


func _short_text(value: String, limit: int) -> String:
	if limit <= 0 or value.length() <= limit:
		return value
	return value.substr(0, max(0, limit - 1)) + "..."
