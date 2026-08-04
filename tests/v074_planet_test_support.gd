extends RefCounted
class_name V074PlanetTestSupport

const INDUSTRIES := ["life", "energy", "industry", "technology", "commerce", "shipping"]
const FACILITY_TYPES := ["factory", "market", "warehouse"]


class MapGenesisReceiptFixture:
	extends RefCounted

	var schema_version := 1
	var ruleset_id := "v0.7.4"
	var map_id := "fixture.map"
	var map_seed := 900626424
	var map_profile_id := "fixture.standard"
	var geography_complexity := "STANDARD"
	var land_ocean_profile := "BALANCED"
	var region_count := 0
	var region_ids: Array = []
	var terrain_by_region: Dictionary = {}
	var region_centers_unit_sphere: Dictionary = {}
	var region_microcell_membership: Dictionary = {}
	var microcell_centers_unit_sphere: Dictionary = {}
	var region_boundaries_spherical: Dictionary = {}
	var region_boundary_lods_spherical: Dictionary = {}
	var shared_boundary_edges: Array = []
	var adjacency_graph: Dictionary = {}
	var land_ocean_edges: Array = []
	var facility_slot_registry: Array = []
	var initial_sun_direction := Vector3(0.82, 0.18, 0.54).normalized()
	var map_fingerprint := ""
	var display_names_by_region: Dictionary = {}

	func to_dictionary() -> Dictionary:
		return {
			"schema_version": schema_version,
			"ruleset_id": ruleset_id,
			"map_id": map_id,
			"map_seed": map_seed,
			"map_profile_id": map_profile_id,
			"geography_complexity": geography_complexity,
			"land_ocean_profile": land_ocean_profile,
			"region_count": region_count,
			"region_ids": region_ids,
			"terrain_by_region": terrain_by_region,
			"region_centers_unit_sphere": region_centers_unit_sphere,
			"region_microcell_membership": region_microcell_membership,
			"microcell_centers_unit_sphere": microcell_centers_unit_sphere,
			"region_boundaries_spherical": region_boundaries_spherical,
			"region_boundary_lods_spherical": region_boundary_lods_spherical,
			"shared_boundary_edges": shared_boundary_edges,
			"adjacency_graph": adjacency_graph,
			"land_ocean_edges": land_ocean_edges,
			"facility_slot_registry": facility_slot_registry,
			"initial_sun_direction": initial_sun_direction,
			"map_fingerprint": map_fingerprint,
			"display_names_by_region": display_names_by_region,
		}


static func build_receipt(region_total: int = 16, complexity: String = "STANDARD") -> MapGenesisReceiptFixture:
	var receipt := MapGenesisReceiptFixture.new()
	receipt.region_count = region_total
	receipt.geography_complexity = complexity
	receipt.map_profile_id = "fixture.%s.%d" % [complexity.to_lower(), region_total]
	var boundary_vertices := {"SIMPLE": 12, "STANDARD": 20, "COMPLEX": 32}.get(complexity, 20) as int
	for index in range(region_total):
		var region_id := "region.%03d" % index
		var center := _fibonacci_unit(index, region_total)
		var terrain := "land" if index % 3 != 1 else "ocean"
		receipt.region_ids.append(region_id)
		receipt.terrain_by_region[region_id] = terrain
		receipt.region_centers_unit_sphere[region_id] = center
		receipt.display_names_by_region[region_id] = "%s %02d" % ["陆域" if terrain == "land" else "海域", index + 1]
		var near := _boundary_loop(center, boundary_vertices, 0.32 / sqrt(float(region_total) / 6.0))
		var medium := _boundary_loop(center, maxi(12, boundary_vertices / 2), 0.32 / sqrt(float(region_total) / 6.0))
		var far := _boundary_loop(center, maxi(8, boundary_vertices / 3), 0.32 / sqrt(float(region_total) / 6.0))
		receipt.region_boundaries_spherical[region_id] = near
		receipt.region_boundary_lods_spherical[region_id] = {"far": far, "medium": medium, "near": near}
		var cell_ids: Array = []
		for cell_index in range(7):
			var cell_id := "%s.cell.%02d" % [region_id, cell_index]
			var cell_unit := center if cell_index == 0 else _offset_unit(center, float(cell_index - 1) / 6.0 * TAU, 0.10)
			cell_ids.append(cell_id)
			receipt.microcell_centers_unit_sphere[cell_id] = cell_unit
		receipt.region_microcell_membership[region_id] = cell_ids
		receipt.adjacency_graph[region_id] = [
			"region.%03d" % posmod(index - 1, region_total),
			"region.%03d" % posmod(index + 1, region_total),
		]
		for facility_type in FACILITY_TYPES:
			for industry_id in INDUSTRIES:
				receipt.facility_slot_registry.append({
					"region_id": region_id,
					"facility_type": facility_type,
					"industry_id": industry_id,
				})
	for index in range(region_total):
		var next := posmod(index + 1, region_total)
		var first_id := "region.%03d" % index
		var second_id := "region.%03d" % next
		receipt.shared_boundary_edges.append({"regions": [first_id, second_id], "edge_id": "edge.%03d" % index})
		if receipt.terrain_by_region[first_id] != receipt.terrain_by_region[second_id]:
			receipt.land_ocean_edges.append("edge.%03d" % index)
	receipt.map_fingerprint = "fixture.%d.%s.%d" % [receipt.map_seed, complexity.to_lower(), region_total]
	return receipt


