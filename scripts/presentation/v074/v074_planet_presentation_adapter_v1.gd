extends RefCounted
class_name V074PlanetPresentationAdapterV1

const Snapshot := preload("res://scripts/presentation/map_presentation_snapshot.gd")

const RULESET_ID := "v0.7.4"
const MAP_WIDTH_M := 4096.0
const MAP_HEIGHT_M := 2048.0
const FACILITY_ASSET_KEYS := {
	"factory": "model.facility.factory.base",
	"market": "model.facility.market.base",
	"warehouse": "model.facility.warehouse.base",
}
const FACILITY_TAGS := {"factory": "F", "market": "M", "warehouse": "W"}
const INDUSTRY_COLORS := {
	"life": "#52d681",
	"energy": "#f2c14e",
	"industry": "#aeb8c6",
	"technology": "#4cc9f0",
	"commerce": "#d08cf0",
	"shipping": "#46d6b5",
}
const LAND_PALETTE := [
	Color("#5aa978"), Color("#77b86f"), Color("#8da96b"), Color("#4f9674"),
	Color("#92b77d"), Color("#68a884"), Color("#a1b469"), Color("#5d9f69"),
]
const OCEAN_PALETTE := [
	Color("#167ea2"), Color("#1d6f9c"), Color("#2587a9"), Color("#23628f"),
	Color("#2b7797"), Color("#176a87"), Color("#318aa8"), Color("#1b5f83"),
]
const RECEIPT_KEYS := [
	"schema_version", "contract_id", "ruleset_id", "accepted", "reason_code",
	"map_id", "map_seed", "map_profile_id", "geography_complexity",
	"land_ocean_profile", "region_count", "region_ids", "terrain_by_region",
	"region_centers_unit_sphere", "region_area_ratio", "region_microcell_membership",
	"microgrid", "microcell_centers_unit_sphere", "microcells",
	"region_boundaries_spherical", "region_boundary_lods_spherical",
	"shared_boundary_edges", "adjacency_graph", "land_ocean_edges",
	"facility_slot_registry", "initial_sun_direction", "sun_direction",
	"solar_threshold", "map_fingerprint", "display_names_by_region",
]

var _build_count := 0
var _last_surface_payload: Dictionary = {}


func build_map_view_payload(
	map_genesis_receipt: Variant,
	public_projection: Dictionary,
	selected_card_instance_id: String = "",
	selected_region_id: String = ""
) -> Dictionary:
	var snapshot := build_map_snapshot(
		map_genesis_receipt,
		public_projection,
		selected_card_instance_id,
		selected_region_id
	)
	if snapshot == null:
		return {}
	return {
		"snapshot": snapshot,
		"authoritative_surface": _last_surface_payload.duplicate(true),
	}


