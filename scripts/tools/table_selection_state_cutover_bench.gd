extends Node

@onready var coordinator: GameRuntimeCoordinator = $GameRuntimeCoordinator


func _ready() -> void:
	var failures: Array[String] = []
	var state := coordinator.table_selection_state()
	if state == null:
		failures.append("table_selection_state_missing")
	else:
		var before_revision := int(state.snapshot().get("revision", -1))
		var snapshot := state.restore({
			"selected_player": 3,
			"inspected_player": 2,
			"selected_district": 5,
			"selected_trade_product": "真空可可",
		})
		if int(snapshot.get("revision", -1)) != before_revision + 1:
			failures.append("selection_revision_not_exact_once")
		if state.to_save_data() != snapshot:
			failures.append("selection_save_not_exact")
	for bridge_name in [
		"MonsterRuntimeWorldBridge",
		"MilitaryRuntimeWorldBridge",
		"ProductMarketRuntimeWorldBridge",
		"CardPlayEligibilityWorldBridge",
		"GameplayBalanceDiagnosticsWorldBridge",
		"RegionInfrastructureWorldBridge",
		"CardResolutionExecutionWorldBridge",
		"CardEconomyProductRouteEffectWorldBridge",
	]:
		var bridge := coordinator.get_node_or_null(bridge_name)
		if bridge == null or bridge.call("table_selection_state") != state:
			failures.append("typed_selection_bridge_missing:%s" % bridge_name)
	if coordinator.get_node_or_null("AiRuntimeWorldBridge") != null:
		failures.append("ai_world_bridge_not_deleted")
	print(
		"TABLE_SELECTION_STATE_CUTOVER_BENCH|status=%s|checks=13|failures=%d|notes=%s"
		% ["PASS" if failures.is_empty() else "FAIL", failures.size(), JSON.stringify(failures)]
	)
	if not failures.is_empty():
		push_error("Table selection state cutover Bench failed: %s" % failures)
