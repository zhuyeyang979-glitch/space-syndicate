@tool
extends PanelContainer
class_name SpaceSyndicatePlanetMonsterToken

@onready var glyph_label: Label = %MonsterTokenGlyphLabel
@onready var name_label: Label = %MonsterTokenNameLabel
@onready var motif_label: Label = %MonsterTokenMotifLabel

var _compact_mode := false
var _token_count := 1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("mcp_sceneized_component", "PlanetMonsterToken")


func configure(data: Dictionary) -> void:
	_compact_mode = bool(data.get("compact", false))
	_token_count = maxi(1, int(data.get("count", 1)))
	var public_names := data.get("names", []) as Array
	var target_size := Vector2(38, 38) if _compact_mode else Vector2(112, 52)
	custom_minimum_size = target_size
	name = "PlanetMonsterToken_%s" % str(data.get("label", "token"))
	if glyph_label != null:
		glyph_label.text = "兽×%d" % _token_count if _compact_mode and _token_count > 1 else str(data.get("glyph", "兽"))
		glyph_label.add_theme_font_size_override("font_size", 10 if _compact_mode and _token_count > 1 else (14 if _compact_mode else 12))
	if name_label != null:
		name_label.text = str(data.get("name", "未知怪兽"))
		name_label.visible = not _compact_mode
	if motif_label != null:
		motif_label.text = str(data.get("detail_label", "场上单位"))
		motif_label.visible = not _compact_mode
	tooltip_text = "怪兽 %d：%s；放大查看完整怪兽标牌。" % [_token_count, "、".join(public_names)] if _token_count > 1 else "%s｜%s；放大查看完整怪兽标牌。" % [str(data.get("name", "未知怪兽")), str(data.get("detail_label", "场上单位"))]
	_refresh_style(Color(str(data.get("accent", "#ef4444"))), Color(str(data.get("secondary", "#fde68a"))), _compact_mode)
	update_minimum_size()
	reset_size()
	size = target_size
	position = _as_vector2(data.get("screen_position", Vector2.ZERO)) - target_size * 0.5


func debug_snapshot() -> Dictionary:
	return {
		"kind": "monster",
		"name": name_label.text if name_label != null else "",
		"detail_label": motif_label.text if motif_label != null else "",
		"compact": _compact_mode,
		"count": _token_count,
	}


func _refresh_style(accent: Color, secondary: Color, compact: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#450a0a", 0.82)
	style.border_color = accent
	style.set_border_width_all(2)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	style.content_margin_left = 5 if compact else 8
	style.content_margin_right = 5 if compact else 8
	style.content_margin_top = 4 if compact else 5
	style.content_margin_bottom = 4 if compact else 5
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
