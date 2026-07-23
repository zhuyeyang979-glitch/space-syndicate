extends SceneTree

const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var coordinator := COORDINATOR_SCENE.instantiate() as GameRuntimeCoordinator
	root.add_child(coordinator)
	await process_frame
	var market := coordinator.get_node_or_null("ProductMarketRuntimeController") as ProductMarketRuntimeController
	var routes := coordinator.get_node_or_null("RouteNetworkRuntimeController") as RouteNetworkRuntimeController
	var market_port := coordinator.get_node_or_null("AiMarketPublicQueryPort") as AiMarketPublicQueryPort
	var route_port := coordinator.get_node_or_null("AiRoutePublicQueryPort") as AiRoutePublicQueryPort
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController
	var world := coordinator.world_session_state()
	var rng := coordinator.get_node_or_null("RunRngService") as RunRngService
	_expect(market != null and routes != null and market_port != null and route_port != null and ai != null and world != null and rng != null, "production composition owns both public query ports and existing authorities")
	world.restore({
		"players": [{"name": "Human"}, {"name": "AI", "is_ai": true, "seat_type": "ai"}],
		"districts": [
			{"region_id": "region:a", "name": "A", "city": {"active": true, "owner": 1}},
			{"region_id": "region:b", "name": "B", "city": {"active": true, "owner": 0}},
		],
		"game_time": 5.0,
	}, true)
	var first_product := str(ProductMarketRuntimeController.PRODUCT_CATALOG[0])
	market.product_market = _market_fixture(first_product)
	market.business_cycle_count = 9
	market.set("_configured", true)
	routes.set("_configured", true)
	routes.set("_cached_topology_revision", "route-public-revision-1")
	routes.set("_cached_all_candidates", [_route_fixture()])
	var market_before := market.runtime_state_snapshot()
	var route_before := (routes.get("_cached_all_candidates") as Array).duplicate(true)
	var rng_before := rng.capture_plan_checkpoint()
	var market_snapshot := market_port.public_snapshot()
	var product := market_port.public_product(first_product)
	var route_snapshot := route_port.public_snapshot()
	var route_row := (route_snapshot.get("rows", []) as Array)[0] as Dictionary
	var region_summary := route_port.region_route_summary(0)
	_expect(bool(market_snapshot.get("available", false)) and int(market_snapshot.get("product_count", 0)) == 46 and (market_snapshot.get("products", []) as Array).size() == 46, "market port requires and returns the complete public catalog")
	_expect(int(product.get("price", 0)) == 90 and int(product.get("base_price", 0)) == 70 and int(product.get("demand", 0)) == 2 and int(product.get("supply", 0)) == 1, "market query preserves the public scoring facts")
	var public_futures := product.get("futures_positions", []) as Array
	_expect(public_futures.size() == 1 and not (public_futures[0] as Dictionary).has("owner") and not (public_futures[0] as Dictionary).has("source") and not (public_futures[0] as Dictionary).has("locked_margin"), "market port rejects private futures identity and margin")
	_expect(int(ai._ai_product_market_signal_score(first_product)) == 94 and int(ai._product_price(first_product)) == 90, "AI market scoring consumes only the typed public product projection")
	_expect(bool(route_snapshot.get("available", false)) and int(route_snapshot.get("route_count", 0)) == 1 and str(route_row.get("route_id", "")) == "route:public-a-b", "route query preserves a stable public route identity")
	_expect((route_row.get("mode_tags", []) as Array) == ["land", "sea"] and int(route_row.get("bottleneck_units_per_minute", 0)) == 175 and is_equal_approx(float(route_row.get("route_efficiency_multiplier", 0.0)), 1.0), "route projection uses authored mode tags and bottleneck fields")
	_expect(not route_row.has("facility_ids") and not route_row.has("capacity_resources") and not route_row.has("expected_rents") and not route_row.has("region_revision_fingerprint"), "route projection excludes facility, rent-recipient, resource, and topology lineage")
	_expect(int(region_summary.get("legal_route_count", 0)) == 1 and (region_summary.get("rows", []) as Array).size() == 1 and ai._route_network_load_for_legacy_region(0) == 1 and ai._route_network_routes_for_legacy_region(0).size() == 1, "legacy AI route scoring consumes the typed public region summary")
	var detached_market := market_snapshot.duplicate(true)
	(detached_market.get("products", []) as Array)[0]["price"] = -1
	var detached_route := route_snapshot.duplicate(true)
	(detached_route.get("rows", []) as Array)[0]["route_id"] = "mutated"
	_expect(market_port.public_product(first_product).get("price") == 90 and str(((route_port.public_snapshot().get("rows", []) as Array)[0] as Dictionary).get("route_id", "")) == "route:public-a-b", "market and route snapshots are detached")
	_expect(market.runtime_state_snapshot() == market_before and (routes.get("_cached_all_candidates") as Array) == route_before and rng.capture_plan_checkpoint() == rng_before, "market and route queries perform zero mutation and consume zero RNG")
	var full_market := market.product_market.duplicate(true)
	var partial_market := {}
	partial_market[first_product] = full_market[first_product]
	market.product_market = partial_market
	var rng_before_failure := rng.capture_plan_checkpoint()
	var failure := market_port.public_snapshot()
	_expect(not bool(failure.get("available", true)) and market.product_market.size() == 1 and rng.capture_plan_checkpoint() == rng_before_failure, "incomplete market fails closed without catalog generation or RNG")
	market.product_market = full_market
	var controller_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_runtime_controller.gd")
	_expect(not controller_source.contains("runtime_state_snapshot().get(\"product_market\"") and not controller_source.contains("_ensure_product_market_catalog") and not controller_source.contains("var product_market:"), "AI has no private ProductMarket snapshot or query-time catalog mutation")
	var route_load_body := _function_body(controller_source, "_route_network_load_for_legacy_region")
	var route_rows_body := _function_body(controller_source, "_route_network_routes_for_legacy_region")
	_expect(route_load_body.contains("_route_public_summary") and route_rows_body.contains("_route_public_summary") and not route_load_body.contains("_route_network_runtime_controller") and not route_rows_body.contains("_route_network_runtime_controller"), "AI route scoring has no raw candidate fallback")
	var market_debug := market_port.debug_snapshot()
	var route_debug := route_port.debug_snapshot()
	_expect(not bool(market_debug.get("calls_ensure_catalog", true)) and not bool(market_debug.get("consumes_rng", true)) and not bool(route_debug.get("refreshes_routes", true)) and not bool(route_debug.get("consumes_rng", true)) and not bool(route_debug.get("references_main", true)), "debug evidence records pure zero-Main query boundaries")
	coordinator.queue_free()
	await process_frame
	_finish()


