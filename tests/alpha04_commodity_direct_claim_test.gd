extends SceneTree

const TRACK_SCENE := preload("res://scenes/ui/table/TopCommoditySushiTrack.tscn")
const ILLUSTRATION_CATALOG: CardIllustrationCatalogResource = preload(
	"res://resources/presentation/alpha01_card_illustration_catalog.tres"
)
const REQUIRED_FAILURE_CODES: Array[String] = [
	"commodity_inventory_full",
	"shared_hand_capacity_full",
	"stale_source_revision",
	"item_already_claimed",
	"item_not_visible",
	"item_not_claimable",
	"actor_authorization_invalid",
	"session_not_running",
	"request_duplicate",
	"request_collision",
]
const SLOT_A := "slot.direct.alpha"
const SLOT_B := "slot.direct.beta"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(960, 540)
	var track := TRACK_SCENE.instantiate() as TopCommoditySushiTrack
	_expect(track != null, "production commodity source track instantiates")
	if track == null:
		_finish()
		return
	root.add_child(track)
	track.custom_minimum_size = Vector2(900, 180)
	_expect(track.set_snapshot_dictionary(_snapshot(1, true)), "typed source snapshot is accepted")
	await _frames(3)

	var card_a := track.find_child("CommoditySlot_slot_direct_alpha", true, false) as TopCommoditySushiTrackItem
	var card_b := track.find_child("CommoditySlot_slot_direct_beta", true, false) as TopCommoditySushiTrackItem
	_expect(card_a != null and card_b != null, "stable source-card nodes render for claimable and unavailable items")
	if card_a == null or card_b == null:
		_dispose(track)
		_finish()
		return

	var claims: Array[Dictionary] = []
	var focused: Array[String] = []
	track.claim_requested.connect(func(item: Variant) -> void:
		if item != null and item.has_method("to_dictionary"):
			claims.append(item.call("to_dictionary"))
	)
	track.item_focused.connect(func(item: Variant) -> void:
		if item != null:
			focused.append(str(item.get("commodity_slot_id")))
	)

	var scene_source := FileAccess.get_file_as_string("res://scenes/ui/table/TopCommoditySushiTrackItem.tscn")
	var item_source := FileAccess.get_file_as_string("res://scripts/ui/table/top_commodity_sushi_track_item.gd")
	_expect(card_a.find_children("*", "Button", true, false).is_empty(), "source card contains no visible or hidden claim Button")
	_expect(not scene_source.contains("CommodityClaimButton") and not item_source.contains("@onready var claim_button"), "retired claim-button node, variable, and connection are absent")
	_expect(not scene_source.contains("点击获取") and not scene_source.contains("免费领取"), "retired button copy is absent from the source-card scene")
	_expect(card_a.focus_mode == Control.FOCUS_ALL and card_b.focus_mode == Control.FOCUS_ALL, "claimable and unavailable cards remain keyboard-focusable")
	var initial_art_a: Dictionary = card_a.debug_snapshot()
	var initial_art_b: Dictionary = card_b.debug_snapshot()
	_expect(
		bool(initial_art_a.get("illustration_active", false)) \
		and bool(initial_art_b.get("illustration_active", false)) \
		and str(initial_art_a.get("illustration_key", "")) != str(initial_art_b.get("illustration_key", "")),
		"source cards consume distinct projected catalog illustration keys without a local card-id mapping"
	)

	# One mouse gesture is down/up on one stable source identity. The track enters pending
	# before forwarding its typed item intent and does not remove the card optimistically.
	await _click_card_via_viewport(card_a)
	_expect(claims.size() == 1 and str(claims[0].get("commodity_slot_id", "")) == SLOT_A, "single card-body click emits exactly one typed claim intent")
	var debug: Dictionary = track.debug_snapshot()
	_expect(int(debug.get("pending_claim_count", 0)) == 1 and int(debug.get("claim_submission_count", 0)) == 1, "first intent atomically owns one pending source identity")
	_expect(int(debug.get("rendered_item_count", 0)) == 2, "direct click never removes the authoritative source item optimistically")

	# OS double-click and rapid triple-click sequences arrive while the exact source
	# identity is pending and are suppressed before another signal can escape.
	_click_card(card_a, true)
	_click_card(card_a)
	_click_card(card_a)
	debug = track.debug_snapshot()
	var card_debug: Dictionary = card_a.debug_snapshot()
	_expect(claims.size() == 1, "double-click and rapid repeated clicks cannot emit a second claim while pending")
	_expect(int(card_debug.get("duplicate_activation_suppression_count", 0)) >= 3, "card records pending/cooldown duplicate suppression")

	_expect(track.bind_pending_request_revision(SLOT_A, 41), "pending source identity binds the Action Spine request revision")
	_expect(track.apply_claim_result(_failure_result(SLOT_A, 41, "commodity_inventory_full")), "structured authoritative failure resolves only the matching pending request")
	debug = track.debug_snapshot()
	card_debug = card_a.debug_snapshot()
	_expect(int(debug.get("pending_claim_count", -1)) == 0 and int(debug.get("claim_result_failure_count", 0)) == 1, "failure releases pending without changing the source snapshot")
	_expect(str((card_debug.get("last_feedback", {}) as Dictionary).get("failure_code", "")) == "commodity_inventory_full", "card feedback retains the typed failure code")
	_expect(_node_text(card_a).contains("容量已满"), "typed capacity failure is visible on the card body")
	var claims_before_revision_change := claims.size()
	var old_center := card_a.get_global_rect().get_center()
	var revision_down := _mouse_button(MOUSE_BUTTON_LEFT, true, old_center)
	card_a.call("_gui_input", revision_down)
	var old_instance_id := card_a.get_instance_id()
	_expect(track.set_snapshot_dictionary(_snapshot(2, true)), "new source revision is accepted while the pointer is held")
	await _frames(1)
	card_a = track.find_child("CommoditySlot_slot_direct_alpha", true, false) as TopCommoditySushiTrackItem
	var revision_up := _mouse_button(MOUSE_BUTTON_LEFT, false, card_a.get_global_rect().get_center())
	card_a.call("_gui_input", revision_up)
	_expect(card_a.get_instance_id() == old_instance_id and claims.size() == claims_before_revision_change, "down/up spanning a source revision reuses the node but cannot claim the changed identity")

	var supported: Array[String] = track.structured_failure_codes()
	var all_required_feedback_structured := true
	for code in REQUIRED_FAILURE_CODES:
		var feedback: Dictionary = track.feedback_for_failure_code(code)
		all_required_feedback_structured = all_required_feedback_structured \
			and supported.has(code) \
			and bool(feedback.get("supported_failure_code", false)) \
			and str(feedback.get("failure_code", "")) == code \
			and not str(feedback.get("label", "")).is_empty()
	_expect(all_required_feedback_structured, "all required failure codes have structured non-text-matched feedback")

	await create_timer(0.40).timeout
	var claim_count_before_gesture_guards := claims.size()
	_drag_card_past_deadzone(card_a)
	_cross_card_release(card_a, card_b)
	var handled_before_non_mouse_claim_input := int(track.debug_snapshot().get("scoped_handled_event_count", 0))
	await _wheel_over_card_via_viewport(card_a)
	await _touch_swipe_over_card_via_viewport(card_a)
	_expect(claims.size() == claim_count_before_gesture_guards, "drag, cross-card release, wheel, and touch swipe input never claim")
	_expect(
		int(track.debug_snapshot().get("scoped_handled_event_count", -1)) == handled_before_non_mouse_claim_input,
		"track router does not swallow wheel or native touch-swipe events"
	)
	card_debug = card_a.debug_snapshot()
	_expect(int(card_debug.get("drag_cancellation_count", 0)) >= 1 and int(card_debug.get("cross_item_release_rejection_count", 0)) >= 1, "deadzone and same-card release guards report their rejections")

	# Keyboard Enter, Space, and mapped controller confirm all use the same pending gate.
	var handled_before_accessible_confirm := int(track.debug_snapshot().get("scoped_handled_event_count", 0))
	await _confirm_key_via_viewport(card_a, KEY_ENTER)
	_confirm_key(card_a, KEY_ENTER, true)
	_expect(claims.size() == claim_count_before_gesture_guards + 1, "Enter emits once and key repeat cannot duplicate it")
	_expect(int(track.debug_snapshot().get("scoped_handled_event_count", -1)) == handled_before_accessible_confirm, "keyboard confirm bypasses the pointer router and uses focused-card activation")
	_expect(track.bind_pending_request_revision(SLOT_A, 42), "Enter intent binds one request revision")
	_expect(not track.apply_claim_result(_failure_result(SLOT_A, 999, "stale_source_revision")), "mismatched receipt identity cannot release a newer pending claim")
	_expect(int(track.debug_snapshot().get("pending_claim_count", 0)) == 1, "stale receipt leaves the exact pending claim locked")
	_expect(track.apply_claim_result(_failure_result(SLOT_A, 42, "stale_source_revision")), "Enter failure releases the exact pending request")
	await create_timer(0.40).timeout
	_confirm_key(card_a, KEY_SPACE)
	_expect(claims.size() == claim_count_before_gesture_guards + 2, "Space directly submits through the same typed intent")
	_expect(track.bind_pending_request_revision(SLOT_A, 43), "Space intent binds one request revision")
	_expect(track.apply_claim_result(_failure_result(SLOT_A, 43, "item_not_claimable")), "Space failure releases the exact pending request")
	await create_timer(0.40).timeout
	var handled_before_controller_confirm := int(track.debug_snapshot().get("scoped_handled_event_count", 0))
	await _confirm_action_via_viewport(card_a)
	_confirm_action(card_a)
	_expect(claims.size() == claim_count_before_gesture_guards + 3, "controller confirm emits exactly once while pending")
	_expect(int(track.debug_snapshot().get("scoped_handled_event_count", -1)) == handled_before_controller_confirm, "controller confirm bypasses the pointer router and uses focused-card activation")
	_expect(track.bind_pending_request_revision(SLOT_A, 44), "controller intent binds one request revision")

	# A success receipt locks this exact source identity but still cannot consume it in UI.
	_expect(track.apply_claim_result(_success_result(SLOT_A, 44)), "matching authoritative success is accepted")
	debug = track.debug_snapshot()
	_expect(int(debug.get("rendered_item_count", 0)) == 2 and int(debug.get("claim_result_success_count", 0)) == 1, "success feedback precedes and does not impersonate the source mutation")
	_click_card(card_a)
	_expect(claims.size() == claim_count_before_gesture_guards + 3, "settled success identity cannot be submitted again before source refresh")
	_expect(track.set_snapshot_dictionary(_snapshot_with_claimable_b(3)), "new authoritative snapshot consumes the claimed source item and advances the visible source")
	await _frames(2)
	card_b = track.find_child("CommoditySlot_slot_direct_beta", true, false) as TopCommoditySushiTrackItem
	var claims_before_source_advance_click := claims.size()
	_click_card(card_b)
	_expect(claims.size() == claims_before_source_advance_click, "the second half of a rapid double-click cannot claim a newly shifted source card after synchronous refresh")
	await create_timer(0.40).timeout
	_click_card(card_b)
	_expect(claims.size() == claims_before_source_advance_click + 1, "a deliberate later click can claim the advanced source card")
	_expect(track.bind_pending_request_revision(SLOT_B, 45), "advanced source click binds its own request revision")
	_expect(track.apply_claim_result(_failure_result(SLOT_B, 45, "item_not_claimable")), "advanced source failure releases only its pending identity")
	_expect(track.set_snapshot_dictionary(_snapshot(4, false)), "new authoritative snapshot can make the remaining source unavailable")
	await _frames(2)
	debug = track.debug_snapshot()
	_expect(int(debug.get("rendered_item_count", -1)) == 1 and track.item_snapshot_by_id(SLOT_A) == null, "only the newer authoritative snapshot removes the source item")

	# Unavailable cards remain focusable and explain why, but all activation modes fail closed.
	card_b = track.find_child("CommoditySlot_slot_direct_beta", true, false) as TopCommoditySushiTrackItem
	_click_card(card_b)
	_confirm_key(card_b, KEY_ENTER)
	_confirm_action(card_b)
	_expect(claims.size() == claim_count_before_gesture_guards + 4, "unavailable source card cannot emit a claim")
	_expect(_node_text(card_b).contains("容量已满") and focused.has(SLOT_B), "unavailable card exposes its reason through focus and card text")

	debug = track.debug_snapshot()
	_expect(int(debug.get("claim_button_count", -1)) == 0, "production source track has zero Button descendants")
	_expect(int(debug.get("direct_inventory_mutation_count", -1)) == 0 and int(debug.get("direct_track_mutation_count", -1)) == 0, "UI owns neither inventory nor source-track mutation")
	_expect(not item_source.contains("claim_belt_card") and not item_source.contains("CommodityCardInventoryRuntimeController"), "source card emits intent and never reaches the inventory owner")

	_dispose(track)
	await _frames(2)
	_finish()


