@tool
extends Control
class_name SpaceSyndicatePlanetDistrictPolygon

var _region_index := -1
var _screen_points := PackedVector2Array()
var _accent := Color("#38bdf8")
var _selected := false
var _sunlit := false
var _legal_target := true
var _efficiency_multiplier := 1.0
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
	_sunlit = bool(data.get("sunlit", false))
	_legal_target = bool(data.get("legal_target", true))
	_efficiency_multiplier = float(data.get("efficiency_multiplier", 1.0))
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
		"sunlit": _sunlit,
		"legal_target": _legal_target,
		"efficiency_multiplier": _efficiency_multiplier,
	}


func _draw() -> void:
	if _screen_points.size() < 3:
		return
	var solar_tint := Color("#fde68a") if _sunlit else Color("#1e293b")
	var fill := _accent.lerp(solar_tint, 0.20 if _sunlit else 0.34)
	if not _legal_target:
		fill = fill.lerp(Color("#020617"), 0.68)
	fill.a = 0.23 if _selected else (0.13 if _legal_target else 0.055)
	var outline := _accent.lightened(0.25) if _legal_target else Color("#475569")
	outline.a = 0.88 if _selected else (0.48 if _legal_target else 0.24)
	if _can_fill_polygon(_screen_points):
		draw_colored_polygon(_screen_points, fill)
	draw_polyline(_closed_points(_screen_points), outline, 2.2 if _selected else 1.2, true)


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
