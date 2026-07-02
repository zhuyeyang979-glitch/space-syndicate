@tool
extends Control
class_name HandLayout

@export var card_size: Vector2 = Vector2(150, 210)
@export var max_spread_width: float = 980.0
@export var max_fan_angle_degrees: float = 16.0
@export var arc_height: float = 28.0
@export var bottom_padding: float = 10.0
@export var hover_lift: float = 58.0
@export var hover_scale: float = 1.15
@export var hover_neighbor_push: float = 32.0
@export var selected_lift: float = 30.0
@export var selected_scale: float = 1.07
@export var drag_lift: float = 48.0
@export var drag_scale: float = 1.12
@export var invalid_drop_sag: float = 10.0
@export var comfortable_gap_ratio: float = 0.74
@export var compressed_gap_ratio: float = 0.54
@export var pressure_gap_ratio: float = 0.40
@export var compression_start_count: int = 6
@export var pressure_start_count: int = 11
@export var max_visible_count: int = 15
@export var overflow_policy: String = "overflow_stack"
@export var card_scale_min: float = 0.58
@export var seek_position_gain: float = 18.0
@export var seek_rotation_gain: float = 20.0
@export var seek_scale_gain: float = 16.0
@export var motion_arrival_epsilon: float = 0.35

var _hovered_card: Control = null
var _selected_card: Control = null
var _dragged_card: Control = null
var _returning_card: Control = null
var _drag_drop_valid := true
var _motion_cards: Array[Control] = []

func _ready() -> void:
	set_process(false)
	_queue_relayout()


