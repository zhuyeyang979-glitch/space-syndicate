extends RefCounted
class_name WeatherEffectResolver

const ROUTE_FLOOR := 0.40
const MONSTER_SPEED_CAP := 1.30
const MILITARY_FLOOR := 0.70
const INTEL_FLOOR := 0.70


func identity_effect() -> Dictionary:
	var explanation: Array = []
	return {
		"available": true,
		"phase_active": false,
		"intensity": 0.0,
		"economy": {
			"price_growth_multiplier": 1.0,
			"production_multiplier": 1.0,
			"demand_multiplier": 1.0,
			"maintenance_multiplier": 1.0,
			"city_maintenance_multiplier": 1.0,
			"multiplier": 1.0,
		},
		"route": {
			"generic_multiplier": 1.0,
			"land_multiplier": 1.0,
			"ocean_multiplier": 1.0,
			"air_multiplier": 1.0,
			"speed_multiplier": 1.0,
			"floor": ROUTE_FLOOR,
		},
		"monster": {
			"preference_multiplier": 1.0,
			"target_score_multiplier": 1.0,
			"speed_multiplier": 1.0,
			"armor_multiplier": 1.0,
			"matched_tags": [],
			"cap": MONSTER_SPEED_CAP,
		},
		"military": {
			"land_multiplier": 1.0,
			"ocean_multiplier": 1.0,
			"air_multiplier": 1.0,
			"ranged_multiplier": 1.0,
			"orbital_multiplier": 1.0,
			"knockback_multiplier": 1.0,
			"flying_risk_multiplier": 1.0,
			"effect_multiplier": 1.0,
			"floor": MILITARY_FLOOR,
		},
		"intel": {
			"duration_multiplier": 1.0,
			"range_multiplier": 1.0,
			"duration_or_range": {"domain": "duration", "multiplier": 1.0},
			"effect_multiplier": 1.0,
			"floor": INTEL_FLOOR,
		},
		"damage": {"per_second": 0.0, "nonlethal": true, "capped": true, "policy": "none"},
		"explanations": explanation,
		"explanation": explanation,
	}


func resolve(definition: WeatherDefinition, phase: String, intensity: float, context: Dictionary = {}) -> Dictionary:
	if definition == null or phase == WeatherRuntimeState.PHASE_ENDED or intensity <= 0.0:
		return identity_effect()
	var safe_intensity := clampf(intensity, 0.0, 1.0)
	var resistance := clampf(float(context.get("weather_resistance", 0.0)), 0.0, 1.0)
	var exploitation := maxf(1.0, float(context.get("weather_exploitation_multiplier", 1.0)))
	var product_tags := _string_array(context.get("product_tags", []))
	var monster_tags := _string_array(context.get("monster_tags", context.get("unit_tags", [])))
	var unit_tags := _string_array(context.get("unit_tags", []))
	var context_tags := _string_array(context.get("context_tags", []))
	var route_mode := _domain(context.get("route_mode", context.get("movement_domain", "")))
	var movement_domain := _domain(context.get("movement_domain", route_mode))
	var intel_domain := _domain(context.get("intel_domain", definition.intel_effect_domain))
	var explanation: Array = _definition_explanations(definition)

	var economy: Dictionary = _economy_effect(definition, product_tags, context_tags, safe_intensity, resistance, exploitation, explanation)
	var route: Dictionary = _route_effect(definition, route_mode, movement_domain, unit_tags, safe_intensity, resistance, exploitation, explanation)
	var monster: Dictionary = _monster_effect(definition, monster_tags, safe_intensity, resistance, exploitation, explanation)
	var military: Dictionary = _military_effect(definition, movement_domain, unit_tags, safe_intensity, resistance, exploitation, explanation)
	var intel: Dictionary = _intel_effect(definition, intel_domain, context, safe_intensity, resistance, explanation)
	var damage: Dictionary = _damage_effect(definition, safe_intensity, resistance, explanation)

	return {
		"available": true,
		"definition_id": definition.id,
		"phase": phase,
		"phase_active": phase == WeatherRuntimeState.PHASE_ACTIVE or phase == WeatherRuntimeState.PHASE_FADING,
		"intensity": safe_intensity,
		"weather_resistance": resistance,
		"weather_exploitation_multiplier": exploitation,
		"economy": economy,
		"route": route,
		"monster": monster,
		"military": military,
		"intel": intel,
		"damage": damage,
		"explanations": explanation,
		"explanation": explanation,
	}


