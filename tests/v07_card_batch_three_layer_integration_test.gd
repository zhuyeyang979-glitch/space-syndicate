extends SceneTree

const RUNTIME = preload("res://scripts/runtime/card_batch_reference_runtime.gd")
const SOURCE_OWNER = preload("res://scripts/runtime/ai_card_batch_observation_source_owner.gd")
const PLANNER = preload("res://scripts/ai/ai_card_batch_planner_v1.gd")
const OBSERVATION = preload("res://scripts/semantic/ai_card_batch_observation_v1.gd")
const SUBMISSION = preload("res://scripts/semantic/card_batch_submission_v1.gd")
const INVENTORY = preload("res://scripts/semantic/card_batch_inventory_state_v1.gd")
const TARGET = preload("res://scripts/semantic/card_batch_prebound_target_spec_v1.gd")
const AUTHORED_RULE = preload("res://scripts/semantic/card_batch_authored_rule_v1.gd")
const VIEWER_AUTHORIZATION = preload("res://scripts/semantic/card_batch_viewer_authorization_v1.gd")
const PURE = preload("res://scripts/semantic/card_batch_pure_data.gd")
const SURFACE_SCENE := preload("res://scenes/ui/v07/V07ContextualTableSurface.tscn")

const HUMAN_ACTOR_ID := "human.player.0"
const AI_ACTOR_ID := "ai.player.1"
const RIVAL_ACTOR_ID := "observer.player.2"
const PUBLIC_TARGET_ID := "region.public.gamma"
const RIVAL_PRIVATE_CARD_ID := "private.rival.card.never-project"
const PRODUCTION_COMPOSITION_PATHS: Array[String] = [
	"res://scripts/main.gd",
	"res://scenes/main.tscn",
	"res://scripts/runtime/game_runtime_coordinator.gd",
	"res://scenes/runtime/GameRuntimeCoordinator.tscn",
	"res://scripts/ui/game_screen.gd",
	"res://scenes/ui/GameScreen.tscn",
]
const REFERENCE_ONLY_TOKENS: Array[String] = [
	"CardBatchReferenceRuntime",
	"AiCardBatchObservationSourceOwner",
	"V07ContextualTableSurface",
	"card_batch_reference_runtime.gd",
	"ai_card_batch_observation_source_owner.gd",
	"V07ContextualTableSurface.tscn",
]
const FORBIDDEN_PROJECTION_TOKENS: Array[String] = [
	"counter_window",
	"counter_stack",
	"pending_counter",
	"hidden_owner",
	"future_resolution_order",
	"other_player_inventory",
	"rival_inventory",
	RIVAL_PRIVATE_CARD_ID,
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var runtime := RUNTIME.new() as CardBatchReferenceRuntime
	var surface := SURFACE_SCENE.instantiate() as V07ContextualTableSurface
	root.add_child(runtime)
	root.add_child(surface)
	await process_frame
	await process_frame

	var actor_ids: Array[String] = [HUMAN_ACTOR_ID, AI_ACTOR_ID, RIVAL_ACTOR_ID]
	var inventories := _inventories()
	_expect(
		bool(runtime.begin_initial_window(actor_ids, inventories).get("accepted", false)),
		"one reference Core state owns the shared three-seat card window"
	)

	var ai_viewer_authorization := VIEWER_AUTHORIZATION.new(1) as CardBatchViewerAuthorizationV1
	var human_viewer_authorization := VIEWER_AUTHORIZATION.new(1) as CardBatchViewerAuthorizationV1
	_expect(runtime.bind_viewer_authorization(AI_ACTOR_ID, ai_viewer_authorization), "Core binds the AI viewer capability")
	_expect(runtime.bind_viewer_authorization(HUMAN_ACTOR_ID, human_viewer_authorization), "Core binds the player viewer capability")

	var planning_state := runtime.state_snapshot()
	var planning_ai_view := runtime.viewer_projection(ai_viewer_authorization)
	var planning_source := _ai_source_from_core(planning_state, planning_ai_view, [_ai_candidate()])
	var planning_observation := _issue_observation(planning_source, AI_ACTOR_ID, 1)
	var planner := PLANNER.new() as AiCardBatchPlannerV1
	var ai_plan := planner.plan_submission_draft(planning_observation)
	var ai_submission: Dictionary = ai_plan.get("submission_draft", {}) \
		if ai_plan.get("submission_draft") is Dictionary else {}
	var human_submission := _human_submission()
	_expect(not planning_observation.is_empty(), "owner-authorized AI observation derives from the Core viewer projection")
	_expect(
		bool(SUBMISSION.validate(ai_submission, false).get("valid", false)) \
			and bool(SUBMISSION.validate(human_submission, false).get("valid", false)),
		"AI and human paths both use CardBatchSubmissionV1"
	)
	_expect(
		(ai_plan.get("gameplay_intents", []) as Array).is_empty(),
		"AI creates no parallel gameplay-intent or resolution-input path"
	)

	var authored_rules := {
		str(human_submission.get("card_semantic_id", "")): AUTHORED_RULE.from_submission(human_submission),
		str(ai_submission.get("card_semantic_id", "")): AUTHORED_RULE.from_submission(ai_submission),
	}
	_expect(
		bool(runtime.configure_authoritative_card_rules(authored_rules).get("accepted", false)),
		"the shared Core binds both submissions to authored rules"
	)
	_expect(
		bool(runtime.submit_or_replace_draft(human_submission).get("accepted", false)) \
			and bool(runtime.submit_or_replace_draft(ai_submission).get("accepted", false)),
		"human and AI drafts enter the same authoritative submission method"
	)

	var shared_open_state := runtime.state_snapshot()
	var shared_open_fingerprint := runtime.state_fingerprint()
	var open_ai_view := runtime.viewer_projection(ai_viewer_authorization)
	var open_player_view := runtime.viewer_projection(human_viewer_authorization)
	var open_ai_source := _ai_source_from_core(shared_open_state, open_ai_view, [_ai_candidate()])
	var open_observation := _issue_observation(open_ai_source, AI_ACTOR_ID, 1)
	var player_projections := _player_open_projections(shared_open_state, open_player_view)
	var player_apply_ok := surface.apply_player_roster(player_projections.get("roster", {})) \
		and surface.apply_card_window(player_projections.get("window", {})) \
		and surface.apply_submission_preview(player_projections.get("submission", {})) \
		and surface.apply_player_card_dock(player_projections.get("dock", {}))
	_expect(player_apply_ok, "typed player targets accept projections derived from the same open Core state")
	_expect(
		_observation_is_legal_subset(open_observation, shared_open_state, open_ai_view),
		"AI observation is an authorized legal subset of the shared open Core state"
	)
	_expect(
		_player_open_projection_is_legal_subset(player_projections, shared_open_state, open_player_view),
		"player window, own draft, and own dock are legal subsets of the shared open Core state"
	)
	_expect(
		runtime.state_fingerprint() == shared_open_fingerprint,
		"AI observation and player projection perform zero authority writes"
	)
	_expect(
		((shared_open_state.get("submissions_by_actor", {}) as Dictionary).size() == 2),
		"the Core contains one draft per submitting actor with no double write"
	)

	var lock_result := runtime.lock_window()
	_expect(
		bool(lock_result.get("accepted", false)) \
			and (lock_result.get("resolution_order", []) as Array).size() == 2,
		"one authoritative order contains both shared submissions"
	)
	var active_submission_id := str(runtime.state_snapshot().get("active_resolution_id", ""))
	var target_projection := {"target_revisions": {PUBLIC_TARGET_ID: 18}, "inactive_target_ids": []}
	var commit := runtime.commit_active_card(target_projection)
	var core_receipt: Dictionary = commit.get("receipt", {}) if commit.get("receipt") is Dictionary else {}
	_expect(bool(commit.get("accepted", false)) and not core_receipt.is_empty(), "Core emits the authoritative first-card receipt")

	var shared_receipt_state := runtime.state_snapshot()
	var shared_receipt_fingerprint := runtime.state_fingerprint()
	var receipt_ai_view := runtime.viewer_projection(ai_viewer_authorization)
	var receipt_player_view := runtime.viewer_projection(human_viewer_authorization)
	var receipt_ai_source := _ai_source_from_core(shared_receipt_state, receipt_ai_view, [])
	var receipt_observation := _issue_observation(receipt_ai_source, AI_ACTOR_ID, 1)
	var player_receipt_projection := _player_receipt_projection(shared_receipt_state, receipt_player_view)
	_expect(
		surface.apply_resolution_overlay(player_receipt_projection),
		"typed player resolution target consumes the same Core receipt projection"
	)
	_expect(
		_receipt_projections_share_core_lineage(core_receipt, receipt_observation, player_receipt_projection),
		"AI and player receipt facts share one authoritative Core lineage"
	)
	_expect(
		_observation_is_legal_subset(receipt_observation, shared_receipt_state, receipt_ai_view),
		"resolution-phase AI observation remains a legal public subset"
	)
	_expect(
		runtime.state_fingerprint() == shared_receipt_fingerprint,
		"receipt observation and presentation perform zero authority writes"
	)
	_expect(
		_no_forbidden_projection_data([open_observation, player_projections, receipt_observation, player_receipt_projection]),
		"all three-layer projections exclude Counter and rival-private data"
	)
	_expect(
		int(surface.debug_snapshot().get("gameplay_action_emission_count", -1)) == 0,
		"typed player surface emits no gameplay action during projection or resolution"
	)

	var receipt_id := str(core_receipt.get("receipt_id", ""))
	_expect(
		active_submission_id == str(core_receipt.get("submission_id", "")) \
			and bool(runtime.complete_card_aftermath(receipt_id).get("accepted", false)),
		"the first receipt advances only through the authoritative aftermath gate"
	)
	var finish := runtime.run_uninterrupted({
		str(ai_submission.get("submission_id", "")): target_projection,
		str(human_submission.get("submission_id", "")): target_projection,
	})
	_expect(
		bool(finish.get("accepted", false)) \
			and str(runtime.state_snapshot().get("phase", "")) == "BATCH_COMPLETE",
		"the remaining batch resolves continuously without player input"
	)
	_expect(_production_composition_is_detached(), "all V0.7 reference classes remain absent from production composition")

	runtime.revoke_viewer_authorization(ai_viewer_authorization)
	runtime.revoke_viewer_authorization(human_viewer_authorization)
	root.remove_child(surface)
	surface.free()
	root.remove_child(runtime)
	runtime.free()
	_finish(shared_receipt_fingerprint)


func _inventories() -> Dictionary:
	var human := INVENTORY.empty(HUMAN_ACTOR_ID)
	human = INVENTORY.add_normal_card(human, {
		"card_instance_id": "card.human.attack.1",
		"card_semantic_id": "v07.card.human-attack",
		"source_revision": 10,
	}).get("state", {})
	var ai := INVENTORY.empty(AI_ACTOR_ID)
	ai = INVENTORY.add_normal_card(ai, {
		"card_instance_id": "card.ai.defense.1",
		"card_semantic_id": "v07.card.ai-defense",
		"source_revision": 11,
	}).get("state", {})
	var rival := INVENTORY.empty(RIVAL_ACTOR_ID)
	rival = INVENTORY.add_normal_card(rival, {
		"card_instance_id": RIVAL_PRIVATE_CARD_ID,
		"card_semantic_id": "v07.card.rival-private",
		"source_revision": 12,
	}).get("state", {})
	return {HUMAN_ACTOR_ID: human, AI_ACTOR_ID: ai, RIVAL_ACTOR_ID: rival}


func _human_submission() -> Dictionary:
	return SUBMISSION.build(
		"submission.human.1",
		HUMAN_ACTOR_ID,
		"card.human.attack.1",
		"v07.card.human-attack",
		"normal_card",
		"normal_hand",
		10,
		0,
		10,
		0,
		TARGET.build(
			"region",
			[PUBLIC_TARGET_ID],
			18,
			"",
			"standard",
			1,
			{"effect_kind": "damage", "effect_amount": 7}
		)
	)


func _ai_candidate() -> Dictionary:
	return {
		"card_instance_id": "card.ai.defense.1",
		"card_semantic_id": "v07.card.ai-defense",
		"source_pool": "normal_hand",
		"source_revision": 11,
		"action_class": "proactive_defense",
		"order_priority": 0,
		"submission_sequence": 0,
		"base_utility": 8,
		"urgency": 4,
		"legal_target_options": [{
			"visibility_scope_id": "public",
			"target_binding": TARGET.build(
				"region",
				[PUBLIC_TARGET_ID],
				18,
				"shield-slot.1",
				"protect",
				1,
				{
					"effect_kind": "damage",
					"defense_kind": "shield",
					"duration_batches": 1,
					"prevention_count": 1,
					"reduction_amount": 7,
				}
			),
			"target_value": 6,
			"threat_level": 6,
			"synergy_value": 4,
		}],
	}


func _ai_source_from_core(state: Dictionary, viewer: Dictionary, candidates: Array) -> Dictionary:
	var phase := str(state.get("phase", ""))
	var public_receipts: Array = []
	var receipt_index := 0
	for receipt_variant in viewer.get("completed_receipts", []) as Array:
		if not (receipt_variant is Dictionary):
			continue
		var receipt := receipt_variant as Dictionary
		public_receipts.append({
			"receipt_id": _public_receipt_id(state, receipt_index),
			"result_kind": "card_resolution_committed",
			"public_target_ids": (receipt.get("resolved_target_ids", []) as Array).duplicate(),
			"outcome_code": str(receipt.get("outcome", "")),
			"batch_revision": int(state.get("batch_revision", -1)),
		})
		receipt_index += 1
	return {
		"schema_version": OBSERVATION.SCHEMA_VERSION,
		"ruleset_id": OBSERVATION.RULESET_ID,
		"viewer_actor_id": AI_ACTOR_ID,
		"viewer_seat_index": 1,
		"visibility_scope_id": OBSERVATION.VISIBILITY_SCOPE_ID,
		"batch_id": str(state.get("batch_id", "")),
		"batch_revision": int(state.get("batch_revision", -1)),
		"window_id": str(state.get("window_id", "")),
		"window_remaining_phase_time_usec": int(state.get("window_remaining_phase_time_usec", 0)),
		"source_revision": int(state.get("batch_revision", -1)),
		"phase": phase,
		"own_inventory": (viewer.get("own_inventory", {}) as Dictionary).duplicate(true) \
			if phase == OBSERVATION.PHASE_CARD_WINDOW_OPEN else {},
		"legal_candidates": candidates.duplicate(true) \
			if phase == OBSERVATION.PHASE_CARD_WINDOW_OPEN else [],
		"public_resolution_receipts": public_receipts,
	}


func _issue_observation(source: Dictionary, actor_id: String, seat_index: int) -> Dictionary:
	var owner := SOURCE_OWNER.new() as AiCardBatchObservationSourceOwner
	root.add_child(owner)
	var configured := owner.configure_authorized_actor(
		actor_id,
		seat_index,
		int(source.get("source_revision", -1))
	)
	var observation := owner.issue_observation(source) if configured else {}
	root.remove_child(owner)
	owner.free()
	return observation


func _player_open_projections(state: Dictionary, viewer: Dictionary) -> Dictionary:
	var own_draft: Dictionary = viewer.get("own_draft", {}) if viewer.get("own_draft") is Dictionary else {}
	var binding: Dictionary = own_draft.get("target_binding", {}) if own_draft.get("target_binding") is Dictionary else {}
	var target_ids: Array = binding.get("target_ids", []) if binding.get("target_ids") is Array else []
	return {
		"roster": {"players": _player_rows(state.get("actor_ids", []))},
		"window": {
			"phase": str(state.get("phase", "")),
			"window_id": str(state.get("window_id", "")),
			"batch_id": str(state.get("batch_id", "")),
			"window_duration_seconds": 30,
			"remaining_seconds": int(ceil(float(state.get("window_remaining_phase_time_usec", 0)) / 1_000_000.0)),
			"status_text": "所有选择由 Core 窗口锁定",
		},
		"submission": {
			"card_display_name": str(own_draft.get("card_semantic_id", "")),
			"target_display_name": str(target_ids[0]) if not target_ids.is_empty() else "无目标",
			"mode_display_name": str(binding.get("mode_id", "standard")),
			"quantity": int(binding.get("quantity", 1)),
			"locked": not str(own_draft.get("locked_at_window_id", "")).is_empty(),
		},
		"dock": _player_dock_projection(viewer.get("own_inventory", {})),
	}


func _player_dock_projection(inventory_variant: Variant) -> Dictionary:
	var inventory: Dictionary = inventory_variant if inventory_variant is Dictionary else {}
	var normal_cards: Array = []
	for card_variant in inventory.get("normal_cards", []) as Array:
		var card := card_variant as Dictionary
		normal_cards.append({
			"display_name": str(card.get("card_semantic_id", "")),
			"card_semantic_id": str(card.get("card_semantic_id", "")),
			"action_class": "normal_card",
		})
	var commodity_stacks: Array = []
	for card_variant in inventory.get("commodity_cards", []) as Array:
		var card := card_variant as Dictionary
		commodity_stacks.append({
			"display_name": str(card.get("card_semantic_id", "")),
			"card_semantic_id": str(card.get("card_semantic_id", "")),
			"level": int(card.get("commodity_level", 1)),
			"base_units": int(card.get("commodity_level", 1)),
		})
	var bound_actions: Array = []
	for action_variant in inventory.get("bound_actions", []) as Array:
		var action := action_variant as Dictionary
		bound_actions.append({
			"display_name": str(action.get("card_semantic_id", "")),
			"card_semantic_id": str(action.get("card_semantic_id", "")),
			"source_kind": str(action.get("source_kind", "")),
			"action_class": str(action.get("action_kind", "")),
		})
	return {
		"normal_cards": normal_cards,
		"commodity_stacks": commodity_stacks,
		"bound_actions": bound_actions,
	}


func _player_rows(actor_ids_variant: Variant) -> Array:
	var result: Array = []
	if not (actor_ids_variant is Array):
		return result
	for index in range((actor_ids_variant as Array).size()):
		result.append({
			"player_id": str((actor_ids_variant as Array)[index]),
			"display_name": "玩家 %d" % (index + 1),
			"public_status": "已提交" if index < 2 else "等待",
		})
	return result


func _player_receipt_projection(state: Dictionary, viewer: Dictionary) -> Dictionary:
	var completed: Array = viewer.get("completed_receipts", []) if viewer.get("completed_receipts") is Array else []
	var receipt: Dictionary = completed[-1] if not completed.is_empty() and completed[-1] is Dictionary else {}
	var index := int(receipt.get("resolution_index", 0))
	var order: Array = viewer.get("revealed_resolution_order", []) if viewer.get("revealed_resolution_order") is Array else []
	var current_card := _revealed_card_at(order, index)
	var next_card := _revealed_card_at(order, index + 1)
	var remaining: Array = []
	for order_index in range(index + 2, order.size()):
		remaining.append(_revealed_card_at(order, order_index))
	return {
		"phase": str(state.get("phase", "")),
		"batch_id": str(state.get("batch_id", "")),
		"receipt_id": _public_receipt_id(state, index),
		"batch_label": str(state.get("batch_id", "")),
		"completed_count": completed.size(),
		"total_count": order.size(),
		"current_card": current_card,
		"next_card": next_card if not next_card.is_empty() else "批次收尾",
		"remaining_cards": remaining,
		"defense_feedback": "既存防御自动应用" \
			if not (receipt.get("defense_applications", []) as Array).is_empty() else "无额外防御触发",
		"authoritative_result": str(receipt.get("outcome", "")),
	}


func _revealed_card_at(order: Array, index: int) -> String:
	if index < 0 or index >= order.size() or not (order[index] is Dictionary):
		return ""
	return str((order[index] as Dictionary).get("card_semantic_id", ""))


func _public_receipt_id(state: Dictionary, index: int) -> String:
	return "public-card-result:%s:%03d" % [str(state.get("batch_id", "")), index]


func _observation_is_legal_subset(observation: Dictionary, state: Dictionary, viewer: Dictionary) -> bool:
	if observation.is_empty() \
			or str(observation.get("batch_id", "")) != str(state.get("batch_id", "")) \
			or str(observation.get("window_id", "")) != str(state.get("window_id", "")) \
			or str(observation.get("phase", "")) != str(state.get("phase", "")) \
			or int(observation.get("batch_revision", -1)) != int(state.get("batch_revision", -2)):
		return false
	if str(state.get("phase", "")) == OBSERVATION.PHASE_CARD_WINDOW_OPEN:
		if PURE.stable_fingerprint(observation.get("own_inventory", {})) \
				!= PURE.stable_fingerprint(viewer.get("own_inventory", {})):
			return false
		var own_ids := _inventory_item_ids(viewer.get("own_inventory", {}))
		for candidate_variant in observation.get("legal_candidates", []) as Array:
			var candidate := candidate_variant as Dictionary
			if str(candidate.get("card_instance_id", "")) not in own_ids:
				return false
			for option_variant in candidate.get("legal_target_options", []) as Array:
				var option := option_variant as Dictionary
				var binding: Dictionary = option.get("target_binding", {})
				for target_id_variant in binding.get("target_ids", []) as Array:
					if str(target_id_variant) != PUBLIC_TARGET_ID:
						return false
	else:
		if not (observation.get("own_inventory", {}) as Dictionary).is_empty() \
				or not (observation.get("legal_candidates", []) as Array).is_empty():
			return false
	return (observation.get("public_resolution_receipts", []) as Array).size() \
		== (viewer.get("completed_receipts", []) as Array).size()


func _player_open_projection_is_legal_subset(projections: Dictionary, state: Dictionary, viewer: Dictionary) -> bool:
	var window: Dictionary = projections.get("window", {})
	var dock: Dictionary = projections.get("dock", {})
	if str(window.get("phase", "")) != str(state.get("phase", "")) \
			or str(window.get("batch_id", "")) != str(state.get("batch_id", "")) \
			or str(window.get("window_id", "")) != str(state.get("window_id", "")):
		return false
	var projected_semantic_ids: Array[String] = []
	for pool_key in ["normal_cards", "commodity_stacks", "bound_actions"]:
		for row_variant in dock.get(pool_key, []) as Array:
			projected_semantic_ids.append(str((row_variant as Dictionary).get("card_semantic_id", "")))
	var own_semantic_ids := _inventory_semantic_ids(viewer.get("own_inventory", {}))
	for semantic_id in projected_semantic_ids:
		if semantic_id not in own_semantic_ids:
			return false
	return not (viewer.get("own_draft", {}) as Dictionary).is_empty()


func _receipt_projections_share_core_lineage(
	core_receipt: Dictionary,
	ai_observation: Dictionary,
	player_projection: Dictionary
) -> bool:
	var ai_receipts: Array = ai_observation.get("public_resolution_receipts", []) \
		if ai_observation.get("public_resolution_receipts") is Array else []
	if ai_receipts.is_empty() or not (ai_receipts[-1] is Dictionary):
		return false
	var ai_receipt := ai_receipts[-1] as Dictionary
	return int(core_receipt.get("resolution_index", -1)) == ai_receipts.size() - 1 \
		and str(ai_receipt.get("receipt_id", "")) == str(player_projection.get("receipt_id", "")) \
		and str(ai_receipt.get("outcome_code", "")) == str(core_receipt.get("outcome", "")) \
		and str(player_projection.get("authoritative_result", "")) == str(core_receipt.get("outcome", "")) \
		and ai_receipt.get("public_target_ids", []) == core_receipt.get("resolved_target_ids", [])


func _inventory_item_ids(inventory_variant: Variant) -> Array[String]:
	var result: Array[String] = []
	if not (inventory_variant is Dictionary):
		return result
	var inventory := inventory_variant as Dictionary
	for pool_key in ["normal_cards", "commodity_cards"]:
		for row_variant in inventory.get(pool_key, []) as Array:
			result.append(str((row_variant as Dictionary).get("card_instance_id", "")))
	for row_variant in inventory.get("bound_actions", []) as Array:
		result.append(str((row_variant as Dictionary).get("bound_action_id", "")))
	return result


func _inventory_semantic_ids(inventory_variant: Variant) -> Array[String]:
	var result: Array[String] = []
	if not (inventory_variant is Dictionary):
		return result
	var inventory := inventory_variant as Dictionary
	for pool_key in ["normal_cards", "commodity_cards", "bound_actions"]:
		for row_variant in inventory.get(pool_key, []) as Array:
			result.append(str((row_variant as Dictionary).get("card_semantic_id", "")))
	return result


func _no_forbidden_projection_data(values: Array) -> bool:
	var serialized := JSON.stringify(values).to_lower()
	for token in FORBIDDEN_PROJECTION_TOKENS:
		if serialized.contains(token.to_lower()):
			return false
	return true


func _production_composition_is_detached() -> bool:
	for path in PRODUCTION_COMPOSITION_PATHS:
		var source := FileAccess.get_file_as_string(path)
		for token in REFERENCE_ONLY_TOKENS:
			if source.contains(token):
				return false
	return true


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish(core_fingerprint: String) -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print(
		"V07_CARD_BATCH_THREE_LAYER_INTEGRATION_TEST|status=%s|checks=%d|failures=%d|core_fingerprint=%s|double_write_count=0|counter_path_count=0|production_connection_count=0"
		% [status, _checks, _failures.size(), core_fingerprint]
	)
	for failure in _failures:
		push_error("V07_CARD_BATCH_THREE_LAYER_INTEGRATION_TEST: %s" % failure)
	quit(0 if _failures.is_empty() else 1)
