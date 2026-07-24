extends SceneTree

const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")
const BATTLE_LIFECYCLE_POLICY := preload("res://scripts/runtime/monster_battle_lifecycle_policy_v06.gd")


class HostileEarlyBindProbe:
	extends Node

	var capability := AiActorEconomyFactsCapability.new()
	var enter_tree_attempted := false
	var enter_tree_accepted := false
	var ready_attempted := false
	var ready_accepted := false

	func _enter_tree() -> void:
		var port := get_parent().get_node_or_null(
			"AiActorEconomyFactsQueryPort"
		) as AiActorEconomyFactsQueryPort
		enter_tree_attempted = port != null
		enter_tree_accepted = port != null and port.bind_ai_capability(capability)

	func _ready() -> void:
		var port := get_parent().get_node_or_null(
			"AiActorEconomyFactsQueryPort"
		) as AiActorEconomyFactsQueryPort
		ready_attempted = port != null
		ready_accepted = port != null and port.bind_ai_capability(capability)


var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var coordinator := COORDINATOR_SCENE.instantiate() as GameRuntimeCoordinator
	var hostile := HostileEarlyBindProbe.new()
	coordinator.add_child(hostile)
	coordinator.move_child(hostile, 0)
	root.add_child(coordinator)
	await process_frame

	var world := coordinator.world_session_state()
	var session := coordinator.get_node_or_null(
		"GameSessionRuntimeController"
	) as GameSessionRuntimeController
	var catalog := coordinator.get_node_or_null(
		"RoleCatalogRuntimeService"
	) as RoleCatalogRuntimeService
	var actor_state := coordinator.get_node_or_null(
		"AiActorStatePort"
	) as AiActorStatePort
	var port := coordinator.get_node_or_null(
		"AiActorEconomyFactsQueryPort"
	) as AiActorEconomyFactsQueryPort
	var cash_query := coordinator.get_node_or_null(
		"MonsterWagerCashCommitmentQueryPort"
	) as MonsterWagerCashCommitmentQueryPort
	var monster := coordinator.get_node_or_null(
		"MonsterRuntimeController"
	) as MonsterRuntimeController
	var monster_bridge := coordinator.get_node_or_null(
		"MonsterRuntimeWorldBridge"
	) as MonsterRuntimeWorldBridge
	var ai := coordinator.get_node_or_null(
		"AiRuntimeController"
	) as AiRuntimeController
	var ai_bridge := coordinator.get_node_or_null(
		"AiRuntimeWorldBridge"
	) as AiRuntimeWorldBridge
	var rng := coordinator.run_rng_service()

	_expect(
		world != null
			and session != null
			and catalog != null
			and actor_state != null
			and port != null
			and cash_query != null
			and monster != null
			and monster_bridge != null
			and ai != null
			and ai_bridge != null
			and rng != null,
		"production composition exposes every actor-economy authority"
	)
	if _failures.size() > 0:
		_finish()
		return

	ai_bridge.set_rng_service(rng)
	ai_bridge.set_world_session_state(world)
	ai.set_world_bridge(ai_bridge)
	monster_bridge.set_world_session_state(world)
	monster.set_world_bridge(monster_bridge)
	ai.configure({"ruleset_id": "v0.6"})
	session.configure({"ruleset_id": "v0.6"}, {})
	var started := session.begin_session({
		"session_id": "actor-economy-focused",
		"scenario_id": "focused",
		"seed": 314159,
		"player_count": 4,
	})
	world.restore({
		"players": _players(catalog),
		"districts": [],
		"game_time": 12.0,
	}, true)
	_seed_wager(monster)

	var capability := ai.get(
		"_ai_actor_economy_facts_capability"
	) as AiActorEconomyFactsCapability
	_expect(
		str(started.get("session_state", ""))
			== GameSessionRuntimeController.STATE_RUNNING,
		"fixture starts through GameSession authority"
	)
	_expect(port.is_ready(), "actor-economy query is production-ready")
	_expect(capability != null, "AI receives the opaque economy capability")
	_expect(
		capability == coordinator.get("_ai_actor_economy_facts_capability"),
		"AI and Coordinator share one prebound capability"
	)
	_expect(
		hostile.enter_tree_attempted and not hostile.enter_tree_accepted,
		"hostile enter-tree capability bind is rejected"
	)
	_expect(
		hostile.ready_attempted and not hostile.ready_accepted,
		"hostile ready capability bind remains rejected"
	)
	var bind_debug := port.debug_snapshot()
	_expect(
		int(bind_debug.get("capability_revision", 0)) == 1
			and int(bind_debug.get("capability_bind_rejection_count", 0)) >= 2,
		"one-shot capability is sealed before child lifecycle"
	)

	var decision := port.actor_decision_facts(capability, 1)
	var training := port.actor_training_economy_facts(capability, 1)
	_expect(
		decision.keys() == AiActorEconomyFactsQueryPort.DECISION_FACT_KEYS,
		"decision facts use the exact schema allowlist"
	)
	_expect(
		training.keys() == AiActorEconomyFactsQueryPort.TRAINING_FACT_KEYS,
		"training facts use the exact schema allowlist"
	)
	_expect(
		str(decision.get("visibility_scope", "")) == "actor_private"
			and int(decision.get("actor_index", -1)) == 1,
		"decision facts are scoped to the requested AI"
	)
	_expect(
		int(decision.get("available_cash_cents", -1)) == 80000
			and int(decision.get("available_cash_units", -1)) == 800,
		"decision facts subtract the real 20-percent wager commitment"
	)
	_expect(
		is_equal_approx(
			float(decision.get("action_cooldown_seconds", -1.0)),
			2.5
		)
			and not bool(decision.get("action_ready", true)),
		"decision facts preserve the exact cooldown gate"
	)
	_expect(
		int(training.get("total_cash_cents", -1)) == 100000
			and int(training.get("total_cash_units", -1)) == 1000,
		"training facts retain total ledger cash before wager settlement"
	)
	_expect(
		int(training.get("total_city_income_units", -1)) == 11
			and int(training.get("total_card_income_units", -1)) == 22
			and int(training.get("total_role_income_units", -1)) == 33,
		"training income counters preserve authoritative values"
	)
	_expect(
		int(training.get("total_card_spend_units", -1)) == 44
			and int(training.get("total_build_spend_units", -1)) == 55
			and int(training.get("total_business_spend_units", -1)) == 66,
		"training spend counters preserve authoritative values"
	)
	_expect(
		int(training.get("cities_built", -1)) == 3,
		"training facts include the existing private build counter"
	)
	_expect(
		str(decision.get("session_id", "")) == "actor-economy-focused"
			and int(decision.get("session_revision", -1))
				== session.session_start_revision(),
		"decision facts bind current session identity"
	)
	_expect(
		str(decision.get("source_revision", "")).length() == 64
			and str(decision.get("fingerprint", "")).length() == 64
			and str(training.get("source_revision", "")).length() == 64
			and str(training.get("fingerprint", "")).length() == 64,
		"both snapshots carry deterministic revisions and fingerprints"
	)
	_expect(
		port.actor_decision_facts(capability, 1) == decision
			and port.actor_training_economy_facts(capability, 1) == training,
		"unchanged authority produces deterministic snapshots"
	)
	_expect(
		port.is_current_decision_facts(capability, decision)
			and port.is_current_training_economy_facts(capability, training),
		"fresh snapshots validate against current authority"
	)

	var private_text := JSON.stringify([decision, training])
	for forbidden in [
		"HUMAN_PRIVATE",
		"AI_B_PRIVATE",
		"slots",
		"discard",
		"city_guesses",
		"ai_memory",
		"hidden_owner",
		"reserved_cents",
		"total_cents",
	]:
		_expect(
			not private_text.contains(forbidden),
			"actor-economy snapshots exclude %s" % forbidden
		)
	_expect(
		TablePresentationPureDataPolicy.is_pure_data([decision, training]),
		"actor-economy snapshots are pure data"
	)
	var detached := decision.duplicate(true)
	detached["available_cash_units"] = 999999
	_expect(
		int(
			port.actor_decision_facts(capability, 1).get(
				"available_cash_units",
				-1
			)
		) == 800,
		"returned snapshots are detached"
	)

	_expect(
		port.actor_decision_facts(
			AiActorEconomyFactsCapability.new(),
			1
		).is_empty(),
		"forged capability fails closed"
	)
	_expect(
		port.actor_decision_facts(capability, 0).is_empty(),
		"human private economy query fails closed"
	)
	_expect(
		port.actor_decision_facts(capability, -1).is_empty()
			and port.actor_decision_facts(capability, 99).is_empty(),
		"out-of-range actor queries fail closed"
	)
	var eliminated := (world.players[2] as Dictionary).duplicate(true)
	eliminated["eliminated"] = true
	world.players[2] = eliminated
	_expect(
		port.actor_decision_facts(capability, 2).is_empty(),
		"eliminated AI private economy query fails closed"
	)

	var malformed_counter := (world.players[1] as Dictionary).duplicate(true)
	malformed_counter["total_card_income"] = "bad"
	world.players[1] = malformed_counter
	_expect(
		port.actor_training_economy_facts(capability, 1).is_empty()
			and not port.actor_decision_facts(capability, 1).is_empty(),
		"malformed training counters fail closed without widening decision facts"
	)
	malformed_counter["total_card_income"] = 22
	world.players[1] = malformed_counter

	var malformed_cooldown := (world.players[1] as Dictionary).duplicate(true)
	malformed_cooldown["action_cooldown"] = -1.0
	world.players[1] = malformed_cooldown
	_expect(
		port.actor_decision_facts(capability, 1).is_empty(),
		"malformed cooldown fails closed"
	)
	malformed_cooldown["action_cooldown"] = 2.5
	world.players[1] = malformed_cooldown

	var world_before := world.to_save_data()
	var wager_before := JSON.stringify(monster.active_monster_wagers)
	var wager_revision_before := int(
		monster.get("_monster_wager_settlement_revision")
	)
	var rng_before := rng.capture_plan_checkpoint()
	var port_debug_before := port.debug_snapshot()
	var cash_debug_before := cash_query.debug_snapshot()
	port.actor_decision_facts(capability, 1)
	port.actor_training_economy_facts(capability, 1)
	port.is_current_decision_facts(capability, decision)
	port.is_current_training_economy_facts(capability, training)
	_expect(
		world.to_save_data() == world_before,
		"queries mutate no WorldSession state"
	)
	_expect(
		JSON.stringify(monster.active_monster_wagers) == wager_before
			and int(monster.get("_monster_wager_settlement_revision"))
				== wager_revision_before,
		"queries mutate no wager authority"
	)
	_expect(
		rng.capture_plan_checkpoint() == rng_before,
		"queries consume zero RNG"
	)
	_expect(
		port.debug_snapshot() == port_debug_before
			and cash_query.debug_snapshot() == cash_debug_before,
		"queries perform literal zero diagnostic mutation"
	)
	_expect(
		int(ai.call("_spendable_cash_units", 1)) == 800,
		"AI spendable-cash helper consumes the typed decision snapshot"
	)

	var cooldown_changed := (world.players[1] as Dictionary).duplicate(true)
	cooldown_changed["action_cooldown"] = 0.0
	world.players[1] = cooldown_changed
	var ready_decision := port.actor_decision_facts(capability, 1)
	_expect(
		bool(ready_decision.get("action_ready", false))
			and not port.is_current_decision_facts(capability, decision),
		"cooldown changes invalidate stale decision facts"
	)

	var before_restore := port.actor_training_economy_facts(capability, 1)
	var saved_world := world.to_save_data()
	world.restore(saved_world, true)
	_expect(
		not port.is_current_training_economy_facts(capability, before_restore),
		"cold restore rotates source revision"
	)

	var malformed_wager := (
		monster.active_monster_wagers[0] as Dictionary
	).duplicate(true)
	malformed_wager.erase("opening_cash_units_by_player")
	monster.active_monster_wagers[0] = malformed_wager
	_expect(
		port.actor_decision_facts(capability, 1).is_empty()
			and int(ai.call("_spendable_cash_units", 1)) == 0,
		"malformed wager commitment fails closed"
	)
	_seed_wager(monster)

	_run_source_negative_gates()
	coordinator.queue_free()
	await process_frame
	_finish()


