extends Node

const BATTLE_LIFECYCLE_POLICY := preload("res://scripts/runtime/monster_battle_lifecycle_policy_v06.gd")

@onready var world: WorldSessionState = $WorldSessionState
@onready var monster_bridge: MonsterRuntimeWorldBridge = $MonsterRuntimeWorldBridge
@onready var monster: MonsterRuntimeController = $MonsterRuntimeController
@onready var query: MonsterWagerCashCommitmentQueryPort = $MonsterWagerCashCommitmentQueryPort
@onready var port: PlayerCashMutationPort = $PlayerCashMutationPort

var _checks := 0
var _failures := 0
var _identity: SimulationStateIdentity
var _audit: SimulationDeterminismAudit
var _authority: SimulationMutationAuthority


func _ready() -> void:
	world.players = [{
		"id": "player-0", "actor_id": "actor.player.0", "name": "玩家1",
		"cash": 1000, "cash_cents": 100000, "cash_history": [1000],
		"economic_ledger": [], "v06_transaction_ledger": [],
		"total_card_income": 0, "total_role_income": 0, "eliminated": false,
	}]
	monster_bridge.set_world_session_state(world)
	monster.set_world_bridge(monster_bridge)
	monster.active_monster_wagers = [_wager()]
	monster.set("_monster_wager_settlement_revision", 1)
	_check(bool(query.configure(world, monster).get("configured", false)), "query configured")
	_identity = SimulationStateIdentity.new()
	_audit = SimulationDeterminismAudit.new()
	_authority = SimulationMutationAuthority.new()
	add_child(_identity)
	add_child(_audit)
	add_child(_authority)
	_authority.bind_diagnostics(_identity, _audit)
	_check(bool(_authority.begin_step(1).get("opened", false)), "simulation mutation step active")
	_check(bool(port.configure(world, query, _authority).get("configured", false)), "mutation port configured")
	var denied := port.commit_product_market_cash_delta(
		"bench:market:denied", 0, -801, "商品期货", "环晶电池", "futures_open"
	)
	_check(not bool(denied.get("committed", true)), "committed wager cash rejected")
	var accepted := port.commit_product_market_cash_delta(
		"bench:market:accepted", 0, -800, "商品期货", "环晶电池", "futures_open"
	)
	_check(bool(accepted.get("committed", false)), "available market cash committed")
	var reward := port.commit_role_monster_upgrade_cash(
		"bench:monster.401:rank.2", 0, 160, "role.star-whale", "星鲸餐饮垄断", 401, "星鲸", 1, 2
	)
	_check(bool(reward.get("committed", false)), "role upgrade reward committed")
	var replay := port.commit_role_monster_upgrade_cash(
		"bench:monster.401:rank.2", 0, 160, "role.star-whale", "星鲸餐饮垄断", 401, "星鲸", 1, 2
	)
	_check(bool(replay.get("replayed", false)), "role upgrade retry replayed")
	var player := world.players[0] as Dictionary
	_check(int(player.get("cash", -1)) == 360 and int(player.get("cash_cents", -1)) == 36000, "cash mirrors remain coherent")
	_check(int(player.get("total_role_income", -1)) == 160, "role counter exact once")
	_check(not bool(port.debug_snapshot().get("stores_cash", true)), "port stores no cash")
	_check(_authority.recent_authorizations().size() == 3, "every first cash mutation is authorized once")
	print("PLAYER_CASH_MUTATION_PORT_BENCH %s %d/%d" % ["PASS" if _failures == 0 else "FAIL", _checks - _failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)


func _wager() -> Dictionary:
	var competitors := [
		{"side": "a", "name": "怪兽A", "slot": 0, "uid": 100, "damage": 2},
		{"side": "b", "name": "怪兽B", "slot": 1, "uid": 101, "damage": 1},
	]
	return {
		"wager_id": 1, "settlement_revision": 1, "base_percent": 5,
		"competitors": competitors, "damage_a": 2, "damage_b": 1,
		"bets": {"0": {"player_index": 0, "side": "a", "stake": 200, "stake_percent": 20, "forced": false}},
		"public_bets": [], "historical_public_pool": 0,
		"eligible_player_indices": [0], "opening_cash_units_by_player": {"0": 1000},
		"public_player_ids_by_index": {"0": "player.0"},
		"lifecycle_schema_version": BATTLE_LIFECYCLE_POLICY.SCHEMA_VERSION,
		"lifecycle_phase": BATTLE_LIFECYCLE_POLICY.PHASE_DECISION,
		"lifecycle_revision": 1, "decision_remaining_seconds": 15.0,
		"battle_limit_seconds": 60.0, "battle_remaining_seconds": 60.0,
		"locked_competitor_uids": [100, 101],
		"battle_roster_fingerprint": BATTLE_LIFECYCLE_POLICY.roster_fingerprint(competitors),
		"opening_attack_applied": true, "decision_open": true, "resolved": false,
	}


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % label)
		return
	_failures += 1
	push_error("FAIL: %s" % label)
