extends SceneTree

const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")


class HostileEarlyBindProbe:
	extends Node

	var capability := AiActorHandInventoryCapability.new()
	var enter_tree_attempted := false
	var enter_tree_accepted := false
	var ready_attempted := false
	var ready_accepted := false

	func _enter_tree() -> void:
		var port := get_parent().get_node_or_null(
			"AiActorHandInventoryQueryPort"
		) as AiActorHandInventoryQueryPort
		enter_tree_attempted = port != null
		enter_tree_accepted = port != null and port.bind_ai_capability(capability)

	func _ready() -> void:
		var port := get_parent().get_node_or_null(
			"AiActorHandInventoryQueryPort"
		) as AiActorHandInventoryQueryPort
		ready_attempted = port != null
		ready_accepted = port != null and port.bind_ai_capability(capability)


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

	func _player_active_city_count(_player_index: int) -> int:
		return 0

	func _card_resolution_current_queue() -> Array:
		return []

	func _card_resolution_next_queue() -> Array:
		return []


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
		"AiActorHandInventoryQueryPort"
	) as AiActorHandInventoryQueryPort
	var inventory := coordinator.get_node_or_null(
		"CardInventoryRuntimeService"
	) as CardInventoryRuntimeService
	var runtime_catalog := coordinator.get_node_or_null(
		"CardRuntimeCatalogService"
	) as CardRuntimeCatalogService
	var definition_bridge := coordinator.get_node_or_null(
		"CardRuntimeDefinitionWorldBridge"
	) as CardRuntimeDefinitionWorldBridge
	var ai := coordinator.get_node_or_null(
		"AiRuntimeController"
	) as AiRuntimeController
	var ai_bridge := coordinator.get_node_or_null(
		"AiRuntimeWorldBridge"
	) as AiRuntimeWorldBridge
	var monster := coordinator.get_node_or_null(
		"MonsterRuntimeController"
	) as MonsterRuntimeController
	var monster_bridge := coordinator.get_node_or_null(
		"MonsterRuntimeWorldBridge"
	) as MonsterRuntimeWorldBridge
	var market := coordinator.get_node_or_null(
		"ProductMarketRuntimeController"
	) as ProductMarketRuntimeController
	var rng := coordinator.run_rng_service()
	_expect(
		coordinator != null
			and world != null
			and session != null
			and catalog != null
			and actor_state != null
			and port != null
			and inventory != null
			and runtime_catalog != null
			and definition_bridge != null
			and ai != null
			and ai_bridge != null
			and monster != null
			and monster_bridge != null
			and market != null
			and rng != null,
		"production composition exposes every actor-hand authority"
	)
	if not _failures.is_empty():
		_finish()
		return

	var consumer_world := AiConsumerWorldProbe.new()
	consumer_world.name = "AiConsumerWorldProbe"
	coordinator.add_child(consumer_world)
	ai_bridge.bind_world(consumer_world)
	ai_bridge.set_rng_service(rng)
	ai_bridge.set_world_session_state(world)
	ai.set_world_bridge(ai_bridge)
	monster_bridge.set_world_session_state(world)
	monster.set_world_bridge(monster_bridge)
	ai.set_monster_runtime_controller(monster)
	ai.set_product_market_runtime_controller(market)
	runtime_catalog.configure({})
	definition_bridge.set_catalog_service(runtime_catalog)
	ai.set_card_definition_bridge(definition_bridge)
	_expect(
		not inventory.is_ready() and not port.is_ready(),
		"unconfigured inventory policy keeps the actor-hand boundary closed"
	)
	inventory.configure({
		"ruleset_id": "v0.4",
		"card_inventory": {
			"ordinary_hand_limit": 5,
			"maximum_card_rank": 4,
		},
	})
	ai.configure({"ruleset_id": "v0.6"})
	session.configure({"ruleset_id": "v0.6"}, {})
	var started := session.begin_session({
		"session_id": "actor-hand-focused",
		"scenario_id": "focused",
		"seed": 161803,
		"player_count": 4,
	})
	world.restore({
		"players": _players(catalog),
		"districts": [],
		"game_time": 17.0,
	}, true)

	var capability := ai.get(
		"_ai_actor_hand_inventory_capability"
	) as AiActorHandInventoryCapability
	_expect(
		str(started.get("session_state", ""))
			== GameSessionRuntimeController.STATE_RUNNING,
		"fixture starts through GameSession authority"
	)
	_expect(port.is_ready(), "actor-hand query is production-ready")
	_expect(capability != null, "AI receives the opaque hand capability")
	_expect(
		capability == coordinator.get("_ai_actor_hand_inventory_capability"),
		"AI and Coordinator share one prebound hand capability"
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
		"one-shot hand capability is sealed before child lifecycle"
	)
	_expect(
		bool(ai.debug_snapshot().get("controller_ready", false)),
		"AI lifecycle requires and receives the actor-hand boundary"
	)
	var bound_port := ai.get(
		"_ai_actor_hand_inventory_query_port"
	) as AiActorHandInventoryQueryPort
	ai.set("_ai_actor_hand_inventory_query_port", null)
	_expect(
		not bool(ai.debug_snapshot().get("controller_ready", true)),
		"missing actor-hand boundary fails AI lifecycle readiness closed"
	)
	ai.set("_ai_actor_hand_inventory_query_port", bound_port)
	_expect(
		bool(ai.debug_snapshot().get("controller_ready", false)),
		"restored actor-hand boundary restores AI lifecycle readiness"
	)

	var snapshot := port.actor_hand_snapshot(capability, 1)
	_expect(
		snapshot.keys() == AiActorHandInventoryQueryPort.SNAPSHOT_KEYS,
		"actor-hand snapshot uses the exact root schema allowlist"
	)
	_expect(
		str(snapshot.get("visibility_scope", "")) == "actor_private"
			and int(snapshot.get("actor_index", -1)) == 1,
		"snapshot is scoped to the authorized AI actor"
	)
	_expect(
		str(snapshot.get("session_id", "")) == "actor-hand-focused"
			and int(snapshot.get("session_revision", -1))
				== session.session_start_revision(),
		"snapshot is bound to current session identity"
	)
	_expect(
		str(snapshot.get("source_revision", "")).length() == 64
			and str(snapshot.get("fingerprint", "")).length() == 64,
		"snapshot carries deterministic revision and fingerprint"
	)
	_expect(
		int(snapshot.get("hand_limit", -1)) == 5
			and int(snapshot.get("counted_hand_size", -1)) == 4,
		"snapshot preserves the current five-card counted-hand policy"
	)
	var slots := snapshot.get("slots", []) as Array
	_expect(slots.size() == 6, "snapshot preserves stable physical slot count")
	_expect(
		(slots[0] as Dictionary).keys()
			== AiActorHandInventoryQueryPort.SLOT_KEYS,
		"occupied slots use the exact slot schema allowlist"
	)
	_expect(
		int((slots[0] as Dictionary).get("slot_index", -1)) == 0
			and int((slots[2] as Dictionary).get("slot_index", -1)) == 2,
		"slot indices survive holes without compaction"
	)
	_expect(
		not bool((slots[1] as Dictionary).get("occupied", true))
			and (slots[1] as Dictionary).get("card", {}) == {},
		"empty slots remain explicit detached rows"
	)
	_expect(
		str((slots[2] as Dictionary).get("card_id", "")) == "城市融资2"
			and is_equal_approx(
				float((slots[2] as Dictionary).get("cooldown_left", -1.0)),
				2.0
			),
		"card identity and cooldown are preserved"
	)
	_expect(
		bool((slots[3] as Dictionary).get("queued_for_resolution", false))
			and is_equal_approx(
				float((slots[4] as Dictionary).get("lock_left", -1.0)),
				3.0
			),
		"queued and locked runtime flags are preserved"
	)
	_expect(
		not bool(
			(slots[5] as Dictionary).get(
				"counts_toward_hand_limit",
				true
			)
		),
		"persistent bound actions remain hand-limit exempt"
	)
	_expect(
		snapshot.get("discardable_slot_indices", []) == [0, 2],
		"discardability preserves queued and lock exclusions"
	)
	_expect(
		int(snapshot.get("counted_hand_size", -1))
			== _legacy_counted_hand_size(world.players[1] as Dictionary),
		"counted-hand projection matches the prior production rule"
	)
	_expect(
		snapshot.get("discardable_slot_indices", [])
			== _legacy_discardable_slots(world.players[1] as Dictionary),
		"discardable slot projection matches the prior production rule"
	)
	var explicit_policy_actor := (world.players[1] as Dictionary).duplicate(true)
	var explicit_policy_slots := (
		explicit_policy_actor.get("slots", []) as Array
	).duplicate(true)
	var explicit_exempt_card := (explicit_policy_slots[0] as Dictionary).duplicate(true)
	explicit_exempt_card["counts_toward_hand_limit"] = false
	explicit_policy_slots[0] = explicit_exempt_card
	explicit_policy_actor["slots"] = explicit_policy_slots
	world.players[1] = explicit_policy_actor
	var explicit_policy_snapshot := port.actor_hand_snapshot(capability, 1)
	_expect(
		int(explicit_policy_snapshot.get("counted_hand_size", -1)) == 3
			and explicit_policy_snapshot.get("discardable_slot_indices", []) == [2]
			and not bool(
				((explicit_policy_snapshot.get("slots", []) as Array)[0]
					as Dictionary).get("counts_toward_hand_limit", true)
			),
		"explicit card count metadata is interpreted by CardInventory authority"
	)
	world.players[1] = _players(catalog)[1]
	_expect(
		_eligible_play_slots(snapshot)
			== _legacy_eligible_play_slots(world.players[1] as Dictionary),
		"play and counter candidate slot filtering preserves parity"
	)
	_expect(
		port.actor_hand_snapshot(capability, 1) == snapshot
			and port.is_current_snapshot(capability, snapshot),
		"unchanged hand authority produces a deterministic current snapshot"
	)
	_expect(
		TablePresentationPureDataPolicy.is_pure_data(snapshot),
		"actor-hand snapshot is pure data"
	)

	var private_text := JSON.stringify(snapshot)
	for forbidden in [
		"HUMAN_HAND_SECRET",
		"RIVAL_HAND_SECRET",
		"cash_cents",
		"city_guesses",
		"ai_memory",
		"hidden_owner",
		"save_payload",
	]:
		_expect(
			not private_text.contains(forbidden),
			"actor-hand snapshot excludes %s" % forbidden
		)
	_expect(
		private_text.contains("AI_ONE_HAND_SECRET"),
		"authorized actor retains its own private card payload"
	)

	var detached := snapshot.duplicate(true)
	(detached.get("slots", []) as Array)[0]["card"]["name"] = "MUTATED_COPY"
	(detached.get("discardable_slot_indices", []) as Array).append(99)
	var unchanged := port.actor_hand_snapshot(capability, 1)
	_expect(
		str(
			(((unchanged.get("slots", []) as Array)[0] as Dictionary).get(
				"card",
				{}
			) as Dictionary).get("name", "")
		) == "城市融资1",
		"returned card rows are deeply detached"
	)
	_expect(
		not (unchanged.get("discardable_slot_indices", []) as Array).has(99),
		"returned discard lists are detached"
	)

	_expect(
		port.actor_hand_snapshot(
			AiActorHandInventoryCapability.new(),
			1
		).is_empty(),
		"forged capability fails closed"
	)
	_expect(
		port.actor_hand_snapshot(capability, 0).is_empty(),
		"human private hand query fails closed"
	)
	_expect(
		port.actor_hand_snapshot(capability, -1).is_empty()
			and port.actor_hand_snapshot(capability, 99).is_empty(),
		"out-of-range actor hand queries fail closed"
	)
	var eliminated := (world.players[2] as Dictionary).duplicate(true)
	eliminated["eliminated"] = true
	world.players[2] = eliminated
	_expect(
		port.actor_hand_snapshot(capability, 2).is_empty(),
		"eliminated AI private hand query fails closed"
	)
	world.players[2] = _players(catalog)[2]

	_expect(
		ai.call("_actor_hand_inventory_snapshot", 1) == snapshot,
		"AI consumes the injected typed snapshot"
	)
	_expect(
		ai.call("_discardable_hand_slots_for_purchase", 1) == [0, 2],
		"buy discard selection consumes typed stable slot indices"
	)
	_expect(
		int(ai.call("_actor_counted_hand_size", snapshot)) == 4
			and int(ai.call("_actor_hand_limit", snapshot)) == 5,
		"AI hand pressure consumes typed counts and limit"
	)
	_expect(
		str(
			(ai.call("_actor_hand_card_at", snapshot, 2) as Dictionary).get(
				"name",
				""
			)
		) == "城市融资2",
		"counter revalidation resolves the typed stable slot"
	)
	_expect(
		(ai.call("_actor_hand_card_at", snapshot, 1) as Dictionary).is_empty(),
		"counter revalidation rejects an empty stable slot"
	)
	_expect(
		int(
			ai.call(
				"_actor_highest_family_card_slot",
				snapshot,
				"城市融资3"
			)
		) == 2,
		"buy upgrade scoring preserves highest-family slot selection"
	)
	_expect(
		int(ai.call("_ai_actor_private_receive_pressure", 1, "player_hand_steal", {}))
			== 46,
		"hand-steal pressure preserves below-limit behavior"
	)
	var observation := ai.call("_ai_observation_vector", 1) as Dictionary
	_expect(
		int(observation.get("counted_hand", -1)) == 4,
		"AI observation reads counted hand through the typed port (%s)"
			% JSON.stringify(observation)
	)

	var world_before := world.to_save_data()
	var session_before := session.session_summary()
	var inventory_before := inventory.debug_snapshot()
	var rng_before := rng.capture_plan_checkpoint()
	var port_before := port.debug_snapshot()
	port.actor_hand_snapshot(capability, 1)
	port.is_current_snapshot(capability, snapshot)
	ai.call("_actor_hand_inventory_snapshot", 1)
	ai.call("_discardable_hand_slots_for_purchase", 1)
	_expect(
		world.to_save_data() == world_before,
		"queries mutate no WorldSession hand authority"
	)
	_expect(
		session.session_summary() == session_before,
		"queries do not mark or mutate GameSession"
	)
	_expect(
		inventory.debug_snapshot() == inventory_before,
		"queries mutate no CardInventory diagnostics"
	)
	_expect(
		rng.capture_plan_checkpoint() == rng_before,
		"queries consume zero RNG"
	)
	_expect(
		port.debug_snapshot() == port_before,
		"queries perform literal zero port diagnostic mutation"
	)

	var original_actor := (world.players[1] as Dictionary).duplicate(true)
	var changed_actor := original_actor.duplicate(true)
	var changed_slots := (changed_actor.get("slots", []) as Array).duplicate(true)
	changed_slots[0] = _card("星际广告1", "AI_ONE_HAND_CHANGED")
	changed_actor["slots"] = changed_slots
	world.players[1] = changed_actor
	_expect(
		not port.is_current_snapshot(capability, snapshot),
		"authoritative hand mutation invalidates a stale snapshot"
	)
	world.players[1] = original_actor
	var before_restore := port.actor_hand_snapshot(capability, 1)
	var saved_world := world.to_save_data()
	world.restore(saved_world, true)
	_expect(
		not port.is_current_snapshot(capability, before_restore),
		"cold restore rotates the hand source revision"
	)
	var before_session_change := port.actor_hand_snapshot(capability, 1)
	session.begin_session({
		"session_id": "actor-hand-next",
		"scenario_id": "focused",
		"seed": 161804,
		"player_count": 4,
	})
	_expect(
		not port.is_current_snapshot(capability, before_session_change),
		"session identity change invalidates a stale hand snapshot"
	)

	var valid_actor := (world.players[1] as Dictionary).duplicate(true)
	var malformed_actor := valid_actor.duplicate(true)
	malformed_actor["slots"] = "not-an-array"
	world.players[1] = malformed_actor
	_expect(
		port.actor_hand_snapshot(capability, 1).is_empty(),
		"non-array hand storage fails closed"
	)
	malformed_actor = valid_actor.duplicate(true)
	malformed_actor["slots"] = ["not-a-card"]
	world.players[1] = malformed_actor
	_expect(
		port.actor_hand_snapshot(capability, 1).is_empty(),
		"malformed slot rows fail closed"
	)
	malformed_actor = valid_actor.duplicate(true)
	malformed_actor["slots"] = [{"name": "坏牌", "cooldown_left": -1.0}]
	world.players[1] = malformed_actor
	_expect(
		port.actor_hand_snapshot(capability, 1).is_empty(),
		"negative runtime timing fails closed"
	)
	malformed_actor = valid_actor.duplicate(true)
	malformed_actor["slots"] = [{"kind": "card"}]
	world.players[1] = malformed_actor
	_expect(
		port.actor_hand_snapshot(capability, 1).is_empty(),
		"missing stable card identity fails closed"
	)
	malformed_actor = valid_actor.duplicate(true)
	var impure := _card("城市融资1", "IMPURE")
	var impure_node := Node.new()
	impure["forbidden_node"] = impure_node
	malformed_actor["slots"] = [impure]
	world.players[1] = malformed_actor
	_expect(
		port.actor_hand_snapshot(capability, 1).is_empty(),
		"Node-bearing card payload fails closed"
	)
	impure_node.free()
	malformed_actor = valid_actor.duplicate(true)
	var hidden_owner_card := _card("城市融资1", "HIDDEN_OWNER")
	hidden_owner_card["hidden_owner"] = 2
	malformed_actor["slots"] = [hidden_owner_card]
	world.players[1] = malformed_actor
	_expect(
		port.actor_hand_snapshot(capability, 1).is_empty(),
		"hidden owner fields fail closed before entering the typed snapshot"
	)
	malformed_actor = valid_actor.duplicate(true)
	var private_target_card := _card("城市融资1", "PRIVATE_TARGET")
	private_target_card["machine"] = {"private_target": 2}
	malformed_actor["slots"] = [private_target_card]
	world.players[1] = malformed_actor
	_expect(
		port.actor_hand_snapshot(capability, 1).is_empty(),
		"nested private target fields fail closed before projection"
	)
	malformed_actor = valid_actor.duplicate(true)
	var overflow_slots: Array = []
	for index in range(6):
		overflow_slots.append(_card("城市融资1", "OVERFLOW_%d" % index))
	malformed_actor["slots"] = overflow_slots
	world.players[1] = malformed_actor
	_expect(
		port.actor_hand_snapshot(capability, 1).is_empty(),
		"counted hand above the authoritative limit fails closed"
	)
	world.players[1] = valid_actor

	_run_source_negative_gates()
	coordinator.queue_free()
	await process_frame
	_finish()


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
				_card("城市融资1", "AI_ONE_HAND_SECRET"),
				null,
				_card("城市融资2", "AI_ONE_COOLDOWN", false, false, 2.0),
				_card("星际广告1", "AI_ONE_QUEUED", false, true),
				_card("轨道融资1", "AI_ONE_LOCKED", false, false, 0.0, 3.0),
				_card(
					"BOUND_ACTION",
					"AI_ONE_EXEMPT",
					true,
					false,
					0.0,
					0.0,
					"monster_bound_action"
				),
			]
		elif player_index == 2:
			slots = [_card("星际广告2", "RIVAL_HAND_SECRET")]
		result.append({
			"id": player_index,
			"actor_id": "player.%d" % player_index,
			"name": "Human" if not is_ai else "AI-%d" % player_index,
			"seat_type": "ai" if is_ai else "human",
			"is_ai": is_ai,
			"role_index": player_index,
			"role_card": role,
			"eliminated": false,
			"cash": 600 if not is_ai else 1000,
			"cash_cents": (600 if not is_ai else 1000) * 100,
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
	cooldown := 0.0,
	lock_left := 0.0,
	kind := "card"
) -> Dictionary:
	return {
		"name": card_name,
		"family_id": card_name.trim_suffix("1").trim_suffix("2").trim_suffix("3"),
		"rank": 2 if card_name.ends_with("2") else 1,
		"kind": kind,
		"persistent": persistent,
		"queued_for_resolution": queued,
		"cooldown_left": cooldown,
		"lock_left": lock_left,
		"cost": 2,
		"private_marker": private_marker,
	}


func _legacy_counted_hand_size(player: Dictionary) -> int:
	var count := 0
	for card_variant in player.get("slots", []):
		if not (card_variant is Dictionary):
			continue
		var card := card_variant as Dictionary
		if CardInventoryRuntimeService.canonical_card_counts_toward_hand_limit(card):
			count += 1
	return count


func _legacy_discardable_slots(player: Dictionary) -> Array:
	var result: Array = []
	var slots := player.get("slots", []) as Array
	for index in range(slots.size()):
		if not (slots[index] is Dictionary):
			continue
		var card := slots[index] as Dictionary
		if not CardInventoryRuntimeService.canonical_card_counts_toward_hand_limit(card) \
				or bool(card.get("queued_for_resolution", false)):
			continue
		if float(card.get("lock_left", 0.0)) > 0.0:
			continue
		result.append(index)
	return result


func _eligible_play_slots(snapshot: Dictionary) -> Array:
	var result: Array = []
	for entry_variant in snapshot.get("slots", []):
		var entry := entry_variant as Dictionary
		if not bool(entry.get("occupied", false)):
			continue
		if bool(entry.get("queued_for_resolution", false)):
			continue
		if float(entry.get("cooldown_left", 0.0)) > 0.0:
			continue
		if float(entry.get("lock_left", 0.0)) > 0.0:
			continue
		result.append(int(entry.get("slot_index", -1)))
	return result


func _legacy_eligible_play_slots(player: Dictionary) -> Array:
	var result: Array = []
	var slots := player.get("slots", []) as Array
	for index in range(slots.size()):
		if not (slots[index] is Dictionary):
			continue
		var card := slots[index] as Dictionary
		if bool(card.get("queued_for_resolution", false)):
			continue
		if float(card.get("cooldown_left", 0.0)) > 0.0:
			continue
		if float(card.get("lock_left", 0.0)) > 0.0:
			continue
		result.append(index)
	return result


func _run_source_negative_gates() -> void:
	var ai_source := FileAccess.get_file_as_string(
		"res://scripts/runtime/ai_runtime_controller.gd"
	)
	var port_source := FileAccess.get_file_as_string(
		"res://scripts/runtime/ai_actor_hand_inventory_query_port.gd"
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
		"_ai_actor_private_receive_pressure",
		"_ai_observation_vector",
		"_ai_route_hand_inventory",
		"_ai_card_play_candidates",
		"_ai_card_buy_candidates",
		"_ai_counter_response_candidates",
		"_ai_queue_counter_response_candidate",
		"_ai_discard_keep_value",
		"_ai_discard_slot_for_purchase",
	]:
		var body := _function_body(ai_source, function_name)
		_expect(body != "MISSING", "%s exists for source inspection" % function_name)
		_expect(
			not body.contains("players[")
				and not body.contains("_player_counted_hand_size")
				and not body.contains(
					"private_discardable_slots_for_actor"
				),
			"%s has no generic actor-hand read" % function_name
		)

	_expect(
		not ai_source.contains(
			"_call_world(&\"_player_counted_hand_size\""
		)
			and not ai_source.contains(
				"_call_world(&\"_find_highest_family_card_slot\""
			)
			and not ai_source.contains("var PLAYER_HAND_LIMIT:"),
		"AI cannot fall back to Main hand helpers"
	)
	_expect(
		coordinator_scene.count(
			"[node name=\"AiActorHandInventoryQueryPort\""
		) == 1,
		"production composition owns exactly one actor-hand query"
	)
	_expect(
		coordinator_source.count(
			"_ai_actor_hand_inventory_capability = AiActorHandInventoryCapability.new()"
		) == 1,
		"Coordinator has one actor-hand capability creation site"
	)
	_expect(
		port_source.contains("SNAPSHOT_KEYS")
			and port_source.contains("SLOT_KEYS")
			and port_source.contains("card_counts_toward_hand_limit")
			and port_source.contains("FORBIDDEN_RUNTIME_FIELDS")
			and not port_source.contains("HAND_LIMIT_EXEMPT_KINDS")
			and not port_source.contains("current_scene")
			and not port_source.contains("/root/" + "Main")
			and not port_source.contains("mark_dirty")
			and not port_source.contains("RunRng"),
		"query source freezes a narrow zero-side-effect boundary"
	)
	_expect(
		registry_scene.count("section_id =") == 19
			and not registry_scene.contains("actor_hand_inventory"),
		"actor-hand migration adds no Save section"
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
			"AI actor hand inventory typed-port migration passed (%d checks)."
			% _checks
		)
		print("AI_ACTOR_HAND_INVENTORY_TYPED_PORT_MIGRATION_COMPLETE")
		quit(0)
		return
	for failure in _failures:
		push_error("AI actor hand inventory migration failed: %s" % failure)
	quit(1)
