extends PanelContainer
class_name SpaceSyndicateBestiaryMonsterHeaderCard

@onready var title_label: Label = %BestiaryMonsterHeaderTitle
@onready var subtitle_label: Label = %BestiaryMonsterHeaderSubtitle
@onready var art_view: Control = %BestiaryMonsterHeaderArtView


func set_header(data: Dictionary) -> void:
	var accent := _dictionary_color(data, "accent", Color("#fb7185"))
	tooltip_text = str(data.get("tooltip", "Monster reference header."))
	add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.10), 1, 8))
	title_label.text = str(data.get("title", "Monster File"))
	var subtitle := str(data.get("subtitle", "Autonomous monster."))
	subtitle_label.text = _short_text(subtitle, 96)
	subtitle_label.tooltip_text = subtitle
	subtitle_label.add_theme_color_override("font_color", accent.lightened(0.18))
	var art_variant: Variant = data.get("art", {})
	var art := art_variant as Dictionary if art_variant is Dictionary else {}
	var profile_variant: Variant = art.get("profile", {})
	var profile := profile_variant as Dictionary if profile_variant is Dictionary else {}
	if not profile.has("accent"):
		profile["accent"] = accent
	if art_view != null and art_view.has_method("set_monster"):
		art_view.call(
			"set_monster",
			str(art.get("name", data.get("title", "Monster"))),
			str(art.get("style", subtitle)),
			int(art.get("hp", 0)),
			int(art.get("armor", 0)),
			str(art.get("move_text", "")),
			profile,
			true
		)


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
