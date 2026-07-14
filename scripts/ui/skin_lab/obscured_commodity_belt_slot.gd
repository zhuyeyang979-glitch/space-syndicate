extends PanelContainer
class_name SpaceSyndicateObscuredCommodityBeltSlot

@onready var accent_bar: ColorRect = %AccentBar
@onready var glyph_label: Label = %GlyphLabel
@onready var category_label: Label = %CategoryLabel
@onready var state_label: Label = %StateLabel

var _safe_snapshot := {
	"color_key": "unknown",
	"direction": "toward_exit",
	"position_index": 0,
}


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_text = ""


func set_safe_snapshot(snapshot: Dictionary) -> void:
	# This component intentionally accepts only the fields the viewer may know.
	# Never pass card ids, names, ranks, artwork, effects or tooltips here.
	_safe_snapshot = {
		"color_key": str(snapshot.get("color_key", "unknown")),
		"direction": str(snapshot.get("direction", "toward_exit")),
		"position_index": int(snapshot.get("position_index", 0)),
	}
	var accent := _color_from(snapshot.get("accent", "#64748b"), Color("#64748b"))
	accent_bar.color = accent
	glyph_label.text = str(snapshot.get("color_glyph", "◆"))
	glyph_label.add_theme_color_override("font_color", accent.lightened(0.08))
	category_label.text = str(snapshot.get("color_label", "商品颜色"))
	state_label.text = "身份未公开 · 不可领取"
	set_meta("player_assistive_name", "%s商品，身份未公开，不可领取" % category_label.text)
	add_theme_stylebox_override("panel", _hidden_style(accent))


func get_safe_debug_snapshot() -> Dictionary:
	return _safe_snapshot.duplicate(true)


func _hidden_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#07101b").lerp(accent, 0.055)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.42)
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	return style


func _color_from(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value as Color
	if value is String and str(value).begins_with("#"):
		return Color(str(value))
	return fallback
