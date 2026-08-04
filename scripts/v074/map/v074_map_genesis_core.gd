extends RefCounted
class_name V074MapGenesisCore

const Request := preload("res://scripts/v074/map/map_genesis_request_v1.gd")
const Receipt := preload("res://scripts/v074/map/map_genesis_receipt_v1.gd")
const GenesisRng := preload("res://scripts/v074/map/v074_map_genesis_rng.gd")
const Microgrid := preload("res://scripts/v074/map/v074_geodesic_microgrid.gd")

const CORE_AUTHORITY_ID := "v074.map_genesis.core_authority.v1"
const MAP_GENESIS_OWNER_COUNT := 1
const MAP_GENESIS_RNG_OWNER_COUNT := 1
const MAP_GENESIS_UI_OWNER_COUNT := 0
const MAP_GENESIS_PRESENTATION_OWNER_COUNT := 0
const MAP_GENESIS_GAMEPLAY_RNG_CROSS_DRAW_COUNT := 0
const PRESENTATION_RNG_GAMEPLAY_DRAW_DELTA := 0
const SOLAR_THRESHOLD := 0.0
const GOLDEN_ANGLE := PI * (3.0 - sqrt(5.0))
const FOUR_PI := 4.0 * PI
const SUBDIVISION_BY_COMPLEXITY := {
	"SIMPLE": 2,
	"STANDARD": 3,
	"COMPLEX": 4,
}
const ORGANIC_WEIGHT_BY_COMPLEXITY := {
	"SIMPLE": 0.08,
	"STANDARD": 0.24,
	"COMPLEX": 0.42,
}
const TERRAIN_ALIGNMENT_BY_COMPLEXITY := {
	"SIMPLE": 0.04,
	"STANDARD": 0.10,
	"COMPLEX": 0.16,
}
const LAND_RATIO_BY_PROFILE := {
	"CONTINENTAL": 0.68,
	"BALANCED": 0.52,
	"ARCHIPELAGO": 0.36,
}
const MINIMUM_REGION_AREA_RATIO := 0.006
const MAXIMUM_NEIGHBOR_COUNT := 14

static var _grid_cache: Dictionary = {}


static func generate(request: Dictionary) -> Dictionary:
	var normalized_result: Dictionary = Request.normalize(request)
	if not bool(normalized_result.get("accepted", false)):
		return Receipt.failure(
			str(normalized_result.get("reason_code", "map_genesis_request_invalid")),
			request
		)
	var normalized: Dictionary = normalized_result.get("request", {}) as Dictionary
	var complexity := str(normalized.get("geography_complexity", ""))
	var grid: Dictionary = _grid_for_complexity(complexity)
	if not bool(grid.get("accepted", false)):
		return Receipt.failure(
			str(grid.get("reason_code", "map_genesis_microgrid_invalid")),
			normalized
		)
	var rng := GenesisRng.new(
		int(normalized.get("map_seed", 0)),
		"map_genesis_rng|%s" % str(normalized.get("canonical_key", ""))
	)
	var terrain_field: Dictionary = _build_terrain_field(grid, normalized, rng)
	var partition: Dictionary = _partition_regions(grid, normalized, terrain_field, rng)
	if not bool(partition.get("accepted", false)):
		return Receipt.failure(
			str(partition.get("reason_code", "map_genesis_partition_failed")),
			normalized
		)
	var region_facts: Dictionary = _build_region_facts(
		grid,
		normalized,
		terrain_field,
		partition
	)
	var boundary_facts: Dictionary = _build_boundary_facts(
		grid,
		region_facts,
		partition
	)
	var slots: Dictionary = _build_facility_slot_registry(normalized)
	var sun_direction: Vector3 = rng.next_unit_vector()
	var microgrid_receipt := {
		"schema": str(grid.get("schema", "")),
		"subdivision": int(grid.get("subdivision", 0)),
		"grid_fingerprint": str(grid.get("grid_fingerprint", "")),
		"vertices_unit_sphere": (grid.get("vertices_unit_sphere", []) as Array).duplicate(true),
		"microcell_vertex_ids": (grid.get("microcell_vertex_ids", []) as Array).duplicate(true),
		"microcell_centers_unit_sphere": (grid.get("microcell_centers_unit_sphere", []) as Array).duplicate(true),
		"microcell_areas_steradians": (grid.get("microcell_areas_steradians", []) as Array).duplicate(),
		"microcell_adjacency": (grid.get("microcell_adjacency", []) as Array).duplicate(true),
		"microcell_elevation": (terrain_field.get("microcell_elevation", []) as Array).duplicate(),
		"region_index_by_microcell": (partition.get("region_index_by_microcell", []) as Array).duplicate(),
		"microcell_count": int(grid.get("microcell_count", 0)),
		"vertex_count": int(grid.get("vertex_count", 0)),
		"edge_count": int(grid.get("edge_count", 0)),
		"closed_edge_count": int(grid.get("closed_edge_count", 0)),
		"nonmanifold_edge_count": int(grid.get("nonmanifold_edge_count", 0)),
		"surface_area_steradians": float(grid.get("surface_area_steradians", 0.0)),
	}
	var receipt := {
		"schema_version": Receipt.SCHEMA_VERSION,
		"contract_id": Receipt.CONTRACT_ID,
		"ruleset_id": Request.RULESET_ID,
		"accepted": true,
		"reason_code": "map_genesis_completed",
		"authority_id": CORE_AUTHORITY_ID,
		"map_genesis_owner_count": MAP_GENESIS_OWNER_COUNT,
		"map_genesis_rng_owner_count": MAP_GENESIS_RNG_OWNER_COUNT,
		"map_genesis_ui_owner_count": MAP_GENESIS_UI_OWNER_COUNT,
		"map_genesis_presentation_owner_count": MAP_GENESIS_PRESENTATION_OWNER_COUNT,
		"map_genesis_gameplay_rng_cross_draw_count": MAP_GENESIS_GAMEPLAY_RNG_CROSS_DRAW_COUNT,
		"presentation_rng_gameplay_draw_delta": PRESENTATION_RNG_GAMEPLAY_DRAW_DELTA,
		"request": normalized.duplicate(true),
		"map_id": "",
		"map_seed": int(normalized.get("map_seed", 0)),
		"map_profile_id": str(normalized.get("map_profile_id", "")),
		"region_count": int(normalized.get("region_count", 0)),
		"region_ids": (region_facts.get("region_ids", []) as Array).duplicate(),
		"terrain_by_region": (region_facts.get("terrain_by_region", {}) as Dictionary).duplicate(true),
		"terrain_elevation_by_region": (region_facts.get("terrain_elevation_by_region", {}) as Dictionary).duplicate(true),
		"region_centers_unit_sphere": (region_facts.get("region_centers_unit_sphere", {}) as Dictionary).duplicate(true),
		"region_area_steradians": (region_facts.get("region_area_steradians", {}) as Dictionary).duplicate(true),
		"region_area_ratio": (region_facts.get("region_area_ratio", {}) as Dictionary).duplicate(true),
		"region_microcell_membership": (region_facts.get("region_microcell_membership", {}) as Dictionary).duplicate(true),
		"microcell_centers_unit_sphere": (grid.get("microcell_centers_unit_sphere", []) as Array).duplicate(true),
		"region_boundaries_spherical": (boundary_facts.get("region_boundaries_spherical", {}) as Dictionary).duplicate(true),
		"region_boundary_lods_spherical": (boundary_facts.get("region_boundary_lods_spherical", {}) as Dictionary).duplicate(true),
		"shared_boundary_edges": (boundary_facts.get("shared_boundary_edges", []) as Array).duplicate(true),
		"adjacency_graph": (boundary_facts.get("adjacency_graph", {}) as Dictionary).duplicate(true),
		"land_ocean_edges": (boundary_facts.get("land_ocean_edges", []) as Array).duplicate(),
		"facility_slot_registry": slots.duplicate(true),
		"facility_slot_count_per_region": (
			(normalized.get("registered_facility_types", []) as Array).size()
			* (normalized.get("industry_ids", []) as Array).size()
		),
		"initial_sun_direction": sun_direction,
		"solar_threshold": SOLAR_THRESHOLD,
		"microgrid": microgrid_receipt,
		"map_genesis_rng": rng.snapshot(),
		"map_fingerprint": "",
	}
	receipt["solar_by_region"] = geometric_solar_by_region(receipt, sun_direction)
	receipt["map_fingerprint"] = replay_fingerprint(receipt)
	receipt["map_id"] = "map.%s" % str(receipt["map_fingerprint"]).substr(0, 16)
	var report := validation_report(receipt)
	receipt["validation_summary"] = report
	if not bool(report.get("valid", false)):
		receipt["accepted"] = false
		receipt["reason_code"] = str(report.get("reason_code", "map_genesis_validation_failed"))
	return receipt


