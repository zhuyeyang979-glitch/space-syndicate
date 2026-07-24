extends SceneTree

const IDENTITY_SCENE := preload("res://scenes/runtime/PlayerIdentityAuthorizationBoundary.tscn")
const RESPONSE_SCENE := preload("res://scenes/runtime/ForcedDecisionResponsePort.tscn")
const SINK_SCENE := preload("res://scenes/runtime/MonsterWagerResponseSink.tscn")
const SINK_SCRIPT := preload("res://scripts/runtime/monster_wager_response_sink.gd")
const RECEIPT_SCRIPT := preload("res://scripts/runtime/monster_wager_response_receipt.gd")
const BATTLE_LIFECYCLE_POLICY := preload("res://scripts/runtime/monster_battle_lifecycle_policy_v06.gd")
const COORDINATOR_SCENE_PATH := "res://scenes/runtime/GameRuntimeCoordinator.tscn"

class FakeWorld:
	extends Node
	var economic_event_count := 0
	var cash_snapshot_count := 0

	func _player_name(player_index: int) -> String:
		return "玩家%d" % player_index

	func _record_player_economic_event(_player_index: int, _kind: String, _label: String, _amount: int, _detail: String = "") -> void:
		economic_event_count += 1

	func _record_player_cash_snapshot(_player_index: int) -> void:
		cash_snapshot_count += 1


var _checks := 0
var _failures := 0
var _host: Node
var _world: WorldSessionState
var _fake_world: FakeWorld
var _identity: PlayerIdentityAuthorizationBoundary
var _scheduler: ForcedDecisionRuntimeScheduler
var _port: ForcedDecisionResponsePort
var _monster: MonsterRuntimeController
var _sink: SINK_SCRIPT
var _last_sink_receipt: RECEIPT_SCRIPT


func _init() -> void:
	_build_fixture()
	_test_scene_contract()
	_test_valid_response_exact_once()
	_test_live_option_revalidation()
	_test_multi_side_response()
	_test_identity_and_stale_binding()
	_test_public_privacy()
	_test_game_screen_and_main_cutover()
	print("MONSTER_WAGER_RESPONSE_CUTOVER %d/%d" % [_checks - _failures, _checks])
	_host.free()
	quit(0 if _failures == 0 else 1)


func _build_fixture() -> void:
	_host = Node.new()
	root.add_child(_host)
	_world = WorldSessionState.new()
	_world.name = "World"
	_host.add_child(_world)
	_world.players = [
		{"id": "player-0", "name": "本地玩家", "is_ai": false, "seat_type": "human", "eliminated": false, "cash": 100, "cash_cents": 10000},
		{"id": "player-1", "name": "AI 1", "is_ai": true, "seat_type": "ai", "eliminated": false, "cash": 100, "cash_cents": 10000},
	]
	var authorization := LocalViewerAuthorization.new()
	authorization.name = "Authorization"
	_host.add_child(authorization)
	authorization.configure(_world)
	var session := GameSessionRuntimeController.new()
	session.name = "GameSession"
	_host.add_child(session)
	session.set("_configured", true)
	session.set("_session_state", GameSessionRuntimeController.STATE_RUNNING)
	session.set("_session_id", "session-monster-wager-1")
	session.set("_scenario_id", "standard")
	_identity = IDENTITY_SCENE.instantiate() as PlayerIdentityAuthorizationBoundary
	_identity.name = "Identity"
	_identity.local_viewer_authorization_path = NodePath("../Authorization")
	_identity.world_session_state_path = NodePath("../World")
	_identity.game_session_path = NodePath("../GameSession")
	_host.add_child(_identity)
	_scheduler = ForcedDecisionRuntimeScheduler.new()
	_scheduler.name = "Scheduler"
	_host.add_child(_scheduler)
	_scheduler.configure(["monster_wager", "other_choice"])
	_port = RESPONSE_SCENE.instantiate() as ForcedDecisionResponsePort
	_port.name = "ResponsePort"
	_port.identity_boundary_path = NodePath("../Identity")
	_port.scheduler_path = NodePath("../Scheduler")
	_host.add_child(_port)
	_fake_world = FakeWorld.new()
	_fake_world.name = "FakeWorld"
	_host.add_child(_fake_world)
	var bridge := MonsterRuntimeWorldBridge.new()
	bridge.name = "MonsterBridge"
	bridge.set_world_session_state(_world)
	bridge.bind_world(_fake_world)
	_host.add_child(bridge)
	_monster = MonsterRuntimeController.new()
	_monster.name = "Monster"
	_monster.set_world_bridge(bridge)
	_host.add_child(_monster)
	_sink = SINK_SCENE.instantiate() as SINK_SCRIPT
	_sink.name = "Sink"
	_sink.monster_runtime_controller_path = NodePath("../Monster")
	_sink.identity_boundary_path = NodePath("../Identity")
	_host.add_child(_sink)
	_port.response_authorized.connect(_sink.consume_authorized_response)
	_sink.receipt_ready.connect(func(receipt: RECEIPT_SCRIPT) -> void: _last_sink_receipt = receipt)
	_sink.presentation_refresh_requested.connect(func(_kind: StringName, _reason: StringName) -> void:
		_sync_active_wager()
	)