func _market_fixture(first_product: String) -> Dictionary:
	var result := {}
	for product_variant in ProductMarketRuntimeController.PRODUCT_CATALOG:
		var product_id := str(product_variant)
		result[product_id] = {
			"tier": "public",
			"base_price": 70 if product_id == first_product else 50,
			"price": 90 if product_id == first_product else 50,
			"trend": 1 if product_id == first_product else 0,
			"volatility": 4,
			"supply": 1 if product_id == first_product else 0,
			"demand": 2 if product_id == first_product else 0,
			"disrupted": 0,
			"temporary_demand_pressure": 1 if product_id == first_product else 0,
			"temporary_supply_pressure": 0,
			"market_contract_demand": 1 if product_id == first_product else 0,
			"market_contract_supply": 0,
			"growth_multiplier": 1.2 if product_id == first_product else 1.0,
			"route_flow_multiplier": 1.1 if product_id == first_product else 1.0,
			"futures_positions": [{
				"position_id": 77,
				"owner": 1,
				"source": "PRIVATE_CARD_SOURCE",
				"card_id": "PRIVATE_CARD_ID",
				"direction": "up",
				"locked_margin": 600,
				"warehouse_region_id": "PRIVATE_WAREHOUSE",
			}] if product_id == first_product else [],
		}
	return result


func _route_fixture() -> Dictionary:
	return {
		"route_id": "route:public-a-b",
		"source_region_id": "region:a",
		"market_region_id": "region:b",
		"ordered_region_ids": ["region:a", "region:b"],
		"mode_tags": ["land", "sea"],
		"actual_distance": 1,
		"shortest_legal_distance": 1,
		"transfer_count": 0,
		"bottleneck_units_per_minute": 175,
		"route_efficiency_multiplier": 1.0,
		"facility_ids": ["PRIVATE_FACILITY"],
		"capacity_resources": [{"resource_id": "PRIVATE_RESOURCE", "capacity_units_per_minute": 175}],
		"expected_rents": [{"recipient_player_index": 1}],
		"rent_rate_pending": false,
		"region_revision_fingerprint": "PRIVATE_TOPOLOGY_FINGERPRINT",
	}


func _function_body(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return ""
	var next := source.find("\nfunc ", start + 1)
	return source.substr(start) if next < 0 else source.substr(start, next - start)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("AI market/route public query ports passed (%d checks)." % _checks)
		print("AI_MARKET_ROUTE_PUBLIC_QUERY_PORTS_COMPLETE")
		quit(0)
		return
	push_error("AI market/route public query port failures:\n- " + "\n- ".join(_failures))
	quit(1)
