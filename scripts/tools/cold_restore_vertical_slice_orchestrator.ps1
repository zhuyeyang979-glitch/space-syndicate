[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,
    [string]$GodotPath = "godot",
    [string]$RunId = "alpha04c-cold-restore",
    [switch]$QualificationProbe,
    [switch]$TargetedOwnerCaptureDiagnostic,
    [switch]$NonOfficialProcessA,
    [ValidateSet("diagnostic", "rehearsal")][string]$NonOfficialProcessAKind = "diagnostic",
    [switch]$TopLevelImportChainPreflightOnly,
    [switch]$OfficialAttempt2PreflightOnly,
    [switch]$EnableColdRestoreExecution,
    [string]$ContractManifestPath = "",
    [string]$RoleTimeoutPolicyPath = "",
    [ValidateRange(0, 1)][int]$AuthorizedOfficialColdRestoreCount = 0,
    [string]$ExpectedScenarioFingerprint = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ColdRestoreModuleLoader = Import-Module `
    (Join-Path $PSScriptRoot "cold_restore_module_loader.psm1") `
    -PassThru `
    -ErrorAction Stop
$ColdRestoreAuthorizationModule = cold_restore_module_loader\Import-ColdRestoreModuleOnce `
    -Path (Join-Path $PSScriptRoot "cold_restore_authorization_contract_v1.psm1") `
    -RequiredCommands @(
        "Get-ColdRestoreAuthorizationContract",
        "Get-ColdRestoreAuthorizationContractPath",
        "Get-ColdRestoreAuthorizationEntry",
        "Get-ColdRestoreAuthorizationRunId",
        "Get-ColdRestoreCurrentTargetedDiagnosticAuthorizationName",
        "Get-ColdRestorePreviousTargetedDiagnosticAuthorizationName",
        "Get-ColdRestoreTargetedDiagnosticAuthorizationBinding"
    )
$ColdRestorePreQuotaModule = cold_restore_module_loader\Import-ColdRestoreModuleOnce `
    -Path (Join-Path $PSScriptRoot "cold_restore_prequota_bootstrap.psm1") `
    -RequiredCommands @(
        "Assert-ColdRestorePreQuotaContextParameters",
        "New-ColdRestoreTargetedDiagnosticPreQuotaContext",
        "New-ColdRestoreTargetedDiagnosticUserArgumentList",
        "Publish-ColdRestoreCurrentTargetedQuotaLedger",
        "Update-ColdRestorePreQuotaAttestation"
    )
$ColdRestoreTargetedLedgerBindingModule = cold_restore_module_loader\Import-ColdRestoreModuleOnce `
    -Path (Join-Path $PSScriptRoot "cold_restore_targeted_ledger_binding_contract_v1.psm1") `
    -RequiredCommands @(
        "Get-ColdRestoreTargetedLedgerBindingContract",
        "Get-ColdRestoreTargetedLedgerBindingContractPath"
    )
$ColdRestoreAttestedProcessModulePath = `
    Join-Path $PSScriptRoot "cold_restore_attested_process.psm1"
$ColdRestoreAttestedProcessModuleBeforeAdmission = `
    cold_restore_module_loader\Get-ColdRestoreLoadedModuleByPath `
        $ColdRestoreAttestedProcessModulePath
if ($null -eq $ColdRestoreAttestedProcessModuleBeforeAdmission) {
    throw "cold_restore_attested_process_not_loaded_by_prequota"
}
$EvidenceFingerprintCommandBeforeAdmission = `
    $ColdRestoreAttestedProcessModuleBeforeAdmission.ExportedCommands[
        "Get-ColdRestoreEvidenceFingerprint"
    ]
if ($null -eq $EvidenceFingerprintCommandBeforeAdmission) {
    throw "cold_restore_evidence_fingerprint_missing_before_admission"
}
$ImportChainFingerprintProbe = [pscustomobject][ordered]@{
    schema_version = 1
    probe_id = "ColdRestoreTopLevelImportChainFingerprintProbeV1"
    semantic_value = "stable-before-and-after-admission"
    evidence_fingerprint = ""
}
$EvidenceFingerprintBeforeAdmission = `
    & $EvidenceFingerprintCommandBeforeAdmission `
        $ImportChainFingerprintProbe "evidence_fingerprint"
$ProcessARehearsalAdmissionModule = cold_restore_module_loader\Import-ColdRestoreModuleOnce `
    -Path (Join-Path $PSScriptRoot "process_a_rehearsal_admission_contract.psm1") `
    -RequiredCommands @(
        "Assert-ProcessARehearsalAdmissionSourcesUnchanged",
        "Complete-ProcessARehearsalLaunch",
        "New-ProcessARehearsalAdmission",
        "Read-ProcessARehearsalAdmissionLedger",
        "Read-ProcessARehearsalLaunchLedger",
        "Write-ProcessARehearsalExclusiveAtomicJson"
    )
$ColdRestoreAttestedProcessModuleAfterAdmission = `
    cold_restore_module_loader\Get-ColdRestoreLoadedModuleByPath `
        $ColdRestoreAttestedProcessModulePath
$EvidenceFingerprintCommandAfterAdmission = `
    $ColdRestoreAttestedProcessModuleAfterAdmission.ExportedCommands[
        "Get-ColdRestoreEvidenceFingerprint"
    ]
if ($null -eq $EvidenceFingerprintCommandAfterAdmission) {
    throw "cold_restore_evidence_fingerprint_missing_after_admission"
}
$EvidenceFingerprintAfterAdmission = `
    & $EvidenceFingerprintCommandAfterAdmission `
        $ImportChainFingerprintProbe "evidence_fingerprint"
$ColdRestoreAttestedProcessModule = cold_restore_module_loader\Import-ColdRestoreModuleOnce `
    -Path $ColdRestoreAttestedProcessModulePath `
    -RequiredCommands @(
        "Add-ColdRestoreFailureRecord",
        "ConvertTo-ColdRestoreCanonicalJson",
        "Get-ColdRestoreEvidenceFingerprint",
        "Get-ColdRestoreFailureProjection",
        "Get-ColdRestoreFailureProjectionFromError",
        "Get-ColdRestoreSafeCollectionCount",
        "Get-ColdRestoreSecondaryFailureCodesFromError",
        "Invoke-ColdRestoreAttestedProcess",
        "New-ColdRestoreFailureException",
        "New-ColdRestoreGodotArgumentList",
        "New-ColdRestorePrimaryFailureState",
        "Test-ColdRestoreChildCompletionAttestation",
        "Test-ColdRestoreProcessAPhaseTimeline"
    )
if (-not [object]::ReferenceEquals(
        $ColdRestoreAttestedProcessModuleBeforeAdmission,
        $ColdRestoreAttestedProcessModuleAfterAdmission
    ) `
    -or -not [object]::ReferenceEquals(
        $ColdRestoreAttestedProcessModuleBeforeAdmission,
        $ColdRestoreAttestedProcessModule
    ) `
    -or $EvidenceFingerprintBeforeAdmission -cne $EvidenceFingerprintAfterAdmission) {
    throw "cold_restore_attested_process_identity_changed_across_admission"
}
$ColdRestoreAttestedProcessIdentity = `
    cold_restore_module_loader\Get-ColdRestoreModuleIdentity `
        $ColdRestoreAttestedProcessModule
$ColdRestoreOfficialAttempt2Module = cold_restore_module_loader\Import-ColdRestoreModuleOnce `
    -Path (Join-Path $PSScriptRoot "cold_restore_official_attempt2_contract.psm1") `
    -RequiredCommands @(
        "Assert-ColdRestoreOfficialAttempt2CandidateRootsAbsent",
        "Assert-ColdRestoreOfficialAttempt2Claim",
        "Assert-ColdRestoreOfficialAttempt2PreflightAuthorizationCount",
        "Assert-ColdRestoreOfficialAttempt2SideEffectSnapshotUnchanged",
        "Get-ColdRestoreOfficialAttempt2SideEffectSnapshot",
        "Publish-ColdRestoreOfficialAttempt2Claim"
    )
$TopLevelImportChainState = [pscustomobject][ordered]@{
    evidence_fingerprint_command_present_before_admission = $true
    evidence_fingerprint_command_present_after_admission = $true
    attested_process_module_identity_stable = $true
    evidence_fingerprint_result_parity = $true
    attested_process_module_name = [string]$ColdRestoreAttestedProcessIdentity.module_name
    attested_process_module_path = [string]$ColdRestoreAttestedProcessIdentity.module_path
    attested_process_module_sha256 = [string]$ColdRestoreAttestedProcessIdentity.file_sha256
    fingerprint_probe_result = [string]$EvidenceFingerprintAfterAdmission
}
$ORCHESTRATOR_SCHEMA_VERSION = 4
$FORMAL_FULL_RUN = $false
$DriverExecutionReady = $true
$AuthorizationContractPath = `
    cold_restore_authorization_contract_v1\Get-ColdRestoreAuthorizationContractPath
$AuthorizationContractSha256 = (
    Get-FileHash -LiteralPath $AuthorizationContractPath -Algorithm SHA256
).Hash.ToLowerInvariant()
$AuthorizationContract = `
    cold_restore_authorization_contract_v1\Get-ColdRestoreAuthorizationContract
$TargetedOwnerCaptureAuthorizationName = `
    cold_restore_authorization_contract_v1\Get-ColdRestoreCurrentTargetedDiagnosticAuthorizationName
$TargetedOwnerCaptureAuthorization = `
    cold_restore_authorization_contract_v1\Get-ColdRestoreAuthorizationEntry `
        $TargetedOwnerCaptureAuthorizationName
$PreviousTargetedOwnerCaptureAuthorizationName = `
    cold_restore_authorization_contract_v1\Get-ColdRestorePreviousTargetedDiagnosticAuthorizationName
$PreviousTargetedOwnerCaptureAuthorization = `
    cold_restore_authorization_contract_v1\Get-ColdRestoreAuthorizationEntry `
        $PreviousTargetedOwnerCaptureAuthorizationName
$ProcessARehearsalAuthorization = $AuthorizationContract.process_a_save_completion_rehearsal_v1
$OfficialAttempt2Authorization = $AuthorizationContract.official_attempt_2
$OfficialAuthorizationId = [string]$OfficialAttempt2Authorization.authorization_id
$OfficialAttempt1ClaimRelativePath = [string]$OfficialAttempt2Authorization.attempt_1_claim_relative_path
$OfficialAttempt2ClaimRelativePath = [string]$OfficialAttempt2Authorization.claim_path
$OfficialAttempt1ClaimSha256 = [string]$OfficialAttempt2Authorization.attempt_1_claim_sha256
$TargetedLedgerBindingContract = `
    cold_restore_targeted_ledger_binding_contract_v1\Get-ColdRestoreTargetedLedgerBindingContract
$PreviousTargetedOwnerCaptureQuotaLedgerRelativePath = `
    [string]$PreviousTargetedOwnerCaptureAuthorization.quota_ledger_relative_path
$PreviousTargetedOwnerCaptureQuotaLedgerSha256 = `
    [string]$TargetedOwnerCaptureAuthorization.previous_quota_ledger_sha256
$HistoricalTargetedOwnerCaptureInvocationCommit = `
    [string]$TargetedLedgerBindingContract.exact_literals.historical_invocation_commit
$HistoricalTargetedOwnerCaptureInvocationBlobSha1 = `
    [string]$TargetedLedgerBindingContract.exact_literals.historical_invocation_blob_sha1
$HistoricalTargetedOwnerCaptureInvocationFileSha256 = `
    [string]$TargetedLedgerBindingContract.exact_literals.historical_invocation_file_sha256
$HistoricalTargetedOwnerCaptureInvocationPath = "reports/handoffs/alpha04c_save_resume_current.json"
$ExhaustedTargetedOwnerCaptureQuotaLedgerRelativePath = "codex\cold_restore_v3\non-official-alpha04c-owner-capture-attestation-12691a8\targeted_owner_capture_quota_ledger.json"
$TargetedOwnerCaptureQuotaLedgerRelativePath = [string]$TargetedOwnerCaptureAuthorization.quota_ledger_relative_path
$TargetedOwnerCaptureEvidenceRootRelativePath = [string]$TargetedOwnerCaptureAuthorization.evidence_root_relative_path
$TargetedOwnerCaptureBootstrapRelativeRoot = [string]$TargetedOwnerCaptureAuthorization.bootstrap_root_relative_path
$TargetedOwnerCaptureAuthorizationId = [string]$TargetedOwnerCaptureAuthorization.authorization_id
$TargetedOwnerCaptureTaskId = [string]$TargetedOwnerCaptureAuthorization.task_id
$TargetedOwnerCaptureRunIdPrefix = [string]$TargetedOwnerCaptureAuthorization.run_id_prefix
$ProcessARehearsalAuthorizationId = [string]$ProcessARehearsalAuthorization.authorization_id
$ProcessARehearsalQuotaLedgerRelativePath = [string]$ProcessARehearsalAuthorization.quota_ledger_relative_path
$ProcessARehearsalLaunchLedgerRelativePath = [string]$ProcessARehearsalAuthorization.launch_ledger_relative_path
$ProcessARehearsalOutcomeLedgerRelativePath = [string]$ProcessARehearsalAuthorization.outcome_ledger_relative_path
$DefaultRoleTimeoutPolicyPath = Join-Path $PSScriptRoot "cold_restore_role_timeout_policy_v1.json"
$RoleTimeoutPolicyEvidence = $null
$LastTargetedPreQuotaContext = $null
$script:OfficialAttempt2Progress = [ordered]@{
    claim_created = $false
    process_a_started = $false
    process_a_completed = $false
    process_b_started = $false
    process_b_completed = $false
    process_c_started = $false
    process_c_completed = $false
    comparison_started = $false
    comparison_completed = $false
}
$DriverScript = "res://scripts/tools/cold_restore_vertical_slice_driver.gd"
$ArtifactRoot = "user://test_runs/alpha04c/$RunId/evidence"
$UserDataPrefix = if ($TargetedOwnerCaptureDiagnostic) {
    "space_syndicate_alpha04c_owner_capture_diagnostic"
}
elseif ($NonOfficialProcessA) {
    "space_syndicate_alpha04c_cold_restore_non_official"
}
else {
    "space_syndicate_alpha04c_cold_restore"
}
$UserDataRoot = Join-Path ([IO.Path]::GetTempPath()) "$UserDataPrefix`_$RunId"
$IsolatedAppData = Join-Path $UserDataRoot "appdata-roaming"
$IsolatedLocalAppData = Join-Path $UserDataRoot "appdata-local"
$ManifestPrefix = "COLD_RESTORE_MANIFEST|"
$QualificationPrefix = "COLD_RESTORE_QUALIFICATION|"
$TargetedOwnerCaptureScenarioFingerprint = "0bccef8426345e2ea1fd8ae7d6187d282d52d44bc73d6fb3d1ed3375dc20b7bf"
$TargetedOwnerCapturePhases = @(
    "session_started",
    "real_commodity_claim_complete",
    "real_normal_card_purchase_complete",
    "real_facility_economy_complete",
    "first_sale_receipt_complete",
    "ai_nondefault_state_complete",
    "queue_entry_committed",
    "restore_barrier_entered"
)
$SaveSectionOrder = @(
    "ruleset", "region_infrastructure", "region_supply", "commodity_flow",
    "routes", "player_mana", "commodity_belt_visibility", "card_inventory",
    "player_organization", "monsters", "military", "weather",
    "card_resolution_queue", "card_resolution_execution", "card_resolution_history",
    "ai", "bankruptcy_neutral_estate", "victory_control", "session"
)
$SaveOwnerOrder = @(
    "ruleset_runtime", "public_facility_region", "region_supply", "commodity_flow",
    "route_network", "player_mana", "commodity_belt_visibility", "card_inventory",
    "player_organization", "monster_runtime", "military_runtime", "weather_runtime",
    "card_resolution_queue", "card_resolution_execution", "card_resolution_history",
    "ai_runtime", "bankruptcy_neutral_estate", "victory_control", "game_session"
)
$OwnerCaptureFailureClasses = @(
    "OWNER_NODE_MISSING",
    "OWNER_METHOD_MISSING",
    "OWNER_CAPTURE_EXCEPTION",
    "OWNER_CAPTURE_WRONG_TYPE",
    "OWNER_CAPTURE_EMPTY",
    "OWNER_CAPTURE_NOT_PURE_DATA",
    "OWNER_CAPTURE_HEADER_INVALID",
    "OWNER_CAPTURE_VERSION_INVALID",
    "OWNER_CAPTURE_RULESET_INVALID",
    "OWNER_CAPTURE_MUTATED_RUNTIME",
    "REGISTRY_INTERNAL_ERROR"
)
$RoleSequence = @("producer", "consumer", "validator")
$ProcessSequence = @(
    "qualification_exit_attested",
    "official_fixed_claim_consumed",
    "producer_child_completion",
    "producer_parent_exit",
    "consumer_start",
    "consumer_child_completion",
    "consumer_parent_exit",
    "validator_start",
    "validator_child_completion",
    "validator_parent_exit",
    "orchestrator_compare"
)
$ManifestFields = @(
    "schema_version",
    "visibility_scope",
    "run_id",
    "process_role",
    "process_id",
    "head_sha",
    "scenario_fingerprint",
    "slot_id",
    "slot_state",
    "source_sections_digest",
    "restored_sections_digest",
    "saved_sections_digest",
    "source_write_id",
    "write_id",
    "source_write_fingerprint",
    "section_count",
    "preflight_count",
    "owner_apply_count",
    "registry_apply_count",
    "registry_commit_count",
    "registry_rebind_count",
    "partial_restore_state_count",
    "save_capture_world_delta",
    "save_capture_rng_delta",
    "save_capture_log_delta",
    "rng_draw_count_before",
    "rng_draw_count_after",
    "restore_rng_draw_delta",
    "restore_world_time_delta",
    "restore_public_log_delta",
    "restore_sale_receipt_delta",
    "restore_economic_reward_delta",
    "restore_ai_action_delta",
    "restore_player_action_delta",
    "restore_notification_delta",
    "restore_private_feedback_delta",
    "human_action_count",
    "commodity_action_count",
    "ai_action_count",
    "sale_receipt_count",
    "normal_card_count",
    "commodity_card_count",
    "commodity_claim_count",
    "facility_count",
    "route_count",
    "military_unit_count",
    "queue_entry_count",
    "weather_region_count",
    "ai_nondefault_state_count",
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
    "victory_unresolved_before_save",
    "production_surface_ready",
    "victory_state_sequence",
    "final_settlement_count",
    "final_settlement_presentation_count",
    "final_settlement_public_log_count",
    "terminal_quiescent_frames",
    "terminal_world_delta",
    "terminal_rng_draw_delta",
    "generation",
    "backup_created",
    "save_readback_green",
    "save_fingerprint_parity",
    "write_fingerprint",
    "elapsed_ms",
    "success",
    "failure_code"
)
$IntegerManifestFields = @(
    "schema_version",
    "process_id",
    "section_count",
    "preflight_count",
    "owner_apply_count",
    "registry_apply_count",
    "registry_commit_count",
    "registry_rebind_count",
    "partial_restore_state_count",
    "save_capture_world_delta",
    "save_capture_rng_delta",
    "save_capture_log_delta",
    "rng_draw_count_before",
    "rng_draw_count_after",
    "restore_rng_draw_delta",
    "restore_world_time_delta",
    "restore_public_log_delta",
    "restore_sale_receipt_delta",
    "restore_economic_reward_delta",
    "restore_ai_action_delta",
    "restore_player_action_delta",
    "restore_notification_delta",
    "restore_private_feedback_delta",
    "human_action_count",
    "commodity_action_count",
    "ai_action_count",
    "sale_receipt_count",
    "normal_card_count",
    "commodity_card_count",
    "commodity_claim_count",
    "facility_count",
    "route_count",
    "military_unit_count",
    "queue_entry_count",
    "weather_region_count",
    "ai_nondefault_state_count",
    "queue_trigger_resolution_id",
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
    "duplicate_queue_entry_count",
    "duplicate_facility_creation_count",
    "duplicate_card_consumption_count",
    "duplicate_cost_consumption_count",
    "duplicate_sale_receipt_count",
    "generation_2_duplicate_transaction_count",
    "final_settlement_count",
    "final_settlement_presentation_count",
    "final_settlement_public_log_count",
    "terminal_quiescent_frames",
    "terminal_world_delta",
    "terminal_rng_draw_delta",
    "generation",
    "elapsed_ms"
)
$RestoreDeltaFields = @(
    "restore_rng_draw_delta",
    "restore_world_time_delta",
    "restore_public_log_delta",
    "restore_sale_receipt_delta",
    "restore_economic_reward_delta",
    "restore_ai_action_delta",
    "restore_player_action_delta",
    "restore_notification_delta",
    "restore_private_feedback_delta"
)
$DuplicateCountFields = @(
    "duplicate_queue_entry_count",
    "duplicate_facility_creation_count",
    "duplicate_card_consumption_count",
    "duplicate_cost_consumption_count",
    "duplicate_sale_receipt_count"
)
$StringManifestFields = @(
    "visibility_scope",
    "run_id",
    "process_role",
    "head_sha",
    "scenario_fingerprint",
    "slot_id",
    "slot_state",
    "source_sections_digest",
    "restored_sections_digest",
    "saved_sections_digest",
    "source_write_id",
    "write_id",
    "source_write_fingerprint",
    "queue_trigger_stable_target_fingerprint",
    "write_fingerprint",
    "failure_code"
)
$BooleanManifestFields = @(
    "backup_created",
    "save_readback_green",
    "save_fingerprint_parity",
    "world_fingerprint_match",
    "rng_cursor_match",
    "ai_state_fingerprint_match",
    "card_inventory_fingerprint_match",
    "queue_fingerprint_match",
    "generation_2_recapture_fingerprint_match",
    "generation_2_rng_cursor_match",
    "victory_unresolved_before_save",
    "production_surface_ready",
    "success"
)
$ActionCountFields = @(
    "human_action_count",
    "commodity_action_count",
    "ai_action_count",
    "sale_receipt_count"
)
$SettlementCountFields = @(
    "final_settlement_count",
    "final_settlement_presentation_count",
    "final_settlement_public_log_count"
)
$GenerationTwoExactCountFields = @(
    "normal_card_count",
    "commodity_card_count",
    "commodity_claim_count",
    "facility_count",
    "route_count",
    "military_unit_count",
    "queue_entry_count",
    "weather_region_count",
    "ai_nondefault_state_count"
)
$QueueTargetSideEffectDeltaFields = @(
    "queue_target_history_duplicate_delta",
    "queue_target_transition_duplicate_delta",
    "queue_target_inventory_queue_commit_delta",
    "queue_target_public_log_duplicate_delta",
    "queue_target_public_log_collision_delta"
)
$QualificationResultFields = @(
    "schema_version",
    "qualification_probe",
    "official_cold_restore_vertical_slice",
    "formal_full_run",
    "run_id",
    "challenge_depth",
    "seed",
    "scenario_fingerprint",
    "human_action_count",
    "commodity_action_count",
    "normal_card_purchase_count",
    "facility_action_count",
    "sale_receipt_count",
    "ai_action_count",
    "ai_state_fingerprint_changed",
    "queue_trigger_actor",
    "queue_trigger_semantic_action_id",
    "queue_trigger_card_semantic_id",
    "queue_trigger_target_fingerprint",
    "queue_count",
    "queue_revision",
    "offer_audit",
    "card_resolution_advance_after_trigger",
    "world_advance_after_trigger",
    "rng_draw_after_trigger",
    "normal_card_count",
    "commodity_card_count",
    "commodity_claim_count",
    "facility_count",
    "route_count",
    "weather_region_count",
    "ai_nondefault_state_count",
    "production_surface_ready",
    "save_written",
    "success",
    "failure_code",
    "product_blocker"
)
$ParentExitAttestationFields = @(
    "schema_version",
    "run_id",
    "role",
    "child_pid",
    "observed_exit",
    "exit_code",
    "timed_out",
    "terminated_by_parent",
    "stdout_sha256",
    "stderr_sha256",
    "child_attestation_found",
    "child_attestation_fingerprint",
    "child_attestation_valid",
    "task_owned_process_count_after",
    "unrelated_preexisting_process_count",
    "wrapper_exit_green",
    "wrapper_reason_code"
)
$OwnerCaptureDiagnosticFields = @(
    "schema_version", "diagnostic_id", "run_id", "repository_head",
    "scenario_fingerprint", "official", "formal", "challenge_depth", "seed",
    "local_player_count", "ai_player_count", "ai_action_count", "ai_state_digest_changed",
    "audit_count", "phase_audits",
    "first_phase_with_capture_failure", "first_failure", "safety_green",
    "save_file_exists", "official_claim_path_present"
)
$OwnerCaptureAuditFields = @(
    "phase_id", "captured", "section_count", "section_results", "first_failure",
    "world_fingerprint_match", "safety_observation_match", "world_advance_delta",
    "rng_draw_delta", "public_log_delta", "private_feedback_delta",
    "sale_receipt_delta", "human_action_delta", "ai_action_delta",
    "notification_delta", "safety_green"
)
$OwnerCaptureSectionResultFields = @(
    "section_id", "owner_id", "captured", "reason_code", "state_version",
    "payload_fingerprint"
)
$OwnerCaptureFailureFields = @(
    "schema_version", "registry_operation_id", "capture_sequence", "section_index",
    "section_id", "owner_id", "owner_node_path", "owner_script_path",
    "capture_method", "failure_class", "reason_code", "method_missing",
    "method_exception", "result_not_dictionary", "result_empty",
    "result_not_pure_data", "result_header_invalid", "result_version_invalid",
    "result_ruleset_invalid", "state_version_observed", "ruleset_id_observed",
    "live_state_mutated_during_capture", "private_payload_redacted"
)
$RoleTimeoutPolicyFields = @(
    "schema_version", "policy_id", "policy_source", "measurement_head",
    "measurement_run_id", "poll_interval_ms", "normal_exit_grace_seconds",
    "stream_drain_grace_seconds", "process_tree_cleanup_grace_seconds",
    "progress_heartbeat_fields", "roles"
)
$RoleTimeoutFields = @(
    "absolute_timeout_seconds", "no_progress_timeout_seconds",
    "timeout_reason_code", "cleanup_policy", "contract_only_in_this_task"
)
$TargetedDiagnosticV2Fields = @(
    "schema_version", "diagnostic_id", "run_id", "repository_head", "official",
    "formal", "scenario_identity", "scenario_identity_attested",
    "scenario_identity_failure", "registry_binding_attested",
    "harness_or_scenario_failure_attested",
    "diagnostic_phase_timeline", "last_completed_diagnostic_phase",
    "current_diagnostic_phase", "next_expected_diagnostic_phase",
    "owner_audit_started", "owner_audit_completed", "first_owner_capture_index",
    "last_completed_owner_capture_index", "owner_capture_attempted_count",
    "owner_capture_succeeded_count", "owner_capture_failed_count",
    "owner_capture_skipped_count", "owner_capture_rows", "first_failure",
    "owner_capture_failure_attested", "post_capture_validation",
    "post_capture_failure", "safety_green", "save_file_exists",
    "official_claim_path_present", "evidence_fingerprint"
)
$DiagnosticScenarioIdentityFields = @(
    "schema_version", "identity_id", "run_id", "repository_head", "ruleset_id",
    "ruleset_fingerprint", "challenge_depth", "run_seed_tagged_int64",
    "session_seed_tagged_int64", "scenario_fingerprint", "local_player_count",
    "ai_player_count", "roster_fingerprint", "session_id", "session_generation",
    "session_plan_fingerprint", "world_revision", "runtime_composition_fingerprint",
    "save_registry_fingerprint", "user_data_path_fingerprint", "diagnostic_role",
    "identity_fingerprint"
)
$DiagnosticScenarioFailureFields = @(
    "schema_version", "failure_field", "reason_code", "expected_summary",
    "actual_summary", "private_payload_redacted"
)
$TargetedDiagnosticTimelineFields = @(
    "schema_version", "timeline_id", "run_id", "repository_head", "phase_rows",
    "last_completed_phase", "current_phase", "next_expected_phase",
    "evidence_fingerprint"
)
$TargetedDiagnosticPhaseRowFields = @(
    "sequence", "phase_id", "owner_index", "completed_monotonic_ms", "success",
    "reason_code", "evidence_fingerprint"
)
$TargetedDiagnosticOwnerRowFields = @(
    "owner_index", "section_id", "owner_id", "owner_path", "capture_started",
    "capture_completed", "capture_result_kind", "state_version",
    "payload_fingerprint", "payload_pure_data", "elapsed_milliseconds",
    "mutation_count", "rng_draw_delta", "world_time_delta", "public_log_delta",
    "reason_code", "private_payload_redacted", "row_evidence_fingerprint"
)
$ProcessARehearsalCompletionFields = @(
    "schema_version", "completion_id", "run_id", "repository_head",
    "scenario_fingerprint", "rehearsal_only", "official", "formal",
    "official_attempt_claim_created", "official_authorization_consumed",
    "authorization_fingerprint", "timeout_policy_fingerprint", "restore_barrier_entered",
    "restore_barrier_quiet", "restore_barrier_released",
    "save_owner_capture_count", "save_section_count", "save_preflight_count",
    "capture_operation_sequence", "captured_sections_fingerprint",
    "readback_sections_fingerprint",
    "save_capture_world_delta", "save_capture_rng_delta", "save_capture_public_log_delta",
    "envelope_encode_green", "atomic_write_green", "save_readback_green",
    "save_capture_fingerprint", "save_readback_fingerprint",
    "save_fingerprint_parity", "save_file_bytes", "save_file_sha256",
    "queue_entry_count", "evidence_fingerprint"
)
$LaunchAttestationFields = @(
    "schema_version",
    "authorization_id",
    "claim_fingerprint",
    "claim_nonce",
    "source_head_sha",
    "scenario_fingerprint",
    "run_id",
    "process_role",
    "launch_nonce",
    "orchestrator_process_id",
    "orchestrator_creation_time_utc_ticks",
    "wrapper_process_id",
    "wrapper_parent_process_id",
    "wrapper_creation_time_utc_ticks",
    "engine_process_id",
    "engine_parent_process_id",
    "engine_creation_time_utc_ticks",
    "status"
)

function Assert-ColdRestoreCondition {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$FailureCode
    )
    if (-not $Condition) {
        throw $FailureCode
    }
}

function Resolve-ColdRestoreGodotExecutable {
    param([Parameter(Mandatory = $true)][string]$Candidate)
    $resolved = if (Test-Path -LiteralPath $Candidate -PathType Leaf) {
        (Resolve-Path -LiteralPath $Candidate).Path
    }
    else {
        (Get-Command $Candidate -CommandType Application -ErrorAction Stop).Source
    }
    if ([IO.Path]::GetFileNameWithoutExtension($resolved).EndsWith("_console", [StringComparison]::OrdinalIgnoreCase)) {
        return $resolved
    }
    $consoleCandidates = @(
        Get-ChildItem -LiteralPath (Split-Path -Parent $resolved) -Filter "Godot*_console.exe" -File -ErrorAction SilentlyContinue
    )
    Assert-ColdRestoreCondition ($consoleCandidates.Count -eq 1) "godot_console_wrapper_unavailable"
    return $consoleCandidates[0].FullName
}

function Test-NonnegativeInteger {
    param([AllowNull()]$Value)
    $isInteger = $Value -is [byte] -or $Value -is [sbyte] `
        -or $Value -is [int16] -or $Value -is [uint16] `
        -or $Value -is [int32] -or $Value -is [uint32] `
        -or $Value -is [int64] -or $Value -is [uint64]
    return $isInteger -and [int64]$Value -ge 0
}

function Test-IntegerValue {
    param([AllowNull()]$Value)
    return $Value -is [byte] -or $Value -is [sbyte] `
        -or $Value -is [int16] -or $Value -is [uint16] `
        -or $Value -is [int32] -or $Value -is [uint32] `
        -or $Value -is [int64] -or $Value -is [uint64]
}

function Test-Sha256OrEmpty {
    param([AllowNull()]$Value)
    $text = [string]$Value
    return $text.Length -eq 0 -or $text -match '^[0-9a-f]{64}$'
}

