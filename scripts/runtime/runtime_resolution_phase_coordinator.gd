extends Node
class_name RuntimeResolutionPhaseCoordinator

var _economy: RuntimeEconomyPort


func bind_port(port: RuntimeEconomyPort) -> void:
	_economy = port


func is_ready() -> bool:
	return _economy != null and _economy.is_ready()


func advance_active(context: RuntimePhaseFrameContext) -> bool:
	context.enter_phase(&"resolution")
	context.append_step(&"advance_commodity_flow")
	if not _economy.advance_runtime_commodity_flow(context.world_delta):
		context.stopped_reason = &"commodity_flow_not_finalized"
		return false
	return true


func debug_snapshot() -> Dictionary:
	return {"ready": is_ready(), "operation_count": 1, "owns_world_state": false}
