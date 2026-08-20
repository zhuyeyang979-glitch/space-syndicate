[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ConfigPath,
    [Parameter(Mandatory = $true)][string]$OutputPath
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'pr90_probe_b_attempt22_contract_v1.psm1') -Force
$config = Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json -Depth 100
if ([string]$config.schema -cne 'Pr90Attempt22AuthorizationConfigV4') { throw 'Attempt 22 preformal config schema mismatch.' }
if (Test-Path -LiteralPath $OutputPath) { throw 'Preformal V2 output must be new.' }
$processesBefore = @(Get-Pr90ProductProcessRowsV1)
$mcpProcessesBefore = @(Get-Pr90McpSupportProcessRowsV1)
$listenersBefore = @(Get-Pr90ProtectedListenerRowsV1)
$checks = [Collections.Generic.List[object]]::new()
function Add-PreformalCheck {
    param([int]$Id,[string]$Name,[bool]$Pass,[string]$Detail)
    $checks.Add([pscustomobject][ordered]@{id=$Id;name=$Name;pass=$Pass;detail=$Detail})
}
function Test-HashBinding {
    param([string]$Path,[string]$Expected)
    return (-not [string]::IsNullOrWhiteSpace($Path)) -and (-not [string]::IsNullOrWhiteSpace($Expected)) -and (Test-Path -LiteralPath $Path -PathType Leaf) -and ((Get-Pr90ProbeBSha256 $Path) -ceq $Expected)
}
function Test-PowerShellLoad {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    $tokens=$null;$errors=$null;[Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors)|Out-Null
    return @($errors).Count -eq 0
}

