extends RefCounted
class_name ColdRestoreTerminalEvidence

## QA-only evidence helper for the cold-restore terminal continuation.
##
## The helper owns no gameplay state. Its only write outside the authoritative
## RuntimeLoop is acquiring/releasing the same bounded process lease used by
## the accepted FullRun driver. All terminal progress enters through that loop.

const AUTHORITATIVE_STEPPER := preload("res://scripts/tools/full_run_authoritative_runtime_stepper.gd")
const FULL_RUN_EVIDENCE := preload("res://scripts/tools/full_run_quality_driver.gd")

const CONTRACT_ID := "cold_restore_terminal_evidence_v1"
const TERMINAL_STEP_SECONDS := 1.0
const GENERATION_TWO_LIFECYCLE_SETTLE_FRAME_LIMIT := 2
const TERMINAL_PRESENTATION_RETRY_LIMIT := 8
const TERMINAL_QUIESCENT_FRAME_COUNT := 8
const ABSOLUTE_TERMINAL_FRAME_LIMIT := 512
const TIMER_TRACE_SAMPLE_LIMIT := 512
const EXPECTED_VICTORY_STATES := ["idle", "qualification", "audit", "resolved"]


static func contract_snapshot() -> Dictionary:
	return {
		"schema_version": 1,
		"contract_id": CONTRACT_ID,
		"qa_only": true,
		"runtime_entry": "FullRunAuthoritativeRuntimeStepper.advance_bounded",
		"step_seconds": TERMINAL_STEP_SECONDS,
		"expected_victory_states": EXPECTED_VICTORY_STATES.duplicate(),
		"generation_two_lifecycle_settle_frame_limit": GENERATION_TWO_LIFECYCLE_SETTLE_FRAME_LIMIT,
		"terminal_presentation_retry_limit": TERMINAL_PRESENTATION_RETRY_LIMIT,
		"terminal_quiescent_frame_count": TERMINAL_QUIESCENT_FRAME_COUNT,
		"generation_two_sale_binding_supported": true,
		"generation_two_sale_binding_required": true,
		"requires_first_active_qualification": true,
		"owns_eligibility_setup": false,
		"automatic_frame_observation": "RuntimeLoop.frame_advanced",
		"direct_world_access": false,
		"direct_victory_resolution": false,
		"direct_terminal_presentation": false,
		"direct_session_completion": false,
	}


static func acquire_manual_lease(context: Dictionary) -> Dictionary:
	var nodes := _runtime_nodes(context)
	if not bool(nodes.get("ready", false)):
		return _lease_rejected(str(nodes.get("reason_code", "terminal_runtime_dependency_missing")))
	var runtime_loop := nodes.get("runtime_loop") as RuntimeLoop
	var barrier := nodes.get("barrier") as SaveRestoreRuntimeBarrier
	var barrier_debug := barrier.debug_snapshot()
	if not bool(barrier_debug.get("barrier_ready", false)) \
			or bool(barrier_debug.get("active", true)):
		return _lease_rejected("restore_barrier_still_active")
	var session := nodes.get("session") as GameSessionRuntimeController
	var session_barrier := session.restore_barrier_snapshot()
	if bool(session_barrier.get("active", true)) \
			or not str(session_barrier.get("operation_id", "missing")).is_empty():
		return _lease_rejected("session_restore_barrier_still_active")
	if not runtime_loop.is_inside_tree() or not runtime_loop.can_process() \
			or not runtime_loop.is_processing():
		return _lease_rejected("runtime_loop_manual_lease_not_available")
	var loop_debug := runtime_loop.debug_snapshot()
	var frame_index := int(loop_debug.get("frame_index", -1))
	if frame_index < 0 or not bool(loop_debug.get("frame_owner", false)) \
			or not bool(loop_debug.get("phase_ready", false)) \
			or bool(loop_debug.get("restore_barrier_held", true)) \
			or bool(loop_debug.get("session_start_barrier_held", true)):
		return _lease_rejected("runtime_loop_manual_lease_precondition_invalid")
	runtime_loop.set_process(false)
	if runtime_loop.is_processing():
		return _lease_rejected("runtime_loop_manual_lease_rejected")
	var after := runtime_loop.debug_snapshot()
	if int(after.get("frame_index", -1)) != frame_index:
		runtime_loop.set_process(true)
		return _lease_rejected("runtime_loop_manual_lease_frame_changed")
	return {
		"accepted": true,
		"reason_code": "runtime_loop_manual_lease_acquired",
		"lease_contract_id": CONTRACT_ID,
		"frame_index": frame_index,
	}


static func release_manual_lease(context: Dictionary) -> Dictionary:
	var nodes := _runtime_nodes(context)
	if not bool(nodes.get("ready", false)):
		return {"released": false, "reason_code": str(nodes.get("reason_code", "terminal_runtime_dependency_missing"))}
	var runtime_loop := nodes.get("runtime_loop") as RuntimeLoop
	if runtime_loop.is_processing():
		return {"released": false, "reason_code": "runtime_loop_manual_lease_not_owned"}
	runtime_loop.set_process(true)
	return {
		"released": runtime_loop.is_processing(),
		"reason_code": "runtime_loop_manual_lease_released" \
			if runtime_loop.is_processing() else "runtime_loop_manual_lease_release_failed",
	}


static func capture_public_sale_binding(context: Dictionary) -> Dictionary:
	var nodes := _runtime_nodes(context)
	if not bool(nodes.get("ready", false)):
		return {
			"accepted": false,
			"reason_code": str(nodes.get("reason_code", "terminal_runtime_dependency_missing")),
			"binding": {},
		}
	var sale := _public_sale_receipt_observation(
		nodes.get("coordinator") as GameRuntimeCoordinator
	)
	var binding := _sale_binding_from_observation(sale)
	if binding.is_empty():
		return {
			"accepted": false,
			"reason_code": "generation_two_public_sale_evidence_missing",
			"binding": {},
		}
	return {
		"accepted": true,
		"reason_code": "generation_two_public_sale_binding_captured",
		"binding": binding,
	}


static func _await_generation_two_lifecycle_clear(
	tree: SceneTree,
	nodes: Dictionary,
	expected_frame: int
) -> Dictionary:
	var runtime_loop := nodes.get("runtime_loop") as RuntimeLoop
	if tree == null or runtime_loop == null or runtime_loop.get_tree() != tree \
			or runtime_loop.is_processing() or expected_frame < 0:
		return {
			"verified": false,
			"reason_code": "generation_two_lifecycle_settle_precondition_invalid",
			"frame_count": 0,
		}
	for settle_frame in range(GENERATION_TWO_LIFECYCLE_SETTLE_FRAME_LIMIT + 1):
		var lifecycle_gate := _lifecycle_checkpoint_gate_for_nodes(nodes)
		if bool(lifecycle_gate.get("verified", false)):
			return {
				"verified": true,
				"reason_code": "generation_two_lifecycle_checkpoint_clear",
				"frame_count": settle_frame,
			}
		if str(lifecycle_gate.get("reason_code", "")) \
				!= "generation_two_lifecycle_checkpoint_pending":
			return {
				"verified": false,
				"reason_code": str(lifecycle_gate.get(
					"reason_code",
					"generation_two_lifecycle_checkpoint_invalid"
				)),
				"frame_count": settle_frame,
			}
		if settle_frame >= GENERATION_TWO_LIFECYCLE_SETTLE_FRAME_LIMIT:
			break
		# Save observers clear their lifecycle checkpoints through call_deferred.
		# Keep RuntimeLoop disabled while yielding so this synchronization window
		# cannot advance world time or victory.
		await tree.process_frame
		if runtime_loop.is_processing() \
				or int(runtime_loop.debug_snapshot().get("frame_index", -1)) != expected_frame:
			return {
				"verified": false,
				"reason_code": "generation_two_lifecycle_settle_lease_lost",
				"frame_count": settle_frame + 1,
			}
	return {
		"verified": false,
		"reason_code": "generation_two_lifecycle_checkpoint_settle_exhausted",
		"frame_count": GENERATION_TWO_LIFECYCLE_SETTLE_FRAME_LIMIT,
	}


