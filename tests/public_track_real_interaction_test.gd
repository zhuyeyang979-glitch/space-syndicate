extends SceneTree

const GAME_SCREEN_SCENE := preload("res://scenes/ui/GameScreen.tscn")
const ILLUSTRATION_CATALOG: CardIllustrationCatalogResource = preload("res://resources/presentation/alpha01_card_illustration_catalog.tres")
const CONTEXT_DETAIL := preload("res://scripts/presentation/context_detail_projection_v1.gd")
const PRIVATE_SENTINEL := "hidden_owner::PRIVATE_TRACK_SENTINEL"
const SLOT_ID := "slot.public.alpha"
const CARD_ID := "commodity.titanium_shell_clam.rank_1"
const CAPTURE_DIR := "user://commodity_sushi_track_real_interaction"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var screen := GAME_SCREEN_SCENE.instantiate() as Control
	_expect(screen != null, "real GameScreen instantiates for commodity-track interaction")
	if screen == null:
		_finish()
		return
	root.add_child(screen)
	screen.call("bind_presentation_viewer", 0, 1)
	var actor_context := GameplayActorAuthorizationContext.new()
	actor_context.request_id = "actor-context:public-track-test:1"
	actor_context.authorized = true
	actor_context.reason_code = "authorized"
	actor_context.viewer_index = 0
	actor_context.authorized_actor_player_index = 0
	actor_context.authorization_revision = 1
	actor_context.session_id = "public-track-test-session"
	actor_context.session_revision = 1
	actor_context.source_surface = &"game_screen"
	actor_context.issued_at_operation_revision = 1
	screen.call("bind_gameplay_actor_authorization_context", actor_context)
	await _wait_frames(4)

	# A stale private hand focus must not win after a public commodity is focused.
	screen.call("_on_card_selected", {
		"name": PRIVATE_SENTINEL,
		"effect": PRIVATE_SENTINEL,
		"cash": PRIVATE_SENTINEL,
		"hand": [PRIVATE_SENTINEL],
	})
	screen.call("apply_state", _table_state(7, 240))
	await _wait_frames(4)

	var track := screen.find_child("TopCommoditySushiTrack", true, false) as Control
	var item := screen.find_child("CommoditySlot_slot_public_alpha", true, false) as Control
	var name_label := item.find_child("CommodityNameLabel", true, false) as Control if item != null else null
	var detail_drawer := screen.find_child("ContextDetailDrawer", true, false) as Control
	_expect(track != null and item != null and name_label != null, "real TopCommoditySushiTrack renders one stable interactive commodity source card")
	_expect(item == null or item.find_children("*", "Button", true, false).is_empty(), "source card contains no claim Button or hidden action control")
	_expect(detail_drawer != null, "real GameScreen keeps the typed context-detail surface mounted")
	_expect(screen.find_children("PublicTrack", "", true, false).is_empty() and screen.find_children("TrackFocusRibbon", "", true, false).is_empty(), "retired persistent card-track nodes remain absent")
	if track == null or item == null or name_label == null or detail_drawer == null:
		_dispose(screen)
		_finish()
		return

	var focused_items: Array[Dictionary] = []
	var claim_requests: Array = []
	var map_view := screen.find_child("PlanetMapView", true, false) as Control
	var map_pointer_events: Array[InputEvent] = []
	if map_view != null:
		map_view.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				map_pointer_events.append(event)
		)
	track.connect("item_focused", func(snapshot: Variant) -> void:
		if snapshot != null and snapshot.has_method("to_dictionary"):
			focused_items.append(snapshot.call("to_dictionary"))
	)
	screen.connect("commodity_claim_requested", func(request: Variant) -> void:
		claim_requests.append(request)
	)

	_expect(track.mouse_filter == Control.MOUSE_FILTER_IGNORE and item.mouse_filter == Control.MOUSE_FILTER_STOP, "transparent belt ignores input while the commodity item owns pointer input")
	_expect(name_label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "commodity label does not intercept the item click")
	var original_item_id := item.get_instance_id()
	await _hover_control(name_label)
	await _wait_frames(3)
	var track_debug: Dictionary = track.call("debug_snapshot")
	_expect(not focused_items.is_empty() and _all_focused_items_match_slot(focused_items), "real viewport hover/click focuses only the typed public commodity item")
	_expect(str(track_debug.get("selected_slot_id", "")) == SLOT_ID, "commodity selection is retained by stable slot id")
	var detail_text := _node_tree_text(detail_drawer)
	_expect(detail_text.contains("公共商品") and detail_text.contains("钛壳贝") and detail_text.contains("单击商品牌本体"), "commodity focus keeps typed public detail and direct-card guidance ready")
	_expect(not detail_text.contains(PRIVATE_SENTINEL), "typed public detail replaces stale private hand text")

	# A newer authoritative snapshot updates values without rebuilding the item or losing focus.
	screen.call("apply_state", _table_state(8, 345))
	await _wait_frames(4)
	var refreshed_item := screen.find_child("CommoditySlot_slot_public_alpha", true, false) as Control
	track_debug = track.call("debug_snapshot")
	detail_text = _node_tree_text(detail_drawer)
	_expect(refreshed_item != null and refreshed_item.get_instance_id() == original_item_id, "new revision reuses the existing commodity item node")
	_expect(int(track_debug.get("snapshot_revision", -1)) == 8 and str(track_debug.get("selected_slot_id", "")) == SLOT_ID, "new revision preserves selected stable id")
	_expect(_node_tree_text(refreshed_item).contains("¥345") and detail_text.contains("需求 9") and not detail_text.contains(PRIVATE_SENTINEL), "item and typed detail refresh their public market facts without private data")
	_expect(bool((refreshed_item.call("debug_snapshot") as Dictionary).get("illustration_active", false)), "real source card renders its authored commodity illustration")

	# The UI submits a typed owner-bound claim and never removes the item optimistically.
	await _click_control(refreshed_item)
	await _click_control(refreshed_item)
	await _wait_frames(3)
	_expect(claim_requests.size() == 1, "rapid card-body clicks emit exactly one typed commodity claim request")
	track_debug = track.call("debug_snapshot")
	_expect(
		map_pointer_events.is_empty() \
		and int(track_debug.get("scoped_pointer_capture_count", 0)) >= 2 \
		and int(track_debug.get("scoped_handled_event_count", 0)) >= 4,
		"card-body down/up events are marked handled before the overlapping map receives them"
	)
	if claim_requests.size() == 1:
		var request: Variant = claim_requests[0]
		_expect(
			int(request.get("viewer_index")) == 0
			and str(request.get("commodity_slot_id")) == SLOT_ID
			and str(request.get("commodity_card_id")) == CARD_ID
			and int(request.get("snapshot_revision")) == 8
			and int(request.get("belt_revision")) == 18
			and int(request.get("visibility_revision")) == 28,
			"claim request binds viewer, stable item ids, and authoritative revisions"
		)
	track_debug = track.call("debug_snapshot")
	_expect(int(track_debug.get("rendered_item_count", -1)) == 1 and (screen.find_child("CommoditySlot_slot_public_alpha", true, false) as Control).get_instance_id() == original_item_id, "UI does not remove or rebuild the commodity before an owner result")

	# A stale snapshot fails closed at the track and cannot replace the selected public facts.
	screen.call("apply_state", _table_state(7, 1))
	await _wait_frames(3)
	track_debug = track.call("debug_snapshot")
	detail_text = _node_tree_text(detail_drawer)
	_expect(int(track_debug.get("snapshot_revision", -1)) == 8 and int(track_debug.get("stale_rejection_count", 0)) >= 1, "stale commodity revision fails closed")
	_expect(_node_tree_text(refreshed_item).contains("¥345") and not _node_tree_text(refreshed_item).contains("¥1") and detail_text.contains("需求 9") and not detail_text.contains("需求 1"), "stale revision cannot overwrite selected item or typed detail facts")

	# The scoped router handles only BeltViewport ∩ card. A normal map click outside
	# that intersection still reaches the production map and is never marked as a track capture.
	map_pointer_events.clear()
	var captures_before_map_click := int((track.call("debug_snapshot") as Dictionary).get("scoped_pointer_capture_count", 0))
	await _click_control(map_view)
	await _wait_frames(2)
	track_debug = track.call("debug_snapshot")
	_expect(
		map_view != null \
		and int(track_debug.get("scoped_pointer_capture_count", -1)) == captures_before_map_click,
		"map input outside the source-card belt never enters the scoped track router"
	)

	await _capture("top_commodity_sushi_track_selected.png")
	_dispose(screen)
	await _wait_frames(2)
	_finish()


