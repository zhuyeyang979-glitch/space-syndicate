extends RefCounted
class_name V075CombatCatalog

const MonsterSourceCore := preload(
	"res://scripts/v075/monster/v075_monster_source_core.gd"
)
const MonsterSkillCore := preload(
	"res://scripts/v075/monster/v075_monster_private_skill_core.gd"
)
const CapabilityCatalog := preload(
	"res://scripts/v075/combat/v075_combat_capability_catalog.gd"
)

const CATALOG_PATH := "res://data/v075/v075_combat_active_catalog.json"
const BALANCE_PATH := "res://docs/rules/v075_combat_balance_defaults.json"
const RULESET_ID := "v0.7.5"
const CONSTITUTION_ID := "space_syndicate.v075.complete"
const ACTIVE_MONSTER_FAMILY_COUNT := 6
const ACTIVE_MONSTER_SKILL_DEFINITION_COUNT := 24
const ACTIVE_MILITARY_DEFINITION_COUNT := 3
const COLORS := [
	"life",
	"energy",
	"industry",
	"technology",
	"commerce",
	"shipping",
]

static var _catalog_cache: Dictionary = {}
static var _balance_cache: Dictionary = {}


static func catalog() -> Dictionary:
	if _catalog_cache.is_empty():
		_catalog_cache = _load_json(CATALOG_PATH)
	return _catalog_cache.duplicate(true)


static func balance_defaults() -> Dictionary:
	if _balance_cache.is_empty():
		_balance_cache = _load_json(BALANCE_PATH)
	return _balance_cache.duplicate(true)


