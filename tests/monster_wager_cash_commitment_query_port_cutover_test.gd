extends SceneTree

const MONSTER_SCENE := preload("res://scenes/runtime/MonsterRuntimeController.tscn")
const PORT_SCENE := preload("res://scenes/runtime/MonsterWagerCashCommitmentQueryPort.tscn")
const CASH_MUTATION_SCENE := preload("res://scenes/runtime/PlayerCashMutationPort.tscn")
const BATTLE_LIFECYCLE_POLICY := preload("res://scripts/runtime/monster_battle_lifecycle_policy_v06.gd")

class FakeWorld:
	extends Node
	var session_state: WorldSessionState


var _checks := 0
var _failures := 0
var _host: Node
var _world: WorldSessionState
var _fake_world: FakeWorld
var _monster: MonsterRuntimeController
var _port: MonsterWagerCashCommitmentQueryPort
var _mutation_authority: SimulationMutationAuthority


func _init() -> void:
	_build_fixture()
	_test_base_and_selected_commitments()
	_test_multiple_wagers_and_income()
	_test_legacy_currency_mirror_reconciliation()
	_test_revision_and_malformed_fail_closed()
	_test_financial_bridge_consumes_available_cash()
	_test_production_composition_and_privacy_gates()
	print("MONSTER_WAGER_CASH_COMMITMENT_QUERY_PORT_CUTOVER %d/%d" % [_checks - _failures, _checks])
	_host.free()
	quit(0 if _failures == 0 else 1)


func _build_fixture() -> void:
	_host = Node.new()
	root.add_child(_host)
	_world = WorldSessionState.new()
	_world.players = [{"id": "player-0", "cash": 1000, "cash_cents": 100000, "eliminated": false}]
	_host.add_child(_world)
	_fake_world = FakeWorld.new()
	_fake_world.session_state = _world
	_host.add_child(_fake_world)
	var bridge := MonsterRuntimeWorldBridge.new()
	bridge.set_world_session_state(_world)
	bridge.bind_world(_fake_world)
	_host.add_child(bridge)
	_monster = MONSTER_SCENE.instantiate() as MonsterRuntimeController
	_monster.set_world_bridge(bridge)
	_host.add_child(_monster)
	_port = PORT_SCENE.instantiate() as MonsterWagerCashCommitmentQueryPort
	_host.add_child(_port)
	var configured := _port.configure(_world, _monster)
	_expect(bool(configured.get("configured", false)), "query port binds the two existing owners without storing their state")
	var identity := SimulationStateIdentity.new()
	var audit := SimulationDeterminismAudit.new()
	_mutation_authority = SimulationMutationAuthority.new()
	_host.add_child(identity)
	_host.add_child(audit)
	_host.add_child(_mutation_authority)
	_mutation_authority.bind_diagnostics(identity, audit)
	_expect(bool(_mutation_authority.begin_step(1).get("opened", false)), "the focused cash fixture runs inside an authoritative simulation step")


func _test_base_and_selected_commitments() -> void:
	_seed_wagers([_wager(10, 1, 5, {})], 1)
	var base := _port.private_cash_availability_snapshot(0)
	_expect(int(base.get("total_cents", -1)) == 100000 and int(base.get("reserved_cents", -1)) == 5000 and int(base.get("available_cents", -1)) == 95000, "an unanswered mandatory wager reserves its deterministic base stake")
	_expect(bool(_port.authorize_debit_cents(0, 95000).get("authorized", false)), "ordinary spending may consume exactly the uncommitted balance")
	var denied := _port.authorize_debit_cents(0, 95001)
	_expect(not bool(denied.get("authorized", true)) and str(denied.get("reason_code", "")) == "cash_reserved_for_monster_wager", "ordinary spending cannot cross the wager commitment")
	var entry := (_monster.active_monster_wagers[0] as Dictionary).duplicate(true)
	entry["bets"] = {"0": {"player_index": 0, "side": "a", "stake": 200, "stake_percent": 20, "forced": false}}
	_monster.active_monster_wagers[0] = entry
	var selected := _port.private_cash_availability_snapshot(0)
	_expect(int(selected.get("reserved_cents", -1)) == 20000 and int(selected.get("available_cents", -1)) == 80000, "the selected 20-percent stake replaces the base commitment without an early debit")
	_expect(int((_world.players[0] as Dictionary).get("cash", -1)) == 1000, "querying and choosing never debits ledger cash")


