extends SceneTree

const CONTROLLER_SCENE := preload("res://scenes/runtime/MonsterRuntimeController.tscn")
const BATTLE_LIFECYCLE_POLICY := preload("res://scripts/runtime/monster_battle_lifecycle_policy_v06.gd")

class FakeWorld:
	extends Node
	var economic_events: Array = []
	var cash_snapshots: Array = []

	func _entity_world_position(entity: Dictionary) -> Vector2:
		var value: Variant = entity.get("world_position", Vector2.ZERO)
		return value if value is Vector2 else Vector2.ZERO

	func _player_name(player_index: int) -> String:
		return "玩家%d" % player_index

	func _limited_name_list(names: Array, limit: int = 6, empty_text: String = "无") -> String:
		if names.is_empty():
			return empty_text
		var shown: Array = names.slice(0, mini(limit, names.size()))
		return "、".join(shown)

	func _record_player_economic_event(player_index: int, kind: String, label: String, amount: int, detail: String = "") -> void:
		economic_events.append({"player_index": player_index, "kind": kind, "label": label, "amount": amount, "detail": detail})

	func _record_player_cash_snapshot(player_index: int) -> void:
		cash_snapshots.append(player_index)


var _checks := 0
var _failures := 0
var _host: Node
var _world: WorldSessionState
var _fake_world: FakeWorld
var _monster: MonsterRuntimeController


func _init() -> void:
	_build_fixture()
	_test_window_rate_and_opening_cash_contract()
	_test_doubled_pool_and_multiplayer_payout()
	_test_tied_sides_and_zero_damage()
	_test_timeout_default_and_eligibility()
	_test_pending_attack_cash_reservation()
	_test_save_replay_and_privacy()
	_test_terminal_journal_binding()
	_test_source_negative_gates()
	print("MONSTER_WAGER_SETTLEMENT_OWNER_CUTOVER %d/%d" % [_checks - _failures, _checks])
	_host.free()
	quit(0 if _failures == 0 else 1)


func _build_fixture() -> void:
	_host = Node.new()
	root.add_child(_host)
	_world = WorldSessionState.new()
	_world.name = "World"
	_host.add_child(_world)
	_fake_world = FakeWorld.new()
	_fake_world.name = "FakeWorld"
	_host.add_child(_fake_world)
	var bridge := MonsterRuntimeWorldBridge.new()
	bridge.name = "MonsterBridge"
	bridge.set_world_session_state(_world)
	bridge.bind_world(_fake_world)
	_host.add_child(bridge)
	_monster = CONTROLLER_SCENE.instantiate() as MonsterRuntimeController
	_monster.name = "Monster"
	_monster.set_world_bridge(bridge)
	_host.add_child(_monster)


func _test_window_rate_and_opening_cash_contract() -> void:
	_set_players([1000, 1000, 0])
	_seed_wager(10, 1, 7, 25, [0, 1, 2], {"0": 1000, "1": 1000, "2": 0}, 4, 2)
	var public := _monster.monster_wager_presentation_for_viewer(0)
	var percents: Array = []
	for action_variant: Variant in public.get("actions", []):
		var percent := int((action_variant as Dictionary).get("stake_percent", 0))
		if not percents.has(percent):
			percents.append(percent)
	_expect(float(public.get("seconds_total", 0.0)) == 15.0 and float(public.get("remaining_seconds", 0.0)) == 15.0, "production owner exposes the one 15-second decision window")
	_expect(percents == range(7, 21), "every one-percent step from the shared base through the 20-percent cap is available")
	var actions: Array = public.get("actions", [])
	var twenty_percent_stake := -1
	for action_variant: Variant in actions:
		var action := action_variant as Dictionary
		if str(action.get("side", "")) == "a" and int(action.get("stake_percent", 0)) == 20:
			twenty_percent_stake = int(action.get("stake", -1))
	_expect(twenty_percent_stake == 200, "stake preview uses frozen opening cash")
	var changed := (_world.players[0] as Dictionary).duplicate(true)
	changed["cash"] = 400
	changed["cash_cents"] = 40000
	_world.players[0] = changed
	var response := _monster.submit_monster_wager_response(10, 0, &"a", 20)
	_expect(bool(response.get("applied", false)) and int(response.get("stake", -1)) == 200, "response still uses opening cash after current cash changes")
	_expect(int((_world.players[0] as Dictionary).get("cash", -1)) == 400, "response records intent without an early debit")


