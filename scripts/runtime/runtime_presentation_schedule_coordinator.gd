extends Node
class_name RuntimePresentationScheduleCoordinator

var _presentation: RuntimePresentationPort


func bind_port(port: RuntimePresentationPort) -> void:
	_presentation = port


func is_ready() -> bool:
	return _presentation != null and _presentation.is_ready()


func advance_blocked_realtime(context: RuntimePhaseFrameContext) -> void:
	context.enter_phase(&"presentation_blocked_realtime")
	context.append_step(&"blocked_visual_real_tick")
	_presentation.advance_visual_cues(context.real_delta)
	context.append_step(&"blocked_table_presentation_real_tick")
	_presentation.advance_table_presentation(context.real_delta)


func advance_frame_end(context: RuntimePhaseFrameContext) -> void:
	context.enter_phase(&"presentation_frame_end")
	context.append_step(&"frame_end_table_presentation_real_tick")
	_presentation.advance_table_presentation(context.real_delta)


func debug_snapshot() -> Dictionary:
	return {"ready": is_ready(), "operation_count": 2, "owns_world_state": false}