static func validation_report(receipt: Dictionary) -> Dictionary:
	var contract_report: Dictionary = Receipt.validate(receipt)
	if not bool(contract_report.get("valid", false)):
		return contract_report
	var topology: Dictionary = _validate_topology(receipt)
	var geometry: Dictionary = _validate_geometry(receipt)
	var facilities: Dictionary = _validate_facility_slots(receipt)
	var errors: Array[String] = []
	for report in [topology, geometry, facilities]:
		for error_variant in (report as Dictionary).get("errors", []) as Array:
			errors.append(str(error_variant))
	var result := {
		"valid": errors.is_empty(),
		"error_count": errors.size(),
		"errors": errors,
		"reason_code": "map_genesis_receipt_valid" if errors.is_empty() else errors[0],
		"region_count": int(receipt.get("region_count", 0)),
		"global_region_adjacency_component_count": int(topology.get("global_region_adjacency_component_count", 0)),
		"disconnected_region_count": int(topology.get("disconnected_region_count", 0)),
		"isolated_region_count": int(topology.get("isolated_region_count", 0)),
		"self_adjacency_count": int(topology.get("self_adjacency_count", 0)),
		"duplicate_adjacency_edge_count": int(topology.get("duplicate_adjacency_edge_count", 0)),
		"asymmetric_adjacency_count": int(topology.get("asymmetric_adjacency_count", 0)),
		"land_region_count": int(topology.get("land_region_count", 0)),
		"ocean_region_count": int(topology.get("ocean_region_count", 0)),
		"land_ocean_boundary_edge_count": int(topology.get("land_ocean_boundary_edge_count", 0)),
		"triangle_region_count": int(geometry.get("triangle_region_count", 0)),
		"quadrilateral_region_count": int(geometry.get("quadrilateral_region_count", 0)),
		"median_boundary_vertex_count": int(geometry.get("median_boundary_vertex_count", 0)),
		"near_boundary_loop_min_vertex_count": int(geometry.get("near_boundary_loop_min_vertex_count", 0)),
		"invalid_ordered_boundary_loop_count": int(geometry.get("invalid_ordered_boundary_loop_count", 0)),
		"concave_region_ratio": float(geometry.get("concave_region_ratio", 0.0)),
		"region_boundary_self_intersection_count": int(geometry.get("region_boundary_self_intersection_count", 0)),
		"region_boundary_gap_count": int(geometry.get("region_boundary_gap_count", 0)),
		"region_boundary_overlap_count": int(geometry.get("region_boundary_overlap_count", 0)),
		"region_sliver_count": int(geometry.get("region_sliver_count", 0)),
		"sphere_coverage_error_ratio": float(geometry.get("sphere_coverage_error_ratio", 1.0)),
		"geometry_nonfinite_count": int(geometry.get("geometry_nonfinite_count", 0)),
		"facility_slot_expected_count": int(facilities.get("facility_slot_expected_count", 0)),
		"facility_slot_actual_count": int(facilities.get("facility_slot_actual_count", 0)),
		"facility_slot_duplicate_key_count": int(facilities.get("facility_slot_duplicate_key_count", 0)),
		"facility_slot_reference_failure_count": int(facilities.get("facility_slot_reference_failure_count", 0)),
	}
	return result


static func replay_fingerprint(receipt: Dictionary) -> String:
	var rows := PackedStringArray()
	var request: Dictionary = receipt.get("request", {}) as Dictionary
	rows.append(str(request.get("canonical_key", "")))
	var microgrid: Dictionary = receipt.get("microgrid", {}) as Dictionary
	rows.append(str(microgrid.get("grid_fingerprint", "")))
	for owner_variant in microgrid.get("region_index_by_microcell", []) as Array:
		rows.append(str(int(owner_variant)))
	var region_ids: Array = receipt.get("region_ids", []) as Array
	var terrain: Dictionary = receipt.get("terrain_by_region", {}) as Dictionary
	var centers: Dictionary = receipt.get("region_centers_unit_sphere", {}) as Dictionary
	var adjacency: Dictionary = receipt.get("adjacency_graph", {}) as Dictionary
	for region_variant in region_ids:
		var region_id := str(region_variant)
		var center: Vector3 = centers.get(region_id, Vector3.ZERO) as Vector3
		var neighbors := PackedStringArray()
		for neighbor_variant in adjacency.get(region_id, []) as Array:
			neighbors.append(str(neighbor_variant))
		rows.append("%s|%s|%d,%d,%d|%s" % [
			region_id,
			str(terrain.get(region_id, "")),
			roundi(center.x * 1000000000.0),
			roundi(center.y * 1000000000.0),
			roundi(center.z * 1000000000.0),
			",".join(neighbors),
		])
	for edge_variant in receipt.get("shared_boundary_edges", []) as Array:
		var edge := edge_variant as Dictionary
		var vertex_ids: Array = edge.get("vertex_ids", []) as Array
		rows.append("%s|%s|%s|%d,%d" % [
			str(edge.get("boundary_id", "")),
			str(edge.get("region_a", "")),
			str(edge.get("region_b", "")),
			int(vertex_ids[0]),
			int(vertex_ids[1]),
		])
	var slot_ids := PackedStringArray()
	for slot_id_variant in (receipt.get("facility_slot_registry", {}) as Dictionary).keys():
		slot_ids.append(str(slot_id_variant))
	slot_ids.sort()
	rows.append("|".join(slot_ids))
	var sun: Vector3 = receipt.get("initial_sun_direction", Vector3.ZERO) as Vector3
	rows.append("%d,%d,%d" % [
		roundi(sun.x * 1000000000.0),
		roundi(sun.y * 1000000000.0),
		roundi(sun.z * 1000000000.0),
	])
	return "\n".join(rows).sha256_text()


