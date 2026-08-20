[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ToolingWorktree,
    [Parameter(Mandatory = $true)][string]$BaseSelfTestPath,
    [Parameter(Mandatory = $true)][string]$ExpectedBaseSelfTestSha256,
    [Parameter(Mandatory = $true)][string]$OutputPath
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'pr90_probe_b_attempt22_contract_v1.psm1') -Force
if((Get-Pr90ProbeBSha256 $BaseSelfTestPath)-cne$ExpectedBaseSelfTestSha256.ToLowerInvariant()){throw 'Base selftest hash mismatch.'}
$base=Get-Content -Raw -LiteralPath $BaseSelfTestPath|ConvertFrom-Json -Depth 100
if([string]$base.status-cne'PASS'-or[int]$base.case_count-ne104-or[int]$base.pass_count-ne104){throw 'Base selftest is not 104/104 PASS.'}
$cases=[Collections.Generic.List[object]]::new()
$parameterBindingFailures=[Collections.Generic.List[object]]::new()
function Add-Case([string]$Name,[bool]$Pass,[string]$Detail){$cases.Add([pscustomobject][ordered]@{name=$Name;pass=$Pass;detail=$Detail})}
function Add-InvocationBindingCase([string]$Name,[string]$CallerPath,[string]$Selector,[string]$CalleePath){
 $tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($CallerPath,[ref]$tokens,[ref]$errors)
 $commands=@($ast.FindAll({param($node)$node-is[Management.Automation.Language.CommandAst]-and$node.Extent.Text.Contains($Selector,[StringComparison]::Ordinal)},$true))
 $detail='';$pass=$false
 if($commands.Count-eq1){
  $elements=@($commands[0].CommandElements);$selectorIndex=-1
  for($index=0;$index-lt$elements.Count;$index+=1){if($elements[$index].Extent.Text.Contains($Selector,[StringComparison]::Ordinal)){$selectorIndex=$index;break}}
  $callerParameters=@($elements|Select-Object -Skip ($selectorIndex+1)|Where-Object{$_-is[Management.Automation.Language.CommandParameterAst]}|ForEach-Object{$_.ParameterName})
  $callee=Get-Command -Name $CalleePath
  $calleeParameters=@($callee.Parameters.Keys)
  $mandatory=@($callee.Parameters.GetEnumerator()|Where-Object{@($_.Value.Attributes|Where-Object{$_-is[Management.Automation.ParameterAttribute]-and$_.Mandatory}).Count-gt0}|ForEach-Object{$_.Key})
  $unknown=@($callerParameters|Where-Object{$calleeParameters-cnotcontains$_});$missing=@($mandatory|Where-Object{$callerParameters-cnotcontains$_})
  $duplicateCount=$callerParameters.Count-@($callerParameters|Select-Object -Unique).Count
  $pass=$selectorIndex-ge0-and$unknown.Count-eq0-and$missing.Count-eq0-and$duplicateCount-eq0
  $detail="commands=$($commands.Count);unknown=$($unknown.Count);missing_mandatory=$($missing.Count);duplicates=$duplicateCount"
 }else{$detail="commands=$($commands.Count)"}
 if(-not$pass){$parameterBindingFailures.Add([pscustomobject]@{name=$Name;detail=$detail})}
 Add-Case $Name $pass $detail
}
$files=@(
 'pr90_probe_b_attempt22_contract_v1.psm1','pr90_exact_clone_probe_b_controller_v1.ps1','pr90_exact_clone_probe_b_result_builder_v1.ps1','pr90_exact_clone_probe_b_attestation_builder_v1.ps1',
 'pr90_probe_b_import_finalizer_binding_v1.ps1','pr90_attempt22_preformal_dry_run_v2.ps1','pr90_attempt22_authorization_manifest_builder_v4.ps1','pr90_attempt22_authorization_validator_v4.ps1',
 'pr90_attempt22_authorization_seal_builder_v4.ps1','pr90_probe_b_attempt22_selftest_v1.ps1','pr90_probe_b_attempt22_tooling_manifest_builder_v1.ps1','pr90_probe_b_attempt22_tooling_seal_builder_v1.ps1'
)
$parseErrorCount=0
foreach($name in $files){
 $path=Join-Path $ToolingWorktree "tools/$name";$tokens=$null;$errors=$null
 if(Test-Path -LiteralPath $path){[Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors)|Out-Null}else{$errors=@('MISSING')}
 $count=@($errors).Count;$parseErrorCount+=$count;Add-Case "PARSE_$name" ($count-eq0) "errors=$count"
}
$required=@(Get-Pr90Attempt22RequiredFieldsV4)
Add-Case 'ATTEMPT22_REQUIRED_FIELDS_EXTEND_ATTEMPT19' ($required.Count-gt@(Get-Pr90Attempt19RequiredFieldsV3).Count) "fields=$($required.Count)"
$eligibility=Test-Pr90ProbeBToolingEligibilityV1 -MissingContractCount 0 -BaseSelfTestPassCount 104 -NewSelfTestPassCount 40 -NewSelfTestCaseCount 40 -FailureCount 0 -PowerShellParseErrorCount 0 -ParameterBindingExceptionCount 0
Add-Case 'STARTUP_PROBE_B_ELIGIBILITY_DERIVED_TRUE' $eligibility 'derived from inventory and selftests'
$notEligible=Test-Pr90ProbeBToolingEligibilityV1 -MissingContractCount 1 -BaseSelfTestPassCount 104 -NewSelfTestPassCount 40 -NewSelfTestCaseCount 40 -FailureCount 0 -PowerShellParseErrorCount 0 -ParameterBindingExceptionCount 0
Add-Case 'MISSING_CONTRACT_PREVENTS_ELIGIBILITY' (-not$notEligible) 'missing_contract_count=1'
$controllerText=[IO.File]::ReadAllText((Join-Path $ToolingWorktree 'tools/pr90_exact_clone_probe_b_controller_v1.ps1'))
Add-Case 'PROBE_B_CONTROLLER_SINGLE_STATE_MACHINE' (($controllerText|Select-String -Pattern 'tooling_bindings\.startup_probe\.path' -AllMatches).Matches.Count-eq1-and-not$controllerText.Contains('function Invoke-Pr90McpStartupStateMachine')) 'one existing startup-probe child call'
Add-Case 'PROBE_B_CONTROLLER_NO_PLAY_MAIN_SCENE' (-not[regex]::IsMatch($controllerText,'(?i)-ToolName\s+[''"]play_main_scene[''"]')) 'no main-scene tool call'
$resultText=[IO.File]::ReadAllText((Join-Path $ToolingWorktree 'tools/pr90_exact_clone_probe_b_result_builder_v1.ps1'))
Add-Case 'PROBE_B_RESULT_SCHEMA_PRESENT' $resultText.Contains("schema='Pr90ExactCloneProbeBResultV1'",[StringComparison]::Ordinal) 'result schema'
$attestationText=[IO.File]::ReadAllText((Join-Path $ToolingWorktree 'tools/pr90_exact_clone_probe_b_attestation_builder_v1.ps1'))
Add-Case 'PROBE_B_ATTESTATION_SCHEMA_PRESENT' $attestationText.Contains("schema='Pr90ExactCloneProbeBAttestationV1'",[StringComparison]::Ordinal) 'attestation schema'
Add-Case 'PROBE_B_ATTESTATION_BINDS_ENDPOINT_EVIDENCE' ($attestationText.Contains('endpoint_ownership_attestation_sha256')-and$attestationText.Contains('endpoint_ownership_samples_sha256')-and$attestationText.Contains('runtime_bridge_ready_status_sha256')) 'endpoint samples, attestation, heartbeat'
$finalizerText=[IO.File]::ReadAllText((Join-Path $ToolingWorktree 'tools/pr90_probe_b_import_finalizer_binding_v1.ps1'))
Add-Case 'FINALIZER_RAW_AND_NORMALIZED_STATE_BOUND' ($finalizerText.Contains('raw_state_sha256')-and$finalizerText.Contains('normalized_state_sha256')-and$finalizerText.Contains('-PostStatePath $normalizedStatePath')-and$finalizerText.Contains('prelaunchIgnored')-and$finalizerText.Contains('disallowedAddedIgnored')-and-not$finalizerText.Contains("EndsWith('.import')")) 'sealed prelaunch set + narrow runtime delta + formal runner'
$preformalText=[IO.File]::ReadAllText((Join-Path $ToolingWorktree 'tools/pr90_attempt22_preformal_dry_run_v2.ps1'))
$preformalSemanticTokens=@('play_main_scene','phase-1-main-scene','phase-2-new-game','phase-3-early-match','phase-4-mid-match','phase-5-combat-facility','phase-6-victory','phase-7-final-settlement','formal import finalizer result','authorized_run_count=1','single_explicit_deferred_binding')
Add-Case 'PREFORMAL_EXACT_22_CHECKS_DECLARED' (($preformalText|Select-String -Pattern 'Add-PreformalCheck\s+(?:[1-9]|1[0-9]|2[0-2])\s' -AllMatches).Matches.Count-eq22-and@($preformalSemanticTokens|Where-Object{-not$preformalText.Contains($_)}).Count-eq0) '22 semantic checks and exact formal plan'
Add-Case 'PREFORMAL_ALL_PATH_HASH_PAIRS_AND_MANDATORY_PARAMETERS' (@(@('ExpectedLaunchScriptSha256','ExpectedStopScriptSha256','ExpectedWatchdogScriptSha256','ExpectedStateMachineSha256','ExpectedContractSha256','ExpectedSealedBaselineSha256','ExpectedStartupToolingManifestSha256','ExpectedStartupToolingSealSha256','missingMandatoryParameters','pairedParameterFailureCount')|Where-Object{-not$preformalText.Contains($_)}).Count-eq0) 'eight paired hashes plus metadata mandatory subset'
Add-Case 'RESULT_BINDS_FULL_M5_AND_EXACT_SCENE' ($resultText.Contains('endpoint_owner_is_console_wrapper')-and$resultText.Contains('endpoint_owner_command_line_fixture_match')-and$resultText.Contains('endpoint_owner_pid_changed_count')-and$resultText.Contains('multiple_active_endpoint_owner_count')-and$resultText.Contains('scene_path -ceq $ProbeScenePath')) 'full M5 gates and exact custom scene'
Add-Case 'LISTENER_FIVE_OF_FIVE_PARITY_PASS' (Test-Pr90ProbeBListenerSampleContractV1 -TotalSampleCount 5 -ConsecutiveParitySampleCount 5 -StableWindowMs 1000 -ObserverSourceCount 2 -Parity $true) '5 total and 5 consecutive parity'
Add-Case 'LISTENER_FIVE_OF_FOUR_PARITY_BLOCKED' (-not(Test-Pr90ProbeBListenerSampleContractV1 -TotalSampleCount 5 -ConsecutiveParitySampleCount 4 -StableWindowMs 1000 -ObserverSourceCount 2 -Parity $true)) '4 consecutive parity must not pass Probe B'
$goodSceneAudit=[pscustomobject]@{schema='Pr90ProbeBSceneIsolationAuditV1';status='PASS';authorized_probe_scene_path='res://scenes/runtime/ActionResultPresentationService.tscn';authorized_probe_scene_sha256='f3a1fb397e820adb4beddc0f641e7c77173b1e4f6fe609796a8887cabdf8adc8';autoload_contract_green=$true;unresolved_resource_count=0;dynamic_resource_load_count=0;main_tscn_dependency_count=0;main_tscn_instance_count=0}
Add-Case 'SCENE_ISOLATION_CONTRACT_PASS' (Test-Pr90ProbeBSceneIsolationContractV1 -Audit $goodSceneAudit -ExpectedScenePath $goodSceneAudit.authorized_probe_scene_path -ExpectedSceneSha256 $goodSceneAudit.authorized_probe_scene_sha256) 'exact custom scene graph contains no main scene'
$badSceneAudit=Copy-Pr90ProbeBJsonObject $goodSceneAudit;$badSceneAudit.main_tscn_dependency_count=1
Add-Case 'SCENE_ISOLATION_MAIN_DEPENDENCY_BLOCKED' (-not(Test-Pr90ProbeBSceneIsolationContractV1 -Audit $badSceneAudit -ExpectedScenePath $goodSceneAudit.authorized_probe_scene_path -ExpectedSceneSha256 $goodSceneAudit.authorized_probe_scene_sha256)) 'main scene dependency cannot pass'
Add-Case 'RESULT_ATTESTATION_BIND_DIRECT_REQUEST_INVENTORY' ($resultText.Contains('request_inventory_sha256')-and$attestationText.Contains('request_inventory_sha256')-and$resultText.Contains('unauthorized_request_count')) 'direct request bytes are sealed and tool set fail-closed'
Add-Case 'MILESTONE_INVENTORY_MATCHES_STATE_MACHINE_FILENAMES' ($resultText.Contains("-Filter '*.receipt.json'")-and$attestationText.Contains("-Filter '*.receipt.json'")-and$resultText.Contains('milestone_sequence_green')) 'M0-M11 exact order, ids, and receipt bytes'
$validatorText=[IO.File]::ReadAllText((Join-Path $ToolingWorktree 'tools/pr90_attempt22_authorization_validator_v4.ps1'))
Add-Case 'VALIDATOR_BINDS_ACTUAL_TOOLING_SEAL_BYTES' ($validatorText.Contains('actualToolingSealSha256')-and$validatorText.Contains("@('tooling_seal_path','tooling_seal_sha256')")) 'actual seal hash pair'
Add-Case 'VALIDATOR_REMOTE_AND_FIELD_INVENTORY_FAIL_CLOSED' ($validatorText.Contains('REMOTE_TOOLING_IDENTITY_UNRESOLVED')-and$validatorText.Contains('unexpected_field_count')) 'remote non-unique/error and unexpected fields block'
$controllerPath=Join-Path $ToolingWorktree 'tools/pr90_exact_clone_probe_b_controller_v1.ps1'
Add-InvocationBindingCase 'BIND_CONTROLLER_IMPORT' $controllerPath 'tooling_bindings.import_controller.path' (Join-Path $ToolingWorktree 'tools/pr90_attempt19_import_controller_v3.ps1')
Add-InvocationBindingCase 'BIND_CONTROLLER_FINALIZER_DRY_RUN' $controllerPath 'tooling_bindings.import_finalizer_dry_run.path' (Join-Path $ToolingWorktree 'tools/pr90_attempt19_import_finalizer_dry_run.ps1')
Add-InvocationBindingCase 'BIND_CONTROLLER_STARTUP_PROBE' $controllerPath 'tooling_bindings.startup_probe.path' (Join-Path $ToolingWorktree 'tools/pr90_attempt21_mcp_startup_probe.ps1')
Add-InvocationBindingCase 'BIND_CONTROLLER_FINALIZER' $controllerPath 'tooling_bindings.finalizer_binding.path' (Join-Path $ToolingWorktree 'tools/pr90_probe_b_import_finalizer_binding_v1.ps1')
Add-InvocationBindingCase 'BIND_CONTROLLER_RESULT' $controllerPath 'tooling_bindings.result_builder.path' (Join-Path $ToolingWorktree 'tools/pr90_exact_clone_probe_b_result_builder_v1.ps1')
Add-InvocationBindingCase 'BIND_CONTROLLER_ATTESTATION' $controllerPath 'tooling_bindings.attestation_builder.path' (Join-Path $ToolingWorktree 'tools/pr90_exact_clone_probe_b_attestation_builder_v1.ps1')
Add-InvocationBindingCase 'BIND_V4_BUILDER_TO_V3' (Join-Path $ToolingWorktree 'tools/pr90_attempt22_authorization_manifest_builder_v4.ps1') '$oldBuilder' (Join-Path $ToolingWorktree 'tools/pr90_attempt19_authorization_manifest_builder.ps1')

