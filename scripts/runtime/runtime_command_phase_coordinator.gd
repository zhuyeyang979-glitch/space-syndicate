extends Node
class_name RuntimeCommandPhaseCoordinator

var _lifecycle: RuntimeLifecyclePort
var _card: RuntimeCardPort


func bind_ports(lifecycle: RuntimeLifecyclePort, card: RuntimeCardPort) -> void:
	_lifecycle = lifecycle
	_card = card


func is_ready() -> bool:
	return _lifecycle != null and _lifecycle.is_ready() and _card != null and _card.is_ready()


func advance_active(context: RuntimePhaseFrameContext) -> void:
	context.enter_phase(&"command")
	context.append_step(&"card_resolution_gate")
	if _lifecycle.allows_card_resolution_progress():
		context.append_step(&"advance_card_resolution_frame")
		_card.advance_card_resolution_frame(context.world_delta)
	context.append_step(&"tick_contract_runtime")
	_card.tick_contract_runtime(context.world_delta)
	context.append_step(&"advance_card_cooldowns")
	_card.advance_card_cooldowns(context.world_delta)


func debug_snapshot() -> Dictionary:
	return {"ready": is_ready(), "operation_count": 1, "owns_world_state": false}
