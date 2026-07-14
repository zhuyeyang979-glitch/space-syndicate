@tool
extends Resource
class_name WeatherDefinition

const FORECAST_MIN_SECONDS := 30.0
const FORECAST_MAX_SECONDS := 60.0
const ACTIVE_MIN_SECONDS := 45.0
const ACTIVE_MAX_SECONDS := 90.0
const FADE_SECONDS := 10.0
const NEGATIVE_FLOOR := 0.40
const MILITARY_INTEL_FLOOR := 0.70
const MONSTER_SPEED_CAP := 1.30

@export var id := ""
@export var display_name := ""
@export_multiline var description := ""
@export_multiline var public_summary := ""
@export var category := ""
@export var icon_key := ""
@export var accent_color := Color("#93c5fd")
@export var forecast_duration := 30.0
@export var active_duration := 45.0
@export var fade_duration := 10.0
@export var affected_region_count := 1

@export var product_tags: PackedStringArray = PackedStringArray()
@export var product_price_growth_multiplier := 1.0
@export var production_multiplier := 1.0
@export var demand_multiplier := 1.0
@export var route_efficiency_multiplier := 1.0
@export var land_movement_multiplier := 1.0
@export var ocean_movement_multiplier := 1.0
@export var air_movement_multiplier := 1.0
@export var ranged_effect_multiplier := 1.0
@export var knockback_multiplier := 1.0
@export var region_damage_per_second := 0.0
@export var monster_preference_tags: PackedStringArray = PackedStringArray()
@export var monster_preference_multiplier := 1.0
@export var monster_speed_multiplier := 1.0
@export var monster_armor_multiplier := 1.0
@export var intel_effect_multiplier := 1.0
@export_enum("duration", "range") var intel_effect_domain := "duration"
@export_multiline var counterplay_hint := ""
@export_multiline var exploitation_hint := ""

@export var orbital_effect_multiplier := 1.0
@export var city_maintenance_multiplier := 1.0
@export var flying_risk_multiplier := 1.0
@export var product_effects := {}
@export var damage_nonlethal := false
@export var damage_capped := false
@export var context_tags: PackedStringArray = PackedStringArray()
@export var explanation_codes: PackedStringArray = PackedStringArray()


func to_dictionary() -> Dictionary:
	var summary := description if not description.strip_edges().is_empty() else public_summary
	return {
		"id": id,
		"display_name": display_name,
		"label": display_name,
		"description": summary,
		"public_summary": summary,
		"category": category,
		"icon_key": icon_key,
		"accent_color": accent_color.to_html(),
		"forecast_duration": forecast_duration,
		"active_duration": active_duration,
		"fade_duration": fade_duration,
		"affected_region_count": affected_region_count,
		"product_tags": Array(product_tags),
		"product_price_growth_multiplier": product_price_growth_multiplier,
		"production_multiplier": production_multiplier,
		"demand_multiplier": demand_multiplier,
		"route_efficiency_multiplier": route_efficiency_multiplier,
		"land_movement_multiplier": land_movement_multiplier,
		"ocean_movement_multiplier": ocean_movement_multiplier,
		"air_movement_multiplier": air_movement_multiplier,
		"ranged_effect_multiplier": ranged_effect_multiplier,
		"knockback_multiplier": knockback_multiplier,
		"region_damage_per_second": region_damage_per_second,
		"monster_preference_tags": Array(monster_preference_tags),
		"monster_preference_multiplier": monster_preference_multiplier,
		"monster_speed_multiplier": monster_speed_multiplier,
		"monster_armor_multiplier": monster_armor_multiplier,
		"intel_effect_multiplier": intel_effect_multiplier,
		"intel_effect_domain": intel_effect_domain,
		"counterplay_hint": counterplay_hint,
		"exploitation_hint": exploitation_hint,
		"orbital_effect_multiplier": orbital_effect_multiplier,
		"city_maintenance_multiplier": city_maintenance_multiplier,
		"flying_risk_multiplier": flying_risk_multiplier,
		"product_effects": product_effects.duplicate(true),
		"damage_nonlethal": damage_nonlethal,
		"damage_capped": damage_capped,
		"context_tags": Array(context_tags),
		"explanation_codes": Array(explanation_codes),
		# Legacy public compatibility keys; not authoritative for v1 resolver.
		"economy_multiplier": maxf(product_price_growth_multiplier, maxf(production_multiplier, demand_multiplier)),
		"route_multiplier": route_efficiency_multiplier,
		"transport_multiplier": route_efficiency_multiplier,
		"military_multiplier": minf(ranged_effect_multiplier, minf(land_movement_multiplier, minf(ocean_movement_multiplier, air_movement_multiplier))),
		"intel_multiplier": intel_effect_multiplier,
		"damage_per_second": region_damage_per_second,
	}