func _economy_effect(definition: WeatherDefinition, product_tags: Array, context_tags: Array, intensity: float, resistance: float, exploitation: float, explanation: Array) -> Dictionary:
	var matches_product := _intersects(product_tags, Array(definition.product_tags))
	var price_base := definition.product_price_growth_multiplier if matches_product else 1.0
	var production_base := definition.production_multiplier if matches_product else 1.0
	var demand_base := definition.demand_multiplier if matches_product else 1.0
	var matched_effect := _matching_product_effect(definition, product_tags)
	if not matched_effect.is_empty():
		price_base = float(matched_effect.get("product_price_growth_multiplier", matched_effect.get("price_growth_multiplier", price_base)))
		production_base = float(matched_effect.get("production_multiplier", production_base))
		demand_base = float(matched_effect.get("demand_multiplier", demand_base))
	var price_growth := _resolved_multiplier(price_base, intensity, resistance, exploitation, 0.0, INF)
	var production := _resolved_multiplier(production_base, intensity, resistance, exploitation, 0.0, INF)
	var demand := _resolved_multiplier(demand_base, intensity, resistance, exploitation, 0.0, INF)
	var maintenance_base := definition.city_maintenance_multiplier if _has_tag(context_tags, "maintenance") or _has_tag(context_tags, "city") else 1.0
	var maintenance := _resolved_multiplier(maintenance_base, intensity, resistance, 1.0, 0.0, INF)
	if price_growth > 1.0:
		explanation.append("price_growth")
	if production > 1.0:
		explanation.append("production_boost")
	elif production < 1.0:
		explanation.append("production_penalty")
	if demand > 1.0:
		explanation.append("demand_growth")
	if maintenance > 1.0:
		explanation.append("maintenance_pressure")
	var legacy_multiplier := maxf(price_growth, maxf(production, demand))
	return {
		"price_growth_multiplier": price_growth,
		"production_multiplier": production,
		"demand_multiplier": demand,
		"maintenance_multiplier": maintenance,
		"city_maintenance_multiplier": maintenance,
		"multiplier": legacy_multiplier,
	}


func _route_effect(definition: WeatherDefinition, route_mode: String, movement_domain: String, unit_tags: Array, intensity: float, resistance: float, exploitation: float, explanation: Array) -> Dictionary:
	var has_route_context := not route_mode.is_empty() or not movement_domain.is_empty()
	var generic_base := definition.route_efficiency_multiplier if has_route_context else 1.0
	var land_base := 1.0
	var ocean_base := 1.0
	var air_base := 1.0
	if _domain_matches("land", route_mode, movement_domain) and _land_context_matches(definition, unit_tags):
		land_base = definition.land_movement_multiplier
	if _domain_matches("ocean", route_mode, movement_domain):
		ocean_base = definition.ocean_movement_multiplier
	if _domain_matches("air", route_mode, movement_domain):
		air_base = definition.air_movement_multiplier
	var generic := _resolved_multiplier(generic_base, intensity, resistance, exploitation, ROUTE_FLOOR, INF)
	var land := _resolved_multiplier(land_base, intensity, resistance, exploitation, ROUTE_FLOOR, INF)
	var ocean := _resolved_multiplier(ocean_base, intensity, resistance, exploitation, ROUTE_FLOOR, INF)
	var air := _resolved_multiplier(air_base, intensity, resistance, exploitation, ROUTE_FLOOR, INF)
	if generic < 1.0 or land < 1.0 or ocean < 1.0:
		explanation.append("route_slowdown")
	if generic > 1.0 or air > 1.0:
		explanation.append("route_boost")
	return {
		"generic_multiplier": generic,
		"land_multiplier": land,
		"ocean_multiplier": ocean,
		"air_multiplier": air,
		"speed_multiplier": generic,
		"floor": ROUTE_FLOOR,
	}


