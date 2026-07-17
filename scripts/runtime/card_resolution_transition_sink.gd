@tool
extends Node
class_name CardResolutionTransitionSink

const INTENT_GUARD := 20
const SUPPORTED_TRANSITIONS := {
	"show_active": true,
	"begin_counter": true,
	"complete_active": true,
	"start_next": true,
	"show_group_window": true,
	"enter_public_bid": true,
	"enter_lock": true,
	"all_ready_public_bid": true,
	"all_ready_lock": true,
	"all_ready_lock_batch": true,
	"lock_batch": true,
	"hide_overlay": true,
}

var _controller: CardResolutionRuntimeController
var _queue: CardResolutionQueueRuntimeService
var _world_session: WorldSessionState
var _execution: CardResolutionExecutionRuntimeService
var _execution_port: CardResolutionExecutionWorldBridge
var _presentation: CardResolutionPresentationPort
var _eligibility: CardPlayEligibilityRuntimeService
var _monster: MonsterRuntimeController
var _configured := false
var _batch_count := 0
var _applied_count := 0
var _duplicate_count := 0
var _rejected_count := 0
var _last_trace: Array[String] = []
var _last_receipt: Dictionary = {}
var _test_fail_before_command_id := ""
var _test_fail_after_handler_command_id := ""


func configure(
	controller: CardResolutionRuntimeController,
	queue: CardResolutionQueueRuntimeService,
	world_session: WorldSessionState,
	execution: CardResolutionExecutionRuntimeService,
	execution_port: CardResolutionExecutionWorldBridge,
	presentation: CardResolutionPresentationPort,
	eligibility: CardPlayEligibilityRuntimeService,
	monster: MonsterRuntimeController
) -> void:
	_controller = controller
	_queue = queue
	_world_session = world_session
	_execution = execution
	_execution_port = execution_port
	_presentation = presentation
	_eligibility = eligibility
	_monster = monster
	_configured = _controller != null \
		and _queue != null \
		and _world_session != null \
		and _execution != null \
		and _execution_port != null \
		and _presentation != null \
		and _eligibility != null


func apply_transition_batch(commands: Array) -> Dictionary:
	_last_trace = []
	if not _configured:
		return _reject_batch("transition_sink_not_configured")
	# A fully-applied replay is still an authored batch. Validate its complete
	# producer binding before consulting exact-once lineage so a subset,
	# reordering, duplicate, stale revision, or mixed batch cannot become a
	# successful replay receipt.
	var validation := _controller.validate_transition_batch(commands)
	if not bool(validation.get("valid", false)):
		return _reject_batch(str(validation.get("reason", "transition_batch_invalid")), validation)
	var replay_receipt := _fully_applied_replay_receipt(commands)
	if bool(replay_receipt.get("replayed", false)):
		_duplicate_count += commands.size()
		_last_trace = (replay_receipt.get("trace", []) as Array).duplicate()
		_last_receipt = replay_receipt.duplicate(true)
		return replay_receipt
	_batch_count += 1
	var receipts: Array = []
	for command_variant in commands:
		var command := (command_variant as Dictionary).duplicate(true)
		var command_id := str(command.get("command_id", ""))
		var command_fingerprint := str(command.get("command_fingerprint", ""))
		var applied := _controller.transition_command_applied(command_id, command_fingerprint)
		if bool(applied.get("applied", false)):
			_duplicate_count += 1
			_last_trace.append("duplicate:%s" % str(command.get("transition", "")))
			receipts.append({
				"handled": true,
				"duplicate": true,
				"command_id": command_id,
				"transition": str(command.get("transition", "")),
			})
			continue
		if str(applied.get("reason", "")) == "applied_fingerprint_mismatch":
			return _reject_batch("command_binding_mismatch", {"command_id": command_id}, receipts)
		if command_id == _test_fail_before_command_id:
			_test_fail_before_command_id = ""
			return _reject_batch("fault_injected_before_dispatch", {"command_id": command_id}, receipts)
		var handler_receipt := _apply_transition(command)
		if not bool(handler_receipt.get("handled", false)):
			return _reject_batch(str(handler_receipt.get("reason", "transition_handler_failed")), handler_receipt, receipts)
		if command_id == _test_fail_after_handler_command_id:
			_test_fail_after_handler_command_id = ""
			return _reject_batch("fault_injected_after_handler", {"command_id": command_id}, receipts)
		var lineage := _controller.mark_transition_command_applied(command, handler_receipt)
		if not bool(lineage.get("accepted", false)):
			return _reject_batch(str(lineage.get("reason", "transition_lineage_rejected")), lineage, receipts)
		_applied_count += 1
		_last_trace.append(str(command.get("transition", "")))
		var public_receipt := {
			"handled": true,
			"duplicate": false,
			"command_id": command_id,
			"transition": str(command.get("transition", "")),
			"batch_revision": int(command.get("batch_revision", -1)),
			"order_index": int(command.get("order_index", -1)),
		}
		receipts.append(public_receipt)
	var result := {
		"handled": true,
		"reason": "",
		"batch_revision": int(validation.get("batch_revision", -1)),
		"command_count": commands.size(),
		"receipts": receipts,
		"trace": _last_trace.duplicate(),
	}
	_last_receipt = result.duplicate(true)
	return result


