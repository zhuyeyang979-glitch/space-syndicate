extends RefCounted
class_name CardResolutionExecutionSaveFullStateFixture

const EXECUTION_SCENE := preload("res://scenes/runtime/CardResolutionExecutionRuntimeService.tscn")
const TRANSITION_SCENE := preload("res://scenes/runtime/CardResolutionRuntimeController.tscn")
const FACILITY_BINDING := preload("res://scripts/cards/v06/queued_facility_card_action_v1.gd")


static func create(tree: SceneTree) -> Dictionary:
	var host := Node.new()
	host.name = "CardResolutionExecutionSaveFullStateFixture"
	tree.root.add_child(host)
	var transition := TRANSITION_SCENE.instantiate() as CardResolutionRuntimeController
	var execution := EXECUTION_SCENE.instantiate() as CardResolutionExecutionRuntimeService
	host.add_child(transition)
	host.add_child(execution)
	execution.configure({"ruleset_id": "v0.6"})
	execution.set_transition_checkpoint_owner(transition)
	return {"host": host, "execution": execution, "transition": transition}


static func cleanup(fixture: Dictionary) -> void:
	var host: Node = fixture.get("host")
	if host != null and is_instance_valid(host):
		host.queue_free()


static func build_nontrivial_state(fixture: Dictionary) -> Dictionary:
	var execution := fixture.get("execution") as CardResolutionExecutionRuntimeService
	var transition := fixture.get("transition") as CardResolutionRuntimeController
	if execution == null or transition == null:
		return {"ok": false, "reason_code": "execution_fixture_missing"}

	_transition_public_bid_with_lineage(transition)
	var planned := execution.plan_execution(_request(4101, "planned"))
	var waiting_target := _advance_until(execution, execution.plan_execution(_request(4102, "target_revalidation")), "revalidate_target")
	var waiting_commitment := _advance_until(execution, execution.plan_execution(_request(4103, "commitment")), "finish_card_commitment")
	var retryable_commitment := execution.advance_execution(
		_advance_until(execution, execution.plan_execution(_request(4104, "commitment_retry")), "finish_card_commitment"),
		{"intent_type": "finish_card_commitment", "committed": false, "reason": "fixture_commitment_retry"}
	)
	var retryable_history := _advance_until(execution, execution.plan_execution(_request(4105, "history_retry")), "append_history")
	retryable_history = execution.advance_execution(retryable_history, {
		"intent_type": "append_history",
		"appended": false,
		"reason": "fixture_history_retry",
	})
	var pending_transaction := _drive_to_completion(execution, execution.plan_execution(_request(4106, "pending_settlement")), 0)
	var pending_finalized := execution.finalize_execution(pending_transaction)
	var facility_retry := _advance_until(execution, execution.plan_execution(_facility_request(4107)), "dispatch_effect")
	facility_retry = execution.advance_execution(facility_retry, {
		"intent_type": "dispatch_effect",
		"dispatched": true,
		"resolved": true,
		"continuation_kind": "facility_commitment",
		"retryable_commitment": true,
	})
	var promote_next := _advance_until(execution, execution.plan_execution(_request(4108, "promote_next")), "append_history")
	promote_next = execution.advance_execution(promote_next, {
		"intent_type": "append_history",
		"appended": true,
		"current_queue_count": 0,
	})
	promote_next = execution.advance_execution(promote_next, {
		"intent_type": "finish_batch",
		"finished": true,
		"next_queue_count": 1,
	})

	var save := execution.to_save_data()
	return {
		"ok": _next_intent(planned) == "counter_check" \
			and _next_intent(waiting_target) == "revalidate_target" \
			and _next_intent(waiting_commitment) == "finish_card_commitment" \
			and str(retryable_commitment.get("status", "")) == "retryable" \
			and _next_intent(retryable_history) == "append_history" \
			and bool(pending_finalized.get("completed", false)) \
			and not execution.pending_settlement(4106).is_empty() \
			and str(facility_retry.get("status", "")) == "retryable" \
			and _next_intent(promote_next) == "promote_next_batch",
		"save": save,
		"coverage": {
			"planned_action": true,
			"waiting_target_revalidation": true,
			"effect_dispatched_waiting_commitment": true,
			"retryable_commitment": true,
			"retryable_history_append": true,
			"pending_settlement": true,
			"facility_commitment_retry": true,
			"transition_command_lineage": true,
			"promote_next_batch": true,
		},
	}