static func geometric_solar_by_region(
	receipt: Dictionary,
	sun_direction: Vector3
) -> Dictionary:
	if not sun_direction.is_normalized():
		sun_direction = sun_direction.normalized()
	if sun_direction.is_zero_approx():
		return {}
	var result := {}
	var centers: Dictionary = receipt.get("region_centers_unit_sphere", {}) as Dictionary
	var threshold := float(receipt.get("solar_threshold", SOLAR_THRESHOLD))
	for region_variant in receipt.get("region_ids", []) as Array:
		var region_id := str(region_variant)
		var normal: Vector3 = centers.get(region_id, Vector3.ZERO) as Vector3
		var exposure := normal.normalized().dot(sun_direction)
		result[region_id] = {
			"region_id": region_id,
			"solar_state": "sunlit" if exposure > threshold else "dark",
			"surface_dot_sun": exposure,
			"efficiency_multiplier": 2.0 if exposure > threshold else 1.0,
		}
	return result


static func clear_grid_cache() -> void:
	_grid_cache.clear()


static func _grid_for_complexity(complexity: String) -> Dictionary:
	var subdivision := int(SUBDIVISION_BY_COMPLEXITY.get(complexity, 0))
	if not _grid_cache.has(subdivision):
		_grid_cache[subdivision] = Microgrid.build(subdivision)
	return _grid_cache[subdivision] as Dictionary


static func _build_terrain_field(
	grid: Dictionary,
	request: Dictionary,
	rng
) -> Dictionary:
	var complexity := str(request.get("geography_complexity", "STANDARD"))
	var frequencies: Array[float] = []
	match complexity:
		"SIMPLE":
			frequencies = [1.15, 1.90, 2.70]
		"COMPLEX":
			frequencies = [1.55, 2.85, 4.60, 6.20]
		_:
			frequencies = [1.35, 2.35, 3.65, 4.80]
	var axes: Array = []
	var phases: Array[float] = []
	for _index in range(frequencies.size()):
		axes.append(rng.next_unit_vector())
		phases.append(rng.next_unit() * TAU)
	var elevations: Array[float] = []
	for center_variant in grid.get("microcell_centers_unit_sphere", []) as Array:
		var center := center_variant as Vector3
		var value := 0.0
		var total_weight := 0.0
		for index in range(frequencies.size()):
			var weight := pow(0.56, float(index))
			var axis := axes[index] as Vector3
			var coordinate := center.dot(axis) * PI * frequencies[index] + phases[index]
			value += sin(coordinate) * weight
			total_weight += weight
		var ridge_axis := axes[0] as Vector3
		value += 0.18 * cos(center.cross(ridge_axis).length() * PI * frequencies[0] * 1.7 + phases[0])
		elevations.append(value / maxf(0.000001, total_weight + 0.18))
	return {
		"microcell_elevation": elevations,
		"frequencies": frequencies,
		"axes": axes,
		"phases": phases,
	}


static func _partition_regions(
	grid: Dictionary,
	request: Dictionary,
	terrain_field: Dictionary,
	rng
) -> Dictionary:
	var face_count := int(grid.get("microcell_count", 0))
	var region_count := int(request.get("region_count", 0))
	var centers: Array = grid.get("microcell_centers_unit_sphere", []) as Array
	var adjacency: Array = grid.get("microcell_adjacency", []) as Array
	var elevations: Array = terrain_field.get("microcell_elevation", []) as Array
	if face_count <= 0 or centers.size() != face_count or adjacency.size() != face_count 			or elevations.size() != face_count or region_count <= 0:
		return {
			"accepted": false,
			"reason_code": "map_genesis_partition_input_invalid",
		}
	var seed_faces: Array[int] = _build_seed_faces(centers, region_count, rng)
	if seed_faces.size() != region_count:
		return {
			"accepted": false,
			"reason_code": "map_genesis_region_seed_failure",
		}
	var owner_axes: Array = []
	var owner_phases: Array[float] = []
	for _index in range(region_count):
		owner_axes.append(rng.next_unit_vector())
		owner_phases.append(rng.next_unit() * TAU)
	var owners: Array[int] = []
	owners.resize(face_count)
	owners.fill(-1)
	var heap := {
		"costs": [],
		"faces": [],
		"owners": [],
	}
	for owner_index in range(region_count):
		_heap_push(
			heap,
			float(owner_index) * 0.000000001,
			seed_faces[owner_index],
			owner_index
		)
	var complexity := str(request.get("geography_complexity", "STANDARD"))
	var organic_weight := float(ORGANIC_WEIGHT_BY_COMPLEXITY.get(complexity, 0.0))
	var terrain_weight := float(TERRAIN_ALIGNMENT_BY_COMPLEXITY.get(complexity, 0.0))
	var organic_frequency := 2.2
	if complexity == "STANDARD":
		organic_frequency = 3.7
	elif complexity == "COMPLEX":
		organic_frequency = 5.4
	var assigned_count := 0
	while not (heap.get("costs", []) as Array).is_empty():
		var item: Dictionary = _heap_pop(heap)
		var face_index := int(item.get("face", -1))
		var owner_index := int(item.get("owner", -1))
		if face_index < 0 or face_index >= face_count or owner_index < 0 				or owner_index >= region_count or owners[face_index] >= 0:
			continue
		owners[face_index] = owner_index
		assigned_count += 1
		var base_cost := float(item.get("cost", 0.0))
		for neighbor_variant in adjacency[face_index] as Array:
			var neighbor := int(neighbor_variant)
			if neighbor < 0 or neighbor >= face_count or owners[neighbor] >= 0:
				continue
			var midpoint := ((centers[face_index] as Vector3) + (centers[neighbor] as Vector3)).normalized()
			var owner_axis := owner_axes[owner_index] as Vector3
			var wave := 0.5 + 0.5 * sin(
				midpoint.dot(owner_axis) * PI * organic_frequency
				+ owner_phases[owner_index]
			)
			var terrain_delta := absf(float(elevations[face_index]) - float(elevations[neighbor]))
			var edge_cost := 1.0 + organic_weight * wave + terrain_weight * terrain_delta
			_heap_push(
				heap,
				base_cost + edge_cost,
				neighbor,
				owner_index
			)
	if assigned_count != face_count:
		return {
			"accepted": false,
			"reason_code": "map_genesis_partition_incomplete",
			"assigned_count": assigned_count,
			"microcell_count": face_count,
		}
	return {
		"accepted": true,
		"reason_code": "map_genesis_partition_ready",
		"region_index_by_microcell": owners,
		"region_seed_microcells": seed_faces,
	}


