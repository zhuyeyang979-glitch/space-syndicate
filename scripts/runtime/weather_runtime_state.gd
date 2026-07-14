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
	return {"valid": true}


static func validate_save_payload(data: Dictionary, known_definition_ids: Array) -> Dictionary:
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
	for event_variant in data.get("events", []):
		if not (event_variant is Dictionary):
			return {"valid": false, "reason": "event_not_dictionary"}
		var event_validation := validate_event(event_variant as Dictionary, known_definition_ids)
		if not bool(event_validation.get("valid", false)):
			return event_validation
	return {"valid": true}


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