static func validation_report() -> Dictionary:
	var errors: Array[String] = []
	var catalog_data := catalog()
	var balance := balance_defaults()
	if catalog_data.is_empty():
		errors.append("active_catalog_missing")
	if balance.is_empty():
		errors.append("combat_balance_defaults_missing")
	var capability_report := CapabilityCatalog.validation_report()
	if not bool(capability_report.get("valid", false)):
		errors.append("combat_capability_catalog_invalid")
	var duplicate_capability_definition_count := 0
	var closed_world := catalog_data.get("closed_world_contract", {}) as Dictionary
	for field_name in [
		"allowed_monster_card_modes",
		"allowed_military_task_kinds",
	]:
		if closed_world.has(field_name):
			duplicate_capability_definition_count += 1
	if str(catalog_data.get("ruleset_id", "")) != RULESET_ID:
		errors.append("active_catalog_ruleset_invalid")
	if str(balance.get("ruleset_id", "")) != RULESET_ID:
		errors.append("combat_balance_ruleset_invalid")
	if str(catalog_data.get("constitution_id", "")) != CONSTITUTION_ID:
		errors.append("active_catalog_constitution_invalid")
	if str(balance.get("constitution_id", "")) != CONSTITUTION_ID:
		errors.append("combat_balance_constitution_invalid")

	var families := catalog_data.get("monster_families", []) as Array
	var military := catalog_data.get("military_definitions", []) as Array
	if families.size() != ACTIVE_MONSTER_FAMILY_COUNT:
		errors.append("active_monster_family_count_invalid")
	if military.size() != ACTIVE_MILITARY_DEFINITION_COUNT:
		errors.append("active_military_definition_count_invalid")

	var family_ids: Array[String] = []
	var preferred_colors: Array[String] = []
	var skill_ids: Array[String] = []
	var ultimate_count := 0
	for family_variant in families:
		if not (family_variant is Dictionary):
			errors.append("monster_family_not_dictionary")
			continue
		var family := family_variant as Dictionary
		if family.has("card_modes"):
			duplicate_capability_definition_count += 1
		var family_id := str(family.get("monster_family_id", ""))
		var preferred_color := str(
			family.get("preferred_industry_color", "")
		)
		if not _stable_id(family_id) or family_ids.has(family_id):
			errors.append("monster_family_identity_invalid")
		else:
			family_ids.append(family_id)
		if preferred_color not in COLORS:
			errors.append("monster_preferred_color_invalid")
		elif preferred_colors.has(preferred_color):
			errors.append("monster_preferred_color_duplicate")
		else:
			preferred_colors.append(preferred_color)
		var skills := family.get("skill_definitions", []) as Array
		if skills.size() != 4:
			errors.append("monster_family_skill_count_invalid")
		for skill_variant in skills:
			if not (skill_variant is Dictionary):
				errors.append("monster_skill_not_dictionary")
				continue
			var skill := skill_variant as Dictionary
			var skill_id := str(skill.get("skill_definition_id", ""))
			if not _stable_id(skill_id) or skill_ids.has(skill_id):
				errors.append("monster_skill_identity_invalid")
			else:
				skill_ids.append(skill_id)
			if bool(skill.get("ultimate", false)):
				ultimate_count += 1
	if preferred_colors.size() != COLORS.size():
		errors.append("preferred_color_coverage_invalid")
	if skill_ids.size() != ACTIVE_MONSTER_SKILL_DEFINITION_COUNT:
		errors.append("active_skill_definition_count_invalid")
	if ultimate_count != ACTIVE_MONSTER_FAMILY_COUNT:
		errors.append("monster_ultimate_count_invalid")

	var source_definitions := monster_source_definitions()
	if source_definitions.size() != ACTIVE_MONSTER_FAMILY_COUNT:
		errors.append("monster_source_definition_coverage_invalid")
	for definition_variant in source_definitions:
		if MonsterSourceCore.normalize_definition(
			definition_variant as Dictionary
		).is_empty():
			errors.append("monster_source_definition_invalid")

	var skill_definitions := monster_skill_definitions()
	if skill_definitions.size() != ACTIVE_MONSTER_SKILL_DEFINITION_COUNT:
		errors.append("monster_skill_authoring_coverage_invalid")
	for definition_variant in skill_definitions:
		if (definition_variant as Dictionary).is_empty():
			errors.append("monster_private_skill_definition_invalid")

	var military_ids: Array[String] = []
	for definition_variant in military:
		if not (definition_variant is Dictionary):
			errors.append("military_definition_not_dictionary")
			continue
		var definition := definition_variant as Dictionary
		var definition_id := str(
			definition.get("military_definition_id", "")
		)
		if not _stable_id(definition_id) or military_ids.has(definition_id):
			errors.append("military_definition_identity_invalid")
		else:
			military_ids.append(definition_id)
		if definition.has("mission_kinds"):
			duplicate_capability_definition_count += 1
		if (
			bool(definition.get("persistent_source", true))
			or int(definition.get("bound_action_count", -1)) != 0
			or int(definition.get("guard_task_count", -1)) != 0
		):
			errors.append("military_forbidden_capability_present")
	if duplicate_capability_definition_count != 0:
		errors.append("combat_capability_duplicate_definition_present")
	return {
		"valid": errors.is_empty(),
		"error_count": errors.size(),
		"errors": errors,
		"reason_code": (
			"v075_combat_catalog_valid"
			if errors.is_empty()
			else errors[0]
		),
		"active_monster_family_count": family_ids.size(),
		"active_monster_skill_definition_count": skill_ids.size(),
		"active_monster_preferred_color_coverage": preferred_colors.size(),
		"active_military_definition_count": military_ids.size(),
		"monster_l4_ultimate_count": ultimate_count,
		"capability_catalog_owner_count": 1,
		"capability_duplicate_definition_count": (
			duplicate_capability_definition_count
		),
	}


static func monster_family_ids() -> Array[String]:
	var result: Array[String] = []
	for family_variant in catalog().get("monster_families", []) as Array:
		var family_id := str(
			(family_variant as Dictionary).get("monster_family_id", "")
		)
		if not family_id.is_empty():
			result.append(family_id)
	return result


static func monster_family(family_id: String) -> Dictionary:
	for family_variant in catalog().get("monster_families", []) as Array:
		var family := family_variant as Dictionary
		if str(family.get("monster_family_id", "")) == family_id:
			var result := family.duplicate(true)
			result["card_modes"] = CapabilityCatalog.monster_card_modes()
			return result
	return {}


