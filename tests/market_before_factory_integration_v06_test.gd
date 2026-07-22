extends SceneTree

const SUPPORT := preload("res://tests/support/commodity_flow_v06_test_support.gd")
const FLOW_SCRIPT := preload("res://scripts/runtime/commodity_flow_runtime_controller.gd")
const WORLD_BRIDGE_SCRIPT := preload("res://scripts/runtime/commodity_flow_world_bridge.gd")

var _checks := 0
var _failures: Array[String] = []


class InfrastructureFacts:
	extends Node

	var regions: Array = []
	var facilities: Array = []
	var retired_facilities: Array = []

	func regions_snapshot() -> Array:
		return regions.duplicate(true)

	func facilities_snapshot(include_inactive := false) -> Array:
		var result := facilities.duplicate(true)
		if include_inactive:
			result.append_array(retired_facilities.duplicate(true))
		return result

	func region_snapshot(region_id: String) -> Dictionary:
		for region_variant in regions:
			if region_variant is Dictionary and str((region_variant as Dictionary).get("region_id", "")) == region_id:
				return (region_variant as Dictionary).duplicate(true)
		return {}


class ProductMarketFacts:
	extends Node

	func product_price(_commodity_id: String) -> int:
		return 10


class RouteNetworkFacts:
	extends Node

	var routes: Array = []

	func all_route_candidates(_commodity_id := "*") -> Array:
		return routes.duplicate(true)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := WorldSessionState.new()
	world.replace_players([
		{"cash": 0, "cash_cents": 0, "v06_transaction_ledger": []},
		{"cash": 0, "cash_cents": 0, "v06_transaction_ledger": []},
	], true)
	var infrastructure := InfrastructureFacts.new()
	var product_market := ProductMarketFacts.new()
	var route_network := RouteNetworkFacts.new()
	var flow := FLOW_SCRIPT.new()
	var bridge := WORLD_BRIDGE_SCRIPT.new()
	root.add_child(world)
	root.add_child(infrastructure)
	root.add_child(product_market)
	root.add_child(route_network)
	root.add_child(flow)
	root.add_child(bridge)
	var region := SUPPORT.region("region.integration")
	var market := SUPPORT.facility("market.integration", "region.integration", "market", 1)
	var factory := SUPPORT.facility("factory.integration", "region.integration", "factory", 0)
	infrastructure.regions = [region]
	infrastructure.facilities = [market]
	bridge.call("set_world_session_state", world)
	bridge.call("set_controller", flow)
	bridge.call("set_runtime_dependencies", infrastructure, product_market, route_network)
	flow.call("set_world_bridge", bridge)
	var configured: Dictionary = flow.call("configure", SUPPORT.profile_snapshot())
	_expect(bool(configured.get("configured", false)), "real CommodityFlow owner configures behind the production WorldBridge")
	_expect(bool(SUPPORT.install(flow, market, SUPPORT.DEFAULT_PRODUCT_ID, "demand", 1, 1).get("finalized", false)), "market facility and concrete demand install before any factory")
	var first := _advance(flow, world, 60.0)
	var second := _advance(flow, world, 60.0)
	_expect(int(first.get("market_backlog_milliunits", 0)) == 10000 and int(second.get("market_backlog_milliunits", 0)) == 20000, "market-first production path accrues capped unmet demand without supply")
	_expect(bool(first.get("advanced", false)) and bool(second.get("advanced", false)) and int(first.get("receipt_count", -1)) == 0 and int(second.get("receipt_count", -1)) == 0 and int((world.players[0] as Dictionary).get("cash_cents", -1)) == 0, "empty authoritative batches advance without inventing cash or manual orders")
	infrastructure.facilities = [market, factory]
	_expect(bool(SUPPORT.install(flow, factory, SUPPORT.DEFAULT_PRODUCT_ID, "production", 0, 2).get("finalized", false)), "matching factory installs later")
	var no_route := _advance(flow, world, 60.0)
	_expect(int(no_route.get("market_sold_milliunits", -1)) == 0 and int(no_route.get("market_backlog_milliunits", 0)) == 20000, "the real bridge cannot turn same-region facts into a fabricated explicit route")
	route_network.routes = [
		SUPPORT.route("local:integration", "region.integration", "region.integration", 1000000, "local:integration", ["local"], 0),
	]
	var recovery_one := _advance(flow, world, 60.0)
	var recovery_two := _advance(flow, world, 60.0)
	var steady := _advance(flow, world, 60.0)
	_expect(int(recovery_one.get("market_backlog_milliunits", -1)) == 10000 and int(recovery_two.get("market_backlog_milliunits", -1)) == 0, "authoritative route arrival enables gradual steady-first recovery")
	_expect(int(steady.get("market_sold_milliunits", 0)) == 10000 and int(steady.get("market_backlog_milliunits", -1)) == 0, "integration returns to steady automatic consumption after backlog reaches zero")
	var player_zero: Dictionary = world.players[0]
	var player_one: Dictionary = world.players[1]
	_expect(int(player_zero.get("cash_cents", 0)) == 50200 and (player_zero.get("v06_transaction_ledger", []) as Array).size() == 52, "actual market and ambient consumption apply exactly once to the commodity owner's cash ledger")
	_expect(int(player_one.get("cash_cents", 0)) == 0, "market ownership alone creates no synthetic turnover cash")
	var bridge_debug: Dictionary = bridge.call("debug_snapshot")
	_expect(not bool(bridge_debug.get("owns_flow_rules", true)) and not bool(bridge_debug.get("owns_installations", true)) and not bool(bridge_debug.get("owns_routes", true)), "WorldBridge exposes facts and atomic application without copying economic computation")
	for node in [bridge, flow, route_network, product_market, infrastructure, world]:
		node.queue_free()
	print("MARKET_BEFORE_FACTORY_INTEGRATION_V06_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	quit(_failures.size())


func _advance(flow: Node, world: WorldSessionState, seconds: float) -> Dictionary:
	world.game_time += seconds
	return flow.call("advance_world", seconds)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)
