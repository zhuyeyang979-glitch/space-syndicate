extends RefCounted
class_name V074RegionPopupDtoV1

const Wire := preload("res://scripts/semantic/semantic_wire_v1.gd")
const SCHEMA_VERSION := 1
const RULESET_ID := "v0.7.4"
const DTO_ID := "v074.region_popup.public.v1"
const FACILITY_TYPES := ["factory", "market", "warehouse"]
const TERRAIN_CLASSES := ["land", "ocean"]
const DTO_FIELDS := [
	"schema_version", "dto_id", "ruleset_id", "map_fingerprint", "region_id",
	"display_name", "public_index", "terrain_class", "sunlit",
	"solar_efficiency_multiplier_bps", "neighbor_region_ids",
	"potential_facility_slot_count", "occupied_facility_count",
	"public_warehouse_count", "public_facilities", "dto_fingerprint",
]
const FACILITY_FIELDS := [
	"facility_id", "slot_id", "region_id", "facility_type", "industry_id",
	"owner_public_id", "owner_public_index", "owner_public_label", "rank",
	"capacity_units", "ingress_throughput_units", "egress_throughput_units",
	"solar_efficiency_state", "solar_efficiency_multiplier_bps",
	"damage_points", "damage_revision", "damage_state", "occupancy", "asset_key",
]
const PRIVATE_KEYS := [
	"warehouse_stock", "warehouse_inventory", "inventory_by_commodity",
	"warehouse_stock_by_commodity", "private_logistics", "private_logistics_plan",
	"future_transport_plan", "future_action", "future_submission", "ai_plan",
	"ai_score", "opponent_hand", "hidden_lead_order", "private_source",
]


static func build(region: Dictionary, facility_rows: Array, map_fingerprint: String) -> Dictionary:
	var region_id := str(region.get("region_id", ""))
	var terrain := str(region.get("terrain_class", ""))
	if not Wire.is_stable_id(region_id) or terrain not in TERRAIN_CLASSES 			or not Wire.is_fingerprint(map_fingerprint):
		return {}
	var sunlit := bool(region.get("sunlit", false))
	var rows: Array = []
	var potential := 0
	var warehouses := 0
	for value in facility_rows:
		if not (value is Dictionary):
			continue
		var source := value as Dictionary
		if str(source.get("region_id", "")) != region_id:
			continue
		potential += 1
		if str(source.get("occupancy", "")) != "occupied":
			continue
		var row := public_facility_row(source, sunlit)
		if row.is_empty():
			continue
		rows.append(row)
		if str(row.get("facility_type", "")) == "warehouse":
			warehouses += 1
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _sort_key(a) < _sort_key(b)
	)
	var unsealed := {
		"schema_version": SCHEMA_VERSION,
		"dto_id": DTO_ID,
		"ruleset_id": RULESET_ID,
		"map_fingerprint": map_fingerprint,
		"region_id": region_id,
		"display_name": str(region.get("display_name", region_id)),
		"public_index": maxi(0, int(region.get("public_index", 0))),
		"terrain_class": terrain,
		"sunlit": sunlit,
		"solar_efficiency_multiplier_bps": _multiplier_bps(
			region,
			["solar_efficiency_multiplier_bps", "facility_efficiency_multiplier_bps", "facility_efficiency_multiplier"],
			20000 if sunlit else 10000
		),
		"neighbor_region_ids": _neighbors(region.get("neighbor_region_ids", [])),
		"potential_facility_slot_count": potential,
		"occupied_facility_count": rows.size(),
		"public_warehouse_count": warehouses,
		"public_facilities": rows,
	}
	var dto := Wire.sealed_copy(unsealed, "dto_fingerprint")
	return dto if bool(validation_report(dto).get("valid", false)) else {}


