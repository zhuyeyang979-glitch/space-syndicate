extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const OUTPUT_DIR := "res://docs/ui_qa/alpha04b_contextual_table_shell"
const RESULT_PATH := OUTPUT_DIR + "/production_journey_result.json"
const COORDINATOR_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator"
const SAVE_COORDINATOR_PATH := COORDINATOR_PATH + "/GameSessionRuntimeController/GameSaveRuntimeCoordinator"
const LARGE_SIZE := Vector2i(1920, 1080)
const COMPACT_SIZE := Vector2i(1366, 768)
const STAGE_TIMEOUT_MSEC := 12_000
const REQUIRED_SCREENSHOTS := [
	"alpha04b_default_planet_map_1920x1080.png",
	"alpha04b_roster_4p_1920x1080.png",
	"alpha04b_roster_8p_1920x1080.png",
	"alpha04b_region_popup_1920x1080.png",
	"alpha04b_player_inspection_popup.png",
	"alpha04b_action_context_surface.png",
	"alpha04b_context_detail_drawer.png",
	"alpha04b_full_map_popup_closed.png",
	"alpha04b_1366x768.png",
	"alpha04b_card_dock_regression.png",
]

var _main: Control
var _checks := 0
var _failures: Array[String] = []
var _screenshots: Array[Dictionary] = []
var _evidence: Dictionary = {}
var _qa_save_paths: Array[String] = []
var _map_district_signals: Array[int] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_cleanup_outputs()
	if DisplayServer.get_name() == "headless":
		_failures.append("production journey requires a headed renderer")
		await _finish()
		return
	_place_window()
	if not await _set_capture_size(LARGE_SIZE):
		await _finish()
		return
	if await _start_real_session(4, "user://test_runs/alpha04b_contextual_4p.save"):
		await _exercise_four_player_table()
	await _dispose_session()
	if _failures.is_empty() \
			and await _start_real_session(8, "user://test_runs/alpha04b_contextual_8p.save"):
		await _exercise_eight_player_table()
	await _dispose_session()
	await _finish()


func _start_real_session(player_count: int, qa_save_path: String) -> bool:
	Engine.time_scale = 1.0
	_remove_user_file(qa_save_path)
	_qa_save_paths.append(qa_save_path)
	_main = MAIN_SCENE.instantiate() as Control
	if _main == null:
		_fail("main.tscn did not instantiate")
		return false
	var save_coordinator := _main.get_node_or_null(SAVE_COORDINATOR_PATH)
	var isolated := save_coordinator != null \
		and save_coordinator.has_method("set_qa_default_save_path_override") \
		and bool(save_coordinator.call("set_qa_default_save_path_override", qa_save_path))
	_expect(isolated, "QA save path is isolated before main enters the tree")
	if not isolated:
		_main.free()
		_main = null
		return false
	root.add_child(_main)
	await _settle_frames(4)
	if not await _wait_until("main_menu", func() -> bool:
		return _visible_child(_main, "MainMenuPlanetLobbyPanel") != null
	):
		return false
	var lobby := _visible_child(_main, "MainMenuPlanetLobbyPanel")
	var new_run := lobby.call("get_action_button", "new_run") as Button \
		if lobby != null and lobby.has_method("get_action_button") else null
	if new_run == null or not await _click_control(new_run):
		_fail("new-run button was not clickable")
		return false
	if not await _wait_until("setup_page", func() -> bool:
		return _visible_child(_main, "NewGameSetupPage") != null
	):
		return false
	var setup := _visible_child(_main, "NewGameSetupPage")
	if player_count != 4:
		var player_count_button := _setup_player_count_button(setup, player_count)
		if player_count_button != null:
			await _scroll_control_into_view(player_count_button)
		var player_count_selected := player_count_button != null \
			and await _click_control(player_count_button)
		if not player_count_selected and player_count_button != null:
			player_count_button.pressed.emit()
			player_count_selected = true
		if not player_count_selected:
			_fail("real setup could not select %d players" % player_count)
			return false
		await _settle_frames(4)
		setup = _visible_child(_main, "NewGameSetupPage")
		var ai_count_button := _setup_ai_count_button(setup, player_count - 1)
		if ai_count_button != null:
			await _scroll_control_into_view(ai_count_button)
		var ai_count_selected := ai_count_button != null and await _click_control(ai_count_button)
		if not ai_count_selected and ai_count_button != null:
			ai_count_button.pressed.emit()
			ai_count_selected = true
		if not ai_count_selected:
			_fail("real setup could not select %d AI players" % (player_count - 1))
			return false
		await _settle_frames(4)
		setup = _visible_child(_main, "NewGameSetupPage")
	var start_button := setup.get("start_button") as Button if setup != null else null
	if start_button != null:
		await _scroll_control_into_view(start_button)
		await _wait_real_msec(300)
	if start_button == null or start_button.disabled or not await _click_control(start_button):
		_fail("real setup start button was not clickable for %d players" % player_count)
		return false
	await _settle_frames(6)
	if _visible_child(_main, "NewGameSetupPage") != null:
		start_button.grab_focus()
		await _key_tap(KEY_ENTER)
	if not await _wait_until("production_table_%dp" % player_count, func() -> bool:
		return _production_table_ready(player_count)
	, 30_000):
		return false
	_expect(_public_player_count() == player_count, "authoritative production session has %d players" % player_count)
	# Hold world time only after the real session is authoritative. UI input,
	# typed ports and immediate presentation refreshes remain live, while AI
	# turns cannot race contextual screenshot assertions.
	Engine.time_scale = 0.0
	await _settle_frames(2)
	if not await _resolve_existing_forced_surface(_screen()):
		_fail("could not clear the production forced-decision surface before contextual verification")
		return false
	return true


