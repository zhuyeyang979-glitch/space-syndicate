@tool
extends Control
class_name SpaceSyndicatePlanetGlobeBackdrop

var _payload := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("mcp_sceneized_component", "PlanetGlobeBackdrop")


func configure(data: Dictionary) -> void:
	_payload = data.duplicate(true)
	name = "PlanetGlobeBackdrop"
	visible = true
	queue_redraw()


func debug_snapshot() -> Dictionary:
	return {
		"kind": "globe_backdrop",
		"mode": str(_payload.get("mode", "")),
		"district_count": int(_payload.get("district_count", 0)),
		"planet_opaque": true,
		"planet_alpha": 1.0,
		"day_brightness": 1.0,
		"night_brightness": 0.50,
		"outer_orbit_decoration_count": 0,
		"sceneized": true,
	}


func _draw() -> void:
	var viewport_size := _as_vector2(_payload.get("viewport_size", size))
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		viewport_size = size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	var center := _as_vector2(_payload.get("globe_center", viewport_size * 0.5))
	var radius := maxf(24.0, float(_payload.get("globe_radius", minf(viewport_size.x, viewport_size.y) * 0.34)))
	var globe_blend := clampf(float(_payload.get("globe_blend", 1.0)), 0.0, 1.0)
	# PlanetBoard owns the full stage-space fill. This layer remains transparent
	# outside the globe so the board-space nebula can composite behind the map.
	_draw_stars(viewport_size)
	_draw_planet_disc(center, radius, globe_blend)


func _draw_stars(viewport_size: Vector2) -> void:
	for i in range(72):
		var star_position := Vector2(
			fposmod(float(i * 137 + 31), maxf(1.0, viewport_size.x)),
			fposmod(float(i * 73 + 43), maxf(1.0, viewport_size.y))
		)
		var star := Color("#e0f2fe")
		star.a = 0.16 + float((i * 19) % 7) * 0.042
		draw_circle(star_position, 0.7 + float(i % 3) * 0.24, star)


func _draw_planet_disc(center: Vector2, radius: float, globe_blend: float) -> void:
	var shadow := Color("#020617")
	shadow.a = 0.78
	draw_circle(center, radius + 4.0, shadow)
	var ocean := Color("#0f172a")
	ocean.a = 1.0
	draw_circle(center, radius, ocean)
	var atmosphere := Color("#38bdf8")
	atmosphere.a = 0.13 + globe_blend * 0.22
	draw_arc(center, radius, 0.0, TAU, 128, atmosphere, 1.6 + globe_blend * 1.6, true)
	var night := Color("#020617")
	night.a = 0.50
	draw_circle(center + Vector2(radius * 0.22, radius * 0.04), radius * 0.82, night)


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
