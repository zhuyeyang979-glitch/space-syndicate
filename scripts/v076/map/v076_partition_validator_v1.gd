@tool
extends RefCounted
class_name V076PartitionValidatorV1

const StateCodec := preload("res://scripts/v076/simulation/v076_authority_state_codec.gd")
const DomainRng := preload("res://scripts/v076/simulation/v076_domain_rng.gd")
const AuthorityCodec := preload("res://scripts/v076/map/v076_partition_authority_codec_v1.gd")
const Microgrid := preload("res://scripts/v076/map/v076_spherical_microgrid_index_v1.gd")
const Partitioner := preload("res://scripts/v076/map/v076_shared_half_edge_partition_v1.gd")


static func validate_partition(partition: Variant) -> Dictionary:
	var shape := AuthorityCodec.validate_partition_shape(partition)
	if not bool(shape.get("valid", false)):
		return _failure(str(shape.get("reason", "v076_partition_shape_invalid")))
	var value := partition as Dictionary
	if int(value.get("schema_version", 0)) != AuthorityCodec.SCHEMA_VERSION:
		return _failure("v076_partition_schema_mismatch")
	if str(value.get("generator_id", "")) != AuthorityCodec.GENERATOR_ID:
		return _failure("v076_partition_generator_mismatch")
	var region_count := int(value.get("region_count", 0))
	if region_count <= 0:
		return _failure("v076_partition_region_count_not_positive")
	var shape_complexity := str(value.get("shape_complexity", ""))
	if not AuthorityCodec.SHAPE_COMPLEXITIES.has(shape_complexity):
		return _failure("v076_partition_shape_complexity_unsupported")
	var topology_result := Microgrid.build()
	if not bool(topology_result.get("accepted", false)):
		return topology_result
	var topology := topology_result.get("topology", {}) as Dictionary
	if region_count > int(topology.get("face_count", 0)):
		return _failure("v076_partition_region_count_exceeds_face_capacity")
	if str(value.get("topology_id", "")) != str(topology.get("topology_id", "")):
		return _failure("v076_partition_topology_id_mismatch")
	if str(value.get("topology_sha256", "")) != str(topology_result.get("topology_sha256", "")):
		return _failure("v076_partition_topology_sha_mismatch")
	var expected_counts := {
		"topology_level": int(topology.get("topology_level", 0)),
		"microvertex_count": int(topology.get("vertex_count", 0)),
		"microface_count": int(topology.get("face_count", 0)),
		"mesh_edge_count": int(topology.get("edge_count", 0)),
		"half_edge_count": int(topology.get("half_edge_count", 0)),
	}
	for count_field in expected_counts.keys():
		if int(value.get(count_field, -1)) != int(expected_counts[count_field]):
			return _failure("v076_partition_topology_count_mismatch:%s" % count_field)
	var half_edge_validation := _validate_half_edges(topology)
	if not bool(half_edge_validation.get("accepted", false)):
		return half_edge_validation
	var expected_region_ids: Array = []
	for region_index in range(region_count):
		expected_region_ids.append("region.%02d" % region_index)
	if value.get("region_ids", []) != expected_region_ids:
		return _failure("v076_partition_region_ids_not_canonical")
	var owners := value.get("owner_by_face", []) as Array
	var seed_faces := value.get("seed_face_ids", []) as Array
	if owners.size() != int(topology.get("face_count", 0)) or seed_faces.size() != region_count:
		return _failure("v076_partition_owner_or_seed_count_mismatch")
	var unique_seeds := {}
	for owner_variant in owners:
		if typeof(owner_variant) != TYPE_INT:
			return _failure("v076_partition_owner_not_integer")
		var owner := int(owner_variant)
		if owner < 0 or owner >= region_count:
			return _failure("v076_partition_owner_out_of_range")
	for region_index in range(region_count):
		if typeof(seed_faces[region_index]) != TYPE_INT:
			return _failure("v076_partition_seed_not_integer")
		var seed_face := int(seed_faces[region_index])
		if seed_face < 0 or seed_face >= owners.size() or unique_seeds.has(seed_face):
			return _failure("v076_partition_seed_invalid_or_duplicate")
		unique_seeds[seed_face] = true
		if int(owners[seed_face]) != region_index:
			return _failure("v076_partition_seed_owner_mismatch")
	var expected_facts := Partitioner.derive_partition_facts(topology, owners, region_count)
	if not bool(expected_facts.get("accepted", false)):
		return expected_facts
	for fact_field in [
		"faces_by_region", "adjacency_by_region", "boundary_cycles_by_region",
		"shared_boundary_edges"
	]:
		if value.get(fact_field, []) != expected_facts.get(fact_field, []):
			return _failure("v076_partition_derived_fact_mismatch:%s" % fact_field)
	var expected_terrain := Partitioner.derive_terrain_facts(
		int(value.get("root_seed", 0)),
		seed_faces,
		owners,
		value.get("adjacency_by_region", []) as Array,
		region_count
	)
	if not bool(expected_terrain.get("accepted", false)):
		return expected_terrain
	for terrain_field in ["terrain_by_region", "terrain_by_face", "terrain_features"]:
		if value.get(terrain_field) != expected_terrain.get(terrain_field):
			return _failure("v076_partition_terrain_fact_mismatch:%s" % terrain_field)
	var terrain_validation := _validate_terrain_contract(value, region_count, owners.size())
	if not bool(terrain_validation.get("accepted", false)):
		return terrain_validation
	var connectivity := _validate_connectivity(
		topology.get("face_neighbors", []) as Array,
		owners,
		value.get("faces_by_region", []) as Array,
		value.get("adjacency_by_region", []) as Array,
		region_count
	)
	if not bool(connectivity.get("accepted", false)):
		return connectivity
	var rng_validation := _validate_rng_snapshot(
		int(value.get("root_seed", 0)),
		region_count,
		value.get("rng_snapshot", {}) as Dictionary
	)
	if not bool(rng_validation.get("accepted", false)):
		return rng_validation
	var canonical_validation := _validate_canonical_generation(value)
	if not bool(canonical_validation.get("accepted", false)):
		return canonical_validation
	var partition_sha256 := AuthorityCodec.fingerprint_partition(value)
	if partition_sha256.is_empty() or StateCodec.count_float_fields(value) != 0:
		return _failure("v076_partition_authority_identity_invalid")
	return {
		"accepted": true,
		"reason": "",
		"partition_sha256": partition_sha256,
		"region_count": region_count,
		"shape_complexity": shape_complexity,
		"microface_count": owners.size(),
		"half_edge_count": int(topology.get("half_edge_count", 0)),
		"shared_boundary_edge_count": (value.get("shared_boundary_edges", []) as Array).size(),
		"region_graph_component_count": 1,
		"disconnected_region_count": 0,
		"float_authority_field_count": 0,
		"rng_draw_count": int((value.get("rng_snapshot", {}) as Dictionary).get("draw_count", -1)),
		"land_region_count": int(expected_terrain.get("land_region_count", 0)),
		"ocean_region_count": int(expected_terrain.get("ocean_region_count", 0)),
		"terrain_feature_counts": _terrain_feature_counts(value.get("terrain_features", {}) as Dictionary),
	}


