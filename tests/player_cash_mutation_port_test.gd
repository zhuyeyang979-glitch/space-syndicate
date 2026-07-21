extends SceneTree

const WORLD_SCENE := preload("res://scenes/runtime/WorldSessionState.tscn")
const MONSTER_SCENE := preload("res://scenes/runtime/MonsterRuntimeController.tscn")
const QUERY_SCENE := preload("res://scenes/runtime/MonsterWagerCashCommitmentQueryPort.tscn")
const MUTATION_SCENE := preload("res://scenes/runtime/PlayerCashMutationPort.tscn")
const BATTLE_LIFECYCLE_POLICY := preload("res://scripts/runtime/monster_battle_lifecycle_policy_v06.gd")

var _checks := 0
var _failures := 0
var _host: Node
var _world: WorldSessionState
var _monster: MonsterRuntimeController
var _query: MonsterWagerCashCommitmentQueryPort
var _port: PlayerCashMutationPort


func _init() -> void:
	_build_fixture()
	_test_cash_cents_parity_and_exact_once()
	_test_commitment_and_negative_balance_guard()
	_test_product_market_and_gdp_counters()
	_test_role_monster_upgrade_reward()
	_test_save_roundtrip_preserves_exact_once()
	_test_owner_and_privacy_boundary()
	print("PLAYER_CASH_MUTATION_PORT %d/%d" % [_checks - _failures, _checks])
	_host.free()
	quit(0 if _failures == 0 else 1)


func _build_fixture() -> void:
	_host = Node.new()
	root.add_child(_host)
	_world = WORLD_SCENE.instantiate() as WorldSessionState
	_world.players = [_player(1000, 100055)]
	_host.add_child(_world)
	var monster_bridge := MonsterRuntimeWorldBridge.new()
	monster_bridge.set_world_session_state(_world)
	_host.add_child(monster_bridge)
	_monster = MONSTER_SCENE.instantiate() as MonsterRuntimeController
	_monster.set_world_bridge(monster_bridge)
	_host.add_child(_monster)
	_query = QUERY_SCENE.instantiate() as MonsterWagerCashCommitmentQueryPort
	_host.add_child(_query)
	_expect(bool(_query.configure(_world, _monster).get("configured", false)), "the existing query port binds the two authoritative owners")
	_port = MUTATION_SCENE.instantiate() as PlayerCashMutationPort
	_host.add_child(_port)
	_expect(bool(_port.configure(_world, _query).get("configured", false)), "the mutation port binds WorldSessionState and the existing commitment boundary")


func _test_cash_cents_parity_and_exact_once() -> void:
	_seed_wagers([])
	var first := _port.commit_product_market_cash_delta(
		"market:position.1:open", 0, -10, "商品期货", "环晶电池", "futures_open", 0, 7
	)
	_expect(bool(first.get("committed", false)) and not bool(first.get("replayed", true)), "a first typed market debit commits")
	var player := _player_state()
	_expect(int(player.get("cash_cents", -1)) == 99055 and int(player.get("cash", -1)) == 990, "the exact cents ledger and whole-unit mirror remain coherent without losing the fractional remainder")
	var history_size := (player.get("cash_history", []) as Array).size()
	var event_size := (player.get("economic_ledger", []) as Array).size()
	var transaction_size := (player.get("v06_transaction_ledger", []) as Array).size()
	var replay := _port.commit_product_market_cash_delta(
		"market:position.1:open", 0, -10, "商品期货", "环晶电池", "futures_open", 0, 7
	)
	player = _player_state()
	_expect(bool(replay.get("committed", false)) and bool(replay.get("replayed", false)), "an identical transaction replays its authoritative receipt")
	_expect(
		int(player.get("cash_cents", -1)) == 99055
			and (player.get("cash_history", []) as Array).size() == history_size
			and (player.get("economic_ledger", []) as Array).size() == event_size
			and (player.get("v06_transaction_ledger", []) as Array).size() == transaction_size,
		"an exact-once replay produces zero cash, history, event, or journal side effects"
	)
	var conflict := _port.commit_product_market_cash_delta(
		"market:position.1:open", 0, -9, "商品期货", "环晶电池", "futures_open", 0, 7
	)
	_expect(not bool(conflict.get("committed", true)) and str(conflict.get("reason_code", "")) == "cash_transaction_id_conflict", "the same transaction ID cannot authorize different terms")