static func _lifecycle_checkpoint_gate_for_nodes(nodes: Dictionary) -> Dictionary:
	var victory_port := nodes.get("victory_port") as RuntimeVictoryPort
	var presentation_queries := nodes.get("presentation_queries") as TablePresentationQueryPorts
	var settlement := nodes.get("settlement") as FinalSettlementRuntimeComposition
	if victory_port == null or presentation_queries == null or settlement == null:
		return {
			"verified": false,
			"reason_code": "generation_two_lifecycle_checkpoint_dependency_missing",
		}
	return _lifecycle_checkpoint_gate(
		victory_port.debug_snapshot(),
		presentation_queries.debug_snapshot(),
		settlement.debug_snapshot()
	)


static func _lifecycle_checkpoint_gate(
	victory_port_debug: Dictionary,
	presentation_debug: Dictionary,
	settlement_debug: Dictionary
) -> Dictionary:
	for snapshot in [victory_port_debug, presentation_debug, settlement_debug]:
		if not snapshot.has("lifecycle_checkpoint_pending") \
				or not snapshot.has("lifecycle_transition_kind"):
			return {
				"verified": false,
				"reason_code": "generation_two_lifecycle_checkpoint_shape_invalid",
			}
	var pending := bool(victory_port_debug.get("lifecycle_checkpoint_pending", true)) \
		or bool(presentation_debug.get("lifecycle_checkpoint_pending", true)) \
		or bool(settlement_debug.get("lifecycle_checkpoint_pending", true)) \
		or not str(victory_port_debug.get("lifecycle_transition_kind", "missing")).is_empty() \
		or not str(presentation_debug.get("lifecycle_transition_kind", "missing")).is_empty() \
		or not str(settlement_debug.get("lifecycle_transition_kind", "missing")).is_empty()
	if pending:
		return {
			"verified": false,
			"reason_code": "generation_two_lifecycle_checkpoint_pending",
		}
	if not presentation_debug.has("session_plan_checkpoint_pending") \
			or bool(presentation_debug.get("session_plan_checkpoint_pending", true)) \
			or not settlement_debug.has("session_plan_checkpoint_pending") \
			or bool(settlement_debug.get("session_plan_checkpoint_pending", true)):
		return {
			"verified": false,
			"reason_code": "generation_two_lifecycle_checkpoint_pending",
		}
	return {
		"verified": true,
		"reason_code": "generation_two_lifecycle_checkpoint_clear",
	}


static func generation_two_idle_gate(context: Dictionary, expected_frame: int) -> Dictionary:
	var nodes := _runtime_nodes(context)
	if not bool(nodes.get("ready", false)):
		return _gate_rejected(str(nodes.get("reason_code", "terminal_runtime_dependency_missing")))
	if expected_frame < 0:
		return _gate_rejected("generation_two_expected_frame_invalid")
	var coordinator := nodes.get("coordinator") as GameRuntimeCoordinator
	var session := nodes.get("session") as GameSessionRuntimeController
	var barrier := nodes.get("barrier") as SaveRestoreRuntimeBarrier
	var runtime_loop := nodes.get("runtime_loop") as RuntimeLoop
	var victory_port := nodes.get("victory_port") as RuntimeVictoryPort
	var presentation_queries := nodes.get("presentation_queries") as TablePresentationQueryPorts
	var settlement := nodes.get("settlement") as FinalSettlementRuntimeComposition
	var standings := nodes.get("standings") as StandingsPublicQueryPort

	var barrier_debug := barrier.debug_snapshot()
	if not bool(barrier_debug.get("barrier_ready", false)) or bool(barrier_debug.get("active", true)):
		return _gate_rejected("generation_two_restore_barrier_not_released")
	if runtime_loop.is_processing():
		return _gate_rejected("generation_two_runtime_loop_not_leased")
	var loop_debug := runtime_loop.debug_snapshot()
	if int(loop_debug.get("frame_index", -1)) != expected_frame:
		return _gate_rejected("generation_two_runtime_frame_changed")
	if not bool(loop_debug.get("frame_owner", false)) or not bool(loop_debug.get("phase_ready", false)) \
			or bool(loop_debug.get("restore_barrier_held", true)) \
			or bool(loop_debug.get("session_start_barrier_held", true)):
		return _gate_rejected("generation_two_runtime_loop_not_ready")

	var session_summary := session.session_summary()
	var session_barrier := session.restore_barrier_snapshot()
	if bool(session_barrier.get("active", true)) \
			or not str(session_barrier.get("operation_id", "missing")).is_empty():
		return _gate_rejected("generation_two_session_restore_barrier_active")
	var session_outcome: Dictionary = session_summary.get("outcome_receipt", {}) \
		if session_summary.get("outcome_receipt", {}) is Dictionary else {}
	if str(session_summary.get("session_state", "")) != "running" or not session_outcome.is_empty():
		return _gate_rejected("generation_two_session_not_running_unresolved")
	var forced_decision := coordinator.active_forced_decision(0)
	if coordinator.blocks_global_time() or bool(forced_decision.get("active", not forced_decision.is_empty())):
		return _gate_rejected("generation_two_forced_decision_active")

	var victory := coordinator.victory_control_public_snapshot(-1)
	var victory_outcome: Dictionary = victory.get("outcome_receipt", {}) \
		if victory.get("outcome_receipt", {}) is Dictionary else {}
	if str(victory.get("visibility_scope", "")) != "public" \
			or str(victory.get("state", "")) != "idle" \
			or not victory_outcome.is_empty() \
			or not is_zero_approx(float(victory.get("qualification_remaining_seconds", -1.0))) \
			or not is_zero_approx(float(victory.get("audit_remaining_seconds", -1.0))):
		return _gate_rejected("generation_two_victory_not_idle")

	var victory_port_debug := victory_port.debug_snapshot()
	var presentation_debug := presentation_queries.debug_snapshot()
	var settlement_debug := settlement.debug_snapshot()
	var lifecycle_gate := _lifecycle_checkpoint_gate(
		victory_port_debug,
		presentation_debug,
		settlement_debug
	)
	if not bool(lifecycle_gate.get("verified", false)):
		return _gate_rejected(str(lifecycle_gate.get(
			"reason_code",
			"generation_two_lifecycle_checkpoint_invalid"
		)))
	if not bool(victory_port_debug.get("ready", false)) \
			or bool(victory_port_debug.get("pending_terminal", false)) \
			or int(victory_port_debug.get("terminal_queue_count", -1)) != 0 \
			or int(victory_port_debug.get("terminal_retry_count", -1)) != 0 \
			or int(victory_port_debug.get("terminal_commit_count", -1)) != 0 \
			or int(victory_port_debug.get("terminal_reject_count", -1)) != 0 \
			or int(victory_port_debug.get("terminal_stale_drop_count", -1)) != 0:
		return _gate_rejected("generation_two_terminal_port_not_clean")
	if not bool(presentation_debug.get("configured", false)) \
			or not bool(presentation_debug.get("requires_outcome_presentation_acceptance", false)) \
			or int(presentation_debug.get("outcome_presentation_result_count", -1)) != 0 \
			or int(presentation_debug.get("outcome_presentation_accepted_count", -1)) != 0 \
			or int(presentation_debug.get("outcome_presentation_rejected_count", -1)) != 0 \
			or int(presentation_debug.get("outcome_immediate_refresh_count", -1)) != 0:
		return _gate_rejected("generation_two_presentation_not_clean")
	var victory_receipts: Dictionary = presentation_debug.get("victory_receipts", {}) \
		if presentation_debug.get("victory_receipts", {}) is Dictionary else {}
	if not bool(victory_receipts.get("configured", false)) \
			or str(victory_receipts.get("last_state", "")) != "idle" \
			or int(victory_receipts.get("outcome_receipt_count", -1)) != 0 \
			or int(victory_receipts.get("applied_outcome_count", -1)) != 0 \
			or int(victory_receipts.get("retained_outcome_receipt_count", -1)) != 0:
		return _gate_rejected("generation_two_victory_receipts_not_clean")

	if int(settlement_debug.get("present_count", -1)) != 0 \
			or int(settlement_debug.get("presented_outcome_count", -1)) != 0 \
			or int(settlement_debug.get("logged_outcome_count", -1)) != 0 \
			or int(settlement_debug.get("action_emission_count", -1)) != 0 \
			or not str(settlement_debug.get("last_presented_outcome_id", "")).is_empty() \
			or not bool(settlement_debug.get("source_adapter_ready", false)) \
			or not bool(settlement_debug.get("snapshot_service_ready", false)) \
			or not bool(settlement_debug.get("menu_overlay_ready", false)) \
			or not bool(settlement_debug.get("board_ready", false)) \
			or not settlement.last_public_snapshot().is_empty():
		return _gate_rejected("generation_two_settlement_not_clean")
	if _authorized_timer_contract(standings.victory_progress_for_authorized_viewer()).is_empty():
		return _gate_rejected("generation_two_authorized_timer_contract_unavailable")
	var final_log := _public_final_settlement_log_observation(coordinator)
	if int(final_log.get("public_entry_count", -1)) != 0:
		return _gate_rejected("generation_two_final_settlement_log_present")
	var sale := _public_sale_receipt_observation(coordinator)
	if not bool(sale.get("observed", false)) \
			or int(sale.get("public_event_count", 0)) <= 0 \
			or str(sale.get("public_fingerprint", "")).length() != 64:
		return _gate_rejected("generation_two_public_sale_evidence_missing")
	var expected_sale: Dictionary = context.get("generation_two_sale_binding", {}) \
		if context.get("generation_two_sale_binding", {}) is Dictionary else {}
	if not _sale_binding_valid(expected_sale):
		return _gate_rejected("generation_two_public_sale_binding_missing")
	var current_sale_binding := _sale_binding_from_observation(sale)
	if expected_sale != current_sale_binding:
		return _gate_rejected("generation_two_public_sale_binding_mismatch")
	return {
		"accepted": true,
		"reason_code": "generation_two_idle_gate_passed",
		"frame_index": expected_frame,
		"victory_state": "idle",
		"sale_receipt_count": int(sale.get("public_event_count", 0)),
		"sale_receipt_source_revision": int(sale.get("latest_source_revision", 0)),
		"sale_receipt_fingerprint": str(sale.get("public_fingerprint", "")),
		"sale_binding": current_sale_binding,
	}


