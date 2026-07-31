extends SceneTree

const DRIVER := preload("res://scripts/tools/cold_restore_vertical_slice_driver.gd")
const DRIVER_PATH := "res://scripts/tools/cold_restore_vertical_slice_driver.gd"
const WORLD_BRIDGE_PATH := "res://scripts/runtime/card_resolution_execution_world_bridge.gd"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var source := FileAccess.get_file_as_string(DRIVER_PATH)
	var consumer := _function_source(source, "_run_consumer")
	var validator := _function_source(source, "_run_validator")
	var resume := _function_source(source, "_resume_via_player_flow")
	var queue_observation := _function_source(source, "_queue_target_observation")
	var duplicate_observation := _function_source(source, "_authoritative_duplicate_observation")
	var world_bridge := FileAccess.get_file_as_string(WORLD_BRIDGE_PATH)

	_expect(not source.is_empty(), "driver source is readable")
	_expect(not consumer.is_empty(), "Process B source is independently auditable")
	_expect(not validator.is_empty(), "Process C source is independently auditable")
	_expect(not resume.is_empty(), "restore transaction source is independently auditable")

	_test_typed_boolean_evidence()
	_test_queue_target_contract(world_bridge)
	_test_facility_lifecycle_contract()
	_test_process_b_ordering(consumer, queue_observation)
	_test_process_c_ordering(validator)
	_test_restore_exact_once_contract(resume)
	_test_duplicate_observation_shape(duplicate_observation)

	if _failures.is_empty():
		print("COLD_RESTORE_PROCESS_BC_EVIDENCE_CONTRACT_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	push_error("Process B/C evidence contract failed:\n- " + "\n- ".join(_failures))
	quit(1)


func _test_typed_boolean_evidence() -> void:
	_expect(
		DRIVER._required_boolean_evidence({"value": true}, "value"),
		"typed Boolean evidence accepts literal true"
	)
	_expect(
		not DRIVER._required_boolean_evidence({"value": "true"}, "value"),
		"typed Boolean evidence rejects a truthy string"
	)
	_expect(
		not DRIVER._required_boolean_evidence({"value": 1}, "value"),
		"typed Boolean evidence rejects an integer"
	)
	_expect(
		not DRIVER._required_boolean_evidence({}, "value"),
		"typed Boolean evidence rejects a missing field"
	)


func _test_queue_target_contract(world_bridge: String) -> void:
	var fingerprint := "a".repeat(64)
	var before := _queue_observation(fingerprint, 1, 0, 0, 10, 20)
	var after := _queue_observation("", 0, 1, 1, 11, 21)
	var evidence := DRIVER._queue_target_manifest_evidence(7, fingerprint, before, after)
	_expect(
		DRIVER._queue_target_role_evidence_valid(
			"consumer", fingerprint, before, after, evidence
		),
		"Process B accepts one pending-to-history target transition"
	)

	var rebound_after := after.duplicate(true)
	rebound_after["stable_target_fingerprint"] = "b".repeat(64)
	var rebound_evidence := DRIVER._queue_target_manifest_evidence(
		7, fingerprint, before, rebound_after
	)
	_expect(
		not DRIVER._queue_target_role_evidence_valid(
			"consumer", fingerprint, before, rebound_after, rebound_evidence
		),
		"Process B rejects private target identity leaking back into History"
	)

	var validator_before := _queue_observation("", 0, 1, 1, 11, 21)
	var validator_after := validator_before.duplicate(true)
	var validator_evidence := DRIVER._queue_target_manifest_evidence(
		7, fingerprint, validator_before, validator_after
	)
	_expect(
		DRIVER._queue_target_role_evidence_valid(
			"validator", fingerprint, validator_before, validator_after, validator_evidence
		),
		"Process C accepts an unchanged completed target across the idle gate"
	)

	validator_after["history_append_count"] = 22
	var duplicate_history_evidence := DRIVER._queue_target_manifest_evidence(
		7, fingerprint, validator_before, validator_after
	)
	_expect(
		not DRIVER._queue_target_role_evidence_valid(
			"validator",
			fingerprint,
			validator_before,
			validator_after,
			duplicate_history_evidence
		),
		"Process C rejects a deferred duplicate History append"
	)

	_expect(
		world_bridge.contains('entry.erase("stable_target_envelope")') \
				and world_bridge.contains('entry.erase("v06_facility_action")'),
		"production History keeps the stable target and facility binding private"
	)

	var quiet_after := after.duplicate(true)
	_expect(
		DRIVER._queue_target_post_continuation_quiet_valid(after, quiet_after),
		"post-continuation target gate accepts an unchanged redacted lineage"
	)
	for field in [
		"pending_count",
		"completed_count",
		"history_count",
		"history_lineage_count",
		"history_duplicate_count",
		"transition_duplicate_count",
		"public_log_duplicate_count",
		"public_log_collision_count",
	]:
		var changed := quiet_after.duplicate(true)
		changed[field] = int(changed.get(field, 0)) + 1
		_expect(
			not DRIVER._queue_target_post_continuation_quiet_valid(after, changed),
			"post-continuation target gate rejects %s drift" % field
		)


func _test_process_b_ordering(consumer: String, queue_observation: String) -> void:
	var history_branch := _source_between(
		queue_observation,
		"if pending_count == 0 and history_count == 1:",
		"var history_lineage_count"
	)
	_expect(
		not history_branch.is_empty() \
				and not history_branch.contains("validate_entry_binding") \
				and history_branch.contains('not target_entry.has("stable_target_envelope")') \
				and history_branch.contains('not target_entry.has("v06_facility_action")'),
		"completed targets prove History privacy instead of recovering erased bindings"
	)

	var drain := consumer.find("var target_drain := _drain_target_resolution")
	var after_observation := consumer.find("var queue_target_after:", drain)
	var target_gate := consumer.find("_queue_target_role_evidence_valid(", after_observation)
	var commitment_after := consumer.find(
		"var target_commitment_after := _facility_commitment_observation",
		target_gate
	)
	var duplicate_gate := consumer.find("var duplicates_before_continuation", commitment_after)
	var resume_session := consumer.find(".resume_session()", duplicate_gate)
	_expect(
		drain >= 0 and after_observation > drain and target_gate > after_observation,
		"Process B observes and validates the target after the bounded drain"
	)
	_expect(
		commitment_after > target_gate and duplicate_gate > commitment_after,
		"Process B validates finalized facility commitment before duplicate sampling"
	)
	_expect(
		not consumer.contains('queue_target_after.get("facility_entry"'),
		"Process B never expects a private facility binding in History"
	)
	_expect(
		resume_session > duplicate_gate,
		"Process B cannot resume gameplay before target and duplicate evidence is sealed"
	)
	var settlement := consumer.find("var terminal := await _finish_to_settlement")
	var final_target := consumer.find(
		"var queue_target_final := _queue_target_observation",
		settlement
	)
	var final_duplicates := consumer.find("var final_duplicates :=", final_target)
	var final_gate := consumer.find(
		"_queue_target_post_continuation_quiet_valid(queue_target_after, queue_target_final)",
		final_duplicates
	)
	var final_fail := consumer.find(
		'return _fail(base, "consumer_post_continuation_exact_once_invalid")',
		final_gate
	)
	var manifest_merge := consumer.find("base.merge({", final_fail)
	_expect(
		settlement >= 0 and final_target > settlement and final_duplicates > final_target \
				and final_gate > final_duplicates and final_fail > final_gate \
				and manifest_merge > final_fail,
		"Process B resamples target and duplicate evidence after settlement before manifest seal"
	)
	for field in [
		"duplicate_queue_entry_count",
		"duplicate_facility_creation_count",
		"duplicate_card_consumption_count",
		"duplicate_cost_consumption_count",
		"duplicate_sale_receipt_count",
	]:
		_expect(
			consumer.contains('"%s": int(final_duplicates.get("%s", -1))' % [field, field]),
			"Process B manifest seals final %s evidence" % field
		)


func _test_process_c_ordering(validator: String) -> void:
	var restore_call := validator.find("var load := _resume_via_player_flow")
	var restore_failure := validator.find("if not bool(load.get(\"ok\", false))", restore_call)
	var restore_return := validator.find("return _fail(base", restore_failure)
	var recapture := validator.find("var recapture := _capture_sections", restore_call)
	_expect(
		restore_call >= 0 and restore_failure > restore_call \
				and restore_return > restore_failure and recapture > restore_return,
		"Process C returns immediately on restore failure before recapture"
	)

	var queue_before := validator.find("var queue_target_before := _queue_target_observation")
	var idle_gate := validator.find("var no_continuation := await", queue_before)
	var queue_after := validator.find("var queue_target_after := _queue_target_observation", idle_gate)
	var target_gate := validator.find("var queue_target_exact :=", queue_after)
	var commitment := validator.find("var validator_target_commitment :=", target_gate)
	var duplicates := validator.find("var duplicate_observation :=", commitment)
	var exact := validator.find("var exact :=", duplicates)
	_expect(
		queue_before >= 0 and idle_gate > queue_before and queue_after > idle_gate,
		"Process C resamples the target only after the bounded no-continuation gate"
	)
	_expect(
		target_gate > queue_after and commitment > target_gate \
				and duplicates > commitment and exact > duplicates,
		"Process C seals target, commitment, and duplicate evidence before success"
	)
	for token in [
		"and queue_target_exact and validator_target_commitment_exact",
		"and _duplicate_observation_is_zero(duplicate_observation)",
		'and bool(no_continuation.get("accepted", false))',
	]:
		_expect(
			validator.contains(token),
			"Process C final exact gate consumes %s" % token
		)
	_expect(
		validator.contains(
			"_facility_commitment_observation_by_resolution("
		) and not validator.contains('queue_target_after.get("facility_entry"'),
		"Process C verifies the authoritative lifecycle by resolution ID without History secrets"
	)

	var source_envelope := validator.find("var source_envelope:")
	var source_victory := validator.find(
		"var source_victory_unresolved := _readback_victory_unresolved(context, source_envelope)",
		source_envelope
	)
	var victory_projection := validator.find(
		'"victory_unresolved_before_save": source_victory_unresolved',
		source_victory
	)
	_expect(
		source_envelope >= 0 and source_victory > source_envelope \
				and victory_projection > source_victory,
		"Process C victory evidence is projected from the Generation 2 source envelope"
	)

	var pause_session := validator.find("coordinator.pause_session()", exact)
	var disable_main := validator.find("active_main.process_mode = Node.PROCESS_MODE_DISABLED", pause_session)
	var manifest_merge := validator.find("base.merge({", disable_main)
	_expect(
		pause_session > exact and disable_main > pause_session and manifest_merge > disable_main,
		"Process C disables task progression before sealing its successful manifest"
	)


func _test_restore_exact_once_contract(resume: String) -> void:
	for token in [
		"registry_commit_delta == 1",
		"registry_rollback_delta == 0",
		"barrier_enter_delta == 1",
		"barrier_commit_delta == 1",
		"barrier_rollback_delta == 0",
		"registry_rebind_delta == 1",
		"coordinator_rebind_delta == 1",
		"coordinator_generation_delta == 1",
		"coordinator_refresh_delta == 1",
		"registry_operation_delta == 1",
		'debug_after.get("last_owner_apply_count", 0)) == SAVE_SECTION_ORDER.size()',
		'debug_after.get("last_registry_apply_count", 0)) == 1',
		'debug_before.get("partial_restore_state_count", -1)) == 0',
		'debug_after.get("partial_restore_state_count", -1)) == 0',
	]:
		_expect(resume.contains(token), "restore exact-once gate contains %s" % token)
	_expect(
		resume.contains(
			"var ok := receipt != null and receipt.accepted and receipt.applied and cross_owner_exact"
		),
		"restore receipt success is gated by the complete cross-owner exact-once predicate"
	)


func _test_facility_lifecycle_contract() -> void:
	var transaction_id := "facility-resolution.7.fixture"
	var green: Dictionary = {}
	green[transaction_id] = {
			"transaction_id": transaction_id,
			"state": "finalized",
			"rollback_open": false,
			"terminal_receipt": {
				"transaction_id": transaction_id,
				"receipt_kind": "facility_action_finalize",
				"committed": true,
				"finalized": true,
				"rolled_back": false,
				"duplicate": false,
			},
	}
	var accepted := DRIVER._facility_commitment_observation_from_lifecycles(green, 7)
	_expect(
		bool(accepted.get("valid", false)) and bool(accepted.get("settled", false)) \
				and bool(accepted.get("committed", false)),
		"one finalized authoritative lifecycle is accepted"
	)
	_expect(
		not bool(DRIVER._facility_commitment_observation_from_lifecycles({}, 7).get("valid", false)),
		"a missing lifecycle is rejected"
	)
	var ambiguous := green.duplicate(true)
	var second: Dictionary = green[transaction_id].duplicate(true)
	second["transaction_id"] = "facility-resolution.7.second"
	var second_receipt: Dictionary = second["terminal_receipt"]
	second_receipt["transaction_id"] = "facility-resolution.7.second"
	ambiguous["facility-resolution.7.second"] = second
	_expect(
		not bool(DRIVER._facility_commitment_observation_from_lifecycles(ambiguous, 7).get("valid", false)),
		"multiple matching lifecycles are rejected"
	)
	for mutation in [
		{"path": "state", "value": "committed", "label": "non-finalized state"},
		{"path": "rollback_open", "value": true, "label": "open rollback"},
		{"path": "terminal_transaction", "value": "wrong", "label": "receipt identity mismatch"},
		{"path": "duplicate", "value": true, "label": "duplicate receipt"},
	]:
		var changed := green.duplicate(true)
		var changed_lifecycle: Dictionary = changed[transaction_id]
		var changed_receipt: Dictionary = changed_lifecycle["terminal_receipt"]
		if mutation.path == "terminal_transaction":
			changed_receipt["transaction_id"] = mutation.value
		elif mutation.path == "duplicate":
			changed_receipt["duplicate"] = mutation.value
		else:
			changed_lifecycle[mutation.path] = mutation.value
		_expect(
			not bool(DRIVER._facility_commitment_observation_from_lifecycles(changed, 7).get("valid", false)),
			"%s is rejected" % mutation.label
		)


func _test_duplicate_observation_shape(duplicate_observation: String) -> void:
	for token in [
		'queue_state.has("current_queue")',
		'execution_state.has("completed_resolution_ids")',
		'history_state.has("appended_resolution_ids")',
		'infrastructure_state.has("facilities")',
		'mana_state.has("reservations")',
		'sale_receipts_variant is Array',
		'"valid": valid',
	]:
		_expect(
			duplicate_observation.contains(token),
			"duplicate observation fails closed on required owner shape %s" % token
		)


func _queue_observation(
	fingerprint: String,
	pending_count: int,
	completed_count: int,
	history_count: int,
	execution_finalize_count: int,
	history_append_count: int
) -> Dictionary:
	return {
		"valid": true,
		"resolution_id": 7,
		"stable_target_fingerprint": fingerprint,
		"stable_target_valid": pending_count == 1,
		"history_privacy_redacted": pending_count == 0 and history_count == 1,
		"pending_count": pending_count,
		"completed_count": completed_count,
		"history_count": history_count,
		"history_lineage_count": history_count,
		"execution_finalize_count": execution_finalize_count,
		"history_append_count": history_append_count,
		"history_duplicate_count": 0,
		"transition_duplicate_count": 0,
		"inventory_queue_commit_count": 1,
		"public_log_duplicate_count": 0,
		"public_log_collision_count": 0,
	}


func _function_source(source: String, function_name: String) -> String:
	var marker := "func %s(" % function_name
	var static_marker := "static func %s(" % function_name
	var start := source.find(marker)
	if start < 0:
		start = source.find(static_marker)
	if start < 0:
		return ""
	var next_function := source.find("\nfunc ", start + marker.length())
	var next_static_function := source.find("\nstatic func ", start + marker.length())
	if next_function < 0 or (next_static_function >= 0 and next_static_function < next_function):
		next_function = next_static_function
	return source.substr(start) if next_function < 0 \
			else source.substr(start, next_function - start)


func _source_between(source: String, start_marker: String, end_marker: String) -> String:
	var start := source.find(start_marker)
	if start < 0:
		return ""
	var end := source.find(end_marker, start + start_marker.length())
	return "" if end < 0 else source.substr(start, end - start)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
