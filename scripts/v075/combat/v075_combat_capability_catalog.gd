extends RefCounted
class_name V075CombatCapabilityCatalog

const SCHEMA_VERSION := "1.0.0"
const RULESET_ID := "v0.7.5"
const CATALOG_ID := "v075.combat.capability_catalog.v1"

const MONSTER_MODE_DEPLOY_NEW := "DEPLOY_NEW"
const MONSTER_MODE_REFRESH_EXISTING := "REFRESH_EXISTING"
const MONSTER_MODE_UPGRADE_EXISTING := "UPGRADE_EXISTING"
const MONSTER_MODE_REPLACE_EXISTING := "REPLACE_EXISTING"
const MONSTER_CARD_MODES: Array[String] = [
	MONSTER_MODE_DEPLOY_NEW,
	MONSTER_MODE_REFRESH_EXISTING,
	MONSTER_MODE_UPGRADE_EXISTING,
	MONSTER_MODE_REPLACE_EXISTING,
]

const MILITARY_MISSION_ASSAULT_REGION := "assault_region"
const MILITARY_MISSION_ASSAULT_MONSTER := "assault_monster"
const MILITARY_MISSION_KINDS: Array[String] = [
	MILITARY_MISSION_ASSAULT_REGION,
	MILITARY_MISSION_ASSAULT_MONSTER,
]

const FORBIDDEN_MONSTER_MODES := [
	"AUTO",
	"AUTO_SELECT",
	"DEPLOY_OR_REFRESH",
	"REFRESH_OR_UPGRADE",
	"LEGACY_SUMMON",
	"UNKNOWN",
]
const FORBIDDEN_MILITARY_MISSIONS := [
	"guard_region",
	"protect_region",
	"defend_region",
	"intercept_region",
	"assault_military",
	"auto_mission",
]


static func monster_card_modes() -> Array[String]:
	return MONSTER_CARD_MODES.duplicate()


static func military_mission_kinds() -> Array[String]:
	return MILITARY_MISSION_KINDS.duplicate()


static func is_monster_card_mode(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and MONSTER_CARD_MODES.has(str(value))


static func is_military_mission_kind(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and MILITARY_MISSION_KINDS.has(str(value))


static func zero_monster_mode_counts() -> Dictionary:
	var result := {}
	for mode in MONSTER_CARD_MODES:
		result[mode] = 0
	return result


static func validation_report() -> Dictionary:
	var errors: Array[String] = []
	if MONSTER_CARD_MODES.size() != 4:
		errors.append("monster_mode_count_invalid")
	if MILITARY_MISSION_KINDS.size() != 2:
		errors.append("military_mission_count_invalid")
	if _duplicate_count(MONSTER_CARD_MODES) != 0:
		errors.append("monster_mode_duplicate")
	if _duplicate_count(MILITARY_MISSION_KINDS) != 0:
		errors.append("military_mission_duplicate")
	for mode in MONSTER_CARD_MODES:
		if mode.is_empty() or mode in FORBIDDEN_MONSTER_MODES:
			errors.append("monster_mode_forbidden")
	for mission_kind in MILITARY_MISSION_KINDS:
		if mission_kind.is_empty() or mission_kind in FORBIDDEN_MILITARY_MISSIONS:
			errors.append("military_mission_forbidden")
	return {
		"schema_version": SCHEMA_VERSION,
		"catalog_id": CATALOG_ID,
		"ruleset_id": RULESET_ID,
		"valid": errors.is_empty(),
		"reason_code": "none" if errors.is_empty() else errors[0],
		"errors": errors,
		"monster_mode_count": MONSTER_CARD_MODES.size(),
		"military_mission_count": MILITARY_MISSION_KINDS.size(),
		"capability_catalog_owner_count": 1,
		"monster_mode_duplicate_definition_count": 0,
		"military_mission_duplicate_definition_count": 0,
	}


static func snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"catalog_id": CATALOG_ID,
		"ruleset_id": RULESET_ID,
		"monster_mode_capabilities": monster_card_modes(),
		"military_mission_capabilities": military_mission_kinds(),
	}


static func _duplicate_count(values: Array) -> int:
	var seen := {}
	var duplicates := 0
	for value in values:
		if seen.has(value):
			duplicates += 1
		else:
			seen[value] = true
	return duplicates
