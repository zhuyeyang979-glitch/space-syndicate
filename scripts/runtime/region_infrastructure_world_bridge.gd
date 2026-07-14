@tool
extends Node
class_name RegionInfrastructureWorldBridge

signal infrastructure_receipt_forwarded(receipt: Dictionary)

const PRODUCT_INDUSTRY_CATALOG := preload("res://resources/content/product_industry_catalog_v05.tres")

var _controller: Node
var _world: Node
var _request_sequence := 0
var _forward_count := 0
var _failure_count := 0


func set_controller(controller: Node) -> void:
	var callback := Callable(self, "_on_controller_receipt")
	if _controller != null and _controller.has_signal("infrastructure_receipt_committed") and _controller.is_connected("infrastructure_receipt_committed", callback):
		_controller.disconnect("infrastructure_receipt_committed", callback)
	_controller = controller
	if _controller != null and _controller.has_signal("infrastructure_receipt_committed") and not _controller.is_connected("infrastructure_receipt_committed", callback):
		_controller.connect("infrastructure_receipt_committed", callback)


func bind_world(world: Node) -> void:
	_world = world


func initialize_from_legacy_map(region_definitions: Array) -> Dictionary:
	if _controller == null or not _controller.has_method("initialize_regions"):
		return {"initialized": false, "reason": "controller_missing"}
	var value: Variant = _controller.call("initialize_regions", region_definitions)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {"initialized": false, "reason": "controller_result_invalid"}


func submit_facility_action(request: Dictionary) -> Dictionary:
	if _controller == null or not _controller.has_method("apply_facility_action"):
		return {"committed": false, "reason": "controller_missing"}
	var value: Variant = _controller.call("apply_facility_action", request)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {"committed": false, "reason": "controller_result_invalid"}


func submit_legacy_index_facility_action(legacy_index: int, request: Dictionary) -> Dictionary:
	if _controller == null or not _controller.has_method("region_id_for_legacy_index"):
		return {"committed": false, "reason": "controller_missing"}
	var region_id: String = str(_controller.call("region_id_for_legacy_index", legacy_index))
	if region_id.is_empty():
		return {"committed": false, "reason": "legacy_region_not_mapped", "legacy_index": legacy_index}
	var normalized := request.duplicate(true)
	normalized["region_id"] = region_id
	return submit_facility_action(normalized)


func submit_unit_damage(request: Dictionary) -> Dictionary:
	if _controller == null or not _controller.has_method("apply_unit_damage"):
		return {"committed": false, "reason": "controller_missing"}
	var value: Variant = _controller.call("apply_unit_damage", request)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {"committed": false, "reason": "controller_result_invalid"}


func submit_repair(request: Dictionary) -> Dictionary:
	if _controller == null or not _controller.has_method("apply_repair"):
		return {"committed": false, "reason": "controller_missing"}
	var value: Variant = _controller.call("apply_repair", request)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {"committed": false, "reason": "controller_result_invalid"}


func submit_legacy_index_unit_damage(legacy_index: int, amount: int, source_kind: String, source_entity_id: String, occurred_at: float) -> Dictionary:
	if _controller == null:
		return {"committed": false, "reason": "controller_missing"}
	var region_id: String = str(_controller.call("region_id_for_legacy_index", legacy_index))
	if region_id.is_empty():
		return {"committed": false, "reason": "legacy_region_not_mapped", "legacy_index": legacy_index}
	_request_sequence += 1
	var value: Variant = _controller.call("apply_unit_damage", {
		"transaction_id": "%s-region-damage-%d" % [source_kind, _request_sequence],
		"source_kind": source_kind,
		"source_entity_id": source_entity_id,
		"region_id": region_id,
		"amount": amount,
		"occurred_at": occurred_at,
	})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {"committed": false, "reason": "controller_result_invalid"}


func submit_legacy_index_repair(legacy_index: int, amount: int, source_kind: String, source_entity_id: String, occurred_at: float) -> Dictionary:
	if _controller == null:
		return {"committed": false, "reason": "controller_missing"}
	var region_id: String = str(_controller.call("region_id_for_legacy_index", legacy_index))
	if region_id.is_empty():
		return {"committed": false, "reason": "legacy_region_not_mapped", "legacy_index": legacy_index}
	_request_sequence += 1
	var value: Variant = _controller.call("apply_repair", {
		"transaction_id": "%s-region-repair-%d" % [source_kind, _request_sequence],
		"source_kind": source_kind,
		"source_entity_id": source_entity_id,
		"region_id": region_id,
		"amount": amount,
		"occurred_at": occurred_at,
	})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {"committed": false, "reason": "controller_result_invalid"}