static func _build_seed_faces(
	centers: Array,
	region_count: int,
	rng
) -> Array[int]:
	var result: Array[int] = []
	var reserved := {}
	var rotation_axis: Vector3 = rng.next_unit_vector()
	var rotation_angle: float = rng.next_unit() * TAU
	var rotation := Basis(rotation_axis, rotation_angle)
	var longitude_phase: float = rng.next_unit() * TAU
	for index in range(region_count):
		var z := 1.0 - 2.0 * (float(index) + 0.5) / float(region_count)
		var radial := sqrt(maxf(0.0, 1.0 - z * z))
		var angle := float(index) * GOLDEN_ANGLE + longitude_phase
		var base := Vector3(radial * cos(angle), z, radial * sin(angle))
		var jitter_axis: Vector3 = rng.next_unit_vector()
		var jitter_angle: float = rng.next_signed() * 0.035
		var desired := (rotation * (Basis(jitter_axis, jitter_angle) * base)).normalized()
		var nearest := _nearest_unreserved_face(centers, desired, reserved)
		if nearest < 0:
			return []
		reserved[nearest] = true
		result.append(nearest)
	return result


static func _nearest_unreserved_face(
	centers: Array,
	desired: Vector3,
	reserved: Dictionary
) -> int:
	var best_index := -1
	var best_dot := -INF
	for index in range(centers.size()):
		if reserved.has(index):
			continue
		var candidate := centers[index] as Vector3
		var candidate_dot := desired.dot(candidate)
		if candidate_dot > best_dot + 0.000000000001:
			best_dot = candidate_dot
			best_index = index
		elif is_equal_approx(candidate_dot, best_dot) and index < best_index:
			best_index = index
	return best_index


static func _heap_push(
	heap: Dictionary,
	cost: float,
	face_index: int,
	owner_index: int
) -> void:
	var costs: Array = heap.get("costs", []) as Array
	var faces: Array = heap.get("faces", []) as Array
	var owners: Array = heap.get("owners", []) as Array
	costs.append(cost)
	faces.append(face_index)
	owners.append(owner_index)
	var index := costs.size() - 1
	while index > 0:
		var parent := (index - 1) / 2
		if not _heap_less(costs, faces, owners, index, parent):
			break
		_heap_swap(costs, faces, owners, index, parent)
		index = parent


static func _heap_pop(heap: Dictionary) -> Dictionary:
	var costs: Array = heap.get("costs", []) as Array
	var faces: Array = heap.get("faces", []) as Array
	var owners: Array = heap.get("owners", []) as Array
	if costs.is_empty():
		return {}
	var result := {
		"cost": float(costs[0]),
		"face": int(faces[0]),
		"owner": int(owners[0]),
	}
	var last := costs.size() - 1
	costs[0] = costs[last]
	faces[0] = faces[last]
	owners[0] = owners[last]
	costs.pop_back()
	faces.pop_back()
	owners.pop_back()
	var index := 0
	while true:
		var left := index * 2 + 1
		var right := left + 1
		var smallest := index
		if left < costs.size() and _heap_less(costs, faces, owners, left, smallest):
			smallest = left
		if right < costs.size() and _heap_less(costs, faces, owners, right, smallest):
			smallest = right
		if smallest == index:
			break
		_heap_swap(costs, faces, owners, index, smallest)
		index = smallest
	return result


static func _heap_less(
	costs: Array,
	faces: Array,
	owners: Array,
	left: int,
	right: int
) -> bool:
	var left_cost := float(costs[left])
	var right_cost := float(costs[right])
	if not is_equal_approx(left_cost, right_cost):
		return left_cost < right_cost
	var left_owner := int(owners[left])
	var right_owner := int(owners[right])
	if left_owner != right_owner:
		return left_owner < right_owner
	return int(faces[left]) < int(faces[right])


static func _heap_swap(
	costs: Array,
	faces: Array,
	owners: Array,
	left: int,
	right: int
) -> void:
	var cost_value: Variant = costs[left]
	costs[left] = costs[right]
	costs[right] = cost_value
	var face_value: Variant = faces[left]
	faces[left] = faces[right]
	faces[right] = face_value
	var owner_value: Variant = owners[left]
	owners[left] = owners[right]
	owners[right] = owner_value

static func _build_region_facts(
	grid: Dictionary,
	request: Dictionary,
	terrain_field: Dictionary,
	partition: Dictionary
) -> Dictionary:
	var region_count := int(request.get("region_count", 0))
	var region_ids: Array[String] = []
	var membership := {}
	var center_accumulators: Array[Vector3] = []
	var area_accumulators: Array[float] = []
	var elevation_accumulators: Array[float] = []
	for index in range(region_count):
		var region_id := _region_id(index)
		region_ids.append(region_id)
		membership[region_id] = []
		center_accumulators.append(Vector3.ZERO)
		area_accumulators.append(0.0)
		elevation_accumulators.append(0.0)
	var owners: Array = partition.get("region_index_by_microcell", []) as Array
	var centers: Array = grid.get("microcell_centers_unit_sphere", []) as Array
	var areas: Array = grid.get("microcell_areas_steradians", []) as Array
	var elevations: Array = terrain_field.get("microcell_elevation", []) as Array
	for face_index in range(owners.size()):
		var owner_index := int(owners[face_index])
		var region_id := region_ids[owner_index]
		(membership[region_id] as Array).append(face_index)
		var area := float(areas[face_index])
		center_accumulators[owner_index] += (centers[face_index] as Vector3) * area
		area_accumulators[owner_index] += area
		elevation_accumulators[owner_index] += float(elevations[face_index]) * area
	var region_centers := {}
	var region_areas := {}
	var region_area_ratios := {}
	var region_elevations := {}
	var terrain_rank_rows: Array[Dictionary] = []
	for index in range(region_count):
		var region_id := region_ids[index]
		var area := area_accumulators[index]
		var center := center_accumulators[index].normalized()
		var average_elevation := elevation_accumulators[index] / maxf(0.000000000001, area)
		region_centers[region_id] = center
		region_areas[region_id] = area
		region_area_ratios[region_id] = area / FOUR_PI
		region_elevations[region_id] = average_elevation
		terrain_rank_rows.append({
			"region_id": region_id,
			"elevation": average_elevation,
		})
	terrain_rank_rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_value := float(left.get("elevation", 0.0))
		var right_value := float(right.get("elevation", 0.0))
		if not is_equal_approx(left_value, right_value):
			return left_value > right_value
		return str(left.get("region_id", "")) < str(right.get("region_id", ""))
	)
	var target_ratio := float(LAND_RATIO_BY_PROFILE.get(
		str(request.get("land_ocean_profile", "BALANCED")),
		0.52
	))
	var land_count := clampi(roundi(float(region_count) * target_ratio), 1, region_count - 1)
	var land_ids := {}
	for index in range(land_count):
		land_ids[str(terrain_rank_rows[index].get("region_id", ""))] = true
	var terrain_by_region := {}
	for region_id in region_ids:
		terrain_by_region[region_id] = "land" if land_ids.has(region_id) else "ocean"
	return {
		"region_ids": region_ids,
		"terrain_by_region": terrain_by_region,
		"terrain_elevation_by_region": region_elevations,
		"region_centers_unit_sphere": region_centers,
		"region_area_steradians": region_areas,
		"region_area_ratio": region_area_ratios,
		"region_microcell_membership": membership,
	}


