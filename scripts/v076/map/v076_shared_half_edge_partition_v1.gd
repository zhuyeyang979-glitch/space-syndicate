@tool
extends RefCounted
class_name V076SharedHalfEdgePartitionV1

const StateCodec := preload("res://scripts/v076/simulation/v076_authority_state_codec.gd")
const AuthorityCodec := preload("res://scripts/v076/map/v076_partition_authority_codec_v1.gd")
const Microgrid := preload("res://scripts/v076/map/v076_spherical_microgrid_index_v1.gd")


static func generate(
	root_seed: int,
	region_count: int,
	shape_complexity: String,
	rng: Variant
) -> Dictionary:
	var seed_validation := StateCodec.validate({"root_seed": root_seed})
	if not bool(seed_validation.get("valid", false)):
		return _failure("v076_partition_root_seed_invalid")
	var request_validation := AuthorityCodec.validate_request_payload({
		"region_count": region_count,
		"shape_complexity": shape_complexity,
	})
	if not bool(request_validation.get("valid", false)):
		return _failure(str(request_validation.get("reason", "v076_partition_request_invalid")))
	if rng == null or not rng.has_method("snapshot") or not rng.has_method("randi_range"):
		return _failure("v076_partition_rng_contract_missing")
	var rng_before_variant: Variant = rng.call("snapshot")
	if not (rng_before_variant is Dictionary):
		return _failure("v076_partition_rng_snapshot_not_dictionary")
	var rng_before := rng_before_variant as Dictionary
	if rng_before.size() != 5 or typeof(rng_before.get("draw_count")) != TYPE_INT:
		return _failure("v076_partition_rng_snapshot_shape_invalid")
	if str(rng_before.get("domain_id", "")) != AuthorityCodec.DOMAIN_ID:
		return _failure("v076_partition_rng_domain_mismatch")
	if int(rng_before.get("root_seed", 0)) != root_seed:
		return _failure("v076_partition_rng_root_seed_mismatch")
	if int(rng_before.get("draw_count", -1)) != 0:
		return _failure("v076_partition_rng_not_at_domain_origin")
	var topology_result := Microgrid.build()
	if not bool(topology_result.get("accepted", false)):
		return topology_result
	var topology := topology_result.get("topology", {}) as Dictionary
	var face_neighbors := topology.get("face_neighbors", []) as Array
	if region_count > face_neighbors.size():
		return _failure("v076_partition_region_count_exceeds_face_capacity")
	var seed_result := _select_seed_faces(face_neighbors, region_count, rng)
	if not bool(seed_result.get("accepted", false)):
		return seed_result
	var seed_faces := seed_result.get("seed_face_ids", []) as Array
	var owner_result := _partition_faces(
		face_neighbors,
		seed_faces,
		root_seed,
		shape_complexity
	)
	if not bool(owner_result.get("accepted", false)):
		return owner_result
	var owners := owner_result.get("owner_by_face", []) as Array
	var fact_result := derive_partition_facts(topology, owners, region_count)
	if not bool(fact_result.get("accepted", false)):
		return fact_result
	var terrain_result := derive_terrain_facts(
		root_seed,
		seed_faces,
		owners,
		fact_result.get("adjacency_by_region", []) as Array,
		region_count
	)
	if not bool(terrain_result.get("accepted", false)):
		return terrain_result
	var rng_after_variant: Variant = rng.call("snapshot")
	if not (rng_after_variant is Dictionary):
		return _failure("v076_partition_rng_final_snapshot_not_dictionary")
	var rng_after := rng_after_variant as Dictionary
	var partition := {
		"schema_version": AuthorityCodec.SCHEMA_VERSION,
		"generator_id": AuthorityCodec.GENERATOR_ID,
		"root_seed": root_seed,
		"region_count": region_count,
		"shape_complexity": shape_complexity,
		"topology_id": str(topology.get("topology_id", "")),
		"topology_sha256": str(topology_result.get("topology_sha256", "")),
		"topology_level": int(topology.get("topology_level", 0)),
		"microvertex_count": int(topology.get("vertex_count", 0)),
		"microface_count": int(topology.get("face_count", 0)),
		"mesh_edge_count": int(topology.get("edge_count", 0)),
		"half_edge_count": int(topology.get("half_edge_count", 0)),
		"region_ids": _region_ids(region_count),
		"seed_face_ids": seed_faces,
		"owner_by_face": owners,
		"faces_by_region": fact_result.get("faces_by_region", []),
		"adjacency_by_region": fact_result.get("adjacency_by_region", []),
		"boundary_cycles_by_region": fact_result.get("boundary_cycles_by_region", []),
		"shared_boundary_edges": fact_result.get("shared_boundary_edges", []),
		"terrain_by_region": terrain_result.get("terrain_by_region", []),
		"terrain_by_face": terrain_result.get("terrain_by_face", []),
		"terrain_features": terrain_result.get("terrain_features", {}),
		"rng_snapshot": rng_after,
	}
	var shape_validation := AuthorityCodec.validate_partition_shape(partition)
	if not bool(shape_validation.get("valid", false)):
		return _failure(str(shape_validation.get("reason", "v076_partition_shape_invalid")))
	var partition_sha256 := AuthorityCodec.fingerprint_partition(partition)
	if partition_sha256.is_empty():
		return _failure("v076_partition_fingerprint_empty")
	return {
		"accepted": true,
		"reason": "",
		"partition": partition,
		"partition_sha256": partition_sha256,
	}


