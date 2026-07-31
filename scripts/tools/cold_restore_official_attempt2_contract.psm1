Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "cold_restore_attested_process.psm1") -ErrorAction Stop

$script:ClaimFields = @(
    "schema_version", "claim_id", "attempt_number", "authorization_id", "created_at_utc",
    "run_id", "source_head", "rehearsal_green_head", "scenario_fingerprint",
    "challenge_depth", "seed", "local_player_count", "ai_player_count",
    "timeout_policy_sha256", "prerequisite_evidence_fingerprint",
    "preclaim_runtime_freeze_fingerprint", "process_role_timeouts", "rehearsal_run_id",
    "rehearsal_evidence_fingerprint", "rehearsal_outcome_sha256",
    "rehearsal_admission_sha256", "rehearsal_launch_sha256",
    "rehearsal_completion_sha256", "rehearsal_child_attestation_sha256",
    "rehearsal_parent_attestation_sha256", "attempt_1_claim_relative_path",
    "attempt_1_claim_sha256", "orchestrator_id", "orchestrator_schema_version",
    "orchestrator_script_sha256", "orchestrator_process_id",
    "orchestrator_creation_time_utc_ticks", "claim_nonce", "status",
    "authorized_official_count", "official_count_before", "official_count_after"
)
$script:RoleTimeoutFields = @("absolute_timeout_seconds", "no_progress_timeout_seconds")
$script:RoleIds = @("process_a", "process_b", "process_c")
$script:SideEffectSnapshotFields = @(
    "attempt_1_exists", "attempt_1_sha256", "attempt_2_claim_root_exists",
    "attempt_2_claim_exists", "candidate_evidence_root_exists",
    "candidate_user_data_root_exists", "claim_inventory_count",
    "claim_inventory_fingerprint", "godot_process_identities",
    "godot_process_count", "godot_process_identity_fingerprint"
)

