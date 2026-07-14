extends SceneTree

const CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v06.tres"
const POLICY_SCRIPT := preload("res://scripts/cards/v06/card_flow_policy_v06.gd")

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := load(CATALOG_PATH) as CardRuntimeCatalogV06Resource
	_expect(catalog != null and bool(catalog.reload().get("valid", false)), "catalog is ready for flow policy tests")
	if catalog == null:
		_finish()
		return
	var policy := POLICY_SCRIPT.new() as CardFlowPolicyV06
	_verify_receive_and_merge(policy, catalog)
	_verify_acquisition(policy, catalog)
	_verify_play_commit_boundary(policy, catalog)
	_verify_player_feedback(policy)
	_finish()


func _verify_receive_and_merge(policy: CardFlowPolicyV06, catalog: CardRuntimeCatalogV06Resource) -> void:
	var ring_one := catalog.card_snapshot("commodity.ring_crystal_battery.rank_1")
	var four_cards := _inventory([
		ring_one,
		catalog.card_snapshot("commodity.star_dew_berry.rank_1"),
		catalog.card_snapshot("facility.road.rank_1"),
		catalog.card_snapshot("interaction.phase_veto.rank_1"),
	])
	var add_plan := policy.plan_receive(four_cards, ring_one, catalog)
	_expect(bool(add_plan.get("ready", false)) and str(add_plan.get("operation", "")) == "add", "same-name card does not auto-merge while the hand has room")
	var add_result := policy.commit_receive(four_cards, add_plan)
	_expect(bool(add_result.get("committed", false)), "same-name card is added as an independent fifth card")
	_expect(_family_rank_count(add_result.get("inventory", {}) as Dictionary, "commodity.ring_crystal_battery", 1) == 2, "the non-full hand keeps two separate rank-I copies")

	var full_inventory := _inventory([
		ring_one,
		catalog.card_snapshot("commodity.star_dew_berry.rank_1"),
		catalog.card_snapshot("facility.road.rank_1"),
		catalog.card_snapshot("interaction.phase_veto.rank_1"),
		catalog.card_snapshot("unit.monster.spore_tide_emperor.rank_1"),
	])
	var auto_plan := policy.plan_receive(full_inventory, ring_one, catalog)
	_expect(bool(auto_plan.get("ready", false)) and str(auto_plan.get("operation", "")) == "auto_merge_when_full", "full hand auto-merges one matching same-rank card")
	var auto_result := policy.commit_receive(full_inventory, auto_plan)
	_expect(bool(auto_result.get("committed", false)), "full-hand auto-merge commits")
	_expect(_family_rank_count(auto_result.get("inventory", {}) as Dictionary, "commodity.ring_crystal_battery", 2) == 1, "full-hand auto-merge produces the explicit next rank")
	_expect(_count_cards(auto_result.get("inventory", {}) as Dictionary) == 5, "full-hand auto-merge does not change counted hand size")

	var unmatched := catalog.card_snapshot("commodity.lunar_soil_grape.rank_1")
	var unmatched_plan := policy.plan_receive(full_inventory, unmatched, catalog)
	_expect(not bool(unmatched_plan.get("ready", true)) and str(unmatched_plan.get("reason_code", "")) == "hand_full_no_matching_merge", "full hand rejects an unmatched card without discard")

	var rank_four := catalog.card_snapshot("commodity.ring_crystal_battery.rank_4")
	var max_inventory := _inventory([
		rank_four,
		catalog.card_snapshot("commodity.star_dew_berry.rank_1"),
		catalog.card_snapshot("facility.road.rank_1"),
		catalog.card_snapshot("interaction.phase_veto.rank_1"),
		catalog.card_snapshot("unit.monster.spore_tide_emperor.rank_1"),
	])
	var max_plan := policy.plan_receive(max_inventory, rank_four, catalog)
	_expect(not bool(max_plan.get("ready", true)) and str(max_plan.get("reason_code", "")) == "matching_card_at_max_rank", "full hand cannot auto-merge two rank-IV cards")

	var merge_inventory := _inventory([ring_one, ring_one])
	var merge_plan := policy.plan_manual_merge(merge_inventory, 0, 1, catalog)
	_expect(bool(merge_plan.get("ready", false)) and str(merge_plan.get("result_card_id", "")) == "commodity.ring_crystal_battery.rank_2", "manual merge requires and resolves two same-name same-rank cards")
	var merge_result := policy.commit_manual_merge(merge_inventory, merge_plan)
	_expect(bool(merge_result.get("committed", false)) and _count_cards(merge_result.get("inventory", {}) as Dictionary) == 1, "manual merge replaces two cards with one next-rank card")
	var mixed_rank_inventory := _inventory([ring_one, catalog.card_snapshot("commodity.ring_crystal_battery.rank_2")])
	var mixed_plan := policy.plan_manual_merge(mixed_rank_inventory, 0, 1, catalog)
	_expect(not bool(mixed_plan.get("ready", true)) and str(mixed_plan.get("reason_code", "")) == "merge_rank_mismatch", "different ranks cannot merge")


