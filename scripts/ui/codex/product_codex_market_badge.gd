extends PanelContainer
class_name SpaceSyndicateProductCodexMarketBadge

@onready var glyph_label: Label = %ProductCodexMarketGlyph
@onready var name_label: Label = %ProductCodexMarketBadgeName
@onready var profile_label: Label = %ProductCodexMarketProfileLine
@onready var terrain_label: Label = %ProductCodexMarketTerrainLine
@onready var price_label: Label = %ProductCodexMarketPriceLine
@onready var meter_label: Label = %ProductCodexMarketMeter
@onready var weather_label: Label = %ProductCodexMarketWeatherLine
@onready var use_label: Label = %ProductCodexMarketUseLine


func set_badge(data: Dictionary, fallback_accent: Color = Color("#22c55e"), fallback_secondary: Color = Color("#f8fafc")) -> void:
	var accent := _dictionary_color(data, "accent", fallback_accent)
	var secondary := _dictionary_color(data, "secondary", fallback_secondary)
	var selected := bool(data.get("selected", false))
	custom_minimum_size = Vector2(210, 206)
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	add_theme_stylebox_override("panel", _card_style(secondary if selected else accent, Color("#0b1120").lerp(accent, 0.18), 3 if selected else 2, 8))
	glyph_label.text = str(data.get("glyph", "◇"))
	glyph_label.add_theme_color_override("font_color", secondary)
	name_label.text = str(data.get("name", "Product"))
	profile_label.text = str(data.get("profile", "Product | trade line"))
	terrain_label.text = str(data.get("terrain", "Terrain: Any"))
	price_label.text = str(data.get("price", "$0 | base $0 | stable"))
	meter_label.text = str(data.get("meter", "Supply 0 Demand 0 Risk 0 Vol 0"))
	var weather_text := str(data.get("weather", "No weather pressure"))
	weather_label.text = _short_text(weather_text, 76)
	weather_label.tooltip_text = weather_text
	var use_text := str(data.get("use", "Read supply, contracts, storage, and monster preference."))
	use_label.text = _short_text(use_text, 72)
	use_label.tooltip_text = use_text


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
