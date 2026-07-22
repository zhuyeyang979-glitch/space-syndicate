extends Node
class_name RuntimeResolutionPhaseCoordinator

var _economy: RuntimeEconomyPort


func bind_port(port: RuntimeEconomyPort) -> void:
	_economy = port


func is_ready() -> bool:
	return _economy != null and _economy.is_ready()


func has_pending_postcommit_recovery() -> bool:
	return _economy != null and _economy.has_pending_postcommit_recovery()


func recover_pending_postcommit_before_frame(context: RuntimePhaseFrameContext) -> Dictionary:
	context.enter_phase(&"postcommit_recovery_fence")
	context.append_step(&"recover_pending_commodity_postcommit")
	var recovery := _economy.recover_pending_postcommit() if _economy != null else {
		"needed": true,
		"completed": false,
		"reason": "runtime_economy_port_missing",
	}
	context.path = &"postcommit_recovery"
	context.stopped_reason = &"postcommit_recovered" if bool(recovery.get("completed", false)) \
		else StringName(str(recovery.get("reason", "postcommit_recovery_failed")))
	return recovery


func advance_active(context: RuntimePhaseFrameContext) -> bool:
	context.enter_phase(&"resolution")
	context.append_step(&"advance_commodity_flow")
	if not _economy.advance_runtime_commodity_flow(context.world_delta):
		context.stopped_reason = &"commodity_flow_not_finalized"
		return false
	return true


func debug_snapshot() -> Dictionary:
	return {"ready": is_ready(), "operation_count": 3, "owns_world_state": false}