static func finish_to_settlement(
	tree: SceneTree,
	context: Dictionary,
	lease_frame: int
) -> Dictionary:
	var nodes := _runtime_nodes(context)
	if tree == null or not bool(nodes.get("ready", false)):
		return _finish_failure(
			nodes.get("runtime_loop") as RuntimeLoop,
			"terminal_runtime_dependency_missing"
		)
	var runtime_loop := nodes.get("runtime_loop") as RuntimeLoop
	var coordinator := nodes.get("coordinator") as GameRuntimeCoordinator
	var session := nodes.get("session") as GameSessionRuntimeController
	var standings := nodes.get("standings") as StandingsPublicQueryPort
	var lifecycle_settle: Dictionary = await _await_generation_two_lifecycle_clear(
		tree,
		nodes,
		lease_frame
	)
	if not bool(lifecycle_settle.get("verified", false)):
		return _finish_failure(
			runtime_loop,
			str(lifecycle_settle.get(
				"reason_code",
				"generation_two_lifecycle_checkpoint_invalid"
			)),
			[],
			{"lifecycle_settle_frames": int(lifecycle_settle.get("frame_count", 0))}
		)
	var gate := generation_two_idle_gate(context, lease_frame)
	if not bool(gate.get("accepted", false)):
		return _finish_failure(
			runtime_loop,
			str(gate.get("reason_code", "generation_two_idle_gate_rejected")),
			[],
			{"lifecycle_settle_frames": int(lifecycle_settle.get("frame_count", 0))}
		)

	var state_sequence: Array[String] = ["idle"]
	var observation_sequence := 1
	var timer_contract := _authorized_timer_contract(standings.victory_progress_for_authorized_viewer())
	var initial_victory := coordinator.victory_control_public_snapshot(-1)
	var initial_sample := _capture_timer_sample(
		coordinator,
		initial_victory,
		observation_sequence,
		timer_contract
	)
	if initial_sample.is_empty():
		return _finish_failure(runtime_loop, "terminal_idle_timer_sample_invalid", state_sequence)
	var timer_trace: Array = [initial_sample]
	var sale_observation := _public_sale_receipt_observation(coordinator)
	if int(sale_observation.get("public_event_count", -1)) != int(gate.get("sale_receipt_count", -2)) \
			or int(sale_observation.get("latest_source_revision", -1)) != int(gate.get("sale_receipt_source_revision", -2)) \
			or str(sale_observation.get("public_fingerprint", "")) != str(gate.get("sale_receipt_fingerprint", "")):
		return _finish_failure(runtime_loop, "generation_two_public_sale_binding_changed", state_sequence)
	sale_observation["first_observation_sequence"] = observation_sequence
	sale_observation["first_world_effective_us"] = int(round(
		float(sale_observation.get("first_world_seconds", -1.0)) * 1_000_000.0
	))

	var expected_frame := lease_frame
	var active_steps := 0
	var attempted_steps := 0
	var terminal_zero_world_steps := 0
	var failure_code := ""
	while not session.is_finished() and attempted_steps < ABSOLUTE_TERMINAL_FRAME_LIMIT:
		var step: Dictionary = AUTHORITATIVE_STEPPER.advance_bounded(
			runtime_loop,
			TERMINAL_STEP_SECONDS,
			1
		)
		if not bool(step.get("accepted", false)) \
				or int(step.get("attempted_steps", 0)) != 1 \
				or int(step.get("frame_index_before", -1)) != expected_frame:
			failure_code = "terminal_authoritative_step_rejected"
			break
		attempted_steps += 1
		expected_frame += 1
		if int(step.get("frame_index_after", -1)) != expected_frame:
			failure_code = "terminal_runtime_frame_discontinuity"
			break
		var frame := runtime_loop.last_frame_receipt()
		var frame_evidence := _terminal_step_frame_evidence(step, frame, session.is_finished())
		if not bool(frame_evidence.get("valid", false)):
			failure_code = str(frame_evidence.get("reason_code", "terminal_runtime_frame_invalid"))
			break
		if bool(frame_evidence.get("active", false)):
			active_steps += 1
		if bool(frame_evidence.get("terminal_zero_world", false)):
			terminal_zero_world_steps += 1
		if terminal_zero_world_steps > TERMINAL_PRESENTATION_RETRY_LIMIT:
			failure_code = "terminal_presentation_retry_exhausted"
			break

		var victory := coordinator.victory_control_public_snapshot(-1)
		var transition := _append_strict_victory_state(state_sequence, victory)
		if not bool(transition.get("accepted", false)):
			failure_code = str(transition.get("reason_code", "terminal_victory_state_invalid"))
			break
		var candidate_timer_contract := _authorized_timer_contract(
			standings.victory_progress_for_authorized_viewer()
		)
		if timer_contract.is_empty():
			timer_contract = candidate_timer_contract
			if not timer_contract.is_empty():
				_backfill_timer_contract(timer_trace, timer_contract)
		elif candidate_timer_contract.is_empty() or candidate_timer_contract != timer_contract:
			failure_code = "authorized_victory_timer_contract_changed"
			break
		observation_sequence += 1
		var sample := _capture_timer_sample(
			coordinator,
			victory,
			observation_sequence,
			timer_contract
		)
		if sample.is_empty() or not _append_timer_sample(timer_trace, sample):
			failure_code = "terminal_timer_trace_invalid"
			break
		if active_steps == 1 and state_sequence != ["idle", "qualification"]:
			failure_code = "generation_two_not_victory_ready"
			break
		if active_steps >= 1 and timer_contract.is_empty():
			failure_code = "authorized_victory_timer_contract_unavailable"
			break
		if not timer_contract.is_empty():
			var duration_us := int(timer_contract.get("qualification_duration_us", 0)) \
				+ int(timer_contract.get("audit_duration_us", 0))
			var active_step_limit := ceili(float(duration_us) / 1_000_000.0 / TERMINAL_STEP_SECONDS) + 1
			if active_steps > active_step_limit:
				failure_code = "terminal_active_step_budget_exhausted"
				break
		if str(victory.get("state", "")) == "resolved" and not session.is_finished():
			var drain: Dictionary = await _drain_terminal_presentation(
				tree,
				nodes,
				expected_frame
			)
			attempted_steps += int(drain.get("frame_count", 0))
			terminal_zero_world_steps += int(drain.get("frame_count", 0))
			expected_frame = int(drain.get("frame_index", expected_frame))
			if not bool(drain.get("verified", false)):
				failure_code = str(drain.get("reason_code", "terminal_presentation_drain_failed"))
				break
			if terminal_zero_world_steps > TERMINAL_PRESENTATION_RETRY_LIMIT:
				failure_code = "terminal_presentation_retry_exhausted"
				break
	if failure_code.is_empty() and not session.is_finished():
		failure_code = "terminal_absolute_frame_budget_exhausted"
	if not failure_code.is_empty():
		return _finish_failure(
			runtime_loop,
			failure_code,
			state_sequence,
			{"active_steps": active_steps, "attempted_steps": attempted_steps}
		)
	if not strict_victory_state_sequence_valid(state_sequence):
		return _finish_failure(runtime_loop, "terminal_victory_sequence_incomplete", state_sequence)
	var timer_evidence: Dictionary = FULL_RUN_EVIDENCE.timer_traversal_evidence(
		timer_trace,
		sale_observation,
		timer_contract,
		"",
		false
	)
	if not bool(timer_evidence.get("verified", false)):
		return _finish_failure(
			runtime_loop,
			"terminal_%s" % str(timer_evidence.get("reason_id", "timer_evidence_invalid")),
			state_sequence
		)
	var exact_once := _terminal_exact_once_probe(nodes)
	if not bool(exact_once.get("verified", false)):
		return _finish_failure(
			runtime_loop,
			str(exact_once.get("reason_code", "terminal_exact_once_invalid")),
			state_sequence
		)
	var quiescence: Dictionary = await _verify_terminal_quiescence(tree, nodes)
	if not bool(quiescence.get("verified", false)):
		return _finish_failure(
			runtime_loop,
			str(quiescence.get("reason_code", "terminal_quiescence_invalid")),
			state_sequence,
			{
				"active_steps": active_steps,
				"attempted_steps": attempted_steps,
				"quiet_frames": int(quiescence.get("frame_count", 0)),
				"world_delta": int(quiescence.get("world_delta", -1)),
				"rng_delta": int(quiescence.get("rng_draw_delta", -1)),
			}
		)
	return {
		"settled": true,
		"failure_code": "",
		"victory_state_sequence": state_sequence.duplicate(),
		"settlement_count": int(exact_once.get("terminal_commit_count", 0)),
		"presentation_count": int(exact_once.get("presentation_count", 0)),
		"public_log_count": int(exact_once.get("public_log_count", 0)),
		"quiet_frames": int(quiescence.get("frame_count", 0)),
		"world_delta": int(quiescence.get("world_delta", -1)),
		"rng_delta": int(quiescence.get("rng_draw_delta", -1)),
		"active_steps": active_steps,
		"attempted_steps": attempted_steps,
		"terminal_zero_world_steps": terminal_zero_world_steps,
		"lifecycle_settle_frames": int(lifecycle_settle.get("frame_count", 0)),
		"outcome_id": str(exact_once.get("outcome_id", "")),
		"outcome_identity_fingerprint": str(exact_once.get("outcome_identity_fingerprint", "")),
		"timer_evidence": timer_evidence.duplicate(true),
		"quiescence_fingerprint": str(quiescence.get("fingerprint", "")),
	}


