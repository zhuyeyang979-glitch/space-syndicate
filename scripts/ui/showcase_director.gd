extends Node
class_name ShowcaseDirector

const SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/visual_event_snapshot.gd")
const DEFAULT_SEQUENCE_PATH := "res://data/showcase/hearthstone_grade_sequence.json"

var sequence: Dictionary = {}
var stages: Array = []


func _ready() -> void:
	if stages.is_empty():
		load_sequence(DEFAULT_SEQUENCE_PATH)


func load_sequence(path: String = DEFAULT_SEQUENCE_PATH) -> bool:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return false
	sequence = parsed as Dictionary
	var parsed_stages: Variant = sequence.get("stages", [])
	stages = parsed_stages if parsed_stages is Array else []
	return not stages.is_empty()


func get_duration_seconds() -> float:
	return float(sequence.get("duration_seconds", 45.0))


func get_stage_ids() -> Array[String]:
	var ids: Array[String] = []
	for stage_variant in stages:
		if stage_variant is Dictionary:
			ids.append(str((stage_variant as Dictionary).get("id", "")))
	return ids


func stage_by_id(stage_id: String) -> Dictionary:
	for stage_variant in stages:
		if not (stage_variant is Dictionary):
			continue
		var stage: Dictionary = stage_variant
		if str(stage.get("id", "")) == stage_id:
			return stage.duplicate(true)
	return stages[0].duplicate(true) if not stages.is_empty() and stages[0] is Dictionary else {}


func stage_for_time(seconds: float) -> Dictionary:
	var selected: Dictionary = {}
	for stage_variant in stages:
		if not (stage_variant is Dictionary):
			continue
		var stage: Dictionary = stage_variant
		if float(stage.get("time", 0.0)) <= seconds:
			selected = stage
	return selected.duplicate(true)


func visual_events_for_stage(stage_id: String) -> Array:
	var stage := stage_by_id(stage_id)
	var events_variant: Variant = stage.get("events", [])
	var events: Array = events_variant if events_variant is Array else []
	return SNAPSHOT_SCRIPT.normalize_events(events)


func stage_snapshot(stage_id: String) -> Dictionary:
	var stage := stage_by_id(stage_id)
	var events := visual_events_for_stage(stage_id)
	return {
		"id": str(stage.get("id", "")),
		"title": str(stage.get("title", "")),
		"inspector": str(stage.get("inspector", "")),
		"events": events,
		"event_classes": SNAPSHOT_SCRIPT.event_classes(events),
		"targeting": stage.get("targeting", {}),
	}
