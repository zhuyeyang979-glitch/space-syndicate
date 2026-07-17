extends SceneTree

const SUPPORT := preload("res://tests/support/commodity_flow_v06_test_support.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_market_then_ambient_then_storage_then_waste()
	_verify_inventory_serves_market_but_not_ambient()
	_verify_wrong_color_and_unreachable_waste()
	print("COMMODITY_FLOW_WAREHOUSE_THEN_WASTE_V06_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	quit(_failures.size())


func _verify_market_then_ambient_then_storage_then_waste() -> void:
	var regions := [
		SUPPORT.region("region.source", ["region.sink"], "land"),
		SUPPORT.region("region.sink", ["region.source"], "sea"),
	]
	var factory := SUPPORT.facility("factory.shared", "region.source", "factory", 0, "life", 1)
	var market := SUPPORT.facility("market.shared", "region.sink", "market", 1, "life", 1)
	var warehouse := SUPPORT.facility("warehouse.shared", "region.sink", "warehouse", 2, "life", 1)
	var shared_route := SUPPORT.route("route.shared", "region.source", "region.sink", 15, "road.shared", ["land"], 1)
	var fixture := SUPPORT.create_fixture(self, regions, [factory, market, warehouse], [shared_route])
	var flow: Node = fixture.get("flow")
	var bridge = fixture.get("bridge")
	_expect(bool(SUPPORT.install(flow, factory, SUPPORT.DEFAULT_PRODUCT_ID, "production", 0, 2).get("finalized", false)), "20/min production installs")
	_expect(bool(SUPPORT.install(flow, market, SUPPORT.DEFAULT_PRODUCT_ID, "demand", 1, 1).get("finalized", false)), "10/min concrete market demand installs")
	var advance: Dictionary = SUPPORT.advance(flow, bridge, 60.0, 60.0)
	_expect(int(advance.get("market_sold_milliunits", 0)) == 10000, "explicit market consumes its steady demand before lower phases")
	_expect(int(advance.get("ambient_consumed_milliunits", 0)) == 1000, "only the source region consumes low-value ambient output")
	_expect(int(advance.get("stored_milliunits", 0)) == 5000, "warehouse inbound uses only the five units of shared route capacity left after the market")
	_expect(int(advance.get("wasted_milliunits", 0)) == 4000, "fresh output left after market, ambient, and storage becomes waste")
	var inventory: Array = flow.call("warehouse_inventory_snapshot", 0)
	_expect(_inventory_total(inventory) == 5000, "stored quantity is authoritative inventory")
	var loss_events: Array = flow.call("recent_flow_loss_events_snapshot")
	_expect(loss_events.size() == 1 and str((loss_events[0] as Dictionary).get("loss_kind", "")) == "浪费产能", "waste emits only a pure-data player-readable loss event")
	var cash_before := int(bridge.cash_by_player.get(0, 0))
	var waste_summary: Dictionary = flow.call("public_waste_summary_snapshot")
	_expect(cash_before == 10100 and float(((waste_summary.get("commodity_rows", []) as Array)[0] as Dictionary).get("cumulative_wasted_units", 0.0)) == 4.0, "market and ambient receipts pay cash while four wasted units produce no settlement")
	SUPPORT.free_fixture(fixture)


func _verify_inventory_serves_market_but_not_ambient() -> void:
	var region := SUPPORT.region("region.buffer")
	var factory := SUPPORT.facility("factory.buffer", "region.buffer", "factory", 0)
	var warehouse := SUPPORT.facility("warehouse.buffer", "region.buffer", "warehouse", 2)
	var local_route := SUPPORT.route("local:buffer", "region.buffer", "region.buffer", 1000000, "local:buffer", ["local"], 0)
	var fixture := SUPPORT.create_fixture(self, [region], [factory, warehouse], [local_route])
	var flow: Node = fixture.get("flow")
	var bridge = fixture.get("bridge")
	_expect(bool(SUPPORT.install(flow, factory, SUPPORT.DEFAULT_PRODUCT_ID, "production", 0, 1).get("finalized", false)), "buffer factory installs")
	var stored: Dictionary = SUPPORT.advance(flow, bridge, 60.0, 60.0)
	_expect(int(stored.get("ambient_consumed_milliunits", 0)) == 1000 and int(stored.get("stored_milliunits", 0)) == 9000, "fresh output serves ambient demand before nine units enter storage")
	bridge.facts["facilities"] = [warehouse]
	bridge.facts["destroyed_facility_ids"] = ["factory.buffer"]
	var no_fresh: Dictionary = SUPPORT.advance(flow, bridge, 60.0, 60.0)
	_expect(int(no_fresh.get("ambient_consumed_milliunits", -1)) == 0 and _inventory_total(flow.call("warehouse_inventory_snapshot", 0)) == 9000, "ambient demand never drains warehouse inventory")
	var market := SUPPORT.facility("market.buffer", "region.buffer", "market", 1)
	bridge.facts["facilities"] = [warehouse, market]
	bridge.facts["destroyed_facility_ids"] = []
	_expect(bool(SUPPORT.install(flow, market, SUPPORT.DEFAULT_PRODUCT_ID, "demand", 1, 1).get("finalized", false)), "buffer market demand installs")
	var sold: Dictionary = SUPPORT.advance(flow, bridge, 60.0, 60.0)
	_expect(int(sold.get("market_sold_milliunits", 0)) == 9000 and _inventory_total(flow.call("warehouse_inventory_snapshot", 0)) == 0, "stored exact-commodity inventory automatically serves explicit market demand")
	_expect(int(sold.get("market_backlog_milliunits", 0)) == 1000, "only the one-unit steady shortfall becomes market backlog")
	SUPPORT.free_fixture(fixture)


func _verify_wrong_color_and_unreachable_waste() -> void:
	var region := SUPPORT.region("region.reject")
	var factory := SUPPORT.facility("factory.reject", "region.reject", "factory", 0, "life", 1)
	var wrong_color := SUPPORT.facility("warehouse.energy", "region.reject", "warehouse", 1, "energy", 1)
	var local_route := SUPPORT.route("local:reject", "region.reject", "region.reject", 1000000, "local:reject", ["local"], 0)
	var wrong_fixture := SUPPORT.create_fixture(self, [region], [factory, wrong_color], [local_route])
	var wrong_flow: Node = wrong_fixture.get("flow")
	var wrong_bridge = wrong_fixture.get("bridge")
	SUPPORT.install(wrong_flow, factory, SUPPORT.DEFAULT_PRODUCT_ID, "production", 0, 1)
	var wrong: Dictionary = SUPPORT.advance(wrong_flow, wrong_bridge, 60.0, 60.0)
	_expect(int(wrong.get("stored_milliunits", -1)) == 0 and int(wrong.get("wasted_milliunits", 0)) == 9000, "wrong-color warehouse rejects surplus, which becomes waste")
	SUPPORT.free_fixture(wrong_fixture)
	var matching := SUPPORT.facility("warehouse.life", "region.reject", "warehouse", 1, "life", 1)
	var unreachable_fixture := SUPPORT.create_fixture(self, [region], [factory, matching], [])
	var unreachable_flow: Node = unreachable_fixture.get("flow")
	var unreachable_bridge = unreachable_fixture.get("bridge")
	SUPPORT.install(unreachable_flow, factory, SUPPORT.DEFAULT_PRODUCT_ID, "production", 0, 1)
	var unreachable: Dictionary = SUPPORT.advance(unreachable_flow, unreachable_bridge, 60.0, 60.0)
	_expect(int(unreachable.get("stored_milliunits", -1)) == 0 and int(unreachable.get("wasted_milliunits", 0)) == 9000, "matching warehouse without an authoritative route also rejects surplus into waste")
	SUPPORT.free_fixture(unreachable_fixture)


func _inventory_total(rows: Array) -> int:
	var total := 0
	for row_variant in rows:
		if row_variant is Dictionary:
			total += int((row_variant as Dictionary).get("milliunits", 0))
	return total


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)
