extends RefCounted
class_name V074CardDefinitionRegistry

const FacilityTypes := preload(
	"res://scripts/v074/facility/v074_facility_type_registry.gd"
)

const SCHEMA_VERSION := 1
const REGISTRY_ID := "space_syndicate.v074.card_definition_registry.v1"
const RULESET_ID := "v0.7.4"
const BALANCE_PROFILE_ID := "V074_ROGUELIKE_WAREHOUSE_BASELINE"
const BALANCE_PROFILE_FINGERPRINT := (
	"7bb3a3c9887d4c6328347b62dc4b582251bb1abbb0190493f47621863b5ee7b1"
)
const PROFILE_FINGERPRINT_INPUT := (
	"V074_ROGUELIKE_WAREHOUSE_BASELINE|"
	+ "registered_facility_types=factory,market,warehouse|"
	+ "starter_facility_types=factory,market|"
	+ "standard_track_facility_types=factory,market,warehouse|"
	+ "warehouse_capacity=200,400,700,1100|"
	+ "warehouse_ingress=50,100,175,275|"
	+ "warehouse_egress=50,100,175,275|"
	+ "warehouse_primary_asset_cost=1,2,3,4|"
	+ "sunlit_multiplier=2.0|dark_multiplier=1.0"
)

const COLORS := FacilityTypes.INDUSTRY_IDS
const CARD_TYPES := FacilityTypes.REGISTERED_FACILITY_TYPES
const STARTER_CARD_TYPES := FacilityTypes.STARTER_FACILITY_TYPES
const ORIGIN_STARTER := "starter_bootstrap"
const ORIGIN_STANDARD := "standard"
const STARTER_COST_PROFILE := "starter_zero_asset"
const MIN_LEVEL := 1
const MAX_LEVEL := 4

const DEFINITION_FIELDS := [
	"definition_id",
	"semantic_id",
	"origin_class",
	"primary_color",
	"card_type",
	"merge_family_id",
	"level",
	"asset_cost_profile",
	"primary_asset_cost",
	"secondary_asset_cost",
	"any_asset_cost",
	"starter_badge",
	"track_spawn_allowed",
	"purchase_allowed",
]


static func registry_contract() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"registry_id": REGISTRY_ID,
		"ruleset_id": RULESET_ID,
		"balance_profile_id": BALANCE_PROFILE_ID,
		"balance_profile_fingerprint": BALANCE_PROFILE_FINGERPRINT,
		"starter_definition_ids": starter_definition_ids(),
		"standard_l1_definition_ids": standard_l1_definition_ids(),
		"normal_track_supply_definition_ids": normal_track_supply_definition_ids(),
		"warehouse_standard_l1_definition_ids": warehouse_standard_l1_definition_ids(),
		"starter_definition_count": starter_definition_ids().size(),
		"standard_l1_definition_count": standard_l1_definition_ids().size(),
		"warehouse_starter_card_count": 0,
		"warehouse_standard_l1_definition_count": warehouse_standard_l1_definition_ids().size(),
		"starter_creation_phase": "genesis_only",
		"starter_creation_allowed_after_genesis": false,
		"starter_track_spawn_allowed": false,
		"starter_standard_l1_merge_allowed": true,
		"starter_zero_cost_privilege_inherited": false,
		"commodity_definition_owner_count": 0,
		"rng_stream_ids": [],
		"production_runtime_connection_count": 0,
	}


static func starter_definition_ids() -> Array[String]:
	var result: Array[String] = []
	for color_id in COLORS:
		for card_type in STARTER_CARD_TYPES:
			result.append(starter_definition_id(str(card_type), str(color_id)))
	return result


static func standard_l1_definition_ids() -> Array[String]:
	var result: Array[String] = []
	for color_id in COLORS:
		for card_type in CARD_TYPES:
			result.append(standard_definition_id(str(card_type), str(color_id), 1))
	return result


static func normal_track_supply_definition_ids() -> Array[String]:
	return standard_l1_definition_ids()


static func track_spawn_definition_ids() -> Array[String]:
	return normal_track_supply_definition_ids()


static func warehouse_standard_l1_definition_ids() -> Array[String]:
	var result: Array[String] = []
	for color_id in COLORS:
		result.append(standard_definition_id("warehouse", str(color_id), 1))
	return result


static func warehouse_standard_l1_definitions() -> Array:
	var result: Array = []
	for definition_id in warehouse_standard_l1_definition_ids():
		result.append(definition(definition_id))
	return result


static func standard_definition_ids() -> Array[String]:
	var result: Array[String] = []
	for level in range(MIN_LEVEL, MAX_LEVEL + 1):
		for color_id in COLORS:
			for card_type in CARD_TYPES:
				result.append(
					standard_definition_id(str(card_type), str(color_id), level)
				)
	return result


static func all_definition_ids() -> Array[String]:
	var result := starter_definition_ids()
	result.append_array(standard_definition_ids())
	return result


static func starter_definition_id(card_type: String, color_id: String) -> String:
	if card_type not in STARTER_CARD_TYPES or color_id not in COLORS:
		return ""
	return "starter.facility.%s.%s.rank_1" % [card_type, color_id]


static func standard_definition_id(
	card_type: String,
	color_id: String,
	level: int
) -> String:
	if card_type not in CARD_TYPES or color_id not in COLORS:
		return ""
	if level < MIN_LEVEL or level > MAX_LEVEL:
		return ""
	return "facility.%s.%s.rank_%d" % [card_type, color_id, level]


static func merge_family_id(card_type: String, color_id: String) -> String:
	if card_type not in CARD_TYPES or color_id not in COLORS:
		return ""
	return "facility.%s.%s" % [card_type, color_id]


