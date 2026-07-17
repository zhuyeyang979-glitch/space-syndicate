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
	var state := coordinator.table_selection_state()
	_expect(state != null, "production coordinator owns TableSelectionState")
	_expect(coordinator.get_node_or_null("TableSelectionState") == state, "production composition contains one stable selection owner")

	var signal_count := [0]
	state.selection_changed.connect(func(_snapshot: Dictionary) -> void: signal_count[0] = int(signal_count[0]) + 1)
	var restored := state.restore({
		"selected_player": 2,
		"inspected_player": 1,
		"selected_district": 7,
		"selected_trade_product": "环晶电池",
		"selected_hand_slot": 3,
		"selected_map_layer_focus": "weather",
	})
	_expect(int(signal_count[0]) == 1, "atomic restore emits one selection change")
	_expect(
		int(restored.get("selected_player", -1)) == 2
		and int(restored.get("inspected_player", -1)) == 1
		and int(restored.get("selected_district", -1)) == 7
		and str(restored.get("selected_trade_product", "")) == "环晶电池"
		and int(restored.get("selected_hand_slot", -1)) == 3
		and str(restored.get("selected_map_layer_focus", "")) == "weather",
		"atomic restore preserves all table-selection values"
	)
	var saved := state.to_save_data()
	state.set_active_context(3, 4, "星露莓")
	var applied := state.apply_save_data(saved)
	_expect(bool(applied.get("applied", false)), "selection save applies")
	_expect(state.snapshot() == saved, "selection save restores exact state and revision")
	_expect(not bool(state.apply_save_data({"schema_version": 0}).get("applied", true)), "invalid selection save fails closed")

	for bridge_name in [
		"AiRuntimeWorldBridge",
		"MonsterRuntimeWorldBridge",
		"MilitaryRuntimeWorldBridge",
		"ProductMarketRuntimeWorldBridge",
		"ContractRuntimeWorldBridge",
		"CardPlayEligibilityWorldBridge",
		"GameplayBalanceDiagnosticsWorldBridge",
		"RegionInfrastructureWorldBridge",
		"CardResolutionExecutionWorldBridge",
		"CardEconomyProductRouteEffectWorldBridge",
	]:
		var bridge := coordinator.get_node_or_null(bridge_name)
		_expect(
			bridge != null and bridge.call("table_selection_state") == state,
			"%s consumes the typed selection owner" % bridge_name
		)

	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	for field_name in [
		"selected_player",
		"inspected_player",
		"selected_district",
		"selected_trade_product",
	]:
		_expect(
			not main_source.contains("var %s " % field_name)
			and not main_source.contains("var %s:" % field_name)
			and not main_source.contains(".get(\"%s\")" % field_name)
			and not main_source.contains(".set(\"%s\"" % field_name),
			"Main has no field or dynamic compatibility access for %s" % field_name
		)
	_expect(main_source.contains(".table_selection_state().selected_district"), "Main consumes the scene owner directly")
	var coordinator_scene := FileAccess.get_file_as_string("res://scenes/runtime/GameRuntimeCoordinator.tscn")
	_expect(coordinator_scene.count("TableSelectionState.tscn") == 1, "production scene composes exactly one TableSelectionState")

	var debug_snapshot := state.debug_snapshot()
	_expect(typeof(debug_snapshot.get("selected_hand_slot", null)) == TYPE_INT, "selection snapshot exposes only the selected hand-slot index")
	_expect(typeof(debug_snapshot.get("selected_map_layer_focus", null)) == TYPE_STRING, "selection snapshot exposes the public map-layer focus")
	for forbidden_key in ["cash", "hand", "hands", "hand_cards", "cards", "discard", "hidden_owner", "owner_truth", "ai_plan"]:
		_expect(not debug_snapshot.has(forbidden_key), "selection snapshot excludes private field %s" % forbidden_key)

	coordinator.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Table selection state cutover passed (%d checks)." % _checks)
		quit(0)
		return
	push_error("Table selection state cutover failed:\n- " + "\n- ".join(_failures))
	quit(1)
