Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'pr90_endpoint_listener_record_v1.psm1')

function Get-ListenerRawObjectInventoryV1 {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][AllowNull()][object]$InputObject)
    if ($null -eq $InputObject) {
        return [pscustomobject][ordered]@{ dotnet_type=$null; ps_type_names=@(); properties=@(); enumerable=$false }
    }
    $properties = [Collections.Generic.List[object]]::new()
    foreach ($property in $InputObject.PSObject.Properties) {
        $valueType = $null
        try { if ($null -ne $property.Value) { $valueType = $property.Value.GetType().FullName } } catch { $valueType = 'READ_ERROR' }
        $properties.Add([pscustomobject][ordered]@{ name=[string]$property.Name; value_type=$valueType })
    }
    return [pscustomobject][ordered]@{
        dotnet_type = $InputObject.GetType().FullName
        ps_type_names = @($InputObject.PSObject.TypeNames)
        properties = @($properties | Sort-Object name)
        enumerable = ($InputObject -is [Collections.IEnumerable] -and $InputObject -isnot [string])
    }
}

function ConvertFrom-GetNetTcpConnectionRecordV1 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][AllowNull()][object]$InputObject,
        [Parameter(Mandatory = $true)][string]$SampleId,
        [Parameter(Mandatory = $true)][DateTimeOffset]$ObservedUtc
    )
    if ($null -eq $InputObject) { throw 'Get-NetTCPConnection adapter rejects a null record.' }
    $localAddress = Get-EndpointSourcePropertyValueV1 -InputObject $InputObject -Name 'LocalAddress' -Required
    $localPort = Get-EndpointSourcePropertyValueV1 -InputObject $InputObject -Name 'LocalPort' -Required
    $state = Get-EndpointSourcePropertyValueV1 -InputObject $InputObject -Name 'State' -Required
    $pid = Get-EndpointSourcePropertyValueV1 -InputObject $InputObject -Name 'OwningProcess' -Required
    $rawProjection = [ordered]@{
        source='Get-NetTCPConnection'
        local_address=[string]$localAddress
        local_port=[string]$localPort
        state=[string]$state
        owning_pid=[string]$pid
        creation_time=[string](Get-EndpointSourcePropertyValueV1 -InputObject $InputObject -Name 'CreationTime')
    }
    return New-EndpointListenerRecordV1 `
        -ObserverSource 'Get-NetTCPConnection' `
        -SampleId $SampleId `
        -ObservedUtc $ObservedUtc `
        -LocalAddressRaw ([string]$localAddress) `
        -LocalPort $localPort `
        -TcpState $state `
        -OwningPid $pid `
        -RawRecordFingerprint (Get-Pr90TextSha256 (ConvertTo-Pr90CanonicalJson $rawProjection))
}

function ConvertFrom-GetNetTcpConnectionRecordsV1 {
    [CmdletBinding()]
    param(
        [AllowNull()][object[]]$InputObject = @(),
        [Parameter(Mandatory = $true)][string]$SampleId,
        [Parameter(Mandatory = $true)][DateTimeOffset]$ObservedUtc
    )
    $records = [Collections.Generic.List[object]]::new()
    $failures = [Collections.Generic.List[object]]::new()
    $index = 0
    foreach ($raw in @($InputObject)) {
        try {
            $records.Add((ConvertFrom-GetNetTcpConnectionRecordV1 -InputObject $raw -SampleId $SampleId -ObservedUtc $ObservedUtc))
        } catch {
            $failures.Add([pscustomobject][ordered]@{
                source='Get-NetTCPConnection'; record_index=$index; failure_class='GETNETTCP_RECORD_PARSE_FAILED'
                detail=$_.Exception.Message; raw_inventory=Get-ListenerRawObjectInventoryV1 $raw
            })
        }
        $index += 1
    }
    return [pscustomobject][ordered]@{
        schema='EndpointListenerSourceObservationV1'
        observer_source='Get-NetTCPConnection'
        sample_id=$SampleId
        observed_utc=$ObservedUtc.ToUniversalTime().ToString('o')
        raw_record_count=@($InputObject).Count
        records=@($records)
        parse_failures=@($failures)
        parse_failure_count=$failures.Count
    }
}

function Invoke-GetNetTcpListenerObservationV1 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][int[]]$Ports,
        [Parameter(Mandatory = $true)][string]$SampleId
    )
    $observed = [DateTimeOffset]::UtcNow
    $raw = @(
        Get-NetTCPConnection -State Listen -ErrorAction Stop |
            Where-Object { [int]$_.LocalPort -in $Ports }
    )
    return ConvertFrom-GetNetTcpConnectionRecordsV1 -InputObject $raw -SampleId $SampleId -ObservedUtc $observed
}

Export-ModuleMember -Function @(
    'Get-ListenerRawObjectInventoryV1', 'ConvertFrom-GetNetTcpConnectionRecordV1',
    'ConvertFrom-GetNetTcpConnectionRecordsV1', 'Invoke-GetNetTcpListenerObservationV1'
)
