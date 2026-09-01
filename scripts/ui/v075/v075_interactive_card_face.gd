extends Control
class_name V075InteractiveCardFace

signal activated(payload: Dictionary)
signal hover_summary(payload: Dictionary)
signal hover_ended
signal drag_started(payload: Dictionary)
signal selection_presentation_finished(
	receipt_id: String,
	evidence: Dictionary
)

const HOVER_SCALE := 1.08
const HOVER_LIFT_PX := 18.0
const HOVER_SECONDS := 0.12
const SELECT_SCALE := 1.04
const SELECT_LIFT_PX := 8.0
const SELECT_SECONDS := 0.12
const DRAG_DEADZONE_PX := 10.0

@onready var _face: SpaceSyndicateCardFace = %CardFace

var _payload: Dictionary = {}
var _presentation_data: Dictionary = {}
var _selected := false
var _draggable := false
var _hovered := false
var _motion_tween: Tween
var _selection_tween: Tween
var _drag_candidate := false
var _drag_gesture_started := false
var _drag_start_position := Vector2.ZERO
var _selection_presentation_generation := 0
var _active_selection_receipt_id := ""
var _active_selection_start_rect := Rect2()


func _ready() -> void:
	_face.custom_minimum_size = Vector2.ZERO
	_face.card_clicked.connect(_on_face_clicked)
	_face.mouse_entered.connect(_on_mouse_entered)
	_face.mouse_exited.connect(_on_mouse_exited)
	_face.gui_input.connect(_on_face_gui_input)
	if not _presentation_data.is_empty():
		_face.set_card_data(_presentation_data)
		tooltip_text = str(_presentation_data.get(
			"tooltip",
			_face.tooltip_text
		))
		_face.tooltip_text = tooltip_text
	_apply_visual_state(false)


func _exit_tree() -> void:
	if not _active_selection_receipt_id.is_empty():
		if _selection_tween != null and _selection_tween.is_valid():
			_selection_tween.kill()
		_finish_active_selection_presentation("INTERRUPTED_BY_EXIT_TREE")


func configure(
	payload: Dictionary,
	presentation_data: Dictionary,
	draggable := false
) -> void:
	_payload = payload.duplicate(true)
	_presentation_data = presentation_data.duplicate(true)
	_draggable = draggable
	if is_node_ready():
		_face.set_card_data(_presentation_data)
		tooltip_text = str(_presentation_data.get(
			"tooltip",
			_face.tooltip_text
		))
		_face.tooltip_text = tooltip_text
		_apply_visual_state(false)


func payload() -> Dictionary:
	return _payload.duplicate(true)


func presentation_data() -> Dictionary:
	return _presentation_data.duplicate(true)


func set_selected(value: bool) -> void:
	if _selected and not value:
		cancel_authorized_selection_presentation("INTERRUPTED_BY_DESELECT")
	_selected = value
	if is_node_ready():
		_apply_visual_state(false)


func play_authorized_selection_presentation(
	receipt_id: String,
	reduced_motion := false
) -> bool:
	if (
		receipt_id.is_empty()
		or not _selected
		or not is_inside_tree()
		or not is_instance_valid(_face)
	):
		return false
	if not _active_selection_receipt_id.is_empty():
		cancel_authorized_selection_presentation("INTERRUPTED_BY_REPLAY")
	_selection_presentation_generation += 1
	var generation := _selection_presentation_generation
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
	var start_rect := _face.get_global_rect()
	_active_selection_receipt_id = receipt_id
	_active_selection_start_rect = start_rect
	var target_scale := Vector2.ONE * (
		SELECT_SCALE if not _hovered else HOVER_SCALE
	)
	var target_position := Vector2(
		0.0,
		-HOVER_LIFT_PX if _hovered else -SELECT_LIFT_PX
	)
	_face.pivot_offset = _face.size * 0.5
	_face.scale = target_scale * (0.985 if reduced_motion else 0.92)
	_face.position = target_position + Vector2(0.0, 2.0 if reduced_motion else 7.0)
	_selection_tween = create_tween()
	_selection_tween.set_parallel(true)
	_selection_tween.set_trans(Tween.TRANS_BACK)
	_selection_tween.set_ease(Tween.EASE_OUT)
	var duration := 0.04 if reduced_motion else SELECT_SECONDS
	_selection_tween.tween_property(_face, "scale", target_scale, duration)
	_selection_tween.tween_property(_face, "position", target_position, duration)
	_selection_tween.finished.connect(
		_on_selection_presentation_tween_finished.bind(
			generation, receipt_id, start_rect
		),
		CONNECT_ONE_SHOT
	)
	return true


