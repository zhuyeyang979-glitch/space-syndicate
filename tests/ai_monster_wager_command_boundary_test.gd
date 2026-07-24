extends SceneTree

const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")

class FakeWorld:
	extends Node

	func _player_name(player_index: int) -> String:
		return "player-%d" % player_index

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var coordinator := COORDINATOR_SCENE.instantiate() as GameRuntimeCoordinator
	root.add_child(coordinator)
	await process_frame
	coordinator.process_mode = Node.PROCESS_MODE_DISABLED
	var session := coordinator.get_node_or_null("GameSessionRuntimeController") as GameSessionRuntimeController
	var world := coordinator.world_session_state()
	var monster := coordinator.get_node_or_null("MonsterRuntimeController") as MonsterRuntimeController
	var monster_bridge := coordinator.get_node_or_null("MonsterRuntimeWorldBridge") as MonsterRuntimeWorldBridge
	_expect(session != null and world != null and monster != null and monster_bridge != null, "production owners are available")
	monster.set_world_bridge(monster_bridge)
	var fake_world := FakeWorld.new()
	coordinator.add_child(fake_world)
	monster_bridge.bind_world(fake_world)
	session.configure({"ruleset_id": "v0.6"}, {})
	session.begin_session({"session_id": "ai-wager-command", "scenario_id": "focused", "seed": 91, "player_count": 2})
	world.replace_players([
		_player("human", false),
		_player("ai", true),
	], true)
	_seed_wager(monster)
	var command := {
		"source_context": "ai",
		"command_id": "ai-wager-command:91:7:1",
		"expected_settlement_revision": 7,
	}
	var first := monster.submit_monster_wager_response(91, 1, &"a", 5, false, command)
	var bet_count := _bet_count(monster)
	var replay := monster.submit_monster_wager_response(91, 1, &"a", 5, false, command)
	_expect(bool(first.get("applied", false)) and bet_count == 1, "revision-bound AI wager command applies once")
	_expect(bool(replay.get("accepted", false)) and not bool(replay.get("applied", true)) and bool(replay.get("idempotent_replay", false)) and _bet_count(monster) == 1, "same command replays without a second bet")
	var collision_command := command.duplicate(true)
	var collision := monster.submit_monster_wager_response(91, 1, &"b", 5, false, collision_command)
	_expect(not bool(collision.get("accepted", true)) and bool(collision.get("request_id_collision", false)) and _bet_count(monster) == 1, "same command ID with different payload fails closed")
	_seed_wager(monster)
	var stale_command := {
		"source_context": "ai",
		"command_id": "ai-wager-command:91:6:1",
		"expected_settlement_revision": 6,
	}
	var stale := monster.submit_monster_wager_response(91, 1, &"a", 5, false, stale_command)
	_expect(not bool(stale.get("applied", true)) and str(stale.get("reason_code", "")) == "monster_wager_settlement_revision_stale" and _bet_count(monster) == 0, "stale settlement revision causes zero mutation")
	var arbitrary_metadata := monster.submit_monster_wager_response(91, 1, &"a", 5, false, {"ai_wager_score": 999})
	_expect(not bool(arbitrary_metadata.get("applied", true)) and str(arbitrary_metadata.get("reason_code", "")) == "monster_wager_metadata_invalid" and _bet_count(monster) == 0, "untyped AI planning metadata cannot cross into the owner")
	coordinator.queue_free()
	await process_frame
	_finish()


func _player(actor_id: String, is_ai: bool) -> Dictionary:
	return {
		"id": actor_id,
		"actor_id": "actor:%s" % actor_id,
		"name": actor_id,
		"is_ai": is_ai,
		"seat_type": "ai" if is_ai else "human",
		"eliminated": false,
		"cash": 100,
		"cash_cents": 10000,
		"ai_profile": {},
		"ai_memory": {},
	}


func _seed_wager(monster: MonsterRuntimeController) -> void:
	monster.active_monster_wagers = [{
		"wager_id": 91,
		"settlement_revision": 7,
		"base_percent": 5,
		"competitors": [
			{"side": "a", "name": "A", "slot": 0, "uid": 101, "damage": 0},
			{"side": "b", "name": "B", "slot": 1, "uid": 102, "damage": 0},
		],
		"damage_a": 0,
		"damage_b": 0,
		"bets": {},
		"public_bets": [],
		"eligible_player_indices": [0, 1],
		"opening_cash_units_by_player": {"0": 100, "1": 100},
		"decision_open": true,
		"resolved": false,
	}]
	monster.monster_wager_sequence = 91
	monster.set("_monster_wager_settlement_revision", 7)


func _bet_count(monster: MonsterRuntimeController) -> int:
	if monster.active_monster_wagers.is_empty():
		return 0
	return ((monster.active_monster_wagers[0] as Dictionary).get("bets", {}) as Dictionary).size()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("AI monster wager command boundary passed (%d checks)." % _checks)
		print("AI_MONSTER_WAGER_COMMAND_BOUNDARY_COMPLETE")
		quit(0)
		return
	push_error("AI monster wager command boundary failures:\n- " + "\n- ".join(_failures))
	quit(1)
