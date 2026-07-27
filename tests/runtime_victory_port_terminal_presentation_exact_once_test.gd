extends SceneTree


class FakeVictoryController extends VictoryControlRuntimeController:
	var queued_results: Array[Dictionary] = []
	var public_value: Dictionary = {}
	var advance_count := 0

	func advance_world_effective(_delta_seconds: float, _world_snapshot: Dictionary) -> Dictionary:
		advance_count += 1
		if queued_results.is_empty():
			return {"valid": true, "public_snapshot": public_value.duplicate(true), "outcome_receipt": {}}
		return queued_results.pop_front().duplicate(true)

	func public_snapshot(_viewer_index := -1) -> Dictionary:
		return public_value.duplicate(true)


class FakeWorldBridge extends VictoryControlWorldBridge:
	var capture_count := 0

	func capture_world_snapshot(_clock_pause: Dictionary = {}, settlement_checkpoint := "read_only") -> Dictionary:
		capture_count += 1
		return {"settlement_checkpoint": settlement_checkpoint}


class FakeSessionController extends GameSessionRuntimeController:
	var finished := false
	var finish_count := 0
	var last_outcome: Dictionary = {}
	var failed_finish_attempts_remaining := 0
	var context_id := "session-old"
	var context_revision := 1

	func finish_session(result_summary: Dictionary = {}) -> void:
		finish_count += 1
		last_outcome = result_summary.duplicate(true)
		if failed_finish_attempts_remaining > 0:
			failed_finish_attempts_remaining -= 1
			return
		finished = true

	func is_finished() -> bool:
		return finished

	func session_summary() -> Dictionary:
		return {
			"session_state": "running",
			"session_id": context_id,
			"scenario_id": "terminal-lifecycle-fixture",
			"ruleset_id": "v0.6",
			"seed": context_revision,
			"setup": {},
			"save_state": "dirty",
			"dirty": true,
			"outcome_receipt": {},
		}

	func session_start_revision() -> int:
		return context_revision

	func change_authorization_context(next_context_id: String, reason_id: String) -> void:
		context_id = next_context_id
		context_revision += 1
		authorization_context_changed.emit(reason_id)

	func restore_authorization_context(previous_context_id: String, previous_revision: int, reason_id: String) -> void:
		context_id = previous_context_id
		context_revision = previous_revision
		authorization_context_changed.emit(reason_id)


class FakeAiController extends AiRuntimeController:
	var finalize_count := 0
	var last_outcome: Dictionary = {}

	func finalize_victory_outcome_learning(receipt: Dictionary) -> int:
		finalize_count += 1
		last_outcome = receipt.duplicate(true)
		return 1


class FakePresentationQueries extends TablePresentationQueryPorts:
	var advance_count := 0
	var outcome_count := 0
	var last_advance: Dictionary = {}
	var last_outcome_snapshot: Dictionary = {}
	var failed_outcome_attempts_remaining := 0
	var successful_outcome_receipt: VictoryPresentationStateChangeReceipt

	func capture_victory_advance(result: Dictionary) -> VictoryPresentationStateChangeReceipt:
		advance_count += 1
		last_advance = result.duplicate(true)
		return null

	func capture_victory_outcome(public_snapshot: Dictionary) -> VictoryPresentationStateChangeReceipt:
		outcome_count += 1
		last_outcome_snapshot = public_snapshot.duplicate(true)
		if failed_outcome_attempts_remaining > 0:
			failed_outcome_attempts_remaining -= 1
			return null
		if successful_outcome_receipt != null:
			successful_outcome_receipt.public_snapshot = VictoryPresentationStateChangeReceipt.project_public_snapshot(
				public_snapshot
			)
		return successful_outcome_receipt