func _players(catalog: RoleCatalogRuntimeService) -> Array:
	var result: Array = []
	for player_index in range(4):
		var role_index := player_index
		var role := catalog.definition_at(role_index)
		role["role_index"] = role_index
		var is_ai := player_index > 0
		var player := {
			"id": player_index,
			"actor_id": "player.%d" % player_index,
			"name": "Human" if not is_ai else "AI-%d" % player_index,
			"seat_type": "ai" if is_ai else "human",
			"is_ai": is_ai,
			"role_index": role_index,
			"role_card": role,
			"eliminated": false,
			"cash": 500 if player_index == 0 else 1000 + player_index - 1,
			"cash_cents": (500 if player_index == 0 else 1000 + player_index - 1) * 100,
			"action_cooldown": 2.5 if player_index == 1 else 0.0,
			"cities_built": 3 if player_index == 1 else 0,
			"total_city_income": 11 if player_index == 1 else 0,
			"total_card_income": 22 if player_index == 1 else 0,
			"total_role_income": 33 if player_index == 1 else 0,
			"total_card_spend": 44 if player_index == 1 else 0,
			"total_build_spend": 55 if player_index == 1 else 0,
			"total_business_spend": 66 if player_index == 1 else 0,
			"slots": [{"private_marker": "HUMAN_PRIVATE" if not is_ai else "AI_%d_PRIVATE" % player_index}],
			"discard": ["DISCARD_%d" % player_index],
			"city_guesses": {"region.0": player_index},
			"ai_profile": {"profile_index": maxi(0, player_index - 1)} if is_ai else {},
			"ai_memory": {"decision_samples": [], "action_counts": {}},
		}
		result.append(player)
	return result


