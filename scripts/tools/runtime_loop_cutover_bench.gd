extends Node

var checks := 0
var failures: Array[String] = []


func _ready() -> void:
	var coordinator_scene := load("res://scenes/runtime/GameRuntimeCoordinator.tscn") as PackedScene
	var coordinator := coordinator_scene.instantiate() as GameRuntimeCoordinator
	add_child(coordinator)
	var loop := coordinator.get_node_or_null("RuntimeLoop") as RuntimeLoop
	var ports := coordinator.get_node_or_null("RuntimeWorldPorts") as RuntimeWorldPorts
	var phases := coordinator.get_node_or_null("RuntimePhaseCoordinator") as RuntimePhaseCoordinator
	_check(loop != null, "production coordinator mounts RuntimeLoop")
	_check(ports != null and ports.get_child_count() == 7, "production coordinator mounts seven narrow typed ports")
	_check(phases != null and phases.get_child_count() == 6, "production coordinator mounts six explicit phase coordinators")
	_check(coordinator.find_children("RuntimeLoop", "RuntimeLoop", true, false).size() == 1, "production composition contains one RuntimeLoop")
	_check(loop != null and loop.is_processing(), "RuntimeLoop owns an enabled process callback")
	var snapshot := loop.debug_snapshot() if loop != null else {}
	_check(bool(snapshot.get("frame_owner", false)), "RuntimeLoop declares its narrow frame-owner role")
	_check(int(snapshot.get("phase_count", 0)) == 6, "RuntimeLoop reports only the phase boundary")
	_check(snapshot.has("frame_index") and not snapshot.has("players") and not snapshot.has("districts"), "RuntimeLoop debug state contains no gameplay world")
	print("RuntimeLoopCutoverBench: %s %d/%d" % ["PASS" if failures.is_empty() else "FAIL", checks - failures.size(), checks])
	if not failures.is_empty():
		push_error("\n- ".join(failures))
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
