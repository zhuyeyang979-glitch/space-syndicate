@tool
extends Control
class_name SpaceSyndicateOrbitalTableOverlay

@export var reduced_motion := false

var _phase := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(not reduced_motion)
	queue_redraw()


func _process(delta: float) -> void:
	_phase = fmod(_phase + delta * 0.22, TAU)
	queue_redraw()


func _draw() -> void:
	if size.x <= 2.0 or size.y <= 2.0:
		return
	var cyan := Color("#38bdf8")
	var amber := Color("#f5b942")
	var center := Vector2(size.x * 0.39, size.y * 0.51)
	var radius := minf(size.x * 0.28, size.y * 0.38)

	_draw_corner_brackets(cyan)
	_draw_orbital_rail(center, radius, cyan, amber)
	_draw_table_seams(cyan)


func _draw_corner_brackets(accent: Color) -> void:
	var inset := 12.0
	var arm := 46.0
	var c := Color(accent.r, accent.g, accent.b, 0.24)
	draw_line(Vector2(inset, inset + arm), Vector2(inset, inset), c, 2.0, true)
	draw_line(Vector2(inset, inset), Vector2(inset + arm, inset), c, 2.0, true)
	draw_line(Vector2(size.x - inset - arm, inset), Vector2(size.x - inset, inset), c, 2.0, true)
	draw_line(Vector2(size.x - inset, inset), Vector2(size.x - inset, inset + arm), c, 2.0, true)
	draw_line(Vector2(inset, size.y - inset - arm), Vector2(inset, size.y - inset), c, 2.0, true)
	draw_line(Vector2(inset, size.y - inset), Vector2(inset + arm, size.y - inset), c, 2.0, true)


func _draw_orbital_rail(center: Vector2, radius: float, cyan: Color, amber: Color) -> void:
	var pulse := 0.5 + 0.5 * sin(_phase)
	for index in range(3):
		var r := radius + 18.0 + float(index) * 17.0
		var color := cyan if index < 2 else amber
		color.a = 0.08 + float(index) * 0.035 + pulse * 0.025
		draw_arc(center, r, -PI * 0.95, PI * 0.58, 96, color, 1.2 + float(index) * 0.35, true)
	for node_index in range(9):
		var angle := -PI * 0.93 + float(node_index) / 8.0 * PI * 1.48
		var node_pos := center + Vector2(cos(angle), sin(angle)) * (radius + 52.0)
		var glow := cyan if node_index % 3 != 0 else amber
		glow.a = 0.18 + pulse * 0.08
		draw_circle(node_pos, 4.6, glow)
		draw_arc(node_pos, 8.0, 0.0, TAU, 20, Color(glow.r, glow.g, glow.b, 0.12), 1.0, true)


func _draw_table_seams(accent: Color) -> void:
	var line := Color(accent.r, accent.g, accent.b, 0.055)
	var bottom_y := size.y - 118.0
	draw_line(Vector2(20.0, bottom_y), Vector2(size.x * 0.75, bottom_y), line, 1.0, true)
	for index in range(5):
		var x := size.x * (0.08 + float(index) * 0.145)
		draw_line(Vector2(x, bottom_y), Vector2(x - 32.0, size.y), line, 1.0, true)
