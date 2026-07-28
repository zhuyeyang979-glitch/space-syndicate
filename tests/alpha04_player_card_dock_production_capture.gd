extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const DOCK_PROJECTION := preload("res://scripts/presentation/player_card_dock_projection_v1.gd")

const OUTPUT_DIR := "res://docs/ui_qa/alpha04_player_card_dock"
const RESULT_PATH := OUTPUT_DIR + "/production_capture_result.json"
const QA_SAVE_PATH := "user://test_runs/alpha04_player_card_dock_production_capture.save"
const PLAYER_DEFAULT_SAVE_PATH := "user://space_syndicate_current_run.save"
const SAVE_COORDINATOR_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController/GameSaveRuntimeCoordinator"
const COORDINATOR_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator"
const CLAIM_FLOW_PATH := "RuntimeServices/CommoditySushiTrackApplicationFlowController"
const CLAIM_SERVICE_PATH := COORDINATOR_PATH + "/CommoditySushiTrackRuntimeService"
const CAPTURE_SIZE_LARGE := Vector2i(1920, 1080)
const CAPTURE_SIZE_COMPACT := Vector2i(1366, 768)
const STAGE_TIMEOUT_MSEC := 10_000
const RAPID_INPUT_SETTLE_MSEC := 390

const REQUIRED_SCREENSHOTS: Array[String] = [
	"production_commodity_source_abstract_art.png",
	"production_commodity_hover.png",
	"production_commodity_single_click_claim.png",
	"production_commodity_inventory_art.png",
	"production_normal_and_commodity_cards.png",
	"production_commodity_claim_failure.png",
	"production_card_dock_1366x768.png",
	"production_card_dock_1920x1080.png",
]

const PERFORMANCE_FIELDS: Array[String] = [
	"commodity_source_render_p95",
	"commodity_inventory_render_p95",
	"commodity_hover_p95",
	"single_click_to_intent_p95",
	"receipt_to_inventory_refresh_p95",
]

var _checks := 0
var _failures: Array[String] = []
var _saved_file_names: Array[String] = []
var _screenshot_records: Array[Dictionary] = []
var _evidence: Dictionary = {}
var _main: Control
var _capture_size := CAPTURE_SIZE_LARGE
var _run_started_msec := 0
var _player_default_before: Dictionary = {}
var _start_debug: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_run_started_msec = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_cleanup_previous_capture_outputs()
	_cleanup_qa_save_artifacts()
	_player_default_before = _save_file_snapshot(PLAYER_DEFAULT_SAVE_PATH)
	if DisplayServer.get_name() == "headless":
		_fail("production capture requires a headed renderer")
		await _finish()
		return
	_place_capture_window()
	if not await _set_capture_size(CAPTURE_SIZE_LARGE):
		await _finish()
		return
	if await _start_real_session():
		await _run_capture_suite()
	await _finish()


func _start_real_session() -> bool:
	_main = MAIN_SCENE.instantiate() as Control
	if _main == null:
		_fail("real main.tscn did not instantiate")
		return false
	var save_coordinator := _main.get_node_or_null(SAVE_COORDINATOR_PATH)
	var save_override_ready := save_coordinator != null \
		and save_coordinator.has_method("set_qa_default_save_path_override") \
		and bool(save_coordinator.call("set_qa_default_save_path_override", QA_SAVE_PATH))
	_expect(save_override_ready, "isolated QA save path is installed before main enters the tree")
	if not save_override_ready:
		_main.free()
		_main = null
		return false
	var save_operation: Dictionary = save_coordinator.call("operation_snapshot") as Dictionary
	_expect(
		str(save_operation.get("default_save_path", "")) == QA_SAVE_PATH \
			and bool(save_operation.get("qa_save_path_override_active", false)),
		"save coordinator reports the pre-tree QA override"
	)
	root.add_child(_main)
	await _settle_frames(4)
	if not await _wait_until("main_menu_ready", func() -> bool:
		return _visible_child(_main, "MainMenuPlanetLobbyPanel") != null
	):
		return false
	var lobby := _visible_child(_main, "MainMenuPlanetLobbyPanel")
	var new_run := lobby.call("get_action_button", "new_run") as Button \
		if lobby != null and lobby.has_method("get_action_button") else null
	if new_run == null or not await _click_control(new_run):
		_fail("main-menu new_run button was not clickable through root viewport input")
		return false
	if not await _wait_until("new_game_setup_ready", func() -> bool:
		return _visible_child(_main, "NewGameSetupPage") != null
	):
		return false
	var setup := _visible_child(_main, "NewGameSetupPage")
	var start_button := setup.get("start_button") as Button if setup != null else null
	var scrolled_into_view := false
	if start_button != null:
		scrolled_into_view = await _scroll_control_into_view(start_button)
		await _wait_input_settle_msec(300)
		_start_debug = {
			"scrolled_into_view": scrolled_into_view,
			"button_rect": str(start_button.get_global_rect()),
			"button_visible": start_button.is_visible_in_tree(),
			"button_disabled": start_button.disabled,
			"visible_through_clippers": _control_visible_through_clippers(start_button),
			"hovered_before_click": _node_path(root.gui_get_hovered_control()),
			"gui_mouse_events": [],
			"button_down_count": 0,
			"button_up_count": 0,
			"pressed_count": 0,
		}
		start_button.gui_input.connect(_on_start_button_gui_input)
		start_button.button_down.connect(func() -> void:
			_start_debug["button_down_count"] = int(_start_debug.get("button_down_count", 0)) + 1
		)
		start_button.button_up.connect(func() -> void:
			_start_debug["button_up_count"] = int(_start_debug.get("button_up_count", 0)) + 1
		)
		start_button.pressed.connect(func() -> void:
			_start_debug["pressed_count"] = int(_start_debug.get("pressed_count", 0)) + 1
		)
	if start_button == null or start_button.disabled or not await _click_control(start_button):
		_fail("setup start button was not clickable through root viewport input")
		return false
	if not await _wait_until("production_table_ready", func() -> bool:
		return _production_table_ready()
	):
		var setup_flow := _main.get_node_or_null("RuntimeServices/SetupApplicationFlowController")
		print("PRODUCTION_TABLE_DEBUG %s" % JSON.stringify({
			"screen_present": _screen() != null,
			"screen_visible": _screen().is_visible_in_tree() if _screen() != null else false,
			"public_player_count": _public_player_count(_coordinator()),
			"track": _track_debug(_track()),
			"dock_projection": _dock_projection(_screen()) if _screen() != null else {},
			"setup_visible": _visible_child(_main, "NewGameSetupPage") != null,
			"lobby_visible": _visible_child(_main, "MainMenuPlanetLobbyPanel") != null,
			"start": _start_debug,
			"setup_flow": setup_flow.call("debug_snapshot") if setup_flow != null and setup_flow.has_method("debug_snapshot") else {},
			"hovered_after_click": _node_path(root.gui_get_hovered_control()),
			"focus_after_click": _node_path(root.gui_get_focus_owner()),
		}))
		return false
	_expect(_public_player_count(_coordinator()) == 4, "real setup click starts the default four-seat production session")
	return true