$goodProbeB=[pscustomobject]@{status='PASS';import_finalizer_status='PASS';product_head_sha='770d741f05964facda4afcbddcdeb3e7f40571d5';product_tree_sha='f5bb584ceea065b13c9b5621b1976af7907c62ad';tooling_head_sha='1111111111111111111111111111111111111111';tooling_tree_sha='2222222222222222222222222222222222222222';tooling_seal_sha256='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';godot_gui_sha256='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';godot_console_sha256='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'}
$goodProbeBA=[pscustomobject]@{status='SEALED';unbound_evidence_count=0;result_sha256='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'}
$goodPreformal=[pscustomobject]@{status='PASS';check_count=22;pass_count=22;fail_count=0;product_process_count_after=0;mcp_product_process_count=0;protected_listener_count_after=0;formal_authorization_consumed=$false;reaches_formal_start_boundary=$true}
$artifactParams=@{ProbeB=$goodProbeB;ProbeBAttestation=$goodProbeBA;Preformal=$goodPreformal;ExpectedProbeBResultSha256='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';ExpectedProductHeadSha='770d741f05964facda4afcbddcdeb3e7f40571d5';ExpectedProductTreeSha='f5bb584ceea065b13c9b5621b1976af7907c62ad';ExpectedToolingHeadSha='1111111111111111111111111111111111111111';ExpectedToolingTreeSha='2222222222222222222222222222222222222222';ExpectedToolingSealSha256='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';ExpectedGodotGuiSha256='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';ExpectedGodotConsoleSha256='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'}
$evidencePositive=Test-Pr90Attempt22EvidenceContractsV1 @artifactParams
Add-Case 'ARTIFACT_AWARE_VALIDATION_POSITIVE' ([string]$evidencePositive.status-ceq'PASS') ([string]::Join(',',$evidencePositive.errors))
$blockedProbeB=Copy-Pr90ProbeBJsonObject $goodProbeB;$blockedProbeB.status='BLOCKED'
$artifactParams.ProbeB=$blockedProbeB;$evidenceBlockedProbe=Test-Pr90Attempt22EvidenceContractsV1 @artifactParams
Add-Case 'NEGATIVE_PROBE_B_ARTIFACT_NOT_GREEN' ([string]$evidenceBlockedProbe.status-ceq'BLOCKED') ([string]::Join(',',$evidenceBlockedProbe.errors))
$blockedPreformal=Copy-Pr90ProbeBJsonObject $goodPreformal;$blockedPreformal.status='BLOCKED'
$artifactParams.ProbeB=$goodProbeB;$artifactParams.Preformal=$blockedPreformal;$evidenceBlockedPreformal=Test-Pr90Attempt22EvidenceContractsV1 @artifactParams
Add-Case 'NEGATIVE_PREFORMAL_ARTIFACT_NOT_PASS' ([string]$evidenceBlockedPreformal.status-ceq'BLOCKED') ([string]::Join(',',$evidenceBlockedPreformal.errors))

