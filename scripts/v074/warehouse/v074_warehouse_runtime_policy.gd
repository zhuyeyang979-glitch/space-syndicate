extends RefCounted
class_name V074WarehouseRuntimePolicy

const CATALOG_PATH := "res://data/v074/v074_facility_warehouse_catalog.json"
const RULESET_ID := "v0.7.4"
const FACILITY_TYPE := "warehouse"
const SOLAR_STATES := ["sunlit", "dark"]
const PUBLIC_FIELDS := [
	"facility_id",
	"facility_type",
	"industry_id",
	"region_id",
	"owner_id",
	"rank",
	"capacity",
	"base_ingress_throughput",
	"base_egress_throughput",
	"ingress_throughput",
	"egress_throughput",
	"damage_points",
	"damage_revision",
	"facility_generation",
	"slot_generation",
	"solar_efficiency_state",
	"commercial_art_key",
	"occupancy",
]
const PRIVATE_FORBIDDEN_FIELDS := [
	"warehouse_stock",
	"stock",
	"inventory",
	"inventory_items",
	"private_logistics",
	"logistics_plan",
	"future_transport_plan",
	"private_commodity_source",
	"future_action",
	"ai_private_plan",
]

static var _catalog_cache: Dictionary = {}


static func contract_snapshot() -> Dictionary:
	var catalog := _catalog()
	return {
		"schema_version": 1,
		"contract_id": "space_syndicate.v074.warehouse_runtime_policy.v1",
		"ruleset_id": RULESET_ID,
		"rank_profiles": (
			(catalog.get("rank_profiles", {}) as Dictionary).duplicate(true)
		),
		"solar_multipliers": (
			(catalog.get("solar_multipliers", {}) as Dictionary).duplicate(true)
		),
		"commercial_art_key": str(
			catalog.get("commercial_art_key", "")
		),
		"warehouse_stock_runtime_phase": str(
			catalog.get(
				"warehouse_stock_runtime_phase",
				"existing_external_owner_or_deferred"
			)
		),
		"world_owner_count": 0,
		"gameplay_owner_count": 0,
		"save_owner_count": 0,
		"rng_owner_count": 0,
		"render_brightness_rule_reader_count": 0,
		"stock_owner_count": 0,
		"private_logistics_owner_count": 0,
	}


static func rank_profile(rank: int) -> Dictionary:
	if rank < 1 or rank > 4:
		return {}
	var catalog := _catalog()
	var profiles := catalog.get("rank_profiles", {}) as Dictionary
	var profile_variant: Variant = profiles.get(str(rank))
	if not (profile_variant is Dictionary):
		return {}
	var profile := (profile_variant as Dictionary).duplicate(true)
	if _rank_profile_error(profile, rank) != "":
		return {}
	return profile


static func repair_points_for_rank(rank: int) -> int:
	return int(rank_profile(rank).get("repair_points", 0))


static func primary_asset_cost_for_rank(rank: int) -> int:
	return int(rank_profile(rank).get("primary_asset_cost", -1))


static func solar_multiplier(solar_state: String) -> float:
	var multipliers := _catalog().get("solar_multipliers", {}) as Dictionary
	if solar_state == "sunlit":
		return float(multipliers.get("sunlit", 2.0))
	if solar_state == "dark":
		return float(multipliers.get("dark", 1.0))
	return 0.0


static func runtime_facts(rank: int, solar_state: String) -> Dictionary:
	var profile := rank_profile(rank)
	if profile.is_empty() or solar_state not in SOLAR_STATES:
		return {}
	var multiplier := solar_multiplier(solar_state)
	var ingress := float(profile.get("ingress_throughput", 0)) * multiplier
	var egress := float(profile.get("egress_throughput", 0)) * multiplier
	if (
		not is_finite(ingress)
		or not is_finite(egress)
		or ingress != floor(ingress)
		or egress != floor(egress)
	):
		return {}
	return {
		"capacity": int(profile.get("capacity", 0)),
		"base_ingress_throughput": int(
			profile.get("ingress_throughput", 0)
		),
		"base_egress_throughput": int(
			profile.get("egress_throughput", 0)
		),
		"ingress_throughput": int(ingress),
		"egress_throughput": int(egress),
		"solar_efficiency_state": solar_state,
		"solar_efficiency_multiplier": multiplier,
		"commercial_art_key": str(
			_catalog().get(
				"commercial_art_key",
				"model.facility.warehouse.base"
			)
		),
		"warehouse_stock_runtime_phase": str(
			_catalog().get(
				"warehouse_stock_runtime_phase",
				"existing_external_owner_or_deferred"
			)
		),
	}


static func decorate_slot(
	slot: Dictionary,
	solar_state: String = "dark"
) -> Dictionary:
	var result := slot.duplicate(true)
	for field_name in [
		"capacity",
		"base_ingress_throughput",
		"base_egress_throughput",
		"ingress_throughput",
		"egress_throughput",
		"solar_efficiency_state",
		"commercial_art_key",
		"warehouse_stock_runtime_phase",
	]:
		result[field_name] = null
	if (
		str(result.get("facility_type", "")) != FACILITY_TYPE
		or str(result.get("occupancy", "")) != "occupied"
	):
		return result
	var facts := runtime_facts(int(result.get("rank", 0)), solar_state)
	if facts.is_empty():
		return {}
	for field_name in facts.keys():
		if field_name == "solar_efficiency_multiplier":
			continue
		result[field_name] = facts[field_name]
	return result


