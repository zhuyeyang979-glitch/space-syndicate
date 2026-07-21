extends SceneTree

const SESSION_DRIVER := preload("res://tests/support/production_session_start_driver.gd")
const QA_SAVE_PATH := "user://test_runs/district_supply_runtime_query_port_cutover.save"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var start: Dictionary = await SESSION_DRIVER.start_configured_session(
		self,
		{
			"player_count": 3,
			"ai_player_count": 2,
			"challenge_depth": 1,
			"role_indices": [0, 1, 2],
			"starter_monster_indices": [0, 1, 2],
		},
		QA_SAVE_PATH,
		"district-supply-runtime-query-cutover"
	)
	var app_root := start.get("main_root") as Node
	var coordinator := start.get("coordinator") as GameRuntimeCoordinator
	_expect(bool(start.get("started", false)) and coordinator != null, "production session composes the query boundary")
	if coordinator == null:
		await _finish(app_root)
		return
	coordinator.pause_session()
	await process_frame
	var query := coordinator.district_supply_runtime_query_port()
	var region_supply := coordinator.get_node_or_null("RegionSupplyRuntimeController") as RegionSupplyRuntimeController
	var inventory := coordinator.get_node_or_null("CommodityCardInventoryRuntimeController") as CommodityCardInventoryRuntimeController
	var purchase := coordinator.get_node_or_null("DistrictPurchaseRuntimeController") as DistrictPurchaseRuntimeController
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController
	_expect(query != null and region_supply != null and inventory != null and purchase != null, "query uses RegionSupply plus the unique production CommodityCardInventory owner")
	_expect(coordinator.find_children("DistrictSupplyRuntimeQueryPort", "DistrictSupplyRuntimeQueryPort", true, false).size() == 1, "exactly one runtime query port exists")
	if query == null or region_supply == null or inventory == null or purchase == null:
		await _finish(app_root)
		return
	var world := coordinator.world_session_state()
	var district_index := _first_rack_district(world, region_supply)
	_expect(district_index >= 0, "authoritative rack is available")
	if district_index < 0:
		await _finish(app_root)
		return
	var region_id := world.region_id_for_district(district_index)
	var owner_rack := region_supply.public_rack_snapshot(region_id)
	var owner_ids := _card_ids(owner_rack)
	var supply_before := region_supply.to_save_data()
	var inventory_before := inventory.debug_snapshot()
	var purchase_before := purchase.debug_snapshot()
	var query_ids := query.public_card_ids_for_district(district_index)
	var listing := query.public_listing_for_district(district_index, str(query_ids[0]) if not query_ids.is_empty() else "")
	var unauthorized_plan := query.private_inventory_plan_for_actor(null, 1, str(query_ids[0]) if not query_ids.is_empty() else "")
	var unauthorized_human_plan := query.private_inventory_plan_for_actor(DistrictSupplyAiQueryCapability.new(), 0, str(query_ids[0]) if not query_ids.is_empty() else "")
	var ai_discardable: Variant = ai.call("_discardable_hand_slots_for_purchase", 1) if ai != null else null
	_expect(query_ids == owner_ids and not query_ids.is_empty(), "public query exactly matches the authoritative current rack")
	_expect(not listing.is_empty() and int(listing.get("price_cash", -1)) >= 0, "public listing preserves authoritative rack price")
	_expect(region_supply.to_save_data() == supply_before, "public query does not refill, reshuffle or expose future bag state")
	_expect(inventory.debug_snapshot() == inventory_before, "AI inventory preview does not mutate inventory diagnostics")
	_expect(purchase.debug_snapshot() == purchase_before, "query does not create quotes or purchase windows")
	_expect(unauthorized_plan.is_empty() and unauthorized_human_plan.is_empty(), "private inventory facts reject missing, forged and human-seat authorization")
	_expect(ai_discardable is Array, "the injected AI capability can read only its own inventory feasibility")
	var public_text := JSON.stringify({"ids": query_ids, "listing": listing})
	for forbidden in ["player_cash", "hand", "discard", "ai_plan", "true_owner", "owner_truth", "future_bag"]:
		_expect(not public_text.to_lower().contains(forbidden), "public query omits %s" % forbidden)
	var ai_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_runtime_controller.gd")
	for retired_call in [
		"_call_world(&\"_district_supply_card_ids\"",
		"_call_world(&\"_district_market_currently_purchasable\"",
		"_call_world(&\"_discardable_hand_slots_for_purchase\"",
		"_call_world(&\"_player_can_receive_card_with_discard\"",
		"_call_world(&\"_purchase_requires_discard\"",
	]:
		_expect(not ai_source.contains(retired_call), "AI no longer uses Main query %s" % retired_call)
	var diagnostics_source := FileAccess.get_file_as_string("res://scripts/runtime/gameplay_balance_diagnostics_world_bridge.gd")
	var codex_source := FileAccess.get_file_as_string("res://scripts/runtime/region_infrastructure_world_bridge.gd")
	var query_source := FileAccess.get_file_as_string("res://scripts/runtime/district_supply_runtime_query_port.gd")
	_expect(not diagnostics_source.contains("_world_array_call(&\"_district_supply_card_ids\""), "developer diagnostics reads the public typed query")
	_expect(not codex_source.contains("_world.call(\"_district_supply_card_ids\""), "region codex reads the public typed query")
	_expect(query_source.contains("CommodityCardInventoryRuntimeController") and query_source.contains("region_supply_receive_preview"), "AI feasibility is projected by the production CommodityCardInventory/CardFlow owner")
	_expect(not query_source.contains("CardInventoryRuntimeService") and not query_source.contains("current_facts"), "query port has no duplicate legacy inventory projection")
	var debug := query.debug_snapshot()
	_expect(not bool(debug.get("mutates_gameplay", true)) and not bool(debug.get("reads_future_supply_bag", true)) and not bool(debug.get("references_main", true)), "query boundary is read-only and Main-free")
	_expect(bool(debug.get("ai_capability_bound", false)) and int(debug.get("rejected_query_count", 0)) >= 2, "AI-private query capability is bound and unauthorized reads are audited")
	var game_session := coordinator.get_node_or_null("GameSessionRuntimeController") as GameSessionRuntimeController
	if game_session != null:
		game_session.finish_session({"reason": "query_terminal_copy_test"})
	_expect(
		game_session != null
		and not query.public_market_purchasable(district_index)
		and query.public_market_availability_text(district_index).contains("仅供查看"),
		"finished sessions expose browse-only availability without contradictory purchase copy"
	)
	await _finish(app_root)


func _first_rack_district(world: WorldSessionState, supply: RegionSupplyRuntimeController) -> int:
	for district_index in range(world.districts.size()):
		if not _card_ids(supply.public_rack_snapshot(world.region_id_for_district(district_index))).is_empty():
			return district_index
	return -1


func _card_ids(rack: Dictionary) -> Array:
	var result: Array = []
	for row_variant in rack.get("regions", []) as Array:
		if not (row_variant is Dictionary):
			continue
		for listing_variant in (row_variant as Dictionary).get("slots", []) as Array:
			if listing_variant is Dictionary:
				var card_id := str((listing_variant as Dictionary).get("card_id", ""))
				if not card_id.is_empty():
					result.append(card_id)
	return result


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % label)
	else:
		_failures.append(label)
		push_error("FAIL: %s" % label)


func _finish(app_root: Node) -> void:
	if app_root != null:
		app_root.queue_free()
	await process_frame
	print("DISTRICT_SUPPLY_RUNTIME_QUERY_PORT_CUTOVER %d/%d" % [_checks - _failures.size(), _checks])
	quit(0 if _failures.is_empty() else 1)
