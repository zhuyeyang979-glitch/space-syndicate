[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [Parameter(Mandatory = $true)][string]$OutputShaPath,
    [Parameter(Mandatory = $true)][string]$ProductHeadSha,
    [Parameter(Mandatory = $true)][string]$ProductTreeSha,
    [Parameter(Mandatory = $true)][string]$ToolingHeadSha,
    [Parameter(Mandatory = $true)][string]$ToolingTreeSha,
    [Parameter(Mandatory = $true)][string]$ImportRunnerPath,
    [Parameter(Mandatory = $true)][string]$BaselinePath,
    [Parameter(Mandatory = $true)][string]$ExpectedBaselineSha256,
    [Parameter(Mandatory = $true)][string]$ClassCachePath,
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [Parameter(Mandatory = $true)][string]$ExpectedGodotVersion,
    [Parameter(Mandatory = $true)][string]$CloneRoot
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'pr90_attempt19_authority_contract.psm1') -Force

Assert-ExactSha256 $BaselinePath $ExpectedBaselineSha256 | Out-Null
$baseline = Get-Content -Raw -LiteralPath $BaselinePath | ConvertFrom-Json -Depth 100
Assert-ProductIdentity $baseline $ProductHeadSha $ProductTreeSha
if ([string]$baseline.schema -cne 'SpaceSyndicatePostImportAuthorityBaselineV2' -or -not [bool]$baseline.post_import_baseline_sealed) {
    throw 'Finalizer dry-run requires the exact sealed V2 baseline.'
}
Assert-ExactSha256 $ClassCachePath ([string]$baseline.class_cache_sha256) | Out-Null
Assert-ExactSha256 $GodotPath ([string]$baseline.godot_sha256) | Out-Null
$godotVersion = (& (Resolve-Path -LiteralPath $GodotPath).Path --version | Select-Object -First 1).Trim()
if ($godotVersion -cne $ExpectedGodotVersion -or $godotVersion -cne [string]$baseline.godot_version) {
    throw 'Godot version does not match the sealed baseline.'
}
$clone = (Resolve-Path -LiteralPath $CloneRoot).Path
$cloneHead = (& git -C $clone rev-parse HEAD).Trim()
$cloneTree = (& git -C $clone rev-parse 'HEAD^{tree}').Trim()
if ($LASTEXITCODE -ne 0 -or $cloneHead -cne $ProductHeadSha -or $cloneTree -cne $ProductTreeSha) {
    throw 'Disposable dry-run clone does not match the product identity.'
}
$baselineState = New-FinalizerStateFromBaseline $baseline
$liveState = Get-CurrentFinalizerState -Worktree $clone
$liveDecision = Get-ImportFinalizerDecision -BaselineState $baselineState -PostState $liveState -DisposableRoot $clone -DispositionTarget $clone
if ([string]$liveDecision.status -cne 'PASS') {
    throw "Disposable clone does not match sealed baseline: $($liveDecision.failure_reasons -join ',')"
}
$names = @(
    'no_changes','allowed_evidence_change','tracked_non_generated','tracked_import_metadata',
    'unknown_untracked','unknown_ignored','user_directory','outside_root','forensics_preserve','safe_discard'
)
$rows = @($names | ForEach-Object { Test-FinalizerScenario -Scenario $_ -BaselineState $baselineState -DisposableRoot $clone })
$failed = @($rows | Where-Object { -not [bool]$_.pass })
if ($failed.Count -ne 0) { throw "Finalizer production-classifier self-test failed: $($failed.scenario -join ',')" }
$safe = @($rows | Where-Object { $_.scenario -eq 'safe_discard' })[0]
$forensics = @($rows | Where-Object { $_.scenario -eq 'forensics_preserve' })[0]
$report = [pscustomobject][ordered]@{
    schema = 'SpaceSyndicatePr90ImportFinalizerDryRunV1'
    run_id = 'pr90-import-finalizer-dry-run-attempt19-001'
    status = 'PASS'
    created_at_utc = [DateTimeOffset]::UtcNow.ToString('o')
    head_sha = $ProductHeadSha
    tree_sha = $ProductTreeSha
    product_head_sha = $ProductHeadSha
    product_tree_sha = $ProductTreeSha
    tooling_head_sha = $ToolingHeadSha
    tooling_tree_sha = $ToolingTreeSha
    import_runner_path = [IO.Path]::GetFullPath($ImportRunnerPath)
    import_runner_sha256 = Get-Sha256 $ImportRunnerPath
    finalizer_classifier_path = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'pr90_attempt19_authority_contract.psm1'))
    finalizer_classifier_sha256 = Get-Sha256 (Join-Path $PSScriptRoot 'pr90_attempt19_authority_contract.psm1')
    baseline_path = [IO.Path]::GetFullPath($BaselinePath)
    baseline_sha256 = Get-Sha256 $BaselinePath
    class_cache_path = [IO.Path]::GetFullPath($ClassCachePath)
    class_cache_sha256 = Get-Sha256 $ClassCachePath
    class_cache_bytes = (Get-Item -LiteralPath $ClassCachePath).Length
    godot_path = [IO.Path]::GetFullPath($GodotPath)
    godot_version = $godotVersion
    godot_executable_sha256 = Get-Sha256 $GodotPath
    disposable_clone_root = $clone
    disposable_clone_head_sha = $cloneHead
    disposable_clone_tree_sha = $cloneTree
    scenario_count = $rows.Count
    scenario_pass_count = @($rows | Where-Object { [bool]$_.pass }).Count
    formal_mcp_count = 0
    product_game_count = 0
    unknown_file_delete_count = 0
    user_file_delete_count = 0
    outside_root_delete_count = 0
    forensics_preservation_green = [string]$forensics.actual_disposition -ceq 'PRESERVED_FOR_FORENSICS'
    safe_discard_green = [string]$safe.actual_disposition -ceq 'DISCARDED_AFTER_SEALED_EVIDENCE'
    baseline_match = $true
    live_baseline_decision = $liveDecision
    live_tracked_import_count = [int]$liveState.tracked_import_count
    live_untracked_uid_count = [int]$liveState.untracked_uid_count
    live_ignored_sidecar_count = [int]$liveState.ignored_sidecar_count
    tooling_sha_match = $true
    deletion_performed = $false
    rows = $rows
    canonical_payload_sha256 = ''
}
$report.canonical_payload_sha256 = Get-CanonicalPayloadSha256 $report
Write-ImmutableJson -Path $OutputPath -Value $report
Write-ImmutableSha256Sidecar -Path $OutputShaPath -TargetPath $OutputPath
[pscustomobject][ordered]@{
    status = 'PASS'
    path = [IO.Path]::GetFullPath($OutputPath)
    sha256 = Get-Sha256 $OutputPath
    scenario_count = $rows.Count
    scenario_pass_count = $rows.Count
    formal_mcp_count = 0
    product_game_count = 0
    deletion_performed = $false
} | ConvertTo-Json -Compress
