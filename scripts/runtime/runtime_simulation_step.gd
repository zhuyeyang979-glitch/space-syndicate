@tool
extends Node
class_name RuntimeSimulationStep

@onready var state_identity: SimulationStateIdentity = $SimulationStateIdentity
@onready var randomness_boundary: SimulationRandomnessBoundary = $SimulationRandomnessBoundary
@onready var determinism_audit: SimulationDeterminismAudit = $SimulationDeterminismAudit
@onready var mutation_authority: SimulationMutationAuthority = $SimulationMutationAuthority

var _command: RuntimeCommandPhaseCoordinator
var _simulation: RuntimeSimulationPhaseCoordinator
var _resolution: RuntimeResolutionPhaseCoordinator
var _lifecycle: RuntimeLifecyclePhaseCoordinator
var _state_commit: RuntimeStateCommitCoordinator
var _step_index := 0
var _last_step_receipt: Dictionary = {}


func _ready() -> void:
	_bind_audit_identity()


func bind_phases(
	command_phase: RuntimeCommandPhaseCoordinator,
	simulation_phase: RuntimeSimulationPhaseCoordinator,
	resolution_phase: RuntimeResolutionPhaseCoordinator,
	lifecycle_phase: RuntimeLifecyclePhaseCoordinator,
	state_commit_phase: RuntimeStateCommitCoordinator
) -> void:
	_command = command_phase
	_simulation = simulation_phase
	_resolution = resolution_phase
	_lifecycle = lifecycle_phase
	_state_commit = state_commit_phase


func is_ready() -> bool:
	return state_identity != null and randomness_boundary != null \
		and _command != null and _command.is_ready() \
		and _simulation != null and _simulation.is_ready() \
		and _resolution != null and _resolution.is_ready() \
		and _lifecycle != null and _lifecycle.is_ready() \
		and _state_commit != null and _state_commit.is_ready()


func recover_postcommit_before_frame(context: RuntimePhaseFrameContext) -> Dictionary:
	if not is_ready() or context == null or not _resolution.has_pending_postcommit_recovery():
		return {"needed": false, "completed": true}
	_step_index += 1
	context.simulation_step_index = _step_index
	if mutation_authority != null:
		var opened := mutation_authority.begin_step(_step_index)
		if not bool(opened.get("opened", false)):
			context.path = &"postcommit_recovery"
			context.stopped_reason = StringName(str(opened.get("reason", "mutation_authority_unavailable")))
			_last_step_receipt = {
				"advanced": false,
				"completed": false,
				"recovery_only": true,
				"step_index": _step_index,
				"reason": str(opened.get("reason", "mutation_authority_unavailable")),
			}
			context.simulation_step_receipt = _last_step_receipt.duplicate(true)
			return {"needed": true, "completed": false, "reason": str(_last_step_receipt.get("reason", "mutation_authority_unavailable"))}
	var phase_start := context.phase_trace.size()
	var mutation_start := context.trace.size()
	var recovery := _resolution.recover_pending_postcommit_before_frame(context)
	if mutation_authority != null:
		mutation_authority.end_step()
	_last_step_receipt = {
		"advanced": true,
		"completed": bool(recovery.get("completed", false)),
		"recovery_only": true,
		"step_index": _step_index,
		"world_delta": 0.0,
		"stopped_reason": context.stopped_reason,
		"phase_trace": context.phase_trace.slice(phase_start),
		"mutation_trace": context.trace.slice(mutation_start),
	}
	context.simulation_step_receipt = _last_step_receipt.duplicate(true)
	var result := recovery.duplicate(true)
	result["needed"] = true
	return result


func advance_active(context: RuntimePhaseFrameContext) -> Dictionary:
	if not is_ready() or context == null or context.path != &"active":
		_last_step_receipt = {
			"advanced": false,
			"step_index": _step_index,
			"reason": "simulation_step_unavailable",
		}
		return _last_step_receipt.duplicate(true)
	_step_index += 1
	context.simulation_step_index = _step_index
	if mutation_authority != null:
		var opened := mutation_authority.begin_step(_step_index)
		if not bool(opened.get("opened", false)):
			_last_step_receipt = {"advanced": false, "step_index": _step_index, "reason": str(opened.get("reason", "mutation_authority_unavailable"))}
			return _last_step_receipt.duplicate(true)
	var phase_start := context.phase_trace.size()
	var mutation_start := context.trace.size()
	_command.advance_active(context)
	_simulation.advance_active(context)
	if not _resolution.advance_active(context):
		return _finish_step(context, phase_start, mutation_start, false)
	if not _lifecycle.allow_after_flow(context):
		return _finish_step(context, phase_start, mutation_start, false)
	_state_commit.advance_active(context)
	if not _lifecycle.allow_after_victory(context):
		return _finish_step(context, phase_start, mutation_start, false)
	return _finish_step(context, phase_start, mutation_start, true)


