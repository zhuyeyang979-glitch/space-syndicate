extends SceneTree

const SESSION_DRIVER := preload("res://tests/support/production_session_start_driver.gd")
const QA_SAVE_PATH := "user://test_runs/ai_saturated_route_plan_learning_cache_parity.save"
const SESSION_REQUEST_ID := "ai-saturated-route-plan-learning-cache-parity"
const DETERMINISTIC_SEED := 2026072502
const FULL_HAND_CARD_ID := "interaction.starlink_dismantle.rank_1"
const HAND_SIZE := 5
const SATURATED_SAMPLE_COUNT := 47
const PATH_LIMIT_MSEC := 120_000
const TOTAL_LIMIT_MSEC := 120_000

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var total_started_msec := Time.get_ticks_msec()
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
	_expect(
		bool(start.get("started", false)) and app_root != null and coordinator != null and session != null,
		"formal four-player session starts"
	)
	if app_root == null or coordinator == null or session == null:
		await _cleanup(app_root)
		_finish(total_started_msec, {})
		return

	app_root.process_mode = Node.PROCESS_MODE_DISABLED
	var world := coordinator.world_session_state()
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController
	var actor_state_port := coordinator.get_node_or_null("AiActorStatePort") as AiActorStatePort
	var rng := coordinator.get_node_or_null("RunRngService") as RunRngService
	_expect(world != null and ai != null and actor_state_port != null and rng != null, "formal AI runtime dependencies are available")
	if world == null or ai == null or actor_state_port == null or rng == null:
		await _cleanup(app_root)
		_finish(total_started_msec, {})
		return

	rng.set_seed(DETERMINISTIC_SEED)
	var actor_index := _first_legal_ai_actor(world)
	_expect(actor_index >= 0, "one legal AI actor is selected for the focused measurement")
	if actor_index < 0:
		await _cleanup(app_root)
		_finish(total_started_msec, {})
		return

	session.pause_session()
	var hand_ready: bool = _replace_actor_hand(coordinator, world, actor_index)
	_expect(hand_ready, "formal full-hand fixture exposes fallback buy candidates")
	session.resume_session()
	if not hand_ready:
		await _cleanup(app_root)
		_finish(total_started_msec, {})
		return

	var saturated: bool = _warm_and_saturate(ai, actor_index)
	_expect(saturated, "AI memory contains 47 decision samples with a current route plan")
	if not saturated:
		await _cleanup(app_root)
		_finish(total_started_msec, {})
		return

	var current_checkpoint := world.capture_runtime_checkpoint()
	var current_rng := rng.capture_plan_checkpoint()
	var route_cycle := int(ai.get("business_cycle_count"))
	var stale_ready: bool = _set_route_plan_cycle(world, actor_index, route_cycle - 1)
	_expect(stale_ready, "test-only fixture makes only the route-plan cycle stale")
	var stale_checkpoint := world.capture_runtime_checkpoint()
	var stale_rng := rng.capture_plan_checkpoint()

	var stale_pair := _run_pair(
		ai,
		actor_state_port,
		rng,
		world,
		actor_index,
		stale_checkpoint,
		stale_rng
	) if stale_ready else {}
	var current_restore: bool = _restore_checkpoint(world, rng, current_checkpoint, current_rng)
	_expect(current_restore, "current-route checkpoint restores before current comparison")
	var current_pair := _run_pair(
		ai,
		actor_state_port,
		rng,
		world,
		actor_index,
		current_checkpoint,
		current_rng
	) if current_restore else {}

	var stale_parity := _pair_parity(stale_pair)
	var current_parity := _pair_parity(current_pair)
	var stale_baseline := stale_pair.get("baseline", {}) as Dictionary
	var stale_optimized := stale_pair.get("optimized", {}) as Dictionary
	var current_baseline := current_pair.get("baseline", {}) as Dictionary
	var current_optimized := current_pair.get("optimized", {}) as Dictionary
	var stale_query_reduction: bool = int(stale_optimized.get("candidate_query_delta", 0)) \
		< int(stale_baseline.get("candidate_query_delta", 0)) \
		and int(stale_baseline.get("candidate_query_delta", 0)) \
			- int(stale_optimized.get("candidate_query_delta", 0)) >= 8
	var current_query_reduction: bool = int(current_optimized.get("candidate_query_delta", 0)) \
		< int(current_baseline.get("candidate_query_delta", 0))
	var stale_commit_once: bool = int(stale_baseline.get("commit_delta", -1)) == 1 \
		and int(stale_optimized.get("commit_delta", -1)) == 1
	var current_zero_commit: bool = int(current_baseline.get("commit_delta", -1)) == 0 \
		and int(current_optimized.get("commit_delta", -1)) == 0
	var path_limits_met: bool = _path_within_limit(stale_baseline) \
		and _path_within_limit(stale_optimized) \
		and _path_within_limit(current_baseline) \
		and _path_within_limit(current_optimized)
	var total_elapsed_msec := Time.get_ticks_msec() - total_started_msec
	var total_limit_met: bool = total_elapsed_msec < TOTAL_LIMIT_MSEC
	var gate_passed: bool = bool(stale_parity.get("all", false)) \
		and bool(current_parity.get("all", false)) \
		and stale_query_reduction \
		and current_query_reduction \
		and stale_commit_once \
		and current_zero_commit \
		and path_limits_met \
		and total_limit_met

	print("SATURATED_AI_CARD_FRAME_GATE|status=%s|sample_count=%d|hotspot=route_plan_learning_memory|stale_baseline_msec=%d|stale_optimized_msec=%d|stale_baseline_queries=%d|stale_optimized_queries=%d|current_baseline_msec=%d|current_optimized_msec=%d|current_baseline_queries=%d|current_optimized_queries=%d|candidate_parity=%s|original_order_parity=%s|ranked_order_parity=%s|selection_parity=%s|full_memory_parity=%s|commit_parity=%s|rng_parity=%s|stale_commit_once=%s|current_zero_commit=%s|total_msec=%d" % [
		"PASS" if gate_passed else "FAIL",
		SATURATED_SAMPLE_COUNT,
		int(stale_baseline.get("elapsed_msec", -1)),
		int(stale_optimized.get("elapsed_msec", -1)),
		int(stale_baseline.get("candidate_query_delta", -1)),
		int(stale_optimized.get("candidate_query_delta", -1)),
		int(current_baseline.get("elapsed_msec", -1)),
		int(current_optimized.get("elapsed_msec", -1)),
		int(current_baseline.get("candidate_query_delta", -1)),
		int(current_optimized.get("candidate_query_delta", -1)),
		str(bool(stale_parity.get("candidate", false)) and bool(current_parity.get("candidate", false))),
		str(bool(stale_parity.get("original_order", false)) and bool(current_parity.get("original_order", false))),
		str(bool(stale_parity.get("ranked_order", false)) and bool(current_parity.get("ranked_order", false))),
		str(bool(stale_parity.get("selection", false)) and bool(current_parity.get("selection", false))),
		str(bool(stale_parity.get("memory", false)) and bool(current_parity.get("memory", false))),
		str(bool(stale_parity.get("commit", false)) and bool(current_parity.get("commit", false))),
		str(bool(stale_parity.get("rng", false)) and bool(current_parity.get("rng", false))),
		str(stale_commit_once),
		str(current_zero_commit),
		total_elapsed_msec,
	])
	_expect(bool(stale_parity.get("all", false)), "stale route preserves full candidates, ordering, selection, memory, commits, and RNG")
	_expect(bool(current_parity.get("all", false)), "current route preserves full candidates, ordering, selection, memory, commits, and RNG")
	_expect(stale_query_reduction, "stale optimized route removes at least eight actor-state snapshot queries")
	_expect(current_query_reduction, "current optimized route removes the redundant actor-state snapshot query")
	_expect(stale_commit_once, "stale route commits exactly once in both paths")
	_expect(current_zero_commit, "current route commits zero times in both paths")
	_expect(path_limits_met, "every candidate path completes below 120 seconds")
	_expect(total_limit_met, "complete saturated test finishes below 120 seconds")

	await _cleanup(app_root)
	_finish(total_started_msec, {
		"gate_passed": gate_passed,
		"stale_pair": stale_pair,
		"current_pair": current_pair,
	})


