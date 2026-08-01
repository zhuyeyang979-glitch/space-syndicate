extends Control

signal presentation_preview_requested(card_kind: String, interaction: String)

const HOVER_SCALE := 1.08
const HOVER_LIFT_PIXELS := 28.0
const HOVER_DURATION_SECONDS := 0.12
const DRAG_DEADZONE_PIXELS := 8.0
const DRAG_LIFT_DURATION_SECONDS := 0.11
const DRAG_MAX_TILT_DEGREES := 4.0
const SELECTED_OUTLINE_PIXELS := 2
const LEGAL_TARGET_GLOW_PIXELS := 3

@export_enum("normal", "commodity", "bound_action", "card_back") var card_kind := "normal"
@export var card_title := "星际契约"
@export var rank_text := "II"
@export var cost_text := "2 + 1"
@export var status_text := "可用"
@export var accent_color := Color("4ea1ff")
@export var frame_texture: Texture2D
@export var asset_icon: Texture2D
@export var pattern_texture: Texture2D
@export var locked := false

var _origin_position := Vector2.ZERO
var _press_screen_position := Vector2.ZERO
var _drag_offset := Vector2.ZERO
var _pressed := false
var _dragging := false
var _selected := false


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_presentation_data()
	_origin_position = position
	pivot_offset = size * 0.5
	mouse_entered.connect(_on_hover_entered)
	mouse_exited.connect(_on_hover_exited)
	focus_entered.connect(_on_hover_entered)
	focus_exited.connect(_on_hover_exited)
	gui_input.connect(_on_gui_input)


func _apply_presentation_data() -> void:
	var frame := get_node_or_null("Frame") as NinePatchRect
	if frame != null and frame_texture != null:
		frame.texture = frame_texture
	var accent := get_node_or_null("Accent") as ColorRect
	if accent != null:
		accent.color = accent_color
	var icon := get_node_or_null("CardMargin/CardContent/Header/AssetIcon") as TextureRect
	if icon != null:
		icon.texture = asset_icon
	var title := get_node_or_null("CardMargin/CardContent/Header/Title") as Label
	if title != null:
		title.text = card_title
	var rank := get_node_or_null("CardMargin/CardContent/Header/Rank") as Label
	if rank != null:
		rank.text = rank_text
	var pattern := get_node_or_null("CardMargin/CardContent/Art/Pattern") as TextureRect
	if pattern != null:
		pattern.texture = pattern_texture
	var cost := get_node_or_null("CardMargin/CardContent/Cost") as Label
	if cost != null:
		cost.text = cost_text
	var status := get_node_or_null("CardMargin/CardContent/Status") as Label
	if status != null:
		status.text = status_text
	var lock_icon := get_node_or_null("LockIcon") as CanvasItem
	if lock_icon != null:
		lock_icon.visible = locked


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size * 0.5


func _on_hover_entered() -> void:
	if _dragging:
		return
	_animate_pose(_origin_position + Vector2(0.0, -HOVER_LIFT_PIXELS), Vector2.ONE * HOVER_SCALE, 0.0, HOVER_DURATION_SECONDS)


func _on_hover_exited() -> void:
	if _dragging or _pressed:
		return
	_animate_pose(_origin_position, Vector2.ONE, 0.0, HOVER_DURATION_SECONDS)


func _on_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_toggle_selected()
		presentation_preview_requested.emit(card_kind, "focus_confirm")
		accept_event()
		return
	if not event is InputEventMouse:
		return
	var screen_position := get_global_mouse_position()
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		if button.pressed:
			_pressed = true
			_dragging = false
			_press_screen_position = screen_position
			_drag_offset = screen_position - global_position
			accept_event()
			return
		if not _pressed:
			return
		_pressed = false
		if _dragging:
			_dragging = false
			presentation_preview_requested.emit(card_kind, "drag_rebound")
			_animate_pose(_origin_position, Vector2.ONE * HOVER_SCALE, 0.0, HOVER_DURATION_SECONDS)
		else:
			_toggle_selected()
			presentation_preview_requested.emit(card_kind, "click_select")
		accept_event()
	elif event is InputEventMouseMotion and _pressed:
		if not _dragging and screen_position.distance_to(_press_screen_position) < DRAG_DEADZONE_PIXELS:
			return
		if not _dragging:
			_dragging = true
			_animate_pose(position, Vector2.ONE * HOVER_SCALE, 0.0, DRAG_LIFT_DURATION_SECONDS)
		global_position = screen_position - _drag_offset
		var horizontal_delta := clampf((screen_position.x - _press_screen_position.x) / 80.0, -1.0, 1.0)
		rotation_degrees = horizontal_delta * DRAG_MAX_TILT_DEGREES
		accept_event()


func _toggle_selected() -> void:
	_selected = not _selected
	var outline := get_node_or_null("SelectedOutline") as CanvasItem
	if outline != null:
		outline.visible = _selected


func _animate_pose(target_position: Vector2, target_scale: Vector2, target_rotation: float, duration: float) -> void:
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", target_position, duration)
	tween.tween_property(self, "scale", target_scale, duration)
	tween.tween_property(self, "rotation_degrees", target_rotation, duration)


func contract_snapshot() -> Dictionary:
	return {
		"card_kind": card_kind,
		"hover_scale": HOVER_SCALE,
		"hover_lift_pixels": HOVER_LIFT_PIXELS,
		"hover_duration_ms": int(HOVER_DURATION_SECONDS * 1000.0),
		"drag_deadzone_pixels": DRAG_DEADZONE_PIXELS,
		"drag_lift_duration_ms": int(DRAG_LIFT_DURATION_SECONDS * 1000.0),
		"drag_max_tilt_degrees": DRAG_MAX_TILT_DEGREES,
		"selected_outline_pixels": SELECTED_OUTLINE_PIXELS,
		"legal_target_glow_pixels": LEGAL_TARGET_GLOW_PIXELS,
		"mutates_gameplay_state": false,
		"consumes_rng": false,
		"submits_gameplay_intent": false,
	}