func _verify_acquisition(policy: CardFlowPolicyV06, catalog: CardRuntimeCatalogV06Resource) -> void:
	var ring := catalog.card_snapshot("commodity.ring_crystal_battery.rank_1")
	var belt_player := _player_state(_inventory([]), 0, _empty_assets())
	var belt_plan := policy.plan_acquisition(belt_player, ring, {
		"source_kind": "commodity_belt",
		"transaction_id": "belt-1",
		"visible": true,
		"claimable": true,
		"expected_revision": 7,
		"current_revision": 7,
	}, catalog)
	_expect(bool(belt_plan.get("ready", false)) and int(belt_plan.get("cash_debit", -1)) == 0, "commodity belt acquisition is free")
	var belt_commit := policy.commit_acquisition(belt_player, belt_plan)
	_expect(bool(belt_commit.get("committed", false)) and int((belt_commit.get("player_state", {}) as Dictionary).get("cash", -1)) == 0, "free belt claim commits without cash debit")

	var warehouse := catalog.card_snapshot("facility.orbital_warehouse.rank_1")
	var market_player := _player_state(_inventory([]), 10, _empty_assets())
	var market_plan := policy.plan_acquisition(market_player, warehouse, {
		"source_kind": "dynamic_market",
		"transaction_id": "market-1",
		"listing_card_id": "facility.orbital_warehouse.rank_1",
		"expected_revision": 3,
		"current_revision": 3,
	}, catalog)
	_expect(bool(market_plan.get("ready", false)) and int(market_plan.get("cash_debit", 0)) == 4, "market purchase plans the provisional cash price only after inventory preflight")
	var market_commit := policy.commit_acquisition(market_player, market_plan)
	var market_after: Dictionary = market_commit.get("player_state", {}) if market_commit.get("player_state", {}) is Dictionary else {}
	_expect(bool(market_commit.get("committed", false)) and int(market_after.get("cash", 0)) == 6, "market purchase debits cash exactly once")
	_expect(bool(market_commit.get("market_refresh_required", false)), "successful market purchase requests immediate listing refresh")
	var duplicate_commit := policy.commit_acquisition(market_after, market_plan)
	_expect(not bool(duplicate_commit.get("committed", true)) and str(duplicate_commit.get("reason_code", "")) == "transaction_already_committed", "same purchase transaction cannot commit twice")