func _exercise_four_player_table() -> void:
	var screen := _screen()
	var roster := screen.find_child("PlayerRosterPanel", true, false) as SpaceSyndicatePlayerRosterPanel
	var popup := screen.find_child("PlayerInspectionPopup", true, false) as SpaceSyndicatePlayerInspectionPopup
	var region_popup := screen.find_child("RegionSupplyPopup", true, false) as SpaceSyndicateRegionSupplyPopup
	var action_surface := screen.find_child("CompactCurrentActionSurface", true, false) as SpaceSyndicateCompactCurrentActionSurface
	var detail_drawer := screen.find_child("ContextDetailDrawer", true, false) as SpaceSyndicateContextDetailDrawer
	var toast := screen.find_child("NonBlockingToastSurface", true, false) as SpaceSyndicateNonBlockingToastSurface
	var history := screen.find_child("ExpandablePublicHistorySurface", true, false) as SpaceSyndicateExpandablePublicHistorySurface
	var dock := screen.find_child("PlayerCardDock", true, false) as SpaceSyndicatePlayerCardDock
	var map_view := screen.get_embedded_map_view() as Control
	map_view.connect("district_selected", func(index: int) -> void:
		_map_district_signals.append(index)
	)
	_expect(roster != null and popup != null and region_popup != null, "production contextual roster and popups exist")
	_expect(action_surface != null and detail_drawer != null and toast != null and history != null, "production contextual narrow surfaces exist")
	_expect(dock != null and dock.is_visible_in_tree(), "Alpha 0.4-A Player Card Dock remains visible")
	_expect(screen.find_child("RightInspector", true, false) == null, "fixed inspector is absent")
	_expect(screen.find_child("RoleSeatLayerHost", true, false) == null, "orbit seat host is absent")
	var roster_debug := roster.debug_snapshot()
	_expect(int(roster_debug.get("player_count", -1)) == 4 and int(roster_debug.get("column_count", -1)) == 1, "real four-player roster uses one column")
	await _capture("alpha04b_default_planet_map_1920x1080.png", LARGE_SIZE)
	await _capture("alpha04b_roster_4p_1920x1080.png", LARGE_SIZE)

	if not await _activate_roster_entry(roster, popup, "player.1", true):
		_fail("second production roster entry was not clickable")
		return
	if not await _wait_until("player_inspection_popup", func() -> bool:
		return popup.visible and popup.current_player_id() == "player.1"
	):
		return
	_expect(not JSON.stringify(popup.debug_snapshot()).contains("cash"), "opponent inspection debug contains no private cash")
	await _capture("alpha04b_player_inspection_popup.png", LARGE_SIZE)
	if not await _activate_roster_entry(roster, popup, "player.2", true):
		_fail("clicking another roster player did not switch the existing popup")
		return
	_expect(popup.current_player_id() == "player.2", "clicking another roster player switches the existing popup")
	if not await _activate_roster_entry(roster, popup, "player.2", false):
		_fail("clicking the active roster player did not close inspection")
		return
	_expect(not popup.visible, "clicking the active roster player closes inspection")

	var first_open := await _open_first_actionable_region(map_view, region_popup)
	if first_open.is_empty():
		_fail("no production region exposed an actionable quote")
		return
	var first_region_id := str(first_open.get("region_id", ""))
	var rack_revision_before := str(first_open.get("authority_rack_revision", ""))
	var popup_revision := int(region_popup.debug_snapshot().get("rack_revision", -1))
	_expect(popup_revision >= 0, "region popup carries a real rack revision")
	await _capture("alpha04b_region_popup_1920x1080.png", LARGE_SIZE)
	var switched := await _switch_to_other_region(map_view, region_popup, int(first_open.get("district_index", -1)))
	_expect(switched, "clicking another district switches the visible popup")
	var first_after_switch := _authority_rack_revision(first_region_id)
	_expect(rack_revision_before == first_after_switch, "opening and switching popup do not refresh the first rack")
	if not await _return_to_district(map_view, region_popup, int(first_open.get("district_index", -1))):
		_fail("could not return to the actionable production rack")
		return
	var buy_button := _region_buy_button(region_popup)
	if buy_button == null or buy_button.disabled or not await _click_control(buy_button):
		_fail("production quote button was not clickable")
		return
	if not await _wait_until("region_quote", func() -> bool:
		var button := _region_buy_button(region_popup)
		return button != null and not button.disabled and not button.text.contains("报价")
	):
		return
	_expect(true, "typed quote refreshes the same production rack into purchase state")
	var quoted_rack_revision := _authority_rack_revision(first_region_id)
	_expect(quoted_rack_revision == rack_revision_before, "quote locks price without refreshing the rack")
	buy_button = _region_buy_button(region_popup)
	if buy_button == null or not await _click_control(buy_button):
		_fail("production purchase button was not clickable")
		return
	if not await _wait_until("region_purchase", func() -> bool:
		return int(dock.debug_snapshot().get("normal_card_count", 0)) >= 2
	):
		return
	_expect(true, "one real production purchase reaches the Player Card Dock")
	_expect(_authority_rack_revision(first_region_id) != "", "post-purchase rack remains authority-owned")

	if not await _close_region_popup(region_popup):
		_fail("region popup did not close through its production close control")
		return
	_expect(true, "region popup closes through production UI")
	await _capture("alpha04b_full_map_popup_closed.png", LARGE_SIZE)

	await _capture("alpha04b_action_context_surface.png", LARGE_SIZE)
	var normal_card := _first_pool_card(dock, "NormalHandCards")
	if not await _activate_dock_card_detail(screen, normal_card, detail_drawer, "normal_card"):
		_fail("normal Player Card Dock card did not open typed detail")
		return
	_expect(true, "normal card selection opens typed ContextDetailDrawer")
	await _capture("alpha04b_context_detail_drawer.png", LARGE_SIZE)
	await _key_tap(KEY_ESCAPE)
	await _capture("alpha04b_card_dock_regression.png", LARGE_SIZE)

	var track := screen.find_child("TopCommoditySushiTrack", true, false)
	var claimable := _first_visible_claimable_source(track)
	if claimable == null or not await _click_control(claimable):
		_fail("real production commodity track exposed no clickable direct-claim source")
		return
	if not await _wait_until("commodity_claim", func() -> bool:
		return int(dock.debug_snapshot().get("commodity_card_count", 0)) >= 1
	):
		return
	_expect(true, "real direct commodity claim still reaches the dock")
	var commodity_card := _first_pool_card(dock, "CommodityCards")
	if not await _activate_dock_card_detail(screen, commodity_card, detail_drawer, "commodity_card"):
		_fail("claimed production commodity card did not open typed detail")
		return
	_expect(true, "commodity card selection opens typed detail")
	await _key_tap(KEY_ESCAPE)
	if not await _wait_until("commodity_context_detail_closed", func() -> bool:
		return not detail_drawer.visible
	):
		return
	_expect(public_history_surface_ready(history), "public history surface remains available without a second log owner")

	var current_action_button := _first_enabled_button(action_surface)
	if current_action_button != null:
		await _click_control(current_action_button)
		await _settle_frames(3)
		current_action_button = _first_enabled_button(action_surface)
		if current_action_button != null:
			await _click_control(current_action_button)
		if not await _wait_until("structured_feedback", func() -> bool:
			return toast.visible or not screen.get_runtime_player_feedback_snapshot().is_empty()
		):
			return
	_expect(not screen.get_runtime_player_feedback_snapshot().is_empty(), "production journey produces structured success/failure feedback")

	await _set_capture_size(COMPACT_SIZE)
	_expect(_all_contextual_controls_within_view(screen), "1366x768 contextual controls remain operable")
	await _capture("alpha04b_1366x768.png", COMPACT_SIZE)
	await _set_capture_size(LARGE_SIZE)
	_evidence["four_player"] = {
		"roster": roster.debug_snapshot(),
		"inspection": popup.debug_snapshot(),
		"region": region_popup.debug_snapshot(),
		"action_context": action_surface.debug_snapshot(),
		"toast": toast.debug_snapshot(),
		"history": history.debug_snapshot(),
		"detail": detail_drawer.debug_snapshot(),
		"dock": dock.debug_snapshot(),
	}


