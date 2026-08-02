[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ModulePath,
    [Parameter(Mandatory = $true)][string]$RunId,
    [Parameter(Mandatory = $true)][string]$Role,
    [Parameter(Mandatory = $true)][string]$RepositoryHead,
    [Parameter(Mandatory = $true)][string]$ChildAttestationPath,
    [Parameter(Mandatory = $true)][string]$Mode,
    [string]$ProgressHeartbeatEventDirectory = "",
    [string]$PolicyRole = "",
    [string]$PolicyFingerprint = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Import-Module $ModulePath -Force

function Write-FixtureProgressHeartbeat {
    param(
        [Parameter(Mandatory = $true)][int]$Sequence,
        [Parameter(Mandatory = $true)][string]$Phase,
        [Parameter(Mandatory = $true)][int64]$WorldTime,
        [Parameter(Mandatory = $true)][int64]$OwnerIndex,
        [Parameter(Mandatory = $true)][int64]$QueueRevision,
        [Parameter(Mandatory = $true)][string]$SavePhase,
        [string]$HeartbeatRunId = $RunId,
        [string]$HeartbeatRepositoryHead = $RepositoryHead,
        [string]$HeartbeatPolicyFingerprint = $PolicyFingerprint,
        [string]$HeartbeatId = "ColdRestoreRoleProgressHeartbeatV1",
        [switch]$CorruptFingerprint
    )

    $heartbeat = [pscustomobject][ordered]@{
        schema_version = 1
        heartbeat_id = $HeartbeatId
        run_id = $HeartbeatRunId
        role_id = $PolicyRole
        repository_head = $HeartbeatRepositoryHead
        policy_fingerprint = $HeartbeatPolicyFingerprint
        heartbeat_sequence = $Sequence
        phase = $Phase
        world_time = $WorldTime
        owner_index = $OwnerIndex
        queue_revision = $QueueRevision
        save_phase = $SavePhase
        last_evidence_write_time = [Environment]::TickCount64
        semantic_progress_fingerprint = ""
        evidence_fingerprint = ""
    }
    $heartbeat.semantic_progress_fingerprint = Get-ColdRestoreProgressSemanticFingerprint $heartbeat
    $heartbeat.evidence_fingerprint = Get-ColdRestoreEvidenceFingerprint $heartbeat "evidence_fingerprint"
    if ($CorruptFingerprint) {
        $heartbeat.evidence_fingerprint = "0" * 64
    }
    $eventPath = Join-Path $ProgressHeartbeatEventDirectory ("{0:D4}.snapshot.json" -f $Sequence)
    Write-ColdRestoreAtomicJson $eventPath $heartbeat | Out-Null
}

if ($Mode -like "policy_*") {
    if ($ProgressHeartbeatEventDirectory -eq "" `
        -or $PolicyRole -eq "" `
        -or $PolicyFingerprint -notmatch '^[0-9a-f]{64}$') {
        throw "fixture_policy_parameters_invalid"
    }
    if ($Mode -ne "policy_missing") {
        $heartbeatRunId = if ($Mode -eq "policy_wrong_run") { "$RunId-wrong" } else { $RunId }
        $heartbeatRepositoryHead = if ($Mode -eq "policy_wrong_head") { "e" * 40 } else { $RepositoryHead }
        $heartbeatPolicyFingerprint = if ($Mode -eq "policy_wrong_policy") { "f" * 64 } else { $PolicyFingerprint }
        $heartbeatId = if ($Mode -eq "policy_wrong_heartbeat_id") { "ColdRestoreRoleProgressHeartbeatV0" } else { "ColdRestoreRoleProgressHeartbeatV1" }
        Write-FixtureProgressHeartbeat 1 "child_bootstrap" 0 -1 0 "not_started" `
            -HeartbeatRunId $heartbeatRunId `
            -HeartbeatRepositoryHead $heartbeatRepositoryHead `
            -HeartbeatPolicyFingerprint $heartbeatPolicyFingerprint `
            -HeartbeatId $heartbeatId `
            -CorruptFingerprint:($Mode -eq "policy_bad_fingerprint")
    }
    switch ($Mode) {
        "policy_green" {
            Start-Sleep -Milliseconds 150
            Write-FixtureProgressHeartbeat 2 "work" 1 0 0 "not_started"
            Start-Sleep -Milliseconds 150
            Write-FixtureProgressHeartbeat 3 "quit_requested" 1 0 1 "quit_requested"
        }
        "policy_no_progress" {
            for ($sequence = 2; $sequence -le 60; $sequence += 1) {
                Write-Output "fixture stdout without semantic progress sequence=$sequence"
                Start-Sleep -Milliseconds 100
                Write-FixtureProgressHeartbeat $sequence "child_bootstrap" 0 -1 0 "not_started"
            }
        }
        "policy_absolute" {
            for ($sequence = 2; $sequence -le 60; $sequence += 1) {
                Start-Sleep -Milliseconds 100
                Write-FixtureProgressHeartbeat $sequence "work" $sequence 0 0 "not_started"
            }
        }
        "policy_sequence_gap" {
            Start-Sleep -Milliseconds 100
            Write-FixtureProgressHeartbeat 3 "work" 1 0 0 "not_started"
            Start-Sleep -Seconds 5
        }
        "policy_bad_fingerprint" { Start-Sleep -Seconds 5 }
        "policy_wrong_run" { Start-Sleep -Seconds 5 }
        "policy_wrong_head" { Start-Sleep -Seconds 5 }
        "policy_wrong_policy" { Start-Sleep -Seconds 5 }
        "policy_wrong_heartbeat_id" { Start-Sleep -Seconds 5 }
        "policy_missing" { }
    }
}

if ($Mode -eq "residual_sleep") {
    Start-Sleep -Seconds 30
    exit 0
}
if ($Mode -eq "timeout") {
    Start-Sleep -Seconds 5
    exit 0
}
if ($Mode -eq "nonzero") {
    [Console]::Error.Write("fixture nonzero harness failure")
    exit 12
}
if ($Mode -eq "write_failure") {
    exit 13
}
if ($Mode -eq "readback_failure") {
    exit 14
}
if ($Mode -eq "missing") {
    Write-Output "fixture intentionally omitted child attestation"
    exit 0
}
if ($Mode -eq "truncated") {
    [IO.Directory]::CreateDirectory((Split-Path -Parent $ChildAttestationPath)) | Out-Null
    [IO.File]::WriteAllText($ChildAttestationPath, '{"schema_version":1', [Text.UTF8Encoding]::new($false))
    exit 0
}

$green = $Mode -ne "valid_blocked"
$blocker = if ($green) { "" } else { "BLOCKED_BY_NO_LEGAL_QUEUE_ACCEPTANCE_SCENARIO" }
$queueCount = if ($green) { 1 } else { 0 }
$attestation = New-ColdRestoreChildCompletionFixture `
    -RunId $RunId `
    -Role $Role `
    -RepositoryHead $RepositoryHead `
    -QualificationGreen $green `
    -ProductBlocker $blocker `
    -QueueCount $queueCount

switch ($Mode) {
    "wrong_schema" { $attestation.schema_version = 2 }
    "wrong_run_id" { $attestation.run_id = "$RunId-wrong" }
    "wrong_role" { $attestation.role = "producer" }
    "wrong_head" { $attestation.repository_head = "c" * 40 }
}
if ($Mode -in @("wrong_schema", "wrong_run_id", "wrong_role", "wrong_head")) {
    $attestation.evidence_fingerprint = Get-ColdRestoreEvidenceFingerprint $attestation "evidence_fingerprint"
}
if ($Mode -eq "wrong_fingerprint") {
    $attestation.evidence_fingerprint = "0" * 64
}

Write-ColdRestoreAtomicJson $ChildAttestationPath $attestation | Out-Null
if ($Mode -eq "stale") {
    [IO.File]::SetLastWriteTimeUtc($ChildAttestationPath, [DateTime]::UtcNow.AddMinutes(-10))
}
if ($Mode -eq "residual") {
    $process = [Diagnostics.Process]::new()
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = (Get-Command pwsh).Source
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    foreach ($argument in @(
        "-NoProfile",
        "-File", $PSCommandPath,
        "-ModulePath", $ModulePath,
        "-RunId", $RunId,
        "-Role", $Role,
        "-RepositoryHead", $RepositoryHead,
        "-ChildAttestationPath", $ChildAttestationPath,
        "-Mode", "residual_sleep"
    )) {
        $startInfo.ArgumentList.Add($argument)
    }
    $process.StartInfo = $startInfo
    $null = $process.Start()
    Write-Output "fixture spawned task-owned descendant pid=$($process.Id)"
    $process.Dispose()
}
else {
    Write-Output "fixture child completed mode=$Mode"
}
[Console]::Error.Write("fixture stderr mode=$Mode")
exit 0
