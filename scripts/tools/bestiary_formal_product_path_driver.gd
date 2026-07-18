extends Control

const MAIN_SCENE := preload("res://scenes/main.tscn")
const COORDINATOR_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator"
const OVERLAY_PATH := "RuntimeGameScreen/OverlayLayer/RuntimeSurfaceLayer/MenuModalOverlay"
const APP_PORT_PATH := "RuntimeServices/ApplicationFlowPort"
const FLOW_PATH := "RuntimeServices/CompendiumApplicationFlowController"
const NAV_PORT_PATH := "RuntimeServices/CompendiumNavigationPort"
const NAV_OWNER_PATH := COORDINATOR_PATH + "/CodexNavigationRuntimeController"
const CARD_SOURCE_PATH := COORDINATOR_PATH + "/CardCodexPublicSourceService"
const MONSTER_SOURCE_PATH := COORDINATOR_PATH + "/MonsterCodexPublicSourceService"
const SAVE_PATH := COORDINATOR_PATH + "/GameSessionRuntimeController/GameSaveRuntimeCoordinator"
const SCREENSHOT_DIR := "res://docs/ui_qa/compendium"
const RESULT_PATH := SCREENSHOT_DIR + "/bestiary_formal_product_path_result.json"
const STAGE_TIMEOUT_MSEC := 8000

var _checks := 0
var _failures: Array[String] = []
var _stage_started_msec := 0
var _run_started_msec := 0
var _scenario_deadline_msec := 0
var _timings: Dictionary = {}
var _metrics: Dictionary = {}
var _expected_card_id := ""
var _actual_card_id := ""


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_run_started_msec = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCREENSHOT_DIR))
	var scenario_a_ok := await _run_scenario_a()
	var scenario_b_ok := false
	if scenario_a_ok:
		scenario_b_ok = await _run_scenario_b()
	_metrics["formal_scenario_a"] = "PASS" if scenario_a_ok else "FAIL"
	_metrics["formal_scenario_b"] = "PASS" if scenario_b_ok else "FAIL"
	_metrics["total_formal_qa_seconds"] = _elapsed_seconds(_run_started_msec)
	_write_result()
	_finish()


