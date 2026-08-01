extends RefCounted
class_name V072CardDefinitionRegistry

## Detached, pure definition authority for V0.7.2 facility cards. Starter
## privileges live in definitions and survive every instance-zone transition.

const SCHEMA_VERSION := 1
const REGISTRY_ID := "space_syndicate.v072.card_definition_registry.v1"
const RULESET_ID := "v0.7.2"
const BALANCE_PROFILE_ID := "V072_STARTER_FREE_FAST"
const BALANCE_PROFILE_FINGERPRINT := (
	"b8f684ab92b06fa44671c38d041ff08b9c1ea7c2950b094705e19192f0a70f48"
)
const PROFILE_FINGERPRINT_INPUT := (
	"V072_STARTER_FREE_FAST|initial_assets_per_color=0|starter_primary_asset_cost=0|"
	+ "standard_l1_primary_asset_cost=1|normal_card_ratio_basis_points=6000|"
	+ "commodity_card_ratio_basis_points=4000|"
	+ "single_color_net_intervention_cap_enabled=true|"
	+ "single_color_net_intervention_cap_basis_points=1200|"
	+ "max_asset_refresh_per_color_per_batch=3|"
	+ "hand_maintenance_timeout_seconds=8|lead_tenure_batches=1|"
	+ "color_cycle_batches=6"
)

const COLORS := [
	"life",
	"energy",
	"industry",
	"technology",
	"commerce",
	"shipping",
]
const CARD_TYPES := ["factory", "market"]
const ORIGIN_STARTER := "starter_bootstrap"
const ORIGIN_STANDARD := "standard"
const STARTER_COST_PROFILE := "starter_zero_asset"
const STARTER_BADGE_ASSET_KEY := "card.badge.starter"
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
	"starter_badge_asset_key",
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
		"starter_definition_count": starter_definition_ids().size(),
		"standard_definition_count": standard_definition_ids().size(),
		"starter_creation_phase": "genesis_only",
		"starter_creation_allowed_after_genesis": false,
		"starter_track_spawn_allowed": false,
		"starter_standard_l1_merge_allowed": true,
		"starter_zero_cost_privilege_inherited": false,
		"rng_stream_ids": [],
		"production_runtime_connection_count": 0,
	}


static func starter_definition_ids() -> Array[String]:
	var result: Array[String] = []
	for color_id in COLORS:
		for card_type in CARD_TYPES:
			result.append(starter_definition_id(str(card_type), str(color_id)))
	return result


static func standard_l1_definition_ids() -> Array[String]:
	var result: Array[String] = []
	for color_id in COLORS:
		for card_type in CARD_TYPES:
			result.append(standard_definition_id(str(card_type), str(color_id), 1))
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
	if card_type not in CARD_TYPES or color_id not in COLORS:
		return ""
	return "starter.facility.%s.%s.rank_1" % [card_type, color_id]


static func standard_definition_id(
	card_type: String,
	color_id: String,
	level: int
) -> String:
	if card_type not in CARD_TYPES or color_id not in COLORS \
			or level < MIN_LEVEL or level > MAX_LEVEL:
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
	var cost_profile := STARTER_COST_PROFILE if starter \
		else "standard_rank_%d" % level
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
		"starter_badge_asset_key": STARTER_BADGE_ASSET_KEY if starter else "",
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


static func track_spawn_definition_ids() -> Array[String]:
	return standard_l1_definition_ids()


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
	if parts.size() == 5 and str(parts[0]) == "starter" \
			and str(parts[1]) == "facility" \
			and str(parts[2]) in CARD_TYPES \
			and str(parts[3]) in COLORS \
			and str(parts[4]) == "rank_1":
		return {
			"origin_class": ORIGIN_STARTER,
			"card_type": str(parts[2]),
			"primary_color": str(parts[3]),
			"level": 1,
		}
	if parts.size() == 4 and str(parts[0]) == "facility" \
			and str(parts[1]) in CARD_TYPES \
			and str(parts[2]) in COLORS \
			and str(parts[3]).begins_with("rank_"):
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
