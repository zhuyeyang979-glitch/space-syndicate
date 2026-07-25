extends SceneTree

const SESSION_DRIVER := preload("res://tests/support/production_session_start_driver.gd")
const QA_SAVE_PATH := "user://test_runs/ai_city_guess_candidate_performance_parity.save"
const SESSION_REQUEST_ID := "ai-city-guess-candidate-performance-parity"
const DETERMINISTIC_REQUEST_ID := "ai-city-guess-candidate-performance-parity-deterministic"
const DETERMINISTIC_SESSION_SEED := 2026072512
const CALL_LIMIT_MSEC := 30_000

const GOLDEN_LOCKED := true
const GOLDEN_ACTOR_COUNT := 3
const GOLDEN_CANDIDATE_COUNT := 27
const GOLDEN_SEMANTIC_SHA256 := "ec2510a397767a7b7ae84b0202854e1cb31dccad074b28e795a954cf147911d3"
const GOLDEN_NORMAL_TERMINAL_SHA256 := "cd4cb99791f77900224f327153d50e8cb825666e210efb580057fbfcece2f676"
const GOLDEN_REGION_PRIVATE_QUERY_DELTA := 3
const GOLDEN_AI_STATE_QUERY_DELTA := 171
const GOLDEN_STATE_COMMIT_DELTA := 0
const PROFILE_ACTION_COUNT := 2
const INTEL_TWO_ACTION_LIMIT_MSEC := 2_000
const FOCUS_CURRENT_TWO_ACTION_LIMIT_MSEC := 800
const PRODUCT_MARGIN_MIN_MSEC := 5_000

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
		_finish()
		return

	app_root.process_mode = Node.PROCESS_MODE_DISABLED
	var rng := coordinator.get_node_or_null("RunRngService") as RunRngService
	_expect(rng != null, "production coordinator owns RunRngService")
	if rng == null:
		await _cleanup(app_root)
		_finish()
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
		_finish()
		return

	session.pause_session()
	var world := coordinator.world_session_state()
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController
	var actor_state_port := coordinator.get_node_or_null("AiActorStatePort") as AiActorStatePort
	var region_query_port := coordinator.get_node_or_null("AiRegionKnowledgeQueryPort") as AiRegionKnowledgeQueryPort
	_expect(
		world != null and ai != null and actor_state_port != null and region_query_port != null,
		"production AI and typed query dependencies are available"
	)
	if world == null or ai == null or actor_state_port == null or region_query_port == null:
		await _cleanup(app_root)
		_finish()
		return

	var pressure_fixture_ready := _install_city_inference_pressure_fixture(world)
	_expect(pressure_fixture_ready, "focused fixture installs twelve active city-inference regions")
	if not pressure_fixture_ready:
		await _cleanup(app_root)
		_finish()
		return

	var actor_indices := _legal_ai_actors(world)
	_expect(actor_indices.size() == 3, "focused fixture exposes exactly three legal AI actors")
	var rng_before := rng.capture_plan_checkpoint()
	var actor_state_before := actor_state_port.debug_snapshot()
	var region_before := region_query_port.debug_snapshot()
	var started_msec := Time.get_ticks_msec()
	var actor_summaries: Array = []
	var candidate_count := 0
	print("AI_CITY_GUESS_CANDIDATE_PERFORMANCE|AGGREGATE|CALL_STARTED|actor_count=%d" % actor_indices.size())
	for actor_index_variant in actor_indices:
		var actor_index := int(actor_index_variant)
		var actor_started_msec := Time.get_ticks_msec()
		var actor_rng_before := rng.capture_plan_checkpoint()
		var candidates := ai.call("_ai_city_guess_candidates", actor_index) as Array
		var actor_elapsed_msec := Time.get_ticks_msec() - actor_started_msec
		var actor_rng_after := rng.capture_plan_checkpoint()
		candidate_count += candidates.size()
		var projection := _candidate_projection(candidates)
		var ranked := ai.rank_candidates(actor_index, candidates, {"source_context": "city_guess_performance"})
		var force_rng_before := rng.capture_plan_checkpoint()
		var forced := ai.call("_ai_pick_candidate", actor_index, candidates, true) as Dictionary
		var force_rng_after := rng.capture_plan_checkpoint()
		var normal_checkpoint := rng.capture_plan_checkpoint()
		var normal := ai.call("_ai_pick_candidate", actor_index, candidates, false) as Dictionary
		var normal_terminal := rng.capture_plan_checkpoint()
		var restored := rng.restore_plan_checkpoint(normal_checkpoint)
		var normal_replay := ai.call("_ai_pick_candidate", actor_index, candidates, false) as Dictionary
		var normal_replay_terminal := rng.capture_plan_checkpoint()
		var reset_after_replay := rng.restore_plan_checkpoint(normal_checkpoint)
		_expect(actor_rng_after == actor_rng_before, "actor %d candidate generation consumes zero RNG" % actor_index)
		_expect(force_rng_after == force_rng_before, "actor %d force selection consumes zero RNG" % actor_index)
		_expect(bool(restored.get("restored", false)), "actor %d normal selection checkpoint restores" % actor_index)
		_expect(bool(reset_after_replay.get("restored", false)), "actor %d replay terminal checkpoint resets" % actor_index)
		_expect(_candidate_projection_row(normal) == _candidate_projection_row(normal_replay), "actor %d normal selection replays identically" % actor_index)
		_expect(normal_terminal == normal_replay_terminal, "actor %d normal selection reaches the same terminal RNG" % actor_index)
		actor_summaries.append({
			"actor_index": actor_index,
			"elapsed_msec": actor_elapsed_msec,
			"candidate_count": candidates.size(),
			"projection_sha256": JSON.stringify(projection).sha256_text(),
			"original_order_sha256": JSON.stringify(_candidate_order(projection)).sha256_text(),
			"ranked_order_sha256": JSON.stringify(_candidate_order(_candidate_projection(ranked))).sha256_text(),
			"force_selection_sha256": JSON.stringify(_candidate_projection_row(forced)).sha256_text(),
			"normal_selection_sha256": JSON.stringify(_candidate_projection_row(normal)).sha256_text(),
			"normal_terminal_sha256": JSON.stringify(normal_terminal).sha256_text(),
		})
	var elapsed_msec := Time.get_ticks_msec() - started_msec
	var actor_state_after := actor_state_port.debug_snapshot()
	var region_after := region_query_port.debug_snapshot()
	var rng_after := rng.capture_plan_checkpoint()
	var region_private_query_delta := int(region_after.get("private_query_count", 0)) - int(region_before.get("private_query_count", 0))
	var ai_state_query_delta := int(actor_state_after.get("ai_state_query_count", 0)) - int(actor_state_before.get("ai_state_query_count", 0))
	var state_commit_delta := int(actor_state_after.get("state_commit_count", 0)) - int(actor_state_before.get("state_commit_count", 0))
	var semantic_projection := _semantic_projection(actor_summaries)
	var semantic_sha256 := JSON.stringify(semantic_projection).sha256_text()
	var normal_terminal_sha256 := JSON.stringify(rng_after).sha256_text()
	print(
		"AI_CITY_GUESS_CANDIDATE_PERFORMANCE|AGGREGATE|CALL_COMPLETED|elapsed_msec=%d|actor_count=%d|candidate_count=%d"
			% [elapsed_msec, actor_indices.size(), candidate_count]
	)
	print(
		"AI_CITY_GUESS_CANDIDATE_PERFORMANCE|AGGREGATE|QUERY_COUNTERS|region_private_query_delta=%d|ai_state_query_delta=%d|state_commit_delta=%d"
			% [region_private_query_delta, ai_state_query_delta, state_commit_delta]
	)
	print("AI_CITY_GUESS_CANDIDATE_PERFORMANCE|AGGREGATE|SAFE_SUMMARY|%s" % JSON.stringify({
		"elapsed_msec": elapsed_msec,
		"actor_count": actor_indices.size(),
		"candidate_count": candidate_count,
		"region_private_query_delta": region_private_query_delta,
		"ai_state_query_delta": ai_state_query_delta,
		"state_commit_delta": state_commit_delta,
		"semantic_sha256": semantic_sha256,
		"normal_terminal_sha256": normal_terminal_sha256,
		"actors": actor_summaries,
	}))
	_expect(elapsed_msec < CALL_LIMIT_MSEC, "three-AI city-guess candidate aggregate stays below the product limit")
	_expect(candidate_count > 0, "three-AI aggregate exposes city-guess candidates")
	_expect(rng_after == rng_before, "aggregate characterization restores the original RNG checkpoint")
	_expect(state_commit_delta == 0, "city-guess candidate generation and selection commit no AI state")
	if GOLDEN_LOCKED:
		_expect(actor_indices.size() == GOLDEN_ACTOR_COUNT, "actor count matches the frozen baseline")
		_expect(candidate_count == GOLDEN_CANDIDATE_COUNT, "candidate count matches the frozen baseline")
		_expect(semantic_sha256 == GOLDEN_SEMANTIC_SHA256, "candidate, order, and selection hashes match the frozen baseline")
		_expect(normal_terminal_sha256 == GOLDEN_NORMAL_TERMINAL_SHA256, "aggregate terminal RNG hash matches the frozen baseline")
		_expect(region_private_query_delta == GOLDEN_REGION_PRIVATE_QUERY_DELTA, "region-private query count matches the optimized contract")
		_expect(ai_state_query_delta == GOLDEN_AI_STATE_QUERY_DELTA, "AI-state query count matches the optimized contract")
		_expect(state_commit_delta == GOLDEN_STATE_COMMIT_DELTA, "AI-state commit count matches the frozen baseline")

	session.resume_session()
	_expect(
		session.session_state() == GameSessionRuntimeController.STATE_RUNNING
			and app_root.process_mode == Node.PROCESS_MODE_DISABLED,
		"Intel mutation profiling is authorized while automatic RuntimeLoop processing stays frozen"
	)
	_run_intel_record_parity(ai, actor_state_port, rng, world, actor_indices)
	_profile_record_context_substages(ai, actor_state_port, actor_indices[-1])
	_run_city_candidate_cache_reference_parity(ai, rng, world, actor_indices)

	await _cleanup(app_root)
	_finish()


