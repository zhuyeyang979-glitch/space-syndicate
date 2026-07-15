extends Node
class_name WeatherTelemetryRuntimeService

const SERVICE_ID := "weather_telemetry_runtime_service"
const EVENT_SCHEMA := "weather_telemetry_event.v1"
const LOG_SCHEMA := "weather_telemetry_log.v1"
const AGGREGATE_SCHEMA := "weather_telemetry_aggregate.v1"

const DEFAULT_EVENT_CAPACITY := 256
const MAX_EVENT_CAPACITY := 512
const MIN_REGION_INDEX := 0
const MAX_REGION_INDEX := 63
const MAX_DURATION_SECONDS := 3600.0
const MAX_PERCENT_DELTA := 1000.0
const MAX_REGION_DAMAGE := 1_000_000.0
const MAX_ECONOMIC_DELTA := 1_000_000_000.0

const DEFINITION_IDS := [
	"ion_storm",
	"gravity_tide",
	"spore_season",
	"crystal_dust_storm",
	"deep_freeze",
	"solar_flare",
]
const DEFINITION_NAMES := {
	"ion_storm": "离子风暴",
	"gravity_tide": "引力潮",
	"spore_season": "孢子季",
	"crystal_dust_storm": "晶尘暴",
	"deep_freeze": "极寒期",
	"solar_flare": "太阳耀斑",
}
const EVENT_TYPES := ["forecast", "activation", "end"]
const RESPONSE_CATEGORIES := [
	"route_after_forecast",
	"buy_after_forecast",
	"build_after_forecast",
	"play_after_forecast",
	"no_response_after_forecast",
]
const NOT_APPLICABLE_RESPONSE := "not_applicable"
const OBSERVABLE_METRICS := [
	"product_price_growth_delta_percent",
	"route_efficiency_delta_percent",
	"region_damage",
	"estimated_economic_delta",
]
const EVENT_KEYS := [
	"schema_version",
	"event_type",
	"definition_id",
	"region_index",
	"forecast_duration_seconds",
	"active_duration_seconds",
	"fade_duration_seconds",
	"product_price_growth_delta_percent",
	"route_efficiency_delta_percent",
	"player_response_category",
	"monster_target_weather_influenced",
	"region_damage",
	"estimated_economic_delta",
]
const PRIVATE_KEY_PATTERNS := [
	"player",
	"seat",
	"owner",
	"cash",
	"hand",
	"discard",
	"card_id",
	"card_identity",
	"card_name",
	"hidden_target",
	"hidden_monster_target",
	"monster_target",
	"monster_target_id",
	"monster_weights",
	"monster_target_weights",
	"target_weights",
	"ai_plan",
	"ai_policy",
	"save",
	"camera",
]
const PRIVATE_VALUE_PATTERNS := [
	"private",
	"player_",
	"player-id",
	"owner",
	"cash=",
	"cash:",
	"hand",
	"discard",
	"card_id",
	"card-id",
	"hidden_target",
	"target_weights",
	"ai_plan",
	"ai-plan",
	"save://",
	"camera",
]

var _event_capacity := DEFAULT_EVENT_CAPACITY

@export_range(1, MAX_EVENT_CAPACITY, 1) var event_capacity := DEFAULT_EVENT_CAPACITY:
	set(value):
		_event_capacity = clampi(value, 1, MAX_EVENT_CAPACITY)
	get:
		return _event_capacity

var _events: Array[Dictionary] = []
var _sessions: Dictionary = {}
var _definition_stats := {}
var _region_stats := {}
var _next_sequence := 1
var _dropped_count := 0
var _rejected_count := 0
var _last_error := ""


func _init() -> void:
	_reset_aggregates()


func configure_capacity(requested_capacity: int) -> int:
	event_capacity = clampi(requested_capacity, 1, MAX_EVENT_CAPACITY)
	while _events.size() > event_capacity:
		_events.pop_front()
		_dropped_count += 1
	return event_capacity


func record_event(event: Dictionary) -> bool:
	_last_error = ""
	if not _validate_event(event):
		_rejected_count += 1
		return false
	var stored := _normalized_event(event)
	stored["sequence"] = _next_sequence
	_next_sequence += 1
	if _events.size() >= event_capacity:
		_events.pop_front()
		_dropped_count += 1
	_events.append(stored)
	if str(stored["event_type"]) == "end":
		_accumulate_end_event(stored)
	return true


