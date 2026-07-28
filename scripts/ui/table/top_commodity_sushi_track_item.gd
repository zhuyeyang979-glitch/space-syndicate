extends PanelContainer
class_name TopCommoditySushiTrackItem

const ITEM_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/commodity_sushi_track_item_snapshot.gd")

const POINTER_DRAG_DEADZONE_PX := 9.0
const RAPID_ACTIVATION_GUARD_MSEC := 360

signal item_focused(item: ITEM_SNAPSHOT_SCRIPT)
signal claim_requested(item: ITEM_SNAPSHOT_SCRIPT)

@onready var icon_label: Label = %CommodityIconLabel
@onready var name_label: Label = %CommodityNameLabel
@onready var industry_label: Label = %CommodityIndustryLabel
@onready var price_label: Label = %CommodityPriceLabel
@onready var pressure_label: Label = %CommodityPressureLabel
@onready var claim_state_label: Label = %CommodityClaimStateLabel
@onready var art_panel: PanelContainer = %CommodityArtPanel
@onready var illustration_layer: SpaceSyndicateCardIllustrationLayer = %CommodityIllustrationLayer
@onready var art_fallback: Label = %CommodityArtFallback

var _item: ITEM_SNAPSHOT_SCRIPT
var _source_identity := ""
var _selected := false
var _pending := false
var _pending_identity := ""
var _pointer_active := false
var _pointer_dragged := false
var _pointer_press_position := Vector2.ZERO
var _pointer_press_identity := ""
var _last_activation_msec := -RAPID_ACTIVATION_GUARD_MSEC
var _last_activation_started_usec := 0
var _last_focus_started_usec := 0
var _duplicate_activation_suppression_count := 0
var _drag_cancellation_count := 0
var _cross_item_release_rejection_count := 0
var _unavailable_activation_rejection_count := 0
var _last_feedback: Dictionary = {}
var _pending_pulse_time := 0.0


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	set_process_input(true)
	set_process(false)
	if not mouse_entered.is_connected(_emit_focus):
		mouse_entered.connect(_emit_focus)
	if not focus_entered.is_connected(_on_focus_entered):
		focus_entered.connect(_on_focus_entered)
	if not focus_exited.is_connected(_on_focus_exited):
		focus_exited.connect(_on_focus_exited)
	_apply_style()


func set_item(item: ITEM_SNAPSHOT_SCRIPT, source_identity_binding := "") -> void:
	var normalized_identity := str(source_identity_binding).strip_edges()
	if normalized_identity != _source_identity:
		_cancel_pointer_interaction()
		_pending = false
		_pending_identity = ""
		_last_feedback = {}
		set_process(false)
		_pending_pulse_time = 0.0
		if claim_state_label != null:
			claim_state_label.modulate = Color.WHITE
	_source_identity = normalized_identity
	_item = item
	if item == null or not item.is_valid():
		visible = false
		return
	visible = true
	icon_label.text = _icon_text(item.public_icon_id)
	name_label.text = item.public_name
	name_label.tooltip_text = item.public_name
	industry_label.text = "%s｜%s" % [
		item.public_industry,
		"¥%d" % item.public_market_price if item.public_market_price >= 0 else "行情 --",
	]
	price_label.text = "供 %d｜需 %d" % [item.public_supply_pressure, item.public_demand_pressure]
	pressure_label.visible = false
	_sync_illustration()
	_sync_claim_state()
	tooltip_text = _tooltip_text()
	set_meta("player_assistive_name", _assistive_name())
	_apply_style()


func set_selected(selected: bool) -> void:
	if _selected == selected:
		return
	_selected = selected
	_apply_style()


func set_pending(pending: bool, pending_identity := "") -> void:
	var normalized_identity := str(pending_identity).strip_edges()
	if pending and (normalized_identity.is_empty() or normalized_identity != _source_identity):
		return
	_pending = pending
	_pending_identity = normalized_identity if pending else ""
	_pending_pulse_time = 0.0
	set_process(_pending)
	if not _pending and claim_state_label != null:
		claim_state_label.modulate = Color.WHITE
	_sync_claim_state()
	tooltip_text = _tooltip_text()
	set_meta("player_assistive_name", _assistive_name())
	_apply_style()


func set_action_feedback(feedback: Dictionary) -> void:
	_last_feedback = feedback.duplicate(true)
	_sync_claim_state()
	tooltip_text = _tooltip_text()
	set_meta("player_assistive_name", _assistive_name())
	_apply_style()


func item_snapshot() -> ITEM_SNAPSHOT_SCRIPT:
	return ITEM_SNAPSHOT_SCRIPT.new().apply_dictionary(_item.to_dictionary()) \
		if _item != null and _item.is_valid() else null


func source_identity() -> String:
	return _source_identity


func is_claim_pending() -> bool:
	return _pending


func notify_pointer_hover() -> void:
	_emit_focus()


func begin_pointer_gesture(screen_position: Vector2) -> void:
	grab_focus()
	_emit_focus()
	_begin_pointer_interaction(screen_position)