function Test-ExactFieldSet {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string[]]$ExpectedFields
    )
    if ($null -eq $Value) {
        return $false
    }
    $actual = @(
        $Value.PSObject.Properties | ForEach-Object { [string]$_.Name } | Sort-Object
    )
    $expected = @($ExpectedFields | Sort-Object)
    return @(Compare-Object -ReferenceObject $expected -DifferenceObject $actual).Count -eq 0
}

function Test-OwnerCaptureFailureIdentity {
    param([Parameter(Mandatory = $true)]$Failure)
    if (-not (Test-ExactFieldSet $Failure $OwnerCaptureFailureFields)) {
        return $false
    }
    if (-not (Test-IntegerValue $Failure.schema_version) `
        -or -not (Test-IntegerValue $Failure.capture_sequence) `
        -or -not (Test-IntegerValue $Failure.section_index) `
        -or -not (Test-IntegerValue $Failure.state_version_observed)) {
        return $false
    }
    $index = [int]$Failure.section_index
    $booleanFields = @(
        "method_missing", "method_exception", "result_not_dictionary", "result_empty",
        "result_not_pure_data", "result_header_invalid", "result_version_invalid",
        "result_ruleset_invalid", "live_state_mutated_during_capture",
        "private_payload_redacted"
    )
    foreach ($field in $booleanFields) {
        if ($Failure.$field -isnot [bool]) {
            return $false
        }
    }
    $classFlag = @{
        OWNER_METHOD_MISSING = "method_missing"
        OWNER_CAPTURE_EXCEPTION = "method_exception"
        OWNER_CAPTURE_WRONG_TYPE = "result_not_dictionary"
        OWNER_CAPTURE_EMPTY = "result_empty"
        OWNER_CAPTURE_NOT_PURE_DATA = "result_not_pure_data"
        OWNER_CAPTURE_HEADER_INVALID = "result_header_invalid"
        OWNER_CAPTURE_VERSION_INVALID = "result_version_invalid"
        OWNER_CAPTURE_RULESET_INVALID = "result_ruleset_invalid"
        OWNER_CAPTURE_MUTATED_RUNTIME = "live_state_mutated_during_capture"
    }[[string]$Failure.failure_class]
    return [int]$Failure.schema_version -eq 1 `
        -and [string]$Failure.registry_operation_id -cmatch '^[A-Za-z0-9_.:-]{1,96}$' `
        -and [int64]$Failure.capture_sequence -ge 1 `
        -and $index -ge 0 `
        -and $index -lt $SaveSectionOrder.Count `
        -and [string]$Failure.section_id -ceq $SaveSectionOrder[$index] `
        -and [string]$Failure.owner_id -ceq $SaveOwnerOrder[$index] `
        -and [string]$Failure.owner_node_path -cmatch '^[A-Za-z0-9_./:-]{0,256}$' `
        -and [string]$Failure.owner_script_path -cmatch '^[A-Za-z0-9_./:-]{0,256}$' `
        -and [string]$Failure.capture_method -cmatch '^[A-Za-z0-9_.:-]{0,96}$' `
        -and [string]$Failure.failure_class -cin $OwnerCaptureFailureClasses `
        -and [string]$Failure.reason_code -cmatch '^[a-z0-9_]{1,128}$' `
        -and [int64]$Failure.state_version_observed -ge -1 `
        -and [string]$Failure.ruleset_id_observed -cin @("", "v0.6") `
        -and ($null -eq $classFlag -or [bool]$Failure.$classFlag) `
        -and [bool]$Failure.private_payload_redacted
}

function Test-OwnerCaptureAuditRelationship {
    param([Parameter(Mandatory = $true)]$Audit)
    if (-not (Test-ExactFieldSet $Audit $OwnerCaptureAuditFields)) {
        return $false
    }
    $results = @($Audit.section_results)
    $successfulCount = [int]$Audit.section_count
    if ($successfulCount -lt 0 -or $successfulCount -gt $SaveSectionOrder.Count `
        -or $results.Count -gt $SaveSectionOrder.Count) {
        return $false
    }
    for ($index = 0; $index -lt $results.Count; $index += 1) {
        $row = $results[$index]
        if (-not (Test-ExactFieldSet $row $OwnerCaptureSectionResultFields) `
            -or [string]$row.section_id -cne $SaveSectionOrder[$index] `
            -or [string]$row.owner_id -cne $SaveOwnerOrder[$index] `
            -or [string]$row.reason_code -cnotmatch '^[a-z0-9_]{1,128}$' `
            -or ([bool]$row.captured -and [string]$row.payload_fingerprint -cnotmatch '^[0-9a-f]{64}$') `
            -or (-not [string]::IsNullOrEmpty([string]$row.payload_fingerprint) `
                -and [string]$row.payload_fingerprint -cnotmatch '^[0-9a-f]{64}$')) {
            return $false
        }
    }
    $failureFields = @($Audit.first_failure.PSObject.Properties | ForEach-Object { [string]$_.Name })
    if ([bool]$Audit.captured) {
        return $successfulCount -eq $SaveSectionOrder.Count `
            -and $results.Count -eq $SaveSectionOrder.Count `
            -and @($results | Where-Object { -not [bool]$_.captured }).Count -eq 0 `
            -and $failureFields.Count -eq 0
    }
    if ($failureFields.Count -eq 0 -or -not (Test-OwnerCaptureFailureIdentity $Audit.first_failure)) {
        return $false
    }
    $failureIndex = [int]$Audit.first_failure.section_index
    if ($successfulCount -eq $SaveSectionOrder.Count) {
        return $results.Count -eq $SaveSectionOrder.Count `
            -and @($results | Where-Object { -not [bool]$_.captured }).Count -eq 0
    }
    if ($results.Count -ne ($successfulCount + 1) -or $failureIndex -ne $successfulCount) {
        return $false
    }
    for ($index = 0; $index -lt $successfulCount; $index += 1) {
        if (-not [bool]$results[$index].captured) {
            return $false
        }
    }
    $failureRow = $results[$successfulCount]
    return -not [bool]$failureRow.captured `
        -and [string]$failureRow.section_id -ceq [string]$Audit.first_failure.section_id `
        -and [string]$failureRow.owner_id -ceq [string]$Audit.first_failure.owner_id `
        -and [string]$failureRow.reason_code -ceq [string]$Audit.first_failure.reason_code
}

function Assert-ColdRestoreManifest {
    param(
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)][ValidateSet("producer", "consumer", "validator")][string]$Role,
        [Parameter(Mandatory = $true)][string]$ExpectedRunId
    )
    Assert-ColdRestoreCondition (Test-ExactFieldSet $Manifest $ManifestFields) "manifest_field_set_invalid"
    foreach ($field in $IntegerManifestFields) {
        Assert-ColdRestoreCondition (Test-NonnegativeInteger $Manifest.$field) "manifest_integer_invalid"
    }
    foreach ($field in $StringManifestFields) {
        Assert-ColdRestoreCondition ($Manifest.$field -is [string]) "manifest_string_type_invalid"
    }
    foreach ($field in $BooleanManifestFields) {
        Assert-ColdRestoreCondition ($Manifest.$field -is [bool]) "manifest_boolean_type_invalid"
    }
    Assert-ColdRestoreCondition ([int]$Manifest.schema_version -eq $ORCHESTRATOR_SCHEMA_VERSION) "manifest_schema_invalid"
    Assert-ColdRestoreCondition ([string]$Manifest.visibility_scope -eq "qa_allowlisted") "manifest_visibility_invalid"
    Assert-ColdRestoreCondition ([string]$Manifest.run_id -eq $ExpectedRunId) "manifest_run_id_mismatch"
    Assert-ColdRestoreCondition ([string]$Manifest.process_role -eq $Role) "manifest_role_mismatch"
    Assert-ColdRestoreCondition ([int64]$Manifest.process_id -gt 0) "manifest_process_id_invalid"
    Assert-ColdRestoreCondition ([string]$Manifest.head_sha -match '^[0-9a-f]{7,64}$') "manifest_head_sha_invalid"
    Assert-ColdRestoreCondition (Test-Sha256OrEmpty $Manifest.scenario_fingerprint) "manifest_scenario_fingerprint_invalid"
    Assert-ColdRestoreCondition ([string]$Manifest.slot_id -eq "current_run") "manifest_slot_id_invalid"
    Assert-ColdRestoreCondition ([string]$Manifest.slot_state -in @("ready", "restored", "validated", "failed")) "manifest_slot_state_invalid"
    foreach ($field in @(
        "source_sections_digest",
        "restored_sections_digest",
        "saved_sections_digest",
        "source_write_fingerprint",
        "write_fingerprint",
        "queue_trigger_stable_target_fingerprint"
    )) {
        Assert-ColdRestoreCondition (Test-Sha256OrEmpty $Manifest.$field) "manifest_digest_invalid"
    }
    foreach ($field in @("source_write_id", "write_id")) {
        Assert-ColdRestoreCondition ([string]$Manifest.$field -match '^[A-Za-z0-9._:-]{0,128}$') "manifest_write_id_invalid"
    }
    Assert-ColdRestoreCondition ($Manifest.backup_created -is [bool]) "manifest_backup_flag_invalid"
    Assert-ColdRestoreCondition ($Manifest.save_readback_green -is [bool] `
        -and $Manifest.save_fingerprint_parity -is [bool]) "manifest_save_readback_flag_invalid"
    Assert-ColdRestoreCondition ($Manifest.victory_unresolved_before_save -is [bool]) "manifest_victory_flag_invalid"
    Assert-ColdRestoreCondition ($Manifest.production_surface_ready -is [bool]) "manifest_surface_flag_invalid"
    Assert-ColdRestoreCondition ($Manifest.success -is [bool]) "manifest_success_flag_invalid"
    Assert-ColdRestoreCondition ($Manifest.victory_state_sequence -is [System.Array] `
        -and @($Manifest.victory_state_sequence).Count -le 12) "manifest_victory_sequence_invalid"
    foreach ($state in @($Manifest.victory_state_sequence)) {
        Assert-ColdRestoreCondition ($state -is [string] `
            -and [string]$state -match '^[a-z0-9_]{1,64}$') "manifest_victory_sequence_invalid"
    }
    Assert-ColdRestoreCondition ([string]$Manifest.failure_code -match '^[a-z0-9_]{0,128}$') "manifest_failure_code_invalid"
    Assert-ColdRestoreCondition (([bool]$Manifest.success -and [string]$Manifest.failure_code -eq "") `
        -or (-not [bool]$Manifest.success -and [string]$Manifest.failure_code -ne "")) "manifest_success_binding_invalid"
}

function Read-ColdRestoreManifest {
    param(
        [Parameter(Mandatory = $true)][string]$StdoutPath,
        [Parameter(Mandatory = $true)][ValidateSet("producer", "consumer", "validator")][string]$Role,
        [Parameter(Mandatory = $true)][string]$ExpectedRunId
    )
    $markerLines = @(
        Get-Content -LiteralPath $StdoutPath -Encoding UTF8 |
            Where-Object { $_.StartsWith($ManifestPrefix, [System.StringComparison]::Ordinal) }
    )
    Assert-ColdRestoreCondition ($markerLines.Count -eq 1) "manifest_marker_count_invalid"
    $payload = $markerLines[0].Substring($ManifestPrefix.Length)
    try {
        $manifest = $payload | ConvertFrom-Json
    }
    catch {
        throw "manifest_json_invalid"
    }
    Assert-ColdRestoreManifest $manifest $Role $ExpectedRunId
    return $manifest
}

function Get-ColdRestoreRolePaths {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedProjectPath,
        [Parameter(Mandatory = $true)][string]$Role
    )
    $root = if ($TargetedOwnerCaptureDiagnostic) {
        Join-Path (Resolve-ColdRestoreGitCommonDirectory $ResolvedProjectPath) `
            $TargetedOwnerCaptureEvidenceRootRelativePath
    }
    else {
        Join-Path $ResolvedProjectPath ".godot\cold_restore_attestation_v1\$RunId"
    }
    return [pscustomobject]@{
        root = $root
        child_attestation = Join-Path $root "child\$Role.completion.json"
        child_result = Join-Path $root "child\$Role.result.json"
        parent_attestation = Join-Path $root "parent\$Role.exit.json"
        stdout = Join-Path $root "parent\$Role.stdout.log"
        stderr = Join-Path $root "parent\$Role.stderr.log"
        phase_timeline = Join-Path $root "diagnostics\producer.phase_timeline.json"
        phase_timeline_events = Join-Path $root "diagnostics\producer.phase_timeline.events"
        targeted_heartbeat_events = Join-Path $root "diagnostics\targeted_owner_diagnostic.heartbeat.events"
        targeted_heartbeat = Join-Path $root "diagnostics\targeted_owner_diagnostic.heartbeat.json"
        process_a_heartbeat_events = Join-Path $root "diagnostics\process_a.heartbeat.events"
        process_a_heartbeat = Join-Path $root "diagnostics\process_a.heartbeat.json"
        process_b_heartbeat_events = Join-Path $root "diagnostics\process_b.heartbeat.events"
        process_b_heartbeat = Join-Path $root "diagnostics\process_b.heartbeat.json"
        process_c_heartbeat_events = Join-Path $root "diagnostics\process_c.heartbeat.events"
        process_c_heartbeat = Join-Path $root "diagnostics\process_c.heartbeat.json"
        targeted_diagnostic = Join-Path $root "diagnostics\owner_capture_audit.json"
        rehearsal_completion = Join-Path $root "diagnostics\process_a.rehearsal_completion.json"
    }
}

function Read-ColdRestoreJsonArtifact {
    param([Parameter(Mandatory = $true)][string]$Path)
    Assert-ColdRestoreCondition (Test-Path -LiteralPath $Path -PathType Leaf) "evidence_artifact_missing"
    try {
        return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json -DateKind String
    }
    catch {
        throw "evidence_artifact_json_invalid"
    }
}

function Get-ColdRestoreOptionalFileSha256 {
    param([AllowEmptyString()][string]$Path)
    if ([string]::IsNullOrEmpty($Path) -or -not [IO.File]::Exists($Path)) {
        return ""
    }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-ColdRestoreRuntimeFreezeObservation {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedProjectPath,
        [Parameter(Mandatory = $true)][string]$ExpectedHead
    )

    $headLines = @(& git -C $ResolvedProjectPath rev-parse HEAD 2>$null)
    $headExitCode = $LASTEXITCODE
    $dirtyPaths = @(& git -C $ResolvedProjectPath status --porcelain=v1 2>$null)
    $statusExitCode = $LASTEXITCODE
    $diffCheckIssues = @(& git -C $ResolvedProjectPath diff --check 2>&1)
    $diffCheckExitCode = $LASTEXITCODE
    $observedHead = if ((cold_restore_attested_process\Get-ColdRestoreSafeCollectionCount $headLines) -eq 1) {
        ([string]$headLines[0]).Trim()
    }
    else {
        ""
    }
    $observation = [ordered]@{
        schema_version = 1
        observation_id = "ColdRestoreRuntimeFreezeObservationV1"
        expected_head = $ExpectedHead
        observed_head = $observedHead
        head_query_green = $headExitCode -eq 0 -and $observedHead -cmatch '^[0-9a-f]{40}$'
        head_matches = $observedHead -ceq $ExpectedHead
        status_query_green = $statusExitCode -eq 0
        tree_clean = $statusExitCode -eq 0 -and (cold_restore_attested_process\Get-ColdRestoreSafeCollectionCount $dirtyPaths) -eq 0
        dirty_path_count = cold_restore_attested_process\Get-ColdRestoreSafeCollectionCount $dirtyPaths
        git_diff_check_green = $diffCheckExitCode -eq 0 -and (cold_restore_attested_process\Get-ColdRestoreSafeCollectionCount $diffCheckIssues) -eq 0
        git_diff_check_issue_count = cold_restore_attested_process\Get-ColdRestoreSafeCollectionCount $diffCheckIssues
        evidence_fingerprint = ""
    }
    $observation.evidence_fingerprint = cold_restore_attested_process\Get-ColdRestoreEvidenceFingerprint ([pscustomobject]$observation) "evidence_fingerprint"
    return [pscustomobject]$observation
}

function Assert-ColdRestoreTargetedDiagnosticRemoteCheckpoint {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedProjectPath,
        [Parameter(Mandatory = $true)][string]$ExpectedHead
    )

    $branchLines = @(& git -C $ResolvedProjectPath branch --show-current 2>$null)
    $localHeadLines = @(& git -C $ResolvedProjectPath rev-parse HEAD 2>$null)
    Assert-ColdRestoreCondition ((cold_restore_attested_process\Get-ColdRestoreSafeCollectionCount $branchLines) -eq 1 `
        -and (cold_restore_attested_process\Get-ColdRestoreSafeCollectionCount $localHeadLines) -eq 1 `
        -and [string]$branchLines[0] -cmatch '^codex/alpha04c-v5-owner-diagnostic-[0-9a-f]{7,12}$' `
        -and [string]$localHeadLines[0] -ceq $ExpectedHead) "targeted_diagnostic_local_checkpoint_invalid"
    $branch = [string]$branchLines[0]
    $remoteLines = @(& git -C $ResolvedProjectPath rev-parse "refs/remotes/origin/$branch" 2>$null)
    Assert-ColdRestoreCondition ($LASTEXITCODE -eq 0 `
        -and (cold_restore_attested_process\Get-ColdRestoreSafeCollectionCount $remoteLines) -eq 1 `
        -and [string]$remoteLines[0] -ceq $ExpectedHead) "targeted_diagnostic_remote_checkpoint_mismatch"
    return [pscustomobject]@{
        branch = $branch
        local_head = [string]$localHeadLines[0]
        remote_head = [string]$remoteLines[0]
        remote_head_matches_local = $true
    }
}

function Assert-ColdRestoreTargetedDiagnosticPostClaimBoundary {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedProjectPath,
        [Parameter(Mandatory = $true)][string]$ExpectedHead,
        [Parameter(Mandatory = $true)]$DiagnosticQuota,
        [Parameter(Mandatory = $true)][string]$EvidenceRoot
    )

    $runtimeFreeze = Get-ColdRestoreRuntimeFreezeObservation $ResolvedProjectPath $ExpectedHead
    $null = Assert-ColdRestoreRuntimeFreezeGreen `
        $runtimeFreeze "targeted_diagnostic_postclaim_runtime_not_frozen"
    Assert-ColdRestoreCondition ([IO.File]::Exists($AuthorizationContractPath) `
        -and (Get-FileHash -LiteralPath $AuthorizationContractPath -Algorithm SHA256).Hash.ToLowerInvariant() `
            -ceq $AuthorizationContractSha256) "targeted_diagnostic_authorization_contract_changed"
    $checkpoint = Assert-ColdRestoreTargetedDiagnosticRemoteCheckpoint `
        $ResolvedProjectPath $ExpectedHead
    $officialBoundary = Assert-ColdRestoreOfficialAttemptBoundary $ResolvedProjectPath
    $gitCommonDirectory = Resolve-ColdRestoreGitCommonDirectory $ResolvedProjectPath
    $previousLedgerPath = Join-Path $gitCommonDirectory $PreviousTargetedOwnerCaptureQuotaLedgerRelativePath
    $exhaustedV2LedgerPath = Join-Path $gitCommonDirectory $ExhaustedTargetedOwnerCaptureQuotaLedgerRelativePath
    $expectedQuotaPath = Join-Path $gitCommonDirectory $TargetedOwnerCaptureQuotaLedgerRelativePath
    $expectedEvidenceRoot = Join-Path $gitCommonDirectory $TargetedOwnerCaptureEvidenceRootRelativePath
    Assert-ColdRestoreCondition ([bool]$checkpoint.remote_head_matches_local `
        -and [bool]$officialBoundary.attempt_1_valid `
        -and [bool]$officialBoundary.attempt_2_absent `
        -and [IO.File]::Exists($previousLedgerPath) `
        -and (Get-FileHash -LiteralPath $previousLedgerPath -Algorithm SHA256).Hash.ToLowerInvariant() `
            -ceq $PreviousTargetedOwnerCaptureQuotaLedgerSha256 `
        -and -not [IO.File]::Exists($exhaustedV2LedgerPath) `
        -and [IO.Path]::GetFullPath([string]$DiagnosticQuota.path) -ceq [IO.Path]::GetFullPath($expectedQuotaPath) `
        -and [IO.File]::Exists([string]$DiagnosticQuota.path) `
        -and (Get-FileHash -LiteralPath ([string]$DiagnosticQuota.path) -Algorithm SHA256).Hash.ToLowerInvariant() `
            -ceq [string]$DiagnosticQuota.fingerprint `
        -and [IO.Path]::GetFullPath($EvidenceRoot) -ceq [IO.Path]::GetFullPath($expectedEvidenceRoot) `
        -and [IO.Directory]::Exists($EvidenceRoot)) "targeted_diagnostic_postclaim_boundary_changed"
    return $true
}

function Assert-ColdRestoreRuntimeFreezeGreen {
    param(
        [Parameter(Mandatory = $true)]$Observation,
        [Parameter(Mandatory = $true)][string]$FailureCode
    )

    Assert-ColdRestoreCondition ([int]$Observation.schema_version -eq 1 `
        -and [string]$Observation.observation_id -ceq "ColdRestoreRuntimeFreezeObservationV1" `
        -and [bool]$Observation.head_query_green `
        -and [bool]$Observation.head_matches `
        -and [bool]$Observation.status_query_green `
        -and [bool]$Observation.tree_clean `
        -and [int]$Observation.dirty_path_count -eq 0 `
        -and [bool]$Observation.git_diff_check_green `
        -and [int]$Observation.git_diff_check_issue_count -eq 0 `
        -and [string]$Observation.evidence_fingerprint -ceq (cold_restore_attested_process\Get-ColdRestoreEvidenceFingerprint $Observation "evidence_fingerprint")) $FailureCode
    return $true
}

function Test-ColdRestoreTargetedDiagnosticTimeline {
    param([AllowNull()]$Timeline)

    if ($null -eq $Timeline) {
        return $false
    }
    $rows = @($Timeline.phase_rows)
    $notApplicablePhaseIds = @(
        "save_intent_submitted",
        "save_capture_complete",
        "envelope_encode_complete",
        "atomic_write_complete",
        "save_readback_complete"
    )
    if ($rows.Count -ne 19) {
        return $false
    }
    foreach ($phaseId in $notApplicablePhaseIds) {
        $matches = @($rows | Where-Object { [string]$_.phase_id -ceq $phaseId })
        if ($matches.Count -ne 1 `
            -or [bool]$matches[0].success `
            -or [string]$matches[0].reason_code -cne "not_applicable_targeted_diagnostic") {
            return $false
        }
    }
    $unexpectedFailures = @($rows | Where-Object {
        -not [bool]$_.success -and $notApplicablePhaseIds -cnotcontains [string]$_.phase_id
    })
    return $unexpectedFailures.Count -eq 0
}

function Write-ColdRestoreProcessARehearsalOutcome {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedProjectPath,
        [Parameter(Mandatory = $true)][string]$HeadSha,
        [Parameter(Mandatory = $true)]$Admission,
        [Parameter(Mandatory = $true)]$Evidence,
        [Parameter(Mandatory = $true)][string]$TerminalStage,
        [Parameter(Mandatory = $true)][string]$TerminalCode,
        [Parameter(Mandatory = $true)][bool]$Success
    )

    $safeTerminalCode = if ($TerminalCode -cmatch '^[a-z0-9_]{1,128}$') { $TerminalCode } else { "process_a_rehearsal_unknown_failure" }
    Assert-ColdRestoreCondition ($TerminalStage -cmatch '^[a-z0-9_]{1,64}$') "process_a_rehearsal_outcome_terminal_stage_invalid"
    Assert-ColdRestoreCondition ((-not $Success -and $safeTerminalCode -cne "ok") -or ($Success -and $safeTerminalCode -ceq "ok")) "process_a_rehearsal_outcome_terminal_code_invalid"
    Assert-ColdRestoreCondition ([string]$Admission.fingerprint -cmatch '^[0-9a-f]{64}$' `
        -and [string]$Admission.value.authorization_id -ceq $ProcessARehearsalAuthorizationId) "process_a_rehearsal_outcome_admission_invalid"
    $gitCommonDirectory = Resolve-ColdRestoreGitCommonDirectory $ResolvedProjectPath
    $outcomePath = Join-Path $gitCommonDirectory $ProcessARehearsalOutcomeLedgerRelativePath
    $officialBoundary = Get-ColdRestoreOfficialAttemptBoundaryObservation $ResolvedProjectPath
    Assert-ColdRestoreCondition (-not [bool]$Evidence.official `
        -and -not [bool]$Evidence.official_attempt_2_authorization_consumed) "process_a_rehearsal_outcome_official_boundary_invalid"
    if ($Success) {
        Assert-ColdRestoreCondition ([bool]$officialBoundary.attempt_1_valid `
            -and [int]$officialBoundary.claim_count -eq 1 `
            -and [bool]$officialBoundary.attempt_2_absent) "process_a_rehearsal_outcome_official_boundary_invalid"
        Assert-ColdRestoreCondition ([string]$Evidence.rehearsal_green_head -ceq $HeadSha `
            -and [bool]$Evidence.rehearsal_green_tree_clean `
            -and [bool]$Evidence.rehearsal_green_git_diff_check_green `
            -and [string]$Evidence.rehearsal_green_freeze_fingerprint -cmatch '^[0-9a-f]{64}$') "process_a_rehearsal_outcome_runtime_freeze_invalid"
    }

    $launchAttestationSha256 = Get-ColdRestoreOptionalFileSha256 ([string]$Evidence.launch_attestation_path)
    $childAttestationSha256 = Get-ColdRestoreOptionalFileSha256 ([string]$Evidence.child_attestation_path)
    $parentAttestationSha256 = Get-ColdRestoreOptionalFileSha256 ([string]$Evidence.parent_attestation_path)
    $stdoutSha256 = Get-ColdRestoreOptionalFileSha256 ([string]$Evidence.stdout_path)
    $stderrSha256 = Get-ColdRestoreOptionalFileSha256 ([string]$Evidence.stderr_path)
    $manifestSha256 = Get-ColdRestoreOptionalFileSha256 ([string]$Evidence.manifest_path)
    $phaseTimelineSha256 = Get-ColdRestoreOptionalFileSha256 ([string]$Evidence.phase_timeline_path)
    $completionSha256 = Get-ColdRestoreOptionalFileSha256 ([string]$Evidence.completion_path)
    $ledger = [ordered]@{
        schema_version = 1
        outcome_id = "ProcessARehearsalOutcomeLedgerV1"
        created_at_utc = [DateTime]::UtcNow.ToString("O", [Globalization.CultureInfo]::InvariantCulture)
        authorization_id = $ProcessARehearsalAuthorizationId
        run_id = $RunId
        repository_head = $HeadSha
        scenario_fingerprint = $ExpectedScenarioFingerprint
        official = $false
        formal = $false
        official_attempt_2_claim_present = [bool]$officialBoundary.attempt_2_claim_present
        official_attempt_2_authorization_consumed = $false
        rehearsal_admission_consumed = $true
        admission_ledger_sha256 = [string]$Admission.fingerprint
        rehearsal_green_head = [string]$Evidence.rehearsal_green_head
        rehearsal_green_tree_clean = [bool]$Evidence.rehearsal_green_tree_clean
        rehearsal_green_git_diff_check_green = [bool]$Evidence.rehearsal_green_git_diff_check_green
        rehearsal_green_freeze_fingerprint = [string]$Evidence.rehearsal_green_freeze_fingerprint
        launch_attestation_present = ($launchAttestationSha256 -cne "")
        launch_attestation_sha256 = $launchAttestationSha256
        child_attestation_present = ($childAttestationSha256 -cne "")
        child_attestation_sha256 = $childAttestationSha256
        parent_attestation_present = ($parentAttestationSha256 -cne "")
        parent_attestation_sha256 = $parentAttestationSha256
        stdout_present = ($stdoutSha256 -cne "")
        stdout_sha256 = $stdoutSha256
        stderr_present = ($stderrSha256 -cne "")
        stderr_sha256 = $stderrSha256
        manifest_present = ($manifestSha256 -cne "")
        manifest_sha256 = $manifestSha256
        phase_timeline_present = ($phaseTimelineSha256 -cne "")
        phase_timeline_sha256 = $phaseTimelineSha256
        completion_present = ($completionSha256 -cne "")
        completion_sha256 = $completionSha256
        wrapper_result_present = [bool]$Evidence.wrapper_result_present
        observed_exit = [bool]$Evidence.observed_exit
        exit_code_observed = [bool]$Evidence.exit_code_observed
        exit_code = [int]$Evidence.exit_code
        timed_out = [bool]$Evidence.timed_out
        terminated_by_parent = [bool]$Evidence.terminated_by_parent
        task_owned_process_count_after = [int]$Evidence.task_owned_process_count_after
        terminal_stage = $TerminalStage
        success = $Success
        terminal_code = $safeTerminalCode
        evidence_fingerprint = ""
    }
    $ledger.evidence_fingerprint = cold_restore_attested_process\Get-ColdRestoreEvidenceFingerprint ([pscustomobject]$ledger)
    $canonicalLedger = cold_restore_attested_process\ConvertTo-ColdRestoreCanonicalJson ([pscustomobject]$ledger)
    if ([IO.File]::Exists($outcomePath)) {
        $existingLedger = [IO.File]::ReadAllText($outcomePath, [Text.UTF8Encoding]::new($false))
        if ($existingLedger -ceq $canonicalLedger) {
            throw "process_a_rehearsal_outcome_already_written"
        }
        throw "process_a_rehearsal_outcome_collision"
    }
    try {
        $outcomeSha256 = process_a_rehearsal_admission_contract\Write-ProcessARehearsalExclusiveAtomicJson $outcomePath ([pscustomobject]$ledger)
    }
    catch {
        if ([IO.File]::Exists($outcomePath)) {
            $existingLedger = [IO.File]::ReadAllText($outcomePath, [Text.UTF8Encoding]::new($false))
            if ($existingLedger -ceq $canonicalLedger) {
                throw "process_a_rehearsal_outcome_already_written"
            }
            throw "process_a_rehearsal_outcome_collision"
        }
        throw "process_a_rehearsal_outcome_write_failed"
    }
    return [pscustomobject]@{
        path = $outcomePath
        fingerprint = $outcomeSha256
        value = [pscustomobject]$ledger
    }
}

function Read-ColdRestoreRoleTimeoutPolicy {
    param([Parameter(Mandatory = $true)][string]$Path)

    $resolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    $raw = Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8
    try {
        $policy = $raw | ConvertFrom-Json
    }
    catch {
        throw "role_timeout_policy_json_invalid"
    }
    Assert-ColdRestoreCondition (Test-ExactFieldSet $policy $RoleTimeoutPolicyFields) "role_timeout_policy_field_set_invalid"
    Assert-ColdRestoreCondition ([int]$policy.schema_version -eq 1 `
        -and [string]$policy.policy_id -ceq "ColdRestoreRoleTimeoutPolicyV1" `
        -and [string]$policy.policy_source -cmatch '^[a-z0-9_]{1,128}$' `
        -and [string]$policy.measurement_head -cmatch '^[0-9a-f]{40,64}$' `
        -and [string]$policy.measurement_run_id -cmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,95}$' `
        -and [int]$policy.poll_interval_ms -ge 25 -and [int]$policy.poll_interval_ms -le 1000 `
        -and [int]$policy.normal_exit_grace_seconds -ge 1 -and [int]$policy.normal_exit_grace_seconds -le 30 `
        -and [int]$policy.stream_drain_grace_seconds -ge 1 -and [int]$policy.stream_drain_grace_seconds -le 30 `
        -and [int]$policy.process_tree_cleanup_grace_seconds -ge 1 -and [int]$policy.process_tree_cleanup_grace_seconds -le 30) "role_timeout_policy_header_invalid"
    $expectedHeartbeatFields = @(
        "phase", "world_time", "owner_index", "queue_revision", "save_phase",
        "last_evidence_write_time"
    )
    Assert-ColdRestoreCondition (@(Compare-Object $expectedHeartbeatFields @($policy.progress_heartbeat_fields) -SyncWindow 0).Count -eq 0) "role_timeout_policy_heartbeat_fields_invalid"
    $expectedRoles = @("targeted_owner_diagnostic", "process_a", "process_b", "process_c")
    Assert-ColdRestoreCondition (Test-ExactFieldSet $policy.roles $expectedRoles) "role_timeout_policy_role_set_invalid"
    $caps = @{
        targeted_owner_diagnostic = 120
        process_a = 300
        process_b = 480
        process_c = 180
    }
    foreach ($roleId in $expectedRoles) {
        $rolePolicy = $policy.roles.$roleId
        Assert-ColdRestoreCondition (Test-ExactFieldSet $rolePolicy $RoleTimeoutFields) "role_timeout_policy_role_field_set_invalid"
        Assert-ColdRestoreCondition ([int]$rolePolicy.absolute_timeout_seconds -gt 0 `
            -and [int]$rolePolicy.absolute_timeout_seconds -le [int]$caps[$roleId] `
            -and [int]$rolePolicy.no_progress_timeout_seconds -gt 0 `
            -and [int]$rolePolicy.no_progress_timeout_seconds -lt [int]$rolePolicy.absolute_timeout_seconds `
            -and [string]$rolePolicy.timeout_reason_code -ceq "${roleId}_timeout" `
            -and [string]$rolePolicy.cleanup_policy -ceq "kill_task_tree_then_verify_pid_and_creation_time" `
            -and $rolePolicy.contract_only_in_this_task -is [bool] `
            -and -not [bool]$rolePolicy.contract_only_in_this_task) "role_timeout_policy_role_invalid"
    }
    return [pscustomobject]@{
        path = $resolvedPath
        sha256 = (Get-FileHash -LiteralPath $resolvedPath -Algorithm SHA256).Hash.ToLowerInvariant()
        policy = $policy
    }
}

