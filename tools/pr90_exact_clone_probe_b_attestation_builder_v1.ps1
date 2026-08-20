[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProbeId,
    [Parameter(Mandatory = $true)][string]$ResultPath,
    [Parameter(Mandatory = $true)][string]$EvidenceRoot,
    [Parameter(Mandatory = $true)][string]$Probe004ResultPath,
    [Parameter(Mandatory = $true)][string]$ExpectedProbe004ResultSha256,
    [Parameter(Mandatory = $true)][string]$Probe004AttestationPath,
    [Parameter(Mandatory = $true)][string]$ExpectedProbe004AttestationSha256,
    [Parameter(Mandatory = $true)][string]$PostImportBaselinePath,
    [Parameter(Mandatory = $true)][string]$ClassCachePath,
    [Parameter(Mandatory = $true)][string]$SceneIsolationAuditPath,
    [Parameter(Mandatory = $true)][string]$ExpectedProbeSceneSha256,
    [Parameter(Mandatory = $true)][string]$ListenerForensicsPath,
    [Parameter(Mandatory = $true)][string]$ExpectedListenerForensicsSha256,
    [Parameter(Mandatory = $true)][string]$FinalizerResultPath,
    [Parameter(Mandatory = $true)][string]$TerminalManifestPath,
    [string]$RecoveryToolingManifestPath = '',
    [string]$RecoveryToolingSealPath = '',
    [string]$BoundResultPath = '',
    [Parameter(Mandatory = $true)][string]$OutputPath
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'pr90_probe_b_attempt22_contract_v1.psm1') -Force
$result = Get-Content -Raw -LiteralPath $ResultPath | ConvertFrom-Json -Depth 100
$executionStart=Get-Content -Raw -LiteralPath ([string]$result.probe_execution_start_path)|ConvertFrom-Json -Depth 100
$executionConfig=Get-Content -Raw -LiteralPath ([string]$result.probe_execution_config_path)|ConvertFrom-Json -Depth 100
if([string]::IsNullOrWhiteSpace($RecoveryToolingManifestPath)){$RecoveryToolingManifestPath=[string]$executionConfig.tooling_manifest_path}
if([string]::IsNullOrWhiteSpace($RecoveryToolingSealPath)){$RecoveryToolingSealPath=[string]$executionConfig.tooling_seal_path}
$recoveryManifest=Get-Content -Raw -LiteralPath $RecoveryToolingManifestPath|ConvertFrom-Json -Depth 100
$recoverySeal=Get-Content -Raw -LiteralPath $RecoveryToolingSealPath|ConvertFrom-Json -Depth 100
$finalizer=Get-Content -Raw -LiteralPath $FinalizerResultPath|ConvertFrom-Json -Depth 100
$terminal=Get-Content -Raw -LiteralPath $TerminalManifestPath|ConvertFrom-Json -Depth 100
$receiptPaths = @(Get-ChildItem -LiteralPath (Join-Path $EvidenceRoot 'milestones') -Filter '*.receipt.json' -File | Where-Object{$_.Name-match'^\d{2}-M(?:[0-9]|1[01])-.*\.receipt\.json$'} | Sort-Object Name | Select-Object -ExpandProperty FullName)
$receipts = Get-Pr90ProbeBFileInventoryV1 -Paths $receiptPaths
$rawPaths = @(Get-ChildItem -LiteralPath (Join-Path $EvidenceRoot 'mcp-raw') -Filter '*.json' -File | Sort-Object FullName | Select-Object -ExpandProperty FullName)
$raw = Get-Pr90ProbeBFileInventoryV1 -Paths $rawPaths
$requestPaths = @(Get-ChildItem -LiteralPath (Join-Path $EvidenceRoot 'requests') -Filter '*.json' -File | Sort-Object FullName | Select-Object -ExpandProperty FullName)
$requests = Get-Pr90ProbeBFileInventoryV1 -Paths $requestPaths
$bootstrap = Join-Path $EvidenceRoot 'witnesses/runtime-stream-bootstrap.json'
$bridgeReady = Join-Path $EvidenceRoot 'witnesses/runtime-bridge-ready-status.json'
$ready = Join-Path $EvidenceRoot 'witnesses/ready-witness.json'
$phase0 = Join-Path $EvidenceRoot 'phases/000-phase-0-ready.json'
$endpointAttestation = Join-Path $EvidenceRoot 'endpoint-ownership-v2-attestation.json'
$endpointSamples = Join-Path $EvidenceRoot 'endpoint-ownership-v2-samples.json'
$endpointAttestationObject=if(Test-Path -LiteralPath $endpointAttestation -PathType Leaf){Get-Content -Raw -LiteralPath $endpointAttestation|ConvertFrom-Json -Depth 100}else{$null}
$endpointSamplesObject=if(Test-Path -LiteralPath $endpointSamples -PathType Leaf){Get-Content -Raw -LiteralPath $endpointSamples|ConvertFrom-Json -Depth 100}else{$null}
$listenerForensics=Get-Content -Raw -LiteralPath $ListenerForensicsPath|ConvertFrom-Json -Depth 100
$probe004Result=Get-Content -Raw -LiteralPath $Probe004ResultPath|ConvertFrom-Json -Depth 100
$probe004Attestation=Get-Content -Raw -LiteralPath $Probe004AttestationPath|ConvertFrom-Json -Depth 100
$sceneIsolation=Get-Content -Raw -LiteralPath $SceneIsolationAuditPath|ConvertFrom-Json -Depth 100
$sceneIsolationGreen=Test-Pr90ProbeBSceneIsolationContractV1 -Audit $sceneIsolation -ExpectedScenePath ([string]$result.authorized_probe_scene_path) -ExpectedSceneSha256 $ExpectedProbeSceneSha256
$probe004Bound=((Get-Pr90ProbeBSha256 $Probe004ResultPath)-ceq$ExpectedProbe004ResultSha256-and(Get-Pr90ProbeBSha256 $Probe004AttestationPath)-ceq$ExpectedProbe004AttestationSha256-and
    [string]$probe004Result.status-ceq'PASS'-and[string]$probe004Result.probe_id-ceq'pr90-mcp-endpoint-ownership-v2-post-repair-m0-m11-004'-and[string]$probe004Attestation.status-ceq'SEALED'-and
    [string]$probe004Attestation.probe_id-ceq'pr90-mcp-endpoint-ownership-v2-post-repair-m0-m11-004'-and[string]$probe004Attestation.result_sha256-ceq$ExpectedProbe004ResultSha256)