func _run_capture_suite() -> void:
	var screen := _screen()
	var track := _track()
	var dock := _dock()
	var claim_flow := _claim_flow()
	var claim_service := _claim_service()
	var planet_board := screen.find_child("PlanetBoard", true, false) as Control if screen != null else null
	var right_inspector := screen.find_child("RightInspector", true, false) as Control if screen != null else null
	if not _required_nodes_ready(screen, track, dock, claim_flow, claim_service, planet_board, right_inspector):
		return
	_assert_production_surface(screen, track, dock, CAPTURE_SIZE_LARGE, false)

	var first_source := _first_visible_claimable_source(track)
	if first_source == null:
		_fail("no visible claimable production commodity source card")
		return
	var first_debug := _item_debug(first_source)
	var first_slot_id := str(first_debug.get("slot_id", ""))
	var first_card_id := str(first_debug.get("card_id", ""))
	var first_illustration_key := str(first_debug.get("illustration_key", ""))
	_expect(
		bool(first_debug.get("illustration_active", false)) \
			and not bool(first_debug.get("illustration_fallback_active", true)) \
			and not first_illustration_key.is_empty(),
		"production source card renders authored commodity art without fallback"
	)
	await _capture("production_commodity_source_abstract_art.png", CAPTURE_SIZE_LARGE)

	await _hover_control(first_source)
	await _wait_until("commodity_hover_projection", func() -> bool:
		return str(_track_debug(track).get("selected_slot_id", "")) == first_slot_id
	)
	_expect(right_inspector.is_visible_in_tree(), "commodity hover keeps the real RightInspector visible")
	await _capture("production_commodity_hover.png", CAPTURE_SIZE_LARGE)

	var outside_before := _claim_state(screen, track, dock, claim_flow, claim_service)
	await _click_position(planet_board.get_global_rect().get_center())
	await _settle_frames(3)
	var outside_after := _claim_state(screen, track, dock, claim_flow, claim_service)
	_assert_no_claim_delta("map outside click", outside_before, outside_after)
	_expect(
		(outside_after.get("rendered_slot_ids", []) as Array).has(first_slot_id),
		"map outside click preserves the hovered commodity source item"
	)

	first_source = _source_by_slot(track, first_slot_id)
	if first_source == null:
		_fail("first source card disappeared before its real click")
		return
	await _hover_control(first_source)
	var single_before := _claim_state(screen, track, dock, claim_flow, claim_service)
	await _click_control(first_source)
	if not await _wait_for_claim_outcome(screen, track, dock, claim_flow, claim_service, single_before, true):
		return
	await _settle_frames(4)
	var single_after := _claim_state(screen, track, dock, claim_flow, claim_service)
	_assert_success_delta("single click", single_before, single_after, first_slot_id)
	_evidence["single_click"] = _delta_evidence(single_before, single_after)
	await _capture("production_commodity_single_click_claim.png", CAPTURE_SIZE_LARGE)

	await _wait_past_rapid_guard()
	if not await _resolve_forced_surfaces_through_ui(screen):
		return
	var double_source := _first_visible_claimable_source(track)
	if double_source == null:
		_fail("no second source card for real double-click evidence")
		return
	var double_slot_id := str(_item_debug(double_source).get("slot_id", ""))
	var double_before := _claim_state(screen, track, dock, claim_flow, claim_service)
	await _double_click_control(double_source)
	if not await _wait_for_claim_outcome(screen, track, dock, claim_flow, claim_service, double_before, true):
		return
	await _wait_past_rapid_guard()
	var double_after := _claim_state(screen, track, dock, claim_flow, claim_service)
	_assert_success_delta("double click", double_before, double_after, double_slot_id)
	_expect(
		int(double_after.get("duplicate_suppression", 0)) > int(double_before.get("duplicate_suppression", 0)),
		"second half of a real double-click is suppressed after the source advances"
	)
	_evidence["double_click"] = _delta_evidence(double_before, double_after)

	if not await _resolve_forced_surfaces_through_ui(screen):
		return
	var keyboard_source := _first_visible_claimable_source(track)
	if keyboard_source == null:
		_fail("no third source card for drag and keyboard evidence")
		return
	var keyboard_slot_id := str(_item_debug(keyboard_source).get("slot_id", ""))
	var drag_before := _claim_state(screen, track, dock, claim_flow, claim_service)
	var drag_cancel_before := int(_item_debug(keyboard_source).get("drag_cancellation_count", 0))
	keyboard_source = await _focus_source_for_keyboard(screen, track, keyboard_slot_id)
	if keyboard_source == null:
		_fail("source card could not regain focus after resolving production decision surfaces")
		return
	await _settle_frames(3)
	var drag_after := _claim_state(screen, track, dock, claim_flow, claim_service)
	_assert_no_claim_delta("source-card drag", drag_before, drag_after)
	_expect(
		int(_item_debug(keyboard_source).get("drag_cancellation_count", 0)) > drag_cancel_before,
		"real root viewport drag crosses the deadzone and cancels claim"
	)
	_expect(root.gui_get_focus_owner() == keyboard_source, "source card receives keyboard focus through real input")
	var keyboard_before := _claim_state(screen, track, dock, claim_flow, claim_service)
	await _key_tap(KEY_ENTER)
	if not await _wait_for_claim_outcome(screen, track, dock, claim_flow, claim_service, keyboard_before, true):
		return
	await _settle_frames(4)
	var keyboard_after := _claim_state(screen, track, dock, claim_flow, claim_service)
	_assert_success_delta("keyboard confirm", keyboard_before, keyboard_after, keyboard_slot_id)
	_evidence["keyboard_claim"] = _delta_evidence(keyboard_before, keyboard_after)

	await _wait_past_rapid_guard()
	if not await _resolve_forced_surfaces_through_ui(screen):
		return
	var fourth_source := _first_visible_claimable_source(track)
	if fourth_source == null:
		_fail("no fourth source card for natural shared-capacity fill")
		return
	var fourth_slot_id := str(_item_debug(fourth_source).get("slot_id", ""))
	var fourth_before := _claim_state(screen, track, dock, claim_flow, claim_service)
	await _click_control(fourth_source)
	if not await _wait_for_claim_outcome(screen, track, dock, claim_flow, claim_service, fourth_before, true):
		return
	await _settle_frames(4)
	var fourth_after := _claim_state(screen, track, dock, claim_flow, claim_service)
	_assert_success_delta("fourth distinct commodity click", fourth_before, fourth_after, fourth_slot_id)
	var full_projection := _dock_projection(screen)
	_expect(
		str(full_projection.get("capacity_mode", "")) == DOCK_PROJECTION.CAPACITY_MODE_SHARED_V06 \
			and int(full_projection.get("normal_count", -1)) == 1 \
			and int(full_projection.get("commodity_count", -1)) == 4 \
			and int(full_projection.get("shared_capacity_count", -1)) == DOCK_PROJECTION.CARD_LIMIT \
			and int(full_projection.get("shared_capacity_limit", -1)) == DOCK_PROJECTION.CARD_LIMIT,
		"four real successful claims naturally reach one normal plus four commodities at 5/5"
	)

	await _wait_past_rapid_guard()
	if not await _resolve_forced_surfaces_through_ui(screen):
		return
	var failure_source := _first_visible_claimable_source(track)
	if failure_source == null:
		_fail("no fifth distinct commodity source for full-capacity failure")
		return
	var failure_slot_id := str(_item_debug(failure_source).get("slot_id", ""))
	var failure_before := _claim_state(screen, track, dock, claim_flow, claim_service)
	await _click_control(failure_source)
	if not await _wait_for_claim_outcome(screen, track, dock, claim_flow, claim_service, failure_before, false):
		return
	await _settle_frames(4)
	var failure_after := _claim_state(screen, track, dock, claim_flow, claim_service)
	_assert_failure_delta("shared capacity failure", failure_before, failure_after, failure_slot_id)
	var failure_feedback: Dictionary = _track_debug(track).get("last_claim_feedback", {}) as Dictionary
	_expect(
		str(failure_feedback.get("failure_code", "")) == "shared_hand_capacity_full" \
			and _node_text(failure_source).contains("容量已满") \
			and _node_text(right_inspector).contains("当前 V0.6 共享手牌容量已满"),
		"fifth distinct commodity click shows the typed V0.6 shared-capacity failure"
	)
	_evidence["shared_capacity_failure"] = _delta_evidence(failure_before, failure_after)
	await _capture("production_commodity_claim_failure.png", CAPTURE_SIZE_LARGE)

	var owned_commodity := _owned_commodity_card(dock, first_card_id)
	if owned_commodity == null:
		_fail("claimed commodity did not render in the production CommodityCards pool")
		return
	var owned_row: Dictionary = _card_row(owned_commodity)
	_expect(
		str(owned_row.get("illustration_key", "")) == first_illustration_key \
			and bool(owned_commodity.get_meta("external_illustration_active", false)) \
			and bool(owned_commodity.get_meta("authored_illustration_active", false)) \
			and int(owned_row.get("level", 0)) == 1,
		"owned rank-I commodity reuses the exact authored source illustration"
	)
	await _click_control(owned_commodity)
	await _wait_until("owned_commodity_selected", func() -> bool:
		return not str(_dock_debug(dock).get("selected_identity", "")).is_empty()
	)
	await _capture("production_commodity_inventory_art.png", CAPTURE_SIZE_LARGE)
	await _click_control(owned_commodity)
	await _settle_frames(2)
	await _move_pointer(_neutral_table_point(screen))
	_expect(
		_visible_pool_card_count(dock, "NormalHandCards") == 1 \
			and _visible_pool_card_count(dock, "CommodityCards") == 4,
		"one real normal starter card and four claimed commodities are simultaneously visible"
	)
	await _capture("production_normal_and_commodity_cards.png", CAPTURE_SIZE_LARGE)
	await _capture("production_card_dock_1920x1080.png", CAPTURE_SIZE_LARGE)

	if not await _set_capture_size(CAPTURE_SIZE_COMPACT):
		return
	_assert_production_surface(screen, track, dock, CAPTURE_SIZE_COMPACT)
	await _capture("production_card_dock_1366x768.png", CAPTURE_SIZE_COMPACT)

	_assert_zero_claim_buttons(track)
	_assert_runtime_mutation_boundaries(track, dock, claim_service)
	_record_performance_evidence(screen)


