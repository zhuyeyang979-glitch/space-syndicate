extends RefCounted
class_name SessionStartWorldPlanBuilder

const MovementModel := preload("res://scripts/balance/movement_balance_model.gd")
const ViabilityPolicy := preload("res://scripts/runtime/roguelike_economic_viability_policy.gd")

const SITE_MARGIN_M := 70.0
const NEIGHBOR_COUNT := 4
const OCEAN_RATIO_MIN := 0.26
const OCEAN_RATIO_MAX := 0.40
const DISTRICT_NAMES := ["东京湾", "能源塔", "旧城区", "港口", "地球总部", "商业区", "地下基地", "电视台", "轨道电梯", "月台仓库", "风暴街", "第七码头", "废弃工厂", "研究院", "环城高速", "巨蛋球场", "磁悬浮站", "海滨公园", "地下商场", "天文台", "避难中心", "中央医院", "卫星阵列", "纪念广场", "冷却塔", "军港", "货运枢纽", "水族馆", "数据塔", "旧神社", "工业岛", "玻璃城区"]
const OCEAN_NAMES := ["蓝潮海", "静默洋", "环流海峡", "极光湾", "赤道航道", "深星海盆", "群岛外海", "寒冠洋", "珊瑚环礁", "远洋航门", "月影海", "磁暴海峡"]
const OCEAN_PRODUCTS := ["星鲸罐头", "星鳍鱼群", "蓝潮藻", "巨藻纤维", "风暴珍珠", "深海菌毯", "海底黑油", "钛壳贝", "夜航香蕉", "暗礁珊瑚", "离岸水晶", "潮汐电浆"]


func build_world(depth: int, cursor: Dictionary) -> Dictionary:
	var movement := MovementModel.new()
	var count_range := movement.region_count_range_for_depth(depth)
	var planet := movement.planet_size_for_depth(depth)
	var next_cursor := cursor.duplicate(true)
	var count_draw := RunRngService.detached_randi_range(next_cursor, int(count_range.get("region_min", 6)), int(count_range.get("region_max", 9)))
	if not bool(count_draw.get("ok", false)):
		return count_draw
	next_cursor = _cursor_from_draw(count_draw)
	var width := float(planet.get("width_m", 1400.0))
	var height := float(planet.get("height_m", 950.0))
	var sites_result := _generate_sites(int(count_draw.get("value", 6)), width, height, next_cursor)
	if not bool(sites_result.get("ok", false)):
		return sites_result
	next_cursor = (sites_result.get("cursor", {}) as Dictionary).duplicate(true)
	var sites: Array = sites_result.get("sites", [])
	var districts: Array = []
	for index in range(sites.size()):
		var polygon := _voronoi_polygon(index, sites, width, height)
		if polygon.size() < 3:
			return {"ok": false, "reason_code": "session_start_world_polygon_invalid"}
		var center := _polygon_centroid(polygon)
		var area := maxf(1.0, absf(_polygon_area(polygon)))
		districts.append({"region_id": "region.%03d" % index, "name": DISTRICT_NAMES[index] if index < DISTRICT_NAMES.size() else "第%d区" % (index + 1), "center": center, "polygon": polygon, "area_m2": area, "radius_m": sqrt(area / PI), "hp": 0, "damage": 0, "last_damage_source": "", "last_damage_amount": 0, "last_damage_time": -1.0, "destroyed": false, "miasma": false, "terrain": "land", "terrain_label": "陆地", "products": [], "demands": [], "neighbors": [], "transport_score": 1.0, "city": {}})
	_assign_neighbors(districts, width, height)
	var terrain_result := _assign_terrain_and_goods(districts, next_cursor)
	if not bool(terrain_result.get("ok", false)):
		return terrain_result
	districts = (terrain_result.get("districts", []) as Array).duplicate(true)
	next_cursor = (terrain_result.get("cursor", {}) as Dictionary).duplicate(true)
	var viability := ViabilityPolicy.normalize({"districts": _economic_rows(districts), "catalog_products": ProductMarketRuntimeController.PRODUCT_CATALOG.duplicate(), "terrain_product_pools": {"land": _product_pool("land"), "ocean": OCEAN_PRODUCTS.duplicate()}})
	if not bool(viability.get("ok", false)):
		return {"ok": false, "reason_code": "session_start_world_viability_failed"}
	var normalized: Array = viability.get("districts", [])
	if normalized.size() == districts.size():
		for index in range(districts.size()):
			var district: Dictionary = districts[index]
			district["demands"] = ((normalized[index] as Dictionary).get("demands", []) as Array).duplicate()
			districts[index] = district
	return {"ok": true, "districts": districts, "map_width_m": width, "map_height_m": height, "selected_district": _nearest_to_center(districts, Vector2(width * 0.5, height * 0.5), width, height), "cursor": next_cursor}


