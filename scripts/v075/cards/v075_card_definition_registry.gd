extends RefCounted
class_name V075CardDefinitionRegistry

const V074Definitions := preload(
	"res://scripts/v074/facility/v074_card_definition_registry.gd"
)

const SCHEMA_VERSION := 1
const REGISTRY_ID := "space_syndicate.v075.card_definition_registry.v1"
const RULESET_ID := "v0.7.5"
const BALANCE_PROFILE_ID := "V075_COMBAT_CANDIDATE_DEFAULTS"
const BALANCE_PROFILE_FINGERPRINT := (
	"26aa0f83b24f96b0c5ff2e78dbd6ee523a53afe9e2cc3f63bd4b2d9c1ec981f5"
)
const PROFILE_FINGERPRINT_INPUT := (
	"V075_COMBAT_CANDIDATE_DEFAULTS|facility_normal_share=7000|"
	+ "monster_normal_share=1500|military_normal_share=1500|"
	+ "outer_normal_commodity=6000,4000|monster_family_count=6|"
	+ "military_definition_count=3|"
	+ "combat_card_primary_cost_by_rank=2,3,4,5"
)

const COLORS := [
	"life",
	"energy",
	"industry",
	"technology",
	"commerce",
	"shipping",
]
const FACILITY_CARD_TYPES := ["factory", "market", "warehouse"]
const MONSTER_FAMILY_IDS := [
	"spore_tide_emperor",
	"meteor_sentinel",
	"sand_armor_rover",
	"blue_edge_knight",
	"prism_blade_colossus",
	"mirror_hunter",
]
const MILITARY_DEFINITION_IDS := [
	"planetary_defense_force",
	"air_superiority_fighter",
	"submarine_fleet",
]
const STARTER_CARD_TYPES := ["factory", "market"]
const CARD_TYPES := [
	"factory",
	"market",
	"warehouse",
	"monster.spore_tide_emperor",
	"monster.meteor_sentinel",
	"monster.sand_armor_rover",
	"monster.blue_edge_knight",
	"monster.prism_blade_colossus",
	"monster.mirror_hunter",
	"military.planetary_defense_force",
	"military.air_superiority_fighter",
	"military.submarine_fleet",
]

const ORIGIN_STARTER := "starter_bootstrap"
const ORIGIN_STANDARD := "standard"
const STARTER_COST_PROFILE := "starter_zero_asset"
const MIN_LEVEL := 1
const MAX_LEVEL := 4

const FACILITY_NORMAL_WEIGHT_BPS := 7000
const MONSTER_NORMAL_WEIGHT_BPS := 1500
const MILITARY_NORMAL_WEIGHT_BPS := 1500
const TRACK_TEMPLATE_WEIGHT_UNIT_COUNT := 240
const FACILITY_TRACK_TEMPLATE_COUNT := 168
const MONSTER_TRACK_TEMPLATE_COUNT := 36
const MILITARY_TRACK_TEMPLATE_COUNT := 36

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
	var templates := track_spawn_definition_ids()
	return {
		"schema_version": SCHEMA_VERSION,
		"registry_id": REGISTRY_ID,
		"ruleset_id": RULESET_ID,
		"balance_profile_id": BALANCE_PROFILE_ID,
		"balance_profile_fingerprint": BALANCE_PROFILE_FINGERPRINT,
		"starter_definition_ids": starter_definition_ids(),
		"standard_l1_definition_ids": standard_l1_definition_ids(),
		"normal_track_supply_definition_ids": templates,
		"starter_definition_count": starter_definition_ids().size(),
		"standard_l1_definition_count": standard_l1_definition_ids().size(),
		"active_monster_family_count": MONSTER_FAMILY_IDS.size(),
		"active_military_definition_count": MILITARY_DEFINITION_IDS.size(),
		"normal_subtype_weights_basis_points": {
			"facility": FACILITY_NORMAL_WEIGHT_BPS,
			"monster": MONSTER_NORMAL_WEIGHT_BPS,
			"military": MILITARY_NORMAL_WEIGHT_BPS,
		},
		"track_template_weight_unit_count": templates.size(),
		"facility_track_template_count": FACILITY_TRACK_TEMPLATE_COUNT,
		"monster_track_template_count": MONSTER_TRACK_TEMPLATE_COUNT,
		"military_track_template_count": MILITARY_TRACK_TEMPLATE_COUNT,
		"starter_creation_phase": "genesis_only",
		"starter_creation_allowed_after_genesis": false,
		"starter_track_spawn_allowed": false,
		"starter_standard_l1_merge_allowed": true,
		"starter_zero_cost_privilege_inherited": false,
		"monster_and_military_card_kind": "normal_card",
		"outer_normal_card_ratio_basis_points": 6000,
		"outer_commodity_card_ratio_basis_points": 4000,
		"rng_stream_ids": [],
		"production_runtime_connection_count": 0,
	}


