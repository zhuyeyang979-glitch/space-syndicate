@tool
extends Node
class_name CardInventoryRuntimeService

const STATUS_READY := "ready"
const STATUS_REQUIRES_DISCARD := "requires_discard"
const STATUS_REJECTED := "rejected"
const FAILURE_POLICY_CONVERT_TO_REMOVE := "convert_to_remove"

var _ruleset_id := ""
var _ordinary_hand_limit := 0
var _maximum_card_rank := 0
var _configured := false
var _receive_plan_count := 0
var _remove_plan_count := 0
var _lock_plan_count := 0
var _transfer_plan_count := 0
var _queue_commit_plan_count := 0
var _queue_committed_count := 0
var _commit_attempt_count := 0
var _committed_count := 0
var _rejected_count := 0
var _last_reason := ""
var _last_operation := ""
var _last_outcome := ""


func configure(ruleset_snapshot: Dictionary) -> void:
	_ruleset_id = str(ruleset_snapshot.get("ruleset_id", ""))
	var rules_variant: Variant = ruleset_snapshot.get("card_inventory", {})
	var rules: Dictionary = rules_variant if rules_variant is Dictionary else {}
	_ordinary_hand_limit = maxi(0, int(rules.get("ordinary_hand_limit", 0)))
	_maximum_card_rank = maxi(0, int(rules.get("maximum_card_rank", 0)))
	_configured = _ruleset_id == "v0.4" and _ordinary_hand_limit > 0 and _maximum_card_rank > 0
	reset_state()


func reset_state() -> void:
	_receive_plan_count = 0
	_remove_plan_count = 0
	_lock_plan_count = 0
	_transfer_plan_count = 0
	_queue_commit_plan_count = 0
	_queue_committed_count = 0
	_commit_attempt_count = 0
	_committed_count = 0
	_rejected_count = 0
	_last_reason = ""
	_last_operation = ""
	_last_outcome = ""


func capture_runtime_checkpoint() -> Dictionary:
	return {"schema_version": 1, "receive_plan_count": _receive_plan_count, "remove_plan_count": _remove_plan_count, "lock_plan_count": _lock_plan_count, "transfer_plan_count": _transfer_plan_count, "queue_commit_plan_count": _queue_commit_plan_count, "queue_committed_count": _queue_committed_count, "commit_attempt_count": _commit_attempt_count, "committed_count": _committed_count, "rejected_count": _rejected_count, "last_reason": _last_reason, "last_operation": _last_operation, "last_outcome": _last_outcome}


func restore_runtime_checkpoint(checkpoint: Dictionary) -> Dictionary:
	if int(checkpoint.get("schema_version", 0)) != 1:
		return {"restored": false, "reason_code": "card_inventory_checkpoint_invalid"}
	_receive_plan_count = int(checkpoint.get("receive_plan_count", 0))
	_remove_plan_count = int(checkpoint.get("remove_plan_count", 0))
	_lock_plan_count = int(checkpoint.get("lock_plan_count", 0))
	_transfer_plan_count = int(checkpoint.get("transfer_plan_count", 0))
	_queue_commit_plan_count = int(checkpoint.get("queue_commit_plan_count", 0))
	_queue_committed_count = int(checkpoint.get("queue_committed_count", 0))
	_commit_attempt_count = int(checkpoint.get("commit_attempt_count", 0))
	_committed_count = int(checkpoint.get("committed_count", 0))
	_rejected_count = int(checkpoint.get("rejected_count", 0))
	_last_reason = str(checkpoint.get("last_reason", ""))
	_last_operation = str(checkpoint.get("last_operation", ""))
	_last_outcome = str(checkpoint.get("last_outcome", ""))
	return {"restored": true, "reason_code": "card_inventory_checkpoint_restored"}


func plan_receive(request: Dictionary) -> Dictionary:
	return _plan_receive(request, true)