func begin_weather_session(
	event_id: int,
	definition_id: String,
	region_indices: Array,
	forecast_duration_seconds: float,
	active_duration_seconds: float,
	fade_duration_seconds: float
) -> bool:
	if event_id <= 0 or not DEFINITION_IDS.has(definition_id):
		return _reject("session_identity")
	var regions := _normalized_regions(region_indices)
	if regions.is_empty():
		return _reject("session_regions")
	if not _valid_duration(forecast_duration_seconds) or forecast_duration_seconds <= 0.0 \
		or not _valid_duration(active_duration_seconds) or active_duration_seconds <= 0.0 \
		or not _valid_duration(fade_duration_seconds) or fade_duration_seconds <= 0.0:
		return _reject("session_durations")
	var key := str(event_id)
	if _sessions.has(key):
		return _session_identity_matches(_sessions[key] as Dictionary, definition_id, regions)
	var session := {
		"event_id": event_id,
		"definition_id": definition_id,
		"region_indices": regions,
		"forecast_duration_seconds": forecast_duration_seconds,
		"active_duration_seconds": active_duration_seconds,
		"fade_duration_seconds": fade_duration_seconds,
		"activated": false,
		"response_category": NOT_APPLICABLE_RESPONSE,
		"monster_target_weather_influenced": false,
		"metric_totals": {},
		"metric_samples": {},
	}
	for metric in OBSERVABLE_METRICS:
		(session["metric_totals"] as Dictionary)[metric] = 0.0
		(session["metric_samples"] as Dictionary)[metric] = 0
	for region_index in regions:
		if not record_event(_lifecycle_event("forecast", definition_id, int(region_index), forecast_duration_seconds, 0.0, 0.0)):
			return false
	_sessions[key] = session
	return true


func activate_weather_session(event_id: int) -> bool:
	var key := str(event_id)
	if not _sessions.has(key):
		return _reject("session_missing")
	var session := _sessions[key] as Dictionary
	if bool(session.get("activated", false)):
		return true
	for region_index in session.get("region_indices", []):
		if not record_event(_lifecycle_event(
			"activation",
			str(session.get("definition_id", "")),
			int(region_index),
			0.0,
			float(session.get("active_duration_seconds", 0.0)),
			0.0
		)):
			return false
	session["activated"] = true
	_sessions[key] = session
	return true


func observe_public_metric(event_id: int, metric: String, value: float) -> bool:
	if not OBSERVABLE_METRICS.has(metric) or not is_finite(value):
		return _reject("metric_invalid")
	var key := str(event_id)
	if not _sessions.has(key):
		return _reject("session_missing")
	var session := _sessions[key] as Dictionary
	var totals := session.get("metric_totals", {}) as Dictionary
	var samples := session.get("metric_samples", {}) as Dictionary
	if metric == "region_damage":
		value = clampf(value, 0.0, MAX_REGION_DAMAGE)
	elif metric == "estimated_economic_delta":
		value = clampf(value, -MAX_ECONOMIC_DELTA, MAX_ECONOMIC_DELTA)
	else:
		value = clampf(value, -100.0, MAX_PERCENT_DELTA)
	totals[metric] = float(totals.get(metric, 0.0)) + value
	samples[metric] = int(samples.get(metric, 0)) + 1
	session["metric_totals"] = totals
	session["metric_samples"] = samples
	_sessions[key] = session
	return true


func record_public_response(region_index: int, category: String) -> int:
	if region_index < MIN_REGION_INDEX or region_index > MAX_REGION_INDEX or not RESPONSE_CATEGORIES.has(category):
		return 0
	var matched := 0
	for key_variant in _sessions.keys():
		var key := str(key_variant)
		var session := _sessions[key] as Dictionary
		if not (session.get("region_indices", []) as Array).has(region_index):
			continue
		if str(session.get("response_category", NOT_APPLICABLE_RESPONSE)) == NOT_APPLICABLE_RESPONSE:
			session["response_category"] = category
			_sessions[key] = session
		matched += 1
	return matched