static func public_facility_row(source: Dictionary, region_sunlit: bool) -> Dictionary:
	var kind := str(source.get("facility_type", ""))
	var region_id := str(source.get("region_id", ""))
	var industry_id := str(source.get("industry_id", ""))
	var occupancy := str(source.get("occupancy", "empty"))
	if kind not in FACILITY_TYPES or not Wire.is_stable_id(region_id) 			or not Wire.is_stable_id(industry_id) 			or occupancy not in ["empty", "occupied"]:
		return {}
	var sunlit := bool(source.get("sunlit", region_sunlit))
	var damage := maxi(0, _integer(source, ["damage_points", "damage"], 0))
	var owner_index := _integer(source, ["owner_public_index", "owner_player_index"], -1)
	var facility_id := _text(source, ["facility_id"])
	var slot_id := _text(source, ["slot_id", "target_slot_id"])
	if facility_id.is_empty():
		facility_id = "facility.unoccupied" if occupancy == "empty" else "facility.public"
	if slot_id.is_empty():
		slot_id = "%s::%s.%s" % [region_id, kind, industry_id]
	var owner_label := _text(source, ["owner_public_label", "owner_display_name"])
	if owner_label.is_empty() and owner_index >= 0:
		owner_label = "Player %d" % (owner_index + 1)
	var row := {
		"facility_id": facility_id,
		"slot_id": slot_id,
		"region_id": region_id,
		"facility_type": kind,
		"industry_id": industry_id,
		"owner_public_id": _text(source, ["owner_public_id", "owner_id"]),
		"owner_public_index": owner_index,
		"owner_public_label": owner_label,
		"rank": maxi(0, _integer(source, ["rank", "level"], 0)),
		"capacity_units": _warehouse_metric(source, kind, ["public_capacity", "capacity_units", "warehouse_capacity", "capacity"]),
		"ingress_throughput_units": _warehouse_metric(source, kind, ["public_ingress_throughput", "ingress_throughput_units", "ingress_throughput"]),
		"egress_throughput_units": _warehouse_metric(source, kind, ["public_egress_throughput", "egress_throughput_units", "egress_throughput"]),
		"solar_efficiency_state": "sunlit" if sunlit else "dark",
		"solar_efficiency_multiplier_bps": _multiplier_bps(
			source,
			["solar_efficiency_multiplier_bps", "facility_efficiency_multiplier_bps", "solar_multiplier"],
			20000 if sunlit else 10000
		),
		"damage_points": damage,
		"damage_revision": maxi(0, _integer(source, ["damage_revision"], 0)),
		"damage_state": "damaged" if damage > 0 else "operational",
		"occupancy": occupancy,
		"asset_key": str(source.get("asset_key", "model.facility.%s.base" % kind)),
	}
	return row if _facility_reason(row).is_empty() else {}


static func validation_report(value: Variant) -> Dictionary:
	if not (value is Dictionary) or not Wire.is_closed_data(value):
		return _invalid("region_popup_not_closed_data")
	var dto := value as Dictionary
	if not Wire.exact_fields(dto, DTO_FIELDS):
		return _invalid("region_popup_fields_invalid")
	if int(dto.get("schema_version", 0)) != SCHEMA_VERSION 			or str(dto.get("dto_id", "")) != DTO_ID 			or str(dto.get("ruleset_id", "")) != RULESET_ID:
		return _invalid("region_popup_identity_invalid")
	if not Wire.is_fingerprint(dto.get("map_fingerprint")) 			or not Wire.is_stable_id(dto.get("region_id")) 			or str(dto.get("terrain_class", "")) not in TERRAIN_CLASSES:
		return _invalid("region_popup_map_identity_invalid")
	for field in ["public_index", "solar_efficiency_multiplier_bps", "potential_facility_slot_count", "occupied_facility_count", "public_warehouse_count"]:
		if not Wire.is_nonnegative_integer(dto.get(field)):
			return _invalid("%s_invalid" % field)
	if Wire.stable_id_array_error(dto.get("neighbor_region_ids"), true, true) != "":
		return _invalid("region_popup_neighbors_invalid")
	var facilities: Variant = dto.get("public_facilities")
	if not (facilities is Array):
		return _invalid("region_popup_facilities_invalid")
	var warehouse_count := 0
	for row_variant in facilities as Array:
		if not (row_variant is Dictionary):
			return _invalid("region_popup_facility_row_invalid")
		var reason := _facility_reason(row_variant as Dictionary)
		if not reason.is_empty():
			return _invalid(reason)
		if str((row_variant as Dictionary).get("facility_type", "")) == "warehouse":
			warehouse_count += 1
	if warehouse_count != int(dto.get("public_warehouse_count", -1)) 			or (facilities as Array).size() != int(dto.get("occupied_facility_count", -1)):
		return _invalid("region_popup_facility_count_mismatch")
	if Wire.contains_key_recursive(dto, PRIVATE_KEYS):
		return _invalid("region_popup_private_field_detected")
	var fingerprint := str(dto.get("dto_fingerprint", ""))
	if not Wire.is_fingerprint(fingerprint) 			or fingerprint != Wire.fingerprint(dto, "dto_fingerprint"):
		return _invalid("region_popup_fingerprint_invalid")
	return {"valid": true, "reason_code": "none"}


