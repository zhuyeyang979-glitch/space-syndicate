[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ManifestPath,
    [Parameter(Mandatory = $true)][string]$ExpectedManifestSha256,
    [Parameter(Mandatory = $true)][string]$ToolingWorktree,
    [Parameter(Mandatory = $true)][string]$OutputPath
)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'pr90_attempt21_mcp_startup_contract.psm1') -Force
$issues=[Collections.Generic.List[string]]::new();$root=(Resolve-Path -LiteralPath $ToolingWorktree).Path.TrimEnd('\')
if((Get-StartupSha256 $ManifestPath)-cne$ExpectedManifestSha256.ToLowerInvariant()){$issues.Add('MANIFEST_HASH_MISMATCH')}
$manifest=Get-Content -Raw -LiteralPath $ManifestPath|ConvertFrom-Json -Depth 100 -DateKind String
$required=@('schema','status','authorization_eligible','startup_probe_b_authorization_eligible','ready_for_new_exact_sha_mcp_authorization','authorized_post_repair_probe_id','authorized_post_repair_probe_count','automatic_retry_allowed','product_head_sha','product_tree_sha','tooling_head_sha','tooling_tree_sha','frozen_failure_witness_sha256','attempt20_startup_root_cause_class','tooling_files','startup_milestones','startup_selftest_sha256','endpoint_ownership_contract_version','endpoint_ownership_v2_selftest_case_count','endpoint_ownership_v2_false_green_count','probe_a_evidence_sha256','post_repair_probe_execution_count','post_repair_probe_m0_m11_green','endpoint_ownership_contract_v2_implemented','formal_mcp_execution_count','authorized_run_count_consumed','exact_sha_mcp_status','new_import_runner_sha256','new_cursor_runbook_sha256','new_startup_watchdog_sha256','new_startup_state_machine_sha256','new_endpoint_ownership_v2_sha256','new_post_repair_probe_controller_sha256','canonical_payload_sha256')
foreach($name in $required){if($manifest.PSObject.Properties.Name -notcontains $name){$issues.Add("MISSING_FIELD:$name")}}
if([string]$manifest.schema-cne'SpaceSyndicatePr90McpStartupToolingManifestV2'){$issues.Add('SCHEMA_MISMATCH')}
if([string]$manifest.tooling_head_sha-cne(& git -C $root rev-parse HEAD).Trim()){$issues.Add('TOOLING_HEAD_MISMATCH')}
if([string]$manifest.tooling_tree_sha-cne(& git -C $root rev-parse 'HEAD^{tree}').Trim()){$issues.Add('TOOLING_TREE_MISMATCH')}
if(@(& git -C $root status --porcelain=v1 --untracked-files=all).Count-ne0){$issues.Add('TOOLING_WORKTREE_DIRTY')}
foreach($file in @($manifest.tooling_files)){
    if(-not(Test-Path -LiteralPath $file.path -PathType Leaf)){$issues.Add("FILE_MISSING:$($file.relative_path)");continue}
    if((Get-StartupSha256 $file.path)-cne[string]$file.sha256){$issues.Add("FILE_HASH_MISMATCH:$($file.relative_path)")}
    if((& git -C $root hash-object -- ([string]$file.relative_path)).Trim()-cne[string]$file.git_blob){$issues.Add("FILE_BLOB_MISMATCH:$($file.relative_path)")}
}
if(@($manifest.startup_milestones).Count-ne12){$issues.Add('MILESTONE_COUNT_MISMATCH')}
for($i=0;$i-lt@($manifest.startup_milestones).Count;$i+=1){if([string]$manifest.startup_milestones[$i].id-cne"M$i"){$issues.Add("MILESTONE_ORDER_MISMATCH:$i")}}
$selftest=Get-Content -Raw -LiteralPath $manifest.startup_selftest_path|ConvertFrom-Json -Depth 100 -DateKind String
if((Get-StartupSha256 $manifest.startup_selftest_path)-cne[string]$manifest.startup_selftest_sha256-or[string]$selftest.status-cne'PASS'-or[int]$selftest.case_count-lt50-or[int]$selftest.pass_count-ne[int]$selftest.case_count-or[int]$selftest.endpoint_ownership_contract_version-ne2-or[int]$selftest.endpoint_ownership_v2_case_count-lt15-or[int]$selftest.endpoint_ownership_v2_pass_count-ne[int]$selftest.endpoint_ownership_v2_case_count-or[int]$selftest.endpoint_ownership_v2_false_green_count-ne0){$issues.Add('SELFTEST_INVALID')}
$probe=Get-Content -Raw -LiteralPath $manifest.probe_a_evidence_path|ConvertFrom-Json -Depth 100 -DateKind String
if((Get-StartupSha256 $manifest.probe_a_evidence_path)-cne[string]$manifest.probe_a_evidence_sha256){$issues.Add('PROBE_A_HASH_MISMATCH')}
$expectedReady=([string]$probe.status-ceq'PASS'-and[string]$probe.probe_id-ceq'pr90-mcp-endpoint-ownership-v2-post-repair-m0-m11-001'-and[int]$probe.post_repair_probe_execution_count-eq1-and-not[bool]$probe.automatic_retry_allowed-and[int]$probe.milestone_count-eq12-and[bool]$probe.startup_milestone_complete-and[bool]$probe.stops_cleanly-and[bool]$probe.endpoint_ownership_contract_v2_implemented-and[int]$probe.endpoint_ownership_contract_version-eq2-and[int]$probe.total_listener_sample_count-ge5-and[int]$probe.consecutive_parity_sample_count-ge3-and[double]$probe.endpoint_owner_stable_window_ms-ge1000-and[bool]$probe.first_jsonrpc_request_sent-and[bool]$probe.first_jsonrpc_response_received-and[int]$probe.m6_to_m11_execution_count-eq6-and[int]$probe.formal_mcp_execution_count-eq0-and[int]$probe.authorized_run_count_consumed-eq0)
if([bool]$manifest.authorization_eligible){$issues.Add('FORMAL_AUTHORIZATION_MUST_REMAIN_FALSE')}
if([bool]$manifest.startup_probe_b_authorization_eligible-ne$expectedReady){$issues.Add('PROBE_B_READINESS_MISMATCH')}
if(([string]$manifest.status-ceq'READY_FOR_PR90_STARTUP_PROBE_B_AUTHORIZATION')-ne$expectedReady){$issues.Add('READINESS_STATUS_MISMATCH')}
if([bool]$manifest.ready_for_new_exact_sha_mcp_authorization){$issues.Add('EXACT_SHA_READINESS_MUST_REMAIN_FALSE')}
if([int]$manifest.formal_mcp_execution_count-ne0-or[int]$manifest.authorized_run_count_consumed-ne0-or[string]$manifest.exact_sha_mcp_status-cne'NOT_STARTED'){$issues.Add('FORMAL_ZERO_COUNT_MISMATCH')}
if((Get-StartupCanonicalSha256 $manifest)-cne[string]$manifest.canonical_payload_sha256){$issues.Add('CANONICAL_HASH_MISMATCH')}
$receipt=[ordered]@{schema='SpaceSyndicatePr90McpStartupToolingValidationV2';status=if($issues.Count-eq0){'PASS'}else{'FAIL'};validated_at_utc=[DateTimeOffset]::UtcNow.ToString('o');manifest_path=[IO.Path]::GetFullPath($ManifestPath);manifest_sha256=Get-StartupSha256 $ManifestPath;tooling_head_sha=[string]$manifest.tooling_head_sha;tooling_tree_sha=[string]$manifest.tooling_tree_sha;authorization_eligible=$false;startup_probe_b_authorization_eligible=[bool]$manifest.startup_probe_b_authorization_eligible;ready_for_new_exact_sha_mcp_authorization=$false;endpoint_ownership_contract_version=2;issue_count=$issues.Count;issues=@($issues);formal_mcp_execution_count=0;authorized_run_count_consumed=0;canonical_payload_sha256=''}
$receipt.canonical_payload_sha256=Get-StartupCanonicalSha256 $receipt;Write-StartupImmutableJson -Path $OutputPath -Value $receipt -WriteSha256Sidecar|Out-Null;$receipt|ConvertTo-Json -Depth 100 -Compress
if($issues.Count-ne0){exit 2}
