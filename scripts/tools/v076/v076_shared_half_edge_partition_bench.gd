extends Node3D

const Audit := preload("res://scripts/v076/map/v076_partition_audit.gd")
const DomainRng := preload("res://scripts/v076/simulation/v076_domain_rng.gd")
const StateCodec := preload("res://scripts/v076/simulation/v076_authority_state_codec.gd")
const AuthorityCodec := preload("res://scripts/v076/map/v076_partition_authority_codec_v1.gd")
const Partitioner := preload("res://scripts/v076/map/v076_shared_half_edge_partition_v1.gd")
const Validator := preload("res://scripts/v076/map/v076_partition_validator_v1.gd")
const Microgrid := preload("res://scripts/v076/map/v076_spherical_microgrid_index_v1.gd")
const PresentationGrid := preload("res://scripts/v074/map/v074_geodesic_microgrid.gd")

const SEED_TARGET := 2000
const DEBUG_ROOT_SEED := 760_076
const DEBUG_REGION_COUNT := 16
const DEBUG_SHAPE_COMPLEXITY := "COMPLEX"
const EXPECTED_PRESENTATION_MAPPING_SHA256 := "01bdd9e9a5cbda0fd036c649b223ef8fa5bcdfd5c9dc51bad83b91199ef14959"
const ROTATE_RADIANS_PER_PIXEL := 0.008
const CAMERA_MIN_DISTANCE := 2.2
const CAMERA_MAX_DISTANCE := 5.0
const CAMERA_ZOOM_STEP := 0.28
const SCREENSHOT_PATH := "user://v076_stage2_debug_sphere_checkpoint004.png"

@onready var _planet_root: Node3D = %PlanetRoot
@onready var _region_surface: MeshInstance3D = %RegionSurface
@onready var _shared_boundary_render: MeshInstance3D = %SharedBoundaryRender
@onready var _selection_highlight: MeshInstance3D = %SelectionHighlight
@onready var _camera: Camera3D = %DebugCamera
@onready var _interaction_status: Label = %InteractionStatus
@onready var _authority_status: Label = %AuthorityStatus

var _partition: Dictionary = {}
var _topology: Dictionary = {}
var _presentation_vertices: Array = []
var _presentation_faces: Array = []
var _face_centers: Array = []
var _dragging := false
var _drag_distance_px := 0.0
var _rotation_event_count := 0
var _zoom_event_count := 0
var _hit_test_count := 0
var _selection_change_count := 0
var _selected_region_index := -1
var _highlight_triangle_count := 0
var _shared_boundary_segment_count := 0
var _presentation_mapping_sha256 := ""
var _land_region_count := 0
var _ocean_region_count := 0
var _terrain_feature_counts: Dictionary = {}