var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node.new()
	root.add_child(host)
	var victory := FakeVictoryController.new()
	var world := FakeWorldBridge.new()
	var session := FakeSessionController.new()
	var ai := FakeAiController.new()
	var presentation := FakePresentationQueries.new()
	presentation.successful_outcome_receipt = _terminal_presentation_receipt()
	var port := RuntimeVictoryPort.new()
	for child in [victory, world, session, ai, presentation, port]:
		host.add_child(child)
	port.bind_dependencies(victory, world, session, ai, presentation)
	_expect(port.is_ready(), "runtime Victory port accepts the existing typed owners")

	victory.queued_results.append(_advance_result("qualification"))
	victory.queued_results.append(_advance_result("audit"))
	port.advance_victory_control(1.0)
	port.advance_victory_control(1.0)
	_expect(presentation.advance_count == 2, "nonterminal state changes keep using advance presentation receipts")
	_expect(presentation.outcome_count == 0 and session.finish_count == 0 and ai.finalize_count == 0, "nonterminal advances cannot finish or present an outcome")

	var outcome := _outcome_receipt()
	var terminal_snapshot := _terminal_public_snapshot(outcome)
	victory.public_value = terminal_snapshot.duplicate(true)
	presentation.failed_outcome_attempts_remaining = 2
	victory.queued_results.append({
		"valid": true,
		"state": "resolved",
		"public_snapshot": terminal_snapshot.duplicate(true),
		"outcome_receipt": outcome.duplicate(true),
	})
	var terminal_result := port.advance_victory_control(1.0)
	_expect(terminal_result.get("outcome_receipt", {}) == outcome, "terminal result preserves the authoritative Victory outcome")
	_expect(presentation.advance_count == 2, "resolved outcome skips the duplicate state-change presentation path")
	_expect(session.finish_count == 0 and ai.finalize_count == 0, "terminal commit waits when the public presentation receipt cannot be constructed")
	_expect(presentation.outcome_count == 1 and presentation.last_outcome_snapshot == terminal_snapshot, "failed terminal presentation attempts use only the public outcome snapshot")
	_expect(port.has_pending_terminal_outcome(), "a rejected terminal presentation leaves one typed terminal commit pending")

	var phases := RuntimePhaseCoordinator.new()
	phases._victory_port = port
	var world_capture_before_retry := world.capture_count
	var victory_advance_before_retry := victory.advance_count
	var rejected_retry := phases.advance_frame(30.0)
	_expect(str(rejected_retry.get("path", "")) == "terminal_pending" and is_zero_approx(float(rejected_retry.get("world_delta", -1.0))), "a rejected terminal retry freezes the next frame before world time")
	_expect(world.capture_count == world_capture_before_retry and victory.advance_count == victory_advance_before_retry, "terminal retry does not re-enter world capture or Victory advancement")
	var accepted_retry := phases.advance_frame(30.0)
	_expect(str(accepted_retry.get("path", "")) == "finished" and is_zero_approx(float(accepted_retry.get("world_delta", -1.0))), "an accepted terminal retry finishes without a gameplay frame")
	_expect(session.finish_count == 1 and session.last_outcome == outcome, "a retried terminal receipt finishes the session exactly once")
	_expect(ai.finalize_count == 1 and ai.last_outcome == outcome, "a retried terminal receipt finalizes AI learning exactly once")
	_expect(presentation.outcome_count == 3, "terminal presentation retries only through the zero-world terminal gate")
	phases.free()

	victory.queued_results.append({
		"valid": true,
		"state": "resolved",
		"public_snapshot": terminal_snapshot.duplicate(true),
		"outcome_receipt": outcome.duplicate(true),
	})
	port.advance_victory_control(1.0)
	_expect(session.finish_count == 1 and ai.finalize_count == 1, "replayed terminal advances cannot repeat session or AI commits")
	_expect(presentation.advance_count == 2 and presentation.outcome_count == 3, "replayed terminal advances cannot emit either presentation path again")

	victory.queued_results.append({
		"valid": true,
		"state": "resolved",
		"public_snapshot": {"state": "resolved", "visibility_scope": "public"},
		"outcome_receipt": "forged_non_dictionary_outcome",
	})
	port.advance_victory_control(1.0)
	_expect(session.finish_count == 1 and ai.finalize_count == 1, "malformed resolved outcome fails closed before terminal commits")
	_expect(presentation.advance_count == 2 and presentation.outcome_count == 3, "malformed resolved outcome cannot fall back to a state-change presentation")
	_expect(world.capture_count == 5 and victory.advance_count == 5, "ordinary advancement still uses the authoritative world and Victory owners exactly once per non-retry call")

	_test_outcome_identity_mismatch()
	_test_finish_retry_after_presentation_commit()
	_test_pending_public_snapshot_stale_rejection()
	_test_pending_reset()
	await _test_new_and_loaded_session_drop_stale_pending()
	_test_failed_replacement_rollback_restores_pending()
	_test_failed_load_rollback_restores_pending()
	_test_formal_lifecycle_transaction_contract()
	_test_special_outcome_route_source()
	_test_receipt_reason_boundary()
	host.queue_free()
	await process_frame
	_finish()


