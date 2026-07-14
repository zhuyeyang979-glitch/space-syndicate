extends Node

const CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v06.tres"
const PROFILE_PATH := "res://resources/rules/space_syndicate_ruleset_v06.tres"
const ASSET_IDS: Array[String] = ["life", "energy", "industry", "technology", "commerce", "shipping"]

@onready var asset_owner: Node = $PlayerAssets
@onready var infrastructure_owner: Node = $Infrastructure
@onready var commodity_flow_owner: Node = $CommodityFlow
@onready var player_state_port: Node = $ProductionPlayerStatePort
@onready var card_source_owner: Node = $CardSource
@onready var core_runtime: Node = $CoreEconomicRuntime

var players: Array = []
var _checks := 0
var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := load(CATALOG_PATH) as CardRuntimeCatalogV06Resource
	var profile := load(PROFILE_PATH) as SpaceSyndicateRulesetProfileV06
	_check(catalog != null and bool(catalog.reload().get("valid", false)), "catalog_ready")
	_check(profile != null, "profile_ready")
	if catalog == null or profile == null:
		_finish()
		return
	var profile_snapshot := profile.debug_snapshot()
	players = [{
		"actor_id": "bench-syndicate",
		"cash": 20,
		"cash_cents": 2000,
		"slots": [
			_card(catalog, "commodity.ring_crystal_battery.rank_1", "bench:ring:1"),
			_card(catalog, "commodity.ring_crystal_battery.rank_1", "bench:ring:2"),
			_card(catalog, "facility.factory.life.rank_1", "bench:factory:1"),
			_card(catalog, "commodity.star_dew_berry.rank_1", "bench:commodity:1"),
		],
	}]

	_check(bool(asset_owner.call("configure", profile_snapshot).get("configured", false)), "asset_owner_configured")
	_check(bool(asset_owner.call("apply_save_data", _asset_save_data(5)).get("applied", false)), "asset_balance_loaded")
	_check(bool(infrastructure_owner.call("configure", profile_snapshot).get("configured", false)), "infrastructure_configured")
	_check(bool(infrastructure_owner.call("initialize_regions", [{
		"region_id": "bench-region",
		"terrain_id": "temperate",
		"neighbor_region_ids": [],
		"legacy_index": 0,
	}]).get("initialized", false)), "region_initialized")
	_check(bool(commodity_flow_owner.call("configure", profile_snapshot).get("configured", false)), "commodity_flow_configured")
	_check(bool(player_state_port.call("configure", catalog, asset_owner).get("configured", false)), "production_state_port_configured")
	_check(bool(player_state_port.call("bind_world", self).get("bound", false)), "production_state_port_bound")
	_check(bool(card_source_owner.call("configure", profile_snapshot, player_state_port, commodity_flow_owner, infrastructure_owner).get("configured", false)), "card_source_configured")
	card_source_owner.call("bind_world", self)
	_check(bool(core_runtime.call("configure", card_source_owner, commodity_flow_owner, infrastructure_owner, {"bench-syndicate": 0}).get("configured", false)), "core_runtime_configured")

	var initial: Dictionary = card_source_owner.call("player_snapshot", "bench-syndicate")
	var merge: Dictionary = card_source_owner.call("manual_merge", "bench-syndicate", 0, 1, int(initial.get("revision", -1)), "bench-merge")
	_check(bool(merge.get("committed", false)) and _family_rank_count(card_source_owner.call("player_snapshot", "bench-syndicate"), "commodity.ring_crystal_battery", 2) == 1, "manual_merge_committed")

	var belt_card := catalog.card_snapshot("commodity.orbital_bonsai.rank_1")
	_check(bool(card_source_owner.call("configure_belt", 4, [{
		"item_id": "bench-belt-item",
		"card": belt_card,
		"visible_actor_ids": ["bench-syndicate"],
	}]).get("configured", false)), "belt_configured")
	var before_belt: Dictionary = card_source_owner.call("player_snapshot", "bench-syndicate")
	var belt_claim: Dictionary = card_source_owner.call("claim_belt_card", "bench-syndicate", "bench-belt-item", int(before_belt.get("revision", -1)), 4, "bench-belt-claim")
	_check(bool(belt_claim.get("committed", false)), "belt_claim_committed")
	var belt_replay: Dictionary = card_source_owner.call("claim_belt_card", "bench-syndicate", "bench-belt-item", int(before_belt.get("revision", -1)), 4, "bench-belt-claim")
	_check(bool(belt_replay.get("idempotent_replay", false)), "belt_claim_exact_once")

	var warehouse := catalog.card_snapshot("facility.orbital_warehouse.rank_1")
	var road := catalog.card_snapshot("facility.road.rank_1")
	_check(bool(card_source_owner.call("configure_market", 8, {
		"item_id": "bench-market-warehouse",
		"card": warehouse,
		"price_cash": 4,
	}).get("configured", false)), "market_configured")
	var before_market: Dictionary = card_source_owner.call("player_snapshot", "bench-syndicate")
	var purchase: Dictionary = card_source_owner.call("purchase_market_card", "bench-syndicate", "bench-market-warehouse", {
		"item_id": "bench-market-road",
		"card": road,
		"price_cash": 3,
	}, int(before_market.get("revision", -1)), 8, "bench-market-purchase")
	_check(bool(purchase.get("committed", false)) and int((card_source_owner.call("player_snapshot", "bench-syndicate") as Dictionary).get("cash", -1)) == 16 and int((players[0] as Dictionary).get("cash_cents", -1)) == 1600, "market_purchase_exact_cash")
	_check(int((card_source_owner.call("market_snapshot") as Dictionary).get("revision", -1)) == 9, "market_refresh_atomic")

	var before_factory: Dictionary = card_source_owner.call("player_snapshot", "bench-syndicate")
	var factory_slot := _card_slot(before_factory, "facility.factory.life.rank_1")
	var facility_play: Dictionary = core_runtime.call("play_card", "bench-syndicate", factory_slot, {
		"valid": true,
		"target_kind": "region_unique_facility_slot",
		"region_id": "bench-region",
		"slot_id": "bench-region::factory.life",
		"industry_id": "life",
	}, int(before_factory.get("revision", -1)), "bench-build-factory")
	_check(not bool(facility_play.get("committed", true)) and str(facility_play.get("reason_code", "")) == "facility_rollback_atomicity_unavailable", "unsafe_facility_rollback_gate_fails_closed")
	_check(_same_player_resources(before_factory, card_source_owner.call("player_snapshot", "bench-syndicate")), "facility_gate_changes_no_player_resources")
	var fixture_factory: Dictionary = infrastructure_owner.call("apply_facility_action", {
		"transaction_id": "bench-fixture-factory",
		"region_id": "bench-region",
		"owner_kind": "player",
		"owner_player_index": 0,
		"facility_type": "factory",
		"industry_id": "life",
		"rank": 1,
		"occurred_at": 0.0,
	})
	_check(bool(fixture_factory.get("committed", false)), "fixture_factory_created_by_authoritative_owner")
	var facilities: Array = infrastructure_owner.call("facilities_snapshot", false)
	_check(facilities.size() == 1 and str((facilities[0] as Dictionary).get("facility_type", "")) == "factory", "factory_exists_in_authoritative_owner")

	var before_commodity: Dictionary = card_source_owner.call("player_snapshot", "bench-syndicate")
	var commodity_slot := _card_slot(before_commodity, "commodity.star_dew_berry.rank_1")
	var facility_id := str((facilities[0] as Dictionary).get("facility_id", "")) if not facilities.is_empty() else ""
	var commodity_play: Dictionary = core_runtime.call("play_card", "bench-syndicate", commodity_slot, {
		"valid": true,
		"target_kind": "same_industry_factory_or_market",
		"facility_id": facility_id,
		"direction": "production",
	}, int(before_commodity.get("revision", -1)), "bench-install-commodity")
	_check(bool(commodity_play.get("committed", false)), "commodity_play_committed")
	_check(not bool((commodity_play.get("effect_finalization", {}) as Dictionary).get("finalized", true)), "commodity_finalize_gap_reported_honestly")
	_check((commodity_flow_owner.call("installations_snapshot", false) as Array).size() == 1, "commodity_installation_exists")
	var commodity_replay: Dictionary = core_runtime.call("play_card", "bench-syndicate", commodity_slot, {
		"valid": true,
		"target_kind": "same_industry_factory_or_market",
		"facility_id": facility_id,
		"direction": "production",
	}, int(before_commodity.get("revision", -1)), "bench-install-commodity")
	_check(bool(commodity_replay.get("idempotent_replay", false)) and (commodity_flow_owner.call("installations_snapshot", false) as Array).size() == 1, "commodity_play_exact_once")

	var player_after: Dictionary = card_source_owner.call("player_snapshot", "bench-syndicate")
	_check(not (player_after.get("assets", {}) as Dictionary).has("generic") and (player_after.get("assets", {}) as Dictionary).size() == ASSET_IDS.size(), "six_color_assets_only")
	_finish()


