extends Node
class_name RuntimeStateCommitCoordinator

var _economy: RuntimeEconomyPort
var _victory: RuntimeVictoryPort


func bind_ports(economy: RuntimeEconomyPort, victory: RuntimeVictoryPort) -> void:
	_economy = economy
	_victory = victory


func is_ready() -> bool:
	return _economy != null and _economy.is_ready() and _victory != null and _victory.is_ready()


func advance_active(context: RuntimePhaseFrameContext) -> void:
	context.enter_phase(&"state_commit")
	context.append_step(&"tick_product_market_cycle")
	_economy.tick_product_market_cycle(context.world_delta)
	context.append_step(&"advance_victory_control")
	_victory.advance_victory_control(context.world_delta)


func debug_snapshot() -> Dictionary:
	return {"ready": is_ready(), "operation_count": 1, "owns_world_state": false}
