[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Worktree,
    [Parameter(Mandatory = $true)][string]$BaselinePath,
    [Parameter(Mandatory = $true)][string]$ClassCachePath,
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [Parameter(Mandatory = $true)][string]$ProductHeadSha,
    [Parameter(Mandatory = $true)][string]$ProductTreeSha,
    [Parameter(Mandatory = $true)][string]$ImportRunnerPath,
    [Parameter(Mandatory = $true)][string]$ExpectedImportRunnerSha256,
    [Parameter(Mandatory = $true)][string]$PrelaunchIgnoredInventoryPath,
    [Parameter(Mandatory = $true)][string]$ExpectedPrelaunchIgnoredInventorySha256,
    [Parameter(Mandatory = $true)][string]$OutputPath
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'pr90_probe_b_attempt22_contract_v1.psm1') -Force
if ((Get-Pr90ProbeBSha256 $ImportRunnerPath) -cne $ExpectedImportRunnerSha256.ToLowerInvariant()) { throw 'Import finalizer runner hash mismatch.' }
Import-Module (Join-Path $PSScriptRoot 'pr90_attempt19_authority_contract.psm1') -Force
$baseline = Get-Content -Raw -LiteralPath $BaselinePath | ConvertFrom-Json -Depth 100
$baselineState = New-FinalizerStateFromBaseline $baseline
if((Get-Pr90ProbeBSha256 $PrelaunchIgnoredInventoryPath)-cne$ExpectedPrelaunchIgnoredInventorySha256){throw 'Prelaunch ignored inventory hash mismatch.'}
$prelaunchInventory=Get-Content -Raw -LiteralPath $PrelaunchIgnoredInventoryPath|ConvertFrom-Json -Depth 100
$prelaunchIgnored=@([string[]]$prelaunchInventory.ignored_paths|Sort-Object -Unique)
$prelaunchGreen=([string]$prelaunchInventory.schema-ceq'Pr90ProbeBPrelaunchIgnoredPathInventoryV1'-and[string]$prelaunchInventory.product_head_sha-ceq$ProductHeadSha-and[string]$prelaunchInventory.product_tree_sha-ceq$ProductTreeSha-and
    [string]$prelaunchInventory.baseline_sha256-ceq(Get-Pr90ProbeBSha256 $BaselinePath)-and[int]$prelaunchInventory.ignored_path_count-eq$prelaunchIgnored.Count-and
    [string]$prelaunchInventory.ignored_path_set_sha256-ceq(Get-Pr90ProbeBStringSetSha256 $prelaunchIgnored)-and[int]$prelaunchInventory.ignored_path_count-eq[int]$baseline.ignored_sidecar_count-and
    [string]$prelaunchInventory.ignored_path_set_sha256-ceq[string]$baseline.ignored_sidecar_path_set_sha256-and[string]$prelaunchInventory.canonical_payload_sha256-ceq(Get-Pr90ProbeBCanonicalSha256 $prelaunchInventory))
$rawStatePath = [IO.Path]::ChangeExtension($OutputPath,'.raw-state.json')
$normalizedStatePath = [IO.Path]::ChangeExtension($OutputPath,'.normalized-state.json')
$runnerOutputPath = [IO.Path]::ChangeExtension($OutputPath,'.runner-result.json')
$rawState = Get-CurrentFinalizerState -Worktree $Worktree
$rawGreen = ([string]$rawState.head_sha -ceq [string]$baselineState.head_sha -and [string]$rawState.tree_sha -ceq [string]$baselineState.tree_sha -and
    [int]$rawState.tracked_non_generated_delta_count -eq 0 -and [string]$rawState.tracked_import_path_set_sha256 -ceq [string]$baselineState.tracked_import_path_set_sha256 -and
    [string]$rawState.tracked_import_byte_map_sha256 -ceq [string]$baselineState.tracked_import_byte_map_sha256 -and
    [string]$rawState.untracked_uid_path_set_sha256 -ceq [string]$baselineState.untracked_uid_path_set_sha256 -and
    [string]$rawState.untracked_uid_byte_map_sha256 -ceq [string]$baselineState.untracked_uid_byte_map_sha256 -and
    [int]$rawState.unknown_untracked_count -eq 0 -and [int]$rawState.unknown_ignored_count -eq 0 -and
    [string]$rawState.class_cache_sha256 -ceq [string]$baselineState.class_cache_sha256)
