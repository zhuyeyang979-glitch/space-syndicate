extends SceneTree

const ORCHESTRATOR_PATH := "res://scripts/tools/cold_restore_vertical_slice_orchestrator.ps1"
const DRIVER_PATH := "res://scripts/tools/cold_restore_vertical_slice_driver.gd"
const ATTESTED_PROCESS_PATH := "res://scripts/tools/cold_restore_attested_process.psm1"
const CHILD_ATTESTATION_PATH := "res://scripts/tools/cold_restore_child_completion_attestation.gd"
const SAVE_OWNER_REGISTRY_PATH := "res://scripts/runtime/v06_save_owner_registry.gd"
const DIAGNOSTIC_SCENARIO_IDENTITY_PATH := "res://scripts/tools/diagnostic_scenario_identity_v1.gd"
const TARGETED_OWNER_DIAGNOSTIC_PATH := "res://scripts/tools/targeted_owner_capture_diagnostic_v2.gd"
const ROLE_TIMEOUT_POLICY_PATH := "res://scripts/tools/cold_restore_role_timeout_policy_v1.json"
const ROLE_PROGRESS_HEARTBEAT_PATH := "res://scripts/tools/cold_restore_role_progress_heartbeat.gd"
const PROCESS_A_REHEARSAL_COMPLETION_PATH := "res://scripts/tools/process_a_rehearsal_completion_v1.gd"
const SAFE_RESULT_FIELDS := [
	"schema_version",
	"driver_id",
	"formal_full_run",
	"execution_ready",
	"executed",
	"contract_fixture",
	"run_id",
	"process_sequence",
	"comparison_scope",
	"process_ids_distinct",
	"head_sha_match",
	"generation1_digest_match",
	"generation2_digest_match",
	"write_chain_match",
	"queue_target_identity_match",
	"pending_queue_exact_once",
	"section_counts_exact",
	"save_capture_deltas_zero",
	"restore_deltas_zero",
	"action_counts_positive",
	"generation2_counts_exact",
	"registry_commit_rebind_exact",
	"save_readback_exact",
	"duplicate_counts_zero",
	"typed_restore_fingerprints_match",
	"generation_two_restore_exact",
	"final_settlement_exact_once",
	"terminal_quiescent_frames",
	"terminal_quiet",
	"success",
	"failure_code",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var source := FileAccess.get_file_as_string(ORCHESTRATOR_PATH)
	var driver_source := FileAccess.get_file_as_string(DRIVER_PATH)
	var wrapper_source := FileAccess.get_file_as_string(ATTESTED_PROCESS_PATH)
	var child_attestation_source := FileAccess.get_file_as_string(CHILD_ATTESTATION_PATH)
	var registry_source := FileAccess.get_file_as_string(SAVE_OWNER_REGISTRY_PATH)
	var scenario_identity_source := FileAccess.get_file_as_string(DIAGNOSTIC_SCENARIO_IDENTITY_PATH)
	var targeted_diagnostic_source := FileAccess.get_file_as_string(TARGETED_OWNER_DIAGNOSTIC_PATH)
	var timeout_policy_source := FileAccess.get_file_as_string(ROLE_TIMEOUT_POLICY_PATH)
	var heartbeat_source := FileAccess.get_file_as_string(ROLE_PROGRESS_HEARTBEAT_PATH)
	var rehearsal_completion_source := FileAccess.get_file_as_string(PROCESS_A_REHEARSAL_COMPLETION_PATH)
	_expect(source.contains("$ORCHESTRATOR_SCHEMA_VERSION = 4") and source.contains("$FORMAL_FULL_RUN = $false") and source.contains("$DriverExecutionReady = $true"), "orchestrator exposes a non-Formal v4 QA role contract behind explicit qualification and official authorization gates")
	_expect(driver_source.contains("const SCHEMA_VERSION := 4") and driver_source.contains("const EXECUTION_READY := true") and driver_source.contains('"driver_id": "alpha04c_cold_restore_vertical_slice_v4"'), "driver and orchestrator share one executable Harness-only v4 contract")
	_expect(driver_source.contains("--cold-restore-expected-queue-resolution-id=") and driver_source.contains("--cold-restore-expected-queue-stable-target-fingerprint=") and driver_source.contains("--cold-restore-scenario-fingerprint=") and driver_source.contains("--cold-restore-official-claim-path=") and driver_source.contains("--cold-restore-launch-attestation-path=") and driver_source.contains("--cold-restore-launch-nonce=") and driver_source.contains('"unknown_option"') and driver_source.contains('"duplicate_option"'), "driver accepts only the closed expected-identity and attested authorization option surface")
	_expect(not driver_source.contains("--cold-restore-official-count-consumed=") and driver_source.contains("caller_boolean_authorization_accepted\": false"), "direct driver invocation cannot forge official authorization with a caller boolean")
	_expect(driver_source.contains("AUTHORIZATION_CONTRACT_PATH") and driver_source.contains('_authorization_contract_entry("official_attempt_2")') and driver_source.contains("OfficialAttemptClaimV2") and driver_source.contains("_resolve_git_common_dir") and driver_source.contains("_authorize_official_launch") and driver_source.contains("OS.get_process_id()"), "driver requires the contract-bound Attempt 2 claim and a launch attestation bound to the actual engine PID")
	_expect(source.contains("$OfficialAttempt2ClaimRelativePath = [string]$OfficialAttempt2Authorization.claim_path") and source.contains("Publish-ColdRestoreOfficialAttempt2Claim") and source.contains("Assert-ColdRestoreOfficialAttempt2Boundary"), "orchestrator consumes one contract-bound independent OfficialAttemptClaimV2 below the Git common directory")
	_expect(not source.contains('Join-Path $paths.root "official_ledger.json"') and source.contains("Invoke-ColdRestoreNonOfficialProcessA") and source.contains("official_cold_restore_vertical_slice = $false"), "non-official Process A uses no RunId-selected official authorization ledger")
	_expect(wrapper_source.contains("[IO.FileMode]::CreateNew") and wrapper_source.contains("Write-ColdRestoreExclusiveJson") and wrapper_source.contains("Write-ColdRestoreLaunchAttestation"), "the claim final path is created exclusively and each child receives a PID-bound launch attestation")
	var claim_call_index := source.rfind("Assert-AndConsumeOfficialColdRestoreAuthorization $resolvedProjectPath $headSha")
	_expect(source.find('if ($ContractManifestPath -ne "")') < claim_call_index and source.find("-and -not $EnableColdRestoreExecution") < claim_call_index and source.find("if ($QualificationProbe)") < claim_call_index and source.find("if ($NonOfficialProcessA)") < claim_call_index and source.find("if ($OfficialAttempt2PreflightOnly)") < claim_call_index, "contract fixture, default check-only, qualification, rehearsal, and side-effect-free Attempt 2 preflight all exit before claim publication")
	var targeted_mode_index := source.find("if ($TargetedOwnerCaptureDiagnostic)")
	_expect(source.contains("[switch]$TargetedOwnerCaptureDiagnostic") and targeted_mode_index >= 0 and targeted_mode_index < claim_call_index and source.contains("targeted_owner_capture_mode_collision") and driver_source.contains('if text == "--cold-restore-targeted-owner-capture-diagnostic":') and driver_source.contains("targeted_owner_capture_official_forbidden"), "targeted Owner capture has a dedicated mutually exclusive CLI mode that cannot cross the official claim boundary")
	_expect(scenario_identity_source.contains('const IDENTITY_ID := "DiagnosticScenarioIdentityV1"') and scenario_identity_source.contains('const EXPECTED_RULESET_ID := "v0.6"') and scenario_identity_source.contains("const EXPECTED_CHALLENGE_DEPTH := 1") and scenario_identity_source.contains("const EXPECTED_RUN_SEED := 900626424") and scenario_identity_source.contains('"run_seed_tagged_int64"') and scenario_identity_source.contains("private_payload_redacted") and scenario_identity_source.contains('SEMANTIC_WIRE.fingerprint(identity, "identity_fingerprint")'), "DiagnosticScenarioIdentityV1 closes and fingerprints the immutable V0.6 depth-one seeded scenario identity")
	_expect(driver_source.contains("const DIAGNOSTIC_SCENARIO_IDENTITY := preload") and driver_source.contains('../RulesetSaveAttestationOwner') and driver_source.contains('"ruleset_id": str(ruleset_attestation.get("ruleset_id", ""))') and driver_source.contains('"challenge_depth": int(started.get("challenge_depth", -1))') and driver_source.contains("DIAGNOSTIC_SCENARIO_IDENTITY.validation_report"), "the driver derives scenario identity from the authoritative ruleset Owner and committed session result")
	var diagnostic_phases := [
		"diagnostic_started", "session_creating", "session_started",
		"scenario_identity_attesting", "scenario_identity_attested",
		"registry_binding_attesting", "registry_binding_attested",
		"owner_audit_started", "owner_capture_started", "owner_capture_succeeded",
		"owner_capture_failed", "owner_audit_completed", "diagnostic_completed",
	]
	var diagnostic_phase_contract_green := diagnostic_phases.size() == 13 \
			and targeted_diagnostic_source.contains('const DIAGNOSTIC_ID := "TargetedOwnerCaptureDiagnosticV2"') \
			and targeted_diagnostic_source.contains('const TIMELINE_ID := "TargetedOwnerCaptureDiagnosticPhaseTimelineV1"') \
			and source.contains('"TargetedOwnerCaptureDiagnosticV2"') \
			and source.contains('[string]$timeline.last_completed_phase -ceq "diagnostic_completed"') \
			and source.contains('[string]$timeline.next_expected_phase -ceq "none"')
	for phase_id in diagnostic_phases:
		diagnostic_phase_contract_green = diagnostic_phase_contract_green \
				and targeted_diagnostic_source.contains('"%s"' % phase_id) \
				and source.contains('"%s"' % phase_id)
	_expect(diagnostic_phase_contract_green, "TargetedOwnerCaptureDiagnosticV2 exposes thirteen closed phase IDs and must terminate at diagnostic_completed")
	_expect(driver_source.contains("# V2 performs one 19-Owner audit at the real restore barrier.") and driver_source.count('registry.call("capture_all_sections_detailed", self)') == 1 and registry_source.contains("func capture_all_sections_detailed(progress_sink: Variant = null) -> Dictionary:") and registry_source.contains("var result := _capture_all_sections_detailed_internal({}, true)") and registry_source.contains("var detailed := _capture_all_sections_detailed_internal(analysis)"), "targeted diagnostics perform one 19-Owner audit through the same Registry implementation used by production Save")
	_expect(targeted_diagnostic_source.contains('"owner_capture_skipped_count"') and targeted_diagnostic_source.contains('"NOT_ATTEMPTED_AFTER_FIRST_FAILURE"') and targeted_diagnostic_source.contains('"first_failure"') and targeted_diagnostic_source.contains('"post_capture_failure"') and source.contains("$ownerRows.Count -eq 19") and source.contains("Test-OwnerCaptureFailureIdentity"), "V2 records a stable 19-row prefix, skipped suffix, and distinct typed Owner versus post-capture failures")
	var diagnostic_capture_index := driver_source.find('registry.call("capture_all_sections_detailed", self)')
	var diagnostic_return_index := driver_source.find('return _fail(base, "targeted_owner_capture_diagnostic_complete"', diagnostic_capture_index)
	var process_a_save_index := driver_source.find('var save_barrier_operation_id := "process-a-save-', diagnostic_capture_index)
	_expect(diagnostic_capture_index >= 0 and diagnostic_return_index > diagnostic_capture_index and process_a_save_index > diagnostic_return_index and driver_source.contains('"targeted_owner_capture_diagnostic_writes_save": false') and source.contains("-and -not [bool]$run.child.save_written") and source.contains('$saveArtifacts.Count -eq 0) "targeted_owner_capture_unexpected_save"'), "targeted Owner capture exits before Save Intent and the parent rejects every Save artifact")
	_expect(source.contains("$PreviousTargetedOwnerCaptureQuotaLedgerRelativePath") and source.contains("$TargetedLedgerBindingContract.exact_literals.previous_ledger_sha256") and source.contains("$TargetedOwnerCaptureQuotaLedgerRelativePath") and source.contains("historical_targeted_owner_capture_invocation_record_mutated") and source.contains("permitted_transition_from") and source.contains("permitted_transition_to") and source.contains("Publish-ColdRestoreTargetedQuotaLedgerV4") and source.contains("Get-ColdRestoreTargetedLedgerBindingContract") and source.contains("Assert-ColdRestoreTargetedDiagnosticRemoteCheckpoint") and source.contains('$AuthorizedOfficialColdRestoreCount -eq 0) "targeted_owner_capture_official_authorization_forbidden"'), "the fourth targeted diagnostic has a shared-contract V4 exact-once quota and remote checkpoint while preserving all historical invocations")
	_expect(targeted_diagnostic_source.contains("const ROOT_FIELDS := [") and targeted_diagnostic_source.contains("const OWNER_ROW_FIELDS := [") and targeted_diagnostic_source.contains("const FAILURE_FIELDS := [") and targeted_diagnostic_source.contains("_has_exact_fields") and targeted_diagnostic_source.contains("private_payload_redacted") and child_attestation_source.contains("TARGETED_DIAGNOSTIC_V2.validation_report") and child_attestation_source.contains("write_owner_capture_diagnostic") and source.contains("targeted_owner_capture_private_log_exposed"), "diagnostic evidence is exact-schema, fingerprinted, atomically written, and redacted at Child and Parent boundaries")
	var timeout_policy_value: Variant = JSON.parse_string(timeout_policy_source)
	var timeout_policy: Dictionary = timeout_policy_value as Dictionary if timeout_policy_value is Dictionary else {}
	var timeout_roles: Dictionary = timeout_policy.get("roles", {}) as Dictionary if timeout_policy.get("roles", {}) is Dictionary else {}
	_expect(str(timeout_policy.get("policy_id", "")) == "ColdRestoreRoleTimeoutPolicyV1" and _has_exact_fields(timeout_roles, ["targeted_owner_diagnostic", "process_a", "process_b", "process_c"]) and int((timeout_roles.get("targeted_owner_diagnostic", {}) as Dictionary).get("absolute_timeout_seconds", 0)) == 120 and int((timeout_roles.get("targeted_owner_diagnostic", {}) as Dictionary).get("no_progress_timeout_seconds", 0)) == 30 and int((timeout_roles.get("process_a", {}) as Dictionary).get("absolute_timeout_seconds", 0)) == 180 and int((timeout_roles.get("process_a", {}) as Dictionary).get("no_progress_timeout_seconds", 0)) == 60 and int((timeout_roles.get("process_b", {}) as Dictionary).get("absolute_timeout_seconds", 0)) == 360 and int((timeout_roles.get("process_c", {}) as Dictionary).get("absolute_timeout_seconds", 0)) == 180 and not bool((timeout_roles.get("process_b", {}) as Dictionary).get("contract_only_in_this_task", true)) and not bool((timeout_roles.get("process_c", {}) as Dictionary).get("contract_only_in_this_task", true)), "ColdRestoreRoleTimeoutPolicyV1 defines executable bounded A/B/C budgets")
	_expect(heartbeat_source.contains('const HEARTBEAT_ID := "ColdRestoreRoleProgressHeartbeatV1"') and heartbeat_source.contains('const ROLE_IDS := ["targeted_owner_diagnostic", "process_a", "process_b", "process_c"]') and heartbeat_source.contains('"policy_fingerprint"') and heartbeat_source.contains('"semantic_progress_fingerprint"') and heartbeat_source.contains("file.flush()") and heartbeat_source.contains("DirAccess.rename_absolute") and wrapper_source.contains("ExpectedPolicyFingerprint") and wrapper_source.contains("Sync-ColdRestoreProgressHeartbeat") and wrapper_source.contains('timeoutKind = "no_progress"') and wrapper_source.contains("ParentExitFieldsV2"), "role heartbeat evidence is policy-bound, semantic, atomic, and drives bounded parent supervision")
	_expect(source.contains("Get-ColdRestoreProcessARehearsalDiagnosticAdmission") and source.find("Get-ColdRestoreProcessARehearsalDiagnosticAdmission") < source.find("Consume-ColdRestoreProcessARehearsalQuota", source.find("function Invoke-ColdRestoreNonOfficialProcessA")) and source.contains("process_a_rehearsal_diagnostic_admission_not_green") and source.contains("$ProcessARehearsalQuotaLedgerRelativePath = [string]$ProcessARehearsalAuthorization.quota_ledger_relative_path") and source.contains("official_attempt_2_claim_must_be_absent") and source.contains("process_a_rehearsal_already_consumed"), "Process A rehearsal admits only a green 19/19 diagnostic and consumes its contract-bound non-official exact-once ledger")
	_expect(driver_source.contains("REHEARSAL_LEDGER_FIELDS") and driver_source.contains("process_a_rehearsal_ledger_binding_invalid") and driver_source.contains("PROCESS_A_REHEARSAL_COMPLETION.build") and rehearsal_completion_source.contains('const COMPLETION_ID := "ProcessARehearsalCompletionV1"') and rehearsal_completion_source.contains('int(completion.get("save_owner_capture_count", 0)) != 19') and rehearsal_completion_source.contains('readback_sections_fingerprint != captured_sections_fingerprint') and rehearsal_completion_source.contains('readback_fingerprint != capture_fingerprint') and rehearsal_completion_source.contains("write_atomic") and rehearsal_completion_source.contains("DirAccess.rename_absolute"), "rehearsal completion binds the ledger to 19-Owner capture, envelope/readback parity, and atomic completion evidence")
	_expect(source.contains('process_a_rehearsal_completion_sha256_$completionSha256') and source.contains("Assert-ColdRestoreProcessARehearsalCompletion") and source.contains("$run.parent.child_attestation_valid") and source.contains('Assert-ColdRestoreCondition ([bool]$run.wrapper_exit_green) "producer_$($run.wrapper_reason_code)"') and source.contains("$Result.run.parent.wrapper_exit_green") and source.contains("$run.parent.task_owned_process_count_after -eq 0"), "the rehearsal ledger, completion SHA, Child attestation, Parent exit, and process cleanup form one closed evidence chain")
	_expect(source.contains("Get-ColdRestoreRuntimeFreezeObservation") and source.contains("process_a_rehearsal_post_run_tree_not_clean") and source.contains("official_attempt_2_preclaim_runtime_not_frozen") and source.contains("official_attempt_2_postclaim_runtime_not_frozen") and source.contains("official_attempt_2_runtime_changed_after_claim") and driver_source.contains('"prerequisite_evidence_fingerprint"') and driver_source.contains('"preclaim_runtime_freeze_fingerprint"'), "rehearsal GREEN and Attempt 2 claim-to-launch are bound to one clean immutable runtime HEAD")
	_expect(source.contains('gate_id -ceq "file_fault_matrix"') and source.contains('gate_id -ceq "save_confirmation"') and source.contains('gate_id -ceq "fork_determinism_parity"') and source.contains("file_fault_matrix_checks_passed = 16") and source.contains("save_confirmation_checks_passed = 10") and source.contains("fork_parity_checks_passed = 14"), "Stage 3 and Attempt 2 bind the frozen file-fault, confirmation, and fork-parity gates")
	_expect(source.contains("New-ColdRestoreOfficialAttempt2FailureResult") and source.contains('$result[$field] = "NOT_RUN"') and source.contains('"official_attempt_2_failure_class"') and source.contains('"process_a_status"') and source.contains('"comparison_status"'), "official failure output preserves typed failure class and NOT_RUN stages instead of projecting false or zero")
	var targeted_orchestrator_start := source.find("function Invoke-ColdRestoreTargetedOwnerCaptureDiagnostic")
	var targeted_orchestrator_end := source.find("function New-ColdRestoreTargetedOwnerCaptureOutput", targeted_orchestrator_start)
	var targeted_orchestrator_source := source.substr(targeted_orchestrator_start, targeted_orchestrator_end - targeted_orchestrator_start) \
			if targeted_orchestrator_start >= 0 and targeted_orchestrator_end > targeted_orchestrator_start else ""
	_expect(targeted_orchestrator_source.contains("Invoke-ColdRestoreAttestedProcess") and targeted_orchestrator_source.contains("$run.parent.child_attestation_valid") and targeted_orchestrator_source.contains("$run.parent.exit_code -eq 0") and targeted_orchestrator_source.contains("-not [bool]$run.parent.timed_out") and targeted_orchestrator_source.contains("-not [bool]$run.parent.terminated_by_parent") and targeted_orchestrator_source.contains("$run.parent.task_owned_process_count_after -eq 0"), "targeted Owner capture completes through the normal child completion and parent exit attestation path")
	_expect(driver_source.contains("cold_restore_process_a_phase_timeline.gd") and driver_source.contains("allowlisted_manifest_complete") and driver_source.contains("child_completion_attestation_complete") and wrapper_source.contains("Sync-ColdRestoreProcessAPhaseTimeline"), "Process A emits a parent-synchronized nineteen-phase timeline without treating progress as completion")
	_expect(driver_source.contains("_advance_targeted_diagnostic_phase") and driver_source.contains('"diagnostic_completed"') and driver_source.contains("_safe_reason_code") and source.contains('$NonOfficialProcessAKind -ceq "rehearsal"'), "diagnostic failure closes typed evidence while Process A rehearsal remains an explicitly authorized product-success path")
	_expect(driver_source.contains("last_internal_capture_failure_section") and driver_source.contains("last_internal_capture_failure_reason") and driver_source.contains('internal_reason = "capture:%s:%s"'), "Process A QA evidence retains the failing Registry section and internal reason without widening the public Save receipt")
	var save_failure_start := driver_source.find("func _save_via_player_flow")
	var save_failure_end := driver_source.find("\nfunc ", save_failure_start + 1)
	var save_failure_source := driver_source.substr(save_failure_start, save_failure_end - save_failure_start) \
			if save_failure_start >= 0 and save_failure_end > save_failure_start else ""
	_expect(save_failure_source.contains("mismatch_path_fingerprint") and save_failure_source.contains("sha256_text().substr(0, 12)") and not save_failure_source.contains('trim_prefix("root.sections.")'), "Process A public readback failure fingerprints the mismatch path and never emits a raw Owner field path")
	_expect(source.contains('"left_scalar"') and source.contains('"right_scalar"') and source.contains('"next_quote_sequence":') and source.contains("targeted_owner_capture_private_log_exposed"), "targeted Parent evidence rejects private mismatch scalars and allocator cursor payloads")
	_expect(source.contains("save_green = [bool]$Result.timeline.save_file_exists `") and source.contains("$Result.timeline.allowlisted_manifest_written") and source.contains("$Result.run.parent.child_attestation_valid") and source.contains("$Result.run.parent.task_owned_process_count_after -eq 0"), "non-official save_green requires Save fingerprint, manifest, both attestations, normal exit, and process cleanup instead of file existence alone")
	var forged_boolean := _invoke_driver_with_forged_boolean()
	_expect(int(forged_boolean.get("exit_code", 0)) != 0 and not driver_source.contains('if text.begins_with("--cold-restore-official-count-consumed")'), "the retired official-count boolean is rejected before runtime or Save access")
	_expect(not driver_source.contains(".tick_ai(") and not driver_source.contains("_tick_ai_until_nontrivial_queue") and driver_source.contains("AUTHORITATIVE_STEPPER.advance_bounded") and driver_source.contains("TERMINAL_EVIDENCE.acquire_manual_lease"), "all AI progress uses the bounded authoritative RuntimeLoop lease with no direct tick fallback")
	_expect(driver_source.contains('var save_failure_code := "" if bool(save.get("ok", false))') and driver_source.contains("_ordered_process_a_boundary_failures") and driver_source.contains('base["_secondary_failure_codes"]'), "Process A freezes the production Save failure and retains later barrier failures as secondary")
	_expect(driver_source.contains('before.has(field) and after.has(field)') and driver_source.contains('typeof(before.get(field)) == TYPE_INT') and driver_source.contains('world_digest_before == world_digest_after') and driver_source.contains('str(barrier_receipt.get("operation_id", "")) == operation_id'), "Process A full quiet window fails closed on missing fields, wrong types, world drift, or operation mismatch")
	_expect(driver_source.count('"observation_kind": "postcondition_projection"') == 2 and driver_source.count('}, "postcondition_projection")') == 2 and driver_source.contains('readback_phase_evidence["full_quiet_window"] = true'), "encode and atomic-write timeline rows are labeled projections while readback closes only after the full quiet window")
	_expect(driver_source.contains("_generation_two_no_continuation_evidence") and driver_source.contains("TERMINAL_EVIDENCE.generation_two_idle_gate") and driver_source.contains("validator_target_commitment_exact"), "Process C proves a clean Generation-2 idle state and the target facility commitment without continuation defaults")
	_expect(driver_source.contains("consumer_restored_queue_target_identity_invalid") and driver_source.contains("consumer_queue_target_exact_once_invalid") and driver_source.contains("validator_queue_target_lineage_invalid"), "driver validates A identity in B before continuation and proves completed Generation-2 lineage in C")
	_expect(source.contains('[ValidateSet("producer", "consumer", "validator")]') and source.contains('$RoleSequence = @("producer", "consumer", "validator")'), "v3 contract has three closed process roles")
	_expect(source.contains('"worktree_not_clean"') and source.contains("-EnvironmentVariables @{ APPDATA = $IsolatedAppData; LOCALAPPDATA = $IsolatedLocalAppData }"), "official execution rejects dirty sources and isolates the shared production slot from player data")
	_expect(wrapper_source.contains("ProcessStartInfo") and wrapper_source.contains("ArgumentList.Add") and wrapper_source.contains("WaitForExit") and wrapper_source.contains("ReadToEndAsync"), "every child uses one quoted-argument-safe bounded process wrapper with explicit stream completion")
	_expect(wrapper_source.contains("stdout_sha256") and wrapper_source.contains("stderr_sha256") and wrapper_source.contains("task_owned_process_count_after") and wrapper_source.contains("ParentExitFields"), "the parent records log hashes, child validation, and process-tree cleanup")
	_expect(child_attestation_source.contains("child_attestation_readback_failed") and child_attestation_source.contains("DirAccess.rename_absolute") and child_attestation_source.contains("evidence_fingerprint"), "child completion uses temp write, readback, fingerprint, and atomic install before quit")
	var chain_index := source.find("function Invoke-ColdRestoreOfficialRoleChain")
	var producer_index := source.find("$producerRun = Invoke-ColdRestoreRole", chain_index)
	var consumer_index := source.find("$consumerRun = Invoke-ColdRestoreRole", producer_index + 1)
	var validator_index := source.find("$validatorRun = Invoke-ColdRestoreRole", consumer_index + 1)
	_expect(producer_index >= 0 and producer_index < consumer_index and consumer_index < validator_index, "producer, consumer, and validator launch sequentially")
	_expect(source.contains("rev-parse HEAD") and source.contains("--cold-restore-head-sha=$HeadSha"), "one repository HEAD attestation is passed to all three roles")
	_expect(source.contains("observed_task_process_ids") and source.contains("manifest.process_id") and source.contains("[string]$manifest.head_sha -eq $HeadSha"), "each runtime manifest is bound to an observed task-owned engine process and repository HEAD")
	_expect(source.contains("--cold-restore-expected-queue-resolution-id=$ExpectedQueueResolutionId") and source.contains("--cold-restore-expected-queue-stable-target-fingerprint=$ExpectedQueueStableTargetFingerprint"), "A's closed queue identity is passed explicitly into B and B's verified identity is passed into C")
	_expect(source.contains("$producerRun.manifest.queue_trigger_resolution_id") and source.contains("$producerRun.manifest.queue_trigger_stable_target_fingerprint") and source.contains("$consumerRun.manifest.queue_trigger_resolution_id") and source.contains("$consumerRun.manifest.queue_trigger_stable_target_fingerprint"), "the sequential launcher sources B's expectation from A and C's expectation from B")
	_expect(source.contains("Read-ColdRestoreJsonArtifact $paths.child_result") and source.contains("child_attestation_valid") and source.contains("manifest_field_set_invalid"), "runtime authority is the atomic result plus child and parent attestations, not the stdout tail")
	_expect(driver_source.contains("quit(0)") and driver_source.contains('"product_blocker"') and driver_source.contains("BLOCKED_BY_NO_LEGAL_QUEUE_ACCEPTANCE_SCENARIO"), "product qualification failure is represented in data while a completed Harness exits zero")
	_expect(wrapper_source.contains("godot_engine_argument_after_separator") and source.contains("New-ColdRestoreGodotArgumentList"), "engine-only arguments are rejected after the Godot user separator")
	_expect(source.contains("$generation1Digest -eq [string]$Consumer.source_sections_digest") and source.contains("$generation1Digest -eq [string]$Consumer.restored_sections_digest"), "generation one compares A saved against B source and restored digests")
	_expect(source.contains("$generation2Digest -eq [string]$Validator.source_sections_digest") and source.contains("$generation2Digest -eq [string]$Validator.restored_sections_digest"), "generation two compares B saved against C source and restored digests")
	_expect(source.contains("write_id_rotation_invalid") and source.contains("write_fingerprint_rotation_invalid") and source.contains("write_chain_mismatch"), "v3 comparison rotates writes while preserving both source chains")
	for required_field in [
		"restore_rng_draw_delta",
		"restore_world_time_delta",
		"restore_public_log_delta",
		"restore_sale_receipt_delta",
		"restore_economic_reward_delta",
		"restore_ai_action_delta",
		"restore_player_action_delta",
		"restore_notification_delta",
		"restore_private_feedback_delta",
		"registry_commit_count",
		"registry_rebind_count",
		"partial_restore_state_count",
		"save_readback_green",
		"save_fingerprint_parity",
		"duplicate_queue_entry_count",
		"duplicate_facility_creation_count",
		"duplicate_card_consumption_count",
		"duplicate_cost_consumption_count",
		"duplicate_sale_receipt_count",
		"world_fingerprint_match",
		"rng_cursor_match",
		"ai_state_fingerprint_match",
		"card_inventory_fingerprint_match",
		"queue_fingerprint_match",
		"generation_2_recapture_fingerprint_match",
		"generation_2_rng_cursor_match",
		"generation_2_duplicate_transaction_count",
		"human_action_count",
		"commodity_action_count",
		"ai_action_count",
		"sale_receipt_count",
		"terminal_quiescent_frames",
		"queue_trigger_resolution_id",
		"queue_trigger_stable_target_fingerprint",
		"queue_target_pending_before_resume",
		"queue_target_pending_after_resume",
		"queue_target_completed_before_resume",
		"queue_target_completed_after_resume",
		"queue_target_history_before_resume",
		"queue_target_history_after_resume",
		"queue_target_execution_finalize_delta",
		"queue_target_history_append_delta",
		"queue_target_history_duplicate_delta",
		"queue_target_transition_duplicate_delta",
		"queue_target_inventory_queue_commit_delta",
		"queue_target_public_log_duplicate_delta",
		"queue_target_public_log_collision_delta",
	]:
		_expect(source.contains('"%s"' % required_field), "v4 manifest includes %s" % required_field)
	_expect(source.contains("validator_action_count_nonzero") and source.contains("producer_queue_target_state_invalid") and source.contains("preterminal_victory_state_invalid"), "role-specific action, pending-queue, and preterminal invariants fail closed")
	_expect(source.contains("consumer_queue_target_exact_once_invalid") and source.contains("consumer_queue_target_duplicate_side_effect") and source.contains("validator_queue_target_lineage_invalid"), "target resolution must restore pending once, complete once, persist in Generation 2, and produce no replay side effects")
	_expect(source.contains("final_settlement_exact_once_invalid") and source.contains("terminal_quiescent_frames -ge 8") and source.contains("terminal_quiet_delta_nonzero") and source.contains("validator_terminal_continuation_invalid"), "B settlement is exact-once and followed by eight zero-delta quiet frames while C performs no continuation")

	var fixture := _valid_fixture()
	var fixture_path := ProjectSettings.globalize_path("user://cold_restore_orchestrator_v3_contract.json")
	_expect(_write_fixture(fixture_path, fixture), "synthetic safe manifest fixture is writable")
	var accepted := _invoke_orchestrator(fixture_path)
	var accepted_result: Dictionary = accepted.get("result", {}) if accepted.get("result", {}) is Dictionary else {}
	_expect(
		int(accepted.get("exit_code", -1)) == 0 and bool(accepted_result.get("success", false)),
		"synthetic three-process manifest chain passes the real PowerShell comparator: %s"
			% JSON.stringify(accepted.get("raw_output", []))
	)
	_expect(_has_exact_fields(accepted_result, SAFE_RESULT_FIELDS) and bool(accepted_result.get("process_ids_distinct", false)) and bool(accepted_result.get("head_sha_match", false)), "successful output uses one closed safe result allowlist")
	_expect(bool(accepted_result.get("generation1_digest_match", false)) and bool(accepted_result.get("generation2_digest_match", false)) and bool(accepted_result.get("write_chain_match", false)), "synthetic comparator proves both digest generations and write lineage")
	_expect(bool(accepted_result.get("queue_target_identity_match", false)) and bool(accepted_result.get("pending_queue_exact_once", false)), "synthetic comparator proves one named A resolution restores, drains once in B, and remains completed in C")
	_expect(bool(accepted_result.get("save_capture_deltas_zero", false)) and bool(accepted_result.get("restore_deltas_zero", false)) and bool(accepted_result.get("action_counts_positive", false)), "synthetic comparator proves save/restore silence and continued actions")
	_expect(bool(accepted_result.get("final_settlement_exact_once", false)) and int(accepted_result.get("terminal_quiescent_frames", 0)) == 8 and bool(accepted_result.get("terminal_quiet", false)), "synthetic comparator proves one settlement and eight quiet frames")
	_expect(
		bool(accepted_result.get("typed_restore_fingerprints_match", false))
			and bool(accepted_result.get("generation_two_restore_exact", false)),
		"successful output explicitly attests typed restore and Generation 2 exactness"
	)
	var accepted_serialized := JSON.stringify(accepted_result)
	for private_value in [
		str((fixture.get("producer", {}) as Dictionary).get("saved_sections_digest", "")),
		str((fixture.get("producer", {}) as Dictionary).get("write_id", "")),
		str((fixture.get("producer", {}) as Dictionary).get("write_fingerprint", "")),
		str((fixture.get("producer", {}) as Dictionary).get("head_sha", "")),
	]:
		_expect(not accepted_serialized.contains(private_value), "safe result omits manifest evidence value %s" % private_value.left(12))

	var missing_consumer_action := fixture.duplicate(true)
	(missing_consumer_action.get("consumer", {}) as Dictionary)["human_action_count"] = 0
	_expect_fixture_rejected(fixture_path, missing_consumer_action, "consumer_action_count_missing", "consumer action delta zero")

	var nonzero_validator_action := fixture.duplicate(true)
	(nonzero_validator_action.get("validator", {}) as Dictionary)["human_action_count"] = 1
	_expect_fixture_rejected(fixture_path, nonzero_validator_action, "validator_action_count_nonzero", "validator action delta nonzero")

	var missing_producer_queue := fixture.duplicate(true)
	(missing_producer_queue.get("producer", {}) as Dictionary)["queue_entry_count"] = 0
	_expect_fixture_rejected(fixture_path, missing_producer_queue, "producer_queue_target_state_invalid", "producer pending queue zero")

	var mismatched_target_identity := fixture.duplicate(true)
	(mismatched_target_identity.get("consumer", {}) as Dictionary)["queue_trigger_stable_target_fingerprint"] = "mismatched-target".sha256_text()
	_expect_fixture_rejected(fixture_path, mismatched_target_identity, "queue_target_identity_mismatch", "consumer target fingerprint differs from producer")

	var missing_target_identity := fixture.duplicate(true)
	(missing_target_identity.get("producer", {}) as Dictionary)["queue_trigger_stable_target_fingerprint"] = ""
	_expect_fixture_rejected(fixture_path, missing_target_identity, "queue_target_identity_invalid", "producer target fingerprint is absent")

	var missing_restored_target := fixture.duplicate(true)
	(missing_restored_target.get("consumer", {}) as Dictionary)["queue_target_pending_before_resume"] = 0
	_expect_fixture_rejected(fixture_path, missing_restored_target, "consumer_queue_target_exact_once_invalid", "consumer does not observe the named target before resume")

	var uncompleted_target := fixture.duplicate(true)
	(uncompleted_target.get("consumer", {}) as Dictionary)["queue_target_completed_after_resume"] = 0
	_expect_fixture_rejected(fixture_path, uncompleted_target, "consumer_queue_target_exact_once_invalid", "consumer does not complete the named target")

	var duplicate_target_history := fixture.duplicate(true)
	(duplicate_target_history.get("consumer", {}) as Dictionary)["queue_target_history_duplicate_delta"] = 1
	_expect_fixture_rejected(fixture_path, duplicate_target_history, "consumer_queue_target_duplicate_side_effect", "consumer attempts a duplicate target history append")

	var duplicate_target_consumption := fixture.duplicate(true)
	(duplicate_target_consumption.get("consumer", {}) as Dictionary)["queue_target_inventory_queue_commit_delta"] = 1
	_expect_fixture_rejected(fixture_path, duplicate_target_consumption, "consumer_queue_target_duplicate_side_effect", "consumer repeats queue-time card consumption")

	var duplicate_target_transition := fixture.duplicate(true)
	(duplicate_target_transition.get("consumer", {}) as Dictionary)["queue_target_transition_duplicate_delta"] = 1
	_expect_fixture_rejected(fixture_path, duplicate_target_transition, "consumer_queue_target_duplicate_side_effect", "consumer replays a target transition command")

	var target_public_log_collision := fixture.duplicate(true)
	(target_public_log_collision.get("consumer", {}) as Dictionary)["queue_target_public_log_collision_delta"] = 1
	_expect_fixture_rejected(fixture_path, target_public_log_collision, "consumer_queue_target_duplicate_side_effect", "consumer collides with a restored public-log receipt binding")

	var private_feedback_replay := fixture.duplicate(true)
	(private_feedback_replay.get("consumer", {}) as Dictionary)["restore_private_feedback_delta"] = 1
	_expect_fixture_rejected(fixture_path, private_feedback_replay, "restore_delta_nonzero", "restore replays private feedback")

	var missing_registry_commit := fixture.duplicate(true)
	(missing_registry_commit.get("consumer", {}) as Dictionary)["registry_commit_count"] = 0
	_expect_fixture_rejected(fixture_path, missing_registry_commit, "restore_apply_count_invalid", "consumer misses the exact-once Registry commit")

	var missing_registry_rebind := fixture.duplicate(true)
	(missing_registry_rebind.get("validator", {}) as Dictionary)["registry_rebind_count"] = 0
	_expect_fixture_rejected(fixture_path, missing_registry_rebind, "restore_apply_count_invalid", "validator misses the exact-once rebind")

	var missing_save_readback := fixture.duplicate(true)
	(missing_save_readback.get("producer", {}) as Dictionary)["save_readback_green"] = false
	_expect_fixture_rejected(fixture_path, missing_save_readback, "save_readback_or_fingerprint_invalid", "Process A lacks Save readback")

	var duplicate_facility := fixture.duplicate(true)
	(duplicate_facility.get("consumer", {}) as Dictionary)["duplicate_facility_creation_count"] = 1
	_expect_fixture_rejected(fixture_path, duplicate_facility, "duplicate_side_effect_detected", "consumer creates a duplicate facility")

	var missing_generation_two_lineage := fixture.duplicate(true)
	(missing_generation_two_lineage.get("validator", {}) as Dictionary)["queue_target_history_before_resume"] = 0
	_expect_fixture_rejected(fixture_path, missing_generation_two_lineage, "validator_queue_target_lineage_invalid", "validator Generation 2 history omits the named target")

	var generation_two_queue_mismatch := fixture.duplicate(true)
	(generation_two_queue_mismatch.get("validator", {}) as Dictionary)["queue_entry_count"] = 1
	_expect_fixture_rejected(fixture_path, generation_two_queue_mismatch, "validator_generation_two_count_mismatch", "generation-two queue mismatch")

	var missing_validator_surface := fixture.duplicate(true)
	(missing_validator_surface.get("validator", {}) as Dictionary)["production_surface_ready"] = false
	_expect_fixture_rejected(fixture_path, missing_validator_surface, "production_surface_not_ready", "validator production surface missing")

	var resolved_validator_before_save := fixture.duplicate(true)
	(resolved_validator_before_save.get("validator", {}) as Dictionary)["victory_unresolved_before_save"] = false
	_expect_fixture_rejected(fixture_path, resolved_validator_before_save, "preterminal_victory_state_invalid", "validator Generation 2 source is already resolved")

	var missing_typed_restore := fixture.duplicate(true)
	(missing_typed_restore.get("consumer", {}) as Dictionary)["ai_state_fingerprint_match"] = false
	_expect_fixture_rejected(fixture_path, missing_typed_restore, "typed_restore_fingerprint_mismatch", "consumer lacks typed AI restore parity")

	for field in [
		"world_fingerprint_match",
		"rng_cursor_match",
		"ai_state_fingerprint_match",
		"card_inventory_fingerprint_match",
		"queue_fingerprint_match",
	]:
		var missing_domain_restore := fixture.duplicate(true)
		(missing_domain_restore.get("consumer", {}) as Dictionary)[field] = false
		_expect_fixture_rejected(
			fixture_path,
			missing_domain_restore,
			"typed_restore_fingerprint_mismatch",
			"consumer lacks typed %s parity" % field
		)

	var producer_non_neutral_restore := fixture.duplicate(true)
	(producer_non_neutral_restore.get("producer", {}) as Dictionary)["world_fingerprint_match"] = true
	_expect_fixture_rejected(
		fixture_path,
		producer_non_neutral_restore,
		"producer_role_typed_evidence_non_neutral",
		"producer cannot claim restore-only evidence"
	)

	var consumer_non_neutral_generation_two := fixture.duplicate(true)
	(consumer_non_neutral_generation_two.get("consumer", {}) as Dictionary)[
		"generation_2_recapture_fingerprint_match"
	] = true
	_expect_fixture_rejected(
		fixture_path,
		consumer_non_neutral_generation_two,
		"role_typed_evidence_non_neutral",
		"consumer cannot claim validator-only recapture evidence"
	)

	var string_boolean_evidence := fixture.duplicate(true)
	(string_boolean_evidence.get("consumer", {}) as Dictionary)["world_fingerprint_match"] = "true"
	_expect_fixture_rejected(
		fixture_path,
		string_boolean_evidence,
		"manifest_boolean_type_invalid",
		"typed restore Boolean string"
	)

	var string_integer_evidence := fixture.duplicate(true)
	(string_integer_evidence.get("validator", {}) as Dictionary)[
		"generation_2_duplicate_transaction_count"
	] = "0"
	_expect_fixture_rejected(
		fixture_path,
		string_integer_evidence,
		"manifest_integer_invalid",
		"Generation 2 transaction-count string"
	)

	var missing_generation_two_rng := fixture.duplicate(true)
	(missing_generation_two_rng.get("validator", {}) as Dictionary)["generation_2_rng_cursor_match"] = false
	_expect_fixture_rejected(fixture_path, missing_generation_two_rng, "generation_two_restore_evidence_invalid", "validator lacks Generation 2 RNG parity")

	var missing_generation_two_recapture := fixture.duplicate(true)
	(missing_generation_two_recapture.get("validator", {}) as Dictionary)[
		"generation_2_recapture_fingerprint_match"
	] = false
	_expect_fixture_rejected(
		fixture_path,
		missing_generation_two_recapture,
		"generation_two_restore_evidence_invalid",
		"validator lacks Generation 2 recapture parity"
	)

	var duplicate_generation_two_transaction := fixture.duplicate(true)
	(duplicate_generation_two_transaction.get("validator", {}) as Dictionary)["generation_2_duplicate_transaction_count"] = 1
	_expect_fixture_rejected(fixture_path, duplicate_generation_two_transaction, "generation_two_restore_evidence_invalid", "validator observes a duplicate Generation 2 restore transaction")

	var non_string_manifest_identity := fixture.duplicate(true)
	(non_string_manifest_identity.get("validator", {}) as Dictionary)["head_sha"] = null
	_expect_fixture_rejected(fixture_path, non_string_manifest_identity, "manifest_string_type_invalid", "manifest rejects null identity instead of coercing it")

	var invalid_consumer_terminal := fixture.duplicate(true)
	(invalid_consumer_terminal.get("consumer", {}) as Dictionary)["final_settlement_count"] = 0
	_expect_fixture_rejected(fixture_path, invalid_consumer_terminal, "final_settlement_exact_once_invalid", "consumer settlement count zero")

	var invalid_validator_victory_sequence := fixture.duplicate(true)
	(invalid_validator_victory_sequence.get("validator", {}) as Dictionary)["victory_state_sequence"] = ["idle"]
	_expect_fixture_rejected(fixture_path, invalid_validator_victory_sequence, "victory_sequence_mismatch", "validator attempts terminal continuation")

	var invalid_validator_quiet := fixture.duplicate(true)
	(invalid_validator_quiet.get("validator", {}) as Dictionary)["terminal_quiescent_frames"] = 1
	_expect_fixture_rejected(fixture_path, invalid_validator_quiet, "validator_terminal_continuation_invalid", "validator records terminal continuation")

	var invalid_producer_zero := fixture.duplicate(true)
	(invalid_producer_zero.get("producer", {}) as Dictionary)["restore_rng_draw_delta"] = 1
	_expect_fixture_rejected(fixture_path, invalid_producer_zero, "producer_role_zero_invalid", "producer restore delta nonzero")

	var invalid_validator_empty := fixture.duplicate(true)
	(invalid_validator_empty.get("validator", {}) as Dictionary)["write_id"] = "validator-must-not-write"
	_expect_fixture_rejected(fixture_path, invalid_validator_empty, "validator_role_empty_field_invalid", "validator write id nonempty")

	var invalid_producer_empty := fixture.duplicate(true)
	(invalid_producer_empty.get("producer", {}) as Dictionary)["source_write_id"] = "producer-must-not-read"
	_expect_fixture_rejected(fixture_path, invalid_producer_empty, "producer_role_empty_field_invalid", "producer source write id nonempty")

	var digest_tamper := fixture.duplicate(true)
	(digest_tamper.get("validator", {}) as Dictionary)["restored_sections_digest"] = "tampered-generation-2".sha256_text()
	_expect(_write_fixture(fixture_path, digest_tamper), "digest-tamper fixture is writable")
	var rejected_digest := _invoke_orchestrator(fixture_path)
	var rejected_digest_result: Dictionary = rejected_digest.get("result", {}) if rejected_digest.get("result", {}) is Dictionary else {}
	_expect(
		int(rejected_digest.get("exit_code", 0)) != 0
			and str(rejected_digest_result.get("failure_code", "")) == "generation2_digest_mismatch",
		"generation-two digest tamper fails closed: %s" % JSON.stringify(rejected_digest)
	)
	_expect(_has_exact_fields(rejected_digest_result, SAFE_RESULT_FIELDS) and not bool(rejected_digest_result.get("success", true)), "digest rejection still emits only allowlisted safe JSON")

	var private_injection := fixture.duplicate(true)
	(private_injection.get("producer", {}) as Dictionary)["envelope"] = {"sections": {"ai": {"private": true}}}
	_expect(_write_fixture(fixture_path, private_injection), "private-injection fixture is writable")
	var rejected_private := _invoke_orchestrator(fixture_path)
	var rejected_private_result: Dictionary = rejected_private.get("result", {}) if rejected_private.get("result", {}) is Dictionary else {}
	_expect(
		int(rejected_private.get("exit_code", 0)) != 0
			and str(rejected_private_result.get("failure_code", "")) == "manifest_field_set_invalid",
		"unknown private manifest fields fail closed: %s" % JSON.stringify(rejected_private)
	)
	_expect(_has_exact_fields(rejected_private_result, SAFE_RESULT_FIELDS) and not JSON.stringify(rejected_private_result).contains("private"), "private-field rejection emits no private payload or raw evidence")

	DirAccess.remove_absolute(fixture_path)
	if _failures.is_empty():
		print("COLD_RESTORE_VERTICAL_SLICE_CONTRACT_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	push_error("Cold restore vertical-slice contract test failed:\n- " + "\n- ".join(_failures))
	quit(1)


func _valid_fixture() -> Dictionary:
	var head_sha := "cold-restore-v3-head".sha256_text()
	var generation1_digest := "cold-restore-generation-1".sha256_text()
	var generation2_digest := "cold-restore-generation-2".sha256_text()
	var generation1_fingerprint := "cold-restore-write-1".sha256_text()
	var generation2_fingerprint := "cold-restore-write-2".sha256_text()
	var queue_target_fingerprint := "cold-restore-queue-target-73".sha256_text()
	var producer := _base_manifest("producer", 101, head_sha)
	producer["saved_sections_digest"] = generation1_digest
	producer["write_id"] = "cold-restore-write-a"
	producer["write_fingerprint"] = generation1_fingerprint
	producer["preflight_count"] = 19
	producer["save_readback_green"] = true
	producer["save_fingerprint_parity"] = true
	producer["generation"] = 1
	producer["slot_state"] = "ready"
	producer["production_surface_ready"] = true
	producer["victory_unresolved_before_save"] = true
	producer["queue_entry_count"] = 1
	producer["queue_trigger_resolution_id"] = 73
	producer["queue_trigger_stable_target_fingerprint"] = queue_target_fingerprint
	producer["queue_target_pending_before_resume"] = 1
	producer["queue_target_pending_after_resume"] = 1

	var consumer := _base_manifest("consumer", 202, head_sha)
	consumer["source_sections_digest"] = generation1_digest
	consumer["restored_sections_digest"] = generation1_digest
	consumer["saved_sections_digest"] = generation2_digest
	consumer["source_write_id"] = "cold-restore-write-a"
	consumer["write_id"] = "cold-restore-write-b"
	consumer["source_write_fingerprint"] = generation1_fingerprint
	consumer["write_fingerprint"] = generation2_fingerprint
	consumer["preflight_count"] = 19
	consumer["owner_apply_count"] = 19
	consumer["registry_apply_count"] = 1
	consumer["registry_commit_count"] = 1
	consumer["registry_rebind_count"] = 1
	consumer["save_readback_green"] = true
	consumer["save_fingerprint_parity"] = true
	for field in [
		"world_fingerprint_match", "rng_cursor_match", "ai_state_fingerprint_match",
		"card_inventory_fingerprint_match", "queue_fingerprint_match",
	]:
		consumer[field] = true
	consumer["rng_draw_count_before"] = 41
	consumer["rng_draw_count_after"] = 41
	consumer["human_action_count"] = 2
	consumer["commodity_action_count"] = 1
	consumer["ai_action_count"] = 3
	consumer["sale_receipt_count"] = 1
	consumer["normal_card_count"] = 2
	consumer["commodity_card_count"] = 2
	consumer["commodity_claim_count"] = 1
	consumer["facility_count"] = 2
	consumer["route_count"] = 1
	consumer["military_unit_count"] = 1
	consumer["queue_entry_count"] = 0
	consumer["queue_trigger_resolution_id"] = 73
	consumer["queue_trigger_stable_target_fingerprint"] = queue_target_fingerprint
	consumer["queue_target_pending_before_resume"] = 1
	consumer["queue_target_pending_after_resume"] = 0
	consumer["queue_target_completed_after_resume"] = 1
	consumer["queue_target_history_after_resume"] = 1
	consumer["queue_target_execution_finalize_delta"] = 1
	consumer["queue_target_history_append_delta"] = 1
	consumer["weather_region_count"] = 1
	consumer["ai_nondefault_state_count"] = 1
	consumer["victory_unresolved_before_save"] = true
	consumer["production_surface_ready"] = true
	consumer["victory_state_sequence"] = ["idle", "qualification", "audit", "resolved"]
	consumer["final_settlement_count"] = 1
	consumer["final_settlement_presentation_count"] = 1
	consumer["final_settlement_public_log_count"] = 1
	consumer["terminal_quiescent_frames"] = 8
	consumer["generation"] = 2
	consumer["backup_created"] = true
	consumer["slot_state"] = "restored"

	var validator := _base_manifest("validator", 303, head_sha)
	validator["source_sections_digest"] = generation2_digest
	validator["restored_sections_digest"] = generation2_digest
	validator["source_write_id"] = "cold-restore-write-b"
	validator["source_write_fingerprint"] = generation2_fingerprint
	validator["preflight_count"] = 19
	validator["owner_apply_count"] = 19
	validator["registry_apply_count"] = 1
	validator["registry_commit_count"] = 1
	validator["registry_rebind_count"] = 1
	validator["save_readback_green"] = true
	validator["save_fingerprint_parity"] = true
	for field in [
		"world_fingerprint_match", "rng_cursor_match", "ai_state_fingerprint_match",
		"card_inventory_fingerprint_match", "queue_fingerprint_match",
	]:
		validator[field] = true
	validator["generation_2_recapture_fingerprint_match"] = true
	validator["generation_2_rng_cursor_match"] = true
	validator["generation_2_duplicate_transaction_count"] = 0
	validator["rng_draw_count_before"] = 52
	validator["rng_draw_count_after"] = 52
	validator["normal_card_count"] = 2
	validator["commodity_card_count"] = 2
	validator["commodity_claim_count"] = 1
	validator["facility_count"] = 2
	validator["route_count"] = 1
	validator["military_unit_count"] = 1
	validator["queue_entry_count"] = 0
	validator["queue_trigger_resolution_id"] = 73
	validator["queue_trigger_stable_target_fingerprint"] = queue_target_fingerprint
	validator["queue_target_completed_before_resume"] = 1
	validator["queue_target_completed_after_resume"] = 1
	validator["queue_target_history_before_resume"] = 1
	validator["queue_target_history_after_resume"] = 1
	validator["weather_region_count"] = 1
	validator["ai_nondefault_state_count"] = 1
	validator["victory_unresolved_before_save"] = true
	validator["production_surface_ready"] = true
	validator["victory_state_sequence"] = []
	validator["final_settlement_count"] = 0
	validator["final_settlement_presentation_count"] = 0
	validator["final_settlement_public_log_count"] = 0
	validator["terminal_quiescent_frames"] = 0
	validator["generation"] = 2
	validator["slot_state"] = "validated"
	return {"producer": producer, "consumer": consumer, "validator": validator}


func _base_manifest(role: String, process_id: int, head_sha: String) -> Dictionary:
	return {
		"schema_version": 4,
		"visibility_scope": "qa_allowlisted",
		"run_id": "run-42",
		"process_role": role,
		"process_id": process_id,
		"head_sha": head_sha,
		"scenario_fingerprint": "cold-restore-v3-scenario".sha256_text(),
		"slot_id": "current_run",
		"slot_state": "failed",
		"source_sections_digest": "",
		"restored_sections_digest": "",
		"saved_sections_digest": "",
		"source_write_id": "",
		"write_id": "",
		"source_write_fingerprint": "",
		"write_fingerprint": "",
		"section_count": 19,
		"preflight_count": 0,
		"owner_apply_count": 0,
		"registry_apply_count": 0,
		"registry_commit_count": 0,
		"registry_rebind_count": 0,
		"partial_restore_state_count": 0,
		"save_capture_world_delta": 0,
		"save_capture_rng_delta": 0,
		"save_capture_log_delta": 0,
		"rng_draw_count_before": 0,
		"rng_draw_count_after": 0,
		"restore_rng_draw_delta": 0,
		"restore_world_time_delta": 0,
		"restore_public_log_delta": 0,
		"restore_sale_receipt_delta": 0,
		"restore_economic_reward_delta": 0,
		"restore_ai_action_delta": 0,
		"restore_player_action_delta": 0,
		"restore_notification_delta": 0,
		"restore_private_feedback_delta": 0,
		"human_action_count": 0,
		"commodity_action_count": 0,
		"ai_action_count": 0,
		"sale_receipt_count": 0,
		"normal_card_count": 0,
		"commodity_card_count": 0,
		"commodity_claim_count": 0,
		"facility_count": 0,
		"route_count": 0,
		"military_unit_count": 0,
		"queue_entry_count": 0,
		"weather_region_count": 0,
		"ai_nondefault_state_count": 0,
		"queue_trigger_resolution_id": 0,
		"queue_trigger_stable_target_fingerprint": "",
		"queue_target_pending_before_resume": 0,
		"queue_target_pending_after_resume": 0,
		"queue_target_completed_before_resume": 0,
		"queue_target_completed_after_resume": 0,
		"queue_target_history_before_resume": 0,
		"queue_target_history_after_resume": 0,
		"queue_target_execution_finalize_delta": 0,
		"queue_target_history_append_delta": 0,
		"queue_target_history_duplicate_delta": 0,
		"queue_target_transition_duplicate_delta": 0,
		"queue_target_inventory_queue_commit_delta": 0,
		"queue_target_public_log_duplicate_delta": 0,
		"queue_target_public_log_collision_delta": 0,
		"duplicate_queue_entry_count": 0,
		"duplicate_facility_creation_count": 0,
		"duplicate_card_consumption_count": 0,
		"duplicate_cost_consumption_count": 0,
		"duplicate_sale_receipt_count": 0,
		"world_fingerprint_match": false,
		"rng_cursor_match": false,
		"ai_state_fingerprint_match": false,
		"card_inventory_fingerprint_match": false,
		"queue_fingerprint_match": false,
		"generation_2_recapture_fingerprint_match": false,
		"generation_2_rng_cursor_match": false,
		"generation_2_duplicate_transaction_count": 0,
		"victory_unresolved_before_save": false,
		"production_surface_ready": false,
		"victory_state_sequence": [],
		"final_settlement_count": 0,
		"final_settlement_presentation_count": 0,
		"final_settlement_public_log_count": 0,
		"terminal_quiescent_frames": 0,
		"terminal_world_delta": 0,
		"terminal_rng_draw_delta": 0,
		"generation": 0,
		"backup_created": false,
		"save_readback_green": false,
		"save_fingerprint_parity": false,
		"elapsed_ms": 10,
		"success": true,
		"failure_code": "",
	}


func _write_fixture(path: String, fixture: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(fixture))
	file.close()
	return true


func _expect_fixture_rejected(
	fixture_path: String,
	fixture: Dictionary,
	expected_failure_code: String,
	label: String
) -> void:
	_expect(_write_fixture(fixture_path, fixture), "%s fixture is writable" % label)
	var rejected := _invoke_orchestrator(fixture_path)
	var result: Dictionary = rejected.get("result", {}) if rejected.get("result", {}) is Dictionary else {}
	_expect(
		int(rejected.get("exit_code", 0)) != 0
			and str(result.get("failure_code", "")) == expected_failure_code,
		"%s fails closed with %s: exit=%s result=%s raw=%s" % [
			label,
			expected_failure_code,
			str(rejected.get("exit_code", "missing")),
			JSON.stringify(result),
			JSON.stringify(rejected.get("raw_output", [])),
		]
	)


func _invoke_orchestrator(fixture_path: String) -> Dictionary:
	var output: Array = []
	var project_path := ProjectSettings.globalize_path("res://").trim_suffix("/").trim_suffix("\\")
	var script_path := ProjectSettings.globalize_path(ORCHESTRATOR_PATH)
	var exit_code := OS.execute("pwsh", PackedStringArray([
		"-NoProfile",
		"-File",
		script_path,
		"-ProjectPath",
		project_path,
		"-RunId",
		"run-42",
		"-ContractManifestPath",
		fixture_path,
	]), output, true)
	var parsed: Dictionary = {}
	for chunk_variant: Variant in output:
		for line in str(chunk_variant).split("\n", false):
			var candidate := line.strip_edges()
			if not candidate.begins_with("{"):
				continue
			var value: Variant = JSON.parse_string(candidate)
			if value is Dictionary:
				parsed = value as Dictionary
	return {"exit_code": exit_code, "result": parsed, "raw_output": output}


func _invoke_driver_with_forged_boolean() -> Dictionary:
	var output: Array = []
	var project_path := ProjectSettings.globalize_path("res://").trim_suffix("/").trim_suffix("\\")
	var exit_code := OS.execute(OS.get_executable_path(), PackedStringArray([
		"--headless",
		"--path",
		project_path,
		"--script",
		DRIVER_PATH,
		"--",
		"--cold-restore-role=producer",
		"--cold-restore-run-id=forged-boolean",
		"--cold-restore-head-sha=%s" % "a".repeat(40),
		"--cold-restore-artifact-root=user://test_runs/alpha04c/forged-boolean/evidence",
		"--cold-restore-scenario-fingerprint=%s" % "b".repeat(64),
		"--cold-restore-official-count-consumed=true",
	]), output, true)
	return {"exit_code": exit_code, "output": "\n".join(output)}


func _has_exact_fields(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key_variant: Variant in value.keys():
		if not expected.has(str(key_variant)):
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
