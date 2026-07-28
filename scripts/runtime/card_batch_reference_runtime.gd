@tool
extends Node
class_name CardBatchReferenceRuntime

const PURE = preload("res://scripts/semantic/card_batch_pure_data.gd")
const TARGET = preload("res://scripts/semantic/card_batch_prebound_target_spec_v1.gd")
const SUBMISSION = preload("res://scripts/semantic/card_batch_submission_v1.gd")
const RESOLUTION = preload("res://scripts/semantic/card_batch_card_resolution_state_v1.gd")
const DEFENSE = preload("res://scripts/semantic/card_batch_defense_status_v1.gd")
const INVENTORY = preload("res://scripts/semantic/card_batch_inventory_state_v1.gd")
const RECEIPT = preload("res://scripts/semantic/card_batch_receipt_v1.gd")
const STATE = preload("res://scripts/semantic/card_batch_state_v1.gd")
const SAVE_CODEC = preload("res://scripts/runtime/card_batch_save_codec_v1.gd")
const REPLAY_IDENTITY = preload("res://scripts/runtime/card_batch_replay_identity_v1.gd")
const VIEWER_AUTHORIZATION = preload("res://scripts/semantic/card_batch_viewer_authorization_v1.gd")
const AUTHORED_RULE = preload("res://scripts/semantic/card_batch_authored_rule_v1.gd")

const MAX_ACTORS := 8
const MAX_UNINTERRUPTED_STEPS := 128

var _state: Dictionary = STATE.empty_state()
var _rejection_count := 0
var _last_reason_code := "idle"
var _viewer_authorization_by_instance_id: Dictionary = {}


func begin_initial_window(actor_ids: Array, inventories_by_actor: Dictionary = {}, world_effective_time_usec: int = 0) -> Dictionary:
	if int(_state.get("batch_sequence", 0)) != 0:
		return _rejected("card_batch_initial_window_already_started")
	var normalized_actor_ids := PURE.string_array(actor_ids, true)
	if normalized_actor_ids.size() != actor_ids.size() or normalized_actor_ids.is_empty() or normalized_actor_ids.size() > MAX_ACTORS:
		return _rejected("card_batch_actor_roster_invalid")
	if world_effective_time_usec < 0:
		return _rejected("card_batch_world_time_invalid")
	var inventories := {}
	for actor_id in normalized_actor_ids:
		var inventory: Dictionary = inventories_by_actor.get(actor_id, INVENTORY.empty(actor_id)) if inventories_by_actor.get(actor_id, INVENTORY.empty(actor_id)) is Dictionary else {}
		var validation := INVENTORY.validate(inventory)
		if not bool(validation.get("valid", false)) or str(inventory.get("actor_id", "")) != actor_id:
			return _rejected("card_batch_inventory_invalid:%s" % actor_id)
		inventories[actor_id] = (validation.get("normalized", {}) as Dictionary).duplicate(true)
	_state = STATE.empty_state()
	_viewer_authorization_by_instance_id.clear()
	_state["batch_sequence"] = 1
	_state["batch_id"] = _batch_id(1)
	_state["window_sequence"] = 1
	_state["window_id"] = _window_id(1)
	_state["window_remaining_phase_time_usec"] = STATE.WINDOW_DURATION_USEC
	_state["world_effective_time_usec"] = world_effective_time_usec
	_state["actor_ids"] = normalized_actor_ids
	_state["inventories_by_actor"] = inventories
	_transition(STATE.PHASE_CARD_WINDOW_OPEN, "INITIAL_WINDOW_BOOTSTRAP")
	return _accepted("card_batch_initial_window_opened", {"state": state_snapshot()})


func set_inventory(actor_id: String, inventory: Dictionary) -> Dictionary:
	if str(_state.get("phase", "")) != STATE.PHASE_CARD_WINDOW_OPEN:
		return _rejected("card_batch_inventory_update_outside_window")
	if actor_id not in (_state.get("actor_ids", []) as Array):
		return _rejected("card_batch_inventory_actor_unknown")
	var validation := INVENTORY.validate(inventory)
	if not bool(validation.get("valid", false)) or str(inventory.get("actor_id", "")) != actor_id:
		return _rejected("card_batch_inventory_invalid")
	var inventories: Dictionary = _state.get("inventories_by_actor", {})
	inventories[actor_id] = (validation.get("normalized", {}) as Dictionary).duplicate(true)
	_state["inventories_by_actor"] = inventories
	_bump_revision("INVENTORY_UPDATED")
	return _accepted("card_batch_inventory_updated")


func configure_authoritative_card_rules(rules_by_semantic_id: Dictionary) -> Dictionary:
	if str(_state.get("phase", "")) != STATE.PHASE_CARD_WINDOW_OPEN \
			or not (_state.get("submissions_by_actor", {}) as Dictionary).is_empty():
		return _rejected("card_batch_authored_rules_configuration_closed")
	if not PURE.is_pure_json_data(rules_by_semantic_id):
		return _rejected("card_batch_authored_rules_not_pure")
	var normalized: Dictionary = {}
	for semantic_id_variant in rules_by_semantic_id.keys():
		var semantic_id := str(semantic_id_variant)
		if semantic_id.is_empty() or not (rules_by_semantic_id.get(semantic_id_variant) is Dictionary):
			return _rejected("card_batch_authored_rule_key_invalid")
		var validation := AUTHORED_RULE.validate(rules_by_semantic_id.get(semantic_id_variant, {}))
		if not bool(validation.get("valid", false)) \
				or str((validation.get("normalized", {}) as Dictionary).get("card_semantic_id", "")) != semantic_id:
			return _rejected("card_batch_authored_rule_invalid:%s" % semantic_id)
		normalized[semantic_id] = (validation.get("normalized", {}) as Dictionary).duplicate(true)
	_state["authored_rules_by_semantic_id"] = normalized
	_bump_revision("AUTHORED_RULES_CONFIGURED")
	return _accepted("card_batch_authored_rules_configured", {
		"rule_count": normalized.size(),
		"catalog_fingerprint": PURE.stable_fingerprint(normalized),
	})


