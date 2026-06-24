extends Control

signal district_selected(index: int)

var districts: Array = []
var map_width_m := 1400.0
var map_height_m := 950.0
var selected_district := -1
var monster_world_position := Vector2.ZERO
var guardian_world_position := Vector2.ZERO
var palette: Array = []

var _scale := 1.0
var _map_offset := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(720, 720)


func set_map(
	new_districts: Array,
	width_m: float,
	height_m: float,
	selected: int,
	monster_position_m: Vector2,
	guardian_position_m: Vector2,
	colors: Array
) -> void:
	districts = new_districts
	map_width_m = max(1.0, width_m)
	map_height_m = max(1.0, height_m)
	selected_district = selected
	monster_world_position = monster_position_m
	guardian_world_position = guardian_position_m
	palette = colors
	queue_redraw()


func _draw() -> void:
	if districts.is_empty():
		return
	_scale = min(size.x / map_width_m, size.y / map_height_m)
	if _scale <= 0.01:
		return
	var map_size := Vector2(map_width_m, map_height_m) * _scale
	_map_offset = (size - map_size) * 0.5
	draw_rect(Rect2(_map_offset - Vector2(8, 8), map_size + Vector2(16, 16)), Color("#020617"), true)

	for i in range(districts.size()):
		_draw_region_fill(i)
	for i in range(districts.size()):
		_draw_region_outline(i)
	for i in range(districts.size()):
		_draw_region_label(i)
	_draw_marker(_world_to_screen(monster_world_position), "怪", Color("#ef4444"))
	_draw_marker(_world_to_screen(guardian_world_position), "守", Color("#38bdf8"))
	_draw_scale_hint()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			var world_position := _screen_to_world(mouse_event.position)
			var index := _district_at_point(world_position)
			if index >= 0:
				district_selected.emit(index)


func _draw_region_fill(index: int) -> void:
	var district: Dictionary = districts[index]
	var color := _region_color(index)
	if bool(district.get("destroyed", false)):
		color = Color("#334155")
	var points := _screen_polygon(district.get("polygon", []))
	if points.size() >= 3:
		draw_colored_polygon(points, color)


func _draw_region_outline(index: int) -> void:
	var district: Dictionary = districts[index]
	var points := _screen_polygon(district.get("polygon", []))
	if points.size() < 3:
		return
	var selected := index == selected_district
	var line_color := Color("#facc15") if selected else Color("#020617")
	var line_width := 3.0 if selected else 1.25
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, line_color, line_width, true)


func _draw_region_label(index: int) -> void:
	var district: Dictionary = districts[index]
	var center: Vector2 = district.get("center", Vector2.ZERO)
	var pos := _world_to_screen(center)
	var font := get_theme_default_font()
	var label := String(district.get("name", "区域"))
	var text_width := 96.0
	draw_string(font, pos + Vector2(-text_width * 0.5, -6), label, HORIZONTAL_ALIGNMENT_CENTER, text_width, 12, Color("#f8fafc"))


func _draw_marker(pos: Vector2, text: String, color: Color) -> void:
	var radius: float = clamp(10.0 * _scale * 2.0, 8.0, 14.0)
	draw_circle(pos, radius, color)
	var font := get_theme_default_font()
	draw_string(font, pos + Vector2(-radius * 0.65, radius * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, radius * 2.0, int(radius * 1.3), Color.WHITE)


func _draw_scale_hint() -> void:
	var font := get_theme_default_font()
	var text := "连续地图：%.0fm × %.0fm，距离/范围按米计算" % [map_width_m, map_height_m]
	draw_string(font, _map_offset + Vector2(12, 20), text, HORIZONTAL_ALIGNMENT_LEFT, 420.0, 12, Color("#cbd5e1"))


func _screen_polygon(world_points: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point_variant in world_points:
		result.append(_world_to_screen(point_variant as Vector2))
	return result


func _world_to_screen(position_m: Vector2) -> Vector2:
	return _map_offset + position_m * _scale


func _screen_to_world(position: Vector2) -> Vector2:
	return (position - _map_offset) / max(0.001, _scale)


func _district_at_point(point: Vector2) -> int:
	for i in range(districts.size()):
		var district: Dictionary = districts[i]
		if _point_in_polygon(point, district.get("polygon", [])):
			return i
	return -1


func _point_in_polygon(point: Vector2, polygon: Array) -> bool:
	if polygon.size() < 3:
		return false
	var inside := false
	var j := polygon.size() - 1
	for i in range(polygon.size()):
		var pi: Vector2 = polygon[i]
		var pj: Vector2 = polygon[j]
		var crosses := (pi.y > point.y) != (pj.y > point.y)
		if crosses:
			var x_at_y: float = (pj.x - pi.x) * (point.y - pi.y) / max(0.001, pj.y - pi.y) + pi.x
			if point.x < x_at_y:
				inside = not inside
		j = i
	return inside


func _region_color(index: int) -> Color:
	if palette.is_empty():
		return Color("#1e293b")
	return palette[index % palette.size()] as Color