func _run_scenario_a() -> bool:
	var session_started := Time.get_ticks_msec()
	_scenario_deadline_msec = session_started + 75000
	var main := await _spawn_four_player_session("scenario_a")
	if main == null:
		return false
	_timings["session_start_seconds"] = _elapsed_seconds(session_started)
	var nodes := _runtime_nodes(main)
	if not _runtime_nodes_ready(nodes):
		_fail("scenario_a_runtime_dependencies_missing")
		await _dispose_main(main)
		return false
	await _press_escape(main)
	if not await _wait_stage("menu_paused", func() -> bool: return bool((nodes.overlay as Control).visible)):
		await _dispose_main(main)
		return false
	var hub_started := Time.get_ticks_msec()
	if not bool(nodes.app_port.call("submit_action", "compendium")):
		_fail("formal_compendium_application_intent_rejected")
		await _dispose_main(main)
		return false
	if not await _wait_stage("hub_visible", func() -> bool: return _surface_mode(nodes.surface, "compendium", "hub")):
		await _dispose_main(main)
		return false
	var monster_button := _button_with_text(nodes.surface.get("compendium_hub") as Control, "怪兽生态档案")
	if monster_button == null or not await _click_control(monster_button):
		_fail("formal_monster_hub_button_unavailable")
		await _dispose_main(main)
		return false
	if not await _wait_stage("monster_browser_visible", func() -> bool: return _surface_mode(nodes.surface, "monster", "browser") and _thumbnail_count(nodes.surface) >= 2):
		await _dispose_main(main)
		return false
	_timings["monster_browser_seconds"] = _elapsed_seconds(hub_started)
	await _settle_frames(2)
	var gameplay_before := _capture_gameplay_state(nodes.coordinator)
	var browser := nodes.surface.get_node_or_null("%BestiaryCodexBrowser") as Control
	var grid := browser.get("thumbnail_grid") as GridContainer if browser != null else null
	if browser == null or grid == null or grid.get_child_count() < 2:
		_fail("formal_bestiary_grid_missing")
		await _dispose_main(main)
		return false
	var first := grid.get_child(0) as Control
	var first_index := int(first.get("_catalog_index"))
	var browser_id := browser.get_instance_id()
	var first_id := first.get_instance_id()
	var child_count := grid.get_child_count()
	var connections_before := _signal_connection_count(first, browser)
	var counters_before := _interaction_counters(nodes, browser)
	var navigation_before := nodes.navigation.call("debug_snapshot") as Dictionary

	var preview_started := Time.get_ticks_msec()
	if not await _click_control(first):
		_fail("formal_first_thumbnail_click_failed")
		await _dispose_main(main)
		return false
	if not await _wait_stage("preview_visible", func() -> bool: return _surface_mode(nodes.surface, "monster", "browser") and _selected_monster(nodes.navigation) == first_index):
		await _dispose_main(main)
		return false
	_timings["monster_preview_seconds"] = _elapsed_seconds(preview_started)
	var counters_after_preview := _interaction_counters(nodes, browser)
	var navigation_after_preview := nodes.navigation.call("debug_snapshot") as Dictionary
	_expect(browser.get_instance_id() == browser_id and grid.get_child_count() == child_count, "preview_keeps_browser_and_grid")
	_expect(is_instance_valid(first) and first.get_instance_id() == first_id and not first.is_queued_for_deletion(), "preview_keeps_thumbnail_instance")
	_expect(_signal_connection_count(first, browser) == connections_before, "preview_keeps_signal_connections")
	_expect(int(counters_after_preview.full_rebuild) == int(counters_before.full_rebuild), "preview_full_page_rebuild_count_zero")
	_expect(int(counters_after_preview.flow_page_apply) == int(counters_before.flow_page_apply), "preview_full_page_apply_count_zero")
	_expect(int(counters_after_preview.preview_request) == int(counters_before.preview_request) + 1, "preview_request_exactly_once|before=%d|after=%d" % [int(counters_before.preview_request), int(counters_after_preview.preview_request)])
	_expect(int(counters_after_preview.detail_request) == int(counters_before.detail_request), "preview_detail_request_zero|before=%d|after=%d" % [int(counters_before.detail_request), int(counters_after_preview.detail_request)])
	_expect(int(navigation_after_preview.history_push_count) == int(navigation_before.history_push_count), "preview_history_push_zero")
	_expect(int(navigation_after_preview.history_pop_count) == int(navigation_before.history_pop_count), "preview_history_pop_zero")
	_expect(str(navigation_after_preview.external_return_target) == str(navigation_before.external_return_target), "preview_external_target_unchanged")
	await _capture("bestiary_formal_browser.png")

	var detail_started := Time.get_ticks_msec()
	if not await _click_control(first, true):
		_fail("formal_first_thumbnail_double_click_failed")
		await _dispose_main(main)
		return false
	if not await _wait_stage("first_monster_detail_visible", func() -> bool: return _surface_mode(nodes.surface, "monster", "detail")):
		await _dispose_main(main)
		return false
	_timings["monster_detail_seconds"] = _elapsed_seconds(detail_started)
	var counters_after_detail := _interaction_counters(nodes, browser)
	_expect(int(counters_after_detail.preview_request) == int(counters_after_preview.preview_request), "double_click_second_preview_zero")
	_expect(int(counters_after_detail.detail_request) == int(counters_after_preview.detail_request) + 1, "double_click_detail_exactly_once")
	_expect(int(counters_after_detail.flow_page_apply) == int(counters_after_preview.flow_page_apply) + 1, "monster_detail_page_apply_exactly_once")
	_expect(int(counters_after_detail.flow_duplicate) == int(counters_after_preview.flow_duplicate), "monster_detail_duplicate_apply_zero")
	await _capture("bestiary_formal_monster_detail.png")

	var monster_snapshot := nodes.monster_source.call("compose_snapshot", first_index, true) as Dictionary
	var link := monster_snapshot.get("monster_card_link", {}) as Dictionary if monster_snapshot.get("monster_card_link", {}) is Dictionary else {}
	var raw_card_reference := str(link.get("card_name", ""))
	_expected_card_id = str(nodes.card_source.call("resolve_card_id", raw_card_reference))
	if _expected_card_id.is_empty():
		_fail("card_id_resolver_rejected|raw=%s" % raw_card_reference)
		await _dispose_main(main)
		return false
	var card_link := nodes.surface.get("monster_card_link_button") as Button
	if card_link == null or not card_link.visible or card_link.disabled:
		_fail("monster_card_link_visible")
		await _dispose_main(main)
		return false
	await _ensure_control_visible(card_link)
	var card_started := Time.get_ticks_msec()
	var deep_before := _interaction_counters(nodes, browser)
	if not await _click_control(card_link):
		_fail("monster_card_link_click_failed")
		await _dispose_main(main)
		return false
	if not await _wait_stage("card_detail_visible", func() -> bool: return _surface_mode(nodes.surface, "card", "detail")):
		await _dispose_main(main)
		return false
	_timings["card_detail_seconds"] = _elapsed_seconds(card_started)
	_actual_card_id = str((nodes.navigation.call("navigation_snapshot") as Dictionary).get("stable_item_id", ""))
	var deep_after := _interaction_counters(nodes, browser)
	_expect(_actual_card_id == _expected_card_id, "monster_card_link_uses_canonical_card_id")
	_expect(int(deep_after.deep_link) == int(deep_before.deep_link) + 1, "monster_card_deep_link_exactly_once")
	_expect(int(deep_after.flow_page_apply) == int(deep_before.flow_page_apply) + 1, "card_detail_page_apply_exactly_once")
	_expect(int(deep_after.flow_duplicate) == int(deep_before.flow_duplicate), "card_detail_duplicate_apply_zero")
	await _capture("bestiary_formal_card_detail.png")

	if not await _click_control(nodes.overlay.get("catalog_back_button") as Control):
		_fail("card_detail_back_button_unavailable")
		await _dispose_main(main)
		return false
	if not await _wait_stage("first_monster_detail_restored", func() -> bool: return _surface_mode(nodes.surface, "monster", "detail") and str((nodes.navigation.call("navigation_snapshot") as Dictionary).get("stable_item_id", "")) == "monster:%d" % first_index):
		await _dispose_main(main)
		return false
	if not await _click_control(nodes.overlay.get("catalog_back_button") as Control):
		_fail("monster_detail_back_button_unavailable")
		await _dispose_main(main)
		return false
	if not await _wait_stage("monster_browser_restored", func() -> bool: return _surface_mode(nodes.surface, "monster", "browser") and _thumbnail_count(nodes.surface) >= 2):
		await _dispose_main(main)
		return false
	await _capture("bestiary_formal_browser_restored.png")
	browser = nodes.surface.get_node_or_null("%BestiaryCodexBrowser") as Control
	grid = browser.get("thumbnail_grid") as GridContainer if browser != null else null
	var second := grid.get_child(1) as Control if grid != null and grid.get_child_count() >= 2 else null
	if second == null or not await _click_control(second) or not await _click_control(second, true):
		_fail("second_monster_double_click_delivery_failed")
		await _dispose_main(main)
		return false
	var second_index := int(second.get("_catalog_index"))
	if not await _wait_stage("second_monster_detail_visible", func() -> bool: return _surface_mode(nodes.surface, "monster", "detail") and _selected_monster(nodes.navigation) == second_index):
		await _dispose_main(main)
		return false
	if not await _click_control(nodes.overlay.get("catalog_back_button") as Control) or not await _wait_stage("second_monster_browser_restored", func() -> bool: return _surface_mode(nodes.surface, "monster", "browser")):
		await _dispose_main(main)
		return false
	if not await _click_control(nodes.overlay.get("catalog_back_button") as Control) or not await _wait_stage("scenario_a_hub_restored", func() -> bool: return _surface_mode(nodes.surface, "compendium", "hub")):
		await _dispose_main(main)
		return false
	var gameplay_after := _capture_gameplay_state(nodes.coordinator)
	_expect(gameplay_after == gameplay_before, "scenario_a_gameplay_mutation_zero")
	_expect(_visible_ui_private_safe(nodes.surface), "scenario_a_privacy_violation_zero")
	_expect(int((nodes.navigation.call("navigation_snapshot") as Dictionary).get("stack_depth", -1)) == 0, "scenario_a_internal_history_drained_to_hub")
	_metrics["scenario_a_counters"] = _scenario_counters(counters_before, counters_after_preview, counters_after_detail, deep_before, deep_after)
	_metrics["scenario_a_navigation"] = (nodes.navigation.call("debug_snapshot") as Dictionary).duplicate(true)
	await _dispose_main(main)
	return _failures.is_empty()