func build_map_snapshot(
	map_genesis_receipt: Variant,
	public_projection: Dictionary,
	selected_card_instance_id: String = "",
	selected_region_id: String = ""
) -> MapPresentationSnapshot:
	var receipt := _receipt_dictionary(map_genesis_receipt)
	if receipt.is_empty() or str(receipt.get("ruleset_id", RULESET_ID)) != RULESET_ID:
		return null
	var surface := build_authoritative_surface(map_genesis_receipt, public_projection)
	if surface.is_empty():
		return null
	var region_ids := surface.get("region_ids", []) as Array
	var terrain_by_region := surface.get("terrain_by_region", {}) as Dictionary
	var centers := surface.get("region_centers_unit_sphere", {}) as Dictionary
	var boundary_lods := surface.get("region_boundary_lods_spherical", {}) as Dictionary
	var adjacency := surface.get("adjacency_graph", {}) as Dictionary
	var legal_regions := _legal_regions(public_projection, selected_card_instance_id)
	var districts: Array = []
	var palette: Array[Color] = []
	for index in range(region_ids.size()):
		var region_id := str(region_ids[index])
		var center_unit := _as_vector3(centers.get(region_id, Vector3.ZERO)).normalized()
		var lods := boundary_lods.get(region_id, {}) as Dictionary
		var near_boundary := _vector3_array(lods.get("near", []))
		var terrain_class := str(terrain_by_region.get(region_id, ""))
		if center_unit.length_squared() < 0.9 or near_boundary.size() < 5:
			return null
		if terrain_class != "land" and terrain_class != "ocean":
			return null
		var sunlit := center_unit.dot(_as_vector3(surface.get("sun_direction", Vector3.RIGHT)).normalized()) > float(surface.get("solar_threshold", 0.0))
		var multiplier := 2.0 if sunlit else 1.0
		var area_ratio := float(_indexed_value(receipt.get("region_area_ratio", {}), region_id, index, 0.0))
		districts.append({
			"region_id": region_id,
			"name": _display_name(receipt, region_id, index),
			"center": _world_from_unit(center_unit),
			"center_unit_sphere": center_unit,
			"polygon": _world_polygon(near_boundary),
			"boundary_lods_spherical": lods.duplicate(true),
			"microcell_ids": (surface.get("region_microcell_membership", {}) as Dictionary).get(region_id, []),
			"neighbors": (adjacency.get(region_id, []) as Array).duplicate(),
			"terrain": terrain_class,
			"terrain_class": terrain_class,
			"area_ratio": area_ratio,
			"radius_m": _display_radius(center_unit, near_boundary, area_ratio),
			"sunlit": sunlit,
			"facility_efficiency_multiplier": multiplier,
			"unified_track_supply_affected": false,
			"legal_target": selected_card_instance_id.is_empty() or legal_regions.has(region_id),
			"hp": 0,
			"panic": 0,
			"products": [("陆地" if terrain_class == "land" else "海洋"), ("日照" if sunlit else "暗面") + " ×%.1f" % multiplier],
			"destroyed": false,
		})
		palette.append(_region_color(terrain_class, index))
	var result := Snapshot.new()
	result.revision = maxi(0, int(public_projection.get("batch_number", 0)))
	result.viewer_index = _viewer_index(public_projection)
	result.authorization_revision = maxi(1, int(public_projection.get("authorization_revision", result.revision + 1)))
	result.districts = districts
	result.width_m = MAP_WIDTH_M
	result.height_m = MAP_HEIGHT_M
	result.selected_district = region_ids.find(selected_region_id)
	result.palette = palette
	result.unit_markers = _public_unit_markers(public_projection, centers)
	result.city_markers = _public_facility_markers(public_projection, centers)
	result.route_markers = _public_route_markers(public_projection, centers)
	result.solar_presentation = {
		"sun_direction": surface.get("sun_direction", Vector3.RIGHT),
		"sun_turn_ppm": _sun_turn_ppm(_as_vector3(surface.get("sun_direction", Vector3.RIGHT))),
		"solar_threshold": float(surface.get("solar_threshold", 0.0)),
		"source": "MapGenesisReceiptV1.current_public_sun_direction",
	}
	result.weather_forecast = {}
	result.weather_overlay = {}
	result.motion_mode = "full"
	result.presentation_seed = int(receipt.get("map_seed", 0))
	result.geometry_fingerprint = str(receipt.get("map_fingerprint", ""))
	_last_surface_payload = surface
	_build_count += 1
	return result


func build_authoritative_surface(map_genesis_receipt: Variant, public_projection: Dictionary = {}) -> Dictionary:
	var receipt := _receipt_dictionary(map_genesis_receipt)
	var region_ids := _string_array(receipt.get("region_ids", []))
	if region_ids.size() < 1 or int(receipt.get("region_count", region_ids.size())) != region_ids.size():
		return {}
	var terrain_by_region: Dictionary = {}
	var centers_by_region: Dictionary = {}
	var lods_by_region: Dictionary = {}
	var loop_lods_by_region: Dictionary = {}
	var boundary_source_by_region: Dictionary = {}
	var membership_by_region: Dictionary = {}
	var boundary_order_reconstruction_count := 0
	for index in range(region_ids.size()):
		var region_id := str(region_ids[index])
		var terrain := str(_indexed_value(receipt.get("terrain_by_region", {}), region_id, index, ""))
		var center := _as_vector3(_indexed_value(receipt.get("region_centers_unit_sphere", {}), region_id, index, Vector3.ZERO)).normalized()
		var loop_lods := _boundary_loop_lods(receipt, region_id, index)
		var lods := _primary_boundary_lods(loop_lods)
		var boundary_source := str(loop_lods.get("source", ""))
		if (terrain != "land" and terrain != "ocean") or center.length_squared() < 0.9 or _vector3_array(lods.get("near", [])).size() < 5:
			return {}
		terrain_by_region[region_id] = terrain
		centers_by_region[region_id] = center
		lods_by_region[region_id] = lods
		loop_lods_by_region[region_id] = _geometry_only_boundary_lods(loop_lods)
		boundary_source_by_region[region_id] = boundary_source
		if boundary_source == "shared_boundary_edges.points_unit_sphere":
			boundary_order_reconstruction_count += 1
		membership_by_region[region_id] = _array_value(_indexed_value(receipt.get("region_microcell_membership", {}), region_id, index, []))
	var hit_cells := _hit_test_cells(receipt, region_ids, terrain_by_region, membership_by_region)
	var request := receipt.get("request", {}) as Dictionary
	var current_sun := _current_sun_direction(receipt, public_projection)
	if current_sun.length_squared() < 0.9:
		return {}
	return {
		"schema": "V074AuthoritativePlanetSurfaceV1",
		"ruleset_id": RULESET_ID,
		"map_id": str(receipt.get("map_id", "")),
		"map_seed": int(receipt.get("map_seed", 0)),
		"map_profile_id": str(receipt.get("map_profile_id", "")),
		"geography_complexity": str(receipt.get("geography_complexity", request.get("geography_complexity", "STANDARD"))),
		"land_ocean_profile": str(receipt.get("land_ocean_profile", request.get("land_ocean_profile", "BALANCED"))),
		"map_fingerprint": str(receipt.get("map_fingerprint", "")),
		"region_ids": region_ids,
		"terrain_by_region": terrain_by_region,
		"region_centers_unit_sphere": centers_by_region,
		"region_boundary_lods_spherical": lods_by_region,
		"region_boundary_loop_lods_spherical": loop_lods_by_region,
		"boundary_source_by_region": boundary_source_by_region,
		"region_microcell_membership": membership_by_region,
		"adjacency_graph": _adjacency_dictionary(receipt.get("adjacency_graph", {}), region_ids),
		"shared_boundary_edges": receipt.get("shared_boundary_edges", []),
		"land_ocean_edges": receipt.get("land_ocean_edges", []),
		"facility_slot_registry": receipt.get("facility_slot_registry", []),
		"microgrid_vertices_unit_sphere": _microgrid_vertices(receipt),
		"hit_test_cells": hit_cells,
		"terrain_surface_samples": hit_cells,
		"sun_direction": current_sun,
		"solar_threshold": float(public_projection.get("solar_threshold", receipt.get("solar_threshold", 0.0))),
		"geometry_source": "MapGenesisReceiptV1",
		"microcell_center_source": _microcell_center_source_name(receipt),
		"presentation_boundary_order_reconstruction_count": boundary_order_reconstruction_count,
		"presentation_generated_geometry_count": 0,
		"presentation_generated_terrain_count": 0,
	}


