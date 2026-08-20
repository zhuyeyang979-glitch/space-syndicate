@tool
extends RefCounted
class_name V076IntegerGeodesicMetricV1

const StateCodec := preload("res://scripts/v076/simulation/v076_authority_state_codec.gd")
const Microgrid := preload("res://scripts/v076/map/v076_spherical_microgrid_index_v1.gd")

const SCHEMA_VERSION := 2
const METRIC_ID := "v076.sealed_spherical_face_center_arc.mu.v2"
const TARGET_POINT_KIND := "SEALED_SPHERICAL_FACE_CENTER"
const REQUIRED_TOPOLOGY_SHA256 := "5cbd98e4027bc2cfd058c857e1a24a5f7c8c61291f1cb7ae7336bcf6851f6452"
const ARC_CLASS_TABLE_SHA256 := "33ec702946b6d4bb5c417e4203b85ccb4d787547cb543c1f133f9c23ff1d07d5"
const _ARC_CLASS_CODE_SHA256 := "35f5d9a490f99504b6d6b37a3353b4d4d550c88609e3847b7c56dee49c972897"
const ARC_MICROUNITS_PER_RADIAN := 1_000_000
const MIN_SEGMENT_DISTANCE_MU := 155_593
const MAX_SEGMENT_DISTANCE_MU := 185_653
const _ARC_DISTANCE_A_MU := 155_593
const _ARC_DISTANCE_B_MU := 172_546
const _ARC_DISTANCE_C_MU := 176_001
const _ARC_DISTANCE_D_MU := 177_514
const _ARC_DISTANCE_E_MU := 178_020
const _ARC_DISTANCE_F_MU := 185_653
const _INFINITY_MU := 1 << 60

# One class byte per face-neighbor slot. Faces are in V076 topology order and
# each face's three neighbors are in ascending face-id order. The six values
# are rounded great-circle angles between the exact V074 spherical face
# centers, sealed here as integer microradians. Runtime authority never calls
# float/Vector geometry.
const _ARC_CLASS_CODE_BY_FACE_NEIGHBOR := (
	"ACCDBEDBEADDACCDBEDBEADDACCDBEDBEADDBBFBBFBBFFFFCACEDBDBEADDCACDBEEDBADDACCDBEDBEADDBBFBBFBBFFFF"
	+ "CACEDBDBEADDCACDBEEDBADDACCDBEDBEADDBBFBBFBBFFFFCACEDBDBEADDCACDBEEDBADDACCDBEDBEADDBBFBBFBBFFFF"
	+ "CCAEDBEDBADDCACDBEEDBADDCACEDBDBEADDBBFBBFBBFFFFCACEDBDBEADDCACDBEEDBADDACCDBEDBEADDBBFBBFBBFFFF"
	+ "CACEDBDBEADDCACDBEEDBADDACCDBEDBEADDBBFBBFBBFFFFCACEDBDBEADDCACDBEEDBADDACCDBEDBEADDBBFBBFBBFFFF"
	+ "CACEDBDBEADDCACDBEEDBADDACCDBEDBEADDBBFBBFBBFFFFCACEDBDBEADDCACDBEEDBADDACCDBEDBEADDBBFBBFBBFFFF"
	+ "ACCDBEDBEADDACCDBEDBEADDACCDBEDBEADDBBFBBFBBFFFFCACEDBDBEADDCACDBEEDBADDACCDBEDBEADDBBFBBFBBFFFF"
	+ "CACEDBDBEADDCACDBEEDBADDACCDBEDBEADDBBFBBFBBFFFFCACEDBDBEADDCACDBEEDBADDACCDBEDBEADDBBFBBFBBFFFF"
	+ "CCAEDBEDBADDCACDBEEDBADDCACEDBDBEADDBBFBBFBBFFFFCCAEDBEDBADDCCAEDBEDBADDCCAEDBEDBADDBBFBBFBBFFFF"
	+ "CCAEDBEDBADDCCAEDBEDBADDCCAEDBEDBADDBBFBBFBBFFFFCCAEDBEDBADDCCAEDBEDBADDCCAEDBEDBADDBBFBBFBBFFFF"
	+ "CCAEDBEDBADDCCAEDBEDBADDCCAEDBEDBADDBBFBBFBBFFFFCCAEDBEDBADDCCAEDBEDBADDCCAEDBEDBADDBBFBBFBBFFFF"
)


