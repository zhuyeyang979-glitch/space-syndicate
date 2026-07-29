extends SceneTree

const Evidence := preload("res://scripts/tools/cold_restore_terminal_evidence.gd")
const HELPER_PATH := "res://scripts/tools/cold_restore_terminal_evidence.gd"
const DRIVER_PATH := "res://scripts/tools/cold_restore_vertical_slice_driver.gd"

const FORBIDDEN_AUTHORITY_TOKENS := [
	".world_session_state(",
	"resolve_victory_outcome(",
	"advance_victory_control(",
	"resolve_special_outcome(",
	"commit_terminal_outcome(",
	"retry_pending_terminal_outcome(",
	"present_victory_receipt(",
	"finish_session(",
	"advance_runtime_world_time(",
	"advance_commodity_flow(",
	"mark_session_dirty(",
	".players =",
	"last_survivor",
]

var _checks := 0
var _failures: Array[String] = []
var _integration_checks := 0
var _integration_failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var contract := Evidence.contract_snapshot()
	_expect(int(contract.get("schema_version", 0)) == 1, "helper contract is versioned")
	_expect(str(contract.get("contract_id", "")) == "cold_restore_terminal_evidence_v1", "helper contract has stable identity")
	_expect(bool(contract.get("qa_only", false)), "helper is explicitly QA-only")
	_expect(str(contract.get("runtime_entry", "")) == "FullRunAuthoritativeRuntimeStepper.advance_bounded", "the bounded production RuntimeLoop lease is the sole progression entry")
	_expect(is_equal_approx(float(contract.get("step_seconds", 0.0)), 1.0), "terminal evidence uses one-second bounded steps")
	_expect((contract.get("expected_victory_states", []) as Array) == ["idle", "qualification", "audit", "resolved"], "natural Victory sequence is closed and ordered")
	_expect(int(contract.get("generation_two_lifecycle_settle_frame_limit", 0)) == 2, "lifecycle checkpoint settlement is bounded")
	_expect(int(contract.get("terminal_presentation_retry_limit", 0)) == 8, "terminal presentation drain is bounded")
	_expect(int(contract.get("terminal_quiescent_frame_count", 0)) == 8, "terminal proof requires eight finished frames")
	_expect(bool(contract.get("generation_two_sale_binding_supported", false)), "helper exposes a public sale binding capture")
	_expect(bool(contract.get("generation_two_sale_binding_required", false)), "generation-two gate requires the pre-save sale binding")
	_expect(bool(contract.get("requires_first_active_qualification", false)), "first active frame must naturally enter qualification")
	_expect(not bool(contract.get("owns_eligibility_setup", true)), "helper never fabricates victory eligibility")
	_expect(str(contract.get("automatic_frame_observation", "")) == "RuntimeLoop.frame_advanced", "automatic frames are observed only after RuntimeLoop completion")
	for field in [
		"direct_world_access",
		"direct_victory_resolution",
		"direct_terminal_presentation",
		"direct_session_completion",
	]:
		_expect(not bool(contract.get(field, true)), "%s remains forbidden" % field)

	var source := FileAccess.get_file_as_string(HELPER_PATH)
	_expect(not source.is_empty(), "helper source is readable")
	_expect(source.contains("AUTHORITATIVE_STEPPER.advance_bounded"), "helper advances only through the accepted authoritative stepper")
	_expect(source.contains("runtime_loop.last_frame_receipt()"), "helper validates the unique RuntimeLoop receipt")
	_expect(source.contains("FULL_RUN_EVIDENCE.timer_traversal_evidence"), "helper reuses the accepted timer traversal oracle")
	_expect(source.contains("FULL_RUN_EVIDENCE.outcome_identity_evidence"), "helper reuses the accepted outcome identity oracle")
	_expect(source.contains("FULL_RUN_EVIDENCE.rng_quiescence_evidence"), "helper reuses the complete RNG quiescence oracle")
	_expect(source.contains("await tree.process_frame"), "helper yields under the held lease only to clear deferred save lifecycle checkpoints")
	_expect(source.contains("await runtime_loop.frame_advanced"), "terminal retry and quiescence await completed RuntimeLoop frames")
	_expect(source.contains("runtime_loop.get_tree() != tree"), "yield paths bind the supplied SceneTree to the leased RuntimeLoop")
	_expect(source.contains("_await_generation_two_lifecycle_clear"), "helper clears deferred lifecycle checkpoints without world progress")
	_expect(source.contains("_lifecycle_checkpoint_gate"), "helper fails closed on every lifecycle checkpoint owner")
	_expect(source.contains("capture_public_sale_binding"), "helper can bind public sale evidence before generation-two save")
	_expect(source.contains('coordinator.get_node_or_null("RuntimeWorldPorts/RuntimeVictoryPort")'), "helper observes the production terminal port")
	_expect(source.contains('services.get_node_or_null("FinalSettlementRuntimeComposition")'), "helper observes the production settlement composition")
	_expect(source.contains('main.get_node_or_null("RuntimeServices/StandingsPublicQueryPort")'), "helper obtains the viewer-authorized timer contract")
	_expect(source.contains("coordinator.save_restore_safety_observation()"), "quiet-frame proof covers the complete save/restore safety observation")
	_expect(source.contains("coordinator.presentation_action_projection(viewer_index)"), "quiet-frame proof covers the authorized action projection")
	_expect(source.contains("coordinator.presentation_recent_public_log_entries(90)"), "quiet-frame proof covers the full bounded public log")
	_expect(source.contains('settlement_debug.get("action_emission_count"'), "quiet-frame proof covers settlement action emissions")
	_expect(source.contains('checkpoint.get("rng_state"'), "quiet-frame proof retains the complete RNG state checkpoint")
	for token in FORBIDDEN_AUTHORITY_TOKENS:
		_expect(not source.contains(token), "helper excludes forbidden authority token %s" % token)

	var sale_binding := {
		"public_event_count": 2,
		"latest_source_revision": 9,
		"public_fingerprint": "b".repeat(64),
	}
	_expect(Evidence._sale_binding_valid(sale_binding), "strict sale binding accepts the exact three-field public identity")
	var incomplete_sale_binding := sale_binding.duplicate(true)
	incomplete_sale_binding.erase("latest_source_revision")
	_expect(not Evidence._sale_binding_valid(incomplete_sale_binding), "strict sale binding rejects an incomplete generation-two identity")
	var lifecycle_clear := _lifecycle_debug_triplet(false, "")
	_expect(bool(Evidence._lifecycle_checkpoint_gate(
		lifecycle_clear[0], lifecycle_clear[1], lifecycle_clear[2]
	).get("verified", false)), "lifecycle gate accepts three cleared production owners")
	var lifecycle_pending := _lifecycle_debug_triplet(false, "")
	(lifecycle_pending[1] as Dictionary)["lifecycle_checkpoint_pending"] = true
	_expect(not bool(Evidence._lifecycle_checkpoint_gate(
		lifecycle_pending[0], lifecycle_pending[1], lifecycle_pending[2]
	).get("verified", true)), "lifecycle gate rejects a pending presentation checkpoint")
	var lifecycle_malformed := _lifecycle_debug_triplet(false, "")
	(lifecycle_malformed[2] as Dictionary).erase("lifecycle_transition_kind")
	_expect(not bool(Evidence._lifecycle_checkpoint_gate(
		lifecycle_malformed[0], lifecycle_malformed[1], lifecycle_malformed[2]
	).get("verified", true)), "lifecycle gate rejects a missing checkpoint field")

	_expect(Evidence.strict_victory_state_sequence_valid(["idle", "qualification", "audit", "resolved"]), "strict sequence accepts the natural lifecycle")
	_expect(not Evidence.strict_victory_state_sequence_valid(["qualification", "audit", "resolved"]), "strict sequence rejects a missing idle baseline")
	_expect(not Evidence.strict_victory_state_sequence_valid(["idle", "qualification", "idle", "audit", "resolved"]), "strict sequence rejects eligibility rollback")
	_expect(not Evidence.strict_victory_state_sequence_valid(["idle", "qualification", "audit", "resolved", "final_settlement"]), "Victory sequence cannot mix presentation labels")

	var timer_contract := Evidence._authorized_timer_contract({
		"schema_version": 1,
		"valid": true,
		"visibility_scope": "viewer_private",
		"viewer_index": 0,
		"qualification_duration_seconds": 10.0,
		"audit_duration_seconds": 120.0,
	})
	_expect(int(timer_contract.get("qualification_duration_us", 0)) == 10_000_000, "authorized qualification duration retains microsecond precision")
	_expect(int(timer_contract.get("audit_duration_us", 0)) == 120_000_000, "authorized audit duration retains microsecond precision")
	var rival_contract := Evidence._authorized_timer_contract({
		"schema_version": 1,
		"valid": true,
		"visibility_scope": "viewer_private",
		"viewer_index": 1,
		"qualification_duration_seconds": 10.0,
		"audit_duration_seconds": 120.0,
	})
	_expect(rival_contract.is_empty(), "timer contract rejects a different viewer")

	var sequence: Array[String] = ["idle"]
	_expect(bool(Evidence._append_strict_victory_state(sequence, _victory("qualification")).get("accepted", false)), "strict state recorder accepts qualification")
	_expect(bool(Evidence._append_strict_victory_state(sequence, _victory("audit")).get("accepted", false)), "strict state recorder accepts audit")
	_expect(bool(Evidence._append_strict_victory_state(sequence, _victory("resolved")).get("accepted", false)), "strict state recorder accepts resolved")
	_expect(Evidence.strict_victory_state_sequence_valid(sequence), "strict state recorder produces the exact lifecycle")
	var invalid_sequence: Array[String] = ["idle"]
	_expect(not bool(Evidence._append_strict_victory_state(invalid_sequence, _victory("audit")).get("accepted", true)), "strict state recorder rejects a skipped qualification")

	var terminal_port := {
		"terminal_queue_count": 1,
		"terminal_retry_count": 1,
		"terminal_commit_count": 1,
		"terminal_reject_count": 0,
		"terminal_stale_drop_count": 0,
		"pending_terminal": false,
	}
	var settlement := {
		"present_count": 1,
		"presented_outcome_count": 1,
		"logged_outcome_count": 1,
		"last_presented_outcome_id": "victory.v06.1",
		"last_public_snapshot_fingerprint": "a".repeat(64),
	}
	_expect(Evidence.terminal_exact_once_counts_valid(terminal_port, settlement, "victory.v06.1"), "exact-once counters accept one terminal commit, presentation, and log")
	var retried_port := terminal_port.duplicate(true)
	retried_port["terminal_reject_count"] = 1
	_expect(Evidence.terminal_exact_once_counts_valid(retried_port, settlement, "victory.v06.1"), "a bounded rejected presentation retry does not duplicate terminal side effects")
	var duplicate_settlement := settlement.duplicate(true)
	duplicate_settlement["present_count"] = 2
	_expect(not Evidence.terminal_exact_once_counts_valid(terminal_port, duplicate_settlement, "victory.v06.1"), "duplicate settlement presentation fails closed")
	var pending_port := terminal_port.duplicate(true)
	pending_port["pending_terminal"] = true
	_expect(not Evidence.terminal_exact_once_counts_valid(pending_port, settlement, "victory.v06.1"), "an uncommitted terminal receipt fails closed")

	var finished_frame := {
		"frame_index": 101,
		"path": "finished",
		"stopped_reason": "session_finished",
		"world_delta": 0.0,
		"phase_trace": ["lifecycle_begin"],
	}
	_expect(Evidence.terminal_finished_frame_valid(finished_frame, 101), "finished frame oracle accepts one lifecycle-only zero-world frame")
	var changed_frame := finished_frame.duplicate(true)
	changed_frame["world_delta"] = 1.0
	_expect(not Evidence.terminal_finished_frame_valid(changed_frame, 101), "finished frame oracle rejects world progress")
	_expect(not Evidence.terminal_finished_frame_valid(finished_frame, 102), "finished frame oracle rejects frame discontinuity")
	_scan_driver_integration()
	_finish()


