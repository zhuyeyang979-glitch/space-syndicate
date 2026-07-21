extends Node

const MONSTER_SCENE := preload("res://scenes/runtime/MonsterRuntimeController.tscn")
const PORT_SCENE := preload("res://scenes/runtime/MonsterWagerCashCommitmentQueryPort.tscn")
const BATTLE_LIFECYCLE_POLICY := preload("res://scripts/runtime/monster_battle_lifecycle_policy_v06.gd")

var _checks := 0
var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := WorldSessionState.new()
	world.players = [{"id": "player-0", "cash": 1000, "cash_cents": 100000, "eliminated": false}]
	add_child(world)
	var bridge := MonsterRuntimeWorldBridge.new()
	bridge.set_world_session_state(world)
	add_child(bridge)
	var monster := MONSTER_SCENE.instantiate() as MonsterRuntimeController
	monster.set_world_bridge(bridge)
	add_child(monster)
	monster.active_monster_wagers = [{
		"wager_id": 1, "settlement_revision": 1, "base_percent": 5,
		"competitors": [{"side": "a", "name": "A", "slot": 0, "uid": 1, "damage": 3}, {"side": "b", "name": "B", "slot": 1, "uid": 2, "damage": 2}],
		"damage_a": 3, "damage_b": 2, "bets": {}, "public_bets": [], "historical_public_pool": 0,
		"eligible_player_indices": [0], "opening_cash_units_by_player": {"0": 1000}, "public_player_ids_by_index": {"0": "player.0"},
		"lifecycle_schema_version": BATTLE_LIFECYCLE_POLICY.SCHEMA_VERSION,
		"lifecycle_phase": BATTLE_LIFECYCLE_POLICY.PHASE_DECISION,
		"lifecycle_revision": 1,
		"decision_remaining_seconds": 15.0,
		"battle_limit_seconds": 60.0,
		"battle_remaining_seconds": 60.0,
		"locked_competitor_uids": [1, 2],
		"battle_roster_fingerprint": BATTLE_LIFECYCLE_POLICY.roster_fingerprint([{"side": "a", "name": "A", "slot": 0, "uid": 1, "damage": 3}, {"side": "b", "name": "B", "slot": 1, "uid": 2, "damage": 2}]),
		"opening_attack_applied": true,
		"decision_open": true,
		"resolved": false,
	}]
	monster.set("_monster_wager_settlement_revision", 1)
	var port := PORT_SCENE.instantiate() as MonsterWagerCashCommitmentQueryPort
	add_child(port)
	_expect(bool(port.configure(world, monster).get("configured", false)), "formal port configures")
	var snapshot := port.private_cash_availability_snapshot(0)
	_expect(int(snapshot.get("total_cents", -1)) == 100000, "ledger cash stays in WorldSessionState")
	_expect(int(snapshot.get("reserved_cents", -1)) == 5000, "base commitment comes from MonsterRuntimeController")
	_expect(int(snapshot.get("available_cents", -1)) == 95000, "spendable cash is derived")
	_expect(bool(port.authorize_debit_cents(0, 95000).get("authorized", false)), "exact available debit is accepted")
	_expect(str(port.authorize_debit_cents(0, 95001).get("reason_code", "")) == "cash_reserved_for_monster_wager", "over-available debit is rejected")
	var debug := port.debug_snapshot()
	_expect(not bool(debug.get("stores_cash", true)), "port stores no cash")
	_expect(not bool(debug.get("stores_commitments", true)), "port stores no commitments")
	_expect(not bool(debug.get("public_snapshot_provider", true)), "port is private development/runtime infrastructure")
	print("MONSTER_WAGER_CASH_COMMITMENT_QUERY_PORT_BENCH|status=%s|checks=%d|failures=%d|reserved_cents=%d|available_cents=%d" % [
		"PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size(), int(snapshot.get("reserved_cents", -1)), int(snapshot.get("available_cents", -1)),
	])
	# Keep the formal scene alive briefly so Godot MCP can inspect the real
	# runtime output and error channel before the Bench exits on its own.
	var hold_seconds := 0.1 if DisplayServer.get_name() == "headless" else 30.0
	await get_tree().create_timer(hold_seconds).timeout
	get_tree().quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(label)
	push_error("MONSTER_WAGER_CASH_COMMITMENT_QUERY_PORT_BENCH: %s" % label)