func _required_nodes_ready(
	screen: Control,
	track: Node,
	dock: Node,
	claim_flow: Node,
	claim_service: Node,
	planet_board: Control,
	right_inspector: Control
) -> bool:
	var ready := screen != null and track != null and dock != null \
		and claim_flow != null and claim_service != null \
		and planet_board != null and right_inspector != null
	_expect(ready, "real main exposes the production screen, track, Dock, claim flow, service, map and inspector")
	return ready


func _resolve_forced_surfaces_through_ui(screen: Control) -> bool:
	var overlay := screen.find_child("OverlayLayer", true, false) if screen != null else null
	if overlay == null or not overlay.has_method("forced_surface_active"):
		return true
	var resolved: Array = _evidence.get("resolved_forced_surfaces", []) as Array
	for _attempt in range(8):
		if not bool(overlay.call("forced_surface_active")):
			_evidence["resolved_forced_surfaces"] = resolved
			return true
		var overlay_debug: Dictionary = overlay.call("debug_snapshot") as Dictionary \
			if overlay.has_method("debug_snapshot") else {}
		var surface_id := str(overlay_debug.get("active_forced_surface_id", ""))
		var action_button: Button = null
		for node_name in [
			"MonsterWagerActionButton",
			"TemporaryChoiceActionButton",
			"TemporaryDecisionActionButton",
			"BidBoardActionButton",
		]:
			for candidate_variant in overlay.find_children(node_name, "Button", true, false):
				var candidate := candidate_variant as Button
				if candidate != null and candidate.is_visible_in_tree() and not candidate.disabled \
						and _control_is_clickable(candidate):
					action_button = candidate
					break
			if action_button != null:
				break
		if action_button == null:
			_fail("forced production surface has no visible enabled action button: %s" % surface_id)
			return false
		var action_label := action_button.text
		if not await _click_control(action_button):
			_fail("forced production action was not clickable: %s" % action_label)
			return false
		var cleared := await _wait_until("forced_surface_resolved", func() -> bool:
			if not bool(overlay.call("forced_surface_active")):
				return true
			var next_debug: Dictionary = overlay.call("debug_snapshot") as Dictionary \
				if overlay.has_method("debug_snapshot") else {}
			return str(next_debug.get("active_forced_surface_id", "")) != surface_id
		, 5_000)
		resolved.append({"surface_id": surface_id, "action_label": action_label, "cleared": cleared})
		if not cleared:
			return false
	_fail("too many consecutive forced production surfaces")
	return false