static func starter_definition_ids() -> Array[String]:
	return V074Definitions.starter_definition_ids()


static func starter_definitions() -> Array:
	return V074Definitions.starter_definitions()


static func standard_l1_definition_ids() -> Array[String]:
	var result: Array[String] = []
	for color_id in COLORS:
		for card_type in CARD_TYPES:
			result.append(standard_definition_id(card_type, color_id, 1))
	return result


static func standard_l1_definitions() -> Array:
	var result: Array = []
	for definition_id in standard_l1_definition_ids():
		result.append(definition(definition_id))
	return result


static func standard_definition_ids() -> Array[String]:
	var result: Array[String] = []
	for level in range(MIN_LEVEL, MAX_LEVEL + 1):
		for color_id in COLORS:
			for card_type in CARD_TYPES:
				result.append(standard_definition_id(card_type, color_id, level))
	return result


static func all_definition_ids() -> Array[String]:
	var result := starter_definition_ids()
	result.append_array(standard_definition_ids())
	return result


static func normal_track_supply_definition_ids() -> Array[String]:
	var result: Array[String] = []
	for _cycle in range(9):
		for color_id in COLORS:
			for card_type in FACILITY_CARD_TYPES:
				result.append(standard_definition_id(card_type, color_id, 1))
	for color_id in COLORS:
		result.append(standard_definition_id("factory", color_id, 1))
	for color_id in COLORS:
		for family_id in MONSTER_FAMILY_IDS:
			result.append(standard_definition_id(
				"monster.%s" % family_id,
				color_id,
				1
			))
	for _cycle in range(2):
		for color_id in COLORS:
			for definition_id in MILITARY_DEFINITION_IDS:
				result.append(standard_definition_id(
					"military.%s" % definition_id,
					color_id,
					1
				))
	return result


static func track_spawn_definition_ids() -> Array[String]:
	return normal_track_supply_definition_ids()


static func starter_definition_id(card_type: String, color_id: String) -> String:
	return V074Definitions.starter_definition_id(card_type, color_id)


static func standard_definition_id(
	card_type: String,
	color_id: String,
	level: int
) -> String:
	if color_id not in COLORS or level < MIN_LEVEL or level > MAX_LEVEL:
		return ""
	if card_type in FACILITY_CARD_TYPES:
		return "facility.%s.%s.rank_%d" % [card_type, color_id, level]
	if card_type.begins_with("monster."):
		var family_id := card_type.trim_prefix("monster.")
		if family_id in MONSTER_FAMILY_IDS:
			return "monster.%s.%s.rank_%d" % [family_id, color_id, level]
	if card_type.begins_with("military."):
		var definition_id := card_type.trim_prefix("military.")
		if definition_id in MILITARY_DEFINITION_IDS:
			return "military.%s.%s.rank_%d" % [
				definition_id,
				color_id,
				level,
			]
	return ""


static func merge_family_id(card_type: String, color_id: String) -> String:
	if card_type not in CARD_TYPES or color_id not in COLORS:
		return ""
	if card_type in FACILITY_CARD_TYPES:
		return "facility.%s.%s" % [card_type, color_id]
	if card_type.begins_with("monster."):
		# Monster reinforcement is keyed by family and rank. The per-instance
		# primary color remains the independent track cost authority.
		return "unit.%s" % card_type
	return "unit.%s.%s" % [card_type, color_id]


