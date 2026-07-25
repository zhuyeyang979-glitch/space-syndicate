extends SceneTree

const SESSION_DRIVER := preload("res://tests/support/production_session_start_driver.gd")
const QA_SAVE_PATH := "user://test_runs/ai_card_play_context_reuse_performance_parity.save"
const SESSION_REQUEST_ID := "ai-card-play-context-reuse-performance-parity"
const DETERMINISTIC_REQUEST_ID := "ai-card-play-context-reuse-performance-parity-deterministic"
const DETERMINISTIC_SESSION_SEED := 2026072501
const FULL_HAND_CARD_ID := "interaction.starlink_dismantle.rank_1"
const QUEUE_FAILURE_HAND_CARD_ID := "interaction.starlink_dismantle.rank_4"
const HAND_SIZE := 5
const CALL_LIMIT_MSEC := 80_000

const FULL_HAND_GOLDEN_LOCKED := true
const FULL_HAND_GOLDEN_CANDIDATE_COUNT := 5
const FULL_HAND_GOLDEN_PROJECTION_SHA256 := "f2f9378fd4f0981d759405e8331a38b7a30ec22e5d2f655ba26abfb0c287d64b"
const FULL_HAND_GOLDEN_ORIGINAL_ORDER_SHA256 := "c3104f72e36712720d1ea158b86058ba55099039f79edd302400d83b6b6cf9da"
const FULL_HAND_GOLDEN_RANKED_ORDER_SHA256 := "c3104f72e36712720d1ea158b86058ba55099039f79edd302400d83b6b6cf9da"
const FULL_HAND_GOLDEN_FORCE_SELECTION_SHA256 := "6c4e9b50341a15d2704543a35b445ad82ccefeeac47769fad315d3f2830a729d"
const FULL_HAND_GOLDEN_NORMAL_SELECTION_SHA256 := "6c4e9b50341a15d2704543a35b445ad82ccefeeac47769fad315d3f2830a729d"
const FULL_HAND_GOLDEN_NORMAL_TERMINAL_SHA256 := "31f5a028edcf8c0afb56a4f234ae09de7b1b050ea62e51da6f7a9a9a8006d78e"
const FULL_HAND_GOLDEN_FINAL_MEMORY_SHA256 := "9a1951ceac14f8fdfd28488f9105b2e0c405a5b5b4160666caaa05ec1637c957"
const FULL_HAND_GOLDEN_AI_QUERY_DELTA := 231
const FULL_HAND_GOLDEN_COMMIT_DELTA := 4

const FALLBACK_SUGGESTED_LIMIT_MSEC := 8_000
const FALLBACK_ABSOLUTE_LIMIT_MSEC := 15_000


class RejectingQueueSubmission:
	extends CardPlaySubmissionRuntimeController
	var submit_count := 0
	var last_request: Dictionary = {}
	var before_reject: Callable
	var rejection_side_effect: Dictionary = {}

	func submit_card_play(request: Dictionary) -> Dictionary:
		submit_count += 1
		last_request = request.duplicate(true)
		if before_reject.is_valid():
			var side_effect_variant: Variant = before_reject.call(request.duplicate(true))
			rejection_side_effect = side_effect_variant as Dictionary \
				if side_effect_variant is Dictionary else {}
		return {
			"accepted": false,
			"queued": false,
			"reason": "focused_queue_rejection",
			"player_message": "",
		}


class CapturingRejectedPurchase:
	extends DistrictSupplyActionPort
	var submit_count := 0
	var last_purchase: Dictionary = {}

	func submit_ai_purchase(
		player_index: int,
		district_index: int,
		card_id: String,
		discard_slot := -1,
		request_id := ""
	) -> bool:
		submit_count += 1
		last_purchase = {
			"player_index": player_index,
			"district": district_index,
			"card_name": card_id,
			"discard_slot": int(discard_slot),
			"request_id": str(request_id),
		}
		return false