func commit_receive(player_state: Dictionary, current_facts: Dictionary, plan: Dictionary) -> Dictionary:
	_commit_attempt_count += 1
	if not _configured or not _is_data_only(player_state) or not _is_data_only(current_facts) or not _is_data_only(plan):
		return _commit_rejection("invalid_receive_commit_request")
	var current_plan := _plan_receive(current_facts, false)
	if not _receive_plans_match(plan, current_plan) or not _player_matches_inventory(player_state, current_facts):
		return _commit_rejection("inventory_drift")
	var after_player := player_state.duplicate(true)
	if not _apply_receive_operation(after_player, current_plan):
		return _commit_rejection("inventory_commit_failed")
	player_state.clear()
	player_state.merge(after_player, true)
	return _commit_success(str(current_plan.get("operation", "")), str(current_plan.get("operation", "")), {
		"hand_count_delta": int(current_plan.get("hand_count_delta", 0)),
		"slot_change_kind": str(current_plan.get("slot_change_kind", "")),
		"target_slot": int(current_plan.get("target_slot", -1)),
	})


func discardable_slots(current_facts: Dictionary) -> Array:
	var result: Array = []
	if not _configured or not _is_data_only(current_facts):
		return result
	var slots: Array = current_facts.get("slots", []) if current_facts.get("slots", []) is Array else []
	for slot_variant in slots:
		if not (slot_variant is Dictionary):
			continue
		var slot_facts: Dictionary = slot_variant
		if not bool(slot_facts.get("occupied", false)):
			continue
		if not bool(slot_facts.get("counts_toward_hand_limit", false)):
			continue
		if bool(slot_facts.get("queued_for_resolution", false)):
			continue
		if float(slot_facts.get("lock_left", 0.0)) > 0.0:
			continue
		result.append(int(slot_facts.get("slot_index", -1)))
	return result


func plan_remove(request: Dictionary) -> Dictionary:
	return _plan_remove(request, true)


func commit_remove(player_state: Dictionary, current_facts: Dictionary, plan: Dictionary) -> Dictionary:
	_commit_attempt_count += 1
	if not _configured or not _is_data_only(player_state) or not _is_data_only(current_facts) or not _is_data_only(plan):
		return _commit_rejection("invalid_remove_commit_request")
	var current_plan := _plan_remove(current_facts, false)
	var inventory := _request_inventory(current_facts)
	if not _mutation_plans_match(plan, current_plan) or not _player_matches_inventory(player_state, inventory):
		return _commit_rejection("inventory_drift")
	var after_player := player_state.duplicate(true)
	var removed := _remove_slot(after_player, int(current_plan.get("target_slot", -1)))
	if removed.is_empty():
		return _commit_rejection("remove_commit_failed")
	player_state.clear()
	player_state.merge(after_player, true)
	var result := _commit_success("remove", "removed", {
		"hand_count_delta": -1 if bool(current_plan.get("counted", true)) else 0,
		"slot_change_kind": "remove",
		"target_slot": int(current_plan.get("target_slot", -1)),
	})
	result["removed_card_id"] = str(removed.get("name", ""))
	result["removed_card"] = removed.duplicate(true)
	return result


func plan_lock(request: Dictionary) -> Dictionary:
	return _plan_lock(request, true)


func commit_lock(player_state: Dictionary, current_facts: Dictionary, plan: Dictionary) -> Dictionary:
	_commit_attempt_count += 1
	if not _configured or not _is_data_only(player_state) or not _is_data_only(current_facts) or not _is_data_only(plan):
		return _commit_rejection("invalid_lock_commit_request")
	var current_plan := _plan_lock(current_facts, false)
	var inventory := _request_inventory(current_facts)
	if not _mutation_plans_match(plan, current_plan) or not _player_matches_inventory(player_state, inventory):
		return _commit_rejection("inventory_drift")
	var after_player := player_state.duplicate(true)
	var target_slot := int(current_plan.get("target_slot", -1))
	var duration_seconds := float(current_plan.get("duration_seconds", 0.0))
	var locked_card := _lock_slot(after_player, target_slot, duration_seconds)
	if locked_card.is_empty():
		return _commit_rejection("lock_commit_failed")
	player_state.clear()
	player_state.merge(after_player, true)
	var result := _commit_success("lock", "locked", {
		"hand_count_delta": 0,
		"slot_change_kind": "lock",
		"target_slot": target_slot,
		"duration_seconds": duration_seconds,
	})
	result["locked_card_id"] = str(locked_card.get("name", ""))
	return result


func plan_transfer(request: Dictionary) -> Dictionary:
	return _plan_transfer(request, true)