func _run_intel_record_parity(
	ai: AiRuntimeController,
	actor_state_port: AiActorStatePort,
	rng: RunRngService,
	world: WorldSessionState,
	actor_indices: Array[int]
) -> void:
	var stale_focus_count := 0
	for actor_index in actor_indices.slice(0, PROFILE_ACTION_COUNT):
		var memory := ai.call("_ai_memory_for_player", actor_index) as Dictionary
		var product := str(memory.get("economic_focus_product", ""))
		if int(memory.get("economic_focus_cycle", -1)) != int(ai.get("business_cycle_count")) \
				or product.is_empty() \
				or not (ai.get("PRODUCT_CATALOG") as Array).has(product):
			stale_focus_count += 1
	_expect(stale_focus_count == PROFILE_ACTION_COUNT, "focus-stale profile begins with both actors requiring the original refresh path")
	var world_checkpoint := world.capture_runtime_checkpoint()
	var rng_checkpoint := rng.capture_plan_checkpoint()
	var baseline := _measure_intel_action_stages(ai, actor_state_port, rng, actor_indices, true)
	var world_restore := world.restore_runtime_checkpoint(world_checkpoint)
	var rng_restore := rng.restore_plan_checkpoint(rng_checkpoint)
	_expect(bool(world_restore.get("applied", false)), "Intel record parity restores the exact pre-baseline world checkpoint")
	_expect(bool(rng_restore.get("restored", false)), "Intel record parity restores the exact pre-baseline RNG checkpoint")
	var optimized := _measure_intel_action_stages(ai, actor_state_port, rng, actor_indices, false)

	var semantic_parity: bool = baseline.get("semantic_projection", []) == optimized.get("semantic_projection", [])
	var route_plan_parity: bool = baseline.get("route_plan_projection", []) == optimized.get("route_plan_projection", [])
	var memory_parity: bool = baseline.get("memory_projection", []) == optimized.get("memory_projection", [])
	var sample_parity: bool = baseline.get("decision_sample_projection", []) == optimized.get("decision_sample_projection", [])
	var commit_parity: bool = int(baseline.get("state_commit_delta", -1)) == int(optimized.get("state_commit_delta", -2)) \
		and baseline.get("commit_projection", []) == optimized.get("commit_projection", [])
	var rng_parity: bool = baseline.get("rng_after", {}) == optimized.get("rng_after", {})
	var query_reduction := int(optimized.get("ai_state_query_delta", 0)) < int(baseline.get("ai_state_query_delta", 0))
	var optimized_elapsed_msec := int(optimized.get("total_elapsed_msec", INTEL_TWO_ACTION_LIMIT_MSEC))
	var two_action_limit_met := optimized_elapsed_msec < INTEL_TWO_ACTION_LIMIT_MSEC
	var product_margin_msec := CALL_LIMIT_MSEC - optimized_elapsed_msec
	var product_margin_met := product_margin_msec > PRODUCT_MARGIN_MIN_MSEC
	var gate_passed: bool = semantic_parity \
		and route_plan_parity \
		and memory_parity \
		and sample_parity \
		and commit_parity \
		and rng_parity \
		and query_reduction \
		and two_action_limit_met \
		and product_margin_met
	print("AI_INTEL_DECISION_STAGE_PROFILE|BASELINE|%s" % JSON.stringify(baseline))
	print("AI_INTEL_DECISION_STAGE_PROFILE|OPTIMIZED|%s" % JSON.stringify(optimized))
	print(
		"INTEL_DECISION_RECORD_GATE|status=%s|baseline_elapsed_msec=%d|optimized_elapsed_msec=%d|baseline_queries=%d|optimized_queries=%d|commits=%d|product_margin_msec=%d"
			% [
				"PASS" if gate_passed else "FAIL",
				int(baseline.get("total_elapsed_msec", -1)),
				optimized_elapsed_msec,
				int(baseline.get("ai_state_query_delta", -1)),
				int(optimized.get("ai_state_query_delta", -1)),
				int(optimized.get("state_commit_delta", -1)),
				product_margin_msec,
			]
	)
	_expect(semantic_parity, "optimized Intel record preserves candidate, order, and normal selection hashes")
	_expect(route_plan_parity, "optimized Intel record preserves each actor's route plan and ranked route memory")
	_expect(memory_parity, "optimized Intel record preserves complete final AI memory for both actors")
	_expect(sample_parity, "optimized Intel record preserves every decision sample")
	_expect(commit_parity, "optimized Intel record preserves per-actor and aggregate state commit counts")
	_expect(rng_parity, "optimized Intel record preserves terminal RNG")
	_expect(query_reduction, "optimized Intel record reduces AI-state queries")
	_expect(two_action_limit_met, "optimized complete two-action Intel cycle stays below two seconds")
	_expect(product_margin_met, "optimized Intel cycle leaves more than five seconds of product timeout margin")

	var focus_current := _run_focus_current_record_parity(ai, actor_state_port, rng, world, actor_indices)
	var focus_gate_passed: bool = gate_passed and bool(focus_current.get("gate_passed", false))
	print(
		"DECISION_FOCUS_SNAPSHOT_REUSE_GATE|status=%s|stale_baseline_msec=%d|stale_optimized_msec=%d|stale_baseline_queries=%d|stale_optimized_queries=%d|current_baseline_msec=%d|current_optimized_msec=%d|current_baseline_queries=%d|current_optimized_queries=%d"
			% [
				"PASS" if focus_gate_passed else "FAIL",
				int(baseline.get("total_elapsed_msec", -1)),
				optimized_elapsed_msec,
				int(baseline.get("ai_state_query_delta", -1)),
				int(optimized.get("ai_state_query_delta", -1)),
				int(focus_current.get("baseline_elapsed_msec", -1)),
				int(focus_current.get("optimized_elapsed_msec", -1)),
				int(focus_current.get("baseline_queries", -1)),
				int(focus_current.get("optimized_queries", -1)),
			]
	)
	_expect(focus_gate_passed, "focus snapshot reuse preserves stale/current semantics and meets the current-focus budget")