static func monster_source_definitions() -> Array:
	var result: Array = []
	for family_id in monster_family_ids():
		var definition := monster_source_definition(family_id)
		if not definition.is_empty():
			result.append(definition)
	return result


static func monster_source_definition(family_id: String) -> Dictionary:
	var family := monster_family(family_id)
	var ranks := _profile_rows(
		"monster_family_rank_profiles",
		family_id
	)
	if family.is_empty() or ranks.size() != 4:
		return {}
	var movement_budgets: Array[int] = []
	var max_hp: Array[int] = []
	var armor: Array[int] = []
	for rank_variant in ranks:
		var rank := rank_variant as Dictionary
		movement_budgets.append(
			int(rank.get("movement_budget_milli_arc", 0))
		)
		max_hp.append(int(rank.get("max_hp", 0)))
		armor.append(int(rank.get("armor", 0)))
	var skill_ids: Array[String] = []
	for skill_variant in family.get("skill_definitions", []) as Array:
		skill_ids.append(str(
			(skill_variant as Dictionary).get("skill_definition_id", "")
		))
	return {
		"source_definition_id": str(
			family.get("source_card_family_id", "")
		),
		"monster_family_id": family_id,
		"preferred_industry_color": str(
			family.get("preferred_industry_color", "")
		),
		"facility_type_preference": (
			family.get("facility_type_preference", []) as Array
		).duplicate(),
		"base_detection_range_hops": int(
			(ranks[0] as Dictionary).get(
				"base_detection_range_hops",
				0
			)
		),
		"movement_profile": str(family.get("movement_profile", "")),
		"movement_budget_milli_arc_by_rank": movement_budgets,
		"max_hp_by_rank": max_hp,
		"armor_by_rank": armor,
		"active_skill_definition_ids": skill_ids,
	}


static func monster_skill_definitions() -> Array:
	var result: Array = []
	for family_id in monster_family_ids():
		var family := monster_family(family_id)
		for skill_variant in family.get("skill_definitions", []) as Array:
			var authored := skill_variant as Dictionary
			var skill_id := str(
				authored.get("skill_definition_id", "")
			)
			var profile := monster_skill_profile(skill_id)
			if profile.is_empty():
				continue
			result.append(MonsterSkillCore.build_skill_definition(
				skill_id,
				str(authored.get("public_effect_id", "")),
				int(authored.get("required_rank", 0)),
				bool(authored.get("ultimate", false)),
				_integer_color_map(
					profile.get("asset_cost_by_color", {})
				),
				_normalize_json_data(
					authored.get("target_contract", {})
				) as Dictionary,
				{
					"metric": str(
						(authored.get(
							"range_contract",
							{}
						) as Dictionary).get("metric", "")
					),
					"maximum_hops": int(
						profile.get("maximum_range_hops", 0)
					),
				},
				int(profile.get("cooldown_batches", 0)),
				str(authored.get("public_presentation_key", "")),
				bool(profile.get("cooldown_on_fizzle", false))
			))
	return result


static func monster_skill_definition(skill_id: String) -> Dictionary:
	for definition_variant in monster_skill_definitions():
		var definition := definition_variant as Dictionary
		if str(definition.get("skill_definition_id", "")) == skill_id:
			return definition.duplicate(true)
	return {}


static func monster_skill_profile(skill_id: String) -> Dictionary:
	var profiles := balance_defaults().get(
		"monster_skill_profiles",
		{}
	) as Dictionary
	return (
		(profiles.get(skill_id, {}) as Dictionary).duplicate(true)
		if profiles.has(skill_id)
		else {}
	)


static func monster_rank_profile(
	family_id: String,
	rank: int
) -> Dictionary:
	var rows := _profile_rows("monster_family_rank_profiles", family_id)
	if rank < 1 or rank > rows.size():
		return {}
	return (rows[rank - 1] as Dictionary).duplicate(true)


static func monster_basic_attack_damage(
	family_id: String,
	rank: int
) -> int:
	return int(monster_rank_profile(family_id, rank).get(
		"basic_attack_damage",
		0
	))


