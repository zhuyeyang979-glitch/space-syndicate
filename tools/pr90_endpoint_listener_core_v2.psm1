Set-StrictMode -Version Latest

function Get-Pr90ListenerPropertyV2 {
    param([Parameter(Mandatory=$true)][object]$InputObject,[Parameter(Mandatory=$true)][string]$Name)
    $property=$InputObject.PSObject.Properties[$Name]
    if($null-eq$property){throw "Listener record is missing required property: $Name"}
    return $property.Value
}

function ConvertTo-EndpointListenerCoreV2 {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][object]$Record)
    $family=[string](Get-Pr90ListenerPropertyV2 $Record 'address_family')
    $address=[string](Get-Pr90ListenerPropertyV2 $Record 'local_address_normalized')
    $port=[int](Get-Pr90ListenerPropertyV2 $Record 'local_port')
    $state=([string](Get-Pr90ListenerPropertyV2 $Record 'tcp_state')).Trim().ToUpperInvariant()
    $pid=[int](Get-Pr90ListenerPropertyV2 $Record 'owning_pid')
    if($family -notin @('IPv4','IPv6')){throw "Unknown listener address family: $family"}
    if([string]::IsNullOrWhiteSpace($address)){throw 'Normalized listener address is empty.'}
    if($port-lt1-or$port-gt65535){throw "Invalid listener port: $port"}
    if($state -in @('LISTENING')){$state='LISTEN'}
    if($state-cne'LISTEN'){throw "Unknown listener core TCP state: $state"}
    if($pid-lt1){throw "Invalid listener owning PID: $pid"}
    return [pscustomobject][ordered]@{
        schema='EndpointListenerCoreV2';address_family=$family;local_address_normalized=$address;local_port=$port;
        tcp_state_canonical=$state;owning_pid=$pid
    }
}

function Format-EndpointListenerCoreKeyV2 {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][object]$Core)
    return '{0}|{1}|{2}|{3}|{4}' -f ([string]$Core.address_family),([string]$Core.local_address_normalized),([int]$Core.local_port),([string]$Core.tcp_state_canonical),([int]$Core.owning_pid)
}

function Compare-EndpointListenerCoreSetsV2 {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][object]$SourceA,[Parameter(Mandatory=$true)][object]$SourceB)
    $aMap=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    $bMap=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    $duplicates=[Collections.Generic.List[object]]::new()
    foreach($entry in @(@{name='A';source=$SourceA;map=$aMap},@{name='B';source=$SourceB;map=$bMap})){
        foreach($record in @($entry.source.records)){
            try{$core=ConvertTo-EndpointListenerCoreV2 $record;$key=Format-EndpointListenerCoreKeyV2 $core}catch{$duplicates.Add([pscustomobject]@{source=$entry.name;key=$null;failure_class='LISTENER_CORE_BUILD_FAILED';detail=$_.Exception.Message});continue}
            if($entry.map.ContainsKey($key)){$duplicates.Add([pscustomobject]@{source=$entry.name;key=$key;failure_class='DUPLICATE_LISTENER_CORE_KEY'})}else{$entry.map.Add($key,[pscustomobject]@{core=$core;record=$record})}
        }
    }
    $aOnly=[Collections.Generic.List[object]]::new();$bOnly=[Collections.Generic.List[object]]::new();$matched=[Collections.Generic.List[object]]::new()
    foreach($key in @($aMap.Keys|Sort-Object)){if($bMap.ContainsKey($key)){$matched.Add([pscustomobject]@{key=$key;core=$aMap[$key].core;source_a_record=$aMap[$key].record;source_b_record=$bMap[$key].record})}else{$aOnly.Add([pscustomobject]@{key=$key;core=$aMap[$key].core})}}
    foreach($key in @($bMap.Keys|Sort-Object)){if(-not$aMap.ContainsKey($key)){$bOnly.Add([pscustomobject]@{key=$key;core=$bMap[$key].core})}}
    $aFailures=@($SourceA.parse_failures);$bFailures=@($SourceB.parse_failures)
    $green=($aFailures.Count-eq0-and$bFailures.Count-eq0-and$duplicates.Count-eq0-and$aOnly.Count-eq0-and$bOnly.Count-eq0)
    return [pscustomobject][ordered]@{
        schema='EndpointListenerCoreParityV2';comparison_policy='EXACT_FIVE_FIELD_LISTENER_CORE_V2';key_fields=@('address_family','local_address_normalized','local_port','tcp_state_canonical','owning_pid');
        key_field_count=5;observer_specific_field_count=0;process_enrichment_field_count=0;source_a_record_count=$aMap.Count;source_b_record_count=$bMap.Count;
        matched_count=$matched.Count;matched_records=@($matched);a_only_count=$aOnly.Count;a_only_cores=@($aOnly);b_only_count=$bOnly.Count;b_only_cores=@($bOnly);
        duplicate_key_count=$duplicates.Count;duplicates=@($duplicates);source_a_parse_failure_count=$aFailures.Count;source_b_parse_failure_count=$bFailures.Count;
        core_parity=$green
    }
}

Export-ModuleMember -Function 'ConvertTo-EndpointListenerCoreV2','Format-EndpointListenerCoreKeyV2','Compare-EndpointListenerCoreSetsV2'
