extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const CodexOpenRequestScript := preload("res://scripts/runtime/codex_open_request.gd")
const QA_SAVE_PATH := "user://test_runs/compendium_readonly_navigation_cutover.save"
const COORDINATOR_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator"
const MENU_OVERLAY_PATH := "RuntimeGameScreen/OverlayLayer/RuntimeSurfaceLayer/MenuModalOverlay"
const FLOW_PATH := "RuntimeServices/CompendiumApplicationFlowController"
const PORT_PATH := "RuntimeServices/CompendiumNavigationPort"
const QUERY_PATH := "RuntimeServices/CompendiumReadOnlyQueryPort"
const APP_PORT_PATH := "RuntimeServices/ApplicationFlowPort"
const NAV_OWNER_PATH := COORDINATOR_PATH + "/CodexNavigationRuntimeController"
const CARD_SOURCE_PATH := COORDINATOR_PATH + "/CardCodexPublicSourceService"
const MONSTER_SOURCE_PATH := COORDINATOR_PATH + "/MonsterCodexPublicSourceService"

const RETIRED_MAIN_METHODS := [
	"_open_compendium_menu", "_on_codex_surface_action_requested", "_cycle_menu_catalog",
	"_back_from_catalog_menu", "_open_card_codex_by_name", "_update_card_codex_menu",
	"_open_bestiary_menu", "_update_bestiary_menu", "_update_product_codex_menu",
	"_update_region_codex_menu", "_update_role_codex_menu", "_present_codex_page",
	"_open_intel_region_codex_link", "_open_intel_card_codex_link",
	"_open_intel_monster_codex_link", "_open_intel_product_codex_link",
]

var _checks := 0
var _failures: Array[String] = []
var _runtime_root: Node
var _coordinator: Node
var _overlay: Control
var _surface: Control
var _flow: Node
var _port: Node
var _query: Node
var _app_port: Node
var _navigation: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_qa_save()
	var packed := load(MAIN_SCENE) as PackedScene
	_expect(packed != null, "main_scene_loads")
	if packed == null:
		_finish()
		return
	_runtime_root = packed.instantiate()
	var save := _runtime_root.get_node_or_null(COORDINATOR_PATH + "/GameSessionRuntimeController/GameSaveRuntimeCoordinator")
	_expect(save != null and save.has_method("set_qa_default_save_path_override"), "qa_save_override_available_before_tree_entry")
	if save == null or not bool(save.call("set_qa_default_save_path_override", QA_SAVE_PATH)):
		_runtime_root.free()
		_runtime_root = null
		_finish()
		return
	root.add_child(_runtime_root)
	await _settle(2)
	_runtime_root.set("configured_player_count", 4)
	_runtime_root.set("configured_ai_player_count", 3)
	_runtime_root.call("_new_game")
	await _settle(3)
	_bind_nodes()
	_test_composition_and_source_direction()
	if _dependencies_ready():
		_runtime_root.call("_open_pause_menu")
		await _settle(2)
		var gameplay_before := _capture_gameplay_state()
		var counters_before := _counter_snapshot()
		await _exercise_internal_navigation()
		var gameplay_after := _capture_gameplay_state()
		_expect(gameplay_after == gameplay_before, "all_internal_compendium_navigation_has_zero_gameplay_mutation")
		_test_exact_once_counters(counters_before, _counter_snapshot())
		await _test_duplicate_and_invalid_requests()
		await _test_return_targets()
	_test_main_negative_surface()
	await _cleanup()
	_finish()


func _bind_nodes() -> void:
	_coordinator = _runtime_root.get_node_or_null(COORDINATOR_PATH)
	_overlay = _runtime_root.get_node_or_null(MENU_OVERLAY_PATH) as Control
	_surface = _overlay.call("get_codex_surface") as Control if _overlay != null and _overlay.has_method("get_codex_surface") else null
	_flow = _runtime_root.get_node_or_null(FLOW_PATH)
	_port = _runtime_root.get_node_or_null(PORT_PATH)
	_query = _runtime_root.get_node_or_null(QUERY_PATH)
	_app_port = _runtime_root.get_node_or_null(APP_PORT_PATH)
	_navigation = _runtime_root.get_node_or_null(NAV_OWNER_PATH)


