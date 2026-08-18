[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ManifestPath,
    [Parameter(Mandatory = $true)][string]$ManifestShaPath,
    [Parameter(Mandatory = $true)][string]$ValidatorPath,
    [Parameter(Mandatory = $true)][string]$ExpectedProductHead,
    [Parameter(Mandatory = $true)][string]$ExpectedProductTree,
    [Parameter(Mandatory = $true)][string]$ExpectedToolingHead,
    [Parameter(Mandatory = $true)][string]$ExpectedToolingTree,
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [Parameter(Mandatory = $true)][string]$OutputShaPath
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'pr90_attempt19_authority_contract.psm1') -Force
$manifest = Get-Content -Raw -LiteralPath $ManifestPath | ConvertFrom-Json -Depth 100
Assert-ExactSha256 $ValidatorPath ([string]$manifest.authorization_validator_sha256) | Out-Null
$pwsh = Join-Path $PSHOME 'pwsh.exe'
$validatorOutput = @(& $pwsh -NoProfile -File $ValidatorPath `
    -ManifestPath $ManifestPath -ManifestShaPath $ManifestShaPath `
    -ExpectedProductHead $ExpectedProductHead -ExpectedProductTree $ExpectedProductTree `
    -ExpectedToolingHead $ExpectedToolingHead -ExpectedToolingTree $ExpectedToolingTree)
$validatorExitCode = $LASTEXITCODE
if ($validatorExitCode -ne 0 -or $validatorOutput.Count -eq 0) { throw "Production authorization validator failed: exit=$validatorExitCode" }
$validation = $validatorOutput[-1] | ConvertFrom-Json -Depth 100
if ([string]$validation.status -cne 'PASS') { throw 'Production authorization validator did not pass.' }

$godotProcesses = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '^Godot' })
$processRows = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)
$mcpProcesses = @($processRows | Where-Object { $_.ProcessId -ne $PID -and [string]$_.CommandLine -match 'funplay_mcp|invoke_cursor_aware_exact_mcp' })
$workerProcesses = @($processRows | Where-Object { $_.ProcessId -ne $PID -and [string]$_.CommandLine -match 'v075.*formal.*worker|new-head-full-focused.*worker' })
$port7576 = @(Get-NetTCPConnection -State Listen -LocalPort 7576 -ErrorAction SilentlyContinue)
$port7586 = @(Get-NetTCPConnection -State Listen -LocalPort 7586 -ErrorAction SilentlyContinue)
$evidenceRoot = [IO.Path]::GetFullPath([string]$manifest.formal_evidence_root)
$evidenceRootNew = -not (Test-Path -LiteralPath $evidenceRoot) -or @(Get-ChildItem -LiteralPath $evidenceRoot -Force -ErrorAction SilentlyContinue).Count -eq 0
if ($godotProcesses.Count -ne 0 -or $mcpProcesses.Count -ne 0 -or $workerProcesses.Count -ne 0 -or
    $port7576.Count -ne 0 -or $port7586.Count -ne 0 -or -not $evidenceRootNew) {
    throw 'Protected process, port, or evidence-root precondition is not zero/new.'
}
$report = [pscustomobject][ordered]@{
    schema = 'SpaceSyndicatePr90PreFormalAuthorizationDryRunV1'
    run_id = 'pr90-attempt19-pre-formal-authorization-dry-run-001'
    status = 'PASS'
    created_at_utc = [DateTimeOffset]::UtcNow.ToString('o')
    manifest_path = [IO.Path]::GetFullPath($ManifestPath)
    manifest_sha256 = Get-Sha256 $ManifestPath
    validator_path = [IO.Path]::GetFullPath($ValidatorPath)
    validator_sha256 = Get-Sha256 $ValidatorPath
    product_head_sha = $ExpectedProductHead
    product_tree_sha = $ExpectedProductTree
    tooling_head_sha = $ExpectedToolingHead
    tooling_tree_sha = $ExpectedToolingTree
    authorization_declared_field_count = [int]$validation.declared_field_count
    authorization_validated_field_count = [int]$validation.validated_field_count
    authorization_field_mismatch_count = [int]$validation.field_mismatch_count
    formal_mcp_started = $false
    authorization_consumed = $false
    formal_mcp_execution_count = 0
    authorized_run_count_consumed = 0
    product_process_count = $godotProcesses.Count
    mcp_process_count = $mcpProcesses.Count
    release_worker_process_count = $workerProcesses.Count
    port_7576_count = $port7576.Count
    port_7586_count = $port7586.Count
    protected_process_count = $godotProcesses.Count + $mcpProcesses.Count + $workerProcesses.Count
    protected_port_count = $port7576.Count + $port7586.Count
    formal_evidence_root = $evidenceRoot
    formal_evidence_root_new = $evidenceRootNew
    reached_formal_process_start_boundary = $true
    canonical_payload_sha256 = ''
}
$report.canonical_payload_sha256 = Get-CanonicalPayloadSha256 $report
Write-ImmutableJson -Path $OutputPath -Value $report
Write-ImmutableSha256Sidecar -Path $OutputShaPath -TargetPath $OutputPath
$report | ConvertTo-Json -Depth 100 -Compress