static func build_lane_a_boundary_receipt(
	source: MapGenesisReceiptFixture,
	include_secondary_loop: bool = false,
	shared_edge_fallback_only: bool = false
) -> Dictionary:
	var result := source.to_dictionary()
	var shared_edges: Array = []
	var boundaries: Dictionary = {}
	var preferred_lods: Dictionary = {}
	var vertices: Array = []
	var edge_ordinal := 0
	for region_index in range(source.region_ids.size()):
		var region_id := str(source.region_ids[region_index])
		var original_lods := source.region_boundary_lods_spherical.get(region_id, {}) as Dictionary
		var near_loops: Array = [(original_lods.get("near", []) as Array).duplicate(true)]
		var medium_loops: Array = [(original_lods.get("medium", []) as Array).duplicate(true)]
		var far_loops: Array = [(original_lods.get("far", []) as Array).duplicate(true)]
		if include_secondary_loop and region_index == 0:
			var center := source.region_centers_unit_sphere.get(region_id, Vector3.UP) as Vector3
			near_loops.append(_boundary_loop(center, 8, 0.115))
			medium_loops.append(_boundary_loop(center, 7, 0.115))
			far_loops.append(_boundary_loop(center, 6, 0.115))
		var region_lods := {
			"near": near_loops,
			"medium": medium_loops,
			"far": far_loops,
		}
		var edge_ids: Array = []
		var ordered_vertex_loops: Array = []
		var boundary_vertex_ids: Array = []
		for loop_variant in near_loops:
			var loop := loop_variant as Array
			var vertex_ids: Array = []
			for point_variant in loop:
				vertex_ids.append(vertices.size())
				boundary_vertex_ids.append(vertices.size())
				vertices.append(point_variant)
			ordered_vertex_loops.append(vertex_ids)
			for point_index in range(loop.size()):
				var edge_id := "boundary.fixture.%03d.%03d" % [
					region_index,
					edge_ordinal,
				]
				var next_index := posmod(point_index + 1, loop.size())
				var edge_points: Array = [
					loop[point_index],
					loop[next_index],
				]
				if edge_ordinal % 2 == 1:
					edge_points.reverse()
				shared_edges.append({
					"boundary_id": edge_id,
					"region_a": region_id,
					"region_b": str(source.region_ids[posmod(region_index + 1, source.region_ids.size())]),
					"points_unit_sphere": edge_points,
				})
				edge_ids.append(edge_id)
				edge_ordinal += 1
		boundaries[region_id] = {
			"shared_boundary_edge_ids": edge_ids,
			"boundary_edge_id_lods": {
				"near": edge_ids.duplicate(),
				"medium": edge_ids.duplicate(),
				"far": edge_ids.duplicate(),
			},
			"ordered_boundary_vertex_loops": (
				[]
				if shared_edge_fallback_only
				else ordered_vertex_loops
			),
			"boundary_lods_spherical": (
				{}
				if shared_edge_fallback_only
				else region_lods
			),
			"boundary_vertex_ids": boundary_vertex_ids,
			"boundary_vertex_count": boundary_vertex_ids.size(),
		}
		if not shared_edge_fallback_only:
			preferred_lods[region_id] = region_lods
	result["region_boundaries_spherical"] = boundaries
	result["region_boundary_lods_spherical"] = preferred_lods
	result["shared_boundary_edges"] = shared_edges
	result["microgrid"] = {
		"vertices_unit_sphere": vertices,
		"microcell_centers_unit_sphere": source.microcell_centers_unit_sphere.duplicate(true),
	}
	return result