func _dependencies_ready() -> bool:
	var ready := _coordinator != null and _overlay != null and _surface != null and _flow != null and _port != null and _query != null and _app_port != null and _navigation != null
	_expect(ready, "real_scene_composes_all_compendium_dependencies")
	return ready


func _test_composition_and_source_direction() -> void:
	_expect(_dependencies_ready(), "scene_owned_compendium_composition_is_complete")
	if not _dependencies_ready():
		return
	var flow_debug := _flow.call("debug_snapshot") as Dictionary
	var query_debug := _query.call("debug_snapshot") as Dictionary
	var port_debug := _port.call("debug_snapshot") as Dictionary
	var nav_debug := _navigation.call("debug_snapshot") as Dictionary
	_expect(not bool(flow_debug.get("references_main", true)) and not bool(flow_debug.get("owns_navigation_state", true)), "flow_has_no_main_or_second_navigation_owner")
	_expect(not bool(query_debug.get("references_main", true)) and bool(query_debug.get("pure_data_only", false)) and not bool(query_debug.get("mutates_runtime", true)), "query_port_is_pure_read_only_and_main_free")
	_expect(not bool(port_debug.get("owns_navigation_state", true)) and bool(port_debug.get("typed_request_boundary", false)), "navigation_port_is_typed_and_non_owning")
	_expect(bool(nav_debug.get("owns_navigation_stack", false)) and not bool(nav_debug.get("reads_gameplay_world", true)), "codex_navigation_controller_remains_unique_state_owner")
	var app_debug := _app_port.call("debug_snapshot") as Dictionary
	_expect(bool(app_debug.get("compendium_signal_boundary", false)) and not bool(app_debug.get("compendium_uses_generic_action_signal", true)) and not bool(app_debug.get("compendium_to_main", true)), "application_flow_uses_dedicated_compendium_signal")