func inject_test_failure_before(command_id: String) -> void:
	_test_fail_before_command_id = command_id


func inject_test_failure_after_handler(command_id: String) -> void:
	_test_fail_after_handler_command_id = command_id


func clear_test_failures() -> void:
	_test_fail_before_command_id = ""
	_test_fail_after_handler_command_id = ""


func debug_snapshot() -> Dictionary:
	return {
		"sink_ready": _configured,
		"sole_frame_command_consumer": _configured,
		"owns_queue": false,
		"owns_timing": false,
		"owns_effects": false,
		"owns_presentation": false,
		"holds_main_reference": false,
		"dynamic_main_access_count": 0,
		"supported_transition_count": SUPPORTED_TRANSITIONS.size(),
		"batch_count": _batch_count,
		"applied_count": _applied_count,
		"duplicate_count": _duplicate_count,
		"rejected_count": _rejected_count,
		"last_trace": _last_trace.duplicate(),
		"last_receipt": _last_receipt.duplicate(true),
	}


func _apply_transition(command: Dictionary) -> Dictionary:
	var transition := str(command.get("transition", ""))
	if not SUPPORTED_TRANSITIONS.has(transition):
		return {"handled": false, "reason": "unsupported_transition"}
	match transition:
		"show_active":
			return _show_active(command)
		"begin_counter":
			return _begin_counter(command)
		"complete_active":
			return _complete_active(command)
		"start_next":
			return _start_next()
		"show_group_window":
			return _show_group_window(command)
		"lock_batch":
			return _lock_batch()
		"hide_overlay":
			_presentation.set_overlay_state({"visible": false, "phase": "idle", "resolution_id": -1})
			return {"handled": true, "reason": "overlay_hidden"}
		_:
			return _publish_phase_event(command)


func _show_active(command: Dictionary) -> Dictionary:
	var entry := _queue.active_entry()
	if entry.is_empty():
		return {"handled": false, "reason": "active_entry_missing"}
	var skill := _dictionary(entry.get("skill", {}))
	_presentation.set_overlay_state({
		"visible": true,
		"phase": str(command.get("stage", "reveal")),
		"resolution_id": int(entry.get("resolution_id", -1)),
		"remaining_seconds": maxf(0.0, float(command.get("remaining", 0.0))),
		"card_name": str(skill.get("name", "卡牌")),
	})
	return {"handled": true, "reason": "active_presentation_updated"}


func _begin_counter(command: Dictionary) -> Dictionary:
	var entry := _queue.active_entry()
	if entry.is_empty():
		return {"handled": false, "reason": "active_entry_missing"}
	var skill := _dictionary(entry.get("skill", {}))
	_presentation.set_overlay_state({
		"visible": true,
		"phase": "counter",
		"resolution_id": int(entry.get("resolution_id", -1)),
		"remaining_seconds": maxf(0.0, float(command.get("remaining", 0.0))),
		"card_name": str(skill.get("name", "卡牌")),
	})
	var published := _presentation.publish_public_event({
		"event_id": str(command.get("command_id", "")),
		"event_kind": "card_counter_window",
		"resolution_id": int(entry.get("resolution_id", -1)),
		"card_name": str(skill.get("name", "卡牌")),
		"phase": "counter",
		"status": "opened",
		"remaining_seconds": maxf(0.0, float(command.get("remaining", 0.0))),
		"summary": "玩家互动响应窗口已经打开。",
	})
	return {"handled": bool(published.get("published", false)), "reason": str(published.get("reason", ""))}


