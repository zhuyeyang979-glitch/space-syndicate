@tool
extends Control
class_name V07ReferencePlanetBackdrop

var _payload := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# PlanetMapView owns the shared underlay protocol. This reference-only
	# component deliberately implements the protocol without table-position
	# decoration or participant placement semantics.
	set_meta("mcp_sceneized_component", "PlanetGlobeBackdrop")


func configure(data: Dictionary) -> void:
	_payload = data.duplicate(true)
	visible = true
	queue_redraw()


func debug_snapshot() -> Dictionary:
	return {
		"kind": "v07_reference_planet_backdrop",
		"mode": str(_payload.get("mode", "")),
		"district_count": int(_payload.get("district_count", 0)),
		"sceneized": true,
		"positional_decoration_count": 0,
	}


func _draw() -> void:
	var viewport_size := _as_vector2(_payload.get("viewport_size", size))
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		viewport_size = size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	var center := _as_vector2(_payload.get("globe_center", viewport_size * 0.5))
	var radius := maxf(
		24.0,
		float(_payload.get("globe_radius", minf(viewport_size.x, viewport_size.y) * 0.34))
	)
	var globe_blend := clampf(float(_payload.get("globe_blend", 1.0)), 0.0, 1.0)
	_draw_nebula(center, radius)
	_draw_stars(viewport_size)
	_draw_planet_disc(center, radius, globe_blend)


func _draw_nebula(center: Vector2, radius: float) -> void:
	var cyan := Color("#164e63")
	cyan.a = 0.18
	draw_circle(center - Vector2(radius * 0.72, radius * 0.48), radius * 0.72, cyan)
	var amber := Color("#451a03")
	amber.a = 0.10
	draw_circle(center + Vector2(radius * 0.82, radius * 0.56), radius * 0.58, amber)


func _draw_stars(viewport_size: Vector2) -> void:
	for index in range(72):
		var point := Vector2(
			fposmod(float(index * 137 + 31), maxf(1.0, viewport_size.x)),
			fposmod(float(index * 73 + 43), maxf(1.0, viewport_size.y))
		)
		var color := Color("#e0f2fe")
		color.a = 0.14 + float((index * 19) % 7) * 0.038
		draw_circle(point, 0.7 + float(index % 3) * 0.24, color)


func _draw_planet_disc(center: Vector2, radius: float, globe_blend: float) -> void:
	var shadow := Color("#020617")
	shadow.a = 0.78
	draw_circle(center, radius + 4.0, shadow)
	var ocean := Color("#0f172a")
	ocean.a = 0.38 + globe_blend * 0.30
	draw_circle(center, radius, ocean)
	var atmosphere := Color("#38bdf8")
	atmosphere.a = 0.13 + globe_blend * 0.22
	draw_arc(center, radius, 0.0, TAU, 128, atmosphere, 1.6 + globe_blend * 1.6, true)
	var horizon := Color("#fde68a")
	horizon.a = 0.07 + globe_blend * 0.07
	draw_arc(center, radius + 11.0, 0.0, TAU, 128, horizon, 1.1, true)


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
