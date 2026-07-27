extends SceneTree

const SESSION_DRIVER := preload("res://tests/support/production_session_start_driver.gd")
const QA_SAVE_PATH := "user://test_runs/ai_card_play_context_reuse_performance_parity.save"
const SESSION_REQUEST_ID := "ai-card-play-context-reuse-performance-parity"
const DETERMINISTIC_REQUEST_ID := "ai-card-play-context-reuse-performance-parity-deterministic"
const DETERMINISTIC_SESSION_SEED := 2026072501
const FULL_HAND_CARD_ID := "interaction.starlink_dismantle.rank_1"
const QUEUE_FAILURE_HAND_CARD_ID := "interaction.starlink_dismantle.rank_4"
const GENERIC_PRODUCT_CARD_ID := "价格套利1"
const ORDINARY_FUTURES_CARD_ID := "商品看涨1"
const WAREHOUSE_FUTURES_CARD_ID := "港仓囤货1"
const HAND_SIZE := 5
const CALL_LIMIT_MSEC := 80_000
const SATURATED_PLAY_SAMPLE_COUNT := 47

const FULL_HAND_GOLDEN_LOCKED := true
const FULL_HAND_GOLDEN_CANDIDATE_COUNT := 5
const FULL_HAND_GOLDEN_PROJECTION_SHA256 := "f2f9378fd4f0981d759405e8331a38b7a30ec22e5d2f655ba26abfb0c287d64b"
const FULL_HAND_GOLDEN_ORIGINAL_ORDER_SHA256 := "c3104f72e36712720d1ea158b86058ba55099039f79edd302400d83b6b6cf9da"
const FULL_HAND_GOLDEN_RANKED_ORDER_SHA256 := "c3104f72e36712720d1ea158b86058ba55099039f79edd302400d83b6b6cf9da"
const FULL_HAND_GOLDEN_FORCE_SELECTION_SHA256 := "6c4e9b50341a15d2704543a35b445ad82ccefeeac47769fad315d3f2830a729d"
const FULL_HAND_GOLDEN_NORMAL_SELECTION_SHA256 := "6c4e9b50341a15d2704543a35b445ad82ccefeeac47769fad315d3f2830a729d"
const FULL_HAND_GOLDEN_NORMAL_TERMINAL_SHA256 := "31f5a028edcf8c0afb56a4f234ae09de7b1b050ea62e51da6f7a9a9a8006d78e"
const FULL_HAND_GOLDEN_FINAL_MEMORY_SHA256 := "9a1951ceac14f8fdfd28488f9105b2e0c405a5b5b4160666caaa05ec1637c957"
const FULL_HAND_GOLDEN_AI_QUERY_DELTA := 22
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


class CapturingAcceptedPurchase:
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
		return true


var _checks := 0
var _failures: Array[String] = []
var _route_lookup_profile: Dictionary = {}
var _route_hand_inventory_profile: Dictionary = {}


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
	_verify_actor_state_tick_cache_boundary(ai, actor_state_port, actor_index)

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
	_run_saturated_play_turn_route_context_gate(ai, actor_state_port, rng, world, actor_index)
	_run_play_turn_eligibility_queue_guard_gate(ai, coordinator, actor_state_port, rng, world, actor_index)
	_run_play_generic_futures_turn_cache_gate(ai, coordinator, actor_state_port, rng, world, actor_index)
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
		_run_development_route_lookup_context_gate(
			ai,
			coordinator.gameplay_balance_diagnostics_service(),
			actor_state_port,
			rng,
			world,
			actor_indices[0]
		)
		_run_route_hand_inventory_cache_review_gate(ai, actor_state_port, rng, world, actor_indices[0])
		_run_fallback_aggregate(ai, actor_state_port, rng, world, actor_indices)

	await _cleanup(app_root)
	_finish(scenario)


func _verify_actor_state_tick_cache_boundary(
	ai: AiRuntimeController,
	actor_state_port: AiActorStatePort,
	actor_index: int
) -> void:
	var port_before := actor_state_port.debug_snapshot()
	var ai_before := ai.debug_snapshot()
	ai._actor_state_tick_cache.clear()
	ai._actor_state_tick_cache_active = true
	var first := ai.call("_ai_actor_state_snapshot", actor_index) as Dictionary
	var second := ai.call("_ai_actor_state_snapshot", actor_index) as Dictionary
	var profile: Dictionary = (first.get("ai_profile", {}) as Dictionary).duplicate(true)
	var memory: Dictionary = (first.get("ai_memory", {}) as Dictionary).duplicate(true)
	var unchanged_commit := ai.call(
		"_commit_ai_actor_state",
		actor_index,
		profile,
		memory,
		first
	) as Dictionary
	var third := ai.call("_ai_actor_state_snapshot", actor_index) as Dictionary
	ai._actor_state_tick_cache_active = false
	ai._actor_state_tick_cache.clear()
	var port_after := actor_state_port.debug_snapshot()
	var ai_after := ai.debug_snapshot()
	_expect(
		not first.is_empty() and first == second and second == third,
		"one synchronous simulation tick reuses an identical actor-state projection"
	)
	_expect(
		int(port_after.get("ai_state_query_count", 0)) - int(port_before.get("ai_state_query_count", 0)) == 2 \
			and int(ai_after.get("actor_state_tick_cache_hit_count", 0)) - int(ai_before.get("actor_state_tick_cache_hit_count", 0)) == 1 \
			and int(ai_after.get("actor_state_tick_cache_miss_count", 0)) - int(ai_before.get("actor_state_tick_cache_miss_count", 0)) == 2,
		"actor-state cache hits only before a typed commit invalidates the tick lease"
	)
	_expect(
		bool(unchanged_commit.get("accepted", false)) and not bool(unchanged_commit.get("changed", true)),
		"cache invalidation probe uses an accepted no-op typed commit"
	)


func _run_saturated_play_turn_route_context_gate(
	ai: AiRuntimeController,
	actor_state_port: AiActorStatePort,
	rng: RunRngService,
	world: WorldSessionState,
	actor_index: int
) -> void:
	var original_world := world.capture_runtime_checkpoint()
	var original_rng := rng.capture_plan_checkpoint()
	var route_skill := ai.call("_make_skill", FULL_HAND_CARD_ID) as Dictionary
	var skills: Array = []
	for _slot_index in range(HAND_SIZE):
		skills.append(route_skill.duplicate(true))
	var fixture_ready := not route_skill.is_empty() \
		and _warm_and_saturate_play_route(ai, actor_index, route_skill)
	var current_world := world.capture_runtime_checkpoint() if fixture_ready else {}
	var current_rng := rng.capture_plan_checkpoint() if fixture_ready else {}
	var current_pair := _run_play_slot_pair(
		ai,
		actor_state_port,
		rng,
		world,
		actor_index,
		skills,
		current_world,
		current_rng
	) if fixture_ready else {}
	var current_restore := _restore_play_checkpoint(world, rng, current_world, current_rng) \
		if fixture_ready else false
	var route_cycle := int(ai.get("business_cycle_count"))
	var stale_ready := _set_play_route_plan_cycle(world, actor_index, route_cycle - 1) \
		if current_restore else false
	var stale_world := world.capture_runtime_checkpoint() if stale_ready else {}
	var stale_rng := rng.capture_plan_checkpoint() if stale_ready else {}
	var stale_pair := _run_play_slot_pair(
		ai,
		actor_state_port,
		rng,
		world,
		actor_index,
		skills,
		stale_world,
		stale_rng
	) if stale_ready else {}
	var wrong_actor := _run_wrong_actor_turn_context_gate(
		ai,
		rng,
		world,
		actor_index,
		current_world,
		current_rng
	) if fixture_ready else {}

	var current_parity := _play_slot_pair_parity(current_pair)
	var stale_parity := _play_slot_pair_parity(stale_pair)
	var current_baseline := current_pair.get("baseline", {}) as Dictionary
	var current_optimized := current_pair.get("optimized", {}) as Dictionary
	var stale_baseline := stale_pair.get("baseline", {}) as Dictionary
	var stale_optimized := stale_pair.get("optimized", {}) as Dictionary
	var current_commit_zero: bool = int(current_baseline.get("commit_delta", -1)) == 0 \
		and int(current_optimized.get("commit_delta", -1)) == 0
	var stale_commit_once: bool = int(stale_baseline.get("commit_delta", -1)) == 1 \
		and int(stale_optimized.get("commit_delta", -1)) == 1
	var stale_query_reduction := int(stale_baseline.get("query_delta", 0)) \
		- int(stale_optimized.get("query_delta", 0))
	var current_not_regressed: bool = int(current_optimized.get("query_delta", 999999)) \
		<= int(current_baseline.get("query_delta", -1))
	var candidates_nonempty: bool = (current_baseline.get("projection", []) as Array).size() == HAND_SIZE \
		and (current_optimized.get("projection", []) as Array).size() == HAND_SIZE \
		and (stale_baseline.get("projection", []) as Array).size() == HAND_SIZE \
		and (stale_optimized.get("projection", []) as Array).size() == HAND_SIZE
	var transient_context_absent: bool = not bool(current_optimized.get("shared_context_has_actor_state", true)) \
		and not bool(current_optimized.get("shared_context_has_learning_memory", true)) \
		and not bool(stale_optimized.get("shared_context_has_actor_state", true)) \
		and not bool(stale_optimized.get("shared_context_has_learning_memory", true))
	var final_restore := _restore_play_checkpoint(world, rng, original_world, original_rng)
	var world_restored: bool = _canonicalize(world.capture_runtime_checkpoint()) \
		== _canonicalize(original_world)
	var rng_restored: bool = rng.capture_plan_checkpoint() == original_rng
	var gate_passed: bool = fixture_ready \
		and stale_ready \
		and bool(current_parity.get("all", false)) \
		and bool(stale_parity.get("all", false)) \
		and candidates_nonempty \
		and current_commit_zero \
		and stale_commit_once \
		and stale_query_reduction >= 150 \
		and current_not_regressed \
		and transient_context_absent \
		and bool(wrong_actor.get("passed", false)) \
		and final_restore \
		and world_restored \
		and rng_restored

	print("SATURATED_PLAY_TURN_ROUTE_CONTEXT_GATE|status=%s|sample_count=%d|current_baseline_msec=%d|current_optimized_msec=%d|current_baseline_queries=%d|current_optimized_queries=%d|stale_baseline_msec=%d|stale_optimized_msec=%d|stale_baseline_queries=%d|stale_optimized_queries=%d|stale_query_reduction=%d|candidate_parity=%s|order_parity=%s|selection_parity=%s|memory_parity=%s|commit_parity=%s|rng_parity=%s|current_commit_zero=%s|stale_commit_once=%s|transient_context_absent=%s|wrong_actor_immutable=%s|world_restored=%s" % [
		"PASS" if gate_passed else "FAIL",
		SATURATED_PLAY_SAMPLE_COUNT,
		int(current_baseline.get("elapsed_msec", -1)),
		int(current_optimized.get("elapsed_msec", -1)),
		int(current_baseline.get("query_delta", -1)),
		int(current_optimized.get("query_delta", -1)),
		int(stale_baseline.get("elapsed_msec", -1)),
		int(stale_optimized.get("elapsed_msec", -1)),
		int(stale_baseline.get("query_delta", -1)),
		int(stale_optimized.get("query_delta", -1)),
		stale_query_reduction,
		str(bool(current_parity.get("candidate", false)) and bool(stale_parity.get("candidate", false))),
		str(bool(current_parity.get("order", false)) and bool(stale_parity.get("order", false))),
		str(bool(current_parity.get("selection", false)) and bool(stale_parity.get("selection", false))),
		str(bool(current_parity.get("memory", false)) and bool(stale_parity.get("memory", false))),
		str(bool(current_parity.get("commit", false)) and bool(stale_parity.get("commit", false))),
		str(bool(current_parity.get("rng", false)) and bool(stale_parity.get("rng", false))),
		str(current_commit_zero),
		str(stale_commit_once),
		str(transient_context_absent),
		str(bool(wrong_actor.get("passed", false))),
		str(final_restore and world_restored and rng_restored),
	])
	_expect(fixture_ready, "play-turn route fixture keeps 47 decision samples with current focus, strategy, phase, and route")
	_expect(bool(current_parity.get("all", false)), "current route preserves complete candidates, ordering, selection, memory, commits, and RNG")
	_expect(bool(stale_parity.get("all", false)), "stale route preserves complete candidates, ordering, selection, memory, commits, and RNG")
	_expect(candidates_nonempty, "current and stale route A/B paths each emit all five play candidates")
	_expect(current_commit_zero, "current route commits zero times in baseline and optimized paths")
	_expect(stale_commit_once, "stale route commits exactly once in baseline and optimized paths")
	_expect(stale_query_reduction >= 150, "stale shared turn route context removes at least 150 actor-state queries")
	_expect(current_not_regressed, "current shared turn route context does not regress actor-state queries")
	_expect(transient_context_absent, "shared turn context retains no actor state or temporary learning memory")
	_expect(bool(wrong_actor.get("passed", false)), "wrong-actor supplied turn context is immutable and fails closed")
	_expect(final_restore and world_restored and rng_restored, "saturated play-turn route fixture restores complete World and RNG state")