func mark_monster_target_weather_influenced(event_id: int) -> bool:
	var key := str(event_id)
	if not _sessions.has(key):
		return false
	var session := _sessions[key] as Dictionary
	session["monster_target_weather_influenced"] = true
	_sessions[key] = session
	return true


func finish_weather_session(event_id: int) -> bool:
	var key := str(event_id)
	if not _sessions.has(key):
		return _reject("session_missing")
	var session := _sessions[key] as Dictionary
	var totals := session.get("metric_totals", {}) as Dictionary
	var samples := session.get("metric_samples", {}) as Dictionary
	for region_index in session.get("region_indices", []):
		var event := _lifecycle_event(
			"end",
			str(session.get("definition_id", "")),
			int(region_index),
			float(session.get("forecast_duration_seconds", 0.0)),
			float(session.get("active_duration_seconds", 0.0)),
			float(session.get("fade_duration_seconds", 0.0))
		)
		event["product_price_growth_delta_percent"] = _sample_average(totals, samples, "product_price_growth_delta_percent")
		event["route_efficiency_delta_percent"] = _sample_average(totals, samples, "route_efficiency_delta_percent")
		event["region_damage"] = float(totals.get("region_damage", 0.0))
		event["estimated_economic_delta"] = float(totals.get("estimated_economic_delta", 0.0))
		event["player_response_category"] = str(session.get("response_category", NOT_APPLICABLE_RESPONSE))
		if event["player_response_category"] == NOT_APPLICABLE_RESPONSE:
			event["player_response_category"] = "no_response_after_forecast"
		event["monster_target_weather_influenced"] = bool(session.get("monster_target_weather_influenced", false))
		if not record_event(event):
			return false
	_sessions.erase(key)
	return true


func event_field_schema() -> Dictionary:
	return {
		"schema_version": EVENT_SCHEMA,
		"exact_keys": EVENT_KEYS.duplicate(),
		"event_types": EVENT_TYPES.duplicate(),
		"definition_ids": DEFINITION_IDS.duplicate(),
		"response_categories": RESPONSE_CATEGORIES.duplicate(),
		"non_terminal_response": NOT_APPLICABLE_RESPONSE,
		"region_index_min": MIN_REGION_INDEX,
		"region_index_max": MAX_REGION_INDEX,
	}


func recent_events_snapshot() -> Dictionary:
	return {
		"schema_version": LOG_SCHEMA,
		"capacity": event_capacity,
		"count": _events.size(),
		"dropped_count": _dropped_count,
		"rejected_count": _rejected_count,
		"events": _events.duplicate(true),
	}


func aggregate_snapshot() -> Dictionary:
	var definitions: Array = []
	for definition_id in DEFINITION_IDS:
		var definition_row := _stats_row(str(definition_id), _definition_stats[str(definition_id)])
		var regions: Array = []
		var definition_regions: Dictionary = _region_stats[str(definition_id)]
		var region_indices: Array = definition_regions.keys()
		region_indices.sort()
		for region_index_variant in region_indices:
			var region_row := _stats_row(str(definition_id), definition_regions[region_index_variant])
			region_row["region_index"] = int(region_index_variant)
			regions.append(region_row)
		definition_row["hit_region_count"] = regions.size()
		definition_row["regions"] = regions
		definitions.append(definition_row)
	return {
		"schema_version": AGGREGATE_SCHEMA,
		"definition_count": definitions.size(),
		"completed_event_count": _completed_event_count(),
		"definitions": definitions,
	}


func clear() -> void:
	_events.clear()
	_sessions.clear()
	_next_sequence = 1
	_dropped_count = 0
	_rejected_count = 0
	_last_error = ""
	_reset_aggregates()


func get_last_error() -> String:
	return _last_error


func debug_snapshot() -> Dictionary:
	return {
		"service_id": SERVICE_ID,
		"authoritative": false,
		"storage_scope": "local_memory_only",
		"network_enabled": false,
		"save_owner": false,
		"event_capacity": event_capacity,
		"event_count": _events.size(),
		"active_session_count": _sessions.size(),
		"definition_capacity": DEFINITION_IDS.size(),
		"region_domain_size": MAX_REGION_INDEX - MIN_REGION_INDEX + 1,
		"rejected_count": _rejected_count,
		"dropped_count": _dropped_count,
	}