func _generate_sites(count: int, width: float, height: float, cursor: Dictionary) -> Dictionary:
	var sites: Array = []
	var attempts := 0
	var next_cursor := cursor.duplicate(true)
	while sites.size() < count and attempts < count * 80:
		attempts += 1
		var x_draw := RunRngService.detached_randf_range(next_cursor, SITE_MARGIN_M, width - SITE_MARGIN_M)
		next_cursor = _cursor_from_draw(x_draw)
		var y_draw := RunRngService.detached_randf_range(next_cursor, SITE_MARGIN_M, height - SITE_MARGIN_M)
		next_cursor = _cursor_from_draw(y_draw)
		var point := Vector2(float(x_draw.get("value", 0.0)), float(y_draw.get("value", 0.0)))
		var too_close := false
		for existing in sites:
			if point.distance_to(existing) < 130.0:
				too_close = true
				break
		if not too_close:
			sites.append(point)
	while sites.size() < count:
		var x_draw := RunRngService.detached_randf_range(next_cursor, SITE_MARGIN_M, width - SITE_MARGIN_M)
		next_cursor = _cursor_from_draw(x_draw)
		var y_draw := RunRngService.detached_randf_range(next_cursor, SITE_MARGIN_M, height - SITE_MARGIN_M)
		next_cursor = _cursor_from_draw(y_draw)
		sites.append(Vector2(float(x_draw.get("value", 0.0)), float(y_draw.get("value", 0.0))))
	return {"ok": true, "sites": sites, "cursor": next_cursor}


func _assign_neighbors(districts: Array, width: float, height: float) -> void:
	for index in range(districts.size()):
		var entries: Array = []
		for other in range(districts.size()):
			if index != other:
				entries.append({"index": other, "distance": _wrapped_distance((districts[index] as Dictionary).get("center", Vector2.ZERO), (districts[other] as Dictionary).get("center", Vector2.ZERO), width, height)})
		entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("distance", INF)) < float(b.get("distance", INF)))
		var neighbors: Array = []
		for entry in entries.slice(0, mini(NEIGHBOR_COUNT, entries.size())):
			neighbors.append(int((entry as Dictionary).get("index", -1)))
		(districts[index] as Dictionary)["neighbors"] = neighbors
	for index in range(districts.size()):
		for neighbor in ((districts[index] as Dictionary).get("neighbors", []) as Array):
			var reverse: Array = (districts[int(neighbor)] as Dictionary).get("neighbors", [])
			if not reverse.has(index):
				reverse.append(index)
				(districts[int(neighbor)] as Dictionary)["neighbors"] = reverse