func commit_transfer(source_state: Dictionary, target_state: Dictionary, current_facts: Dictionary, plan: Dictionary) -> Dictionary:
	_commit_attempt_count += 1
	if not _configured or not _is_data_only(source_state) or not _is_data_only(target_state) or not _is_data_only(current_facts) or not _is_data_only(plan):
		return _commit_rejection("invalid_transfer_commit_request")
	var current_plan := _plan_transfer(current_facts, false)
	var source_inventory: Dictionary = current_facts.get("source_inventory", {}) if current_facts.get("source_inventory", {}) is Dictionary else {}
	var target_inventory: Dictionary = current_facts.get("target_inventory", {}) if current_facts.get("target_inventory", {}) is Dictionary else {}
	if not _transfer_plans_match(plan, current_plan):
		return _commit_rejection("inventory_drift")
	if not _player_matches_inventory(source_state, source_inventory) or not _player_matches_inventory(target_state, target_inventory):
		return _commit_rejection("inventory_drift")
	var after_source := source_state.duplicate(true)
	var after_target := target_state.duplicate(true)
	var target_slot := int(current_plan.get("target_slot", -1))
	var removed := _remove_slot(after_target, target_slot)
	if removed.is_empty():
		return _commit_rejection("transfer_remove_failed")
	var outcome := str(current_plan.get("outcome", ""))
	var source_receive_plan: Dictionary = current_plan.get("source_receive_plan", {}) if current_plan.get("source_receive_plan", {}) is Dictionary else {}
	if outcome != "converted_to_remove":
		if not _apply_receive_operation(after_source, source_receive_plan):
			return _commit_rejection("transfer_receive_failed")
	source_state.clear()
	source_state.merge(after_source, true)
	target_state.clear()
	target_state.merge(after_target, true)
	var result := _commit_success("transfer", outcome, {
		"hand_count_delta": int(source_receive_plan.get("hand_count_delta", 0)) if outcome != "converted_to_remove" else 0,
		"target_hand_count_delta": -1,
		"slot_change_kind": outcome,
		"target_slot": target_slot,
		"source_target_slot": int(source_receive_plan.get("target_slot", -1)),
	})
	result["removed_card_id"] = str(removed.get("name", ""))
	result["removed_card"] = removed.duplicate(true)
	return result


func plan_queue_commit(request: Dictionary) -> Dictionary:
	return _plan_queue_commit(request, true)


func commit_queue_commit(player_state: Dictionary, current_facts: Dictionary, plan: Dictionary) -> Dictionary:
	_commit_attempt_count += 1
	if not _configured or not _is_data_only(player_state) or not _is_data_only(current_facts) or not _is_data_only(plan):
		return _commit_rejection("invalid_queue_commit_request")
	var current_plan := _plan_queue_commit(current_facts, false)
	var inventory: Dictionary = current_facts.get("inventory", {}) if current_facts.get("inventory", {}) is Dictionary else {}
	if not _queue_commit_plans_match(plan, current_plan) or not _player_matches_inventory(player_state, inventory):
		return _commit_rejection("inventory_drift")
	var target_slot := int(current_plan.get("target_slot", -1))
	var slots: Array = player_state.get("slots", []) if player_state.get("slots", []) is Array else []
	if target_slot < 0 or target_slot >= slots.size() or not (slots[target_slot] is Dictionary):
		return _commit_rejection("queue_slot_missing")
	var after_player := player_state.duplicate(true)
	var after_slots: Array = (after_player.get("slots", []) as Array).duplicate(true)
	if bool(current_plan.get("consumed_on_queue", false)):
		after_slots[target_slot] = null
	else:
		after_slots[target_slot] = (current_plan.get("queued_skill", {}) as Dictionary).duplicate(true)
	after_player["slots"] = after_slots
	player_state.clear()
	player_state.merge(after_player, true)
	_queue_committed_count += 1
	_last_reason = "committed"
	_last_operation = "queue_commit"
	_last_outcome = "consumed" if bool(current_plan.get("consumed_on_queue", false)) else "marked_queued"
	return {
		"committed": true,
		"reason": "committed",
		"operation": "queue_commit",
		"outcome": _last_outcome,
		"hand_count_delta": -1 if bool(current_plan.get("consumed_on_queue", false)) and bool(current_plan.get("counts_toward_hand_limit", true)) else 0,
		"slot_change_kind": "consume_on_queue" if bool(current_plan.get("consumed_on_queue", false)) else "mark_queued",
		"target_slot": target_slot,
		"target_hand_count_delta": 0,
		"source_target_slot": -1,
		"duration_seconds": 0.0,
		"mutation_count": 1,
	}


