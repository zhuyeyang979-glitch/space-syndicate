extends Control

signal district_selected(index: int)
signal district_double_clicked(index: int)

const GLOBE_MODE_ZOOM_THRESHOLD := 0.58
const PLANET_PROJECTION_BLEND_NAME := "PlanetProjectionBlend"
const PLANET_PROJECTION_LOCAL_ZOOM := 0.96
const PLANET_PROJECTION_GLOBE_ZOOM := 0.58
const PLANET_PROJECTION_VISIBILITY_FADE_START := 0.74
const MIN_VIEW_ZOOM := 0.34
const MAX_VIEW_ZOOM := 5.0
const DRAG_THRESHOLD_PIXELS := 4.0
const ANIMATED_REDRAW_INTERVAL_SECONDS := 1.0 / 24.0
const ZOOM_SMOOTHING_SPEED := 12.0
const ZOOM_WHEEL_STEP := 1.11
const LABEL_INTERACTION_ZOOM_EPSILON := 0.018
const INTERACTION_DETAIL_SETTLE_SECONDS := 0.28
const INTERACTION_REDRAW_INTERVAL_SECONDS := 1.0 / 24.0
const GLOBE_POLYGON_DETAIL_STEP_METERS := 45.0
const GLOBE_POLYGON_INTERACTION_STEP_METERS := 120.0
const GLOBE_EDGE_DETAIL_STEP_METERS := 28.0
const GLOBE_EDGE_INTERACTION_STEP_METERS := 90.0
const BETTING_TABLE_THEME_NAME := "星际赌桌"
const BETTING_TABLE_CHIP_COUNT := 18
const BETTING_TABLE_SEAT_COUNT := 8

var districts: Array = []
var map_width_m := 1400.0
var map_height_m := 950.0
var selected_district := -1
var palette: Array = []
var movement_trails: Array = []
var action_callouts: Array = []
var map_event_effects: Array = []
var auto_monster_markers: Array = []
var city_markers: Array = []
var trade_route_markers: Array = []
var trade_product := ""
var visual_layer_focus := "all"

var _scale := 1.0
var _map_offset := Vector2.ZERO
var _view_center_m := Vector2(700.0, 475.0)
var _view_zoom := 1.0
var _target_view_zoom := 1.0
var _dragging := false
var _drag_moved := false
var _drag_start := Vector2.ZERO
var _last_mouse_position := Vector2.ZERO
var _map_signature := ""
var _visual_payload_signature := ""
var _animated_redraw_timer := 0.0
var _interaction_detail_timer := 0.0
var _interaction_redraw_timer := 0.0
var _interaction_redraw_requested := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(720, 720)
	set_process(true)


func betting_table_theme_report() -> Dictionary:
	return {
		"enabled": true,
		"name": BETTING_TABLE_THEME_NAME,
		"felt_color": "#052e24",
		"rim_color": "#d6a440",
		"chip_count": BETTING_TABLE_CHIP_COUNT,
		"seat_count": BETTING_TABLE_SEAT_COUNT,
		"planet_center_policy": "globe_center",
		"detail_policy": "edge_icons_stay_small_until_clicked",
		"projection_contract": PLANET_PROJECTION_BLEND_NAME,
		"projection_policy": "local_xy_eases_into_center_globe",
	}


func _has_active_animation_layers() -> bool:
	return not action_callouts.is_empty() or not movement_trails.is_empty() or not map_event_effects.is_empty()


func _update_smooth_zoom(delta: float) -> bool:
	if is_equal_approx(_view_zoom, _target_view_zoom):
		return false
	var before := _view_zoom
	var weight := clampf(delta * ZOOM_SMOOTHING_SPEED, 0.0, 1.0)
	_view_zoom = lerpf(_view_zoom, _target_view_zoom, weight)
	if absf(_view_zoom - _target_view_zoom) <= 0.002:
		_view_zoom = _target_view_zoom
	return not is_equal_approx(before, _view_zoom)


func _mark_interaction_detail_dirty() -> void:
	_interaction_detail_timer = INTERACTION_DETAIL_SETTLE_SECONDS
	_interaction_redraw_requested = true


func _map_detail_reduced() -> bool:
	return _dragging \
		or _interaction_detail_timer > 0.0 \
		or absf(_view_zoom - _target_view_zoom) > LABEL_INTERACTION_ZOOM_EPSILON


func _process(delta: float) -> void:
	var zoom_changed := _update_smooth_zoom(delta)
	if zoom_changed:
		_mark_interaction_detail_dirty()
	var was_interacting := _interaction_detail_timer > 0.0
	if _interaction_detail_timer > 0.0:
		_interaction_detail_timer = maxf(0.0, _interaction_detail_timer - delta)
	var interaction_settled := was_interacting and _interaction_detail_timer <= 0.0 and not _dragging and not zoom_changed
	_interaction_redraw_timer -= delta
	var has_animated_layers := _has_active_animation_layers()
	if has_animated_layers:
		_animated_redraw_timer -= delta
	var interaction_redraw_due := (zoom_changed or _interaction_redraw_requested) and _interaction_redraw_timer <= 0.0
	if interaction_redraw_due or interaction_settled or (has_animated_layers and _animated_redraw_timer <= 0.0):
		queue_redraw()
		if interaction_redraw_due:
			_interaction_redraw_timer = INTERACTION_REDRAW_INTERVAL_SECONDS
			_interaction_redraw_requested = false
		if has_animated_layers:
			_animated_redraw_timer = ANIMATED_REDRAW_INTERVAL_SECONDS


func set_map(
	new_districts: Array,
	width_m: float,
	height_m: float,
	selected: int,
	colors: Array,
	trails: Array = [],
	callouts: Array = [],
	event_effects: Array = [],
	monster_markers: Array = [],
	new_city_markers: Array = [],
	new_trade_route_markers: Array = [],
	new_trade_product: String = "",
	new_visual_layer_focus: String = "all"
) -> void:
	var next_signature := _build_map_signature(new_districts, width_m, height_m)
	var should_center_view := next_signature != _map_signature
	var next_payload_signature := _build_visual_payload_signature(
		new_districts,
		selected,
		trails,
		callouts,
		event_effects,
		monster_markers,
		new_city_markers,
		new_trade_route_markers,
		new_trade_product,
		new_visual_layer_focus
	)
	var should_redraw := should_center_view or next_payload_signature != _visual_payload_signature
	districts = new_districts
	map_width_m = max(1.0, width_m)
	map_height_m = max(1.0, height_m)
	if should_center_view:
		_view_center_m = Vector2(map_width_m * 0.5, map_height_m * 0.5)
	selected_district = selected
	palette = colors
	movement_trails = trails
	action_callouts = callouts
	map_event_effects = event_effects
	auto_monster_markers = monster_markers
	city_markers = new_city_markers
	trade_route_markers = new_trade_route_markers
	trade_product = new_trade_product
	visual_layer_focus = new_visual_layer_focus
	if should_center_view:
		_map_signature = next_signature
	_visual_payload_signature = next_payload_signature
	if should_redraw:
		queue_redraw()


func _draw() -> void:
	if districts.is_empty():
		return
	_scale = min(size.x / map_width_m, size.y / map_height_m)
	if _scale <= 0.01:
		return
	var globe_blend := _globe_blend()
	var reduced_detail := _map_detail_reduced()
	if globe_blend >= 0.985:
		_draw_globe_projection()
		return
	_scale *= _view_zoom
	_map_offset = size * 0.5
	_draw_betting_table_background(globe_blend)
	if globe_blend > 0.001:
		_draw_projection_transition_backdrop(globe_blend)
	if not reduced_detail:
		_draw_local_grid()

	for i in range(districts.size()):
		if _region_is_near_view(i):
			if reduced_detail:
				_draw_region_fill_fast(i)
			else:
				_draw_region_fill(i)
	if not reduced_detail and _layer_focus_allows("effects"):
		for i in range(districts.size()):
			if _region_is_near_view(i):
				_draw_region_effects(i)
	var draw_dense_labels := _should_draw_dense_region_labels() or visual_layer_focus in ["product", "city", "route", "intel"]
	for i in range(districts.size()):
		if _region_is_near_view(i) and (not reduced_detail or i == selected_district):
			_draw_region_outline(i)
	for i in range(districts.size()):
		if _region_is_near_view(i) and (draw_dense_labels or i == selected_district):
			_draw_region_label(i)
	if _layer_focus_allows("route"):
		_draw_trade_routes()
	if _layer_focus_allows("city"):
		_draw_city_clusters()
	if _layer_focus_allows("movement"):
		_draw_movement_trails()
	if not reduced_detail and _layer_focus_allows("events"):
		_draw_map_event_effects()
	if _layer_focus_allows("monster"):
		_draw_auto_monster_markers()
	if not reduced_detail and _layer_focus_allows("callouts"):
		_draw_action_callouts()
	_draw_scale_hint()


func _layer_focus_allows(layer_id: String) -> bool:
	if visual_layer_focus == "" or visual_layer_focus == "all":
		return true
	match layer_id:
		"route":
			return visual_layer_focus in ["route", "product"]
		"city":
			return visual_layer_focus in ["city", "intel", "route"]
		"monster", "movement":
			return visual_layer_focus == "monster"
		"effects", "events":
			return visual_layer_focus in ["weather", "monster", "city"]
		"callouts":
			return visual_layer_focus in ["weather", "monster", "city", "intel"]
	return visual_layer_focus == layer_id


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			_target_view_zoom = clamp(_target_view_zoom * ZOOM_WHEEL_STEP, MIN_VIEW_ZOOM, MAX_VIEW_ZOOM)
			_mark_interaction_detail_dirty()
			return
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			_target_view_zoom = clamp(_target_view_zoom / ZOOM_WHEEL_STEP, MIN_VIEW_ZOOM, MAX_VIEW_ZOOM)
			_mark_interaction_detail_dirty()
			return
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_dragging = true
				_drag_moved = false
				_drag_start = mouse_event.position
				_last_mouse_position = mouse_event.position
				if mouse_event.double_click:
					var double_world_position := _screen_to_world(mouse_event.position)
					var double_index := _district_at_point(double_world_position)
					if double_index >= 0:
						district_double_clicked.emit(double_index)
					accept_event()
					return
			else:
				_dragging = false
				if not _drag_moved:
					var world_position := _screen_to_world(mouse_event.position)
					var index := _district_at_point(world_position)
					if index >= 0:
						district_selected.emit(index)
				_mark_interaction_detail_dirty()
	if event is InputEventMouseMotion and _dragging:
		var motion_event := event as InputEventMouseMotion
		var delta := motion_event.position - _last_mouse_position
		if motion_event.position.distance_to(_drag_start) > DRAG_THRESHOLD_PIXELS:
			_drag_moved = true
		_pan_view(delta)
		_last_mouse_position = motion_event.position
		_mark_interaction_detail_dirty()


