extends Node
class_name AudioEventBus

signal audio_event_emitted(event_id: String, payload: Dictionary)
signal canonical_audio_event_emitted(canonical_id: String, event: Dictionary)

const REGISTRY_SCRIPT := preload("res://scripts/audio/audio_event_registry.gd")

var registry: Variant = REGISTRY_SCRIPT.new()
var emitted_events: Array[Dictionary] = []
var silent_mode := true
var _redacted_path_value_count := 0


func _ready() -> void:
	_ensure_registry_loaded()


func emit_audio_event(event_id: String, payload: Dictionary = {}) -> Dictionary:
	_ensure_registry_loaded()
	var definition: Dictionary = registry.call("event_definition", event_id)
	var canonical_id := str(definition.get("canonical_id", event_id.strip_edges()))
	var record := {
		"id": event_id.strip_edges(),
		"canonical_id": canonical_id,
		"legacy_alias": bool(definition.get("legacy_alias", false)),
		"payload": _sanitize_public_payload(payload),
		"mode": str(definition.get("mode", "silent")),
		"category": str(definition.get("category", "unknown")),
		"asset_key": str(definition.get("asset_key", "")),
		"volume_db": float(definition.get("volume_db", 0.0)),
		"loop": bool(definition.get("loop", false)),
	}
	emitted_events.append(record)
	audio_event_emitted.emit(event_id.strip_edges(), record.duplicate(true))
	canonical_audio_event_emitted.emit(canonical_id, record.duplicate(true))
	return record.duplicate(true)


func clear_events() -> void:
	emitted_events.clear()


func last_event_id() -> String:
	if emitted_events.is_empty():
		return ""
	return str(emitted_events.back().get("id", ""))


func last_canonical_event_id() -> String:
	if emitted_events.is_empty():
		return ""
	return str(emitted_events.back().get("canonical_id", ""))


func debug_snapshot() -> Dictionary:
	return {
		"emitted_event_count": emitted_events.size(),
		"last_event_id": last_event_id(),
		"last_canonical_event_id": last_canonical_event_id(),
		"silent_mode": silent_mode,
		"commercial_contract_ready": bool(registry.call("commercial_contract_ready")),
		"contains_resource_paths": JSON.stringify(emitted_events).contains("res://"),
		"redacted_path_value_count": _redacted_path_value_count,
		"rules_rng_draw_count": 0,
	}


func _ensure_registry_loaded() -> void:
	var registry_events: Dictionary = registry.get("events")
	if registry_events.is_empty():
		registry.call("load_default")
	silent_mode = not bool(registry.call("commercial_contract_ready"))


func _sanitize_public_payload(value: Variant) -> Variant:
	if value is Dictionary:
		var sanitized: Dictionary = {}
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant)
			var normalized_key := key.to_lower()
			if normalized_key == "path" or normalized_key.ends_with("_path") \
					or normalized_key.contains("resource_path") or normalized_key.contains("vendor_path"):
				_redacted_path_value_count += 1
				continue
			sanitized[key_variant] = _sanitize_public_payload((value as Dictionary).get(key_variant))
		return sanitized
	if value is Array:
		var sanitized_array: Array = []
		for child_variant in value as Array:
			sanitized_array.append(_sanitize_public_payload(child_variant))
		return sanitized_array
	if value is String:
		var text := str(value)
		if text.begins_with("res://") or text.begins_with("user://") \
				or text.begins_with("file://") or text.begins_with("/") \
				or (text.length() >= 3 and text[1] == ":" and text[2] in ["/", "\\"]) \
				or text.contains("assets/third_party") or text.contains("assets\\third_party"):
			_redacted_path_value_count += 1
			return "[redacted]"
	return value
