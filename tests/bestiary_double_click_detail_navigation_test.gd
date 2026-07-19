extends SceneTree

const SESSION_START_DRIVER := preload("res://tests/support/production_session_start_driver.gd")
const QA_SAVE_PATH := "user://test_runs/bestiary_double_click_detail_navigation.save"
const COORDINATOR_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator"
const MENU_OVERLAY_PATH := "RuntimeGameScreen/OverlayLayer/RuntimeSurfaceLayer/MenuModalOverlay"
const FLOW_PATH := "RuntimeServices/CompendiumApplicationFlowController"
const APP_PORT_PATH := "RuntimeServices/ApplicationFlowPort"
const NAV_OWNER_PATH := COORDINATOR_PATH + "/CodexNavigationRuntimeController"

var _checks := 0
var _failures: Array[String] = []
var _runtime_root: Node
var _coordinator: Node
var _overlay: Control
var _surface: Control
var _flow: Node
var _app_port: Node
var _navigation: Node
var _game_session: GameSessionRuntimeController
var _preview_signal_count := 0
var _detail_signal_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_qa_save()
	var start_result := await SESSION_START_DRIVER.start_default_session(self, QA_SAVE_PATH, "bestiary-double-click-detail")
	_runtime_root = start_result.get("main_root") as Node
	_game_session = start_result.get("game_session") as GameSessionRuntimeController
	_assert_formal_session_start(start_result, 4)
	if _runtime_root == null or not bool(start_result.get("started", false)):
		await _cleanup()
		_finish()
		return
	_bind_nodes()
	if _dependencies_ready():
		await _exercise_real_thumbnail_path()
	await _cleanup()
	_finish()


func _bind_nodes() -> void:
	_coordinator = _runtime_root.get_node_or_null(COORDINATOR_PATH)
	_overlay = _runtime_root.get_node_or_null(MENU_OVERLAY_PATH) as Control
	_surface = _overlay.call("get_codex_surface") as Control if _overlay != null and _overlay.has_method("get_codex_surface") else null
	_flow = _runtime_root.get_node_or_null(FLOW_PATH)
	_app_port = _runtime_root.get_node_or_null(APP_PORT_PATH)
	_navigation = _runtime_root.get_node_or_null(NAV_OWNER_PATH)


func _dependencies_ready() -> bool:
	var ready := _coordinator != null and _overlay != null and _surface != null and _flow != null and _app_port != null and _navigation != null
	_expect(ready, "real_scene_composes_bestiary_navigation_dependencies")
	return ready