var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1600, 960)
	var scenario := "full_hand"
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
		SESSION_REQUEST_ID
	)
	var app_root := start.get("main_root") as Node
	var coordinator := start.get("coordinator") as GameRuntimeCoordinator
	var session := start.get("game_session") as GameSessionRuntimeController
	var draft := start.get("draft_service") as NewGameSetupDraftService
	var transaction := start.get("transaction") as SessionStartTransactionCoordinator
	_expect(
		bool(start.get("started", false))
			and app_root != null
			and coordinator != null
			and session != null
			and draft != null
			and transaction != null,
		"formal four-player fixture starts through SessionStartTransaction"
	)
	if app_root == null or coordinator == null or session == null or draft == null or transaction == null:
		await _cleanup(app_root)
		_finish(scenario)
		return

	app_root.process_mode = Node.PROCESS_MODE_DISABLED
	var rng := coordinator.get_node_or_null("RunRngService") as RunRngService
	_expect(rng != null, "production coordinator owns RunRngService")
	if rng == null:
		await _cleanup(app_root)
		_finish(scenario)
		return

	rng.set_seed(DETERMINISTIC_SESSION_SEED)
	var deterministic_seed_state := rng.state
	var cursor_reset := rng.restore_plan_checkpoint({
		"schema_version": 1,
		"rng_state": deterministic_seed_state,
		"draw_count": 0,
	})
	var deterministic_request := SessionStartRequest.create(
		DETERMINISTIC_REQUEST_ID,
		draft.draft_snapshot(),
		session.session_start_revision(),
		"focused_test"
	)
	var deterministic_receipt := transaction.start_session(deterministic_request)
	_expect(bool(cursor_reset.get("restored", false)), "fixture resets RunRngService to a deterministic checkpoint")
	_expect(
		deterministic_receipt != null and deterministic_receipt.applied,
		"deterministic replacement commits through SessionStartTransaction"
	)
	if deterministic_receipt == null or not deterministic_receipt.applied:
		await _cleanup(app_root)
		_finish(scenario)
		return

	session.pause_session()
	var world := coordinator.world_session_state()
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController
	var actor_state_port := coordinator.get_node_or_null("AiActorStatePort") as AiActorStatePort
	_expect(
		world != null and ai != null and actor_state_port != null,
		"production world and AI query dependencies are available"
	)
	if world == null or ai == null or actor_state_port == null:
		await _cleanup(app_root)
		_finish(scenario)
		return

	var actor_index := _first_legal_ai_actor(world)
	_expect(actor_index >= 1, "focused query selects one legal AI actor")
	if actor_index < 1:
		await _cleanup(app_root)
		_finish(scenario)
		return

	var hand_ready := _replace_actor_hand(coordinator, world, actor_index, FULL_HAND_CARD_ID)
	_expect(hand_ready, "focused fixture installs exactly five owned runtime cards")
	if not hand_ready:
		await _cleanup(app_root)
		_finish(scenario)
		return

	session.resume_session()
	_expect(
		session.session_state() == GameSessionRuntimeController.STATE_RUNNING
			and app_root.process_mode == Node.PROCESS_MODE_DISABLED,
		"typed-query authorization runs while RuntimeLoop processing stays frozen"
	)

	_verify_turn_context_scope()
	_run_full_hand_play(ai, actor_state_port, rng, actor_index)
	_run_queue_failure_fresh_context(ai, coordinator, actor_state_port, rng, world, actor_index)
	var actor_indices := _legal_ai_actors(world)
	var fallback_fixture_ready := true
	for fallback_actor_index in actor_indices:
		fallback_fixture_ready = _replace_actor_hand(
			coordinator,
			world,
			fallback_actor_index,
			FULL_HAND_CARD_ID,
			true
		) and fallback_fixture_ready
	_expect(fallback_fixture_ready, "fallback fixture installs five evaluated but unplayable cards for every AI actor")
	if fallback_fixture_ready:
		_run_fallback_aggregate(ai, actor_state_port, rng, world, actor_indices)

	await _cleanup(app_root)
	_finish(scenario)


func _run_full_hand_play(
	ai: AiRuntimeController,
	actor_state_port: AiActorStatePort,
	rng: RunRngService,
	actor_index: int
) -> void:
	var rng_before := rng.capture_plan_checkpoint()
	var state_before := actor_state_port.debug_snapshot()
	print("AI_CARD_PLAY_CONTEXT_REUSE|FULL_HAND|CALL_STARTED")
	var started_msec := Time.get_ticks_msec()
	var candidates := ai.call("_ai_card_play_candidates", actor_index) as Array
	var elapsed_msec := Time.get_ticks_msec() - started_msec
	var state_after := actor_state_port.debug_snapshot()
	var query_delta := int(state_after.get("ai_state_query_count", 0)) - int(state_before.get("ai_state_query_count", 0))
	var commit_delta := int(state_after.get("state_commit_count", 0)) - int(state_before.get("state_commit_count", 0))
	var rng_after := rng.capture_plan_checkpoint()
	var projection := _candidate_projection(candidates)
	var projection_sha256 := JSON.stringify(projection).sha256_text()
	var original_order_sha256 := JSON.stringify(_candidate_order(projection)).sha256_text()
	var ranked := ai.rank_candidates(actor_index, candidates, {"source_context": "full_hand_play_performance"})
	var ranked_order_sha256 := JSON.stringify(_candidate_order(_candidate_projection(ranked))).sha256_text()

	var force_rng_before := rng.capture_plan_checkpoint()
	var forced_selection := ai.call("_ai_pick_candidate", actor_index, candidates, true) as Dictionary
	var force_rng_after := rng.capture_plan_checkpoint()
	var force_selection_sha256 := JSON.stringify(_candidate_projection_row(forced_selection)).sha256_text()
	var normal_checkpoint := rng.capture_plan_checkpoint()
	var normal_selection := ai.call("_ai_pick_candidate", actor_index, candidates, false) as Dictionary
	var normal_terminal := rng.capture_plan_checkpoint()
	var restored := rng.restore_plan_checkpoint(normal_checkpoint)
	var normal_replay := ai.call("_ai_pick_candidate", actor_index, candidates, false) as Dictionary
	var normal_replay_terminal := rng.capture_plan_checkpoint()
	var normal_selection_sha256 := JSON.stringify(_candidate_projection_row(normal_selection)).sha256_text()
	var normal_terminal_sha256 := JSON.stringify(normal_terminal).sha256_text()
	var final_memory := ai.call("_ai_memory_for_player", actor_index) as Dictionary
	var compact_memory := _compact_final_memory_projection(final_memory.duplicate(true))
	var final_memory_sha256 := JSON.stringify(compact_memory).sha256_text()
	var memory_reference := _first_memory_context_candidate(projection)

	print(
		"AI_CARD_PLAY_CONTEXT_REUSE|FULL_HAND|CALL_COMPLETED|elapsed_msec=%d|candidate_count=%d"
			% [elapsed_msec, candidates.size()]
	)
	print(
		"AI_CARD_PLAY_CONTEXT_REUSE|FULL_HAND|QUERY_COUNTERS|ai_state_query_count_delta=%d|state_commit_count_delta=%d"
			% [query_delta, commit_delta]
	)
	print("AI_CARD_PLAY_CONTEXT_REUSE|FULL_HAND|SAFE_SUMMARY|%s" % JSON.stringify({
		"elapsed_msec": elapsed_msec,
		"candidate_count": candidates.size(),
		"ai_state_query_count_delta": query_delta,
		"state_commit_count_delta": commit_delta,
		"projection_sha256": projection_sha256,
		"original_order_sha256": original_order_sha256,
		"ranked_order_sha256": ranked_order_sha256,
		"force_selection_sha256": force_selection_sha256,
		"normal_selection_sha256": normal_selection_sha256,
		"normal_terminal_sha256": normal_terminal_sha256,
		"final_memory_sha256": final_memory_sha256,
	}))
	_expect(elapsed_msec < CALL_LIMIT_MSEC, "full-hand play candidate generation stays below the focused limit")
	_expect(not candidates.is_empty(), "full-hand fixture exposes legal card-play candidates")
	_expect(rng_after == rng_before, "full-hand candidate generation consumes zero RNG")
	_expect(force_rng_after == force_rng_before, "full-hand force selection consumes zero RNG")
	_expect(bool(restored.get("restored", false)), "full-hand normal selection restores the RNG checkpoint")
	_expect(_candidate_projection_row(normal_selection) == _candidate_projection_row(normal_replay), "full-hand normal selection replays identically")
	_expect(normal_terminal == normal_replay_terminal, "full-hand normal selection reaches the same terminal RNG")
	_expect(TablePresentationPureDataPolicy.is_pure_data(projection), "full-hand candidate projection is detached pure data")
	_expect(not memory_reference.is_empty(), "full-hand candidate carries final memory context")
	_expect(
		compact_memory == _candidate_memory_context_projection(memory_reference),
		"full-hand final focus, phase, strategy, and route memory matches the candidate context"
	)
	if FULL_HAND_GOLDEN_LOCKED:
		_expect(candidates.size() == FULL_HAND_GOLDEN_CANDIDATE_COUNT, "full-hand candidate count matches the frozen baseline")
		_expect(projection_sha256 == FULL_HAND_GOLDEN_PROJECTION_SHA256, "full-hand projection matches the frozen baseline")
		_expect(original_order_sha256 == FULL_HAND_GOLDEN_ORIGINAL_ORDER_SHA256, "full-hand original order matches the frozen baseline")
		_expect(ranked_order_sha256 == FULL_HAND_GOLDEN_RANKED_ORDER_SHA256, "full-hand ranked order matches the frozen baseline")
		_expect(force_selection_sha256 == FULL_HAND_GOLDEN_FORCE_SELECTION_SHA256, "full-hand force selection matches the frozen baseline")
		_expect(normal_selection_sha256 == FULL_HAND_GOLDEN_NORMAL_SELECTION_SHA256, "full-hand normal selection matches the frozen baseline")
		_expect(normal_terminal_sha256 == FULL_HAND_GOLDEN_NORMAL_TERMINAL_SHA256, "full-hand terminal RNG matches the frozen baseline")
		_expect(final_memory_sha256 == FULL_HAND_GOLDEN_FINAL_MEMORY_SHA256, "full-hand final memory matches the frozen baseline")
		_expect(query_delta == FULL_HAND_GOLDEN_AI_QUERY_DELTA, "full-hand actor-state query count matches the frozen baseline")
		_expect(commit_delta == FULL_HAND_GOLDEN_COMMIT_DELTA, "full-hand actor-state commit count matches the frozen baseline")


