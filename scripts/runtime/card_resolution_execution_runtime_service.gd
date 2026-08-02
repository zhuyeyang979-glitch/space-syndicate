@tool
extends Node
class_name CardResolutionExecutionRuntimeService

const FacilityBinding := preload("res://scripts/cards/v06/queued_facility_card_action_v1.gd")
const SaveWireCodecV4 := preload("res://scripts/runtime/card_resolution_execution_save_wire_codec_v4.gd")
const SemanticWireV1 := preload("res://scripts/semantic/semantic_wire_v1.gd")

const STATUS_READY := "ready"
const STATUS_RETRYABLE := "retryable"
const STATUS_REJECTED := "rejected"
const STATUS_ABORTED := "aborted"
const SAVE_SCHEMA_VERSION := 4
const EXECUTION_WIRE_VERSION := 1
const TRANSITION_STATE_WIRE_VERSION := 2
const SAVE_RULESET_ID := "v0.6"
const LEGACY_SAVE_SCHEMA_VERSIONS := [1, 2, 3]
const LEGACY_CLOSED_WIRE_REASON := "card_resolution_execution_v3_closed_wire_upgrade_requires_backup"
const RUNTIME_SAVE_FIELDS := [
	"schema_version",
	"execution_wire_version",
	"ruleset_id",
	"transaction_sequence",
	"completed_resolution_ids",
	"inflight_resolution_ids",
	"inflight_execution_transactions",
	"pending_settlements",
	"transition_controller",
]
const TRANSITION_STATE_FIELDS := [
	"transition_state_wire_version",
	"card_group_cadence_version",
	"card_group_cadence",
	"card_group_window_phase",
	"card_resolution_timer",
	"card_resolution_counter_window_active",
	"card_resolution_counter_timer",
	"card_resolution_simultaneous_timer",
	"card_resolution_auction_timer",
	"card_resolution_auction_open",
	"card_resolution_batch_locked",
	"card_resolution_batch_reference_player",
	"card_group_window_sequence",
	"last_card_resolution_player_index",
	"card_group_ready_players",
	"card_transition_command_schema_version",
	"card_transition_command_revision",
	"card_transition_command_next_order_index",
	"card_transition_applied_lineage",
	"card_transition_last_applied_revision",
	"card_transition_last_applied_order_index",
]
const EXECUTION_TRANSACTION_FIELDS := [
	"status",
	"ready",
	"reason",
	"execution_id",
	"resolution_id",
	"entry_fingerprint",
	"execution_kind",
	"current_phase",
	"next_intent",
	"completed_intents",
	"countered",
	"resolved",
	"failure_reason",
	"history_required",
	"history_appended",
	"active_released",
	"effect_dispatched",
	"commitment_checked",
	"context_restored",
	"continuation_kind",
	"continuation_checked",
	"aftermath_required",
	"counter_resolution_id",
	"counter_card_name",
	"target_kind",
	"handler_id",
	"active_entry",
	"skill",
	"selection_context",
	"monster_wager_decision_count_before",
	"recovered",
]
const NEXT_INTENT_FIELDS := ["intent_type", "execution_id", "resolution_id", "handler_id"]
const PENDING_SETTLEMENT_FIELDS := ["resolution_id", "execution_id", "transaction", "finalized"]
const FINALIZED_FIELDS := [
	"completed",
	"reason",
	"resolution_id",
	"execution_id",
	"countered",
	"resolved",
	"effect_dispatched",
	"history_appended",
	"continuation_kind",
	"settlement_binding",
	"settlement_binding_fingerprint",
]
const SETTLEMENT_BINDING_FIELDS := [
	"resolution_id",
	"execution_id",
	"resolved",
	"countered",
	"effect_dispatched",
	"history_appended",
	"continuation_kind",
]

const INTENT_COUNTER_CHECK := "counter_check"
const INTENT_RELEASE_ACTIVE := "release_active"
const INTENT_FINISH_PRESENTATION := "finish_presentation"
const INTENT_REVALIDATE_REQUIREMENT := "revalidate_requirement"
const INTENT_REVALIDATE_TARGET := "revalidate_target"
const INTENT_DISPATCH_EFFECT := "dispatch_effect"
const INTENT_FINISH_COMMITMENT := "finish_card_commitment"
const INTENT_CREATE_AFTERMATH := "create_aftermath"
const INTENT_RESTORE_CONTEXT := "restore_context"
const INTENT_APPEND_HISTORY := "append_history"
const INTENT_START_NEXT := "start_next"
const INTENT_FINISH_BATCH := "finish_batch"
const INTENT_PROMOTE_NEXT_BATCH := "promote_next_batch"
const SUPPORTED_INTENTS := {
	INTENT_COUNTER_CHECK: true,
	INTENT_RELEASE_ACTIVE: true,
	INTENT_FINISH_PRESENTATION: true,
	INTENT_REVALIDATE_REQUIREMENT: true,
	INTENT_REVALIDATE_TARGET: true,
	INTENT_DISPATCH_EFFECT: true,
	INTENT_FINISH_COMMITMENT: true,
	INTENT_CREATE_AFTERMATH: true,
	INTENT_RESTORE_CONTEXT: true,
	INTENT_APPEND_HISTORY: true,
	INTENT_START_NEXT: true,
	INTENT_FINISH_BATCH: true,
	INTENT_PROMOTE_NEXT_BATCH: true,
}

var _configured := false
var _transaction_sequence := 0
var _plan_count := 0
var _advance_count := 0
var _finalized_count := 0
var _rejected_count := 0
var _aborted_count := 0
var _completed_resolution_ids: Dictionary = {}
var _inflight_resolution_ids: Dictionary = {}
var _inflight_execution_transactions: Dictionary = {}
var _pending_settlements: Dictionary = {}
var _last_resolution_id := -1
var _last_phase := ""
var _last_reason := ""
var _last_summary: Dictionary = {}
var _transition_checkpoint_owner: CardResolutionRuntimeController


func configure(_config: Dictionary = {}) -> void:
	_configured = true
	reset_state()


func set_transition_checkpoint_owner(checkpoint_owner: CardResolutionRuntimeController) -> void:
	_transition_checkpoint_owner = checkpoint_owner


func reset_state() -> void:
	_transaction_sequence = 0
	_plan_count = 0
	_advance_count = 0
	_finalized_count = 0
	_rejected_count = 0
	_aborted_count = 0
	_completed_resolution_ids.clear()
	_inflight_resolution_ids.clear()
	_inflight_execution_transactions.clear()
	_pending_settlements.clear()
	_last_resolution_id = -1
	_last_phase = ""
	_last_reason = ""
	_last_summary = {}


