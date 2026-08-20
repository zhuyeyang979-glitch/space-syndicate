[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ManifestPath,
    [Parameter(Mandatory = $true)][string]$CompatibilityProjectionPath,
    [Parameter(Mandatory = $true)][string]$ExpectedProductHead,
    [Parameter(Mandatory = $true)][string]$ExpectedProductTree,
    [Parameter(Mandatory = $true)][string]$ExpectedToolingHead,
    [Parameter(Mandatory = $true)][string]$ExpectedToolingTree,
    [Parameter(Mandatory = $true)][string]$OutputPath
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'pr90_probe_b_attempt22_contract_v1.psm1') -Force
$manifest=Get-Content -Raw -LiteralPath $ManifestPath|ConvertFrom-Json -Depth 100
$sealObject=Get-Content -Raw -LiteralPath $manifest.tooling_seal_path|ConvertFrom-Json -Depth 100
$toolingManifestObject=Get-Content -Raw -LiteralPath $manifest.tooling_manifest_path|ConvertFrom-Json -Depth 100
$actualToolingSealSha256=Get-Pr90ProbeBSha256 $manifest.tooling_seal_path
$remote=@(& git -C ([string]$manifest.import_tooling_worktree_path) ls-remote --heads ([string]$manifest.tooling_repository) "refs/heads/$([string]$manifest.tooling_remote_branch)")
$remoteIdentityGreen=$LASTEXITCODE-eq0-and$remote.Count-eq1
$remoteHead=if($remoteIdentityGreen){([string]$remote[0]).Split("`t")[0]}else{''}
$sidecarGreen=Test-Pr90ProbeBShaSidecar -TargetPath $ManifestPath -SidecarPath "$ManifestPath.sha256"
$observed=Get-Pr90ProbeBSha256 $ManifestPath
$sidecarSha=if($sidecarGreen){([IO.File]::ReadAllText("$ManifestPath.sha256").Trim().Split(' ')[0])}else{''}
$logic=Test-Pr90Attempt22ManifestObjectV4 -Manifest $manifest -ExpectedProductHead $ExpectedProductHead -ExpectedProductTree $ExpectedProductTree `
    -ExpectedToolingHead $ExpectedToolingHead -ExpectedToolingTree $ExpectedToolingTree -ExpectedToolingSealSha256 $actualToolingSealSha256 `
    -ExpectedRemoteToolingHead $remoteHead -FormalEvidenceRootExists (Test-Path -LiteralPath ([string]$manifest.formal_evidence_root) -PathType Container) `
    -ObservedManifestSha256 $observed -SidecarManifestSha256 $sidecarSha
$errors=[Collections.Generic.List[string]]::new();foreach($e in @($logic.errors)){$errors.Add([string]$e)}
if(-not$remoteIdentityGreen-or[string]::IsNullOrWhiteSpace($remoteHead)){$errors.Add('REMOTE_TOOLING_IDENTITY_UNRESOLVED')}
if(-not$sidecarGreen){$errors.Add('MANIFEST_SIDECAR_MISMATCH')}
if([string]$manifest.canonical_payload_sha256-cne(Get-Pr90ProbeBCanonicalSha256 $manifest)){$errors.Add('CANONICAL_PAYLOAD_MISMATCH')}
if([string]$sealObject.schema-cne'Pr90ProbeBV2ResultRecoveryToolingSealV1'-or[string]$sealObject.status-cne'SEALED'-or[string]$sealObject.tooling_head_sha-cne$ExpectedToolingHead-or[string]$sealObject.tooling_tree_sha-cne$ExpectedToolingTree-or[string]$sealObject.manifest_sha256-cne[string]$manifest.tooling_manifest_sha256-or
    [bool]$sealObject.startup_probe_b_authorization_eligible-or-not[bool]$sealObject.preformal_authorization_eligible-or[int]$sealObject.listener_parity_contract_version-ne2-or[string]$sealObject.listener_forensics_sha256-cne[string]$manifest.listener_forensics_sha256-or[int]$sealObject.runtime_reachable_tooling_hash_mismatch_count-ne0-or
    [string]$sealObject.import_runner_sha256-cne[string]$manifest.import_runner_sha256-or[string]$sealObject.canonical_payload_sha256-cne(Get-Pr90ProbeBCanonicalSha256 $sealObject)){$errors.Add('TOOLING_SEAL_CONTRACT_MISMATCH')}
if([string]$toolingManifestObject.schema-cne'Pr90ProbeBV2ResultRecoveryToolingManifestV1'-or[string]$toolingManifestObject.status-cne'READY'-or[bool]$toolingManifestObject.startup_probe_b_authorization_eligible-or-not[bool]$toolingManifestObject.preformal_authorization_eligible-or[string]$toolingManifestObject.tooling_head_sha-cne$ExpectedToolingHead-or[string]$toolingManifestObject.tooling_tree_sha-cne$ExpectedToolingTree-or
    [int]$toolingManifestObject.listener_parity_contract_version-ne2-or[string]$toolingManifestObject.listener_core_normalizer_sha256-cne[string]$manifest.listener_core_normalizer_sha256-or[string]$toolingManifestObject.bracketed_cohort_controller_sha256-cne[string]$manifest.bracketed_cohort_controller_sha256-or[string]$toolingManifestObject.listener_forensics_sha256-cne[string]$manifest.listener_forensics_sha256-or
    [int]$toolingManifestObject.runtime_reachable_tooling_hash_mismatch_count-ne0-or[string]$toolingManifestObject.import_runner_sha256-cne[string]$manifest.import_runner_sha256-or[string]$toolingManifestObject.probe_b_recovery_contract_module_sha256-cne[string]$manifest.probe_b_recovery_contract_module_sha256-or[string]$toolingManifestObject.attempt22_contract_module_sha256-cne[string]$manifest.attempt22_contract_module_sha256-or[string]$toolingManifestObject.tooling_file_hash_inventory_sha256-cne[string]$manifest.tooling_file_hash_inventory_sha256-or[string]$toolingManifestObject.canonical_payload_sha256-cne(Get-Pr90ProbeBCanonicalSha256 $toolingManifestObject)){$errors.Add('TOOLING_MANIFEST_CONTRACT_MISMATCH')}
$toolingFieldRows=@(
    @('startup_watchdog_sha256','tools/pr90_attempt21_mcp_startup_watchdog.ps1'),@('startup_state_machine_sha256','tools/pr90_mcp_startup_state_machine_v1.psm1'),@('endpoint_ownership_validator_sha256','tools/pr90_mcp_endpoint_ownership_v2.psm1'),
    @('listener_core_normalizer_sha256','tools/pr90_endpoint_listener_core_v2.psm1'),@('listener_parity_comparator_sha256','tools/pr90_endpoint_listener_core_v2.psm1'),@('bracketed_cohort_controller_sha256','tools/pr90_listener_bracketed_cohort_v2.psm1'),@('process_identity_enricher_sha256','tools/pr90_listener_process_identity_reader_v1.psm1'),@('failure_cleanup_sha256','tools/pr90_mcp_startup_state_machine_v1.psm1'),
    @('probe_b_controller_sha256','tools/pr90_exact_clone_probe_b_controller_v1.ps1'),@('probe_b_result_builder_sha256','tools/pr90_exact_clone_probe_b_result_builder_v1.ps1'),@('probe_b_attestation_builder_sha256','tools/pr90_exact_clone_probe_b_attestation_builder_v1.ps1'),@('probe_b_recovery_controller_sha256','tools/pr90_exact_clone_probe_b_postrun_recovery_controller_v1.ps1'),@('attempt22_contract_module_sha256','tools/pr90_probe_b_attempt22_contract_v1.psm1'),@('probe_b_frozen_input_inventory_builder_sha256','tools/pr90_probe_b_v2_frozen_input_inventory_builder_v1.ps1'),
    @('probe_b_finalizer_binding_sha256','tools/pr90_probe_b_import_finalizer_binding_v1.ps1'),@('preformal_v2_controller_sha256','tools/pr90_attempt22_preformal_dry_run_v2.ps1'),@('authorization_builder_sha256','tools/pr90_attempt22_authorization_manifest_builder_v4.ps1'),
    @('authorization_validator_sha256','tools/pr90_attempt22_authorization_validator_v4.ps1'),@('authorization_seal_builder_sha256','tools/pr90_attempt22_authorization_seal_builder_v4.ps1'),@('import_runner_sha256','tools/pr90_attempt19_import_runner_v3.ps1')
)
foreach($binding in $toolingFieldRows){$row=@($toolingManifestObject.tooling_files|Where-Object{([string]$_.relative_path).Replace('\','/')-ceq$binding[1]});if($row.Count-ne1-or[string]$manifest.($binding[0])-cne[string]$row[0].sha256){$errors.Add("TOOLING_FIELD_BINDING_MISMATCH:$($binding[0])")}}
$pairs=@(
    @('tooling_manifest_path','tooling_manifest_sha256'),@('tooling_seal_path','tooling_seal_sha256'),@('probe004_result_path','probe004_result_sha256'),@('probe004_attestation_path','probe004_attestation_sha256'),
    @('probe_b_result_path','probe_b_result_sha256'),@('probe_b_attestation_path','probe_b_attestation_sha256'),@('probe_b_recovery_receipt_path','probe_b_recovery_receipt_sha256'),@('probe_b_frozen_input_inventory_path','probe_b_frozen_input_inventory_sha256'),@('probe_b_execution_start_path','probe_b_execution_start_sha256'),@('probe_b_execution_config_path','probe_b_execution_config_sha256'),@('probe_b_finalizer_result_path','probe_b_finalizer_result_sha256'),@('preformal_dry_run_path','preformal_dry_run_sha256'),@('listener_forensics_path','listener_forensics_sha256'),
    @('sealed_baseline_path','sealed_baseline_sha256'),@('class_cache_path','class_cache_sha256'),@('import_pass1_manifest_path','import_pass1_manifest_sha256'),
    @('import_pass2_manifest_path','import_pass2_manifest_sha256'),@('import_finalizer_dry_run_path','import_finalizer_dry_run_evidence_sha256'),@('formal_gate_1_79_receipt_path','formal_gate_1_79_receipt_sha256'),@('godot_path','godot_executable_sha256'),@('godot_console_path','godot_console_sha256')
)
foreach($pair in $pairs){if(-not(Test-Path -LiteralPath ([string]$manifest.($pair[0])) -PathType Leaf)-or(Get-Pr90ProbeBSha256 ([string]$manifest.($pair[0])))-cne[string]$manifest.($pair[1])){$errors.Add("EVIDENCE_HASH_MISMATCH:$($pair[1])")}}
$probeB=$null;$probeBA=$null;$probeBR=$null;$preformal=$null
try{$probeB=Get-Content -Raw -LiteralPath $manifest.probe_b_result_path|ConvertFrom-Json -Depth 100}catch{}
try{$probeBA=Get-Content -Raw -LiteralPath $manifest.probe_b_attestation_path|ConvertFrom-Json -Depth 100}catch{}
try{$probeBR=Get-Content -Raw -LiteralPath $manifest.probe_b_recovery_receipt_path|ConvertFrom-Json -Depth 100}catch{}
try{$preformal=Get-Content -Raw -LiteralPath $manifest.preformal_dry_run_path|ConvertFrom-Json -Depth 100}catch{}
$evidenceContracts=Test-Pr90Attempt22EvidenceContractsV1 -ProbeB $probeB -ProbeBAttestation $probeBA -ProbeBRecoveryReceipt $probeBR -Preformal $preformal -ExpectedProbeBResultSha256 ([string]$manifest.probe_b_result_sha256) `
    -ExpectedProductHeadSha ([string]$manifest.product_head_sha) -ExpectedProductTreeSha ([string]$manifest.product_tree_sha) -ExpectedToolingHeadSha ([string]$manifest.tooling_head_sha) -ExpectedToolingTreeSha ([string]$manifest.tooling_tree_sha) `
    -ExpectedToolingManifestSha256 ([string]$manifest.tooling_manifest_sha256) -ExpectedToolingSealSha256 ([string]$manifest.tooling_seal_sha256) `
    -ExpectedProbeRecoveryToolingHeadSha ([string]$manifest.probe_b_recovery_tooling_head_sha) -ExpectedProbeRecoveryToolingTreeSha ([string]$manifest.probe_b_recovery_tooling_tree_sha) -ExpectedProbeRecoveryToolingManifestSha256 ([string]$manifest.probe_b_recovery_tooling_manifest_sha256) -ExpectedProbeRecoveryToolingSealSha256 ([string]$manifest.probe_b_recovery_tooling_seal_sha256) `
    -ExpectedProbeExecutionToolingHeadSha ([string]$manifest.probe_b_execution_tooling_head_sha) -ExpectedProbeExecutionToolingTreeSha ([string]$manifest.probe_b_execution_tooling_tree_sha) -ExpectedProbeExecutionToolingSealSha256 ([string]$manifest.probe_b_execution_tooling_seal_sha256) -ExpectedRecoveryControllerSha256 ([string]$manifest.probe_b_recovery_controller_sha256) -ExpectedRecoveryContractModuleSha256 ([string]$manifest.probe_b_recovery_contract_module_sha256) -ExpectedFrozenInputInventorySha256 ([string]$manifest.probe_b_frozen_input_inventory_sha256) `
    -ExpectedGodotGuiSha256 ([string]$manifest.godot_executable_sha256) -ExpectedGodotConsoleSha256 ([string]$manifest.godot_console_sha256) -ExpectedBaselineSha256 ([string]$manifest.sealed_baseline_sha256) -ExpectedClassCacheSha256 ([string]$manifest.class_cache_sha256)