func _warm_and_saturate_play_route(
	ai: AiRuntimeController,
	actor_index: int,
	route_skill: Dictionary
) -> bool:
	var warm_context := ai.call("_ai_card_turn_scoring_context", actor_index) as Dictionary
	var warm_candidate := ai.call(
		"_ai_card_play_context", actor_index, 0, route_skill, warm_context
	) as Dictionary
	if warm_candidate.is_empty():
		return false
	var actor_state := ai.call("_ai_actor_state_snapshot", actor_index) as Dictionary
	if actor_state.is_empty():
		return false
	var memory: Dictionary = (actor_state.get("ai_memory", {}) as Dictionary).duplicate(true)
	var samples: Array = []
	for sample_index in range(SATURATED_PLAY_SAMPLE_COUNT):
		samples.append({
			"time": float(sample_index),
			"cycle": sample_index,
			"kind": "play",
			"target": sample_index % 4,
			"score": 2000 + sample_index,
			"reason": "saturated-play-turn-route-context",
			"state": {
				"cash": 2000 + sample_index,
				"active_city_count": 2,
				"total_product_flow": 12,
				"game_phase": str(memory.get("game_phase", "midgame")),
			},
			"candidates": [],
			"focus_product": str(memory.get("economic_focus_product", "")),
			"strategy_intent": str(memory.get("strategic_intent", "")),
			"route_plan_product": str(memory.get("route_plan_product", "")),
			"route_plan_stage": str(memory.get("route_plan_stage", "")),
			"reward_finalized": false,
			"learning_applied": false,
		})
	memory["decision_samples"] = samples
	var commit := ai.call("_commit_ai_memory", actor_index, memory, actor_state) as Dictionary
	if not bool(commit.get("accepted", false)):
		return false
	var stored_memory := ai.call("_ai_memory_for_player", actor_index) as Dictionary
	var current_cycle := int(ai.get("business_cycle_count"))
	return (stored_memory.get("decision_samples", []) as Array).size() == SATURATED_PLAY_SAMPLE_COUNT \
		and int(stored_memory.get("economic_focus_cycle", -1)) == current_cycle \
		and int(stored_memory.get("strategic_intent_cycle", -1)) == current_cycle \
		and int(stored_memory.get("route_plan_cycle", -1)) == current_cycle \
		and not str(stored_memory.get("economic_focus_product", "")).is_empty() \
		and not str(stored_memory.get("strategic_intent", "")).is_empty() \
		and not str(stored_memory.get("route_plan_product", "")).is_empty() \
		and not str(stored_memory.get("route_plan_stage", "")).is_empty()


func _set_play_route_plan_cycle(
	world: WorldSessionState,
	actor_index: int,
	route_cycle: int
) -> bool:
	if actor_index < 0 or actor_index >= world.players.size() \
			or not (world.players[actor_index] is Dictionary):
		return false
	var players := world.players.duplicate(true)
	var player := (players[actor_index] as Dictionary).duplicate(true)
	var memory: Dictionary = (player.get("ai_memory", {}) as Dictionary).duplicate(true)
	memory["route_plan_cycle"] = route_cycle
	player["ai_memory"] = memory
	players[actor_index] = player
	world.players = players
	return true


func _run_play_turn_eligibility_queue_guard_gate(
	ai: AiRuntimeController,
	coordinator: GameRuntimeCoordinator,
	actor_state_port: AiActorStatePort,
	rng: RunRngService,
	world: WorldSessionState,
	actor_index: int
) -> void:
	var queue := coordinator.get_node_or_null("CardResolutionQueueRuntimeService") as CardResolutionQueueRuntimeService
	_expect(queue != null, "play-turn eligibility fixture uses the production card-resolution queue owner")
	if queue == null:
		print("PLAY_TURN_ELIGIBILITY_QUEUE_GUARD_GATE|status=FAIL|reason=queue_owner_missing")
		return
	var original_world := world.capture_runtime_checkpoint()
	var original_rng := rng.capture_plan_checkpoint()
	var original_queue := queue.capture_runtime_checkpoint()
	var stale_cycle := int(ai.get("business_cycle_count")) - 1

	var inactive_ready := _set_play_guard_fixture(world, actor_index, stale_cycle, 1.0)
	var inactive_facts := ai.call("_actor_decision_economy_facts", actor_index) as Dictionary \
		if inactive_ready else {}
	var inactive_world := world.capture_runtime_checkpoint() if inactive_ready else {}
	var inactive_rng := rng.capture_plan_checkpoint() if inactive_ready else {}
	var inactive_memory := _world_actor_memory(world, actor_index) if inactive_ready else {}
	var inactive_state_before := actor_state_port.debug_snapshot()
	var inactive_result := str(ai.call("_ai_execute_card_turn", actor_index, false)) \
		if inactive_ready else "fixture_failed"
	var inactive_state_after := actor_state_port.debug_snapshot()
	var inactive_commit_delta := int(inactive_state_after.get("state_commit_count", 0)) \
		- int(inactive_state_before.get("state_commit_count", 0))
	var inactive_world_unchanged: bool = inactive_ready \
		and _canonicalize(world.capture_runtime_checkpoint()) == _canonicalize(inactive_world)
	var inactive_memory_unchanged: bool = inactive_ready \
		and _canonicalize(_world_actor_memory(world, actor_index)) == _canonicalize(inactive_memory)
	var inactive_rng_unchanged: bool = inactive_ready \
		and rng.capture_plan_checkpoint() == inactive_rng
	var inactive_passed: bool = inactive_ready \
		and not bool(inactive_facts.get("action_ready", true)) \
		and inactive_result == "wait" \
		and inactive_commit_delta == 0 \
		and inactive_world_unchanged \
		and inactive_memory_unchanged \
		and inactive_rng_unchanged

	var queued_base_restore := _restore_play_checkpoint(world, rng, original_world, original_rng)
	var queued_fixture_ready := queued_base_restore \
		and _set_play_guard_fixture(world, actor_index, stale_cycle, 0.0)
	queue.restore_runtime_checkpoint(original_queue)
	queue.replace_current_queue([_play_guard_queue_entry(actor_index)])
	queued_fixture_ready = queued_fixture_ready \
		and queue.entry_index_for_player(actor_index) >= 0
	var queued_world := world.capture_runtime_checkpoint() if queued_fixture_ready else {}
	var queued_rng := rng.capture_plan_checkpoint() if queued_fixture_ready else {}
	var queued_queue := queue.capture_runtime_checkpoint() if queued_fixture_ready else {}
	var queued_memory := _world_actor_memory(world, actor_index) if queued_fixture_ready else {}
	var structural_context := _new_structural_play_context(actor_index)
	var structural_context_before: Variant = _canonicalize(structural_context.duplicate(true))
	var queued_state_before := actor_state_port.debug_snapshot()
	var queued_candidates := ai.call(
		"_ai_card_play_candidates", actor_index, structural_context
	) as Array if queued_fixture_ready else []
	var queued_state_after := actor_state_port.debug_snapshot()
	var queued_commit_delta := int(queued_state_after.get("state_commit_count", 0)) \
		- int(queued_state_before.get("state_commit_count", 0))
	var structural_context_unchanged: bool = _canonicalize(structural_context) == structural_context_before \
		and not structural_context.has("focus_product") \
		and not structural_context.has("strategy") \
		and not structural_context.has("route_plan")
	var queued_guard_passed: bool = queued_fixture_ready \
		and queued_candidates.is_empty() \
		and structural_context_unchanged \
		and queued_commit_delta == 0 \
		and _canonicalize(_world_actor_memory(world, actor_index)) == _canonicalize(queued_memory) \
		and _canonicalize(world.capture_runtime_checkpoint()) == _canonicalize(queued_world) \
		and rng.capture_plan_checkpoint() == queued_rng \
		and _canonicalize(queue.capture_runtime_checkpoint()) == _canonicalize(queued_queue)

	var execute_restore := _restore_play_checkpoint(world, rng, original_world, original_rng)
	var execute_queue_restore := bool(queue.restore_runtime_checkpoint(original_queue).get("restored", false))
	var execute_fixture_ready := execute_restore \
		and execute_queue_restore \
		and _set_play_guard_fixture(world, actor_index, stale_cycle, 0.0)
	queue.replace_current_queue([_play_guard_queue_entry(actor_index)])
	execute_fixture_ready = execute_fixture_ready \
		and queue.entry_index_for_player(actor_index) >= 0
	var execute_world := world.capture_runtime_checkpoint() if execute_fixture_ready else {}
	var execute_rng := rng.capture_plan_checkpoint() if execute_fixture_ready else {}
	var execute_queue := queue.capture_runtime_checkpoint() if execute_fixture_ready else {}
	var reference_state_before := actor_state_port.debug_snapshot()
	var reference_candidates := ai.call("_ai_card_buy_candidates", actor_index, {}) as Array \
		if execute_fixture_ready else []
	var reference_choice := ai.call("_ai_pick_candidate", actor_index, reference_candidates, false) as Dictionary \
		if execute_fixture_ready else {}
	var reference_state_after := actor_state_port.debug_snapshot()
	var reference_commit_delta := int(reference_state_after.get("state_commit_count", 0)) \
		- int(reference_state_before.get("state_commit_count", 0))
	var reference_rng := rng.capture_plan_checkpoint() if execute_fixture_ready else {}
	var reference_receipt := {
		"player_index": actor_index,
		"district": int(reference_choice.get("district", -1)),
		"card_name": str(reference_choice.get("card_name", "")),
		"discard_slot": int(reference_choice.get("discard_slot", -1)),
		"request_id": "",
	}

	var production_world_restore := world.restore_runtime_checkpoint(execute_world) \
		if execute_fixture_ready else {}
	var production_rng_restore := rng.restore_plan_checkpoint(execute_rng) \
		if execute_fixture_ready else {}
	var production_queue_restore := queue.restore_runtime_checkpoint(execute_queue) \
		if execute_fixture_ready else {}
	var original_purchase := coordinator.district_supply_action_port()
	var accepting_purchase := CapturingAcceptedPurchase.new()
	root.add_child(accepting_purchase)
	ai.set_district_supply_action_port(accepting_purchase)
	var production_state_before := actor_state_port.debug_snapshot()
	var production_result := str(ai.call("_ai_execute_card_turn", actor_index, false)) \
		if execute_fixture_ready else "fixture_failed"
	var production_state_after := actor_state_port.debug_snapshot()
	var production_commit_delta := int(production_state_after.get("state_commit_count", 0)) \
		- int(production_state_before.get("state_commit_count", 0))
	var production_rng := rng.capture_plan_checkpoint() if execute_fixture_ready else {}
	var production_queue_unchanged: bool = execute_fixture_ready \
		and _canonicalize(queue.capture_runtime_checkpoint()) == _canonicalize(execute_queue)
	ai.set_district_supply_action_port(original_purchase)
	accepting_purchase.queue_free()
	var queued_execute_passed: bool = execute_fixture_ready \
		and bool(production_world_restore.get("applied", false)) \
		and bool(production_rng_restore.get("restored", false)) \
		and bool(production_queue_restore.get("restored", false)) \
		and not reference_candidates.is_empty() \
		and not reference_choice.is_empty() \
		and production_result == "buy" \
		and accepting_purchase.submit_count == 1 \
		and accepting_purchase.last_purchase == reference_receipt \
		and production_commit_delta == reference_commit_delta + 1 \
		and production_rng == reference_rng \
		and production_queue_unchanged

	var final_world_restore := world.restore_runtime_checkpoint(original_world)
	var final_rng_restore := rng.restore_plan_checkpoint(original_rng)
	var final_queue_restore := queue.restore_runtime_checkpoint(original_queue)
	var final_restore: bool = bool(final_world_restore.get("applied", false)) \
		and bool(final_rng_restore.get("restored", false)) \
		and bool(final_queue_restore.get("restored", false)) \
		and _canonicalize(world.capture_runtime_checkpoint()) == _canonicalize(original_world) \
		and rng.capture_plan_checkpoint() == original_rng \
		and _canonicalize(queue.capture_runtime_checkpoint()) == _canonicalize(original_queue)
	var gate_passed := inactive_passed and queued_guard_passed and queued_execute_passed and final_restore
	print("PLAY_TURN_ELIGIBILITY_QUEUE_GUARD_GATE|status=%s|inactive_result=%s|inactive_commits=%d|queued_candidates=%d|queued_commits=%d|queued_context_unchanged=%s|queued_execute_result=%s|reference_buy_candidates=%d|reference_commits=%d|production_commits=%d|purchase_receipt_parity=%s|rng_parity=%s|restored=%s" % [
		"PASS" if gate_passed else "FAIL",
		inactive_result,
		inactive_commit_delta,
		queued_candidates.size(),
		queued_commit_delta,
		str(structural_context_unchanged),
		production_result,
		reference_candidates.size(),
		reference_commit_delta,
		production_commit_delta,
		str(accepting_purchase.last_purchase == reference_receipt),
		str(production_rng == reference_rng),
		str(final_restore),
	])
	_expect(inactive_passed, "action-ready false returns wait without AI-memory, World, or RNG mutation despite stale learning cycles")
	_expect(queued_guard_passed, "queued play eligibility returns no candidates without preparing or mutating the supplied structural context")
	_expect(queued_execute_passed, "a complete queued AI turn still prepares the fresh buy path once and preserves purchase receipt and RNG parity")
	_expect(final_restore, "play-turn eligibility and queue fixtures restore complete World, queue, and RNG state")


