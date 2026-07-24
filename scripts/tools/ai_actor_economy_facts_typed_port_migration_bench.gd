extends Node

const BATTLE_LIFECYCLE_POLICY := preload("res://scripts/runtime/monster_battle_lifecycle_policy_v06.gd")


class AiConsumerWorldProbe:
	extends Node

	func _runtime_session_finished() -> bool:
		return false

	func _player_product_flow(
		_player_index: int,
		_product_name: String
	) -> int:
		return 0

	func _signed_int_text(value: int) -> String:
		return "+%d" % value if value > 0 else str(value)

	func _player_counted_hand_size(player: Dictionary) -> int:
		return (player.get("slots", []) as Array).size()

	func _player_active_city_count(_player_index: int) -> int:
		return 0

	func _card_resolution_current_queue() -> Array:
		return []

	func _card_resolution_next_queue() -> Array:
		return []


var _checks := 0
var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var coordinator := get_node_or_null(
		"GameRuntimeCoordinator"
	) as GameRuntimeCoordinator
	var world := coordinator.world_session_state() if coordinator != null else null
	var session := coordinator.get_node_or_null(
		"GameSessionRuntimeController"
	) as GameSessionRuntimeController if coordinator != null else null
	var catalog := coordinator.get_node_or_null(
		"RoleCatalogRuntimeService"
	) as RoleCatalogRuntimeService if coordinator != null else null
	var market := coordinator.get_node_or_null(
		"ProductMarketRuntimeController"
	) as ProductMarketRuntimeController if coordinator != null else null
	var port := coordinator.get_node_or_null(
		"AiActorEconomyFactsQueryPort"
	) as AiActorEconomyFactsQueryPort if coordinator != null else null
	var cash_query := coordinator.get_node_or_null(
		"MonsterWagerCashCommitmentQueryPort"
	) as MonsterWagerCashCommitmentQueryPort if coordinator != null else null
	var monster := coordinator.get_node_or_null(
		"MonsterRuntimeController"
	) as MonsterRuntimeController if coordinator != null else null
	var monster_bridge := coordinator.get_node_or_null(
		"MonsterRuntimeWorldBridge"
	) as MonsterRuntimeWorldBridge if coordinator != null else null
	var ai := coordinator.get_node_or_null(
		"AiRuntimeController"
	) as AiRuntimeController if coordinator != null else null
	var bridge := coordinator.get_node_or_null(
		"AiRuntimeWorldBridge"
	) as AiRuntimeWorldBridge if coordinator != null else null
	var rng := coordinator.run_rng_service() if coordinator != null else null
	_check(
		coordinator != null
			and world != null
			and session != null
			and catalog != null
			and market != null
			and port != null
			and cash_query != null
			and monster != null
			and monster_bridge != null
			and ai != null
			and bridge != null
			and rng != null,
		"production_dependencies"
	)
	if not _failures.is_empty():
		await _finish({}, {})
		return

	var consumer_world := AiConsumerWorldProbe.new()
	consumer_world.name = "AiConsumerWorldProbe"
	coordinator.add_child(consumer_world)
	bridge.bind_world(consumer_world)
	bridge.set_rng_service(rng)
	bridge.set_world_session_state(world)
	ai.set_world_bridge(bridge)
	monster_bridge.set_world_session_state(world)
	monster.set_world_bridge(monster_bridge)
	ai.set_monster_runtime_controller(monster)
	ai.set_product_market_runtime_controller(market)
	ai.configure({"ruleset_id": "v0.6"})
	session.configure({"ruleset_id": "v0.6"}, {})
	session.begin_session({
		"session_id": "actor-economy-bench",
		"scenario_id": "bench",
		"seed": 271828,
		"player_count": 4,
	})
	world.restore({
		"players": _players(catalog),
		"districts": [],
		"game_time": 5.0,
	}, true)
	_seed_wager(monster)

	var capability := ai.get(
		"_ai_actor_economy_facts_capability"
	) as AiActorEconomyFactsCapability
	var world_before := world.to_save_data()
	var wager_before := JSON.stringify(monster.active_monster_wagers)
	var rng_before := rng.capture_plan_checkpoint()
	var port_debug_before := port.debug_snapshot()
	var cash_debug_before := cash_query.debug_snapshot()
	var decision := port.actor_decision_facts(capability, 1)
	var training := port.actor_training_economy_facts(capability, 1)

	_check(port.is_ready(), "port_ready")
	_check(capability != null, "capability_bound")
	_check(
		capability == coordinator.get("_ai_actor_economy_facts_capability"),
		"single_capability"
	)
	_check(
		int(decision.get("available_cash_cents", -1)) == 80000,
		"wager_adjusted_available_cash"
	)
	_check(
		not bool(decision.get("action_ready", true))
			and is_equal_approx(
				float(decision.get("action_cooldown_seconds", -1.0)),
				1.25
			),
		"cooldown_preserved"
	)
	_check(
		int(training.get("total_cash_cents", -1)) == 100000,
		"training_uses_total_cash"
	)
	_check(
		int(training.get("total_city_income_units", -1)) == 12
			and int(training.get("total_business_spend_units", -1)) == 34,
		"training_counters_preserved"
	)
	var text := JSON.stringify([decision, training])
	_check(
		not text.contains("RIVAL_PRIVATE")
			and not text.contains("slots")
			and not text.contains("ai_memory"),
		"privacy_allowlist"
	)
	_check(
		port.actor_decision_facts(
			AiActorEconomyFactsCapability.new(),
			1
		).is_empty()
			and port.actor_decision_facts(capability, 0).is_empty(),
		"forged_and_human_rejected"
	)
	_check(
		int(ai.call("_spendable_cash_units", 1)) == 800,
		"ai_consumes_typed_available_cash"
	)
	_check(world.to_save_data() == world_before, "world_zero_mutation")
	_check(
		JSON.stringify(monster.active_monster_wagers) == wager_before,
		"wager_zero_mutation"
	)
	_check(rng.capture_plan_checkpoint() == rng_before, "rng_zero_delta")
	_check(
		port.debug_snapshot() == port_debug_before
			and cash_query.debug_snapshot() == cash_debug_before,
		"literal_query_zero_mutation"
	)
	_check(
		not bool(port.debug_snapshot().get("stores_cash", true))
			and not bool(
				port.debug_snapshot().get("stores_wager_commitments", true)
			)
			and not bool(port.debug_snapshot().get("owns_save_section", true)),
		"query_is_not_state_owner"
	)
	_check(
		bool(ai.debug_snapshot().get("controller_ready", false)),
		"ai_lifecycle_requires_economy_port"
	)
	var positive_actor := (world.players[1] as Dictionary).duplicate(true)
	var indebted_actor := positive_actor.duplicate(true)
	indebted_actor["cash"] = -4
	indebted_actor["cash_cents"] = -400
	world.players[1] = indebted_actor
	var indebted_decision := port.actor_decision_facts(capability, 1)
	var indebted_training := port.actor_training_economy_facts(capability, 1)
	_check(
		int(indebted_decision.get("available_cash_cents", -1)) == 0,
		"indebted_decision_cash_clamped"
	)
	_check(
		int(indebted_training.get("total_cash_cents", 0)) == -400
			and int(indebted_training.get("total_cash_units", 0)) == -4
			and int(
				(ai.call("_ai_observation_vector", 1) as Dictionary).get(
					"cash",
					0
				)
			) == -4,
		"signed_training_cash_preserved_end_to_end"
	)
	world.players[1] = positive_actor
	await _finish(decision, training)