func cancel_authorized_selection_presentation(
	reason := "INTERRUPTED_BY_SURFACE"
) -> bool:
	if _active_selection_receipt_id.is_empty():
		return false
	if _selection_tween != null and _selection_tween.is_valid():
		_selection_tween.kill()
	_selection_tween = null
	_finish_active_selection_presentation(reason)
	return true


func card_face() -> SpaceSyndicateCardFace:
	return _face


func debug_snapshot() -> Dictionary:
	var disabled := bool(_presentation_data.get(
		"disabled",
		_payload.get("disabled", false)
	))
	return {
		"instance_id": str(_payload.get("instance_id", "")),
		"card_definition_id": str(_payload.get(
			"card_definition_id",
			_payload.get("definition_id", "")
		)),
		"authority_zone": str(_payload.get("authority_zone", "")),
		"projection_role": str(_payload.get("projection_role", "")),
		"selected": _selected,
		"hovered": _hovered,
		"draggable": _draggable,
		"drag_candidate": _drag_candidate,
		"drag_gesture_started": _drag_gesture_started,
		"disabled": disabled,
		"legality_state": str(_presentation_data.get(
			"legality_state",
			_presentation_data.get("play_state", "")
		)),
		"purpose_readable": not str(_presentation_data.get(
			"summary",
			_presentation_data.get("effect", "")
		)).strip_edges().is_empty(),
		"semantic_fields_present": [
			"name", "cost", "type", "rank", "effect", "summary",
			"use_case", "target_type", "legality_state",
		],
		"hover_scale": HOVER_SCALE,
		"hover_lift_px": HOVER_LIFT_PX,
		"uses_card_face": true,
		"layout_reflow_count": 0,
	}


func _on_face_clicked(_data: Dictionary) -> void:
	if bool(_presentation_data.get("disabled", _payload.get("disabled", false))):
		return
	activated.emit(_payload.duplicate(true))


## Compatibility bridge for the production readiness harness and keyboard/mouse
## adapters.  Real input still arrives through the owned CardFace signal.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
			_on_face_clicked(_payload)
			accept_event()


func _on_mouse_entered() -> void:
	_hovered = true
	z_index = 40
	_apply_visual_state(true)
	hover_summary.emit(_payload.duplicate(true))


func _on_mouse_exited() -> void:
	_hovered = false
	z_index = 1 if _selected else 0
	_apply_visual_state(true)
	hover_ended.emit()


