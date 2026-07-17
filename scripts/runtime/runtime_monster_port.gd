extends Node
class_name RuntimeMonsterPort

var _monster: MonsterRuntimeController


func bind_dependency(monster: MonsterRuntimeController) -> void:
	_monster = monster


func is_ready() -> bool:
	return is_instance_valid(_monster)


func tick_wagers(delta_seconds: float) -> void:
	if _monster != null:
		_monster.tick_wagers(delta_seconds)


func tick_motion(delta_seconds: float) -> void:
	if _monster != null:
		_monster.tick_motion(delta_seconds)


func tick_actions(delta_seconds: float) -> void:
	if _monster != null:
		_monster.tick_action_timers(delta_seconds)


func tick_durations(delta_seconds: float) -> void:
	if _monster != null:
		_monster.tick_durations(delta_seconds)


func tick_revivals(delta_seconds: float) -> void:
	if _monster != null:
		_monster.tick_revivals(delta_seconds)


func debug_snapshot() -> Dictionary:
	return {"port_kind": "monster", "ready": is_ready(), "operation_count": 5, "owns_monster_state": false}