func grant_bound_action(actor_id: String, action: Dictionary) -> Dictionary:
	if str(_state.get("phase", "")) != STATE.PHASE_CARD_WINDOW_OPEN:
		return _rejected("bound_action_grant_outside_window")
	var inventory := _inventory_for(actor_id)
	if inventory.is_empty():
		return _rejected("bound_action_actor_unknown")
	var grant := INVENTORY.grant_bound_action(inventory, action)
	if not bool(grant.get("committed", false)):
		return _rejected(str(grant.get("reason_code", "bound_action_grant_rejected")))
	return set_inventory(actor_id, grant.get("state", {}))


func revoke_bound_actions_from_source(actor_id: String, source_kind: String, source_id: String) -> Dictionary:
	if str(_state.get("phase", "")) != STATE.PHASE_CARD_WINDOW_OPEN:
		return _rejected("bound_action_revoke_outside_window")
	var inventory := _inventory_for(actor_id)
	if inventory.is_empty():
		return _rejected("bound_action_actor_unknown")
	var revoke := INVENTORY.revoke_source(inventory, source_kind, source_id)
	if not bool(revoke.get("committed", false)):
		return _rejected(str(revoke.get("reason_code", "bound_action_revoke_rejected")))
	return set_inventory(actor_id, revoke.get("state", {}))


func submit_or_replace_draft(submission: Dictionary) -> Dictionary:
	if str(_state.get("phase", "")) != STATE.PHASE_CARD_WINDOW_OPEN:
		return _rejected("resolution_accepts_no_gameplay_input")
	var validation := SUBMISSION.validate(submission, false)
	if not bool(validation.get("valid", false)):
		return _rejected(str(validation.get("reason_code", "card_batch_submission_invalid")))
	if not str(submission.get("locked_at_window_id", "")).is_empty():
		return _rejected("card_batch_draft_must_be_unlocked")
	var authored_rules: Dictionary = _state.get("authored_rules_by_semantic_id", {})
	var authored_rule: Dictionary = authored_rules.get(str(submission.get("card_semantic_id", "")), {})
	if not AUTHORED_RULE.matches_submission(authored_rule, submission):
		return _rejected("card_batch_submission_authored_rule_mismatch")
	var actor_id := str(submission.get("actor_id", ""))
	var actors: Array = _state.get("actor_ids", [])
	if actor_id not in actors or actors.find(actor_id) != int(submission.get("actor_seat_index", -1)):
		return _rejected("card_batch_submission_actor_binding_invalid")
	if not _submission_source_available(submission):
		return _rejected("card_batch_submission_source_unavailable")
	var drafts: Dictionary = _state.get("submissions_by_actor", {})
	for existing_actor_variant in drafts.keys():
		var existing: Dictionary = drafts.get(existing_actor_variant, {})
		if str(existing.get("submission_id", "")) == str(submission.get("submission_id", "")) and str(existing_actor_variant) != actor_id:
			return _rejected("card_batch_submission_id_duplicate")
	drafts[actor_id] = (validation.get("normalized", {}) as Dictionary).duplicate(true)
	_state["submissions_by_actor"] = drafts
	_bump_revision("DRAFT_SUBMITTED_OR_REPLACED")
	return _accepted("card_batch_draft_recorded", {"submission_id": str(submission.get("submission_id", ""))})


func withdraw_draft(actor_id: String) -> Dictionary:
	if str(_state.get("phase", "")) != STATE.PHASE_CARD_WINDOW_OPEN:
		return _rejected("resolution_accepts_no_gameplay_input")
	var drafts: Dictionary = _state.get("submissions_by_actor", {})
	if not drafts.has(actor_id):
		return _rejected("card_batch_draft_missing")
	drafts.erase(actor_id)
	_state["submissions_by_actor"] = drafts
	_bump_revision("DRAFT_WITHDRAWN")
	return _accepted("card_batch_draft_withdrawn")


func advance_window_phase_time_usec(delta_usec: int) -> Dictionary:
	if str(_state.get("phase", "")) != STATE.PHASE_CARD_WINDOW_OPEN:
		return _rejected("card_batch_window_timer_not_running")
	if delta_usec < 0:
		return _rejected("card_batch_window_delta_invalid")
	var remaining := int(_state.get("window_remaining_phase_time_usec", 0))
	var consumed := mini(delta_usec, remaining)
	_state["window_remaining_phase_time_usec"] = remaining - consumed
	_state["world_effective_time_usec"] = int(_state.get("world_effective_time_usec", 0)) + consumed
	_state["card_phase_time_usec"] = int(_state.get("card_phase_time_usec", 0)) + consumed
	_advance_bound_action_cooldowns(consumed)
	if int(_state.get("window_remaining_phase_time_usec", 0)) == 0:
		var lock_result := lock_window()
		return _accepted("card_batch_window_elapsed", {"consumed_usec": consumed, "lock_result": lock_result}) if bool(lock_result.get("accepted", false)) else lock_result
	return _accepted("card_batch_window_advanced", {"consumed_usec": consumed, "remaining_usec": int(_state.get("window_remaining_phase_time_usec", 0))})


func lock_window() -> Dictionary:
	if str(_state.get("phase", "")) != STATE.PHASE_CARD_WINDOW_OPEN:
		return _rejected("card_batch_window_not_open")
	var drafts: Dictionary = _state.get("submissions_by_actor", {})
	for actor_variant in drafts.keys():
		var draft: Dictionary = drafts.get(actor_variant, {})
		if not _submission_source_available(draft):
			return _rejected("card_batch_submission_source_changed_before_lock:%s" % str(actor_variant))
	_transition(STATE.PHASE_CARD_WINDOW_LOCKING, "WINDOW_LOCKED")
	_state["window_remaining_phase_time_usec"] = 0
	var locked_ids: Array[String] = []
	var locked_by_id := {}
	for actor_id_variant in _state.get("actor_ids", []) as Array:
		var actor_id := str(actor_id_variant)
		if not drafts.has(actor_id):
			continue
		var locked := SUBMISSION.locked_copy(drafts.get(actor_id, {}), str(_state.get("window_id", "")))
		if locked.is_empty():
			return _rejected("card_batch_submission_lock_failed:%s" % actor_id)
		var submission_id := str(locked.get("submission_id", ""))
		locked_ids.append(submission_id)
		locked_by_id[submission_id] = locked
	_state["locked_submission_ids"] = locked_ids
	_state["locked_submissions_by_id"] = locked_by_id
	_transition(STATE.PHASE_RESOLUTION_ORDER_BUILD, "LOCKED_SUBMISSIONS_FROZEN")
	var order_rows: Array = []
	for submission_id in locked_ids:
		order_rows.append(locked_by_id.get(submission_id, {}))
	order_rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return SUBMISSION.stable_order_key(left) < SUBMISSION.stable_order_key(right))
	var resolution_order: Array[String] = []
	for row_variant in order_rows:
		resolution_order.append(str((row_variant as Dictionary).get("submission_id", "")))
	_state["resolution_order"] = resolution_order
	_state["current_resolution_index"] = 0
	_transition(STATE.PHASE_RESOLUTION_ORDER_REVEAL, "UNIQUE_RESOLUTION_ORDER_REVEALED")
	if resolution_order.is_empty():
		_state["active_resolution_id"] = ""
		_state["card_resolution_state"] = {}
		_transition(STATE.PHASE_BATCH_AFTERMATH, "EMPTY_BATCH_REQUIRES_COMPLETION_RECEIPT")
	else:
		_state["active_resolution_id"] = resolution_order[0]
		_transition(STATE.PHASE_CARD_RESOLUTION_ACTIVE, "FIRST_LOCKED_CARD_ACTIVE")
		_set_card_resolution_state(STATE.PHASE_CARD_RESOLUTION_ACTIVE)
	return _accepted("card_batch_window_locked", {
		"resolution_order": resolution_order.duplicate(),
		"resolution_order_fingerprint": PURE.stable_fingerprint(resolution_order),
	})