func last_authoritative_surface() -> Dictionary:
	return _last_surface_payload.duplicate(true)


func debug_snapshot() -> Dictionary:
	return {
		"schema": "V074PlanetPresentationAdapterDebugV1",
		"connection_count": 1,
		"build_count": _build_count,
		"gameplay_owner_count": 0,
		"save_owner_count": 0,
		"rng_owner_count": 0,
		"gameplay_rng_draw_count": 0,
		"presentation_generated_geometry_count": 0,
		"presentation_generated_terrain_count": 0,
		"region_count": (_last_surface_payload.get("region_ids", []) as Array).size(),
		"geometry_source": str(_last_surface_payload.get("geometry_source", "none")),
		"microcell_center_source": str(_last_surface_payload.get("microcell_center_source", "none")),
		"presentation_boundary_order_reconstruction_count": int(_last_surface_payload.get("presentation_boundary_order_reconstruction_count", 0)),
		"map_fingerprint": str(_last_surface_payload.get("map_fingerprint", "")),
	}


func _receipt_dictionary(receipt: Variant) -> Dictionary:
	if receipt is Dictionary:
		return (receipt as Dictionary).duplicate(true)
	if receipt == null or not (receipt is Object):
		return {}
	var object := receipt as Object
	if object.has_method("to_dictionary"):
		var value: Variant = object.call("to_dictionary")
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	var properties := {}
	for property in object.get_property_list():
		properties[str((property as Dictionary).get("name", ""))] = true
	var result := {}
	for key in RECEIPT_KEYS:
		if properties.has(key):
			result[key] = object.get(key)
	return result


func _boundary_lods(receipt: Dictionary, region_id: String, index: int) -> Dictionary:
	return _primary_boundary_lods(_boundary_loop_lods(receipt, region_id, index))


func _boundary_loop_lods(receipt: Dictionary, region_id: String, index: int) -> Dictionary:
	var preferred_value: Variant = _indexed_value(
		receipt.get("region_boundary_lods_spherical", {}),
		region_id,
		index,
		{}
	)
	var preferred := _normalized_boundary_lods(
		preferred_value,
		"region_boundary_lods_spherical"
	)
	if not preferred.is_empty():
		return preferred

	var base_value: Variant = _indexed_value(
		receipt.get("region_boundaries_spherical", {}),
		region_id,
		index,
		[]
	)
	if base_value is Dictionary:
		var base := base_value as Dictionary
		var embedded := _normalized_boundary_lods(
			base.get("boundary_lods_spherical", {}),
			"region_boundaries_spherical.boundary_lods_spherical"
		)
		if not embedded.is_empty():
			return embedded
		var ordered_vertex_loops := _boundary_loops_from_vertex_ids(
			receipt,
			base.get("ordered_boundary_vertex_loops", [])
		)
		if not ordered_vertex_loops.is_empty():
			return {
				"far": ordered_vertex_loops.duplicate(true),
				"medium": ordered_vertex_loops.duplicate(true),
				"near": ordered_vertex_loops,
				"source": "microgrid.vertices_unit_sphere",
			}

	var shared_edge_index := _shared_boundary_edge_index(
		receipt.get("shared_boundary_edges", [])
	)
	if not shared_edge_index.is_empty():
		var shared_lods := _shared_edge_boundary_lods(base_value, shared_edge_index)
		if not shared_lods.is_empty():
			return shared_lods

	var direct_value: Variant = (
		(base_value as Dictionary).get("points_unit_sphere", [])
		if base_value is Dictionary
		else base_value
	)
	var direct_loops := _normalize_boundary_loops(direct_value)
	if direct_loops.is_empty():
		return {}
	return {
		"far": direct_loops.duplicate(true),
		"medium": direct_loops.duplicate(true),
		"near": direct_loops,
		"source": "region_boundaries_spherical.points_unit_sphere",
	}


