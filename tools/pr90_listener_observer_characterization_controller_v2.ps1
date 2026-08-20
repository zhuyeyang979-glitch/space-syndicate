[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ProbeRoot,
    [Parameter(Mandatory=$true)][string]$FixtureSourceRoot,
    [Parameter(Mandatory=$true)][string]$ToolingWorktree,
    [Parameter(Mandatory=$true)][string]$GodotConsolePath,
    [Parameter(Mandatory=$true)][string]$ToolingManifestPath,
    [Parameter(Mandatory=$true)][string]$ExpectedToolingManifestSha256,
    [Parameter(Mandatory=$true)][string]$ToolingSealPath,
    [Parameter(Mandatory=$true)][string]$ExpectedToolingSealSha256,
    [Parameter(Mandatory=$true)][string]$SelfTestPath,
    [Parameter(Mandatory=$true)][string]$ExpectedSelfTestSha256,
    [ValidateRange(1,65535)][int]$Port=7576,
    [ValidateRange(1,65535)][int]$SecondaryPort=7586
)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'pr90_endpoint_listener_record_v1.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'pr90_getnettcp_listener_adapter_v1.psm1')
Import-Module (Join-Path $PSScriptRoot 'pr90_netstat_listener_adapter_v1.psm1')
Import-Module (Join-Path $PSScriptRoot 'pr90_listener_process_identity_reader_v1.psm1')
Import-Module (Join-Path $PSScriptRoot 'pr90_endpoint_listener_key_formatter_v1.psm1')
Import-Module (Join-Path $PSScriptRoot 'pr90_listener_parity_validator_v1.psm1')