func _table_state(revision: int, public_price: int) -> Dictionary:
	var demand_pressure := 9 if public_price == 345 else (1 if public_price == 1 else 7)
	var detail := CONTEXT_DETAIL.build({
		"schema_version": 1,
		"viewer_index": 0,
		"authorization_revision": 1,
		"source_revision": revision,
		"context_id": "commodity-source-detail-%d" % revision,
		"context_kind": CONTEXT_DETAIL.KIND_COMMODITY_SOURCE,
		"visibility_scope": "public",
		"title": "公共商品｜钛壳贝",
		"subtitle": "可领取公开来源",
		"content": {
			"source_id": SLOT_ID,
			"commodity_id": CARD_ID,
			"display_name": "钛壳贝",
			"illustration_key": str(ILLUSTRATION_CATALOG.presentation_key_for_card(CARD_ID)),
			"public_status": "available",
			"summary": "价格 ¥%d · 需求 %d" % [public_price, demand_pressure],
			"detail": "单击商品牌本体直接领取；需求 %d。" % demand_pressure,
		},
		"navigation_intents": [],
	})
	return {
		"commodity_sushi_track": {
			"schema_version": 1,
			"available": true,
			"snapshot_revision": revision,
			"belt_revision": revision + 10,
			"visibility_revision": revision + 20,
			"market_revision": revision + 30,
			"public_refresh_phase": "共享商品公开快照",
			"items": [{
				"commodity_slot_id": SLOT_ID,
				"commodity_card_id": CARD_ID,
				"illustration_key": str(ILLUSTRATION_CATALOG.presentation_key_for_card(CARD_ID)),
				"public_name": "钛壳贝",
				"public_icon_id": "industry",
				"slot_index": 0,
				"availability_state": "available",
				"claimable": true,
				"public_claim_disabled_reason": "",
				"public_supply_pressure": 4,
				"public_demand_pressure": demand_pressure,
				"public_market_price": public_price,
				"public_market_trend": 2,
				"public_refresh_phase": "公开",
				"display_accent_id": "industry",
				"public_industry": "晶体工业",
				"public_short_effect": "免费领取后安装到合法设施。",
			}],
			"empty_text": "当前没有可领取商品。",
		},
		"context_detail": detail,
		"player_board": {"hand_cards": []},
	}


