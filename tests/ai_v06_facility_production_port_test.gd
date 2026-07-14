extends SceneTree

const COORDINATOR_SCENE := "res://scenes/runtime/GameRuntimeCoordinator.tscn"
const PROFILE := preload("res://resources/rules/space_syndicate_ruleset_v04.tres")

var _checks := 0
var _failures: Array[String] = []


class RuntimeWorld:
	extends Node
	var selected_district := 0
	var players: Array = [{
		"id": 0,
		"name": "Focused Player",
		"cash": 20,
		"cash_cents": 2000,
		"slots": [],
	}]
	var districts: Array = [
		{
			"id": 0,
			"region_id": "region.demand",
			"terrain": "land",
			"products": ["星露莓"],
			"demands": ["星露莓"],
		},
		{
			"id": 1,
			"region_id": "region.no-demand",
			"terrain": "land",
			"products": ["星露莓"],
			"demands": [],
		},
	]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(COORDINATOR_SCENE) as PackedScene
	_expect(packed != null, "production Coordinator scene loads")
	if packed == null:
		_finish()
		return
	var coordinator := packed.instantiate()
	root.add_child(coordinator)
	coordinator.call("configure", PROFILE.debug_snapshot())
	var world := RuntimeWorld.new()
	root.add_child(world)
	var infrastructure: Object = coordinator.call("region_infrastructure_runtime_controller")
	var initialization: Dictionary = infrastructure.call("initialize_regions", [
		{
			"region_id": "region.demand",
			"terrain_id": "land",
			"neighbor_region_ids": ["region.no-demand"],
			"legacy_index": 0,
		},
		{
			"region_id": "region.no-demand",
			"terrain_id": "land",
			"neighbor_region_ids": ["region.demand"],
			"legacy_index": 1,
		},
	])
	_expect(bool(initialization.get("initialized", false)), "focused world initializes the real RegionInfrastructure owner")
	var region_bridge := coordinator.get_node_or_null("RegionInfrastructureWorldBridge")
	_expect(region_bridge != null, "authoritative region commodity facts bridge is composed")
	region_bridge.call("bind_world", world)
	var binding: Dictionary = coordinator.call("refresh_v06_production_player_bindings", world)
	print("AI_V06_PORT_STAGE|stage=bind|port=%s|state=%s|inventory=%s|core=%s|demand=%s|monster=%s" % [
		bool(binding.get("ai_v06_economy_port_ready", false)),
		bool(binding.get("state_adapter_ready", false)),
		bool(binding.get("inventory_ready", false)),
		bool(binding.get("core_economic_ready", false)),
		bool(binding.get("public_demand_ready", false)),
		bool(binding.get("monster_card_adapter_ready", false)),
	])
	_expect(bool(binding.get("ai_v06_economy_port_ready", false)), "Coordinator injects the narrow production port into AI")
	var facility_chain_ready := bool(binding.get("state_adapter_ready", false)) \
		and bool(binding.get("inventory_ready", false)) \
		and bool(binding.get("core_economic_ready", false)) \
		and bool(binding.get("public_demand_ready", false))
	_expect(facility_chain_ready, "focused fixture composes every production owner used by the facility chain")
	# The global Coordinator readiness gate also requires the Monster card adapter,
	# whose world contract is intentionally outside this focused fixture. The test
	# opens only that aggregate gate after proving all facility-chain owners ready.
	if facility_chain_ready:
		coordinator.set("_configured", true)
	var ai := coordinator.get_node_or_null("AiRuntimeController")
	var ai_public: Dictionary = ai.call("ai_v06_facility_bootstrap_public_snapshot") if ai != null else {}
	_expect(bool(ai_public.get("available", false)), "AI reports the production port capability without private policy details")

	var players: Array = world.players
	_expect(not players.is_empty() and players[0] is Dictionary and not (players[0] as Dictionary).has("actor_id"), "production player has no actor_id field")
	var identity: Dictionary = coordinator.call("actor_id_for_player_index", 0)
	var actor_id := str(identity.get("actor_id", ""))
	_expect(bool(identity.get("available", false)) and actor_id == "player.0", "Coordinator reverses the sole production adapter actor map")
	var source_before: Dictionary = coordinator.call("economic_source_snapshot", actor_id)
	_expect(bool(source_before.get("available", false)) and not bool(source_before.get("has_source", true)), "source snapshot reads existing owners and starts empty")
	var market_before: Dictionary = coordinator.call("market_snapshot", actor_id)
	var listing: Dictionary = market_before.get("listing", {}) if market_before.get("listing", {}) is Dictionary else {}
	var legal_regions: Array = listing.get("legal_region_ids", []) if listing.get("legal_region_ids", []) is Array else []
	print("AI_V06_PORT_STAGE|stage=market|available=%s|reason=%s|legal=%d" % [bool(market_before.get("available", false)), str(market_before.get("reason_code", "missing")), legal_regions.size()])
	_expect(bool(market_before.get("available", false)) and bool(listing.get("canonical", false)), "production market exposes one canonical rank-I facility listing")
	_expect(not legal_regions.is_empty() and str(listing.get("target_region_id", "")) == str(legal_regions[0]), "listing target is selected from authoritative legal region candidates")
	var player_before: Dictionary = coordinator.call("player_snapshot", actor_id)
	_expect(bool(player_before.get("available", false)) and player_before.get("cards", []) is Array, "production player snapshot is narrow pure data")

	var inventory: Object = coordinator.call("commodity_card_inventory_runtime_controller")
	var flow: Object = coordinator.call("commodity_flow_runtime_controller")
	var facilities_before: Array = infrastructure.call("facilities_snapshot", false)
	var installations_before: Array = flow.call("installations_snapshot", false)
	var journal_before: Dictionary = inventory.call("transaction_journal_snapshot")
	var purchase_transaction_id := "vs06-b5b:production-purchase:%s" % actor_id
	var purchase: Dictionary = coordinator.call(
		"purchase_rank_i_facility",
		actor_id,
		str(listing.get("item_id", "")),
		purchase_transaction_id,
		int(market_before.get("revision", -1)),
		int(player_before.get("revision", -1)),
		int(source_before.get("revision", -1))
	)
	_expect(bool(purchase.get("available", false)) and bool(purchase.get("committed", false)), "narrow port purchases through Inventory and CardFlow")
	var player_after_purchase: Dictionary = coordinator.call("player_snapshot", actor_id)
	var cards_after_purchase: Array = player_after_purchase.get("cards", []) if player_after_purchase.get("cards", []) is Array else []
	_expect(cards_after_purchase.size() == 1 and int(player_after_purchase.get("cash", 0)) < int(player_before.get("cash", 0)), "purchase debits authoritative cash once and exposes the stable runtime card")
	_expect((infrastructure.call("facilities_snapshot", false) as Array).size() == facilities_before.size(), "purchase alone never writes a facility")
	var purchase_replay: Dictionary = coordinator.call(
		"purchase_rank_i_facility",
		actor_id,
		str(listing.get("item_id", "")),
		purchase_transaction_id,
		int(market_before.get("revision", -1)),
		int(player_before.get("revision", -1)),
		int(source_before.get("revision", -1))
	)
	_expect(bool(purchase_replay.get("committed", false)) and bool(purchase_replay.get("idempotent_replay", false)), "purchase transaction replay is exact-once")
	var player_after_purchase_replay: Dictionary = coordinator.call("player_snapshot", actor_id)
	_expect(int(player_after_purchase_replay.get("cash", -1)) == int(player_after_purchase.get("cash", -2)) and (player_after_purchase_replay.get("cards", []) as Array).size() == cards_after_purchase.size(), "purchase replay does not debit cash or add a second card")

	var source_after_purchase: Dictionary = coordinator.call("economic_source_snapshot", actor_id)
	_expect(int(source_after_purchase.get("revision", -1)) == int(source_before.get("revision", -2)) and not bool(source_after_purchase.get("has_source", true)), "buying a card does not fabricate a facility source revision")
	var card_binding: Dictionary = cards_after_purchase[0] if not cards_after_purchase.is_empty() and cards_after_purchase[0] is Dictionary else {}
	var play_transaction_id := "vs06-b5b:production-play:%s" % actor_id
	_expect(legal_regions.has("region.no-demand"), "a production region without an explicit demand endpoint remains a legal factory target")
	var play_request := {
		"actor_id": actor_id,
		"slot_index": int(card_binding.get("slot_index", -1)),
		"runtime_instance_id": str(card_binding.get("runtime_instance_id", "")),
		"transaction_id": play_transaction_id,
		"region_id": "region.no-demand",
		"expected_player_revision": int(player_after_purchase.get("revision", -1)),
		"expected_source_revision": int(source_after_purchase.get("revision", -1)),
	}
	var play: Dictionary = coordinator.call("play_runtime_card", play_request)
	_expect(bool(play.get("available", false)) and bool(play.get("committed", false)) and bool(play.get("finalized", false)), "narrow port plays through the real CardFlow and composite facility owners")
	_expect((infrastructure.call("facilities_snapshot", false) as Array).size() == facilities_before.size() + 1, "play creates exactly one authoritative facility")
	_expect((flow.call("installations_snapshot", false) as Array).size() == installations_before.size() + 1, "play creates exactly one permanent CommodityFlow production installation")
	var source_after_play: Dictionary = coordinator.call("economic_source_snapshot", actor_id)
	_expect(bool(source_after_play.get("has_source", false)) and bool(source_after_play.get("bootstrap_finalized", false)), "source snapshot derives finalized bootstrap state from existing owners and journal")
	_expect(str(source_after_play.get("lineage_transaction_id", "")) == play_transaction_id and int(source_after_play.get("revision", -1)) != int(source_before.get("revision", -1)), "source lineage and revision come from the existing transaction journal")
	var play_replay: Dictionary = coordinator.call("play_runtime_card", play_request)
	_expect(bool(play_replay.get("committed", false)) and bool(play_replay.get("idempotent_replay", false)), "play transaction replay is exact-once")
	_expect((infrastructure.call("facilities_snapshot", false) as Array).size() == facilities_before.size() + 1 and (flow.call("installations_snapshot", false) as Array).size() == installations_before.size() + 1, "play replay duplicates neither owner state")
	var journal_after: Dictionary = inventory.call("transaction_journal_snapshot")
	_expect(journal_after.size() == journal_before.size() + 2 and journal_after.has(purchase_transaction_id) and journal_after.has(play_transaction_id), "purchase and play persist only in the existing Inventory/CardFlow journal")

	coordinator.queue_free()
	world.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print("AI_V06_FACILITY_PRODUCTION_PORT_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(_failures.size())