func _snapshot(revision: int, include_claimable: bool) -> Dictionary:
	var items: Array = []
	if include_claimable:
		items.append(_item(
			SLOT_A,
			"commodity.ring_crystal_battery.rank_1",
			"环晶电池",
			0,
			true,
			"",
			str(ILLUSTRATION_CATALOG.presentation_key_for_card("commodity.ring_crystal_battery.rank_1"))
		))
	items.append(_item(
		SLOT_B,
		"commodity.gravity_ceramic.rank_1",
		"重力陶瓷",
		1,
		false,
		"共享容量已满，暂时不能领取。",
		str(ILLUSTRATION_CATALOG.presentation_key_for_card("commodity.gravity_ceramic.rank_1"))
	))
	return {
		"schema_version": 1,
		"available": true,
		"snapshot_revision": revision,
		"belt_revision": 10 + revision,
		"visibility_revision": 20 + revision,
		"market_revision": 30 + revision,
		"public_refresh_phase": "共享来源测试",
		"items": items,
		"empty_text": "当前没有可领取商品。",
	}


func _snapshot_with_claimable_b(revision: int) -> Dictionary:
	return {
		"schema_version": 1,
		"available": true,
		"snapshot_revision": revision,
		"belt_revision": 10 + revision,
		"visibility_revision": 20 + revision,
		"market_revision": 30 + revision,
		"public_refresh_phase": "共享来源测试",
		"items": [_item(
			SLOT_B,
			"commodity.gravity_ceramic.rank_1",
			"重力陶瓷",
			0,
			true,
			"",
			str(ILLUSTRATION_CATALOG.presentation_key_for_card("commodity.gravity_ceramic.rank_1"))
		)],
		"empty_text": "当前没有可领取商品。",
	}


