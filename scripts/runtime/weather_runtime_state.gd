extends RefCounted
class_name WeatherRuntimeState

const SCHEMA_VERSION := 2
const EVENT_SCHEMA_VERSION := 1
const PHASE_QUEUED := "queued"
const PHASE_FORECAST := "forecast"
const PHASE_ACTIVE := "active"
const PHASE_FADING := "fading"
const PHASE_ENDED := "ended"
const PUBLIC_PHASES := [PHASE_QUEUED, PHASE_FORECAST, PHASE_ACTIVE, PHASE_FADING]
const SAVE_KEYS := [
	"schema_version",
	"events",
	"queue",
	"next_generation_world_us",
	"sequence",
	"history",
	"region_history",
	"telemetry",
]
const EVENT_KEYS := [
	"event_schema_version",
	"id",
	"definition_id",
	"type",
	"region_indices",
	"districts",
	"phase",
	"source_type",
	"created_at_world_us",
	"forecast_starts_at_world_us",
	"active_starts_at_world_us",
	"active_ends_at_world_us",
	"fade_ends_at_world_us",
	"forecast_duration_world_us",
	"active_duration_world_us",
	"fade_duration_world_us",
	"lifecycle_end_recorded",
	"telemetry_end_recorded",
	"weather_damage_last_accounted_world_us",
	"weather_damage_accounted_units_by_region",
	"weather_damage_applied_units_by_region",
]
const HISTORY_KEYS := ["id", "definition_id", "region_indices", "ended_at_world_us"]
const TELEMETRY_KEYS := [
	"activated",
	"blocked_settlement",
	"deprecated_apply_weather_control_rejected",
	"dequeued",
	"ended",
	"flat_shape_failclosed_migration",
	"natural_missing_definition",
	"natural_no_region",
	"phase_active",
	"phase_ended",
	"phase_fading",
	"phase_forecast",
	"phase_queued",
	"queued_conflict",
	"region_damage_accounted",
	"region_damage_applied",
	"rejected_invalid_target",
	"rejected_max_unended",
	"scheduled_forecast",
	"scheduled_natural",
]


static func empty_save_payload() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"events": [],
		"queue": [],
		"next_generation_world_us": 90_000_000,
		"sequence": 0,
		"history": [],
		"region_history": {},
		"telemetry": {},
	}


static func duplicate_events(events: Array) -> Array:
	var result: Array = []
	for event_variant in events:
		if event_variant is Dictionary:
			result.append((event_variant as Dictionary).duplicate(true))
	return result


static func is_unended(event: Dictionary) -> bool:
	return str(event.get("phase", "")) != PHASE_ENDED


static func event_region_indices(event: Dictionary) -> Array:
	var result: Array = []
	var regions_variant: Variant = event.get("region_indices", event.get("districts", []))
	if regions_variant is Array:
		for region_variant in regions_variant:
			var region := int(region_variant)
			if region >= 0 and not result.has(region):
				result.append(region)
	return result


