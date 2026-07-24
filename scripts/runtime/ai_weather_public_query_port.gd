@tool
extends Node
class_name AiWeatherPublicQueryPort

const RULES_SCHEMA_VERSION := 1

@export var weather_runtime_controller_path: NodePath
@export var region_knowledge_query_port_path: NodePath

var _query_count := 0
var _rejected_query_count := 0


func is_ready() -> bool:
	return _weather() != null \
		and _regions() != null \
		and _regions().is_ready()


func public_snapshot() -> Dictionary:
	_query_count += 1
	if not is_ready():
		_rejected_query_count += 1
		return {}
	var source := _weather().public_snapshot()
	var result := {
		"schema_version": int(source.get("schema_version", 0)),
		"world_effective_us": int(source.get("world_effective_us", 0)),
		"forecast": _pure_dictionary(source.get("forecast", {})),
		"active_zones": _pure_array(source.get("active_zones", [])),
		"events": _pure_array(source.get("events", [])),
		"sequence": int(source.get("sequence", 0)),
		"new_forecasts_allowed": bool(source.get("new_forecasts_allowed", false)),
		"timing": _pure_dictionary(source.get("timing", {})),
		"visibility_scope": "public",
	}
	if not TablePresentationPureDataPolicy.is_pure_data(result):
		_rejected_query_count += 1
		return {}
	return TablePresentationPureDataPolicy.detached_copy(result)


func rules_snapshot() -> Dictionary:
	_query_count += 1
	if not is_ready():
		_rejected_query_count += 1
		return {}
	var result := {
		"schema_version": RULES_SCHEMA_VERSION,
		"weather_type_ids": _weather().weather_type_ids(),
		"weather_types": WeatherRuntimeController.WEATHER_TYPES.duplicate(true),
		"duration_min_seconds": WeatherRuntimeController.DURATION_MIN_SECONDS,
		"duration_max_seconds": WeatherRuntimeController.DURATION_MAX_SECONDS,
		"forecast_lead_min_seconds": WeatherRuntimeController.FORECAST_LEAD_MIN_SECONDS,
		"forecast_lead_max_seconds": WeatherRuntimeController.FORECAST_LEAD_MAX_SECONDS,
		"zone_max": WeatherRuntimeController.ZONE_MAX,
		"zone_count_for_planet": _weather().zone_count_for_planet(),
		"visibility_scope": "public",
	}
	if not TablePresentationPureDataPolicy.is_pure_data(result):
		_rejected_query_count += 1
		return {}
	return TablePresentationPureDataPolicy.detached_copy(result)


func definition_snapshot(type_id: String) -> Dictionary:
	_query_count += 1
	if not is_ready() or not _weather().weather_type_ids().has(type_id):
		_rejected_query_count += 1
		return {}
	var result := _weather().template(type_id)
	if result.is_empty() or not TablePresentationPureDataPolicy.is_pure_data(result):
		_rejected_query_count += 1
		return {}
	return TablePresentationPureDataPolicy.detached_copy(result)


func label(type_id: String) -> String:
	var definition := definition_snapshot(type_id)
	return str(definition.get("display_name", type_id)) if not definition.is_empty() else type_id


func preview_districts(anchor_index: int, zone_count: int) -> Array:
	_query_count += 1
	if not is_ready():
		_rejected_query_count += 1
		return []
	var anchor := _regions().public_region(anchor_index)
	if anchor.is_empty() or bool(anchor.get("destroyed", false)):
		_rejected_query_count += 1
		return []
	var bounded_zone_count := clampi(zone_count, 1, WeatherRuntimeController.ZONE_MAX)
	if bounded_zone_count != 1:
		_rejected_query_count += 1
		return []
	return [anchor_index]


func debug_snapshot() -> Dictionary:
	return {
		"port_ready": is_ready(),
		"query_count": _query_count,
		"rejected_query_count": _rejected_query_count,
		"returns_public_weather_only": true,
		"preview_consumes_rng": false,
		"mutates_world": false,
		"consumes_rng": false,
		"references_main": false,
		"owns_state": false,
	}


func _pure_dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) \
		if value is Dictionary and TablePresentationPureDataPolicy.is_pure_data(value) else {}


func _pure_array(value: Variant) -> Array:
	return (value as Array).duplicate(true) \
		if value is Array and TablePresentationPureDataPolicy.is_pure_data(value) else []


func _weather() -> WeatherRuntimeController:
	return get_node_or_null(weather_runtime_controller_path) as WeatherRuntimeController


func _regions() -> AiRegionKnowledgeQueryPort:
	return get_node_or_null(region_knowledge_query_port_path) as AiRegionKnowledgeQueryPort