func _run_fallback_aggregate(
	ai: AiRuntimeController,
	actor_state_port: AiActorStatePort,
	rng: RunRngService,
	world: WorldSessionState,
	actor_indices: Array[int]
) -> void:
	var initial_players := world.players.duplicate(true)
	var initial_rng := rng.capture_plan_checkpoint()
	var baseline := _measure_fallback_aggregate(ai, actor_state_port, rng, actor_indices, false)
	world.players = initial_players.duplicate(true)
	var rng_restore := rng.restore_plan_checkpoint(initial_rng)
	_expect(bool(rng_restore.get("restored", false)), "turn-context parity restores the pre-baseline RNG checkpoint")
	var optimized := _measure_fallback_aggregate(ai, actor_state_port, rng, actor_indices, true)

	var semantic_parity: bool = baseline.get("semantic_projection", []) == optimized.get("semantic_projection", [])
	var memory_parity: bool = baseline.get("final_memory_projection", []) == optimized.get("final_memory_projection", [])
	var commit_parity: bool = baseline.get("commit_projection", []) == optimized.get("commit_projection", []) \
		and int(baseline.get("state_commit_delta", -1)) == int(optimized.get("state_commit_delta", -2))
	var terminal_rng_parity: bool = baseline.get("rng_checkpoint", {}) == optimized.get("rng_checkpoint", {})
	var query_reduction := int(optimized.get("ai_state_query_delta", 0)) < int(baseline.get("ai_state_query_delta", 0))
	var optimized_elapsed_msec := int(optimized.get("elapsed_msec", FALLBACK_ABSOLUTE_LIMIT_MSEC))
	var absolute_limit_met := optimized_elapsed_msec < FALLBACK_ABSOLUTE_LIMIT_MSEC
	var suggested_limit_met := optimized_elapsed_msec < FALLBACK_SUGGESTED_LIMIT_MSEC
	var gate_passed: bool = semantic_parity \
		and memory_parity \
		and commit_parity \
		and terminal_rng_parity \
		and query_reduction \
		and absolute_limit_met

	print("AI_CARD_TURN_FALLBACK_AGGREGATE|BASELINE|%s" % JSON.stringify(baseline))
	print("AI_CARD_TURN_FALLBACK_AGGREGATE|OPTIMIZED|%s" % JSON.stringify(optimized))
	print(
		"TURN_CONTEXT_REUSE_GATE|status=%s|baseline_elapsed_msec=%d|optimized_elapsed_msec=%d|baseline_queries=%d|optimized_queries=%d|suggested_limit_met=%s"
			% [
				"PASS" if gate_passed else "FAIL",
				int(baseline.get("elapsed_msec", -1)),
				optimized_elapsed_msec,
				int(baseline.get("ai_state_query_delta", -1)),
				int(optimized.get("ai_state_query_delta", -1)),
				str(suggested_limit_met),
			]
	)
	_expect(semantic_parity, "three-AI shared turn context preserves candidate semantics, original/ranked order, and force/normal selection")
	_expect(memory_parity, "three-AI shared turn context preserves each actor's final memory")
	_expect(commit_parity, "three-AI shared turn context preserves per-actor and aggregate state commit counts")
	_expect(terminal_rng_parity, "three-AI shared turn context preserves terminal RNG")
	_expect(query_reduction, "three-AI shared turn context reduces actor-state queries")
	_expect(absolute_limit_met, "three-AI shared turn context stays below the absolute 15 second limit")


