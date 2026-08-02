extends RefCounted
class_name ExecutionRestoreExactOnceProbeV1

const FIXTURE := preload("res://tests/fixtures/card_resolution_execution_save_full_state_fixture.gd")
const HISTORY_SCENE := preload("res://scenes/runtime/CardResolutionHistoryRuntimeService.tscn")


static func run(tree: SceneTree) -> Dictionary:
	if tree == null:
		return _failure("execution_exact_once_probe_tree_missing")
	var commitment := _commitment_retry_probe(tree)
	var history := _history_retry_probe(tree)
	var settlement := _pending_settlement_probe(tree)
	var transition := _transition_lineage_probe(tree)
	var green := bool(commitment.get("green", false)) \
			and bool(history.get("green", false)) \
			and bool(settlement.get("green", false)) \
			and bool(transition.get("green", false))
	return {
		"green": green,
		"reason_code": "execution_restore_exact_once_green" \
				if green else "execution_restore_exact_once_failed",
		"probe_case_count": 4,
		"retryable_commitment_green": bool(commitment.get("green", false)),
		"retryable_history_green": bool(history.get("green", false)),
		"pending_settlement_green": bool(settlement.get("green", false)),
		"transition_lineage_green": bool(transition.get("green", false)),
		"facility_commitment_retry_green": bool(commitment.get("facility_green", false)),
		"duplicate_effect_dispatch_count": int(commitment.get("duplicate_effect_dispatch_count", -1)) \
				+ int(history.get("duplicate_effect_dispatch_count", -1)),
		"duplicate_card_commitment_count": int(commitment.get("duplicate_card_commitment_count", -1)),
		"duplicate_history_append_count": int(history.get("duplicate_history_append_count", -1)),
		"duplicate_settlement_count": int(settlement.get("duplicate_settlement_count", -1)),
		"duplicate_transition_command_apply_count": int(transition.get("duplicate_transition_command_apply_count", -1)),
		"private_payload_redacted": true,
	}


static func _commitment_retry_probe(tree: SceneTree) -> Dictionary:
	var pair := _restored_nontrivial_pair(tree)
	if not bool(pair.get("ok", false)):
		return _failure(str(pair.get("reason_code", "execution_commitment_probe_restore_failed")))
	var owner := pair.get("owner") as CardResolutionExecutionRuntimeService
	var transaction := owner.resume_inflight_execution(4104)
	var attempted: Array[String] = []
	var guard := 0
	while not _next_intent(transaction).is_empty() and guard < 20:
		guard += 1
		var intent_type := _next_intent(transaction)
		attempted.append(intent_type)
		transaction = owner.advance_execution(transaction, _success_receipt(intent_type))
	var commitment_count := attempted.count("finish_card_commitment")
	var duplicate_effect_dispatch_count := attempted.count("dispatch_effect")
	var duplicate_card_commitment_count := maxi(0, commitment_count - 1)
	var commitment_green := not attempted.is_empty() \
			and attempted[0] == "finish_card_commitment" \
			and duplicate_effect_dispatch_count == 0 \
			and commitment_count == 1 \
			and duplicate_card_commitment_count == 0 \
			and _next_intent(transaction).is_empty()

	var facility := owner.resume_inflight_execution(4107)
	var facility_attempted: Array[String] = []
	guard = 0
	while not _next_intent(facility).is_empty() and guard < 20:
		guard += 1
		var intent_type := _next_intent(facility)
		facility_attempted.append(intent_type)
		facility = owner.advance_execution(facility, _success_receipt(intent_type))
	var facility_green := not facility_attempted.is_empty() \
			and facility_attempted[0] == "finish_card_commitment" \
			and facility_attempted.count("dispatch_effect") == 0 \
			and facility_attempted.count("finish_card_commitment") == 1 \
			and _next_intent(facility).is_empty()
	FIXTURE.cleanup(pair.get("source") as Dictionary)
	FIXTURE.cleanup(pair.get("target") as Dictionary)
	return {
		"green": commitment_green and facility_green,
		"facility_green": facility_green,
		"duplicate_effect_dispatch_count": duplicate_effect_dispatch_count \
				+ facility_attempted.count("dispatch_effect"),
		"duplicate_card_commitment_count": duplicate_card_commitment_count \
				+ maxi(0, facility_attempted.count("finish_card_commitment") - 1),
	}


