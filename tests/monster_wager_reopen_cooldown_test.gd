extends SceneTree

const MONSTER_SCENE := preload("res://scenes/runtime/MonsterRuntimeController.tscn")
const RNG_SCENE := preload("res://scenes/runtime/RunRngService.tscn")

class FakeWorld:
	extends Node

	func _ruleset_timing_seconds(rule_id: StringName) -> float:
		return 20.0 if rule_id == &"monster_wager_reopen_cooldown_seconds" else 0.0

	func _entity_world_position(entity: Dictionary) -> Vector2:
		return entity.get("world_position", Vector2.ZERO) as Vector2

	func _ai_runtime_call(_method_name: StringName, _arguments: Array = []) -> Variant:
		return null

	func _player_name(player_index: int) -> String:
		return "玩家%d" % player_index

	func _limited_name_list(names: Array, limit: int = 6, empty_text: String = "无") -> String:
		return empty_text if names.is_empty() else "、".join(names.slice(0, mini(limit, names.size())))

	func _record_player_economic_event(_player_index: int, _kind: String, _label: String, _amount: int, _detail: String = "") -> void:
		pass

	func _record_player_cash_snapshot(_player_index: int) -> void:
		pass

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node.new()
	root.add_child(host)
	var world := WorldSessionState.new()
	world.players = [
		{"id": "player-0", "name": "玩家0", "cash": 1000, "cash_cents": 100000, "eliminated": false},
		{"id": "player-1", "name": "玩家1", "cash": 1000, "cash_cents": 100000, "eliminated": false},
	]
	world.game_time = 100.0
	host.add_child(world)
	var fake_world := FakeWorld.new()
	host.add_child(fake_world)
	var rng := RNG_SCENE.instantiate() as RunRngService
	rng.seed = 71
	host.add_child(rng)
	var bridge := MonsterRuntimeWorldBridge.new()
	bridge.set_world_session_state(world)
	bridge.set_rng_service(rng)
	bridge.bind_world(fake_world)
	host.add_child(bridge)
	var monsters := MONSTER_SCENE.instantiate() as MonsterRuntimeController
	monsters.set_world_bridge(bridge)
	host.add_child(monsters)
	_expect(monsters != null, "real MonsterRuntimeController is available without a Main compatibility fixture")

	var cooldown := float(fake_world._ruleset_timing_seconds(&"monster_wager_reopen_cooldown_seconds"))
	_expect(is_equal_approx(cooldown, 20.0), "ruleset owns a 20-second wager reopen cooldown")
	var actor_a := {"slot": 0, "uid": 101, "name": "怪兽A", "position": 0, "world_position": Vector2(10.0, 10.0), "down": false}
	var actor_b := {"slot": 1, "uid": 102, "name": "怪兽B", "position": 0, "world_position": Vector2(20.0, 10.0), "down": false}
	monsters.set("auto_monsters", [actor_a, actor_b])
	monsters.set("active_monster_wagers", [])
	monsters.set("resolved_monster_wager_history", [])

	var wager_id := int(monsters.call("_open_monster_wager_for_pair", 0, 1, "QA cooldown"))
	_expect(wager_id > 0, "first eligible monster wager opens")
	_expect(bool(monsters.call("_close_monster_wager_decision_window", 0, "QA lifecycle cooldown")), "15-second decision owner transitions into battle lifecycle")
	monsters.tick_battle_lifecycles(60.0)
	var history: Array = monsters.get("resolved_monster_wager_history")
	_expect(history.size() == 1 and is_equal_approx(float((history[0] as Dictionary).get("resolved_at", -1.0)), 100.0), "60-second battle lifecycle records the authoritative reopen anchor")
	_expect(int(monsters.call("_open_monster_wager_for_pair", 0, 1, "QA immediate reopen")) == -1, "immediate serial wager is blocked")

	world.game_time = 100.0 + cooldown - 0.001
	_expect(int(monsters.call("_open_monster_wager_for_pair", 0, 1, "QA boundary before")) == -1, "half-open cooldown remains active immediately before its boundary")
	world.game_time = 100.0 + cooldown
	_expect(int(monsters.call("_open_monster_wager_for_pair", 0, 1, "QA boundary")) > wager_id, "a new wager may open exactly at the cooldown boundary")
	_expect(not (history[0] as Dictionary).has("reopen_cooldown_remaining"), "cooldown is derived from existing history without duplicate mutable state")

	root.remove_child(host)
	host.free()
	print("MONSTER_WAGER_REOPEN_COOLDOWN_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error(message)
