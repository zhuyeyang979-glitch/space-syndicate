@tool
extends PanelContainer
class_name SpaceSyndicatePlanetSelectionRing

@onready var title_label: Label = %SelectionRingTitleLabel
@onready var detail_label: Label = %SelectionRingDetailLabel

var _region_index := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("mcp_sceneized_component", "PlanetSelectionRing")


func configure(data: Dictionary) -> void:
	_region_index = int(data.get("index", -1))
	custom_minimum_size = Vector2(156, 74)
	size = custom_minimum_size
	position = _as_vector2(data.get("screen_position", Vector2.ZERO)) - custom_minimum_size * 0.5
	name = "PlanetSelectionRing_%02d" % max(0, _region_index)
	if title_label != null:
		title_label.text = str(data.get("name", "Selected region"))
	if detail_label != null:
		detail_label.text = str(data.get("detail", "active focus"))
	_refresh_style(Color(str(data.get("accent", "#facc15"))))


func debug_snapshot() -> Dictionary:
	return {
		"index": _region_index,
		"kind": "selection",
		"visible": visible,
	}


func _refresh_style(accent: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#020617", 0.12)
	style.border_color = accent
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)


func _as_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value as Vector2
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	if value is Dictionary:
		var dict := value as Dictionary
		return Vector2(float(dict.get("x", 0.0)), float(dict.get("y", 0.0)))
	return Vector2.ZERO
