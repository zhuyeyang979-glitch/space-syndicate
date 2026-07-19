@tool
extends Node
class_name PlayerIdentityAuthorizationBoundary

signal authorization_completed(receipt: PlayerIdentityAuthorizationReceipt)

const JOURNAL_LIMIT := 256

@export var local_viewer_authorization_path: NodePath
@export var world_session_state_path: NodePath
@export var game_session_path: NodePath

var _request_journal: Dictionary = {}
var _request_order: Array[String] = []
var _submission_count := 0
var _authorized_count := 0
var _rejection_count := 0
var _replay_count := 0
var _collision_count := 0


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
	_remember_request(request.request_id, fingerprint)
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
	return _complete(_receipt(request, true, "authorized"))


func debug_snapshot() -> Dictionary:
	return {
		"boundary_id": "player_identity_authorization_v1",
		"submission_count": _submission_count,
		"authorized_count": _authorized_count,
		"rejection_count": _rejection_count,
		"replay_count": _replay_count,
		"collision_count": _collision_count,
		"journal_size": _request_journal.size(),
		"journal_limit": JOURNAL_LIMIT,
		"scene_owned": true,
		"typed_requests": true,
		"viewer_authority": "LocalViewerAuthorization",
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


func _remember_request(request_id: String, fingerprint: String) -> void:
	_request_journal[request_id] = fingerprint
	_request_order.append(request_id)
	while _request_order.size() > JOURNAL_LIMIT:
		_request_journal.erase(_request_order.pop_front())


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