func update_pointer_gesture(screen_position: Vector2) -> void:
	_update_pointer_motion(screen_position)


func finish_pointer_gesture(screen_position: Vector2) -> void:
	_finish_pointer_interaction(screen_position)


func last_activation_started_usec() -> int:
	return _last_activation_started_usec


func last_focus_started_usec() -> int:
	return _last_focus_started_usec


func debug_snapshot() -> Dictionary:
	return {
		"slot_id": _item.commodity_slot_id if _item != null else "",
		"card_id": _item.commodity_card_id if _item != null else "",
		"source_identity": _source_identity,
		"selected": _selected,
		"claimable": _item != null and _item.claimable,
		"claim_pending": _pending,
		"pending_identity": _pending_identity,
		"pointer_active": _pointer_active,
		"pointer_dragged": _pointer_dragged,
		"duplicate_activation_suppression_count": _duplicate_activation_suppression_count,
		"drag_cancellation_count": _drag_cancellation_count,
		"cross_item_release_rejection_count": _cross_item_release_rejection_count,
		"unavailable_activation_rejection_count": _unavailable_activation_rejection_count,
		"last_feedback": _last_feedback.duplicate(true),
		"illustration_key": _item.illustration_key if _item != null else "",
		"illustration_active": bool(get_meta("external_illustration_active", false)),
		"illustration_fallback_active": bool(get_meta("illustration_fallback_active", true)),
		"claim_button_count": 0,
		"direct_inventory_mutation_count": 0,
		"direct_track_mutation_count": 0,
	}


func _process(delta: float) -> void:
	if not _pending or claim_state_label == null:
		set_process(false)
		return
	_pending_pulse_time = fmod(_pending_pulse_time + maxf(0.0, delta), 2.0)
	var pulse := 0.72 + sin(_pending_pulse_time * TAU * 1.8) * 0.18
	claim_state_label.modulate = Color(1.0, 1.0, 1.0, pulse)


func _input(event: InputEvent) -> void:
	if not _pointer_active:
		return
	if event is InputEventMouseMotion:
		_update_pointer_motion((event as InputEventMouseMotion).global_position)
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			_finish_pointer_interaction(mouse_event.global_position)


func _gui_input(event: InputEvent) -> void:
	if event == null:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			grab_focus()
			_emit_focus()
			_begin_pointer_interaction(mouse_event.global_position)
		else:
			_finish_pointer_interaction(mouse_event.global_position)
		accept_event()
		return
	if event is InputEventMouseMotion:
		_update_pointer_motion((event as InputEventMouseMotion).global_position)
		return
	if _is_confirm_event(event):
		_emit_focus()
		_attempt_claim("confirm")
		accept_event()


func _begin_pointer_interaction(screen_position: Vector2) -> void:
	_pointer_active = true
	_pointer_dragged = false
	_pointer_press_position = screen_position
	_pointer_press_identity = _source_identity


func _update_pointer_motion(screen_position: Vector2) -> void:
	if not _pointer_active or _pointer_dragged:
		return
	if _pointer_press_position.distance_to(screen_position) > POINTER_DRAG_DEADZONE_PX:
		_pointer_dragged = true
		_drag_cancellation_count += 1


func _finish_pointer_interaction(screen_position: Vector2) -> void:
	if not _pointer_active:
		return
	_update_pointer_motion(screen_position)
	var release_on_same_card := get_global_rect().has_point(screen_position) \
		and not _source_identity.is_empty() \
		and _pointer_press_identity == _source_identity
	var should_claim := release_on_same_card and not _pointer_dragged
	if not release_on_same_card:
		_cross_item_release_rejection_count += 1
	_cancel_pointer_interaction()
	if should_claim:
		_attempt_claim("mouse")


func _cancel_pointer_interaction() -> void:
	_pointer_active = false
	_pointer_dragged = false
	_pointer_press_position = Vector2.ZERO
	_pointer_press_identity = ""


func _attempt_claim(_input_kind: String) -> void:
	_last_activation_started_usec = Time.get_ticks_usec()
	if _item == null or not _item.is_valid() or not _item.claimable:
		_unavailable_activation_rejection_count += 1
		_sync_claim_state()
		return
	if _source_identity.is_empty():
		_unavailable_activation_rejection_count += 1
		return
	var now_msec := Time.get_ticks_msec()
	if _pending or now_msec - _last_activation_msec < RAPID_ACTIVATION_GUARD_MSEC:
		_duplicate_activation_suppression_count += 1
		return
	_last_activation_msec = now_msec
	claim_requested.emit(item_snapshot())


func _is_confirm_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return false
		return key_event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] \
			or key_event.is_action_pressed("ui_accept")
	if event is InputEventJoypadButton:
		var joypad_event := event as InputEventJoypadButton
		return joypad_event.pressed and joypad_event.is_action_pressed("ui_accept")
	if event is InputEventAction:
		var action_event := event as InputEventAction
		return action_event.pressed and action_event.action == &"ui_accept"
	return false


func _emit_focus() -> void:
	if _item != null and _item.is_valid():
		_last_focus_started_usec = Time.get_ticks_usec()
		item_focused.emit(item_snapshot())


