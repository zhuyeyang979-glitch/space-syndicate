extends Node

var checks := 0
var failures: Array[String] = []


func _ready() -> void:
	var coordinator := get_node_or_null("GameRuntimeCoordinator") as GameRuntimeCoordinator
	var loop := coordinator.get_node_or_null("RuntimeLoop") as RuntimeLoop if coordinator != null else null
	var ports := coordinator.get_node_or_null("RuntimeWorldPorts") as RuntimeWorldPorts if coordinator != null else null
	var phases := coordinator.get_node_or_null("RuntimePhaseCoordinator") as RuntimePhaseCoordinator if coordinator != null else null
	if loop != null:
		loop.set_process(false)
	_check(coordinator != null, "production GameRuntimeCoordinator loads")
	_check(loop != null and bool(loop.debug_snapshot().get("frame_owner", false)), "production RuntimeLoop remains the frame owner")
	_check(ports != null and ports.get_child_count() == 7, "production typed-port graph remains intact")
	_check(phases != null and phases.get_child_count() == 6, "production phase graph contains six explicit coordinators")
	var phase_debug := phases.debug_snapshot() if phases != null else {}
	_check(not bool(phase_debug.get("owns_world_state", true)) and not bool(phase_debug.get("owns_gameplay_rules", true)), "phase graph owns neither world state nor gameplay rules")
	_check(coordinator.find_children("RuntimeLoop", "RuntimeLoop", true, false).size() == 1, "production composition has one RuntimeLoop")
	_check(coordinator.find_children("RuntimePhaseCoordinator", "RuntimePhaseCoordinator", true, false).size() == 1, "production composition has one phase root")
	print("RuntimeCoordinationPhaseDecompositionBench: %s %d/%d" % ["PASS" if failures.is_empty() else "FAIL", checks - failures.size(), checks])
	if not failures.is_empty():
		push_error("\n- ".join(failures))
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