func _test_outcome_identity_mismatch() -> void:
	var victory := FakeVictoryController.new()
	var world := FakeWorldBridge.new()
	var session := FakeSessionController.new()
	var ai := FakeAiController.new()
	var presentation := FakePresentationQueries.new()
	presentation.successful_outcome_receipt = _terminal_presentation_receipt()
	var port := RuntimeVictoryPort.new()
	for node in [victory, world, session, ai, presentation, port]:
		root.add_child(node)
	port.bind_dependencies(victory, world, session, ai, presentation)
	var authoritative := _outcome_receipt()
	var mismatched := authoritative.duplicate(true)
	mismatched["outcome_id"] = "victory.v06.mismatched"
	var public_snapshot := _terminal_public_snapshot(mismatched)
	victory.public_value = public_snapshot.duplicate(true)
	victory.queued_results.append({
		"valid": true,
		"state": "resolved",
		"public_snapshot": public_snapshot.duplicate(true),
		"outcome_receipt": authoritative.duplicate(true),
	})
	var result := port.advance_victory_control(1.0)
	var commit: Dictionary = result.get("terminal_commit", {}) if result.get("terminal_commit", {}) is Dictionary else {}
	_expect(not bool(commit.get("accepted", true)) and str(commit.get("reason_id", "")) == "terminal_outcome_identity_mismatch", "public presentation outcome must match the authoritative session outcome")
	_expect(not port.has_pending_terminal_outcome() and session.finish_count == 0 and presentation.outcome_count == 0, "identity mismatch fails before queue, presentation, or session finish")
	for node in [port, presentation, ai, session, world, victory]:
		node.free()


func _test_finish_retry_after_presentation_commit() -> void:
	var victory := FakeVictoryController.new()
	var world := FakeWorldBridge.new()
	var session := FakeSessionController.new()
	session.failed_finish_attempts_remaining = 1
	var ai := FakeAiController.new()
	var presentation := FakePresentationQueries.new()
	presentation.successful_outcome_receipt = _terminal_presentation_receipt()
	var port := RuntimeVictoryPort.new()
	for node in [victory, world, session, ai, presentation, port]:
		root.add_child(node)
	port.bind_dependencies(victory, world, session, ai, presentation)
	var outcome := _outcome_receipt()
	var public_snapshot := _terminal_public_snapshot(outcome)
	victory.public_value = public_snapshot.duplicate(true)
	var first := port.commit_terminal_outcome(outcome, public_snapshot)
	_expect(not bool(first.get("accepted", true)) and str(first.get("reason_id", "")) == "terminal_session_finish_rejected", "a fail-once Session finish leaves the terminal transaction pending")
	_expect(presentation.outcome_count == 1 and session.finish_count == 1 and ai.finalize_count == 0, "presentation commits exactly once before the failed Session finish")
	var pending_debug := port.debug_snapshot()
	_expect(bool(pending_debug.get("pending_presentation_committed", false)) and str(pending_debug.get("pending_presentation_receipt_fingerprint", "")).length() == 64, "the pending transaction attests its committed presentation stage")
	var retry := port.retry_pending_terminal_outcome()
	_expect(bool(retry.get("accepted", false)) and session.finish_count == 2 and session.is_finished(), "the zero-world retry can finish Session after a transient rejection")
	_expect(presentation.outcome_count == 1 and ai.finalize_count == 1, "the Session retry does not replay presentation and finalizes AI once")
	for node in [port, presentation, ai, session, world, victory]:
		node.free()


