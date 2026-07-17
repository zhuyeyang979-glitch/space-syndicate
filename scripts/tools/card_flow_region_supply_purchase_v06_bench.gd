extends Node

const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")
const RULESET_V04 := preload("res://resources/rules/space_syndicate_ruleset_v04.tres")

var _checks := 0
var _failures: Array[String] = []


class RuntimeWorld:
	extends Node

	var players: Array = [
		{
			"id": 0,
			"name": "Current Player",
			"cash": 100,
			"cash_cents": 10000,
			"slots": [],
		},
		{
			"id": 1,
			"name": "Private Rival",
			"cash": 987654,
			"cash_cents": 98765400,
			"slots": [],
		},
	]
	var game_time := 0.0
	var map_width_m := 1000.0
	var districts: Array = [
		{
			"name": "Alpha",
			"region_id": "region.alpha",
			"terrain": "land",
			"center": Vector2.ZERO,
			"neighbors": [],
			"destroyed": false,
		},
	]
	var monster_runtime_controller: Node = null


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var coordinator := COORDINATOR_SCENE.instantiate()
	add_child(coordinator)
	await get_tree().process_frame
	coordinator.call(
		"configure",
		RULESET_V04.debug_snapshot()
	)
	var world := RuntimeWorld.new()
	add_child(world)
	coordinator.call("bind_ai_world", world)
	var inventory: Node = coordinator.call(
		"commodity_card_inventory_runtime_controller"
	)
	var source: Node = coordinator.get_node_or_null(
		"RegionSupplyRuntimeController"
	)
	_check(inventory != null and source != null, "production_owners_present")
	if inventory == null or source == null:
		_finish()
		return
	_check(
		bool((inventory.call("debug_snapshot") as Dictionary).get("controller_ready", false)),
		"coordinator_configured"
	)
	var catalog: Resource = inventory.call("catalog")
	var supply_configured: Dictionary = source.call(
		"configure",
		46017,
		[
			{
				"region_id": "region.alpha",
				"region_index": 0,
				"display_name": "Alpha",
				"terrain": "land",
				"active": true,
				"destroyed": false,
			},
		],
		[
			_card_descriptor(catalog, "facility.road.rank_1"),
			_card_descriptor(catalog, "facility.seaport.rank_1"),
			_card_descriptor(catalog, "facility.orbital_warehouse.rank_1"),
		],
		2
	)
	_check(bool(supply_configured.get("configured", false)), "region_supply_configured")
	var source_binding: Dictionary = inventory.call(
		"set_region_supply_source_port",
		source
	)
	_check(bool(source_binding.get("configured", false)), "card_flow_source_port_bound")
	var before_snapshot: Dictionary = source.call(
		"public_rack_snapshot",
		"region.alpha"
	)
	var before_slots := _slots(before_snapshot)
	_check(before_slots.size() == 2, "two_public_slots_ready")
	if before_slots.size() < 2:
		_finish()
		return
	var listing: Dictionary = before_slots[0] as Dictionary
	var other_before := JSON.stringify(before_slots[1])
	var player_before: Dictionary = inventory.call("player_snapshot", "player.0")
	var quote: Dictionary = coordinator.call("card_market_quote", {
		"player_index": 0,
		"district_index": int(listing.get("source_district_index", -1)),
		"card_id": str(listing.get("card_id", "")),
		"supply_revision": str(listing.get("supply_revision", "")),
		"base_price": int(listing.get("price_cash", -1)),
	})
	var quote_request := {
		"quote_id": str(quote.get("quote_id", "")),
		"quote_fingerprint": str(quote.get("quote_fingerprint", "")),
		"player_index": 0,
		"district_index": int(listing.get("source_district_index", -1)),
		"card_id": str(listing.get("card_id", "")),
		"supply_revision": str(listing.get("supply_revision", "")),
		"source_region_id": str(listing.get("source_region_id", "")),
		"slot_index": int(listing.get("slot_index", -1)),
		"source_item_id": str(listing.get("item_id", "")),
	}
	var purchase: Dictionary = inventory.call(
		"purchase_region_supply_card",
		"player.0",
		str(listing.get("source_region_id", "")),
		int(listing.get("slot_index", -1)),
		str(listing.get("item_id", "")),
		str(listing.get("card_id", "")),
		int(player_before.get("revision", -1)),
		str(listing.get("supply_revision", "")),
		"bench:region-supply-purchase",
		quote_request
	)
	if not bool(purchase.get("committed", false)):
		print("CARD_FLOW_REGION_SUPPLY_PURCHASE_V06_BENCH_DIAG|listing=%s|player=%s|quote=%s|purchase=%s" % [
			JSON.stringify(listing),
			JSON.stringify(player_before),
			JSON.stringify(quote),
			JSON.stringify(purchase),
		])
	_check(bool(purchase.get("committed", false)), "purchase_committed")
	_check(bool((purchase.get("region_supply_finalization", {}) as Dictionary).get("finalized", false)), "source_finalized")
	var player_after: Dictionary = inventory.call("player_snapshot", "player.0")
	_check(
		int(player_after.get("cash", -1))
			== int(player_before.get("cash", -1)) - int(purchase.get("cash_debit", -1)),
		"cash_debited_once"
	)
	_check(_card_count(player_after) == 1, "card_received_once")
	var after_slots := _slots(source.call("public_rack_snapshot", "region.alpha"))
	_check(
		after_slots.size() == 2
			and str((after_slots[0] as Dictionary).get("item_id", ""))
				!= str(listing.get("item_id", "")),
		"selected_slot_refilled"
	)
	_check(
		after_slots.size() == 2
			and JSON.stringify(after_slots[1]) == other_before,
		"other_slot_unchanged"
	)
	var replay: Dictionary = inventory.call(
		"purchase_region_supply_card",
		"player.0",
		str(listing.get("source_region_id", "")),
		int(listing.get("slot_index", -1)),
		str(listing.get("item_id", "")),
		str(listing.get("card_id", "")),
		int(player_before.get("revision", -1)),
		str(listing.get("supply_revision", "")),
		"bench:region-supply-purchase",
		quote_request
	)
	_check(
		bool(replay.get("committed", false))
			and bool(replay.get("idempotent_replay", false)),
		"replay_exact_once"
	)
	_check(
		int((inventory.call("player_snapshot", "player.0") as Dictionary).get("cash", -1))
			== int(player_after.get("cash", -1))
			and _card_count(inventory.call("player_snapshot", "player.0") as Dictionary) == 1,
		"replay_no_duplicate_mutation"
	)
	var public_text := JSON.stringify(purchase.get("public_receipt", {}))
	_check(
		not public_text.contains("987654")
			and not public_text.contains("quote_fingerprint")
			and not public_text.contains("bag"),
		"public_receipt_private_safe"
	)
	_check(
		not public_text.contains(str(listing.get("card_id", "")))
			and not public_text.contains("price_cash")
			and not public_text.contains("actor"),
		"public_receipt_keeps_specific_purchase_private"
	)
	_check(
		bool((inventory.call("checkpoint_status") as Dictionary).get("can_checkpoint", false)),
		"checkpoint_ready"
	)
	_finish()


