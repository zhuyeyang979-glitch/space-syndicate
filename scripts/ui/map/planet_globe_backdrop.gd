@tool
extends Control
class_name SpaceSyndicatePlanetGlobeBackdrop

const SURFACE_PADDING_PX := 2.0

@onready var _surface_rect: ColorRect = %GlobeSurface

var _payload := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("mcp_sceneized_component", "PlanetGlobeBackdrop")
	if _surface_rect != null:
		_surface_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_surface_rect.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		_surface_rect.position = Vector2.ZERO
		_surface_rect.size = Vector2.ONE * 4.0
		_surface_rect.visible = true


func configure(data: Dictionary) -> void:
	_payload = {
		"viewport_size": data.get("viewport_size", size),
		"globe_center": data.get("globe_center", size * 0.5),
		"globe_radius": data.get("globe_radius", minf(size.x, size.y) * 0.43),
		"globe_blend": data.get("globe_blend", 1.0),
		"camera_lon_rad": data.get("camera_lon_rad", PI),
		"camera_lat_rad": data.get("camera_lat_rad", 0.0),
		"sun_turn_ppm": data.get("sun_turn_ppm", 0),
		"presentation_seed": data.get("presentation_seed", 1),
		"district_count": data.get("district_count", 0),
		"geometry_fingerprint": data.get("geometry_fingerprint", ""),
	}
	name = "PlanetGlobeBackdrop"
	visible = true
	_apply_shader_parameters()
	queue_redraw()


func debug_snapshot() -> Dictionary:
	return {
		"kind": "globe_backdrop",
		"mode": str(_payload.get("mode", "procedural_canvas_shader")),
		"rendering_mode": "procedural_canvas_shader_sphere",
		"district_count": int(_payload.get("district_count", 0)),
		"planet_opaque": true,
		"planet_alpha": 1.0,
		"day_brightness": 1.0,
		"night_brightness": 0.50,
		"outer_orbit_decoration_count": 0,
		"flat_texture_dependency_count": 0,
		"surface_rotates_with_camera": true,
		"solar_terminator": true,
		"geometry_fingerprint": str(_payload.get("geometry_fingerprint", "")),
		"sceneized": true,
	}


func _apply_shader_parameters() -> void:
	if _surface_rect == null or not (_surface_rect.material is ShaderMaterial):
		return
	var shader_material := _surface_rect.material as ShaderMaterial
	var viewport_size := _as_vector2(_payload.get("viewport_size", size))
	var center := _as_vector2(_payload.get("globe_center", viewport_size * 0.5))
	var radius := maxf(24.0, float(_payload.get("globe_radius", minf(viewport_size.x, viewport_size.y) * 0.43)))
	var surface_extent := ceilf(radius + SURFACE_PADDING_PX)
	var surface_size := Vector2.ONE * surface_extent * 2.0
	_surface_rect.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_surface_rect.position = center - surface_size * 0.5
	_surface_rect.size = surface_size

	var camera_lon := float(_payload.get("camera_lon_rad", PI))
	var camera_lat := float(_payload.get("camera_lat_rad", 0.0))
	var sin_lon := sin(camera_lon)
	var cos_lon := cos(camera_lon)
	var sin_lat := sin(camera_lat)
	var cos_lat := cos(camera_lat)
	var camera_east := Vector3(-sin_lon, 0.0, cos_lon)
	var camera_north := Vector3(-sin_lat * cos_lon, cos_lat, -sin_lat * sin_lon)
	var camera_forward := Vector3(cos_lat * cos_lon, sin_lat, cos_lat * sin_lon)
	var sun_lon := float(int(_payload.get("sun_turn_ppm", 0))) / 1_000_000.0 * TAU
	var sun_direction := Vector3(cos(sun_lon), 0.12, sin(sun_lon)).normalized()
	var presentation_seed := int(_payload.get("presentation_seed", 1))
	var presentation_seed_vector := Vector3(
		fposmod(float(presentation_seed) * 0.000001, 1.0),
		fposmod(float(presentation_seed) * 0.0000031 + 0.37, 1.0),
		fposmod(float(presentation_seed) * 0.0000073 + 0.61, 1.0)
	) * 2.0 - Vector3.ONE

	shader_material.set_shader_parameter("surface_size", surface_size)
	shader_material.set_shader_parameter("globe_radius", radius)
	shader_material.set_shader_parameter("camera_east", camera_east)
	shader_material.set_shader_parameter("camera_north", camera_north)
	shader_material.set_shader_parameter("camera_forward", camera_forward)
	shader_material.set_shader_parameter("sun_direction", sun_direction)
	shader_material.set_shader_parameter("presentation_seed_vector", presentation_seed_vector)
	shader_material.set_shader_parameter("globe_blend", clampf(float(_payload.get("globe_blend", 1.0)), 0.0, 1.0))
	_surface_rect.visible = true


func _draw() -> void:
	var viewport_size := _as_vector2(_payload.get("viewport_size", size))
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		viewport_size = size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	var center := _as_vector2(_payload.get("globe_center", viewport_size * 0.5))
	var radius := maxf(24.0, float(_payload.get("globe_radius", minf(viewport_size.x, viewport_size.y) * 0.43)))
	var globe_blend := clampf(float(_payload.get("globe_blend", 1.0)), 0.0, 1.0)
	_draw_stars(viewport_size)
	var shadow := Color("#020617")
	shadow.a = 0.82 * globe_blend
	draw_circle(center + Vector2(0.0, radius * 0.035), radius + 5.0, shadow)
	var atmosphere := Color("#38bdf8")
	atmosphere.a = (0.12 + globe_blend * 0.28) * globe_blend
	draw_arc(center, radius + 1.5, 0.0, TAU, 144, atmosphere, 1.8 + globe_blend * 1.8, true)


func _draw_stars(viewport_size: Vector2) -> void:
	for i in range(72):
		var star_position := Vector2(
			fposmod(float(i * 137 + 31), maxf(1.0, viewport_size.x)),
			fposmod(float(i * 73 + 43), maxf(1.0, viewport_size.y))
		)
		var star := Color("#e0f2fe")
		star.a = 0.16 + float((i * 19) % 7) * 0.042
		draw_circle(star_position, 0.7 + float(i % 3) * 0.24, star)


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
