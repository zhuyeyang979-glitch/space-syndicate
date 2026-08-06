extends SceneTree

const Core := preload(
	"res://scripts/v075/monster/v075_monster_source_core.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var definition := _definition()
	var damaged := Core.build_source_snapshot(
		definition,
		"monster.alpha.damaged",
		"player.alpha",
		"region.a",
		3,
		100,
		"active",
		1,
		"card.origin.damaged"
	)
	var state := Core.new_state(
		["player.alpha"],
		{},
		[damaged]
	)
	var request := _request(
		"refresh.rank1",
		"card.refresh.rank1",
		1,
		"monster.alpha.damaged"
	)
	var bound := Core.prebind_card_mode(state, request, definition)
	_expect(
		bound.get("accepted") == true
		and (bound.get("action", {}) as Dictionary).get(
			"monster_card_mode"
		) == Core.MODE_REFRESH_EXISTING
		and bound.get("mode_auto_conversion_count") == 0,
		"refresh is explicitly prebound"
	)
	var result := Core.resolve_prebound_card(
		state,
		bound.get("action", {}) as Dictionary
	)
	var receipt := result.get("receipt", {}) as Dictionary
	var refreshed := Core.source_snapshot(
		result.get("state", {}) as Dictionary,
		"monster.alpha.damaged"
	)
	_expect(
		receipt.get("refresh_percent") == 25
		and receipt.get("healing_amount_requested") == 75
		and receipt.get("healing_amount_applied") == 75
		and refreshed.get("hp") == 175
		and refreshed.get("rank") == 3,
		"rank-I duplicate heals 25 percent without rank change"
	)
	var high_rank_refresh := _request(
		"refresh.rank4.invalid",
		"card.refresh.rank4.invalid",
		4,
		"monster.alpha.damaged"
	)
	var high_rank_bound := Core.prebind_card_mode(
		state,
		high_rank_refresh,
		definition
	)
	_expect(
		high_rank_bound.get("accepted") == false
		and high_rank_bound.get("reason_code")
		== "monster_refresh_rank_requires_upgrade"
		and high_rank_bound.get("mode_auto_conversion_count") == 0,
		"higher-rank refresh is rejected rather than auto-upgraded"
	)
	var full := Core.build_source_snapshot(
		definition,
		"monster.alpha.full",
		"player.alpha",
		"region.a",
		3,
		300,
		"active",
		1,
		"card.origin.full"
	)
	var full_state := Core.new_state(
		["player.alpha"],
		{},
		[full]
	)
	_expect(
		Core.prebind_card_mode(
			full_state,
			_request(
				"refresh.full",
				"card.refresh.full",
				1,
				"monster.alpha.full"
			),
			definition
		).get("reason_code")
		== "monster_refresh_full_hp_illegal",
		"full-health source cannot consume a non-upgrade refresh"
	)
	var downed := Core.build_source_snapshot(
		definition,
		"monster.alpha.downed",
		"player.alpha",
		"region.a",
		2,
		0,
		"downed",
		1,
		"card.origin.downed"
	)
	var downed_state := Core.new_state(
		["player.alpha"],
		{},
		[downed]
	)
	var revived_result := _resolve(
		downed_state,
		_request(
			"refresh.revive",
			"card.refresh.revive",
			2,
			"monster.alpha.downed"
		),
		definition
	)
	var revived := Core.source_snapshot(
		revived_result.get("state", {}) as Dictionary,
		"monster.alpha.downed"
	)
	var revived_skills := (
		revived.get("skill_states", {}) as Dictionary
	)
	_expect(
		revived_result.get("accepted") == true
		and revived.get("status") == "active"
		and revived.get("hp") == 100
		and (revived_skills.get(
			"skill.alpha.1",
			{}
		) as Dictionary).get("status") == Core.SKILL_READY
		and (revived_skills.get(
			"skill.alpha.2",
			{}
		) as Dictionary).get("status") == Core.SKILL_READY,
		"downed source revives and restores disabled unlocked skills"
	)
	_finish()


func _resolve(
	state: Dictionary,
	request: Dictionary,
	definition: Dictionary
) -> Dictionary:
	var bound := Core.prebind_card_mode(state, request, definition)
	if not bool(bound.get("accepted", false)):
		return bound
	return Core.resolve_prebound_card(
		state,
		bound.get("action", {}) as Dictionary
	)


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
		"monster_card_mode": Core.MODE_REFRESH_EXISTING,
		"target_region_id": "",
		"target_source_instance_id": target_source_id,
	}


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
		push_error("V075_MONSTER_REFRESH_MODE_TEST|FAIL|%s" % failure)
	print(
		"V075_MONSTER_REFRESH_MODE_TEST|%s|checks=%d|failures=%d"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks,
			_failures.size(),
		]
	)
	quit(0 if _failures.is_empty() else 1)
