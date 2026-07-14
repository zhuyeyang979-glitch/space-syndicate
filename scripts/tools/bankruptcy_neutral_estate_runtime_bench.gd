extends Node
class_name BankruptcyNeutralEstateRuntimeBench

signal bench_finished(exit_code: int)

const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")
const RULESET_V04 := preload("res://resources/rules/space_syndicate_ruleset_v04.tres")

var players: Array = []
var districts: Array = []
var game_time := 12.0
var game_over := false
var _checks := 0
var _failures: Array[String] = []
var _coordinator: GameRuntimeCoordinator
var _estate: BankruptcyNeutralEstateRuntimeController
var _flow: CommodityFlowRuntimeController
var _flow_bridge: CommodityFlowWorldBridge
var _region: RegionInfrastructureRuntimeController
var _military: MilitaryRuntimeController
var _monster: MonsterRuntimeController
var bench_complete := false
var bench_status := "RUNNING"
var bench_check_count := 0
var bench_failure_count := 0
var bench_failed_cases := ""


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_coordinator = COORDINATOR_SCENE.instantiate() as GameRuntimeCoordinator
	add_child(_coordinator)
	await get_tree().process_frame
	_coordinator.configure(RULESET_V04.debug_snapshot())
	_coordinator.bind_ai_world(self)
	_estate = _coordinator.get_node_or_null("BankruptcyNeutralEstateRuntimeController") as BankruptcyNeutralEstateRuntimeController
	_flow = _coordinator.get_node_or_null("CommodityFlowRuntimeController") as CommodityFlowRuntimeController
	_flow_bridge = _coordinator.get_node_or_null("CommodityFlowWorldBridge") as CommodityFlowWorldBridge
	_region = _coordinator.get_node_or_null("RegionInfrastructureRuntimeController") as RegionInfrastructureRuntimeController
	_military = _coordinator.get_node_or_null("MilitaryRuntimeController") as MilitaryRuntimeController
	_monster = _coordinator.get_node_or_null("MonsterRuntimeController") as MonsterRuntimeController
	_check("static_composition", _estate != null and _flow_bridge != null and _coordinator.get_node_or_null("BankruptcyNeutralEstateWorldBridge") != null)

	_seed_runtime(-100, 0)
	var prepared := _estate.prepare_checkpoint({"transaction_id": "bench:rollback", "reason_code": "active_storage_debt", "occurred_at": game_time})
	var external_units: Array = _military.military_units.duplicate(true)
	external_units.append({"uid": 99, "owner": 1, "hp": 10, "rank": 1})
	_military.military_units = external_units
	var failed_commit := _estate.commit_checkpoint(prepared)
	_check("cross_owner_failure_rejected", not bool(failed_commit.get("committed", false)))
	_check("cross_owner_failure_rolls_back_card", not bool((players[0] as Dictionary).get("eliminated", false)) and ((players[0] as Dictionary).get("slots", []) as Array).size() == 2)
	_check("cross_owner_failure_rolls_back_goods", (_flow.get("_warehouse_inventory") as Dictionary).size() == 1)

	_estate.reset_state()
	_seed_runtime(-100, 0)
	var region_before := _region.region_snapshot("region.alpha")
	var monster_before: Dictionary = (_monster.auto_monsters[0] as Dictionary).duplicate(true)
	var receipt := _coordinator.settle_bankruptcy_checkpoint({"transaction_id": "bench:success", "reason_code": "active_storage_debt", "occurred_at": game_time})
	var public_receipt: Dictionary = receipt.get("public_receipt", {}) if receipt.get("public_receipt", {}) is Dictionary else {}
	var counts: Dictionary = public_receipt.get("estate_counts", {}) if public_receipt.get("estate_counts", {}) is Dictionary else {}
	_check("negative_cash_bankrupt", bool(receipt.get("finalized", false)) and bool((players[0] as Dictionary).get("eliminated", false)))
	_check("zero_cash_stays_active", not bool((players[1] as Dictionary).get("eliminated", false)) and int((players[1] as Dictionary).get("cash_cents", -1)) == 0)
	_check("hand_and_goods_cleared", ((players[0] as Dictionary).get("slots", []) as Array).is_empty() and (_flow.get("_warehouse_inventory") as Dictionary).is_empty())
	_check("military_removed", _military.military_units.size() == 1 and int((_military.military_units[0] as Dictionary).get("owner", -1)) == 1)
	var orphan: Dictionary = _monster.auto_monsters[0] if _monster.auto_monsters[0] is Dictionary else {}
	_check("monster_orphan_preserves_runtime", int(orphan.get("owner", -2)) == -1 and int(orphan.get("hp", -1)) == int(monster_before.get("hp", -2)) and int(orphan.get("rank", -1)) == int(monster_before.get("rank", -2)))
	var facilities := _region.facilities_snapshot(false)
	var neutral: Dictionary = facilities[0] if not facilities.is_empty() and facilities[0] is Dictionary else {}
	var region_after := _region.region_snapshot("region.alpha")
	_check("facility_neutral_preserves_rank_hp", str(neutral.get("owner_kind", "")) == "neutral" and int(neutral.get("rank", -1)) == 2 and int(region_after.get("derived_current_hp", -1)) == int(region_before.get("derived_current_hp", -2)))
	_check("estate_counts", int(counts.get("hand_cards_removed", 0)) == 2 and int(counts.get("goods_removed", 0)) == 1 and int(counts.get("military_units_removed", 0)) == 1 and int(counts.get("monsters_orphaned", 0)) == 1 and int(counts.get("facilities_neutralized", 0)) == 1)
	var public_keys: Array = public_receipt.keys()
	public_keys.sort()
	_check("public_receipt_allowlist", public_keys == ["estate_counts", "player_indices", "reason"] and not JSON.stringify(public_receipt).contains("cash") and not JSON.stringify(public_receipt).contains("card_id"))
	var replay := _coordinator.settle_bankruptcy_checkpoint({"transaction_id": "bench:success", "reason_code": "active_storage_debt", "occurred_at": game_time})
	var estate_debug := _estate.debug_snapshot()
	_check("checkpoint_exact_once", bool(replay.get("duplicate", false)) and int(estate_debug.get("finalized_count", 0)) == 1 and bool(estate_debug.get("last_survivor_requested", false)))

	var pool_before := _monster.public_card_bid_monster_wager_pool
	var neutral_rent := _flow_bridge.apply_sale_receipt_batch({
		"batch_id": "bench:neutral-rent",
		"receipts": [{
			"receipt_id": "bench:neutral-sale", "trade_kind": "remote_route", "commodity_owner": 1,
			"owner_net_cash": 100, "rent_rows": [{"facility_id": str(neutral.get("facility_id", "")), "recipient_player_index": -1, "amount": 40}],
		}],
	})
	_check("neutral_rent_to_public_pool_exact_once", bool(neutral_rent.get("applied", false)) and _monster.public_card_bid_monster_wager_pool == pool_before + 40 and bool(_flow_bridge.apply_sale_receipt_batch({"batch_id": "bench:neutral-rent", "receipts": []}).get("duplicate", false)))
	var passive_reject := _flow_bridge.apply_sale_receipt_batch({"batch_id": "bench:passive", "receipts": [{"receipt_id": "bench:passive-sale", "trade_kind": "remote_route", "commodity_owner": 1, "owner_net_cash": -101, "rent_rows": []}]})
	_check("passive_forced_goods_never_negative", not bool(passive_reject.get("applied", false)) and int((players[1] as Dictionary).get("cash_cents", -1)) == 100)
	var active_apply := _flow_bridge.apply_sale_receipt_batch({"batch_id": "bench:active", "receipts": [{"receipt_id": "bench:active-sale", "trade_kind": "remote_route", "commodity_owner": 1, "owner_net_cash": -101, "bankruptcy_causality": "active_storage_debt", "rent_rows": []}]})
	_check("active_storage_debt_can_cross_zero", bool(active_apply.get("applied", false)) and int((players[1] as Dictionary).get("cash_cents", 0)) == -1)

	print("BANKRUPTCY_NEUTRAL_ESTATE_BENCH|status=%s|checks=%d|failures=%d|failed=%s" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size(), ",".join(_failures)])
	bench_status = "PASS" if _failures.is_empty() else "FAIL"
	bench_check_count = _checks
	bench_failure_count = _failures.size()
	bench_failed_cases = ",".join(_failures)
	bench_complete = true
	bench_finished.emit(0 if _failures.is_empty() else 1)