func _process(delta: float) -> void:
	_pump_card_motion(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_queue_relayout()


func relayout(snap: bool = true) -> void:
	_connect_card_signals()
	_layout_cards(snap)


func get_hovered_card() -> Control:
	_hovered_card = _validated_card(_hovered_card)
	return _hovered_card


func set_hovered_card(card: Control) -> void:
	_hovered_card = card if card != null and card.get_parent() == self else null
	_layout_cards(false)
	_pump_card_motion(1.0 / 60.0)


func get_selected_card() -> Control:
	_selected_card = _validated_card(_selected_card)
	return _selected_card


func set_selected_card(card: Control) -> void:
	_selected_card = card if card != null and card.get_parent() == self else null
	_layout_cards(false)
	_pump_card_motion(1.0 / 60.0)


func clear_selected_card() -> void:
	set_selected_card(null)


func get_dragged_card() -> Control:
	_dragged_card = _validated_card(_dragged_card)
	return _dragged_card


func set_dragged_card(card: Control, valid_drop: bool = true) -> void:
	var previous_dragged := get_dragged_card()
	_dragged_card = card if card != null and card.get_parent() == self else null
	_drag_drop_valid = valid_drop
	if _dragged_card != null:
		_returning_card = null
	elif previous_dragged != null:
		_returning_card = previous_dragged
	_layout_cards(false)
	_pump_card_motion(1.0 / 60.0)


func set_drag_drop_valid(valid_drop: bool) -> void:
	_drag_drop_valid = valid_drop
	_layout_cards(false)


func clear_dragged_card() -> void:
	set_dragged_card(null, true)


func get_card_target_snapshot() -> Array:
	var result: Array = []
	for card in _card_children():
		var state := _card_interaction_state(card)
		var target_position: Vector2 = card.get_meta("hand_target_position", card.position)
		var target_rotation: float = float(card.get_meta("hand_target_rotation", card.rotation))
		var target_scale: Vector2 = card.get_meta("hand_target_scale", card.scale)
		result.append({
			"name": card.name,
			"position": target_position,
			"rotation": target_rotation,
			"scale": target_scale,
			"target_position": target_position,
			"target_rotation": target_rotation,
			"target_scale": target_scale,
			"z_index": int(card.get_meta("hand_target_z_index", card.z_index)),
			"hovered": bool(state.get("hovered", false)),
			"selected": bool(state.get("selected", false)),
			"dragging": bool(state.get("dragging", false)),
			"pressed": bool(state.get("pressed", false)),
			"drop_valid": bool(state.get("drop_valid", true)),
			"drop_invalid": bool(state.get("drop_invalid", false)),
			"drag_state": str(state.get("drag_state", "idle")),
			"state_tokens": state.get("tokens", []),
			"profile": str(card.get_meta("hand_layout_profile", "")),
			"slot_ratio": float(card.get_meta("hand_slot_ratio", 0.5)),
			"gap": float(card.get_meta("hand_layout_gap", 0.0)),
			"visible_ratio": float(card.get_meta("hand_visible_ratio", 1.0)),
			"overflow_hidden": bool(card.get_meta("hand_overflow_hidden", false)),
			"drop_zone": card.get_meta("hand_drop_preview_zone", Rect2()),
		})
	return result


func _queue_relayout() -> void:
	if is_inside_tree():
		call_deferred("relayout")


func _card_children() -> Array[Control]:
	var result: Array[Control] = []
	for child in get_children():
		if child is Control:
			result.append(child as Control)
	return result


func _connect_card_signals() -> void:
	for card in _card_children():
		var entered: Callable = Callable(self, "_on_card_mouse_entered").bind(card)
		if not card.mouse_entered.is_connected(entered):
			card.mouse_entered.connect(entered)
		var exited: Callable = Callable(self, "_on_card_mouse_exited").bind(card)
		if not card.mouse_exited.is_connected(exited):
			card.mouse_exited.connect(exited)


func _layout_cards(snap: bool = false) -> void:
	var cards: Array[Control] = _card_children()
	var count: int = cards.size()
	if count == 0:
		_motion_cards.clear()
		set_process(false)
		return
	var hovered_card: Control = get_hovered_card()
	var selected_card: Control = get_selected_card()
	var dragged_card: Control = get_dragged_card()
	var focus_card: Control = dragged_card if dragged_card != null else (hovered_card if hovered_card != null else selected_card)
	var focus_index: int = cards.find(focus_card)

	var layout_card_size: Vector2 = _fitted_card_size(count)
	var profile := _hand_layout_profile(count)
	var usable_width: float = minf(max_spread_width, maxf(size.x - layout_card_size.x, 0.0))
	var gap: float = 0.0
	if count > 1:
		gap = minf(usable_width / float(count - 1), layout_card_size.x * float(profile.get("gap_ratio", comfortable_gap_ratio)))

	var total_width: float = gap * float(max(count - 1, 0)) + layout_card_size.x
	var start_x: float = (size.x - total_width) * 0.5
	var base_y: float = maxf(0.0, size.y - layout_card_size.y - bottom_padding)
	var profile_name := str(profile.get("name", "comfortable"))
	var fan_strength := float(profile.get("fan_strength", 0.65))
	var arc_strength := float(profile.get("arc_strength", 0.65))
	var hover_lift_multiplier := float(profile.get("hover_lift_multiplier", 1.0))
	var neighbor_push_multiplier := float(profile.get("neighbor_push_multiplier", 1.0))
	var profile_max_visible: int = maxi(1, int(profile.get("max_visible_count", max_visible_count)))
	var overflow_start: int = maxi(count - profile_max_visible, 0)
	var drop_zone_height := minf(size.y, maxf(layout_card_size.y * 0.34, 28.0))
	var drop_zone := Rect2(0.0, maxf(0.0, size.y - drop_zone_height), size.x, drop_zone_height)

	for i in range(count):
		var card: Control = cards[i]
		var ratio: float = _slot_ratio(i, count)
		var centered_ratio: float = (ratio - 0.5) * 2.0
		var arc_curve: float = 1.0 - pow(absf(centered_ratio), 2.0)
		var y_offset: float = -arc_height * arc_strength * maxf(0.0, arc_curve)
		var angle: float = deg_to_rad(max_fan_angle_degrees * fan_strength * centered_ratio)
		var target_position: Vector2 = Vector2(start_x + gap * float(i), base_y + y_offset).round()
		var target_scale: Vector2 = Vector2.ONE
		var target_z: int = i
		var overflow_hidden: bool = overflow_start > 0 and i < overflow_start and card != focus_card and card != selected_card and card != dragged_card and card != hovered_card
		var visible_ratio: float = 0.35 if overflow_hidden else 1.0
		if overflow_hidden:
			target_position.x = clampf(start_x - minf(24.0, layout_card_size.x * 0.18) + float(i % 4) * 3.0, 0.0, maxf(0.0, size.x - layout_card_size.x))
			target_position.y = base_y + float(i % 4) * 1.5
			target_scale = Vector2.ONE * 0.72
			angle = deg_to_rad(-max_fan_angle_degrees * 0.25)

		if focus_index >= 0 and card != focus_card:
			var hover_distance: int = absi(i - focus_index)
			if hover_distance <= 2:
				var push_dir: float = -1.0 if i < focus_index else 1.0
				var push_strength: float = 1.0 if hover_distance == 1 else 0.42
				target_position.x += push_dir * hover_neighbor_push * neighbor_push_multiplier * push_strength
				target_position.x = clampf(target_position.x, 0.0, maxf(0.0, size.x - layout_card_size.x))

		card.custom_minimum_size = layout_card_size
		card.size = layout_card_size
		card.pivot_offset = layout_card_size * 0.5

		if card == selected_card:
			target_position.y = maxf(-selected_lift, target_position.y - selected_lift)
			target_position.x = clampf(target_position.x, 0.0, maxf(0.0, size.x - layout_card_size.x))
			angle *= 0.35
			target_scale = Vector2.ONE * selected_scale
			target_z = max(target_z, 900)
		if card == hovered_card:
			var active_hover_lift := hover_lift * hover_lift_multiplier
			var hover_floor := -minf(active_hover_lift, layout_card_size.y * 0.50)
			target_position.y = maxf(hover_floor, target_position.y - active_hover_lift)
			target_position.x = clampf(target_position.x, 0.0, maxf(0.0, size.x - layout_card_size.x))
			angle = 0.0
			target_scale = Vector2.ONE * hover_scale
			target_z = 1000
		if card == dragged_card:
			var drag_floor := -minf(drag_lift, layout_card_size.y * 0.50)
			target_position.y = maxf(drag_floor, target_position.y - drag_lift)
			if not _drag_drop_valid:
				target_position.y += invalid_drop_sag
			target_position.x = clampf(target_position.x, 0.0, maxf(0.0, size.x - layout_card_size.x))
			angle = 0.0
			target_scale = Vector2.ONE * drag_scale
			target_z = 1100
		var interaction_state := _build_card_interaction_state(card, hovered_card, selected_card, dragged_card)
		_set_card_motion_target(
			card,
			target_position,
			angle,
			target_scale,
			target_z,
			snap or not card.has_meta("hand_target_position"),
			{
				"hand_layout_profile": profile_name,
				"hand_slot_ratio": ratio,
				"hand_layout_gap": gap,
				"hand_visible_ratio": visible_ratio,
				"hand_overflow_hidden": overflow_hidden,
				"hand_drop_preview_zone": drop_zone,
				"hand_interaction_state": interaction_state,
			}
		)
		_apply_card_interaction_state(card, interaction_state)
	_update_motion_process()


func _set_card_motion_target(card: Control, target_position: Vector2, target_rotation: float, target_scale: Vector2, target_z: int, snap: bool, layout_meta: Dictionary = {}) -> void:
	card.set_meta("hand_target_position", target_position)
	card.set_meta("hand_target_rotation", target_rotation)
	card.set_meta("hand_target_scale", target_scale)
	card.set_meta("hand_target_z_index", target_z)
	for key in layout_meta.keys():
		card.set_meta(StringName(str(key)), layout_meta[key])
	card.z_index = target_z
	if not _motion_cards.has(card):
		_motion_cards.append(card)
	if snap:
		card.position = target_position
		card.rotation = target_rotation
		card.scale = target_scale


func _pump_card_motion(delta: float) -> void:
	if _motion_cards.is_empty():
		set_process(false)
		return
	var active_cards: Array[Control] = []
	for card in _motion_cards:
		if card == null or not is_instance_valid(card) or card.get_parent() != self:
			continue
		var target_position: Vector2 = card.get_meta("hand_target_position", card.position)
		var target_rotation: float = float(card.get_meta("hand_target_rotation", card.rotation))
		var target_scale: Vector2 = card.get_meta("hand_target_scale", card.scale)
		card.position = _seek_vector2(card.position, target_position, seek_position_gain, delta)
		card.rotation = _seek_angle(card.rotation, target_rotation, seek_rotation_gain, delta)
		card.scale = _seek_vector2(card.scale, target_scale, seek_scale_gain, delta)
		if _card_motion_active(card, target_position, target_rotation, target_scale):
			active_cards.append(card)
		else:
			card.position = target_position
			card.rotation = target_rotation
			card.scale = target_scale
	_motion_cards = active_cards
	set_process(not _motion_cards.is_empty())


func _card_motion_active(card: Control, target_position: Vector2, target_rotation: float, target_scale: Vector2) -> bool:
	return card.position.distance_to(target_position) > motion_arrival_epsilon \
		or absf(angle_difference(card.rotation, target_rotation)) > deg_to_rad(0.25) \
		or card.scale.distance_to(target_scale) > 0.003


func _seek_vector2(current: Vector2, target: Vector2, gain: float, delta: float) -> Vector2:
	var factor: float = clampf(gain * delta, 0.0, 1.0)
	return current.lerp(target, factor)


func _seek_angle(current: float, target: float, gain: float, delta: float) -> float:
	var factor: float = clampf(gain * delta, 0.0, 1.0)
	return current + angle_difference(current, target) * factor


func _update_motion_process() -> void:
	set_process(not _motion_cards.is_empty())


func _fitted_card_size(count: int = 1) -> Vector2:
	var height_room: float = maxf(54.0, size.y - bottom_padding - 2.0)
	var profile := _hand_layout_profile(count)
	var min_scale: float = float(profile.get("card_scale_min", card_scale_min))
	var height_scale: float = clampf(height_room / maxf(card_size.y, 1.0), min_scale, 1.0)
	var gap_ratio: float = maxf(0.10, float(profile.get("gap_ratio", comfortable_gap_ratio)))
	var width_room: float = maxf(48.0, minf(size.x, max_spread_width + card_size.x))
	var width_scale: float = 1.0
	if count > 1:
		var needed_width: float = card_size.x * (1.0 + gap_ratio * float(count - 1))
		width_scale = clampf(width_room / maxf(needed_width, 1.0), min_scale, 1.0)
	var scale: float = minf(height_scale, width_scale)
	return Vector2(maxf(48.0, roundf(card_size.x * scale)), maxf(64.0, roundf(card_size.y * scale)))


func _hand_layout_profile(count: int) -> Dictionary:
	if count <= 1:
		return {
			"name": "single_focus",
			"gap_ratio": comfortable_gap_ratio,
			"fan_strength": 0.0,
			"arc_strength": 0.0,
			"card_scale_min": card_scale_min,
			"hover_lift_multiplier": 1.0,
			"neighbor_push_multiplier": 0.0,
			"max_visible_count": max_visible_count,
			"overflow_policy": overflow_policy,
		}
	if count < compression_start_count:
		var fan_strength := lerpf(0.34, 0.62, clampf(float(count - 2) / 3.0, 0.0, 1.0))
		return {
			"name": "comfortable",
			"gap_ratio": comfortable_gap_ratio,
			"fan_strength": fan_strength,
			"arc_strength": 0.58,
			"card_scale_min": card_scale_min,
			"hover_lift_multiplier": 1.0,
			"neighbor_push_multiplier": 1.0,
			"max_visible_count": max_visible_count,
			"overflow_policy": overflow_policy,
		}
	if count < pressure_start_count:
		var pressure := clampf(float(count - compression_start_count) / maxf(1.0, float(pressure_start_count - compression_start_count)), 0.0, 1.0)
		return {
			"name": "compressed",
			"gap_ratio": lerpf(compressed_gap_ratio + 0.05, compressed_gap_ratio, pressure),
			"fan_strength": lerpf(0.74, 0.92, pressure),
			"arc_strength": lerpf(0.72, 0.90, pressure),
			"card_scale_min": card_scale_min,
			"hover_lift_multiplier": lerpf(0.94, 0.88, pressure),
			"neighbor_push_multiplier": lerpf(0.92, 0.78, pressure),
			"max_visible_count": max_visible_count,
			"overflow_policy": overflow_policy,
		}
	if count > max_visible_count:
		return {
			"name": "overflow_stack",
			"gap_ratio": pressure_gap_ratio,
			"fan_strength": 1.0,
			"arc_strength": 1.0,
			"card_scale_min": maxf(card_scale_min, 0.60),
			"hover_lift_multiplier": 0.82,
			"neighbor_push_multiplier": 0.62,
			"max_visible_count": max_visible_count,
			"overflow_policy": overflow_policy,
		}
	return {
		"name": "pressure",
		"gap_ratio": pressure_gap_ratio,
		"fan_strength": 1.0,
		"arc_strength": 1.0,
		"card_scale_min": card_scale_min,
		"hover_lift_multiplier": 0.86,
		"neighbor_push_multiplier": 0.70,
		"max_visible_count": max_visible_count,
		"overflow_policy": overflow_policy,
	}


func _slot_ratio(index: int, count: int) -> float:
	if count <= 1:
		return 0.5
	var linear := float(index) / float(count - 1)
	return clampf(linear, 0.0, 1.0)


func _validated_card(card: Control) -> Control:
	if card == null:
		return null
	if not is_instance_valid(card) or card.get_parent() != self:
		return null
	return card


func _build_card_interaction_state(card: Control, hovered_card: Control, selected_card: Control, dragged_card: Control) -> Dictionary:
	var hovered := card == hovered_card
	var selected := card == selected_card
	var dragging := card == dragged_card
	var returning := card == _returning_card and not dragging
	var pressed := bool(card.get_meta("hand_card_pressed", false))
	var disabled := bool(card.get_meta("hand_card_drag_disabled", false))
	var drop_valid := not dragging or _drag_drop_valid
	var drop_invalid := dragging and not _drag_drop_valid
	var drag_state := "idle"
	if disabled and not dragging:
		drag_state = "disabled"
	if pressed:
		drag_state = "pressed"
	if returning:
		drag_state = "returning"
	if dragging:
		drag_state = "valid_drop" if _drag_drop_valid else "invalid_drop"
	var tokens: Array[String] = []
	if hovered:
		tokens.append("hover")
	if selected:
		tokens.append("selected")
	if pressed:
		tokens.append("pressed")
	if dragging:
		tokens.append("drag")
	if returning:
		tokens.append("returning")
	if disabled:
		tokens.append("disabled")
	if drop_invalid:
		tokens.append("invalid_drop")
	return {
		"hovered": hovered,
		"selected": selected,
		"dragging": dragging,
		"pressed": pressed,
		"returning": returning,
		"disabled": disabled,
		"drop_valid": drop_valid,
		"drop_invalid": drop_invalid,
		"drag_state": drag_state,
		"tokens": tokens,
	}


func _card_interaction_state(card: Control) -> Dictionary:
	var state_variant: Variant = card.get_meta("hand_interaction_state", {})
	return state_variant if state_variant is Dictionary else {}


func _apply_card_interaction_state(card: Control, state: Dictionary) -> void:
	card.set_meta("hand_state_hovered", bool(state.get("hovered", false)))
	card.set_meta("hand_state_selected", bool(state.get("selected", false)))
	card.set_meta("hand_state_dragging", bool(state.get("dragging", false)))
	card.set_meta("hand_state_pressed", bool(state.get("pressed", false)))
	card.set_meta("hand_state_returning", bool(state.get("returning", false)))
	card.set_meta("hand_state_disabled", bool(state.get("disabled", false)))
	card.set_meta("hand_state_drop_valid", bool(state.get("drop_valid", true)))
	card.set_meta("hand_state_drop_invalid", bool(state.get("drop_invalid", false)))
	card.set_meta("hand_drag_state", str(state.get("drag_state", "idle")))
	if card.has_method("set_interaction_state"):
		card.call("set_interaction_state", state)


func _on_card_mouse_entered(card: Control) -> void:
	set_hovered_card(card)


func _on_card_mouse_exited(card: Control) -> void:
	if _hovered_card == card:
		set_hovered_card(null)