func _complete_active(command: Dictionary) -> Dictionary:
	var resolution_id := int(command.get("resolution_id", -1))
	var pending_settlement := _execution.pending_settlement(resolution_id)
	if not pending_settlement.is_empty():
		return _settle_pending_execution(pending_settlement)
	if _execution.resolution_completed(resolution_id):
		return {"handled": true, "reason": "execution_already_completed", "resolution_id": resolution_id}
	var transaction: Dictionary
	if _execution.has_inflight_execution(resolution_id):
		transaction = _execution.resume_inflight_execution(resolution_id)
	else:
		var entry := _queue.active_entry()
		if entry.is_empty() or int(entry.get("resolution_id", -1)) != resolution_id:
			return {"handled": false, "reason": "active_resolution_mismatch"}
		var skill := _dictionary(entry.get("skill", {}))
		if skill.is_empty():
			return {"handled": false, "reason": "active_skill_missing"}
		var monster_count := _monster.roster_snapshot(true).size() if _monster != null else 0
		var target := _eligibility.target_status({"skill": skill}, {
			"player_count": _world_session.players.size(),
			"monster_count": monster_count,
		})
		transaction = _execution.plan_execution({
			"active_entry": entry,
			"skill": skill,
			"target_kind": str(target.get("target_kind", "none")),
			"forced_decision_count_before": _monster.active_wagers_snapshot().size() if _monster != null else 0,
			"selection_context": _entry_selection_context(entry),
		})
	if not bool(transaction.get("ready", false)):
		if str(transaction.get("reason", "")) == "already_completed":
			return {"handled": true, "reason": "execution_already_completed", "resolution_id": resolution_id}
		return {"handled": false, "reason": str(transaction.get("reason", "execution_plan_rejected"))}
	var intent_trace: Array[String] = []
	var guard := 0
	while not _dictionary(transaction.get("next_intent", {})).is_empty() and guard < INTENT_GUARD:
		guard += 1
		var intent_type := str(_dictionary(transaction.get("next_intent", {})).get("intent_type", ""))
		intent_trace.append(intent_type)
		var receipt := _execution_port.apply_intent(transaction)
		transaction = _execution.advance_execution(transaction, receipt)
		if str(transaction.get("status", "")) != CardResolutionExecutionRuntimeService.STATUS_READY:
			break
	if guard >= INTENT_GUARD or str(transaction.get("status", "")) != CardResolutionExecutionRuntimeService.STATUS_READY:
		return {
			"handled": false,
			"reason": str(transaction.get("failure_reason", transaction.get("reason", "execution_intent_guard"))),
			"intent_trace": intent_trace,
		}
	var finalized := _execution.finalize_execution(transaction)
	if not bool(finalized.get("completed", false)):
		return {"handled": false, "reason": str(finalized.get("reason", "execution_finalize_failed")), "intent_trace": intent_trace}
	var pending_registration := _execution.ensure_pending_settlement(transaction, finalized)
	if not bool(pending_registration.get("registered", false)):
		return {"handled": false, "reason": str(pending_registration.get("reason", "pending_settlement_registration_failed")), "intent_trace": intent_trace}
	var settlement_result := _settle_pending_execution(_execution.pending_settlement(resolution_id))
	if not bool(settlement_result.get("handled", false)):
		settlement_result["intent_trace"] = intent_trace
		return settlement_result
	return {
		"handled": true,
		"reason": "execution_completed",
		"resolution_id": resolution_id,
		"resolved": bool(finalized.get("resolved", false)),
		"countered": bool(finalized.get("countered", false)),
		"intent_trace": intent_trace,
	}


func _settle_pending_execution(pending: Dictionary) -> Dictionary:
	var resolution_id := int(pending.get("resolution_id", -1))
	var transaction := _dictionary(pending.get("transaction", {}))
	var finalized := _dictionary(pending.get("finalized", {}))
	if resolution_id < 0 or transaction.is_empty() or finalized.is_empty():
		return {"handled": false, "reason": "pending_settlement_invalid", "resolution_id": resolution_id}
	var settlement := _execution_port.settle_finalized_execution(transaction, finalized)
	if not bool(settlement.get("settled", false)):
		return {
			"handled": false,
			"reason": str(settlement.get("reason", "execution_settlement_failed")),
			"resolution_id": resolution_id,
			"settlement_pending": true,
		}
	var completion := _execution.complete_pending_settlement(resolution_id, settlement)
	if not bool(completion.get("completed", false)):
		return {"handled": false, "reason": str(completion.get("reason", "settlement_finalize_failed")), "resolution_id": resolution_id}
	return {
		"handled": true,
		"reason": "settlement_completed",
		"resolution_id": resolution_id,
		"resolved": bool(finalized.get("resolved", false)),
		"countered": bool(finalized.get("countered", false)),
		"settlement_pending": false,
	}


