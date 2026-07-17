extends SceneTree

var failures: Array[String] = []


func _init() -> void: call_deferred("_run")


func _run() -> void:
	var port := (load("res://scenes/runtime/ApplicationFlowPort.tscn") as PackedScene).instantiate() as ApplicationFlowPort
	root.add_child(port)
	var counts := {"dedicated": 0, "generic": 0}
	port.economy_requested.connect(func(): counts["dedicated"] = int(counts["dedicated"]) + 1)
	port.action_requested.connect(func(_id): counts["generic"] = int(counts["generic"]) + 1)
	_expect(port.submit_action("economy"), "economy intent accepted")
	_expect(int(counts["dedicated"]) == 1 and int(counts["generic"]) == 0, "economy emits dedicated signal exactly once")
	var query := (load("res://scenes/runtime/EconomyDashboardViewerQueryPort.tscn") as PackedScene).instantiate() as EconomyDashboardViewerQueryPort
	var controller := (load("res://scenes/runtime/EconomyApplicationFlowController.tscn") as PackedScene).instantiate() as EconomyApplicationFlowController
	_expect(query != null and controller != null, "query port and flow controller instantiate independently")
	var own_receipts := query._own_receipts([{"commodity_owner": 0, "commodity_id": "life", "owner_net_cash": 12}, {"commodity_owner": 1, "commodity_id": "energy", "owner_net_cash": 987654}], 0)
	var own_warehouses := query._own_warehouses([{"owner_player_index": 0, "commodity_id": "life", "quantity_milliunits": 10}, {"owner_player_index": 1, "commodity_id": "energy", "quantity_milliunits": 987654}], 0)
	_expect(own_receipts.size() == 1 and not JSON.stringify(own_receipts).contains("987654"), "opponent receipts are excluded, not merely relabeled")
	_expect(own_warehouses.size() == 1 and not JSON.stringify(own_warehouses).contains("987654"), "opponent warehouse inventory is excluded")
	var query_source := FileAccess.get_file_as_string("res://scripts/runtime/economy_dashboard_viewer_query_port.gd")
	_expect(not query_source.contains("ensure_catalog") and not query_source.contains("refresh_routes(") and not query_source.contains("current_scene") and not query_source.contains("/root/" + "Main"), "query is cached-only and has no Main fallback")
	var main_source := FileAccess.get_file_as_string("res://scripts/" + "main.gd")
	for retired in ["func _open_economy_overview_menu", "func _populate_economy_overview_summary_cards", "func _add_economy_dashboard_panel", "func _economy_dashboard_public_source_snapshot", "func _economy_dashboard_public_snapshot", "EconomyDashboardScene"]:
		_expect(not main_source.contains(retired), "Main economy symbol removed: %s" % retired)
	var scene_source := FileAccess.get_file_as_string("res://scenes/main.tscn")
	_expect(scene_source.count("signal=\"economy_requested\"") == 1, "production scene has one economy connection")
	_expect(scene_source.contains("EconomyDashboardViewerQueryPort") and scene_source.contains("EconomyApplicationFlowController"), "production composition is explicit")
	var service_source := FileAccess.get_file_as_string("res://scripts/runtime/economy_dashboard_public_snapshot_service.gd")
	for retired_text in ["合约签拒", "修商路", "城市业主", "player_cash_entries"]:
		_expect(not service_source.contains(retired_text), "retired contract/text absent: %s" % retired_text)
	_expect(int(counts["generic"]) == 0 and int(port.debug_snapshot().get("economy_emission_count", 0)) == 1, "debug counters preserve exact once")
	port.queue_free()
	query.free()
	controller.free()
	await process_frame
	_finish()


func _expect(value: bool, message: String) -> void:
	if not value: failures.append(message); push_error("ECONOMY FLOW: %s" % message)


func _finish() -> void:
	print("ECONOMY APPLICATION FLOW CUTOVER %s" % ("PASS" if failures.is_empty() else "FAIL: %d" % failures.size()))
	quit(0 if failures.is_empty() else 1)
