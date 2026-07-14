extends Control
class_name InstalledCommodityContinuousEconomyCharacterizationBench

const PROFILE_PATH := "res://resources/rules/space_syndicate_ruleset_v06.tres"
const CATALOG_PATH := "res://resources/content/product_industry_catalog_v05.tres"
const CONTROLLER_SCENE_PATH := "res://scenes/runtime/CommodityFlowRuntimeController.tscn"
const BRIDGE_SCENE_PATH := "res://scenes/runtime/CommodityFlowWorldBridge.tscn"
const ROUTE_CONTROLLER_SCENE_PATH := "res://scenes/runtime/RouteNetworkRuntimeController.tscn"
const ROUTE_BRIDGE_SCENE_PATH := "res://scenes/runtime/RouteNetworkWorldBridge.tscn"
const COORDINATOR_SCENE_PATH := "res://scenes/runtime/GameRuntimeCoordinator.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const CONTROLLER_SCRIPT_PATH := "res://scripts/runtime/commodity_flow_runtime_controller.gd"
const BRIDGE_SCRIPT_PATH := "res://scripts/runtime/commodity_flow_world_bridge.gd"
const CITY_TRADE_SCRIPT_PATH := "res://scripts/runtime/city_trade_network_runtime_controller.gd"
const CASHFLOW_SCRIPT_PATH := "res://scripts/runtime/economy_cashflow_runtime_controller.gd"
const GDP_SCRIPT_PATH := "res://scripts/runtime/gdp_formula_runtime_controller.gd"
const PRODUCT_MARKET_SCRIPT_PATH := "res://scripts/runtime/product_market_runtime_controller.gd"
const OUTPUT_DIR := "user://space_syndicate_design_qa/multimodal_route_warehouse_hard_cutover/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/multimodal_route_warehouse_hard_cutover_sprint_3.png"

const CASE_IDS := [
	"controller_scene_loads", "world_bridge_scene_loads", "coordinator_static_composition",
	"v06_profile_configures", "real_product_catalog_used", "installation_schema_aligned",
	"sale_receipt_schema_aligned", "installation_transaction_exact_once", "invalid_direction_rejected",
	"production_requires_factory", "demand_requires_market", "rank_rate_table_10_20_40_80",
	"same_region_has_no_distance_premium", "adjacent_has_no_distance_premium",
	"distance_two_adds_twelve_percent", "distance_three_adds_twenty_four_percent",
	"distance_premium_caps_at_one_hundred_twenty_percent", "receipt_explains_linear_price",
	"shortest_route_prevents_distance_premium_farming",
	"one_source_splits_to_many_demands", "many_sources_feed_one_demand",
	"many_sources_feed_many_demands", "allocation_is_stable_by_identity",
	"facility_capacity_is_proportional", "region_integrity_scales_effective_flow",
	"missing_demand_creates_backpressure", "missing_route_creates_backpressure",
	"one_sold_unit_one_receipt", "cash_rent_gdp_mana_share_receipt_id",
	"public_receipt_hides_owner", "save_round_trip_preserves_installations",
	"legacy_project_save_is_rejected", "cash_bridge_is_atomic_and_exact_once",
	"economy_cashflow_not_composed", "gdp_formula_not_composed", "legacy_industry_capacity_not_composed",
	"legacy_project_and_cash_algorithms_absent", "city_trade_transition_removed",
	"product_market_no_longer_records_parallel_gdp", "main_legacy_cashflow_entry_absent",
	"single_authoritative_flow_owner", "all_snapshots_are_pure_data",
	"route_controller_scene_loads", "route_world_bridge_scene_loads", "coordinator_route_network_composition",
	"city_trade_runtime_retired", "same_or_adjacent_direct_exempt", "long_land_requires_roads",
	"sea_requires_ports", "air_requires_spaceports", "multimodal_route_tags",
	"canonical_distance_shared_across_detours", "route_priority_owner_net_first",
	"topology_revision_rebuild", "route_capacity_uses_integrity",
	"six_colored_warehouse_slots", "uncolored_warehouse_rejected", "wrong_color_warehouse_rejected",
	"warehouse_stores_before_backpressure", "warehouse_capacity_and_throughput_ranked",
	"warehouse_outflow_pays_owner_rent", "warehouse_rent_excluded_from_gdp",
	"full_warehouse_backpressures_continuous", "full_warehouse_loses_one_shot",
	"warehouse_destruction_loses_inventory_once", "warehouse_save_round_trip",
	"route_and_warehouse_snapshots_pure",
]

@export var auto_run := true

@onready var summary_label: Label = %SummaryLabel
@onready var status_label: Label = %StatusLabel
@onready var ownership_text: RichTextLabel = %OwnershipText
@onready var cases_text: RichTextLabel = %CasesText

var _profile: Resource
var _catalog: Resource
var _product_id := ""
var _industry_id := ""
var _evidence: Dictionary = {}
var _records: Array = []
var _failures: Array[String] = []


class FakeFlowBridge extends Node:
	var facts: Dictionary = {}
	var batches: Array = []
	var committed_notifications: Array = []
	var applied_batch_ids: Dictionary = {}

	func capture_flow_facts() -> Dictionary:
		return facts.duplicate(true)

	func apply_sale_receipt_batch(batch: Dictionary) -> Dictionary:
		var batch_id := str(batch.get("batch_id", ""))
		if batch_id.is_empty():
			return {"applied": false, "reason": "batch_id_missing"}
		if applied_batch_ids.has(batch_id):
			return {"applied": true, "duplicate": true, "batch_id": batch_id}
		applied_batch_ids[batch_id] = true
		batches.append(batch.duplicate(true))
		return {"applied": true, "duplicate": false, "batch_id": batch_id}

	func notify_sale_receipt_batch_committed(batch: Dictionary) -> void:
		committed_notifications.append(batch.duplicate(true))


class FakeRouteBridge extends Node:
	var topology: Dictionary = {}

	func capture_route_topology() -> Dictionary:
		return topology.duplicate(true)


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_characterization_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func screenshot_path() -> String:
	return SCREENSHOT_PATH


func characterization_cases() -> Array:
	return CASE_IDS.duplicate()


func build_characterization_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id in CASE_IDS:
		records.append(_record(str(case_id), false, "preview"))
	return {"suite": "multimodal-route-warehouse-hard-cutover-ss06-03", "ruleset_id": "v0.6", "runtime_cutover_enabled": true, "case_count": CASE_IDS.size(), "records": records}


func run_suite() -> void:
	run_characterization_suite()


func run_characterization_suite() -> void:
	_records.clear()
	_failures.clear()
	_profile = load(PROFILE_PATH)
	_catalog = load(CATALOG_PATH)
	_resolve_real_product()
	_prepare_output_dir()
	_collect_evidence()
	for case_id in CASE_IDS:
		var record := _evaluate(str(case_id))
		record["pure_data_checked"] = _is_pure_data(record)
		record["passed"] = bool(record.get("passed", false)) and bool(record.get("pure_data_checked", false))
		_records.append(record)
		if not bool(record.get("passed", false)):
			_failures.append("%s: %s" % [str(record.get("case_id", "")), str(record.get("notes", "failed"))])
	var manifest := {
		"suite": "multimodal-route-warehouse-hard-cutover-ss06-03",
		"ruleset_id": "v0.6",
		"runtime_cutover_enabled": true,
		"case_count": CASE_IDS.size(),
		"passed_count": _count_passed(),
		"failed_count": _failures.size(),
		"distance_price_rule": "base_price_x_(1+12%*max(0,distance-1)), capped at +120%",
		"allocation_model": "deterministic_many_source_many_sink_proportional_capacity_flow",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"records": _records.duplicate(true),
	}
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text(REPORT_PATH, _report(manifest))
	_update_ui(manifest)
	await get_tree().process_frame
	await get_tree().process_frame
	_save_screenshot()
	print("InstalledCommodityContinuousEconomyCharacterizationBench manifest: %s" % MANIFEST_PATH)
	print("InstalledCommodityContinuousEconomyCharacterizationBench report: %s" % REPORT_PATH)
	print("InstalledCommodityContinuousEconomyCharacterizationBench screenshot: %s" % SCREENSHOT_PATH)
	print("InstalledCommodityContinuousEconomyCharacterizationBench SS06-03 passed: %d/%d" % [_count_passed(), CASE_IDS.size()])
	if not _failures.is_empty():
		push_error("SS06-03 failed:\n- %s" % "\n- ".join(_failures))
	if DisplayServer.get_name() == "headless":
		for _frame in range(3):
			await get_tree().process_frame
		get_tree().quit(0 if _failures.is_empty() else 1)