func _ready() -> void:
	var visual_receipt := _build_debug_sphere()
	await get_tree().process_frame
	await get_tree().process_frame
	var interaction_receipt := await _run_interaction_probe()
	await get_tree().process_frame
	await get_tree().process_frame
	var screenshot_receipt := _capture_visual_evidence()
	var ready_status := "PASS" if (
		str(visual_receipt.get("status", "FAIL")) == "PASS"
		and str(interaction_receipt.get("status", "FAIL")) == "PASS"
		and str(screenshot_receipt.get("status", "FAIL")) == "PASS"
	) else "FAIL"
	print("V076_STAGE2_DEBUG_SPHERE_READY|%s" % JSON.stringify({
		"status": ready_status,
		"visual": visual_receipt,
		"interaction": interaction_receipt,
		"screenshot": screenshot_receipt,
	}))
	var started_ms := Time.get_ticks_msec()
	var focused := Audit.run_focused_suite()
	var sampled := Audit.run_seed_suite(SEED_TARGET)
	var elapsed_ms := Time.get_ticks_msec() - started_ms
	var status := "PASS" if (
		ready_status == "PASS"
		and str(focused.get("status", "FAIL")) == "PASS"
		and str(sampled.get("status", "FAIL")) == "PASS"
	) else "FAIL"
	var reason := ""
	if ready_status != "PASS":
		reason = "debug_sphere_interaction_or_visual_failed"
	elif str(focused.get("status", "FAIL")) != "PASS":
		reason = str(focused.get("reason", "focused_failed"))
	elif str(sampled.get("status", "FAIL")) != "PASS":
		reason = str(sampled.get("reason", "sampled_failed"))
	var result := {
		"status": status,
		"reason": reason,
		"scene_path": "res://scenes/tools/v076/V076SharedHalfEdgePartitionBench.tscn",
		"topology_sha256": str(focused.get("topology_sha256", "")),
		"focused_region_count_case_count": int(focused.get("focused_region_count_case_count", 0)),
		"focused_replay_mismatch_count": int(focused.get("focused_replay_mismatch_count", -1)),
		"distinct_seed_count": int(sampled.get("distinct_seed_count", 0)),
		"same_seed_fresh_replay_count": int(sampled.get("same_seed_fresh_replay_count", 0)),
		"generation_failure_count": int(sampled.get("generation_failure_count", -1)),
		"validation_failure_count": int(sampled.get("validation_failure_count", -1)),
		"replay_mismatch_count": int(sampled.get("replay_mismatch_count", -1)),
		"sample_count_by_region_count": sampled.get("sample_count_by_region_count", {}),
		"sample_count_by_shape_complexity": sampled.get("sample_count_by_shape_complexity", {}),
		"sample_count_by_region_count_and_complexity": sampled.get("sample_count_by_region_count_and_complexity", {}),
		"aggregate_land_region_count": int(sampled.get("aggregate_land_region_count", 0)),
		"aggregate_ocean_region_count": int(sampled.get("aggregate_ocean_region_count", 0)),
		"aggregate_terrain_feature_counts": sampled.get("aggregate_terrain_feature_counts", {}),
		"all_terrain_features_observed": bool(sampled.get("all_terrain_features_observed", false)),
		"float_authority_field_count": int(sampled.get("float_authority_field_count", -1)),
		"debug_sphere_visual": visual_receipt,
		"debug_sphere_interaction": interaction_receipt,
		"visual_evidence": screenshot_receipt,
		"elapsed_ms_diagnostic_only": elapsed_ms,
		"production_composition_cutover": false,
	}
	print("V076_SHARED_HALF_EDGE_PARTITION_BENCH|%s" % JSON.stringify(result))
	if status != "PASS":
		push_error("V076 shared half-edge partition Bench failed: %s" % reason)
	await get_tree().create_timer(30.0).timeout
	get_tree().quit(0 if status == "PASS" else 1)


func _build_debug_sphere() -> Dictionary:
	var rng := DomainRng.new()
	var configured := rng.configure(DEBUG_ROOT_SEED, AuthorityCodec.DOMAIN_ID)
	if not bool(configured.get("accepted", false)):
		return {"status": "FAIL", "reason": "debug_rng_configure_failed"}
	var generated := Partitioner.generate(
		DEBUG_ROOT_SEED,
		DEBUG_REGION_COUNT,
		DEBUG_SHAPE_COMPLEXITY,
		rng
	)
	if not bool(generated.get("accepted", false)):
		return {"status": "FAIL", "reason": str(generated.get("reason", "debug_partition_failed"))}
	_partition = generated.get("partition", {}) as Dictionary
	var validated := Validator.validate_partition(_partition)
	if not bool(validated.get("accepted", false)):
		return {"status": "FAIL", "reason": str(validated.get("reason", "debug_partition_invalid"))}
	var topology_result := Microgrid.build()
	var presentation_grid := PresentationGrid.build(Microgrid.TOPOLOGY_LEVEL)
	if not bool(topology_result.get("accepted", false)) or not bool(presentation_grid.get("accepted", false)):
		return {"status": "FAIL", "reason": "debug_topology_projection_failed"}
	_topology = topology_result.get("topology", {}) as Dictionary
	_presentation_vertices = presentation_grid.get("vertices_unit_sphere", []) as Array
	_presentation_faces = presentation_grid.get("microcell_vertex_ids", []) as Array
	_face_centers = presentation_grid.get("microcell_centers_unit_sphere", []) as Array
	var mapping_validation := validate_presentation_mapping(
		_topology,
		_presentation_vertices,
		_presentation_faces
	)
	if not bool(mapping_validation.get("accepted", false)):
		return {"status": "FAIL", "reason": str(mapping_validation.get("reason", "debug_topology_mapping_parity_failed")), "actual_mapping_sha256": str(mapping_validation.get("actual_mapping_sha256", ""))}
	_presentation_mapping_sha256 = str(mapping_validation.get("mapping_sha256", ""))
	_land_region_count = _count_terrain_regions("Land")
	_ocean_region_count = _count_terrain_regions("Ocean")
	_terrain_feature_counts = _feature_counts(_partition.get("terrain_features", {}) as Dictionary)
	_region_surface.mesh = _build_region_surface_mesh()
	_shared_boundary_render.mesh = _build_shared_boundary_mesh()
	_selection_highlight.visible = false
	_authority_status.text = "%s · %d regions · Land %d / Ocean %d · Features C%d B%d P%d S%d A%d · %d edges" % [
		DEBUG_SHAPE_COMPLEXITY,
		DEBUG_REGION_COUNT,
		_land_region_count,
		_ocean_region_count,
		int(_terrain_feature_counts.get("continent_count", 0)),
		int(_terrain_feature_counts.get("bay_count", 0)),
		int(_terrain_feature_counts.get("peninsula_count", 0)),
		int(_terrain_feature_counts.get("strait_count", 0)),
		int(_terrain_feature_counts.get("archipelago_count", 0)),
		_shared_boundary_segment_count,
	]
	_update_interaction_status()
	return {
		"status": "PASS",
		"reason": "",
		"region_mesh_triangle_count": _presentation_faces.size(),
		"shared_boundary_segment_count": _shared_boundary_segment_count,
		"shape_complexity": DEBUG_SHAPE_COMPLEXITY,
		"land_region_count": _land_region_count,
		"ocean_region_count": _ocean_region_count,
		"terrain_feature_counts": _terrain_feature_counts,
		"presentation_mapping_parity": true,
		"presentation_mapping_sha256": _presentation_mapping_sha256,
		"mesh_instance_count": find_children("*", "MeshInstance3D", true, false).size(),
		"camera_count": find_children("*", "Camera3D", true, false).size(),
		"authority_projection_uses_float_geometry": false,
		"presentation_projection_source": "V074GeodesicMicrogrid.presentation_only",
	}