func _is_globe_mode() -> bool:
	return _globe_blend() >= 0.985


func _globe_blend() -> float:
	return _planet_projection_blend()


func _planet_projection_blend() -> float:
	var denom: float = max(0.001, PLANET_PROJECTION_LOCAL_ZOOM - PLANET_PROJECTION_GLOBE_ZOOM)
	var t: float = clamp((PLANET_PROJECTION_LOCAL_ZOOM - _view_zoom) / denom, 0.0, 1.0)
	return _projection_smoothstep(t)


func _projection_smoothstep(t: float) -> float:
	t = clamp(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _projection_visibility_alpha(z_value: float, blend: float) -> float:
	if blend < PLANET_PROJECTION_VISIBILITY_FADE_START:
		return 1.0
	var horizon_fade: float = clampf((z_value + 0.10) / 0.28, 0.0, 1.0)
	return lerp(1.0, horizon_fade, clampf((blend - PLANET_PROJECTION_VISIBILITY_FADE_START) / 0.24, 0.0, 1.0))


func _wrap_world_position(position: Vector2) -> Vector2:
	var x := position.x
	var y := position.y
	var guard := 0
	while (y < 0.0 or y > map_height_m) and guard < 12:
		if y < 0.0:
			y = -y
			x += map_width_m * 0.5
		elif y > map_height_m:
			y = map_height_m - (y - map_height_m)
			x += map_width_m * 0.5
		guard += 1
	return Vector2(fposmod(x, map_width_m), clamp(y, 0.0, map_height_m))


func _surface_delta(from_position: Vector2, to_position: Vector2) -> Vector2:
	var delta := _wrap_world_position(to_position) - _wrap_world_position(from_position)
	if abs(delta.x) > map_width_m * 0.5:
		delta.x -= sign(delta.x) * map_width_m
	return delta


func _surface_distance(from_position: Vector2, to_position: Vector2) -> float:
	var a := _sphere_unit(from_position)
	var b := _sphere_unit(to_position)
	return acos(clamp(a.dot(b), -1.0, 1.0)) * max(1.0, map_width_m / TAU)


func _world_to_lon_lat(position: Vector2) -> Vector2:
	var wrapped := _wrap_world_position(position)
	return Vector2(
		fposmod(wrapped.x / map_width_m * TAU, TAU),
		PI * 0.5 - wrapped.y / map_height_m * PI
	)


func _lon_lat_to_world(lon: float, lat: float) -> Vector2:
	return _wrap_world_position(Vector2(
		fposmod(lon, TAU) / TAU * map_width_m,
		(PI * 0.5 - clamp(lat, -PI * 0.5, PI * 0.5)) / PI * map_height_m
	))


func _sphere_unit(position: Vector2) -> Vector3:
	var lon_lat := _world_to_lon_lat(position)
	var lon := lon_lat.x
	var lat := lon_lat.y
	return Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon)).normalized()


func _globe_radius() -> float:
	return min(size.x, size.y) * lerp(0.47, 0.43, _globe_blend())


func _globe_center() -> Vector2:
	return size * 0.5


func _project_globe(position: Vector2) -> Dictionary:
	var lon_lat := _world_to_lon_lat(position)
	var center_lon_lat := _world_to_lon_lat(_view_center_m)
	var lon := lon_lat.x
	var lat := lon_lat.y
	var lon0 := center_lon_lat.x
	var lat0 := center_lon_lat.y
	var dlon := wrapf(lon - lon0, -PI, PI)
	var projected_x := cos(lat) * sin(dlon)
	var projected_y := cos(lat0) * sin(lat) - sin(lat0) * cos(lat) * cos(dlon)
	var visible_z := sin(lat0) * sin(lat) + cos(lat0) * cos(lat) * cos(dlon)
	return {
		"position": _globe_center() + Vector2(projected_x, -projected_y) * _globe_radius(),
		"visible": visible_z >= -0.02,
		"z": visible_z,
	}


func _screen_to_globe_world(screen_position: Vector2) -> Vector2:
	var radius: float = _globe_radius()
	var p: Vector2 = (screen_position - _globe_center()) / max(1.0, radius)
	p.y = -p.y
	var rho_sq: float = p.length_squared()
	if rho_sq > 1.0:
		return _view_center_m
	var z: float = sqrt(max(0.0, 1.0 - rho_sq))
	var center_lon_lat: Vector2 = _world_to_lon_lat(_view_center_m)
	var lon0: float = center_lon_lat.x
	var lat0: float = center_lon_lat.y
	var lat: float = asin(clamp(z * sin(lat0) + p.y * cos(lat0), -1.0, 1.0))
	var lon: float = lon0 + atan2(p.x, z * cos(lat0) - p.y * sin(lat0))
	return _lon_lat_to_world(lon, lat)


func _pan_view(delta_screen: Vector2) -> void:
	if _globe_blend() > 0.62:
		var radius: float = max(1.0, _globe_radius())
		var lon_lat: Vector2 = _world_to_lon_lat(_view_center_m)
		var lon: float = lon_lat.x - delta_screen.x / radius
		var lat: float = clamp(lon_lat.y + delta_screen.y / radius, -PI * 0.48, PI * 0.48)
		_view_center_m = _lon_lat_to_world(lon, lat)
	else:
		_view_center_m = _wrap_world_position(_view_center_m - delta_screen / max(0.001, _scale))


func _region_is_near_view(index: int) -> bool:
	if _globe_blend() > 0.08:
		return true
	var center: Vector2 = districts[index].get("center", Vector2.ZERO)
	var max_screen_distance: float = max(size.x, size.y) * 0.72
	return _surface_delta(_view_center_m, center).length() * _scale <= max_screen_distance


func _should_draw_dense_region_labels() -> bool:
	if _dragging:
		return false
	if absf(_view_zoom - _target_view_zoom) > LABEL_INTERACTION_ZOOM_EPSILON:
		return false
	if districts.size() > 32 and _globe_blend() > 0.05:
		return false
	return true


func _draw_local_grid() -> void:
	var grid_color := Color("#1e293b")
	grid_color.a = 0.6 * (1.0 - _globe_blend() * 0.72)
	var step_m := 100.0
	for x in range(-8, 9):
		var world_x := _view_center_m.x + float(x) * step_m
		var from := _world_to_screen(Vector2(world_x, _view_center_m.y - 1000.0))
		var to := _world_to_screen(Vector2(world_x, _view_center_m.y + 1000.0))
		draw_line(from, to, grid_color, 1.0)
	for y in range(-8, 9):
		var world_y := _view_center_m.y + float(y) * step_m
		var from_y := _world_to_screen(Vector2(_view_center_m.x - 1400.0, world_y))
		var to_y := _world_to_screen(Vector2(_view_center_m.x + 1400.0, world_y))
		draw_line(from_y, to_y, grid_color, 1.0)


func _draw_betting_table_background(globe_blend: float) -> void:
	var felt := Color("#052e24")
	var dark_felt := Color("#021510")
	draw_rect(Rect2(Vector2.ZERO, size), dark_felt, true)
	var center: Vector2 = _globe_center()
	felt.a = 0.92
	draw_rect(Rect2(Vector2.ZERO, size), felt, true)
	var felt_glow := Color("#064e3b")
	felt_glow.a = 0.50
	draw_circle(center, max(size.x, size.y) * 0.52, felt_glow)
	var reduced_detail := _map_detail_reduced()
	if not reduced_detail:
		_draw_betting_table_weave(globe_blend)
	var planet_radius: float = _globe_radius()
	var rail_radius: float = min(min(size.x, size.y) * 0.49, planet_radius + 34.0)
	var shadow := Color("#020617")
	shadow.a = 0.70
	draw_arc(center, rail_radius + 10.0, 0.0, TAU, 48 if reduced_detail else 128, shadow, 10.0, true)
	var rim := Color("#d6a440")
	rim.a = 0.34 + globe_blend * 0.16
	draw_arc(center, rail_radius + 5.0, 0.0, TAU, 48 if reduced_detail else 128, rim, 3.0, true)
	var inner_rim := Color("#fde68a")
	inner_rim.a = 0.12 + globe_blend * 0.08
	draw_arc(center, max(8.0, planet_radius + 8.0), 0.0, TAU, 48 if reduced_detail else 128, inner_rim, 1.6, true)
	if not reduced_detail:
		_draw_betting_table_edge_chips(center, rail_radius + 22.0, globe_blend)


func _draw_betting_table_weave(globe_blend: float) -> void:
	var line_color := Color("#a7f3d0")
	line_color.a = 0.040 + globe_blend * 0.018
	var step: float = 44.0
	var x: float = fposmod(-_view_center_m.x * 0.018, step)
	while x < size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), line_color, 1.0)
		x += step
	var y: float = fposmod(-_view_center_m.y * 0.018, step)
	while y < size.y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), line_color, 1.0)
		y += step


func _draw_betting_table_edge_chips(center: Vector2, preferred_radius: float, globe_blend: float) -> void:
	var chip_palette := [
		Color("#ef4444"),
		Color("#f59e0b"),
		Color("#38bdf8"),
		Color("#a78bfa"),
		Color("#f8fafc"),
		Color("#22c55e"),
	]
	var safe_radius: float = min(preferred_radius, max(24.0, min(size.x, size.y) * 0.5 - 18.0))
	for i in range(BETTING_TABLE_CHIP_COUNT):
		var angle: float = -PI * 0.5 + TAU * float(i) / float(BETTING_TABLE_CHIP_COUNT)
		var pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * safe_radius
		if pos.x < 8.0 or pos.y < 8.0 or pos.x > size.x - 8.0 or pos.y > size.y - 8.0:
			continue
		var chip_color: Color = chip_palette[i % chip_palette.size()]
		chip_color.a = 0.56 + globe_blend * 0.12
		var chip_radius: float = 4.4 if i % 3 != 0 else 5.8
		var chip_shadow := Color("#020617")
		chip_shadow.a = 0.78
		draw_circle(pos, chip_radius + 2.4, chip_shadow)
		draw_circle(pos, chip_radius, chip_color)
		var chip_mark := Color("#020617")
		chip_mark.a = 0.42
		draw_arc(pos, max(2.0, chip_radius - 1.2), 0.0, TAU, 20, chip_mark, 0.9, true)
	for seat in range(BETTING_TABLE_SEAT_COUNT):
		var seat_angle: float = -PI * 0.5 + TAU * (float(seat) + 0.5) / float(BETTING_TABLE_SEAT_COUNT)
		var seat_pos: Vector2 = center + Vector2(cos(seat_angle), sin(seat_angle)) * max(18.0, safe_radius - 18.0)
		var seat_glow := Color("#facc15")
		seat_glow.a = 0.14 + globe_blend * 0.05
		draw_arc(seat_pos, 9.0, 0.0, TAU, 24, seat_glow, 1.4, true)