static func derive_partition_facts(
	topology: Dictionary,
	owners: Array,
	region_count: int
) -> Dictionary:
	var face_count := int(topology.get("face_count", 0))
	var half_edges := topology.get("half_edges", []) as Array
	if owners.size() != face_count or region_count <= 0:
		return _failure("v076_partition_fact_input_invalid")
	var faces_by_region: Array = []
	var adjacency_sets: Array = []
	var boundary_half_edges: Array = []
	for _region_index in range(region_count):
		faces_by_region.append([])
		adjacency_sets.append({})
		boundary_half_edges.append([])
	for face_id in range(face_count):
		var owner := int(owners[face_id])
		if owner < 0 or owner >= region_count:
			return _failure("v076_partition_owner_out_of_range")
		(faces_by_region[owner] as Array).append(face_id)
	var shared_boundary_edges: Array = []
	for half_edge_id in range(half_edges.size()):
		var half_edge := half_edges[half_edge_id] as Dictionary
		var twin_id := int(half_edge.get("twin_half_edge_id", -1))
		if twin_id < 0 or twin_id >= half_edges.size():
			return _failure("v076_partition_half_edge_twin_invalid")
		var face_id := int(half_edge.get("face_id", -1))
		var twin_face_id := int((half_edges[twin_id] as Dictionary).get("face_id", -1))
		var owner := int(owners[face_id])
		var twin_owner := int(owners[twin_face_id])
		if owner == twin_owner:
			continue
		(adjacency_sets[owner] as Dictionary)[twin_owner] = true
		(boundary_half_edges[owner] as Array).append(half_edge_id)
		if half_edge_id < twin_id:
			var region_a := mini(owner, twin_owner)
			var region_b := maxi(owner, twin_owner)
			var half_edge_a := half_edge_id if owner == region_a else twin_id
			var half_edge_b := twin_id if owner == region_a else half_edge_id
			shared_boundary_edges.append({
				"region_a_index": region_a,
				"region_b_index": region_b,
				"half_edge_a_to_b": half_edge_a,
				"half_edge_b_to_a": half_edge_b,
			})
	var adjacency_by_region: Array = []
	var boundary_cycles_by_region: Array = []
	for region_index in range(region_count):
		var neighbors: Array = (adjacency_sets[region_index] as Dictionary).keys()
		neighbors.sort()
		adjacency_by_region.append(neighbors)
		var cycle_result := _canonical_boundary_cycles(
			boundary_half_edges[region_index] as Array,
			half_edges
		)
		if not bool(cycle_result.get("accepted", false)):
			return cycle_result
		boundary_cycles_by_region.append(cycle_result.get("cycles", []))
	return {
		"accepted": true,
		"reason": "",
		"faces_by_region": faces_by_region,
		"adjacency_by_region": adjacency_by_region,
		"boundary_cycles_by_region": boundary_cycles_by_region,
		"shared_boundary_edges": shared_boundary_edges,
	}