func _collect_evidence() -> void:
	_evidence = {
		"same": _run_fixture(1, 1, 0, true),
		"adjacent": _run_fixture(1, 1, 1, true),
		"distance_two": _run_fixture(1, 1, 2, true),
		"distance_three": _run_fixture(1, 1, 3, true),
		"distance_cap": _run_fixture(1, 1, 20, true),
		"route_choice": _run_route_choice_fixture(),
		"one_many": _run_fixture(1, 2, 2, true),
		"many_one": _run_fixture(2, 1, 2, true),
		"many_many": _run_fixture(2, 2, 2, true),
		"many_many_reverse": _run_fixture(2, 2, 2, true, true),
		"capacity": _run_fixture(5, 4, 1, true, false, 10000, 10000, true),
		"integrity": _run_fixture(1, 1, 1, true, false, 5000, 5000),
		"no_demand": _run_fixture(1, 0, 1, true),
		"no_route": _run_fixture(1, 1, 3, false),
		"route_network": _route_network_evidence(),
		"warehouse": _run_warehouse_fixture(true),
		"warehouse_wrong_color": _run_warehouse_fixture(false),
		"warehouse_full": _run_full_warehouse_fixture(),
		"warehouse_color_slots": _warehouse_color_slot_fixture(),
	}
	_evidence["save"] = _save_round_trip()
	_evidence["installation"] = _installation_exact_once()


func _route_network_evidence() -> Dictionary:
	var land_regions := [
		_route_region("land-a", "land", ["land-b"]),
		_route_region("land-b", "land", ["land-a", "land-c"]),
		_route_region("land-c", "land", ["land-b"]),
	]
	var land_facilities := [
		_route_facility("road-a", "land-a", "road", 1),
		_route_facility("road-b", "land-b", "road", 1),
		_route_facility("road-c", "land-c", "road", 1),
		_route_facility("spaceport-a", "land-a", "spaceport", 1),
		_route_facility("spaceport-c", "land-c", "spaceport", 1),
	]
	var land_topology := _route_topology(land_regions, land_facilities, "land-v1")
	var no_roads := _route_topology(land_regions, [], "no-roads-v1")
	var sea_topology := _route_topology([
		_route_region("sea-a", "land", ["sea-water"]),
		_route_region("sea-water", "ocean", ["sea-a", "sea-c"]),
		_route_region("sea-c", "land", ["sea-water"]),
	], [
		_route_facility("port-a", "sea-a", "port", 1),
		_route_facility("port-water", "sea-water", "port", 1),
		_route_facility("port-c", "sea-c", "port", 1),
	], "sea-v1")
	var air_topology := _route_topology([
		_route_region("air-a", "land", []),
		_route_region("air-c", "land", []),
	], [
		_route_facility("air-a-port", "air-a", "spaceport", 1),
		_route_facility("air-c-port", "air-c", "spaceport", 1),
	], "air-v1")
	var multimodal_topology := _route_topology([
		_route_region("multi-a", "land", ["multi-b"]),
		_route_region("multi-b", "land", ["multi-a", "multi-water"]),
		_route_region("multi-water", "ocean", ["multi-b"]),
	], [
		_route_facility("multi-road-a", "multi-a", "road", 1),
		_route_facility("multi-road-b", "multi-b", "road", 1),
		_route_facility("multi-port-b", "multi-b", "port", 1),
		_route_facility("multi-port-water", "multi-water", "port", 1),
	], "multi-v1")
	var integrity_topology := _route_topology([
		_route_region("integrity-a", "land", ["integrity-b"]),
		_route_region("integrity-b", "land", ["integrity-a", "integrity-c"], 5000),
		_route_region("integrity-c", "land", ["integrity-b"]),
	], [
		_route_facility("integrity-road-a", "integrity-a", "road", 1),
		_route_facility("integrity-road-b", "integrity-b", "road", 1),
		_route_facility("integrity-road-c", "integrity-c", "road", 1),
	], "integrity-v1")
	return {
		"direct": _route_query(land_topology, "land-a", "land-b"),
		"land": _route_query(land_topology, "land-a", "land-c"),
		"no_roads": _route_query(no_roads, "land-a", "land-c"),
		"sea": _route_query(sea_topology, "sea-a", "sea-c"),
		"air": _route_query(air_topology, "air-a", "air-c"),
		"multimodal": _route_query(multimodal_topology, "multi-a", "multi-water"),
		"integrity": _route_query(integrity_topology, "integrity-a", "integrity-c"),
		"revision": _route_revision_fixture(land_topology, no_roads),
		"owner_net": _run_owner_net_route_fixture(),
	}


func _route_query(topology: Dictionary, source_region_id: String, market_region_id: String) -> Dictionary:
	var controller := RouteNetworkRuntimeController.new()
	var bridge := FakeRouteBridge.new()
	add_child(controller)
	add_child(bridge)
	bridge.topology = topology.duplicate(true)
	controller.set_world_bridge(bridge)
	var configured := controller.configure(_profile.debug_snapshot())
	var refreshed := controller.refresh_routes(true)
	var candidates := controller.route_candidates_for_regions(_product_id, source_region_id, market_region_id)
	var debug := controller.debug_snapshot()
	controller.queue_free()
	bridge.queue_free()
	return {"configured": configured, "refreshed": refreshed, "candidates": candidates, "debug": debug}


func _route_revision_fixture(first_topology: Dictionary, second_topology: Dictionary) -> Dictionary:
	var controller := RouteNetworkRuntimeController.new()
	var bridge := FakeRouteBridge.new()
	add_child(controller)
	add_child(bridge)
	controller.set_world_bridge(bridge)
	controller.configure(_profile.debug_snapshot())
	bridge.topology = first_topology.duplicate(true)
	var first := controller.refresh_routes(true)
	bridge.topology = second_topology.duplicate(true)
	var second := controller.refresh_routes(false)
	var debug := controller.debug_snapshot()
	controller.queue_free()
	bridge.queue_free()
	return {"first": first, "second": second, "debug": debug}


func _run_owner_net_route_fixture() -> Dictionary:
	var controller := CommodityFlowRuntimeController.new()
	var bridge := FakeFlowBridge.new()
	add_child(controller)
	add_child(bridge)
	controller.set_world_bridge(bridge)
	controller.configure(_profile.debug_snapshot())
	var source_region_id := "net-source"
	var market_region_id := "net-market"
	var factory := _facility("net-factory", source_region_id, "factory", 1)
	var market := _facility("net-market", market_region_id, "market", 1)
	var expensive := _route(source_region_id, market_region_id, 2)
	expensive["route_id"] = "route:fast-expensive"
	expensive["arrival_seconds"] = 1.0
	expensive["expected_rents"] = [{"facility_id": "rent-road", "facility_type": "road", "recipient_player_index": 2, "amount_per_unit_cents": 2000}]
	var profitable := _route(source_region_id, market_region_id, 2)
	profitable["route_id"] = "route:owner-net"
	profitable["arrival_seconds"] = 5.0
	bridge.facts = {"game_time": 60.0, "regions": [_region(source_region_id, 10000, []), _region(market_region_id, 10000, [])], "facilities": [factory, market], "destroyed_facility_ids": [], "price_cents_by_commodity": {_product_id: 10000}, "route_candidates": [expensive, profitable]}
	var production := _install_request("net-production", "net-production-tx", "net-factory", source_region_id, "production", 0)
	production["facility"] = factory
	var demand := _install_request("net-demand", "net-demand-tx", "net-market", market_region_id, "demand", 1)
	demand["facility"] = market
	controller.install_commodity(production)
	controller.install_commodity(demand)
	controller.advance_world(60.0, {})
	var receipts: Array = (bridge.batches[0] as Dictionary).get("receipts", []).duplicate(true) if not bridge.batches.is_empty() else []
	controller.queue_free()
	bridge.queue_free()
	return {"receipts": receipts}