func _normalized_boundary_lods(value: Variant, source_name: String) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var source := value as Dictionary
	var near := _normalize_boundary_loops(source.get("near", []))
	if near.is_empty():
		return {}
	var medium := _normalize_boundary_loops(source.get("medium", []))
	if medium.is_empty():
		medium = near.duplicate(true)
	var far := _normalize_boundary_loops(source.get("far", []))
	if far.is_empty():
		far = medium.duplicate(true)
	return {
		"far": far,
		"medium": medium,
		"near": near,
		"source": source_name,
	}


func _normalize_boundary_loops(value: Variant) -> Array:
	var result: Array = []
	if value is PackedVector3Array:
		var packed_loop := _vector3_array(value)
		if packed_loop.size() >= 3:
			result.append(packed_loop)
		return result
	if not (value is Array):
		return result
	var rows := value as Array
	if rows.is_empty():
		return result
	if _is_vector3_value(rows[0]):
		var single_loop := _vector3_array(rows)
		if single_loop.size() >= 3:
			result.append(single_loop)
		return result
	for loop_variant in rows:
		var loop := _vector3_array(loop_variant)
		if loop.size() >= 3:
			result.append(loop)
	return result


func _primary_boundary_lods(loop_lods: Dictionary) -> Dictionary:
	return {
		"far": _primary_boundary_loop(loop_lods.get("far", [])),
		"medium": _primary_boundary_loop(loop_lods.get("medium", [])),
		"near": _primary_boundary_loop(loop_lods.get("near", [])),
	}


func _geometry_only_boundary_lods(loop_lods: Dictionary) -> Dictionary:
	return {
		"far": _normalize_boundary_loops(loop_lods.get("far", [])),
		"medium": _normalize_boundary_loops(loop_lods.get("medium", [])),
		"near": _normalize_boundary_loops(loop_lods.get("near", [])),
	}


func _primary_boundary_loop(value: Variant) -> Array[Vector3]:
	var best: Array[Vector3] = []
	for loop_variant in _normalize_boundary_loops(value):
		var loop := _vector3_array(loop_variant)
		if loop.size() > best.size():
			best = loop
	return best


func _boundary_loops_from_vertex_ids(receipt: Dictionary, value: Variant) -> Array:
	if not (value is Array):
		return []
	var vertices := _microgrid_vertices(receipt)
	if vertices.is_empty():
		return []
	var result: Array = []
	for loop_ids_variant in value as Array:
		if not (loop_ids_variant is Array):
			continue
		var loop: Array[Vector3] = []
		for vertex_id_variant in loop_ids_variant as Array:
			var vertex_index := int(vertex_id_variant)
			if vertex_index < 0 or vertex_index >= vertices.size():
				continue
			loop.append(vertices[vertex_index])
		if loop.size() >= 3:
			result.append(loop)
	return result


func _shared_boundary_edge_index(value: Variant) -> Dictionary:
	var result := {}
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var edge_id := str(key_variant)
			var row: Variant = (value as Dictionary)[key_variant]
			var points := _shared_edge_points(row)
			if points.size() >= 2:
				result[edge_id] = points
	elif value is Array:
		for row_variant in value as Array:
			if not (row_variant is Dictionary):
				continue
			var row := row_variant as Dictionary
			var edge_id := str(row.get("boundary_id", row.get("edge_id", row.get("id", ""))))
			var points := _shared_edge_points(row)
			if not edge_id.is_empty() and points.size() >= 2:
				result[edge_id] = points
	return result


func _shared_edge_points(value: Variant) -> Array[Vector3]:
	var points_value: Variant = value
	if value is Dictionary:
		var row := value as Dictionary
		points_value = row.get("points_unit_sphere", row.get("points", []))
	return _vector3_array(points_value)