func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if id.strip_edges().is_empty():
		errors.append("id_missing")
	if display_name.strip_edges().is_empty():
		errors.append("display_name_missing")
	if description.strip_edges().is_empty() and public_summary.strip_edges().is_empty():
		errors.append("description_missing")
	if category.strip_edges().is_empty():
		errors.append("category_missing")
	if forecast_duration < FORECAST_MIN_SECONDS or forecast_duration > FORECAST_MAX_SECONDS:
		errors.append("forecast_duration_out_of_range")
	if active_duration < ACTIVE_MIN_SECONDS or active_duration > ACTIVE_MAX_SECONDS:
		errors.append("active_duration_out_of_range")
	if not is_equal_approx(fade_duration, FADE_SECONDS):
		errors.append("fade_duration_must_be_10")
	if affected_region_count < 1:
		errors.append("affected_region_count_invalid")
	for check in _positive_guardrail_checks():
		errors.append(check)
	for check in _floor_guardrail_checks():
		errors.append(check)
	if monster_speed_multiplier > MONSTER_SPEED_CAP:
		errors.append("monster_speed_above_cap")
	if intel_effect_multiplier < MILITARY_INTEL_FLOOR:
		errors.append("intel_effect_below_floor")
	if not ["duration", "range"].has(intel_effect_domain):
		errors.append("intel_effect_domain_invalid")
	if region_damage_per_second > 0.0 and (not damage_nonlethal or not damage_capped):
		errors.append("damage_must_be_nonlethal_and_capped")
	if not (product_effects is Dictionary):
		errors.append("product_effects_invalid")
	return errors


func is_valid_definition() -> bool:
	return validation_errors().is_empty()


func _positive_guardrail_checks() -> Array[String]:
	var errors: Array[String] = []
	for pair in [
		["product_price_growth_multiplier", product_price_growth_multiplier],
		["production_multiplier", production_multiplier],
		["demand_multiplier", demand_multiplier],
		["monster_preference_multiplier", monster_preference_multiplier],
		["monster_speed_multiplier", monster_speed_multiplier],
		["monster_armor_multiplier", monster_armor_multiplier],
		["knockback_multiplier", knockback_multiplier],
		["orbital_effect_multiplier", orbital_effect_multiplier],
		["city_maintenance_multiplier", city_maintenance_multiplier],
		["flying_risk_multiplier", flying_risk_multiplier],
		["route_efficiency_multiplier", route_efficiency_multiplier],
		["land_movement_multiplier", land_movement_multiplier],
		["ocean_movement_multiplier", ocean_movement_multiplier],
		["air_movement_multiplier", air_movement_multiplier],
		["ranged_effect_multiplier", ranged_effect_multiplier],
	]:
		var key := str(pair[0])
		var value := float(pair[1])
		if value > 1.0 and (value < 1.10 or value > 1.30):
			errors.append("%s_positive_out_of_guardrail" % key)
	return errors


func _floor_guardrail_checks() -> Array[String]:
	var errors: Array[String] = []
	for pair in [
		["route_efficiency_multiplier", route_efficiency_multiplier, NEGATIVE_FLOOR],
		["land_movement_multiplier", land_movement_multiplier, NEGATIVE_FLOOR],
		["ocean_movement_multiplier", ocean_movement_multiplier, NEGATIVE_FLOOR],
		["air_movement_multiplier", air_movement_multiplier, NEGATIVE_FLOOR],
		["ranged_effect_multiplier", ranged_effect_multiplier, MILITARY_INTEL_FLOOR],
		["intel_effect_multiplier", intel_effect_multiplier, MILITARY_INTEL_FLOOR],
	]:
		var key := str(pair[0])
		var value := float(pair[1])
		var floor_value := float(pair[2])
		if value < floor_value:
			errors.append("%s_below_floor" % key)
	return errors
