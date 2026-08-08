extends SceneTree

const Core := preload(
	"res://scripts/v075/monster/v075_monster_source_core.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var definition := {
		"source_definition_id": "monster.self.effect.source",
		"monster_family_id": "self_effect",
		"preferred_industry_color": "life",
		"facility_type_preference": ["factory", "market", "warehouse"],
		"base_detection_range_hops": 1,
		"movement_profile": "ground_trample",
		"movement_budget_milli_arc_by_rank": [100, 120, 140, 160],
		"max_hp_by_rank": [50, 70, 90, 110],
		"armor_by_rank": [1, 2, 3, 4],
		"active_skill_definition_ids": [
			"skill.self.1",
			"skill.self.2",
			"skill.self.3",
			"skill.self.4",
		],
	}
	var source := Core.build_source_snapshot(
		definition,
		"monster.self.001",
		"player.alpha",
		"region.000",
		1,
		20
	)
	var state := Core.new_state(["player.alpha"], {}, [source])
	var healed := Core.commit_private_skill_self_heal(
		state,
		"operation.skill.self.heal.001",
		"monster.self.001",
		1,
		15
	)
	_expect(bool(healed.get("accepted", false)), "self heal commits")
	state = healed.get("state", {}) as Dictionary
	var healed_source := Core.source_snapshot(state, "monster.self.001")
	_expect(
		int(healed_source.get("hp", 0)) == 35
		and int(healed_source.get("damage_revision", 0)) == 1,
		"self heal changes HP through sealed source transition"
	)
	var replay := Core.commit_private_skill_self_heal(
		state,
		"operation.skill.self.heal.001",
		"monster.self.001",
		1,
		15
	)
	_expect(
		bool(replay.get("accepted", false))
		and bool(replay.get("idempotent_replay", false))
		and replay.get("state") == state,
		"self heal replays exact once"
	)
	var armored := Core.commit_private_skill_armor_gain(
		state,
		"operation.skill.self.armor.001",
		"monster.self.001",
		1,
		4
	)
	_expect(bool(armored.get("accepted", false)), "armor gain commits")
	state = armored.get("state", {}) as Dictionary
	var armored_source := Core.source_snapshot(state, "monster.self.001")
	_expect(
		int(armored_source.get("armor", 0)) == 5
		and int(armored_source.get("damage_revision", 0)) == 2,
		"armor gain changes armor through sealed source transition"
	)
	_expect(
		bool(Core.validation_report(state).get("valid", false)),
		"self-effect transition journal remains valid"
	)
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print("V075_MONSTER_PRIVATE_SKILL_SELF_EFFECT_TEST|%s|%d/%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks - _failures.size(),
		_checks,
	])
	quit(0 if _failures.is_empty() else 1)
