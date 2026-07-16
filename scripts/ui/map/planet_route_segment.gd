@tool
extends Control
class_name SpaceSyndicatePlanetRouteSegment

var _from_position := Vector2.ZERO
var _to_position := Vector2.ZERO
var _accent := Color("#38bdf8")
var _disrupted := false
var _product := ""
var _segment_index := -1
var _flow_kind := "market_sale"
var _strength := "weak"
var _low_emphasis := false
var _capacity_limited := false
var _congested := false
var _transport_modes: Array = []


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
	_flow_kind = str(data.get("flow_kind", "market_sale"))
	_strength = str(data.get("strength", "weak"))
	_low_emphasis = bool(data.get("low_emphasis", false))
	_capacity_limited = bool(data.get("capacity_limited", false))
	_congested = bool(data.get("congested", false))
	_transport_modes = (data.get("transport_modes", []) as Array).duplicate(true) if data.get("transport_modes", []) is Array else []
	name = "PlanetRouteSegment_%s_%02d" % [_product, max(0, _segment_index)]
	queue_redraw()


func debug_snapshot() -> Dictionary:
	return {
		"kind": "route_segment",
		"product": _product,
		"segment_index": _segment_index,
		"disrupted": _disrupted,
		"flow_kind": _flow_kind,
		"strength": _strength,
		"low_emphasis": _low_emphasis,
		"capacity_limited": _capacity_limited,
		"congested": _congested,
		"transport_modes": _transport_modes.duplicate(true),
	}


func _draw() -> void:
	if _from_position.distance_to(_to_position) <= 1.0:
		return
	var color := Color("#f97316") if _disrupted else _accent
	color.a = _route_alpha()
	var curve := _flight_curve_points(_from_position, _to_position)
	if _flow_kind in ["warehouse_inbound", "warehouse_outbound"] or _disrupted:
		_draw_dashed_curve(curve, color)
	else:
		draw_polyline(curve, Color(color.r, color.g, color.b, 0.08 if _low_emphasis else 0.12), 7.0 if _low_emphasis else 10.0, true)
		draw_polyline(curve, color, _route_width(), true)
		_draw_route_arrow(curve, color)
		_draw_endpoint(_from_position, color.darkened(0.12))
		_draw_endpoint(_to_position, color.lightened(0.12))


func _draw_dashed_curve(points: PackedVector2Array, color: Color) -> void:
	for index in range(points.size() - 1):
		if index % 4 < 2:
			draw_line(points[index], points[index + 1], color, _route_width(), true)
	_draw_route_arrow(points, color)
	_draw_endpoint(points[0], color)
	_draw_endpoint(points[points.size() - 1], color)


func _flight_curve_points(from_point: Vector2, to_point: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	var offset := to_point - from_point
	var distance := offset.length()
	var normal := Vector2(-offset.y, offset.x).normalized()
	var lift_sign := -1.0 if _segment_index % 2 == 0 else 1.0
	var control := (from_point + to_point) * 0.5 + normal * clampf(distance * 0.16, 18.0, 72.0) * lift_sign
	for index in range(25):
		var t := float(index) / 24.0
		var inverse := 1.0 - t
		result.append(inverse * inverse * from_point + 2.0 * inverse * t * control + t * t * to_point)
	return result


func _draw_route_arrow(points: PackedVector2Array, color: Color) -> void:
	var arrow_index := clampi(int(points.size() * 0.62), 1, points.size() - 1)
	var tip := points[arrow_index]
	var direction := (tip - points[arrow_index - 1]).normalized()
	var normal := Vector2(-direction.y, direction.x)
	draw_colored_polygon(PackedVector2Array([
		tip + direction * 7.0,
		tip - direction * 6.0 + normal * 4.0,
		tip - direction * 6.0 - normal * 4.0,
	]), color.lightened(0.18))


func _draw_endpoint(point: Vector2, color: Color) -> void:
	var dot := color.lightened(0.16)
	dot.a = maxf(dot.a, 0.74)
	draw_circle(point, 4.2, Color("#020617", 0.9))
	draw_circle(point, 2.8, dot)


func _route_alpha() -> float:
	if _low_emphasis:
		return 0.30
	if _disrupted:
		return 0.76
	match _strength:
		"strong":
			return 0.82
		"medium":
			return 0.64
	return 0.46


func _route_width() -> float:
	if _low_emphasis:
		return 1.6
	match _strength:
		"strong":
			return 4.0
		"medium":
			return 3.0
	return 2.2


func _as_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value as Vector2
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	if value is Dictionary:
		var dict := value as Dictionary
		return Vector2(float(dict.get("x", 0.0)), float(dict.get("y", 0.0)))
	return Vector2.ZERO
