@tool
extends Control
class_name SpaceSyndicatePlanetOrbitGuide

const GRATICULE_LATITUDE_COUNT := 5
const GRATICULE_LONGITUDE_SCALES := [0.28, 0.55, 0.82]
const GRATICULE_SEGMENTS := 64

var _payload := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("mcp_sceneized_component", "PlanetOrbitGuide")


func configure(data: Dictionary) -> void:
	_payload = data.duplicate(true)
	name = "PlanetOrbitGuide"
	visible = true
	queue_redraw()


func debug_snapshot() -> Dictionary:
	var lines: Array = _payload.get("local_grid_lines", []) if _payload.get("local_grid_lines", []) is Array else []
	return {
		"kind": "orbit_guide",
		"mode": str(_payload.get("mode", "")),
		"grid_line_count": lines.size(),
		"graticule_kind": "latitude_longitude",
		"latitude_line_count": GRATICULE_LATITUDE_COUNT,
		"longitude_curve_count": GRATICULE_LONGITUDE_SCALES.size(),
		"sceneized": true,
	}


func _draw() -> void:
	var center := _as_vector2(_payload.get("globe_center", size * 0.5))
	var radius := maxf(24.0, float(_payload.get("globe_radius", minf(size.x, size.y) * 0.34)))
	var globe_blend := clampf(float(_payload.get("globe_blend", 1.0)), 0.0, 1.0)
	_draw_orbit_rings(center, radius)
	_draw_latitude_longitude_graticule(center, radius, globe_blend)
	_draw_local_grid(globe_blend)


func _draw_orbit_rings(center: Vector2, radius: float) -> void:
	var rings: Array = _payload.get("orbit_rings", []) if _payload.get("orbit_rings", []) is Array else []
	for ring_variant in rings:
		if not (ring_variant is Dictionary):
			continue
		var ring: Dictionary = ring_variant
		var color := Color("#38bdf8")
		color.a = float(ring.get("alpha", 0.12))
		draw_arc(_as_vector2(ring.get("center", center)), maxf(2.0, float(ring.get("radius", radius))), 0.0, TAU, 96, color, 0.8, true)


func _draw_latitude_longitude_graticule(
	center: Vector2,
	radius: float,
	globe_blend: float
) -> void:
	var color := Color("#67e8f9")
	color.a = 0.05 + globe_blend * 0.08
	for latitude_index in range(GRATICULE_LATITUDE_COUNT):
		var latitude_ratio := (
			float(latitude_index + 1) / float(GRATICULE_LATITUDE_COUNT + 1) * 2.0 - 1.0
		)
		var latitude_y := radius * latitude_ratio
		var latitude_half_width := radius * sqrt(maxf(0.0, 1.0 - latitude_ratio * latitude_ratio))
		_draw_ellipse(
			center + Vector2(0.0, latitude_y),
			Vector2(latitude_half_width, maxf(1.2, radius * 0.035)),
			color
		)
	for longitude_scale in GRATICULE_LONGITUDE_SCALES:
		_draw_ellipse(
			center,
			Vector2(radius * float(longitude_scale), radius),
			color
		)


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for segment in range(GRATICULE_SEGMENTS + 1):
		var angle := TAU * float(segment) / float(GRATICULE_SEGMENTS)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_polyline(points, color, 0.7, true)


func _draw_local_grid(globe_blend: float) -> void:
	var lines: Array = _payload.get("local_grid_lines", []) if _payload.get("local_grid_lines", []) is Array else []
	var base := Color("#1e293b")
	for line_variant in lines:
		if not (line_variant is Dictionary):
			continue
		var line: Dictionary = line_variant
		var color := base
		color.a = 0.42 * float(line.get("alpha", maxf(0.0, 1.0 - globe_blend)))
		draw_line(_as_vector2(line.get("from", Vector2.ZERO)), _as_vector2(line.get("to", Vector2.ZERO)), color, 1.0, true)


func _as_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Vector2i:
		return Vector2(value)
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if value is Dictionary:
		return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
	return Vector2.ZERO