func _build_region_surface_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var owners := _partition.get("owner_by_face", []) as Array
	var terrain_by_face := _partition.get("terrain_by_face", []) as Array
	for face_id in range(_presentation_faces.size()):
		var face := _presentation_faces[face_id] as Array
		var region_owner := int(owners[face_id])
		var terrain := str(terrain_by_face[face_id])
		var variation := fmod(float(region_owner) * 0.137, 0.12)
		var color := (
			Color.from_hsv(0.25 + variation, 0.58, 0.72)
			if terrain == "Land"
			else Color.from_hsv(0.55 + variation, 0.72, 0.78)
		)
		for vertex_variant in face:
			var vertex := _presentation_vertices[int(vertex_variant)] as Vector3
			surface.set_color(color)
			surface.set_normal(vertex)
			surface.add_vertex(vertex)
	var mesh := surface.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.72
	material.metallic = 0.08
	_region_surface.material_override = material
	return mesh


func _build_shared_boundary_mesh() -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.42, 0.94, 1.0, 1.0)
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	_shared_boundary_segment_count = 0
	var half_edges := _topology.get("half_edges", []) as Array
	for boundary_variant in _partition.get("shared_boundary_edges", []) as Array:
		var boundary := boundary_variant as Dictionary
		var half_edge_id := int(boundary.get("half_edge_a_to_b", -1))
		var half_edge := half_edges[half_edge_id] as Dictionary
		var origin := (_presentation_vertices[int(half_edge.get("origin_vertex_id", -1))] as Vector3) * 1.012
		var destination := (_presentation_vertices[int(half_edge.get("destination_vertex_id", -1))] as Vector3) * 1.012
		mesh.surface_add_vertex(origin)
		mesh.surface_add_vertex(destination)
		_shared_boundary_segment_count += 1
	mesh.surface_end()
	return mesh


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera.position.z = clampf(_camera.position.z - CAMERA_ZOOM_STEP, CAMERA_MIN_DISTANCE, CAMERA_MAX_DISTANCE)
			_zoom_event_count += 1
			_update_interaction_status()
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera.position.z = clampf(_camera.position.z + CAMERA_ZOOM_STEP, CAMERA_MIN_DISTANCE, CAMERA_MAX_DISTANCE)
			_zoom_event_count += 1
			_update_interaction_status()
		elif mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				_dragging = true
				_drag_distance_px = 0.0
			else:
				_dragging = false
				if _drag_distance_px < 5.0:
					_select_region_at_screen_position(mouse_button.position)
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		_drag_distance_px += motion.relative.length()
		_planet_root.rotate_y(-motion.relative.x * ROTATE_RADIANS_PER_PIXEL)
		_planet_root.rotate_x(-motion.relative.y * ROTATE_RADIANS_PER_PIXEL)
		_rotation_event_count += 1
		_update_interaction_status()


