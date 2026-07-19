@tool
extends Node
class_name PlayerHandInteractionRuntimeService

const STATUS_READY := "ready"
const STATUS_REJECTED := "rejected"
const KIND_DISRUPT := "player_hand_disrupt"
const KIND_STEAL := "player_hand_steal"

var _inventory_service: Node = null
var _configured := false
var _ordinary_hand_limit := 0
var _maximum_card_rank := 0
var _plan_count := 0
var _commit_attempt_count := 0
var _committed_count := 0
var _rejected_count := 0
var _last_kind := ""
var _last_reason := ""
var _last_result_summary: Dictionary = {}


func set_inventory_service(service: Node) -> void:
	_inventory_service = service


func configure(_config: Dictionary = {}) -> void:
	var inventory_debug := _inventory_debug_snapshot()
	_ordinary_hand_limit = maxi(0, int(inventory_debug.get("ordinary_hand_limit", 0)))
	_maximum_card_rank = maxi(0, int(inventory_debug.get("maximum_card_rank", 0)))
	_configured = _inventory_service != null and bool(inventory_debug.get("service_ready", false)) and _ordinary_hand_limit > 0 and _maximum_card_rank > 0
	reset_state()


func reset_state() -> void:
	_plan_count = 0
	_commit_attempt_count = 0
	_committed_count = 0
	_rejected_count = 0
	_last_kind = ""
	_last_reason = ""
	_last_result_summary = {}


func capture_runtime_checkpoint() -> Dictionary:
	return {"schema_version": 1, "plan_count": _plan_count, "commit_attempt_count": _commit_attempt_count, "committed_count": _committed_count, "rejected_count": _rejected_count, "last_kind": _last_kind, "last_reason": _last_reason, "last_result_summary": _last_result_summary.duplicate(true)}


func restore_runtime_checkpoint(checkpoint: Dictionary) -> Dictionary:
	if int(checkpoint.get("schema_version", 0)) != 1 or not (checkpoint.get("last_result_summary") is Dictionary):
		return {"restored": false, "reason_code": "hand_interaction_checkpoint_invalid"}
	_plan_count = int(checkpoint.get("plan_count", 0))
	_commit_attempt_count = int(checkpoint.get("commit_attempt_count", 0))
	_committed_count = int(checkpoint.get("committed_count", 0))
	_rejected_count = int(checkpoint.get("rejected_count", 0))
	_last_kind = str(checkpoint.get("last_kind", ""))
	_last_reason = str(checkpoint.get("last_reason", ""))
	_last_result_summary = (checkpoint.get("last_result_summary", {}) as Dictionary).duplicate(true)
	return {"restored": true, "reason_code": "hand_interaction_checkpoint_restored"}


func plan_interaction(request: Dictionary) -> Dictionary:
	return _plan_interaction(request, true)