func commit_active_card(target_validation_projection: Dictionary) -> Dictionary:
	if str(_state.get("phase", "")) != STATE.PHASE_CARD_RESOLUTION_ACTIVE:
		return _rejected("card_batch_no_active_resolution")
	if not PURE.is_pure_json_data(target_validation_projection):
		return _rejected("card_batch_target_validation_projection_not_pure")
	var submission_id := str(_state.get("active_resolution_id", ""))
	var locked: Dictionary = _state.get("locked_submissions_by_id", {})
	if not (locked.get(submission_id) is Dictionary):
		return _rejected("card_batch_active_submission_missing")
	var submission := locked.get(submission_id, {}) as Dictionary
	_transition(STATE.PHASE_CARD_EFFECT_COMMIT, "LOCKED_CARD_COMMIT_STARTED")
	_set_card_resolution_state(STATE.PHASE_CARD_EFFECT_COMMIT)
	var target_result := _resolve_prebound_targets(submission, target_validation_projection)
	var outcome := str(target_result.get("outcome", "FIZZLE_NO_EFFECT"))
	var resolved_target_ids: Array = target_result.get("resolved_target_ids", [])
	var binding: Dictionary = submission.get("target_binding", {})
	var authored: Dictionary = binding.get("authored_parameters", {})
	var defense_applications: Array = []
	var effect_amount := 0
	var created_defense_status_id := ""
	if outcome != "FIZZLE_NO_EFFECT" and outcome != "REFUND_BY_AUTHORED_RULE":
		if str(submission.get("action_class", "")) == "proactive_defense":
			var defense_creation := _create_defense_status(submission, resolved_target_ids)
			if not bool(defense_creation.get("created", false)):
				outcome = "FIZZLE_NO_EFFECT"
				target_result["reason_code"] = str(defense_creation.get("reason_code", "defense_status_invalid"))
			else:
				created_defense_status_id = str(defense_creation.get("defense_status_id", ""))
		else:
			effect_amount = int(authored.get("effect_amount", 0)) * int(binding.get("quantity", 1))
			var defense_result := _apply_existing_defenses(submission, resolved_target_ids, effect_amount)
			effect_amount = int(defense_result.get("effect_amount", effect_amount))
			defense_applications = defense_result.get("applications", [])
	var mutation_summary := {
		"mutation_kind": "DEFENSE_STATUS_CREATED" if not created_defense_status_id.is_empty() else ("NO_EFFECT" if outcome in ["FIZZLE_NO_EFFECT", "REFUND_BY_AUTHORED_RULE"] else "CARD_EFFECT_COMMITTED"),
		"submission_id": submission_id,
		"resolved_target_ids": resolved_target_ids.duplicate(),
		"effect_amount": effect_amount,
		"created_defense_status_id": created_defense_status_id,
		"defense_application_count": defense_applications.size(),
	}
	if outcome not in ["FIZZLE_NO_EFFECT", "REFUND_BY_AUTHORED_RULE"] and created_defense_status_id.is_empty():
		_commit_effect_totals(resolved_target_ids, effect_amount)
	if outcome != "REFUND_BY_AUTHORED_RULE":
		_consume_submission_source(submission, authored)
	var receipt_id := RECEIPT.expected_card_receipt_id(
		str(_state.get("batch_id", "")),
		int(_state.get("current_resolution_index", 0))
	)
	var receipt := RECEIPT.card_resolution(
		receipt_id,
		str(_state.get("batch_id", "")),
		str(_state.get("window_id", "")),
		int(_state.get("current_resolution_index", 0)),
		submission,
		outcome,
		resolved_target_ids,
		effect_amount,
		defense_applications,
		mutation_summary,
		str(target_result.get("reason_code", ""))
	)
	var receipts: Array = _state.get("card_receipts", [])
	receipts.append(receipt)
	_state["card_receipts"] = receipts
	var pending: Array = _state.get("pending_receipt_ids", [])
	pending.append(receipt_id)
	_state["pending_receipt_ids"] = pending
	var mutations: Array = _state.get("mutation_trace", [])
	mutations.append({
		"mutation_index": mutations.size(),
		"batch_id": str(_state.get("batch_id", "")),
		"submission_id": submission_id,
		"outcome": outcome,
		"summary": mutation_summary.duplicate(true),
		"receipt_fingerprint": PURE.stable_fingerprint(receipt),
	})
	_state["mutation_trace"] = mutations
	_state["aftermath_state"] = {"kind": "CARD", "receipt_id": receipt_id, "complete": false}
	_transition(STATE.PHASE_CARD_AFTERMATH, "AUTHORITATIVE_CARD_RECEIPT_PENDING")
	var applied_defense_status_ids: Array = []
	for application_variant in defense_applications:
		if application_variant is Dictionary:
			applied_defense_status_ids.append(str((application_variant as Dictionary).get("defense_status_id", "")))
	_set_card_resolution_state(
		STATE.PHASE_CARD_AFTERMATH,
		outcome,
		receipt_id,
		str(target_result.get("reason_code", "target_validation_complete")),
		applied_defense_status_ids
	)
	return _accepted("card_batch_card_committed", {"receipt": receipt.duplicate(true)})


