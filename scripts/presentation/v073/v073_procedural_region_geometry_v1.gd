extends RefCounted
class_name V073ProceduralRegionGeometryV1

const PRESENTATION_NAMESPACE := "v073.planet.presentation.geometry.v1"
const MAP_WIDTH_M := 1400.0
const MAP_HEIGHT_M := 950.0
const REGION_IDS := [
	"region.alpha",
	"region.beta",
	"region.gamma",
	"region.delta",
	"region.epsilon",
	"region.zeta",
]
const REGION_NAMES := ["阿尔法", "贝塔", "伽马", "德尔塔", "艾普西隆", "泽塔"]
const BASE_SITES := [
	Vector2(0.22, 0.27),
	Vector2(0.34, 0.50),
	Vector2(0.22, 0.73),
	Vector2(0.78, 0.27),
	Vector2(0.66, 0.50),
	Vector2(0.78, 0.73),
]
const MODULUS := 2147483647


static func build(match_seed: int) -> Dictionary:
	var sites := _build_sites(match_seed)
	var districts: Array = []
	for index in range(REGION_IDS.size()):
		var polygon := _voronoi_polygon(index, sites)
		var area := absf(_polygon_area(polygon))
		var center := _polygon_centroid(polygon)
		districts.append({
			"region_id": REGION_IDS[index],
			"name": REGION_NAMES[index],
			"center": center,
			"polygon": polygon,
			"area_m2": area,
			"radius_m": sqrt(maxf(1.0, area) / PI),
			"neighbors": [],
			"terrain": "surface",
			"hp": 0,
			"panic": 0,
			"products": [],
			"destroyed": false,
		})
	_assign_neighbors(districts)
	return {
		"schema": "V073ProceduralRegionGeometryV1",
		"namespace": PRESENTATION_NAMESPACE,
		"match_seed": match_seed,
		"width_m": MAP_WIDTH_M,
		"height_m": MAP_HEIGHT_M,
		"districts": districts,
		"fingerprint": fingerprint(districts),
		"gameplay_rng_draw_count": 0,
	}


static func fingerprint(districts: Array) -> String:
	var rows := PackedStringArray()
	for district_variant in districts:
		var district := district_variant as Dictionary
		var points := PackedStringArray()
		for point_variant in district.get("polygon", []) as Array:
			var point := point_variant as Vector2
			points.append("%d,%d" % [roundi(point.x * 1000.0), roundi(point.y * 1000.0)])
		rows.append("%s|%s|%s" % [
			str(district.get("region_id", "")),
			";".join(points),
			",".join(PackedStringArray((district.get("neighbors", []) as Array).map(func(value: Variant) -> String: return str(value)))),
		])
	return "\n".join(rows).sha256_text()


static func audit(districts: Array) -> Dictionary:
	var ids := {}
	var duplicate_count := 0
	var nonfinite_count := 0
	var self_intersection_count := 0
	for district_variant in districts:
		var district := district_variant as Dictionary
		var region_id := str(district.get("region_id", ""))
		if ids.has(region_id):
			duplicate_count += 1
		ids[region_id] = true
		var polygon := district.get("polygon", []) as Array
		for point_variant in polygon:
			if not (point_variant is Vector2):
				nonfinite_count += 1
				continue
			var point := point_variant as Vector2
			if not is_finite(point.x) or not is_finite(point.y):
				nonfinite_count += 1
		if _polygon_self_intersects(polygon):
			self_intersection_count += 1
	return {
		"region_count": districts.size(),
		"region_id_duplicate_count": duplicate_count,
		"geometry_nonfinite_count": nonfinite_count,
		"polygon_self_intersection_count": self_intersection_count,
	}


static func _build_sites(match_seed: int) -> Array:
	var sites: Array = []
	for index in range(BASE_SITES.size()):
		var base := BASE_SITES[index] as Vector2
		var jitter_x := (_unit_value(match_seed, index, 17) - 0.5) * 0.105
		var jitter_y := (_unit_value(match_seed, index, 53) - 0.5) * 0.090
		var normalized := Vector2(
			clampf(base.x + jitter_x, 0.10, 0.90),
			clampf(base.y + jitter_y, 0.12, 0.88)
		)
		sites.append(Vector2(normalized.x * MAP_WIDTH_M, normalized.y * MAP_HEIGHT_M))
	return sites


static func _unit_value(match_seed: int, index: int, salt: int) -> float:
	var value := posmod(match_seed, MODULUS)
	value = posmod(value * 48271 + (index + 1) * 69621 + salt * 31337, MODULUS)
	value = posmod(value * 40692 + 127773, MODULUS)
	return float(value) / float(MODULUS)