func _run_focus_current_record_parity(
	ai: AiRuntimeController,
	actor_state_port: AiActorStatePort,
	rng: RunRngService,
	world: WorldSessionState,
	actor_indices: Array[int]
) -> Dictionary:
	var current_focus_count := 0
	for actor_index in actor_indices.slice(0, PROFILE_ACTION_COUNT):
		ai.call("_ai_refresh_economic_focus", actor_index)
		ai.call("_ai_refresh_game_phase", actor_index)
		ai.call("_ai_refresh_strategy_intent", actor_index)
		ai.call("_ai_refresh_route_plan", actor_index)
		var memory := ai.call("_ai_memory_for_player", actor_index) as Dictionary
		var cycle := int(ai.get("business_cycle_count"))
		if int(memory.get("economic_focus_cycle", -1)) == cycle \
				and not str(memory.get("economic_focus_product", "")).is_empty() \
				and int(memory.get("strategic_intent_cycle", -1)) == cycle \
				and not str(memory.get("strategic_intent", "")).is_empty() \
				and int(memory.get("route_plan_cycle", -1)) == cycle \
				and not str(memory.get("route_plan_product", "")).is_empty() \
				and not str(memory.get("route_plan_stage", "")).is_empty():
			current_focus_count += 1
	_expect(current_focus_count == PROFILE_ACTION_COUNT, "focus-current profile prewarms focus, phase, strategy, and route for both actors")

	var world_checkpoint := world.capture_runtime_checkpoint()
	var rng_checkpoint := rng.capture_plan_checkpoint()
	var baseline := _measure_intel_action_stages(ai, actor_state_port, rng, actor_indices, true)
	var world_restore := world.restore_runtime_checkpoint(world_checkpoint)
	var rng_restore := rng.restore_plan_checkpoint(rng_checkpoint)
	_expect(bool(world_restore.get("applied", false)), "focus-current parity restores the exact pre-reference world checkpoint")
	_expect(bool(rng_restore.get("restored", false)), "focus-current parity restores the exact pre-reference RNG checkpoint")
	var optimized := _measure_intel_action_stages(ai, actor_state_port, rng, actor_indices, false)

	var semantic_parity: bool = baseline.get("semantic_projection", []) == optimized.get("semantic_projection", [])
	var route_plan_parity: bool = baseline.get("route_plan_projection", []) == optimized.get("route_plan_projection", [])
	var memory_parity: bool = baseline.get("memory_projection", []) == optimized.get("memory_projection", [])
	var sample_parity: bool = baseline.get("decision_sample_projection", []) == optimized.get("decision_sample_projection", [])
	var commit_parity: bool = baseline.get("commit_projection", []) == optimized.get("commit_projection", []) \
		and int(baseline.get("state_commit_delta", -1)) == int(optimized.get("state_commit_delta", -2))
	var rng_parity: bool = baseline.get("rng_after", {}) == optimized.get("rng_after", {})
	var query_reduction: bool = int(optimized.get("ai_state_query_delta", 0)) < int(baseline.get("ai_state_query_delta", 0))
	var optimized_elapsed_msec := int(optimized.get("total_elapsed_msec", FOCUS_CURRENT_TWO_ACTION_LIMIT_MSEC))
	var current_limit_met: bool = optimized_elapsed_msec < FOCUS_CURRENT_TWO_ACTION_LIMIT_MSEC
	var current_commit_parity: bool = commit_parity \
		and int(baseline.get("state_commit_delta", -1)) == PROFILE_ACTION_COUNT
	var gate_passed: bool = semantic_parity \
		and route_plan_parity \
		and memory_parity \
		and sample_parity \
		and current_commit_parity \
		and rng_parity \
		and query_reduction \
		and current_limit_met
	_expect(semantic_parity, "focus-current optimization preserves candidate, order, and selection hashes")
	_expect(route_plan_parity, "focus-current optimization preserves route plans and ranked route memory")
	_expect(memory_parity, "focus-current optimization preserves complete final AI memory")
	_expect(sample_parity, "focus-current optimization preserves every decision sample")
	_expect(current_commit_parity, "focus-current optimization preserves one decision commit per actor")
	_expect(rng_parity, "focus-current optimization preserves terminal RNG")
	_expect(query_reduction, "focus-current optimization reduces actor-state queries")
	_expect(current_limit_met, "focus-current optimized two-action Intel cycle stays below 800ms")
	return {
		"gate_passed": gate_passed,
		"baseline_elapsed_msec": int(baseline.get("total_elapsed_msec", -1)),
		"optimized_elapsed_msec": optimized_elapsed_msec,
		"baseline_queries": int(baseline.get("ai_state_query_delta", -1)),
		"optimized_queries": int(optimized.get("ai_state_query_delta", -1)),
	}