func _run_pair(
	ai: AiRuntimeController,
	actor_state_port: AiActorStatePort,
	rng: RunRngService,
	world: WorldSessionState,
	actor_index: int,
	world_checkpoint: Dictionary,
	rng_checkpoint: Dictionary
) -> Dictionary:
	var baseline_restore: bool = _restore_checkpoint(world, rng, world_checkpoint, rng_checkpoint)
	var baseline := _measure_buy_path(ai, actor_state_port, rng, actor_index, false) if baseline_restore else {}
	var optimized_restore: bool = _restore_checkpoint(world, rng, world_checkpoint, rng_checkpoint)
	var optimized := _measure_buy_path(ai, actor_state_port, rng, actor_index, true) if optimized_restore else {}
	var final_restore: bool = _restore_checkpoint(world, rng, world_checkpoint, rng_checkpoint)
	_expect(baseline_restore and optimized_restore and final_restore, "world and RNG restore around each one-shot buy path")
	return {
		"baseline": baseline,
		"optimized": optimized,
	}


func _measure_buy_path(
	ai: AiRuntimeController,
	actor_state_port: AiActorStatePort,
	rng: RunRngService,
	actor_index: int,
	optimized: bool
) -> Dictionary:
	var supplied_context: Dictionary = ai.call("_ai_card_turn_scoring_context", actor_index) as Dictionary \
		if optimized else {}
	var state_before := actor_state_port.debug_snapshot()
	var rng_before := rng.capture_plan_checkpoint()
	var started_msec := Time.get_ticks_msec()
	var candidates := ai.call("_ai_card_buy_candidates", actor_index, supplied_context) as Array
	var candidate_elapsed_msec := Time.get_ticks_msec() - started_msec
	var state_after_candidates := actor_state_port.debug_snapshot()
	var projection := _canonicalize(candidates) as Array
	var original_order := _candidate_order(projection)
	var ranked := ai.rank_candidates(actor_index, candidates, {"source_context": "saturated_route_plan_cache_parity"})
	var ranked_order := _candidate_order(_canonicalize(ranked) as Array)
	var selection := ai.call("_ai_pick_candidate", actor_index, candidates, false) as Dictionary
	var memory := ai.call("_ai_memory_for_player", actor_index) as Dictionary
	var rng_terminal := rng.capture_plan_checkpoint()
	var state_after := actor_state_port.debug_snapshot()
	return {
		"mode": "optimized" if optimized else "baseline",
		"elapsed_msec": Time.get_ticks_msec() - started_msec,
		"candidate_elapsed_msec": candidate_elapsed_msec,
		"candidate_query_delta": int(state_after_candidates.get("ai_state_query_count", 0))
			- int(state_before.get("ai_state_query_count", 0)),
		"total_query_delta": int(state_after.get("ai_state_query_count", 0))
			- int(state_before.get("ai_state_query_count", 0)),
		"commit_delta": int(state_after.get("state_commit_count", 0))
			- int(state_before.get("state_commit_count", 0)),
		"candidate_count": candidates.size(),
		"projection": projection,
		"original_order": original_order,
		"ranked_order": ranked_order,
		"selection": _canonicalize(selection),
		"memory": _canonicalize(memory),
		"rng_before": rng_before,
		"rng_terminal": rng_terminal,
	}


