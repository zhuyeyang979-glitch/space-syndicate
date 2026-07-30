extends SceneTree

const ORCHESTRATOR_PATH := "res://scripts/tools/cold_restore_vertical_slice_orchestrator.ps1"
const DRIVER_PATH := "res://scripts/tools/cold_restore_vertical_slice_driver.gd"
const ATTESTED_PROCESS_PATH := "res://scripts/tools/cold_restore_attested_process.psm1"
const CHILD_ATTESTATION_PATH := "res://scripts/tools/cold_restore_child_completion_attestation.gd"
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
	var wrapper_source := FileAccess.get_file_as_string(ATTESTED_PROCESS_PATH)
	var child_attestation_source := FileAccess.get_file_as_string(CHILD_ATTESTATION_PATH)
	_expect(source.contains("$ORCHESTRATOR_SCHEMA_VERSION = 3") and source.contains("$FORMAL_FULL_RUN = $false") and source.contains("$DriverExecutionReady = $true"), "orchestrator exposes a non-Formal v3 role contract behind explicit qualification and official authorization gates")
	_expect(driver_source.contains("const SCHEMA_VERSION := 3") and driver_source.contains("const EXECUTION_READY := true") and driver_source.contains('"driver_id": "alpha04c_cold_restore_vertical_slice_v3"'), "driver and orchestrator share one executable Harness-only v3 contract")
	_expect(driver_source.contains("--cold-restore-expected-queue-resolution-id=") and driver_source.contains("--cold-restore-expected-queue-stable-target-fingerprint=") and driver_source.contains("--cold-restore-scenario-fingerprint=") and driver_source.contains("--cold-restore-official-claim-path=") and driver_source.contains("--cold-restore-launch-attestation-path=") and driver_source.contains("--cold-restore-launch-nonce=") and driver_source.contains('"unknown_option"') and driver_source.contains('"duplicate_option"'), "driver accepts only the closed expected-identity and attested authorization option surface")
	_expect(not driver_source.contains("--cold-restore-official-count-consumed=") and driver_source.contains("caller_boolean_authorization_accepted\": false"), "direct driver invocation cannot forge official authorization with a caller boolean")
	_expect(driver_source.contains("official-alpha04c-depth1-seed900626424/official_claim_ledger.json") and driver_source.contains("_resolve_git_common_dir") and driver_source.contains("_authorize_official_launch") and driver_source.contains("OS.get_process_id()"), "driver requires the fixed cross-worktree claim and a launch attestation bound to the actual engine PID")
	_expect(source.contains("$OfficialClaimRelativePath = \"codex\\cold_restore_v3\\official-alpha04c-depth1-seed900626424\\official_claim_ledger.json\"") and source.contains("Resolve-ColdRestoreGitCommonDirectory") and source.contains("Write-ColdRestoreExclusiveJson"), "orchestrator consumes one RunId-independent claim below the Git common directory")
	_expect(not source.contains('Join-Path $paths.root "official_ledger.json"') and source.contains("Invoke-ColdRestoreNonOfficialProcessA") and source.contains("official_cold_restore_vertical_slice = $false"), "non-official Process A uses no RunId-selected official authorization ledger")
	_expect(wrapper_source.contains("[IO.FileMode]::CreateNew") and wrapper_source.contains("Write-ColdRestoreExclusiveJson") and wrapper_source.contains("Write-ColdRestoreLaunchAttestation"), "the claim final path is created exclusively and each child receives a PID-bound launch attestation")
	var claim_call_index := source.rfind("Assert-AndConsumeOfficialColdRestoreAuthorization $resolvedProjectPath $headSha")
	_expect(source.find('if ($ContractManifestPath -ne "")') < claim_call_index and source.find("if (-not $QualificationProbe -and -not $NonOfficialProcessA -and -not $EnableColdRestoreExecution)") < claim_call_index and source.find("if ($QualificationProbe)") < claim_call_index and source.find("if ($NonOfficialProcessA)") < claim_call_index, "contract fixture, default check-only, qualification, and non-official Process A all exit before the fixed claim boundary")
	_expect(driver_source.contains("cold_restore_process_a_phase_timeline.gd") and driver_source.contains("allowlisted_manifest_complete") and driver_source.contains("child_completion_attestation_complete") and wrapper_source.contains("Sync-ColdRestoreProcessAPhaseTimeline"), "Process A emits a parent-synchronized nineteen-phase timeline without treating progress as completion")
	var forged_boolean := _invoke_driver_with_forged_boolean()
	_expect(int(forged_boolean.get("exit_code", 0)) != 0 and str(forged_boolean.get("output", "")).contains("unknown_option"), "the retired official-count boolean is rejected before runtime or Save access")
	_expect(not driver_source.contains(".tick_ai(") and not driver_source.contains("_tick_ai_until_nontrivial_queue") and driver_source.contains("AUTHORITATIVE_STEPPER.advance_bounded") and driver_source.contains("TERMINAL_EVIDENCE.acquire_manual_lease"), "all AI progress uses the bounded authoritative RuntimeLoop lease with no direct tick fallback")
	_expect(driver_source.contains("consumer_restored_queue_target_identity_invalid") and driver_source.contains("consumer_queue_target_exact_once_invalid") and driver_source.contains("validator_queue_target_lineage_invalid"), "driver validates A identity in B before continuation and proves completed Generation-2 lineage in C")
	_expect(source.contains('[ValidateSet("producer", "consumer", "validator")]') and source.contains('$RoleSequence = @("producer", "consumer", "validator")'), "v3 contract has three closed process roles")
	_expect(source.contains('"worktree_not_clean"') and source.contains("-EnvironmentVariables @{ APPDATA = $IsolatedAppData; LOCALAPPDATA = $IsolatedLocalAppData }"), "official execution rejects dirty sources and isolates the shared production slot from player data")
	_expect(wrapper_source.contains("ProcessStartInfo") and wrapper_source.contains("ArgumentList.Add") and wrapper_source.contains("WaitForExit") and wrapper_source.contains("ReadToEndAsync"), "every child uses one quoted-argument-safe bounded process wrapper with explicit stream completion")
	_expect(wrapper_source.contains("stdout_sha256") and wrapper_source.contains("stderr_sha256") and wrapper_source.contains("task_owned_process_count_after") and wrapper_source.contains("ParentExitFields"), "the parent records log hashes, child validation, and process-tree cleanup")
	_expect(child_attestation_source.contains("child_attestation_readback_failed") and child_attestation_source.contains("DirAccess.rename_absolute") and child_attestation_source.contains("evidence_fingerprint"), "child completion uses temp write, readback, fingerprint, and atomic install before quit")
	var producer_index := source.find('Invoke-ColdRestoreRole "producer"')
	var consumer_index := source.find('Invoke-ColdRestoreRole "consumer"')
	var validator_index := source.find('Invoke-ColdRestoreRole "validator"')
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
	return {
		"schema_version": 3,
		"visibility_scope": "qa_allowlisted",
		"run_id": "run-42",
		"process_role": role,
		"process_id": process_id,
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
