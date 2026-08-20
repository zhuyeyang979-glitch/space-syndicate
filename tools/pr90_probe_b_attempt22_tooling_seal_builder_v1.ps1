[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$ManifestPath,
 [Parameter(Mandatory=$true)][string]$ToolingWorktree,
 [Parameter(Mandatory=$true)][string]$OutputPath
)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'pr90_probe_b_attempt22_contract_v1.psm1') -Force
if(-not(Test-Pr90ProbeBShaSidecar $ManifestPath "$ManifestPath.sha256")){throw 'Result recovery Tooling manifest sidecar mismatch.'}
$manifest=Get-Content -Raw -LiteralPath $ManifestPath|ConvertFrom-Json -Depth 100
$root=(Resolve-Path -LiteralPath $ToolingWorktree).Path;$head=(& git -C $root rev-parse HEAD).Trim();$tree=(& git -C $root rev-parse 'HEAD^{tree}').Trim();$parent=(& git -C $root rev-parse 'HEAD^').Trim()
$ready=([string]$manifest.schema-ceq'Pr90ProbeBV2ResultRecoveryToolingManifestV1'-and[string]$manifest.status-ceq'READY'-and[bool]$manifest.preformal_authorization_eligible-and-not[bool]$manifest.startup_probe_b_authorization_eligible-and
 [string]$manifest.tooling_head_sha-ceq$head-and[string]$manifest.tooling_tree_sha-ceq$tree-and[string]$manifest.tooling_parent_sha-ceq$parent-and[string]$parent-ceq'44f5ef84185f3488dfde7551a787571337b0f531'-and
 [int]$manifest.new_tooling_commit_count-eq1-and[int]$manifest.new_tooling_diff_count-eq10-and[int]$manifest.new_tooling_modified_count-eq10-and[int]$manifest.new_tooling_added_count-eq0-and[int]$manifest.tooling_scope_violation_count-eq0-and[int]$manifest.product_code_change_count-eq0-and[int]$manifest.product_test_change_count-eq0-and[int]$manifest.tooling_file_hash_mismatch_count-eq0-and
 [string]$manifest.import_runner_sha256-ceq(Get-Pr90ProbeBSha256 (Join-Path $root 'tools/pr90_attempt19_import_runner_v3.ps1'))-and
 [int]$manifest.base_selftest_pass_count-eq326-and[string]$manifest.new_selftest_revision-ceq'PR90_ATTEMPT22_FORMAL_AUTHORITY_REPAIR_V1'-and[int]$manifest.new_selftest_case_count-eq125-and[string]$manifest.new_selftest_case_name_inventory_sha256-ceq'a33f60d58af47d2f767c03987821e8f0485065968505748bfd1864bd129ab13c'-and[int]$manifest.new_selftest_pass_count-eq125-and[int]$manifest.total_selftest_failure_count-eq0-and
 [int]$manifest.frozen_input_count-eq241-and[string]$manifest.frozen_input_hash_inventory_sha256-ceq'af5e309da4a512bbee1cdf3118e69ac243782715484757410702234f75d94f50'-and[int]$manifest.authorized_runtime_reachable_change_count-eq3-and[int]$manifest.runtime_reachable_tooling_hash_mismatch_count-eq0)