func _run_warehouse_fixture(color_match: bool) -> Dictionary:
	var controller := CommodityFlowRuntimeController.new()
	var bridge := FakeFlowBridge.new()
	add_child(controller)
	add_child(bridge)
	controller.set_world_bridge(bridge)
	controller.configure(_profile.debug_snapshot())
	var region_id := "warehouse-region"
	var factory := _facility("warehouse-factory", region_id, "factory", 1, _industry_id, 0)
	var warehouse_industry := _industry_id if color_match else _other_industry_id()
	var warehouse := _facility("warehouse-colored", region_id, "warehouse", 1, warehouse_industry, 2)
	bridge.facts = {"game_time": 60.0, "regions": [_region(region_id, 10000, [])], "facilities": [factory, warehouse], "destroyed_facility_ids": [], "price_cents_by_commodity": {_product_id: 10000}, "route_candidates": []}
	var production := _install_request("warehouse-production", "warehouse-production-tx", "warehouse-factory", region_id, "production", 0)
	production["facility"] = factory
	controller.install_commodity(production)
	var store_advance := controller.advance_world(60.0, {})
	var stored_snapshot := controller.warehouse_inventory_snapshot(0)
	var save_after_store := controller.to_save_data()
	var market := _facility("warehouse-market", region_id, "market", 1, _industry_id, 1)
	var demand := _install_request("warehouse-demand", "warehouse-demand-tx", "warehouse-market", region_id, "demand", 1)
	demand["facility"] = market
	controller.install_commodity(demand)
	bridge.facts = {"game_time": 120.0, "regions": [_region(region_id, 10000, [])], "facilities": [warehouse, market], "destroyed_facility_ids": ["warehouse-factory"], "price_cents_by_commodity": {_product_id: 10000}, "route_candidates": []}
	var outflow_advance := controller.advance_world(60.0, {})
	var outflow_receipts: Array = (bridge.batches.back() as Dictionary).get("receipts", []).duplicate(true) if not bridge.batches.is_empty() else []
	var final_snapshot := controller.warehouse_inventory_snapshot(0)
	controller.queue_free()
	bridge.queue_free()
	return {"store_advance": store_advance, "stored_snapshot": stored_snapshot, "save_after_store": save_after_store, "outflow_advance": outflow_advance, "outflow_receipts": outflow_receipts, "final_snapshot": final_snapshot}


func _run_full_warehouse_fixture() -> Dictionary:
	var controller := CommodityFlowRuntimeController.new()
	var bridge := FakeFlowBridge.new()
	add_child(controller)
	add_child(bridge)
	controller.set_world_bridge(bridge)
	controller.configure(_profile.debug_snapshot())
	var region_id := "full-warehouse-region"
	var factory := _facility("full-factory", region_id, "factory", 4, _industry_id, 0)
	var warehouse := _facility("full-warehouse", region_id, "warehouse", 1, _industry_id, 3)
	bridge.facts = {"game_time": 0.0, "regions": [_region(region_id, 10000, [])], "facilities": [factory, warehouse], "destroyed_facility_ids": [], "price_cents_by_commodity": {_product_id: 10000}, "route_candidates": []}
	var production := _install_request("full-production", "full-production-tx", "full-factory", region_id, "production", 0, 4)
	production["facility"] = factory
	controller.install_commodity(production)
	var fill_advances: Array = []
	for minute in range(1, 5):
		bridge.facts["game_time"] = float(minute * 60)
		fill_advances.append(controller.advance_world(60.0, {}))
	var full_snapshot := controller.warehouse_inventory_snapshot(0)
	var save_full := controller.to_save_data()
	bridge.facts["game_time"] = 300.0
	var full_backpressure := controller.advance_world(60.0, {})
	var one_shot_submit := controller.inject_one_shot_supply({"transaction_id": "full-one-shot", "commodity_id": _product_id, "region_id": region_id, "owner_player_index": 0, "units": 10})
	bridge.facts = {"game_time": 360.0, "regions": [_region(region_id, 10000, [])], "facilities": [warehouse], "destroyed_facility_ids": ["full-factory"], "price_cents_by_commodity": {_product_id: 10000}, "route_candidates": []}
	var one_shot_advance := controller.advance_world(60.0, {})
	var one_shot_replay := controller.inject_one_shot_supply({"transaction_id": "full-one-shot", "commodity_id": _product_id, "region_id": region_id, "owner_player_index": 0, "units": 10})
	bridge.facts = {"game_time": 420.0, "regions": [_region(region_id, 10000, [])], "facilities": [], "destroyed_facility_ids": ["full-factory", "full-warehouse"], "price_cents_by_commodity": {_product_id: 10000}, "route_candidates": []}
	var destruction_first := controller.advance_world(60.0, {})
	bridge.facts["game_time"] = 480.0
	var destruction_second := controller.advance_world(60.0, {})
	var restored := CommodityFlowRuntimeController.new()
	add_child(restored)
	restored.configure(_profile.debug_snapshot())
	var save_applied := restored.apply_save_data(save_full)
	var restored_save := restored.to_save_data()
	restored.queue_free()
	controller.queue_free()
	bridge.queue_free()
	return {"fill_advances": fill_advances, "full_snapshot": full_snapshot, "full_backpressure": full_backpressure, "one_shot_submit": one_shot_submit, "one_shot_advance": one_shot_advance, "one_shot_replay": one_shot_replay, "destruction_first": destruction_first, "destruction_second": destruction_second, "save_full": save_full, "save_applied": save_applied, "restored_save": restored_save}


func _warehouse_color_slot_fixture() -> Dictionary:
	var controller := RegionInfrastructureRuntimeController.new()
	add_child(controller)
	var configured := controller.configure(_profile.debug_snapshot())
	var initialized := controller.initialize_regions([{"region_id": "color-region", "terrain_id": "land", "neighbor_region_ids": [], "legacy_index": 0}])
	var slots := controller.standard_slot_ids("color-region")
	var commits: Array = []
	for industry_id in RegionInfrastructureRuntimeController.INDUSTRY_IDS:
		commits.append(controller.apply_facility_action({"transaction_id": "warehouse-%s" % industry_id, "region_id": "color-region", "facility_type": "warehouse", "industry_id": industry_id, "owner_kind": "player", "owner_player_index": 0, "rank": 1, "occurred_at": 0.0}))
	var invalid := controller.apply_facility_action({"transaction_id": "warehouse-uncolored", "region_id": "color-region", "facility_type": "warehouse", "industry_id": "", "owner_kind": "player", "owner_player_index": 0, "rank": 1, "occurred_at": 0.0})
	var facilities := controller.facilities_snapshot(false)
	controller.queue_free()
	return {"configured": configured, "initialized": initialized, "slots": slots, "commits": commits, "invalid": invalid, "facilities": facilities}


