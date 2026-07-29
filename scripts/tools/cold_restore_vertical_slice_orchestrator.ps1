[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,
    [string]$GodotPath = "godot",
    [string]$RunId = "alpha04c-cold-restore",
    [switch]$EnableColdRestoreExecution,
    [string]$ContractManifestPath = "",
    [switch]$ContractCleanupProbe,
    [ValidateRange(30, 300)]
    [int]$RoleTimeoutSeconds = 300
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ORCHESTRATOR_SCHEMA_VERSION = 4
$FORMAL_FULL_RUN = $false
$DriverExecutionReady = $false
$DriverScript = "res://scripts/tools/cold_restore_vertical_slice_driver.gd"
$ArtifactRoot = "user://test_runs/alpha04c/$RunId/evidence"
$OfficialClaimSchemaVersion = 2
$LaunchAttestationSchemaVersion = 1
$OfficialAuthorizationId = "alpha04c-p0-cold-restore-depth1-seed900626424-v1"
$OfficialChallengeDepth = 1
$OfficialSeed = 900626424
$OfficialClaimRelativeDirectory = "codex\cold_restore_v3\official-alpha04c-depth1-seed900626424"
$OfficialClaimLedgerFileName = "official_claim_ledger.json"
$OfficialClaimFields = @(
    "schema_version",
    "authorization_id",
    "created_at_utc",
    "source_head_sha",
    "challenge_depth",
    "seed",
    "status",
    "claim_nonce",
    "orchestrator_process_id",
    "orchestrator_creation_time_utc_ticks"
)
$LaunchAttestationFields = @(
    "schema_version",
    "authorization_id",
    "claim_fingerprint",
    "claim_nonce",
    "source_head_sha",
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
    "parent_process_id",
    "process_creation_time_utc_ticks",
    "wrapper_process_id",
    "wrapper_parent_process_id",
    "wrapper_creation_time_utc_ticks",
    "orchestrator_process_id",
    "orchestrator_creation_time_utc_ticks",
    "launch_nonce",
    "official_claim_fingerprint",
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
    "parent_process_id",
    "wrapper_process_id",
    "wrapper_parent_process_id",
    "orchestrator_process_id",
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
    foreach ($field in @(
        "process_creation_time_utc_ticks",
        "wrapper_creation_time_utc_ticks",
        "orchestrator_creation_time_utc_ticks"
    )) {
        Assert-ColdRestoreCondition ([string]$Manifest.$field -match '^[1-9][0-9]{0,18}$') "manifest_creation_time_invalid"
    }
    Assert-ColdRestoreCondition ([string]$Manifest.launch_nonce -match '^[0-9a-f]{32}$') "manifest_launch_nonce_invalid"
    Assert-ColdRestoreCondition ([string]$Manifest.official_claim_fingerprint -match '^[0-9a-f]{64}$') "manifest_claim_fingerprint_invalid"
    Assert-ColdRestoreCondition ([int64]$Manifest.wrapper_parent_process_id -eq [int64]$Manifest.orchestrator_process_id) "manifest_wrapper_parent_invalid"
    if ([int64]$Manifest.wrapper_process_id -eq [int64]$Manifest.process_id) {
        Assert-ColdRestoreCondition (
            [int64]$Manifest.parent_process_id -eq [int64]$Manifest.orchestrator_process_id `
                -and [string]$Manifest.process_creation_time_utc_ticks -eq [string]$Manifest.wrapper_creation_time_utc_ticks
        ) "manifest_single_process_binding_invalid"
    }
    else {
        Assert-ColdRestoreCondition ([int64]$Manifest.parent_process_id -eq [int64]$Manifest.wrapper_process_id) "manifest_engine_parent_invalid"
    }
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

function Resolve-OfficialClaimDirectory {
    param([Parameter(Mandatory = $true)][string]$ResolvedProjectPath)
    $commonDirectoryLines = @(
        & git -C $ResolvedProjectPath rev-parse --path-format=absolute --git-common-dir 2>$null
    )
    $gitExitCode = $LASTEXITCODE
    Assert-ColdRestoreCondition ($gitExitCode -eq 0 -and $commonDirectoryLines.Count -eq 1) "git_common_dir_unavailable"
    $commonDirectory = [string]$commonDirectoryLines[0]
    Assert-ColdRestoreCondition ([IO.Path]::IsPathRooted($commonDirectory)) "git_common_dir_not_absolute"
    $resolvedCommonDirectory = [IO.Path]::GetFullPath($commonDirectory)
    Assert-ColdRestoreCondition (Test-Path -LiteralPath $resolvedCommonDirectory -PathType Container) "git_common_dir_invalid"
    return Join-Path $resolvedCommonDirectory $OfficialClaimRelativeDirectory
}

function New-OfficialClaimLedger {
    param(
        [Parameter(Mandatory = $true)][string]$EvidenceDirectory,
        [Parameter(Mandatory = $true)][string]$HeadSha,
        [Parameter(Mandatory = $true)]$OrchestratorRecord,
        [Parameter(Mandatory = $true)][string]$ClaimNonce
    )
    Assert-ColdRestoreCondition ($HeadSha -match '^[0-9a-f]{40,64}$') "official_claim_head_sha_invalid"
    Assert-ColdRestoreCondition ($ClaimNonce -match '^[0-9a-f]{32}$') "official_claim_nonce_invalid"
    New-Item -ItemType Directory -Path $EvidenceDirectory -Force | Out-Null
    $ledgerPath = Join-Path $EvidenceDirectory $OfficialClaimLedgerFileName
    $claim = [ordered]@{
        schema_version = $OfficialClaimSchemaVersion
        authorization_id = $OfficialAuthorizationId
        created_at_utc = [DateTimeOffset]::UtcNow.ToString("o", [Globalization.CultureInfo]::InvariantCulture)
        source_head_sha = $HeadSha
        challenge_depth = $OfficialChallengeDepth
        seed = $OfficialSeed
        status = "claimed"
        claim_nonce = $ClaimNonce
        orchestrator_process_id = [int64]$OrchestratorRecord.process_id
        orchestrator_creation_time_utc_ticks = ([int64]$OrchestratorRecord.creation_time_utc_ticks).ToString([Globalization.CultureInfo]::InvariantCulture)
    }
    Assert-ColdRestoreCondition (Test-ExactFieldSet ([pscustomobject]$claim) $OfficialClaimFields) "official_claim_field_set_invalid"
    $json = $claim | ConvertTo-Json -Compress -Depth 2
    $stream = $null
    $writer = $null
    try {
        try {
            $stream = [System.IO.FileStream]::new(
                $ledgerPath,
                [System.IO.FileMode]::CreateNew,
                [System.IO.FileAccess]::Write,
                [System.IO.FileShare]::None
            )
        }
        catch [System.IO.IOException] {
            if ([System.IO.File]::Exists($ledgerPath)) {
                throw "official_claim_already_exists"
            }
            throw "official_claim_create_failed"
        }
        $writer = [System.IO.StreamWriter]::new(
            $stream,
            [System.Text.UTF8Encoding]::new($false),
            1024,
            $true
        )
        $writer.Write($json)
        $writer.Flush()
        $stream.Flush($true)
    }
    finally {
        if ($null -ne $writer) {
            $writer.Dispose()
        }
        if ($null -ne $stream) {
            $stream.Dispose()
        }
    }
    return $ledgerPath
}

function Resolve-ColdRestoreExecutablePath {
    param([Parameter(Mandatory = $true)][string]$ExecutablePath)
    if (Test-Path -LiteralPath $ExecutablePath -PathType Leaf) {
        return (Resolve-Path -LiteralPath $ExecutablePath).Path
    }
    $command = Get-Command $ExecutablePath -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    Assert-ColdRestoreCondition ($null -ne $command -and -not [string]::IsNullOrWhiteSpace([string]$command.Source)) "godot_executable_unavailable"
    return [IO.Path]::GetFullPath([string]$command.Source)
}

function Get-ColdRestoreEngineExecutablePath {
    param([Parameter(Mandatory = $true)][string]$WrapperExecutablePath)
    $resolvedWrapperPath = [IO.Path]::GetFullPath($WrapperExecutablePath)
    $fileName = [IO.Path]::GetFileName($resolvedWrapperPath)
    if ($fileName -match '(?i)_console\.exe$') {
        $engineFileName = $fileName -replace '(?i)_console(?=\.exe$)', ''
        return Join-Path ([IO.Path]::GetDirectoryName($resolvedWrapperPath)) $engineFileName
    }
    return $resolvedWrapperPath
}

function ConvertTo-ColdRestoreProcessRecord {
    param([Parameter(Mandatory = $true)]$ProcessInfo)
    $executablePath = [string]$ProcessInfo.ExecutablePath
    $commandLine = [string]$ProcessInfo.CommandLine
    Assert-ColdRestoreCondition (-not [string]::IsNullOrWhiteSpace($executablePath)) "process_executable_path_unavailable"
    Assert-ColdRestoreCondition (-not [string]::IsNullOrWhiteSpace($commandLine)) "process_command_line_unavailable"
    $cimCreationTime = ([DateTime]$ProcessInfo.CreationDate).ToUniversalTime().Ticks
    try {
        $boundProcess = [System.Diagnostics.Process]::GetProcessById([int]$ProcessInfo.ProcessId)
        $creationTime = $boundProcess.StartTime.ToUniversalTime().Ticks
    }
    catch {
        throw "process_identity_unavailable"
    }
    Assert-ColdRestoreCondition ([Math]::Abs([int64]$creationTime - [int64]$cimCreationTime) `
        -le [TimeSpan]::TicksPerSecond) "process_creation_time_disagreement"
    return [pscustomobject]@{
        process_id = [int64]$ProcessInfo.ProcessId
        parent_process_id = [int64]$ProcessInfo.ParentProcessId
        executable_path = [IO.Path]::GetFullPath($executablePath)
        command_line = $commandLine
        creation_time_utc_ticks = [int64]$creationTime
    }
}

function Get-ColdRestoreProcessRecord {
    param([Parameter(Mandatory = $true)][int64]$ProcessId)
    $rows = @(
        Get-CimInstance -ClassName Win32_Process -Filter ("ProcessId = {0}" -f $ProcessId) `
            -ErrorAction SilentlyContinue
    )
    if ($rows.Count -eq 0) {
        return $null
    }
    Assert-ColdRestoreCondition ($rows.Count -eq 1) "process_identity_ambiguous"
    return ConvertTo-ColdRestoreProcessRecord $rows[0]
}

function Get-ColdRestoreChildProcessRecords {
    param([Parameter(Mandatory = $true)][int64]$ParentProcessId)
    $records = @()
    foreach ($row in @(
        Get-CimInstance -ClassName Win32_Process -Filter ("ParentProcessId = {0}" -f $ParentProcessId) `
            -ErrorAction SilentlyContinue
    )) {
        $records += ConvertTo-ColdRestoreProcessRecord $row
    }
    return @($records)
}

function Test-ColdRestorePathBinding {
    param(
        [Parameter(Mandatory = $true)][string]$ActualPath,
        [Parameter(Mandatory = $true)][string]$ExpectedPath
    )
    return [string]::Equals(
        [IO.Path]::GetFullPath($ActualPath),
        [IO.Path]::GetFullPath($ExpectedPath),
        [System.StringComparison]::OrdinalIgnoreCase
    )
}

function Test-ColdRestoreCommandLineBinding {
    param(
        [Parameter(Mandatory = $true)][string]$CommandLine,
        [Parameter(Mandatory = $true)][string]$ExpectedExecutablePath,
        [Parameter(Mandatory = $true)][string]$ExpectedArgumentLine
    )
    if ([string]::IsNullOrWhiteSpace($CommandLine) `
            -or [string]::IsNullOrWhiteSpace($ExpectedArgumentLine)) {
        return $false
    }

    $resolvedExecutablePath = [IO.Path]::GetFullPath($ExpectedExecutablePath)
    foreach ($executablePrefix in @(
        ('"{0}" ' -f $resolvedExecutablePath),
        ('{0} ' -f $resolvedExecutablePath)
    )) {
        if ($CommandLine.StartsWith($executablePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            $actualArgumentLine = $CommandLine.Substring($executablePrefix.Length)
            return [string]::Equals(
                $actualArgumentLine,
                $ExpectedArgumentLine,
                [System.StringComparison]::Ordinal
            )
        }
    }
    return $false
}

function Test-ColdRestoreProcessRecordBinding {
    param(
        [Parameter(Mandatory = $true)]$Record,
        [Parameter(Mandatory = $true)][int64]$ExpectedParentProcessId,
        [Parameter(Mandatory = $true)][string]$ExpectedExecutablePath,
        [Parameter(Mandatory = $true)][string]$ExpectedArgumentLine
    )
    return [int64]$Record.parent_process_id -eq $ExpectedParentProcessId `
        -and (Test-ColdRestorePathBinding ([string]$Record.executable_path) $ExpectedExecutablePath) `
        -and (Test-ColdRestoreCommandLineBinding ([string]$Record.command_line) `
            $ExpectedExecutablePath $ExpectedArgumentLine)
}

function Wait-ColdRestoreProcessRecord {
    param(
        [Parameter(Mandatory = $true)][int64]$ProcessId,
        [ValidateRange(100, 10000)][int]$TimeoutMilliseconds = 5000
    )
    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        $record = Get-ColdRestoreProcessRecord $ProcessId
        if ($null -ne $record) {
            return $record
        }
        Start-Sleep -Milliseconds 25
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "process_identity_unavailable"
}

function Get-ColdRestoreFileSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    Assert-ColdRestoreCondition (Test-Path -LiteralPath $Path -PathType Leaf) "attested_file_missing"
    $stream = $null
    $sha256 = $null
    try {
        $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        return ([System.BitConverter]::ToString($sha256.ComputeHash($stream))).Replace("-", "").ToLowerInvariant()
    }
    finally {
        if ($null -ne $sha256) {
            $sha256.Dispose()
        }
        if ($null -ne $stream) {
            $stream.Dispose()
        }
    }
}