if(-not$ready){throw 'Result recovery Tooling manifest is not exact READY.'}
if(@(& git -C $root status --porcelain=v1 --untracked-files=all).Count-ne0){throw 'Result recovery Tooling worktree mutated before seal.'}
$mismatch=0
foreach($row in @($manifest.tooling_files)){$path=Join-Path $root ([string]$row.relative_path);$blob=if(Test-Path -LiteralPath $path -PathType Leaf){(& git -C $root rev-parse "HEAD:$([string]$row.relative_path)").Trim()}else{''};if(-not(Test-Path -LiteralPath $path -PathType Leaf)-or(Get-Pr90ProbeBSha256 $path)-cne[string]$row.sha256-or$blob-cne[string]$row.git_blob_sha){$mismatch+=1}}
if($mismatch-ne0){throw 'Result recovery Tooling file inventory changed before seal.'}
$seal=[pscustomobject][ordered]@{
 schema='Pr90ProbeBV2ResultRecoveryToolingSealV1';status='SEALED';created_at_utc=[DateTimeOffset]::UtcNow.ToString('o');product_head_sha=[string]$manifest.product_head_sha;product_tree_sha=[string]$manifest.product_tree_sha
 tooling_repository=[string]$manifest.tooling_repository;tooling_remote_branch=[string]$manifest.tooling_remote_branch;tooling_head_sha=$head;tooling_tree_sha=$tree;tooling_parent_sha=$parent;manifest_path=[IO.Path]::GetFullPath($ManifestPath);manifest_sha256=Get-Pr90ProbeBSha256 $ManifestPath;tooling_file_count=[int]$manifest.tooling_file_count;tooling_file_hash_inventory_sha256=[string]$manifest.tooling_file_hash_inventory_sha256
 base_tooling_head_sha=[string]$manifest.base_tooling_head_sha;base_tooling_tree_sha=[string]$manifest.base_tooling_tree_sha;base_tooling_manifest_sha256=[string]$manifest.base_tooling_manifest_sha256;base_tooling_seal_sha256=[string]$manifest.base_tooling_seal_sha256
 frozen_input_inventory_sha256=[string]$manifest.frozen_input_inventory_sha256;frozen_input_count=[int]$manifest.frozen_input_count;frozen_input_hash_inventory_sha256=[string]$manifest.frozen_input_hash_inventory_sha256
 listener_forensics_sha256=[string]$manifest.listener_forensics_sha256;listener_parity_root_cause_class=[string]$manifest.listener_parity_root_cause_class;listener_parity_contract_version=2;listener_core_normalizer_sha256=[string]$manifest.listener_core_normalizer_sha256;bracketed_cohort_controller_sha256=[string]$manifest.bracketed_cohort_controller_sha256
 import_runner_sha256=[string]$manifest.import_runner_sha256
 probe_b_result_builder_sha256=[string]$manifest.probe_b_result_builder_sha256;probe_b_attestation_builder_sha256=[string]$manifest.probe_b_attestation_builder_sha256;probe_b_recovery_controller_sha256=[string]$manifest.probe_b_recovery_controller_sha256;probe_b_recovery_contract_module_sha256=[string]$manifest.probe_b_recovery_contract_module_sha256;attempt22_contract_module_sha256=[string]$manifest.attempt22_contract_module_sha256;probe_b_frozen_input_inventory_builder_sha256=[string]$manifest.probe_b_frozen_input_inventory_builder_sha256
 new_selftest_sha256=[string]$manifest.new_selftest_sha256;new_selftest_revision=[string]$manifest.new_selftest_revision;new_selftest_case_name_inventory_sha256=[string]$manifest.new_selftest_case_name_inventory_sha256;new_selftest_case_count=[int]$manifest.new_selftest_case_count;new_tooling_modified_count=10;new_tooling_added_count=0;new_tooling_diff=@($manifest.new_tooling_diff)
 runtime_reachable_tooling_file_count=[int]$manifest.runtime_reachable_tooling_file_count;authorized_runtime_reachable_change_count=3;runtime_reachable_tooling_hash_mismatch_count=0;startup_probe_b_authorization_eligible=$false;preformal_authorization_eligible=$true;probe_execution_count_delta=0;formal_mcp_execution_count=0;canonical_payload_sha256=''
}
$seal.canonical_payload_sha256=Get-Pr90ProbeBCanonicalSha256 $seal
Write-Pr90ProbeBImmutableJson -Path $OutputPath -Value $seal -WriteSha256Sidecar|Out-Null
$seal|ConvertTo-Json -Depth 100 -Compress