static func _build_boundary_facts(
	grid: Dictionary,
	region_facts: Dictionary,
	partition: Dictionary
) -> Dictionary:
	var region_ids: Array = region_facts.get("region_ids", []) as Array
	var terrain: Dictionary = region_facts.get("terrain_by_region", {}) as Dictionary
	var owners: Array = partition.get("region_index_by_microcell", []) as Array
	var edge_faces: Dictionary = grid.get("edge_faces", {}) as Dictionary
	var edge_vertex_ids: Dictionary = grid.get("edge_vertex_ids", {}) as Dictionary
	var vertices: Array = grid.get("vertices_unit_sphere", []) as Array
	var adjacency_sets := {}
	var boundary_ids_by_region := {}
	var boundary_vertices_by_region := {}
	var boundary_pairs_by_region := {}
	for region_variant in region_ids:
		var region_id := str(region_variant)
		adjacency_sets[region_id] = {}
		boundary_ids_by_region[region_id] = []
		boundary_vertices_by_region[region_id] = {}
		boundary_pairs_by_region[region_id] = []
	var edge_keys := PackedStringArray()
	for key_variant in edge_faces.keys():
		edge_keys.append(str(key_variant))
	edge_keys.sort()
	var shared_boundaries: Array = []
	var land_ocean_edges: Array[String] = []
	for edge_key in edge_keys:
		var incident: Array = edge_faces.get(edge_key, []) as Array
		if incident.size() != 2:
			continue
		var left_owner := int(owners[int(incident[0])])
		var right_owner := int(owners[int(incident[1])])
		if left_owner == right_owner:
			continue
		var left_region := str(region_ids[left_owner])
		var right_region := str(region_ids[right_owner])
		var region_a: String = left_region if left_region < right_region else right_region
		var region_b: String = right_region if left_region < right_region else left_region
		var vertex_ids: Array = (edge_vertex_ids.get(edge_key, []) as Array).duplicate()
		var boundary_id := "boundary.%06d" % shared_boundaries.size()
		var boundary := {
			"boundary_id": boundary_id,
			"mesh_edge_key": edge_key,
			"region_a": region_a,
			"region_b": region_b,
			"vertex_ids": vertex_ids,
			"points_unit_sphere": [
				vertices[int(vertex_ids[0])],
				vertices[int(vertex_ids[1])],
			],
		}
		shared_boundaries.append(boundary)
		(boundary_ids_by_region[left_region] as Array).append(boundary_id)
		(boundary_ids_by_region[right_region] as Array).append(boundary_id)
		(boundary_pairs_by_region[left_region] as Array).append(vertex_ids.duplicate())
		(boundary_pairs_by_region[right_region] as Array).append(vertex_ids.duplicate())
		(boundary_vertices_by_region[left_region] as Dictionary)[int(vertex_ids[0])] = true
		(boundary_vertices_by_region[left_region] as Dictionary)[int(vertex_ids[1])] = true
		(boundary_vertices_by_region[right_region] as Dictionary)[int(vertex_ids[0])] = true
		(boundary_vertices_by_region[right_region] as Dictionary)[int(vertex_ids[1])] = true
		(adjacency_sets[left_region] as Dictionary)[right_region] = true
		(adjacency_sets[right_region] as Dictionary)[left_region] = true
		if str(terrain.get(left_region, "")) != str(terrain.get(right_region, "")):
			land_ocean_edges.append(boundary_id)
	var adjacency_graph := {}
	var region_boundaries := {}
	var region_boundary_lods := {}
	for region_variant in region_ids:
		var region_id := str(region_variant)
		var neighbors := PackedStringArray()
		for neighbor_variant in (adjacency_sets[region_id] as Dictionary).keys():
			neighbors.append(str(neighbor_variant))
		neighbors.sort()
		adjacency_graph[region_id] = Array(neighbors)
		var near_ids: Array = (boundary_ids_by_region[region_id] as Array).duplicate()
		near_ids.sort()
		var vertex_ids: Array = (boundary_vertices_by_region[region_id] as Dictionary).keys()
		vertex_ids.sort()
		var ordered_vertex_loops: Array = _ordered_boundary_vertex_loops(
			boundary_pairs_by_region[region_id] as Array
		)
		var near_loops := _vector_loops(ordered_vertex_loops, vertices, 1)
		var medium_loops := _vector_loops(ordered_vertex_loops, vertices, 2)
		var far_loops := _vector_loops(ordered_vertex_loops, vertices, 4)
		var lods := {
			"near": near_loops,
			"medium": medium_loops,
			"far": far_loops,
		}
		region_boundary_lods[region_id] = lods
		region_boundaries[region_id] = {
			"shared_boundary_edge_ids": near_ids,
			"boundary_edge_id_lods": {
				"near": near_ids.duplicate(),
				"medium": _decimate_ids(near_ids, 2),
				"far": _decimate_ids(near_ids, 4),
			},
			"ordered_boundary_vertex_loops": ordered_vertex_loops,
			"boundary_lods_spherical": lods,
			"boundary_vertex_ids": vertex_ids,
			"boundary_vertex_count": vertex_ids.size(),
		}
	return {
		"shared_boundary_edges": shared_boundaries,
		"region_boundaries_spherical": region_boundaries,
		"region_boundary_lods_spherical": region_boundary_lods,
		"adjacency_graph": adjacency_graph,
		"land_ocean_edges": land_ocean_edges,
	}


