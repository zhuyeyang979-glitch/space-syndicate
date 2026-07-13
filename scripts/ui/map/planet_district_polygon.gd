@tool
extends Control
class_name SpaceSyndicatePlanetDistrictPolygon

var _region_index := -1
var _screen_points := PackedVector2Array()
var _accent := Color("#38bdf8")
var _selected := false
var _label := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("mcp_sceneized_component", "PlanetDistrictPolygon")


func configure(data: Dictionary) -> void:
	_region_index = int(data.get("index", -1))
	_screen_points = _packed_points(data.get("screen_points", []))
	_accent = Color(str(data.get("accent", "#38bdf8")))
	_selected = bool(data.get("selected", false))
	_label = str(data.get("name", "District"))
	name = "PlanetDistrictPolygon_%02d" % max(0, _region_index)
	queue_redraw()


func debug_snapshot() -> Dictionary:
	return {
		"index": _region_index,
		"kind": "district_polygon",
		"name": _label,
		"point_count": _screen_points.size(),
		"selected": _selected,
	}


func _draw() -> void:
	if _screen_points.size() < 3:
		return
	var fill := _accent
	fill.a = 0.18 if _selected else 0.10
	var outline := _accent.lightened(0.2)
	outline.a = 0.78 if _selected else 0.38
	if _can_fill_polygon(_screen_points):
		draw_colored_polygon(_screen_points, fill)
	draw_polyline(_closed_points(_screen_points), outline, 2.0 if _selected else 1.1, true)


func _packed_points(value: Variant) -> PackedVector2Array:
	var result := PackedVector2Array()
	if not (value is Array or value is PackedVector2Array):
		return result
	for point_variant in value:
		if point_variant is Vector2:
			result.append(point_variant as Vector2)
		elif point_variant is Array and (point_variant as Array).size() >= 2:
			result.append(Vector2(float((point_variant as Array)[0]), float((point_variant as Array)[1])))
		elif point_variant is Dictionary:
			var dict := point_variant as Dictionary
			result.append(Vector2(float(dict.get("x", 0.0)), float(dict.get("y", 0.0))))
	return result


func _closed_points(points: PackedVector2Array) -> PackedVector2Array:
	var closed := PackedVector2Array(points)
	if not closed.is_empty():
		closed.append(closed[0])
	return closed


func _can_fill_polygon(points: PackedVector2Array) -> bool:
	if points.size() < 3:
		return false
	return not Geometry2D.triangulate_polygon(points).is_empty()