static func military_definition_ids() -> Array[String]:
	var result: Array[String] = []
	for definition_variant in (
		catalog().get("military_definitions", []) as Array
	):
		var definition_id := str(
			(definition_variant as Dictionary).get(
				"military_definition_id",
				""
			)
		)
		if not definition_id.is_empty():
			result.append(definition_id)
	return result


static func military_definition(definition_id: String) -> Dictionary:
	for definition_variant in (
		catalog().get("military_definitions", []) as Array
	):
		var definition := definition_variant as Dictionary
		if str(definition.get(
			"military_definition_id",
			""
		)) == definition_id:
			var result := definition.duplicate(true)
			result["mission_kinds"] = CapabilityCatalog.military_mission_kinds()
			return result
	return {}


static func military_rank_profile(
	definition_id: String,
	rank: int
) -> Dictionary:
	var rows := _profile_rows(
		"military_definition_rank_profiles",
		definition_id
	)
	if rank < 1 or rank > rows.size():
		return {}
	return (rows[rank - 1] as Dictionary).duplicate(true)


static func trample_balance() -> Dictionary:
	var source := balance_defaults().get("trample_defaults", {}) as Dictionary
	var damage_source := source.get(
		"trample_damage_per_step_by_rank",
		{}
	) as Dictionary
	var cap_source := source.get(
		"trample_damage_cap_per_region_by_rank",
		{}
	) as Dictionary
	var damage_by_rank := {}
	var cap_by_rank := {}
	for rank in range(1, 5):
		var rank_key := str(rank)
		damage_by_rank[rank_key] = int(damage_source.get(rank_key, 0))
		cap_by_rank[rank_key] = int(cap_source.get(rank_key, 0))
	return {
		"trample_distance_step_milli_arc": int(source.get(
			"trample_distance_step_milli_arc",
			0
		)),
		"trample_damage_per_step_by_rank": damage_by_rank,
		"trample_damage_cap_per_region_by_rank": cap_by_rank,
		"positive_distance_minimum_step_count": int(source.get(
			"positive_distance_minimum_step_count",
			0
		)),
		"default_forced_movement_trample": bool(source.get(
			"default_forced_movement_trample",
			false
		)),
	}


static func monster_family_id_from_card_type(card_type: String) -> String:
	if not card_type.begins_with("monster."):
		return ""
	var family_id := card_type.trim_prefix("monster.")
	return family_id if family_id in monster_family_ids() else ""


static func military_definition_id_from_card_type(card_type: String) -> String:
	if not card_type.begins_with("military."):
		return ""
	var definition_id := card_type.trim_prefix("military.")
	return (
		definition_id
		if definition_id in military_definition_ids()
		else ""
	)


static func _profile_rows(
	profile_key: String,
	identity: String
) -> Array:
	var profiles := balance_defaults().get(profile_key, {}) as Dictionary
	if not profiles.has(identity):
		return []
	return (profiles.get(identity, []) as Array).duplicate(true)


static func _normalize_json_data(value: Variant) -> Variant:
	if value is float:
		var number := float(value)
		return int(number) if number == floor(number) else number
	if value is Array:
		var rows: Array = []
		for item_variant in value as Array:
			rows.append(_normalize_json_data(item_variant))
		return rows
	if value is Dictionary:
		var result := {}
		for key_variant in (value as Dictionary).keys():
			result[str(key_variant)] = _normalize_json_data(
				(value as Dictionary).get(key_variant)
			)
		return result
	return value


static func _integer_color_map(value: Variant) -> Dictionary:
	var source := value as Dictionary if value is Dictionary else {}
	var result := {}
	for color in COLORS:
		result[color] = int(source.get(color, 0))
	return result


static func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	return (
		(parsed as Dictionary).duplicate(true)
		if parsed is Dictionary
		else {}
	)


static func _stable_id(value: Variant) -> bool:
	if not (value is String or value is StringName):
		return false
	var text := str(value)
	if text.is_empty() or text.length() > 160:
		return false
	return text.strip_edges() == text and not text.contains(" ")