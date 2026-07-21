extends SceneTree

const IDENTITY_SCENE := preload("res://scenes/runtime/PlayerIdentityAuthorizationBoundary.tscn")
const RESPONSE_SCENE := preload("res://scenes/runtime/ForcedDecisionResponsePort.tscn")

var _checks := 0
var _failures := 0
var _host: Node
var _scheduler: ForcedDecisionRuntimeScheduler
var _port: ForcedDecisionResponsePort


func _init() -> void:
	_build_fixture()
	_test_active_counter_response()
	_test_option_policy()
	_test_exact_once()
	_test_current_kind_allowlist()
	print("ForcedDecisionResponseBoundary: %d checks / %d failures" % [_checks, _failures])
	_host.free()
	quit(0 if _failures == 0 else 1)


func _build_fixture() -> void:
	_host = Node.new()
	root.add_child(_host)
	var world := WorldSessionState.new()
	world.name = "World"
	world.players = [{"id": "player-0", "is_ai": false, "seat_type": "human"}]
	_host.add_child(world)
	var authorization := LocalViewerAuthorization.new()
	authorization.name = "Authorization"
	_host.add_child(authorization)
	authorization.configure(world)
	var session := GameSessionRuntimeController.new()
	session.name = "GameSession"
	session.set("_configured", true)
	session.set("_session_state", GameSessionRuntimeController.STATE_RUNNING)
	session.set("_session_id", "session-decision-v06")
	_host.add_child(session)
	var identity := IDENTITY_SCENE.instantiate() as PlayerIdentityAuthorizationBoundary
	identity.name = "Identity"
	identity.local_viewer_authorization_path = NodePath("../Authorization")
	identity.world_session_state_path = NodePath("../World")
	identity.game_session_path = NodePath("../GameSession")
	_host.add_child(identity)
	_scheduler = ForcedDecisionRuntimeScheduler.new()
	_scheduler.name = "Scheduler"
	_scheduler.configure(["monster_wager", "counter_response", "other_choice"])
	_host.add_child(_scheduler)
	_port = RESPONSE_SCENE.instantiate() as ForcedDecisionResponsePort
	_port.name = "ResponsePort"
	_port.identity_boundary_path = NodePath("../Identity")
	_port.scheduler_path = NodePath("../Scheduler")
	_host.add_child(_port)
	_scheduler.sync_candidates([{
		"id": "counter_response_41",
		"kind": "counter_response",
		"priority_group": "counter_response",
		"owner_player_index": 0,
		"visibility_scope": "private",
		"presentation_surface": "overlay",
		"opened_sequence": 41.0,
		"blocks_player_actions": true,
	}])


func _test_active_counter_response() -> void:
	var request := _port.build_request("forced:counter:1", "counter_pass", 1)
	_expect(request is ForcedDecisionResponseRequest, "forced response uses the typed identity envelope")
	_expect(request.decision_id == "counter_response_41" and request.decision_kind == &"counter_response", "request binds the active counter decision")
	var emissions := [0]
	_port.response_authorized.connect(func(_request: ForcedDecisionResponseRequest) -> void: emissions[0] += 1, CONNECT_ONE_SHOT)
	var receipt := _port.submit_response(request)
	_expect(receipt.accepted and receipt.emitted and int(emissions[0]) == 1, "authorized counter response emits exactly once")
	_expect(receipt.gameplay_mutation_delta == 0, "authorization boundary does not mutate gameplay")


func _test_option_policy() -> void:
	_expect(bool(ForcedDecisionResponseOptionPolicy.validation_report(&"counter_response", "counter_response_41", "counter_pass").get("valid", false)), "counter pass remains valid")
	_expect(bool(ForcedDecisionResponseOptionPolicy.validation_report(&"counter_response", "counter_response_41", "counter_play_2").get("valid", false)), "indexed counter play remains valid")
	_expect(not bool(ForcedDecisionResponseOptionPolicy.validation_report(&"counter_response", "counter_response_41", "target_player_cancel").get("valid", true)), "cross-kind option fails closed")


func _test_exact_once() -> void:
	var request := _port.build_request("forced:counter:replay", "counter_pass", 2)
	_expect(_port.submit_response(request).accepted, "first request authorizes")
	var replay := _port.submit_response(request)
	_expect(not replay.accepted and replay.idempotent_replay and replay.reason_code == "request_replay", "replay is rejected exactly once")


func _test_current_kind_allowlist() -> void:
	var expected := [&"monster_wager", &"counter_response", &"discard_purchase", &"monster_target_choice", &"player_target_choice", &"public_bid"]
	_expect(ForcedDecisionResponseRequest.DECISION_KINDS == expected, "typed allowlist contains the six current decision kinds")


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("[PASS] %s" % label)
		return
	_failures += 1
	push_error("[FAIL] %s" % label)
