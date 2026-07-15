@tool
extends Node
class_name RegionInfrastructureWorldBridge

signal infrastructure_receipt_forwarded(receipt: Dictionary)

const PRODUCT_INDUSTRY_CATALOG := preload("res://resources/content/product_industry_catalog_v05.tres")
const REGION_CODEX_PUBLIC_FACTS_CONTRACT_V06 := "region_codex_public_facts_v06"
const REGION_CODEX_PUBLIC_CLUE_EMPTY_V06 := "暂无公开线索"
const REGION_CODEX_PRIVATE_SENTINEL_MARKERS_V06 := [
	"private_sentinel", "secret_sentinel", "cash_sentinel", "hand_sentinel", "discard_sentinel",
	"owner_sentinel", "ai_plan_sentinel", "do_not_leak",
]

var _controller: Node
var _world: Node
var _request_sequence := 0
var _forward_count := 0
var _failure_count := 0
var _region_codex_public_projection_count := 0


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


func submit_weather_damage_by_legacy_index(legacy_index: int, event_id: int, amount: int, accounted_total: int, occurred_at_world_us: int) -> Dictionary:
	if _controller == null or not _controller.has_method("region_id_for_legacy_index") or not _controller.has_method("apply_weather_damage"):
		return {"committed": false, "reason": "controller_missing"}
	var region_id := str(_controller.call("region_id_for_legacy_index", legacy_index))
	if region_id.is_empty():
		return {"committed": false, "reason": "legacy_region_not_mapped", "legacy_index": legacy_index}
	var normalized_total := maxi(0, accounted_total)
	var transaction_id := "weather:%d:region:%s:through:%d" % [event_id, region_id, normalized_total]
	var value: Variant = _controller.call("apply_weather_damage", {
		"transaction_id": transaction_id,
		"source_event_id": event_id,
		"region_id": region_id,
		"amount": amount,
		"accounted_total": normalized_total,
		"occurred_at_world_us": occurred_at_world_us,
	})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {"committed": false, "reason": "controller_result_invalid"}


func weather_intervention_snapshot_for_legacy_index(legacy_index: int) -> Dictionary:
	if _world == null or not is_instance_valid(_world):
		return {"available": false, "weather_resistance": 0.0, "reason": "world_missing"}
	var districts_variant: Variant = _world.get("districts")
	if not (districts_variant is Array) or legacy_index < 0 or legacy_index >= (districts_variant as Array).size():
		return {"available": false, "weather_resistance": 0.0, "reason": "region_missing"}
	var district_variant: Variant = (districts_variant as Array)[legacy_index]
	if not (district_variant is Dictionary):
		return {"available": false, "weather_resistance": 0.0, "reason": "region_invalid"}
	var district := district_variant as Dictionary
	var resistance := clampf(float(district.get("weather_resistance", 0.0)), 0.0, 1.0)
	var city_variant: Variant = district.get("city", {})
	if city_variant is Dictionary:
		resistance = maxf(resistance, clampf(float((city_variant as Dictionary).get("weather_resistance", 0.0)), 0.0, 1.0))
	return {
		"available": true,
		"weather_resistance": resistance,
	}


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