func _measure_intel_action_stages(
	ai: AiRuntimeController,
	actor_state_port: AiActorStatePort,
	rng: RunRngService,
	actor_indices: Array[int],
	use_reference_record: bool
) -> Dictionary:
	var mode := "baseline" if use_reference_record else "optimized"
	var rng_before := rng.capture_plan_checkpoint()
	var actor_state_before := actor_state_port.debug_snapshot()
	var total_started_msec := Time.get_ticks_msec()
	var candidate_elapsed_msec := 0
	var pick_elapsed_msec := 0
	var apply_elapsed_msec := 0
	var record_elapsed_msec := 0
	var acted := 0
	var action_summaries: Array = []
	var semantic_projection: Array = []
	var route_plan_projection: Array = []
	var memory_projection: Array = []
	var decision_sample_projection: Array = []
	var commit_projection: Array = []
	for actor_index in actor_indices:
		if acted >= PROFILE_ACTION_COUNT:
			break
		var per_actor_state_before := actor_state_port.debug_snapshot()
		var candidate_started_msec := Time.get_ticks_msec()
		var candidates := ai.call("_ai_city_guess_candidates", actor_index) as Array
		var candidate_duration := Time.get_ticks_msec() - candidate_started_msec
		candidate_elapsed_msec += candidate_duration
		var pick_started_msec := Time.get_ticks_msec()
		var choice := ai.call("_ai_pick_candidate", actor_index, candidates, false) as Dictionary
		var pick_duration := Time.get_ticks_msec() - pick_started_msec
		pick_elapsed_msec += pick_duration
		if choice.is_empty():
			continue
		var district_index := int(choice.get("district", -1))
		var guessed_player := int(choice.get("guessed_player", -1))
		var apply_started_msec := Time.get_ticks_msec()
		var applied := bool(ai.call(
			"_mark_city_guess_for_player",
			actor_index,
			district_index,
			guessed_player,
			int(choice.get("confidence", WorldSessionState.CITY_GUESS_CONFIDENCE_LOW)),
			str(choice.get("reason_key", "intuition"))
		))
		var apply_duration := Time.get_ticks_msec() - apply_started_msec
		apply_elapsed_msec += apply_duration
		if not applied:
			continue
		var record_metadata := {
			"policy_kind": str(choice.get("policy_kind", "city_owner_guess")),
			"guessed_player": guessed_player,
			"confidence": int(choice.get("confidence", 0)),
			"reason_key": str(choice.get("reason_key", "")),
			"learning_bonus": int(choice.get("learning_bonus", 0)),
		}
		var record_started_msec := Time.get_ticks_msec()
		if use_reference_record:
			_record_ai_decision_reference(
				ai,
				actor_index,
				"城市业主推理",
				district_index,
				int(choice.get("score", 0)),
				str(choice.get("reason", "按公开商品和城市线索标注")),
				candidates,
				record_metadata
			)
		else:
			ai.call(
				"_record_ai_decision",
				actor_index,
				"城市业主推理",
				district_index,
				int(choice.get("score", 0)),
				str(choice.get("reason", "按公开商品和城市线索标注")),
				candidates,
				record_metadata
			)
		var record_duration := Time.get_ticks_msec() - record_started_msec
		record_elapsed_msec += record_duration
		var final_memory := ai.call("_ai_memory_for_player", actor_index) as Dictionary
		var decision_samples: Array = final_memory.get("decision_samples", []) \
			if final_memory.get("decision_samples", []) is Array else []
		var per_actor_state_after := actor_state_port.debug_snapshot()
		var per_actor_commit_delta := int(per_actor_state_after.get("state_commit_count", 0)) - int(per_actor_state_before.get("state_commit_count", 0))
		var candidate_projection := _candidate_projection(candidates)
		var ranked := ai.rank_candidates(actor_index, candidates, {"source_context": "intel_record_parity"})
		var actor_semantic := {
			"actor_index": actor_index,
			"candidate_count": candidates.size(),
			"candidate_sha256": JSON.stringify(candidate_projection).sha256_text(),
			"original_order_sha256": JSON.stringify(_candidate_order(candidate_projection)).sha256_text(),
			"ranked_order_sha256": JSON.stringify(_candidate_order(_candidate_projection(ranked))).sha256_text(),
			"selection_sha256": JSON.stringify(_candidate_projection_row(choice)).sha256_text(),
		}
		acted += 1
		action_summaries.append({
			"actor_index": actor_index,
			"candidate_elapsed_msec": candidate_duration,
			"pick_elapsed_msec": pick_duration,
			"apply_elapsed_msec": apply_duration,
			"record_elapsed_msec": record_duration,
			"candidate_count": candidates.size(),
			"choice_sha256": JSON.stringify(_candidate_projection_row(choice)).sha256_text(),
			"state_commit_delta": per_actor_commit_delta,
		})
		semantic_projection.append(actor_semantic)
		route_plan_projection.append({
			"actor_index": actor_index,
			"product": str(final_memory.get("route_plan_product", "")),
			"stage": str(final_memory.get("route_plan_stage", "")),
			"score": int(final_memory.get("route_plan_score", 0)),
			"reason": str(final_memory.get("route_plan_reason", "")),
			"target_city": int(final_memory.get("route_plan_target_city", -1)),
			"partner_district": int(final_memory.get("route_plan_partner_district", -1)),
			"rankings_sha256": JSON.stringify(_canonicalize(final_memory.get("route_plan_rankings", []))).sha256_text(),
		})
		memory_projection.append({
			"actor_index": actor_index,
			"memory_sha256": JSON.stringify(_canonicalize(final_memory)).sha256_text(),
		})
		decision_sample_projection.append({
			"actor_index": actor_index,
			"sample_count": decision_samples.size(),
			"samples_sha256": JSON.stringify(_canonicalize(decision_samples)).sha256_text(),
		})
		commit_projection.append({
			"actor_index": actor_index,
			"state_commit_delta": per_actor_commit_delta,
		})
	var total_elapsed_msec := Time.get_ticks_msec() - total_started_msec
	var actor_state_after := actor_state_port.debug_snapshot()
	var rng_after := rng.capture_plan_checkpoint()
	var ai_state_query_delta := int(actor_state_after.get("ai_state_query_count", 0)) - int(actor_state_before.get("ai_state_query_count", 0))
	var state_commit_delta := int(actor_state_after.get("state_commit_count", 0)) - int(actor_state_before.get("state_commit_count", 0))
	var result := {
		"mode": mode,
		"action_count": acted,
		"total_elapsed_msec": total_elapsed_msec,
		"candidate_elapsed_msec": candidate_elapsed_msec,
		"pick_elapsed_msec": pick_elapsed_msec,
		"apply_elapsed_msec": apply_elapsed_msec,
		"record_elapsed_msec": record_elapsed_msec,
		"ai_state_query_delta": ai_state_query_delta,
		"state_commit_delta": state_commit_delta,
		"rng_before": rng_before,
		"rng_after": rng_after,
		"actions": action_summaries,
		"semantic_projection": semantic_projection,
		"route_plan_projection": route_plan_projection,
		"memory_projection": memory_projection,
		"decision_sample_projection": decision_sample_projection,
		"commit_projection": commit_projection,
	}
	print("AI_INTEL_DECISION_STAGE_PROFILE|mode=%s|%s" % [mode, JSON.stringify(result)])
	_expect(acted == PROFILE_ACTION_COUNT, "stage profile executes exactly two complete Intel actions")
	return result


