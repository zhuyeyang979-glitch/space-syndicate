extends SceneTree

const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var coordinator := COORDINATOR_SCENE.instantiate() as GameRuntimeCoordinator
	root.add_child(coordinator)
	await process_frame
	coordinator.configure({"ruleset_id": "v0.6"})
	await process_frame
	var session := coordinator.get_node_or_null("GameSessionRuntimeController") as GameSessionRuntimeController
	var world := coordinator.world_session_state()
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController
	var eligibility := coordinator.get_node_or_null(
		"CardPlayEligibilityRuntimeService"
	) as CardPlayEligibilityRuntimeService
	var definitions := coordinator.get_node_or_null(
		"CardRuntimeDefinitionWorldBridge"
	) as CardRuntimeDefinitionWorldBridge
	var rng := coordinator.get_node_or_null("RunRngService") as RunRngService
	_expect(
		session != null and world != null and ai != null
			and eligibility != null and definitions != null and rng != null,
		"production composition injects existing eligibility and definition owners"
	)
	if session == null or world == null or ai == null 			or eligibility == null or definitions == null or rng == null:
		coordinator.queue_free()
		await process_frame
		_finish()
		return
	session.configure({"ruleset_id": "v0.6"}, {})
	session.begin_session({
		"session_id": "ai-card-static-traits",
		"scenario_id": "focused",
		"seed": 173,
		"player_count": 3,
	})
	world.restore({
		"players": [
			_player("Human", false),
			_player("AI-A", true),
			_player("AI-B", true),
		],
		"districts": [],
		"game_time": 7.0,
	}, true)
	var world_before := world.to_save_data()
	var rng_before := rng.capture_plan_checkpoint()
	var samples := [
		{"kind": "attack"},
		{"kind": "player_hand_disrupt"},
		{"kind": "global_barrage"},
		{"kind": "card_counter"},
		{"kind": "cash_gain"},
	]
	for skill_variant in samples:
		var skill := (skill_variant as Dictionary).duplicate(true)
		var expected := eligibility.target_status({"skill": skill}, {})
		_expect(
			bool(ai.call("_skill_targets_monster", skill))
				== bool(expected.get("targets_monster", false))
				and bool(ai.call("_skill_targets_player", skill))
				== bool(expected.get("targets_player", false))
				and bool(ai.call("_is_counter_skill", skill))
				== bool(expected.get("is_counter", false))
				and bool(ai.call("_skill_is_counterable_player_interaction", skill))
				== bool(expected.get("counterable_player_interaction", false)),
			"AI static target traits match the authoritative eligibility service for %s" % str(
				skill.get("kind", "")
			)
		)
	_expect(
		int(ai.call("_skill_play_flow_required", {
			"play_flow_required": 3,
			"legacy_flow_gate_enabled": true,
		}, 1)) == 3
			and int(ai.call("_skill_play_flow_required", {
				"play_flow_required": 3,
				"legacy_flow_gate_enabled": false,
			}, 1)) == 0,
		"legacy flow affinity keeps the retired Main helper semantics"
	)
	_expect(
		is_equal_approx(float(ai.call("_skill_duration_seconds", {
			"contract_seconds": 75.0,
			"contract_turns": 9,
		}, "contract_seconds", "contract_turns", 1)), 75.0)
			and is_equal_approx(float(ai.call("_skill_duration_seconds", {
				"contract_turns": 2,
			}, "contract_seconds", "contract_turns", 1)), 60.0),
		"duration projection preserves explicit seconds and 30-second legacy turns"
	)
	_expect(
		str(ai.call("_canonical_card_supply_name", "轨道齐射3")) == "轨道齐射1"
			and str(ai.call("_canonical_card_supply_name", "MISSING_CARD")) == "",
		"canonical supply identity comes from the typed card definition bridge"
	)
	_expect(
		str(ai.call("_card_display_name", "轨道齐射3")) == "轨道齐射 III级",
		"display identity preserves family and rank formatting"
	)
	var hand := {
		"slots": [
			_card(definitions, "轨道齐射1"),
			_card(definitions, "轨道齐射3"),
			{
				"name": "PERSISTENT_BOUND",
				"kind": "monster_bound_action",
				"persistent": true,
			},
			{
				"name": "LEGACY_NORMAL",
				"kind": "cash_gain",
				"persistent": false,
			},
		],
	}
	_expect(
		int(ai.call("_find_highest_family_card_slot", hand, "轨道齐射2")) == 1,
		"family upgrade lookup keeps highest-rank slot ordering"
	)
	_expect(
		int(ai.call("_player_counted_hand_size", hand)) == 3,
		"legacy persistent bound actions remain exempt from counted hand size"
	)
	_expect(
		world.to_save_data() == world_before
			and rng.capture_plan_checkpoint() == rng_before,
		"static definition queries mutate no world state and consume zero RNG"
	)
	var ai_source := FileAccess.get_file_as_string(
		"res://scripts/runtime/ai_runtime_controller.gd"
	)
	for forbidden in [
		"_call_world(&\"_card_play_target_snapshot\"",
		"_call_world(&\"_skill_play_flow_required\"",
		"_call_world(&\"_skill_duration_seconds\"",
		"_call_world(&\"_canonical_card_supply_name\"",
		"_call_world(&\"_card_display_name\"",
		"_call_world(&\"_find_highest_family_card_slot\"",
		"_call_world(&\"_player_counted_hand_size\"",
	]:
		_expect(
			not ai_source.contains(forbidden),
			"AI source retires generic route %s" % forbidden
		)
	coordinator.queue_free()
	await process_frame
	_finish()


func _player(name: String, is_ai: bool) -> Dictionary:
	return {
		"id": name.hash(),
		"actor_id": "actor:%s" % name,
		"name": name,
		"seat_type": "ai" if is_ai else "human",
		"is_ai": is_ai,
		"cash": 500,
		"cash_cents": 50000,
		"action_cooldown": 0.0,
		"slots": [],
		"ai_profile": {},
		"ai_memory": {},
	}


func _card(definitions: CardRuntimeDefinitionWorldBridge, card_id: String) -> Dictionary:
	var result := definitions.resolve_definition(card_id)
	result["name"] = card_id
	return result


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("AI card static traits and definition cutover passed (%d checks)." % _checks)
		print("AI_CARD_STATIC_TRAITS_DEFINITION_CUTOVER_COMPLETE")
		quit(0)
		return
	push_error(
		"AI card static traits and definition cutover failures:\n- "
			+ "\n- ".join(_failures)
	)
	quit(1)
