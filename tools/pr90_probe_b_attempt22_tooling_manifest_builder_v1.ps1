[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ToolingWorktree,
    [Parameter(Mandatory=$true)][string]$ToolingRepository,
    [Parameter(Mandatory=$true)][string]$ToolingRemoteBranch,
    [Parameter(Mandatory=$true)][string]$ProductHeadSha,
    [Parameter(Mandatory=$true)][string]$ProductTreeSha,
    [Parameter(Mandatory=$true)][string]$BaseToolingManifestPath,
    [Parameter(Mandatory=$true)][string]$ExpectedBaseToolingManifestSha256,
    [Parameter(Mandatory=$true)][string]$BaseToolingSealPath,
    [Parameter(Mandatory=$true)][string]$ExpectedBaseToolingSealSha256,
    [Parameter(Mandatory=$true)][string]$BaseSelfTestPath,
    [Parameter(Mandatory=$true)][string]$ExpectedBaseSelfTestSha256,
    [Parameter(Mandatory=$true)][string]$NewSelfTestPath,
    [Parameter(Mandatory=$true)][string]$ExpectedNewSelfTestSha256,
    [Parameter(Mandatory=$true)][string]$ListenerForensicsPath,
    [Parameter(Mandatory=$true)][string]$ExpectedListenerForensicsSha256,
    [Parameter(Mandatory=$true)][string]$FrozenInputInventoryPath,
    [Parameter(Mandatory=$true)][string]$ExpectedFrozenInputInventorySha256,
    [Parameter(Mandatory=$true)][string]$OutputPath
)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'pr90_probe_b_attempt22_contract_v1.psm1') -Force
$baseHead='2ebb2df9a1c649e8527b045939e9d6e47b98f17c';$baseTree='c8c8df008ca8af433b95e6fe092e02fb03d2cda0'
$root=(Resolve-Path -LiteralPath $ToolingWorktree).Path
$head=(& git -C $root rev-parse HEAD).Trim();$tree=(& git -C $root rev-parse 'HEAD^{tree}').Trim();$parent=(& git -C $root rev-parse 'HEAD^').Trim()
if($parent-cne$baseHead-or$head-ceq$baseHead-or@(& git -C $root rev-list --count "$baseHead..$head")[0]-ne'1'){throw 'Result recovery Tooling commit identity/count mismatch.'}
if(@(& git -C $root status --porcelain=v1 --untracked-files=all).Count-ne0){throw 'Result recovery Tooling worktree must be clean.'}
$bindings=@(
    @($BaseToolingManifestPath,$ExpectedBaseToolingManifestSha256),@($BaseToolingSealPath,$ExpectedBaseToolingSealSha256),@($BaseSelfTestPath,$ExpectedBaseSelfTestSha256),
    @($NewSelfTestPath,$ExpectedNewSelfTestSha256),@($ListenerForensicsPath,$ExpectedListenerForensicsSha256),@($FrozenInputInventoryPath,$ExpectedFrozenInputInventorySha256)
)
foreach($binding in $bindings){if((Get-Pr90ProbeBSha256 ([string]$binding[0]))-cne([string]$binding[1]).ToLowerInvariant()){throw "Result recovery authority evidence hash mismatch: $($binding[0])"}}
$baseManifest=Get-Content -Raw -LiteralPath $BaseToolingManifestPath|ConvertFrom-Json -Depth 100
$baseSeal=Get-Content -Raw -LiteralPath $BaseToolingSealPath|ConvertFrom-Json -Depth 100
$baseSelfTest=Get-Content -Raw -LiteralPath $BaseSelfTestPath|ConvertFrom-Json -Depth 100
$newSelfTest=Get-Content -Raw -LiteralPath $NewSelfTestPath|ConvertFrom-Json -Depth 100
$forensics=Get-Content -Raw -LiteralPath $ListenerForensicsPath|ConvertFrom-Json -Depth 100
$frozenInput=Get-Content -Raw -LiteralPath $FrozenInputInventoryPath|ConvertFrom-Json -Depth 100
if([string]$baseManifest.schema-cne'Pr90ListenerParityV2ToolingManifestV1'-or[string]$baseManifest.status-cne'READY'-or[string]$baseManifest.tooling_head_sha-cne$baseHead-or[string]$baseManifest.tooling_tree_sha-cne$baseTree-or[string]$baseSeal.schema-cne'Pr90ListenerParityV2ToolingSealV1'-or[string]$baseSeal.status-cne'SEALED'-or[string]$baseSeal.manifest_sha256-cne$ExpectedBaseToolingManifestSha256){throw 'Frozen 2ebb Tooling authority contract mismatch.'}
if([string]$baseSelfTest.status-cne'PASS'-or[int]$baseSelfTest.total_tooling_selftest_pass_count-ne230-or[int]$baseSelfTest.total_tooling_selftest_failure_count-ne0){throw 'Frozen 2ebb Tooling self-test is not 230/230.'}
if([string]$newSelfTest.schema-cne'Pr90ProbeBV2ResultRecoveryToolingSelfTestV1'-or[string]$newSelfTest.status-cne'PASS'-or[int]$newSelfTest.base_tooling_selftest_pass_count-ne230-or[int]$newSelfTest.new_selftest_case_count-lt40-or[int]$newSelfTest.new_selftest_pass_count-ne[int]$newSelfTest.new_selftest_case_count-or[int]$newSelfTest.total_tooling_selftest_failure_count-ne0-or[int]$newSelfTest.powershell_parse_error_count-ne0-or[int]$newSelfTest.powershell_parameter_binding_exception_count-ne0){throw 'Result recovery self-test contract mismatch.'}
if([string]$forensics.status-cne'ROOT_CAUSE_RESOLVED'-or[int]$forensics.sample_count-ne23-or[string]$forensics.root_cause_class-cne'J'-or[bool]$forensics.characterization_probe_required){throw 'Frozen listener forensics contract mismatch.'}
if([string]$frozenInput.schema-cne'Pr90ProbeBV2FrozenInputInventoryV1'-or[string]$frozenInput.status-cne'FROZEN'-or[string]$frozenInput.tooling_head_sha-cne$head-or[string]$frozenInput.tooling_tree_sha-cne$tree-or
   [string]$frozenInput.inventory_builder_sha256-cne(Get-Pr90ProbeBSha256 (Join-Path $root 'tools/pr90_probe_b_v2_frozen_input_inventory_builder_v1.ps1'))-or[string]$frozenInput.contract_module_sha256-cne(Get-Pr90ProbeBSha256 (Join-Path $root 'tools/pr90_probe_b_attempt22_contract_v1.psm1'))-or
   [int]$frozenInput.input_count-ne241-or[string]$frozenInput.input_inventory_sha256-cne'af5e309da4a512bbee1cdf3118e69ac243782715484757410702234f75d94f50'){throw 'Frozen recovery input inventory mismatch.'}