func _exercise_real_thumbnail_path() -> void:
	_game_session.pause_session()
	await _settle(1)
	_expect(str(_game_session.session_summary().get("session_state", "")) == "paused", "formal_game_session_is_paused_before_bestiary_open")
	_expect(bool(_app_port.call("submit_action", "compendium")), "compendium_opens_through_dedicated_application_port")
	await _settle(2)
	_surface.emit_signal("action_requested", "hub_action", {"action_id": "monster"})
	await _settle(2)
	_expect(_surface_mode_is("monster", "browser"), "real_monster_browser_opens")
	var browser := _surface.get_node_or_null("%BestiaryCodexBrowser") as Control
	var grid := browser.get("thumbnail_grid") as GridContainer if browser != null else null
	_expect(browser != null and grid != null and grid.get_child_count() >= 2, "real_bestiary_grid_has_multiple_thumbnails|browser=%s|grid=%s|children=%d|debug=%s" % [browser != null, grid != null, grid.get_child_count() if grid != null else -1, browser.call("debug_snapshot") if browser != null else {}])
	if browser == null or grid == null or grid.get_child_count() < 2:
		return

	var gameplay_before := _capture_gameplay_state()
	var browser_id := browser.get_instance_id()
	var child_count := grid.get_child_count()
	var first := grid.get_child(0) as Control
	var first_id := first.get_instance_id()
	var first_index := _thumbnail_index(first)
	_connect_probe(first)
	var first_preview_connections := first.get_signal_connection_list("preview_requested").size()
	var first_detail_connections := first.get_signal_connection_list("detail_requested").size()
	var browser_preview_connections := browser.get_signal_connection_list("entry_preview_requested").size()
	var before := _interaction_counters(browser)

	_emit_left_press(first, false)
	await _settle(2)
	var after_single := _interaction_counters(browser)
	_expect(_preview_signal_count == 1 and _detail_signal_count == 0, "single_click_emits_preview_once_and_no_detail")
	_expect(_surface_mode_is("monster", "browser"), "single_click_keeps_monster_browser_visible")
	_expect(browser.get_instance_id() == browser_id and grid.get_child_count() == child_count, "single_click_keeps_browser_and_grid_child_count")
	_expect(is_instance_valid(first) and first.get_instance_id() == first_id and not first.is_queued_for_deletion(), "single_click_preserves_first_thumbnail_node_identity")
	_expect(is_instance_valid(first) and first.get_signal_connection_list("preview_requested").size() == first_preview_connections and first.get_signal_connection_list("detail_requested").size() == first_detail_connections, "single_click_preserves_thumbnail_signal_connections")
	_expect(browser.get_signal_connection_list("entry_preview_requested").size() == browser_preview_connections, "single_click_preserves_browser_signal_connections")
	_expect(int(after_single.get("full_rebuild", 0)) == int(before.get("full_rebuild", 0)), "single_preview_performs_zero_full_grid_rebuilds")
	_expect(int(after_single.get("browser_preview_apply", 0)) == int(before.get("browser_preview_apply", 0)) + 1, "single_preview_applies_browser_preview_once")
	_expect(int(after_single.get("surface_preview_apply", 0)) == int(before.get("surface_preview_apply", 0)) + 1, "single_preview_applies_surface_preview_once")
	_expect(int(after_single.get("flow_preview_apply", 0)) == int(before.get("flow_preview_apply", 0)) + 1, "single_preview_applies_flow_preview_once")
	_expect(int(after_single.get("flow_page_apply", 0)) == int(before.get("flow_page_apply", 0)), "single_preview_applies_zero_full_pages")
	_expect(_selected_index(browser) == first_index, "single_preview_selects_actual_thumbnail")

	if not is_instance_valid(first):
		first = grid.get_child(0) as Control
		_connect_probe(first)
	_emit_left_press(first, true)
	await _settle(2)
	var after_double := _interaction_counters(browser)
	_expect(_preview_signal_count == 1 and _detail_signal_count == 1, "double_second_press_emits_detail_once_without_preview_increment")
	_expect(_surface_mode_is("monster", "detail"), "double_second_press_opens_monster_detail")
	_expect(int(after_double.get("flow_page_apply", 0)) == int(after_single.get("flow_page_apply", 0)) + 1, "monster_detail_applies_one_full_page")
	_expect(int(after_double.get("flow_duplicate", 0)) == int(after_single.get("flow_duplicate", 0)), "double_click_has_zero_duplicate_page_apply")

	var link_button := _surface.get("monster_card_link_button") as Button
	_expect(link_button != null and link_button.visible and not link_button.disabled, "monster_detail_exposes_public_card_link")
	var linked_card := ""
	if link_button != null:
		linked_card = link_button.text
		var deep_before := _interaction_counters(browser)
		link_button.pressed.emit()
		await _settle(2)
		var deep_after := _interaction_counters(browser)
		var nav := _navigation.call("navigation_snapshot") as Dictionary
		_expect(_surface_mode_is("card", "detail"), "monster_card_link_opens_card_detail")
		_expect(str(nav.get("stable_item_id", "")) != "" and str(nav.get("stable_item_id", "")) != "catalog", "monster_card_link_selects_concrete_public_card_id")
		_expect(int(deep_after.get("surface_deep_link", 0)) == int(deep_before.get("surface_deep_link", 0)) + 1, "monster_card_link_emits_once")
		_expect(int(deep_after.get("flow_page_apply", 0)) == int(deep_before.get("flow_page_apply", 0)) + 1, "monster_card_link_applies_one_card_detail_page")
		_expect(int(deep_after.get("flow_duplicate", 0)) == int(deep_before.get("flow_duplicate", 0)), "monster_card_link_has_zero_duplicate_apply")
		_expect(linked_card != "", "monster_card_link_has_visible_player_facing_label")

	_overlay.emit_signal("catalog_back_requested")
	await _settle(2)
	_expect(_surface_mode_is("monster", "detail"), "card_detail_back_restores_monster_detail")
	_overlay.emit_signal("catalog_back_requested")
	await _settle(2)
	_expect(_surface_mode_is("monster", "browser"), "monster_detail_back_restores_monster_browser")
	browser = _surface.get_node_or_null("%BestiaryCodexBrowser") as Control
	grid = browser.get("thumbnail_grid") as GridContainer if browser != null else null
	_expect(browser != null and grid != null and grid.get_child_count() >= 2, "returned_monster_browser_grid_is_available")
	if browser == null or grid == null or grid.get_child_count() < 2:
		return
	_expect(_selected_index(browser) == first_index, "return_to_browser_preserves_selected_monster")
	var second := grid.get_child(1) as Control
	var second_index := _thumbnail_index(second)
	var internal_preview_connections := second.get_signal_connection_list("preview_requested").size()
	var internal_detail_connections := second.get_signal_connection_list("detail_requested").size()
	_expect(internal_preview_connections == 1 and internal_detail_connections == 1, "returned_thumbnail_has_no_duplicate_internal_connections")
	_reset_probe_counts()
	_connect_probe(second)
	var slow_before := _interaction_counters(browser)
	_emit_left_press(second, false)
	await _settle(1)
	if not is_instance_valid(second):
		second = grid.get_child(1) as Control
		_connect_probe(second)
	_emit_left_press(second, false)
	await _settle(2)
	var slow_after := _interaction_counters(browser)
	_expect(_preview_signal_count == 2 and _detail_signal_count == 0, "slow_two_singles_emit_two_previews_and_no_detail")
	_expect(_selected_index(browser) == second_index, "different_thumbnail_selects_only_actual_target")
	_expect(int(slow_after.get("full_rebuild", 0)) == int(slow_before.get("full_rebuild", 0)), "slow_single_previews_do_not_rebuild_grid")

	_reset_probe_counts()
	var current_second := grid.get_child(1) as Control
	_connect_probe(current_second)
	var rapid_before := _interaction_counters(browser)
	_emit_left_press(current_second, true)
	await _settle(2)
	var rapid_after := _interaction_counters(browser)
	_expect(_preview_signal_count == 0 and _detail_signal_count == 1, "rapid_double_event_emits_detail_once_and_preview_zero")
	_expect(_surface_mode_is("monster", "detail"), "rapid_double_event_opens_detail")
	_expect(int(rapid_after.get("flow_page_apply", 0)) == int(rapid_before.get("flow_page_apply", 0)) + 1, "rapid_double_applies_detail_once")

	var gameplay_after := _capture_gameplay_state()
	_expect(gameplay_after == gameplay_before, "bestiary_preview_detail_and_deep_link_have_zero_gameplay_session_rng_market_route_selection_log_save_mutation")
	_expect(_visible_ui_is_private_safe(), "visible_bestiary_and_card_ui_exposes_no_private_or_machine_tokens")
	_expect(_main_route_count() == 0, "bestiary_navigation_has_zero_main_route")


