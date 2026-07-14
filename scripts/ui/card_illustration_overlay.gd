extends Control
class_name SpaceSyndicateCardIllustrationOverlay

var _accent := Color("#38bdf8")
var _motif := ""
var _intensity := 0.4


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure(accent: Color, motif: String, intensity: float) -> void:
	_accent = accent
	_motif = motif.strip_edges().to_lower()
	_intensity = clampf(intensity, 0.0, 1.0)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if size.x <= 2.0 or size.y <= 2.0:
		return
	_draw_vignette()
	_draw_print_grid()
	match _resolved_motif(_motif):
		"energy_orbit":
			_draw_energy_orbit()
		"warehouse_grid":
			_draw_warehouse_grid()
		"sea_route_arc":
			_draw_sea_route_arc()
		"supply_stream":
			_draw_supply_stream()
		"miasma_field":
			_draw_miasma_field()
		"phase_null":
			_draw_phase_null()
	_draw_print_dots()
	var rim := _accent.lightened(0.28)
	rim.a = 0.20 + _intensity * 0.24
	draw_rect(Rect2(Vector2.ONE, size - Vector2(2.0, 2.0)), rim, false, 1.2)


func get_debug_snapshot() -> Dictionary:
	return {
		"semantic_motif": _motif,
		"resolved_motif": _resolved_motif(_motif),
		"intensity": _intensity,
	}


func _resolved_motif(motif: String) -> String:
	match motif:
		"inbound_sea_procurement":
			return "sea_route_arc"
		"outbound_land_supply":
			return "supply_stream"
		_:
			return motif


func _draw_vignette() -> void:
	var edge := Color("#01040b")
	for index in range(5):
		var t := float(index + 1) / 5.0
		edge.a = (0.035 + t * 0.055) * (0.55 + _intensity * 0.45)
		var thickness := maxf(1.0, minf(size.x, size.y) * 0.035)
		var inset := float(index) * thickness
		draw_rect(Rect2(inset, inset, maxf(1.0, size.x - inset * 2.0), maxf(1.0, size.y - inset * 2.0)), edge, false, thickness)


func _draw_print_grid() -> void:
	var grid := _accent.darkened(0.18)
	grid.a = 0.025 + _intensity * 0.045
	var spacing := maxf(9.0, size.y * 0.18)
	var x := spacing
	while x < size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), grid, 0.8)
		x += spacing
	var y := spacing
	while y < size.y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), grid, 0.8)
		y += spacing


func _draw_energy_orbit() -> void:
	var center := size * Vector2(0.50, 0.48)
	var radius := minf(size.x, size.y) * 0.31
	var color := _accent.lightened(0.26)
	color.a = 0.10 + _intensity * 0.22
	draw_arc(center, radius, -PI * 0.18, PI * 1.14, 48, color, 1.4, true)
	var secondary := color
	secondary.a *= 0.56
	draw_arc(center, radius * 1.28, PI * 0.62, PI * 1.72, 48, secondary, 1.0, true)


func _draw_warehouse_grid() -> void:
	var color := _accent.lightened(0.28)
	color.a = 0.09 + _intensity * 0.18
	var cell := Vector2(maxf(9.0, size.x * 0.12), maxf(7.0, size.y * 0.22))
	for column in range(3):
		for row in range(2):
			var left := 5.0 + float(column) * (cell.x + 3.0)
			var top := size.y - 6.0 - float(row + 1) * (cell.y + 2.0)
			draw_rect(Rect2(Vector2(left, top), cell), color, false, 1.2)
	for index in range(3):
		var x := size.x - 8.0 - float(index) * 9.0
		draw_line(Vector2(x, size.y * 0.18), Vector2(x, size.y * 0.82), color, 1.0)


func _draw_sea_route_arc() -> void:
	var color := Color("#67e8f9")
	color.a = 0.13 + _intensity * 0.24
	var from := Vector2(size.x * 0.08, size.y * 0.76)
	var control := Vector2(size.x * 0.52, -size.y * 0.12)
	var to := Vector2(size.x * 0.94, size.y * 0.62)
	var points := PackedVector2Array()
	for index in range(25):
		var t := float(index) / 24.0
		points.append(from * pow(1.0 - t, 2.0) + control * 2.0 * (1.0 - t) * t + to * t * t)
	draw_polyline(points, color, 1.8, true)
	for node_index in [0, 8, 16, 24]:
		draw_circle(points[node_index], 1.8 + _intensity * 1.2, color)


func _draw_supply_stream() -> void:
	var color := Color("#86efac")
	color.a = 0.12 + _intensity * 0.24
	for row in range(3):
		var y := size.y * (0.30 + float(row) * 0.20)
		var from := Vector2(size.x * 0.08, y + float(row - 1) * 3.0)
		var to := Vector2(size.x * 0.92, y - float(row - 1) * 4.0)
		draw_line(from, to, color, 1.2 + float(row) * 0.35, true)
		draw_line(to, to + Vector2(-6.0, -3.0), color, 1.2, true)
		draw_line(to, to + Vector2(-6.0, 3.0), color, 1.2, true)


func _draw_miasma_field() -> void:
	var mist := Color("#86efac")
	mist.a = 0.035 + _intensity * 0.075
	var radius := minf(size.x, size.y) * 0.24
	for index in range(7):
		var angle := float(index) / 7.0 * TAU
		var center := size * 0.5 + Vector2(cos(angle), sin(angle)) * radius * 1.15
		draw_circle(center, radius * (0.42 + float(index % 3) * 0.12), mist)
	var threat := Color("#fb7185")
	threat.a = 0.08 + _intensity * 0.12
	draw_arc(size * 0.5, radius * 1.48, -PI * 0.92, PI * 0.06, 38, threat, 1.6, true)


func _draw_phase_null() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.28
	var color := Color("#c084fc")
	color.a = 0.12 + _intensity * 0.25
	for ring_index in range(3):
		draw_arc(center, radius * (1.0 + float(ring_index) * 0.34), -PI * 0.18 + ring_index * 0.40, PI * 1.38 + ring_index * 0.32, 42, color, 1.0 + ring_index * 0.35, true)
	var cut := Color("#e0f2fe")
	cut.a = 0.14 + _intensity * 0.22
	draw_line(center + Vector2(-radius * 0.95, radius * 0.78), center + Vector2(radius * 0.95, -radius * 0.78), cut, 1.8, true)


func _draw_print_dots() -> void:
	var dot := Color("#f8fafc")
	dot.a = 0.025 + _intensity * 0.030
	var columns := 9
	var rows := 4
	for column in range(columns):
		for row in range(rows):
			var x := fmod(float(column * 37 + row * 19 + 11), maxf(1.0, size.x - 6.0)) + 3.0
			var y := fmod(float(column * 17 + row * 29 + 7), maxf(1.0, size.y - 6.0)) + 3.0
			draw_circle(Vector2(x, y), 0.55, dot)