func _run_fixture(source_count: int, demand_count: int, distance: int, route_available: bool, reverse_install_order := false, source_integrity_bp := 10000, demand_integrity_bp := 10000, shared_facilities := false) -> Dictionary:
	var controller := CommodityFlowRuntimeController.new()
	var bridge := FakeFlowBridge.new()
	add_child(controller)
	add_child(bridge)
	controller.set_world_bridge(bridge)
	var configured: Dictionary = controller.configure(_profile.debug_snapshot())
	var source_region_ids: Array = []
	var demand_region_ids: Array = []
	for index in range(source_count):
		source_region_ids.append("source-shared" if shared_facilities else "source-%02d" % index)
	for index in range(demand_count):
		if distance == 0 and source_count == 1 and demand_count == 1:
			demand_region_ids.append(str(source_region_ids[0]))
		else:
			demand_region_ids.append("market-shared" if shared_facilities else "market-%02d" % index)
	var regions: Array = []
	var facilities: Array = []
	for index in range(source_count):
		var region_id := str(source_region_ids[index])
		if not _array_has_region(regions, region_id):
			regions.append(_region(region_id, source_integrity_bp, demand_region_ids if distance == 1 else []))
		facilities.append(_facility("factory-shared" if shared_facilities else "factory-%02d" % index, region_id, "factory", 1))
	for index in range(demand_count):
		var region_id := str(demand_region_ids[index])
		if not _array_has_region(regions, region_id):
			regions.append(_region(region_id, demand_integrity_bp, source_region_ids if distance == 1 else []))
		facilities.append(_facility("market-shared" if shared_facilities else "market-%02d" % index, region_id, "market", 1))
	var routes: Array = []
	if route_available and distance > 1:
		for source_region_id in source_region_ids:
			for demand_region_id in demand_region_ids:
				routes.append(_route(str(source_region_id), str(demand_region_id), distance))
	bridge.facts = {"game_time": 60.0, "regions": regions, "facilities": facilities, "destroyed_facility_ids": [], "price_cents_by_commodity": {_product_id: 10000}, "route_candidates": routes}
	var requests: Array = []
	for index in range(source_count):
		requests.append(_install_request("p-%02d" % index, "tx-p-%02d" % index, "factory-shared" if shared_facilities else "factory-%02d" % index, str(source_region_ids[index]), "production", 0))
	for index in range(demand_count):
		requests.append(_install_request("d-%02d" % index, "tx-d-%02d" % index, "market-shared" if shared_facilities else "market-%02d" % index, str(demand_region_ids[index]), "demand", 1))
	if reverse_install_order:
		requests.reverse()
	var install_results: Array = []
	for request_variant in requests:
		var request: Dictionary = request_variant
		request["facility"] = _facility_for_id(facilities, str(request.get("facility_id", "")))
		install_results.append(controller.install_commodity(request))
	var advance: Dictionary = controller.advance_world(60.0, {})
	var receipts: Array = (bridge.batches[0] as Dictionary).get("receipts", []).duplicate(true) if not bridge.batches.is_empty() else []
	var debug := controller.debug_snapshot()
	var save := controller.to_save_data()
	controller.queue_free()
	bridge.queue_free()
	return {"configured": configured, "installs": install_results, "advance": advance, "receipts": receipts, "debug": debug, "save": save}


func _installation_exact_once() -> Dictionary:
	var controller := CommodityFlowRuntimeController.new()
	add_child(controller)
	controller.configure(_profile.debug_snapshot())
	var facility := _facility("factory-once", "source-once", "factory", 1)
	var request := _install_request("once", "install-once", "factory-once", "source-once", "production", 0)
	request["facility"] = facility
	var first := controller.install_commodity(request)
	var second := controller.install_commodity(request)
	var invalid := request.duplicate(true)
	invalid["transaction_id"] = "invalid-direction"
	invalid["direction"] = "sideways"
	var invalid_result := controller.install_commodity(invalid)
	controller.queue_free()
	return {"first": first, "second": second, "invalid": invalid_result}


func _run_route_choice_fixture() -> Dictionary:
	var controller := CommodityFlowRuntimeController.new()
	var bridge := FakeFlowBridge.new()
	add_child(controller)
	add_child(bridge)
	controller.set_world_bridge(bridge)
	controller.configure(_profile.debug_snapshot())
	var source_region_id := "route-choice-source"
	var market_region_id := "route-choice-market"
	var factory := _facility("route-choice-factory", source_region_id, "factory", 1)
	var market := _facility("route-choice-market", market_region_id, "market", 1)
	bridge.facts = {
		"game_time": 60.0,
		"regions": [_region(source_region_id, 10000, [market_region_id]), _region(market_region_id, 10000, [source_region_id])],
		"facilities": [factory, market],
		"destroyed_facility_ids": [],
		"price_cents_by_commodity": {_product_id: 10000},
		"route_candidates": [_route(source_region_id, market_region_id, 5)],
	}
	var production := _install_request("route-choice-production", "route-choice-production-tx", "route-choice-factory", source_region_id, "production", 0)
	production["facility"] = factory
	var demand := _install_request("route-choice-demand", "route-choice-demand-tx", "route-choice-market", market_region_id, "demand", 1)
	demand["facility"] = market
	controller.install_commodity(production)
	controller.install_commodity(demand)
	var advance := controller.advance_world(60.0, {})
	var receipts: Array = (bridge.batches[0] as Dictionary).get("receipts", []).duplicate(true) if not bridge.batches.is_empty() else []
	controller.queue_free()
	bridge.queue_free()
	return {"advance": advance, "receipts": receipts}


func _save_round_trip() -> Dictionary:
	var fixture: Dictionary = _evidence.get("many_many", {}) if _evidence.has("many_many") else _run_fixture(2, 2, 2, true)
	var source_save: Dictionary = fixture.get("save", {})
	var controller := CommodityFlowRuntimeController.new()
	add_child(controller)
	controller.configure(_profile.debug_snapshot())
	var applied := controller.apply_save_data(source_save)
	var restored := controller.to_save_data()
	var legacy := controller.apply_save_data({"state_version": 1, "ruleset_id": "v0.6", "project_slots": []})
	controller.queue_free()
	return {"source": source_save, "applied": applied, "restored": restored, "legacy": legacy}


