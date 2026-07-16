extends SceneTree

const SUPPORT := preload("res://tests/support/commodity_flow_v06_test_support.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_market_first_backlog_and_recovery()
	_verify_shared_market_capacity_reserves_steady()
	_verify_shared_physical_route_capacity_across_commodities()
	print("COMMODITY_FLOW_MARKET_BACKLOG_V06_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	quit(_failures.size())


func _verify_market_first_backlog_and_recovery() -> void:
	var region := SUPPORT.region("region.market")
	var market := SUPPORT.facility("market.primary", "region.market", "market", 1)
	var fixture := SUPPORT.create_fixture(self, [region], [market], [])
	var flow: Node = fixture.get("flow")
	var bridge = fixture.get("bridge")
	_expect(bool((fixture.get("configured", {}) as Dictionary).get("configured", false)), "market-first fixture configures")
	_expect(bool(SUPPORT.install(flow, market, SUPPORT.DEFAULT_PRODUCT_ID, "demand", 1, 1).get("finalized", false)), "concrete market demand installs before any factory")
	var first: Dictionary = SUPPORT.advance(flow, bridge, 60.0, 60.0)
	_expect(int(first.get("market_backlog_milliunits", 0)) == 10000 and int(first.get("market_sold_milliunits", -1)) == 0, "market backlog grows without supply")
	var paused_before := JSON.stringify(flow.call("to_save_data"))
	var paused: Dictionary = flow.call("advance_world", 60.0, {"time_paused": true})
	_expect(not bool(paused.get("advanced", true)) and str(paused.get("reason", "")) == "clock_paused" and paused_before == JSON.stringify(flow.call("to_save_data")), "pause freezes demand generation, remainders, revisions, and backlog")
	var second: Dictionary = SUPPORT.advance(flow, bridge, 60.0, 60.0)
	_expect(int(second.get("market_backlog_milliunits", 0)) == 20000, "backlog reaches the authored two-minute cap")
	var factory := SUPPORT.facility("factory.primary", "region.market", "factory", 0)
	bridge.facts["facilities"] = [market.duplicate(true), factory.duplicate(true)]
	_expect(bool(SUPPORT.install(flow, factory, SUPPORT.DEFAULT_PRODUCT_ID, "production", 0, 2).get("finalized", false)), "matching factory is installed later")
	var no_route: Dictionary = SUPPORT.advance(flow, bridge, 60.0, 60.0)
	_expect(int(no_route.get("market_sold_milliunits", -1)) == 0 and int(no_route.get("market_backlog_milliunits", 0)) == 20000, "same-region market delivery still requires an authoritative RouteNetwork route fact")
	bridge.facts["route_candidates"] = [
		SUPPORT.route("local:region.market>region.market", "region.market", "region.market", 1000000, "local:region.market>region.market", ["local"], 0),
	]
	var recovery_one: Dictionary = SUPPORT.advance(flow, bridge, 60.0, 60.0)
	_expect(int(recovery_one.get("market_sold_milliunits", 0)) == 20000 and int(recovery_one.get("market_backlog_milliunits", -1)) == 10000, "steady demand is served first and only equal extra supply reduces old backlog")
	var recovery_two: Dictionary = SUPPORT.advance(flow, bridge, 60.0, 60.0)
	_expect(int(recovery_two.get("market_sold_milliunits", 0)) == 20000 and int(recovery_two.get("market_backlog_milliunits", -1)) == 0, "allowed extra supply drains the remaining backlog without overshoot")
	var steady_only: Dictionary = SUPPORT.advance(flow, bridge, 60.0, 60.0)
	_expect(int(steady_only.get("market_sold_milliunits", 0)) == 10000 and int(steady_only.get("market_backlog_milliunits", -1)) == 0, "after recovery, consumption returns to the installed steady rate")
	var phase_counts := {"steady": 0, "recovery": 0}
	for receipt_variant in bridge.committed_receipts:
		var receipt: Dictionary = receipt_variant
		var phase := str(receipt.get("market_demand_phase", ""))
		if phase_counts.has(phase):
			phase_counts[phase] = int(phase_counts.get(phase, 0)) + 1
	_expect(int(phase_counts.get("steady", 0)) == 30 and int(phase_counts.get("recovery", 0)) == 20, "receipt lineage distinguishes steady units from backlog recovery units")
	bridge.facts["facilities"] = [factory.duplicate(true)]
	bridge.facts["destroyed_facility_ids"] = ["market.primary"]
	var destroyed: Dictionary = SUPPORT.advance(flow, bridge, 1.0, 1.0)
	_expect(bool(destroyed.get("advanced", false)) and (flow.call("public_market_backlog_snapshot").get("rows", []) as Array).is_empty(), "market destruction clears its backlog record exactly once")
	var rebuilt_market := SUPPORT.facility("market.rebuilt", "region.market", "market", 1)
	bridge.facts["facilities"] = [factory.duplicate(true), rebuilt_market.duplicate(true)]
	bridge.facts["destroyed_facility_ids"] = []
	_expect(bool(SUPPORT.install(flow, rebuilt_market, SUPPORT.DEFAULT_PRODUCT_ID, "demand", 1, 1).get("finalized", false)), "rebuilt market receives a new facility identity")
	_expect((flow.call("public_market_backlog_snapshot").get("rows", []) as Array).is_empty(), "rebuilt market starts with zero inherited backlog before its first tick")
	SUPPORT.free_fixture(fixture)


func _verify_shared_market_capacity_reserves_steady() -> void:
	var region := SUPPORT.region("region.capacity")
	var market := SUPPORT.facility("market.capacity", "region.capacity", "market", 2, "life", 1)
	var fixture := SUPPORT.create_fixture(
		self,
		[region],
		[market],
		[],
		{
			SUPPORT.DEFAULT_PRODUCT_ID: SUPPORT.DEFAULT_PRICE_CENTS,
			SUPPORT.SECOND_LIFE_PRODUCT_ID: SUPPORT.DEFAULT_PRICE_CENTS,
		}
	)
	var flow: Node = fixture.get("flow")
	var bridge = fixture.get("bridge")
	_expect(bool(SUPPORT.install(flow, market, SUPPORT.DEFAULT_PRODUCT_ID, "demand", 2, 4).get("finalized", false)), "first high-rate commodity demand installs")
	_expect(bool(SUPPORT.install(flow, market, SUPPORT.SECOND_LIFE_PRODUCT_ID, "demand", 2, 4).get("finalized", false)), "second high-rate commodity demand installs")
	SUPPORT.advance(flow, bridge, 60.0, 60.0)
	var backlog_before: Dictionary = flow.call("to_save_data").get("market_backlog_by_key", {})
	_expect(_backlog_for(backlog_before, SUPPORT.DEFAULT_PRODUCT_ID) == 20000 and _backlog_for(backlog_before, SUPPORT.SECOND_LIFE_PRODUCT_ID) == 20000, "rank-I market reserves its 40/min steady capacity proportionally across both commodities")
	var factory_a := SUPPORT.facility("factory.capacity.a", "region.capacity", "factory", 0, "life", 4)
	var factory_b := SUPPORT.facility("factory.capacity.b", "region.capacity", "factory", 1, "life", 4)
	bridge.facts["facilities"] = [market, factory_a, factory_b]
	bridge.facts["route_candidates"] = [
		SUPPORT.route("local:capacity", "region.capacity", "region.capacity", 1000000, "local:capacity", ["local"], 0),
	]
	_expect(bool(SUPPORT.install(flow, factory_a, SUPPORT.DEFAULT_PRODUCT_ID, "production", 0, 4).get("finalized", false)), "first high-rate supply installs")
	_expect(bool(SUPPORT.install(flow, factory_b, SUPPORT.SECOND_LIFE_PRODUCT_ID, "production", 1, 4).get("finalized", false)), "second high-rate supply installs")
	var served: Dictionary = SUPPORT.advance(flow, bridge, 60.0, 60.0)
	var backlog_after: Dictionary = flow.call("to_save_data").get("market_backlog_by_key", {})
	_expect(int(served.get("market_sold_milliunits", 0)) == 40000, "market processing capacity remains the final shared ceiling")
	_expect(_backlog_for(backlog_after, SUPPORT.DEFAULT_PRODUCT_ID) == 20000 and _backlog_for(backlog_after, SUPPORT.SECOND_LIFE_PRODUCT_ID) == 20000, "when steady demand fills the market, neither commodity receives recovery headroom")
	SUPPORT.free_fixture(fixture)


func _verify_shared_physical_route_capacity_across_commodities() -> void:
	var regions := [
		SUPPORT.region("region.route.a"),
		SUPPORT.region("region.route.b"),
		SUPPORT.region("region.route.market"),
	]
	var factory_a := SUPPORT.facility("factory.route.a", "region.route.a", "factory", 0, "life", 4)
	var factory_b := SUPPORT.facility("factory.route.b", "region.route.b", "factory", 1, "life", 4)
	var market := SUPPORT.facility("market.route", "region.route.market", "market", 2, "life", 4)
	var shared_resource_id := "road.shared.physical"
	var routes := [
		SUPPORT.route("route.a", "region.route.a", "region.route.market", 100, shared_resource_id, ["land"], 2),
		SUPPORT.route("route.b", "region.route.b", "region.route.market", 100, shared_resource_id, ["land"], 2),
	]
	var fixture := SUPPORT.create_fixture(
		self,
		regions,
		[factory_a, factory_b, market],
		routes,
		{
			SUPPORT.DEFAULT_PRODUCT_ID: SUPPORT.DEFAULT_PRICE_CENTS,
			SUPPORT.SECOND_LIFE_PRODUCT_ID: SUPPORT.DEFAULT_PRICE_CENTS,
		}
	)
	var flow: Node = fixture.get("flow")
	var bridge = fixture.get("bridge")
	_expect(bool(SUPPORT.install(flow, factory_a, SUPPORT.DEFAULT_PRODUCT_ID, "production", 0, 4).get("finalized", false)), "first routed supply installs")
	_expect(bool(SUPPORT.install(flow, factory_b, SUPPORT.SECOND_LIFE_PRODUCT_ID, "production", 1, 4).get("finalized", false)), "second routed supply installs")
	_expect(bool(SUPPORT.install(flow, market, SUPPORT.DEFAULT_PRODUCT_ID, "demand", 2, 4).get("finalized", false)), "first routed demand installs")
	_expect(bool(SUPPORT.install(flow, market, SUPPORT.SECOND_LIFE_PRODUCT_ID, "demand", 2, 4).get("finalized", false)), "second routed demand installs")
	var advance: Dictionary = SUPPORT.advance(flow, bridge, 60.0, 60.0)
	_expect(int(advance.get("market_sold_milliunits", 0)) == 100000, "two commodities consume one shared physical 100/min route budget only once")
	_expect(int(advance.get("market_backlog_milliunits", 0)) == 60000, "the unsent 60 units become commodity-specific unmet market demand instead of route oversell")
	SUPPORT.free_fixture(fixture)


func _backlog_for(records: Dictionary, commodity_id: String) -> int:
	for record_variant in records.values():
		if record_variant is Dictionary and str((record_variant as Dictionary).get("commodity_id", "")) == commodity_id:
			return int((record_variant as Dictionary).get("unmet_backlog_milliunits", 0))
	return -1


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)
