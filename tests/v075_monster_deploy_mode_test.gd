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
	var semantics := {
		"player.alpha": Port.build_semantic("player.alpha", 1),
	}
	var state := Core.new_state(["player.alpha"], semantics)
	var fingerprint_before := str(state.get("state_fingerprint", ""))
	var request := {
		"request_id": "request.deploy.rank2",
		"card_instance_id": "card.alpha.rank2",
		"card_definition_id": "definition.alpha.rank2",
		"owner_player_id": "player.alpha",
		"card_rank": 2,
		"monster_card_mode": Core.MODE_DEPLOY_NEW,
		"target_region_id": "region.deploy",
		"target_source_instance_id": "",
	}
	var bound := Core.prebind_card_mode(
		state,
		request,
		_definition()
	)
	var action := bound.get("action", {}) as Dictionary
	_expect(
		bound.get("accepted") == true
		and bound.get("state_mutation_count") == 0
		and bound.get("mode_auto_conversion_count") == 0
		and action.get("prebound") == true
		and action.get("monster_card_mode") == Core.MODE_DEPLOY_NEW
		and action.get("mode_auto_conversion_allowed") == false
		and state.get("state_fingerprint") == fingerprint_before,
		"deploy mode is explicitly prebound without state mutation"
	)
	var raw_rejected := Core.resolve_prebound_card(state, request)
	_expect(
		raw_rejected.get("accepted") == false,
		"unbound request cannot resolve"
	)
	var result := Core.resolve_prebound_card(state, action)
	var receipt := result.get("receipt", {}) as Dictionary
	state = result.get("state", {}) as Dictionary
	var source := Core.source_snapshot(
		state,
		str(receipt.get("source_instance_id", ""))
	)
	var skills := source.get("skill_states", {}) as Dictionary
	_expect(
		result.get("accepted") == true
		and source.get("rank") == 2
		and source.get("hp") == 200
		and source.get("max_hp") == 200
		and source.get("region_id") == "region.deploy"
		and source.get("monster_family_id") == "alpha"
		and source.get("created_from_card_instance_id")
		== "card.alpha.rank2",
		"deploy creates the bound family, rank, HP, and region"
	)
	_expect(
		(source.get("unlocked_skill_definition_ids", []) as Array).size()
		== 2
		and (skills.get("skill.alpha.1", {}) as Dictionary).get(
			"status"
		) == Core.SKILL_READY
		and (skills.get("skill.alpha.2", {}) as Dictionary).get(
			"status"
		) == Core.SKILL_READY
		and (skills.get("skill.alpha.3", {}) as Dictionary).get(
			"status"
		) == Core.SKILL_LOCKED,
		"deployed rank unlocks exactly rank-count active skills"
	)
	_expect(
		receipt.get("card_destination") == "personal_discard"
		and receipt.get("mode_auto_converted") == false
		and receipt.get("mode_auto_conversion_count") == 0,
		"deploy receipt routes card to discard without conversion"
	)
	var replay := Core.resolve_prebound_card(state, action)
	_expect(
		replay.get("accepted") == true
		and replay.get("idempotent_replay") == true
		and (replay.get("state", {}) as Dictionary).get(
			"state_fingerprint"
		) == state.get("state_fingerprint")
		and Core.controlled_source_count(state, "player.alpha") == 1,
		"same prebound deploy is exact-once"
	)
	var same_family := request.duplicate(true)
	same_family["request_id"] = "request.deploy.same.family"
	same_family["card_instance_id"] = "card.alpha.second"
	same_family["card_definition_id"] = "definition.alpha.second"
	var same_family_bound := Core.prebind_card_mode(
		state,
		same_family,
		_definition()
	)
	_expect(
		same_family_bound.get("reason_code")
		== "monster_deploy_same_family_exists",
		"spare capacity does not permit duplicate controlled family"
	)
	var forged_target := same_family.duplicate(true)
	forged_target["request_id"] = "request.deploy.forged.target"
	forged_target["card_instance_id"] = "card.beta.forged"
	forged_target["card_definition_id"] = "definition.beta.forged"
	forged_target["target_source_instance_id"] = str(
		receipt.get("source_instance_id", "")
	)
	_expect(
		Core.prebind_card_mode(
			state,
			forged_target,
			_definition("beta", "energy")
		).get("reason_code")
		== "monster_deploy_target_source_forbidden",
		"deploy cannot smuggle an existing-source target"
	)
	_finish()


func _definition(
	family_id: String = "alpha",
	color_id: String = "life"
) -> Dictionary:
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


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	for failure in _failures:
		push_error("V075_MONSTER_DEPLOY_MODE_TEST|FAIL|%s" % failure)
	print(
		"V075_MONSTER_DEPLOY_MODE_TEST|%s|checks=%d|failures=%d"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks,
			_failures.size(),
		]
	)
	quit(0 if _failures.is_empty() else 1)
