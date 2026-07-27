@tool
extends Node
class_name ViewerPrivateFeedbackOwner

const MAX_MESSAGES_PER_VIEWER := 48
const SESSION_CHECKPOINT_SCHEMA_VERSION := 1
const SESSION_CHECKPOINT_KEYS := ["schema_version", "revision", "messages_by_viewer"]

var _messages_by_viewer: Dictionary = {}
var _revision := 0


func reset_state() -> void:
	_messages_by_viewer.clear()
	_revision += 1


func capture_session_checkpoint() -> Dictionary:
	var messages_by_viewer: Dictionary = {}
	for viewer_variant in _messages_by_viewer.keys():
		messages_by_viewer[str(int(viewer_variant))] = (
			_messages_by_viewer.get(viewer_variant, []) as Array
		).duplicate()
	return {
		"schema_version": SESSION_CHECKPOINT_SCHEMA_VERSION,
		"revision": _revision,
		"messages_by_viewer": messages_by_viewer,
	}


func restore_session_checkpoint(checkpoint: Dictionary) -> bool:
	if not TablePresentationPureDataPolicy.is_pure_data(checkpoint) \
			or not _has_exact_keys(checkpoint, SESSION_CHECKPOINT_KEYS) \
			or typeof(checkpoint.get("schema_version")) != TYPE_INT \
			or int(checkpoint.get("schema_version", 0)) != SESSION_CHECKPOINT_SCHEMA_VERSION \
			or typeof(checkpoint.get("revision")) != TYPE_INT \
			or int(checkpoint.get("revision", -1)) < 0 \
			or not (checkpoint.get("messages_by_viewer") is Dictionary):
		return false
	var source := checkpoint.get("messages_by_viewer", {}) as Dictionary
	var normalized: Dictionary = {}
	for viewer_key_variant in source.keys():
		if not (viewer_key_variant is String):
			return false
		var viewer_key := str(viewer_key_variant)
		var messages_variant: Variant = source.get(viewer_key_variant)
		if not viewer_key.is_valid_int() or int(viewer_key) < 0 \
				or str(int(viewer_key)) != viewer_key \
				or not (messages_variant is Array) \
				or (messages_variant as Array).size() > MAX_MESSAGES_PER_VIEWER:
			return false
		var messages: Array = []
		for message_variant in messages_variant as Array:
			if not (message_variant is String) or str(message_variant).is_empty() \
					or str(message_variant).strip_edges() != str(message_variant):
				return false
			messages.append(str(message_variant))
		normalized[int(viewer_key)] = messages
	_messages_by_viewer = normalized
	_revision = int(checkpoint.get("revision", 0))
	return true


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


func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key_variant in expected:
		if not value.has(key_variant):
			return false
	return true