func plan_execution(request: Dictionary) -> Dictionary:
	_plan_count += 1
	if not _configured:
		return _plan_rejection("service_not_configured")
	if not _is_data_only(request):
		return _plan_rejection("invalid_request")
	var active_entry := _dictionary(request.get("active_entry", {}))
	if active_entry.is_empty():
		return _plan_rejection("active_missing")
	var resolution_id := int(active_entry.get("resolution_id", active_entry.get("queued_order", -1)))
	if resolution_id < 0:
		return _plan_rejection("invalid_resolution_id")
	var resolution_key := str(resolution_id)
	if _completed_resolution_ids.has(resolution_key):
		return _plan_rejection("already_completed", resolution_id)
	if _inflight_resolution_ids.has(resolution_key):
		return _plan_rejection("already_inflight", resolution_id)
	var skill := _dictionary(request.get("skill", active_entry.get("skill", {})))
	if bool(active_entry.get("play_cost_paid_on_queue", false)):
		skill["_play_cost_paid_on_queue"] = true
	_transaction_sequence += 1
	var execution_id := _transaction_sequence
	var target_kind := str(request.get("target_kind", "none"))
	var transaction := {
		"status": STATUS_READY,
		"ready": true,
		"reason": "ready",
		"execution_id": execution_id,
		"resolution_id": resolution_id,
		"entry_fingerprint": JSON.stringify(active_entry).sha256_text(),
		"execution_kind": _execution_kind(skill, target_kind),
		"current_phase": "planned",
		"next_intent": _intent(INTENT_COUNTER_CHECK, execution_id, resolution_id, skill),
		"completed_intents": [],
		"countered": false,
		"resolved": false,
		"failure_reason": "",
		"history_required": true,
		"history_appended": false,
		"active_released": false,
		"effect_dispatched": false,
		"commitment_checked": false,
		"context_restored": false,
		"continuation_kind": "normal",
		"continuation_checked": false,
		"aftermath_required": false,
		"counter_resolution_id": -1,
		"counter_card_name": "",
		"target_kind": target_kind,
		"handler_id": _handler_id(skill, target_kind),
		"active_entry": active_entry,
		"skill": skill,
		"selection_context": _dictionary(request.get("selection_context", {})),
		"monster_wager_decision_count_before": maxi(0, int(request.get("monster_wager_decision_count_before", 0))),
		"recovered": bool(request.get("recovered", false)),
	}
	_inflight_resolution_ids[resolution_key] = execution_id
	_inflight_execution_transactions[resolution_key] = transaction.duplicate(true)
	_last_resolution_id = resolution_id
	_last_phase = "planned"
	_last_reason = "ready"
	_last_summary = _transaction_summary(transaction)
	return transaction


func advance_execution(transaction: Dictionary, receipt: Dictionary) -> Dictionary:
	_advance_count += 1
	if not _configured or not _is_data_only(transaction) or not _is_data_only(receipt):
		return _abort_transaction(transaction, "invalid_advance_request")
	var next := _dictionary(transaction.get("next_intent", {}))
	var expected := str(next.get("intent_type", ""))
	if expected == "":
		return _abort_transaction(transaction, "execution_has_no_next_intent")
	if str(receipt.get("intent_type", "")) != expected:
		return _abort_transaction(transaction, "intent_receipt_mismatch")
	var updated := transaction.duplicate(true)
	var completed: Array = updated.get("completed_intents", []) if updated.get("completed_intents", []) is Array else []
	completed.append(expected)
	updated["completed_intents"] = completed
	updated["current_phase"] = expected
	updated["reason"] = str(receipt.get("reason", ""))
	if receipt.get("skill", {}) is Dictionary and not (receipt.get("skill", {}) as Dictionary).is_empty():
		updated["skill"] = (receipt.get("skill", {}) as Dictionary).duplicate(true)
	match expected:
		INTENT_COUNTER_CHECK:
			updated["countered"] = bool(receipt.get("countered", false))
			updated["counter_resolution_id"] = int(receipt.get("counter_resolution_id", -1))
			updated["counter_card_name"] = str(receipt.get("counter_card_name", ""))
			if bool(updated["countered"]):
				updated["execution_kind"] = "countered"
			updated["next_intent"] = _intent_for(updated, INTENT_RELEASE_ACTIVE)
		INTENT_RELEASE_ACTIVE:
			if not bool(receipt.get("completed", false)):
				return _abort_transaction(updated, str(receipt.get("reason", "active_release_failed")))
			updated["active_released"] = true
			updated["next_intent"] = _intent_for(updated, INTENT_FINISH_PRESENTATION)
		INTENT_FINISH_PRESENTATION:
			updated["next_intent"] = _intent_for(updated, INTENT_FINISH_COMMITMENT if bool(updated.get("countered", false)) else INTENT_REVALIDATE_REQUIREMENT)
		INTENT_REVALIDATE_REQUIREMENT:
			var requirement_valid := bool(receipt.get("valid", false))
			if requirement_valid:
				updated["next_intent"] = _intent_for(updated, INTENT_REVALIDATE_TARGET)
			else:
				updated["failure_reason"] = str(receipt.get("reason", "requirement_invalid"))
				updated["resolved"] = false
				updated["aftermath_required"] = false
				updated["next_intent"] = _intent_for(updated, INTENT_FINISH_COMMITMENT)
		INTENT_REVALIDATE_TARGET:
			var target_valid := bool(receipt.get("valid", false))
			updated["aftermath_required"] = true
			if target_valid:
				updated["next_intent"] = _intent_for(updated, INTENT_DISPATCH_EFFECT)
			else:
				updated["failure_reason"] = str(receipt.get("reason", "target_invalid"))
				updated["resolved"] = false
				updated["next_intent"] = _intent_for(updated, INTENT_FINISH_COMMITMENT)
		INTENT_DISPATCH_EFFECT:
			updated["effect_dispatched"] = bool(receipt.get("dispatched", false))
			updated["resolved"] = bool(receipt.get("resolved", false))
			updated["failure_reason"] = "" if bool(updated["resolved"]) else str(receipt.get("reason", "effect_not_resolved"))
			updated["continuation_kind"] = str(receipt.get("continuation_kind", "normal"))
			updated["next_intent"] = _intent_for(updated, INTENT_FINISH_COMMITMENT)
			if bool(receipt.get("retryable_commitment", false)):
				updated["status"] = STATUS_RETRYABLE
				updated["ready"] = false
				updated["reason"] = "facility_commitment_retry_required"
				updated["failure_reason"] = str(updated["reason"])
				_store_inflight_transaction(updated)
				_last_resolution_id = int(updated.get("resolution_id", -1))
				_last_phase = "retryable_commitment"
				_last_reason = str(updated["reason"])
				_last_summary = _transaction_summary(updated)
				return updated
		INTENT_FINISH_COMMITMENT:
			var facility_commitment := _dictionary(updated.get("active_entry", {})).has("v06_facility_action")
			var commitment_settled := bool(receipt.get("committed", false)) \
				and (not facility_commitment or bool(receipt.get("commitment_settled", false)))
			if not commitment_settled:
				completed.pop_back()
				updated["completed_intents"] = completed
				updated["status"] = STATUS_RETRYABLE
				updated["ready"] = false
				updated["reason"] = str(receipt.get("reason", "card_commitment_unsettled"))
				updated["failure_reason"] = str(updated["reason"])
				updated["next_intent"] = _intent_for(updated, INTENT_FINISH_COMMITMENT)
				_store_inflight_transaction(updated)
				_last_resolution_id = int(updated.get("resolution_id", -1))
				_last_phase = "retryable_commitment"
				_last_reason = str(updated["reason"])
				_last_summary = _transaction_summary(updated)
				return updated
			updated["commitment_checked"] = true
			updated["next_intent"] = _intent_for(updated, INTENT_CREATE_AFTERMATH if bool(updated.get("countered", false)) or bool(updated.get("aftermath_required", false)) else INTENT_RESTORE_CONTEXT)
		INTENT_CREATE_AFTERMATH:
			var active_entry := _dictionary(updated.get("active_entry", {}))
			var entry_patch := _dictionary(receipt.get("entry_patch", {}))
			active_entry.merge(entry_patch, true)
			updated["active_entry"] = active_entry
			updated["entry_fingerprint"] = JSON.stringify(active_entry).sha256_text()
			updated["next_intent"] = _intent_for(updated, INTENT_RESTORE_CONTEXT)
		INTENT_RESTORE_CONTEXT:
			updated["context_restored"] = bool(receipt.get("restored", false))
			updated["next_intent"] = _intent_for(updated, INTENT_APPEND_HISTORY)
		INTENT_APPEND_HISTORY:
			if not bool(receipt.get("appended", false)):
				# History is an owner mutation boundary. A failed receipt must keep the
				# exact same intent resumable; release/effect intents already recorded in
				# this transaction must never be planned again after save/load.
				completed.pop_back()
				updated["completed_intents"] = completed
				updated["status"] = STATUS_RETRYABLE
				updated["ready"] = false
				updated["reason"] = str(receipt.get("reason", "history_append_failed"))
				updated["failure_reason"] = str(updated["reason"])
				updated["next_intent"] = _intent_for(updated, INTENT_APPEND_HISTORY)
				_store_inflight_transaction(updated)
				_last_resolution_id = int(updated.get("resolution_id", -1))
				_last_phase = "retryable_history"
				_last_reason = str(updated["reason"])
				_last_summary = _transaction_summary(updated)
				return updated
			updated["history_appended"] = true
			updated["failure_reason"] = ""
			var current_count := maxi(0, int(receipt.get("current_queue_count", 0)))
			updated["next_intent"] = _intent_for(updated, INTENT_START_NEXT if current_count > 0 else INTENT_FINISH_BATCH)
		INTENT_START_NEXT:
			updated["continuation_checked"] = bool(receipt.get("started", false))
			updated["next_intent"] = {}
		INTENT_FINISH_BATCH:
			updated["continuation_checked"] = bool(receipt.get("finished", false))
			var next_count := maxi(0, int(receipt.get("next_queue_count", 0)))
			updated["next_intent"] = _intent_for(updated, INTENT_PROMOTE_NEXT_BATCH) if next_count > 0 else {}
		INTENT_PROMOTE_NEXT_BATCH:
			updated["continuation_checked"] = bool(receipt.get("promoted", false))
			updated["next_intent"] = {}
		_:
			return _abort_transaction(updated, "unsupported_intent")
	_last_resolution_id = int(updated.get("resolution_id", -1))
	_last_phase = str(updated.get("current_phase", ""))
	_last_reason = str(updated.get("reason", ""))
	_last_summary = _transaction_summary(updated)
	_store_inflight_transaction(updated)
	return updated