func _run_scenario_b() -> bool:
	var scenario_started := Time.get_ticks_msec()
	_scenario_deadline_msec = scenario_started + 35000
	var main := await _spawn_four_player_session("scenario_b")
	if main == null:
		return false
	var nodes := _runtime_nodes(main)
	if not _runtime_nodes_ready(nodes):
		_fail("scenario_b_runtime_dependencies_missing")
		await _dispose_main(main)
		return false
	await _press_escape(main)
	if not await _wait_stage("scenario_b_menu_paused", func() -> bool: return bool((nodes.overlay as Control).visible)):
		await _dispose_main(main)
		return false
	if not bool(nodes.app_port.call("submit_action", "intel")):
		_fail("intel_application_intent_rejected")
		await _dispose_main(main)
		return false
	if not await _wait_stage("intel_visible", func() -> bool: return _quick_navigation_active(nodes.overlay) == "intel"):
		await _dispose_main(main)
		return false
	var return_before := int((nodes.flow.call("debug_snapshot") as Dictionary).get("return_count", 0))
	if not bool(nodes.navigation_port.call("request_open", "compendium", "hub", "hub", -1, "", 0, "intel", {"origin": "intel"})):
		_fail("intel_compendium_navigation_intent_rejected")
		await _dispose_main(main)
		return false
	if not await _wait_stage("intel_compendium_visible", func() -> bool: return _surface_mode(nodes.surface, "compendium", "hub")):
		await _dispose_main(main)
		return false
	var monster_button := _button_with_text(nodes.surface.get("compendium_hub") as Control, "怪兽生态档案")
	if monster_button == null or not await _click_control(monster_button):
		_fail("scenario_b_monster_hub_button_unavailable")
		await _dispose_main(main)
		return false
	if not await _wait_stage("scenario_b_monster_browser_visible", func() -> bool: return _surface_mode(nodes.surface, "monster", "browser")):
		await _dispose_main(main)
		return false
	await _settle_frames(2)
	var intel_private_before := _capture_gameplay_state(nodes.coordinator)
	if not await _click_control(nodes.overlay.get("catalog_back_button") as Control) or not await _wait_stage("scenario_b_hub_restored", func() -> bool: return _surface_mode(nodes.surface, "compendium", "hub")):
		await _dispose_main(main)
		return false
	if not await _click_control(nodes.overlay.get("catalog_back_button") as Control):
		_fail("scenario_b_external_back_button_unavailable")
		await _dispose_main(main)
		return false
	if not await _wait_stage("intel_returned", func() -> bool: return _quick_navigation_active(nodes.overlay) == "intel"):
		await _dispose_main(main)
		return false
	_timings["intel_return_seconds"] = _elapsed_seconds(scenario_started)
	var intel_private_after := _capture_gameplay_state(nodes.coordinator)
	var return_after := int((nodes.flow.call("debug_snapshot") as Dictionary).get("return_count", 0))
	var changed_gameplay_sections := _changed_gameplay_sections(intel_private_before, intel_private_after)
	_expect(changed_gameplay_sections.is_empty(), "scenario_b_intel_private_and_gameplay_state_unchanged:changed=%s" % [changed_gameplay_sections])
	_expect(return_after == return_before + 1, "scenario_b_external_return_consumed_once")
	_expect(int((nodes.navigation.call("navigation_snapshot") as Dictionary).get("stack_depth", -1)) == 0, "scenario_b_internal_history_empty_on_exit")
	_expect(_quick_navigation_active(nodes.overlay) == "intel", "scenario_b_returns_to_intel")
	_metrics["scenario_b_external_return_consumed_count"] = return_after - return_before
	await _dispose_main(main)
	return _failures.is_empty()