func region_snapshot_for_legacy_index(legacy_index: int) -> Dictionary:
	if _controller == null:
		return {}
	var region_id: String = str(_controller.call("region_id_for_legacy_index", legacy_index))
	if region_id.is_empty():
		return {}
	var value: Variant = _controller.call("region_snapshot", region_id)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func region_commodity_facts(region_id: String) -> Dictionary:
	var normalized_id := region_id.strip_edges()
	if normalized_id.is_empty() or _controller == null or _world == null or not is_instance_valid(_world):
		return {"available": false, "authoritative": false, "reason_code": "region_commodity_facts_unavailable"}
	var districts_variant: Variant = _world.get("districts")
	if not (districts_variant is Array):
		return {"available": false, "authoritative": false, "reason_code": "region_district_facts_missing"}
	var district: Dictionary = {}
	for district_variant in districts_variant as Array:
		if district_variant is Dictionary and str((district_variant as Dictionary).get("region_id", "")).strip_edges() == normalized_id:
			district = (district_variant as Dictionary).duplicate(true)
			break
	if district.is_empty():
		return {"available": false, "authoritative": false, "reason_code": "region_district_facts_missing", "region_id": normalized_id}
	var region_variant: Variant = _controller.call("region_snapshot", normalized_id) if _controller.has_method("region_snapshot") else {}
	var region: Dictionary = (region_variant as Dictionary).duplicate(true) if region_variant is Dictionary else {}
	if region.is_empty():
		return {"available": false, "authoritative": false, "reason_code": "region_runtime_facts_missing", "region_id": normalized_id}
	var production_result := _commodity_fact_rows(district.get("products", []))
	var demand_result := _commodity_fact_rows(district.get("demands", []))
	if not bool(production_result.get("valid", false)) or not bool(demand_result.get("valid", false)):
		return {
			"available": false,
			"authoritative": false,
			"reason_code": str(production_result.get("reason_code", demand_result.get("reason_code", "region_product_unknown"))),
			"region_id": normalized_id,
		}
	var facts := {
		"available": true,
		"authoritative": true,
		"reason_code": "region_commodity_facts_ready",
		"region_id": normalized_id,
		"legacy_index": int(region.get("legacy_index", district.get("id", -1))),
		"region_revision": int(region.get("revision", 0)),
		"terrain_id": str(region.get("terrain_id", district.get("terrain", "unknown"))),
		"production_products": (production_result.get("rows", []) as Array).duplicate(true),
		"demand_products": (demand_result.get("rows", []) as Array).duplicate(true),
	}
	facts["facts_fingerprint"] = str(hash(JSON.stringify(facts)))
	return facts


func public_commodity_region_facts() -> Array:
	if _controller == null or not _controller.has_method("regions_snapshot"):
		return []
	var result: Array = []
	var regions_variant: Variant = _controller.call("regions_snapshot")
	if not (regions_variant is Array):
		return result
	for region_variant in regions_variant as Array:
		if not (region_variant is Dictionary):
			continue
		var facts := region_commodity_facts(str((region_variant as Dictionary).get("region_id", "")))
		if bool(facts.get("available", false)):
			result.append(facts)
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("region_id", "")) < str(right.get("region_id", ""))
	)
	return result


func selected_region_commodity_facts() -> Dictionary:
	if _world == null or not is_instance_valid(_world):
		return {"available": false, "authoritative": false, "reason_code": "region_commodity_facts_unavailable"}
	var selected_index := int(_world.get("selected_district"))
	var districts_variant: Variant = _world.get("districts")
	if not (districts_variant is Array) or selected_index < 0 or selected_index >= (districts_variant as Array).size():
		return {"available": false, "authoritative": false, "reason_code": "selected_region_missing"}
	var district_variant: Variant = (districts_variant as Array)[selected_index]
	if not (district_variant is Dictionary):
		return {"available": false, "authoritative": false, "reason_code": "selected_region_missing"}
	return region_commodity_facts(str((district_variant as Dictionary).get("region_id", "")))


func debug_snapshot() -> Dictionary:
	return {
		"bridge_ready": _controller != null,
		"world_bound": _world != null and is_instance_valid(_world),
		"request_sequence": _request_sequence,
		"forward_count": _forward_count,
		"failure_count": _failure_count,
		"owns_region_state": false,
		"owns_facility_rules": false,
		"owns_damage_rules": false,
		"provides_authoritative_region_commodity_facts": has_method("region_commodity_facts"),
	}


func _commodity_fact_rows(source_variant: Variant) -> Dictionary:
	if not (source_variant is Array):
		return {"valid": false, "reason_code": "region_product_list_invalid", "rows": []}
	var rows: Array = []
	var seen: Dictionary = {}
	for product_variant in source_variant as Array:
		var product_id := ""
		if product_variant is String or product_variant is StringName:
			product_id = str(product_variant).strip_edges()
		elif product_variant is Dictionary:
			product_id = str((product_variant as Dictionary).get("product_id", "")).strip_edges()
		if product_id.is_empty() or seen.has(product_id):
			continue
		var industry_id := str(PRODUCT_INDUSTRY_CATALOG.call("industry_for_product", product_id)) if PRODUCT_INDUSTRY_CATALOG != null and PRODUCT_INDUSTRY_CATALOG.has_method("industry_for_product") else ""
		if industry_id.is_empty():
			return {"valid": false, "reason_code": "region_product_unknown", "product_id": product_id, "rows": []}
		seen[product_id] = true
		rows.append({"product_id": product_id, "industry_id": industry_id})
	return {"valid": true, "reason_code": "region_product_rows_ready", "rows": rows}


func _on_controller_receipt(receipt: Dictionary) -> void:
	if not _is_pure_data(receipt):
		_failure_count += 1
		push_error("Region infrastructure receipt rejected because it is not pure data.")
		return
	_forward_count += 1
	infrastructure_receipt_forwarded.emit(receipt.duplicate(true))
	if _world != null and is_instance_valid(_world) and _world.has_method("_on_region_infrastructure_receipt"):
		_world.call("_on_region_infrastructure_receipt", receipt.duplicate(true))


func _is_pure_data(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item in value:
			if not _is_pure_data(item):
				return false
		return true
	if value is Dictionary:
		for key in value:
			if not (key is String or key is StringName or key is int) or not _is_pure_data(value[key]):
				return false
		return true
	return false