static func strict_victory_state_sequence_valid(sequence: Array) -> bool:
	return sequence == EXPECTED_VICTORY_STATES


static func terminal_finished_frame_valid(frame: Dictionary, expected_frame_index: int) -> bool:
	return FULL_RUN_EVIDENCE._terminal_finished_frame_valid(frame, expected_frame_index)


static func terminal_exact_once_counts_valid(
	victory_port_debug: Dictionary,
	settlement_debug: Dictionary,
	outcome_id: String
) -> bool:
	return not outcome_id.is_empty() \
		and int(victory_port_debug.get("terminal_queue_count", 0)) == 1 \
		and int(victory_port_debug.get("terminal_retry_count", 0)) >= 1 \
		and int(victory_port_debug.get("terminal_commit_count", 0)) == 1 \
		and int(victory_port_debug.get("terminal_reject_count", -1)) >= 0 \
		and int(victory_port_debug.get("terminal_stale_drop_count", 0)) == 0 \
		and not bool(victory_port_debug.get("pending_terminal", true)) \
		and int(settlement_debug.get("present_count", 0)) == 1 \
		and int(settlement_debug.get("presented_outcome_count", 0)) == 1 \
		and int(settlement_debug.get("logged_outcome_count", 0)) == 1 \
		and str(settlement_debug.get("last_presented_outcome_id", "")) == outcome_id \
		and str(settlement_debug.get("last_public_snapshot_fingerprint", "")).length() == 64


static func _runtime_nodes(context: Dictionary) -> Dictionary:
	var main := context.get("main") as Node
	var services := context.get("services") as Node
	var coordinator := context.get("coordinator") as GameRuntimeCoordinator
	var session := context.get("session") as GameSessionRuntimeController
	var barrier := context.get("barrier") as SaveRestoreRuntimeBarrier
	if main == null or services == null or coordinator == null or session == null or barrier == null:
		return {"ready": false, "reason_code": "terminal_context_dependency_missing"}
	var runtime_loop := coordinator.get_node_or_null("RuntimeLoop") as RuntimeLoop
	var victory_port := coordinator.get_node_or_null("RuntimeWorldPorts/RuntimeVictoryPort") as RuntimeVictoryPort
	var presentation_queries := coordinator.table_presentation_query_ports()
	var settlement := services.get_node_or_null("FinalSettlementRuntimeComposition") as FinalSettlementRuntimeComposition
	var standings := main.get_node_or_null("RuntimeServices/StandingsPublicQueryPort") as StandingsPublicQueryPort
	if runtime_loop == null or victory_port == null or presentation_queries == null \
			or settlement == null or standings == null:
		return {"ready": false, "reason_code": "terminal_runtime_node_missing"}
	return {
		"ready": true,
		"reason_code": "terminal_runtime_nodes_ready",
		"main": main,
		"services": services,
		"coordinator": coordinator,
		"session": session,
		"barrier": barrier,
		"runtime_loop": runtime_loop,
		"victory_port": victory_port,
		"presentation_queries": presentation_queries,
		"settlement": settlement,
		"standings": standings,
	}


