extends SceneTree

const Core := preload(
	"res://scripts/v075/monster/v075_monster_source_core.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var state := Core.new_state(["player.alpha"])
	var deploy_bound := Core.prebind_card_mode(
		state,
		_request("deploy", Core.MODE_DEPLOY_NEW, "region.a"),
		_definition()
	)
	var deploy_action := deploy_bound.get("action", {}) as Dictionary
	var deployed := Core.resolve_prebound_card(state, deploy_action)
	state = deployed.get("state", {}) as Dictionary
	var deploy_receipt := deployed.get("receipt", {}) as Dictionary
	var source_id := str(deploy_receipt.get("source_instance_id", ""))
	_expect(
		bool(deploy_bound.get("accepted", false))
		and bool(deployed.get("accepted", false))
		and not source_id.is_empty(),
		"first use deploys the monster"
	)
	var replay := Core.resolve_prebound_card(state, deploy_action)
	_expect(
		bool(replay.get("accepted", false))
		and bool(replay.get("idempotent_replay", false))
		and (replay.get("state", {}) as Dictionary).get(
			"state_fingerprint"
		) == state.get("state_fingerprint"),
		"the same card action remains exact-once"
	)

	var source := Core.source_snapshot(state, source_id)
	var damage := Core.commit_runtime_transition(
		state,
		Core.build_combat_damage_transition_operation(
			"operation.damage.before.reuse",
			source_id,
			int(source.get("source_generation", 0)),
			40
		)
	)
	state = damage.get("state", {}) as Dictionary
	var refresh_bound := Core.prebind_card_mode(
		state,
		_request(
			"refresh.after.reshuffle",
			Core.MODE_REFRESH_EXISTING,
			"",
			source_id
		),
		_definition()
	)
	var refreshed := Core.resolve_prebound_card(
		state,
		refresh_bound.get("action", {}) as Dictionary
	)
	var refreshed_source := Core.source_snapshot(
		refreshed.get("state", {}) as Dictionary,
		source_id
	)
	_expect(
		bool(damage.get("accepted", false))
		and bool(refresh_bound.get("accepted", false))
		and bool(refreshed.get("accepted", false))
		and refreshed_source.get("hp") == 85
		and (refreshed.get("receipt", {}) as Dictionary).get(
			"card_instance_id"
		) == "card.monster.alpha.reusable",
		"a reshuffled card instance can begin a later refresh action"
	)
	_expect(
		(state.get("processed_cards", {}) as Dictionary).size() == 1
		and (
			refreshed.get("state", {}) as Dictionary
		).get("processed_cards", {}).size() == 2,
		"exact-once is journaled per card use instead of permanently per card"
	)
	_finish()


func _request(
	request_suffix: String,
	mode: String,
	region_id: String,
	target_source_id: String = ""
) -> Dictionary:
	return {
		"request_id": "request.%s" % request_suffix,
		"card_instance_id": "card.monster.alpha.reusable",
		"card_definition_id": "definition.monster.alpha.rank1",
		"owner_player_id": "player.alpha",
		"card_rank": 1,
		"monster_card_mode": mode,
		"target_region_id": region_id,
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
		push_error(
			"V075_MONSTER_CARD_REUSE_EXACT_ONCE_TEST|FAIL|%s"
			% failure
		)
	print(
		"V075_MONSTER_CARD_REUSE_EXACT_ONCE_TEST|%s|checks=%d|failures=%d"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks,
			_failures.size(),
		]
	)
	quit(0 if _failures.is_empty() else 1)
