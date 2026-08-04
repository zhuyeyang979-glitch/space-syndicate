@tool
extends Control
class_name SpaceSyndicatePlanetGlobeBackdrop

const SURFACE_PADDING_PX := 2.0
const TERRAIN_MASK_SIZE := Vector2i(256, 128)
const TERRAIN_BIN_SIZE := Vector2i(64, 32)
const TERRAIN_SEARCH_RING := 4

@onready var _surface_rect: ColorRect = %GlobeSurface

var _payload := {}
var _terrain_texture: ImageTexture
var _terrain_mask_fingerprint := ""
var _terrain_mask_rebuild_count := 0
var _terrain_mask_ready := false
var _terrain_sample_count := 0


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
		"sun_direction": data.get("sun_direction", Vector3.ZERO),
		"presentation_seed": data.get("presentation_seed", 1),
		"district_count": data.get("district_count", 0),
		"geometry_fingerprint": data.get("geometry_fingerprint", ""),
		"terrain_surface_samples": data.get("terrain_surface_samples", []),
		"geography_complexity": data.get("geography_complexity", "STANDARD"),
		"land_ocean_profile": data.get("land_ocean_profile", "BALANCED"),
		"authoritative_surface_connected": data.get("authoritative_surface_connected", false),
	}
	name = "PlanetGlobeBackdrop"
	visible = true
	_update_authoritative_terrain_mask()
	_apply_shader_parameters()
	queue_redraw()


func debug_snapshot() -> Dictionary:
	return {
		"kind": "globe_backdrop",
		"mode": "v074_authoritative_terrain_canvas_shader" if _terrain_mask_ready else "v073_procedural_compatibility",
		"rendering_mode": "procedural_canvas_shader_sphere",
		"district_count": int(_payload.get("district_count", 0)),
		"planet_opaque": true,
		"planet_alpha": 1.0,
		"day_brightness": 1.0,
		"night_brightness": 0.42,
		"outer_orbit_decoration_count": 0,
		"flat_texture_dependency_count": 0,
		"static_texture_only_mode": false,
		"terrain_relief": true,
		"ocean_depth_shading": true,
		"coastline_visual_alignment": _terrain_mask_ready,
		"surface_rotates_with_camera": true,
		"solar_terminator": true,
		"geometry_fingerprint": str(_payload.get("geometry_fingerprint", "")),
		"authoritative_terrain_mask_ready": _terrain_mask_ready,
		"terrain_mask_rebuild_count": _terrain_mask_rebuild_count,
		"terrain_sample_count": _terrain_sample_count,
		"sceneized": true,
	}


func _update_authoritative_terrain_mask() -> void:
	var authoritative := bool(_payload.get("authoritative_surface_connected", false))
	var fingerprint := str(_payload.get("geometry_fingerprint", ""))
	var samples_variant: Variant = _payload.get("terrain_surface_samples", [])
	if not authoritative or fingerprint.is_empty() or not (samples_variant is Array):
		_terrain_mask_ready = false
		_terrain_sample_count = 0
		return
	var samples := samples_variant as Array
	if fingerprint == _terrain_mask_fingerprint and _terrain_texture != null:
		_terrain_mask_ready = true
		return
	var normalized_samples := _normalized_terrain_samples(samples)
	if normalized_samples.is_empty():
		_terrain_mask_ready = false
		_terrain_sample_count = 0
		return
	var image := _rasterize_terrain_mask(normalized_samples)
	if image == null or image.is_empty():
		_terrain_mask_ready = false
		return
	_terrain_texture = ImageTexture.create_from_image(image)
	_terrain_mask_fingerprint = fingerprint
	_terrain_mask_rebuild_count += 1
	_terrain_sample_count = normalized_samples.size()
	_terrain_mask_ready = true


func _normalized_terrain_samples(samples: Array) -> Array:
	var result: Array = []
	for sample_variant in samples:
		if not (sample_variant is Dictionary):
			continue
		var sample := sample_variant as Dictionary
		var terrain := str(sample.get("terrain_class", ""))
		if terrain != "land" and terrain != "ocean":
			continue
		var unit := _as_vector3(sample.get("unit_sphere", Vector3.ZERO)).normalized()
		if unit.length_squared() < 0.9:
			continue
		var uv := _unit_to_uv(unit)
		result.append({
			"unit": unit,
			"terrain": 1.0 if terrain == "land" else 0.0,
			"bin_x": clampi(int(floor(uv.x * float(TERRAIN_BIN_SIZE.x))), 0, TERRAIN_BIN_SIZE.x - 1),
			"bin_y": clampi(int(floor(uv.y * float(TERRAIN_BIN_SIZE.y))), 0, TERRAIN_BIN_SIZE.y - 1),
		})
	return result