func _test_doubled_pool_and_multiplayer_payout() -> void:
	_set_players([1000, 1000, 2000])
	_seed_wager(20, 2, 5, 100, [0, 1, 2], {"0": 1000, "1": 1000, "2": 2000}, 30, 10)
	_expect(bool(_monster.submit_monster_wager_response(20, 0, &"a", 5).get("applied", false)), "first multiplayer response accepted")
	_expect(bool(_monster.submit_monster_wager_response(20, 1, &"a", 20).get("applied", false)), "second multiplayer response accepted")
	var final := _monster.submit_monster_wager_response(20, 2, &"b", 5)
	_expect(bool(final.get("applied", false)) and bool(final.get("decision_closed", false)), "last response closes only the decision window")
	_expect(_monster.active_wager_count() == 1 and _monster.open_wager_decision_count() == 0, "closed decision remains an active battle without freezing the table")
	_expect(int((_world.players[0] as Dictionary).get("cash", -1)) == 1000 and int((_world.players[1] as Dictionary).get("cash", -1)) == 1000 and int((_world.players[2] as Dictionary).get("cash", -1)) == 2000, "decision close performs no early cash settlement")
	_monster.tick_battle_lifecycles(0.0)
	_expect(_monster.active_wager_count() == 0, "unavailable locked combatants end the battle and settle once")
	_expect(int((_world.players[0] as Dictionary).get("cash", -1)) == 1200, "first winner receives twice own stake plus equal remaining bonus")
	_expect(int((_world.players[1] as Dictionary).get("cash", -1)) == 1350, "second winner receives its own doubled stake plus the same bonus")
	_expect(int((_world.players[2] as Dictionary).get("cash", -1)) == 1900, "loser pays its opening-cash stake")
	var history: Dictionary = _monster.resolved_wagers_snapshot().back()
	var receipt: Dictionary = history.get("settlement_public_receipt", {})
	_expect(int(receipt.get("current_stake_total", -1)) == 350 and int(receipt.get("settlement_pool", -1)) == 800, "settlement pool is historical pool plus twice all current stakes")
	_expect(int(receipt.get("remaining_bonus_each", -1)) == 150 and int(receipt.get("public_pool_after", -1)) == 0, "multiplayer bonus is equal per winner and conserves the pool")
	var before := JSON.stringify(_world.players)
	_monster.tick_battle_lifecycles(60.0)
	_expect(JSON.stringify(_world.players) == before and _monster.active_wager_count() == 0, "terminal journal makes later battle ticks idempotent")


func _test_tied_sides_and_zero_damage() -> void:
	_set_players([1000, 1000, 1000])
	_seed_wager(30, 3, 5, 1, [0, 1, 2], {"0": 1000, "1": 1000, "2": 1000}, 12, 12)
	_monster.submit_monster_wager_response(30, 0, &"a", 5)
	_monster.submit_monster_wager_response(30, 1, &"b", 5)
	_monster.submit_monster_wager_response(30, 2, &"b", 5)
	_monster.tick_battle_lifecycles(0.0)
	var tied: Dictionary = (_monster.resolved_wagers_snapshot().back() as Dictionary).get("settlement_public_receipt", {})
	_expect((tied.get("winning_side_ids", []) as Array) == ["a", "b"], "all tied maximum-positive-damage monster sides win")
	_expect(int((_world.players[0] as Dictionary).get("cash", -1)) == 1050 and int((_world.players[1] as Dictionary).get("cash", -1)) == 1050 and int((_world.players[2] as Dictionary).get("cash", -1)) == 1050, "all three tied-side winners receive their own doubled stakes")
	_expect(_monster.public_card_bid_monster_wager_pool == 1, "only the indivisible public bonus remainder stays in the pool")

	_set_players([1000, 1000])
	_seed_wager(31, 4, 5, 77, [0, 1], {"0": 1000, "1": 1000}, 0, 0)
	_monster.submit_monster_wager_response(31, 0, &"a", 5)
	_monster.submit_monster_wager_response(31, 1, &"b", 10)
	_monster.tick_battle_lifecycles(0.0)
	var void_receipt: Dictionary = (_monster.resolved_wagers_snapshot().back() as Dictionary).get("settlement_public_receipt", {})
	_expect(str(void_receipt.get("outcome_kind", "")) == "void_no_effective_damage", "zero effective damage takes the refund branch")
	_expect(int((_world.players[0] as Dictionary).get("cash", -1)) == 1000 and int((_world.players[1] as Dictionary).get("cash", -1)) == 1000, "zero-damage settlement refunds every original stake through zero net deltas")
	_expect(_monster.public_card_bid_monster_wager_pool == 77, "zero-damage settlement preserves the historical public pool without matching money")


