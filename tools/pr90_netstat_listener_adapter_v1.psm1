Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'pr90_endpoint_listener_record_v1.psm1')

function Split-NetstatLocalEndpointV1 {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Endpoint)
    $text = $Endpoint.Trim()
    if ($text -match '^\[(?<address>[^\]]+)\]:(?<port>[0-9]+)$') {
        return [pscustomobject]@{ address=$Matches.address; port=$Matches.port }
    }
    $separator = $text.LastIndexOf(':')
    if ($separator -le 0 -or $separator -eq $text.Length - 1) { throw "Invalid netstat local endpoint: $text" }
    return [pscustomobject]@{ address=$text.Substring(0,$separator); port=$text.Substring($separator+1) }
}

function ConvertFrom-NetstatListenerRecordV1 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][AllowNull()][object]$InputObject,
        [Parameter(Mandatory = $true)][string]$SampleId,
        [Parameter(Mandatory = $true)][DateTimeOffset]$ObservedUtc
    )
    if ($InputObject -isnot [string]) { throw 'netstat adapter requires a System.String line.' }
    $line = [string]$InputObject
    if ($line -notmatch '^\s*TCP\s+(?<local>\S+)\s+(?<remote>\S+)\s+(?<state>\S+)\s+(?<pid>\S+)\s*$') {
        throw 'netstat line does not match the TCP listener grammar.'
    }
    $endpoint = Split-NetstatLocalEndpointV1 $Matches.local
    return New-EndpointListenerRecordV1 `
        -ObserverSource 'netstat-ano-p-TCP' `
        -SampleId $SampleId `
        -ObservedUtc $ObservedUtc `
        -LocalAddressRaw ([string]$endpoint.address) `
        -LocalPort $endpoint.port `
        -TcpState $Matches.state `
        -OwningPid $Matches.pid `
        -RawRecordFingerprint (Get-Pr90TextSha256 $line)
}

function ConvertFrom-NetstatListenerRecordsV1 {
    [CmdletBinding()]
    param(
        [AllowNull()][object[]]$InputObject = @(),
        [Parameter(Mandatory = $true)][string]$SampleId,
        [Parameter(Mandatory = $true)][DateTimeOffset]$ObservedUtc,
        [int[]]$Ports = @()
    )
    $records = [Collections.Generic.List[object]]::new()
    $failures = [Collections.Generic.List[object]]::new()
    $ignored = 0
    $index = 0
    foreach ($raw in @($InputObject)) {
        if ($raw -is [string] -and [string]$raw -notmatch '^\s*TCP\s+') { $ignored += 1; $index += 1; continue }
        try {
            $record = ConvertFrom-NetstatListenerRecordV1 -InputObject $raw -SampleId $SampleId -ObservedUtc $ObservedUtc
            if ($Ports.Count -eq 0 -or [int]$record.local_port -in $Ports) { $records.Add($record) }
        } catch {
            $failures.Add([pscustomobject][ordered]@{
                source='netstat-ano-p-TCP'; record_index=$index; failure_class='NETSTAT_RECORD_PARSE_FAILED'
                detail=$_.Exception.Message
                raw_dotnet_type=if($null -eq $raw){$null}else{$raw.GetType().FullName}
                raw_fingerprint=if($raw -is [string]){Get-Pr90TextSha256 ([string]$raw)}else{$null}
            })
        }
        $index += 1
    }
    return [pscustomobject][ordered]@{
        schema='EndpointListenerSourceObservationV1'
        observer_source='netstat-ano-p-TCP'
        sample_id=$SampleId
        observed_utc=$ObservedUtc.ToUniversalTime().ToString('o')
        raw_record_count=@($InputObject).Count
        ignored_non_tcp_line_count=$ignored
        records=@($records)
        parse_failures=@($failures)
        parse_failure_count=$failures.Count
    }
}

function Invoke-NetstatTcpListenerObservationV1 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][int[]]$Ports,
        [Parameter(Mandatory = $true)][string]$SampleId
    )
    $observed = [DateTimeOffset]::UtcNow
    $raw = @(& netstat.exe -ano -p TCP 2>$null)
    return ConvertFrom-NetstatListenerRecordsV1 -InputObject $raw -SampleId $SampleId -ObservedUtc $observed -Ports $Ports
}

Export-ModuleMember -Function @(
    'Split-NetstatLocalEndpointV1', 'ConvertFrom-NetstatListenerRecordV1',
    'ConvertFrom-NetstatListenerRecordsV1', 'Invoke-NetstatTcpListenerObservationV1'
)