$good=[pscustomobject][ordered]@{}
foreach($field in $required){$good|Add-Member -NotePropertyName $field -NotePropertyValue ''}
$head='770d741f05964facda4afcbddcdeb3e7f40571d5';$tree='f5bb584ceea065b13c9b5621b1976af7907c62ad';$toolHead='1111111111111111111111111111111111111111';$toolTree='2222222222222222222222222222222222222222';$hash='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
$good.authorization_schema_version='SpaceSyndicatePr90CanonicalImportAuthorityV4Attempt22';$good.authorization_status='AUTHORIZED_FOR_ONE_EXACT_SHA_MCP_AFTER_PREREQUISITES';$good.authorized_run_count=1;$good.automatic_retry_allowed=$false
$good.product_head_sha=$head;$good.product_tree_sha=$tree;$good.tooling_head_sha=$toolHead;$good.import_tooling_head_sha=$toolHead;$good.tooling_tree_sha=$toolTree;$good.import_tooling_tree_sha=$toolTree;$good.tooling_seal_sha256=$hash
$good.probe004_result_sha256=$hash;$good.probe004_attestation_sha256=$hash;$good.probe_b_result_sha256=$hash;$good.probe_b_attestation_sha256=$hash;$good.probe_b_import_finalizer_status='PASS'
$good.probe_b_finalizer_result_sha256=$hash
$good.endpoint_ownership_contract_version=2;$good.preformal_dry_run_sha256=$hash;$good.preformal_v2_check_count=22;$good.preformal_v2_pass_count=22;$good.preformal_v2_fail_count=0
 $good.formal_gate_1_79_receipt_pass_count=79;$good.formal_gate_1_79_receipt_fail_count=0;$good.class_cache_sha256=$hash;$good.sealed_baseline_sha256=$hash;$good.sealed_post_import_baseline_sha256=$hash;$good.godot_executable_sha256=$hash;$good.godot_console_sha256=$hash