func _focus_source_for_keyboard(screen: Control, track: Node, slot_id: String) -> Control:
	for _attempt in range(8):
		if not await _resolve_forced_surfaces_through_ui(screen):
			return null
		var source := _source_by_slot(track, slot_id)
		if source == null:
			return null
		await _drag_control_past_deadzone(source)
		await _settle_frames(3)
		if root.gui_get_focus_owner() == source:
			return source
	return null


func _assert_production_surface(
	screen: Control,
	track: Node,
	dock: Node,
	expected_size: Vector2i,
	require_commodity := true
) -> void:
	_expect(root.size == expected_size, "root viewport is exactly %dx%d" % [expected_size.x, expected_size.y])
	for node_name in ["TopCommoditySushiTrack", "PlanetBoard", "RightInspector", "PlayerBoard", "PlayerCardDock"]:
		var control := screen.find_child(node_name, true, false) as Control
		_expect(
			control != null and control.is_visible_in_tree() \
				and control.get_global_rect().size.x > 0.0 and control.get_global_rect().size.y > 0.0 \
				and _screen_visible_ratio(control) >= 0.95,
			"%s is visible inside %dx%d" % [node_name, expected_size.x, expected_size.y]
		)
	var normal_visible := _visible_pool_card_count(dock, "NormalHandCards") >= 1
	var commodity_visible := _visible_pool_card_count(dock, "CommodityCards") >= 1
	_expect(
		normal_visible and (commodity_visible or not require_commodity),
		("normal card remains visible inside %dx%d" if not require_commodity \
			else "normal and commodity cards remain visible inside %dx%d") \
			% [expected_size.x, expected_size.y]
	)
	_assert_zero_claim_buttons(track)


func _assert_zero_claim_buttons(track: Node) -> void:
	var track_debug := _track_debug(track)
	var actual_buttons := track.find_children("*", "Button", true, false)
	var item_buttons := 0
	for item_variant in track.find_children("CommoditySlot_*", "PanelContainer", true, false):
		var item_node := item_variant as Node
		item_buttons += item_node.find_children("*", "Button", true, false).size()
		if item_node.has_method("debug_snapshot"):
			_expect(int((item_node.call("debug_snapshot") as Dictionary).get("claim_button_count", -1)) == 0, "source item reports zero claim buttons")
	_expect(
		int(track_debug.get("claim_button_count", -1)) == 0 \
			and actual_buttons.is_empty() and item_buttons == 0,
		"production commodity source contains zero visible or hidden claim Buttons"
	)


func _assert_runtime_mutation_boundaries(track: Node, dock: Node, claim_service: Node) -> void:
	var track_debug := _track_debug(track)
	var dock_debug := _dock_debug(dock)
	var service_debug := claim_service.call("debug_snapshot") as Dictionary
	_expect(
		int(track_debug.get("direct_inventory_mutation_count", -1)) == 0 \
			and int(track_debug.get("direct_track_mutation_count", -1)) == 0 \
			and not bool(dock_debug.get("mutates_gameplay", true)) \
			and not bool(dock_debug.get("reads_world_state", true)) \
			and not bool(service_debug.get("owns_belt_state", true)) \
			and not bool(service_debug.get("owns_player_state", true)),
		"UI and presentation keep zero direct gameplay mutations"
	)


func _record_performance_evidence(screen: Control) -> void:
	var raw: Dictionary = screen.call("commodity_claim_performance_snapshot") as Dictionary
	var recorded := {
		"commodity_source_render_p95": float(raw.get("commodity_source_render_p95_ms", -1.0)),
		"commodity_inventory_render_p95": float(raw.get("commodity_inventory_render_p95_ms", -1.0)),
		"commodity_hover_p95": float(raw.get("commodity_hover_p95_ms", -1.0)),
		"single_click_to_intent_p95": float(raw.get("single_click_to_intent_p95_ms", -1.0)),
		"receipt_to_inventory_refresh_p95": float(raw.get("receipt_to_inventory_refresh_p95_ms", -1.0)),
	}
	for field in PERFORMANCE_FIELDS:
		_expect(recorded.has(field) and float(recorded.get(field, -1.0)) >= 0.0, "%s is recorded as a nonnegative p95 sample" % field)
	_evidence["performance_p95_ms"] = recorded


func _wait_for_claim_outcome(
	screen: Control,
	track: Node,
	dock: Node,
	claim_flow: Node,
	claim_service: Node,
	before: Dictionary,
	expect_success: bool
) -> bool:
	var reached := await _wait_until("claim_success" if expect_success else "claim_failure", func() -> bool:
		var current := _claim_state(screen, track, dock, claim_flow, claim_service)
		if expect_success:
			return int(current.get("track_success", 0)) >= int(before.get("track_success", 0)) + 1 \
				and int(current.get("dock_commodity", 0)) >= int(before.get("dock_commodity", 0)) + 1 \
				and int(current.get("belt_revision", 0)) >= int(before.get("belt_revision", 0)) + 1 \
				and int(current.get("track_pending", 0)) == 0
		return int(current.get("track_failure", 0)) >= int(before.get("track_failure", 0)) + 1 \
			and str(current.get("last_failure_code", "")) == "shared_hand_capacity_full" \
			and int(current.get("track_pending", 0)) == 0
	)
	if not reached:
		print("CLAIM_OUTCOME_DEBUG expect_success=%s before=%s after=%s feedback=%s" % [
			expect_success,
			JSON.stringify(before),
			JSON.stringify(_claim_state(screen, track, dock, claim_flow, claim_service)),
			JSON.stringify(_track_debug(track).get("last_claim_feedback", {})),
		])
	return reached


func _claim_state(screen: Control, track: Node, dock: Node, claim_flow: Node, claim_service: Node) -> Dictionary:
	var track_debug := _track_debug(track)
	var dock_debug := _dock_debug(dock)
	var flow_debug: Dictionary = claim_flow.call("debug_snapshot") as Dictionary
	var service_debug: Dictionary = claim_service.call("debug_snapshot") as Dictionary
	var track_projection := _track_projection(screen)
	var feedback: Dictionary = track_debug.get("last_claim_feedback", {}) as Dictionary
	return {
		"track_submission": int(track_debug.get("claim_submission_count", 0)),
		"track_success": int(track_debug.get("claim_result_success_count", 0)),
		"track_failure": int(track_debug.get("claim_result_failure_count", 0)),
		"track_pending": int(track_debug.get("pending_claim_count", 0)),
		"duplicate_suppression": int(track_debug.get("duplicate_claim_suppression_count", 0)),
		"rendered_count": int(track_debug.get("rendered_item_count", 0)),
		"rendered_slot_ids": (track_debug.get("rendered_slot_ids", []) as Array).duplicate(),
		"snapshot_revision": int(track_projection.get("snapshot_revision", 0)),
		"belt_revision": int(track_projection.get("belt_revision", 0)),
		"dock_source_revision": int(dock_debug.get("source_revision", 0)),
		"dock_normal": int(dock_debug.get("normal_card_count", 0)),
		"dock_commodity": int(dock_debug.get("commodity_card_count", 0)),
		"flow_submit": int(flow_debug.get("submit_count", 0)),
		"flow_success": int(flow_debug.get("success_count", 0)),
		"flow_failure": int(flow_debug.get("failure_count", 0)),
		"service_claim": int(service_debug.get("claim_count", 0)),
		"service_rejected": int(service_debug.get("rejected_count", 0)),
		"service_terminal": int(service_debug.get("terminal_request_count", 0)),
		"last_failure_code": str(feedback.get("failure_code", "")),
	}