func _assert_formal_session_start(start_result: Dictionary, expected_players: int) -> void:
	_expect(bool(start_result.get("qa_save_override_ready", false)), "driver_installs_qa_save_override_before_tree_entry")
	_expect(bool(start_result.get("started", false)), "formal_session_start_succeeds|reason=%s" % start_result.get("reason_code", ""))
	var receipt := start_result.get("receipt") as SessionStartReceipt
	_expect(receipt != null and receipt.applied, "formal_session_receipt_is_applied")
	_expect(int(start_result.get("main_start_call_count", -1)) == 0, "formal_fixture_calls_no_Main_start_method")
	_expect(int(start_result.get("setup_fallback_count", -1)) == 0, "formal_fixture_uses_no_setup_fallback")
	var world := start_result.get("world_session") as WorldSessionState
	_expect(world != null and world.players.size() == expected_players, "formal_world_has_expected_player_count")
	var operation: Dictionary = start_result.get("transaction_snapshot", {})
	_expect(str(operation.get("operation_state", "")) == "succeeded" and int(operation.get("terminal_request_count", 0)) == 1 and not bool(operation.get("references_main", true)), "formal_session_transaction_commits_exactly_once_without_Main")
	_expect(_game_session != null and str(_game_session.session_summary().get("session_state", "")) == "running", "formal_game_session_is_running")


func _interaction_counters(browser: Control) -> Dictionary:
	var browser_debug := browser.call("debug_snapshot") as Dictionary
	var surface_debug := _surface.call("debug_snapshot") as Dictionary
	var flow_debug := _flow.call("debug_snapshot") as Dictionary
	return {
		"full_rebuild": int(browser_debug.get("full_rebuild_count", 0)),
		"browser_preview_apply": int(browser_debug.get("preview_apply_count", 0)),
		"surface_preview_apply": int(surface_debug.get("monster_preview_apply_count", 0)),
		"surface_deep_link": int(surface_debug.get("monster_card_deep_link_count", 0)),
		"flow_preview_apply": int(flow_debug.get("monster_preview_apply_count", 0)),
		"flow_page_apply": int(flow_debug.get("page_apply_count", 0)),
		"flow_duplicate": int(flow_debug.get("duplicate_apply_count", 0)),
	}


