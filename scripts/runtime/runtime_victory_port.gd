extends Node
class_name RuntimeVictoryPort

var _victory: VictoryControlRuntimeController
var _world_query: VictoryControlWorldBridge
var _session: GameSessionRuntimeController
var _ai: AiRuntimeController
var _presentation_queries: TablePresentationQueryPorts


func bind_dependencies(
	victory: VictoryControlRuntimeController,
	world_query: VictoryControlWorldBridge,
	session: GameSessionRuntimeController,
	ai: AiRuntimeController,
	presentation_queries: TablePresentationQueryPorts
) -> void:
	_victory = victory
	_world_query = world_query
	_session = session
	_ai = ai
	_presentation_queries = presentation_queries


func is_ready() -> bool:
	return is_instance_valid(_victory) and is_instance_valid(_world_query) \
		and is_instance_valid(_session) and is_instance_valid(_presentation_queries)


func advance_victory_control(delta_seconds: float, clock_pause: Dictionary = {}) -> Dictionary:
	if _victory == null or _world_query == null:
		return {"valid": false, "reason": "victory_boundary_unavailable"}
	var world_snapshot := _world_query.capture_world_snapshot(clock_pause, "post_world_settlement")
	var result := _victory.advance_world_effective(delta_seconds, world_snapshot).duplicate(true)
	if _presentation_queries != null:
		_presentation_queries.capture_victory_advance(result)
	var outcome: Dictionary = result.get("outcome_receipt", {}) if result.get("outcome_receipt", {}) is Dictionary else {}
	if not outcome.is_empty() and _session != null and not _session.is_finished():
		_session.finish_session(outcome)
		if _session.is_finished():
			if _ai != null:
				_ai.finalize_victory_outcome_learning(outcome)
			if _presentation_queries != null:
				_presentation_queries.capture_victory_outcome(_victory.public_snapshot(-1))
	return result


func debug_snapshot() -> Dictionary:
	return {"port_kind": "victory", "ready": is_ready(), "operation_count": 1, "owns_victory_state": false}
