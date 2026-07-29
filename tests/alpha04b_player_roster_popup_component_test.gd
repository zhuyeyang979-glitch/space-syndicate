extends SceneTree

const SERVICE := preload(
	"res://scripts/presentation/public_player_roster_projection_service.gd"
)
const ROSTER_SCENE := preload("res://scenes/ui/table/PlayerRosterPanel.tscn")
const POPUP_SCENE := preload("res://scenes/ui/table/PlayerInspectionPopup.tscn")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var service := SERVICE.new() as PublicPlayerRosterProjectionService
	var public_players := _public_players(8)
	var panel := ROSTER_SCENE.instantiate() as SpaceSyndicatePlayerRosterPanel
	var popup := POPUP_SCENE.instantiate() as SpaceSyndicatePlayerInspectionPopup
	_expect(panel != null and popup != null, "roster and inspection scenes instantiate")
	if panel == null or popup == null:
		_finish()
		return
	root.add_child(panel)
	panel.position = Vector2(20, 18)
	panel.size = Vector2(184, 650)
	root.add_child(popup)
	_expect(panel.bind_viewer(2, 7) and popup.bind_viewer(2, 7), "both surfaces bind one viewer authorization")
	await _frames(2)

	var revision := 1
	for player_count in [3, 4, 5, 8]:
		var projection := service.compose_roster(
			public_players.slice(0, player_count),
			2,
			7,
			revision,
			1,
			"unlocked"
		)
		_expect(panel.apply_projection(projection), "%d-player projection applies" % player_count)
		await _frames(2)
		var layout_debug := panel.debug_snapshot()
		_expect(
			int(layout_debug.get("column_count", 0)) == (1 if player_count <= 4 else 2),
			"%d players use the required column count" % player_count
		)
		_expect(
			float(layout_debug.get("panel_rendered_width", 999.0)) <= 190.0
				and float(layout_debug.get("maximum_entry_width", 999.0)) \
				<= (86.0 if player_count >= 5 else 172.0),
			"%d-player roster stays within the compact 184px lane" % player_count
		)
		_expect(
			layout_debug.get("public_order_indices", []) == range(player_count)
				and (layout_debug.get("ordered_player_ids", []) as Array)[0] == "player.0"
				and (layout_debug.get("ordered_player_ids", []) as Array)[2] == "player.2",
			"%d-player layout preserves public order and does not rotate viewer player.2 first" % player_count
		)
		revision += 1

	var before_reuse := panel.debug_snapshot()
	var before_instance_ids: Array = before_reuse.get("node_instance_ids", []) as Array
	var updated_players := public_players.duplicate(true)
	(updated_players[0] as Dictionary)["public_status"] = "waiting"
	var updated_roster := service.compose_roster(updated_players, 2, 7, revision, 1)
	_expect(panel.apply_projection(updated_roster), "new roster revision applies")
	await _frames(2)
	var after_reuse := panel.debug_snapshot()
	_expect(
		after_reuse.get("node_instance_ids", []) == before_instance_ids,
		"new signatures update eight stable player entry nodes in place"
	)
	var render_count := int(after_reuse.get("render_count", -1))
	_expect(panel.apply_projection(updated_roster), "duplicate roster projection is accepted idempotently")
	_expect(
		int(panel.debug_snapshot().get("render_count", -1)) == render_count,
		"duplicate signature does not rebuild roster nodes"
	)

	var requested_ids: Array[String] = []
	panel.player_inspection_requested.connect(func(player_id: String) -> void:
		requested_ids.append(player_id)
	)
	var entry_zero := panel.entry_for_player_id("player.0")
	var entry_one := panel.entry_for_player_id("player.1")
	var entry_two := panel.entry_for_player_id("player.2")
	_expect(
		entry_zero != null and entry_one != null and entry_two != null,
		"stable public player entries are addressable by player identity"
	)
	if entry_zero != null and entry_one != null and entry_two != null:
		await _click_control(entry_zero)
		await _confirm_key(entry_one, KEY_ENTER)
		await _confirm_action(entry_two)
		_expect(
			requested_ids == ["player.0", "player.1", "player.2"],
			"mouse, keyboard, and mapped gamepad confirm each request exactly one inspection"
		)
		_expect(
			panel.focus_first_entry()
				and entry_zero.focus_mode == Control.FOCUS_ALL
				and not entry_zero.focus_next.is_empty(),
			"roster entries expose a connected keyboard/gamepad focus path"
		)

	var history_intent := {
		"kind": "open_intel",
		"focused_history_entry_id": "card-history:3",
		"focused_region_id": "",
	}
	var table_intent := {
		"request_id": "popup-component-test",
		"action_kind": "compendium_hub",
		"source_surface": "player_roster",
		"target_card_name": "",
	}
	var popup_zero := service.compose_inspection(
		public_players[0] as Dictionary,
		2,
		7,
		20,
		_summaries("玩家一"),
		[_history_link(history_intent)],
		[table_intent]
	)
	var popup_one := service.compose_inspection(
		public_players[1] as Dictionary,
		2,
		7,
		20,
		_summaries("玩家二"),
		[_history_link(history_intent)],
		[table_intent]
	)
	_expect(
		popup.toggle_projection(popup_zero)
			and popup.visible
			and popup.current_player_id() == "player.0",
		"first player opens the transient inspection popup"
	)
	_expect(
		popup.toggle_projection(popup_one)
			and popup.visible
			and popup.current_player_id() == "player.1",
		"different player switches the open popup at the same public revision"
	)
	var navigation_requests: Array[Dictionary] = []
	popup.navigation_intent_requested.connect(func(intent: Dictionary) -> void:
		navigation_requests.append(intent.duplicate(true))
	)
	await _frames(1)
	var navigation_host := popup.find_child("NavigationRows", true, false) as VBoxContainer
	var first_navigation_button := navigation_host.get_child(0) as Button \
		if navigation_host != null and navigation_host.get_child_count() > 0 else null
	if first_navigation_button != null:
		await _confirm_action(first_navigation_button)
	_expect(
		navigation_requests.size() == 1
			and str(navigation_requests[0].get("kind", "")) == "open_intel",
		"focused popup navigation emits one unchanged public intent through ui_accept"
	)
	var first_popup_debug := popup.debug_snapshot()
	var navigation_ids: Array = first_popup_debug.get(
		"navigation_node_instance_ids",
		[]
	) as Array
	var popup_one_updated := service.compose_inspection(
		public_players[1] as Dictionary,
		2,
		7,
		21,
		_summaries("玩家二更新"),
		[_history_link(history_intent)],
		[table_intent]
	)
	_expect(popup.show_projection(popup_one_updated), "new inspection signature applies")
	_expect(
		popup.debug_snapshot().get("navigation_node_instance_ids", []) == navigation_ids,
		"inspection revision reuses stable public navigation nodes"
	)
	_expect(
		popup.toggle_projection(popup_one_updated) and not popup.visible,
		"selecting the same player toggles the popup closed"
	)

	var popup_zero_reopen := service.compose_inspection(
		public_players[0] as Dictionary,
		2,
		7,
		22,
		_summaries("玩家一更新"),
		[_history_link(history_intent)],
		[table_intent]
	)
	_expect(
		popup.show_projection(popup_zero_reopen) and popup.visible,
		"popup reopens for escape test"
	)
	await _escape_via_viewport()
	_expect(
		not popup.visible and str(popup.debug_snapshot().get("last_close_reason", "")) == "escape",
		"Esc closes the popup through viewport input"
	)
	_expect(
		popup.show_projection(popup_zero_reopen) and popup.visible,
		"popup reopens for outside-click test"
	)
	await _click_point(Vector2(1140, 690))
	_expect(
		not popup.visible \
			and str(popup.debug_snapshot().get("last_close_reason", "")) == "outside_click",
		"clicking the overlay outside PopupCard closes the popup"
	)

	var panel_debug := panel.debug_snapshot()
	var popup_debug := popup.debug_snapshot()
	_expect(
		int(panel_debug.get("local_marker_count", 0)) == 1
			and int(panel_debug.get("direct_gameplay_mutation_count", -1)) == 0
			and int(panel_debug.get("rng_draw_count", -1)) == 0
			and int(panel_debug.get("private_fact_read_count", -1)) == 0,
		"roster displays one local marker and owns zero mutation, RNG, or private facts"
	)
	_expect(
		bool(popup_debug.get("transient_overlay", false))
			and int(popup_debug.get("permanent_layout_width", -1)) == 0
			and int(popup_debug.get("direct_gameplay_mutation_count", -1)) == 0
			and int(popup_debug.get("rng_draw_count", -1)) == 0
			and int(popup_debug.get("private_fact_read_count", -1)) == 0,
		"inspection remains a zero-width transient public-only presentation surface"
	)

	panel.queue_free()
	popup.queue_free()
	await _frames(2)
	_finish()


