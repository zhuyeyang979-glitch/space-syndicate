extends SceneTree

const AuthorityCommand := preload("res://scripts/v076/simulation/v076_authority_command_v1.gd")
const StateCodec := preload("res://scripts/v076/simulation/v076_authority_state_codec.gd")
const DomainRng := preload("res://scripts/v076/simulation/v076_domain_rng.gd")
const Kernel := preload("res://scripts/v076/simulation/v076_deterministic_kernel.gd")
const AuthorityCodec := preload("res://scripts/v076/map/v076_partition_authority_codec_v1.gd")
const Microgrid := preload("res://scripts/v076/map/v076_spherical_microgrid_index_v1.gd")
const Partitioner := preload("res://scripts/v076/map/v076_shared_half_edge_partition_v1.gd")
const Validator := preload("res://scripts/v076/map/v076_partition_validator_v1.gd")
const Reducer := preload("res://scripts/v076/map/v076_partition_reducer_v1.gd")
const Audit := preload("res://scripts/v076/map/v076_partition_audit.gd")
const PresentationGrid := preload("res://scripts/v074/map/v074_geodesic_microgrid.gd")
const BenchScript := preload("res://scripts/tools/v076/v076_shared_half_edge_partition_bench.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_frozen_half_edge_topology()
	_test_closed_request_and_state_contracts()
	_test_focused_region_counts()
	_test_region_capacity_and_shape_complexity()
	_test_resigned_partition_tamper_rejection()
	_test_debug_sphere_scene_contract()
	_test_spherical_triangle_hit_contract()
	_test_stage1_fresh_script_reducer()
	_test_production_composition_isolation()
	print("V076_SHARED_HALF_EDGE_PARTITION_TEST|%s|%d/%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks - _failures.size(),
		_checks,
	])
	if not _failures.is_empty():
		push_error("\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _test_frozen_half_edge_topology() -> void:
	var result := Microgrid.build()
	_check(bool(result.get("accepted", false)), "frozen combinatorial spherical topology builds: %s actual=%s" % [str(result.get("reason", "")), str(result.get("actual_topology_sha256", ""))])
	if not bool(result.get("accepted", false)):
		return
	var topology := result.get("topology", {}) as Dictionary
	_check(int(topology.get("vertex_count", 0)) == 162, "subdivision-2 topology has 162 integer vertex identities")
	_check(int(topology.get("face_count", 0)) == 320, "subdivision-2 topology has 320 triangular faces")
	_check(int(topology.get("edge_count", 0)) == 480, "closed sphere topology has 480 shared mesh edges")
	_check(int(topology.get("half_edge_count", 0)) == 960, "every shared mesh edge has two directed half-edges")
	_check(162 - 480 + 320 == 2, "frozen topology satisfies the sphere Euler characteristic")
	var half_edge_links_valid := true
	for half_edge_variant in topology.get("half_edges", []) as Array:
		var half_edge := half_edge_variant as Dictionary
		var half_edge_id := int(half_edge.get("half_edge_id", -1))
		var next_id := int(half_edge.get("next_half_edge_id", -1))
		var previous_id := int(half_edge.get("previous_half_edge_id", -1))
		var next_row := (topology.get("half_edges", []) as Array)[next_id] as Dictionary
		var previous_row := (topology.get("half_edges", []) as Array)[previous_id] as Dictionary
		if (
			int(next_row.get("previous_half_edge_id", -1)) != half_edge_id
			or int(previous_row.get("next_half_edge_id", -1)) != half_edge_id
			or int(half_edge.get("destination_vertex_id", -1)) != int(next_row.get("origin_vertex_id", -1))
			or int(half_edge.get("origin_vertex_id", -1)) != int(previous_row.get("destination_vertex_id", -1))
		):
			half_edge_links_valid = false
			break
	_check(half_edge_links_valid, "every half-edge has reciprocal previous/next links and continuous endpoints")
	_check(str(result.get("topology_sha256", "")) == Microgrid.EXPECTED_TOPOLOGY_SHA256, "topology bytes match the frozen SHA256")


func _test_closed_request_and_state_contracts() -> void:
	for valid_count in [1, 6, 8, 12, 16, 20, 24, 30, 31, 32, 320, 321]:
		_check(bool(AuthorityCodec.validate_request_payload({"region_count": valid_count, "shape_complexity": "STANDARD"}).get("valid", false)), "positive region count %d passes request syntax without a 30-region constitutional cap" % int(valid_count))
	for invalid_count in [0, -1]:
		_check(not bool(AuthorityCodec.validate_request_payload({"region_count": invalid_count, "shape_complexity": "STANDARD"}).get("valid", true)), "non-positive region count %d fails closed" % int(invalid_count))
	for shape_complexity in AuthorityCodec.SHAPE_COMPLEXITIES:
		_check(bool(AuthorityCodec.validate_request_payload({"region_count": 16, "shape_complexity": shape_complexity}).get("valid", false)), "shape complexity %s passes the exact request contract" % str(shape_complexity))
	_check(not bool(AuthorityCodec.validate_request_payload({"region_count": 6.0, "shape_complexity": "STANDARD"}).get("valid", true)), "float region count cannot enter authority")
	_check(not bool(AuthorityCodec.validate_request_payload({"region_count": 6, "shape_complexity": "EXTREME"}).get("valid", true)), "unknown shape complexity fails closed")
	_check(not bool(AuthorityCodec.validate_request_payload({"region_count": 6, "shape_complexity": "STANDARD", "extra": 1}).get("valid", true)), "unknown request fields fail closed")
	_check(bool(AuthorityCodec.validate_domain_state(Reducer.initial_state()).get("valid", false)), "reducer initial state has exact closed shape")
	_check(not bool(StateCodec.validate({"map_position": Vector3.ZERO}).get("valid", true)), "Vector3 geometry cannot enter V076 authority")


func _test_focused_region_counts() -> void:
	var result := Audit.run_focused_suite()
	_check(str(result.get("status", "FAIL")) == "PASS", "all focused region-count/complexity partitions validate: %s actual_topology=%s" % [str(result.get("reason", "")), str(result.get("actual_topology_sha256", ""))])
	_check(int(result.get("focused_region_count_case_count", 0)) == 7, "required acceptance matrix retains exact 6/8/12/16/20/24/30 coverage")
	_check(int(result.get("focused_complexity_matrix_case_count", 0)) == 21, "focused gate covers the complete 7-count by 3-complexity matrix")
	_check(int(result.get("focused_extended_positive_region_count_case_count", 0)) == 2, "focused gate proves 31 and 32 regions are accepted")
	_check(int(result.get("focused_generation_failure_count", -1)) == 0, "focused generation failure count is zero")
	_check(int(result.get("focused_replay_mismatch_count", -1)) == 0, "fresh same-seed partition fingerprints match")
	_check(bool(result.get("changed_seed_partition_delta", false)), "known changed seeds produce distinct partition identity")
	_check(bool(result.get("changed_seed_terrain_delta", false)), "known changed seeds produce distinct terrain identity")
	_check(int(result.get("shape_complexity_boundary_delta_count", 0)) == 7, "shape complexity changes integer owner/boundary authority for every acceptance-matrix count")


func _test_region_capacity_and_shape_complexity() -> void:
	for supported_count in [1, 320]:
		var supported_rng := DomainRng.new()
		supported_rng.configure(760_000 + int(supported_count), AuthorityCodec.DOMAIN_ID)
		var supported := Partitioner.generate(760_000 + int(supported_count), int(supported_count), "SIMPLE", supported_rng)
		_check(bool(supported.get("accepted", false)) and bool(Validator.validate_partition(supported.get("partition", {})).get("accepted", false)), "%d regions generate and validate within the natural face capacity" % int(supported_count))
	var capacity_rng := DomainRng.new()
	capacity_rng.configure(760_321, AuthorityCodec.DOMAIN_ID)
	var over_capacity := Partitioner.generate(760_321, 321, "STANDARD", capacity_rng)
	_check(not bool(over_capacity.get("accepted", true)) and str(over_capacity.get("reason", "")) == "v076_partition_region_count_exceeds_face_capacity", "321 regions fail closed at the natural 320-face capacity")
	var partitions_by_complexity := {}
	for shape_complexity in AuthorityCodec.SHAPE_COMPLEXITIES:
		var rng := DomainRng.new()
		rng.configure(760_160, AuthorityCodec.DOMAIN_ID)
		var generated := Partitioner.generate(760_160, 16, str(shape_complexity), rng)
		_check(bool(generated.get("accepted", false)), "%s authority partition generates" % str(shape_complexity))
		if bool(generated.get("accepted", false)):
			partitions_by_complexity[str(shape_complexity)] = generated.get("partition", {})
	var simple := partitions_by_complexity.get("SIMPLE", {}) as Dictionary
	var standard := partitions_by_complexity.get("STANDARD", {}) as Dictionary
	var complex := partitions_by_complexity.get("COMPLEX", {}) as Dictionary
	_check(simple.get("owner_by_face", []) != standard.get("owner_by_face", []) or simple.get("shared_boundary_edges", []) != standard.get("shared_boundary_edges", []), "STANDARD jitter changes integer authority rather than only labeling SIMPLE output")
	_check(simple.get("owner_by_face", []) != complex.get("owner_by_face", []) or simple.get("shared_boundary_edges", []) != complex.get("shared_boundary_edges", []), "COMPLEX jitter changes integer authority rather than only labeling SIMPLE output")
	if not complex.is_empty():
		var terrain_by_region := complex.get("terrain_by_region", []) as Array
		var terrain_by_face := complex.get("terrain_by_face", []) as Array
		_check(terrain_by_region.size() == 16 and terrain_by_region.has("Land") and terrain_by_region.has("Ocean"), "terrain authority covers every region with both Land and Ocean")
		_check(terrain_by_face.size() == 320 and terrain_by_face.has("Land") and terrain_by_face.has("Ocean"), "terrain authority covers every microface with both Land and Ocean")


func _test_resigned_partition_tamper_rejection() -> void:
	var rng := DomainRng.new()
	rng.configure(760_077, AuthorityCodec.DOMAIN_ID)
	var generated := Partitioner.generate(760_077, 12, "COMPLEX", rng)
	_check(bool(generated.get("accepted", false)), "tamper fixture starts from one valid sealed partition")
	if not bool(generated.get("accepted", false)):
		return
	var partition := generated.get("partition", {}) as Dictionary
	var owner_tamper := partition.duplicate(true)
	var owners := owner_tamper.get("owner_by_face", []) as Array
	owners[owners.size() - 1] = (int(owners.back()) + 1) % 12
	owner_tamper["owner_by_face"] = owners
	_check(not bool(Validator.validate_partition(owner_tamper).get("accepted", true)), "re-signed owner mutation cannot retain stale membership or boundary facts")
	var boundary_tamper := partition.duplicate(true)
	var boundaries := boundary_tamper.get("boundary_cycles_by_region", []) as Array
	var first_region_cycles := boundaries[0] as Array
	var first_cycle := first_region_cycles[0] as Array
	first_cycle.pop_back()
	first_region_cycles[0] = first_cycle
	boundaries[0] = first_region_cycles
	boundary_tamper["boundary_cycles_by_region"] = boundaries
	_check(not bool(Validator.validate_partition(boundary_tamper).get("accepted", true)), "re-signed open boundary cycle fails derived-fact validation")
	var rng_tamper := partition.duplicate(true)
	var rng_snapshot := (rng_tamper.get("rng_snapshot", {}) as Dictionary).duplicate(true)
	rng_snapshot["draw_count"] = int(rng_snapshot.get("draw_count", 0)) + 1
	rng_tamper["rng_snapshot"] = rng_snapshot
	_check(not bool(Validator.validate_partition(rng_tamper).get("accepted", true)), "re-signed RNG cursor mutation fails exact draw-count validation")
	var rng_state_tamper := partition.duplicate(true)
	var state_snapshot := (rng_state_tamper.get("rng_snapshot", {}) as Dictionary).duplicate(true)
	state_snapshot["state"] = int(state_snapshot.get("state", 1)) + 1
	if int(state_snapshot.get("state", 0)) >= DomainRng.MODULUS:
		state_snapshot["state"] = 1
	rng_state_tamper["rng_snapshot"] = state_snapshot
	_check(not bool(Validator.validate_partition(rng_state_tamper).get("accepted", true)), "re-signed RNG state mutation fails exact root/domain/draw replay")
	var topology_tamper := partition.duplicate(true)
	topology_tamper["topology_sha256"] = "0".repeat(64)
	_check(not bool(Validator.validate_partition(topology_tamper).get("accepted", true)), "re-signed topology identity mutation fails the frozen table seal")
	var terrain_tamper := partition.duplicate(true)
	var terrain_by_region := (terrain_tamper.get("terrain_by_region", []) as Array).duplicate()
	terrain_by_region[0] = "Ocean" if str(terrain_by_region[0]) == "Land" else "Land"
	terrain_tamper["terrain_by_region"] = terrain_by_region
	_check(not bool(Validator.validate_partition(terrain_tamper).get("accepted", true)), "re-signed region terrain mutation fails deterministic terrain derivation")
	var complexity_tamper := partition.duplicate(true)
	complexity_tamper["shape_complexity"] = "SIMPLE"
	_check(not bool(Validator.validate_partition(complexity_tamper).get("accepted", true)), "re-signed complexity label cannot preserve different weighted authority bytes")
	var synchronized_tamper := partition.duplicate(true)
	var synchronized_owners := (synchronized_tamper.get("owner_by_face", []) as Array).duplicate()
	for face_id in range(synchronized_owners.size()):
		if int(synchronized_owners[face_id]) == 0:
			synchronized_owners[face_id] = 1
		elif int(synchronized_owners[face_id]) == 1:
			synchronized_owners[face_id] = 0
	var synchronized_seeds := (synchronized_tamper.get("seed_face_ids", []) as Array).duplicate()
	var seed_swap: Variant = synchronized_seeds[0]
	synchronized_seeds[0] = synchronized_seeds[1]
	synchronized_seeds[1] = seed_swap
	var topology := (Microgrid.build().get("topology", {}) as Dictionary)
	var synchronized_facts := Partitioner.derive_partition_facts(topology, synchronized_owners, 12)
	synchronized_tamper["owner_by_face"] = synchronized_owners
	synchronized_tamper["seed_face_ids"] = synchronized_seeds
	for fact_field in ["faces_by_region", "adjacency_by_region", "boundary_cycles_by_region", "shared_boundary_edges"]:
		synchronized_tamper[fact_field] = synchronized_facts.get(fact_field, [])
	var synchronized_terrain := Partitioner.derive_terrain_facts(
		760_077,
		synchronized_seeds,
		synchronized_owners,
		synchronized_facts.get("adjacency_by_region", []) as Array,
		12
	)
	for terrain_field in ["terrain_by_region", "terrain_by_face", "terrain_features"]:
		synchronized_tamper[terrain_field] = synchronized_terrain.get(terrain_field)
	_check(not bool(Validator.validate_partition(synchronized_tamper).get("accepted", true)), "synchronously re-signed seed/owner/derived facts still fail canonical generation replay")
	var consumed_rng := DomainRng.new()
	consumed_rng.configure(760_077, AuthorityCodec.DOMAIN_ID)
	consumed_rng.next_int()
	_check(not bool(Partitioner.generate(760_077, 12, "COMPLEX", consumed_rng).get("accepted", true)), "partition generation rejects a Domain RNG with prior draws")


func _test_debug_sphere_scene_contract() -> void:
	var packed := load("res://scenes/tools/v076/V076SharedHalfEdgePartitionBench.tscn") as PackedScene
	_check(packed != null, "interactive Debug Sphere Bench loads as a PackedScene")
	if packed == null:
		return
	var instance := packed.instantiate()
	_check(instance is Node3D, "interactive Debug Sphere has a Node3D root")
	_check(instance.get_node_or_null("PlanetRoot/RegionSurface") is MeshInstance3D, "Debug Sphere owns a region MeshInstance3D")
	_check(instance.get_node_or_null("PlanetRoot/SharedBoundaryRender") is MeshInstance3D, "Debug Sphere owns a shared-boundary MeshInstance3D")
	_check(instance.get_node_or_null("PlanetRoot/SelectionHighlight") is MeshInstance3D, "Debug Sphere owns a selection-highlight MeshInstance3D")
	_check(instance.get_node_or_null("DebugCamera") is Camera3D, "Debug Sphere owns a real Camera3D")
	var bench_source := FileAccess.get_file_as_string("res://scripts/tools/v076/v076_shared_half_edge_partition_bench.gd")
	_check(bench_source.contains("Input.parse_input_event") and bench_source.contains("project_ray_origin") and bench_source.contains("project_ray_normal"), "Debug Sphere interaction probe uses the real input and camera ray path")
	_check(bench_source.contains("PRIMITIVE_LINES") and bench_source.contains("shared_boundary_edges"), "Debug Sphere renders authority-derived shared boundaries")
	_check(bench_source.contains("terrain_by_face") and bench_source.contains("Land") and bench_source.contains("Ocean"), "Debug Sphere visibly distinguishes authoritative Land and Ocean faces")
	_check(bench_source.contains("spherical_triangle_contains") and not bench_source.contains("best_dot"), "Debug Sphere resolves hits with spherical triangle containment instead of nearest-center approximation")
	instance.free()


func _test_spherical_triangle_hit_contract() -> void:
	var topology := Microgrid.build().get("topology", {}) as Dictionary
	var presentation := PresentationGrid.build(Microgrid.TOPOLOGY_LEVEL)
	var vertices := presentation.get("vertices_unit_sphere", []) as Array
	var faces := presentation.get("microcell_vertex_ids", []) as Array
	var mapping := BenchScript.validate_presentation_mapping(topology, vertices, faces)
	_check(bool(mapping.get("accepted", false)), "V074 presentation arrays exactly match the sealed V076 vertex/face identity mapping: %s actual=%s" % [str(mapping.get("reason", "")), str(mapping.get("actual_mapping_sha256", ""))])
	var drifted_faces := faces.duplicate(true)
	var face_swap: Variant = drifted_faces[0]
	drifted_faces[0] = drifted_faces[1]
	drifted_faces[1] = face_swap
	_check(not bool(BenchScript.validate_presentation_mapping(topology, vertices, drifted_faces).get("accepted", true)), "presentation face-order drift fails before any V076 ID indexes V074 float arrays")
	var half_edges := topology.get("half_edges", []) as Array
	var half_edge := half_edges[0] as Dictionary
	var twin_id := int(half_edge.get("twin_half_edge_id", -1))
	var adjacent_face_id := int((half_edges[twin_id] as Dictionary).get("face_id", -1))
	var origin := vertices[int(half_edge.get("origin_vertex_id", -1))] as Vector3
	var destination := vertices[int(half_edge.get("destination_vertex_id", -1))] as Vector3
	var edge_midpoint := (origin + destination).normalized()
	var resolved_boundary_face := BenchScript.resolve_spherical_triangle_face(edge_midpoint, vertices, faces)
	_check(resolved_boundary_face == mini(0, adjacent_face_id), "exact shared-edge hit resolves deterministically to the smallest face_id")
	var face_zero := faces[0] as Array
	var face_center := (
		(vertices[int(face_zero[0])] as Vector3)
		+ (vertices[int(face_zero[1])] as Vector3)
		+ (vertices[int(face_zero[2])] as Vector3)
	).normalized()
	var just_inside := (edge_midpoint * 1000.0 + face_center).normalized()
	_check(BenchScript.spherical_triangle_contains(just_inside, vertices[int(face_zero[0])] as Vector3, vertices[int(face_zero[1])] as Vector3, vertices[int(face_zero[2])] as Vector3), "point just inside a shared edge passes spherical half-space containment")
	_check(not BenchScript.spherical_triangle_contains(Vector3.ZERO, vertices[int(face_zero[0])] as Vector3, vertices[int(face_zero[1])] as Vector3, vertices[int(face_zero[2])] as Vector3), "invalid zero-direction hit fails spherical triangle containment")


func _test_stage1_fresh_script_reducer() -> void:
	var kernel := Kernel.new()
	root.add_child(kernel)
	_check(bool(kernel.configure(760_076).get("accepted", false)), "Stage1 kernel accepts the Stage2 root seed")
	_check(bool(kernel.register_domain(AuthorityCodec.DOMAIN_ID, Reducer.initial_state(), Reducer).get("accepted", false)), "Stage2 reducer satisfies the Script-only fresh reducer contract")
	var built := AuthorityCommand.build(
		"map.partition.generate.001",
		AuthorityCodec.DOMAIN_ID,
		AuthorityCodec.COMMAND_TYPE,
		"system.map_genesis",
		1,
		10,
		1,
		{"region_count": 16, "shape_complexity": "COMPLEX"}
	)
	_check(bool(built.get("accepted", false)), "partition command uses the closed Stage1 envelope")
	_check(bool(kernel.submit_command(built.get("command", {}) as Dictionary).get("accepted", false)), "partition command enters the deterministic queue")
	var advanced := kernel.advance_elapsed_us(50_000)
	_check(bool(advanced.get("accepted", false)) and kernel.current_tick() == 1, "partition executes atomically on one 20Hz tick")
	var state := kernel.domain_state(AuthorityCodec.DOMAIN_ID)
	_check(bool(AuthorityCodec.validate_domain_state(state).get("valid", false)), "kernel state contains a hash-bound pure-integer partition")
	_check(int(state.get("generation_count", 0)) == 1, "kernel commits the partition exactly once")
	_check(StateCodec.count_float_fields(state) == 0, "kernel partition state has zero float authority fields")
	var envelope := kernel.capture_snapshot()
	_check(bool(envelope.get("accepted", false)), "Stage2 partition survives Stage1 snapshot capture")
	var restored := Kernel.new()
	root.add_child(restored)
	restored.configure(760_076)
	restored.register_domain(AuthorityCodec.DOMAIN_ID, Reducer.initial_state(), Reducer)
	var restore_result := restored.restore_snapshot(envelope.get("snapshot", {}) as Dictionary, str(envelope.get("snapshot_sha256", "")))
	_check(bool(restore_result.get("accepted", false)), "Stage1 semantic replay validates the Stage2 snapshot")
	_check(restored.state_fingerprint() == kernel.state_fingerprint(), "snapshot restore preserves exact Stage2 authority identity")
	var second_built := AuthorityCommand.build(
		"map.partition.generate.002",
		AuthorityCodec.DOMAIN_ID,
		AuthorityCodec.COMMAND_TYPE,
		"system.map_genesis",
		2,
		10,
		2,
		{"region_count": 16, "shape_complexity": "COMPLEX"}
	)
	kernel.submit_command(second_built.get("command", {}) as Dictionary)
	var before_second_hash := kernel.state_fingerprint()
	var second_advance := kernel.advance_elapsed_us(50_000)
	_check(not bool(second_advance.get("accepted", true)), "a second partition generation in the same domain fails closed")
	_check(kernel.state_fingerprint() == before_second_hash, "rejected second generation leaves the first partition atomic and unchanged")
	restored.free()
	kernel.free()


func _test_production_composition_isolation() -> void:
	var project_source := FileAccess.get_file_as_string("res://project.godot")
	var main_source := FileAccess.get_file_as_string("res://scenes/main.tscn")
	var v075_owner_source := FileAccess.get_file_as_string("res://scripts/v075_runtime/v075_runtime_owner.gd")
	_check(project_source.contains('run/main_scene="res://scenes/main.tscn"'), "Stage2 does not replace the production main scene")
	_check(main_source.contains("V075RuntimeComposition.tscn") and not main_source.contains("v076_partition"), "Stage2 does not enter main.tscn composition")
	_check(v075_owner_source.begins_with('extends "res://scripts/v074_runtime/v074_runtime_owner.gd"'), "Stage2 does not cut over the inherited V075 runtime owner")


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