func _shared_edge_boundary_lods(base_value: Variant, edge_index: Dictionary) -> Dictionary:
	var near := _ordered_shared_edge_loops(
		_boundary_edge_ids(base_value, "near", edge_index),
		edge_index
	)
	if near.is_empty():
		return {}
	var medium := _ordered_shared_edge_loops(
		_boundary_edge_ids(base_value, "medium", edge_index),
		edge_index
	)
	if medium.is_empty():
		medium = near.duplicate(true)
	var far := _ordered_shared_edge_loops(
		_boundary_edge_ids(base_value, "far", edge_index),
		edge_index
	)
	if far.is_empty():
		far = medium.duplicate(true)
	return {
		"far": far,
		"medium": medium,
		"near": near,
		"source": "shared_boundary_edges.points_unit_sphere",
	}


func _boundary_edge_ids(base_value: Variant, lod_name: String, edge_index: Dictionary) -> Array:
	var candidate: Variant = []
	if base_value is Dictionary:
		var base := base_value as Dictionary
		var by_lod: Variant = base.get("boundary_edge_id_lods", {})
		if by_lod is Dictionary:
			candidate = (by_lod as Dictionary).get(lod_name, [])
		if _id_sequence(candidate).is_empty():
			candidate = base.get("shared_boundary_edge_ids", [])
		if _id_sequence(candidate).is_empty():
			var keyed_ids: Array = []
			for key_variant in base.keys():
				if edge_index.has(str(key_variant)):
					keyed_ids.append(str(key_variant))
			candidate = keyed_ids
	else:
		candidate = base_value
	var result: Array = []
	for edge_id_variant in _id_sequence(candidate):
		var edge_id := str(edge_id_variant)
		if edge_index.has(edge_id) and not result.has(edge_id):
			result.append(edge_id)
	result.sort()
	return result


func _id_sequence(value: Variant) -> Array:
	var result: Array = []
	if value is Array or value is PackedStringArray:
		for item in value:
			result.append(item)
	elif value is StringName or value is String:
		result.append(str(value))
	return result


func _ordered_shared_edge_loops(edge_ids: Array, edge_index: Dictionary) -> Array:
	var remaining: Array = []
	for edge_id_variant in edge_ids:
		var edge_id := str(edge_id_variant)
		var points := _vector3_array(edge_index.get(edge_id, []))
		if points.size() >= 2:
			remaining.append({"edge_id": edge_id, "points": points})
	remaining.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("edge_id", "")) < str(right.get("edge_id", ""))
	)
	var result: Array = []
	while not remaining.is_empty():
		var first := remaining.pop_front() as Dictionary
		var chain := _vector3_array(first.get("points", []))
		var guard := 0
		while (
			chain.size() >= 2
			and not _boundary_points_match(chain[0], chain[chain.size() - 1])
			and not remaining.is_empty()
			and guard <= edge_ids.size()
		):
			guard += 1
			var match_index := -1
			var reverse_match := false
			for candidate_index in range(remaining.size()):
				var candidate := remaining[candidate_index] as Dictionary
				var candidate_points := _vector3_array(candidate.get("points", []))
				if candidate_points.size() < 2:
					continue
				if _boundary_points_match(chain[chain.size() - 1], candidate_points[0]):
					match_index = candidate_index
					break
				if _boundary_points_match(
					chain[chain.size() - 1],
					candidate_points[candidate_points.size() - 1]
				):
					match_index = candidate_index
					reverse_match = true
					break
			if match_index < 0:
				break
			var matched := remaining[match_index] as Dictionary
			var matched_points := _vector3_array(matched.get("points", []))
			if reverse_match:
				matched_points.reverse()
			for point_index in range(1, matched_points.size()):
				chain.append(matched_points[point_index])
			remaining.remove_at(match_index)
		if (
			chain.size() >= 4
			and _boundary_points_match(chain[0], chain[chain.size() - 1])
		):
			chain.remove_at(chain.size() - 1)
			if chain.size() >= 3:
				result.append(chain)
	result.sort_custom(func(left: Array, right: Array) -> bool:
		return left.size() > right.size()
	)
	return result


func _boundary_points_match(left: Vector3, right: Vector3) -> bool:
	return left.distance_squared_to(right) <= 0.000000000001


func _microgrid_vertices(receipt: Dictionary) -> Array[Vector3]:
	var microgrid_value: Variant = receipt.get("microgrid", {})
	if not (microgrid_value is Dictionary):
		return []
	return _vector3_array(
		(microgrid_value as Dictionary).get("vertices_unit_sphere", [])
	)