func _monster_effect(definition: WeatherDefinition, monster_tags: Array, intensity: float, resistance: float, exploitation: float, explanation: Array) -> Dictionary:
	var matched_tags := _intersection(monster_tags, Array(definition.monster_preference_tags))
	var matches_monster := not matched_tags.is_empty()
	var preference := _resolved_multiplier(definition.monster_preference_multiplier if matches_monster else 1.0, intensity, resistance, exploitation, 0.0, INF)
	var speed := _resolved_multiplier(definition.monster_speed_multiplier if matches_monster else 1.0, intensity, resistance, exploitation, 0.0, MONSTER_SPEED_CAP)
	var armor := _resolved_multiplier(definition.monster_armor_multiplier if matches_monster else 1.0, intensity, resistance, exploitation, 0.0, INF)
	if preference > 1.0:
		explanation.append("monster_preference")
	if speed > 1.0:
		explanation.append("monster_speed")
	if armor > 1.0:
		explanation.append("monster_armor")
	return {
		"preference_multiplier": preference,
		"target_score_multiplier": preference,
		"speed_multiplier": speed,
		"armor_multiplier": armor,
		"matched_tags": matched_tags,
		"cap": MONSTER_SPEED_CAP,
	}


func _military_effect(definition: WeatherDefinition, movement_domain: String, unit_tags: Array, intensity: float, resistance: float, exploitation: float, explanation: Array) -> Dictionary:
	var land_base := definition.land_movement_multiplier if _domain_matches("land", "", movement_domain) and _land_context_matches(definition, unit_tags) else 1.0
	var ocean_base := definition.ocean_movement_multiplier if _domain_matches("ocean", "", movement_domain) else 1.0
	var air_base := definition.air_movement_multiplier if _domain_matches("air", "", movement_domain) else 1.0
	var ranged_base := definition.ranged_effect_multiplier if _has_tag(unit_tags, "ranged") else 1.0
	var orbital_base := definition.orbital_effect_multiplier if _has_tag(unit_tags, "orbital") else 1.0
	var knockback_base := definition.knockback_multiplier if _has_tag(unit_tags, "knockback") else 1.0
	var flying_base := definition.flying_risk_multiplier if _has_tag(unit_tags, "flying") or movement_domain == "air" else 1.0
	var land := _resolved_multiplier(land_base, intensity, resistance, exploitation, ROUTE_FLOOR, INF)
	var ocean := _resolved_multiplier(ocean_base, intensity, resistance, exploitation, ROUTE_FLOOR, INF)
	var air := _resolved_multiplier(air_base, intensity, resistance, exploitation, ROUTE_FLOOR, INF)
	var ranged := _resolved_multiplier(ranged_base, intensity, resistance, exploitation, MILITARY_FLOOR, INF)
	var orbital := _resolved_multiplier(orbital_base, intensity, resistance, exploitation, 0.0, INF)
	var knockback := _resolved_multiplier(knockback_base, intensity, resistance, exploitation, 0.0, INF)
	var flying := _resolved_multiplier(flying_base, intensity, resistance, 1.0, 0.0, INF)
	if ranged < 1.0:
		explanation.append("ranged_penalty")
	if orbital > 1.0:
		explanation.append("orbital_boost")
	if knockback > 1.0:
		explanation.append("knockback_boost")
	if flying > 1.0:
		explanation.append("flying_risk")
	var effect_multiplier := minf(ranged, minf(land, minf(ocean, air)))
	return {
		"land_multiplier": land,
		"ocean_multiplier": ocean,
		"air_multiplier": air,
		"ranged_multiplier": ranged,
		"orbital_multiplier": orbital,
		"knockback_multiplier": knockback,
		"flying_risk_multiplier": flying,
		"effect_multiplier": effect_multiplier,
		"floor": MILITARY_FLOOR,
	}