func _exercise_internal_navigation() -> void:
	var app_before := _app_port.call("debug_snapshot") as Dictionary
	_expect(bool(_app_port.call("submit_action", "compendium")), "dedicated_compendium_action_is_accepted")
	await _settle(2)
	var app_after := _app_port.call("debug_snapshot") as Dictionary
	_expect(int(app_after.get("compendium_emission_count", 0)) == int(app_before.get("compendium_emission_count", 0)) + 1, "compendium_signal_emits_once")
	_expect(int(app_after.get("action_emission_count", 0)) == int(app_before.get("action_emission_count", 0)), "compendium_never_uses_generic_action_signal")
	_expect(_surface_mode_is("compendium", "hub"), "hub_renders_on_real_codex_surface")

	_emit_surface_action("hub_action", {"action_id": "role"})
	await _settle(2)
	_expect(_surface_mode_is("role", "detail"), "role_detail_renders")
	_emit_overlay_step(1)
	await _settle(2)
	_expect(int((_navigation.call("navigation_snapshot") as Dictionary).get("role", {}).get("selected_index", -1)) == 1, "role_previous_next_is_owner_driven")
	_emit_overlay_back()
	await _settle(2)
	_expect(_surface_mode_is("compendium", "hub"), "role_back_returns_to_hub")

	_emit_surface_action("hub_action", {"action_id": "card"})
	await _settle(2)
	_expect(_surface_mode_is("card", "browser"), "card_browser_renders")
	_emit_surface_action("card_filter", {"filter_id": "monster"})
	await _settle(2)
	var card_source := _runtime_root.get_node_or_null(CARD_SOURCE_PATH)
	var card_ids: Array = card_source.call("ordered_card_ids", "monster") if card_source != null else []
	_expect(not card_ids.is_empty(), "card_filter_resolves_current_v06_public_catalog")
	if not card_ids.is_empty():
		var card_id := str(card_ids[0])
		_emit_surface_action("card_preview", {"card_name": card_id})
		await _settle(2)
		_expect(_surface_mode_is("card", "browser"), "card_preview_updates_browser_without_second_state_owner")
		_emit_surface_action("card_detail", {"card_name": card_id})
		await _settle(2)
		_expect(_surface_mode_is("card", "detail"), "card_detail_renders")
		_emit_overlay_step(1)
		await _settle(2)
		_expect(_surface_mode_is("card", "detail"), "card_detail_step_wraps_through_query_owner")
		_emit_overlay_back()
		await _settle(2)
		_expect(_surface_mode_is("card", "browser"), "card_detail_back_returns_to_browser")
	_emit_overlay_back()
	await _settle(2)
	_expect(_surface_mode_is("compendium", "hub"), "card_browser_back_returns_to_hub")

	_emit_surface_action("hub_action", {"action_id": "monster"})
	await _settle(2)
	_expect(_surface_mode_is("monster", "browser"), "monster_browser_renders")
	_emit_surface_action("monster_preview", {"catalog_index": 0})
	await _settle(2)
	_expect(_surface_mode_is("monster", "browser"), "monster_preview_renders_in_browser")
	_emit_surface_action("monster_detail", {"catalog_index": 0})
	await _settle(2)
	_expect(_surface_mode_is("monster", "detail"), "monster_detail_renders")
	var monster_source := _runtime_root.get_node_or_null(MONSTER_SOURCE_PATH)
	var monster := monster_source.call("compose_snapshot", 0, true) as Dictionary if monster_source != null else {}
	var link := monster.get("monster_card_link", {}) as Dictionary if monster.get("monster_card_link", {}) is Dictionary else {}
	var linked_card := str(link.get("card_name", ""))
	_expect(linked_card != "", "monster_detail_exposes_public_card_deep_link")
	if linked_card != "":
		_emit_surface_action("card_deep_link", {"card_name": linked_card})
		await _settle(2)
		_expect(_surface_mode_is("card", "detail"), "monster_to_card_deep_link_renders_card")
		_emit_overlay_back()
		await _settle(2)
		_expect(_surface_mode_is("monster", "detail"), "owner_stack_restores_monster_detail_after_card_deep_link")
	_emit_overlay_back()
	await _settle(2)
	_expect(_surface_mode_is("monster", "browser"), "monster_detail_back_returns_to_browser")
	_emit_overlay_back()
	await _settle(2)
	_expect(_surface_mode_is("compendium", "hub"), "monster_browser_back_returns_to_hub")

	_emit_surface_action("hub_action", {"action_id": "product"})
	await _settle(2)
	_expect(_surface_mode_is("product", "browser"), "product_browser_renders_without_catalog_initialization")
	_emit_surface_action("product_preview", {"catalog_index": 0})
	await _settle(2)
	_expect(_surface_mode_is("product", "browser"), "product_preview_renders")
	_emit_surface_action("product_detail", {"catalog_index": 0})
	await _settle(2)
	_expect(_surface_mode_is("product", "detail"), "product_detail_renders")
	_emit_overlay_back()
	await _settle(2)
	_emit_overlay_back()
	await _settle(2)
	_expect(_surface_mode_is("compendium", "hub"), "product_returns_to_hub")

	_emit_surface_action("hub_action", {"action_id": "region"})
	await _settle(2)
	_expect(_surface_mode_is("region", "detail"), "region_detail_renders")
	_emit_overlay_step(1)
	await _settle(2)
	_expect(_surface_mode_is("region", "detail"), "region_previous_next_is_navigation_only")
	_emit_overlay_back()
	await _settle(2)
	_expect(_surface_mode_is("compendium", "hub"), "region_returns_to_hub")


