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
	var port := coordinator.get_node_or_null("AiCardHandQueryPort") as AiCardHandQueryPort
	var rng := coordinator.get_node_or_null("RunRngService") as RunRngService
	_expect(session != null and world != null and ai != null and port != null and rng != null, "production composition owns the hand query and existing authorities")
	session.configure({"ruleset_id": "v0.6"}, {})
	session.begin_session({"session_id": "ai-card-hand-focused", "scenario_id": "focused", "seed": 113, "player_count": 3})
	world.restore({
		"players": [
			_player("Human", false, "HUMAN_HAND", 999999),
			_player("AI-A", true, "AI_A_HAND", 700),
			_player("AI-B", true, "AI_B_HAND", 800),
		],
		"districts": [],
		"game_time": 4.0,
	}, true)
	var capabilities := ai.get("_ai_card_hand_capabilities") as Dictionary
	var actor_capability := capabilities.get(1) as AiCardHandCapability
	var rival_capability := capabilities.get(2) as AiCardHandCapability
	_expect(capabilities.size() == 2 and not capabilities.has(0) and actor_capability != null and rival_capability != null, "composition issues hand capabilities only to current AI seats")
	var world_before := world.to_save_data()
	var rng_before := rng.capture_plan_checkpoint()
	var snapshot := port.private_hand_snapshot(actor_capability, 1)
	var text := JSON.stringify(snapshot)
	_expect(text.contains("AI_A_HAND") and not text.contains("AI_B_HAND") and not text.contains("HUMAN_HAND"), "actor snapshot contains only its own private hand")
	_expect(not snapshot.has("cash") and not text.contains("\"cash\""), "hand projection exposes no cash")
	_expect(port.private_hand_snapshot(rival_capability, 1).is_empty() and port.private_hand_snapshot(AiCardHandCapability.new(), 1).is_empty() and port.private_hand_snapshot(actor_capability, 0).is_empty(), "rival, forged, and human capability queries fail closed")
	var detached := snapshot.duplicate(true)
	((detached.get("slots", []) as Array)[0] as Dictionary)["name"] = "MUTATED_COPY"
	_expect(not JSON.stringify(port.private_hand_snapshot(actor_capability, 1)).contains("MUTATED_COPY"), "hand snapshots are detached")
	_expect(world.to_save_data() == world_before and rng.capture_plan_checkpoint() == rng_before, "hand queries perform zero mutation and consume zero RNG")
	_expect(int(snapshot.get("counted_hand_size", -1)) == 1 and (snapshot.get("discardable_slots", []) as Array) == [0] and is_equal_approx(float(snapshot.get("action_cooldown", -1.0)), 0.0), "projection uses the existing CardFlow counted/discardable semantics")
	var old_capability := actor_capability
	world.replace_players(world.players.duplicate(true), true)
	capabilities = ai.get("_ai_card_hand_capabilities") as Dictionary
	actor_capability = capabilities.get(1) as AiCardHandCapability
	_expect(actor_capability != null and actor_capability != old_capability and port.private_hand_snapshot(old_capability, 1).is_empty() and not port.private_hand_snapshot(actor_capability, 1).is_empty(), "roster replacement revokes and reissues hand capabilities")
	var controller_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_runtime_controller.gd")
	for function_name in ["_ai_card_play_candidates", "_ai_counter_response_candidates", "_ai_queue_counter_response_candidate", "_ai_discard_keep_value", "_ai_discard_slot_for_purchase"]:
		var body := _function_body(controller_source, function_name)
		_expect(body.contains("_ai_card_hand_snapshot") and not body.contains("players["), "%s uses no whole-player hand access" % function_name)
	var debug := port.debug_snapshot()
	_expect(bool(debug.get("port_ready", false)) and int(debug.get("actor_scoped_capability_count", 0)) == 2 and not bool(debug.get("returns_cash", true)) and not bool(debug.get("returns_rival_hand", true)) and not bool(debug.get("references_main", true)), "debug evidence records actor-private zero-Main scope")
	coordinator.queue_free()
	await process_frame
	_finish()


func _player(name: String, is_ai: bool, marker: String, cash: int) -> Dictionary:
	return {
		"id": name.hash(),
		"name": name,
		"seat_type": "ai" if is_ai else "human",
		"is_ai": is_ai,
		"cash": cash,
		"action_cooldown": 0.0,
		"slots": [{
			"name": marker,
			"runtime_instance_id": "instance:%s" % marker,
			"machine": {"card_id": marker, "family_id": marker, "rank": 1, "counts_toward_hand_limit": true},
		}],
		"discard": ["discard:%s" % marker],
		"discarded_cards": ["discarded:%s" % marker],
		"ai_profile": {},
		"ai_memory": {},
	}


func _function_body(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return ""
	var next := source.find("\nfunc ", start + 1)
	return source.substr(start) if next < 0 else source.substr(start, next - start)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("AI card hand query port passed (%d checks)." % _checks)
		print("AI_CARD_HAND_QUERY_PORT_COMPLETE")
		quit(0)
		return
	push_error("AI card hand query port failures:\n- " + "\n- ".join(_failures))
	quit(1)