func _test_commitment_and_negative_balance_guard() -> void:
	_reset_player(1000, 100000)
	_seed_wagers([_wager(20, 20)])
	var denied := _port.commit_product_market_cash_delta(
		"market:position.2:open", 0, -801, "商品期货", "星露莓", "futures_open"
	)
	_expect(not bool(denied.get("committed", true)) and str(denied.get("reason_code", "")) == "cash_reserved_for_monster_wager", "ordinary market spending cannot consume the frozen 20-percent wager commitment")
	_expect(int(_player_state().get("cash_cents", -1)) == 100000, "a commitment rejection is atomic")
	var exact_available := _port.commit_product_market_cash_delta(
		"market:position.2:open:available", 0, -800, "商品期货", "星露莓", "futures_open"
	)
	_expect(bool(exact_available.get("committed", false)) and int(_player_state().get("cash_cents", -1)) == 20000, "the uncommitted balance can be spent exactly while reserved wager cash remains intact")
	_reset_player(1000, 100000)
	_seed_wagers([])
	var negative := _port.commit_city_gdp_derivative_cash_delta(
		"gdp:position.9:open", 0, -1001, "城市期权", "region.3", "风暴湾", "derivative_open"
	)
	_expect(not bool(negative.get("committed", true)), "a typed debit cannot create a negative cash balance")
	_expect(int(_player_state().get("cash_cents", -1)) == 100000, "a negative-balance rejection leaves both cash fields unchanged")


func _test_product_market_and_gdp_counters() -> void:
	_reset_player(100, 10000)
	_seed_wagers([])
	var market := _port.commit_product_market_cash_delta(
		"market:position.3:settle", 0, 50, "商品期货", "钛壳贝", "futures_expiry", 30, 8
	)
	_expect(bool(market.get("committed", false)) and int(market.get("income_amount", -1)) == 30, "market settlement preserves the authored income classification")
	var player := _player_state()
	_expect(int(player.get("cash_cents", -1)) == 15000 and int(player.get("total_card_income", -1)) == 30, "market cash and card-income counters commit atomically")
	_expect((player.get("economic_ledger", []) as Array).size() == 2, "market settlement keeps the income and non-income economic events")
	var gdp := _port.commit_city_gdp_derivative_cash_delta(
		"gdp:position.4:settle", 0, 40, "城市GDP期权", "region.4", "浮空港", "derivative_expiry", 25, 8
	)
	player = _player_state()
	_expect(bool(gdp.get("committed", false)) and int(player.get("cash_cents", -1)) == 19000, "GDP derivative settlement uses the same typed cash authority")
	_expect(int(player.get("total_card_income", -1)) == 55 and (player.get("economic_ledger", []) as Array).size() == 4, "GDP derivative income classification and history remain exact")


func _test_role_monster_upgrade_reward() -> void:
	_reset_player(200, 20000)
	_seed_wagers([_wager(30, 5)])
	var reward := _port.commit_role_monster_upgrade_cash(
		"monster:uid.401:rank.2:role-cash", 0, 160, "role.star-whale", "星鲸餐饮垄断", 401, "星鲸", 1, 2, 9
	)
	var player := _player_state()
	_expect(bool(reward.get("committed", false)) and int(player.get("cash_cents", -1)) == 36000, "role income is credited even while an unresolved wager commitment exists")
	_expect(int(player.get("total_card_income", -1)) == 160 and int(player.get("total_role_income", -1)) == 160, "monster-upgrade reward preserves both existing role income counters")
	var replay := _port.commit_role_monster_upgrade_cash(
		"monster:uid.401:rank.2:role-cash", 0, 160, "role.star-whale", "星鲸餐饮垄断", 401, "星鲸", 1, 2, 9
	)
	player = _player_state()
	_expect(bool(replay.get("replayed", false)) and int(player.get("cash_cents", -1)) == 36000 and int(player.get("total_role_income", -1)) == 160, "role reward retry is exact-once")