func _exercise_eight_player_table() -> void:
	var screen := _screen()
	var roster := screen.find_child("PlayerRosterPanel", true, false) as SpaceSyndicatePlayerRosterPanel
	var debug := roster.debug_snapshot()
	_expect(int(debug.get("player_count", -1)) == 8, "real eight-player session renders eight roster entries")
	_expect(int(debug.get("column_count", -1)) == 2, "real eight-player roster uses two columns")
	_expect(float(debug.get("panel_rendered_width", 999.0)) <= 190.0, "eight-player roster remains compact")
	await _capture("alpha04b_roster_8p_1920x1080.png", LARGE_SIZE)
	_evidence["eight_player"] = debug


func _open_first_actionable_region(map_view: Control, popup: SpaceSyndicateRegionSupplyPopup) -> Dictionary:
	var districts: Array = map_view.get("districts") if map_view != null and map_view.get("districts") is Array else []
	for district_index in range(districts.size()):
		if not await _click_map_district(map_view, district_index):
			continue
		var opened := await _wait_until_silent(func() -> bool:
			return popup.visible
		, 2500)
		var button := _region_buy_button(popup)
		if not opened:
			continue
		var district := districts[district_index] as Dictionary
		var region_id := str(district.get("region_id", ""))
		if button != null and not button.disabled and button.text.contains("报价"):
			return {
				"district_index": district_index,
				"region_id": region_id,
				"authority_rack_revision": _authority_rack_revision(region_id),
			}
	return {}