func _pair_parity(pair: Dictionary) -> Dictionary:
	var baseline := pair.get("baseline", {}) as Dictionary
	var optimized := pair.get("optimized", {}) as Dictionary
	var candidate_parity: bool = not baseline.is_empty() \
		and baseline.get("projection", []) == optimized.get("projection", [])
	var original_order_parity: bool = baseline.get("original_order", []) == optimized.get("original_order", [])
	var ranked_order_parity: bool = baseline.get("ranked_order", []) == optimized.get("ranked_order", [])
	var selection_parity: bool = baseline.get("selection", {}) == optimized.get("selection", {})
	var memory_parity: bool = baseline.get("memory", {}) == optimized.get("memory", {})
	var commit_parity: bool = int(baseline.get("commit_delta", -1)) == int(optimized.get("commit_delta", -2))
	var rng_parity: bool = baseline.get("rng_before", {}) == optimized.get("rng_before", {}) \
		and baseline.get("rng_terminal", {}) == optimized.get("rng_terminal", {})
	return {
		"all": candidate_parity and original_order_parity and ranked_order_parity \
			and selection_parity and memory_parity and commit_parity and rng_parity,
		"candidate": candidate_parity,
		"original_order": original_order_parity,
		"ranked_order": ranked_order_parity,
		"selection": selection_parity,
		"memory": memory_parity,
		"commit": commit_parity,
		"rng": rng_parity,
	}


