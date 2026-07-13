@tool
extends PanelContainer
class_name SpaceSyndicatePlanetCityMarker

@onready var tag_label: Label = %CityMarkerTagLabel
@onready var level_label: Label = %CityMarkerLevelLabel
@onready var product_label: Label = %CityMarkerProductLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("mcp_sceneized_component", "PlanetCityMarker")


func configure(data: Dictionary) -> void:
	custom_minimum_size = Vector2(92, 48)
	size = custom_minimum_size
	position = _as_vector2(data.get("screen_position", Vector2.ZERO)) - custom_minimum_size * 0.5
	name = "PlanetCityMarker_%s" % str(data.get("tag", "city"))
	if tag_label != null:
		tag_label.text = str(data.get("tag", "C"))
	if level_label != null:
		level_label.text = "Lv %d" % int(data.get("level", 1))
	if product_label != null:
		product_label.text = _joined_strings(data.get("products", []))
	_refresh_style(Color(str(data.get("accent", "#38bdf8"))), bool(data.get("active", true)))


func debug_snapshot() -> Dictionary:
	return {
		"kind": "city",
		"tag": tag_label.text if tag_label != null else "",
	}


func _refresh_style(accent: Color, active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#082f49", 0.82) if active else Color("#1e293b", 0.72)
	style.border_color = accent if active else Color("#64748b", 0.68)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 5
	style.content_margin_bottom = 5
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


func _joined_strings(value: Variant) -> String:
	var result := PackedStringArray()
	if value is Array:
		for item in value:
			result.append(str(item))
	return " / ".join(result)
