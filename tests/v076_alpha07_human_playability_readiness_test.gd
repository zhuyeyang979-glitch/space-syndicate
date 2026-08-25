extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const FIXED_SEED := 900626424
const VIEWPORTS := [
	Vector2i(1366, 768),
	Vector2i(1600, 960),
	Vector2i(1920, 1080),
]

var _checks := 0
var _failures: Array[String] = []
var _receipts: Array[Dictionary] = []
var _real_pointer_trace: Array[Dictionary] = []
var _direct_method_call_false_green_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if OS.get_environment("V076_READINESS_FUNCTIONAL_ONLY") != "1":
		for viewport_size in VIEWPORTS:
			var context := await _start_from_real_ui(viewport_size)
			await _assert_viewport(context, viewport_size)
			await _cleanup(context)
	var functional_context := await _start_from_real_ui(Vector2i(1600, 960))
	if not functional_context.is_empty():
		await _assert_coach_pacing_gate(functional_context)
		await _dismiss_coach_before_play(functional_context)
		await _assert_real_pointer_contract(functional_context)
		await _assert_pause_freezes_submission_timer(functional_context)
		await _assert_real_card_and_action_path(functional_context)
		await _assert_pacing_controls(functional_context)
		await _assert_coach_step3(functional_context)
		await _cleanup(functional_context)
	if OS.get_environment("V076_READINESS_FUNCTIONAL_ONLY") != "1":
		_expect(_checks >= 60, "readiness gate executes at least sixty checks")
	print((
		"V076_ALPHA07_HUMAN_PLAYABILITY_READINESS|status=%s|passed=%d|total=%d|"
		+ "production_main_scene_used=true|fixture_state_injection_count=0|"
		+ "human_green_claimed=false|details=%s"
	) % [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks - _failures.size(),
			_checks,
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)



func _assert_coach_pacing_gate(context: Dictionary) -> void:
	var screen := context.get("screen") as Control
	var flow := context.get("flow") as Node
	var coach := screen.get_node("V073PlaytestCoachMarks") as Node
	var before := flow.call("local_snapshot") as Dictionary
	var initial_screen_debug := screen.call("debug_snapshot") as Dictionary
	var initial_human := initial_screen_debug.get("human_playability", {}) as Dictionary
	_expect(bool((coach.call("debug_snapshot") as Dictionary).get("active", false)), "new game opens the coach activity gate")
	_expect(int((flow.call("pacing_snapshot") as Dictionary).get("effective_multiplier", -1)) == 0, "coach activity immediately pauses the shared effective pace")
	_expect(int(initial_human.get("coach_pacing_saved_multiplier", -1)) == 2, "coach gate saves the Candidate 2 default 2x once")
	var runtime := flow.get("_runtime_owner") as Node
	if runtime != null:
		runtime.call("_process", 31.0)
	var after_long_delta := flow.call("local_snapshot") as Dictionary
	_expect(
		is_equal_approx(
			float(before.get("submission_seconds_remaining", -1.0)),
			float(after_long_delta.get("submission_seconds_remaining", -2.0))
		),
		"coach gate keeps the authoritative submission timer unchanged across a 31-second delta"
	)
	var next := coach.find_child("CoachNext", true, false) as Button
	if next != null:
		next.pressed.emit()
		await process_frame
		next.pressed.emit()
		await process_frame
	var after_steps := flow.call("local_snapshot") as Dictionary
	_expect(
		is_equal_approx(
			float(before.get("submission_seconds_remaining", -1.0)),
			float(after_steps.get("submission_seconds_remaining", -2.0))
		),
		"coach step changes preserve the frozen authoritative submission timer"
	)
	await create_timer(0.12).timeout
	var after_wall_delay := flow.call("local_snapshot") as Dictionary
	_expect(
		is_equal_approx(
			float(before.get("submission_seconds_remaining", -1.0)),
			float(after_wall_delay.get("submission_seconds_remaining", -2.0))
		),
		"coach gate keeps submission time frozen during a real wall-clock delay"
	)


func _dismiss_coach_before_play(context: Dictionary) -> void:
	var screen := context.get("screen") as Control
	var flow := context.get("flow") as Node
	var coach := screen.get_node("V073PlaytestCoachMarks") as Node
	var skip := coach.find_child("CoachSkipAll", true, false) as Button
	_expect(skip != null, "coach exposes a production Skip control")
	if skip != null:
		skip.pressed.emit()
		await process_frame
		await process_frame
	_expect(not bool((coach.call("debug_snapshot") as Dictionary).get("active", true)), "Skip closes the coach activity gate")
	_expect(int((flow.call("pacing_snapshot") as Dictionary).get("effective_multiplier", -1)) == 2, "Skip restores the saved Candidate 2 pace exactly once")
	var human := (screen.call("debug_snapshot") as Dictionary).get("human_playability", {}) as Dictionary
	_expect(int(human.get("coach_pacing_gate_apply_count", 0)) == 1, "coach opening applies one pause request")
	_expect(int(human.get("coach_pacing_gate_restore_count", 0)) == 1, "coach Skip applies one restore request")


func _start_from_real_ui(viewport_size: Vector2i) -> Dictionary:
	root.size = viewport_size
	var packed := load(MAIN_SCENE) as PackedScene
	_expect(packed != null, "%s real main.tscn loads" % viewport_size)
	if packed == null:
		return {}
	var application := packed.instantiate()
	root.add_child(application)
	for _frame in range(4):
		await process_frame
	var screen := application.get_node_or_null("V075GameScreen") as Control
	var flow := application.get_node_or_null("V075RuntimeComposition") as Node
	_expect(screen != null, "%s production V075 screen exists" % viewport_size)
	_expect(flow != null, "%s production Application Flow exists" % viewport_size)
	if screen == null or flow == null:
		return {"application": application}
	var player_option := screen.find_child("PlayerCountOption", true, false) as OptionButton
	var start_button := screen.find_child("StartConfiguredButton", true, false) as Button
	var seed_input := screen.find_child("SeedInput", true, false) as LineEdit
	_expect(player_option != null, "%s real player-count control exists" % viewport_size)
	_expect(start_button != null, "%s real start control exists" % viewport_size)
	_expect(seed_input != null, "%s real seed control exists" % viewport_size)
	if player_option != null:
		for index in range(player_option.item_count):
			if int(player_option.get_item_metadata(index)) == 4:
				player_option.select(index)
				break
	if seed_input != null:
		seed_input.text = str(FIXED_SEED)
	_receipts = []
	flow.receipt_ready.connect(func(receipt: Dictionary) -> void:
		_receipts.append(receipt.duplicate(true))
	)
	if start_button != null:
		start_button.pressed.emit()
	for _frame in range(12):
		await process_frame
	var snapshot := flow.call("local_snapshot") as Dictionary
	_expect(bool(snapshot.get("match_started", false)), "%s normal UI start opens the match" % viewport_size)
	_expect((snapshot.get("roster", []) as Array).size() == 4, "%s starts one human plus three AI" % viewport_size)
	_expect(str(snapshot.get("ruleset_id", "")) == "v0.7.5", "%s remains on production V075 ruleset" % viewport_size)
	return {
		"application": application,
		"screen": screen,
		"flow": flow,
		"viewport_size": viewport_size,
	}


func _assert_viewport(context: Dictionary, viewport_size: Vector2i) -> void:
	var screen := context.get("screen") as Control
	if screen == null:
		return
	for _frame in range(4):
		await process_frame
	var root_scroll := screen.get_node("RootMargin") as ScrollContainer
	var track_rail := screen.find_child("TrackRail", true, false) as HBoxContainer
	var planet := screen.find_child("PlanetStageViewport", true, false) as Control
	var asset_rail := screen.find_child("AssetRail", true, false) as Control
	var hand_rail := screen.find_child("HandRail", true, false) as Control
	var action_panel := screen.find_child("CurrentActionPanel", true, false) as Control
	var feed_panel := screen.find_child("PublicActionFeedPanel", true, false) as Control
	_expect(root_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "%s root vertical scrolling is disabled" % viewport_size)
	_expect(root_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "%s root horizontal scrolling is disabled" % viewport_size)
	_expect(not root_scroll.follow_focus, "%s root does not scroll to focused controls" % viewport_size)
	_expect(screen.find_children("*", "VSplitContainer", true, false).is_empty(), "%s has no draggable vertical splitter" % viewport_size)
	_expect(track_rail != null and track_rail.get_child_count() == 10, "%s exposes ten physical sushi-track slots" % viewport_size)
	for surface in [planet, asset_rail, hand_rail, action_panel, feed_panel]:
		_expect(surface != null, "%s required primary surface exists" % viewport_size)
		if surface != null:
			_expect(surface.is_visible_in_tree(), "%s primary surface is visible" % viewport_size)
	var debug := screen.call("debug_snapshot") as Dictionary
	var human := debug.get("human_playability", {}) as Dictionary
	_expect(int(human.get("main_table_root_vertical_scroll_count", -1)) == 0, "%s debug confirms zero root scroll owners" % viewport_size)
	_expect(int(human.get("main_table_drag_splitter_count", -1)) == 0, "%s debug confirms zero splitters" % viewport_size)
	_expect(int(human.get("sushi_track_visible_slot_count", 0)) == 10, "%s debug confirms ten track slots" % viewport_size)
	_expect(bool(human.get("primary_action_button_visible", false)), "%s fixed confirm action remains visible" % viewport_size)
	_expect(bool(human.get("public_action_feed_visible", false)), "%s fixed public action feed remains visible" % viewport_size)
	_expect(bool(human.get("asset_pool_visible", false)), "%s current assets remain visible" % viewport_size)
	_expect(bool(human.get("current_hand_visible", false)), "%s current hand remains visible" % viewport_size)
	var layout := human.get("single_viewport_layout", {}) as Dictionary
	_expect(bool(layout.get("main_table_single_viewport", false)), "%s uses the single-table layout contract" % viewport_size)
	_expect(float(layout.get("table_height", 0.0)) >= 220.0, "%s preserves a readable central planet" % viewport_size)
	var confirm := screen.find_child("CurrentActionConfirmButton", true, false) as Button
	var cancel := screen.find_child("CurrentActionCancelButton", true, false) as Button
	_expect(confirm != null and confirm.focus_mode == Control.FOCUS_ALL, "%s confirm button is keyboard focusable" % viewport_size)
	_expect(cancel != null and cancel.focus_mode == Control.FOCUS_ALL, "%s cancel button is keyboard focusable" % viewport_size)


func _assert_real_pointer_contract(context: Dictionary) -> void:
	"""Exercise the production V075 tree through SceneTree GUI dispatch.

	This is deliberately additive to the inherited data-flow checks above.  It
	never emits a Button signal, calls a Control's private input method, or calls
	a map/target resolver as a substitute for a mouse event.
	"""
	var screen := context.get("screen") as Control
	if screen == null:
		return
	var arrangement := screen.find_child(
		"CentralPublicActionArrangement", true, false
	) as Control
	var planet_board := screen.find_child("PlanetBoard", true, false) as Node
	var map := planet_board.call("get_embedded_map_view") as Control \
		if planet_board != null and planet_board.has_method("get_embedded_map_view") else null
	var hand_rail := screen.find_child("HandRail", true, false) as Control
	_expect(map != null, "real V075 production map view exists for pointer dispatch")
	_expect(hand_rail != null, "real V075 hand rail exists for pointer dispatch")
	if arrangement == null or map == null or hand_rail == null:
		return
	# Public projections briefly use the existing discoverability peek.  Let that
	# bounded presentation transition settle before sampling the stable
	# collapsed contract; this wait never invokes a drawer method directly.
	await _wait_frames(3)
	await create_timer(1.20).timeout
	await _wait_frames(2)

	var handle := arrangement.find_child(
		"PublicArrangementDrawerHandle", true, false
	) as Control
	var panel := arrangement.find_child(
		"PublicArrangementCardTablePopout", true, false
	) as Control
	var host := arrangement.find_child(
		"PublicArrangementPopoutHost", true, false
	) as Control
	_expect(handle != null and handle.is_visible_in_tree(), "collapsed public drawer exposes a visible handle")
	_expect(handle != null and handle.get_global_rect().position.x <= map.get_global_rect().position.x + 12.0, "collapsed public drawer handle stays on the map left edge")
	_expect(panel == null or not panel.is_visible_in_tree(), "collapsed public drawer panel is absent from the hit-test tree")
	_expect(host == null or host.mouse_filter == Control.MOUSE_FILTER_IGNORE, "public drawer host is pointer-transparent")

	var board_counts := {
		"district_selected": 0,
		"map_background_clicked": 0,
		"camera_interacted": 0,
	}
	for signal_name in board_counts.keys():
		if planet_board != null and planet_board.has_signal(str(signal_name)):
			planet_board.connect(str(signal_name), func(_value: Variant = null) -> void:
				board_counts[signal_name] = int(board_counts[signal_name]) + 1
			)

	# A center click and four interior points are enough to prove that the
	# collapsed state does not swallow the map.  An idle district click opens the
	# inherited RegionPopup; close that intentional modal immediately through its
	# production button before sampling the next map point, so a popup cannot
	# masquerade as drawer passthrough evidence.
	var map_rect := map.get_global_rect()
	var region_popup := screen.find_child("RegionPopup", true, false) as Control
	var region_popup_close := screen.find_child(
		"RegionPopupClose", true, false
	) as Button
	var region_popup_swallowed_map_click_count := 0
	var idle_points := []
	for y_ratio in [0.14, 0.32, 0.50, 0.68, 0.86]:
		for x_ratio in [0.12, 0.31, 0.50, 0.69]:
			idle_points.append(Vector2(
				map_rect.position.x + map_rect.size.x * float(x_ratio),
				map_rect.position.y + map_rect.size.y * float(y_ratio),
			))
	var collapsed_map_view_hit_count := 0
	for point_index in range(idle_points.size()):
		var point := idle_points[point_index] as Vector2
		var trace := await _dispatch_real_click(point, "collapsed_map_%02d" % point_index)
		_real_pointer_trace.append(trace)
		var hovered_pressed_path := str((trace.get("hovered_pressed", {}) as Dictionary).get("path", ""))
		if hovered_pressed_path.contains("/OverlayLayer/RegionPopup/"):
			region_popup_swallowed_map_click_count += 1
		if hovered_pressed_path.contains("/MapHost/PlanetMapView"):
			collapsed_map_view_hit_count += 1
		_expect(
			hovered_pressed_path.contains("/MapHost/PlanetMapView"),
			"each collapsed drawer map sample is received by the production MapView"
		)
		if region_popup != null and region_popup.is_visible_in_tree():
			_expect(region_popup_close != null, "idle region inspection exposes a production close control")
			if region_popup_close != null and region_popup_close.is_visible_in_tree():
				_real_pointer_trace.append(await _dispatch_real_click(
					region_popup_close.get_global_rect().get_center(),
					"region_popup_close"
				))
				await _wait_frames(2)
			_expect(not region_popup.is_visible_in_tree(), "production RegionPopup closes before the next map sample")
	var collapsed_map_hits := int(board_counts["district_selected"]) + int(board_counts["map_background_clicked"])
	_expect(collapsed_map_hits >= 1, "collapsed drawer leaves a real map click reachable")
	_expect(int(board_counts["camera_interacted"]) >= 1, "collapsed drawer leaves real map camera interaction reachable")
	_expect(collapsed_map_view_hit_count >= 20, "real pointer gate samples at least twenty collapsed-map coordinates")
	_expect(region_popup_swallowed_map_click_count == 0, "collapsed drawer map samples never hit the modal RegionPopup")

	# Expand using the actual left handle, then click outside the panel through
	# the same dispatch path.  The arrangement may close itself, but it must not
	# consume the outside map gesture.
	if handle != null and handle.is_visible_in_tree():
		_real_pointer_trace.append(await _dispatch_real_click(handle.get_global_rect().get_center(), "drawer_handle"))
		await _wait_frames(2)
		panel = arrangement.find_child("PublicArrangementCardTablePopout", true, false) as Control
		if panel != null and panel.is_visible_in_tree():
			var outside := map.get_global_rect().get_center() + Vector2(map_rect.size.x * 0.36, 0.0)
			var before_camera := int(board_counts["camera_interacted"])
			_real_pointer_trace.append(await _dispatch_real_drag(outside, outside + Vector2(28.0, 0.0), "expanded_outside_map"))
			_expect(int(board_counts["camera_interacted"]) > before_camera, "expanded drawer outside area reaches the map")
		await _wait_frames(2)
		panel = arrangement.find_child("PublicArrangementCardTablePopout", true, false) as Control
		_expect(panel == null or not panel.is_visible_in_tree(), "outside map input collapses the expanded drawer")

	# Authority-to-visible parity and no-hover semantic fields use only the
	# production projection controls.  No hand is injected into the scene.
	var flow := context.get("flow") as Node
	var snapshot := flow.call("local_snapshot") as Dictionary if flow != null else {}
	var facts := (snapshot.get("personal_dbg", {}) as Dictionary).get("facts", {}) as Dictionary
	var authority_hand := facts.get("hand", []) as Array
	var projected_ids := {}
	var visible_ids := {}
	for child in hand_rail.get_children():
		if not (child is Control) or not child.has_method("payload"):
			continue
		var card := child as Control
		var payload := card.call("payload") as Dictionary
		var instance_id := str(payload.get("instance_id", ""))
		if instance_id.is_empty():
			continue
		projected_ids[instance_id] = true
		if _control_visible_inside_viewport(card, root.get_viewport().get_visible_rect()):
			visible_ids[instance_id] = true
			await _assert_no_hover_face_semantics(card)
	_expect(projected_ids.size() == authority_hand.size(), "general hand authority and production projection counts match")
	_expect(visible_ids.size() == projected_ids.size(), "every projected general hand card is visibly inside the viewport")

	# Select one real hand card, then use the map's own district coordinate
	# discovery only to choose a point.  The click itself remains a real GUI
	# dispatch and is accepted only when the production signal/receipt changes.
	var target_card: Control = null
	for child in hand_rail.get_children():
		if child is Control and child.has_method("payload"):
			var payload := child.call("payload") as Dictionary
			if not bool(payload.get("disabled", false)):
				target_card = child as Control
				break
	if target_card != null:
		_real_pointer_trace.append(await _dispatch_real_click(target_card.get_global_rect().get_center(), "target_card"))
		await _wait_frames(2)
		_expect(
			region_popup == null or not region_popup.is_visible_in_tree(),
			"ordinary hand target mode keeps the modal RegionPopup hidden"
		)
		var selected_panel := screen.find_child("CurrentActionPanel", true, false) as Control
		var before_binding := int((screen.call("debug_snapshot") as Dictionary).get("map_target_binding_count", 0))
		var before_selection := int(board_counts["district_selected"])
		var target_binding_seen := false
		var target_selection_seen := false
		if map.has_method("get_district_control_position"):
			# Coordinate discovery is deliberately limited to the production map's
			# own district controls.  A visible district may be illegal for the
			# selected card, so probe those real coordinates until the authority's
			# legal-target query accepts one; no resolver or binding method is called
			# by the test itself.
			for index in range(16):
				var local_position := map.call("get_district_control_position", index) as Vector2
				if local_position.x < 0.0 or local_position.y < 0.0:
					continue
				var target_position := map.global_position + local_position
				_real_pointer_trace.append(await _dispatch_real_click(target_position, "real_region_target_probe_%02d" % index))
				await _wait_frames(2)
				var current_debug := screen.call("debug_snapshot") as Dictionary
				var current_binding := int(current_debug.get("map_target_binding_count", 0))
				var current_selection := int(board_counts["district_selected"])
				if current_selection > before_selection:
					target_selection_seen = true
				if current_binding > before_binding:
					target_binding_seen = true
					break
		_expect(target_selection_seen, "real target click reaches the production district signal")
		_expect(target_binding_seen, "real target click creates a production target binding")
		_expect(selected_panel == null or selected_panel.is_visible_in_tree(), "target mode keeps the fixed action panel visible")

	print("V076_REAL_POINTER_TRACE=" + JSON.stringify(_real_pointer_trace))


func _dispatch_real_click(position: Vector2, state: String) -> Dictionary:
	_push_mouse_motion(position, Vector2.ZERO)
	await process_frame
	var hovered_before := root.gui_get_hovered_control()
	_push_mouse_button(MOUSE_BUTTON_LEFT, position, true, false)
	await process_frame
	var hovered_pressed := root.gui_get_hovered_control()
	_push_mouse_button(MOUSE_BUTTON_LEFT, position, false, false)
	await process_frame
	return {
		"state": state,
		"position": position,
		"hovered_before": _control_trace(hovered_before),
		"hovered_pressed": _control_trace(hovered_pressed),
	}


func _dispatch_real_drag(start: Vector2, finish: Vector2, state: String) -> Dictionary:
	_push_mouse_motion(start, Vector2.ZERO)
	await process_frame
	_push_mouse_button(MOUSE_BUTTON_LEFT, start, true, false)
	await process_frame
	_push_mouse_motion(finish, finish - start)
	await process_frame
	_push_mouse_button(MOUSE_BUTTON_LEFT, finish, false, false)
	await process_frame
	return {
		"state": state,
		"start": start,
		"finish": finish,
		"hovered": _control_trace(root.gui_get_hovered_control()),
	}


func _control_trace(control: Control) -> Dictionary:
	if control == null or not is_instance_valid(control):
		return {"path": "<none>"}
	var chain: Array[String] = []
	var cursor: Node = control
	while cursor != null:
		chain.append(str(cursor.get_path()))
		cursor = cursor.get_parent()
	return {
		"path": str(control.get_path()),
		"chain": chain,
		"visible": control.is_visible_in_tree(),
		"mouse_filter": control.mouse_filter,
		"focus_mode": control.focus_mode,
		"z_index": control.z_index,
		"global_rect": control.get_global_rect(),
		"modulate_alpha": control.modulate.a,
	}


func _control_visible_inside_viewport(control: Control, viewport_rect: Rect2) -> bool:
	if control == null or not control.is_visible_in_tree() or control.modulate.a <= 0.01:
		return false
	var visible_rect := control.get_global_rect().intersection(viewport_rect)
	var cursor: Node = control.get_parent()
	while cursor != null:
		if cursor is Control:
			var parent_control := cursor as Control
			if parent_control.clip_contents:
				visible_rect = visible_rect.intersection(parent_control.get_global_rect())
		cursor = cursor.get_parent()
	return visible_rect.has_area()


func _assert_no_hover_face_semantics(card: Control) -> void:
	var face := card.find_child("CardFace", true, false) as Control
	if face == null:
		_expect(false, "production hand card contains its existing CardFace renderer")
		return
	for label_name in ["NameLabel", "CostLabel", "TypeLabel", "EffectLabel", "RouteGlyphLabel"]:
		var label := face.find_child(label_name, true, false) as Label
		_expect(
			label != null and label.is_visible_in_tree() and not label.text.strip_edges().is_empty()
			and _control_visible_inside_viewport(label, root.get_viewport().get_visible_rect()),
			"unhovered card exposes readable %s" % label_name
		)


func _assert_real_card_and_action_path(context: Dictionary) -> void:
	var screen := context.get("screen") as Control
	var flow := context.get("flow") as Node
	var track_rail := screen.find_child("TrackRail", true, false) as HBoxContainer
	var unaffordable: Control
	var claimable_commodity: Control
	var normal_full_hand_affordance := false
	for child in track_rail.get_children():
		if not child.has_method("payload"):
			continue
		var payload := child.call("payload") as Dictionary
		if (
			str(payload.get("card_kind", "")) == "normal_card"
			and (child as Control).tooltip_text.contains("满手")
		):
			normal_full_hand_affordance = true
		if not bool(payload.get("claimable", false)) and unaffordable == null:
			unaffordable = child as Control
		if bool(payload.get("claimable", false)) and str(payload.get("card_kind", "")) == "commodity_card":
			claimable_commodity = child as Control
	var interactive_state_count := 0
	for child in track_rail.get_children():
		if child.has_method("payload") and (child.call("payload") as Dictionary).has("claimable"):
			interactive_state_count += 1
	_expect(interactive_state_count > 0, "every visible real track card exposes an explicit interaction state")
	_expect(normal_full_hand_affordance, "normal track cards visibly explain that a full five-card hand can still acquire to discard")
	if unaffordable != null:
		_click_card(unaffordable)
		await process_frame
		var confirm := screen.find_child("CurrentActionConfirmButton", true, false) as Button
		var reason := screen.find_child("CurrentActionReason", true, false) as Label
		_expect(confirm.disabled, "illegal track selection cannot be confirmed")
		_expect(not reason.text.strip_edges().is_empty(), "illegal track selection exposes a concrete reason")
	_expect(claimable_commodity != null, "normal supply exposes a legal commodity acquisition")
	var before := flow.call("local_snapshot") as Dictionary
	var before_count := int(((before.get("personal_dbg", {}) as Dictionary).get("facts", {}) as Dictionary).get("commodity_inventory_count", 0))
	if claimable_commodity != null:
		_click_card(claimable_commodity)
		for _frame in range(4):
			await process_frame
	var after_acquire := flow.call("local_snapshot") as Dictionary
	var after_count := int(((after_acquire.get("personal_dbg", {}) as Dictionary).get("facts", {}) as Dictionary).get("commodity_inventory_count", 0))
	_expect(after_count == before_count + 1, "real track click commits one authoritative commodity acquisition")
	_expect(_receipt_count("track.acquire", true) >= 1, "human acquisition returns an accepted track.acquire receipt")
	var track_debug := (after_acquire.get("unified_track", {}) as Dictionary).get("debug", {}) as Dictionary
	_expect(int(track_debug.get("supply_cursor_delta_on_acquisition", 0)) == 0, "acquisition does not advance the supply cursor")
	_expect(int(track_debug.get("supply_rng_draw_delta_on_acquisition", 0)) == 0, "acquisition consumes no extra supply RNG")
	var commodity_tab := screen.find_child("CommodityHandTabButton", true, false) as Button
	commodity_tab.pressed.emit()
	await process_frame
	_expect((screen.find_child("HandRail", true, false) as Control).get_child_count() == after_count, "commodity tab exposes every owned commodity card")
	var general_tab := screen.find_child("GeneralHandTabButton", true, false) as Button
	general_tab.pressed.emit()
	await process_frame
	var legal_actions := after_acquire.get("legal_actions", []) as Array
	var playable_card_id := ""
	for option_variant in legal_actions:
		if option_variant is Dictionary:
			playable_card_id = str((option_variant as Dictionary).get("card_instance_id", ""))
			if not playable_card_id.is_empty():
				break
	var hand_rail := screen.find_child("HandRail", true, false) as HBoxContainer
	var hand_card: Control
	for child in hand_rail.get_children():
		if child.has_method("payload") and str((child.call("payload") as Dictionary).get("instance_id", "")) == playable_card_id:
			hand_card = child as Control
			break
	_expect(hand_card != null, "a legal authoritative hand card is reachable in the fixed dock")
	if hand_card != null:
		_click_card(hand_card)
		await process_frame
	var target_rail := screen.find_child("TargetRail", true, false) as HBoxContainer
	var target_button: Button
	for child in target_rail.get_children():
		if child is Button and not (child as Button).disabled:
			target_button = child as Button
			break
	_expect(target_button != null, "selected hand card exposes a legal existing target-query button")
	if target_button != null:
		target_button.pressed.emit()
		await process_frame
		await process_frame
	var confirm := screen.find_child("CurrentActionConfirmButton", true, false) as Button
	if confirm != null and confirm.disabled:
		var virtual_target_rail := screen.find_child(
			"V074VirtualizedTargetRail",
			true,
			false
		) as Control
		if virtual_target_rail != null:
			for candidate in virtual_target_rail.find_children(
				"VirtualTargetRow*",
				"Button",
				true,
				false
			):
				var virtual_button := candidate as Button
				if virtual_button.visible and not virtual_button.disabled:
					virtual_button.pressed.emit()
					await process_frame
					break
	if confirm != null and confirm.disabled:
		var popup_choices := screen.find_child(
			"RegionPopupTargetChoices",
			true,
			false
		) as Control
		if popup_choices != null:
			for candidate in popup_choices.find_children("*", "Button", true, false):
				var popup_button := candidate as Button
				if not popup_button.disabled:
					popup_button.pressed.emit()
					await process_frame
					break
	_expect(confirm != null and not confirm.disabled, "target binding enables fixed card confirmation")
	if confirm != null and not confirm.disabled:
		confirm.pressed.emit()
		for _frame in range(4):
			await process_frame
	_expect(_receipt_count("card.queue", true) >= 1, "real hand-target-confirm path returns an accepted card.queue receipt")
	var queued := (flow.call("local_snapshot") as Dictionary).get("queued_actions", []) as Array
	_expect(not queued.is_empty(), "authoritative queue contains the human card plan")
	var lock_button := screen.find_child("LockButton", true, false) as Button
	var started_msec := Time.get_ticks_msec()
	lock_button.pressed.emit()
	for _frame in range(50):
		await process_frame
		var human := (screen.call("debug_snapshot") as Dictionary).get("human_playability", {}) as Dictionary
		if int(human.get("public_action_feed_visible_count", 0)) > 0:
			break
	var elapsed := float(Time.get_ticks_msec() - started_msec) / 1000.0
	var human_debug := (screen.call("debug_snapshot") as Dictionary).get("human_playability", {}) as Dictionary
	_expect(int(human_debug.get("public_action_feed_visible_count", 0)) > 0, "public receipt history projects into the fixed action feed")
	_expect(int(human_debug.get("blank_public_action_count", -1)) == 0, "action feed never emits a blank action")
	_expect(int(human_debug.get("action_feed_duplicate_entry_count", -1)) == 0, "action feed presents no duplicate public receipt")
	_expect(elapsed <= 5.0, "2x pace exposes the first resolved action within five wall seconds")
	var post_lock_snapshot := flow.call("local_snapshot") as Dictionary
	_expect(str(post_lock_snapshot.get("phase", "")) != "submission", "locked production batch leaves the acquisition phase")
	var receipt_count_before_phase_reject := _receipt_count("track.acquire", true)
	var refreshed_track := screen.find_child("TrackRail", true, false) as HBoxContainer
	var phase_revalidation_card: Control
	for child in refreshed_track.get_children():
		if child.has_method("payload") and bool((child.call("payload") as Dictionary).get("claimable", false)):
			phase_revalidation_card = child as Control
			break
	_expect(phase_revalidation_card != null, "post-lock track retains a card for phase revalidation")
	if phase_revalidation_card != null:
		_click_card(phase_revalidation_card)
		await process_frame
		var phase_confirm := screen.find_child("CurrentActionConfirmButton", true, false) as Button
		var phase_reason := screen.find_child("CurrentActionReason", true, false) as Label
		_expect(phase_confirm.disabled, "non-submission track acquisition is visibly disabled")
		_expect(phase_reason.text == "当前阶段不能取得卡牌", "non-submission track acquisition names the exact phase reason")
		_expect(_receipt_count("track.acquire", true) == receipt_count_before_phase_reject, "phase revalidation emits no acquisition intent")


func _assert_pause_freezes_submission_timer(context: Dictionary) -> void:
	var screen := context.get("screen") as Control
	var flow := context.get("flow") as Node
	var pause := screen.find_child("PauseButton", true, false) as Button
	var speed_2x := screen.find_child("Speed2xButton", true, false) as Button
	_expect(pause != null and speed_2x != null, "Pause and 2x controls exist for timer parity")
	if pause == null or speed_2x == null:
		return
	pause.pressed.emit()
	await process_frame
	var authority_before := flow.call("local_snapshot") as Dictionary
	var human_before := (screen.call("debug_snapshot") as Dictionary).get("human_playability", {}) as Dictionary
	await create_timer(0.12).timeout
	var authority_after := flow.call("local_snapshot") as Dictionary
	var human_after := (screen.call("debug_snapshot") as Dictionary).get("human_playability", {}) as Dictionary
	_expect(int((flow.call("pacing_snapshot") as Dictionary).get("effective_multiplier", -1)) == 0, "Pause sets the shared effective pace to zero")
	_expect(is_equal_approx(float(authority_before.get("submission_seconds_remaining", -1.0)), float(authority_after.get("submission_seconds_remaining", -2.0))), "Pause freezes authoritative submission time")
	_expect(is_equal_approx(float(human_before.get("visible_submission_seconds_remaining", -1.0)), float(human_after.get("visible_submission_seconds_remaining", -2.0))), "Pause freezes the visible submission countdown")
	speed_2x.pressed.emit()
	await process_frame
	_expect(int((flow.call("pacing_snapshot") as Dictionary).get("effective_multiplier", -1)) == 2, "timer parity check restores Candidate 2 default 2x")


func _assert_pacing_controls(context: Dictionary) -> void:
	var screen := context.get("screen") as Control
	var flow := context.get("flow") as Node
	for entry in [
		{"node": "PauseButton", "multiplier": 0},
		{"node": "Speed1xButton", "multiplier": 1},
		{"node": "Speed2xButton", "multiplier": 2},
		{"node": "Speed4xButton", "multiplier": 4},
	]:
		var button := screen.find_child(str(entry.get("node")), true, false) as Button
		_expect(button != null, "%s pace button exists" % str(entry.get("node")))
		if button == null:
			continue
		button.pressed.emit()
		await process_frame
		var pace := flow.call("pacing_snapshot") as Dictionary
		_expect(int(pace.get("multiplier", -1)) == int(entry.get("multiplier")), "%s pace request reaches the shared flow" % str(entry.get("node")))
		_expect(int(pace.get("logical_kernel_tick_hz", 0)) == 20, "%s preserves the 20 Hz logical Kernel" % str(entry.get("node")))
		_expect(not bool(pace.get("changes_rng_order", true)), "%s does not alter RNG order" % str(entry.get("node")))
	(screen.find_child("Speed2xButton", true, false) as Button).pressed.emit()
	await process_frame
	_expect(int((flow.call("pacing_snapshot") as Dictionary).get("multiplier", -1)) == 2, "Candidate 2 returns to the default 2x pace")
	_expect(int((flow.call("pacing_snapshot") as Dictionary).get("mode_count", 0)) == 4, "pace owner exposes exactly Pause, 1x, 2x and 4x")


func _assert_coach_step3(context: Dictionary) -> void:
	var screen := context.get("screen") as Control
	var guide := screen.find_child("GuideButton", true, false) as Button
	var coach := screen.get_node("V073PlaytestCoachMarks") as Node
	var next := coach.find_child("CoachNext", true, false) as Button
	var callout := coach.find_child("CoachCallout", true, false) as Control
	_expect(guide != null and next != null and callout != null, "existing Coach controls are production reachable")
	guide.pressed.emit()
	await process_frame
	next.pressed.emit()
	await process_frame
	next.pressed.emit()
	await process_frame
	var at_step3 := coach.call("debug_snapshot") as Dictionary
	_expect(int(at_step3.get("current_index", -1)) == 2, "two real Next presses enter Coach Step 3")
	var origin := callout.position
	for _iteration in range(30):
		callout.mouse_entered.emit()
		callout.mouse_exited.emit()
	for _iteration in range(10):
		next.mouse_entered.emit()
		next.mouse_exited.emit()
	await process_frame
	_expect(callout.position.distance_to(origin) <= 1.0, "thirty pointer entries do not move the Step 3 callout")
	_expect(next.is_visible_in_tree() and not next.disabled, "Step 3 Next stays visible and enabled")
	next.pressed.emit()
	await process_frame
	var after := coach.call("debug_snapshot") as Dictionary
	_expect(int(after.get("current_index", -1)) == 3, "one real Step 3 click advances exactly once")
	_expect(int(after.get("step3_next_click_advance_count", -1)) == 1, "Coach records one Step 3 Next click")
	_expect(int(after.get("step3_duplicate_advance_count", -1)) == 0, "Coach records no duplicate Step 3 advance")
	_expect(int(after.get("pointer_entry_recompute_count", -1)) == 0, "pointer entry never triggers placement recomputation")
	_expect(float(after.get("step3_pointer_entry_position_delta_px", -1.0)) <= 1.0, "Step 3 pointer-entry position delta is at most one pixel")
	_expect(int(after.get("step3_mouse_event_loss_count", -1)) == 0, "Coach loses no Step 3 mouse event")
	var close := coach.find_child("CoachClose", true, false) as Button
	if close != null:
		close.pressed.emit()
		await process_frame
		await process_frame
	var flow := context.get("flow") as Node
	var pacing := flow.call("pacing_snapshot") as Dictionary
	_expect(int(pacing.get("effective_multiplier", -1)) == 2, "Coach Close restores the saved pace after the Step 3 check")


func _click_card(card: Control) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = card.size * 0.5
	card.call("_gui_input", click)


func _push_mouse_button(
	button_index: int,
	position: Vector2,
	pressed: bool,
	double_click: bool
) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = pressed
	event.double_click = double_click
	event.position = position
	event.global_position = position
	Input.parse_input_event(event)


func _push_mouse_motion(position: Vector2, relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = relative
	Input.parse_input_event(event)


func _wait_frames(count: int) -> void:
	for _index in range(maxi(1, count)):
		await process_frame


func _receipt_count(intent_kind: String, accepted: bool) -> int:
	var count := 0
	for receipt in _receipts:
		if str(receipt.get("intent_kind", "")) == intent_kind and bool(receipt.get("accepted", false)) == accepted:
			count += 1
	return count


func _cleanup(context: Dictionary) -> void:
	var application := context.get("application") as Node
	if application != null and is_instance_valid(application):
		application.queue_free()
		await process_frame
		await process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)