func _validate_event(event: Dictionary) -> bool:
	if _contains_private_key(event):
		return _reject("private_key")
	if _contains_private_value(event):
		return _reject("private_value")
	if not _has_exact_keys(event, EVENT_KEYS):
		return _reject("event_keys")
	if typeof(event["schema_version"]) != TYPE_STRING or str(event["schema_version"]) != EVENT_SCHEMA:
		return _reject("schema_version")
	if typeof(event["event_type"]) != TYPE_STRING or not EVENT_TYPES.has(str(event["event_type"])):
		return _reject("event_type")
	if typeof(event["definition_id"]) != TYPE_STRING or not DEFINITION_IDS.has(str(event["definition_id"])):
		return _reject("definition_id")
	if typeof(event["region_index"]) != TYPE_INT:
		return _reject("region_index_type")
	var region_index := int(event["region_index"])
	if region_index < MIN_REGION_INDEX or region_index > MAX_REGION_INDEX:
		return _reject("region_index_range")
	for key in [
		"forecast_duration_seconds",
		"active_duration_seconds",
		"fade_duration_seconds",
		"product_price_growth_delta_percent",
		"route_efficiency_delta_percent",
		"region_damage",
		"estimated_economic_delta",
	]:
		if not _is_finite_number(event[key]):
			return _reject("%s_type" % str(key))
	if typeof(event["player_response_category"]) != TYPE_STRING:
		return _reject("player_response_category_type")
	if typeof(event["monster_target_weather_influenced"]) != TYPE_BOOL:
		return _reject("monster_target_weather_influenced_type")
	if not _validate_ranges(event):
		return false
	return _validate_lifecycle_shape(event)


func _validate_ranges(event: Dictionary) -> bool:
	for duration_key in ["forecast_duration_seconds", "active_duration_seconds", "fade_duration_seconds"]:
		var duration := float(event[duration_key])
		if duration < 0.0 or duration > MAX_DURATION_SECONDS:
			return _reject("%s_range" % str(duration_key))
	for percent_key in ["product_price_growth_delta_percent", "route_efficiency_delta_percent"]:
		var percent_delta := float(event[percent_key])
		if percent_delta < -100.0 or percent_delta > MAX_PERCENT_DELTA:
			return _reject("%s_range" % str(percent_key))
	var region_damage := float(event["region_damage"])
	if region_damage < 0.0 or region_damage > MAX_REGION_DAMAGE:
		return _reject("region_damage_range")
	if absf(float(event["estimated_economic_delta"])) > MAX_ECONOMIC_DELTA:
		return _reject("estimated_economic_delta_range")
	return true


func _validate_lifecycle_shape(event: Dictionary) -> bool:
	var event_type := str(event["event_type"])
	var response := str(event["player_response_category"])
	if event_type == "forecast":
		if float(event["forecast_duration_seconds"]) <= 0.0:
			return _reject("forecast_duration_required")
		if not _non_terminal_metrics_are_empty(event, "forecast_duration_seconds"):
			return _reject("forecast_payload_scope")
		return response == NOT_APPLICABLE_RESPONSE or _reject("forecast_response")
	if event_type == "activation":
		if float(event["active_duration_seconds"]) <= 0.0:
			return _reject("active_duration_required")
		if not _non_terminal_metrics_are_empty(event, "active_duration_seconds"):
			return _reject("activation_payload_scope")
		return response == NOT_APPLICABLE_RESPONSE or _reject("activation_response")
	if float(event["forecast_duration_seconds"]) <= 0.0 \
		or float(event["active_duration_seconds"]) <= 0.0 \
		or float(event["fade_duration_seconds"]) <= 0.0:
		return _reject("end_durations_required")
	if not RESPONSE_CATEGORIES.has(response):
		return _reject("end_response_category")
	return true


func _non_terminal_metrics_are_empty(event: Dictionary, duration_key: String) -> bool:
	for key in ["forecast_duration_seconds", "active_duration_seconds", "fade_duration_seconds"]:
		if str(key) != duration_key and not is_zero_approx(float(event[key])):
			return false
	for key in [
		"product_price_growth_delta_percent",
		"route_efficiency_delta_percent",
		"region_damage",
		"estimated_economic_delta",
	]:
		if not is_zero_approx(float(event[key])):
			return false
	return not bool(event["monster_target_weather_influenced"])