func _select_region_at_screen_position(screen_position: Vector2) -> void:
	_hit_test_count += 1
	var ray_origin := _camera.project_ray_origin(screen_position)
	var ray_direction := _camera.project_ray_normal(screen_position).normalized()
	var quadratic_b := 2.0 * ray_origin.dot(ray_direction)
	var quadratic_c := ray_origin.length_squared() - 1.0
	var discriminant := quadratic_b * quadratic_b - 4.0 * quadratic_c
	if discriminant < 0.0:
		_update_interaction_status()
		return
	var distance := (-quadratic_b - sqrt(discriminant)) * 0.5
	if distance <= 0.0:
		_update_interaction_status()
		return
	var world_hit := ray_origin + ray_direction * distance
	var local_hit := (_planet_root.global_transform.affine_inverse() * world_hit).normalized()
	var best_face := resolve_spherical_triangle_face(
		local_hit,
		_presentation_vertices,
		_presentation_faces
	)
	if best_face < 0:
		_update_interaction_status()
		return
	var owners := _partition.get("owner_by_face", []) as Array
	var next_region := int(owners[best_face])
	if next_region != _selected_region_index:
		_selected_region_index = next_region
		_selection_change_count += 1
		_rebuild_selection_highlight(next_region)
	_update_interaction_status()


static func validate_presentation_mapping(
	topology: Dictionary,
	presentation_vertices: Array,
	presentation_faces: Array
) -> Dictionary:
	var expected_vertex_count := int(topology.get("vertex_count", 0))
	var expected_faces := topology.get("faces", []) as Array
	if presentation_vertices.size() != expected_vertex_count:
		return {"accepted": false, "reason": "debug_presentation_vertex_count_mismatch"}
	if presentation_faces != expected_faces:
		return {"accepted": false, "reason": "debug_presentation_face_id_order_mismatch"}
	var mapping_sha256 := StateCodec.fingerprint({
		"vertex_count": presentation_vertices.size(),
		"face_vertex_ids": presentation_faces,
	})
	if mapping_sha256 != EXPECTED_PRESENTATION_MAPPING_SHA256:
		return {
			"accepted": false,
			"reason": "debug_presentation_mapping_seal_mismatch",
			"actual_mapping_sha256": mapping_sha256,
		}
	return {
		"accepted": true,
		"reason": "",
		"mapping_sha256": mapping_sha256,
	}


static func resolve_spherical_triangle_face(
	point: Vector3,
	presentation_vertices: Array,
	presentation_faces: Array
) -> int:
	if point.length_squared() <= 0.0:
		return -1
	var normalized_point := point.normalized()
	for face_id in range(presentation_faces.size()):
		var face := presentation_faces[face_id] as Array
		if face.size() != 3:
			return -1
		var a := presentation_vertices[int(face[0])] as Vector3
		var b := presentation_vertices[int(face[1])] as Vector3
		var c := presentation_vertices[int(face[2])] as Vector3
		if spherical_triangle_contains(normalized_point, a, b, c):
			return face_id
	return -1


static func spherical_triangle_contains(
	point: Vector3,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	epsilon: float = 0.000001
) -> bool:
	if point.length_squared() <= 0.0:
		return false
	var center := (a + b + c).normalized()
	var vertices := [a, b, c]
	for edge_index in range(3):
		var edge_start := vertices[edge_index] as Vector3
		var edge_end := vertices[(edge_index + 1) % 3] as Vector3
		var edge_normal := edge_start.cross(edge_end)
		var reference_sign := edge_normal.dot(center)
		var point_sign := edge_normal.dot(point)
		if absf(point_sign) <= epsilon:
			continue
		if reference_sign * point_sign < 0.0:
			return false
	return true


func _rebuild_selection_highlight(region_index: int) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var owners := _partition.get("owner_by_face", []) as Array
	_highlight_triangle_count = 0
	for face_id in range(_presentation_faces.size()):
		if int(owners[face_id]) != region_index:
			continue
		for vertex_variant in _presentation_faces[face_id] as Array:
			var vertex := (_presentation_vertices[int(vertex_variant)] as Vector3) * 1.025
			surface.set_normal(vertex.normalized())
			surface.add_vertex(vertex)
		_highlight_triangle_count += 1
	_selection_highlight.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.78, 0.16, 0.62)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.56, 0.08, 1.0)
	material.emission_energy_multiplier = 1.6
	_selection_highlight.material_override = material
	_selection_highlight.visible = _highlight_triangle_count > 0


