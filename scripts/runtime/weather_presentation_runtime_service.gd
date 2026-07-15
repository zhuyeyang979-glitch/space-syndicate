extends Node
class_name WeatherPresentationRuntimeService

const FORECAST_VIEW_MODEL := preload("res://scripts/viewmodels/weather_forecast_view_model.gd")
const MAP_OVERLAY_VIEW_MODEL := preload("res://scripts/viewmodels/weather_map_overlay_view_model.gd")

const SERVICE_ID := "weather_presentation_runtime_service"
const DEFINITIONS_SCHEMA := "weather_definitions_public.v1"

var _weather_controller: WeatherRuntimeController


func configure(weather_controller: WeatherRuntimeController) -> void:
	_weather_controller = weather_controller


func runtime_public_projection() -> Dictionary:
	if _weather_controller == null:
		return {}
	var source := _weather_controller.public_snapshot()
	var events: Array = []
	for event_variant in source.get("events", []):
		if not (event_variant is Dictionary):
			return {}
		var event := event_variant as Dictionary
		var phase := str(event.get("phase", ""))
		var boundary_world_us := _phase_boundary_world_us(event, phase)
		events.append({
			"id": int(event.get("id", 0)),
			"definition_id": str(event.get("definition_id", "")),
			"type": str(event.get("type", "")),
			"label": str(event.get("label", "")),
			"color": _hex_color(str(event.get("color", ""))),
			"region_indices": (event.get("region_indices", []) as Array).duplicate(),
			"districts": (event.get("districts", []) as Array).duplicate(),
			"phase": phase,
			"source_type": str(event.get("source_type", "")),
			"created_world_us": int(event.get("created_at_world_us", 0)),
			"boundary_world_us": boundary_world_us,
			"forecast_remaining_seconds": float(event.get("forecast_remaining", 0.0)),
			"active_remaining_seconds": float(event.get("active_remaining", 0.0)),
			"fade_remaining_seconds": float(event.get("fade_remaining", 0.0)),
			"intensity": float(event.get("intensity", 0.0)),
		})
	return {
		"schema_version": int(source.get("schema_version", -1)),
		"world_effective_us": int(source.get("world_effective_us", 0)),
		"sequence": int(source.get("sequence", 0)),
		"next_generation_world_us": int(source.get("next_generation_world_us", 0)),
		"new_forecasts_allowed": bool(source.get("new_forecasts_allowed", false)),
		"events": events,
	}


func definitions_public_projection() -> Dictionary:
	if _weather_controller == null:
		return {}
	var catalog := _weather_controller.weather_types_snapshot()
	var definitions: Array = []
	for definition_id in FORECAST_VIEW_MODEL.WEATHER_IDS:
		var raw_variant: Variant = catalog.get(definition_id, {})
		if not (raw_variant is Dictionary):
			return {}
		var raw := raw_variant as Dictionary
		definitions.append({
			"definition_id": definition_id,
			"type": definition_id,
			"label": str(raw.get("display_name", "")),
			"description": str(raw.get("description", "")),
			"category": str(raw.get("category", "regional_weather")),
			"icon_key": _icon_key(definition_id),
			"accent_hex": _hex_color(str(raw.get("accent_color", ""))),
			"pattern_key": _pattern_key(definition_id),
			"exploitation_hint": str(raw.get("exploitation_hint", "")),
			"counterplay_hint": str(raw.get("counterplay_hint", "")),
			"effects": _effect_rows(definition_id, raw),
		})
	return {"schema_version": DEFINITIONS_SCHEMA, "definitions": definitions}


func forecast_view_model() -> Dictionary:
	return FORECAST_VIEW_MODEL.new().compose_from_runtime(
		runtime_public_projection(),
		definitions_public_projection()
	)


func map_overlay_view_model() -> Dictionary:
	var forecast := forecast_view_model()
	return MAP_OVERLAY_VIEW_MODEL.new().compose(forecast) if not forecast.is_empty() else {}


func region_detail_snapshot(region_index: int) -> Dictionary:
	if region_index < 0:
		return {}
	var forecast := forecast_view_model()
	if forecast.is_empty():
		return {}
	for event_variant in forecast.get("events", []):
		var event := event_variant as Dictionary
		for region_variant in event.get("regions", []):
			if int((region_variant as Dictionary).get("region_index", -1)) == region_index:
				return {
					"schema_version": "weather_region_detail.v1",
					"event_id": int(event.get("event_id", 0)),
					"region_index": region_index,
					"definition_id": str(event.get("definition_id", "")),
					"display_name": str(event.get("display_name", "")),
					"phase": str(event.get("phase", "")),
					"remaining_us": int(event.get("remaining_us", 0)),
					"intensity": float(event.get("intensity", 0.0)),
					"effects": (event.get("effects", []) as Array).duplicate(true),
					"exploitation_hint": str(event.get("exploitation_hint", "")),
					"counterplay_hint": str(event.get("counterplay_hint", "")),
					"accessible_text": str(event.get("accessible_text", "")),
				}
	return {
		"schema_version": "weather_region_detail.v1",
		"event_id": 0,
		"region_index": region_index,
		"definition_id": "",
		"display_name": "天气平稳",
		"phase": "clear",
		"remaining_us": 0,
		"intensity": 0.0,
		"effects": [],
		"exploitation_hint": "维持当前计划",
		"counterplay_hint": "无需额外部署",
		"accessible_text": "当前区域天气平稳。",
	}