func _record_ai_decision_reference(
	ai: AiRuntimeController,
	player_index: int,
	kind: String,
	target_index: int,
	score: int,
	reason: String,
	candidates: Array,
	metadata: Dictionary
) -> void:
	if not bool(ai.call("_player_is_ai", player_index)):
		return
	ai.call("_ai_refresh_economic_focus", player_index)
	var phase_info := ai.call("_ai_refresh_game_phase", player_index) as Dictionary
	var observation := ai.call("_ai_observation_vector", player_index) as Dictionary
	var actor_state := ai.call("_ai_actor_state_snapshot", player_index) as Dictionary
	if actor_state.is_empty() or observation.is_empty():
		return
	var memory := ai.call("_normalized_ai_memory", actor_state.get("ai_memory", {})) as Dictionary
	var samples := (memory.get("decision_samples", []) as Array).duplicate(true)
	var sample := {
		"time": float(ai.get("game_time")),
		"cycle": int(ai.get("business_cycle_count")),
		"kind": kind,
		"target": target_index,
		"score": score,
		"reason": reason,
		"state": observation,
		"candidates": ai.call("_ai_candidate_training_views", candidates) as Array,
		"focus_product": String(memory.get("economic_focus_product", "")),
		"focus_score": int(memory.get("economic_focus_score", 0)),
		"focus_reason": String(memory.get("economic_focus_reason", "")),
		"strategy_intent": String(memory.get("strategic_intent", "")),
		"strategy_score": int(memory.get("strategic_intent_score", 0)),
		"strategy_reason": String(memory.get("strategic_intent_reason", "")),
		"route_plan_product": String(memory.get("route_plan_product", "")),
		"route_plan_stage": String(memory.get("route_plan_stage", "")),
		"route_plan_score": int(memory.get("route_plan_score", 0)),
		"route_plan_reason": String(memory.get("route_plan_reason", "")),
		"game_phase": String(phase_info.get("phase", "midgame")),
		"competitive_posture": String(phase_info.get("posture", "contesting")),
		"score_gap_to_leader": int(phase_info.get("gap", 0)),
		"leader_index": int(phase_info.get("leader_index", -1)),
		"phase_reason": String(phase_info.get("reason", "")),
		"endgame_urgency": int(ai.call("_ai_endgame_urgency_score", player_index)),
		"baseline_cash": int(observation.get("cash", 0)),
		"baseline_victory_gdp": int(observation.get("victory_top_n_gdp_per_minute", 0)),
		"baseline_victory_regions": int(observation.get("victory_controlled_region_count", 0)),
		"reward_cash": 0,
		"reward_victory_gdp": 0,
		"reward_victory_regions": 0,
		"reward_score": 0,
		"reward_finalized": false,
		"learning_applied": false,
	}
	var reserved_sample_fields := ["time", "cycle", "kind", "target", "state", "candidates", "reward_cash", "reward_victory_gdp", "reward_victory_regions", "reward_score", "reward_finalized", "learning_applied"]
	for key_variant in metadata.keys():
		if reserved_sample_fields.has(String(key_variant)):
			continue
		sample[key_variant] = metadata[key_variant]
	samples.append(sample)
	while samples.size() > int(ai.get("AI_DECISION_SAMPLE_LIMIT")):
		samples.pop_front()
	memory["decision_samples"] = samples
	var action_counts := (memory.get("action_counts", {}) as Dictionary).duplicate(true)
	action_counts[kind] = int(action_counts.get(kind, 0)) + 1
	memory["action_counts"] = action_counts
	memory["last_plan"] = "%s｜目标%d｜评分%d｜%s" % [kind, target_index + 1, score, reason]
	ai.call("_commit_ai_memory", player_index, memory, actor_state)