func _hit_test_cells(receipt: Dictionary, region_ids: Array, terrain: Dictionary, membership: Dictionary) -> Array:
	var centers_source: Variant = _microcell_centers_source(receipt)
	var microgrid := _microgrid_dictionary(receipt)
	var microcells_value: Variant = receipt.get("microcells", [])
	if not _collection_has_values(microcells_value):
		microcells_value = microgrid.get("microcells", [])
	var result: Array = []
	for region_index in range(region_ids.size()):
		var region_id := str(region_ids[region_index])
		for cell_id_variant in membership.get(region_id, []) as Array:
			var cell_key := str(cell_id_variant)
			var cell_index := int(cell_id_variant) if cell_key.is_valid_int() else -1
			var center_value: Variant = _indexed_value(
				centers_source,
				cell_key,
				cell_index,
				null
			)
			if center_value == null:
				var cell_value: Variant = _indexed_value(
					microcells_value,
					cell_key,
					cell_index,
					null
				)
				if cell_value is Dictionary:
					var cell := cell_value as Dictionary
					center_value = cell.get(
						"center_unit_sphere",
						cell.get("unit_center", Vector3.ZERO)
					)
			var unit := _as_vector3(center_value).normalized()
			if unit.length_squared() < 0.9:
				continue
			result.append({
				"microcell_id": cell_key,
				"unit_sphere": unit,
				"region_id": region_id,
				"region_index": region_index,
				"terrain_class": str(terrain.get(region_id, "")),
			})
	return result


func _microcell_centers_source(receipt: Dictionary) -> Variant:
	var top_level: Variant = receipt.get("microcell_centers_unit_sphere", {})
	if _collection_has_values(top_level):
		return top_level
	return _microgrid_dictionary(receipt).get(
		"microcell_centers_unit_sphere",
		{}
	)


func _microcell_center_source_name(receipt: Dictionary) -> String:
	if _collection_has_values(receipt.get("microcell_centers_unit_sphere", {})):
		return "microcell_centers_unit_sphere"
	if _collection_has_values(
		_microgrid_dictionary(receipt).get("microcell_centers_unit_sphere", {})
	):
		return "microgrid.microcell_centers_unit_sphere"
	return "none"


func _microgrid_dictionary(receipt: Dictionary) -> Dictionary:
	var value: Variant = receipt.get("microgrid", {})
	return value as Dictionary if value is Dictionary else {}


func _collection_has_values(value: Variant) -> bool:
	if value is Array or value is Dictionary:
		return value.size() > 0
	if value is PackedVector3Array or value is PackedStringArray:
		return value.size() > 0
	return false


func _public_facility_markers(public_projection: Dictionary, centers: Dictionary) -> Array:
	var rows := _projection_rows(public_projection, "public_facility_slots")
	var result: Array = []
	var ordinal_by_region := {}
	var ordered_rows: Array = []
	for row_variant in rows:
		if row_variant is Dictionary:
			ordered_rows.append((row_variant as Dictionary).duplicate(true))
	ordered_rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return _facility_marker_identity(left) < _facility_marker_identity(right)
	)
	for row_variant in ordered_rows:
		if not (row_variant is Dictionary):
			continue
		var row := (row_variant as Dictionary).duplicate(true)
		var facility := row.get("facility", {}) as Dictionary
		var occupancy := str(row.get("occupancy", "occupied" if not facility.is_empty() else "empty"))
		if occupancy != "occupied":
			continue
		row.merge(facility, false)
		var facility_type := str(row.get("facility_type", ""))
		if not FACILITY_ASSET_KEYS.has(facility_type):
			continue
		var region_id := str(row.get("region_id", ""))
		if not centers.has(region_id):
			continue
		var ordinal := int(ordinal_by_region.get(region_id, 0))
		ordinal_by_region[region_id] = ordinal + 1
		var center := _as_vector3(centers.get(region_id, Vector3.RIGHT)).normalized()
		var marker_unit := _offset_unit(center, ordinal)
		var industry_id := str(row.get("industry_id", "industry"))
		var slot_id := str(row.get("slot_id", ""))
		var facility_id := str(row.get("facility_id", ""))
		var marker_id := facility_id if not facility_id.is_empty() else slot_id
		if marker_id.is_empty():
			marker_id = "%s|%s|%s|%d" % [region_id, facility_type, industry_id, ordinal]
		var damage_points := int(row.get("damage_points", 0))
		result.append({
			"position": _world_from_unit(marker_unit),
			"position_unit_sphere": marker_unit,
			"tag": str(FACILITY_TAGS.get(facility_type, "?")),
			"level": maxi(1, int(row.get("rank", 1))),
			"products": [industry_id],
			"tag_color": Color(str(INDUSTRY_COLORS.get(industry_id, "#38bdf8"))),
			"active": damage_points <= 0,
			"asset_key": str(FACILITY_ASSET_KEYS.get(facility_type, "")),
			"facility_type": facility_type,
			"shape_kind": facility_type,
			"marker_id": marker_id,
			"facility_id": facility_id,
			"slot_id": slot_id,
			"region_id": region_id,
			"industry_id": industry_id,
			"owner_public_id": str(row.get("owner_public_id", row.get("owner_id", ""))),
			"public_capacity": row.get("public_capacity", row.get("capacity", null)),
			"public_ingress_throughput": row.get("public_ingress_throughput", row.get("ingress_throughput", null)),
			"public_egress_throughput": row.get("public_egress_throughput", row.get("egress_throughput", null)),
			"solar_efficiency_state": str(row.get("solar_efficiency_state", "")),
			"damage_points": damage_points,
			"damage_revision": int(row.get("damage_revision", 0)),
			"visual_revision": int(row.get("slot_generation", row.get("facility_generation", 0))),
			"damage_state": "DAMAGED" if damage_points > 0 else "HEALTHY",
		})
	return result


