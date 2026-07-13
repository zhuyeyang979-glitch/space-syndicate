@tool
extends PanelContainer
class_name SpaceSyndicatePlanetActionCallout

@onready var title_label: Label = %ActionCalloutTitleLabel
@onready var detail_label: Label = %ActionCalloutDetailLabel

var _accent := Color("#facc15")
var _alpha := 1.0
var _callout_index := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("mcp_sceneized_component", "PlanetActionCallout")


func configure(data: Dictionary) -> void:
	_accent = Color(str(data.get("accent", "#facc15")))
	_alpha = clampf(float(data.get("alpha", 1.0)), 0.0, 1.0)
	_callout_index = int(data.get("callout_index", -1))
	name = "PlanetActionCallout_%02d" % max(0, _callout_index)
	custom_minimum_size = _as_vector2(data.get("panel_size", Vector2(320.0, 52.0)))
	size = custom_minimum_size
	position = _as_vector2(data.get("panel_position", Vector2.ZERO))
	if title_label != null:
		title_label.text = _short_text(str(data.get("title", "Action")), 38)
		title_label.add_theme_color_override("font_color", _with_alpha(_accent, 0.95 * _alpha))
	if detail_label != null:
		detail_label.text = _short_text(str(data.get("detail", "")), 56)
		detail_label.add_theme_color_override("font_color", Color("#e2e8f0", 0.88 * _alpha))
	_refresh_style()


func debug_snapshot() -> Dictionary:
	return {
		"kind": "action_callout",
		"title": title_label.text if title_label != null else "",
		"callout_index": _callout_index,
	}


func _refresh_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.04, 0.10, 0.82 * _alpha)
	style.border_color = _with_alpha(_accent, 0.45 * _alpha)
	style.set_border_width_all(1)
	style.border_width_left = 4
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)


func _with_alpha(color: Color, alpha: float) -> Color:
	var result := color
	result.a = alpha
	return result


func _short_text(text: String, max_characters: int) -> String:
	if text.length() <= max_characters:
		return text
	return text.left(maxi(1, max_characters - 1)) + "..."


func _as_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value as Vector2
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	if value is Dictionary:
		var dict := value as Dictionary
		return Vector2(float(dict.get("x", 0.0)), float(dict.get("y", 0.0)))
	return Vector2.ZERO
