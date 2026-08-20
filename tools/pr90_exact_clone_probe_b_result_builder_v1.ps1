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
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [Parameter(Mandatory = $true)][string]$OutputMarkdownPath
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'pr90_probe_b_attempt22_contract_v1.psm1') -Force

$evidence = (Resolve-Path -LiteralPath $EvidenceRoot).Path
$statePath = Join-Path $evidence 'startup-state-machine-result.json'
$state = Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json -Depth 100
$receiptPaths = @(Get-ChildItem -LiteralPath (Join-Path $evidence 'milestones') -Filter '*.receipt.json' -File | Where-Object{$_.Name-match'^\d{2}-M(?:[0-9]|1[01])-.*\.receipt\.json$'} | Sort-Object Name | Select-Object -ExpandProperty FullName)
$receiptInventory = Get-Pr90ProbeBFileInventoryV1 -Paths $receiptPaths
$rawPaths = @(Get-ChildItem -LiteralPath (Join-Path $evidence 'mcp-raw') -Filter '*.json' -File | Sort-Object FullName | Select-Object -ExpandProperty FullName)
$rawInventory = Get-Pr90ProbeBFileInventoryV1 -Paths $rawPaths
$requestPaths = @(Get-ChildItem -LiteralPath (Join-Path $evidence 'requests') -Filter '*.json' -File | Sort-Object FullName | Select-Object -ExpandProperty FullName)
$requestInventory = Get-Pr90ProbeBFileInventoryV1 -Paths $requestPaths
$requests = @($requestPaths | ForEach-Object { Get-Content -Raw -LiteralPath $_ | ConvertFrom-Json -Depth 100 })
$enterPlayRequests = @($requests | Where-Object { [string]$_.params.name -ceq 'enter_play_mode' })
$projectInfoRequestCount = @($requests | Where-Object { [string]$_.params.name -ceq 'get_project_info' }).Count
$bridgeStatusRequestCount = @($requests | Where-Object { [string]$_.params.name -ceq 'get_runtime_bridge_status' }).Count
$runtimeEventsRequestCount = @($requests | Where-Object { [string]$_.params.name -ceq 'get_runtime_events' }).Count
$exitPlayModeRequestCount = @($requests | Where-Object { [string]$_.params.name -ceq 'exit_play_mode' }).Count
$allowedRequestTools=@('get_project_info','enter_play_mode','get_runtime_bridge_status','get_runtime_events','exit_play_mode')
$unauthorizedRequestCount=@($requests|Where-Object{$allowedRequestTools-cnotcontains[string]$_.params.name}).Count
$customNonMainRequestCount = @($enterPlayRequests | Where-Object { [string]$_.params.arguments.mode -ceq 'custom' -and [string]$_.params.arguments.scene_path -ceq $ProbeScenePath -and $ProbeScenePath -notin @('res://scenes/main.tscn','res://main.tscn') }).Count
$playMainSceneRequestCount = @($requests | Where-Object { [string]$_.params.name -ceq 'play_main_scene' -or [string]$_.params.arguments.scene_path -in @('res://scenes/main.tscn','res://main.tscn') }).Count
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
$listenerSampleContract=Test-Pr90ProbeBListenerSampleContractV1 -TotalSampleCount ([int]$state.total_listener_sample_count) -ConsecutiveParitySampleCount ([int]$state.consecutive_parity_sample_count) -StableWindowMs ([double]$state.endpoint_owner_stable_window_ms) -ObserverSourceCount ([int]$state.endpoint_listener_observer_source_count) -Parity ([bool]$state.endpoint_listener_observer_parity)
$green = ([string]$state.status -ceq 'PASS' -and $passCount -eq 12 -and $failCount -eq 0 -and $receiptInventory.count -eq 12 -and
    $milestoneSequenceGreen-and[bool]$state.endpoint_owner_is_gui_engine -and -not [bool]$state.endpoint_owner_is_console_wrapper -and [bool]$state.endpoint_owner_is_descendant_of_launcher -and
    [bool]$state.endpoint_owner_command_line_fixture_match -and [bool]$state.endpoint_owner_windows_session_match -and [bool]$state.endpoint_owner_user_sid_match -and$listenerSampleContract-and
    [int]$state.endpoint_listener_a_only_count -eq 0 -and [int]$state.endpoint_listener_b_only_count -eq 0 -and [int]$state.endpoint_owner_pid_changed_count -eq 0 -and
    [int]$state.endpoint_owner_creation_identity_changed_count -eq 0 -and [int]$state.endpoint_owner_process_lineage_changed_count -eq 0 -and [int]$state.multiple_active_endpoint_owner_count -eq 0 -and
    [int]$state.prelaunch_protected_port_listener_count -eq 0 -and [bool]$state.stops_cleanly -and -not [bool]$state.forced_stop -and
    [double]$state.endpoint_owner_stable_window_ms -ge 1000 -and [bool]$state.first_jsonrpc_request_sent -and [bool]$state.first_jsonrpc_response_received -and
    $missingEvidence.Count -eq 0 -and$sceneIsolationGreen-and
    $requestInventory.count-eq$requests.Count-and$projectInfoRequestCount-eq1-and$enterPlayRequests.Count -eq 1 -and$bridgeStatusRequestCount-ge1-and$runtimeEventsRequestCount-ge2-and$exitPlayModeRequestCount-eq1-and$unauthorizedRequestCount-eq0-and$customNonMainRequestCount -eq 1 -and $playMainSceneRequestCount -eq 0 -and $productEventCount -eq 0 -and
    [string]$finalizer.status -ceq 'PASS' -and [string]$terminal.status -ceq 'PASS' -and
    [int]$terminal.godot_process_count -eq 0 -and [int]$terminal.mcp_process_count -eq 0 -and [int]$terminal.port_7576_count -eq 0 -and [int]$terminal.port_7586_count -eq 0)