func _players(catalog: RoleCatalogRuntimeService) -> Array:
	var result: Array = []
	for player_index in range(4):
		var role := catalog.definition_at(player_index)
		role["role_index"] = player_index
		var is_ai := player_index > 0
		result.append({
			"id": player_index,
			"actor_id": "player.%d" % player_index,
			"name": "Human" if not is_ai else "AI-%d" % player_index,
			"seat_type": "ai" if is_ai else "human",
			"is_ai": is_ai,
			"role_index": player_index,
			"role_card": role,
			"eliminated": false,
			"cash": 500 if not is_ai else 1000,
			"cash_cents": (500 if not is_ai else 1000) * 100,
			"action_cooldown": 1.25 if player_index == 1 else 0.0,
			"cities_built": 2 if player_index == 1 else 0,
			"total_city_income": 12 if player_index == 1 else 0,
			"total_card_income": 0,
			"total_role_income": 0,
			"total_card_spend": 0,
			"total_build_spend": 0,
			"total_business_spend": 34 if player_index == 1 else 0,
			"slots": [{"private_marker": "RIVAL_PRIVATE"}],
			"discard": [],
			"city_guesses": {},
			"ai_profile": {"profile_index": maxi(0, player_index - 1)} if is_ai else {},
			"ai_memory": {"decision_samples": [], "action_counts": {}},
		})
	return result


func _seed_wager(monster: MonsterRuntimeController) -> void:
	var competitors := [
		{"side": "a", "name": "A", "slot": 0, "uid": 201, "damage": 3},
		{"side": "b", "name": "B", "slot": 1, "uid": 202, "damage": 2},
	]
	monster.active_monster_wagers = [{
		"wager_id": 81,
		"settlement_revision": 10,
		"base_percent": 5,
		"competitors": competitors,
		"damage_a": 3,
		"damage_b": 2,
		"bets": {
			"1": {
				"player_index": 1,
				"side": "a",
				"stake": 200,
				"stake_percent": 20,
				"forced": false,
			},
		},
		"public_bets": [],
		"historical_public_pool": 0,
		"eligible_player_indices": [1],
		"opening_cash_units_by_player": {"1": 1000},
		"public_player_ids_by_index": {"1": "player.1"},
		"lifecycle_schema_version": BATTLE_LIFECYCLE_POLICY.SCHEMA_VERSION,
		"lifecycle_phase": BATTLE_LIFECYCLE_POLICY.PHASE_DECISION,
		"lifecycle_revision": 1,
		"decision_remaining_seconds": 15.0,
		"battle_limit_seconds": 60.0,
		"battle_remaining_seconds": 60.0,
		"locked_competitor_uids": [201, 202],
		"battle_roster_fingerprint": BATTLE_LIFECYCLE_POLICY.roster_fingerprint(
			competitors
		),
		"opening_attack_applied": true,
		"decision_open": true,
		"resolved": false,
	}]
	monster.set("_monster_wager_settlement_revision", 10)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error("AI_ACTOR_ECONOMY_FACTS_BENCH: %s" % label)


func _finish(decision: Dictionary, training: Dictionary) -> void:
	print(
		"AI_ACTOR_ECONOMY_FACTS_TYPED_PORT_MIGRATION_BENCH|status=%s|checks=%d|failures=%d|available_cents=%d|total_cents=%d"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks,
			_failures.size(),
			int(decision.get("available_cash_cents", -1)),
			int(training.get("total_cash_cents", -1)),
		]
	)
	var hold_seconds := 0.1 if DisplayServer.get_name() == "headless" else 30.0
	await get_tree().create_timer(hold_seconds).timeout
	get_tree().quit(0 if _failures.is_empty() else 1)
