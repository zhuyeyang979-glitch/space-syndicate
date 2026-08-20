[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ManifestPath,
    [Parameter(Mandatory=$true)][string]$ExpectedManifestSha256,
    [Parameter(Mandatory=$true)][string]$ValidationReceiptPath,
    [Parameter(Mandatory=$true)][string]$ExpectedValidationReceiptSha256,
    [Parameter(Mandatory=$true)][string]$ToolingWorktree,
    [Parameter(Mandatory=$true)][string]$OutputPath
)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'pr90_attempt21_mcp_startup_contract.psm1') -Force
$root=(Resolve-Path -LiteralPath $ToolingWorktree).Path.TrimEnd('\')
if(@(& git -C $root status --porcelain=v1 --untracked-files=all).Count-ne0){throw 'Startup tooling seal requires a clean worktree and index.'}
if((Get-StartupSha256 $ManifestPath)-cne$ExpectedManifestSha256.ToLowerInvariant()){throw 'Startup tooling manifest hash mismatch.'}
if((Get-StartupSha256 $ValidationReceiptPath)-cne$ExpectedValidationReceiptSha256.ToLowerInvariant()){throw 'Startup tooling validation hash mismatch.'}
$manifest=Get-Content -Raw -LiteralPath $ManifestPath|ConvertFrom-Json -Depth 100 -DateKind String
$validation=Get-Content -Raw -LiteralPath $ValidationReceiptPath|ConvertFrom-Json -Depth 100 -DateKind String
if([string]$validation.status-cne'PASS'-or[string]$validation.manifest_sha256-cne(Get-StartupSha256 $ManifestPath)){throw 'Startup tooling validation receipt is not an exact PASS.'}
$seal=[ordered]@{schema='SpaceSyndicatePr90McpStartupToolingSealV2';status='SEALED';readiness_status=[string]$manifest.status;authorization_eligible=$false;startup_probe_b_authorization_eligible=[bool]$manifest.startup_probe_b_authorization_eligible;ready_for_new_exact_sha_mcp_authorization=$false;endpoint_ownership_contract_version=2;authorized_post_repair_probe_id=[string]$manifest.authorized_post_repair_probe_id;post_repair_probe_execution_count=[int]$manifest.post_repair_probe_execution_count;sealed_at_utc=[DateTimeOffset]::UtcNow.ToString('o');product_head_sha=[string]$manifest.product_head_sha;product_tree_sha=[string]$manifest.product_tree_sha;tooling_head_sha=[string]$manifest.tooling_head_sha;tooling_tree_sha=[string]$manifest.tooling_tree_sha;manifest_path=[IO.Path]::GetFullPath($ManifestPath);manifest_sha256=Get-StartupSha256 $ManifestPath;validation_receipt_path=[IO.Path]::GetFullPath($ValidationReceiptPath);validation_receipt_sha256=Get-StartupSha256 $ValidationReceiptPath;tooling_file_count=@($manifest.tooling_files).Count;new_import_runner_sha256=[string]$manifest.new_import_runner_sha256;new_cursor_runbook_sha256=[string]$manifest.new_cursor_runbook_sha256;new_startup_watchdog_sha256=[string]$manifest.new_startup_watchdog_sha256;new_startup_state_machine_sha256=[string]$manifest.new_startup_state_machine_sha256;new_endpoint_ownership_v2_sha256=[string]$manifest.new_endpoint_ownership_v2_sha256;new_post_repair_probe_controller_sha256=[string]$manifest.new_post_repair_probe_controller_sha256;formal_mcp_execution_count=0;authorized_run_count_consumed=0;exact_sha_mcp_status='NOT_STARTED';post_seal_mutation_count=0;canonical_payload_sha256=''}
$seal.canonical_payload_sha256=Get-StartupCanonicalSha256 $seal;Write-StartupImmutableJson -Path $OutputPath -Value $seal -WriteSha256Sidecar|Out-Null;$seal|ConvertTo-Json -Depth 100 -Compress
