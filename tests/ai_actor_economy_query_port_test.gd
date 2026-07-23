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
	var session := coordinator.get_node_or_null("GameSessionRuntimeController") as GameSessionRuntimeController
	var world := coordinator.world_session_state()
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController
	var port := coordinator.get_node_or_null("AiActorEconomyQueryPort") as AiActorEconomyQueryPort
	var monster := coordinator.get_node_or_null("MonsterRuntimeController") as MonsterRuntimeController
	var monster_bridge := coordinator.get_node_or_null("MonsterRuntimeWorldBridge") as MonsterRuntimeWorldBridge
	var market := coordinator.get_node_or_null("ProductMarketRuntimeController") as ProductMarketRuntimeController
	var region_port := coordinator.get_node_or_null("AiRegionKnowledgeQueryPort") as AiRegionKnowledgeQueryPort
	var rng := coordinator.get_node_or_null("RunRngService") as RunRngService
	_expect(
		session != null and world != null and ai != null and port != null \
			and monster != null and monster_bridge != null and market != null \
			and region_port != null and rng != null,
		"production composition owns the actor economy query and existing authorities"
	)
	monster.set_world_bridge(monster_bridge)
	session.configure({"ruleset_id": "v0.6"}, {})
	session.begin_session({"session_id": "ai-actor-economy-focused", "scenario_id": "focused", "seed": 127, "player_count": 3})
	world.restore({
		"players": [
			_player("Human", false, 990),
			_player("AI-A", true, 700, 10),
			_player("AI-B", true, -50),
		],
		"districts": [
			_district("region:human", "Human City", 0, "HUMAN_WAREHOUSE", 9),
			_district("region:ai-a", "AI A City", 1, "AI_A_WAREHOUSE", 3),
			_district("region:ai-b", "AI B City", 2, "AI_B_WAREHOUSE", 7),
		],
		"game_time": 8.0,
	}, true)
	coordinator._wire_ai_world_typed_ports()
	market.product_market = {
		"AI_A_PRODUCT": {"price": 100, "futures_positions": [_position(11, 1, "AI_A_PRODUCT", 30), _position(12, 2, "AI_B_PRODUCT", 40)]},
		"HUMAN_PRODUCT": {"price": 120, "futures_positions": [_position(13, 0, "HUMAN_PRODUCT", 50)]},
	}
	var capabilities := ai.get("_ai_actor_economy_capabilities") as Dictionary
	var actor_capability := capabilities.get(1) as AiActorEconomyCapability
	var rival_capability := capabilities.get(2) as AiActorEconomyCapability
	_expect(capabilities.size() == 2 and not capabilities.has(0) and actor_capability != null and rival_capability != null, "composition issues economy capabilities only to current AI seats")
	var world_before := world.to_save_data()
	var market_before := market.runtime_state_snapshot()
	var rng_before := rng.capture_plan_checkpoint()
	var snapshot := port.private_economy_snapshot(actor_capability, 1)
	var text := JSON.stringify(snapshot)
	var cash := snapshot.get("cash", {}) as Dictionary
	var economy_summary := snapshot.get("economy_summary", {}) as Dictionary
	var own_cities := snapshot.get("own_cities", []) as Array
	var own_futures := snapshot.get("own_futures", []) as Array
	var negative_cash := (port.private_economy_snapshot(rival_capability, 2).get("cash", {}) as Dictionary)
	_expect(int(cash.get("total_units", -1)) == 700 and int(cash.get("available_units", -1)) == 700 and int(cash.get("reserved_units", -1)) == 0, "actor cash uses the shared wager-aware cash authority")
	_expect(int(economy_summary.get("total_city_income", -1)) == 10 and int(economy_summary.get("total_card_income", -1)) == 20 and int(economy_summary.get("total_role_income", -1)) == 30 and int(economy_summary.get("total_business_spend", -1)) == 60, "actor economy summary exposes only the actor's progression counters")
	_expect(int(negative_cash.get("total_units", 0)) == -50 and int(negative_cash.get("available_units", -1)) == 0, "signed total cash remains exact while bankruptcy leaves zero spendable cash")
	_expect(own_cities.size() == 1 and str((own_cities[0] as Dictionary).get("region_id", "")) == "region:ai-a" and text.contains("AI_A_WAREHOUSE"), "actor snapshot contains only its own city and warehouse facts")
	_expect(not text.contains("AI_B_WAREHOUSE") and not text.contains("HUMAN_WAREHOUSE") and not text.contains("-5000") and not text.contains("99000"), "rival and human private economy facts never cross the port")
	_expect(own_futures.size() == 1 and int((own_futures[0] as Dictionary).get("position_id", -1)) == 11 and text.contains("AI_A_PRODUCT") and not text.contains("AI_B_PRODUCT") and not text.contains("HUMAN_PRODUCT"), "ProductMarket owner projection returns only the actor's futures")
	var public_positions := (((market.public_market_snapshot().get("product_market", {}) as Dictionary).get("AI_A_PRODUCT", {}) as Dictionary).get("futures_positions", []) as Array)
	var public_position := public_positions[0] as Dictionary
	_expect(not public_position.has("owner") and not public_position.has("position_id") and not public_position.has("source") and not public_position.has("card_id") and not public_position.has("locked_margin") and not public_position.has("warehouse_region_id"), "public market futures redact actor, source-card, margin, and private warehouse identity")
	_expect(port.private_economy_snapshot(rival_capability, 1).is_empty() and port.private_economy_snapshot(AiActorEconomyCapability.new(), 1).is_empty() and port.private_economy_snapshot(actor_capability, 0).is_empty(), "rival, forged, and human capability queries fail closed")
	var detached := snapshot.duplicate(true)
	(detached.get("cash", {}) as Dictionary)["total_units"] = 1
	_expect(int(((port.private_economy_snapshot(actor_capability, 1).get("cash", {}) as Dictionary).get("total_units", 0))) == 700, "economy snapshots are detached")
	_expect(world.to_save_data() == world_before and market.runtime_state_snapshot() == market_before and rng.capture_plan_checkpoint() == rng_before, "economy queries perform zero mutation and consume zero RNG")
	var region_capabilities := ai.get("_ai_region_knowledge_capabilities") as Dictionary
	var region_capability := region_capabilities.get(1) as AiRegionKnowledgeCapability
	var actor_regions := region_port.actor_intelligence_snapshot(region_capability, 1)
	var own_region_city := _region_city(actor_regions, "region:ai-a")
	var rival_region_city := _region_city(actor_regions, "region:ai-b")
	var public_region_city := _region_city({"regions": region_port.public_regions_snapshot()}, "region:ai-a")
	_expect(
		region_capability != null \
			and int(own_region_city.get("warehouse_stockpile_units", -1)) == 3,
		"actor-scoped region projection retains only its own warehouse facts"
	)
	_expect(
		not rival_region_city.has("warehouse_stockpile_units") \
			and not rival_region_city.has("warehouse_stockpile_products") \
			and not public_region_city.has("warehouse_stockpile_units") \
			and not public_region_city.has("warehouse_stockpile_products") \
			and int(rival_region_city.get("owner", -1)) == -1,
		"rival and public region projections redact private warehouse inventory and hidden owner truth"
	)
	var old_capability := actor_capability
	(world.players[1] as Dictionary)["actor_id"] = "actor:AI-A:rebound"
	_expect(port.private_economy_snapshot(old_capability, 1).is_empty(), "unsignaled actor identity replacement invalidates the bound capability")
	world.replace_players(world.players.duplicate(true), true)
	capabilities = ai.get("_ai_actor_economy_capabilities") as Dictionary
	actor_capability = capabilities.get(1) as AiActorEconomyCapability
	_expect(actor_capability != null and actor_capability != old_capability and port.private_economy_snapshot(old_capability, 1).is_empty() and not port.private_economy_snapshot(actor_capability, 1).is_empty(), "roster replacement revokes and reissues economy capabilities")
	var controller_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_runtime_controller.gd")
	for function_name in ["_ai_observation_vector", "_record_ai_decision", "_finalize_ai_decision_rewards", "_ai_route_hand_inventory", "_ai_card_play_context", "_ai_card_buy_candidates"]:
		var body := _function_body(controller_source, function_name)
		_expect((body.contains("_actor_cash_units") or body.contains("_actor_available_cash_units") or body.contains("_ai_actor_economy_snapshot")) and not body.contains("players["), "%s reads actor cash without whole-player access" % function_name)
	_expect(not controller_source.contains("_cash_commitment_query_port") and not controller_source.contains("set_cash_commitment_query_port"), "AI no longer receives the unscoped cash query")
	var whole_players_pattern := RegEx.new()
	whole_players_pattern.compile("(^|[^A-Za-z0-9_])players\\s*(\\[|\\.size\\()")
	_expect(not controller_source.contains("\nvar players:") and not controller_source.contains("_world_value(&\"players\"") and whole_players_pattern.search(controller_source) == null, "AI controller has no whole-player collection read or write")
	var direct_interaction_body := _function_body(controller_source, "_ai_direct_player_interaction_plan")
	_expect(direct_interaction_body.contains("_ai_card_hand_snapshot") and not direct_interaction_body.contains("_player_counted_hand_size"), "direct interaction reads only the actor-scoped hand snapshot")
	var plan_source := FileAccess.get_file_as_string("res://scripts/runtime/session_start_plan_builder.gd")
	_expect(plan_source.contains("\"last_cycle_income\": 0") and plan_source.contains("\"cashflow_remainder\": 0.0") and plan_source.contains("\"total_city_income\": 0"), "new-session plans initialize compatibility economy counters before AI starts")
	var debug := port.debug_snapshot()
	_expect(bool(debug.get("port_ready", false)) and int(debug.get("actor_scoped_capability_count", 0)) == 2 and not bool(debug.get("returns_rival_cash", true)) and not bool(debug.get("returns_rival_warehouse", true)) and not bool(debug.get("returns_rival_futures", true)) and not bool(debug.get("references_main", true)), "debug evidence records actor-private zero-Main scope")
	coordinator.queue_free()
	await process_frame
	_finish()