func _normalized_event(event: Dictionary) -> Dictionary:
	return {
		"schema_version": EVENT_SCHEMA,
		"event_type": str(event["event_type"]),
		"definition_id": str(event["definition_id"]),
		"region_index": int(event["region_index"]),
		"forecast_duration_seconds": float(event["forecast_duration_seconds"]),
		"active_duration_seconds": float(event["active_duration_seconds"]),
		"fade_duration_seconds": float(event["fade_duration_seconds"]),
		"product_price_growth_delta_percent": float(event["product_price_growth_delta_percent"]),
		"route_efficiency_delta_percent": float(event["route_efficiency_delta_percent"]),
		"player_response_category": str(event["player_response_category"]),
		"monster_target_weather_influenced": bool(event["monster_target_weather_influenced"]),
		"region_damage": float(event["region_damage"]),
		"estimated_economic_delta": float(event["estimated_economic_delta"]),
	}


func _lifecycle_event(event_type: String, definition_id: String, region_index: int, forecast_duration: float, active_duration: float, fade_duration: float) -> Dictionary:
	return {
		"schema_version": EVENT_SCHEMA,
		"event_type": event_type,
		"definition_id": definition_id,
		"region_index": region_index,
		"forecast_duration_seconds": forecast_duration,
		"active_duration_seconds": active_duration,
		"fade_duration_seconds": fade_duration,
		"product_price_growth_delta_percent": 0.0,
		"route_efficiency_delta_percent": 0.0,
		"player_response_category": NOT_APPLICABLE_RESPONSE,
		"monster_target_weather_influenced": false,
		"region_damage": 0.0,
		"estimated_economic_delta": 0.0,
	}


func _normalized_regions(region_indices: Array) -> Array:
	var result: Array = []
	for value in region_indices:
		if typeof(value) != TYPE_INT:
			continue
		var region_index := int(value)
		if region_index < MIN_REGION_INDEX or region_index > MAX_REGION_INDEX or result.has(region_index):
			continue
		result.append(region_index)
	result.sort()
	return result


func _valid_duration(value: float) -> bool:
	return is_finite(value) and value >= 0.0 and value <= MAX_DURATION_SECONDS


func _session_identity_matches(session: Dictionary, definition_id: String, regions: Array) -> bool:
	return str(session.get("definition_id", "")) == definition_id and session.get("region_indices", []) == regions


func _sample_average(totals: Dictionary, samples: Dictionary, metric: String) -> float:
	var count := int(samples.get(metric, 0))
	return float(totals.get(metric, 0.0)) / float(count) if count > 0 else 0.0


func _accumulate_end_event(event: Dictionary) -> void:
	var definition_id := str(event["definition_id"])
	var region_index := int(event["region_index"])
	_accumulate_stats(_definition_stats[definition_id], event)
	var definition_regions: Dictionary = _region_stats[definition_id]
	if not definition_regions.has(region_index):
		definition_regions[region_index] = _empty_stats()
	_accumulate_stats(definition_regions[region_index], event)


func _accumulate_stats(stats: Dictionary, event: Dictionary) -> void:
	stats["event_count"] = int(stats["event_count"]) + 1
	stats["forecast_duration_total"] = float(stats["forecast_duration_total"]) + float(event["forecast_duration_seconds"])
	stats["active_duration_total"] = float(stats["active_duration_total"]) + float(event["active_duration_seconds"])
	stats["fade_duration_total"] = float(stats["fade_duration_total"]) + float(event["fade_duration_seconds"])
	stats["product_price_growth_delta_total"] = float(stats["product_price_growth_delta_total"]) + float(event["product_price_growth_delta_percent"])
	stats["route_efficiency_delta_total"] = float(stats["route_efficiency_delta_total"]) + float(event["route_efficiency_delta_percent"])
	var responses: Dictionary = stats["response_counts"]
	var response := str(event["player_response_category"])
	responses[response] = int(responses[response]) + 1
	if bool(event["monster_target_weather_influenced"]):
		stats["monster_target_weather_influenced_count"] = int(stats["monster_target_weather_influenced_count"]) + 1
	stats["region_damage_total"] = float(stats["region_damage_total"]) + float(event["region_damage"])
	stats["estimated_economic_delta_total"] = float(stats["estimated_economic_delta_total"]) + float(event["estimated_economic_delta"])


