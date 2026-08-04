extends RefCounted
class_name V074GeodesicMicrogrid

const GRID_SCHEMA := "V074GeodesicMicrogridV1"
const MIN_SUBDIVISION := 1
const MAX_SUBDIVISION := 4


static func build(subdivision: int) -> Dictionary:
	if subdivision < MIN_SUBDIVISION or subdivision > MAX_SUBDIVISION:
		return {
			"accepted": false,
			"reason_code": "geodesic_microgrid_subdivision_unsupported",
		}
	var vertices := _base_vertices()
	var faces := _base_faces()
	for _level in range(subdivision):
		var midpoint_cache := {}
		var next_faces: Array = []
		for face_variant in faces:
			var face := face_variant as Array
			var a := int(face[0])
			var b := int(face[1])
			var c := int(face[2])
			var ab := _midpoint_index(a, b, vertices, midpoint_cache)
			var bc := _midpoint_index(b, c, vertices, midpoint_cache)
			var ca := _midpoint_index(c, a, vertices, midpoint_cache)
			next_faces.append([a, ab, ca])
			next_faces.append([b, bc, ab])
			next_faces.append([c, ca, bc])
			next_faces.append([ab, bc, ca])
		faces = next_faces
	var topology := _build_topology(vertices, faces)
	if not bool(topology.get("accepted", false)):
		return topology
	var result := {
		"accepted": true,
		"reason_code": "geodesic_microgrid_ready",
		"schema": GRID_SCHEMA,
		"subdivision": subdivision,
		"vertices_unit_sphere": vertices,
		"microcell_vertex_ids": faces,
		"microcell_centers_unit_sphere": topology.get("face_centers", []),
		"microcell_areas_steradians": topology.get("face_areas", []),
		"microcell_adjacency": topology.get("face_adjacency", []),
		"edge_faces": topology.get("edge_faces", {}),
		"edge_vertex_ids": topology.get("edge_vertex_ids", {}),
		"vertex_count": vertices.size(),
		"microcell_count": faces.size(),
		"edge_count": int((topology.get("edge_faces", {}) as Dictionary).size()),
		"closed_edge_count": int(topology.get("closed_edge_count", 0)),
		"nonmanifold_edge_count": int(topology.get("nonmanifold_edge_count", 0)),
		"surface_area_steradians": float(topology.get("surface_area_steradians", 0.0)),
	}
	result["grid_fingerprint"] = fingerprint(result)
	return result


static func fingerprint(grid: Dictionary) -> String:
	var rows := PackedStringArray([
		GRID_SCHEMA,
		str(grid.get("subdivision", -1)),
		str(grid.get("vertex_count", 0)),
		str(grid.get("microcell_count", 0)),
	])
	for vertex_variant in grid.get("vertices_unit_sphere", []) as Array:
		var vertex := vertex_variant as Vector3
		rows.append("%d,%d,%d" % [
			roundi(vertex.x * 1000000000.0),
			roundi(vertex.y * 1000000000.0),
			roundi(vertex.z * 1000000000.0),
		])
	for face_variant in grid.get("microcell_vertex_ids", []) as Array:
		var face := face_variant as Array
		rows.append("%d,%d,%d" % [int(face[0]), int(face[1]), int(face[2])])
	return "\n".join(rows).sha256_text()


static func _base_vertices() -> Array:
	var t := (1.0 + sqrt(5.0)) * 0.5
	var vertices: Array = [
		Vector3(-1.0, t, 0.0),
		Vector3(1.0, t, 0.0),
		Vector3(-1.0, -t, 0.0),
		Vector3(1.0, -t, 0.0),
		Vector3(0.0, -1.0, t),
		Vector3(0.0, 1.0, t),
		Vector3(0.0, -1.0, -t),
		Vector3(0.0, 1.0, -t),
		Vector3(t, 0.0, -1.0),
		Vector3(t, 0.0, 1.0),
		Vector3(-t, 0.0, -1.0),
		Vector3(-t, 0.0, 1.0),
	]
	for index in range(vertices.size()):
		vertices[index] = (vertices[index] as Vector3).normalized()
	return vertices


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


static func _midpoint_index(
	left: int,
	right: int,
	vertices: Array,
	cache: Dictionary
) -> int:
	var key := edge_key(left, right)
	if cache.has(key):
		return int(cache[key])
	var midpoint := ((vertices[left] as Vector3) + (vertices[right] as Vector3)).normalized()
	var index := vertices.size()
	vertices.append(midpoint)
	cache[key] = index
	return index


static func _build_topology(vertices: Array, faces: Array) -> Dictionary:
	var edge_faces := {}
	var edge_vertex_ids := {}
	var face_adjacency: Array = []
	var face_centers: Array = []
	var face_areas: Array = []
	var surface_area := 0.0
	for face_index in range(faces.size()):
		face_adjacency.append([])
		var face := faces[face_index] as Array
		if face.size() != 3:
			return {
				"accepted": false,
				"reason_code": "geodesic_microgrid_face_invalid",
			}
		var a := vertices[int(face[0])] as Vector3
		var b := vertices[int(face[1])] as Vector3
		var c := vertices[int(face[2])] as Vector3
		face_centers.append((a + b + c).normalized())
		var area := spherical_triangle_area(a, b, c)
		face_areas.append(area)
		surface_area += area
		for pair in [[int(face[0]), int(face[1])], [int(face[1]), int(face[2])], [int(face[2]), int(face[0])]]:
			var key := edge_key(int(pair[0]), int(pair[1]))
			if not edge_faces.has(key):
				edge_faces[key] = []
				edge_vertex_ids[key] = [mini(int(pair[0]), int(pair[1])), maxi(int(pair[0]), int(pair[1]))]
			(edge_faces[key] as Array).append(face_index)
	var closed_edge_count := 0
	var nonmanifold_edge_count := 0
	for key_variant in edge_faces.keys():
		var incident := edge_faces[key_variant] as Array
		if incident.size() == 2:
			closed_edge_count += 1
			var left := int(incident[0])
			var right := int(incident[1])
			(face_adjacency[left] as Array).append(right)
			(face_adjacency[right] as Array).append(left)
		else:
			nonmanifold_edge_count += 1
	for index in range(face_adjacency.size()):
		(face_adjacency[index] as Array).sort()
	if nonmanifold_edge_count > 0:
		return {
			"accepted": false,
			"reason_code": "geodesic_microgrid_not_closed_manifold",
			"nonmanifold_edge_count": nonmanifold_edge_count,
		}
	return {
		"accepted": true,
		"reason_code": "geodesic_microgrid_topology_ready",
		"edge_faces": edge_faces,
		"edge_vertex_ids": edge_vertex_ids,
		"face_adjacency": face_adjacency,
		"face_centers": face_centers,
		"face_areas": face_areas,
		"closed_edge_count": closed_edge_count,
		"nonmanifold_edge_count": nonmanifold_edge_count,
		"surface_area_steradians": surface_area,
	}


static func edge_key(left: int, right: int) -> String:
	return "%d:%d" % [mini(left, right), maxi(left, right)]


static func spherical_triangle_area(a: Vector3, b: Vector3, c: Vector3) -> float:
	var numerator := absf(a.dot(b.cross(c)))
	var denominator := 1.0 + a.dot(b) + b.dot(c) + c.dot(a)
	return 2.0 * atan2(numerator, maxf(0.000000000001, denominator))