func _run_queue_failure_fresh_context(
	ai: AiRuntimeController,
	coordinator: GameRuntimeCoordinator,
	actor_state_port: AiActorStatePort,
	rng: RunRngService,
	world: WorldSessionState,
	actor_index: int
) -> void:
	var formal_hand_ready := _replace_actor_hand(
		coordinator,
		world,
		actor_index,
		QUEUE_FAILURE_HAND_CARD_ID
	)
	_expect(formal_hand_ready, "queue-failure fixture installs five non-mergeable counted cards through the formal hand projection")
	if not formal_hand_ready:
		print("QUEUE_FAILURE_FRESH_CONTEXT_GATE|status=FAIL|reason=formal_non_mergeable_hand_unavailable")
		return
	var discard_fixture := _prepare_authoritative_discard_pressure_fixture(coordinator, actor_index)
	_expect(bool(discard_fixture.get("prepared", false)), "queue-failure fixture fills the authoritative inventory to its formal hand limit")
	if not bool(discard_fixture.get("prepared", false)):
		print("QUEUE_FAILURE_FRESH_CONTEXT_GATE|status=FAIL|reason=authoritative_discard_fixture_unavailable")
		return
	var original_submission := coordinator.card_play_submission_controller()
	var original_purchase := coordinator.district_supply_action_port()
	var history := coordinator.get_node_or_null("CardResolutionHistoryRuntimeService") as CardResolutionHistoryRuntimeService
	var rejecting_queue := RejectingQueueSubmission.new()
	var capturing_purchase := CapturingRejectedPurchase.new()
	root.add_child(rejecting_queue)
	root.add_child(capturing_purchase)
	rejecting_queue.before_reject = Callable(self, "_invalidate_queue_failure_cached_slot").bind(world, actor_index)
	ai.set_card_execution_dependencies(rejecting_queue, history)
	ai.set_district_supply_action_port(capturing_purchase)

	var world_checkpoint := world.capture_runtime_checkpoint()
	var rng_checkpoint := rng.capture_plan_checkpoint()
	var production_state_before := actor_state_port.debug_snapshot()
	var production_result := str(ai.call("_ai_execute_card_turn", actor_index, false))
	var production_state_after := actor_state_port.debug_snapshot()
	var production_memory := ai.call("_ai_memory_for_player", actor_index) as Dictionary
	var production_rng := rng.capture_plan_checkpoint()
	var production_commits := int(production_state_after.get("state_commit_count", 0)) \
		- int(production_state_before.get("state_commit_count", 0))
	var production_buy := capturing_purchase.last_purchase.duplicate(true)
	var production_queue := rejecting_queue.last_request.duplicate(true)
	var production_fresh_buy_candidates := ai.call("_ai_card_buy_candidates", actor_index) as Array
	var production_fresh_projection := _candidate_projection(production_fresh_buy_candidates)
	var production_fresh_ranked := ai.rank_candidates(
		actor_index,
		production_fresh_buy_candidates,
		{"source_context": "queue_failure_fresh_context_production"}
	)

	var world_restore := world.restore_runtime_checkpoint(world_checkpoint)
	var rng_restore := rng.restore_plan_checkpoint(rng_checkpoint)
	var reference_state_before := actor_state_port.debug_snapshot()
	var reference_turn_context := ai.call("_ai_card_turn_scoring_context", actor_index) as Dictionary
	var reference_play_candidates := ai.call("_ai_card_play_candidates", actor_index, reference_turn_context) as Array
	var reference_play_choice := ai.call("_ai_pick_candidate", actor_index, reference_play_candidates, false) as Dictionary
	var reference_side_effect := _invalidate_queue_failure_cached_slot(
		{
			"slot_index": int(reference_play_choice.get("slot_index", -1)),
		},
		world,
		actor_index
	)
	var stale_buy_candidates := ai.call("_ai_card_buy_candidates", actor_index, reference_turn_context) as Array
	var reference_buy_candidates := ai.call("_ai_card_buy_candidates", actor_index) as Array
	var reference_buy_choice := ai.call("_ai_pick_candidate", actor_index, reference_buy_candidates, false) as Dictionary
	var reference_state_after := actor_state_port.debug_snapshot()
	var reference_memory := ai.call("_ai_memory_for_player", actor_index) as Dictionary
	var reference_rng := rng.capture_plan_checkpoint()
	var reference_commits := int(reference_state_after.get("state_commit_count", 0)) \
		- int(reference_state_before.get("state_commit_count", 0))
	var reference_fresh_projection := _candidate_projection(reference_buy_candidates)
	var reference_fresh_ranked := ai.rank_candidates(
		actor_index,
		reference_buy_candidates,
		{"source_context": "queue_failure_fresh_context_reference"}
	)
	var stale_projection := _candidate_projection(stale_buy_candidates)

	var production_play_projection := {
		"player_index": int(production_queue.get("player_index", -1)),
		"slot_index": int(production_queue.get("slot_index", -1)),
		"target_slot": int(production_queue.get("target_slot", -1)),
		"target_player": int(production_queue.get("target_player", -1)),
		"selected_card_resolution_id": int(production_queue.get("selected_card_resolution_id", -1)),
	}
	var reference_play_projection := {
		"player_index": actor_index,
		"slot_index": int(reference_play_choice.get("slot_index", -1)),
		"target_slot": int(reference_play_choice.get("target_slot", -1)),
		"target_player": int(reference_play_choice.get("target_player", -1)),
		"selected_card_resolution_id": int(reference_play_choice.get("selected_card_resolution_id", -1)),
	}
	var reference_buy_projection := {
		"player_index": actor_index,
		"district": int(reference_buy_choice.get("district", -1)),
		"card_name": str(reference_buy_choice.get("card_name", "")),
		"discard_slot": int(reference_buy_choice.get("discard_slot", -1)),
		"request_id": "",
	}
	var queue_fault_reached: bool = rejecting_queue.submit_count == 1 \
		and not production_queue.is_empty() \
		and production_play_projection == reference_play_projection
	var fallback_reached: bool = capturing_purchase.submit_count == 1 \
		and production_result == "wait" \
		and not reference_buy_choice.is_empty()
	var fixture_discriminates_stale_context: bool = bool(rejecting_queue.rejection_side_effect.get("mutated", false)) \
		and bool(reference_side_effect.get("mutated", false)) \
		and stale_projection != reference_fresh_projection
	var candidate_parity: bool = production_fresh_projection == reference_fresh_projection \
		and _candidate_order(production_fresh_projection) == _candidate_order(reference_fresh_projection) \
		and _candidate_order(_candidate_projection(production_fresh_ranked)) \
			== _candidate_order(_candidate_projection(reference_fresh_ranked))
	var buy_discard_parity: bool = production_buy == reference_buy_projection \
		and bool(reference_buy_choice.get("requires_discard", false)) \
		and int(reference_buy_choice.get("discard_slot", -1)) >= 0
	var memory_parity: bool = _canonicalize(production_memory) == _canonicalize(reference_memory)
	var commit_parity: bool = production_commits == reference_commits
	var rng_parity: bool = production_rng == reference_rng
	var final_world_restore := world.restore_runtime_checkpoint(world_checkpoint)
	var final_rng_restore := rng.restore_plan_checkpoint(rng_checkpoint)
	ai.set_card_execution_dependencies(original_submission, history)
	ai.set_district_supply_action_port(original_purchase)
	rejecting_queue.queue_free()
	capturing_purchase.queue_free()
	var gate_passed: bool = bool(world_restore.get("applied", false)) \
		and bool(rng_restore.get("restored", false)) \
		and queue_fault_reached \
		and fallback_reached \
		and fixture_discriminates_stale_context \
		and candidate_parity \
		and buy_discard_parity \
		and memory_parity \
		and commit_parity \
		and rng_parity \
		and bool(final_world_restore.get("applied", false)) \
		and bool(final_rng_restore.get("restored", false))
	print(
		"QUEUE_FAILURE_FRESH_CONTEXT_GATE|status=%s|queue_rejections=%d|fallback_purchases=%d|discard_slot=%d|candidate_count=%d|stale_context_discriminated=%s|production_commits=%d|reference_commits=%d|rng_parity=%s"
			% [
				"PASS" if gate_passed else "FAIL",
				rejecting_queue.submit_count,
				capturing_purchase.submit_count,
				int(reference_buy_choice.get("discard_slot", -1)),
				reference_buy_candidates.size(),
				str(fixture_discriminates_stale_context),
				production_commits,
				reference_commits,
				str(rng_parity),
			]
	)
	_expect(bool(world_restore.get("applied", false)) and bool(rng_restore.get("restored", false)), "queue-failure reference restores the exact production world and RNG checkpoint")
	_expect(queue_fault_reached, "production turn reaches one typed queue rejection with the same selected play as the reference")
	_expect(fallback_reached, "production turn continues from queue rejection into exactly one fallback purchase attempt")
	_expect(fixture_discriminates_stale_context, "queue side effect makes the cached turn context observably stale before fallback scoring")
	_expect(candidate_parity, "queue-failure fresh candidates preserve uncached reference semantics and original/ranked order")
	_expect(buy_discard_parity, "queue-failure fallback buy and discard match an independently built fresh-buy context")
	_expect(memory_parity, "queue-failure production turn preserves the fresh-buy final AI memory")
	_expect(commit_parity, "queue-failure production turn preserves the fresh-buy AI commit count")
	_expect(rng_parity, "queue-failure production turn preserves the fresh-buy terminal RNG")
	_expect(bool(final_world_restore.get("applied", false)) and bool(final_rng_restore.get("restored", false)), "queue-failure test leaves the focused fixture at its original checkpoint")