func invalidate_bound_military_commands(player_state: Dictionary, unit_uid: int, reason: String) -> Dictionary:
	if not _configured or unit_uid <= 0 or not _is_data_only(player_state):
		return {"committed": false, "reason": "invalid_military_command_invalidation", "invalidated_count": 0}
	var after_player := player_state.duplicate(true)
	var slots: Array = after_player.get("slots", []) if after_player.get("slots", []) is Array else []
	var invalidated_count := 0
	for slot_index in range(slots.size()):
		if not (slots[slot_index] is Dictionary):
			continue
		var skill := slots[slot_index] as Dictionary
		if int(skill.get("bound_military_uid", 0)) != unit_uid:
			continue
		skill["bound_military_uid"] = -1
		skill["lock_left"] = maxf(float(skill.get("lock_left", 0.0)), 9999.0)
		skill["text"] = "%s（%s）" % [str(skill.get("text", "")), reason]
		slots[slot_index] = skill
		invalidated_count += 1
	after_player["slots"] = slots
	player_state.clear()
	player_state.merge(after_player, true)
	return {
		"committed": true,
		"reason": "committed",
		"operation": "invalidate_bound_military_commands",
		"unit_uid": unit_uid,
		"invalidated_count": invalidated_count,
	}


func inventory_fingerprint(current_facts: Dictionary) -> Array:
	var result: Array = []
	var slots: Array = current_facts.get("slots", []) if current_facts.get("slots", []) is Array else []
	for slot_variant in slots:
		if not (slot_variant is Dictionary):
			continue
		var slot_facts: Dictionary = slot_variant
		if not bool(slot_facts.get("occupied", false)):
			continue
		result.append({
			"family_hash": str(hash(str(slot_facts.get("family", "")))),
			"rank": int(slot_facts.get("rank", 0)),
			"queued": bool(slot_facts.get("queued_for_resolution", false)),
			"locked": float(slot_facts.get("lock_left", 0.0)) > 0.0,
			"counted": bool(slot_facts.get("counts_toward_hand_limit", false)),
		})
	return result


func debug_snapshot() -> Dictionary:
	return {
		"service_ready": _configured,
		"service_authoritative": _configured,
		"ruleset_id": _ruleset_id,
		"ordinary_hand_limit": _ordinary_hand_limit,
		"maximum_card_rank": _maximum_card_rank,
		"receive_plan_count": _receive_plan_count,
		"remove_plan_count": _remove_plan_count,
		"lock_plan_count": _lock_plan_count,
		"transfer_plan_count": _transfer_plan_count,
		"queue_commit_plan_count": _queue_commit_plan_count,
		"queue_committed_count": _queue_committed_count,
		"commit_attempt_count": _commit_attempt_count,
		"committed_count": _committed_count,
		"rejected_count": _rejected_count,
		"last_reason": _last_reason,
		"last_operation": _last_operation,
		"last_outcome": _last_outcome,
		"purchase_cash_authority": false,
		"ledger_authority": false,
		"event_authority": false,
		"legacy_inventory_fallback_used": false,
	}


func _plan_queue_commit(request: Dictionary, count_plan: bool) -> Dictionary:
	if count_plan:
		_queue_commit_plan_count += 1
	if not _configured or not _is_data_only(request):
		return {"status": STATUS_REJECTED, "ready": false, "reason": "invalid_queue_inventory_request"}
	var inventory: Dictionary = request.get("inventory", {}) if request.get("inventory", {}) is Dictionary else {}
	var target_slot := int(request.get("target_slot", -1))
	var queued_skill: Dictionary = request.get("queued_skill", {}) if request.get("queued_skill", {}) is Dictionary else {}
	var consumed_on_queue := bool(request.get("consumed_on_queue", false))
	var slot_facts := _slot_facts(inventory, target_slot)
	if slot_facts.is_empty() or not bool(slot_facts.get("occupied", false)):
		return {"status": STATUS_REJECTED, "ready": false, "reason": "queue_slot_missing"}
	if bool(slot_facts.get("queued_for_resolution", false)):
		return {"status": STATUS_REJECTED, "ready": false, "reason": "queue_slot_already_committed"}
	if queued_skill.is_empty():
		return {"status": STATUS_REJECTED, "ready": false, "reason": "queued_skill_missing"}
	return {
		"status": STATUS_READY,
		"ready": true,
		"reason": "",
		"operation": "queue_commit",
		"target_slot": target_slot,
		"consumed_on_queue": consumed_on_queue,
		"counts_toward_hand_limit": bool(slot_facts.get("counts_toward_hand_limit", true)),
		"queued_skill": queued_skill.duplicate(true),
		"inventory_fingerprint": inventory_fingerprint(inventory),
	}