func _test_pending_public_snapshot_stale_rejection() -> void:
	var victory := FakeVictoryController.new()
	var world := FakeWorldBridge.new()
	var session := FakeSessionController.new()
	var presentation := FakePresentationQueries.new()
	presentation.failed_outcome_attempts_remaining = 1
	presentation.successful_outcome_receipt = _terminal_presentation_receipt()
	var port := RuntimeVictoryPort.new()
	for node in [victory, world, session, presentation, port]:
		root.add_child(node)
	port.bind_dependencies(victory, world, session, null, presentation)
	var outcome := _outcome_receipt()
	var public_snapshot := _terminal_public_snapshot(outcome)
	victory.public_value = public_snapshot.duplicate(true)
	port.commit_terminal_outcome(outcome, public_snapshot)
	_expect(port.has_pending_terminal_outcome() and presentation.outcome_count == 1, "fixture queues one exact public settlement after a presentation rejection")
	var mutated_public := public_snapshot.duplicate(true)
	var mutated_outcome: Dictionary = (mutated_public.get("outcome_receipt", {}) as Dictionary).duplicate(true)
	var mutated_evidence: Dictionary = (mutated_outcome.get("audit_evidence", {}) as Dictionary).duplicate(true)
	mutated_evidence["settlement_checkpoint"] = "forged_checkpoint"
	mutated_outcome["audit_evidence"] = mutated_evidence
	mutated_public["outcome_receipt"] = mutated_outcome
	victory.public_value = mutated_public
	var retry := port.retry_pending_terminal_outcome()
	_expect(not bool(retry.get("accepted", true)) and str(retry.get("reason_id", "")) == "terminal_outcome_became_stale", "same-ID public settlement payload mutation fails the retry binding")
	_expect(session.finish_count == 0 and presentation.outcome_count == 1 and not port.has_pending_terminal_outcome(), "stale public settlement cannot present or finish Session and is removed from the retry gate")
	var world_captures_before_recovery := world.capture_count
	victory.queued_results.append(_advance_result("qualification"))
	var recovered := port.advance_victory_control(1.0)
	_expect(str(recovered.get("state", "")) == "qualification" and world.capture_count == world_captures_before_recovery + 1, "a stale rejection consumes one zero-world retry but cannot wedge later Victory advancement")
	for node in [port, presentation, session, world, victory]:
		node.free()


func _test_pending_reset() -> void:
	var victory := FakeVictoryController.new()
	var world := FakeWorldBridge.new()
	var session := FakeSessionController.new()
	var presentation := FakePresentationQueries.new()
	presentation.failed_outcome_attempts_remaining = 1
	presentation.successful_outcome_receipt = _terminal_presentation_receipt()
	var port := RuntimeVictoryPort.new()
	for node in [victory, world, session, presentation, port]:
		root.add_child(node)
	port.bind_dependencies(victory, world, session, null, presentation)
	var outcome := _outcome_receipt()
	var public_snapshot := _terminal_public_snapshot(outcome)
	victory.public_value = public_snapshot.duplicate(true)
	port.commit_terminal_outcome(outcome, public_snapshot)
	_expect(port.has_pending_terminal_outcome(), "fixture creates a pending terminal commit")
	session.authorization_context_changed.emit("session_began")
	_expect(not port.has_pending_terminal_outcome() and int(port.debug_snapshot().get("terminal_queue_count", -1)) == 0, "new-session authorization reset clears pending terminal state")
	for node in [port, presentation, session, world, victory]:
		node.free()