$listenerV2Bound=((Get-Pr90ProbeBSha256 $ListenerForensicsPath)-ceq$ExpectedListenerForensicsSha256-and[string]$listenerForensics.status-ceq'ROOT_CAUSE_RESOLVED'-and[int]$listenerForensics.sample_count-eq23-and[string]$listenerForensics.root_cause_class-ceq'J'-and-not[bool]$listenerForensics.characterization_probe_required-and
    $null-ne$endpointAttestationObject-and[string]$endpointAttestationObject.status-ceq'PASS'-and[bool]$endpointAttestationObject.bracketed_sample_model-and[int]$endpointAttestationObject.listener_core_parity_key_field_count-eq5-and[int]$endpointAttestationObject.matched_listener_process_enrichment_count-eq1-and[int]$endpointAttestationObject.duplicate_source_process_enrichment_count-eq0-and
    $null-ne$endpointSamplesObject-and[string]$endpointSamplesObject.schema-ceq'SpaceSyndicatePr90McpEndpointOwnershipBracketedCohortsV2'-and[bool]$endpointSamplesObject.bracketed_sample_model-and[string]$endpointSamplesObject.raw_listener_evidence_preservation-ceq'100_PERCENT'-and[int]$endpointSamplesObject.cohort_count-ge5-and
    [int]$result.total_listener_cohort_attempt_count-ge5-and[int]$result.consecutive_stable_parity_cohort_count-ge5-and[double]$result.stable_parity_window_ms-ge1000-and[bool]$result.endpoint_listener_core_parity-and[int]$result.endpoint_listener_a_only_core_count-eq0-and[int]$result.endpoint_listener_b_only_core_count-eq0-and
    [bool]$result.endpoint_owner_project_match-and[bool]$result.endpoint_owner_mcp_session_match-and[bool]$result.endpoint_owner_creation_identity_match-and[int]$result.protected_port_multiple_owner_count-eq0-and[int]$result.foreign_listener_count-eq0)
$executionBindingGreen=((Get-Pr90ProbeBSha256 ([string]$result.probe_execution_start_path))-ceq[string]$result.probe_execution_start_sha256-and(Get-Pr90ProbeBSha256 ([string]$result.probe_execution_config_path))-ceq[string]$result.probe_execution_config_sha256-and
    [string]$executionStart.probe_id-ceq$ProbeId-and[string]$executionStart.config_sha256-ceq[string]$result.probe_execution_config_sha256-and[int]$executionStart.execution_count-eq1-and
    [string]$executionStart.tooling_head_sha-ceq[string]$result.tooling_head_sha-and[string]$executionStart.tooling_tree_sha-ceq[string]$result.tooling_tree_sha-and[string]$executionStart.tooling_seal_sha256-ceq[string]$result.tooling_seal_sha256-and
    [string]$executionConfig.tooling_head_sha-ceq[string]$result.tooling_head_sha-and[string]$executionConfig.tooling_tree_sha-ceq[string]$result.tooling_tree_sha-and[string]$executionConfig.tooling_seal_sha256-ceq[string]$result.tooling_seal_sha256)
