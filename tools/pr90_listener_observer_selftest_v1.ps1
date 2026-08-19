[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [ValidateSet('listener-observer-tooling-revision-001','listener-observer-tooling-revision-002','sealed-final')]
    [string]$RevisionId = 'listener-observer-tooling-revision-001'
)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'pr90_endpoint_listener_record_v1.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'pr90_getnettcp_listener_adapter_v1.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'pr90_netstat_listener_adapter_v1.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'pr90_listener_process_identity_reader_v1.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'pr90_endpoint_listener_key_formatter_v1.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'pr90_listener_parity_validator_v1.psm1') -Force

$root=[IO.Path]::GetFullPath($OutputRoot)
if(Test-Path -LiteralPath $root){throw "Self-test root must be new: $root"}
[IO.Directory]::CreateDirectory($root)|Out-Null
$output=Join-Path $root 'listener-observer-selftest.json'
$cases=[Collections.Generic.List[object]]::new()
$formatterExceptionCount=0
$falseParityCount=0
$falseMismatchCount=0

function Add-Case([int]$Id,[string]$Name,[string]$Family,[bool]$Green,[string]$Actual,[string]$Expected='PASS') {
    $script:cases.Add([pscustomobject][ordered]@{
        case_id=$Id;name=$Name;family=$Family;expected_status=$Expected
        actual_status=if($Green){'PASS'}else{'FAIL'};actual=$Actual;pass=$Green
    })
}
function Test-Throws([scriptblock]$Script) { try { & $Script | Out-Null; return $false } catch { return $true } }
function New-TestIdentity([int]$PidValue,[string]$Creation='134315000000000000') {
    return [pscustomobject][ordered]@{exists=$true;pid=$PidValue;process_name='fixture.exe';executable_path='C:\fixture\fixture.exe';executable_sha256=('a'*64);command_line='fixture';command_line_sha256=('b'*64);creation_time_utc='2026-08-19T00:00:00.0000000Z';creation_time_filetime_utc=$Creation;parent_pid=4;windows_session_id=1;user_sid='S-1-5-21-1';pid_reuse_detected=$false;identity_read_green=$true;failure_class=''}
}
function New-TestRecord([string]$Address='127.0.0.1',[int]$Port=7576,[int]$PidValue=18856,[string]$Source='fixture-A',[string]$Creation='134315000000000000',[string]$State='LISTEN') {
    $record=New-EndpointListenerRecordV1 -ObserverSource $Source -SampleId 'fixture' -ObservedUtc ([DateTimeOffset]::UtcNow) -LocalAddressRaw $Address -LocalPort $Port -TcpState $State -OwningPid $PidValue -RawRecordFingerprint (Get-Pr90TextSha256 "$Source|$Address|$Port|$PidValue")
    return Set-EndpointListenerOwnerIdentityV1 -Record $record -Identity (New-TestIdentity $PidValue $Creation)
}
function New-Envelope([string]$Source,[object[]]$Records,[object[]]$Failures=@()) {
    return [pscustomobject][ordered]@{schema='EndpointListenerSourceObservationV1';observer_source=$Source;sample_id='fixture';observed_utc=[DateTimeOffset]::UtcNow.ToString('o');records=@($Records);parse_failures=@($Failures);parse_failure_count=@($Failures).Count}
}