func _queue_commit_plans_match(expected: Dictionary, current: Dictionary) -> bool:
	return bool(expected.get("ready", false)) \
		and bool(current.get("ready", false)) \
		and int(expected.get("target_slot", -1)) == int(current.get("target_slot", -1)) \
		and bool(expected.get("consumed_on_queue", false)) == bool(current.get("consumed_on_queue", false)) \
		and expected.get("inventory_fingerprint", []) == current.get("inventory_fingerprint", []) \
		and expected.get("queued_skill", {}) == current.get("queued_skill", {})


func _slot_facts(inventory: Dictionary, target_slot: int) -> Dictionary:
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	for slot_variant in slots:
		if slot_variant is Dictionary and int((slot_variant as Dictionary).get("slot_index", -1)) == target_slot:
			return (slot_variant as Dictionary).duplicate(true)
	return {}


func _plan_receive(inventory: Dictionary, count_plan: bool) -> Dictionary:
	if count_plan:
		_receive_plan_count += 1
	if not _configured:
		return _inventory_rejection("service_not_configured", inventory)
	if not _is_data_only(inventory) or not bool(inventory.get("valid", false)):
		return _inventory_rejection("invalid_inventory", inventory)
	if inventory.has("hand_limit") and int(inventory.get("hand_limit", 0)) != _ordinary_hand_limit:
		return _inventory_rejection("ruleset_hand_limit_mismatch", inventory)
	var incoming_card_id := str(inventory.get("incoming_card_id", ""))
	var incoming_card: Dictionary = inventory.get("incoming_card", {}) if inventory.get("incoming_card", {}) is Dictionary else {}
	var incoming_family := str(inventory.get("incoming_family", ""))
	if incoming_card_id.is_empty() or incoming_card.is_empty() or incoming_family.is_empty():
		return _inventory_rejection("invalid_card", inventory)
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	var family_slot: Dictionary = {}
	if bool(inventory.get("incoming_allows_family_upgrade", true)):
		for slot_variant in slots:
			if not (slot_variant is Dictionary):
				continue
			var slot_facts: Dictionary = slot_variant
			if not bool(slot_facts.get("occupied", false)) or str(slot_facts.get("family", "")) != incoming_family:
				continue
			if family_slot.is_empty() or int(slot_facts.get("rank", 1)) > int(family_slot.get("rank", 1)):
				family_slot = slot_facts
	var fingerprint := _inventory_fingerprint_hash(inventory)
	if not family_slot.is_empty():
		var held_rank := maxi(1, int(family_slot.get("rank", 1)))
		var next_card_id := str(family_slot.get("next_upgrade_id", ""))
		var next_card: Dictionary = family_slot.get("next_upgrade_card", {}) if family_slot.get("next_upgrade_card", {}) is Dictionary else {}
		if held_rank >= _maximum_card_rank or next_card_id.is_empty() or next_card.is_empty():
			return _inventory_rejection("max_rank", inventory)
		return _inventory_ready("upgrade", int(family_slot.get("slot_index", -1)), -1, next_card_id, next_card, fingerprint, 0)
	var counted_hand_size := _counted_hand_size(slots)
	var incoming_counted := bool(inventory.get("incoming_counts_toward_hand_limit", true))
	if incoming_counted and counted_hand_size >= _ordinary_hand_limit:
		var available_discards := discardable_slots(inventory)
		if available_discards.is_empty():
			return _inventory_rejection("hand_limit_no_discard", inventory)
		var discard_slot := int(inventory.get("discard_slot", -1))
		if discard_slot < 0:
			return {
				"status": STATUS_REQUIRES_DISCARD,
				"ready": false,
				"requires_discard": true,
				"reason": "hand_limit_requires_discard",
				"discardable_slots": available_discards.duplicate(),
				"inventory_fingerprint": fingerprint,
			}
		if not available_discards.has(discard_slot):
			return _inventory_rejection("invalid_discard_slot", inventory)
		return _inventory_ready("replace", discard_slot, discard_slot, incoming_card_id, incoming_card, fingerprint, 0)
	var empty_slot := slots.size()
	for slot_variant in slots:
		if slot_variant is Dictionary and not bool((slot_variant as Dictionary).get("occupied", false)):
			empty_slot = int((slot_variant as Dictionary).get("slot_index", empty_slot))
			break
	return _inventory_ready("add", empty_slot, -1, incoming_card_id, incoming_card, fingerprint, 1 if incoming_counted else 0)