func _set_play_guard_fixture(
	world: WorldSessionState,
	actor_index: int,
	stale_cycle: int,
	action_cooldown: float
) -> bool:
	if actor_index < 0 or actor_index >= world.players.size() \
			or not (world.players[actor_index] is Dictionary):
		return false
	var players := world.players.duplicate(true)
	var player := (players[actor_index] as Dictionary).duplicate(true)
	var memory: Dictionary = (player.get("ai_memory", {}) as Dictionary).duplicate(true)
	memory["economic_focus_cycle"] = stale_cycle
	memory["strategic_intent_cycle"] = stale_cycle
	memory["route_plan_cycle"] = stale_cycle
	player["ai_memory"] = memory
	player["action_cooldown"] = action_cooldown
	players[actor_index] = player
	world.players = players
	return float((world.players[actor_index] as Dictionary).get("action_cooldown", -1.0)) \
		== action_cooldown \
		and int(_world_actor_memory(world, actor_index).get("economic_focus_cycle", 0)) == stale_cycle \
		and int(_world_actor_memory(world, actor_index).get("strategic_intent_cycle", 0)) == stale_cycle \
		and int(_world_actor_memory(world, actor_index).get("route_plan_cycle", 0)) == stale_cycle


func _world_actor_memory(world: WorldSessionState, actor_index: int) -> Dictionary:
	if actor_index < 0 or actor_index >= world.players.size() \
			or not (world.players[actor_index] is Dictionary):
		return {}
	var player := world.players[actor_index] as Dictionary
	return (player.get("ai_memory", {}) as Dictionary).duplicate(true) \
		if player.get("ai_memory", {}) is Dictionary else {}


func _new_structural_play_context(actor_index: int) -> Dictionary:
	return {
		"cache_active": true,
		"player_index": actor_index,
		"slot_play_contexts": {},
		"district_focus_score_by_index": {},
	}


func _play_guard_queue_entry(actor_index: int) -> Dictionary:
	return {
		"player_index": actor_index,
		"slot_index": 0,
		"resolution_id": 970001,
		"queued_order": 970001,
		"skill": {"name": "play-turn-eligibility-guard"},
	}


func _run_wrong_actor_turn_context_gate(
	ai: AiRuntimeController,
	rng: RunRngService,
	world: WorldSessionState,
	actor_index: int,
	world_checkpoint: Dictionary,
	rng_checkpoint: Dictionary
) -> Dictionary:
	var restore_ready := _restore_play_checkpoint(world, rng, world_checkpoint, rng_checkpoint)
	var wrong_context := {
		"cache_active": true,
		"player_index": actor_index + 1,
		"slot_play_contexts": {},
		"district_focus_score_by_index": {},
		"route_plan": {"product": "__wrong_actor_route__", "stage": "attack_rival"},
		"route_product": "__wrong_actor_route__",
		"route_stage": "attack_rival",
		"actor_state": {"player_index": actor_index + 1, "poison": true},
		"learning_memory": {"poison": true},
	}
	var wrong_before: Variant = _canonicalize(wrong_context.duplicate(true))
	var result := ai.call("_ai_card_turn_scoring_context", actor_index, wrong_context) as Dictionary \
		if restore_ready else {}
	var wrong_unchanged: bool = _canonicalize(wrong_context) == wrong_before
	var result_safe: bool = int(result.get("player_index", -1)) == actor_index \
		and result.get("route_plan") is Dictionary \
		and not result.has("actor_state") \
		and not result.has("learning_memory") \
		and str(result.get("route_product", "")) != "__wrong_actor_route__"
	var world_unchanged: bool = _canonicalize(world.capture_runtime_checkpoint()) \
		== _canonicalize(world_checkpoint)
	var rng_unchanged: bool = rng.capture_plan_checkpoint() == rng_checkpoint
	var final_restore := _restore_play_checkpoint(world, rng, world_checkpoint, rng_checkpoint)
	return {
		"passed": restore_ready \
			and wrong_unchanged \
			and result_safe \
			and world_unchanged \
			and rng_unchanged \
			and final_restore,
		"wrong_unchanged": wrong_unchanged,
		"result_safe": result_safe,
	}


