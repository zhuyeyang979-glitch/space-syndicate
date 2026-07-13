@tool
extends Control
class_name SpaceSyndicatePlanetRouteSegment

var _from_position := Vector2.ZERO
var _to_position := Vector2.ZERO
var _accent := Color("#38bdf8")
var _disrupted := false
var _product := ""
var _segment_index := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("mcp_sceneized_component", "PlanetRouteSegment")


func configure(data: Dictionary) -> void:
	_from_position = _as_vector2(data.get("from_position", Vector2.ZERO))
	_to_position = _as_vector2(data.get("to_position", Vector2.ZERO))
	_accent = Color(str(data.get("accent", "#38bdf8")))
	_disrupted = bool(data.get("disrupted", false))
	_product = str(data.get("product", "route"))
	_segment_index = int(data.get("segment_index", -1))
	name = "PlanetRouteSegment_%s_%02d" % [_product, max(0, _segment_index)]
	queue_redraw()


func debug_snapshot() -> Dictionary:
	return {
		"kind": "route_segment",
		"product": _product,
		"segment_index": _segment_index,
		"disrupted": _disrupted,
	}


func _draw() -> void:
	if _from_position.distance_to(_to_position) <= 1.0:
		return
	var color := Color("#f97316") if _disrupted else _accent
	color.a = 0.72 if _disrupted else 0.58
	if _disrupted:
		_draw_dashed_line(_from_position, _to_position, color)
	else:
		draw_line(_from_position, _to_position, color, 3.0, true)
		_draw_endpoint(_from_position, color.darkened(0.12))
		_draw_endpoint(_to_position, color.lightened(0.12))


func _draw_dashed_line(from_point: Vector2, to_point: Vector2, color: Color) -> void:
	var offset := to_point - from_point
	var length := offset.length()
	if length <= 1.0:
		return
	var forward := offset / length
	var cursor := 0.0
	while cursor < length:
		var next_cursor: float = min(length, cursor + 16.0)
		draw_line(from_point + forward * cursor, from_point + forward * next_cursor, color, 3.2, true)
		cursor += 27.0
	_draw_endpoint(from_point, color)
	_draw_endpoint(to_point, color)


func _draw_endpoint(point: Vector2, color: Color) -> void:
	var dot := color.lightened(0.16)
	dot.a = maxf(dot.a, 0.74)
	draw_circle(point, 4.2, Color("#020617", 0.9))
	draw_circle(point, 2.8, dot)


func _as_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value as Vector2
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	if value is Dictionary:
		var dict := value as Dictionary
		return Vector2(float(dict.get("x", 0.0)), float(dict.get("y", 0.0)))
	return Vector2.ZERO
