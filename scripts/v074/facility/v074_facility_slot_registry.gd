extends RefCounted
class_name V074FacilitySlotRegistry

const FacilityTypes := preload(
	"res://scripts/v074/facility/v074_facility_type_registry.gd"
)
const FacilityRuntimeCore := preload(
	"res://scripts/v074/facility/v074_facility_runtime_core.gd"
)

const SCHEMA_VERSION := 1
const REGISTRY_ID := "space_syndicate.v074.facility_slot_registry.v1"
const RULESET_ID := "v0.7.4"


static func registry_contract() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"registry_id": REGISTRY_ID,
		"ruleset_id": RULESET_ID,
		"slot_key_fields": ["region_id", "facility_type", "industry_id"],
		"registered_facility_types": FacilityTypes.registered_facility_types(),
		"industry_ids": FacilityTypes.industry_ids(),
		"facility_slot_count_per_region": facility_slot_count_per_region(),
		"land_receives_complete_matrix": true,
		"ocean_receives_complete_matrix": true,
		"gameplay_owner_count": 0,
		"map_owner_count": 0,
		"save_owner_count": 0,
		"rng_owner_count": 0,
	}


static func facility_slot_count_per_region() -> int:
	return FacilityTypes.facility_slot_count_per_region()


static func total_facility_slot_count(region_count: int) -> int:
	return FacilityTypes.total_facility_slot_count(region_count)


static func slot_id(
	region_id: String,
	facility_type: String,
	industry_id: String
) -> String:
	return FacilityRuntimeCore.facility_slot_id(
		region_id,
		facility_type,
		industry_id
	)


static func build_slots(
	region_ids: Array,
	region_revisions: Dictionary = {}
) -> Array:
	var normalized_ids := _normalized_region_ids(region_ids)
	if normalized_ids.size() != region_ids.size():
		return []
	var result: Array = []
	for region_id in normalized_ids:
		var region_revision := int(region_revisions.get(region_id, 1))
		if region_revision < 0:
			return []
		for facility_type in FacilityTypes.REGISTERED_FACILITY_TYPES:
			for industry_id in FacilityTypes.INDUSTRY_IDS:
				var slot := FacilityRuntimeCore.build_empty_slot(
					region_id,
					region_revision,
					str(facility_type),
					str(industry_id),
					0
				)
				if slot.is_empty():
					return []
				result.append(slot)
	return result


static func build_slot_registry(
	region_ids: Array,
	region_revisions: Dictionary = {}
) -> Dictionary:
	var slots := build_slots(region_ids, region_revisions)
	if slots.is_empty() and not region_ids.is_empty():
		return {}
	var result := {}
	for slot_variant in slots:
		var slot := slot_variant as Dictionary
		var key := str(slot.get("slot_id", ""))
		if key.is_empty() or result.has(key):
			return {}
		result[key] = slot.duplicate(true)
	return result


static func validation_report(
	region_ids: Array,
	slots: Array
) -> Dictionary:
	var normalized_ids := _normalized_region_ids(region_ids)
	var duplicate_key_count := 0
	var region_reference_missing_count := 0
	var type_reference_missing_count := 0
	var industry_reference_missing_count := 0
	var invalid_slot_count := 0
	var seen_keys := {}
	var counts_by_region := {}
	for slot_variant in slots:
		if not (slot_variant is Dictionary):
			invalid_slot_count += 1
			continue
		var slot := slot_variant as Dictionary
		var key := str(slot.get("slot_id", ""))
		if seen_keys.has(key):
			duplicate_key_count += 1
		seen_keys[key] = true
		var region_id := str(slot.get("region_id", ""))
		var facility_type := str(slot.get("facility_type", ""))
		var industry_id := str(slot.get("industry_id", ""))
		if region_id not in normalized_ids:
			region_reference_missing_count += 1
		if not FacilityTypes.is_registered(facility_type):
			type_reference_missing_count += 1
		if industry_id not in FacilityTypes.INDUSTRY_IDS:
			industry_reference_missing_count += 1
		if key != slot_id(region_id, facility_type, industry_id):
			invalid_slot_count += 1
		if not bool(
			FacilityRuntimeCore.slot_validation_report(slot).get(
				"valid",
				false
			)
		):
			invalid_slot_count += 1
		counts_by_region[region_id] = int(
			counts_by_region.get(region_id, 0)
		) + 1
	var region_count_mismatch := 0
	for region_id in normalized_ids:
		if int(counts_by_region.get(region_id, 0)) != facility_slot_count_per_region():
			region_count_mismatch += 1
	var expected_count := (
		normalized_ids.size() * facility_slot_count_per_region()
	)
	var valid := (
		normalized_ids.size() == region_ids.size()
		and slots.size() == expected_count
		and duplicate_key_count == 0
		and region_reference_missing_count == 0
		and type_reference_missing_count == 0
		and industry_reference_missing_count == 0
		and invalid_slot_count == 0
		and region_count_mismatch == 0
	)
	return {
		"valid": valid,
		"reason_code": (
			"facility_slot_registry_valid"
			if valid
			else "facility_slot_registry_invalid"
		),
		"region_count": normalized_ids.size(),
		"expected_slot_count": expected_count,
		"actual_slot_count": slots.size(),
		"facility_slot_count_per_region": facility_slot_count_per_region(),
		"duplicate_key_count": duplicate_key_count,
		"region_reference_missing_count": region_reference_missing_count,
		"type_reference_missing_count": type_reference_missing_count,
		"industry_reference_missing_count": industry_reference_missing_count,
		"invalid_slot_count": invalid_slot_count,
		"region_count_mismatch": region_count_mismatch,
	}


static func _normalized_region_ids(region_ids: Array) -> Array[String]:
	var result: Array[String] = []
	var seen := {}
	for region_id_variant in region_ids:
		if not (region_id_variant is String):
			return []
		var region_id := str(region_id_variant).strip_edges()
		if region_id.is_empty() or seen.has(region_id):
			return []
		seen[region_id] = true
		result.append(region_id)
	return result