func _item(slot_id: String, card_id: String, display_name: String, index: int, claimable: bool, disabled_reason: String, illustration_key: String) -> Dictionary:
	return {
		"commodity_slot_id": slot_id,
		"commodity_card_id": card_id,
		"illustration_key": illustration_key,
		"public_name": display_name,
		"public_icon_id": "industry",
		"slot_index": index,
		"availability_state": "available" if claimable else "unavailable",
		"claimable": claimable,
		"public_claim_disabled_reason": disabled_reason,
		"public_supply_pressure": 4,
		"public_demand_pressure": 7,
		"public_market_price": 120,
		"public_market_trend": 1,
		"public_refresh_phase": "公开",
		"display_accent_id": "industry",
		"public_industry": "晶体工业",
		"public_short_effect": "领取后进入权威商品库存。",
	}


func _failure_result(slot_id: String, request_revision: int, failure_code: String) -> Dictionary:
	return {
		"success": false,
		"failure_code": failure_code,
		"focus_target": slot_id,
		"request_revision": request_revision,
		"explanation": "测试中的结构化失败说明。",
		"suggested_action": "等待权威来源刷新。",
	}


func _success_result(slot_id: String, request_revision: int) -> Dictionary:
	return {
		"success": true,
		"failure_code": "",
		"focus_target": slot_id,
		"request_revision": request_revision,
		"explanation": "商品已由权威库存接收。",
		"suggested_action": "查看商品库存。",
	}