func _spawn_four_player_session(scenario_id: String) -> Control:
	var main := MAIN_SCENE.instantiate() as Control
	if main == null:
		_fail("%s_main_scene_instantiation_failed" % scenario_id)
		return null
	var save := main.get_node_or_null(SAVE_PATH)
	var save_path := "user://test_runs/bestiary_formal_product_path_%s.save" % scenario_id
	if save == null or not save.has_method("set_qa_default_save_path_override") or not bool(save.call("set_qa_default_save_path_override", save_path)):
		_fail("%s_qa_save_override_failed" % scenario_id)
		main.free()
		return null
	add_child(main)
	if not await _wait_stage("%s_main_menu_ready" % scenario_id, func() -> bool: return _visible_child(main, "MainMenuPlanetLobbyPanel") != null):
		await _dispose_main(main)
		return null
	var lobby := _visible_child(main, "MainMenuPlanetLobbyPanel")
	var new_run := lobby.call("get_action_button", "new_run") as Button if lobby != null and lobby.has_method("get_action_button") else null
	if new_run == null or not await _click_control(new_run):
		_fail("%s_new_run_button_unavailable" % scenario_id)
		await _dispose_main(main)
		return null
	if not await _wait_stage("%s_setup_ready" % scenario_id, func() -> bool: return _visible_child(main, "NewGameSetupPage") != null):
		await _dispose_main(main)
		return null
	var setup := _visible_child(main, "NewGameSetupPage")
	var start_button := setup.get("start_button") as Button if setup != null else null
	if start_button == null or start_button.disabled:
		_fail("%s_setup_start_button_unavailable" % scenario_id)
		await _dispose_main(main)
		return null
	start_button.pressed.emit()
	await _settle_frames(2)
	var coordinator := main.get_node_or_null(COORDINATOR_PATH)
	if not await _wait_stage("session_ready", func() -> bool: return _public_player_count(coordinator) == 4):
		await _dispose_main(main)
		return null
	return main