static func _validate_half_edges(topology: Dictionary) -> Dictionary:
	var faces := topology.get("faces", []) as Array
	var half_edges := topology.get("half_edges", []) as Array
	var vertex_count := int(topology.get("vertex_count", 0))
	var edge_count := int(topology.get("edge_count", 0))
	if half_edges.size() != faces.size() * 3 or half_edges.size() != edge_count * 2:
		return _failure("v076_half_edge_cardinality_invalid")
	if vertex_count - edge_count + faces.size() != 2:
		return _failure("v076_half_edge_euler_invalid")
	for half_edge_id in range(half_edges.size()):
		var row := half_edges[half_edge_id] as Dictionary
		if int(row.get("half_edge_id", -1)) != half_edge_id:
			return _failure("v076_half_edge_id_invalid")
		var face_id := int(row.get("face_id", -1))
		var next_id := int(row.get("next_half_edge_id", -1))
		var previous_id := int(row.get("previous_half_edge_id", -1))
		var twin_id := int(row.get("twin_half_edge_id", -1))
		if (
			face_id < 0
			or half_edge_id < face_id * 3
			or half_edge_id >= face_id * 3 + 3
			or next_id != face_id * 3 + ((half_edge_id + 1) % 3)
			or previous_id != face_id * 3 + ((half_edge_id + 2) % 3)
		):
			return _failure("v076_half_edge_face_cycle_invalid")
		var next_row := half_edges[next_id] as Dictionary
		var previous_row := half_edges[previous_id] as Dictionary
		if int(next_row.get("previous_half_edge_id", -1)) != half_edge_id:
			return _failure("v076_half_edge_next_previous_not_reciprocal")
		if int(previous_row.get("next_half_edge_id", -1)) != half_edge_id:
			return _failure("v076_half_edge_previous_next_not_reciprocal")
		if int(row.get("destination_vertex_id", -1)) != int(next_row.get("origin_vertex_id", -1)):
			return _failure("v076_half_edge_next_endpoint_discontinuous")
		if int(row.get("origin_vertex_id", -1)) != int(previous_row.get("destination_vertex_id", -1)):
			return _failure("v076_half_edge_previous_endpoint_discontinuous")
		if twin_id < 0 or twin_id >= half_edges.size():
			return _failure("v076_half_edge_twin_out_of_range")
		var twin := half_edges[twin_id] as Dictionary
		if int(twin.get("twin_half_edge_id", -1)) != half_edge_id:
			return _failure("v076_half_edge_twin_not_reciprocal")
		if int(row.get("origin_vertex_id", -1)) != int(twin.get("destination_vertex_id", -1)):
			return _failure("v076_half_edge_twin_origin_mismatch")
		if int(row.get("destination_vertex_id", -1)) != int(twin.get("origin_vertex_id", -1)):
			return _failure("v076_half_edge_twin_destination_mismatch")
	return {"accepted": true, "reason": ""}


