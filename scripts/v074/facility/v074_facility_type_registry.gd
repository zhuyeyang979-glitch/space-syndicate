extends RefCounted
class_name V074FacilityTypeRegistry

const SCHEMA_VERSION := 1
const REGISTRY_ID := "space_syndicate.v074.facility_type_registry.v1"
const RULESET_ID := "v0.7.4"
const MAX_FACILITY_RANK := 4

const REGISTERED_FACILITY_TYPES := ["factory", "market", "warehouse"]
const STARTER_FACILITY_TYPES := ["factory", "market"]
const STANDARD_TRACK_FACILITY_TYPES := ["factory", "market", "warehouse"]
const INDUSTRY_IDS := [
	"life",
	"energy",
	"industry",
	"technology",
	"commerce",
	"shipping",
]
const COMMERCIAL_ART_KEYS := {
	"factory": "model.facility.factory.base",
	"market": "model.facility.market.base",
	"warehouse": "model.facility.warehouse.base",
}


static func registry_contract() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"registry_id": REGISTRY_ID,
		"ruleset_id": RULESET_ID,
		"registered_facility_types": registered_facility_types(),
		"starter_facility_types": starter_facility_types(),
		"standard_track_facility_types": standard_track_facility_types(),
		"industry_ids": industry_ids(),
		"registered_facility_type_count": REGISTERED_FACILITY_TYPES.size(),
		"facility_slot_key_fields": ["region_id", "facility_type", "industry_id"],
		"facility_slot_count_per_region": facility_slot_count_per_region(),
		"warehouse_retired": false,
		"warehouse_starter_card_count": 0,
		"gameplay_owner_count": 0,
		"save_owner_count": 0,
		"rng_owner_count": 0,
	}


static func registered_facility_types() -> Array[String]:
	var result: Array[String] = []
	result.assign(REGISTERED_FACILITY_TYPES)
	return result


static func starter_facility_types() -> Array[String]:
	var result: Array[String] = []
	result.assign(STARTER_FACILITY_TYPES)
	return result


static func standard_track_facility_types() -> Array[String]:
	var result: Array[String] = []
	result.assign(STANDARD_TRACK_FACILITY_TYPES)
	return result


static func industry_ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(INDUSTRY_IDS)
	return result


static func facility_slot_count_per_region() -> int:
	return REGISTERED_FACILITY_TYPES.size() * INDUSTRY_IDS.size()


static func total_facility_slot_count(region_count: int) -> int:
	return maxi(0, region_count) * facility_slot_count_per_region()


static func is_registered(facility_type: String) -> bool:
	return REGISTERED_FACILITY_TYPES.has(facility_type)


static func is_starter_type(facility_type: String) -> bool:
	return STARTER_FACILITY_TYPES.has(facility_type)


static func is_standard_track_type(facility_type: String) -> bool:
	return STANDARD_TRACK_FACILITY_TYPES.has(facility_type)


static func commercial_art_key(facility_type: String) -> String:
	return str(COMMERCIAL_ART_KEYS.get(facility_type, ""))


static func validation_report() -> Dictionary:
	var duplicate_count := (
		REGISTERED_FACILITY_TYPES.size()
		- _unique_strings(REGISTERED_FACILITY_TYPES).size()
	)
	var starter_outside_registry := 0
	for facility_type in STARTER_FACILITY_TYPES:
		if not REGISTERED_FACILITY_TYPES.has(facility_type):
			starter_outside_registry += 1
	var track_outside_registry := 0
	for facility_type in STANDARD_TRACK_FACILITY_TYPES:
		if not REGISTERED_FACILITY_TYPES.has(facility_type):
			track_outside_registry += 1
	var valid := (
		REGISTERED_FACILITY_TYPES == ["factory", "market", "warehouse"]
		and STARTER_FACILITY_TYPES == ["factory", "market"]
		and STANDARD_TRACK_FACILITY_TYPES == REGISTERED_FACILITY_TYPES
		and INDUSTRY_IDS.size() == 6
		and duplicate_count == 0
		and starter_outside_registry == 0
		and track_outside_registry == 0
		and facility_slot_count_per_region() == 18
		and commercial_art_key("warehouse") == "model.facility.warehouse.base"
	)
	return {
		"valid": valid,
		"reason_code": "facility_type_registry_valid" if valid else "facility_type_registry_invalid",
		"duplicate_type_count": duplicate_count,
		"starter_outside_registry_count": starter_outside_registry,
		"track_outside_registry_count": track_outside_registry,
	}


static func _unique_strings(values: Array) -> Array[String]:
	var seen := {}
	var result: Array[String] = []
	for value_variant in values:
		var value := str(value_variant)
		if seen.has(value):
			continue
		seen[value] = true
		result.append(value)
	return result
