extends RefCounted
class_name WeatherEffectResolver

const ROUTE_FLOOR := 0.40
const MONSTER_SPEED_CAP := 1.30
const MILITARY_FLOOR := 0.70
const INTEL_FLOOR := 0.70


func identity_effect() -> Dictionary:
	return {
		"available": true,
		"phase_active": false,
		"intensity": 0.0,
		"economy": {"multiplier": 1.0},
		"route": {"speed_multiplier": 1.0, "floor": ROUTE_FLOOR},
		"monster": {"speed_multiplier": 1.0, "cap": MONSTER_SPEED_CAP},
		"military": {"effect_multiplier": 1.0, "floor": MILITARY_FLOOR},
		"intel": {"effect_multiplier": 1.0, "floor": INTEL_FLOOR},
		"damage": {"per_second": 0.0, "nonlethal": true, "capped": true},
		"explanation": [],
	}


func resolve(definition: WeatherDefinition, phase: String, intensity: float, context: Dictionary = {}) -> Dictionary:
	if definition == null or phase == WeatherRuntimeState.PHASE_ENDED or intensity <= 0.0:
		return identity_effect()
	var safe_intensity := clampf(intensity, 0.0, 1.0)
	var resistance := clampf(float(context.get("weather_resistance", 0.0)), 0.0, 1.0)
	var exploitation := maxf(1.0, float(context.get("weather_exploitation_multiplier", 1.0)))
	var economy := _resolved_multiplier(definition.economy_multiplier, safe_intensity, resistance, exploitation, 0.0, INF)
	var route := maxf(ROUTE_FLOOR, _resolved_multiplier(definition.route_multiplier, safe_intensity, resistance, exploitation, ROUTE_FLOOR, INF))
	var monster_speed := minf(MONSTER_SPEED_CAP, _resolved_multiplier(definition.monster_speed_multiplier, safe_intensity, resistance, exploitation, 0.0, MONSTER_SPEED_CAP))
	var military := maxf(MILITARY_FLOOR, _resolved_multiplier(definition.military_multiplier, safe_intensity, resistance, exploitation, MILITARY_FLOOR, INF))
	var intel := maxf(INTEL_FLOOR, _resolved_multiplier(definition.intel_multiplier, safe_intensity, resistance, exploitation, INTEL_FLOOR, INF))
	return {
		"available": true,
		"definition_id": definition.id,
		"phase": phase,
		"phase_active": phase == WeatherRuntimeState.PHASE_ACTIVE or phase == WeatherRuntimeState.PHASE_FADING,
		"intensity": safe_intensity,
		"weather_resistance": resistance,
		"weather_exploitation_multiplier": exploitation,
		"economy": {
			"multiplier": economy,
			"city_maintenance_multiplier": _resolved_multiplier(definition.city_maintenance_multiplier, safe_intensity, resistance, exploitation, 0.0, INF),
		},
		"route": {
			"speed_multiplier": route,
			"floor": ROUTE_FLOOR,
		},
		"monster": {
			"speed_multiplier": monster_speed,
			"cap": MONSTER_SPEED_CAP,
		},
		"military": {
			"effect_multiplier": military,
			"floor": MILITARY_FLOOR,
		},
		"intel": {
			"effect_multiplier": intel,
			"floor": INTEL_FLOOR,
		},
		"damage": {
			"per_second": maxf(0.0, definition.damage_per_second * safe_intensity),
			"nonlethal": definition.damage_nonlethal,
			"capped": definition.damage_capped,
			"policy": "nonlethal_capped" if definition.damage_per_second > 0.0 else "none",
		},
		"explanation": _explanation(definition, economy, route, monster_speed, military, intel),
	}


func _resolved_multiplier(base: float, intensity: float, resistance: float, exploitation: float, floor_value: float, cap_value: float) -> float:
	var delta := base - 1.0
	if delta >= 0.0:
		delta *= intensity * exploitation
	else:
		delta *= intensity * (1.0 - resistance)
	var value := 1.0 + delta
	if is_finite(floor_value):
		value = maxf(floor_value, value)
	if is_finite(cap_value):
		value = minf(cap_value, value)
	return value


func _explanation(definition: WeatherDefinition, economy: float, route: float, monster: float, military: float, intel: float) -> Array:
	var result: Array = []
	for code in definition.explanation_codes:
		result.append(str(code))
	if economy > 1.0:
		result.append("economy_boost")
	if route < 1.0:
		result.append("route_slowdown")
	elif route > 1.0:
		result.append("route_boost")
	if monster > 1.0:
		result.append("monster_speedup")
	if military < 1.0:
		result.append("military_disruption")
	if intel < 1.0:
		result.append("intel_noise")
	return result
