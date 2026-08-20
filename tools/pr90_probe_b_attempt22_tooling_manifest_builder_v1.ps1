[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ToolingWorktree,
    [Parameter(Mandatory = $true)][string]$ToolingRepository,
    [Parameter(Mandatory = $true)][string]$ToolingRemoteBranch,
    [Parameter(Mandatory = $true)][string]$ProductHeadSha,
    [Parameter(Mandatory = $true)][string]$ProductTreeSha,
    [Parameter(Mandatory = $true)][string]$BaseToolingSealPath,
    [Parameter(Mandatory = $true)][string]$ExpectedBaseToolingSealSha256,
    [Parameter(Mandatory = $true)][string]$BaseSelfTestPath,
    [Parameter(Mandatory = $true)][string]$ExpectedBaseSelfTestSha256,
    [Parameter(Mandatory = $true)][string]$NewSelfTestPath,
    [Parameter(Mandatory = $true)][string]$ExpectedNewSelfTestSha256,
    [Parameter(Mandatory = $true)][string]$PreviousBlockerPath,
    [Parameter(Mandatory = $true)][string]$ExpectedPreviousBlockerSha256,
    [Parameter(Mandatory = $true)][string]$OutputPath
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'pr90_probe_b_attempt22_contract_v1.psm1') -Force
$baseHead='7eda5b355759dbad952beeebd16e3b2d3b20b4f0';$baseTree='41c9cd45e57e987036102dcf10cd1c34385f864b'
$root=(Resolve-Path -LiteralPath $ToolingWorktree).Path;$head=(& git -C $root rev-parse HEAD).Trim();$tree=(& git -C $root rev-parse 'HEAD^{tree}').Trim();$parent=(& git -C $root rev-parse 'HEAD^').Trim()
if($parent-cne$baseHead-or$head-ceq$baseHead-or@(& git -C $root rev-list --count "$baseHead..$head")[0]-ne'1'){throw 'New Tooling commit identity/count mismatch.'}
if(@(& git -C $root status --porcelain=v1 --untracked-files=all).Count-ne0){throw 'New Tooling worktree must be clean.'}
if((Get-Pr90ProbeBSha256 $BaseToolingSealPath)-cne$ExpectedBaseToolingSealSha256-or(Get-Pr90ProbeBSha256 $BaseSelfTestPath)-cne$ExpectedBaseSelfTestSha256-or(Get-Pr90ProbeBSha256 $NewSelfTestPath)-cne$ExpectedNewSelfTestSha256-or(Get-Pr90ProbeBSha256 $PreviousBlockerPath)-cne$ExpectedPreviousBlockerSha256){throw 'Tooling authority evidence hash mismatch.'}
$baseSeal=Get-Content -Raw -LiteralPath $BaseToolingSealPath|ConvertFrom-Json -Depth 100
$baseManifest=Get-Content -Raw -LiteralPath $baseSeal.manifest_path|ConvertFrom-Json -Depth 100
$baseMismatches=[Collections.Generic.List[string]]::new()
foreach($row in @($baseManifest.tooling_files)){$path=Join-Path $root ([string]$row.relative_path);if(-not(Test-Path -LiteralPath $path -PathType Leaf)-or(Get-Pr90ProbeBSha256 $path)-cne[string]$row.sha256){$baseMismatches.Add([string]$row.relative_path)}}
$newSelfTest=Get-Content -Raw -LiteralPath $NewSelfTestPath|ConvertFrom-Json -Depth 100
$newNames=@('pr90_probe_b_attempt22_contract_v1.psm1','pr90_exact_clone_probe_b_controller_v1.ps1','pr90_exact_clone_probe_b_result_builder_v1.ps1','pr90_exact_clone_probe_b_attestation_builder_v1.ps1','pr90_probe_b_import_finalizer_binding_v1.ps1','pr90_attempt22_preformal_dry_run_v2.ps1','pr90_attempt22_authorization_manifest_builder_v4.ps1','pr90_attempt22_authorization_validator_v4.ps1','pr90_attempt22_authorization_seal_builder_v4.ps1','pr90_probe_b_attempt22_selftest_v1.ps1','pr90_probe_b_attempt22_tooling_manifest_builder_v1.ps1','pr90_probe_b_attempt22_tooling_seal_builder_v1.ps1')
$expectedNewPaths=@($newNames|ForEach-Object{"tools/$_"}|Sort-Object)
$diffRows=[Collections.Generic.List[object]]::new()
foreach($line in @(& git -C $root diff --name-status --find-renames=0 "$baseHead..$head" --)){$parts=([string]$line).Split("`t");if($parts.Count-ge2){$diffRows.Add([pscustomobject][ordered]@{status=[string]$parts[0];path=([string]$parts[1]).Replace('\','/')})}}
$actualDiffPaths=@($diffRows.path|Sort-Object)
$scopeGreen=$diffRows.Count-eq12-and@($diffRows|Where-Object{[string]$_.status-cne'A'}).Count-eq0-and[Collections.StructuralComparisons]::StructuralEqualityComparer.Equals([object[]]$actualDiffPaths,[object[]]$expectedNewPaths)
$scopeViolationCount=if($scopeGreen){0}else{1}
$productCodeChangeCount=@($diffRows|Where-Object{[string]$_.path-notlike'tools/*'}).Count
$productTestChangeCount=@($diffRows|Where-Object{[string]$_.path-match'(^|/)(?:test|tests)/|(?:_test|\.test)\.'}).Count
$allRelative=@(@($baseManifest.tooling_files|ForEach-Object{[string]$_.relative_path})+@($newNames|ForEach-Object{"tools/$_"})|Sort-Object -Unique)
$rows=[Collections.Generic.List[object]]::new();$mismatchCount=0
foreach($relative in $allRelative){$path=Join-Path $root $relative;if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Missing Tooling file: $relative"};$blob=(& git -C $root rev-parse "HEAD:$relative").Trim();if($LASTEXITCODE-ne0){throw "Tooling file is not committed: $relative"};$workingBlob=(& git -C $root hash-object -- $relative).Trim();if($blob-cne$workingBlob){$mismatchCount+=1};$rows.Add([pscustomobject][ordered]@{relative_path=$relative;path=[IO.Path]::GetFullPath($path);sha256=Get-Pr90ProbeBSha256 $path;byte_count=(Get-Item -LiteralPath $path).Length;git_blob_sha=$blob})}
$inventory=Get-Pr90ProbeBFileInventoryV1 -Paths @($rows.path)
$missingContractCount=if($scopeGreen){0}else{8}
$eligible=Test-Pr90ProbeBToolingEligibilityV1 -MissingContractCount $missingContractCount -BaseSelfTestPassCount ([int]$newSelfTest.base_selftest_pass_count) -NewSelfTestPassCount ([int]$newSelfTest.new_selftest_pass_count) -NewSelfTestCaseCount ([int]$newSelfTest.new_selftest_case_count) -FailureCount ([int]$newSelfTest.new_selftest_failure_count) -PowerShellParseErrorCount ([int]$newSelfTest.powershell_parse_error_count) -ParameterBindingExceptionCount ([int]$newSelfTest.powershell_parameter_binding_exception_count)
if($baseMismatches.Count-ne0-or$mismatchCount-ne0-or-not$scopeGreen-or$productCodeChangeCount-ne0-or$productTestChangeCount-ne0){$eligible=$false}
$manifest=[pscustomobject][ordered]@{schema='Pr90ProbeBAttempt22ToolingManifestV1';status=if($eligible){'READY'}else{'BLOCKED'};created_at_utc=[DateTimeOffset]::UtcNow.ToString('o');product_head_sha=$ProductHeadSha;product_tree_sha=$ProductTreeSha;authorized_probe_scene_path='res://scenes/runtime/ActionResultPresentationService.tscn';authorized_probe_scene_sha256='f3a1fb397e820adb4beddc0f641e7c77173b1e4f6fe609796a8887cabdf8adc8';tooling_repository=$ToolingRepository;tooling_remote_branch=$ToolingRemoteBranch;tooling_head_sha=$head;tooling_tree_sha=$tree;tooling_parent_sha=$parent;base_tooling_head_sha=$baseHead;base_tooling_tree_sha=$baseTree;base_tooling_seal_path=[IO.Path]::GetFullPath($BaseToolingSealPath);base_tooling_seal_sha256=Get-Pr90ProbeBSha256 $BaseToolingSealPath;previous_blocker_sha256=Get-Pr90ProbeBSha256 $PreviousBlockerPath;missing_contract_count_before=8;missing_contract_count_after=$missingContractCount;startup_probe_b_authorization_eligible=[bool]$eligible;eligibility_derivation='exact 12-file added-only diff AND missing_contract_count=0 AND base_selftest=104/104 AND new_selftest>=30/all-pass AND parse/binding/failure=0 AND file hashes exact';new_tooling_diff_count=$diffRows.Count;new_tooling_diff=@($diffRows);tooling_scope_violation_count=$scopeViolationCount;product_code_change_count=$productCodeChangeCount;product_test_change_count=$productTestChangeCount;base_tooling_file_hash_mismatch_count=$baseMismatches.Count;tooling_file_hash_mismatch_count=$mismatchCount;base_selftest_path=[IO.Path]::GetFullPath($BaseSelfTestPath);base_selftest_sha256=Get-Pr90ProbeBSha256 $BaseSelfTestPath;base_selftest_case_count=104;base_selftest_pass_count=104;new_selftest_path=[IO.Path]::GetFullPath($NewSelfTestPath);new_selftest_sha256=Get-Pr90ProbeBSha256 $NewSelfTestPath;new_selftest_case_count=[int]$newSelfTest.new_selftest_case_count;new_selftest_pass_count=[int]$newSelfTest.new_selftest_pass_count;new_selftest_failure_count=[int]$newSelfTest.new_selftest_failure_count;total_selftest_pass_count=[int]$newSelfTest.total_selftest_pass_count;total_selftest_failure_count=[int]$newSelfTest.total_selftest_failure_count;authorization_negative_test_count=[int]$newSelfTest.authorization_negative_test_count;authorization_negative_test_pass_count=[int]$newSelfTest.authorization_negative_test_pass_count;authorization_negative_test_fail_count=[int]$newSelfTest.authorization_negative_test_fail_count;tooling_file_count=$rows.Count;tooling_files=@($rows);tooling_file_hash_inventory_sha256=$inventory.inventory_sha256;probe_b_controller_sha256=Get-Pr90ProbeBSha256 (Join-Path $root 'tools/pr90_exact_clone_probe_b_controller_v1.ps1');probe_b_result_builder_sha256=Get-Pr90ProbeBSha256 (Join-Path $root 'tools/pr90_exact_clone_probe_b_result_builder_v1.ps1');probe_b_attestation_builder_sha256=Get-Pr90ProbeBSha256 (Join-Path $root 'tools/pr90_exact_clone_probe_b_attestation_builder_v1.ps1');probe_b_finalizer_binding_sha256=Get-Pr90ProbeBSha256 (Join-Path $root 'tools/pr90_probe_b_import_finalizer_binding_v1.ps1');preformal_v2_controller_sha256=Get-Pr90ProbeBSha256 (Join-Path $root 'tools/pr90_attempt22_preformal_dry_run_v2.ps1');attempt22_builder_sha256=Get-Pr90ProbeBSha256 (Join-Path $root 'tools/pr90_attempt22_authorization_manifest_builder_v4.ps1');attempt22_validator_sha256=Get-Pr90ProbeBSha256 (Join-Path $root 'tools/pr90_attempt22_authorization_validator_v4.ps1');attempt22_seal_builder_sha256=Get-Pr90ProbeBSha256 (Join-Path $root 'tools/pr90_attempt22_authorization_seal_builder_v4.ps1');import_runner_sha256=Get-Pr90ProbeBSha256 (Join-Path $root 'tools/pr90_attempt19_import_runner_v3.ps1');formal_mcp_execution_count=0;canonical_payload_sha256=''}
$manifest.canonical_payload_sha256=Get-Pr90ProbeBCanonicalSha256 $manifest
Write-Pr90ProbeBImmutableJson -Path $OutputPath -Value $manifest -WriteSha256Sidecar|Out-Null
$manifest|ConvertTo-Json -Depth 100 -Compress
if(-not$eligible){exit 2}
