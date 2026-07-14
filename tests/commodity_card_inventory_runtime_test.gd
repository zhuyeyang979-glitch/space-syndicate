extends SceneTree

const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")
const RULESET_V04 := preload("res://resources/rules/space_syndicate_ruleset_v04.tres")

class RuntimeWorld:
	extends Node
	var players: Array = []
	var game_time := 0.0

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var coordinator := COORDINATOR_SCENE.instantiate() as GameRuntimeCoordinator
	root.add_child(coordinator)
	await process_frame
	coordinator.configure(RULESET_V04.debug_snapshot())
	var world := RuntimeWorld.new()
	world.players = [_player_fixture(0), _player_fixture(1)]
	root.add_child(world)
	coordinator.bind_ai_world(world)
	var controller := coordinator.commodity_card_inventory_runtime_controller()
	var state_adapter := coordinator.card_player_state_production_adapter_v06()
	var core_adapter := coordinator.core_economic_card_runtime_adapter_v06()
	var flow := coordinator.commodity_flow_runtime_controller()
	var infrastructure := coordinator.get_node_or_null("RegionInfrastructureRuntimeController") as RegionInfrastructureRuntimeController
	_expect(controller != null and state_adapter != null and core_adapter != null, "runtime composition includes one production state adapter and the shared core effect adapter")
	_expect(bool(controller.debug_snapshot().get("controller_ready", false)), "commodity card inventory controller is ready")
	_expect(bool(state_adapter.debug_snapshot().get("world_bound", false)), "production state adapter binds the real player state")
	_expect(not bool(state_adapter.debug_snapshot().get("stores_inventory", true)) and coordinator.get_node_or_null("CommodityCardInventoryWorldBridge") == null, "legacy state bridge is absent and no parallel inventory journal is composed")
	_expect(bool(core_adapter.debug_snapshot().get("configured", false)), "core economic runtime adapter consumes the shared card source without a second transaction service")

	var initialized := infrastructure.initialize_regions([
		{"region_id": "region.alpha", "terrain_id": "land", "neighbor_region_ids": [], "legacy_index": 0},
	])
	_expect(bool(initialized.get("initialized", false)), "region infrastructure fixture initializes")
	var facility_receipt := infrastructure.apply_facility_action({
		"transaction_id": "test:facility:life",
		"region_id": "region.alpha",
		"owner_kind": "player",
		"owner_player_index": 1,
		"facility_type": "factory",
		"industry_id": "life",
		"rank": 1,
		"occurred_at": 1.0,
	})
	_expect(bool(facility_receipt.get("committed", false)), "cross-owner life factory fixture builds")
	var facility_id := str(facility_receipt.get("facility_id", ""))

	var catalog: Resource = controller.catalog()
	var rank_one: Dictionary = catalog.call("card_snapshot", "commodity.star_dew_berry.rank_1")
	_expect(not rank_one.is_empty(), "real v0.6 commodity card loads")
	var configured := coordinator.configure_commodity_card_belt(1, [_belt_item("belt:one", rank_one)])
	_expect(bool(configured.get("configured", false)), "commodity belt source configures through consumed Card Flow API")
	var player_before := controller.player_snapshot("player.0")
	var claim := coordinator.claim_commodity_card("player.0", "belt:one", int(player_before.get("revision", -1)), 1, "test:claim:add")
	_expect(bool(claim.get("committed", false)), "free commodity claim commits")
	_expect(int(controller.player_snapshot("player.0").get("cash", -1)) == 1000, "free claim does not change cash")
	_expect(_world_commodity_count(world, 0) == 1, "claim writes exactly one real player slot")
	var claim_replay := coordinator.claim_commodity_card("player.0", "belt:one", int(player_before.get("revision", -1)), 1, "test:claim:add")
	_expect(bool(claim_replay.get("committed", false)) and bool(claim_replay.get("idempotent_replay", false)), "claim transaction replays exactly once")

	_set_world_cards(world, 0, _commodity_cards(catalog, [
		"commodity.star_dew_berry.rank_1",
		"commodity.lunar_soil_grape.rank_1",
		"commodity.spore_silk.rank_1",
		"commodity.photosynthetic_gel.rank_1",
		"commodity.orbital_bonsai.rank_1",
	], "full-match"))
	var full_before := controller.player_snapshot("player.0")
	coordinator.configure_commodity_card_belt(2, [_belt_item("belt:merge", rank_one)])
	var auto_merge := coordinator.claim_commodity_card("player.0", "belt:merge", int(full_before.get("revision", -1)), 2, "test:claim:auto-merge")
	_expect(bool(auto_merge.get("committed", false)), "full hand auto-merges one same-family same-rank commodity")
	_expect(_world_has_card(world, 0, "commodity.star_dew_berry.rank_2"), "auto merge creates the next rank")
	_expect(_world_nonempty_slot_count(world, 0) == 5, "auto merge keeps the full-hand count stable")

	_set_world_cards(world, 0, _commodity_cards(catalog, [
		"commodity.lunar_soil_grape.rank_1",
		"commodity.spore_silk.rank_1",
		"commodity.photosynthetic_gel.rank_1",
		"commodity.orbital_bonsai.rank_1",
		"commodity.lunar_soil_grape.rank_2",
	], "full-no-match"))
	var no_match_before := controller.player_snapshot("player.0")
	coordinator.configure_commodity_card_belt(3, [_belt_item("belt:no-match", rank_one)])
	var no_match := coordinator.claim_commodity_card("player.0", "belt:no-match", int(no_match_before.get("revision", -1)), 3, "test:claim:no-match")
	_expect(not bool(no_match.get("committed", false)) and str(no_match.get("reason_code", "")) == "hand_full_no_matching_merge", "full hand without match rejects")
	_expect((controller.belt_snapshot().get("items", {}) as Dictionary).has("belt:no-match"), "failed claim leaves the belt item intact")
	_expect(_world_nonempty_slot_count(world, 0) == 5, "failed claim leaves the hand intact")

	_set_world_cards(world, 0, _commodity_cards(catalog, [
		"commodity.star_dew_berry.rank_1",
		"commodity.star_dew_berry.rank_1",
	], "manual"))
	var merge_before := controller.player_snapshot("player.0")
	var manual_merge := coordinator.merge_commodity_cards("player.0", 0, 1, int(merge_before.get("revision", -1)), "test:manual-merge")
	_expect(bool(manual_merge.get("committed", false)), "manual same-family same-rank merge commits")
	_expect(_world_has_card(world, 0, "commodity.star_dew_berry.rank_2") and _world_nonempty_slot_count(world, 0) == 1, "manual merge consumes two cards into one")

	var facility_rank_one: Dictionary = catalog.call("card_snapshot", "facility.factory.life.rank_1")
	var market_rank_one: Dictionary = catalog.call("card_snapshot", "facility.market.life.rank_1")
	_expect(not facility_rank_one.is_empty() and not market_rank_one.is_empty(), "real dynamic-market core cards load")
	_set_world_cards(world, 0, [])
	_set_world_cash(world, 0, 1000)
	var market_configured := controller.configure_market(5, _market_listing("market:factory-life", facility_rank_one, 4))
	_expect(bool(market_configured.get("configured", false)) and str((controller.market_snapshot().get("listing", {}) as Dictionary).get("item_id", "")) == "market:factory-life", "market source configures through the unique Card Flow service")
	var market_before := controller.player_snapshot("player.0")
	var purchase := controller.purchase_market_card(
		"player.0",
		"market:factory-life",
		_market_listing("market:market-life", market_rank_one, 4),
		int(market_before.get("revision", -1)),
		5,
		"test:market:purchase"
	)
	_expect(bool(purchase.get("committed", false)), "market purchase commits through the unique inventory owner")
	_expect(_world_cash(world, 0) == 996 and _world_has_card(world, 0, "facility.factory.life.rank_1"), "market purchase atomically applies the exact cash debit and inventory delta")
	_expect(int(controller.market_snapshot().get("revision", -1)) == 6, "market purchase advances the source revision once")
	var purchase_replay := controller.purchase_market_card(
		"player.0",
		"market:factory-life",
		_market_listing("market:market-life", market_rank_one, 4),
		int(market_before.get("revision", -1)),
		5,
		"test:market:purchase"
	)
	_expect(bool(purchase_replay.get("committed", false)) and bool(purchase_replay.get("idempotent_replay", false)) and _world_cash(world, 0) == 996 and _world_nonempty_slot_count(world, 0) == 1, "market purchase replay does not debit cash or add inventory twice")

	_set_world_cards(world, 0, _commodity_cards(catalog, [
		"facility.factory.life.rank_1",
		"facility.factory.life.rank_1",
	], "generic-merge"))
	var generic_merge_before := controller.player_snapshot("player.0")
	var generic_merge := controller.manual_merge("player.0", 0, 1, int(generic_merge_before.get("revision", -1)), "test:generic-merge")
	_expect(bool(generic_merge.get("committed", false)) and _world_has_card(world, 0, "facility.factory.life.rank_2"), "generic manual merge supports non-commodity core cards without a second inventory owner")
	_expect(controller.has_method("play_core_card"), "controller exposes the generic core-card play port for Agent B effect routing")
	_expect(_is_pure_data(controller.transaction_journal_snapshot()), "transaction journal snapshot is pure data")

	_set_world_cards(world, 0, _commodity_cards(catalog, ["commodity.star_dew_berry.rank_1"], "play"))
	var play_before := controller.player_snapshot("player.0")
	var play := coordinator.play_commodity_card(
		"player.0",
		0,
		{"valid": true, "target_kind": "same_industry_factory_or_market", "facility_id": facility_id, "game_time": 5.0},
		int(play_before.get("revision", -1)),
		"test:play:install"
	)
	_expect(bool(play.get("committed", false)), "commodity play commits against a same-color facility")
	var play_finalization: Dictionary = play.get("effect_finalization", {}) if play.get("effect_finalization", {}) is Dictionary else {}
	_expect(bool(play_finalization.get("finalized", false)), "transaction finalization reaches the authoritative commodity installation owner")
	_expect(_world_nonempty_slot_count(world, 0) == 0, "card is consumed only after installation commit")
	var closed_installation_rollback := flow.rollback_commodity_installation("test:play:install")
	_expect(str(closed_installation_rollback.get("reason_code", closed_installation_rollback.get("reason", ""))) == "installation_rollback_closed" and flow.installations_snapshot(false).size() == 1, "finalized commodity installation closes rollback without removing the installation")
	var play_replay := coordinator.play_commodity_card(
		"player.0",
		0,
		{"valid": true, "target_kind": "same_industry_factory_or_market", "facility_id": facility_id, "game_time": 5.0},
		int(play_before.get("revision", -1)),
		"test:play:install"
	)
	_expect(bool(play_replay.get("committed", false)) and bool(play_replay.get("idempotent_replay", false)) and _world_nonempty_slot_count(world, 0) == 0, "commodity play checks terminal replay before the now-empty source slot")
	var installations := flow.installations_snapshot(false)
	_expect(installations.size() == 1, "permanent installation is owned by CommodityFlowRuntimeController")
	if not installations.is_empty():
		var installation: Dictionary = installations[0]
		_expect(int(installation.get("installer_player_index", -1)) == 0 and int(facility_receipt.get("owner_player_index", -1)) == 1, "cross-owner install preserves facility owner and records installer")
		_expect(int(installation.get("base_units_per_minute", 0)) == 10, "rank-I installation uses 10 units per minute")
	var market_facility_receipt := infrastructure.apply_facility_action({
		"transaction_id": "test:facility:market-life",
		"region_id": "region.alpha",
		"owner_kind": "player",
		"owner_player_index": 1,
		"facility_type": "market",
		"industry_id": "life",
		"rank": 1,
		"occurred_at": 6.0,
	})
	var market_facility_id := str(market_facility_receipt.get("facility_id", ""))
	var market_facility := _facility_by_id(infrastructure.facilities_snapshot(false), market_facility_id)
	var installed_commodity_id := str((installations[0] as Dictionary).get("commodity_id", "")) if not installations.is_empty() else ""
	var demand_install := flow.install_commodity({
		"transaction_id": "test:flow:demand-life",
		"facility_id": market_facility_id,
		"facility": market_facility,
		"region_id": "region.alpha",
		"region_revision": int(infrastructure.region_snapshot("region.alpha").get("revision", 0)),
		"commodity_id": installed_commodity_id,
		"direction": "demand",
		"installer_player_index": 1,
		"source_card_rank": 1,
		"game_time": 6.0,
	})
	_expect(bool(demand_install.get("committed", false)), "real matching market demand installation commits")
	world.game_time = 12.0
	var flow_tick := flow.advance_world(6.0)
	_expect(bool(flow_tick.get("advanced", false)) and int(flow_tick.get("receipt_count", 0)) >= 1, "real production and demand create a Sale Receipt lineage")
	var candidate_snapshot := flow.card_effect_candidates_snapshot()
	var candidate_rows: Array = candidate_snapshot.get("candidates", []) if candidate_snapshot.get("candidates", []) is Array else []
	_expect(bool(candidate_snapshot.get("valid", false)) and candidate_rows.size() >= 2 and candidate_rows.size() % 2 == 0, "authoritative card-effect snapshot enumerates every current factory-to-market route with factory and market candidates")
	if not candidate_rows.is_empty():
		var candidate: Dictionary = candidate_rows[0]
		var route: Dictionary = candidate.get("route", {}) if candidate.get("route", {}) is Dictionary else {}
		var resources: Array = route.get("capacity_resources", []) if route.get("capacity_resources", []) is Array else []
		_expect(not str(route.get("source_facility_id", "")).is_empty() and not str(route.get("market_facility_id", "")).is_empty() and not resources.is_empty() and int(candidate.get("available_capacity_units", 0)) > 0, "candidate preserves real endpoint, route, and shared-capacity lineage")

	var save_data := flow.to_save_data()
	flow.reset_state()
	var restore := flow.apply_save_data(save_data)
	_expect(bool(restore.get("applied", false)) and flow.installations_snapshot(false).size() == 2, "persistent production and demand installations survive save round-trip")
	var controller_snapshot := controller.debug_snapshot()
	_expect(_is_pure_data(controller_snapshot), "controller debug snapshot is pure data")
	_expect(not bool(controller_snapshot.get("viewer_belt_visibility_owner", true)), "SS06-06 does not claim viewer-scoped belt visibility")
	var controller_save := controller.to_save_data()
	var saved_market_revision := int((controller_save.get("market", {}) as Dictionary).get("revision", -1))
	var saved_journal_count := (controller_save.get("transaction_journal", {}) as Dictionary).size()
	_expect(saved_market_revision == 6 and saved_journal_count >= 2, "controller save data covers market state and transaction journal evidence")

	coordinator.queue_free()
	world.queue_free()
	await process_frame
	if _failures.is_empty():
		print("COMMODITY_CARD_INVENTORY_RUNTIME_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("COMMODITY_CARD_INVENTORY_RUNTIME_TEST|status=FAIL|checks=%d|failures=%d" % [_checks, _failures.size()])
		quit(1)


func _player_fixture(player_index: int) -> Dictionary:
	return {
		"id": player_index,
		"name": "Player %d" % (player_index + 1),
		"cash": 1000,
		"cash_cents": 100000,
		"slots": [],
	}


func _belt_item(item_id: String, card: Dictionary) -> Dictionary:
	return {"item_id": item_id, "card": card.duplicate(true), "claimable": true, "visible_actor_ids": ["player.0"]}


func _market_listing(item_id: String, card: Dictionary, price_cash: int) -> Dictionary:
	return {"item_id": item_id, "card": card.duplicate(true), "price_cash": price_cash, "claimable": true, "legal_actor_ids": ["player.0"]}


func _commodity_cards(catalog: Resource, card_ids: Array, prefix: String) -> Array:
	var result: Array = []
	for index in range(card_ids.size()):
		var card: Dictionary = catalog.call("card_snapshot", str(card_ids[index]))
		card["runtime_instance_id"] = "%s:%d" % [prefix, index]
		result.append(card)
	return result


func _set_world_cards(world: RuntimeWorld, player_index: int, cards: Array) -> void:
	var players := world.players.duplicate(true)
	var player: Dictionary = (players[player_index] as Dictionary).duplicate(true)
	player["slots"] = cards.duplicate(true)
	players[player_index] = player
	world.players = players


func _set_world_cash(world: RuntimeWorld, player_index: int, cash: int) -> void:
	var players := world.players.duplicate(true)
	var player: Dictionary = (players[player_index] as Dictionary).duplicate(true)
	player["cash"] = cash
	players[player_index] = player
	world.players = players


func _world_cash(world: RuntimeWorld, player_index: int) -> int:
	return int((world.players[player_index] as Dictionary).get("cash", -1))


func _world_nonempty_slot_count(world: RuntimeWorld, player_index: int) -> int:
	var count := 0
	var slots: Array = ((world.players[player_index] as Dictionary).get("slots", []) as Array)
	for slot_variant in slots:
		if slot_variant is Dictionary:
			count += 1
	return count


func _world_commodity_count(world: RuntimeWorld, player_index: int) -> int:
	var count := 0
	var slots: Array = ((world.players[player_index] as Dictionary).get("slots", []) as Array)
	for slot_variant in slots:
		if not (slot_variant is Dictionary):
			continue
		var machine: Dictionary = (slot_variant as Dictionary).get("machine", {}) if (slot_variant as Dictionary).get("machine", {}) is Dictionary else {}
		if str(machine.get("category_id", "")) == "commodity":
			count += 1
	return count


func _world_has_card(world: RuntimeWorld, player_index: int, card_id: String) -> bool:
	var slots: Array = ((world.players[player_index] as Dictionary).get("slots", []) as Array)
	for slot_variant in slots:
		if not (slot_variant is Dictionary):
			continue
		var machine: Dictionary = (slot_variant as Dictionary).get("machine", {}) if (slot_variant as Dictionary).get("machine", {}) is Dictionary else {}
		if str(machine.get("card_id", "")) == card_id:
			return true
	return false


func _facility_by_id(facilities: Array, facility_id: String) -> Dictionary:
	for facility_variant in facilities:
		if facility_variant is Dictionary and str((facility_variant as Dictionary).get("facility_id", "")) == facility_id:
			return (facility_variant as Dictionary).duplicate(true)
	return {}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _is_pure_data(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item in value:
			if not _is_pure_data(item):
				return false
		return true
	if value is Dictionary:
		for key_variant in value.keys():
			if not _is_pure_data(key_variant) or not _is_pure_data(value.get(key_variant)):
				return false
		return true
	return false