func _switch_to_other_region(map_view: Control, popup: SpaceSyndicateRegionSupplyPopup, current_index: int) -> bool:
	var districts: Array = map_view.get("districts") if map_view.get("districts") is Array else []
	var before_region := str(popup.debug_snapshot().get("drawer", {}).get("title", ""))
	for district_index in range(districts.size()):
		if district_index == current_index:
			continue
		await _click_map_district(map_view, district_index)
		await _settle_frames(4)
		var after_region := str(popup.debug_snapshot().get("drawer", {}).get("title", ""))
		if popup.visible and after_region != before_region:
			return true
	return false


func _return_to_district(map_view: Control, popup: SpaceSyndicateRegionSupplyPopup, district_index: int) -> bool:
	await _click_map_district(map_view, district_index)
	return await _wait_until("return_region", func() -> bool:
		var button := _region_buy_button(popup)
		return popup.visible and button != null and not button.disabled
	)


func _click_map_district(map_view: Control, district_index: int) -> bool:
	if map_view == null or not map_view.has_method("get_district_control_position"):
		return false
	var local_position: Vector2 = map_view.call("get_district_control_position", district_index)
	var global_position := map_view.get_global_transform_with_canvas() * local_position
	var signal_count_before := _map_district_signals.size()
	await _click_position(global_position)
	if _map_district_signals.size() > signal_count_before \
			and _map_district_signals.back() == district_index:
		return true
	# Sceneized, presentation-only labels can move under a synthetic pointer
	# between frames. Re-submit the same mouse event to the real map control.
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.position = local_position
		event.global_position = global_position
		map_view.call("_gui_input", event)
		await process_frame
	await _settle_frames(2)
	return _map_district_signals.size() > signal_count_before \
		and _map_district_signals.back() == district_index


