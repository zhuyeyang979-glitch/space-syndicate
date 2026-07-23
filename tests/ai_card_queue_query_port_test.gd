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
	var session := coordinator.get_node_or_null("GameSessionRuntimeController") as GameSessionRuntimeController
	var world := coordinator.world_session_state()
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController
	var port := coordinator.get_node_or_null("AiCardQueueQueryPort") as AiCardQueueQueryPort
	var queue := coordinator.get_node_or_null("CardResolutionQueueRuntimeService") as CardResolutionQueueRuntimeService
	var rng := coordinator.get_node_or_null("RunRngService") as RunRngService
	_expect(
		session != null and world != null and ai != null and port != null and queue != null and rng != null,
		"production composition owns the queue query and existing authorities"
	)
	session.configure({"ruleset_id": "v0.6"}, {})
	session.begin_session({
		"session_id": "ai-card-queue-focused",
		"scenario_id": "focused",
		"seed": 131,
		"player_count": 3,
	})
	world.restore({
		"players": [
			_player("Human", false),
			_player("AI-A", true),
			_player("AI-B", true),
		],
		"districts": [{
			"region_id": "region:test",
			"name": "测试区域",
			"terrain": "land",
			"destroyed": false,
		}],
		"game_time": 9.0,
	}, true)
	var active_entry := _entry(2, 7001, 0)
	var current_entry := _entry(1, 7002, -1)
	var next_entry := _entry(1, 7003, 2)
	queue.replace_active_entry(active_entry)
	queue.replace_current_queue([current_entry])
	queue.replace_next_queue([next_entry])
	var capabilities := ai.get("_ai_card_queue_capabilities") as Dictionary
	var actor_capability := capabilities.get(1) as AiCardQueueCapability
	var rival_capability := capabilities.get(2) as AiCardQueueCapability
	_expect(
		capabilities.size() == 2 and not capabilities.has(0)
			and actor_capability != null and rival_capability != null,
		"composition issues queue capabilities only to current AI seats"
	)
	var world_before := world.to_save_data()
	var queue_before := _queue_state(queue)
	var rng_before := rng.capture_plan_checkpoint()
	var public_snapshot := port.public_resolution_snapshot()
	var public_text := JSON.stringify(public_snapshot)
	var public_active := public_snapshot.get("active", {}) as Dictionary
	var active_facts := public_active.get("card_facts", {}) as Dictionary
	_expect(
		int(public_snapshot.get("current_count", -1)) == 1
			and int(public_snapshot.get("next_count", -1)) == 1
			and bool(public_snapshot.get("active_present", false)),
		"public projection preserves queue counts and active presence"
	)
	_expect(
		int(public_active.get("resolution_id", -1)) == 7001
			and str(public_active.get("card_name", "")) == "轨道齐射1"
			and str(active_facts.get("name", "")) == "轨道齐射1",
		"public projection exposes stable public card identity and definition facts"
	)
	_expect(
		int(public_active.get("target_player", -1)) == 0
			and bool(public_active.get("counterable", false)),
		"public active projection exposes its legal target and counterable state"
	)
	_expect(
		not _contains_any_key(public_snapshot, [
			"player_index",
			"slot_index",
			"actor_index",
			"actor_id",
			"ai_utility_score",
			"ai_reason",
			"target_owner",
		]) and not public_text.contains("AI_PRIVATE_REASON"),
		"public projection strips source identity and AI-private diagnostics recursively"
	)
	var actor_snapshot := port.private_actor_submission_snapshot(actor_capability, 1)
	var rival_snapshot := port.private_actor_submission_snapshot(rival_capability, 2)
	_expect(
		bool(actor_snapshot.get("has_current_submission", false))
			and int(actor_snapshot.get("current_resolution_id", -1)) == 7002
			and bool(actor_snapshot.get("has_next_submission", false))
			and int(actor_snapshot.get("next_resolution_id", -1)) == 7003
			and not bool(actor_snapshot.get("has_active_submission", true)),
		"actor capability sees only its own current and next submission identities"
	)
	_expect(
		bool(rival_snapshot.get("has_active_submission", false))
			and int(rival_snapshot.get("active_resolution_id", -1)) == 7001
			and not bool(rival_snapshot.get("has_current_submission", true)),
		"active submission identity is visible only to its owning AI capability"
	)
	_expect(
		port.private_actor_submission_snapshot(rival_capability, 1).is_empty()
			and port.private_actor_submission_snapshot(AiCardQueueCapability.new(), 1).is_empty()
			and port.private_actor_submission_snapshot(actor_capability, 0).is_empty(),
		"rival, forged, and human capability queries fail closed"
	)
	var detached_public := public_snapshot.duplicate(true)
	(detached_public.get("active", {}) as Dictionary)["card_name"] = "MUTATED_COPY"
	var detached_private := actor_snapshot.duplicate(true)
	detached_private["current_resolution_id"] = 1
	_expect(
		str((port.public_resolution_snapshot().get("active", {}) as Dictionary).get("card_name", "")) == "轨道齐射1"
			and int(port.private_actor_submission_snapshot(actor_capability, 1).get(
				"current_resolution_id",
				-1
			)) == 7002,
		"public and actor-private queue snapshots are detached"
	)
	_expect(
		world.to_save_data() == world_before
			and _queue_state(queue) == queue_before
			and rng.capture_plan_checkpoint() == rng_before,
		"queue queries perform zero world or queue mutation and consume zero RNG"
	)
	var legacy_current := current_entry.duplicate(true)
	legacy_current.erase("resolution_id")
	legacy_current.erase("queued_order")
	queue.replace_current_queue([legacy_current])
	var legacy_snapshot := port.private_actor_submission_snapshot(actor_capability, 1)
	_expect(
		bool(legacy_snapshot.get("has_current_submission", false))
			and int(legacy_snapshot.get("current_resolution_id", 0)) == -1,
		"legacy ID-less entries still block duplicate AI submission"
	)
	queue.replace_current_queue([current_entry])
	var old_capability := actor_capability
	world.replace_players(world.players.duplicate(true), true)
	capabilities = ai.get("_ai_card_queue_capabilities") as Dictionary
	actor_capability = capabilities.get(1) as AiCardQueueCapability
	_expect(
		actor_capability != null and actor_capability != old_capability
			and port.private_actor_submission_snapshot(old_capability, 1).is_empty()
			and not port.private_actor_submission_snapshot(actor_capability, 1).is_empty(),
		"roster replacement revokes and reissues queue capabilities"
	)
	var unavailable_players := world.players.duplicate(true)
	var unavailable_actor := (unavailable_players[1] as Dictionary).duplicate(true)
	unavailable_actor["slots"] = [{
		"name": "轨道融资1",
		"kind": "cash_gain",
		"cooldown_left": 0.0,
		"lock_left": 0.0,
		"queued_for_resolution": false,
	}]
	unavailable_players[1] = unavailable_actor
	world.players = unavailable_players
	var current_capabilities := capabilities.duplicate()
	ai.set_card_queue_query_port(port, {})
	var unavailable_rng_before := rng.capture_plan_checkpoint()
	var unavailable_candidates: Array = ai.call("_ai_card_play_candidates", 1)
	_expect(
		bool(ai.call("_ai_has_current_card_submission", 1))
			and unavailable_candidates.is_empty()
			and rng.capture_plan_checkpoint() == unavailable_rng_before,
		"unavailable queue capability fails closed before candidates or RNG"
	)
	ai.set_card_queue_query_port(port, current_capabilities)
	var ai_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_runtime_controller.gd")
	var submission_source := FileAccess.get_file_as_string(
		"res://scripts/runtime/card_play_submission_runtime_controller.gd"
	)
	for forbidden in [
		"_card_resolution_current_queue",
		"_card_resolution_next_queue",
		"_store_card_resolution_entry",
		"_queued_card_entry_index_for_player",
		"_next_batch_card_entry_index_for_player",
		"_call_world(&\"_queue_monster_card_as_counter\"",
	]:
		_expect(not ai_source.contains(forbidden), "AI source retires %s" % forbidden)
	_expect(
		submission_source.contains("func submit_monster_counter_conversion(")
			and not submission_source.contains("ai_private_metadata")
			and not submission_source.contains("entry_context.merge(private_metadata"),
		"typed submission owns conversion without copying AI diagnostics into the queue"
	)
	var debug := port.debug_snapshot()
	_expect(
		bool(debug.get("port_ready", false))
			and int(debug.get("actor_scoped_capability_count", 0)) == 2
			and not bool(debug.get("returns_rival_submission_identity", true))
			and not bool(debug.get("returns_private_entry", true))
			and not bool(debug.get("returns_ai_metadata", true))
			and not bool(debug.get("mutates_queue", true))
			and not bool(debug.get("consumes_rng", true))
			and not bool(debug.get("references_main", true)),
		"debug evidence records actor scope, zero mutation, zero RNG, and zero Main"
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


func _entry(player_index: int, resolution_id: int, target_player: int) -> Dictionary:
	return {
		"player_index": player_index,
		"slot_index": 0,
		"resolution_id": resolution_id,
		"queued_order": resolution_id,
		"selected_district": 0,
		"selected_trade_product": "环晶电池",
		"target_player": target_player,
		"target_owner": target_player,
		"ai_utility_score": 999,
		"ai_reason": "AI_PRIVATE_REASON",
		"skill": {
			"name": "轨道齐射1",
			"kind": "global_barrage",
			"global_barrage_damage": 2,
			"global_barrage_route_damage": 1,
			"global_barrage_target_count": 2,
		},
	}


func _queue_state(queue: CardResolutionQueueRuntimeService) -> Dictionary:
	return {
		"active": queue.active_entry(),
		"current": queue.current_queue(),
		"next": queue.next_queue(),
		"debug": queue.debug_snapshot(),
	}


func _contains_any_key(value: Variant, forbidden: Array) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if forbidden.has(str(key_variant)) \
					or _contains_any_key((value as Dictionary)[key_variant], forbidden):
				return true
	elif value is Array:
		for item in value as Array:
			if _contains_any_key(item, forbidden):
				return true
	return false


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("AI card queue query port passed (%d checks)." % _checks)
		print("AI_CARD_QUEUE_QUERY_PORT_COMPLETE")
		quit(0)
		return
	push_error("AI card queue query port failures:\n- " + "\n- ".join(_failures))
	quit(1)
