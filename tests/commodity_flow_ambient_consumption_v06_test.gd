extends SceneTree

const SUPPORT := preload("res://tests/support/commodity_flow_v06_test_support.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_local_and_adjacent_only()
	_verify_unfulfilled_due_expires()
	_verify_saved_residual_fairness()
	print("COMMODITY_FLOW_AMBIENT_CONSUMPTION_V06_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	quit(_failures.size())


func _verify_local_and_adjacent_only() -> void:
	var regions := [
		SUPPORT.region("region.source", ["region.adjacent"], "land"),
		SUPPORT.region("region.adjacent", ["region.source", "region.second"], "land"),
		SUPPORT.region("region.second", ["region.adjacent"], "land"),
		SUPPORT.region("region.sea", ["region.source"], "sea"),
	]
	var factory := SUPPORT.facility("factory.source", "region.source", "factory", 0)
	var fixture := SUPPORT.create_fixture(self, regions, [factory], [])
	var flow: Node = fixture.get("flow")
	var bridge = fixture.get("bridge")
	_expect(bool((fixture.get("configured", {}) as Dictionary).get("configured", false)), "ambient fixture configures")
	_expect(bool(SUPPORT.install(flow, factory, SUPPORT.DEFAULT_PRODUCT_ID, "production", 0, 1, false, "factory-source-install").get("finalized", false)), "ambient production installation finalizes")
	var advance: Dictionary = SUPPORT.advance(flow, bridge, 60.0, 60.0)
	_expect(bool(advance.get("advanced", false)), "ambient fixture advances")
	_expect(int(advance.get("ambient_consumed_milliunits", 0)) == 2000, "only same-region and direct-adjacent land demand consume fresh output")
	_expect(int(advance.get("wasted_milliunits", 0)) == 8000, "second-hop and sea demand do not consume the remaining fresh output")
	var receipts: Array = bridge.committed_receipts
	_expect(receipts.size() == 2, "two whole ambient units emit exactly two receipts")
	var trade_kinds: Dictionary = {}
	var consuming_regions: Dictionary = {}
	for receipt_variant in receipts:
		var receipt: Dictionary = receipt_variant
		trade_kinds[str(receipt.get("trade_kind", ""))] = true
		consuming_regions[str(receipt.get("consuming_region_id", ""))] = true
		_expect(str(receipt.get("route_id", "x")).is_empty() and (receipt.get("rent_rows", []) as Array).is_empty(), "ambient receipt fabricates no route or rent")
		_expect(int(receipt.get("distance_premium_basis_points", -1)) == 0 and int(receipt.get("owner_net_cash", 0)) == int(receipt.get("gdp_value", -1)), "ambient value has no distance premium and pays the commodity owner")
	_expect(trade_kinds.has("ambient_local_consumption") and trade_kinds.has("ambient_adjacent_land_consumption"), "both ambient receipt kinds are committed")
	_expect(consuming_regions.has("region.source") and consuming_regions.has("region.adjacent") and not consuming_regions.has("region.second") and not consuming_regions.has("region.sea"), "GDP belongs only to eligible consuming regions")
	var save: Dictionary = flow.call("to_save_data")
	var ambient_remainders: Dictionary = save.get("ambient_rate_remainders", {})
	_expect(ambient_remainders.size() >= 46 * regions.size(), "every active commodity has an ambient fixed-point claim in every live region")
	_expect(not JSON.stringify(save).contains("ambient_backlog"), "ambient unmet demand is never persisted as backlog")
	SUPPORT.free_fixture(fixture)


func _verify_unfulfilled_due_expires() -> void:
	var fixture := SUPPORT.create_fixture(self, [SUPPORT.region("region.only")], [], [])
	var flow: Node = fixture.get("flow")
	var bridge = fixture.get("bridge")
	var empty_advance: Dictionary = SUPPORT.advance(flow, bridge, 60.0, 60.0)
	_expect(bool(empty_advance.get("advanced", false)) and bridge.committed_receipts.is_empty(), "an ambient tick without supply advances without settlement")
	var injected: Dictionary = flow.call("inject_one_shot_supply", {
		"transaction_id": "ambient-current-tick-only",
		"commodity_id": SUPPORT.DEFAULT_PRODUCT_ID,
		"region_id": "region.only",
		"owner_player_index": 0,
		"milliunits": 1000,
	})
	_expect(bool(injected.get("accepted", false)), "fresh one-shot supply is accepted")
	var supplied_advance: Dictionary = SUPPORT.advance(flow, bridge, 60.0, 60.0)
	_expect(int(supplied_advance.get("ambient_consumed_milliunits", 0)) == 1000 and bridge.committed_receipts.size() == 1, "later supply serves only the new ambient tick, not expired unmet demand")
	SUPPORT.free_fixture(fixture)


func _verify_saved_residual_fairness() -> void:
	var region := SUPPORT.region("region.fair")
	var factory_a := SUPPORT.facility("factory.a", "region.fair", "factory", 0)
	var factory_b := SUPPORT.facility("factory.b", "region.fair", "factory", 1)
	var fixture := SUPPORT.create_fixture(self, [region], [factory_a, factory_b], [])
	var flow: Node = fixture.get("flow")
	var bridge = fixture.get("bridge")
	_expect(bool(SUPPORT.install(flow, factory_a, SUPPORT.DEFAULT_PRODUCT_ID, "production", 0, 1, false, "factory-a-install").get("finalized", false)), "first fair source installs")
	_expect(bool(SUPPORT.install(flow, factory_b, SUPPORT.DEFAULT_PRODUCT_ID, "production", 1, 1, false, "factory-b-install").get("finalized", false)), "second fair source installs")
	var advance: Dictionary = SUPPORT.advance(flow, bridge, 0.12, 0.06)
	_expect(bool(advance.get("advanced", false)) and int(advance.get("ambient_consumed_milliunits", 0)) == 2, "two one-milliunit ambient residuals are allocated")
	var save: Dictionary = flow.call("to_save_data")
	var cumulative: Dictionary = save.get("cumulative_wasted_milliunits_by_source", {})
	_expect(int(cumulative.get("factory-a-install", -1)) == 19 and int(cumulative.get("factory-b-install", -1)) == 19, "saved residual cursor rotates equal sources without permanent first-source advantage")
	_expect(not (save.get("ambient_fairness_cursor_by_region_commodity", {}) as Dictionary).is_empty(), "ambient fairness cursor is persisted")
	SUPPORT.free_fixture(fixture)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)
