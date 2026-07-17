extends Node

var checks := 0
var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var coordinator_scene := load("res://scenes/runtime/GameRuntimeCoordinator.tscn") as PackedScene
	var coordinator := coordinator_scene.instantiate() as GameRuntimeCoordinator
	add_child(coordinator)
	var loop := coordinator.get_node_or_null("RuntimeLoop") as RuntimeLoop
	var ports := coordinator.get_node_or_null("RuntimeWorldPorts") as RuntimeWorldPorts
	var phases := coordinator.get_node_or_null("RuntimePhaseCoordinator") as RuntimePhaseCoordinator
	if loop != null:
		loop.set_process(false)
	_check(loop != null, "production RuntimeLoop exists")
	_check(ports != null and ports.get_child_count() == 7, "production port composition contains seven ports")
	_check(phases != null and phases.get_child_count() == 6, "production phase composition contains six coordinators")
	_check(coordinator.find_children("RuntimeWorldPorts", "RuntimeWorldPorts", true, false).size() == 1, "production port composition is unique")
	var loop_debug := loop.debug_snapshot() if loop != null else {}
	var port_debug := ports.debug_snapshot() if ports != null else {}
	_check(int(loop_debug.get("phase_count", 0)) == 6 and not loop_debug.has("port_count"), "RuntimeLoop reports only the six-phase boundary")
	_check(not loop_debug.has("players") and not loop_debug.has("districts") and not loop_debug.has("world"), "RuntimeLoop owns no world state")
	_check(not port_debug.has("players") and not port_debug.has("districts") and not port_debug.has("cash"), "port diagnostics expose no mutable or private world state")
	_check(not bool(port_debug.get("references_main", true)) and not bool(port_debug.get("owns_world_state", true)), "port composition references neither Main nor world ownership")
	print("TypedWorldPortsBoundaryBench: %s %d/%d" % ["PASS" if failures.is_empty() else "FAIL", checks - failures.size(), checks])
	if not failures.is_empty():
		push_error("\n- ".join(failures))
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