function Invoke-ColdRestoreExecutionPreflight {
    param(
        [Parameter(Mandatory = $true)][string]$RequestedProjectPath,
        [Parameter(Mandatory = $true)][string]$RequestedGodotPath
    )
    $resolvedProjectPath = (Resolve-Path -LiteralPath $RequestedProjectPath).Path
    Assert-ColdRestoreCondition (Test-Path -LiteralPath (Join-Path $resolvedProjectPath "project.godot") -PathType Leaf) "godot_project_invalid"
    $resolvedGodotPath = Resolve-ColdRestoreExecutablePath $RequestedGodotPath
    $resolvedEnginePath = Get-ColdRestoreEngineExecutablePath $resolvedGodotPath
    Assert-ColdRestoreCondition (Test-Path -LiteralPath $resolvedEnginePath -PathType Leaf) "godot_engine_executable_unavailable"

    $startProcessCommand = Get-Command Start-Process -CommandType Cmdlet -ErrorAction SilentlyContinue
    Assert-ColdRestoreCondition ($null -ne $startProcessCommand `
        -and $startProcessCommand.Parameters.ContainsKey("Environment") `
        -and $startProcessCommand.Parameters.ContainsKey("RedirectStandardOutput") `
        -and $startProcessCommand.Parameters.ContainsKey("RedirectStandardError") `
        -and $startProcessCommand.Parameters.ContainsKey("PassThru")) "process_launch_environment_unsupported"
    $cimCommand = Get-Command Get-CimInstance -CommandType Cmdlet -ErrorAction SilentlyContinue
    Assert-ColdRestoreCondition ($null -ne $cimCommand) "cim_process_query_unavailable"
    $orchestratorRecord = Wait-ColdRestoreProcessRecord ([int64]$PID)
    Assert-ColdRestoreCondition ([int64]$orchestratorRecord.process_id -eq [int64]$PID `
        -and [int64]$orchestratorRecord.parent_process_id -gt 0 `
        -and [int64]$orchestratorRecord.creation_time_utc_ticks -gt 0) "orchestrator_process_identity_invalid"

    $headLines = @(& git -C $resolvedProjectPath rev-parse HEAD 2>$null)
    $headExitCode = $LASTEXITCODE
    Assert-ColdRestoreCondition ($headExitCode -eq 0 -and $headLines.Count -eq 1) "head_sha_unavailable"
    $headSha = [string]$headLines[0]
    Assert-ColdRestoreCondition ($headSha -match '^[0-9a-f]{40,64}$') "head_sha_unavailable"
    $dirtyPaths = @(& git -C $resolvedProjectPath status --porcelain=v1 2>$null)
    $statusExitCode = $LASTEXITCODE
    Assert-ColdRestoreCondition ($statusExitCode -eq 0) "git_status_unavailable"
    Assert-ColdRestoreCondition ($dirtyPaths.Count -eq 0) "worktree_not_clean"

    $logRoot = Join-Path $resolvedProjectPath ".godot\cold_restore_v3\$RunId\orchestrator-$PID"
    foreach ($directory in @($logRoot, $IsolatedAppData, $IsolatedLocalAppData)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
        Assert-ColdRestoreCondition (Test-Path -LiteralPath $directory -PathType Container) "process_environment_directory_unavailable"
    }
    Invoke-ColdRestoreDriverContractPreflight $resolvedProjectPath $resolvedGodotPath $logRoot
    $officialClaimDirectory = Resolve-OfficialClaimDirectory $resolvedProjectPath
    $officialClaimLedgerPath = Join-Path $officialClaimDirectory $OfficialClaimLedgerFileName
    Assert-ColdRestoreCondition (-not [System.IO.File]::Exists($officialClaimLedgerPath)) "official_claim_already_exists"
    return [pscustomobject]@{
        resolved_project_path = $resolvedProjectPath
        resolved_godot_path = $resolvedGodotPath
        resolved_engine_path = $resolvedEnginePath
        orchestrator_record = $orchestratorRecord
        head_sha = $headSha
        log_root = $logRoot
        official_claim_directory = $officialClaimDirectory
        official_claim_ledger_path = $officialClaimLedgerPath
    }
}

