[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ToolingWorktree,
    [Parameter(Mandatory = $true)][string]$ExpectedToolingHead,
    [Parameter(Mandatory = $true)][string]$ExpectedToolingTree,
    [Parameter(Mandatory = $true)][string]$ProductHead,
    [Parameter(Mandatory = $true)][string]$ProductTree,
    [Parameter(Mandatory = $true)][string]$ImportRunnerPath,
    [Parameter(Mandatory = $true)][string]$BaselinePath,
    [Parameter(Mandatory = $true)][string]$ClassCachePath,
    [Parameter(Mandatory = $true)][string]$FormalReceiptPath,
    [Parameter(Mandatory = $true)][string]$FinalizerDryRunPath,
    [Parameter(Mandatory = $true)][string]$SelfTestPath,
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [Parameter(Mandatory = $true)][string]$OutputShaPath
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'pr90_attempt19_authority_contract.psm1') -Force
$root = (Resolve-Path -LiteralPath $ToolingWorktree).Path
$head = (& git -C $root rev-parse HEAD).Trim(); $tree = (& git -C $root rev-parse 'HEAD^{tree}').Trim()
if ($LASTEXITCODE -ne 0 -or $head -cne $ExpectedToolingHead -or $tree -cne $ExpectedToolingTree) { throw 'Formal dry-run tooling identity mismatch.' }
if (@(& git -C $root status --porcelain=v1).Count -ne 0) { throw 'Formal dry-run requires a clean tooling worktree.' }
$baseline = Get-Content -Raw -LiteralPath $BaselinePath | ConvertFrom-Json -Depth 100
Assert-ProductIdentity $baseline $ProductHead $ProductTree
if (-not [bool]$baseline.post_import_baseline_sealed) { throw 'Formal dry-run baseline is not sealed.' }
Assert-ExactSha256 $ClassCachePath ([string]$baseline.class_cache_sha256) | Out-Null
Assert-ExactSha256 $GodotPath ([string]$baseline.godot_sha256) | Out-Null
$receipt = Get-Content -Raw -LiteralPath $FormalReceiptPath | ConvertFrom-Json -Depth 100
Assert-ProductIdentity $receipt $ProductHead $ProductTree
if ([string]$receipt.status -cne 'PASS' -or [int]$receipt.gate_count -ne 79 -or [int]$receipt.pass_count -ne 79 -or
    [int]$receipt.fail_count -ne 0 -or [int]$receipt.duplicate_gate_count -ne 0 -or [int]$receipt.missing_gate_count -ne 0 -or
    [string]$receipt.canonical_payload_sha256 -cne (Get-CanonicalPayloadSha256 $receipt)) { throw 'Formal dry-run receipt contract failed.' }
$finalizer = Get-Content -Raw -LiteralPath $FinalizerDryRunPath | ConvertFrom-Json -Depth 100
if ([string]$finalizer.status -cne 'PASS' -or [string]$finalizer.tooling_head_sha -cne $head -or [string]$finalizer.tooling_tree_sha -cne $tree -or
    [string]$finalizer.import_runner_sha256 -cne (Get-Sha256 $ImportRunnerPath) -or [string]$finalizer.baseline_sha256 -cne (Get-Sha256 $BaselinePath) -or
    [int]$finalizer.formal_mcp_count -ne 0 -or [int]$finalizer.product_game_count -ne 0 -or
    [string]$finalizer.canonical_payload_sha256 -cne (Get-CanonicalPayloadSha256 $finalizer)) { throw 'Formal dry-run finalizer contract failed.' }
$selftest = Get-Content -Raw -LiteralPath $SelfTestPath | ConvertFrom-Json -Depth 100
if ([string]$selftest.status -cne 'PASS' -or [int]$selftest.case_count -lt 15 -or [int]$selftest.case_count -ne [int]$selftest.pass_count -or
    [int]$selftest.missing_prerequisite_false_accept_count -ne 0 -or [int]$selftest.stale_tooling_false_accept_count -ne 0 -or
    [string]$selftest.canonical_payload_sha256 -cne (Get-CanonicalPayloadSha256 $selftest)) { throw 'Formal dry-run self-test contract failed.' }
$godotProcesses = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '^Godot' })
$rows = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)
$mcpProcesses = @($rows | Where-Object { $_.ProcessId -ne $PID -and [string]$_.CommandLine -match 'funplay_mcp|invoke_cursor_aware_exact_mcp' })
$workerProcesses = @($rows | Where-Object { $_.ProcessId -ne $PID -and [string]$_.CommandLine -match 'v075.*formal.*worker|new-head-full-focused.*worker' })
$ports = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { [int]$_.LocalPort -in @(7576,7586) })
if ($godotProcesses.Count -ne 0 -or $mcpProcesses.Count -ne 0 -or $workerProcesses.Count -ne 0 -or $ports.Count -ne 0) { throw 'Formal dry-run protected process/port gate is not zero.' }
$report = [pscustomobject][ordered]@{
    schema = 'SpaceSyndicatePr90Attempt19FormalDryRunV1'
    status = 'PASS'
    run_id = 'pr90-attempt19-formal-dry-run-001'
    created_at_utc = [DateTimeOffset]::UtcNow.ToString('o')
    product_head_sha = $ProductHead
    product_tree_sha = $ProductTree
    tooling_head_sha = $head
    tooling_tree_sha = $tree
    import_runner_path = [IO.Path]::GetFullPath($ImportRunnerPath)
    import_runner_sha256 = Get-Sha256 $ImportRunnerPath
    sealed_baseline_path = [IO.Path]::GetFullPath($BaselinePath)
    sealed_baseline_sha256 = Get-Sha256 $BaselinePath
    class_cache_sha256 = Get-Sha256 $ClassCachePath
    formal_receipt_sha256 = Get-Sha256 $FormalReceiptPath
    finalizer_dry_run_sha256 = Get-Sha256 $FinalizerDryRunPath
    selftest_manifest_sha256 = Get-Sha256 $SelfTestPath
    godot_executable_sha256 = Get-Sha256 $GodotPath
    formal_mcp_started = $false
    formal_mcp_execution_count = 0
    authorization_consumed = $false
    product_process_count = $godotProcesses.Count
    mcp_process_count = $mcpProcesses.Count
    release_worker_process_count = $workerProcesses.Count
    protected_port_count = $ports.Count
    reached_authorization_construction_boundary = $true
    canonical_payload_sha256 = ''
}
$report.canonical_payload_sha256 = Get-CanonicalPayloadSha256 $report
Write-ImmutableJson -Path $OutputPath -Value $report
Write-ImmutableSha256Sidecar -Path $OutputShaPath -TargetPath $OutputPath
$report | ConvertTo-Json -Depth 100 -Compress
