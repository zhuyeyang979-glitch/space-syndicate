extends Node

@onready var coordinator := get_node("GameRuntimeCoordinator")


func _ready() -> void:
	var pipeline := coordinator.get_node_or_null("RuntimeCommandPipeline") as RuntimeCommandPipeline
	var sink := coordinator.get_node_or_null("MonsterMoveCommandSink") as MonsterMoveCommandSink
	var checks := 0
	var failures: Array[String] = []
	checks += 1
	if pipeline == null or sink == null:
		failures.append("production autonomous command composition unavailable")
	checks += 1
	if pipeline != null and not bool(pipeline.debug_snapshot().get("monster_move_ready", false)):
		failures.append("MonsterMoveCommand sink is not bound")
	checks += 1
	if sink != null and not bool(sink.debug_snapshot().get("owns_monster_state", true)):
		pass
	else:
		failures.append("autonomous sink must not own monster state")
	print("SimulationAutonomousBehaviorCommandMigrationBench: %s %d/%d" % ["PASS" if failures.is_empty() else "FAIL", checks - failures.size(), checks])
	if not failures.is_empty():
		push_error("\n- ".join(failures))
	await get_tree().create_timer(2.0).timeout
	get_tree().quit(0 if failures.is_empty() else 1)