func _evaluate(case_id: String) -> Dictionary:
	var controller_source := FileAccess.get_file_as_string(CONTROLLER_SCRIPT_PATH)
	var bridge_source := FileAccess.get_file_as_string(BRIDGE_SCRIPT_PATH)
	var city_trade_source := FileAccess.get_file_as_string(CITY_TRADE_SCRIPT_PATH)
	var cashflow_source := FileAccess.get_file_as_string(CASHFLOW_SCRIPT_PATH)
	var gdp_source := FileAccess.get_file_as_string(GDP_SCRIPT_PATH)
	var product_market_source := FileAccess.get_file_as_string(PRODUCT_MARKET_SCRIPT_PATH)
	var route_controller_source := FileAccess.get_file_as_string("res://scripts/runtime/route_network_runtime_controller.gd")
	var region_infrastructure_source := FileAccess.get_file_as_string("res://scripts/runtime/region_infrastructure_runtime_controller.gd")
	var coordinator_scene := FileAccess.get_file_as_string(COORDINATOR_SCENE_PATH)
	var main_source := FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)
	var same: Dictionary = _evidence.get("same", {})
	var adjacent: Dictionary = _evidence.get("adjacent", {})
	var distance_two: Dictionary = _evidence.get("distance_two", {})
	var distance_three: Dictionary = _evidence.get("distance_three", {})
	var distance_cap: Dictionary = _evidence.get("distance_cap", {})
	var first_same := _first_receipt(same)
	var first_adjacent := _first_receipt(adjacent)
	var first_two := _first_receipt(distance_two)
	var first_three := _first_receipt(distance_three)
	var first_cap := _first_receipt(distance_cap)
	match case_id:
		"controller_scene_loads": return _record(case_id, load(CONTROLLER_SCENE_PATH) is PackedScene, "CommodityFlow controller is a real editable scene.")
		"world_bridge_scene_loads": return _record(case_id, load(BRIDGE_SCENE_PATH) is PackedScene, "WorldBridge is a real editable scene.")
		"coordinator_static_composition": return _record(case_id, coordinator_scene.contains("CommodityFlowRuntimeController.tscn") and coordinator_scene.contains("CommodityFlowWorldBridge.tscn"), "Coordinator statically composes both nodes.")
		"v06_profile_configures": return _record(case_id, bool((same.get("configured", {}) as Dictionary).get("configured", false)), "Controller accepts only v0.6 continuous-flow profile.")
		"real_product_catalog_used": return _record(case_id, not _product_id.is_empty() and not _industry_id.is_empty(), "Fixture uses a real catalog product and industry.")
		"installation_schema_aligned": return _record(case_id, _has_schema_fields("installed_commodity_rate", InstalledCommodityContinuousEconomyCharacterizationRegistry.REQUIRED_INSTALLATION_FIELDS), "Installed commodity schema matches runtime records.")
		"sale_receipt_schema_aligned": return _record(case_id, _has_schema_fields("commodity_sale_receipt", InstalledCommodityContinuousEconomyCharacterizationRegistry.REQUIRED_SALE_RECEIPT_FIELDS), "Sale receipt schema matches the unique ledger.")
		"installation_transaction_exact_once": return _record(case_id, bool(((_evidence.get("installation", {}) as Dictionary).get("first", {}) as Dictionary).get("committed", false)) and bool(((_evidence.get("installation", {}) as Dictionary).get("second", {}) as Dictionary).get("duplicate", false)), "Repeated installation transaction returns the original exact-once receipt.")
		"invalid_direction_rejected": return _record(case_id, not bool(((_evidence.get("installation", {}) as Dictionary).get("invalid", {}) as Dictionary).get("committed", true)), "Unknown production/demand direction fails closed.")
		"production_requires_factory": return _record(case_id, controller_source.contains('var expected_type := "factory" if direction == "production" else "market"'), "Production binds to a factory.")
		"demand_requires_market": return _record(case_id, controller_source.contains('else "market"'), "Demand binds to a market.")
		"rank_rate_table_10_20_40_80": return _record(case_id, (_profile.debug_snapshot().get("commodity", {}) as Dictionary).get("commodity_rate_by_rank", {}) == {"I": 10, "II": 20, "III": 40, "IV": 80}, "Rank rates remain 10/20/40/80 units per minute.")
		"same_region_has_no_distance_premium": return _record(case_id, int(first_same.get("unit_price_cents", -1)) == 10000, "Distance 0 keeps base price.")
		"adjacent_has_no_distance_premium": return _record(case_id, int(first_adjacent.get("unit_price_cents", -1)) == 10000, "Distance 1 keeps base price.")
		"distance_two_adds_twelve_percent": return _record(case_id, int(first_two.get("unit_price_cents", -1)) == 11200, "Distance 2 adds one linear 12% step.")
		"distance_three_adds_twenty_four_percent": return _record(case_id, int(first_three.get("unit_price_cents", -1)) == 12400, "Distance 3 adds two linear 12% steps.")
		"distance_premium_caps_at_one_hundred_twenty_percent": return _record(case_id, int(first_cap.get("unit_price_cents", -1)) == 22000, "Distance premium caps at +120%.")
		"receipt_explains_linear_price": return _record(case_id, _has_fields(first_three, ["base_unit_price_cents", "shortest_legal_distance", "distance_premium_basis_points", "unit_price_cents"]), "Every receipt explains the linear distance price.")
		"shortest_route_prevents_distance_premium_farming": return _record(case_id, int(_first_receipt(_evidence.get("route_choice", {}) as Dictionary).get("shortest_legal_distance", -1)) == 1 and int(_first_receipt(_evidence.get("route_choice", {}) as Dictionary).get("unit_price_cents", -1)) == 10000, "An adjacent direct route wins over a profitable detour, preventing distance-premium farming.")
		"one_source_splits_to_many_demands": return _record(case_id, _unique_field_count((_evidence.get("one_many", {}) as Dictionary).get("receipts", []), "demand_installation_id") == 2, "One production installation automatically splits into two demand sinks.")
		"many_sources_feed_one_demand": return _record(case_id, _unique_field_count((_evidence.get("many_one", {}) as Dictionary).get("receipts", []), "source_installation_id") == 2, "Two sources automatically feed one demand sink.")
		"many_sources_feed_many_demands": return _record(case_id, _pair_count((_evidence.get("many_many", {}) as Dictionary).get("receipts", [])) == 4, "The flow graph produces all four source-to-demand pairings.")
		"allocation_is_stable_by_identity": return _record(case_id, _receipt_pair_histogram((_evidence.get("many_many", {}) as Dictionary).get("receipts", [])) == _receipt_pair_histogram((_evidence.get("many_many_reverse", {}) as Dictionary).get("receipts", [])), "Installation order does not change allocation by stable IDs.")
		"facility_capacity_is_proportional": return _record(case_id, int(((_evidence.get("capacity", {}) as Dictionary).get("advance", {}) as Dictionary).get("receipt_count", -1)) == 40, "Five 10/min sources share a 40/min factory proportionally.")
		"region_integrity_scales_effective_flow": return _record(case_id, int(((_evidence.get("integrity", {}) as Dictionary).get("advance", {}) as Dictionary).get("receipt_count", -1)) == 5, "50% integrity yields 50% effective production and demand.")
		"missing_demand_creates_backpressure": return _record(case_id, int(((_evidence.get("no_demand", {}) as Dictionary).get("advance", {}) as Dictionary).get("backpressured_milliunits", 0)) > 0, "Unmatched production becomes backpressure and produces no cash.")
		"missing_route_creates_backpressure": return _record(case_id, int(((_evidence.get("no_route", {}) as Dictionary).get("advance", {}) as Dictionary).get("backpressured_milliunits", 0)) > 0, "Disconnected production becomes backpressure.")
		"one_sold_unit_one_receipt": return _record(case_id, int((same.get("advance", {}) as Dictionary).get("receipt_count", -1)) == ((same.get("receipts", []) as Array).size()), "Each sold unit has exactly one receipt.")
		"cash_rent_gdp_mana_share_receipt_id": return _record(case_id, _observer_ids_match(first_two), "Cash, rent, GDP and mana observers consume one receipt ID.")
		"public_receipt_hides_owner": return _record(case_id, controller_source.contains('receipt.erase("commodity_owner")') and controller_source.contains('receipt.erase("source_installation_id")') and controller_source.contains('receipt.erase("observer_intents")') and controller_source.contains('rent.erase("recipient_player_index")'), "Public receipt projection strips owner, private installation identity, internal observer intents and rent recipients.")
		"save_round_trip_preserves_installations": return _record(case_id, bool(((_evidence.get("save", {}) as Dictionary).get("applied", {}) as Dictionary).get("applied", false)) and ((_evidence.get("save", {}) as Dictionary).get("source", {}) as Dictionary).get("installations", []) == ((_evidence.get("save", {}) as Dictionary).get("restored", {}) as Dictionary).get("installations", []) and ((_evidence.get("save", {}) as Dictionary).get("source", {}) as Dictionary).get("installation_transaction_receipts", {}) == ((_evidence.get("save", {}) as Dictionary).get("restored", {}) as Dictionary).get("installation_transaction_receipts", {}), "v0.6 installations, exact-once installation receipts and fixed-point remainders round-trip.")
		"legacy_project_save_is_rejected": return _record(case_id, str(((_evidence.get("save", {}) as Dictionary).get("legacy", {}) as Dictionary).get("reason", "")).contains("invalid") or str(((_evidence.get("save", {}) as Dictionary).get("legacy", {}) as Dictionary).get("reason", "")).contains("legacy"), "Legacy project save payload is rejected.")
		"cash_bridge_is_atomic_and_exact_once": return _record(case_id, bridge_source.contains("prepared_players") and bridge_source.contains("_applied_batch_ids") and bridge_source.contains('_world.set("players", prepared_players)'), "Bridge validates a cloned player array and commits once.")
		"economy_cashflow_not_composed": return _record(case_id, not coordinator_scene.contains("EconomyCashflowRuntimeController.tscn") and cashflow_source.contains('"retired": true'), "Legacy cashflow controller is a non-runtime retired shell.")
		"gdp_formula_not_composed": return _record(case_id, not coordinator_scene.contains("GdpFormulaRuntimeController.tscn") and gdp_source.contains('"retired": true'), "Legacy GDP formula is a non-runtime retired shell.")
		"legacy_industry_capacity_not_composed": return _record(case_id, not coordinator_scene.contains("IndustryCapacityRuntimeService.tscn") and not coordinator_scene.contains("IndustryCapacityWorldBridge.tscn"), "v0.5 GDP capacity reservations are absent from production composition.")
		"legacy_project_and_cash_algorithms_absent": return _record(case_id, not city_trade_source.contains("func install_project") and not city_trade_source.contains("func settle_cashflow_seconds") and not city_trade_source.contains("func project_share") and not cashflow_source.contains("func settle_sources") and not gdp_source.contains("func calculate_city_gdp"), "Project GDP, project-share payout and parallel cash algorithms are absent; legacy save keys remain rejection-only evidence.")
		"city_trade_transition_removed": return _record(case_id, city_trade_source.contains('"retired": true') and city_trade_source.contains("RouteNetworkRuntimeController") and not city_trade_source.contains("all_transition_route_candidates"), "The temporary CityTrade route adapter has been retired instead of retained as a parallel owner.")
		"product_market_no_longer_records_parallel_gdp": return _record(case_id, product_market_source.contains("_on_product_market_cycle_completed") and not product_market_source.contains("_apply_product_market_cycle_world_step"), "Price refresh no longer calculates or records GDP.")
		"main_legacy_cashflow_entry_absent": return _record(case_id, not main_source.contains("func _update_realtime_economy_cashflow") and not main_source.contains("func _settle_city_cashflow_seconds") and main_source.contains("func _advance_continuous_commodity_flow"), "main advances only CommodityFlow.")
		"single_authoritative_flow_owner": return _record(case_id, controller_source.contains('"controller_authoritative": _configured') and not city_trade_source.contains('"controller_authoritative": true') and not cashflow_source.contains('"controller_authoritative": true'), "CommodityFlow is the only authoritative continuous economy owner.")
		"all_snapshots_are_pure_data": return _record(case_id, _is_pure_data(_evidence) and _is_pure_data(build_characterization_manifest_preview()), "Runtime evidence and reports contain only pure data.")
		"route_controller_scene_loads": return _record(case_id, load(ROUTE_CONTROLLER_SCENE_PATH) is PackedScene, "RouteNetworkRuntimeController is a real editable runtime scene.")
		"route_world_bridge_scene_loads": return _record(case_id, load(ROUTE_BRIDGE_SCENE_PATH) is PackedScene, "RouteNetworkWorldBridge is a real non-owning scene.")
		"coordinator_route_network_composition": return _record(case_id, coordinator_scene.contains("RouteNetworkRuntimeController.tscn") and coordinator_scene.contains("RouteNetworkWorldBridge.tscn") and not coordinator_scene.contains("CityTradeNetworkRuntimeController.tscn"), "Coordinator statically composes RouteNetwork and no longer composes CityTrade.")
		"city_trade_runtime_retired": return _record(case_id, city_trade_source.contains("RETIRED_BY") and not city_trade_source.contains("func routes_for_product") and not city_trade_source.contains("func refresh_routes"), "CityTrade contains no live route algorithm or compatibility fallback.")
		"same_or_adjacent_direct_exempt": return _record(case_id, _route_has_mode(_route_candidates("direct"), "direct") and (_first_route_candidate("direct").get("facility_ids", []) as Array).is_empty(), "Same/adjacent delivery stays direct and facility-rent exempt.")
		"long_land_requires_roads": return _record(case_id, _route_has_mode(_route_candidates("land"), "land") and _route_candidates("no_roads").is_empty(), "Long land flow exists only when every leg has active roads.")
		"sea_requires_ports": return _record(case_id, _route_has_mode(_route_candidates("sea"), "sea") and route_controller_source.contains('"sea": return "port"'), "Sea legs require active ports on both ends.")
		"air_requires_spaceports": return _record(case_id, _route_has_mode(_route_candidates("air"), "air") and route_controller_source.contains('"air": return "spaceport"'), "Air legs require active spaceports on both ends.")
		"multimodal_route_tags": return _record(case_id, _route_has_all_modes(_route_candidates("multimodal"), ["land", "sea"]), "One candidate records both land and sea tags without duplicating goods.")
		"canonical_distance_shared_across_detours": return _record(case_id, _all_routes_share_distance(_route_candidates("land"), 1), "Actual land and air paths share the canonical shortest legal pricing distance, preventing premium farming.")
		"route_priority_owner_net_first": return _record(case_id, str(_first_receipt(_evidence.get("route_network", {}).get("owner_net", {})).get("route_id", "")) == "route:owner-net", "Actual route selection prioritizes commodity-owner net cash before arrival and transfers.")
		"topology_revision_rebuild": return _record(case_id, bool(((_evidence.get("route_network", {}) as Dictionary).get("revision", {}).get("second", {}) as Dictionary).get("rebuilt", false)) and int(((_evidence.get("route_network", {}) as Dictionary).get("revision", {}).get("first", {}) as Dictionary).get("route_count", 0)) > int(((_evidence.get("route_network", {}) as Dictionary).get("revision", {}).get("second", {}) as Dictionary).get("route_count", 0)), "Topology revision invalidates and rebuilds derived paths.")
		"route_capacity_uses_integrity": return _record(case_id, int(_first_route_candidate("integrity").get("bottleneck_units_per_minute", -1)) == 25, "A 50%-integrity rank-I road scales the shared 50/min bottleneck to 25/min.")
		"six_colored_warehouse_slots": return _record(case_id, _warehouse_slot_count() == 6 and _all_committed(((_evidence.get("warehouse_color_slots", {}) as Dictionary).get("commits", []))), "Every region has six industry-specific warehouse slots and all six can coexist.")
		"uncolored_warehouse_rejected": return _record(case_id, not bool(((_evidence.get("warehouse_color_slots", {}) as Dictionary).get("invalid", {}) as Dictionary).get("committed", true)) and region_infrastructure_source.contains('facility_type == "warehouse"'), "A warehouse build without one of the six industry IDs fails closed.")
		"wrong_color_warehouse_rejected": return _record(case_id, ((_evidence.get("warehouse_wrong_color", {}) as Dictionary).get("stored_snapshot", []) as Array).is_empty() and int(((_evidence.get("warehouse_wrong_color", {}) as Dictionary).get("store_advance", {}) as Dictionary).get("backpressured_milliunits", 0)) > 0, "A warehouse cannot absorb goods from another industry color.")
		"warehouse_stores_before_backpressure": return _record(case_id, int(((_evidence.get("warehouse", {}) as Dictionary).get("store_advance", {}) as Dictionary).get("stored_milliunits", 0)) == 10000 and int(((_evidence.get("warehouse", {}) as Dictionary).get("store_advance", {}) as Dictionary).get("backpressured_milliunits", -1)) == 0, "Unmatched continuous output enters a reachable same-color warehouse before backpressure.")
		"warehouse_capacity_and_throughput_ranked": return _record(case_id, (_profile.debug_snapshot().get("infrastructure", {}) as Dictionary).get("warehouse_capacity_by_rank", {}) == {"I": 200, "II": 400, "III": 700, "IV": 1100} and (_profile.debug_snapshot().get("infrastructure", {}) as Dictionary).get("warehouse_throughput_by_rank", {}) == {"I": 50, "II": 100, "III": 175, "IV": 275}, "Warehouse inventory, inbound and outbound throughput use the authored rank tables.")
		"warehouse_outflow_pays_owner_rent": return _record(case_id, _warehouse_rent_total(((_evidence.get("warehouse", {}) as Dictionary).get("outflow_receipts", [])), 2) > 0, "Storage debt is settled to the warehouse owner only when stored goods leave through a Sale Receipt.")
		"warehouse_rent_excluded_from_gdp": return _record(case_id, _warehouse_receipt_conserves_value(((_evidence.get("warehouse", {}) as Dictionary).get("outflow_receipts", [])), 2), "Warehouse rent is a cash transfer; gross commodity value remains the sole GDP value.")
		"full_warehouse_backpressures_continuous": return _record(case_id, _warehouse_inventory_milliunits(((_evidence.get("warehouse_full", {}) as Dictionary).get("full_snapshot", []))) == 200000 and int(((_evidence.get("warehouse_full", {}) as Dictionary).get("full_backpressure", {}) as Dictionary).get("backpressured_milliunits", 0)) > 0, "A full rank-I colored warehouse causes continuous factories to backpressure.")
		"full_warehouse_loses_one_shot": return _record(case_id, int(((_evidence.get("warehouse_full", {}) as Dictionary).get("one_shot_advance", {}) as Dictionary).get("one_shot_lost_milliunits", 0)) == 10000 and bool(((_evidence.get("warehouse_full", {}) as Dictionary).get("one_shot_replay", {}) as Dictionary).get("duplicate", false)), "One-shot physical goods overflow and are lost exactly once when the matching warehouse is full.")
		"warehouse_destruction_loses_inventory_once": return _record(case_id, int(((_evidence.get("warehouse_full", {}) as Dictionary).get("destruction_first", {}) as Dictionary).get("warehouse_destroyed_loss_milliunits", 0)) == 200000 and int(((_evidence.get("warehouse_full", {}) as Dictionary).get("destruction_second", {}) as Dictionary).get("warehouse_destroyed_loss_milliunits", -1)) == 0, "Destroyed warehouse inventory is cleared once and cannot be replayed.")
		"warehouse_save_round_trip": return _record(case_id, bool(((_evidence.get("warehouse_full", {}) as Dictionary).get("save_applied", {}) as Dictionary).get("applied", false)) and ((_evidence.get("warehouse_full", {}) as Dictionary).get("save_full", {}) as Dictionary).get("warehouse_inventory", {}) == ((_evidence.get("warehouse_full", {}) as Dictionary).get("restored_save", {}) as Dictionary).get("warehouse_inventory", {}), "Colored inventory, rent debt and fixed-point state round-trip through the v0.6 controller save.")
		"route_and_warehouse_snapshots_pure": return _record(case_id, _is_pure_data((_evidence.get("route_network", {}) as Dictionary)) and _is_pure_data((_evidence.get("warehouse_full", {}) as Dictionary)) and controller_source.contains('"owns_warehouse_inventory": true'), "Route and warehouse evidence remain pure data with one goods owner.")
	return _record(case_id, false, "unknown case")