func _profile_record_context_substages(
	ai: AiRuntimeController,
	actor_state_port: AiActorStatePort,
	actor_index: int
) -> void:
	var candidates := ai.call("_ai_city_guess_candidates", actor_index) as Array
	var stages := {}
	var query_stages := {}
	var stage_started_msec := Time.get_ticks_msec()
	var state_before := actor_state_port.debug_snapshot()
	var focus_product := str(ai.call("_ai_refresh_economic_focus", actor_index))
	stages["focus_msec"] = Time.get_ticks_msec() - stage_started_msec
	var state_after := actor_state_port.debug_snapshot()
	query_stages["focus"] = int(state_after.get("ai_state_query_count", 0)) - int(state_before.get("ai_state_query_count", 0))

	stage_started_msec = Time.get_ticks_msec()
	state_before = actor_state_port.debug_snapshot()
	var phase_info := ai.call("_ai_refresh_game_phase", actor_index) as Dictionary
	stages["phase_msec"] = Time.get_ticks_msec() - stage_started_msec
	state_after = actor_state_port.debug_snapshot()
	query_stages["phase"] = int(state_after.get("ai_state_query_count", 0)) - int(state_before.get("ai_state_query_count", 0))

	stage_started_msec = Time.get_ticks_msec()
	state_before = actor_state_port.debug_snapshot()
	var economy_facts := ai.call("_actor_training_economy_facts", actor_index) as Dictionary
	var hand_snapshot := ai.call("_actor_hand_inventory_snapshot", actor_index) as Dictionary
	var observation_memory := ai.call("_ai_memory_for_player", actor_index) as Dictionary
	stages["snapshots_msec"] = Time.get_ticks_msec() - stage_started_msec
	state_after = actor_state_port.debug_snapshot()
	query_stages["snapshots"] = int(state_after.get("ai_state_query_count", 0)) - int(state_before.get("ai_state_query_count", 0))

	stage_started_msec = Time.get_ticks_msec()
	state_before = actor_state_port.debug_snapshot()
	for product_variant in ai.get("PRODUCT_CATALOG") as Array:
		ai.call("_player_product_flow", actor_index, str(product_variant))
	ai.call("_victory_top_n_gdp", actor_index)
	ai.call("_victory_controlled_regions", actor_index)
	ai.call("_player_active_city_count", actor_index)
	stages["world_facts_msec"] = Time.get_ticks_msec() - stage_started_msec
	state_after = actor_state_port.debug_snapshot()
	query_stages["world_facts"] = int(state_after.get("ai_state_query_count", 0)) - int(state_before.get("ai_state_query_count", 0))

	stage_started_msec = Time.get_ticks_msec()
	state_before = actor_state_port.debug_snapshot()
	var strategy := ai.call("_ai_refresh_strategy_intent", actor_index) as Dictionary
	stages["strategy_msec"] = Time.get_ticks_msec() - stage_started_msec
	state_after = actor_state_port.debug_snapshot()
	query_stages["strategy"] = int(state_after.get("ai_state_query_count", 0)) - int(state_before.get("ai_state_query_count", 0))

	stage_started_msec = Time.get_ticks_msec()
	state_before = actor_state_port.debug_snapshot()
	var route_plan := ai.call("_ai_refresh_route_plan", actor_index) as Dictionary
	stages["route_msec"] = Time.get_ticks_msec() - stage_started_msec
	state_after = actor_state_port.debug_snapshot()
	query_stages["route"] = int(state_after.get("ai_state_query_count", 0)) - int(state_before.get("ai_state_query_count", 0))

	stage_started_msec = Time.get_ticks_msec()
	state_before = actor_state_port.debug_snapshot()
	ai.call("_ai_endgame_urgency_score", actor_index)
	ai.call("_ai_actor_state_snapshot", actor_index)
	ai.call("_ai_candidate_training_views_for_decision", candidates)
	stages["tail_msec"] = Time.get_ticks_msec() - stage_started_msec
	state_after = actor_state_port.debug_snapshot()
	query_stages["tail"] = int(state_after.get("ai_state_query_count", 0)) - int(state_before.get("ai_state_query_count", 0))
	print("AI_INTEL_DECISION_RECORD_SUBSTAGES|%s" % JSON.stringify({
		"actor_index": actor_index,
		"candidate_count": candidates.size(),
		"focus_product": focus_product,
		"phase": str(phase_info.get("phase", "")),
		"economy_ready": not economy_facts.is_empty(),
		"hand_ready": not hand_snapshot.is_empty(),
		"memory_ready": not observation_memory.is_empty(),
		"strategy": str(strategy.get("intent", "")),
		"route_product": str(route_plan.get("product", "")),
		"stages": stages,
		"query_stages": query_stages,
	}))