func resume_inflight_execution(resolution_id: int) -> Dictionary:
	if resolution_id < 0:
		return _plan_rejection("invalid_resolution_id", resolution_id)
	var resolution_key := str(resolution_id)
	if not _inflight_execution_transactions.has(resolution_key):
		return _plan_rejection("inflight_transaction_missing", resolution_id)
	var transaction := _dictionary(_inflight_execution_transactions.get(resolution_key, {}))
	if transaction.is_empty() or int(transaction.get("resolution_id", -1)) != resolution_id:
		return _plan_rejection("inflight_transaction_invalid", resolution_id)
	if str(transaction.get("status", "")) == STATUS_RETRYABLE:
		transaction["status"] = STATUS_READY
		transaction["ready"] = true
		transaction["reason"] = "retry_ready"
		transaction["failure_reason"] = ""
		_store_inflight_transaction(transaction)
	elif str(transaction.get("status", "")) != STATUS_READY:
		return _plan_rejection("inflight_transaction_not_resumable", resolution_id)
	_last_resolution_id = resolution_id
	_last_phase = "resumed"
	_last_reason = "retry_ready"
	_last_summary = _transaction_summary(transaction)
	return transaction


func has_inflight_execution(resolution_id: int) -> bool:
	return resolution_id >= 0 and _inflight_execution_transactions.has(str(resolution_id))


func pending_settlement(resolution_id: int) -> Dictionary:
	if resolution_id < 0:
		return {}
	return _dictionary(_pending_settlements.get(str(resolution_id), {}))


func immediate_facility_resolution_snapshot() -> Dictionary:
	var candidates: Array[Dictionary] = []
	for pending_variant in _pending_settlements.values():
		if not (pending_variant is Dictionary):
			continue
		var transaction: Dictionary = (pending_variant as Dictionary).get("transaction", {}) \
			if (pending_variant as Dictionary).get("transaction", {}) is Dictionary else {}
		var candidate := _facility_execution_candidate(transaction, "pending_settlement")
		if not candidate.is_empty():
			candidates.append(candidate)
	for transaction_variant in _inflight_execution_transactions.values():
		if not (transaction_variant is Dictionary):
			continue
		var candidate := _facility_execution_candidate(transaction_variant as Dictionary, "inflight")
		if not candidate.is_empty():
			candidates.append(candidate)
	if candidates.is_empty():
		return {"pending": false, "reason_code": "facility_execution_not_pending"}
	if candidates.size() != 1:
		return {"pending": false, "reason_code": "facility_execution_collision"}
	return candidates[0].duplicate(true)


func _facility_execution_candidate(transaction: Dictionary, stage_id: String) -> Dictionary:
	var entry: Dictionary = transaction.get("active_entry", {}) \
		if transaction.get("active_entry", {}) is Dictionary else {}
	var binding: Dictionary = entry.get("v06_facility_action", {}) \
		if entry.get("v06_facility_action", {}) is Dictionary else {}
	if not bool(FacilityBinding.validation_report(binding).get("valid", false)):
		return {}
	var resolution_id := int(transaction.get("resolution_id", -1))
	if resolution_id <= 0 or resolution_id != int(entry.get("resolution_id", -2)) \
			or resolution_id != int(binding.get("resolution_id", -3)):
		return {}
	return {
		"pending": true,
		"reason_code": "facility_execution_pending",
		"resolution_id": resolution_id,
		"stage_id": stage_id,
	}


func ensure_pending_settlement(transaction: Dictionary, finalized: Dictionary) -> Dictionary:
	if not _is_data_only(transaction) or not _is_data_only(finalized):
		return {"registered": false, "reason": "pending_settlement_not_data"}
	var resolution_id := int(finalized.get("resolution_id", -1))
	var execution_id := int(finalized.get("execution_id", -1))
	if not bool(finalized.get("completed", false)) \
			or resolution_id < 0 \
			or int(transaction.get("resolution_id", -1)) != resolution_id \
			or int(transaction.get("execution_id", -1)) != execution_id:
		return {"registered": false, "reason": "pending_settlement_binding_invalid"}
	var expected_binding := _settlement_binding(transaction, finalized)
	if not _finalized_matches_settlement_binding(finalized, expected_binding) \
			or _dictionary(finalized.get("settlement_binding", {})) != expected_binding \
			or str(finalized.get("settlement_binding_fingerprint", "")) != _settlement_binding_fingerprint(expected_binding):
		return {"registered": false, "reason": "pending_settlement_outcome_binding_invalid"}
	var resolution_key := str(resolution_id)
	if _pending_settlements.has(resolution_key):
		var existing := _dictionary(_pending_settlements[resolution_key])
		if existing == {
			"resolution_id": resolution_id,
			"execution_id": execution_id,
			"transaction": transaction.duplicate(true),
			"finalized": finalized.duplicate(true),
		}:
			return {"registered": true, "reason": "already_registered", "resolution_id": resolution_id}
		return {"registered": false, "reason": "pending_settlement_binding_mismatch"}
	_pending_settlements[resolution_key] = {
		"resolution_id": resolution_id,
		"execution_id": execution_id,
		"transaction": transaction.duplicate(true),
		"finalized": finalized.duplicate(true),
	}
	return {"registered": true, "reason": "registered", "resolution_id": resolution_id}