static func canonical_target_point(face_id: int) -> Dictionary:
	var topology_result := _build_bound_topology()
	if not bool(topology_result.get("accepted", false)):
		return topology_result
	var topology := topology_result.get("topology", {}) as Dictionary
	var faces := topology.get("faces", []) as Array
	if face_id < 0 or face_id >= faces.size():
		return _failure("v076_monster_target_point_face_out_of_range")
	var projection := {
		"schema_version": SCHEMA_VERSION,
		"point_kind": TARGET_POINT_KIND,
		"projection_rule": "NORMALIZED_EQUAL_WEIGHT_VERTEX_SUM",
		"topology_sha256": REQUIRED_TOPOLOGY_SHA256,
		"face_id": face_id,
		"vertex_ids": (faces[face_id] as Array).duplicate(),
		"barycentric_numerators": [1, 1, 1],
		"barycentric_denominator": 3,
	}
	return {
		"accepted": true,
		"reason": "",
		"target_point": projection,
		"target_point_sha256": StateCodec.fingerprint(projection),
	}


static func validate_target_point(point: Dictionary, expected_face_id: int = -1) -> Dictionary:
	var canonical := canonical_target_point(int(point.get("face_id", -1)))
	if (
		not bool(canonical.get("accepted", false))
		or (expected_face_id >= 0 and int(point.get("face_id", -1)) != expected_face_id)
		or canonical.get("target_point", {}) != point
	):
		return _failure("v076_monster_target_point_noncanonical")
	return {
		"accepted": true,
		"reason": "",
		"target_point_sha256": str(canonical.get("target_point_sha256", "")),
	}


static func build_route(start_face_id: int, target_face_id: int, target_point: Dictionary) -> Dictionary:
	var topology_result := _build_bound_topology()
	if not bool(topology_result.get("accepted", false)):
		return topology_result
	var topology := topology_result.get("topology", {}) as Dictionary
	var face_count := int(topology.get("face_count", 0))
	if start_face_id < 0 or start_face_id >= face_count or target_face_id < 0 or target_face_id >= face_count:
		return _failure("v076_monster_route_face_out_of_range")
	var point_validation := validate_target_point(target_point, target_face_id)
	if not bool(point_validation.get("accepted", false)):
		return point_validation
	var neighbors_by_face := topology.get("face_neighbors", []) as Array
	var distances: Array = []
	var previous: Array = []
	for _face_id in range(face_count):
		distances.append(_INFINITY_MU)
		previous.append(-1)
	distances[start_face_id] = 0
	var frontier: Array = []
	_heap_push(frontier, [0, start_face_id])
	while not frontier.is_empty():
		var entry := _heap_pop(frontier)
		var current_distance_mu := int(entry[0])
		var current_face_id := int(entry[1])
		if current_distance_mu != int(distances[current_face_id]):
			continue
		if current_face_id == target_face_id:
			break
		var neighbors := neighbors_by_face[current_face_id] as Array
		for neighbor_variant in neighbors:
			var neighbor_face_id := int(neighbor_variant)
			var segment_distance_mu := _segment_distance_from_neighbors(current_face_id, neighbor_face_id, neighbors_by_face)
			if segment_distance_mu <= 0:
				return _failure("v076_monster_arc_distance_lookup_failed")
			var candidate_distance_mu := current_distance_mu + segment_distance_mu
			if (
				candidate_distance_mu < int(distances[neighbor_face_id])
				or (
					candidate_distance_mu == int(distances[neighbor_face_id])
					and (int(previous[neighbor_face_id]) < 0 or current_face_id < int(previous[neighbor_face_id]))
				)
			):
				distances[neighbor_face_id] = candidate_distance_mu
				previous[neighbor_face_id] = current_face_id
				_heap_push(frontier, [candidate_distance_mu, neighbor_face_id])
	if int(distances[target_face_id]) == _INFINITY_MU:
		return _failure("v076_monster_route_disconnected")
	var reverse_faces: Array = [target_face_id]
	var trace := target_face_id
	while trace != start_face_id:
		trace = int(previous[trace])
		if trace < 0:
			return _failure("v076_monster_route_predecessor_missing")
		reverse_faces.append(trace)
	reverse_faces.reverse()
	var segment_distances: Array = []
	var total_distance_mu := 0
	for segment_index in range(maxi(0, reverse_faces.size() - 1)):
		var segment_distance_mu := _segment_distance_from_neighbors(
			int(reverse_faces[segment_index]),
			int(reverse_faces[segment_index + 1]),
			neighbors_by_face
		)
		segment_distances.append(segment_distance_mu)
		total_distance_mu += segment_distance_mu
	var projection := {
		"schema_version": SCHEMA_VERSION,
		"metric_id": METRIC_ID,
		"topology_sha256": REQUIRED_TOPOLOGY_SHA256,
		"arc_class_table_sha256": ARC_CLASS_TABLE_SHA256,
		"start_face_id": start_face_id,
		"target_face_id": target_face_id,
		"target_point": target_point.duplicate(true),
		"face_path": reverse_faces,
		"segment_distance_mu_by_index": segment_distances,
		"segment_count": segment_distances.size(),
		"total_distance_mu": total_distance_mu,
	}
	return {
		"accepted": true,
		"reason": "",
		"route": projection,
		"route_sha256": StateCodec.fingerprint(projection),
	}