func complete_card_aftermath(receipt_id: String) -> Dictionary:
	if str(_state.get("phase", "")) != STATE.PHASE_CARD_AFTERMATH:
		return _rejected("card_batch_card_aftermath_not_pending")
	var aftermath: Dictionary = _state.get("aftermath_state", {})
	if str(aftermath.get("receipt_id", "")) != receipt_id:
		return _rejected("card_batch_card_aftermath_receipt_mismatch")
	var pending: Array = _state.get("pending_receipt_ids", [])
	if receipt_id not in pending:
		return _rejected("card_batch_pending_receipt_missing")
	pending.erase(receipt_id)
	_state["pending_receipt_ids"] = pending
	_state["aftermath_state"] = {}
	var next_index := int(_state.get("current_resolution_index", 0)) + 1
	_state["current_resolution_index"] = next_index
	var order: Array = _state.get("resolution_order", [])
	if next_index < order.size():
		_state["active_resolution_id"] = str(order[next_index])
		_transition(STATE.PHASE_CARD_RESOLUTION_ACTIVE, "NEXT_LOCKED_CARD_ACTIVE")
		_set_card_resolution_state(STATE.PHASE_CARD_RESOLUTION_ACTIVE)
	else:
		_state["active_resolution_id"] = ""
		_state["card_resolution_state"] = {}
		_transition(STATE.PHASE_BATCH_AFTERMATH, "ALL_LOCKED_CARDS_COMMITTED")
	return _accepted("card_batch_card_aftermath_complete")


func complete_batch_aftermath() -> Dictionary:
	if str(_state.get("phase", "")) != STATE.PHASE_BATCH_AFTERMATH:
		return _rejected("card_batch_batch_aftermath_not_ready")
	if not (_state.get("pending_receipt_ids", []) as Array).is_empty() or not str(_state.get("active_resolution_id", "")).is_empty():
		return _rejected("card_batch_batch_completion_gate_blocked")
	_state["aftermath_state"] = {"kind": "BATCH", "complete": true}
	_state["batch_after_action_complete"] = true
	_transition(STATE.PHASE_BATCH_COMPLETE, "BATCH_AFTERMATH_COMPLETE")
	var order: Array = _state.get("resolution_order", [])
	var receipt_id := RECEIPT.expected_batch_receipt_id(str(_state.get("batch_id", "")))
	var receipt := RECEIPT.batch_complete(
		receipt_id,
		str(_state.get("batch_id", "")),
		str(_state.get("window_id", "")),
		order,
		PURE.stable_fingerprint(order),
		PURE.stable_fingerprint(_state.get("defense_statuses", [])),
		_window_id(int(_state.get("window_sequence", 0)) + 1),
		PURE.stable_fingerprint(_state.get("phase_trace", [])),
		order.is_empty()
	)
	_state["batch_complete"] = true
	_state["batch_complete_receipt"] = receipt
	return _accepted("card_batch_complete_receipt_emitted", {"receipt": receipt.duplicate(true)})


func consume_batch_complete_receipt(receipt: Dictionary) -> Dictionary:
	if not RECEIPT.validate_batch_complete(receipt):
		return _rejected("card_batch_complete_receipt_invalid")
	var receipt_id := str(receipt.get("receipt_id", ""))
	var consumed: Array = _state.get("consumed_batch_complete_receipt_ids", [])
	if receipt_id in consumed:
		return _rejected("card_batch_complete_receipt_duplicate")
	if str(_state.get("phase", "")) != STATE.PHASE_BATCH_COMPLETE or not bool(_state.get("batch_complete", false)):
		return _rejected("next_window_requires_batch_complete")
	var expected: Dictionary = _state.get("batch_complete_receipt", {})
	if PURE.stable_fingerprint(receipt) != PURE.stable_fingerprint(expected):
		return _rejected("card_batch_complete_receipt_mismatch")
	if not (_state.get("pending_receipt_ids", []) as Array).is_empty() or not bool(_state.get("batch_after_action_complete", false)):
		return _rejected("card_batch_complete_receipt_gate_blocked")
	consumed.append(receipt_id)
	_state["consumed_batch_complete_receipt_ids"] = consumed
	var next_batch_sequence := int(_state.get("batch_sequence", 0)) + 1
	var next_window_sequence := int(_state.get("window_sequence", 0)) + 1
	_state["batch_sequence"] = next_batch_sequence
	_state["batch_id"] = _batch_id(next_batch_sequence)
	_state["window_sequence"] = next_window_sequence
	_state["window_id"] = _window_id(next_window_sequence)
	_state["window_remaining_phase_time_usec"] = STATE.WINDOW_DURATION_USEC
	_state["submissions_by_actor"] = {}
	_state["locked_submission_ids"] = []
	_state["locked_submissions_by_id"] = {}
	_state["resolution_order"] = []
	_state["current_resolution_index"] = 0
	_state["active_resolution_id"] = ""
	_state["card_resolution_state"] = {}
	_state["pending_receipt_ids"] = []
	_state["card_receipts"] = []
	_state["aftermath_state"] = {}
	_state["batch_after_action_complete"] = false
	_state["batch_complete"] = false
	_state["batch_complete_receipt"] = {}
	_state["private_defense_receipts_by_actor"] = {}
	_state["phase_trace"] = []
	_state["mutation_trace"] = []
	_prune_expired_defenses()
	_transition(STATE.PHASE_CARD_WINDOW_OPEN, "BATCH_COMPLETE_RECEIPT_CONSUMED")
	return _accepted("card_batch_next_window_opened", {"window_id": str(_state.get("window_id", ""))})