func complete_pending_settlement(resolution_id: int, receipt: Dictionary) -> Dictionary:
	var resolution_key := str(resolution_id)
	if not _pending_settlements.has(resolution_key):
		return {"completed": false, "reason": "pending_settlement_missing", "resolution_id": resolution_id}
	if not _is_data_only(receipt) or not bool(receipt.get("settled", false)):
		return {"completed": false, "reason": str(receipt.get("reason", "settlement_not_completed")), "resolution_id": resolution_id}
	var pending := _dictionary(_pending_settlements[resolution_key])
	var finalized := _dictionary(pending.get("finalized", {}))
	var expected_binding := _dictionary(finalized.get("settlement_binding", {}))
	if int(receipt.get("resolution_id", -1)) != resolution_id \
			or int(receipt.get("execution_id", -1)) != int(pending.get("execution_id", -1)) \
			or _dictionary(receipt.get("settlement_binding", {})) != expected_binding \
			or str(receipt.get("settlement_binding_fingerprint", "")) != str(finalized.get("settlement_binding_fingerprint", "")):
		return {"completed": false, "reason": "settlement_receipt_binding_mismatch", "resolution_id": resolution_id}
	_pending_settlements.erase(resolution_key)
	_last_resolution_id = resolution_id
	_last_phase = "settled"
	_last_reason = "settlement_completed"
	return {"completed": true, "reason": "settlement_completed", "resolution_id": resolution_id}


func finalize_execution(transaction: Dictionary) -> Dictionary:
	if not _configured or not _is_data_only(transaction):
		return _finalize_rejection("invalid_finalize_request")
	var resolution_id := int(transaction.get("resolution_id", -1))
	var resolution_key := str(resolution_id)
	if _completed_resolution_ids.has(resolution_key):
		var pending := pending_settlement(resolution_id)
		if not pending.is_empty():
			return _dictionary(pending.get("finalized", {}))
		return _finalize_rejection("already_completed", resolution_id)
	if str(transaction.get("status", "")) != STATUS_READY:
		return _finalize_rejection(str(transaction.get("failure_reason", transaction.get("reason", "execution_aborted"))), resolution_id)
	if not _dictionary(transaction.get("next_intent", {})).is_empty():
		return _finalize_rejection("execution_incomplete", resolution_id)
	if not bool(transaction.get("active_released", false)) \
			or not bool(transaction.get("commitment_checked", false)) \
			or not bool(transaction.get("history_appended", false)):
		return _finalize_rejection("execution_incomplete", resolution_id)
	_completed_resolution_ids[resolution_key] = true
	_inflight_resolution_ids.erase(resolution_key)
	_inflight_execution_transactions.erase(resolution_key)
	_finalized_count += 1
	_last_resolution_id = resolution_id
	_last_phase = "finalized"
	_last_reason = "completed"
	_last_summary = _transaction_summary(transaction)
	var finalized := {
		"completed": true,
		"reason": "completed",
		"resolution_id": resolution_id,
		"execution_id": int(transaction.get("execution_id", -1)),
		"countered": bool(transaction.get("countered", false)),
		"resolved": bool(transaction.get("resolved", false)),
		"effect_dispatched": bool(transaction.get("effect_dispatched", false)),
		"history_appended": true,
		"continuation_kind": str(transaction.get("continuation_kind", "normal")),
	}
	var settlement_binding := _settlement_binding(transaction, finalized)
	finalized["settlement_binding"] = settlement_binding
	finalized["settlement_binding_fingerprint"] = _settlement_binding_fingerprint(settlement_binding)
	_pending_settlements[resolution_key] = {
		"resolution_id": resolution_id,
		"execution_id": int(transaction.get("execution_id", -1)),
		"transaction": transaction.duplicate(true),
		"finalized": finalized.duplicate(true),
	}
	return finalized


func recover_from_active(active_entry: Dictionary, facts: Dictionary = {}) -> Dictionary:
	if active_entry.is_empty():
		return {
			"status": STATUS_REJECTED,
			"ready": false,
			"reason": "active_missing",
			"replay_allowed": false,
		}
	var request := facts.duplicate(true)
	request["active_entry"] = active_entry.duplicate(true)
	if not request.has("skill"):
		request["skill"] = _dictionary(active_entry.get("skill", {}))
	request["recovered"] = true
	return plan_execution(request)


func resolution_completed(resolution_id: int) -> bool:
	return resolution_id >= 0 and _completed_resolution_ids.has(str(resolution_id))


func to_save_data() -> Dictionary:
	if _transition_checkpoint_owner == null:
		push_error("Execution Save v4 capture requires its registry-managed Transition checkpoint owner.")
		return {}
	var transition_state := {"transition_state_wire_version": TRANSITION_STATE_WIRE_VERSION}
	transition_state.merge(_transition_checkpoint_owner.to_save_data(), true)
	var runtime_state := {
		"schema_version": SAVE_SCHEMA_VERSION,
		"execution_wire_version": EXECUTION_WIRE_VERSION,
		"ruleset_id": SAVE_RULESET_ID,
		"transaction_sequence": _transaction_sequence,
		"completed_resolution_ids": _sorted_nonnegative_id_keys(_completed_resolution_ids),
		"inflight_resolution_ids": _sorted_nonnegative_id_keys(_inflight_resolution_ids),
		"inflight_execution_transactions": _sorted_execution_records(_inflight_execution_transactions),
		"pending_settlements": _sorted_execution_records(_pending_settlements),
		"transition_controller": transition_state,
	}
	var encoded := SaveWireCodecV4.encode_save_state(runtime_state)
	if not bool(encoded.get("ok", false)) or not (encoded.get("value") is Dictionary) \
			or not SemanticWireV1.is_closed_data(encoded.get("value")):
		push_error("Execution Save v4 capture failed: %s" % str(encoded.get("reason_code", "execution_save_v4_encode_failed")))
		return {}
	return (encoded.get("value") as Dictionary).duplicate(true)


func preflight_save_data(data: Dictionary) -> Dictionary:
	if _looks_like_legacy_execution_save(data):
		return _save_preflight_rejection(LEGACY_CLOSED_WIRE_REASON, true)
	if not SemanticWireV1.is_closed_data(data):
		return _save_preflight_rejection("execution_save_v4_not_closed_data")
	var decoded := SaveWireCodecV4.decode_save_state(data)
	if not bool(decoded.get("ok", false)) or not (decoded.get("value") is Dictionary):
		return _save_preflight_rejection(str(decoded.get("reason_code", "execution_save_v4_decode_invalid")))
	var runtime_state := decoded.get("value") as Dictionary
	var validation := _validate_runtime_save_v4(runtime_state)
	if not bool(validation.get("valid", false)):
		return _save_preflight_rejection(str(validation.get("reason", "execution_save_v4_invalid")))
	var canonical := SaveWireCodecV4.encode_save_state(runtime_state)
	if not bool(canonical.get("ok", false)) or not (canonical.get("value") is Dictionary) \
			or canonical.get("value") != data:
		return _save_preflight_rejection("execution_save_v4_not_canonical")
	return {
		"accepted": true,
		"reason": "",
		"reason_code": "execution_save_v4_valid",
		"normalized_state": (canonical.get("value") as Dictionary).duplicate(true),
	}


