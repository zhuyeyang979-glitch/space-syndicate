[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$modulePath = Join-Path $projectRoot "scripts/tools/cold_restore_official_attempt2_contract.psm1"
$root = Join-Path ([IO.Path]::GetTempPath()) "alpha04c preflight 路径 $([Guid]::NewGuid().ToString('N'))"
$script:checks = 0
$script:failures = [Collections.Generic.List[string]]::new()

function Assert-PreflightCondition {
    param([bool]$Condition, [string]$Message)
    $script:checks += 1
    if (-not $Condition) { $script:failures.Add($Message) }
}

function Get-ThrownReason {
    param([scriptblock]$Action)
    try { & $Action | Out-Null } catch { return [string]$_.Exception.Message }
    return ""
}

function Copy-TestValue {
    param($Value)
    return $Value | ConvertTo-Json -Depth 16 | ConvertFrom-Json -DateKind String
}

try {
    Import-Module $modulePath -Force
    $officialRoot = Join-Path $root "git common/codex/cold_restore_v3"
    $attempt1Path = Join-Path $officialRoot "official-alpha04c-depth1-seed900626424/official_claim_ledger.json"
    $otherClaimPath = Join-Path $officialRoot "official-history/another_claim.json"
    $candidateClaimPath = Join-Path $officialRoot "official-alpha04c-attempt-2-depth1-seed900626424/official_attempt_2_claim.json"
    $candidateEvidenceRoot = Join-Path $root "project evidence/alpha04c-cold-retry"
    $candidateUserDataRoot = Join-Path $root "isolated user data/alpha04c-cold-retry"
    [IO.Directory]::CreateDirectory((Split-Path -Parent $attempt1Path)) | Out-Null
    [IO.Directory]::CreateDirectory((Split-Path -Parent $otherClaimPath)) | Out-Null
    [IO.File]::WriteAllText($attempt1Path, "attempt-one-immutable", [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($otherClaimPath, "historical-claim", [Text.UTF8Encoding]::new($false))

    Assert-PreflightCondition ((Get-ThrownReason {
        Assert-ColdRestoreOfficialAttempt2PreflightAuthorizationCount 0
    }) -ceq "") "preflight accepts only the non-consuming authorization count"
    Assert-PreflightCondition ((Get-ThrownReason {
        Assert-ColdRestoreOfficialAttempt2PreflightAuthorizationCount 1
    }) -ceq "official_preflight_authorization_must_be_zero") "preflight rejects a consuming authorization count"

    $snapshotArguments = @{
        OfficialClaimRoot = $officialRoot
        Attempt1ClaimPath = $attempt1Path
        CandidateClaimPath = $candidateClaimPath
        CandidateEvidenceRoot = $candidateEvidenceRoot
        CandidateUserDataRoot = $candidateUserDataRoot
    }
    $before = Get-ColdRestoreOfficialAttempt2SideEffectSnapshot @snapshotArguments
    Assert-PreflightCondition ([bool]$before.attempt_1_exists `
        -and [string]$before.attempt_1_sha256 -cmatch '^[0-9a-f]{64}$') "snapshot binds Attempt 1 bytes"
    Assert-PreflightCondition ([int]$before.claim_inventory_count -eq 2 `
        -and [string]$before.claim_inventory_fingerprint -cmatch '^[0-9a-f]{64}$') "snapshot binds the complete claim inventory"
    Assert-PreflightCondition ([int]$before.godot_process_count -eq @($before.godot_process_identities).Count `
        -and [string]$before.godot_process_identity_fingerprint -cmatch '^[0-9a-f]{64}$') "snapshot binds Godot PID and creation-time identities"
    Assert-PreflightCondition ((Get-ThrownReason {
        Assert-ColdRestoreOfficialAttempt2CandidateRootsAbsent $before
    }) -ceq "") "all three candidate roots are initially absent"

    $unchanged = Get-ColdRestoreOfficialAttempt2SideEffectSnapshot @snapshotArguments
    Assert-PreflightCondition ((Get-ThrownReason {
        Assert-ColdRestoreOfficialAttempt2SideEffectSnapshotUnchanged $before $unchanged
    }) -ceq "") "identical before and after snapshots pass"
    Assert-PreflightCondition (-not [IO.Directory]::Exists((Split-Path -Parent $candidateClaimPath)) `
        -and -not [IO.Directory]::Exists($candidateEvidenceRoot) `
        -and -not [IO.Directory]::Exists($candidateUserDataRoot)) "snapshot operations create no candidate directory"

    [IO.File]::WriteAllText($otherClaimPath, "historical-claim-mutated", [Text.UTF8Encoding]::new($false))
    $claimChanged = Get-ColdRestoreOfficialAttempt2SideEffectSnapshot @snapshotArguments
    Assert-PreflightCondition ((Get-ThrownReason {
        Assert-ColdRestoreOfficialAttempt2SideEffectSnapshotUnchanged $before $claimChanged
    }) -ceq "official_preflight_side_effect_detected") "claim inventory mutation fails closed"
    [IO.File]::WriteAllText($otherClaimPath, "historical-claim", [Text.UTF8Encoding]::new($false))

    $pidChanged = Copy-TestValue $before
    $pidChanged.godot_process_count = [int]$pidChanged.godot_process_count + 1
    Assert-PreflightCondition ((Get-ThrownReason {
        Assert-ColdRestoreOfficialAttempt2SideEffectSnapshotUnchanged $before $pidChanged
    }) -ceq "official_preflight_side_effect_detected") "PID identity mutation fails closed"

    foreach ($collision in @(
        [pscustomobject]@{ path = (Split-Path -Parent $candidateClaimPath); label = "claim" },
        [pscustomobject]@{ path = $candidateEvidenceRoot; label = "evidence" },
        [pscustomobject]@{ path = $candidateUserDataRoot; label = "user data" }
    )) {
        [IO.Directory]::CreateDirectory([string]$collision.path) | Out-Null
        $collisionSnapshot = Get-ColdRestoreOfficialAttempt2SideEffectSnapshot @snapshotArguments
        Assert-PreflightCondition ((Get-ThrownReason {
            Assert-ColdRestoreOfficialAttempt2CandidateRootsAbsent $collisionSnapshot
        }) -ceq "official_attempt_2_candidate_root_collision") "$($collision.label) root collision fails closed"
        [IO.Directory]::Delete([string]$collision.path, $true)
    }

    Assert-PreflightCondition ((Get-ThrownReason {
        Get-ColdRestoreOfficialAttempt2SideEffectSnapshot `
            -OfficialClaimRoot (Join-Path $root "missing official root") `
            -Attempt1ClaimPath $attempt1Path `
            -CandidateClaimPath $candidateClaimPath `
            -CandidateEvidenceRoot $candidateEvidenceRoot `
            -CandidateUserDataRoot $candidateUserDataRoot
    }) -ceq "official_preflight_claim_inventory_unavailable") "claim inventory enumeration failure is typed and fail closed"

    $info = Get-ColdRestoreOfficialAttempt2ContractInfo
    Assert-PreflightCondition (@($info.side_effect_snapshot_fields).Count -eq 11) "module publishes the closed snapshot schema"
    Assert-PreflightCondition (-not [IO.File]::Exists($candidateClaimPath)) "behavior fixture never publishes Attempt 2"
}
catch {
    $script:failures.Add("unexpected exception: $($_.Exception.Message)")
}
finally {
    $resolvedRoot = [IO.Path]::GetFullPath($root)
    $resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolvedRoot.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase) `
        -and [IO.Path]::GetFileName($resolvedRoot).StartsWith("alpha04c preflight 路径 ", [StringComparison]::Ordinal)) {
        Remove-Item -LiteralPath $resolvedRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$status = if ($script:failures.Count -eq 0) { "PASS" } else { "FAIL" }
Write-Output "COLD_RESTORE_OFFICIAL_ATTEMPT2_PREFLIGHT_BEHAVIOR|status=$status|checks=$script:checks|failures=$($script:failures.Count)"
foreach ($failure in $script:failures) { Write-Output "FAIL|$failure" }
if ($script:failures.Count -gt 0) { exit 1 }
exit 0
