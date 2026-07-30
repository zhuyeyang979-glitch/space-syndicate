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
    [switch]$EnableColdRestoreExecution,
    [string]$ContractManifestPath = "",
    [ValidateRange(1, 3600)][int]$ChildTimeoutSeconds = 60,
    [ValidateRange(0, 1)][int]$AuthorizedOfficialColdRestoreCount = 0,
    [string]$ExpectedScenarioFingerprint = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Import-Module (Join-Path $PSScriptRoot "cold_restore_attested_process.psm1") -Force
$ORCHESTRATOR_SCHEMA_VERSION = 3
$FORMAL_FULL_RUN = $false
$DriverExecutionReady = $true
$OfficialAuthorizationId = "alpha04c-p0-cold-restore-depth1-seed900626424-v1"
$OfficialClaimRelativePath = "codex\cold_restore_v3\official-alpha04c-depth1-seed900626424\official_claim_ledger.json"
$TargetedOwnerCaptureQuotaLedgerRelativePath = "codex\cold_restore_v3\non-official-alpha04c-production-save-completion-repair-0240dae\targeted_owner_capture_quota_ledger.json"
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
    "slot_id",
    "slot_state",
    "source_sections_digest",
    "restored_sections_digest",
    "saved_sections_digest",
    "source_write_id",
    "write_id",
    "source_write_fingerprint",
    "write_fingerprint",
    "section_count",
    "preflight_count",
    "owner_apply_count",
    "registry_apply_count",
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
    "restore_notification_delta"
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
    "section_id", "owner_id", "failure_class", "reason_code", "result_empty",
    "result_not_dictionary", "result_not_pure_data", "result_header_invalid",
    "result_version_invalid", "result_ruleset_invalid", "state_version_observed",
    "ruleset_id_observed", "live_state_mutated_during_capture",
    "private_payload_redacted"
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
    $actual = @($Value.PSObject.Properties.Name | Sort-Object)
    $expected = @($ExpectedFields | Sort-Object)
    return @(Compare-Object -ReferenceObject $expected -DifferenceObject $actual).Count -eq 0
}

function Test-OwnerCaptureFailureIdentity {
    param([Parameter(Mandatory = $true)]$Failure)
    if (-not (Test-ExactFieldSet $Failure $OwnerCaptureFailureFields)) {
        return $false
    }
    $index = [int]$Failure.section_index
    return [int]$Failure.schema_version -eq 1 `
        -and $index -ge 0 `
        -and $index -lt $SaveSectionOrder.Count `
        -and [string]$Failure.section_id -ceq $SaveSectionOrder[$index] `
        -and [string]$Failure.owner_id -ceq $SaveOwnerOrder[$index] `
        -and [string]$Failure.failure_class -cin $OwnerCaptureFailureClasses `
        -and [string]$Failure.reason_code -cmatch '^[a-z0-9_]{1,128}$' `
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
    $failureFields = @($Audit.first_failure.PSObject.Properties.Name)
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
    Assert-ColdRestoreCondition ([int]$Manifest.schema_version -eq $ORCHESTRATOR_SCHEMA_VERSION) "manifest_schema_invalid"
    Assert-ColdRestoreCondition ([string]$Manifest.visibility_scope -eq "qa_allowlisted") "manifest_visibility_invalid"
    Assert-ColdRestoreCondition ([string]$Manifest.run_id -eq $ExpectedRunId) "manifest_run_id_mismatch"
    Assert-ColdRestoreCondition ([string]$Manifest.process_role -eq $Role) "manifest_role_mismatch"
    Assert-ColdRestoreCondition ([int64]$Manifest.process_id -gt 0) "manifest_process_id_invalid"
    Assert-ColdRestoreCondition ([string]$Manifest.head_sha -match '^[0-9a-f]{7,64}$') "manifest_head_sha_invalid"
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
    Assert-ColdRestoreCondition ($Manifest.victory_unresolved_before_save -is [bool]) "manifest_victory_flag_invalid"
    Assert-ColdRestoreCondition ($Manifest.production_surface_ready -is [bool]) "manifest_surface_flag_invalid"
    Assert-ColdRestoreCondition ($Manifest.success -is [bool]) "manifest_success_flag_invalid"
    Assert-ColdRestoreCondition ($Manifest.victory_state_sequence -is [System.Array] `
        -and @($Manifest.victory_state_sequence).Count -le 12) "manifest_victory_sequence_invalid"
    foreach ($state in @($Manifest.victory_state_sequence)) {
        Assert-ColdRestoreCondition ([string]$state -match '^[a-z0-9_]{1,64}$') "manifest_victory_sequence_invalid"
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
    $root = Join-Path $ResolvedProjectPath ".godot\cold_restore_attestation_v1\$RunId"
    return [pscustomobject]@{
        root = $root
        child_attestation = Join-Path $root "child\$Role.completion.json"
        child_result = Join-Path $root "child\$Role.result.json"
        parent_attestation = Join-Path $root "parent\$Role.exit.json"
        stdout = Join-Path $root "parent\$Role.stdout.log"
        stderr = Join-Path $root "parent\$Role.stderr.log"
        phase_timeline = Join-Path $root "diagnostics\producer.phase_timeline.json"
        phase_timeline_events = Join-Path $root "diagnostics\producer.phase_timeline.events"
    }
}

