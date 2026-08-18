extends SceneTree

const Core := preload(
	"res://scripts/v075/monster/v075_monster_source_core.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var definition := _definition("alpha", "life")
	var source := Core.build_source_snapshot(
		definition,
		"monster.alpha.upgrade",
		"player.alpha",
		"region.a",
		1,
		20,
		"active",
		4,
		"card.origin.alpha"
	)
	var state := Core.new_state(
		["player.alpha"],
		{},
		[source]
	)
	var request := _request(
		"upgrade.rank4",
		"card.alpha.rank4",
		4,
		"monster.alpha.upgrade"
	)
	var bound := Core.prebind_card_mode(state, request, definition)
	_expect(
		bound.get("accepted") == true
		and (bound.get("action", {}) as Dictionary).get(
			"monster_card_mode"
		) == Core.MODE_UPGRADE_EXISTING
		and bound.get("mode_auto_conversion_count") == 0,
		"upgrade mode is explicitly prebound"
	)
	var result := Core.resolve_prebound_card(
		state,
		bound.get("action", {}) as Dictionary
	)
	var receipt := result.get("receipt", {}) as Dictionary
	var upgraded := Core.source_snapshot(
		result.get("state", {}) as Dictionary,
		"monster.alpha.upgrade"
	)
	var skills := upgraded.get("skill_states", {}) as Dictionary
	_expect(
		result.get("accepted") == true
		and upgraded.get("source_instance_id") == "monster.alpha.upgrade"
		and upgraded.get("source_generation") == 4
		and upgraded.get("rank") == 4
		and upgraded.get("hp") == 400
		and upgraded.get("max_hp") == 400
		and upgraded.get("armor") == 3,
		"upgrade preserves source identity and reaches authored rank profile"
	)
	_expect(
		(upgraded.get(
			"unlocked_skill_definition_ids",
			[]
		) as Array).size() == 4
		and _ready_count(skills) == 4
		and receipt.get("new_skill_ready_count") == 3,
		"rank IV unlocks exactly four active skills"
	)
	_expect(
		receipt.get("old_rank") == 1
		and receipt.get("new_rank") == 4
		and receipt.get("upgrade_full_heal") == true
		and receipt.get("upgrade_cooldown_reset_count") == 0
		and receipt.get("card_destination") == "personal_discard",
		"upgrade fully heals and never resets cooldown"
	)
	var nonhigher := _request(
		"upgrade.nonhigher",
		"card.alpha.rank1.second",
		1,
		"monster.alpha.upgrade"
	)
	_expect(
		Core.prebind_card_mode(
			state,
			nonhigher,
			definition
		).get("reason_code")
		== "monster_upgrade_rank_not_higher",
		"same-rank card cannot bind as upgrade"
	)
	var mismatch := _request(
		"upgrade.mismatch",
		"card.beta.rank4",
		4,
		"monster.alpha.upgrade"
	)
	var mismatch_bound := Core.prebind_card_mode(
		state,
		mismatch,
		_definition("beta", "energy")
	)
	_expect(
		mismatch_bound.get("reason_code")
		== "monster_target_family_mismatch"
		and mismatch_bound.get("mode_auto_conversion_count") == 0,
		"different family cannot auto-convert upgrade into replace"
	)
	var downed := Core.build_source_snapshot(
		definition,
		"monster.alpha.downed.upgrade",
		"player.alpha",
		"region.a",
		1,
		0,
		"downed",
		1,
		"card.origin.downed.upgrade"
	)
	var downed_state := Core.new_state(
		["player.alpha"],
		{},
		[downed]
	)
	var downed_request := _request(
		"upgrade.downed.rank2",
		"card.alpha.downed.rank2",
		2,
		"monster.alpha.downed.upgrade"
	)
	var downed_bound := Core.prebind_card_mode(
		downed_state,
		downed_request,
		definition
	)
	var downed_result := Core.resolve_prebound_card(
		downed_state,
		downed_bound.get("action", {}) as Dictionary
	)
	var downed_upgraded := Core.source_snapshot(
		downed_result.get("state", {}) as Dictionary,
		"monster.alpha.downed.upgrade"
	)
	var downed_skills := (
		downed_upgraded.get("skill_states", {}) as Dictionary
	)
	_expect(
		downed_result.get("accepted") == true
		and downed_upgraded.get("status") == "active"
		and downed_upgraded.get("hp") == 200
		and (downed_skills.get(
			"skill.alpha.1",
			{}
		) as Dictionary).get("status") == Core.SKILL_READY
		and (downed_skills.get(
			"skill.alpha.2",
			{}
		) as Dictionary).get("status") == Core.SKILL_READY,
		"downed upgrade restores prior skill state and fully revives"
	)
	_finish()


func _request(
	suffix: String,
	card_id: String,
	rank: int,
	target_source_id: String
) -> Dictionary:
	return {
		"request_id": "request.%s" % suffix,
		"card_instance_id": card_id,
		"card_definition_id": "definition.%s" % suffix,
		"owner_player_id": "player.alpha",
		"card_rank": rank,
		"monster_card_mode": Core.MODE_UPGRADE_EXISTING,
		"target_region_id": "",
		"target_source_instance_id": target_source_id,
	}


func _definition(family_id: String, color_id: String) -> Dictionary:
	return {
		"source_definition_id": "monster.%s.source" % family_id,
		"monster_family_id": family_id,
		"preferred_industry_color": color_id,
		"facility_type_preference": ["factory", "market", "warehouse"],
		"base_detection_range_hops": 2,
		"movement_profile": "ground_trample",
		"movement_budget_milli_arc_by_rank": [1000, 1200, 1400, 1600],
		"max_hp_by_rank": [100, 200, 300, 400],
		"armor_by_rank": [0, 1, 2, 3],
		"active_skill_definition_ids": [
			"skill.%s.1" % family_id,
			"skill.%s.2" % family_id,
			"skill.%s.3" % family_id,
			"skill.%s.4" % family_id,
		],
	}


func _ready_count(skill_states: Dictionary) -> int:
	var count := 0
	for skill_variant in skill_states.values():
		if (
			str((skill_variant as Dictionary).get("status", ""))
			== Core.SKILL_READY
		):
			count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	for failure in _failures:
		push_error("V075_MONSTER_UPGRADE_MODE_TEST|FAIL|%s" % failure)
	print(
		"V075_MONSTER_UPGRADE_MODE_TEST|%s|checks=%d|failures=%d"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks,
			_failures.size(),
		]
	)
	quit(0 if _failures.is_empty() else 1)