$recoveryBindingGreen=((Get-Pr90ProbeBSha256 $RecoveryToolingManifestPath)-ceq[string]$result.result_recovery_tooling_manifest_sha256-and(Get-Pr90ProbeBSha256 $RecoveryToolingSealPath)-ceq[string]$result.result_recovery_tooling_seal_sha256-and
    [string]$recoveryManifest.status-ceq'READY'-and[string]$recoveryManifest.tooling_head_sha-ceq[string]$result.result_recovery_tooling_head_sha-and[string]$recoveryManifest.tooling_tree_sha-ceq[string]$result.result_recovery_tooling_tree_sha-and[int]$result.runtime_reachable_tooling_hash_mismatch_count-eq0-and
    [string]$recoverySeal.status-ceq'SEALED'-and[string]$recoverySeal.tooling_head_sha-ceq[string]$result.result_recovery_tooling_head_sha-and[string]$recoverySeal.tooling_tree_sha-ceq[string]$result.result_recovery_tooling_tree_sha-and[string]$recoverySeal.manifest_sha256-ceq[string]$result.result_recovery_tooling_manifest_sha256)
$artifactBindingGreen=([string]$finalizer.status-ceq'PASS'-and[string]$terminal.status-ceq'PASS'-and[string]$result.finalizer_result_sha256-ceq(Get-Pr90ProbeBSha256 $FinalizerResultPath)-and[string]$result.terminal_manifest_sha256-ceq(Get-Pr90ProbeBSha256 $TerminalManifestPath)-and
    [string]$result.post_import_baseline_sha256-ceq(Get-Pr90ProbeBSha256 $PostImportBaselinePath)-and[string]$result.class_cache_sha256-ceq(Get-Pr90ProbeBSha256 $ClassCachePath)-and[string]$result.scene_isolation_audit_sha256-ceq(Get-Pr90ProbeBSha256 $SceneIsolationAuditPath)-and[string]$result.listener_forensics_sha256-ceq(Get-Pr90ProbeBSha256 $ListenerForensicsPath))
$allBound = ([string]$result.schema-ceq'Pr90ExactCloneProbeBV2ResultV1'-and[string]$result.probe_id-ceq$ProbeId-and[string]$result.status -ceq 'PASS' -and$executionBindingGreen-and$recoveryBindingGreen-and$artifactBindingGreen-and $receipts.count -eq 12 -and[bool]$result.milestone_sequence_green-and[int]$result.milestone_duplicate_count-eq0-and $raw.count -gt 0 -and
    $requests.count-gt0-and[string]$result.request_inventory_sha256-ceq[string]$requests.inventory_sha256-and[int]$result.request_count-eq[int]$requests.count-and
    $probe004Bound-and$sceneIsolationGreen-and[string]$result.authorized_probe_scene_sha256-ceq$ExpectedProbeSceneSha256-and[string]$result.scene_isolation_audit_sha256-ceq(Get-Pr90ProbeBSha256 $SceneIsolationAuditPath)-and-not[string]::IsNullOrWhiteSpace([string]$result.godot_gui_sha256)-and-not[string]::IsNullOrWhiteSpace([string]$result.godot_console_sha256)-and
    $listenerV2Bound-and(Test-Path -LiteralPath $endpointAttestation -PathType Leaf) -and (Test-Path -LiteralPath $endpointSamples -PathType Leaf) -and
    (Test-Path -LiteralPath $bridgeReady -PathType Leaf) -and (Test-Path -LiteralPath $bootstrap -PathType Leaf) -and (Test-Path -LiteralPath $ready -PathType Leaf) -and (Test-Path -LiteralPath $phase0 -PathType Leaf))