$requiredFields = @(Get-Pr90Attempt22RequiredFieldsV4)
Add-PreformalCheck 1 'AUTHORIZATION_SCHEMA_LOADABLE' ($requiredFields.Count -gt @(Get-Pr90Attempt19RequiredFieldsV3).Count) "required_fields=$($requiredFields.Count)"
$productHead = (& git -C ([string]$config.product_worktree) rev-parse HEAD).Trim()
$productTree = (& git -C ([string]$config.product_worktree) rev-parse 'HEAD^{tree}').Trim()
Add-PreformalCheck 2 'PRODUCT_HEAD_BOUND' ($productHead -ceq [string]$config.product_head_sha) $productHead
Add-PreformalCheck 3 'PRODUCT_TREE_BOUND' ($productTree -ceq [string]$config.product_tree_sha) $productTree
$toolingHead = (& git -C ([string]$config.tooling_worktree) rev-parse HEAD).Trim()
$toolingTree = (& git -C ([string]$config.tooling_worktree) rev-parse 'HEAD^{tree}').Trim()
Add-PreformalCheck 4 'TOOLING_HEAD_BOUND' ($toolingHead -ceq [string]$config.tooling_head_sha) $toolingHead
Add-PreformalCheck 5 'TOOLING_TREE_BOUND' ($toolingTree -ceq [string]$config.tooling_tree_sha) $toolingTree
$toolSealGreen = Test-HashBinding $config.tooling_seal_path $config.tooling_seal_sha256
if($toolSealGreen){$seal=Get-Content -Raw -LiteralPath $config.tooling_seal_path|ConvertFrom-Json -Depth 100;$toolSealGreen=[string]$seal.status-ceq'SEALED'-and[string]$seal.tooling_head_sha-ceq$toolingHead}
Add-PreformalCheck 6 'TOOLING_SEAL_BOUND' $toolSealGreen ([string]$config.tooling_seal_sha256)
$toolManifestGreen=Test-HashBinding $config.tooling_manifest_path $config.tooling_manifest_sha256
if($toolManifestGreen){$tm=Get-Content -Raw -LiteralPath $config.tooling_manifest_path|ConvertFrom-Json -Depth 100;$toolManifestGreen=[string]$tm.status-ceq'READY'-and[bool]$tm.startup_probe_b_authorization_eligible-and[int]$tm.tooling_file_hash_mismatch_count-eq0}
Add-PreformalCheck 7 'TOOLING_FILE_HASH_INVENTORY_BOUND' $toolManifestGreen ([string]$config.tooling_manifest_sha256)
$remote=@(& git -C ([string]$config.tooling_worktree) ls-remote --heads ([string]$config.tooling_repository) "refs/heads/$([string]$config.tooling_remote_branch)")
$remoteGreen=$LASTEXITCODE-eq0-and$remote.Count-eq1-and([string]$remote[0]).Split("`t")[0]-ceq$toolingHead
Add-PreformalCheck 8 'REMOTE_TOOLING_BRANCH_BOUND' $remoteGreen ([string]$config.tooling_remote_branch)
$gateGreen=Test-HashBinding $config.formal_gate_1_79_receipt_path $config.formal_gate_1_79_receipt_sha256
if($gateGreen){$g=Get-Content -Raw -LiteralPath $config.formal_gate_1_79_receipt_path|ConvertFrom-Json -Depth 100;$gateGreen=[string]$g.status-ceq'PASS'-and[int]$g.pass_count-eq79-and[int]$g.fail_count-eq0}
Add-PreformalCheck 9 'FORMAL_GATE_1_79_RECEIPT_BOUND' $gateGreen ([string]$config.formal_gate_1_79_receipt_sha256)
$baselineGreen=Test-HashBinding $config.sealed_baseline_path $config.sealed_baseline_sha256
if($baselineGreen){$b=Get-Content -Raw -LiteralPath $config.sealed_baseline_path|ConvertFrom-Json -Depth 100;$baselineGreen=[bool]$b.post_import_baseline_sealed-and[string]$b.head_sha-ceq$productHead-and[string]$b.tree_sha-ceq$productTree}
Add-PreformalCheck 10 'SEALED_POST_IMPORT_BASELINE_BOUND' $baselineGreen ([string]$config.sealed_baseline_sha256)
Add-PreformalCheck 11 'CLASS_CACHE_BOUND' (Test-HashBinding $config.class_cache_path $config.class_cache_sha256) ([string]$config.class_cache_sha256)
Add-PreformalCheck 12 'IMPORT_PASS1_MANIFEST_BOUND' (Test-HashBinding $config.import_pass1_manifest_path $config.import_pass1_manifest_sha256) ([string]$config.import_pass1_manifest_sha256)
Add-PreformalCheck 13 'IMPORT_PASS2_MANIFEST_BOUND' (Test-HashBinding $config.import_pass2_manifest_path $config.import_pass2_manifest_sha256) ([string]$config.import_pass2_manifest_sha256)
$p004=Test-HashBinding $config.probe004_result_path $config.probe004_result_sha256
if($p004){$v=Get-Content -Raw -LiteralPath $config.probe004_result_path|ConvertFrom-Json -Depth 100;$p004=[string]$v.status-ceq'PASS'}
Add-PreformalCheck 14 'PROBE004_RESULT_BOUND' $p004 ([string]$config.probe004_result_sha256)
$p004a=Test-HashBinding $config.probe004_attestation_path $config.probe004_attestation_sha256
if($p004a){$v=Get-Content -Raw -LiteralPath $config.probe004_attestation_path|ConvertFrom-Json -Depth 100;$p004a=[string]$v.status-ceq'SEALED'}
Add-PreformalCheck 15 'PROBE004_ATTESTATION_BOUND' $p004a ([string]$config.probe004_attestation_sha256)
$pb=Test-HashBinding $config.probe_b_result_path $config.probe_b_result_sha256
if($pb){$v=Get-Content -Raw -LiteralPath $config.probe_b_result_path|ConvertFrom-Json -Depth 100;$pb=[string]$v.schema-ceq'Pr90ExactCloneProbeBV2ResultV1'-and[string]$v.probe_id-ceq'pr90-exact-clone-startup-probe-b-v2-001'-and[string]$v.status-ceq'PASS'-and[int]$v.milestone_pass_count-eq12-and[string]$v.import_finalizer_status-ceq'PASS'-and
    [string]$v.product_head_sha-ceq[string]$config.product_head_sha-and[string]$v.product_tree_sha-ceq[string]$config.product_tree_sha-and[string]$v.tooling_head_sha-ceq$toolingHead-and[string]$v.tooling_tree_sha-ceq$toolingTree-and
    [string]$v.tooling_seal_sha256-ceq[string]$config.tooling_seal_sha256-and[string]$v.godot_gui_sha256-ceq[string]$config.godot_gui_sha256-and[string]$v.godot_console_sha256-ceq[string]$config.godot_console_sha256-and
    [bool]$v.bracketed_sample_model-and[int]$v.total_listener_cohort_attempt_count-ge5-and[int]$v.consecutive_stable_parity_cohort_count-ge5-and[double]$v.stable_parity_window_ms-ge1000-and[bool]$v.endpoint_listener_core_parity-and[int]$v.matched_listener_process_enrichment_count-eq1-and[int]$v.duplicate_source_process_enrichment_count-eq0-and
    (Test-HashBinding $config.godot_gui_path $config.godot_gui_sha256)-and(Test-HashBinding $config.godot_console_path $config.godot_console_sha256)}
