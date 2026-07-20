extends SceneTree

const BOUNDARY_SCENE := preload("res://scenes/runtime/PlayerIdentityAuthorizationBoundary.tscn")
const COORDINATOR_SCENE_PATH := "res://scenes/runtime/GameRuntimeCoordinator.tscn"

var _checks := 0
var _failures := 0
var _host: Node
var _world: WorldSessionState
var _authorization: LocalViewerAuthorization
var _session: GameSessionRuntimeController
var _boundary: PlayerIdentityAuthorizationBoundary


func _init() -> void:
	_build_fixture()
	_test_scene_contract()
	_test_authorized_request()
	_test_identity_fail_closed()
	_test_session_fail_closed()
	_test_replay_and_collision()
	_test_journal_resilience()
	_test_journal_session_scope()
	_test_input_validation()
	_test_zero_gameplay_mutation()
	print("PlayerIdentityAuthorizationBoundary: %d checks / %d failures" % [_checks, _failures])
	_host.free()
	quit(0 if _failures == 0 else 1)


func _build_fixture() -> void:
	_host = Node.new()
	_host.name = "IdentityBoundaryFixture"
	root.add_child(_host)
	_world = WorldSessionState.new()
	_world.name = "World"
	_host.add_child(_world)
	_world.players = [
		{"id": "player-0", "name": "本地玩家", "is_ai": false, "seat_type": "human"},
		{"id": "player-1", "name": "AI 1", "is_ai": true, "seat_type": "ai"},
		{"id": "player-2", "name": "AI 2", "is_ai": true, "seat_type": "ai"},
		{"id": "player-3", "name": "AI 3", "is_ai": true, "seat_type": "ai"},
	]
	_authorization = LocalViewerAuthorization.new()
	_authorization.name = "Authorization"
	_host.add_child(_authorization)
	_authorization.configure(_world)
	_session = GameSessionRuntimeController.new()
	_session.name = "GameSession"
	_host.add_child(_session)
	_session.set("_configured", true)
	_session.set("_session_state", GameSessionRuntimeController.STATE_RUNNING)
	_session.set("_session_id", "session-auth-1")
	_session.set("_scenario_id", "standard")
	_session.set("_seed", 42)
	_boundary = BOUNDARY_SCENE.instantiate() as PlayerIdentityAuthorizationBoundary
	_boundary.name = "Boundary"
	_boundary.local_viewer_authorization_path = NodePath("../Authorization")
	_boundary.world_session_state_path = NodePath("../World")
	_boundary.game_session_path = NodePath("../GameSession")
	_host.add_child(_boundary)


func _test_scene_contract() -> void:
	_expect(_boundary != null and _boundary.scene_file_path == "res://scenes/runtime/PlayerIdentityAuthorizationBoundary.tscn", "boundary is an editable production scene")
	var coordinator_source := FileAccess.get_file_as_string(COORDINATOR_SCENE_PATH)
	_expect(coordinator_source.count("PlayerIdentityAuthorizationBoundary.tscn") == 1, "runtime coordinator composes one identity boundary scene")
	_expect(coordinator_source.count("[node name=\"PlayerIdentityAuthorizationBoundary\"") == 1, "runtime coordinator owns one identity boundary node")
	var debug := _boundary.debug_snapshot()
	_expect(bool(debug.get("scene_owned", false)) and bool(debug.get("typed_requests", false)), "boundary declares scene-owned typed request semantics")
	_expect(not bool(debug.get("infers_actor_from_ui", true)) and not bool(debug.get("owns_gameplay_state", true)), "boundary neither infers UI actors nor owns gameplay")
	_expect(not bool(debug.get("references_main", true)), "boundary has no root-script dependency")


func _test_authorized_request() -> void:
	var request := _boundary.build_request("identity:authorized:1", &"game_screen", 1)
	_expect(request.viewer_index == 0 and request.authorized_player_index == 0, "request identity comes from the sole local viewer authority")
	_expect(request.authorization_revision == _authorization.context().authorization_revision, "request binds the current authorization revision")
	_expect(request.session_id == "session-auth-1" and request.session_revision == _session.session_start_revision(), "request binds the active session identity and revision")
	_expect(bool(request.validation_report().get("valid", false)) and not request.fingerprint().is_empty(), "request is typed, valid, and fingerprinted")
	var receipt := _boundary.authorize_request(request)
	_expect(receipt.authorized and receipt.reason_code == "authorized", "matching viewer, player, and session authorize")
	_expect(TablePresentationPureDataPolicy.is_pure_data(receipt.to_dictionary()), "authorization receipt is detached pure data")


func _test_identity_fail_closed() -> void:
	var wrong_viewer := _request("identity:wrong-viewer", 2)
	wrong_viewer.viewer_index = 1
	_expect(_reason(wrong_viewer) == "wrong_viewer", "wrong viewer fails closed")
	var forged_player := _request("identity:forged-player", 3)
	forged_player.authorized_player_index = 1
	_expect(_reason(forged_player) == "forged_player_index", "forged authorized player fails closed")
	var stale_authorization := _request("identity:stale-authorization", 4)
	stale_authorization.authorization_revision += 1
	_expect(_reason(stale_authorization) == "authorization_revision_stale", "stale authorization revision fails closed")
	var original_players := _world.players.duplicate(true)
	var ai_only := original_players.duplicate(true)
	(ai_only[0] as Dictionary)["is_ai"] = true
	(ai_only[0] as Dictionary)["seat_type"] = "ai"
	_world.players = ai_only
	var spectator_request := PlayerIdentityActionRequest.new()
	spectator_request.request_id = "identity:spectator"
	spectator_request.viewer_index = 0
	spectator_request.authorized_player_index = 0
	spectator_request.authorization_revision = _authorization.context().authorization_revision
	spectator_request.session_id = "session-auth-1"
	spectator_request.session_revision = _session.session_start_revision()
	spectator_request.source_surface = &"player_board"
	spectator_request.request_revision = 5
	_expect(_reason(spectator_request) == "spectator_private_mismatch", "spectator cannot submit a private player request")
	_world.players = original_players
	_authorization.context()


