extends Node

const BATTLE_LIFECYCLE_POLICY := preload("res://scripts/runtime/monster_battle_lifecycle_policy_v06.gd")

class FakeWorld:
	extends Node
	func _player_name(player_index: int) -> String: return "玩家%d" % player_index
	func _limited_name_list(names: Array, limit: int = 6, empty_text: String = "无") -> String:
		return empty_text if names.is_empty() else "、".join(names.slice(0, mini(limit, names.size())))
	func _record_player_economic_event(_player_index: int, _kind: String, _label: String, _amount: int, _detail: String = "") -> void: pass
	func _record_player_cash_snapshot(_player_index: int) -> void: pass


func _ready() -> void:
	var monster := get_node("MonsterRuntimeController") as MonsterRuntimeController
	var world := WorldSessionState.new()
	world.name = "WorldSessionState"
	add_child(world)
	world.players = [
		{"name": "玩家0", "cash": 100, "cash_cents": 10000, "eliminated": false},
		{"name": "玩家1", "cash": 100, "cash_cents": 10000, "eliminated": false},
	]
	var fake := FakeWorld.new()
	add_child(fake)
	var bridge := MonsterRuntimeWorldBridge.new()
	bridge.set_world_session_state(world)
	bridge.bind_world(fake)
	add_child(bridge)
	monster.set_world_bridge(bridge)
	monster.set("_monster_wager_settlement_revision", 1)
	monster.active_monster_wagers = [{
		"wager_id": 1, "settlement_revision": 1, "base_percent": 5,
		"competitors": [
			{"side": "a", "name": "怪兽A", "slot": 0, "uid": 1, "damage": 4},
			{"side": "b", "name": "怪兽B", "slot": 1, "uid": 2, "damage": 1},
		],
		"damage_a": 4, "damage_b": 1, "bets": {}, "public_bets": [],
		"historical_public_pool": 10, "eligible_player_indices": [0, 1],
		"opening_cash_units_by_player": {"0": 100, "1": 100},
		"public_player_ids_by_index": {"0": "player.0", "1": "player.1"},
		"lifecycle_schema_version": BATTLE_LIFECYCLE_POLICY.SCHEMA_VERSION,
		"lifecycle_phase": BATTLE_LIFECYCLE_POLICY.PHASE_DECISION,
		"lifecycle_revision": 1,
		"decision_remaining_seconds": 15.0,
		"battle_limit_seconds": 60.0,
		"battle_remaining_seconds": 60.0,
		"locked_competitor_uids": [1, 2],
		"battle_roster_fingerprint": BATTLE_LIFECYCLE_POLICY.roster_fingerprint([
			{"side": "a", "name": "怪兽A", "slot": 0, "uid": 1, "damage": 4},
			{"side": "b", "name": "怪兽B", "slot": 1, "uid": 2, "damage": 1},
		]),
		"opening_attack_applied": true,
		"decision_open": true,
		"resolved": false,
	}]
	var view := monster.monster_wager_presentation_for_viewer(0)
	var first := monster.submit_monster_wager_response(1, 0, &"a", 5)
	var second := monster.submit_monster_wager_response(1, 1, &"b", 5)
	monster.tick_battle_lifecycles(60.0)
	var history: Dictionary = monster.resolved_wagers_snapshot().back() if not monster.resolved_wagers_snapshot().is_empty() else {}
	var receipt: Dictionary = history.get("settlement_public_receipt", {}) if history.get("settlement_public_receipt", {}) is Dictionary else {}
	var saved := monster.to_save_data()
	var checks := [
		float(view.get("seconds_total", 0.0)) == 15.0,
		(view.get("actions", []) as Array).size() == 32,
		bool(first.get("applied", false)),
		bool(second.get("applied", false)) and bool(second.get("decision_closed", false)),
		monster.active_wager_count() == 0,
		int(receipt.get("settlement_pool", -1)) == 30,
		int((world.players[0] as Dictionary).get("cash", -1)) == 125,
		int((world.players[1] as Dictionary).get("cash", -1)) == 95,
		monster.public_card_bid_monster_wager_pool == 0,
		(saved.get("monster_wager_settlement_terminal_journal", {}) as Dictionary).size() == 1,
	]
	var passed := 0
	for check: Variant in checks:
		if bool(check):
			passed += 1
	print("MONSTER_WAGER_SETTLEMENT_OWNER_BENCH PASS %d/%d" % [passed, checks.size()])
	if passed != checks.size():
		push_error("Monster wager production settlement bench failed")
	await get_tree().create_timer(5.0).timeout
	get_tree().quit(0 if passed == checks.size() else 1)
