extends Control

const RulesSnapshot := preload("res://scripts/viewmodels/rules_quick_reference_snapshot_v06.gd")

@onready var board: Control = %RulesQuickReferenceBoard


func _ready() -> void:
	board.call("set_board", RulesSnapshot.compose(maxf(960.0, size.x - 64.0)))