foreach($e in @($evidenceContracts.errors)){$errors.Add([string]$e)}
Import-Module (Join-Path $PSScriptRoot 'pr90_attempt19_authority_contract.psm1') -Force
$compatibility=Get-AuthorizationValidation -ManifestPath $CompatibilityProjectionPath -ManifestShaPath "$CompatibilityProjectionPath.sha256" -ExpectedProductHead $ExpectedProductHead -ExpectedProductTree $ExpectedProductTree -ExpectedToolingHead $ExpectedToolingHead -ExpectedToolingTree $ExpectedToolingTree
if([string]$compatibility.status-cne'PASS'){$errors.Add('ATTEMPT19_COMPATIBILITY_VALIDATION_FAILED')}
$projection=Get-Content -Raw -LiteralPath $CompatibilityProjectionPath|ConvertFrom-Json -Depth 100
foreach($field in @(Get-Pr90Attempt19RequiredFieldsV3|Where-Object{$_-notin@('authorization_schema_version','canonical_payload_sha256')})){if((ConvertTo-Pr90ProbeBCanonicalJson $projection.$field)-cne(ConvertTo-Pr90ProbeBCanonicalJson $manifest.$field)){$errors.Add("COMPATIBILITY_PROJECTION_MISMATCH:$field")}}
$requiredFields=@(Get-Pr90Attempt22RequiredFieldsV4)
$declaredFields=@($manifest.PSObject.Properties.Name)
$validatedFieldCount=@($requiredFields|Where-Object{$declaredFields-ccontains$_}).Count
if([IO.Path]::GetFullPath($OutputPath)-cne[IO.Path]::GetFullPath([string]$manifest.formal_authorization_validation_receipt_path)){$errors.Add('VALIDATION_RECEIPT_PATH_MISMATCH')}
$formalRoot=[IO.Path]::GetFullPath([string]$manifest.formal_evidence_root)
if([IO.Path]::GetFullPath([string]$manifest.formal_terminal_manifest_path)-cne[IO.Path]::GetFullPath((Join-Path $formalRoot 'terminal-process-port-manifest.json'))-or
   [IO.Path]::GetFullPath([string]$manifest.formal_finalizer_result_path)-cne[IO.Path]::GetFullPath((Join-Path $formalRoot 'formal-import-finalizer-result.json'))){$errors.Add('FORMAL_TERMINAL_OR_FINALIZER_PATH_MISMATCH')}