func apply_save_data(data: Dictionary) -> Dictionary:
	var preflight := preflight_save_data(data)
	if not bool(preflight.get("accepted", false)):
		return {
			"applied": false,
			"reason": str(preflight.get("reason_code", preflight.get("reason", "execution_save_v4_invalid"))),
			"reason_code": str(preflight.get("reason_code", preflight.get("reason", "execution_save_v4_invalid"))),
			"requires_backup": bool(preflight.get("requires_backup", false)),
		}
	var decoded := SaveWireCodecV4.decode_save_state(preflight.get("normalized_state", {}) as Dictionary)
	if not bool(decoded.get("ok", false)) or not (decoded.get("value") is Dictionary):
		return {"applied": false, "reason": "execution_save_v4_decode_invalid", "reason_code": "execution_save_v4_decode_invalid"}
	var normalized := (decoded.get("value") as Dictionary).duplicate(true)
	var completed := _validated_id_dictionary(normalized.get("completed_resolution_ids"), true)
	var inflight_transactions := _validated_execution_records(normalized.get("inflight_execution_transactions"), false)
	var pending_settlements := _validated_execution_records(normalized.get("pending_settlements"), true)
	var restored_sequence := int(normalized.get("transaction_sequence"))
	var transition_state := (normalized.get("transition_controller") as Dictionary).duplicate(true)
	transition_state.erase("transition_state_wire_version")
	var transition_apply := _transition_checkpoint_owner.apply_execution_save_transition_state(transition_state)
	if not bool(transition_apply.get("applied", false)):
		return {
			"applied": false,
			"reason": str(transition_apply.get("reason", "execution_transition_state_apply_failed")),
			"reason_code": str(transition_apply.get("reason", "execution_transition_state_apply_failed")),
		}
	_transaction_sequence = restored_sequence
	_completed_resolution_ids = (completed.get("values", {}) as Dictionary).duplicate(true)
	_inflight_execution_transactions = (inflight_transactions.get("values", {}) as Dictionary).duplicate(true)
	_inflight_resolution_ids.clear()
	for resolution_key_variant in _inflight_execution_transactions.keys():
		var resolution_key := str(resolution_key_variant)
		var transaction := _dictionary(_inflight_execution_transactions[resolution_key_variant])
		_inflight_resolution_ids[resolution_key] = int(transaction.get("execution_id", -1))
	_pending_settlements = (pending_settlements.get("values", {}) as Dictionary).duplicate(true)
	_last_resolution_id = -1
	_last_phase = "restored"
	_last_reason = "execution_lineage_restored"
	_last_summary = {}
	return {
		"applied": true,
		"reason": "execution_save_v4_restored",
		"reason_code": "execution_save_v4_restored",
		"transition_checkpoint_restored": true,
	}


func _validate_runtime_save_v4(data: Dictionary) -> Dictionary:
	if not _has_exact_keys(data, RUNTIME_SAVE_FIELDS):
		return {"valid": false, "reason": "execution_save_v4_runtime_shape_invalid"}
	if not (data.get("schema_version") is int) or int(data.get("schema_version")) != SAVE_SCHEMA_VERSION \
			or not (data.get("execution_wire_version") is int) or int(data.get("execution_wire_version")) != EXECUTION_WIRE_VERSION \
			or not (data.get("ruleset_id") is String) or str(data.get("ruleset_id")) != SAVE_RULESET_ID \
			or not (data.get("transaction_sequence") is int) or int(data.get("transaction_sequence")) < 0:
		return {"valid": false, "reason": "execution_save_v4_identity_invalid"}
	var completed := _validated_id_dictionary(data.get("completed_resolution_ids"), true)
	var inflight := _validated_id_dictionary(data.get("inflight_resolution_ids"), false)
	if not bool(completed.get("valid", false)) or not bool(inflight.get("valid", false)):
		return {"valid": false, "reason": "execution_lineage_invalid"}
	var inflight_transactions := _validated_execution_records(data.get("inflight_execution_transactions"), false)
	var pending_settlements := _validated_execution_records(data.get("pending_settlements"), true)
	if not bool(inflight_transactions.get("valid", false)):
		return {"valid": false, "reason": str(inflight_transactions.get("reason", "inflight_transactions_invalid"))}
	if not bool(pending_settlements.get("valid", false)):
		return {"valid": false, "reason": str(pending_settlements.get("reason", "pending_settlements_invalid"))}
	var authored_inflight_ids := _sorted_nonnegative_id_keys(inflight.get("values", {}) as Dictionary)
	var transaction_ids := _sorted_nonnegative_id_keys(inflight_transactions.get("values", {}) as Dictionary)
	if authored_inflight_ids != transaction_ids:
		return {"valid": false, "reason": "inflight_transaction_ids_mismatch"}
	var completed_values := completed.get("values", {}) as Dictionary
	var inflight_values := inflight_transactions.get("values", {}) as Dictionary
	var pending_values := pending_settlements.get("values", {}) as Dictionary
	var seen_execution_ids: Dictionary = {}
	for resolution_key_variant: Variant in inflight_values.keys():
		var resolution_key := str(resolution_key_variant)
		if completed_values.has(resolution_key) or pending_values.has(resolution_key):
			return {"valid": false, "reason": "execution_resolution_lineage_overlap"}
	for resolution_key_variant: Variant in pending_values.keys():
		if not completed_values.has(str(resolution_key_variant)):
			return {"valid": false, "reason": "pending_settlement_not_finalized"}
	for record_variant: Variant in inflight_values.values():
		var execution_id := int((record_variant as Dictionary).get("execution_id"))
		if execution_id > int(data.get("transaction_sequence")):
			return {"valid": false, "reason": "execution_sequence_precedes_record"}
		if seen_execution_ids.has(str(execution_id)):
			return {"valid": false, "reason": "execution_id_duplicate"}
		seen_execution_ids[str(execution_id)] = true
	for record_variant: Variant in pending_values.values():
		var pending_transaction := (record_variant as Dictionary).get("transaction") as Dictionary
		var pending_execution_id := int(pending_transaction.get("execution_id"))
		if pending_execution_id > int(data.get("transaction_sequence")):
			return {"valid": false, "reason": "execution_sequence_precedes_record"}
		if seen_execution_ids.has(str(pending_execution_id)):
			return {"valid": false, "reason": "execution_id_duplicate"}
		seen_execution_ids[str(pending_execution_id)] = true
	var transition_variant: Variant = data.get("transition_controller")
	if not (transition_variant is Dictionary):
		return {"valid": false, "reason": "execution_transition_state_invalid"}
	var transition_state := (transition_variant as Dictionary).duplicate(true)
	if not _has_exact_keys(transition_state, TRANSITION_STATE_FIELDS) \
			or not (transition_state.get("transition_state_wire_version") is int) \
			or int(transition_state.get("transition_state_wire_version")) != TRANSITION_STATE_WIRE_VERSION:
		return {"valid": false, "reason": "execution_transition_state_wire_version_invalid"}
	if _transition_checkpoint_owner == null:
		return {"valid": false, "reason": "execution_transition_state_owner_missing"}
	transition_state.erase("transition_state_wire_version")
	var transition_validation := _transition_checkpoint_owner.validate_execution_save_transition_state(transition_state)
	if not bool(transition_validation.get("valid", false)):
		return {"valid": false, "reason": str(transition_validation.get("reason", "execution_transition_state_invalid"))}
	return {"valid": true, "reason": ""}


func _looks_like_legacy_execution_save(data: Dictionary) -> bool:
	var schema_variant: Variant = data.get("schema_version")
	if schema_variant is int and LEGACY_SAVE_SCHEMA_VERSIONS.has(int(schema_variant)):
		return true
	return not data.has("execution_wire_version") \
			and data.has("transaction_sequence") \
			and data.has("completed_resolution_ids") \
			and data.has("inflight_resolution_ids")


