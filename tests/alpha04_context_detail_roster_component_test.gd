extends SceneTree

const ROSTER_SCENE := preload("res://scenes/ui/table/PlayerRoster.tscn")
const DETAIL_SCENE := preload("res://scenes/ui/table/ContextDetailPopup.tscn")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_roster_receipt_selection()
	await _test_context_actions_and_privacy()
	_finish()


func _test_roster_receipt_selection() -> void:
	var roster := ROSTER_SCENE.instantiate() as SpaceSyndicatePlayerRoster
	root.add_child(roster)
	await process_frame
	var requested: Array[int] = []
	roster.player_inspection_requested.connect(func(player_index: int) -> void: requested.append(player_index))
	roster.bind_viewer(2, 9)
	var projection := _roster_projection()
	_expect(roster.apply_projection(projection), "typed public roster projection applies")
	var initial := roster.debug_snapshot()
	_expect(int(initial.get("columns", 0)) == 1 and int(initial.get("player_count", 0)) == 4, "four-player roster uses one left-side column")
	_expect((initial.get("public_order", []) as Array) == [0, 1, 2, 3], "public order remains stable instead of rotating the viewer first")
	_expect(int(initial.get("viewer_marker_count", 0)) == 1 and int(initial.get("selected_player_index", -1)) == 2, "one viewer marker exists and initial selection is local")
	_expect(bool(initial.get("focus_links_valid", false)), "roster buttons expose deterministic keyboard focus links")

	_expect(roster.request_player_inspection(3), "programmatic inspection request accepts an authorized public player")
	_expect(requested == [3] and int(roster.debug_snapshot().get("selected_player_index", -1)) == 2, "request emits intent without optimistic visual selection")
	var receipt := TableSelectionReceipt.new()
	receipt.request_id = "inspect-player-3"
	receipt.accepted = true
	receipt.applied = true
	receipt.selection_kind = TableSelectionIntent.KIND_INSPECT_PLAYER
	receipt.viewer_index = 2
	receipt.inspected_player_index = 3
	receipt.selection_revision_before = 4
	receipt.selection_revision_after = 5
	_expect(roster.apply_selection_receipt(receipt), "accepted typed inspection receipt updates selection")
	_expect(int(roster.debug_snapshot().get("selected_player_index", -1)) == 3 and requested == [3], "receipt sync emits no second inspection request")
	_expect(not roster.apply_selection_receipt(receipt), "duplicate receipt revision is rejected")
	var hostile_receipt := TableSelectionReceipt.new()
	hostile_receipt.accepted = true
	hostile_receipt.applied = true
	hostile_receipt.selection_kind = TableSelectionIntent.KIND_INSPECT_PLAYER
	hostile_receipt.viewer_index = 7
	hostile_receipt.inspected_player_index = 1
	hostile_receipt.selection_revision_after = 6
	_expect(not roster.apply_selection_receipt(hostile_receipt), "receipt for another viewer fails closed")

	var keyboard_button := _roster_button(roster, 1)
	_expect(keyboard_button != null and keyboard_button.focus_mode == Control.FOCUS_ALL, "public roster row is keyboard focusable")
	if keyboard_button != null:
		keyboard_button.grab_focus()
		await process_frame
		var pressed := InputEventKey.new()
		pressed.keycode = KEY_ENTER
		pressed.pressed = true
		Input.parse_input_event(pressed)
		await process_frame
		var released := InputEventKey.new()
		released.keycode = KEY_ENTER
		released.pressed = false
		Input.parse_input_event(released)
		await process_frame
	_expect(requested == [3, 1], "focused Enter preserves the inspection request behavior")
	_expect(int(roster.debug_snapshot().get("selected_player_index", -1)) == 3, "keyboard request also waits for its authority receipt")

	var three_players := _roster_projection_for_count(3, 13)
	_expect(roster.apply_projection(three_players), "three-player production roster projection applies")
	var three_debug := roster.debug_snapshot()
	_expect(int(three_debug.get("columns", 0)) == 1 \
		and int(three_debug.get("player_count", 0)) == 3 \
		and (three_debug.get("public_order", []) as Array) == [0, 1, 2], "three-player roster keeps one ordered column")
	var five_players := _roster_projection_for_count(5, 14)
	_expect(roster.apply_projection(five_players), "five-player production roster projection applies")
	var five_debug := roster.debug_snapshot()
	_expect(int(five_debug.get("columns", 0)) == 2 \
		and int(five_debug.get("player_count", 0)) == 5 \
		and (five_debug.get("public_order", []) as Array) == [0, 1, 2, 3, 4], "five-player roster switches to two ordered columns")
	var eight_players := _roster_projection_for_count(8, 15)
	_expect(roster.apply_projection(eight_players), "eight-player production roster projection applies")
	var eight_debug := roster.debug_snapshot()
	_expect(int(eight_debug.get("columns", 0)) == 2 \
		and int(eight_debug.get("player_count", 0)) == 8 \
		and (eight_debug.get("public_order", []) as Array) == [0, 1, 2, 3, 4, 5, 6, 7] \
		and int(eight_debug.get("viewer_marker_count", 0)) == 1, "eight-player roster keeps two columns, stable public order, and one local marker")

	var hostile_projection := _roster_projection_for_count(8, 16)
	(hostile_projection.get("players", []) as Array)[0]["rival_cash"] = 987654
	_expect(not roster.apply_projection(hostile_projection), "roster rejects a private rival-cash field")
	roster.queue_free()
	await process_frame


