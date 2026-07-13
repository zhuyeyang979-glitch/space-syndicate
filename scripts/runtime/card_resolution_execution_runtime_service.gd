@tool
extends Node
class_name CardResolutionExecutionRuntimeService

const STATUS_READY := "ready"
const STATUS_REJECTED := "rejected"
const STATUS_ABORTED := "aborted"

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

var _configured := false
var _transaction_sequence := 0
var _plan_count := 0
var _advance_count := 0
var _finalized_count := 0
var _rejected_count := 0
var _aborted_count := 0
var _completed_resolution_ids: Dictionary = {}
var _inflight_resolution_ids: Dictionary = {}
var _last_resolution_id := -1
var _last_phase := ""
var _last_reason := ""
var _last_summary: Dictionary = {}


func configure(_config: Dictionary = {}) -> void:
	_configured = true
	reset_state()


func reset_state() -> void:
	_transaction_sequence = 0
	_plan_count = 0
	_advance_count = 0
	_finalized_count = 0
	_rejected_count = 0
	_aborted_count = 0
	_completed_resolution_ids.clear()
	_inflight_resolution_ids.clear()
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
		"forced_decision_count_before": maxi(0, int(request.get("forced_decision_count_before", 0))),
		"recovered": bool(request.get("recovered", false)),
	}
	_inflight_resolution_ids[resolution_key] = execution_id
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
		INTENT_FINISH_COMMITMENT:
			updated["commitment_checked"] = bool(receipt.get("committed", false))
			updated["next_intent"] = _intent_for(updated, INTENT_CREATE_AFTERMATH if bool(updated.get("countered", false)) or bool(updated.get("aftermath_required", false)) else INTENT_RESTORE_CONTEXT)
		INTENT_CREATE_AFTERMATH:
			var active_entry := _dictionary(updated.get("active_entry", {}))
			var entry_patch := _dictionary(receipt.get("entry_patch", {}))
			active_entry.merge(entry_patch, true)
			updated["active_entry"] = active_entry
			updated["next_intent"] = _intent_for(updated, INTENT_RESTORE_CONTEXT)
		INTENT_RESTORE_CONTEXT:
			updated["context_restored"] = bool(receipt.get("restored", false))
			updated["next_intent"] = _intent_for(updated, INTENT_APPEND_HISTORY)
		INTENT_APPEND_HISTORY:
			if not bool(receipt.get("appended", false)):
				return _abort_transaction(updated, str(receipt.get("reason", "history_append_failed")))
			updated["history_appended"] = true
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
	return updated


func finalize_execution(transaction: Dictionary) -> Dictionary:
	if not _configured or not _is_data_only(transaction):
		return _finalize_rejection("invalid_finalize_request")
	var resolution_id := int(transaction.get("resolution_id", -1))
	var resolution_key := str(resolution_id)
	if _completed_resolution_ids.has(resolution_key):
		return _finalize_rejection("already_completed", resolution_id)
	if str(transaction.get("status", "")) != STATUS_READY:
		return _finalize_rejection(str(transaction.get("failure_reason", transaction.get("reason", "execution_aborted"))), resolution_id)
	if not _dictionary(transaction.get("next_intent", {})).is_empty():
		return _finalize_rejection("execution_incomplete", resolution_id)
	if not bool(transaction.get("active_released", false)) or not bool(transaction.get("history_appended", false)):
		return _finalize_rejection("execution_incomplete", resolution_id)
	_completed_resolution_ids[resolution_key] = true
	_inflight_resolution_ids.erase(resolution_key)
	_finalized_count += 1
	_last_resolution_id = resolution_id
	_last_phase = "finalized"
	_last_reason = "completed"
	_last_summary = _transaction_summary(transaction)
	return {
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
		"completed_count": _completed_resolution_ids.size(),
		"last_resolution_id": _last_resolution_id,
		"last_phase": _last_phase,
		"last_reason": _last_reason,
		"last_summary": _last_summary.duplicate(true),
		"legacy_main_orchestration_fallback_used": false,
	}


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
	if kind == "area_trade_contract":
		return "contract_continuation"
	if target_kind == "monster" or target_kind == "player":
		return "targeted"
	return "normal"


func _handler_id(skill: Dictionary, target_kind: String) -> String:
	if target_kind == "monster":
		return "target_monster"
	if target_kind == "player":
		return "target_player"
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


func _abort_transaction(transaction: Dictionary, reason: String) -> Dictionary:
	var aborted := transaction.duplicate(true)
	aborted["status"] = STATUS_ABORTED
	aborted["ready"] = false
	aborted["reason"] = reason
	aborted["failure_reason"] = reason
	aborted["next_intent"] = {}
	var resolution_id := int(aborted.get("resolution_id", -1))
	_inflight_resolution_ids.erase(str(resolution_id))
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
