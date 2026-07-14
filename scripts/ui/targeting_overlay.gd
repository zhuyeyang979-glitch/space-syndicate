extends Control
class_name TargetingOverlay

@export var reduced_motion := false

const VALID_DROP_COPY := "松开出牌"
const INVALID_DROP_COPY := "不能出牌"
const NO_MAP_COPY := "拖到星球地图"

var _active := false
var _valid := false
var _from_point := Vector2.ZERO
var _to_point := Vector2.ZERO
var _label_text := NO_MAP_COPY
var _reason_text := ""
@onready var _label: Label = %TargetingOverlayLabel
var _pulse_phase := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(not reduced_motion)
	clear_targeting()


func _process(delta: float) -> void:
	if not _active or reduced_motion:
		return
	_pulse_phase = fmod(_pulse_phase + delta * 0.9, 1.0)
	queue_redraw()


func set_targeting(from_point: Vector2, to_point: Vector2, valid: bool, label_text: String, reason_text: String = "") -> void:
	_active = true
	_valid = valid
	_from_point = from_point
	_to_point = to_point
	_label_text = label_text
	_reason_text = reason_text
	_update_label()
	queue_redraw()


func set_state(state: Dictionary) -> void:
	var from_point := _point_from(state.get("from", Vector2(760, 600)))
	var to_point := _point_from(state.get("to", Vector2(720, 430)))
	set_targeting(from_point, to_point, bool(state.get("valid", false)), str(state.get("label", "拖到星球地图")), str(state.get("reason", "")))


func clear_targeting() -> void:
	_active = false
	if _label != null:
		_label.visible = false
	queue_redraw()


func is_targeting_active() -> bool:
	return _active


func _draw() -> void:
	if not _active:
		return
	var color := Color("#facc15") if _valid else Color("#fb7185")
	var points := _curve_points(_from_point, _to_point)
	var glow := Color(color.r, color.g, color.b, 0.13)
	draw_polyline(points, glow, 15.0, true)
	draw_polyline(points, Color(color.r, color.g, color.b, 0.34), 7.0, true)
	draw_polyline(points, color, 2.6, true)
	var direction := (points[points.size() - 1] - points[points.size() - 2]).normalized()
	if direction.length() <= 0.01:
		direction = Vector2.UP
	var normal := Vector2(-direction.y, direction.x)
	draw_colored_polygon(PackedVector2Array([
		_to_point,
		_to_point - direction * 24.0 + normal * 10.0,
		_to_point - direction * 18.0,
		_to_point - direction * 24.0 - normal * 10.0,
	]), color)
	var pulse := 1.0 if reduced_motion else 0.78 + 0.22 * sin(_pulse_phase * TAU)
	draw_circle(_to_point, 48.0 * pulse, Color(color.r, color.g, color.b, 0.10))
	draw_arc(_to_point, 38.0 * pulse, 0.0, TAU, 48, Color(color.r, color.g, color.b, 0.54), 2.0, true)
	draw_circle(_to_point, 15.0, Color(color.r, color.g, color.b, 0.22))
	if not reduced_motion:
		var travel_index := clampi(int(round(_pulse_phase * float(points.size() - 1))), 0, points.size() - 1)
		draw_circle(points[travel_index], 5.0, color)


func _update_label() -> void:
	if _label == null:
		return
	_label.visible = _active
	_label.text = _label_text if _reason_text == "" else "%s｜%s" % [_label_text, _reason_text]
	_label.position = _to_point + Vector2(-122, 48)
	_label.modulate = Color("#fde68a") if _valid else Color("#fecdd3")
	_label.tooltip_text = _reason_text
	_label.set_meta("player_assistive_name", _label.text)


func _curve_points(from_point: Vector2, to_point: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	var distance := from_point.distance_to(to_point)
	var lift := clampf(distance * 0.22, 38.0, 130.0)
	var control_a := from_point + Vector2(0.0, -lift)
	var control_b := to_point + Vector2(-distance * 0.12, lift * 0.18)
	for index in range(25):
		var t := float(index) / 24.0
		var inv := 1.0 - t
		var point := inv * inv * inv * from_point
		point += 3.0 * inv * inv * t * control_a
		point += 3.0 * inv * t * t * control_b
		point += t * t * t * to_point
		result.append(point)
	return result


func _point_from(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array:
		var point_array: Array = value
		if point_array.size() >= 2:
			return Vector2(float(point_array[0]), float(point_array[1]))
	return Vector2.ZERO
