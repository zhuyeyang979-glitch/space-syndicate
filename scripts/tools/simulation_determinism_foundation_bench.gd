extends Node

@onready var phase_coordinator: RuntimePhaseCoordinator = $RuntimePhaseCoordinator
@onready var simulation_step: RuntimeSimulationStep = $RuntimePhaseCoordinator/RuntimeSimulationStep

var _checks := 0
var _failures: Array[String] = []


func _ready() -> void:
	var left := simulation_step.identify_state({"clock_us": 1000, "actors": [{"id": "a", "hp": 8}]}, [{"order_index": 0}])
	var right := simulation_step.identify_state({"actors": [{"hp": 8, "id": "a"}], "clock_us": 1000}, [{"order_index": 0}])
	_check(bool(left.get("valid", false)) and left.get("fingerprint") == right.get("fingerprint"), "canonical simulation identity is stable")
	_check(not str(left.get("fingerprint", "")).is_empty(), "simulation identity emits a non-empty SHA-256 fingerprint")
	var randomness := simulation_step.randomness_boundary.audit([
		{"source_id": "RunRngService", "classification": "seeded_simulation", "seedable": true, "reproducible": true, "can_mutate_world": true},
		{"source_id": "presentation_sparkle", "classification": "visual_only", "seedable": false, "reproducible": false, "can_mutate_world": false},
	])
	_check(bool(randomness.get("valid", false)), "declared seeded and visual randomness stay in their capability boundaries")
	_check(not simulation_step.has_method("_process") and not simulation_step.has_method("_physics_process"), "simulation step is not an engine-frame owner")
	_check(simulation_step.get_child_count() == 4, "scene owns identity, randomness, audit and mutation-authority consumers")
	_check(phase_coordinator.find_children("RuntimeSimulationStep", "RuntimeSimulationStep", true, false).size() == 1, "production phase scene composes exactly one simulation-step owner")
	print("SimulationDeterminismFoundationBench: %s %d/%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks - _failures.size(), _checks])
	if not _failures.is_empty():
		push_error("\n- ".join(_failures))
	await get_tree().create_timer(3.0).timeout
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
