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
    [Parameter(Mandatory=$true)][string]$FrozenProbeBResultPath,
    [Parameter(Mandatory=$true)][string]$ExpectedFrozenProbeBResultSha256,
    [Parameter(Mandatory=$true)][string]$OutputPath
)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'pr90_probe_b_attempt22_contract_v1.psm1') -Force
$baseHead='c9508c47f0aec647151dfb4ae58a720014ab3702';$baseTree='59e25856a0f1e4508789ca3fb278d26104621602'
$root=(Resolve-Path -LiteralPath $ToolingWorktree).Path
$head=(& git -C $root rev-parse HEAD).Trim();$tree=(& git -C $root rev-parse 'HEAD^{tree}').Trim();$parent=(& git -C $root rev-parse 'HEAD^').Trim()
if($parent-cne$baseHead-or$head-ceq$baseHead-or@(& git -C $root rev-list --count "$baseHead..$head")[0]-ne'1'){throw 'Listener Parity V2 Tooling commit identity/count mismatch.'}
if(@(& git -C $root status --porcelain=v1 --untracked-files=all).Count-ne0){throw 'Listener Parity V2 Tooling worktree must be clean.'}
$evidenceBindings=@(
    @($BaseToolingManifestPath,$ExpectedBaseToolingManifestSha256),@($BaseToolingSealPath,$ExpectedBaseToolingSealSha256),@($BaseSelfTestPath,$ExpectedBaseSelfTestSha256),
    @($NewSelfTestPath,$ExpectedNewSelfTestSha256),@($ListenerForensicsPath,$ExpectedListenerForensicsSha256),@($FrozenProbeBResultPath,$ExpectedFrozenProbeBResultSha256)
)
foreach($binding in $evidenceBindings){if((Get-Pr90ProbeBSha256 ([string]$binding[0]))-cne([string]$binding[1]).ToLowerInvariant()){throw "Tooling authority evidence hash mismatch: $($binding[0])"}}
$baseManifest=Get-Content -Raw -LiteralPath $BaseToolingManifestPath|ConvertFrom-Json -Depth 100
$baseSeal=Get-Content -Raw -LiteralPath $BaseToolingSealPath|ConvertFrom-Json -Depth 100
$baseSelfTest=Get-Content -Raw -LiteralPath $BaseSelfTestPath|ConvertFrom-Json -Depth 100
$newSelfTest=Get-Content -Raw -LiteralPath $NewSelfTestPath|ConvertFrom-Json -Depth 100
$forensics=Get-Content -Raw -LiteralPath $ListenerForensicsPath|ConvertFrom-Json -Depth 100
$frozenProbeB=Get-Content -Raw -LiteralPath $FrozenProbeBResultPath|ConvertFrom-Json -Depth 100
if([string]$baseManifest.status-cne'READY'-or[string]$baseManifest.tooling_head_sha-cne$baseHead-or[string]$baseManifest.tooling_tree_sha-cne$baseTree-or[string]$baseSeal.status-cne'SEALED'-or[string]$baseSeal.manifest_sha256-cne$ExpectedBaseToolingManifestSha256){throw 'Frozen c950 Tooling authority contract mismatch.'}
if([string]$baseSelfTest.status-cne'PASS'-or[int]$baseSelfTest.total_selftest_pass_count-ne170-or[int]$baseSelfTest.total_selftest_failure_count-ne0){throw 'Frozen base Tooling self-test is not 170/170.'}
if([string]$newSelfTest.status-cne'PASS'-or[int]$newSelfTest.base_tooling_selftest_pass_count-ne170-or[int]$newSelfTest.new_listener_parity_selftest_count-lt41-or[int]$newSelfTest.new_listener_parity_selftest_pass_count-ne[int]$newSelfTest.new_listener_parity_selftest_count-or[int]$newSelfTest.total_tooling_selftest_pass_count-lt211-or[int]$newSelfTest.total_tooling_selftest_failure_count-ne0-or[int]$newSelfTest.powershell_parse_error_count-ne0-or[int]$newSelfTest.powershell_parameter_binding_exception_count-ne0){throw 'Listener Parity V2 self-test contract mismatch.'}
if([string]$forensics.status-cne'ROOT_CAUSE_RESOLVED'-or[int]$forensics.sample_count-ne23-or[int]$forensics.old_parity_count-ne0-or[int]$forensics.listener_core_equal_sample_count-ne23-or[string]$forensics.root_cause_class-cne'J'-or[bool]$forensics.characterization_probe_required-or[int]$forensics.characterization_probe_execution_count-ne0){throw 'Frozen listener forensics contract mismatch.'}
if([string]$frozenProbeB.schema-cne'Pr90ExactCloneProbeBResultV1'-or[string]$frozenProbeB.probe_id-cne'pr90-exact-clone-startup-probe-b-001'-or[string]$frozenProbeB.status-cne'BLOCKED'-or[int]$frozenProbeB.milestone_pass_count-ne5-or[string]$frozenProbeB.import_finalizer_status-cne'PASS'){throw 'Frozen Probe B blocker identity/disposition mismatch.'}
$modified=@(
 'tools/pr90_attempt21_mcp_startup_contract.psm1','tools/pr90_attempt22_authorization_manifest_builder_v4.ps1','tools/pr90_attempt22_authorization_seal_builder_v4.ps1','tools/pr90_attempt22_authorization_validator_v4.ps1','tools/pr90_attempt22_preformal_dry_run_v2.ps1',
 'tools/pr90_exact_clone_probe_b_attestation_builder_v1.ps1','tools/pr90_exact_clone_probe_b_controller_v1.ps1','tools/pr90_exact_clone_probe_b_result_builder_v1.ps1','tools/pr90_getnettcp_listener_adapter_v1.psm1',
 'tools/pr90_mcp_endpoint_ownership_v2.psm1','tools/pr90_mcp_startup_state_machine_v1.psm1','tools/pr90_netstat_listener_adapter_v1.psm1','tools/pr90_probe_b_attempt22_contract_v1.psm1',
 'tools/pr90_probe_b_attempt22_tooling_manifest_builder_v1.ps1','tools/pr90_probe_b_attempt22_tooling_seal_builder_v1.ps1'
)
$added=@('tools/pr90_endpoint_listener_core_v2.psm1','tools/pr90_listener_bracketed_cohort_v2.psm1','tools/pr90_listener_parity_v2_selftest.ps1','tools/pr90_m5_listener_parity_v2_contract.psm1')
$expectedStatus=@{};foreach($path in $modified){$expectedStatus[$path]='M'};foreach($path in $added){$expectedStatus[$path]='A'}
$diffRows=[Collections.Generic.List[object]]::new()
foreach($line in @(& git -C $root diff --name-status --find-renames=0 "$baseHead..$head" --)){$parts=([string]$line).Split("`t");if($parts.Count-ge2){$diffRows.Add([pscustomobject][ordered]@{status=[string]$parts[0];relative_path=([string]$parts[1]).Replace('\','/')})}}
$actualPaths=@($diffRows.relative_path|Sort-Object);$expectedPaths=@($expectedStatus.Keys|Sort-Object)
$scopeErrors=[Collections.Generic.List[string]]::new()
if($diffRows.Count-ne$expectedStatus.Count){$scopeErrors.Add('DIFF_COUNT_MISMATCH')}
foreach($row in $diffRows){if(-not$expectedStatus.ContainsKey([string]$row.relative_path)-or[string]$row.status-cne[string]$expectedStatus[[string]$row.relative_path]){$scopeErrors.Add("DIFF_SCOPE_MISMATCH:$($row.status):$($row.relative_path)")}}
foreach($path in $expectedPaths){if($actualPaths-cnotcontains$path){$scopeErrors.Add("MISSING_DIFF:$path")}}
$unchangedMismatch=[Collections.Generic.List[string]]::new()
foreach($row in @($baseManifest.tooling_files)){$relative=([string]$row.relative_path).Replace('\','/');if($modified-ccontains$relative){continue};$path=Join-Path $root $relative;if(-not(Test-Path -LiteralPath $path -PathType Leaf)-or(Get-Pr90ProbeBSha256 $path)-cne[string]$row.sha256){$unchangedMismatch.Add($relative)}}
$allRelative=@(@($baseManifest.tooling_files|ForEach-Object{([string]$_.relative_path).Replace('\','/')})+@($added)|Sort-Object -Unique)
$rows=[Collections.Generic.List[object]]::new();$worktreeBlobMismatch=0
foreach($relative in $allRelative){$path=Join-Path $root $relative;if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Missing Tooling file: $relative"};$blob=(& git -C $root rev-parse "HEAD:$relative").Trim();$workingBlob=(& git -C $root hash-object -- $relative).Trim();if($blob-cne$workingBlob){$worktreeBlobMismatch+=1};$rows.Add([pscustomobject][ordered]@{relative_path=$relative;path=[IO.Path]::GetFullPath($path);sha256=Get-Pr90ProbeBSha256 $path;byte_count=(Get-Item -LiteralPath $path).Length;git_blob_sha=$blob})}
$inventory=Get-Pr90ProbeBFileInventoryV1 -Paths @($rows.path)
$productCodeChangeCount=@($diffRows|Where-Object{[string]$_.relative_path-notlike'tools/*'}).Count
$productTestChangeCount=@($diffRows|Where-Object{[string]$_.relative_path-match'(^|/)(?:test|tests)/|(?:_test|\.test)\.'}).Count
$eligible=($scopeErrors.Count-eq0-and$unchangedMismatch.Count-eq0-and$worktreeBlobMismatch-eq0-and$productCodeChangeCount-eq0-and$productTestChangeCount-eq0)
$getHash={param($relative)Get-Pr90ProbeBSha256 (Join-Path $root $relative)}
$manifest=[pscustomobject][ordered]@{
 schema='Pr90ListenerParityV2ToolingManifestV1';status=if($eligible){'READY'}else{'BLOCKED'};created_at_utc=[DateTimeOffset]::UtcNow.ToString('o');product_head_sha=$ProductHeadSha;product_tree_sha=$ProductTreeSha
 tooling_repository=$ToolingRepository;tooling_remote_branch=$ToolingRemoteBranch;tooling_head_sha=$head;tooling_tree_sha=$tree;tooling_parent_sha=$parent;base_tooling_head_sha=$baseHead;base_tooling_tree_sha=$baseTree
 base_tooling_manifest_path=[IO.Path]::GetFullPath($BaseToolingManifestPath);base_tooling_manifest_sha256=Get-Pr90ProbeBSha256 $BaseToolingManifestPath;base_tooling_seal_path=[IO.Path]::GetFullPath($BaseToolingSealPath);base_tooling_seal_sha256=Get-Pr90ProbeBSha256 $BaseToolingSealPath
 frozen_probe_b_result_path=[IO.Path]::GetFullPath($FrozenProbeBResultPath);frozen_probe_b_result_sha256=Get-Pr90ProbeBSha256 $FrozenProbeBResultPath;listener_forensics_path=[IO.Path]::GetFullPath($ListenerForensicsPath);listener_forensics_sha256=Get-Pr90ProbeBSha256 $ListenerForensicsPath;listener_parity_root_cause_class='J';listener_parity_root_cause_components=@('F_SOURCE_FILTER_SCOPE_MISMATCH','I_LOCALIZED_NETSTAT_OR_SOURCE_PARSER_DRIFT');characterization_probe_execution_count=0
 protected_ports=@(7576,7586);listener_parity_contract_version=2;bracketed_sample_model=$true;listener_core_parity_key_fields=@('address_family','local_address_normalized','local_port','tcp_state_canonical','owning_pid');listener_core_parity_key_field_count=5;observer_specific_field_in_key_count=0;process_enrichment_field_in_key_count=0
 required_total_cohort_attempt_count=5;required_consecutive_stable_parity_cohort_count=5;required_stable_parity_window_ms=1000;source_observer_timeout_ms=1000;cohort_interval_ms=300;sampling_budget_ms=21200;sampling_budget_maximum_ms=30000
 startup_contract_sha256=&$getHash 'tools/pr90_attempt21_mcp_startup_contract.psm1';getnettcp_source_adapter_sha256=&$getHash 'tools/pr90_getnettcp_listener_adapter_v1.psm1';netstat_source_adapter_sha256=&$getHash 'tools/pr90_netstat_listener_adapter_v1.psm1';listener_core_normalizer_sha256=&$getHash 'tools/pr90_endpoint_listener_core_v2.psm1';listener_parity_comparator_sha256=&$getHash 'tools/pr90_endpoint_listener_core_v2.psm1';bracketed_cohort_controller_sha256=&$getHash 'tools/pr90_listener_bracketed_cohort_v2.psm1';process_identity_enricher_sha256=&$getHash 'tools/pr90_listener_process_identity_reader_v1.psm1';endpoint_ownership_validator_sha256=&$getHash 'tools/pr90_mcp_endpoint_ownership_v2.psm1';failure_cleanup_sha256=&$getHash 'tools/pr90_mcp_startup_state_machine_v1.psm1';probe_b_controller_sha256=&$getHash 'tools/pr90_exact_clone_probe_b_controller_v1.ps1';probe_b_result_builder_sha256=&$getHash 'tools/pr90_exact_clone_probe_b_result_builder_v1.ps1';probe_b_attestation_builder_sha256=&$getHash 'tools/pr90_exact_clone_probe_b_attestation_builder_v1.ps1'
 authorized_probe_scene_path='res://scenes/runtime/ActionResultPresentationService.tscn';authorized_probe_scene_sha256='f3a1fb397e820adb4beddc0f641e7c77173b1e4f6fe609796a8887cabdf8adc8';authorized_probe_b_v2_id='pr90-exact-clone-startup-probe-b-v2-001';startup_probe_b_authorization_eligible=[bool]$eligible
 base_selftest_path=[IO.Path]::GetFullPath($BaseSelfTestPath);base_selftest_sha256=Get-Pr90ProbeBSha256 $BaseSelfTestPath;base_selftest_count=170;base_selftest_pass_count=170;new_selftest_path=[IO.Path]::GetFullPath($NewSelfTestPath);new_selftest_sha256=Get-Pr90ProbeBSha256 $NewSelfTestPath;new_listener_parity_selftest_count=[int]$newSelfTest.new_listener_parity_selftest_count;new_listener_parity_selftest_pass_count=[int]$newSelfTest.new_listener_parity_selftest_pass_count;total_selftest_pass_count=[int]$newSelfTest.total_tooling_selftest_pass_count;total_selftest_failure_count=[int]$newSelfTest.total_tooling_selftest_failure_count
 new_tooling_diff_count=$diffRows.Count;new_tooling_modified_count=@($diffRows|Where-Object{$_.status-ceq'M'}).Count;new_tooling_added_count=@($diffRows|Where-Object{$_.status-ceq'A'}).Count;new_tooling_diff=@($diffRows);tooling_scope_violation_count=$scopeErrors.Count;tooling_scope_errors=@($scopeErrors);product_code_change_count=$productCodeChangeCount;product_test_change_count=$productTestChangeCount;base_unchanged_file_hash_mismatch_count=$unchangedMismatch.Count;base_unchanged_file_hash_mismatches=@($unchangedMismatch);tooling_file_hash_mismatch_count=$worktreeBlobMismatch
 tooling_file_count=$rows.Count;tooling_files=@($rows);tooling_file_hash_inventory_sha256=$inventory.inventory_sha256;formal_mcp_execution_count=0;canonical_payload_sha256=''
}
$manifest.canonical_payload_sha256=Get-Pr90ProbeBCanonicalSha256 $manifest
Write-Pr90ProbeBImmutableJson -Path $OutputPath -Value $manifest -WriteSha256Sidecar|Out-Null
$manifest|ConvertTo-Json -Depth 100 -Compress
if(-not$eligible){exit 2}