static func public_projection(slot: Dictionary) -> Dictionary:
	if str(slot.get("facility_type", "")) != FACILITY_TYPE:
		return {}
	if str(slot.get("occupancy", "")) != "occupied":
		return {}
	if slot_runtime_error(slot) != "":
		return {}
	var projection := {}
	for field_name in PUBLIC_FIELDS:
		projection[field_name] = slot.get(field_name)
	projection["public_projection_id"] = (
		"space_syndicate.v074.warehouse_public_projection.v1"
	)
	projection["stock_runtime_phase"] = str(
		slot.get(
			"warehouse_stock_runtime_phase",
			"existing_external_owner_or_deferred"
		)
	)
	projection["private_stock_included"] = false
	projection["private_logistics_included"] = false
	return projection


static func private_boundary_projection(slot: Dictionary) -> Dictionary:
	if str(slot.get("facility_type", "")) != FACILITY_TYPE:
		return {}
	return {
		"warehouse_id": str(slot.get("facility_id", "")),
		"stock_runtime_phase": str(
			slot.get(
				"warehouse_stock_runtime_phase",
				"existing_external_owner_or_deferred"
			)
		),
		"stock_payload_included": false,
		"logistics_payload_included": false,
		"external_stock_owner_required": true,
	}


static func slot_runtime_error(slot: Dictionary) -> String:
	if str(slot.get("facility_type", "")) != FACILITY_TYPE:
		return ""
	if str(slot.get("occupancy", "")) == "empty":
		for field_name in [
			"capacity",
			"base_ingress_throughput",
			"base_egress_throughput",
			"ingress_throughput",
			"egress_throughput",
			"solar_efficiency_state",
			"commercial_art_key",
			"warehouse_stock_runtime_phase",
		]:
			if slot.get(field_name) != null:
				return "empty_warehouse_runtime_field_not_null"
		return ""
	if str(slot.get("occupancy", "")) != "occupied":
		return "warehouse_occupancy_invalid"
	var rank := int(slot.get("rank", 0))
	var solar_state := str(slot.get("solar_efficiency_state", ""))
	var expected := runtime_facts(rank, solar_state)
	if expected.is_empty():
		return "warehouse_runtime_profile_invalid"
	for field_name in [
		"capacity",
		"base_ingress_throughput",
		"base_egress_throughput",
		"ingress_throughput",
		"egress_throughput",
		"solar_efficiency_state",
		"commercial_art_key",
		"warehouse_stock_runtime_phase",
	]:
		if slot.get(field_name) != expected.get(field_name):
			return "warehouse_runtime_field_mismatch:%s" % field_name
	return ""


static func privacy_report(projection: Dictionary) -> Dictionary:
	var leaked_fields: Array[String] = []
	_collect_forbidden_fields(projection, leaked_fields)
	return {
		"valid": leaked_fields.is_empty(),
		"hidden_info_field_count": leaked_fields.size(),
		"leaked_fields": leaked_fields,
		"stock_runtime_phase": str(
			projection.get(
				"stock_runtime_phase",
				"existing_external_owner_or_deferred"
			)
		),
	}


static func _catalog() -> Dictionary:
	if not _catalog_cache.is_empty():
		return _catalog_cache
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return {}
	var catalog := parsed as Dictionary
	if (
		int(catalog.get("schema_version", 0)) != 1
		or str(catalog.get("ruleset_id", "")) != RULESET_ID
	):
		return {}
	_catalog_cache = catalog.duplicate(true)
	return _catalog_cache


static func _rank_profile_error(profile: Dictionary, rank: int) -> String:
	var expected_fields := [
		"capacity",
		"ingress_throughput",
		"egress_throughput",
		"repair_points",
		"primary_asset_cost",
	]
	if profile.size() != expected_fields.size():
		return "warehouse_rank_profile_fields_invalid"
	for field_name in expected_fields:
		if not profile.has(field_name):
			return "warehouse_rank_profile_field_missing"
		if not _nonnegative_integral_number(profile.get(field_name)):
			return "warehouse_rank_profile_value_not_integer"
	if int(profile.get("primary_asset_cost", -1)) != rank:
		return "warehouse_rank_asset_cost_mismatch"
	return ""


static func _nonnegative_integral_number(value: Variant) -> bool:
	if value is int:
		return int(value) >= 0
	if value is float:
		var number := float(value)
		return is_finite(number) and number >= 0.0 and number == floor(number)
	return false


static func _collect_forbidden_fields(
	value: Variant,
	result: Array[String],
	path: String = ""
) -> void:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant)
			var field_path := key if path.is_empty() else "%s.%s" % [path, key]
			if PRIVATE_FORBIDDEN_FIELDS.has(key):
				result.append(field_path)
			_collect_forbidden_fields(
				(value as Dictionary).get(key_variant),
				result,
				field_path
			)
	elif value is Array:
		for index in range((value as Array).size()):
			_collect_forbidden_fields(
				(value as Array)[index],
				result,
				"%s[%d]" % [path, index]
			)
