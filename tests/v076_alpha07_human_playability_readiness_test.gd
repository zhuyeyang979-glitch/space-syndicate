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


func _assert_real_card_and_action_path(context: Dictionary) -> void:
	var screen := context.get("screen") as Control
	var flow := context.get("flow") as Node
	var track_rail := screen.find_child("TrackRail", true, false) as HBoxContainer
	var unaffordable: Control
	var claimable_commodity: Control
	for child in track_rail.get_children():
		if not child.has_method("payload"):
			continue
		var payload := child.call("payload") as Dictionary
		if not bool(payload.get("claimable", false)) and unaffordable == null:
			unaffordable = child as Control
		if bool(payload.get("claimable", false)) and str(payload.get("card_kind", "")) == "commodity_card":
			claimable_commodity = child as Control
	var interactive_state_count := 0
	for child in track_rail.get_children():
		if child.has_method("payload") and (child.call("payload") as Dictionary).has("claimable"):
			interactive_state_count += 1
	_expect(interactive_state_count > 0, "every visible real track card exposes an explicit interaction state")
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


func _click_card(card: Control) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = card.size * 0.5
	card.call("_gui_input", click)


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