func _public_players(count: int) -> Array:
	var result: Array = []
	for player_index in range(count):
		result.append({
			"player_index": player_index,
			"public_player_name": "玩家%d" % (player_index + 1),
			"role_name": "公开角色%d" % (player_index + 1),
			"public_status": "ready",
			"eliminated": false,
			"cash": 100000 + player_index,
			"hand": ["PRIVATE_%d" % player_index],
		})
	return result


func _summaries(prefix: String) -> Dictionary:
	return {
		"public_assets_summary": "%s · 公开资产" % prefix,
		"public_facilities_summary": "%s · 公开设施" % prefix,
		"public_military_summary": "%s · 公开军力" % prefix,
		"public_monster_summary": "%s · 公开怪兽" % prefix,
	}


func _history_link(intent: Dictionary) -> Dictionary:
	return {
		"history_entry_id": "card-history:3",
		"label": "查看公开记录",
		"navigation_intent": intent.duplicate(true),
	}


func _click_control(control: Control) -> void:
	await _frames(1)
	await _click_point(control.get_global_rect().get_center())


func _click_point(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		root.push_input(event, true)
		await process_frame


func _confirm_key(control: Control, keycode: Key) -> void:
	control.grab_focus()
	await process_frame
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func _confirm_action(control: Control) -> void:
	control.grab_focus()
	await process_frame
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = &"ui_accept"
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func _escape_via_viewport() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.physical_keycode = KEY_ESCAPE
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func _frames(count: int) -> void:
	for _frame in range(count):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("ALPHA04B_ROSTER_POPUP_COMPONENT_PASS checks=%d" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("ALPHA04B_ROSTER_POPUP_COMPONENT_FAIL: %s" % failure)
	quit(1)