func _runtime_nodes(main: Control) -> Dictionary:
	var overlay := main.get_node_or_null(OVERLAY_PATH)
	return {
		"coordinator": main.get_node_or_null(COORDINATOR_PATH),
		"overlay": overlay,
		"surface": overlay.call("get_codex_surface") if overlay != null and overlay.has_method("get_codex_surface") else null,
		"app_port": main.get_node_or_null(APP_PORT_PATH),
		"flow": main.get_node_or_null(FLOW_PATH),
		"navigation_port": main.get_node_or_null(NAV_PORT_PATH),
		"navigation": main.get_node_or_null(NAV_OWNER_PATH),
		"card_source": main.get_node_or_null(CARD_SOURCE_PATH),
		"monster_source": main.get_node_or_null(MONSTER_SOURCE_PATH),
	}


func _runtime_nodes_ready(nodes: Dictionary) -> bool:
	for key in ["coordinator", "overlay", "surface", "app_port", "flow", "navigation_port", "navigation", "card_source", "monster_source"]:
		if nodes.get(key) == null:
			return false
	return true


func _wait_stage(stage: String, predicate: Callable) -> bool:
	_stage_started_msec = Time.get_ticks_msec()
	while Time.get_ticks_msec() - _stage_started_msec < STAGE_TIMEOUT_MSEC and Time.get_ticks_msec() < _scenario_deadline_msec:
		await get_tree().process_frame
		if bool(predicate.call()):
			_timings["stage_%s_seconds" % stage] = _elapsed_seconds(_stage_started_msec)
			return true
	_fail("stage_timeout:%s" % stage)
	return false