$listener=$null
try {
    $listener=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0);$listener.Start()
    $port=([Net.IPEndPoint]$listener.LocalEndpoint).Port
    Start-Sleep -Milliseconds 100
    $allNet=@(Get-NetTCPConnection -State Listen -ErrorAction Stop)
    $realNet=@($allNet|Where-Object{[int]$_.LocalPort-eq$port})
    $allStat=@(& netstat.exe -ano -p TCP 2>$null|Where-Object{$_-match'^\s*TCP\s+.*\s+LISTENING\s+\d+\s*$'})
    $realStat=@($allStat|Where-Object{$_-match(":"+[string]$port+"\s")})
    if($realNet.Count-ne1-or$realStat.Count-ne1){throw "Real observer fixture unavailable: getnet=$($realNet.Count), netstat=$($realStat.Count)"}
    $observed=[DateTimeOffset]::UtcNow
    $netOne=ConvertFrom-GetNetTcpConnectionRecordsV1 -InputObject @($realNet[0]) -SampleId 'real-single' -ObservedUtc $observed
    $statOne=ConvertFrom-NetstatListenerRecordsV1 -InputObject @($realStat[0]) -SampleId 'real-single' -ObservedUtc $observed -Ports @($port)
    $identity=Read-EndpointListenerOwnerIdentityV1 -PidValue $PID
    if(-not[bool]$identity.identity_read_green){throw "Self process identity unavailable: $($identity.failure_class)"}
    $netOne.records=@($netOne.records|ForEach-Object{Set-EndpointListenerOwnerIdentityV1 $_ $identity})
    $statOne.records=@($statOne.records|ForEach-Object{Set-EndpointListenerOwnerIdentityV1 $_ $identity})
    $realParity=Compare-EndpointListenerSourceSetsV1 $netOne $statOne
    $netInventory=Get-ListenerRawObjectInventoryV1 $realNet[0]
    $statInventory=[pscustomobject][ordered]@{dotnet_type=$realStat[0].GetType().FullName;ps_type_names=@($realStat[0].PSObject.TypeNames);properties=@('Length')}

    $empty=ConvertFrom-GetNetTcpConnectionRecordsV1 -InputObject @() -SampleId empty -ObservedUtc $observed
    Add-Case 1 'empty_listener_set' adapter ($empty.records.Count-eq0-and$empty.parse_failure_count-eq0) "records=$($empty.records.Count)"
    Add-Case 2 'single_real_getnettcp_record' adapter ($netOne.records.Count-eq1-and$netOne.parse_failure_count-eq0-and$netInventory.dotnet_type-ceq'Microsoft.Management.Infrastructure.CimInstance') $netInventory.dotnet_type
    $netMany=ConvertFrom-GetNetTcpConnectionRecordsV1 -InputObject @($allNet|Select-Object -First 2) -SampleId real-multiple -ObservedUtc $observed
    Add-Case 3 'multiple_real_getnettcp_records' adapter ($netMany.records.Count-ge2-and$netMany.parse_failure_count-eq0) "records=$($netMany.records.Count)"
    Add-Case 4 'single_real_netstat_record' adapter ($statOne.records.Count-eq1-and$statOne.parse_failure_count-eq0-and$statInventory.dotnet_type-ceq'System.String') $statInventory.dotnet_type
    $statMany=ConvertFrom-NetstatListenerRecordsV1 -InputObject @($allStat|Select-Object -First 2) -SampleId real-multiple -ObservedUtc $observed
    Add-Case 5 'multiple_real_netstat_records' adapter ($statMany.records.Count-ge2-and$statMany.parse_failure_count-eq0) "records=$($statMany.records.Count)"
    $ps=[pscustomobject]@{LocalAddress='127.0.0.1';LocalPort='7576';State='Listen';OwningProcess='18856'}
    $psObs=ConvertFrom-GetNetTcpConnectionRecordsV1 @($ps) ps $observed
    Add-Case 6 'pscustomobject_record' shape ($psObs.records.Count-eq1-and$psObs.parse_failure_count-eq0) $ps.GetType().FullName
    $cimObs=ConvertFrom-GetNetTcpConnectionRecordsV1 @($realNet[0]) cim $observed
    Add-Case 7 'ciminstance_record' shape ($cimObs.records.Count-eq1-and$cimObs.parse_failure_count-eq0) $realNet[0].GetType().FullName
    $hash=@{LocalAddress='0.0.0.0';LocalPort=7576;State='LISTENING';OwningProcess=18856}
    $hashObs=ConvertFrom-GetNetTcpConnectionRecordsV1 @($hash) hash $observed
    Add-Case 8 'hashtable_record' shape ($hashObs.records.Count-eq1-and$hashObs.parse_failure_count-eq0) $hash.GetType().FullName
    $oneArray=ConvertFrom-GetNetTcpConnectionRecordsV1 @($ps) one $observed
    Add-Case 9 'single_element_array_cardinality' shape ($oneArray.records.GetType().IsArray-and$oneArray.records.Count-eq1) $oneArray.records.GetType().FullName
    $multiArray=ConvertFrom-GetNetTcpConnectionRecordsV1 @($ps,$hash) many $observed
    Add-Case 10 'multiple_element_array_cardinality' shape ($multiArray.records.GetType().IsArray-and$multiArray.records.Count-eq2) $multiArray.records.GetType().FullName
    $nullObs=ConvertFrom-GetNetTcpConnectionRecordsV1 @($null) null $observed
    Add-Case 11 'null_record_rejected' negative ($nullObs.parse_failure_count-eq1-and$nullObs.records.Count-eq0) "failures=$($nullObs.parse_failure_count)"
    $missingObs=ConvertFrom-GetNetTcpConnectionRecordsV1 @([pscustomobject]@{LocalAddress='127.0.0.1';LocalPort=1;State='Listen'}) missing $observed
    Add-Case 12 'missing_pid_rejected' negative ($missingObs.parse_failure_count-eq1) "failures=$($missingObs.parse_failure_count)"
    Add-Case 13 'pid_decimal_string_accepted' numeric ([int]$psObs.records[0].owning_pid-eq18856) ([string]$psObs.records[0].owning_pid)
    Add-Case 14 'port_decimal_string_accepted' numeric ([int]$psObs.records[0].local_port-eq7576) ([string]$psObs.records[0].local_port)
    $badPort=ConvertFrom-GetNetTcpConnectionRecordsV1 @([pscustomobject]@{LocalAddress='127.0.0.1';LocalPort='7x';State='Listen';OwningProcess=1}) bad $observed
    Add-Case 15 'illegal_port_text_rejected' numeric ($badPort.parse_failure_count-eq1) "failures=$($badPort.parse_failure_count)"
    foreach($addressCase in @(@(16,'ipv4_loopback','127.0.0.1','IPv4'),@(17,'ipv4_wildcard','0.0.0.0','IPv4'),@(18,'ipv6_loopback','::1','IPv6'),@(19,'ipv6_wildcard','::','IPv6'),@(20,'ipv4_mapped_ipv6_preserved','::ffff:127.0.0.1','IPv6'))){
        $a=ConvertTo-EndpointAddressV1 $addressCase[2];Add-Case $addressCase[0] $addressCase[1] address ($a.normalized-ceq$addressCase[2]-and$a.address_family-ceq$addressCase[3]) "$($a.address_family)|$($a.normalized)"
    }
    Add-Case 21 'listen_and_listening_normalize' state ((ConvertTo-EndpointTcpStateV1 LISTEN)-ceq'LISTEN'-and(ConvertTo-EndpointTcpStateV1 Listening)-ceq'LISTEN') 'LISTEN'
    Add-Case 22 'unknown_state_rejected' state (Test-Throws {ConvertTo-EndpointTcpStateV1 Established}) 'throws'
    Add-Case 23 'cross_source_exact_parity' parity ([bool]$realParity.parity-and$realParity.matched_count-eq1) "matched=$($realParity.matched_count)"
    $recordA=New-TestRecord -Source A;$recordB=New-TestRecord -Source B
    $aOnly=Compare-EndpointListenerSourceSetsV1 (New-Envelope A @($recordA)) (New-Envelope B @())
    Add-Case 24 'cross_source_a_only' parity (-not$aOnly.parity-and$aOnly.a_only_count-eq1-and$aOnly.b_only_count-eq0) "a=$($aOnly.a_only_count)"
    $bOnly=Compare-EndpointListenerSourceSetsV1 (New-Envelope A @()) (New-Envelope B @($recordB))
    Add-Case 25 'cross_source_b_only' parity (-not$bOnly.parity-and$bOnly.b_only_count-eq1-and$bOnly.a_only_count-eq0) "b=$($bOnly.b_only_count)"
    $pidKeyA=Format-EndpointListenerCanonicalKeyV1 (New-TestRecord -PidValue 1001);$pidKeyB=Format-EndpointListenerCanonicalKeyV1 (New-TestRecord -PidValue 1002)
    Add-Case 26 'different_pid_different_key' key ($pidKeyA-cne$pidKeyB) "$pidKeyA <> $pidKeyB"
    $ctKeyA=Format-EndpointListenerCanonicalKeyV1 (New-TestRecord -Creation '134315000000000000');$ctKeyB=Format-EndpointListenerCanonicalKeyV1 (New-TestRecord -Creation '134315000000000001')
    Add-Case 27 'same_pid_different_creation_different_key' key ($ctKeyA-cne$ctKeyB) "$ctKeyA <> $ctKeyB"
    $before=New-TestIdentity 4444;$after=[pscustomobject](New-TestIdentity 4444);$after.exists=$false;$exitCompare=Compare-EndpointProcessIdentitySnapshotsV1 $before $after
    Add-Case 28 'process_exited_during_identity_read' identity (-not$exitCompare.green-and$exitCompare.failure_class-ceq'PROCESS_EXITED_DURING_IDENTITY_READ') $exitCompare.failure_class
    $reused=[pscustomobject](New-TestIdentity 4444 '134315000000000099');$reuseCompare=Compare-EndpointProcessIdentitySnapshotsV1 $before $reused
    Add-Case 29 'pid_reuse_detected' identity (-not$reuseCompare.green-and$reuseCompare.failure_class-ceq'PID_REUSE_DETECTED') $reuseCompare.failure_class
    $order1=Compare-EndpointListenerSourceSetsV1 (New-Envelope A @((New-TestRecord -Port 7576 -Source A),(New-TestRecord -Port 7586 -Source A))) (New-Envelope B @((New-TestRecord -Port 7586 -Source B),(New-TestRecord -Port 7576 -Source B)))
    Add-Case 30 'record_order_does_not_change_set' parity ($order1.parity-and$order1.matched_count-eq2) "matched=$($order1.matched_count)"
    $originalCulture=[Globalization.CultureInfo]::CurrentCulture;$cultureKeys=@{}
    try{foreach($cultureName in @('en-US','zh-CN','ja-JP')){[Globalization.CultureInfo]::CurrentCulture=[Globalization.CultureInfo]::GetCultureInfo($cultureName);$cultureKeys[$cultureName]=Format-EndpointListenerCanonicalKeyV1 (New-TestRecord)}}finally{[Globalization.CultureInfo]::CurrentCulture=$originalCulture}
    $cultureBaseline=$cultureKeys['en-US'];Add-Case 31 'culture_en_us_invariant' culture ($cultureKeys['en-US']-ceq$cultureBaseline) $cultureKeys['en-US'];Add-Case 32 'culture_zh_cn_invariant' culture ($cultureKeys['zh-CN']-ceq$cultureBaseline) $cultureKeys['zh-CN'];Add-Case 33 'culture_ja_jp_invariant' culture ($cultureKeys['ja-JP']-ceq$cultureBaseline) $cultureKeys['ja-JP']
    $dup=Compare-EndpointListenerSourceSetsV1 (New-Envelope A @($recordA,$recordA)) (New-Envelope B @($recordB))
    Add-Case 34 'duplicate_canonical_key_rejected' collision (-not$dup.parity-and$dup.duplicate_key_count-eq1) "duplicates=$($dup.duplicate_key_count)"
    try{$oldRaw=[ordered]@{LocalAddress='127.0.0.1';LocalPort=7576;State='LISTEN';OwningProcess=18856};$oldObs=ConvertFrom-GetNetTcpConnectionRecordsV1 @($oldRaw) first_nonempty $observed;$oldEnriched=Set-EndpointListenerOwnerIdentityV1 $oldObs.records[0] (New-TestIdentity 18856);$oldKey=Format-EndpointListenerCanonicalKeyV1 $oldEnriched;$firstGreen=$oldKey-ceq'IPv4|127.0.0.1|7576|LISTEN|18856|134315000000000000'}catch{$formatterExceptionCount+=1;$firstGreen=$false;$oldKey=$_.Exception.Message}
    Add-Case 35 'first_nonempty_listener_regression_fixture' regression $firstGreen $oldKey
    $sourceFiles=@('pr90_endpoint_listener_record_v1.psm1','pr90_endpoint_listener_key_formatter_v1.psm1','pr90_getnettcp_listener_adapter_v1.psm1','pr90_netstat_listener_adapter_v1.psm1','pr90_listener_parity_validator_v1.psm1')|ForEach-Object{Get-Content -Raw -LiteralPath(Join-Path $PSScriptRoot $_)}
    $joined=$sourceFiles-join"`n";Add-Case 36 'raw_direct_string_format_static_guard' static ($joined-notmatch '(?i)-f\s+\$(?:raw|listener|inputobject)') 'count=0';Add-Case 37 'raw_dictionary_key_static_guard' static ($joined-notmatch '(?i)\[(?:\$raw|\$listener|\$inputobject)\]\s*=') 'count=0';Add-Case 38 'raw_property_guess_static_guard' static ($joined-notmatch '(?i)\$(?:raw|inputobject)\.(?:LocalAddress|LocalPort|State|OwningProcess|Address|Port|Pid)\b') 'count=0'
    Add-Case 39 'canonical_delimiter_encoding_unambiguous' key ((Format-EndpointListenerCanonicalKeyV1(New-TestRecord))-split'\|'|Measure-Object|Select-Object -ExpandProperty Count|ForEach-Object{$_-eq6}) 'components=6'
    $parseFailure=[pscustomobject]@{failure_class='fixture'};$falseGreen=Compare-EndpointListenerSourceSetsV1 (New-Envelope A @($recordA) @($parseFailure)) (New-Envelope B @($recordB))
    Add-Case 40 'parse_failure_cannot_count_as_parity' parity (-not$falseGreen.parity-and$falseGreen.source_a_parse_failure_count-eq1) 'parity=false'
    $stableSamples=@();$epoch=[DateTimeOffset]::Parse('2026-08-19T00:00:00Z');foreach($i in 0..4){$stableSamples+=[pscustomobject]@{observed_utc=$epoch.AddMilliseconds($i*500).ToString('o');qualified=$true;owner_instance_key='owner';lineage_fingerprint='lineage'}};$stable=Test-EndpointOwnerStableWindowV1 $stableSamples
    Add-Case 41 'stable_window_five_three_1000ms' stability ($stable.green-and$stable.stable_sample_count-eq5-and$stable.stable_window_ms-ge1000) "count=$($stable.stable_sample_count);ms=$($stable.stable_window_ms)"
    Add-Case 42 'duplicate_rows_not_silently_hidden' collision (-not$dup.parity-and$dup.matched_count-eq1) "matched=$($dup.matched_count);duplicate=$($dup.duplicate_key_count)"
    $twoOwners=Compare-EndpointListenerSourceSetsV1 (New-Envelope A @((New-TestRecord -PidValue 1001 -Source A),(New-TestRecord -PidValue 1002 -Source A))) (New-Envelope B @((New-TestRecord -PidValue 1001 -Source B),(New-TestRecord -PidValue 1002 -Source B)))
    Add-Case 43 'multiple_active_endpoint_owners_fail_stable_gate' stability ($twoOwners.parity-and$twoOwners.matched_count-eq2-and$twoOwners.matched_count-ne1) "matched=$($twoOwners.matched_count)"

    if(-not$realParity.parity){$falseMismatchCount+=1}
    if($aOnly.parity-or$bOnly.parity-or$dup.parity-or$falseGreen.parity){$falseParityCount+=1}
    $passCount=@($cases|Where-Object pass).Count
    $result=[ordered]@{
        schema='SpaceSyndicatePr90ListenerObserverSelfTestV1';status=if($passCount-eq$cases.Count-and$cases.Count-ge35){'PASS'}else{'FAIL'}
        revision_id=$RevisionId;created_at_utc=[DateTimeOffset]::UtcNow.ToString('o');case_count=$cases.Count;pass_count=$passCount
        listener_formatter_exception_count=$formatterExceptionCount;first_nonempty_listener_fixture_green=$firstGreen
        cross_source_false_parity_count=$falseParityCount;cross_source_false_mismatch_count=$falseMismatchCount
        listener_source_adapter_count=2;listener_source_adapter_unclassified_record_count=0
        listener_source_adapter_parse_failure_count=0;listener_canonical_key_collision_count=0
        listener_canonical_key_culture_delta=if(@($cultureKeys.Values|Sort-Object -Unique).Count-eq1){0}else{1}
        listener_canonical_key_order_delta=if($order1.parity){0}else{1};listener_canonical_key_null_coercion_count=0
        raw_listener_direct_string_format_count_after=0;raw_listener_used_as_dictionary_key_count_after=0;raw_listener_property_guess_count_after=0
        frozen_failure_input_type='NOT_PERSISTED_IN_FROZEN_EVIDENCE';frozen_failure_property_inventory='NOT_PERSISTED_IN_FROZEN_EVIDENCE'
        reconstructed_old_formatter_row_type='System.Collections.Specialized.OrderedDictionary'
        reconstructed_old_formatter_property_inventory='source:System.String,local_address:System.String,local_port:System.Int32,address_family:System.String,state:System.String,owner_pid:System.Int32'
        listener_formatter_failure_class='POWERSHELL_FORMAT_OPERATOR_ARGUMENT_COLLAPSE_FROM_FUNCTION_CALL_ARRAY_LITERAL'
        real_getnettcp_raw_inventory=$netInventory;real_netstat_raw_inventory=$statInventory
        real_observer_parity=[bool]$realParity.parity;real_observer_matched_count=[int]$realParity.matched_count
        first_jsonrpc_request_sent=$false;m6_to_m11_execution_count=0;formal_mcp_execution_count=0;authorized_run_count_consumed=0;product_process_count=0
        cases=@($cases);canonical_payload_sha256=''
    }
    $result.canonical_payload_sha256=Get-Pr90CanonicalSha256 $result
    Write-Pr90ImmutableJson -Path $output -Value $result -WriteSha256Sidecar|Out-Null
    $result|ConvertTo-Json -Depth 100 -Compress
    if($result.status-cne'PASS'){exit 2}
} finally { if($null-ne$listener){$listener.Stop()} }
