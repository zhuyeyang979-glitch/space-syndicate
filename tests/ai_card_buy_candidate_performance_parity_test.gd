extends SceneTree

const SESSION_DRIVER := preload("res://tests/support/production_session_start_driver.gd")
const QA_SAVE_PATH := "user://test_runs/ai_card_buy_candidate_performance_parity.save"
const SESSION_REQUEST_ID := "ai-card-buy-candidate-performance-parity"
const DETERMINISTIC_REQUEST_ID := "ai-card-buy-candidate-performance-parity-deterministic"
const DETERMINISTIC_SESSION_SEED := 2026072501
const PRODUCT_LIMIT_MSEC := 30_000

const REQUIRED_PROJECTION_FIELDS := [
	"action",
	"card_name",
	"kind",
	"policy_kind",
	"district",
	"product",
	"price",
	"score",
	"focus_product",
	"focus_score",
	"focus_bonus",
	"strategy_intent",
	"strategy_score",
	"strategy_bonus",
	"route_plan_product",
	"route_plan_stage",
	"route_plan_score",
	"route_plan_bonus",
	"route_gap_bonus",
	"route_gap_penalty",
	"route_gap_reason",
	"route_gap_field_match",
	"development_route",
	"development_route_bias",
	"development_route_bonus",
	"route_inventory_bonus",
	"route_inventory_penalty",
	"route_hand_total",
	"route_hand_playable",
	"route_hand_blocked",
	"playability_bonus",
	"play_requirement_kind",
	"play_requirement_scope",
	"required_share_percent",
	"current_share_percent",
	"qualifying_district",
	"requirement_satisfied",
	"requires_discard",
	"discard_slot",
	"discard_keep_value",
	"hand_pressure_penalty",
]