func _save_preflight_rejection(reason_code: String, requires_backup := false) -> Dictionary:
	return {
		"accepted": false,
		"reason": reason_code,
		"reason_code": reason_code,
		"requires_backup": requires_backup,
		"normalized_state": {},
	}


func debug_snapshot() -> Dictionary:
	return {
		"service_ready": _configured,
		"service_authoritative": _configured,
		"execution_orchestration_authority": _configured,
		"queue_authority": false,
		"timing_authority": false,
		"inventory_authority": false,
		"concrete_effect_authority": false,
		"plan_count": _plan_count,
		"advance_count": _advance_count,
		"finalized_count": _finalized_count,
		"rejected_count": _rejected_count,
		"aborted_count": _aborted_count,
		"inflight_count": _inflight_resolution_ids.size(),
		"recoverable_inflight_count": _inflight_execution_transactions.size(),
		"pending_settlement_count": _pending_settlements.size(),
		"completed_count": _completed_resolution_ids.size(),
		"last_resolution_id": _last_resolution_id,
		"last_phase": _last_phase,
		"last_reason": _last_reason,
		"last_summary": _last_summary.duplicate(true),
		"legacy_main_orchestration_fallback_used": false,
		"save_schema_version": SAVE_SCHEMA_VERSION,
		"persistent_exact_once_lineage": true,
		"transition_checkpoint_bound": _transition_checkpoint_owner != null,
	}


func _sorted_nonnegative_id_keys(values: Dictionary) -> Array[int]:
	var result: Array[int] = []
	for key_variant in values.keys():
		var key := str(key_variant)
		if not key.is_valid_int():
			continue
		var value := int(key)
		if value >= 0:
			result.append(value)
	result.sort()
	return result


func _validated_id_dictionary(value: Variant, completed: bool) -> Dictionary:
	if not (value is Array):
		return {"valid": false, "values": {}}
	var result := {}
	for item in value as Array:
		if typeof(item) != TYPE_INT or int(item) < 0:
			return {"valid": false, "values": {}}
		var key := str(int(item))
		if result.has(key):
			return {"valid": false, "values": {}}
		if completed:
			result[key] = true
		else:
			result[key] = -1
	return {"valid": true, "values": result}


func _validated_execution_records(value: Variant, pending_settlement_records: bool) -> Dictionary:
	if not value is Array:
		return {"valid": false, "reason": "execution_records_not_array", "values": {}}
	var result: Dictionary = {}
	var previous_resolution_id := -1
	for record_variant in value as Array:
		if not record_variant is Dictionary or not _is_data_only(record_variant):
			return {"valid": false, "reason": "execution_record_not_data", "values": {}}
		var authored_record := record_variant as Dictionary
		if pending_settlement_records and not _has_exact_keys(authored_record, PENDING_SETTLEMENT_FIELDS):
			return {"valid": false, "reason": "pending_settlement_shape_invalid", "values": {}}
		var transaction := _dictionary(authored_record.get("transaction", {})) if pending_settlement_records else authored_record.duplicate(true)
		var transaction_validation := _validate_execution_transaction(transaction, not pending_settlement_records)
		if not bool(transaction_validation.get("valid", false)):
			return {"valid": false, "reason": str(transaction_validation.get("reason", "execution_transaction_invalid")), "values": {}}
		var resolution_id := int(transaction.get("resolution_id", -1))
		if resolution_id <= previous_resolution_id:
			return {"valid": false, "reason": "execution_records_not_strictly_sorted", "values": {}}
		previous_resolution_id = resolution_id
		var resolution_key := str(resolution_id)
		if result.has(resolution_key):
			return {"valid": false, "reason": "duplicate_execution_record", "values": {}}
		if pending_settlement_records:
			var finalized := _dictionary(authored_record.get("finalized", {}))
			var expected_binding := _settlement_binding(transaction, finalized)
			if not _has_exact_keys(finalized, FINALIZED_FIELDS) \
					or not _has_exact_keys(_dictionary(finalized.get("settlement_binding", {})), SETTLEMENT_BINDING_FIELDS) \
					or not (authored_record.get("resolution_id") is int) \
					or not (authored_record.get("execution_id") is int) \
					or not (finalized.get("completed") is bool) \
					or not bool(finalized.get("completed")) \
					or not (finalized.get("reason") is String) \
					or not (finalized.get("resolution_id") is int) \
					or not (finalized.get("execution_id") is int) \
					or not (finalized.get("countered") is bool) \
					or not (finalized.get("resolved") is bool) \
					or not (finalized.get("effect_dispatched") is bool) \
					or not (finalized.get("history_appended") is bool) \
					or not (finalized.get("continuation_kind") is String) \
					or int(finalized.get("resolution_id", -1)) != resolution_id \
					or int(authored_record.get("resolution_id", -1)) != resolution_id \
					or int(authored_record.get("execution_id", -1)) != int(transaction.get("execution_id", -1)) \
					or not (finalized.get("settlement_binding_fingerprint") is String) \
					or not SemanticWireV1.is_fingerprint(finalized.get("settlement_binding_fingerprint")) \
					or not _finalized_matches_settlement_binding(finalized, expected_binding) \
					or _dictionary(finalized.get("settlement_binding", {})) != expected_binding \
					or str(finalized.get("settlement_binding_fingerprint", "")) != _settlement_binding_fingerprint(expected_binding):
				return {"valid": false, "reason": "pending_settlement_binding_invalid", "values": {}}
			var settlement_binding := finalized.get("settlement_binding") as Dictionary
			for settlement_integer_field in ["resolution_id", "execution_id"]:
				if not (settlement_binding.get(settlement_integer_field) is int):
					return {"valid": false, "reason": "pending_settlement_binding_invalid", "values": {}}
			for settlement_boolean_field in ["resolved", "countered", "effect_dispatched", "history_appended"]:
				if not (settlement_binding.get(settlement_boolean_field) is bool):
					return {"valid": false, "reason": "pending_settlement_binding_invalid", "values": {}}
			if not (settlement_binding.get("continuation_kind") is String):
				return {"valid": false, "reason": "pending_settlement_binding_invalid", "values": {}}
			result[resolution_key] = authored_record.duplicate(true)
		else:
			result[resolution_key] = transaction.duplicate(true)
	return {"valid": true, "reason": "", "values": result}