func _test_context_actions_and_privacy() -> void:
	var popup := DETAIL_SCENE.instantiate() as SpaceSyndicateContextDetailPopup
	root.add_child(popup)
	await process_frame
	var action_ids: Array[String] = []
	var intent_capture := {"count": 0, "intent": null}
	popup.action_requested.connect(func(action_id: String) -> void: action_ids.append(action_id))
	popup.application_intent_requested.connect(func(intent: IntelApplicationIntent) -> void:
		intent_capture["count"] = int(intent_capture.get("count", 0)) + 1
		intent_capture["intent"] = intent
	)
	popup.bind_viewer(2, 9)
	var projection := _context_projection()
	_expect(popup.apply_projection(projection), "viewer-safe typed context projection applies")
	var snapshot := popup.debug_snapshot()
	_expect(int(snapshot.get("action_entry_count", 0)) == 1 and int(snapshot.get("deep_link_entry_count", 0)) == 1, "typed action and deep-link rows render exactly once")
	_expect(not bool(snapshot.get("mutates_gameplay", true)), "context popup owns no gameplay mutation")
	var action_button := popup.get_node_or_null("DetailMargin/DetailRows/DetailActions/ContextAction") as Button
	var deep_link_button := popup.get_node_or_null("DetailMargin/DetailRows/DetailDeepLinks/ContextDeepLink") as Button
	_expect(action_button != null and deep_link_button != null, "action surfaces are editable scene descendants")
	if action_button != null:
		action_button.pressed.emit()
	if deep_link_button != null:
		deep_link_button.pressed.emit()
	_expect(action_ids == ["card.inspect-targets"], "ordinary action forwards only its stable action id")
	var forwarded_intent := intent_capture.get("intent") as IntelApplicationIntent
	_expect(int(intent_capture.get("count", 0)) == 1 and forwarded_intent != null and forwarded_intent.is_valid(), "deep link forwards one validated application intent")

	var hostile_projection := projection.duplicate(true)
	hostile_projection["hidden_owner"] = "private-owner"
	_expect(not popup.apply_projection(hostile_projection), "context popup rejects hidden owner data")
	var malformed_action := projection.duplicate(true)
	(malformed_action.get("actions", []) as Array)[0].erase("application_intent")
	_expect(not popup.apply_projection(malformed_action), "context action rows require an exact closed schema")
	var object_projection := projection.duplicate(true)
	object_projection["body"] = Node.new()
	_expect(not popup.apply_projection(object_projection), "runtime Object values fail the closed-data gate")
	(object_projection.get("body") as Node).free()
	popup.queue_free()
	await process_frame


func _roster_projection() -> Dictionary:
	return _roster_projection_for_count(4, 12)


func _roster_projection_for_count(player_count: int, source_revision: int) -> Dictionary:
	var players: Array = []
	# Deliberately feed viewer-first rows so the target must restore public order.
	players.append(_player(2, 2, true))
	for player_index in range(player_count):
		if player_index == 2:
			continue
		players.append(_player(player_index, player_index, false))
	return {
		"schema_version": 1,
		"source_revision": source_revision,
		"viewer_index": 2,
		"authorization_revision": 9,
		"visibility_scope": "viewer_scoped_public",
		"players": players,
	}


func _player(player_index: int, public_order_index: int, local: bool) -> Dictionary:
	return {
		"player_index": player_index,
		"public_order_index": public_order_index,
		"public_player_name": "玩家 %d" % (player_index + 1),
		"role_name": "星际商会",
		"player_color": Color("#38bdf8") if local else Color("#94a3b8"),
		"is_local_player": local,
		"public_status": "ready",
		"is_publicly_active": false,
		"public_activity_is_anonymous": true,
	}


func _context_projection() -> Dictionary:
	return {
		"schema_version": 1,
		"source_revision": 27,
		"viewer_index": 2,
		"authorization_revision": 9,
		"visibility_scope": "viewer_private",
		"context_kind": "hand_card",
		"context_id": "card-instance-4",
		"title": "轨道融资",
		"subtitle": "经济牌｜合法目标 2",
		"body": "选择合法设施后，通过正式行动入口提交。",
		"chips": [{"text": "可打出", "tooltip": "当前满足条件", "accent": "#86efac"}],
		"actions": [{
			"id": "card.inspect-targets",
			"label": "查看目标",
			"disabled": false,
			"tooltip": "只查看当前合法目标。",
			"application_intent": {},
		}],
		"deep_links": [{
			"id": "intel.open",
			"label": "情报详情",
			"disabled": false,
			"tooltip": "打开公开情报档案。",
			"application_intent": IntelApplicationIntent.open("card-history:2", "region.1").to_dictionary(),
		}],
	}


func _roster_button(roster: SpaceSyndicatePlayerRoster, player_index: int) -> Button:
	var grid := roster.get_node_or_null("RosterMargin/RosterRows/RosterScroll/RosterGrid")
	if grid == null:
		return null
	for child in grid.get_children():
		if child is Button and int(child.get_meta("public_player_index", -1)) == player_index:
			return child as Button
	return null


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("ALPHA04_CONTEXT_DETAIL_ROSTER_COMPONENT_TEST|status=%s|checks=%d|failures=%d" % [status, _checks, _failures.size()])
	for failure in _failures:
		push_error("ALPHA04_CONTEXT_DETAIL_ROSTER_COMPONENT_TEST: %s" % failure)
	quit(0 if _failures.is_empty() else 1)