static func _authorized_timer_contract(progress: Dictionary) -> Dictionary:
	var qualification_value: Variant = progress.get("qualification_duration_seconds", null)
	var audit_value: Variant = progress.get("audit_duration_seconds", null)
	if int(progress.get("schema_version", 0)) != 1 \
			or not bool(progress.get("valid", false)) \
			or str(progress.get("visibility_scope", "")) != "viewer_private" \
			or int(progress.get("viewer_index", -1)) != 0 \
			or typeof(qualification_value) not in [TYPE_INT, TYPE_FLOAT] \
			or typeof(audit_value) not in [TYPE_INT, TYPE_FLOAT]:
		return {}
	var qualification_seconds := float(qualification_value)
	var audit_seconds := float(audit_value)
	if not is_finite(qualification_seconds) or qualification_seconds <= 0.0 \
			or not is_finite(audit_seconds) or audit_seconds <= 0.0:
		return {}
	var qualification_us := int(round(qualification_seconds * 1_000_000.0))
	var audit_us := int(round(audit_seconds * 1_000_000.0))
	if qualification_us <= 0 or audit_us <= 0:
		return {}
	return {
		"schema_version": 1,
		"visibility_scope": "viewer_private",
		"viewer_index": 0,
		"qualification_duration_seconds": qualification_seconds,
		"audit_duration_seconds": audit_seconds,
		"qualification_duration_us": qualification_us,
		"audit_duration_us": audit_us,
	}


static func _capture_timer_sample(
	coordinator: GameRuntimeCoordinator,
	victory: Dictionary,
	observation_sequence: int,
	timer_contract: Dictionary
) -> Dictionary:
	if coordinator == null or observation_sequence <= 0 \
			or str(victory.get("visibility_scope", "")) != "public" \
			or str(victory.get("state", "")) not in EXPECTED_VICTORY_STATES:
		return {}
	var clock := coordinator.world_effective_clock_snapshot()
	var world_effective_us := int(clock.get(
		"world_effective_us",
		int(round(float(clock.get("world_effective_seconds", -1.0)) * 1_000_000.0))
	))
	var qualification_remaining := float(victory.get("qualification_remaining_seconds", -1.0))
	var audit_remaining := float(victory.get("audit_remaining_seconds", -1.0))
	if world_effective_us < 0 or not is_finite(qualification_remaining) \
			or qualification_remaining < 0.0 or not is_finite(audit_remaining) \
			or audit_remaining < 0.0:
		return {}
	return {
		"observation_sequence": observation_sequence,
		"world_effective_us": world_effective_us,
		"state": str(victory.get("state", "")),
		"qualification_remaining_us": int(round(qualification_remaining * 1_000_000.0)),
		"audit_remaining_us": int(round(audit_remaining * 1_000_000.0)),
		"qualification_duration_us": int(timer_contract.get("qualification_duration_us", -1)),
		"audit_duration_us": int(timer_contract.get("audit_duration_us", -1)),
	}


static func _backfill_timer_contract(trace: Array, timer_contract: Dictionary) -> void:
	for index in range(trace.size()):
		if not (trace[index] is Dictionary):
			continue
		var sample := (trace[index] as Dictionary).duplicate(true)
		sample["qualification_duration_us"] = int(timer_contract.get("qualification_duration_us", -1))
		sample["audit_duration_us"] = int(timer_contract.get("audit_duration_us", -1))
		trace[index] = sample


static func _append_timer_sample(trace: Array, sample: Dictionary) -> bool:
	if sample.is_empty() or trace.size() >= TIMER_TRACE_SAMPLE_LIMIT:
		return false
	if not trace.is_empty():
		var previous: Dictionary = trace[-1] if trace[-1] is Dictionary else {}
		if int(previous.get("observation_sequence", -1)) >= int(sample.get("observation_sequence", -1)) \
				or int(previous.get("world_effective_us", -1)) > int(sample.get("world_effective_us", -1)):
			return false
		if str(previous.get("state", "")) == str(sample.get("state", "")) \
				and int(previous.get("world_effective_us", -1)) == int(sample.get("world_effective_us", -1)) \
				and int(previous.get("qualification_remaining_us", -1)) == int(sample.get("qualification_remaining_us", -1)) \
				and int(previous.get("audit_remaining_us", -1)) == int(sample.get("audit_remaining_us", -1)):
			return true
	trace.append(sample.duplicate(true))
	return true


static func _append_strict_victory_state(sequence: Array[String], victory: Dictionary) -> Dictionary:
	if str(victory.get("visibility_scope", "")) != "public":
		return {"accepted": false, "reason_code": "terminal_victory_snapshot_not_public"}
	var state_id := str(victory.get("state", "")).strip_edges()
	if state_id not in EXPECTED_VICTORY_STATES:
		return {"accepted": false, "reason_code": "terminal_victory_state_invalid"}
	if not sequence.is_empty() and sequence[-1] == state_id:
		return {"accepted": true, "reason_code": "terminal_victory_state_unchanged"}
	if sequence.size() >= EXPECTED_VICTORY_STATES.size() \
			or state_id != str(EXPECTED_VICTORY_STATES[sequence.size()]):
		return {"accepted": false, "reason_code": "terminal_victory_state_nonmonotonic"}
	sequence.append(state_id)
	return {"accepted": true, "reason_code": "terminal_victory_state_advanced"}


static func _terminal_step_frame_evidence(
	step: Dictionary,
	frame: Dictionary,
	session_finished: bool
) -> Dictionary:
	var path := str(frame.get("path", ""))
	var stopped_reason := str(frame.get("stopped_reason", ""))
	var world_delta := float(frame.get("world_delta", -1.0))
	var phase_trace: Array = frame.get("phase_trace", []) if frame.get("phase_trace", []) is Array else []
	if int(step.get("active_steps", 0)) == 1:
		return {
			"valid": path == "active" \
				and is_equal_approx(world_delta, TERMINAL_STEP_SECONDS) \
				and stopped_reason in ["completed", "session_finished_after_victory"],
			"reason_code": "terminal_active_frame_invalid",
			"active": true,
			"terminal_zero_world": false,
		}
	if path == "terminal_pending":
		return {
			"valid": is_zero_approx(world_delta) \
				and stopped_reason == "terminal_presentation_pending" \
				and _has_only_phase(phase_trace, "terminal_presentation_retry"),
			"reason_code": "terminal_pending_frame_invalid",
			"active": false,
			"terminal_zero_world": true,
		}
	if path == "finished" and session_finished:
		return {
			"valid": is_zero_approx(world_delta) \
				and stopped_reason == "session_finished_after_terminal_retry" \
				and _has_only_phase(phase_trace, "terminal_presentation_retry"),
			"reason_code": "terminal_retry_completion_frame_invalid",
			"active": false,
			"terminal_zero_world": true,
		}
	return {
		"valid": false,
		"reason_code": "terminal_runtime_path_not_advanceable",
		"active": false,
		"terminal_zero_world": false,
	}


static func _has_only_phase(phase_trace: Array, expected_phase: String) -> bool:
	return phase_trace.size() == 1 and str(phase_trace[0]) == expected_phase


