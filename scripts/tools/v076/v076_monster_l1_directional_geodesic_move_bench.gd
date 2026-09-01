extends Node3D

const StateCodec := preload("res://scripts/v076/simulation/v076_authority_state_codec.gd")
const Microgrid := preload("res://scripts/v076/map/v076_spherical_microgrid_index_v1.gd")
const PresentationGrid := preload("res://scripts/v074/map/v074_geodesic_microgrid.gd")
const Metric := preload("res://scripts/v076/monster/v076_integer_geodesic_metric_v1.gd")
const Audit := preload("res://scripts/v076/monster/v076_monster_l1_audit.gd")

const DEBUG_ROOT_SEED := 760_076
const EXPECTED_PRESENTATION_MAPPING_SHA256 := "01bdd9e9a5cbda0fd036c649b223ef8fa5bcdfd5c9dc51bad83b91199ef14959"
const SCREENSHOT_PATH := "user://v076_stage3_monster_l1_geodesic_bench.png"

@onready var _planet_surface: MeshInstance3D = %PlanetSurface
@onready var _route_render: MeshInstance3D = %RouteRender
@onready var _monster_marker: MeshInstance3D = %MonsterMarker
@onready var _authority_status: Label = %AuthorityStatus
@onready var _movement_status: Label = %MovementStatus


func _ready() -> void:
	var result := await _run_bench()
	print("V076_MONSTER_L1_DIRECTIONAL_GEODESIC_MOVE_BENCH|%s" % JSON.stringify(result))
	if str(result.get("status", "FAIL")) != "PASS":
		push_error("V076 monster L1 Bench failed: %s" % str(result.get("reason", "unknown")))
	await get_tree().create_timer(8.0).timeout
	get_tree().quit(0 if str(result.get("status", "FAIL")) == "PASS" else 1)