func _test_timeout_default_and_eligibility() -> void:
	_set_players([1000, 1000, 2000, 900])
	var eliminated := (_world.players[3] as Dictionary).duplicate(true)
	eliminated["eliminated"] = true
	_world.players[3] = eliminated
	_seed_wager(40, 5, 5, 0, [0, 1, 2], {"0": 1000, "1": 1000, "2": 2000}, 8, 3)
	_monster.submit_monster_wager_response(40, 0, &"a", 10)
	_monster.tick_wager_decisions_realtime(15.0)
	_expect(_monster.active_wager_count() == 1 and _monster.open_wager_decision_count() == 0, "timeout locks deterministic defaults before battle")
	_monster.tick_battle_lifecycles(0.0)
	var receipt: Dictionary = (_monster.resolved_wagers_snapshot().back() as Dictionary).get("settlement_public_receipt", {})
	var rows: Dictionary = {}
	for row_variant: Variant in receipt.get("participants", []):
		var row := row_variant as Dictionary
		rows[str(row.get("public_player_id", ""))] = row
	_expect(str((rows.get("player.1", {}) as Dictionary).get("selected_side_id", "")) == "b", "first timeout response selects the current least-staked side")
	_expect(str((rows.get("player.2", {}) as Dictionary).get("selected_side_id", "")) == "b", "later timeout response observes earlier public assignment deterministically")
	_expect(not rows.has("player.3"), "player eliminated before opening is excluded from the frozen roster")
	_expect(int((_world.players[3] as Dictionary).get("cash", -1)) == 900, "excluded player receives no wager cash mutation")


func _test_pending_attack_cash_reservation() -> void:
	_set_players([100])
	_monster.auto_monsters = [
		{"slot": 0, "uid": 201, "name": "怪兽A", "position": 0, "world_position": Vector2.ZERO, "down": false, "owner": 0, "max_hp": 100, "owner_damage_cash_total": 100, "owner_damage_cash_lost": 0, "owner_damage_cash_pool": 100},
		{"slot": 1, "uid": 202, "name": "怪兽B", "position": 0, "world_position": Vector2.ONE, "down": false, "owner": -1, "max_hp": 100},
	]
	_monster.next_auto_monster_uid = 203
	_seed_wager(41, 6, 5, 0, [0], {"0": 100}, 0, 10)
	var entry: Dictionary = (_monster.active_monster_wagers[0] as Dictionary).duplicate(true)
	entry["competitors"] = [
		{"side": "a", "name": "怪兽A", "slot": 0, "uid": 201, "damage": 0},
		{"side": "b", "name": "怪兽B", "slot": 1, "uid": 202, "damage": 10},
	]
	entry["locked_competitor_uids"] = [201, 202]
	entry["battle_roster_fingerprint"] = BATTLE_LIFECYCLE_POLICY.roster_fingerprint(entry.get("competitors", []) as Array)
	entry["bets"] = {"0": {"player_index": 0, "side": "a", "stake": 20, "stake_percent": 20, "forced": false}}
	entry["public_bets"] = [{"player_index": 0, "side": "a", "stake": 20, "stake_percent": 20, "forced": false}]
	_monster.active_monster_wagers[0] = entry
	_monster.call("_apply_owner_damage_cash_loss", 0, 100, "pending wager attack")
	_expect(int((_world.players[0] as Dictionary).get("cash", -1)) == 20, "pending monster damage cannot consume the frozen wager commitment")
	_expect(bool(_monster.call("_close_monster_wager_decision_window", 0, "reservation fault injection")), "cash reservation survives the decision-to-battle transition")
	_monster.tick_battle_lifecycles(60.0)
	_expect(int((_world.players[0] as Dictionary).get("cash", -1)) == 0 and _monster.active_wager_count() == 0, "reserved loser stake debits exactly once without a closed orphan wager")


