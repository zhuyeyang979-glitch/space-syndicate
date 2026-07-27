extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const MAIN_SOURCE := "res://scripts/" + "main.gd"
const QUERY_SCENE := "res://scenes/runtime/StandingsPublicQueryPort.tscn"
const CONTROLLER_SCENE := "res://scenes/runtime/StandingsApplicationFlowController.tscn"
const SERVICE_SCENE := "res://scenes/runtime/StandingsPublicSnapshotService.tscn"
const MENU_SCENE := "res://scenes/ui/MenuOverlay.tscn"

class FakeVictoryController extends VictoryControlRuntimeController:
	var public_value := {
		"state": "audit",
		"audit_remaining_seconds": 42.0,
		"victory_rule": {"required_top_k_gdp_per_minute": 130, "required_region_count": 4},
		"audit_roster": [],
		"audit_entries": [],
		"outcome_receipt": {},
		"visibility_scope": "public",
	}
	var private_value := {
		"viewer_player_index": 0,
		"own_candidate": {"top_k_gdp_per_minute": 145, "top_n_gdp_per_minute": 145, "controlled_region_count": 4, "eligible": true},
		"visibility_scope": "viewer_private",
	}

	func public_snapshot(_viewer_index := -1) -> Dictionary:
		return public_value.duplicate(true)

	func private_snapshot(_viewer_index: int) -> Dictionary:
		return private_value.duplicate(true)

	func timer_duration(timer_id: String) -> float:
		return 10.0 if timer_id == "victory_qualification" else (120.0 if timer_id == "public_audit" else 0.0)