static func _terminal_exact_once_probe(nodes: Dictionary) -> Dictionary:
	var coordinator := nodes.get("coordinator") as GameRuntimeCoordinator
	var session := nodes.get("session") as GameSessionRuntimeController
	var victory_port := nodes.get("victory_port") as RuntimeVictoryPort
	var presentation_queries := nodes.get("presentation_queries") as TablePresentationQueryPorts
	var settlement := nodes.get("settlement") as FinalSettlementRuntimeComposition
	var victory := coordinator.victory_control_public_snapshot(-1)
	var public_outcome: Dictionary = victory.get("outcome_receipt", {}) \
		if victory.get("outcome_receipt", {}) is Dictionary else {}
	var session_summary := session.session_summary()
	var session_outcome: Dictionary = session_summary.get("outcome_receipt", {}) \
		if session_summary.get("outcome_receipt", {}) is Dictionary else {}
	var identity: Dictionary = FULL_RUN_EVIDENCE.outcome_identity_evidence(public_outcome, session_outcome)
	var outcome_id := str(public_outcome.get("outcome_id", ""))
	var audit_evidence: Dictionary = public_outcome.get("audit_evidence", {}) \
		if public_outcome.get("audit_evidence", {}) is Dictionary else {}
	var victory_port_debug := victory_port.debug_snapshot()
	var presentation_debug := presentation_queries.debug_snapshot()
	var settlement_debug := settlement.debug_snapshot()
	var lifecycle_gate := _lifecycle_checkpoint_gate(
		victory_port_debug,
		presentation_debug,
		settlement_debug
	)
	var victory_receipts: Dictionary = presentation_debug.get("victory_receipts", {}) \
		if presentation_debug.get("victory_receipts", {}) is Dictionary else {}
	var final_log := _public_final_settlement_log_observation(coordinator, outcome_id)
	var counts_valid := terminal_exact_once_counts_valid(
		victory_port_debug,
		settlement_debug,
		outcome_id
	)
	var presentation_exact_once := bool(presentation_debug.get("configured", false)) \
		and bool(presentation_debug.get("requires_outcome_presentation_acceptance", false)) \
		and int(presentation_debug.get("outcome_presentation_result_count", 0)) == 1 \
		and int(presentation_debug.get("outcome_presentation_accepted_count", 0)) == 1 \
		and int(presentation_debug.get("outcome_presentation_rejected_count", -1)) >= 0 \
		and int(presentation_debug.get("outcome_immediate_refresh_count", 0)) == 1 \
		and bool(victory_receipts.get("configured", false)) \
		and str(victory_receipts.get("last_state", "")) == "resolved" \
		and int(victory_receipts.get("outcome_receipt_count", 0)) == 1 \
		and int(victory_receipts.get("applied_outcome_count", 0)) == 1 \
		and int(victory_receipts.get("retained_outcome_receipt_count", 0)) == 1
	var verified := session.is_finished() \
		and str(session_summary.get("session_state", "")) == "finished" \
		and str(victory.get("visibility_scope", "")) == "public" \
		and str(victory.get("state", "")) == "resolved" \
		and str(victory.get("settlement_checkpoint", "")) == "post_world_settlement" \
		and str(public_outcome.get("reason_code", "")) == "public_audit_complete" \
		and str(audit_evidence.get("settlement_checkpoint", "")) == "post_world_settlement" \
		and not (audit_evidence.get("audit_roster", []) as Array).is_empty() \
		and bool(identity.get("verified", false)) \
		and str(identity.get("public_fingerprint", "")).length() == 64 \
		and counts_valid \
		and presentation_exact_once \
		and bool(lifecycle_gate.get("verified", false)) \
		and not settlement.last_public_snapshot().is_empty() \
		and int(final_log.get("public_entry_count", 0)) == 1 \
		and str(final_log.get("outcome_id", "")) == outcome_id \
		and str(final_log.get("public_fingerprint", "")).length() == 64
	return {
		"verified": verified,
		"reason_code": "terminal_exact_once_verified" if verified else "terminal_exact_once_invalid",
		"outcome_id": outcome_id,
		"outcome_identity_fingerprint": str(identity.get("public_fingerprint", "")),
		"terminal_commit_count": int(victory_port_debug.get("terminal_commit_count", 0)),
		"presentation_count": int(settlement_debug.get("present_count", 0)),
		"presentation_query_accepted_count": int(
			presentation_debug.get("outcome_presentation_accepted_count", 0)
		),
		"public_log_count": int(final_log.get("public_entry_count", 0)),
		"public_log_fingerprint": str(final_log.get("public_fingerprint", "")),
	}


static func _drain_terminal_presentation(
	tree: SceneTree,
	nodes: Dictionary,
	expected_frame: int
) -> Dictionary:
	var runtime_loop := nodes.get("runtime_loop") as RuntimeLoop
	var victory_port := nodes.get("victory_port") as RuntimeVictoryPort
	var session := nodes.get("session") as GameSessionRuntimeController
	if tree == null or runtime_loop == null or victory_port == null or session == null \
			or runtime_loop.get_tree() != tree or not runtime_loop.can_process() \
			or runtime_loop.is_processing() or expected_frame < 0 \
			or not victory_port.has_pending_terminal_outcome():
		return {
			"verified": false,
			"reason_code": "terminal_presentation_drain_precondition_invalid",
			"frame_count": 0,
			"frame_index": expected_frame,
		}
	runtime_loop.set_process(true)
	if not runtime_loop.is_processing() or not runtime_loop.can_process():
		return {
			"verified": false,
			"reason_code": "terminal_presentation_drain_owner_unavailable",
			"frame_count": 0,
			"frame_index": expected_frame,
		}
	var frame_count := 0
	var reason_code := "terminal_presentation_drain_exhausted"
	for _retry_index in range(TERMINAL_PRESENTATION_RETRY_LIMIT):
		# Wait on the authoritative loop's completed-frame signal. SceneTree's
		# process_frame signal fires before Node._process and therefore cannot
		# attest that this RuntimeLoop frame has actually finished.
		await runtime_loop.frame_advanced
		expected_frame += 1
		frame_count += 1
		var frame := runtime_loop.last_frame_receipt()
		var phase_trace: Array = frame.get("phase_trace", []) \
			if frame.get("phase_trace", []) is Array else []
		if int(frame.get("frame_index", -1)) != expected_frame \
				or not is_zero_approx(float(frame.get("world_delta", -1.0))) \
				or not _has_only_phase(phase_trace, "terminal_presentation_retry"):
			reason_code = "terminal_presentation_drain_frame_invalid"
			break
		var path := str(frame.get("path", ""))
		var stopped_reason := str(frame.get("stopped_reason", ""))
		if path == "terminal_pending" and stopped_reason == "terminal_presentation_pending" \
				and not session.is_finished():
			continue
		if path == "finished" and stopped_reason == "session_finished_after_terminal_retry" \
				and session.is_finished() and not victory_port.has_pending_terminal_outcome():
			reason_code = "terminal_presentation_drain_verified"
			break
		reason_code = "terminal_presentation_drain_path_invalid"
		break
	runtime_loop.set_process(false)
	var verified := reason_code == "terminal_presentation_drain_verified" \
		and not runtime_loop.is_processing() \
		and int(runtime_loop.debug_snapshot().get("frame_index", -1)) == expected_frame
	if reason_code == "terminal_presentation_drain_verified" and runtime_loop.is_processing():
		reason_code = "terminal_presentation_drain_lease_reacquire_failed"
	elif reason_code == "terminal_presentation_drain_verified" \
			and int(runtime_loop.debug_snapshot().get("frame_index", -1)) != expected_frame:
		reason_code = "terminal_presentation_drain_frame_changed_during_reacquire"
	return {
		"verified": verified,
		"reason_code": reason_code if not verified else "terminal_presentation_drain_verified",
		"frame_count": frame_count,
		"frame_index": expected_frame,
	}


