extends SceneTree

const CONTROLLER_SCENE := preload("res://scenes/runtime/CardResolutionRuntimeController.tscn")
const QUEUE_SCENE := preload("res://scenes/runtime/CardResolutionQueueRuntimeService.tscn")
const WORLD_SCENE := preload("res://scenes/runtime/WorldSessionState.tscn")
const ELIGIBILITY_SCENE := preload("res://scenes/runtime/CardPlayEligibilityRuntimeService.tscn")
const EXECUTION_SCENE := preload("res://scenes/runtime/CardResolutionExecutionRuntimeService.tscn")
const PRESENTATION_SCENE := preload("res://scenes/runtime/CardResolutionPresentationPort.tscn")
const SINK_SCENE := preload("res://scenes/runtime/CardResolutionTransitionSink.tscn")

const FAILURE_COMPLETE_HISTORY := "complete_history_failure_after_mutation"
const FAILURE_SETTLEMENT := "settlement_failure_before_mutation"
const FAILURE_START_AFTER_MUTATION := "start_handler_failure_after_mutation"
const FAILURE_LOCK_AFTER_MUTATION := "lock_handler_failure_after_mutation"


class FaultInjectingExecutionPort extends CardResolutionExecutionWorldBridge:
	var queue: CardResolutionQueueRuntimeService
	var failure_mode := ""
	var failure_consumed := false
	var release_mutation_count := 0
	var effect_mutation_count := 0
	var history_mutation_count := 0
	var settlement_mutation_count := 0
	var start_mutation_count := 0
	var lock_mutation_count := 0

	func bind_queue(queue_service: CardResolutionQueueRuntimeService, authored_failure_mode: String) -> void:
		queue = queue_service
		failure_mode = authored_failure_mode

	func apply_intent(transaction: Dictionary) -> Dictionary:
		var next_intent: Dictionary = transaction.get("next_intent", {}) if transaction.get("next_intent", {}) is Dictionary else {}
		var intent_type := str(next_intent.get("intent_type", ""))
		match intent_type:
			"counter_check":
				return {"intent_type": intent_type, "countered": false}
			"release_active":
				var released := queue.complete_active(int(transaction.get("resolution_id", -1)), {})
				if bool(released.get("completed", false)):
					release_mutation_count += 1
				released["intent_type"] = intent_type
				return released
			"finish_presentation":
				return {"intent_type": intent_type, "finished": true}
			"revalidate_requirement":
				return {"intent_type": intent_type, "valid": true}
			"revalidate_target":
				return {"intent_type": intent_type, "valid": true}
			"dispatch_effect":
				effect_mutation_count += 1
				return {
					"intent_type": intent_type,
					"dispatched": true,
					"resolved": true,
					"continuation_kind": "normal",
				}
			"finish_card_commitment":
				return {"intent_type": intent_type, "committed": true}
			"create_aftermath":
				return {"intent_type": intent_type, "entry_patch": {"aftermath_clue": "public"}}
			"restore_context":
				return {"intent_type": intent_type, "restored": true}
			"append_history":
				if failure_mode == FAILURE_COMPLETE_HISTORY and not failure_consumed:
					failure_consumed = true
					return {"intent_type": intent_type, "appended": false, "reason": "injected_history_failure"}
				history_mutation_count += 1
				return {
					"intent_type": intent_type,
					"appended": true,
					"current_queue_count": queue.current_queue().size(),
				}
			"start_next":
				var started := _start_next_mutation()
				started["intent_type"] = intent_type
				return started
			"finish_batch":
				return {"intent_type": intent_type, "finished": true, "next_queue_count": queue.next_queue().size()}
			"promote_next_batch":
				return {"intent_type": intent_type, "promoted": false, "reason": "next_queue_empty"}
		return {"intent_type": intent_type, "reason": "unsupported_fake_intent"}

	func start_next_transition() -> Dictionary:
		var started := _start_next_mutation()
		started["intent_type"] = "start_next"
		if failure_mode == FAILURE_START_AFTER_MUTATION and not failure_consumed and bool(started.get("started", false)):
			failure_consumed = true
			return {"intent_type": "start_next", "started": false, "reason": "injected_start_handler_failure"}
		return started

	func lock_batch_transition() -> Dictionary:
		lock_mutation_count += 1
		var started := _start_next_mutation()
		if failure_mode == FAILURE_LOCK_AFTER_MUTATION and not failure_consumed:
			failure_consumed = true
			return {"handled": false, "reason": "injected_lock_handler_failure"}
		return {
			"handled": bool(started.get("started", false)) or bool(started.get("batch_finished", false)),
			"reason": str(started.get("reason", "")),
		}

	func settle_finalized_execution(_transaction: Dictionary, finalized: Dictionary) -> Dictionary:
		if not bool(finalized.get("completed", false)):
			return {"settled": false, "reason": "execution_not_completed"}
		if failure_mode == FAILURE_SETTLEMENT and not failure_consumed:
			failure_consumed = true
			return {"settled": false, "reason": "injected_settlement_failure"}
		settlement_mutation_count += 1
		return {
			"settled": true,
			"reason": "settled",
			"resolution_id": int(finalized.get("resolution_id", -1)),
			"execution_id": int(finalized.get("execution_id", -1)),
			"settlement_binding": (finalized.get("settlement_binding", {}) as Dictionary).duplicate(true),
			"settlement_binding_fingerprint": str(finalized.get("settlement_binding_fingerprint", "")),
		}

	func _start_next_mutation() -> Dictionary:
		if not queue.active_entry().is_empty():
			return {"started": true, "reason": "already_started"}
		var started := queue.start_next({"game_time": 0.0})
		if bool(started.get("started", false)):
			start_mutation_count += 1
			return {"started": true, "reason": "started"}
		return {
			"started": false,
			"batch_finished": bool(started.get("batch_empty", false)),
			"reason": str(started.get("reason", "batch_empty")),
		}