func _test_save_replay_and_privacy() -> void:
	_set_players([1000, 1000])
	_seed_wager(50, 6, 6, 13, [0, 1], {"0": 917, "1": 628}, 5, 4)
	_monster.submit_monster_wager_response(50, 0, &"a", 6)
	var public := _monster.monster_wager_presentation_for_viewer(0)
	var serialized := JSON.stringify(public)
	for forbidden in ["opening_cash", "exact_cash", "fingerprint", "terminal_journal", "ai_wager", "hidden_owner", "owner_truth"]:
		_expect(not serialized.contains(forbidden), "public wager presentation excludes %s" % forbidden)
	_expect(not serialized.contains("917") and not serialized.contains("628"), "public wager presentation cannot reconstruct either opening-cash snapshot")
	var actor_snapshot := _monster.monster_wager_decision_snapshot_for_actor(50, 0)
	var actor_opening: Dictionary = actor_snapshot.get("opening_cash_units_by_player", {}) as Dictionary
	_expect(actor_opening == {"0": 917} and not JSON.stringify(actor_snapshot).contains("628"), "AI decision query exposes only its own frozen opening cash")
	_expect(not actor_snapshot.has("pending_attack") and not actor_snapshot.has("public_player_ids_by_index"), "AI decision query excludes private owner bindings and pending mutation state")
	var saved := _monster.to_save_data()
	var restored := CONTROLLER_SCENE.instantiate() as MonsterRuntimeController
	restored.name = "RestoredMonster"
	var bridge := MonsterRuntimeWorldBridge.new()
	bridge.name = "RestoredBridge"
	bridge.set_world_session_state(_world)
	bridge.bind_world(_fake_world)
	_host.add_child(bridge)
	restored.set_world_bridge(bridge)
	_host.add_child(restored)
	var load_receipt := restored.apply_save_data(saved)
	_expect(bool(load_receipt.get("applied", false)) and (restored.to_save_data().get("active_monster_wagers", []) as Array) == (_monster.to_save_data().get("active_monster_wagers", []) as Array), "save/load restores opening snapshots and partial responses exactly (%s)" % JSON.stringify(load_receipt))
	restored.free()
	bridge.free()


func _test_terminal_journal_binding() -> void:
	_set_players([1000, 1000])
	_seed_wager(60, 7, 5, 9, [0, 1], {"0": 1000, "1": 1000}, 11, 4)
	_monster.submit_monster_wager_response(60, 0, &"a", 5)
	_monster.submit_monster_wager_response(60, 1, &"b", 5)
	_monster.tick_battle_lifecycles(60.0)
	var saved := _monster.to_save_data()
	var terminal_journal: Dictionary = saved.get("monster_wager_settlement_terminal_journal", {}) as Dictionary
	_expect(terminal_journal.has("60:7"), "terminal journal key binds wager id and settlement revision")

	var forged_key_save := saved.duplicate(true)
	var forged_journal: Dictionary = (terminal_journal as Dictionary).duplicate(true)
	forged_journal["forged:7"] = forged_journal.get("60:7", {})
	forged_journal.erase("60:7")
	forged_key_save["monster_wager_settlement_terminal_journal"] = forged_journal
	var forged_key_controller := CONTROLLER_SCENE.instantiate() as MonsterRuntimeController
	forged_key_controller.set_world_bridge(_monster.get("_world_bridge") as MonsterRuntimeWorldBridge)
	_host.add_child(forged_key_controller)
	_expect(not bool(forged_key_controller.apply_save_data(forged_key_save).get("applied", false)), "load rejects a terminal journal stored under a forged key")
	forged_key_controller.free()

	var forged_receipt_save := saved.duplicate(true)
	var forged_receipt_journal: Dictionary = terminal_journal.duplicate(true)
	var forged_terminal: Dictionary = (forged_receipt_journal.get("60:7", {}) as Dictionary).duplicate(true)
	var forged_receipt: Dictionary = (forged_terminal.get("public_receipt", {}) as Dictionary).duplicate(true)
	forged_receipt["revision"] = 8
	forged_terminal["public_receipt"] = forged_receipt
	forged_receipt_journal["60:7"] = forged_terminal
	forged_receipt_save["monster_wager_settlement_terminal_journal"] = forged_receipt_journal
	var forged_receipt_controller := CONTROLLER_SCENE.instantiate() as MonsterRuntimeController
	forged_receipt_controller.set_world_bridge(_monster.get("_world_bridge") as MonsterRuntimeWorldBridge)
	_host.add_child(forged_receipt_controller)
	_expect(not bool(forged_receipt_controller.apply_save_data(forged_receipt_save).get("applied", false)), "load rejects a terminal public receipt with a mismatched revision/fingerprint")
	forged_receipt_controller.free()

	var restored := CONTROLLER_SCENE.instantiate() as MonsterRuntimeController
	restored.set_world_bridge(_monster.get("_world_bridge") as MonsterRuntimeWorldBridge)
	_host.add_child(restored)
	var before_cash := JSON.stringify(_world.players)
	var valid_load := restored.apply_save_data(saved)
	restored.tick_battle_lifecycles(60.0)
	_expect(bool(valid_load.get("applied", false)) and JSON.stringify(_world.players) == before_cash and restored.active_wager_count() == 0, "valid terminal save/load replay is exact-once with zero cash side effects (%s)" % JSON.stringify(valid_load))
	restored.free()