if([IO.Path]::GetFullPath([string]$manifest.formal_authorization_consumption_receipt_path).StartsWith("$formalRoot\",[StringComparison]::OrdinalIgnoreCase)-or
   [IO.Path]::GetFullPath([string]$manifest.formal_prelaunch_ignored_inventory_path).StartsWith("$formalRoot\",[StringComparison]::OrdinalIgnoreCase)){$errors.Add('FORMAL_EXTERNAL_AUTHORITY_PATH_OVERLAP')}
foreach($futurePath in @($manifest.formal_authorization_seal_path,$manifest.formal_authorization_consumption_receipt_path,$manifest.formal_prelaunch_ignored_inventory_path,$manifest.formal_evidence_root)){
    if(Test-Path -LiteralPath ([string]$futurePath)){$errors.Add("FUTURE_AUTHORITY_PATH_ALREADY_EXISTS:$futurePath")}
}
$result=[pscustomobject][ordered]@{schema='Pr90Attempt22AuthorizationValidationV4';status=if($errors.Count-eq0){'PASS'}else{'BLOCKED'};created_at_utc=[DateTimeOffset]::UtcNow.ToString('o');authorization_id=[string]$manifest.authorization_id;authorized_run_id=[string]$manifest.authorized_run_id;formal_evidence_root=[IO.Path]::GetFullPath([string]$manifest.formal_evidence_root);manifest_path=[IO.Path]::GetFullPath($ManifestPath);manifest_sha256=$observed;tooling_manifest_sha256=[string]$manifest.tooling_manifest_sha256;tooling_seal_sha256=[string]$manifest.tooling_seal_sha256;product_head_sha=$ExpectedProductHead;product_tree_sha=$ExpectedProductTree;tooling_head_sha=$ExpectedToolingHead;tooling_tree_sha=$ExpectedToolingTree;declared_field_count=$declaredFields.Count;validated_field_count=$validatedFieldCount;field_mismatch_count=$errors.Count;missing_field_count=@($errors|Where-Object{$_-like'MISSING_FIELD:*'}).Count;unexpected_field_count=@($errors|Where-Object{$_-like'UNEXPECTED_FIELD:*'}).Count;attempt19_compatibility_status=[string]$compatibility.status;authorization_consumed=$false;errors=@($errors);canonical_payload_sha256=''}
$result.canonical_payload_sha256=Get-Pr90ProbeBCanonicalSha256 $result
Write-Pr90ProbeBImmutableJson -Path $OutputPath -Value $result -WriteSha256Sidecar|Out-Null
$result|ConvertTo-Json -Depth 100 -Compress
if([string]$result.status-cne'PASS'){exit 2}
