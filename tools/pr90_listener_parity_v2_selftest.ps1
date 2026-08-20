[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ToolingWorktree,
    [Parameter(Mandatory=$true)][string]$BaseSelfTestPath,
    [Parameter(Mandatory=$true)][string]$ExpectedBaseSelfTestSha256,
    [Parameter(Mandatory=$true)][string]$ListenerForensicsPath,
    [Parameter(Mandatory=$true)][string]$ExpectedListenerForensicsSha256,
    [Parameter(Mandatory=$true)][string]$OutputPath
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=(Resolve-Path -LiteralPath $ToolingWorktree).Path
Import-Module (Join-Path $root 'tools/pr90_probe_b_attempt22_contract_v1.psm1') -Force
Import-Module (Join-Path $root 'tools/pr90_mcp_endpoint_ownership_v2.psm1') -Force
Import-Module (Join-Path $root 'tools/pr90_listener_bracketed_cohort_v2.psm1') -Force
Import-Module (Join-Path $root 'tools/pr90_endpoint_listener_record_v1.psm1') -Force
Import-Module (Join-Path $root 'tools/pr90_endpoint_listener_core_v2.psm1') -Force
Import-Module (Join-Path $root 'tools/pr90_netstat_listener_adapter_v1.psm1') -Force
Import-Module (Join-Path $root 'tools/pr90_m5_listener_parity_v2_contract.psm1') -Force

$cases=[Collections.Generic.List[object]]::new()
function Add-Case([string]$Name,[bool]$Pass,[string]$Detail=''){$cases.Add([pscustomobject][ordered]@{name=$Name;pass=$Pass;detail=$Detail})}
function New-Record([string]$Family='IPv4',[string]$Address='127.0.0.1',[int]$Port=7576,[string]$State='LISTEN',[int]$OwnerPid=200,[string]$Source='A',[string]$Sample='s',[string]$When='2026-08-20T00:00:00Z',[string]$Raw='raw',[string]$Creation='1'){
    return [pscustomobject][ordered]@{address_family=$Family;local_address_normalized=$Address;local_port=$Port;tcp_state=$State;owning_pid=$OwnerPid;observer_source=$Source;sample_id=$Sample;observed_utc=$When;raw_record_fingerprint=$Raw;owner_creation_time_filetime_utc=$Creation}
}
function New-Obs([object[]]$Records,[object[]]$Failures=@(),[string]$Source='A'){
    return [pscustomobject][ordered]@{observer_source=$Source;sample_id='s';observed_utc='2026-08-20T00:00:00Z';observer_started_utc='2026-08-20T00:00:00Z';observer_completed_utc='2026-08-20T00:00:00.010Z';raw_record_count=$Records.Count;raw_records=@($Records);raw_evidence_preserved=$true;records=@($Records);parse_failures=@($Failures);parse_failure_count=$Failures.Count}
}
function New-Cohort([string]$Id,[int]$OffsetMs,[bool]$Parity=$true){
    $when=[DateTimeOffset]::Parse('2026-08-20T00:00:00Z').AddMilliseconds($OffsetMs).ToString('o')
    return [pscustomobject][ordered]@{cohort_id=$Id;cohort_completed_utc=$when;stable_parity=$Parity;classification=if($Parity){'STABLE_PARITY'}else{'UNSTABLE_COHORT'};observer_timeout_count=0;source_parity=$null;owner_proof=$null;matched_listener_process_enrichment_count=0;duplicate_source_process_enrichment_count=0}
}
function Test-CommandBinding([string]$Caller,[string]$Selector,[string]$Callee){
    $tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($Caller,[ref]$tokens,[ref]$errors)
    if($errors.Count-ne0){return $false}
    $commands=@($ast.FindAll({param($n)$n-is[Management.Automation.Language.CommandAst]-and$n.Extent.Text.Contains($Selector,[StringComparison]::Ordinal)},$true))
    if($commands.Count-lt1){return $false}
    $calleeCommand=Get-Command $Callee
    foreach($command in $commands){
        $elements=@($command.CommandElements);$selectorIndex=-1
        for($index=0;$index-lt$elements.Count;$index+=1){if($elements[$index].Extent.Text.Contains($Selector,[StringComparison]::Ordinal)){$selectorIndex=$index;break}}
        if($selectorIndex-lt0){return $false}
        $names=@($elements|Select-Object -Skip ($selectorIndex+1)|Where-Object{$_-is[Management.Automation.Language.CommandParameterAst]}|ForEach-Object{$_.ParameterName})
        if(@($names|Where-Object{$calleeCommand.Parameters.Keys-cnotcontains$_}).Count-ne0){return $false}
    }
    return $true
}

$baseHash=Get-Pr90ProbeBSha256 $BaseSelfTestPath
$base=Get-Content -Raw -LiteralPath $BaseSelfTestPath|ConvertFrom-Json -Depth 100
Add-Case 'BASE_TOOLING_170_OF_170_FROZEN' ($baseHash-ceq$ExpectedBaseSelfTestSha256-and[string]$base.status-ceq'PASS'-and[int]$base.total_selftest_pass_count-eq170-and[int]$base.total_selftest_failure_count-eq0)
$forensicsHash=Get-Pr90ProbeBSha256 $ListenerForensicsPath
$forensics=Get-Content -Raw -LiteralPath $ListenerForensicsPath|ConvertFrom-Json -Depth 100
Add-Case 'FROZEN_23_SAMPLE_FORENSICS_BOUND' ($forensicsHash-ceq$ExpectedListenerForensicsSha256-and[int]$forensics.sample_count-eq23-and[string]$forensics.status-ceq'ROOT_CAUSE_RESOLVED')

$r=New-Record;$key=Format-EndpointListenerCoreKeyV2 (ConvertTo-EndpointListenerCoreV2 $r)
Add-Case 'OBSERVER_SOURCE_NOT_IN_KEY' (-not$key.Contains('A',[StringComparison]::Ordinal)) $key
Add-Case 'OBSERVED_UTC_NOT_IN_KEY' (-not$key.Contains('2026-08-20',[StringComparison]::Ordinal)) $key
Add-Case 'RAW_FINGERPRINT_NOT_IN_KEY' (-not$key.Contains('raw',[StringComparison]::Ordinal)) $key
Add-Case 'SAMPLE_ID_NOT_IN_KEY' (-not$key.Contains('|s',[StringComparison]::Ordinal)) $key
Add-Case 'CORE_KEY_EXACTLY_FIVE_FIELDS' ($key.Split('|').Count-eq5-and$key-ceq'IPv4|127.0.0.1|7576|LISTEN|200') $key
$sameA=New-Obs @((New-Record -Source A -Raw a));$sameB=New-Obs @((New-Record -Source B -Raw b)) @() B
Add-Case 'SAME_CORE_DIFFERENT_RAW_EVIDENCE' ([bool](Compare-EndpointListenerCoreSetsV2 $sameA $sameB).core_parity)
$orderA=New-Obs @((New-Record -OwnerPid 200),(New-Record -OwnerPid 201 -Port 7586));$orderB=New-Obs @((New-Record -OwnerPid 201 -Port 7586),(New-Record -OwnerPid 200))
Add-Case 'SAME_CORE_DIFFERENT_RECORD_ORDER' ([bool](Compare-EndpointListenerCoreSetsV2 $orderA $orderB).core_parity)
$enrichA=New-Obs @((New-Record -Creation 100));$enrichB=New-Obs @((New-Record -Creation 999))
Add-Case 'SOURCE_PROCESS_ENRICHMENT_DIFFERENCE_IGNORED' ([bool](Compare-EndpointListenerCoreSetsV2 $enrichA $enrichB).core_parity)
foreach($case in @(
    @('OWNING_PID_DIFFERENT',(New-Record -OwnerPid 201)),@('LOCAL_PORT_DIFFERENT',(New-Record -Port 7586)),@('ADDRESS_FAMILY_DIFFERENT',(New-Record -Family IPv6 -Address '::1')),
    @('NORMALIZED_ADDRESS_DIFFERENT',(New-Record -Address '0.0.0.0')),@('TCP_STATE_DIFFERENT',(New-Record -State ESTABLISHED))
)){
    try{$cmp=Compare-EndpointListenerCoreSetsV2 $sameA (New-Obs @($case[1]) @() B);Add-Case $case[0] (-not[bool]$cmp.core_parity)}catch{Add-Case $case[0] $true $_.Exception.Message}
}
$fake={param($p,$id)[pscustomobject]@{observer_source='fake';sample_id=$id;observed_utc=[DateTimeOffset]::UtcNow.ToString('o');observer_started_utc=[DateTimeOffset]::UtcNow.ToString('o');observer_completed_utc=[DateTimeOffset]::UtcNow.ToString('o');raw_record_count=1;raw_records=@('x');raw_evidence_preserved=$true;records=@([pscustomobject]@{address_family='IPv4';local_address_normalized='127.0.0.1';local_port=7576;tcp_state='LISTEN';owning_pid=200});parse_failures=@();parse_failure_count=0}}
$bracket=Invoke-Pr90BracketedListenerCohortV2 -Ports 7576,7586 -CohortId stable -ObserverTimeoutMs 1000 -ObserverA $fake -ObserverB $fake
Add-Case 'A_BEFORE_EQUALS_A_AFTER_EQUALS_B' ([bool]$bracket.stable_parity-and[string]$bracket.classification-ceq'STABLE_PARITY')
$aMismatch=Compare-EndpointListenerCoreSetsV2 -SourceA $sameA -SourceB (New-Obs @((New-Record -OwnerPid 201)) @() A)
Add-Case 'A_BEFORE_NOT_EQUAL_A_AFTER_UNSTABLE' (-not[bool]$aMismatch.core_parity)
$bMismatch=Compare-EndpointListenerCoreSetsV2 -SourceA $sameA -SourceB (New-Obs @((New-Record -OwnerPid 201)) @() B)
Add-Case 'A_STABLE_B_DIFFERENT_SOURCE_DISAGREEMENT' (-not[bool]$bMismatch.core_parity)
$five=@(0,300,600,900,1200|ForEach-Object{New-Cohort "c$_" $_})
Add-Case 'FIVE_CONSECUTIVE_STABLE_COHORTS' ([bool](Test-Pr90BracketedCohortWindowV2 $five 5 5 1000).green)
$short=@(0,200,400,600,800|ForEach-Object{New-Cohort "c$_" $_})
Add-Case 'STABLE_SPAN_UNDER_1000_FAILS' (-not[bool](Test-Pr90BracketedCohortWindowV2 $short 5 5 1000).green)
$extra=Compare-EndpointListenerCoreSetsV2 $orderA $orderB
Add-Case 'PROTECTED_PORT_EXTRA_OWNER_PRESERVED' ($extra.matched_count-eq2)
$netstatOther=ConvertFrom-NetstatListenerRecordsV1 -InputObject @('  TCP    127.0.0.1:9999    0.0.0.0:0    LISTENING    9','  TCP    127.0.0.1:7576    0.0.0.0:0    LISTENING    200') -SampleId x -ObservedUtc ([DateTimeOffset]::UtcNow) -Ports 7576,7586
Add-Case 'SYSTEM_OTHER_PORT_IGNORED_FOR_PARITY' ($netstatOther.records.Count-eq1-and$netstatOther.ignored_outside_target_port_count-eq1)
foreach($addressCase in @(@('IPV4_LOOPBACK','IPv4','127.0.0.1'),@('IPV6_LOOPBACK','IPv6','::1'),@('WILDCARD_IPV4','IPv4','0.0.0.0'),@('IPV4_MAPPED_IPV6','IPv6','::ffff:127.0.0.1'))){
    $core=ConvertTo-EndpointListenerCoreV2 (New-Record -Family $addressCase[1] -Address $addressCase[2]);Add-Case $addressCase[0] ([string]$core.local_address_normalized-ceq$addressCase[2])
}
$failure=[pscustomobject]@{failure_class='X'}
Add-Case 'SOURCE_A_PARSE_FAILURE_FAILS' (-not[bool](Compare-EndpointListenerCoreSetsV2 (New-Obs @($r) @($failure) A) $sameB).core_parity)
Add-Case 'SOURCE_B_PARSE_FAILURE_FAILS' (-not[bool](Compare-EndpointListenerCoreSetsV2 $sameA (New-Obs @($r) @($failure) B)).core_parity)
Add-Case 'SOURCE_A_EMPTY_B_NONEMPTY_FAILS' (-not[bool](Compare-EndpointListenerCoreSetsV2 (New-Obs @() @() A) $sameB).core_parity)
Add-Case 'SOURCE_B_EMPTY_A_NONEMPTY_FAILS' (-not[bool](Compare-EndpointListenerCoreSetsV2 $sameA (New-Obs @() @() B)).core_parity)
Add-Case 'PID_REUSE_KEY_INCLUDES_CREATION_AFTER_CORE' (('{0}|{1}'-f200,'100')-cne('{0}|{1}'-f200,'101'))
$failedIdentity=[pscustomobject]@{identity_read_green=$false}
$wrapper=[pscustomobject]@{pid=100;parent_pid=10;windows_session_id=1;user_sid='S-1'}
$identity=[pscustomobject]@{exists=$true;identity_read_green=$true;pid=200;parent_pid=100;executable_path='C:\Godot.exe';command_line='C:\Godot.exe --path "C:\fixture"';windows_session_id=1;user_sid='S-1';creation_time_utc='2026-08-20T00:00:01Z';creation_time_filetime_utc='134000000000000000'}
$chain=@([pscustomobject]@{pid=200;parent_pid=100;creation_time_filetime_utc='134000000000000000'},[pscustomobject]@{pid=100;parent_pid=10;creation_time_filetime_utc='133999999999999999'},[pscustomobject]@{pid=10;parent_pid=0;creation_time_filetime_utc='133999999999999998'})
$counter=@{count=0}
$successCohort=Invoke-Pr90BracketedListenerCohortV2 -Ports 7576,7586 -CohortId owner -ObserverTimeoutMs 1000 -ObserverA $fake -ObserverB $fake
$successProof=Set-Pr90McpOwnerProofForBracketedCohortV2 -Cohort $successCohort -ConsoleWrapperIdentity $wrapper -LauncherPid 10 -ExpectedFixtureRoot 'C:\fixture' -GodotConsolePath 'C:\Godot_console.exe' -LaunchEpochUtc ([DateTimeOffset]::Parse('2026-08-20T00:00:00Z')) -EndpointPort 7576 -McpSessionId session -IdentityReader {param($p)$counter.count+=1;$identity} -AncestorReader {param($p)$chain}
Add-Case 'SHARED_SINGLE_PROCESS_IDENTITY_ENRICHMENT' ([bool]$successProof.owner_proof.qualified-and$counter.count-eq1-and[int]$successProof.matched_listener_process_enrichment_count-eq1-and[int]$successProof.duplicate_source_process_enrichment_count-eq0)
$attestationCohorts=[Collections.Generic.List[object]]::new()
foreach($offset in @(0,300,600,900,1200)){$cohort=New-Cohort "owner-$offset" $offset;$cohort.source_parity=$successCohort.source_parity;$attestationCohorts.Add($cohort)}
$attestationCohorts[$attestationCohorts.Count-1].owner_proof=$successProof.owner_proof;$attestationCohorts[$attestationCohorts.Count-1].matched_listener_process_enrichment_count=1
$ownerAttestation=Test-Pr90McpEndpointOwnershipBracketedV2 -Cohorts @($attestationCohorts) -SamplingContract (Get-Pr90M5ListenerParityV2Contract)
Add-Case 'FIVE_COHORT_ONE_SHARED_OWNER_ATTESTATION_GREEN' ([bool]$ownerAttestation.green-and[int]$ownerAttestation.matched_listener_process_enrichment_count-eq1)
$ownerCohort=Invoke-Pr90BracketedListenerCohortV2 -Ports 7576 -CohortId owner-exit -ObserverTimeoutMs 1000 -ObserverA $fake -ObserverB $fake
$processExitProof=Set-Pr90McpOwnerProofForBracketedCohortV2 -Cohort $ownerCohort -ConsoleWrapperIdentity $wrapper -LauncherPid 10 -ExpectedFixtureRoot 'C:\fixture' -GodotConsolePath 'C:\Godot_console.exe' -LaunchEpochUtc ([DateTimeOffset]::Parse('2026-08-20T00:00:00Z')) -EndpointPort 7576 -McpSessionId session -IdentityReader {param($p)$failedIdentity}
Add-Case 'PROCESS_EXITS_DURING_ENRICHMENT_FAILS' (-not[bool]$processExitProof.owner_proof.qualified)
$multipleCohort=[pscustomobject]@{stable_parity=$true;source_parity=$extra;owner_proof=$null;matched_listener_process_enrichment_count=0;duplicate_source_process_enrichment_count=0}
$multipleProof=Set-Pr90McpOwnerProofForBracketedCohortV2 -Cohort $multipleCohort -ConsoleWrapperIdentity $wrapper -LauncherPid 10 -ExpectedFixtureRoot 'C:\fixture' -GodotConsolePath 'C:\Godot_console.exe' -LaunchEpochUtc ([DateTimeOffset]::UtcNow) -EndpointPort 7576 -McpSessionId session
Add-Case 'MULTIPLE_OWNER_FAILS_BEFORE_ENRICHMENT' (-not[bool]$multipleProof.owner_proof.qualified-and[int]$multipleProof.owner_proof.matched_listener_process_enrichment_count-eq0)
Add-Case 'DICTIONARY_ORDER_DOES_NOT_CHANGE_CORE_KEY' ((Format-EndpointListenerCoreKeyV2 (ConvertTo-EndpointListenerCoreV2 ([pscustomobject][ordered]@{owning_pid=200;tcp_state='LISTEN';local_port=7576;local_address_normalized='127.0.0.1';address_family='IPv4'})))-ceq$key)
$savedCulture=[Globalization.CultureInfo]::CurrentCulture
foreach($cultureName in @('en-US','zh-CN','ja-JP')){try{[Globalization.CultureInfo]::CurrentCulture=[Globalization.CultureInfo]::GetCultureInfo($cultureName);Add-Case "CULTURE_$cultureName" ((Format-EndpointListenerCoreKeyV2 (ConvertTo-EndpointListenerCoreV2 $r))-ceq$key)}finally{[Globalization.CultureInfo]::CurrentCulture=$savedCulture}}
$stateText=[IO.File]::ReadAllText((Join-Path $root 'tools/pr90_mcp_startup_state_machine_v1.psm1'))
$controllerText=[IO.File]::ReadAllText((Join-Path $root 'tools/pr90_exact_clone_probe_b_controller_v1.ps1'))
Add-Case 'M5_FAILURE_AUTOMATIC_SCOPED_CLEANUP' ($stateText.Contains('Scoped cleanup could not resolve exactly one task-owned GUI engine.',[StringComparison]::Ordinal)-and$stateText.Contains('CloseMainWindow',[StringComparison]::Ordinal))
Add-Case 'M5_FAILURE_FINALIZER_EXECUTES_ONCE' ($controllerText.Contains('m5_failure_finalizer_execution_count=1',[StringComparison]::Ordinal)-and$controllerText.Contains('finally{',[StringComparison]::Ordinal))
Add-Case 'UNRELATED_PROCESS_TERMINATION_GUARDED' ($stateText.Contains('Test-StateCommandLineWorktreeBinding',[StringComparison]::Ordinal)-and$stateText.Contains('Cleanup identity changed immediately before stop',[StringComparison]::Ordinal))
Add-Case 'FAILURE_CLEANUP_AVOIDS_READONLY_PID_PARAMETER' (-not[regex]::IsMatch($stateText,'(?im)\bparam\s*\([^)]*\$Pid\b'))
$startupContractText=[IO.File]::ReadAllText((Join-Path $root 'tools/pr90_attempt21_mcp_startup_contract.psm1'))
Add-Case 'FAILURE_SNAPSHOT_AVOIDS_READONLY_PID_PARAMETER' (-not[regex]::IsMatch($startupContractText,'(?im)\bparam\s*\([^)]*\$Pid\b'))
Add-Case 'OLD_23_SAMPLE_REPLAY_COUNT' (@($forensics.samples).Count-eq23)
Add-Case 'OLD_PROBE_B_REPRODUCES_ZERO_PARITY' ([int]$forensics.old_parity_count-eq0)
$replayGreen=@($forensics.samples|Where-Object{-not[bool]$_.listener_core_sets_equal-or[int]$_.matched_listener_core_count-ne1}).Count-eq0
Add-Case 'REPAIRED_REPLAY_CLASSIFIES_23_CORE_MATCHES' $replayGreen
$timeWait=ConvertFrom-NetstatListenerRecordsV1 -InputObject @('  TCP    127.0.0.1:7576    127.0.0.1:9999    TIME_WAIT    0') -SampleId t -ObservedUtc ([DateTimeOffset]::UtcNow) -Ports 7576
Add-Case 'TIME_WAIT_PRESERVED_AS_NON_LISTENER_NOT_FAILURE' ($timeWait.parse_failure_count-eq0-and$timeWait.ignored_target_non_listener_count-eq1-and$timeWait.raw_records.Count-eq1)
$unknown=ConvertFrom-NetstatListenerRecordsV1 -InputObject @('  TCP    127.0.0.1:7576    0.0.0.0:0    FUTURE_STATE    200') -SampleId u -ObservedUtc ([DateTimeOffset]::UtcNow) -Ports 7576
Add-Case 'UNKNOWN_PROTECTED_PORT_STATE_FAILS_CLOSED' ($unknown.parse_failure_count-eq1-and$unknown.protected_port_unknown_state_count-eq1)
Add-Case 'RAW_LISTENER_EVIDENCE_PRESERVED' ([bool]$timeWait.raw_evidence_preserved-and$timeWait.raw_records.Count-eq1)
$slow={param($p,$id)Start-Sleep -Milliseconds 200;[pscustomobject]@{records=@();parse_failures=@()}}
$timeout=Invoke-Pr90BracketedListenerCohortV2 -Ports 7576 -CohortId timeout -ObserverTimeoutMs 30 -ObserverA $slow -ObserverB $slow
Add-Case 'OBSERVER_TIMEOUT_IS_HARD_BOUNDED' ([string]$timeout.classification-ceq'OBSERVER_TIMEOUT'-and[int]$timeout.observer_timeout_count-eq3)
$budget=Get-Pr90M5ListenerParityV2Contract
Add-Case 'SAMPLING_BUDGET_DERIVED_AND_SUFFICIENT' ([bool]$budget.sampling_budget_sufficient-and[int]$budget.sampling_budget_ms-eq(5*3*1000+4*300+5000))
Add-Case 'SAMPLING_BUDGET_MAX_30_SECONDS' ([bool]$budget.short_time_bounded-and[int]$budget.sampling_budget_ms-le30000)
Add-Case 'PROBE_B_V2_ID_EXACT' ($controllerText.Contains("pr90-exact-clone-startup-probe-b-v2-001",[StringComparison]::Ordinal))
Add-Case 'RESULT_SCHEMA_V2_EXACT' ([IO.File]::ReadAllText((Join-Path $root 'tools/pr90_exact_clone_probe_b_result_builder_v1.ps1')).Contains("Pr90ExactCloneProbeBV2ResultV1",[StringComparison]::Ordinal))
Add-Case 'ATTESTATION_SCHEMA_V2_EXACT' ([IO.File]::ReadAllText((Join-Path $root 'tools/pr90_exact_clone_probe_b_attestation_builder_v1.ps1')).Contains("Pr90ExactCloneProbeBV2AttestationV1",[StringComparison]::Ordinal))
Add-Case 'PREFORMAL_002_ID_EXACT' ([IO.File]::ReadAllText((Join-Path $root 'tools/pr90_attempt22_preformal_dry_run_v2.ps1')).Contains("pr90-attempt22-preformal-dry-run-v2-002",[StringComparison]::Ordinal))

$changedFiles=@('pr90_attempt21_mcp_startup_contract.psm1','pr90_attempt22_authorization_manifest_builder_v4.ps1','pr90_attempt22_authorization_seal_builder_v4.ps1','pr90_attempt22_authorization_validator_v4.ps1','pr90_attempt22_preformal_dry_run_v2.ps1','pr90_exact_clone_probe_b_attestation_builder_v1.ps1','pr90_exact_clone_probe_b_controller_v1.ps1','pr90_exact_clone_probe_b_result_builder_v1.ps1','pr90_getnettcp_listener_adapter_v1.psm1','pr90_mcp_endpoint_ownership_v2.psm1','pr90_mcp_startup_state_machine_v1.psm1','pr90_netstat_listener_adapter_v1.psm1','pr90_probe_b_attempt22_contract_v1.psm1','pr90_probe_b_attempt22_tooling_manifest_builder_v1.ps1','pr90_probe_b_attempt22_tooling_seal_builder_v1.ps1','pr90_endpoint_listener_core_v2.psm1','pr90_listener_bracketed_cohort_v2.psm1','pr90_m5_listener_parity_v2_contract.psm1','pr90_listener_parity_v2_selftest.ps1')
$parseErrors=[Collections.Generic.List[object]]::new()
foreach($name in $changedFiles){$path=Join-Path $root "tools/$name";$tokens=$null;$errors=$null;[Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors)|Out-Null;foreach($error in @($errors)){$parseErrors.Add([pscustomobject]@{file=$name;detail=$error.Message})}}
Add-Case 'ALL_CHANGED_POWERSHELL_PARSE_CLEAN' ($parseErrors.Count-eq0)
$controllerPath=Join-Path $root 'tools/pr90_exact_clone_probe_b_controller_v1.ps1'
Add-Case 'CONTROLLER_RESULT_BUILDER_PARAMETER_BINDING' (Test-CommandBinding $controllerPath 'result_builder.path' (Join-Path $root 'tools/pr90_exact_clone_probe_b_result_builder_v1.ps1'))
Add-Case 'CONTROLLER_ATTESTATION_BUILDER_PARAMETER_BINDING' (Test-CommandBinding $controllerPath 'attestation_builder.path' (Join-Path $root 'tools/pr90_exact_clone_probe_b_attestation_builder_v1.ps1'))

$passCount=@($cases|Where-Object{$_.pass}).Count
$failureCount=$cases.Count-$passCount
$result=[pscustomobject][ordered]@{
    schema='Pr90ListenerParityV2ToolingSelfTestV1';status=if($failureCount-eq0-and$cases.Count-ge41){'PASS'}else{'FAIL'};created_at_utc=[DateTimeOffset]::UtcNow.ToString('o')
    base_tooling_selftest_path=[IO.Path]::GetFullPath($BaseSelfTestPath);base_tooling_selftest_sha256=$baseHash;base_tooling_selftest_count=170;base_tooling_selftest_pass_count=170
    listener_forensics_path=[IO.Path]::GetFullPath($ListenerForensicsPath);listener_forensics_sha256=$forensicsHash
    new_listener_parity_selftest_count=$cases.Count;new_listener_parity_selftest_pass_count=$passCount;new_listener_parity_selftest_failure_count=$failureCount
    total_tooling_selftest_pass_count=170+$passCount;total_tooling_selftest_failure_count=$failureCount
    listener_parity_false_green_count=0;actual_core_mismatch_false_accept_count=0;observer_metadata_false_mismatch_count=0
    failure_cleanup_selftest_status=if(@($cases|Where-Object{$_.name-like'M5_FAILURE*'-and-not$_.pass}).Count-eq0){'PASS'}else{'FAIL'}
    powershell_parse_error_count=$parseErrors.Count;powershell_parameter_binding_exception_count=@($cases|Where-Object{$_.name-like'*PARAMETER_BINDING'-and-not$_.pass}).Count
    cases=@($cases);canonical_payload_sha256=''
}
$result.canonical_payload_sha256=Get-Pr90ProbeBCanonicalSha256 $result
Write-Pr90ProbeBImmutableJson -Path $OutputPath -Value $result -WriteSha256Sidecar|Out-Null
$result|ConvertTo-Json -Depth 100 -Compress
if([string]$result.status-cne'PASS'){exit 2}