static func _history_retry_probe(tree: SceneTree) -> Dictionary:
	var pair := _restored_nontrivial_pair(tree)
	if not bool(pair.get("ok", false)):
		return _failure(str(pair.get("reason_code", "execution_history_probe_restore_failed")))
	var owner := pair.get("owner") as CardResolutionExecutionRuntimeService
	var target := pair.get("target") as Dictionary
	var history := HISTORY_SCENE.instantiate() as CardResolutionHistoryRuntimeService
	(target.get("host") as Node).add_child(history)
	history.configure({})
	var history_entry := {"resolution_id": 4105, "resolved": true, "resolution_outcome": "resolved"}
	var seeded := history.append_resolved(history_entry)
	var before := history.debug_snapshot()
	var transaction := owner.resume_inflight_execution(4105)
	var retry := history.append_resolved(history_entry)
	var appended_or_duplicate := bool(retry.get("appended", false)) or bool(retry.get("duplicate", false))
	transaction = owner.advance_execution(transaction, {
		"intent_type": "append_history",
		"appended": appended_or_duplicate,
		"current_queue_count": 0,
	})
	var after := history.debug_snapshot()
	var no_duplicate_mutation := bool(retry.get("duplicate", false)) \
			and int(after.get("history_count", -1)) == 1 \
			and int(after.get("append_count", -1)) == int(before.get("append_count", -2))
	var preserved_completed_steps := bool(transaction.get("effect_dispatched", false)) \
			and bool(transaction.get("commitment_checked", false)) \
			and _next_intent(transaction) == "finish_batch"
	transaction = owner.advance_execution(transaction, {
		"intent_type": "finish_batch",
		"finished": true,
		"next_queue_count": 0,
	})
	var green := bool(seeded.get("appended", false)) \
			and no_duplicate_mutation \
			and preserved_completed_steps \
			and _next_intent(transaction).is_empty()
	FIXTURE.cleanup(pair.get("source") as Dictionary)
	FIXTURE.cleanup(target)
	return {
		"green": green,
		"duplicate_effect_dispatch_count": 0 if preserved_completed_steps else 1,
		"duplicate_history_append_count": 0 if no_duplicate_mutation else 1,
	}


static func _pending_settlement_probe(tree: SceneTree) -> Dictionary:
	var pair := _restored_nontrivial_pair(tree)
	if not bool(pair.get("ok", false)):
		return _failure(str(pair.get("reason_code", "execution_settlement_probe_restore_failed")))
	var owner := pair.get("owner") as CardResolutionExecutionRuntimeService
	var mutation_counter := {"count": 0}
	var first := _complete_settlement_once(owner, 4106, mutation_counter)
	var second := _complete_settlement_once(owner, 4106, mutation_counter)
	var duplicate_settlement_count := maxi(0, int(mutation_counter.get("count", 0)) - 1)
	var green := bool(first.get("completed", false)) \
			and not bool(second.get("completed", true)) \
			and str(second.get("reason", "")) == "pending_settlement_missing" \
			and duplicate_settlement_count == 0 \
			and int(owner.debug_snapshot().get("pending_settlement_count", -1)) == 0
	FIXTURE.cleanup(pair.get("source") as Dictionary)
	FIXTURE.cleanup(pair.get("target") as Dictionary)
	return {"green": green, "duplicate_settlement_count": duplicate_settlement_count}