func region_codex_public_facts(legacy_index: int) -> Dictionary:
	_region_codex_public_projection_count += 1
	if _world == null or not is_instance_valid(_world):
		return _region_codex_public_unavailable(legacy_index, "region_codex_public_world_unavailable")
	var districts_variant: Variant = _world.get("districts")
	if not (districts_variant is Array):
		return _region_codex_public_unavailable(legacy_index, "region_codex_public_regions_invalid")
	var districts := districts_variant as Array
	if legacy_index < 0 or legacy_index >= districts.size() or not (districts[legacy_index] is Dictionary):
		return _region_codex_public_unavailable(legacy_index, "region_codex_public_region_invalid", districts.size())
	var district := districts[legacy_index] as Dictionary
	var products_result := _region_codex_public_string_array(district.get("products", []))
	var demands_result := _region_codex_public_string_array(district.get("demands", []))
	var cards_result := _region_codex_public_string_array(district.get("card_choices", []))
	var neighbors_result := _region_codex_public_index_array(district.get("neighbors", []), districts.size())
	for result_variant: Variant in [products_result, demands_result, cards_result, neighbors_result]:
		var result := result_variant as Dictionary
		if not bool(result.get("valid", false)):
			return _region_codex_public_unavailable(legacy_index, str(result.get("reason_code", "region_codex_public_scalar_array_invalid")), districts.size())
	var city_variant: Variant = district.get("city", {})
	if not (city_variant is Dictionary):
		return _region_codex_public_unavailable(legacy_index, "region_codex_public_city_invalid", districts.size())
	var city := city_variant as Dictionary
	var region_id_variant: Variant = district.get("region_id", "")
	var name_variant: Variant = district.get("name", "区域")
	var terrain_variant: Variant = district.get("terrain", "land")
	var terrain_label_variant: Variant = district.get("terrain_label", "区域")
	var focus_variant: Variant = district.get("economic_focus_label", "均衡")
	if not _region_codex_public_text_scalar(region_id_variant) or not _region_codex_public_text_scalar(name_variant) or not _region_codex_public_text_scalar(terrain_variant) or not _region_codex_public_text_scalar(terrain_label_variant) or not _region_codex_public_text_scalar(focus_variant):
		return _region_codex_public_unavailable(legacy_index, "region_codex_public_identity_invalid", districts.size())
	if str(region_id_variant).strip_edges().is_empty() or str(name_variant).strip_edges().is_empty():
		return _region_codex_public_unavailable(legacy_index, "region_codex_public_identity_invalid", districts.size())
	for numeric_variant: Variant in [district.get("hp", 0), district.get("damage", 0)]:
		if not (numeric_variant is int or numeric_variant is float):
			return _region_codex_public_unavailable(legacy_index, "region_codex_public_hp_invalid", districts.size())
	if not (district.get("destroyed", false) is bool):
		return _region_codex_public_unavailable(legacy_index, "region_codex_public_lifecycle_invalid", districts.size())
	var hp_total := maxi(0, int(district.get("hp", 0)))
	var hp_now := maxi(0, hp_total - maxi(0, int(district.get("damage", 0))))
	var destroyed := bool(district.get("destroyed", false))
	var city_present := not city.is_empty()
	if city_present and (not (city.get("active", true) is bool) or not (city.get("level", 0) is int or city.get("level", 0) is float) or not (city.get("last_income", 0) is int or city.get("last_income", 0) is float)):
		return _region_codex_public_unavailable(legacy_index, "region_codex_public_city_invalid", districts.size())
	var city_public := {
		"present": city_present,
		"active": city_present and bool(city.get("active", true)) and not destroyed,
		"level": maxi(0, int(city.get("level", 0))) if city_present else 0,
		"last_income": maxi(0, int(city.get("last_income", 0))) if city_present else 0,
	}
	return {
		"available": true,
		"contract_version": REGION_CODEX_PUBLIC_FACTS_CONTRACT_V06,
		"reason_code": "region_codex_public_facts_ready",
		"index": legacy_index,
		"total": districts.size(),
		"region_id": str(region_id_variant),
		"name": str(name_variant),
		"terrain": str(terrain_variant),
		"terrain_label": str(terrain_label_variant),
		"economic_focus_label": str(focus_variant),
		"destroyed": destroyed,
		"hp_total": hp_total,
		"hp_now": hp_now,
		"products": (products_result.get("values", []) as Array).duplicate(),
		"demands": (demands_result.get("values", []) as Array).duplicate(),
		"card_ids": (cards_result.get("values", []) as Array).duplicate(),
		"neighbor_indices": (neighbors_result.get("values", []) as Array).duplicate(),
		"city": city_public,
		"public_clue": _region_codex_public_clue(city),
	}


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
		"region_codex_public_projection": true,
		"region_codex_public_projection_count": _region_codex_public_projection_count,
		"reads_viewer_state": false,
		"reads_private_player_state": false,
		"owns_rules": false,
		"owns_save_state": false,
	}