$ignoredPaths = @(& git -C $Worktree -c core.quotePath=false ls-files -o -i --exclude-standard | ForEach-Object { $_.Replace('\','/') })
if ($LASTEXITCODE -ne 0) { throw 'Unable to inventory ignored finalizer paths.' }
$currentIgnored=@($ignoredPaths|Sort-Object -Unique)
$removedIgnored=@($prelaunchIgnored|Where-Object{$currentIgnored-cnotcontains$_})
$addedIgnored=@($currentIgnored|Where-Object{$prelaunchIgnored-cnotcontains$_})
$allowedAddedIgnored=@($addedIgnored|Where-Object{$_.StartsWith('.codex-godot/',[StringComparison]::Ordinal)-or$_-ceq'.godot/editor/editor_script_doc_cache.res'})
$disallowedAddedIgnored=@($addedIgnored|Where-Object{$allowedAddedIgnored-cnotcontains$_})
$baselineIgnoredSetGreen=$prelaunchGreen-and$removedIgnored.Count-eq0-and$disallowedAddedIgnored.Count-eq0
$rawEnvelope = [pscustomobject][ordered]@{schema='Pr90ProbeBFinalizerRawStateV1';state=$rawState;ignored_paths=$currentIgnored;prelaunch_ignored_inventory_path=[IO.Path]::GetFullPath($PrelaunchIgnoredInventoryPath);prelaunch_ignored_inventory_sha256=Get-Pr90ProbeBSha256 $PrelaunchIgnoredInventoryPath;prelaunch_ignored_paths=$prelaunchIgnored;removed_ignored_paths=$removedIgnored;added_ignored_paths=$addedIgnored;allowed_added_ignored_paths=$allowedAddedIgnored;disallowed_added_ignored_paths=$disallowedAddedIgnored;raw_state_green=$rawGreen;baseline_ignored_path_set_match=$baselineIgnoredSetGreen;allowed_generated_ignored_count=$allowedAddedIgnored.Count;disallowed_ignored_count=$removedIgnored.Count+$disallowedAddedIgnored.Count;canonical_payload_sha256=''}
$rawEnvelope.canonical_payload_sha256=Get-Pr90ProbeBCanonicalSha256 $rawEnvelope
Write-Pr90ProbeBImmutableJson -Path $rawStatePath -Value $rawEnvelope -WriteSha256Sidecar | Out-Null
if(-not$rawGreen-or-not$baselineIgnoredSetGreen){
    $blocked=[pscustomobject][ordered]@{schema='Pr90ProbeBImportFinalizerBindingV1';status='BLOCKED';created_at_utc=[DateTimeOffset]::UtcNow.ToString('o');product_head_sha=$ProductHeadSha;product_tree_sha=$ProductTreeSha;baseline_sha256=Get-Pr90ProbeBSha256 $BaselinePath;class_cache_sha256=Get-Pr90ProbeBSha256 $ClassCachePath;raw_state_path=$rawStatePath;raw_state_sha256=Get-Pr90ProbeBSha256 $rawStatePath;normalized_state_path='';normalized_state_sha256='';allowed_generated_ignored_count=$allowedAddedIgnored.Count;disallowed_ignored_count=$removedIgnored.Count+$disallowedAddedIgnored.Count;baseline_ignored_path_set_match=$baselineIgnoredSetGreen;raw_state_green=$rawGreen;runner_invoked=$false;runner_result_path='';runner_result_sha256='';post_run_non_generated_tracked_delta=[int]$rawState.tracked_non_generated_delta_count;post_run_tracked_import_metadata_delta_from_baseline=-1;post_run_unknown_untracked_count=[int]$rawState.unknown_untracked_count;post_run_unknown_ignored_count=[int]$rawState.unknown_ignored_count;deletion_performed=$false;canonical_payload_sha256=''}
    $blocked.canonical_payload_sha256=Get-Pr90ProbeBCanonicalSha256 $blocked
    Write-Pr90ProbeBImmutableJson -Path $OutputPath -Value $blocked -WriteSha256Sidecar|Out-Null
    $blocked|ConvertTo-Json -Depth 100 -Compress
    exit 2
}
$normalizedState = Copy-Pr90ProbeBJsonObject $rawState
$normalizedState.ignored_sidecar_path_set_sha256 = [string]$baselineState.ignored_sidecar_path_set_sha256
Write-Pr90ProbeBImmutableJson -Path $normalizedStatePath -Value $normalizedState -WriteSha256Sidecar | Out-Null
$runnerShaPath = "$runnerOutputPath.sha256"
$output = @(& (Join-Path $PSHOME 'pwsh.exe') -NoProfile -File $ImportRunnerPath -Mode FinalizeSnapshot -Worktree $Worktree `
    -BaselinePath $BaselinePath -ExpectedBaselineSha256 (Get-Pr90ProbeBSha256 $BaselinePath) -ClassCachePath $ClassCachePath `
    -GodotPath $GodotPath -ExpectedHeadSha $ProductHeadSha -ExpectedTreeSha $ProductTreeSha -OutputPath $runnerOutputPath -OutputShaPath $runnerShaPath -PostStatePath $normalizedStatePath)
$runnerExitCode=$LASTEXITCODE
$receipt=if(Test-Path -LiteralPath $runnerOutputPath -PathType Leaf){Get-Content -Raw -LiteralPath $runnerOutputPath|ConvertFrom-Json -Depth 100}else{$null}
$runnerGreen=$false
$postNonGenerated=-1;$postTrackedImport=-1;$postUnknownUntracked=-1;$postUnknownIgnored=-1
if($null-ne$receipt){
    $postNonGenerated=[int]$receipt.finalizer.post_run_non_generated_tracked_delta
    $postTrackedImport=[int]$receipt.finalizer.post_run_tracked_import_metadata_delta_from_baseline
    $postUnknownUntracked=[int]$receipt.finalizer.post_run_unknown_untracked_count
    $postUnknownIgnored=[int]$receipt.finalizer.post_run_unknown_ignored_count
    $runnerGreen=($runnerExitCode-eq0-and[string]$receipt.status-ceq'PASS'-and$postNonGenerated-eq0-and$postTrackedImport-eq0-and$postUnknownUntracked-eq0-and$postUnknownIgnored-eq0)
}
$binding = [pscustomobject][ordered]@{
    schema='Pr90ProbeBImportFinalizerBindingV1';status=if($runnerGreen){'PASS'}else{'BLOCKED'};created_at_utc=[DateTimeOffset]::UtcNow.ToString('o')
    product_head_sha=$ProductHeadSha;product_tree_sha=$ProductTreeSha;baseline_sha256=Get-Pr90ProbeBSha256 $BaselinePath;class_cache_sha256=Get-Pr90ProbeBSha256 $ClassCachePath
    raw_state_path=$rawStatePath;raw_state_sha256=Get-Pr90ProbeBSha256 $rawStatePath;normalized_state_path=$normalizedStatePath;normalized_state_sha256=Get-Pr90ProbeBSha256 $normalizedStatePath
    allowed_generated_ignored_count=$allowedAddedIgnored.Count;disallowed_ignored_count=0;baseline_ignored_path_set_match=$baselineIgnoredSetGreen;raw_state_green=$rawGreen;runner_invoked=$true;runner_exit_code=$runnerExitCode;runner_result_path=if($null-ne$receipt){$runnerOutputPath}else{''};runner_result_sha256=if($null-ne$receipt){Get-Pr90ProbeBSha256 $runnerOutputPath}else{''}
    post_run_non_generated_tracked_delta=$postNonGenerated;post_run_tracked_import_metadata_delta_from_baseline=$postTrackedImport;post_run_unknown_untracked_count=$postUnknownUntracked;post_run_unknown_ignored_count=$postUnknownIgnored
    deletion_performed=$false;canonical_payload_sha256=''
}
$binding.canonical_payload_sha256=Get-Pr90ProbeBCanonicalSha256 $binding
Write-Pr90ProbeBImmutableJson -Path $OutputPath -Value $binding -WriteSha256Sidecar | Out-Null
$binding | ConvertTo-Json -Depth 100 -Compress
if(-not$runnerGreen){exit 2}
