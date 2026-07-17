@tool
extends Node
class_name CardResolutionPresentationPort

signal public_event_published(event: Dictionary)

const MAX_EVENTS := 48
const PUBLIC_KEYS := [
	"event_id", "event_kind", "resolution_id", "card_name", "phase",
	"status", "remaining_seconds", "target_kind", "district_index",
	"world_position", "accent", "public_owner_revealed",
	"public_target_revealed",
]
const SUPPORTED_EVENT_KINDS := [
	"card_resolution_phase",
	"card_counter_window",
	"card_target_check",
	"card_aftermath",
	"card_counter",
	"player_interaction",
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
	if str(event.get("event_kind", "")) not in SUPPORTED_EVENT_KINDS:
		return {"published": false, "reason": "event_kind_unsupported"}
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


func public_events_after(presentation_revision: int) -> Array:
	var result: Array = []
	for event_variant in _events:
		if not (event_variant is Dictionary):
			continue
		var event := event_variant as Dictionary
		if int(event.get("presentation_revision", 0)) > presentation_revision:
			result.append(event.duplicate(true))
	return result


func latest_public_event_revision() -> int:
	var latest := 0
	for event_variant in _events:
		if event_variant is Dictionary:
			latest = maxi(latest, int((event_variant as Dictionary).get("presentation_revision", 0)))
	return latest


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
	var owner_revealed := bool(result.get("public_owner_revealed", false))
	if owner_revealed:
		var owner_label := _public_label(source.get("public_owner_label", ""))
		if not owner_label.is_empty():
			result["public_owner_label"] = owner_label
	var target_revealed := bool(result.get("public_target_revealed", false))
	if target_revealed:
		var target_label := _public_label(source.get("target_label", ""))
		if not target_label.is_empty():
			result["target_label"] = target_label
	result["localization_key"] = _localization_key(result)
	result["public_values"] = _public_values(result)
	for forbidden in FORBIDDEN_KEYS:
		result.erase(forbidden)
	return result


func _localization_key(event: Dictionary) -> String:
	var event_kind := str(event.get("event_kind", ""))
	var status := str(event.get("status", ""))
	match event_kind:
		"card_resolution_phase":
			return {
				"enter_public_bid": "card_resolution.phase.public_bid",
				"enter_lock": "card_resolution.phase.lock",
				"all_ready_public_bid": "card_resolution.phase.all_ready_public_bid",
				"all_ready_lock": "card_resolution.phase.all_ready_lock",
				"all_ready_lock_batch": "card_resolution.phase.all_ready_lock_batch",
			}.get(status, "card_resolution.phase.updated")
		"card_counter_window":
			return "card_resolution.counter_window.opened"
		"card_target_check":
			return "card_resolution.target.valid" if status == "valid" else "card_resolution.target.invalid"
		"card_aftermath":
			return "card_resolution.aftermath.resolved" if status == "resolved" else "card_resolution.aftermath.not_resolved"
		"card_counter":
			return "card_resolution.counter.resolved"
		"player_interaction":
			return "card_resolution.player_interaction.resolved"
	return "card_resolution.public_update"


func _public_values(event: Dictionary) -> Dictionary:
	var result := {}
	var card_name := _public_label(event.get("card_name", ""))
	if not card_name.is_empty():
		result["card_name"] = card_name
	var phase := str(event.get("phase", ""))
	if phase in ["planning", "public_bid", "lock", "counter", "resolving", "idle"]:
		result["phase"] = phase
	var status := str(event.get("status", ""))
	if status in [
		"opened", "valid", "invalid", "resolved", "not_resolved",
		"enter_public_bid", "enter_lock", "all_ready_public_bid",
		"all_ready_lock", "all_ready_lock_batch",
	]:
		result["status"] = status
	if event.has("remaining_seconds"):
		result["remaining_seconds"] = maxf(0.0, float(event.get("remaining_seconds", 0.0)))
	return result


func _public_label(value: Variant) -> String:
	if not (value is String or value is StringName):
		return ""
	return str(value).strip_edges().replace("\n", " ").replace("\r", " ").left(80)


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