function Resolve-ColdRestoreOwnedProcessTree {
    param(
        [Parameter(Mandatory = $true)][System.Diagnostics.Process]$Wrapper,
        [Parameter(Mandatory = $true)][string]$WrapperExecutablePath,
        [Parameter(Mandatory = $true)][string]$ExpectedArgumentLine
    )
    $wrapperRecord = Wait-ColdRestoreProcessRecord ([int64]$Wrapper.Id)
    Assert-ColdRestoreCondition (
        [int64]$wrapperRecord.parent_process_id -eq [int64]$PID `
        -and (Test-ColdRestorePathBinding ([string]$wrapperRecord.executable_path) $WrapperExecutablePath) `
        -and (Test-ColdRestoreCommandLineBinding ([string]$wrapperRecord.command_line) `
            $WrapperExecutablePath $ExpectedArgumentLine)
    ) "wrapper_process_binding_invalid"

    $engineExecutablePath = Get-ColdRestoreEngineExecutablePath $WrapperExecutablePath
    if (Test-ColdRestorePathBinding $engineExecutablePath $WrapperExecutablePath) {
        return [pscustomobject]@{
            wrapper_process = $Wrapper
            wrapper_record = $wrapperRecord
            wrapper_process_id = [int64]$Wrapper.Id
            engine_process = $Wrapper
            engine_record = $wrapperRecord
            engine_process_id = [int64]$Wrapper.Id
        }
    }

    $deadline = [DateTime]::UtcNow.AddSeconds(10)
    do {
        $matchingChildren = @(
            Get-ColdRestoreChildProcessRecords ([int64]$Wrapper.Id) |
                Where-Object {
                    Test-ColdRestoreProcessRecordBinding $_ ([int64]$Wrapper.Id) `
                        $engineExecutablePath $ExpectedArgumentLine
                }
        )
        Assert-ColdRestoreCondition ($matchingChildren.Count -le 1) "engine_process_binding_ambiguous"
        if ($matchingChildren.Count -eq 1) {
            $engineRecord = $matchingChildren[0]
            try {
                $engineProcess = [System.Diagnostics.Process]::GetProcessById([int]$engineRecord.process_id)
            }
            catch {
                throw "engine_process_exited_before_ownership_capture"
            }
            return [pscustomobject]@{
                wrapper_process = $Wrapper
                wrapper_record = $wrapperRecord
                wrapper_process_id = [int64]$Wrapper.Id
                engine_process = $engineProcess
                engine_record = $engineRecord
                engine_process_id = [int64]$engineRecord.process_id
            }
        }
        Start-Sleep -Milliseconds 25
    } while ([DateTime]::UtcNow -lt $deadline -and -not $Wrapper.HasExited)
    throw "engine_process_binding_unavailable"
}