func commit_interaction(actor_state: Dictionary, target_state: Dictionary, current_facts: Dictionary, plan: Dictionary) -> Dictionary:
	_commit_attempt_count += 1
	if not _configured or not _is_data_only(actor_state) or not _is_data_only(target_state) or not _is_data_only(current_facts) or not _is_data_only(plan):
		return _commit_rejection("invalid_commit_request")
	var current_plan := _plan_interaction(current_facts, false)
	if not _plans_match(plan, current_plan):
		return _commit_rejection("interaction_drift")
	var selected_slots: Array = plan.get("selected_slots", []) if plan.get("selected_slots", []) is Array else []
	if not _selection_matches_plan(selected_slots, current_plan):
		return _commit_rejection("invalid_slot_selection")
	var catalog: Dictionary = current_facts.get("card_catalog", {}) if current_facts.get("card_catalog", {}) is Dictionary else {}
	var after_actor := actor_state.duplicate(true)
	var after_target := target_state.duplicate(true)
	var actor_before_count := _counted_hand_size(after_actor, catalog)
	var target_before_count := _counted_hand_size(after_target, catalog)
	var private_intents: Array = []
	var removed_count := 0
	var transferred_count := 0
	var converted_count := 0
	var locked_count := 0
	var mutation_count := 0
	var operation_count := int(current_plan.get("operation_count", 0))
	var interaction_kind := str(current_plan.get("interaction_kind", ""))
	var source_label := str(current_plan.get("source_label", ""))
	for selection_index in range(operation_count):
		var target_slot := int(selected_slots[selection_index])
		if interaction_kind == KIND_DISRUPT:
			var remove_result := _commit_remove(after_target, target_slot, catalog)
			if not bool(remove_result.get("committed", false)):
				return _commit_rejection("remove_commit_failed")
			removed_count += 1
			mutation_count += 1
			private_intents.append({
				"intent_kind": "target_card_lost",
				"recipient_role": "target",
				"card_id": str(remove_result.get("removed_card_id", "")),
				"source_label": source_label,
			})
		else:
			var transfer_result := _commit_transfer(after_actor, after_target, target_slot, catalog)
			if not bool(transfer_result.get("committed", false)):
				return _commit_rejection("transfer_commit_failed")
			mutation_count += 1
			var outcome := str(transfer_result.get("outcome", ""))
			var transferred_card_id := str(transfer_result.get("removed_card_id", ""))
			private_intents.append({
				"intent_kind": "target_card_lost",
				"recipient_role": "target",
				"card_id": transferred_card_id,
				"source_label": source_label,
			})
			if outcome == "converted_to_remove":
				converted_count += 1
			else:
				transferred_count += 1
				private_intents.append({
					"intent_kind": "actor_card_received",
					"recipient_role": "actor",
					"card_id": transferred_card_id,
					"source_label": source_label,
					"outcome": outcome,
				})
	var lock_seconds := float(current_plan.get("lock_seconds", 0.0))
	if bool(current_plan.get("lock_planned", false)):
		var lock_slot := int(selected_slots[operation_count])
		var lock_result := _commit_lock(after_target, lock_slot, lock_seconds, catalog)
		if not bool(lock_result.get("committed", false)):
			return _commit_rejection("lock_commit_failed")
		locked_count = 1
		mutation_count += 1
		private_intents.append({
			"intent_kind": "target_card_locked",
			"recipient_role": "target",
			"card_id": str(lock_result.get("locked_card_id", "")),
			"duration_seconds": lock_seconds,
			"source_label": source_label,
		})
	var actor_cash_before := int(after_actor.get("cash", 0))
	var target_cash_before := int(after_target.get("cash", 0))
	var penalty_requested := int(current_plan.get("target_cash_penalty", 0))
	var penalty_paid := 0
	if interaction_kind == KIND_DISRUPT and penalty_requested > 0:
		penalty_paid = mini(penalty_requested, maxi(0, target_cash_before))
		after_target["cash"] = target_cash_before - penalty_paid
		if penalty_paid > 0:
			private_intents.append({
				"intent_kind": "target_card_spend",
				"recipient_role": "target",
				"amount": penalty_paid,
				"label": "直接互动重组成本",
				"source_label": source_label,
			})
	var compensation_rule := int(current_plan.get("steal_fail_cash", 0))
	var compensation_paid := compensation_rule if interaction_kind == KIND_STEAL and (converted_count > 0 or transferred_count <= 0) else 0
	if compensation_paid > 0:
		after_actor["cash"] = actor_cash_before + compensation_paid
		private_intents.append({
			"intent_kind": "actor_card_income",
			"recipient_role": "actor",
			"amount": compensation_paid,
			"label": source_label,
			"detail": "牵取失败补偿",
		})
	var resolution_success := removed_count > 0 or locked_count > 0 or penalty_requested > 0
	if interaction_kind == KIND_STEAL:
		resolution_success = transferred_count > 0 or converted_count > 0 or locked_count > 0
	var actor_after_count := _counted_hand_size(after_actor, catalog)
	var target_after_count := _counted_hand_size(after_target, catalog)
	var public_intents: Array = []
	var callout_intents: Array = []
	if resolution_success:
		public_intents.append({
			"intent_kind": "interaction_summary",
			"interaction_kind": interaction_kind,
			"source_label": source_label,
			"target_player_index": int(current_plan.get("target_player_index", -1)),
			"removed_count": removed_count,
			"transferred_count": transferred_count,
			"converted_count": converted_count,
			"locked_count": locked_count,
			"target_cash_penalty": penalty_requested,
		})
		callout_intents.append({
			"intent_kind": "interaction_callout",
			"interaction_kind": interaction_kind,
			"source_label": source_label,
			"target_player_index": int(current_plan.get("target_player_index", -1)),
		})
	actor_state.clear()
	actor_state.merge(after_actor, true)
	target_state.clear()
	target_state.merge(after_target, true)
	var result := {
		"committed": true,
		"reason": "committed",
		"resolution_success": resolution_success,
		"interaction_kind": interaction_kind,
		"source_label": source_label,
		"requested_count": int(current_plan.get("requested_count", 0)),
		"removed_count": removed_count,
		"transferred_count": transferred_count,
		"converted_count": converted_count,
		"locked_count": locked_count,
		"actor_cash_delta": int(after_actor.get("cash", 0)) - actor_cash_before,
		"target_cash_delta": int(after_target.get("cash", 0)) - target_cash_before,
		"source_hand_delta": actor_after_count - actor_before_count,
		"target_hand_delta": target_after_count - target_before_count,
		"penalty_requested": penalty_requested,
		"penalty_paid": penalty_paid,
		"compensation_paid": compensation_paid,
		"mutation_count": mutation_count,
		"private_event_intents": private_intents,
		"public_event_intents": public_intents,
		"action_callout_intents": callout_intents,
		"post_commit_hooks": [],
	}
	return _commit_success(result)