func _warm_and_saturate(ai: AiRuntimeController, actor_index: int) -> bool:
	var warm_context := ai.call("_ai_card_turn_scoring_context", actor_index) as Dictionary
	var warm_candidates := ai.call("_ai_card_buy_candidates", actor_index, warm_context) as Array
	if warm_candidates.is_empty():
		return false
	var actor_state := ai.call("_ai_actor_state_snapshot", actor_index) as Dictionary
	if actor_state.is_empty():
		return false
	var memory: Dictionary = (actor_state.get("ai_memory", {}) as Dictionary).duplicate(true)
	var samples: Array = []
	for sample_index in range(SATURATED_SAMPLE_COUNT):
		samples.append({
			"time": float(sample_index),
			"cycle": sample_index,
			"kind": "buy",
			"target": sample_index % 4,
			"score": 1000 + sample_index,
			"reason": "saturated-route-plan-cache-parity",
			"state": {
				"cash": 1000 + sample_index,
				"active_city_count": 2,
				"total_product_flow": 12,
				"game_phase": "midgame",
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
	return (stored_memory.get("decision_samples", []) as Array).size() == SATURATED_SAMPLE_COUNT \
		and int(stored_memory.get("route_plan_cycle", -1)) == int(ai.get("business_cycle_count"))


func _set_route_plan_cycle(world: WorldSessionState, actor_index: int, route_cycle: int) -> bool:
	if actor_index < 0 or actor_index >= world.players.size() or not (world.players[actor_index] is Dictionary):
		return false
	var players := world.players.duplicate(true)
	var player := (players[actor_index] as Dictionary).duplicate(true)
	var memory: Dictionary = (player.get("ai_memory", {}) as Dictionary).duplicate(true)
	memory["route_plan_cycle"] = route_cycle
	player["ai_memory"] = memory
	players[actor_index] = player
	world.players = players
	return true


func _restore_checkpoint(
	world: WorldSessionState,
	rng: RunRngService,
	world_checkpoint: Dictionary,
	rng_checkpoint: Dictionary
) -> bool:
	var world_receipt := world.restore_runtime_checkpoint(world_checkpoint)
	var rng_receipt := rng.restore_plan_checkpoint(rng_checkpoint)
	return bool(world_receipt.get("applied", false)) and bool(rng_receipt.get("restored", false))


func _replace_actor_hand(
	coordinator: GameRuntimeCoordinator,
	world: WorldSessionState,
	actor_index: int
) -> bool:
	var definition := coordinator.v06_card_definition(FULL_HAND_CARD_ID)
	if definition.is_empty() or actor_index < 0 or actor_index >= world.players.size():
		return false
	var slots: Array = []
	for slot_index in range(HAND_SIZE):
		var card := definition.duplicate(true)
		card["runtime_instance_id"] = "saturated-route-plan:%d:%d" % [actor_index, slot_index]
		card["queued_for_resolution"] = false
		card["cooldown_left"] = 0.0
		card["lock_left"] = 0.0
		card["play_requirement_kind"] = "region_gdp_share"
		card["play_region_scope"] = "own_best_region"
		card["play_region_gdp_share_required"] = 100
		slots.append(card)
	var players := world.players.duplicate(true)
	var player := (players[actor_index] as Dictionary).duplicate(true)
	player["slots"] = slots
	player["cash"] = maxi(1000, int(player.get("cash", 0)))
	player["cash_cents"] = maxi(100000, int(player.get("cash_cents", 0)))
	player["action_cooldown"] = 0.0
	players[actor_index] = player
	world.players = players
	var actor_mapping := coordinator.actor_id_for_player_index(actor_index)
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
			"district": int(candidate.get("district", -1)),
			"product": str(candidate.get("product", "")),
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


func _path_within_limit(path: Dictionary) -> bool:
	return not path.is_empty() and int(path.get("elapsed_msec", PATH_LIMIT_MSEC)) < PATH_LIMIT_MSEC


func _first_legal_ai_actor(world: WorldSessionState) -> int:
	for player_index in range(world.players.size()):
		var player := world.players[player_index] as Dictionary
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


func _finish(total_started_msec: int, _result: Dictionary) -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("AI_SATURATED_ROUTE_PLAN_LEARNING_CACHE_TEST|status=%s|checks=%d|failures=%d|elapsed_msec=%d" % [
		status,
		_checks,
		_failures.size(),
		Time.get_ticks_msec() - total_started_msec,
	])
	for failure in _failures:
		push_error("AI_SATURATED_ROUTE_PLAN_LEARNING_CACHE_TEST: %s" % failure)
	quit(0 if _failures.is_empty() else 1)