var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node.new()
	root.add_child(host)
	var world := WorldSessionState.new()
	world.name = "WorldSessionState"
	world.players = [
		{"id": "human", "name": "本地玩家", "is_ai": false, "cash": 610, "cash_cents": 61000, "slots": []},
		{"id": "rival", "name": "电脑对手", "is_ai": true, "cash": 987654321, "cash_cents": 98765432100, "slots": [{"name": "秘密牌"}]},
	]
	host.add_child(world)
	var authorization := LocalViewerAuthorization.new()
	authorization.configure(world)
	var world_query := WorldSessionPresentationQuery.new()
	world_query.configure(world, authorization)
	var public_log := PublicLogPresentationOwner.new()
	var table_queries := TablePresentationQueryPorts.new()
	table_queries.name = "TablePresentationQueryPorts"
	table_queries.add_child(authorization)
	table_queries.add_child(world_query)
	table_queries.add_child(public_log)
	table_queries.local_viewer_authorization = authorization
	table_queries.world_session_query = world_query
	table_queries.public_log_owner = public_log
	host.add_child(table_queries)
	var victory := FakeVictoryController.new()
	victory.name = "VictoryControlRuntimeController"
	host.add_child(victory)
	var service := (load(SERVICE_SCENE) as PackedScene).instantiate() as StandingsPublicSnapshotService
	service.name = "StandingsPublicSnapshotService"
	host.add_child(service)
	service.configure({})
	var query := (load(QUERY_SCENE) as PackedScene).instantiate() as StandingsPublicQueryPort
	query.name = "StandingsPublicQueryPort"
	query.table_query_ports_path = NodePath("../TablePresentationQueryPorts")
	query.victory_controller_path = NodePath("../VictoryControlRuntimeController")
	query.snapshot_service_path = NodePath("../StandingsPublicSnapshotService")
	host.add_child(query)

	var before_world := JSON.stringify(world.players)
	var snapshot := query.snapshot_for_authorized_viewer(960.0)
	var progress := query.victory_progress_for_authorized_viewer()
	var after_world := JSON.stringify(world.players)
	_check(before_world == after_world, "opening standings does not mutate world state")
	_check(str(snapshot.get("summary_text", "")).contains("局势排名"), "authorized viewer receives a standings snapshot")
	_check(JSON.stringify(snapshot).contains("本地玩家") and not JSON.stringify(snapshot).contains("987654321") and not JSON.stringify(snapshot).contains("秘密牌"), "opponent cash and hand stay private")
	var seats := ((snapshot.get("scoreboard", {}) as Dictionary).get("seats", []) as Array)
	_check(seats.size() == 2 and str((seats[0] as Dictionary).get("score", "")) == "Top-N 145" and str((seats[1] as Dictionary).get("score", "")) == "进度隐藏", "only the authorized local viewer receives private progress")
	_check(bool(progress.get("valid", false)) and int(progress.get("schema_version", 0)) == 1 and str(progress.get("visibility_scope", "")) == "viewer_private", "typed victory progress requires the same authorized local viewer")
	_check(int(progress.get("selected_top_k_gdp_per_minute", -1)) == 145 and int(progress.get("required_top_k_gdp_per_minute", -1)) == 130 and int(progress.get("selected_controlled_region_count", -1)) == 4 and int(progress.get("required_controlled_region_count", -1)) == 4 and bool(progress.get("eligible", false)), "typed victory progress preserves authoritative numeric facts without presentation parsing")
	_check(is_equal_approx(float(progress.get("qualification_duration_seconds", 0.0)), 10.0) and is_equal_approx(float(progress.get("audit_duration_seconds", 0.0)), 120.0), "typed progress projects timer durations from the authoritative Victory clock registry")
	victory.private_value["viewer_player_index"] = 1
	_check(str(query.victory_progress_for_authorized_viewer().get("reason_id", "")) == "victory_progress_subject_mismatch", "typed victory progress rejects a cross-subject private snapshot")
	victory.private_value["viewer_player_index"] = 0
	_check(not JSON.stringify(progress).contains("987654321") and not JSON.stringify(progress).contains("秘密牌") and not progress.has("cash") and not progress.has("players"), "typed victory progress contains no rival cash, hand, or world payload")
	progress["selected_top_k_gdp_per_minute"] = 999999
	_check(int(query.victory_progress_for_authorized_viewer().get("selected_top_k_gdp_per_minute", -1)) == 145, "typed victory progress is a detached read and cannot mutate the Victory owner")
	var query_debug := query.debug_snapshot()
	_check(int(query_debug.get("progress_query_count", 0)) == 2 and bool(query_debug.get("provides_viewer_authorized_progress", false)) and not bool(query_debug.get("refreshes_routes", true)) and not bool(query_debug.get("mutates_world", true)) and not bool(query_debug.get("reveals_all_on_session_finish", true)), "query boundary is read-only, counts accepted typed progress reads, and never enables finish-time full disclosure")

	var flow := ApplicationFlowPort.new()
	host.add_child(flow)
	var generic_actions: Array[StringName] = []
	var standings_counter := [0]
	flow.action_requested.connect(func(action_id: StringName) -> void: generic_actions.append(action_id))
	flow.standings_requested.connect(func() -> void: standings_counter[0] = int(standings_counter[0]) + 1)
	_check(flow.submit_action("standings") and int(standings_counter[0]) == 1 and generic_actions.is_empty(), "standings uses its dedicated exact-once signal")
	var flow_debug := flow.debug_snapshot()
	_check(bool(flow_debug.get("standings_uses_dedicated_signal", false)) and not bool(flow_debug.get("standings_uses_generic_action_signal", true)), "flow debug exposes the dedicated boundary")

	var overlay := (load(MENU_SCENE) as PackedScene).instantiate() as SpaceSyndicateMenuOverlay
	overlay.name = "MenuOverlay"
	host.add_child(overlay)
	var controller := (load(CONTROLLER_SCENE) as PackedScene).instantiate() as StandingsApplicationFlowController
	controller.name = "StandingsApplicationFlowController"
	controller.menu_overlay_path = NodePath("../MenuOverlay")
	controller.query_port_path = NodePath("../StandingsPublicQueryPort")
	host.add_child(controller)
	await process_frame
	_check(controller.open_standings(), "scene-owned controller opens standings")
	await process_frame
	_check(overlay.visible and overlay.get_preview_host().find_child("StandingsPlayerScoreGrid", true, false) != null, "controller mounts the real standings scoreboard")

	var main_scene_source := FileAccess.get_file_as_string(MAIN_SCENE)
	var main_source := FileAccess.get_file_as_string(MAIN_SOURCE)
	_check(main_scene_source.contains("StandingsPublicQueryPort.tscn") and main_scene_source.contains("StandingsApplicationFlowController.tscn") and main_scene_source.contains('signal="standings_requested"'), "formal main scene explicitly composes and connects the standings flow")
	for retired in ["func _open_standings_menu(", "func _populate_standings_summary_cards(", "func _add_standings_scoreboard_panel(", "func _standings_public_source_snapshot(", "func _standings_public_snapshot(", "StandingsScoreboardScene"]:
		_check(not main_source.contains(retired), "Main retired standings symbol is absent: %s" % retired)
	var query_source := FileAccess.get_file_as_string("res://scripts/runtime/standings_public_query_port.gd")
	_check(not query_source.contains("_refresh_route_network") and not query_source.contains("TableSelectionState") and not query_source.contains("/root/" + "Main") and not query_source.contains("current_scene"), "query port has no route mutation, selection-state authorization, Main, or current-scene fallback")
	_check(not query_source.contains("func victory_progress_for_authorized_viewer() -> Dictionary:\n\tvar query_ports := _table_query_ports()\n\tvar victory := _victory_controller()\n\tif query_ports == null or victory == null:\n\t\treturn _rejected_progress(\"progress_dependency_unavailable\")\n\tvar context := query_ports.viewer_context()\n\tvar public_world"), "typed progress authorization does not deep-copy the public world")

	host.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("standings_application_flow_cutover_test: PASS %d/%d" % [_checks, _checks])
		quit(0)
	else:
		printerr("standings_application_flow_cutover_test: FAIL %d/%d\n%s" % [_failures.size(), _checks, "\n".join(_failures)])
		quit(1)