func run_uninterrupted(target_projection_by_submission_id: Dictionary) -> Dictionary:
	if not PURE.is_pure_json_data(target_projection_by_submission_id):
		return _rejected("card_batch_target_projection_not_pure")
	var starting_receipt_count := (_state.get("card_receipts", []) as Array).size()
	var steps := 0
	while steps < MAX_UNINTERRUPTED_STEPS:
		steps += 1
		match str(_state.get("phase", "")):
			STATE.PHASE_CARD_RESOLUTION_ACTIVE:
				var submission_id := str(_state.get("active_resolution_id", ""))
				var projection: Dictionary = target_projection_by_submission_id.get(submission_id, {}) if target_projection_by_submission_id.get(submission_id, {}) is Dictionary else {}
				var commit_result := commit_active_card(projection)
				if not bool(commit_result.get("accepted", false)):
					return commit_result
			STATE.PHASE_CARD_AFTERMATH:
				var receipt_id := str((_state.get("aftermath_state", {}) as Dictionary).get("receipt_id", ""))
				var aftermath_result := complete_card_aftermath(receipt_id)
				if not bool(aftermath_result.get("accepted", false)):
					return aftermath_result
			STATE.PHASE_BATCH_AFTERMATH:
				var complete_result := complete_batch_aftermath()
				if not bool(complete_result.get("accepted", false)):
					return complete_result
			STATE.PHASE_BATCH_COMPLETE:
				var all_receipts: Array = _state.get("card_receipts", [])
				return _accepted("card_batch_uninterrupted_complete", {
					"new_card_receipts": all_receipts.slice(starting_receipt_count),
					"batch_complete_receipt": (_state.get("batch_complete_receipt", {}) as Dictionary).duplicate(true),
					"mid_resolution_gameplay_wait_count": 0,
					"counter_window_wait_seconds": 0,
					"counter_stack_depth": 0,
					"steps": steps,
				})
			_:
				return _rejected("card_batch_uninterrupted_run_phase_invalid")
	return _rejected("card_batch_uninterrupted_step_guard_exceeded")


func state_snapshot() -> Dictionary:
	return _state.duplicate(true)


func state_fingerprint() -> String:
	return STATE.fingerprint(_state)


func time_policy() -> Dictionary:
	var phase := str(_state.get("phase", ""))
	return {
		"world_effective_time_running": phase == STATE.PHASE_CARD_WINDOW_OPEN,
		"card_window_timer_running": phase == STATE.PHASE_CARD_WINDOW_OPEN,
		"presentation_time_running": phase in STATE.RESOLUTION_PHASES,
		"card_state_commits_sequentially": true,
		"no_world_tick_between_resolving_cards": phase in STATE.RESOLUTION_PHASES,
		"gameplay_input_accepted": phase == STATE.PHASE_CARD_WINDOW_OPEN,
	}


func bind_viewer_authorization(actor_id: String, authorization: CardBatchViewerAuthorizationV1) -> bool:
	if authorization == null or actor_id not in (_state.get("actor_ids", []) as Array):
		return false
	_viewer_authorization_by_instance_id[authorization.get_instance_id()] = {
		"actor_id": actor_id,
		"revision": authorization.revision(),
	}
	return true


func revoke_viewer_authorization(authorization: CardBatchViewerAuthorizationV1) -> void:
	if authorization != null:
		_viewer_authorization_by_instance_id.erase(authorization.get_instance_id())


func viewer_projection(authorization: CardBatchViewerAuthorizationV1) -> Dictionary:
	var binding: Dictionary = _viewer_authorization_by_instance_id.get(
		authorization.get_instance_id() if authorization != null else 0,
		{}
	)
	var viewer_actor_id := ""
	var authorization_revision := 0
	if authorization != null \
			and int(binding.get("revision", 0)) == authorization.revision():
		viewer_actor_id = str(binding.get("actor_id", ""))
		authorization_revision = int(binding.get("revision", 0))
	var phase := str(_state.get("phase", ""))
	var result := {
		"ruleset_id": STATE.RULESET_ID,
		"batch_id": str(_state.get("batch_id", "")),
		"window_id": str(_state.get("window_id", "")),
		"phase": phase,
		"window_remaining_phase_time_usec": int(_state.get("window_remaining_phase_time_usec", 0)),
		"submission_visibility": "PRIVATE_UNTIL_ORDER_REVEAL",
		"visibility_scope": "viewer_private" if not viewer_actor_id.is_empty() else "public",
		"authorization_revision": authorization_revision,
		"own_draft": {},
		"revealed_resolution_order": [],
		"completed_receipts": [],
		"own_inventory": {},
		"own_defense_trigger_receipts": [],
		"visible_defense_statuses": [],
	}
	var drafts: Dictionary = _state.get("submissions_by_actor", {})
	if phase == STATE.PHASE_CARD_WINDOW_OPEN and drafts.get(viewer_actor_id) is Dictionary:
		result["own_draft"] = (drafts.get(viewer_actor_id, {}) as Dictionary).duplicate(true)
	if viewer_actor_id in (_state.get("actor_ids", []) as Array):
		result["own_inventory"] = _inventory_for(viewer_actor_id)
		var private_receipts: Dictionary = _state.get("private_defense_receipts_by_actor", {})
		result["own_defense_trigger_receipts"] = (private_receipts.get(viewer_actor_id, []) as Array).duplicate(true) \
			if private_receipts.get(viewer_actor_id) is Array else []
	if phase in [STATE.PHASE_RESOLUTION_ORDER_REVEAL, STATE.PHASE_CARD_RESOLUTION_ACTIVE, STATE.PHASE_CARD_EFFECT_COMMIT, STATE.PHASE_CARD_AFTERMATH, STATE.PHASE_BATCH_AFTERMATH, STATE.PHASE_BATCH_COMPLETE]:
		var revealed: Array = []
		var locked: Dictionary = _state.get("locked_submissions_by_id", {})
		var resolution_position := 0
		for submission_id_variant in _state.get("resolution_order", []) as Array:
			var submission: Dictionary = locked.get(str(submission_id_variant), {})
			revealed.append({
				"resolution_index": resolution_position,
				"card_semantic_id": str(submission.get("card_semantic_id", "")),
				"action_class": str(submission.get("action_class", "")),
			})
			resolution_position += 1
		result["revealed_resolution_order"] = revealed
	var public_receipts: Array = []
	for receipt_variant in _state.get("card_receipts", []) as Array:
		var receipt := receipt_variant as Dictionary
		var safe_applications: Array = []
		for application_variant in receipt.get("defense_applications", []) as Array:
			if not (application_variant is Dictionary):
				continue
			var application := application_variant as Dictionary
			safe_applications.append({
				"effect_kind": str(application.get("effect_kind", "")),
				"amount_before": int(application.get("amount_before", 0)),
				"amount_after": int(application.get("amount_after", 0)),
				"remaining_uses": int(application.get("remaining_uses", 0)),
			})
		public_receipts.append({
			"resolution_index": int(receipt.get("resolution_index", -1)),
			"outcome": str(receipt.get("outcome", "")),
			"reason_code": str(receipt.get("reason_code", "")),
			"resolved_target_ids": (receipt.get("resolved_target_ids", []) as Array).duplicate(),
			"effect_amount": int(receipt.get("effect_amount", 0)),
			"defense_applications": safe_applications,
		})
	result["completed_receipts"] = public_receipts
	var visible_statuses: Array = []
	for status_variant in _state.get("defense_statuses", []) as Array:
		var status := status_variant as Dictionary
		var visibility := str(status.get("visibility_policy", ""))
		if visibility == "public":
			visible_statuses.append({
				"defense_kind": str(status.get("defense_kind", "")),
				"effect_filter": str(status.get("effect_filter", "")),
				"protected_target_ids": (status.get("protected_target_ids", []) as Array).duplicate(),
				"reduction_amount": int(status.get("reduction_amount", 0)),
				"prevention_count": int(status.get("prevention_count", 0)),
				"remaining_uses": int(status.get("remaining_uses", 0)),
				"visibility_policy": "public",
			})
		elif visibility == "owner_private" and str(status.get("owner_player_id", "")) == viewer_actor_id:
			visible_statuses.append(status.duplicate(true))
	result["visible_defense_statuses"] = visible_statuses
	return result