func _validate_execution_transaction(transaction: Dictionary, require_pending_intent: bool) -> Dictionary:
	if transaction.is_empty() or not _is_data_only(transaction) \
			or not _has_exact_keys(transaction, EXECUTION_TRANSACTION_FIELDS):
		return {"valid": false, "reason": "execution_transaction_not_data"}
	for string_field in [
		"status",
		"reason",
		"entry_fingerprint",
		"execution_kind",
		"current_phase",
		"failure_reason",
		"continuation_kind",
		"counter_card_name",
		"target_kind",
		"handler_id",
	]:
		if not (transaction.get(string_field) is String):
			return {"valid": false, "reason": "execution_transaction_string_field_invalid"}
	for boolean_field in [
		"ready",
		"countered",
		"resolved",
		"history_required",
		"history_appended",
		"active_released",
		"effect_dispatched",
		"commitment_checked",
		"context_restored",
		"continuation_checked",
		"aftermath_required",
		"recovered",
	]:
		if not (transaction.get(boolean_field) is bool):
			return {"valid": false, "reason": "execution_transaction_boolean_field_invalid"}
	for integer_field in [
		"execution_id",
		"resolution_id",
		"counter_resolution_id",
		"monster_wager_decision_count_before",
	]:
		if not (transaction.get(integer_field) is int):
			return {"valid": false, "reason": "execution_transaction_integer_field_invalid"}
	for dictionary_field in ["next_intent", "active_entry", "skill", "selection_context"]:
		if not (transaction.get(dictionary_field) is Dictionary):
			return {"valid": false, "reason": "execution_transaction_dictionary_field_invalid"}
	var resolution_id := int(transaction.get("resolution_id", -1))
	var execution_id := int(transaction.get("execution_id", -1))
	if resolution_id < 0 or execution_id <= 0:
		return {"valid": false, "reason": "execution_transaction_identity_invalid"}
	var status := str(transaction.get("status", ""))
	if bool(transaction.get("ready")) != (status == STATUS_READY):
		return {"valid": false, "reason": "execution_transaction_ready_status_mismatch"}
	if require_pending_intent and not [STATUS_READY, STATUS_RETRYABLE].has(status):
		return {"valid": false, "reason": "inflight_transaction_status_invalid"}
	if not require_pending_intent and (status != STATUS_READY \
			or not bool(transaction.get("active_released", false)) \
			or not bool(transaction.get("commitment_checked", false)) \
			or not bool(transaction.get("history_appended", false))):
		return {"valid": false, "reason": "finalized_transaction_state_invalid"}
	var active_entry := transaction.get("active_entry") as Dictionary
	if active_entry.is_empty() \
			or not (active_entry.get("resolution_id") is int) \
			or int(active_entry.get("resolution_id")) != resolution_id \
			or not SemanticWireV1.is_fingerprint(transaction.get("entry_fingerprint")) \
			or str(transaction.get("entry_fingerprint")) != JSON.stringify(active_entry).sha256_text():
		return {"valid": false, "reason": "execution_transaction_entry_fingerprint_invalid"}
	if active_entry.has("v06_facility_action"):
		var facility_binding_variant: Variant = active_entry.get("v06_facility_action")
		if not (facility_binding_variant is Dictionary) \
				or not bool(FacilityBinding.validation_report(facility_binding_variant as Dictionary).get("valid", false)) \
				or int((facility_binding_variant as Dictionary).get("resolution_id", -1)) != resolution_id:
			return {"valid": false, "reason": "execution_transaction_facility_binding_invalid"}
	var next_intent := _dictionary(transaction.get("next_intent", {}))
	if require_pending_intent:
		var intent_type := str(next_intent.get("intent_type", ""))
		if not _has_exact_keys(next_intent, NEXT_INTENT_FIELDS) \
				or not (next_intent.get("intent_type") is String) \
				or not (next_intent.get("execution_id") is int) \
				or not (next_intent.get("resolution_id") is int) \
				or not (next_intent.get("handler_id") is String) \
				or not SUPPORTED_INTENTS.has(intent_type) \
				or int(next_intent.get("execution_id", -1)) != execution_id \
				or int(next_intent.get("resolution_id", -1)) != resolution_id:
			return {"valid": false, "reason": "inflight_next_intent_invalid"}
		if intent_type == INTENT_DISPATCH_EFFECT:
			if str(next_intent.get("handler_id")) != str(transaction.get("handler_id")):
				return {"valid": false, "reason": "inflight_next_intent_handler_invalid"}
		elif not str(next_intent.get("handler_id")).is_empty():
			return {"valid": false, "reason": "inflight_next_intent_handler_invalid"}
	elif not next_intent.is_empty():
		return {"valid": false, "reason": "finalized_transaction_has_next_intent"}
	var completed_intents: Variant = transaction.get("completed_intents", [])
	if not completed_intents is Array:
		return {"valid": false, "reason": "completed_intents_invalid"}
	var seen_intents: Dictionary = {}
	var previous_rank := -1
	for intent_variant in completed_intents as Array:
		var completed_intent := str(intent_variant)
		var completed_rank := _intent_order_rank(completed_intent)
		if not intent_variant is String \
				or not SUPPORTED_INTENTS.has(completed_intent) \
				or seen_intents.has(completed_intent):
			return {"valid": false, "reason": "completed_intent_invalid"}
		if completed_rank <= previous_rank:
			return {"valid": false, "reason": "completed_intents_out_of_order"}
		seen_intents[completed_intent] = true
		previous_rank = completed_rank
	var current_phase := str(transaction.get("current_phase"))
	if (completed_intents as Array).is_empty():
		if current_phase != "planned":
			return {"valid": false, "reason": "execution_current_phase_invalid"}
	else:
		var last_completed_intent := str((completed_intents as Array).back())
		var next_phase := str(next_intent.get("intent_type", ""))
		if current_phase != last_completed_intent \
				and not (status == STATUS_RETRYABLE and current_phase == next_phase):
			return {"valid": false, "reason": "execution_current_phase_invalid"}
	if require_pending_intent:
		var next_intent_type := str(next_intent.get("intent_type", ""))
		var next_rank := _intent_order_rank(next_intent_type)
		if seen_intents.has(next_intent_type) or next_rank <= previous_rank:
			return {"valid": false, "reason": "next_intent_order_invalid"}
		if next_rank > _intent_order_rank(INTENT_COUNTER_CHECK) and not seen_intents.has(INTENT_COUNTER_CHECK):
			return {"valid": false, "reason": "next_intent_missing_counter_check"}
		if next_rank > _intent_order_rank(INTENT_RELEASE_ACTIVE) and not seen_intents.has(INTENT_RELEASE_ACTIVE):
			return {"valid": false, "reason": "next_intent_missing_active_release"}
		if next_intent_type == INTENT_DISPATCH_EFFECT and not seen_intents.has(INTENT_REVALIDATE_TARGET):
			return {"valid": false, "reason": "dispatch_intent_missing_target_validation"}
		if next_rank >= _intent_order_rank(INTENT_APPEND_HISTORY) and not seen_intents.has(INTENT_RESTORE_CONTEXT):
			return {"valid": false, "reason": "history_intent_missing_context_restore"}
		if [INTENT_START_NEXT, INTENT_FINISH_BATCH].has(next_intent_type) and not seen_intents.has(INTENT_APPEND_HISTORY):
			return {"valid": false, "reason": "continuation_intent_missing_history"}
		if next_intent_type == INTENT_PROMOTE_NEXT_BATCH and not seen_intents.has(INTENT_FINISH_BATCH):
			return {"valid": false, "reason": "promotion_intent_missing_batch_finish"}
		if status == STATUS_RETRYABLE and next_intent_type not in [
			INTENT_FINISH_COMMITMENT,
			INTENT_APPEND_HISTORY,
		]:
			return {"valid": false, "reason": "retryable_intent_invalid"}
		if status == STATUS_RETRYABLE \
				and next_intent_type == INTENT_FINISH_COMMITMENT \
				and bool(transaction.get("commitment_checked", false)):
			return {"valid": false, "reason": "retryable_commitment_already_checked"}
	if bool(transaction.get("active_released", false)) != seen_intents.has(INTENT_RELEASE_ACTIVE):
		return {"valid": false, "reason": "active_release_flag_inconsistent"}
	if bool(transaction.get("history_appended", false)) != seen_intents.has(INTENT_APPEND_HISTORY):
		return {"valid": false, "reason": "history_flag_inconsistent"}
	if (bool(transaction.get("effect_dispatched", false)) or bool(transaction.get("resolved", false))) and not seen_intents.has(INTENT_DISPATCH_EFFECT):
		return {"valid": false, "reason": "effect_flag_inconsistent"}
	if bool(transaction.get("resolved", false)) and not bool(transaction.get("effect_dispatched", false)):
		return {"valid": false, "reason": "resolved_without_effect_dispatch"}
	if bool(transaction.get("countered", false)) and not seen_intents.has(INTENT_COUNTER_CHECK):
		return {"valid": false, "reason": "counter_flag_inconsistent"}
	if bool(transaction.get("commitment_checked", false)) and not seen_intents.has(INTENT_FINISH_COMMITMENT):
		return {"valid": false, "reason": "commitment_flag_inconsistent"}
	if bool(transaction.get("context_restored", false)) and not seen_intents.has(INTENT_RESTORE_CONTEXT):
		return {"valid": false, "reason": "context_flag_inconsistent"}
	return {"valid": true, "reason": ""}