static func public_projection(receipt: MapGenesisReceiptFixture) -> Dictionary:
	var slots: Array = []
	for index in range(3):
		var facility_type := str(FACILITY_TYPES[index])
		slots.append({
			"occupancy": "occupied",
			"facility_type": facility_type,
			"region_id": str(receipt.region_ids[index]),
			"industry_id": INDUSTRIES[index],
			"rank": index + 1,
			"owner_public_id": "player.%d" % index,
			"public_capacity": 8 if facility_type == "warehouse" else null,
			"public_ingress_throughput": 4.0 if facility_type == "warehouse" else null,
			"public_egress_throughput": 4.0 if facility_type == "warehouse" else null,
			"damage_points": 0,
			"private_stock": {"ore": 99},
			"private_logistics_plan": ["hidden"],
		})
	return {
		"ruleset_id": "v0.7.4",
		"batch_number": 3,
		"authorization_revision": 4,
		"local_player_index": 0,
		"sun_direction": receipt.initial_sun_direction,
		"solar_threshold": 0.0,
		"facility_contention": {"public_facility_slots": slots},
		"legal_actions": [
			{"card_instance_id": "card.fixture", "target_region_id": str(receipt.region_ids[0])},
			{"card_instance_id": "card.fixture", "target_region_id": str(receipt.region_ids[2])},
		],
		"monster_public_facts": [
			{"region_id": str(receipt.region_ids[3]), "display_name": "公开怪兽", "public_status": "活动"},
		],
		"military_public_facts": [
			{"region_id": str(receipt.region_ids[4]), "display_name": "公开军队", "public_status": "驻防"},
		],
		"public_routes": [
			{"from_region_id": str(receipt.region_ids[0]), "to_region_id": str(receipt.region_ids[1]), "commodity_id": "life"},
		],
	}


static func add_failure(failures: Array, condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


static func print_result(label: String, checks: int, failures: Array, tree: SceneTree) -> void:
	var passed := failures.is_empty()
	print("%s|status=%s|passed=%d|total=%d|details=%s" % [
		label,
		"PASS" if passed else "FAIL",
		checks - failures.size(),
		checks,
		JSON.stringify(failures),
	])
	tree.quit(0 if passed else 1)


static func _fibonacci_unit(index: int, count: int) -> Vector3:
	var y := 1.0 - 2.0 * (float(index) + 0.5) / float(count)
	var radius := sqrt(maxf(0.0, 1.0 - y * y))
	var theta := float(index) * PI * (3.0 - sqrt(5.0))
	return Vector3(cos(theta) * radius, y, sin(theta) * radius).normalized()


static func _boundary_loop(center: Vector3, vertex_count: int, angular_radius: float) -> Array:
	var tangent := center.cross(Vector3.UP)
	if tangent.length_squared() < 0.01:
		tangent = center.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	var bitangent := center.cross(tangent).normalized()
	var result: Array = []
	for index in range(vertex_count):
		var angle := float(index) / float(vertex_count) * TAU
		var wobble := 1.0 + sin(angle * 3.0 + center.y * 2.0) * 0.16
		var direction := tangent * cos(angle) + bitangent * sin(angle)
		result.append((center * cos(angular_radius * wobble) + direction * sin(angular_radius * wobble)).normalized())
	return result


static func _offset_unit(center: Vector3, angle: float, angular_radius: float) -> Vector3:
	var tangent := center.cross(Vector3.UP)
	if tangent.length_squared() < 0.01:
		tangent = center.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	var bitangent := center.cross(tangent).normalized()
	var direction := tangent * cos(angle) + bitangent * sin(angle)
	return (center * cos(angular_radius) + direction * sin(angular_radius)).normalized()
