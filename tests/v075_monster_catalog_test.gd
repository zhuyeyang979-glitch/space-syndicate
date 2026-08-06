extends SceneTree

const Catalog := preload(
	"res://scripts/v075/combat/v075_combat_catalog.gd"
)
const MonsterSourceCore := preload(
	"res://scripts/v075/monster/v075_monster_source_core.gd"
)
const MonsterSkillCore := preload(
	"res://scripts/v075/monster/v075_monster_private_skill_core.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var report := Catalog.validation_report()
	_expect(bool(report.get("valid", false)), "catalog validates")
	_expect(
		int(report.get("active_monster_family_count", 0)) == 6,
		"six active monster families"
	)
	_expect(
		int(report.get("active_monster_skill_definition_count", 0)) == 24,
		"twenty-four active monster skills"
	)
	_expect(
		int(report.get("active_monster_preferred_color_coverage", 0)) == 6,
		"preferred industry colors cover six of six"
	)
	_expect(
		int(report.get("active_military_definition_count", 0)) == 3,
		"three active military definitions"
	)
	_expect(
		int(report.get("monster_l4_ultimate_count", 0)) == 6,
		"each family has one level-four ultimate"
	)

	var colors: Array[String] = []
	for family_id in Catalog.monster_family_ids():
		var family := Catalog.monster_family(family_id)
		var color := str(family.get("preferred_industry_color", ""))
		if not colors.has(color):
			colors.append(color)
		var definition := Catalog.monster_source_definition(family_id)
		_expect(
			not MonsterSourceCore.normalize_definition(definition).is_empty(),
			"source definition normalizes for %s" % family_id
		)
		_expect(
			(definition.get("active_skill_definition_ids", []) as Array)
			.size() == 4,
			"family has four ordered skills for %s" % family_id
		)
	_expect(colors.size() == 6, "runtime preferred color coverage is unique")

	var skill_ids: Array[String] = []
	for definition_variant in Catalog.monster_skill_definitions():
		var definition := definition_variant as Dictionary
		var skill_id := str(definition.get("skill_definition_id", ""))
		if not skill_ids.has(skill_id):
			skill_ids.append(skill_id)
		_expect(
			bool(definition.get("ultimate", false))
			== (int(definition.get("required_rank", 0)) == 4),
			"ultimate flag matches rank four for %s" % skill_id
		)
	_expect(skill_ids.size() == 24, "all private skill identities are unique")

	for definition_id in Catalog.military_definition_ids():
		var definition := Catalog.military_definition(definition_id)
		_expect(
			definition.get("mission_kinds", []) == [
				"assault_region",
				"assault_monster",
			],
			"military definition exposes exactly two tasks"
		)
		_expect(
			not bool(definition.get("persistent_source", true))
			and int(definition.get("bound_action_count", -1)) == 0
			and int(definition.get("guard_task_count", -1)) == 0,
			"military definition has no persistent, bound, or guard capability"
		)
		for rank in range(1, 5):
			var profile := Catalog.military_rank_profile(
				definition_id,
				rank
			)
			_expect(
				int(profile.get("region_damage_budget", 0)) > 0
				and int(profile.get("monster_damage", 0)) > 0,
				"military rank profile is complete"
			)
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print(
		"V075_MONSTER_CATALOG_TEST|status=%s|passed=%d|total=%d|failures=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks - _failures.size(),
			_checks,
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)