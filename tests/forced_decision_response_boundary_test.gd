extends SceneTree

const IDENTITY_SCENE := preload("res://scenes/runtime/PlayerIdentityAuthorizationBoundary.tscn")
const RESPONSE_SCENE := preload("res://scenes/runtime/ForcedDecisionResponsePort.tscn")
const COORDINATOR_SCENE_PATH := "res://scenes/runtime/GameRuntimeCoordinator.tscn"

var _checks := 0
var _failures := 0
var _host: Node
var _world: WorldSessionState
var _authorization: LocalViewerAuthorization
var _session: GameSessionRuntimeController
var _identity: PlayerIdentityAuthorizationBoundary
var _scheduler: ForcedDecisionRuntimeScheduler
var _port: ForcedDecisionResponsePort


func _init() -> void:
	_build_fixture()
	_test_scene_contract()
	_test_authorized_response()
	_test_decision_binding_failures()
	_test_option_policy()
	_test_exact_once()
	_test_journal_resilience()
	_test_journal_session_scope()
	_test_decision_revision_contract()
	_test_private_viewer_and_blocking()
	_test_all_seven_kinds_are_typed()
	print("ForcedDecisionResponseBoundary: %d checks / %d failures" % [_checks, _failures])
	_host.free()
	quit(0 if _failures == 0 else 1)