func debug_snapshot() -> Dictionary:
	return {
		"service_ready": _configured,
		"service_authoritative": _configured,
		"interaction_orchestration_authority": _configured,
		"cash_adjustment_authority": _configured,
		"event_intent_authority": _configured,
		"inventory_mutation_authority": false,
		"inventory_service_ready": bool(_inventory_debug_snapshot().get("service_ready", false)),
		"ordinary_hand_limit": _ordinary_hand_limit,
		"maximum_card_rank": _maximum_card_rank,
		"plan_count": _plan_count,
		"commit_attempt_count": _commit_attempt_count,
		"committed_count": _committed_count,
		"rejected_count": _rejected_count,
		"last_kind": _last_kind,
		"last_reason": _last_reason,
		"last_result_summary": _last_result_summary.duplicate(true),
		"legacy_main_orchestration_fallback_used": false,
	}


func _plan_interaction(request: Dictionary, count_plan: bool) -> Dictionary:
	if count_plan:
		_plan_count += 1
	if not _configured:
		return _plan_rejection("service_not_configured")
	if not _is_data_only(request):
		return _plan_rejection("invalid_request")
	var actor_index := int(request.get("actor_player_index", -1))
	var target_index := int(request.get("target_player_index", -1))
	var skill: Dictionary = request.get("skill", {}) if request.get("skill", {}) is Dictionary else {}
	var interaction_kind := str(skill.get("kind", ""))
	if actor_index < 0 or target_index < 0 or actor_index == target_index:
		return _plan_rejection("invalid_target")
	if not [KIND_DISRUPT, KIND_STEAL].has(interaction_kind):
		return _plan_rejection("unsupported_interaction")
	var target_inventory: Dictionary = request.get("target_inventory", {}) if request.get("target_inventory", {}) is Dictionary else {}
	var actor_inventory: Dictionary = request.get("actor_inventory", {}) if request.get("actor_inventory", {}) is Dictionary else {}
	if target_inventory.is_empty() or actor_inventory.is_empty():
		return _plan_rejection("missing_inventory")
	var candidate_variant: Variant = _inventory_service.call("discardable_slots", target_inventory)
	var candidate_slots: Array = (candidate_variant as Array).duplicate() if candidate_variant is Array else []
	var requested_count := maxi(1, int(skill.get("hand_discard_count", 1))) if interaction_kind == KIND_DISRUPT else maxi(1, int(skill.get("hand_steal_count", 1)))
	var operation_count := mini(requested_count, candidate_slots.size())
	var lock_seconds := maxf(0.0, float(skill.get("hand_lock_seconds", 0.0)))
	var lock_planned := lock_seconds > 0.0 and candidate_slots.size() > operation_count
	return {
		"status": STATUS_READY,
		"ready": true,
		"reason": "ready",
		"interaction_kind": interaction_kind,
		"source_label": str(skill.get("name", "星链拆解" if interaction_kind == KIND_DISRUPT else "影仓牵引")),
		"actor_player_index": actor_index,
		"target_player_index": target_index,
		"requested_count": requested_count,
		"operation_count": operation_count,
		"candidate_slots": candidate_slots,
		"lock_seconds": lock_seconds,
		"lock_planned": lock_planned,
		"selection_draw_count": operation_count + (1 if lock_planned else 0),
		"target_cash_penalty": maxi(0, int(skill.get("target_cash_penalty", 0))),
		"steal_fail_cash": maxi(0, int(skill.get("steal_fail_cash", 0))),
		"request_fingerprint": _request_fingerprint(request),
	}