static func validate_event(event: Dictionary, known_definition_ids: Array) -> Dictionary:
	if not _has_only_keys(event, EVENT_KEYS):
		return {"valid": false, "reason": "event_keys_invalid"}
	if int(event.get("event_schema_version", EVENT_SCHEMA_VERSION)) != EVENT_SCHEMA_VERSION:
		return {"valid": false, "reason": "event_schema_version_invalid"}
	var definition_id := str(event.get("definition_id", event.get("type", "")))
	if definition_id.is_empty() or not known_definition_ids.has(definition_id):
		return {"valid": false, "reason": "definition_id_invalid"}
	var phase := str(event.get("phase", ""))
	if not [PHASE_QUEUED, PHASE_FORECAST, PHASE_ACTIVE, PHASE_FADING, PHASE_ENDED].has(phase):
		return {"valid": false, "reason": "phase_invalid"}
	var source_type := str(event.get("source_type", ""))
	if not ["natural", "monster", "card"].has(source_type):
		return {"valid": false, "reason": "source_type_invalid"}
	var regions := event_region_indices(event)
	if regions.is_empty():
		return {"valid": false, "reason": "region_indices_invalid"}
	for key in [
		"id",
		"created_at_world_us",
		"forecast_starts_at_world_us",
		"active_starts_at_world_us",
		"active_ends_at_world_us",
		"fade_ends_at_world_us",
		"forecast_duration_world_us",
		"active_duration_world_us",
		"fade_duration_world_us",
	]:
		if not (event.get(key) is int) or int(event.get(key)) < 0:
			return {"valid": false, "reason": "%s_invalid" % key}
	if int(event.get("active_starts_at_world_us", 0)) < int(event.get("forecast_starts_at_world_us", 0)):
		return {"valid": false, "reason": "forecast_boundary_invalid"}
	if int(event.get("active_ends_at_world_us", 0)) < int(event.get("active_starts_at_world_us", 0)):
		return {"valid": false, "reason": "active_boundary_invalid"}
	if int(event.get("fade_ends_at_world_us", 0)) < int(event.get("active_ends_at_world_us", 0)):
		return {"valid": false, "reason": "fade_boundary_invalid"}
	for optional_bool_key in ["lifecycle_end_recorded", "telemetry_end_recorded"]:
		if event.has(optional_bool_key) and not (event.get(optional_bool_key) is bool):
			return {"valid": false, "reason": "%s_invalid" % optional_bool_key}
	if event.has("weather_damage_last_accounted_world_us") and (not (event.get("weather_damage_last_accounted_world_us") is int) or int(event.get("weather_damage_last_accounted_world_us")) < 0):
		return {"valid": false, "reason": "weather_damage_last_accounted_world_us_invalid"}
	for damage_key in ["weather_damage_accounted_units_by_region", "weather_damage_applied_units_by_region"]:
		if event.has(damage_key) and not _valid_nonnegative_int_map(event.get(damage_key)):
			return {"valid": false, "reason": "%s_invalid" % damage_key}
	return {"valid": true}


static func validate_save_payload(data: Dictionary, known_definition_ids: Array) -> Dictionary:
	if not _has_only_keys(data, SAVE_KEYS) or data.keys().size() != SAVE_KEYS.size():
		return {"valid": false, "reason": "save_keys_invalid"}
	if int(data.get("schema_version", -1)) != SCHEMA_VERSION:
		return {"valid": false, "reason": "schema_version_invalid"}
	if not (data.get("events") is Array):
		return {"valid": false, "reason": "events_invalid"}
	if not (data.get("queue") is Array):
		return {"valid": false, "reason": "queue_invalid"}
	if not (data.get("next_generation_world_us") is int) or int(data.get("next_generation_world_us", -1)) < 0:
		return {"valid": false, "reason": "next_generation_world_us_invalid"}
	if not (data.get("sequence") is int) or int(data.get("sequence", -1)) < 0:
		return {"valid": false, "reason": "sequence_invalid"}
	if not (data.get("history") is Array):
		return {"valid": false, "reason": "history_invalid"}
	if not (data.get("region_history") is Dictionary):
		return {"valid": false, "reason": "region_history_invalid"}
	if not (data.get("telemetry") is Dictionary):
		return {"valid": false, "reason": "telemetry_invalid"}
	var event_ids := {}
	var queued_event_ids := {}
	for event_variant in data.get("events", []):
		if not (event_variant is Dictionary):
			return {"valid": false, "reason": "event_not_dictionary"}
		var event_validation := validate_event(event_variant as Dictionary, known_definition_ids)
		if not bool(event_validation.get("valid", false)):
			return event_validation
		var event_id := int((event_variant as Dictionary).get("id", -1))
		if event_ids.has(event_id):
			return {"valid": false, "reason": "event_id_duplicate"}
		event_ids[event_id] = true
		if str((event_variant as Dictionary).get("phase", "")) == PHASE_QUEUED:
			queued_event_ids[event_id] = true
	var queue_ids := {}
	for queue_variant in data.get("queue", []):
		if not (queue_variant is int) or int(queue_variant) < 0 or queue_ids.has(int(queue_variant)):
			return {"valid": false, "reason": "queue_entry_invalid"}
		queue_ids[int(queue_variant)] = true
	if queue_ids != queued_event_ids:
		return {"valid": false, "reason": "queue_event_mismatch"}
	for history_variant in data.get("history", []):
		if not _valid_history_entry(history_variant, known_definition_ids):
			return {"valid": false, "reason": "history_entry_invalid"}
	if not _valid_nonnegative_int_map(data.get("region_history")):
		return {"valid": false, "reason": "region_history_entry_invalid"}
	if not _valid_telemetry(data.get("telemetry")):
		return {"valid": false, "reason": "telemetry_entry_invalid"}
	return {"valid": true}