Add-PreformalCheck 16 'PROBE_B_RESULT_BOUND' $pb ([string]$config.probe_b_result_sha256)
$pba=Test-HashBinding $config.probe_b_attestation_path $config.probe_b_attestation_sha256
if($pba){$v=Get-Content -Raw -LiteralPath $config.probe_b_attestation_path|ConvertFrom-Json -Depth 100;$pba=[string]$v.schema-ceq'Pr90ExactCloneProbeBV2AttestationV1'-and[string]$v.status-ceq'SEALED'-and[int]$v.unbound_evidence_count-eq0-and[bool]$v.bracketed_sample_model-and[int]$v.matched_listener_process_enrichment_count-eq1}
Add-PreformalCheck 17 'PROBE_B_ATTESTATION_BOUND' $pba ([string]$config.probe_b_attestation_sha256)
$endpointGreen=([int]$config.endpoint_ownership_contract_version-eq2)-and([int]$config.listener_parity_contract_version-eq2)-and(Test-HashBinding $config.endpoint_ownership_validator_path $config.endpoint_ownership_validator_sha256)-and(Test-HashBinding $config.listener_core_normalizer_path $config.listener_core_normalizer_sha256)-and(Test-HashBinding $config.bracketed_cohort_controller_path $config.bracketed_cohort_controller_sha256)-and(Test-HashBinding $config.listener_forensics_path $config.listener_forensics_sha256)
Add-PreformalCheck 18 'ENDPOINT_OWNERSHIP_CONTRACT_V2_BOUND' $endpointGreen ([string]$config.endpoint_ownership_validator_sha256)
$cursorGreen=(Test-HashBinding $config.cursor_runbook_path $config.cursor_runbook_sha256)-and(Test-PowerShellLoad $config.cursor_runbook_path)
Add-PreformalCheck 19 'CURSOR_AWARE_RUNBOOK_LOADABLE_AND_BOUND' $cursorGreen ([string]$config.cursor_runbook_sha256)
$importGreen=(Test-HashBinding $config.import_controller_path $config.import_controller_sha256)-and(Test-HashBinding $config.import_finalizer_path $config.import_finalizer_sha256)-and(Test-PowerShellLoad $config.import_controller_path)-and(Test-PowerShellLoad $config.import_finalizer_path)
Add-PreformalCheck 20 'IMPORT_CONTROLLER_FINALIZER_LOADABLE_AND_BOUND' $importGreen 'controller+finalizer'
$runbookText=[IO.File]::ReadAllText([IO.Path]::GetFullPath([string]$config.cursor_runbook_path))
$requiredRunbookTokens=@('Invoke-Pr90McpStartupStateMachine','KeepRunningAfterM11','exit_play_mode','play_main_scene','phase-1-main-scene','phase-2-new-game','phase-3-early-match','phase-4-mid-match','phase-5-combat-facility','phase-6-victory','phase-7-settlement','phase-7-final-settlement','natural UI match did not settle','Stop-Pr90McpStartupWatchdog')
$missingRunbookTokens=@($requiredRunbookTokens|Where-Object{-not$runbookText.Contains($_,[StringComparison]::Ordinal)})
$commandParameters=@(
    [pscustomobject]@{name='ExecutionMode';value='FORMAL_EXACT_SHA_MCP';binding_source='sealed_plan'},
    [pscustomobject]@{name='RunId';value=[string]$config.authorized_run_id;binding_source='attempt22_authorization'},
    [pscustomobject]@{name='Worktree';value=[IO.Path]::GetFullPath([string]$config.formal_product_worktree);binding_source='future_exact_clone'},
    [pscustomobject]@{name='EvidenceRoot';value=[IO.Path]::GetFullPath([string]$config.formal_evidence_root);binding_source='authorized_run_id'},
    [pscustomobject]@{name='GodotPath';value=[IO.Path]::GetFullPath([string]$config.godot_console_path);sha256=[string]$config.godot_console_sha256;binding_source='probe_b_attestation'},
    [pscustomobject]@{name='ExpectedHeadSha';value=[string]$config.product_head_sha;binding_source='pr90_exact_head'},
    [pscustomobject]@{name='ExpectedTreeSha';value=[string]$config.product_tree_sha;binding_source='pr90_exact_tree'},
    [pscustomobject]@{name='LaunchScriptPath';value=[IO.Path]::GetFullPath([string]$config.launch_script_path);sha256=[string]$config.launch_script_sha256;binding_source='tooling_manifest'},
    [pscustomobject]@{name='ExpectedLaunchScriptSha256';value=[string]$config.launch_script_sha256;binding_source='tooling_manifest'},
    [pscustomobject]@{name='StopScriptPath';value=[IO.Path]::GetFullPath([string]$config.stop_script_path);sha256=[string]$config.stop_script_sha256;binding_source='tooling_manifest'},
    [pscustomobject]@{name='ExpectedStopScriptSha256';value=[string]$config.stop_script_sha256;binding_source='tooling_manifest'},
    [pscustomobject]@{name='WatchdogScriptPath';value=[IO.Path]::GetFullPath([string]$config.startup_watchdog_path);sha256=[string]$config.startup_watchdog_sha256;binding_source='tooling_manifest'},
    [pscustomobject]@{name='ExpectedWatchdogScriptSha256';value=[string]$config.startup_watchdog_sha256;binding_source='tooling_manifest'},
    [pscustomobject]@{name='StateMachineScriptPath';value=[IO.Path]::GetFullPath([string]$config.startup_state_machine_path);sha256=[string]$config.startup_state_machine_sha256;binding_source='tooling_manifest'},
    [pscustomobject]@{name='ExpectedStateMachineSha256';value=[string]$config.startup_state_machine_sha256;binding_source='tooling_manifest'},
    [pscustomobject]@{name='ContractScriptPath';value=[IO.Path]::GetFullPath([string]$config.startup_contract_path);sha256=[string]$config.startup_contract_sha256;binding_source='tooling_manifest'},
    [pscustomobject]@{name='ExpectedContractSha256';value=[string]$config.startup_contract_sha256;binding_source='tooling_manifest'},
    [pscustomobject]@{name='SealedBaselinePath';value=[IO.Path]::GetFullPath([string]$config.sealed_baseline_path);sha256=[string]$config.sealed_baseline_sha256;binding_source='probe_b_attestation'},
    [pscustomobject]@{name='ExpectedSealedBaselineSha256';value=[string]$config.sealed_baseline_sha256;binding_source='probe_b_attestation'},
    [pscustomobject]@{name='StartupToolingManifestPath';value=[IO.Path]::GetFullPath([string]$config.tooling_manifest_path);sha256=[string]$config.tooling_manifest_sha256;binding_source='tooling_seal'},
    [pscustomobject]@{name='ExpectedStartupToolingManifestSha256';value=[string]$config.tooling_manifest_sha256;binding_source='tooling_seal'},
    [pscustomobject]@{name='StartupToolingSealPath';value=[IO.Path]::GetFullPath([string]$config.tooling_seal_path);sha256=[string]$config.tooling_seal_sha256;binding_source='tooling_seal'},
    [pscustomobject]@{name='ExpectedStartupToolingSealSha256';value=[string]$config.tooling_seal_sha256;binding_source='tooling_seal'},
    [pscustomobject]@{name='FormalAuthorizationValidationReceiptPath';value=[IO.Path]::GetFullPath([string]$config.future_authorization_validation_receipt_path);binding_source='attempt22_seal_after_preformal'},
    [pscustomobject]@{name='ExpectedFormalAuthorizationValidationReceiptSha256';value_source='attempt22_seal.validation_receipt_sha256';binding_source='single_explicit_deferred_binding'},
    [pscustomobject]@{name='AllowFormalContinuation';value=$true;binding_source='future_user_authorization'},
    [pscustomobject]@{name='Port';value=7576;binding_source='endpoint_contract_v2'}
)
$phasePlan=@('M0-M11 startup and phase-0-ready','exit custom probe play mode','play_main_scene exact res://scenes/main.tscn','phase-1-main-scene cursor witness','phase-2-new-game cursor witness','phase-3-early-match cursor witness','phase-4-mid-match cursor witness','phase-5-combat-facility cursor witness','phase-6-victory cursor witness','phase-7-settlement cursor witness','phase-7-final-settlement and exact result')
$evidencePlan=@('authorization-validation','12 milestone receipts and sidecars','endpoint ownership V2 samples and attestation','raw JSON-RPC inventory','runtime bridge heartbeat/bootstrap','ready witness','phase-0 through phase-7 cursor witnesses','exact-sha-mcp result or failure','terminal process and port manifest','formal import finalizer result')
$accountingPlan=@('authorized_run_count=1','automatic_retry_allowed=false','formal_mcp_execution_count=0 before authorized boundary','authorized_run_count_consumed=0 before authorized boundary','same run id evidence root must not exist','no automatic retry after any failure')
$finalizerPlan=[pscustomobject][ordered]@{controller=[IO.Path]::GetFullPath([string]$config.import_finalizer_path);controller_sha256=[string]$config.import_finalizer_sha256;mode='FinalizeSnapshot';baseline_sha256=[string]$config.sealed_baseline_sha256;class_cache_sha256=[string]$config.class_cache_sha256;normal_stop_required=$true;terminal_zero_required=$true}
$plan=[pscustomobject][ordered]@{executable=Join-Path $PSHOME 'pwsh.exe';script=[IO.Path]::GetFullPath([string]$config.cursor_runbook_path);script_sha256=[string]$config.cursor_runbook_sha256;command_parameters=$commandParameters;phase_plan=$phasePlan;evidence_plan=$evidencePlan;accounting_plan=$accountingPlan;finalizer_plan=$finalizerPlan;deferred_binding_count=1;deferred_binding='ExpectedFormalAuthorizationValidationReceiptSha256 from the post-preformal Attempt22 seal';formal_evidence_root=[IO.Path]::GetFullPath([string]$config.formal_evidence_root)}
$runbookCommand=Get-Command -Name ([string]$config.cursor_runbook_path)
$boundScriptParameters=@($runbookCommand.Parameters.Keys)
$missingCommandParameters=@($commandParameters.name|Where-Object{$boundScriptParameters-cnotcontains$_})
$mandatoryScriptParameters=@($runbookCommand.Parameters.GetEnumerator()|Where-Object{@($_.Value.Attributes|Where-Object{$_-is[Management.Automation.ParameterAttribute]-and$_.Mandatory}).Count-gt0}|ForEach-Object{$_.Key})
$missingMandatoryParameters=@($mandatoryScriptParameters|Where-Object{$commandParameters.name-cnotcontains$_})
$duplicateCommandParameterCount=$commandParameters.Count-@($commandParameters.name|Select-Object -Unique).Count
$pairedParameters=@(
    @('LaunchScriptPath','ExpectedLaunchScriptSha256'),@('StopScriptPath','ExpectedStopScriptSha256'),@('WatchdogScriptPath','ExpectedWatchdogScriptSha256'),
    @('StateMachineScriptPath','ExpectedStateMachineSha256'),@('ContractScriptPath','ExpectedContractSha256'),@('SealedBaselinePath','ExpectedSealedBaselineSha256'),
    @('StartupToolingManifestPath','ExpectedStartupToolingManifestSha256'),@('StartupToolingSealPath','ExpectedStartupToolingSealSha256')
)
$pairedParameterFailureCount=0
foreach($pair in $pairedParameters){
    $pathRow=@($commandParameters|Where-Object{$_.name-ceq$pair[0]});$hashRow=@($commandParameters|Where-Object{$_.name-ceq$pair[1]})
    if($pathRow.Count-ne1-or$hashRow.Count-ne1-or-not(Test-HashBinding ([string]$pathRow[0].value) ([string]$hashRow[0].value))){$pairedParameterFailureCount+=1}
}
$hashParametersGreen=@($commandParameters|Where-Object{$_.PSObject.Properties.Name-ccontains'sha256'}|Where-Object{-not(Test-HashBinding $_.value $_.sha256)}).Count-eq0
$planGreen=$missingRunbookTokens.Count-eq0-and$missingCommandParameters.Count-eq0-and$missingMandatoryParameters.Count-eq0-and$duplicateCommandParameterCount-eq0-and$pairedParameterFailureCount-eq0-and$hashParametersGreen-and$commandParameters.Count-eq27-and$phasePlan.Count-eq11-and$evidencePlan.Count-eq10-and$accountingPlan.Count-eq6-and[string]$finalizerPlan.mode-ceq'FinalizeSnapshot'
Add-PreformalCheck 21 'FORMAL_COMMAND_PHASE_EVIDENCE_ACCOUNTING_PLAN_CONSTRUCTED' $planGreen "missing_runbook_tokens=$($missingRunbookTokens.Count);missing_parameters=$($missingCommandParameters.Count);missing_mandatory=$($missingMandatoryParameters.Count);duplicate_parameters=$duplicateCommandParameterCount;paired_hash_failures=$pairedParameterFailureCount;hash_bindings_green=$hashParametersGreen"
$processesAfter=@(Get-Pr90ProductProcessRowsV1);$mcpProcessesAfter=@(Get-Pr90McpSupportProcessRowsV1);$listenersAfter=@(Get-Pr90ProtectedListenerRowsV1)
$boundaryGreen=$processesBefore.Count-eq0-and$mcpProcessesBefore.Count-eq0-and$listenersBefore.Count-eq0-and$processesAfter.Count-eq0-and$mcpProcessesAfter.Count-eq0-and$listenersAfter.Count-eq0-and-not(Test-Path -LiteralPath ([string]$config.formal_evidence_root))
Add-PreformalCheck 22 'FORMAL_START_BOUNDARY_REACHED_WITHOUT_PROCESS' $boundaryGreen ([string]$config.formal_evidence_root)
$passCount=@($checks|Where-Object{$_.pass}).Count
$result=[pscustomobject][ordered]@{
    schema='Pr90Attempt22PreformalDryRunV2';run_id='pr90-attempt22-preformal-dry-run-v2-002';status=if($passCount-eq22-and$processesAfter.Count-eq0-and$mcpProcessesAfter.Count-eq0-and$listenersAfter.Count-eq0){'PASS'}else{'BLOCKED'};created_at_utc=[DateTimeOffset]::UtcNow.ToString('o')
    product_head_sha=[string]$config.product_head_sha;product_tree_sha=[string]$config.product_tree_sha;tooling_head_sha=[string]$config.tooling_head_sha;tooling_tree_sha=[string]$config.tooling_tree_sha;tooling_seal_sha256=[string]$config.tooling_seal_sha256
    check_count=22;pass_count=$passCount;fail_count=22-$passCount;checks=@($checks);formal_plan=$plan;product_process_count_before=$processesBefore.Count;product_process_count_after=$processesAfter.Count;mcp_product_process_count_before=$mcpProcessesBefore.Count;mcp_product_process_count=$mcpProcessesAfter.Count
    protected_listener_count_before=$listenersBefore.Count;protected_listener_count_after=$listenersAfter.Count;play_main_scene_count=0;product_match_count=0;formal_authorization_consumed=$false;reaches_formal_start_boundary=[bool]$boundaryGreen;formal_mcp_execution_count=0;canonical_payload_sha256=''
}
$result.canonical_payload_sha256=Get-Pr90ProbeBCanonicalSha256 $result
Write-Pr90ProbeBImmutableJson -Path $OutputPath -Value $result -WriteSha256Sidecar | Out-Null
$result|ConvertTo-Json -Depth 100 -Compress
if([string]$result.status-cne'PASS'){exit 2}
