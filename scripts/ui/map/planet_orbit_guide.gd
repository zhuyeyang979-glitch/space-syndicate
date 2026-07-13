@tool
extends Control
class_name SpaceSyndicatePlanetOrbitGuide

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
		"sceneized": true,
	}


func _draw() -> void:
	var center := _as_vector2(_payload.get("globe_center", size * 0.5))
	var radius := maxf(24.0, float(_payload.get("globe_radius", minf(size.x, size.y) * 0.34)))
	var globe_blend := clampf(float(_payload.get("globe_blend", 1.0)), 0.0, 1.0)
	_draw_orbit_rings(center, radius)
	_draw_globe_graticule(center, radius, globe_blend)
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


func _draw_globe_graticule(center: Vector2, radius: float, globe_blend: float) -> void:
	var color := Color("#67e8f9")
	color.a = 0.05 + globe_blend * 0.08
	for i in range(1, 4):
		var ratio := float(i) / 4.0
		draw_arc(center, radius * ratio, 0.0, TAU, 96, color, 0.7, true)
	for i in range(0, 8):
		var angle := TAU * float(i) / 8.0
		var forward := Vector2(cos(angle), sin(angle))
		draw_line(center - forward * radius, center + forward * radius, color, 0.7, true)


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