function Read-ColdRestoreJsonArtifact {
    param([Parameter(Mandatory = $true)][string]$Path)
    Assert-ColdRestoreCondition (Test-Path -LiteralPath $Path -PathType Leaf) "evidence_artifact_missing"
    try {
        return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        throw "evidence_artifact_json_invalid"
    }
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
    $arguments = New-ColdRestoreGodotArgumentList `
        -EngineArgumentList @("--headless", "--path", $ResolvedProjectPath, "--script", $DriverScript) `
        -UserArgumentList @(
            "--cold-restore-qualification-probe",
            "--cold-restore-role=qualification",
            "--cold-restore-run-id=$RunId",
            "--cold-restore-head-sha=$HeadSha",
            "--cold-restore-artifact-root=$ArtifactRoot"
        )
    $run = Invoke-ColdRestoreAttestedProcess `
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
        -TimeoutSeconds $ChildTimeoutSeconds `
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

    Assert-ColdRestoreCondition ($ChildTimeoutSeconds -le 180) "diagnostic_timeout_exceeds_limit"
    Assert-ColdRestoreCondition ($ExpectedScenarioFingerprint -match '^[0-9a-f]{64}$') "expected_scenario_fingerprint_invalid"
    $paths = Get-ColdRestoreRolePaths $ResolvedProjectPath "producer"
    $arguments = New-ColdRestoreGodotArgumentList `
        -EngineArgumentList @("--headless", "--path", $ResolvedProjectPath, "--script", $DriverScript) `
        -UserArgumentList @(
            "--cold-restore-non-official-process-a",
            "--cold-restore-role=producer",
            "--cold-restore-run-id=$RunId",
            "--cold-restore-head-sha=$HeadSha",
            "--cold-restore-artifact-root=$ArtifactRoot",
            "--cold-restore-scenario-fingerprint=$ExpectedScenarioFingerprint"
        )
    $run = Invoke-ColdRestoreAttestedProcess `
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
        -TimeoutSeconds $ChildTimeoutSeconds `
        -EnvironmentVariables @{ APPDATA = $IsolatedAppData; LOCALAPPDATA = $IsolatedLocalAppData } `
        -PhaseTimelineEventDirectory $paths.phase_timeline_events `
        -PhaseTimelinePath $paths.phase_timeline
    Assert-ColdRestoreCondition ([bool]$run.wrapper_exit_green) "producer_$($run.wrapper_reason_code)"
    $manifest = Read-ColdRestoreJsonArtifact $paths.child_result
    Assert-ColdRestoreManifest $manifest "producer" $RunId
    Assert-ColdRestoreCondition (-not [bool]$run.child.official `
        -and -not [bool]$run.child.formal `
        -and -not [bool]$run.child.official_count_consumed `
        -and [bool]$run.child.qualification_green -eq [bool]$manifest.success) "non_official_process_a_child_binding_invalid"
    if ($NonOfficialProcessAKind -eq "rehearsal") {
        Assert-ColdRestoreCondition ([bool]$manifest.success `
            -and [bool]$run.child.save_written) "process_a_rehearsal_product_failed"
    }
    $timeline = $run.phase_timeline
    Assert-ColdRestoreCondition ($null -ne $timeline `
        -and [int]$timeline.schema_version -eq 1 `
        -and [string]$timeline.timeline_id -eq "ProcessAPhaseTimelineV1" `
        -and @($timeline.phase_rows).Count -eq 19 `
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
    return [pscustomobject]@{
        run = $run
        manifest = $manifest
        timeline = $timeline
        paths = $paths
        save_path = $savePath
    }
}