static func build_transition_scenarios(tree: SceneTree) -> Array[Dictionary]:
	var scenarios: Array[Dictionary] = []
	for scenario_id in ["batch_30", "public_bid", "lock", "active_display", "counter_window"]:
		var fixture := create(tree)
		var transition := fixture.get("transition") as CardResolutionRuntimeController
		match scenario_id:
			"batch_30":
				transition.begin_group_window(-1.0, 0, 3)
			"public_bid":
				transition.begin_group_window(-1.0, 0, 3)
				transition.simultaneous_timer = 8.625
				transition.tick(0.0, _facts(false, false))
			"lock":
				transition.begin_group_window(-1.0, 0, 3)
				transition.simultaneous_timer = 3.375
				transition.tick(0.0, _facts(false, false))
			"active_display":
				transition.begin_active_display(3.125)
			"counter_window":
				transition.begin_active_display(0.0)
				transition.begin_counter(2.375)
		var execution := fixture.get("execution") as CardResolutionExecutionRuntimeService
		scenarios.append({
			"scenario_id": scenario_id,
			"save": execution.to_save_data(),
			"fixture": fixture,
		})
	return scenarios


static func _transition_public_bid_with_lineage(transition: CardResolutionRuntimeController) -> void:
	transition.begin_group_window(-1.0, 0, 3)
	transition.simultaneous_timer = 8.625
	var commands := transition.tick(0.0, _facts(false, false))
	for command_variant in commands:
		if command_variant is Dictionary:
			transition.mark_transition_command_applied(command_variant, {
				"handled": true,
				"reason": "fixture_transition_applied",
			})


static func _advance_until(
	execution: CardResolutionExecutionRuntimeService,
	transaction: Dictionary,
	target_intent: String
) -> Dictionary:
	var current := transaction.duplicate(true)
	var guard := 0
	while _next_intent(current) != target_intent and not _next_intent(current).is_empty() and guard < 20:
		guard += 1
		current = execution.advance_execution(current, _success_receipt(_next_intent(current), 0))
	return current


static func _drive_to_completion(
	execution: CardResolutionExecutionRuntimeService,
	transaction: Dictionary,
	next_queue_count: int
) -> Dictionary:
	var current := transaction.duplicate(true)
	var guard := 0
	while not _next_intent(current).is_empty() and guard < 20:
		guard += 1
		current = execution.advance_execution(current, _success_receipt(_next_intent(current), next_queue_count))
	return current


static func _success_receipt(intent_type: String, next_queue_count: int) -> Dictionary:
	var receipt := {"intent_type": intent_type}
	match intent_type:
		"counter_check": receipt["countered"] = false
		"release_active": receipt["completed"] = true
		"finish_presentation": receipt["finished"] = true
		"revalidate_requirement", "revalidate_target": receipt["valid"] = true
		"dispatch_effect":
			receipt["dispatched"] = true
			receipt["resolved"] = true
			receipt["continuation_kind"] = "normal"
		"finish_card_commitment": receipt["committed"] = true
		"create_aftermath": receipt["entry_patch"] = {"aftermath_clue": "fixture"}
		"restore_context": receipt["restored"] = true
		"append_history":
			receipt["appended"] = true
			receipt["current_queue_count"] = 0
		"start_next": receipt["started"] = true
		"finish_batch":
			receipt["finished"] = true
			receipt["next_queue_count"] = next_queue_count
		"promote_next_batch": receipt["promoted"] = true
	return receipt