func _measure_fallback_aggregate(
	ai: AiRuntimeController,
	actor_state_port: AiActorStatePort,
	rng: RunRngService,
	actor_indices: Array[int],
	reuse_turn_context: bool
) -> Dictionary:
	var mode := "optimized" if reuse_turn_context else "baseline"
	var rng_before := rng.capture_plan_checkpoint()
	var state_before := actor_state_port.debug_snapshot()
	var started_msec := Time.get_ticks_msec()
	var actor_summaries: Array = []
	var semantic_projection: Array = []
	var final_memory_projection: Array = []
	var commit_projection: Array = []
	var total_buy_candidates := 0
	print("AI_CARD_TURN_FALLBACK_AGGREGATE|CALL_STARTED|mode=%s|actor_count=%d" % [mode, actor_indices.size()])
	for actor_index in actor_indices:
		var actor_state_before := actor_state_port.debug_snapshot()
		var turn_scoring_context: Dictionary = {}
		if reuse_turn_context:
			turn_scoring_context = ai.call("_ai_card_turn_scoring_context", actor_index) as Dictionary
		var play_started_msec := Time.get_ticks_msec()
		var play_candidates: Array = []
		if reuse_turn_context:
			play_candidates = ai.call("_ai_card_play_candidates", actor_index, turn_scoring_context) as Array
		else:
			play_candidates = ai.call("_ai_card_play_candidates", actor_index) as Array
		var play_elapsed_msec := Time.get_ticks_msec() - play_started_msec
		var play_choice := ai.call("_ai_pick_candidate", actor_index, play_candidates, false) as Dictionary
		var buy_started_msec := Time.get_ticks_msec()
		var buy_candidates: Array = []
		if reuse_turn_context and play_choice.is_empty():
			buy_candidates = ai.call("_ai_card_buy_candidates", actor_index, turn_scoring_context) as Array
		else:
			buy_candidates = ai.call("_ai_card_buy_candidates", actor_index) as Array
		var buy_elapsed_msec := Time.get_ticks_msec() - buy_started_msec
		total_buy_candidates += buy_candidates.size()
		var projection := _candidate_projection(buy_candidates)
		var ranked := ai.rank_candidates(actor_index, buy_candidates, {"source_context": "fallback_aggregate_performance"})
		var force_rng_before := rng.capture_plan_checkpoint()
		var forced := ai.call("_ai_pick_candidate", actor_index, buy_candidates, true) as Dictionary
		var force_rng_after := rng.capture_plan_checkpoint()
		var normal_checkpoint := rng.capture_plan_checkpoint()
		var normal := ai.call("_ai_pick_candidate", actor_index, buy_candidates, false) as Dictionary
		var normal_terminal := rng.capture_plan_checkpoint()
		var restored := rng.restore_plan_checkpoint(normal_checkpoint)
		var normal_replay := ai.call("_ai_pick_candidate", actor_index, buy_candidates, false) as Dictionary
		var normal_replay_terminal := rng.capture_plan_checkpoint()
		var reset_after_replay := rng.restore_plan_checkpoint(normal_checkpoint)
		var final_memory := ai.call("_ai_memory_for_player", actor_index) as Dictionary
		var final_memory_sha256 := JSON.stringify(_canonicalize(final_memory)).sha256_text()
		var actor_state_after := actor_state_port.debug_snapshot()
		var actor_query_delta := int(actor_state_after.get("ai_state_query_count", 0)) - int(actor_state_before.get("ai_state_query_count", 0))
		var actor_commit_delta := int(actor_state_after.get("state_commit_count", 0)) - int(actor_state_before.get("state_commit_count", 0))
		_expect(play_candidates.is_empty() and play_choice.is_empty(), "actor %d reaches fallback buy only after evaluated play candidates are empty" % actor_index)
		_expect(not buy_candidates.is_empty(), "actor %d exposes fallback buy candidates" % actor_index)
		_expect(force_rng_after == force_rng_before, "actor %d fallback force selection consumes zero RNG" % actor_index)
		_expect(bool(restored.get("restored", false)) and bool(reset_after_replay.get("restored", false)), "actor %d fallback RNG checkpoints restore" % actor_index)
		_expect(_candidate_projection_row(normal) == _candidate_projection_row(normal_replay), "actor %d fallback normal selection replays identically" % actor_index)
		_expect(normal_terminal == normal_replay_terminal, "actor %d fallback normal selection reaches the same terminal RNG" % actor_index)
		var actor_summary := {
			"actor_index": actor_index,
			"play_elapsed_msec": play_elapsed_msec,
			"buy_elapsed_msec": buy_elapsed_msec,
			"ai_state_query_delta": actor_query_delta,
			"state_commit_delta": actor_commit_delta,
			"play_candidate_count": play_candidates.size(),
			"buy_candidate_count": buy_candidates.size(),
			"projection_sha256": JSON.stringify(projection).sha256_text(),
			"original_order_sha256": JSON.stringify(_candidate_order(projection)).sha256_text(),
			"ranked_order_sha256": JSON.stringify(_candidate_order(_candidate_projection(ranked))).sha256_text(),
			"force_selection_sha256": JSON.stringify(_candidate_projection_row(forced)).sha256_text(),
			"normal_selection_sha256": JSON.stringify(_candidate_projection_row(normal)).sha256_text(),
			"normal_terminal_sha256": JSON.stringify(normal_terminal).sha256_text(),
			"final_memory_sha256": final_memory_sha256,
		}
		actor_summaries.append(actor_summary)
		semantic_projection.append({
			"actor_index": actor_index,
			"play_candidate_count": play_candidates.size(),
			"buy_candidate_count": buy_candidates.size(),
			"projection_sha256": str(actor_summary.get("projection_sha256", "")),
			"original_order_sha256": str(actor_summary.get("original_order_sha256", "")),
			"ranked_order_sha256": str(actor_summary.get("ranked_order_sha256", "")),
			"force_selection_sha256": str(actor_summary.get("force_selection_sha256", "")),
			"normal_selection_sha256": str(actor_summary.get("normal_selection_sha256", "")),
			"normal_terminal_sha256": str(actor_summary.get("normal_terminal_sha256", "")),
		})
		final_memory_projection.append({
			"actor_index": actor_index,
			"final_memory_sha256": final_memory_sha256,
		})
		commit_projection.append({
			"actor_index": actor_index,
			"state_commit_delta": actor_commit_delta,
		})
	var elapsed_msec := Time.get_ticks_msec() - started_msec
	var state_after := actor_state_port.debug_snapshot()
	var rng_after := rng.capture_plan_checkpoint()
	var query_delta := int(state_after.get("ai_state_query_count", 0)) - int(state_before.get("ai_state_query_count", 0))
	var commit_delta := int(state_after.get("state_commit_count", 0)) - int(state_before.get("state_commit_count", 0))
	var semantic_sha256 := JSON.stringify(semantic_projection).sha256_text()
	var terminal_sha256 := JSON.stringify(rng_after).sha256_text()
	print(
		"AI_CARD_TURN_FALLBACK_AGGREGATE|CALL_COMPLETED|mode=%s|elapsed_msec=%d|actor_count=%d|buy_candidate_count=%d"
			% [mode, elapsed_msec, actor_indices.size(), total_buy_candidates]
	)
	print(
		"AI_CARD_TURN_FALLBACK_AGGREGATE|QUERY_COUNTERS|mode=%s|ai_state_query_delta=%d|state_commit_delta=%d"
			% [mode, query_delta, commit_delta]
	)
	var result := {
		"mode": mode,
		"elapsed_msec": elapsed_msec,
		"actor_count": actor_indices.size(),
		"buy_candidate_count": total_buy_candidates,
		"ai_state_query_delta": query_delta,
		"state_commit_delta": commit_delta,
		"semantic_sha256": semantic_sha256,
		"terminal_sha256": terminal_sha256,
		"actors": actor_summaries,
		"semantic_projection": semantic_projection,
		"final_memory_projection": final_memory_projection,
		"commit_projection": commit_projection,
		"rng_checkpoint": rng_after,
	}
	print("AI_CARD_TURN_FALLBACK_AGGREGATE|SAFE_SUMMARY|%s" % JSON.stringify(result))
	_expect(rng_after == rng_before, "three-AI fallback characterization restores the original RNG checkpoint")
	return result


