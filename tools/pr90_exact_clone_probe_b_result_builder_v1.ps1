[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProbeId,
    [Parameter(Mandatory = $true)][string]$EvidenceRoot,
    [Parameter(Mandatory = $true)][string]$ProductHeadSha,
    [Parameter(Mandatory = $true)][string]$ProductTreeSha,
    [Parameter(Mandatory = $true)][string]$ToolingHeadSha,
    [Parameter(Mandatory = $true)][string]$ToolingTreeSha,
    [Parameter(Mandatory = $true)][string]$ToolingSealPath,
    [Parameter(Mandatory = $true)][string]$PostImportBaselinePath,
    [Parameter(Mandatory = $true)][string]$ClassCachePath,
    [Parameter(Mandatory = $true)][string]$GodotGuiPath,
    [Parameter(Mandatory = $true)][string]$GodotConsolePath,
    [Parameter(Mandatory = $true)][string]$FinalizerResultPath,
    [Parameter(Mandatory = $true)][string]$TerminalManifestPath,
    [Parameter(Mandatory = $true)][string]$ProbeScenePath,
    [Parameter(Mandatory = $true)][string]$ExpectedProbeSceneSha256,
    [Parameter(Mandatory = $true)][string]$SceneIsolationAuditPath,
    [Parameter(Mandatory = $true)][string]$ListenerForensicsPath,
    [Parameter(Mandatory = $true)][string]$ExpectedListenerForensicsSha256,
    [string]$ExecutionStartPath = '',
    [string]$ExpectedExecutionStartSha256 = '',
    [string]$ExecutionConfigPath = '',
    [string]$ExpectedExecutionConfigSha256 = '',
    [string]$RecoveryToolingHeadSha = '',
    [string]$RecoveryToolingTreeSha = '',
    [string]$RecoveryToolingManifestPath = '',
    [string]$RecoveryToolingSealPath = '',
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [Parameter(Mandatory = $true)][string]$OutputMarkdownPath
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'pr90_probe_b_attempt22_contract_v1.psm1') -Force

