extends SceneTree

const Core := preload(
	"res://scripts/v075/monster/v075_monster_source_core.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var source := Core.build_source_snapshot(
		_definition(),
		"monster.alpha.cooldown",
		"player.alpha",
		"region.a",
		1,
		40,
		"active",
		6,
		"card.origin.cooldown",
		{
			"skill.alpha.1": {
				"status": Core.SKILL_COOLDOWN,
				"cooldown_batches_remaining": 3,
				"skill_generation": 9,
				"resume_status": Core.SKILL_COOLDOWN,
			},
		}
	)
	var state := Core.new_state(
		["player.alpha"],
		{},
		[source]
	)
	var rank_three := _resolve(
		state,
		"upgrade.rank3",
		"card.upgrade.rank3",
		3
	)
	var receipt_three := (
		rank_three.get("receipt", {}) as Dictionary
	)
	state = rank_three.get("state", {}) as Dictionary
	var source_three := Core.source_snapshot(
		state,
		"monster.alpha.cooldown"
	)
	var skills_three := (
		source_three.get("skill_states", {}) as Dictionary
	)
	var old_skill := (
		skills_three.get("skill.alpha.1", {}) as Dictionary
	)
	_expect(
		old_skill.get("status") == Core.SKILL_COOLDOWN
		and old_skill.get("cooldown_batches_remaining") == 3
		and old_skill.get("skill_generation") == 9
		and receipt_three.get("upgrade_cooldown_reset_count") == 0
		and receipt_three.get("old_skill_state_preserved_count") == 1,
		"rank-I cooldown and generation survive rank-III upgrade"
	)
	_expect(
		(skills_three.get(
			"skill.alpha.2",
			{}
		) as Dictionary).get("status") == Core.SKILL_READY
		and (skills_three.get(
			"skill.alpha.3",
			{}
		) as Dictionary).get("status") == Core.SKILL_READY
		and (skills_three.get(
			"skill.alpha.4",
			{}
		) as Dictionary).get("status") == Core.SKILL_LOCKED
		and receipt_three.get("new_skill_ready_count") == 2,
		"new rank-II and rank-III skills start READY"
	)
	var rank_four := _resolve(
		state,
		"upgrade.rank4",
		"card.upgrade.rank4",
		4
	)
	var receipt_four := (
		rank_four.get("receipt", {}) as Dictionary
	)
	var source_four := Core.source_snapshot(
		rank_four.get("state", {}) as Dictionary,
		"monster.alpha.cooldown"
	)
	var skills_four := (
		source_four.get("skill_states", {}) as Dictionary
	)
	_expect(
		(skills_four.get(
			"skill.alpha.1",
			{}
		) as Dictionary).get("cooldown_batches_remaining") == 3
		and (skills_four.get(
			"skill.alpha.1",
			{}
		) as Dictionary).get("skill_generation") == 9
		and receipt_four.get("old_skill_state_preserved_count") == 3
		and receipt_four.get("upgrade_cooldown_reset_count") == 0,
		"later rank-IV upgrade still preserves every existing skill state"
	)
	_expect(
		(skills_four.get(
			"skill.alpha.4",
			{}
		) as Dictionary).get("status") == Core.SKILL_READY
		and (skills_four.get(
			"skill.alpha.4",
			{}
		) as Dictionary).get("skill_generation") == 1
		and receipt_four.get("new_skill_ready_count") == 1
		and source_four.get("source_generation") == 6,
		"rank-IV unlock is fresh READY while source identity stays stable"
	)
	_finish()


func _resolve(
	state: Dictionary,
	suffix: String,
	card_id: String,
	card_rank: int
) -> Dictionary:
	var request := {
		"request_id": "request.%s" % suffix,
		"card_instance_id": card_id,
		"card_definition_id": "definition.%s" % suffix,
		"owner_player_id": "player.alpha",
		"card_rank": card_rank,
		"monster_card_mode": Core.MODE_UPGRADE_EXISTING,
		"target_region_id": "",
		"target_source_instance_id": "monster.alpha.cooldown",
	}
	var bound := Core.prebind_card_mode(
		state,
		request,
		_definition()
	)
	if not bool(bound.get("accepted", false)):
		return bound
	return Core.resolve_prebound_card(
		state,
		bound.get("action", {}) as Dictionary
	)


func _definition() -> Dictionary:
	return {
		"source_definition_id": "monster.alpha.source",
		"monster_family_id": "alpha",
		"preferred_industry_color": "life",
		"facility_type_preference": ["factory", "market", "warehouse"],
		"base_detection_range_hops": 2,
		"movement_profile": "ground_trample",
		"movement_budget_milli_arc_by_rank": [1000, 1200, 1400, 1600],
		"max_hp_by_rank": [100, 200, 300, 400],
		"armor_by_rank": [0, 1, 2, 3],
		"active_skill_definition_ids": [
			"skill.alpha.1",
			"skill.alpha.2",
			"skill.alpha.3",
			"skill.alpha.4",
		],
	}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	for failure in _failures:
		push_error(
			"V075_MONSTER_UPGRADE_NO_COOLDOWN_RESET_TEST|FAIL|%s"
			% failure
		)
	print(
		"V075_MONSTER_UPGRADE_NO_COOLDOWN_RESET_TEST|%s|checks=%d|failures=%d"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks,
			_failures.size(),
		]
	)
	quit(0 if _failures.is_empty() else 1)
