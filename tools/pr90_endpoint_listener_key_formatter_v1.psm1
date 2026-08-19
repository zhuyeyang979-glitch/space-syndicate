Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'pr90_endpoint_listener_record_v1.psm1')

function Format-EndpointListenerCanonicalKeyV1 {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$EndpointListenerRecord)
    Assert-EndpointListenerRecordV1 -Record $EndpointListenerRecord -RequireOwnerIdentity | Out-Null
    return Build-EndpointListenerCanonicalKeyV1 -Record $EndpointListenerRecord
}

Export-ModuleMember -Function 'Format-EndpointListenerCanonicalKeyV1'
