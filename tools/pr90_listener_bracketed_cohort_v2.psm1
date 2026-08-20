Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'pr90_getnettcp_listener_adapter_v1.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'pr90_netstat_listener_adapter_v1.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'pr90_endpoint_listener_core_v2.psm1') -Force

function New-Pr90ObserverFailureObservationV2 {
    param([string]$Source,[string]$SampleId,[string]$FailureClass,[string]$Detail,[string]$StartedUtc,[string]$CompletedUtc)
    return [pscustomobject][ordered]@{
        schema='EndpointListenerSourceObservationV1';observer_source=$Source;sample_id=$SampleId;observed_utc=$StartedUtc;
        observer_started_utc=$StartedUtc;observer_completed_utc=$CompletedUtc;raw_record_count=0;raw_records=@();raw_evidence_preserved=$true;
        ignored_target_non_listener_count=0;ignored_target_non_listener_records=@();protected_port_unknown_state_count=0;records=@();
        parse_failures=@([pscustomobject][ordered]@{source=$Source;failure_class=$FailureClass;detail=$Detail});parse_failure_count=1
    }
}

function Invoke-Pr90BoundedObserverV2 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][ValidateSet('A','B')][string]$ObserverKind,
        [Parameter(Mandatory=$true)][int[]]$Ports,
        [Parameter(Mandatory=$true)][string]$SampleId,
        [ValidateRange(1,10000)][int]$TimeoutMs=1000,
        [scriptblock]$ObserverScript
    )
    $started=[DateTimeOffset]::UtcNow
    if($null-eq$ObserverScript){
        $modulePath=if($ObserverKind-ceq'A'){Join-Path $PSScriptRoot 'pr90_getnettcp_listener_adapter_v1.psm1'}else{Join-Path $PSScriptRoot 'pr90_netstat_listener_adapter_v1.psm1'}
        $functionName=if($ObserverKind-ceq'A'){'Invoke-GetNetTcpListenerObservationV1'}else{'Invoke-NetstatTcpListenerObservationV1'}
        $ObserverScript={param($module,$function,$p,$id) Import-Module $module -Force -ErrorAction Stop;&$function -Ports $p -SampleId $id}
        $arguments=@($modulePath,$functionName,$Ports,$SampleId)
    }else{$arguments=@($Ports,$SampleId)}
    $shell=[powershell]::Create()
    try{
        $null=$shell.AddScript($ObserverScript.ToString())
        foreach($argument in $arguments){$null=$shell.AddArgument($argument)}
        $async=$shell.BeginInvoke()
        if(-not$async.AsyncWaitHandle.WaitOne($TimeoutMs)){
            $shell.Stop()
            return [pscustomobject][ordered]@{timed_out=$true;elapsed_ms=[math]::Round(([DateTimeOffset]::UtcNow-$started).TotalMilliseconds,3);observation=(New-Pr90ObserverFailureObservationV2 -Source $ObserverKind -SampleId $SampleId -FailureClass 'OBSERVER_TIMEOUT' -Detail "Observer exceeded $TimeoutMs ms." -StartedUtc $started.ToString('o') -CompletedUtc ([DateTimeOffset]::UtcNow.ToString('o')))}
        }
        $output=@($shell.EndInvoke($async))
        if($shell.HadErrors-or$output.Count-ne1){
            $detail=if($shell.Streams.Error.Count-gt0){[string]$shell.Streams.Error[0]}else{"Observer returned $($output.Count) results."}
            return [pscustomobject][ordered]@{timed_out=$false;elapsed_ms=[math]::Round(([DateTimeOffset]::UtcNow-$started).TotalMilliseconds,3);observation=(New-Pr90ObserverFailureObservationV2 -Source $ObserverKind -SampleId $SampleId -FailureClass 'OBSERVER_EXECUTION_FAILED' -Detail $detail -StartedUtc $started.ToString('o') -CompletedUtc ([DateTimeOffset]::UtcNow.ToString('o')))}
        }
        return [pscustomobject][ordered]@{timed_out=$false;elapsed_ms=[math]::Round(([DateTimeOffset]::UtcNow-$started).TotalMilliseconds,3);observation=$output[0]}
    }finally{
        if($null-ne$shell){$shell.Dispose()}
    }
}