func _on_face_gui_input(event: InputEvent) -> void:
	if bool(_presentation_data.get("disabled", _payload.get("disabled", false))):
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		if button.pressed:
			_drag_candidate = _draggable and not _payload.is_empty()
			_drag_gesture_started = false
			_drag_start_position = button.position
		else:
			_drag_candidate = false
			_drag_gesture_started = false
			_apply_visual_state(true)
		return
	if not _draggable or not (event is InputEventMouseMotion):
		return
	var motion := event as InputEventMouseMotion
	if (
		not _drag_candidate
		or (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0
		or motion.position.distance_to(_drag_start_position) < DRAG_DEADZONE_PX
	):
		return
	_drag_candidate = false
	_drag_gesture_started = true
	cancel_authorized_selection_presentation("INTERRUPTED_BY_DRAG")
	_apply_visual_state(true)
	var envelope := _drag_envelope()
	var preview := _drag_preview()
	# CardFace is the actual STOP-filter hit control in the production scene.
	# Starting the native drag here keeps Godot's real drag discovery path alive
	# even though the semantic wrapper owns the payload and telemetry.
	_face.force_drag(envelope, preview)
	drag_started.emit(_payload.duplicate(true))


func _drag_envelope() -> Dictionary:
	return {
		"drag_type": "v073_card",
		"payload": _payload.duplicate(true),
	}


func _drag_preview() -> Control:
	var preview := duplicate() as Control
	preview.modulate = Color(1.0, 1.0, 1.0, 0.86)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return preview


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not _draggable or _payload.is_empty() or bool(
		_presentation_data.get("disabled", _payload.get("disabled", false))
	):
		return null
	set_drag_preview(_drag_preview())
	return _drag_envelope()


func _apply_visual_state(animated: bool) -> void:
	if not is_instance_valid(_face):
		return
	if (
		_active_selection_receipt_id.is_empty()
		and _motion_tween != null
		and _motion_tween.is_valid()
	):
		_motion_tween.kill()
	var target_scale := Vector2.ONE * (
		HOVER_SCALE if _hovered else SELECT_SCALE if _selected else 1.0
	)
	var target_position := Vector2(
		0.0,
		-HOVER_LIFT_PX if _hovered else -SELECT_LIFT_PX if _selected else 0.0
	)
	_face.pivot_offset = _face.size * 0.5
	var disabled := bool(_presentation_data.get(
		"disabled",
		_payload.get("disabled", false)
	))
	var drop_valid := bool(_presentation_data.get(
		"drop_valid",
		not disabled
	))
	_face.set_interaction_state({
		"hovered": _hovered,
		"selected": _selected,
		"dragging": _drag_gesture_started,
		"pressed": false,
		"returning": false,
		"disabled": disabled,
		"drop_valid": drop_valid,
		"drop_invalid": not drop_valid,
		"resolving": bool(_payload.get("resolving", false)),
	})
	if not _active_selection_receipt_id.is_empty():
		return
	if not animated or not is_inside_tree():
		_face.scale = target_scale
		_face.position = target_position
		return
	_motion_tween = create_tween()
	_motion_tween.set_parallel(true)
	_motion_tween.set_trans(Tween.TRANS_CUBIC)
	_motion_tween.set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(_face, "scale", target_scale, HOVER_SECONDS)
	_motion_tween.tween_property(_face, "position", target_position, HOVER_SECONDS)


func _on_selection_presentation_tween_finished(
	generation: int,
	receipt_id: String,
	start_rect: Rect2
) -> void:
	if generation != _selection_presentation_generation:
		return
	if receipt_id != _active_selection_receipt_id:
		return
	_selection_tween = null
	_finish_active_selection_presentation("SETTLED", start_rect)
	if is_inside_tree():
		call_deferred("_apply_visual_state", false)


func _finish_active_selection_presentation(
	terminal_status: String,
	start_rect := Rect2()
) -> void:
	var receipt_id := _active_selection_receipt_id
	if receipt_id.is_empty():
		return
	var resolved_start_rect := (
		start_rect
		if start_rect.has_area()
		else _active_selection_start_rect
	)
	_active_selection_receipt_id = ""
	_active_selection_start_rect = Rect2()
	_selection_presentation_generation += 1
	selection_presentation_finished.emit(receipt_id, {
		"schema": "V076CardSelectionPresentationEvidenceV1",
		"receipt_id": receipt_id,
		"card_instance_id": str(_payload.get("instance_id", "")),
		"start_rect": resolved_start_rect,
		"end_rect": _face.get_global_rect(),
		"selected": _selected,
		"terminal_status": terminal_status,
		"presentation_only": true,
		"gameplay_mutation_count": 0,
		"rng_draw_delta": 0,
		"authority_sequence_delta": 0,
	})