class SettlementOracleCoordinator extends GameRuntimeCoordinator:
	var authored_receipt: Dictionary = {}

	func settle_card_mana_reservation(_entry: Dictionary, _execution_receipt: Dictionary) -> Dictionary:
		return authored_receipt.duplicate(true)


var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_production_port_mana_settlement_failure_propagation()
	_test_complete_active_handler_failure_roundtrip()
	_test_complete_active_settlement_failure_roundtrip()
	_test_inflight_save_rejects_forged_intent_progress()
	_test_v1_migration_resets_live_transition_lineage()
	_test_complete_active_post_handler_roundtrip()
	_test_start_next_handler_failure_roundtrip()
	_test_start_next_post_handler_roundtrip()
	_test_lock_batch_handler_failure_roundtrip()
	_test_lock_batch_post_handler_roundtrip()
	await process_frame
	_finish()


func _test_production_port_mana_settlement_failure_propagation() -> void:
	var port := CardResolutionExecutionWorldBridge.new()
	var coordinator := SettlementOracleCoordinator.new()
	root.add_child(port)
	root.add_child(coordinator)
	coordinator.authored_receipt = {
		"settled": false,
		"reason": "injected_production_mana_settlement_failure",
		"transaction_id": "mana-reservation-7",
		"owner_receipt": "preserved",
	}
	port.set_runtime_dependencies(null, null, null, null, null, null, null, null, null, coordinator)
	var binding := {
		"resolution_id": 7,
		"execution_id": 11,
		"resolved": true,
		"countered": false,
		"effect_dispatched": true,
		"history_appended": true,
		"continuation_kind": "normal",
	}
	var finalized := binding.duplicate(true)
	finalized["completed"] = true
	finalized["settlement_binding"] = binding.duplicate(true)
	finalized["settlement_binding_fingerprint"] = JSON.stringify(binding).sha256_text()
	var receipt := port.settle_finalized_execution({
		"active_entry": {"asset_reservation_id": "mana-reservation-7"},
	}, finalized)
	_expect(not bool(receipt.get("settled", true)), "production execution port preserves failed mana settlement status")
	_expect(str(receipt.get("reason", "")) == "injected_production_mana_settlement_failure", "production execution port propagates the coordinator failure reason")
	_expect(str(receipt.get("transaction_id", "")) == "mana-reservation-7" and str(receipt.get("owner_receipt", "")) == "preserved", "production execution port preserves coordinator settlement evidence")
	port.queue_free()
	coordinator.queue_free()