function Invoke-ColdRestoreTargetedOwnerCaptureDiagnostic {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedProjectPath,
        [Parameter(Mandatory = $true)][string]$HeadSha
    )

    Assert-ColdRestoreCondition ($RunId -cmatch '^alpha04c-owner-capture-diagnostic-[0-9a-f]{12}$' `
        -and $RunId -ceq "alpha04c-owner-capture-diagnostic-$($HeadSha.Substring(0, 12))") "targeted_owner_capture_run_id_invalid"
    Assert-ColdRestoreCondition ($AuthorizedOfficialColdRestoreCount -eq 0) "targeted_owner_capture_official_authorization_forbidden"
    Assert-ColdRestoreCondition ($ChildTimeoutSeconds -eq 180) "targeted_owner_capture_timeout_must_be_180"
    Assert-ColdRestoreCondition ($ExpectedScenarioFingerprint -ceq $TargetedOwnerCaptureScenarioFingerprint) "expected_scenario_fingerprint_invalid"
    $diagnosticQuota = Consume-ColdRestoreTargetedOwnerCaptureDiagnosticQuota $ResolvedProjectPath $HeadSha
    Assert-ColdRestoreCondition ([IO.File]::Exists([string]$diagnosticQuota.path) `
        -and [string]$diagnosticQuota.fingerprint -cmatch '^[0-9a-f]{64}$') "targeted_owner_capture_diagnostic_quota_ledger_invalid"
    $paths = Get-ColdRestoreRolePaths $ResolvedProjectPath "producer"
    $arguments = New-ColdRestoreGodotArgumentList `
        -EngineArgumentList @("--headless", "--path", $ResolvedProjectPath, "--script", $DriverScript) `
        -UserArgumentList @(
            "--cold-restore-non-official-process-a",
            "--cold-restore-targeted-owner-capture-diagnostic",
            "--cold-restore-role=producer",
            "--cold-restore-run-id=$RunId",
            "--cold-restore-head-sha=$HeadSha",
            "--cold-restore-artifact-root=$ArtifactRoot",
            "--cold-restore-scenario-fingerprint=$ExpectedScenarioFingerprint"
        )
    $run = Invoke-ColdRestoreAttestedProcess `
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
        -TimeoutSeconds $ChildTimeoutSeconds `
        -EnvironmentVariables @{ APPDATA = $IsolatedAppData; LOCALAPPDATA = $IsolatedLocalAppData } `
        -PhaseTimelineEventDirectory $paths.phase_timeline_events `
        -PhaseTimelinePath $paths.phase_timeline
    Assert-ColdRestoreCondition ([bool]$run.wrapper_exit_green) "targeted_owner_capture_$($run.wrapper_reason_code)"
    Assert-ColdRestoreCondition (-not [bool]$run.child.official `
        -and -not [bool]$run.child.formal `
        -and -not [bool]$run.child.official_count_consumed `
        -and -not [bool]$run.child.save_written `
        -and [bool]$run.parent.child_attestation_valid `
        -and [int]$run.parent.exit_code -eq 0 `
        -and -not [bool]$run.parent.timed_out `
        -and -not [bool]$run.parent.terminated_by_parent `
        -and [int]$run.parent.task_owned_process_count_after -eq 0) "targeted_owner_capture_exit_attestation_invalid"
    $timeline = $run.phase_timeline
    $cleanupRows = if ($null -ne $timeline) { @($timeline.phase_rows | Where-Object { [string]$_.phase_id -ceq "runtime_cleanup_complete" }) } else { @() }
    $quitRows = if ($null -ne $timeline) { @($timeline.phase_rows | Where-Object { [string]$_.phase_id -ceq "quit_requested" }) } else { @() }
    Assert-ColdRestoreCondition ($null -ne $timeline `
        -and [int]$timeline.schema_version -eq 1 `
        -and [string]$timeline.timeline_id -ceq "ProcessAPhaseTimelineV1" `
        -and @($timeline.phase_rows).Count -eq 19 `
        -and [string]$timeline.last_completed_phase -ceq "quit_requested" `
        -and -not [bool]$timeline.save_file_exists `
        -and [bool]$timeline.allowlisted_manifest_written `
        -and [bool]$timeline.child_completion_written `
        -and [bool]$timeline.quit_requested `
        -and $cleanupRows.Count -eq 1 -and [bool]$cleanupRows[0].success `
        -and $quitRows.Count -eq 1 -and [bool]$quitRows[0].success) "targeted_owner_capture_timeline_cleanup_invalid"
    $manifest = Read-ColdRestoreJsonArtifact $paths.child_result
    Assert-ColdRestoreManifest $manifest "producer" $RunId
    $expectedDiagnosticManifest = -not [bool]$manifest.success `
        -and [string]$manifest.failure_code -in @("targeted_owner_capture_diagnostic_complete", "save_coordinator_or_envelope_capture_path_divergence")
    if (-not $expectedDiagnosticManifest) {
        $childFailureCode = [string]$manifest.failure_code
        $safeChildFailureCode = if ($childFailureCode -cmatch '^[a-z0-9_]{1,88}$') {
            "targeted_owner_capture_child_$childFailureCode"
        }
        else {
            "targeted_owner_capture_manifest_invalid"
        }
        throw $safeChildFailureCode
    }
    $diagnosticPath = Join-Path $ResolvedProjectPath ".godot\cold_restore_attestation_v1\$RunId\diagnostics\owner_capture_audit.json"
    $diagnostic = Read-ColdRestoreJsonArtifact $diagnosticPath
    $diagnosticSha256 = (Get-FileHash -LiteralPath $diagnosticPath -Algorithm SHA256).Hash.ToLowerInvariant()
    Assert-ColdRestoreCondition ([string]$run.child.product_blocker -ceq "TARGETED_OWNER_CAPTURE_DIAGNOSTIC_SHA256:$diagnosticSha256" `
        -and [string]$run.child.final_reason_code -ceq "targeted_owner_capture_diagnostic_sha256_$diagnosticSha256") "targeted_owner_capture_child_diagnostic_binding_invalid"
    Assert-ColdRestoreCondition (Test-ExactFieldSet $diagnostic $OwnerCaptureDiagnosticFields) "targeted_owner_capture_field_set_invalid"
    $actualPhases = @($diagnostic.phase_audits | ForEach-Object { [string]$_.phase_id })
    $phaseDifferences = @(Compare-Object $TargetedOwnerCapturePhases $actualPhases -SyncWindow 0)
    Assert-ColdRestoreCondition ([int]$diagnostic.schema_version -eq 1 `
        -and [string]$diagnostic.diagnostic_id -ceq "TargetedOwnerCaptureDiagnosticV1" `
        -and [string]$diagnostic.run_id -ceq $RunId `
        -and [string]$diagnostic.repository_head -ceq $HeadSha `
        -and [string]$diagnostic.scenario_fingerprint -ceq $ExpectedScenarioFingerprint `
        -and -not [bool]$diagnostic.official `
        -and -not [bool]$diagnostic.formal `
        -and [int]$diagnostic.challenge_depth -eq 1 `
        -and [int64]$diagnostic.seed -eq 900626424 `
        -and [int]$diagnostic.local_player_count -eq 1 `
        -and [int]$diagnostic.ai_player_count -eq 3 `
        -and [int]$diagnostic.ai_action_count -ge 1 `
        -and [bool]$diagnostic.ai_state_digest_changed `
        -and [int]$diagnostic.audit_count -eq 8 `
        -and $phaseDifferences.Count -eq 0 `
        -and [bool]$diagnostic.safety_green `
        -and -not [bool]$diagnostic.save_file_exists `
        -and -not [bool]$diagnostic.official_claim_path_present) "targeted_owner_capture_diagnostic_invalid"
    $observedFirstFailure = $null
    $observedFirstFailurePhase = "none"
    foreach ($audit in @($diagnostic.phase_audits)) {
        Assert-ColdRestoreCondition (Test-OwnerCaptureAuditRelationship $audit) "targeted_owner_capture_audit_relationship_invalid"
        if ($null -eq $observedFirstFailure -and @($audit.first_failure.PSObject.Properties).Count -gt 0) {
            $observedFirstFailure = $audit.first_failure
            $observedFirstFailurePhase = [string]$audit.phase_id
        }
        Assert-ColdRestoreCondition ([bool]$audit.safety_green `
            -and [bool]$audit.world_fingerprint_match `
            -and [bool]$audit.safety_observation_match `
            -and [int]$audit.world_advance_delta -eq 0 `
            -and [int]$audit.rng_draw_delta -eq 0 `
            -and [int]$audit.public_log_delta -eq 0 `
            -and [int]$audit.private_feedback_delta -eq 0 `
            -and [int]$audit.sale_receipt_delta -eq 0 `
            -and [int]$audit.human_action_delta -eq 0 `
            -and [int]$audit.ai_action_delta -eq 0 `
            -and [int]$audit.notification_delta -eq 0) "targeted_owner_capture_audit_mutated_runtime"
    }
    $topFailureFields = @($diagnostic.first_failure.PSObject.Properties.Name)
    $observedFailureJson = if ($null -eq $observedFirstFailure) { "{}" } else { $observedFirstFailure | ConvertTo-Json -Compress -Depth 6 }
    $topFailureJson = if ($topFailureFields.Count -eq 0) { "{}" } else { $diagnostic.first_failure | ConvertTo-Json -Compress -Depth 6 }
    Assert-ColdRestoreCondition ($topFailureJson -ceq $observedFailureJson `
        -and [string]$diagnostic.first_phase_with_capture_failure -ceq $observedFirstFailurePhase) "targeted_owner_capture_first_failure_binding_invalid"
    Assert-ColdRestoreCondition (($topFailureFields.Count -gt 0 `
            -and [string]$manifest.failure_code -ceq "targeted_owner_capture_diagnostic_complete") `
        -or ($topFailureFields.Count -eq 0 `
            -and [string]$manifest.failure_code -ceq "save_coordinator_or_envelope_capture_path_divergence")) "targeted_owner_capture_manifest_failure_binding_invalid"
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
        paths = $paths
        diagnostic_path = $diagnosticPath
    }
}

function Assert-ColdRestoreTargetedOwnerCapturePostconditions {
    param([Parameter(Mandatory = $true)][string]$ResolvedProjectPath)

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
    $saveArtifacts = if (Test-Path -LiteralPath $UserDataRoot -PathType Container) {
        @(Get-ChildItem -LiteralPath $UserDataRoot -Recurse -File | Where-Object {
            $_.FullName -match '[\\/]saves[\\/]' -or $_.Name -like '*.save*' `
                -or $_.Name -like '*.tmp*' -or $_.Name -like '*.backup*'
        })
    }
    else {
        @()
    }
    Assert-ColdRestoreCondition ($saveArtifacts.Count -eq 0) "targeted_owner_capture_unexpected_save"
}