static func validate_route(route: Dictionary, expected_sha256: String = "") -> Dictionary:
	var fields := [
		"schema_version", "metric_id", "topology_sha256", "arc_class_table_sha256",
		"start_face_id", "target_face_id", "target_point", "face_path",
		"segment_distance_mu_by_index", "segment_count", "total_distance_mu",
	]
	if not _has_exact_fields(route, fields):
		return _failure("v076_monster_route_shape_invalid")
	if (
		typeof(route.get("schema_version")) != TYPE_INT
		or int(route.get("schema_version", 0)) != SCHEMA_VERSION
		or str(route.get("metric_id", "")) != METRIC_ID
		or str(route.get("topology_sha256", "")) != REQUIRED_TOPOLOGY_SHA256
		or str(route.get("arc_class_table_sha256", "")) != ARC_CLASS_TABLE_SHA256
		or not (route.get("target_point") is Dictionary)
		or not (route.get("face_path") is Array)
		or not (route.get("segment_distance_mu_by_index") is Array)
	):
		return _failure("v076_monster_route_contract_mismatch")
	var canonical := build_route(
		int(route.get("start_face_id", -1)),
		int(route.get("target_face_id", -1)),
		route.get("target_point", {}) as Dictionary
	)
	if not bool(canonical.get("accepted", false)) or canonical.get("route", {}) != route:
		return _failure("v076_monster_route_noncanonical")
	var actual_sha256 := StateCodec.fingerprint(route)
	if actual_sha256.is_empty() or (not expected_sha256.is_empty() and actual_sha256 != expected_sha256):
		return _failure("v076_monster_route_sha_mismatch")
	return {"accepted": true, "reason": "", "route_sha256": actual_sha256}


static func segment_distance_at(route: Dictionary, segment_index: int) -> int:
	var distances := route.get("segment_distance_mu_by_index", []) as Array
	return int(distances[segment_index]) if segment_index >= 0 and segment_index < distances.size() else -1


static func distance_before_segment(route: Dictionary, segment_index: int) -> int:
	var distances := route.get("segment_distance_mu_by_index", []) as Array
	if segment_index < 0 or segment_index > distances.size():
		return -1
	var total := 0
	for index in range(segment_index):
		total += int(distances[index])
	return total


static func segment_midpoint_mu(segment_distance_mu: int) -> int:
	@warning_ignore("integer_division")
	return segment_distance_mu / 2


static func interval_region_distance(
	from_face_id: int,
	to_face_id: int,
	segment_distance_mu: int,
	start_progress_mu: int,
	end_progress_mu: int,
	owner_by_face: Array
) -> Dictionary:
	if (
		from_face_id < 0 or from_face_id >= owner_by_face.size()
		or to_face_id < 0 or to_face_id >= owner_by_face.size()
		or segment_distance_mu < MIN_SEGMENT_DISTANCE_MU or segment_distance_mu > MAX_SEGMENT_DISTANCE_MU
		or start_progress_mu < 0 or end_progress_mu < start_progress_mu
		or end_progress_mu > segment_distance_mu
	):
		return _failure("v076_monster_segment_interval_invalid")
	var midpoint_mu := segment_midpoint_mu(segment_distance_mu)
	var source_distance := maxi(0, mini(end_progress_mu, midpoint_mu) - start_progress_mu)
	var destination_distance := maxi(0, end_progress_mu - maxi(start_progress_mu, midpoint_mu))
	var by_region := {}
	var source_region := int(owner_by_face[from_face_id])
	var destination_region := int(owner_by_face[to_face_id])
	if source_distance > 0:
		by_region[str(source_region)] = source_distance
	if destination_distance > 0:
		var destination_key := str(destination_region)
		by_region[destination_key] = int(by_region.get(destination_key, 0)) + destination_distance
	return {
		"accepted": true,
		"reason": "",
		"distance_by_region_mu": by_region,
		"crossed_region_boundary": (
			source_region != destination_region
			and start_progress_mu < midpoint_mu
			and end_progress_mu >= midpoint_mu
		),
	}