function Get-ColdRestoreRoleTimeout {
    param([Parameter(Mandatory = $true)][ValidateSet("targeted_owner_diagnostic", "process_a", "process_b", "process_c")][string]$RoleId)
    Assert-ColdRestoreCondition ($null -ne $RoleTimeoutPolicyEvidence) "role_timeout_policy_not_loaded"
    $rolePolicy = $RoleTimeoutPolicyEvidence.policy.roles.$RoleId
    return [pscustomobject]@{
        role_id = $RoleId
        absolute_timeout_seconds = [int]$rolePolicy.absolute_timeout_seconds
        no_progress_timeout_seconds = [int]$rolePolicy.no_progress_timeout_seconds
        timeout_reason_code = [string]$rolePolicy.timeout_reason_code
        heartbeat_directory_name = "$RoleId.heartbeat.events"
    }
}

function Test-ColdRestoreTaggedInt64 {
    param([Parameter(Mandatory = $true)]$Value)
    return $null -ne $Value `
        -and (Test-ExactFieldSet $Value @('$codec', 'value')) `
        -and [string]$Value.'$codec' -ceq "Int64" `
        -and [string]$Value.value -cmatch '^-?(0|[1-9][0-9]{0,18})$'
}

function Assert-ColdRestoreTargetedDiagnosticV2 {
    param(
        [Parameter(Mandatory = $true)]$Diagnostic,
        [Parameter(Mandatory = $true)][string]$HeadSha,
        [string]$ExpectedDiagnosticRunId = $RunId
    )
    Assert-ColdRestoreCondition (Test-ExactFieldSet $Diagnostic $TargetedDiagnosticV2Fields) "targeted_owner_capture_v2_field_set_invalid"
    Assert-ColdRestoreCondition ([int]$Diagnostic.schema_version -eq 2 `
        -and [string]$Diagnostic.diagnostic_id -ceq "TargetedOwnerCaptureDiagnosticV2" `
        -and [string]$Diagnostic.run_id -ceq $ExpectedDiagnosticRunId `
        -and [string]$Diagnostic.repository_head -ceq $HeadSha `
        -and -not [bool]$Diagnostic.official `
        -and -not [bool]$Diagnostic.formal `
        -and -not [bool]$Diagnostic.save_file_exists `
        -and -not [bool]$Diagnostic.official_claim_path_present `
        -and [string]$Diagnostic.evidence_fingerprint -cmatch '^[0-9a-f]{64}$') "targeted_owner_capture_v2_header_invalid"
    Assert-ColdRestoreCondition (Test-ExactFieldSet $Diagnostic.diagnostic_phase_timeline $TargetedDiagnosticTimelineFields) "targeted_owner_capture_v2_timeline_field_set_invalid"
    $timeline = $Diagnostic.diagnostic_phase_timeline
    Assert-ColdRestoreCondition ([int]$timeline.schema_version -eq 1 `
        -and [string]$timeline.timeline_id -ceq "TargetedOwnerCaptureDiagnosticPhaseTimelineV1" `
        -and [string]$timeline.run_id -ceq $ExpectedDiagnosticRunId `
        -and [string]$timeline.repository_head -ceq $HeadSha `
        -and [string]$timeline.last_completed_phase -ceq "diagnostic_completed" `
        -and [string]$timeline.current_phase -ceq "diagnostic_completed" `
        -and [string]$timeline.next_expected_phase -ceq "none" `
        -and [string]$timeline.evidence_fingerprint -cmatch '^[0-9a-f]{64}$') "targeted_owner_capture_v2_timeline_invalid"
    $sequence = 0
    $lastMonotonic = -1
    foreach ($phaseRow in @($timeline.phase_rows)) {
        $sequence += 1
        Assert-ColdRestoreCondition (Test-ExactFieldSet $phaseRow $TargetedDiagnosticPhaseRowFields) "targeted_owner_capture_v2_phase_row_field_set_invalid"
        Assert-ColdRestoreCondition ([int]$phaseRow.sequence -eq $sequence `
            -and [string]$phaseRow.phase_id -in @(
                "diagnostic_started", "session_creating", "session_started",
                "scenario_identity_attesting", "scenario_identity_attested",
                "registry_binding_attesting", "registry_binding_attested",
                "owner_audit_started", "owner_capture_started", "owner_capture_succeeded",
                "owner_capture_failed", "owner_audit_completed", "diagnostic_completed"
            ) `
            -and [int64]$phaseRow.completed_monotonic_ms -ge $lastMonotonic `
            -and [string]$phaseRow.reason_code -cmatch '^[a-z0-9_]{1,128}$' `
            -and [string]$phaseRow.evidence_fingerprint -cmatch '^[0-9a-f]{64}$') "targeted_owner_capture_v2_phase_row_invalid"
        $lastMonotonic = [int64]$phaseRow.completed_monotonic_ms
    }
    Assert-ColdRestoreCondition ([string]$Diagnostic.last_completed_diagnostic_phase -ceq [string]$timeline.last_completed_phase `
        -and [string]$Diagnostic.current_diagnostic_phase -ceq [string]$timeline.current_phase `
        -and [string]$Diagnostic.next_expected_diagnostic_phase -ceq [string]$timeline.next_expected_phase) "targeted_owner_capture_v2_timeline_binding_invalid"

    $identityFailureFields = @(
        $Diagnostic.scenario_identity_failure.PSObject.Properties |
            ForEach-Object { [string]$_.Name }
    )
    if ([bool]$Diagnostic.scenario_identity_attested) {
        Assert-ColdRestoreCondition (Test-ExactFieldSet $Diagnostic.scenario_identity $DiagnosticScenarioIdentityFields) "targeted_owner_capture_v2_identity_field_set_invalid"
        $identity = $Diagnostic.scenario_identity
        Assert-ColdRestoreCondition ([int]$identity.schema_version -eq 1 `
            -and [string]$identity.identity_id -ceq "DiagnosticScenarioIdentityV1" `
            -and [string]$identity.run_id -ceq $ExpectedDiagnosticRunId `
            -and [string]$identity.repository_head -ceq $HeadSha `
            -and [string]$identity.ruleset_id -ceq "v0.6" `
            -and [int]$identity.challenge_depth -eq 1 `
            -and (Test-ColdRestoreTaggedInt64 $identity.run_seed_tagged_int64) `
            -and [string]$identity.run_seed_tagged_int64.value -ceq "900626424" `
            -and (Test-ColdRestoreTaggedInt64 $identity.session_seed_tagged_int64) `
            -and [string]$identity.scenario_fingerprint -ceq $ExpectedScenarioFingerprint `
            -and [int]$identity.local_player_count -eq 1 `
            -and [int]$identity.ai_player_count -eq 3 `
            -and [string]$identity.diagnostic_role -ceq "targeted_owner_diagnostic" `
            -and [string]$identity.identity_fingerprint -cmatch '^[0-9a-f]{64}$') "targeted_owner_capture_v2_identity_invalid"
    }
    Assert-ColdRestoreCondition ($Diagnostic.registry_binding_attested -is [bool] `
        -and [bool]$Diagnostic.registry_binding_attested -eq (
            @($timeline.phase_rows | Where-Object {
                [string]$_.phase_id -ceq "registry_binding_attested"
            }).Count -eq 1
        )) "targeted_owner_capture_v2_registry_binding_invalid"
    if ([bool]$Diagnostic.harness_or_scenario_failure_attested) {
        Assert-ColdRestoreCondition (-not [bool]$Diagnostic.owner_audit_started `
            -and $identityFailureFields.Count -gt 0 `
            -and (Test-ExactFieldSet $Diagnostic.scenario_identity_failure $DiagnosticScenarioFailureFields) `
            -and [bool]$Diagnostic.scenario_identity_failure.private_payload_redacted) "targeted_owner_capture_v2_pre_owner_failure_invalid"
    }

    $ownerRows = @($Diagnostic.owner_capture_rows)
    $firstFailureFields = @(
        $Diagnostic.first_failure.PSObject.Properties | ForEach-Object { [string]$_.Name }
    )
    $postFailureFields = @(
        $Diagnostic.post_capture_failure.PSObject.Properties | ForEach-Object { [string]$_.Name }
    )
    if ([bool]$Diagnostic.owner_audit_started) {
        Assert-ColdRestoreCondition ([bool]$Diagnostic.scenario_identity_attested `
            -and [bool]$Diagnostic.owner_audit_completed `
            -and [int]$Diagnostic.first_owner_capture_index -eq 0 `
            -and $ownerRows.Count -eq 19) "targeted_owner_capture_v2_owner_audit_shape_invalid"
        $attempted = 0
        $succeeded = 0
        $failed = 0
        $skipped = 0
        foreach ($ownerIndex in 0..18) {
            $row = $ownerRows[$ownerIndex]
            Assert-ColdRestoreCondition (Test-ExactFieldSet $row $TargetedDiagnosticOwnerRowFields) "targeted_owner_capture_v2_owner_row_field_set_invalid"
            Assert-ColdRestoreCondition ([int]$row.owner_index -eq $ownerIndex `
                -and [string]$row.section_id -ceq $SaveSectionOrder[$ownerIndex] `
                -and [string]$row.owner_id -ceq $SaveOwnerOrder[$ownerIndex] `
                -and [string]$row.owner_path -cmatch '^[A-Za-z0-9_./-]{1,256}$' `
                -and [string]$row.capture_result_kind -in @("CAPTURED", "FAILED", "NOT_ATTEMPTED_AFTER_FIRST_FAILURE") `
                -and [int]$row.state_version -ge -1 `
                -and [int64]$row.elapsed_milliseconds -ge 0 `
                -and [int]$row.mutation_count -ge 0 `
                -and [bool]$row.private_payload_redacted `
                -and [string]$row.row_evidence_fingerprint -cmatch '^[0-9a-f]{64}$') "targeted_owner_capture_v2_owner_row_invalid"
            switch ([string]$row.capture_result_kind) {
                "CAPTURED" { $attempted += 1; $succeeded += 1 }
                "FAILED" { $attempted += 1; $failed += 1 }
                default { $skipped += 1 }
            }
        }
        Assert-ColdRestoreCondition ([int]$Diagnostic.owner_capture_attempted_count -eq $attempted `
            -and [int]$Diagnostic.owner_capture_succeeded_count -eq $succeeded `
            -and [int]$Diagnostic.owner_capture_failed_count -eq $failed `
            -and [int]$Diagnostic.owner_capture_skipped_count -eq $skipped) "targeted_owner_capture_v2_owner_count_invalid"
        if ($failed -eq 1) {
            Assert-ColdRestoreCondition ($firstFailureFields.Count -gt 0 `
                -and (Test-OwnerCaptureFailureIdentity $Diagnostic.first_failure) `
                -and [bool]$Diagnostic.owner_capture_failure_attested `
                -and $postFailureFields.Count -eq 0 `
                -and [string]$Diagnostic.post_capture_validation -ceq "NOT_RUN_AFTER_OWNER_FAILURE") "targeted_owner_capture_v2_first_failure_invalid"
        }
        elseif ($failed -eq 0) {
            Assert-ColdRestoreCondition ($succeeded -eq 19 `
                -and $firstFailureFields.Count -eq 0 `
                -and -not [bool]$Diagnostic.owner_capture_failure_attested) "targeted_owner_capture_v2_all_owner_result_invalid"
            if ($postFailureFields.Count -gt 0) {
                Assert-ColdRestoreCondition ((Test-OwnerCaptureFailureIdentity $Diagnostic.post_capture_failure) `
                    -and [string]$Diagnostic.post_capture_validation -ceq "FAILED") "targeted_owner_capture_v2_post_failure_invalid"
            }
            else {
                Assert-ColdRestoreCondition ([string]$Diagnostic.post_capture_validation -ceq "PASSED") "targeted_owner_capture_v2_post_validation_invalid"
            }
        }
        else {
            throw "targeted_owner_capture_v2_failure_count_invalid"
        }
    }
    else {
        Assert-ColdRestoreCondition ($ownerRows.Count -eq 0 `
            -and $firstFailureFields.Count -eq 0 `
            -and $postFailureFields.Count -eq 0 `
            -and [bool]$Diagnostic.harness_or_scenario_failure_attested) "targeted_owner_capture_v2_pre_owner_payload_invalid"
    }
}

function Assert-ColdRestoreProcessARehearsalCompletion {
    param(
        [Parameter(Mandatory = $true)]$Completion,
        [Parameter(Mandatory = $true)][string]$HeadSha,
        [Parameter(Mandatory = $true)][string]$AuthorizationFingerprint
    )
    Assert-ColdRestoreCondition (Test-ExactFieldSet $Completion $ProcessARehearsalCompletionFields) "process_a_rehearsal_completion_field_set_invalid"
    Assert-ColdRestoreCondition ([int]$Completion.schema_version -eq 1 `
        -and [string]$Completion.completion_id -ceq "ProcessARehearsalCompletionV1" `
        -and [string]$Completion.run_id -ceq $RunId `
        -and [string]$Completion.repository_head -ceq $HeadSha `
        -and [string]$Completion.scenario_fingerprint -ceq $ExpectedScenarioFingerprint `
        -and [bool]$Completion.rehearsal_only `
        -and -not [bool]$Completion.official `
        -and -not [bool]$Completion.formal `
        -and -not [bool]$Completion.official_attempt_claim_created `
        -and -not [bool]$Completion.official_authorization_consumed `
        -and [string]$Completion.authorization_fingerprint -ceq $AuthorizationFingerprint `
        -and [string]$Completion.timeout_policy_fingerprint -ceq [string]$RoleTimeoutPolicyEvidence.sha256 `
        -and [bool]$Completion.restore_barrier_entered `
        -and [bool]$Completion.restore_barrier_quiet `
        -and [bool]$Completion.restore_barrier_released `
        -and [int]$Completion.save_owner_capture_count -eq 19 `
        -and [int]$Completion.save_section_count -eq 19 `
        -and [int]$Completion.save_preflight_count -eq 19 `
        -and [int]$Completion.capture_operation_sequence -gt 0 `
        -and [string]$Completion.captured_sections_fingerprint -cmatch '^[0-9a-f]{64}$' `
        -and [string]$Completion.readback_sections_fingerprint -ceq [string]$Completion.captured_sections_fingerprint `
        -and [int]$Completion.save_capture_world_delta -eq 0 `
        -and [int]$Completion.save_capture_rng_delta -eq 0 `
        -and [int]$Completion.save_capture_public_log_delta -eq 0 `
        -and [bool]$Completion.envelope_encode_green `
        -and [bool]$Completion.atomic_write_green `
        -and [bool]$Completion.save_readback_green `
        -and [bool]$Completion.save_fingerprint_parity `
        -and [string]$Completion.save_capture_fingerprint -cmatch '^[0-9a-f]{64}$' `
        -and [string]$Completion.save_readback_fingerprint -ceq [string]$Completion.save_capture_fingerprint `
        -and [int64]$Completion.save_file_bytes -gt 0 `
        -and [string]$Completion.save_file_sha256 -cmatch '^[0-9a-f]{64}$' `
        -and [int]$Completion.queue_entry_count -eq 1 `
        -and [string]$Completion.evidence_fingerprint -cmatch '^[0-9a-f]{64}$') "process_a_rehearsal_completion_not_green"
}

function Assert-ColdRestoreQualificationResult {
    param(
        [Parameter(Mandatory = $true)]$Result,
        [Parameter(Mandatory = $true)]$Child,
        [Parameter(Mandatory = $true)][string]$HeadSha
    )
    Assert-ColdRestoreCondition (Test-ExactFieldSet $Result $QualificationResultFields) "qualification_result_field_set_invalid"
    Assert-ColdRestoreCondition ([int]$Result.schema_version -eq 1) "qualification_result_schema_invalid"
    Assert-ColdRestoreCondition ([bool]$Result.qualification_probe `
        -and -not [bool]$Result.official_cold_restore_vertical_slice `
        -and -not [bool]$Result.formal_full_run `
        -and -not [bool]$Result.save_written) "qualification_mode_binding_invalid"
    Assert-ColdRestoreCondition ([string]$Result.run_id -eq $RunId) "qualification_result_run_id_mismatch"
    Assert-ColdRestoreCondition ([int]$Result.challenge_depth -eq 1 `
        -and [int64]$Result.seed -eq 900626424) "qualification_configuration_mismatch"
    Assert-ColdRestoreCondition ([string]$Result.scenario_fingerprint -match '^[0-9a-f]{64}$') "qualification_scenario_fingerprint_invalid"
    Assert-ColdRestoreCondition ([string]$Result.queue_trigger_actor -in @("local", "ai", "none")) "qualification_actor_invalid"
    Assert-ColdRestoreCondition ((Test-NonnegativeInteger $Result.queue_count) `
        -and (Test-NonnegativeInteger $Result.queue_revision)) "qualification_queue_count_invalid"
    Assert-ColdRestoreCondition (Test-ExactFieldSet $Result.offer_audit @("legal_offers", "queue_capable_offers", "rejected_offers")) "qualification_offer_audit_invalid"
    Assert-ColdRestoreCondition ($Result.offer_audit.legal_offers -is [System.Array] `
        -and $Result.offer_audit.queue_capable_offers -is [System.Array] `
        -and $Result.offer_audit.rejected_offers -is [System.Array]) "qualification_offer_audit_invalid"
    Assert-ColdRestoreCondition (([bool]$Result.success `
            -and [int]$Result.queue_count -ge 1 `
            -and [string]$Result.product_blocker -eq "") `
        -or (-not [bool]$Result.success `
            -and [string]$Result.product_blocker -match '^BLOCKED_BY_[A-Z0-9_]{1,192}$')) "qualification_product_binding_invalid"
    Assert-ColdRestoreCondition ([string]$Child.repository_head -eq $HeadSha `
        -and [string]$Child.scenario_fingerprint -eq [string]$Result.scenario_fingerprint `
        -and [bool]$Child.qualification_green -eq [bool]$Result.success `
        -and [string]$Child.product_blocker -eq [string]$Result.product_blocker `
        -and [int]$Child.queue_count -eq [int]$Result.queue_count `
        -and [int]$Child.queue_revision -eq [int]$Result.queue_revision `
        -and [string]$Child.queue_trigger_actor -eq [string]$Result.queue_trigger_actor `
        -and [string]$Child.queue_trigger_semantic_action_id -eq [string]$Result.queue_trigger_semantic_action_id `
        -and [string]$Child.queue_trigger_card_semantic_id -eq [string]$Result.queue_trigger_card_semantic_id `
        -and [string]$Child.queue_trigger_target_fingerprint -eq [string]$Result.queue_trigger_target_fingerprint) "qualification_child_result_binding_invalid"
    Assert-ColdRestoreCondition (-not [bool]$Child.official `
        -and -not [bool]$Child.formal `
        -and -not [bool]$Child.save_written `
        -and -not [bool]$Child.official_count_consumed `
        -and [int]$Child.direct_authority_mutation_count -eq 0 `
        -and [int]$Child.queue_injection_count -eq 0) "qualification_forbidden_mutation_evidence_invalid"
}

function New-ColdRestoreQualificationOutput {
    param(
        [Parameter(Mandatory = $true)]$Run,
        [Parameter(Mandatory = $true)]$Result
    )
    $productGreen = [bool]$Result.success
    return [ordered]@{
        schema_version = 1
        driver_id = "alpha04c_cold_restore_qualification_attested_v1"
        formal_full_run = $false
        official_cold_restore_vertical_slice = $false
        run_id = $RunId
        child_completion_attestation_green = [bool]$Run.parent.child_attestation_valid
        parent_exit_attestation_green = [bool]$Run.parent.wrapper_exit_green
        wrapper_exit_attestation_green = [bool]$Run.wrapper_exit_green
        wrapper_execution_status = $(if ([bool]$Run.wrapper_exit_green) { "GREEN" } else { "FAILED" })
        wrapper_reason_code = [string]$Run.wrapper_reason_code
        product_qualification_status = $(if ($productGreen) { "GREEN" } else { "BLOCKED" })
        product_queue_qualification_green = $productGreen
        product_blocker = [string]$Result.product_blocker
        challenge_depth = [int]$Result.challenge_depth
        seed = [int64]$Result.seed
        scenario_fingerprint = [string]$Result.scenario_fingerprint
        queue_count = [int]$Result.queue_count
        queue_revision = [int]$Result.queue_revision
        queue_trigger_actor = [string]$Result.queue_trigger_actor
        queue_trigger_semantic_action_id = [string]$Result.queue_trigger_semantic_action_id
        queue_trigger_card_semantic_id = [string]$Result.queue_trigger_card_semantic_id
        queue_trigger_target_fingerprint = [string]$Result.queue_trigger_target_fingerprint
        legal_offer_count = @($Result.offer_audit.legal_offers).Count
        queue_capable_offer_count = @($Result.offer_audit.queue_capable_offers).Count
        rejected_offer_count = @($Result.offer_audit.rejected_offers).Count
        task_owned_process_count_after = [int]$Run.parent.task_owned_process_count_after
        unrelated_preexisting_process_count = [int]$Run.parent.unrelated_preexisting_process_count
        success = [bool]$Run.wrapper_exit_green
        failure_code = $(if ([bool]$Run.wrapper_exit_green) { "" } else { [string]$Run.wrapper_reason_code })
    }
}

function Invoke-ColdRestoreQualification {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedProjectPath,
        [Parameter(Mandatory = $true)][string]$HeadSha
    )
    $paths = Get-ColdRestoreRolePaths $ResolvedProjectPath "qualification"
    $timeout = Get-ColdRestoreRoleTimeout "process_a"
    $arguments = cold_restore_attested_process\New-ColdRestoreGodotArgumentList `
        -EngineArgumentList @("--headless", "--path", $ResolvedProjectPath, "--script", $DriverScript) `
        -UserArgumentList @(
            "--cold-restore-qualification-probe",
            "--cold-restore-role=qualification",
            "--cold-restore-run-id=$RunId",
            "--cold-restore-head-sha=$HeadSha",
            "--cold-restore-artifact-root=$ArtifactRoot"
        )
    $run = cold_restore_attested_process\Invoke-ColdRestoreAttestedProcess `
        -ExecutablePath $GodotPath `
        -WorkingDirectory $ResolvedProjectPath `
        -ArgumentList $arguments `
        -RunId $RunId `
        -Role "qualification" `
        -RepositoryHead $HeadSha `
        -ChildAttestationPath $paths.child_attestation `
        -ParentAttestationPath $paths.parent_attestation `
        -StdoutPath $paths.stdout `
        -StderrPath $paths.stderr `
        -TimeoutSeconds $timeout.absolute_timeout_seconds `
        -EnvironmentVariables @{ APPDATA = $IsolatedAppData; LOCALAPPDATA = $IsolatedLocalAppData }
    Assert-ColdRestoreCondition ([bool]$run.wrapper_exit_green) ([string]$run.wrapper_reason_code)
    $result = Read-ColdRestoreJsonArtifact $paths.child_result
    Assert-ColdRestoreQualificationResult $result $run.child $HeadSha
    return [pscustomobject]@{ run = $run; result = $result; paths = $paths }
}

function Invoke-ColdRestoreNonOfficialProcessA {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedProjectPath,
        [Parameter(Mandatory = $true)][string]$HeadSha
    )

    Assert-ColdRestoreCondition ($NonOfficialProcessAKind -ceq "rehearsal") "process_a_diagnostic_not_authorized"
    Assert-ColdRestoreCondition ($AuthorizedOfficialColdRestoreCount -eq 0) "process_a_rehearsal_official_authorization_forbidden"
    Assert-ColdRestoreCondition ($RunId -ceq (cold_restore_authorization_contract_v1\Get-ColdRestoreAuthorizationRunId `
            "process_a_save_completion_rehearsal_v1" $HeadSha)) "process_a_rehearsal_run_id_invalid"
    Assert-ColdRestoreCondition ($ExpectedScenarioFingerprint -ceq $TargetedOwnerCaptureScenarioFingerprint) "expected_scenario_fingerprint_invalid"
    $timeout = Get-ColdRestoreRoleTimeout "process_a"
    Assert-ColdRestoreCondition ([int]$timeout.absolute_timeout_seconds -eq 180 `
        -and [int]$timeout.no_progress_timeout_seconds -eq 60) "process_a_rehearsal_timeout_policy_invalid"
    $stage3Prerequisites = Assert-ColdRestoreProcessARehearsalPrerequisites $ResolvedProjectPath $HeadSha
    $diagnosticAdmission = Get-ColdRestoreProcessARehearsalDiagnosticAdmission $ResolvedProjectPath $HeadSha
    $diagnosticAdmission | Add-Member -NotePropertyName stage3_prerequisites -NotePropertyValue $stage3Prerequisites
    $paths = $null
    $launchAuthorization = $null
    $launchAttestationPath = ""
    $childAttestationPath = ""
    $parentAttestationPath = ""
    $stdoutPath = ""
    $stderrPath = ""
    $manifestPath = ""
    $phaseTimelinePath = ""
    $completionPath = ""
    $run = $null
    $launchEvidence = $null
    $launchLedger = $null
    $wrapperInvoked = $false
    $saveGreen = $false
    $manifest = $null
    $timeline = $null
    $savePath = ""
    $completion = $null
    $completionSha256 = ""
    $outcome = $null
    $terminalStage = "pre_wrapper_failure"
    $terminalCode = "process_a_rehearsal_pre_wrapper_failure"
    $terminalSuccess = $false
    $primaryFailure = $null
    $outcomeFailure = $null
    $postRunFreeze = $null
    $gitCommonDirectory = Resolve-ColdRestoreGitCommonDirectory $ResolvedProjectPath
    $admissionConsumed = $false
    try {
        $rehearsalAuthorization = Consume-ColdRestoreProcessARehearsalQuota $ResolvedProjectPath $HeadSha $diagnosticAdmission
        $admissionConsumed = $true
        $terminalStage = "admission_post_commit_validation_failure"
        $terminalCode = "process_a_rehearsal_admission_post_commit_validation_failed"
        $officialClaimRoot = Join-Path $gitCommonDirectory "codex\cold_restore_v3"
        $officialAttempt1ClaimPath = Join-Path $officialClaimRoot ([string]$rehearsalAuthorization.value.official_attempt_1_claim_relative_path)
        $revalidatedStage3Prerequisites = Assert-ColdRestoreProcessARehearsalPrerequisites $ResolvedProjectPath $HeadSha
        Assert-ColdRestoreCondition ([string]$revalidatedStage3Prerequisites.evidence_fingerprint `
            -ceq [string]$stage3Prerequisites.evidence_fingerprint) "process_a_rehearsal_prerequisites_changed_after_admission"
        $null = process_a_rehearsal_admission_contract\Assert-ProcessARehearsalAdmissionSourcesUnchanged `
            -Admission $rehearsalAuthorization `
            -PrerequisiteEvidenceFingerprint ([string]$revalidatedStage3Prerequisites.evidence_fingerprint) `
            -TimeoutPolicyPath $RoleTimeoutPolicyEvidence.path `
            -AdmissionEvidencePath $diagnosticAdmission.path `
            -DiagnosticQuotaLedgerPath $diagnosticAdmission.quota_ledger_path `
            -DiagnosticLaunchAttestationPath $diagnosticAdmission.launch_attestation_path `
            -DiagnosticManifestPath $diagnosticAdmission.manifest_path `
            -DiagnosticChildAttestationPath $diagnosticAdmission.child_attestation_path `
            -DiagnosticParentAttestationPath $diagnosticAdmission.parent_attestation_path `
            -DiagnosticStdoutPath $diagnosticAdmission.stdout_path `
            -DiagnosticStderrPath $diagnosticAdmission.stderr_path `
            -OfficialClaimRoot $officialClaimRoot `
            -OfficialAttempt1ClaimPath $officialAttempt1ClaimPath
        $terminalStage = "pre_wrapper_failure"
        $terminalCode = "process_a_rehearsal_pre_wrapper_failure"
        $paths = Get-ColdRestoreRolePaths $ResolvedProjectPath "producer"
        $launchAuthorization = $rehearsalAuthorization.launch_authorization
        $launchAttestationPath = Join-Path $paths.root "launch\orchestrator-$($launchAuthorization.orchestrator_process_id)\producer.authorized.json"
        $childAttestationPath = [string]$paths.child_attestation
        $parentAttestationPath = [string]$paths.parent_attestation
        $stdoutPath = [string]$paths.stdout
        $stderrPath = [string]$paths.stderr
        $manifestPath = [string]$paths.child_result
        $phaseTimelinePath = [string]$paths.phase_timeline
        $completionPath = [string]$paths.rehearsal_completion
        $arguments = cold_restore_attested_process\New-ColdRestoreGodotArgumentList `
            -EngineArgumentList @("--headless", "--path", $ResolvedProjectPath, "--script", $DriverScript) `
            -UserArgumentList @(
                "--cold-restore-non-official-process-a",
                "--cold-restore-role=producer",
                "--cold-restore-run-id=$RunId",
                "--cold-restore-head-sha=$HeadSha",
                "--cold-restore-artifact-root=$ArtifactRoot",
                "--cold-restore-scenario-fingerprint=$ExpectedScenarioFingerprint",
                "--cold-restore-timeout-policy-fingerprint=$($RoleTimeoutPolicyEvidence.sha256)",
                "--cold-restore-process-a-rehearsal",
                "--cold-restore-rehearsal-ledger-path=$($rehearsalAuthorization.path)",
                "--cold-restore-rehearsal-ledger-fingerprint=$($rehearsalAuthorization.fingerprint)",
                "--cold-restore-launch-attestation-path=$launchAttestationPath",
                "--cold-restore-launch-nonce=$($launchAuthorization.launch_nonce)"
            )
        $wrapperInvoked = $true
        $terminalStage = "wrapper_failure"
        $terminalCode = "process_a_rehearsal_wrapper_failure"
        $run = cold_restore_attested_process\Invoke-ColdRestoreAttestedProcess `
            -ExecutablePath $GodotPath `
            -WorkingDirectory $ResolvedProjectPath `
            -ArgumentList $arguments `
            -RunId $RunId `
            -Role "producer" `
            -RepositoryHead $HeadSha `
            -ChildAttestationPath $paths.child_attestation `
            -ParentAttestationPath $paths.parent_attestation `
            -StdoutPath $paths.stdout `
            -StderrPath $paths.stderr `
            -TimeoutSeconds $timeout.absolute_timeout_seconds `
            -EnvironmentVariables @{ APPDATA = $IsolatedAppData; LOCALAPPDATA = $IsolatedLocalAppData } `
            -LaunchAttestationPath $launchAttestationPath `
            -LaunchAuthorization $launchAuthorization `
            -PhaseTimelineEventDirectory $paths.phase_timeline_events `
            -PhaseTimelinePath $paths.phase_timeline `
            -TimeoutPolicy $RoleTimeoutPolicyEvidence.policy `
            -TimeoutPolicyPath $RoleTimeoutPolicyEvidence.path `
            -ExpectedPolicyFingerprint $RoleTimeoutPolicyEvidence.sha256 `
            -PolicyRole "process_a" `
            -ExpectedScenarioFingerprint $ExpectedScenarioFingerprint `
            -ProgressHeartbeatEventDirectory $paths.process_a_heartbeat_events `
            -ProgressHeartbeatPath $paths.process_a_heartbeat
        Assert-ColdRestoreCondition ([bool]$run.wrapper_exit_green) "producer_$($run.wrapper_reason_code)"
        $terminalStage = "manifest_failure"
        $terminalCode = "process_a_rehearsal_manifest_failure"
        $launchEvidence = Assert-ColdRestoreLaunchAttestation `
            -Path $launchAttestationPath `
            -Role "producer" `
            -HeadSha $HeadSha `
            -ScenarioFingerprint $ExpectedScenarioFingerprint `
            -LaunchNonce ([string]$launchAuthorization.launch_nonce) `
            -Authorization $launchAuthorization `
            -Run $run
        $manifest = Read-ColdRestoreJsonArtifact $paths.child_result
        $stdoutManifest = Read-ColdRestoreManifest $paths.stdout "producer" $RunId
        Assert-ColdRestoreManifest $manifest "producer" $RunId
        $manifestCanonical = cold_restore_attested_process\ConvertTo-ColdRestoreCanonicalJson $manifest
        $stdoutManifestCanonical = cold_restore_attested_process\ConvertTo-ColdRestoreCanonicalJson $stdoutManifest
        $stdoutSha256 = (Get-FileHash -LiteralPath $paths.stdout -Algorithm SHA256).Hash.ToLowerInvariant()
        Assert-ColdRestoreCondition ($manifestCanonical -ceq $stdoutManifestCanonical) "process_a_rehearsal_manifest_stdout_mismatch"
        Assert-ColdRestoreCondition ($stdoutSha256 -ceq [string]$run.parent.stdout_sha256) "process_a_rehearsal_parent_stdout_sha256_mismatch"
        Assert-ColdRestoreCondition ([int]$manifest.process_id -eq [int]$launchEvidence.value.engine_process_id `
            -and @($run.observed_task_process_ids) -contains [int]$manifest.process_id) "process_a_rehearsal_manifest_process_id_mismatch"
        Assert-ColdRestoreCondition (-not [bool]$run.child.official `
            -and -not [bool]$run.child.formal `
            -and -not [bool]$run.child.official_count_consumed `
            -and [string]$run.child.run_id -ceq $RunId `
            -and [string]$run.child.repository_head -ceq $HeadSha `
            -and [string]$run.child.scenario_fingerprint -ceq $ExpectedScenarioFingerprint `
            -and [string]$manifest.run_id -ceq $RunId `
            -and [string]$manifest.head_sha -ceq $HeadSha `
            -and [string]$manifest.scenario_fingerprint -ceq $ExpectedScenarioFingerprint `
            -and [bool]$run.child.qualification_green -eq [bool]$manifest.success `
            -and [bool]$manifest.success `
            -and [bool]$run.child.save_written) "process_a_rehearsal_child_binding_invalid"
        $terminalStage = "timeline_failure"
        $terminalCode = "process_a_rehearsal_timeline_failure"
        $timeline = $run.phase_timeline
        $failedTimelineRows = @($timeline.phase_rows | Where-Object { -not [bool]$_.success })
        Assert-ColdRestoreCondition ($null -ne $timeline `
            -and [int]$timeline.schema_version -eq 1 `
            -and [string]$timeline.timeline_id -eq "ProcessAPhaseTimelineV1" `
            -and [string]$timeline.run_id -ceq $RunId `
            -and [string]$timeline.repository_head -ceq $HeadSha `
            -and [string]$timeline.scenario_fingerprint -ceq $ExpectedScenarioFingerprint `
            -and -not [bool]$timeline.official `
            -and @($timeline.phase_rows).Count -eq 19 `
            -and $failedTimelineRows.Count -eq 0 `
            -and [string]$timeline.last_completed_phase -eq "quit_requested" `
            -and [bool]$timeline.save_file_exists `
            -and [bool]$timeline.allowlisted_manifest_written `
            -and [bool]$timeline.child_completion_written `
            -and [bool]$timeline.quit_requested) "process_a_phase_timeline_incomplete"
        $saveFiles = @(Get-ChildItem -LiteralPath $UserDataRoot -Recurse -File -Filter "current_run.save")
        Assert-ColdRestoreCondition ($saveFiles.Count -eq 1) "non_official_process_a_save_count_invalid"
        $savePath = [IO.Path]::GetFullPath($saveFiles[0].FullName)
        Assert-ColdRestoreCondition ($savePath.StartsWith([IO.Path]::GetFullPath($UserDataRoot), [StringComparison]::OrdinalIgnoreCase)) "non_official_process_a_save_scope_invalid"
        Assert-ColdRestoreCondition ([int64]$saveFiles[0].Length -eq [int64]$timeline.save_file_bytes `
            -and (Get-FileHash -LiteralPath $savePath -Algorithm SHA256).Hash.ToLowerInvariant() -eq [string]$timeline.save_file_sha256) "non_official_process_a_save_fingerprint_mismatch"
        $terminalStage = "completion_failure"
        $terminalCode = "process_a_rehearsal_completion_failure"
        $completion = Read-ColdRestoreJsonArtifact $paths.rehearsal_completion
        $completionSha256 = (Get-FileHash -LiteralPath $paths.rehearsal_completion -Algorithm SHA256).Hash.ToLowerInvariant()
        Assert-ColdRestoreProcessARehearsalCompletion $completion $HeadSha ([string]$rehearsalAuthorization.fingerprint)
        Assert-ColdRestoreCondition ([string]$run.child.final_reason_code -ceq "process_a_rehearsal_completion_sha256_$completionSha256" `
            -and [int64]$completion.save_file_bytes -eq [int64]$timeline.save_file_bytes `
            -and [string]$completion.save_file_sha256 -ceq [string]$timeline.save_file_sha256 `
            -and [int]$manifest.section_count -eq 19 `
            -and [int]$manifest.preflight_count -eq 19 `
            -and [string]$manifest.saved_sections_digest -cmatch '^[0-9a-f]{64}$' `
            -and [string]$manifest.write_fingerprint -ceq [string]$completion.save_readback_fingerprint) "process_a_rehearsal_completion_binding_invalid"
        Assert-ColdRestoreOfficialAttemptBoundary $ResolvedProjectPath | Out-Null
        $launchLedger = process_a_rehearsal_admission_contract\Complete-ProcessARehearsalLaunch `
            -LaunchLedgerPath $rehearsalAuthorization.launch_ledger_path `
            -AdmissionLedgerPath $rehearsalAuthorization.path `
            -ExpectedAdmissionLedgerSha256 $rehearsalAuthorization.fingerprint `
            -PrerequisiteEvidenceFingerprint ([string]$revalidatedStage3Prerequisites.evidence_fingerprint) `
            -LaunchAttestationPath $launchAttestationPath `
            -TimeoutPolicyPath $RoleTimeoutPolicyEvidence.path `
            -AdmissionEvidencePath $diagnosticAdmission.path `
            -DiagnosticQuotaLedgerPath $diagnosticAdmission.quota_ledger_path `
            -DiagnosticLaunchAttestationPath $diagnosticAdmission.launch_attestation_path `
            -DiagnosticManifestPath $diagnosticAdmission.manifest_path `
            -DiagnosticChildAttestationPath $diagnosticAdmission.child_attestation_path `
            -DiagnosticParentAttestationPath $diagnosticAdmission.parent_attestation_path `
            -DiagnosticStdoutPath $diagnosticAdmission.stdout_path `
            -DiagnosticStderrPath $diagnosticAdmission.stderr_path `
            -OfficialClaimRoot (Join-Path (Resolve-ColdRestoreGitCommonDirectory $ResolvedProjectPath) "codex\cold_restore_v3") `
            -OfficialAttempt1ClaimPath ([string](Assert-ColdRestoreOfficialAttemptBoundary $ResolvedProjectPath).path)
        Assert-ColdRestoreCondition ([string]$launchLedger.value.admission_ledger_sha256 -ceq [string]$rehearsalAuthorization.fingerprint `
            -and [string]$launchLedger.value.launch_attestation_sha256 -ceq [string]$launchEvidence.sha256 `
            -and [int]$launchLedger.value.engine_process_id -eq [int]$launchEvidence.value.engine_process_id) "process_a_rehearsal_launch_ledger_invalid"
        $postRunFreeze = Get-ColdRestoreRuntimeFreezeObservation $ResolvedProjectPath $HeadSha
        $null = Assert-ColdRestoreRuntimeFreezeGreen `
            $postRunFreeze "process_a_rehearsal_post_run_tree_not_clean"
        $saveGreen = $true
        $terminalStage = "success"
        $terminalCode = "ok"
        $terminalSuccess = $true
    }
    catch {
        $candidateFailureCode = [string]$_.Exception.Message
        $terminalCode = if ($candidateFailureCode -cmatch '^[a-z0-9_]{1,128}$') {
            $candidateFailureCode
        }
        else {
            "process_a_rehearsal_unknown_failure"
        }
        $primaryFailure = $_
    }
    finally {
        if ($admissionConsumed) {
            try {
                $wrapperResultPresent = $null -ne $run -and $null -ne $run.parent
                $outcomeEvidence = [pscustomobject][ordered]@{
                admission_ledger_sha256 = [string]$rehearsalAuthorization.fingerprint
                rehearsal_green_head = $(if ($null -ne $postRunFreeze) { [string]$postRunFreeze.observed_head } else { "" })
                rehearsal_green_tree_clean = $(if ($null -ne $postRunFreeze) { [bool]$postRunFreeze.tree_clean } else { $false })
                rehearsal_green_git_diff_check_green = $(if ($null -ne $postRunFreeze) { [bool]$postRunFreeze.git_diff_check_green } else { $false })
                rehearsal_green_freeze_fingerprint = $(if ($null -ne $postRunFreeze) { [string]$postRunFreeze.evidence_fingerprint } else { "" })
                launch_attestation_path = $launchAttestationPath
                launch_attestation_sha256 = Get-ColdRestoreOptionalFileSha256 $launchAttestationPath
                child_attestation_path = $childAttestationPath
                child_attestation_sha256 = Get-ColdRestoreOptionalFileSha256 $childAttestationPath
                parent_attestation_path = $parentAttestationPath
                parent_attestation_sha256 = Get-ColdRestoreOptionalFileSha256 $parentAttestationPath
                stdout_path = $stdoutPath
                stdout_sha256 = Get-ColdRestoreOptionalFileSha256 $stdoutPath
                stderr_path = $stderrPath
                stderr_sha256 = Get-ColdRestoreOptionalFileSha256 $stderrPath
                manifest_path = $manifestPath
                manifest_sha256 = Get-ColdRestoreOptionalFileSha256 $manifestPath
                phase_timeline_path = $phaseTimelinePath
                phase_timeline_sha256 = Get-ColdRestoreOptionalFileSha256 $phaseTimelinePath
                completion_path = $completionPath
                completion_sha256 = Get-ColdRestoreOptionalFileSha256 $completionPath
                wrapper_result_present = $wrapperResultPresent
                observed_exit = $(if ($wrapperResultPresent) { [bool]$run.parent.observed_exit } else { $false })
                exit_code_observed = $(if ($wrapperResultPresent) { [bool]$run.parent.observed_exit } else { $false })
                exit_code = $(if ($wrapperResultPresent) { [int]$run.parent.exit_code } else { -1 })
                timed_out = $(if ($wrapperResultPresent) { [bool]$run.parent.timed_out } else { $false })
                terminated_by_parent = $(if ($wrapperResultPresent) { [bool]$run.parent.terminated_by_parent } else { $false })
                task_owned_process_count_after = $(if ($wrapperResultPresent) { [int]$run.parent.task_owned_process_count_after } else { -1 })
                terminal_code = $terminalCode
                official = $false
                official_attempt_2_claim_present = $false
                official_attempt_2_authorization_consumed = $false
                }
                $outcome = Write-ColdRestoreProcessARehearsalOutcome `
                    -ResolvedProjectPath $ResolvedProjectPath `
                    -HeadSha $HeadSha `
                    -Admission $rehearsalAuthorization `
                    -Evidence $outcomeEvidence `
                    -TerminalStage $terminalStage `
                    -TerminalCode $terminalCode `
                    -Success $terminalSuccess
            }
            catch {
                $outcomeFailure = $_
            }
        }
    }
    if ($null -ne $primaryFailure) {
        throw $primaryFailure
    }
    if ($null -ne $outcomeFailure) {
        throw $outcomeFailure
    }
    return [pscustomobject]@{
        run = $run
        manifest = $manifest
        timeline = $timeline
        paths = $paths
        save_path = $savePath
        completion = $completion
        completion_sha256 = $completionSha256
        authorization = $rehearsalAuthorization
        launch = $launchLedger
        outcome = $outcome
        diagnostic_admission = $diagnosticAdmission
        timeout = $timeout
    }
}