func _test_complete_active_settlement_failure_roundtrip() -> void:
	var source := _make_harness(FAILURE_SETTLEMENT)
	var commands := _complete_active_commands(source, 103)
	var first := (source.sink as CardResolutionTransitionSink).apply_transition_batch(commands)
	_expect(not bool(first.get("handled", true)) and str(first.get("reason", "")) == "injected_settlement_failure", "complete_active exposes settlement failure after finalization")
	var source_port := source.port as FaultInjectingExecutionPort
	_expect(source_port.release_mutation_count == 1 and source_port.effect_mutation_count == 1 and source_port.history_mutation_count == 1, "settlement failure occurs after gameplay intents finish once")
	_expect(source_port.settlement_mutation_count == 0 and int((source.execution as CardResolutionExecutionRuntimeService).debug_snapshot().get("pending_settlement_count", -1)) == 1, "failed settlement remains pending without claiming a mutation")
	var execution_save := (source.execution as CardResolutionExecutionRuntimeService).to_save_data()
	_expect((execution_save.get("pending_settlements", []) as Array).size() == 1 and (execution_save.get("inflight_execution_transactions", []) as Array).is_empty(), "save persists finalized pending settlement separately from inflight intents")
	var pending_record := (source.execution as CardResolutionExecutionRuntimeService).pending_settlement(103)
	var finalized := (pending_record.get("finalized", {}) as Dictionary).duplicate(true)
	var mismatched_receipt := {
		"settled": true,
		"reason": "forged_success",
		"resolution_id": 103,
		"execution_id": int(finalized.get("execution_id", -1)) + 1,
		"settlement_binding": (finalized.get("settlement_binding", {}) as Dictionary).duplicate(true),
		"settlement_binding_fingerprint": str(finalized.get("settlement_binding_fingerprint", "")),
	}
	var mismatched_completion := (source.execution as CardResolutionExecutionRuntimeService).complete_pending_settlement(103, mismatched_receipt)
	_expect(not bool(mismatched_completion.get("completed", true)) and str(mismatched_completion.get("reason", "")) == "settlement_receipt_binding_mismatch", "pending settlement rejects a success receipt bound to another execution")
	_expect(int((source.execution as CardResolutionExecutionRuntimeService).debug_snapshot().get("pending_settlement_count", -1)) == 1, "mismatched settlement receipt cannot clear pending state")
	var forged_pending_save := execution_save.duplicate(true)
	var forged_pending_records := forged_pending_save.get("pending_settlements", []) as Array
	var forged_pending_record := (forged_pending_records[0] as Dictionary).duplicate(true)
	var forged_finalized := (forged_pending_record.get("finalized", {}) as Dictionary).duplicate(true)
	forged_finalized["resolved"] = not bool(forged_finalized.get("resolved", false))
	forged_pending_record["finalized"] = forged_finalized
	forged_pending_records[0] = forged_pending_record
	forged_pending_save["pending_settlements"] = forged_pending_records
	var pending_target := _make_harness()
	_expect_save_rejected_without_mutation(pending_target, forged_pending_save, "pending settlement save rejects an outcome detached from its transaction")
	_free_harness(pending_target)

	var restored := _roundtrip_harness(source)
	_expect(int((restored.execution as CardResolutionExecutionRuntimeService).debug_snapshot().get("pending_settlement_count", -1)) == 1, "save/load restores the pending settlement exactly")
	var retry := (restored.sink as CardResolutionTransitionSink).apply_transition_batch(commands)
	var restored_port := restored.port as FaultInjectingExecutionPort
	_expect(bool(retry.get("handled", false)) and source_port.settlement_mutation_count + restored_port.settlement_mutation_count == 1, "pending settlement retries and mutates exactly once")
	_expect(restored_port.release_mutation_count == 0 and restored_port.effect_mutation_count == 0 and restored_port.history_mutation_count == 0, "settlement retry never replays release, effect, or history")
	_expect(int((restored.execution as CardResolutionExecutionRuntimeService).debug_snapshot().get("pending_settlement_count", -1)) == 0, "successful settlement clears the persisted pending record")
	_free_harness(source)
	_free_harness(restored)