function Invoke-Pr90BracketedListenerCohortV2 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][int[]]$Ports,
        [Parameter(Mandatory=$true)][string]$CohortId,
        [ValidateRange(1,10000)][int]$ObserverTimeoutMs=1000,
        [scriptblock]$ObserverA,
        [scriptblock]$ObserverB
    )
    $started=[DateTimeOffset]::UtcNow
    $aBeforeRun=Invoke-Pr90BoundedObserverV2 -ObserverKind A -Ports $Ports -SampleId "$CohortId-a-before" -TimeoutMs $ObserverTimeoutMs -ObserverScript $ObserverA
    $bRun=Invoke-Pr90BoundedObserverV2 -ObserverKind B -Ports $Ports -SampleId "$CohortId-b" -TimeoutMs $ObserverTimeoutMs -ObserverScript $ObserverB
    $aAfterRun=Invoke-Pr90BoundedObserverV2 -ObserverKind A -Ports $Ports -SampleId "$CohortId-a-after" -TimeoutMs $ObserverTimeoutMs -ObserverScript $ObserverA
    $aBefore=$aBeforeRun.observation;$b=$bRun.observation;$aAfter=$aAfterRun.observation
    $aBeforeElapsed=[double]$aBeforeRun.elapsed_ms;$bElapsed=[double]$bRun.elapsed_ms;$aAfterElapsed=[double]$aAfterRun.elapsed_ms
    $aBracket=Compare-EndpointListenerCoreSetsV2 -SourceA $aBefore -SourceB $aAfter
    $sourceParity=if([bool]$aBracket.core_parity){Compare-EndpointListenerCoreSetsV2 -SourceA $aBefore -SourceB $b}else{$null}
    $timeoutCount=@(@($aBeforeRun,$bRun,$aAfterRun)|Where-Object{[bool]$_.timed_out}).Count
    $stable=[bool]$aBracket.core_parity-and$timeoutCount-eq0
    $parity=$stable-and$null-ne$sourceParity-and[bool]$sourceParity.core_parity
    return [pscustomobject][ordered]@{
        schema='Pr90BracketedListenerCohortV2';cohort_id=$CohortId;cohort_started_utc=$started.ToString('o');cohort_completed_utc=[DateTimeOffset]::UtcNow.ToString('o');
        observer_timeout_ms=$ObserverTimeoutMs;observer_timeout_count=$timeoutCount;observer_elapsed_ms=[ordered]@{a_before=[math]::Round($aBeforeElapsed,3);b=[math]::Round($bElapsed,3);a_after=[math]::Round($aAfterElapsed,3)};
        a_before=$aBefore;source_b=$b;a_after=$aAfter;a_before_after_parity=$aBracket;source_parity=$sourceParity;stable_cohort=$stable;stable_parity=$parity;
        classification=if($timeoutCount-gt0){'OBSERVER_TIMEOUT'}elseif(-not[bool]$aBracket.core_parity){'UNSTABLE_COHORT'}elseif($parity){'STABLE_PARITY'}else{'STABLE_SOURCE_DISAGREEMENT'};
        matched_listener_process_enrichment_count=0;duplicate_source_process_enrichment_count=0;owner_proof=$null
    }
}

function Test-Pr90BracketedCohortWindowV2 {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][AllowEmptyCollection()][object[]]$Cohorts,[int]$RequiredAttempts=5,[int]$RequiredConsecutive=5,[int]$RequiredWindowMs=1000)
    $current=[Collections.Generic.List[object]]::new();$best=[Collections.Generic.List[object]]::new();$bestSpan=0.0
    foreach($cohort in @($Cohorts)){
        $qualified=[bool]$cohort.stable_parity
        if(-not$qualified){$current.Clear();continue}
        $current.Add($cohort)
        $span=if($current.Count-gt1){([DateTimeOffset]$current[-1].cohort_completed_utc-[DateTimeOffset]$current[0].cohort_completed_utc).TotalMilliseconds}else{0}
        if($current.Count-gt$best.Count-or($current.Count-eq$best.Count-and$span-gt$bestSpan)){$best=[Collections.Generic.List[object]]::new();foreach($row in $current){$best.Add($row)};$bestSpan=$span}
    }
    return [pscustomobject][ordered]@{green=(@($Cohorts).Count-ge$RequiredAttempts-and$best.Count-ge$RequiredConsecutive-and$bestSpan-ge$RequiredWindowMs);total_attempt_count=@($Cohorts).Count;consecutive_stable_parity_cohort_count=$best.Count;stable_parity_window_ms=[math]::Round($bestSpan,3);unstable_cohort_count=@($Cohorts|Where-Object{$_.classification-ceq'UNSTABLE_COHORT'}).Count;source_disagreement_count=@($Cohorts|Where-Object{$_.classification-ceq'STABLE_SOURCE_DISAGREEMENT'}).Count;observer_timeout_count=@($Cohorts|ForEach-Object{$_.observer_timeout_count}|Measure-Object -Sum).Sum}
}

Export-ModuleMember -Function 'Invoke-Pr90BracketedListenerCohortV2','Test-Pr90BracketedCohortWindowV2'
