extends RefCounted
class_name AudioEventRegistry

const DEFAULT_MAP_PATH := "res://data/audio/audio_event_map.json"

var events: Dictionary = {}


func load_default() -> void:
	load_from_file(DEFAULT_MAP_PATH)


func load_from_file(path: String) -> void:
	events.clear()
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		events = parsed as Dictionary


func has_event(event_id: String) -> bool:
	return events.has(event_id)


func event_definition(event_id: String) -> Dictionary:
	var definition: Variant = events.get(event_id, {"mode": "silent", "category": "unknown"})
	return definition if definition is Dictionary else {"mode": "silent", "category": "unknown"}


func supported_event_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in events.keys():
		ids.append(str(key))
	ids.sort()
	return ids
