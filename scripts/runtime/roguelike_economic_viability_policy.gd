extends RefCounted
class_name RoguelikeEconomicViabilityPolicy

const POLICY_ID := "roguelike_economic_viability_v06"
const SCHEMA_VERSION := 3


static func normalize(request: Dictionary) -> Dictionary:
	var validation := _validate_request(request)
	if not bool(validation.get("valid", false)):
		return _failure_result(str(validation.get("reason_code", "request_invalid")), validation.get("districts", []), _empty_audit())

	var original: Array = (validation.get("districts", []) as Array).duplicate(true)
	var before_audit := _audit_validated(original)
	if bool(before_audit.get("viable", false)):
		return {
			"ok": true,
			"reason_code": "global_remote_trade_opportunity_already_satisfied",
			"districts": original,
			"audit": before_audit,
		}

	var repair := _first_legal_repair(original)
	if not bool(repair.get("available", false)):
		return _failure_result("global_remote_trade_destination_unavailable", original, before_audit)

	var source_index := int(repair.get("source_index", -1))
	var destination_index := int(repair.get("destination_index", -1))
	var product_id := str(repair.get("product_id", ""))
	var normalized := original.duplicate(true)
	var destination := (normalized[destination_index] as Dictionary).duplicate(true)
	destination["demands"] = [product_id]
	normalized[destination_index] = destination

	var after_audit := _audit_validated(normalized)
	if not bool(after_audit.get("viable", false)):
		return _failure_result("post_normalize_global_remote_match_missing", original, before_audit)
	after_audit["changed"] = true
	after_audit["mutation_count"] = 1
	after_audit["changed_destination_indices"] = [destination_index]
	after_audit["repair"] = {
		"source_index": source_index,
		"source_region_id": str((normalized[source_index] as Dictionary).get("region_id", "")),
		"destination_index": destination_index,
		"destination_region_id": str(destination.get("region_id", "")),
		"product_id": product_id,
	}
	return {
		"ok": true,
		"reason_code": "global_remote_trade_opportunity_repaired",
		"districts": normalized,
		"audit": after_audit,
	}


static func audit(request: Dictionary) -> Dictionary:
	var validation := _validate_request(request)
	if not bool(validation.get("valid", false)):
		var result := _empty_audit()
		result["reason_code"] = str(validation.get("reason_code", "request_invalid"))
		return result
	return _audit_validated(validation.get("districts", []) as Array)