function Invoke-ColdRestoreTargetedOwnerCaptureDiagnostic {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedProjectPath,
        [Parameter(Mandatory = $true)][string]$HeadSha,
        [Parameter(Mandatory = $true)]$PreQuotaContext,
        [Parameter(Mandatory = $true)]$FailureState
    )

    $script:TargetedOwnerCaptureCurrentPhase = "authorization_check"
    Assert-ColdRestoreCondition ($RunId -ceq (cold_restore_authorization_contract_v1\Get-ColdRestoreAuthorizationRunId `
            $TargetedOwnerCaptureAuthorizationName $HeadSha)) "targeted_owner_capture_run_id_invalid"
    Assert-ColdRestoreCondition ($AuthorizedOfficialColdRestoreCount -eq 0) "targeted_owner_capture_official_authorization_forbidden"
    Assert-ColdRestoreCondition ($ExpectedScenarioFingerprint -ceq $TargetedOwnerCaptureScenarioFingerprint) "expected_scenario_fingerprint_invalid"
    $dirtyPaths = @(& git -C $ResolvedProjectPath status --porcelain=v1 2>$null)
    Assert-ColdRestoreCondition ($LASTEXITCODE -eq 0 -and (cold_restore_attested_process\Get-ColdRestoreSafeCollectionCount $dirtyPaths) -eq 0) "worktree_not_clean"
    $script:RoleTimeoutPolicyEvidence = Read-ColdRestoreRoleTimeoutPolicy $RoleTimeoutPolicyPath
    $timeout = Get-ColdRestoreRoleTimeout "targeted_owner_diagnostic"
    Assert-ColdRestoreCondition ([int]$timeout.absolute_timeout_seconds -eq 120 `
        -and [int]$timeout.no_progress_timeout_seconds -eq 30) "targeted_owner_capture_timeout_policy_invalid"
    $paths = Get-ColdRestoreRolePaths $ResolvedProjectPath "producer"
    $diagnosticEvidenceRoot = [string]$paths.root
    Assert-ColdRestoreCondition (-not (Test-Path -LiteralPath $UserDataRoot) `
        -and -not (Test-Path -LiteralPath $diagnosticEvidenceRoot)) "targeted_owner_capture_evidence_collision"
    $null = cold_restore_prequota_bootstrap\Update-ColdRestorePreQuotaAttestation `
        -Context $PreQuotaContext `
        -Updates ([ordered]@{ authorization_checked = $true }) `
        -FailureState $FailureState
    $script:TargetedOwnerCaptureCurrentPhase = "quota_claim"
    $null = cold_restore_prequota_bootstrap\Update-ColdRestorePreQuotaAttestation `
        -Context $PreQuotaContext `
        -Updates ([ordered]@{ quota_claim_attempted = $true }) `
        -FailureState $FailureState
    $diagnosticQuota = Consume-ColdRestoreTargetedOwnerCaptureDiagnosticQuota `
        $ResolvedProjectPath $HeadSha $PreQuotaContext
    Assert-ColdRestoreCondition ([IO.File]::Exists([string]$diagnosticQuota.path) `
        -and [string]$diagnosticQuota.fingerprint -cmatch '^[0-9a-f]{64}$') "targeted_owner_capture_diagnostic_quota_ledger_invalid"
    $null = cold_restore_prequota_bootstrap\Update-ColdRestorePreQuotaAttestation `
        -Context $PreQuotaContext `
        -Updates ([ordered]@{ quota_claimed = $true }) `
        -FailureState $FailureState
    $script:TargetedOwnerCaptureCurrentPhase = "evidence_root_creation"
    $null = cold_restore_prequota_bootstrap\Update-ColdRestorePreQuotaAttestation `
        -Context $PreQuotaContext `
        -Updates ([ordered]@{ evidence_root_creation_attempted = $true }) `
        -FailureState $FailureState
    [IO.Directory]::CreateDirectory([string]$paths.root) | Out-Null
    Assert-ColdRestoreCondition ([IO.Directory]::Exists([string]$paths.root)) "targeted_owner_capture_evidence_root_failed"
    $null = cold_restore_prequota_bootstrap\Update-ColdRestorePreQuotaAttestation `
        -Context $PreQuotaContext `
        -Updates ([ordered]@{ evidence_root_created = $true }) `
        -FailureState $FailureState
    [IO.Directory]::CreateDirectory($IsolatedAppData) | Out-Null
    [IO.Directory]::CreateDirectory($IsolatedLocalAppData) | Out-Null
    $null = Assert-ColdRestoreTargetedDiagnosticPostClaimBoundary `
        $ResolvedProjectPath $HeadSha $diagnosticQuota ([string]$paths.root)
    $GodotPath = Resolve-ColdRestoreGodotExecutable $GodotPath
    $launchAuthorization = $diagnosticQuota.launch_authorization
    $launchAttestationPath = Join-Path $paths.root "launch\orchestrator-$($launchAuthorization.orchestrator_process_id)\producer.authorized.json"
    $targetedUserArguments = cold_restore_prequota_bootstrap\New-ColdRestoreTargetedDiagnosticUserArgumentList `
        -GitCommonDirectory (Resolve-ColdRestoreGitCommonDirectory $ResolvedProjectPath) `
        -RepositoryHead $HeadSha `
        -RunId $RunId `
        -ArtifactRoot $ArtifactRoot `
        -ScenarioFingerprint $ExpectedScenarioFingerprint `
        -TimeoutPolicyFingerprint ([string]$RoleTimeoutPolicyEvidence.sha256) `
        -QuotaLedgerPath ([string]$diagnosticQuota.path) `
        -QuotaLedgerFingerprint ([string]$diagnosticQuota.fingerprint) `
        -LaunchAttestationPath $launchAttestationPath `
        -LaunchNonce ([string]$launchAuthorization.launch_nonce) `
        -AuthorizationName $TargetedOwnerCaptureAuthorizationName
    $arguments = cold_restore_attested_process\New-ColdRestoreGodotArgumentList `
        -EngineArgumentList @("--headless", "--path", $ResolvedProjectPath, "--script", $DriverScript) `
        -UserArgumentList $targetedUserArguments
    $script:TargetedOwnerCaptureCurrentPhase = "godot_launch"
    $null = cold_restore_prequota_bootstrap\Update-ColdRestorePreQuotaAttestation `
        -Context $PreQuotaContext `
        -Updates ([ordered]@{ godot_launch_attempted = $true }) `
        -FailureState $FailureState
    $run = cold_restore_attested_process\Invoke-ColdRestoreAttestedProcess `
        -ExecutablePath $GodotPath `
        -WorkingDirectory $ResolvedProjectPath `
        -ArgumentList $arguments `
        -RunId $RunId `
        -Role "producer" `
        -RepositoryHead $HeadSha `
        -ChildAttestationPath $paths.child_attestation `
        -ParentAttestationPath $paths.parent_attestation `
        -StdoutPath $paths.stdout `
        -StderrPath $paths.stderr `
        -TimeoutSeconds $timeout.absolute_timeout_seconds `
        -EnvironmentVariables @{
            APPDATA = $IsolatedAppData
            LOCALAPPDATA = $IsolatedLocalAppData
            SPACE_SYNDICATE_COLD_RESTORE_EVIDENCE_ROOT = [string]$paths.root
        } `
        -LaunchAttestationPath $launchAttestationPath `
        -LaunchAuthorization $launchAuthorization `
        -PhaseTimelineEventDirectory $paths.phase_timeline_events `
        -PhaseTimelinePath $paths.phase_timeline `
        -TimeoutPolicy $RoleTimeoutPolicyEvidence.policy `
        -TimeoutPolicyPath $RoleTimeoutPolicyEvidence.path `
        -ExpectedPolicyFingerprint $RoleTimeoutPolicyEvidence.sha256 `
        -PolicyRole "targeted_owner_diagnostic" `
        -ExpectedScenarioFingerprint $ExpectedScenarioFingerprint `
        -ProgressHeartbeatEventDirectory $paths.targeted_heartbeat_events `
        -ProgressHeartbeatPath $paths.targeted_heartbeat `
        -FailureState $FailureState
    $godotLaunched = (cold_restore_attested_process\Get-ColdRestoreSafeCollectionCount $run.observed_task_process_ids) -gt 0
    $null = cold_restore_prequota_bootstrap\Update-ColdRestorePreQuotaAttestation `
        -Context $PreQuotaContext `
        -Updates ([ordered]@{
            godot_launched = $godotLaunched
            task_owned_process_count_after = [int]$run.parent.task_owned_process_count_after
        }) `
        -FailureState $FailureState
    $script:TargetedOwnerCaptureCurrentPhase = "diagnostic_validation"
    if (-not [bool]$run.wrapper_exit_green) {
        throw (cold_restore_attested_process\New-ColdRestoreFailureException $FailureState)
    }
    $launchEvidence = Assert-ColdRestoreLaunchAttestation `
        -Path $launchAttestationPath `
        -Role "producer" `
        -HeadSha $HeadSha `
        -ScenarioFingerprint $ExpectedScenarioFingerprint `
        -LaunchNonce ([string]$launchAuthorization.launch_nonce) `
        -Authorization $launchAuthorization `
        -Run $run
    Assert-ColdRestoreCondition (-not [bool]$run.child.official `
        -and -not [bool]$run.child.formal `
        -and -not [bool]$run.child.official_count_consumed `
        -and -not [bool]$run.child.save_written `
        -and [string]$run.child.run_id -ceq $RunId `
        -and [string]$run.child.repository_head -ceq $HeadSha `
        -and [string]$run.child.scenario_fingerprint -ceq $ExpectedScenarioFingerprint `
        -and [bool]$run.parent.child_attestation_valid `
        -and [int]$run.parent.exit_code -eq 0 `
        -and -not [bool]$run.parent.timed_out `
        -and -not [bool]$run.parent.terminated_by_parent `
        -and [int]$run.parent.task_owned_process_count_after -eq 0) "targeted_owner_capture_exit_attestation_invalid"
    $timeline = $run.phase_timeline
    $cleanupRows = @(
        if ($null -ne $timeline) {
            $timeline.phase_rows | Where-Object { [string]$_.phase_id -ceq "runtime_cleanup_complete" }
        }
    )
    $quitRows = @(
        if ($null -ne $timeline) {
            $timeline.phase_rows | Where-Object { [string]$_.phase_id -ceq "quit_requested" }
        }
    )
    Assert-ColdRestoreCondition ($null -ne $timeline `
        -and [int]$timeline.schema_version -eq 1 `
        -and [string]$timeline.timeline_id -ceq "ProcessAPhaseTimelineV1" `
        -and [string]$timeline.run_id -ceq $RunId `
        -and [string]$timeline.repository_head -ceq $HeadSha `
        -and [string]$timeline.scenario_fingerprint -ceq $ExpectedScenarioFingerprint `
        -and -not [bool]$timeline.official `
        -and @($timeline.phase_rows).Count -eq 19 `
        -and (Test-ColdRestoreTargetedDiagnosticTimeline $timeline) `
        -and [string]$timeline.last_completed_phase -ceq "quit_requested" `
        -and -not [bool]$timeline.save_file_exists `
        -and [bool]$timeline.allowlisted_manifest_written `
        -and [bool]$timeline.child_completion_written `
        -and [bool]$timeline.quit_requested `
        -and (cold_restore_attested_process\Get-ColdRestoreSafeCollectionCount $cleanupRows) -eq 1 -and [bool]$cleanupRows[0].success `
        -and (cold_restore_attested_process\Get-ColdRestoreSafeCollectionCount $quitRows) -eq 1 -and [bool]$quitRows[0].success) "targeted_owner_capture_timeline_cleanup_invalid"
    $manifest = Read-ColdRestoreJsonArtifact $paths.child_result
    $stdoutManifest = Read-ColdRestoreManifest $paths.stdout "producer" $RunId
    Assert-ColdRestoreManifest $manifest "producer" $RunId
    $manifestCanonical = cold_restore_attested_process\ConvertTo-ColdRestoreCanonicalJson $manifest
    $stdoutManifestCanonical = cold_restore_attested_process\ConvertTo-ColdRestoreCanonicalJson $stdoutManifest
    $stdoutSha256 = (Get-FileHash -LiteralPath $paths.stdout -Algorithm SHA256).Hash.ToLowerInvariant()
    Assert-ColdRestoreCondition ($manifestCanonical -ceq $stdoutManifestCanonical) "targeted_owner_capture_manifest_stdout_mismatch"
    Assert-ColdRestoreCondition ($stdoutSha256 -ceq [string]$run.parent.stdout_sha256) "targeted_owner_capture_parent_stdout_sha256_mismatch"
    Assert-ColdRestoreCondition ([int]$manifest.process_id -eq [int]$launchEvidence.value.engine_process_id `
        -and @($run.observed_task_process_ids) -contains [int]$manifest.process_id `
        -and [string]$manifest.run_id -ceq $RunId `
        -and [string]$manifest.head_sha -ceq $HeadSha `
        -and [string]$manifest.scenario_fingerprint -ceq $ExpectedScenarioFingerprint) "targeted_owner_capture_manifest_process_id_mismatch"
    Assert-ColdRestoreCondition (-not [bool]$manifest.success) "targeted_owner_capture_manifest_must_be_diagnostic"
    $diagnosticPath = $paths.targeted_diagnostic
    $diagnostic = Read-ColdRestoreJsonArtifact $diagnosticPath
    $diagnosticSha256 = (Get-FileHash -LiteralPath $diagnosticPath -Algorithm SHA256).Hash.ToLowerInvariant()
    Assert-ColdRestoreCondition ([string]$run.child.product_blocker -ceq "TARGETED_OWNER_CAPTURE_DIAGNOSTIC_SHA256:$diagnosticSha256" `
        -and [string]$run.child.final_reason_code -ceq "targeted_owner_capture_diagnostic_sha256_$diagnosticSha256") "targeted_owner_capture_child_diagnostic_binding_invalid"
    Assert-ColdRestoreTargetedDiagnosticV2 $diagnostic $HeadSha
    $firstFailureFields = @(
        $diagnostic.first_failure.PSObject.Properties | ForEach-Object { [string]$_.Name }
    )
    $postFailureFields = @(
        $diagnostic.post_capture_failure.PSObject.Properties | ForEach-Object { [string]$_.Name }
    )
    $diagnosticResultKind = if (-not [bool]$diagnostic.owner_audit_started) {
        "PRE_OWNER_FAILURE"
    }
    elseif ($firstFailureFields.Count -gt 0) {
        "OWNER_CAPTURE_FAILURE"
    }
    elseif ($postFailureFields.Count -gt 0) {
        "POST_CAPTURE_FAILURE"
    }
    else {
        "ALL_OWNERS_CAPTURED"
    }
    $expectedManifestFailure = switch ($diagnosticResultKind) {
        "OWNER_CAPTURE_FAILURE" { "targeted_owner_capture_diagnostic_complete" }
        "POST_CAPTURE_FAILURE" { "targeted_owner_capture_post_validation_failed" }
        "ALL_OWNERS_CAPTURED" { "targeted_owner_capture_all_owners_succeeded" }
        default { "" }
    }
    Assert-ColdRestoreCondition (([string]$diagnosticResultKind -ceq "PRE_OWNER_FAILURE" `
            -and [string]$manifest.failure_code -cmatch '^[a-z0-9_]{1,128}$') `
        -or ([string]$diagnosticResultKind -cne "PRE_OWNER_FAILURE" `
            -and [string]$manifest.failure_code -ceq $expectedManifestFailure)) "targeted_owner_capture_manifest_failure_binding_invalid"
    $diagnosticJson = $diagnostic | ConvertTo-Json -Compress -Depth 12
    foreach ($forbiddenDiagnosticToken in @('"owner_state"', '"section_payloads"', '"plan"', '"envelope"', '"private_hand"', '"ai_memory"', '"commodity_inventory"')) {
        Assert-ColdRestoreCondition (-not $diagnosticJson.Contains($forbiddenDiagnosticToken, [StringComparison]::OrdinalIgnoreCase)) "targeted_owner_capture_private_payload_exposed"
    }
    $stdoutText = if (Test-Path -LiteralPath $paths.stdout -PathType Leaf) { Get-Content -LiteralPath $paths.stdout -Raw } else { "" }
    $stderrText = if (Test-Path -LiteralPath $paths.stderr -PathType Leaf) { Get-Content -LiteralPath $paths.stderr -Raw } else { "" }
    foreach ($forbiddenLogToken in @(
        '"owner_state"', '"section_payloads"', '"private_hand"', '"ai_memory"',
        '"left_scalar"', '"right_scalar"', '"next_quote_sequence":',
        '"next_listing_sequence":', '"next_transaction_sequence":',
        'COLD_RESTORE_CARD_INVENTORY_CAPTURE_PROBE'
    )) {
        Assert-ColdRestoreCondition (-not ($stdoutText + $stderrText).Contains($forbiddenLogToken, [StringComparison]::OrdinalIgnoreCase)) "targeted_owner_capture_private_log_exposed"
    }
    $saveArtifacts = @(Get-ChildItem -LiteralPath $UserDataRoot -Recurse -File | Where-Object {
        $_.FullName -match '[\\/]saves[\\/]' -or $_.Name -like '*.save*'
    })
    Assert-ColdRestoreCondition ($saveArtifacts.Count -eq 0) "targeted_owner_capture_unexpected_save"
    return [pscustomobject]@{
        run = $run
        manifest = $manifest
        diagnostic = $diagnostic
        diagnostic_result_kind = $diagnosticResultKind
        paths = $paths
        diagnostic_path = $diagnosticPath
    }
}

function Assert-ColdRestoreTargetedOwnerCapturePostconditions {
    param([Parameter(Mandatory = $true)][string]$ResolvedProjectPath)

    Assert-ColdRestoreOfficialAttemptBoundary $ResolvedProjectPath | Out-Null
    $paths = Get-ColdRestoreRolePaths $ResolvedProjectPath "producer"
    $retainedLogText = ""
    foreach ($logPath in @($paths.stdout, $paths.stderr)) {
        if (Test-Path -LiteralPath $logPath -PathType Leaf) {
            $retainedLogText += Get-Content -LiteralPath $logPath -Raw
        }
    }
    foreach ($forbiddenLogToken in @(
        '"owner_state"', '"section_payloads"', '"plan"', '"envelope"',
        '"private_hand"', '"ai_memory"', '"commodity_inventory"',
        '"left_scalar"', '"right_scalar"', '"next_quote_sequence":',
        '"next_listing_sequence":', '"next_transaction_sequence":',
        'V06_OWNER_REGISTRY_PRIVATE_HAND', 'V06_OWNER_REGISTRY_OWNER_TRUTH',
        'V06_OWNER_REGISTRY_AI_PLAN', 'COLD_RESTORE_CARD_INVENTORY_CAPTURE_PROBE'
    )) {
        Assert-ColdRestoreCondition (-not $retainedLogText.Contains($forbiddenLogToken, [StringComparison]::OrdinalIgnoreCase)) "targeted_owner_capture_private_log_exposed"
    }
    $saveArtifacts = @(
        if (Test-Path -LiteralPath $UserDataRoot -PathType Container) {
            Get-ChildItem -LiteralPath $UserDataRoot -Recurse -File | Where-Object {
                $_.FullName -match '[\\/]saves[\\/]' -or $_.Name -like '*.save*' `
                    -or $_.Name -like '*.tmp*' -or $_.Name -like '*.backup*'
            }
        }
        else {
            @()
        }
    )
    Assert-ColdRestoreCondition ($saveArtifacts.Count -eq 0) "targeted_owner_capture_unexpected_save"
}

function Invoke-ColdRestoreTargetedOwnerCaptureGuarded {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedProjectPath,
        [Parameter(Mandatory = $true)][string]$HeadSha
    )

    $targetedDiagnostic = $null
    $failureState = cold_restore_attested_process\New-ColdRestorePrimaryFailureState
    $preQuotaContext = $null
    $script:TargetedOwnerCaptureCurrentPhase = "bootstrap_admission"
    try {
        $gitCommonDirectory = Resolve-ColdRestoreGitCommonDirectory $ResolvedProjectPath
        $branchLines = @(& git -C $ResolvedProjectPath branch --show-current 2>$null)
        Assert-ColdRestoreCondition ($LASTEXITCODE -eq 0 `
            -and (cold_restore_attested_process\Get-ColdRestoreSafeCollectionCount $branchLines) -le 1) "branch_identity_unavailable"
        $branch = $(if ((cold_restore_attested_process\Get-ColdRestoreSafeCollectionCount $branchLines) -eq 1) { [string]$branchLines[0] } else { "" })
        $null = Assert-ColdRestoreTargetedDiagnosticRemoteCheckpoint $ResolvedProjectPath $HeadSha
        $preQuotaFreeze = Get-ColdRestoreRuntimeFreezeObservation $ResolvedProjectPath $HeadSha
        $null = Assert-ColdRestoreRuntimeFreezeGreen `
            $preQuotaFreeze "targeted_diagnostic_prequota_runtime_not_frozen"
        Assert-ColdRestoreCondition ([IO.File]::Exists($AuthorizationContractPath) `
            -and (Get-FileHash -LiteralPath $AuthorizationContractPath -Algorithm SHA256).Hash.ToLowerInvariant() `
                -ceq $AuthorizationContractSha256) "targeted_diagnostic_authorization_contract_changed"
        $authorizationBinding = cold_restore_authorization_contract_v1\Get-ColdRestoreTargetedDiagnosticAuthorizationBinding `
            -GitCommonDirectory $gitCommonDirectory `
            -RepositoryHead $HeadSha `
            -AuthorizationName $TargetedOwnerCaptureAuthorizationName
        Assert-ColdRestoreCondition ($RunId -ceq [string]$authorizationBinding.run_id) `
            "targeted_owner_capture_run_id_invalid"
        $preQuotaContext = cold_restore_prequota_bootstrap\New-ColdRestoreTargetedDiagnosticPreQuotaContext `
            -GitCommonDirectory $gitCommonDirectory `
            -RepositoryHead $HeadSha `
            -Branch $branch `
            -AuthorizationName $TargetedOwnerCaptureAuthorizationName
        $script:LastTargetedPreQuotaContext = $preQuotaContext
        $targetedDiagnostic = Invoke-ColdRestoreTargetedOwnerCaptureDiagnostic `
            $ResolvedProjectPath $HeadSha $preQuotaContext $failureState
    }
    catch {
        $caughtError = $_
        if ($null -eq (cold_restore_attested_process\Get-ColdRestoreFailureProjectionFromError $caughtError)) {
            $null = cold_restore_attested_process\Add-ColdRestoreFailureRecord `
                -State $failureState `
                -Phase $script:TargetedOwnerCaptureCurrentPhase `
                -ReasonCode ([string]$caughtError.Exception.Message) `
                -FallbackReasonCode "targeted_owner_capture_orchestrator_failure" `
                -SourceId "targeted_diagnostic"
        }
        foreach ($secondaryCode in @(cold_restore_attested_process\Get-ColdRestoreSecondaryFailureCodesFromError $caughtError)) {
            $null = cold_restore_attested_process\Add-ColdRestoreFailureRecord `
                -State $failureState `
                -Phase $script:TargetedOwnerCaptureCurrentPhase `
                -ReasonCode $secondaryCode `
                -FallbackReasonCode "targeted_owner_capture_secondary_failure" `
                -SourceId "targeted_diagnostic"
        }
    }
    finally {
        try {
            Assert-ColdRestoreTargetedOwnerCapturePostconditions $ResolvedProjectPath
        }
        catch {
            $null = cold_restore_attested_process\Add-ColdRestoreFailureRecord `
                -State $failureState `
                -Phase "postcondition_validation" `
                -ReasonCode ([string]$_.Exception.Message) `
                -FallbackReasonCode "targeted_owner_capture_postcondition_failure" `
                -SourceId "postcondition"
        }
        if ($null -ne $preQuotaContext) {
            try {
                $null = cold_restore_prequota_bootstrap\Update-ColdRestorePreQuotaAttestation `
                    -Context $preQuotaContext `
                    -Updates ([ordered]@{}) `
                    -FailureState $failureState
            }
            catch {
                $caughtError = $_
                $null = cold_restore_attested_process\Add-ColdRestoreFailureRecord `
                    -State $failureState `
                    -Phase "prequota_evidence_write" `
                    -ReasonCode ([string]$caughtError.Exception.Message) `
                    -FallbackReasonCode "prequota_attestation_write_failed" `
                    -SourceId "evidence_write"
                foreach ($secondaryCode in @(cold_restore_attested_process\Get-ColdRestoreSecondaryFailureCodesFromError $caughtError)) {
                    $null = cold_restore_attested_process\Add-ColdRestoreFailureRecord `
                        -State $failureState `
                        -Phase "prequota_evidence_write" `
                        -ReasonCode $secondaryCode `
                        -FallbackReasonCode "prequota_attestation_secondary_failure" `
                        -SourceId "evidence_write"
                }
            }
        }
    }
    $failureProjection = cold_restore_attested_process\Get-ColdRestoreFailureProjection $failureState
    if (-not [string]::IsNullOrEmpty([string]$failureProjection.primary_failure_code)) {
        throw (cold_restore_attested_process\New-ColdRestoreFailureException $failureState)
    }
    $targetedDiagnostic | Add-Member -NotePropertyName prequota -NotePropertyValue ([pscustomobject]@{
        path = [string]$preQuotaContext.attestation_path
        sha256 = [string]$preQuotaContext.attestation_sha256
        fingerprint = [string]$preQuotaContext.value.attestation_fingerprint
        admission_path = [string]$preQuotaContext.admission_path
        admission_sha256 = [string]$preQuotaContext.admission_sha256
        admission_fingerprint = [string]$preQuotaContext.admission_fingerprint
    })
    return $targetedDiagnostic
}

function New-ColdRestoreTargetedOwnerCaptureOutput {
    param([Parameter(Mandatory = $true)]$Result)

    $failure = if (@($Result.diagnostic.first_failure.PSObject.Properties).Count -gt 0) {
        $Result.diagnostic.first_failure
    }
    else {
        $Result.diagnostic.post_capture_failure
    }
    $failureFields = if ($null -ne $failure) {
        @($failure.PSObject.Properties | ForEach-Object { [string]$_.Name })
    }
    else {
        @()
    }
    $diagnosticGreen = [string]$Result.diagnostic_result_kind -ceq "ALL_OWNERS_CAPTURED"
    $failureCode = switch ([string]$Result.diagnostic_result_kind) {
        "ALL_OWNERS_CAPTURED" { "" }
        "OWNER_CAPTURE_FAILURE" { "owner_capture_failed" }
        "POST_CAPTURE_FAILURE" { "owner_capture_post_validation_failed" }
        "PRE_OWNER_FAILURE" { "owner_diagnostic_pre_audit_failure" }
        default { "owner_diagnostic_result_unknown" }
    }
    return [ordered]@{
        schema_version = 3
        driver_id = "alpha04c_targeted_owner_capture_diagnostic_v5_canonical_binding"
        formal_full_run = $false
        official_cold_restore_vertical_slice = $false
        targeted_owner_capture_diagnostic = $true
        run_id = $RunId
        repository_head = [string]$Result.diagnostic.repository_head
        scenario_fingerprint = $(if ([bool]$Result.diagnostic.scenario_identity_attested) { [string]$Result.diagnostic.scenario_identity.scenario_fingerprint } else { "" })
        diagnostic_result_kind = [string]$Result.diagnostic_result_kind
        scenario_identity_attested = [bool]$Result.diagnostic.scenario_identity_attested
        registry_binding_attested = [bool]$Result.diagnostic.registry_binding_attested
        scenario_identity_failure_field = $(if (@($Result.diagnostic.scenario_identity_failure.PSObject.Properties).Count -gt 0) { [string]$Result.diagnostic.scenario_identity_failure.failure_field } else { "" })
        scenario_identity_failure_reason = $(if (@($Result.diagnostic.scenario_identity_failure.PSObject.Properties).Count -gt 0) { [string]$Result.diagnostic.scenario_identity_failure.reason_code } else { "" })
        owner_audit_started = [bool]$Result.diagnostic.owner_audit_started
        owner_audit_completed = [bool]$Result.diagnostic.owner_audit_completed
        first_owner_capture_index = [int]$Result.diagnostic.first_owner_capture_index
        last_completed_owner_capture_index = [int]$Result.diagnostic.last_completed_owner_capture_index
        owner_capture_attempted_count = [int]$Result.diagnostic.owner_capture_attempted_count
        owner_capture_succeeded_count = [int]$Result.diagnostic.owner_capture_succeeded_count
        owner_capture_failed_count = [int]$Result.diagnostic.owner_capture_failed_count
        failing_section_id = $(if ($failureFields -contains "section_id") { [string]$failure.section_id } else { "" })
        failing_owner_id = $(if ($failureFields -contains "owner_id") { [string]$failure.owner_id } else { "" })
        failing_failure_class = $(if ($failureFields -contains "failure_class") { [string]$failure.failure_class } else { "" })
        failing_reason_code = $(if ($failureFields -contains "reason_code") { [string]$failure.reason_code } else { "" })
        post_capture_validation = [string]$Result.diagnostic.post_capture_validation
        child_completion_attestation_valid = [bool]$Result.run.parent.child_attestation_valid
        parent_exit_attestation_green = [bool]$Result.run.parent.wrapper_exit_green
        exit_code = [int]$Result.run.parent.exit_code
        timed_out = [bool]$Result.run.parent.timed_out
        terminated_by_parent = [bool]$Result.run.parent.terminated_by_parent
        task_owned_process_count_after = [int]$Result.run.parent.task_owned_process_count_after
        save_written = $false
        official_count_consumed = $false
        process_a_rehearsal_authorized = $diagnosticGreen
        diagnostic_path = [string]$Result.diagnostic_path
        prequota_attestation_path = [string]$Result.prequota.path
        prequota_attestation_sha256 = [string]$Result.prequota.sha256
        prequota_attestation_fingerprint = [string]$Result.prequota.fingerprint
        bootstrap_admission_sha256 = [string]$Result.prequota.admission_sha256
        bootstrap_admission_fingerprint = [string]$Result.prequota.admission_fingerprint
        success = $diagnosticGreen
        failure_code = $failureCode
    }
}

function New-ColdRestoreNonOfficialProcessAOutput {
    param([Parameter(Mandatory = $true)]$Result)

    return [ordered]@{
        schema_version = 1
        driver_id = "alpha04c_non_official_process_a_v1"
        formal_full_run = $false
        official_cold_restore_vertical_slice = $false
        non_official_process_a = $true
        run_kind = $NonOfficialProcessAKind
        run_id = $RunId
        repository_head = [string]$Result.manifest.head_sha
        scenario_fingerprint = $ExpectedScenarioFingerprint
        timeout_seconds = [int]$Result.timeout.absolute_timeout_seconds
        no_progress_timeout_seconds = [int]$Result.timeout.no_progress_timeout_seconds
        timeout_policy_sha256 = [string]$RoleTimeoutPolicyEvidence.sha256
        rehearsal_only = $true
        official_attempt_claim_created = $false
        official_authorization_consumed = $false
        rehearsal_authorization_fingerprint = [string]$Result.authorization.fingerprint
        rehearsal_completion_sha256 = [string]$Result.completion_sha256
        wall_elapsed_ms = [int64]$Result.run.wall_elapsed_ms
        save_green = [bool]$Result.timeline.save_file_exists `
            -and [int64]$Result.timeline.save_file_bytes -gt 0 `
            -and [string]$Result.timeline.save_file_sha256 -match '^[0-9a-f]{64}$' `
            -and [bool]$Result.timeline.allowlisted_manifest_written `
            -and [bool]$Result.timeline.child_completion_written `
            -and [bool]$Result.timeline.quit_requested `
            -and [bool]$Result.manifest.success `
            -and [bool]$Result.run.child.save_written `
            -and [bool]$Result.run.parent.child_attestation_valid `
            -and [bool]$Result.run.parent.wrapper_exit_green `
            -and [int]$Result.run.parent.exit_code -eq 0 `
            -and -not [bool]$Result.run.parent.timed_out `
            -and -not [bool]$Result.run.parent.terminated_by_parent `
            -and [int]$Result.run.parent.task_owned_process_count_after -eq 0
        save_file_bytes = [int64]$Result.timeline.save_file_bytes
        save_file_sha256 = [string]$Result.timeline.save_file_sha256
        phase_timeline_green = @($Result.timeline.phase_rows).Count -eq 19
        phase_timeline_path = [string]$Result.paths.phase_timeline
        child_completion_attestation_green = [bool]$Result.run.parent.child_attestation_valid
        parent_exit_attestation_green = [bool]$Result.run.parent.wrapper_exit_green
        exit_code = [int]$Result.run.parent.exit_code
        timed_out = [bool]$Result.run.parent.timed_out
        terminated_by_parent = [bool]$Result.run.parent.terminated_by_parent
        task_owned_process_count_after = [int]$Result.run.parent.task_owned_process_count_after
        phase_rows = @($Result.timeline.phase_rows)
        save_owner_capture_count = [int]$Result.completion.save_owner_capture_count
        save_section_count = [int]$Result.completion.save_section_count
        save_preflight_count = [int]$Result.completion.save_preflight_count
        save_readback_green = [bool]$Result.completion.save_readback_green
        save_fingerprint_parity = [bool]$Result.completion.save_fingerprint_parity
        restore_barrier_entered = [bool]$Result.completion.restore_barrier_entered
        restore_barrier_quiet = [bool]$Result.completion.restore_barrier_quiet
        restore_barrier_released = [bool]$Result.completion.restore_barrier_released
        success = [bool]$Result.run.wrapper_exit_green -and [bool]$Result.manifest.success
        failure_code = $(if ([bool]$Result.manifest.success) { "" } else { [string]$Result.manifest.failure_code })
    }
}

function Assert-ColdRestoreLaunchAttestation {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][ValidateSet("producer", "consumer", "validator")][string]$Role,
        [Parameter(Mandatory = $true)][string]$HeadSha,
        [Parameter(Mandatory = $true)][string]$ScenarioFingerprint,
        [Parameter(Mandatory = $true)][string]$LaunchNonce,
        [Parameter(Mandatory = $true)]$Authorization,
        [Parameter(Mandatory = $true)]$Run
    )

    $launch = Read-ColdRestoreJsonArtifact $Path
    Assert-ColdRestoreCondition (Test-ExactFieldSet $launch $LaunchAttestationFields) "launch_attestation_field_set_invalid"
    Assert-ColdRestoreCondition ([int]$launch.schema_version -eq 1 `
        -and [string]$launch.authorization_id -eq [string]$Authorization.authorization_id `
        -and [string]$launch.claim_fingerprint -eq [string]$Authorization.claim_fingerprint `
        -and [string]$launch.claim_nonce -eq [string]$Authorization.claim_nonce `
        -and [string]$launch.source_head_sha -eq $HeadSha `
        -and [string]$launch.scenario_fingerprint -eq $ScenarioFingerprint `
        -and [string]$launch.run_id -eq $RunId `
        -and [string]$launch.process_role -eq $Role `
        -and [string]$launch.launch_nonce -eq $LaunchNonce `
        -and [int]$launch.orchestrator_process_id -eq [int]$Authorization.orchestrator_process_id `
        -and [string]$launch.orchestrator_creation_time_utc_ticks -eq [string]$Authorization.orchestrator_creation_time_utc_ticks `
        -and [string]$launch.status -eq "authorized") "launch_attestation_binding_invalid"
    foreach ($field in @("orchestrator_creation_time_utc_ticks", "wrapper_creation_time_utc_ticks", "engine_creation_time_utc_ticks")) {
        Assert-ColdRestoreCondition ([string]$launch.$field -match '^[1-9][0-9]{0,18}$') "launch_attestation_creation_time_invalid"
    }
    $processRelationValid = [int]$launch.wrapper_parent_process_id -eq [int]$launch.orchestrator_process_id
    if ([int]$launch.engine_process_id -eq [int]$launch.wrapper_process_id) {
        $processRelationValid = $processRelationValid `
            -and [int]$launch.engine_parent_process_id -eq [int]$launch.orchestrator_process_id `
            -and [string]$launch.engine_creation_time_utc_ticks -eq [string]$launch.wrapper_creation_time_utc_ticks
    }
    else {
        $processRelationValid = $processRelationValid `
            -and [int]$launch.engine_parent_process_id -eq [int]$launch.wrapper_process_id
    }
    $wrapperIdentityRows = @($Run.observed_task_process_identities | Where-Object {
        [int]$_.process_id -eq [int]$launch.wrapper_process_id `
            -and [string]$_.creation_time_utc_ticks -ceq [string]$launch.wrapper_creation_time_utc_ticks
    })
    $engineIdentityRows = @($Run.observed_task_process_identities | Where-Object {
        [int]$_.process_id -eq [int]$launch.engine_process_id `
            -and [string]$_.creation_time_utc_ticks -ceq [string]$launch.engine_creation_time_utc_ticks
    })
    Assert-ColdRestoreCondition ($processRelationValid `
        -and [int]$launch.wrapper_process_id -eq [int]$Run.parent.child_pid `
        -and @($Run.observed_task_process_ids) -contains [int]$launch.engine_process_id `
        -and $wrapperIdentityRows.Count -eq 1 `
        -and $engineIdentityRows.Count -eq 1) "launch_attestation_process_identity_invalid"
    return [pscustomobject]@{
        value = $launch
        sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

function Invoke-ColdRestoreRole {
    param(
        [Parameter(Mandatory = $true)][ValidateSet("producer", "consumer", "validator")][string]$Role,
        [Parameter(Mandatory = $true)][string]$ResolvedProjectPath,
        [Parameter(Mandatory = $true)][string]$HeadSha,
        [Parameter(Mandatory = $true)][string]$ScenarioFingerprint,
        [Parameter(Mandatory = $true)]$Authorization,
        [int64]$ExpectedQueueResolutionId = 0,
        [string]$ExpectedQueueStableTargetFingerprint = ""
    )
    $paths = Get-ColdRestoreRolePaths $ResolvedProjectPath $Role
    $timeoutRoleId = @{ producer = "process_a"; consumer = "process_b"; validator = "process_c" }[$Role]
    $timeout = Get-ColdRestoreRoleTimeout $timeoutRoleId
    $launchNonce = [Guid]::NewGuid().ToString("N")
    $launchAttestationPath = Join-Path $paths.root "launch\orchestrator-$($Authorization.orchestrator_process_id)\$Role.authorized.json"
    $userArguments = @(
        "--cold-restore-role=$Role",
        "--cold-restore-run-id=$RunId",
        "--cold-restore-head-sha=$HeadSha",
        "--cold-restore-artifact-root=$ArtifactRoot",
        "--cold-restore-scenario-fingerprint=$ScenarioFingerprint",
        "--cold-restore-timeout-policy-fingerprint=$($RoleTimeoutPolicyEvidence.sha256)",
        "--cold-restore-official-claim-path=$($Authorization.ledger_path)",
        "--cold-restore-launch-attestation-path=$launchAttestationPath",
        "--cold-restore-launch-nonce=$launchNonce"
    )
    if ($Role -ne "producer") {
        Assert-ColdRestoreCondition ($ExpectedQueueResolutionId -gt 0) "expected_queue_resolution_id_invalid"
        Assert-ColdRestoreCondition ($ExpectedQueueStableTargetFingerprint -match '^[0-9a-f]{64}$') "expected_queue_stable_target_fingerprint_invalid"
        $userArguments += "--cold-restore-expected-queue-resolution-id=$ExpectedQueueResolutionId"
        $userArguments += "--cold-restore-expected-queue-stable-target-fingerprint=$ExpectedQueueStableTargetFingerprint"
    }
    $arguments = cold_restore_attested_process\New-ColdRestoreGodotArgumentList `
        -EngineArgumentList @("--headless", "--path", $ResolvedProjectPath, "--script", $DriverScript) `
        -UserArgumentList $userArguments
    $heartbeatEventDirectory = @{
        producer = $paths.process_a_heartbeat_events
        consumer = $paths.process_b_heartbeat_events
        validator = $paths.process_c_heartbeat_events
    }[$Role]
    $heartbeatPath = @{
        producer = $paths.process_a_heartbeat
        consumer = $paths.process_b_heartbeat
        validator = $paths.process_c_heartbeat
    }[$Role]
    $run = cold_restore_attested_process\Invoke-ColdRestoreAttestedProcess `
        -ExecutablePath $GodotPath `
        -WorkingDirectory $ResolvedProjectPath `
        -ArgumentList $arguments `
        -RunId $RunId `
        -Role $Role `
        -RepositoryHead $HeadSha `
        -ChildAttestationPath $paths.child_attestation `
        -ParentAttestationPath $paths.parent_attestation `
        -StdoutPath $paths.stdout `
        -StderrPath $paths.stderr `
        -TimeoutSeconds $timeout.absolute_timeout_seconds `
        -EnvironmentVariables @{ APPDATA = $IsolatedAppData; LOCALAPPDATA = $IsolatedLocalAppData } `
        -LaunchAttestationPath $launchAttestationPath `
        -LaunchAuthorization ([pscustomobject][ordered]@{
            authorization_id = [string]$Authorization.authorization_id
            claim_fingerprint = [string]$Authorization.claim_fingerprint
            claim_nonce = [string]$Authorization.claim_nonce
            source_head_sha = $HeadSha
            scenario_fingerprint = $ScenarioFingerprint
            run_id = $RunId
            process_role = $Role
            launch_nonce = $launchNonce
            orchestrator_process_id = [int]$Authorization.orchestrator_process_id
            orchestrator_creation_time_utc_ticks = [string]$Authorization.orchestrator_creation_time_utc_ticks
        }) `
        -PhaseTimelineEventDirectory $(if ($Role -eq "producer") { $paths.phase_timeline_events } else { "" }) `
        -PhaseTimelinePath $(if ($Role -eq "producer") { $paths.phase_timeline } else { "" }) `
        -TimeoutPolicy $RoleTimeoutPolicyEvidence.policy `
        -TimeoutPolicyPath $RoleTimeoutPolicyEvidence.path `
        -ExpectedPolicyFingerprint $RoleTimeoutPolicyEvidence.sha256 `
        -PolicyRole $timeoutRoleId `
        -ExpectedScenarioFingerprint $ScenarioFingerprint `
        -ProgressHeartbeatEventDirectory $heartbeatEventDirectory `
        -ProgressHeartbeatPath $heartbeatPath
    Assert-ColdRestoreCondition ([bool]$run.wrapper_exit_green) "${Role}_$($run.wrapper_reason_code)"
    $launchEvidence = Assert-ColdRestoreLaunchAttestation `
        -Path $launchAttestationPath `
        -Role $Role `
        -HeadSha $HeadSha `
        -ScenarioFingerprint $ScenarioFingerprint `
        -LaunchNonce $launchNonce `
        -Authorization $Authorization `
        -Run $run
    $manifest = Read-ColdRestoreJsonArtifact $paths.child_result
    Assert-ColdRestoreManifest $manifest $Role $RunId
    Assert-ColdRestoreCondition (@($run.observed_task_process_ids) -contains [int]$manifest.process_id `
        -and [int]$launchEvidence.value.engine_process_id -eq [int]$manifest.process_id) "${Role}_manifest_process_id_mismatch"
    Assert-ColdRestoreCondition ([string]$manifest.head_sha -eq $HeadSha) "${Role}_manifest_head_sha_mismatch"
    Assert-ColdRestoreCondition ([string]$manifest.scenario_fingerprint -eq $ScenarioFingerprint) "${Role}_manifest_scenario_fingerprint_mismatch"
    Assert-ColdRestoreCondition ([bool]$run.child.official `
        -and -not [bool]$run.child.formal `
        -and [bool]$run.child.official_count_consumed `
        -and [string]$run.child.scenario_fingerprint -eq $ScenarioFingerprint `
        -and [bool]$run.child.qualification_green -eq [bool]$manifest.success `
        -and [int]$run.child.queue_count -eq [int]$manifest.queue_entry_count `
        -and [string]$run.child.queue_trigger_target_fingerprint -eq [string]$manifest.queue_trigger_stable_target_fingerprint) "${Role}_child_manifest_binding_invalid"
    Assert-ColdRestoreCondition ([bool]$manifest.success) "${Role}_$([string]$manifest.failure_code)"
    return [pscustomobject]@{
        process_id = [int]$run.parent.child_pid
        manifest = $manifest
        child = $run.child
        parent = $run.parent
        launch_attestation_sha256 = [string]$launchEvidence.sha256
    }
}

function Invoke-ColdRestoreOfficialRoleChain {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedProjectPath,
        [Parameter(Mandatory = $true)][string]$HeadSha,
        [Parameter(Mandatory = $true)][string]$ScenarioFingerprint,
        [Parameter(Mandatory = $true)]$Authorization
    )

    $script:OfficialAttempt2Progress.process_a_started = $true
    $producerRun = Invoke-ColdRestoreRole `
        "producer" $ResolvedProjectPath $HeadSha $ScenarioFingerprint $Authorization
    $script:OfficialAttempt2Progress.process_a_completed = $true
    $script:OfficialAttempt2Progress.process_b_started = $true
    $consumerRun = Invoke-ColdRestoreRole `
        "consumer" $ResolvedProjectPath $HeadSha $ScenarioFingerprint $Authorization `
        ([int64]$producerRun.manifest.queue_trigger_resolution_id) `
        ([string]$producerRun.manifest.queue_trigger_stable_target_fingerprint)
    $script:OfficialAttempt2Progress.process_b_completed = $true
    $script:OfficialAttempt2Progress.process_c_started = $true
    $validatorRun = Invoke-ColdRestoreRole `
        "validator" $ResolvedProjectPath $HeadSha $ScenarioFingerprint $Authorization `
        ([int64]$consumerRun.manifest.queue_trigger_resolution_id) `
        ([string]$consumerRun.manifest.queue_trigger_stable_target_fingerprint)
    $script:OfficialAttempt2Progress.process_c_completed = $true
    $script:OfficialAttempt2Progress.comparison_started = $true
    $comparison = Compare-ColdRestoreManifests `
        $producerRun.manifest $consumerRun.manifest $validatorRun.manifest
    $script:OfficialAttempt2Progress.comparison_completed = $true
    return [pscustomobject]@{
        producer = $producerRun
        consumer = $consumerRun
        validator = $validatorRun
        comparison = $comparison
    }
}

function Read-ContractManifestFixture {
    param([Parameter(Mandatory = $true)][string]$Path)
    Assert-ColdRestoreCondition (Test-Path -LiteralPath $Path -PathType Leaf) "contract_fixture_missing"
    try {
        $fixture = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        throw "contract_fixture_invalid"
    }
    Assert-ColdRestoreCondition (Test-ExactFieldSet $fixture $RoleSequence) "contract_fixture_role_set_invalid"
    foreach ($role in $RoleSequence) {
        Assert-ColdRestoreManifest $fixture.$role $role $RunId
    }
    return $fixture
}

function Compare-ColdRestoreManifests {
    param(
        [Parameter(Mandatory = $true)]$Producer,
        [Parameter(Mandatory = $true)]$Consumer,
        [Parameter(Mandatory = $true)]$Validator
    )
    foreach ($manifest in @($Producer, $Consumer, $Validator)) {
        Assert-ColdRestoreCondition ([bool]$manifest.success) "role_reported_failure"
    }
    $processIds = @([int64]$Producer.process_id, [int64]$Consumer.process_id, [int64]$Validator.process_id)
    Assert-ColdRestoreCondition (@($processIds | Sort-Object -Unique).Count -eq 3) "process_id_reuse"
    Assert-ColdRestoreCondition ([string]$Producer.head_sha -eq [string]$Consumer.head_sha `
        -and [string]$Consumer.head_sha -eq [string]$Validator.head_sha) "head_sha_mismatch"
    Assert-ColdRestoreCondition ([string]$Producer.scenario_fingerprint -match '^[0-9a-f]{64}$' `
        -and [string]$Producer.scenario_fingerprint -eq [string]$Consumer.scenario_fingerprint `
        -and [string]$Consumer.scenario_fingerprint -eq [string]$Validator.scenario_fingerprint) "scenario_fingerprint_mismatch"
    Assert-ColdRestoreCondition ([int]$Producer.generation -eq 1 -and [int]$Consumer.generation -eq 2 `
        -and [int]$Validator.generation -eq 2) "generation_sequence_invalid"
    Assert-ColdRestoreCondition ([string]$Producer.slot_state -eq "ready" `
        -and [string]$Consumer.slot_state -eq "restored" `
        -and [string]$Validator.slot_state -eq "validated") "slot_state_sequence_invalid"

    $generation1Digest = [string]$Producer.saved_sections_digest
    Assert-ColdRestoreCondition ($generation1Digest -ne "" `
        -and $generation1Digest -eq [string]$Consumer.source_sections_digest `
        -and $generation1Digest -eq [string]$Consumer.restored_sections_digest) "generation1_digest_mismatch"
    $generation2Digest = [string]$Consumer.saved_sections_digest
    Assert-ColdRestoreCondition ($generation2Digest -ne "" `
        -and $generation2Digest -eq [string]$Validator.source_sections_digest `
        -and $generation2Digest -eq [string]$Validator.restored_sections_digest) "generation2_digest_mismatch"

    Assert-ColdRestoreCondition ([string]$Producer.write_id -ne "" -and [string]$Consumer.write_id -ne "" `
        -and [string]$Producer.write_id -ne [string]$Consumer.write_id) "write_id_rotation_invalid"
    Assert-ColdRestoreCondition ([string]$Producer.write_fingerprint -ne "" -and [string]$Consumer.write_fingerprint -ne "" `
        -and [string]$Producer.write_fingerprint -ne [string]$Consumer.write_fingerprint) "write_fingerprint_rotation_invalid"
    Assert-ColdRestoreCondition ([string]$Consumer.source_write_id -eq [string]$Producer.write_id `
        -and [string]$Consumer.source_write_fingerprint -eq [string]$Producer.write_fingerprint `
        -and [string]$Validator.source_write_id -eq [string]$Consumer.write_id `
        -and [string]$Validator.source_write_fingerprint -eq [string]$Consumer.write_fingerprint) "write_chain_mismatch"

    $queueTargetResolutionId = [int64]$Producer.queue_trigger_resolution_id
    $queueTargetFingerprint = [string]$Producer.queue_trigger_stable_target_fingerprint
    Assert-ColdRestoreCondition ($queueTargetResolutionId -gt 0 `
        -and $queueTargetFingerprint -match '^[0-9a-f]{64}$') "queue_target_identity_invalid"
    Assert-ColdRestoreCondition ([int64]$Consumer.queue_trigger_resolution_id -eq $queueTargetResolutionId `
        -and [int64]$Validator.queue_trigger_resolution_id -eq $queueTargetResolutionId `
        -and [string]$Consumer.queue_trigger_stable_target_fingerprint -eq $queueTargetFingerprint `
        -and [string]$Validator.queue_trigger_stable_target_fingerprint -eq $queueTargetFingerprint) "queue_target_identity_mismatch"

    foreach ($manifest in @($Producer, $Consumer, $Validator)) {
        Assert-ColdRestoreCondition ([int]$manifest.section_count -eq 19 `
            -and [int]$manifest.preflight_count -eq 19) "section_or_preflight_count_invalid"
        Assert-ColdRestoreCondition ([int]$manifest.save_capture_world_delta -eq 0 `
            -and [int]$manifest.save_capture_rng_delta -eq 0 `
            -and [int]$manifest.save_capture_log_delta -eq 0) "save_capture_delta_nonzero"
    }
    Assert-ColdRestoreCondition ([int]$Producer.owner_apply_count -eq 0 `
        -and [int]$Producer.registry_apply_count -eq 0 `
        -and [int]$Producer.registry_commit_count -eq 0 `
        -and [int]$Producer.registry_rebind_count -eq 0 `
        -and [int]$Producer.partial_restore_state_count -eq 0) "producer_apply_count_invalid"
    foreach ($manifest in @($Consumer, $Validator)) {
        Assert-ColdRestoreCondition ([int]$manifest.owner_apply_count -eq 19 `
            -and [int]$manifest.registry_apply_count -eq 1 `
            -and [int]$manifest.registry_commit_count -eq 1 `
            -and [int]$manifest.registry_rebind_count -eq 1 `
            -and [int]$manifest.partial_restore_state_count -eq 0) "restore_apply_count_invalid"
        foreach ($field in $RestoreDeltaFields) {
            Assert-ColdRestoreCondition ([int]$manifest.$field -eq 0) "restore_delta_nonzero"
        }
        Assert-ColdRestoreCondition ([int]$manifest.rng_draw_count_before -eq [int]$manifest.rng_draw_count_after) "restore_rng_count_changed"
        foreach ($field in @(
            "world_fingerprint_match",
            "rng_cursor_match",
            "ai_state_fingerprint_match",
            "card_inventory_fingerprint_match",
            "queue_fingerprint_match"
        )) {
            Assert-ColdRestoreCondition ([bool]$manifest.$field) "typed_restore_fingerprint_mismatch"
        }
    }
    foreach ($field in @(
        "world_fingerprint_match",
        "rng_cursor_match",
        "ai_state_fingerprint_match",
        "card_inventory_fingerprint_match",
        "queue_fingerprint_match",
        "generation_2_recapture_fingerprint_match",
        "generation_2_rng_cursor_match"
    )) {
        Assert-ColdRestoreCondition (-not [bool]$Producer.$field) "producer_role_typed_evidence_non_neutral"
    }
    Assert-ColdRestoreCondition (-not [bool]$Consumer.generation_2_recapture_fingerprint_match `
        -and -not [bool]$Consumer.generation_2_rng_cursor_match `
        -and [int]$Consumer.generation_2_duplicate_transaction_count -eq 0 `
        -and [int]$Producer.generation_2_duplicate_transaction_count -eq 0) "role_typed_evidence_non_neutral"
    foreach ($field in @(
        "source_sections_digest",
        "restored_sections_digest",
        "source_write_id",
        "source_write_fingerprint"
    )) {
        Assert-ColdRestoreCondition ([string]$Producer.$field -eq "") "producer_role_empty_field_invalid"
    }
    foreach ($field in @("saved_sections_digest", "write_id", "write_fingerprint")) {
        Assert-ColdRestoreCondition ([string]$Validator.$field -eq "") "validator_role_empty_field_invalid"
    }
    foreach ($field in $RestoreDeltaFields) {
        Assert-ColdRestoreCondition ([int]$Producer.$field -eq 0) "producer_role_zero_invalid"
    }
    foreach ($manifest in @($Producer, $Consumer, $Validator)) {
        Assert-ColdRestoreCondition ([bool]$manifest.save_readback_green `
            -and [bool]$manifest.save_fingerprint_parity) "save_readback_or_fingerprint_invalid"
        foreach ($field in $DuplicateCountFields) {
            Assert-ColdRestoreCondition ([int]$manifest.$field -eq 0) "duplicate_side_effect_detected"
        }
    }
    foreach ($field in $SettlementCountFields) {
        Assert-ColdRestoreCondition ([int]$Producer.$field -eq 0) "producer_role_zero_invalid"
    }
    Assert-ColdRestoreCondition (@($Producer.victory_state_sequence).Count -eq 0 `
        -and [int]$Producer.terminal_quiescent_frames -eq 0 `
        -and [int]$Producer.terminal_world_delta -eq 0 `
        -and [int]$Producer.terminal_rng_draw_delta -eq 0) "producer_role_zero_invalid"

    foreach ($field in $ActionCountFields) {
        Assert-ColdRestoreCondition ([int]$Consumer.$field -gt 0) "consumer_action_count_missing"
        Assert-ColdRestoreCondition ([int]$Validator.$field -eq 0) "validator_action_count_nonzero"
    }
    Assert-ColdRestoreCondition ([int]$Producer.queue_entry_count -eq 1 `
        -and [int]$Producer.queue_target_pending_before_resume -eq 1 `
        -and [int]$Producer.queue_target_pending_after_resume -eq 1 `
        -and [int]$Producer.queue_target_completed_before_resume -eq 0 `
        -and [int]$Producer.queue_target_completed_after_resume -eq 0 `
        -and [int]$Producer.queue_target_history_before_resume -eq 0 `
        -and [int]$Producer.queue_target_history_after_resume -eq 0 `
        -and [int]$Producer.queue_target_execution_finalize_delta -eq 0 `
        -and [int]$Producer.queue_target_history_append_delta -eq 0) "producer_queue_target_state_invalid"
    foreach ($field in $QueueTargetSideEffectDeltaFields) {
        Assert-ColdRestoreCondition ([int]$Producer.$field -eq 0) "producer_queue_target_state_invalid"
    }
    Assert-ColdRestoreCondition ([int]$Consumer.queue_target_pending_before_resume -eq 1 `
        -and [int]$Consumer.queue_target_pending_after_resume -eq 0 `
        -and [int]$Consumer.queue_target_completed_before_resume -eq 0 `
        -and [int]$Consumer.queue_target_completed_after_resume -eq 1 `
        -and [int]$Consumer.queue_target_history_before_resume -eq 0 `
        -and [int]$Consumer.queue_target_history_after_resume -eq 1 `
        -and [int]$Consumer.queue_target_execution_finalize_delta -eq 1 `
        -and [int]$Consumer.queue_target_history_append_delta -eq 1) "consumer_queue_target_exact_once_invalid"
    foreach ($field in $QueueTargetSideEffectDeltaFields) {
        Assert-ColdRestoreCondition ([int]$Consumer.$field -eq 0) "consumer_queue_target_duplicate_side_effect"
    }
    Assert-ColdRestoreCondition ([int]$Validator.queue_target_pending_before_resume -eq 0 `
        -and [int]$Validator.queue_target_pending_after_resume -eq 0 `
        -and [int]$Validator.queue_target_completed_before_resume -eq 1 `
        -and [int]$Validator.queue_target_completed_after_resume -eq 1 `
        -and [int]$Validator.queue_target_history_before_resume -eq 1 `
        -and [int]$Validator.queue_target_history_after_resume -eq 1 `
        -and [int]$Validator.queue_target_execution_finalize_delta -eq 0 `
        -and [int]$Validator.queue_target_history_append_delta -eq 0) "validator_queue_target_lineage_invalid"
    foreach ($field in $QueueTargetSideEffectDeltaFields) {
        Assert-ColdRestoreCondition ([int]$Validator.$field -eq 0) "validator_queue_target_duplicate_side_effect"
    }
    foreach ($field in $GenerationTwoExactCountFields) {
        Assert-ColdRestoreCondition ([int]$Validator.$field -eq [int]$Consumer.$field) "validator_generation_two_count_mismatch"
    }
    Assert-ColdRestoreCondition ([bool]$Consumer.production_surface_ready `
        -and [bool]$Validator.production_surface_ready) "production_surface_not_ready"
    Assert-ColdRestoreCondition ([bool]$Producer.victory_unresolved_before_save `
        -and [bool]$Consumer.victory_unresolved_before_save `
        -and [bool]$Validator.victory_unresolved_before_save) "preterminal_victory_state_invalid"
    Assert-ColdRestoreCondition ([bool]$Validator.generation_2_recapture_fingerprint_match `
        -and [bool]$Validator.generation_2_rng_cursor_match `
        -and [int]$Validator.generation_2_duplicate_transaction_count -eq 0) "generation_two_restore_evidence_invalid"
    $expectedVictorySequence = @("idle", "qualification", "audit", "resolved")
    $consumerVictory = @($Consumer.victory_state_sequence) | ConvertTo-Json -Compress
    $expectedVictory = $expectedVictorySequence | ConvertTo-Json -Compress
    Assert-ColdRestoreCondition ($consumerVictory -eq $expectedVictory `
        -and @($Validator.victory_state_sequence).Count -eq 0) "victory_sequence_mismatch"
    foreach ($field in $SettlementCountFields) {
        Assert-ColdRestoreCondition ([int]$Consumer.$field -eq 1 `
            -and [int]$Validator.$field -eq 0) "final_settlement_exact_once_invalid"
    }
    Assert-ColdRestoreCondition ([int]$Consumer.terminal_quiescent_frames -ge 8 `
        -and [int]$Consumer.terminal_world_delta -eq 0 `
        -and [int]$Consumer.terminal_rng_draw_delta -eq 0) "terminal_quiet_delta_nonzero"
    Assert-ColdRestoreCondition ([int]$Validator.terminal_quiescent_frames -eq 0 `
        -and [int]$Validator.terminal_world_delta -eq 0 `
        -and [int]$Validator.terminal_rng_draw_delta -eq 0) "validator_terminal_continuation_invalid"
    Assert-ColdRestoreCondition (-not [bool]$Producer.backup_created `
        -and [bool]$Consumer.backup_created -and -not [bool]$Validator.backup_created) "backup_generation_binding_invalid"

    return [pscustomobject]@{
        process_ids_distinct = $true
        head_sha_match = $true
        generation1_digest_match = $true
        generation2_digest_match = $true
        write_chain_match = $true
        queue_target_identity_match = $true
        pending_queue_exact_once = $true
        section_counts_exact = $true
        save_capture_deltas_zero = $true
        restore_deltas_zero = $true
        action_counts_positive = $true
        generation2_counts_exact = $true
        registry_commit_rebind_exact = $true
        save_readback_exact = $true
        duplicate_counts_zero = $true
        typed_restore_fingerprints_match = $true
        generation_two_restore_exact = $true
        final_settlement_exact_once = $true
        terminal_quiescent_frames = [int]$Consumer.terminal_quiescent_frames
        terminal_quiet = $true
    }
}

function Resolve-ColdRestoreGitCommonDirectory {
    param([Parameter(Mandatory = $true)][string]$ResolvedProjectPath)

    $lines = @(& git -C $ResolvedProjectPath rev-parse --path-format=absolute --git-common-dir 2>$null)
    Assert-ColdRestoreCondition ($LASTEXITCODE -eq 0 -and $lines.Count -eq 1) "git_common_dir_unavailable"
    $resolved = [IO.Path]::GetFullPath([string]$lines[0])
    Assert-ColdRestoreCondition ([IO.Directory]::Exists($resolved)) "git_common_dir_invalid"
    return $resolved
}

function Get-ColdRestoreOfficialAttemptBoundaryObservation {
    param([Parameter(Mandatory = $true)][string]$ResolvedProjectPath)

    $gitCommonDirectory = Resolve-ColdRestoreGitCommonDirectory $ResolvedProjectPath
    $attempt1Path = Join-Path $gitCommonDirectory $OfficialAttempt1ClaimRelativePath
    $attempt2Path = Join-Path $gitCommonDirectory $OfficialAttempt2ClaimRelativePath
    $attempt1Present = [IO.File]::Exists($attempt1Path)
    $attempt1Sha256 = if ($attempt1Present) {
        (Get-FileHash -LiteralPath $attempt1Path -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    else {
        ""
    }
    $officialRoot = Join-Path $gitCommonDirectory "codex\cold_restore_v3"
    try {
        $officialDirectories = @(Get-ChildItem -LiteralPath $officialRoot -Directory -Filter "official-*" -ErrorAction Stop)
        $officialClaims = @(
            $officialDirectories | ForEach-Object {
                Get-ChildItem -LiteralPath $_.FullName -File -Filter "*claim*.json" -ErrorAction Stop
            }
        )
    }
    catch {
        throw "official_claim_inventory_unavailable"
    }
    $attempt2Present = [IO.File]::Exists($attempt2Path)
    $attempt2Sha256 = if ($attempt2Present) {
        (Get-FileHash -LiteralPath $attempt2Path -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    else {
        ""
    }
    $expectedPaths = @([IO.Path]::GetFullPath($attempt1Path), [IO.Path]::GetFullPath($attempt2Path))
    $unexpectedClaims = @($officialClaims | Where-Object {
        $expectedPaths -cnotcontains [IO.Path]::GetFullPath($_.FullName)
    })
    return [pscustomobject]@{
        path = $attempt1Path
        sha256 = $attempt1Sha256
        attempt_1_path = $attempt1Path
        attempt_1_sha256 = $attempt1Sha256
        attempt_1_valid = $attempt1Present -and $attempt1Sha256 -ceq $OfficialAttempt1ClaimSha256
        attempt_2_path = $attempt2Path
        attempt_2_sha256 = $attempt2Sha256
        attempt_2_claim_present = $attempt2Present
        attempt_2_absent = -not $attempt2Present
        claim_count = $(cold_restore_attested_process\Get-ColdRestoreSafeCollectionCount $officialClaims)
        unexpected_claim_count = $(cold_restore_attested_process\Get-ColdRestoreSafeCollectionCount $unexpectedClaims)
    }
}

function Assert-ColdRestoreOfficialAttemptBoundary {
    param([Parameter(Mandatory = $true)][string]$ResolvedProjectPath)

    $observation = Get-ColdRestoreOfficialAttemptBoundaryObservation $ResolvedProjectPath
    Assert-ColdRestoreCondition ([bool]$observation.attempt_1_valid) "official_attempt_1_claim_mutated"
    Assert-ColdRestoreCondition ([int]$observation.claim_count -eq 1 `
        -and [bool]$observation.attempt_2_absent `
        -and [int]$observation.unexpected_claim_count -eq 0) "official_attempt_2_claim_must_be_absent"
    return $observation
}

function Assert-ColdRestoreOfficialAttempt2Boundary {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedProjectPath,
        [Parameter(Mandatory = $true)][string]$ExpectedAttempt2Sha256
    )

    $observation = Get-ColdRestoreOfficialAttemptBoundaryObservation $ResolvedProjectPath
    Assert-ColdRestoreCondition ([bool]$observation.attempt_1_valid `
        -and [bool]$observation.attempt_2_claim_present `
        -and [string]$observation.attempt_2_sha256 -ceq $ExpectedAttempt2Sha256 `
        -and [int]$observation.claim_count -eq 2 `
        -and [int]$observation.unexpected_claim_count -eq 0) "official_attempt_2_claim_boundary_invalid"
    return $observation
}

function Get-ColdRestoreOrchestratorCreationTimeTicks {
    try {
        return ([Diagnostics.Process]::GetProcessById($PID).StartTime.ToUniversalTime().Ticks).ToString([Globalization.CultureInfo]::InvariantCulture)
    }
    catch {
        throw "orchestrator_creation_time_unavailable"
    }
}

function Consume-ColdRestoreTargetedOwnerCaptureDiagnosticQuota {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedProjectPath,
        [Parameter(Mandatory = $true)][string]$HeadSha,
        [Parameter(Mandatory = $true)]$PreQuotaContext
    )

    $gitCommonDirectory = Resolve-ColdRestoreGitCommonDirectory $ResolvedProjectPath
    $officialBoundary = Assert-ColdRestoreOfficialAttemptBoundary $ResolvedProjectPath
    $previousLedgerPath = Join-Path $gitCommonDirectory $PreviousTargetedOwnerCaptureQuotaLedgerRelativePath
    Assert-ColdRestoreCondition ([IO.File]::Exists($previousLedgerPath) `
        -and (Get-FileHash -LiteralPath $previousLedgerPath -Algorithm SHA256).Hash.ToLowerInvariant() -ceq $PreviousTargetedOwnerCaptureQuotaLedgerSha256) "previous_targeted_owner_capture_ledger_mutated"
    $exhaustedV2LedgerPath = Join-Path $gitCommonDirectory $ExhaustedTargetedOwnerCaptureQuotaLedgerRelativePath
    Assert-ColdRestoreCondition (-not [IO.File]::Exists($exhaustedV2LedgerPath)) "exhausted_v2_targeted_owner_capture_ledger_must_remain_absent"
    $historicalRevision = "$HistoricalTargetedOwnerCaptureInvocationCommit`:$HistoricalTargetedOwnerCaptureInvocationPath"
    $historicalBlobLines = @(& git -C $ResolvedProjectPath rev-parse $historicalRevision 2>$null)
    Assert-ColdRestoreCondition ($LASTEXITCODE -eq 0 `
        -and (cold_restore_attested_process\Get-ColdRestoreSafeCollectionCount $historicalBlobLines) -eq 1 `
        -and [string]$historicalBlobLines[0] -ceq $HistoricalTargetedOwnerCaptureInvocationBlobSha1) "historical_targeted_owner_capture_invocation_record_mutated"
    $historicalJsonLines = @(& git -C $ResolvedProjectPath show $historicalRevision 2>$null)
    Assert-ColdRestoreCondition ($LASTEXITCODE -eq 0 `
        -and (cold_restore_attested_process\Get-ColdRestoreSafeCollectionCount $historicalJsonLines) -gt 0) "historical_targeted_owner_capture_invocation_record_unavailable"
    try {
        $historicalRecord = ($historicalJsonLines -join "`n") | ConvertFrom-Json
    }
    catch {
        throw "historical_targeted_owner_capture_invocation_record_invalid"
    }
    $historicalDiagnostic = $historicalRecord.targeted_owner_capture_diagnostic
    Assert-ColdRestoreCondition ([int]$historicalDiagnostic.attempted_count_after -eq 2 `
        -and [bool]$historicalDiagnostic.second_diagnostic_run_performed `
        -and [string]$historicalDiagnostic.quota_ledger_status -ceq "NOT_CREATED" `
        -and -not [bool]$historicalDiagnostic.evidence_root_created `
        -and -not [bool]$historicalDiagnostic.scenario_identity_attested `
        -and -not [bool]$historicalDiagnostic.owner_audit_started) "historical_targeted_owner_capture_invocation_count_invalid"
    Assert-ColdRestoreCondition ([IO.File]::Exists([string]$PreQuotaContext.admission_path) `
        -and (Get-FileHash -LiteralPath $PreQuotaContext.admission_path -Algorithm SHA256).Hash.ToLowerInvariant() -ceq [string]$PreQuotaContext.admission_sha256 `
        -and [string]$PreQuotaContext.admission_fingerprint -cmatch '^[0-9a-f]{64}$') "prequota_bootstrap_admission_binding_invalid"
    $ledgerPath = Join-Path $gitCommonDirectory $TargetedOwnerCaptureQuotaLedgerRelativePath
    Assert-ColdRestoreCondition ([IO.Path]::GetFullPath($ledgerPath) -ceq [IO.Path]::GetFullPath([string]$PreQuotaContext.value.quota_ledger_path)) "prequota_quota_ledger_path_mismatch"
    $ledger = [ordered]@{
        schema_version = [int]$TargetedLedgerBindingContract.exact_literals.schema_version
        ledger_id = [string]$TargetedOwnerCaptureAuthorization.ledger_id
        authorization_id = $TargetedOwnerCaptureAuthorizationId
        task_id = $TargetedOwnerCaptureTaskId
        created_at_utc = [DateTime]::UtcNow.ToString("O", [Globalization.CultureInfo]::InvariantCulture)
        run_id = $RunId
        repository_head = $HeadSha
        scenario_fingerprint = $ExpectedScenarioFingerprint
        authorized_new_diagnostic_count = [int]$TargetedOwnerCaptureAuthorization.authorized_increment
        diagnostic_count_before = [int]$TargetedOwnerCaptureAuthorization.permitted_transition_from
        diagnostic_count_after = [int]$TargetedOwnerCaptureAuthorization.permitted_transition_to
        diagnostic_count_maximum = [int]$TargetedOwnerCaptureAuthorization.maximum_invocation_count
        previous_ledger_sha256 = $PreviousTargetedOwnerCaptureQuotaLedgerSha256
        historical_invocation_commit = $HistoricalTargetedOwnerCaptureInvocationCommit
        historical_invocation_blob_sha1 = $HistoricalTargetedOwnerCaptureInvocationBlobSha1
        historical_invocation_file_sha256 = $HistoricalTargetedOwnerCaptureInvocationFileSha256
        bootstrap_admission_path = [IO.Path]::GetFullPath([string]$PreQuotaContext.admission_path)
        bootstrap_admission_sha256 = [string]$PreQuotaContext.admission_sha256
        bootstrap_admission_fingerprint = [string]$PreQuotaContext.admission_fingerprint
        prequota_attestation_path = [IO.Path]::GetFullPath([string]$PreQuotaContext.attestation_path)
        role_timeout_policy_sha256 = [string]$RoleTimeoutPolicyEvidence.sha256
        official_attempt_1_claim_sha256 = [string]$officialBoundary.sha256
        official_attempt_2_claim_absent = [bool]$TargetedLedgerBindingContract.boolean_rules.official_attempt_2_claim_absent
        official = [bool]$TargetedLedgerBindingContract.boolean_rules.official
        formal = [bool]$TargetedLedgerBindingContract.boolean_rules.formal
        official_authorization_consumed = [bool]$TargetedLedgerBindingContract.boolean_rules.official_authorization_consumed
        orchestrator_script_sha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()
        orchestrator_process_id = $PID
        orchestrator_creation_time_utc_ticks = (Get-ColdRestoreOrchestratorCreationTimeTicks)
        claim_nonce = [Guid]::NewGuid().ToString("N")
        launch_nonce = [Guid]::NewGuid().ToString("N")
        status = [string]$TargetedLedgerBindingContract.exact_literals.status
    }
    Assert-ColdRestoreCondition ([string]$ledger.claim_nonce -cne [string]$ledger.launch_nonce) "targeted_owner_capture_nonce_collision"
    $ledgerFingerprint = cold_restore_prequota_bootstrap\Publish-ColdRestoreCurrentTargetedQuotaLedger $ledgerPath ([pscustomobject]$ledger)
    return [pscustomobject]@{
        path = $ledgerPath
        fingerprint = [string]$ledgerFingerprint
        value = [pscustomobject]$ledger
        launch_authorization = [pscustomobject][ordered]@{
            authorization_id = $TargetedOwnerCaptureAuthorizationId
            claim_fingerprint = [string]$ledgerFingerprint
            claim_nonce = [string]$ledger.claim_nonce
            source_head_sha = $HeadSha
            scenario_fingerprint = $ExpectedScenarioFingerprint
            run_id = $RunId
            process_role = "producer"
            launch_nonce = [string]$ledger.launch_nonce
            orchestrator_process_id = $PID
            orchestrator_creation_time_utc_ticks = [string]$ledger.orchestrator_creation_time_utc_ticks
        }
    }
}

function Assert-ColdRestoreProcessARehearsalPrerequisites {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedProjectPath,
        [Parameter(Mandatory = $true)][string]$HeadSha
    )

    $handoffPath = Join-Path $ResolvedProjectPath "reports\handoffs\alpha04c_save_resume_current.json"
    $wrapperPath = Join-Path $ResolvedProjectPath "reports\handoffs\alpha04c_wrapper_exit_attestation_result.json"
    $gateCachePath = Join-Path $ResolvedProjectPath "reports\handoffs\alpha04c_gate_cache.json"
    $programStatePath = Join-Path $ResolvedProjectPath "docs\development\current_program_state.json"
    $handoff = Read-ColdRestoreJsonArtifact $handoffPath
    $wrapper = Read-ColdRestoreJsonArtifact $wrapperPath
    $gateCache = Read-ColdRestoreJsonArtifact $gateCachePath
    $programState = Read-ColdRestoreJsonArtifact $programStatePath
    Assert-ColdRestoreCondition ([int]$handoff.transactional_save_owner_count -eq 19 `
        -and [int]$handoff.unsupported_save_owner_count -eq 0 `
        -and [bool]$handoff.allocator_cursor_repair.persistence_green `
        -and [bool]$handoff.allocator_cursor_repair.expired_quote_omission_green `
        -and [bool]$handoff.allocator_cursor_repair.next_quote_id_parity `
        -and [bool]$handoff.allocator_cursor_repair.next_listing_id_parity `
        -and [bool]$handoff.allocator_cursor_repair.next_transaction_id_parity `
        -and [string]$handoff.focused_tests.allocator_cursor_spec -ceq "34/34" `
        -and [string]$handoff.focused_tests.production_registry_transaction_current -ceq "59/59" `
        -and [string]$handoff.focused_tests.production_save_capture_readback -ceq "25/25" `
        -and [bool]$handoff.role_timeout_policy_green `
        -and [int]$handoff.continuation_action_routing_change_count -eq 0 `
        -and [int]$handoff.continuation_queue_behavior_change_count -eq 0 `
        -and -not [bool]$handoff.third_formal_run_performed `
        -and -not [bool]$handoff.full_smoke) "process_a_rehearsal_save_prerequisites_invalid"
    Assert-ColdRestoreCondition ([string]$wrapper.short_gates.registry_owner_preflight -ceq "19/19" `
        -and [string]$wrapper.short_gates.registry_owner_fault_rollback -ceq "19/19" `
        -and [int]$wrapper.short_gates.registry_owner_apply_count -eq 19 `
        -and [int]$wrapper.short_gates.registry_commit_count -eq 1 `
        -and [int]$wrapper.short_gates.registry_rebind_count -eq 1 `
        -and [int]$wrapper.scope_deltas.production_action_routing_change_count -eq 0 `
        -and [int]$wrapper.scope_deltas.production_queue_owner_change_count -eq 0) "process_a_rehearsal_registry_prerequisites_invalid"
    $fileFaultGates = @($gateCache.gates | Where-Object { [string]$_.gate_id -ceq "file_fault_matrix" })
    $saveConfirmationGates = @($gateCache.gates | Where-Object { [string]$_.gate_id -ceq "save_confirmation" })
    $forkParityGates = @($gateCache.gates | Where-Object { [string]$_.gate_id -ceq "fork_determinism_parity" })
    Assert-ColdRestoreCondition ((cold_restore_attested_process\Get-ColdRestoreSafeCollectionCount $fileFaultGates) -eq 1 `
        -and [string]$fileFaultGates[0].result.status -ceq "PASS" `
        -and [int]$fileFaultGates[0].result.checks -eq 16 `
        -and (cold_restore_attested_process\Get-ColdRestoreSafeCollectionCount $saveConfirmationGates) -eq 1 `
        -and [string]$saveConfirmationGates[0].result.status -ceq "PASS" `
        -and [int]$saveConfirmationGates[0].result.checks -eq 10 `
        -and (cold_restore_attested_process\Get-ColdRestoreSafeCollectionCount $forkParityGates) -eq 1 `
        -and [string]$forkParityGates[0].result.status -ceq "PASS" `
        -and [int]$forkParityGates[0].result.checks -eq 14 `
        -and [string]$wrapper.short_gates.save_confirmation -ceq "10/10" `
        -and [string]$wrapper.short_gates.fork_parity -ceq "14/14") "process_a_rehearsal_frozen_save_gates_invalid"
    Assert-ColdRestoreCondition ([string]$programState.known_test_state.alpha04_a_regression -ceq "GREEN_598_OF_598" `
        -and [string]$programState.known_test_state.alpha04_b_roster_inspection_schema_privacy -ceq "GREEN_268_OF_268" `
        -and [string]$programState.known_test_state.alpha04_b_region_action_semantic_flow -ceq "GREEN_273_OF_273" `
        -and [string]$programState.known_test_state.alpha04_b_legacy_retirement_architecture -ceq "GREEN_60_OF_60" `
        -and [string]$programState.known_test_state.alpha04_b_layout_measurement -ceq "GREEN_28_OF_28" `
        -and [string]$programState.known_test_state.alpha04_b_production_ui_journey -ceq "GREEN_53_OF_53_WITH_10_SCREENSHOTS" `
        -and [string]$programState.known_test_state.alpha04c_allocator_cursor_spec -ceq "GREEN_34_OF_34" `
        -and [string]$programState.known_test_state.alpha04c_production_registry_transaction_current -ceq "GREEN_59_OF_59" `
        -and [string]$programState.known_test_state.alpha04c_production_save_capture_readback -ceq "GREEN_25_OF_25") "process_a_rehearsal_regression_prerequisites_invalid"
    $changedPaths = @(& git -C $ResolvedProjectPath diff --name-only $HistoricalTargetedOwnerCaptureInvocationCommit $HeadSha 2>$null)
    Assert-ColdRestoreCondition ($LASTEXITCODE -eq 0) "process_a_rehearsal_scope_diff_unavailable"
    $forbiddenPaths = @(
        $changedPaths | Where-Object {
            [string]$_ -notmatch '^(scripts/tools/|tests/)'
        }
    )
    Assert-ColdRestoreCondition ((cold_restore_attested_process\Get-ColdRestoreSafeCollectionCount $forbiddenPaths) -eq 0) "process_a_rehearsal_production_scope_changed"
    $evidence = [ordered]@{
        schema_version = 1
        evidence_id = "ProcessARehearsalPrerequisiteEvidenceV1"
        repository_head = $HeadSha
        scenario_fingerprint = $ExpectedScenarioFingerprint
        handoff_sha256 = (Get-FileHash -LiteralPath $handoffPath -Algorithm SHA256).Hash.ToLowerInvariant()
        wrapper_baseline_sha256 = (Get-FileHash -LiteralPath $wrapperPath -Algorithm SHA256).Hash.ToLowerInvariant()
        gate_cache_sha256 = (Get-FileHash -LiteralPath $gateCachePath -Algorithm SHA256).Hash.ToLowerInvariant()
        program_state_sha256 = (Get-FileHash -LiteralPath $programStatePath -Algorithm SHA256).Hash.ToLowerInvariant()
        changed_path_count = cold_restore_attested_process\Get-ColdRestoreSafeCollectionCount $changedPaths
        forbidden_path_count = cold_restore_attested_process\Get-ColdRestoreSafeCollectionCount $forbiddenPaths
        registry_owner_capture_count = 19
        registry_owner_preflight_count = 19
        registry_owner_fault_rollback_count = 19
        registry_owner_apply_count = 19
        registry_commit_count = 1
        registry_rebind_count = 1
        allocator_cursor_checks_passed = 34
        allocator_cursor_checks_total = 34
        production_capture_checks_passed = 25
        production_capture_checks_total = 25
        file_fault_matrix_checks_passed = 16
        file_fault_matrix_checks_total = 16
        save_confirmation_checks_passed = 10
        save_confirmation_checks_total = 10
        fork_parity_checks_passed = 14
        fork_parity_checks_total = 14
        alpha04_a_regression_green = $true
        alpha04_b_regression_green = $true
        production_action_routing_change_count = 0
        production_queue_behavior_change_count = 0
        third_formal_run_performed = $false
        full_smoke = $false
        evidence_fingerprint = ""
    }
    $evidence.evidence_fingerprint = cold_restore_attested_process\Get-ColdRestoreEvidenceFingerprint ([pscustomobject]$evidence) "evidence_fingerprint"
    return [pscustomobject]$evidence
}

function Get-ColdRestoreProcessARehearsalDiagnosticAdmission {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedProjectPath,
        [Parameter(Mandatory = $true)][string]$HeadSha
    )
    $diagnosticRunId = cold_restore_authorization_contract_v1\Get-ColdRestoreAuthorizationRunId `
        $TargetedOwnerCaptureAuthorizationName $HeadSha
    $diagnosticRoot = Join-Path (Resolve-ColdRestoreGitCommonDirectory $ResolvedProjectPath) `
        $TargetedOwnerCaptureEvidenceRootRelativePath
    $diagnosticPath = Join-Path $diagnosticRoot "diagnostics\owner_capture_audit.json"
    $gitCommonDirectory = Resolve-ColdRestoreGitCommonDirectory $ResolvedProjectPath
    $quotaLedgerPath = Join-Path $gitCommonDirectory $TargetedOwnerCaptureQuotaLedgerRelativePath
    $quotaLedger = Read-ColdRestoreJsonArtifact $quotaLedgerPath
    Assert-ColdRestoreCondition ([int]$quotaLedger.orchestrator_process_id -gt 0) "process_a_rehearsal_diagnostic_quota_process_invalid"
    $diagnostic = Read-ColdRestoreJsonArtifact $diagnosticPath
    Assert-ColdRestoreTargetedDiagnosticV2 $diagnostic $HeadSha $diagnosticRunId
    Assert-ColdRestoreCondition ([bool]$diagnostic.scenario_identity_attested `
        -and [bool]$diagnostic.owner_audit_started `
        -and [bool]$diagnostic.owner_audit_completed `
        -and [int]$diagnostic.owner_capture_attempted_count -eq 19 `
        -and [int]$diagnostic.owner_capture_succeeded_count -eq 19 `
        -and [int]$diagnostic.owner_capture_failed_count -eq 0 `
        -and @($diagnostic.first_failure.PSObject.Properties).Count -eq 0 `
        -and @($diagnostic.post_capture_failure.PSObject.Properties).Count -eq 0 `
        -and [string]$diagnostic.post_capture_validation -ceq "PASSED" `
        -and [bool]$diagnostic.safety_green) "process_a_rehearsal_diagnostic_admission_not_green"
    return [pscustomobject]@{
        run_id = $diagnosticRunId
        path = $diagnosticPath
        sha256 = (Get-FileHash -LiteralPath $diagnosticPath -Algorithm SHA256).Hash.ToLowerInvariant()
        quota_ledger_path = $quotaLedgerPath
        launch_attestation_path = Join-Path $diagnosticRoot "launch\orchestrator-$($quotaLedger.orchestrator_process_id)\producer.authorized.json"
        manifest_path = Join-Path $diagnosticRoot "child\producer.result.json"
        child_attestation_path = Join-Path $diagnosticRoot "child\producer.completion.json"
        parent_attestation_path = Join-Path $diagnosticRoot "parent\producer.exit.json"
        stdout_path = Join-Path $diagnosticRoot "parent\producer.stdout.log"
        stderr_path = Join-Path $diagnosticRoot "parent\producer.stderr.log"
        diagnostic = $diagnostic
    }
}

function Consume-ColdRestoreProcessARehearsalQuota {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedProjectPath,
        [Parameter(Mandatory = $true)][string]$HeadSha,
        [Parameter(Mandatory = $true)]$DiagnosticAdmission
    )
    $gitCommonDirectory = Resolve-ColdRestoreGitCommonDirectory $ResolvedProjectPath
    $officialBoundary = Assert-ColdRestoreOfficialAttemptBoundary $ResolvedProjectPath
    $officialClaimRoot = Join-Path $gitCommonDirectory "codex\cold_restore_v3"
    $ledgerPath = Join-Path $gitCommonDirectory $ProcessARehearsalQuotaLedgerRelativePath
    $launchLedgerPath = Join-Path $gitCommonDirectory $ProcessARehearsalLaunchLedgerRelativePath
    Assert-ColdRestoreCondition ([IO.Path]::GetFullPath($DiagnosticAdmission.quota_ledger_path) -ceq [IO.Path]::GetFullPath((Join-Path $gitCommonDirectory $TargetedOwnerCaptureQuotaLedgerRelativePath))) "process_a_rehearsal_diagnostic_quota_path_invalid"
    try {
        $admission = process_a_rehearsal_admission_contract\New-ProcessARehearsalAdmission `
            -LedgerPath $ledgerPath `
            -RunId $RunId `
            -RepositoryHead $HeadSha `
            -ScenarioFingerprint $ExpectedScenarioFingerprint `
            -PrerequisiteEvidenceFingerprint ([string]$DiagnosticAdmission.stage3_prerequisites.evidence_fingerprint) `
            -TimeoutPolicyPath $RoleTimeoutPolicyEvidence.path `
            -AdmissionEvidencePath $DiagnosticAdmission.path `
            -DiagnosticQuotaLedgerPath $DiagnosticAdmission.quota_ledger_path `
            -DiagnosticLaunchAttestationPath $DiagnosticAdmission.launch_attestation_path `
            -DiagnosticManifestPath $DiagnosticAdmission.manifest_path `
            -DiagnosticChildAttestationPath $DiagnosticAdmission.child_attestation_path `
            -DiagnosticParentAttestationPath $DiagnosticAdmission.parent_attestation_path `
            -DiagnosticStdoutPath $DiagnosticAdmission.stdout_path `
            -DiagnosticStderrPath $DiagnosticAdmission.stderr_path `
            -OfficialClaimRoot $officialClaimRoot `
            -OfficialAttempt1ClaimPath $officialBoundary.path
    }
    catch {
        if ([string]$_.Exception.Message -eq "process_a_rehearsal_admission_already_consumed") {
            throw "process_a_rehearsal_already_consumed"
        }
        throw
    }
    $admission | Add-Member -NotePropertyName launch_ledger_path -NotePropertyValue $launchLedgerPath
    return $admission
}

function Assert-AndConsumeOfficialColdRestoreAuthorization {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedProjectPath,
        [Parameter(Mandatory = $true)][string]$HeadSha,
        [switch]$PreflightOnly
    )
    if ($PreflightOnly) {
        $null = cold_restore_official_attempt2_contract\Assert-ColdRestoreOfficialAttempt2PreflightAuthorizationCount `
            $AuthorizedOfficialColdRestoreCount
    }
    else {
        Assert-ColdRestoreCondition ($AuthorizedOfficialColdRestoreCount -eq 1) "official_authorization_count_invalid"
    }
    Assert-ColdRestoreCondition ($RunId -ceq (cold_restore_authorization_contract_v1\Get-ColdRestoreAuthorizationRunId `
            "official_attempt_2" $HeadSha)) "official_attempt_2_run_id_invalid"
    Assert-ColdRestoreCondition ($ExpectedScenarioFingerprint -ceq $TargetedOwnerCaptureScenarioFingerprint) "expected_scenario_fingerprint_invalid"
    $gitCommonDirectory = Resolve-ColdRestoreGitCommonDirectory $ResolvedProjectPath
    $candidateEvidenceRoot = Join-Path $ResolvedProjectPath ".godot\cold_restore_attestation_v1\$RunId"
    $candidateUserDataRoot = [IO.Path]::GetFullPath($UserDataRoot)
    $candidateClaimPath = Join-Path $gitCommonDirectory $OfficialAttempt2ClaimRelativePath
    $officialClaimRoot = Join-Path $gitCommonDirectory "codex\cold_restore_v3"
    $attempt1ClaimPath = Join-Path $gitCommonDirectory $OfficialAttempt1ClaimRelativePath
    $sideEffectSnapshotBefore = if ($PreflightOnly) {
        cold_restore_official_attempt2_contract\Get-ColdRestoreOfficialAttempt2SideEffectSnapshot `
            -OfficialClaimRoot $officialClaimRoot `
            -Attempt1ClaimPath $attempt1ClaimPath `
            -CandidateClaimPath $candidateClaimPath `
            -CandidateEvidenceRoot $candidateEvidenceRoot `
            -CandidateUserDataRoot $candidateUserDataRoot
    }
    else {
        $null
    }
    if ($PreflightOnly) {
        $null = cold_restore_official_attempt2_contract\Assert-ColdRestoreOfficialAttempt2CandidateRootsAbsent $sideEffectSnapshotBefore
    }
    else {
        Assert-ColdRestoreCondition (-not [IO.Directory]::Exists((Split-Path -Parent $candidateClaimPath)) `
            -and -not [IO.File]::Exists($candidateClaimPath) `
            -and -not [IO.Directory]::Exists($candidateEvidenceRoot) `
            -and -not [IO.Directory]::Exists($candidateUserDataRoot)) "official_attempt_2_candidate_root_collision"
    }
    $officialBoundary = Assert-ColdRestoreOfficialAttemptBoundary $ResolvedProjectPath
    $rehearsalRunId = cold_restore_authorization_contract_v1\Get-ColdRestoreAuthorizationRunId `
        "process_a_save_completion_rehearsal_v1" $HeadSha
    $rehearsalRoot = Join-Path $ResolvedProjectPath ".godot\cold_restore_attestation_v1\$rehearsalRunId"
    $outcomePath = Join-Path $gitCommonDirectory $ProcessARehearsalOutcomeLedgerRelativePath
    $admissionPath = Join-Path $gitCommonDirectory $ProcessARehearsalQuotaLedgerRelativePath
    $launchLedgerPath = Join-Path $gitCommonDirectory $ProcessARehearsalLaunchLedgerRelativePath
    $completionPath = Join-Path $rehearsalRoot "diagnostics\process_a.rehearsal_completion.json"
    $childPath = Join-Path $rehearsalRoot "child\producer.completion.json"
    $parentPath = Join-Path $rehearsalRoot "parent\producer.exit.json"
    $manifestPath = Join-Path $rehearsalRoot "child\producer.result.json"
    $timelinePath = Join-Path $rehearsalRoot "diagnostics\producer.phase_timeline.json"
    $stdoutPath = Join-Path $rehearsalRoot "parent\producer.stdout.log"
    $stderrPath = Join-Path $rehearsalRoot "parent\producer.stderr.log"
    $outcome = Read-ColdRestoreJsonArtifact $outcomePath
    $outcomeSha256 = (Get-FileHash -LiteralPath $outcomePath -Algorithm SHA256).Hash.ToLowerInvariant()
    Assert-ColdRestoreCondition ([int]$outcome.schema_version -eq 1 `
        -and [string]$outcome.outcome_id -ceq "ProcessARehearsalOutcomeLedgerV1" `
        -and [string]$outcome.authorization_id -ceq $ProcessARehearsalAuthorizationId `
        -and [string]$outcome.run_id -ceq $rehearsalRunId `
        -and [string]$outcome.repository_head -ceq $HeadSha `
        -and [string]$outcome.scenario_fingerprint -ceq $ExpectedScenarioFingerprint `
        -and -not [bool]$outcome.official `
        -and -not [bool]$outcome.formal `
        -and -not [bool]$outcome.official_attempt_2_claim_present `
        -and -not [bool]$outcome.official_attempt_2_authorization_consumed `
        -and [bool]$outcome.rehearsal_admission_consumed `
        -and [string]$outcome.rehearsal_green_head -ceq $HeadSha `
        -and [bool]$outcome.rehearsal_green_tree_clean `
        -and [bool]$outcome.rehearsal_green_git_diff_check_green `
        -and [string]$outcome.rehearsal_green_freeze_fingerprint -cmatch '^[0-9a-f]{64}$' `
        -and [bool]$outcome.launch_attestation_present `
        -and [bool]$outcome.child_attestation_present `
        -and [bool]$outcome.parent_attestation_present `
        -and [bool]$outcome.stdout_present `
        -and [bool]$outcome.stderr_present `
        -and [bool]$outcome.manifest_present `
        -and [bool]$outcome.phase_timeline_present `
        -and [bool]$outcome.completion_present `
        -and [bool]$outcome.wrapper_result_present `
        -and [bool]$outcome.observed_exit `
        -and [bool]$outcome.exit_code_observed `
        -and [int]$outcome.exit_code -eq 0 `
        -and -not [bool]$outcome.timed_out `
        -and -not [bool]$outcome.terminated_by_parent `
        -and [int]$outcome.task_owned_process_count_after -eq 0 `
        -and [string]$outcome.terminal_stage -ceq "success" `
        -and [bool]$outcome.success `
        -and [string]$outcome.terminal_code -ceq "ok" `
        -and [string]$outcome.evidence_fingerprint -ceq (cold_restore_attested_process\Get-ColdRestoreEvidenceFingerprint $outcome "evidence_fingerprint")) "official_attempt_2_rehearsal_outcome_invalid"
    $admission = process_a_rehearsal_admission_contract\Read-ProcessARehearsalAdmissionLedger $admissionPath ([string]$outcome.admission_ledger_sha256)
    $launchLedger = process_a_rehearsal_admission_contract\Read-ProcessARehearsalLaunchLedger $launchLedgerPath
    Assert-ColdRestoreCondition ([string]$launchLedger.value.admission_ledger_sha256 -ceq [string]$admission.fingerprint `
        -and [string]$launchLedger.value.repository_head -ceq $HeadSha `
        -and [string]$launchLedger.value.run_id -ceq $rehearsalRunId `
        -and [string]$launchLedger.value.timeout_policy_fingerprint -ceq [string]$RoleTimeoutPolicyEvidence.sha256) "official_attempt_2_rehearsal_launch_invalid"
    $launchAttestationPath = Join-Path $rehearsalRoot "launch\orchestrator-$($launchLedger.value.orchestrator_process_id)\producer.authorized.json"
    $artifactBindings = @(
        @($launchAttestationPath, [string]$outcome.launch_attestation_sha256),
        @($childPath, [string]$outcome.child_attestation_sha256),
        @($parentPath, [string]$outcome.parent_attestation_sha256),
        @($stdoutPath, [string]$outcome.stdout_sha256),
        @($stderrPath, [string]$outcome.stderr_sha256),
        @($manifestPath, [string]$outcome.manifest_sha256),
        @($timelinePath, [string]$outcome.phase_timeline_sha256),
        @($completionPath, [string]$outcome.completion_sha256)
    )
    foreach ($binding in $artifactBindings) {
        Assert-ColdRestoreCondition ([IO.File]::Exists([string]$binding[0]) `
            -and [string]$binding[1] -cmatch '^[0-9a-f]{64}$' `
            -and (Get-FileHash -LiteralPath ([string]$binding[0]) -Algorithm SHA256).Hash.ToLowerInvariant() -ceq [string]$binding[1]) "official_attempt_2_rehearsal_artifact_sha256_mismatch"
    }
    Assert-ColdRestoreCondition ([string]$launchLedger.value.launch_attestation_sha256 -ceq [string]$outcome.launch_attestation_sha256) "official_attempt_2_rehearsal_launch_sha256_mismatch"
    $diagnosticAdmission = Get-ColdRestoreProcessARehearsalDiagnosticAdmission $ResolvedProjectPath $HeadSha
    $stage3Prerequisites = Assert-ColdRestoreProcessARehearsalPrerequisites $ResolvedProjectPath $HeadSha
    Assert-ColdRestoreCondition ([string]$admission.value.prerequisite_evidence_fingerprint `
        -ceq [string]$stage3Prerequisites.evidence_fingerprint) "official_attempt_2_prerequisite_evidence_changed"
    process_a_rehearsal_admission_contract\Assert-ProcessARehearsalAdmissionSourcesUnchanged `
        -Admission $admission `
        -PrerequisiteEvidenceFingerprint ([string]$stage3Prerequisites.evidence_fingerprint) `
        -TimeoutPolicyPath $RoleTimeoutPolicyEvidence.path `
        -AdmissionEvidencePath $diagnosticAdmission.path `
        -DiagnosticQuotaLedgerPath $diagnosticAdmission.quota_ledger_path `
        -DiagnosticLaunchAttestationPath $diagnosticAdmission.launch_attestation_path `
        -DiagnosticManifestPath $diagnosticAdmission.manifest_path `
        -DiagnosticChildAttestationPath $diagnosticAdmission.child_attestation_path `
        -DiagnosticParentAttestationPath $diagnosticAdmission.parent_attestation_path `
        -DiagnosticStdoutPath $diagnosticAdmission.stdout_path `
        -DiagnosticStderrPath $diagnosticAdmission.stderr_path `
        -OfficialClaimRoot (Join-Path $gitCommonDirectory "codex\cold_restore_v3") `
        -OfficialAttempt1ClaimPath ([string]$officialBoundary.path) | Out-Null
    $manifest = Read-ColdRestoreJsonArtifact $manifestPath
    Assert-ColdRestoreManifest $manifest "producer" $rehearsalRunId
    Assert-ColdRestoreCondition ([bool]$manifest.success `
        -and [int]$manifest.section_count -eq 19 `
        -and [int]$manifest.preflight_count -eq 19 `
        -and [bool]$manifest.save_readback_green `
        -and [bool]$manifest.save_fingerprint_parity `
        -and [int]$manifest.registry_commit_count -eq 0 `
        -and [int]$manifest.registry_rebind_count -eq 0 `
        -and [int]$manifest.partial_restore_state_count -eq 0) "official_attempt_2_rehearsal_manifest_invalid"
    foreach ($field in $DuplicateCountFields) {
        Assert-ColdRestoreCondition ([int]$manifest.$field -eq 0) "official_attempt_2_rehearsal_duplicate_count_invalid"
    }
    $timeline = Read-ColdRestoreJsonArtifact $timelinePath
    $timelineValidation = cold_restore_attested_process\Test-ColdRestoreProcessAPhaseTimeline `
        -Value $timeline `
        -ExpectedRunId $rehearsalRunId `
        -ExpectedRepositoryHead $HeadSha `
        -ExpectedScenarioFingerprint $ExpectedScenarioFingerprint
    Assert-ColdRestoreCondition ([bool]$timelineValidation.valid `
        -and @($timeline.phase_rows).Count -eq 19 `
        -and [string]$timeline.last_completed_phase -ceq "quit_requested" `
        -and [bool]$timeline.save_file_exists `
        -and [bool]$timeline.allowlisted_manifest_written `
        -and [bool]$timeline.child_completion_written `
        -and [bool]$timeline.quit_requested) "official_attempt_2_rehearsal_timeline_invalid"
    $completion = Read-ColdRestoreJsonArtifact $completionPath
    $completionSha256 = (Get-FileHash -LiteralPath $completionPath -Algorithm SHA256).Hash.ToLowerInvariant()
    Assert-ColdRestoreCondition ($completionSha256 -ceq [string]$outcome.completion_sha256) "official_attempt_2_rehearsal_completion_sha256_mismatch"
    Assert-ColdRestoreProcessARehearsalCompletion $completion $HeadSha ([string]$admission.fingerprint)
    $childSha256 = (Get-FileHash -LiteralPath $childPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $parentSha256 = (Get-FileHash -LiteralPath $parentPath -Algorithm SHA256).Hash.ToLowerInvariant()
    Assert-ColdRestoreCondition ($childSha256 -ceq [string]$outcome.child_attestation_sha256 `
        -and $parentSha256 -ceq [string]$outcome.parent_attestation_sha256) "official_attempt_2_rehearsal_exit_sha256_mismatch"
    $childValidation = cold_restore_attested_process\Test-ColdRestoreChildCompletionAttestation `
        -Path $childPath `
        -ExpectedRunId $rehearsalRunId `
        -ExpectedRole "producer" `
        -ExpectedRepositoryHead $HeadSha `
        -ProcessStartedAtUtc ([IO.File]::GetLastWriteTimeUtc($childPath).AddMinutes(-10)) `
        -ExpectedScenarioFingerprint $ExpectedScenarioFingerprint
    $parent = Read-ColdRestoreJsonArtifact $parentPath
    Assert-ColdRestoreCondition ([bool]$childValidation.valid `
        -and [bool]$parent.observed_exit `
        -and [int]$parent.exit_code -eq 0 `
        -and -not [bool]$parent.timed_out `
        -and -not [bool]$parent.terminated_by_parent `
        -and [bool]$parent.child_attestation_valid `
        -and [string]$parent.child_attestation_fingerprint -ceq [string]$childValidation.fingerprint `
        -and [int]$parent.task_owned_process_count_after -eq 0 `
        -and [bool]$parent.wrapper_exit_green `
        -and [string]$parent.wrapper_reason_code -ceq "ok" `
        -and [string]$parent.policy_role -ceq "process_a" `
        -and [string]$parent.timeout_policy_fingerprint -ceq [string]$RoleTimeoutPolicyEvidence.sha256 `
        -and [int]$parent.absolute_timeout_seconds -eq 180 `
        -and [int]$parent.no_progress_timeout_seconds -eq 60) "official_attempt_2_rehearsal_exit_invalid"
    Assert-ColdRestoreCondition ([string]$parent.stdout_sha256 -ceq [string]$outcome.stdout_sha256 `
        -and [string]$parent.stderr_sha256 -ceq [string]$outcome.stderr_sha256) "official_attempt_2_rehearsal_stream_sha256_mismatch"
    $expectedRoleTimeouts = @{
        process_a = @(180, 60)
        process_b = @(360, 60)
        process_c = @(180, 30)
    }
    foreach ($roleId in @("process_a", "process_b", "process_c")) {
        $rolePolicy = $RoleTimeoutPolicyEvidence.policy.roles.$roleId
        Assert-ColdRestoreCondition (-not [bool]$rolePolicy.contract_only_in_this_task `
            -and [int]$rolePolicy.absolute_timeout_seconds -eq [int]$expectedRoleTimeouts[$roleId][0] `
            -and [int]$rolePolicy.no_progress_timeout_seconds -eq [int]$expectedRoleTimeouts[$roleId][1]) "official_attempt_2_role_timeout_not_executable"
    }
    $preClaimPrerequisites = Assert-ColdRestoreProcessARehearsalPrerequisites $ResolvedProjectPath $HeadSha
    Assert-ColdRestoreCondition ([string]$preClaimPrerequisites.evidence_fingerprint `
        -ceq [string]$stage3Prerequisites.evidence_fingerprint `
        -and [string]$preClaimPrerequisites.evidence_fingerprint `
        -ceq [string]$admission.value.prerequisite_evidence_fingerprint) "official_attempt_2_preclaim_prerequisite_changed"
    $preClaimFreeze = Get-ColdRestoreRuntimeFreezeObservation $ResolvedProjectPath $HeadSha
    $null = Assert-ColdRestoreRuntimeFreezeGreen `
        $preClaimFreeze "official_attempt_2_preclaim_runtime_not_frozen"
    Assert-ColdRestoreCondition ([string]$preClaimFreeze.evidence_fingerprint `
        -ceq [string]$outcome.rehearsal_green_freeze_fingerprint) "official_attempt_2_rehearsal_runtime_freeze_changed"
    $ledgerPath = $candidateClaimPath
    $orchestratorCreationTimeTicks = Get-ColdRestoreOrchestratorCreationTimeTicks
    $orchestratorScriptSha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $claimNonce = [Guid]::NewGuid().ToString("N")
    $ledger = [ordered]@{
        schema_version = 2
        claim_id = "OfficialAttemptClaimV2"
        attempt_number = 2
        authorization_id = $OfficialAuthorizationId
        created_at_utc = [DateTime]::UtcNow.ToString("O", [Globalization.CultureInfo]::InvariantCulture)
        run_id = $RunId
        source_head = $HeadSha
        rehearsal_green_head = $HeadSha
        scenario_fingerprint = $ExpectedScenarioFingerprint
        challenge_depth = 1
        seed = [int64]900626424
        local_player_count = 1
        ai_player_count = 3
        timeout_policy_sha256 = [string]$RoleTimeoutPolicyEvidence.sha256
        prerequisite_evidence_fingerprint = [string]$preClaimPrerequisites.evidence_fingerprint
        preclaim_runtime_freeze_fingerprint = [string]$preClaimFreeze.evidence_fingerprint
        process_role_timeouts = [pscustomobject][ordered]@{
            process_a = [pscustomobject][ordered]@{ absolute_timeout_seconds = 180; no_progress_timeout_seconds = 60 }
            process_b = [pscustomobject][ordered]@{ absolute_timeout_seconds = 360; no_progress_timeout_seconds = 60 }
            process_c = [pscustomobject][ordered]@{ absolute_timeout_seconds = 180; no_progress_timeout_seconds = 30 }
        }
        rehearsal_run_id = $rehearsalRunId
        rehearsal_evidence_fingerprint = [string]$outcome.evidence_fingerprint
        rehearsal_outcome_sha256 = $outcomeSha256
        rehearsal_admission_sha256 = [string]$admission.fingerprint
        rehearsal_launch_sha256 = [string]$launchLedger.fingerprint
        rehearsal_completion_sha256 = $completionSha256
        rehearsal_child_attestation_sha256 = $childSha256
        rehearsal_parent_attestation_sha256 = $parentSha256
        attempt_1_claim_relative_path = "official-alpha04c-depth1-seed900626424/official_claim_ledger.json"
        attempt_1_claim_sha256 = [string]$officialBoundary.attempt_1_sha256
        orchestrator_id = "alpha04c_cold_restore_vertical_slice_orchestrator_v4"
        orchestrator_schema_version = $ORCHESTRATOR_SCHEMA_VERSION
        orchestrator_script_sha256 = $orchestratorScriptSha256
        orchestrator_process_id = $PID
        orchestrator_creation_time_utc_ticks = $orchestratorCreationTimeTicks
        claim_nonce = $claimNonce
        status = "consumed"
        authorized_official_count = 1
        official_count_before = 1
        official_count_after = 2
    }
    cold_restore_official_attempt2_contract\Assert-ColdRestoreOfficialAttempt2Claim ([pscustomobject]$ledger)
    if ($PreflightOnly) {
        $null = Assert-ColdRestoreOfficialAttemptBoundary $ResolvedProjectPath
        $sideEffectSnapshotAfter = cold_restore_official_attempt2_contract\Get-ColdRestoreOfficialAttempt2SideEffectSnapshot `
            -OfficialClaimRoot $officialClaimRoot `
            -Attempt1ClaimPath $attempt1ClaimPath `
            -CandidateClaimPath $candidateClaimPath `
            -CandidateEvidenceRoot $candidateEvidenceRoot `
            -CandidateUserDataRoot $candidateUserDataRoot
        $null = cold_restore_official_attempt2_contract\Assert-ColdRestoreOfficialAttempt2SideEffectSnapshotUnchanged `
            $sideEffectSnapshotBefore $sideEffectSnapshotAfter
        return [pscustomobject]@{
            ledger_path = $ledgerPath
            authorization_id = $OfficialAuthorizationId
            claim_fingerprint = ""
            claim_nonce = $claimNonce
            orchestrator_process_id = $PID
            orchestrator_creation_time_utc_ticks = $orchestratorCreationTimeTicks
            scenario_fingerprint = $ExpectedScenarioFingerprint
            rehearsal_outcome = $outcome
            candidate = [pscustomobject]$ledger
            claim_ready = $true
            claim_created = $false
            candidate_evidence_root_absent = -not [IO.Directory]::Exists($candidateEvidenceRoot)
            candidate_user_data_root_absent = -not [IO.Directory]::Exists($candidateUserDataRoot)
            candidate_claim_root_absent = -not [IO.Directory]::Exists((Split-Path -Parent $candidateClaimPath))
            side_effect_snapshot_match = $true
            claim_inventory_count_before = [int]$sideEffectSnapshotBefore.claim_inventory_count
            claim_inventory_count_after = [int]$sideEffectSnapshotAfter.claim_inventory_count
            claim_inventory_fingerprint_before = [string]$sideEffectSnapshotBefore.claim_inventory_fingerprint
            claim_inventory_fingerprint_after = [string]$sideEffectSnapshotAfter.claim_inventory_fingerprint
            godot_pid_count_before = [int]$sideEffectSnapshotBefore.godot_process_count
            godot_pid_count_after = [int]$sideEffectSnapshotAfter.godot_process_count
            godot_pid_fingerprint_before = [string]$sideEffectSnapshotBefore.godot_process_identity_fingerprint
            godot_pid_fingerprint_after = [string]$sideEffectSnapshotAfter.godot_process_identity_fingerprint
        }
    }
    Assert-ColdRestoreCondition (-not [IO.Directory]::Exists((Split-Path -Parent $candidateClaimPath)) `
        -and -not [IO.File]::Exists($candidateClaimPath) `
        -and -not [IO.Directory]::Exists($candidateEvidenceRoot) `
        -and -not [IO.Directory]::Exists($candidateUserDataRoot)) "official_attempt_2_candidate_root_collision"
    try {
        $claimFingerprint = cold_restore_official_attempt2_contract\Publish-ColdRestoreOfficialAttempt2Claim $ledgerPath ([pscustomobject]$ledger)
        $script:OfficialAttempt2Progress.claim_created = $true
    }
    catch {
        if ([IO.File]::Exists($ledgerPath)) {
            $script:OfficialAttempt2Progress.claim_created = $true
        }
        throw
    }
    $null = Assert-ColdRestoreOfficialAttempt2Boundary $ResolvedProjectPath $claimFingerprint
    return [pscustomobject]@{
        ledger_path = $ledgerPath
        authorization_id = $OfficialAuthorizationId
        claim_fingerprint = [string]$claimFingerprint
        claim_nonce = $claimNonce
        orchestrator_process_id = $PID
        orchestrator_creation_time_utc_ticks = $orchestratorCreationTimeTicks
        scenario_fingerprint = $ExpectedScenarioFingerprint
        prerequisite_evidence_fingerprint = [string]$preClaimPrerequisites.evidence_fingerprint
        preclaim_runtime_freeze_fingerprint = [string]$preClaimFreeze.evidence_fingerprint
        rehearsal_outcome = $outcome
    }
}

function New-ColdRestoreOfficialAttempt2PreflightOutput {
    param([Parameter(Mandatory = $true)]$Admission)

    return [ordered]@{
        schema_version = 1
        driver_id = "alpha04c_official_attempt_2_preflight_v1"
        formal_full_run = $false
        official_cold_restore_vertical_slice = $false
        preflight_only = $true
        run_id = $RunId
        repository_head = [string]$Admission.candidate.source_head
        scenario_fingerprint = [string]$Admission.scenario_fingerprint
        timeout_policy_sha256 = [string]$Admission.candidate.timeout_policy_sha256
        rehearsal_run_id = [string]$Admission.candidate.rehearsal_run_id
        rehearsal_evidence_fingerprint = [string]$Admission.candidate.rehearsal_evidence_fingerprint
        official_attempt_1_claim_sha256 = [string]$Admission.candidate.attempt_1_claim_sha256
        official_attempt_2_claim_ready = [bool]$Admission.claim_ready
        official_attempt_2_claim_created = [bool]$Admission.claim_created
        official_authorization_consumed = $false
        godot_launch_attempted = $false
        evidence_root_created = $false
        user_data_root_created = $false
        candidate_evidence_root_absent = [bool]$Admission.candidate_evidence_root_absent
        candidate_user_data_root_absent = [bool]$Admission.candidate_user_data_root_absent
        candidate_claim_root_absent = [bool]$Admission.candidate_claim_root_absent
        side_effect_snapshot_match = [bool]$Admission.side_effect_snapshot_match
        claim_inventory_count_before = [int]$Admission.claim_inventory_count_before
        claim_inventory_count_after = [int]$Admission.claim_inventory_count_after
        claim_inventory_fingerprint_before = [string]$Admission.claim_inventory_fingerprint_before
        claim_inventory_fingerprint_after = [string]$Admission.claim_inventory_fingerprint_after
        godot_pid_count_before = [int]$Admission.godot_pid_count_before
        godot_pid_count_after = [int]$Admission.godot_pid_count_after
        godot_pid_fingerprint_before = [string]$Admission.godot_pid_fingerprint_before
        godot_pid_fingerprint_after = [string]$Admission.godot_pid_fingerprint_after
        success = [bool]$Admission.claim_ready -and -not [bool]$Admission.claim_created
        failure_code = ""
    }
}

function Get-ColdRestoreTopLevelImportRuntimeAudit {
    $moduleInfos = @(
        $ColdRestoreModuleLoader,
        $ColdRestoreAuthorizationModule,
        $ColdRestorePreQuotaModule,
        $ProcessARehearsalAdmissionModule,
        $ColdRestoreAttestedProcessModule,
        $ColdRestoreOfficialAttempt2Module
    )
    $exportOwner = @{}
    $fileOwner = @{
        ([IO.Path]::GetFullPath($PSCommandPath)) = ""
    }
    foreach ($moduleInfo in $moduleInfos) {
        $resolvedModulePath = [IO.Path]::GetFullPath([string]$moduleInfo.Path)
        $fileOwner[$resolvedModulePath] = [string]$moduleInfo.Name
        foreach ($commandName in @($moduleInfo.ExportedCommands.Keys)) {
            $exportOwner[[string]$commandName] = [string]$moduleInfo.Name
        }
    }

    $forceCount = 0
    $localForceCount = 0
    $ambientDependencyCount = 0
    $parseErrorCount = 0
    foreach ($path in @($fileOwner.Keys | Sort-Object)) {
        $tokens = $null
        $parseErrors = $null
        $ast = [Management.Automation.Language.Parser]::ParseFile(
            $path,
            [ref]$tokens,
            [ref]$parseErrors
        )
        $parseErrorCount += @($parseErrors).Count
        $localFunctions = @(
            $ast.FindAll({
                param($node)
                $node -is [Management.Automation.Language.FunctionDefinitionAst]
            }, $true) | ForEach-Object { [string]$_.Name }
        )
        foreach ($commandAst in @($ast.FindAll({
                    param($node)
                    $node -is [Management.Automation.Language.CommandAst]
                }, $true))) {
            $commandName = [string]$commandAst.GetCommandName()
            if ($commandName -ceq "Import-Module") {
                $parameterNames = @(
                    $commandAst.CommandElements | Where-Object {
                        $_ -is [Management.Automation.Language.CommandParameterAst]
                    } | ForEach-Object { [string]$_.ParameterName }
                )
                if ($parameterNames -ccontains "Force") {
                    $forceCount += 1
                    if ($parameterNames -ccontains "Scope" `
                        -and [string]$commandAst.Extent.Text -cmatch '(?i)-Scope\s+Local') {
                        $localForceCount += 1
                    }
                }
            }
            if (-not [string]::IsNullOrEmpty($commandName) `
                -and -not $commandName.Contains("\") `
                -and $localFunctions -cnotcontains $commandName `
                -and $exportOwner.ContainsKey($commandName) `
                -and [string]$exportOwner[$commandName] -cne [string]$fileOwner[$path]) {
                $ambientDependencyCount += 1
            }
        }
    }
    return [pscustomobject][ordered]@{
        audited_file_count = $fileOwner.Count
        parse_error_count = $parseErrorCount
        runtime_import_force_count = $forceCount
        runtime_local_force_import_count = $localForceCount
        ambient_script_scope_command_dependency_count = $ambientDependencyCount
    }
}

