@tool
extends Control
class_name SpaceSyndicatePlanetGlobeBackdrop

const SEAT_DECORATION_ANGLES := {
	"top": -PI * 0.5,
	"right_high": -PI * 0.25,
	"right_mid": 0.0,
	"right_low": PI * 0.25,
	"bottom": PI * 0.5,
	"left_low": PI * 0.75,
	"left_mid": PI,
	"left_high": PI * 1.25,
}

var _payload := {}
var _seat_decoration_visibility := {}


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
		"sceneized": true,
		"seat_decoration_visibility": seat_decoration_visibility_snapshot(),
	}


func set_seat_decoration_visibility(value: Dictionary) -> void:
	var next_visibility := {}
	for seat_position in SEAT_DECORATION_ANGLES.keys():
		next_visibility[seat_position] = bool(value.get(seat_position, false))
	_seat_decoration_visibility = next_visibility
	queue_redraw()


func seat_decoration_visibility_snapshot() -> Dictionary:
	if _seat_decoration_visibility.is_empty():
		var defaults := {}
		for seat_position in SEAT_DECORATION_ANGLES.keys():
			defaults[seat_position] = true
		return defaults
	return _seat_decoration_visibility.duplicate(true)


func _draw() -> void:
	var viewport_size := _as_vector2(_payload.get("viewport_size", size))
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		viewport_size = size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	var center := _as_vector2(_payload.get("globe_center", viewport_size * 0.5))
	var radius := maxf(24.0, float(_payload.get("globe_radius", minf(viewport_size.x, viewport_size.y) * 0.34)))
	var globe_blend := clampf(float(_payload.get("globe_blend", 1.0)), 0.0, 1.0)
	# PlanetBoard owns the full stage-space fill. Keeping this layer transparent
	# outside the globe lets BackSeatLayer portraits sit behind the planet disc
	# without disappearing behind an opaque square map surface.
	_draw_nebula(center, radius, globe_blend)
	_draw_stars(viewport_size)
	_draw_table_ring(center, radius, globe_blend)
	_draw_planet_disc(center, radius, globe_blend)


func _draw_nebula(center: Vector2, radius: float, globe_blend: float) -> void:
	var cyan := Color("#164e63")
	cyan.a = 0.18 + globe_blend * 0.05
	draw_circle(center - Vector2(radius * 0.72, radius * 0.48), radius * 0.72, cyan)
	var amber := Color("#451a03")
	amber.a = 0.11
	draw_circle(center + Vector2(radius * 0.82, radius * 0.56), radius * 0.58, amber)


func _draw_stars(viewport_size: Vector2) -> void:
	for i in range(72):
		var star_position := Vector2(
			fposmod(float(i * 137 + 31), maxf(1.0, viewport_size.x)),
			fposmod(float(i * 73 + 43), maxf(1.0, viewport_size.y))
		)
		var star := Color("#e0f2fe")
		star.a = 0.16 + float((i * 19) % 7) * 0.042
		draw_circle(star_position, 0.7 + float(i % 3) * 0.24, star)


func _draw_table_ring(center: Vector2, radius: float, globe_blend: float) -> void:
	var rail_radius := radius + 38.0
	var shadow := Color("#020617")
	shadow.a = 0.66
	draw_arc(center, rail_radius + 8.0, 0.0, TAU, 128, shadow, 10.0, true)
	var rim := Color("#d6a440")
	rim.a = 0.27 + globe_blend * 0.17
	draw_arc(center, rail_radius, 0.0, TAU, 128, rim, 2.4, true)
	var inner := Color("#fde68a")
	inner.a = 0.08 + globe_blend * 0.08
	draw_arc(center, radius + 8.0, 0.0, TAU, 128, inner, 1.4, true)
	var visibility := seat_decoration_visibility_snapshot()
	for seat_position in SEAT_DECORATION_ANGLES.keys():
		if not bool(visibility.get(seat_position, false)):
			continue
		var angle := float(SEAT_DECORATION_ANGLES[seat_position])
		var pos := center + Vector2(cos(angle), sin(angle)) * maxf(18.0, rail_radius - 18.0)
		var glow := Color("#facc15")
		glow.a = 0.12 + globe_blend * 0.05
		draw_arc(pos, 8.0, 0.0, TAU, 24, glow, 1.1, true)


func _draw_planet_disc(center: Vector2, radius: float, globe_blend: float) -> void:
	var shadow := Color("#020617")
	shadow.a = 0.78
	draw_circle(center, radius + 4.0, shadow)
	var ocean := Color("#0f172a")
	ocean.a = 0.36 + globe_blend * 0.30
	draw_circle(center, radius, ocean)
	var atmosphere := Color("#38bdf8")
	atmosphere.a = 0.13 + globe_blend * 0.22
	draw_arc(center, radius, 0.0, TAU, 128, atmosphere, 1.6 + globe_blend * 1.6, true)
	var night := Color("#020617")
	night.a = 0.14
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
