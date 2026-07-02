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
var _label: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.name = "TargetingOverlayLabel"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.custom_minimum_size = Vector2(220, 34)
	add_child(_label)
	clear_targeting()


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
	draw_line(_from_point, _to_point, color, 5.0)
	var direction := (_to_point - _from_point).normalized()
	if direction.length() <= 0.01:
		direction = Vector2.UP
	var normal := Vector2(-direction.y, direction.x)
	draw_line(_to_point, _to_point - direction * 24.0 + normal * 11.0, color, 5.0)
	draw_line(_to_point, _to_point - direction * 24.0 - normal * 11.0, color, 5.0)
	draw_circle(_to_point, 46.0, Color(color.r, color.g, color.b, 0.18))
	draw_circle(_to_point, 20.0, Color(color.r, color.g, color.b, 0.35))
	if not reduced_motion:
		draw_circle(_from_point.lerp(_to_point, 0.5), 7.0, color)


func _update_label() -> void:
	if _label == null:
		return
	_label.visible = _active
	_label.text = _label_text if _reason_text == "" else "%s｜%s" % [_label_text, _reason_text]
	_label.position = _to_point + Vector2(-110, 42)
	_label.modulate = Color("#fde68a") if _valid else Color("#fecdd3")


func _point_from(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array:
		var point_array: Array = value
		if point_array.size() >= 2:
			return Vector2(float(point_array[0]), float(point_array[1]))
	return Vector2.ZERO
