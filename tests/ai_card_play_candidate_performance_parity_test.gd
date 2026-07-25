extends SceneTree

const SESSION_DRIVER := preload("res://tests/support/production_session_start_driver.gd")
const QA_SAVE_PATH := "user://test_runs/ai_card_play_candidate_performance_parity.save"
const SESSION_REQUEST_ID := "ai-card-play-candidate-performance-parity"
const DETERMINISTIC_REQUEST_ID := "ai-card-play-candidate-performance-parity-deterministic"
const DETERMINISTIC_SESSION_SEED := 2026072501
const PRODUCT_LIMIT_MSEC := 30_000

const REQUIRED_PROJECTION_FIELDS := [
	"action",
	"slot_index",
	"card_name",
	"kind",
	"policy_kind",
	"district",
	"target_slot",
	"target_player",
	"product",
	"score",
]

# Frozen from unchanged production in run
# 20260725-004628-735-ai_card_play_candidate_performance_parity_test-ac7e1662.
const GOLDEN_LOCKED := true
const GOLDEN_CANDIDATE_COUNT := 1
const GOLDEN_PROJECTION_SHA256 := "f329df1f8a8b04508e53f29e56244fee81bbd186f75606b7b1025340a52d64f3"
const GOLDEN_ORIGINAL_ORDER_SHA256 := "237bceb0caf77bd132384a6fb5f626fed9becb2070c346d808da36defd0cce61"
const GOLDEN_RANKED_ORDER_SHA256 := "237bceb0caf77bd132384a6fb5f626fed9becb2070c346d808da36defd0cce61"
const GOLDEN_FORCE_SELECTION_SHA256 := "505a6887dc16826b0171669289404bec75bbed35412fb87310c7d323898b4b86"
const GOLDEN_NORMAL_SELECTION_SHA256 := "505a6887dc16826b0171669289404bec75bbed35412fb87310c7d323898b4b86"
const GOLDEN_NORMAL_TERMINAL_SHA256 := "de8e5bac67516eca681844c67c09c05ebb6a39acc38d1916fd19109de93bcd58"
const GOLDEN_FINAL_MEMORY_SHA256 := "9a1951ceac14f8fdfd28488f9105b2e0c405a5b5b4160666caaa05ec1637c957"
const GOLDEN_AI_STATE_QUERY_COUNT_DELTA := 219
const GOLDEN_STATE_COMMIT_COUNT_DELTA := 4

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
	_expect(session.session_state() == GameSessionRuntimeController.STATE_PAUSED, "fixture pauses before the focused query")
	_expect(world != null and ai != null and actor_state_port != null, "production world and AI query dependencies are available")
	_expect(
		world != null
			and world.players.size() == 4
			and not bool((world.players[0] as Dictionary).get("is_ai", true))
			and bool((world.players[1] as Dictionary).get("is_ai", false))
			and bool((world.players[2] as Dictionary).get("is_ai", false))
			and bool((world.players[3] as Dictionary).get("is_ai", false)),
		"formal roster contains one human and three AI seats"
	)
	if world == null or ai == null or actor_state_port == null:
		await _cleanup(app_root)
		_finish()
		return

	session.resume_session()
	_expect(
		session.session_state() == GameSessionRuntimeController.STATE_RUNNING
			and app_root.process_mode == Node.PROCESS_MODE_DISABLED,
		"typed-query authorization runs while RuntimeLoop processing stays frozen"
	)
	var actor_index := _first_legal_ai_actor(world)
	_expect(actor_index >= 1, "focused query selects one legal AI actor")
	if actor_index < 1:
		await _cleanup(app_root)
		_finish()
		return

	var rng_before_generation := rng.capture_plan_checkpoint()
	var actor_state_debug_before := actor_state_port.debug_snapshot()
	print("AI_CARD_PLAY_CANDIDATE_PERFORMANCE|CALL_STARTED")
	var call_started_msec := Time.get_ticks_msec()
	var candidates := ai.call("_ai_card_play_candidates", actor_index) as Array
	var call_elapsed_msec := Time.get_ticks_msec() - call_started_msec
	var actor_state_debug_after := actor_state_port.debug_snapshot()
	var ai_state_query_count_delta := int(actor_state_debug_after.get("ai_state_query_count", 0)) - int(actor_state_debug_before.get("ai_state_query_count", 0))
	var state_commit_count_delta := int(actor_state_debug_after.get("state_commit_count", 0)) - int(actor_state_debug_before.get("state_commit_count", 0))
	print(
		"AI_CARD_PLAY_CANDIDATE_PERFORMANCE|CALL_COMPLETED|elapsed_msec=%d|candidate_count=%d"
			% [call_elapsed_msec, candidates.size()]
	)
	print(
		"AI_CARD_PLAY_CANDIDATE_PERFORMANCE|QUERY_COUNTERS|ai_state_query_count_delta=%d|state_commit_count_delta=%d"
			% [ai_state_query_count_delta, state_commit_count_delta]
	)
	var rng_after_generation := rng.capture_plan_checkpoint()
	_expect(call_elapsed_msec < PRODUCT_LIMIT_MSEC, "candidate generation stays below the product timeout")
	_expect(not candidates.is_empty(), "formal AI actor exposes at least one legal card-play candidate")
	_expect(rng_after_generation == rng_before_generation, "candidate generation consumes zero RunRngService draws")

	var projection := _candidate_projection(candidates)
	var projection_json := JSON.stringify(projection)
	var projection_sha256 := projection_json.sha256_text()
	var missing_projection_fields := _missing_projection_fields(projection)
	_expect(missing_projection_fields.is_empty(), "complete detached projection contains every ordering and selection input")
	_expect(TablePresentationPureDataPolicy.is_pure_data(projection), "candidate projection is detached pure data")

	var final_memory_variant: Variant = ai.call("_ai_memory_for_player", actor_index)
	var detached_final_memory := (final_memory_variant as Dictionary).duplicate(true) \
		if final_memory_variant is Dictionary else {}
	var compact_final_memory := _compact_final_memory_projection(detached_final_memory)
	var memory_reference := _first_memory_context_candidate(projection)
	var expected_final_memory := _candidate_memory_context_projection(memory_reference)
	_expect(not detached_final_memory.is_empty(), "formal AI actor exposes detached final decision memory")
	_expect(not memory_reference.is_empty(), "at least one candidate carries the final memory context")
	_expect(TablePresentationPureDataPolicy.is_pure_data(compact_final_memory), "compact final-memory projection is detached pure data")
	_expect(
		compact_final_memory == expected_final_memory,
		"final focus, phase, strategy, and route memory matches the candidate context"
	)
	var final_memory_sha256 := JSON.stringify(compact_final_memory).sha256_text()

	var original_order_json := JSON.stringify(_candidate_order(projection))
	var ranked := ai.rank_candidates(actor_index, candidates, {"source_context": "focused_performance_parity"})
	var ranked_projection := _candidate_projection(ranked)
	var ranked_order_json := JSON.stringify(_candidate_order(ranked_projection))

	var force_rng_before := rng.capture_plan_checkpoint()
	var forced_selection := ai.call("_ai_pick_candidate", actor_index, candidates, true) as Dictionary
	var force_rng_after := rng.capture_plan_checkpoint()
	_expect(force_rng_after == force_rng_before, "force=true selection consumes zero RNG")

	var normal_checkpoint := rng.capture_plan_checkpoint()
	var normal_selection_first := ai.call("_ai_pick_candidate", actor_index, candidates, false) as Dictionary
	var normal_terminal_first := rng.capture_plan_checkpoint()
	var restored := rng.restore_plan_checkpoint(normal_checkpoint)
	var normal_selection_replay := ai.call("_ai_pick_candidate", actor_index, candidates, false) as Dictionary
	var normal_terminal_replay := rng.capture_plan_checkpoint()
	_expect(bool(restored.get("restored", false)), "normal selection restores through RunRngService")
	_expect(
		_candidate_projection_row(normal_selection_first) == _candidate_projection_row(normal_selection_replay),
		"normal selection is deterministic from the same RNG checkpoint"
	)
	_expect(normal_terminal_first == normal_terminal_replay, "normal selection reaches the same terminal RNG cursor")

	var force_selection_sha256 := JSON.stringify(_candidate_projection_row(forced_selection)).sha256_text()
	var normal_selection_sha256 := JSON.stringify(_candidate_projection_row(normal_selection_first)).sha256_text()
	var normal_terminal_sha256 := JSON.stringify(normal_terminal_first).sha256_text()
	var safe_summary := {
		"elapsed_msec": call_elapsed_msec,
		"candidate_count": candidates.size(),
		"ai_state_query_count_delta": ai_state_query_count_delta,
		"state_commit_count_delta": state_commit_count_delta,
		"projection_sha256": projection_sha256,
		"original_order_sha256": original_order_json.sha256_text(),
		"ranked_order_sha256": ranked_order_json.sha256_text(),
		"force_selection_sha256": force_selection_sha256,
		"normal_selection_sha256": normal_selection_sha256,
		"normal_terminal_sha256": normal_terminal_sha256,
		"final_memory_sha256": final_memory_sha256,
	}
	print("AI_CARD_PLAY_CANDIDATE_PERFORMANCE|SAFE_SUMMARY|%s" % JSON.stringify(safe_summary))

	if GOLDEN_LOCKED:
		_expect(candidates.size() == GOLDEN_CANDIDATE_COUNT, "candidate count matches the frozen baseline")
		_expect(projection_sha256 == GOLDEN_PROJECTION_SHA256, "complete candidate projection matches the frozen baseline")
		_expect(original_order_json.sha256_text() == GOLDEN_ORIGINAL_ORDER_SHA256, "original candidate order matches the frozen baseline")
		_expect(ranked_order_json.sha256_text() == GOLDEN_RANKED_ORDER_SHA256, "ranked candidate order matches the frozen baseline")
		_expect(force_selection_sha256 == GOLDEN_FORCE_SELECTION_SHA256, "force=true selection matches the frozen baseline")
		_expect(normal_selection_sha256 == GOLDEN_NORMAL_SELECTION_SHA256, "normal selection matches the frozen baseline")
		_expect(normal_terminal_sha256 == GOLDEN_NORMAL_TERMINAL_SHA256, "normal selection terminal RNG matches the frozen baseline")
		_expect(final_memory_sha256 == GOLDEN_FINAL_MEMORY_SHA256, "final compact memory matches the frozen baseline")
		_expect(ai_state_query_count_delta == GOLDEN_AI_STATE_QUERY_COUNT_DELTA, "actor-state query count matches the frozen baseline")
		_expect(state_commit_count_delta == GOLDEN_STATE_COMMIT_COUNT_DELTA, "actor-state commit count matches the frozen baseline")

	await _cleanup(app_root)
	_finish()


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


func _missing_projection_fields(projection: Array) -> Array:
	var missing: Array = []
	for candidate_index in range(projection.size()):
		if not (projection[candidate_index] is Dictionary):
			missing.append("%d:not_dictionary" % candidate_index)
			continue
		var candidate := projection[candidate_index] as Dictionary
		for field_name in REQUIRED_PROJECTION_FIELDS:
			if not candidate.has(field_name):
				missing.append("%d:%s" % [candidate_index, field_name])
	return missing


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
	print("AI_CARD_PLAY_CANDIDATE_PERFORMANCE_TEST|status=%s|checks=%d|failures=%d" % [status, _checks, _failures.size()])
	for failure in _failures:
		push_error("AI_CARD_PLAY_CANDIDATE_PERFORMANCE_TEST: %s" % failure)
	quit(0 if _failures.is_empty() else 1)
