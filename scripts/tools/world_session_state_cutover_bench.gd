extends Node

@onready var coordinator: GameRuntimeCoordinator = $GameRuntimeCoordinator


func _ready() -> void:
	var failures: Array[String] = []
	var state := coordinator.world_session_state()
	if state == null:
		failures.append("world_session_state_missing")
	else:
		state.restore({
			"players": [{"name": "本席"}, {"name": "对手"}],
			"districts": [{"name": "区域A"}, {"name": "区域B"}, {"name": "区域C"}],
			"game_time": 18.0,
		})
		if state.players.size() != 2 or state.districts.size() != 3:
			failures.append("world_session_records_invalid")
		if not is_equal_approx(state.advance_game_time(2.0), 20.0):
			failures.append("world_session_time_invalid")
	for bridge_name in [
		"AiRuntimeWorldBridge",
		"MonsterRuntimeWorldBridge",
		"MilitaryRuntimeWorldBridge",
		"WeatherRuntimeWorldBridge",
		"ProductMarketRuntimeWorldBridge",
		"ContractRuntimeWorldBridge",
		"CardPlayEligibilityWorldBridge",
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
		if bridge == null or bridge.call("world_session_state") != state:
			failures.append("typed_world_session_bridge_missing:%s" % bridge_name)
	print(
		"WORLD_SESSION_STATE_CUTOVER_BENCH|status=%s|checks=19|failures=%d|notes=%s"
		% ["PASS" if failures.is_empty() else "FAIL", failures.size(), JSON.stringify(failures)]
	)
	if not failures.is_empty():
		push_error("World session state cutover Bench failed: %s" % failures)