func _test_inflight_save_rejects_forged_intent_progress() -> void:
	var source := _make_harness(FAILURE_COMPLETE_HISTORY)
	var commands := _complete_active_commands(source, 104)
	var first := (source.sink as CardResolutionTransitionSink).apply_transition_batch(commands)
	_expect(not bool(first.get("handled", true)) and str(first.get("reason", "")) == "injected_history_failure", "forged inflight oracle reaches a retryable history boundary")
	var authored_save := (source.execution as CardResolutionExecutionRuntimeService).to_save_data()
	var records := authored_save.get("inflight_execution_transactions", []) as Array
	_expect(records.size() == 1, "forged inflight oracle persists one recoverable transaction")
	if records.size() == 1:
		var forgeries: Array[Dictionary] = []
		var duplicate_completed := authored_save.duplicate(true)
		var duplicate_records := duplicate_completed.get("inflight_execution_transactions", []) as Array
		var duplicate_transaction := (duplicate_records[0] as Dictionary).duplicate(true)
		var duplicate_list := (duplicate_transaction.get("completed_intents", []) as Array).duplicate()
		duplicate_list.append(duplicate_list.back())
		duplicate_transaction["completed_intents"] = duplicate_list
		duplicate_records[0] = duplicate_transaction
		duplicate_completed["inflight_execution_transactions"] = duplicate_records
		forgeries.append({"save": duplicate_completed, "label": "duplicate completed intent"})

		var reordered_completed := authored_save.duplicate(true)
		var reordered_records := reordered_completed.get("inflight_execution_transactions", []) as Array
		var reordered_transaction := (reordered_records[0] as Dictionary).duplicate(true)
		var reordered_list := (reordered_transaction.get("completed_intents", []) as Array).duplicate()
		if reordered_list.size() >= 2:
			var first_intent: Variant = reordered_list[0]
			reordered_list[0] = reordered_list[1]
			reordered_list[1] = first_intent
		reordered_transaction["completed_intents"] = reordered_list
		reordered_records[0] = reordered_transaction
		reordered_completed["inflight_execution_transactions"] = reordered_records
		forgeries.append({"save": reordered_completed, "label": "out-of-order completed intents"})

		var inconsistent_flag := authored_save.duplicate(true)
		var flag_records := inconsistent_flag.get("inflight_execution_transactions", []) as Array
		var flag_transaction := (flag_records[0] as Dictionary).duplicate(true)
		flag_transaction["active_released"] = false
		flag_records[0] = flag_transaction
		inconsistent_flag["inflight_execution_transactions"] = flag_records
		forgeries.append({"save": inconsistent_flag, "label": "active release flag detached from completed intents"})

		var regressed_next := authored_save.duplicate(true)
		var next_records := regressed_next.get("inflight_execution_transactions", []) as Array
		var next_transaction := (next_records[0] as Dictionary).duplicate(true)
		var next_intent := (next_transaction.get("next_intent", {}) as Dictionary).duplicate(true)
		next_intent["intent_type"] = "dispatch_effect"
		next_transaction["next_intent"] = next_intent
		next_records[0] = next_transaction
		regressed_next["inflight_execution_transactions"] = next_records
		forgeries.append({"save": regressed_next, "label": "regressed next intent"})

		for forged_case in forgeries:
			var target := _make_harness()
			_expect_save_rejected_without_mutation(target, forged_case.get("save", {}) as Dictionary, "inflight save rejects %s" % str(forged_case.get("label", "forgery")))
			_free_harness(target)
	_free_harness(source)


func _test_v1_migration_resets_live_transition_lineage() -> void:
	var harness := _make_harness()
	var commands := _start_next_commands(harness, 105)
	var applied := (harness.sink as CardResolutionTransitionSink).apply_transition_batch(commands)
	var before := (harness.controller as CardResolutionRuntimeController).transition_lineage_snapshot()
	_expect(bool(applied.get("handled", false)) and int(before.get("applied_command_count", 0)) > 0, "v1 migration oracle starts with nonempty live transition lineage")
	var legacy_save := {
		"schema_version": 1,
		"transaction_sequence": 0,
		"completed_resolution_ids": [],
		"inflight_resolution_ids": [],
	}
	var restored := (harness.execution as CardResolutionExecutionRuntimeService).apply_save_data(legacy_save)
	var after := (harness.controller as CardResolutionRuntimeController).transition_lineage_snapshot()
	_expect(bool(restored.get("applied", false)), "v1 execution save migrates through a canonical transition checkpoint")
	_expect(int(after.get("batch_revision", -1)) == 0 and int(after.get("next_order_index", -1)) == 0 and int(after.get("applied_command_count", -1)) == 0, "v1 migration clears live transition command lineage instead of inheriting it")
	_free_harness(harness)