func _verify_turn_context_scope() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/runtime/ai_runtime_controller.gd")
	var function_start := source.find("func _ai_execute_card_turn(")
	var function_end := source.find("\nfunc ", function_start + 1)
	var body := source.substr(function_start, function_end - function_start) \
		if function_start >= 0 and function_end > function_start else ""
	var queue_attempt_at := body.find("if not play_choice.is_empty():")
	var fresh_context_at := body.find("var fallback_discard_scoring_context: Dictionary = {}")
	var empty_choice_reuse_at := body.find("if play_choice.is_empty():", fresh_context_at)
	var buy_call_at := body.find("_ai_card_buy_candidates(player_index, fallback_discard_scoring_context)")
	_expect(
		queue_attempt_at >= 0 \
			and fresh_context_at > queue_attempt_at \
			and empty_choice_reuse_at > fresh_context_at \
			and buy_call_at > empty_choice_reuse_at,
		"turn-local context reaches fallback buy only through the empty play-choice branch"
	)
	_expect(
		body.find("fallback_discard_scoring_context = turn_play_scoring_context", empty_choice_reuse_at) >= empty_choice_reuse_at,
		"a failed queue attempt retains the fresh fallback context instead of the dynamic play context"
	)


func _prepare_authoritative_discard_pressure_fixture(
	coordinator: GameRuntimeCoordinator,
	player_index: int
) -> Dictionary:
	var inventory := coordinator.commodity_card_inventory_runtime_controller()
	var actor_mapping := coordinator.actor_id_for_player_index(player_index)
	var actor_id := str(actor_mapping.get("actor_id", ""))
	if inventory == null or not bool(actor_mapping.get("available", false)) or actor_id.is_empty():
		return {"prepared": false}
	var grant_count := 0
	for grant_index in range(8):
		var player := inventory.player_snapshot(actor_id)
		var inventory_state: Dictionary = player.get("inventory", {}) \
			if player.get("inventory", {}) is Dictionary else {}
		var hand_limit := int(inventory_state.get("hand_limit", HAND_SIZE))
		var counted_hand := _counted_inventory_size(inventory_state)
		if counted_hand >= hand_limit:
			var preview := inventory.region_supply_receive_preview(actor_id, FULL_HAND_CARD_ID)
			return {
				"prepared": counted_hand == hand_limit \
					and bool(preview.get("requires_discard", false)) \
					and not (preview.get("discardable_slots", []) as Array).is_empty(),
				"actor_id": actor_id,
				"hand_limit": hand_limit,
				"counted_hand": counted_hand,
				"grant_count": grant_count,
			}
		var grant := inventory.grant_card(
			actor_id,
			FULL_HAND_CARD_ID,
			int(player.get("revision", -1)),
			"queue-failure-discard-pressure-%d" % grant_index,
			"focused_queue_failure"
		)
		if not bool(grant.get("committed", false)):
			return {"prepared": false, "grant_count": grant_count}
		grant_count += 1
	return {"prepared": false, "grant_count": grant_count}