static func _verify_terminal_quiescence(tree: SceneTree, nodes: Dictionary) -> Dictionary:
	var runtime_loop := nodes.get("runtime_loop") as RuntimeLoop
	var coordinator := nodes.get("coordinator") as GameRuntimeCoordinator
	if tree == null or runtime_loop == null or coordinator == null \
			or runtime_loop.get_tree() != tree or not runtime_loop.can_process() \
			or runtime_loop.is_processing():
		return _quiescence_rejected("terminal_quiescence_manual_lease_invalid")
	var terminal_rng := _capture_rng_checkpoint(coordinator)
	var baseline := _terminal_stable_snapshot(nodes)
	if terminal_rng.is_empty() or baseline.is_empty():
		return _quiescence_rejected("terminal_quiescence_baseline_invalid")
	var expected_frame := int(runtime_loop.debug_snapshot().get("frame_index", -1))
	if expected_frame < 0:
		return _quiescence_rejected("terminal_quiescence_frame_index_invalid")
	runtime_loop.set_process(true)
	if not runtime_loop.is_processing() or not runtime_loop.can_process():
		return _quiescence_rejected("terminal_quiescence_automatic_owner_unavailable")
	var passed_frames := 0
	var reason_code := "terminal_quiescence_verified"
	for _frame_index in range(TERMINAL_QUIESCENT_FRAME_COUNT):
		await runtime_loop.frame_advanced
		expected_frame += 1
		var frame := runtime_loop.last_frame_receipt()
		if not terminal_finished_frame_valid(frame, expected_frame):
			reason_code = "terminal_runtime_frame_not_quiescent"
			break
		var stable := _terminal_stable_snapshot(nodes)
		if stable.is_empty() or stable != baseline:
			reason_code = "terminal_state_changed_during_quiescence"
			break
		passed_frames += 1
	var quiescent_rng := _capture_rng_checkpoint(coordinator)
	var rng_evidence: Dictionary = FULL_RUN_EVIDENCE.rng_quiescence_evidence({
		"terminal": terminal_rng,
		"terminal_quiescent": quiescent_rng,
	})
	var final_stable := _terminal_stable_snapshot(nodes)
	var world_delta := int(final_stable.get("world_effective_us", -1)) \
		- int(baseline.get("world_effective_us", -1)) \
		if not final_stable.is_empty() else -1
	var verified := passed_frames == TERMINAL_QUIESCENT_FRAME_COUNT \
		and final_stable == baseline \
		and world_delta == 0 \
		and bool(rng_evidence.get("verified", false))
	if passed_frames == TERMINAL_QUIESCENT_FRAME_COUNT and not bool(rng_evidence.get("verified", false)):
		reason_code = str(rng_evidence.get("reason_id", "terminal_rng_delta_nonzero"))
	elif passed_frames == TERMINAL_QUIESCENT_FRAME_COUNT and world_delta != 0:
		reason_code = "terminal_world_delta_nonzero"
	return {
		"verified": verified,
		"reason_code": reason_code,
		"frame_count": passed_frames,
		"world_delta": world_delta,
		"rng_draw_delta": int(rng_evidence.get("draw_delta", -1)),
		"fingerprint": JSON.stringify(baseline).sha256_text() if verified else "",
	}


static func _terminal_stable_snapshot(nodes: Dictionary) -> Dictionary:
	var coordinator := nodes.get("coordinator") as GameRuntimeCoordinator
	var session := nodes.get("session") as GameSessionRuntimeController
	var victory_port := nodes.get("victory_port") as RuntimeVictoryPort
	var presentation_queries := nodes.get("presentation_queries") as TablePresentationQueryPorts
	var settlement := nodes.get("settlement") as FinalSettlementRuntimeComposition
	if coordinator == null or session == null or victory_port == null \
			or presentation_queries == null or settlement == null:
		return {}
	var exact_once := _terminal_exact_once_probe(nodes)
	if not bool(exact_once.get("verified", false)):
		return {}
	var public_projection := coordinator.presentation_public_world_projection()
	var public_world := public_projection.to_dictionary() if public_projection != null else {}
	if public_world.is_empty() or str(public_world.get("visibility_scope", "")) != "public":
		return {}
	var clock := coordinator.world_effective_clock_snapshot()
	var world_effective_us := int(clock.get("world_effective_us", -1))
	var victory := coordinator.victory_control_public_snapshot(-1)
	var session_summary := session.session_summary()
	var settlement_debug := settlement.debug_snapshot()
	var settlement_snapshot := settlement.last_public_snapshot()
	var victory_port_debug := victory_port.debug_snapshot()
	var presentation_debug := presentation_queries.debug_snapshot()
	var lifecycle_gate := _lifecycle_checkpoint_gate(
		victory_port_debug,
		presentation_debug,
		settlement_debug
	)
	var safety := coordinator.save_restore_safety_observation()
	var viewer_index := coordinator.presentation_authorized_viewer_index()
	var action_projection := coordinator.presentation_action_projection(viewer_index)
	var action_projection_data := action_projection.to_dictionary() \
		if action_projection != null else {}
	var public_log_entries := coordinator.presentation_recent_public_log_entries(90)
	var rng := _capture_rng_checkpoint(coordinator)
	if world_effective_us < 0 or rng.is_empty() or settlement_snapshot.is_empty() \
			or int(safety.get("schema_version", 0)) != 1 \
			or viewer_index < 0 or action_projection_data.is_empty() \
			or not bool(action_projection_data.get("authorized", false)) \
			or str(action_projection_data.get("visibility_scope", "")) != "viewer_private" \
			or not bool(lifecycle_gate.get("verified", false)):
		return {}
	return {
		"session_state": str(session_summary.get("session_state", "")),
		"session_summary_fingerprint": JSON.stringify(session_summary).sha256_text(),
		"session_outcome_identity_fingerprint": str(exact_once.get("outcome_identity_fingerprint", "")),
		"world_effective_us": world_effective_us,
		"public_world_fingerprint": JSON.stringify(public_world).sha256_text(),
		"action_projection_fingerprint": JSON.stringify(action_projection_data).sha256_text(),
		"victory_public_fingerprint": JSON.stringify(victory).sha256_text(),
		"outcome_id": str(exact_once.get("outcome_id", "")),
		"runtime_victory": {
			"pending_terminal": bool(victory_port_debug.get("pending_terminal", true)),
			"terminal_queue_count": int(victory_port_debug.get("terminal_queue_count", 0)),
			"terminal_retry_count": int(victory_port_debug.get("terminal_retry_count", 0)),
			"terminal_commit_count": int(victory_port_debug.get("terminal_commit_count", 0)),
			"terminal_reject_count": int(victory_port_debug.get("terminal_reject_count", 0)),
			"terminal_stale_drop_count": int(victory_port_debug.get("terminal_stale_drop_count", 0)),
			"lifecycle_checkpoint_pending": bool(victory_port_debug.get("lifecycle_checkpoint_pending", true)),
			"lifecycle_transition_kind": str(victory_port_debug.get("lifecycle_transition_kind", "missing")),
		},
		"presentation_queries": {
			"lifecycle_checkpoint_pending": bool(presentation_debug.get("lifecycle_checkpoint_pending", true)),
			"lifecycle_transition_kind": str(presentation_debug.get("lifecycle_transition_kind", "missing")),
			"session_plan_checkpoint_pending": bool(presentation_debug.get("session_plan_checkpoint_pending", true)),
			"outcome_presentation_result_count": int(presentation_debug.get("outcome_presentation_result_count", 0)),
			"outcome_presentation_accepted_count": int(presentation_debug.get("outcome_presentation_accepted_count", 0)),
			"outcome_presentation_rejected_count": int(presentation_debug.get("outcome_presentation_rejected_count", 0)),
			"outcome_immediate_refresh_count": int(presentation_debug.get("outcome_immediate_refresh_count", 0)),
			"victory_receipts_fingerprint": JSON.stringify(
				presentation_debug.get("victory_receipts", {})
			).sha256_text(),
		},
		"settlement": {
			"present_count": int(settlement_debug.get("present_count", 0)),
			"presented_outcome_count": int(settlement_debug.get("presented_outcome_count", 0)),
			"logged_outcome_count": int(settlement_debug.get("logged_outcome_count", 0)),
			"last_presented_outcome_id": str(settlement_debug.get("last_presented_outcome_id", "")),
			"last_public_snapshot_fingerprint": str(settlement_debug.get("last_public_snapshot_fingerprint", "")),
			"actual_snapshot_fingerprint": JSON.stringify(settlement_snapshot).sha256_text(),
			"action_emission_count": int(settlement_debug.get("action_emission_count", 0)),
			"lifecycle_checkpoint_pending": bool(settlement_debug.get("lifecycle_checkpoint_pending", true)),
			"lifecycle_transition_kind": str(settlement_debug.get("lifecycle_transition_kind", "missing")),
		},
		"final_public_log_fingerprint": str(exact_once.get("public_log_fingerprint", "")),
		"public_log_fingerprint": JSON.stringify(public_log_entries).sha256_text(),
		"safety_observation": safety.duplicate(true),
		"rng": rng,
	}