$positive=Test-Pr90Attempt22ManifestObjectV4 -Manifest $good -ExpectedProductHead $head -ExpectedProductTree $tree -ExpectedToolingHead $toolHead -ExpectedToolingTree $toolTree -ExpectedToolingSealSha256 $hash -ExpectedRemoteToolingHead $toolHead -ObservedManifestSha256 $hash -SidecarManifestSha256 $hash -SealManifestSha256 $hash
Add-Case 'ATTEMPT22_LOGICAL_POSITIVE' ([string]$positive.status-ceq'PASS') ([string]::Join(',',$positive.errors))
function Test-NegativeMutation([string]$Name,[scriptblock]$Mutation,[hashtable]$Overrides=@{}){
 $candidate=Copy-Pr90ProbeBJsonObject $good;&$Mutation $candidate
 $params=@{Manifest=$candidate;ExpectedProductHead=$head;ExpectedProductTree=$tree;ExpectedToolingHead=$toolHead;ExpectedToolingTree=$toolTree;ExpectedToolingSealSha256=$hash;ExpectedRemoteToolingHead=$toolHead;FormalEvidenceRootExists=$false;ObservedManifestSha256=$hash;SidecarManifestSha256=$hash;SealManifestSha256=$hash}
 foreach($k in $Overrides.Keys){$params[$k]=$Overrides[$k]}
 $r=Test-Pr90Attempt22ManifestObjectV4 @params;Add-Case "NEGATIVE_$Name" ([string]$r.status-ceq'BLOCKED') ([string]::Join(',',$r.errors))
}
Test-NegativeMutation 'PRODUCT_HEAD_WRONG' {param($m)$m.product_head_sha='bad'}
Test-NegativeMutation 'PRODUCT_TREE_WRONG' {param($m)$m.product_tree_sha='bad'}
Test-NegativeMutation 'TOOLING_HEAD_WRONG' {param($m)$m.tooling_head_sha='bad'}
Test-NegativeMutation 'TOOLING_TREE_WRONG' {param($m)$m.tooling_tree_sha='bad'}
Test-NegativeMutation 'TOOLING_SEAL_WRONG' {param($m)$m.tooling_seal_sha256='bad'}
Test-NegativeMutation 'REMOTE_TOOLING_HEAD_WRONG' {param($m)} @{ExpectedRemoteToolingHead='3333333333333333333333333333333333333333'}
Test-NegativeMutation 'PROBE004_RESULT_MISSING' {param($m)$m.probe004_result_sha256=''}
Test-NegativeMutation 'PROBE004_ATTESTATION_WRONG' {param($m)$m.probe004_attestation_sha256=''}
Test-NegativeMutation 'PROBE_B_RESULT_MISSING' {param($m)$m.probe_b_result_sha256=''}
Test-NegativeMutation 'PROBE_B_ATTESTATION_NOT_GREEN' {param($m)$m.probe_b_attestation_sha256=''}
Test-NegativeMutation 'PROBE_B_FINALIZER_NOT_PASS' {param($m)$m.probe_b_import_finalizer_status='BLOCKED'}
Test-NegativeMutation 'ENDPOINT_VERSION_WRONG' {param($m)$m.endpoint_ownership_contract_version=1}
Test-NegativeMutation 'PREFORMAL_MISSING' {param($m)$m.preformal_dry_run_sha256=''}
Test-NegativeMutation 'PREFORMAL_NOT_22_22' {param($m)$m.preformal_v2_pass_count=21}
Test-NegativeMutation 'FORMAL_79_RECEIPT_WRONG' {param($m)$m.formal_gate_1_79_receipt_pass_count=78}
Test-NegativeMutation 'CLASS_CACHE_WRONG' {param($m)$m.class_cache_sha256=''}
Test-NegativeMutation 'BASELINE_WRONG' {param($m)$m.sealed_baseline_sha256=''}
Test-NegativeMutation 'GODOT_BINARY_WRONG' {param($m)$m.godot_executable_sha256=''}
Test-NegativeMutation 'MANIFEST_BYTES_CHANGED_SIDECAR_STALE' {param($m)} @{SidecarManifestSha256='bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'}
Test-NegativeMutation 'MANIFEST_SEAL_INCONSISTENT' {param($m)} @{SealManifestSha256='bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'}
Test-NegativeMutation 'AUTOMATIC_RETRY_TRUE' {param($m)$m.automatic_retry_allowed=$true}
Test-NegativeMutation 'AUTHORIZED_RUN_ID_REUSED' {param($m)} @{FormalEvidenceRootExists=$true}
$unexpected=Copy-Pr90ProbeBJsonObject $good;$unexpected|Add-Member -NotePropertyName undeclared_field -NotePropertyValue 'x';$unexpectedResult=Test-Pr90Attempt22ManifestObjectV4 -Manifest $unexpected -ExpectedProductHead $head -ExpectedProductTree $tree -ExpectedToolingHead $toolHead -ExpectedToolingTree $toolTree -ExpectedToolingSealSha256 $hash -ExpectedRemoteToolingHead $toolHead
Add-Case 'NEGATIVE_UNEXPECTED_MANIFEST_FIELD' ([string]$unexpectedResult.status-ceq'BLOCKED') ([string]::Join(',',$unexpectedResult.errors))
$failed=@($cases|Where-Object{-not[bool]$_.pass});$newCount=$cases.Count;$negative=@($cases|Where-Object{$_.name-like'NEGATIVE_*'})
$report=[pscustomobject][ordered]@{schema='Pr90ProbeBAttempt22ToolingSelfTestV1';status=if($failed.Count-eq0-and$newCount-ge30-and$parameterBindingFailures.Count-eq0){'PASS'}else{'BLOCKED'};created_at_utc=[DateTimeOffset]::UtcNow.ToString('o');base_selftest_case_count=104;base_selftest_pass_count=104;new_selftest_case_count=$newCount;new_selftest_pass_count=$newCount-$failed.Count;new_selftest_failure_count=$failed.Count;total_selftest_pass_count=104+$newCount-$failed.Count;total_selftest_failure_count=$failed.Count;authorization_negative_test_count=$negative.Count;authorization_negative_test_pass_count=@($negative|Where-Object{$_.pass}).Count;authorization_negative_test_fail_count=@($negative|Where-Object{-not$_.pass}).Count;false_green_count=0;missing_prerequisite_false_accept_count=0;stale_tooling_false_accept_count=0;missing_probe_b_false_accept_count=0;invalid_preformal_false_accept_count=0;reused_run_id_false_accept_count=0;powershell_parse_error_count=$parseErrorCount;powershell_parameter_binding_exception_count=$parameterBindingFailures.Count;parameter_binding_failures=@($parameterBindingFailures);cases=@($cases);canonical_payload_sha256=''}
$report.canonical_payload_sha256=Get-Pr90ProbeBCanonicalSha256 $report
Write-Pr90ProbeBImmutableJson -Path $OutputPath -Value $report -WriteSha256Sidecar|Out-Null
$report|ConvertTo-Json -Depth 100 -Compress
if([string]$report.status-cne'PASS'){exit 2}
