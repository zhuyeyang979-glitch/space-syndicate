extends PanelContainer
class_name SpaceSyndicateTopBar

signal end_turn_requested

@onready var phase_label: Label = %PhaseLabel
@onready var turn_label: Label = %TurnLabel
@onready var resource_label: Label = %ResourceLabel
@onready var end_turn_button: Button = %EndTurnButton

func _ready() -> void:
	if not end_turn_button.pressed.is_connected(_on_end_turn_pressed):
		end_turn_button.pressed.connect(_on_end_turn_pressed)


func set_state(data: Dictionary) -> void:
	phase_label.text = str(data.get("phase", "阶段｜开局"))
	turn_label.text = str(data.get("turn", "席位｜1/4"))
	resource_label.text = str(data.get("resources", "¥ —   GDP —/s   目标 —   手牌 —/—"))


func _on_end_turn_pressed() -> void:
	end_turn_requested.emit()
