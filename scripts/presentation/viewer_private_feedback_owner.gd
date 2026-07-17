@tool
extends Node
class_name ViewerPrivateFeedbackOwner

const MAX_MESSAGES_PER_VIEWER := 48

var _messages_by_viewer: Dictionary = {}
var _revision := 0


func reset_state() -> void:
	_messages_by_viewer.clear()
	_revision += 1


func append_for_viewer(viewer_index: int, message: String) -> Dictionary:
	var normalized := message.strip_edges()
	if viewer_index < 0 or normalized.is_empty():
		return {"applied": false, "reason_code": "viewer_private_feedback_invalid"}
	var messages: Array = _messages_by_viewer.get(viewer_index, [])
	messages.append(normalized)
	while messages.size() > MAX_MESSAGES_PER_VIEWER:
		messages.pop_front()
	_messages_by_viewer[viewer_index] = messages
	_revision += 1
	return {"applied": true, "viewer_index": viewer_index, "revision": _revision}


func recent_for_viewer(viewer_index: int, limit := 6) -> Array:
	if viewer_index < 0:
		return []
	var messages: Array = _messages_by_viewer.get(viewer_index, [])
	var start := maxi(0, messages.size() - maxi(0, limit))
	return messages.slice(start).duplicate()


func debug_snapshot() -> Dictionary:
	var counts: Dictionary = {}
	for viewer_variant in _messages_by_viewer.keys():
		counts[str(int(viewer_variant))] = (_messages_by_viewer.get(viewer_variant, []) as Array).size()
	return {
		"revision": _revision,
		"message_counts_by_viewer": counts,
		"visibility_scope": "viewer_private",
		"public_log_writer": false,
		"references_main": false,
	}