$evidence = (Resolve-Path -LiteralPath $EvidenceRoot).Path
$probeRoot = [IO.Path]::GetFullPath((Split-Path -Parent $evidence))
if ([string]::IsNullOrWhiteSpace($ExecutionStartPath)) { $ExecutionStartPath = Join-Path $probeRoot 'probe-b-execution-start.json' }
$executionStart = Get-Content -Raw -LiteralPath $ExecutionStartPath | ConvertFrom-Json -Depth 100
if ([string]::IsNullOrWhiteSpace($ExecutionConfigPath)) { $ExecutionConfigPath = [string]$executionStart.config_path }
$executionConfig = Get-Content -Raw -LiteralPath $ExecutionConfigPath | ConvertFrom-Json -Depth 100
$executionStartSha = Get-Pr90ProbeBSha256 $ExecutionStartPath
$executionConfigSha = Get-Pr90ProbeBSha256 $ExecutionConfigPath
if ([string]::IsNullOrWhiteSpace($ExpectedExecutionStartSha256)) { $ExpectedExecutionStartSha256 = $executionStartSha }
if ([string]::IsNullOrWhiteSpace($ExpectedExecutionConfigSha256)) { $ExpectedExecutionConfigSha256 = $executionConfigSha }
$executionToolingSealSha = Get-Pr90ProbeBSha256 $ToolingSealPath
$exactClonePath = Join-Path ([string]$executionConfig.probe_root) 'exact-product-clone'
$exactClonePathFingerprint = Get-Pr90ProbeBPathFingerprintV1 $exactClonePath
$exactCloneHead = (& git -C $exactClonePath rev-parse HEAD).Trim()
$exactCloneTree = (& git -C $exactClonePath rev-parse 'HEAD^{tree}').Trim()
$executionIdentityGreen = (
    $executionStartSha -ceq $ExpectedExecutionStartSha256.ToLowerInvariant() -and $executionConfigSha -ceq $ExpectedExecutionConfigSha256.ToLowerInvariant() -and
    [string]$executionStart.schema -ceq 'Pr90ExactCloneProbeBV2ExecutionStartV1' -and [string]$executionStart.probe_id -ceq $ProbeId -and [int]$executionStart.execution_count -eq 1 -and
    [string]$executionStart.config_sha256 -ceq $executionConfigSha -and [string]$executionConfig.schema -ceq 'Pr90ExactCloneProbeBV2ExecutionConfigV1' -and [string]$executionConfig.probe_id -ceq $ProbeId -and
    [IO.Path]::GetFullPath([string]$executionConfig.probe_root) -ceq $probeRoot -and [string]$executionStart.product_head_sha -ceq $ProductHeadSha -and [string]$executionStart.product_tree_sha -ceq $ProductTreeSha -and
    [string]$executionStart.tooling_head_sha -ceq $ToolingHeadSha -and [string]$executionStart.tooling_tree_sha -ceq $ToolingTreeSha -and [string]$executionStart.tooling_seal_sha256 -ceq $executionToolingSealSha -and
    [string]$executionConfig.tooling_head_sha -ceq $ToolingHeadSha -and [string]$executionConfig.tooling_tree_sha -ceq $ToolingTreeSha -and [string]$executionConfig.tooling_seal_sha256 -ceq $executionToolingSealSha -and
    [string]$executionStart.clone_path_fingerprint -ceq $exactClonePathFingerprint -and $exactCloneHead -ceq $ProductHeadSha -and $exactCloneTree -ceq $ProductTreeSha
)
if ([string]::IsNullOrWhiteSpace($RecoveryToolingHeadSha)) { $RecoveryToolingHeadSha = $ToolingHeadSha }
if ([string]::IsNullOrWhiteSpace($RecoveryToolingTreeSha)) { $RecoveryToolingTreeSha = $ToolingTreeSha }
if ([string]::IsNullOrWhiteSpace($RecoveryToolingManifestPath)) { $RecoveryToolingManifestPath = [string]$executionConfig.tooling_manifest_path }
if ([string]::IsNullOrWhiteSpace($RecoveryToolingSealPath)) { $RecoveryToolingSealPath = $ToolingSealPath }
$recoveryManifest = Get-Content -Raw -LiteralPath $RecoveryToolingManifestPath | ConvertFrom-Json -Depth 100
$recoverySeal = Get-Content -Raw -LiteralPath $RecoveryToolingSealPath | ConvertFrom-Json -Depth 100
$recoveryManifestSha = Get-Pr90ProbeBSha256 $RecoveryToolingManifestPath
$recoverySealSha = Get-Pr90ProbeBSha256 $RecoveryToolingSealPath
$sameToolingIdentity = $RecoveryToolingHeadSha -ceq $ToolingHeadSha -and $RecoveryToolingTreeSha -ceq $ToolingTreeSha
$runtimeReachableToolingHashMismatchCount = if ($recoveryManifest.PSObject.Properties.Name -ccontains 'runtime_reachable_tooling_hash_mismatch_count') { [int]$recoveryManifest.runtime_reachable_tooling_hash_mismatch_count } elseif ($sameToolingIdentity) { 0 } else { 1 }
$recoveryIdentityGreen = (
    [string]$recoveryManifest.status -ceq 'READY' -and [string]$recoveryManifest.tooling_head_sha -ceq $RecoveryToolingHeadSha -and [string]$recoveryManifest.tooling_tree_sha -ceq $RecoveryToolingTreeSha -and
    [string]$recoverySeal.status -ceq 'SEALED' -and [string]$recoverySeal.tooling_head_sha -ceq $RecoveryToolingHeadSha -and [string]$recoverySeal.tooling_tree_sha -ceq $RecoveryToolingTreeSha -and
    [string]$recoverySeal.manifest_sha256 -ceq $recoveryManifestSha -and $runtimeReachableToolingHashMismatchCount -eq 0
)
$statePath = Join-Path $evidence 'startup-state-machine-result.json'
$state = Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json -Depth 100
$endpointAttestationPath=Join-Path $evidence 'endpoint-ownership-v2-attestation.json'
$endpointCohortsPath=Join-Path $evidence 'endpoint-ownership-v2-samples.json'
$endpointAttestation=if(Test-Path -LiteralPath $endpointAttestationPath -PathType Leaf){Get-Content -Raw -LiteralPath $endpointAttestationPath|ConvertFrom-Json -Depth 100}else{$null}
$endpointCohorts=if(Test-Path -LiteralPath $endpointCohortsPath -PathType Leaf){Get-Content -Raw -LiteralPath $endpointCohortsPath|ConvertFrom-Json -Depth 100}else{$null}
$listenerForensics=Get-Content -Raw -LiteralPath $ListenerForensicsPath|ConvertFrom-Json -Depth 100
$listenerForensicsGreen=((Get-Pr90ProbeBSha256 $ListenerForensicsPath)-ceq$ExpectedListenerForensicsSha256-and[string]$listenerForensics.schema-ceq'Pr90FrozenProbeBListenerParityFieldDiffMatrixV1'-and[string]$listenerForensics.status-ceq'ROOT_CAUSE_RESOLVED'-and[int]$listenerForensics.sample_count-eq23-and[int]$listenerForensics.old_parity_count-eq0-and[int]$listenerForensics.listener_core_equal_sample_count-eq23-and[string]$listenerForensics.root_cause_class-ceq'J'-and-not[bool]$listenerForensics.characterization_probe_required-and[int]$listenerForensics.characterization_probe_execution_count-eq0)
$receiptPaths = @(Get-ChildItem -LiteralPath (Join-Path $evidence 'milestones') -Filter '*.receipt.json' -File | Where-Object{$_.Name-match'^\d{2}-M(?:[0-9]|1[01])-.*\.receipt\.json$'} | Sort-Object Name | Select-Object -ExpandProperty FullName)
$receiptInventory = Get-Pr90ProbeBFileInventoryV1 -Paths $receiptPaths
$rawPaths = @(Get-ChildItem -LiteralPath (Join-Path $evidence 'mcp-raw') -Filter '*.json' -File | Sort-Object FullName | Select-Object -ExpandProperty FullName)
$rawInventory = Get-Pr90ProbeBFileInventoryV1 -Paths $rawPaths
$requestPaths = @(Get-ChildItem -LiteralPath (Join-Path $evidence 'requests') -Filter '*.json' -File | Sort-Object FullName | Select-Object -ExpandProperty FullName)
$requestInventory = Get-Pr90ProbeBFileInventoryV1 -Paths $requestPaths
$requests = @($requestPaths | ForEach-Object { Get-Content -Raw -LiteralPath $_ | ConvertFrom-Json -Depth 100 })
$requestFacts = @($requests | ForEach-Object { ConvertTo-Pr90ProbeBRequestFactV1 -Request $_ })
$enterPlayRequests = @($requestFacts | Where-Object { [string]$_.name -ceq 'enter_play_mode' })
$projectInfoRequestCount = @($requestFacts | Where-Object { [string]$_.name -ceq 'get_project_info' }).Count
$bridgeStatusRequestCount = @($requestFacts | Where-Object { [string]$_.name -ceq 'get_runtime_bridge_status' }).Count
$runtimeEventsRequestCount = @($requestFacts | Where-Object { [string]$_.name -ceq 'get_runtime_events' }).Count
$exitPlayModeRequestCount = @($requestFacts | Where-Object { [string]$_.name -ceq 'exit_play_mode' }).Count
$allowedRequestTools=@('get_project_info','enter_play_mode','get_runtime_bridge_status','get_runtime_events','exit_play_mode')
$unauthorizedRequestCount=@($requestFacts|Where-Object{$allowedRequestTools-cnotcontains[string]$_.name}).Count
$malformedRequestCount=@($requestFacts|Where-Object{[bool]$_.malformed}).Count
$customNonMainRequestCount = @($enterPlayRequests | Where-Object { [string]$_.mode -ceq 'custom' -and [string]$_.scene_path -ceq $ProbeScenePath -and $ProbeScenePath -notin @('res://scenes/main.tscn','res://main.tscn') }).Count
$playMainSceneRequestCount = @($requestFacts | Where-Object { [bool]$_.requests_main_scene }).Count
$phaseEvidencePath=Join-Path $evidence 'phases/000-phase-0-ready.json'
$phaseEvents=@()
if(Test-Path -LiteralPath $phaseEvidencePath -PathType Leaf){$phaseEvidence=Get-Content -Raw -LiteralPath $phaseEvidencePath|ConvertFrom-Json -Depth 100;$phaseEvents=@($phaseEvidence.events)}
$productEventCount = @($phaseEvents | Where-Object { (([string]$_.kind)+' '+([string]$_.message)) -match '(?i)(new[_ -]?game|match[_ -]?(?:start|created)|product[_ -]?frame)' }).Count
$finalizer = Get-Content -Raw -LiteralPath $FinalizerResultPath | ConvertFrom-Json -Depth 100
$terminal = Get-Content -Raw -LiteralPath $TerminalManifestPath | ConvertFrom-Json -Depth 100
$sceneIsolation=Get-Content -Raw -LiteralPath $SceneIsolationAuditPath|ConvertFrom-Json -Depth 100
$sceneIsolationGreen=Test-Pr90ProbeBSceneIsolationContractV1 -Audit $sceneIsolation -ExpectedScenePath $ProbeScenePath -ExpectedSceneSha256 $ExpectedProbeSceneSha256
$milestoneRows = @($receiptPaths | ForEach-Object { Get-Content -Raw -LiteralPath $_ | ConvertFrom-Json -Depth 100 })
$passCount = @($milestoneRows | Where-Object { [string]$_.status -ceq 'PASS' }).Count
$failCount = @($milestoneRows | Where-Object { [string]$_.status -ceq 'FAIL' }).Count
$expectedMilestoneIds=@(0..11|ForEach-Object{"M$_"})
$milestoneSequenceGreen=$milestoneRows.Count-eq12
for($milestoneIndex=0;$milestoneIndex-lt$milestoneRows.Count;$milestoneIndex+=1){if([int]$milestoneRows[$milestoneIndex].milestone_index-ne$milestoneIndex-or[string]$milestoneRows[$milestoneIndex].milestone_id-cne$expectedMilestoneIds[$milestoneIndex]-or[string]$milestoneRows[$milestoneIndex].run_id-cne$ProbeId-or[string]$milestoneRows[$milestoneIndex].status-cne'PASS'){$milestoneSequenceGreen=$false}}
$requiredEvidence = [ordered]@{
    endpoint_ownership = Join-Path $evidence 'endpoint-ownership-v2-attestation.json'
    runtime_bootstrap = Join-Path $evidence 'witnesses/runtime-stream-bootstrap.json'
    ready_witness = Join-Path $evidence 'witnesses/ready-witness.json'
    phase0 = Join-Path $evidence 'phases/000-phase-0-ready.json'
}
$missingEvidence = @($requiredEvidence.GetEnumerator() | Where-Object { -not (Test-Path -LiteralPath $_.Value -PathType Leaf) } | ForEach-Object { $_.Key })
$cohortRows=if($null-ne$endpointCohorts){@($endpointCohorts.cohorts)}else{@()}
$rawSourceRows=@($cohortRows|ForEach-Object{@($_.a_before,$_.source_b,$_.a_after)})
$cohortEvidenceGreen=($null-ne$endpointCohorts-and[string]$endpointCohorts.schema-ceq'SpaceSyndicatePr90McpEndpointOwnershipBracketedCohortsV2'-and[bool]$endpointCohorts.bracketed_sample_model-and[string]$endpointCohorts.raw_listener_evidence_preservation-ceq'100_PERCENT'-and[int]$endpointCohorts.cohort_count-ge5-and$cohortRows.Count-eq[int]$endpointCohorts.cohort_count-and@($rawSourceRows|Where-Object{-not[bool]$_.raw_evidence_preserved-or[string]::IsNullOrWhiteSpace([string]$_.observer_started_utc)-or[string]::IsNullOrWhiteSpace([string]$_.observer_completed_utc)}).Count-eq0)
$ownerContractGreen=($null-ne$endpointAttestation-and[string]$endpointAttestation.schema-ceq'SpaceSyndicatePr90McpEndpointOwnershipBracketedV2Attestation'-and[string]$endpointAttestation.status-ceq'PASS'-and[bool]$endpointAttestation.green-and[bool]$endpointAttestation.bracketed_sample_model-and
    [int]$state.total_listener_cohort_attempt_count-ge5-and[int]$state.consecutive_stable_parity_cohort_count-ge5-and[double]$state.stable_parity_window_ms-ge1000-and[int]$state.endpoint_listener_observer_source_count-eq2-and[bool]$state.endpoint_listener_core_parity-and
    [int]$state.endpoint_listener_a_only_core_count-eq0-and[int]$state.endpoint_listener_b_only_core_count-eq0-and[int]$state.listener_core_parity_key_field_count-eq5-and[int]$state.listener_core_parity_observer_specific_field_count-eq0-and[int]$state.listener_core_parity_process_enrichment_field_count-eq0-and
    [int]$state.matched_listener_process_enrichment_count-eq1-and[int]$state.duplicate_source_process_enrichment_count-eq0-and[bool]$state.endpoint_owner_is_gui_engine-and-not[bool]$state.endpoint_owner_is_console_wrapper-and[bool]$state.endpoint_owner_is_descendant_of_launcher-and
    [bool]$state.endpoint_owner_project_match-and[bool]$state.endpoint_owner_mcp_session_match-and[bool]$state.endpoint_owner_windows_session_match-and[bool]$state.endpoint_owner_user_sid_match-and[bool]$state.endpoint_owner_creation_identity_match-and
    [int]$state.endpoint_owner_pid_changed_count-eq0-and[int]$state.endpoint_owner_identity_changed_count-eq0-and[int]$state.protected_port_multiple_owner_count-eq0-and[int]$state.foreign_listener_count-eq0)