func _assert_success_delta(label: String, before: Dictionary, after: Dictionary, claimed_slot_id: String) -> void:
	_expect(int(after.get("track_submission", 0)) == int(before.get("track_submission", 0)) + 1, "%s emits exactly one track request" % label)
	_expect(int(after.get("track_success", 0)) == int(before.get("track_success", 0)) + 1, "%s accepts exactly one success" % label)
	_expect(int(after.get("track_failure", 0)) == int(before.get("track_failure", 0)), "%s emits no failure" % label)
	_expect(int(after.get("dock_commodity", 0)) == int(before.get("dock_commodity", 0)) + 1, "%s adds exactly one commodity to the Dock" % label)
	_expect(int(after.get("dock_normal", 0)) == int(before.get("dock_normal", 0)), "%s preserves the normal-card pool" % label)
	_expect(int(after.get("rendered_count", 0)) == int(before.get("rendered_count", 0)) - 1, "%s removes exactly one source item" % label)
	_expect(int(after.get("belt_revision", 0)) == int(before.get("belt_revision", 0)) + 1, "%s advances the authoritative source revision exactly once" % label)
	_expect(not (after.get("rendered_slot_ids", []) as Array).has(claimed_slot_id), "%s removes the claimed stable source id" % label)
	_expect(int(after.get("flow_submit", 0)) == int(before.get("flow_submit", 0)) + 1, "%s enters the application flow exactly once" % label)
	_expect(int(after.get("flow_success", 0)) == int(before.get("flow_success", 0)) + 1, "%s receives exactly one successful flow receipt" % label)
	_expect(int(after.get("flow_failure", 0)) == int(before.get("flow_failure", 0)), "%s produces no flow rejection" % label)
	_expect(int(after.get("service_claim", 0)) == int(before.get("service_claim", 0)) + 1, "%s commits exactly once in the authoritative claim service" % label)
	_expect(int(after.get("service_rejected", 0)) == int(before.get("service_rejected", 0)), "%s has no authoritative rejection" % label)
	_expect(int(after.get("service_terminal", 0)) == int(before.get("service_terminal", 0)) + 1, "%s creates exactly one terminal request identity" % label)
	_expect(int(after.get("track_pending", -1)) == 0, "%s leaves no pending source identity" % label)


func _assert_failure_delta(label: String, before: Dictionary, after: Dictionary, source_slot_id: String) -> void:
	_expect(int(after.get("track_submission", 0)) == int(before.get("track_submission", 0)) + 1, "%s emits exactly one request" % label)
	_expect(int(after.get("track_success", 0)) == int(before.get("track_success", 0)), "%s accepts no success" % label)
	_expect(int(after.get("track_failure", 0)) == int(before.get("track_failure", 0)) + 1, "%s returns exactly one failure" % label)
	_expect(int(after.get("dock_commodity", 0)) == int(before.get("dock_commodity", 0)), "%s adds no inventory card" % label)
	_expect(int(after.get("dock_normal", 0)) == int(before.get("dock_normal", 0)), "%s preserves normal cards" % label)
	_expect(int(after.get("rendered_count", 0)) == int(before.get("rendered_count", 0)), "%s preserves source count" % label)
	_expect(int(after.get("belt_revision", 0)) == int(before.get("belt_revision", 0)), "%s preserves authoritative source revision" % label)
	_expect((after.get("rendered_slot_ids", []) as Array).has(source_slot_id), "%s preserves the rejected source item" % label)
	_expect(int(after.get("flow_submit", 0)) == int(before.get("flow_submit", 0)) + 1, "%s enters the flow exactly once" % label)
	_expect(int(after.get("flow_success", 0)) == int(before.get("flow_success", 0)), "%s has no successful flow receipt" % label)
	_expect(int(after.get("flow_failure", 0)) == int(before.get("flow_failure", 0)) + 1, "%s has exactly one failed flow receipt" % label)
	_expect(int(after.get("service_claim", 0)) == int(before.get("service_claim", 0)), "%s commits no authoritative claim" % label)
	_expect(int(after.get("service_rejected", 0)) == int(before.get("service_rejected", 0)) + 1, "%s records exactly one authoritative rejection" % label)
	_expect(int(after.get("service_terminal", 0)) == int(before.get("service_terminal", 0)) + 1, "%s creates one terminal failure identity" % label)
	_expect(str(after.get("last_failure_code", "")) == "shared_hand_capacity_full", "%s retains its typed shared-capacity code" % label)
	_expect(int(after.get("track_pending", -1)) == 0, "%s restores source-card interactivity" % label)


func _assert_no_claim_delta(label: String, before: Dictionary, after: Dictionary) -> void:
	for field in [
		"track_submission", "track_success", "track_failure", "track_pending",
		"rendered_count", "belt_revision", "dock_normal", "dock_commodity",
		"flow_submit", "flow_success", "flow_failure", "service_claim",
		"service_rejected", "service_terminal",
	]:
		_expect(int(after.get(field, -1)) == int(before.get(field, -2)), "%s preserves %s" % [label, field])
	_expect(after.get("rendered_slot_ids", []) == before.get("rendered_slot_ids", []), "%s preserves source identities" % label)


func _delta_evidence(before: Dictionary, after: Dictionary) -> Dictionary:
	return {
		"request_delta": int(after.get("track_submission", 0)) - int(before.get("track_submission", 0)),
		"success_delta": int(after.get("track_success", 0)) - int(before.get("track_success", 0)),
		"failure_delta": int(after.get("track_failure", 0)) - int(before.get("track_failure", 0)),
		"commodity_inventory_delta": int(after.get("dock_commodity", 0)) - int(before.get("dock_commodity", 0)),
		"source_count_delta": int(after.get("rendered_count", 0)) - int(before.get("rendered_count", 0)),
		"belt_revision_delta": int(after.get("belt_revision", 0)) - int(before.get("belt_revision", 0)),
		"failure_code": str(after.get("last_failure_code", "")),
	}


