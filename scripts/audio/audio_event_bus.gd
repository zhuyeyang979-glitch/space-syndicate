extends Node
class_name AudioEventBus

signal audio_event_emitted(event_id: String, payload: Dictionary)

const REGISTRY_SCRIPT := preload("res://scripts/audio/audio_event_registry.gd")

var registry: Variant = REGISTRY_SCRIPT.new()
var emitted_events: Array[Dictionary] = []
var silent_mode := true


func _ready() -> void:
	var registry_events: Dictionary = registry.get("events")
	if registry_events.is_empty():
		registry.call("load_default")


func emit_audio_event(event_id: String, payload: Dictionary = {}) -> void:
	var registry_events: Dictionary = registry.get("events")
	if registry_events.is_empty():
		registry.call("load_default")
	var definition: Dictionary = registry.call("event_definition", event_id)
	var record := {
		"id": event_id,
		"payload": payload.duplicate(true),
		"mode": str(definition.get("mode", "silent")),
		"category": str(definition.get("category", "unknown")),
	}
	emitted_events.append(record)
	audio_event_emitted.emit(event_id, record)


func clear_events() -> void:
	emitted_events.clear()


func last_event_id() -> String:
	if emitted_events.is_empty():
		return ""
	return str(emitted_events.back().get("id", ""))
