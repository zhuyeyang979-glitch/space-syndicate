extends PanelContainer
class_name SpaceSyndicateBestiaryMonsterActionCard

@onready var index_label: Label = %BestiaryMonsterActionIndex
@onready var name_label: Label = %BestiaryMonsterActionName
@onready var tags_label: Label = %BestiaryMonsterActionTags
@onready var probability_label: Label = %BestiaryMonsterActionProbability
@onready var facts_label: Label = %BestiaryMonsterActionFacts
@onready var body_label: Label = %BestiaryMonsterActionBody


func set_action(data: Dictionary, action_index: int = 0, fallback_accent: Color = Color("#fb7185")) -> void:
	var accent := _dictionary_color(data, "accent", fallback_accent.lerp(Color("#fde68a"), clampf(float(action_index) / 7.0, 0.0, 0.45)))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0, 108)
	tooltip_text = str(data.get("tooltip", data.get("body", "")))
	add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.08), 1, 8))
	index_label.text = str(data.get("index", "%02d" % (action_index + 1)))
	index_label.add_theme_color_override("font_color", accent.lightened(0.18))
	var name_text := str(data.get("name", "Action"))
	name_label.text = _short_text(name_text, 24)
	name_label.tooltip_text = name_text
	var tags_text := str(data.get("tags", "Base"))
	tags_label.text = _short_text(tags_text, 18)
	tags_label.tooltip_text = tags_text
	tags_label.add_theme_color_override("font_color", accent.lightened(0.14))
	var probability_text := str(data.get("probability", "I --/-- | IV --/--"))
	probability_label.text = probability_text
	probability_label.tooltip_text = str(data.get("probability_tooltip", probability_text))
	var facts_text := str(data.get("facts", "Move / pressure"))
	facts_label.text = _short_text(facts_text, 72)
	facts_label.tooltip_text = facts_text
	var body_text := str(data.get("body", ""))
	body_label.text = _short_text(body_text, 72)
	body_label.tooltip_text = body_text
	body_label.visible = body_text != ""


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
