extends Node
class_name RuntimeSimulationPhaseCoordinator

var _economy: RuntimeEconomyPort
var _actors: RuntimeActorPort
var _monster: RuntimeMonsterPort
var _presentation: RuntimePresentationPort
var _timing_count: Dictionary = {}
var _timing_total_usec: Dictionary = {}
var _timing_max_usec: Dictionary = {}


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
	var started_usec := Time.get_ticks_usec()
	_monster.tick_wager_decisions_realtime(context.real_delta)
	_record_timing(&"blocked_wager_real_tick", started_usec)


func advance_active(context: RuntimePhaseFrameContext) -> void:
	context.enter_phase(&"simulation")
	context.append_step(&"advance_city_gdp_derivative_timers")
	var started_usec := Time.get_ticks_usec()
	_economy.advance_city_gdp_derivative_timers()
	_record_timing(&"advance_city_gdp_derivative_timers", started_usec)
	context.append_step(&"advance_product_futures_timers")
	started_usec = Time.get_ticks_usec()
	_economy.advance_product_futures_timers()
	_record_timing(&"advance_product_futures_timers", started_usec)
	context.append_step(&"tick_weather")
	started_usec = Time.get_ticks_usec()
	_actors.tick_weather(context.world_delta)
	_record_timing(&"tick_weather", started_usec)
	context.append_step(&"advance_economic_boons")
	started_usec = Time.get_ticks_usec()
	_economy.advance_economic_boons(context.world_delta)
	_record_timing(&"advance_economic_boons", started_usec)
	context.append_step(&"tick_monster_wagers")
	started_usec = Time.get_ticks_usec()
	_monster.tick_battle_lifecycles(context.world_delta)
	_record_timing(&"tick_monster_wagers", started_usec)
	context.append_step(&"tick_ai")
	started_usec = Time.get_ticks_usec()
	_actors.tick_ai(context.world_delta)
	_record_timing(&"tick_ai", started_usec)
	context.append_step(&"tick_monster_motion")
	started_usec = Time.get_ticks_usec()
	_monster.tick_motion(context.world_delta)
	_record_timing(&"tick_monster_motion", started_usec)
	context.append_step(&"tick_military")
	started_usec = Time.get_ticks_usec()
	_actors.tick_military(context.world_delta)
	_record_timing(&"tick_military", started_usec)
	context.append_step(&"tick_monster_actions")
	started_usec = Time.get_ticks_usec()
	_monster.tick_actions(context.world_delta)
	_record_timing(&"tick_monster_actions", started_usec)
	context.append_step(&"tick_monster_durations")
	started_usec = Time.get_ticks_usec()
	_monster.tick_durations(context.world_delta)
	_record_timing(&"tick_monster_durations", started_usec)
	context.append_step(&"advance_visual_cues")
	started_usec = Time.get_ticks_usec()
	_presentation.advance_visual_cues(context.world_delta)
	_record_timing(&"advance_visual_cues", started_usec)
	context.append_step(&"tick_monster_revivals")
	started_usec = Time.get_ticks_usec()
	_monster.tick_revivals(context.world_delta)
	_record_timing(&"tick_monster_revivals", started_usec)


func debug_snapshot() -> Dictionary:
	return {
		"ready": is_ready(),
		"operation_count": 2,
		"owns_world_state": false,
		"timing_count": _timing_count.duplicate(true),
		"timing_total_usec": _timing_total_usec.duplicate(true),
		"timing_max_usec": _timing_max_usec.duplicate(true),
		"actor": _actors.debug_snapshot() if _actors != null else {},
	}


func _record_timing(operation_id: StringName, started_usec: int) -> void:
	var key := str(operation_id)
	var elapsed_usec := maxi(0, Time.get_ticks_usec() - started_usec)
	_timing_count[key] = int(_timing_count.get(key, 0)) + 1
	_timing_total_usec[key] = int(_timing_total_usec.get(key, 0)) + elapsed_usec
	_timing_max_usec[key] = maxi(int(_timing_max_usec.get(key, 0)), elapsed_usec)