func _commit_remove(target_state: Dictionary, target_slot: int, catalog: Dictionary) -> Dictionary:
	var request := {"inventory": _compose_inventory(target_state, catalog), "slot_index": target_slot}
	var plan_variant: Variant = _inventory_service.call("plan_remove", request)
	var plan: Dictionary = plan_variant if plan_variant is Dictionary else {}
	if str(plan.get("status", "")) != STATUS_READY:
		return {"committed": false, "reason": str(plan.get("reason", "remove_plan_rejected"))}
	var result_variant: Variant = _inventory_service.call("commit_remove", target_state, request, plan)
	return (result_variant as Dictionary).duplicate(true) if result_variant is Dictionary else {"committed": false, "reason": "remove_result_missing"}


func _commit_lock(target_state: Dictionary, target_slot: int, duration_seconds: float, catalog: Dictionary) -> Dictionary:
	var request := {"inventory": _compose_inventory(target_state, catalog), "slot_index": target_slot, "duration_seconds": duration_seconds}
	var plan_variant: Variant = _inventory_service.call("plan_lock", request)
	var plan: Dictionary = plan_variant if plan_variant is Dictionary else {}
	if str(plan.get("status", "")) != STATUS_READY:
		return {"committed": false, "reason": str(plan.get("reason", "lock_plan_rejected"))}
	var result_variant: Variant = _inventory_service.call("commit_lock", target_state, request, plan)
	return (result_variant as Dictionary).duplicate(true) if result_variant is Dictionary else {"committed": false, "reason": "lock_result_missing"}


func _commit_transfer(actor_state: Dictionary, target_state: Dictionary, target_slot: int, catalog: Dictionary) -> Dictionary:
	var target_slots: Array = target_state.get("slots", []) if target_state.get("slots", []) is Array else []
	if target_slot < 0 or target_slot >= target_slots.size() or not (target_slots[target_slot] is Dictionary):
		return {"committed": false, "reason": "target_card_missing"}
	var incoming_card: Dictionary = (target_slots[target_slot] as Dictionary).duplicate(true)
	var incoming_card_id := str(incoming_card.get("name", ""))
	var request := {
		"source_inventory": _compose_inventory(actor_state, catalog, incoming_card, incoming_card_id),
		"target_inventory": _compose_inventory(target_state, catalog),
		"target_slot": target_slot,
		"failure_policy": "convert_to_remove",
	}
	var plan_variant: Variant = _inventory_service.call("plan_transfer", request)
	var plan: Dictionary = plan_variant if plan_variant is Dictionary else {}
	if str(plan.get("status", "")) != STATUS_READY:
		return {"committed": false, "reason": str(plan.get("reason", "transfer_plan_rejected"))}
	var result_variant: Variant = _inventory_service.call("commit_transfer", actor_state, target_state, request, plan)
	return (result_variant as Dictionary).duplicate(true) if result_variant is Dictionary else {"committed": false, "reason": "transfer_result_missing"}


func _compose_inventory(player_state: Dictionary, catalog: Dictionary, incoming_card: Dictionary = {}, incoming_card_id: String = "") -> Dictionary:
	var slot_facts: Array = []
	var slots: Array = player_state.get("slots", []) if player_state.get("slots", []) is Array else []
	for slot_index in range(slots.size()):
		var card_variant: Variant = slots[slot_index]
		if not (card_variant is Dictionary):
			slot_facts.append({"slot_index": slot_index, "occupied": false})
			continue
		var card: Dictionary = card_variant
		var card_id := str(card.get("name", ""))
		var metadata := _card_metadata(catalog, card_id)
		slot_facts.append({
			"slot_index": slot_index,
			"occupied": true,
			"card_id": card_id,
			"family": str(metadata.get("family", "")),
			"rank": maxi(1, int(metadata.get("rank", card.get("rank", 1)))),
			"counts_toward_hand_limit": bool(metadata.get("counts_toward_hand_limit", true)),
			"queued_for_resolution": bool(card.get("queued_for_resolution", false)),
			"lock_left": float(card.get("lock_left", 0.0)),
			"next_upgrade_id": str(metadata.get("next_upgrade_id", "")),
			"next_upgrade_card": (metadata.get("next_upgrade_card", {}) as Dictionary).duplicate(true) if metadata.get("next_upgrade_card", {}) is Dictionary else {},
		})
	var incoming_metadata := _card_metadata(catalog, incoming_card_id)
	return {
		"valid": not incoming_card_id.is_empty() and not incoming_card.is_empty(),
		"incoming_card_id": incoming_card_id,
		"incoming_card": incoming_card.duplicate(true),
		"incoming_family": str(incoming_metadata.get("family", "")),
		"incoming_rank": maxi(1, int(incoming_metadata.get("rank", incoming_card.get("rank", 1)))) if not incoming_card.is_empty() else 0,
		"incoming_counts_toward_hand_limit": bool(incoming_metadata.get("counts_toward_hand_limit", true)),
		"incoming_allows_family_upgrade": true,
		"counted_hand_size": _counted_hand_size(player_state, catalog),
		"hand_limit": _ordinary_hand_limit,
		"discard_slot": -1,
		"slots": slot_facts,
	}