func _resolve_real_product() -> void:
	if _catalog == null or not _catalog.has_method("product_ids"):
		return
	for product_variant in _catalog.call("product_ids"):
		var candidate := str(product_variant)
		var industry := str(_catalog.call("industry_for_product", candidate))
		if not candidate.is_empty() and not industry.is_empty():
			_product_id = candidate
			_industry_id = industry
			return


func _region(region_id: String, integrity_bp: int, neighbor_ids: Array) -> Dictionary:
	return {"region_id": region_id, "integrity_basis_points": integrity_bp, "lifecycle_state": "active", "neighbor_region_ids": neighbor_ids.duplicate(), "revision": 1}


func _facility(facility_id: String, region_id: String, facility_type: String, rank: int, industry_override := "", owner_player_index := 0) -> Dictionary:
	return {"facility_id": facility_id, "region_id": region_id, "facility_type": facility_type, "industry_id": _industry_id if industry_override.is_empty() else industry_override, "owner_player_index": owner_player_index, "rank": rank, "active": true}


func _route_region(region_id: String, terrain_id: String, neighbor_ids: Array, integrity_bp := 10000) -> Dictionary:
	return {"region_id": region_id, "terrain_id": terrain_id, "neighbor_region_ids": neighbor_ids.duplicate(), "integrity_basis_points": integrity_bp, "lifecycle_state": "active", "revision": 1, "legacy_index": -1, "legacy_city_active": true}


