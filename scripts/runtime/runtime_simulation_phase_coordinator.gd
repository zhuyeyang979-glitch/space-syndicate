extends Node
class_name RuntimeSimulationPhaseCoordinator

var _economy: RuntimeEconomyPort
var _actors: RuntimeActorPort
var _monster: RuntimeMonsterPort
var _presentation: RuntimePresentationPort


func bind_ports(
	economy: RuntimeEconomyPort,
	actors: RuntimeActorPort,
	monster: RuntimeMonsterPort,
	presentation: RuntimePresentationPort
) -> void:
	_economy = economy
	_actors = actors
	_monster = monster
	_presentation = presentation


func is_ready() -> bool:
	return _economy != null and _economy.is_ready() and _actors != null and _actors.is_ready() \
		and _monster != null and _monster.is_ready() and _presentation != null and _presentation.is_ready()


func advance_blocked_realtime(context: RuntimePhaseFrameContext) -> void:
	context.enter_phase(&"simulation_blocked_realtime")
	context.append_step(&"blocked_wager_real_tick")
	_monster.tick_wagers(context.real_delta)


func advance_active(context: RuntimePhaseFrameContext) -> void:
	context.enter_phase(&"simulation")
	context.append_step(&"advance_city_gdp_derivative_timers")
	_economy.advance_city_gdp_derivative_timers()
	context.append_step(&"advance_product_futures_timers")
	_economy.advance_product_futures_timers()
	context.append_step(&"tick_weather")
	_actors.tick_weather(context.world_delta)
	context.append_step(&"advance_economic_boons")
	_economy.advance_economic_boons(context.world_delta)
	context.append_step(&"tick_monster_wagers")
	_monster.tick_wagers(context.world_delta)
	context.append_step(&"tick_ai")
	_actors.tick_ai(context.world_delta)
	context.append_step(&"tick_monster_motion")
	_monster.tick_motion(context.world_delta)
	context.append_step(&"tick_military")
	_actors.tick_military(context.world_delta)
	context.append_step(&"tick_monster_actions")
	_monster.tick_actions(context.world_delta)
	context.append_step(&"tick_monster_durations")
	_monster.tick_durations(context.world_delta)
	context.append_step(&"advance_visual_cues")
	_presentation.advance_visual_cues(context.world_delta)
	context.append_step(&"tick_monster_revivals")
	_monster.tick_revivals(context.world_delta)


func debug_snapshot() -> Dictionary:
	return {"ready": is_ready(), "operation_count": 2, "owns_world_state": false}