func _test_session_fail_closed() -> void:
	var wrong_session := _request("identity:wrong-session", 6)
	wrong_session.session_id = "session-other"
	_expect(_reason(wrong_session) == "wrong_session", "wrong session identity fails closed")
	var stale_session := _request("identity:stale-session", 7)
	stale_session.session_revision -= 1
	_expect(_reason(stale_session) == "session_revision_stale", "stale session revision fails closed")
	var idle_request := _request("identity:idle-session", 8)
	_session.set("_session_state", GameSessionRuntimeController.STATE_IDLE)
	_expect(_reason(idle_request) == "session_not_actionable", "inactive session rejects gameplay identity")
	_session.set("_session_state", GameSessionRuntimeController.STATE_RUNNING)


func _test_replay_and_collision() -> void:
	var request := _request("identity:replay", 9)
	_expect(_boundary.authorize_request(request).authorized, "first stable request authorizes")
	var replay := _boundary.authorize_request(request)
	_expect(not replay.authorized and replay.idempotent_replay and replay.reason_code == "request_replay", "same request replay is rejected exactly once")
	var collision := _request("identity:replay", 10)
	var collision_receipt := _boundary.authorize_request(collision)
	_expect(not collision_receipt.authorized and collision_receipt.request_id_collision and collision_receipt.reason_code == "request_id_collision", "same ID with different binding is rejected as collision")


func _test_journal_resilience() -> void:
	var poisoned := _request("identity:retry-after-rejection", 11)
	poisoned.authorization_revision += 1
	_expect(_reason(poisoned) == "authorization_revision_stale", "rejected request does not enter the exact-once journal")
	poisoned.authorization_revision = _authorization.context().authorization_revision
	_expect(_boundary.authorize_request(poisoned).authorized, "corrected request may reuse an ID that never authorized")
	var retained := _request("identity:retained", 12)
	_expect(_boundary.authorize_request(retained).authorized, "retained request authorizes before journal pressure")
	var bulk_authorized := true
	for index in range(300):
		var request := _request("identity:bulk:%d" % index, 1000 + index)
		bulk_authorized = bulk_authorized and _boundary.authorize_request(request).authorized
	_expect(bulk_authorized, "more than the former journal limit authorizes without eviction")
	var replay := _boundary.authorize_request(retained)
	_expect(not replay.authorized and replay.idempotent_replay, "accepted request remains replay-protected without journal eviction")
	var debug := _boundary.debug_snapshot()
	_expect(not bool(debug.get("journal_eviction_enabled", true)) and int(debug.get("journal_size", 0)) >= 302, "journal retains accepted IDs for the active session")


func _test_journal_session_scope() -> void:
	var request_id := "identity:session-scoped"
	_expect(_boundary.authorize_request(_request(request_id, 1400)).authorized, "request ID authorizes in the original session")
	_session.set("_session_id", "session-auth-2")
	_session.set("_seed", 43)
	_expect(_boundary.authorize_request(_request(request_id, 1401)).authorized, "request ID may be reused after the authoritative session changes")
	_session.set("_session_id", "session-auth-1")
	_session.set("_seed", 42)


func _test_input_validation() -> void:
	var missing_id := _request("identity:temporary", 11)
	missing_id.request_id = ""
	_expect(_reason(missing_id) == "request_id_invalid", "missing request identity is rejected")
	var invalid_surface := _request("identity:surface", 12)
	invalid_surface.source_surface = &"unknown_surface"
	_expect(_reason(invalid_surface) == "source_surface_invalid", "unrecognized source surface is rejected")
	var invalid_revision := _request("identity:revision", 13)
	invalid_revision.request_revision = 0
	_expect(_reason(invalid_revision) == "request_revision_invalid", "invalid producer request revision is rejected")
	_expect(not _boundary.authorize_request(null).authorized, "missing typed request is rejected")


func _test_zero_gameplay_mutation() -> void:
	var world_before := _world.debug_snapshot()
	var session_before := _session.session_summary()
	var request := _request("identity:zero-mutation", 14)
	_boundary.authorize_request(request)
	_expect(_world.debug_snapshot() == world_before, "authorization does not mutate world state")
	_expect(_session.session_summary() == session_before, "authorization does not mutate session state")
	var debug := _boundary.debug_snapshot()
	_expect(int(debug.get("authorized_count", 0)) >= 304 and int(debug.get("replay_count", 0)) >= 2 and int(debug.get("collision_count", 0)) == 1, "debug counters expose successful, replay, and collision outcomes")


func _request(request_id: String, revision: int) -> PlayerIdentityActionRequest:
	return _boundary.build_request(request_id, &"player_board", revision)


func _reason(request: PlayerIdentityActionRequest) -> String:
	return _boundary.authorize_request(request).reason_code


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("[PASS] %s" % label)
		return
	_failures += 1
	push_error("[FAIL] %s" % label)