func _click_card(card: Control, double_click := false) -> void:
	if card == null:
		return
	var center := card.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := _mouse_button(MOUSE_BUTTON_LEFT, pressed, center)
		event.double_click = double_click
		card.call("_gui_input", event)


func _click_card_via_viewport(card: Control) -> void:
	if card == null:
		return
	var center := card.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = center
	motion.global_position = center
	root.push_input(motion, true)
	await process_frame
	for pressed in [true, false]:
		root.push_input(_mouse_button(MOUSE_BUTTON_LEFT, pressed, center), true)
		await process_frame


func _mouse_button(button_index: MouseButton, pressed: bool, position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = pressed
	event.position = position
	event.global_position = position
	return event


func _drag_card_past_deadzone(card: Control) -> void:
	var center := card.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = center
	down.global_position = center
	card.call("_gui_input", down)
	var motion := InputEventMouseMotion.new()
	motion.position = center + Vector2(18, 0)
	motion.global_position = motion.position
	card.call("_input", motion)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = motion.position
	up.global_position = motion.position
	card.call("_input", up)


func _cross_card_release(card_a: Control, card_b: Control) -> void:
	var start := card_a.get_global_rect().get_center()
	var finish := card_b.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = start
	down.global_position = start
	card_a.call("_gui_input", down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = finish
	up.global_position = finish
	card_a.call("_input", up)


func _wheel_over_card_via_viewport(card: Control) -> void:
	var center := card.get_global_rect().get_center()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	event.pressed = true
	event.position = center
	event.global_position = center
	root.push_input(event, true)
	await process_frame


func _touch_swipe_over_card_via_viewport(card: Control) -> void:
	var center := card.get_global_rect().get_center()
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = center
	root.push_input(touch, true)
	await process_frame
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = center + Vector2(24, 0)
	drag.relative = Vector2(24, 0)
	root.push_input(drag, true)
	await process_frame
	touch = InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = false
	touch.position = center + Vector2(24, 0)
	root.push_input(touch, true)
	await process_frame


func _confirm_key(card: Control, keycode: Key, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	event.echo = echo
	card.call("_gui_input", event)


func _confirm_key_via_viewport(card: Control, keycode: Key) -> void:
	card.grab_focus()
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	root.push_input(event, true)
	await process_frame


func _confirm_action(card: Control) -> void:
	var event := InputEventAction.new()
	event.action = &"ui_accept"
	event.pressed = true
	card.call("_gui_input", event)


func _confirm_action_via_viewport(card: Control) -> void:
	card.grab_focus()
	var event := InputEventAction.new()
	event.action = &"ui_accept"
	event.pressed = true
	root.push_input(event, true)
	await process_frame


func _node_text(node: Node) -> String:
	var parts: Array[String] = []
	if node is Label:
		parts.append((node as Label).text)
	for child in node.get_children():
		var child_text := _node_text(child)
		if not child_text.is_empty():
			parts.append(child_text)
	return " ".join(parts)


func _frames(count: int) -> void:
	for _index in range(maxi(1, count)):
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
		print("Alpha04 commodity direct claim test passed.")
	else:
		push_error("Alpha04 commodity direct claim test failed:\n- " + "\n- ".join(_failures))
	quit(_failures.size())