static func _ordered_boundary_vertex_loops(boundary_pairs: Array) -> Array:
	var adjacency := {}
	var unused := {}
	for pair_variant in boundary_pairs:
		var pair := pair_variant as Array
		if pair.size() != 2:
			return []
		var left := int(pair[0])
		var right := int(pair[1])
		var key := _vertex_edge_key(left, right)
		unused[key] = true
		if not adjacency.has(left):
			adjacency[left] = []
		if not adjacency.has(right):
			adjacency[right] = []
		if not (adjacency[left] as Array).has(right):
			(adjacency[left] as Array).append(right)
		if not (adjacency[right] as Array).has(left):
			(adjacency[right] as Array).append(left)
	for vertex_variant in adjacency.keys():
		(adjacency[vertex_variant] as Array).sort()
	var loops: Array = []
	while not unused.is_empty():
		var keys := PackedStringArray()
		for key_variant in unused.keys():
			keys.append(str(key_variant))
		keys.sort()
		var parts := keys[0].split(":")
		if parts.size() != 2:
			return []
		var start := mini(int(parts[0]), int(parts[1]))
		var current := start
		var previous := -1
		var loop: Array[int] = [start]
		var closed := false
		var guard := 0
		while guard <= boundary_pairs.size() + 1:
			guard += 1
			var next_vertex := -1
			var candidates: Array = adjacency.get(current, []) as Array
			for candidate_variant in candidates:
				var candidate := int(candidate_variant)
				var edge_key := _vertex_edge_key(current, candidate)
				if unused.has(edge_key) and (candidate != previous or candidates.size() == 1):
					next_vertex = candidate
					break
			if next_vertex < 0:
				break
			unused.erase(_vertex_edge_key(current, next_vertex))
			previous = current
			current = next_vertex
			if current == start:
				closed = true
				break
			loop.append(current)
		if not closed:
			return []
		loops.append(loop)
	loops.sort_custom(func(left: Array, right: Array) -> bool:
		if left.size() != right.size():
			return left.size() > right.size()
		return int(left[0]) < int(right[0])
	)
	return loops


static func _vector_loops(
	vertex_loops: Array,
	vertices: Array,
	stride: int
) -> Array:
	var result: Array = []
	for loop_variant in vertex_loops:
		var loop := loop_variant as Array
		var simplified: Array = _simplify_ordered_loop(loop, stride)
		var points: Array[Vector3] = []
		for vertex_id_variant in simplified:
			points.append(vertices[int(vertex_id_variant)] as Vector3)
		result.append(points)
	return result


static func _simplify_ordered_loop(source: Array, stride: int) -> Array:
	if stride <= 1 or source.size() <= 5:
		return source.duplicate()
	var target_count := maxi(5, ceili(float(source.size()) / float(stride)))
	target_count = mini(target_count, source.size())
	var result: Array = []
	for index in range(target_count):
		var source_index := floori(float(index) * float(source.size()) / float(target_count))
		if result.is_empty() or result.back() != source[source_index]:
			result.append(source[source_index])
	return result


static func _vertex_edge_key(left: int, right: int) -> String:
	return "%d:%d" % [mini(left, right), maxi(left, right)]


static func _build_facility_slot_registry(request: Dictionary) -> Dictionary:
	var slots := {}
	var region_count := int(request.get("region_count", 0))
	var facility_types: Array = request.get("registered_facility_types", []) as Array
	var industries: Array = request.get("industry_ids", []) as Array
	for region_index in range(region_count):
		var region_id := _region_id(region_index)
		for facility_variant in facility_types:
			var facility_type := str(facility_variant)
			for industry_variant in industries:
				var industry_id := str(industry_variant)
				var slot_id := "slot.%s.%s.%s" % [
					region_id,
					facility_type,
					industry_id,
				]
				slots[slot_id] = {
					"slot_id": slot_id,
					"region_id": region_id,
					"region_revision": 1,
					"facility_type": facility_type,
					"industry_id": industry_id,
					"slot_generation": 0,
					"occupancy": "empty",
					"facility_id": null,
					"facility_generation": null,
					"owner_id": null,
					"rank": null,
					"damage_revision": null,
					"damage_points": null,
				}
	return slots


static func _decimate_ids(source: Array, stride: int) -> Array:
	if stride <= 1 or source.size() <= 6:
		return source.duplicate()
	var result: Array = []
	for index in range(0, source.size(), stride):
		result.append(source[index])
	if result.back() != source.back():
		result.append(source.back())
	return result


static func _region_id(index: int) -> String:
	return "region.%03d" % index

