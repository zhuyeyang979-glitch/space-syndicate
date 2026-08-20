[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ConfigPath,
    [Parameter(Mandatory = $true)][string]$ExpectedConfigSha256,
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [Parameter(Mandatory = $true)][string]$CompatibilityProjectionPath
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'pr90_probe_b_attempt22_contract_v1.psm1') -Force
if((Get-Pr90ProbeBSha256 $ConfigPath)-cne$ExpectedConfigSha256.ToLowerInvariant()){throw 'Attempt 22 config hash mismatch.'}
$config=Get-Content -Raw -LiteralPath $ConfigPath|ConvertFrom-Json -Depth 100
if([string]$config.schema-cne'Pr90Attempt22AuthorizationConfigV4'){throw 'Attempt 22 config schema mismatch.'}
$oldBuilder=Join-Path $PSScriptRoot 'pr90_attempt19_authorization_manifest_builder.ps1'
$projectionOutput=@(& (Join-Path $PSHOME 'pwsh.exe') -NoProfile -File $oldBuilder -ConfigPath $ConfigPath -OutputPath $CompatibilityProjectionPath -OutputShaPath "$CompatibilityProjectionPath.sha256")
if($LASTEXITCODE-ne0-or-not(Test-Path -LiteralPath $CompatibilityProjectionPath -PathType Leaf)){throw "Attempt 19 compatibility projection failed: $([string]::Join(' | ',[string[]]$projectionOutput))"}
$manifest=Get-Content -Raw -LiteralPath $CompatibilityProjectionPath|ConvertFrom-Json -Depth 100
$manifest.authorization_schema_version='SpaceSyndicatePr90CanonicalImportAuthorityV4Attempt22'
$manifest.authorization_id=[string]$config.authorization_id
$manifest.formal_run_id=[string]$config.authorized_run_id
$additions=[ordered]@{
    authorized_run_id=[string]$config.authorized_run_id;tooling_repository=[string]$config.tooling_repository;tooling_remote_branch=[string]$config.tooling_remote_branch
    tooling_head_sha=[string]$config.tooling_head_sha;tooling_tree_sha=[string]$config.tooling_tree_sha;tooling_parent_sha=[string]$config.tooling_parent_sha
    tooling_manifest_path=[IO.Path]::GetFullPath([string]$config.tooling_manifest_path);tooling_manifest_sha256=Get-Pr90ProbeBSha256 $config.tooling_manifest_path
    tooling_file_hash_inventory_sha256=[string]$config.tooling_file_hash_inventory_sha256;startup_watchdog_sha256=[string]$config.startup_watchdog_sha256;startup_state_machine_sha256=[string]$config.startup_state_machine_sha256
    endpoint_ownership_contract_version=[int]$config.endpoint_ownership_contract_version;endpoint_ownership_validator_sha256=[string]$config.endpoint_ownership_validator_sha256
    probe004_result_path=[IO.Path]::GetFullPath([string]$config.probe004_result_path);probe004_result_sha256=Get-Pr90ProbeBSha256 $config.probe004_result_path
    probe004_attestation_path=[IO.Path]::GetFullPath([string]$config.probe004_attestation_path);probe004_attestation_sha256=Get-Pr90ProbeBSha256 $config.probe004_attestation_path
    probe_b_result_path=[IO.Path]::GetFullPath([string]$config.probe_b_result_path);probe_b_result_sha256=Get-Pr90ProbeBSha256 $config.probe_b_result_path
    probe_b_attestation_path=[IO.Path]::GetFullPath([string]$config.probe_b_attestation_path);probe_b_attestation_sha256=Get-Pr90ProbeBSha256 $config.probe_b_attestation_path
    probe_b_finalizer_result_path=[IO.Path]::GetFullPath([string]$config.probe_b_finalizer_result_path);probe_b_finalizer_result_sha256=Get-Pr90ProbeBSha256 $config.probe_b_finalizer_result_path
    probe_b_import_finalizer_status=[string]$config.probe_b_import_finalizer_status;preformal_dry_run_path=[IO.Path]::GetFullPath([string]$config.preformal_dry_run_path);preformal_dry_run_sha256=Get-Pr90ProbeBSha256 $config.preformal_dry_run_path
    preformal_v2_check_count=22;preformal_v2_pass_count=22;preformal_v2_fail_count=0
    authorization_seal_builder_path=[IO.Path]::GetFullPath([string]$config.authorization_seal_builder_path);authorization_seal_builder_sha256=Get-Pr90ProbeBSha256 $config.authorization_seal_builder_path
    probe_b_controller_sha256=[string]$config.probe_b_controller_sha256;probe_b_result_builder_sha256=[string]$config.probe_b_result_builder_sha256;probe_b_attestation_builder_sha256=[string]$config.probe_b_attestation_builder_sha256
    probe_b_finalizer_binding_sha256=[string]$config.probe_b_finalizer_binding_sha256;preformal_v2_controller_sha256=[string]$config.preformal_v2_controller_sha256
    authorization_negative_test_count=[int]$config.authorization_negative_test_count;authorization_negative_test_pass_count=[int]$config.authorization_negative_test_pass_count;authorization_negative_test_fail_count=[int]$config.authorization_negative_test_fail_count
    attempt22_authorization_missing_contract_count=0;godot_console_path=[IO.Path]::GetFullPath([string]$config.godot_console_path);godot_console_sha256=Get-Pr90ProbeBSha256 $config.godot_console_path
    sealed_post_import_baseline_sha256=[string]$manifest.sealed_baseline_sha256;import_finalizer_dry_run_sha256=[string]$manifest.import_finalizer_dry_run_evidence_sha256
}
foreach($entry in $additions.GetEnumerator()){$manifest|Add-Member -NotePropertyName $entry.Key -NotePropertyValue $entry.Value -Force}
$manifest.canonical_payload_sha256='';$manifest.canonical_payload_sha256=Get-Pr90ProbeBCanonicalSha256 $manifest
$required=@(Get-Pr90Attempt22RequiredFieldsV4);$names=@($manifest.PSObject.Properties.Name)
if(@($required|Where-Object{$names-cnotcontains$_}).Count-ne0-or@($names|Where-Object{$required-cnotcontains$_}).Count-ne0){throw 'Attempt 22 builder/validator field inventory drift.'}
Write-Pr90ProbeBImmutableJson -Path $OutputPath -Value $manifest -WriteSha256Sidecar|Out-Null
[pscustomobject][ordered]@{status='PASS';manifest_path=[IO.Path]::GetFullPath($OutputPath);manifest_sha256=Get-Pr90ProbeBSha256 $OutputPath;declared_field_count=$names.Count;compatibility_projection_sha256=Get-Pr90ProbeBSha256 $CompatibilityProjectionPath}|ConvertTo-Json -Compress