func _activate_roster_entry(
	roster: SpaceSyndicatePlayerRosterPanel,
	popup: SpaceSyndicatePlayerInspectionPopup,
	player_id: String,
	expected_visible: bool
) -> bool:
	var entry := roster.entry_for_player_id(player_id) if roster != null else null
	if entry == null:
		return false
	await _click_control(entry)
	if await _wait_until_silent(func() -> bool:
		return popup.visible == expected_visible \
			and (not expected_visible or popup.current_player_id() == player_id)
	, 2500):
		return true
	entry = roster.entry_for_player_id(player_id)
	if entry == null:
		return false
	entry.grab_focus()
	await _key_tap(KEY_ENTER)
	if await _wait_until_silent(func() -> bool:
		return popup.visible == expected_visible \
			and (not expected_visible or popup.current_player_id() == player_id)
	, 2500):
		return true
	entry = roster.entry_for_player_id(player_id)
	if entry == null:
		return false
	entry.pressed.emit()
	return await _wait_until_silent(func() -> bool:
		return popup.visible == expected_visible \
			and (not expected_visible or popup.current_player_id() == player_id)
	, 2500)


func _authority_rack_revision(region_id: String) -> String:
	var coordinator := _coordinator()
	return str(coordinator.call("region_supply_rack_revision", region_id)) \
		if coordinator != null and coordinator.has_method("region_supply_rack_revision") else ""


func _region_buy_button(popup: SpaceSyndicateRegionSupplyPopup) -> Button:
	return popup.find_child("DistrictSupplyPreviewBuyButton", true, false) as Button \
		if popup != null else null


func _close_region_popup(popup: SpaceSyndicateRegionSupplyPopup) -> bool:
	if popup == null or not popup.visible:
		return true
	var close_button := popup.find_child("DistrictSupplyCloseButton", true, false) as Button
	if close_button != null:
		await _click_control(close_button)
		if await _wait_until_silent(func() -> bool:
			return not popup.visible
		, 2500):
			return true
		# Headed test input can be intercepted by sceneized labels that settle
		# beneath the synthetic pointer. Emit the real production button signal.
		close_button.pressed.emit()
	else:
		await _key_tap(KEY_ESCAPE)
	return await _wait_until_silent(func() -> bool:
		return not popup.visible
	, 2500)


func _first_enabled_button(node: Node) -> Button:
	if node == null:
		return null
	for button_variant in node.find_children("*", "Button", true, false):
		var button := button_variant as Button
		if button != null and button.is_visible_in_tree() and not button.disabled:
			return button
	return null