func _plan_remove(request: Dictionary, count_plan: bool) -> Dictionary:
	if count_plan:
		_remove_plan_count += 1
	var inventory := _request_inventory(request)
	if not _configured or not _is_data_only(request) or inventory.is_empty():
		return _mutation_rejection("invalid_remove_request", "remove", inventory)
	var target_slot := int(request.get("slot_index", -1))
	if not discardable_slots(inventory).has(target_slot):
		return _mutation_rejection("slot_not_discardable", "remove", inventory)
	return {
		"status": STATUS_READY,
		"ready": true,
		"reason": "ready",
		"operation": "remove",
		"target_slot": target_slot,
		"counted": true,
		"inventory_fingerprint": _inventory_fingerprint_hash(inventory),
	}


func _plan_lock(request: Dictionary, count_plan: bool) -> Dictionary:
	if count_plan:
		_lock_plan_count += 1
	var inventory := _request_inventory(request)
	var duration_seconds := maxf(0.0, float(request.get("duration_seconds", 0.0)))
	if not _configured or not _is_data_only(request) or inventory.is_empty() or duration_seconds <= 0.0:
		return _mutation_rejection("invalid_lock_request", "lock", inventory)
	var target_slot := int(request.get("slot_index", -1))
	if not discardable_slots(inventory).has(target_slot):
		return _mutation_rejection("slot_not_lockable", "lock", inventory)
	return {
		"status": STATUS_READY,
		"ready": true,
		"reason": "ready",
		"operation": "lock",
		"target_slot": target_slot,
		"duration_seconds": duration_seconds,
		"inventory_fingerprint": _inventory_fingerprint_hash(inventory),
	}


func _plan_transfer(request: Dictionary, count_plan: bool) -> Dictionary:
	if count_plan:
		_transfer_plan_count += 1
	if not _configured or not _is_data_only(request):
		return _transfer_rejection("invalid_transfer_request")
	var source_inventory: Dictionary = request.get("source_inventory", {}) if request.get("source_inventory", {}) is Dictionary else {}
	var target_inventory: Dictionary = request.get("target_inventory", {}) if request.get("target_inventory", {}) is Dictionary else {}
	var target_slot := int(request.get("target_slot", -1))
	var remove_plan := _plan_remove({"inventory": target_inventory, "slot_index": target_slot}, false)
	if str(remove_plan.get("status", "")) != STATUS_READY:
		return _transfer_rejection(str(remove_plan.get("reason", "target_not_discardable")))
	var receive_plan := _plan_receive(source_inventory, false)
	var receive_ready := str(receive_plan.get("status", "")) == STATUS_READY
	var failure_policy := str(request.get("failure_policy", "reject_before_removal"))
	if not receive_ready and failure_policy != FAILURE_POLICY_CONVERT_TO_REMOVE:
		return _transfer_rejection(str(receive_plan.get("reason", "receiver_rejected")))
	var outcome := "converted_to_remove"
	if receive_ready:
		outcome = "upgraded" if str(receive_plan.get("operation", "")) == "upgrade" else "received"
	return {
		"status": STATUS_READY,
		"ready": true,
		"reason": "ready",
		"operation": "transfer",
		"outcome": outcome,
		"target_slot": target_slot,
		"failure_policy": failure_policy,
		"source_receive_plan": receive_plan.duplicate(true),
		"source_inventory_fingerprint": _inventory_fingerprint_hash(source_inventory),
		"target_inventory_fingerprint": _inventory_fingerprint_hash(target_inventory),
	}