function New-ColdRestoreTargetedOwnerCaptureOutput {
    param([Parameter(Mandatory = $true)]$Result)

    $failure = $Result.diagnostic.first_failure
    $failureFields = if ($null -ne $failure) { @($failure.PSObject.Properties.Name) } else { @() }
    return [ordered]@{
        schema_version = 1
        driver_id = "alpha04c_targeted_owner_capture_diagnostic_v1"
        formal_full_run = $false
        official_cold_restore_vertical_slice = $false
        targeted_owner_capture_diagnostic = $true
        run_id = $RunId
        repository_head = [string]$Result.diagnostic.repository_head
        scenario_fingerprint = $ExpectedScenarioFingerprint
        audit_count = [int]$Result.diagnostic.audit_count
        ai_action_count = [int]$Result.diagnostic.ai_action_count
        ai_state_digest_changed = [bool]$Result.diagnostic.ai_state_digest_changed
        first_phase_with_capture_failure = [string]$Result.diagnostic.first_phase_with_capture_failure
        failing_section_id = $(if ($failureFields -contains "section_id") { [string]$failure.section_id } else { "" })
        failing_owner_id = $(if ($failureFields -contains "owner_id") { [string]$failure.owner_id } else { "" })
        failing_failure_class = $(if ($failureFields -contains "failure_class") { [string]$failure.failure_class } else { "" })
        failing_reason_code = $(if ($failureFields -contains "reason_code") { [string]$failure.reason_code } else { "" })
        child_completion_attestation_valid = [bool]$Result.run.parent.child_attestation_valid
        parent_exit_attestation_green = [bool]$Result.run.parent.wrapper_exit_green
        exit_code = [int]$Result.run.parent.exit_code
        timed_out = [bool]$Result.run.parent.timed_out
        terminated_by_parent = [bool]$Result.run.parent.terminated_by_parent
        task_owned_process_count_after = [int]$Result.run.parent.task_owned_process_count_after
        save_written = $false
        official_count_consumed = $false
        diagnostic_path = [string]$Result.diagnostic_path
        success = $true
        failure_code = ""
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
        timeout_seconds = $ChildTimeoutSeconds
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
        -and [string]$launch.authorization_id -eq $OfficialAuthorizationId `
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
    Assert-ColdRestoreCondition ($processRelationValid `
        -and [int]$launch.wrapper_process_id -eq [int]$Run.parent.child_pid `
        -and @($Run.observed_task_process_ids) -contains [int]$launch.engine_process_id) "launch_attestation_process_identity_invalid"
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
    $launchNonce = [Guid]::NewGuid().ToString("N")
    $launchAttestationPath = Join-Path $paths.root "launch\orchestrator-$($Authorization.orchestrator_process_id)\$Role.authorized.json"
    $userArguments = @(
        "--cold-restore-role=$Role",
        "--cold-restore-run-id=$RunId",
        "--cold-restore-head-sha=$HeadSha",
        "--cold-restore-artifact-root=$ArtifactRoot",
        "--cold-restore-scenario-fingerprint=$ScenarioFingerprint",
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
    $arguments = New-ColdRestoreGodotArgumentList `
        -EngineArgumentList @("--headless", "--path", $ResolvedProjectPath, "--script", $DriverScript) `
        -UserArgumentList $userArguments
    $run = Invoke-ColdRestoreAttestedProcess `
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
        -TimeoutSeconds $ChildTimeoutSeconds `
        -EnvironmentVariables @{ APPDATA = $IsolatedAppData; LOCALAPPDATA = $IsolatedLocalAppData } `
        -LaunchAttestationPath $launchAttestationPath `
        -LaunchAuthorization ([pscustomobject][ordered]@{
            authorization_id = $OfficialAuthorizationId
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
        -PhaseTimelinePath $(if ($Role -eq "producer") { $paths.phase_timeline } else { "" })
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
    Assert-ColdRestoreCondition ([bool]$run.child.official `
        -and -not [bool]$run.child.formal `
        -and [bool]$run.child.official_count_consumed `
        -and [string]$run.child.scenario_fingerprint -eq $ScenarioFingerprint `
        -and [bool]$run.child.qualification_green -eq [bool]$manifest.success `
        -and [int]$run.child.queue_count -eq [int]$manifest.queue_entry_count `
        -and [string]$run.child.queue_trigger_target_fingerprint -eq [string]$manifest.queue_trigger_stable_target_fingerprint) "${Role}_child_manifest_binding_invalid"
    return [pscustomobject]@{
        process_id = [int]$run.parent.child_pid
        manifest = $manifest
        child = $run.child
        parent = $run.parent
        launch_attestation_sha256 = [string]$launchEvidence.sha256
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
        -and [int]$Producer.registry_apply_count -eq 0) "producer_apply_count_invalid"
    foreach ($manifest in @($Consumer, $Validator)) {
        Assert-ColdRestoreCondition ([int]$manifest.owner_apply_count -eq 19 `
            -and [int]$manifest.registry_apply_count -eq 1) "restore_apply_count_invalid"
        foreach ($field in $RestoreDeltaFields) {
            Assert-ColdRestoreCondition ([int]$manifest.$field -eq 0) "restore_delta_nonzero"
        }
        Assert-ColdRestoreCondition ([int]$manifest.rng_draw_count_before -eq [int]$manifest.rng_draw_count_after) "restore_rng_count_changed"
    }
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
    $expectedVictorySequence = @("idle", "qualification", "audit", "resolved")
    $consumerVictory = @($Consumer.victory_state_sequence) | ConvertTo-Json -Compress
    $validatorVictory = @($Validator.victory_state_sequence) | ConvertTo-Json -Compress
    $expectedVictory = $expectedVictorySequence | ConvertTo-Json -Compress
    Assert-ColdRestoreCondition ($consumerVictory -eq $expectedVictory `
        -and $validatorVictory -eq $consumerVictory) "victory_sequence_mismatch"
    foreach ($field in $SettlementCountFields) {
        Assert-ColdRestoreCondition ([int]$Consumer.$field -eq 1 `
            -and [int]$Validator.$field -eq 1) "final_settlement_exact_once_invalid"
    }
    foreach ($manifest in @($Consumer, $Validator)) {
        Assert-ColdRestoreCondition ([int]$manifest.terminal_quiescent_frames -eq 8) "terminal_quiescent_frames_invalid"
        Assert-ColdRestoreCondition ([int]$manifest.terminal_world_delta -eq 0 `
            -and [int]$manifest.terminal_rng_draw_delta -eq 0) "terminal_quiet_delta_nonzero"
    }
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
        final_settlement_exact_once = $true
        terminal_quiescent_frames = 8
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
        [Parameter(Mandatory = $true)][string]$HeadSha
    )

    $gitCommonDirectory = Resolve-ColdRestoreGitCommonDirectory $ResolvedProjectPath
    $ledgerPath = Join-Path $gitCommonDirectory $TargetedOwnerCaptureQuotaLedgerRelativePath
    $ledger = [ordered]@{
        schema_version = 1
        ledger_id = "Alpha04C.TargetedOwnerCaptureDiagnosticQuotaLedgerV1"
        task_id = "ALPHA_0_4_C_PRODUCTION_SAVE_COMPLETION_DEFECT_REPAIR_AND_GREEN_PROCESS_A_REHEARSAL"
        created_at_utc = [DateTime]::UtcNow.ToString("O", [Globalization.CultureInfo]::InvariantCulture)
        run_id = $RunId
        repository_head = $HeadSha
        scenario_fingerprint = $ExpectedScenarioFingerprint
        authorized_diagnostic_count = 1
        diagnostic_count_before = 0
        diagnostic_count_after = 1
        official = $false
        formal = $false
        official_authorization_consumed = $false
        orchestrator_script_sha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()
        orchestrator_process_id = $PID
        status = "consumed"
    }
    try {
        $ledgerFingerprint = Write-ColdRestoreExclusiveJson $ledgerPath ([pscustomobject]$ledger)
    }
    catch {
        $ledgerFailure = [string]$_.Exception.Message
        if ($ledgerFailure -eq "exclusive_evidence_create_new_failed" -and [IO.File]::Exists($ledgerPath)) {
            throw "targeted_owner_capture_diagnostic_already_consumed"
        }
        throw "targeted_owner_capture_diagnostic_quota_ledger_failed"
    }
    return [pscustomobject]@{
        path = $ledgerPath
        fingerprint = [string]$ledgerFingerprint
    }
}

function Assert-AndConsumeOfficialColdRestoreAuthorization {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedProjectPath,
        [Parameter(Mandatory = $true)][string]$HeadSha
    )
    Assert-ColdRestoreCondition ($AuthorizedOfficialColdRestoreCount -eq 1) "official_authorization_count_invalid"
    Assert-ColdRestoreCondition ($ExpectedScenarioFingerprint -match '^[0-9a-f]{64}$') "expected_scenario_fingerprint_invalid"
    $paths = Get-ColdRestoreRolePaths $ResolvedProjectPath "qualification"
    Assert-ColdRestoreCondition (Test-Path -LiteralPath $paths.child_attestation -PathType Leaf) "official_qualification_child_attestation_missing"
    $startedAt = [IO.File]::GetLastWriteTimeUtc($paths.child_attestation).AddSeconds(-1)
    $childValidation = Test-ColdRestoreChildCompletionAttestation `
        -Path $paths.child_attestation `
        -ExpectedRunId $RunId `
        -ExpectedRole "qualification" `
        -ExpectedRepositoryHead $HeadSha `
        -ProcessStartedAtUtc $startedAt
    Assert-ColdRestoreCondition ([bool]$childValidation.valid) "official_qualification_child_attestation_invalid"
    $parent = Read-ColdRestoreJsonArtifact $paths.parent_attestation
    Assert-ColdRestoreCondition (Test-ExactFieldSet $parent $ParentExitAttestationFields) "official_qualification_parent_attestation_field_set_invalid"
    Assert-ColdRestoreCondition ([int]$parent.schema_version -eq 1 `
        -and [string]$parent.run_id -eq $RunId `
        -and [string]$parent.role -eq "qualification" `
        -and [bool]$parent.observed_exit `
        -and [int]$parent.exit_code -eq 0 `
        -and -not [bool]$parent.timed_out `
        -and -not [bool]$parent.terminated_by_parent `
        -and [bool]$parent.child_attestation_found `
        -and [bool]$parent.child_attestation_valid `
        -and [string]$parent.child_attestation_fingerprint -eq [string]$childValidation.fingerprint `
        -and [int]$parent.task_owned_process_count_after -eq 0 `
        -and [bool]$parent.wrapper_exit_green `
        -and [string]$parent.wrapper_reason_code -eq "ok") "official_qualification_parent_attestation_invalid"
    $result = Read-ColdRestoreJsonArtifact $paths.child_result
    Assert-ColdRestoreQualificationResult $result $childValidation.value $HeadSha
    Assert-ColdRestoreCondition ([bool]$result.success `
        -and [int]$result.queue_count -ge 1 `
        -and [string]$result.product_blocker -eq "" `
        -and [string]$result.scenario_fingerprint -eq $ExpectedScenarioFingerprint) "official_product_qualification_not_green"
    $gateCachePath = Join-Path $ResolvedProjectPath "reports\handoffs\alpha04c_gate_cache.json"
    $gateCache = Read-ColdRestoreJsonArtifact $gateCachePath
    Assert-ColdRestoreCondition ([int]$gateCache.official_cold_restore_vertical_slice_count -eq 0) "official_count_before_not_zero"
    $gitCommonDirectory = Resolve-ColdRestoreGitCommonDirectory $ResolvedProjectPath
    $ledgerPath = Join-Path $gitCommonDirectory $OfficialClaimRelativePath
    $orchestratorCreationTimeTicks = Get-ColdRestoreOrchestratorCreationTimeTicks
    $orchestratorScriptSha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $claimNonce = [Guid]::NewGuid().ToString("N")
    $ledger = [ordered]@{
        schema_version = 1
        authorization_id = $OfficialAuthorizationId
        created_at_utc = [DateTime]::UtcNow.ToString("O", [Globalization.CultureInfo]::InvariantCulture)
        run_id = $RunId
        source_head_sha = $HeadSha
        challenge_depth = 1
        seed = [int64]900626424
        scenario_fingerprint = [string]$result.scenario_fingerprint
        qualification_child_attestation_fingerprint = [string]$childValidation.fingerprint
        qualification_parent_attestation_sha256 = (Get-FileHash -LiteralPath $paths.parent_attestation -Algorithm SHA256).Hash.ToLowerInvariant()
        qualification_result_sha256 = (Get-FileHash -LiteralPath $paths.child_result -Algorithm SHA256).Hash.ToLowerInvariant()
        orchestrator_id = "alpha04c_cold_restore_vertical_slice_orchestrator_v3"
        orchestrator_schema_version = $ORCHESTRATOR_SCHEMA_VERSION
        orchestrator_script_sha256 = $orchestratorScriptSha256
        orchestrator_process_id = $PID
        orchestrator_creation_time_utc_ticks = $orchestratorCreationTimeTicks
        claim_nonce = $claimNonce
        status = "consumed"
        authorized_official_count = 1
        official_count_before = 0
        official_count_after = 1
    }
    try {
        $claimFingerprint = Write-ColdRestoreExclusiveJson $ledgerPath ([pscustomobject]$ledger)
    }
    catch {
        $claimFailure = [string]$_.Exception.Message
        if ($claimFailure -eq "exclusive_evidence_create_new_failed" -and [IO.File]::Exists($ledgerPath)) {
            throw "official_authorization_already_consumed"
        }
        if ($claimFailure -like "exclusive_evidence_consumed_*") {
            throw "official_authorization_consumed_but_claim_incomplete"
        }
        throw "official_claim_create_new_failed"
    }
    return [pscustomobject]@{
        ledger_path = $ledgerPath
        claim_fingerprint = [string]$claimFingerprint
        claim_nonce = $claimNonce
        orchestrator_process_id = $PID
        orchestrator_creation_time_utc_ticks = $orchestratorCreationTimeTicks
        scenario_fingerprint = [string]$result.scenario_fingerprint
        qualification_result = $result
    }
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
        driver_id = "alpha04c_cold_restore_vertical_slice_orchestrator_v3"
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
        final_settlement_exact_once = $compared -and [bool]$Comparison.final_settlement_exact_once
        terminal_quiescent_frames = if ($compared) { [int]$Comparison.terminal_quiescent_frames } else { 0 }
        terminal_quiet = $compared -and [bool]$Comparison.terminal_quiet
        success = $Success
        failure_code = $FailureCode
    }
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
        -and -not $NonOfficialProcessA -and -not $EnableColdRestoreExecution) {
        Write-AllowlistedResult (New-AllowlistedResult $false $false $true "")
        exit 0
    }

    Assert-ColdRestoreCondition $DriverExecutionReady "driver_execution_not_ready"
    $resolvedProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path
    Assert-ColdRestoreCondition (Test-Path -LiteralPath (Join-Path $resolvedProjectPath "project.godot") -PathType Leaf) "godot_project_invalid"
    $GodotPath = Resolve-ColdRestoreGodotExecutable $GodotPath
    $headSha = [string](& git -C $resolvedProjectPath rev-parse HEAD 2>$null)
    Assert-ColdRestoreCondition ($headSha -match '^[0-9a-f]{40,64}$') "head_sha_unavailable"
    $dirtyPaths = @(& git -C $resolvedProjectPath status --porcelain=v1 2>$null)
    Assert-ColdRestoreCondition ($dirtyPaths.Count -eq 0) "worktree_not_clean"
    if ($TargetedOwnerCaptureDiagnostic) {
        $diagnosticEvidenceRoot = Join-Path $resolvedProjectPath ".godot\cold_restore_attestation_v1\$RunId"
        Assert-ColdRestoreCondition (-not (Test-Path -LiteralPath $UserDataRoot) `
            -and -not (Test-Path -LiteralPath $diagnosticEvidenceRoot)) "targeted_owner_capture_evidence_collision"
    }
    New-Item -ItemType Directory -Path $IsolatedAppData -Force | Out-Null
    New-Item -ItemType Directory -Path $IsolatedLocalAppData -Force | Out-Null

    if ($QualificationProbe) {
        $qualification = Invoke-ColdRestoreQualification $resolvedProjectPath $headSha
        Write-AllowlistedResult (New-ColdRestoreQualificationOutput $qualification.run $qualification.result)
        exit 0
    }

    if ($TargetedOwnerCaptureDiagnostic) {
        Assert-ColdRestoreCondition (-not $QualificationProbe `
            -and -not $NonOfficialProcessA `
            -and -not $EnableColdRestoreExecution `
            -and [string]::IsNullOrEmpty($ContractManifestPath)) "targeted_owner_capture_mode_collision"
        try {
            $targetedDiagnostic = Invoke-ColdRestoreTargetedOwnerCaptureDiagnostic $resolvedProjectPath $headSha
        }
        finally {
            Assert-ColdRestoreTargetedOwnerCapturePostconditions $resolvedProjectPath
        }
        Write-AllowlistedResult (New-ColdRestoreTargetedOwnerCaptureOutput $targetedDiagnostic)
        exit 0
    }

    if ($NonOfficialProcessA) {
        $processA = Invoke-ColdRestoreNonOfficialProcessA $resolvedProjectPath $headSha
        Write-AllowlistedResult (New-ColdRestoreNonOfficialProcessAOutput $processA)
        exit 0
    }

    $authorization = Assert-AndConsumeOfficialColdRestoreAuthorization $resolvedProjectPath $headSha
    $scenarioFingerprint = [string]$authorization.scenario_fingerprint
    $producerRun = Invoke-ColdRestoreRole "producer" $resolvedProjectPath $headSha $scenarioFingerprint $authorization
    # Process B starts only after Process A exited and its one safe manifest parsed.
    $consumerRun = Invoke-ColdRestoreRole "consumer" $resolvedProjectPath $headSha $scenarioFingerprint $authorization `
        ([int64]$producerRun.manifest.queue_trigger_resolution_id) `
        ([string]$producerRun.manifest.queue_trigger_stable_target_fingerprint)
    # Process C starts only after Process B exited and its one safe manifest parsed.
    $validatorRun = Invoke-ColdRestoreRole "validator" $resolvedProjectPath $headSha $scenarioFingerprint $authorization `
        ([int64]$consumerRun.manifest.queue_trigger_resolution_id) `
        ([string]$consumerRun.manifest.queue_trigger_stable_target_fingerprint)
    $comparison = Compare-ColdRestoreManifests `
        $producerRun.manifest $consumerRun.manifest $validatorRun.manifest
    Write-AllowlistedResult (New-AllowlistedResult $true $false $true "" $comparison)
    exit 0
}
catch {
    $candidateFailureCode = [string]$_.Exception.Message
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
            schema_version = 1
            driver_id = "alpha04c_targeted_owner_capture_diagnostic_v1"
            formal_full_run = $false
            official_cold_restore_vertical_slice = $false
            targeted_owner_capture_diagnostic = $true
            run_id = $(if ($RunId -match '^[A-Za-z0-9][A-Za-z0-9._-]{0,95}$') { $RunId } else { "" })
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
    else {
        Write-AllowlistedResult (New-AllowlistedResult ([bool]$EnableColdRestoreExecution) ($ContractManifestPath -ne "") $false $safeFailureCode)
    }
    exit 1
}