func _asset_save_data(value: int) -> Dictionary:
	var pools: Dictionary = {}
	var remainders: Dictionary = {}
	for asset_id in ASSET_IDS:
		pools[asset_id] = value * 1000
		remainders[asset_id] = 0
	return {
		"state_version": 1,
		"ruleset_id": "v0.6",
		"current_game_time": 0.0,
		"revision": 1,
		"pools_by_player": {"0": pools},
		"recovery_remainders_by_player": {"0": remainders},
		"reservations": {},
		"terminal_receipts": {},
	}


func _card(catalog: CardRuntimeCatalogV06Resource, card_id: String, instance_id: String) -> Dictionary:
	var card := catalog.card_snapshot(card_id)
	card["runtime_instance_id"] = instance_id
	return card


func _card_slot(player_state: Dictionary, card_id: String) -> int:
	var inventory: Dictionary = player_state.get("inventory", {}) if player_state.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	for slot_index in range(slots.size()):
		if not (slots[slot_index] is Dictionary):
			continue
		var machine: Dictionary = (slots[slot_index] as Dictionary).get("machine", {}) if (slots[slot_index] as Dictionary).get("machine", {}) is Dictionary else {}
		if str(machine.get("card_id", "")) == card_id:
			return slot_index
	return -1


func _family_rank_count(player_state: Dictionary, family_id: String, rank: int) -> int:
	var inventory: Dictionary = player_state.get("inventory", {}) if player_state.get("inventory", {}) is Dictionary else {}
	var count := 0
	for slot_variant in inventory.get("slots", []) as Array:
		if not (slot_variant is Dictionary):
			continue
		var machine: Dictionary = (slot_variant as Dictionary).get("machine", {}) if (slot_variant as Dictionary).get("machine", {}) is Dictionary else {}
		if str(machine.get("family_id", "")) == family_id and int(machine.get("rank", 0)) == rank:
			count += 1
	return count


func _same_player_resources(first: Dictionary, second: Dictionary) -> bool:
	return (
		int(first.get("revision", -1)) == int(second.get("revision", -2))
		and int(first.get("cash", -1)) == int(second.get("cash", -2))
		and JSON.stringify(first.get("assets", {})) == JSON.stringify(second.get("assets", {}))
		and JSON.stringify(first.get("inventory", {})) == JSON.stringify(second.get("inventory", {}))
	)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("CORE_ECONOMY_PRODUCTION_WIRING_V06_BENCH|status=PASS|checks=%d|failures=0|terminology=assets" % _checks)
		return
	for failure in _failures:
		push_error("CORE_ECONOMY_PRODUCTION_WIRING_V06_BENCH failure: %s" % failure)
	print("CORE_ECONOMY_PRODUCTION_WIRING_V06_BENCH|status=FAIL|checks=%d|failures=%d|details=%s" % [_checks, _failures.size(), JSON.stringify(_failures)])