static func _validate_topology(receipt: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var region_ids: Array = receipt.get("region_ids", []) as Array
	var adjacency: Dictionary = receipt.get("adjacency_graph", {}) as Dictionary
	var terrain: Dictionary = receipt.get("terrain_by_region", {}) as Dictionary
	var isolated_count := 0
	var self_count := 0
	var duplicate_count := 0
	var asymmetric_count := 0
	var max_neighbor_count := 0
	for region_variant in region_ids:
		var region_id := str(region_variant)
		var neighbors: Array = adjacency.get(region_id, []) as Array
		max_neighbor_count = maxi(max_neighbor_count, neighbors.size())
		if neighbors.is_empty():
			isolated_count += 1
		var seen := {}
		for neighbor_variant in neighbors:
			var neighbor := str(neighbor_variant)
			if neighbor == region_id:
				self_count += 1
			if seen.has(neighbor):
				duplicate_count += 1
			seen[neighbor] = true
			if not (adjacency.get(neighbor, []) as Array).has(region_id):
				asymmetric_count += 1
	var graph_components := _graph_component_count(region_ids, adjacency)
	var disconnected_regions := _disconnected_region_count(receipt)
	var land_count := 0
	var ocean_count := 0
	for region_variant in region_ids:
		var terrain_class := str(terrain.get(str(region_variant), ""))
		if terrain_class == "land":
			land_count += 1
		elif terrain_class == "ocean":
			ocean_count += 1
		else:
			errors.append("map_genesis_terrain_class_invalid")
	if graph_components != 1:
		errors.append("map_genesis_global_adjacency_disconnected")
	if disconnected_regions != 0:
		errors.append("map_genesis_region_microcells_disconnected")
	if isolated_count != 0:
		errors.append("map_genesis_isolated_region")
	if self_count != 0:
		errors.append("map_genesis_self_adjacency")
	if duplicate_count != 0:
		errors.append("map_genesis_duplicate_adjacency")
	if asymmetric_count != 0:
		errors.append("map_genesis_asymmetric_adjacency")
	if max_neighbor_count > MAXIMUM_NEIGHBOR_COUNT:
		errors.append("map_genesis_neighbor_count_exceeds_default")
	if land_count == 0:
		errors.append("map_genesis_landless")
	if ocean_count == 0:
		errors.append("map_genesis_oceanless")
	var land_ocean_edge_count := (receipt.get("land_ocean_edges", []) as Array).size()
	if land_ocean_edge_count == 0:
		errors.append("map_genesis_land_ocean_boundary_missing")
	return {
		"errors": errors,
		"global_region_adjacency_component_count": graph_components,
		"disconnected_region_count": disconnected_regions,
		"isolated_region_count": isolated_count,
		"self_adjacency_count": self_count,
		"duplicate_adjacency_edge_count": duplicate_count,
		"asymmetric_adjacency_count": asymmetric_count,
		"maximum_neighbor_count": max_neighbor_count,
		"land_region_count": land_count,
		"ocean_region_count": ocean_count,
		"land_ocean_boundary_edge_count": land_ocean_edge_count,
	}


static func _validate_geometry(receipt: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var region_ids: Array = receipt.get("region_ids", []) as Array
	var microgrid: Dictionary = receipt.get("microgrid", {}) as Dictionary
	var microcell_count := int(microgrid.get("microcell_count", 0))
	var membership: Dictionary = receipt.get("region_microcell_membership", {}) as Dictionary
	var seen: Array[int] = []
	seen.resize(microcell_count)
	seen.fill(0)
	var overlap_count := 0
	for region_variant in region_ids:
		var region_id := str(region_variant)
		for face_variant in membership.get(region_id, []) as Array:
			var face_index := int(face_variant)
			if face_index < 0 or face_index >= microcell_count:
				overlap_count += 1
				continue
			seen[face_index] += 1
			if seen[face_index] > 1:
				overlap_count += 1
	var gap_count := 0
	for count in seen:
		if count == 0:
			gap_count += 1
	var boundary_rows: Dictionary = receipt.get("region_boundaries_spherical", {}) as Dictionary
	var boundary_counts: Array[int] = []
	var triangle_count := 0
	var quadrilateral_count := 0
	var near_loop_min_vertex_count := 2147483647
	var invalid_ordered_loop_count := 0
	var lod_rows: Dictionary = receipt.get("region_boundary_lods_spherical", {}) as Dictionary
	for region_variant in region_ids:
		var region_id := str(region_variant)
		var boundary: Dictionary = boundary_rows.get(region_id, {}) as Dictionary
		var count := int(boundary.get("boundary_vertex_count", 0))
		boundary_counts.append(count)
		if count == 3:
			triangle_count += 1
		elif count == 4:
			quadrilateral_count += 1
		var region_lods: Dictionary = lod_rows.get(region_id, {}) as Dictionary
		var near_loops: Array = region_lods.get("near", []) as Array
		if near_loops.is_empty():
			invalid_ordered_loop_count += 1
		for loop_variant in near_loops:
			var loop := loop_variant as Array
			near_loop_min_vertex_count = mini(near_loop_min_vertex_count, loop.size())
			if loop.size() < 5:
				invalid_ordered_loop_count += 1
	if near_loop_min_vertex_count == 2147483647:
		near_loop_min_vertex_count = 0
	var median_boundary_count := int(_percentile_numbers(boundary_counts, 0.50))
	var area_ratios: Dictionary = receipt.get("region_area_ratio", {}) as Dictionary
	var sliver_count := 0
	for region_variant in region_ids:
		if float(area_ratios.get(str(region_variant), 0.0)) < MINIMUM_REGION_AREA_RATIO:
			sliver_count += 1
	var surface_area := float(microgrid.get("surface_area_steradians", 0.0))
	var coverage_error := absf(surface_area - FOUR_PI) / FOUR_PI
	var nonfinite_count := _geometry_nonfinite_count(receipt)
	var duplicate_mesh_edge_count := _duplicate_shared_mesh_edge_count(receipt)
	var self_intersection_count := 0
	if int(microgrid.get("nonmanifold_edge_count", 0)) != 0:
		self_intersection_count += int(microgrid.get("nonmanifold_edge_count", 0))
	if gap_count != 0:
		errors.append("map_genesis_sphere_coverage_gap")
	if overlap_count != 0:
		errors.append("map_genesis_sphere_coverage_overlap")
	if triangle_count != 0:
		errors.append("map_genesis_triangle_region")
	if quadrilateral_count != 0:
		errors.append("map_genesis_quadrilateral_region")
	if invalid_ordered_loop_count != 0:
		errors.append("map_genesis_ordered_boundary_lod_invalid")
	if self_intersection_count != 0:
		errors.append("map_genesis_boundary_self_intersection")
	if duplicate_mesh_edge_count != 0:
		errors.append("map_genesis_shared_boundary_duplicate")
	if sliver_count != 0:
		errors.append("map_genesis_region_sliver")
	if coverage_error > 0.0001:
		errors.append("map_genesis_sphere_coverage_error")
	if nonfinite_count != 0:
		errors.append("map_genesis_geometry_nonfinite")
	var concavity_ratio := _concave_region_ratio(receipt)
	return {
		"errors": errors,
		"triangle_region_count": triangle_count,
		"quadrilateral_region_count": quadrilateral_count,
		"median_boundary_vertex_count": median_boundary_count,
		"near_boundary_loop_min_vertex_count": near_loop_min_vertex_count,
		"invalid_ordered_boundary_loop_count": invalid_ordered_loop_count,
		"concave_region_ratio": concavity_ratio,
		"region_boundary_self_intersection_count": self_intersection_count,
		"region_boundary_gap_count": gap_count,
		"region_boundary_overlap_count": overlap_count + duplicate_mesh_edge_count,
		"region_sliver_count": sliver_count,
		"sphere_coverage_error_ratio": coverage_error,
		"geometry_nonfinite_count": nonfinite_count,
	}


static func _validate_facility_slots(receipt: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var request: Dictionary = receipt.get("request", {}) as Dictionary
	var region_ids: Array = receipt.get("region_ids", []) as Array
	var facility_types: Array = request.get("registered_facility_types", []) as Array
	var industries: Array = request.get("industry_ids", []) as Array
	var slots: Dictionary = receipt.get("facility_slot_registry", {}) as Dictionary
	var expected := region_ids.size() * facility_types.size() * industries.size()
	var duplicate_count := 0
	var reference_failure_count := 0
	var canonical_keys := {}
	for slot_id_variant in slots.keys():
		var slot_id := str(slot_id_variant)
		var slot: Dictionary = slots.get(slot_id, {}) as Dictionary
		var region_id := str(slot.get("region_id", ""))
		var facility_type := str(slot.get("facility_type", ""))
		var industry_id := str(slot.get("industry_id", ""))
		var canonical := "%s|%s|%s" % [region_id, facility_type, industry_id]
		if canonical_keys.has(canonical):
			duplicate_count += 1
		canonical_keys[canonical] = true
		if not region_ids.has(region_id) or not facility_types.has(facility_type) 				or not industries.has(industry_id) 				or slot_id != "slot.%s.%s.%s" % [region_id, facility_type, industry_id]:
			reference_failure_count += 1
	if slots.size() != expected:
		errors.append("map_genesis_facility_slot_count_mismatch")
	if duplicate_count != 0:
		errors.append("map_genesis_facility_slot_duplicate")
	if reference_failure_count != 0:
		errors.append("map_genesis_facility_slot_reference_invalid")
	return {
		"errors": errors,
		"facility_slot_expected_count": expected,
		"facility_slot_actual_count": slots.size(),
		"facility_slot_duplicate_key_count": duplicate_count,
		"facility_slot_reference_failure_count": reference_failure_count,
	}


static func _graph_component_count(region_ids: Array, adjacency: Dictionary) -> int:
	if region_ids.is_empty():
		return 0
	var unvisited := {}
	for region_variant in region_ids:
		unvisited[str(region_variant)] = true
	var component_count := 0
	while not unvisited.is_empty():
		component_count += 1
		var start := str(unvisited.keys()[0])
		var queue: Array[String] = [start]
		unvisited.erase(start)
		while not queue.is_empty():
			var current: String = str(queue.pop_front())
			for neighbor_variant in adjacency.get(current, []) as Array:
				var neighbor := str(neighbor_variant)
				if unvisited.has(neighbor):
					unvisited.erase(neighbor)
					queue.append(neighbor)
	return component_count


static func _disconnected_region_count(receipt: Dictionary) -> int:
	var microgrid: Dictionary = receipt.get("microgrid", {}) as Dictionary
	var adjacency: Array = microgrid.get("microcell_adjacency", []) as Array
	var owners: Array = microgrid.get("region_index_by_microcell", []) as Array
	var membership: Dictionary = receipt.get("region_microcell_membership", {}) as Dictionary
	var disconnected_count := 0
	var region_ids: Array = receipt.get("region_ids", []) as Array
	for region_index in range(region_ids.size()):
		var region_id := str(region_ids[region_index])
		var faces: Array = membership.get(region_id, []) as Array
		if faces.is_empty():
			disconnected_count += 1
			continue
		var visited := {}
		var queue: Array[int] = [int(faces[0])]
		visited[int(faces[0])] = true
		while not queue.is_empty():
			var face_index: int = int(queue.pop_front())
			for neighbor_variant in adjacency[face_index] as Array:
				var neighbor := int(neighbor_variant)
				if int(owners[neighbor]) == region_index and not visited.has(neighbor):
					visited[neighbor] = true
					queue.append(neighbor)
		if visited.size() != faces.size():
			disconnected_count += 1
	return disconnected_count


static func _geometry_nonfinite_count(receipt: Dictionary) -> int:
	var count := 0
	var microgrid: Dictionary = receipt.get("microgrid", {}) as Dictionary
	for vertex_variant in microgrid.get("vertices_unit_sphere", []) as Array:
		var vertex := vertex_variant as Vector3
		if not is_finite(vertex.x) or not is_finite(vertex.y) or not is_finite(vertex.z):
			count += 1
	for center_variant in (receipt.get("region_centers_unit_sphere", {}) as Dictionary).values():
		var center := center_variant as Vector3
		if not is_finite(center.x) or not is_finite(center.y) or not is_finite(center.z):
			count += 1
	return count


static func _duplicate_shared_mesh_edge_count(receipt: Dictionary) -> int:
	var seen := {}
	var duplicate_count := 0
	for edge_variant in receipt.get("shared_boundary_edges", []) as Array:
		var edge := edge_variant as Dictionary
		var key := str(edge.get("mesh_edge_key", ""))
		if key.is_empty() or seen.has(key):
			duplicate_count += 1
		seen[key] = true
	return duplicate_count


static func _concave_region_ratio(receipt: Dictionary) -> float:
	var region_ids: Array = receipt.get("region_ids", []) as Array
	if region_ids.is_empty():
		return 0.0
	var microgrid: Dictionary = receipt.get("microgrid", {}) as Dictionary
	var vertices: Array = microgrid.get("vertices_unit_sphere", []) as Array
	var boundaries: Dictionary = receipt.get("region_boundaries_spherical", {}) as Dictionary
	var centers: Dictionary = receipt.get("region_centers_unit_sphere", {}) as Dictionary
	var concave_count := 0
	for region_variant in region_ids:
		var region_id := str(region_variant)
		var center: Vector3 = centers.get(region_id, Vector3.UP) as Vector3
		var reference := Vector3.UP if absf(center.y) < 0.90 else Vector3.RIGHT
		var tangent := reference.cross(center).normalized()
		var bitangent := center.cross(tangent).normalized()
		var points: Array[Vector2] = []
		var boundary: Dictionary = boundaries.get(region_id, {}) as Dictionary
		for vertex_id_variant in boundary.get("boundary_vertex_ids", []) as Array:
			var vertex := vertices[int(vertex_id_variant)] as Vector3
			points.append(Vector2(vertex.dot(tangent), vertex.dot(bitangent)))
		var hull_count := _convex_hull_vertex_count(points)
		var required_indent_count := maxi(2, ceili(float(points.size()) * 0.08))
		if points.size() - hull_count >= required_indent_count:
			concave_count += 1
	return float(concave_count) / float(region_ids.size())


static func _convex_hull_vertex_count(source: Array[Vector2]) -> int:
	if source.size() <= 3:
		return source.size()
	var points: Array[Vector2] = source.duplicate()
	points.sort_custom(func(left: Vector2, right: Vector2) -> bool:
		if not is_equal_approx(left.x, right.x):
			return left.x < right.x
		return left.y < right.y
	)
	var lower: Array[Vector2] = []
	for point in points:
		while lower.size() >= 2 and _cross_2d(
			lower[lower.size() - 2],
			lower[lower.size() - 1],
			point
		) <= 0.000000001:
			lower.pop_back()
		lower.append(point)
	var upper: Array[Vector2] = []
	for index in range(points.size() - 1, -1, -1):
		var point := points[index]
		while upper.size() >= 2 and _cross_2d(
			upper[upper.size() - 2],
			upper[upper.size() - 1],
			point
		) <= 0.000000001:
			upper.pop_back()
		upper.append(point)
	return lower.size() + upper.size() - 2


static func _cross_2d(origin: Vector2, left: Vector2, right: Vector2) -> float:
	return (left - origin).cross(right - origin)


static func _percentile_numbers(values: Array, percentile: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted_values: Array = values.duplicate()
	sorted_values.sort()
	var index := clampi(
		ceili(percentile * float(sorted_values.size())) - 1,
		0,
		sorted_values.size() - 1
	)
	return float(sorted_values[index])