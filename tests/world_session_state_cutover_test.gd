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
	coordinator.configure({"ruleset_id": "v0.6"})
	var state := coordinator.world_session_state()
	var game_session := coordinator.get_node_or_null("GameSessionRuntimeController") as GameSessionRuntimeController
	var session_port := coordinator.get_node_or_null("AiSessionPublicQueryPort") as AiSessionPublicQueryPort
	var actor_port := coordinator.get_node_or_null("AiActorStatePort") as AiActorStatePort
	var region_port := coordinator.get_node_or_null("AiRegionKnowledgeQueryPort") as AiRegionKnowledgeQueryPort
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController
	var rng := coordinator.run_rng_service()
	_expect(
		state != null and game_session != null and session_port != null and actor_port != null \
			and region_port != null and ai != null and rng != null,
		"production coordinator owns WorldSessionState and the scoped AI query ports"
	)
	_expect(coordinator.get_node_or_null("WorldSessionState") == state, "production composition contains one stable world-session owner")

	game_session.configure({"ruleset_id": "v0.6"}, {})
	game_session.begin_session({
		"session_id": "world-session-cutover",
		"scenario_id": "focused",
		"seed": 7331,
		"player_count": 2,
	})
	var players := [
		{
			"id": "player:0",
			"actor_id": "actor:0",
			"name": "本席",
			"seat_type": "human",
			"is_ai": false,
			"eliminated": false,
			"cash": 900,
		},
		{
			"id": "player:1",
			"actor_id": "actor:1",
			"name": "对手",
			"seat_type": "ai",
			"is_ai": true,
			"eliminated": false,
			"cash": 800,
			"ai_profile": {"policy_id": "balanced"},
			"ai_memory": {"private_marker": "AI_PRIVATE_SENTINEL"},
		},
	]
	var districts := [
		{
			"region_id": "region.000",
			"name": "港区",
			"destroyed": false,
			"products": ["晶矿"],
			"demands": [],
			"city": {"active": true, "owner": 1, "products": [], "demands": []},
		},
		{
			"region_id": "region.001",
			"name": "海区",
			"destroyed": false,
			"products": ["生物质"],
			"demands": [],
		},
	]
	state.restore({"players": players, "districts": districts, "game_time": 12.5}, true)
	_expect(state.players.size() == 2 and state.districts.size() == 2, "world-session restore owns player and district records")
	_expect(is_equal_approx(state.game_time, 12.5), "world-session restore owns elapsed gameplay time")
	var live_players := state.players
	(live_players[0] as Dictionary)["cash"] = 850
	_expect(int((state.players[0] as Dictionary).get("cash", 0)) == 850, "owner exposes the existing live player record semantics")
	_expect(is_equal_approx(state.advance_game_time(2.5), 15.0), "owner advances elapsed gameplay time deterministically")
	var saved := state.to_save_data()
	state.reset()
	var applied := state.apply_save_data(saved)
	_expect(bool(applied.get("applied", false)), "world-session save applies")
	_expect(state.to_save_data() == saved, "world-session save roundtrip restores exact records and time")
	_expect(not bool(state.apply_save_data({"schema_version": 0}).get("applied", true)), "invalid world-session save fails closed")

	coordinator._wire_ai_world_typed_ports()
	var actor_capabilities := ai.get("_ai_actor_state_capabilities") as Dictionary
	var region_capabilities := ai.get("_ai_region_knowledge_capabilities") as Dictionary
	var actor_cap := actor_capabilities.get(1) as AiActorStateCapability
	var region_cap := region_capabilities.get(1) as AiRegionKnowledgeCapability
	var rng_before_queries := rng.capture_plan_checkpoint()
	var public_session := session_port.public_snapshot()
	var public_players := actor_port.public_players_snapshot()
	var private_actor := actor_port.ai_actor_state_snapshot(actor_cap, 1)
	var actor_regions := region_port.regions_for_actor(region_cap, 1)
	_expect(
		int(public_session.get("player_count", -1)) == 2 \
			and int(public_session.get("district_count", -1)) == 2 \
			and is_equal_approx(float(public_session.get("game_time", -1.0)), 15.0),
		"AiSessionPublicQueryPort reads aggregate world facts from WorldSessionState"
	)
	_expect(
		TablePresentationPureDataPolicy.is_pure_data(public_players) \
			and TablePresentationPureDataPolicy.is_pure_data(private_actor) \
			and TablePresentationPureDataPolicy.is_pure_data(actor_regions),
		"AI world projections are detached pure data"
	)
	_expect(
		int(private_actor.get("player_index", -1)) == 1 \
			and JSON.stringify(private_actor).contains("AI_PRIVATE_SENTINEL") \
			and not JSON.stringify(public_players).contains("AI_PRIVATE_SENTINEL") \
			and not JSON.stringify(public_players).contains("\"cash\""),
		"AI private actor projection is actor-scoped while public players omit cash and memory"
	)
	_expect(
		actor_regions.size() == 2 \
			and str(((actor_regions[0] as Dictionary).get("city", {}) as Dictionary).get("owner_knowledge", "")) == "actor_own",
		"AI region projection recognizes only its own authoritative city ownership"
	)
	_expect(rng.capture_plan_checkpoint() == rng_before_queries, "AI world queries consume zero RNG")

	for bridge_name in [
		"MonsterRuntimeWorldBridge",
		"MilitaryRuntimeWorldBridge",
		"WeatherRuntimeWorldBridge",
		"ProductMarketRuntimeWorldBridge",
		"CardPlayEligibilityWorldBridge",
		"GameplayBalanceDiagnosticsWorldBridge",
		"RegionInfrastructureWorldBridge",
		"CardResolutionExecutionWorldBridge",
		"CardEconomyProductRouteEffectWorldBridge",
		"CardMarketPolicyWorldBridge",
		"CityGdpDerivativeRuntimeWorldBridge",
		"RouteNetworkWorldBridge",
		"CommodityFlowWorldBridge",
		"VictoryControlWorldBridge",
		"BankruptcyNeutralEstateWorldBridge",
	]:
		var bridge := coordinator.get_node_or_null(bridge_name)
		_expect(
			bridge != null and bridge.call("world_session_state") == state,
			"%s consumes the typed world-session owner" % bridge_name
		)
	_expect(
		coordinator.get_node_or_null("AiRuntimeWorldBridge") == null,
		"AI consumes WorldSessionState only through scoped typed ports"
	)

	var player_state_adapter := coordinator.get_node_or_null("CardPlayerStateProductionAdapterV06")
	var inventory := coordinator.get_node_or_null("CommodityCardInventoryRuntimeController")
	_expect(
		player_state_adapter != null \
			and bool(player_state_adapter.call("set_world_session_state", state).get("bound", false)),
		"production player-state port consumes WorldSessionState instead of Main"
	)
	_expect(
		inventory != null and inventory.has_method("set_world_session_state"),
		"production card inventory exposes only the scene-state binding"
	)

	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	for field_name in ["players", "districts", "game_time"]:
		_expect(
			not main_source.contains("var %s " % field_name) \
				and not main_source.contains("var %s:" % field_name) \
				and not main_source.contains(".get(\"%s\")" % field_name) \
				and not main_source.contains(".set(\"%s\"" % field_name),
			"Main has no field or dynamic compatibility access for %s" % field_name
		)
	_expect(main_source.contains(".world_session_state().players"), "Main consumes player records through the scene owner")
	_expect(main_source.contains(".world_session_state().districts"), "Main consumes district records through the scene owner")
	_expect(main_source.contains(".world_session_state().game_time"), "Main consumes elapsed time through the scene owner")
	_expect(not main_source.contains("func _new_game("), "retired Main new-game mutation path remains physically absent")
	_expect(ResourceLoader.exists("res://scenes/runtime/SessionStartTransactionCoordinator.tscn"), "formal session starts are owned by the scene transaction coordinator")
	var coordinator_scene := FileAccess.get_file_as_string("res://scenes/runtime/GameRuntimeCoordinator.tscn")
	_expect(coordinator_scene.count("WorldSessionState.tscn") == 1, "production scene composes exactly one WorldSessionState")

	var debug_text := JSON.stringify(state.debug_snapshot())
	for forbidden in ["cash", "hand", "discard", "hidden_owner", "owner_truth", "ai_plan", "player_records", "district_records"]:
		_expect(not debug_text.contains(forbidden), "world-session debug snapshot excludes private payload %s" % forbidden)
	_expect(int(state.debug_snapshot().get("player_count", -1)) == 2, "debug snapshot exposes only aggregate player count")

	coordinator.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("World session state cutover passed (%d checks)." % _checks)
		quit(0)
		return
	push_error("World session state cutover failed:\n- " + "\n- ".join(_failures))
	quit(1)