function Write-ColdRestoreLaunchAttestation {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][ValidateSet("producer", "consumer", "validator")][string]$Role,
        [Parameter(Mandatory = $true)][string]$HeadSha,
        [Parameter(Mandatory = $true)][string]$LaunchNonce,
        [Parameter(Mandatory = $true)][string]$ClaimFingerprint,
        [Parameter(Mandatory = $true)][string]$ClaimNonce,
        [Parameter(Mandatory = $true)]$OrchestratorRecord,
        [Parameter(Mandatory = $true)]$Ownership
    )
    Assert-ColdRestoreCondition ($LaunchNonce -match '^[0-9a-f]{32}$') "launch_nonce_invalid"
    Assert-ColdRestoreCondition ($ClaimFingerprint -match '^[0-9a-f]{64}$') "official_claim_fingerprint_invalid"
    $attestation = [ordered]@{
        schema_version = $LaunchAttestationSchemaVersion
        authorization_id = $OfficialAuthorizationId
        claim_fingerprint = $ClaimFingerprint
        claim_nonce = $ClaimNonce
        source_head_sha = $HeadSha
        run_id = $RunId
        process_role = $Role
        launch_nonce = $LaunchNonce
        orchestrator_process_id = [int64]$OrchestratorRecord.process_id
        orchestrator_creation_time_utc_ticks = ([int64]$OrchestratorRecord.creation_time_utc_ticks).ToString([Globalization.CultureInfo]::InvariantCulture)
        wrapper_process_id = [int64]$Ownership.wrapper_process_id
        wrapper_parent_process_id = [int64]$Ownership.wrapper_record.parent_process_id
        wrapper_creation_time_utc_ticks = ([int64]$Ownership.wrapper_record.creation_time_utc_ticks).ToString([Globalization.CultureInfo]::InvariantCulture)
        engine_process_id = [int64]$Ownership.engine_process_id
        engine_parent_process_id = [int64]$Ownership.engine_record.parent_process_id
        engine_creation_time_utc_ticks = ([int64]$Ownership.engine_record.creation_time_utc_ticks).ToString([Globalization.CultureInfo]::InvariantCulture)
        status = "authorized"
    }
    Assert-ColdRestoreCondition (Test-ExactFieldSet ([pscustomobject]$attestation) $LaunchAttestationFields) "launch_attestation_field_set_invalid"
    Assert-ColdRestoreCondition (-not [System.IO.File]::Exists($Path)) "launch_attestation_already_exists"
    $pendingPath = "$Path.pending-$LaunchNonce"
    Assert-ColdRestoreCondition (-not [System.IO.File]::Exists($pendingPath)) "launch_attestation_pending_exists"
    $json = $attestation | ConvertTo-Json -Compress -Depth 2
    $stream = $null
    $writer = $null
    try {
        $stream = [System.IO.FileStream]::new(
            $pendingPath,
            [System.IO.FileMode]::CreateNew,
            [System.IO.FileAccess]::Write,
            [System.IO.FileShare]::None
        )
        $writer = [System.IO.StreamWriter]::new(
            $stream,
            [System.Text.UTF8Encoding]::new($false),
            1024,
            $true
        )
        $writer.Write($json)
        $writer.Flush()
        $stream.Flush($true)
    }
    finally {
        if ($null -ne $writer) {
            $writer.Dispose()
        }
        if ($null -ne $stream) {
            $stream.Dispose()
        }
    }
    [System.IO.File]::Move($pendingPath, $Path)
    Assert-ColdRestoreCondition ([System.IO.File]::Exists($Path)) "launch_attestation_publish_failed"
}