func _test_new_and_loaded_session_drop_stale_pending() -> void:
	var fixture := _pending_terminal_fixture()
	var port := fixture.get("port") as RuntimeVictoryPort
	var session := fixture.get("session") as FakeSessionController
	var victory := fixture.get("victory") as FakeVictoryController
	var world := fixture.get("world") as FakeWorldBridge
	_expect(port.has_pending_terminal_outcome(), "new-session fixture starts with an old authoritative terminal pending")
	session.change_authorization_context("session-new", "session_plan_applied")
	_expect(not port.has_pending_terminal_outcome() and bool(port.debug_snapshot().get("lifecycle_checkpoint_pending", false)), "formal replacement removes old pending from the active runtime gate while rollback remains possible")
	await process_frame
	_expect(not bool(port.debug_snapshot().get("lifecycle_checkpoint_pending", true)), "successful replacement retires its rollback-only terminal checkpoint on the next idle turn")
	var captures_before_new_session := world.capture_count
	victory.queued_results.append(_advance_result("qualification"))
	var new_session_advance := port.advance_victory_control(1.0)
	_expect(str(new_session_advance.get("state", "")) == "qualification" and world.capture_count == captures_before_new_session + 1, "old pending cannot force the replacement session into terminal_pending")

	var outcome := _outcome_receipt("victory.v06.loaded-predecessor")
	var terminal_snapshot := _terminal_public_snapshot(outcome)
	victory.public_value = terminal_snapshot.duplicate(true)
	(fixture.get("presentation") as FakePresentationQueries).failed_outcome_attempts_remaining = 1
	port.commit_terminal_outcome(outcome, terminal_snapshot)
	_expect(port.has_pending_terminal_outcome(), "load fixture creates a terminal pending in the replaced session")
	session.change_authorization_context("session-loaded", "session_save_applied")
	_expect(not port.has_pending_terminal_outcome(), "authoritative save application immediately removes predecessor pending from the loaded session")
	session.authorization_context_changed.emit("session_load_completed")
	await process_frame
	_expect(not port.has_pending_terminal_outcome() and not bool(port.debug_snapshot().get("lifecycle_checkpoint_pending", true)), "completed load cannot inherit or later resurrect predecessor terminal state")
	_free_terminal_fixture(fixture)


func _test_failed_replacement_rollback_restores_pending() -> void:
	var fixture := _pending_terminal_fixture(true)
	var port := fixture.get("port") as RuntimeVictoryPort
	var session := fixture.get("session") as FakeSessionController
	var presentation := fixture.get("presentation") as FakePresentationQueries
	var old_debug := port.debug_snapshot()
	var old_context_id := session.context_id
	var old_context_revision := session.context_revision
	session.change_authorization_context("session-replacement", "session_plan_applied")
	_expect(not port.has_pending_terminal_outcome(), "replacement apply quarantines old pending before later commit-only stages")
	session.restore_authorization_context(old_context_id, old_context_revision, "session_checkpoint_rolled_back")
	var restored_debug := port.debug_snapshot()
	_expect(port.has_pending_terminal_outcome() and str(restored_debug.get("pending_binding_fingerprint", "")) == str(old_debug.get("pending_binding_fingerprint", "")), "failed replacement rollback restores the exact old-session terminal binding")
	_expect(bool(restored_debug.get("pending_presentation_committed", false)) and str(restored_debug.get("pending_presentation_receipt_fingerprint", "")) == str(old_debug.get("pending_presentation_receipt_fingerprint", "")), "failed replacement rollback preserves the accepted presentation stage and its exact receipt attestation")
	_expect(int(restored_debug.get("terminal_queue_count", -1)) == int(old_debug.get("terminal_queue_count", -2)) and int(restored_debug.get("terminal_retry_count", -1)) == int(old_debug.get("terminal_retry_count", -2)), "failed replacement rollback restores old exact-once counters instead of resetting them")
	_expect(int(restored_debug.get("lifecycle_restore_count", 0)) == 1 and not bool(restored_debug.get("lifecycle_checkpoint_pending", true)), "rollback consumes its lifecycle checkpoint exactly once")
	session.authorization_context_changed.emit("session_checkpoint_rolled_back")
	_expect(port.has_pending_terminal_outcome() and int(port.debug_snapshot().get("lifecycle_restore_count", 0)) == 1, "duplicate replacement rollback is idempotent and cannot destroy restored old-session state")
	var retry := port.retry_pending_terminal_outcome()
	_expect(bool(retry.get("accepted", false)) and session.finish_count == 2 and presentation.outcome_count == 1, "restored old-session pending resumes Session finish without replaying its committed presentation")
	_free_terminal_fixture(fixture)


