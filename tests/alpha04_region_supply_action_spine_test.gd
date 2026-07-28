extends SceneTree

const SESSION_DRIVER := preload("res://tests/support/production_session_start_driver.gd")
const ENVELOPE := preload("res://scripts/presentation/district_supply_presentation_envelope_v1.gd")
const QA_SAVE_PATH := "user://test_runs/alpha04_region_supply_action_spine.save"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1600, 960)
	var start := await SESSION_DRIVER.start_configured_session(
		self,
		{
			"player_count": 3,
			"ai_player_count": 2,
			"challenge_depth": 1,
			"role_indices": [0, 1, 2],
			"starter_monster_indices": [0, 1, 2],
		},
		QA_SAVE_PATH,
		"alpha04-region-supply-action-spine"
	)
	var app_root := start.get("main_root") as Node
	var coordinator := start.get("coordinator") as GameRuntimeCoordinator
	_expect(bool(start.get("started", false)) and app_root != null and coordinator != null, "production session starts")
	if app_root == null or coordinator == null:
		_finish()
		return
	coordinator.pause_session()
	await process_frame
	var screen := app_root.find_child("RuntimeGameScreen", true, false) as SpaceSyndicateGameScreen
	var query := coordinator.get_node_or_null("DistrictSupplyViewerQueryPort") as DistrictSupplyViewerQueryPort
	var viewmodel := coordinator.get_node_or_null("TablePresentationViewModelQuery") as TablePresentationViewModelQuery
	var query_ports := coordinator.get_node_or_null("TablePresentationQueryPorts") as TablePresentationQueryPorts
	var action_port := coordinator.district_supply_action_port()
	var flow := coordinator.get_node_or_null("TablePlayerActionApplicationFlowController") as TablePlayerActionApplicationFlowController
	var rng := coordinator.run_rng_service()
	_expect(screen != null and query != null and viewmodel != null and query_ports != null \
		and action_port != null and flow != null and rng != null, "production typed source, popup target, action flow and owners are composed")
	if screen == null or query == null or viewmodel == null or query_ports == null \
			or action_port == null or flow == null or rng == null:
		app_root.queue_free()
		await process_frame
		_finish()
		return
	var context := query_ports.viewer_context()
	screen.bind_presentation_viewer(0, context.authorization_revision)
	var table_state := viewmodel.compose_table_state(0, true)
	screen.apply_state(table_state)
	var district_index := _first_purchasable_district(coordinator)
	_expect(district_index >= 0, "one real public rack is purchasable for the focused interaction")
	if district_index < 0:
		app_root.queue_free()
		await process_frame
		_finish()
		return
	var world := coordinator.world_session_state()
	var district := world.districts[district_index] as Dictionary
	var region_id := str(district.get("region_id", ""))
	var rack_before := coordinator.region_supply_rack_revision(region_id)
	var rng_before := rng.capture_plan_checkpoint()
	var action_before := action_port.debug_snapshot()
	var flow_before := flow.debug_snapshot()
	_expect(screen.request_district_supply_open(district_index, &"qa_driver"), "map-selected rack open submits a projected typed offer")
	await _wait_frames(2)
	var action_after_open := action_port.debug_snapshot()
	var flow_after_open := flow.debug_snapshot()
	_expect(int(action_after_open.get("accepted_count", 0)) == int(action_before.get("accepted_count", 0)) + 1, "open reaches DistrictSupplyActionPort exactly once through the adapter")
	_expect(int(flow_after_open.get("accepted_count", 0)) == int(flow_before.get("accepted_count", 0)) + 1, "open crosses the shared GameAction application flow exactly once")
	var surface := query.snapshot_for_viewer(0)
	_expect(bool(ENVELOPE.validation_report(surface).get("valid", false)), "query returns the exact eleven-field typed presentation envelope|validation=%s surface=%s query=%s snapshot=%s" % [
		JSON.stringify(ENVELOPE.validation_report(surface)),
		JSON.stringify(surface),
		JSON.stringify(query.debug_snapshot()),
		JSON.stringify((coordinator.get_node_or_null("DistrictSupplySnapshotService") as DistrictSupplySnapshotService).debug_snapshot()),
	])
	_expect(screen.region_supply_popup.apply_presentation(surface, 0, context.authorization_revision), "production RegionSupplyPopup accepts its bound viewer envelope")
	var popup := screen.region_supply_popup
	var popup_debug := popup.presentation_target_snapshot()
	_expect(popup.visible and int(popup_debug.get("rendered_card_count", 0)) > 0, "real rack cards render in the production popup")
	_expect(coordinator.region_supply_rack_revision(region_id) == rack_before \
		and rng.capture_plan_checkpoint() == rng_before, "opening and rendering mutate neither rack revision nor RunRngService")
	var card_ids: Array = popup_debug.get("rendered_card_names", []) if popup_debug.get("rendered_card_names", []) is Array else []
	var first_card := str(card_ids[0]) if not card_ids.is_empty() else ""
	var action_before_hover := action_port.debug_snapshot()
	popup.call("_on_card_preview_requested", first_card, "hover")
	_expect(action_port.debug_snapshot() == action_before_hover \
		and coordinator.region_supply_rack_revision(region_id) == rack_before \
		and rng.capture_plan_checkpoint() == rng_before, "hover is passive and leaves action owner, rack and RNG unchanged")
	var action_before_quote := action_port.debug_snapshot()
	_expect(popup.request_card_quote(first_card), "explicit card selection emits the projected quote offer")
	await _wait_frames(2)
	var action_after_quote := action_port.debug_snapshot()
	_expect(int(action_after_quote.get("accepted_count", 0)) == int(action_before_quote.get("accepted_count", 0)) + 1, "quote reaches the authoritative port once")
	_expect(coordinator.region_supply_rack_revision(region_id) == rack_before \
		and rng.capture_plan_checkpoint() == rng_before, "quote changes no rack slot and consumes no rules RNG")
	var action_before_close := action_port.debug_snapshot()
	_expect(popup.close_popup(), "close emits the typed close offer")
	_expect(not popup.visible and not popup.close_popup(), "one close request hides the popup immediately and rejects a duplicate click")
	await _wait_frames(2)
	_expect(int(action_port.debug_snapshot().get("accepted_count", 0)) == int(action_before_close.get("accepted_count", 0)) + 1, "close reaches the authoritative port once")
	_expect(coordinator.region_supply_rack_revision(region_id) == rack_before \
		and rng.capture_plan_checkpoint() == rng_before, "close changes neither rack revision nor RNG")
	_expect(not FileAccess.get_file_as_string("res://scripts/ui/game_screen.gd").contains("district_supply_action_intent_requested") \
		and not FileAccess.get_file_as_string("res://scripts/ui/table/region_supply_popup.gd").contains("supply_action_requested.emit"), "production UI contains no parallel district-supply submission path")
	_stop_audio(app_root)
	app_root.queue_free()
	await process_frame
	_finish()


func _first_purchasable_district(coordinator: GameRuntimeCoordinator) -> int:
	var world := coordinator.world_session_state()
	if world == null:
		return -1
	for district_index in range(world.districts.size()):
		var district := world.districts[district_index] as Dictionary
		var region_id := str(district.get("region_id", ""))
		if not coordinator.region_supply_card_ids(region_id).is_empty() \
				and bool(coordinator.card_market_listing_availability(district_index).get("purchasable", false)):
			return district_index
	return -1


func _wait_frames(count: int) -> void:
	for _index in range(maxi(1, count)):
		await process_frame


func _stop_audio(root_node: Node) -> void:
	for node in root_node.find_children("*", "AudioStreamPlayer", true, false):
		(node as AudioStreamPlayer).stop()


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("ALPHA04_REGION_SUPPLY_ACTION_SPINE_TEST|status=%s|checks=%d|failures=%d" % [status, _checks, _failures.size()])
	for failure in _failures:
		push_error("ALPHA04_REGION_SUPPLY_ACTION_SPINE_TEST: %s" % failure)
	quit(0 if _failures.is_empty() else 1)