static func derive_terrain_facts(
	root_seed: int,
	seed_faces: Array,
	owners: Array,
	adjacency_by_region: Array,
	region_count: int
) -> Dictionary:
	if (
		region_count <= 0
		or seed_faces.size() != region_count
		or adjacency_by_region.size() != region_count
		or owners.is_empty()
	):
		return _failure("v076_partition_terrain_input_invalid")
	var terrain_by_region: Array = []
	var terrain_scores: Array = []
	var land_count := 0
	for region_index in range(region_count):
		var score := _terrain_score(root_seed, region_index, int(seed_faces[region_index]))
		terrain_scores.append(score)
		var terrain := "Land" if score < 57 else "Ocean"
		terrain_by_region.append(terrain)
		if terrain == "Land":
			land_count += 1
	if region_count > 1 and land_count == 0:
		var land_index := _minimum_score_index(terrain_scores)
		terrain_by_region[land_index] = "Land"
		land_count = 1
	elif region_count > 1 and land_count == region_count:
		var ocean_index := _maximum_score_index(terrain_scores)
		terrain_by_region[ocean_index] = "Ocean"
		land_count -= 1
	var terrain_by_face: Array = []
	for owner_variant in owners:
		var owner := int(owner_variant)
		if owner < 0 or owner >= region_count:
			return _failure("v076_partition_terrain_owner_out_of_range")
		terrain_by_face.append(str(terrain_by_region[owner]))
	var land_components := _terrain_components(
		terrain_by_region,
		adjacency_by_region,
		"Land"
	)
	var continents: Array = []
	var archipelagos: Array = []
	for component_variant in land_components:
		var component := component_variant as Array
		if component.size() >= 3:
			continents.append(component)
		else:
			archipelagos.append(component)
	var bays: Array = []
	var peninsulas: Array = []
	var straits: Array = []
	for region_index in range(region_count):
		var land_neighbor_count := 0
		var ocean_neighbor_count := 0
		for neighbor_variant in adjacency_by_region[region_index] as Array:
			var neighbor_terrain := str(terrain_by_region[int(neighbor_variant)])
			if neighbor_terrain == "Land":
				land_neighbor_count += 1
			else:
				ocean_neighbor_count += 1
		var terrain := str(terrain_by_region[region_index])
		if terrain == "Ocean":
			if land_neighbor_count >= 3:
				bays.append(region_index)
			if land_neighbor_count >= 2 and ocean_neighbor_count <= 2:
				straits.append(region_index)
		elif ocean_neighbor_count >= 2 and land_neighbor_count <= 2:
			peninsulas.append(region_index)
	return {
		"accepted": true,
		"reason": "",
		"terrain_by_region": terrain_by_region,
		"terrain_by_face": terrain_by_face,
		"terrain_features": {
			"continents": continents,
			"bays": bays,
			"peninsulas": peninsulas,
			"straits": straits,
			"archipelagos": archipelagos,
		},
		"land_region_count": land_count,
		"ocean_region_count": region_count - land_count,
	}


static func _terrain_score(root_seed: int, region_index: int, seed_face_id: int) -> int:
	var normalized_seed := posmod(root_seed, 2_147_483_646) + 1
	var mixed := int(
		(
			normalized_seed * 40_009
			+ (region_index + 1) * 65_537
			+ (seed_face_id + 1) * 97_409
		) % 2_147_483_647
	)
	return mixed % 100


static func _minimum_score_index(scores: Array) -> int:
	var best_index := 0
	for index in range(1, scores.size()):
		if int(scores[index]) < int(scores[best_index]):
			best_index = index
	return best_index


static func _maximum_score_index(scores: Array) -> int:
	var best_index := 0
	for index in range(1, scores.size()):
		if int(scores[index]) > int(scores[best_index]):
			best_index = index
	return best_index