func _test_multiple_wagers_and_income() -> void:
	_seed_wagers([_wager(11, 2, 5, {"0": {"player_index": 0, "side": "a", "stake": 100, "stake_percent": 10, "forced": false}}), _wager(12, 3, 5, {})], 3)
	var combined := _port.private_cash_availability_snapshot(0)
	_expect(int(combined.get("reserved_cents", -1)) == 15000 and int(combined.get("available_cents", -1)) == 85000, "all unresolved wager commitments add deterministically")
	var player := (_world.players[0] as Dictionary).duplicate(true)
	player["cash"] = 1200
	player["cash_cents"] = 120000
	_world.players[0] = player
	var after_income := _port.private_cash_availability_snapshot(0)
	_expect(int(after_income.get("reserved_cents", -1)) == 15000 and int(after_income.get("available_cents", -1)) == 105000, "income remains available while the frozen stakes stay unchanged")


func _test_legacy_currency_mirror_reconciliation() -> void:
	_seed_wagers([_wager(121, 31, 5, {})], 31)
	var player := (_world.players[0] as Dictionary).duplicate(true)
	player["cash"] = 900
	player["cash_cents"] = 100000
	_world.players[0] = player
	var after_legacy_spend := _port.private_cash_availability_snapshot(0)
	_expect(
		int(after_legacy_spend.get("total_cents", -1)) == 90000
			and int(after_legacy_spend.get("available_cents", -1)) == 85000
			and bool(after_legacy_spend.get("used_legacy_unit_reconciliation", false)),
		"a legacy whole-unit debit cannot leave stale cents that resurrect wager cash"
	)
	player = (_world.players[0] as Dictionary).duplicate(true)
	player["cash"] = 1100
	player["cash_cents"] = 100000
	_world.players[0] = player
	var after_legacy_income := _port.private_cash_availability_snapshot(0)
	_expect(
		int(after_legacy_income.get("total_cents", -1)) == 110000
			and int(after_legacy_income.get("available_cents", -1)) == 105000,
		"a legacy whole-unit income remains spendable without releasing the frozen stake"
	)
	player = (_world.players[0] as Dictionary).duplicate(true)
	player["cash"] = 1000
	player["cash_cents"] = 100055
	_world.players[0] = player
	var exact_cents := _port.private_cash_availability_snapshot(0)
	_expect(
		int(exact_cents.get("total_cents", -1)) == 100055
			and not bool(exact_cents.get("used_legacy_unit_reconciliation", true)),
		"a coherent exact-cents balance preserves its fractional remainder"
	)


func _test_revision_and_malformed_fail_closed() -> void:
	_seed_wagers([_wager(13, 4, 5, {})], 4)
	var before := _port.private_cash_availability_snapshot(0)
	var old_fingerprint := str(before.get("availability_fingerprint", ""))
	var entry := (_monster.active_monster_wagers[0] as Dictionary).duplicate(true)
	entry["bets"] = {"0": {"player_index": 0, "side": "a", "stake": 200, "stake_percent": 20, "forced": false}}
	_monster.active_monster_wagers[0] = entry
	var stale := _port.authorize_debit_cents(0, 1, old_fingerprint)
	_expect(not bool(stale.get("authorized", true)) and str(stale.get("reason_code", "")) == "cash_availability_changed", "commit-time CAS rejects a changed wager commitment")
	var malformed := (_monster.active_monster_wagers[0] as Dictionary).duplicate(true)
	malformed.erase("opening_cash_units_by_player")
	_monster.active_monster_wagers[0] = malformed
	var invalid := _port.private_cash_availability_snapshot(0)
	_expect(not bool(invalid.get("valid", true)) and _port.available_cash_cents(0) == 0, "a malformed unresolved commitment fails closed instead of releasing cash")