func _sorted_execution_records(values: Dictionary) -> Array:
	var result: Array = []
	for resolution_id in _sorted_nonnegative_id_keys(values):
		var record := _dictionary(values.get(str(resolution_id), {}))
		if not record.is_empty():
			result.append(record)
	return result


func _intent_order_rank(intent_type: String) -> int:
	return {
		INTENT_COUNTER_CHECK: 0,
		INTENT_RELEASE_ACTIVE: 1,
		INTENT_FINISH_PRESENTATION: 2,
		INTENT_REVALIDATE_REQUIREMENT: 3,
		INTENT_REVALIDATE_TARGET: 4,
		INTENT_DISPATCH_EFFECT: 5,
		INTENT_FINISH_COMMITMENT: 6,
		INTENT_CREATE_AFTERMATH: 7,
		INTENT_RESTORE_CONTEXT: 8,
		INTENT_APPEND_HISTORY: 9,
		INTENT_START_NEXT: 10,
		INTENT_FINISH_BATCH: 10,
		INTENT_PROMOTE_NEXT_BATCH: 11,
	}.get(intent_type, -1)


func _intent(intent_type: String, execution_id: int, resolution_id: int, skill: Dictionary) -> Dictionary:
	return {
		"intent_type": intent_type,
		"execution_id": execution_id,
		"resolution_id": resolution_id,
		"handler_id": _handler_id(skill, "none") if intent_type == INTENT_DISPATCH_EFFECT else "",
	}


func _intent_for(transaction: Dictionary, intent_type: String) -> Dictionary:
	var intent := _intent(intent_type, int(transaction.get("execution_id", -1)), int(transaction.get("resolution_id", -1)), _dictionary(transaction.get("skill", {})))
	if intent_type == INTENT_DISPATCH_EFFECT:
		intent["handler_id"] = str(transaction.get("handler_id", intent.get("handler_id", "")))
	return intent


func _execution_kind(skill: Dictionary, target_kind: String) -> String:
	var kind := str(skill.get("kind", ""))
	if target_kind == "monster" or target_kind == "player":
		return "targeted"
	return "normal"


func _handler_id(skill: Dictionary, target_kind: String) -> String:
	if target_kind == "monster":
		return "target_monster"
	if target_kind == "player":
		return "target_player"
	var machine: Dictionary = skill.get("machine", {}) if skill.get("machine", {}) is Dictionary else {}
	var effect_kind := str(machine.get("effect_kind", ""))
	if effect_kind in ["global_order_budget", "global_supply_spawn"]:
		return effect_kind
	return str(skill.get("kind", "missing_skill"))


func _transaction_summary(transaction: Dictionary) -> Dictionary:
	return {
		"resolution_id": int(transaction.get("resolution_id", -1)),
		"execution_kind": str(transaction.get("execution_kind", "")),
		"current_phase": str(transaction.get("current_phase", "")),
		"next_intent": str(_dictionary(transaction.get("next_intent", {})).get("intent_type", "")),
		"countered": bool(transaction.get("countered", false)),
		"resolved": bool(transaction.get("resolved", false)),
		"effect_dispatched": bool(transaction.get("effect_dispatched", false)),
		"history_appended": bool(transaction.get("history_appended", false)),
		"continuation_kind": str(transaction.get("continuation_kind", "normal")),
	}


func _settlement_binding(transaction: Dictionary, _finalized: Dictionary = {}) -> Dictionary:
	return {
		"resolution_id": int(transaction.get("resolution_id", -1)),
		"execution_id": int(transaction.get("execution_id", -1)),
		"resolved": bool(transaction.get("resolved", false)),
		"countered": bool(transaction.get("countered", false)),
		"effect_dispatched": bool(transaction.get("effect_dispatched", false)),
		"history_appended": bool(transaction.get("history_appended", false)),
		"continuation_kind": str(transaction.get("continuation_kind", "normal")),
	}


func _settlement_binding_fingerprint(binding: Dictionary) -> String:
	return JSON.stringify(binding).sha256_text()


func _finalized_matches_settlement_binding(finalized: Dictionary, binding: Dictionary) -> bool:
	return int(finalized.get("resolution_id", -1)) == int(binding.get("resolution_id", -2)) \
		and int(finalized.get("execution_id", -1)) == int(binding.get("execution_id", -2)) \
		and bool(finalized.get("resolved", false)) == bool(binding.get("resolved", false)) \
		and bool(finalized.get("countered", false)) == bool(binding.get("countered", false)) \
		and bool(finalized.get("effect_dispatched", false)) == bool(binding.get("effect_dispatched", false)) \
		and bool(finalized.get("history_appended", false)) == bool(binding.get("history_appended", false)) \
		and str(finalized.get("continuation_kind", "")) == str(binding.get("continuation_kind", "normal"))


func _store_inflight_transaction(transaction: Dictionary) -> void:
	var resolution_id := int(transaction.get("resolution_id", -1))
	var execution_id := int(transaction.get("execution_id", -1))
	if resolution_id < 0 or execution_id <= 0:
		return
	var resolution_key := str(resolution_id)
	_inflight_resolution_ids[resolution_key] = execution_id
	_inflight_execution_transactions[resolution_key] = transaction.duplicate(true)


func _abort_transaction(transaction: Dictionary, reason: String) -> Dictionary:
	var aborted := transaction.duplicate(true)
	aborted["status"] = STATUS_ABORTED
	aborted["ready"] = false
	aborted["reason"] = reason
	aborted["failure_reason"] = reason
	aborted["next_intent"] = {}
	var resolution_id := int(aborted.get("resolution_id", -1))
	_inflight_resolution_ids.erase(str(resolution_id))
	_inflight_execution_transactions.erase(str(resolution_id))
	_aborted_count += 1
	_last_resolution_id = resolution_id
	_last_phase = "aborted"
	_last_reason = reason
	_last_summary = _transaction_summary(aborted)
	return aborted


func _plan_rejection(reason: String, resolution_id: int = -1) -> Dictionary:
	_rejected_count += 1
	_last_resolution_id = resolution_id
	_last_phase = "rejected"
	_last_reason = reason
	return {
		"status": STATUS_REJECTED,
		"ready": false,
		"reason": reason,
		"resolution_id": resolution_id,
		"next_intent": {},
		"completed_intents": [],
	}


func _finalize_rejection(reason: String, resolution_id: int = -1) -> Dictionary:
	_rejected_count += 1
	_last_resolution_id = resolution_id
	_last_phase = "finalize_rejected"
	_last_reason = reason
	return {
		"completed": false,
		"reason": reason,
		"resolution_id": resolution_id,
	}


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key_variant: Variant in expected:
		if not value.has(str(key_variant)):
			return false
	return true


func _is_data_only(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return true
		TYPE_ARRAY:
			for item in value as Array:
				if not _is_data_only(item):
					return false
			return true
		TYPE_DICTIONARY:
			for key in (value as Dictionary).keys():
				if not _is_data_only(key) or not _is_data_only((value as Dictionary)[key]):
					return false
			return true
	return false