func _test_exact_once_counters(before: Dictionary, after: Dictionary) -> void:
	var accepted_delta := int(after.get("port_accepted", 0)) - int(before.get("port_accepted", 0))
	var input_delta := int(after.get("flow_input", 0)) - int(before.get("flow_input", 0))
	var transition_delta := int(after.get("flow_navigation", 0)) - int(before.get("flow_navigation", 0))
	var query_delta := int(after.get("flow_query", 0)) - int(before.get("flow_query", 0))
	var apply_delta := int(after.get("flow_apply", 0)) - int(before.get("flow_apply", 0))
	var resolve_delta := int(after.get("query_resolve", 0)) - int(before.get("query_resolve", 0))
	var compose_delta := int(after.get("query_compose", 0)) - int(before.get("query_compose", 0))
	var owner_delta := int(after.get("owner_transition", 0)) - int(before.get("owner_transition", 0))
	_expect(accepted_delta > 0 and accepted_delta == input_delta, "each_accepted_request_reaches_flow_once")
	_expect(input_delta == transition_delta and input_delta == query_delta and input_delta == apply_delta, "input_navigation_query_and_page_apply_are_exact_once")
	_expect(input_delta == resolve_delta and input_delta == compose_delta and input_delta == owner_delta, "query_resolution_and_navigation_owner_transition_are_exact_once")
	_expect(int(after.get("flow_duplicate", 0)) == int(before.get("flow_duplicate", 0)), "internal_navigation_has_no_duplicate_page_apply")


func _test_duplicate_and_invalid_requests() -> void:
	var revision := int((_port.call("debug_snapshot") as Dictionary).get("next_revision", 1))
	var request: RefCounted = CodexOpenRequestScript.new() as RefCounted
	request.set("domain", "compendium")
	request.set("view", "hub")
	request.set("stable_item_id", "hub")
	request.set("return_target", "compendium")
	request.set("request_revision", revision)
	request.set("public_source_context", {"origin": "compendium"})
	_expect(bool(_port.call("submit_request", request)), "first_typed_revision_is_accepted")
	await _settle(2)
	var flow_after_first := _flow.call("debug_snapshot") as Dictionary
	_expect(not bool(_port.call("submit_request", request)), "duplicate_typed_revision_fails_closed")
	await _settle(1)
	var flow_after_duplicate := _flow.call("debug_snapshot") as Dictionary
	_expect(int(flow_after_duplicate.get("page_apply_count", 0)) == int(flow_after_first.get("page_apply_count", 0)), "duplicate_revision_does_not_apply_page_twice")

	_expect(not bool(_port.call("request_open", "card", "browser", "catalog", -1, "invalid_filter", 0, "compendium", {})), "invalid_filter_fails_closed_before_flow")
	var canary := Node.new()
	_expect(not bool(_port.call("request_open", "card", "browser", "catalog", -1, "all", 0, "compendium", {"origin": "card", "runtime": canary})), "runtime_object_context_fails_closed")
	canary.free()
	var nav_before := _navigation.call("navigation_snapshot") as Dictionary
	var flow_before := _flow.call("debug_snapshot") as Dictionary
	_expect(bool(_port.call("request_open", "product", "detail", "missing_product", -1, "", 0, "compendium", {"origin": "product"})), "well_typed_unknown_item_reaches_read_only_resolver")
	await _settle(2)
	var flow_after := _flow.call("debug_snapshot") as Dictionary
	_expect(_navigation.call("navigation_snapshot") == nav_before, "unknown_stable_id_does_not_change_navigation_owner")
	_expect(int(flow_after.get("page_apply_count", 0)) == int(flow_before.get("page_apply_count", 0)), "unknown_stable_id_never_applies_old_or_first_item")


func _test_return_targets() -> void:
	for target in ["economy", "standings", "intel"]:
		_expect(bool(_port.call("request_open", "role", "detail", "catalog", 0, "", 0, target, {"origin": target})), "return_target_%s_page_opens" % target)
		await _settle(2)
		_emit_overlay_back()
		await _settle(2)
		var expected_title: String = str({"economy": "经济总览", "standings": "局势排名", "intel": "情报档案"}.get(target, ""))
		_expect(str((_overlay.call("debug_snapshot") as Dictionary).get("title", "")) == expected_title, "return_target_%s_routes_through_application_flow" % target)
	_runtime_root.call("_open_pause_menu")
	await _settle(1)
	_expect(bool(_port.call("request_open", "role", "detail", "catalog", 0, "", 0, "game", {"origin": "game"})), "game_return_page_opens")
	await _settle(1)
	_emit_overlay_back()
	await _settle(1)
	_expect(not _overlay.visible, "game_return_closes_menu")