func _inventory_ready(operation: String, target_slot: int, discard_slot: int, result_card_id: String, result_card: Dictionary, fingerprint: String, hand_delta: int) -> Dictionary:
	return {
		"status": STATUS_READY,
		"ready": true,
		"requires_discard": false,
		"reason": "ready",
		"operation": operation,
		"target_slot": target_slot,
		"discard_slot": discard_slot,
		"result_card_id": result_card_id,
		"result_card": result_card.duplicate(true),
		"inventory_fingerprint": fingerprint,
		"hand_count_delta": hand_delta,
		"slot_change_kind": operation,
	}


func _inventory_rejection(reason: String, inventory: Dictionary) -> Dictionary:
	return {
		"status": STATUS_REJECTED,
		"ready": false,
		"requires_discard": false,
		"reason": reason,
		"discardable_slots": discardable_slots(inventory),
		"inventory_fingerprint": _inventory_fingerprint_hash(inventory),
	}


func _mutation_rejection(reason: String, operation: String, inventory: Dictionary) -> Dictionary:
	return {
		"status": STATUS_REJECTED,
		"ready": false,
		"reason": reason,
		"operation": operation,
		"target_slot": -1,
		"inventory_fingerprint": _inventory_fingerprint_hash(inventory),
	}


func _transfer_rejection(reason: String) -> Dictionary:
	return {
		"status": STATUS_REJECTED,
		"ready": false,
		"reason": reason,
		"operation": "transfer",
		"outcome": "rejected",
	}


func _commit_success(operation: String, outcome: String, extra: Dictionary) -> Dictionary:
	_committed_count += 1
	_last_reason = "committed"
	_last_operation = operation
	_last_outcome = outcome
	var result := {
		"committed": true,
		"reason": "committed",
		"operation": operation,
		"outcome": outcome,
		"hand_count_delta": 0,
		"target_hand_count_delta": 0,
		"slot_change_kind": operation,
		"target_slot": -1,
		"source_target_slot": -1,
		"duration_seconds": 0.0,
		"mutation_count": 1,
	}
	result.merge(extra, true)
	return result


func _commit_rejection(reason: String) -> Dictionary:
	_rejected_count += 1
	_last_reason = reason
	_last_operation = ""
	_last_outcome = "rejected"
	return {
		"committed": false,
		"reason": reason,
		"operation": "none",
		"outcome": "rejected",
		"hand_count_delta": 0,
		"target_hand_count_delta": 0,
		"slot_change_kind": "none",
		"target_slot": -1,
		"source_target_slot": -1,
		"duration_seconds": 0.0,
		"mutation_count": 0,
	}


func _receive_plans_match(expected: Dictionary, current: Dictionary) -> bool:
	for key in ["status", "operation", "target_slot", "discard_slot", "result_card_id", "inventory_fingerprint"]:
		if expected.get(key) != current.get(key):
			return false
	return str(current.get("status", "")) == STATUS_READY


func _mutation_plans_match(expected: Dictionary, current: Dictionary) -> bool:
	for key in ["status", "operation", "target_slot", "inventory_fingerprint"]:
		if expected.get(key) != current.get(key):
			return false
	if str(current.get("operation", "")) == "lock" and not is_equal_approx(float(expected.get("duration_seconds", 0.0)), float(current.get("duration_seconds", 0.0))):
		return false
	return str(current.get("status", "")) == STATUS_READY


func _transfer_plans_match(expected: Dictionary, current: Dictionary) -> bool:
	for key in ["status", "operation", "outcome", "target_slot", "failure_policy", "source_inventory_fingerprint", "target_inventory_fingerprint"]:
		if expected.get(key) != current.get(key):
			return false
	return str(current.get("status", "")) == STATUS_READY


func _player_matches_inventory(player_state: Dictionary, inventory: Dictionary) -> bool:
	var player_slots: Array = player_state.get("slots", []) if player_state.get("slots", []) is Array else []
	var slot_facts: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	if player_slots.size() != slot_facts.size():
		return false
	for slot_variant in slot_facts:
		if not (slot_variant is Dictionary):
			return false
		var facts: Dictionary = slot_variant
		var slot_index := int(facts.get("slot_index", -1))
		if slot_index < 0 or slot_index >= player_slots.size():
			return false
		var actual_variant: Variant = player_slots[slot_index]
		if bool(facts.get("occupied", false)) != (actual_variant is Dictionary):
			return false
		if actual_variant is Dictionary:
			var actual_card: Dictionary = actual_variant
			if str(actual_card.get("name", "")) != str(facts.get("card_id", "")):
				return false
			if bool(actual_card.get("queued_for_resolution", false)) != bool(facts.get("queued_for_resolution", false)):
				return false
			if not is_equal_approx(float(actual_card.get("lock_left", 0.0)), float(facts.get("lock_left", 0.0))):
				return false
	return true