func _click_control(control: Control) -> void:
	if control == null:
		return
	var position := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion, true)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		event.global_position = position
		root.push_input(event, true)
		await process_frame


func _hover_control(control: Control) -> void:
	if control == null:
		return
	var position := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion, true)
	await process_frame


func _node_tree_text(node: Node) -> String:
	if node == null:
		return ""
	var parts: Array[String] = []
	if node is Label:
		parts.append((node as Label).text)
	elif node is RichTextLabel:
		parts.append((node as RichTextLabel).text)
	elif node is Button:
		parts.append((node as Button).text)
	for child in node.get_children():
		var child_text := _node_tree_text(child)
		if not child_text.is_empty():
			parts.append(child_text)
	return " ".join(parts)


func _all_focused_items_match_slot(items: Array[Dictionary]) -> bool:
	for item in items:
		if str(item.get("commodity_slot_id", "")) != SLOT_ID:
			return false
	return true


func _controls_under_point(node: Node, point: Vector2, result: Array[String] = []) -> Array[String]:
	for child in node.get_children():
		if child is Control:
			var control := child as Control
			if control.is_visible_in_tree() and control.get_global_rect().has_point(point) \
					and control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				result.append("%s:%d" % [control.get_path(), control.mouse_filter])
		_controls_under_point(child, point, result)
	return result


func _capture(file_name: String) -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		return
	await RenderingServer.frame_post_draw
	var absolute_dir := ProjectSettings.globalize_path(CAPTURE_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var absolute_path := absolute_dir.path_join(file_name)
	var image := root.get_texture().get_image()
	var error := image.save_png(absolute_path)
	_expect(error == OK, "headed viewport screenshot saves: %s" % file_name)
	if error == OK:
		print("COMMODITY_TRACK_CAPTURE=%s" % absolute_path)


func _wait_frames(count: int) -> void:
	for _frame in range(maxi(1, count)):
		await process_frame


func _dispose(node: Node) -> void:
	if node != null and node.get_parent() != null:
		node.get_parent().remove_child(node)
	if node != null:
		node.queue_free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PublicTrack real interaction test passed.")
	else:
		push_error("PublicTrack real interaction test failed:\n- " + "\n- ".join(_failures))
	quit(_failures.size())
