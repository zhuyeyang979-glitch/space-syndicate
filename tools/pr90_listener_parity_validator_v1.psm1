Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'pr90_endpoint_listener_record_v1.psm1')
Import-Module (Join-Path $PSScriptRoot 'pr90_endpoint_listener_key_formatter_v1.psm1')

function Compare-EndpointListenerSourceSetsV1 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$SourceA,
        [Parameter(Mandatory = $true)][object]$SourceB
    )
    $aRecords = @(Get-EndpointSourcePropertyValueV1 $SourceA 'records' -Required)
    $bRecords = @(Get-EndpointSourcePropertyValueV1 $SourceB 'records' -Required)
    $aFailures = @(Get-EndpointSourcePropertyValueV1 $SourceA 'parse_failures' -Required)
    $bFailures = @(Get-EndpointSourcePropertyValueV1 $SourceB 'parse_failures' -Required)
    $aMap = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    $bMap = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    $duplicates = [Collections.Generic.List[object]]::new()
    foreach ($entry in @(@{source='A';records=$aRecords;map=$aMap},@{source='B';records=$bRecords;map=$bMap})) {
        foreach ($record in @($entry.records)) {
            try { $key = Format-EndpointListenerCanonicalKeyV1 $record } catch {
                $duplicates.Add([pscustomobject]@{source=$entry.source;key=$null;failure_class='CANONICAL_KEY_BUILD_FAILED';detail=$_.Exception.Message})
                continue
            }
            if ($entry.map.ContainsKey($key)) {
                $duplicates.Add([pscustomobject]@{source=$entry.source;key=$key;failure_class='DUPLICATE_CANONICAL_KEY'})
            } else { $entry.map.Add($key,$record) }
        }
    }
    $aOnly = [Collections.Generic.List[object]]::new()
    $bOnly = [Collections.Generic.List[object]]::new()
    $matched = [Collections.Generic.List[object]]::new()
    foreach ($key in @($aMap.Keys | Sort-Object)) {
        if ($bMap.ContainsKey($key)) { $matched.Add([pscustomobject]@{key=$key;source_a_record=$aMap[$key];source_b_record=$bMap[$key]}) }
        else { $aOnly.Add([pscustomobject]@{key=$key;record=$aMap[$key]}) }
    }
    foreach ($key in @($bMap.Keys | Sort-Object)) {
        if (-not $aMap.ContainsKey($key)) { $bOnly.Add([pscustomobject]@{key=$key;record=$bMap[$key]}) }
    }
    $parity = ($aFailures.Count -eq 0 -and $bFailures.Count -eq 0 -and $duplicates.Count -eq 0 -and $aOnly.Count -eq 0 -and $bOnly.Count -eq 0)
    return [pscustomobject][ordered]@{
        schema='EndpointListenerSourceParityV1'
        comparison_policy='EXACT_NORMALIZED_ADDRESS_AND_PROCESS_INSTANCE_V1'
        source_a=[string](Get-EndpointSourcePropertyValueV1 $SourceA 'observer_source' -Required)
        source_b=[string](Get-EndpointSourcePropertyValueV1 $SourceB 'observer_source' -Required)
        source_a_record_count=$aRecords.Count
        source_b_record_count=$bRecords.Count
        matched_count=$matched.Count
        matched_records=@($matched)
        a_only_count=$aOnly.Count
        a_only_records=@($aOnly)
        b_only_count=$bOnly.Count
        b_only_records=@($bOnly)
        duplicate_key_count=$duplicates.Count
        duplicate_keys=@($duplicates)
        source_a_parse_failure_count=$aFailures.Count
        source_a_parse_failures=@($aFailures)
        source_b_parse_failure_count=$bFailures.Count
        source_b_parse_failures=@($bFailures)
        parity=$parity
    }
}

function Test-EndpointOwnerStableWindowV1 {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object[]]$Samples)
    $maxCount=0; $maxSpan=0.0; $current=[Collections.Generic.List[object]]::new(); $lastIdentity=''; $lastLineage=''
    foreach ($sample in @($Samples | Sort-Object observed_utc)) {
        $qualified = [bool](Get-EndpointSourcePropertyValueV1 $sample 'qualified' -Required)
        $identity = [string](Get-EndpointSourcePropertyValueV1 $sample 'owner_instance_key' -Required)
        $lineage = [string](Get-EndpointSourcePropertyValueV1 $sample 'lineage_fingerprint' -Required)
        if (-not $qualified -or ($current.Count -gt 0 -and ($identity -cne $lastIdentity -or $lineage -cne $lastLineage))) { $current.Clear() }
        if ($qualified) {
            $current.Add($sample); $lastIdentity=$identity; $lastLineage=$lineage
            $span = if($current.Count -gt 1){([DateTimeOffset]::Parse([string]$current[-1].observed_utc)-[DateTimeOffset]::Parse([string]$current[0].observed_utc)).TotalMilliseconds}else{0}
            if ($current.Count -gt $maxCount -or ($current.Count -eq $maxCount -and $span -gt $maxSpan)) { $maxCount=$current.Count; $maxSpan=$span }
        }
    }
    $green = (@($Samples).Count -ge 5 -and $maxCount -ge 3 -and $maxSpan -ge 1000)
    return [pscustomobject][ordered]@{ green=$green; total_sample_count=@($Samples).Count; stable_sample_count=$maxCount; stable_window_ms=[math]::Round($maxSpan,3) }
}

Export-ModuleMember -Function 'Compare-EndpointListenerSourceSetsV1','Test-EndpointOwnerStableWindowV1'
