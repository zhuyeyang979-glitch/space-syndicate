extends RefCounted
class_name MapGenesisRequestV1

const SCHEMA_VERSION := 1
const CONTRACT_ID := "MapGenesisRequestV1"
const RULESET_ID := "v0.7.4"
const SUPPORTED_REGION_MIN := 6
const SUPPORTED_REGION_MAX := 30
const COMPLEXITIES := ["SIMPLE", "STANDARD", "COMPLEX"]
const LAND_OCEAN_PROFILES := ["CONTINENTAL", "BALANCED", "ARCHIPELAGO"]
const REGISTERED_FACILITY_TYPES := ["factory", "market", "warehouse"]
const INDUSTRY_IDS := ["life", "energy", "industry", "technology", "commerce", "shipping"]


static func normalize(raw: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	if int(raw.get("schema_version", -1)) != SCHEMA_VERSION:
		errors.append("map_genesis_request_schema_invalid")
	if str(raw.get("ruleset_id", "")) != RULESET_ID:
		errors.append("map_genesis_request_ruleset_invalid")
	if not (raw.get("map_seed") is int):
		errors.append("map_genesis_request_seed_invalid")
	var region_count := int(raw.get("region_count", 0))
	if region_count < SUPPORTED_REGION_MIN or region_count > SUPPORTED_REGION_MAX:
		errors.append("map_genesis_request_region_count_unsupported")
	var complexity := str(raw.get("geography_complexity", "")).to_upper()
	if not COMPLEXITIES.has(complexity):
		errors.append("map_genesis_request_complexity_invalid")
	var profile := str(raw.get("land_ocean_profile", "")).to_upper()
	if not LAND_OCEAN_PROFILES.has(profile):
		errors.append("map_genesis_request_land_ocean_profile_invalid")
	var facility_types := _stable_string_array(raw.get("registered_facility_types", []))
	if facility_types != REGISTERED_FACILITY_TYPES:
		errors.append("map_genesis_request_facility_registry_invalid")
	var industries := _stable_string_array(raw.get("industry_ids", []))
	if industries != INDUSTRY_IDS:
		errors.append("map_genesis_request_industry_registry_invalid")
	if not errors.is_empty():
		return {
			"accepted": false,
			"contract_id": CONTRACT_ID,
			"reason_code": errors[0],
			"errors": errors,
			"request": {},
		}
	var normalized := {
		"schema_version": SCHEMA_VERSION,
		"contract_id": CONTRACT_ID,
		"ruleset_id": RULESET_ID,
		"map_seed": int(raw.get("map_seed", 0)),
		"region_count": region_count,
		"geography_complexity": complexity,
		"land_ocean_profile": profile,
		"registered_facility_types": facility_types,
		"industry_ids": industries,
	}
	normalized["map_profile_id"] = profile_id(normalized)
	normalized["canonical_key"] = canonical_key(normalized)
	return {
		"accepted": true,
		"contract_id": CONTRACT_ID,
		"reason_code": "map_genesis_request_valid",
		"errors": [],
		"request": normalized,
	}


static func build(
	map_seed: int,
	region_count: int,
	geography_complexity: String,
	land_ocean_profile: String,
	registered_facility_types: Array = REGISTERED_FACILITY_TYPES,
	industry_ids: Array = INDUSTRY_IDS
) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"ruleset_id": RULESET_ID,
		"map_seed": map_seed,
		"region_count": region_count,
		"geography_complexity": geography_complexity.to_upper(),
		"land_ocean_profile": land_ocean_profile.to_upper(),
		"registered_facility_types": registered_facility_types.duplicate(),
		"industry_ids": industry_ids.duplicate(),
	}


static func profile_id(request: Dictionary) -> String:
	return "v074.%s.%s.regions_%d" % [
		str(request.get("geography_complexity", "")).to_lower(),
		str(request.get("land_ocean_profile", "")).to_lower(),
		int(request.get("region_count", 0)),
	]


static func canonical_key(request: Dictionary) -> String:
	return "%s|%d|%d|%s|%s|%s|%s" % [
		str(request.get("ruleset_id", "")),
		int(request.get("map_seed", 0)),
		int(request.get("region_count", 0)),
		str(request.get("geography_complexity", "")),
		str(request.get("land_ocean_profile", "")),
		",".join(PackedStringArray(request.get("registered_facility_types", []))),
		",".join(PackedStringArray(request.get("industry_ids", []))),
	]


static func _stable_string_array(value: Variant) -> Array:
	if not (value is Array):
		return []
	var result: Array[String] = []
	var seen := {}
	for item in value as Array:
		var text := str(item)
		if text.is_empty() or seen.has(text):
			return []
		seen[text] = true
		result.append(text)
	return result