func _player(name: String, is_ai: bool, cash_units: int, progress_seed := 0) -> Dictionary:
	return {
		"id": name.hash(),
		"actor_id": "actor:%s" % name,
		"name": name,
		"seat_type": "ai" if is_ai else "human",
		"is_ai": is_ai,
		"cash": cash_units,
		"cash_cents": cash_units * 100,
		"ai_profile": {},
		"ai_memory": {},
		"cities_built": progress_seed,
		"total_city_income": progress_seed,
		"total_card_income": progress_seed * 2,
		"total_role_income": progress_seed * 3,
		"total_card_spend": progress_seed * 4,
		"total_build_spend": progress_seed * 5,
		"total_business_spend": progress_seed * 6,
	}


func _district(region_id: String, public_name: String, owner: int, marker: String, units: int) -> Dictionary:
	return {
		"region_id": region_id,
		"name": public_name,
		"terrain": "land",
		"products": [],
		"demands": [],
		"city": {
			"active": true,
			"owner": owner,
			"level": 1,
			"products": [{"name": marker}],
			"demands": [],
			"last_income": 12,
			"warehouse_stockpile_count": 1,
			"warehouse_stockpile_units": units,
			"warehouse_stockpile_products": [marker],
		},
	}


func _position(position_id: int, owner: int, product_id: String, locked_margin: int) -> Dictionary:
	return {
		"position_id": position_id,
		"owner": owner,
		"product_id": product_id,
		"card_id": "PRODUCT_FUTURES",
		"direction": "up",
		"baseline_price": 100,
		"opened_at": 1.0,
		"expires_at": 30.0,
		"duration_seconds": 29.0,
		"multiplier": 1.0,
		"units": 1,
		"warehouse_region_id": "region:%d" % owner,
		"locked_margin": locked_margin,
		"maximum_gain": 100,
		"maximum_loss": locked_margin,
		"settled": false,
	}


func _region_city(snapshot: Dictionary, region_id: String) -> Dictionary:
	for row_variant in snapshot.get("regions", []) as Array:
		if row_variant is Dictionary and str((row_variant as Dictionary).get("region_id", "")) == region_id:
			return ((row_variant as Dictionary).get("city", {}) as Dictionary).duplicate(true)
	return {}


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
		print("AI actor economy query port passed (%d checks)." % _checks)
		print("AI_ACTOR_ECONOMY_QUERY_PORT_COMPLETE")
		quit(0)
		return
	push_error("AI actor economy query port failures:\n- " + "\n- ".join(_failures))
	quit(1)
