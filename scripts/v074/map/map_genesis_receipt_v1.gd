extends RefCounted
class_name MapGenesisReceiptV1

const SCHEMA_VERSION := 1
const CONTRACT_ID := "MapGenesisReceiptV1"
const RULESET_ID := "v0.7.4"
const REQUIRED_FIELDS := [
	"schema_version",
	"contract_id",
	"ruleset_id",
	"accepted",
	"reason_code",
	"map_id",
	"map_seed",
	"map_profile_id",
	"region_count",
	"region_ids",
	"terrain_by_region",
	"region_centers_unit_sphere",
	"region_microcell_membership",
	"microcell_centers_unit_sphere",
	"region_boundaries_spherical",
	"region_boundary_lods_spherical",
	"adjacency_graph",
	"land_ocean_edges",
	"facility_slot_registry",
	"initial_sun_direction",
	"map_fingerprint",
]


static func failure(reason_code: String, request: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"contract_id": CONTRACT_ID,
		"ruleset_id": RULESET_ID,
		"accepted": false,
		"reason_code": reason_code,
		"request": request.duplicate(true),
		"map_id": "",
		"map_seed": int(request.get("map_seed", 0)),
		"map_profile_id": str(request.get("map_profile_id", "")),
		"region_count": 0,
		"region_ids": [],
		"terrain_by_region": {},
		"region_centers_unit_sphere": {},
		"region_microcell_membership": {},
		"microcell_centers_unit_sphere": [],
		"region_boundaries_spherical": {},
		"region_boundary_lods_spherical": {},
		"adjacency_graph": {},
		"land_ocean_edges": [],
		"facility_slot_registry": {},
		"initial_sun_direction": Vector3.ZERO,
		"map_fingerprint": "",
	}


static func validate(receipt: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	for field in REQUIRED_FIELDS:
		if not receipt.has(field):
			errors.append("map_genesis_receipt_missing_%s" % field)
	if not errors.is_empty():
		return _report(errors)
	if int(receipt.get("schema_version", -1)) != SCHEMA_VERSION:
		errors.append("map_genesis_receipt_schema_invalid")
	if str(receipt.get("contract_id", "")) != CONTRACT_ID:
		errors.append("map_genesis_receipt_contract_invalid")
	if str(receipt.get("ruleset_id", "")) != RULESET_ID:
		errors.append("map_genesis_receipt_ruleset_invalid")
	if not bool(receipt.get("accepted", false)):
		errors.append(str(receipt.get("reason_code", "map_genesis_receipt_rejected")))
	var region_count := int(receipt.get("region_count", 0))
	var region_ids := receipt.get("region_ids", []) as Array
	if region_count <= 0 or region_ids.size() != region_count:
		errors.append("map_genesis_receipt_region_count_mismatch")
	if not (receipt.get("terrain_by_region") is Dictionary) 			or (receipt.get("terrain_by_region") as Dictionary).size() != region_count:
		errors.append("map_genesis_receipt_terrain_count_mismatch")
	if not (receipt.get("region_centers_unit_sphere") is Dictionary) 			or (receipt.get("region_centers_unit_sphere") as Dictionary).size() != region_count:
		errors.append("map_genesis_receipt_center_count_mismatch")
	if not (receipt.get("region_microcell_membership") is Dictionary) 			or (receipt.get("region_microcell_membership") as Dictionary).size() != region_count:
		errors.append("map_genesis_receipt_membership_count_mismatch")
	if not (receipt.get("region_boundaries_spherical") is Dictionary) 			or (receipt.get("region_boundaries_spherical") as Dictionary).size() != region_count:
		errors.append("map_genesis_receipt_boundary_count_mismatch")
	if not (receipt.get("adjacency_graph") is Dictionary) 			or (receipt.get("adjacency_graph") as Dictionary).size() != region_count:
		errors.append("map_genesis_receipt_adjacency_count_mismatch")
	var sun: Variant = receipt.get("initial_sun_direction", Vector3.ZERO)
	if not (sun is Vector3) or not (sun as Vector3).is_normalized():
		errors.append("map_genesis_receipt_sun_direction_invalid")
	var fingerprint := str(receipt.get("map_fingerprint", ""))
	if fingerprint.length() != 64 or not fingerprint.is_valid_hex_number(false):
		errors.append("map_genesis_receipt_fingerprint_invalid")
	return _report(errors)


static func _report(errors: Array[String]) -> Dictionary:
	return {
		"valid": errors.is_empty(),
		"error_count": errors.size(),
		"errors": errors,
		"reason_code": "map_genesis_receipt_valid" if errors.is_empty() else errors[0],
	}
