[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ManifestPath,
    [Parameter(Mandatory = $true)][string]$ToolingWorktree,
    [Parameter(Mandatory = $true)][string]$OutputPath
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'pr90_probe_b_attempt22_contract_v1.psm1') -Force
if(-not(Test-Pr90ProbeBShaSidecar $ManifestPath "$ManifestPath.sha256")){throw 'Tooling manifest sidecar mismatch.'}
$manifest=Get-Content -Raw -LiteralPath $ManifestPath|ConvertFrom-Json -Depth 100
$root=(Resolve-Path -LiteralPath $ToolingWorktree).Path;$head=(& git -C $root rev-parse HEAD).Trim();$tree=(& git -C $root rev-parse 'HEAD^{tree}').Trim()
if([string]$manifest.status-cne'READY'-or-not[bool]$manifest.startup_probe_b_authorization_eligible-or[int]$manifest.missing_contract_count_after-ne0-or[int]$manifest.total_selftest_failure_count-ne0-or[long]$manifest.total_selftest_pass_count-lt134-or[int]$manifest.new_tooling_diff_count-ne12-or[int]$manifest.tooling_scope_violation_count-ne0-or[int]$manifest.product_code_change_count-ne0-or[int]$manifest.product_test_change_count-ne0-or[string]$manifest.tooling_head_sha-cne$head-or[string]$manifest.tooling_tree_sha-cne$tree){throw 'Tooling manifest is not an eligible exact identity READY.'}
if(@(& git -C $root status --porcelain=v1 --untracked-files=all).Count-ne0){throw 'Tooling worktree mutated before sealing.'}
$mismatch=0
foreach($row in @($manifest.tooling_files)){$path=Join-Path $root ([string]$row.relative_path);if(-not(Test-Path -LiteralPath $path -PathType Leaf)-or(Get-Pr90ProbeBSha256 $path)-cne[string]$row.sha256-or(& git -C $root rev-parse "HEAD:$([string]$row.relative_path)").Trim()-cne[string]$row.git_blob_sha){$mismatch+=1}}
if($mismatch-ne0){throw 'Tooling file inventory changed before seal.'}
$seal=[pscustomobject][ordered]@{schema='Pr90ProbeBAttempt22ToolingSealV1';status='SEALED';created_at_utc=[DateTimeOffset]::UtcNow.ToString('o');product_head_sha=[string]$manifest.product_head_sha;product_tree_sha=[string]$manifest.product_tree_sha;authorized_probe_scene_path=[string]$manifest.authorized_probe_scene_path;authorized_probe_scene_sha256=[string]$manifest.authorized_probe_scene_sha256;tooling_repository=[string]$manifest.tooling_repository;tooling_remote_branch=[string]$manifest.tooling_remote_branch;tooling_head_sha=$head;tooling_tree_sha=$tree;tooling_parent_sha=[string]$manifest.tooling_parent_sha;manifest_path=[IO.Path]::GetFullPath($ManifestPath);manifest_sha256=Get-Pr90ProbeBSha256 $ManifestPath;tooling_file_count=[int]$manifest.tooling_file_count;tooling_file_hash_inventory_sha256=[string]$manifest.tooling_file_hash_inventory_sha256;new_selftest_sha256=[string]$manifest.new_selftest_sha256;total_selftest_pass_count=[int]$manifest.total_selftest_pass_count;missing_contract_count_after=0;startup_probe_b_authorization_eligible=[bool]$manifest.startup_probe_b_authorization_eligible;import_runner_sha256=[string]$manifest.import_runner_sha256;formal_mcp_execution_count=0;canonical_payload_sha256=''}
$seal.canonical_payload_sha256=Get-Pr90ProbeBCanonicalSha256 $seal
Write-Pr90ProbeBImmutableJson -Path $OutputPath -Value $seal -WriteSha256Sidecar|Out-Null
$seal|ConvertTo-Json -Depth 100 -Compress