func _test_main_negative_surface() -> void:
	var main_source := FileAccess.get_file_as_string("res://scripts/" + "main.gd")
	var scene_source := FileAccess.get_file_as_string("res://scenes/main.tscn")
	var offenders: Array[String] = []
	for method_name in RETIRED_MAIN_METHODS:
		if main_source.contains("func %s(" % method_name):
			offenders.append(method_name)
	_expect(offenders.is_empty(), "retired_main_compendium_methods_are_physically_absent|offenders=%s" % offenders)
	_expect(not main_source.contains("CompendiumHubSnapshotScript") and not main_source.contains("PLAYER_ROLE_CATALOG"), "main_has_no_compendium_hub_or_role_catalog_copy")
	_expect(scene_source.contains('signal="compendium_requested"') and scene_source.contains('to="RuntimeServices/CompendiumApplicationFlowController" method="open_hub"'), "dedicated_compendium_signal_is_scene_composed")
	_expect(scene_source.contains('signal="catalog_step_requested"') and scene_source.contains('signal="catalog_back_requested"') and scene_source.contains('signal="codex_action_requested"'), "all_codex_surface_signals_target_scene_owned_flow")
	_expect(not scene_source.contains('signal="catalog_step_requested" from="RuntimeGameScreen/OverlayLayer/RuntimeSurfaceLayer/MenuModalOverlay" to="."'), "main_has_no_catalog_signal_connection")


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
	return {
		"world_session": session.call("internal_snapshot") if session != null else {},
		"world_clock": _coordinator.call("world_effective_clock_snapshot"),
		"selection": selection.call("snapshot") if selection != null else {},
		"rng_state": int(rng.get("state")) if rng != null else -1,
		"public_log": _coordinator.call("presentation_recent_public_log_entries", 256),
		"owners": owners,
	}


func _counter_snapshot() -> Dictionary:
	var flow := _flow.call("debug_snapshot") as Dictionary
	var port := _port.call("debug_snapshot") as Dictionary
	var query := _query.call("debug_snapshot") as Dictionary
	var owner := _navigation.call("debug_snapshot") as Dictionary
	return {
		"port_accepted": int(port.get("accepted_count", 0)),
		"flow_input": int(flow.get("input_count", 0)),
		"flow_navigation": int(flow.get("navigation_transition_count", 0)),
		"flow_query": int(flow.get("query_count", 0)),
		"flow_apply": int(flow.get("page_apply_count", 0)),
		"flow_duplicate": int(flow.get("duplicate_apply_count", 0)),
		"query_resolve": int(query.get("resolve_count", 0)),
		"query_compose": int(query.get("query_count", 0)),
		"owner_transition": int(owner.get("transition_count", 0)),
	}


func _surface_mode_is(mode: String, view: String) -> bool:
	var snapshot := _surface.call("debug_snapshot") as Dictionary
	return str(snapshot.get("mode", "")) == mode and str(snapshot.get("view", "")) == view and bool(snapshot.get("page_is_pure_data", false))


func _emit_surface_action(action_id: String, payload: Dictionary) -> void:
	_surface.emit_signal("action_requested", action_id, payload.duplicate(true))


func _emit_overlay_step(delta: int) -> void:
	_overlay.emit_signal("catalog_step_requested", delta)


func _emit_overlay_back() -> void:
	_overlay.emit_signal("catalog_back_requested")


func _settle(frame_count: int) -> void:
	for _index in range(maxi(1, frame_count)):
		await process_frame


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(label)
	push_error("COMPENDIUM READONLY NAVIGATION: %s" % label)


func _cleanup() -> void:
	if _runtime_root != null:
		_runtime_root.queue_free()
		_runtime_root = null
	await process_frame
	_cleanup_qa_save()


func _cleanup_qa_save() -> void:
	for path in [QA_SAVE_PATH, QA_SAVE_PATH + ".tmp"]:
		var absolute := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(absolute)


func _finish() -> void:
	if _failures.is_empty():
		print("COMPENDIUM_READONLY_NAVIGATION_CUTOVER_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	print("COMPENDIUM_READONLY_NAVIGATION_CUTOVER_TEST|status=FAIL|checks=%d|failures=%d|labels=%s" % [_checks, _failures.size(), _failures])
	quit(1)