func debug_snapshot() -> Dictionary:
	var runtime := runtime_public_projection()
	var definitions := definitions_public_projection()
	var forecast := forecast_view_model()
	return {
		"service_id": SERVICE_ID,
		"service_ready": _weather_controller != null and not runtime.is_empty() and not definitions.is_empty() and not forecast.is_empty(),
		"service_authoritative": false,
		"weather_controller_bound": _weather_controller != null,
		"runtime_key_count": runtime.size(),
		"definition_count": (definitions.get("definitions", []) as Array).size(),
		"forecast_state": str(forecast.get("state", "invalid")),
		"visibility_scope": "public",
	}


func _phase_boundary_world_us(event: Dictionary, phase: String) -> int:
	match phase:
		"queued", "forecast": return int(event.get("active_starts_at_world_us", 0))
		"active": return int(event.get("active_ends_at_world_us", 0))
		"fading": return int(event.get("fade_ends_at_world_us", 0))
	return 0


func _effect_rows(definition_id: String, raw: Dictionary) -> Array:
	match definition_id:
		"ion_storm":
			return [
				_effect("energy_growth", "economy", "能源价格增长", _delta_text(float(raw.get("product_price_growth_multiplier", 1.0))), "opportunity", ["product.weather_energy"]),
				_effect("air_route", "route", "空中运输效率", _delta_text(float(raw.get("air_movement_multiplier", 1.0))), "opportunity", ["route.air"]),
				_effect("flying_risk", "military", "飞行单位风险", _delta_text(float(raw.get("flying_risk_multiplier", 1.0))), "risk", ["unit.flying"]),
			]
		"gravity_tide":
			return [
				_effect("ocean_route", "route", "海运效率", _delta_text(float(raw.get("ocean_movement_multiplier", 1.0))), "risk", ["route.ocean"]),
				_effect("knockback", "military", "击退距离", _delta_text(float(raw.get("knockback_multiplier", 1.0))), "opportunity", ["effect.knockback"]),
				_effect("orbital", "military", "轨道攻击效果", _delta_text(float(raw.get("orbital_effect_multiplier", 1.0))), "opportunity", ["effect.orbital"]),
			]
		"spore_season":
			return [
				_effect("bio_production", "economy", "生物/医药/食品生产", _delta_text(float(raw.get("production_multiplier", 1.0))), "opportunity", ["product.weather_biological", "product.weather_medicine", "product.weather_food"]),
				_effect("bio_demand", "economy", "相关商品需求", _delta_text(float(raw.get("demand_multiplier", 1.0))), "opportunity", ["demand.biological"]),
				_effect("route_drag", "route", "污染路线效率", _delta_text(float(raw.get("route_efficiency_multiplier", 1.0))), "risk", ["route.polluted"]),
			]
		"crystal_dust_storm":
			return [
				_effect("crystal_output", "economy", "晶体商品产量", _delta_text(float(raw.get("production_multiplier", 1.0))), "opportunity", ["product.weather_crystal"]),
				_effect("ranged_effect", "military", "远程效果", _delta_text(float(raw.get("ranged_effect_multiplier", 1.0))), "risk", ["unit.ranged"]),
				_effect("region_damage", "region", "区域轻微损伤", "%.2f/秒（非致命）" % float(raw.get("region_damage_per_second", 0.0)), "risk", ["region.damage.nonlethal"]),
			]
		"deep_freeze":
			return [
				_effect("food_energy_demand", "economy", "食品与能源需求", _delta_text(float(raw.get("demand_multiplier", 1.0))), "opportunity", ["product.weather_food", "product.weather_energy"]),
				_effect("land_movement", "route", "陆地移动效率", _delta_text(float(raw.get("land_movement_multiplier", 1.0))), "risk", ["route.land"]),
				_effect("city_maintenance", "economy", "城市维持压力", _delta_text(float(raw.get("city_maintenance_multiplier", 1.0))), "risk", ["city.maintenance"]),
			]
		"solar_flare":
			var electronic := raw.get("product_effects", {}) as Dictionary
			var electronic_effect := electronic.get("weather_electronic", {}) as Dictionary
			return [
				_effect("energy_growth", "economy", "能源价格增长", _delta_text(float(raw.get("product_price_growth_multiplier", 1.0))), "opportunity", ["product.weather_energy"]),
				_effect("electronic_output", "economy", "电子商品生产", _delta_text(float(electronic_effect.get("production_multiplier", 1.0))), "risk", ["product.weather_electronic"]),
				_effect("intel_duration", "intel", "情报持续时间", _delta_text(float(raw.get("intel_effect_multiplier", 1.0))), "risk", ["intel.duration"]),
			]
	return []


func _effect(effect_id: String, scope: String, label: String, value_text: String, polarity: String, tags: Array) -> Dictionary:
	return {
		"effect_id": effect_id,
		"scope": scope,
		"label": label,
		"value_text": value_text,
		"polarity": polarity,
		"classification_tags": tags.duplicate(),
	}


func _delta_text(multiplier: float) -> String:
	var percent := int(round((multiplier - 1.0) * 100.0))
	return "%+d%%" % percent


func _icon_key(definition_id: String) -> String:
	var values := {
		"ion_storm": "ion_bolt",
		"gravity_tide": "gravity_wave",
		"spore_season": "spore",
		"crystal_dust_storm": "crystal",
		"deep_freeze": "snowflake",
		"solar_flare": "solar",
	}
	return str(values.get(definition_id, "ion_bolt"))


func _pattern_key(definition_id: String) -> String:
	var values := {
		"ion_storm": "diagonal",
		"gravity_tide": "concentric",
		"spore_season": "dots",
		"crystal_dust_storm": "facets",
		"deep_freeze": "crosshatch",
		"solar_flare": "rays",
	}
	return str(values.get(definition_id, "diagonal"))


func _hex_color(value: String) -> String:
	var normalized := value.strip_edges().trim_prefix("#")
	if normalized.length() >= 6:
		return "#%s" % normalized.substr(0, 6).to_upper()
	return "#93C5FD"