static func _build_bound_topology() -> Dictionary:
	var arc_definition := "A=%d;B=%d;C=%d;D=%d;E=%d;F=%d;CODE=%s" % [
		_ARC_DISTANCE_A_MU,
		_ARC_DISTANCE_B_MU,
		_ARC_DISTANCE_C_MU,
		_ARC_DISTANCE_D_MU,
		_ARC_DISTANCE_E_MU,
		_ARC_DISTANCE_F_MU,
		_ARC_CLASS_CODE_BY_FACE_NEIGHBOR,
	]
	if (
		_ARC_CLASS_CODE_BY_FACE_NEIGHBOR.length() != 960
		or _ARC_CLASS_CODE_BY_FACE_NEIGHBOR.sha256_text() != _ARC_CLASS_CODE_SHA256
		or arc_definition.sha256_text() != ARC_CLASS_TABLE_SHA256
	):
		return _failure("v076_monster_arc_class_table_seal_mismatch")
	var topology_result := Microgrid.build()
	if not bool(topology_result.get("accepted", false)):
		return _failure(str(topology_result.get("reason", "v076_monster_topology_build_failed")))
	if str(topology_result.get("topology_sha256", "")) != REQUIRED_TOPOLOGY_SHA256:
		return _failure("v076_monster_topology_binding_mismatch")
	var topology := topology_result.get("topology", {}) as Dictionary
	var neighbors_by_face := topology.get("face_neighbors", []) as Array
	if neighbors_by_face.size() != 320:
		return _failure("v076_monster_arc_neighbor_cardinality_mismatch")
	for face_id in range(neighbors_by_face.size()):
		var neighbors := neighbors_by_face[face_id] as Array
		if neighbors.size() != 3:
			return _failure("v076_monster_arc_neighbor_degree_mismatch")
		for neighbor_variant in neighbors:
			var neighbor_face_id := int(neighbor_variant)
			var forward_distance_mu := _segment_distance_from_neighbors(face_id, neighbor_face_id, neighbors_by_face)
			var reverse_distance_mu := _segment_distance_from_neighbors(neighbor_face_id, face_id, neighbors_by_face)
			if forward_distance_mu <= 0 or forward_distance_mu != reverse_distance_mu:
				return _failure("v076_monster_arc_distance_symmetry_mismatch")
	return topology_result


static func _segment_distance_from_neighbors(from_face_id: int, to_face_id: int, neighbors_by_face: Array) -> int:
	if from_face_id < 0 or from_face_id >= neighbors_by_face.size():
		return -1
	var neighbors := neighbors_by_face[from_face_id] as Array
	var neighbor_slot := neighbors.find(to_face_id)
	if neighbor_slot < 0 or neighbors.size() != 3:
		return -1
	var code := _ARC_CLASS_CODE_BY_FACE_NEIGHBOR.unicode_at(from_face_id * 3 + neighbor_slot)
	match code:
		65:
			return _ARC_DISTANCE_A_MU
		66:
			return _ARC_DISTANCE_B_MU
		67:
			return _ARC_DISTANCE_C_MU
		68:
			return _ARC_DISTANCE_D_MU
		69:
			return _ARC_DISTANCE_E_MU
		70:
			return _ARC_DISTANCE_F_MU
		_:
			return -1


static func _heap_push(heap: Array, entry: Array) -> void:
	heap.append(entry)
	var index := heap.size() - 1
	while index > 0:
		@warning_ignore("integer_division")
		var parent := (index - 1) / 2
		if not _entry_before(entry, heap[parent] as Array):
			break
		heap[index] = heap[parent]
		index = parent
	heap[index] = entry


static func _heap_pop(heap: Array) -> Array:
	var result := heap[0] as Array
	var tail := heap.pop_back() as Array
	if heap.is_empty():
		return result
	var index := 0
	while true:
		var left := index * 2 + 1
		if left >= heap.size():
			break
		var right := left + 1
		var child := left
		if right < heap.size() and _entry_before(heap[right] as Array, heap[left] as Array):
			child = right
		if not _entry_before(heap[child] as Array, tail):
			break
		heap[index] = heap[child]
		index = child
	heap[index] = tail
	return result


static func _entry_before(left: Array, right: Array) -> bool:
	return int(left[0]) < int(right[0]) or (int(left[0]) == int(right[0]) and int(left[1]) < int(right[1]))


static func _has_exact_fields(value: Dictionary, fields: Array) -> bool:
	if value.size() != fields.size():
		return false
	for field_name in fields:
		if not value.has(field_name):
			return false
	return true


static func _failure(reason: String) -> Dictionary:
	return {"accepted": false, "reason": reason}