static func _validate_connectivity(
	face_neighbors: Array,
	owners: Array,
	faces_by_region: Array,
	adjacency_by_region: Array,
	region_count: int
) -> Dictionary:
	if faces_by_region.size() != region_count or adjacency_by_region.size() != region_count:
		return _failure("v076_partition_region_fact_count_mismatch")
	for region_index in range(region_count):
		var region_faces := faces_by_region[region_index] as Array
		if region_faces.is_empty():
			return _failure("v076_partition_region_empty")
		var visited := {int(region_faces[0]): true}
		var queue: Array = [int(region_faces[0])]
		var cursor := 0
		while cursor < queue.size():
			var face_id := int(queue[cursor])
			cursor += 1
			for neighbor_variant in face_neighbors[face_id] as Array:
				var neighbor := int(neighbor_variant)
				if int(owners[neighbor]) == region_index and not visited.has(neighbor):
					visited[neighbor] = true
					queue.append(neighbor)
		if visited.size() != region_faces.size():
			return _failure("v076_partition_region_disconnected")
		var neighbors := adjacency_by_region[region_index] as Array
		if neighbors.is_empty() and region_count > 1:
			return _failure("v076_partition_region_isolated")
		var previous := -1
		for neighbor_variant in neighbors:
			if typeof(neighbor_variant) != TYPE_INT:
				return _failure("v076_partition_neighbor_not_integer")
			var neighbor := int(neighbor_variant)
			if neighbor <= previous or neighbor == region_index or neighbor < 0 or neighbor >= region_count:
				return _failure("v076_partition_neighbor_not_canonical")
			if not (adjacency_by_region[neighbor] as Array).has(region_index):
				return _failure("v076_partition_neighbor_not_symmetric")
			previous = neighbor
	var seen := {0: true}
	var region_queue: Array = [0]
	var region_cursor := 0
	while region_cursor < region_queue.size():
		var region_index := int(region_queue[region_cursor])
		region_cursor += 1
		for neighbor_variant in adjacency_by_region[region_index] as Array:
			var neighbor := int(neighbor_variant)
			if not seen.has(neighbor):
				seen[neighbor] = true
				region_queue.append(neighbor)
	if seen.size() != region_count:
		return _failure("v076_partition_region_graph_disconnected")
	return {"accepted": true, "reason": ""}


static func _validate_rng_snapshot(
	root_seed: int,
	region_count: int,
	snapshot: Dictionary
) -> Dictionary:
	var rng := DomainRng.new()
	var configured := rng.configure(root_seed, AuthorityCodec.DOMAIN_ID)
	if not bool(configured.get("accepted", false)):
		return _failure("v076_partition_rng_validation_configure_failed")
	var restored := rng.restore(snapshot)
	if not bool(restored.get("accepted", false)):
		return _failure(str(restored.get("reason", "v076_partition_rng_snapshot_invalid")))
	if int(snapshot.get("draw_count", -1)) != region_count:
		return _failure("v076_partition_rng_draw_count_mismatch")
	var verifier := DomainRng.new()
	var verifier_configured := verifier.configure(root_seed, AuthorityCodec.DOMAIN_ID)
	if not bool(verifier_configured.get("accepted", false)):
		return _failure("v076_partition_rng_replay_configure_failed")
	for _draw_index in range(region_count):
		verifier.next_int()
	if verifier.snapshot() != snapshot:
		return _failure("v076_partition_rng_state_replay_mismatch")
	return {"accepted": true, "reason": ""}