static func definition(definition_id: String) -> Dictionary:
	var parsed := _parse_definition_id(definition_id)
	if parsed.is_empty():
		return {}
	var origin_class := str(parsed.get("origin_class", ""))
	var card_type := str(parsed.get("card_type", ""))
	var color_id := str(parsed.get("primary_color", ""))
	var level := int(parsed.get("level", 0))
	var starter := origin_class == ORIGIN_STARTER
	var domain := card_domain(card_type)
	var primary_cost := 0
	var cost_profile := STARTER_COST_PROFILE
	if not starter:
		primary_cost = level if domain == "facility" else level + 1
		cost_profile = (
			"standard_rank_%d" % level
			if domain == "facility"
			else "v075_%s_track_color_rank_%d" % [domain, level]
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
	if (
		card_domain(str(left.get("card_type", ""))) != "facility"
		or card_domain(str(right.get("card_type", ""))) != "facility"
	):
		return _merge_result(false, "starter_combat_merge_forbidden")
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


static func card_domain(card_type: String) -> String:
	if card_type in FACILITY_CARD_TYPES:
		return "facility"
	if (
		card_type.begins_with("monster.")
		and card_type.trim_prefix("monster.") in MONSTER_FAMILY_IDS
	):
		return "monster"
	if (
		card_type.begins_with("military.")
		and card_type.trim_prefix("military.") in MILITARY_DEFINITION_IDS
	):
		return "military"
	return ""


static func monster_family_id_from_card_type(card_type: String) -> String:
	if card_domain(card_type) != "monster":
		return ""
	return card_type.trim_prefix("monster.")


static func military_definition_id_from_card_type(card_type: String) -> String:
	if card_domain(card_type) != "military":
		return ""
	return card_type.trim_prefix("military.")


static func is_starter_definition(definition_id: String) -> bool:
	return str(definition(definition_id).get("origin_class", "")) == ORIGIN_STARTER


static func commodity_definition_ids() -> Array[String]:
	return []


static func commodity_definitions() -> Array:
	return []


static func commodity_definition(_definition_id: String) -> Dictionary:
	return {}


static func warehouse_standard_l1_definition_ids() -> Array[String]:
	var result: Array[String] = []
	for color_id in COLORS:
		result.append(standard_definition_id("warehouse", color_id, 1))
	return result


static func warehouse_standard_l1_definitions() -> Array:
	var result: Array = []
	for definition_id in warehouse_standard_l1_definition_ids():
		result.append(definition(definition_id))
	return result


static func _parse_definition_id(definition_id: String) -> Dictionary:
	var starter := V074Definitions.definition(definition_id)
	if (
		not starter.is_empty()
		and str(starter.get("origin_class", "")) == ORIGIN_STARTER
	):
		return {
			"origin_class": ORIGIN_STARTER,
			"card_type": str(starter.get("card_type", "")),
			"primary_color": str(starter.get("primary_color", "")),
			"level": int(starter.get("level", 0)),
		}
	var parts := definition_id.split(".")
	if parts.size() != 4 or str(parts[3]).begins_with("rank_") == false:
		return {}
	var level_text := str(parts[3]).trim_prefix("rank_")
	if not level_text.is_valid_int():
		return {}
	var level := int(level_text)
	if level < MIN_LEVEL or level > MAX_LEVEL:
		return {}
	var prefix := str(parts[0])
	var identity := str(parts[1])
	var color_id := str(parts[2])
	if color_id not in COLORS:
		return {}
	var card_type := ""
	if prefix == "facility" and identity in FACILITY_CARD_TYPES:
		card_type = identity
	elif prefix == "monster" and identity in MONSTER_FAMILY_IDS:
		card_type = "monster.%s" % identity
	elif prefix == "military" and identity in MILITARY_DEFINITION_IDS:
		card_type = "military.%s" % identity
	else:
		return {}
	return {
		"origin_class": ORIGIN_STANDARD,
		"card_type": card_type,
		"primary_color": color_id,
		"level": level,
	}


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
