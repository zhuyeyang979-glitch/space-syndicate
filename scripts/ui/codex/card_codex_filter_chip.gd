extends Button
class_name SpaceSyndicateCardCodexFilterChip

signal filter_selected(filter_id: String)

var _filter_id := ""


func _ready() -> void:
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)


func set_filter(data: Dictionary) -> void:
	_filter_id = str(data.get("id", ""))
	text = str(data.get("text", _filter_id))
	tooltip_text = str(data.get("tooltip", text))
	toggle_mode = true
	button_pressed = bool(data.get("active", false))
	disabled = bool(data.get("disabled", false))
	custom_minimum_size = Vector2(104, 34)
	_style_button(_dictionary_color(data, "accent", Color("#93c5fd")))


func filter_id() -> String:
	return _filter_id


func _on_pressed() -> void:
	if _filter_id == "":
		return
	filter_selected.emit(_filter_id)


func _style_button(accent: Color) -> void:
	add_theme_stylebox_override("normal", _card_style(accent, Color("#0b1220").lerp(accent, 0.10), 1, 8))
	add_theme_stylebox_override("hover", _card_style(accent.lightened(0.18), Color("#0b1220").lerp(accent, 0.18), 1, 8))
	add_theme_stylebox_override("pressed", _card_style(accent.lightened(0.28), Color("#020617").lerp(accent, 0.24), 1, 8))
	add_theme_stylebox_override("disabled", _card_style(Color("#334155"), Color("#020617"), 1, 8))
	add_theme_color_override("font_color", Color("#f8fafc"))
	add_theme_color_override("font_disabled_color", Color("#64748b"))
	add_theme_font_size_override("font_size", 13)


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