func _test_complete_active_handler_failure_roundtrip() -> void:
	var source := _make_harness(FAILURE_COMPLETE_HISTORY)
	var commands := _complete_active_commands(source, 101)
	var first := (source.sink as CardResolutionTransitionSink).apply_transition_batch(commands)
	_expect(not bool(first.get("handled", true)) and str(first.get("reason", "")) == "injected_history_failure", "complete_active exposes a downstream handler failure")
	var source_port := source.port as FaultInjectingExecutionPort
	_expect(source_port.release_mutation_count == 1 and source_port.effect_mutation_count == 1, "complete_active performs each pre-failure gameplay mutation once")
	var restored := _roundtrip_harness(source)
	var retry := (restored.sink as CardResolutionTransitionSink).apply_transition_batch(commands)
	var restored_port := restored.port as FaultInjectingExecutionPort
	_expect(bool(retry.get("handled", false)), "complete_active resumes after handler failure and save/load")
	_expect(source_port.release_mutation_count + restored_port.release_mutation_count == 1, "complete_active release remains exact-once across retry")
	_expect(source_port.effect_mutation_count + restored_port.effect_mutation_count == 1, "complete_active effect remains exact-once across retry")
	_expect(source_port.history_mutation_count + restored_port.history_mutation_count == 1, "complete_active finishes history exactly once after recovery")
	_expect(source_port.settlement_mutation_count + restored_port.settlement_mutation_count == 1, "complete_active finishes settlement exactly once after recovery")
	_free_harness(source)
	_free_harness(restored)


func _test_complete_active_post_handler_roundtrip() -> void:
	var source := _make_harness()
	var commands := _complete_active_commands(source, 102)
	var command_id := _command_id(commands, "complete_active")
	(source.sink as CardResolutionTransitionSink).inject_test_failure_after_handler(command_id)
	var first := (source.sink as CardResolutionTransitionSink).apply_transition_batch(commands)
	_expect(str(first.get("reason", "")) == "fault_injected_after_handler", "complete_active exposes post-handler-before-lineage fault")
	var restored := _roundtrip_harness(source)
	var retry := (restored.sink as CardResolutionTransitionSink).apply_transition_batch(commands)
	var source_port := source.port as FaultInjectingExecutionPort
	var restored_port := restored.port as FaultInjectingExecutionPort
	_expect(bool(retry.get("handled", false)), "complete_active finalizes lineage after post-handler save/load")
	_expect(source_port.release_mutation_count + restored_port.release_mutation_count == 1, "complete_active post-handler recovery does not release twice")
	_expect(source_port.effect_mutation_count + restored_port.effect_mutation_count == 1, "complete_active post-handler recovery does not dispatch twice")
	_expect(source_port.settlement_mutation_count + restored_port.settlement_mutation_count == 1, "complete_active post-handler recovery does not settle twice")
	_free_harness(source)
	_free_harness(restored)


func _test_start_next_handler_failure_roundtrip() -> void:
	var source := _make_harness(FAILURE_START_AFTER_MUTATION)
	var commands := _start_next_commands(source, 201)
	var first := (source.sink as CardResolutionTransitionSink).apply_transition_batch(commands)
	_expect(str(first.get("reason", "")) == "injected_start_handler_failure", "start_next exposes a handler failure after its gameplay mutation")
	var restored := _roundtrip_harness(source)
	var retry := (restored.sink as CardResolutionTransitionSink).apply_transition_batch(commands)
	var source_port := source.port as FaultInjectingExecutionPort
	var restored_port := restored.port as FaultInjectingExecutionPort
	_expect(bool(retry.get("handled", false)), "start_next recognizes its restored post-mutation state")
	_expect(source_port.start_mutation_count + restored_port.start_mutation_count == 1, "start_next handler failure remains exact-once across save/load")
	_free_harness(source)
	_free_harness(restored)