func _route_facility(facility_id: String, region_id: String, facility_type: String, rank: int) -> Dictionary:
	return {"facility_id": facility_id, "region_id": region_id, "facility_type": facility_type, "industry_id": "", "owner_player_index": 0, "rank": rank, "active": true}


func _route_topology(regions: Array, facilities: Array, revision: String) -> Dictionary:
	return {"ruleset_id": "v0.6", "regions": regions.duplicate(true), "facilities": facilities.duplicate(true), "topology_revision": revision}


func _other_industry_id() -> String:
	for industry_id in RegionInfrastructureRuntimeController.INDUSTRY_IDS:
		if industry_id != _industry_id:
			return industry_id
	return ""


func _facility_for_id(facilities: Array, facility_id: String) -> Dictionary:
	for facility_variant in facilities:
		if facility_variant is Dictionary and str((facility_variant as Dictionary).get("facility_id", "")) == facility_id:
			return (facility_variant as Dictionary).duplicate(true)
	return {}


func _array_has_region(regions: Array, region_id: String) -> bool:
	for region_variant in regions:
		if region_variant is Dictionary and str((region_variant as Dictionary).get("region_id", "")) == region_id:
			return true
	return false


func _install_request(installation_id: String, transaction_id: String, facility_id: String, region_id: String, direction: String, player_index: int, rank := 1) -> Dictionary:
	return {"installation_id": installation_id, "transaction_id": transaction_id, "facility_id": facility_id, "region_id": region_id, "commodity_id": _product_id, "color": _industry_id, "direction": direction, "installer_player_index": player_index, "source_card_rank": rank, "region_revision": 1}


func _route(source_region_id: String, market_region_id: String, distance: int) -> Dictionary:
	var legs: Array = []
	for index in range(maxi(0, distance)):
		legs.append({"from_region_id": source_region_id if index == 0 else "hop-%02d" % index, "to_region_id": market_region_id if index == distance - 1 else "hop-%02d" % (index + 1), "mode": "test"})
	return {"route_id": "route:%s>%s" % [source_region_id, market_region_id], "commodity_id": _product_id, "source_region_id": source_region_id, "market_region_id": market_region_id, "ordered_legs": legs, "mode_tags": ["test"], "facility_ids": [], "shortest_legal_distance": distance, "bottleneck_units_per_minute": 1000000, "expected_rents": [], "region_revision_fingerprint": "fixture"}


func _first_receipt(fixture: Dictionary) -> Dictionary:
	var receipts: Array = fixture.get("receipts", []) if fixture.get("receipts", []) is Array else []
	return (receipts[0] as Dictionary).duplicate(true) if not receipts.is_empty() else {}


func _route_candidates(key: String) -> Array:
	var route_network: Dictionary = _evidence.get("route_network", {})
	var fixture: Dictionary = route_network.get(key, {})
	return (fixture.get("candidates", []) as Array).duplicate(true) if fixture.get("candidates", []) is Array else []


func _first_route_candidate(key: String) -> Dictionary:
	var candidates := _route_candidates(key)
	return (candidates[0] as Dictionary).duplicate(true) if not candidates.is_empty() else {}


func _route_has_mode(candidates: Array, mode: String) -> bool:
	for candidate_variant in candidates:
		if candidate_variant is Dictionary and ((candidate_variant as Dictionary).get("mode_tags", []) as Array).has(mode):
			return true
	return false


func _route_has_all_modes(candidates: Array, modes: Array) -> bool:
	for candidate_variant in candidates:
		if not (candidate_variant is Dictionary):
			continue
		var tags: Array = (candidate_variant as Dictionary).get("mode_tags", [])
		var complete := true
		for mode_variant in modes:
			if not tags.has(str(mode_variant)):
				complete = false
				break
		if complete:
			return true
	return false


func _all_routes_share_distance(candidates: Array, expected_distance: int) -> bool:
	if candidates.size() < 2:
		return false
	for candidate_variant in candidates:
		if not (candidate_variant is Dictionary) or int((candidate_variant as Dictionary).get("shortest_legal_distance", -1)) != expected_distance:
			return false
	return true


func _warehouse_slot_count() -> int:
	var fixture: Dictionary = _evidence.get("warehouse_color_slots", {})
	var count := 0
	for slot_variant in fixture.get("slots", []):
		if str(slot_variant).contains("::warehouse."):
			count += 1
	return count