function Test-ColdRestoreProcessRecordCurrent {
    param([Parameter(Mandatory = $true)]$Record)
    $current = Get-ColdRestoreProcessRecord ([int64]$Record.process_id)
    if ($null -eq $current) {
        return $false
    }
    return [int64]$current.parent_process_id -eq [int64]$Record.parent_process_id `
        -and [int64]$current.creation_time_utc_ticks -eq [int64]$Record.creation_time_utc_ticks `
        -and (Test-ColdRestorePathBinding ([string]$current.executable_path) ([string]$Record.executable_path))
}

function Stop-ColdRestoreOwnedProcessRecord {
    param(
        [Parameter(Mandatory = $true)]$Record,
        [System.Diagnostics.Process]$Process = $null
    )
    if (-not (Test-ColdRestoreProcessRecordCurrent $Record)) {
        return $true
    }
    $boundProcess = $Process
    try {
        if ($null -eq $boundProcess) {
            $boundProcess = [System.Diagnostics.Process]::GetProcessById([int]$Record.process_id)
        }
        $boundStartTicks = $boundProcess.StartTime.ToUniversalTime().Ticks
        if ([int64]$boundProcess.Id -ne [int64]$Record.process_id `
                -or [int64]$boundStartTicks -ne [int64]$Record.creation_time_utc_ticks) {
            return $false
        }
        $boundProcess.Kill()
        [void]$boundProcess.WaitForExit(5000)
    }
    catch {
        # A later identity check decides whether this was an already-exited process or a cleanup failure.
    }
    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    while ((Test-ColdRestoreProcessRecordCurrent $Record) -and [DateTime]::UtcNow -lt $deadline) {
        Start-Sleep -Milliseconds 25
    }
    return -not (Test-ColdRestoreProcessRecordCurrent $Record)
}

function Stop-ColdRestoreOwnedProcessTree {
    param([Parameter(Mandatory = $true)]$Ownership)
    $records = @()
    if ([int64]$Ownership.engine_process_id -ne [int64]$Ownership.wrapper_process_id) {
        $records += [pscustomobject]@{ record = $Ownership.engine_record; process = $Ownership.engine_process }
    }
    $records += [pscustomobject]@{ record = $Ownership.wrapper_record; process = $Ownership.wrapper_process }
    foreach ($entry in $records) {
        try {
            [void](Stop-ColdRestoreOwnedProcessRecord $entry.record $entry.process)
        }
        catch {
            # Continue so one failed leg cannot prevent cleanup of the other owned process.
        }
    }
    $residualCount = 0
    foreach ($entry in $records) {
        try {
            if (Test-ColdRestoreProcessRecordCurrent $entry.record) {
                $residualCount += 1
            }
        }
        catch {
            $residualCount += 1
        }
    }
    Assert-ColdRestoreCondition ($residualCount -eq 0) "task_owned_process_cleanup_failed"
}

function Stop-ColdRestoreLaunchedProcessTree {
    param(
        [Parameter(Mandatory = $true)][System.Diagnostics.Process]$Wrapper,
        [Parameter(Mandatory = $true)][string]$WrapperExecutablePath,
        [Parameter(Mandatory = $true)][string]$ExpectedArgumentLine
)
    $engineExecutablePath = Get-ColdRestoreEngineExecutablePath $WrapperExecutablePath
    $records = @()
    foreach ($childRecord in Get-ColdRestoreChildProcessRecords ([int64]$Wrapper.Id)) {
        if (Test-ColdRestoreProcessRecordBinding $childRecord ([int64]$Wrapper.Id) `
                $engineExecutablePath $ExpectedArgumentLine) {
            $records += [pscustomobject]@{ record = $childRecord; process = $null }
        }
    }
    $wrapperRecord = Get-ColdRestoreProcessRecord ([int64]$Wrapper.Id)
    $wrapperBound = $false
    if ($null -ne $wrapperRecord `
            -and [int64]$wrapperRecord.parent_process_id -eq [int64]$PID `
            -and (Test-ColdRestorePathBinding ([string]$wrapperRecord.executable_path) $WrapperExecutablePath) `
            -and (Test-ColdRestoreCommandLineBinding ([string]$wrapperRecord.command_line) `
                $WrapperExecutablePath $ExpectedArgumentLine)) {
        $records += [pscustomobject]@{ record = $wrapperRecord; process = $Wrapper }
        $wrapperBound = $true
    }
    foreach ($entry in $records) {
        try {
            [void](Stop-ColdRestoreOwnedProcessRecord $entry.record $entry.process)
        }
        catch {
            # Best effort continues across all records captured for this exact launch.
        }
    }
    $residualCount = 0
    foreach ($entry in $records) {
        try {
            if (Test-ColdRestoreProcessRecordCurrent $entry.record) {
                $residualCount += 1
            }
        }
        catch {
            $residualCount += 1
        }
    }
    if (-not $wrapperBound) {
        try {
            if (-not $Wrapper.HasExited) {
                $residualCount += 1
            }
        }
        catch {
            $residualCount += 1
        }
    }
    foreach ($childRecord in Get-ColdRestoreChildProcessRecords ([int64]$Wrapper.Id)) {
        if (Test-ColdRestoreProcessRecordBinding $childRecord ([int64]$Wrapper.Id) `
                $engineExecutablePath $ExpectedArgumentLine) {
            $residualCount += 1
        }
    }
    Assert-ColdRestoreCondition ($residualCount -eq 0) "task_owned_process_cleanup_failed"
}

function Invoke-ColdRestoreDriverContractPreflight {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedProjectPath,
        [Parameter(Mandatory = $true)][string]$ResolvedGodotPath,
        [Parameter(Mandatory = $true)][string]$LogRoot
    )
    $stdoutPath = Join-Path $LogRoot "driver-contract-preflight.stdout.log"
    $stderrPath = Join-Path $LogRoot "driver-contract-preflight.stderr.log"
    $arguments = @(
        "--headless",
        "--path", "`"$ResolvedProjectPath`"",
        "--script", $DriverScript,
        "--",
        "--cold-restore-contract-only"
    )
    $argumentLine = $arguments -join " "
    $process = $null
    $ownership = $null
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $process = Start-Process -FilePath $ResolvedGodotPath -ArgumentList $argumentLine `
            -PassThru -WindowStyle Hidden `
            -Environment @{ APPDATA = $IsolatedAppData; LOCALAPPDATA = $IsolatedLocalAppData } `
            -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
        $ownership = Resolve-ColdRestoreOwnedProcessTree $process $ResolvedGodotPath $argumentLine
        $remainingMilliseconds = [Math]::Max([int64]0, 30000 - $stopwatch.ElapsedMilliseconds)
        Assert-ColdRestoreCondition ($ownership.engine_process.WaitForExit([int]$remainingMilliseconds)) "driver_contract_preflight_timeout"
        $ownership.engine_process.WaitForExit()
        if ([int64]$ownership.wrapper_process_id -ne [int64]$ownership.engine_process_id) {
            $remainingMilliseconds = [Math]::Max([int64]0, 30000 - $stopwatch.ElapsedMilliseconds)
            Assert-ColdRestoreCondition ($ownership.wrapper_process.WaitForExit([int]$remainingMilliseconds)) "driver_contract_preflight_timeout"
            $ownership.wrapper_process.WaitForExit()
        }
    }
    catch {
        $failureCode = [string]$_.Exception.Message
        if ($null -ne $ownership) {
            try {
                Stop-ColdRestoreOwnedProcessTree $ownership
            }
            catch {
                throw "task_owned_process_cleanup_failed"
            }
        }
        elseif ($null -ne $process) {
            try {
                Stop-ColdRestoreLaunchedProcessTree $process $ResolvedGodotPath $argumentLine
            }
            catch {
                throw "task_owned_process_cleanup_failed"
            }
        }
        throw $failureCode
    }
    finally {
        $stopwatch.Stop()
    }
    Assert-ColdRestoreCondition ($ownership.engine_process.ExitCode -eq 0 `
        -and $ownership.wrapper_process.ExitCode -eq 0) "driver_contract_preflight_process_failed"
    Assert-ColdRestoreCondition (-not (Test-ColdRestoreProcessRecordCurrent $ownership.engine_record) `
        -and -not (Test-ColdRestoreProcessRecordCurrent $ownership.wrapper_record)) "task_owned_process_residual"
    $contractLines = @(
        Get-Content -LiteralPath $stdoutPath -Encoding UTF8 |
            Where-Object { $_.StartsWith("{", [System.StringComparison]::Ordinal) }
    )
    Assert-ColdRestoreCondition ($contractLines.Count -eq 1) "driver_contract_preflight_output_invalid"
    try {
        $contract = $contractLines[0] | ConvertFrom-Json
    }
    catch {
        throw "driver_contract_preflight_output_invalid"
    }
    Assert-ColdRestoreCondition ([int]$contract.schema_version -eq $ORCHESTRATOR_SCHEMA_VERSION `
        -and [string]$contract.driver_id -eq "alpha04c_cold_restore_vertical_slice_v4" `
        -and [bool]$contract.official_ledger_required `
        -and [bool]$contract.launch_attestation_required) "driver_contract_preflight_contract_mismatch"
}