func _draw_projection_transition_backdrop(globe_blend: float) -> void:
	var center := _globe_center()
	var radius := _globe_radius()
	var shadow := Color("#02040a")
	shadow.a = 0.18 + globe_blend * 0.46
	draw_circle(center, radius + 6.0 * globe_blend, shadow)
	var ocean := Color("#0f172a")
	ocean.a = 0.08 + globe_blend * 0.36
	draw_circle(center, radius, ocean)
	var edge := Color("#38bdf8")
	edge.a = 0.10 + globe_blend * 0.42
	draw_arc(center, radius, 0.0, TAU, 96, edge, 1.0 + globe_blend * 2.2, true)


func _draw_globe_projection() -> void:
	_draw_betting_table_background(1.0)
	_map_offset = _globe_center()
	var center := _globe_center()
	var radius := _globe_radius()
	var reduced_detail := _map_detail_reduced()
	draw_circle(center, radius + 4.0, Color("#020617"))
	draw_circle(center, radius, Color("#0f172a"))
	for i in range(districts.size()):
		if reduced_detail:
			_draw_globe_region_fill_fast(i)
		else:
			_draw_globe_region_fill(i)
	if not reduced_detail:
		_draw_globe_graticule(center, radius)
	for i in range(districts.size()):
		if not reduced_detail or i == selected_district:
			_draw_globe_region_outline(i)
	var draw_dense_labels := _should_draw_dense_region_labels() or visual_layer_focus in ["product", "city", "route", "intel"]
	for i in range(districts.size()):
		if draw_dense_labels or i == selected_district:
			_draw_globe_region_label(i)
	if _layer_focus_allows("route"):
		_draw_trade_routes()
	if _layer_focus_allows("city"):
		_draw_city_clusters()
	if _layer_focus_allows("movement"):
		_draw_movement_trails()
	if not reduced_detail and _layer_focus_allows("events"):
		_draw_map_event_effects()
	if _layer_focus_allows("monster"):
		_draw_auto_monster_markers()
	if not reduced_detail and _layer_focus_allows("callouts"):
		_draw_action_callouts()
	_draw_scale_hint()


func _draw_globe_graticule(center: Vector2, radius: float) -> void:
	var grid_color := Color("#38bdf8")
	grid_color.a = 0.09
	for lon_step in range(0, 12):
		var points := PackedVector2Array()
		for lat_step in range(-18, 19):
			var lon := float(lon_step) / 12.0 * TAU
			var lat := float(lat_step) / 18.0 * PI * 0.5
			var projected := _project_globe(_lon_lat_to_world(lon, lat))
			if bool(projected["visible"]):
				points.append(projected["position"] as Vector2)
		if points.size() > 1:
			draw_polyline(points, grid_color, 0.8, true)
	for lat_step in range(-4, 5):
		var lat := float(lat_step) / 5.0 * PI * 0.5
		var points := PackedVector2Array()
		for lon_step in range(0, 73):
			var lon := float(lon_step) / 72.0 * TAU
			var projected := _project_globe(_lon_lat_to_world(lon, lat))
			if bool(projected["visible"]):
				points.append(projected["position"] as Vector2)
		if points.size() > 1:
			draw_polyline(points, grid_color, 0.8, true)


func _draw_globe_region_fill(index: int) -> void:
	var district: Dictionary = districts[index]
	var points := _globe_projected_polygon(district.get("polygon", []))
	var color := _region_color(index)
	if bool(district.get("destroyed", false)):
		color = Color("#475569")
	else:
		var damage_ratio: float = float(district.get("damage", 0)) / max(1.0, float(district.get("hp", 1)))
		var panic_ratio: float = float(district.get("panic", 0)) / 100.0
		color = color.lerp(Color("#7f1d1d"), clamp(damage_ratio * 0.45, 0.0, 0.45))
		color = color.lerp(Color("#f97316"), clamp(panic_ratio * 0.14, 0.0, 0.14))
	color.a = 0.76
	if points.size() >= 3 and _can_fill_polygon(points):
		draw_colored_polygon(points, color)
	else:
		var projected := _project_globe(district.get("center", Vector2.ZERO))
		if bool(projected["visible"]):
			var pos: Vector2 = projected["position"]
			var marker_radius: float = clamp(float(district.get("radius_m", 45.0)) * _scale * _view_zoom * 0.18, 2.5, 8.0)
			draw_circle(pos, marker_radius, color)


func _draw_globe_region_fill_fast(index: int) -> void:
	var district: Dictionary = districts[index]
	var projected := _project_globe(district.get("center", Vector2.ZERO))
	if not bool(projected["visible"]):
		return
	var pos: Vector2 = projected["position"]
	var color := _region_color(index)
	if bool(district.get("destroyed", false)):
		color = Color("#475569")
	else:
		var damage_ratio: float = float(district.get("damage", 0)) / max(1.0, float(district.get("hp", 1)))
		color = color.lerp(Color("#7f1d1d"), clamp(damage_ratio * 0.34, 0.0, 0.34))
	color.a = 0.74 * _projection_visibility_alpha(float(projected.get("z", 1.0)), 1.0)
	var marker_radius: float = clamp(float(district.get("radius_m", 45.0)) * _globe_radius() / max(1.0, map_width_m) * 0.40, 2.8, 9.0)
	if index == selected_district:
		var selected_glow := Color("#facc15")
		selected_glow.a = 0.34
		draw_circle(pos, marker_radius + 5.0, selected_glow)
	draw_circle(pos, marker_radius, color)


func _draw_globe_region_outline(index: int) -> void:
	var district: Dictionary = districts[index]
	var selected := index == selected_district
	var line_color := Color("#facc15") if selected else Color("#7dd3fc")
	line_color.a = 0.98 if selected else 0.62
	var line_width := 2.6 if selected else 1.45
	_draw_globe_polygon_outline(district.get("polygon", []), line_color, line_width)


func _draw_globe_region_label(index: int) -> void:
	var district: Dictionary = districts[index]
	var projected := _project_globe(district.get("center", Vector2.ZERO))
	if not bool(projected["visible"]):
		return
	var pos: Vector2 = projected["position"]
	var center_dot := Color("#f8fafc")
	center_dot.a = 0.58
	draw_circle(pos, 2.0, center_dot)
	if index == selected_district:
		draw_arc(pos, 10.0, 0.0, TAU, 24, Color("#facc15"), 2.0, true)
		var font := get_theme_default_font()
		var label := String(district.get("name", "区域"))
		draw_string(font, pos + Vector2(-48, -20), label, HORIZONTAL_ALIGNMENT_CENTER, 96, 11, Color("#fef3c7"))
		_draw_selected_region_card_badges(index, pos + Vector2(14.0, 16.0))