func _run_play_generic_futures_turn_cache_gate(
	ai: AiRuntimeController,
	coordinator: GameRuntimeCoordinator,
	actor_state_port: AiActorStatePort,
	rng: RunRngService,
	world: WorldSessionState,
	actor_index: int
) -> void:
	var original_world := world.capture_runtime_checkpoint()
	var original_rng := rng.capture_plan_checkpoint()
	var generic_skill := ai.call("_make_skill", GENERIC_PRODUCT_CARD_ID) as Dictionary
	var ordinary_futures_skill := ai.call("_make_skill", ORDINARY_FUTURES_CARD_ID) as Dictionary
	var warehouse_futures_skill := ai.call("_make_skill", WAREHOUSE_FUTURES_CARD_ID) as Dictionary
	var skills_ready := not generic_skill.is_empty() \
		and not ordinary_futures_skill.is_empty() \
		and not warehouse_futures_skill.is_empty()
	_expect(skills_ready, "play-cache fixture resolves generic, ordinary-futures, and warehouse-futures skills")
	if not skills_ready:
		print("PLAY_GENERIC_FUTURES_TURN_CACHE_GATE|status=FAIL|reason=skills_unavailable")
		return

	var ordinary_pair := _run_play_slot_pair(
		ai,
		actor_state_port,
		rng,
		world,
		actor_index,
		[generic_skill, ordinary_futures_skill],
		original_world,
		original_rng
	)
	var ordinary_parity := _play_slot_pair_parity(ordinary_pair)
	var wrong_actor := _run_wrong_actor_play_context_gate(
		ai,
		actor_state_port,
		rng,
		world,
		actor_index,
		ordinary_futures_skill,
		original_world,
		original_rng
	)
	var empty_plan := _run_empty_plan_play_context_gate(
		ai,
		coordinator,
		actor_state_port,
		rng,
		world,
		actor_index,
		generic_skill,
		ordinary_futures_skill,
		original_world,
		original_rng
	)

	var pre_warehouse_restore := _restore_play_checkpoint(world, rng, original_world, original_rng)
	var warehouse_fixture := _install_empty_play_warehouse_city(coordinator, world, actor_index) \
		if pre_warehouse_restore else {}
	var warehouse_ready := bool(warehouse_fixture.get("ready", false))
	var warehouse_world := world.capture_runtime_checkpoint() if warehouse_ready else {}
	var warehouse_rng := rng.capture_plan_checkpoint() if warehouse_ready else {}
	var warehouse_pair := _run_play_slot_pair(
		ai,
		actor_state_port,
		rng,
		world,
		actor_index,
		[warehouse_futures_skill],
		warehouse_world,
		warehouse_rng
	) if warehouse_ready else {}
	var warehouse_parity := _play_slot_pair_parity(warehouse_pair)
	var warehouse_candidate_contract := _warehouse_play_pair_contract(
		warehouse_pair,
		int(warehouse_fixture.get("district_index", -1))
	)
	var final_restore := _restore_play_checkpoint(world, rng, original_world, original_rng)
	coordinator.refresh_route_network(true)
	var world_restored: bool = _canonicalize(world.capture_runtime_checkpoint()) \
		== _canonicalize(original_world)
	var rng_restored: bool = rng.capture_plan_checkpoint() == original_rng

	var ordinary_baseline := ordinary_pair.get("baseline", {}) as Dictionary
	var ordinary_optimized := ordinary_pair.get("optimized", {}) as Dictionary
	var warehouse_optimized := warehouse_pair.get("optimized", {}) as Dictionary
	var ordinary_query_reduction: bool = int(ordinary_optimized.get("query_delta", 0)) \
		< int(ordinary_baseline.get("query_delta", 0))
	var turn_context_isolated: bool = not bool(ordinary_optimized.get("shared_context_has_futures_plan", true)) \
		and not bool(warehouse_optimized.get("shared_context_has_futures_plan", true))
	var gate_passed: bool = bool(ordinary_parity.get("all", false)) \
		and bool(warehouse_parity.get("all", false)) \
		and bool(warehouse_candidate_contract.get("passed", false)) \
		and ordinary_query_reduction \
		and turn_context_isolated \
		and bool(wrong_actor.get("passed", false)) \
		and bool(empty_plan.get("passed", false)) \
		and warehouse_ready \
		and final_restore \
		and world_restored \
		and rng_restored

	print("PLAY_GENERIC_FUTURES_TURN_CACHE_GATE|status=%s|baseline_msec=%d|optimized_msec=%d|baseline_queries=%d|optimized_queries=%d|query_reduction=%d|candidate_parity=%s|order_parity=%s|selection_parity=%s|score_reason_parity=%s|memory_parity=%s|commit_parity=%s|rng_parity=%s|warehouse_parity=%s|wrong_actor_fail_closed=%s|empty_plan_final_refresh=%s|world_restored=%s" % [
		"PASS" if gate_passed else "FAIL",
		int(ordinary_baseline.get("elapsed_msec", -1)),
		int(ordinary_optimized.get("elapsed_msec", -1)),
		int(ordinary_baseline.get("query_delta", -1)),
		int(ordinary_optimized.get("query_delta", -1)),
		int(ordinary_baseline.get("query_delta", 0)) - int(ordinary_optimized.get("query_delta", 0)),
		str(bool(ordinary_parity.get("candidate", false))),
		str(bool(ordinary_parity.get("order", false))),
		str(bool(ordinary_parity.get("selection", false))),
		str(bool(ordinary_parity.get("score_reason", false))),
		str(bool(ordinary_parity.get("memory", false))),
		str(bool(ordinary_parity.get("commit", false))),
		str(bool(ordinary_parity.get("rng", false))),
		str(bool(warehouse_parity.get("all", false))),
		str(bool(wrong_actor.get("passed", false))),
		str(bool(empty_plan.get("passed", false))),
		str(world_restored and rng_restored),
	])
	print("PLAY_WAREHOUSE_CANDIDATE_GATE|status=%s|fixture_district=%d|baseline_count=%d|optimized_count=%d|baseline_required=%s|optimized_required=%s|baseline_city=%d|optimized_city=%d" % [
		"PASS" if bool(warehouse_candidate_contract.get("passed", false)) else "FAIL",
		int(warehouse_fixture.get("district_index", -1)),
		int(warehouse_candidate_contract.get("baseline_count", 0)),
		int(warehouse_candidate_contract.get("optimized_count", 0)),
		str(bool(warehouse_candidate_contract.get("baseline_required", false))),
		str(bool(warehouse_candidate_contract.get("optimized_required", false))),
		int(warehouse_candidate_contract.get("baseline_city", -1)),
		int(warehouse_candidate_contract.get("optimized_city", -1)),
	])
	_expect(bool(ordinary_parity.get("all", false)), "generic product and ordinary futures preserve candidates, order, selection, score, reason, memory, commits, and RNG")
	_expect(ordinary_query_reduction, "shared play-turn context reduces generic/futures actor-state queries")
	_expect(bool(warehouse_fixture.get("source_city_empty", false)), "warehouse play fixture writes only to a previously empty city district")
	_expect(bool(warehouse_fixture.get("topology_valid", false)), "warehouse play fixture preserves region ID topology and becomes RouteNetwork-active")
	_expect(bool(warehouse_parity.get("all", false)), "warehouse futures preserves candidate, selection, memory, commit, and RNG parity")
	_expect(bool(warehouse_candidate_contract.get("passed", false)), "warehouse baseline and optimized each emit a required warehouse candidate targeting the fixture district")
	_expect(turn_context_isolated, "candidate-local futures plans never write into the shared play-turn context")
	_expect(bool(wrong_actor.get("passed", false)), "wrong-actor play context fails closed without mutation or poison leakage")
	_expect(bool(empty_plan.get("flow_city_ready", false)), "final-plan fixture installs one legal actor-owned flow city on previously empty land")
	_expect(bool(empty_plan.get("fixture_ready", false)), "final-plan fixture finds a legal flow correction whose initial and final futures products differ")
	_expect(bool(empty_plan.get("selection_tie_verified", false)), "initial route product and flow-corrected product are tied before preferred-order resolution")
	_expect(bool(empty_plan.get("products_changed", false)), "flow correction changes the futures product before final candidate scoring")
	_expect(bool(empty_plan.get("generic_scores_distinguish_plans", false)), "initial and final futures plans produce distinct generic scores for the same candidate inputs")
	_expect(bool(empty_plan.get("final_plan_matches_candidate", false)), "candidate futures fields match the flow-corrected final plan")
	_expect(bool(empty_plan.get("fixture_restored", false)), "flow-correction fixture restores the complete original World and RNG checkpoint")
	_expect(bool(empty_plan.get("passed", false)), "explicit empty shared plan remains unchanged while final refreshed plan scores the candidate")
	_expect(final_restore and world_restored and rng_restored, "play-cache fixtures restore the complete original world and RNG checkpoint")


func _run_play_slot_pair(
	ai: AiRuntimeController,
	actor_state_port: AiActorStatePort,
	rng: RunRngService,
	world: WorldSessionState,
	actor_index: int,
	skills: Array,
	world_checkpoint: Dictionary,
	rng_checkpoint: Dictionary
) -> Dictionary:
	var baseline_restore := _restore_play_checkpoint(world, rng, world_checkpoint, rng_checkpoint)
	var baseline := _measure_play_slot_path(ai, actor_state_port, rng, actor_index, skills, false) \
		if baseline_restore else {}
	var optimized_restore := _restore_play_checkpoint(world, rng, world_checkpoint, rng_checkpoint)
	var optimized := _measure_play_slot_path(ai, actor_state_port, rng, actor_index, skills, true) \
		if optimized_restore else {}
	var final_restore := _restore_play_checkpoint(world, rng, world_checkpoint, rng_checkpoint)
	_expect(baseline_restore and optimized_restore and final_restore, "play-slot pair restores world and RNG around both paths")
	return {"baseline": baseline, "optimized": optimized}


func _measure_play_slot_path(
	ai: AiRuntimeController,
	actor_state_port: AiActorStatePort,
	rng: RunRngService,
	actor_index: int,
	skills: Array,
	optimized: bool
) -> Dictionary:
	var state_before := actor_state_port.debug_snapshot()
	var rng_before := rng.capture_plan_checkpoint()
	var started_msec := Time.get_ticks_msec()
	var turn_context := ai.call("_ai_card_turn_scoring_context", actor_index) as Dictionary \
		if optimized else {}
	var candidates: Array = []
	for slot_index in range(skills.size()):
		var skill := skills[slot_index] as Dictionary
		var candidate := ai.call(
			"_ai_card_play_context",
			actor_index,
			slot_index,
			skill,
			turn_context if optimized else {}
		) as Dictionary
		if not candidate.is_empty():
			candidates.append(candidate)
	var elapsed_msec := Time.get_ticks_msec() - started_msec
	var state_after_candidates := actor_state_port.debug_snapshot()
	var projection := _candidate_projection(candidates)
	var original_order := _candidate_order(projection)
	var ranked := ai.rank_candidates(actor_index, candidates, {"source_context": "play_generic_futures_turn_cache"})
	var ranked_order := _candidate_order(_candidate_projection(ranked))
	var forced_selection := ai.call("_ai_pick_candidate", actor_index, candidates, true) as Dictionary
	var normal_selection := ai.call("_ai_pick_candidate", actor_index, candidates, false) as Dictionary
	var memory := ai.call("_ai_memory_for_player", actor_index) as Dictionary
	var state_after := actor_state_port.debug_snapshot()
	return {
		"elapsed_msec": elapsed_msec,
		"query_delta": int(state_after_candidates.get("ai_state_query_count", 0))
			- int(state_before.get("ai_state_query_count", 0)),
		"commit_delta": int(state_after.get("state_commit_count", 0))
			- int(state_before.get("state_commit_count", 0)),
		"projection": projection,
		"original_order": original_order,
		"ranked_order": ranked_order,
		"forced_selection": _candidate_projection_row(forced_selection),
		"normal_selection": _candidate_projection_row(normal_selection),
		"memory": _canonicalize(memory),
		"rng_before": rng_before,
		"rng_terminal": rng.capture_plan_checkpoint(),
		"shared_context_has_futures_plan": turn_context.has("product_futures_plan"),
		"shared_context_has_actor_state": turn_context.has("actor_state"),
		"shared_context_has_learning_memory": turn_context.has("learning_memory"),
	}


func _play_slot_pair_parity(pair: Dictionary) -> Dictionary:
	var baseline := pair.get("baseline", {}) as Dictionary
	var optimized := pair.get("optimized", {}) as Dictionary
	var candidate_parity: bool = not baseline.is_empty() \
		and baseline.get("projection", []) == optimized.get("projection", [])
	var order_parity: bool = baseline.get("original_order", []) == optimized.get("original_order", []) \
		and baseline.get("ranked_order", []) == optimized.get("ranked_order", [])
	var selection_parity: bool = baseline.get("forced_selection", {}) == optimized.get("forced_selection", {}) \
		and baseline.get("normal_selection", {}) == optimized.get("normal_selection", {})
	var score_reason_parity := _score_reason_projection(baseline.get("projection", []) as Array) \
		== _score_reason_projection(optimized.get("projection", []) as Array)
	var memory_parity: bool = baseline.get("memory", {}) == optimized.get("memory", {})
	var commit_parity: bool = int(baseline.get("commit_delta", -1)) == int(optimized.get("commit_delta", -2))
	var rng_parity: bool = baseline.get("rng_before", {}) == optimized.get("rng_before", {}) \
		and baseline.get("rng_terminal", {}) == optimized.get("rng_terminal", {})
	return {
		"all": candidate_parity and order_parity and selection_parity \
			and score_reason_parity and memory_parity and commit_parity and rng_parity,
		"candidate": candidate_parity,
		"order": order_parity,
		"selection": selection_parity,
		"score_reason": score_reason_parity,
		"memory": memory_parity,
		"commit": commit_parity,
		"rng": rng_parity,
	}


func _warehouse_play_pair_contract(pair: Dictionary, expected_district_index: int) -> Dictionary:
	var baseline := pair.get("baseline", {}) as Dictionary
	var optimized := pair.get("optimized", {}) as Dictionary
	var baseline_projection := baseline.get("projection", []) as Array
	var optimized_projection := optimized.get("projection", []) as Array
	var baseline_candidate: Dictionary = baseline_projection[0] as Dictionary \
		if baseline_projection.size() == 1 and baseline_projection[0] is Dictionary else {}
	var optimized_candidate: Dictionary = optimized_projection[0] as Dictionary \
		if optimized_projection.size() == 1 and optimized_projection[0] is Dictionary else {}
	var baseline_required := bool(baseline_candidate.get("futures_warehouse_required", false))
	var optimized_required := bool(optimized_candidate.get("futures_warehouse_required", false))
	var baseline_city := int(baseline_candidate.get("futures_warehouse_city", -1))
	var optimized_city := int(optimized_candidate.get("futures_warehouse_city", -1))
	return {
		"passed": expected_district_index >= 0 \
			and not baseline_candidate.is_empty() \
			and not optimized_candidate.is_empty() \
			and baseline_required \
			and optimized_required \
			and baseline_city == expected_district_index \
			and optimized_city == expected_district_index,
		"baseline_count": baseline_projection.size(),
		"optimized_count": optimized_projection.size(),
		"baseline_required": baseline_required,
		"optimized_required": optimized_required,
		"baseline_city": baseline_city,
		"optimized_city": optimized_city,
	}