func _facility_marker_identity(row: Dictionary) -> String:
	var facility_id := str(row.get("facility_id", ""))
	if not facility_id.is_empty():
		return "facility|%s" % facility_id
	var slot_id := str(row.get("slot_id", ""))
	if not slot_id.is_empty():
		return "slot|%s" % slot_id
	return "%s|%s|%s" % [
		str(row.get("region_id", "")),
		str(row.get("facility_type", "")),
		str(row.get("industry_id", "")),
	]


func _public_unit_markers(public_projection: Dictionary, centers: Dictionary) -> Array:
	var result: Array = []
	for source_key in ["monster_public_facts", "military_public_facts"]:
		for row_variant in public_projection.get(source_key, []) as Array:
			if not (row_variant is Dictionary):
				continue
			var row := row_variant as Dictionary
			var region_id := str(row.get("region_id", ""))
			if not centers.has(region_id):
				continue
			var kind := "monster" if source_key.begins_with("monster") else "military"
			result.append({
				"position": _world_from_unit(_as_vector3(centers.get(region_id, Vector3.RIGHT))),
				"name": str(row.get("display_name", kind.capitalize())),
				"label": str(row.get("public_label", kind.capitalize())),
				"glyph": "M" if kind == "monster" else "A",
				"display_subtitle": str(row.get("public_status", "公开单位")),
				"color": Color("#ef4444") if kind == "monster" else Color("#93c5fd"),
				"secondary": Color("#fde68a"),
				"asset_key": str(row.get("asset_key", "model.monster.default" if kind == "monster" else "model.military.tier1")),
				"region_id": region_id,
				"unit_kind": kind,
			})
	return result


func _public_route_markers(public_projection: Dictionary, centers: Dictionary) -> Array:
	var result: Array = []
	for row_variant in public_projection.get("public_routes", []) as Array:
		if not (row_variant is Dictionary):
			continue
		var row := row_variant as Dictionary
		var from_id := str(row.get("from_region_id", ""))
		var to_id := str(row.get("to_region_id", ""))
		if not centers.has(from_id) or not centers.has(to_id):
			continue
		result.append({
			"points": [_world_from_unit(_as_vector3(centers[from_id])), _world_from_unit(_as_vector3(centers[to_id]))],
			"product": str(row.get("commodity_id", "公开路线")),
			"flow_kind": str(row.get("flow_kind", "public")),
			"disrupted": bool(row.get("disrupted", false)),
			"show_marker": true,
			"asset_key": "model.shipping.route_marker",
		})
	return result


func _projection_rows(public_projection: Dictionary, key: String) -> Array:
	if public_projection.has(key) and public_projection.get(key) is Array:
		return public_projection.get(key) as Array
	var facility_contention := public_projection.get("facility_contention", {}) as Dictionary
	return facility_contention.get(key, []) as Array if facility_contention.get(key, []) is Array else []


func _legal_regions(public_projection: Dictionary, selected_card_id: String) -> Dictionary:
	var result := {}
	if selected_card_id.is_empty():
		return result
	for option_variant in public_projection.get("legal_actions", []) as Array:
		if option_variant is Dictionary:
			var option := option_variant as Dictionary
			if str(option.get("card_instance_id", "")) == selected_card_id:
				result[str(option.get("target_region_id", ""))] = true
	return result


func _viewer_index(public_projection: Dictionary) -> int:
	for row_variant in public_projection.get("roster", []) as Array:
		if row_variant is Dictionary and bool((row_variant as Dictionary).get("is_local_player", false)):
			return int((row_variant as Dictionary).get("public_order_index", 0))
	return maxi(0, int(public_projection.get("local_player_index", 0)))


func _current_sun_direction(receipt: Dictionary, public_projection: Dictionary) -> Vector3:
	var solar := public_projection.get("solar_geometry", {}) as Dictionary
	var value: Variant = public_projection.get("sun_direction", solar.get("sun_direction", receipt.get("sun_direction", receipt.get("initial_sun_direction", Vector3.ZERO))))
	return _as_vector3(value).normalized()