func _globe_projected_polygon(world_polygon: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	if world_polygon.size() < 3:
		return points
	var step_m := GLOBE_POLYGON_INTERACTION_STEP_METERS if _map_detail_reduced() else GLOBE_POLYGON_DETAIL_STEP_METERS
	var max_steps := 8 if _map_detail_reduced() else 18
	for i in range(world_polygon.size()):
		var a: Vector2 = world_polygon[i]
		var b: Vector2 = world_polygon[(i + 1) % world_polygon.size()]
		var delta := _surface_delta(a, b)
		var steps: int = clampi(int(ceil(delta.length() / step_m)), 2, max_steps)
		for step in range(steps):
			var t := float(step) / float(steps)
			var projected := _project_globe(_wrap_world_position(a + delta * t))
			if bool(projected["visible"]):
				var screen_point: Vector2 = projected["position"]
				if points.is_empty() or points[points.size() - 1].distance_to(screen_point) > 0.5:
					points.append(screen_point)
	return points


func _draw_globe_polygon_outline(world_polygon: Array, color: Color, width: float) -> void:
	if world_polygon.size() < 2:
		return
	for i in range(world_polygon.size()):
		var a: Vector2 = world_polygon[i]
		var b: Vector2 = world_polygon[(i + 1) % world_polygon.size()]
		_draw_globe_edge(a, b, color, width)


func _draw_globe_edge(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	var delta := _surface_delta(a, b)
	var step_m := GLOBE_EDGE_INTERACTION_STEP_METERS if _map_detail_reduced() else GLOBE_EDGE_DETAIL_STEP_METERS
	var steps: int = clampi(int(ceil(delta.length() / step_m)), 2, 12 if _map_detail_reduced() else 24)
	var run := PackedVector2Array()
	for step in range(steps + 1):
		var t := float(step) / float(steps)
		var projected := _project_globe(_wrap_world_position(a + delta * t))
		if bool(projected["visible"]):
			run.append(projected["position"] as Vector2)
		else:
			if run.size() > 1:
				draw_polyline(run, color, width, true)
			run = PackedVector2Array()
	if run.size() > 1:
		draw_polyline(run, color, width, true)


func _draw_region_fill_fast(index: int) -> void:
	var district: Dictionary = districts[index]
	var center: Vector2 = district.get("center", Vector2.ZERO)
	var pos := _world_to_screen(center)
	var color := _region_color(index)
	if bool(district.get("destroyed", false)):
		color = Color("#334155")
	else:
		var damage_ratio: float = float(district.get("damage", 0)) / max(1.0, float(district.get("hp", 1)))
		color = color.lerp(Color("#7f1d1d"), clamp(damage_ratio * 0.38, 0.0, 0.38))
	color.a = 0.72 * _projection_visibility_alpha_for_district(index)
	var radius: float = clamp(float(district.get("radius_m", 48.0)) * _scale * 0.30, 4.0, 18.0)
	if index == selected_district:
		var selected_glow := Color("#facc15")
		selected_glow.a = 0.30
		draw_circle(pos, radius + 5.0, selected_glow)
	draw_circle(pos, radius, color)


func _draw_region_fill(index: int) -> void:
	var district: Dictionary = districts[index]
	var color := _region_color(index)
	if bool(district.get("destroyed", false)):
		color = Color("#334155")
	else:
		var damage_ratio: float = float(district.get("damage", 0)) / max(1.0, float(district.get("hp", 1)))
		var panic_ratio: float = float(district.get("panic", 0)) / 100.0
		color = color.lerp(Color("#7f1d1d"), clamp(damage_ratio * 0.55, 0.0, 0.55))
		color = color.lerp(Color("#f97316"), clamp(panic_ratio * 0.18, 0.0, 0.18))
	color.a *= _projection_visibility_alpha_for_district(index)
	var points := _screen_polygon(district.get("polygon", []))
	if points.size() >= 3:
		if _can_fill_polygon(points):
			draw_colored_polygon(points, color)
		else:
			draw_circle(_world_to_screen(district.get("center", Vector2.ZERO)), clamp(float(district.get("radius_m", 45.0)) * _scale * 0.38, 6.0, 18.0), color)


func _draw_region_effects(index: int) -> void:
	var district: Dictionary = districts[index]
	var points := _screen_polygon(district.get("polygon", []))
	if points.size() < 3:
		return
	var projection_alpha := _projection_visibility_alpha_for_district(index)
	var pulse: float = float(district.get("pulse", 0.0))
	if pulse > 0.0:
		var pulse_color: Color = district.get("pulse_color", Color("#facc15"))
		pulse_color.a = clamp(pulse / 1.2, 0.0, 1.0) * 0.38 * projection_alpha
		if _can_fill_polygon(points):
			draw_colored_polygon(points, pulse_color)
		else:
			draw_circle(_world_to_screen(district.get("center", Vector2.ZERO)), clamp(float(district.get("radius_m", 45.0)) * _scale * 0.45, 8.0, 22.0), pulse_color)
	if bool(district.get("miasma", false)):
		var center := _world_to_screen(district.get("center", Vector2.ZERO))
		var radius: float = clamp(16.0 * _scale, 7.0, 13.0)
		var miasma_color := Color("#a855f7")
		miasma_color.a = 0.42 * projection_alpha
		draw_circle(center, radius, miasma_color)
		var miasma_ring := Color("#c084fc")
		miasma_ring.a *= projection_alpha
		draw_arc(center, radius + 3.0, 0.0, TAU, 24, miasma_ring, 2.0, true)
	if int(district.get("damage", 0)) > 0 and not bool(district.get("destroyed", false)):
		var center_damage := _world_to_screen(district.get("center", Vector2.ZERO))
		var damage_ratio: float = float(district.get("damage", 0)) / max(1.0, float(district.get("hp", 1)))
		var damage_color := Color("#fca5a5")
		damage_color.a *= projection_alpha
		draw_arc(center_damage, clamp(24.0 * _scale, 12.0, 20.0), -PI * 0.5, -PI * 0.5 + TAU * clamp(damage_ratio, 0.0, 1.0), 18, damage_color, 3.0, true)


func _draw_region_outline(index: int) -> void:
	var district: Dictionary = districts[index]
	var points := _screen_polygon(district.get("polygon", []))
	if points.size() < 3:
		return
	var selected := index == selected_district
	var line_color := Color("#facc15") if selected else Color("#020617")
	line_color.a *= _projection_visibility_alpha_for_district(index)
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
	var blend := _globe_blend()
	var label_alpha: float = _projection_visibility_alpha_for_district(index) * (1.0 - clampf((blend - 0.36) / 0.48, 0.0, 1.0) * 0.72)
	if label_alpha <= 0.05 and index != selected_district:
		return
	var label_color := Color("#f8fafc")
	label_color.a = 0.90 * label_alpha
	if index == selected_district:
		label_color = Color("#fef3c7")
		label_color.a = maxf(0.82, label_alpha)
	draw_string(font, pos + Vector2(-text_width * 0.5, -30), label, HORIZONTAL_ALIGNMENT_CENTER, text_width, 12, label_color)
	var terrain := String(district.get("terrain", "land"))
	var sublabel := "海运"
	if terrain != "ocean":
		sublabel = "产%d/需%d" % [
			(district.get("products", []) as Array).size(),
			(district.get("demands", []) as Array).size(),
		]
	var sub_color := Color("#bae6fd") if terrain == "ocean" else Color("#bbf7d0")
	sub_color.a = 0.86 * label_alpha
	draw_string(font, pos + Vector2(-text_width * 0.5, -16), sublabel, HORIZONTAL_ALIGNMENT_CENTER, text_width, 10, sub_color)
	var hp_total: int = maxi(1, int(district.get("hp", 1)))
	var hp_left: int = maxi(0, hp_total - int(district.get("damage", 0)))
	var hp_color := Color("#fecaca") if hp_left <= maxi(1, int(ceil(float(hp_total) * 0.35))) else Color("#fde68a")
	hp_color.a = 0.84 * label_alpha
	draw_string(font, pos + Vector2(-text_width * 0.5, -4), "HP %d/%d" % [hp_left, hp_total], HORIZONTAL_ALIGNMENT_CENTER, text_width, 9, hp_color)
	if index == selected_district:
		_draw_selected_region_card_badges(index, pos + Vector2(20.0, 18.0))


func _draw_selected_region_card_badges(index: int, anchor: Vector2) -> void:
	if index < 0 or index >= districts.size():
		return
	var district: Dictionary = districts[index]
	var choices: Array = district.get("card_choices", [])
	if choices.is_empty():
		return
	var font := get_theme_default_font()
	var width := 118.0
	var height := 30.0
	var x: float = clamp(anchor.x, 8.0, max(8.0, size.x - width - 8.0))
	var y: float = clamp(anchor.y, 34.0, max(34.0, size.y - height - 8.0))
	if _is_globe_mode():
		var globe_center := _globe_center()
		x = clamp(globe_center.x - _globe_radius() - width - 16.0, 10.0, max(10.0, size.x - width - 10.0))
		y = clamp(globe_center.y - height * 0.5, 34.0, max(34.0, size.y - height - 10.0))
	var background := Color("#020617")
	background.a = 0.82
	var rect := Rect2(x, y, width, height)
	draw_rect(rect, background, true)
	draw_rect(rect, Color("#f59e0b"), false, 1.2)
	draw_circle(Vector2(x + 14.0, y + 15.0), 6.0, Color("#f59e0b"))
	draw_string(font, Vector2(x + 5.5, y + 18.5), "+", HORIZONTAL_ALIGNMENT_CENTER, 17.0, 12, Color("#020617"))
	draw_string(font, Vector2(x + 25.0, y + 13.0), "牌架 %d" % choices.size(), HORIZONTAL_ALIGNMENT_LEFT, width - 32.0, 10, Color("#fde68a"))
	draw_string(font, Vector2(x + 25.0, y + 25.0), "双击区域看牌", HORIZONTAL_ALIGNMENT_LEFT, width - 32.0, 8, Color("#cbd5e1"))


func _draw_trade_routes() -> void:
	if trade_route_markers.is_empty():
		return
	var font := get_theme_default_font()
	var reduced_detail := _map_detail_reduced()
	for route_variant in trade_route_markers:
		var route: Dictionary = route_variant
		var points: Array = route.get("points", [])
		if points.size() < 2:
			continue
		var disrupted := bool(route.get("disrupted", false))
		var color := Color("#fb7185") if disrupted else Color("#38bdf8")
		color.a = 0.68 if disrupted else 0.56
		for i in range(points.size() - 1):
			var from_world: Vector2 = points[i]
			var to_world: Vector2 = points[i + 1]
			if _is_globe_mode():
				var from_projected := _project_globe(from_world)
				var to_projected := _project_globe(to_world)
				if not bool(from_projected["visible"]) and not bool(to_projected["visible"]):
					continue
				_draw_trade_segment(from_projected["position"], to_projected["position"], color, disrupted)
			else:
				_draw_trade_segment(_world_to_screen(from_world), _world_to_screen(to_world), color, disrupted)
		if reduced_detail:
			continue
		var label_index: int = clampi(int(points.size() / 2), 0, points.size() - 1)
		var label_world: Vector2 = points[label_index]
		if _is_globe_mode():
			var projected := _project_globe(label_world)
			if not bool(projected["visible"]):
				continue
			label_world = projected["position"]
		else:
			label_world = _world_to_screen(label_world)
		var label := "%s%s" % [String(route.get("product", trade_product)), " 受损" if disrupted else ""]
		draw_string(font, label_world + Vector2(8.0, -8.0), _short_action_text(label, 14), HORIZONTAL_ALIGNMENT_LEFT, 120.0, 11, color.lightened(0.18))


func _draw_trade_segment(from_pos: Vector2, to_pos: Vector2, color: Color, disrupted: bool) -> void:
	if from_pos.distance_to(to_pos) <= 1.0:
		return
	if disrupted:
		var direction: Vector2 = to_pos - from_pos
		var length: float = direction.length()
		var forward: Vector2 = direction / max(1.0, length)
		var cursor: float = 0.0
		while cursor < length:
			var next_cursor: float = min(length, cursor + 14.0)
			draw_line(from_pos + forward * cursor, from_pos + forward * next_cursor, color, 3.0, true)
			cursor += 24.0
	else:
		draw_line(from_pos, to_pos, color, 2.2, true)
	var pulse_color := color.lightened(0.25)
	pulse_color.a = min(0.85, color.a + 0.12)
	draw_circle(to_pos, 3.0, pulse_color)


func _draw_city_clusters() -> void:
	for marker_variant in city_markers:
		var marker: Dictionary = marker_variant
		var world_position: Vector2 = marker.get("position", Vector2.ZERO)
		var pos := _world_to_screen(world_position)
		if _is_globe_mode():
			var projected := _project_globe(world_position)
			if not bool(projected["visible"]):
				continue
			pos = projected["position"]
		_draw_city_cluster(pos, marker)


func _draw_city_cluster(pos: Vector2, marker: Dictionary) -> void:
	var font := get_theme_default_font()
	var active := bool(marker.get("active", true))
	var tag_color: Color = marker.get("tag_color", Color("#94a3b8"))
	if _is_globe_mode() or _map_detail_reduced():
		var pin_color := Color("#64748b") if active else Color("#3f3f46")
		draw_rect(Rect2(pos + Vector2(-3.0, -7.0), Vector2(3.0, 7.0)), pin_color, true)
		draw_rect(Rect2(pos + Vector2(1.0, -10.0), Vector2(3.0, 10.0)), pin_color.lightened(0.16), true)
		draw_circle(pos + Vector2(0.0, -13.0), 5.0, Color("#020617"))
		draw_circle(pos + Vector2(0.0, -13.0), 3.5, tag_color)
		return
	if not active:
		var rubble := Color("#52525b")
		draw_rect(Rect2(pos + Vector2(-18.0, 7.0), Vector2(36.0, 5.0)), Color("#18181b"), true)
		draw_line(pos + Vector2(-15.0, 5.0), pos + Vector2(-4.0, -5.0), rubble, 5.0, true)
		draw_line(pos + Vector2(-1.0, 5.0), pos + Vector2(11.0, -2.0), rubble, 6.0, true)
		draw_string(font, pos + Vector2(-36.0, 28.0), "城市废墟", HORIZONTAL_ALIGNMENT_CENTER, 72.0, 10, Color("#a1a1aa"))
		return

	var rise: float = smoothstep(0.0, 1.0, float(marker.get("rise", 1.0)))
	var level_scale: float = 1.0 + float(max(0, int(marker.get("level", 1)) - 1)) * 0.08
	var base_color := Color("#475569")
	var edge_color := Color("#94a3b8")
	var window_color := Color("#67e8f9")
	var widths := [13.0, 15.0, 11.0, 9.0]
	var heights := [29.0, 43.0, 34.0, 24.0]
	var offsets := [-23.0, -8.0, 9.0, 21.0]
	_draw_ellipse_shadow(pos)
	for i in range(widths.size()):
		var width: float = float(widths[i]) * level_scale
		var height: float = float(heights[i]) * level_scale * rise
		var x: float = float(offsets[i]) - width * 0.5
		var rect := Rect2(pos + Vector2(x, 8.0 - height), Vector2(width, height))
		draw_rect(rect, base_color.lightened(float(i) * 0.035), true)
		draw_line(rect.position, rect.position + Vector2(width, 0.0), edge_color, 1.2, true)
		if height > 14.0:
			var rows: int = min(4, int(height / 8.0))
			for row in range(rows):
				var window_y := rect.position.y + 6.0 + row * 7.0
				draw_rect(Rect2(Vector2(rect.position.x + 3.0, window_y), Vector2(max(2.0, width - 6.0), 2.0)), window_color, true)

	var tag := String(marker.get("tag", "?"))
	var tag_pos := pos + Vector2(25.0, -34.0)
	var tag_radius := 11.0 if tag.length() <= 1 else 14.0
	draw_circle(tag_pos, tag_radius + 2.0, Color("#020617"))
	draw_circle(tag_pos, tag_radius, tag_color)
	draw_string(font, tag_pos + Vector2(-tag_radius, 4.0), tag, HORIZONTAL_ALIGNMENT_CENTER, tag_radius * 2.0, 10, Color.WHITE)

	var products: Array = marker.get("products", [])
	var product_text := ""
	if not products.is_empty():
		product_text = String(products[0])
		if products.size() > 1:
			product_text += " / %s" % String(products[1])
		if products.size() > 2:
			product_text += " +%d" % (products.size() - 2)
	draw_string(font, pos + Vector2(-56.0, 25.0), product_text, HORIZONTAL_ALIGNMENT_CENTER, 112.0, 10, Color("#a7f3d0"))


func _draw_ellipse_shadow(pos: Vector2) -> void:
	var shadow := Color("#020617")
	shadow.a = 0.72
	draw_set_transform(pos, 0.0, Vector2(1.8, 0.42))
	draw_circle(Vector2(0.0, 20.0), 18.0, shadow)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_auto_monster_markers() -> void:
	var font := get_theme_default_font()
	for marker_variant in auto_monster_markers:
		var marker: Dictionary = marker_variant
		var color: Color = marker.get("color", Color("#ef4444"))
		if bool(marker.get("down", false)):
			color = Color("#64748b")
		var pos := _world_to_screen(marker.get("position", Vector2.ZERO))
		if _is_globe_mode():
			var projected := _project_globe(marker.get("position", Vector2.ZERO))
			if not bool(projected["visible"]):
				continue
			pos = projected["position"]
		_draw_monster_token(pos, marker, color)
		if not _map_detail_reduced():
			var name := _short_action_text(String(marker.get("name", "怪兽")), 8)
			draw_string(font, pos + Vector2(18, -14), name, HORIZONTAL_ALIGNMENT_LEFT, 92.0, 11, color)


func _draw_monster_token(pos: Vector2, marker: Dictionary, color: Color) -> void:
	var radius: float = clamp(13.0 * _scale * 2.0, 13.0, 21.0)
	var secondary: Color = marker.get("secondary", Color("#e2e8f0"))
	var slot_color: Color = marker.get("slot_color", color)
	var motif := String(marker.get("motif", "beast"))
	var glyph := String(marker.get("glyph", String(marker.get("label", "?"))))
	var base := color.darkened(0.08)
	var glow := secondary.lightened(0.12)
	glow.a = 0.24
	if _map_detail_reduced():
		draw_circle(pos, radius + 2.0, Color("#020617"))
		draw_circle(pos, radius, base)
		draw_arc(pos, radius + 1.0, 0.0, TAU, 18, slot_color, 2.0, true)
		var font := get_theme_default_font()
		draw_string(font, pos + Vector2(-radius, radius * 0.35), glyph, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, int(clamp(radius * 1.10, 12.0, 18.0)), Color("#f8fafc"))
		return
	draw_circle(pos, radius + 6.0, glow)
	draw_circle(pos, radius + 2.5, Color("#020617"))
	draw_circle(pos, radius, base)
	_draw_monster_token_motif(pos, radius, motif, color, secondary)
	var border := color.lightened(0.25)
	draw_arc(pos, radius + 1.0, 0.0, TAU, 32, border, 2.0, true)
	draw_arc(pos, radius + 4.0, -PI * 0.35, PI * 0.88, 28, slot_color, 2.0, true)

	var font := get_theme_default_font()
	var glyph_size: int = int(clamp(radius * 1.22, 14.0, 22.0))
	draw_string(font, pos + Vector2(-radius, radius * 0.35 + 1.5), glyph, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, glyph_size, Color("#020617"))
	draw_string(font, pos + Vector2(-radius, radius * 0.35), glyph, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, glyph_size, Color("#f8fafc"))

	var slot_label := String(marker.get("label", "?"))
	var label_pos := pos + Vector2(radius * 0.72, -radius * 0.72)
	draw_circle(label_pos, max(6.0, radius * 0.34), Color("#020617"))
	draw_circle(label_pos, max(4.8, radius * 0.26), slot_color)
	draw_string(font, label_pos + Vector2(-radius * 0.26, radius * 0.16), slot_label, HORIZONTAL_ALIGNMENT_CENTER, radius * 0.52, int(max(8.0, radius * 0.45)), Color.WHITE)

	if bool(marker.get("down", false)):
		var slash := Color("#f8fafc")
		slash.a = 0.82
		draw_line(pos + Vector2(-radius * 0.70, radius * 0.70), pos + Vector2(radius * 0.70, -radius * 0.70), slash, 3.0, true)


func _draw_monster_token_motif(pos: Vector2, radius: float, motif: String, color: Color, secondary: Color) -> void:
	var detail := secondary.lightened(0.16)
	detail.a = 0.72
	match motif:
		"miasma":
			for i in range(5):
				var angle := float(i) / 5.0 * TAU
				draw_circle(pos + Vector2(cos(angle), sin(angle)) * radius * 0.42, radius * 0.16, detail)
		"mud":
			var body := PackedVector2Array([
				pos + Vector2(-radius * 0.58, radius * 0.34),
				pos + Vector2(-radius * 0.30, -radius * 0.44),
				pos + Vector2(radius * 0.24, -radius * 0.54),
				pos + Vector2(radius * 0.58, radius * 0.28),
				pos + Vector2(-radius * 0.04, radius * 0.58),
			])
			draw_colored_polygon(body, color.darkened(0.18))
			draw_line(pos + Vector2(-radius * 0.56, radius * 0.55), pos + Vector2(radius * 0.58, radius * 0.45), detail, 2.4, true)
		"meteor_sentinel", "prism_armor":
			var head := Rect2(pos - Vector2(radius * 0.48, radius * 0.36), Vector2(radius * 0.96, radius * 0.72))
			draw_rect(head, color.darkened(0.18), true)
			draw_rect(Rect2(head.position + Vector2(radius * 0.18, radius * 0.24), Vector2(radius * 0.60, radius * 0.12)), detail, true)
			if motif == "prism_armor":
				draw_line(pos + Vector2(0.0, -radius * 0.56), pos + Vector2(0.0, radius * 0.22), detail, 2.0, true)
		"oasis_support":
			draw_line(pos + Vector2(-radius * 0.46, 0.0), pos + Vector2(radius * 0.46, 0.0), detail, 3.0, true)
			draw_line(pos + Vector2(0.0, -radius * 0.46), pos + Vector2(0.0, radius * 0.46), detail, 3.0, true)
		"ember_ring":
			var flame := PackedVector2Array([
				pos + Vector2(0.0, -radius * 0.62),
				pos + Vector2(radius * 0.42, radius * 0.12),
				pos + Vector2(0.0, radius * 0.62),
				pos + Vector2(-radius * 0.42, radius * 0.12),
			])
			draw_colored_polygon(flame, color.lightened(0.08))
			draw_circle(pos + Vector2(0.0, radius * 0.16), radius * 0.20, detail)
		"blue_lancer":
			draw_line(pos + Vector2(-radius * 0.58, radius * 0.54), pos + Vector2(radius * 0.58, -radius * 0.58), detail, 3.0, true)
			draw_line(pos + Vector2(-radius * 0.20, -radius * 0.54), pos + Vector2(radius * 0.26, radius * 0.52), detail, 1.6, true)
		"mirror_hunter":
			var eye := Rect2(pos - Vector2(radius * 0.48, radius * 0.08), Vector2(radius * 0.96, radius * 0.16))
			draw_rect(eye, detail, true)
			draw_line(pos + Vector2(-radius * 0.50, -radius * 0.36), pos + Vector2(-radius * 0.76, -radius * 0.64), detail, 1.6, true)
			draw_line(pos + Vector2(radius * 0.50, -radius * 0.36), pos + Vector2(radius * 0.76, -radius * 0.64), detail, 1.6, true)
		"force":
			var shield := PackedVector2Array([
				pos + Vector2(0.0, -radius * 0.62),
				pos + Vector2(radius * 0.50, -radius * 0.22),
				pos + Vector2(radius * 0.36, radius * 0.42),
				pos + Vector2(0.0, radius * 0.66),
				pos + Vector2(-radius * 0.36, radius * 0.42),
				pos + Vector2(-radius * 0.50, -radius * 0.22),
			])
			draw_colored_polygon(shield, color.darkened(0.12))
			draw_line(pos + Vector2(-radius * 0.28, -radius * 0.04), pos + Vector2(radius * 0.28, -radius * 0.04), detail, 2.2, true)
			draw_line(pos + Vector2(0.0, -radius * 0.34), pos + Vector2(0.0, radius * 0.36), detail, 2.2, true)
		"fighter":
			var wing := PackedVector2Array([
				pos + Vector2(0.0, -radius * 0.72),
				pos + Vector2(radius * 0.18, radius * 0.04),
				pos + Vector2(radius * 0.72, radius * 0.30),
				pos + Vector2(radius * 0.12, radius * 0.28),
				pos + Vector2(0.0, radius * 0.68),
				pos + Vector2(-radius * 0.12, radius * 0.28),
				pos + Vector2(-radius * 0.72, radius * 0.30),
				pos + Vector2(-radius * 0.18, radius * 0.04),
			])
			draw_colored_polygon(wing, color.darkened(0.12))
			draw_polyline(wing, detail, 1.8, true)
		"bomber":
			draw_circle(pos + Vector2(0.0, -radius * 0.12), radius * 0.34, color.darkened(0.10))
			for i in range(3):
				var x := (float(i) - 1.0) * radius * 0.30
				draw_line(pos + Vector2(x, radius * 0.05), pos + Vector2(x * 0.50, radius * 0.62), detail, 2.0, true)
		"tank":
			var body := Rect2(pos - Vector2(radius * 0.58, radius * 0.18), Vector2(radius * 1.16, radius * 0.44))
			draw_rect(body, color.darkened(0.16), true)
			draw_rect(body, detail, false, 1.6)
			draw_line(pos + Vector2(radius * 0.08, -radius * 0.10), pos + Vector2(radius * 0.66, -radius * 0.34), detail, 2.4, true)
		"missile":
			for i in range(2):
				var x := (float(i) - 0.5) * radius * 0.34
				draw_line(pos + Vector2(x, radius * 0.58), pos + Vector2(x, -radius * 0.70), detail, 2.4, true)
				draw_circle(pos + Vector2(x, -radius * 0.70), radius * 0.08, secondary)
			draw_arc(pos, radius * 0.68, PI * 0.12, PI * 0.88, 28, detail, 1.8, true)
		"submarine":
			draw_arc(pos, radius * 0.66, PI * 0.05, PI * 0.95, 28, detail, 2.4, true)
			draw_line(pos + Vector2(0.0, -radius * 0.42), pos + Vector2(0.0, -radius * 0.68), detail, 2.0, true)
			draw_line(pos + Vector2(-radius * 0.50, radius * 0.32), pos + Vector2(radius * 0.50, radius * 0.32), detail, 2.0, true)
		"warship":
			var hull := PackedVector2Array([
				pos + Vector2(-radius * 0.70, radius * 0.08),
				pos + Vector2(radius * 0.70, radius * 0.08),
				pos + Vector2(radius * 0.40, radius * 0.48),
				pos + Vector2(-radius * 0.42, radius * 0.48),
			])
			draw_colored_polygon(hull, color.darkened(0.14))
			draw_polyline(hull, detail, 1.8, true)
			draw_line(pos + Vector2(0.0, radius * 0.04), pos + Vector2(0.0, -radius * 0.52), detail, 2.2, true)
		_:
			draw_line(pos + Vector2(-radius * 0.26, -radius * 0.42), pos + Vector2(-radius * 0.58, -radius * 0.72), detail, 2.2, true)
			draw_line(pos + Vector2(radius * 0.26, -radius * 0.42), pos + Vector2(radius * 0.58, -radius * 0.72), detail, 2.2, true)


func _draw_range_ring(center_m: Vector2, radius_m: float, color: Color, label: String) -> void:
	var center := _world_to_screen(center_m)
	var radius := radius_m * _scale
	if radius < 8.0:
		return
	color.a = 0.38
	draw_arc(center, radius, 0.0, TAU, 64, color, 1.5, true)
	var font := get_theme_default_font()
	var label_color := color
	label_color.a = 0.78
	draw_string(font, center + Vector2(radius + 5.0, -3.0), label, HORIZONTAL_ALIGNMENT_LEFT, 110.0, 11, label_color)


func _draw_movement_trails() -> void:
	var font := get_theme_default_font()
	var reduced_detail := _map_detail_reduced()
	for trail_variant in movement_trails:
		var trail: Dictionary = trail_variant
		var from_world: Vector2 = trail.get("from", Vector2.ZERO)
		var to_world: Vector2 = trail.get("to", Vector2.ZERO)
		var from_pos := _world_to_screen(from_world)
		var to_pos := _world_to_screen(to_world)
		if _is_globe_mode():
			var from_projected := _project_globe(from_world)
			var to_projected := _project_globe(to_world)
			if not bool(from_projected["visible"]) and not bool(to_projected["visible"]):
				continue
			from_pos = from_projected["position"]
			to_pos = to_projected["position"]
		var color: Color = trail.get("color", Color.WHITE)
		var duration: float = max(0.01, float(trail.get("duration", 1.0)))
		var alpha: float = clamp(float(trail.get("life", duration)) / duration, 0.0, 1.0)
		var is_card_ingress := String(trail.get("style", "movement")) == "card_ingress"
		color.a = 0.14 + alpha * 0.38 if is_card_ingress else 0.25 + alpha * 0.65
		var width: float = 0.9 + alpha * 1.4 if is_card_ingress else 1.5 + alpha * 2.5
		draw_line(from_pos, to_pos, color, width, true)
		if not reduced_detail:
			_draw_arrow_head(from_pos, to_pos, color, alpha, 0.58 if is_card_ingress else 1.0)
		draw_circle(to_pos, (2.5 + alpha * 2.5) if is_card_ingress else (4.0 + alpha * 4.0), color)
		var label := String(trail.get("label", ""))
		if label != "" and not reduced_detail and (not is_card_ingress or not _is_globe_mode()):
			var label_color := color
			label_color.a = min(1.0, color.a + 0.1)
			draw_string(font, to_pos + Vector2(7, -7), label, HORIZONTAL_ALIGNMENT_LEFT, 88.0, 11, label_color)


func _draw_map_event_effects() -> void:
	if map_event_effects.is_empty():
		return
	for effect_variant in map_event_effects:
		var effect: Dictionary = effect_variant
		var kind := String(effect.get("kind", "impact"))
		var duration: float = max(0.01, float(effect.get("duration", 1.0)))
		var alpha: float = clamp(float(effect.get("life", duration)) / duration, 0.0, 1.0)
		if alpha <= 0.0:
			continue
		var progress := 1.0 - alpha
		if ["laser", "beam", "melee"].has(kind):
			_draw_map_event_attack(effect, alpha, progress, kind)
		else:
			_draw_map_event_local(effect, alpha, progress, kind)


func _draw_map_event_attack(effect: Dictionary, alpha: float, progress: float, kind: String) -> void:
	var fallback_position: Vector2 = effect.get("position", Vector2.ZERO)
	var from_world: Vector2 = effect.get("from", fallback_position)
	var to_world: Vector2 = effect.get("to", fallback_position)
	var from_projected := _map_event_screen_position(from_world)
	var to_projected := _map_event_screen_position(to_world)
	if not bool(from_projected["visible"]) and not bool(to_projected["visible"]):
		return
	var from_pos: Vector2 = from_projected["position"]
	var to_pos: Vector2 = to_projected["position"]
	var color: Color = effect.get("color", Color("#fbbf24"))
	if kind == "melee":
		var sweep_color := color.lightened(0.10)
		sweep_color.a = 0.28 + alpha * 0.46
		var angle := (to_pos - from_pos).angle()
		var sweep_radius: float = clamp(20.0 + progress * 18.0, 18.0, 42.0)
		draw_arc(to_pos, sweep_radius, angle - 1.05, angle + 1.05, 28, sweep_color, 4.0 + alpha * 2.0, true)
		var trace_color := color
		trace_color.a = 0.16 + alpha * 0.26
		draw_line(from_pos, to_pos, trace_color, 1.2 + alpha * 1.6, true)
		_draw_map_event_burst(to_pos, color, alpha, progress, 0.82)
		_draw_map_event_label(to_pos, String(effect.get("label", "")), color, alpha)
		return
	var glow := color
	glow.a = 0.14 + alpha * 0.28
	var core := color.lightened(0.28)
	core.a = 0.50 + alpha * 0.42
	var hot := Color("#f8fafc")
	hot.a = 0.40 + alpha * 0.42
	var width: float = 3.0 + alpha * 4.5
	draw_line(from_pos, to_pos, glow, width + 9.0, true)
	draw_line(from_pos, to_pos, core, width, true)
	draw_line(from_pos, to_pos, hot, max(1.2, width * 0.34), true)
	_draw_arrow_head(from_pos, to_pos, core, alpha, 0.9)
	var spark_pos := from_pos.lerp(to_pos, clamp(0.12 + progress * 0.86, 0.0, 1.0))
	var spark_color := hot
	spark_color.a = 0.52 + alpha * 0.34
	draw_circle(spark_pos, 4.0 + alpha * 5.0, spark_color)
	_draw_map_event_burst(to_pos, color, alpha, progress, 1.0)
	_draw_map_event_label(to_pos, String(effect.get("label", "")), color, alpha)


func _draw_map_event_local(effect: Dictionary, alpha: float, progress: float, kind: String) -> void:
	var world_position: Vector2 = effect.get("position", Vector2.ZERO)
	var projected := _map_event_screen_position(world_position)
	if not bool(projected["visible"]):
		return
	var pos: Vector2 = projected["position"]
	var color: Color = effect.get("color", Color("#fbbf24"))
	var card_style := String(effect.get("card_style", "generic"))
	var radius_m: float = max(38.0, float(effect.get("radius_m", 70.0)))
	var map_scale: float = _scale * (0.34 if _is_globe_mode() else 0.64)
	var base_radius: float = clamp(radius_m * map_scale, 10.0, 54.0)
	match kind:
		"card_open":
			var ring := color.lightened(0.18)
			ring.a = 0.18 + alpha * 0.42
			draw_arc(pos, base_radius * (0.70 + progress * 0.85), 0.0, TAU, 48, ring, 2.0 + alpha * 1.4, true)
			var card_color := color.lightened(0.28)
			card_color.a = 0.34 + alpha * 0.48
			var card_w := 18.0 + progress * 3.0
			var card_h := 25.0 + progress * 4.0
			var tilt := sin(progress * PI) * 5.0
			var card_points := PackedVector2Array([
				pos + Vector2(-card_w * 0.5 + tilt, -card_h * 0.5),
				pos + Vector2(card_w * 0.5 + tilt, -card_h * 0.5 + 3.0),
				pos + Vector2(card_w * 0.5 - tilt, card_h * 0.5),
				pos + Vector2(-card_w * 0.5 - tilt, card_h * 0.5 - 3.0),
			])
			draw_colored_polygon(card_points, card_color)
			var edge := Color("#f8fafc")
			edge.a = 0.24 + alpha * 0.42
			draw_polyline(card_points, edge, 1.4 + alpha, true)
			_draw_card_style_glyph(pos, base_radius, color, alpha, progress, card_style)
		"card_resolve":
			var beam := color.lightened(0.35)
			beam.a = 0.22 + alpha * 0.52
			draw_line(pos + Vector2(0.0, -base_radius * 1.35), pos + Vector2(0.0, base_radius * 1.35), beam, 2.4 + alpha * 2.2, true)
			draw_line(pos + Vector2(-base_radius * 1.05, 0.0), pos + Vector2(base_radius * 1.05, 0.0), beam, 1.3 + alpha * 1.4, true)
			draw_arc(pos, base_radius * (0.55 + progress * 0.70), 0.0, TAU, 42, beam, 2.1 + alpha * 1.4, true)
			_draw_map_event_burst(pos, color, alpha, progress, 0.78)
			_draw_card_style_glyph(pos, base_radius, color, alpha, progress, card_style)
		"card_afterglow":
			var after := color.lightened(0.12)
			after.a = 0.14 + alpha * 0.32
			for i in range(3):
				var radius := base_radius * (0.48 + float(i) * 0.30 + progress * 0.24)
				draw_arc(pos, radius, progress * TAU * (0.12 + float(i) * 0.03), TAU + progress * TAU * (0.12 + float(i) * 0.03), 34, after, 1.3 + alpha * 0.8, true)
			for i in range(6):
				var angle := float(i) / 6.0 * TAU + progress * 0.9
				var spark := pos + Vector2(cos(angle), sin(angle)) * base_radius * (0.35 + 0.45 * progress)
				draw_circle(spark, 1.8 + alpha * 2.4, after)
			_draw_card_style_glyph(pos, base_radius, color, alpha, progress, card_style)
		"city_rise":
			var ring := color.lightened(0.20)
			ring.a = 0.18 + alpha * 0.44
			draw_arc(pos, base_radius * (0.75 + progress * 0.70), 0.0, TAU, 48, ring, 2.2 + alpha * 1.4, true)
			var foundation := Color("#67e8f9")
			foundation.a = 0.20 + alpha * 0.48
			for i in range(5):
				var x := -20.0 + float(i) * 10.0
				var height: float = lerp(6.0, 34.0 + float(i % 2) * 9.0, progress)
				draw_line(pos + Vector2(x, 12.0), pos + Vector2(x, 12.0 - height), foundation, 2.4, true)
			var shine := Color("#fef3c7")
			shine.a = 0.22 + alpha * 0.46
			draw_line(pos + Vector2(-24.0, 14.0), pos + Vector2(24.0, 14.0), shine, 2.0, true)
		"city_destroyed", "collapse":
			var dust := Color("#a1a1aa")
			dust.a = 0.16 + alpha * 0.34
			draw_arc(pos, base_radius * (0.9 + progress * 0.95), 0.0, TAU, 46, color, 3.0 + alpha * 2.0, true)
			for i in range(6):
				var angle := float(i) / 6.0 * TAU + progress * 0.8
				var rubble_pos := pos + Vector2(cos(angle), sin(angle)) * base_radius * (0.28 + progress * 0.62)
				draw_circle(rubble_pos, 3.0 + alpha * 3.0, dust)
			var crack := color.darkened(0.20)
			crack.a = 0.30 + alpha * 0.44
			draw_line(pos + Vector2(-18.0, 7.0), pos + Vector2(-4.0, -7.0), crack, 3.0, true)
			draw_line(pos + Vector2(1.0, 8.0), pos + Vector2(20.0, -4.0), crack, 3.0, true)
		"stomp":
			var shock := color
			shock.a = 0.18 + alpha * 0.50
			draw_arc(pos, base_radius * (0.62 + progress * 1.35), 0.0, TAU, 54, shock, 3.0 + alpha * 1.8, true)
			for i in range(7):
				var angle := float(i) / 7.0 * TAU + 0.25
				var start := pos + Vector2(cos(angle), sin(angle)) * base_radius * 0.28
				var end := pos + Vector2(cos(angle + sin(float(i)) * 0.25), sin(angle + sin(float(i)) * 0.25)) * base_radius * (0.72 + progress * 0.46)
				draw_line(start, end, shock, 1.8 + alpha * 1.2, true)
		"wager":
			var field := color.lightened(0.16)
			field.a = 0.10 + alpha * 0.26
			for i in range(4):
				var radius := base_radius * (0.55 + float(i) * 0.32 + progress * 0.80)
				draw_arc(pos, radius, 0.0, TAU, 72, field, 2.2 + alpha * 1.8, true)
			var cross := Color("#fef3c7")
			cross.a = 0.18 + alpha * 0.38
			draw_line(pos + Vector2(-base_radius * 1.25, 0.0), pos + Vector2(base_radius * 1.25, 0.0), cross, 2.0 + alpha, true)
			draw_line(pos + Vector2(0.0, -base_radius * 1.25), pos + Vector2(0.0, base_radius * 1.25), cross, 2.0 + alpha, true)
			for i in range(10):
				var angle := float(i) / 10.0 * TAU + progress * 1.4
				var chip_pos := pos + Vector2(cos(angle), sin(angle)) * base_radius * (0.38 + 0.72 * progress)
				draw_circle(chip_pos, 2.6 + alpha * 3.2, cross)
			_draw_map_event_burst(pos, color, alpha, progress, 1.35)
		_:
			_draw_map_event_burst(pos, color, alpha, progress, 0.86)
	_draw_map_event_label(pos, String(effect.get("label", "")), color, alpha)


func _draw_map_event_burst(pos: Vector2, color: Color, alpha: float, progress: float, strength: float) -> void:
	var burst := color.lightened(0.18)
	burst.a = (0.18 + alpha * 0.52) * strength
	var radius: float = (12.0 + progress * 24.0) * strength
	draw_arc(pos, radius, 0.0, TAU, 32, burst, 2.0 + alpha * 2.0, true)
	for i in range(8):
		var angle := float(i) / 8.0 * TAU + progress * 0.6
		var inner := pos + Vector2(cos(angle), sin(angle)) * radius * 0.32
		var outer := pos + Vector2(cos(angle), sin(angle)) * radius
		draw_line(inner, outer, burst, 1.4 + alpha * 1.5, true)


func _draw_card_style_glyph(pos: Vector2, base_radius: float, color: Color, alpha: float, progress: float, style: String) -> void:
	var glyph := color.lightened(0.34)
	glyph.a = 0.18 + alpha * 0.50
	match style:
		"city":
			for i in range(5):
				var x := -base_radius * 0.42 + float(i) * base_radius * 0.21
				var h: float = base_radius * (0.18 + float((i * 2) % 3) * 0.08 + progress * 0.28)
				draw_line(pos + Vector2(x, base_radius * 0.28), pos + Vector2(x, base_radius * 0.28 - h), glyph, 2.0 + alpha, true)
			draw_line(pos + Vector2(-base_radius * 0.50, base_radius * 0.30), pos + Vector2(base_radius * 0.50, base_radius * 0.30), glyph, 1.5 + alpha, true)
		"product":
			var last := pos + Vector2(-base_radius * 0.52, base_radius * 0.18)
			for i in range(1, 6):
				var t := float(i) / 5.0
				var next := pos + Vector2(lerp(-base_radius * 0.52, base_radius * 0.52, t), sin(t * PI * 1.4 + progress * 1.5) * base_radius * -0.28)
				draw_line(last, next, glyph, 1.7 + alpha, true)
				draw_circle(next, 1.8 + alpha * 1.8, glyph)
				last = next
		"summon":
			for i in range(6):
				var angle := float(i) / 6.0 * TAU + progress * 0.75
				var inner := pos + Vector2(cos(angle), sin(angle)) * base_radius * 0.28
				var outer := pos + Vector2(cos(angle), sin(angle)) * base_radius * 0.62
				draw_line(inner, outer, glyph, 2.1 + alpha, true)
			draw_arc(pos, base_radius * (0.42 + progress * 0.18), 0.0, TAU, 36, glyph, 1.8 + alpha, true)
		"monster_command":
			draw_arc(pos, base_radius * 0.52, 0.0, TAU, 40, glyph, 1.8 + alpha, true)
			draw_line(pos + Vector2(-base_radius * 0.72, 0.0), pos + Vector2(-base_radius * 0.28, 0.0), glyph, 1.6 + alpha, true)
			draw_line(pos + Vector2(base_radius * 0.28, 0.0), pos + Vector2(base_radius * 0.72, 0.0), glyph, 1.6 + alpha, true)
			draw_line(pos + Vector2(0.0, -base_radius * 0.72), pos + Vector2(0.0, -base_radius * 0.28), glyph, 1.6 + alpha, true)
			draw_line(pos + Vector2(0.0, base_radius * 0.28), pos + Vector2(0.0, base_radius * 0.72), glyph, 1.6 + alpha, true)
		"region":
			for i in range(3):
				var offset := (float(i) - 1.0) * base_radius * 0.25
				draw_line(pos + Vector2(offset, -base_radius * 0.48), pos + Vector2(offset, base_radius * 0.48), glyph, 1.1 + alpha * 0.8, true)
				draw_line(pos + Vector2(-base_radius * 0.48, offset), pos + Vector2(base_radius * 0.48, offset), glyph, 1.1 + alpha * 0.8, true)
		"heat":
			for i in range(3):
				draw_arc(pos, base_radius * (0.30 + float(i) * 0.18 + progress * 0.10), -0.55, 0.55, 24, glyph, 1.5 + alpha, true)
				draw_arc(pos, base_radius * (0.30 + float(i) * 0.18 + progress * 0.10), PI - 0.55, PI + 0.55, 24, glyph, 1.5 + alpha, true)
		"supply":
			for i in range(3):
				var y := -base_radius * 0.30 + float(i) * base_radius * 0.30
				draw_line(pos + Vector2(-base_radius * 0.45, y), pos + Vector2(base_radius * 0.20, y), glyph, 1.8 + alpha, true)
				_draw_arrow_head(pos + Vector2(base_radius * 0.08, y), pos + Vector2(base_radius * 0.42, y), glyph, alpha, 0.46)
		"cash":
			draw_arc(pos, base_radius * 0.42, 0.0, TAU, 32, glyph, 2.0 + alpha, true)
			draw_line(pos + Vector2(0.0, -base_radius * 0.42), pos + Vector2(0.0, base_radius * 0.42), glyph, 1.8 + alpha, true)
			draw_line(pos + Vector2(-base_radius * 0.20, -base_radius * 0.14), pos + Vector2(base_radius * 0.20, -base_radius * 0.14), glyph, 1.4 + alpha, true)
			draw_line(pos + Vector2(-base_radius * 0.20, base_radius * 0.14), pos + Vector2(base_radius * 0.20, base_radius * 0.14), glyph, 1.4 + alpha, true)


func _draw_map_event_label(pos: Vector2, label: String, color: Color, alpha: float) -> void:
	if label == "":
		return
	var font := get_theme_default_font()
	var label_color := color.lightened(0.20)
	label_color.a = 0.30 + alpha * 0.55
	draw_string(font, pos + Vector2(9.0, -20.0), _short_action_text(label, 10), HORIZONTAL_ALIGNMENT_LEFT, 88.0, 11, label_color)


func _map_event_screen_position(world_position: Vector2) -> Dictionary:
	if _is_globe_mode():
		return _project_globe(world_position)
	var blend := _globe_blend()
	if blend > 0.001:
		var local_position := _map_offset + _surface_delta(_view_center_m, world_position) * _scale
		var projected := _project_globe(world_position)
		return {
			"position": local_position.lerp(projected["position"] as Vector2, blend),
			"visible": true if blend < 0.96 else bool(projected["visible"]),
			"z": projected["z"],
		}
	return {
		"position": _world_to_screen(world_position),
		"visible": true,
		"z": 1.0,
	}


func _draw_arrow_head(from_screen: Vector2, to_screen: Vector2, color: Color, alpha: float, size_scale: float = 1.0) -> void:
	var offset := to_screen - from_screen
	if offset.length() <= 1.0:
		return
	var forward := offset.normalized()
	var side := Vector2(-forward.y, forward.x)
	var size: float = (7.0 + alpha * 5.0) * size_scale
	var points := PackedVector2Array([
		to_screen,
		to_screen - forward * size + side * size * 0.45,
		to_screen - forward * size - side * size * 0.45,
	])
	draw_colored_polygon(points, color)


func _draw_action_callouts() -> void:
	if action_callouts.is_empty():
		return
	var font := get_theme_default_font()
	var panel_width: float = min(390.0, size.x * 0.52)
	var row_height := 52.0
	var panel_x: float = max(12.0, size.x - panel_width - 14.0)
	var first_index: int = max(0, action_callouts.size() - 4)
	var row := 0
	for i in range(action_callouts.size() - 1, first_index - 1, -1):
		var callout: Dictionary = action_callouts[i]
		var duration: float = max(0.01, float(callout.get("duration", 1.0)))
		var alpha: float = clamp(float(callout.get("life", duration)) / duration, 0.0, 1.0)
		var row_y: float = 38.0 + float(row) * (row_height + 6.0)
		var background := Color(0.02, 0.04, 0.10, 0.82 * alpha)
		var accent: Color = callout.get("color", Color.WHITE)
		accent.a = 0.95 * alpha
		var secondary := Color("#e2e8f0")
		secondary.a = 0.88 * alpha
		draw_rect(Rect2(panel_x, row_y, panel_width, row_height), background, true)
		draw_rect(Rect2(panel_x, row_y, 4.0, row_height), accent, true)
		var title := "%s｜%s" % [String(callout.get("actor", "行动")), String(callout.get("action", ""))]
		draw_string(font, Vector2(panel_x + 12.0, row_y + 19.0), _short_action_text(title, 34), HORIZONTAL_ALIGNMENT_LEFT, panel_width - 20.0, 14, accent)
		var detail := _short_action_text(String(callout.get("detail", "")), 52)
		draw_string(font, Vector2(panel_x + 12.0, row_y + 39.0), detail, HORIZONTAL_ALIGNMENT_LEFT, panel_width - 20.0, 11, secondary)
		row += 1
	_draw_latest_action_bubble(font)


func _draw_latest_action_bubble(font: Font) -> void:
	var latest: Dictionary = action_callouts.back()
	var duration: float = max(0.01, float(latest.get("duration", 1.0)))
	var alpha: float = clamp(float(latest.get("life", duration)) / duration, 0.0, 1.0)
	var world_position: Vector2 = latest.get("world_position", Vector2.ZERO)
	if _is_globe_mode():
		var projected := _project_globe(world_position)
		if not bool(projected["visible"]):
			return
	var anchor := _world_to_screen(world_position)
	var bubble_width := 196.0
	var bubble_height := 30.0
	var bubble_x: float = clamp(anchor.x - bubble_width * 0.5, 8.0, max(8.0, size.x - bubble_width - 8.0))
	var bubble_y: float = clamp(anchor.y - 48.0, 28.0, max(28.0, size.y - bubble_height - 8.0))
	var background := Color(0.02, 0.04, 0.10, 0.88 * alpha)
	var color: Color = latest.get("color", Color.WHITE)
	color.a = alpha
	draw_rect(Rect2(bubble_x, bubble_y, bubble_width, bubble_height), background, true)
	var label := _short_action_text(String(latest.get("action", "行动")), 22)
	draw_string(font, Vector2(bubble_x + 8.0, bubble_y + 20.0), label, HORIZONTAL_ALIGNMENT_CENTER, bubble_width - 16.0, 13, color)


func _short_action_text(text: String, max_characters: int) -> String:
	if text.length() <= max_characters:
		return text
	return text.left(max(1, max_characters - 1)) + "…"


func _draw_scale_hint() -> void:
	var font := get_theme_default_font()
	var text := ""
	var anchor := Vector2(12, 22)
	if _is_globe_mode():
		text = "星球全景｜滚轮贴近｜拖拽旋转｜圆点=在场单位"
	elif _globe_blend() > 0.001:
		text = "拉远中｜地表牌板正在卷成星球"
	else:
		text = "局部地表｜滚轮拉远看星球｜拖拽平移｜双击区域看牌"
	draw_string(font, anchor, text, HORIZONTAL_ALIGNMENT_LEFT, min(760.0, size.x - 24.0), 12, Color("#cbd5e1"))


func _screen_polygon(world_points: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point_variant in world_points:
		result.append(_world_to_screen(point_variant as Vector2))
	return result


func _can_fill_polygon(points: PackedVector2Array) -> bool:
	if points.size() < 3:
		return false
	return not Geometry2D.triangulate_polygon(points).is_empty()


func _world_to_screen(position_m: Vector2) -> Vector2:
	if _is_globe_mode():
		var projected := _project_globe(position_m)
		return projected["position"]
	var local_position := _map_offset + _surface_delta(_view_center_m, position_m) * _scale
	var blend := _globe_blend()
	if blend <= 0.001:
		return local_position
	var projected := _project_globe(position_m)
	return local_position.lerp(projected["position"] as Vector2, blend)


func _projection_visibility_alpha_for_district(index: int) -> float:
	if index < 0 or index >= districts.size():
		return 1.0
	var blend := _globe_blend()
	if blend < PLANET_PROJECTION_VISIBILITY_FADE_START:
		return 1.0
	var projected := _project_globe(districts[index].get("center", Vector2.ZERO))
	return _projection_visibility_alpha(float(projected.get("z", 1.0)), blend)


func _screen_to_world(position: Vector2) -> Vector2:
	if _globe_blend() > 0.62:
		return _screen_to_globe_world(position)
	return _wrap_world_position(_view_center_m + (position - _map_offset) / max(0.001, _scale))


func _district_at_point(point: Vector2) -> int:
	var best_index := -1
	var best_distance := INF
	for i in range(districts.size()):
		var district: Dictionary = districts[i]
		var distance := _surface_distance(point, district.get("center", Vector2.ZERO))
		if distance < best_distance:
			best_distance = distance
			best_index = i
	if best_index >= 0 and best_distance <= 2.0:
		return best_index
	for i in range(districts.size()):
		var district: Dictionary = districts[i]
		if _point_in_polygon(point, district.get("polygon", [])):
			return i
	return best_index


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
	if index >= 0 and index < districts.size():
		var district: Dictionary = districts[index]
		if String(district.get("terrain", "land")) == "ocean":
			return Color("#075985") if not bool(district.get("destroyed", false)) else Color("#334155")
		var product_count: int = (district.get("products", []) as Array).size()
		if product_count > 0:
			return Color("#166534").lerp(Color("#854d0e"), clamp(float(product_count - 3) / 3.0, 0.0, 1.0) * 0.36)
	if palette.is_empty():
		return Color("#1e293b")
	return palette[index % palette.size()] as Color


func _build_visual_payload_signature(
	new_districts: Array,
	selected: int,
	trails: Array,
	callouts: Array,
	event_effects: Array,
	monster_markers: Array,
	new_city_markers: Array,
	new_trade_route_markers: Array,
	new_trade_product: String,
	new_visual_layer_focus: String = "all"
) -> String:
	var parts := [
		"sel:%d" % selected,
		"product:%s" % new_trade_product,
		"layer:%s" % new_visual_layer_focus,
		"trail:%s" % _marker_array_signature(trails, ["from", "to", "color", "label", "style", "duration", "remaining"]),
		"call:%s" % _marker_array_signature(callouts, ["position", "actor", "action", "detail", "color", "duration", "remaining"]),
		"effect:%s" % _marker_array_signature(event_effects, ["position", "kind", "label", "color", "duration", "remaining", "radius"]),
		"monster:%s" % _marker_array_signature(monster_markers, ["position", "label", "name", "glyph", "motif", "down"]),
		"city:%s" % _marker_array_signature(new_city_markers, ["district", "position", "level", "active", "tag", "products", "competition", "rise"]),
		"route:%s" % _marker_array_signature(new_trade_route_markers, ["product", "from", "to", "points", "disrupted", "flow_multiplier"]),
	]
	for i in range(new_districts.size()):
		var district: Dictionary = new_districts[i]
		var city: Dictionary = district.get("city", {}) as Dictionary
		var city_active := 0
		var city_level := 0
		var city_products := 0
		var city_demands := 0
		if not city.is_empty():
			city_active = 1 if bool(city.get("active", true)) else 0
			city_level = int(city.get("level", 1))
			city_products = (city.get("products", []) as Array).size()
			city_demands = (city.get("demands", []) as Array).size()
		parts.append("d%d:%s:%d:%d:%d:%d:%d:%d:%d:%d" % [
			i,
			String(district.get("terrain", "")),
			int(district.get("damage", 0)),
			int(district.get("hp", 0)),
			1 if bool(district.get("destroyed", false)) else 0,
			int(district.get("panic", 0)),
			(district.get("products", []) as Array).size(),
			(district.get("demands", []) as Array).size(),
			city_active,
			city_level + city_products + city_demands,
		])
	return "|".join(parts)


func _marker_array_signature(items: Array, keys: Array) -> String:
	var parts := ["n%d" % items.size()]
	for item_variant in items:
		if not (item_variant is Dictionary):
			parts.append(str(item_variant))
			continue
		var item: Dictionary = item_variant
		var item_parts := []
		for key_variant in keys:
			var key := String(key_variant)
			item_parts.append("%s=%s" % [key, _visual_value_signature(item.get(key, ""))])
		parts.append(",".join(item_parts))
	return ";".join(parts)


func _visual_value_signature(value) -> String:
	if value is Vector2:
		var point: Vector2 = value
		return "%.1f,%.1f" % [point.x, point.y]
	if value is Color:
		var color: Color = value
		return color.to_html(true)
	if value is Array:
		var values: Array = value
		if values.is_empty():
			return "[]"
		return "[%d:%s:%s]" % [
			values.size(),
			_visual_value_signature(values.front()),
			_visual_value_signature(values.back()),
		]
	if value is float:
		return "%.2f" % float(value)
	return str(value)


func _build_map_signature(new_districts: Array, width_m: float, height_m: float) -> String:
	if new_districts.is_empty():
		return "empty:%.1f:%.1f" % [width_m, height_m]
	var first: Dictionary = new_districts.front()
	var last: Dictionary = new_districts.back()
	var first_center: Vector2 = first.get("center", Vector2.ZERO)
	var last_center: Vector2 = last.get("center", Vector2.ZERO)
	return "%d:%.1f:%.1f:%.1f:%.1f:%.1f:%.1f" % [
		new_districts.size(),
		width_m,
		height_m,
		first_center.x,
		first_center.y,
		last_center.x,
		last_center.y,
	]