func _lifecycle_debug_triplet(pending: bool, kind: String) -> Array[Dictionary]:
	return [
		{
			"lifecycle_checkpoint_pending": pending,
			"lifecycle_transition_kind": kind,
		},
		{
			"lifecycle_checkpoint_pending": pending,
			"lifecycle_transition_kind": kind,
			"session_plan_checkpoint_pending": pending,
		},
		{
			"lifecycle_checkpoint_pending": pending,
			"lifecycle_transition_kind": kind,
			"session_plan_checkpoint_pending": pending,
		},
	]


func _scan_driver_integration() -> void:
	var driver_source := FileAccess.get_file_as_string(DRIVER_PATH)
	_expect_integration(not driver_source.is_empty(), "cold-restore driver source is readable")
	if driver_source.is_empty():
		return
	var consumer_source := _function_source(driver_source, "_run_consumer")
	var terminal_source := _function_source(driver_source, "_finish_to_settlement")
	_expect_integration(not consumer_source.is_empty(), "consumer path is source-auditable")
	_expect_integration(not terminal_source.is_empty(), "terminal adapter is source-auditable")
	_expect_integration(
		driver_source.contains('preload("res://scripts/tools/cold_restore_terminal_evidence.gd")'),
		"driver preloads the independent terminal evidence helper"
	)
	var sale_capture_index := consumer_source.find(".capture_public_sale_binding(")
	var generation_two_save_index := consumer_source.find("generation_two := _save_via_player_flow")
	var sale_context_index := consumer_source.find('"generation_two_sale_binding"')
	_expect_integration(
		sale_capture_index >= 0 and generation_two_save_index > sale_capture_index,
		"driver captures the public sale binding before generation-two save"
	)
	_expect_integration(
		sale_context_index > generation_two_save_index,
		"driver carries the pre-save sale binding into generation-two terminal context"
	)
	var acquire_index := terminal_source.find(".acquire_manual_lease(")
	var lease_yield_index := terminal_source.find("await process_frame", acquire_index + 1)
	var idle_gate_index := terminal_source.find(".generation_two_idle_gate(")
	var finish_index := terminal_source.find(".finish_to_settlement(")
	var tree_argument_index := terminal_source.find("self", finish_index) if finish_index >= 0 else -1
	_expect_integration(acquire_index >= 0, "driver acquires the bounded RuntimeLoop lease")
	_expect_integration(
		lease_yield_index > acquire_index and idle_gate_index > lease_yield_index,
		"driver yields with RuntimeLoop disabled before asserting the lifecycle-clean idle gate"
	)
	_expect_integration(
		finish_index > idle_gate_index and tree_argument_index > finish_index,
		"driver delegates terminal progression to the async helper with the real SceneTree"
	)
	_expect_integration(
		terminal_source.contains(".release_manual_lease("),
		"driver releases the lease on a pre-terminal gate rejection"
	)
	for token in FORBIDDEN_AUTHORITY_TOKENS:
		_expect_integration(
			not terminal_source.contains(token),
			"driver terminal adapter excludes forbidden authority token %s" % token
		)
	for legacy_label in ["restored_running", "last_survivor", "final_settlement", "quiescent"]:
		_expect_integration(
			not terminal_source.contains(legacy_label),
			"driver terminal adapter excludes legacy fixture label %s" % legacy_label
		)


func _function_source(source: String, function_name: String) -> String:
	var marker := "func %s(" % function_name
	var start := source.find(marker)
	if start < 0:
		return ""
	var next_function := source.find("\nfunc ", start + marker.length())
	return source.substr(start) if next_function < 0 \
		else source.substr(start, next_function - start)


func _victory(state_id: String) -> Dictionary:
	return {
		"visibility_scope": "public",
		"state": state_id,
	}


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _expect_integration(condition: bool, label: String) -> void:
	_integration_checks += 1
	if not condition:
		_integration_failures.append(label)


func _finish() -> void:
	print("cold_restore_terminal_evidence_helper_contract: %s %d/%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks - _failures.size(),
		_checks,
	])
	print("cold_restore_terminal_evidence_driver_integration: %s %d/%d" % [
		"PASS" if _integration_failures.is_empty() else "PENDING",
		_integration_checks - _integration_failures.size(),
		_integration_checks,
	])
	for failure in _failures:
		push_error("HELPER_CONTRACT: %s" % failure)
	for failure in _integration_failures:
		push_error("DRIVER_INTEGRATION_PENDING: %s" % failure)
	quit(0 if _failures.is_empty() and _integration_failures.is_empty() else 1)