func _test_failed_load_rollback_restores_pending() -> void:
	var fixture := _pending_terminal_fixture()
	var port := fixture.get("port") as RuntimeVictoryPort
	var session := fixture.get("session") as FakeSessionController
	var old_binding := str(port.debug_snapshot().get("pending_binding_fingerprint", ""))
	var old_context_id := session.context_id
	var old_context_revision := session.context_revision
	session.change_authorization_context("session-loaded", "session_save_applied")
	_expect(not port.has_pending_terminal_outcome(), "save-owner apply quarantines old pending while registry post-apply validation is in flight")
	session.restore_authorization_context(old_context_id, old_context_revision, "session_save_applied")
	_expect(port.has_pending_terminal_outcome() and str(port.debug_snapshot().get("pending_binding_fingerprint", "")) == old_binding, "reverse-order save rollback restores the exact predecessor pending on the second owner apply event")
	_free_terminal_fixture(fixture)


func _pending_terminal_fixture(presentation_committed := false) -> Dictionary:
	var victory := FakeVictoryController.new()
	var world := FakeWorldBridge.new()
	var session := FakeSessionController.new()
	var presentation := FakePresentationQueries.new()
	if presentation_committed:
		session.failed_finish_attempts_remaining = 1
	else:
		presentation.failed_outcome_attempts_remaining = 1
	presentation.successful_outcome_receipt = _terminal_presentation_receipt()
	var port := RuntimeVictoryPort.new()
	for node in [victory, world, session, presentation, port]:
		root.add_child(node)
	port.bind_dependencies(victory, world, session, null, presentation)
	var outcome := _outcome_receipt()
	var public_snapshot := _terminal_public_snapshot(outcome)
	victory.public_value = public_snapshot.duplicate(true)
	port.commit_terminal_outcome(outcome, public_snapshot)
	return {
		"victory": victory,
		"world": world,
		"session": session,
		"presentation": presentation,
		"port": port,
	}


func _free_terminal_fixture(fixture: Dictionary) -> void:
	for key in ["port", "presentation", "session", "world", "victory"]:
		var node := fixture.get(key) as Node
		if is_instance_valid(node):
			node.free()


