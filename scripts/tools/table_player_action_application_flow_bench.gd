extends Node

var _checks := 0
var _failures: Array[String] = []
var _player_receipt_count := 0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	call_deferred("_run")


func _run() -> void:
	await get_tree().process_frame
	var coordinator := get_node_or_null("GameRuntimeCoordinator") as GameRuntimeCoordinator
	var screen := get_node_or_null("RuntimeGameScreen") as SpaceSyndicateGameScreen
	var ruleset := get_node_or_null("RulesetRuntimeBridge") as RulesetRuntimeBridge
	_check(coordinator != null and screen != null and ruleset != null, "real production coordinator, GameScreen, and ruleset bridge are composed without Main")
	if coordinator == null or screen == null or ruleset == null:
		_finish()
		return
	coordinator.configure(ruleset.debug_snapshot())
	await get_tree().process_frame
	await get_tree().process_frame
	var world := coordinator.world_session_state()
	world.players = [
		{"name": "Bench Human", "is_ai": false, "eliminated": false, "slots": [], "cash": 500},
		{"name": "Bench AI 1", "is_ai": true, "eliminated": false, "slots": [], "cash": 500},
		{"name": "Bench AI 2", "is_ai": true, "eliminated": false, "slots": [], "cash": 500},
	]
	world.districts = [{"id": "region.bench", "region_id": "region.bench", "name": "Bench Region", "destroyed": false}]
	var session_result := coordinator.begin_session({"session_id": "bench.action-spine", "scenario_id": "bench", "seed": 20260728, "player_count": 3})
	_check(str(session_result.get("session_state", "")) == GameSessionRuntimeController.STATE_RUNNING, "real session owner accepts the deterministic bench session")
	var flow := coordinator.get_node_or_null("TablePlayerActionApplicationFlowController") as TablePlayerActionApplicationFlowController
	var group_port := coordinator.get_node_or_null("CardGroupActionPort") as CardGroupActionPort
	var query := coordinator.get_node_or_null("TablePresentationViewModelQuery") as TablePresentationViewModelQuery
	_check(flow != null and group_port != null and query != null, "real typed action flow, group port, and source revision owner are composed")
	if flow == null or query == null:
		_finish()
		return
	query.call("_ensure_action_offer_revision", 0)
	var authorization := flow.human_actor_authorization("bench")
	_check(not authorization.is_empty(), "production identity boundary issues the bench actor authorization")
	var context := coordinator.get_node("PlayerIdentityAuthorizationBoundary").current_actor_context(&"game_screen") as GameplayActorAuthorizationContext
	screen.bind_presentation_viewer(0, context.authorization_revision)
	_check(not authorization.is_empty() and not screen.game_action_actor_authorization("human_click").is_empty(), "production session lifecycle binds the bench actor authorization into GameScreen")
	flow.receipt_ready.connect(_on_player_receipt)
	var source_revision := query.current_action_offer_revision(0)
	var offer := flow.human_action_offer(GameActionIntentV1.ACTION_SESSION_END_TURN, source_revision, true, "none", {}, "full", ["action.session.end-turn"])
	var intent := GameActionIntentV1.build({
		"schema_version": GameActionIntentV1.SCHEMA_VERSION,
		"request_id": "bench.end-turn.1",
		"semantic_action_id": GameActionIntentV1.ACTION_SESSION_END_TURN,
		"source_revision": source_revision,
		"actor_authorization": authorization,
		"target_ids": {},
		"parameters": {},
		"submission_kind": "human_click",
	})
	_check(bool(GameActionOfferV1.accepts_intent(offer, intent)), "production offer and intent share one closed semantic contract")
	var first := flow.submit_intent(intent)
	var replay := flow.submit_intent(intent)
	_check(bool(first.get("accepted", false)) and bool(replay.get("idempotent_replay", false)), "production action commits once and returns an idempotent replay")
	var debug := flow.debug_snapshot()
	_check(int(debug.get("accepted_count", 0)) == 2 and int(debug.get("replay_count", 0)) == 1 and int(debug.get("refresh_request_count", 0)) == 1, "duplicate delivery performs one refresh and no second domain apply")
	_check(_player_receipt_count == 2, "human commit and replay each produce one private feedback receipt")
	var forged_authorization := authorization.duplicate(true)
	forged_authorization["actor_revision"] = int(forged_authorization.get("actor_revision", 0)) + 1
	forged_authorization["authorization_proof_ref"] = "authorization.forged"
	var forged := GameActionIntentV1.build({
		"schema_version": GameActionIntentV1.SCHEMA_VERSION,
		"request_id": "bench.forged.1",
		"semantic_action_id": GameActionIntentV1.ACTION_SESSION_END_TURN,
		"source_revision": source_revision,
		"actor_authorization": forged_authorization,
		"target_ids": {},
		"parameters": {},
		"submission_kind": "human_click",
	})
	var forged_receipt := flow.submit_intent(forged)
	_check(not bool(forged_receipt.get("accepted", true)) and int(flow.debug_snapshot().get("journal_size", 0)) == 1, "unauthorized production request fails with zero journal pollution")
	_check(not screen.has_signal(&"action_requested") and not screen.has_signal(&"end_turn_requested") and not screen.has_signal(&"card_drop_requested"), "production GameScreen has no retired raw outward action signal")
	_check(get_node_or_null("Main") == null and not bool(flow.debug_snapshot().get("references_main", true)) and not bool(group_port.debug_snapshot().get("references_main", true)), "bench and typed ports contain no Main fallback")
	_finish()


func _on_player_receipt(_receipt: Dictionary) -> void:
	_player_receipt_count += 1


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("BENCH_PASS|%s" % message)
		return
	_failures.append(message)
	push_error("TABLE PLAYER ACTION FLOW BENCH: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("TABLE_PLAYER_ACTION_APPLICATION_FLOW_BENCH|status=PASS|checks=%d|failures=0" % _checks)
		get_tree().quit(0)
		return
	print("TABLE_PLAYER_ACTION_APPLICATION_FLOW_BENCH|status=FAIL|checks=%d|failures=%d" % [_checks, _failures.size()])
	get_tree().quit(1)
