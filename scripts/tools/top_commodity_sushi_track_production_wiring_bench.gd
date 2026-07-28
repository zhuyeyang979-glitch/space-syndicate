extends Control
class_name TopCommoditySushiTrackProductionWiringBench

const RULESET_V04 := preload("res://resources/rules/space_syndicate_ruleset_v04.tres")
const SCREENSHOT_PATH := "res://docs/ui_qa/top_commodity_track/commodity_track_right_inspector.png"

@export var auto_run := true
@export var quit_on_finish := false

var last_result: Dictionary = {}
var _checks := 0
var _failures: Array[String] = []
var _running := false


class RuntimeWorld:
	extends Node
	var players: Array = [
		{"id": 0, "name": "本地玩家", "seat_type": "human", "is_ai": false, "cash": 1000, "cash_cents": 100000, "slots": []},
		{"id": 1, "name": "对手", "seat_type": "ai", "is_ai": true, "cash": 654321, "cash_cents": 65432100, "slots": [{"name": "PRIVATE_HAND"}], "ai_plan": "PRIVATE_PLAN"},
	]
	var game_time := 0.0
	var map_width_m := 1000.0
	var districts: Array = [
		{"name": "Alpha", "region_id": "region.alpha", "center": Vector2.ZERO, "neighbors": [], "destroyed": false},
	]
	var monster_runtime_controller: Node = null


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("_run_auto")


func _run_auto() -> void:
	var result := await run_checks()
	if quit_on_finish or DisplayServer.get_name().to_lower() == "headless":
		get_tree().quit(0 if bool(result.get("passed", false)) else 1)


