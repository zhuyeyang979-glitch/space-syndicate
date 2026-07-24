extends SceneTree

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/runtime/GameRuntimeCoordinator.tscn") as PackedScene
	var coordinator := packed.instantiate() as GameRuntimeCoordinator if packed != null else null
	_expect(coordinator != null, "production coordinator scene instantiates")
	if coordinator == null:
		_finish()
		return
	get_root().add_child(coordinator)
	await process_frame
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController
	var port := coordinator.get_node_or_null("DistrictSupplyActionPort") as DistrictSupplyActionPort
	_expect(ai != null, "production composition contains AiRuntimeController")
	_expect(port != null, "production composition contains DistrictSupplyActionPort")
	_expect(
		coordinator.find_children("DistrictSupplyActionPort", "DistrictSupplyActionPort", true, false).size() == 1,
		"production composition has exactly one district purchase action port"
	)

	var ai_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_runtime_controller.gd")
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	var port_source := FileAccess.get_file_as_string("res://scripts/runtime/district_supply_action_port.gd")
	for retired in [
		"AiV06EconomyActionPort",
		"ai_v06_economy_action_port",
		"set_v06_economy_action_port",
		"execute_v06_facility_bootstrap_cycle",
		"_ai_v06_facility_bootstrap_candidate",
		"_ai_execute_v06_facility_bootstrap_for_player",
		"ai_v06_facility_bootstrap_public_snapshot",
		"v06_facility_market_snapshot",
		"purchase_v06_facility_card",
		"execute_v06_facility_purchase_action",
	]:
		_expect(
			not ai_source.contains(retired) and not coordinator_source.contains(retired),
			"retired facility side-market symbol is absent: %s" % retired
		)
	_expect(
		not FileAccess.file_exists("res://scripts/runtime/ai_v06_economy_action_port.gd"),
		"retired AI facility side-market port remains physically deleted"
	)
	_expect(ai != null and ai.has_method("_ai_card_buy_candidates"), "AI keeps one ordinary public-rack candidate builder")
	_expect(
		ai_source.contains("func _buy_card_for_player_from_district(")
			and ai_source.contains("_district_supply_action_port.submit_ai_purchase"),
		"AI facility-card purchases share the typed district-supply command port"
	)
	_expect(
		ai_source.contains("func _ai_card_buy_candidates(")
			and ai_source.contains("_district_supply_card_ids(district_index)")
			and ai_source.contains("_market_listing_purchasable(district_index)"),
		"AI candidates come from the same public regional rack as human purchases"
	)
	_expect(
		port_source.contains("func submit_ai_purchase(")
			and port_source.contains("current_runtime_simulation_step_index")
			and port_source.contains("_remember_request(normalized_request_id, fingerprint)"),
		"typed AI purchases use stable simulation-step identity and exact-once journaling"
	)
	_expect(
		port_source.contains("purchase_region_supply_card")
			and port_source.contains("CommodityCardInventoryRuntimeController")
			and not port_source.contains("refresh_v06_facility_quote"),
		"facility cards use the authoritative rack and inventory owners without a side market"
	)
	if port != null:
		for request_index in range(24):
			port.call("_remember_request", "facility-retirement-%d" % request_index, "fingerprint-%d" % request_index)
		var debug := port.debug_snapshot()
		_expect(int(debug.get("journal_limit", -1)) == 14, "typed purchase journal retains its bounded contract")
		_expect(int(debug.get("journal_size", -1)) <= 14, "typed purchase journal stays bounded")
		_expect(not bool(debug.get("owns_region_supply", true)), "command port does not own the public rack")
		_expect(not bool(debug.get("owns_inventory", true)), "command port does not own inventory")
		_expect(not bool(debug.get("owns_cash", true)), "command port does not own cash")
		_expect(not bool(debug.get("references_main", true)), "command port has no Main fallback")
	coordinator.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("AI V0.6 FACILITY BOOTSTRAP RETIREMENT TEST PASS: %d checks" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("AI V0.6 FACILITY BOOTSTRAP RETIREMENT TEST FAIL: %s" % failure)
	print("AI V0.6 FACILITY BOOTSTRAP RETIREMENT TEST FAIL: %d/%d" % [_failures.size(), _checks])
	quit(1)