func _score_reason_projection(candidates: Array) -> Array:
	var result: Array = []
	for candidate_variant in candidates:
		if candidate_variant is Dictionary:
			var candidate := candidate_variant as Dictionary
			result.append({
				"slot_index": int(candidate.get("slot_index", -1)),
				"score": int(candidate.get("score", 0)),
				"reason": str(candidate.get("reason", "")),
			})
	return result


func _run_wrong_actor_play_context_gate(
	ai: AiRuntimeController,
	actor_state_port: AiActorStatePort,
	rng: RunRngService,
	world: WorldSessionState,
	actor_index: int,
	skill: Dictionary,
	world_checkpoint: Dictionary,
	rng_checkpoint: Dictionary
) -> Dictionary:
	var baseline_restore := _restore_play_checkpoint(world, rng, world_checkpoint, rng_checkpoint)
	var baseline := _measure_single_play_context(ai, actor_state_port, rng, actor_index, skill, {}) \
		if baseline_restore else {}
	var wrong_context := {
		"cache_active": true,
		"player_index": actor_index + 1,
		"slot_play_contexts": {},
		"district_focus_score_by_index": {},
		"focus_product": "__wrong_actor_focus__",
		"route_product": "__wrong_actor_route__",
		"route_plan": {"product": "__wrong_actor_route__"},
		"product_futures_plan": {
			"product": "__wrong_actor_product__",
			"futures_signal": 999999,
		},
	}
	var wrong_context_before: Variant = _canonicalize(wrong_context.duplicate(true))
	var wrong_restore := _restore_play_checkpoint(world, rng, world_checkpoint, rng_checkpoint)
	var wrong := _measure_single_play_context(ai, actor_state_port, rng, actor_index, skill, wrong_context) \
		if wrong_restore else {}
	var context_unchanged: bool = _canonicalize(wrong_context) == wrong_context_before
	var wrong_candidate := wrong.get("candidate", {}) as Dictionary
	var poison_absent: bool = int(wrong_candidate.get("futures_signal", 999999)) != 999999 \
		and str(wrong_candidate.get("product", "")) != "__wrong_actor_product__"
	var result_parity: bool = baseline.get("candidate", {}) == wrong.get("candidate", {}) \
		and baseline.get("memory", {}) == wrong.get("memory", {}) \
		and int(baseline.get("commit_delta", -1)) == int(wrong.get("commit_delta", -2)) \
		and baseline.get("rng_before", {}) == wrong.get("rng_before", {}) \
		and baseline.get("rng_terminal", {}) == wrong.get("rng_terminal", {})
	var query_fail_closed: bool = int(baseline.get("query_delta", 0)) > 0 \
		and int(baseline.get("query_delta", -1)) == int(wrong.get("query_delta", -2))
	var final_restore := _restore_play_checkpoint(world, rng, world_checkpoint, rng_checkpoint)
	return {
		"passed": baseline_restore and wrong_restore and final_restore \
			and result_parity and query_fail_closed and context_unchanged and poison_absent,
		"baseline_queries": int(baseline.get("query_delta", -1)),
		"wrong_queries": int(wrong.get("query_delta", -1)),
		"context_unchanged": context_unchanged,
		"poison_absent": poison_absent,
	}


func _run_empty_plan_play_context_gate(
	ai: AiRuntimeController,
	coordinator: GameRuntimeCoordinator,
	actor_state_port: AiActorStatePort,
	rng: RunRngService,
	world: WorldSessionState,
	actor_index: int,
	warm_skill: Dictionary,
	futures_skill: Dictionary,
	world_checkpoint: Dictionary,
	rng_checkpoint: Dictionary
) -> Dictionary:
	var fixture_restore := _restore_play_checkpoint(world, rng, world_checkpoint, rng_checkpoint)
	var short_futures_skill := ai.call("_make_skill", "商品看跌1") as Dictionary
	var flow_spec := _find_flow_corrected_futures_spec(
		ai,
		actor_index,
		[futures_skill, short_futures_skill]
	) if fixture_restore and not short_futures_skill.is_empty() else {}
	var flow_city_fixture := _install_empty_play_flow_city(
		coordinator,
		world,
		actor_index,
		str(flow_spec.get("final_product", "")),
		int(flow_spec.get("final_product_level", 0))
	) if bool(flow_spec.get("ready", false)) else {}
	var flow_world_checkpoint := world.capture_runtime_checkpoint() \
		if bool(flow_city_fixture.get("ready", false)) else {}
	var flow_rng_checkpoint := rng.capture_plan_checkpoint() \
		if bool(flow_city_fixture.get("ready", false)) else {}
	var flow_fixture := _build_flow_corrected_futures_fixture(
		ai,
		actor_index,
		flow_spec
	) if bool(flow_city_fixture.get("ready", false)) else {}
	var fixture_ready := bool(flow_fixture.get("ready", false))
	var fixture_skill := flow_fixture.get("skill", {}) as Dictionary
	var fixture_context := flow_fixture.get("context", {}) as Dictionary
	var initial_plan := flow_fixture.get("initial_plan", {}) as Dictionary
	var final_plan := flow_fixture.get("final_plan", {}) as Dictionary

	var reference_restore := _restore_play_checkpoint(
		world, rng, flow_world_checkpoint, flow_rng_checkpoint
	) if fixture_ready else false
	var reference_context := fixture_context.duplicate(true) if fixture_ready else {}
	if fixture_ready:
		ai.call("_ai_card_play_context", actor_index, 0, warm_skill, reference_context)
	var reference := _measure_single_play_context(
		ai, actor_state_port, rng, actor_index, fixture_skill, reference_context
	) if fixture_ready and reference_restore else {}

	var empty_restore := _restore_play_checkpoint(
		world, rng, flow_world_checkpoint, flow_rng_checkpoint
	) if fixture_ready else false
	var empty_context := fixture_context.duplicate(true) if fixture_ready else {}
	if fixture_ready:
		ai.call("_ai_card_play_context", actor_index, 0, warm_skill, empty_context)
		empty_context["product_futures_plan"] = {}
	var empty_context_before: Variant = _canonicalize(empty_context.duplicate(true))
	var empty := _measure_single_play_context(
		ai, actor_state_port, rng, actor_index, fixture_skill, empty_context
	) if fixture_ready and empty_restore else {}
	var context_unchanged: bool = _canonicalize(empty_context) == empty_context_before
	var candidate := empty.get("candidate", {}) as Dictionary
	var initial_plan_context := empty_context.duplicate(true)
	initial_plan_context["product_futures_plan"] = initial_plan
	var final_plan_context := empty_context.duplicate(true)
	final_plan_context["product_futures_plan"] = final_plan
	var initial_generic_score := int(ai.call(
		"_ai_generic_card_effect_score",
		actor_index,
		fixture_skill,
		int(candidate.get("district", -1)),
		str(candidate.get("product", "")),
		int(candidate.get("target_owner", -999)),
		initial_plan_context
	)) if not candidate.is_empty() else -1
	var final_generic_score := int(ai.call(
		"_ai_generic_card_effect_score",
		actor_index,
		fixture_skill,
		int(candidate.get("district", -1)),
		str(candidate.get("product", "")),
		int(candidate.get("target_owner", -999)),
		final_plan_context
	)) if not candidate.is_empty() else -1
	var initial_product := str(initial_plan.get("product", ""))
	var final_product := str(final_plan.get("product", ""))
	var products_changed: bool = not initial_product.is_empty() \
		and not final_product.is_empty() \
		and initial_product != final_product \
		and str(candidate.get("product", "")) == final_product
	var final_plan_matches_candidate: bool = not candidate.is_empty() \
		and int(candidate.get("futures_signal", -1)) == int(final_plan.get("futures_signal", -2)) \
		and int(candidate.get("futures_product_flow", -1)) == int(final_plan.get("futures_product_flow", -2))
	var generic_scores_distinguish_plans: bool = initial_generic_score != final_generic_score
	var final_plan_used: bool = final_plan_matches_candidate \
		and int(candidate.get("generic_effect_bonus", -1)) == final_generic_score \
		and int(candidate.get("generic_effect_bonus", -1)) != initial_generic_score \
		and generic_scores_distinguish_plans \
		and int(candidate.get("futures_signal", 0)) > 0
	var parity: bool = reference.get("candidate", {}) == empty.get("candidate", {}) \
		and reference.get("memory", {}) == empty.get("memory", {}) \
		and int(reference.get("commit_delta", -1)) == int(empty.get("commit_delta", -2)) \
		and reference.get("rng_before", {}) == empty.get("rng_before", {}) \
		and reference.get("rng_terminal", {}) == empty.get("rng_terminal", {})
	var final_restore := _restore_play_checkpoint(world, rng, world_checkpoint, rng_checkpoint)
	coordinator.refresh_route_network(true)
	var fixture_world_restored: bool = _canonicalize(world.capture_runtime_checkpoint()) \
		== _canonicalize(world_checkpoint)
	var fixture_rng_restored: bool = rng.capture_plan_checkpoint() == rng_checkpoint
	var passed: bool = fixture_restore and fixture_ready \
		and reference_restore and empty_restore and final_restore \
		and bool(flow_city_fixture.get("ready", false)) \
		and fixture_world_restored and fixture_rng_restored \
		and parity and context_unchanged and products_changed and final_plan_used
	print("PLAY_FINAL_FUTURES_PLAN_GATE|status=%s|fixture_ready=%s|card=%s|required_flow=%d|initial_product=%s|final_product=%s|initial_flow=%d|final_flow=%d|initial_selection_score=%d|final_selection_score=%d|planned_product=%s|corrected_product=%s|initial_generic_score=%d|final_generic_score=%d|candidate_generic_score=%d|candidate_matches_final=%s|context_unchanged=%s|flow_city=%d|world_restored=%s" % [
		"PASS" if passed else "FAIL",
		str(fixture_ready),
		str(fixture_skill.get("name", "")),
		int(flow_fixture.get("required_flow", 0)),
		initial_product,
		final_product,
		int(flow_fixture.get("initial_product_flow", -1)),
		int(flow_fixture.get("final_product_flow", -1)),
		int(flow_fixture.get("initial_product_score", -1)),
		int(flow_fixture.get("final_product_score", -1)),
		str(flow_fixture.get("planned_product", "")),
		str(flow_fixture.get("corrected_product", "")),
		initial_generic_score,
		final_generic_score,
		int(candidate.get("generic_effect_bonus", -1)),
		str(final_plan_matches_candidate),
		str(context_unchanged),
		int(flow_city_fixture.get("district_index", -1)),
		str(fixture_world_restored and fixture_rng_restored),
	])
	return {
		"passed": passed,
		"fixture_ready": fixture_ready,
		"flow_city_ready": bool(flow_city_fixture.get("ready", false)),
		"fixture_world_restored": fixture_world_restored,
		"fixture_rng_restored": fixture_rng_restored,
		"fixture_restored": final_restore and fixture_world_restored and fixture_rng_restored,
		"selection_tie_verified": bool(flow_fixture.get("selection_tie_verified", false)),
		"context_unchanged": context_unchanged,
		"products_changed": products_changed,
		"initial_product": initial_product,
		"final_product": final_product,
		"initial_generic_score": initial_generic_score,
		"final_generic_score": final_generic_score,
		"generic_scores_distinguish_plans": generic_scores_distinguish_plans,
		"final_plan_matches_candidate": final_plan_matches_candidate,
		"final_plan_used": final_plan_used,
	}


