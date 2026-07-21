@tool
extends Node
class_name PlayerIdentityAuthorizationBoundary

signal authorization_completed(receipt: PlayerIdentityAuthorizationReceipt)

@export var local_viewer_authorization_path: NodePath
@export var world_session_state_path: NodePath
@export var game_session_path: NodePath

var _request_journal: Dictionary = {}
var _journal_session_key := ""
var _submission_count := 0
var _authorized_count := 0
var _rejection_count := 0
var _replay_count := 0
var _collision_count := 0
var _context_issue_count := 0


func build_request(request_id: String, source_surface: StringName, request_revision: int) -> PlayerIdentityActionRequest:
	var request := PlayerIdentityActionRequest.new()
	request.request_id = request_id
	request.source_surface = source_surface
	request.request_revision = request_revision
	var authorization := _authorization()
	var session := _game_session()
	if authorization != null:
		var context := authorization.context()
		request.viewer_index = context.viewer_index
		request.authorized_player_index = context.viewer_index
		request.authorization_revision = context.authorization_revision
	if session != null:
		var summary := session.session_summary()
		request.session_id = str(summary.get("session_id", ""))
		request.session_revision = session.session_start_revision()
	return request


func authorize_request(request: PlayerIdentityActionRequest) -> PlayerIdentityAuthorizationReceipt:
	_submission_count += 1
	if request == null:
		return _complete(_receipt(null, false, "request_missing"))
	var validation := request.validation_report()
	if not bool(validation.get("valid", false)):
		return _complete(_receipt(request, false, str(validation.get("reason_code", "request_invalid"))))
	var dependencies := _dependencies_report()
	if not bool(dependencies.get("ready", false)):
		return _complete(_receipt(request, false, str(dependencies.get("reason_code", "authority_dependency_missing"))))
	var authorization := _authorization()
	var context := authorization.context()
	if not context.authorized:
		return _complete(_receipt(request, false, "spectator_private_mismatch"))
	if request.viewer_index != context.viewer_index:
		return _complete(_receipt(request, false, "wrong_viewer"))
	if request.authorized_player_index != context.viewer_index:
		return _complete(_receipt(request, false, "forged_player_index"))
	if request.authorization_revision != context.authorization_revision:
		return _complete(_receipt(request, false, "authorization_revision_stale"))
	var public_players: Array = _world().public_intel_projection().get("players", [])
	if request.authorized_player_index >= public_players.size():
		return _complete(_receipt(request, false, "authorized_player_missing"))
	var public_player: Dictionary = public_players[request.authorized_player_index] if public_players[request.authorized_player_index] is Dictionary else {}
	if int(public_player.get("player_index", -1)) != request.authorized_player_index:
		return _complete(_receipt(request, false, "public_authority_mismatch"))
	var session := _game_session()
	var session_summary := session.session_summary()
	if str(session_summary.get("session_state", "")) not in [GameSessionRuntimeController.STATE_RUNNING, GameSessionRuntimeController.STATE_PAUSED]:
		return _complete(_receipt(request, false, "session_not_actionable"))
	if request.session_id != str(session_summary.get("session_id", "")):
		return _complete(_receipt(request, false, "wrong_session"))
	if request.session_revision != session.session_start_revision():
		return _complete(_receipt(request, false, "session_revision_stale"))
	_sync_journal_session(request.session_id, request.session_revision)
	var fingerprint := request.fingerprint()
	if _request_journal.has(request.request_id):
		var prior_fingerprint := str(_request_journal.get(request.request_id, ""))
		if prior_fingerprint != fingerprint:
			_collision_count += 1
			var collision := _receipt(request, false, "request_id_collision")
			collision.request_id_collision = true
			return _complete(collision)
		_replay_count += 1
		var replay := _receipt(request, false, "request_replay")
		replay.idempotent_replay = true
		return _complete(replay)
	_request_journal[request.request_id] = fingerprint
	return _complete(_receipt(request, true, "authorized"))


func current_actor_context(source_surface: StringName = &"game_screen") -> GameplayActorAuthorizationContext:
	_context_issue_count += 1
	if not PlayerIdentityActionRequest.SOURCE_SURFACES.has(source_surface):
		return GameplayActorAuthorizationContext.denied("source_surface_invalid", _context_issue_count, source_surface)
	var dependencies := _dependencies_report()
	if not bool(dependencies.get("ready", false)):
		return GameplayActorAuthorizationContext.denied(str(dependencies.get("reason_code", "authority_dependency_missing")), _context_issue_count, source_surface)
	var viewer_context := _authorization().context()
	if not viewer_context.authorized or viewer_context.viewer_index < 0:
		return GameplayActorAuthorizationContext.denied("spectator_private_mismatch", _context_issue_count, source_surface)
	var public_players: Array = _world().public_intel_projection().get("players", [])
	if viewer_context.viewer_index >= public_players.size():
		return GameplayActorAuthorizationContext.denied("authorized_player_missing", _context_issue_count, source_surface)
	var public_player: Dictionary = public_players[viewer_context.viewer_index] if public_players[viewer_context.viewer_index] is Dictionary else {}
	if int(public_player.get("player_index", -1)) != viewer_context.viewer_index:
		return GameplayActorAuthorizationContext.denied("public_authority_mismatch", _context_issue_count, source_surface)
	var summary := _game_session().session_summary()
	if str(summary.get("session_state", "")) not in [GameSessionRuntimeController.STATE_RUNNING, GameSessionRuntimeController.STATE_PAUSED]:
		return GameplayActorAuthorizationContext.denied("session_not_actionable", _context_issue_count, source_surface)
	var context := GameplayActorAuthorizationContext.new()
	context.request_id = "actor-context:%s:%d" % [str(summary.get("session_id", "")), _context_issue_count]
	context.authorized = true
	context.reason_code = "authorized"
	context.viewer_index = viewer_context.viewer_index
	context.authorized_actor_player_index = viewer_context.viewer_index
	context.authorization_revision = viewer_context.authorization_revision
	context.session_id = str(summary.get("session_id", ""))
	context.session_revision = _game_session().session_start_revision()
	context.source_surface = source_surface
	context.issued_at_operation_revision = _context_issue_count
	return context if context.is_valid() else GameplayActorAuthorizationContext.denied("actor_context_invalid", _context_issue_count, source_surface)


