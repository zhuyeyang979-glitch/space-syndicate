extends Node
class_name RuntimeLifecyclePort

var _composition_ready := false
var _session: GameSessionRuntimeController
var _scheduler: ForcedDecisionRuntimeScheduler
var _candidate_sources: ForcedDecisionCandidateSources
var _clock: WorldEffectiveClockRuntimeController
var _world_state: WorldSessionState


func bind_dependencies(
	session: GameSessionRuntimeController,
	scheduler: ForcedDecisionRuntimeScheduler,
	candidate_sources: ForcedDecisionCandidateSources,
	clock: WorldEffectiveClockRuntimeController,
	world_state: WorldSessionState
) -> void:
	_session = session
	_scheduler = scheduler
	_candidate_sources = candidate_sources
	_clock = clock
	_world_state = world_state


func set_composition_ready(value: bool) -> void:
	_composition_ready = value


func is_ready() -> bool:
	return _composition_ready and is_instance_valid(_session) and is_instance_valid(_scheduler) \
		and is_instance_valid(_candidate_sources) and is_instance_valid(_clock) and is_instance_valid(_world_state)


func session_is_finished() -> bool:
	return _session == null or _session.is_finished()


func session_is_paused() -> bool:
	return _session == null or _session.session_state() == "paused"


func synchronize_forced_decisions() -> Dictionary:
	return _candidate_sources.synchronize() if _candidate_sources != null else {
		"synchronized": false,
		"reason": "forced_decision_sources_unavailable",
	}


func blocks_global_time() -> bool:
	return _scheduler != null and _scheduler.blocks_global_time()


func allows_card_resolution_progress() -> bool:
	return _scheduler == null or not _scheduler.blocks_card_resolution()


func advance_world_time(delta_seconds: float) -> Dictionary:
	if _clock == null or _world_state == null:
		return {"advanced": false, "reason": "world_clock_boundary_unavailable"}
	var snapshot := _clock.advance(delta_seconds)
	_world_state.set_game_time(float(snapshot.get("world_effective_seconds", _world_state.game_time)))
	return snapshot.duplicate(true)


func debug_snapshot() -> Dictionary:
	return {
		"port_kind": "lifecycle",
		"ready": is_ready(),
		"operation_count": 7,
		"owns_world_state": false,
	}