static func _request(resolution_id: int, fixture_kind: String) -> Dictionary:
	var skill := {
		"name": "Execution Characterization Card",
		"kind": "cash_gain",
		"rank": 1,
		"duration_seconds": 7.75,
		"machine": {
			"effect_kind": "cash_gain",
			"effect_scale": 1.125,
			"optional_target_id": null,
		},
	}
	return {
		"active_entry": {
			"resolution_id": resolution_id,
			"queued_order": resolution_id,
			"player_index": 0,
			"slot_index": -1,
			"window_sequence": 3,
			"group_id": "execution-characterization",
			"group_order": resolution_id - 4100,
			"group_size": 8,
			"started_time": 123.125 + float(resolution_id - 4100) * 0.25,
			"consumed_on_queue": true,
			"play_cost_paid_on_queue": true,
			"fixture_kind": fixture_kind,
			"skill": skill.duplicate(true),
		},
		"skill": skill,
		"target_kind": "none",
		"selection_context": {
			"selected_district": 0,
			"selected_trade_product": "product.fixture",
			"play_requirement_district": 0,
		},
	}


static func _facility_request(resolution_id: int) -> Dictionary:
	var request := _request(resolution_id, "facility_commitment_retry")
	var active_entry := (request.get("active_entry", {}) as Dictionary).duplicate(true)
	active_entry["v06_facility_action"] = FACILITY_BINDING.build(_facility_binding_input(resolution_id))
	request["active_entry"] = active_entry
	return request


static func _facility_binding_input(resolution_id: int) -> Dictionary:
	return {
		"schema_version": 1,
		"binding_kind_id": "v06.queued-facility-card-action",
		"resolution_id": resolution_id,
		"request_id": "request.execution.characterization",
		"intent_fingerprint": "1".repeat(64),
		"session_id": "session.execution.characterization",
		"session_revision": 1,
		"session_identity_fingerprint": "2".repeat(64),
		"source_revision": 1,
		"actor_kind_id": "ai",
		"actor_id": "player.2",
		"actor_player_index": 2,
		"card_instance_id": "card.instance.execution.characterization",
		"runtime_instance_id": "card.instance.execution.characterization",
		"card_semantic_id": "facility.factory.energy.rank_1",
		"hand_slot_id": "hand.slot.0",
		"source_slot_index": 0,
		"source_record_fingerprint": "3".repeat(64),
		"source_slot_fingerprint": "4".repeat(64),
		"facility_kind_id": "factory",
		"industry_id": "energy",
		"rank": 1,
		"prebound_target": {
			"schema_version": 1,
			"target_kind_id": "region_unique_facility_slot",
			"region_id": "region.execution",
			"region_revision": 1,
			"target_slot_id": "region.execution::factory::energy",
			"target_slot_generation": 0,
			"target_state_fingerprint": "5".repeat(64),
		},
		"asset_reservation": {
			"schema_version": 1,
			"owner_id": "player_mana",
			"required": false,
			"reservation_id": "",
			"reservation_state_id": "reserved",
			"reservation_fingerprint": "6".repeat(64),
		},
		"card_escrow": {
			"schema_version": 1,
			"owner_id": "world_session_state",
			"escrow_id": "escrow.execution.characterization",
			"state_id": "committed_resolution_escrow",
			"escrow_fingerprint": "7".repeat(64),
		},
		"submitted_at_world_time": 0,
		"queue_revision_at_commit": 1,
		"local_action_index": 0,
		"public_visibility": {
			"schema_version": 1,
			"owner_visibility_id": "anonymous",
			"card_visibility_id": "public",
			"target_visibility_id": "public",
		},
	}


static func _facts(queue_empty: bool, active_present: bool) -> Dictionary:
	return {
		"queue_empty": queue_empty,
		"active_present": active_present,
		"active_counterable": false,
		"active_id": "",
		"lock_duration": 5.0,
		"public_bid_duration": 5.0,
		"counter_duration": 5.0,
		"active_player_indices": [],
	}


static func _next_intent(transaction: Dictionary) -> String:
	var next := transaction.get("next_intent", {}) as Dictionary if transaction.get("next_intent", {}) is Dictionary else {}
	return str(next.get("intent_type", ""))