static func _terrain_components(
	terrain_by_region: Array,
	adjacency_by_region: Array,
	target_terrain: String
) -> Array:
	var visited := {}
	var components: Array = []
	for start_index in range(terrain_by_region.size()):
		if str(terrain_by_region[start_index]) != target_terrain or visited.has(start_index):
			continue
		var component: Array = []
		var queue: Array = [start_index]
		visited[start_index] = true
		var cursor := 0
		while cursor < queue.size():
			var region_index := int(queue[cursor])
			cursor += 1
			component.append(region_index)
			for neighbor_variant in adjacency_by_region[region_index] as Array:
				var neighbor := int(neighbor_variant)
				if (
					str(terrain_by_region[neighbor]) == target_terrain
					and not visited.has(neighbor)
				):
					visited[neighbor] = true
					queue.append(neighbor)
		component.sort()
		components.append(component)
	components.sort_custom(func(left: Array, right: Array) -> bool:
		return int(left[0]) < int(right[0])
	)
	return components


static func _select_seed_faces(
	face_neighbors: Array,
	region_count: int,
	rng: Variant
) -> Dictionary:
	if face_neighbors.size() < region_count:
		return _failure("v076_partition_not_enough_faces_for_seeds")
	var seeds: Array = [int(rng.call("randi_range", 0, face_neighbors.size() - 1))]
	var reserved := {seeds[0]: true}
	while seeds.size() < region_count:
		var distances := _distance_from_seeds(face_neighbors, seeds)
		if distances.size() != face_neighbors.size():
			return _failure("v076_partition_seed_distance_failed")
		var tie_anchor := int(rng.call("randi_range", 0, face_neighbors.size() - 1))
		var best_face := -1
		var best_distance := -1
		var best_rank := face_neighbors.size() + 1
		for face_id in range(face_neighbors.size()):
			if reserved.has(face_id):
				continue
			var distance := int(distances[face_id])
			var rank := (face_id - tie_anchor + face_neighbors.size()) % face_neighbors.size()
			if distance > best_distance or (distance == best_distance and rank < best_rank):
				best_face = face_id
				best_distance = distance
				best_rank = rank
		if best_face < 0:
			return _failure("v076_partition_seed_selection_exhausted")
		reserved[best_face] = true
		seeds.append(best_face)
	return {"accepted": true, "reason": "", "seed_face_ids": seeds}


static func _distance_from_seeds(face_neighbors: Array, seeds: Array) -> Array:
	var distances: Array = []
	distances.resize(face_neighbors.size())
	distances.fill(-1)
	var queue: Array = []
	for seed_variant in seeds:
		var seed_face_id := int(seed_variant)
		if seed_face_id < 0 or seed_face_id >= face_neighbors.size() or int(distances[seed_face_id]) != -1:
			return []
		distances[seed_face_id] = 0
		queue.append(seed_face_id)
	var cursor := 0
	while cursor < queue.size():
		var face_id := int(queue[cursor])
		cursor += 1
		for neighbor_variant in face_neighbors[face_id] as Array:
			var neighbor := int(neighbor_variant)
			if neighbor < 0 or neighbor >= face_neighbors.size():
				return []
			if int(distances[neighbor]) == -1:
				distances[neighbor] = int(distances[face_id]) + 1
				queue.append(neighbor)
	return distances if queue.size() == face_neighbors.size() else []


static func _partition_faces(
	face_neighbors: Array,
	seed_faces: Array,
	root_seed: int,
	shape_complexity: String
) -> Dictionary:
	var owners: Array = []
	owners.resize(face_neighbors.size())
	owners.fill(-1)
	var heap: Array = []
	for owner_index in range(seed_faces.size()):
		_heap_push(heap, [0, owner_index, int(seed_faces[owner_index])])
	var assigned_count := 0
	while not heap.is_empty():
		var item := _heap_pop(heap)
		var cost := int(item[0])
		var owner := int(item[1])
		var face_id := int(item[2])
		if int(owners[face_id]) >= 0:
			continue
		owners[face_id] = owner
		assigned_count += 1
		for neighbor_variant in face_neighbors[face_id] as Array:
			var neighbor := int(neighbor_variant)
			if int(owners[neighbor]) < 0:
				var edge_cost := _authority_edge_cost(
					root_seed,
					shape_complexity,
					face_id,
					neighbor
				)
				_heap_push(heap, [cost + edge_cost, owner, neighbor])
	if assigned_count != face_neighbors.size():
		return _failure("v076_partition_face_assignment_incomplete")
	return {"accepted": true, "reason": "", "owner_by_face": owners}


