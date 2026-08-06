extends Node

const Core := preload(
	"res://scripts/v075/monster/v075_monster_source_core.gd"
)
const CapacityPort := preload(
	"res://scripts/v075/monster/v075_character_monster_capacity_port.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_capacity_and_modes()
	_test_refresh_upgrade_replace_and_checkpoint()
	var evidence := {
		"checks": _checks,
		"failure_count": _failures.size(),
		"base_capacity": (
			Core.BASE_MONSTER_CONTROL_CAPACITY_PER_PLAYER
		),
		"card_modes": Core.CARD_MODES,
		"refresh_percent_by_rank": (
			Core.contract_snapshot().get(
				"refresh_percent_by_rank",
				{}
			)
		),
		"mode_auto_conversion_count": int(
			Core.contract_snapshot().get(
				"monster_card_mode_auto_conversion_count",
				-1
			)
		),
		"capacity_drop_forced_kill_count": int(
			Core.contract_snapshot().get(
				"capacity_drop_forced_kill_count",
				-1
			)
		),
		"checkpoint_pure_data": bool(
			Core.contract_snapshot().get(
				"checkpoint_pure_data",
				false
			)
		),
	}
	print(
		"V075_MONSTER_SOURCE_CORE_BENCH|%s|%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			JSON.stringify(evidence),
		]
	)
	for failure in _failures:
		push_error("V075_MONSTER_SOURCE_CORE_BENCH|FAIL|%s" % failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _test_capacity_and_modes() -> void:
	var life := _definition("ember", "life")
	var energy := _definition("volt", "energy")
	var state := Core.new_state(["player.alpha"])
	_expect(not state.is_empty(), "new source state is valid")
	_expect(
		Core.capacity_for_player(state, "player.alpha") == 1,
		"base capacity is exactly one"
	)
	var first := _resolve(
		state,
		_request(
			"deploy.first",
			"card.ember.first",
			1,
			Core.MODE_DEPLOY_NEW,
			"region.a"
		),
		life
	)
	_expect(first.get("accepted") == true, "first deploy resolves")
	state = first.get("state", {}) as Dictionary
	var first_receipt := first.get("receipt", {}) as Dictionary
	var first_source_id := str(
		first_receipt.get("source_instance_id", "")
	)
	_expect(
		Core.controlled_source_count(state, "player.alpha") == 1,
		"first deploy creates one controlled source"
	)
	var blocked := Core.prebind_card_mode(
		state,
		_request(
			"deploy.blocked",
			"card.volt.blocked",
			1,
			Core.MODE_DEPLOY_NEW,
			"region.b"
		),
		energy
	)
	_expect(
		blocked.get("reason_code")
		== "monster_control_capacity_reached",
		"second deploy is rejected at base capacity"
	)
	var increase := CapacityPort.build_semantic(
		"player.alpha",
		1,
		2
	)
	var capacity_update := Core.apply_character_capacity_semantic(
		state,
		"capacity.raise",
		increase
	)
	_expect(
		capacity_update.get("accepted") == true
		and capacity_update.get("effective_capacity") == 2
		and capacity_update.get("forced_kill_count") == 0,
		"typed character modifier raises capacity without kills"
	)
	state = capacity_update.get("state", {}) as Dictionary
	var second := _resolve(
		state,
		_request(
			"deploy.second",
			"card.volt.second",
			1,
			Core.MODE_DEPLOY_NEW,
			"region.b"
		),
		energy
	)
	_expect(second.get("accepted") == true, "expanded capacity permits deploy")
	state = second.get("state", {}) as Dictionary
	var lower := CapacityPort.build_semantic(
		"player.alpha",
		0,
		3
	)
	var lowered := Core.apply_character_capacity_semantic(
		state,
		"capacity.lower",
		lower
	)
	state = lowered.get("state", {}) as Dictionary
	_expect(
		lowered.get("accepted") == true
		and lowered.get("over_capacity_count") == 1
		and lowered.get("forced_kill_count") == 0
		and lowered.get("source_state_mutation_count") == 0
		and Core.controlled_source_count(
			state,
			"player.alpha"
		) == 2,
		"capacity drop blocks future deploys and never kills"
	)
	_expect(
		Core.source_snapshot(state, first_source_id).get("status")
		== "active",
		"capacity drop leaves existing source active"
	)


func _test_refresh_upgrade_replace_and_checkpoint() -> void:
	var life := _definition("ember", "life")
	var energy := _definition("volt", "energy")
	var downed := Core.build_source_snapshot(
		life,
		"monster.fixture.downed",
		"player.alpha",
		"region.a",
		4,
		0,
		"downed",
		1,
		"card.fixture.downed"
	)
	var refresh_state := Core.new_state(
		["player.alpha"],
		{},
		[downed]
	)
	var refreshed := _resolve(
		refresh_state,
		_request(
			"refresh.rank2",
			"card.ember.refresh2",
			2,
			Core.MODE_REFRESH_EXISTING,
			"",
			"monster.fixture.downed"
		),
		life
	)
	var refreshed_receipt := (
		refreshed.get("receipt", {}) as Dictionary
	)
	var refreshed_source := Core.source_snapshot(
		refreshed.get("state", {}) as Dictionary,
		"monster.fixture.downed"
	)
	_expect(
		refreshed_receipt.get("refresh_percent") == 50
		and refreshed_receipt.get("healing_amount_applied") == 200
		and refreshed_source.get("hp") == 200
		and refreshed_source.get("status") == "active",
		"rank-II refresh heals fifty percent and revives downed source"
	)
	var cooldown_override := {
		"skill.ember.1": {
			"status": Core.SKILL_COOLDOWN,
			"cooldown_batches_remaining": 3,
			"skill_generation": 7,
			"resume_status": Core.SKILL_COOLDOWN,
		},
	}
	var rank_one := Core.build_source_snapshot(
		life,
		"monster.fixture.upgrade",
		"player.alpha",
		"region.a",
		1,
		50,
		"active",
		1,
		"card.fixture.upgrade",
		cooldown_override
	)
	var upgrade_state := Core.new_state(
		["player.alpha"],
		{},
		[rank_one]
	)
	var upgraded := _resolve(
		upgrade_state,
		_request(
			"upgrade.rank3",
			"card.ember.upgrade3",
			3,
			Core.MODE_UPGRADE_EXISTING,
			"",
			"monster.fixture.upgrade"
		),
		life
	)
	var upgrade_receipt := upgraded.get("receipt", {}) as Dictionary
	var upgraded_source := Core.source_snapshot(
		upgraded.get("state", {}) as Dictionary,
		"monster.fixture.upgrade"
	)
	var upgraded_skills := (
		upgraded_source.get("skill_states", {}) as Dictionary
	)
	_expect(
		upgraded_source.get("rank") == 3
		and upgraded_source.get("hp") == 300
		and upgraded_source.get("max_hp") == 300
		and upgrade_receipt.get("upgrade_full_heal") == true,
		"upgrade jumps to bound rank and fully heals new max HP"
	)
	_expect(
		(upgraded_skills.get(
			"skill.ember.1",
			{}
		) as Dictionary).get("cooldown_batches_remaining") == 3
		and (upgraded_skills.get(
			"skill.ember.2",
			{}
		) as Dictionary).get("status") == Core.SKILL_READY
		and (upgraded_skills.get(
			"skill.ember.3",
			{}
		) as Dictionary).get("status") == Core.SKILL_READY
		and upgrade_receipt.get("upgrade_cooldown_reset_count") == 0,
		"upgrade preserves old cooldown and readies new skills"
	)
	var replace_source := Core.build_source_snapshot(
		life,
		"monster.fixture.replace",
		"player.alpha",
		"region.a",
		1,
		-1,
		"active",
		1,
		"card.fixture.replace"
	)
	var replace_state := Core.new_state(
		["player.alpha"],
		{},
		[replace_source]
	)
	var checkpoint := Core.capture_checkpoint(
		replace_state,
		"checkpoint.before.replace"
	)
	var replaced := _resolve(
		replace_state,
		_request(
			"replace.volt",
			"card.volt.replace",
			2,
			Core.MODE_REPLACE_EXISTING,
			"region.c",
			"monster.fixture.replace"
		),
		energy
	)
	var replace_receipt := replaced.get("receipt", {}) as Dictionary
	var replaced_state := replaced.get("state", {}) as Dictionary
	var old_source := Core.source_snapshot(
		replaced_state,
		"monster.fixture.replace"
	)
	var new_source := Core.source_snapshot(
		replaced_state,
		str(replace_receipt.get("source_instance_id", ""))
	)
	_expect(
		old_source.get("status") == "withdrawn"
		and old_source.get("kill_reward_count") == 0
		and replace_receipt.get("replace_kill_reward_count") == 0
		and replace_receipt.get("withdrawn_counts_as_kill") == false
		and new_source.get("monster_family_id") == "volt",
		"replace withdraws old family and deploys clean new source"
	)
	var rollback := Core.rollback_to_checkpoint(
		replaced_state,
		checkpoint
	)
	_expect(
		rollback.get("accepted") == true
		and (rollback.get("state", {}) as Dictionary).get(
			"state_fingerprint"
		) == replace_state.get("state_fingerprint")
		and rollback.get("in_place_mutation_count") == 0,
		"pure checkpoint restores exact pre-replace state"
	)


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
	request_suffix: String,
	card_instance_id: String,
	rank: int,
	mode: String,
	region_id: String,
	target_source_id: String = ""
) -> Dictionary:
	return {
		"request_id": "request.%s" % request_suffix,
		"card_instance_id": card_instance_id,
		"card_definition_id": "definition.%s.rank.%d" % [
			card_instance_id,
			rank,
		],
		"owner_player_id": "player.alpha",
		"card_rank": rank,
		"monster_card_mode": mode,
		"target_region_id": region_id,
		"target_source_instance_id": target_source_id,
	}


func _definition(family_id: String, color_id: String) -> Dictionary:
	return {
		"source_definition_id": "monster.%s.source" % family_id,
		"monster_family_id": family_id,
		"preferred_industry_color": color_id,
		"facility_type_preference": [
			"factory",
			"market",
			"warehouse",
		],
		"base_detection_range_hops": 2,
		"movement_profile": "ground_trample",
		"movement_budget_milli_arc_by_rank": [
			1000,
			1200,
			1400,
			1600,
		],
		"max_hp_by_rank": [100, 200, 300, 400],
		"armor_by_rank": [0, 1, 2, 3],
		"active_skill_definition_ids": [
			"skill.%s.1" % family_id,
			"skill.%s.2" % family_id,
			"skill.%s.3" % family_id,
			"skill.%s.4" % family_id,
		],
	}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