static func _transition_lineage_probe(tree: SceneTree) -> Dictionary:
	var source := FIXTURE.create(tree)
	var source_controller := source.get("transition") as CardResolutionRuntimeController
	source_controller.begin_group_window(-1.0, 0, 3)
	source_controller.simultaneous_timer = 8.625
	var commands := source_controller.tick(0.0, _facts())
	var source_marked := not commands.is_empty()
	for command_variant: Variant in commands:
		if not (command_variant is Dictionary) \
				or not bool(source_controller.mark_transition_command_applied(
					command_variant as Dictionary, {"handled": true}
				).get("accepted", false)):
			source_marked = false
	var source_owner := source.get("execution") as CardResolutionExecutionRuntimeService
	var parsed: Variant = JSON.parse_string(JSON.stringify(source_owner.to_save_data()))
	var target := FIXTURE.create(tree)
	var target_owner := target.get("execution") as CardResolutionExecutionRuntimeService
	var target_controller := target.get("transition") as CardResolutionRuntimeController
	var restored := parsed is Dictionary \
			and bool(target_owner.apply_save_data(parsed as Dictionary).get("applied", false))
	var duplicate_green := false
	if restored and not commands.is_empty() and commands[0] is Dictionary:
		var command := commands[0] as Dictionary
		var before := target_controller.transition_lineage_snapshot()
		var duplicate := target_controller.mark_transition_command_applied(command, {"handled": true})
		var after := target_controller.transition_lineage_snapshot()
		duplicate_green = not bool(duplicate.get("accepted", true)) \
				and bool(duplicate.get("exact_once", false)) \
				and str(duplicate.get("reason", "")) == "duplicate_command" \
				and before == after
	FIXTURE.cleanup(source)
	FIXTURE.cleanup(target)
	return {
		"green": source_marked and restored and duplicate_green,
		"duplicate_transition_command_apply_count": 0 if duplicate_green else 1,
	}


static func _restored_nontrivial_pair(tree: SceneTree) -> Dictionary:
	var source := FIXTURE.create(tree)
	var rich := FIXTURE.build_nontrivial_state(source)
	var parsed: Variant = JSON.parse_string(JSON.stringify(rich.get("save", {})))
	var target := FIXTURE.create(tree)
	var owner := target.get("execution") as CardResolutionExecutionRuntimeService
	if not bool(rich.get("ok", false)) or not (parsed is Dictionary) \
			or not bool(owner.apply_save_data(parsed as Dictionary).get("applied", false)):
		FIXTURE.cleanup(source)
		FIXTURE.cleanup(target)
		return _failure("execution_exact_once_probe_restore_failed")
	return {"ok": true, "source": source, "target": target, "owner": owner}


static func _complete_settlement_once(
	owner: CardResolutionExecutionRuntimeService,
	resolution_id: int,
	mutation_counter: Dictionary
) -> Dictionary:
	var pending := owner.pending_settlement(resolution_id)
	if pending.is_empty():
		return owner.complete_pending_settlement(resolution_id, {})
	mutation_counter["count"] = int(mutation_counter.get("count", 0)) + 1
	var finalized := pending.get("finalized", {}) as Dictionary
	return owner.complete_pending_settlement(resolution_id, {
		"settled": true,
		"resolution_id": resolution_id,
		"execution_id": int(pending.get("execution_id", -1)),
		"settlement_binding": (finalized.get("settlement_binding", {}) as Dictionary).duplicate(true),
		"settlement_binding_fingerprint": str(finalized.get("settlement_binding_fingerprint", "")),
	})


static func _success_receipt(intent_type: String) -> Dictionary:
	var receipt := {"intent_type": intent_type}
	match intent_type:
		"finish_card_commitment":
			receipt["committed"] = true
			receipt["commitment_settled"] = true
		"create_aftermath": receipt["entry_patch"] = {"restored_aftermath": true}
		"restore_context": receipt["restored"] = true
		"append_history":
			receipt["appended"] = true
			receipt["current_queue_count"] = 0
		"finish_batch":
			receipt["finished"] = true
			receipt["next_queue_count"] = 0
		"start_next": receipt["started"] = true
		"promote_next_batch": receipt["promoted"] = true
	return receipt


static func _facts() -> Dictionary:
	return {
		"queue_empty": false,
		"active_present": false,
		"active_counterable": false,
		"active_id": "",
		"lock_duration": 5.0,
		"public_bid_duration": 5.0,
		"counter_duration": 5.0,
		"active_player_indices": [],
	}


static func _next_intent(transaction: Dictionary) -> String:
	var next := transaction.get("next_intent", {}) as Dictionary \
			if transaction.get("next_intent", {}) is Dictionary else {}
	return str(next.get("intent_type", ""))


static func _failure(reason_code: String) -> Dictionary:
	return {
		"green": false,
		"ok": false,
		"reason_code": reason_code,
		"duplicate_effect_dispatch_count": -1,
		"duplicate_card_commitment_count": -1,
		"duplicate_history_append_count": -1,
		"duplicate_settlement_count": -1,
		"duplicate_transition_command_apply_count": -1,
	}