func _test_formal_lifecycle_transaction_contract() -> void:
	var session_source := FileAccess.get_file_as_string("res://scripts/runtime/game_session_runtime_controller.gd")
	var transaction_source := FileAccess.get_file_as_string("res://scripts/runtime/session_start_transaction_coordinator.gd")
	var registry_source := FileAccess.get_file_as_string("res://scripts/runtime/v06_save_owner_registry.gd")
	var registry_scene := FileAccess.get_file_as_string("res://scenes/runtime/V06SaveOwnerRegistry.tscn")
	_expect(session_source.contains('_emit_authorization_context_changed("session_plan_applied")') and session_source.contains('_emit_authorization_context_changed("session_checkpoint_rolled_back")') and session_source.contains('_emit_authorization_context_changed("session_save_applied")') and session_source.contains('_emit_authorization_context_changed("session_load_completed")'), "terminal lifecycle constants match every formal GameSession replacement and load event")
	var session_apply_at := transaction_source.find("var session_apply := _game_session().apply_new_session_plan")
	var rng_commit_at := transaction_source.find("var rng_commit := _run_rng().commit_plan_state")
	_expect(session_apply_at >= 0 and rng_commit_at > session_apply_at, "session_plan_applied occurs before commit-only RNG and side-effect stages that may still force rollback")
	var rollback_start := transaction_source.find("func _rollback_failure")
	var rollback_end := transaction_source.find("\nfunc ", rollback_start + 1)
	var rollback_body := transaction_source.substr(rollback_start, rollback_end - rollback_start)
	var rollback_session_at := rollback_body.find("rollback_new_session_checkpoint")
	var rollback_runtime_at := rollback_body.find("_runtime_coordinator().rollback_new_session_checkpoint")
	_expect(rollback_session_at >= 0 and rollback_runtime_at > rollback_session_at, "failed replacement restores GameSession and emits its rollback event before restoring runtime owners")
	var session_binding_at := registry_scene.find('section_id = "session"')
	var session_binding := registry_scene.substr(session_binding_at, 600) if session_binding_at >= 0 else ""
	_expect(session_binding_at >= 0 and session_binding.contains('apply_method = "apply_save_data"') and session_binding.contains('rollback_method = "apply_save_data"') and registry_source.contains("\"victory_control\",\n\t\"session\",") and registry_source.contains("range(applied_sections.size() - 1, -1, -1)"), "save registry applies Session last and reverse rollback reuses the same authoritative session_save_applied lifecycle event")


func _test_special_outcome_route_source() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	var apply_start := source.find("func _apply_victory_outcome_receipt")
	var apply_end := source.find("\nfunc ", apply_start + 1)
	var apply_body := source.substr(apply_start, apply_end - apply_start)
	_expect(apply_start >= 0 and apply_body.contains("commit_terminal_outcome"), "special last-survivor and planet-destroyed outcomes use the shared typed terminal commit")
	_expect(not apply_body.contains("session.finish_session") and not apply_body.contains("capture_victory_outcome"), "special outcomes cannot bypass presentation acceptance or finish directly")


func _test_receipt_reason_boundary() -> void:
	var receipt := VictoryPresentationStateChangeReceipt.new()
	receipt.receipt_id = "victory-outcome-fixture"
	receipt.revision = 3
	receipt.change_kind = &"outcome"
	receipt.previous_state = "audit"
	receipt.state = "resolved"
	receipt.world_time = 12.5
	receipt.public_snapshot = VictoryPresentationStateChangeReceipt.project_public_snapshot(
		_terminal_public_snapshot(_outcome_receipt())
	)
	receipt.participant_names = VictoryPresentationStateChangeReceipt.project_participant_names({"0": "Test Player"})
	receipt.public_map_facts = VictoryPresentationStateChangeReceipt.project_public_map_facts({"active_city_count": 3})
	receipt.immediate_refresh_mask = [&"live", &"full"]
	_expect(receipt.is_valid(), "terminal presentation receipt remains valid public pure data")
	_expect(str(receipt.to_dictionary().get("change_kind", "")) == "outcome", "change_kind remains typed event metadata")
	var context := receipt.public_context()
	var context_snapshot: Dictionary = context.get("victory_public_snapshot", {}) if context.get("victory_public_snapshot", {}) is Dictionary else {}
	var context_outcome: Dictionary = context_snapshot.get("outcome_receipt", {}) if context_snapshot.get("outcome_receipt", {}) is Dictionary else {}
	_expect(not context.has("reason"), "technical change_kind is not exposed as a player display reason")
	_expect(str(context_outcome.get("reason_code", "")) == "public_audit_complete", "public settlement context retains the authoritative outcome reason")
	context_outcome["reason_code"] = "forged_reason"
	_expect(str((receipt.public_snapshot.get("outcome_receipt", {}) as Dictionary).get("reason_code", "")) == "public_audit_complete", "detached public context cannot mutate the receipt outcome reason")
	var special_log := PublicLogReceipt.create(
		"final-settlement-special",
		&"final_settlement",
		&"victory.public.final_settlement",
		{
			"outcome_id": "victory.v06.special",
			"public_status": "settled",
			"reason_code": "last_survivor",
			"winner_player_indices": [0],
		},
		1,
		1.0
	)
	_expect(special_log.is_valid(), "closed special Victory reasons share the structured final-settlement receipt")
	var forged_log := PublicLogReceipt.create(
		"final-settlement-forged",
		&"final_settlement",
		&"victory.public.final_settlement",
		{
			"outcome_id": "victory.v06.forged",
			"public_status": "settled",
			"reason_code": "caller_controlled_reason",
			"winner_player_indices": [0],
		},
		1,
		1.0
	)
	_expect(not forged_log.is_valid(), "unregistered terminal reason codes fail closed")