function Start-ColdRestoreCleanupProbeProcess {
    $orchestratorRecord = Wait-ColdRestoreProcessRecord ([int64]$PID)
    $argumentLine = '-NoProfile -Command "Start-Sleep -Seconds 30"'
    $process = Start-Process -FilePath ([string]$orchestratorRecord.executable_path) `
        -ArgumentList $argumentLine -PassThru -WindowStyle Hidden
    $record = Wait-ColdRestoreProcessRecord ([int64]$process.Id)
    Assert-ColdRestoreCondition ([int64]$record.parent_process_id -eq [int64]$PID `
        -and (Test-ColdRestorePathBinding ([string]$record.executable_path) ([string]$orchestratorRecord.executable_path))) "cleanup_probe_process_binding_invalid"
    return [pscustomobject]@{ process = $process; record = $record }
}

function Invoke-ColdRestoreCleanupContractProbe {
    $wrapper = $null
    $engine = $null
    try {
        $wrapper = Start-ColdRestoreCleanupProbeProcess
        $engine = Start-ColdRestoreCleanupProbeProcess
        Assert-ColdRestoreCondition ([int64]$wrapper.record.process_id -ne [int64]$engine.record.process_id) "cleanup_probe_pid_collision"
        $ownership = [pscustomobject]@{
            wrapper_process = $wrapper.process
            wrapper_record = $wrapper.record
            wrapper_process_id = [int64]$wrapper.record.process_id
            engine_process = $wrapper.process
            engine_record = $engine.record
            engine_process_id = [int64]$engine.record.process_id
        }
        $failureCode = ""
        try {
            Stop-ColdRestoreOwnedProcessTree $ownership
        }
        catch {
            $failureCode = [string]$_.Exception.Message
        }
        Assert-ColdRestoreCondition ($failureCode -eq "task_owned_process_cleanup_failed") "cleanup_probe_residual_not_reported"
        Assert-ColdRestoreCondition (-not (Test-ColdRestoreProcessRecordCurrent $wrapper.record)) "cleanup_probe_wrapper_not_stopped"
        Assert-ColdRestoreCondition (Test-ColdRestoreProcessRecordCurrent $engine.record) "cleanup_probe_engine_residual_missing"
        Assert-ColdRestoreCondition (Stop-ColdRestoreOwnedProcessRecord $engine.record $engine.process) "cleanup_probe_engine_final_cleanup_failed"
        Assert-ColdRestoreCondition (-not (Test-ColdRestoreProcessRecordCurrent $engine.record)) "cleanup_probe_engine_still_running"
        return [ordered]@{
            schema_version = 1
            probe_id = "cold_restore_owned_process_cleanup"
            engine_failure_injected = $true
            wrapper_cleanup_continued = $true
            residual_failure_reported = $true
            final_owned_process_count = 0
            success = $true
            failure_code = ""
        }
    }
    finally {
        foreach ($entry in @($engine, $wrapper)) {
            if ($null -eq $entry) {
                continue
            }
            try {
                [void](Stop-ColdRestoreOwnedProcessRecord $entry.record $entry.process)
            }
            catch {
                # The probe result already fails if either exact owned process remains.
            }
        }
    }
}

