@tool
extends RefCounted
class_name V076SphericalMicrogridIndexV1

const StateCodec := preload("res://scripts/v076/simulation/v076_authority_state_codec.gd")

const SCHEMA_VERSION := 1
const TOPOLOGY_LEVEL := 2
const TOPOLOGY_ID := "v076.icosahedron.combinatorial.subdivision2.v1"
const EXPECTED_VERTEX_COUNT := 162
const EXPECTED_FACE_COUNT := 320
const EXPECTED_EDGE_COUNT := 480
const EXPECTED_HALF_EDGE_COUNT := 960
# Sealed after the first engine-computed build. A mismatch fails closed.
const EXPECTED_TOPOLOGY_SHA256 := "5cbd98e4027bc2cfd058c857e1a24a5f7c8c61291f1cb7ae7336bcf6851f6452"

static var _cached_topology: Dictionary = {}


static func build() -> Dictionary:
	if not _cached_topology.is_empty():
		return _cached_topology.duplicate(true)
	var vertex_count := 12
	var faces: Array = _base_faces()
	for _level in range(TOPOLOGY_LEVEL):
		var midpoint_ids := {}
		var next_faces: Array = []
		for face_variant in faces:
			var face := face_variant as Array
			var a := int(face[0])
			var b := int(face[1])
			var c := int(face[2])
			var ab_result := _midpoint_id(a, b, vertex_count, midpoint_ids)
			var ab := int(ab_result.get("vertex_id", -1))
			vertex_count = int(ab_result.get("next_vertex_count", vertex_count))
			var bc_result := _midpoint_id(b, c, vertex_count, midpoint_ids)
			var bc := int(bc_result.get("vertex_id", -1))
			vertex_count = int(bc_result.get("next_vertex_count", vertex_count))
			var ca_result := _midpoint_id(c, a, vertex_count, midpoint_ids)
			var ca := int(ca_result.get("vertex_id", -1))
			vertex_count = int(ca_result.get("next_vertex_count", vertex_count))
			next_faces.append([a, ab, ca])
			next_faces.append([b, bc, ab])
			next_faces.append([c, ca, bc])
			next_faces.append([ab, bc, ca])
		faces = next_faces
	var built := _build_half_edges(vertex_count, faces)
	if not bool(built.get("accepted", false)):
		return built
	var topology := built.get("topology", {}) as Dictionary
	var topology_sha256 := StateCodec.fingerprint(topology)
	if topology_sha256.is_empty():
		return _failure("v076_topology_fingerprint_empty")
	if topology_sha256 != EXPECTED_TOPOLOGY_SHA256:
		return {
			"accepted": false,
			"reason": "v076_topology_seal_mismatch",
			"actual_topology_sha256": topology_sha256,
			"expected_topology_sha256": EXPECTED_TOPOLOGY_SHA256,
		}
	_cached_topology = {
		"accepted": true,
		"reason": "",
		"topology": topology,
		"topology_sha256": topology_sha256,
	}
	return _cached_topology.duplicate(true)