func _on_focus_entered() -> void:
	_emit_focus()
	_apply_style()


func _on_focus_exited() -> void:
	_apply_style()


func _sync_claim_state() -> void:
	if claim_state_label == null or _item == null or not _item.is_valid():
		return
	var state_text := "可领取"
	var state_color := Color("#fde68a")
	if _pending:
		state_text = "领取中…"
		state_color = Color("#67e8f9")
	elif not _last_feedback.is_empty():
		state_text = str(_last_feedback.get("label", "领取未完成"))
		state_color = Color("#86efac") if bool(_last_feedback.get("success", false)) else Color("#fda4af")
	elif not _item.claimable:
		state_text = _item.public_claim_disabled_reason
		state_color = Color("#94a3b8")
	claim_state_label.text = state_text
	claim_state_label.tooltip_text = _item.public_claim_disabled_reason \
		if not _item.claimable and _last_feedback.is_empty() else _feedback_tooltip()
	claim_state_label.add_theme_color_override("font_color", state_color)
	mouse_default_cursor_shape = Control.CURSOR_BUSY if _pending else (
		Control.CURSOR_POINTING_HAND if _item.claimable else Control.CURSOR_ARROW
	)


func _sync_illustration() -> void:
	if _item == null or not _item.is_valid():
		return
	var accent := _accent_color(_item.display_accent_id)
	var illustration_active := false
	var illustration_key := StringName(_item.illustration_key.strip_edges())
	if illustration_layer != null and illustration_key != StringName():
		illustration_active = illustration_layer.set_illustration_key(illustration_key, accent)
	if illustration_layer != null:
		illustration_layer.visible = illustration_active
	if art_fallback != null:
		art_fallback.visible = not illustration_active
		art_fallback.text = _icon_text(_item.public_icon_id)
		art_fallback.add_theme_color_override("font_color", accent.lightened(0.18))
	if art_panel != null:
		var art_style := StyleBoxFlat.new()
		art_style.bg_color = Color("#020617").lerp(accent, 0.18)
		art_style.border_color = accent.darkened(0.22)
		art_style.set_border_width_all(1)
		art_style.set_corner_radius_all(5)
		art_panel.add_theme_stylebox_override("panel", art_style)
	set_meta("external_illustration_active", illustration_active)
	set_meta("illustration_fallback_active", not illustration_active)


func _tooltip_text() -> String:
	if _item == null or not _item.is_valid():
		return ""
	var action_hint := "按下并在牌面松开以领取；键盘或手柄确认也可领取。" \
		if _item.claimable else _item.public_claim_disabled_reason
	if _pending:
		action_hint = "领取请求已提交，等待权威结果。"
	elif not _last_feedback.is_empty():
		action_hint = _feedback_tooltip()
	return "%s｜%s\n%s\n供给 %d｜需求 %d｜市场价 ¥%d\n%s" % [
		_item.public_name,
		_item.public_industry,
		_item.public_short_effect,
		_item.public_supply_pressure,
		_item.public_demand_pressure,
		_item.public_market_price,
		action_hint,
	]


func _assistive_name() -> String:
	if _item == null or not _item.is_valid():
		return "商品来源卡不可用"
	return "%s，%s" % [_item.public_name, claim_state_label.text if claim_state_label != null else ""]


func _feedback_tooltip() -> String:
	if _last_feedback.is_empty():
		return ""
	var detail := str(_last_feedback.get("detail", "")).strip_edges()
	var suggestion := str(_last_feedback.get("suggestion", "")).strip_edges()
	return "%s%s" % [detail, "\n%s" % suggestion if not suggestion.is_empty() else ""]


func _apply_style() -> void:
	var accent := _accent_color(_item.display_accent_id if _item != null else "generic")
	var highlighted := _selected or has_focus()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#07111f").lerp(accent, 0.18 if _pending else (0.14 if highlighted else 0.07))
	style.border_color = Color("#67e8f9") if _pending else (accent if highlighted else Color("#334155").lerp(accent, 0.42))
	style.set_border_width_all(2 if highlighted or _pending else 1)
	style.set_corner_radius_all(6)
	style.set_content_margin(SIDE_LEFT, 7.0)
	style.set_content_margin(SIDE_RIGHT, 7.0)
	style.set_content_margin(SIDE_TOP, 6.0)
	style.set_content_margin(SIDE_BOTTOM, 6.0)
	add_theme_stylebox_override("panel", style)


func _icon_text(icon_id: String) -> String:
	return {
		"life": "生",
		"energy": "能",
		"industry": "工",
		"technology": "技",
		"commerce": "商",
		"shipping": "运",
	}.get(icon_id, "货")


func _accent_color(accent_id: String) -> Color:
	return {
		"life": Color("#4ade80"),
		"energy": Color("#facc15"),
		"industry": Color("#fb923c"),
		"technology": Color("#67e8f9"),
		"commerce": Color("#f472b6"),
		"shipping": Color("#60a5fa"),
	}.get(accent_id, Color("#cbd5e1"))