func _capture_gameplay_state() -> Dictionary:
	var owners := {}
	for node_name in [
		"ProductMarketRuntimeController", "CommodityFlowRuntimeController", "RouteNetworkRuntimeController",
		"RegionInfrastructureRuntimeController", "WeatherRuntimeController", "MonsterRuntimeController",
		"VictoryControlRuntimeController", "GameSessionRuntimeController", "RuntimeCommandPipeline",
	]:
		var node := _coordinator.get_node_or_null(node_name)
		if node == null:
			owners[node_name] = {"missing": true}
		elif node.has_method("to_save_data"):
			owners[node_name] = (node.call("to_save_data") as Dictionary).duplicate(true)
		elif node.has_method("debug_snapshot"):
			owners[node_name] = (node.call("debug_snapshot") as Dictionary).duplicate(true)
	var session: WorldSessionState = _coordinator.call("world_session_state") as WorldSessionState
	var selection: TableSelectionState = _coordinator.call("table_selection_state") as TableSelectionState
	var rng: RunRngService = _coordinator.call("run_rng_service") as RunRngService
	var save := _coordinator.get_node_or_null("GameSessionRuntimeController/GameSaveRuntimeCoordinator")
	return {
		"world_session": session.call("internal_snapshot") if session != null else {},
		"world_clock": _coordinator.call("world_effective_clock_snapshot"),
		"selection": selection.call("snapshot") if selection != null else {},
		"rng_state": int(rng.get("state")) if rng != null else -1,
		"public_log": _coordinator.call("presentation_recent_public_log_entries", 256),
		"save": save.call("debug_snapshot") if save != null else {},
		"owners": owners,
	}


func _connect_probe(card: Control) -> void:
	var preview_callable := Callable(self, "_on_preview_probe")
	var detail_callable := Callable(self, "_on_detail_probe")
	if not card.is_connected("preview_requested", preview_callable):
		card.connect("preview_requested", preview_callable)
	if not card.is_connected("detail_requested", detail_callable):
		card.connect("detail_requested", detail_callable)


func _on_preview_probe(_catalog_index: int) -> void:
	_preview_signal_count += 1


func _on_detail_probe(_catalog_index: int) -> void:
	_detail_signal_count += 1


func _reset_probe_counts() -> void:
	_preview_signal_count = 0
	_detail_signal_count = 0


func _emit_left_press(card: Control, double_click: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.double_click = double_click
	card.emit_signal("gui_input", event)


func _thumbnail_index(card: Control) -> int:
	return int(card.get("_catalog_index"))


func _selected_index(browser: Control) -> int:
	return int((browser.call("debug_snapshot") as Dictionary).get("selected_index", -1))


func _surface_mode_is(mode: String, view: String) -> bool:
	var snapshot := _surface.call("debug_snapshot") as Dictionary
	return str(snapshot.get("mode", "")) == mode and str(snapshot.get("view", "")) == view


func _visible_ui_is_private_safe() -> bool:
	var forbidden := ["hidden_owner", "owner_actor_id", "private_hand", "private_cash", "ai_score", "/root/" + "Main", "res://"]
	for node in _surface.find_children("*", "Label", true, false) + _surface.find_children("*", "Button", true, false):
		if not (node is Control) or not (node as Control).is_visible_in_tree():
			continue
		var text := str(node.get("text"))
		var tooltip := str((node as Control).tooltip_text)
		for token in forbidden:
			if text.contains(token) or tooltip.contains(token):
				return false
	return true


func _main_route_count() -> int:
	var source := FileAccess.get_file_as_string("res://scripts/" + "main.gd")
	var count := 0
	var retired_negative_scan_methods := ["_open_bestiary_menu", "_update_bestiary_menu", "_on_codex_surface_action_requested", "_present_codex_page"]
	for method_name in retired_negative_scan_methods:
		if source.contains("func %s(" % method_name):
			count += 1
	return count


func _settle(frame_count: int) -> void:
	for _index in range(maxi(1, frame_count)):
		await process_frame


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(label)
	push_error("BESTIARY DOUBLE CLICK: %s" % label)


func _cleanup() -> void:
	if _runtime_root != null:
		_runtime_root.queue_free()
		_runtime_root = null
	_game_session = null
	await process_frame
	await process_frame
	_cleanup_qa_save()


func _cleanup_qa_save() -> void:
	for path in [QA_SAVE_PATH, QA_SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _finish() -> void:
	if _failures.is_empty():
		print("BESTIARY_DOUBLE_CLICK_DETAIL_NAVIGATION_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	print("BESTIARY_DOUBLE_CLICK_DETAIL_NAVIGATION_TEST|status=FAIL|checks=%d|failures=%d|labels=%s" % [_checks, _failures.size(), _failures])
	quit(1)