func _test_scene_contract() -> void:
	var source := FileAccess.get_file_as_string(COORDINATOR_SCENE_PATH)
	var ai_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_runtime_controller.gd")
	_expect(source.count("MonsterWagerResponseSink.tscn") == 1, "production coordinator composes one monster-wager response sink")
	_expect(source.count("[node name=\"MonsterWagerResponseSink\"") == 1, "production coordinator owns one monster-wager response node")
	var debug := _sink.debug_snapshot()
	_expect(bool(debug.get("typed_response_required", false)) and bool(debug.get("live_action_binding_required", false)), "sink requires typed identity and a live advertised wager option")
	_expect(not bool(debug.get("owns_wager_state", true)) and not bool(debug.get("owns_player_cash", true)) and not bool(debug.get("owns_public_pool", true)), "sink duplicates no wager, cash, or public-pool ownership")
	_expect(not bool(debug.get("owns_save_state", true)) and not bool(debug.get("references_main", true)), "sink is not a save owner and never references Main")
	_expect(ai_source.contains("_monster_runtime_controller.submit_monster_wager_response(") \
		and not ai_source.contains("_call_monster"), "human and AI wager decisions converge on the same typed monster-owner entry without dynamic dispatch")


func _test_valid_response_exact_once() -> void:
	_seed_wager(41, 5, ["a", "b"])
	var decision := _monster.monster_wager_decision_snapshot_for_actor(41, 0)
	var stake_options: Array = decision.get("stake_options", []) if decision.get("stake_options", []) is Array else []
	var opening_cash: Dictionary = decision.get("opening_cash_units_by_player", {}) if decision.get("opening_cash_units_by_player", {}) is Dictionary else {}
	_expect(
		int(decision.get("base_percent", -1)) == 5 \
			and int(decision.get("max_percent", -1)) == 20 \
			and stake_options.size() == 16 \
			and int((stake_options[0] as Dictionary).get("percent", -1)) == 5 \
			and int((stake_options[0] as Dictionary).get("stake", -1)) == 5 \
			and int((stake_options[-1] as Dictionary).get("percent", -1)) == 20 \
			and opening_cash.keys() == ["0"],
		"Monster owner advertises actor-scoped stake options without rival opening cash"
	)
	var request := _request("wager:valid", "monster_wager:41:a:5", 1)
	var port_receipt := _port.submit_response(request)
	_expect(port_receipt.accepted and _last_sink_receipt != null and _last_sink_receipt.applied, "authorized wager response reaches the typed sink and mutates once")
	var player: Dictionary = _world.players[0]
	var entry: Dictionary = _monster.active_monster_wagers[0]
	_expect(int(player.get("cash", -1)) == 100 and int(player.get("cash_cents", -1)) == 10000, "response records the opening-cash commitment without an early cash mutation")
	_expect((entry.get("bets", {}) as Dictionary).size() == 1 and (entry.get("public_bets", []) as Array).size() == 1, "one response creates one private bet and one sanitized public bet")
	_expect(_last_sink_receipt.stake_percent == 5 and _last_sink_receipt.stake == 5 and _fake_world.economic_event_count == 0 and _fake_world.cash_snapshot_count == 0, "receipt reports the commitment while economic effects wait for atomic settlement")
	var before_cash := int(player.get("cash_cents", -1))
	var replay := _port.submit_response(request)
	_expect(not replay.accepted and replay.idempotent_replay and int((_world.players[0] as Dictionary).get("cash_cents", -1)) == before_cash, "port replay cannot debit a second wager")
	var direct_replay := _sink.consume_authorized_response(request)
	_expect(not direct_replay.accepted and direct_replay.idempotent_replay and int((_world.players[0] as Dictionary).get("cash_cents", -1)) == before_cash, "sink duplicate delivery is also exact-once")
	var collision := _request("wager:valid", "monster_wager:41:b:5", 2)
	var collision_receipt := _sink.consume_authorized_response(collision)
	_expect(not collision_receipt.accepted and collision_receipt.request_id_collision, "sink rejects a reused request ID with different wager content")
	var second := _request("wager:second", "monster_wager:41:b:5", 3)
	_expect(_port.submit_response(second).accepted and not _last_sink_receipt.applied and _last_sink_receipt.reason_code == "monster_wager_already_decided", "a new request cannot place a second bet for the same player")