function Invoke-ColdRestoreRole {
    param(
        [Parameter(Mandatory = $true)][ValidateSet("producer", "consumer", "validator")][string]$Role,
        [Parameter(Mandatory = $true)][string]$ResolvedProjectPath,
        [Parameter(Mandatory = $true)][string]$ResolvedGodotPath,
        [Parameter(Mandatory = $true)][string]$LogRoot,
        [Parameter(Mandatory = $true)][string]$HeadSha,
        [Parameter(Mandatory = $true)][string]$OfficialClaimLedgerPath,
        [Parameter(Mandatory = $true)][string]$OfficialClaimFingerprint,
        [Parameter(Mandatory = $true)][string]$ClaimNonce,
        [Parameter(Mandatory = $true)]$OrchestratorRecord,
        [int64]$ExpectedQueueResolutionId = 0,
        [string]$ExpectedQueueStableTargetFingerprint = ""
    )
    $stdoutPath = Join-Path $LogRoot "$Role.stdout.log"
    $stderrPath = Join-Path $LogRoot "$Role.stderr.log"
    $launchNonce = [Guid]::NewGuid().ToString("N")
    $launchAttestationPath = Join-Path $LogRoot "$Role.launch-attestation.json"
    $arguments = @(
        "--headless",
        "--path", "`"$ResolvedProjectPath`"",
        "--script", $DriverScript,
        "--",
        "--cold-restore-role=$Role",
        "--cold-restore-run-id=$RunId",
        "--cold-restore-head-sha=$HeadSha",
        "--cold-restore-artifact-root=$ArtifactRoot",
        "--cold-restore-official-claim-path=`"$OfficialClaimLedgerPath`"",
        "--cold-restore-launch-attestation-path=`"$launchAttestationPath`"",
        "--cold-restore-launch-nonce=$launchNonce"
    )
    if ($Role -ne "producer") {
        Assert-ColdRestoreCondition ($ExpectedQueueResolutionId -gt 0) "expected_queue_resolution_id_invalid"
        Assert-ColdRestoreCondition ($ExpectedQueueStableTargetFingerprint -match '^[0-9a-f]{64}$') "expected_queue_stable_target_fingerprint_invalid"
        $arguments += "--cold-restore-expected-queue-resolution-id=$ExpectedQueueResolutionId"
        $arguments += "--cold-restore-expected-queue-stable-target-fingerprint=$ExpectedQueueStableTargetFingerprint"
    }
    $argumentLine = $arguments -join " "
    $process = $null
    $ownership = $null
    $roleStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $process = Start-Process -FilePath $resolvedGodotPath -ArgumentList $argumentLine `
            -PassThru -WindowStyle Hidden `
            -Environment @{ APPDATA = $IsolatedAppData; LOCALAPPDATA = $IsolatedLocalAppData } `
            -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
        $ownership = Resolve-ColdRestoreOwnedProcessTree $process $resolvedGodotPath $argumentLine
        Write-ColdRestoreLaunchAttestation $launchAttestationPath $Role $HeadSha $launchNonce `
            $OfficialClaimFingerprint $ClaimNonce $OrchestratorRecord $ownership

        $remainingTimeoutMilliseconds = [Math]::Max(
            [int64]0,
            ([int64]$RoleTimeoutSeconds * 1000) - $roleStopwatch.ElapsedMilliseconds
        )
        if (-not $ownership.engine_process.WaitForExit([int]$remainingTimeoutMilliseconds)) {
            throw "${Role}_process_timeout"
        }
        $ownership.engine_process.WaitForExit()

        if ([int64]$ownership.wrapper_process_id -ne [int64]$ownership.engine_process_id) {
            $remainingTimeoutMilliseconds = [Math]::Max(
                [int64]0,
                ([int64]$RoleTimeoutSeconds * 1000) - $roleStopwatch.ElapsedMilliseconds
            )
            if (-not $ownership.wrapper_process.WaitForExit([int]$remainingTimeoutMilliseconds)) {
                throw "${Role}_process_timeout"
            }
            $ownership.wrapper_process.WaitForExit()
        }
    }
    catch {
        $originalFailureCode = [string]$_.Exception.Message
        if ($null -ne $ownership) {
            try {
                Stop-ColdRestoreOwnedProcessTree $ownership
            }
            catch {
                throw "task_owned_process_cleanup_failed"
            }
        }
        elseif ($null -ne $process) {
            try {
                Stop-ColdRestoreLaunchedProcessTree $process $resolvedGodotPath $argumentLine
            }
            catch {
                throw "task_owned_process_cleanup_failed"
            }
        }
        throw $originalFailureCode
    }
    finally {
        $roleStopwatch.Stop()
    }
    Assert-ColdRestoreCondition ($ownership.engine_process.ExitCode -eq 0) "${Role}_engine_process_failed"
    Assert-ColdRestoreCondition ($ownership.wrapper_process.ExitCode -eq 0) "${Role}_wrapper_process_failed"
    Assert-ColdRestoreCondition (-not (Test-ColdRestoreProcessRecordCurrent $ownership.engine_record) `
        -and -not (Test-ColdRestoreProcessRecordCurrent $ownership.wrapper_record)) "task_owned_process_residual"
    $manifest = Read-ColdRestoreManifest $stdoutPath $Role $RunId
    Assert-ColdRestoreCondition ([int64]$manifest.process_id -eq [int64]$ownership.engine_process_id) "${Role}_manifest_process_id_mismatch"
    Assert-ColdRestoreCondition ([int64]$manifest.parent_process_id -eq [int64]$ownership.engine_record.parent_process_id `
        -and [string]$manifest.process_creation_time_utc_ticks -eq ([int64]$ownership.engine_record.creation_time_utc_ticks).ToString([Globalization.CultureInfo]::InvariantCulture) `
        -and [int64]$manifest.wrapper_process_id -eq [int64]$ownership.wrapper_process_id `
        -and [int64]$manifest.wrapper_parent_process_id -eq [int64]$ownership.wrapper_record.parent_process_id `
        -and [string]$manifest.wrapper_creation_time_utc_ticks -eq ([int64]$ownership.wrapper_record.creation_time_utc_ticks).ToString([Globalization.CultureInfo]::InvariantCulture)) "${Role}_manifest_process_identity_mismatch"
    Assert-ColdRestoreCondition ([int64]$manifest.orchestrator_process_id -eq [int64]$OrchestratorRecord.process_id `
        -and [string]$manifest.orchestrator_creation_time_utc_ticks -eq ([int64]$OrchestratorRecord.creation_time_utc_ticks).ToString([Globalization.CultureInfo]::InvariantCulture) `
        -and [string]$manifest.launch_nonce -eq $launchNonce `
        -and [string]$manifest.official_claim_fingerprint -eq $OfficialClaimFingerprint) "${Role}_manifest_launch_attestation_mismatch"
    Assert-ColdRestoreCondition ([string]$manifest.head_sha -eq $HeadSha) "${Role}_manifest_head_sha_mismatch"
    return [pscustomobject]@{
        wrapper_process_id = [int64]$ownership.wrapper_process_id
        engine_process_id = [int64]$ownership.engine_process_id
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
    $claimFingerprint = [string]$Producer.official_claim_fingerprint
    $orchestratorProcessId = [int64]$Producer.orchestrator_process_id
    $orchestratorCreationTicks = [string]$Producer.orchestrator_creation_time_utc_ticks
    Assert-ColdRestoreCondition ([string]$Consumer.official_claim_fingerprint -eq $claimFingerprint `
        -and [string]$Validator.official_claim_fingerprint -eq $claimFingerprint `
        -and [int64]$Consumer.orchestrator_process_id -eq $orchestratorProcessId `
        -and [int64]$Validator.orchestrator_process_id -eq $orchestratorProcessId `
        -and [string]$Consumer.orchestrator_creation_time_utc_ticks -eq $orchestratorCreationTicks `
        -and [string]$Validator.orchestrator_creation_time_utc_ticks -eq $orchestratorCreationTicks) "launch_attestation_chain_mismatch"
    $launchNonces = @([string]$Producer.launch_nonce, [string]$Consumer.launch_nonce, [string]$Validator.launch_nonce)
    Assert-ColdRestoreCondition (@($launchNonces | Sort-Object -Unique).Count -eq 3) "launch_nonce_reuse"
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
    Assert-ColdRestoreCondition (-not ($ContractCleanupProbe -and ($EnableColdRestoreExecution -or $ContractManifestPath -ne ""))) "execution_mode_conflict"

    if ($ContractCleanupProbe) {
        Write-Output ((Invoke-ColdRestoreCleanupContractProbe) | ConvertTo-Json -Compress -Depth 2)
        exit 0
    }

    if ($ContractManifestPath -ne "") {
        $fixture = Read-ContractManifestFixture $ContractManifestPath
        $comparison = Compare-ColdRestoreManifests $fixture.producer $fixture.consumer $fixture.validator
        Write-AllowlistedResult (New-AllowlistedResult $false $true $true "" $comparison)
        exit 0
    }

    # Check-only and non-official qualification callers exit before the official claim boundary.
    if (-not $EnableColdRestoreExecution) {
        Write-AllowlistedResult (New-AllowlistedResult $false $false $true "")
        exit 0
    }

    Assert-ColdRestoreCondition $DriverExecutionReady "driver_execution_not_ready"
    $executionPreflight = Invoke-ColdRestoreExecutionPreflight $ProjectPath $GodotPath
    $headSha = [string]$executionPreflight.head_sha
    $claimNonce = [Guid]::NewGuid().ToString("N")
    $officialClaimLedgerPath = New-OfficialClaimLedger `
        ([string]$executionPreflight.official_claim_directory) `
        $headSha `
        $executionPreflight.orchestrator_record `
        $claimNonce
    Assert-ColdRestoreCondition ([System.IO.File]::Exists($officialClaimLedgerPath)) "official_claim_missing_after_create"
    Assert-ColdRestoreCondition ([IO.Path]::GetFullPath($officialClaimLedgerPath) -eq [IO.Path]::GetFullPath([string]$executionPreflight.official_claim_ledger_path)) "official_claim_path_mismatch"
    $officialClaimFingerprint = Get-ColdRestoreFileSha256 $officialClaimLedgerPath

    $producerRun = Invoke-ColdRestoreRole "producer" `
        $executionPreflight.resolved_project_path $executionPreflight.resolved_godot_path `
        $executionPreflight.log_root $headSha $officialClaimLedgerPath $officialClaimFingerprint `
        $claimNonce $executionPreflight.orchestrator_record
    # Process B starts only after Process A exited and its one safe manifest parsed.
    $consumerRun = Invoke-ColdRestoreRole "consumer" `
        $executionPreflight.resolved_project_path $executionPreflight.resolved_godot_path `
        $executionPreflight.log_root $headSha $officialClaimLedgerPath $officialClaimFingerprint `
        $claimNonce $executionPreflight.orchestrator_record `
        ([int64]$producerRun.manifest.queue_trigger_resolution_id) `
        ([string]$producerRun.manifest.queue_trigger_stable_target_fingerprint)
    # Process C starts only after Process B exited and its one safe manifest parsed.
    $validatorRun = Invoke-ColdRestoreRole "validator" `
        $executionPreflight.resolved_project_path $executionPreflight.resolved_godot_path `
        $executionPreflight.log_root $headSha $officialClaimLedgerPath $officialClaimFingerprint `
        $claimNonce $executionPreflight.orchestrator_record `
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
