extends Node
class_name RuntimeLifecyclePhaseCoordinator

var _lifecycle: RuntimeLifecyclePort


func bind_port(port: RuntimeLifecyclePort) -> void:
	_lifecycle = port


func is_ready() -> bool:
	return _lifecycle != null and _lifecycle.is_ready()


func begin_frame(context: RuntimePhaseFrameContext) -> StringName:
	context.enter_phase(&"lifecycle_begin")
	context.append_step(&"session_finished_gate")
	if _lifecycle.session_is_finished():
		context.path = &"finished"
		context.stopped_reason = &"session_finished"
		return &"stop"
	context.append_step(&"synchronize_forced_decisions")
	_lifecycle.synchronize_forced_decisions()
	context.append_step(&"global_time_block_gate")
	if _lifecycle.blocks_global_time():
		context.path = &"global_blocked"
		context.stopped_reason = &"global_time_blocked"
		return &"global_blocked"
	context.append_step(&"ordinary_session_pause_gate")
	if _lifecycle.session_is_paused():
		context.path = &"paused"
		context.stopped_reason = &"session_paused"
		return &"stop"
	context.world_delta = context.real_delta
	context.path = &"active"
	context.stopped_reason = &"completed"
	context.append_step(&"advance_world_clock_and_project_game_time")
	_lifecycle.advance_world_time(context.world_delta)
	return &"active"


func allow_after_flow(context: RuntimePhaseFrameContext) -> bool:
	context.enter_phase(&"lifecycle_post_flow")
	context.append_step(&"post_flow_session_finished_gate")
	if _lifecycle.session_is_finished():
		context.stopped_reason = &"session_finished_after_flow"
		return false
	return true


func allow_after_victory(context: RuntimePhaseFrameContext) -> bool:
	context.enter_phase(&"lifecycle_post_victory")
	context.append_step(&"post_victory_session_finished_gate")
	if _lifecycle.session_is_finished():
		context.stopped_reason = &"session_finished_after_victory"
		return false
	return true


func debug_snapshot() -> Dictionary:
	return {"ready": is_ready(), "operation_count": 3, "owns_world_state": false}
