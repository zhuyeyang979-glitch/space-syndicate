extends SceneTree

const ORCHESTRATOR_PATH := "res://scripts/tools/cold_restore_vertical_slice_orchestrator.ps1"
const DRIVER_PATH := "res://scripts/tools/cold_restore_vertical_slice_driver.gd"
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
	_expect(source.contains("$ORCHESTRATOR_SCHEMA_VERSION = 4") and source.contains('driver_id = "alpha04c_cold_restore_vertical_slice_orchestrator_v4"') and source.contains("$FORMAL_FULL_RUN = $false") and source.contains("$DriverExecutionReady = $false"), "orchestrator latches the non-Formal v4 contract closed after the official attempt")
	_expect(driver_source.contains("const SCHEMA_VERSION := 4") and driver_source.contains("const EXECUTION_READY := false") and driver_source.contains('"driver_id": "alpha04c_cold_restore_vertical_slice_v4"'), "driver and orchestrator share one closed post-attempt v4 contract")
	_expect(driver_source.contains("--cold-restore-expected-queue-resolution-id=") and driver_source.contains("--cold-restore-expected-queue-stable-target-fingerprint=") and driver_source.contains("--cold-restore-official-claim-path=") and driver_source.contains("--cold-restore-launch-attestation-path=") and driver_source.contains("--cold-restore-launch-nonce=") and driver_source.contains('"unknown_option"') and driver_source.contains('"duplicate_option"'), "driver accepts only the closed expected-identity and launch-attestation option surface")
	_expect(driver_source.contains("await _authorize_official_launch(validation") and driver_source.find("await _authorize_official_launch(validation") < driver_source.find("await _run_role(validation") and driver_source.contains('"official_claim_path_mismatch"') and driver_source.contains('"launch_attestation_binding_invalid"'), "driver requires the fixed ledger and PID-bound launch attestation before any role")
	_expect(not driver_source.contains(".tick_ai(") and not driver_source.contains("_tick_ai_until_nontrivial_queue") and driver_source.contains("AUTHORITATIVE_STEPPER.advance_bounded") and driver_source.contains("TERMINAL_EVIDENCE.acquire_manual_lease"), "all AI progress uses the bounded authoritative RuntimeLoop lease with no direct tick fallback")
	_expect(driver_source.contains("consumer_restored_queue_target_identity_invalid") and driver_source.contains("consumer_queue_target_exact_once_invalid") and driver_source.contains("validator_queue_target_lineage_invalid"), "driver validates A identity in B before continuation and proves completed Generation-2 lineage in C")
	_expect(source.contains('[ValidateSet("producer", "consumer", "validator")]') and source.contains('$RoleSequence = @("producer", "consumer", "validator")'), "v3 contract has three closed process roles")
	_expect(source.contains('"worktree_not_clean"') and source.contains('"git_status_unavailable"') and source.contains("$statusExitCode = $LASTEXITCODE") and source.contains("-Environment @{ APPDATA = $IsolatedAppData; LOCALAPPDATA = $IsolatedLocalAppData }"), "official execution checks git status exit and clean sources while isolating player data")
	_expect(source.contains("-PassThru -WindowStyle Hidden") and source.contains("$roleStopwatch = [System.Diagnostics.Stopwatch]::StartNew()") and source.contains("$ownership.engine_process.WaitForExit([int]$remainingTimeoutMilliseconds)") and source.contains("$ownership.wrapper_process.WaitForExit([int]$remainingTimeoutMilliseconds)"), "every Godot role uses one total timeout across engine and wrapper")
	_expect(source.contains("-RedirectStandardOutput") and source.contains("-RedirectStandardError") and source.contains("Invoke-ColdRestoreExecutionPreflight $ProjectPath $GodotPath"), "every role redirects output after one exact pre-claim executable preflight")
	var ownership_function_index := source.find("function Resolve-ColdRestoreOwnedProcessTree")
	var ownership_function_end_index := source.find("function Test-ColdRestoreProcessRecordCurrent")
	var cleanup_function_index := source.find("function Stop-ColdRestoreOwnedProcessTree")
	var cleanup_function_end_index := source.find("function Stop-ColdRestoreLaunchedProcessTree")
	var claim_function_index := source.find("function New-OfficialClaimLedger")
	var claim_function_end_index := source.find("function Resolve-ColdRestoreExecutablePath")
	var claim_call_index := source.find("$officialClaimLedgerPath = New-OfficialClaimLedger")
	var readiness_index := source.find('Assert-ColdRestoreCondition $DriverExecutionReady "driver_execution_not_ready"')
	var preflight_call_index := source.find("$executionPreflight = Invoke-ColdRestoreExecutionPreflight")
	var producer_index := source.find('Invoke-ColdRestoreRole "producer"')
	var consumer_index := source.find('Invoke-ColdRestoreRole "consumer"')
	var validator_index := source.find('Invoke-ColdRestoreRole "validator"')
	var ownership_block := source.substr(ownership_function_index, ownership_function_end_index - ownership_function_index) if ownership_function_index >= 0 and ownership_function_end_index > ownership_function_index else ""
	var cleanup_block := source.substr(cleanup_function_index, cleanup_function_end_index - cleanup_function_index) if cleanup_function_index >= 0 and cleanup_function_end_index > cleanup_function_index else ""
	var claim_block := source.substr(claim_function_index, claim_function_end_index - claim_function_index) if claim_function_index >= 0 and claim_function_end_index > claim_function_index else ""
	_expect(source.contains("function Test-ColdRestoreCommandLineBinding") and source.contains("$CommandLine.Substring($executablePrefix.Length)") and source.contains("$ExpectedArgumentLine") and source.contains("[System.StringComparison]::Ordinal"), "process ownership requires the exact complete command-line argument string")
	_expect(ownership_block.contains("[int64]$wrapperRecord.parent_process_id -eq [int64]$PID") and ownership_block.contains("Get-ColdRestoreChildProcessRecords ([int64]$Wrapper.Id)") and ownership_block.contains("Test-ColdRestoreProcessRecordBinding $_ ([int64]$Wrapper.Id)"), "wrapper and engine ownership are bound to the exact PowerShell parent and wrapper child")
	_expect(source.contains("creation_time_utc_ticks") and source.contains("$current.creation_time_utc_ticks -eq [int64]$Record.creation_time_utc_ticks"), "cleanup revalidates creation time before acting on a PID")
	_expect(cleanup_block.contains("foreach ($entry in $records)") and cleanup_block.contains("Continue so one failed leg cannot prevent cleanup of the other owned process") and source.contains("Stop-ColdRestoreLaunchedProcessTree"), "timeout cleanup attempts every captured engine and wrapper leg")
	_expect(source.contains("$boundProcess.StartTime.ToUniversalTime().Ticks") and source.contains("$boundProcess.Kill()") and source.contains('"task_owned_process_cleanup_failed"') and source.contains('"task_owned_process_residual"') and not source.contains("Stop-Process -Name"), "cleanup kills only a creation-time-revalidated process handle and rejects residual task processes")
	_expect(source.contains("function Invoke-ColdRestoreCleanupContractProbe") and source.find("if ($ContractCleanupProbe)") < claim_call_index, "behavioral cleanup probe is isolated before the official claim boundary")
	_expect(source.contains("[System.IO.FileMode]::CreateNew") and source.contains("[System.IO.FileShare]::None"), "official authorization is claimed atomically with exclusive .NET CreateNew semantics")
	_expect(source.contains('throw "official_claim_already_exists"') and source.contains("[System.IO.File]::Exists($ledgerPath)"), "an existing ledger rejects a second official claim regardless of its prior outcome")
	_expect(source.contains('$OfficialClaimRelativeDirectory = "codex\\cold_restore_v3\\official-alpha04c-depth1-seed900626424"') and source.contains('$OfficialClaimLedgerFileName = "official_claim_ledger.json"'), "one fixed task claim path prevents RunId changes from minting another authorization")
	_expect(source.contains("function Resolve-OfficialClaimDirectory") and source.contains("rev-parse --path-format=absolute --git-common-dir") and source.contains("$officialClaimDirectory = Resolve-OfficialClaimDirectory $resolvedProjectPath"), "all linked worktrees share the one official ledger under git common-dir")
	_expect(not source.contains("$OfficialEvidenceRelativeDirectory") and not source.contains("Remove-Item") and not source.contains("[System.IO.File]::Delete"), "the orchestrator neither uses a per-worktree official path nor deletes or rolls back the one-shot ledger")
	for claim_field in [
		"schema_version",
		"authorization_id",
		"created_at_utc",
		"source_head_sha",
		"challenge_depth",
		"seed",
		"status",
		"claim_nonce",
		"orchestrator_process_id",
		"orchestrator_creation_time_utc_ticks",
	]:
		_expect(claim_block.contains("%s =" % claim_field) and source.contains('"%s"' % claim_field), "official claim includes only the closed field %s" % claim_field)
	_expect(claim_block.contains('status = "claimed"') and claim_block.contains("challenge_depth = $OfficialChallengeDepth") and claim_block.contains("seed = $OfficialSeed"), "claim binds the frozen depth-one seed and claimed status")
	_expect(not claim_block.contains("player_state") and not claim_block.contains("card_record") and not claim_block.contains("save_payload") and not claim_block.contains("gate_cache"), "claim JSON contains no gameplay state and no gate-cache substitute")
	_expect(readiness_index >= 0 and readiness_index < preflight_call_index and preflight_call_index < claim_call_index and claim_call_index < producer_index, "readiness and the complete environment preflight precede the one claim, which precedes Process A")
	var preflight_function_index := source.find("function Invoke-ColdRestoreExecutionPreflight")
	var preflight_function_end_index := source.find("function Resolve-ColdRestoreOwnedProcessTree")
	var preflight_block := source.substr(preflight_function_index, preflight_function_end_index - preflight_function_index) if preflight_function_index >= 0 and preflight_function_end_index > preflight_function_index else ""
	_expect(preflight_block.contains("Resolve-ColdRestoreExecutablePath $RequestedGodotPath") and preflight_block.contains("godot_engine_executable_unavailable") and preflight_block.contains("process_launch_environment_unsupported") and preflight_block.contains("Get-CimInstance") and preflight_block.contains("$headExitCode = $LASTEXITCODE") and preflight_block.contains("$statusExitCode = $LASTEXITCODE") and preflight_block.contains("Invoke-ColdRestoreDriverContractPreflight") and preflight_block.contains("Resolve-OfficialClaimDirectory"), "Godot contract launch, CIM, process environment, git exits, directories, and common ledger path are all preflighted before claim")
	_expect(source.find("if ($ContractManifestPath -ne \"\")") < claim_call_index and source.find("if (-not $EnableColdRestoreExecution)") < claim_call_index and source.contains("Check-only and non-official qualification callers exit before the official claim boundary"), "contract, check-only, and qualification modes cannot create the official claim")
	_expect(producer_index >= 0 and producer_index < consumer_index and consumer_index < validator_index, "producer, consumer, and validator launch sequentially")
	_expect(source.contains("rev-parse HEAD") and source.contains("--cold-restore-head-sha=$HeadSha"), "one repository HEAD attestation is passed to all three roles")
	_expect(source.contains("[int64]$manifest.process_id -eq [int64]$ownership.engine_process_id") and source.contains("manifest.process_creation_time_utc_ticks") and source.contains("manifest.wrapper_creation_time_utc_ticks") and source.contains("manifest.launch_nonce") and source.contains("manifest.official_claim_fingerprint") and source.contains("[string]$manifest.head_sha -eq $HeadSha"), "each runtime manifest binds engine, wrapper, creation times, launch nonce, claim, and repository HEAD")
	_expect(source.contains("wrapper_process_id = [int64]$ownership.wrapper_process_id") and source.contains("engine_process_id = [int64]$ownership.engine_process_id") and not source.contains("process_id = $process.Id"), "role results preserve distinct wrapper and engine PID fields")
	_expect(source.contains("--cold-restore-expected-queue-resolution-id=$ExpectedQueueResolutionId") and source.contains("--cold-restore-expected-queue-stable-target-fingerprint=$ExpectedQueueStableTargetFingerprint"), "A's closed queue identity is passed explicitly into B and B's verified identity is passed into C")
	_expect(source.contains("$producerRun.manifest.queue_trigger_resolution_id") and source.contains("$producerRun.manifest.queue_trigger_stable_target_fingerprint") and source.contains("$consumerRun.manifest.queue_trigger_resolution_id") and source.contains("$consumerRun.manifest.queue_trigger_stable_target_fingerprint"), "the sequential launcher sources B's expectation from A and C's expectation from B")
	_expect(source.contains('$ManifestPrefix = "COLD_RESTORE_MANIFEST|"') and source.contains("manifest_marker_count_invalid") and source.contains("manifest_field_set_invalid"), "stdout parser accepts exactly one closed manifest marker")
	_expect(source.contains("$generation1Digest -eq [string]$Consumer.source_sections_digest") and source.contains("$generation1Digest -eq [string]$Consumer.restored_sections_digest"), "generation one compares A saved against B source and restored digests")
	_expect(source.contains("$generation2Digest -eq [string]$Validator.source_sections_digest") and source.contains("$generation2Digest -eq [string]$Validator.restored_sections_digest"), "generation two compares B saved against C source and restored digests")
	_expect(source.contains("write_id_rotation_invalid") and source.contains("write_fingerprint_rotation_invalid") and source.contains("write_chain_mismatch"), "v3 comparison rotates writes while preserving both source chains")
	for required_field in [
		"parent_process_id",
		"process_creation_time_utc_ticks",
		"wrapper_process_id",
		"wrapper_parent_process_id",
		"wrapper_creation_time_utc_ticks",
		"orchestrator_process_id",
		"orchestrator_creation_time_utc_ticks",
		"launch_nonce",
		"official_claim_fingerprint",
		"restore_rng_draw_delta",
		"restore_world_time_delta",
		"restore_public_log_delta",
		"restore_sale_receipt_delta",
		"restore_economic_reward_delta",
		"restore_ai_action_delta",
		"restore_player_action_delta",
		"restore_notification_delta",
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
		_expect(source.contains('"%s"' % required_field), "v3 manifest includes %s" % required_field)
	_expect(source.contains("validator_action_count_nonzero") and source.contains("producer_queue_target_state_invalid") and source.contains("preterminal_victory_state_invalid"), "role-specific action, pending-queue, and preterminal invariants fail closed")
	_expect(source.contains("consumer_queue_target_exact_once_invalid") and source.contains("consumer_queue_target_duplicate_side_effect") and source.contains("validator_queue_target_lineage_invalid"), "target resolution must restore pending once, complete once, persist in Generation 2, and produce no replay side effects")
	_expect(source.contains("final_settlement_exact_once_invalid") and source.contains("terminal_quiescent_frames -eq 8") and source.contains("terminal_quiet_delta_nonzero"), "settlement is exact-once and followed by eight zero-delta quiet frames")

	var ledger_path := _official_ledger_path()
	_expect(not ledger_path.is_empty(), "fixed shared official ledger path resolves without creating it")
	var ledger_before := _file_snapshot(ledger_path)
	var nonofficial_execution := _invoke_nonofficial_orchestrator()
	var nonofficial_result: Dictionary = nonofficial_execution.get("result", {}) if nonofficial_execution.get("result", {}) is Dictionary else {}
	_expect(int(nonofficial_execution.get("exit_code", -1)) == 0 and bool(nonofficial_result.get("success", false)) and not bool(nonofficial_result.get("execution_ready", true)) and not bool(nonofficial_result.get("executed", true)), "real non-official check-only request exits before preflight and claim while reporting the post-attempt safety latch")
	var cleanup_probe := _invoke_cleanup_probe()
	var cleanup_result: Dictionary = cleanup_probe.get("result", {}) if cleanup_probe.get("result", {}) is Dictionary else {}
	_expect(int(cleanup_probe.get("exit_code", -1)) == 0 and bool(cleanup_result.get("success", false)) and bool(cleanup_result.get("wrapper_cleanup_continued", false)) and bool(cleanup_result.get("residual_failure_reported", false)) and int(cleanup_result.get("final_owned_process_count", -1)) == 0, "real cleanup probe continues to wrapper after an engine-leg failure, reports the residual, and leaves zero owned processes: %s" % JSON.stringify(cleanup_probe))
	var direct_driver := _invoke_driver_without_attestation()
	_expect(int(direct_driver.get("exit_code", 0)) != 0 and not str(direct_driver.get("raw_output", "")).contains("COLD_RESTORE_MANIFEST|"), "direct role invocation cannot emit a manifest without orchestrator authorization")
	var ledger_after := _file_snapshot(ledger_path)
	_expect(ledger_before == ledger_after, "behavior-level negative probes neither create nor mutate the one-shot official ledger")

	var fixture := _valid_fixture()
	var fixture_path := ProjectSettings.globalize_path("user://cold_restore_orchestrator_v3_contract.json")
	_expect(_write_fixture(fixture_path, fixture), "synthetic safe manifest fixture is writable")
	var accepted := _invoke_orchestrator(fixture_path)
	var accepted_result: Dictionary = accepted.get("result", {}) if accepted.get("result", {}) is Dictionary else {}
	_expect(int(accepted.get("exit_code", -1)) == 0 and bool(accepted_result.get("success", false)), "synthetic three-process manifest chain passes the real PowerShell comparator")
	_expect(_has_exact_fields(accepted_result, SAFE_RESULT_FIELDS) and bool(accepted_result.get("process_ids_distinct", false)) and bool(accepted_result.get("head_sha_match", false)), "successful output uses one closed safe result allowlist")
	_expect(bool(accepted_result.get("generation1_digest_match", false)) and bool(accepted_result.get("generation2_digest_match", false)) and bool(accepted_result.get("write_chain_match", false)), "synthetic comparator proves both digest generations and write lineage")
	_expect(bool(accepted_result.get("queue_target_identity_match", false)) and bool(accepted_result.get("pending_queue_exact_once", false)), "synthetic comparator proves one named A resolution restores, drains once in B, and remains completed in C")
	_expect(bool(accepted_result.get("save_capture_deltas_zero", false)) and bool(accepted_result.get("restore_deltas_zero", false)) and bool(accepted_result.get("action_counts_positive", false)), "synthetic comparator proves save/restore silence and continued actions")
	_expect(bool(accepted_result.get("final_settlement_exact_once", false)) and int(accepted_result.get("terminal_quiescent_frames", 0)) == 8 and bool(accepted_result.get("terminal_quiet", false)), "synthetic comparator proves one settlement and eight quiet frames")
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
	_expect_fixture_rejected(fixture_path, resolved_validator_before_save, "preterminal_victory_state_invalid", "validator preterminal state resolved")

	var invalid_validator_terminal := fixture.duplicate(true)
	(invalid_validator_terminal.get("validator", {}) as Dictionary)["final_settlement_count"] = 0
	_expect_fixture_rejected(fixture_path, invalid_validator_terminal, "final_settlement_exact_once_invalid", "validator settlement count zero")

	var invalid_validator_victory_sequence := fixture.duplicate(true)
	(invalid_validator_victory_sequence.get("validator", {}) as Dictionary)["victory_state_sequence"] = ["idle", "qualification", "resolved"]
	_expect_fixture_rejected(fixture_path, invalid_validator_victory_sequence, "victory_sequence_mismatch", "validator victory sequence skips audit")

	var invalid_validator_quiet := fixture.duplicate(true)
	(invalid_validator_quiet.get("validator", {}) as Dictionary)["terminal_quiescent_frames"] = 7
	_expect_fixture_rejected(fixture_path, invalid_validator_quiet, "terminal_quiescent_frames_invalid", "validator quiet frame count short")

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
	_expect(int(rejected_digest.get("exit_code", 0)) != 0 and str(rejected_digest_result.get("failure_code", "")) == "generation2_digest_mismatch", "generation-two digest tamper fails closed")
	_expect(_has_exact_fields(rejected_digest_result, SAFE_RESULT_FIELDS) and not bool(rejected_digest_result.get("success", true)), "digest rejection still emits only allowlisted safe JSON")

	var private_injection := fixture.duplicate(true)
	(private_injection.get("producer", {}) as Dictionary)["envelope"] = {"sections": {"ai": {"private": true}}}
	_expect(_write_fixture(fixture_path, private_injection), "private-injection fixture is writable")
	var rejected_private := _invoke_orchestrator(fixture_path)
	var rejected_private_result: Dictionary = rejected_private.get("result", {}) if rejected_private.get("result", {}) is Dictionary else {}
	_expect(int(rejected_private.get("exit_code", 0)) != 0 and str(rejected_private_result.get("failure_code", "")) == "manifest_field_set_invalid", "unknown private manifest fields fail closed")
	_expect(_has_exact_fields(rejected_private_result, SAFE_RESULT_FIELDS) and not JSON.stringify(rejected_private_result).contains("private"), "private-field rejection emits no private payload or raw evidence")

	var invalid_launch_nonce := fixture.duplicate(true)
	(invalid_launch_nonce.get("producer", {}) as Dictionary)["launch_nonce"] = "caller-forged"
	_expect_fixture_rejected(fixture_path, invalid_launch_nonce, "manifest_launch_nonce_invalid", "invalid launch nonce")

	var invalid_engine_parent := fixture.duplicate(true)
	(invalid_engine_parent.get("producer", {}) as Dictionary)["parent_process_id"] = 777
	_expect_fixture_rejected(fixture_path, invalid_engine_parent, "manifest_engine_parent_invalid", "engine parent detached from wrapper")

	var mismatched_claim_attestation := fixture.duplicate(true)
	(mismatched_claim_attestation.get("consumer", {}) as Dictionary)["official_claim_fingerprint"] = "different-official-claim".sha256_text()
	_expect_fixture_rejected(fixture_path, mismatched_claim_attestation, "launch_attestation_chain_mismatch", "role bound to a different official claim")

	var replayed_launch_nonce := fixture.duplicate(true)
	(replayed_launch_nonce.get("consumer", {}) as Dictionary)["launch_nonce"] = str((replayed_launch_nonce.get("producer", {}) as Dictionary).get("launch_nonce", ""))
	_expect_fixture_rejected(fixture_path, replayed_launch_nonce, "launch_nonce_reuse", "role launch nonce replay")

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
	validator["victory_state_sequence"] = ["idle", "qualification", "audit", "resolved"]
	validator["final_settlement_count"] = 1
	validator["final_settlement_presentation_count"] = 1
	validator["final_settlement_public_log_count"] = 1
	validator["terminal_quiescent_frames"] = 8
	validator["generation"] = 2
	validator["slot_state"] = "validated"
	return {"producer": producer, "consumer": consumer, "validator": validator}


func _base_manifest(role: String, process_id: int, head_sha: String) -> Dictionary:
	var orchestrator_process_id := 9001
	var wrapper_process_id := process_id + 1000
	return {
		"schema_version": 4,
		"visibility_scope": "qa_allowlisted",
		"run_id": "run-42",
		"process_role": role,
		"process_id": process_id,
		"parent_process_id": wrapper_process_id,
		"process_creation_time_utc_ticks": str(638500000000000000 + process_id),
		"wrapper_process_id": wrapper_process_id,
		"wrapper_parent_process_id": orchestrator_process_id,
		"wrapper_creation_time_utc_ticks": str(638400000000000000 + process_id),
		"orchestrator_process_id": orchestrator_process_id,
		"orchestrator_creation_time_utc_ticks": "638300000000009001",
		"launch_nonce": ("launch-%s-%d" % [role, process_id]).sha256_text().left(32),
		"official_claim_fingerprint": "official-claim-fixture".sha256_text(),
		"head_sha": head_sha,
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
		"%s fails closed with %s" % [label, expected_failure_code]
	)


func _official_ledger_path() -> String:
	var output: Array = []
	var project_path := ProjectSettings.globalize_path("res://").trim_suffix("/").trim_suffix("\\")
	var exit_code := OS.execute("git", PackedStringArray([
		"-C",
		project_path,
		"rev-parse",
		"--path-format=absolute",
		"--git-common-dir",
	]), output, true)
	if exit_code != 0 or output.is_empty():
		return ""
	var common_dir := str(output[0]).strip_edges()
	if common_dir.is_empty():
		return ""
	if not common_dir.is_absolute_path():
		common_dir = project_path.path_join(common_dir)
	return common_dir.replace("\\", "/").simplify_path().path_join(
		"codex/cold_restore_v3/official-alpha04c-depth1-seed900626424/official_claim_ledger.json"
	)


func _file_snapshot(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {"exists": false, "fingerprint": ""}
	return {
		"exists": true,
		"fingerprint": FileAccess.get_file_as_string(path).sha256_text(),
	}


func _invoke_nonofficial_orchestrator() -> Dictionary:
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
		"qualified-nonofficial-probe",
	]), output, true)
	return {
		"exit_code": exit_code,
		"result": _parse_safe_json_output(output),
		"raw_output": "\n".join(PackedStringArray(output)),
	}