func _assign_terrain_and_goods(districts: Array, cursor: Dictionary) -> Dictionary:
	var next_cursor := cursor.duplicate(true)
	var ratio_draw := RunRngService.detached_randf_range(next_cursor, OCEAN_RATIO_MIN, OCEAN_RATIO_MAX)
	next_cursor = _cursor_from_draw(ratio_draw)
	var desired := clampi(int(round(float(districts.size()) * float(ratio_draw.get("value", OCEAN_RATIO_MIN)))), 1, districts.size() - 1)
	var ocean_indices: Array = []
	var seed_count_draw := RunRngService.detached_randi_range(next_cursor, 1, 3)
	next_cursor = _cursor_from_draw(seed_count_draw)
	var seed_count := clampi(int(seed_count_draw.get("value", 1)), 1, desired)
	while ocean_indices.size() < seed_count:
		var pick_draw := RunRngService.detached_randi_range(next_cursor, 0, districts.size() - 1)
		next_cursor = _cursor_from_draw(pick_draw)
		var pick := int(pick_draw.get("value", 0))
		if not ocean_indices.has(pick):
			ocean_indices.append(pick)
	var guard := 0
	while ocean_indices.size() < desired and guard < districts.size() * 8:
		guard += 1
		var candidates: Array = []
		for index_variant in ocean_indices:
			var source_index := int(index_variant)
			for neighbor_variant in ((districts[source_index] as Dictionary).get("neighbors", []) as Array):
				var neighbor := int(neighbor_variant)
				if neighbor >= 0 and neighbor < districts.size() and not ocean_indices.has(neighbor) and not candidates.has(neighbor):
					candidates.append(neighbor)
		if candidates.is_empty():
			for index in range(districts.size()):
				if not ocean_indices.has(index):
					candidates.append(index)
		if candidates.is_empty():
			break
		var candidate_draw := RunRngService.detached_randi_range(next_cursor, 0, candidates.size() - 1)
		next_cursor = _cursor_from_draw(candidate_draw)
		ocean_indices.append(int(candidates[int(candidate_draw.get("value", 0))]))
	var name_draw := RunRngService.detached_randi_range(next_cursor, 0, OCEAN_NAMES.size() - 1)
	next_cursor = _cursor_from_draw(name_draw)
	var ocean_name_offset := int(name_draw.get("value", 0))
	var ocean_count := 0
	for index in range(districts.size()):
		var district: Dictionary = districts[index]
		var is_ocean := ocean_indices.has(index)
		var focus: String = "ocean_transport" if is_ocean else str(["production", "transport", "consumption", "balanced"][index % 4])
		if not is_ocean:
			var focus_draw := RunRngService.detached_randi_range(next_cursor, 0, 3)
			next_cursor = _cursor_from_draw(focus_draw)
			focus = ["production", "transport", "consumption", "balanced"][int(focus_draw.get("value", 0))]
		var product_result := _draw_product(_product_pool("ocean" if is_ocean else "land"), next_cursor, [])
		next_cursor = (product_result.get("cursor", {}) as Dictionary).duplicate(true)
		var products := [str(product_result.get("product", ""))]
		var demand_result := _draw_product(ProductMarketRuntimeController.PRODUCT_CATALOG, next_cursor, products)
		next_cursor = (demand_result.get("cursor", {}) as Dictionary).duplicate(true)
		district["terrain"] = "ocean" if is_ocean else "land"
		district["terrain_label"] = "海洋" if is_ocean else "陆地"
		if is_ocean:
			district["name"] = OCEAN_NAMES[(ocean_name_offset + ocean_count) % OCEAN_NAMES.size()]
			ocean_count += 1
		district["economic_focus"] = focus
		district["economic_focus_label"] = {"production": "生产区", "transport": "交通枢纽", "consumption": "消费区", "ocean_transport": "海运通道"}.get(focus, "均衡区")
		var levels: Array = {"production": [3, 2, 1], "transport": [1, 3, 2], "consumption": [1, 2, 3], "balanced": [2, 2, 2], "ocean_transport": [1, 4, 1]}.get(focus, [2, 2, 2]) as Array
		district["production_level"] = levels[0]
		district["transport_level"] = levels[1]
		district["consumption_level"] = levels[2]
		district["transport_score"] = clampf((1.25 if is_ocean else 1.0) + float(levels[1] - 1) * 0.18, 0.55, 2.4)
		district["products"] = products
		district["demands"] = [str(demand_result.get("product", ""))]
		districts[index] = district
	return {"ok": true, "districts": districts, "cursor": next_cursor}


func _draw_product(source: Array, cursor: Dictionary, excluded: Array) -> Dictionary:
	var pool: Array = []
	for value in source:
		if not excluded.has(value):
			pool.append(value)
	if pool.is_empty():
		return {"product": "", "cursor": cursor.duplicate(true)}
	var draw := RunRngService.detached_randi_range(cursor, 0, pool.size() - 1)
	return {"product": str(pool[int(draw.get("value", 0))]), "cursor": _cursor_from_draw(draw)}


