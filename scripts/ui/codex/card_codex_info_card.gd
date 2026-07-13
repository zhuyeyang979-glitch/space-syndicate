extends PanelContainer
class_name SpaceSyndicateCardCodexInfoCard

@onready var tick: ColorRect = %CardCodexAttributeColorTick
@onready var title_label: Label = %CardCodexInfoCardTitle
@onready var body_label: Label = %CardCodexInfoCardBody
@onready var meta_label: Label = %CardCodexInfoCardMeta


func set_info(data: Dictionary, node_name: String = "CardCodexInfoCard") -> void:
	name = node_name
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var accent := _dictionary_color(data, "accent", Color("#38bdf8"))
	tooltip_text = str(data.get("tooltip", data.get("meta", "")))
	set_meta("card_codex_patterned_attribute", true)
	add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.10), 1, 8))
	tick.color = accent.lightened(0.12)
	title_label.name = "%sTitle" % node_name
	title_label.text = str(data.get("title", ""))
	title_label.add_theme_color_override("font_color", accent.lightened(0.18))
	body_label.name = "%sBody" % node_name
	body_label.text = str(data.get("body", ""))
	body_label.tooltip_text = str(data.get("body_tooltip", body_label.text))
	meta_label.name = "%sMeta" % node_name
	meta_label.text = str(data.get("meta", ""))
	meta_label.visible = meta_label.text != ""


func _card_style(accent: Color, fill: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = accent
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	style.shadow_size = 4
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