func _invoke_driver_without_attestation() -> Dictionary:
	var output: Array = []
	var project_path := ProjectSettings.globalize_path("res://").trim_suffix("/").trim_suffix("\\")
	var driver_path := ProjectSettings.globalize_path(DRIVER_PATH)
	var run_id := "direct-bypass-probe"
	var exit_code := OS.execute(OS.get_executable_path(), PackedStringArray([
		"--headless",
		"--path",
		project_path,
		"--script",
		driver_path,
		"--",
		"--cold-restore-role=producer",
		"--cold-restore-run-id=%s" % run_id,
		"--cold-restore-head-sha=%s" % "direct-driver-head".sha256_text(),
		"--cold-restore-artifact-root=user://test_runs/alpha04c/%s/evidence" % run_id,
	]), output, true)
	return {
		"exit_code": exit_code,
		"raw_output": "\n".join(PackedStringArray(output)),
	}


func _invoke_cleanup_probe() -> Dictionary:
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
		"cleanup-contract-probe",
		"-ContractCleanupProbe",
	]), output, true)
	return {
		"exit_code": exit_code,
		"result": _parse_safe_json_output(output),
		"raw_output": "\n".join(PackedStringArray(output)),
	}


func _parse_safe_json_output(output: Array) -> Dictionary:
	var parsed: Dictionary = {}
	for chunk_variant: Variant in output:
		for line in str(chunk_variant).split("\n", false):
			var candidate := line.strip_edges()
			if not candidate.begins_with("{"):
				continue
			var value: Variant = JSON.parse_string(candidate)
			if value is Dictionary:
				parsed = value as Dictionary
	return parsed


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
	var parsed := _parse_safe_json_output(output)
	return {"exit_code": exit_code, "result": parsed, "raw_output": output}


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