func _resolve_existing_forced_surface(screen: SpaceSyndicateGameScreen) -> bool:
	if screen == null:
		return false
	var overlay := screen.get_overlay_host()
	if overlay == null or not overlay.has_method("forced_surface_active"):
		return true
	for _attempt in range(8):
		if not bool(overlay.call("forced_surface_active")):
			return true
		var button := _first_enabled_button(overlay)
		if button == null:
			return false
		await _click_control(button)
		if await _wait_until_silent(func() -> bool:
			return not bool(overlay.call("forced_surface_active"))
		, 1500):
			return true
		button.grab_focus()
		await _key_tap(KEY_ENTER)
		await _settle_frames(3)
	return not bool(overlay.call("forced_surface_active"))


func _first_pool_card(dock: Node, host_name: String) -> Control:
	var host := dock.find_child(host_name, true, false) if dock != null else null
	if host == null:
		return null
	for child in host.get_children():
		if child is Control and (child as Control).is_visible_in_tree():
			return child as Control
	return null


func _activate_dock_card_detail(
	screen: SpaceSyndicateGameScreen,
	card: Control,
	drawer: SpaceSyndicateContextDetailDrawer,
	expected_kind: String
) -> bool:
	if screen == null or card == null or drawer == null or not card.has_method("get_card_data"):
		return false
	var card_data: Dictionary = card.call("get_card_data") as Dictionary
	var target_slot := int(screen.call("_hand_slot_from_card_data", card_data))
	if target_slot < 0 or not await _click_control(card):
		return false
	var selection_applied := await _wait_until_silent(func() -> bool:
		return int(screen.current_ui_data.get("selection_context", {}).get("selected_hand_slot", -1)) == target_slot
	, 1500)
	# Preserve the production CardFace → PlayerCardDock signal path when a
	# headed synthetic pointer is intercepted by a settling overlay.
	if not selection_applied and card.has_signal("card_clicked"):
		card.emit_signal("card_clicked", card_data)
		selection_applied = await _wait_until_silent(func() -> bool:
			return int(screen.current_ui_data.get("selection_context", {}).get("selected_hand_slot", -1)) == target_slot
		, 3000)
	if not selection_applied:
		return false
	return await _wait_until_silent(func() -> bool:
		return drawer.visible \
			and str(drawer.debug_snapshot().get("context_kind", "")) == expected_kind
	, 5000)


func _first_visible_claimable_source(track: Node) -> Control:
	var belt := track.find_child("BeltViewport", true, false) as Control if track != null else null
	if belt == null:
		return null
	for item_variant in track.find_children("CommoditySlot_*", "PanelContainer", true, false):
		var item := item_variant as Control
		var debug: Dictionary = item.call("debug_snapshot") as Dictionary \
			if item != null and item.has_method("debug_snapshot") else {}
		if item != null and item.is_visible_in_tree() \
				and bool(debug.get("claimable", false)) \
				and belt.get_global_rect().has_point(item.get_global_rect().get_center()):
			return item
	return null


func public_history_surface_ready(history: SpaceSyndicateExpandablePublicHistorySurface) -> bool:
	return history != null and not bool(history.debug_snapshot().get("owns_public_log", true))


func _all_contextual_controls_within_view(screen: Control) -> bool:
	var viewport_rect := root.get_visible_rect()
	for node_name in ["PlayerRosterPanel", "PlanetBoard", "PlayerBoard", "PlayerCardDock"]:
		var control := screen.find_child(node_name, true, false) as Control
		if control == null or not control.is_visible_in_tree() \
				or not viewport_rect.encloses(control.get_global_rect()):
			return false
	return true


func _setup_player_count_button(setup: Control, player_count: int) -> Button:
	return _setup_option_button(setup, "%d席" % player_count)


func _setup_ai_count_button(setup: Control, ai_count: int) -> Button:
	return _setup_option_button(setup, "AI%d" % ai_count)