static func _build_half_edges(vertex_count: int, faces: Array) -> Dictionary:
	var half_edges: Array = []
	var directed_lookup := {}
	for face_id in range(faces.size()):
		var face := faces[face_id] as Array
		if face.size() != 3:
			return _failure("v076_topology_face_not_triangle")
		for local_edge in range(3):
			var origin := int(face[local_edge])
			var destination := int(face[(local_edge + 1) % 3])
			var half_edge_id := face_id * 3 + local_edge
			var directed_key := _directed_edge_key(origin, destination)
			if directed_lookup.has(directed_key):
				return _failure("v076_topology_duplicate_directed_edge")
			directed_lookup[directed_key] = half_edge_id
			half_edges.append({
				"half_edge_id": half_edge_id,
				"origin_vertex_id": origin,
				"destination_vertex_id": destination,
				"face_id": face_id,
				"next_half_edge_id": face_id * 3 + ((local_edge + 1) % 3),
				"previous_half_edge_id": face_id * 3 + ((local_edge + 2) % 3),
				"twin_half_edge_id": -1,
			})
	var face_neighbors: Array = []
	for _face_id in range(faces.size()):
		face_neighbors.append([-1, -1, -1])
	for half_edge_id in range(half_edges.size()):
		var row := half_edges[half_edge_id] as Dictionary
		var reverse_key := _directed_edge_key(
			int(row.get("destination_vertex_id", -1)),
			int(row.get("origin_vertex_id", -1))
		)
		if not directed_lookup.has(reverse_key):
			return _failure("v076_topology_open_or_misoriented_edge")
		var twin_id := int(directed_lookup[reverse_key])
		if twin_id == half_edge_id:
			return _failure("v076_topology_self_twin")
		row["twin_half_edge_id"] = twin_id
		half_edges[half_edge_id] = row
		var face_id := int(row.get("face_id", -1))
		var local_edge := half_edge_id % 3
		(face_neighbors[face_id] as Array)[local_edge] = int(
			(half_edges[twin_id] as Dictionary).get("face_id", -1)
		)
	if vertex_count != EXPECTED_VERTEX_COUNT or faces.size() != EXPECTED_FACE_COUNT:
		return _failure("v076_topology_cardinality_mismatch")
	if half_edges.size() != EXPECTED_HALF_EDGE_COUNT:
		return _failure("v076_topology_half_edge_count_mismatch")
	var edge_count := half_edges.size() >> 1
	if edge_count != EXPECTED_EDGE_COUNT or vertex_count - edge_count + faces.size() != 2:
		return _failure("v076_topology_euler_contract_failed")
	for face_neighbors_variant in face_neighbors:
		var neighbors := face_neighbors_variant as Array
		if neighbors.size() != 3 or neighbors.has(-1):
			return _failure("v076_topology_face_neighbor_missing")
		neighbors.sort()
	return {
		"accepted": true,
		"reason": "",
		"topology": {
			"schema_version": SCHEMA_VERSION,
			"topology_id": TOPOLOGY_ID,
			"topology_level": TOPOLOGY_LEVEL,
			"vertex_count": vertex_count,
			"face_count": faces.size(),
			"edge_count": edge_count,
			"half_edge_count": half_edges.size(),
			"faces": faces,
			"face_neighbors": face_neighbors,
			"half_edges": half_edges,
		},
	}


static func _midpoint_id(
	left: int,
	right: int,
	vertex_count: int,
	cache: Dictionary
) -> Dictionary:
	var key := _undirected_edge_key(left, right)
	if cache.has(key):
		return {
			"vertex_id": int(cache[key]),
			"next_vertex_count": vertex_count,
		}
	cache[key] = vertex_count
	return {
		"vertex_id": vertex_count,
		"next_vertex_count": vertex_count + 1,
	}


static func _base_faces() -> Array:
	return [
		[0, 11, 5],
		[0, 5, 1],
		[0, 1, 7],
		[0, 7, 10],
		[0, 10, 11],
		[1, 5, 9],
		[5, 11, 4],
		[11, 10, 2],
		[10, 7, 6],
		[7, 1, 8],
		[3, 9, 4],
		[3, 4, 2],
		[3, 2, 6],
		[3, 6, 8],
		[3, 8, 9],
		[4, 9, 5],
		[2, 4, 11],
		[6, 2, 10],
		[8, 6, 7],
		[9, 8, 1],
	]


static func _undirected_edge_key(left: int, right: int) -> String:
	return "%d:%d" % [mini(left, right), maxi(left, right)]


static func _directed_edge_key(origin: int, destination: int) -> String:
	return "%d>%d" % [origin, destination]


static func _failure(reason: String) -> Dictionary:
	return {"accepted": false, "reason": reason}