func _counted_hand_size(player_state: Dictionary, catalog: Dictionary) -> int:
	var count := 0
	var slots: Array = player_state.get("slots", []) if player_state.get("slots", []) is Array else []
	for card_variant in slots:
		if not (card_variant is Dictionary):
			continue
		var card: Dictionary = card_variant
		if bool(_card_metadata(catalog, str(card.get("name", ""))).get("counts_toward_hand_limit", true)):
			count += 1
	return count


func _card_metadata(catalog: Dictionary, card_id: String) -> Dictionary:
	var value: Variant = catalog.get(card_id, {})
	return value if value is Dictionary else {}


func _plans_match(expected: Dictionary, current: Dictionary) -> bool:
	for key in ["status", "interaction_kind", "actor_player_index", "target_player_index", "requested_count", "operation_count", "candidate_slots", "lock_seconds", "lock_planned", "selection_draw_count", "target_cash_penalty", "steal_fail_cash", "request_fingerprint"]:
		if expected.get(key) != current.get(key):
			return false
	return str(current.get("status", "")) == STATUS_READY


func _selection_matches_plan(selected_slots: Array, plan: Dictionary) -> bool:
	if selected_slots.size() != int(plan.get("selection_draw_count", 0)):
		return false
	var candidates: Array = (plan.get("candidate_slots", []) as Array).duplicate() if plan.get("candidate_slots", []) is Array else []
	for slot_variant in selected_slots:
		var slot_index := int(slot_variant)
		if not candidates.has(slot_index):
			return false
		candidates.erase(slot_index)
	return true


func _request_fingerprint(request: Dictionary) -> String:
	var source := {
		"actor_player_index": int(request.get("actor_player_index", -1)),
		"target_player_index": int(request.get("target_player_index", -1)),
		"skill": request.get("skill", {}),
		"actor_inventory": request.get("actor_inventory", {}),
		"target_inventory": request.get("target_inventory", {}),
		"card_catalog": request.get("card_catalog", {}),
	}
	return str(hash(JSON.stringify(source)))


func _plan_rejection(reason: String) -> Dictionary:
	return {
		"status": STATUS_REJECTED,
		"ready": false,
		"reason": reason,
		"interaction_kind": "",
		"candidate_slots": [],
		"selection_draw_count": 0,
	}


func _commit_success(result: Dictionary) -> Dictionary:
	_committed_count += 1
	_last_kind = str(result.get("interaction_kind", ""))
	_last_reason = "committed"
	_last_result_summary = {
		"interaction_kind": _last_kind,
		"resolution_success": bool(result.get("resolution_success", false)),
		"removed_count": int(result.get("removed_count", 0)),
		"transferred_count": int(result.get("transferred_count", 0)),
		"converted_count": int(result.get("converted_count", 0)),
		"locked_count": int(result.get("locked_count", 0)),
		"penalty_paid": int(result.get("penalty_paid", 0)),
		"compensation_paid": int(result.get("compensation_paid", 0)),
	}
	return result


func _commit_rejection(reason: String) -> Dictionary:
	_rejected_count += 1
	_last_reason = reason
	_last_result_summary = {"committed": false, "reason": reason}
	return {
		"committed": false,
		"reason": reason,
		"resolution_success": false,
		"removed_count": 0,
		"transferred_count": 0,
		"converted_count": 0,
		"locked_count": 0,
		"actor_cash_delta": 0,
		"target_cash_delta": 0,
		"source_hand_delta": 0,
		"target_hand_delta": 0,
		"mutation_count": 0,
		"private_event_intents": [],
		"public_event_intents": [],
		"action_callout_intents": [],
		"post_commit_hooks": [],
	}


func _inventory_debug_snapshot() -> Dictionary:
	if _inventory_service != null and _inventory_service.has_method("debug_snapshot"):
		var value: Variant = _inventory_service.call("debug_snapshot")
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {}


func _is_data_only(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item in value:
			if not _is_data_only(item):
				return false
		return true
	if value is Dictionary:
		for key in value.keys():
			if not _is_data_only(key) or not _is_data_only(value[key]):
				return false
		return true
	return false