func _start_next() -> Dictionary:
	if not _queue.active_entry().is_empty():
		return {"handled": true, "reason": "active_already_started"}
	var receipt := _execution_port.start_next_transition()
	return {
		"handled": bool(receipt.get("started", false)) or bool(receipt.get("batch_finished", false)),
		"reason": str(receipt.get("reason", "")),
	}


func _show_group_window(command: Dictionary) -> Dictionary:
	var phase := str(command.get("window_phase", command.get("phase", "planning")))
	_presentation.set_overlay_state({
		"visible": true,
		"phase": phase,
		"resolution_id": -1,
		"remaining_seconds": maxf(0.0, float(command.get("remaining", 0.0))),
		"card_name": "",
	})
	return {"handled": true, "reason": "group_window_presentation_updated", "phase": phase}


func _lock_batch() -> Dictionary:
	if not _queue.active_entry().is_empty():
		return {"handled": true, "reason": "batch_already_started"}
	var receipt := _execution_port.lock_batch_transition()
	return {"handled": bool(receipt.get("handled", false)), "reason": str(receipt.get("reason", ""))}


func _publish_phase_event(command: Dictionary) -> Dictionary:
	var transition := str(command.get("transition", ""))
	var summary: String = str({
		"enter_public_bid": "共享卡牌窗进入公开展示阶段。",
		"enter_lock": "共享卡牌窗进入锁牌阶段。",
		"all_ready_public_bid": "所有席位已经完成规划。",
		"all_ready_lock": "所有席位已经完成公开展示。",
		"all_ready_lock_batch": "所有席位已经确认锁牌。",
	}.get(transition, "卡牌结算阶段已更新。"))
	var published := _presentation.publish_public_event({
		"event_id": str(command.get("command_id", "")),
		"event_kind": "card_resolution_phase",
		"phase": str(command.get("phase", "")),
		"status": transition,
		"summary": summary,
	})
	return {"handled": bool(published.get("published", false)), "reason": str(published.get("reason", ""))}


func _entry_selection_context(entry: Dictionary) -> Dictionary:
	return {
		"selected_district": int(entry.get("selected_district", -1)),
		"selected_trade_product": str(entry.get("selected_trade_product", "")),
		"contract_source_district": int(entry.get("contract_source_district", -1)),
		"contract_target_district": int(entry.get("contract_target_district", -1)),
		"play_requirement_district": int(entry.get("play_requirement_district", -1)),
	}


func _reject_batch(reason: String, details: Dictionary = {}, prior_receipts: Array = []) -> Dictionary:
	_rejected_count += 1
	var result := {
		"handled": false,
		"reason": reason,
		"receipts": prior_receipts.duplicate(true),
		"trace": _last_trace.duplicate(),
	}
	if not details.is_empty():
		result["details"] = details.duplicate(true)
	_last_receipt = result.duplicate(true)
	return result


func _fully_applied_replay_receipt(commands: Array) -> Dictionary:
	if commands.is_empty():
		return {"replayed": false}
	var receipts: Array = []
	var trace: Array[String] = []
	for command_variant in commands:
		if not (command_variant is Dictionary):
			return {"replayed": false}
		var command := command_variant as Dictionary
		var applied := _controller.transition_command_applied(
			str(command.get("command_id", "")),
			str(command.get("command_fingerprint", ""))
		)
		if not bool(applied.get("applied", false)):
			return {"replayed": false}
		var transition := str(command.get("transition", ""))
		trace.append("duplicate:%s" % transition)
		receipts.append({
			"handled": true,
			"duplicate": true,
			"command_id": str(command.get("command_id", "")),
			"transition": transition,
		})
	return {
		"handled": true,
		"reason": "already_applied",
		"replayed": true,
		"command_count": commands.size(),
		"receipts": receipts,
		"trace": trace,
	}


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}
