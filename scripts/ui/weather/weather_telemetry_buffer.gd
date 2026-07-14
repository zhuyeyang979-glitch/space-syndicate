extends RefCounted
class_name WeatherTelemetryBuffer

const INPUT_SCHEMA := "weather_telemetry_event.v1"
const BUFFER_SCHEMA := "weather_telemetry_buffer.v1"
const MAX_CAPACITY := 256

const EVENT_TYPES := [
	"forecast_rendered",
	"overlay_rendered",
	"overlay_toggled",
	"detail_opened",
	"region_jump_requested",
	"region_jump_completed",
	"motion_mode_applied",
]
const SURFACES := [
	"forecast_strip",
	"map_overlay",
	"bench",
	"region_detail",
	"economy_dashboard",
	"route_detail",
	"notification",
]
const DEFINITION_IDS := ["", "ion_storm", "gravity_tide", "spore_season", "crystal_dust_storm", "deep_freeze", "solar_flare"]
const PHASES := ["clear", "queued", "forecast", "active", "fading"]
const MOTION_MODES := ["full", "reduced", "off"]
const INPUT_KINDS := ["none", "pointer", "keyboard"]
const RESULTS := ["shown", "accepted", "rejected", "ignored"]

const INPUT_KEYS := [
	"schema_version",
	"event_type",
	"world_effective_us",
	"surface",
	"definition_id",
	"phase",
	"region_index",
	"source_revision",
	"motion_mode",
	"input_kind",
	"result",
]
const STORED_KEYS := [
	"schema_version",
	"sequence",
	"event_type",
	"world_effective_us",
	"surface",
	"definition_id",
	"phase",
	"region_index",
	"source_revision",
	"motion_mode",
	"input_kind",
	"result",
]
const PRIVATE_KEY_TOKENS := ["source", "card_id", "player", "owner", "cash", "hand", "discard", "ai", "save", "camera", "text", "message"]
const ALLOWED_SOURCE_KEYS := ["source_revision"]

var _capacity: int
var _events: Array[Dictionary] = []
var _next_sequence := 1
var _dropped_count := 0
var _rejected_count := 0
var _last_error := ""


func _init(capacity: int = MAX_CAPACITY) -> void:
	_capacity = clampi(capacity, 1, MAX_CAPACITY)


func record_event(event: Dictionary) -> bool:
	_last_error = ""
	if not _validate_input(event):
		_rejected_count += 1
		return false
	var stored := {
		"schema_version": INPUT_SCHEMA,
		"sequence": _next_sequence,
		"event_type": event["event_type"],
		"world_effective_us": event["world_effective_us"],
		"surface": event["surface"],
		"definition_id": event["definition_id"],
		"phase": event["phase"],
		"region_index": event["region_index"],
		"source_revision": event["source_revision"],
		"motion_mode": event["motion_mode"],
		"input_kind": event["input_kind"],
		"result": event["result"],
	}
	_next_sequence += 1
	if _events.size() == _capacity:
		_events.pop_front()
		_dropped_count += 1
	_events.append(stored)
	return true


func snapshot() -> Dictionary:
	return {
		"schema_version": BUFFER_SCHEMA,
		"capacity": _capacity,
		"count": _events.size(),
		"dropped_count": _dropped_count,
		"rejected_count": _rejected_count,
		"events": _events.duplicate(true),
	}


func clear() -> void:
	_events.clear()
	_dropped_count = 0
	_rejected_count = 0
	_last_error = ""


func get_last_error() -> String:
	return _last_error


func input_field_schema() -> Dictionary:
	return {"event": INPUT_KEYS.duplicate(), "stored_event": STORED_KEYS.duplicate()}


func _validate_input(event: Dictionary) -> bool:
	if _contains_private_key(event):
		return _reject("private_key")
	if not _has_exact_keys(event, INPUT_KEYS):
		return _reject("event_keys")
	if event["schema_version"] != INPUT_SCHEMA:
		return _reject("schema_version")
	if typeof(event["event_type"]) != TYPE_STRING or not EVENT_TYPES.has(event["event_type"]):
		return _reject("event_type")
	if typeof(event["surface"]) != TYPE_STRING or not SURFACES.has(event["surface"]):
		return _reject("surface")
	if typeof(event["definition_id"]) != TYPE_STRING or not DEFINITION_IDS.has(event["definition_id"]):
		return _reject("definition_id")
	if typeof(event["phase"]) != TYPE_STRING or not PHASES.has(event["phase"]):
		return _reject("phase")
	if typeof(event["world_effective_us"]) != TYPE_INT or int(event["world_effective_us"]) < 0:
		return _reject("world_effective_us")
	if typeof(event["region_index"]) != TYPE_INT or int(event["region_index"]) < -1:
		return _reject("region_index")
	if typeof(event["source_revision"]) != TYPE_INT or int(event["source_revision"]) < 0:
		return _reject("source_revision")
	if typeof(event["motion_mode"]) != TYPE_STRING or not MOTION_MODES.has(event["motion_mode"]):
		return _reject("motion_mode")
	if typeof(event["input_kind"]) != TYPE_STRING or not INPUT_KINDS.has(event["input_kind"]):
		return _reject("input_kind")
	if typeof(event["result"]) != TYPE_STRING or not RESULTS.has(event["result"]):
		return _reject("result")
	if event["phase"] == "clear" and event["definition_id"] != "":
		return _reject("clear_definition")
	if event["phase"] != "clear" and event["definition_id"] == "":
		return _reject("weather_definition")
	return true


func _contains_private_key(value: Variant) -> bool:
	if typeof(value) == TYPE_DICTIONARY:
		for raw_key: Variant in (value as Dictionary).keys():
			var key := str(raw_key).to_lower()
			if not ALLOWED_SOURCE_KEYS.has(key) and _key_has_private_token(key):
				return true
			if _contains_private_key((value as Dictionary)[raw_key]):
				return true
	elif typeof(value) == TYPE_ARRAY:
		for item: Variant in value as Array:
			if _contains_private_key(item):
				return true
	return false


func _key_has_private_token(key: String) -> bool:
	for token: String in PRIVATE_KEY_TOKENS:
		if key == token or key.begins_with(token + "_") or key.ends_with("_" + token) or key.contains("_" + token + "_"):
			return true
	return false


func _has_exact_keys(value: Dictionary, expected_keys: Array) -> bool:
	if value.size() != expected_keys.size():
		return false
	for key: String in expected_keys:
		if not value.has(key):
			return false
	return true


func _reject(reason: String) -> bool:
	_last_error = reason
	return false