func _apply_receive_operation(player_state: Dictionary, plan: Dictionary) -> bool:
	var operation := str(plan.get("operation", ""))
	if not ["add", "upgrade", "replace"].has(operation):
		return false
	var target_slot := int(plan.get("target_slot", -1))
	var result_card: Dictionary = plan.get("result_card", {}) if plan.get("result_card", {}) is Dictionary else {}
	if target_slot < 0 or result_card.is_empty() or not _is_data_only(result_card):
		return false
	var slots: Array = (player_state.get("slots", []) as Array).duplicate(true) if player_state.get("slots", []) is Array else []
	while slots.size() <= target_slot:
		slots.append(null)
	if operation == "add" and slots[target_slot] is Dictionary:
		return false
	if ["upgrade", "replace"].has(operation) and not (slots[target_slot] is Dictionary):
		return false
	slots[target_slot] = result_card.duplicate(true)
	player_state["slots"] = slots
	return true


func _remove_slot(player_state: Dictionary, target_slot: int) -> Dictionary:
	var slots: Array = (player_state.get("slots", []) as Array).duplicate(true) if player_state.get("slots", []) is Array else []
	if target_slot < 0 or target_slot >= slots.size() or not (slots[target_slot] is Dictionary):
		return {}
	var removed: Dictionary = (slots[target_slot] as Dictionary).duplicate(true)
	slots[target_slot] = null
	player_state["slots"] = slots
	return removed


func _lock_slot(player_state: Dictionary, target_slot: int, duration_seconds: float) -> Dictionary:
	var slots: Array = (player_state.get("slots", []) as Array).duplicate(true) if player_state.get("slots", []) is Array else []
	if target_slot < 0 or target_slot >= slots.size() or not (slots[target_slot] is Dictionary) or duration_seconds <= 0.0:
		return {}
	var card: Dictionary = (slots[target_slot] as Dictionary).duplicate(true)
	card["lock_left"] = maxf(float(card.get("lock_left", 0.0)), duration_seconds)
	slots[target_slot] = card
	player_state["slots"] = slots
	return card


func _request_inventory(request: Dictionary) -> Dictionary:
	var value: Variant = request.get("inventory", request)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _counted_hand_size(slots: Array) -> int:
	var count := 0
	for slot_variant in slots:
		if slot_variant is Dictionary and bool((slot_variant as Dictionary).get("occupied", false)) and bool((slot_variant as Dictionary).get("counts_toward_hand_limit", false)):
			count += 1
	return count


func _inventory_fingerprint_hash(inventory: Dictionary) -> String:
	var normalized: Array = []
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	for slot_variant in slots:
		if not (slot_variant is Dictionary):
			continue
		var slot_facts: Dictionary = slot_variant
		normalized.append({
			"slot_index": int(slot_facts.get("slot_index", -1)),
			"occupied": bool(slot_facts.get("occupied", false)),
			"card_id": str(slot_facts.get("card_id", "")),
			"family": str(slot_facts.get("family", "")),
			"rank": int(slot_facts.get("rank", 0)),
			"counts": bool(slot_facts.get("counts_toward_hand_limit", false)),
			"queued": bool(slot_facts.get("queued_for_resolution", false)),
			"lock_left": float(slot_facts.get("lock_left", 0.0)),
			"next_upgrade_id": str(slot_facts.get("next_upgrade_id", "")),
		})
	var source := JSON.stringify({
		"incoming_card_id": str(inventory.get("incoming_card_id", "")),
		"incoming_family": str(inventory.get("incoming_family", "")),
		"incoming_rank": int(inventory.get("incoming_rank", 0)),
		"incoming_counted": bool(inventory.get("incoming_counts_toward_hand_limit", true)),
		"incoming_allows_family_upgrade": bool(inventory.get("incoming_allows_family_upgrade", true)),
		"ordinary_hand_limit": _ordinary_hand_limit,
		"maximum_card_rank": _maximum_card_rank,
		"discard_slot": int(inventory.get("discard_slot", -1)),
		"slots": normalized,
	})
	return str(hash(source))


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
