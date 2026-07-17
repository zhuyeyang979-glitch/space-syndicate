extends Node

@onready var simulation_step: RuntimeSimulationStep = $RuntimeSimulationStep

var _checks := 0
var _failures: Array[String] = []


func _ready() -> void:
	var before := simulation_step.identify_state({"actors": [{"id": "bench", "value": 1}], "step": 0})
	var after := simulation_step.identify_state({"actors": [{"id": "bench", "value": 2}], "step": 1})
	_check(bool(before.get("valid", false)) and bool(after.get("valid", false)), "production identity owner fingerprints pure state")
	var record := simulation_step.determinism_audit.record_step(
		1,
		[{
			"schema_version": 1,
			"command_type": "bench_command",
			"command_id": "bench:1",
			"order_index": 0,
			"payload_fingerprint": str(before.get("fingerprint", "")),
			"envelope_fingerprint": str(before.get("fingerprint", "")),
		}],
		[{
			"command_id": "bench:1",
			"accepted": true,
			"reason": "",
			"result_fingerprint": str(after.get("fingerprint", "")),
		}],
		[&"command", &"simulation", &"state_commit"],
		str(before.get("fingerprint", "")),
		str(after.get("fingerprint", "")),
		[{
			"domain": "bench",
			"mutation_kind": "increment",
			"target_key": "bench",
			"outcome": "committed",
			"summary_fingerprint": str(after.get("fingerprint", "")),
		}],
		true
	)
	_check(bool(record.get("recorded", false)), "development audit accepts one valid deterministic trace")
	var trace := simulation_step.recent_deterministic_trace()
	_check(int(trace.get("simulation_step_index", 0)) == 1 and str(trace.get("trace_fingerprint", "")).length() == 64, "recent trace exposes stable step and trace fingerprints")
	_check(bool(SimulationTraceContract.validate(trace).get("valid", false)), "stored trace still satisfies the pure-data trace contract")
	var audit_identity := simulation_step.current_simulation_identity()
	_check(str(audit_identity.get("fingerprint", "")) == str(after.get("fingerprint", "")), "audit identity follows the recorded authoritative after-state")
	simulation_step.record_deterministic_violation("bench_probe", {"private_detail": "fingerprinted_not_retained"})
	var violations := simulation_step.deterministic_violations()
	_check(violations.size() == 1 and not (violations[0] as Dictionary).has("private_detail"), "violation output retains code and fingerprint, not raw diagnostic details")
	var debug := simulation_step.determinism_audit.debug_snapshot()
	_check(not bool(debug.get("owns_world_state", true)) and not bool(debug.get("save_owner", true)), "audit remains a passive development consumer")
	_check(not simulation_step.determinism_audit.has_method("_process") and not simulation_step.determinism_audit.has_method("_physics_process"), "audit cannot become a second simulation clock")
	print("SimulationDeterminismConsumptionLayerBench: %s %d/%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks - _failures.size(), _checks])
	if not _failures.is_empty():
		push_error("\n- ".join(_failures))
	await get_tree().create_timer(8.0).timeout
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