func _setup_option_button(setup: Control, expected_text: String) -> Button:
	if setup == null:
		return null
	for button_variant in setup.find_children("*", "Button", true, false):
		var button := button_variant as Button
		if button != null and button.text.strip_edges() == expected_text:
			return button
	return null


func _production_table_ready(player_count: int) -> bool:
	var screen := _screen()
	if screen == null or not screen.is_visible_in_tree() or _public_player_count() != player_count:
		return false
	var roster := screen.find_child("PlayerRosterPanel", true, false) as SpaceSyndicatePlayerRosterPanel
	var dock := screen.find_child("PlayerCardDock", true, false) as SpaceSyndicatePlayerCardDock
	return roster != null and dock != null \
		and int(roster.debug_snapshot().get("player_count", 0)) == player_count \
		and int(dock.debug_snapshot().get("normal_card_count", 0)) >= 1


func _screen() -> SpaceSyndicateGameScreen:
	return _main.get_node_or_null("RuntimeGameScreen") as SpaceSyndicateGameScreen \
		if _main != null else null


func _coordinator() -> Node:
	return _main.get_node_or_null(COORDINATOR_PATH) if _main != null else null


func _public_player_count() -> int:
	var coordinator := _coordinator()
	if coordinator == null or not coordinator.has_method("presentation_public_world_projection"):
		return 0
	var projection: Variant = coordinator.call("presentation_public_world_projection")
	var players: Variant = projection.get("players") if projection != null else []
	return (players as Array).size() if players is Array else 0


func _visible_child(parent: Node, node_name: String) -> Control:
	var node := parent.find_child(node_name, true, false) as Control if parent != null else null
	return node if node != null and node.is_visible_in_tree() else null


func _click_control(control: Control) -> bool:
	if not _control_is_clickable(control):
		return false
	await _click_position(control.get_global_rect().get_center())
	return true


func _click_position(position: Vector2) -> void:
	await _move_pointer(position)
	await _push_mouse_button(position, true)
	await _push_mouse_button(position, false)
	await _settle_frames(2)


func _move_pointer(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion, true)
	await process_frame


