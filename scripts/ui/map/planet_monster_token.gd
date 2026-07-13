@tool
extends PanelContainer
class_name SpaceSyndicatePlanetMonsterToken

@onready var glyph_label: Label = %MonsterTokenGlyphLabel
@onready var name_label: Label = %MonsterTokenNameLabel
@onready var motif_label: Label = %MonsterTokenMotifLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("mcp_sceneized_component", "PlanetMonsterToken")


func configure(data: Dictionary) -> void:
	custom_minimum_size = Vector2(112, 52)
	size = custom_minimum_size
	position = _as_vector2(data.get("screen_position", Vector2.ZERO)) - custom_minimum_size * 0.5
	name = "PlanetMonsterToken_%s" % str(data.get("label", "token"))
	if glyph_label != null:
		glyph_label.text = str(data.get("glyph", "M"))
	if name_label != null:
		name_label.text = str(data.get("name", "Monster"))
	if motif_label != null:
		motif_label.text = str(data.get("motif", "threat"))
	_refresh_style(Color(str(data.get("accent", "#ef4444"))), Color(str(data.get("secondary", "#fde68a"))))


func debug_snapshot() -> Dictionary:
	return {
		"kind": "monster",
		"name": name_label.text if name_label != null else "",
	}


func _refresh_style(accent: Color, secondary: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#450a0a", 0.82)
	style.border_color = accent
	style.set_border_width_all(2)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	add_theme_stylebox_override("panel", style)
	if glyph_label != null:
		glyph_label.add_theme_color_override("font_color", secondary)


func _as_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value as Vector2
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	if value is Dictionary:
		var dict := value as Dictionary
		return Vector2(float(dict.get("x", 0.0)), float(dict.get("y", 0.0)))
	return Vector2.ZERO