static func _has_only_keys(data: Dictionary, allowed_keys: Array) -> bool:
	for key_variant in data.keys():
		if not allowed_keys.has(str(key_variant)):
			return false
	return true


static func _valid_nonnegative_int_map(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	for key_variant in (value as Dictionary).keys():
		var key := str(key_variant)
		var entry: Variant = (value as Dictionary).get(key_variant)
		if not key.is_valid_int() or int(key) < 0 or not (entry is int) or int(entry) < 0:
			return false
	return true


static func _valid_history_entry(value: Variant, known_definition_ids: Array) -> bool:
	if not (value is Dictionary):
		return false
	var entry := value as Dictionary
	if not _has_only_keys(entry, HISTORY_KEYS) or entry.keys().size() != HISTORY_KEYS.size():
		return false
	if not (entry.get("id") is int) or int(entry.get("id")) < 0:
		return false
	if not known_definition_ids.has(str(entry.get("definition_id", ""))):
		return false
	if not (entry.get("region_indices") is Array) or event_region_indices(entry).is_empty():
		return false
	return entry.get("ended_at_world_us") is int and int(entry.get("ended_at_world_us")) >= 0


static func _valid_telemetry(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	for key_variant in (value as Dictionary).keys():
		var key := str(key_variant)
		var entry: Variant = (value as Dictionary).get(key_variant)
		if not TELEMETRY_KEYS.has(key) or not (entry is int) or int(entry) < 0:
			return false
	return true


static func public_event(event: Dictionary, now_us: int, definition: WeatherDefinition, intensity: float) -> Dictionary:
	if event.is_empty() or definition == null:
		return {}
	var phase := str(event.get("phase", PHASE_ENDED))
	return {
		"id": int(event.get("id", 0)),
		"definition_id": definition.id,
		"type": definition.id,
		"label": definition.display_name,
		"color": definition.accent_color.to_html(),
		"region_indices": event_region_indices(event),
		"districts": event_region_indices(event),
		"phase": phase,
		"source_type": str(event.get("source_type", "natural")),
		"created_at_world_us": int(event.get("created_at_world_us", 0)),
		"created_at_game_time": float(int(event.get("created_at_world_us", 0))) / 1_000_000.0,
		"forecast_remaining": _remaining_seconds(now_us, int(event.get("active_starts_at_world_us", 0))) if phase == PHASE_FORECAST else 0.0,
		"active_remaining": _remaining_seconds(now_us, int(event.get("active_ends_at_world_us", 0))) if phase == PHASE_ACTIVE else 0.0,
		"fade_remaining": _remaining_seconds(now_us, int(event.get("fade_ends_at_world_us", 0))) if phase == PHASE_FADING else 0.0,
		"forecast_starts_at_world_us": int(event.get("forecast_starts_at_world_us", 0)),
		"active_starts_at_world_us": int(event.get("active_starts_at_world_us", 0)),
		"active_ends_at_world_us": int(event.get("active_ends_at_world_us", 0)),
		"fade_ends_at_world_us": int(event.get("fade_ends_at_world_us", 0)),
		"intensity": clampf(intensity, 0.0, 1.0),
	}


static func _remaining_seconds(now_us: int, boundary_us: int) -> float:
	return maxf(0.0, float(boundary_us - now_us) / 1_000_000.0)