$green = ($executionIdentityGreen -and $recoveryIdentityGreen -and [string]$state.status -ceq 'PASS' -and $passCount -eq 12 -and $failCount -eq 0 -and $receiptInventory.count -eq 12 -and
    $milestoneSequenceGreen-and[bool]$state.endpoint_owner_is_gui_engine -and -not [bool]$state.endpoint_owner_is_console_wrapper -and [bool]$state.endpoint_owner_is_descendant_of_launcher -and
    [bool]$state.endpoint_owner_command_line_fixture_match -and [bool]$state.endpoint_owner_windows_session_match -and [bool]$state.endpoint_owner_user_sid_match -and$ownerContractGreen-and$cohortEvidenceGreen-and$listenerForensicsGreen-and
    [int]$state.endpoint_listener_a_only_count -eq 0 -and [int]$state.endpoint_listener_b_only_count -eq 0 -and [int]$state.endpoint_owner_pid_changed_count -eq 0 -and
    [int]$state.endpoint_owner_creation_identity_changed_count -eq 0 -and [int]$state.endpoint_owner_process_lineage_changed_count -eq 0 -and [int]$state.multiple_active_endpoint_owner_count -eq 0 -and
    [int]$state.prelaunch_protected_port_listener_count -eq 0 -and [bool]$state.stops_cleanly -and -not [bool]$state.forced_stop -and
    [double]$state.endpoint_owner_stable_window_ms -ge 1000 -and [bool]$state.first_jsonrpc_request_sent -and [bool]$state.first_jsonrpc_response_received -and
    $missingEvidence.Count -eq 0 -and$sceneIsolationGreen-and
    $requestInventory.count-eq$requests.Count-and$malformedRequestCount-eq0-and$projectInfoRequestCount-eq1-and$enterPlayRequests.Count -eq 1 -and$bridgeStatusRequestCount-ge1-and$runtimeEventsRequestCount-ge2-and$exitPlayModeRequestCount-eq1-and$unauthorizedRequestCount-eq0-and$customNonMainRequestCount -eq 1 -and $playMainSceneRequestCount -eq 0 -and $productEventCount -eq 0 -and
    [string]$finalizer.status -ceq 'PASS' -and [string]$terminal.status -ceq 'PASS' -and
    [int]$terminal.godot_process_count -eq 0 -and [int]$terminal.mcp_process_count -eq 0 -and [int]$terminal.port_7576_count -eq 0 -and [int]$terminal.port_7586_count -eq 0)
