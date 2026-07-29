[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,
    [string]$GodotPath = "godot",
    [string]$RunId = "alpha04c-cold-restore",
    [switch]$EnableColdRestoreExecution,
    [string]$ContractManifestPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ORCHESTRATOR_SCHEMA_VERSION = 3
$FORMAL_FULL_RUN = $false
$DriverExecutionReady = $false
$DriverScript = "res://scripts/tools/cold_restore_vertical_slice_driver.gd"
$ArtifactRoot = "user://test_runs/alpha04c/$RunId/evidence"
$UserDataRoot = Join-Path ([IO.Path]::GetTempPath()) "space_syndicate_alpha04c_cold_restore_$RunId"
$IsolatedAppData = Join-Path $UserDataRoot "appdata-roaming"
$IsolatedLocalAppData = Join-Path $UserDataRoot "appdata-local"
$ManifestPrefix = "COLD_RESTORE_MANIFEST|"
$RoleSequence = @("producer", "consumer", "validator")
$ProcessSequence = @(
    "producer_exit",
    "consumer_start",
    "consumer_exit",
    "validator_start",
    "validator_exit",
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

function Assert-ColdRestoreCondition {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$FailureCode
    )
    if (-not $Condition) {
        throw $FailureCode
    }
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

function Invoke-ColdRestoreRole {
    param(
        [Parameter(Mandatory = $true)][ValidateSet("producer", "consumer", "validator")][string]$Role,
        [Parameter(Mandatory = $true)][string]$ResolvedProjectPath,
        [Parameter(Mandatory = $true)][string]$LogRoot,
        [Parameter(Mandatory = $true)][string]$HeadSha,
        [int64]$ExpectedQueueResolutionId = 0,
        [string]$ExpectedQueueStableTargetFingerprint = ""
    )
    $stdoutPath = Join-Path $LogRoot "$Role.stdout.log"
    $stderrPath = Join-Path $LogRoot "$Role.stderr.log"
    $arguments = @(
        "--headless",
        "--path", "`"$ResolvedProjectPath`"",
        "--script", $DriverScript,
        "--",
        "--cold-restore-role=$Role",
        "--cold-restore-run-id=$RunId",
        "--cold-restore-head-sha=$HeadSha",
        "--cold-restore-artifact-root=$ArtifactRoot"
    )
    if ($Role -ne "producer") {
        Assert-ColdRestoreCondition ($ExpectedQueueResolutionId -gt 0) "expected_queue_resolution_id_invalid"
        Assert-ColdRestoreCondition ($ExpectedQueueStableTargetFingerprint -match '^[0-9a-f]{64}$') "expected_queue_stable_target_fingerprint_invalid"
        $arguments += "--cold-restore-expected-queue-resolution-id=$ExpectedQueueResolutionId"
        $arguments += "--cold-restore-expected-queue-stable-target-fingerprint=$ExpectedQueueStableTargetFingerprint"
    }
    $process = Start-Process -FilePath $GodotPath -ArgumentList $arguments `
        -PassThru -Wait -WindowStyle Hidden `
        -Environment @{ APPDATA = $IsolatedAppData; LOCALAPPDATA = $IsolatedLocalAppData } `
        -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    Assert-ColdRestoreCondition ($process.ExitCode -eq 0) "${Role}_process_failed"
    $manifest = Read-ColdRestoreManifest $stdoutPath $Role $RunId
    Assert-ColdRestoreCondition ([int64]$manifest.process_id -eq [int64]$process.Id) "${Role}_manifest_process_id_mismatch"
    Assert-ColdRestoreCondition ([string]$manifest.head_sha -eq $HeadSha) "${Role}_manifest_head_sha_mismatch"
    return [pscustomobject]@{
        process_id = $process.Id
        manifest = $manifest
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
    Assert-ColdRestoreCondition (-not ($EnableColdRestoreExecution -and $ContractManifestPath -ne "")) "execution_mode_conflict"

    if ($ContractManifestPath -ne "") {
        $fixture = Read-ContractManifestFixture $ContractManifestPath
        $comparison = Compare-ColdRestoreManifests $fixture.producer $fixture.consumer $fixture.validator
        Write-AllowlistedResult (New-AllowlistedResult $false $true $true "" $comparison)
        exit 0
    }

    if (-not $EnableColdRestoreExecution) {
        Write-AllowlistedResult (New-AllowlistedResult $false $false $true "")
        exit 0
    }

    Assert-ColdRestoreCondition $DriverExecutionReady "driver_execution_not_ready"
    $resolvedProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path
    Assert-ColdRestoreCondition (Test-Path -LiteralPath (Join-Path $resolvedProjectPath "project.godot") -PathType Leaf) "godot_project_invalid"
    $logRoot = Join-Path $resolvedProjectPath ".godot\cold_restore_v3\$RunId\orchestrator-$PID"
    New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
    $headSha = [string](& git -C $resolvedProjectPath rev-parse HEAD 2>$null)
    Assert-ColdRestoreCondition ($headSha -match '^[0-9a-f]{40,64}$') "head_sha_unavailable"
    $dirtyPaths = @(& git -C $resolvedProjectPath status --porcelain=v1 2>$null)
    Assert-ColdRestoreCondition ($dirtyPaths.Count -eq 0) "worktree_not_clean"
    New-Item -ItemType Directory -Path $IsolatedAppData -Force | Out-Null
    New-Item -ItemType Directory -Path $IsolatedLocalAppData -Force | Out-Null

    $producerRun = Invoke-ColdRestoreRole "producer" $resolvedProjectPath $logRoot $headSha
    # Process B starts only after Process A exited and its one safe manifest parsed.
    $consumerRun = Invoke-ColdRestoreRole "consumer" $resolvedProjectPath $logRoot $headSha `
        ([int64]$producerRun.manifest.queue_trigger_resolution_id) `
        ([string]$producerRun.manifest.queue_trigger_stable_target_fingerprint)
    # Process C starts only after Process B exited and its one safe manifest parsed.
    $validatorRun = Invoke-ColdRestoreRole "validator" $resolvedProjectPath $logRoot $headSha `
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
    Write-AllowlistedResult (New-AllowlistedResult ([bool]$EnableColdRestoreExecution) ($ContractManifestPath -ne "") $false $safeFailureCode)
    exit 1
}