func _test_live_option_revalidation() -> void:
	_reset_player_cash(100)
	_seed_wager(42, 7, ["a", "b"])
	var forged_percent := _request("wager:percent", "monster_wager:42:a:99", 4)
	_expect(_port.submit_response(forged_percent).accepted and not _last_sink_receipt.applied and _last_sink_receipt.reason_code == "monster_wager_option_unavailable", "syntactically valid but unadvertised percentage is rejected rather than clamped")
	var absent_side := _request("wager:side", "monster_wager:42:c:7", 5)
	_expect(_port.submit_response(absent_side).accepted and not _last_sink_receipt.applied and _last_sink_receipt.reason_code == "monster_wager_option_unavailable", "syntactically valid absent competitor side is rejected")
	_expect(int((_world.players[0] as Dictionary).get("cash_cents", -1)) == 10000 and (_monster.active_monster_wagers[0].get("bets", {}) as Dictionary).is_empty(), "invalid live options produce zero cash or wager mutation")
	var closed_request := _request("wager:closed", "monster_wager:42:a:7", 6)
	_monster.active_monster_wagers.clear()
	var closed_receipt := _sink.consume_authorized_response(closed_request)
	_expect(not closed_receipt.accepted and closed_receipt.reason_code == "monster_wager_not_active", "sink rechecks the live wager after response authorization")


func _test_multi_side_response() -> void:
	_reset_player_cash(100)
	_seed_wager(43, 6, ["a", "c"])
	_expect(bool(ForcedDecisionResponseOptionPolicy.validation_report(&"monster_wager", "monster_wager_43", "monster_wager:43:c:6").get("valid", false)), "typed syntax accepts supported multi-monster side IDs beyond a/b")
	var request := _request("wager:side-c", "monster_wager:43:c:6", 7)
	_expect(_port.submit_response(request).accepted and _last_sink_receipt.applied and _last_sink_receipt.side == &"c", "live side c reaches the same authoritative wager owner")


func _test_identity_and_stale_binding() -> void:
	_reset_player_cash(100)
	_seed_wager(44, 5, ["a", "b"])
	var stale := _request("wager:stale", "monster_wager:44:a:5", 8)
	stale.decision_revision += 1
	var stale_receipt := _port.submit_response(stale)
	_expect(not stale_receipt.accepted and stale_receipt.reason_code == "decision_revision_stale", "stale decision revision never reaches the wager owner")
	var forged_actor := _request("wager:actor", "monster_wager:44:a:5", 9)
	forged_actor.authorized_player_index = 1
	var actor_receipt := _port.submit_response(forged_actor)
	_expect(not actor_receipt.accepted and actor_receipt.reason_code.begins_with("identity_"), "forged responding player fails identity authorization")
	_expect(int((_world.players[0] as Dictionary).get("cash_cents", -1)) == 10000 and (_monster.active_monster_wagers[0].get("bets", {}) as Dictionary).is_empty(), "identity and stale failures create zero gameplay mutation")


func _test_public_privacy() -> void:
	var applied := RECEIPT_SCRIPT.new()
	applied.applied = true
	applied.wager_id = 44
	applied.player_index = 0
	applied.side = &"a"
	applied.stake_percent = 5
	applied.stake = 5
	var public := applied.public_summary()
	var serialized := JSON.stringify(public)
	_expect(bool(public.get("publishable", false)) and int(public.get("public_player_index", -1)) == 0 and int(public.get("stake", 0)) == 5, "public receipt exposes only the intentionally public wager clue")
	for forbidden in ["request_id", "viewer_index", "cash", "cash_cents", "hand", "discard", "owner", "ai_wager", "score", "plan", "learning", "pending_attack"]:
		_expect(not serialized.contains(forbidden), "public wager receipt omits %s" % forbidden)
	_expect(TablePresentationPureDataPolicy.is_pure_data(applied.to_dictionary()), "private wager response receipt is stable pure data without Node references")