func _intel_effect(definition: WeatherDefinition, intel_domain: String, context: Dictionary, intensity: float, resistance: float, explanation: Array) -> Dictionary:
	var has_intel_context := context.has("intel_domain") or _string_array(context.get("unit_tags", [])).has("intel") or _string_array(context.get("context_tags", [])).has("intel")
	var duration_base := definition.intel_effect_multiplier if has_intel_context and definition.intel_effect_domain == "duration" and intel_domain == "duration" else 1.0
	var range_base := definition.intel_effect_multiplier if has_intel_context and definition.intel_effect_domain == "range" and intel_domain == "range" else 1.0
	var duration := _resolved_multiplier(duration_base, intensity, resistance, 1.0, INTEL_FLOOR, INF)
	var range := _resolved_multiplier(range_base, intensity, resistance, 1.0, INTEL_FLOOR, INF)
	if duration < 1.0 or range < 1.0:
		explanation.append("intel_noise")
	var selected_multiplier := duration if definition.intel_effect_domain == "duration" else range
	return {
		"duration_multiplier": duration,
		"range_multiplier": range,
		"duration_or_range": {"domain": definition.intel_effect_domain, "multiplier": selected_multiplier},
		"effect_multiplier": selected_multiplier,
		"floor": INTEL_FLOOR,
	}


func _damage_effect(definition: WeatherDefinition, intensity: float, resistance: float, explanation: Array) -> Dictionary:
	var damage := maxf(0.0, definition.region_damage_per_second * intensity * (1.0 - resistance))
	if damage > 0.0:
		explanation.append("region_damage")
	return {
		"per_second": damage,
		"nonlethal": definition.damage_nonlethal,
		"capped": definition.damage_capped,
		"policy": "nonlethal_capped" if definition.region_damage_per_second > 0.0 else "none",
	}


func _resolved_multiplier(base: float, intensity: float, resistance: float, exploitation: float, floor_value: float, cap_value: float) -> float:
	var delta := base - 1.0
	var damped_delta := delta * intensity * (1.0 - resistance)
	if delta > 0.0:
		damped_delta *= exploitation
	var value := 1.0 + damped_delta
	if is_finite(floor_value):
		value = maxf(floor_value, value)
	if is_finite(cap_value):
		value = minf(cap_value, value)
	return value


func _matching_product_effect(definition: WeatherDefinition, product_tags: Array) -> Dictionary:
	for tag_variant in product_tags:
		var tag := str(tag_variant)
		if definition.product_effects.has(tag) and definition.product_effects[tag] is Dictionary:
			return (definition.product_effects[tag] as Dictionary).duplicate(true)
	return {}


func _definition_explanations(definition: WeatherDefinition) -> Array:
	var result: Array = []
	for code in definition.explanation_codes:
		result.append(str(code))
	return result


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if value is PackedStringArray:
		for item in value:
			result.append(str(item))
	elif value is Array:
		for item in value:
			result.append(str(item))
	elif value is String and not str(value).strip_edges().is_empty():
		result.append(str(value))
	return result


func _intersects(left: Array, right: Array) -> bool:
	for item in left:
		if right.has(str(item)):
			return true
	return false


func _intersection(left: Array, right: Array) -> Array:
	var result: Array = []
	for item in left:
		var tag := str(item)
		if right.has(tag) and not result.has(tag):
			result.append(tag)
	return result


func _has_tag(tags: Array, tag: String) -> bool:
	return tags.has(tag)


func _domain(value: Variant) -> String:
	var normalized := str(value).strip_edges().to_lower()
	return "ocean" if normalized == "sea" else normalized


func _domain_matches(expected: String, route_mode: String, movement_domain: String) -> bool:
	return route_mode == expected or movement_domain == expected


func _land_context_matches(definition: WeatherDefinition, unit_tags: Array) -> bool:
	var context_tags := Array(definition.context_tags)
	if context_tags.has("heavy"):
		return unit_tags.has("heavy")
	return true