static func _facility_reason(row: Dictionary) -> String:
	if not Wire.exact_fields(row, FACILITY_FIELDS):
		return "public_facility_fields_invalid"
	if str(row.get("facility_type", "")) not in FACILITY_TYPES 			or not Wire.is_stable_id(row.get("region_id")) 			or not Wire.is_stable_id(row.get("industry_id")):
		return "public_facility_identity_invalid"
	for field in ["facility_id", "slot_id", "asset_key"]:
		if not Wire.is_ascii_reference(row.get(field)):
			return "public_facility_reference_invalid"
	for field in ["rank", "capacity_units", "ingress_throughput_units", "egress_throughput_units", "solar_efficiency_multiplier_bps", "damage_points", "damage_revision"]:
		if not Wire.is_nonnegative_integer(row.get(field)):
			return "public_facility_metric_invalid"
	if not Wire.is_safe_integer(row.get("owner_public_index")) 			or str(row.get("solar_efficiency_state", "")) not in ["sunlit", "dark"] 			or str(row.get("damage_state", "")) not in ["operational", "damaged"] 			or str(row.get("occupancy", "")) not in ["empty", "occupied"]:
		return "public_facility_state_invalid"
	if str(row.get("facility_type", "")) != "warehouse" and (
		int(row.get("capacity_units", 0)) != 0 		or int(row.get("ingress_throughput_units", 0)) != 0 		or int(row.get("egress_throughput_units", 0)) != 0
	):
		return "nonwarehouse_storage_metrics_disclosed"
	return ""


static func _warehouse_metric(source: Dictionary, kind: String, fields: Array) -> int:
	return maxi(0, _integer(source, fields, 0)) if kind == "warehouse" else 0


static func _neighbors(value: Variant) -> Array:
	var result: Array[String] = []
	if value is Array:
		for item in value as Array:
			var region_id := str(item)
			if Wire.is_stable_id(region_id) and not result.has(region_id):
				result.append(region_id)
	result.sort()
	return result


static func _sort_key(row: Dictionary) -> String:
	return "%s|%s|%s" % [row.get("facility_type", ""), row.get("industry_id", ""), row.get("slot_id", "")]


static func _text(source: Dictionary, fields: Array) -> String:
	for value in fields:
		var field := str(value)
		if source.has(field):
			return str(source.get(field, ""))
	return ""


static func _integer(source: Dictionary, fields: Array, fallback: int) -> int:
	for value in fields:
		var field := str(value)
		if source.has(field) and (source.get(field) is int or source.get(field) is float):
			return int(source.get(field))
	return fallback


static func _multiplier_bps(source: Dictionary, fields: Array, fallback: int) -> int:
	for value in fields:
		var field := str(value)
		if not source.has(field):
			continue
		var raw: Variant = source.get(field)
		if raw is int:
			return int(raw) if int(raw) >= 1000 else int(raw) * 10000
		if raw is float:
			return int(round(float(raw) * 10000.0))
	return fallback


static func _invalid(reason_code: String) -> Dictionary:
	return {"valid": false, "reason_code": reason_code}