func _invalidate_queue_failure_cached_slot(
	request: Dictionary,
	world: WorldSessionState,
	player_index: int
) -> Dictionary:
	if player_index < 0 or player_index >= world.players.size() \
			or not (world.players[player_index] is Dictionary):
		return {"mutated": false}
	var players := world.players.duplicate(true)
	var player := (players[player_index] as Dictionary).duplicate(true)
	var slots: Array = player.get("slots", []) if player.get("slots", []) is Array else []
	var selected_slot := int(request.get("slot_index", -1))
	if slots.size() < 2 or selected_slot < 0 or selected_slot >= slots.size():
		return {"mutated": false}
	var mutated_slot := wrapi(selected_slot + 1, 0, slots.size())
	if not (slots[mutated_slot] is Dictionary):
		return {"mutated": false}
	var card := (slots[mutated_slot] as Dictionary).duplicate(true)
	card["play_requirement_kind"] = "region_gdp_share"
	card["play_region_scope"] = "own_best_region"
	card["play_region_gdp_share_required"] = 100
	slots[mutated_slot] = card
	player["slots"] = slots
	players[player_index] = player
	world.players = players
	return {
		"mutated": true,
		"selected_slot": selected_slot,
		"mutated_slot": mutated_slot,
	}


func _replace_actor_hand(
	coordinator: GameRuntimeCoordinator,
	world: WorldSessionState,
	player_index: int,
	card_id: String,
	force_unplayable: bool = false
) -> bool:
	var definition := coordinator.v06_card_definition(card_id)
	if definition.is_empty() or player_index < 0 or player_index >= world.players.size():
		return false
	var slots: Array = []
	for slot_index in range(HAND_SIZE):
		var card := definition.duplicate(true)
		card["runtime_instance_id"] = "ai-card-play-context-reuse:%d:%d" % [player_index, slot_index]
		card["queued_for_resolution"] = false
		card["cooldown_left"] = 0.0
		card["lock_left"] = 0.0
		if force_unplayable:
			card["play_requirement_kind"] = "region_gdp_share"
			card["play_region_scope"] = "own_best_region"
			card["play_region_gdp_share_required"] = 100
		slots.append(card)
	var players := world.players.duplicate(true)
	var player := (players[player_index] as Dictionary).duplicate(true)
	player["slots"] = slots
	player["cash"] = maxi(1000, int(player.get("cash", 0)))
	player["cash_cents"] = maxi(100000, int(player.get("cash_cents", 0)))
	player["action_cooldown"] = 0.0
	players[player_index] = player
	world.players = players
	var actor_mapping := coordinator.actor_id_for_player_index(player_index)
	var actor_id := str(actor_mapping.get("actor_id", ""))
	var player_state := coordinator.v06_card_player_snapshot(actor_id)
	return bool(actor_mapping.get("available", false)) \
		and _counted_inventory_size(player_state.get("inventory", {}) as Dictionary) == HAND_SIZE


