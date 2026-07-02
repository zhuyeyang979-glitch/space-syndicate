extends RefCounted
class_name VisualEventQueue

const SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/visual_event_snapshot.gd")
const MAX_EVENT_COUNT := 32

var reduced_motion := false
var _events: Array = []


func enqueue_event(event_data: Dictionary) -> void:
	var normalized: Dictionary = SNAPSHOT_SCRIPT.normalize_event(event_data)
	normalized["reduced_motion"] = reduced_motion or bool(normalized.get("reduced_motion", false))
	_events.append(normalized)
	while _events.size() > MAX_EVENT_COUNT:
		_events.pop_front()


func enqueue_many(events: Array) -> void:
	for event_variant in events:
		if event_variant is Dictionary:
			enqueue_event(event_variant as Dictionary)


func set_events(events: Array) -> void:
	_events.clear()
	enqueue_many(events)


func clear() -> void:
	_events.clear()


func get_events() -> Array:
	return _events.duplicate(true)


func to_snapshot() -> Dictionary:
	return {
		"reduced_motion": reduced_motion,
		"max_events": MAX_EVENT_COUNT,
		"events": get_events(),
		"event_classes": SNAPSHOT_SCRIPT.event_classes(_events),
	}


func active_count() -> int:
	return _events.size()