static func _voronoi_polygon(site_index: int, sites: Array) -> Array:
	var polygon: Array = [
		Vector2.ZERO,
		Vector2(MAP_WIDTH_M, 0.0),
		Vector2(MAP_WIDTH_M, MAP_HEIGHT_M),
		Vector2(0.0, MAP_HEIGHT_M),
	]
	var site := sites[site_index] as Vector2
	for index in range(sites.size()):
		if index != site_index:
			polygon = _clip_polygon(polygon, site, sites[index] as Vector2)
	return polygon


static func _clip_polygon(polygon: Array, site: Vector2, other: Vector2) -> Array:
	var result: Array = []
	var normal := other - site
	var midpoint := (site + other) * 0.5
	for index in range(polygon.size()):
		var current := polygon[index] as Vector2
		var next := polygon[(index + 1) % polygon.size()] as Vector2
		var current_inside := (current - midpoint).dot(normal) <= 0.001
		var next_inside := (next - midpoint).dot(normal) <= 0.001
		if current_inside and next_inside:
			result.append(next)
		elif current_inside != next_inside:
			var direction := next - current
			var denominator := direction.dot(normal)
			var intersection := current
			if absf(denominator) > 0.001:
				intersection = current + direction * clampf(
					-((current - midpoint).dot(normal)) / denominator,
					0.0,
					1.0
				)
			result.append(intersection)
			if next_inside:
				result.append(next)
	return result


static func _assign_neighbors(districts: Array) -> void:
	for index in range(districts.size()):
		var rows: Array = []
		var center := (districts[index] as Dictionary).get("center", Vector2.ZERO) as Vector2
		for other in range(districts.size()):
			if other == index:
				continue
			var other_center := (districts[other] as Dictionary).get("center", Vector2.ZERO) as Vector2
			rows.append({"index": other, "distance": center.distance_squared_to(other_center)})
		rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			return float(left.get("distance", INF)) < float(right.get("distance", INF))
		)
		var neighbors: Array = []
		for row_variant in rows.slice(0, mini(3, rows.size())):
			neighbors.append(int((row_variant as Dictionary).get("index", -1)))
		(districts[index] as Dictionary)["neighbors"] = neighbors
	for index in range(districts.size()):
		for neighbor_variant in (districts[index] as Dictionary).get("neighbors", []) as Array:
			var neighbor := int(neighbor_variant)
			if neighbor < 0 or neighbor >= districts.size():
				continue
			var reverse := (districts[neighbor] as Dictionary).get("neighbors", []) as Array
			if not reverse.has(index):
				reverse.append(index)
				(districts[neighbor] as Dictionary)["neighbors"] = reverse


static func _polygon_area(polygon: Array) -> float:
	var area := 0.0
	for index in range(polygon.size()):
		var current := polygon[index] as Vector2
		var next := polygon[(index + 1) % polygon.size()] as Vector2
		area += current.x * next.y - next.x * current.y
	return area * 0.5


static func _polygon_centroid(polygon: Array) -> Vector2:
	var signed_area := _polygon_area(polygon)
	if absf(signed_area) <= 0.001:
		var fallback := Vector2.ZERO
		for point_variant in polygon:
			fallback += point_variant as Vector2
		return fallback / maxf(1.0, float(polygon.size()))
	var cx := 0.0
	var cy := 0.0
	for index in range(polygon.size()):
		var current := polygon[index] as Vector2
		var next := polygon[(index + 1) % polygon.size()] as Vector2
		var cross := current.x * next.y - next.x * current.y
		cx += (current.x + next.x) * cross
		cy += (current.y + next.y) * cross
	return Vector2(cx, cy) / (6.0 * signed_area)


static func _polygon_self_intersects(polygon: Array) -> bool:
	if polygon.size() < 3:
		return true
	for first in range(polygon.size()):
		var first_next := (first + 1) % polygon.size()
		for second in range(first + 1, polygon.size()):
			var second_next := (second + 1) % polygon.size()
			if first == second or first_next == second or second_next == first:
				continue
			if _segments_intersect(
				polygon[first] as Vector2,
				polygon[first_next] as Vector2,
				polygon[second] as Vector2,
				polygon[second_next] as Vector2
			):
				return true
	return false


static func _segments_intersect(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var ab_c := (b - a).cross(c - a)
	var ab_d := (b - a).cross(d - a)
	var cd_a := (d - c).cross(a - c)
	var cd_b := (d - c).cross(b - c)
	return ab_c * ab_d < -0.0001 and cd_a * cd_b < -0.0001