func _build_fixture() -> void:
	_host = Node.new()
	root.add_child(_host)
	_world = WorldSessionState.new()
	_world.name = "World"
	_host.add_child(_world)
	_world.players = [
		{"id": "player-0", "name": "本地玩家", "is_ai": false, "seat_type": "human"},
		{"id": "player-1", "name": "AI 1", "is_ai": true, "seat_type": "ai"},
		{"id": "player-2", "name": "AI 2", "is_ai": true, "seat_type": "ai"},
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
	_session.set("_session_id", "session-decision-1")
	_session.set("_scenario_id", "standard")
	_identity = IDENTITY_SCENE.instantiate() as PlayerIdentityAuthorizationBoundary
	_identity.name = "Identity"
	_identity.local_viewer_authorization_path = NodePath("../Authorization")
	_identity.world_session_state_path = NodePath("../World")
	_identity.game_session_path = NodePath("../GameSession")
	_host.add_child(_identity)
	_scheduler = ForcedDecisionRuntimeScheduler.new()
	_scheduler.name = "Scheduler"
	_host.add_child(_scheduler)
	_scheduler.configure(["monster_wager", "counter_response", "contract_response", "other_choice"])
	_port = RESPONSE_SCENE.instantiate() as ForcedDecisionResponsePort
	_port.name = "ResponsePort"
	_port.identity_boundary_path = NodePath("../Identity")
	_port.scheduler_path = NodePath("../Scheduler")
	_host.add_child(_port)
	_sync_contract(41, 0)


func _test_scene_contract() -> void:
	var source := FileAccess.get_file_as_string(COORDINATOR_SCENE_PATH)
	_expect(source.count("ForcedDecisionResponsePort.tscn") == 1, "runtime coordinator composes one response port scene")
	_expect(source.count("[node name=\"ForcedDecisionResponsePort\"") == 1, "runtime coordinator owns one response port node")
	var debug := _port.debug_snapshot()
	_expect(bool(debug.get("typed_identity_envelope_required", false)) and bool(debug.get("active_decision_required", false)), "port requires typed identity and active decision bindings")
	_expect(not bool(debug.get("owns_decision_state", true)) and not bool(debug.get("owns_gameplay_state", true)), "port does not duplicate scheduler or gameplay state")
	_expect(not bool(debug.get("references_main", true)), "port has no root-script dependency")


func _test_authorized_response() -> void:
	var request := _port.build_request("forced:contract:1", "contract_accept_41", 1)
	_expect(request is PlayerIdentityActionRequest and request is ForcedDecisionResponseRequest, "forced response inherits the player identity envelope")
	_expect(request.decision_id == "contract_response_41" and request.decision_kind == &"contract_response", "request binds the active decision ID and kind")
	_expect(request.decision_revision > 0 and request.authorization_revision > 0 and request.session_revision > 0, "request binds decision, authorization, and session revisions")
	var emissions := [0]
	_port.response_authorized.connect(func(_request: ForcedDecisionResponseRequest) -> void: emissions[0] = int(emissions[0]) + 1, CONNECT_ONE_SHOT)
	var receipt := _port.submit_response(request)
	_expect(receipt.accepted and receipt.emitted and receipt.reason_code == "response_authorized", "valid typed response is authorized")
	_expect(int(emissions[0]) == 1 and receipt.gameplay_mutation_delta == 0, "authorization emits exactly once without applying gameplay")
	_expect(TablePresentationPureDataPolicy.is_pure_data(receipt.to_dictionary()), "response receipt is pure data")


func _test_decision_binding_failures() -> void:
	var stale_revision := _request("forced:stale-revision", "contract_reject_41", 2)
	stale_revision.decision_revision += 1
	_expect(_reason(stale_revision) == "decision_revision_stale", "stale decision revision fails closed")
	var wrong_id := _request("forced:wrong-id", "contract_reject_41", 3)
	wrong_id.decision_id = "contract_response_99"
	_expect(_reason(wrong_id) == "decision_not_active", "non-active decision ID fails closed")
	var wrong_kind := _request("forced:wrong-kind", "contract_reject_41", 4)
	wrong_kind.decision_kind = &"discard_purchase"
	_expect(_reason(wrong_kind) == "decision_kind_mismatch", "wrong decision kind fails closed")
	var closed := _request("forced:closed", "contract_reject_41", 5)
	_scheduler.sync_candidates([])
	_expect(_reason(closed) == "decision_already_closed", "closed decision fails closed")
	_sync_contract(41, 0)


func _test_option_policy() -> void:
	var invalid := _request("forced:invalid-option", "target_player_cancel", 6)
	_expect(_reason(invalid) == "option_not_available", "option from another decision kind fails closed")
	var contract_binding := _request("forced:wrong-contract-option", "contract_accept_99", 7)
	_expect(_reason(contract_binding) == "option_not_available", "option bound to another decision fails closed")
	_expect(bool(ForcedDecisionResponseOptionPolicy.validation_report(&"discard_purchase", "discard_choice_1", "discard_purchase_2").get("valid", false)), "discard option uses typed indexed allowlist")
	_expect(bool(ForcedDecisionResponseOptionPolicy.validation_report(&"monster_target_choice", "choice-1", "target_monster_cancel").get("valid", false)), "target cancellation uses a typed kind-specific option")
	_expect(bool(ForcedDecisionResponseOptionPolicy.validation_report(&"monster_target_choice", "choice-1", "target_monster_uid_42").get("valid", false)), "monster target response uses a stable positive public UID")
	_expect(not bool(ForcedDecisionResponseOptionPolicy.validation_report(&"monster_target_choice", "choice-1", "target_monster_0").get("valid", false)), "retired mutable roster-index target options fail closed")
	_expect(bool(ForcedDecisionResponseOptionPolicy.validation_report(&"monster_wager", "monster_wager_7", "monster_wager:7:c:6").get("valid", false)), "monster wager syntax supports stable multi-competitor side IDs while the domain sink validates live membership")
	_expect(not bool(ForcedDecisionResponseOptionPolicy.validation_report(&"public_bid", "public_bid_1", "accept").get("valid", true)), "bare generic response words are not accepted as authority")


func _test_exact_once() -> void:
	var request := _request("forced:replay", "contract_reject_41", 8)
	_expect(_port.submit_response(request).accepted, "first response authorizes")
	var replay := _port.submit_response(request)
	_expect(not replay.accepted and replay.idempotent_replay and replay.reason_code == "request_replay", "response replay is rejected exactly once")
	var collision := _request("forced:replay", "contract_accept_41", 9)
	var collision_receipt := _port.submit_response(collision)
	_expect(not collision_receipt.accepted and collision_receipt.request_id_collision and collision_receipt.reason_code == "request_id_collision", "request ID collision fails closed")


func _test_journal_resilience() -> void:
	var rejected := _request("forced:retry-after-rejection", "target_player_cancel", 20)
	_expect(_reason(rejected) == "option_not_available", "invalid option is rejected before it enters either authorization journal")
	rejected.option_id = "contract_reject_41"
	_expect(_port.submit_response(rejected).accepted, "corrected response may reuse an ID that never authorized")
	var retained := _request("forced:retained", "contract_accept_41", 21)
	_expect(_port.submit_response(retained).accepted, "retained response authorizes before journal pressure")
	var bulk_accepted := true
	for index in range(300):
		var request := _request("forced:bulk:%d" % index, "contract_reject_41", 2000 + index)
		bulk_accepted = bulk_accepted and _port.submit_response(request).accepted
	_expect(bulk_accepted, "more than the former journal limit authorizes without eviction")
	var replay := _port.submit_response(retained)
	_expect(not replay.accepted and replay.idempotent_replay, "accepted response remains replay-protected without journal eviction")
	var debug := _port.debug_snapshot()
	_expect(not bool(debug.get("journal_eviction_enabled", true)) and int(debug.get("journal_size", 0)) >= 303, "response journal retains accepted IDs for the active session")


func _test_journal_session_scope() -> void:
	var request_id := "forced:session-scoped"
	_expect(_port.submit_response(_request(request_id, "contract_accept_41", 2400)).accepted, "response ID authorizes in the original session")
	_session.set("_session_id", "session-decision-2")
	_session.set("_seed", 84)
	_expect(_port.submit_response(_request(request_id, "contract_reject_41", 2401)).accepted, "response ID may be reused after the authoritative session changes")
	_session.set("_session_id", "session-decision-1")
	_session.set("_seed", 0)


func _test_decision_revision_contract() -> void:
	var before := int(_scheduler.debug_snapshot().get("decision_revision", 0))
	_sync_contract(41, 0)
	_expect(int(_scheduler.debug_snapshot().get("decision_revision", 0)) == before, "identical candidate synchronization preserves decision revision")
	_sync_contract(43, 0)
	var changed := int(_scheduler.debug_snapshot().get("decision_revision", 0))
	_expect(changed == before + 1, "active decision transition increments revision exactly once")
	_sync_contract(43, 0)
	_expect(int(_scheduler.debug_snapshot().get("decision_revision", 0)) == changed, "repeated active decision snapshot remains revision-stable")
	_sync_contract(41, 0)


func _test_private_viewer_and_blocking() -> void:
	_expect(_port.blocks_ordinary_gameplay(0), "blocking forced decision blocks ordinary gameplay for its viewer")
	var private_for_ai := {
		"id": "contract_response_42", "kind": "contract_response", "priority_group": "contract_response",
		"owner_player_index": 1, "visibility_scope": "private", "presentation_surface": "overlay",
		"opened_sequence": 42.0, "blocks_player_actions": true,
	}
	_scheduler.sync_candidates([private_for_ai])
	var request := _identity.build_request("forced:private-other", &"forced_decision", 10)
	var typed := ForcedDecisionResponseRequest.new()
	for key in request.to_dictionary().keys():
		typed.set(str(key), request.to_dictionary()[key])
	typed.decision_id = "contract_response_42"
	typed.decision_kind = &"contract_response"
	typed.decision_revision = int(_scheduler.debug_snapshot().get("decision_revision", 0))
	typed.option_id = "contract_reject_42"
	_expect(_reason(typed) == "decision_viewer_unauthorized", "viewer cannot respond to another player's private decision")
	_scheduler.sync_candidates([])
	_expect(not _port.blocks_ordinary_gameplay(0), "ordinary gameplay unblocks when the forced decision closes")
	_sync_contract(41, 0)


func _test_all_seven_kinds_are_typed() -> void:
	_expect(ForcedDecisionResponseRequest.DECISION_KINDS.size() == 7, "exactly seven current forced decision kinds are typed")
	for kind in ["monster_wager", "counter_response", "contract_response", "discard_purchase", "monster_target_choice", "player_target_choice", "public_bid"]:
		_expect(ForcedDecisionResponseRequest.DECISION_KINDS.has(StringName(kind)), "%s is present in the typed decision allowlist" % kind)
	var debug := _port.debug_snapshot()
	_expect(int(debug.get("emission_count", 0)) >= 304 and int(debug.get("replay_count", 0)) >= 2 and int(debug.get("collision_count", 0)) == 1, "port counters preserve exact-once response authorization")
	_expect(int(debug.get("gameplay_mutation_count", -1)) == 0, "response boundary performs zero gameplay mutations")


func _sync_contract(contract_id: int, owner_index: int) -> void:
	_scheduler.sync_candidates([{
		"id": "contract_response_%d" % contract_id,
		"kind": "contract_response",
		"priority_group": "contract_response",
		"owner_player_index": owner_index,
		"visibility_scope": "private",
		"presentation_surface": "overlay",
		"opened_sequence": float(contract_id),
		"blocks_player_actions": true,
	}])


func _request(request_id: String, option_id: String, revision: int) -> ForcedDecisionResponseRequest:
	return _port.build_request(request_id, option_id, revision)


func _reason(request: ForcedDecisionResponseRequest) -> String:
	return _port.submit_response(request).reason_code


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("[PASS] %s" % label)
		return
	_failures += 1
	push_error("[FAIL] %s" % label)
