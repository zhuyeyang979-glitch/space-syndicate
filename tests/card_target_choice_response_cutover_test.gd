extends SceneTree

const IDENTITY_SCENE := preload("res://scenes/runtime/PlayerIdentityAuthorizationBoundary.tscn")
const RESPONSE_SCENE := preload("res://scenes/runtime/ForcedDecisionResponsePort.tscn")
const SINK_SCENE := preload("res://scenes/runtime/CardTargetChoiceResponseSink.tscn")
const SINK_SCRIPT := preload("res://scripts/runtime/card_target_choice_response_sink.gd")
const SINK_RECEIPT_SCRIPT := preload("res://scripts/runtime/card_target_choice_response_receipt.gd")
const COORDINATOR_SCENE_PATH := "res://scenes/runtime/GameRuntimeCoordinator.tscn"

class FakeSubmission:
	extends CardPlaySubmissionRuntimeController
	var submit_count := 0
	var next_result := {"accepted": true, "reason": "queued", "player_message": "卡牌已进入共享卡牌窗。"}
	var last_request: Dictionary = {}
	var before_submit: Callable
	var before_submit_result: Variant

	func submit_card_play(request: Dictionary) -> Dictionary:
		submit_count += 1
		last_request = request.duplicate(true)
		if before_submit.is_valid():
			before_submit_result = before_submit.call()
		return next_result.duplicate(true)


var _checks := 0
var _failures := 0
var _host: Node
var _world: WorldSessionState
var _authorization: LocalViewerAuthorization
var _session: GameSessionRuntimeController
var _identity: PlayerIdentityAuthorizationBoundary
var _scheduler: ForcedDecisionRuntimeScheduler
var _port: ForcedDecisionResponsePort
var _choices: CardTargetChoiceRuntimeController
var _submission: FakeSubmission
var _monster: MonsterRuntimeController
var _sink: SINK_SCRIPT
var _last_sink_receipt: SINK_RECEIPT_SCRIPT


func _init() -> void:
	_build_fixture()
	_test_scene_contract()
	_test_monster_success_exact_once()
	_test_down_monster_replay_and_collision()
	_test_cancel_without_card_consumption()
	_test_player_target_rules()
	_test_submission_failure_and_stale_binding()
	_test_privacy_projection()
	_test_ui_and_main_cutover()
	print("CARD_TARGET_CHOICE_RESPONSE_CUTOVER %d/%d" % [_checks - _failures, _checks])
	_host.free()
	quit(0 if _failures == 0 else 1)