func _product_pool(terrain: String) -> Array:
	if terrain == "ocean":
		return OCEAN_PRODUCTS.duplicate()
	var result: Array = []
	for product in ProductMarketRuntimeController.PRODUCT_CATALOG:
		if not OCEAN_PRODUCTS.has(product):
			result.append(product)
	return result


func _economic_rows(districts: Array) -> Array:
	var result: Array = []
	for district_variant in districts:
		var district: Dictionary = district_variant
		result.append({"region_id": str(district.get("region_id", "")), "terrain": str(district.get("terrain", "unknown")), "neighbors": (district.get("neighbors", []) as Array).duplicate(), "products": (district.get("products", []) as Array).duplicate(), "demands": (district.get("demands", []) as Array).duplicate()})
	return result


func _voronoi_polygon(site_index: int, sites: Array, width: float, height: float) -> Array:
	var polygon := [Vector2.ZERO, Vector2(width, 0.0), Vector2(width, height), Vector2(0.0, height)]
	var site: Vector2 = sites[site_index]
	for index in range(sites.size()):
		if index != site_index:
			polygon = _clip_polygon(polygon, site, sites[index])
	return polygon


func _clip_polygon(polygon: Array, site: Vector2, other: Vector2) -> Array:
	var result: Array = []
	var normal := other - site
	var midpoint := (site + other) * 0.5
	for index in range(polygon.size()):
		var current: Vector2 = polygon[index]
		var next: Vector2 = polygon[(index + 1) % polygon.size()]
		var current_inside := (current - midpoint).dot(normal) <= 0.001
		var next_inside := (next - midpoint).dot(normal) <= 0.001
		if current_inside and next_inside:
			result.append(next)
		elif current_inside != next_inside:
			var direction := next - current
			var denominator := direction.dot(normal)
			var intersection := current if absf(denominator) <= 0.001 else current + direction * clampf(-((current - midpoint).dot(normal)) / denominator, 0.0, 1.0)
			result.append(intersection)
			if next_inside:
				result.append(next)
	return result


func _polygon_area(polygon: Array) -> float:
	var area := 0.0
	for index in range(polygon.size()):
		var current: Vector2 = polygon[index]
		var next: Vector2 = polygon[(index + 1) % polygon.size()]
		area += current.x * next.y - next.x * current.y
	return area * 0.5


func _polygon_centroid(polygon: Array) -> Vector2:
	var signed_area := _polygon_area(polygon)
	if absf(signed_area) <= 0.001:
		var fallback := Vector2.ZERO
		for point in polygon:
			fallback += point as Vector2
		return fallback / maxf(1.0, float(polygon.size()))
	var cx := 0.0
	var cy := 0.0
	for index in range(polygon.size()):
		var current: Vector2 = polygon[index]
		var next: Vector2 = polygon[(index + 1) % polygon.size()]
		var cross := current.x * next.y - next.x * current.y
		cx += (current.x + next.x) * cross
		cy += (current.y + next.y) * cross
	return Vector2(cx, cy) / (6.0 * signed_area)


func _wrapped_distance(from: Vector2, to: Vector2, width: float, height: float) -> float:
	var dx := absf(from.x - to.x)
	var dy := absf(from.y - to.y)
	dx = minf(dx, width - dx)
	dy = minf(dy, height - dy)
	return Vector2(dx, dy).length()


func _nearest_to_center(districts: Array, center: Vector2, width: float, height: float) -> int:
	var best := -1
	var distance := INF
	for index in range(districts.size()):
		var candidate := _wrapped_distance(center, (districts[index] as Dictionary).get("center", Vector2.ZERO), width, height)
		if candidate < distance:
			distance = candidate
			best = index
	return best


func _cursor_from_draw(draw: Dictionary) -> Dictionary:
	return {"schema_version": 1, "rng_state": int(draw.get("rng_state", 1)), "draw_count": int(draw.get("draw_count", 0))}
