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
		"graticule_kind": "retired",
		"latitude_line_count": 0,
		"longitude_curve_count": 0,
		"outer_orbit_decoration_count": 0,
		"sceneized": true,
	}


func _draw() -> void:
	var globe_blend := clampf(float(_payload.get("globe_blend", 1.0)), 0.0, 1.0)
	_draw_local_grid(globe_blend)


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