static func _validate_request(request: Dictionary) -> Dictionary:
	if not _is_pure_data(request):
		return {"valid": false, "reason_code": "request_not_pure_data", "districts": []}
	if not (request.get("districts", null) is Array):
		return {"valid": false, "reason_code": "districts_missing", "districts": []}
	if not (request.get("catalog_products", null) is Array):
		return {"valid": false, "reason_code": "catalog_missing", "districts": []}
	if not (request.get("terrain_product_pools", null) is Dictionary):
		return {"valid": false, "reason_code": "terrain_product_pools_missing", "districts": []}

	var districts: Array = (request.get("districts", []) as Array).duplicate(true)
	if districts.size() < 2:
		return {"valid": false, "reason_code": "district_count_insufficient", "districts": districts}
	var catalog_result := _string_set(request.get("catalog_products", []) as Array)
	if not bool(catalog_result.get("valid", false)) or (catalog_result.get("values", []) as Array).is_empty():
		return {"valid": false, "reason_code": "catalog_invalid", "districts": districts}
	var catalog_set: Dictionary = catalog_result.get("set", {}) as Dictionary
	var terrain_pools: Dictionary = request.get("terrain_product_pools", {}) as Dictionary
	var normalized_pools: Dictionary = {}
	for terrain_variant: Variant in terrain_pools.keys():
		var terrain := str(terrain_variant).strip_edges()
		var pool_variant: Variant = terrain_pools.get(terrain_variant)
		if terrain.is_empty() or not (pool_variant is Array):
			return {"valid": false, "reason_code": "terrain_product_pool_invalid", "districts": districts}
		var pool_result := _string_set(pool_variant as Array)
		if not bool(pool_result.get("valid", false)) or (pool_result.get("values", []) as Array).is_empty():
			return {"valid": false, "reason_code": "terrain_product_pool_invalid", "districts": districts}
		for product_variant: Variant in pool_result.get("values", []) as Array:
			if not catalog_set.has(str(product_variant)):
				return {"valid": false, "reason_code": "terrain_product_outside_catalog", "districts": districts}
		normalized_pools[terrain] = pool_result.get("set", {})

	var region_ids: Dictionary = {}
	for district_index in range(districts.size()):
		if not (districts[district_index] is Dictionary):
			return {"valid": false, "reason_code": "district_not_dictionary", "districts": districts}
		var district := districts[district_index] as Dictionary
		var region_id := str(district.get("region_id", "")).strip_edges()
		var terrain := str(district.get("terrain", "")).strip_edges()
		if region_id.is_empty() or region_ids.has(region_id):
			return {"valid": false, "reason_code": "region_id_invalid", "districts": districts}
		if terrain.is_empty() or not normalized_pools.has(terrain):
			return {"valid": false, "reason_code": "district_terrain_pool_missing", "districts": districts}
		region_ids[region_id] = true
		if not (district.get("products", null) is Array) or not (district.get("demands", null) is Array) or not (district.get("neighbors", null) is Array):
			return {"valid": false, "reason_code": "district_economic_fields_invalid", "districts": districts}
		var products: Array = district.get("products", []) as Array
		var demands: Array = district.get("demands", []) as Array
		if products.size() != 1 or demands.size() != 1:
			return {"valid": false, "reason_code": "district_slot_count_invalid", "districts": districts}
		var product_id := str(products[0]).strip_edges()
		var demand_id := str(demands[0]).strip_edges()
		if product_id.is_empty() or demand_id.is_empty() or not catalog_set.has(product_id) or not catalog_set.has(demand_id):
			return {"valid": false, "reason_code": "district_product_outside_catalog", "districts": districts}
		if not (normalized_pools.get(terrain, {}) as Dictionary).has(product_id):
			return {"valid": false, "reason_code": "production_product_outside_terrain_pool", "districts": districts}
		if product_id == demand_id:
			return {"valid": false, "reason_code": "district_self_demand", "districts": districts}
		var seen_neighbors: Dictionary = {}
		for neighbor_variant: Variant in district.get("neighbors", []) as Array:
			if not (neighbor_variant is int):
				return {"valid": false, "reason_code": "neighbor_index_invalid", "districts": districts}
			var neighbor_index := int(neighbor_variant)
			if neighbor_index < 0 or neighbor_index >= districts.size() or neighbor_index == district_index or seen_neighbors.has(neighbor_index):
				return {"valid": false, "reason_code": "neighbor_index_invalid", "districts": districts}
			seen_neighbors[neighbor_index] = true
	return {"valid": true, "reason_code": "request_valid", "districts": districts}