func _test_game_screen_and_main_cutover() -> void:
	var game_screen_source := FileAccess.get_file_as_string("res://scripts/ui/game_screen.gd")
	_expect(game_screen_source.contains("apply_monster_wager_response_receipt") and game_screen_source.contains("_emit_forced_decision_response(action_id, \"monster_wager\", \"monster-wager\")"), "GameScreen emits and consumes the typed wager response path")
	var screen := SpaceSyndicateGameScreen.new()
	screen.set("_presentation_authorized_viewer_index", 0)
	screen.set("_presentation_authorization_revision", 1)
	screen.set("_presentation_session_id", "session-monster-wager-1")
	screen.set("_presentation_session_revision", 1)
	screen.current_ui_data = {"active_forced_decision": {"id": "monster_wager_50", "kind": "monster_wager", "decision_revision": 8, "visible_to_viewer": true}}
	screen.set("_rendered_forced_decision_binding", {"decision_id": "monster_wager_49", "decision_revision": 7, "kind": "monster_wager"})
	var typed_requests: Array = []
	var generic_actions: Array = []
	screen.forced_decision_response_requested.connect(func(request: ForcedDecisionResponseRequest) -> void: typed_requests.append(request))
	screen.action_requested.connect(func(action_id: String) -> void: generic_actions.append(action_id))
	screen.call("_on_temporary_decision_action_requested", "monster_wager:49:a:5")
	_expect(typed_requests.is_empty() and generic_actions.is_empty(), "stale rendered wager cannot rebind to a newer decision or fall through to Main")
	screen.set("_rendered_forced_decision_binding", {"decision_id": "monster_wager_50", "decision_revision": 8, "kind": "monster_wager"})
	screen.call("_on_temporary_decision_action_requested", "monster_wager:50:a:5")
	_expect(typed_requests.size() == 1 and generic_actions.is_empty() and (typed_requests[0] as ForcedDecisionResponseRequest).decision_id == "monster_wager_50", "matching wager click emits one typed request and zero generic actions")
	screen.free()


func _seed_wager(wager_id: int, base_percent: int, sides: Array[String]) -> void:
	var competitors: Array = []
	for index in range(sides.size()):
		competitors.append({"side": sides[index], "name": "怪兽%s" % sides[index].to_upper(), "slot": index, "uid": 100 + index, "damage": 0})
	_monster.active_monster_wagers = [{
		"wager_id": wager_id,
		"settlement_revision": wager_id,
		"base_percent": base_percent,
		"competitors": competitors,
		"damage_a": 0,
		"damage_b": 0,
		"damage_c": 0,
		"bets": {},
		"public_bets": [],
		"historical_public_pool": 20,
		"eligible_player_indices": [0, 1],
		"opening_cash_units_by_player": {"0": 100, "1": 100},
		"public_player_ids_by_index": {"0": "player.0", "1": "player.1"},
		"lifecycle_schema_version": BATTLE_LIFECYCLE_POLICY.SCHEMA_VERSION,
		"lifecycle_phase": BATTLE_LIFECYCLE_POLICY.PHASE_DECISION,
		"lifecycle_revision": 1,
		"decision_remaining_seconds": 15.0,
		"battle_limit_seconds": 60.0,
		"battle_remaining_seconds": 60.0,
		"locked_competitor_uids": competitors.map(func(row: Dictionary) -> int: return int(row.get("uid", 0))),
		"battle_roster_fingerprint": BATTLE_LIFECYCLE_POLICY.roster_fingerprint(competitors),
		"opening_attack_applied": true,
		"decision_open": true,
		"context": "聚焦测试",
		"resolved": false,
	}]
	_monster.monster_wager_sequence = wager_id
	_sync_active_wager()
	_last_sink_receipt = null


func _sync_active_wager() -> void:
	if _monster.active_monster_wagers.is_empty():
		_scheduler.sync_candidates([])
		return
	var wager_id := int((_monster.active_monster_wagers[0] as Dictionary).get("wager_id", -1))
	_scheduler.sync_candidates([{
		"id": "monster_wager_%d" % wager_id,
		"kind": "monster_wager",
		"priority_group": "monster_wager",
		"owner_player_index": -1,
		"visibility_scope": "public",
		"presentation_surface": "overlay",
		"opened_sequence": float(wager_id),
		"blocks_global_time": true,
		"blocks_player_actions": true,
		"blocks_card_resolution": true,
	}])


func _reset_player_cash(amount: int) -> void:
	var player: Dictionary = (_world.players[0] as Dictionary).duplicate(true)
	player["cash"] = amount
	player["cash_cents"] = amount * 100
	_world.players[0] = player


func _request(request_id: String, option_id: String, revision: int) -> ForcedDecisionResponseRequest:
	return _port.build_request(request_id, option_id, revision)


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % label)
		return
	_failures += 1
	push_error("FAIL: %s" % label)