func _find_flow_corrected_futures_spec(
	ai: AiRuntimeController,
	actor_index: int,
	futures_skills: Array
) -> Dictionary:
	var products: Array = ProductMarketRuntimeController.PRODUCT_CATALOG.duplicate()
	var existing_flow_product_count := 0
	for product_variant in products:
		if int(ai.call("_player_product_flow", actor_index, str(product_variant))) > 0:
			existing_flow_product_count += 1
	if existing_flow_product_count > 0:
		return {
			"ready": false,
			"existing_flow_product_count": existing_flow_product_count,
		}
	for skill_variant in futures_skills:
		if not (skill_variant is Dictionary) or (skill_variant as Dictionary).is_empty():
			continue
		var source_skill := skill_variant as Dictionary
		for required_variant in [1, 2, 3, 4]:
			var required := int(required_variant)
			var fixture_skill := source_skill.duplicate(true)
			fixture_skill["legacy_flow_gate_enabled"] = true
			fixture_skill["play_flow_required"] = required
			fixture_skill.erase("play_product")
			var neutral_context := ai.call("_ai_card_turn_scoring_context", actor_index) as Dictionary
			neutral_context["focus_product"] = ""
			neutral_context["route_product"] = ""
			neutral_context["route_plan"] = {"product": "", "stage": "", "score": 0}
			var products_by_neutral_score := {}
			var neutral_score_by_product := {}
			var max_neutral_score := -999999
			for product_variant in products:
				var product_name := str(product_variant)
				var neutral_score := int(ai.call(
					"_ai_product_futures_product_score",
					actor_index,
					fixture_skill,
					product_name,
					neutral_context
				))
				neutral_score_by_product[product_name] = neutral_score
				max_neutral_score = maxi(max_neutral_score, neutral_score)
				var same_score_products := products_by_neutral_score.get(neutral_score, []) as Array
				same_score_products.append(product_name)
				products_by_neutral_score[neutral_score] = same_score_products
			for final_product_variant in products:
				var final_product := str(final_product_variant)
				var final_neutral_score := int(neutral_score_by_product.get(final_product, -999999))
				for final_product_level in range(required, 13):
					var flow_score_gain := required * 140 + final_product_level * 36
					var required_initial_neutral_score := final_neutral_score + flow_score_gain - 80
					if not products_by_neutral_score.has(required_initial_neutral_score):
						continue
					var tied_score_after_fixture := required_initial_neutral_score + 80
					if tied_score_after_fixture < max_neutral_score:
						continue
					for initial_product_variant in products_by_neutral_score[required_initial_neutral_score] as Array:
						var initial_product := str(initial_product_variant)
						if initial_product == final_product:
							continue
						return {
							"ready": true,
							"required_flow": required,
							"skill": fixture_skill,
							"initial_product": initial_product,
							"final_product": final_product,
							"final_product_level": final_product_level,
							"expected_tied_score": tied_score_after_fixture,
							"existing_flow_product_count": 0,
						}
	return {
		"ready": false,
		"existing_flow_product_count": existing_flow_product_count,
	}


func _build_flow_corrected_futures_fixture(
	ai: AiRuntimeController,
	actor_index: int,
	flow_spec: Dictionary
) -> Dictionary:
	if not bool(flow_spec.get("ready", false)):
		return {"ready": false}
	var fixture_skill := (flow_spec.get("skill", {}) as Dictionary).duplicate(true)
	var required := int(flow_spec.get("required_flow", 0))
	var initial_product := str(flow_spec.get("initial_product", ""))
	var expected_final_product := str(flow_spec.get("final_product", ""))
	var actor_context := ai.call("_ai_card_turn_scoring_context", actor_index) as Dictionary
	actor_context["focus_product"] = ""
	actor_context["route_product"] = initial_product
	actor_context["route_plan"] = {
		"product": initial_product,
		"stage": "",
		"score": 0,
	}
	var initial_flow := int(ai.call("_player_product_flow", actor_index, initial_product))
	var final_flow := int(ai.call("_player_product_flow", actor_index, expected_final_product))
	var initial_product_score := int(ai.call(
		"_ai_product_futures_product_score",
		actor_index,
		fixture_skill,
		initial_product,
		actor_context
	))
	var final_product_score := int(ai.call(
		"_ai_product_futures_product_score",
		actor_index,
		fixture_skill,
		expected_final_product,
		actor_context
	))
	var planned_product := str(ai.call(
		"_ai_product_for_skill", actor_index, fixture_skill, actor_context
	))
	var initial_plan := ai.call(
		"_ai_product_futures_plan",
		actor_index,
		fixture_skill,
		planned_product,
		actor_context
	) as Dictionary
	var corrected_product := str(ai.call(
		"_best_player_flow_product",
		actor_index,
		required,
		[
			str(initial_plan.get("product", "")),
			initial_product,
			"",
		]
	))
	var final_plan := ai.call(
		"_ai_product_futures_plan",
		actor_index,
		fixture_skill,
		corrected_product,
		actor_context
	) as Dictionary
	var ready: bool = required > 0 \
		and initial_flow < required \
		and final_flow >= required \
		and initial_product_score == final_product_score \
		and str(initial_plan.get("product", "")) == initial_product \
		and corrected_product == expected_final_product \
		and str(final_plan.get("product", "")) == expected_final_product
	return {
		"ready": ready,
		"required_flow": required,
		"skill": fixture_skill,
		"context": actor_context,
		"initial_plan": initial_plan,
		"final_plan": final_plan,
		"initial_product_flow": initial_flow,
		"final_product_flow": final_flow,
		"initial_product_score": initial_product_score,
		"final_product_score": final_product_score,
		"planned_product": planned_product,
		"corrected_product": corrected_product,
		"selection_tie_verified": initial_product_score == final_product_score,
	}


func _measure_single_play_context(
	ai: AiRuntimeController,
	actor_state_port: AiActorStatePort,
	rng: RunRngService,
	actor_index: int,
	skill: Dictionary,
	supplied_context: Dictionary
) -> Dictionary:
	var state_before := actor_state_port.debug_snapshot()
	var rng_before := rng.capture_plan_checkpoint()
	var candidate := ai.call(
		"_ai_card_play_context",
		actor_index,
		1,
		skill,
		supplied_context
	) as Dictionary
	var state_after_candidate := actor_state_port.debug_snapshot()
	var memory := ai.call("_ai_memory_for_player", actor_index) as Dictionary
	var state_after := actor_state_port.debug_snapshot()
	return {
		"candidate": _candidate_projection_row(candidate),
		"query_delta": int(state_after_candidate.get("ai_state_query_count", 0))
			- int(state_before.get("ai_state_query_count", 0)),
		"commit_delta": int(state_after.get("state_commit_count", 0))
			- int(state_before.get("state_commit_count", 0)),
		"memory": _canonicalize(memory),
		"rng_before": rng_before,
		"rng_terminal": rng.capture_plan_checkpoint(),
	}


func _install_empty_play_flow_city(
	coordinator: GameRuntimeCoordinator,
	world: WorldSessionState,
	actor_index: int,
	product_name: String,
	product_level: int
) -> Dictionary:
	var route_network := coordinator.get_node_or_null("RouteNetworkRuntimeController") as RouteNetworkRuntimeController
	if route_network == null \
			or product_name.is_empty() \
			or not ProductMarketRuntimeController.PRODUCT_CATALOG.has(product_name) \
			or product_level <= 0:
		return {"ready": false}
	var districts := world.districts.duplicate(true)
	for district_index in range(districts.size()):
		if not (districts[district_index] is Dictionary):
			continue
		var district := districts[district_index] as Dictionary
		var source_city := district.get("city", {}) as Dictionary \
			if district.get("city", {}) is Dictionary else {}
		var valid_land := not bool(district.get("destroyed", false)) \
			and not bool(district.get("is_ocean", false)) \
			and str(district.get("terrain", "land")) != "ocean"
		var region_id := world.region_id_for_district(district_index)
		var region_match := not region_id.is_empty() \
			and world.district_index_for_region_id(region_id) == district_index
		if not valid_land or not source_city.is_empty() or not region_match:
			continue
		district["city"] = {
			"active": true,
			"owner": actor_index,
			"name": "Play futures flow fixture",
			"products": [{"name": product_name, "level": product_level}],
			"demands": [],
			"trade_routes": [],
		}
		districts[district_index] = district
		world.replace_districts(districts, true)
		coordinator.refresh_route_network(true)
		var city := (world.districts[district_index] as Dictionary).get("city", {}) as Dictionary
		var route_active := (route_network.active_region_legacy_indices() as Array).has(district_index)
		var city_products := city.get("products", []) as Array
		var city_valid := not city.is_empty() \
			and bool(city.get("active", false)) \
			and int(city.get("owner", -1)) == actor_index \
			and city_products.size() == 1 \
			and city_products[0] is Dictionary \
			and str((city_products[0] as Dictionary).get("name", "")) == product_name \
			and int((city_products[0] as Dictionary).get("level", 0)) == product_level
		return {
			"ready": valid_land and region_match and city_valid and route_active,
			"district_index": district_index,
			"source_city_empty": source_city.is_empty(),
			"topology_valid": region_match and route_active and city_valid,
			"product": product_name,
			"product_level": product_level,
		}
	return {"ready": false}


func _install_empty_play_warehouse_city(
	coordinator: GameRuntimeCoordinator,
	world: WorldSessionState,
	actor_index: int
) -> Dictionary:
	var route_network := coordinator.get_node_or_null("RouteNetworkRuntimeController") as RouteNetworkRuntimeController
	if route_network == null:
		return {"ready": false}
	var districts := world.districts.duplicate(true)
	for district_index in range(districts.size()):
		if not (districts[district_index] is Dictionary):
			continue
		var district := districts[district_index] as Dictionary
		var source_city := district.get("city", {}) as Dictionary \
			if district.get("city", {}) is Dictionary else {}
		var valid_land := not bool(district.get("destroyed", false)) \
			and not bool(district.get("is_ocean", false)) \
			and str(district.get("terrain", "land")) != "ocean"
		var region_id := world.region_id_for_district(district_index)
		var region_match := not region_id.is_empty() \
			and world.district_index_for_region_id(region_id) == district_index
		if not valid_land or not source_city.is_empty() or not region_match:
			continue
		district["city"] = {
			"active": true,
			"owner": actor_index,
			"name": "Play futures warehouse",
			"products": [],
			"demands": [],
		}
		districts[district_index] = district
		world.replace_districts(districts, true)
		coordinator.refresh_route_network(true)
		var city := (world.districts[district_index] as Dictionary).get("city", {}) as Dictionary
		var route_active := (route_network.active_region_legacy_indices() as Array).has(district_index)
		var city_valid := not city.is_empty() \
			and bool(city.get("active", false)) \
			and int(city.get("owner", -1)) == actor_index
		return {
			"ready": valid_land and region_match and city_valid and route_active,
			"district_index": district_index,
			"source_city_empty": source_city.is_empty(),
			"topology_valid": region_match and route_active and city_valid,
		}
	return {"ready": false}


