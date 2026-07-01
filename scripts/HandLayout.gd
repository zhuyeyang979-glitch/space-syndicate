@tool
extends Control
class_name HandLayout

@export var card_size: Vector2 = Vector2(150, 210)
@export var max_spread_width: float = 980.0
@export var max_fan_angle_degrees: float = 16.0
@export var arc_height: float = 28.0
@export var bottom_padding: float = 10.0
@export var hover_lift: float = 42.0
@export var hover_scale: float = 1.12

var _hovered_card: Control = null

func _ready() -> void:
	_queue_relayout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_queue_relayout()


func relayout() -> void:
	_connect_card_signals()
	_layout_cards()


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
		var entered := Callable(self, "_on_card_mouse_entered").bind(card)
		if not card.mouse_entered.is_connected(entered):
			card.mouse_entered.connect(entered)
		var exited := Callable(self, "_on_card_mouse_exited").bind(card)
		if not card.mouse_exited.is_connected(exited):
			card.mouse_exited.connect(exited)


func _layout_cards() -> void:
	var cards := _card_children()
	var count := cards.size()
	if count == 0:
		return

	var usable_width: float = minf(max_spread_width, maxf(size.x - card_size.x, 0.0))
	var gap: float = 0.0
	if count > 1:
		gap = minf(usable_width / float(count - 1), card_size.x * 0.64)

	var total_width: float = gap * float(max(count - 1, 0)) + card_size.x
	var start_x: float = (size.x - total_width) * 0.5
	var base_y: float = maxf(0.0, size.y - card_size.y - bottom_padding)

	for i in range(count):
		var card := cards[i]
		var ratio := 0.5
		if count > 1:
			ratio = float(i) / float(count - 1)
		var y_offset: float = -sin(ratio * PI) * arc_height
		var angle: float = deg_to_rad(lerp(-max_fan_angle_degrees, max_fan_angle_degrees, ratio))

		card.custom_minimum_size = card_size
		card.size = card_size
		card.pivot_offset = card_size * 0.5
		card.position = Vector2(start_x + gap * float(i), base_y + y_offset).round()
		card.rotation = angle
		card.scale = Vector2.ONE
		card.z_index = i

		if card == _hovered_card:
			card.position.y = maxf(0.0, card.position.y - hover_lift)
			card.rotation = 0.0
			card.scale = Vector2.ONE * hover_scale
			card.z_index = 1000


func _on_card_mouse_entered(card: Control) -> void:
	_hovered_card = card
	_layout_cards()


func _on_card_mouse_exited(card: Control) -> void:
	if _hovered_card == card:
		_hovered_card = null
	_layout_cards()