func _build_fixture() -> void:
	_host = Node.new()
	root.add_child(_host)
	_world = WorldSessionState.new()
	_world.name = "World"
	_host.add_child(_world)
	_world.players = [
		{"id": "player-0", "name": "本地玩家", "is_ai": false, "seat_type": "human", "eliminated": false},
		{"id": "player-1", "name": "淘汰玩家", "is_ai": true, "seat_type": "ai", "eliminated": true},
		{"id": "player-2", "name": "有效目标", "is_ai": true, "seat_type": "ai", "eliminated": false},
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
	_session.set("_session_id", "session-target-choice-1")
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
	_scheduler.configure(["other_choice"])
	_port = RESPONSE_SCENE.instantiate() as ForcedDecisionResponsePort
	_port.name = "ResponsePort"
	_port.identity_boundary_path = NodePath("../Identity")
	_port.scheduler_path = NodePath("../Scheduler")
	_host.add_child(_port)
	_choices = CardTargetChoiceRuntimeController.new()
	_choices.name = "Choices"
	_host.add_child(_choices)
	_submission = FakeSubmission.new()
	_submission.name = "Submission"
	_host.add_child(_submission)
	_monster = MonsterRuntimeController.new()
	_monster.name = "Monster"
	_monster.auto_monsters = [
		{"uid": 11, "name": "活动怪兽", "down": false},
		{"uid": 12, "name": "倒地怪兽", "down": true},
	]
	_host.add_child(_monster)
	_sink = SINK_SCENE.instantiate() as SINK_SCRIPT
	_sink.name = "Sink"
	_sink.target_choice_controller_path = NodePath("../Choices")
	_sink.card_play_submission_controller_path = NodePath("../Submission")
	_sink.monster_runtime_controller_path = NodePath("../Monster")
	_sink.identity_boundary_path = NodePath("../Identity")
	_host.add_child(_sink)
	_port.response_authorized.connect(_sink.consume_authorized_response)
	_sink.receipt_ready.connect(func(receipt: SINK_RECEIPT_SCRIPT) -> void: _last_sink_receipt = receipt)
	_sink.presentation_refresh_requested.connect(func(_kind: StringName, _reason: StringName) -> void:
		_scheduler.sync_candidates(_choices.forced_decision_candidates())
	)


func _test_scene_contract() -> void:
	var source := FileAccess.get_file_as_string(COORDINATOR_SCENE_PATH)
	_expect(source.count("CardTargetChoiceResponseSink.tscn") == 1, "production coordinator composes one target-choice response sink")
	_expect(source.count("[node name=\"CardTargetChoiceResponseSink\"") == 1, "production coordinator owns one target-choice response node")
	var debug := _sink.debug_snapshot()
	_expect(bool(debug.get("typed_response_required", false)) and not bool(debug.get("references_main", true)), "sink requires typed responses and never references Main")
	_expect(not bool(debug.get("owns_target_choice", true)) and not bool(debug.get("owns_card_queue", true)) and not bool(debug.get("owns_monster_roster", true)), "sink does not duplicate target, queue, or roster ownership")
	_expect(_identity.public_player_is_active(0) and not _identity.public_player_is_active(1) and _identity.public_player_is_active(2), "public identity boundary distinguishes active and eliminated target players")


func _test_monster_success_exact_once() -> void:
	_begin_choice(CardTargetChoiceRuntimeController.KIND_MONSTER, 0, 3)
	_submission.before_submit = func() -> Dictionary:
		return _choices.clear_choice(CardTargetChoiceRuntimeController.KIND_MONSTER)
	_monster.auto_monsters.reverse()
	var request := _request("target:monster:success", "target_monster_uid_11", 1)
	var authorization_receipt := _port.submit_response(request)
	_submission.before_submit = Callable()
	_expect(authorization_receipt.accepted and _last_sink_receipt != null and _last_sink_receipt.queued, "authorized monster target reaches the typed sink and queues once")
	_expect(_submission.submit_count == 1 and int(_submission.last_request.get("target_slot", -1)) == 1 and int(_submission.last_request.get("target_monster_uid", -1)) == 11 and int(_submission.last_request.get("target_player", -2)) == -1, "stable monster UID resolves the intended target after roster reordering")
	var interleaved_clear: Dictionary = _submission.before_submit_result if _submission.before_submit_result is Dictionary else {}
	_expect(not bool(interleaved_clear.get("cleared", true)) and str(interleaved_clear.get("reason", "")) == "target_choice_reserved", "choice reservation prevents an interleaved clear during queue commit")
	_expect(not _choices.has_choice(CardTargetChoiceRuntimeController.KIND_MONSTER) and _last_sink_receipt.choice_cleared, "successful monster submission clears its choice exactly once")
	var before := _submission.submit_count
	var replay := _port.submit_response(request)
	_expect(not replay.accepted and replay.reason_code == "decision_already_closed" and _submission.submit_count == before, "closed decision replay cannot queue a second card")


func _test_down_monster_replay_and_collision() -> void:
	_begin_choice(CardTargetChoiceRuntimeController.KIND_MONSTER, 0, 4)
	var request := _request("target:monster:down", "target_monster_uid_12", 2)
	_expect(_port.submit_response(request).accepted and _last_sink_receipt.reason_code == "target_monster_down", "down monster is rejected by the domain sink after typed authorization")
	var before := _submission.submit_count
	var replay := _port.submit_response(request)
	_expect(not replay.accepted and replay.idempotent_replay and replay.reason_code == "request_replay" and _submission.submit_count == before, "same rejected response identity is exact-once")
	var collision := _request("target:monster:down", "target_monster_uid_11", 3)
	var collision_receipt := _port.submit_response(collision)
	_expect(not collision_receipt.accepted and collision_receipt.request_id_collision and _submission.submit_count == before, "same request ID with another target is rejected as collision")
	_expect(_choices.has_choice(CardTargetChoiceRuntimeController.KIND_MONSTER), "invalid monster target leaves the live choice open")


func _test_cancel_without_card_consumption() -> void:
	var before := _submission.submit_count
	var request := _request("target:monster:cancel", "target_monster_cancel", 4)
	_expect(_port.submit_response(request).accepted and _last_sink_receipt.cancelled and _last_sink_receipt.choice_cleared, "cancel closes the current target choice")
	_expect(_submission.submit_count == before and not _choices.has_choice(CardTargetChoiceRuntimeController.KIND_MONSTER), "cancel consumes no card and creates no queue entry")


func _test_player_target_rules() -> void:
	_begin_choice(CardTargetChoiceRuntimeController.KIND_PLAYER, 0, 5)
	var self_request := _request("target:player:self", "target_player_0", 5)
	_expect(_port.submit_response(self_request).accepted and _last_sink_receipt.reason_code == "target_player_self", "self target is rejected without clearing the choice")
	var eliminated := _request("target:player:eliminated", "target_player_1", 6)
	_expect(_port.submit_response(eliminated).accepted and _last_sink_receipt.reason_code == "target_player_unavailable", "eliminated player is rejected from public target facts")
	var valid := _request("target:player:valid", "target_player_2", 7)
	_expect(_port.submit_response(valid).accepted and _last_sink_receipt.queued and _last_sink_receipt.target_index == 2, "active opponent target queues the card")
	_expect(int(_submission.last_request.get("target_player", -1)) == 2 and int(_submission.last_request.get("target_slot", -2)) == -1, "player response submits only the selected public target")
	_expect(not _choices.has_choice(CardTargetChoiceRuntimeController.KIND_PLAYER), "successful player target clears its choice")


func _test_submission_failure_and_stale_binding() -> void:
	_submission.next_result = {"accepted": false, "reason": "stable_target_card_changed", "player_message": "卡牌状态已变化。"}
	_begin_choice(CardTargetChoiceRuntimeController.KIND_PLAYER, 0, 6)
	var rejected := _request("target:player:changed", "target_player_2", 8)
	_expect(_port.submit_response(rejected).accepted and _last_sink_receipt.reason_code == "stable_target_card_changed", "card submission rejection is surfaced by the sink")
	_expect(_choices.has_choice(CardTargetChoiceRuntimeController.KIND_PLAYER), "rejected card submission does not clear the choice")
	_expect(int(_choices.debug_snapshot().get("reservation_count", -1)) == 0, "rejected card submission releases its synchronous choice reservation")
	var stale := _request("target:player:stale", "target_player_2", 9)
	stale.decision_revision += 1
	var before := _submission.submit_count
	var stale_receipt := _port.submit_response(stale)
	_expect(not stale_receipt.accepted and stale_receipt.reason_code == "decision_revision_stale" and _submission.submit_count == before, "stale decision revision never reaches mutation")
	_submission.next_result = {"accepted": true, "reason": "queued", "player_message": "卡牌已进入共享卡牌窗。"}


func _test_privacy_projection() -> void:
	var private_cancel := SINK_RECEIPT_SCRIPT.new()
	private_cancel.cancelled = true
	private_cancel.applied = true
	private_cancel.decision_kind = &"player_target_choice"
	var cancel_public := private_cancel.public_summary()
	_expect(not bool(cancel_public.get("publishable", true)) and not cancel_public.has("decision_kind") and not cancel_public.has("cancelled"), "pre-track cancellation has no public event")
	var public := _last_sink_receipt.public_summary()
	var queued_public_receipt := SINK_RECEIPT_SCRIPT.new()
	queued_public_receipt.queued = true
	queued_public_receipt.decision_kind = &"monster_target_choice"
	queued_public_receipt.target_index = 1
	var queued_public := queued_public_receipt.public_summary()
	var serialized := JSON.stringify(public)
	_expect(not serialized.contains("viewer_index") and not serialized.contains("request_id") and not serialized.contains("card") and not serialized.contains("owner") and not serialized.contains("hand") and not serialized.contains("cash"), "public projection omits actor, card, owner, hand, and cash data")
	_expect(bool(queued_public.get("publishable", false)) and int(queued_public.get("public_target_index", -1)) == 1 and not JSON.stringify(queued_public).contains("request_id"), "queued public projection exposes only the public target result")
	_expect(TablePresentationPureDataPolicy.is_pure_data(_last_sink_receipt.to_dictionary()), "target response receipt is stable pure data")


func _test_ui_and_main_cutover() -> void:
	var game_screen := FileAccess.get_file_as_string("res://scripts/ui/game_screen.gd")
	_expect(game_screen.contains("forced_decision_response_requested.emit(request)") and game_screen.contains("apply_card_target_choice_response_receipt"), "GameScreen emits typed responses and consumes typed sink receipts")
	_expect(game_screen.contains("_rendered_forced_decision_binding") and game_screen.contains("decision_revision") and game_screen.contains("decision_id"), "GameScreen binds clicks to the decision identity that rendered the target window")
	var screen := SpaceSyndicateGameScreen.new()
	screen.set("_presentation_authorized_viewer_index", 0)
	screen.set("_presentation_authorization_revision", 1)
	screen.set("_presentation_session_id", "session-target-choice-1")
	screen.set("_presentation_session_revision", 1)
	screen.current_ui_data = {"active_forced_decision": {"id": "choice-new", "kind": "player_target_choice", "decision_revision": 8, "visible_to_viewer": true}}
	screen.set("_rendered_forced_decision_binding", {"decision_id": "choice-old", "decision_revision": 7, "kind": "player_target_choice"})
	var emitted_requests: Array = []
	screen.forced_decision_response_requested.connect(func(response: ForcedDecisionResponseRequest) -> void: emitted_requests.append(response))
	_expect(not bool(screen.call("_emit_forced_decision_response", "target_player_2", "player_target_choice", "target-choice")) and emitted_requests.is_empty(), "stale rendered target window cannot rebind its click to a newer same-kind choice")
	screen.set("_rendered_forced_decision_binding", {"decision_id": "choice-new", "decision_revision": 8, "kind": "player_target_choice"})
	_expect(bool(screen.call("_emit_forced_decision_response", "target_player_2", "player_target_choice", "target-choice")) and emitted_requests.size() == 1 and (emitted_requests[0] as ForcedDecisionResponseRequest).decision_id == "choice-new" and (emitted_requests[0] as ForcedDecisionResponseRequest).decision_revision == 8, "matching rendered decision emits one typed response with its frozen identity")
	screen.free()
	_expect(game_screen.contains("_emit_forced_decision_response(action_id, expected_kind, \"target-choice\")"), "target choices are intercepted before generic Main action routing")


func _begin_choice(kind: String, player_index: int, slot_index: int) -> Dictionary:
	var choice := _choices.begin_choice(kind, player_index, slot_index)
	_scheduler.sync_candidates(_choices.forced_decision_candidates())
	_last_sink_receipt = null
	return choice


func _request(request_id: String, option_id: String, revision: int) -> ForcedDecisionResponseRequest:
	return _port.build_request(request_id, option_id, revision)


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % label)
		return
	_failures += 1
	push_error("FAIL: %s" % label)