func _all_committed(receipts_variant: Variant) -> bool:
	if not (receipts_variant is Array) or (receipts_variant as Array).size() != 6:
		return false
	for receipt_variant in receipts_variant:
		if not (receipt_variant is Dictionary) or not bool((receipt_variant as Dictionary).get("committed", false)):
			return false
	return true


func _warehouse_rent_total(receipts_variant: Variant, owner_index: int) -> int:
	var total := 0
	if not (receipts_variant is Array):
		return total
	for receipt_variant in receipts_variant:
		if not (receipt_variant is Dictionary):
			continue
		for rent_variant in (receipt_variant as Dictionary).get("rent_rows", []):
			if rent_variant is Dictionary and str((rent_variant as Dictionary).get("facility_type", "")) == "warehouse" and int((rent_variant as Dictionary).get("recipient_player_index", -1)) == owner_index:
				total += maxi(0, int((rent_variant as Dictionary).get("amount", 0)))
	return total


func _warehouse_receipt_conserves_value(receipts_variant: Variant, warehouse_owner_index: int) -> bool:
	if not (receipts_variant is Array) or (receipts_variant as Array).is_empty():
		return false
	var saw_rent := false
	for receipt_variant in receipts_variant:
		if not (receipt_variant is Dictionary):
			return false
		var receipt: Dictionary = receipt_variant
		var rent_total := 0
		for rent_variant in receipt.get("rent_rows", []):
			if rent_variant is Dictionary:
				rent_total += int((rent_variant as Dictionary).get("amount", 0))
				if str((rent_variant as Dictionary).get("facility_type", "")) == "warehouse" and int((rent_variant as Dictionary).get("recipient_player_index", -1)) == warehouse_owner_index:
					saw_rent = true
		if int(receipt.get("gdp_value", -1)) != int(receipt.get("gross_value", -2)) or int(receipt.get("owner_net_cash", -1)) + rent_total != int(receipt.get("gross_value", -2)):
			return false
	return saw_rent


func _warehouse_inventory_milliunits(snapshot_variant: Variant) -> int:
	var total := 0
	if snapshot_variant is Array:
		for row_variant in snapshot_variant:
			if row_variant is Dictionary:
				total += maxi(0, int((row_variant as Dictionary).get("milliunits", 0)))
	return total


func _has_schema_fields(schema_id: String, required_fields: Array) -> bool:
	var schema := RulesetV06SchemaRegistry.schema_snapshot(schema_id)
	return _has_fields({"required": schema.get("required", [])}, required_fields)


func _has_fields(source: Dictionary, fields: Array) -> bool:
	var keys: Array = source.get("required", source.keys()) if source.has("required") else source.keys()
	for field_variant in fields:
		if not keys.has(str(field_variant)):
			return false
	return true


func _unique_field_count(receipts_variant: Variant, field_name: String) -> int:
	var ids: Dictionary = {}
	if receipts_variant is Array:
		for receipt_variant in receipts_variant:
			if receipt_variant is Dictionary:
				ids[str((receipt_variant as Dictionary).get(field_name, ""))] = true
	return ids.size()


func _pair_count(receipts_variant: Variant) -> int:
	return _receipt_pair_histogram(receipts_variant).size()


func _receipt_pair_histogram(receipts_variant: Variant) -> Dictionary:
	var result: Dictionary = {}
	if receipts_variant is Array:
		for receipt_variant in receipts_variant:
			if not (receipt_variant is Dictionary): continue
			var receipt: Dictionary = receipt_variant
			var key := "%s>%s" % [str(receipt.get("source_installation_id", "")), str(receipt.get("demand_installation_id", ""))]
			result[key] = int(result.get(key, 0)) + int(receipt.get("units", 0))
	return result


func _observer_ids_match(receipt: Dictionary) -> bool:
	var expected := str(receipt.get("receipt_id", ""))
	var observers: Dictionary = {}
	for observer_variant in receipt.get("observer_intents", []):
		if not (observer_variant is Dictionary) or str((observer_variant as Dictionary).get("receipt_id", "")) != expected:
			return false
		observers[str((observer_variant as Dictionary).get("observer", ""))] = true
	var observer_ids: Array = observers.keys()
	observer_ids.sort()
	return observer_ids == ["cash", "gdp", "mana", "rent"]


func _record(case_id: String, passed: bool, notes: String) -> Dictionary:
	return {"case_id": case_id, "observed": passed, "contract_aligned": passed, "cutover_checked": true, "many_to_many_checked": case_id.contains("source") or case_id.contains("many") or case_id.contains("allocation"), "route_checked": case_id.contains("route") or case_id.contains("land") or case_id.contains("sea") or case_id.contains("air") or case_id.contains("multimodal"), "warehouse_checked": case_id.contains("warehouse"), "distance_price_checked": case_id.contains("distance") or case_id.contains("price"), "receipt_checked": case_id.contains("receipt") or case_id.contains("cash") or case_id.contains("gdp") or case_id.contains("rent"), "legacy_absent_checked": case_id.contains("legacy") or case_id.contains("composed") or case_id.contains("absent") or case_id.contains("retired"), "pure_data_checked": false, "passed": passed, "notes": notes}


func _count_passed() -> int:
	var count := 0
	for record_variant in _records:
		if record_variant is Dictionary and bool((record_variant as Dictionary).get("passed", false)): count += 1
	return count


func _prepare_output_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))


func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(content)
		file.close()


func _report(manifest: Dictionary) -> String:
	var lines := ["# SS06-03 Multimodal Route + Warehouse Hard Cutover", "", "- Gate: %d/%d" % [int(manifest.get("passed_count", 0)), int(manifest.get("case_count", 0))], "- Routes: direct exemption plus road, sea, air and multimodal candidates", "- Allocation: many-source / many-sink, deterministic and capacity constrained", "- Price: canonical shortest legal distance; actual route chosen by owner net, arrival, transfers and stable ID", "- Warehouses: six industry colors, ranked capacity/throughput, timed storage rent, backpressure and one-shot overflow loss", "- Settlement: one sold unit, one Sale Receipt; rent is cash-only and never second GDP", ""]
	for record_variant in _records:
		var record: Dictionary = record_variant
		lines.append("- [%s] `%s`: %s" % ["x" if bool(record.get("passed", false)) else " ", str(record.get("case_id", "")), str(record.get("notes", ""))])
	return "\n".join(lines) + "\n"


func _update_ui(manifest: Dictionary) -> void:
	summary_label.text = "SS06-03 %d/%d passed" % [int(manifest.get("passed_count", 0)), int(manifest.get("case_count", 0))]
	status_label.text = "PASSED" if _failures.is_empty() else "FAILED"
	ownership_text.text = "[b]Route owner[/b]\nRouteNetworkRuntimeController\n\n[b]Goods owner[/b]\nCommodityFlowRuntimeController\n\n[b]Flow[/b]\nMany-source/many-sink, shared bottlenecks, six-color warehouses\n\n[b]Price[/b]\nCanonical shortest distance; actual path cannot farm premium\n\n[b]Settlement[/b]\nSale Receipt pays commodity cash + facility rent once\n\n[b]Retired[/b]\nCityTrade route/project engine is inactive."
	var lines: Array = []
	for record_variant in _records:
		var record: Dictionary = record_variant
		lines.append("[color=%s]%s[/color] %s" % ["#5ee6a8" if bool(record.get("passed", false)) else "#fb7185", "PASS" if bool(record.get("passed", false)) else "FAIL", str(record.get("case_id", ""))])
	cases_text.text = "\n".join(lines)


func _save_screenshot() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var texture := get_viewport().get_texture()
	if texture == null:
		return
	var image := texture.get_image()
	if image != null and not image.is_empty():
		image.save_png(SCREENSHOT_PATH)


func _is_pure_data(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float: return true
	if value is Dictionary:
		for key in value.keys():
			if not _is_pure_data(key) or not _is_pure_data(value[key]): return false
		return true
	if value is Array:
		for item in value:
			if not _is_pure_data(item): return false
		return true
	return false