func _rasterize_terrain_mask(samples: Array) -> Image:
	var bins := _build_sample_bins(samples)
	var image := Image.create(TERRAIN_MASK_SIZE.x, TERRAIN_MASK_SIZE.y, false, Image.FORMAT_RGBA8)
	for y in range(TERRAIN_MASK_SIZE.y):
		var v := (float(y) + 0.5) / float(TERRAIN_MASK_SIZE.y)
		var lat := PI * 0.5 - v * PI
		var cos_lat := cos(lat)
		for x in range(TERRAIN_MASK_SIZE.x):
			var u := (float(x) + 0.5) / float(TERRAIN_MASK_SIZE.x)
			var lon := u * TAU
			var unit := Vector3(cos_lat * cos(lon), sin(lat), cos_lat * sin(lon))
			var terrain_value := _nearest_sample_terrain(unit, x, y, bins, samples)
			image.set_pixel(x, y, Color(terrain_value, terrain_value, terrain_value, 1.0))
	return image


func _build_sample_bins(samples: Array) -> Dictionary:
	var bins := {}
	for sample_variant in samples:
		var sample := sample_variant as Dictionary
		var key := int(sample.get("bin_y", 0)) * TERRAIN_BIN_SIZE.x + int(sample.get("bin_x", 0))
		if not bins.has(key):
			bins[key] = []
		(bins[key] as Array).append(sample)
	return bins


func _nearest_sample_terrain(unit: Vector3, pixel_x: int, pixel_y: int, bins: Dictionary, all_samples: Array) -> float:
	var bin_x := clampi(int(floor(float(pixel_x) / float(TERRAIN_MASK_SIZE.x) * float(TERRAIN_BIN_SIZE.x))), 0, TERRAIN_BIN_SIZE.x - 1)
	var bin_y := clampi(int(floor(float(pixel_y) / float(TERRAIN_MASK_SIZE.y) * float(TERRAIN_BIN_SIZE.y))), 0, TERRAIN_BIN_SIZE.y - 1)
	var candidates: Array = []
	for ring in range(TERRAIN_SEARCH_RING + 1):
		for offset_y in range(-ring, ring + 1):
			for offset_x in range(-ring, ring + 1):
				if ring > 0 and abs(offset_x) != ring and abs(offset_y) != ring:
					continue
				var candidate_y := bin_y + offset_y
				if candidate_y < 0 or candidate_y >= TERRAIN_BIN_SIZE.y:
					continue
				var candidate_x := posmod(bin_x + offset_x, TERRAIN_BIN_SIZE.x)
				var key := candidate_y * TERRAIN_BIN_SIZE.x + candidate_x
				if bins.has(key):
					candidates.append_array(bins[key] as Array)
		if not candidates.is_empty() and ring >= 1:
			break
	if candidates.is_empty():
		candidates = all_samples
	var best_dot := -INF
	var terrain := 0.0
	for sample_variant in candidates:
		var sample := sample_variant as Dictionary
		var alignment := unit.dot(sample.get("unit", Vector3.ZERO) as Vector3)
		if alignment > best_dot:
			best_dot = alignment
			terrain = float(sample.get("terrain", 0.0))
	return terrain


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
	var sun_direction := _as_vector3(_payload.get("sun_direction", Vector3.ZERO)).normalized()
	if sun_direction.length_squared() < 0.9:
		var sun_lon := float(int(_payload.get("sun_turn_ppm", 0))) / 1_000_000.0 * TAU
		sun_direction = Vector3(cos(sun_lon), 0.12, sin(sun_lon)).normalized()
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
	shader_material.set_shader_parameter("terrain_mask_ready", _terrain_mask_ready)
	shader_material.set_shader_parameter("terrain_texel_size", Vector2.ONE / Vector2(TERRAIN_MASK_SIZE))
	shader_material.set_shader_parameter("geography_complexity", _complexity_value(str(_payload.get("geography_complexity", "STANDARD"))))
	if _terrain_texture != null:
		shader_material.set_shader_parameter("terrain_mask", _terrain_texture)
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


func _unit_to_uv(unit: Vector3) -> Vector2:
	var safe := unit.normalized()
	return Vector2(
		fposmod(atan2(safe.z, safe.x), TAU) / TAU,
		(PI * 0.5 - asin(clampf(safe.y, -1.0, 1.0))) / PI
	)


func _complexity_value(value: String) -> float:
	match value.to_upper():
		"SIMPLE":
			return 0.0
		"COMPLEX":
			return 2.0
	return 1.0


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


func _as_vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value as Vector3
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if value is Dictionary:
		return Vector3(float(value.get("x", 0.0)), float(value.get("y", 0.0)), float(value.get("z", 0.0)))
	return Vector3.ZERO
