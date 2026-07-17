extends Node

@onready var simulation_step: RuntimeSimulationStep = $RuntimeSimulationStep

var _checks := 0
var _failures: Array[String] = []


func _ready() -> void:
	_check(simulation_step.mutation_authority != null, "runtime scene includes mutation authority")
	_check(simulation_step.determinism_audit != null and simulation_step.determinism_audit.is_ready(), "runtime scene binds deterministic audit identity")
	_check(simulation_step.get_child_count() == 4, "runtime scene has one authority child set")
	var opened := simulation_step.mutation_authority.begin_step(1)
	_check(bool(opened.get("opened", false)), "authority opens a real scene-owned simulation step")
	var before := simulation_step.identify_state({"entity": "bench", "hp": 10})
	var after := simulation_step.identify_state({"entity": "bench", "hp": 8})
	var mutation := simulation_step.mutation_authority.record_mutation(
		{"command_type": "bench_mutation", "command_id": "bench:1", "source": "bench"},
		{"entity": "bench", "hp": 10},
		{"entity": "bench", "hp": 8},
		{"domain": "bench", "mutation_kind": "damage", "target_key": "bench", "outcome": "applied"}
	)
	_check(bool(mutation.get("recorded", false)) and str(before.get("fingerprint", "")).length() == 64 and str(after.get("fingerprint", "")).length() == 64, "authority records before/after state fingerprints")
	simulation_step.mutation_authority.end_step()
	_check(simulation_step.determinism_audit.recent_mutations().size() == 1, "scene-owned audit exposes one mutation receipt")
	_check(not bool(simulation_step.mutation_authority.debug_snapshot().get("owns_world_state", true)), "mutation authority is a gate, not a second world owner")
	print("SimulationRuntimeAuthorityMigrationBench: %s %d/%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks - _failures.size(), _checks])
	if not _failures.is_empty():
		push_error("\n- ".join(_failures))
	await get_tree().create_timer(4.0).timeout
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