func _track_projection(screen: Control) -> Dictionary:
	var ui_data_variant: Variant = screen.get("current_ui_data") if screen != null else {}
	var ui_data: Dictionary = ui_data_variant if ui_data_variant is Dictionary else {}
	var projection_variant: Variant = ui_data.get("commodity_sushi_track", {})
	return (projection_variant as Dictionary).duplicate(true) if projection_variant is Dictionary else {}


func _dock_projection(screen: Control) -> Dictionary:
	var ui_data_variant: Variant = screen.get("current_ui_data") if screen != null else {}
	var ui_data: Dictionary = ui_data_variant if ui_data_variant is Dictionary else {}
	var projection_variant: Variant = ui_data.get("player_card_dock", {})
	return (projection_variant as Dictionary).duplicate(true) if projection_variant is Dictionary else {}


func _track_debug(track: Node) -> Dictionary:
	return track.call("debug_snapshot") as Dictionary if track != null and track.has_method("debug_snapshot") else {}


func _dock_debug(dock: Node) -> Dictionary:
	return dock.call("debug_snapshot") as Dictionary if dock != null and dock.has_method("debug_snapshot") else {}


func _item_debug(item: Control) -> Dictionary:
	return item.call("debug_snapshot") as Dictionary if item != null and item.has_method("debug_snapshot") else {}


func _card_row(card: Control) -> Dictionary:
	var row_variant: Variant = card.get_meta("player_card_dock_row", {}) if card != null else {}
	return (row_variant as Dictionary).duplicate(true) if row_variant is Dictionary else {}


func _first_visible_claimable_source(track: Node) -> Control:
	var belt_viewport := track.find_child("BeltViewport", true, false) as Control if track != null else null
	if belt_viewport == null:
		return null
	var clip_rect := belt_viewport.get_global_rect()
	var root_rect := root.get_visible_rect()
	for item_variant in track.find_children("CommoditySlot_*", "PanelContainer", true, false):
		var item := item_variant as Control
		if item == null or not item.is_visible_in_tree() or not item.has_method("debug_snapshot"):
			continue
		var item_debug := _item_debug(item)
		var center := item.get_global_rect().get_center()
		if bool(item_debug.get("claimable", false)) \
				and not bool(item_debug.get("claim_pending", false)) \
				and clip_rect.has_point(center) and root_rect.has_point(center):
			return item
	return null


func _source_by_slot(track: Node, slot_id: String) -> Control:
	if track == null or slot_id.is_empty():
		return null
	for item_variant in track.find_children("CommoditySlot_*", "PanelContainer", true, false):
		var item := item_variant as Control
		if item != null and str(_item_debug(item).get("slot_id", "")) == slot_id:
			return item
	return null


func _owned_commodity_card(dock: Node, card_semantic_id: String) -> Control:
	var host := dock.find_child("CommodityCards", true, false) if dock != null else null
	if host == null:
		return null
	for child in host.get_children():
		var card := child as Control
		var row := _card_row(card)
		if card != null and card.is_visible_in_tree() \
				and str(row.get("card_semantic_id", "")) == card_semantic_id:
			return card
	return null


func _visible_pool_card_count(dock: Node, host_name: String) -> int:
	var host := dock.find_child(host_name, true, false) as Control if dock != null else null
	if host == null or not host.is_visible_in_tree():
		return 0
	var count := 0
	for child in host.get_children():
		var card := child as Control
		if card != null and card.is_visible_in_tree() \
				and _screen_visible_ratio(card) >= 0.90:
			count += 1
	return count


func _control_viewport_rect(control: Control) -> Rect2:
	if control == null:
		return Rect2()
	# Keep the control and viewport bounds in the same virtual-pixel coordinate
	# space. This remains correct with canvas_items + expand, HiDPI scaling, and
	# a root window whose physical size differs from its visible canvas rect.
	var transform := control.get_global_transform_with_canvas()
	var corners: Array[Vector2] = [
		transform * Vector2.ZERO,
		transform * Vector2(control.size.x, 0.0),
		transform * control.size,
		transform * Vector2(0.0, control.size.y),
	]
	var minimum := corners[0]
	var maximum := corners[0]
	for corner in corners:
		minimum = Vector2(minf(minimum.x, corner.x), minf(minimum.y, corner.y))
		maximum = Vector2(maxf(maximum.x, corner.x), maxf(maximum.y, corner.y))
	return Rect2(minimum, maximum - minimum)


func _screen_visible_ratio(control: Control) -> float:
	var screen_rect := _control_viewport_rect(control)
	var area := screen_rect.size.x * screen_rect.size.y
	if area <= 0.0:
		return 0.0
	var visible := screen_rect.intersection(root.get_visible_rect())
	return (visible.size.x * visible.size.y) / area


func _click_control(control: Control) -> bool:
	if not _control_is_clickable(control):
		return false
	await _move_pointer(control.get_global_rect().get_center())
	await _push_mouse_button(control.get_global_rect().get_center(), true, false)
	await _push_mouse_button(control.get_global_rect().get_center(), false, false)
	await _settle_frames(2)
	return true


func _double_click_control(control: Control) -> bool:
	if not _control_is_clickable(control):
		return false
	var position := control.get_global_rect().get_center()
	await _move_pointer(position)
	await _push_mouse_button(position, true, false)
	await _push_mouse_button(position, false, false)
	await _push_mouse_button(position, true, true)
	await _push_mouse_button(position, false, true)
	await _settle_frames(2)
	return true


func _click_position(position: Vector2) -> void:
	await _move_pointer(position)
	await _push_mouse_button(position, true, false)
	await _push_mouse_button(position, false, false)
	await _settle_frames(2)


func _scroll_control_into_view(control: Control) -> bool:
	if control == null:
		return false
	var scroll: ScrollContainer = null
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			scroll = ancestor as ScrollContainer
			break
		ancestor = ancestor.get_parent()
	if scroll == null:
		return _control_visible_through_clippers(control)
	var scroll_point := scroll.get_global_rect().get_center()
	for _index in range(32):
		if _control_visible_through_clippers(control):
			# Do not leave the target grazing the ScrollContainer's lower edge.
			# Continue with real wheel input so the whole action row is safely
			# inside the interactive viewport rather than merely center-visible.
			for _extra_scroll in range(6):
				await _move_pointer(scroll_point)
				await _push_mouse_wheel(scroll_point, MOUSE_BUTTON_WHEEL_DOWN)
				await _settle_frames(2)
			await _settle_frames(10)
			return _control_visible_through_clippers(control)
		await _move_pointer(scroll_point)
		await _push_mouse_wheel(scroll_point, MOUSE_BUTTON_WHEEL_DOWN)
		await _settle_frames(2)
	return _control_visible_through_clippers(control)