func _test_start_next_post_handler_roundtrip() -> void:
	var source := _make_harness()
	var commands := _start_next_commands(source, 202)
	(source.sink as CardResolutionTransitionSink).inject_test_failure_after_handler(_command_id(commands, "start_next"))
	var first := (source.sink as CardResolutionTransitionSink).apply_transition_batch(commands)
	_expect(str(first.get("reason", "")) == "fault_injected_after_handler", "start_next exposes post-handler-before-lineage fault")
	var restored := _roundtrip_harness(source)
	var retry := (restored.sink as CardResolutionTransitionSink).apply_transition_batch(commands)
	var source_port := source.port as FaultInjectingExecutionPort
	var restored_port := restored.port as FaultInjectingExecutionPort
	_expect(bool(retry.get("handled", false)), "start_next finalizes lineage after post-handler save/load")
	_expect(source_port.start_mutation_count + restored_port.start_mutation_count == 1, "start_next post-handler recovery does not start twice")
	_free_harness(source)
	_free_harness(restored)


func _test_lock_batch_handler_failure_roundtrip() -> void:
	var source := _make_harness(FAILURE_LOCK_AFTER_MUTATION)
	var commands := _lock_batch_commands(source, 301)
	var first := (source.sink as CardResolutionTransitionSink).apply_transition_batch(commands)
	_expect(str(first.get("reason", "")) == "injected_lock_handler_failure", "lock_batch exposes a handler failure after its gameplay mutation")
	var restored := _roundtrip_harness(source)
	var retry := (restored.sink as CardResolutionTransitionSink).apply_transition_batch(commands)
	var source_port := source.port as FaultInjectingExecutionPort
	var restored_port := restored.port as FaultInjectingExecutionPort
	_expect(bool(retry.get("handled", false)), "lock_batch recognizes its restored post-mutation state")
	_expect(source_port.lock_mutation_count + restored_port.lock_mutation_count == 1, "lock_batch handler failure remains exact-once across save/load")
	_expect(source_port.start_mutation_count + restored_port.start_mutation_count == 1, "lock_batch handler failure does not start the batch twice")
	_free_harness(source)
	_free_harness(restored)


func _test_lock_batch_post_handler_roundtrip() -> void:
	var source := _make_harness()
	var commands := _lock_batch_commands(source, 302)
	(source.sink as CardResolutionTransitionSink).inject_test_failure_after_handler(_command_id(commands, "lock_batch"))
	var first := (source.sink as CardResolutionTransitionSink).apply_transition_batch(commands)
	_expect(str(first.get("reason", "")) == "fault_injected_after_handler", "lock_batch exposes post-handler-before-lineage fault")
	var restored := _roundtrip_harness(source)
	var retry := (restored.sink as CardResolutionTransitionSink).apply_transition_batch(commands)
	var source_port := source.port as FaultInjectingExecutionPort
	var restored_port := restored.port as FaultInjectingExecutionPort
	_expect(bool(retry.get("handled", false)), "lock_batch finalizes lineage after post-handler save/load")
	_expect(source_port.lock_mutation_count + restored_port.lock_mutation_count == 1, "lock_batch post-handler recovery does not lock twice")
	_expect(source_port.start_mutation_count + restored_port.start_mutation_count == 1, "lock_batch post-handler recovery does not start twice")
	_free_harness(source)
	_free_harness(restored)


func _make_harness(failure_mode: String = "") -> Dictionary:
	var controller := CONTROLLER_SCENE.instantiate() as CardResolutionRuntimeController
	var queue := QUEUE_SCENE.instantiate() as CardResolutionQueueRuntimeService
	var world := WORLD_SCENE.instantiate() as WorldSessionState
	var eligibility := ELIGIBILITY_SCENE.instantiate() as CardPlayEligibilityRuntimeService
	var execution := EXECUTION_SCENE.instantiate() as CardResolutionExecutionRuntimeService
	var presentation := PRESENTATION_SCENE.instantiate() as CardResolutionPresentationPort
	var port := FaultInjectingExecutionPort.new()
	var sink := SINK_SCENE.instantiate() as CardResolutionTransitionSink
	for node in [controller, queue, world, eligibility, execution, presentation, port, sink]:
		root.add_child(node)
	controller.configure({})
	queue.configure(_ruleset_snapshot())
	world.replace_players([{"public_name": "local"}, {"public_name": "rival"}], true)
	execution.configure({})
	execution.set_transition_checkpoint_owner(controller)
	port.bind_queue(queue, failure_mode)
	sink.configure(controller, queue, world, execution, port, presentation, eligibility, null)
	return {
		"controller": controller,
		"queue": queue,
		"world": world,
		"eligibility": eligibility,
		"execution": execution,
		"presentation": presentation,
		"port": port,
		"sink": sink,
	}