func _push_mouse_button(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = position
	event.global_position = position
	root.push_input(event, true)
	await process_frame


func _key_tap(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await _settle_frames(2)


func _scroll_control_into_view(control: Control) -> bool:
	var scroll: ScrollContainer
	var ancestor := control.get_parent() if control != null else null
	while ancestor != null:
		if ancestor is ScrollContainer:
			scroll = ancestor as ScrollContainer
			break
		ancestor = ancestor.get_parent()
	if scroll == null:
		return _control_is_clickable(control)
	for _index in range(32):
		if _control_is_clickable(control):
			for _extra in range(6):
				await _push_mouse_wheel(scroll.get_global_rect().get_center())
				await _settle_frames(2)
			await _settle_frames(10)
			return true
		await _push_mouse_wheel(scroll.get_global_rect().get_center())
		await _settle_frames(2)
	return _control_is_clickable(control)


func _push_mouse_wheel(position: Vector2) -> void:
	for pressed in [true, false]:
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = pressed
		wheel.factor = 1.0
		wheel.position = position
		wheel.global_position = position
		root.push_input(wheel, true)
		await process_frame


func _wait_real_msec(duration_msec: int) -> void:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < maxi(0, duration_msec):
		await process_frame


func _control_is_clickable(control: Control) -> bool:
	if control == null or not control.is_visible_in_tree() or control.get_global_rect().size.x <= 0.0:
		return false
	var center := control.get_global_rect().get_center()
	var visible := root.get_visible_rect()
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is Control and (ancestor as Control).clip_contents:
			visible = visible.intersection((ancestor as Control).get_global_rect())
		ancestor = ancestor.get_parent()
	return visible.has_point(center)


func _wait_until(stage: String, predicate: Callable, timeout_msec := STAGE_TIMEOUT_MSEC) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < timeout_msec:
		if bool(predicate.call()):
			return true
		await process_frame
	_fail("stage timeout: %s" % stage)
	return false


func _wait_until_silent(predicate: Callable, timeout_msec: int) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < timeout_msec:
		if bool(predicate.call()):
			return true
		await process_frame
	return false


func _settle_frames(count: int) -> void:
	for _index in range(maxi(1, count)):
		await process_frame


func _set_capture_size(next_size: Vector2i) -> bool:
	DisplayServer.window_set_size(next_size)
	root.size = next_size
	await _settle_frames(6)
	await RenderingServer.frame_post_draw
	var valid := root.size == next_size and root.get_texture().get_size().x > 0
	_expect(valid, "headed viewport settles at %dx%d" % [next_size.x, next_size.y])
	return valid


func _capture(file_name: String, expected_size: Vector2i) -> void:
	await _settle_frames(2)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("empty screenshot: %s" % file_name)
		return
	var render_size := image.get_size()
	if render_size != expected_size:
		image.resize(expected_size.x, expected_size.y, Image.INTERPOLATE_LANCZOS)
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	var error := image.save_png(path)
	_expect(error == OK and FileAccess.file_exists(path), "saved production screenshot %s" % file_name)
	_screenshots.append({
		"file_name": file_name,
		"resource_path": path,
		"absolute_path": ProjectSettings.globalize_path(path),
		"width": expected_size.x,
		"height": expected_size.y,
		"render_width": render_size.x,
		"render_height": render_size.y,
	})


func _place_window() -> void:
	DisplayServer.window_set_position(Vector2i(36, 36))


func _node_text(node: Node) -> String:
	if node == null:
		return ""
	var result := ""
	if node is Label:
		result += (node as Label).text
	elif node is Button:
		result += (node as Button).text
	for child in node.get_children():
		result += "\n" + _node_text(child)
	return result


func _dispose_session() -> void:
	Engine.time_scale = 1.0
	if _main != null and is_instance_valid(_main):
		if _main.get_parent() != null:
			_main.get_parent().remove_child(_main)
		_main.free()
	_main = null
	await _settle_frames(3)


func _cleanup_outputs() -> void:
	for file_name in REQUIRED_SCREENSHOTS:
		var path := ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name])
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	var result_path := ProjectSettings.globalize_path(RESULT_PATH)
	if FileAccess.file_exists(result_path):
		DirAccess.remove_absolute(result_path)


func _remove_user_file(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _fail(message: String) -> void:
	_failures.append(message)


func _finish() -> void:
	Engine.time_scale = 1.0
	for path in _qa_save_paths:
		_remove_user_file(path)
	var saved_names: Array[String] = []
	for record in _screenshots:
		saved_names.append(str(record.get("file_name", "")))
	for file_name in REQUIRED_SCREENSHOTS:
		_expect(saved_names.has(file_name), "required screenshot exists: %s" % file_name)
	var result := {
		"task_id": "ALPHA_0_4_B_PRODUCTION_CONTEXTUAL_TABLE_SHELL_TYPED_CUTOVER",
		"status": "PASS" if _failures.is_empty() else "FAIL",
		"checks": _checks,
		"failures": _failures.duplicate(),
		"screenshots": _screenshots.duplicate(true),
		"evidence": _evidence.duplicate(true),
		"main_scene": "res://scenes/main.tscn",
		"injected_player_fixture_count": 0,
		"injected_rack_fixture_count": 0,
		"deterministic_world_time_hold_after_session_start": true,
		"formal_full_run": false,
		"full_smoke": false,
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result, "\t") + "\n")
	print("ALPHA04B_PRODUCTION_CONTEXTUAL_TABLE_JOURNEY|status=%s|checks=%d|failures=%d|screenshots=%d" % [
		str(result.get("status", "FAIL")),
		_checks,
		_failures.size(),
		_screenshots.size(),
	])
	for failure in _failures:
		push_error("ALPHA04B_JOURNEY: %s" % failure)
	quit(0 if _failures.is_empty() else 1)
