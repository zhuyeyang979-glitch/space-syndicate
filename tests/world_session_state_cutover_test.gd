extends SceneTree

const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")
const MAIN_SCENE := preload("res://scenes/main.tscn")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var coordinator := COORDINATOR_SCENE.instantiate() as GameRuntimeCoordinator
	root.add_child(coordinator)
	await process_frame
	var state := coordinator.world_session_state()
	_expect(state != null, "production coordinator owns WorldSessionState")
	_expect(coordinator.get_node_or_null("WorldSessionState") == state, "production composition contains one stable world-session owner")

	var players := [{"name": "本席", "cash": 900}, {"name": "对手", "cash": 800}]
	var districts := [{"name": "港区", "destroyed": false}, {"name": "海区", "destroyed": false}]
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

	for bridge_name in [
		"AiRuntimeWorldBridge",
		"MonsterRuntimeWorldBridge",
		"MilitaryRuntimeWorldBridge",
		"WeatherRuntimeWorldBridge",
		"ProductMarketRuntimeWorldBridge",
		"ContractRuntimeWorldBridge",
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
	var player_state_adapter := coordinator.get_node_or_null("CardPlayerStateProductionAdapterV06")
	var inventory := coordinator.get_node_or_null("CommodityCardInventoryRuntimeController")
	_expect(
		player_state_adapter != null
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
			not main_source.contains("var %s " % field_name)
			and not main_source.contains("var %s:" % field_name)
			and not main_source.contains(".get(\"%s\")" % field_name)
			and not main_source.contains(".set(\"%s\"" % field_name),
			"Main has no field or dynamic compatibility access for %s" % field_name
		)
	_expect(main_source.contains(".world_session_state().players"), "Main consumes player records through the scene owner")
	_expect(main_source.contains(".world_session_state().districts"), "Main consumes district records through the scene owner")
	_expect(main_source.contains(".world_session_state().game_time"), "Main consumes elapsed time through the scene owner")
	var coordinator_scene := FileAccess.get_file_as_string("res://scenes/runtime/GameRuntimeCoordinator.tscn")
	_expect(coordinator_scene.count("WorldSessionState.tscn") == 1, "production scene composes exactly one WorldSessionState")

	var debug_text := JSON.stringify(state.debug_snapshot())
	for forbidden in ["cash", "hand", "discard", "hidden_owner", "owner_truth", "ai_plan", "player_records", "district_records"]:
		_expect(not debug_text.contains(forbidden), "world-session debug snapshot excludes private payload %s" % forbidden)
	_expect(int(state.debug_snapshot().get("player_count", -1)) == 2, "debug snapshot exposes only aggregate player count")

	var main := MAIN_SCENE.instantiate()
	main.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(main)
	await process_frame
	var main_coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator
	_expect(main_coordinator != null and main_coordinator.world_session_state() != null, "production Main mounts the scene-owned world-session state")
	if main.has_method("_new_game"):
		main.call("_new_game")
		await process_frame
		var main_state := main_coordinator.world_session_state()
		_expect(not main_state.players.is_empty(), "new-game setup writes player records into WorldSessionState")
		_expect(not main_state.districts.is_empty(), "new-game setup writes district records into WorldSessionState")
		_expect(is_equal_approx(main_state.game_time, 0.0), "new-game setup resets scene-owned gameplay time")

	main.queue_free()
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