$result = [pscustomobject][ordered]@{
    schema='Pr90ExactCloneProbeBV2ResultV1';probe_id=$ProbeId;status=if($green){'PASS'}else{'BLOCKED'};created_at_utc=[DateTimeOffset]::UtcNow.ToString('o')
    product_head_sha=$ProductHeadSha;product_tree_sha=$ProductTreeSha;tooling_head_sha=$ToolingHeadSha;tooling_tree_sha=$ToolingTreeSha
    tooling_seal_sha256=Get-Pr90ProbeBSha256 $ToolingSealPath
    probe_execution_start_path=[IO.Path]::GetFullPath($ExecutionStartPath);probe_execution_start_sha256=$executionStartSha;probe_execution_config_path=[IO.Path]::GetFullPath($ExecutionConfigPath);probe_execution_config_sha256=$executionConfigSha
    probe_execution_tooling_head_sha=$ToolingHeadSha;probe_execution_tooling_tree_sha=$ToolingTreeSha;probe_execution_tooling_seal_sha256=$executionToolingSealSha
    result_recovery_tooling_head_sha=$RecoveryToolingHeadSha;result_recovery_tooling_tree_sha=$RecoveryToolingTreeSha;result_recovery_tooling_manifest_sha256=$recoveryManifestSha;result_recovery_tooling_seal_sha256=$recoverySealSha;runtime_reachable_tooling_hash_mismatch_count=$runtimeReachableToolingHashMismatchCount
    exact_clone_path_fingerprint=$exactClonePathFingerprint
    post_import_baseline_sha256=Get-Pr90ProbeBSha256 $PostImportBaselinePath;class_cache_sha256=Get-Pr90ProbeBSha256 $ClassCachePath
    godot_gui_sha256=Get-Pr90ProbeBSha256 $GodotGuiPath;godot_console_sha256=Get-Pr90ProbeBSha256 $GodotConsolePath
    milestone_pass_count=$passCount;milestone_fail_count=$failCount;milestone_receipt_count=$receiptInventory.count;milestone_receipt_inventory_sha256=$receiptInventory.inventory_sha256;milestone_sequence_green=$milestoneSequenceGreen;milestone_duplicate_count=$milestoneRows.Count-@($milestoneRows.milestone_id|Select-Object -Unique).Count
    endpoint_ownership_mode=if([bool]$state.endpoint_owner_is_gui_engine){'GUI_ENGINE'}else{'UNKNOWN'}
    endpoint_owner_process_lineage_result=[bool]$state.endpoint_owner_is_descendant_of_launcher
    dual_source_listener_parity_result=[bool]$state.endpoint_listener_observer_parity
    endpoint_owner_total_listener_sample_count=[int]$state.total_listener_sample_count;endpoint_owner_dual_source_parity_count=[int]$state.consecutive_parity_sample_count;endpoint_owner_stable_window_ms=[double]$state.endpoint_owner_stable_window_ms
    bracketed_sample_model=[bool]$state.bracketed_sample_model;total_listener_cohort_attempt_count=[int]$state.total_listener_cohort_attempt_count;consecutive_stable_parity_cohort_count=[int]$state.consecutive_stable_parity_cohort_count;stable_parity_window_ms=[double]$state.stable_parity_window_ms;unstable_cohort_count=[int]$state.unstable_cohort_count
    endpoint_listener_observer_source_count=[int]$state.endpoint_listener_observer_source_count;endpoint_listener_core_parity=[bool]$state.endpoint_listener_core_parity;endpoint_listener_a_only_core_count=[int]$state.endpoint_listener_a_only_core_count;endpoint_listener_b_only_core_count=[int]$state.endpoint_listener_b_only_core_count
    listener_core_parity_key_field_count=[int]$state.listener_core_parity_key_field_count;observer_specific_field_in_new_key_count=[int]$state.listener_core_parity_observer_specific_field_count;process_enrichment_field_in_new_key_count=[int]$state.listener_core_parity_process_enrichment_field_count
    matched_listener_process_enrichment_count=[int]$state.matched_listener_process_enrichment_count;duplicate_source_process_enrichment_count=[int]$state.duplicate_source_process_enrichment_count
    endpoint_owner_is_gui_engine=[bool]$state.endpoint_owner_is_gui_engine;endpoint_owner_is_console_wrapper=[bool]$state.endpoint_owner_is_console_wrapper;endpoint_owner_is_descendant_of_launcher=[bool]$state.endpoint_owner_is_descendant_of_launcher;endpoint_owner_project_match=[bool]$state.endpoint_owner_project_match;endpoint_owner_mcp_session_match=[bool]$state.endpoint_owner_mcp_session_match;endpoint_owner_windows_session_match=[bool]$state.endpoint_owner_windows_session_match;endpoint_owner_user_sid_match=[bool]$state.endpoint_owner_user_sid_match;endpoint_owner_creation_identity_match=[bool]$state.endpoint_owner_creation_identity_match
    endpoint_owner_pid_changed_count=[int]$state.endpoint_owner_pid_changed_count;endpoint_owner_identity_changed_count=[int]$state.endpoint_owner_identity_changed_count;protected_port_multiple_owner_count=[int]$state.protected_port_multiple_owner_count;foreign_listener_count=[int]$state.foreign_listener_count
    listener_forensics_root_cause_class=[string]$listenerForensics.root_cause_class;listener_forensics_root_cause_components=@($listenerForensics.root_cause_components);listener_forensics_sha256=Get-Pr90ProbeBSha256 $ListenerForensicsPath;characterization_probe_execution_count=0
    bracketed_cohort_evidence_sha256=if($null-ne$endpointCohorts){Get-Pr90ProbeBSha256 $endpointCohortsPath}else{''};shared_process_identity_attestation_sha256=if($null-ne$endpointAttestation){Get-Pr90ProbeBSha256 $endpointAttestationPath}else{''};raw_listener_evidence_preservation=if($cohortEvidenceGreen){'100_PERCENT'}else{'INCOMPLETE'}
    first_jsonrpc_result=([bool]$state.first_jsonrpc_request_sent -and [bool]$state.first_jsonrpc_response_received)
    raw_evidence_result=($rawInventory.count -gt 0);raw_mcp_evidence_inventory_sha256=$rawInventory.inventory_sha256
    runtime_bootstrap_result=(Test-Path -LiteralPath $requiredEvidence.runtime_bootstrap -PathType Leaf)
    ready_witness_result=(Test-Path -LiteralPath $requiredEvidence.ready_witness -PathType Leaf)
    phase0_result=(Test-Path -LiteralPath $requiredEvidence.phase0 -PathType Leaf)
    import_finalizer_status=[string]$finalizer.status;terminal_process_port_status=[string]$terminal.status
    stopped_cleanly=[bool]$state.stops_cleanly;forced_stop=[bool]$state.forced_stop
    authorized_probe_scene_path=$ProbeScenePath;authorized_probe_scene_sha256=$ExpectedProbeSceneSha256;enter_play_mode_request_count=$enterPlayRequests.Count;custom_non_main_scene_request_count=$customNonMainRequestCount
    request_count=$requestInventory.count;request_inventory_sha256=$requestInventory.inventory_sha256;request_inventory=$requestInventory.rows;malformed_request_count=$malformedRequestCount;get_project_info_request_count=$projectInfoRequestCount;runtime_bridge_status_request_count=$bridgeStatusRequestCount;runtime_events_request_count=$runtimeEventsRequestCount;exit_play_mode_request_count=$exitPlayModeRequestCount;unauthorized_request_count=$unauthorizedRequestCount
    play_main_scene_count=$playMainSceneRequestCount;main_tscn_instance_count=[int]$sceneIsolation.main_tscn_instance_count;main_tscn_dependency_count=[int]$sceneIsolation.main_tscn_dependency_count;scene_isolation_audit_sha256=Get-Pr90ProbeBSha256 $SceneIsolationAuditPath;product_match_count=$productEventCount;product_frame_count=$productEventCount;formal_product_result_count=0
    missing_required_evidence_count=$missingEvidence.Count;missing_required_evidence=@($missingEvidence)
    state_machine_result_path=$statePath;state_machine_result_sha256=Get-Pr90ProbeBSha256 $statePath
    finalizer_result_path=[IO.Path]::GetFullPath($FinalizerResultPath);finalizer_result_sha256=Get-Pr90ProbeBSha256 $FinalizerResultPath
    terminal_manifest_path=[IO.Path]::GetFullPath($TerminalManifestPath);terminal_manifest_sha256=Get-Pr90ProbeBSha256 $TerminalManifestPath
    canonical_payload_sha256=''
}
$result.canonical_payload_sha256 = Get-Pr90ProbeBCanonicalSha256 $result
Write-Pr90ProbeBImmutableJson -Path $OutputPath -Value $result -WriteSha256Sidecar | Out-Null
$markdown = @"
# PR #90 Exact Clone Startup Probe B V2

- Probe: $ProbeId
- Status: $($result.status)
- Product: $ProductHeadSha / $ProductTreeSha
- Tooling: $ToolingHeadSha / $ToolingTreeSha
- Milestones: $passCount/12 PASS; $failCount FAIL
- Endpoint owner: $($result.endpoint_ownership_mode)
- Finalizer: $($result.import_finalizer_status)
- Terminal: $($result.terminal_process_port_status)
- Formal MCP consumed: false
"@
Write-Pr90ProbeBImmutableText -Path $OutputMarkdownPath -Text $markdown | Out-Null
$result | ConvertTo-Json -Depth 100 -Compress
if (-not $green) { exit 2 }
