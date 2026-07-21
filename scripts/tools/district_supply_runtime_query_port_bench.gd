extends Node

func _ready() -> void:
	var coordinator := get_node_or_null("GameRuntimeCoordinator") as GameRuntimeCoordinator
	await get_tree().process_frame
	var query := coordinator.district_supply_runtime_query_port() if coordinator != null else null
	var world := coordinator.world_session_state() if coordinator != null else null
	if world != null:
		world.districts = [{"region_id": "region.042", "name": "QA区域", "terrain": "land", "destroyed": false}]
	var configured := coordinator.configure_region_supply(
		4242,
		[{"region_id": "region.042", "region_index": 0, "display_name": "QA区域", "terrain": "land", "active": true}],
		[{"card_id": "移动1", "family_id": "移动", "card_type": "ordinary", "rank": "I", "price_cash": 37, "valid": true}],
		1
	) if coordinator != null else {}
	var ids := query.public_card_ids_for_district(0) if query != null else []
	var listing := query.public_listing_for_district(0, "移动1") if query != null else {}
	var checks := [
		coordinator != null,
		query != null,
		bool(configured.get("configured", false)),
		ids == ["移动1"],
		int(listing.get("price_cash", -1)) == 37,
		not bool(query.debug_snapshot().get("references_main", true)) if query != null else false,
		not bool(query.debug_snapshot().get("mutates_gameplay", true)) if query != null else false,
		not bool(query.debug_snapshot().get("reads_future_supply_bag", true)) if query != null else false,
	]
	var passed := 0
	for check in checks:
		if bool(check):
			passed += 1
	print("DISTRICT_SUPPLY_RUNTIME_QUERY_PORT_BENCH PASS %d/%d" % [passed, checks.size()])
	if passed != checks.size():
		push_error("DistrictSupplyRuntimeQueryPort production composition failed")
	await get_tree().create_timer(5.0).timeout
	get_tree().quit(0 if passed == checks.size() else 1)
