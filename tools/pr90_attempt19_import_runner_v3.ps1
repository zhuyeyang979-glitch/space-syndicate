[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateSet('Preflight','FinalizeSnapshot')][string]$Mode,
    [Parameter(Mandatory = $true)][string]$Worktree,
    [Parameter(Mandatory = $true)][string]$BaselinePath,
    [Parameter(Mandatory = $true)][string]$ExpectedBaselineSha256,
    [Parameter(Mandatory = $true)][string]$ClassCachePath,
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [Parameter(Mandatory = $true)][string]$ExpectedHeadSha,
    [Parameter(Mandatory = $true)][string]$ExpectedTreeSha,
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [Parameter(Mandatory = $true)][string]$OutputShaPath,
    [string]$PostStatePath = '',
    [switch]$ForceForensics
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'pr90_attempt19_authority_contract.psm1') -Force

# Attempt 19 revision marker. This runner deliberately does not regenerate the
# sealed Attempt 18 import baseline. It validates those immutable bytes and
# owns the production finalizer classification path used by the dry-run.
$attempt19Revision = 'PR90_ATTEMPT19_IMPORT_AUTHORITY_V3_001'
$root = (Resolve-Path -LiteralPath $Worktree).Path.TrimEnd('\')
$worktreeHead = (& git -C $root rev-parse HEAD).Trim()
$worktreeTree = (& git -C $root rev-parse 'HEAD^{tree}').Trim()
if ($LASTEXITCODE -ne 0 -or $worktreeHead -cne $ExpectedHeadSha -or $worktreeTree -cne $ExpectedTreeSha) {
    throw 'Import runner worktree does not match the frozen product Head/Tree.'
}
Assert-ExactSha256 $BaselinePath $ExpectedBaselineSha256 | Out-Null
$baseline = Get-Content -Raw -LiteralPath $BaselinePath | ConvertFrom-Json -Depth 100
Assert-ProductIdentity $baseline $ExpectedHeadSha $ExpectedTreeSha
if ([string]$baseline.schema -cne 'SpaceSyndicatePostImportAuthorityBaselineV2' -or -not [bool]$baseline.post_import_baseline_sealed) {
    throw 'Import runner requires the sealed V2 post-import baseline.'
}
Assert-ExactSha256 $ClassCachePath ([string]$baseline.class_cache_sha256) | Out-Null
Assert-ExactSha256 $GodotPath ([string]$baseline.godot_sha256) | Out-Null
$godotVersion = (& (Resolve-Path -LiteralPath $GodotPath).Path --version | Select-Object -First 1).Trim()
if ($godotVersion -cne [string]$baseline.godot_version) { throw 'Godot version mismatch.' }

$result = [pscustomobject][ordered]@{
    schema = 'SpaceSyndicatePr90Attempt19ImportRunnerV3Receipt'
    revision = $attempt19Revision
    mode = $Mode
    status = 'PASS'
    created_at_utc = [DateTimeOffset]::UtcNow.ToString('o')
    product_head_sha = $ExpectedHeadSha
    product_tree_sha = $ExpectedTreeSha
    baseline_path = [IO.Path]::GetFullPath($BaselinePath)
    baseline_sha256 = Get-Sha256 $BaselinePath
    class_cache_path = [IO.Path]::GetFullPath($ClassCachePath)
    class_cache_sha256 = Get-Sha256 $ClassCachePath
    godot_path = [IO.Path]::GetFullPath($GodotPath)
    godot_version = $godotVersion
    godot_executable_sha256 = Get-Sha256 $GodotPath
    formal_mcp_started = $false
    product_game_count = 0
    deletion_performed = $false
    finalizer = $null
    canonical_payload_sha256 = ''
}
$baselineState = New-FinalizerStateFromBaseline $baseline
$postState = if ($Mode -ceq 'FinalizeSnapshot' -and -not [string]::IsNullOrWhiteSpace($PostStatePath)) {
    if (-not (Test-Path -LiteralPath $PostStatePath -PathType Leaf)) { throw 'Post-state JSON file does not exist.' }
    Get-Content -Raw -LiteralPath $PostStatePath | ConvertFrom-Json -Depth 100
} else { Get-CurrentFinalizerState -Worktree $root }
$decision = Get-ImportFinalizerDecision -BaselineState $baselineState -PostState $postState -DisposableRoot $root -DispositionTarget $root -ForceForensics ([bool]$ForceForensics)
$result.finalizer = $decision
$result.status = [string]$decision.status
$result.canonical_payload_sha256 = Get-CanonicalPayloadSha256 $result
Write-ImmutableJson -Path $OutputPath -Value $result
Write-ImmutableSha256Sidecar -Path $OutputShaPath -TargetPath $OutputPath
$result | ConvertTo-Json -Depth 100 -Compress
if ([string]$result.status -cne 'PASS') { exit 2 }
