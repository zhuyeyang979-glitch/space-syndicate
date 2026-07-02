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
@export var comfortable_gap_ratio: float = 0.74
@export var compressed_gap_ratio: float = 0.54
@export var pressure_gap_ratio: float = 0.40
@export var compression_start_count: int = 6
@export var pressure_start_count: int = 11
@export var seek_position_gain: float = 18.0
@export var seek_rotation_gain: float = 20.0
@export var seek_scale_gain: float = 16.0
@export var motion_arrival_epsilon: float = 0.35

var _hovered_card: Control = null
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
	if _hovered_card == null:
		return null
	if not is_instance_valid(_hovered_card) or _hovered_card.get_parent() != self:
		_hovered_card = null
		return null
	return _hovered_card


func set_hovered_card(card: Control) -> void:
	_hovered_card = card if card != null and card.get_parent() == self else null
	_layout_cards(false)
	_pump_card_motion(1.0 / 60.0)


func get_card_target_snapshot() -> Array:
	var result: Array = []
	for card in _card_children():
		result.append({
			"name": card.name,
			"position": card.get_meta("hand_target_position", card.position),
			"rotation": card.get_meta("hand_target_rotation", card.rotation),
			"scale": card.get_meta("hand_target_scale", card.scale),
			"z_index": int(card.get_meta("hand_target_z_index", card.z_index)),
			"hovered": card == get_hovered_card(),
			"profile": str(card.get_meta("hand_layout_profile", "")),
			"slot_ratio": float(card.get_meta("hand_slot_ratio", 0.5)),
			"gap": float(card.get_meta("hand_layout_gap", 0.0)),
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
	var hovered_index: int = cards.find(hovered_card)

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

		if hovered_index >= 0 and card != hovered_card:
			var hover_distance: int = absi(i - hovered_index)
			if hover_distance <= 2:
				var push_dir: float = -1.0 if i < hovered_index else 1.0
				var push_strength: float = 1.0 if hover_distance == 1 else 0.42
				target_position.x += push_dir * hover_neighbor_push * push_strength
				target_position.x = clampf(target_position.x, 0.0, maxf(0.0, size.x - layout_card_size.x))

		card.custom_minimum_size = layout_card_size
		card.size = layout_card_size
		card.pivot_offset = layout_card_size * 0.5

		if card == hovered_card:
			var hover_floor := -minf(hover_lift, layout_card_size.y * 0.50)
			target_position.y = maxf(hover_floor, target_position.y - hover_lift)
			target_position.x = clampf(target_position.x, 0.0, maxf(0.0, size.x - layout_card_size.x))
			angle = 0.0
			target_scale = Vector2.ONE * hover_scale
			target_z = 1000
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
				"hand_drop_preview_zone": drop_zone,
			}
		)
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
	var height_scale: float = clampf(height_room / maxf(card_size.y, 1.0), 0.58, 1.0)
	var profile := _hand_layout_profile(count)
	var gap_ratio: float = maxf(0.10, float(profile.get("gap_ratio", comfortable_gap_ratio)))
	var width_room: float = maxf(48.0, minf(size.x, max_spread_width + card_size.x))
	var width_scale: float = 1.0
	if count > 1:
		var needed_width: float = card_size.x * (1.0 + gap_ratio * float(count - 1))
		width_scale = clampf(width_room / maxf(needed_width, 1.0), 0.58, 1.0)
	var scale: float = minf(height_scale, width_scale)
	return Vector2(maxf(48.0, roundf(card_size.x * scale)), maxf(64.0, roundf(card_size.y * scale)))


func _hand_layout_profile(count: int) -> Dictionary:
	if count <= 1:
		return {
			"name": "single_focus",
			"gap_ratio": comfortable_gap_ratio,
			"fan_strength": 0.0,
			"arc_strength": 0.0,
		}
	if count < compression_start_count:
		var fan_strength := lerpf(0.34, 0.62, clampf(float(count - 2) / 3.0, 0.0, 1.0))
		return {
			"name": "comfortable",
			"gap_ratio": comfortable_gap_ratio,
			"fan_strength": fan_strength,
			"arc_strength": 0.58,
		}
	if count < pressure_start_count:
		var pressure := clampf(float(count - compression_start_count) / maxf(1.0, float(pressure_start_count - compression_start_count)), 0.0, 1.0)
		return {
			"name": "compressed",
			"gap_ratio": lerpf(compressed_gap_ratio + 0.05, compressed_gap_ratio, pressure),
			"fan_strength": lerpf(0.74, 0.92, pressure),
			"arc_strength": lerpf(0.72, 0.90, pressure),
		}
	return {
		"name": "pressure",
		"gap_ratio": pressure_gap_ratio,
		"fan_strength": 1.0,
		"arc_strength": 1.0,
	}


func _slot_ratio(index: int, count: int) -> float:
	if count <= 1:
		return 0.5
	var linear := float(index) / float(count - 1)
	return clampf(linear, 0.0, 1.0)


func _on_card_mouse_entered(card: Control) -> void:
	set_hovered_card(card)


func _on_card_mouse_exited(card: Control) -> void:
	if _hovered_card == card:
		set_hovered_card(null)