func _roundtrip_harness(source: Dictionary) -> Dictionary:
	var execution_save := (source.execution as CardResolutionExecutionRuntimeService).to_save_data()
	var queue_save := (source.queue as CardResolutionQueueRuntimeService).queue_state_snapshot()
	var restored := _make_harness()
	(restored.queue as CardResolutionQueueRuntimeService).replace_state(queue_save)
	var restore_receipt := (restored.execution as CardResolutionExecutionRuntimeService).apply_save_data(execution_save)
	_expect(bool(restore_receipt.get("applied", false)), "fault oracle restores execution and transition checkpoint")
	return restored


func _complete_active_commands(harness: Dictionary, resolution_id: int) -> Array:
	var controller := harness.controller as CardResolutionRuntimeController
	var queue := harness.queue as CardResolutionQueueRuntimeService
	controller.reset_state()
	queue.replace_state({
		"current_queue": [],
		"next_queue": [],
		"active_entry": _entry(resolution_id),
		"resolution_sequence": resolution_id,
	})
	controller.begin_active_display(0.0)
	return controller.tick(0.0, _facts(false, true, str(resolution_id)))


func _start_next_commands(harness: Dictionary, resolution_id: int) -> Array:
	var controller := harness.controller as CardResolutionRuntimeController
	var queue := harness.queue as CardResolutionQueueRuntimeService
	controller.reset_state()
	queue.replace_state({
		"current_queue": [_entry(resolution_id)],
		"next_queue": [],
		"active_entry": {},
		"resolution_sequence": resolution_id,
	})
	controller.batch_locked = true
	return controller.tick(0.0, _facts(false, false, ""))


func _lock_batch_commands(harness: Dictionary, resolution_id: int) -> Array:
	var controller := harness.controller as CardResolutionRuntimeController
	var queue := harness.queue as CardResolutionQueueRuntimeService
	controller.reset_state()
	queue.replace_state({
		"current_queue": [_entry(resolution_id)],
		"next_queue": [],
		"active_entry": {},
		"resolution_sequence": resolution_id,
	})
	controller.begin_group_window(11.0, 0, 3)
	return controller.tick(20.0, _facts(false, false, ""))


func _entry(resolution_id: int) -> Dictionary:
	return {
		"resolution_id": resolution_id,
		"queued_order": resolution_id,
		"player_index": 0,
		"skill": {"name": "故障注入测试牌", "kind": "phase_counter"},
	}


func _facts(queue_empty: bool, active_present: bool, active_id: String) -> Dictionary:
	return {
		"queue_empty": queue_empty,
		"active_present": active_present,
		"active_counterable": false,
		"active_id": active_id,
		"lock_duration": 5.0,
		"public_bid_duration": 5.0,
		"counter_duration": 5.0,
		"active_player_indices": [0, 1],
	}


func _command_id(commands: Array, transition: String) -> String:
	for command_variant in commands:
		if command_variant is Dictionary and str((command_variant as Dictionary).get("transition", "")) == transition:
			return str((command_variant as Dictionary).get("command_id", ""))
	return ""


func _expect_save_rejected_without_mutation(harness: Dictionary, forged_save: Dictionary, message: String) -> void:
	var execution := harness.execution as CardResolutionExecutionRuntimeService
	var before := execution.to_save_data()
	var receipt := execution.apply_save_data(forged_save)
	_expect(not bool(receipt.get("applied", true)), message)
	_expect(execution.to_save_data() == before, "%s leaves execution and transition state unchanged" % message)


func _ruleset_snapshot() -> Dictionary:
	return {
		"ruleset_id": "v0.6",
		"card_group": {
			"group_seconds": 30,
			"planning_seconds": 20,
			"public_bid_seconds": 5,
			"lock_seconds": 5,
			"opening_extended_windows": 3,
			"opening_group_seconds": 45,
			"opening_planning_seconds": 35,
			"ordinary_card_limit": 1,
			"maximum_with_explicit_capability": 3,
		},
	}


func _free_harness(harness: Dictionary) -> void:
	for value in harness.values():
		if value is Node and is_instance_valid(value):
			(value as Node).queue_free()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error("CARD TRANSITION GAMEPLAY FAULT: %s" % message)


func _finish() -> void:
	print("CARD_RESOLUTION_TRANSITION_GAMEPLAY_FAULT|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	quit(0 if _failures.is_empty() else 1)