# Frozen from unchanged production in run
# 20260724-234853-418-ai_card_buy_candidate_performance_parity_test-66640030.
const GOLDEN_LOCKED := true
const GOLDEN_CANDIDATE_COUNT := 16
const GOLDEN_PROJECTION_SHA256 := "4a1081e225ee9f164ccbdb9b61403d1dc00effdcb6edf639f3b3c669579ce5fa"
const GOLDEN_ORIGINAL_ORDER_SHA256 := "e2c5a4a1b7b95863a39c942e6f89d669f53ee3705972e359edb40082e7460975"
const GOLDEN_RANKED_ORDER_SHA256 := "814fed244e1efba5d17b5b1d03d6e35203f68bfcbff54f5003b6462fdf091d15"
const GOLDEN_FORCE_SELECTION_SHA256 := "bca23143165fbe984d62294f0bf612c0deb8339e951160daadb142d95b3f8443"
const GOLDEN_NORMAL_SELECTION_SHA256 := "bca23143165fbe984d62294f0bf612c0deb8339e951160daadb142d95b3f8443"
const GOLDEN_FORCE_SELECTION := {
	"action": "购牌",
	"card_name": "interaction.starlink_dismantle.rank_1",
	"district": 1,
	"kind": "",
	"policy_kind": "",
	"price": 5,
	"product": "星露莓",
	"score": 139,
}
const GOLDEN_NORMAL_SELECTION := {
	"action": "购牌",
	"card_name": "interaction.starlink_dismantle.rank_1",
	"district": 1,
	"kind": "",
	"policy_kind": "",
	"price": 5,
	"product": "星露莓",
	"score": 139,
}
const GOLDEN_NORMAL_TERMINAL := {
	"schema_version": 1,
	"rng_state": -6040541359276059718,
	"draw_count": 240,
}
const GOLDEN_STATE_COMMIT_COUNT_DELTA := 4
const GOLDEN_PRIVATE_AI_QUERY_COUNT_DELTA := 12
const AI_STATE_QUERY_COUNT_UPPER_BOUND := 320
const DISCARD_PRESSURE_GRANT_CARD_ID := "interaction.starlink_dismantle.rank_1"
const DISCARD_PRESSURE_LIMIT_MSEC := 60_000
const DISCARD_PRESSURE_GOLDEN_LOCKED := true
const DISCARD_PRESSURE_GOLDEN_CANDIDATE_COUNT := 16
const DISCARD_PRESSURE_GOLDEN_DISCARD_CANDIDATE_COUNT := 14
const DISCARD_PRESSURE_GOLDEN_PROJECTION_SHA256 := "06454d9b06dda5850ef497f918153f23f3569f2fe62659c920d27c3e46dc9118"
const DISCARD_PRESSURE_GOLDEN_AI_STATE_QUERY_COUNT_DELTA := 109
const DISCARD_PRESSURE_GOLDEN_STATE_COMMIT_COUNT_DELTA := 0
const DISCARD_PRESSURE_GOLDEN_PRIVATE_AI_QUERY_COUNT_DELTA := 12

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
		"formal four-player session starts through ProductionSessionStartDriver: %s"
			% str(start.get("reason_code", "missing"))
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

	# Main randomizes the production RNG before the Driver can configure the draft.
	# Replacing the just-started session through the same formal transaction gives
	# this performance oracle one stable world without introducing a fixture owner.
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
	_expect(bool(cursor_reset.get("restored", false)), "focused setup resets the existing RunRngService to a stable checkpoint")
	_expect(
		deterministic_receipt != null and deterministic_receipt.applied,
		"deterministic replacement commits through SessionStartTransaction: %s"
			% (deterministic_receipt.reason_code if deterministic_receipt != null else "missing_receipt")
	)
	if deterministic_receipt == null or not deterministic_receipt.applied:
		await _cleanup(app_root)
		_finish()
		return

	session.pause_session()
	var world := coordinator.world_session_state()
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController
	var actor_state_port := coordinator.get_node_or_null("AiActorStatePort") as AiActorStatePort
	var district_supply_query := coordinator.get_node_or_null("DistrictSupplyRuntimeQueryPort") as DistrictSupplyRuntimeQueryPort
	_expect(session.session_state() == GameSessionRuntimeController.STATE_PAUSED, "formal session reaches the paused lifecycle before the focused query")
	_expect(
		world != null and ai != null and actor_state_port != null and district_supply_query != null,
		"production WorldSession, AI controller, actor-state port, and district-supply query are available"
	)
	_expect(
		world != null
			and world.players.size() == 4
			and not bool((world.players[0] as Dictionary).get("is_ai", true))
			and bool((world.players[1] as Dictionary).get("is_ai", false))
			and bool((world.players[2] as Dictionary).get("is_ai", false))
			and bool((world.players[3] as Dictionary).get("is_ai", false)),
		"formal roster contains one human and three legal AI seats"
	)
	if world == null or ai == null or actor_state_port == null or district_supply_query == null:
		await _cleanup(app_root)
		_finish()
		return
	# The typed actor economy and hand ports correctly authorize only a running
	# GameSession. Runtime processing remains disabled on app_root, so resuming the
	# lifecycle enables the real query without advancing a production frame.
	session.resume_session()
	_expect(
		session.session_state() == GameSessionRuntimeController.STATE_RUNNING
			and app_root.process_mode == Node.PROCESS_MODE_DISABLED,
		"typed-query authorization is running while automatic RuntimeLoop processing stays frozen"
	)

	var actor_index := _first_legal_ai_actor(world)
	_expect(actor_index >= 1, "focused query selects one non-eliminated AI actor")
	if actor_index < 1:
		await _cleanup(app_root)
		_finish()
		return

	var rng_before_generation := rng.capture_plan_checkpoint()
	var actor_state_debug_before := actor_state_port.debug_snapshot()
	var district_supply_debug_before := district_supply_query.debug_snapshot()
	print("AI_CARD_BUY_CANDIDATE_PERFORMANCE|CALL_STARTED")
	var call_started_msec := Time.get_ticks_msec()
	var candidates := ai.call("_ai_card_buy_candidates", actor_index) as Array
	var call_elapsed_msec := Time.get_ticks_msec() - call_started_msec
	var actor_state_debug_after := actor_state_port.debug_snapshot()
	var district_supply_debug_after := district_supply_query.debug_snapshot()
	var ai_state_query_count_delta := int(actor_state_debug_after.get("ai_state_query_count", 0)) - int(actor_state_debug_before.get("ai_state_query_count", 0))
	var state_commit_count_delta := int(actor_state_debug_after.get("state_commit_count", 0)) - int(actor_state_debug_before.get("state_commit_count", 0))
	var private_ai_query_count_delta := int(district_supply_debug_after.get("private_ai_query_count", 0)) - int(district_supply_debug_before.get("private_ai_query_count", 0))
	print(
		"AI_CARD_BUY_CANDIDATE_PERFORMANCE|CALL_COMPLETED|elapsed_msec=%d|candidate_count=%d"
			% [call_elapsed_msec, candidates.size()]
	)
	print(
		"AI_CARD_BUY_CANDIDATE_PERFORMANCE|QUERY_COUNTERS|ai_state_query_count_delta=%d|state_commit_count_delta=%d|private_ai_query_count_delta=%d"
			% [ai_state_query_count_delta, state_commit_count_delta, private_ai_query_count_delta]
	)
	var rng_after_generation := rng.capture_plan_checkpoint()
	_expect(call_elapsed_msec < PRODUCT_LIMIT_MSEC, "candidate generation stays below the 30000 ms product limit: %d ms" % call_elapsed_msec)
	_expect(not candidates.is_empty(), "formal AI actor exposes at least one legal card-buy candidate")
	_expect(rng_after_generation == rng_before_generation, "candidate generation consumes zero RunRngService draws")
	_expect(
		state_commit_count_delta == GOLDEN_STATE_COMMIT_COUNT_DELTA,
		"candidate generation preserves the frozen actor-state commit delta: %d" % state_commit_count_delta
	)
	_expect(
		ai_state_query_count_delta <= AI_STATE_QUERY_COUNT_UPPER_BOUND,
		"candidate generation stays below the actor-state query regression ceiling: %d" % ai_state_query_count_delta
	)
	_expect(
		private_ai_query_count_delta == GOLDEN_PRIVATE_AI_QUERY_COUNT_DELTA,
		"candidate generation preserves the frozen private inventory query delta: %d" % private_ai_query_count_delta
	)

	var projection := _candidate_projection(candidates)
	var projection_json := JSON.stringify(projection)
	var projection_sha256 := projection_json.sha256_text()
	var missing_projection_fields := _missing_projection_fields(projection)
	_expect(missing_projection_fields.is_empty(), "complete stable projection includes all ordering inputs: %s" % JSON.stringify(missing_projection_fields))
	_expect(TablePresentationPureDataPolicy.is_pure_data(projection), "candidate projection is detached pure data")
	var final_memory_variant: Variant = ai.call("_ai_memory_for_player", actor_index)
	var detached_final_memory := (final_memory_variant as Dictionary).duplicate(true) \
		if final_memory_variant is Dictionary else {}
	var compact_final_memory := _compact_final_memory_projection(detached_final_memory)
	var reference_candidate := projection[0] as Dictionary \
		if not projection.is_empty() and projection[0] is Dictionary else {}
	var expected_final_memory := _candidate_memory_context_projection(reference_candidate)
	_expect(not detached_final_memory.is_empty(), "formal AI actor exposes final detached decision memory")
	_expect(TablePresentationPureDataPolicy.is_pure_data(compact_final_memory), "compact final-memory projection is detached pure data")
	_expect(
		compact_final_memory == expected_final_memory,
		"final focus, phase, strategy, and route memory matches the frozen candidate context"
	)
	var final_memory_sha256 := JSON.stringify(compact_final_memory).sha256_text()

	var original_order := _candidate_order(projection)
	var original_order_json := JSON.stringify(original_order)
	var ranked := ai.rank_candidates(actor_index, candidates, {"source_context": "focused_performance_parity"})
	var ranked_projection := _candidate_projection(ranked)
	var ranked_order := _candidate_order(ranked_projection)
	var ranked_order_json := JSON.stringify(ranked_order)

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
	_expect(bool(restored.get("restored", false)), "normal selection checkpoint restores through RunRngService")
	_expect(
		_candidate_projection_row(normal_selection_first) == _candidate_projection_row(normal_selection_replay),
		"normal selection chooses the same candidate from the same RNG checkpoint"
	)
	_expect(
		normal_terminal_first == normal_terminal_replay,
		"normal selection reaches the same terminal draw_count and RNG state"
	)

	var forced_json := JSON.stringify(_candidate_projection_row(forced_selection))
	var normal_json := JSON.stringify(_candidate_projection_row(normal_selection_first))
	var safe_summary := {
		"elapsed_msec": call_elapsed_msec,
		"ai_state_query_count_delta": ai_state_query_count_delta,
		"state_commit_count_delta": state_commit_count_delta,
		"private_ai_query_count_delta": private_ai_query_count_delta,
		"candidate_count": candidates.size(),
		"projection_sha256": projection_sha256,
		"original_order_sha256": original_order_json.sha256_text(),
		"ranked_order_sha256": ranked_order_json.sha256_text(),
		"force_selection_sha256": forced_json.sha256_text(),
		"normal_selection_sha256": normal_json.sha256_text(),
		"normal_terminal_sha256": JSON.stringify(normal_terminal_first).sha256_text(),
		"final_memory_sha256": final_memory_sha256,
	}
	print("AI_CARD_BUY_CANDIDATE_PERFORMANCE|SAFE_SUMMARY|%s" % JSON.stringify(safe_summary))

	if GOLDEN_LOCKED:
		_expect(candidates.size() == GOLDEN_CANDIDATE_COUNT, "candidate count matches the frozen baseline")
		_expect(projection_sha256 == GOLDEN_PROJECTION_SHA256, "complete candidate projection matches the frozen baseline")
		_expect(original_order_json.sha256_text() == GOLDEN_ORIGINAL_ORDER_SHA256, "original candidate order matches the frozen baseline")
		_expect(ranked_order_json.sha256_text() == GOLDEN_RANKED_ORDER_SHA256, "rank_candidates order matches the frozen baseline")
		_expect(forced_json.sha256_text() == GOLDEN_FORCE_SELECTION_SHA256, "force=true selection matches the frozen baseline")
		_expect(normal_json.sha256_text() == GOLDEN_NORMAL_SELECTION_SHA256, "normal selection matches the frozen baseline")
		_expect(_selection_identity(forced_selection) == GOLDEN_FORCE_SELECTION, "force=true selected action matches the explicit golden")
		_expect(_selection_identity(normal_selection_first) == GOLDEN_NORMAL_SELECTION, "normal selected action matches the explicit golden")
		_expect(normal_terminal_first == GOLDEN_NORMAL_TERMINAL, "normal selection reaches the frozen terminal RNG cursor")

	var discard_pressure_fixture := _prepare_discard_pressure_fixture(coordinator, actor_index)
	_expect(bool(discard_pressure_fixture.get("prepared", false)), "formal inventory owner prepares one full-hand discard-pressure fixture")
	if bool(discard_pressure_fixture.get("prepared", false)):
		var pressure_rng_before := rng.capture_plan_checkpoint()
		var pressure_actor_state_before := actor_state_port.debug_snapshot()
		var pressure_supply_before := district_supply_query.debug_snapshot()
		print("AI_CARD_BUY_DISCARD_PRESSURE|CALL_STARTED")
		var pressure_started_msec := Time.get_ticks_msec()
		var pressure_candidates := ai.call("_ai_card_buy_candidates", actor_index) as Array
		var pressure_elapsed_msec := Time.get_ticks_msec() - pressure_started_msec
		var pressure_actor_state_after := actor_state_port.debug_snapshot()
		var pressure_supply_after := district_supply_query.debug_snapshot()
		var pressure_ai_query_delta := int(pressure_actor_state_after.get("ai_state_query_count", 0)) - int(pressure_actor_state_before.get("ai_state_query_count", 0))
		var pressure_commit_delta := int(pressure_actor_state_after.get("state_commit_count", 0)) - int(pressure_actor_state_before.get("state_commit_count", 0))
		var pressure_private_query_delta := int(pressure_supply_after.get("private_ai_query_count", 0)) - int(pressure_supply_before.get("private_ai_query_count", 0))
		var pressure_rng_after := rng.capture_plan_checkpoint()
		var pressure_projection := _candidate_projection(pressure_candidates)
		var pressure_projection_sha256 := JSON.stringify(pressure_projection).sha256_text()
		var discard_candidate_count := _discard_candidate_count(pressure_projection)
		var discard_plan_variant_count := _discard_plan_variant_count(pressure_projection)
		print(
			"AI_CARD_BUY_DISCARD_PRESSURE|CALL_COMPLETED|elapsed_msec=%d|candidate_count=%d|discard_candidate_count=%d"
				% [pressure_elapsed_msec, pressure_candidates.size(), discard_candidate_count]
		)
		print(
			"AI_CARD_BUY_DISCARD_PRESSURE|QUERY_COUNTERS|ai_state_query_count_delta=%d|state_commit_count_delta=%d|private_ai_query_count_delta=%d"
				% [pressure_ai_query_delta, pressure_commit_delta, pressure_private_query_delta]
		)
		print("AI_CARD_BUY_DISCARD_PRESSURE|SAFE_SUMMARY|%s" % JSON.stringify({
			"elapsed_msec": pressure_elapsed_msec,
			"candidate_count": pressure_candidates.size(),
			"discard_candidate_count": discard_candidate_count,
			"discard_plan_variant_count": discard_plan_variant_count,
			"ai_state_query_count_delta": pressure_ai_query_delta,
			"state_commit_count_delta": pressure_commit_delta,
			"private_ai_query_count_delta": pressure_private_query_delta,
			"projection_sha256": pressure_projection_sha256,
		}))
		_expect(pressure_elapsed_msec < DISCARD_PRESSURE_LIMIT_MSEC, "discard-pressure candidate generation stays below the focused limit")
		_expect(pressure_rng_after == pressure_rng_before, "discard-pressure candidate generation consumes zero RunRngService draws")
		_expect(discard_candidate_count > 1, "full-hand fixture reaches repeated requires-discard candidates")
		_expect(discard_plan_variant_count == 1, "all requires-discard candidates preserve one discard slot and keep value")
		_expect(TablePresentationPureDataPolicy.is_pure_data(pressure_projection), "discard-pressure projection is detached pure data")
		if DISCARD_PRESSURE_GOLDEN_LOCKED:
			_expect(pressure_candidates.size() == DISCARD_PRESSURE_GOLDEN_CANDIDATE_COUNT, "discard-pressure candidate count matches the frozen baseline")
			_expect(discard_candidate_count == DISCARD_PRESSURE_GOLDEN_DISCARD_CANDIDATE_COUNT, "discard-pressure candidate subset matches the frozen baseline")
			_expect(pressure_projection_sha256 == DISCARD_PRESSURE_GOLDEN_PROJECTION_SHA256, "discard-pressure projection matches the frozen baseline")
			_expect(pressure_ai_query_delta == DISCARD_PRESSURE_GOLDEN_AI_STATE_QUERY_COUNT_DELTA, "discard-pressure actor-state query count matches the frozen baseline")
			_expect(pressure_commit_delta == DISCARD_PRESSURE_GOLDEN_STATE_COMMIT_COUNT_DELTA, "discard-pressure actor-state commit count matches the frozen baseline")
			_expect(pressure_private_query_delta == DISCARD_PRESSURE_GOLDEN_PRIVATE_AI_QUERY_COUNT_DELTA, "discard-pressure private inventory query count matches the frozen baseline")

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
		if candidate_variant is Dictionary:
			result.append(_selection_identity(candidate_variant as Dictionary))
	return result