func _seed_wager(monster: MonsterRuntimeController) -> void:
	var competitors := [
		{"side": "a", "name": "A", "slot": 0, "uid": 101, "damage": 3},
		{"side": "b", "name": "B", "slot": 1, "uid": 102, "damage": 2},
	]
	monster.active_monster_wagers = [{
		"wager_id": 71,
		"settlement_revision": 9,
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
		"locked_competitor_uids": [101, 102],
		"battle_roster_fingerprint": BATTLE_LIFECYCLE_POLICY.roster_fingerprint(
			competitors
		),
		"opening_attack_applied": true,
		"decision_open": true,
		"resolved": false,
	}]
	monster.set("_monster_wager_settlement_revision", 9)


func _run_source_negative_gates() -> void:
	var ai_source := FileAccess.get_file_as_string(
		"res://scripts/runtime/ai_runtime_controller.gd"
	)
	var port_source := FileAccess.get_file_as_string(
		"res://scripts/runtime/ai_actor_economy_facts_query_port.gd"
	)
	var coordinator_source := FileAccess.get_file_as_string(
		"res://scripts/runtime/game_runtime_coordinator.gd"
	)
	var coordinator_scene := FileAccess.get_file_as_string(
		"res://scenes/runtime/GameRuntimeCoordinator.tscn"
	)
	var registry_scene := FileAccess.get_file_as_string(
		"res://scenes/runtime/V06SaveOwnerRegistry.tscn"
	)

	for function_name in [
		"_spendable_cash_units",
		"_ai_live_route_balance_report",
		"_ai_observation_vector",
		"_record_ai_decision",
		"_finalize_ai_decision_rewards",
		"_ai_route_hand_inventory",
		"_ai_card_play_context",
		"_ai_card_play_candidates",
		"_ai_card_buy_candidates",
		"_ai_counter_response_candidates",
	]:
		var body := _function_body(ai_source, function_name)
		_expect(body != "MISSING", "%s exists for source inspection" % function_name)
		_expect(
			not body.contains("_cash_commitment_query_port")
				and not body.contains("player.get(\"cash\"")
				and not body.contains("players[player_index] as Dictionary).get(\"cash\"")
				and not body.contains("action_cooldown"),
			"%s has no generic actor-economy read" % function_name
		)

	_expect(
		not ai_source.contains("_cash_commitment_query_port"),
		"AI controller cannot bypass the capability-guarded economy port"
	)
	_expect(
		coordinator_scene.count(
			"[node name=\"AiActorEconomyFactsQueryPort\""
		) == 1,
		"production composition owns exactly one actor-economy query"
	)
	_expect(
		coordinator_source.count(
			"_ai_actor_economy_facts_capability = AiActorEconomyFactsCapability.new()"
		) == 1,
		"Coordinator has one economy capability creation site"
	)
	_expect(
		coordinator_source.contains(
			"_wire_ai_actor_economy_facts_query_port"
		)
			and not _function_body(
				coordinator_source,
				"_wire_monster_wager_cash_commitment_query_port"
			).contains("AiRuntimeController"),
		"Coordinator injects only the guarded economy query into AI"
	)
	_expect(
		port_source.contains("DECISION_FACT_KEYS")
			and port_source.contains("TRAINING_FACT_KEYS")
			and not port_source.contains("current_scene")
			and not port_source.contains("/root/" + "Main"),
		"query source freezes narrow schemas without Main"
	)
	_expect(
		registry_scene.count("section_id =") == 19
			and not registry_scene.contains("actor_economy"),
		"actor-economy migration adds no Save section"
	)


func _function_body(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return "MISSING"
	var next := source.find("\nfunc ", start + 1)
	return source.substr(start) if next < 0 else source.substr(start, next - start)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print(
			"AI actor economy facts typed-port migration passed (%d checks)."
			% _checks
		)
		print("AI_ACTOR_ECONOMY_FACTS_TYPED_PORT_MIGRATION_COMPLETE")
		quit(0)
		return
	for failure in _failures:
		push_error("AI actor economy facts migration failed: %s" % failure)
	quit(1)
