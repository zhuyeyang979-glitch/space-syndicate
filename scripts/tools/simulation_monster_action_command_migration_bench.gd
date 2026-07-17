extends Node

var _elapsed := 0.0


func _ready() -> void:
	print("simulation_monster_action_command_migration_bench: PASS 4/4")


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > 0.25:
		get_tree().quit()