func capture_save_data() -> Dictionary:
	return SAVE_CODEC.capture(_state)


func restore_save_data(save_data: Dictionary) -> Dictionary:
	var roundtrip := SAVE_CODEC.stable_roundtrip(save_data)
	if not bool(roundtrip.get("roundtrip", false)):
		return _rejected(str(roundtrip.get("reason_code", "card_batch_save_restore_rejected")))
	_state = (roundtrip.get("restored_state", {}) as Dictionary).duplicate(true)
	_viewer_authorization_by_instance_id.clear()
	_last_reason_code = "card_batch_save_restored"
	return _accepted(_last_reason_code, {"state_fingerprint": state_fingerprint()})


func replay_identity() -> Dictionary:
	return REPLAY_IDENTITY.build(_state)


func debug_snapshot() -> Dictionary:
	return {
		"ruleset_id": STATE.RULESET_ID,
		"production_wired": false,
		"production_cutover": false,
		"phase": str(_state.get("phase", "")),
		"batch_id": str(_state.get("batch_id", "")),
		"window_id": str(_state.get("window_id", "")),
		"rejection_count": _rejection_count,
		"last_reason_code": _last_reason_code,
		"state_fingerprint": state_fingerprint(),
		"mid_resolution_gameplay_wait_count": 0,
		"counter_window_wait_seconds": 0,
		"counter_stack_depth": 0,
		"rng_draw_count": 0,
	}


func _resolve_prebound_targets(submission: Dictionary, projection: Dictionary) -> Dictionary:
	var binding: Dictionary = submission.get("target_binding", {})
	var target_kind := str(binding.get("target_kind", ""))
	var target_ids: Array = binding.get("target_ids", [])
	if target_kind == "none":
		return {"outcome": "COMMITTED", "resolved_target_ids": [], "reason_code": "targetless_card_valid"}
	var legal: Array[String] = []
	for target_id_variant in target_ids:
		var target_id := str(target_id_variant)
		if _target_is_valid(target_id, int(binding.get("target_revision", -1)), projection):
			legal.append(target_id)
	if legal.size() == target_ids.size():
		return {"outcome": "COMMITTED", "resolved_target_ids": legal, "reason_code": "prebound_target_valid"}
	var policy := str(binding.get("target_invalidation_policy", TARGET.DEFAULT_INVALIDATION_POLICY))
	match policy:
		"COMMIT_LEGAL_REMAINDER":
			return {"outcome": "COMMIT_LEGAL_REMAINDER" if not legal.is_empty() else "FIZZLE_NO_EFFECT", "resolved_target_ids": legal, "reason_code": "invalid_targets_removed_without_reselection"}
		"REFUND_BY_AUTHORED_RULE":
			return {"outcome": "REFUND_BY_AUTHORED_RULE", "resolved_target_ids": [], "reason_code": "authored_refund_without_reselection"}
		"DETERMINISTIC_FALLBACK":
			var parameters: Dictionary = binding.get("authored_parameters", {})
			var fallback_ids := PURE.string_array(parameters.get("deterministic_fallback_target_ids", []), true)
			fallback_ids.sort()
			for fallback_id in fallback_ids:
				if _target_is_valid(fallback_id, int(binding.get("target_revision", -1)), projection):
					return {"outcome": "COMMITTED", "resolved_target_ids": [fallback_id], "reason_code": "authored_deterministic_fallback_applied"}
			return {"outcome": "FIZZLE_NO_EFFECT", "resolved_target_ids": [], "reason_code": "deterministic_fallback_unavailable"}
		_:
			return {"outcome": "FIZZLE_NO_EFFECT", "resolved_target_ids": [], "reason_code": "prebound_target_invalid_no_effect"}


func _target_is_valid(target_id: String, expected_revision: int, projection: Dictionary) -> bool:
	var inactive: Array = projection.get("inactive_target_ids", []) if projection.get("inactive_target_ids") is Array else []
	if target_id in inactive:
		return false
	var revisions: Dictionary = projection.get("target_revisions", {}) if projection.get("target_revisions") is Dictionary else {}
	return revisions.has(target_id) and int(revisions.get(target_id, -1)) == expected_revision


func _create_defense_status(submission: Dictionary, protected_target_ids: Array) -> Dictionary:
	var binding: Dictionary = submission.get("target_binding", {})
	var authored: Dictionary = binding.get("authored_parameters", {})
	var status_id := "defense:%s:%s" % [str(_state.get("batch_id", "")), str(submission.get("submission_id", ""))]
	var status := DEFENSE.build(
		status_id,
		str(submission.get("card_instance_id", "")),
		str(submission.get("actor_id", "")),
		protected_target_ids,
		str(authored.get("defense_kind", "shield")),
		str(authored.get("effect_filter", "damage")),
		maxi(0, int(authored.get("reduction_amount", 0))),
		maxi(0, int(authored.get("prevention_count", 0))),
		int(_state.get("batch_revision", 0)),
		str(authored.get("expires_at_batch_id", str(_state.get("batch_id", "")))),
		maxi(0, int(authored.get("expires_at_world_time_usec", 0))),
		maxi(0, int(authored.get("remaining_uses", 1))),
		str(authored.get("visibility_policy", "owner_private")),
		maxi(0, int(authored.get("trigger_refund_amount", authored.get("refund_amount", 0)))),
		maxi(0, int(authored.get("private_trace_count", 0)))
	)
	var validation := DEFENSE.validate(status)
	if not bool(validation.get("valid", false)) or protected_target_ids.is_empty() or int(status.get("remaining_uses", 0)) <= 0:
		return {"created": false, "reason_code": str(validation.get("reason_code", "defense_status_invalid"))}
	var statuses: Array = _state.get("defense_statuses", [])
	statuses.append(status)
	statuses.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return DEFENSE.stable_order_key(left) < DEFENSE.stable_order_key(right))
	_state["defense_statuses"] = statuses
	return {"created": true, "reason_code": "defense_status_created", "defense_status_id": status_id}