static func _authority_edge_cost(
	root_seed: int,
	shape_complexity: String,
	face_a: int,
	face_b: int
) -> int:
	if shape_complexity == "SIMPLE":
		return 100
	var low := mini(face_a, face_b)
	var high := maxi(face_a, face_b)
	var normalized_seed := posmod(root_seed, 2_147_483_646) + 1
	var mixed := int(
		(
			normalized_seed * 48_271
			+ (low + 1) * 69_621
			+ (high + 1) * 104_729
		) % 2_147_483_647
	)
	if shape_complexity == "STANDARD":
		return 90 + (mixed % 21)
	if shape_complexity == "COMPLEX":
		return 25 + (mixed % 151)
	return 0


static func _canonical_boundary_cycles(
	boundary_half_edge_ids: Array,
	half_edges: Array
) -> Dictionary:
	if boundary_half_edge_ids.is_empty():
		return {"accepted": true, "reason": "", "cycles": []}
	var outgoing := {}
	var unused := {}
	for half_edge_variant in boundary_half_edge_ids:
		var half_edge_id := int(half_edge_variant)
		var row := half_edges[half_edge_id] as Dictionary
		var origin := int(row.get("origin_vertex_id", -1))
		if outgoing.has(origin):
			return _failure("v076_partition_boundary_vertex_ambiguous")
		outgoing[origin] = half_edge_id
		unused[half_edge_id] = true
	var cycles: Array = []
	while not unused.is_empty():
		var remaining: Array = unused.keys()
		remaining.sort()
		var start := int(remaining[0])
		var current := start
		var cycle: Array = []
		var guard := 0
		while guard <= boundary_half_edge_ids.size():
			guard += 1
			if not unused.has(current):
				if current == start:
					break
				return _failure("v076_partition_boundary_cycle_reused_edge")
			unused.erase(current)
			cycle.append(current)
			var row := half_edges[current] as Dictionary
			var destination := int(row.get("destination_vertex_id", -1))
			if not outgoing.has(destination):
				return _failure("v076_partition_boundary_cycle_open")
			current = int(outgoing[destination])
			if current == start:
				break
		if current != start or cycle.size() < 3:
			return _failure("v076_partition_boundary_cycle_invalid")
		cycles.append(cycle)
	cycles.sort_custom(func(left: Array, right: Array) -> bool:
		if int(left[0]) != int(right[0]):
			return int(left[0]) < int(right[0])
		return left.size() < right.size()
	)
	return {"accepted": true, "reason": "", "cycles": cycles}


static func _heap_push(heap: Array, item: Array) -> void:
	heap.append(item)
	var index := heap.size() - 1
	while index > 0:
		var parent := (index - 1) >> 1
		if not _heap_item_less(heap[index] as Array, heap[parent] as Array):
			break
		var swap: Variant = heap[index]
		heap[index] = heap[parent]
		heap[parent] = swap
		index = parent


static func _heap_pop(heap: Array) -> Array:
	var result := heap[0] as Array
	var last: Variant = heap.pop_back()
	if heap.is_empty():
		return result
	heap[0] = last
	var index := 0
	while true:
		var left := index * 2 + 1
		var right := left + 1
		var smallest := index
		if left < heap.size() and _heap_item_less(heap[left] as Array, heap[smallest] as Array):
			smallest = left
		if right < heap.size() and _heap_item_less(heap[right] as Array, heap[smallest] as Array):
			smallest = right
		if smallest == index:
			break
		var swap: Variant = heap[index]
		heap[index] = heap[smallest]
		heap[smallest] = swap
		index = smallest
	return result


static func _heap_item_less(left: Array, right: Array) -> bool:
	for index in range(3):
		if int(left[index]) != int(right[index]):
			return int(left[index]) < int(right[index])
	return false


static func _region_ids(region_count: int) -> Array:
	var result: Array = []
	for region_index in range(region_count):
		result.append("region.%02d" % region_index)
	return result


static func _failure(reason: String) -> Dictionary:
	return {"accepted": false, "reason": reason}