func _restore_play_checkpoint(
	world: WorldSessionState,
	rng: RunRngService,
	world_checkpoint: Dictionary,
	rng_checkpoint: Dictionary
) -> bool:
	var world_restore := world.restore_runtime_checkpoint(world_checkpoint)
	var rng_restore := rng.restore_plan_checkpoint(rng_checkpoint)
	return bool(world_restore.get("applied", false)) and bool(rng_restore.get("restored", false))


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
	var buy_query_reduction := int(optimized.get("buy_ai_state_query_delta", 0)) \
		< int(baseline.get("buy_ai_state_query_delta", 0))
	var buy_elapsed_reduction := int(optimized.get("buy_elapsed_msec", 0)) \
		< int(baseline.get("buy_elapsed_msec", 0))
	var optimized_elapsed_msec := int(optimized.get("elapsed_msec", FALLBACK_ABSOLUTE_LIMIT_MSEC))
	var absolute_limit_met := optimized_elapsed_msec < FALLBACK_ABSOLUTE_LIMIT_MSEC
	var suggested_limit_met := optimized_elapsed_msec < FALLBACK_SUGGESTED_LIMIT_MSEC
	var route_lookup_gate := bool(_route_lookup_profile.get("passed", false))
	var route_hand_gate := bool(_route_hand_inventory_profile.get("passed", false))
	var gate_passed: bool = semantic_parity \
		and memory_parity \
		and commit_parity \
		and terminal_rng_parity \
		and query_reduction \
		and buy_query_reduction \
		and route_lookup_gate \
		and route_hand_gate \
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
	print(
		"ROUTE_LOOKUP_CACHE_REVIEW_REPAIR_GATE|status=%s|fresh_snapshot_contexts=%d|shared_snapshot_contexts=%d|index_build_delta=%d|legacy_snapshot_delta=%d|baseline_resolutions=%d|optimized_resolutions=%d|lookup_context_detached=%s|uncached_route_hand_scans=%d|cached_route_hand_scans=%d|unique_route_count=%d|candidate_order_selection_parity=%s|memory_parity=%s|commit_parity=%s|rng_parity=%s"
			% [
				"PASS" if gate_passed else "FAIL",
				int(_route_lookup_profile.get("baseline_snapshot_lookup_count", -1)),
				int(_route_lookup_profile.get("optimized_snapshot_lookup_count", -1)),
				int(_route_lookup_profile.get("index_build_delta", -1)),
				int(_route_lookup_profile.get("legacy_snapshot_delta", -1)),
				int(_route_lookup_profile.get("baseline_resolution_delta", -1)),
				int(_route_lookup_profile.get("optimized_resolution_delta", -1)),
				str(bool(_route_lookup_profile.get("lookup_context_remained_detached", false))),
				int(_route_hand_inventory_profile.get("uncached_scan_count", -1)),
				int(_route_hand_inventory_profile.get("cached_scan_count", -1)),
				int(_route_hand_inventory_profile.get("unique_route_count", -1)),
				str(semantic_parity),
				str(memory_parity),
				str(commit_parity),
				str(terminal_rng_parity),
			]
	)
	print(
		"NEXT_AI_FRAME_HOTSPOT_GATE|status=%s|hotspot=sealed_development_route_index|baseline_route_usec=%d|optimized_route_usec=%d|baseline_snapshot_lookups=%d|optimized_snapshot_lookups=%d|index_build_delta=%d|legacy_snapshot_delta=%d|fallback_buy_elapsed_msec=%d|fallback_buy_queries=%d|semantic_parity=%s|order_selection_parity=%s|memory_parity=%s|commit_parity=%s|rng_parity=%s"
			% [
				"PASS" if gate_passed else "FAIL",
				int(_route_lookup_profile.get("baseline_elapsed_usec", -1)),
				int(_route_lookup_profile.get("optimized_elapsed_usec", -1)),
				int(_route_lookup_profile.get("baseline_snapshot_lookup_count", -1)),
				int(_route_lookup_profile.get("optimized_snapshot_lookup_count", -1)),
				int(_route_lookup_profile.get("index_build_delta", -1)),
				int(_route_lookup_profile.get("legacy_snapshot_delta", -1)),
				int(optimized.get("buy_elapsed_msec", -1)),
				int(optimized.get("buy_ai_state_query_delta", -1)),
				str(semantic_parity),
				str(semantic_parity),
				str(memory_parity),
				str(commit_parity),
				str(terminal_rng_parity),
			]
	)
	_expect(semantic_parity, "three-AI shared turn context preserves candidate semantics, original/ranked order, and force/normal selection")
	_expect(memory_parity, "three-AI shared turn context preserves each actor's final memory")
	_expect(commit_parity, "three-AI shared turn context preserves per-actor and aggregate state commit counts")
	_expect(terminal_rng_parity, "three-AI shared turn context preserves terminal RNG")
	_expect(query_reduction, "three-AI shared turn context reduces actor-state queries")
	_expect(buy_query_reduction, "three-AI shared turn context reduces fallback-buy actor-state queries")
	_expect(route_lookup_gate, "call-local development-route lookup gate passes")
	_expect(route_hand_gate, "route-hand uncached/cached review gate passes")
	_expect(absolute_limit_met, "three-AI shared turn context stays below the absolute 15 second limit")
	print("NEXT_AI_FRAME_HOTSPOT_TIMING|buy_elapsed_reduction=%s" % str(buy_elapsed_reduction))


func _run_development_route_lookup_context_gate(
	ai: AiRuntimeController,
	diagnostics: GameplayBalanceDiagnosticsRuntimeService,
	actor_state_port: AiActorStatePort,
	rng: RunRngService,
	world: WorldSessionState,
	actor_index: int
) -> void:
	if diagnostics == null:
		_route_lookup_profile = {"passed": false}
		print("DEVELOPMENT_ROUTE_LOOKUP_CONTEXT_GATE|status=FAIL|reason=diagnostics_missing")
		_expect(false, "route lookup fixture exposes production diagnostics service")
		return
	var skills: Array = []
	for district_index in range(world.districts.size()):
		for card_variant in ai.call("_district_supply_card_ids", district_index) as Array:
			var card_name := str(card_variant)
			if not card_name.is_empty():
				skills.append(ai.call("_make_skill", card_name) as Dictionary)
	if skills.is_empty():
		_route_lookup_profile = {"passed": false}
		print("DEVELOPMENT_ROUTE_LOOKUP_CONTEXT_GATE|status=FAIL|reason=no_supply_skills")
		_expect(false, "route lookup fixture exposes formal district-supply skills")
		return

	var memory_before := ai.call("_ai_memory_for_player", actor_index) as Dictionary
	var rng_before := rng.capture_plan_checkpoint()
	var diagnostics_before := diagnostics.debug_snapshot()
	var baseline_state_before := actor_state_port.debug_snapshot()
	var baseline_started_usec := Time.get_ticks_usec()
	var baseline_routes: Array = []
	var baseline_snapshot_lookup_count := 0
	for skill_variant in skills:
		var uncached_lookup_context: Dictionary = {}
		baseline_routes.append(ai.call(
			"_card_development_route_id",
			skill_variant as Dictionary,
			uncached_lookup_context
		))
		if uncached_lookup_context.has("world_snapshot"):
			baseline_snapshot_lookup_count += 1
	var baseline_elapsed_usec := Time.get_ticks_usec() - baseline_started_usec
	var baseline_state_after := actor_state_port.debug_snapshot()
	var diagnostics_after_baseline := diagnostics.debug_snapshot()

	var lookup_context: Dictionary = {}
	var optimized_state_before := actor_state_port.debug_snapshot()
	var optimized_started_usec := Time.get_ticks_usec()
	var optimized_routes: Array = []
	for skill_variant in skills:
		optimized_routes.append(ai.call(
			"_card_development_route_id",
			skill_variant as Dictionary,
			lookup_context
		))
	var optimized_elapsed_usec := Time.get_ticks_usec() - optimized_started_usec
	var optimized_snapshot_lookup_count := 1 if lookup_context.has("world_snapshot") else 0
	var lookup_context_remained_detached := optimized_snapshot_lookup_count == 0
	var optimized_state_after := actor_state_port.debug_snapshot()
	var diagnostics_after_optimized := diagnostics.debug_snapshot()
	var memory_after := ai.call("_ai_memory_for_player", actor_index) as Dictionary
	var rng_after := rng.capture_plan_checkpoint()

	var result_parity: bool = baseline_routes == optimized_routes
	var memory_parity: bool = _canonicalize(memory_before) == _canonicalize(memory_after)
	var commit_parity: bool = (
		int(baseline_state_after.get("state_commit_count", 0))
			- int(baseline_state_before.get("state_commit_count", 0))
	) == 0 and (
		int(optimized_state_after.get("state_commit_count", 0))
			- int(optimized_state_before.get("state_commit_count", 0))
	) == 0
	var rng_parity: bool = rng_after == rng_before
	var baseline_resolution_delta := (
		int(diagnostics_after_baseline.get("card_route_index_hit_count", 0))
			+ int(diagnostics_after_baseline.get("card_route_index_miss_count", 0))
	) - (
		int(diagnostics_before.get("card_route_index_hit_count", 0))
			+ int(diagnostics_before.get("card_route_index_miss_count", 0))
	)
	var optimized_resolution_delta := (
		int(diagnostics_after_optimized.get("card_route_index_hit_count", 0))
			+ int(diagnostics_after_optimized.get("card_route_index_miss_count", 0))
	) - (
		int(diagnostics_after_baseline.get("card_route_index_hit_count", 0))
			+ int(diagnostics_after_baseline.get("card_route_index_miss_count", 0))
	)
	var index_build_delta := int(diagnostics_after_optimized.get("card_route_index_build_count", 0)) \
		- int(diagnostics_before.get("card_route_index_build_count", 0))
	var legacy_snapshot_delta := int(diagnostics_after_optimized.get("card_route_legacy_snapshot_lookup_count", 0)) \
		- int(diagnostics_before.get("card_route_legacy_snapshot_lookup_count", 0))
	var sealed_index_contract := bool(diagnostics_before.get("card_route_index_ready", false)) \
		and bool(diagnostics_before.get("card_route_index_sealed", false)) \
		and index_build_delta == 0 \
		and legacy_snapshot_delta == 0 \
		and baseline_snapshot_lookup_count == 0 \
		and optimized_snapshot_lookup_count == 0 \
		and lookup_context_remained_detached \
		and baseline_resolution_delta > 0 \
		and optimized_resolution_delta == baseline_resolution_delta
	var gate_passed: bool = result_parity \
		and memory_parity \
		and commit_parity \
		and rng_parity \
		and sealed_index_contract
	_route_lookup_profile = {
		"passed": gate_passed,
		"baseline_elapsed_usec": baseline_elapsed_usec,
		"optimized_elapsed_usec": optimized_elapsed_usec,
		"baseline_queries": int(baseline_state_after.get("ai_state_query_count", 0))
			- int(baseline_state_before.get("ai_state_query_count", 0)),
		"optimized_queries": int(optimized_state_after.get("ai_state_query_count", 0))
			- int(optimized_state_before.get("ai_state_query_count", 0)),
		"baseline_snapshot_lookup_count": baseline_snapshot_lookup_count,
		"optimized_snapshot_lookup_count": optimized_snapshot_lookup_count,
		"lookup_context_remained_detached": lookup_context_remained_detached,
		"index_build_delta": index_build_delta,
		"legacy_snapshot_delta": legacy_snapshot_delta,
		"baseline_resolution_delta": baseline_resolution_delta,
		"optimized_resolution_delta": optimized_resolution_delta,
		"result_sha256": JSON.stringify(baseline_routes).sha256_text(),
	}
	print("DEVELOPMENT_ROUTE_LOOKUP_CONTEXT_GATE|status=%s|calls=%d|baseline_usec=%d|optimized_usec=%d|baseline_queries=%d|optimized_queries=%d|baseline_snapshot_lookups=%d|optimized_snapshot_lookups=%d|index_build_delta=%d|legacy_snapshot_delta=%d|baseline_resolutions=%d|optimized_resolutions=%d|lookup_context_detached=%s|result_parity=%s|memory_parity=%s|commit_parity=%s|rng_parity=%s" % [
		"PASS" if gate_passed else "FAIL",
		skills.size(),
		baseline_elapsed_usec,
		optimized_elapsed_usec,
		int(_route_lookup_profile.get("baseline_queries", -1)),
		int(_route_lookup_profile.get("optimized_queries", -1)),
		baseline_snapshot_lookup_count,
		optimized_snapshot_lookup_count,
		index_build_delta,
		legacy_snapshot_delta,
		baseline_resolution_delta,
		optimized_resolution_delta,
		str(lookup_context_remained_detached),
		str(result_parity),
		str(memory_parity),
		str(commit_parity),
		str(rng_parity),
	])
	_expect(gate_passed, "sealed development-route index preserves results, memory, commits, and RNG without candidate-loop builds or snapshots")