func _click_control(control: Control, double_click: bool = false) -> bool:
	if control == null or not control.is_visible_in_tree() or control.get_global_rect().size.x <= 0.0 or control.get_global_rect().size.y <= 0.0:
		return false
	var position := control.get_global_rect().get_center()
	var viewport := control.get_viewport()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	viewport.push_input(motion, true)
	await get_tree().process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = position
	press.global_position = position
	press.double_click = double_click
	viewport.push_input(press, true)
	await get_tree().process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = position
	release.global_position = position
	viewport.push_input(release, true)
	await _settle_frames(2)
	return true


func _ensure_control_visible(control: Control) -> void:
	control.grab_focus()
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			(ancestor as ScrollContainer).ensure_control_visible(control)
			break
		ancestor = ancestor.get_parent()
	await _settle_frames(2)


func _press_escape(main: Control) -> void:
	var viewport := main.get_viewport()
	var press := InputEventKey.new()
	press.keycode = KEY_ESCAPE
	press.physical_keycode = KEY_ESCAPE
	press.pressed = true
	viewport.push_input(press, true)
	var release := InputEventKey.new()
	release.keycode = KEY_ESCAPE
	release.physical_keycode = KEY_ESCAPE
	release.pressed = false
	viewport.push_input(release, true)
	await _settle_frames(2)