static func _capture_rng_checkpoint(coordinator: GameRuntimeCoordinator) -> Dictionary:
	if coordinator == null:
		return {}
	var rng := coordinator.run_rng_service()
	if rng == null:
		return {}
	var checkpoint := rng.capture_plan_checkpoint()
	if int(checkpoint.get("schema_version", 0)) != 1 \
			or int(checkpoint.get("rng_state", 0)) == 0 \
			or int(checkpoint.get("draw_count", -1)) < 0:
		return {}
	return {
		"schema_version": 1,
		"rng_state": int(checkpoint.get("rng_state", 0)),
		"draw_count": int(checkpoint.get("draw_count", 0)),
		"checkpoint_fingerprint": JSON.stringify({
			"schema_version": 1,
			"rng_state": str(checkpoint.get("rng_state", 0)),
			"draw_count": int(checkpoint.get("draw_count", 0)),
		}).sha256_text(),
	}


static func _sale_binding_from_observation(sale: Dictionary) -> Dictionary:
	var binding := {
		"public_event_count": int(sale.get("public_event_count", -1)),
		"latest_source_revision": int(sale.get("latest_source_revision", -1)),
		"public_fingerprint": str(sale.get("public_fingerprint", "")),
	}
	return binding if _sale_binding_valid(binding) else {}


static func _sale_binding_valid(binding: Dictionary) -> bool:
	return binding.keys().size() == 3 \
		and binding.has("public_event_count") \
		and binding.has("latest_source_revision") \
		and binding.has("public_fingerprint") \
		and typeof(binding.get("public_event_count")) == TYPE_INT \
		and int(binding.get("public_event_count", 0)) > 0 \
		and typeof(binding.get("latest_source_revision")) == TYPE_INT \
		and int(binding.get("latest_source_revision", -1)) >= 0 \
		and binding.get("public_fingerprint") is String \
		and str(binding.get("public_fingerprint", "")).length() == 64


static func _public_sale_receipt_observation(coordinator: GameRuntimeCoordinator) -> Dictionary:
	var rows: Array = []
	if coordinator != null:
		for entry_variant in coordinator.presentation_recent_public_log_entries(90):
			if not (entry_variant is Dictionary):
				continue
			var entry := entry_variant as Dictionary
			if str(entry.get("event_kind", "")) != CommodityFlowPostCommitPublicReceipt.EVENT_KIND:
				continue
			var public_values: Dictionary = entry.get("public_values", {}) \
				if entry.get("public_values", {}) is Dictionary else {}
			if str(public_values.get("result", "")) != "committed" \
					or str(public_values.get("public_status", "")) != "sale_receipt":
				continue
			rows.append({
				"source_revision": maxi(0, int(entry.get("source_revision", 0))),
				"world_time": maxf(0.0, float(entry.get("world_time", 0.0))),
				"value_band": str(public_values.get("value_band", "")),
			})
	var first_world_seconds := -1.0
	var latest_source_revision := 0
	for row_variant in rows:
		var row := row_variant as Dictionary
		var world_time := float(row.get("world_time", 0.0))
		first_world_seconds = world_time if first_world_seconds < 0.0 else minf(first_world_seconds, world_time)
		latest_source_revision = maxi(latest_source_revision, int(row.get("source_revision", 0)))
	return {
		"observed": not rows.is_empty(),
		"public_event_count": rows.size(),
		"first_world_seconds": first_world_seconds,
		"latest_source_revision": latest_source_revision,
		"public_fingerprint": JSON.stringify(rows).sha256_text() if not rows.is_empty() else "",
	}


static func _public_final_settlement_log_observation(
	coordinator: GameRuntimeCoordinator,
	expected_outcome_id := ""
) -> Dictionary:
	var rows: Array = []
	if coordinator != null:
		for entry_variant in coordinator.presentation_recent_public_log_entries(90):
			if not (entry_variant is Dictionary):
				continue
			var entry := entry_variant as Dictionary
			var public_values: Dictionary = entry.get("public_values", {}) \
				if entry.get("public_values", {}) is Dictionary else {}
			var outcome_id := str(public_values.get("outcome_id", "")).strip_edges()
			var winner_indices: Array = public_values.get("winner_player_indices", []) \
				if public_values.get("winner_player_indices", []) is Array else []
			if str(entry.get("event_kind", "")) != "final_settlement" \
					or str(entry.get("localization_key", "")) != "victory.public.final_settlement" \
					or str(public_values.get("public_status", "")) != "settled" \
					or str(public_values.get("reason_code", "")) != "public_audit_complete" \
					or outcome_id.is_empty() or winner_indices.is_empty() \
					or not expected_outcome_id.is_empty() and outcome_id != expected_outcome_id:
				continue
			rows.append({
				"outcome_id": outcome_id,
				"source_revision": maxi(0, int(entry.get("source_revision", 0))),
				"winner_count": winner_indices.size(),
			})
	return {
		"public_entry_count": rows.size(),
		"outcome_id": str((rows[0] as Dictionary).get("outcome_id", "")) if rows.size() == 1 else "",
		"public_fingerprint": JSON.stringify(rows).sha256_text() if not rows.is_empty() else "",
	}


static func _lease_rejected(reason_code: String) -> Dictionary:
	return {"accepted": false, "reason_code": reason_code, "frame_index": -1}


static func _gate_rejected(reason_code: String) -> Dictionary:
	return {"accepted": false, "reason_code": reason_code, "frame_index": -1}


static func _quiescence_rejected(reason_code: String) -> Dictionary:
	return {
		"verified": false,
		"reason_code": reason_code,
		"frame_count": 0,
		"world_delta": -1,
		"rng_draw_delta": -1,
		"fingerprint": "",
	}


static func _finish_failure(
	runtime_loop: RuntimeLoop,
	reason_code: String,
	state_sequence: Array = [],
	details: Dictionary = {}
) -> Dictionary:
	if runtime_loop != null and not runtime_loop.is_processing():
		runtime_loop.set_process(true)
	var result := {
		"settled": false,
		"failure_code": reason_code,
		"victory_state_sequence": state_sequence.duplicate(),
		"settlement_count": 0,
		"presentation_count": 0,
		"public_log_count": 0,
		"quiet_frames": int(details.get("quiet_frames", 0)),
		"world_delta": int(details.get("world_delta", -1)),
		"rng_delta": int(details.get("rng_delta", -1)),
		"active_steps": int(details.get("active_steps", 0)),
		"attempted_steps": int(details.get("attempted_steps", 0)),
		"terminal_zero_world_steps": int(details.get("terminal_zero_world_steps", 0)),
		"lifecycle_settle_frames": int(details.get("lifecycle_settle_frames", 0)),
		"outcome_id": "",
		"outcome_identity_fingerprint": "",
		"timer_evidence": {},
		"quiescence_fingerprint": "",
	}
	return result