$cloneFingerprintBytes = [Text.UTF8Encoding]::new($false).GetBytes(([IO.Path]::GetFullPath([string]$state.evidence_root).ToLowerInvariant()))
$result = [pscustomobject][ordered]@{
    schema='Pr90ExactCloneProbeBResultV1';probe_id=$ProbeId;status=if($green){'PASS'}else{'BLOCKED'};created_at_utc=[DateTimeOffset]::UtcNow.ToString('o')
    product_head_sha=$ProductHeadSha;product_tree_sha=$ProductTreeSha;tooling_head_sha=$ToolingHeadSha;tooling_tree_sha=$ToolingTreeSha
    tooling_seal_sha256=Get-Pr90ProbeBSha256 $ToolingSealPath
    exact_clone_path_fingerprint=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($cloneFingerprintBytes)).ToLowerInvariant()
    post_import_baseline_sha256=Get-Pr90ProbeBSha256 $PostImportBaselinePath;class_cache_sha256=Get-Pr90ProbeBSha256 $ClassCachePath
    godot_gui_sha256=Get-Pr90ProbeBSha256 $GodotGuiPath;godot_console_sha256=Get-Pr90ProbeBSha256 $GodotConsolePath
    milestone_pass_count=$passCount;milestone_fail_count=$failCount;milestone_receipt_count=$receiptInventory.count;milestone_receipt_inventory_sha256=$receiptInventory.inventory_sha256;milestone_sequence_green=$milestoneSequenceGreen;milestone_duplicate_count=$milestoneRows.Count-@($milestoneRows.milestone_id|Select-Object -Unique).Count
    endpoint_ownership_mode=if([bool]$state.endpoint_owner_is_gui_engine){'GUI_ENGINE'}else{'UNKNOWN'}
    endpoint_owner_process_lineage_result=[bool]$state.endpoint_owner_is_descendant_of_launcher
    dual_source_listener_parity_result=[bool]$state.endpoint_listener_observer_parity
    endpoint_owner_total_listener_sample_count=[int]$state.total_listener_sample_count;endpoint_owner_dual_source_parity_count=[int]$state.consecutive_parity_sample_count;endpoint_owner_stable_window_ms=[double]$state.endpoint_owner_stable_window_ms
    first_jsonrpc_result=([bool]$state.first_jsonrpc_request_sent -and [bool]$state.first_jsonrpc_response_received)
    raw_evidence_result=($rawInventory.count -gt 0);raw_mcp_evidence_inventory_sha256=$rawInventory.inventory_sha256
    runtime_bootstrap_result=(Test-Path -LiteralPath $requiredEvidence.runtime_bootstrap -PathType Leaf)
    ready_witness_result=(Test-Path -LiteralPath $requiredEvidence.ready_witness -PathType Leaf)
    phase0_result=(Test-Path -LiteralPath $requiredEvidence.phase0 -PathType Leaf)
    import_finalizer_status=[string]$finalizer.status;terminal_process_port_status=[string]$terminal.status
    stopped_cleanly=[bool]$state.stops_cleanly;forced_stop=[bool]$state.forced_stop
    authorized_probe_scene_path=$ProbeScenePath;authorized_probe_scene_sha256=$ExpectedProbeSceneSha256;enter_play_mode_request_count=$enterPlayRequests.Count;custom_non_main_scene_request_count=$customNonMainRequestCount
    request_count=$requestInventory.count;request_inventory_sha256=$requestInventory.inventory_sha256;request_inventory=$requestInventory.rows;get_project_info_request_count=$projectInfoRequestCount;runtime_bridge_status_request_count=$bridgeStatusRequestCount;runtime_events_request_count=$runtimeEventsRequestCount;exit_play_mode_request_count=$exitPlayModeRequestCount;unauthorized_request_count=$unauthorizedRequestCount
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
# PR #90 Exact Clone Startup Probe B

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
