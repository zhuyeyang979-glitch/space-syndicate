extends Node
class_name CardFlowRegionSupplyProductionWiringV06Bench

const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")
const RULESET_V04 := preload("res://resources/rules/space_syndicate_ruleset_v04.tres")

@export var auto_run := true
@export var quit_on_finish := true

var last_result: Dictionary = {}
var _checks := 0
var _failures: Array[String] = []
var _running := false


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
	if auto_run:
		call_deferred("_run_and_finish")


func run_checks() -> Dictionary:
	if _running:
		return {
			"passed": false,
			"checks": _checks,
			"failures": ["bench_already_running"],
		}
	_running = true
	_checks = 0
	_failures.clear()

	var coordinator := COORDINATOR_SCENE.instantiate()
	add_child(coordinator)
	await get_tree().process_frame
	coordinator.call("configure", RULESET_V04.debug_snapshot())

	var inventory: Node = coordinator.call(
		"commodity_card_inventory_runtime_controller"
	)
	var source: Node = coordinator.call("region_supply_runtime_controller")
	_check(inventory != null and source != null, "production_owners_present")
	_check(
		_count_region_supply_owners(coordinator) == 1,
		"production_scene_has_one_region_supply_owner"
	)
	_check(
		coordinator.has_method("purchase_region_supply_card"),
		"thin_region_supply_purchase_facade_present"
	)
	_check(
		coordinator.has_method("commit_district_purchase_with_region_supply"),
		"legacy_bridge_retained_for_main_cutover"
	)
	if inventory == null or source == null:
		coordinator.queue_free()
		_running = false
		return _result()

	var inventory_debug: Dictionary = inventory.call("debug_snapshot")
	_check(
		bool(inventory_debug.get("region_supply_source_ready", false)),
		"configure_injects_scene_region_supply_source"
	)
	coordinator.call("reset_state")
	inventory_debug = inventory.call("debug_snapshot")
	_check(
		bool(inventory_debug.get("region_supply_source_ready", false)),
		"reset_rebinds_scene_region_supply_source"
	)
	coordinator.call("configure", RULESET_V04.debug_snapshot())
	inventory_debug = inventory.call("debug_snapshot")
	_check(
		bool(inventory_debug.get("controller_ready", false))
			and bool(inventory_debug.get("region_supply_source_ready", false)),
		"reconfigure_keeps_inventory_and_source_ready"
	)

	var world := RuntimeWorld.new()
	add_child(world)
	coordinator.call("bind_ai_world", world)
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
	_check(bool(supply_configured.get("configured", false)), "production_source_configured")
	var before_snapshot: Dictionary = source.call(
		"public_rack_snapshot",
		"region.alpha"
	)
	var before_slots := _slots(before_snapshot)
	_check(before_slots.size() == 2, "two_public_slots_ready")
	if before_slots.size() < 2:
		world.queue_free()
		coordinator.queue_free()
		_running = false
		return _result()

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
	var quote_request := _bound_quote_request(listing, quote)
	_check(
		not str(quote_request.get("quote_id", "")).is_empty()
			and not str(quote_request.get("quote_fingerprint", "")).is_empty(),
		"authoritative_quote_ready"
	)

	var wrong_request := _purchase_request(
		listing,
		int(player_before.get("revision", -1)),
		"bench:production-wiring:wrong-binding",
		quote_request
	)
	wrong_request["item_id"] = "%s.wrong" % str(listing.get("item_id", ""))
	var player_before_wrong := JSON.stringify(
		inventory.call("player_snapshot", "player.0")
	)
	var rack_before_wrong := JSON.stringify(
		source.call("public_rack_snapshot", "region.alpha")
	)
	var wrong_result: Dictionary = coordinator.call(
		"purchase_region_supply_card",
		wrong_request
	)
	_check(
		not bool(wrong_result.get("committed", false)),
		"wrong_binding_fails_closed"
	)
	_check(
		JSON.stringify(inventory.call("player_snapshot", "player.0"))
				== player_before_wrong
			and JSON.stringify(source.call("public_rack_snapshot", "region.alpha"))
				== rack_before_wrong,
		"wrong_binding_has_zero_player_or_rack_side_effects"
	)

	var purchase_request := _purchase_request(
		listing,
		int(player_before.get("revision", -1)),
		"bench:production-wiring:purchase",
		quote_request
	)
	var purchase: Dictionary = coordinator.call(
		"purchase_region_supply_card",
		purchase_request
	)
	if not bool(purchase.get("committed", false)):
		print("CARD_FLOW_REGION_SUPPLY_PRODUCTION_WIRING_V06_DIAG|listing=%s|player=%s|quote=%s|purchase=%s" % [
			JSON.stringify(listing),
			JSON.stringify(player_before),
			JSON.stringify(quote),
			JSON.stringify(purchase),
		])
	_check(bool(purchase.get("committed", false)), "facade_purchase_committed")
	_check(
		bool((purchase.get("region_supply_finalization", {}) as Dictionary).get("finalized", false)),
		"facade_purchase_finalizes_source"
	)
	var player_after: Dictionary = inventory.call("player_snapshot", "player.0")
	_check(
		int(player_after.get("cash", -1))
			== int(player_before.get("cash", -1))
				- int(purchase.get("cash_debit", -1)),
		"facade_debits_cash_once"
	)
	_check(_card_count(player_after) == 1, "facade_receives_card_once")
	var after_slots := _slots(source.call("public_rack_snapshot", "region.alpha"))
	_check(
		after_slots.size() == 2
			and str((after_slots[0] as Dictionary).get("item_id", ""))
				!= str(listing.get("item_id", "")),
		"facade_refills_selected_slot"
	)
	_check(
		after_slots.size() == 2
			and JSON.stringify(after_slots[1]) == other_before,
		"facade_leaves_other_slot_unchanged"
	)

	purchase["committed"] = false
	var replay: Dictionary = coordinator.call(
		"purchase_region_supply_card",
		purchase_request
	)
	_check(
		bool(replay.get("committed", false))
			and bool(replay.get("idempotent_replay", false)),
		"facade_returns_copy_and_replay_stays_canonical"
	)
	_check(
		int((inventory.call("player_snapshot", "player.0") as Dictionary).get("cash", -1))
				== int(player_after.get("cash", -1))
			and _card_count(
				inventory.call("player_snapshot", "player.0") as Dictionary
			) == 1,
		"facade_replay_has_no_duplicate_mutation"
	)
	var public_text := JSON.stringify(replay.get("public_receipt", {}))
	_check(
		not public_text.contains("987654")
			and not public_text.contains("quote_fingerprint")
			and not public_text.contains("bag")
			and not public_text.contains("actor")
			and not public_text.contains(str(listing.get("card_id", ""))),
		"facade_public_receipt_preserves_purchase_privacy"
	)

	var bare := GameRuntimeCoordinator.new()
	var unavailable: Dictionary = bare.purchase_region_supply_card(
		purchase_request
	)
	_check(
		not bool(unavailable.get("committed", false))
			and str(unavailable.get("reason_code", ""))
				== "region_supply_purchase_inventory_unavailable",
		"facade_missing_dependency_fails_closed"
	)
	bare.free()

	world.queue_free()
	coordinator.queue_free()
	await get_tree().process_frame
	_running = false
	return _result()