func _test_source_negative_gates() -> void:
	var ai_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_runtime_controller.gd")
	var monster_source := FileAccess.get_file_as_string("res://scripts/runtime/monster_runtime_controller.gd")
	_expect(not ai_source.contains("_monster_runtime_controller.active_monster_wagers ="), "AI cannot replace the wager owner's active array")
	_expect(not ai_source.contains("active_wagers_snapshot"), "AI cannot read the owner's private all-player wager snapshot")
	_expect(not monster_source.contains("MONSTER_WAGER_MAX_STAKE_PERCENT := 30") and not monster_source.contains("ceil(float(player_cash)"), "old 30-percent and ceil stake formulas are physically absent")
	_expect(not monster_source.contains("func _settle_monster_wager("), "manual wager-id settlement wrapper is physically retired")
	_expect(monster_source.count("MONSTER_WAGER_SETTLEMENT_POLICY_V06.settle") == 1, "one production settlement path consumes the pure policy")


func _set_players(cash_values: Array) -> void:
	var result: Array = []
	for index in range(cash_values.size()):
		var cash := int(cash_values[index])
		result.append({"id": "player-%d" % index, "name": "玩家%d" % index, "cash": cash, "cash_cents": cash * 100, "eliminated": false, "is_ai": index > 0})
	_world.players = result


func _seed_wager(wager_id: int, revision: int, base_percent: int, historical_pool: int, eligible: Array, opening_cash: Dictionary, damage_a: int, damage_b: int) -> void:
	var public_ids: Dictionary = {}
	for player_index_variant: Variant in eligible:
		public_ids[str(int(player_index_variant))] = "player.%d" % int(player_index_variant)
	_monster.active_monster_wagers = [{
		"wager_id": wager_id,
		"settlement_revision": revision,
		"base_percent": base_percent,
		"competitors": [
			{"side": "a", "name": "怪兽A", "slot": 0, "uid": 100, "damage": damage_a},
			{"side": "b", "name": "怪兽B", "slot": 1, "uid": 101, "damage": damage_b},
		],
		"damage_a": damage_a,
		"damage_b": damage_b,
		"bets": {},
		"public_bets": [],
		"historical_public_pool": historical_pool,
		"eligible_player_indices": eligible.duplicate(true),
		"opening_cash_units_by_player": opening_cash.duplicate(true),
		"public_player_ids_by_index": public_ids,
		"lifecycle_schema_version": BATTLE_LIFECYCLE_POLICY.SCHEMA_VERSION,
		"lifecycle_phase": BATTLE_LIFECYCLE_POLICY.PHASE_DECISION,
		"lifecycle_revision": 1,
		"decision_remaining_seconds": 15.0,
		"battle_limit_seconds": 60.0,
		"battle_remaining_seconds": 60.0,
		"locked_competitor_uids": [100, 101],
		"battle_roster_fingerprint": BATTLE_LIFECYCLE_POLICY.roster_fingerprint([
			{"side": "a", "name": "怪兽A", "slot": 0, "uid": 100, "damage": damage_a},
			{"side": "b", "name": "怪兽B", "slot": 1, "uid": 101, "damage": damage_b},
		]),
		"opening_attack_applied": true,
		"decision_open": true,
		"context": "owner cutover test",
		"resolved": false,
	}]
	_monster.monster_wager_sequence = maxi(_monster.monster_wager_sequence, wager_id)
	_monster.set("_monster_wager_settlement_revision", maxi(int(_monster.get("_monster_wager_settlement_revision")), revision))
	_monster.public_card_bid_monster_wager_pool = 0


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % label)
		return
	_failures += 1
	push_error("FAIL: %s" % label)