func _run_route_hand_inventory_cache_review_gate(
	ai: AiRuntimeController,
	actor_state_port: AiActorStatePort,
	rng: RunRngService,
	world: WorldSessionState,
	actor_index: int
) -> void:
	var initial_players := world.players.duplicate(true)
	var initial_rng := rng.capture_plan_checkpoint()
	var turn_context := ai.call("_ai_card_turn_scoring_context", actor_index) as Dictionary
	var play_candidates := ai.call("_ai_card_play_candidates", actor_index, turn_context) as Array
	var buy_candidates := ai.call("_ai_card_buy_candidates", actor_index, turn_context) as Array
	var hand_snapshot := ai.call("_actor_hand_inventory_snapshot", actor_index) as Dictionary
	var best_district := int(ai.call("_best_player_gdp_share_district", actor_index))
	if not play_candidates.is_empty() or buy_candidates.is_empty() or hand_snapshot.is_empty():
		_route_hand_inventory_profile = {"passed": false}
		world.players = initial_players.duplicate(true)
		rng.restore_plan_checkpoint(initial_rng)
		print("ROUTE_HAND_INVENTORY_CACHE_REVIEW_GATE|status=FAIL|reason=formal_candidate_fixture_unavailable")
		_expect(false, "route-hand review fixture exposes fallback buy candidates and a formal hand snapshot")
		return

	var route_lookup_context: Dictionary = {}
	var candidate_routes: Array = []
	var unique_routes: Array = []
	var unique_route_set: Dictionary = {}
	for candidate_variant in buy_candidates:
		var candidate := candidate_variant as Dictionary
		var skill := ai.call("_make_skill", str(candidate.get("card_name", ""))) as Dictionary
		var route_id := str(ai.call("_card_development_route_id", skill, route_lookup_context))
		candidate_routes.append(route_id)
		if not unique_route_set.has(route_id):
			unique_route_set[route_id] = true
			unique_routes.append(route_id)

	var candidate_projection_before := _candidate_projection(buy_candidates)
	var memory_before := ai.call("_ai_memory_for_player", actor_index) as Dictionary
	var rng_before := rng.capture_plan_checkpoint()
	var state_before := actor_state_port.debug_snapshot()
	var uncached_inventory_projection: Array = []
	var uncached_scan_count := 0
	for route_variant in candidate_routes:
		var uncached_inventory := ai.call(
			"_ai_route_hand_inventory",
			actor_index,
			str(route_variant),
			hand_snapshot,
			best_district,
			true,
			{},
			{}
		) as Dictionary
		uncached_inventory_projection.append(_canonicalize(uncached_inventory))
		uncached_scan_count += 1

	var cached_inventory_by_route: Dictionary = {}
	var cached_route_by_card_name: Dictionary = {}
	var cached_lookup_context: Dictionary = {}
	var cached_scan_count := 0
	for route_variant in unique_routes:
		var route_id := str(route_variant)
		cached_inventory_by_route[route_id] = ai.call(
			"_ai_route_hand_inventory",
			actor_index,
			route_id,
			hand_snapshot,
			best_district,
			true,
			cached_route_by_card_name,
			cached_lookup_context
		) as Dictionary
		cached_scan_count += 1
	var cached_inventory_projection: Array = []
	for route_variant in candidate_routes:
		cached_inventory_projection.append(_canonicalize(
			cached_inventory_by_route.get(str(route_variant), {}) as Dictionary
		))

	var state_after := actor_state_port.debug_snapshot()
	var rng_after := rng.capture_plan_checkpoint()
	var memory_after := ai.call("_ai_memory_for_player", actor_index) as Dictionary
	var candidate_projection_after := _candidate_projection(buy_candidates)
	var inventory_result_parity: bool = uncached_inventory_projection == cached_inventory_projection
	var scan_count_reduction: bool = uncached_scan_count > cached_scan_count \
		and cached_scan_count == unique_routes.size()
	var candidate_order_parity: bool = candidate_projection_before == candidate_projection_after \
		and _candidate_order(candidate_projection_before) == _candidate_order(candidate_projection_after)
	var memory_parity: bool = _canonicalize(memory_before) == _canonicalize(memory_after)
	var commit_parity: bool = int(state_after.get("state_commit_count", 0)) \
		- int(state_before.get("state_commit_count", 0)) == 0
	var rng_parity: bool = rng_after == rng_before
	var gate_passed: bool = inventory_result_parity \
		and scan_count_reduction \
		and candidate_order_parity \
		and memory_parity \
		and commit_parity \
		and rng_parity
	_route_hand_inventory_profile = {
		"passed": gate_passed,
		"candidate_count": buy_candidates.size(),
		"unique_route_count": unique_routes.size(),
		"uncached_scan_count": uncached_scan_count,
		"cached_scan_count": cached_scan_count,
		"inventory_sha256": JSON.stringify(uncached_inventory_projection).sha256_text(),
	}
	print("ROUTE_HAND_INVENTORY_CACHE_REVIEW_GATE|status=%s|candidate_count=%d|unique_route_count=%d|uncached_scan_count=%d|cached_scan_count=%d|inventory_result_parity=%s|candidate_order_parity=%s|memory_parity=%s|commit_parity=%s|rng_parity=%s" % [
		"PASS" if gate_passed else "FAIL",
		buy_candidates.size(),
		unique_routes.size(),
		uncached_scan_count,
		cached_scan_count,
		str(inventory_result_parity),
		str(candidate_order_parity),
		str(memory_parity),
		str(commit_parity),
		str(rng_parity),
	])
	_expect(gate_passed, "route-hand cached inventories match the per-candidate uncached reference with fewer scans")
	world.players = initial_players.duplicate(true)
	var restore_rng := rng.restore_plan_checkpoint(initial_rng)
	_expect(bool(restore_rng.get("restored", false)), "route-hand review restores its initial RNG checkpoint")




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
	var total_play_elapsed_msec := 0
	var total_buy_elapsed_msec := 0
	var total_play_query_delta := 0
	var total_buy_query_delta := 0
	var total_play_commit_delta := 0
	var total_buy_commit_delta := 0
	print("AI_CARD_TURN_FALLBACK_AGGREGATE|CALL_STARTED|mode=%s|actor_count=%d" % [mode, actor_indices.size()])
	for actor_index in actor_indices:
		var actor_state_before := actor_state_port.debug_snapshot()
		var turn_scoring_context: Dictionary = {}
		if reuse_turn_context:
			turn_scoring_context = ai.call("_ai_card_turn_scoring_context", actor_index) as Dictionary
		var play_state_before := actor_state_port.debug_snapshot()
		var play_started_msec := Time.get_ticks_msec()
		var play_candidates: Array = []
		if reuse_turn_context:
			play_candidates = ai.call("_ai_card_play_candidates", actor_index, turn_scoring_context) as Array
		else:
			play_candidates = ai.call("_ai_card_play_candidates", actor_index) as Array
		var play_elapsed_msec := Time.get_ticks_msec() - play_started_msec
		var play_state_after := actor_state_port.debug_snapshot()
		var play_query_delta := int(play_state_after.get("ai_state_query_count", 0)) - int(play_state_before.get("ai_state_query_count", 0))
		var play_commit_delta := int(play_state_after.get("state_commit_count", 0)) - int(play_state_before.get("state_commit_count", 0))
		var play_choice := ai.call("_ai_pick_candidate", actor_index, play_candidates, false) as Dictionary
		var buy_state_before := actor_state_port.debug_snapshot()
		var buy_started_msec := Time.get_ticks_msec()
		var buy_candidates: Array = []
		if reuse_turn_context and play_choice.is_empty():
			buy_candidates = ai.call("_ai_card_buy_candidates", actor_index, turn_scoring_context) as Array
		else:
			buy_candidates = ai.call("_ai_card_buy_candidates", actor_index) as Array
		var buy_elapsed_msec := Time.get_ticks_msec() - buy_started_msec
		var buy_state_after := actor_state_port.debug_snapshot()
		var buy_query_delta := int(buy_state_after.get("ai_state_query_count", 0)) - int(buy_state_before.get("ai_state_query_count", 0))
		var buy_commit_delta := int(buy_state_after.get("state_commit_count", 0)) - int(buy_state_before.get("state_commit_count", 0))
		total_play_elapsed_msec += play_elapsed_msec
		total_buy_elapsed_msec += buy_elapsed_msec
		total_play_query_delta += play_query_delta
		total_buy_query_delta += buy_query_delta
		total_play_commit_delta += play_commit_delta
		total_buy_commit_delta += buy_commit_delta
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
			"play_ai_state_query_delta": play_query_delta,
			"buy_ai_state_query_delta": buy_query_delta,
			"play_state_commit_delta": play_commit_delta,
			"buy_state_commit_delta": buy_commit_delta,
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
	print(
		"NEXT_AI_FRAME_HOTSPOT_CHARACTERIZATION|mode=%s|play_elapsed_msec=%d|buy_elapsed_msec=%d|play_queries=%d|buy_queries=%d|play_commits=%d|buy_commits=%d"
			% [
				mode,
				total_play_elapsed_msec,
				total_buy_elapsed_msec,
				total_play_query_delta,
				total_buy_query_delta,
				total_play_commit_delta,
				total_buy_commit_delta,
			]
	)
	var result := {
		"mode": mode,
		"elapsed_msec": elapsed_msec,
		"actor_count": actor_indices.size(),
		"buy_candidate_count": total_buy_candidates,
		"ai_state_query_delta": query_delta,
		"state_commit_delta": commit_delta,
		"play_elapsed_msec": total_play_elapsed_msec,
		"buy_elapsed_msec": total_buy_elapsed_msec,
		"play_ai_state_query_delta": total_play_query_delta,
		"buy_ai_state_query_delta": total_buy_query_delta,
		"play_state_commit_delta": total_play_commit_delta,
		"buy_state_commit_delta": total_buy_commit_delta,
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
	var structural_context_at := body.find("var turn_play_scoring_context: Dictionary = {")
	var play_candidates_at := body.find("_ai_card_play_candidates(player_index, turn_play_scoring_context)")
	var eager_prepare_at := body.find("_ai_card_turn_scoring_context(")
	var queue_attempt_at := body.find("if not play_choice.is_empty():")
	var fresh_context_at := body.find("var fallback_discard_scoring_context: Dictionary = {}")
	var empty_choice_reuse_at := body.find("if play_choice.is_empty():", fresh_context_at)
	var buy_call_at := body.find("_ai_card_buy_candidates(player_index, fallback_discard_scoring_context)")
	_expect(
		structural_context_at >= 0 \
			and play_candidates_at > structural_context_at \
			and eager_prepare_at < 0,
		"AI card execution creates only a structural play context before eligibility and queue guards"
	)
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