$attestation = [pscustomobject][ordered]@{
    schema='Pr90ExactCloneProbeBV2AttestationV1';probe_id=$ProbeId;status=if($allBound){'SEALED'}else{'BLOCKED'};created_at_utc=[DateTimeOffset]::UtcNow.ToString('o')
    result_path=if([string]::IsNullOrWhiteSpace($BoundResultPath)){[IO.Path]::GetFullPath($ResultPath)}else{[IO.Path]::GetFullPath($BoundResultPath)};result_sha256=Get-Pr90ProbeBSha256 $ResultPath
    probe_execution_start_sha256=[string]$result.probe_execution_start_sha256;probe_execution_config_sha256=[string]$result.probe_execution_config_sha256
    probe_execution_tooling_head_sha=[string]$result.tooling_head_sha;probe_execution_tooling_tree_sha=[string]$result.tooling_tree_sha;probe_execution_tooling_seal_sha256=[string]$result.tooling_seal_sha256
    result_recovery_tooling_head_sha=[string]$result.result_recovery_tooling_head_sha;result_recovery_tooling_tree_sha=[string]$result.result_recovery_tooling_tree_sha;result_recovery_tooling_manifest_sha256=[string]$result.result_recovery_tooling_manifest_sha256;result_recovery_tooling_seal_sha256=[string]$result.result_recovery_tooling_seal_sha256;runtime_reachable_tooling_hash_mismatch_count=[int]$result.runtime_reachable_tooling_hash_mismatch_count
    milestone_receipt_count=$receipts.count;milestone_receipt_inventory_sha256=$receipts.inventory_sha256;milestone_receipts=$receipts.rows
    probe004_result_sha256=Get-Pr90ProbeBSha256 $Probe004ResultPath;probe004_attestation_sha256=Get-Pr90ProbeBSha256 $Probe004AttestationPath
    godot_gui_sha256=[string]$result.godot_gui_sha256;godot_console_sha256=[string]$result.godot_console_sha256
    scene_isolation_audit_sha256=Get-Pr90ProbeBSha256 $SceneIsolationAuditPath;main_tscn_instance_count=[int]$sceneIsolation.main_tscn_instance_count
    post_import_baseline_sha256=Get-Pr90ProbeBSha256 $PostImportBaselinePath;class_cache_sha256=Get-Pr90ProbeBSha256 $ClassCachePath
    raw_mcp_evidence_count=$raw.count;raw_mcp_evidence_inventory_sha256=$raw.inventory_sha256;raw_mcp_evidence=$raw.rows
    request_count=$requests.count;request_inventory_sha256=$requests.inventory_sha256;request_inventory=$requests.rows
    endpoint_ownership_attestation_sha256=if(Test-Path -LiteralPath $endpointAttestation){Get-Pr90ProbeBSha256 $endpointAttestation}else{''}
    endpoint_ownership_samples_sha256=if(Test-Path -LiteralPath $endpointSamples){Get-Pr90ProbeBSha256 $endpointSamples}else{''}
    listener_forensics_sha256=Get-Pr90ProbeBSha256 $ListenerForensicsPath;listener_parity_root_cause_class=[string]$listenerForensics.root_cause_class;characterization_probe_execution_count=0
    bracketed_sample_model=[bool]$result.bracketed_sample_model;total_listener_cohort_attempt_count=[int]$result.total_listener_cohort_attempt_count;consecutive_stable_parity_cohort_count=[int]$result.consecutive_stable_parity_cohort_count;stable_parity_window_ms=[double]$result.stable_parity_window_ms
    listener_core_parity_key_field_count=[int]$result.listener_core_parity_key_field_count;matched_listener_process_enrichment_count=[int]$result.matched_listener_process_enrichment_count;duplicate_source_process_enrichment_count=[int]$result.duplicate_source_process_enrichment_count;raw_listener_evidence_preservation=[string]$result.raw_listener_evidence_preservation
    runtime_bridge_ready_status_sha256=if(Test-Path -LiteralPath $bridgeReady){Get-Pr90ProbeBSha256 $bridgeReady}else{''}
    runtime_bootstrap_sha256=if(Test-Path -LiteralPath $bootstrap){Get-Pr90ProbeBSha256 $bootstrap}else{''}
    ready_witness_sha256=if(Test-Path -LiteralPath $ready){Get-Pr90ProbeBSha256 $ready}else{''}
    phase0_sha256=if(Test-Path -LiteralPath $phase0){Get-Pr90ProbeBSha256 $phase0}else{''}
    finalizer_result_sha256=Get-Pr90ProbeBSha256 $FinalizerResultPath;terminal_manifest_sha256=Get-Pr90ProbeBSha256 $TerminalManifestPath
    unbound_evidence_count=if($allBound){0}else{1};probe_execution_count_delta=0;godot_process_start_count=0;mcp_process_start_count=0;formal_mcp_execution_count=0;authorized_run_count_consumed=0;canonical_payload_sha256=''
}
$attestation.canonical_payload_sha256 = Get-Pr90ProbeBCanonicalSha256 $attestation
Write-Pr90ProbeBImmutableJson -Path $OutputPath -Value $attestation -WriteSha256Sidecar | Out-Null
$attestation | ConvertTo-Json -Depth 100 -Compress
if (-not $allBound) { exit 2 }