func _run_bench() -> Dictionary:
	var topology_result := Microgrid.build()
	var presentation_result := PresentationGrid.build(Microgrid.TOPOLOGY_LEVEL)
	if not bool(topology_result.get("accepted", false)) or not bool(presentation_result.get("accepted", false)):
		return {"status": "FAIL", "reason": "bench_topology_build_failed"}
	var topology := topology_result.get("topology", {}) as Dictionary
	var vertices := presentation_result.get("vertices_unit_sphere", []) as Array
	var faces := presentation_result.get("microcell_vertex_ids", []) as Array
	var centers := presentation_result.get("microcell_centers_unit_sphere", []) as Array
	var mapping_sha256 := StateCodec.fingerprint({"vertex_count": vertices.size(), "face_vertex_ids": faces})
	if (
		str(topology_result.get("topology_sha256", "")) != Metric.REQUIRED_TOPOLOGY_SHA256
		or vertices.size() != int(topology.get("vertex_count", -1))
		or faces != topology.get("faces", [])
		or mapping_sha256 != EXPECTED_PRESENTATION_MAPPING_SHA256
	):
		return {"status": "FAIL", "reason": "bench_presentation_mapping_mismatch", "actual_mapping_sha256": mapping_sha256}
	var audit := Audit.run_seed(DEBUG_ROOT_SEED, "GROUND", 2)
	if str(audit.get("status", "FAIL")) != "PASS":
		return {"status": "FAIL", "reason": str(audit.get("reason", "bench_audit_failed"))}
	var start_face_id := absi(DEBUG_ROOT_SEED * 17 + 3) % 320
	var target_face_id := absi(DEBUG_ROOT_SEED * 97 + 157) % 320
	if target_face_id == start_face_id:
		target_face_id = (target_face_id + 137) % 320
	var target_point_result := Metric.canonical_target_point(target_face_id)
	var route_result := Metric.build_route(
		start_face_id,
		target_face_id,
		target_point_result.get("target_point", {}) as Dictionary
	)
	var route := route_result.get("route", {}) as Dictionary
	if not bool(route_result.get("accepted", false)) or str(route_result.get("route_sha256", "")) != str(audit.get("route_sha256", "")):
		return {"status": "FAIL", "reason": "bench_route_identity_mismatch"}
	_planet_surface.mesh = _build_surface(vertices, faces)
	_route_render.mesh = _build_route_mesh(route.get("face_path", []) as Array, centers)
	var travelled_mu := int(audit.get("travelled_distance_mu", 0))
	var route_position := _locate_route_position(route, travelled_mu)
	if not bool(route_position.get("accepted", false)):
		return {"status": "FAIL", "reason": str(route_position.get("reason", "bench_position_projection_failed"))}
	var segment_index := int(route_position.get("segment_index", 0))
	var progress_mu := int(route_position.get("segment_progress_mu", 0))
	var segment_distance_mu := int(route_position.get("segment_distance_mu", 0))
	var face_path := route.get("face_path", []) as Array
	var marker_position := centers[int(face_path[mini(segment_index, face_path.size() - 1)])] as Vector3
	if progress_mu > 0 and segment_index + 1 < face_path.size():
		var from_center := centers[int(face_path[segment_index])] as Vector3
		var to_center := centers[int(face_path[segment_index + 1])] as Vector3
		marker_position = from_center.slerp(to_center, float(progress_mu) / float(segment_distance_mu)).normalized()
	_monster_marker.position = marker_position * 1.055
	var marker_mesh := SphereMesh.new()
	marker_mesh.radius = 0.045
	marker_mesh.height = 0.09
	_monster_marker.mesh = marker_mesh
	var marker_material := StandardMaterial3D.new()
	marker_material.albedo_color = Color(1.0, 0.24, 0.09, 1.0)
	marker_material.emission_enabled = true
	marker_material.emission = Color(1.0, 0.08, 0.02, 1.0)
	marker_material.emission_energy_multiplier = 2.4
	_monster_marker.material_override = marker_material
	_authority_status.text = "DIAGNOSTIC ONLY · NOT HUMAN GOLDEN STEP06-09 · topology %s… · sealed true-arc metric" % Metric.REQUIRED_TOPOLOGY_SHA256.left(12)
	_movement_status.text = "GROUND · travelled %d μrad · damage %d · crossings %d · replay 2/2 · float authority 0" % [travelled_mu, int(audit.get("total_trample_damage", 0)), int(audit.get("region_crossing_count", 0))]
	await get_tree().process_frame
	await get_tree().process_frame
	var viewport_texture := get_viewport().get_texture()
	if viewport_texture == null:
		return {"status": "FAIL", "reason": "bench_viewport_texture_unavailable"}
	var viewport_image := viewport_texture.get_image()
	if viewport_image == null:
		return {"status": "FAIL", "reason": "bench_viewport_image_unavailable"}
	var screenshot_result := viewport_image.save_png(SCREENSHOT_PATH)
	var screenshot_path := ProjectSettings.globalize_path(SCREENSHOT_PATH)
	var status := "PASS" if screenshot_result == OK else "FAIL"
	return {
		"status": status,
		"reason": "" if status == "PASS" else "bench_screenshot_failed",
		"scene_path": "res://scenes/tools/v076/V076MonsterL1DirectionalGeodesicMoveBench.tscn",
		"topology_sha256": Metric.REQUIRED_TOPOLOGY_SHA256,
		"arc_class_table_sha256": Metric.ARC_CLASS_TABLE_SHA256,
		"presentation_mapping_sha256": mapping_sha256,
		"route_sha256": str(audit.get("route_sha256", "")),
		"target_point_sha256": str(audit.get("target_point_sha256", "")),
		"route_segment_count": int(route.get("segment_count", 0)),
		"travelled_distance_mu": travelled_mu,
		"region_crossing_count": int(audit.get("region_crossing_count", 0)),
		"total_trample_damage": int(audit.get("total_trample_damage", 0)),
		"deterministic_replay_count": int(audit.get("deterministic_replay_count", 0)),
		"replay_state_hash_mismatch_count": int(audit.get("replay_state_hash_mismatch_count", -1)),
		"float_authority_field_count": int(audit.get("float_authority_field_count", -1)),
		"screenshot_path": screenshot_path,
		"screenshot_saved": screenshot_result == OK and FileAccess.file_exists(screenshot_path),
		"production_composition_cutover": false,
		"diagnostic_only": true,
		"human_golden_step_06_09": false,
	}


func _locate_route_position(route: Dictionary, travelled_distance_mu: int) -> Dictionary:
	var remaining_mu := travelled_distance_mu
	var segment_distances := route.get("segment_distance_mu_by_index", []) as Array
	for segment_index in range(segment_distances.size()):
		var segment_distance_mu := int(segment_distances[segment_index])
		if remaining_mu < segment_distance_mu:
			return {
				"accepted": true,
				"reason": "",
				"segment_index": segment_index,
				"segment_progress_mu": remaining_mu,
				"segment_distance_mu": segment_distance_mu,
			}
		remaining_mu -= segment_distance_mu
	if remaining_mu == 0:
		return {
			"accepted": true,
			"reason": "",
			"segment_index": segment_distances.size(),
			"segment_progress_mu": 0,
			"segment_distance_mu": 0,
		}
	return {"accepted": false, "reason": "bench_position_distance_overflow"}


func _build_surface(vertices: Array, faces: Array) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face_id in range(faces.size()):
		var color := Color.from_hsv(fmod(float(face_id) * 0.031, 1.0), 0.22, 0.34)
		for vertex_id_variant in faces[face_id] as Array:
			var vertex := vertices[int(vertex_id_variant)] as Vector3
			surface.set_color(color)
			surface.set_normal(vertex)
			surface.add_vertex(vertex)
	var mesh := surface.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.78
	_planet_surface.material_override = material
	return mesh


func _build_route_mesh(face_path: Array, centers: Array) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.73, 0.12, 1.0)
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, material)
	for face_id_variant in face_path:
		mesh.surface_add_vertex((centers[int(face_id_variant)] as Vector3) * 1.025)
	mesh.surface_end()
	return mesh