func _test_save_roundtrip_preserves_exact_once() -> void:
	var saved := _world.to_save_data()
	var restored := WORLD_SCENE.instantiate() as WorldSessionState
	_host.add_child(restored)
	_expect(bool(restored.apply_save_data(saved).get("applied", false)), "the existing WorldSessionState save section restores the cash journal")
	var restored_query := QUERY_SCENE.instantiate() as MonsterWagerCashCommitmentQueryPort
	_host.add_child(restored_query)
	_expect(bool(restored_query.configure(restored, _monster).get("configured", false)), "the restored owner can use the same private commitment boundary")
	var restored_port := MUTATION_SCENE.instantiate() as PlayerCashMutationPort
	_host.add_child(restored_port)
	_expect(bool(restored_port.configure(restored, restored_query).get("configured", false)), "the stateless port needs no new save section")
	var replay := restored_port.commit_role_monster_upgrade_cash(
		"monster:uid.401:rank.2:role-cash", 0, 160, "role.star-whale", "星鲸餐饮垄断", 401, "星鲸", 1, 2, 9
	)
	var restored_player := (restored.players[0] as Dictionary)
	_expect(bool(replay.get("replayed", false)) and int(restored_player.get("cash_cents", -1)) == 36000 and int(restored_player.get("total_role_income", -1)) == 160, "save/load cannot replay an already committed role reward")


func _test_owner_and_privacy_boundary() -> void:
	var debug := _port.debug_snapshot()
	_expect(
		not bool(debug.get("stores_cash", true))
			and not bool(debug.get("stores_transaction_journal", true))
			and not bool(debug.get("stores_wager_commitments", true))
			and str(debug.get("cash_owner", "")) == "WorldSessionState",
		"the port owns no second cash balance, journal, or wager state"
	)
	_expect(not bool(debug.get("public_snapshot_provider", true)), "private cash mutation diagnostics are never a player-facing snapshot")
	var port_source := FileAccess.get_file_as_string("res://scripts/runtime/player_cash_mutation_port.gd")
	_expect(not port_source.contains("scripts/main.gd") and not port_source.contains("/root/Main") and not port_source.contains("current_scene"), "the typed port has no Main or scene-discovery fallback")
	var request := FileAccess.get_file_as_string("res://docs/integration_requests/P0-CASH-AUTHORITY-COMMITMENT-BOUNDARY.json")
	_expect(not request.is_empty(), "shared hot-file wiring is described through an integration request")


func _player(cash_units: int, cash_cents: int) -> Dictionary:
	return {
		"id": "player-0",
		"actor_id": "actor.player.0",
		"name": "玩家1",
		"cash": cash_units,
		"cash_cents": cash_cents,
		"cash_history": [cash_units],
		"economic_ledger": [],
		"v06_transaction_ledger": [],
		"total_card_income": 0,
		"total_role_income": 0,
		"eliminated": false,
	}


func _player_state() -> Dictionary:
	return (_world.players[0] as Dictionary).duplicate(true)


func _reset_player(cash_units: int, cash_cents: int) -> void:
	_world.players = [_player(cash_units, cash_cents)]


func _wager(wager_id: int, selected_percent: int) -> Dictionary:
	var competitors := [
		{"side": "a", "name": "怪兽A", "slot": 0, "uid": 100, "damage": 2},
		{"side": "b", "name": "怪兽B", "slot": 1, "uid": 101, "damage": 1},
	]
	var bets := {}
	if selected_percent > 0:
		var stake_units := int(floor(1000.0 * float(selected_percent) / 100.0))
		bets["0"] = {"player_index": 0, "side": "a", "stake": stake_units, "stake_percent": selected_percent, "forced": false}
	return {
		"wager_id": wager_id,
		"settlement_revision": wager_id,
		"base_percent": 5,
		"competitors": competitors,
		"damage_a": 2,
		"damage_b": 1,
		"bets": bets,
		"public_bets": [],
		"historical_public_pool": 0,
		"eligible_player_indices": [0],
		"opening_cash_units_by_player": {"0": 1000},
		"public_player_ids_by_index": {"0": "player.0"},
		"lifecycle_schema_version": BATTLE_LIFECYCLE_POLICY.SCHEMA_VERSION,
		"lifecycle_phase": BATTLE_LIFECYCLE_POLICY.PHASE_DECISION,
		"lifecycle_revision": 1,
		"decision_remaining_seconds": 15.0,
		"battle_limit_seconds": 60.0,
		"battle_remaining_seconds": 60.0,
		"locked_competitor_uids": [100, 101],
		"battle_roster_fingerprint": BATTLE_LIFECYCLE_POLICY.roster_fingerprint(competitors),
		"opening_attack_applied": true,
		"decision_open": true,
		"resolved": false,
	}


func _seed_wagers(wagers: Array) -> void:
	_monster.active_monster_wagers = wagers.duplicate(true)
	_monster.set("_monster_wager_settlement_revision", wagers.size())


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % label)
		return
	_failures += 1
	push_error("FAIL: %s" % label)