func _sun_turn_ppm(direction: Vector3) -> int:
	var angle := fposmod(atan2(direction.z, direction.x), TAU)
	return int(round(angle / TAU * 1_000_000.0)) % 1_000_000


func _display_name(receipt: Dictionary, region_id: String, index: int) -> String:
	var names: Variant = receipt.get("display_names_by_region", {})
	var value := str(_indexed_value(names, region_id, index, ""))
	return value if not value.is_empty() else "区域 %02d" % (index + 1)


func _display_radius(center: Vector3, boundary: Array[Vector3], area_ratio: float) -> float:
	if area_ratio > 0.0:
		return sqrt(area_ratio / PI) * MAP_WIDTH_M
	var max_angle := 0.0
	for point in boundary:
		max_angle = maxf(max_angle, acos(clampf(center.dot(point.normalized()), -1.0, 1.0)))
	return maxf(12.0, max_angle / TAU * MAP_WIDTH_M)


func _offset_unit(center: Vector3, ordinal: int) -> Vector3:
	if ordinal <= 0:
		return center
	var tangent := center.cross(Vector3.UP)
	if tangent.length_squared() < 0.01:
		tangent = center.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	var bitangent := center.cross(tangent).normalized()
	var angle := float(ordinal) * 2.39996323
	var offset := tangent * cos(angle) + bitangent * sin(angle)
	return (center * cos(0.032) + offset * sin(0.032)).normalized()


func _region_color(terrain: String, index: int) -> Color:
	var colors := LAND_PALETTE if terrain == "land" else OCEAN_PALETTE
	return colors[index % colors.size()]


func _adjacency_dictionary(value: Variant, region_ids: Array) -> Dictionary:
	var result := {}
	for index in range(region_ids.size()):
		var region_id := str(region_ids[index])
		var entries := _array_value(_indexed_value(value, region_id, index, []))
		var normalized: Array = []
		for neighbor in entries:
			var neighbor_id := str(neighbor)
			if neighbor is int and int(neighbor) >= 0 and int(neighbor) < region_ids.size():
				neighbor_id = str(region_ids[int(neighbor)])
			if region_ids.has(neighbor_id) and neighbor_id != region_id and not normalized.has(neighbor_id):
				normalized.append(neighbor_id)
		result[region_id] = normalized
	return result


func _indexed_value(source: Variant, key: String, index: int, fallback: Variant) -> Variant:
	if source is Dictionary:
		var dictionary := source as Dictionary
		if dictionary.has(key):
			return dictionary[key]
		if index >= 0 and dictionary.has(index):
			return dictionary[index]
		if index >= 0 and dictionary.has(str(index)):
			return dictionary[str(index)]
	if source is Array and index >= 0 and index < (source as Array).size():
		return (source as Array)[index]
	return fallback


func _world_from_unit(value: Vector3) -> Vector2:
	var unit := value.normalized()
	var lon := fposmod(atan2(unit.z, unit.x), TAU)
	var lat := asin(clampf(unit.y, -1.0, 1.0))
	return Vector2(lon / TAU * MAP_WIDTH_M, (PI * 0.5 - lat) / PI * MAP_HEIGHT_M)


func _world_polygon(points: Array[Vector3]) -> Array:
	var result: Array = []
	for point in points:
		result.append(_world_from_unit(point))
	return result


func _vector3_array(value: Variant) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if value is PackedVector3Array or value is Array:
		for item in value:
			if not _is_vector3_value(item):
				continue
			var unit := _as_vector3(item).normalized()
			if unit.length_squared() > 0.9:
				result.append(unit)
	return result


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if value is Array or value is PackedStringArray:
		for item in value:
			result.append(str(item))
	return result


func _array_value(value: Variant) -> Array:
	return (value as Array).duplicate(true) if value is Array else []


func _as_vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value as Vector3
	if value is Array and _is_vector3_value(value):
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if value is Dictionary and _is_vector3_value(value):
		var source := value as Dictionary
		return Vector3(
			float(source.get("x", 0.0)),
			float(source.get("y", 0.0)),
			float(source.get("z", 0.0))
		)
	return Vector3.ZERO


func _is_vector3_value(value: Variant) -> bool:
	if value is Vector3:
		return true
	if value is Dictionary:
		var source := value as Dictionary
		return source.has("x") and source.has("y") and source.has("z")
	if value is Array:
		var source := value as Array
		return (
			source.size() >= 3
			and _is_number_value(source[0])
			and _is_number_value(source[1])
			and _is_number_value(source[2])
		)
	return false


func _is_number_value(value: Variant) -> bool:
	var value_type := typeof(value)
	return value_type == TYPE_INT or value_type == TYPE_FLOAT
