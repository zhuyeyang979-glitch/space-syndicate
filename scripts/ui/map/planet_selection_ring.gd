@tool
extends Control
class_name SpaceSyndicatePlanetSelectionRing

const RING_SIZE := Vector2(44.0, 44.0)

var _region_index := -1
var _accent := Color("#facc15")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("mcp_sceneized_component", "PlanetSelectionRing")
	queue_redraw()


func configure(data: Dictionary) -> void:
	_region_index = int(data.get("index", -1))
	_accent = Color(str(data.get("accent", "#facc15")))
	custom_minimum_size = RING_SIZE
	size = RING_SIZE
	position = _as_vector2(data.get("screen_position", Vector2.ZERO)) - RING_SIZE * 0.5
	name = "PlanetSelectionRing_%02d" % max(0, _region_index)
	tooltip_text = "%s\n%s" % [
		str(data.get("name", "Selected region")),
		str(data.get("detail", "active focus")),
	]
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, 18.0, Color("#020617", 0.22))
	draw_arc(center, 18.0, 0.0, TAU, 64, Color(_accent, 0.95), 3.0, true)
	draw_arc(center, 13.0, 0.0, TAU, 48, Color(_accent, 0.34), 1.0, true)
	draw_circle(center, 3.0, Color(_accent, 0.92))


func debug_snapshot() -> Dictionary:
	return {
		"index": _region_index,
		"kind": "selection",
		"visible": visible,
		"text_panel_count": 0,
	}


func _as_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value as Vector2
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	if value is Dictionary:
		var dict := value as Dictionary
		return Vector2(float(dict.get("x", 0.0)), float(dict.get("y", 0.0)))
	return Vector2.ZERO