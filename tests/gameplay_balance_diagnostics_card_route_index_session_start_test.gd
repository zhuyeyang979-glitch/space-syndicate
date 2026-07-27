extends SceneTree

const SESSION_DRIVER := preload("res://tests/support/production_session_start_driver.gd")
const QA_SAVE_PATH := "user://test_runs/gameplay_balance_diagnostics_card_route_index_session_start.save"
const INITIAL_REQUEST_ID := "diagnostics-route-index-initial"
const PRIME_REQUEST_ID := "diagnostics-route-index-prime"
const FAILED_REQUEST_ID := "diagnostics-route-index-rollback"
const EXPECTED_SAVE_SECTION_COUNT := 19

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1600, 960)
	var start: Dictionary = await SESSION_DRIVER.start_configured_session(
		self,
		{
			"player_count": 4,
			"ai_player_count": 3,
			"challenge_depth": 1,
			"role_indices": [0, 1, 2, 3],
			"starter_monster_indices": [7, 6, 2, 4],
		},
		QA_SAVE_PATH,
		INITIAL_REQUEST_ID
	)
	var app_root := start.get("main_root") as Node
	var coordinator := start.get("coordinator") as GameRuntimeCoordinator
	var world := start.get("world_session") as WorldSessionState
	var session := start.get("game_session") as GameSessionRuntimeController
	var draft := start.get("draft_service") as NewGameSetupDraftService
	var transaction := start.get("transaction") as SessionStartTransactionCoordinator
	var initial_receipt := start.get("receipt") as SessionStartReceipt
	_expect(
		bool(start.get("started", false))
			and app_root != null
			and coordinator != null
			and world != null
			and session != null
			and draft != null
			and transaction != null,
		"production session composition starts through ProductionSessionStartDriver: %s"
			% str(start.get("reason_code", "missing"))
	)
	if app_root == null or coordinator == null or world == null or session == null \
			or draft == null or transaction == null:
		await _cleanup(app_root)
		_finish()
		return

	app_root.process_mode = Node.PROCESS_MODE_DISABLED
	var diagnostics := coordinator.gameplay_balance_diagnostics_service()
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController
	var rng := coordinator.get_node_or_null("RunRngService") as RunRngService
	var registry := coordinator.get_node_or_null(
		"GameSessionRuntimeController/V06SaveOwnerRegistry"
	) as V06SaveOwnerRegistry
	_expect(
		diagnostics != null and ai != null and rng != null and registry != null,
		"production composition exposes diagnostics, AI, RNG, and the sole Save registry"
	)
	if diagnostics == null or ai == null or rng == null or registry == null:
		await _cleanup(app_root)
		_finish()
		return

	var initial_commit: Dictionary = initial_receipt.details.get("commit_only", {}) \
		if initial_receipt != null else {}
	var initial_prime: Dictionary = initial_commit.get("card_route_index", {}) \
		if initial_commit.get("card_route_index", {}) is Dictionary else {}
	_expect(
		initial_receipt != null and initial_receipt.applied
			and bool(initial_prime.get("accepted", false)),
		"initial production session primes the card-route index at commit-only"
	)
	_expect(
		int(initial_commit.get("rng_draw_delta", -1)) == 0,
		"initial commit-only publication, including route-index priming, consumes zero RNG"
	)

	var save_before := registry.registry_snapshot()
	_expect(
		bool(save_before.get("valid", false))
			and int(save_before.get("required_section_count", 0)) == EXPECTED_SAVE_SECTION_COUNT,
		"production Save registry starts with the unchanged 19-section manifest"
	)

	# Commit a real replacement so the exact request object can be replayed and
	# collided without reconstructing the hashed active-session revision.
	var before_success := diagnostics.debug_snapshot()
	var success_request := SessionStartRequest.create(
		PRIME_REQUEST_ID,
		draft.draft_snapshot(),
		session.session_start_revision(),
		"focused_test"
	)
	var stale_active_revision := success_request.expected_active_session_revision
	var success_receipt := transaction.start_session(success_request)
	var after_success := diagnostics.debug_snapshot()
	var success_commit: Dictionary = success_receipt.details.get("commit_only", {}) \
		if success_receipt != null else {}
	var success_prime: Dictionary = success_commit.get("card_route_index", {}) \
		if success_commit.get("card_route_index", {}) is Dictionary else {}
	_expect(
		success_receipt != null and success_receipt.applied
			and success_receipt.trace.find("commit:side_effects") >= 0,
		"successful replacement reaches the formal commit-only side-effect barrier"
	)
	_expect(
		bool(success_prime.get("accepted", false))
			and str(success_prime.get("reason_code", "")) == "card_route_index_ready"
			and bool(after_success.get("card_route_index_ready", false))
			and bool(after_success.get("card_route_index_sealed", false)),
		"successful replacement leaves a ready, sealed production card-route index"
	)
	_expect(
		int(after_success.get("card_route_index_build_count", -1))
			== int(before_success.get("card_route_index_build_count", -2)) + 1,
		"successful replacement primes the index exactly once"
	)
	_expect(
		str(after_success.get("card_route_index_fingerprint", "")) != ""
			and str(after_success.get("card_route_index_fingerprint", ""))
				== str(success_prime.get("fingerprint", "")),
		"commit receipt attests the sealed index fingerprint"
	)
	_expect(
		int(success_commit.get("rng_draw_delta", -1)) == 0
			and int(success_commit.get("gameplay_mutation_count", -1)) == 0,
		"successful route-index priming has zero RNG and gameplay-state delta"
	)

	var actor_index := _first_legal_ai_actor(world)
	_expect(actor_index >= 1, "production roster exposes a non-eliminated AI actor")
	if actor_index >= 1:
		var before_candidates := diagnostics.debug_snapshot()
		var candidate_rng_before := rng.capture_plan_checkpoint()
		var candidates := ai.call("_ai_card_buy_candidates", actor_index) as Array
		var candidate_rng_after := rng.capture_plan_checkpoint()
		var after_candidates := diagnostics.debug_snapshot()
		_expect(not candidates.is_empty(), "AI candidate generation runs after production priming")
		_expect(
			bool(before_candidates.get("card_route_index_sealed", false))
				and int(after_candidates.get("card_route_index_build_count", -1))
					== int(before_candidates.get("card_route_index_build_count", -2)),
			"the route index is sealed before candidates and is not rebuilt in the candidate loop"
		)
		_expect(
			int(after_candidates.get("card_route_index_hit_count", 0))
				> int(before_candidates.get("card_route_index_hit_count", 0)),
			"AI candidates record real hits against the already-primed index"
		)
		_expect(
			int(after_candidates.get("card_route_index_miss_count", -1))
				== int(before_candidates.get("card_route_index_miss_count", -2)),
			"AI candidates record zero misses against the sealed index"
		)
		_expect(
			int(after_candidates.get("card_route_legacy_snapshot_lookup_count", -1))
				== int(before_candidates.get("card_route_legacy_snapshot_lookup_count", -2)),
			"AI candidates perform zero legacy diagnostics snapshot lookups"
		)
		_expect(
			candidate_rng_after == candidate_rng_before,
			"route-index-backed AI candidate generation consumes zero RNG"
		)

	var sealed_baseline := diagnostics.debug_snapshot()
	var replay_rng_before := rng.capture_plan_checkpoint()
	var success_replay := transaction.start_session(success_request)
	_expect(
		success_replay != null and success_replay.applied and success_replay.idempotent,
		"successful session request replay returns the terminal idempotent receipt"
	)
	_assert_index_unchanged(
		sealed_baseline,
		diagnostics.debug_snapshot(),
		"successful replay"
	)
	_expect(
		rng.capture_plan_checkpoint() == replay_rng_before,
		"successful session replay consumes zero RNG"
	)

	var collision_rng_before := rng.capture_plan_checkpoint()
	var collision_request := SessionStartRequest.create(
		PRIME_REQUEST_ID,
		draft.draft_snapshot(),
		session.session_start_revision(),
		"focused_test"
	)
	var collision_receipt := transaction.start_session(collision_request)
	_expect(
		collision_receipt != null and not collision_receipt.applied
			and collision_receipt.reason_code == "session_start_request_collision",
		"same request ID with a different active-session binding fails closed"
	)
	_assert_index_unchanged(
		sealed_baseline,
		diagnostics.debug_snapshot(),
		"request collision"
	)
	_expect(
		rng.capture_plan_checkpoint() == collision_rng_before,
		"request collision consumes zero RNG"
	)

	var stale_rng_before := rng.capture_plan_checkpoint()
	var stale_request := SessionStartRequest.create(
		"diagnostics-route-index-stale-rebind",
		draft.draft_snapshot(),
		stale_active_revision,
		"focused_test"
	)
	var stale_receipt := transaction.start_session(stale_request)
	_expect(
		stale_receipt != null and not stale_receipt.applied
			and stale_receipt.reason_code == "active_session_revision_stale",
		"stale active-session rebind fails closed before route-index priming"
	)
	_assert_index_unchanged(
		sealed_baseline,
		diagnostics.debug_snapshot(),
		"stale session rebind"
	)
	_expect(
		rng.capture_plan_checkpoint() == stale_rng_before,
		"stale session rebind consumes zero RNG"
	)

	var failed_request := SessionStartRequest.create(
		FAILED_REQUEST_ID,
		draft.draft_snapshot(),
		session.session_start_revision(),
		"focused_test"
	)
	var failed_rng_before := rng.capture_plan_checkpoint()
	coordinator.set_new_session_test_fault_stage("after_card_route_index_prime")
	var failed_receipt := transaction.start_session(failed_request)
	coordinator.set_new_session_test_fault_stage("")
	var failed_commit: Dictionary = coordinator.new_session_start_debug_snapshot().get(
		"last_commit_only_receipt",
		{}
	)
	_expect(
		failed_receipt != null and not failed_receipt.applied
			and failed_receipt.rollback_complete
			and failed_receipt.reason_code == "new_session_fault_after_card_route_index_prime"
			and bool((failed_commit.get("card_route_index", {}) as Dictionary).get("accepted", false)),
		"post-prime commit-only fault proves priming occurred and rolls back"
	)
	_assert_index_unchanged(
		sealed_baseline,
		diagnostics.debug_snapshot(),
		"failed replacement rollback"
	)
	_expect(
		rng.capture_plan_checkpoint() == failed_rng_before,
		"failed replacement restores the exact RNG checkpoint"
	)

	var failed_replay_rng_before := rng.capture_plan_checkpoint()
	var failed_replay := transaction.start_session(failed_request)
	_expect(
		failed_replay != null and not failed_replay.applied and failed_replay.idempotent,
		"failed session request replay preserves its terminal fail-closed receipt"
	)
	_assert_index_unchanged(
		sealed_baseline,
		diagnostics.debug_snapshot(),
		"failed request replay"
	)
	_expect(
		rng.capture_plan_checkpoint() == failed_replay_rng_before,
		"failed request replay consumes zero RNG"
	)

	var save_after := registry.registry_snapshot()
	_expect(
		int(save_after.get("required_section_count", 0)) == EXPECTED_SAVE_SECTION_COUNT
			and int(save_after.get("required_section_count", -1))
				== int(save_before.get("required_section_count", -2))
			and int(save_after.get("binding_count", -1))
				== int(save_before.get("binding_count", -2))
			and save_after.get("fixed_apply_order", []) == save_before.get("fixed_apply_order", []),
		"priming, rollback, replay, collision, and stale rejection leave the 19-section Save registry unchanged"
	)

	await _cleanup(app_root)
	_finish()


