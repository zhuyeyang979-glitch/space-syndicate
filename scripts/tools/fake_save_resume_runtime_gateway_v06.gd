extends Node

## Focused-test double for the not-yet-landed production orchestration API.
## The application flow sees only this one typed high-level method.

var received_intents: Array[Dictionary] = []
var reentrant_receipt: SaveResumeReceiptV06
var reentrant_flow_path: NodePath
var trigger_reentrant_save := false
var _responses: Dictionary = {}


func set_response(operation: StringName, response: Dictionary) -> void:
	_responses[String(operation)] = response.duplicate(true)


func submit_save_resume_intent(intent: SaveResumeIntentV06) -> Dictionary:
	if intent == null or not intent.is_valid():
		return {}
	received_intents.append(intent.to_dictionary())
	if trigger_reentrant_save:
		trigger_reentrant_save = false
		var flow := get_node_or_null(reentrant_flow_path) as SaveResumeApplicationFlowController \
			if not reentrant_flow_path.is_empty() else null
		if flow != null:
			reentrant_receipt = flow.request_save_game(&"pause_menu")
	var template: Dictionary = (_responses.get(String(intent.operation), {}) as Dictionary).duplicate(true)
	return {
		"schema_version": SaveResumeReceiptV06.SCHEMA_VERSION,
		"request_id": intent.request_id,
		"operation": String(intent.operation),
		"slot_id": String(intent.slot_id),
		"accepted": bool(template.get("accepted", false)),
		"applied": bool(template.get("applied", false)),
		"reason_code": str(template.get("reason_code", "save_resume_rejected")),
		"slot_state": str(template.get("slot_state", "unavailable")),
		"can_save": bool(template.get("can_save", false)),
		"can_resume": bool(template.get("can_resume", false)),
		"backup_available": bool(template.get("backup_available", false)),
		"saved_at_unix": int(template.get("saved_at_unix", 0)),
		"playtime_seconds": int(template.get("playtime_seconds", 0)),
		"seat_count": int(template.get("seat_count", 0)),
		"ruleset_id": str(template.get("ruleset_id", "")),
		"mission_title": str(template.get("mission_title", "")),
		"session_state": str(template.get("session_state", "")),
	}
