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


func get_scenario_ids() -> Array[String]:
	var ids: Array[String] = []
	var segments_variant: Variant = sequence.get("scenario_segments", [])
	var segments: Array = segments_variant if segments_variant is Array else []
	for segment_variant in segments:
		if segment_variant is Dictionary:
			_append_unique_string(ids, str((segment_variant as Dictionary).get("id", "")))
	if ids.is_empty():
		var scenario_variant: Variant = sequence.get("scenarios", [])
		var scenarios: Array = scenario_variant if scenario_variant is Array else []
		for scenario_id_variant in scenarios:
			_append_unique_string(ids, str(scenario_id_variant))
	return ids


func stage_ids_for_scenario(scenario_id: String) -> Array[String]:
	var ids: Array[String] = []
	for stage_variant in stages:
		if not (stage_variant is Dictionary):
			continue
		var stage: Dictionary = stage_variant
		if _stage_belongs_to_scenario(stage, scenario_id):
			_append_unique_string(ids, str(stage.get("id", "")))
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


func scenario_segment(scenario_id: String) -> Dictionary:
	var segments_variant: Variant = sequence.get("scenario_segments", [])
	var segments: Array = segments_variant if segments_variant is Array else []
	for segment_variant in segments:
		if not (segment_variant is Dictionary):
			continue
		var segment: Dictionary = segment_variant
		if str(segment.get("id", "")) == scenario_id:
			return segment.duplicate(true)
	return {}


func scenario_snapshot(scenario_id: String) -> Dictionary:
	var segment := scenario_segment(scenario_id)
	var stage_ids_variant: Variant = segment.get("required_stage_ids", stage_ids_for_scenario(scenario_id))
	var stage_ids: Array = stage_ids_variant if stage_ids_variant is Array else stage_ids_for_scenario(scenario_id)
	var events: Array = []
	var audio_hooks: Array[String] = []
	for stage_id_variant in stage_ids:
		var stage_id := str(stage_id_variant)
		events.append_array(visual_events_for_stage(stage_id))
		var stage := stage_by_id(stage_id)
		var hooks_variant: Variant = stage.get("audio_hooks", [])
		var hooks: Array = hooks_variant if hooks_variant is Array else []
		for hook_variant in hooks:
			_append_unique_string(audio_hooks, str(hook_variant))
	return {
		"id": scenario_id,
		"label": str(segment.get("label", scenario_id)),
		"stage_ids": stage_ids.duplicate(true),
		"events": events,
		"event_classes": SNAPSHOT_SCRIPT.event_classes(events),
		"audio_hooks": audio_hooks,
		"required_event_classes": segment.get("required_event_classes", []),
		"required_audio_hooks": segment.get("required_audio_hooks", []),
		"showcase_goal": str(segment.get("showcase_goal", "")),
	}


func stage_snapshot(stage_id: String) -> Dictionary:
	var stage := stage_by_id(stage_id)
	var events := visual_events_for_stage(stage_id)
	return {
		"id": str(stage.get("id", "")),
		"scenario_ids": stage.get("scenario_ids", []),
		"title": str(stage.get("title", "")),
		"inspector": str(stage.get("inspector", "")),
		"events": events,
		"event_classes": SNAPSHOT_SCRIPT.event_classes(events),
		"audio_hooks": stage.get("audio_hooks", []),
		"targeting": stage.get("targeting", {}),
	}


func _stage_belongs_to_scenario(stage: Dictionary, scenario_id: String) -> bool:
	var scenario_ids_variant: Variant = stage.get("scenario_ids", [])
	var scenario_ids: Array = scenario_ids_variant if scenario_ids_variant is Array else []
	for scenario_id_variant in scenario_ids:
		if str(scenario_id_variant) == scenario_id:
			return true
	return false


func _fallback_stage_for_scenario(scenario_id: String) -> Dictionary:
	var ids := stage_ids_for_scenario(scenario_id)
	if ids.is_empty():
		return stage_by_id("board_idle")
	return stage_by_id(str(ids[0]))


func _append_unique_string(target: Array[String], value: String) -> void:
	if value.strip_edges() == "":
		return
	if not target.has(value):
		target.append(value)