func _apply_existing_defenses(submission: Dictionary, resolved_target_ids: Array, initial_effect_amount: int) -> Dictionary:
	if initial_effect_amount <= 0 or resolved_target_ids.is_empty():
		return {"effect_amount": initial_effect_amount, "applications": []}
	var binding: Dictionary = submission.get("target_binding", {})
	var authored: Dictionary = binding.get("authored_parameters", {})
	var effect_kind := str(authored.get("effect_kind", "damage"))
	var statuses: Array = _state.get("defense_statuses", [])
	statuses.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return DEFENSE.stable_order_key(left) < DEFENSE.stable_order_key(right))
	var applications: Array = []
	var amount := initial_effect_amount
	for index in range(statuses.size()):
		var status := (statuses[index] as Dictionary).duplicate(true)
		if not _defense_is_active(status) or not _targets_intersect(status.get("protected_target_ids", []), resolved_target_ids):
			continue
		var effect_filter := str(status.get("effect_filter", ""))
		if effect_filter not in ["*", effect_kind]:
			continue
		var before := amount
		if int(status.get("prevention_count", 0)) > 0:
			amount = 0
			status["prevention_count"] = int(status.get("prevention_count", 0)) - 1
		else:
			amount = maxi(0, amount - int(status.get("reduction_amount", 0)))
		status["remaining_uses"] = maxi(0, int(status.get("remaining_uses", 0)) - 1)
		statuses[index] = status
		applications.append({
			"defense_status_id": str(status.get("defense_status_id", "")),
			"owner_player_id": str(status.get("owner_player_id", "")),
			"source_card_instance_id": str(status.get("source_card_instance_id", "")),
			"effect_kind": effect_kind,
			"amount_before": before,
			"amount_after": amount,
			"remaining_uses": int(status.get("remaining_uses", 0)),
			"refund_amount": int(status.get("trigger_refund_amount", 0)),
			"private_trace_count": int(status.get("private_trace_count", 0)),
		})
		if amount == 0:
			break
	_state["defense_statuses"] = statuses
	_record_private_defense_trigger_receipts(applications, str(submission.get("submission_id", "")))
	return {"effect_amount": amount, "applications": applications}


func _record_private_defense_trigger_receipts(applications: Array, triggering_submission_id: String) -> void:
	var by_actor: Dictionary = _state.get("private_defense_receipts_by_actor", {})
	for application_variant in applications:
		if not (application_variant is Dictionary):
			continue
		var application := application_variant as Dictionary
		var owner_id := str(application.get("owner_player_id", ""))
		if owner_id.is_empty():
			continue
		var rows: Array = by_actor.get(owner_id, []) if by_actor.get(owner_id) is Array else []
		var private_receipt := RECEIPT.private_defense_trigger(
			str(_state.get("batch_id", "")),
			str(_state.get("window_id", "")),
			int(_state.get("current_resolution_index", 0)),
			owner_id,
			str(application.get("defense_status_id", "")),
			str(application.get("source_card_instance_id", "")),
			triggering_submission_id,
			int(application.get("refund_amount", 0)),
			int(application.get("private_trace_count", 0)),
			int(application.get("amount_before", 0)),
			int(application.get("amount_after", 0))
		)
		if not RECEIPT.validate_private_defense_trigger(private_receipt):
			continue
		rows.append(private_receipt)
		by_actor[owner_id] = rows
	_state["private_defense_receipts_by_actor"] = by_actor


func _defense_is_active(status: Dictionary) -> bool:
	if int(status.get("remaining_uses", 0)) <= 0 or int(status.get("active_from_revision", 0)) > int(_state.get("batch_revision", 0)):
		return false
	var expiry_world := int(status.get("expires_at_world_time_usec", 0))
	if expiry_world > 0 and int(_state.get("world_effective_time_usec", 0)) > expiry_world:
		return false
	var expiry_batch := str(status.get("expires_at_batch_id", ""))
	return expiry_batch.is_empty() or _id_sequence(str(_state.get("batch_id", ""))) <= _id_sequence(expiry_batch)


func _prune_expired_defenses() -> void:
	var kept: Array = []
	for status_variant in _state.get("defense_statuses", []) as Array:
		var status := status_variant as Dictionary
		if _defense_is_active(status):
			kept.append(status.duplicate(true))
	_state["defense_statuses"] = kept


func _targets_intersect(left: Variant, right: Array) -> bool:
	if not (left is Array):
		return false
	for target_variant in left as Array:
		if str(target_variant) in right:
			return true
	return false


func _commit_effect_totals(target_ids: Array, effect_amount: int) -> void:
	var totals: Dictionary = _state.get("deterministic_effect_totals_by_target", {})
	for target_id_variant in target_ids:
		var target_id := str(target_id_variant)
		totals[target_id] = int(totals.get(target_id, 0)) + effect_amount
	_state["deterministic_effect_totals_by_target"] = totals