func _hover_control(control: Control) -> void:
	if control == null:
		return
	await _move_pointer(control.get_global_rect().get_center())
	await _settle_frames(2)


func _move_pointer(position: Vector2, relative := Vector2.ZERO, button_mask := 0) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	motion.relative = relative
	motion.button_mask = button_mask
	root.push_input(motion, true)
	await process_frame


func _push_mouse_button(position: Vector2, pressed: bool, double_click: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.double_click = double_click
	event.position = position
	event.global_position = position
	root.push_input(event, true)
	await process_frame


func _push_mouse_wheel(position: Vector2, button_index: MouseButton) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = button_index
	press.pressed = true
	press.factor = 1.0
	press.position = position
	press.global_position = position
	root.push_input(press, true)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = button_index
	release.pressed = false
	release.factor = 1.0
	release.position = position
	release.global_position = position
	root.push_input(release, true)
	await process_frame


func _drag_control_past_deadzone(control: Control) -> void:
	if not _control_is_clickable(control):
		_fail("drag target is not clickable")
		return
	var start := control.get_global_rect().get_center()
	var finish := start + Vector2(minf(24.0, control.get_global_rect().size.x * 0.2), 0.0)
	await _move_pointer(start)
	await _push_mouse_button(start, true, false)
	await _move_pointer(finish, finish - start, MOUSE_BUTTON_MASK_LEFT)
	await _push_mouse_button(finish, false, false)
	await _settle_frames(2)


func _key_tap(keycode: Key) -> void:
	var press := InputEventKey.new()
	press.keycode = keycode
	press.physical_keycode = keycode
	press.pressed = true
	root.push_input(press, true)
	await process_frame
	var release := InputEventKey.new()
	release.keycode = keycode
	release.physical_keycode = keycode
	release.pressed = false
	root.push_input(release, true)
	await process_frame


func _control_is_clickable(control: Control) -> bool:
	return control != null and control.is_visible_in_tree() \
		and control.get_global_rect().size.x > 0.0 and control.get_global_rect().size.y > 0.0 \
		and _control_visible_through_clippers(control)


func _control_visible_through_clippers(control: Control) -> bool:
	if control == null:
		return false
	var center := control.get_global_rect().get_center()
	var visible_rect := root.get_visible_rect()
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is Control and (ancestor as Control).clip_contents:
			visible_rect = visible_rect.intersection((ancestor as Control).get_global_rect())
		ancestor = ancestor.get_parent()
	return visible_rect.has_point(center)


func _neutral_table_point(screen: Control) -> Vector2:
	var planet_board := screen.find_child("PlanetBoard", true, false) as Control if screen != null else null
	if planet_board != null:
		return planet_board.get_global_rect().position + Vector2(8.0, 8.0)
	return Vector2(4.0, 4.0)


func _set_capture_size(next_size: Vector2i) -> bool:
	_capture_size = next_size
	DisplayServer.window_set_size(next_size)
	root.size = next_size
	await _settle_frames(6)
	await RenderingServer.frame_post_draw
	var exact: bool = root.size == next_size \
		and DisplayServer.window_get_size() == next_size \
		and root.get_texture().get_size().x > 0 \
		and root.get_texture().get_size().y > 0
	print(
		"CAPTURE_SIZE_DEBUG requested=%s window=%s root=%s content_scale=%s texture=%s screen=%s" % [
			next_size,
			DisplayServer.window_get_size(),
			root.size,
			root.content_scale_size,
			Vector2i(root.get_texture().get_size()),
			DisplayServer.screen_get_size(DisplayServer.window_get_current_screen()),
		]
	)
	_expect(
		exact,
		"headed viewport settles at exactly %dx%d" % [next_size.x, next_size.y]
	)
	return exact


func _capture(file_name: String, expected_size: Vector2i) -> void:
	await _settle_frames(2)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("viewport image is empty for %s" % file_name)
		return
	if root.size != expected_size or DisplayServer.window_get_size() != expected_size or _capture_size != expected_size:
		_fail("%s size mismatch: image=%s root=%s expected=%s" % [file_name, image.get_size(), root.size, expected_size])
		return
	var render_texture_size := image.get_size()
	# On Windows with per-monitor DPI scaling, Godot can render the root texture
	# above the logical viewport size. The production layout and all input use the
	# exact logical viewport; normalize only the exported evidence bitmap.
	if render_texture_size != expected_size:
		var scale_x := float(render_texture_size.x) / float(expected_size.x)
		var scale_y := float(render_texture_size.y) / float(expected_size.y)
		if absf(scale_x - scale_y) > 0.02 or scale_x < 0.5 or scale_x > 2.0:
			_fail("%s render texture has an invalid DPI scale: %s -> %s" % [file_name, render_texture_size, expected_size])
			return
		image.resize(expected_size.x, expected_size.y, Image.INTERPOLATE_LANCZOS)
	if image.get_size() != expected_size:
		_fail("%s could not normalize the DPI-scaled render texture to %s" % [file_name, expected_size])
		return
	var resource_path := "%s/%s" % [OUTPUT_DIR, file_name]
	var error := image.save_png(resource_path)
	if error != OK or not FileAccess.file_exists(resource_path):
		_fail("failed to save %s: %s" % [resource_path, error_string(error)])
		return
	_saved_file_names.append(file_name)
	_screenshot_records.append({
		"file_name": file_name,
		"resource_path": resource_path,
		"absolute_path": ProjectSettings.globalize_path(resource_path),
		"width": expected_size.x,
		"height": expected_size.y,
		"render_texture_width": render_texture_size.x,
		"render_texture_height": render_texture_size.y,
	})
	print("CAPTURE: %s" % ProjectSettings.globalize_path(resource_path))


func _production_table_ready() -> bool:
	var screen := _screen()
	var track := _track()
	var dock := _dock()
	if screen == null or track == null or dock == null \
			or not screen.is_visible_in_tree() or not (track as Control).is_visible_in_tree() \
			or not (dock as Control).is_visible_in_tree():
		return false
	var track_debug := _track_debug(track)
	var dock_projection := _dock_projection(screen)
	return _public_player_count(_coordinator()) == 4 \
		and int(track_debug.get("rendered_item_count", 0)) >= 5 \
		and int(dock_projection.get("normal_count", 0)) == 1 \
		and int(dock_projection.get("commodity_count", -1)) == 0 \
		and int(dock_projection.get("shared_capacity_count", 0)) == 1


func _screen() -> Control:
	return _main.get_node_or_null("RuntimeGameScreen") as Control if _main != null else null


func _track() -> Node:
	var screen := _screen()
	return screen.find_child("TopCommoditySushiTrack", true, false) if screen != null else null


func _dock() -> Node:
	var screen := _screen()
	return screen.find_child("PlayerCardDock", true, false) if screen != null else null


func _coordinator() -> Node:
	return _main.get_node_or_null(COORDINATOR_PATH) if _main != null else null


func _claim_flow() -> Node:
	return _main.get_node_or_null(CLAIM_FLOW_PATH) if _main != null else null


func _claim_service() -> Node:
	return _main.get_node_or_null(CLAIM_SERVICE_PATH) if _main != null else null


func _public_player_count(coordinator: Node) -> int:
	if coordinator == null or not coordinator.has_method("presentation_public_world_projection"):
		return 0
	var projection: Variant = coordinator.call("presentation_public_world_projection")
	if projection == null or not projection.has_method("get"):
		return 0
	var players_variant: Variant = projection.get("players")
	return (players_variant as Array).size() if players_variant is Array else 0


func _visible_child(parent: Node, node_name: String) -> Control:
	var node := parent.find_child(node_name, true, false) as Control if parent != null else null
	return node if node != null and node.is_visible_in_tree() else null


func _wait_until(stage: String, predicate: Callable, timeout_msec := STAGE_TIMEOUT_MSEC) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < timeout_msec:
		if bool(predicate.call()):
			return true
		await process_frame
	_fail("stage timeout: %s" % stage)
	return false


func _wait_past_rapid_guard() -> void:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < RAPID_INPUT_SETTLE_MSEC:
		await process_frame


func _wait_input_settle_msec(duration_msec: int) -> void:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < maxi(0, duration_msec):
		await process_frame


func _settle_frames(count: int) -> void:
	for _index in range(maxi(1, count)):
		await process_frame


func _node_text(node: Node) -> String:
	if node == null:
		return ""
	var parts: Array[String] = []
	if node is Label:
		parts.append((node as Label).text)
	elif node is Button:
		parts.append((node as Button).text)
	for child in node.get_children():
		parts.append(_node_text(child))
	return "\n".join(parts)


func _node_path(node: Node) -> String:
	return str(node.get_path()) if node != null and is_instance_valid(node) else ""


func _on_start_button_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	var events: Array = _start_debug.get("gui_mouse_events", []) as Array
	events.append({
		"button": mouse.button_index,
		"pressed": mouse.pressed,
		"position": str(mouse.position),
		"global_position": str(mouse.global_position),
	})
	_start_debug["gui_mouse_events"] = events


func _place_capture_window() -> void:
	var screen_index := 0
	var largest_area := -1
	for candidate in range(DisplayServer.get_screen_count()):
		var size := DisplayServer.screen_get_size(candidate)
		var area := size.x * size.y
		if area > largest_area:
			largest_area = area
			screen_index = candidate
	DisplayServer.window_set_current_screen(screen_index)
	DisplayServer.window_set_position(DisplayServer.screen_get_position(screen_index) + Vector2i(20, 20))


func _save_file_snapshot(path: String) -> Dictionary:
	var exists := FileAccess.file_exists(path)
	if not exists:
		return {"path": path, "exists": false, "size_bytes": 0, "modified_unix": 0, "sha256": ""}
	return {
		"path": path,
		"exists": true,
		"size_bytes": FileAccess.get_size(path),
		"modified_unix": FileAccess.get_modified_time(path),
		"sha256": FileAccess.get_sha256(path),
	}


func _qa_save_artifacts() -> Array[String]:
	var artifacts: Array[String] = []
	var directory_path := QA_SAVE_PATH.get_base_dir()
	var file_prefix := QA_SAVE_PATH.get_file()
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return artifacts
	for file_name in directory.get_files():
		if file_name.begins_with(file_prefix):
			artifacts.append("%s/%s" % [directory_path, file_name])
	return artifacts


func _cleanup_qa_save_artifacts() -> void:
	for path in _qa_save_artifacts():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _cleanup_previous_capture_outputs() -> void:
	for file_name in REQUIRED_SCREENSHOTS:
		var path := "%s/%s" % [OUTPUT_DIR, file_name]
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if FileAccess.file_exists(RESULT_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RESULT_PATH))