static func _validate_terrain_contract(
	partition: Dictionary,
	region_count: int,
	face_count: int
) -> Dictionary:
	var terrain_by_region := partition.get("terrain_by_region", []) as Array
	var terrain_by_face := partition.get("terrain_by_face", []) as Array
	var owners := partition.get("owner_by_face", []) as Array
	if terrain_by_region.size() != region_count or terrain_by_face.size() != face_count:
		return _failure("v076_partition_terrain_coverage_mismatch")
	var terrain_counts := {"Land": 0, "Ocean": 0}
	for region_index in range(region_count):
		if typeof(terrain_by_region[region_index]) != TYPE_STRING:
			return _failure("v076_partition_region_terrain_not_string")
		var terrain := str(terrain_by_region[region_index])
		if not AuthorityCodec.TERRAIN_TYPES.has(terrain):
			return _failure("v076_partition_region_terrain_unsupported")
		terrain_counts[terrain] = int(terrain_counts[terrain]) + 1
	if region_count > 1 and (int(terrain_counts["Land"]) == 0 or int(terrain_counts["Ocean"]) == 0):
		return _failure("v076_partition_terrain_both_types_required")
	for face_id in range(face_count):
		if typeof(terrain_by_face[face_id]) != TYPE_STRING:
			return _failure("v076_partition_face_terrain_not_string")
		var owner := int(owners[face_id])
		if str(terrain_by_face[face_id]) != str(terrain_by_region[owner]):
			return _failure("v076_partition_face_terrain_owner_mismatch")
	var features := partition.get("terrain_features", {}) as Dictionary
	for component_field in ["continents", "archipelagos"]:
		var previous_component_start := -1
		for component_variant in features.get(component_field, []) as Array:
			if not (component_variant is Array) or (component_variant as Array).is_empty():
				return _failure("v076_partition_terrain_component_invalid:%s" % component_field)
			var previous_region := -1
			for region_variant in component_variant as Array:
				if typeof(region_variant) != TYPE_INT:
					return _failure("v076_partition_terrain_feature_region_not_integer")
				var region_index := int(region_variant)
				if region_index <= previous_region or region_index < 0 or region_index >= region_count:
					return _failure("v076_partition_terrain_component_not_canonical")
				previous_region = region_index
			if int((component_variant as Array)[0]) <= previous_component_start:
				return _failure("v076_partition_terrain_components_not_sorted")
			previous_component_start = int((component_variant as Array)[0])
	for scalar_field in ["bays", "peninsulas", "straits"]:
		var previous_region := -1
		for region_variant in features.get(scalar_field, []) as Array:
			if typeof(region_variant) != TYPE_INT:
				return _failure("v076_partition_terrain_feature_region_not_integer")
			var region_index := int(region_variant)
			if region_index <= previous_region or region_index < 0 or region_index >= region_count:
				return _failure("v076_partition_terrain_feature_not_canonical:%s" % scalar_field)
			previous_region = region_index
	return {"accepted": true, "reason": ""}


static func _terrain_feature_counts(features: Dictionary) -> Dictionary:
	return {
		"continent_count": (features.get("continents", []) as Array).size(),
		"bay_count": (features.get("bays", []) as Array).size(),
		"peninsula_count": (features.get("peninsulas", []) as Array).size(),
		"strait_count": (features.get("straits", []) as Array).size(),
		"archipelago_count": (features.get("archipelagos", []) as Array).size(),
	}


static func _validate_canonical_generation(partition: Dictionary) -> Dictionary:
	var root_seed := int(partition.get("root_seed", 0))
	var region_count := int(partition.get("region_count", 0))
	var shape_complexity := str(partition.get("shape_complexity", ""))
	var canonical_rng := DomainRng.new()
	var configured := canonical_rng.configure(root_seed, AuthorityCodec.DOMAIN_ID)
	if not bool(configured.get("accepted", false)):
		return _failure("v076_partition_canonical_rng_configure_failed")
	var generated := Partitioner.generate(root_seed, region_count, shape_complexity, canonical_rng)
	if not bool(generated.get("accepted", false)):
		return _failure(str(generated.get("reason", "v076_partition_canonical_generation_failed")))
	var canonical_partition := generated.get("partition", {}) as Dictionary
	if canonical_partition != partition:
		return _failure("v076_partition_noncanonical_generation")
	return {"accepted": true, "reason": ""}


static func _failure(reason: String) -> Dictionary:
	return {"accepted": false, "reason": reason}