static func definition(definition_id: String) -> Dictionary:
	var parsed := _parse_definition_id(definition_id)
	if parsed.is_empty():
		return {}
	var origin_class := str(parsed.get("origin_class", ""))
	var card_type := str(parsed.get("card_type", ""))
	var color_id := str(parsed.get("primary_color", ""))
	var level := int(parsed.get("level", 0))
	var starter := origin_class == ORIGIN_STARTER
	var primary_cost := 0 if starter else level
	var cost_profile := (
		STARTER_COST_PROFILE if starter else "standard_rank_%d" % level
	)
	return {
		"definition_id": definition_id,
		"semantic_id": definition_id,
		"origin_class": origin_class,
		"primary_color": color_id,
		"card_type": card_type,
		"merge_family_id": merge_family_id(card_type, color_id),
		"level": level,
		"asset_cost_profile": cost_profile,
		"primary_asset_cost": primary_cost,
		"secondary_asset_cost": 0,
		"any_asset_cost": 0,
		"starter_badge": starter,
		"track_spawn_allowed": not starter and level == 1,
		"purchase_allowed": not starter,
	}


static func starter_definitions() -> Array:
	var result: Array = []
	for definition_id in starter_definition_ids():
		result.append(definition(definition_id))
	return result


static func standard_l1_definitions() -> Array:
	var result: Array = []
	for definition_id in standard_l1_definition_ids():
		result.append(definition(definition_id))
	return result


static func commodity_definition_ids() -> Array[String]:
	return []


static func commodity_definitions() -> Array:
	return []


static func commodity_definition(_definition_id: String) -> Dictionary:
	return {}


static func is_starter_definition(definition_id: String) -> bool:
	return str(definition(definition_id).get("origin_class", "")) == ORIGIN_STARTER


static func definition_error(value: Dictionary) -> String:
	if not _exact_fields(value, DEFINITION_FIELDS):
		return "definition_fields_invalid"
	var canonical := definition(str(value.get("definition_id", "")))
	if canonical.is_empty():
		return "definition_id_invalid"
	if value != canonical:
		return "definition_contract_mismatch"
	return ""


static func resolve_primary_asset_cost(definition_id: String) -> Dictionary:
	var value := definition(definition_id)
	if value.is_empty():
		return {
			"valid": false,
			"reason_code": "card_definition_unknown",
		}
	return {
		"valid": true,
		"reason_code": "card_definition_cost_resolved",
		"definition_id": definition_id,
		"origin_class": str(value.get("origin_class", "")),
		"asset_cost_profile": str(value.get("asset_cost_profile", "")),
		"primary_color": str(value.get("primary_color", "")),
		"primary_asset_cost": int(value.get("primary_asset_cost", -1)),
		"secondary_asset_cost": int(value.get("secondary_asset_cost", -1)),
		"any_asset_cost": int(value.get("any_asset_cost", -1)),
	}


static func starter_standard_merge(left_id: String, right_id: String) -> Dictionary:
	var left := definition(left_id)
	var right := definition(right_id)
	if left.is_empty() or right.is_empty():
		return _merge_result(false, "merge_definition_unknown")
	if str(left.get("merge_family_id", "")) != str(right.get("merge_family_id", "")):
		return _merge_result(false, "merge_family_mismatch")
	if int(left.get("level", 0)) != 1 or int(right.get("level", 0)) != 1:
		return _merge_result(false, "starter_standard_merge_requires_level_one")
	var origins := [
		str(left.get("origin_class", "")),
		str(right.get("origin_class", "")),
	]
	origins.sort()
	if origins != [ORIGIN_STANDARD, ORIGIN_STARTER]:
		return _merge_result(false, "starter_standard_origin_pair_required")
	var output_id := standard_definition_id(
		str(left.get("card_type", "")),
		str(left.get("primary_color", "")),
		2
	)
	return {
		"accepted": true,
		"reason_code": "starter_standard_l1_merge_allowed",
		"source_definition_ids": [left_id, right_id],
		"source_origin_classes": [
			str(left.get("origin_class", "")),
			str(right.get("origin_class", "")),
		],
		"output_definition_id": output_id,
		"output_origin_class": ORIGIN_STANDARD,
		"output_definition": definition(output_id),
		"starter_privilege_consumed": true,
	}


static func _parse_definition_id(definition_id: String) -> Dictionary:
	var parts := definition_id.split(".")
	if (
		parts.size() == 5
		and str(parts[0]) == "starter"
		and str(parts[1]) == "facility"
		and str(parts[2]) in STARTER_CARD_TYPES
		and str(parts[3]) in COLORS
		and str(parts[4]) == "rank_1"
	):
		return {
			"origin_class": ORIGIN_STARTER,
			"card_type": str(parts[2]),
			"primary_color": str(parts[3]),
			"level": 1,
		}
	if (
		parts.size() == 4
		and str(parts[0]) == "facility"
		and str(parts[1]) in CARD_TYPES
		and str(parts[2]) in COLORS
		and str(parts[3]).begins_with("rank_")
	):
		var level_text := str(parts[3]).trim_prefix("rank_")
		if level_text.is_valid_int():
			var level := int(level_text)
			if level >= MIN_LEVEL and level <= MAX_LEVEL:
				return {
					"origin_class": ORIGIN_STANDARD,
					"card_type": str(parts[1]),
					"primary_color": str(parts[2]),
					"level": level,
				}
	return {}


static func _merge_result(accepted: bool, reason_code: String) -> Dictionary:
	return {
		"accepted": accepted,
		"reason_code": reason_code,
		"source_definition_ids": [],
		"source_origin_classes": [],
		"output_definition_id": "",
		"output_origin_class": "",
		"output_definition": {},
		"starter_privilege_consumed": false,
	}


static func _exact_fields(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for field_name in expected:
		if not value.has(field_name):
			return false
	return true