$probeId='pr90-m5-endpoint-owner-characterization-v5-001'
$expectedFixtureHead='99c53e0ac2663155d24e4c645644f93b08e3fd09'
$expectedFixtureTree='4435a8d7ed9f824180c12dbae6e489c778f2226a'
$productHead='770d741f05964facda4afcbddcdeb3e7f40571d5'
$productTree='f5bb584ceea065b13c9b5621b1976af7907c62ad'
$root=[IO.Path]::GetFullPath($ProbeRoot)
if(Test-Path -LiteralPath $root){throw "Characterization root must be new: $root"}
$tooling=(Resolve-Path -LiteralPath $ToolingWorktree).Path.TrimEnd('\')
$fixtureSource=(Resolve-Path -LiteralPath $FixtureSourceRoot).Path.TrimEnd('\')
$godot=(Resolve-Path -LiteralPath $GodotConsolePath).Path
$manifestPath=(Resolve-Path -LiteralPath $ToolingManifestPath).Path
$sealPath=(Resolve-Path -LiteralPath $ToolingSealPath).Path
$selfTestPath=(Resolve-Path -LiteralPath $SelfTestPath).Path

function Write-EvidenceJson([string]$Path,[object]$Value){
    Set-Pr90CanonicalPayloadV1 $Value | Out-Null
    Write-Pr90ImmutableJson -Path $Path -Value $Value -WriteSha256Sidecar|Out-Null
}
function Write-Milestone([string]$Id,[string]$Status,[string]$FailureClass,[object]$Facts){
    $receipt=[ordered]@{schema='SpaceSyndicatePr90M5CharacterizationMilestoneReceiptV3';probe_id=$probeId;milestone_id=$Id;status=$Status;failure_class=$FailureClass;completed_utc=[DateTimeOffset]::UtcNow.ToString('o');facts=$Facts;first_jsonrpc_request_count=0;endpoint_application_request_count=0;m6_to_m11_count=0;formal_mcp_execution_count=0;authorized_run_count_consumed=0;canonical_payload_sha256=''}
    Write-EvidenceJson (Join-Path $evidence ("$Id-receipt.json")) $receipt
}
function Test-PathBinding([string]$CommandLine,[string]$ExpectedPath){
    if([string]::IsNullOrWhiteSpace($CommandLine)){return $false}
    return ($CommandLine.IndexOf($ExpectedPath,[StringComparison]::OrdinalIgnoreCase)-ge0-or$CommandLine.IndexOf($ExpectedPath.Replace('\','/'),[StringComparison]::OrdinalIgnoreCase)-ge0)
}
function Get-GodotRows {
    return ,@(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue|Where-Object{[string]$_.Name-match'(?i)^Godot.*\.exe$'})
}
function Add-IdentityToObservation([object]$Observation,[hashtable]$IdentityByPid){
    $records=[Collections.Generic.List[object]]::new();$failures=[Collections.Generic.List[object]]::new()
    foreach($failure in @($Observation.parse_failures)){$failures.Add($failure)}
    foreach($record in @($Observation.records)){
        $pidKey=[string][int]$record.owning_pid
        if(-not$IdentityByPid.ContainsKey($pidKey)-or-not[bool]$IdentityByPid[$pidKey].identity_read_green){
            $failureClass=if($IdentityByPid.ContainsKey($pidKey)){[string]$IdentityByPid[$pidKey].failure_class}else{'PROCESS_IDENTITY_NOT_READ'}
            $failures.Add([pscustomobject]@{source=$Observation.observer_source;failure_class=$failureClass;owning_pid=[int]$record.owning_pid})
        }else{
            try{$records.Add((Set-EndpointListenerOwnerIdentityV1 $record $IdentityByPid[$pidKey]))}catch{$failures.Add([pscustomobject]@{source=$Observation.observer_source;failure_class='PROCESS_IDENTITY_ENRICHMENT_FAILED';owning_pid=[int]$record.owning_pid;detail=$_.Exception.Message})}
        }
    }
    return [pscustomobject][ordered]@{schema='EndpointListenerSourceObservationV1';observer_source=$Observation.observer_source;sample_id=$Observation.sample_id;observed_utc=$Observation.observed_utc;raw_record_count=$Observation.raw_record_count;records=@($records);parse_failures=@($failures);parse_failure_count=$failures.Count}
}

[IO.Directory]::CreateDirectory($root)|Out-Null
$evidence=Join-Path $root 'evidence';[IO.Directory]::CreateDirectory($evidence)|Out-Null
$fixture=Join-Path $root 'minimal-project'
$milestoneFailure='';$characterizationFailure='';$launcher=$null;$launchReceipt=$null;$wrapperPid=0;$ownerPid=0;$samples=[Collections.Generic.List[object]]::new();$processCreateRequestUtc=$null;$launcherIdentity=$null;$wrapperIdentity=$null;$ownerIdentity=$null;$ancestorChain=@();$forcedStop=$false;$normalCloseRequested=$false;$taskPids=[Collections.Generic.HashSet[int]]::new();$m5Green=$false;$manifest=$null;$seal=$null;$selftest=$null;$stable=$null
try{
    if((Get-Pr90Sha256 $manifestPath)-cne$ExpectedToolingManifestSha256.ToLowerInvariant()){throw 'Tooling manifest SHA mismatch.'}
    if((Get-Pr90Sha256 $sealPath)-cne$ExpectedToolingSealSha256.ToLowerInvariant()){throw 'Tooling seal SHA mismatch.'}
    if((Get-Pr90Sha256 $selfTestPath)-cne$ExpectedSelfTestSha256.ToLowerInvariant()){throw 'Self-test SHA mismatch.'}
    $manifest=Get-Content -Raw -LiteralPath $manifestPath|ConvertFrom-Json -Depth 100 -DateKind String
    $seal=Get-Content -Raw -LiteralPath $sealPath|ConvertFrom-Json -Depth 100 -DateKind String
    $selftest=Get-Content -Raw -LiteralPath $selfTestPath|ConvertFrom-Json -Depth 100 -DateKind String
    $toolingHead=(& git -C $tooling rev-parse HEAD).Trim();$toolingTree=(& git -C $tooling rev-parse 'HEAD^{tree}').Trim()
    $gitClean=@(& git -C $tooling status --porcelain=v1 --untracked-files=all).Count-eq0
    $fileMismatch=@($manifest.tooling_files|Where-Object{(Get-Pr90Sha256 $_.path)-cne[string]$_.sha256}).Count
    $m0Green=([string]$manifest.schema-ceq'SpaceSyndicatePr90ListenerObserverToolingManifestV4'-and[string]$manifest.status-ceq'READY_FOR_ONE_M0_M5_CHARACTERIZATION_ONLY'-and[bool]$manifest.characterization_eligible-and-not[bool]$manifest.formal_authorization_eligible-and[string]$seal.schema-ceq'SpaceSyndicatePr90ListenerObserverToolingSealV4'-and[string]$seal.status-ceq'SEALED'-and[bool]$seal.characterization_eligible-and[string]$seal.authorized_characterization_probe_id-ceq$probeId-and[string]$selftest.schema-ceq'SpaceSyndicatePr90ListenerObserverSelfTestV4'-and[string]$selftest.status-ceq'PASS'-and[int]$selftest.case_count-ge60-and[int]$selftest.pass_count-eq[int]$selftest.case_count-and[bool]$selftest.ancestor_chain_flat_cardinality_green-and[int]$selftest.ancestor_chain_nested_array_count-eq0-and[int]$selftest.ancestor_chain_pid_conversion_failure_count-eq0-and[string]$manifest.tooling_head_sha-ceq$toolingHead-and[string]$manifest.tooling_tree_sha-ceq$toolingTree-and$gitClean-and$fileMismatch-eq0)
    if(-not$m0Green){throw 'M0 characterization-only seal revalidation failed.'}
    Write-Milestone M0 PASS '' ([ordered]@{tooling_head=$toolingHead;tooling_tree=$toolingTree;manifest_sha256=Get-Pr90Sha256 $manifestPath;seal_sha256=Get-Pr90Sha256 $sealPath;selftest_sha256=Get-Pr90Sha256 $selfTestPath;tooling_clean=$gitClean;file_mismatch_count=$fileMismatch})

    & git clone --quiet --no-hardlinks --local $fixtureSource $fixture
    if($LASTEXITCODE-ne0){throw 'Fresh minimal fixture clone failed.'}
    $fixtureHead=(& git -C $fixture rev-parse HEAD).Trim();$fixtureTree=(& git -C $fixture rev-parse 'HEAD^{tree}').Trim();$fixtureClean=@(& git -C $fixture status --porcelain=v1 --untracked-files=all).Count-eq0
    if($fixtureHead-cne$expectedFixtureHead-or$fixtureTree-cne$expectedFixtureTree-or-not$fixtureClean){throw 'Fresh minimal fixture identity mismatch.'}
    $protectedPorts=@($Port,$SecondaryPort)|Sort-Object -Unique
    $preNet=Invoke-GetNetTcpListenerObservationV1 -Ports $protectedPorts -SampleId prelaunch
    $preStat=Invoke-NetstatTcpListenerObservationV1 -Ports $protectedPorts -SampleId prelaunch
    $preGodot=Get-GodotRows
    $preCount=@($preNet.records).Count+@($preStat.records).Count
    if($preCount-ne0-or$preNet.parse_failure_count-ne0-or$preStat.parse_failure_count-ne0-or$preGodot.Count-ne0){throw "Prelaunch process/port gate failed: listener_records=$preCount godot=$($preGodot.Count)"}
    $m1=[ordered]@{schema='SpaceSyndicatePr90M5CharacterizationExecutionStartV3';probe_id=$probeId;started_utc=[DateTimeOffset]::UtcNow.ToString('o');fixture_head=$fixtureHead;fixture_tree=$fixtureTree;fixture_root=$fixture;fixture_clean=$fixtureClean;prelaunch_7576_listener_count=0;prelaunch_7586_listener_count=0;prelaunch_godot_process_count=0;first_jsonrpc_request_sent=$false;m6_to_m11_execution_count=0;formal_mcp_execution_count=0;authorized_run_count_consumed=0;canonical_payload_sha256=''}
    Write-EvidenceJson (Join-Path $evidence 'execution-start-v3.json') $m1;Write-Milestone M1 PASS '' ([ordered]@{execution_start_sha256=Get-Pr90Sha256 (Join-Path $evidence 'execution-start-v3.json');fixture_head=$fixtureHead;fixture_tree=$fixtureTree})

    $launchScript=Join-Path $tooling 'tools\launch_role_godot_mcp.ps1';$launchReceiptPath=Join-Path $evidence 'launch-receipt-v3.json';$launchOut=Join-Path $evidence 'launcher.stdout.log';$launchErr=Join-Path $evidence 'launcher.stderr.log';$sessionId=[guid]::NewGuid().ToString('N')
    $arguments=@('-NoProfile','-File',$launchScript,'-Role','A','-Port',[string]$Port,'-Worktree',$fixture,'-GodotPath',$godot,'-Renderer','compatibility','-StartupTimeoutSeconds','90','-StartOnly','-LaunchReceiptPath',$launchReceiptPath,'-LaunchSessionId',$sessionId)
    $processCreateRequestUtc=[DateTimeOffset]::UtcNow
    $launcher=Start-Process -FilePath(Join-Path $PSHOME 'pwsh.exe') -ArgumentList $arguments -WorkingDirectory $fixture -WindowStyle Hidden -RedirectStandardOutput $launchOut -RedirectStandardError $launchErr -PassThru
    [void]$taskPids.Add([int]$launcher.Id);$launcherIdentity=Read-EndpointListenerOwnerIdentityV1 $launcher.Id
    $deadline=[DateTimeOffset]::UtcNow.AddSeconds(20)
    while([DateTimeOffset]::UtcNow-lt$deadline-and-not(Test-Path -LiteralPath $launchReceiptPath)){if($launcher.HasExited){break};Start-Sleep -Milliseconds 100}
    if(-not(Test-Path -LiteralPath $launchReceiptPath)){throw 'M2 launch receipt was not persisted.'}
    $launchReceipt=Get-Content -Raw -LiteralPath $launchReceiptPath|ConvertFrom-Json -Depth 30 -DateKind String;$wrapperPid=[int]$launchReceipt.pid;[void]$taskPids.Add($wrapperPid)
    $wrapperIdentity=Read-EndpointListenerOwnerIdentityV1 $wrapperPid
    if(-not[bool]$wrapperIdentity.identity_read_green){throw "M2 wrapper identity failed: $($wrapperIdentity.failure_class)"}
    Write-Milestone M2 PASS '' ([ordered]@{launcher_pid=$launcher.Id;wrapper_pid=$wrapperPid;launch_receipt_sha256=Get-Pr90Sha256 $launchReceiptPath;process_created_after_request=$true})
    $m3Green=([int]$wrapperIdentity.parent_pid-eq[int]$launcher.Id-and(Test-PathBinding $wrapperIdentity.command_line $fixture)-and[string]$wrapperIdentity.executable_path-ieq$godot)
    if(-not$m3Green){throw 'M3 console wrapper identity/lineage verification failed.'}
    Write-Milestone M3 PASS '' ([ordered]@{wrapper_pid=$wrapperPid;wrapper_parent_pid=$wrapperIdentity.parent_pid;launcher_pid=$launcher.Id;fixture_binding=$true;wrapper_creation_filetime=$wrapperIdentity.creation_time_filetime_utc})

    $bound=$false;$boundDeadline=[DateTimeOffset]::UtcNow.AddSeconds(30)
    while([DateTimeOffset]::UtcNow-lt$boundDeadline){$net=Invoke-GetNetTcpListenerObservationV1 -Ports @($Port) -SampleId m4;$stat=Invoke-NetstatTcpListenerObservationV1 -Ports @($Port) -SampleId m4;if(@($net.records).Count-gt0-and@($stat.records).Count-gt0){$bound=$true;break};Start-Sleep -Milliseconds 200}
    if(-not$bound){throw 'M4 endpoint did not bind within 30 seconds.'}
    Write-Milestone M4 PASS '' ([ordered]@{port=$Port;getnet_count=@($net.records).Count;netstat_count=@($stat.records).Count;first_jsonrpc_request_sent=$false})

    $sampleDeadline=[DateTimeOffset]::UtcNow.AddSeconds(10);$sampleIndex=0
    do{
        $sampleIndex+=1;$sampleStarted=[DateTimeOffset]::UtcNow;$sampleId=('stable-{0:d2}'-f$sampleIndex)
        $sourceA=Invoke-GetNetTcpListenerObservationV1 -Ports $protectedPorts -SampleId $sampleId
        $sourceB=Invoke-NetstatTcpListenerObservationV1 -Ports $protectedPorts -SampleId $sampleId
        $pids=@(@($sourceA.records)+@($sourceB.records)|ForEach-Object{[int]$_.owning_pid}|Sort-Object -Unique);$identityByPid=@{}
        foreach($pidValue in $pids){$identityByPid[[string]$pidValue]=Read-EndpointListenerOwnerIdentityV1 $pidValue}
        $sourceA=Add-IdentityToObservation $sourceA $identityByPid;$sourceB=Add-IdentityToObservation $sourceB $identityByPid
        $parity=Compare-EndpointListenerSourceSetsV1 $sourceA $sourceB
        $targetMatches=@($parity.matched_records|Where-Object{[int]$_.source_a_record.local_port-eq$Port})
        $sampleOwner=$null;$chain=@();$ownerKey='';$lineageFingerprint='';$qualified=$false;$guiRole=$false;$descendant=$false;$fixtureMatch=$false;$sessionMatch=$false;$sidMatch=$false;$createdAfter=$false
        if($targetMatches.Count-eq1-and$parity.matched_count-eq1){
            $sampleOwner=$targetMatches[0].source_a_record;$ownerPid=[int]$sampleOwner.owning_pid;$ownerIdentity=$identityByPid[[string]$ownerPid];[void]$taskPids.Add($ownerPid)
            $chain=@(Get-EndpointProcessAncestorChainV1 $ownerPid);$chainPids=@($chain|ForEach-Object{[int]$_.pid});$descendant=$wrapperPid-in$chainPids
            $guiPath=[regex]::Replace($godot,'(?i)_console(?=\.exe$)','');$guiRole=([string]$ownerIdentity.executable_path-ieq$guiPath-and$ownerPid-ne$wrapperPid)
            $fixtureMatch=Test-PathBinding $ownerIdentity.command_line $fixture;$sessionMatch=([int]$ownerIdentity.windows_session_id-eq[int]$wrapperIdentity.windows_session_id);$sidMatch=(-not[string]::IsNullOrWhiteSpace([string]$ownerIdentity.user_sid)-and[string]$ownerIdentity.user_sid-ceq[string]$wrapperIdentity.user_sid)
            $createdAfter=([DateTimeOffset]::Parse([string]$ownerIdentity.creation_time_utc)-ge$processCreateRequestUtc);$ownerKey=Format-EndpointListenerCanonicalKeyV1 $sampleOwner;$lineageFingerprint=Get-Pr90CanonicalSha256 @($chain|ForEach-Object{[ordered]@{pid=$_.pid;parent_pid=if($_.PSObject.Properties.Name-contains'parent_pid'){$_.parent_pid}else{$null};creation=if($_.PSObject.Properties.Name-contains'creation_time_filetime_utc'){$_.creation_time_filetime_utc}else{$null}}})
            $qualified=([bool]$parity.parity-and$targetMatches.Count-eq1-and$parity.matched_count-eq1-and[bool]$ownerIdentity.identity_read_green-and$guiRole-and$descendant-and[int]$ownerIdentity.parent_pid-eq$wrapperPid-and$fixtureMatch-and$sessionMatch-and$sidMatch-and$createdAfter)
        }
        $samples.Add([pscustomobject][ordered]@{sample_index=$sampleIndex;sample_id=$sampleId;observed_utc=$sampleStarted.ToString('o');source_a=$sourceA;source_b=$sourceB;parity=$parity;endpoint_owner_pid=if($null-ne$sampleOwner){$ownerPid}else{$null};endpoint_owner_identity=$ownerIdentity;ancestor_chain=$chain;owner_instance_key=$ownerKey;lineage_fingerprint=$lineageFingerprint;owner_is_gui_engine=$guiRole;owner_descendant_of_wrapper=$descendant;command_line_fixture_match=$fixtureMatch;windows_session_match=$sessionMatch;user_sid_match=$sidMatch;created_after_launch_epoch=$createdAfter;qualified=$qualified})
        if($samples.Count-ge5){$stable=Test-EndpointOwnerStableWindowV1 @($samples);if($stable.green){break}}
        Start-Sleep -Milliseconds 500
    }while([DateTimeOffset]::UtcNow-lt$sampleDeadline)
    $stable=Test-EndpointOwnerStableWindowV1 @($samples);$paritySamples=@($samples|Where-Object{[bool]$_.parity.parity});$ownerPids=@($samples|Where-Object{$null-ne$_.endpoint_owner_pid}|ForEach-Object{[int]$_.endpoint_owner_pid}|Sort-Object -Unique);$ownerKeys=@($samples|Where-Object{-not[string]::IsNullOrWhiteSpace($_.owner_instance_key)}|ForEach-Object{$_.owner_instance_key}|Sort-Object -Unique);$lineageKeys=@($samples|Where-Object{-not[string]::IsNullOrWhiteSpace($_.lineage_fingerprint)}|ForEach-Object{$_.lineage_fingerprint}|Sort-Object -Unique)
    $lastGood=@($samples|Where-Object qualified|Select-Object -Last 1);if($lastGood.Count-eq1){$ownerIdentity=$lastGood[0].endpoint_owner_identity;$ancestorChain=$lastGood[0].ancestor_chain;$ownerPid=[int]$lastGood[0].endpoint_owner_pid}
    $m5Green=($stable.green-and$paritySamples.Count-ge3-and@($samples|Where-Object{-not[bool]$_.parity.parity}).Count-eq0-and$ownerPids.Count-eq1-and$ownerKeys.Count-eq1-and$lineageKeys.Count-eq1-and$null-ne$ownerIdentity-and[bool]$lastGood[0].owner_is_gui_engine-and[bool]$lastGood[0].owner_descendant_of_wrapper-and[bool]$lastGood[0].command_line_fixture_match-and[bool]$lastGood[0].windows_session_match-and[bool]$lastGood[0].user_sid_match-and[bool]$lastGood[0].created_after_launch_epoch)
    $samplesEvidence=[ordered]@{schema='SpaceSyndicatePr90EndpointListenerSamplesV3';probe_id=$probeId;sample_count=$samples.Count;samples=@($samples);first_jsonrpc_request_count=0;endpoint_application_request_count=0;canonical_payload_sha256=''};Write-EvidenceJson (Join-Path $evidence 'endpoint-listener-samples-v3.json') $samplesEvidence
    $parityEvidence=[ordered]@{schema='SpaceSyndicatePr90ListenerSourceParityV3';probe_id=$probeId;observer_source_count=2;sample_count=$samples.Count;parity_sample_count=$paritySamples.Count;disagreement_sample_count=@($samples|Where-Object{-not[bool]$_.parity.parity}).Count;final_a_only_count=if($samples.Count){$samples[-1].parity.a_only_count}else{0};final_b_only_count=if($samples.Count){$samples[-1].parity.b_only_count}else{0};all_samples=@($samples|ForEach-Object{[ordered]@{sample_id=$_.sample_id;parity=$_.parity.parity;matched_count=$_.parity.matched_count;a_only_count=$_.parity.a_only_count;b_only_count=$_.parity.b_only_count;parse_failure_count=$_.parity.source_a_parse_failure_count+$_.parity.source_b_parse_failure_count;duplicate_key_count=$_.parity.duplicate_key_count}});canonical_payload_sha256=''};Write-EvidenceJson (Join-Path $evidence 'listener-source-parity-v3.json') $parityEvidence
    $lineage=[ordered]@{schema='SpaceSyndicatePr90ProcessLineageV3';probe_id=$probeId;controller_process=Read-EndpointListenerOwnerIdentityV1 $PID;launcher_process=$launcherIdentity;console_wrapper=$wrapperIdentity;gui_engine=$ownerIdentity;endpoint_owner=$ownerIdentity;endpoint_owner_ancestor_chain=$ancestorChain;launcher_pid=[int]$launcher.Id;console_wrapper_pid=$wrapperPid;gui_engine_pid=$ownerPid;endpoint_owner_pid=$ownerPid;wrapper_parent_is_launcher=([int]$wrapperIdentity.parent_pid-eq[int]$launcher.Id);gui_parent_is_wrapper=($null-ne$ownerIdentity-and[int]$ownerIdentity.parent_pid-eq$wrapperPid);canonical_payload_sha256=''};Write-EvidenceJson (Join-Path $evidence 'process-lineage-v3.json') $lineage
    $characterization=[ordered]@{schema='SpaceSyndicatePr90EndpointOwnerCharacterizationV3';status=if($m5Green){'PASS'}else{'BLOCKED'};probe_id=$probeId;endpoint_owner_pid=$ownerPid;endpoint_owner_process_role=if($null-ne$ownerIdentity-and$ownerPid-ne$wrapperPid){'GUI_ENGINE'}else{'UNKNOWN'};endpoint_owner_is_gui_engine=if($null-ne$lastGood-and$lastGood.Count){[bool]$lastGood[0].owner_is_gui_engine}else{$false};endpoint_owner_is_console_wrapper=($ownerPid-eq$wrapperPid);endpoint_owner_is_descendant_of_launcher=if($null-ne$lastGood-and$lastGood.Count){[bool]$lastGood[0].owner_descendant_of_wrapper-and[int]$wrapperIdentity.parent_pid-eq[int]$launcher.Id}else{$false};endpoint_owner_command_line_fixture_match=if($lastGood.Count){[bool]$lastGood[0].command_line_fixture_match}else{$false};endpoint_owner_windows_session_match=if($lastGood.Count){[bool]$lastGood[0].windows_session_match}else{$false};endpoint_owner_user_sid_match=if($lastGood.Count){[bool]$lastGood[0].user_sid_match}else{$false};endpoint_owner_created_after_launch_epoch=if($lastGood.Count){[bool]$lastGood[0].created_after_launch_epoch}else{$false};stable_sample_count=$stable.stable_sample_count;stable_window_ms=$stable.stable_window_ms;pid_changed_count=[math]::Max(0,$ownerPids.Count-1);creation_identity_changed_count=[math]::Max(0,$ownerKeys.Count-1);process_lineage_changed_count=[math]::Max(0,$lineageKeys.Count-1);multiple_active_endpoint_owner_count=if($samples.Count){[math]::Max(0,[int]$samples[-1].parity.matched_count-1)}else{0};m5_root_cause_class=if($m5Green){'D'}else{'G'};m5_root_cause_name=if($m5Green){'ENDPOINT_ARCHITECTURE_CONTRACT_DRIFT'}else{'UNRESOLVED'};m5_root_cause_formally_attested=$m5Green;endpoint_ownership_contract_v2_implemented=$false;first_jsonrpc_request_count=0;endpoint_application_request_count=0;m6_to_m11_count=0;formal_mcp_execution_count=0;authorized_run_count_consumed=0;canonical_payload_sha256=''};Write-EvidenceJson (Join-Path $evidence 'endpoint-owner-characterization-v3.json') $characterization
    Write-Milestone M5 (if($m5Green){'PASS'}else{'FAIL'}) (if($m5Green){''}else{'M5_CHARACTERIZATION_GATES_NOT_MET'}) ([ordered]@{characterization_sha256=Get-Pr90Sha256 (Join-Path $evidence 'endpoint-owner-characterization-v3.json');stable_sample_count=$stable.stable_sample_count;stable_window_ms=$stable.stable_window_ms;owner_pid=$ownerPid;root_cause_class=$characterization.m5_root_cause_class})
}catch{
    $characterizationFailure=$_.Exception.Message
    if([string]::IsNullOrWhiteSpace($milestoneFailure)){$milestoneFailure='CHARACTERIZATION_CONTROLLER_EXCEPTION'}
}finally{
    if($ownerPid-gt0){$guiProcess=Get-Process -Id $ownerPid -ErrorAction SilentlyContinue;if($null-ne$guiProcess-and-not$guiProcess.HasExited){try{$normalCloseRequested=$guiProcess.CloseMainWindow()}catch{$normalCloseRequested=$false}}}
    $stopDeadline=[DateTimeOffset]::UtcNow.AddSeconds(20)
    do{$live=@($taskPids|Where-Object{$null-ne(Get-Process -Id $_ -ErrorAction SilentlyContinue)});$listeners=@(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue|Where-Object{[int]$_.LocalPort-in@($Port,$SecondaryPort)});if($live.Count-eq0-and$listeners.Count-eq0){break};Start-Sleep -Milliseconds 200}while([DateTimeOffset]::UtcNow-lt$stopDeadline)
    $liveAfter=@($taskPids|Where-Object{$null-ne(Get-Process -Id $_ -ErrorAction SilentlyContinue)});$listenersAfter=@(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue|Where-Object{[int]$_.LocalPort-in@($Port,$SecondaryPort)});$godotAfter=Get-GodotRows
    $terminal=[ordered]@{schema='SpaceSyndicatePr90M5CharacterizationTerminalV3';probe_id=$probeId;observed_utc=[DateTimeOffset]::UtcNow.ToString('o');task_owned_pids=@($taskPids|Sort-Object);task_owned_process_residual_count=$liveAfter.Count;listeners_after=@($listenersAfter|ForEach-Object{[ordered]@{local_address=[string]$_.LocalAddress;local_port=[int]$_.LocalPort;owner_pid=[int]$_.OwningProcess}});port_7576_count_after=@($listenersAfter|Where-Object{[int]$_.LocalPort-eq$Port}).Count;port_7586_count_after=@($listenersAfter|Where-Object{[int]$_.LocalPort-eq$SecondaryPort}).Count;godot_process_count_after=$godotAfter.Count;normal_close_requested=$normalCloseRequested;forced_stop=$forcedStop;unrelated_process_termination_count=0;stopped_cleanly=($liveAfter.Count-eq0-and$listenersAfter.Count-eq0-and$godotAfter.Count-eq0-and-not$forcedStop);first_jsonrpc_request_count=0;endpoint_application_request_count=0;m6_to_m11_count=0;formal_mcp_execution_count=0;authorized_run_count_consumed=0;canonical_payload_sha256=''}
    try{Write-EvidenceJson (Join-Path $evidence 'terminal-process-port-manifest-v3.json') $terminal}catch{}
}

$requiredEvidence=@('process-lineage-v3.json','endpoint-listener-samples-v3.json','listener-source-parity-v3.json','endpoint-owner-characterization-v3.json','terminal-process-port-manifest-v3.json')
$evidenceComplete=@($requiredEvidence|Where-Object{-not(Test-Path -LiteralPath(Join-Path $evidence $_))}).Count-eq0
$terminal=Get-Content -Raw -LiteralPath (Join-Path $evidence 'terminal-process-port-manifest-v3.json')|ConvertFrom-Json -Depth 100 -DateKind String
$status=if($m5Green-and$evidenceComplete-and[bool]$terminal.stopped_cleanly){'PASS'}else{'BLOCKED'}
$result=[ordered]@{schema='SpaceSyndicatePr90M5EndpointOwnerCharacterizationV3Result';status=$status;probe_id=$probeId;execution_mode='NONFORMAL_PASSIVE_M0_M5_CHARACTERIZATION_ONLY';product_head_sha=$productHead;product_tree_sha=$productTree;tooling_head_sha=if($null-ne$manifest){[string]$manifest.tooling_head_sha}else{''};tooling_tree_sha=if($null-ne$manifest){[string]$manifest.tooling_tree_sha}else{''};fixture_head_sha=$expectedFixtureHead;fixture_tree_sha=$expectedFixtureTree;characterization_probe_execution_count=1;listener_observer_selftest_status=if($null-ne$selftest){[string]$selftest.status}else{'UNKNOWN'};endpoint_listener_observer_source_count=2;endpoint_listener_observer_parity=if($samples.Count){@($samples|Where-Object{-not[bool]$_.parity.parity}).Count-eq0}else{$false};endpoint_listener_a_only_count=if($samples.Count){[int]$samples[-1].parity.a_only_count}else{0};endpoint_listener_b_only_count=if($samples.Count){[int]$samples[-1].parity.b_only_count}else{0};endpoint_owner_stable_sample_count=if($null-ne$stable){[int]$stable.stable_sample_count}else{0};endpoint_owner_stable_window_ms=if($null-ne$stable){[double]$stable.stable_window_ms}else{0};endpoint_owner_pid=if($ownerPid-gt0){$ownerPid}else{$null};endpoint_owner_process_role=if($m5Green){'GUI_ENGINE'}else{'UNKNOWN'};endpoint_owner_is_gui_engine=$m5Green;endpoint_owner_is_descendant_of_launcher=$m5Green;endpoint_owner_command_line_fixture_match=$m5Green;endpoint_owner_windows_session_match=$m5Green;endpoint_owner_user_sid_match=$m5Green;m5_root_cause_class=if($m5Green){'D'}else{'G'};m5_root_cause_formally_attested=$m5Green;characterization_stopped_cleanly=[bool]$terminal.stopped_cleanly;forced_stop=[bool]$terminal.forced_stop;godot_process_count_after=[int]$terminal.godot_process_count_after;port_7576_count_after=[int]$terminal.port_7576_count_after;port_7586_count_after=[int]$terminal.port_7586_count_after;failure_class=if($status-ceq'PASS'){''}else{$milestoneFailure};failure_detail=$characterizationFailure;first_jsonrpc_request_sent=$false;endpoint_application_request_count=0;post_repair_m0_m11_probe_execution_count=0;m6_to_m11_execution_count=0;formal_mcp_execution_count=0;authorized_run_count_consumed=0;exact_sha_mcp_status='NOT_STARTED';ready_for_endpoint_ownership_v2_repair_authorization=($status-ceq'PASS');ready_for_pr90_startup_probe_b=$false;ready_for_new_exact_sha_mcp_authorization=$false;canonical_payload_sha256=''}
$resultPath=Join-Path $root 'pr90_m5_endpoint_owner_characterization_v3_result.json';Write-EvidenceJson $resultPath $result
$md=@"
# PR90 M5 Endpoint Owner Characterization V3

- Status: $status
- Probe: $probeId
- Endpoint owner PID: $ownerPid
- Endpoint owner role: $(if($m5Green){'GUI_ENGINE'}else{'UNKNOWN'})
- Stable samples/window: $($result.endpoint_owner_stable_sample_count) / $($result.endpoint_owner_stable_window_ms) ms
- Root-cause class: $($result.m5_root_cause_class)
- Root cause formally attested: $($result.m5_root_cause_formally_attested)
- JSON-RPC sent: false
- M6-M11 executions: 0
- Formal MCP executions: 0
- Clean stop: $($result.characterization_stopped_cleanly)
"@
$mdPath=Join-Path $root 'pr90_m5_endpoint_owner_characterization_v3_result.md';Write-Pr90ImmutableText -Path $mdPath -Text $md -WriteSha256Sidecar|Out-Null
$boundEvidence=@();foreach($name in $requiredEvidence){$path=Join-Path $evidence $name;if(Test-Path -LiteralPath $path){$boundEvidence+=[ordered]@{name=$name;path=$path;sha256=Get-Pr90Sha256 $path;bytes=[int64](Get-Item -LiteralPath $path).Length}}}
$attestation=[ordered]@{schema='SpaceSyndicatePr90M5EndpointOwnerCharacterizationV3Attestation';status=if($status-ceq'PASS'){'SEALED'}else{'BLOCKED_EVIDENCE_SEALED'};probe_id=$probeId;product_head_sha=$productHead;product_tree_sha=$productTree;tooling_head_sha=$result.tooling_head_sha;tooling_tree_sha=$result.tooling_tree_sha;tooling_manifest_sha256=Get-Pr90Sha256 $manifestPath;tooling_seal_sha256=Get-Pr90Sha256 $sealPath;selftest_sha256=Get-Pr90Sha256 $selfTestPath;tooling_files=if($null-ne$manifest){$manifest.tooling_files}else{@()};bound_evidence=$boundEvidence;result_path=$resultPath;result_sha256=Get-Pr90Sha256 $resultPath;markdown_path=$mdPath;markdown_sha256=Get-Pr90Sha256 $mdPath;terminal_manifest_sha256=Get-Pr90Sha256 (Join-Path $evidence 'terminal-process-port-manifest-v3.json');characterization_attestation_sealed=($status-ceq'PASS');characterization_tooling_bytes_changed_after_seal=$false;endpoint_ownership_contract_v2_implemented=$false;post_repair_m0_m11_probe_execution_count=0;first_jsonrpc_request_sent=$false;endpoint_application_request_count=0;m6_to_m11_execution_count=0;formal_mcp_execution_count=0;authorized_run_count_consumed=0;canonical_payload_sha256=''}
$attestationPath=Join-Path $root 'pr90_m5_endpoint_owner_characterization_v3_attestation.json';Write-EvidenceJson $attestationPath $attestation
$result|ConvertTo-Json -Depth 100 -Compress
if($status-cne'PASS'){exit 2}