func _verify_play_commit_boundary(policy: CardFlowPolicyV06, catalog: CardRuntimeCatalogV06Resource) -> void:
	var ring := catalog.card_snapshot("commodity.ring_crystal_battery.rank_1")
	var ring_player := _player_state(_inventory([ring]), 0, _empty_assets())
	var ring_plan := policy.plan_play(ring_player, 0, {"valid": true, "target_kind": "same_industry_factory_or_market", "target_id": "facility-1"}, ["install_commodity_rate"], "play-ring-1")
	_expect(bool(ring_plan.get("ready", false)) and _asset_total(ring_plan.get("asset_debit", {}) as Dictionary) == 0, "commodity play is free after target and handler preflight")
	var failed_effect := policy.commit_play(ring_player, ring_plan, {"committed": false, "reason_code": "target_changed", "transaction_id": "play-ring-1"})
	_expect(not bool(failed_effect.get("committed", true)) and _count_cards((failed_effect.get("player_state", {}) as Dictionary).get("inventory", {}) as Dictionary) == 1, "failed effect leaves the card and assets untouched")
	var successful_effect := policy.commit_play(ring_player, ring_plan, {"committed": true, "transaction_id": "play-ring-1"})
	_expect(bool(successful_effect.get("committed", false)) and _count_cards((successful_effect.get("player_state", {}) as Dictionary).get("inventory", {}) as Dictionary) == 0, "card is consumed only after effect commit succeeds")

	var warehouse := catalog.card_snapshot("facility.orbital_warehouse.rank_2")
	var warehouse_player := _player_state(_inventory([warehouse]), 0, _empty_assets())
	var insufficient_plan := policy.plan_play(warehouse_player, 0, {"valid": true, "target_kind": "region_unique_facility_slot"}, ["build_upgrade_or_repair_facility"], "play-warehouse-1")
	_expect(not bool(insufficient_plan.get("ready", true)) and str(insufficient_plan.get("reason_code", "")) == "assets_insufficient", "rank-II facility play rejects before card consumption when generic assets are insufficient")
	var funded_assets := _empty_assets()
	funded_assets["life"] = 2
	var funded_warehouse_player := _player_state(_inventory([warehouse]), 0, funded_assets)
	var funded_plan := policy.plan_play(funded_warehouse_player, 0, {
		"valid": true,
		"target_kind": "region_unique_facility_slot",
		"generic_asset_allocation": {"life": 2},
	}, ["build_upgrade_or_repair_facility"], "play-warehouse-2")
	var funded_debit: Dictionary = funded_plan.get("asset_debit", {}) if funded_plan.get("asset_debit", {}) is Dictionary else {}
	_expect(bool(funded_plan.get("ready", false)) and int(funded_debit.get("life", 0)) == 2 and not funded_debit.has("generic"), "generic cost is allocated from the six colored asset pools instead of a seventh pool")
	var funded_commit := policy.commit_play(funded_warehouse_player, funded_plan, {"committed": true, "transaction_id": "play-warehouse-2"})
	var funded_after: Dictionary = funded_commit.get("player_state", {}) if funded_commit.get("player_state", {}) is Dictionary else {}
	var assets_after: Dictionary = funded_after.get("assets", {}) if funded_after.get("assets", {}) is Dictionary else {}
	_expect(bool(funded_commit.get("committed", false)) and int(assets_after.get("life", -1)) == 0 and not assets_after.has("generic"), "committed generic payment debits only the selected colored assets")
	var invalid_allocation := policy.plan_play(funded_warehouse_player, 0, {
		"valid": true,
		"target_kind": "region_unique_facility_slot",
		"generic_asset_allocation": {"energy": 2},
	}, ["build_upgrade_or_repair_facility"], "play-warehouse-3")
	_expect(not bool(invalid_allocation.get("ready", true)) and str(invalid_allocation.get("reason_code", "")) == "asset_allocation_invalid", "player-selected generic allocation cannot spend unavailable colored assets")
	var unavailable_plan := policy.plan_play(ring_player, 0, {"valid": true, "target_kind": "same_industry_factory_or_market"}, [], "play-ring-2")
	_expect(not bool(unavailable_plan.get("ready", true)) and str(unavailable_plan.get("reason_code", "")) == "effect_owner_unavailable", "unwired effect rejects before card consumption")


func _verify_player_feedback(policy: CardFlowPolicyV06) -> void:
	for reason_code in ["hand_full_no_matching_merge", "matching_card_at_max_rank", "assets_insufficient", "asset_allocation_invalid", "effect_owner_unavailable"]:
		var feedback := policy.player_feedback(reason_code)
		_expect(str(feedback.get("reason", "")).strip_edges() != "" and str(feedback.get("next_step", "")).strip_edges() != "", "%s has localized why-and-next-step feedback" % reason_code)
		_expect(not str(feedback.get("reason", "")).contains(reason_code) and not str(feedback.get("next_step", "")).contains(reason_code), "%s does not leak the machine reason code" % reason_code)


func _inventory(cards: Array) -> Dictionary:
	return {"hand_limit": 5, "slots": cards.duplicate(true)}


func _player_state(inventory: Dictionary, cash: int, assets: Dictionary) -> Dictionary:
	return {"inventory": inventory.duplicate(true), "cash": cash, "assets": assets.duplicate(true), "committed_transaction_ids": []}


func _empty_assets() -> Dictionary:
	return {"life": 0, "energy": 0, "industry": 0, "technology": 0, "commerce": 0, "shipping": 0}


func _family_rank_count(inventory: Dictionary, family_id: String, rank: int) -> int:
	var count := 0
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	for slot_variant in slots:
		if not (slot_variant is Dictionary):
			continue
		var machine: Dictionary = (slot_variant as Dictionary).get("machine", {}) if (slot_variant as Dictionary).get("machine", {}) is Dictionary else {}
		if str(machine.get("family_id", "")) == family_id and int(machine.get("rank", 0)) == rank:
			count += 1
	return count


func _count_cards(inventory: Dictionary) -> int:
	var count := 0
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	for slot_variant in slots:
		if slot_variant is Dictionary:
			count += 1
	return count


func _asset_total(assets: Dictionary) -> int:
	var total := 0
	for value in assets.values():
		total += int(value)
	return total


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	print("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("CARD_FLOW_POLICY_V06_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	print("CARD_FLOW_POLICY_V06_TEST|status=FAIL|checks=%d|failures=%d|details=%s" % [_checks, _failures.size(), JSON.stringify(_failures)])
	quit(1)
