extends Node
class_name RuntimeActorPort

var _weather: WeatherRuntimeController
var _ai: AiRuntimeController
var _military: MilitaryRuntimeController
var _victory: VictoryControlRuntimeController


func bind_dependencies(
	weather: WeatherRuntimeController,
	ai: AiRuntimeController,
	military: MilitaryRuntimeController,
	victory: VictoryControlRuntimeController
) -> void:
	_weather = weather
	_ai = ai
	_military = military
	_victory = victory


func is_ready() -> bool:
	return is_instance_valid(_weather) and is_instance_valid(_ai) \
		and is_instance_valid(_military) and is_instance_valid(_victory)


func tick_weather(delta_seconds: float) -> void:
	if _weather == null:
		return
	var victory_state := str(_victory.public_snapshot().get("state", "idle")) if _victory != null else "idle"
	_weather.set_new_forecasts_allowed(victory_state == "idle")
	_weather.tick(delta_seconds)


func tick_ai(delta_seconds: float) -> void:
	if _ai != null:
		_ai.tick(delta_seconds)


func tick_military(delta_seconds: float) -> void:
	if _military != null:
		_military.tick(delta_seconds)


func debug_snapshot() -> Dictionary:
	var ai_debug := _ai.debug_snapshot() if _ai != null else {}
	return {
		"port_kind": "actors",
		"ready": is_ready(),
		"operation_count": 3,
		"owns_actor_state": false,
		"ai_tick_timing": {
			"count": (ai_debug.get("tick_timing_count", {}) as Dictionary).duplicate(true) \
				if ai_debug.get("tick_timing_count", {}) is Dictionary else {},
			"total_usec": (ai_debug.get("tick_timing_total_usec", {}) as Dictionary).duplicate(true) \
				if ai_debug.get("tick_timing_total_usec", {}) is Dictionary else {},
			"max_usec": (ai_debug.get("tick_timing_max_usec", {}) as Dictionary).duplicate(true) \
				if ai_debug.get("tick_timing_max_usec", {}) is Dictionary else {},
		},
	}