func _run_interaction_probe() -> Dictionary:
	var rotation_before := _planet_root.rotation
	var camera_distance_before := _camera.position.z
	var center := get_viewport().get_visible_rect().size * 0.5
	_parse_mouse_button(MOUSE_BUTTON_LEFT, true, center)
	await get_tree().process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = center + Vector2(84.0, -32.0)
	motion.global_position = motion.position
	motion.relative = Vector2(84.0, -32.0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion)
	await get_tree().process_frame
	_parse_mouse_button(MOUSE_BUTTON_LEFT, false, motion.position)
	await get_tree().process_frame
	_parse_mouse_button(MOUSE_BUTTON_WHEEL_UP, true, center)
	await get_tree().process_frame
	_parse_mouse_button(MOUSE_BUTTON_LEFT, true, center)
	await get_tree().process_frame
	_parse_mouse_button(MOUSE_BUTTON_LEFT, false, center)
	await get_tree().process_frame
	var rotation_changed := not _planet_root.rotation.is_equal_approx(rotation_before)
	var zoom_changed := not is_equal_approx(_camera.position.z, camera_distance_before)
	var selection_ready := _selected_region_index >= 0 and _selection_highlight.visible and _highlight_triangle_count > 0
	var status := "PASS" if (
		rotation_changed
		and zoom_changed
		and selection_ready
		and _rotation_event_count > 0
		and _zoom_event_count > 0
		and _hit_test_count > 0
		and _selection_change_count > 0
	) else "FAIL"
	return {
		"status": status,
		"rotation_changed": rotation_changed,
		"rotation_event_count": _rotation_event_count,
		"rotation_before_milliradians": _milliradian_vector(rotation_before),
		"rotation_after_milliradians": _milliradian_vector(_planet_root.rotation),
		"zoom_changed": zoom_changed,
		"zoom_event_count": _zoom_event_count,
		"camera_distance_before_milli": roundi(camera_distance_before * 1000.0),
		"camera_distance_after_milli": roundi(_camera.position.z * 1000.0),
		"hit_test_count": _hit_test_count,
		"selection_change_count": _selection_change_count,
		"selected_region_index": _selected_region_index,
		"highlight_visible": _selection_highlight.visible,
		"highlight_triangle_count": _highlight_triangle_count,
		"shared_boundary_segment_count": _shared_boundary_segment_count,
		"presentation_mapping_parity": not _presentation_mapping_sha256.is_empty(),
		"presentation_mapping_sha256": _presentation_mapping_sha256,
		"shape_complexity": DEBUG_SHAPE_COMPLEXITY,
		"land_region_count": _land_region_count,
		"ocean_region_count": _ocean_region_count,
		"terrain_feature_counts": _terrain_feature_counts,
	}


func _parse_mouse_button(button_index: MouseButton, pressed: bool, screen_position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = pressed
	event.position = screen_position
	event.global_position = screen_position
	Input.parse_input_event(event)


func _capture_visual_evidence() -> Dictionary:
	var image := get_viewport().get_texture().get_image()
	if image == null or image.get_width() <= 0 or image.get_height() <= 0:
		return {"status": "FAIL", "reason": "debug_sphere_viewport_image_empty"}
	var save_error := image.save_png(SCREENSHOT_PATH)
	if save_error != OK:
		return {"status": "FAIL", "reason": "debug_sphere_png_save_failed", "save_error": save_error}
	var absolute_path := ProjectSettings.globalize_path(SCREENSHOT_PATH)
	var bytes := FileAccess.get_file_as_bytes(SCREENSHOT_PATH)
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	var sha256 := hashing.finish().hex_encode()
	return {
		"status": "PASS",
		"reason": "",
		"path": absolute_path,
		"width": image.get_width(),
		"height": image.get_height(),
		"bytes": bytes.size(),
		"sha256": sha256,
	}


func _update_interaction_status() -> void:
	_interaction_status.text = "Drag rotate %d  ·  Wheel zoom %d  ·  Hit tests %d  ·  Selected %s" % [
		_rotation_event_count,
		_zoom_event_count,
		_hit_test_count,
		"none" if _selected_region_index < 0 else "region.%02d" % _selected_region_index,
	]


func _count_terrain_regions(target: String) -> int:
	var count := 0
	for terrain_variant in _partition.get("terrain_by_region", []) as Array:
		if str(terrain_variant) == target:
			count += 1
	return count


static func _feature_counts(features: Dictionary) -> Dictionary:
	return {
		"continent_count": (features.get("continents", []) as Array).size(),
		"bay_count": (features.get("bays", []) as Array).size(),
		"peninsula_count": (features.get("peninsulas", []) as Array).size(),
		"strait_count": (features.get("straits", []) as Array).size(),
		"archipelago_count": (features.get("archipelagos", []) as Array).size(),
	}


static func _milliradian_vector(value: Vector3) -> Array:
	return [
		roundi(value.x * 1000.0),
		roundi(value.y * 1000.0),
		roundi(value.z * 1000.0),
	]