func _counted_inventory_size(inventory: Dictionary) -> int:
	var count := 0
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	for slot_variant in slots:
		if not (slot_variant is Dictionary):
			continue
		var card := slot_variant as Dictionary
		var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
		if bool(machine.get("counts_toward_hand_limit", true)):
			count += 1
	return count


func _candidate_projection(candidates: Array) -> Array:
	var result: Array = []
	for candidate_variant in candidates:
		if candidate_variant is Dictionary:
			result.append(_candidate_projection_row(candidate_variant as Dictionary))
	return result


func _candidate_projection_row(candidate: Dictionary) -> Dictionary:
	return _canonicalize(candidate) as Dictionary


func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var source := value as Dictionary
		var keys: Array = source.keys()
		keys.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
		var result := {}
		for key_variant in keys:
			result[str(key_variant)] = _canonicalize(source[key_variant])
		return result
	if value is Array:
		var result: Array = []
		for item_variant in value as Array:
			result.append(_canonicalize(item_variant))
		return result
	if value is StringName:
		return str(value)
	return value


func _candidate_order(projection: Array) -> Array:
	var result: Array = []
	for candidate_variant in projection:
		if not (candidate_variant is Dictionary):
			continue
		var candidate := candidate_variant as Dictionary
		result.append({
			"action": str(candidate.get("action", "")),
			"card_name": str(candidate.get("card_name", "")),
			"kind": str(candidate.get("kind", "")),
			"policy_kind": str(candidate.get("policy_kind", "")),
			"slot_index": int(candidate.get("slot_index", -1)),
			"district": int(candidate.get("district", -1)),
			"target_slot": int(candidate.get("target_slot", -1)),
			"target_player": int(candidate.get("target_player", -1)),
			"product": str(candidate.get("product", "")),
			"score": int(candidate.get("score", 0)),
		})
	return result


func _compact_final_memory_projection(memory: Dictionary) -> Dictionary:
	return {
		"focus_product": str(memory.get("economic_focus_product", "")),
		"focus_score": int(memory.get("economic_focus_score", 0)),
		"game_phase": str(memory.get("game_phase", "")),
		"competitive_posture": str(memory.get("competitive_posture", "")),
		"score_gap_to_leader": int(memory.get("score_gap_to_leader", 0)),
		"leader_index": int(memory.get("leader_index", -1)),
		"strategy_intent": str(memory.get("strategic_intent", "")),
		"strategy_score": int(memory.get("strategic_intent_score", 0)),
		"route_product": str(memory.get("route_plan_product", "")),
		"route_stage": str(memory.get("route_plan_stage", "")),
		"route_score": int(memory.get("route_plan_score", 0)),
	}


func _first_memory_context_candidate(projection: Array) -> Dictionary:
	for candidate_variant in projection:
		if not (candidate_variant is Dictionary):
			continue
		var candidate := candidate_variant as Dictionary
		if candidate.has("focus_product") \
			and candidate.has("game_phase") \
			and candidate.has("strategy_intent") \
			and candidate.has("route_plan_product"):
			return candidate
	return {}


func _candidate_memory_context_projection(candidate: Dictionary) -> Dictionary:
	return {
		"focus_product": str(candidate.get("focus_product", "")),
		"focus_score": int(candidate.get("focus_score", 0)),
		"game_phase": str(candidate.get("game_phase", "")),
		"competitive_posture": str(candidate.get("competitive_posture", "")),
		"score_gap_to_leader": int(candidate.get("score_gap_to_leader", 0)),
		"leader_index": int(candidate.get("leader_index", -1)),
		"strategy_intent": str(candidate.get("strategy_intent", "")),
		"strategy_score": int(candidate.get("strategy_score", 0)),
		"route_product": str(candidate.get("route_plan_product", "")),
		"route_stage": str(candidate.get("route_plan_stage", "")),
		"route_score": int(candidate.get("route_plan_score", 0)),
	}


func _first_legal_ai_actor(world: WorldSessionState) -> int:
	for player_index in range(world.players.size()):
		var player: Dictionary = world.players[player_index]
		if bool(player.get("is_ai", false)) and not bool(player.get("eliminated", false)):
			return player_index
	return -1


func _legal_ai_actors(world: WorldSessionState) -> Array[int]:
	var result: Array[int] = []
	for player_index in range(world.players.size()):
		var player: Dictionary = world.players[player_index]
		if bool(player.get("is_ai", false)) and not bool(player.get("eliminated", false)):
			result.append(player_index)
	return result


func _cleanup(app_root: Node) -> void:
	if app_root == null:
		return
	for node in app_root.find_children("*", "AudioStreamPlayer", true, false):
		(node as AudioStreamPlayer).stop()
	app_root.queue_free()
	await process_frame


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish(scenario: String) -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("AI_CARD_PLAY_CONTEXT_REUSE_TEST|scenario=%s|status=%s|checks=%d|failures=%d" % [scenario, status, _checks, _failures.size()])
	for failure in _failures:
		push_error("AI_CARD_PLAY_CONTEXT_REUSE_TEST: %s" % failure)
	quit(0 if _failures.is_empty() else 1)