$modified=@(
 'tools/pr90_attempt22_authorization_manifest_builder_v4.ps1','tools/pr90_attempt22_authorization_seal_builder_v4.ps1','tools/pr90_attempt22_authorization_validator_v4.ps1','tools/pr90_attempt22_preformal_dry_run_v2.ps1',
 'tools/pr90_exact_clone_probe_b_attestation_builder_v1.ps1','tools/pr90_exact_clone_probe_b_result_builder_v1.ps1','tools/pr90_probe_b_attempt22_contract_v1.psm1','tools/pr90_probe_b_attempt22_selftest_v1.ps1',
 'tools/pr90_probe_b_attempt22_tooling_manifest_builder_v1.ps1','tools/pr90_probe_b_attempt22_tooling_seal_builder_v1.ps1'
)
$added=@('tools/pr90_exact_clone_probe_b_postrun_recovery_controller_v1.ps1','tools/pr90_probe_b_v2_frozen_input_inventory_builder_v1.ps1')
$expectedStatus=@{};foreach($path in $modified){$expectedStatus[$path]='M'};foreach($path in $added){$expectedStatus[$path]='A'}
$diffRows=[Collections.Generic.List[object]]::new()
foreach($line in @(& git -C $root diff --name-status --find-renames=0 "$baseHead..$head" --)){$parts=([string]$line).Split("`t");if($parts.Count-ge2){$diffRows.Add([pscustomobject][ordered]@{status=[string]$parts[0];relative_path=([string]$parts[1]).Replace('\','/')})}}
$scopeErrors=[Collections.Generic.List[string]]::new();$actualPaths=@($diffRows.relative_path|Sort-Object);$expectedPaths=@($expectedStatus.Keys|Sort-Object)
if($diffRows.Count-ne$expectedStatus.Count){$scopeErrors.Add('DIFF_COUNT_MISMATCH')}
foreach($row in $diffRows){if(-not$expectedStatus.ContainsKey([string]$row.relative_path)-or[string]$row.status-cne[string]$expectedStatus[[string]$row.relative_path]){$scopeErrors.Add("DIFF_SCOPE_MISMATCH:$($row.status):$($row.relative_path)")}}
foreach($path in $expectedPaths){if($actualPaths-cnotcontains$path){$scopeErrors.Add("MISSING_DIFF:$path")}}
$allRelative=@(@($baseManifest.tooling_files|ForEach-Object{([string]$_.relative_path).Replace('\','/')})+@($added)|Sort-Object -Unique)
$rows=[Collections.Generic.List[object]]::new();$worktreeBlobMismatch=0
foreach($relative in $allRelative){$path=Join-Path $root $relative;if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Missing Tooling file: $relative"};$blob=(& git -C $root rev-parse "HEAD:$relative").Trim();$workingBlob=(& git -C $root hash-object -- $relative).Trim();if($blob-cne$workingBlob){$worktreeBlobMismatch+=1};$rows.Add([pscustomobject][ordered]@{relative_path=$relative;path=[IO.Path]::GetFullPath($path);sha256=Get-Pr90ProbeBSha256 $path;byte_count=(Get-Item -LiteralPath $path).Length;git_blob_sha=$blob})}
$inventory=Get-Pr90ProbeBFileInventoryV1 -Paths @($rows.path)
$runtimeReachable=@('tools/launch_role_godot_mcp.ps1','tools/stop_role_godot_mcp.ps1','tools/pr90_attempt19_import_controller_v3.ps1','tools/pr90_attempt19_import_runner_v3.ps1','tools/pr90_attempt19_import_finalizer_dry_run.ps1','tools/pr90_attempt21_mcp_startup_probe.ps1','tools/pr90_attempt21_mcp_startup_watchdog.ps1','tools/pr90_mcp_startup_state_machine_v1.psm1','tools/pr90_attempt21_mcp_startup_contract.psm1','tools/pr90_getnettcp_listener_adapter_v1.psm1','tools/pr90_netstat_listener_adapter_v1.psm1','tools/pr90_endpoint_listener_core_v2.psm1','tools/pr90_listener_bracketed_cohort_v2.psm1','tools/pr90_listener_process_identity_reader_v1.psm1','tools/pr90_mcp_endpoint_ownership_v2.psm1','tools/pr90_m5_listener_parity_v2_contract.psm1','tools/pr90_attempt21_cursor_aware_exact_mcp_v5.ps1','tools/pr90_probe_b_import_finalizer_binding_v1.ps1')
$runtimeMismatch=[Collections.Generic.List[string]]::new()
foreach($relative in $runtimeReachable){$baseRow=@($baseManifest.tooling_files|Where-Object{([string]$_.relative_path).Replace('\','/')-ceq$relative});$newRow=@($rows|Where-Object{[string]$_.relative_path-ceq$relative});if($baseRow.Count-ne1-or$newRow.Count-ne1-or[string]$baseRow[0].sha256-cne[string]$newRow[0].sha256){$runtimeMismatch.Add($relative)}}
$productCodeChangeCount=@($diffRows|Where-Object{[string]$_.relative_path-notlike'tools/*'}).Count;$productTestChangeCount=@($diffRows|Where-Object{[string]$_.relative_path-match'(^|/)(?:test|tests)/|(?:_test|\.test)\.'}).Count
$eligible=($scopeErrors.Count-eq0-and$worktreeBlobMismatch-eq0-and$runtimeMismatch.Count-eq0-and$productCodeChangeCount-eq0-and$productTestChangeCount-eq0)
$getHash={param($relative)Get-Pr90ProbeBSha256 (Join-Path $root $relative)}
$manifest=[pscustomobject][ordered]@{
 schema='Pr90ProbeBV2ResultRecoveryToolingManifestV1';status=if($eligible){'READY'}else{'BLOCKED'};created_at_utc=[DateTimeOffset]::UtcNow.ToString('o');product_head_sha=$ProductHeadSha;product_tree_sha=$ProductTreeSha
 tooling_repository=$ToolingRepository;tooling_remote_branch=$ToolingRemoteBranch;tooling_head_sha=$head;tooling_tree_sha=$tree;tooling_parent_sha=$parent;base_tooling_head_sha=$baseHead;base_tooling_tree_sha=$baseTree
 base_tooling_manifest_path=[IO.Path]::GetFullPath($BaseToolingManifestPath);base_tooling_manifest_sha256=Get-Pr90ProbeBSha256 $BaseToolingManifestPath;base_tooling_seal_path=[IO.Path]::GetFullPath($BaseToolingSealPath);base_tooling_seal_sha256=Get-Pr90ProbeBSha256 $BaseToolingSealPath
 frozen_input_inventory_path=[IO.Path]::GetFullPath($FrozenInputInventoryPath);frozen_input_inventory_sha256=Get-Pr90ProbeBSha256 $FrozenInputInventoryPath;frozen_input_count=[int]$frozenInput.input_count;frozen_input_hash_inventory_sha256=[string]$frozenInput.input_inventory_sha256
 listener_forensics_path=[IO.Path]::GetFullPath($ListenerForensicsPath);listener_forensics_sha256=Get-Pr90ProbeBSha256 $ListenerForensicsPath;listener_parity_root_cause_class='J';characterization_probe_execution_count=0
 listener_parity_contract_version=2;listener_core_normalizer_sha256=&$getHash 'tools/pr90_endpoint_listener_core_v2.psm1';listener_parity_comparator_sha256=&$getHash 'tools/pr90_endpoint_listener_core_v2.psm1';bracketed_cohort_controller_sha256=&$getHash 'tools/pr90_listener_bracketed_cohort_v2.psm1';process_identity_enricher_sha256=&$getHash 'tools/pr90_listener_process_identity_reader_v1.psm1';endpoint_ownership_validator_sha256=&$getHash 'tools/pr90_mcp_endpoint_ownership_v2.psm1';failure_cleanup_sha256=&$getHash 'tools/pr90_mcp_startup_state_machine_v1.psm1';startup_contract_sha256=&$getHash 'tools/pr90_attempt21_mcp_startup_contract.psm1';startup_watchdog_sha256=&$getHash 'tools/pr90_attempt21_mcp_startup_watchdog.ps1';startup_state_machine_sha256=&$getHash 'tools/pr90_mcp_startup_state_machine_v1.psm1'
 probe_b_controller_sha256=&$getHash 'tools/pr90_exact_clone_probe_b_controller_v1.ps1';probe_b_result_builder_sha256=&$getHash 'tools/pr90_exact_clone_probe_b_result_builder_v1.ps1';probe_b_attestation_builder_sha256=&$getHash 'tools/pr90_exact_clone_probe_b_attestation_builder_v1.ps1';probe_b_recovery_controller_sha256=&$getHash 'tools/pr90_exact_clone_probe_b_postrun_recovery_controller_v1.ps1';probe_b_recovery_contract_module_sha256=&$getHash 'tools/pr90_probe_b_attempt22_contract_v1.psm1';probe_b_frozen_input_inventory_builder_sha256=&$getHash 'tools/pr90_probe_b_v2_frozen_input_inventory_builder_v1.ps1'
 base_selftest_path=[IO.Path]::GetFullPath($BaseSelfTestPath);base_selftest_sha256=Get-Pr90ProbeBSha256 $BaseSelfTestPath;base_selftest_pass_count=230;new_selftest_path=[IO.Path]::GetFullPath($NewSelfTestPath);new_selftest_sha256=Get-Pr90ProbeBSha256 $NewSelfTestPath;new_selftest_case_count=[int]$newSelfTest.new_selftest_case_count;new_selftest_pass_count=[int]$newSelfTest.new_selftest_pass_count;total_selftest_pass_count=[int]$newSelfTest.total_tooling_selftest_pass_count;total_selftest_failure_count=[int]$newSelfTest.total_tooling_selftest_failure_count
 new_tooling_commit_count=1;new_tooling_diff_count=$diffRows.Count;new_tooling_modified_count=@($diffRows|Where-Object{$_.status-ceq'M'}).Count;new_tooling_added_count=@($diffRows|Where-Object{$_.status-ceq'A'}).Count;new_tooling_diff=@($diffRows);tooling_scope_violation_count=$scopeErrors.Count;tooling_scope_errors=@($scopeErrors);product_code_change_count=$productCodeChangeCount;product_test_change_count=$productTestChangeCount;tooling_file_hash_mismatch_count=$worktreeBlobMismatch
 runtime_reachable_tooling_file_count=$runtimeReachable.Count;runtime_reachable_tooling_hash_mismatch_count=$runtimeMismatch.Count;runtime_reachable_tooling_hash_mismatches=@($runtimeMismatch)
 tooling_file_count=$rows.Count;tooling_files=@($rows);tooling_file_hash_inventory_sha256=$inventory.inventory_sha256;startup_probe_b_authorization_eligible=$false;preformal_authorization_eligible=[bool]$eligible;probe_execution_count_delta=0;formal_mcp_execution_count=0;canonical_payload_sha256=''
}
$manifest.canonical_payload_sha256=Get-Pr90ProbeBCanonicalSha256 $manifest
Write-Pr90ProbeBImmutableJson -Path $OutputPath -Value $manifest -WriteSha256Sidecar|Out-Null
$manifest|ConvertTo-Json -Depth 100 -Compress
if(-not$eligible){exit 2}