func identify_state(simulation_projection: Dictionary, command_trace: Array = []) -> Dictionary:
	if state_identity == null:
		return {"valid": false, "reason": "simulation_state_identity_unavailable", "fingerprint": ""}
	return state_identity.identify(simulation_projection, command_trace)


func record_deterministic_trace(
	state_before: Dictionary,
	state_after: Dictionary,
	command_sequence: Array,
	command_results: Array,
	mutation_summary: Array
) -> Dictionary:
	_bind_audit_identity()
	if determinism_audit == null:
		return {"recorded": false, "reason": "simulation_determinism_audit_unavailable"}
	var before_identity := state_identity.identify(state_before)
	var after_identity := state_identity.identify(state_after)
	if not bool(before_identity.get("valid", false)) or not bool(after_identity.get("valid", false)):
		return {"recorded": false, "reason": "simulation_trace_state_identity_invalid"}
	return determinism_audit.record_step(
		int(_last_step_receipt.get("step_index", _step_index)),
		command_sequence,
		command_results,
		_last_step_receipt.get("phase_trace", []),
		str(before_identity.get("fingerprint", "")),
		str(after_identity.get("fingerprint", "")),
		mutation_summary,
		bool(_last_step_receipt.get("completed", false)),
		str(_last_step_receipt.get("stopped_reason", ""))
	)


func current_simulation_identity() -> Dictionary:
	return determinism_audit.current_simulation_identity() if determinism_audit != null else {}


func current_step_index() -> int:
	return _step_index


func recent_deterministic_trace() -> Dictionary:
	return determinism_audit.recent_deterministic_trace() if determinism_audit != null else {}


func deterministic_violations() -> Array:
	return determinism_audit.deterministic_violations() if determinism_audit != null else []


func simulation_mutation_authority() -> SimulationMutationAuthority:
	return mutation_authority


func record_deterministic_violation(code: String, details: Dictionary = {}) -> Dictionary:
	_bind_audit_identity()
	return determinism_audit.record_violation(code, details) if determinism_audit != null else {"code": code}


func last_step_receipt() -> Dictionary:
	return _last_step_receipt.duplicate(true)


func debug_snapshot() -> Dictionary:
	return {
		"ready": is_ready(),
		"simulation_step_entry_points": 1,
		"step_index": _step_index,
		"owns_engine_frame": false,
		"owns_world_state": false,
		"owns_gameplay_rules": false,
		"fixed_step_enabled": false,
		"current_production_steps_per_active_frame": 1,
		"identity": state_identity.debug_snapshot() if state_identity != null else {},
		"randomness_boundary": randomness_boundary.debug_snapshot() if randomness_boundary != null else {},
		"determinism_audit": determinism_audit.debug_snapshot() if determinism_audit != null else {},
		"mutation_authority": mutation_authority.debug_snapshot() if mutation_authority != null else {},
		"last_step_receipt": _last_step_receipt.duplicate(true),
	}


func _finish_step(
	context: RuntimePhaseFrameContext,
	phase_start: int,
	mutation_start: int,
	completed: bool
) -> Dictionary:
	if mutation_authority != null:
		mutation_authority.end_step()
	_last_step_receipt = {
		"advanced": true,
		"completed": completed,
		"step_index": _step_index,
		"world_delta": context.world_delta,
		"stopped_reason": context.stopped_reason,
		"phase_trace": context.phase_trace.slice(phase_start),
		"mutation_trace": context.trace.slice(mutation_start),
	}
	context.simulation_step_receipt = _last_step_receipt.duplicate(true)
	return _last_step_receipt.duplicate(true)


func _bind_audit_identity() -> void:
	if determinism_audit != null and state_identity != null:
		determinism_audit.bind_identity(state_identity)
	if mutation_authority != null:
		mutation_authority.bind_diagnostics(state_identity, determinism_audit)
