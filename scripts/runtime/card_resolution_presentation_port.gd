@tool
extends Node
class_name CardResolutionPresentationPort

signal public_event_published(event: Dictionary)

const MAX_EVENTS := 48
const PUBLIC_KEYS := [
	"event_id", "event_kind", "resolution_id", "card_name", "phase",
	"status", "remaining_seconds", "target_kind", "target_label",
	"summary", "aftermath_clue", "district_index", "world_position",
	"accent", "public_owner_revealed", "public_owner_label",
]
const FORBIDDEN_KEYS := [
	"player_index", "actor_player_index", "slot_index", "hand", "slots",
	"discard", "cash", "true_owner", "hidden_owner", "owner_truth",
	"target_player", "target_slot", "private_target", "hidden_owner_id",
	"ai_plan", "ai_private_plan", "ai_reason", "ai_utility_score", "route_plan_score",
	"pressure_bucket", "decision_samples", "learning_bonus",
]

var _events: Array = []
var _event_ids: Dictionary = {}
var _overlay_state := {"visible": false, "phase": "idle", "resolution_id": -1}
var _revision := 0


func reset_state() -> void:
	_events.clear()
	_event_ids.clear()
	_overlay_state = {"visible": false, "phase": "idle", "resolution_id": -1}
	_revision += 1


func publish_public_event(source: Dictionary) -> Dictionary:
	var event := _sanitize(source)
	var event_id := str(event.get("event_id", "")).strip_edges()
	if event_id.is_empty():
		return {"published": false, "reason": "event_id_missing"}
	if _event_ids.has(event_id):
		return {"published": true, "reason": "already_published", "event": (_event_ids[event_id] as Dictionary).duplicate(true)}
	_revision += 1
	event["presentation_revision"] = _revision
	_events.append(event)
	_event_ids[event_id] = event
	while _events.size() > MAX_EVENTS:
		var removed: Dictionary = _events.pop_front()
		_event_ids.erase(str(removed.get("event_id", "")))
	public_event_published.emit(event.duplicate(true))
	return {"published": true, "reason": "published", "event": event.duplicate(true)}


func set_overlay_state(source: Dictionary) -> Dictionary:
	_overlay_state = {
		"visible": bool(source.get("visible", false)),
		"phase": str(source.get("phase", "idle")),
		"resolution_id": int(source.get("resolution_id", -1)),
		"remaining_seconds": maxf(0.0, float(source.get("remaining_seconds", 0.0))),
		"card_name": str(source.get("card_name", "")),
	}
	_revision += 1
	return public_snapshot()


func public_snapshot() -> Dictionary:
	return {
		"schema_version": 1,
		"revision": _revision,
		"overlay": _overlay_state.duplicate(true),
		"events": _events.duplicate(true),
	}


func debug_snapshot() -> Dictionary:
	return {
		"port_ready": true,
		"public_event_count": _events.size(),
		"overlay_visible": bool(_overlay_state.get("visible", false)),
		"private_payload_exposed": false,
		"owns_gameplay_state": false,
	}


func _sanitize(source: Dictionary) -> Dictionary:
	var result := {}
	for key in PUBLIC_KEYS:
		if source.has(key):
			result[key] = _sanitize_value(source[key])
	for forbidden in FORBIDDEN_KEYS:
		result.erase(forbidden)
	return result


func _sanitize_value(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant)
			if key not in FORBIDDEN_KEYS:
				result[key] = _sanitize_value((value as Dictionary)[key_variant])
		return result
	if value is Array:
		var result: Array = []
		for item in value as Array:
			result.append(_sanitize_value(item))
		return result
	return value
