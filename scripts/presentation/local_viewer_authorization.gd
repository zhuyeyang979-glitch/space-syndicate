@tool
extends Node
class_name LocalViewerAuthorization

var _world_session_state: WorldSessionState
var _authorized_viewer_index := -1
var _revision := 0
var _last_player_signature := ""


func configure(world_session_state: WorldSessionState) -> void:
	_world_session_state = world_session_state
	_refresh_from_world()


func context() -> TablePresentationViewerContext:
	_refresh_from_world()
	if _authorized_viewer_index < 0:
		return TablePresentationViewerContext.denied(_revision)
	return TablePresentationViewerContext.granted(_authorized_viewer_index, _revision)


func authorized_viewer_index() -> int:
	return context().viewer_index


func can_view_subject(viewer_index: int, subject_index: int) -> bool:
	var current := context()
	return current.authorized and current.viewer_index == viewer_index and current.can_view_subject(subject_index)


func debug_snapshot() -> Dictionary:
	return {
		"configured": _world_session_state != null,
		"authorized_viewer_index": authorized_viewer_index(),
		"revision": _revision,
		"single_local_viewer_required": true,
		"opponent_private_access": false,
	}


func _refresh_from_world() -> void:
	var next_index := -1
	var human_indices: Array[int] = []
	var signature_parts: Array[String] = []
	if _world_session_state != null:
		for index in range(_world_session_state.players.size()):
			var player: Dictionary = _world_session_state.players[index] if _world_session_state.players[index] is Dictionary else {}
			var is_ai := bool(player.get("is_ai", str(player.get("seat_type", "ai")) == "ai"))
			signature_parts.append("%d:%s:%s" % [index, str(player.get("id", index)), str(is_ai)])
			if not is_ai:
				human_indices.append(index)
	if human_indices.size() == 1:
		next_index = human_indices[0]
	var signature := "|".join(signature_parts)
	if signature != _last_player_signature or next_index != _authorized_viewer_index:
		_last_player_signature = signature
		_authorized_viewer_index = next_index
		_revision += 1