func _run_city_candidate_cache_reference_parity(
	ai: AiRuntimeController,
	rng: RunRngService,
	world: WorldSessionState,
	actor_indices: Array[int]
) -> void:
	var viewer_index := actor_indices[0]
	var other_viewer_index := actor_indices[1]
	var world_checkpoint := world.capture_runtime_checkpoint()
	var rng_checkpoint := rng.capture_plan_checkpoint()
	var viewer_before_snapshot := ai.call("_city_inference_snapshot", viewer_index) as Dictionary
	var viewer_before := _compare_city_candidate_paths(ai, rng, viewer_index, "before_revision")
	var other_before := _compare_city_candidate_paths(ai, rng, other_viewer_index, "other_before_revision")
	var candidates_before := ai.call("_ai_city_guess_candidates", viewer_index) as Array
	var mutation_candidate: Dictionary = candidates_before[0] as Dictionary if not candidates_before.is_empty() else {}
	var mutation_applied := false
	if not mutation_candidate.is_empty():
		mutation_applied = bool(ai.call(
			"_mark_city_guess_for_player",
			viewer_index,
			int(mutation_candidate.get("district", -1)),
			int(mutation_candidate.get("guessed_player", -1)),
			WorldSessionState.CITY_GUESS_CONFIDENCE_HIGH,
			"product"
		))
	var viewer_after_snapshot := ai.call("_city_inference_snapshot", viewer_index) as Dictionary
	var viewer_after := _compare_city_candidate_paths(ai, rng, viewer_index, "after_revision")
	var other_after := _compare_city_candidate_paths(ai, rng, other_viewer_index, "other_after_revision")

	var initial_parity: bool = bool(viewer_before.get("parity", false)) and bool(other_before.get("parity", false))
	var revised_parity: bool = bool(viewer_after.get("parity", false)) and bool(other_after.get("parity", false))
	var revision_changed: bool = mutation_applied \
		and str(viewer_before_snapshot.get("owner_revision", "")) != str(viewer_after_snapshot.get("owner_revision", ""))
	var viewer_refresh_observed: bool = viewer_before.get("optimized_semantics", {}) != viewer_after.get("optimized_semantics", {})
	var other_viewer_isolated: bool = other_before.get("optimized_semantics", {}) == other_after.get("optimized_semantics", {})
	var rng_restored := rng.restore_plan_checkpoint(rng_checkpoint)
	var world_restored := world.restore_runtime_checkpoint(world_checkpoint)
	var gate_passed: bool = initial_parity \
		and revised_parity \
		and revision_changed \
		and viewer_refresh_observed \
		and other_viewer_isolated \
		and bool(rng_restored.get("restored", false)) \
		and bool(world_restored.get("applied", false))
	print(
		"CITY_CANDIDATE_CACHE_REFERENCE_GATE|status=%s|before_reference_queries=%d|before_optimized_queries=%d|after_reference_queries=%d|after_optimized_queries=%d|revision_changed=%s|viewer_refresh=%s|other_viewer_isolated=%s"
			% [
				"PASS" if gate_passed else "FAIL",
				int(viewer_before.get("reference_queries", -1)),
				int(viewer_before.get("optimized_queries", -1)),
				int(viewer_after.get("reference_queries", -1)),
				int(viewer_after.get("optimized_queries", -1)),
				str(revision_changed),
				str(viewer_refresh_observed),
				str(other_viewer_isolated),
			]
	)
	_expect(initial_parity, "uncached city reference matches optimized semantics, order, selection, and RNG for both viewers")
	_expect(revised_parity, "uncached city reference still matches optimized output after the owner revision changes")
	_expect(revision_changed, "viewer-private high-confidence mutation advances the city-inference owner revision")
	_expect(viewer_refresh_observed, "a new optimized call observes the revised owner state instead of a prior-frame cache")
	_expect(other_viewer_isolated, "viewer-private revision change does not pollute another viewer's optimized candidates")
	_expect(bool(rng_restored.get("restored", false)) and bool(world_restored.get("applied", false)), "city cache parity restores its world and RNG checkpoints")


func _compare_city_candidate_paths(
	ai: AiRuntimeController,
	rng: RunRngService,
	viewer_index: int,
	label: String
) -> Dictionary:
	var path_checkpoint := rng.capture_plan_checkpoint()
	var reference := _measure_city_candidate_path(ai, rng, viewer_index, true)
	var reference_restore := rng.restore_plan_checkpoint(path_checkpoint)
	var optimized := _measure_city_candidate_path(ai, rng, viewer_index, false)
	var optimized_restore := rng.restore_plan_checkpoint(path_checkpoint)
	var parity: bool = reference.get("semantics", {}) == optimized.get("semantics", {}) \
		and reference.get("terminal_rng", {}) == optimized.get("terminal_rng", {}) \
		and bool(reference_restore.get("restored", false)) \
		and bool(optimized_restore.get("restored", false))
	_expect(parity, "%s uncached and optimized city candidate paths are behaviorally identical" % label)
	return {
		"parity": parity,
		"reference_queries": int(reference.get("private_query_delta", -1)),
		"optimized_queries": int(optimized.get("private_query_delta", -1)),
		"reference_semantics": reference.get("semantics", {}),
		"optimized_semantics": optimized.get("semantics", {}),
	}


func _measure_city_candidate_path(
	ai: AiRuntimeController,
	rng: RunRngService,
	viewer_index: int,
	uncached_reference: bool
) -> Dictionary:
	var region_query_port := ai.get_node_or_null("../AiRegionKnowledgeQueryPort") as AiRegionKnowledgeQueryPort
	var query_before := region_query_port.debug_snapshot() if region_query_port != null else {}
	var candidates := _city_candidates_uncached_reference(ai, viewer_index) \
		if uncached_reference else ai.call("_ai_city_guess_candidates", viewer_index) as Array
	var projection := _candidate_projection(candidates)
	var ranked := ai.rank_candidates(viewer_index, candidates, {"source_context": "city_cache_reference_parity"})
	var force_rng_before := rng.capture_plan_checkpoint()
	var forced := ai.call("_ai_pick_candidate", viewer_index, candidates, true) as Dictionary
	var force_rng_after := rng.capture_plan_checkpoint()
	var normal := ai.call("_ai_pick_candidate", viewer_index, candidates, false) as Dictionary
	var terminal_rng := rng.capture_plan_checkpoint()
	var query_after := region_query_port.debug_snapshot() if region_query_port != null else {}
	return {
		"semantics": {
			"candidate_count": candidates.size(),
			"projection_sha256": JSON.stringify(projection).sha256_text(),
			"original_order_sha256": JSON.stringify(_candidate_order(projection)).sha256_text(),
			"ranked_order_sha256": JSON.stringify(_candidate_order(_candidate_projection(ranked))).sha256_text(),
			"force_selection_sha256": JSON.stringify(_candidate_projection_row(forced)).sha256_text(),
			"normal_selection_sha256": JSON.stringify(_candidate_projection_row(normal)).sha256_text(),
			"force_rng_unchanged": force_rng_before == force_rng_after,
		},
		"terminal_rng": terminal_rng,
		"private_query_delta": int(query_after.get("private_query_count", 0)) - int(query_before.get("private_query_count", 0)),
	}


