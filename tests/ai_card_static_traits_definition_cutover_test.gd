extends SceneTree

const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")
const MONSTER_CATALOG := preload("res://scripts/runtime/monster_catalog_v06.gd")

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
	var monster := coordinator.get_node_or_null(
		"MonsterRuntimeController"
	) as MonsterRuntimeController
	var rng := coordinator.get_node_or_null("RunRngService") as RunRngService
	_expect(
		session != null and world != null and ai != null
			and eligibility != null and definitions != null
			and monster != null and rng != null,
		"production composition injects existing eligibility, definition, and monster owners"
	)
	if session == null or world == null or ai == null \
			or eligibility == null or definitions == null \
			or monster == null or rng == null:
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
	_expect(
		bool(definitions.debug_snapshot().get("monster_definition_source_bound", false)),
		"definition bridge binds the existing Monster owner as its typed public source"
	)
	for catalog_index in range(MONSTER_CATALOG.catalog_size()):
		var entry := MONSTER_CATALOG.catalog_entry(catalog_index)
		var monster_name := str(entry.get("name", ""))
		var actions := MONSTER_CATALOG.catalog_actions(catalog_index)
		for rank in range(1, 5):
			var monster_card_id := MONSTER_CATALOG.monster_card_name(catalog_index, rank)
			var monster_definition := definitions.resolve_definition(monster_card_id)
			var expected_hp := int(round(float(entry.get("hp", 40)) * (1.0 + float(rank - 1) * 0.22)))
			var expected_move := float(entry.get(
				"move",
				MonsterRuntimeController.MONSTER_RAMPAGE_MOVE_METERS
			)) * (1.0 + float(rank - 1) * 0.10)
			var expected_duration := float(entry.get(
				"duration",
				MonsterRuntimeController.MONSTER_CARD_DURATION_BASE_SECONDS
					+ float(rank - 1)
						* MonsterRuntimeController.MONSTER_CARD_DURATION_RANK_STEP_SECONDS
			))
			var terrain_multiplier: Dictionary = entry.get("terrain_move_multiplier", {})
			var ocean_multiplier := float(terrain_multiplier.get("ocean", 1.0))
			var land_multiplier := float(terrain_multiplier.get("land", 1.0))
			if absf(ocean_multiplier - 1.0) > 0.01 \
					or absf(land_multiplier - 1.0) > 0.01:
				_expect(
					str(monster_definition.get("text", "")).contains(
						"海×%.2f/陆×%.2f" % [ocean_multiplier, land_multiplier]
					),
					"typed Monster owner preserves %s mobility text" % monster_name
				)
			_expect(
				str(monster_definition.get("kind", "")) == "monster_card"
					and str(monster_definition.get("monster_name", "")) == monster_name
					and int(monster_definition.get("catalog_index", -1)) == catalog_index
					and int(monster_definition.get("rank", 0)) == rank
					and int(monster_definition.get("cost", 0)) == 5 + rank
					and int(monster_definition.get("hp", 0)) == expected_hp
					and is_equal_approx(float(monster_definition.get("move", 0.0)), expected_move)
					and is_equal_approx(
						float(monster_definition.get("duration", 0.0)),
						expected_duration
					)
					and int(monster_definition.get("fixed_skill_count", 0)) == rank
					and int(monster_definition.get("play_cash_per_monster", 0))
						== MonsterRuntimeController.MONSTER_CARD_PLAY_CASH_PER_EXISTING,
				"typed Monster owner preserves %s rank %d definition fields" % [
					monster_name,
					rank,
				]
			)
			for action_index in range(actions.size()):
				var technique_id := MONSTER_CATALOG.monster_technique_card_name(
					monster_name,
					action_index,
					rank
				)
				var technique := definitions.resolve_definition(technique_id)
				var expected_action: Dictionary = (
					actions[action_index] as Dictionary
				).duplicate(true)
				if expected_action.has("damage"):
					expected_action["damage"] = maxi(
						1,
						int(round(
							float(expected_action.get("damage", 1))
								* (1.0 + float(rank - 1) * 0.20)
						))
					)
				if expected_action.has("move_override") \
						and float(expected_action.get("move_override", -1.0)) > 0.0:
					expected_action["move_override"] = float(
						expected_action.get("move_override", 0.0)
					) * (1.0 + float(rank - 1) * 0.08)
				_expect(
					str(technique.get("kind", "")) == "monster_bound_action"
						and str(technique.get("monster_name", "")) == monster_name
						and int(technique.get("catalog_index", -1)) == catalog_index
						and int(technique.get("action_index", -1)) == action_index
						and int(technique.get("rank", 0)) == rank
						and int(technique.get("cost", 0)) == 2 + rank
						and bool(technique.get("persistent", false))
						and technique.get("action", {}) == expected_action,
					"typed Monster owner preserves %s action %d rank %d definition" % [
						monster_name,
						action_index,
						rank,
					]
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
	var definition_bridge_source := FileAccess.get_file_as_string(
		"res://scripts/runtime/card_runtime_definition_world_bridge.gd"
	)
	for forbidden in [
		"var _world",
		"func bind_world(",
		".has_method(",
		".call(",
		"\"_is_monster_card_name\"",
		"\"_monster_card_definition\"",
		"\"_is_monster_technique_card_name\"",
		"\"_monster_technique_definition\"",
	]:
		_expect(
			not definition_bridge_source.contains(forbidden),
			"definition bridge cannot regain Main/dynamic route %s" % forbidden
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