func authorize_actor_index(requested_actor_player_index: int, source_surface: StringName = &"game_screen") -> GameplayActorAuthorizationContext:
	var context := current_actor_context(source_surface)
	if not context.is_valid():
		return context
	if requested_actor_player_index != context.authorized_actor_player_index:
		return GameplayActorAuthorizationContext.denied("actor_authority_mismatch", context.issued_at_operation_revision, source_surface)
	return GameplayActorAuthorizationContext.from_dictionary(context.to_dictionary())


func public_player_exists(player_index: int) -> bool:
	if _world() == null or player_index < 0:
		return false
	var public_players: Array = _world().public_intel_projection().get("players", [])
	if player_index >= public_players.size() or not (public_players[player_index] is Dictionary):
		return false
	return int((public_players[player_index] as Dictionary).get("player_index", -1)) == player_index


func public_player_is_active(player_index: int) -> bool:
	if _world() == null or player_index < 0:
		return false
	var public_players: Array = _world().public_intel_projection().get("players", [])
	if player_index >= public_players.size() or not (public_players[player_index] is Dictionary):
		return false
	var player := public_players[player_index] as Dictionary
	return int(player.get("player_index", -1)) == player_index and not bool(player.get("eliminated", false))


func public_district_exists(district_index: int) -> bool:
	if _world() == null or district_index < 0:
		return false
	var public_regions: Array = _world().public_intel_projection().get("regions", [])
	if district_index >= public_regions.size() or not (public_regions[district_index] is Dictionary):
		return false
	return int((public_regions[district_index] as Dictionary).get("district_index", -1)) == district_index


func authorized_player_hand_slot_exists(viewer_index: int, slot_index: int) -> bool:
	if _world() == null or viewer_index < 0 or viewer_index >= _world().players.size() or slot_index < 0:
		return false
	var player: Dictionary = _world().players[viewer_index] if _world().players[viewer_index] is Dictionary else {}
	var slots: Array = player.get("slots", []) if player.get("slots", []) is Array else []
	return slot_index < slots.size() and slots[slot_index] is Dictionary


func debug_snapshot() -> Dictionary:
	return {
		"boundary_id": "player_identity_authorization_v1",
		"submission_count": _submission_count,
		"authorized_count": _authorized_count,
		"rejection_count": _rejection_count,
		"replay_count": _replay_count,
		"collision_count": _collision_count,
		"context_issue_count": _context_issue_count,
		"journal_size": _request_journal.size(),
		"journal_session_key": _journal_session_key,
		"journal_eviction_enabled": false,
		"scene_owned": true,
		"typed_requests": true,
		"viewer_authority": "LocalViewerAuthorization",
		"actor_authority": "LocalViewerAuthorization+GameSessionRuntimeController+WorldSessionState",
		"session_authority": "GameSessionRuntimeController",
		"world_authority": "WorldSessionState.public_intel_projection",
		"infers_actor_from_ui": false,
		"owns_gameplay_state": false,
		"references_main": false,
	}


func _dependencies_report() -> Dictionary:
	if _authorization() == null:
		return {"ready": false, "reason_code": "viewer_authority_missing"}
	if _world() == null:
		return {"ready": false, "reason_code": "world_authority_missing"}
	if _game_session() == null:
		return {"ready": false, "reason_code": "session_authority_missing"}
	return {"ready": true, "reason_code": ""}


func _sync_journal_session(session_id: String, session_revision: int) -> void:
	var session_key := "%s:%d" % [session_id, session_revision]
	if _journal_session_key == session_key:
		return
	_request_journal.clear()
	_journal_session_key = session_key


func _receipt(request: PlayerIdentityActionRequest, authorized: bool, reason_code: String) -> PlayerIdentityAuthorizationReceipt:
	var receipt := PlayerIdentityAuthorizationReceipt.new()
	if request != null:
		receipt.request_id = request.request_id
		receipt.viewer_index = request.viewer_index
		receipt.authorized_player_index = request.authorized_player_index
		receipt.authorization_revision = request.authorization_revision
		receipt.session_id = request.session_id
		receipt.session_revision = request.session_revision
		receipt.source_surface = request.source_surface
		receipt.request_revision = request.request_revision
	receipt.authorized = authorized
	receipt.reason_code = reason_code
	return receipt


func _complete(receipt: PlayerIdentityAuthorizationReceipt) -> PlayerIdentityAuthorizationReceipt:
	if receipt.authorized:
		_authorized_count += 1
	else:
		_rejection_count += 1
	authorization_completed.emit(receipt)
	return receipt


func _authorization() -> LocalViewerAuthorization:
	return get_node_or_null(local_viewer_authorization_path) as LocalViewerAuthorization


func _world() -> WorldSessionState:
	return get_node_or_null(world_session_state_path) as WorldSessionState


func _game_session() -> GameSessionRuntimeController:
	return get_node_or_null(game_session_path) as GameSessionRuntimeController