func _seed_runtime(cash_zero: int, other_cash: int) -> void:
	players = [
		{"id": 0, "name": "Player 1", "cash": int(floor(float(cash_zero) / 100.0)), "cash_cents": cash_zero, "slots": [{"card_id": "private.a"}, {"card_id": "private.b"}], "eliminated": false, "revision": 1},
		{"id": 1, "name": "Player 2", "cash": int(floor(float(other_cash) / 100.0)), "cash_cents": other_cash, "slots": [], "eliminated": false, "revision": 1},
	]
	var adapter := _coordinator.get_node_or_null("CardPlayerStateProductionAdapterV06")
	adapter.call("reset_state")
	adapter.call("bind_world", self)
	_flow.reset_state()
	_flow.set("_warehouse_inventory", {"bucket": {"owner_player_index": 0, "milliunits": 1000, "commodity_id": "private.product"}})
	_military.reset_state()
	_military.military_units = [{"uid": 1, "owner": 0, "hp": 20, "rank": 2}, {"uid": 2, "owner": 1, "hp": 20, "rank": 2}]
	_monster.reset_state()
	_monster.auto_monsters = [{"uid": 1, "owner": 0, "owner_revealed": false, "hp": 37, "max_hp": 40, "rank": 3, "remaining_time": 45.0, "cooldown_left": 3.0}]
	_region.initialize_regions([{"region_id": "region.alpha", "terrain_id": "land", "neighbor_region_ids": [], "legacy_index": 0}])
	_region.apply_facility_action({"transaction_id": "bench:facility:%d" % _checks, "region_id": "region.alpha", "owner_kind": "player", "owner_player_index": 0, "facility_type": "warehouse", "industry_id": "life", "rank": 2, "occurred_at": game_time})
	_region.apply_unit_damage({"transaction_id": "bench:damage:%d" % _checks, "source_kind": "monster", "source_entity_id": "monster.1", "region_id": "region.alpha", "amount": 25, "occurred_at": game_time})


func _player_is_eliminated(player_index: int) -> bool:
	return player_index < 0 or player_index >= players.size() or bool((players[player_index] as Dictionary).get("eliminated", false))


func _on_victory_outcome_applied(_receipt: Dictionary) -> void:
	game_over = true


func _check(case_id: String, passed: bool) -> void:
	_checks += 1
	if not passed:
		_failures.append(case_id)
	print("BANKRUPTCY_NEUTRAL_ESTATE_CASE|case=%s|passed=%s" % [case_id, str(passed)])