func _assert_index_unchanged(before: Dictionary, after: Dictionary, boundary: String) -> void:
	_expect(
		bool(after.get("card_route_index_ready", false))
			and bool(after.get("card_route_index_sealed", false))
			and int(after.get("card_route_index_build_count", -1))
				== int(before.get("card_route_index_build_count", -2))
			and int(after.get("card_route_index_card_count", -1))
				== int(before.get("card_route_index_card_count", -2))
			and str(after.get("card_route_index_fingerprint", ""))
				== str(before.get("card_route_index_fingerprint", "missing"))
			and int(after.get("card_route_index_hit_count", -1))
				== int(before.get("card_route_index_hit_count", -2))
			and int(after.get("card_route_index_miss_count", -1))
				== int(before.get("card_route_index_miss_count", -2))
			and int(after.get("card_route_legacy_snapshot_lookup_count", -1))
				== int(before.get("card_route_legacy_snapshot_lookup_count", -2)),
		"%s restores the sealed card-route index and all counters exactly" % boundary
	)


func _first_legal_ai_actor(world: WorldSessionState) -> int:
	for player_index in range(world.players.size()):
		var player: Dictionary = world.players[player_index]
		if bool(player.get("is_ai", false)) and not bool(player.get("eliminated", false)):
			return player_index
	return -1


func _cleanup(app_root: Node) -> void:
	if app_root == null:
		return
	for node in app_root.find_children("*", "AudioStreamPlayer", true, false):
		(node as AudioStreamPlayer).stop()
	app_root.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print(
		"GAMEPLAY_BALANCE_DIAGNOSTICS_CARD_ROUTE_INDEX_SESSION_START_TEST|status=%s|checks=%d|failures=%d"
			% [status, _checks, _failures.size()]
	)
	for failure in _failures:
		push_error("GAMEPLAY_BALANCE_DIAGNOSTICS_CARD_ROUTE_INDEX_SESSION_START_TEST: %s" % failure)
	quit(0 if _failures.is_empty() else 1)