function Test-ColdRestoreOfficialAttempt2UtcTimestamp {
    param([AllowNull()]$Value)
    if ($Value -isnot [string]) { return $false }
    $parsed = [DateTime]::MinValue
    return [DateTime]::TryParseExact(
        [string]$Value,
        "O",
        [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::RoundtripKind,
        [ref]$parsed
    )
}

function Assert-ColdRestoreOfficialAttempt2Claim {
    param([Parameter(Mandatory = $true)]$Value)

    if (-not (Test-ColdRestoreExactFieldSet $Value $script:ClaimFields) `
        -or [int]$Value.schema_version -ne 2 `
        -or [string]$Value.claim_id -cne "OfficialAttemptClaimV2" `
        -or [int]$Value.attempt_number -ne 2 `
        -or [string]$Value.authorization_id -cne "alpha04c-official-cold-restore-attempt-2-v1" `
        -or -not (Test-ColdRestoreOfficialAttempt2UtcTimestamp $Value.created_at_utc) `
        -or [string]$Value.run_id -cnotmatch '^alpha04c-cold-retry-[0-9a-f]{12}$' `
        -or [string]$Value.source_head -cnotmatch '^[0-9a-f]{40}$' `
        -or [string]$Value.run_id -cne "alpha04c-cold-retry-$(([string]$Value.source_head).Substring(0, 12))" `
        -or [string]$Value.rehearsal_green_head -cne [string]$Value.source_head `
        -or [string]$Value.scenario_fingerprint -cnotmatch '^[0-9a-f]{64}$' `
        -or [int]$Value.challenge_depth -ne 1 `
        -or [int64]$Value.seed -ne 900626424 `
        -or [int]$Value.local_player_count -ne 1 `
        -or [int]$Value.ai_player_count -ne 3 `
        -or [string]$Value.timeout_policy_sha256 -cnotmatch '^[0-9a-f]{64}$' `
        -or [string]$Value.prerequisite_evidence_fingerprint -cnotmatch '^[0-9a-f]{64}$' `
        -or [string]$Value.preclaim_runtime_freeze_fingerprint -cnotmatch '^[0-9a-f]{64}$' `
        -or [string]$Value.rehearsal_run_id -cne "alpha04c-process-a-rehearsal-$(([string]$Value.source_head).Substring(0, 12))" `
        -or [string]$Value.rehearsal_evidence_fingerprint -cnotmatch '^[0-9a-f]{64}$' `
        -or [string]$Value.attempt_1_claim_relative_path -cne "official-alpha04c-depth1-seed900626424/official_claim_ledger.json" `
        -or [string]$Value.attempt_1_claim_sha256 -cne "80979cf3089e46ebff6025253126b57c1dd4e522cc5f858be8d4f5915ed17458" `
        -or [string]$Value.orchestrator_id -cne "alpha04c_cold_restore_vertical_slice_orchestrator_v4" `
        -or [int]$Value.orchestrator_schema_version -ne 4 `
        -or [string]$Value.orchestrator_script_sha256 -cnotmatch '^[0-9a-f]{64}$' `
        -or [int]$Value.orchestrator_process_id -le 0 `
        -or [string]$Value.orchestrator_creation_time_utc_ticks -cnotmatch '^[1-9][0-9]{0,18}$' `
        -or [string]$Value.claim_nonce -cnotmatch '^[0-9a-f]{32}$' `
        -or [string]$Value.status -cne "consumed" `
        -or [int]$Value.authorized_official_count -ne 1 `
        -or [int]$Value.official_count_before -ne 1 `
        -or [int]$Value.official_count_after -ne 2) {
        throw "official_attempt_2_claim_invalid"
    }
    foreach ($field in @(
        "rehearsal_outcome_sha256", "rehearsal_admission_sha256", "rehearsal_launch_sha256",
        "rehearsal_completion_sha256", "rehearsal_child_attestation_sha256",
        "rehearsal_parent_attestation_sha256"
    )) {
        if ([string]$Value.$field -cnotmatch '^[0-9a-f]{64}$') {
            throw "official_attempt_2_rehearsal_evidence_invalid"
        }
    }
    if (-not (Test-ColdRestoreExactFieldSet $Value.process_role_timeouts $script:RoleIds)) {
        throw "official_attempt_2_role_timeout_set_invalid"
    }
    $expected = @{
        process_a = @(180, 60)
        process_b = @(360, 60)
        process_c = @(180, 30)
    }
    foreach ($role in $script:RoleIds) {
        $entry = $Value.process_role_timeouts.$role
        if (-not (Test-ColdRestoreExactFieldSet $entry $script:RoleTimeoutFields) `
            -or [int]$entry.absolute_timeout_seconds -ne [int]$expected[$role][0] `
            -or [int]$entry.no_progress_timeout_seconds -ne [int]$expected[$role][1]) {
            throw "official_attempt_2_role_timeout_invalid"
        }
    }
}

function Publish-ColdRestoreOfficialAttempt2Claim {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Claim
    )

    Assert-ColdRestoreOfficialAttempt2Claim $Claim
    try {
        return Write-ColdRestoreExclusiveJson $Path $Claim
    }
    catch {
        $reason = [string]$_.Exception.Message
        if ($reason -eq "exclusive_evidence_create_new_failed" -and [IO.File]::Exists($Path)) {
            try {
                $existing = [IO.File]::ReadAllText($Path, [Text.UTF8Encoding]::new($false)) | ConvertFrom-Json -DateKind String
                Assert-ColdRestoreOfficialAttempt2Claim $existing
            }
            catch {
                throw "official_attempt_2_stale_claim"
            }
            throw "official_attempt_2_authorization_already_consumed"
        }
        if ($reason -like "exclusive_evidence_consumed_*") {
            throw "official_attempt_2_consumed_but_claim_invalid"
        }
        throw "official_attempt_2_claim_write_failed"
    }
}

function Get-ColdRestoreOfficialAttempt2SideEffectSnapshot {
    param(
        [Parameter(Mandatory = $true)][string]$OfficialClaimRoot,
        [Parameter(Mandatory = $true)][string]$Attempt1ClaimPath,
        [Parameter(Mandatory = $true)][string]$CandidateClaimPath,
        [Parameter(Mandatory = $true)][string]$CandidateEvidenceRoot,
        [Parameter(Mandatory = $true)][string]$CandidateUserDataRoot
    )

    try {
        $godotProcesses = @(Get-Process -ErrorAction Stop | Where-Object { $_.ProcessName -like "godot*" })
        $godotIdentities = @(
            @(
                foreach ($process in $godotProcesses) {
                    [pscustomobject][ordered]@{
                        process_id = [int]$process.Id
                        creation_time_utc_ticks = $process.StartTime.ToUniversalTime().Ticks.ToString(
                            [Globalization.CultureInfo]::InvariantCulture
                        )
                    }
                }
            ) | Sort-Object process_id, creation_time_utc_ticks
        )
    }
    catch {
        throw "official_preflight_pid_snapshot_unavailable"
    }

    try {
        $claimDirectories = @(Get-ChildItem -LiteralPath $OfficialClaimRoot -Directory -Filter "official-*" -ErrorAction Stop)
        $claimFiles = @(
            foreach ($directory in $claimDirectories) {
                Get-ChildItem -LiteralPath $directory.FullName -File -Filter "*claim*.json" -ErrorAction Stop
            }
        )
        $claimInventory = @(
            $claimFiles |
                Sort-Object FullName |
                ForEach-Object {
                    [pscustomobject][ordered]@{
                        relative_path = [IO.Path]::GetRelativePath($OfficialClaimRoot, $_.FullName).Replace('\', '/')
                        file_bytes = [int64]$_.Length
                        sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
                    }
                }
        )
    }
    catch {
        throw "official_preflight_claim_inventory_unavailable"
    }

    return [pscustomobject][ordered]@{
        attempt_1_exists = [IO.File]::Exists($Attempt1ClaimPath)
        attempt_1_sha256 = $(if ([IO.File]::Exists($Attempt1ClaimPath)) {
            (Get-FileHash -LiteralPath $Attempt1ClaimPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
        } else { "" })
        attempt_2_claim_root_exists = [IO.Directory]::Exists((Split-Path -Parent $CandidateClaimPath))
        attempt_2_claim_exists = [IO.File]::Exists($CandidateClaimPath)
        candidate_evidence_root_exists = [IO.Directory]::Exists($CandidateEvidenceRoot)
        candidate_user_data_root_exists = [IO.Directory]::Exists($CandidateUserDataRoot)
        claim_inventory_count = Get-ColdRestoreSafeCollectionCount $claimInventory
        claim_inventory_fingerprint = Get-ColdRestoreTextSha256 (ConvertTo-ColdRestoreCanonicalJson $claimInventory)
        godot_process_identities = $godotIdentities
        godot_process_count = Get-ColdRestoreSafeCollectionCount $godotIdentities
        godot_process_identity_fingerprint = Get-ColdRestoreTextSha256 (ConvertTo-ColdRestoreCanonicalJson $godotIdentities)
    }
}

function Assert-ColdRestoreOfficialAttempt2CandidateRootsAbsent {
    param([Parameter(Mandatory = $true)]$Snapshot)

    if (-not (Test-ColdRestoreExactFieldSet $Snapshot $script:SideEffectSnapshotFields) `
        -or [bool]$Snapshot.attempt_2_claim_root_exists `
        -or [bool]$Snapshot.attempt_2_claim_exists `
        -or [bool]$Snapshot.candidate_evidence_root_exists `
        -or [bool]$Snapshot.candidate_user_data_root_exists) {
        throw "official_attempt_2_candidate_root_collision"
    }
    return $true
}

function Assert-ColdRestoreOfficialAttempt2PreflightAuthorizationCount {
    param([Parameter(Mandatory = $true)][int]$AuthorizedOfficialCount)

    if ($AuthorizedOfficialCount -ne 0) {
        throw "official_preflight_authorization_must_be_zero"
    }
    return $true
}

function Assert-ColdRestoreOfficialAttempt2SideEffectSnapshotUnchanged {
    param(
        [Parameter(Mandatory = $true)]$Before,
        [Parameter(Mandatory = $true)]$After
    )

    if (-not (Test-ColdRestoreExactFieldSet $Before $script:SideEffectSnapshotFields) `
        -or -not (Test-ColdRestoreExactFieldSet $After $script:SideEffectSnapshotFields) `
        -or (ConvertTo-ColdRestoreCanonicalJson $Before) -cne (ConvertTo-ColdRestoreCanonicalJson $After)) {
        throw "official_preflight_side_effect_detected"
    }
    return $true
}

function Get-ColdRestoreOfficialAttempt2ContractInfo {
    return [pscustomobject]@{
        schema_version = 2
        claim_id = "OfficialAttemptClaimV2"
        authorization_id = "alpha04c-official-cold-restore-attempt-2-v1"
        claim_fields = @($script:ClaimFields)
        role_timeout_fields = @($script:RoleTimeoutFields)
        role_ids = @($script:RoleIds)
        side_effect_snapshot_fields = @($script:SideEffectSnapshotFields)
    }
}

Export-ModuleMember -Function @(
    "Assert-ColdRestoreOfficialAttempt2Claim",
    "Publish-ColdRestoreOfficialAttempt2Claim",
    "Get-ColdRestoreOfficialAttempt2SideEffectSnapshot",
    "Assert-ColdRestoreOfficialAttempt2CandidateRootsAbsent",
    "Assert-ColdRestoreOfficialAttempt2PreflightAuthorizationCount",
    "Assert-ColdRestoreOfficialAttempt2SideEffectSnapshotUnchanged",
    "Get-ColdRestoreOfficialAttempt2ContractInfo"
)
