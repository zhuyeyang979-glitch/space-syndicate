[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ModulePath,
    [Parameter(Mandatory = $true)][string]$RunId,
    [Parameter(Mandatory = $true)][string]$Role,
    [Parameter(Mandatory = $true)][string]$RepositoryHead,
    [Parameter(Mandatory = $true)][string]$ChildAttestationPath,
    [Parameter(Mandatory = $true)][string]$Mode
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Import-Module $ModulePath -Force

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