func _run_and_finish() -> void:
	last_result = await run_checks()
	if bool(last_result.get("passed", false)):
		print("CARD_FLOW_REGION_SUPPLY_PRODUCTION_WIRING_V06_BENCH|status=PASS|checks=%d|failures=0" % int(last_result.get("checks", 0)))
	else:
		print("CARD_FLOW_REGION_SUPPLY_PRODUCTION_WIRING_V06_BENCH|status=FAIL|checks=%d|failures=%d|details=%s" % [
			int(last_result.get("checks", 0)),
			(last_result.get("failures", []) as Array).size(),
			JSON.stringify(last_result.get("failures", [])),
		])
	if quit_on_finish:
		get_tree().quit(0 if bool(last_result.get("passed", false)) else 1)


func _purchase_request(
	listing: Dictionary,
	player_revision: int,
	transaction_id: String,
	quote_request: Dictionary
) -> Dictionary:
	return {
		"actor_id": "player.0",
		"region_id": str(listing.get("source_region_id", "")),
		"slot_index": int(listing.get("slot_index", -1)),
		"item_id": str(listing.get("item_id", "")),
		"card_id": str(listing.get("card_id", "")),
		"player_revision": player_revision,
		"supply_revision": str(listing.get("supply_revision", "")),
		"transaction_id": transaction_id,
		"quote_request": quote_request.duplicate(true),
	}


func _bound_quote_request(listing: Dictionary, quote: Dictionary) -> Dictionary:
	return {
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
	var slots: Array = inventory.get("slots", []) \
		if inventory.get("slots", []) is Array else []
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


func _count_region_supply_owners(root: Node) -> int:
	var count := 1 if root is RegionSupplyRuntimeController else 0
	for child in root.get_children():
		if child is Node:
			count += _count_region_supply_owners(child as Node)
	return count


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(label)
	push_error("CARD_FLOW_REGION_SUPPLY_PRODUCTION_WIRING_V06_FAIL|%s" % label)


func _result() -> Dictionary:
	return {
		"passed": _failures.is_empty(),
		"checks": _checks,
		"failures": _failures.duplicate(),
	}
