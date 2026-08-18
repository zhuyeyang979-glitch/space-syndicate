extends SceneTree

const Core := preload(
	"res://scripts/v075/monster/v075_monster_source_core.gd"
)
const Port := preload(
	"res://scripts/v075/monster/v075_character_monster_capacity_port.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var alpha := _definition("alpha", "life")
	var beta := _definition("beta", "energy")
	var old_source := Core.build_source_snapshot(
		alpha,
		"monster.alpha.replace",
		"player.alpha",
		"region.a",
		3,
		170,
		"active",
		2,
		"card.origin.alpha"
	)
	var state := Core.new_state(
		["player.alpha"],
		{},
		[old_source]
	)
	var request := _request(
		"replace.beta",
		"card.beta.rank2",
		2,
		"region.c",
		"monster.alpha.replace"
	)
	var bound := Core.prebind_card_mode(state, request, beta)
	_expect(
		bound.get("accepted") == true
		and (bound.get("action", {}) as Dictionary).get(
			"monster_card_mode"
		) == Core.MODE_REPLACE_EXISTING
		and (bound.get("action", {}) as Dictionary).get(
			"target_source_instance_id"
		) == "monster.alpha.replace"
		and bound.get("mode_auto_conversion_count") == 0,
		"replace prebinds old source and deployment region"
	)
	var result := Core.resolve_prebound_card(
		state,
		bound.get("action", {}) as Dictionary
	)
	var receipt := result.get("receipt", {}) as Dictionary
	state = result.get("state", {}) as Dictionary
	var withdrawn := Core.source_snapshot(
		state,
		"monster.alpha.replace"
	)
	var replacement := Core.source_snapshot(
		state,
		str(receipt.get("source_instance_id", ""))
	)
	_expect(
		withdrawn.get("status") == "withdrawn"
		and withdrawn.get("withdrawal_reason") == "replaced"
		and withdrawn.get("kill_reward_count") == 0
		and _all_revoked(
			withdrawn.get("skill_states", {}) as Dictionary
		),
		"old source is withdrawn with every skill revoked"
	)
	_expect(
		replacement.get("monster_family_id") == "beta"
		and replacement.get("region_id") == "region.c"
		and replacement.get("rank") == 2
		and replacement.get("hp") == 200
		and replacement.get("source_instance_id")
		!= withdrawn.get("source_instance_id")
		and Core.controlled_source_count(state, "player.alpha") == 1,
		"replacement is a clean new source with no inherited state"
	)
	_expect(
		receipt.get("replace_kill_reward_count") == 0
		and receipt.get("withdrawn_counts_as_kill") == false
		and receipt.get("card_destination") == "personal_discard",
		"replacement produces no kill reward and discards its card"
	)
	var expanded_state := Core.new_state(
		["player.alpha"],
		{
			"player.alpha": Port.build_semantic(
				"player.alpha",
				1
			),
		},
		[old_source]
	)
	_expect(
		Core.prebind_card_mode(
			expanded_state,
			_request(
				"replace.below.capacity",
				"card.beta.below.capacity",
				1,
				"region.c",
				"monster.alpha.replace"
			),
			beta
		).get("reason_code")
		== "monster_replace_capacity_not_reached",
		"replace is illegal while below effective capacity"
	)
	_expect(
		Core.prebind_card_mode(
			Core.new_state(["player.alpha"], {}, [old_source]),
			_request(
				"replace.same.family",
				"card.alpha.same.family",
				1,
				"region.c",
				"monster.alpha.replace"
			),
			alpha
		).get("reason_code")
		== "monster_replace_same_family_forbidden",
		"same family cannot bind as replace"
	)
	var no_target := _request(
		"replace.no.target",
		"card.beta.no.target",
		1,
		"region.c",
		""
	)
	_expect(
		Core.prebind_card_mode(
			Core.new_state(["player.alpha"], {}, [old_source]),
			no_target,
			beta
		).get("reason_code")
		== "monster_target_source_missing",
		"replace requires explicit old source identity"
	)
	_finish()


func _request(
	suffix: String,
	card_id: String,
	rank: int,
	region_id: String,
	target_source_id: String
) -> Dictionary:
	return {
		"request_id": "request.%s" % suffix,
		"card_instance_id": card_id,
		"card_definition_id": "definition.%s" % suffix,
		"owner_player_id": "player.alpha",
		"card_rank": rank,
		"monster_card_mode": Core.MODE_REPLACE_EXISTING,
		"target_region_id": region_id,
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


func _all_revoked(skill_states: Dictionary) -> bool:
	for skill_variant in skill_states.values():
		if (
			str((skill_variant as Dictionary).get("status", ""))
			!= Core.SKILL_REVOKED
		):
			return false
	return skill_states.size() == 4


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	for failure in _failures:
		push_error("V075_MONSTER_REPLACE_MODE_TEST|FAIL|%s" % failure)
	print(
		"V075_MONSTER_REPLACE_MODE_TEST|%s|checks=%d|failures=%d"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks,
			_failures.size(),
		]
	)
	quit(0 if _failures.is_empty() else 1)