func _test_financial_bridge_consumes_available_cash() -> void:
	var player := (_world.players[0] as Dictionary).duplicate(true)
	player["cash"] = 1000
	player["cash_cents"] = 100000
	_world.players[0] = player
	_seed_wagers([_wager(14, 5, 5, {})], 5)
	var bridge := ProductMarketRuntimeWorldBridge.new()
	bridge.bind_world(_fake_world)
	bridge.set_world_session_state(_world)
	bridge.set_cash_commitment_query_port(_port)
	var mutation_port := CASH_MUTATION_SCENE.instantiate() as PlayerCashMutationPort
	_host.add_child(mutation_port)
	_expect(bool(mutation_port.configure(_world, _port, _mutation_authority).get("configured", false)), "the financial bridge receives the typed mutation boundary")
	bridge.set_cash_mutation_port(mutation_port)
	_host.add_child(bridge)
	var denied := bridge.commit_player_cash_delta("test:denied", 0, -951, "test", "product", "futures_open")
	_expect(not bool(denied.get("committed", true)), "financial margin cannot spend a committed wager stake")
	var accepted := bridge.commit_player_cash_delta("test:accepted", 0, -950, "test", "product", "futures_open")
	_expect(
		bool(accepted.get("committed", false))
			and int((_world.players[0] as Dictionary).get("cash", -1)) == 50
			and int((_world.players[0] as Dictionary).get("cash_cents", -1)) == 5000
			and _port.available_cash_cents(0) == 0,
		"the typed financial debit preserves exact cents without resurrecting the committed stake"
	)
	var income := bridge.commit_player_cash_delta("test:income", 0, 5, "test", "product", "futures_close", 5)
	_expect(
		bool(income.get("committed", false))
			and int((_world.players[0] as Dictionary).get("cash_cents", -1)) == 5500
			and _port.available_cash_cents(0) == 500,
		"typed income remains available and keeps the commitment frozen"
	)
	bridge.free()


func _test_production_composition_and_privacy_gates() -> void:
	var scene_source := FileAccess.get_file_as_string("res://scenes/runtime/GameRuntimeCoordinator.tscn")
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	_expect(scene_source.count("[node name=\"MonsterWagerCashCommitmentQueryPort\"") == 1, "production composition owns exactly one private query port")
	for consumer_path in [
		"res://scripts/cards/v06/production/card_player_state_production_adapter_v06.gd",
		"res://scripts/runtime/card_play_eligibility_world_bridge.gd",
		"res://scripts/runtime/card_play_submission_runtime_controller.gd",
		"res://scripts/runtime/card_commitment_runtime_service.gd",
		"res://scripts/runtime/product_market_runtime_world_bridge.gd",
		"res://scripts/runtime/city_gdp_derivative_runtime_world_bridge.gd",
		"res://scripts/runtime/player_hand_interaction_runtime_service.gd",
		"res://scripts/runtime/district_purchase_settlement_runtime_service.gd",
		"res://scripts/runtime/commodity_flow_world_bridge.gd",
	]:
		_expect(FileAccess.get_file_as_string(consumer_path).contains("_cash_commitment_query_port"), "%s consumes the shared private cash boundary" % consumer_path.get_file())
	var ai_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_runtime_controller.gd")
	var ai_economy_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_actor_economy_facts_query_port.gd")
	_expect(not ai_source.contains("_cash_commitment_query_port") and ai_economy_source.contains("private_cash_availability_projection"), "AI consumes wager-adjusted cash only through the capability-guarded actor-economy query")
	_expect(coordinator_source.contains("_wire_monster_wager_cash_commitment_query_port"), "coordinator explicitly injects the one query port")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	_expect(not main_source.contains("MonsterWagerCashCommitmentQueryPort") and not main_source.contains("private_wager_cash_commitment_snapshot"), "Main receives no new cash or wager dependency")
	var presentation_source := FileAccess.get_file_as_string("res://scripts/presentation/table_presentation_viewmodel_query.gd")
	_expect(not presentation_source.contains("private_wager_cash_commitment_snapshot") and not presentation_source.contains("reserved_cents"), "private commitment data is absent from the player-facing table source")
	var debug := _port.debug_snapshot()
	_expect(not bool(debug.get("stores_cash", true)) and not bool(debug.get("stores_commitments", true)) and not bool(debug.get("public_snapshot_provider", true)), "the port is not a second owner or public information source")


func _wager(wager_id: int, revision: int, base_percent: int, bets: Dictionary) -> Dictionary:
	var competitors := [
		{"side": "a", "name": "怪兽A", "slot": 0, "uid": 100, "damage": 2},
		{"side": "b", "name": "怪兽B", "slot": 1, "uid": 101, "damage": 1},
	]
	return {
		"wager_id": wager_id,
		"settlement_revision": revision,
		"base_percent": base_percent,
		"competitors": competitors,
		"damage_a": 2,
		"damage_b": 1,
		"bets": bets.duplicate(true),
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


func _seed_wagers(wagers: Array, revision: int) -> void:
	_monster.active_monster_wagers = wagers.duplicate(true)
	_monster.set("_monster_wager_settlement_revision", revision)


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % label)
		return
	_failures += 1
	push_error("FAIL: %s" % label)
