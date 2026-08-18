[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Worktree,
    [Parameter(Mandatory = $true)][string]$EvidenceRoot,
    [Parameter(Mandatory = $true)][string]$ProfileRoot,
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [Parameter(Mandatory = $true)][string]$ExpectedHeadSha,
    [Parameter(Mandatory = $true)][string]$ExpectedTreeSha,
    [Parameter(Mandatory = $true)][string]$LegacyImportEnginePath,
    [Parameter(Mandatory = $true)][string]$ExpectedLegacyImportEngineSha256,
    [Parameter(Mandatory = $true)][string]$SourceClassCachePath,
    [Parameter(Mandatory = $true)][string]$ExpectedSourceClassCacheSha256,
    [Parameter(Mandatory = $true)][string]$OutputReceiptPath,
    [Parameter(Mandatory = $true)][string]$OutputReceiptShaPath
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'pr90_attempt19_authority_contract.psm1') -Force
$root = (Resolve-Path -LiteralPath $Worktree).Path
$evidence = [IO.Path]::GetFullPath($EvidenceRoot)
$profile = [IO.Path]::GetFullPath($ProfileRoot)
if (Test-Path -LiteralPath $evidence) { throw 'Attempt 19 import evidence root must be new.' }
if (Test-Path -LiteralPath $profile) { throw 'Attempt 19 import profile root must be new.' }
Assert-ExactSha256 $LegacyImportEnginePath $ExpectedLegacyImportEngineSha256 | Out-Null
Assert-ExactSha256 $SourceClassCachePath $ExpectedSourceClassCacheSha256 | Out-Null
$head = (& git -C $root rev-parse HEAD).Trim(); $tree = (& git -C $root rev-parse 'HEAD^{tree}').Trim()
if ($LASTEXITCODE -ne 0 -or $head -cne $ExpectedHeadSha -or $tree -cne $ExpectedTreeSha) { throw 'Attempt 19 import clone identity mismatch.' }
if (@(& git -C $root status --porcelain=v1 --untracked-files=all).Count -ne 0) { throw 'Attempt 19 import requires a fresh clean clone.' }
$pwsh = Join-Path $PSHOME 'pwsh.exe'
$engineOutput = @(& $pwsh -NoProfile -File $LegacyImportEnginePath `
    -Worktree $root -EvidenceRoot $evidence -ProfileRoot $profile -GodotPath $GodotPath `
    -ExpectedHeadSha $ExpectedHeadSha -ExpectedTreeSha $ExpectedTreeSha)
$engineExitCode = $LASTEXITCODE
if ($engineExitCode -ne 0 -or $engineOutput.Count -eq 0) { throw "Bound import engine failed: exit=$engineExitCode" }
$engineResult = ([string]::Join("`n", [string[]]$engineOutput)) | ConvertFrom-Json -Depth 100
$pass1Path = Join-Path $evidence 'import-pass-1-manifest.json'
$pass2Path = Join-Path $evidence 'import-pass-2-manifest.json'
$baselinePath = Join-Path $evidence 'post-import-authority-baseline.json'
$warmupPath = Join-Path $evidence 'compatibility-warmup.godot.log'
foreach ($path in @($pass1Path,$pass2Path,$baselinePath,$warmupPath)) { if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Bound import engine omitted evidence: $path" } }
$baseline = Get-Content -Raw -LiteralPath $baselinePath | ConvertFrom-Json -Depth 100
Assert-ProductIdentity $baseline $ExpectedHeadSha $ExpectedTreeSha
$newClassCache = Join-Path $root '.godot/global_script_class_cache.cfg'
Assert-ExactSha256 $newClassCache $ExpectedSourceClassCacheSha256 | Out-Null
if ([string]$engineResult.status -cne 'PASS' -or -not [bool]$baseline.post_import_baseline_sealed -or
    [string]$baseline.import_pass_1_manifest_sha256 -cne (Get-Sha256 $pass1Path) -or
    [string]$baseline.import_pass_2_manifest_sha256 -cne (Get-Sha256 $pass2Path) -or
    [string]$baseline.class_cache_sha256 -cne $ExpectedSourceClassCacheSha256) { throw 'Bound import engine result is not a sealed byte-identical Attempt 19 baseline.' }
$receipt = [pscustomobject][ordered]@{
    schema = 'SpaceSyndicatePr90Attempt19ImportControllerReceiptV3'
    status = 'PASS'
    run_id = 'pr90-attempt19-import-controller-001'
    created_at_utc = [DateTimeOffset]::UtcNow.ToString('o')
    product_head_sha = $head
    product_tree_sha = $tree
    import_controller_path = [IO.Path]::GetFullPath($MyInvocation.MyCommand.Path)
    import_controller_sha256 = Get-Sha256 $MyInvocation.MyCommand.Path
    bound_import_engine_path = [IO.Path]::GetFullPath($LegacyImportEnginePath)
    bound_import_engine_sha256 = Get-Sha256 $LegacyImportEnginePath
    worktree_path = $root
    evidence_root = $evidence
    profile_root = $profile
    import_pass1_manifest_path = $pass1Path
    import_pass1_manifest_sha256 = Get-Sha256 $pass1Path
    import_pass2_manifest_path = $pass2Path
    import_pass2_manifest_sha256 = Get-Sha256 $pass2Path
    warmup_log_path = $warmupPath
    warmup_log_sha256 = Get-Sha256 $warmupPath
    sealed_baseline_path = $baselinePath
    sealed_baseline_sha256 = Get-Sha256 $baselinePath
    class_cache_path = $newClassCache
    class_cache_sha256 = Get-Sha256 $newClassCache
    source_class_cache_path = [IO.Path]::GetFullPath($SourceClassCachePath)
    source_class_cache_sha256 = Get-Sha256 $SourceClassCachePath
    class_cache_byte_identical_to_attempt18 = $true
    import_pass1_exit_code = [int]$baseline.import_pass_1_exit_code
    import_pass2_exit_code = [int]$baseline.import_pass_2_exit_code
    import_pass1_2_path_set_parity = [bool]$baseline.import_pass_1_2_path_set_parity
    import_pass1_2_byte_parity = [bool]$baseline.import_pass_1_2_byte_parity
    import_pass2_new_mutation_count = [int]$baseline.import_pass_2_new_mutation_count
    tracked_import_metadata_unknown_count = [int]$baseline.tracked_import_metadata_unknown_count
    post_import_baseline_sealed = [bool]$baseline.post_import_baseline_sealed
    formal_mcp_count = 0
    product_game_count = 0
    canonical_payload_sha256 = ''
}
$receipt.canonical_payload_sha256 = Get-CanonicalPayloadSha256 $receipt
Write-ImmutableJson -Path $OutputReceiptPath -Value $receipt
Write-ImmutableSha256Sidecar -Path $OutputReceiptShaPath -TargetPath $OutputReceiptPath
$receipt | ConvertTo-Json -Depth 100 -Compress
