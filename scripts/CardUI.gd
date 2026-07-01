extends Control
class_name CardUI

signal card_double_clicked(card_data: Dictionary)

@export var cost_text: String = "3"
@export var card_name: String = "轨道融资"
@export_multiline var effect_text: String = "提升一座城市的现金流。"
@export var card_type: String = "经济"
@export var stats_text: String = "I"
@export var accent_color: Color = Color(0.45, 0.65, 0.95, 1.0)

var _card_data: Dictionary = {}

@onready var cost_label: Label = %CostLabel
@onready var name_label: Label = %NameLabel
@onready var art_panel: PanelContainer = %ArtPanel
@onready var art_label: Label = %ArtLabel
@onready var effect_label: Label = %EffectLabel
@onready var type_label: Label = %TypeLabel
@onready var stat_label: Label = %StatLabel

func _ready() -> void:
	_apply_data()


func set_card_data(data: Dictionary) -> void:
	_card_data = data.duplicate(true)
	cost_text = str(data.get("cost", data.get("price", data.get("play_cost", cost_text))))
	card_name = str(data.get("name", card_name))
	effect_text = str(data.get("effect", data.get("text", data.get("description", effect_text))))
	card_type = str(data.get("type", data.get("category", card_type)))
	stats_text = str(data.get("rank", data.get("stats", stats_text)))
	if data.has("accent") and data["accent"] is Color:
		accent_color = data["accent"]
	_apply_data()


func get_card_data() -> Dictionary:
	return _card_data.duplicate(true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed and mouse_event.double_click:
			card_double_clicked.emit(get_card_data())


func _apply_data() -> void:
	if not is_node_ready():
		return
	cost_label.text = cost_text
	name_label.text = card_name
	effect_label.text = effect_text
	type_label.text = card_type
	stat_label.text = stats_text
	tooltip_text = "%s\n%s\n%s" % [card_name, card_type, effect_text]
	art_label.text = _art_hint_for_type(card_type)
	var art_style := StyleBoxFlat.new()
	art_style.bg_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.28)
	art_style.border_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.82)
	art_style.border_width_left = 1
	art_style.border_width_top = 1
	art_style.border_width_right = 1
	art_style.border_width_bottom = 1
	art_style.corner_radius_top_left = 8
	art_style.corner_radius_top_right = 8
	art_style.corner_radius_bottom_left = 8
	art_style.corner_radius_bottom_right = 8
	art_panel.add_theme_stylebox_override("panel", art_style)


func _art_hint_for_type(value: String) -> String:
	match value:
		"怪兽":
			return "MONSTER"
		"金融":
			return "FUTURES"
		"情报":
			return "INTEL"
		"军队":
			return "FORCE"
		"合约":
			return "PACT"
		"商品":
			return "GOODS"
		_:
			return "ACTION"