func run_checks() -> Dictionary:
	if _running:
		return last_result.duplicate(true)
	_running = true
	_checks = 0
	_failures.clear()
	var coordinator := %GameRuntimeCoordinator as GameRuntimeCoordinator
	var game_screen := %GameScreen as SpaceSyndicateGameScreen
	var status_label := %StatusLabel as Label
	_check(coordinator != null and game_screen != null, "production_coordinator_and_game_screen_present")
	if coordinator == null or game_screen == null:
		return _finish(status_label)
	var runtime_loop := coordinator.get_node_or_null("RuntimeLoop") as RuntimeLoop
	if runtime_loop != null:
		runtime_loop.set_process(false)
	coordinator.configure(RULESET_V04.debug_snapshot())
	_configure_presentation_dependencies(coordinator)
	var world := RuntimeWorld.new()
	world.name = "RuntimeWorldFixture"
	add_child(world)
	coordinator.bind_ai_world(world)
	coordinator.world_session_state().replace_players(world.players, true)
	coordinator.world_session_state().replace_districts(world.districts, true)
	coordinator.refresh_v06_production_player_bindings(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var viewer_context := coordinator.table_presentation_query_ports().viewer_context()
	var actor_context := GameplayActorAuthorizationContext.new()
	actor_context.request_id = "actor-context:commodity-track-bench:1"
	actor_context.authorized = true
	actor_context.reason_code = "authorized"
	actor_context.viewer_index = 0
	actor_context.authorized_actor_player_index = 0
	actor_context.authorization_revision = maxi(1, int(viewer_context.authorization_revision))
	actor_context.session_id = "commodity-track-bench-session"
	actor_context.session_revision = 1
	actor_context.source_surface = &"game_screen"
	actor_context.issued_at_operation_revision = 1
	game_screen.bind_gameplay_actor_authorization_context(actor_context)
	_check(
		actor_context.is_valid() \
			and str(game_screen.get("_presentation_session_id")) == actor_context.session_id \
			and int(game_screen.get("_presentation_session_revision")) == actor_context.session_revision,
		"synthetic_bench_actor_context_is_valid_and_bound:%s" % JSON.stringify(actor_context.to_dictionary())
	)
	var service := coordinator.get_node_or_null("CommoditySushiTrackRuntimeService")
	var inventory := coordinator.commodity_card_inventory_runtime_controller()
	var track := game_screen.get_node_or_null("SafeArea/MainRows/TopCommoditySushiTrack")
	_check(service != null and inventory != null and track != null, "unique_owner_projection_and_track_present")
	_check(coordinator.find_children("CommoditySushiTrackRuntimeService", "Node", true, false).size() == 1, "one_projection_service")
	_check(game_screen.find_children("TopCommoditySushiTrack", "PanelContainer", true, false).size() == 1, "one_top_commodity_track")
	_check(game_screen.find_children("PublicTrack", "*", true, false).is_empty() and game_screen.find_children("TrackFocusRibbon", "*", true, false).is_empty(), "old_persistent_track_absent")
	if service == null or inventory == null or track == null:
		world.queue_free()
		return _finish(status_label)

	var receipt := coordinator.request_table_presentation_refresh(&"full", &"commodity_sushi_bench")
	await get_tree().process_frame
	# The synthetic Bench has no running GameSession, so the production refresh
	# correctly rebinds a denied session context. Re-apply the explicit valid Bench
	# context after that refresh to exercise the UI/ApplicationFlow claim path.
	game_screen.bind_gameplay_actor_authorization_context(actor_context)
	_check(receipt != null and receipt.applied, "typed_full_presentation_applies")
	var track_debug: Dictionary = track.debug_snapshot()
	var initial_rendered_count := int(track_debug.get("rendered_item_count", -1))
	_check(initial_rendered_count == 12, "all_twelve_active_public_commodity_types_render")
	_check(track.size.x >= 1000.0 and track.size.y >= 150.0, "top_track_is_wide_and_thick")
	var planet := game_screen.get_node_or_null("SafeArea/MainRows/TableArea/PlanetBoard") as Control
	var inspector := game_screen.get_node_or_null("SafeArea/MainRows/TableArea/RightInspector") as Control
	_check(planet != null and inspector != null and planet.size.x > inspector.size.x and planet.size.y > track.size.y, "planet_remains_primary_visual")
	_check(planet != null and not planet.get_global_rect().intersects(track.get_global_rect()), "top_track_does_not_cover_planet_input")
	_check(inspector != null and not inspector.get_global_rect().intersects(track.get_global_rect()), "top_track_does_not_overlap_right_inspector")
	var rendered_ids: Array = track_debug.get("rendered_slot_ids", []) if track_debug.get("rendered_slot_ids", []) is Array else []
	if not rendered_ids.is_empty():
		var slot_id := str(rendered_ids[0])
		var item_node := track.find_child("CommoditySlot_%s" % _safe_node_name(slot_id), true, false)
		if item_node != null:
			await _hover_control(item_node as Control)
		await get_tree().process_frame
		var inspector_title := inspector.find_child("InspectorTitle", true, false) as Label if inspector != null else null
		_check(item_node != null and inspector_title != null and inspector_title.text == "公共商品", "item_focus_updates_right_inspector")
		var cash_before := int(inventory.player_snapshot("player.0").get("cash", -1))
		var rng_before := JSON.stringify(coordinator.run_rng_service().debug_snapshot())
		var market := coordinator.get_node_or_null("ProductMarketRuntimeController")
		var market_before := JSON.stringify(market.public_market_snapshot()) if market != null else ""
		var item_debug: Dictionary = item_node.call("debug_snapshot") as Dictionary if item_node != null else {}
		_check(item_node != null and item_node.find_children("*", "Button", true, false).is_empty(), "source_card_has_no_claim_button")
		_check(bool(item_debug.get("illustration_active", false)), "source_card_renders_authored_commodity_art")
		if item_node != null:
			await _click_control(item_node as Control)
		await _wait_for_rendered_count(track, initial_rendered_count - 1, 12)
		var after_debug: Dictionary = track.debug_snapshot()
		_check(int(after_debug.get("claim_submission_count", 0)) == 1 \
			and int(after_debug.get("claim_result_success_count", 0)) == 1 \
			and int(after_debug.get("rendered_item_count", -1)) == initial_rendered_count - 1,
			"card_body_claim_refreshes_track_from_owner_snapshot_exactly_once:%s" % JSON.stringify(after_debug)
		)
		_check(int(inventory.player_snapshot("player.0").get("cash", -2)) == cash_before, "free_claim_changes_no_cash")
		_check(JSON.stringify(coordinator.run_rng_service().debug_snapshot()) == rng_before and (market == null or JSON.stringify(market.public_market_snapshot()) == market_before), "claim_consumes_no_rng_and_does_not_refresh_market")
		_check(inspector_title != null and inspector_title.text == "公共商品", "claim_result_keeps_public_commodity_inspector_focus")
	var service_debug: Dictionary = service.debug_snapshot()
	_check(not bool(service_debug.get("owns_belt_state", true)) and not bool(service_debug.get("references_main", true)), "projection_has_no_second_owner_or_main_fallback")
	_check(not JSON.stringify(game_screen.current_ui_data).contains("654321") and not JSON.stringify(game_screen.current_ui_data).contains("PRIVATE_HAND") and not JSON.stringify(game_screen.current_ui_data).contains("PRIVATE_PLAN"), "rendered_table_contains_no_rival_private_state")
	var screenshot := await _capture_screenshot()
	_check(bool(screenshot.get("passed", false)), "headed_or_dummy_screenshot_contract")
	world.queue_free()
	return _finish(status_label, screenshot)


func _configure_presentation_dependencies(coordinator: GameRuntimeCoordinator) -> void:
	var card_presentation := coordinator.get_node_or_null("CardPresentationRuntimeService") as CardPresentationRuntimeService
	var table_viewmodel := coordinator.get_node_or_null("GameTableViewModelRuntimeService") as GameTableViewModelRuntimeService
	var eligibility := coordinator.get_node_or_null("CardPlayEligibilityRuntimeService") as CardPlayEligibilityRuntimeService
	var queue := coordinator.get_node_or_null("CardResolutionQueueRuntimeService") as CardResolutionQueueRuntimeService
	var history := coordinator.get_node_or_null("CardResolutionHistoryRuntimeService") as CardResolutionHistoryRuntimeService
	var resolution := coordinator.get_node_or_null("CardResolutionRuntimeController") as CardResolutionRuntimeController
	if card_presentation != null:
		card_presentation.configure({})
	if table_viewmodel != null:
		table_viewmodel.configure(card_presentation)
	if eligibility != null:
		eligibility.configure({"ruleset_id": "v0.6"})
	if queue != null:
		queue.configure({"ruleset_id": "v0.6", "card_group": preload("res://resources/rules/space_syndicate_ruleset_v06.tres").card_group_rules()})
	if history != null:
		history.configure({"history_limit": 24})
	if resolution != null:
		resolution.configure(preload("res://resources/rules/space_syndicate_ruleset_v06.tres").card_group_rules())


func _capture_screenshot() -> Dictionary:
	var display_name := DisplayServer.get_name().to_lower()
	var driver := RenderingServer.get_current_rendering_driver_name().to_lower()
	if display_name == "headless" or driver == "dummy":
		return {"passed": true, "mode": "dummy_renderer_skipped"}
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return {"passed": false, "reason": "viewport_image_unavailable"}
	var absolute_path := ProjectSettings.globalize_path(SCREENSHOT_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var error := image.save_png(absolute_path)
	return {"passed": error == OK and FileAccess.file_exists(absolute_path), "path": absolute_path, "error": error}


func _safe_node_name(value: String) -> String:
	return value.replace(".", "_").replace(":", "_").replace("/", "_")


func _hover_control(control: Control) -> void:
	if control == null:
		return
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	get_viewport().push_input(motion, true)
	await get_tree().process_frame


func _click_control(control: Control) -> void:
	if control == null:
		return
	var point := control.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		get_viewport().push_input(event, true)
		await get_tree().process_frame


func _wait_for_rendered_count(track: Node, expected_count: int, max_frames: int) -> void:
	for _frame in range(maxi(1, max_frames)):
		var state: Dictionary = track.debug_snapshot() if track != null and track.has_method("debug_snapshot") else {}
		if int(state.get("rendered_item_count", -1)) == expected_count:
			return
		await get_tree().process_frame


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish(status_label: Label, screenshot: Dictionary = {}) -> Dictionary:
	var result := {
		"passed": _failures.is_empty(),
		"checks": _checks,
		"failures": _failures.duplicate(),
		"screenshot": screenshot.duplicate(true),
	}
	last_result = result.duplicate(true)
	_running = false
	if status_label != null:
		status_label.text = "PASS %d/%d" % [_checks - _failures.size(), _checks] if _failures.is_empty() else "FAIL %d/%d" % [_checks - _failures.size(), _checks]
	print("TOP_COMMODITY_SUSHI_TRACK_PRODUCTION_WIRING_BENCH|status=%s|checks=%d|failures=%d|details=%s" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size(), JSON.stringify(_failures)])
	return result