func _capture(file_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("%s/%s" % [SCREENSHOT_DIR, file_name])
	var error := image.save_png(path)
	_expect(error == OK and FileAccess.file_exists(path), "screenshot_saved:%s" % file_name)


func _capture_gameplay_state(coordinator: Node) -> Dictionary:
	var owners := {}
	for node_name in ["ProductMarketRuntimeController", "CommodityFlowRuntimeController", "RouteNetworkRuntimeController", "RegionInfrastructureRuntimeController", "WeatherRuntimeController", "MonsterRuntimeController", "VictoryControlRuntimeController", "GameSessionRuntimeController", "RuntimeCommandPipeline"]:
		var node := coordinator.get_node_or_null(node_name)
		if node == null:
			owners[node_name] = {"missing": true}
		elif node.has_method("to_save_data"):
			owners[node_name] = (node.call("to_save_data") as Dictionary).duplicate(true)
		elif node.has_method("debug_snapshot"):
			owners[node_name] = (node.call("debug_snapshot") as Dictionary).duplicate(true)
	var public_world: WorldSessionPublicProjection = coordinator.call("presentation_public_world_projection") as WorldSessionPublicProjection
	var selection: TableSelectionState = coordinator.call("table_selection_state") as TableSelectionState
	var rng: RunRngService = coordinator.call("run_rng_service") as RunRngService
	var save := coordinator.get_node_or_null("GameSessionRuntimeController/GameSaveRuntimeCoordinator")
	return {
		"public_world": public_world.call("to_dictionary") if public_world != null else {},
		"world_clock": coordinator.call("world_effective_clock_snapshot"),
		"selection": selection.call("snapshot") if selection != null else {},
		"rng_state": int(rng.get("state")) if rng != null else -1,
		"public_log": coordinator.call("presentation_recent_public_log_entries", 256),
		"save": _capture_save_file_state(save),
		"owners": owners,
	}


func _capture_save_file_state(save: Node) -> Dictionary:
	if save == null or not save.has_method("default_save_path"):
		return {"available": false}
	var path := str(save.call("default_save_path"))
	var exists := not path.is_empty() and FileAccess.file_exists(path)
	return {
		"available": true,
		"path": path,
		"exists": exists,
		"sha256": FileAccess.get_sha256(path) if exists else "",
	}


func _changed_gameplay_sections(before: Dictionary, after: Dictionary) -> Array[String]:
	var changed: Array[String] = []
	var keys: Array = before.keys()
	for key_variant in after.keys():
		if key_variant not in keys:
			keys.append(key_variant)
	keys.sort()
	for key_variant in keys:
		var key := str(key_variant)
		if not before.has(key_variant) or not after.has(key_variant):
			changed.append(key)
			continue
		if key != "owners":
			if before[key_variant] != after[key_variant]:
				changed.append(key)
			continue
		var before_owners := before[key_variant] as Dictionary
		var after_owners := after[key_variant] as Dictionary
		var owner_names: Array = before_owners.keys()
		for owner_variant in after_owners.keys():
			if owner_variant not in owner_names:
				owner_names.append(owner_variant)
		owner_names.sort()
		for owner_variant in owner_names:
			if not before_owners.has(owner_variant) or not after_owners.has(owner_variant) or before_owners[owner_variant] != after_owners[owner_variant]:
				changed.append("owners.%s" % str(owner_variant))
	return changed


func _interaction_counters(nodes: Dictionary, browser: Control) -> Dictionary:
	var browser_debug := browser.call("debug_snapshot") as Dictionary
	var surface_debug := nodes.surface.call("debug_snapshot") as Dictionary
	var flow_debug := nodes.flow.call("debug_snapshot") as Dictionary
	return {
		"full_rebuild": int(browser_debug.get("full_rebuild_count", 0)),
		"preview_request": int(surface_debug.get("monster_preview_request_count", 0)),
		"detail_request": int(surface_debug.get("monster_detail_request_count", 0)),
		"deep_link": int(surface_debug.get("monster_card_deep_link_count", 0)),
		"flow_page_apply": int(flow_debug.get("page_apply_count", 0)),
		"flow_duplicate": int(flow_debug.get("duplicate_apply_count", 0)),
	}


func _scenario_counters(before: Dictionary, after_preview: Dictionary, after_detail: Dictionary, deep_before: Dictionary, deep_after: Dictionary) -> Dictionary:
	return {
		"preview_full_page_rebuild_count": int(after_preview.full_rebuild) - int(before.full_rebuild),
		"double_click_detail_count": int(after_detail.detail_request) - int(after_preview.detail_request),
		"second_click_preview_count": int(after_detail.preview_request) - int(after_preview.preview_request),
		"duplicate_detail_apply_count": int(after_detail.flow_duplicate) - int(after_preview.flow_duplicate),
		"monster_card_deep_link_count": int(deep_after.deep_link) - int(deep_before.deep_link),
		"duplicate_card_apply_count": int(deep_after.flow_duplicate) - int(deep_before.flow_duplicate),
	}


func _signal_connection_count(thumbnail: Control, browser: Control) -> int:
	return thumbnail.get_signal_connection_list("preview_requested").size() + thumbnail.get_signal_connection_list("detail_requested").size() + browser.get_signal_connection_list("entry_preview_requested").size() + browser.get_signal_connection_list("entry_detail_requested").size()


func _surface_mode(surface: Control, mode: String, view: String) -> bool:
	if surface == null:
		return false
	var snapshot := surface.call("debug_snapshot") as Dictionary
	return bool(snapshot.get("visible", false)) and str(snapshot.get("mode", "")) == mode and str(snapshot.get("view", "")) == view


func _selected_monster(navigation: Node) -> int:
	var snapshot := navigation.call("navigation_snapshot") as Dictionary
	return int((snapshot.get("monster", {}) as Dictionary).get("selected_index", -1))


func _thumbnail_count(surface: Control) -> int:
	var browser := surface.get_node_or_null("%BestiaryCodexBrowser") as Control
	var grid := browser.get("thumbnail_grid") as GridContainer if browser != null else null
	return grid.get_child_count() if grid != null else 0


func _button_with_text(parent: Control, text: String) -> Button:
	if parent == null:
		return null
	for node in parent.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.text == text and button.visible and not button.disabled:
			return button
	return null


func _quick_navigation_active(overlay: Control) -> String:
	if overlay == null or not overlay.visible:
		return ""
	var debug := overlay.call("debug_snapshot") as Dictionary
	var quick := debug.get("quick_navigation", {}) as Dictionary if debug.get("quick_navigation", {}) is Dictionary else {}
	return str(quick.get("active_id", ""))


func _visible_child(root_node: Node, node_name: String) -> Control:
	var node := root_node.find_child(node_name, true, false) as Control
	return node if node != null and node.is_visible_in_tree() else null


func _public_player_count(coordinator: Node) -> int:
	if coordinator == null:
		return 0
	var projection: WorldSessionPublicProjection = coordinator.call("presentation_public_world_projection") as WorldSessionPublicProjection
	return (projection.get("players") as Array).size() if projection != null and projection.get("players") is Array else 0


func _visible_ui_private_safe(surface: Control) -> bool:
	var text_controls: Array[Node] = []
	text_controls.append_array(surface.find_children("*", "Label", true, false))
	text_controls.append_array(surface.find_children("*", "Button", true, false))
	text_controls.append_array(surface.find_children("*", "RichTextLabel", true, false))
	for node in text_controls:
		var control := node as Control
		if control == null or not control.is_visible_in_tree():
			continue
		var combined := "%s %s" % [str(node.get("text")), control.tooltip_text]
		for forbidden in ["hidden_owner", "owner_actor_id", "private_hand", "private_cash", "ai_score", "/root/" + "Main", "res://", "MISSING"]:
			if combined.contains(forbidden):
				return false
	return true


func _settle_frames(count: int) -> void:
	for _index in range(maxi(1, count)):
		await get_tree().process_frame


func _dispose_main(main: Control) -> void:
	if main != null and is_instance_valid(main):
		main.queue_free()
	await _settle_frames(3)


func _elapsed_seconds(started_msec: int) -> float:
	return snappedf(float(Time.get_ticks_msec() - started_msec) / 1000.0, 0.001)


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_fail(label)


func _fail(label: String) -> void:
	if not _failures.has(label):
		_failures.append(label)
	push_error("BESTIARY FORMAL PRODUCT PATH: %s" % label)


func _write_result() -> void:
	var payload := {
		"status": "PASS" if _failures.is_empty() else "FAIL",
		"checks": _checks,
		"failures": _failures,
		"timings": _timings,
		"metrics": _metrics,
		"expected_card_id": _expected_card_id,
		"actual_card_id": _actual_card_id,
		"card_id_resolver_used": not _expected_card_id.is_empty(),
	}
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "\t"))


func _finish() -> void:
	if _failures.is_empty():
		print("BESTIARY_FORMAL_PRODUCT_PATH|status=PASS|checks=%d|scenario_a=PASS|scenario_b=PASS|seconds=%.3f" % [_checks, _elapsed_seconds(_run_started_msec)])
		get_tree().quit(0)
		return
	print("BESTIARY_FORMAL_PRODUCT_PATH|status=FAIL|checks=%d|failures=%d|labels=%s" % [_checks, _failures.size(), _failures])
	get_tree().quit(1)