func _city_candidates_uncached_reference(ai: AiRuntimeController, viewer_index: int) -> Array:
	var result: Array = []
	var player_count := int(ai.call("_public_player_count"))
	var entries := ai.call("_intel_city_guess_entries", viewer_index, 12) as Array
	for entry_variant in entries:
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		if bool(entry.get("marked", false)) \
				and int(entry.get("confidence", 0)) >= WorldSessionState.CITY_GUESS_CONFIDENCE_HIGH:
			continue
		var best: Dictionary = {}
		for guessed_player in range(player_count):
			var candidate := ai.call("_ai_city_guess_owner_candidate", viewer_index, entry, guessed_player) as Dictionary
			if candidate.is_empty():
				continue
			if best.is_empty() or int(candidate.get("score", 0)) > int(best.get("score", 0)):
				best = candidate
		if not best.is_empty():
			result.append(best)
	return result


func _semantic_projection(actor_summaries: Array) -> Array:
	var result: Array = []
	for summary_variant in actor_summaries:
		var summary := summary_variant as Dictionary
		result.append({
			"actor_index": int(summary.get("actor_index", -1)),
			"candidate_count": int(summary.get("candidate_count", 0)),
			"projection_sha256": str(summary.get("projection_sha256", "")),
			"original_order_sha256": str(summary.get("original_order_sha256", "")),
			"ranked_order_sha256": str(summary.get("ranked_order_sha256", "")),
			"force_selection_sha256": str(summary.get("force_selection_sha256", "")),
			"normal_selection_sha256": str(summary.get("normal_selection_sha256", "")),
			"normal_terminal_sha256": str(summary.get("normal_terminal_sha256", "")),
		})
	return result


func _candidate_projection(candidates: Array) -> Array:
	var result: Array = []
	for candidate_variant in candidates:
		if candidate_variant is Dictionary:
			result.append(_candidate_projection_row(candidate_variant as Dictionary))
	return result


func _candidate_projection_row(candidate: Dictionary) -> Dictionary:
	return _canonicalize(candidate) as Dictionary


func _candidate_order(projection: Array) -> Array:
	var result: Array = []
	for candidate_variant in projection:
		if not (candidate_variant is Dictionary):
			continue
		var candidate := candidate_variant as Dictionary
		result.append({
			"kind": str(candidate.get("kind", "")),
			"district": int(candidate.get("district", -1)),
			"guessed_player": int(candidate.get("guessed_player", -1)),
			"confidence": int(candidate.get("confidence", 0)),
			"reason_key": str(candidate.get("reason_key", "")),
			"learning_bonus": int(candidate.get("learning_bonus", 0)),
			"score": int(candidate.get("score", 0)),
		})
	return result


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


func _legal_ai_actors(world: WorldSessionState) -> Array[int]:
	var result: Array[int] = []
	for player_index in range(world.players.size()):
		var player: Dictionary = world.players[player_index]
		if bool(player.get("is_ai", false)) and not bool(player.get("eliminated", false)):
			result.append(player_index)
	return result


func _install_city_inference_pressure_fixture(world: WorldSessionState) -> bool:
	if world.players.size() != 4:
		return false
	var products := ["生命", "能源", "信息", "工业", "贸易", "科技"]
	var districts: Array = []
	for district_index in range(12):
		var first_product := str(products[district_index % products.size()])
		var second_product := str(products[(district_index + 1) % products.size()])
		var third_product := str(products[(district_index + 2) % products.size()])
		var owner_index := district_index % 4
		districts.append({
			"region_id": "region.%03d" % district_index,
			"name": "压力区域%02d" % (district_index + 1),
			"destroyed": false,
			"terrain": "land" if district_index % 2 == 0 else "ocean",
			"products": [first_product, second_product, third_product],
			"demands": [third_product, second_product, first_product],
			"city": {
				"active": true,
				"owner": owner_index,
				"level": 2,
				"products": [
					{"name": first_product},
					{"name": second_product},
					{"name": third_product},
				],
				"demands": [third_product, second_product, first_product],
				"last_income": 40 + district_index * 3,
				"trade_disrupted_routes": district_index % 3,
				"public_clues": [
					{"text": "公开商品流向", "products": [first_product, third_product]},
					{"text": "公开需求变化", "products": [second_product]},
				],
			},
		})
	var players := world.players.duplicate(true)
	for viewer_index in range(players.size()):
		var player := (players[viewer_index] as Dictionary).duplicate(true)
		var guesses := {}
		var confidences := {}
		var reasons := {}
		for district_index in range(districts.size()):
			var owner_index := int((districts[district_index] as Dictionary).get("city", {}).get("owner", -1))
			if owner_index == viewer_index:
				continue
			var guessed_player := (owner_index + 1) % players.size()
			if guessed_player == viewer_index:
				guessed_player = (guessed_player + 1) % players.size()
			guesses[district_index] = guessed_player
			confidences[district_index] = WorldSessionState.CITY_GUESS_CONFIDENCE_MEDIUM
			reasons[district_index] = "product"
		player["city_guesses"] = guesses
		player["city_guess_confidence"] = confidences
		player["city_guess_reasons"] = reasons
		players[viewer_index] = player
	world.restore({
		"players": players,
		"districts": districts,
		"game_time": world.game_time,
	}, true)
	return world.players.size() == 4 \
		and world.districts.size() == 12


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


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("AI_CITY_GUESS_CANDIDATE_PERFORMANCE_TEST|status=%s|checks=%d|failures=%d" % [status, _checks, _failures.size()])
	for failure in _failures:
		push_error("AI_CITY_GUESS_CANDIDATE_PERFORMANCE_TEST: %s" % failure)
	quit(0 if _failures.is_empty() else 1)