func _finish() -> void:
	if _main != null and is_instance_valid(_main):
		if _main.get_parent() == root:
			root.remove_child(_main)
		_main.queue_free()
	await _settle_frames(4)
	_main = null
	_cleanup_qa_save_artifacts()
	var player_default_after := _save_file_snapshot(PLAYER_DEFAULT_SAVE_PATH)
	_expect(_player_default_before == player_default_after, "player default save metadata and SHA-256 remain unchanged")
	var remaining_qa_artifacts := _qa_save_artifacts()
	_expect(remaining_qa_artifacts.is_empty(), "isolated QA save artifacts are cleaned")
	var expected: Array[String] = REQUIRED_SCREENSHOTS.duplicate()
	var actual: Array[String] = _saved_file_names.duplicate()
	expected.sort()
	actual.sort()
	_expect(actual == expected, "all eight required production screenshots are saved exactly once")
	var result := {
		"status": "PASS" if _failures.is_empty() else "FAIL",
		"checks": _checks,
		"failures": _failures.duplicate(),
		"elapsed_seconds": float(Time.get_ticks_msec() - _run_started_msec) / 1000.0,
		"main_scene": "res://scenes/main.tscn",
		"input_delivery": "root.push_input",
		"direct_gameplay_state_injection_count": 0,
		"direct_claim_service_call_count": 0,
		"private_pointer_method_call_count": 0,
		"screenshots": _screenshot_records.duplicate(true),
		"evidence": _evidence.duplicate(true),
		"save_isolation": {
			"qa_save_path": QA_SAVE_PATH,
			"remaining_qa_artifacts": remaining_qa_artifacts,
			"player_default_before": _player_default_before,
			"player_default_after": player_default_after,
			"player_default_unchanged": _player_default_before == player_default_after,
		},
	}
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file == null:
		_fail("could not write production capture result")
	else:
		file.store_string(JSON.stringify(result, "  "))
		file.close()
	if _failures.is_empty():
		print("ALPHA04 PLAYER CARD DOCK PRODUCTION CAPTURE PASS (%d checks)" % _checks)
		quit(0)
	else:
		printerr("ALPHA04 PLAYER CARD DOCK PRODUCTION CAPTURE FAIL (%d checks, %d failures)" % [_checks, _failures.size()])
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)