func _slots(snapshot: Dictionary) -> Array:
	var regions: Array = snapshot.get("regions", []) \
		if snapshot.get("regions", []) is Array else []
	if regions.is_empty() or not (regions[0] is Dictionary):
		return []
	return ((regions[0] as Dictionary).get("slots", []) as Array).duplicate(true) \
		if (regions[0] as Dictionary).get("slots", []) is Array else []


func _card_count(player: Dictionary) -> int:
	var inventory: Dictionary = player.get("inventory", {}) \
		if player.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	var count := 0
	for slot_variant in slots:
		if slot_variant is Dictionary:
			count += 1
	return count


func _card_descriptor(catalog: Resource, card_id: String) -> Dictionary:
	var card: Dictionary = catalog.call("card_snapshot", card_id) \
		if catalog != null and catalog.has_method("card_snapshot") else {}
	var machine: Dictionary = card.get("machine", {}) \
		if card.get("machine", {}) is Dictionary else {}
	return {
		"card_id": card_id,
		"family_id": str(machine.get("family_id", card_id)),
		"card_type": str(machine.get("category_id", "ordinary")),
		"rank": int(machine.get("rank", 1)),
		"display_name": str(card.get("display_name", card_id)),
		"price_cash": maxi(0, int(machine.get("purchase_cash", 0))),
		"enabled": true,
		"retired": false,
		"valid": not card.is_empty(),
		"potential_target_exists": true,
		"is_commodity": false,
		"region_supply_weight": 1,
	}


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(label)
	push_error("CARD_FLOW_REGION_SUPPLY_PURCHASE_V06_BENCH_FAIL|%s" % label)


func _finish() -> void:
	if _failures.is_empty():
		print("CARD_FLOW_REGION_SUPPLY_PURCHASE_V06_BENCH|status=PASS|checks=%d|failures=0" % _checks)
		get_tree().quit(0)
		return
	print("CARD_FLOW_REGION_SUPPLY_PURCHASE_V06_BENCH|status=FAIL|checks=%d|failures=%d|details=%s" % [
		_checks,
		_failures.size(),
		JSON.stringify(_failures),
	])
	get_tree().quit(1)