func _selection_identity(candidate: Dictionary) -> Dictionary:
	return {
		"action": str(candidate.get("action", "")),
		"card_name": str(candidate.get("card_name", "")),
		"kind": str(candidate.get("kind", "")),
		"policy_kind": str(candidate.get("policy_kind", "")),
		"district": int(candidate.get("district", -1)),
		"product": str(candidate.get("product", "")),
		"price": int(candidate.get("price", -1)),
		"score": int(candidate.get("score", 0)),
	}


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


func _prepare_discard_pressure_fixture(coordinator: GameRuntimeCoordinator, player_index: int) -> Dictionary:
	var inventory := coordinator.get_node_or_null("CommodityCardInventoryRuntimeController") as CommodityCardInventoryRuntimeController
	var actor_mapping := coordinator.actor_id_for_player_index(player_index)
	var actor_id := str(actor_mapping.get("actor_id", ""))
	if inventory == null or not bool(actor_mapping.get("available", false)) or actor_id.is_empty():
		return {"prepared": false}
	var grant_count := 0
	for grant_index in range(8):
		var player := inventory.player_snapshot(actor_id)
		var inventory_state: Dictionary = player.get("inventory", {}) if player.get("inventory", {}) is Dictionary else {}
		var hand_limit := int(inventory_state.get("hand_limit", 5))
		if _counted_inventory_size(inventory_state) >= hand_limit:
			return {"prepared": true, "grant_count": grant_count}
		var grant := inventory.grant_card(
			actor_id,
			DISCARD_PRESSURE_GRANT_CARD_ID,
			int(player.get("revision", -1)),
			"ai-card-buy-discard-pressure-grant-%d" % grant_index,
			"focused_discard_pressure"
		)
		if not bool(grant.get("committed", false)):
			return {"prepared": false, "grant_count": grant_count}
		grant_count += 1
	return {"prepared": false, "grant_count": grant_count}


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


func _discard_candidate_count(projection: Array) -> int:
	var count := 0
	for candidate_variant in projection:
		if candidate_variant is Dictionary and bool((candidate_variant as Dictionary).get("requires_discard", false)):
			count += 1
	return count


func _discard_plan_variant_count(projection: Array) -> int:
	var variants := {}
	for candidate_variant in projection:
		if not (candidate_variant is Dictionary):
			continue
		var candidate := candidate_variant as Dictionary
		if not bool(candidate.get("requires_discard", false)):
			continue
		variants["%d|%d" % [int(candidate.get("discard_slot", -1)), int(candidate.get("discard_keep_value", 0))]] = true
	return variants.size()


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
	print("AI_CARD_BUY_CANDIDATE_PERFORMANCE_TEST|status=%s|checks=%d|failures=%d" % [status, _checks, _failures.size()])
	for failure in _failures:
		push_error("AI_CARD_BUY_CANDIDATE_PERFORMANCE_TEST: %s" % failure)
	quit(0 if _failures.is_empty() else 1)