func _region_codex_public_unavailable(legacy_index: int, reason_code: String, total: int = 0) -> Dictionary:
	return {
		"available": false,
		"contract_version": REGION_CODEX_PUBLIC_FACTS_CONTRACT_V06,
		"reason_code": reason_code,
		"index": legacy_index,
		"total": maxi(0, total),
		"region_id": "",
		"name": "",
		"terrain": "",
		"terrain_label": "",
		"economic_focus_label": "",
		"destroyed": false,
		"hp_total": 0,
		"hp_now": 0,
		"products": [],
		"demands": [],
		"card_ids": [],
		"neighbor_indices": [],
		"city": {"present": false, "active": false, "level": 0, "last_income": 0},
		"public_clue": REGION_CODEX_PUBLIC_CLUE_EMPTY_V06,
	}


func _region_codex_public_string_array(value: Variant) -> Dictionary:
	if not (value is Array):
		return {"valid": false, "reason_code": "region_codex_public_string_array_invalid", "values": []}
	var values: Array = []
	var seen: Dictionary = {}
	for entry_variant: Variant in value as Array:
		if not _region_codex_public_text_scalar(entry_variant):
			return {"valid": false, "reason_code": "region_codex_public_string_array_invalid", "values": []}
		var entry := str(entry_variant).strip_edges()
		if entry.is_empty() or seen.has(entry):
			continue
		seen[entry] = true
		values.append(entry)
	return {"valid": true, "reason_code": "", "values": values}


func _region_codex_public_index_array(value: Variant, region_count: int) -> Dictionary:
	if not (value is Array):
		return {"valid": false, "reason_code": "region_codex_public_index_array_invalid", "values": []}
	var values: Array = []
	for entry_variant: Variant in value as Array:
		if not (entry_variant is int):
			return {"valid": false, "reason_code": "region_codex_public_index_array_invalid", "values": []}
		var entry := int(entry_variant)
		if entry < 0 or entry >= region_count:
			return {"valid": false, "reason_code": "region_codex_public_neighbor_invalid", "values": []}
		if not values.has(entry):
			values.append(entry)
	values.sort()
	return {"valid": true, "reason_code": "", "values": values}


func _region_codex_public_clue(city: Dictionary) -> String:
	var clues_variant: Variant = city.get("public_clues", [])
	if clues_variant is Array:
		var clues := clues_variant as Array
		for index in range(clues.size() - 1, -1, -1):
			var formatted := _region_codex_public_clue_entry(clues[index])
			if not formatted.is_empty():
				return formatted
	var last_clue_variant: Variant = city.get("last_public_clue", "")
	if _region_codex_public_text_scalar(last_clue_variant):
		var last_clue := str(last_clue_variant).strip_edges()
		if not last_clue.is_empty():
			return last_clue
	return REGION_CODEX_PUBLIC_CLUE_EMPTY_V06


func _region_codex_public_clue_entry(value: Variant) -> String:
	if not (value is Dictionary):
		return ""
	var entry := value as Dictionary
	var text_variant: Variant = entry.get("text", "")
	var kind_variant: Variant = entry.get("kind", "公开")
	var time_variant: Variant = entry.get("time", -1.0)
	var products_result := _region_codex_public_string_array(entry.get("products", []))
	if not _region_codex_public_text_scalar(text_variant) or not _region_codex_public_text_scalar(kind_variant) or not (time_variant is int or time_variant is float) or not bool(products_result.get("valid", false)):
		return ""
	var text := str(text_variant).strip_edges()
	if text.is_empty():
		return ""
	var time_value := float(time_variant)
	var time_text := "T+%.0fs" % time_value if time_value >= 0.0 else "时间未知"
	var products: Array = products_result.get("values", []) as Array
	return "%s｜%s｜商品:%s｜%s" % [time_text, str(kind_variant), "、".join(products) if not products.is_empty() else "无", text]


func _region_codex_public_text_scalar(value: Variant) -> bool:
	if not (value is String or value is StringName):
		return false
	var lowered := str(value).to_lower()
	for marker in REGION_CODEX_PRIVATE_SENTINEL_MARKERS_V06:
		if lowered.contains(marker):
			return false
	return true


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
