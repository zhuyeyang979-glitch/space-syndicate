extends Node


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
	var port := coordinator.get_node_or_null(
		"AiActorHandInventoryQueryPort"
	) as AiActorHandInventoryQueryPort if coordinator != null else null
	var inventory := coordinator.get_node_or_null(
		"CardInventoryRuntimeService"
	) as CardInventoryRuntimeService if coordinator != null else null
	var ai := coordinator.get_node_or_null(
		"AiRuntimeController"
	) as AiRuntimeController if coordinator != null else null
	var rng := coordinator.run_rng_service() if coordinator != null else null
	_check(
		coordinator != null
			and world != null
			and session != null
			and catalog != null
			and port != null
			and inventory != null
			and ai != null
			and rng != null,
		"production_dependencies"
	)
	if not _failures.is_empty():
		await _finish({})
		return

	inventory.configure({
		"ruleset_id": "v0.4",
		"card_inventory": {
			"ordinary_hand_limit": 5,
			"maximum_card_rank": 4,
		},
	})
	ai.configure({"ruleset_id": "v0.6"})
	session.configure({"ruleset_id": "v0.6"}, {})
	session.begin_session({
		"session_id": "actor-hand-bench",
		"scenario_id": "bench",
		"seed": 141421,
		"player_count": 4,
	})
	world.restore({
		"players": _players(catalog),
		"districts": [],
		"game_time": 9.0,
	}, true)

	var capability := ai.get(
		"_ai_actor_hand_inventory_capability"
	) as AiActorHandInventoryCapability
	var world_before := world.to_save_data()
	var session_before := session.session_summary()
	var inventory_before := inventory.debug_snapshot()
	var rng_before := rng.capture_plan_checkpoint()
	var port_before := port.debug_snapshot()
	var snapshot := port.actor_hand_snapshot(capability, 1)

	_check(port.is_ready(), "port_ready")
	_check(capability != null, "capability_bound")
	_check(
		capability == coordinator.get("_ai_actor_hand_inventory_capability"),
		"single_capability"
	)
	_check(
		snapshot.keys() == AiActorHandInventoryQueryPort.SNAPSHOT_KEYS,
		"exact_snapshot_schema"
	)
	_check(
		int(snapshot.get("actor_index", -1)) == 1
			and str(snapshot.get("visibility_scope", "")) == "actor_private",
		"actor_private_scope"
	)
	_check(
		int(snapshot.get("counted_hand_size", -1)) == 3
			and int(snapshot.get("hand_limit", -1)) == 5,
		"counted_hand_and_limit"
	)
	_check(
		snapshot.get("discardable_slot_indices", []) == [0],
		"discardable_slot_parity"
	)
	_check(
		(snapshot.get("slots", []) as Array).size() == 4
			and not bool(
				((snapshot.get("slots", []) as Array)[1] as Dictionary).get(
					"occupied",
					true
				)
			),
		"stable_slot_hole"
	)
	_check(
		str(
			(ai.call("_actor_hand_card_at", snapshot, 0) as Dictionary).get(
				"name",
				""
			)
		) == "城市融资1",
		"ai_stable_slot_consumption"
	)
	_check(
		ai.call("_discardable_hand_slots_for_purchase", 1) == [0],
		"ai_discard_consumption"
	)
	var text := JSON.stringify(snapshot)
	_check(
		text.contains("OWN_HAND_SECRET")
			and not text.contains("RIVAL_HAND_SECRET")
			and not text.contains("HUMAN_HAND_SECRET")
			and not text.contains("ai_memory"),
		"viewer_isolation"
	)
	_check(
		port.actor_hand_snapshot(
			AiActorHandInventoryCapability.new(),
			1
		).is_empty()
			and port.actor_hand_snapshot(capability, 0).is_empty(),
		"forged_and_human_rejected"
	)
	_check(
		TablePresentationPureDataPolicy.is_pure_data(snapshot),
		"pure_data_snapshot"
	)
	_check(
		port.is_current_snapshot(capability, snapshot),
		"current_snapshot_validation"
	)
	_check(world.to_save_data() == world_before, "world_zero_mutation")
	_check(session.session_summary() == session_before, "session_zero_mutation")
	_check(
		inventory.debug_snapshot() == inventory_before,
		"inventory_zero_mutation"
	)
	_check(rng.capture_plan_checkpoint() == rng_before, "rng_zero_delta")
	_check(port.debug_snapshot() == port_before, "literal_query_zero_mutation")
	_check(
		not bool(port.debug_snapshot().get("stores_hand_or_inventory", true))
			and not bool(port.debug_snapshot().get("owns_save_section", true)),
		"query_is_not_state_owner"
	)
	await _finish(snapshot)


func _players(catalog: RoleCatalogRuntimeService) -> Array:
	var result: Array = []
	for player_index in range(4):
		var role := catalog.definition_at(player_index)
		role["role_index"] = player_index
		var is_ai := player_index > 0
		var slots: Array = []
		if player_index == 0:
			slots = [_card("城市融资1", "HUMAN_HAND_SECRET")]
		elif player_index == 1:
			slots = [
				_card("城市融资1", "OWN_HAND_SECRET"),
				null,
				_card("星际广告1", "OWN_QUEUED", false, true),
				_card("轨道融资1", "OWN_LOCKED", false, false, 2.0),
			]
		elif player_index == 2:
			slots = [_card("城市融资2", "RIVAL_HAND_SECRET")]
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
			"action_cooldown": 0.0,
			"cities_built": 0,
			"total_city_income": 0,
			"total_card_income": 0,
			"total_role_income": 0,
			"total_card_spend": 0,
			"total_build_spend": 0,
			"total_business_spend": 0,
			"slots": slots,
			"discard": [],
			"city_guesses": {},
			"ai_profile": {"profile_index": maxi(0, player_index - 1)}
				if is_ai else {},
			"ai_memory": {"decision_samples": [], "action_counts": {}},
		})
	return result


func _card(
	card_name: String,
	private_marker: String,
	persistent := false,
	queued := false,
	lock_left := 0.0,
	kind := "card"
) -> Dictionary:
	return {
		"name": card_name,
		"family_id": card_name,
		"rank": 1,
		"kind": kind,
		"persistent": persistent,
		"queued_for_resolution": queued,
		"cooldown_left": 0.0,
		"lock_left": lock_left,
		"private_marker": private_marker,
	}


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error("AI_ACTOR_HAND_INVENTORY_BENCH: %s" % label)


func _finish(snapshot: Dictionary) -> void:
	print(
		"AI_ACTOR_HAND_INVENTORY_TYPED_PORT_MIGRATION_BENCH|status=%s|checks=%d|failures=%d|counted_hand=%d|discardable=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks,
			_failures.size(),
			int(snapshot.get("counted_hand_size", -1)),
			JSON.stringify(snapshot.get("discardable_slot_indices", [])),
		]
	)
	var hold_seconds := 0.1 if DisplayServer.get_name() == "headless" else 30.0
	await get_tree().create_timer(hold_seconds).timeout
	get_tree().quit(0 if _failures.is_empty() else 1)