func _terminal_presentation_receipt() -> VictoryPresentationStateChangeReceipt:
	var receipt := VictoryPresentationStateChangeReceipt.new()
	receipt.receipt_id = "victory-outcome-port-fixture"
	receipt.revision = 1
	receipt.change_kind = &"outcome"
	receipt.previous_state = "audit"
	receipt.state = "resolved"
	receipt.world_time = 12.5
	receipt.public_snapshot = VictoryPresentationStateChangeReceipt.project_public_snapshot(
		_terminal_public_snapshot(_outcome_receipt())
	)
	receipt.participant_names = {"0": "Test Player"}
	receipt.public_map_facts = {"active_city_count": 3}
	receipt.immediate_refresh_mask = [&"live", &"full"]
	return receipt


func _advance_result(state: String) -> Dictionary:
	return {
		"valid": true,
		"state": state,
		"public_snapshot": {"state": state, "outcome_receipt": {}, "visibility_scope": "public"},
		"outcome_receipt": {},
	}


func _terminal_public_snapshot(outcome: Dictionary) -> Dictionary:
	return {
		"controller_id": "victory_control_runtime_v06",
		"ruleset_id": "v0.6",
		"state": "resolved",
		"victory_rule": {
			"surviving_region_count": 4,
			"coverage_basis_points": 4000,
			"required_region_count": 2,
			"gdp_per_required_region_per_minute": 36,
			"required_top_k_gdp_per_minute": 72,
			"required_top_k_gdp_per_minute_cents": 7200,
			"ordinary_victory_paused": false,
		},
		"qualification_remaining_seconds": 0.0,
		"audit_remaining_seconds": 0.0,
		"audit_roster": [0],
		"audit_entries": [],
		"paused": false,
		"pause_reasons": [],
		"settlement_checkpoint": "post_world_settlement",
		"outcome_receipt": outcome.duplicate(true),
		"visibility_scope": "public",
	}


func _outcome_receipt(outcome_id: String = "victory.v06.fixture.1") -> Dictionary:
	return {
		"outcome_id": outcome_id,
		"schema_version": "victory_outcome_v1",
		"ruleset_id": "v0.6",
		"reason_code": "public_audit_complete",
		"winner_player_indices": [0],
		"co_victory": false,
		"comparison_order": ["top_k_gdp_per_minute_cents", "controlled_region_count", "cash_ledger_cents"],
		"rankings": [{
			"player_index": 0,
			"top_k_gdp_per_minute_cents": 7200,
			"top_k_gdp_per_minute": 72,
			"top_n_gdp_per_minute": 72,
			"controlled_region_count": 2,
			"winner": true,
		}],
		"audit_evidence": {
			"victory_rule": {"required_region_count": 2},
			"audit_roster": [0],
			"settlement_checkpoint": "post_world_settlement",
		},
		"visibility_scope": "public",
	}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("runtime_victory_port_terminal_presentation_exact_once_test: %s %d/%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks - _failures.size(), _checks])
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
	quit(_failures.size())
