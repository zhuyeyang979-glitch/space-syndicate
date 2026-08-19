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
$required=@('schema','status','authorization_eligible','product_head_sha','product_tree_sha','tooling_head_sha','tooling_tree_sha','frozen_failure_witness_sha256','attempt20_startup_root_cause_class','tooling_files','startup_milestones','startup_selftest_sha256','probe_a_evidence_sha256','formal_mcp_execution_count','authorized_run_count_consumed','exact_sha_mcp_status','new_import_runner_sha256','new_cursor_runbook_sha256','new_startup_watchdog_sha256','new_startup_state_machine_sha256','canonical_payload_sha256')
foreach($name in $required){if($manifest.PSObject.Properties.Name -notcontains $name){$issues.Add("MISSING_FIELD:$name")}}
if([string]$manifest.schema-cne'SpaceSyndicatePr90McpStartupToolingManifestV1'){$issues.Add('SCHEMA_MISMATCH')}
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
if((Get-StartupSha256 $manifest.startup_selftest_path)-cne[string]$manifest.startup_selftest_sha256-or[string]$selftest.status-cne'PASS'-or[int]$selftest.case_count-lt28-or[int]$selftest.pass_count-ne[int]$selftest.case_count){$issues.Add('SELFTEST_INVALID')}
$probe=Get-Content -Raw -LiteralPath $manifest.probe_a_evidence_path|ConvertFrom-Json -Depth 100 -DateKind String
if((Get-StartupSha256 $manifest.probe_a_evidence_path)-cne[string]$manifest.probe_a_evidence_sha256){$issues.Add('PROBE_A_HASH_MISMATCH')}
$expectedEligible=([string]$probe.status-ceq'PASS'-and[int]$probe.milestone_count-eq12-and[bool]$probe.startup_milestone_complete-and[bool]$probe.stops_cleanly)
if([bool]$manifest.authorization_eligible-ne$expectedEligible){$issues.Add('ELIGIBILITY_MISMATCH')}
if(([string]$manifest.status-ceq'READY')-ne$expectedEligible){$issues.Add('READINESS_STATUS_MISMATCH')}
if([int]$manifest.formal_mcp_execution_count-ne0-or[int]$manifest.authorized_run_count_consumed-ne0-or[string]$manifest.exact_sha_mcp_status-cne'NOT_STARTED'){$issues.Add('FORMAL_ZERO_COUNT_MISMATCH')}
if((Get-StartupCanonicalSha256 $manifest)-cne[string]$manifest.canonical_payload_sha256){$issues.Add('CANONICAL_HASH_MISMATCH')}
$receipt=[ordered]@{schema='SpaceSyndicatePr90McpStartupToolingValidationV1';status=if($issues.Count-eq0){'PASS'}else{'FAIL'};validated_at_utc=[DateTimeOffset]::UtcNow.ToString('o');manifest_path=[IO.Path]::GetFullPath($ManifestPath);manifest_sha256=Get-StartupSha256 $ManifestPath;tooling_head_sha=[string]$manifest.tooling_head_sha;tooling_tree_sha=[string]$manifest.tooling_tree_sha;authorization_eligible=[bool]$manifest.authorization_eligible;issue_count=$issues.Count;issues=@($issues);formal_mcp_execution_count=0;authorized_run_count_consumed=0;canonical_payload_sha256=''}
$receipt.canonical_payload_sha256=Get-StartupCanonicalSha256 $receipt;Write-StartupImmutableJson -Path $OutputPath -Value $receipt -WriteSha256Sidecar|Out-Null;$receipt|ConvertTo-Json -Depth 100 -Compress
if($issues.Count-ne0){exit 2}
