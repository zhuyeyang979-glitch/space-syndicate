extends Control
class_name SpaceSyndicateMenuPlanetArt

const STAR_COUNT := 120
const ORBIT_COUNT := 5
const CITY_LIGHT_COUNT := 34
const CLOUD_BAND_COUNT := 4

var accent: Color = Color("#f59e0b")


func _ready() -> void:
	custom_minimum_size = Vector2(300, 210)


func set_art(data: Dictionary) -> void:
	var value: Variant = data.get("accent", accent)
	if value is Color:
		accent = value as Color
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color("#020617"), true)
	_draw_stars()
	_draw_orbits()
	_draw_planet()


func _draw_stars() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	for i in range(STAR_COUNT):
		var position := Vector2(
			fposmod(float(i * 97 + 23), size.x),
			fposmod(float(i * 53 + 41), size.y)
		)
		var star := Color("#e0f2fe")
		star.a = 0.22 + float((i * 17) % 7) * 0.07
		draw_circle(position, 0.8 + float(i % 3) * 0.35, star)


func _draw_orbits() -> void:
	var center := _planet_center()
	var orbit_color := accent.lightened(0.10)
	for i in range(ORBIT_COUNT):
		var radius: float = minf(size.x, size.y) * (0.42 + float(i) * 0.082)
		orbit_color.a = 0.05 + float(i) * 0.025
		draw_arc(center, radius, -0.16 * PI, 1.16 * PI, 128, orbit_color, 1.0, true)
	for i in range(8):
		var angle: float = -0.18 * PI + TAU * float(i) / 8.0
		var lane_radius: float = minf(size.x, size.y) * (0.53 + float(i % 3) * 0.075)
		var tick := center + Vector2(cos(angle), sin(angle)) * lane_radius
		var tick_color := accent.lightened(0.22)
		tick_color.a = 0.18 + float(i % 2) * 0.08
		draw_circle(tick, 2.0 + float(i % 3) * 0.45, tick_color)


func _draw_planet() -> void:
	var center := _planet_center()
	var radius: float = minf(size.x, size.y) * 0.37
	var atmosphere := accent.lightened(0.20)
	atmosphere.a = 0.16
	draw_circle(center, radius * 1.13, atmosphere)
	var shadow := Color("#020617")
	shadow.a = 0.66
	draw_circle(center + Vector2(radius * 0.06, radius * 0.10), radius * 1.20, shadow)
	var ocean := Color("#082f49").lerp(accent, 0.14)
	draw_circle(center, radius, ocean)
	var day_glow := accent.lightened(0.18)
	day_glow.a = 0.28
	draw_circle(center - Vector2(radius * 0.24, radius * 0.18), radius * 0.76, day_glow)
	_draw_landmass(center, radius, -0.24, Color("#14532d").lerp(accent, 0.16), 0)
	_draw_landmass(center, radius, 0.20, Color("#164e63").lerp(accent, 0.10), 1)
	_draw_cloud_bands(center, radius)
	var terminator := Color("#020617")
	terminator.a = 0.36
	draw_circle(center + Vector2(radius * 0.36, radius * 0.02), radius * 0.88, terminator)
	_draw_city_lights(center, radius)
	var rim := accent.lightened(0.18)
	rim.a = 0.74
	draw_arc(center, radius, 0.0, TAU, 160, rim, 2.2, true)
	for lane in range(3):
		var line := Color("#bae6fd")
		line.a = 0.08 + float(lane) * 0.035
		var y: float = center.y - radius * 0.36 + float(lane) * radius * 0.34
		draw_line(Vector2(center.x - radius * 0.74, y), Vector2(center.x + radius * 0.70, y + radius * 0.08), line, 1.0, true)


func _draw_landmass(center: Vector2, radius: float, phase: float, color: Color, index_offset: int) -> void:
	color.a = 0.44
	for island in range(3):
		var points := PackedVector2Array()
		var island_phase := phase + float(island + index_offset) * 0.62
		var island_center := center + Vector2(cos(island_phase) * radius * 0.22, sin(island_phase * 1.4) * radius * 0.30)
		var island_width: float = radius * (0.25 + float(island % 2) * 0.09)
		var island_height: float = radius * (0.13 + float((island + 1) % 2) * 0.06)
		for step in range(12):
			var angle := TAU * float(step) / 12.0
			var wobble := 0.78 + 0.22 * sin(angle * 3.0 + island_phase * 5.0)
			var point := island_center + Vector2(cos(angle) * island_width, sin(angle) * island_height) * wobble
			if point.distance_to(center) <= radius * 0.94:
				points.append(point)
		if points.size() >= 3:
			draw_colored_polygon(points, color)


func _draw_cloud_bands(center: Vector2, radius: float) -> void:
	for band in range(CLOUD_BAND_COUNT):
		var cloud := Color("#f8fafc")
		cloud.a = 0.075 + float(band) * 0.014
		var y: float = center.y - radius * 0.42 + float(band) * radius * 0.26
		var from := Vector2(center.x - radius * 0.62, y)
		var to := Vector2(center.x + radius * 0.58, y + radius * (0.05 if band % 2 == 0 else -0.04))
		draw_line(from, to, cloud, 2.0, true)


func _draw_city_lights(center: Vector2, radius: float) -> void:
	var light := Color("#fde68a")
	for i in range(CITY_LIGHT_COUNT):
		var angle: float = TAU * float((i * 7) % CITY_LIGHT_COUNT) / float(CITY_LIGHT_COUNT)
		var distance: float = radius * (0.28 + float((i * 11) % 9) * 0.062)
		var pos := center + Vector2(cos(angle), sin(angle) * 0.78) * distance
		if pos.x < center.x + radius * 0.08 or pos.distance_to(center) > radius * 0.90:
			continue
		light.a = 0.14 + float((i * 5) % 5) * 0.04
		draw_circle(pos, 0.9 + float(i % 2) * 0.35, light)


func _planet_center() -> Vector2:
	if size.x >= 900.0:
		return Vector2(size.x * 0.42, size.y * 0.55)
	return size * 0.5