function New-ColdRestoreTopLevelImportChainPreflightAttestation {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedProjectPath,
        [Parameter(Mandatory = $true)][string]$HeadSha
    )

    $gitCommonDirectory = Resolve-ColdRestoreGitCommonDirectory $ResolvedProjectPath
    $binding = cold_restore_authorization_contract_v1\Get-ColdRestoreTargetedDiagnosticAuthorizationBinding `
        -GitCommonDirectory $gitCommonDirectory `
        -RepositoryHead $HeadSha `
        -AuthorizationName $TargetedOwnerCaptureAuthorizationName
    Assert-ColdRestoreCondition ($RunId -ceq [string]$binding.run_id) `
        "top_level_preflight_run_id_invalid"
    $branchLines = @(& git -C $ResolvedProjectPath branch --show-current 2>$null)
    Assert-ColdRestoreCondition ($LASTEXITCODE -eq 0 `
        -and (cold_restore_attested_process\Get-ColdRestoreSafeCollectionCount $branchLines) -le 1) `
        "top_level_preflight_branch_unavailable"
    $branch = if ((cold_restore_attested_process\Get-ColdRestoreSafeCollectionCount $branchLines) -eq 1) {
        [string]$branchLines[0]
    }
    else {
        ""
    }

    $runtimeAudit = Get-ColdRestoreTopLevelImportRuntimeAudit
    Assert-ColdRestoreCondition ([int]$runtimeAudit.parse_error_count -eq 0 `
        -and [int]$runtimeAudit.runtime_import_force_count -eq 0 `
        -and [int]$runtimeAudit.runtime_local_force_import_count -eq 0 `
        -and [int]$runtimeAudit.ambient_script_scope_command_dependency_count -eq 0) `
        "top_level_preflight_import_audit_failed"

    $runtimeFreeze = Get-ColdRestoreRuntimeFreezeObservation $ResolvedProjectPath $HeadSha
    Assert-ColdRestoreCondition ([bool]$runtimeFreeze.head_query_green `
        -and [bool]$runtimeFreeze.head_matches `
        -and [bool]$runtimeFreeze.status_query_green `
        -and [bool]$runtimeFreeze.git_diff_check_green) `
        "top_level_preflight_runtime_observation_failed"

    $null = cold_restore_prequota_bootstrap\Assert-ColdRestorePreQuotaContextParameters `
        -GitCommonDirectory $gitCommonDirectory `
        -BootstrapRoot ([string]$binding.bootstrap_root) `
        -RunId ([string]$binding.run_id) `
        -RepositoryHead $HeadSha `
        -Branch $branch `
        -AuthorizationId ([string]$binding.authorization_id) `
        -QuotaLedgerPath ([string]$binding.quota_ledger_path)

    $policy = Read-ColdRestoreRoleTimeoutPolicy $RoleTimeoutPolicyPath
    $preflightFingerprint = cold_restore_attested_process\Get-ColdRestoreEvidenceFingerprint `
        ([pscustomobject][ordered]@{
            attestation_id = "TopLevelImportChainPreflightAttestationV1"
            run_id = $RunId
            repository_head = $HeadSha
            authorization_id = [string]$binding.authorization_id
        })
    $launchNonce = $preflightFingerprint.Substring(0, 32)
    $launchAttestationPath = Join-Path ([string]$binding.evidence_root) `
        "preflight-only\producer.authorized.json"
    $userArguments = cold_restore_prequota_bootstrap\New-ColdRestoreTargetedDiagnosticUserArgumentList `
        -GitCommonDirectory $gitCommonDirectory `
        -RepositoryHead $HeadSha `
        -RunId $RunId `
        -ArtifactRoot "user://test_runs/alpha04c/$RunId/evidence" `
        -ScenarioFingerprint $TargetedOwnerCaptureScenarioFingerprint `
        -TimeoutPolicyFingerprint ([string]$policy.sha256) `
        -QuotaLedgerPath ([string]$binding.quota_ledger_path) `
        -QuotaLedgerFingerprint $preflightFingerprint `
        -LaunchAttestationPath $launchAttestationPath `
        -LaunchNonce $launchNonce `
        -AuthorizationName $TargetedOwnerCaptureAuthorizationName
    $commandArguments = cold_restore_attested_process\New-ColdRestoreGodotArgumentList `
        -EngineArgumentList @(
            "--headless", "--path", $ResolvedProjectPath, "--script", $DriverScript
        ) `
        -UserArgumentList $userArguments

    $commandRows = @(
        foreach ($moduleInfo in @(
                $ColdRestoreModuleLoader,
                $ColdRestoreAuthorizationModule,
                $ColdRestorePreQuotaModule,
                $ProcessARehearsalAdmissionModule,
                $ColdRestoreAttestedProcessModule,
                $ColdRestoreOfficialAttempt2Module
            )) {
            foreach ($commandName in @($moduleInfo.ExportedCommands.Keys | Sort-Object)) {
                [ordered]@{
                    module_name = [string]$moduleInfo.Name
                    module_path = [IO.Path]::GetFullPath([string]$moduleInfo.Path)
                    command_name = [string]$commandName
                }
            }
        }
    )
    $commandSetFingerprint = cold_restore_attested_process\Get-ColdRestoreEvidenceFingerprint `
        ([pscustomobject][ordered]@{ command_rows = $commandRows })
    $commandArgumentFingerprint = cold_restore_attested_process\Get-ColdRestoreEvidenceFingerprint `
        ([pscustomobject][ordered]@{ arguments = @($commandArguments) })

    $quotaExistsBefore = [IO.File]::Exists([string]$binding.quota_ledger_path)
    $evidenceRootExistsBefore = [IO.Directory]::Exists([string]$binding.evidence_root)
    $bootstrapRootExistsBefore = [IO.Directory]::Exists([string]$binding.bootstrap_root)
    $attestation = [ordered]@{
        schema_version = 1
        attestation_id = "TopLevelImportChainPreflightAttestationV1"
        run_id = $RunId
        repository_head = $HeadSha
        authorization_name = $TargetedOwnerCaptureAuthorizationName
        authorization_id = [string]$binding.authorization_id
        import_order = @(
            "module_loader", "authorization_contract", "prequota_bootstrap",
            "admission_contract", "attested_process_reuse", "official_attempt2_contract",
            "runtime_freeze_observation", "evidence_fingerprint", "prequota_context",
            "command_argument_construction"
        )
        runtime_import_force_count = [int]$runtimeAudit.runtime_import_force_count
        runtime_local_force_import_count = [int]$runtimeAudit.runtime_local_force_import_count
        ambient_script_scope_command_dependency_count = `
            [int]$runtimeAudit.ambient_script_scope_command_dependency_count
        evidence_fingerprint_command_present_before_admission = `
            [bool]$TopLevelImportChainState.evidence_fingerprint_command_present_before_admission
        evidence_fingerprint_command_present_after_admission = `
            [bool]$TopLevelImportChainState.evidence_fingerprint_command_present_after_admission
        attested_process_module_identity_stable = `
            [bool]$TopLevelImportChainState.attested_process_module_identity_stable
        attested_process_module_name = [string]$TopLevelImportChainState.attested_process_module_name
        attested_process_module_path = [string]$TopLevelImportChainState.attested_process_module_path
        attested_process_module_sha256 = [string]$TopLevelImportChainState.attested_process_module_sha256
        evidence_fingerprint_result_parity = `
            [bool]$TopLevelImportChainState.evidence_fingerprint_result_parity
        evidence_fingerprint_probe_result = [string]$TopLevelImportChainState.fingerprint_probe_result
        command_set_fingerprint = $commandSetFingerprint
        command_argument_fingerprint = $commandArgumentFingerprint
        command_argument_count = @($commandArguments).Count
        runtime_freeze_observation_fingerprint = [string]$runtimeFreeze.evidence_fingerprint
        runtime_freeze_tree_clean = [bool]$runtimeFreeze.tree_clean
        prequota_context_parameters_valid = $true
        quota_ledger_exists_before = $quotaExistsBefore
        quota_ledger_exists_after = [IO.File]::Exists([string]$binding.quota_ledger_path)
        evidence_root_exists_before = $evidenceRootExistsBefore
        evidence_root_exists_after = [IO.Directory]::Exists([string]$binding.evidence_root)
        bootstrap_root_exists_before = $bootstrapRootExistsBefore
        bootstrap_root_exists_after = [IO.Directory]::Exists([string]$binding.bootstrap_root)
        quota_claim_count = 0
        diagnostic_count_delta = 0
        godot_launch_count = 0
        save_write_count = 0
        official = $false
        formal = $false
        official_authorization_consumed = $false
        normal_exit_requested = $true
        evidence_fingerprint = ""
        success = $true
        failure_code = ""
    }
    Assert-ColdRestoreCondition ([bool]$attestation.quota_ledger_exists_before `
            -eq [bool]$attestation.quota_ledger_exists_after `
        -and [bool]$attestation.evidence_root_exists_before `
            -eq [bool]$attestation.evidence_root_exists_after `
        -and [bool]$attestation.bootstrap_root_exists_before `
            -eq [bool]$attestation.bootstrap_root_exists_after) `
        "top_level_preflight_side_effect_detected"
    $attestation.evidence_fingerprint = `
        cold_restore_attested_process\Get-ColdRestoreEvidenceFingerprint `
            ([pscustomobject]$attestation) "evidence_fingerprint"
    return [pscustomobject]$attestation
}

function New-AllowlistedResult {
    param(
        [Parameter(Mandatory = $true)][bool]$Executed,
        [Parameter(Mandatory = $true)][bool]$ContractFixture,
        [Parameter(Mandatory = $true)][bool]$Success,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$FailureCode,
        $Comparison = $null
    )
    $compared = $null -ne $Comparison
    $safeRunId = if ($RunId -match '^[A-Za-z0-9][A-Za-z0-9._-]{0,95}$') { $RunId } else { "" }
    return [ordered]@{
        schema_version = $ORCHESTRATOR_SCHEMA_VERSION
        driver_id = "alpha04c_cold_restore_vertical_slice_orchestrator_v4"
        formal_full_run = $FORMAL_FULL_RUN
        execution_ready = $DriverExecutionReady
        executed = $Executed
        contract_fixture = $ContractFixture
        run_id = $safeRunId
        process_sequence = $ProcessSequence
        comparison_scope = "qa_allowlisted_manifests_only"
        process_ids_distinct = $compared -and [bool]$Comparison.process_ids_distinct
        head_sha_match = $compared -and [bool]$Comparison.head_sha_match
        generation1_digest_match = $compared -and [bool]$Comparison.generation1_digest_match
        generation2_digest_match = $compared -and [bool]$Comparison.generation2_digest_match
        write_chain_match = $compared -and [bool]$Comparison.write_chain_match
        queue_target_identity_match = $compared -and [bool]$Comparison.queue_target_identity_match
        pending_queue_exact_once = $compared -and [bool]$Comparison.pending_queue_exact_once
        section_counts_exact = $compared -and [bool]$Comparison.section_counts_exact
        save_capture_deltas_zero = $compared -and [bool]$Comparison.save_capture_deltas_zero
        restore_deltas_zero = $compared -and [bool]$Comparison.restore_deltas_zero
        action_counts_positive = $compared -and [bool]$Comparison.action_counts_positive
        generation2_counts_exact = $compared -and [bool]$Comparison.generation2_counts_exact
        registry_commit_rebind_exact = $compared -and [bool]$Comparison.registry_commit_rebind_exact
        save_readback_exact = $compared -and [bool]$Comparison.save_readback_exact
        duplicate_counts_zero = $compared -and [bool]$Comparison.duplicate_counts_zero
        typed_restore_fingerprints_match = $compared -and [bool]$Comparison.typed_restore_fingerprints_match
        generation_two_restore_exact = $compared -and [bool]$Comparison.generation_two_restore_exact
        final_settlement_exact_once = $compared -and [bool]$Comparison.final_settlement_exact_once
        terminal_quiescent_frames = if ($compared) { [int]$Comparison.terminal_quiescent_frames } else { 0 }
        terminal_quiet = $compared -and [bool]$Comparison.terminal_quiet
        success = $Success
        failure_code = $FailureCode
    }
}

function Get-ColdRestoreOfficialAttempt2RoleStatus {
    param(
        [Parameter(Mandatory = $true)][bool]$Started,
        [Parameter(Mandatory = $true)][bool]$Completed
    )
    if ($Completed) { return "GREEN" }
    if ($Started) { return "FAILED" }
    return "NOT_RUN"
}

function Get-ColdRestoreOfficialAttempt2FailureClass {
    param([Parameter(Mandatory = $true)][string]$FailureCode)

    $progress = $script:OfficialAttempt2Progress
    if (-not [bool]$progress.claim_created -or -not [bool]$progress.process_a_started) {
        return "ENVIRONMENT_FAILURE"
    }
    if (-not [bool]$progress.process_a_completed) {
        if ($FailureCode -match 'timeout|wrapper') { return "WRAPPER_FAILURE" }
        if ($FailureCode -match 'attestation|exit|process_tree|child_process') { return "PROCESS_A_EXIT_ATTESTATION_FAILED" }
        if ($FailureCode -match 'commodity|normal_card|facility_economy|queue_entry|product_setup|qualification') {
            return "PROCESS_A_PRODUCT_SETUP_FAILED"
        }
        return "PROCESS_A_SAVE_FAILED"
    }
    if (-not [bool]$progress.process_b_completed) {
        if ($FailureCode -match 'attestation|exit|process_tree|timeout|wrapper') { return "PROCESS_B_EXIT_ATTESTATION_FAILED" }
        if ($FailureCode -match 'restore|recapture|fingerprint|preflight|apply|commit|rebind|readback|(^|_)read(_|$)|generation1|source_envelope|envelope') { return "PROCESS_B_RESTORE_FAILED" }
        if ($FailureCode -match 'queue|target|facility|resolution') { return "PROCESS_B_QUEUE_CONTINUATION_FAILED" }
        if ($FailureCode -match 'settlement|terminal|victory|quiescent') { return "PROCESS_B_SETTLEMENT_FAILED" }
        if ($FailureCode -match 'sale|econom') { return "PROCESS_B_ECONOMY_CONTINUATION_FAILED" }
        return "PROCESS_B_POST_RESTORE_ACTION_FAILED"
    }
    if (-not [bool]$progress.process_c_completed) {
        if ($FailureCode -match 'attestation|exit|process_tree|timeout|wrapper') { return "PROCESS_C_EXIT_ATTESTATION_FAILED" }
        return "PROCESS_C_GENERATION2_FAILED"
    }
    return "UNKNOWN"
}

function New-ColdRestoreOfficialAttempt2FailureResult {
    param([Parameter(Mandatory = $true)][string]$FailureCode)

    $result = New-AllowlistedResult ([bool]$script:OfficialAttempt2Progress.claim_created) $false $false $FailureCode
    foreach ($field in @(
        "process_ids_distinct", "head_sha_match", "generation1_digest_match",
        "generation2_digest_match", "write_chain_match", "queue_target_identity_match",
        "pending_queue_exact_once", "section_counts_exact", "save_capture_deltas_zero",
        "restore_deltas_zero", "action_counts_positive", "generation2_counts_exact",
        "registry_commit_rebind_exact", "save_readback_exact", "duplicate_counts_zero",
        "typed_restore_fingerprints_match", "generation_two_restore_exact",
        "final_settlement_exact_once", "terminal_quiescent_frames", "terminal_quiet"
    )) {
        $result[$field] = "NOT_RUN"
    }
    $result["official_attempt_2_claim_created"] = [bool]$script:OfficialAttempt2Progress.claim_created
    $result["official_authorization_consumed"] = [bool]$script:OfficialAttempt2Progress.claim_created
    $result["official_attempt_2_failure_class"] = Get-ColdRestoreOfficialAttempt2FailureClass $FailureCode
    $result["process_a_status"] = Get-ColdRestoreOfficialAttempt2RoleStatus `
        ([bool]$script:OfficialAttempt2Progress.process_a_started) `
        ([bool]$script:OfficialAttempt2Progress.process_a_completed)
    $result["process_b_status"] = Get-ColdRestoreOfficialAttempt2RoleStatus `
        ([bool]$script:OfficialAttempt2Progress.process_b_started) `
        ([bool]$script:OfficialAttempt2Progress.process_b_completed)
    $result["process_c_status"] = Get-ColdRestoreOfficialAttempt2RoleStatus `
        ([bool]$script:OfficialAttempt2Progress.process_c_started) `
        ([bool]$script:OfficialAttempt2Progress.process_c_completed)
    $result["comparison_status"] = Get-ColdRestoreOfficialAttempt2RoleStatus `
        ([bool]$script:OfficialAttempt2Progress.comparison_started) `
        ([bool]$script:OfficialAttempt2Progress.comparison_completed)
    return $result
}

function New-ColdRestoreOfficialAttempt2SuccessResult {
    param([Parameter(Mandatory = $true)]$Comparison)

    $result = New-AllowlistedResult $true $false $true "" $Comparison
    $result["official_attempt_2_claim_created"] = $true
    $result["official_authorization_consumed"] = $true
    $result["official_attempt_2_failure_class"] = ""
    $result["process_a_status"] = "GREEN"
    $result["process_b_status"] = "GREEN"
    $result["process_c_status"] = "GREEN"
    $result["comparison_status"] = "GREEN"
    return $result
}

function Write-AllowlistedResult {
    param([Parameter(Mandatory = $true)]$Result)
    Write-Output ($Result | ConvertTo-Json -Compress -Depth 4)
}

try {
    Assert-ColdRestoreCondition ($RunId -match '^[A-Za-z0-9][A-Za-z0-9._-]{0,95}$') "run_id_invalid"
    $selectedModeCount = @(
        [bool]$QualificationProbe,
        [bool]$TargetedOwnerCaptureDiagnostic,
        [bool]$NonOfficialProcessA,
        [bool]$TopLevelImportChainPreflightOnly,
        [bool]$OfficialAttempt2PreflightOnly,
        [bool]$EnableColdRestoreExecution,
        ($ContractManifestPath -ne "")
    ).Where({ $_ }).Count
    Assert-ColdRestoreCondition ($selectedModeCount -le 1) "execution_mode_conflict"

    if ($ContractManifestPath -ne "") {
        $fixture = Read-ContractManifestFixture $ContractManifestPath
        $comparison = Compare-ColdRestoreManifests $fixture.producer $fixture.consumer $fixture.validator
        Write-AllowlistedResult (New-AllowlistedResult $false $true $true "" $comparison)
        exit 0
    }

    if (-not $QualificationProbe -and -not $TargetedOwnerCaptureDiagnostic `
        -and -not $NonOfficialProcessA -and -not $TopLevelImportChainPreflightOnly `
        -and -not $OfficialAttempt2PreflightOnly `
        -and -not $EnableColdRestoreExecution) {
        Write-AllowlistedResult (New-AllowlistedResult $false $false $true "")
        exit 0
    }

    Assert-ColdRestoreCondition $DriverExecutionReady "driver_execution_not_ready"
    $resolvedProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path
    Assert-ColdRestoreCondition (Test-Path -LiteralPath (Join-Path $resolvedProjectPath "project.godot") -PathType Leaf) "godot_project_invalid"
    if (-not $TargetedOwnerCaptureDiagnostic `
        -and -not $TopLevelImportChainPreflightOnly `
        -and -not $OfficialAttempt2PreflightOnly) {
        $GodotPath = Resolve-ColdRestoreGodotExecutable $GodotPath
    }
    $headSha = [string](& git -C $resolvedProjectPath rev-parse HEAD 2>$null)
    Assert-ColdRestoreCondition ($headSha -match '^[0-9a-f]{40,64}$') "head_sha_unavailable"
    if (-not $TargetedOwnerCaptureDiagnostic -and -not $TopLevelImportChainPreflightOnly) {
        $dirtyPaths = @(& git -C $resolvedProjectPath status --porcelain=v1 2>$null)
        Assert-ColdRestoreCondition ((cold_restore_attested_process\Get-ColdRestoreSafeCollectionCount $dirtyPaths) -eq 0) "worktree_not_clean"
    }
    $resolvedPolicyPath = if ([string]::IsNullOrWhiteSpace($RoleTimeoutPolicyPath)) {
        $DefaultRoleTimeoutPolicyPath
    }
    else {
        $RoleTimeoutPolicyPath
    }
    $RoleTimeoutPolicyPath = $resolvedPolicyPath
    if (-not $TargetedOwnerCaptureDiagnostic) {
        $RoleTimeoutPolicyEvidence = Read-ColdRestoreRoleTimeoutPolicy $resolvedPolicyPath
    }
    if ($NonOfficialProcessA) {
        $rehearsalEvidenceRoot = Join-Path $resolvedProjectPath ".godot\cold_restore_attestation_v1\$RunId"
        Assert-ColdRestoreCondition (-not (Test-Path -LiteralPath $UserDataRoot) `
            -and -not (Test-Path -LiteralPath $rehearsalEvidenceRoot)) "process_a_rehearsal_evidence_collision"
    }
    if ($QualificationProbe) {
        New-Item -ItemType Directory -Path $IsolatedAppData -Force | Out-Null
        New-Item -ItemType Directory -Path $IsolatedLocalAppData -Force | Out-Null
        $qualification = Invoke-ColdRestoreQualification $resolvedProjectPath $headSha
        Write-AllowlistedResult (New-ColdRestoreQualificationOutput $qualification.run $qualification.result)
        exit 0
    }

    if ($TopLevelImportChainPreflightOnly) {
        Assert-ColdRestoreCondition (-not $QualificationProbe `
            -and -not $TargetedOwnerCaptureDiagnostic `
            -and -not $NonOfficialProcessA `
            -and -not $OfficialAttempt2PreflightOnly `
            -and -not $EnableColdRestoreExecution `
            -and [string]::IsNullOrEmpty($ContractManifestPath)) `
            "top_level_import_chain_preflight_mode_collision"
        $preflight = New-ColdRestoreTopLevelImportChainPreflightAttestation `
            $resolvedProjectPath $headSha
        Write-Output ($preflight | ConvertTo-Json -Compress -Depth 12)
        exit 0
    }

    if ($TargetedOwnerCaptureDiagnostic) {
        Assert-ColdRestoreCondition (-not $QualificationProbe `
            -and -not $NonOfficialProcessA `
            -and -not $EnableColdRestoreExecution `
            -and [string]::IsNullOrEmpty($ContractManifestPath)) "targeted_owner_capture_mode_collision"
        $targetedDiagnostic = Invoke-ColdRestoreTargetedOwnerCaptureGuarded $resolvedProjectPath $headSha
        Write-AllowlistedResult (New-ColdRestoreTargetedOwnerCaptureOutput $targetedDiagnostic)
        exit 0
    }

    if ($NonOfficialProcessA) {
        New-Item -ItemType Directory -Path $IsolatedAppData -Force | Out-Null
        New-Item -ItemType Directory -Path $IsolatedLocalAppData -Force | Out-Null
        $processA = Invoke-ColdRestoreNonOfficialProcessA $resolvedProjectPath $headSha
        Write-AllowlistedResult (New-ColdRestoreNonOfficialProcessAOutput $processA)
        exit 0
    }

    if ($OfficialAttempt2PreflightOnly) {
        $preflight = Assert-AndConsumeOfficialColdRestoreAuthorization `
            $resolvedProjectPath $headSha -PreflightOnly
        Write-AllowlistedResult (New-ColdRestoreOfficialAttempt2PreflightOutput $preflight)
        exit 0
    }

    $authorization = Assert-AndConsumeOfficialColdRestoreAuthorization $resolvedProjectPath $headSha
    $postClaimFreeze = Get-ColdRestoreRuntimeFreezeObservation $resolvedProjectPath $headSha
    $null = Assert-ColdRestoreRuntimeFreezeGreen `
        $postClaimFreeze "official_attempt_2_postclaim_runtime_not_frozen"
    Assert-ColdRestoreCondition ([string]$postClaimFreeze.evidence_fingerprint `
        -ceq [string]$authorization.preclaim_runtime_freeze_fingerprint) "official_attempt_2_runtime_changed_after_claim"
    $postClaimPrerequisites = Assert-ColdRestoreProcessARehearsalPrerequisites $resolvedProjectPath $headSha
    Assert-ColdRestoreCondition ([string]$postClaimPrerequisites.evidence_fingerprint `
        -ceq [string]$authorization.prerequisite_evidence_fingerprint) "official_attempt_2_prerequisite_changed_after_claim"
    $postClaimPolicy = Read-ColdRestoreRoleTimeoutPolicy $RoleTimeoutPolicyEvidence.path
    Assert-ColdRestoreCondition ([string]$postClaimPolicy.sha256 -ceq [string]$RoleTimeoutPolicyEvidence.sha256) "official_attempt_2_timeout_policy_changed_after_claim"
    Assert-ColdRestoreCondition ([IO.File]::Exists([string]$authorization.ledger_path) `
        -and (Get-FileHash -LiteralPath ([string]$authorization.ledger_path) -Algorithm SHA256).Hash.ToLowerInvariant() `
        -ceq [string]$authorization.claim_fingerprint) "official_attempt_2_claim_changed_before_process_a"
    New-Item -ItemType Directory -Path $IsolatedAppData -Force | Out-Null
    New-Item -ItemType Directory -Path $IsolatedLocalAppData -Force | Out-Null
    $scenarioFingerprint = [string]$authorization.scenario_fingerprint
    $chain = Invoke-ColdRestoreOfficialRoleChain `
        $resolvedProjectPath $headSha $scenarioFingerprint $authorization
    Write-AllowlistedResult (New-ColdRestoreOfficialAttempt2SuccessResult $chain.comparison)
    exit 0
}
catch {
    $failureProjection = cold_restore_attested_process\Get-ColdRestoreFailureProjectionFromError $_
    $candidateFailureCode = if ($null -ne $failureProjection `
        -and -not [string]::IsNullOrEmpty([string]$failureProjection.primary_failure_code)) {
        [string]$failureProjection.primary_failure_code
    }
    else {
        [string]$_.Exception.Message
    }
    $safeFailureCode = if ($candidateFailureCode -match '^[a-z0-9_]{1,128}$') {
        $candidateFailureCode
    }
    else {
        "orchestrator_internal_failure"
    }
    if ($QualificationProbe) {
        Write-AllowlistedResult ([ordered]@{
            schema_version = 1
            driver_id = "alpha04c_cold_restore_qualification_attested_v1"
            formal_full_run = $false
            official_cold_restore_vertical_slice = $false
            run_id = $(if ($RunId -match '^[A-Za-z0-9][A-Za-z0-9._-]{0,95}$') { $RunId } else { "" })
            child_completion_attestation_green = $false
            parent_exit_attestation_green = $false
            wrapper_exit_attestation_green = $false
            wrapper_execution_status = "FAILED"
            wrapper_reason_code = $safeFailureCode
            product_qualification_status = "UNTRUSTED"
            product_queue_qualification_green = $false
            product_blocker = ""
            queue_count = 0
            task_owned_process_count_after = -1
            success = $false
            failure_code = $safeFailureCode
        })
    }
    elseif ($TargetedOwnerCaptureDiagnostic) {
        Write-AllowlistedResult ([ordered]@{
            schema_version = 3
            driver_id = "alpha04c_targeted_owner_capture_diagnostic_v5_canonical_binding"
            formal_full_run = $false
            official_cold_restore_vertical_slice = $false
            targeted_owner_capture_diagnostic = $true
            run_id = $(if ($RunId -match '^[A-Za-z0-9][A-Za-z0-9._-]{0,95}$') { $RunId } else { "" })
            primary_failure_phase = $(if ($null -ne $failureProjection) { [string]$failureProjection.primary_failure_phase } else { "top_level" })
            primary_failure_code = $safeFailureCode
            secondary_failure_codes = $(if ($null -ne $failureProjection) { @($failureProjection.secondary_failure_codes) } else { @() })
            primary_failure_overwrite_count = $(if ($null -ne $failureProjection) { [int]$failureProjection.primary_failure_overwrite_count } else { 0 })
            prequota_attestation_path = $(if ($null -ne $LastTargetedPreQuotaContext) { [string]$LastTargetedPreQuotaContext.attestation_path } else { "" })
            prequota_attestation_sha256 = $(if ($null -ne $LastTargetedPreQuotaContext) { [string]$LastTargetedPreQuotaContext.attestation_sha256 } else { "" })
            success = $false
            failure_code = $safeFailureCode
        })
    }
    elseif ($NonOfficialProcessA) {
        Write-AllowlistedResult ([ordered]@{
            schema_version = 1
            driver_id = "alpha04c_non_official_process_a_v1"
            formal_full_run = $false
            official_cold_restore_vertical_slice = $false
            non_official_process_a = $true
            run_kind = $NonOfficialProcessAKind
            run_id = $(if ($RunId -match '^[A-Za-z0-9][A-Za-z0-9._-]{0,95}$') { $RunId } else { "" })
            success = $false
            failure_code = $safeFailureCode
        })
    }
    elseif ($OfficialAttempt2PreflightOnly) {
        Write-AllowlistedResult ([ordered]@{
            schema_version = 1
            driver_id = "alpha04c_official_attempt_2_preflight_v1"
            formal_full_run = $false
            official_cold_restore_vertical_slice = $false
            preflight_only = $true
            run_id = $(if ($RunId -match '^[A-Za-z0-9][A-Za-z0-9._-]{0,95}$') { $RunId } else { "" })
            official_attempt_2_claim_ready = $false
            official_attempt_2_claim_created = $false
            official_authorization_consumed = $false
            godot_launch_attempted = $false
            evidence_root_created = $false
            user_data_root_created = $false
            candidate_evidence_root_absent = $false
            candidate_user_data_root_absent = $false
            candidate_claim_root_absent = $false
            side_effect_snapshot_match = $false
            success = $false
            failure_code = $safeFailureCode
        })
    }
    elseif ($EnableColdRestoreExecution) {
        Write-AllowlistedResult (New-ColdRestoreOfficialAttempt2FailureResult $safeFailureCode)
    }
    else {
        Write-AllowlistedResult (New-AllowlistedResult $false ($ContractManifestPath -ne "") $false $safeFailureCode)
    }
    exit 1
}