func _submission_source_available(submission: Dictionary) -> bool:
	var inventory := _inventory_for(str(submission.get("actor_id", "")))
	if inventory.is_empty():
		return false
	var pool := str(submission.get("source_pool", ""))
	var instance_id := str(submission.get("card_instance_id", ""))
	var semantic_id := str(submission.get("card_semantic_id", ""))
	var source_revision := int(submission.get("source_revision", -1))
	var items: Array = []
	var id_key := "card_instance_id"
	match pool:
		"normal_hand":
			items = inventory.get("normal_cards", [])
		"commodity_inventory":
			items = inventory.get("commodity_cards", [])
		"bound_action_inventory":
			items = inventory.get("bound_actions", [])
			id_key = "bound_action_id"
		_:
			return false
	for item_variant in items:
		if not (item_variant is Dictionary):
			continue
		var item := item_variant as Dictionary
		if str(item.get(id_key, "")) == instance_id \
				and str(item.get("card_semantic_id", "")) == semantic_id \
				and int(item.get("source_revision", -1)) == source_revision \
				and (pool != "bound_action_inventory" \
					or (int(item.get("charges", 0)) > 0 \
						and int(item.get("cooldown_remaining_phase_time_usec", 0)) == 0)):
			return true
	return false


func _advance_bound_action_cooldowns(delta_usec: int) -> void:
	if delta_usec <= 0:
		return
	var inventories: Dictionary = _state.get("inventories_by_actor", {})
	for actor_id_variant in inventories.keys():
		if not (inventories.get(actor_id_variant) is Dictionary):
			continue
		var inventory := (inventories.get(actor_id_variant, {}) as Dictionary).duplicate(true)
		var actions: Array = []
		for action_variant in inventory.get("bound_actions", []) as Array:
			var action := (action_variant as Dictionary).duplicate(true)
			action["cooldown_remaining_phase_time_usec"] = maxi(
				0,
				int(action.get("cooldown_remaining_phase_time_usec", 0)) - delta_usec
			)
			actions.append(action)
		inventory["bound_actions"] = actions
		inventories[actor_id_variant] = inventory
	_state["inventories_by_actor"] = inventories


func _consume_submission_source(submission: Dictionary, authored: Dictionary) -> void:
	var actor_id := str(submission.get("actor_id", ""))
	var inventory := _inventory_for(actor_id)
	var pool := str(submission.get("source_pool", ""))
	var instance_id := str(submission.get("card_instance_id", ""))
	match pool:
		"normal_hand":
			inventory["normal_cards"] = _without_item(inventory.get("normal_cards", []), "card_instance_id", instance_id)
		"commodity_inventory":
			inventory["commodity_cards"] = _without_item(inventory.get("commodity_cards", []), "card_instance_id", instance_id)
		"bound_action_inventory":
			var actions: Array = []
			for action_variant in inventory.get("bound_actions", []) as Array:
				var action := (action_variant as Dictionary).duplicate(true)
				if str(action.get("bound_action_id", "")) == instance_id:
					action["charges"] = maxi(0, int(action.get("charges", 0)) - 1)
					action["cooldown_remaining_phase_time_usec"] = maxi(0, int(authored.get("cooldown_phase_time_usec", 0)))
				actions.append(action)
			inventory["bound_actions"] = actions
	var inventories: Dictionary = _state.get("inventories_by_actor", {})
	inventories[actor_id] = inventory
	_state["inventories_by_actor"] = inventories


func _without_item(items_variant: Variant, id_key: String, item_id: String) -> Array:
	var result: Array = []
	if not (items_variant is Array):
		return result
	for item_variant in items_variant as Array:
		if item_variant is Dictionary and str((item_variant as Dictionary).get(id_key, "")) == item_id:
			continue
		result.append((item_variant as Dictionary).duplicate(true) if item_variant is Dictionary else item_variant)
	return result


func _inventory_for(actor_id: String) -> Dictionary:
	var inventories: Dictionary = _state.get("inventories_by_actor", {})
	return (inventories.get(actor_id, {}) as Dictionary).duplicate(true) if inventories.get(actor_id) is Dictionary else {}


func _set_card_resolution_state(
	phase: String,
	outcome: String = "",
	receipt_id: String = "",
	target_validation_result: String = "",
	applied_defense_status_ids: Array = []
) -> void:
	var submission_id := str(_state.get("active_resolution_id", ""))
	var locked: Dictionary = _state.get("locked_submissions_by_id", {})
	if submission_id.is_empty() or not (locked.get(submission_id) is Dictionary):
		_state["card_resolution_state"] = {}
		return
	_state["card_resolution_state"] = RESOLUTION.build(
		str(_state.get("batch_id", "")),
		str(_state.get("window_id", "")),
		int(_state.get("current_resolution_index", 0)),
		locked.get(submission_id, {}),
		phase,
		outcome,
		receipt_id,
		target_validation_result,
		applied_defense_status_ids,
		false
	)


func _transition(next_phase: String, reason_code: String) -> void:
	_state["phase"] = next_phase
	_state["batch_revision"] = int(_state.get("batch_revision", 0)) + 1
	var trace: Array = _state.get("phase_trace", [])
	trace.append({
		"event_index": trace.size(),
		"event_kind": "PHASE_TRANSITION",
		"phase": next_phase,
		"reason_code": reason_code,
		"batch_id": str(_state.get("batch_id", "")),
		"window_id": str(_state.get("window_id", "")),
		"batch_revision": int(_state.get("batch_revision", 0)),
		"resolution_index": int(_state.get("current_resolution_index", 0)),
	})
	_state["phase_trace"] = trace


func _bump_revision(reason_code: String) -> void:
	_state["batch_revision"] = int(_state.get("batch_revision", 0)) + 1
	var trace: Array = _state.get("phase_trace", [])
	trace.append({
		"event_index": trace.size(),
		"event_kind": "AUTHORITY_REVISION",
		"phase": str(_state.get("phase", "")),
		"reason_code": reason_code,
		"batch_id": str(_state.get("batch_id", "")),
		"window_id": str(_state.get("window_id", "")),
		"batch_revision": int(_state.get("batch_revision", 0)),
		"resolution_index": int(_state.get("current_resolution_index", 0)),
	})
	_state["phase_trace"] = trace


func _batch_id(sequence: int) -> String:
	return "card-batch:%06d" % sequence


func _window_id(sequence: int) -> String:
	return "card-window:%06d" % sequence


func _id_sequence(value: String) -> int:
	var parts := value.split(":")
	return int(parts[-1]) if not parts.is_empty() else -1


func _accepted(reason_code: String, extra: Dictionary = {}) -> Dictionary:
	_last_reason_code = reason_code
	var result := {"accepted": true, "reason_code": reason_code}
	for key in extra.keys():
		result[key] = extra.get(key)
	return result


func _rejected(reason_code: String) -> Dictionary:
	_rejection_count += 1
	_last_reason_code = reason_code
	return {"accepted": false, "reason_code": reason_code}