static func _audit_validated(districts: Array) -> Dictionary:
	var global_remote_match_count := 0
	var direct_remote_match_count := 0
	var assignments: Array = []
	for source_index in range(districts.size()):
		var source := districts[source_index] as Dictionary
		var source_product := _product_id(source)
		var neighbors: Array = source.get("neighbors", []) as Array
		var first_destination := -1
		for destination_index in range(districts.size()):
			if destination_index == source_index:
				continue
			var destination := districts[destination_index] as Dictionary
			if _demand_id(destination) != source_product or _product_id(destination) == source_product:
				continue
			global_remote_match_count += 1
			if neighbors.has(destination_index):
				direct_remote_match_count += 1
			if first_destination < 0:
				first_destination = destination_index
		if first_destination >= 0:
			var proof_destination := districts[first_destination] as Dictionary
			assignments.append({
				"source_index": source_index,
				"source_region_id": str(source.get("region_id", "")),
				"destination_index": first_destination,
				"destination_region_id": str(proof_destination.get("region_id", "")),
				"product_id": source_product,
				"direct": neighbors.has(first_destination),
			})
	var source_count := districts.size()
	var source_with_remote_count := assignments.size()
	var isolated_source_count := source_count - source_with_remote_count
	var coverage_ratio := float(source_with_remote_count) / float(source_count) if source_count > 0 else 0.0
	var viable := global_remote_match_count > 0
	return {
		"policy_id": POLICY_ID,
		"schema_version": SCHEMA_VERSION,
		"valid_input": true,
		"viable": viable,
		"reason_code": "global_remote_trade_opportunity_ready" if viable else "global_remote_trade_opportunity_missing",
		"source_count": source_count,
		"global_remote_match_count": global_remote_match_count,
		"direct_remote_match_count": direct_remote_match_count,
		"source_with_remote_count": source_with_remote_count,
		"isolated_source_count": isolated_source_count,
		"coverage_ratio": coverage_ratio,
		"assignments": assignments,
		"changed": false,
		"mutation_count": 0,
		"changed_destination_indices": [],
		"repair": {},
	}


static func _first_legal_repair(districts: Array) -> Dictionary:
	for source_index in range(districts.size()):
		var source_product := _product_id(districts[source_index] as Dictionary)
		for destination_index in range(districts.size()):
			if source_index == destination_index:
				continue
			if _product_id(districts[destination_index] as Dictionary) == source_product:
				continue
			return {
				"available": true,
				"source_index": source_index,
				"destination_index": destination_index,
				"product_id": source_product,
			}
	return {"available": false}


static func _product_id(district: Dictionary) -> String:
	return str((district.get("products", []) as Array)[0])


static func _demand_id(district: Dictionary) -> String:
	return str((district.get("demands", []) as Array)[0])


static func _string_set(values: Array) -> Dictionary:
	var result: Array = []
	var seen: Dictionary = {}
	for value_variant: Variant in values:
		if not (value_variant is String or value_variant is StringName):
			return {"valid": false, "values": [], "set": {}}
		var value := str(value_variant).strip_edges()
		if value.is_empty() or seen.has(value):
			return {"valid": false, "values": [], "set": {}}
		seen[value] = true
		result.append(value)
	return {"valid": true, "values": result, "set": seen}


static func _failure_result(reason_code: String, districts_variant: Variant, audit_variant: Variant) -> Dictionary:
	var districts: Array = (districts_variant as Array).duplicate(true) if districts_variant is Array else []
	var audit_result: Dictionary = (audit_variant as Dictionary).duplicate(true) if audit_variant is Dictionary else _empty_audit()
	audit_result["viable"] = false
	audit_result["reason_code"] = reason_code
	audit_result["changed"] = false
	audit_result["mutation_count"] = 0
	audit_result["changed_destination_indices"] = []
	audit_result["repair"] = {}
	return {"ok": false, "reason_code": reason_code, "districts": districts, "audit": audit_result}


static func _empty_audit() -> Dictionary:
	return {
		"policy_id": POLICY_ID,
		"schema_version": SCHEMA_VERSION,
		"valid_input": false,
		"viable": false,
		"reason_code": "not_audited",
		"source_count": 0,
		"global_remote_match_count": 0,
		"direct_remote_match_count": 0,
		"source_with_remote_count": 0,
		"isolated_source_count": 0,
		"coverage_ratio": 0.0,
		"assignments": [],
		"changed": false,
		"mutation_count": 0,
		"changed_destination_indices": [],
		"repair": {},
	}


static func _is_pure_data(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item_variant: Variant in value:
			if not _is_pure_data(item_variant):
				return false
		return true
	if value is Dictionary:
		for key_variant: Variant in value.keys():
			if not (key_variant is String or key_variant is StringName) or not _is_pure_data(value.get(key_variant)):
				return false
		return true
	return false