func _stats_row(definition_id: String, stats: Dictionary) -> Dictionary:
	var count := int(stats["event_count"])
	return {
		"definition_id": definition_id,
		"display_name": str(DEFINITION_NAMES[definition_id]),
		"event_count": count,
		"average_forecast_duration_seconds": _average(float(stats["forecast_duration_total"]), count),
		"average_active_duration_seconds": _average(float(stats["active_duration_total"]), count),
		"average_fade_duration_seconds": _average(float(stats["fade_duration_total"]), count),
		"average_product_price_growth_delta_percent": _average(float(stats["product_price_growth_delta_total"]), count),
		"average_route_efficiency_delta_percent": _average(float(stats["route_efficiency_delta_total"]), count),
		"player_response_counts": (stats["response_counts"] as Dictionary).duplicate(),
		"monster_target_weather_influenced_count": int(stats["monster_target_weather_influenced_count"]),
		"monster_target_weather_influenced_rate": _average(float(stats["monster_target_weather_influenced_count"]), count),
		"region_damage_total": float(stats["region_damage_total"]),
		"estimated_economic_delta_total": float(stats["estimated_economic_delta_total"]),
		"average_estimated_economic_delta": _average(float(stats["estimated_economic_delta_total"]), count),
	}


func _average(total: float, count: int) -> float:
	return total / float(count) if count > 0 else 0.0


func _completed_event_count() -> int:
	var total := 0
	for definition_id in DEFINITION_IDS:
		total += int((_definition_stats[str(definition_id)] as Dictionary)["event_count"])
	return total


func _reset_aggregates() -> void:
	_definition_stats.clear()
	_region_stats.clear()
	for definition_id in DEFINITION_IDS:
		_definition_stats[str(definition_id)] = _empty_stats()
		_region_stats[str(definition_id)] = {}


func _empty_stats() -> Dictionary:
	var responses := {}
	for category in RESPONSE_CATEGORIES:
		responses[str(category)] = 0
	return {
		"event_count": 0,
		"forecast_duration_total": 0.0,
		"active_duration_total": 0.0,
		"fade_duration_total": 0.0,
		"product_price_growth_delta_total": 0.0,
		"route_efficiency_delta_total": 0.0,
		"response_counts": responses,
		"monster_target_weather_influenced_count": 0,
		"region_damage_total": 0.0,
		"estimated_economic_delta_total": 0.0,
	}


func _has_exact_keys(value: Dictionary, expected_keys: Array) -> bool:
	if value.size() != expected_keys.size():
		return false
	for key in expected_keys:
		if not value.has(str(key)):
			return false
	return true


func _contains_private_key(value: Variant) -> bool:
	if value is Dictionary:
		for raw_key in (value as Dictionary).keys():
			var key := str(raw_key).strip_edges().to_lower()
			if not EVENT_KEYS.has(key) and _matches_private_key(key):
				return true
			if _contains_private_key((value as Dictionary)[raw_key]):
				return true
	elif value is Array:
		for item in value as Array:
			if _contains_private_key(item):
				return true
	return false


func _matches_private_key(key: String) -> bool:
	for pattern_variant in PRIVATE_KEY_PATTERNS:
		var pattern := str(pattern_variant)
		if key == pattern or key.begins_with(pattern + "_") or key.ends_with("_" + pattern) or key.contains("_" + pattern + "_"):
			return true
	return false


func _contains_private_value(value: Variant) -> bool:
	if typeof(value) == TYPE_STRING:
		var normalized := str(value).strip_edges().to_lower()
		for pattern_variant in PRIVATE_VALUE_PATTERNS:
			if normalized.contains(str(pattern_variant)):
				return true
	elif value is Dictionary:
		for nested_value in (value as Dictionary).values():
			if _contains_private_value(nested_value):
				return true
	elif value is Array:
		for nested_value in value as Array:
			if _contains_private_value(nested_value):
				return true
	return false


func _is_finite_number(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	return is_finite(float(value))


func _reject(reason: String) -> bool:
	_last_error = reason
	return false
