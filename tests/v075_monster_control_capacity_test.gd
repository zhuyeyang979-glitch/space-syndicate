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
	var state := Core.new_state(["player.alpha"])
	_expect(
		Core.capacity_for_player(state, "player.alpha") == 1,
		"base control capacity is exactly one"
	)
	var first := _resolve(
		state,
		_request(
			"deploy.alpha",
			"card.alpha.one",
			Core.MODE_DEPLOY_NEW,
			"region.a"
		),
		_definition("alpha", "life")
	)
	_expect(first.get("accepted") == true, "first monster deploys")
	state = first.get("state", {}) as Dictionary
	var first_source_id := str(
		(first.get("receipt", {}) as Dictionary).get(
			"source_instance_id",
			""
		)
	)
	var blocked := Core.prebind_card_mode(
		state,
		_request(
			"deploy.beta.blocked",
			"card.beta.blocked",
			Core.MODE_DEPLOY_NEW,
			"region.b"
		),
		_definition("beta", "energy")
	)
	_expect(
		blocked.get("reason_code")
		== "monster_control_capacity_reached",
		"base capacity rejects a second active monster"
	)
	var raised := Core.apply_character_capacity_semantic(
		state,
		"capacity.raise",
		Port.build_semantic("player.alpha", 1, 2)
	)
	_expect(
		raised.get("accepted") == true
		and raised.get("effective_capacity") == 2
		and raised.get("forced_kill_count") == 0,
		"typed character modifier raises capacity to two"
	)
	state = raised.get("state", {}) as Dictionary
	var second := _resolve(
		state,
		_request(
			"deploy.beta",
			"card.beta.one",
			Core.MODE_DEPLOY_NEW,
			"region.b"
		),
		_definition("beta", "energy")
	)
	_expect(second.get("accepted") == true, "raised capacity permits second family")
	state = second.get("state", {}) as Dictionary
	var sources_before := (
		state.get("sources", {}) as Dictionary
	).duplicate(true)
	var lowered := Core.apply_character_capacity_semantic(
		state,
		"capacity.lower",
		Port.build_semantic("player.alpha", 0, 3)
	)
	state = lowered.get("state", {}) as Dictionary
	_expect(
		lowered.get("accepted") == true
		and lowered.get("over_capacity_count") == 1
		and lowered.get("deployment_blocked") == true
		and lowered.get("forced_kill_count") == 0
		and lowered.get("source_state_mutation_count") == 0,
		"capacity drop reports over-capacity without forced kill"
	)
	_expect(
		state.get("sources") == sources_before
		and Core.controlled_source_count(state, "player.alpha") == 2
		and Core.source_snapshot(
			state,
			first_source_id
		).get("status") == "active",
		"all existing monsters survive capacity drop unchanged"
	)
	var future_blocked := Core.prebind_card_mode(
		state,
		_request(
			"deploy.gamma.blocked",
			"card.gamma.blocked",
			Core.MODE_DEPLOY_NEW,
			"region.c"
		),
		_definition("gamma", "industry")
	)
	_expect(
		future_blocked.get("reason_code")
		== "monster_control_capacity_reached",
		"over-capacity player cannot deploy again"
	)
	var stale := Core.apply_character_capacity_semantic(
		state,
		"capacity.stale",
		Port.build_semantic("player.alpha", 2, 2)
	)
	_expect(
		stale.get("accepted") == false
		and stale.get("reason_code")
		== "character_capacity_revision_stale",
		"stale character semantic cannot overwrite capacity"
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
	mode: String,
	region_id: String
) -> Dictionary:
	return {
		"request_id": "request.%s" % suffix,
		"card_instance_id": card_id,
		"card_definition_id": "definition.%s" % suffix,
		"owner_player_id": "player.alpha",
		"card_rank": 1,
		"monster_card_mode": mode,
		"target_region_id": region_id,
		"target_source_instance_id": "",
	}


func _definition(family_id: String, color_id: String) -> Dictionary:
	return {
		"source_definition_id": "monster.%s.source" % family_id,
		"monster_family_id": family_id,
		"preferred_industry_color": color_id,
		"facility_type_preference": ["factory", "market", "warehouse"],
		"base_detection_range_hops": 1,
		"movement_profile": "ground_trample",
		"movement_budget_milli_arc_by_rank": [1000, 1100, 1200, 1300],
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


func _finish() -> void:
	for failure in _failures:
		push_error("V075_MONSTER_CONTROL_CAPACITY_TEST|FAIL|%s" % failure)
	print(
		"V075_MONSTER_CONTROL_CAPACITY_TEST|%s|checks=%d|failures=%d"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks,
			_failures.size(),
		]
	)
	quit(0 if _failures.is_empty() else 1)
