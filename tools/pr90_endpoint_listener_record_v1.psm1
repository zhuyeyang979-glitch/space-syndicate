Set-StrictMode -Version Latest

$script:EndpointListenerRequiredFields = @(
    'schema_version', 'observer_source', 'sample_id', 'observed_utc',
    'address_family', 'local_address_raw', 'local_address_normalized',
    'local_port', 'tcp_state', 'owning_pid', 'owner_process_name',
    'owner_executable_path', 'owner_executable_sha256',
    'owner_creation_time_filetime_utc', 'owner_parent_pid',
    'owner_session_id', 'owner_user_sid', 'raw_record_fingerprint'
)

function Get-Pr90Sha256 {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-Pr90TextSha256 {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Text)
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

function ConvertTo-Pr90CanonicalJson {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][AllowNull()][object]$Value)
    return ($Value | ConvertTo-Json -Depth 100 -Compress)
}

function Get-Pr90CanonicalSha256 {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][AllowNull()][object]$Value)
    $copy = ConvertTo-Pr90CanonicalJson $Value | ConvertFrom-Json -Depth 100 -DateKind String
    if ($null -ne $copy -and $copy.PSObject.Properties.Name -contains 'canonical_payload_sha256') {
        $copy.canonical_payload_sha256 = ''
    }
    return Get-Pr90TextSha256 (ConvertTo-Pr90CanonicalJson $copy)
}

function Set-Pr90CanonicalPayloadV1 {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][AllowNull()][object]$Value)
    if ($null -eq $Value) { throw 'Canonical payload value is null.' }
    $hasField = if ($Value -is [Collections.IDictionary]) {
        $Value.Contains('canonical_payload_sha256')
    } else {
        $Value.PSObject.Properties.Name -ccontains 'canonical_payload_sha256'
    }
    if (-not $hasField) { throw 'Canonical payload field is missing.' }
    $canonical = Get-Pr90CanonicalSha256 $Value
    if ($Value -is [Collections.IDictionary]) {
        $Value['canonical_payload_sha256'] = $canonical
    } else {
        $Value.canonical_payload_sha256 = $canonical
    }
    if ($canonical -notmatch '^[0-9a-f]{64}$') { throw 'Canonical payload SHA-256 is invalid.' }
    return $Value
}

function Write-Pr90ImmutableText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text,
        [switch]$WriteSha256Sidecar
    )
    $full = [IO.Path]::GetFullPath($Path)
    if (Test-Path -LiteralPath $full) { throw "Refusing overwrite: $full" }
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($full)) | Out-Null
    $temporary = "$full.$([Guid]::NewGuid().ToString('N')).tmp"
    try {
        [IO.File]::WriteAllText($temporary, $Text, [Text.UTF8Encoding]::new($false))
        [IO.File]::Move($temporary, $full, $false)
    } finally {
        if (Test-Path -LiteralPath $temporary) { [IO.File]::Delete($temporary) }
    }
    if ($WriteSha256Sidecar) {
        $line = "$(Get-Pr90Sha256 $full)  $([IO.Path]::GetFileName($full))`n"
        Write-Pr90ImmutableText -Path "$full.sha256" -Text $line | Out-Null
    }
    return $full
}

function Write-Pr90ImmutableJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][AllowNull()][object]$Value,
        [switch]$WriteSha256Sidecar
    )
    return Write-Pr90ImmutableText -Path $Path -Text ($Value | ConvertTo-Json -Depth 100) -WriteSha256Sidecar:$WriteSha256Sidecar
}

function Get-EndpointSourcePropertyValueV1 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][AllowNull()][object]$InputObject,
        [Parameter(Mandatory = $true)][string]$Name,
        [switch]$Required
    )
    if ($null -eq $InputObject) {
        if ($Required) { throw "Required source property '$Name' cannot be read from null." }
        return $null
    }
    if ($InputObject -is [Collections.IDictionary]) {
        foreach ($key in $InputObject.Keys) {
            if ([string]$key -ceq $Name) { return $InputObject[$key] }
        }
    } else {
        $property = $InputObject.PSObject.Properties[$Name]
        if ($null -ne $property) { return $property.Value }
    }
    if ($Required) { throw "Required source property '$Name' is missing." }
    return $null
}

function ConvertTo-EndpointPositiveIntV1 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][AllowNull()][object]$Value,
        [Parameter(Mandatory = $true)][string]$FieldName,
        [int]$Maximum = [int]::MaxValue
    )
    if ($null -eq $Value) { throw "$FieldName is null." }
    $parsed = [int64]0
    if (-not [int64]::TryParse([string]$Value, [Globalization.NumberStyles]::None, [Globalization.CultureInfo]::InvariantCulture, [ref]$parsed)) {
        throw "$FieldName is not a base-10 integer."
    }
    if ($parsed -lt 1 -or $parsed -gt $Maximum) { throw "$FieldName is outside 1..$Maximum." }
    return [int]$parsed
}

function ConvertTo-EndpointAddressV1 {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][AllowNull()][object]$Address)
    if ($null -eq $Address) { throw 'Listener local address is null.' }
    $raw = [string]$Address
    if ([string]::IsNullOrWhiteSpace($raw)) { throw 'Listener local address is blank.' }
    $candidate = $raw.Trim()
    if ($candidate.StartsWith('[') -and $candidate.EndsWith(']')) {
        $candidate = $candidate.Substring(1, $candidate.Length - 2)
    }
    $ip = $null
    if (-not [Net.IPAddress]::TryParse($candidate, [ref]$ip)) { throw "Listener local address is invalid: $raw" }
    $family = switch ($ip.AddressFamily) {
        ([Net.Sockets.AddressFamily]::InterNetwork) { 'IPv4'; break }
        ([Net.Sockets.AddressFamily]::InterNetworkV6) { 'IPv6'; break }
        default { throw "Unsupported listener address family: $($ip.AddressFamily)" }
    }
    return [pscustomobject][ordered]@{
        raw = $raw
        normalized = $ip.ToString().ToLowerInvariant()
        address_family = $family
        is_ipv4_mapped_ipv6 = ($family -ceq 'IPv6' -and $ip.IsIPv4MappedToIPv6)
    }
}

function ConvertTo-EndpointTcpStateV1 {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][AllowNull()][object]$State)
    if ($null -eq $State) { throw 'Listener TCP state is null.' }
    $text = ([string]$State).Trim().ToUpperInvariant()
    if ($text -in @('LISTEN', 'LISTENING')) { return 'LISTEN' }
    throw "Unsupported listener TCP state: $text"
}

function New-EndpointListenerRecordV1 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ObserverSource,
        [Parameter(Mandatory = $true)][string]$SampleId,
        [Parameter(Mandatory = $true)][DateTimeOffset]$ObservedUtc,
        [Parameter(Mandatory = $true)][string]$LocalAddressRaw,
        [Parameter(Mandatory = $true)][object]$LocalPort,
        [Parameter(Mandatory = $true)][object]$TcpState,
        [Parameter(Mandatory = $true)][object]$OwningPid,
        [Parameter(Mandatory = $true)][string]$RawRecordFingerprint,
        [AllowNull()][object]$OwnerProcessName = $null,
        [AllowNull()][object]$OwnerExecutablePath = $null,
        [AllowNull()][object]$OwnerExecutableSha256 = $null,
        [AllowNull()][object]$OwnerCreationTimeFiletimeUtc = $null,
        [AllowNull()][Nullable[int]]$OwnerParentPid = $null,
        [AllowNull()][Nullable[int]]$OwnerSessionId = $null,
        [AllowNull()][object]$OwnerUserSid = $null
    )
    if ([string]::IsNullOrWhiteSpace($ObserverSource)) { throw 'observer_source is blank.' }
    if ([string]::IsNullOrWhiteSpace($SampleId)) { throw 'sample_id is blank.' }
    if ($RawRecordFingerprint -notmatch '^[0-9a-f]{64}$') { throw 'raw_record_fingerprint is not lowercase SHA-256.' }
    $address = ConvertTo-EndpointAddressV1 $LocalAddressRaw
    $record = [pscustomobject][ordered]@{
        schema_version = 'EndpointListenerRecordV1'
        observer_source = $ObserverSource
        sample_id = $SampleId
        observed_utc = $ObservedUtc.ToUniversalTime().ToString('o')
        address_family = [string]$address.address_family
        local_address_raw = [string]$address.raw
        local_address_normalized = [string]$address.normalized
        local_port = ConvertTo-EndpointPositiveIntV1 -Value $LocalPort -FieldName 'local_port' -Maximum 65535
        tcp_state = ConvertTo-EndpointTcpStateV1 $TcpState
        owning_pid = ConvertTo-EndpointPositiveIntV1 -Value $OwningPid -FieldName 'owning_pid'
        owner_process_name = $OwnerProcessName
        owner_executable_path = $OwnerExecutablePath
        owner_executable_sha256 = $OwnerExecutableSha256
        owner_creation_time_filetime_utc = $OwnerCreationTimeFiletimeUtc
        owner_parent_pid = $OwnerParentPid
        owner_session_id = $OwnerSessionId
        owner_user_sid = $OwnerUserSid
        raw_record_fingerprint = $RawRecordFingerprint
    }
    Assert-EndpointListenerRecordV1 -Record $record | Out-Null
    return $record
}

function Test-EndpointListenerRecordV1 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][AllowNull()][object]$Record,
        [switch]$RequireOwnerIdentity
    )
    $issues = [Collections.Generic.List[string]]::new()
    if ($null -eq $Record) {
        $issues.Add('RECORD_NULL')
        return [pscustomobject]@{ valid=$false; issue_count=1; issues=@($issues) }
    }
    $names = @($Record.PSObject.Properties.Name)
    foreach ($field in $script:EndpointListenerRequiredFields) {
        if ($names -cnotcontains $field) { $issues.Add("MISSING_FIELD:$field") }
    }
    if ($issues.Count -eq 0) {
        if ([string]$Record.schema_version -cne 'EndpointListenerRecordV1') { $issues.Add('SCHEMA_MISMATCH') }
        if ([string]::IsNullOrWhiteSpace([string]$Record.observer_source)) { $issues.Add('OBSERVER_SOURCE_BLANK') }
        if ([string]::IsNullOrWhiteSpace([string]$Record.sample_id)) { $issues.Add('SAMPLE_ID_BLANK') }
        $observed = [DateTimeOffset]::MinValue
        if (-not [DateTimeOffset]::TryParseExact([string]$Record.observed_utc, 'o', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$observed)) { $issues.Add('OBSERVED_UTC_INVALID') }
        try {
            $address = ConvertTo-EndpointAddressV1 $Record.local_address_raw
            if ([string]$Record.local_address_normalized -cne [string]$address.normalized) { $issues.Add('ADDRESS_NORMALIZATION_MISMATCH') }
            if ([string]$Record.address_family -cne [string]$address.address_family) { $issues.Add('ADDRESS_FAMILY_MISMATCH') }
        } catch { $issues.Add('ADDRESS_INVALID') }
        if ($Record.local_port -isnot [int] -or [int]$Record.local_port -lt 1 -or [int]$Record.local_port -gt 65535) { $issues.Add('LOCAL_PORT_TYPE_OR_RANGE') }
        if ([string]$Record.tcp_state -cne 'LISTEN') { $issues.Add('TCP_STATE_INVALID') }
        if ($Record.owning_pid -isnot [int] -or [int]$Record.owning_pid -lt 1) { $issues.Add('OWNING_PID_TYPE_OR_RANGE') }
        if ([string]$Record.raw_record_fingerprint -notmatch '^[0-9a-f]{64}$') { $issues.Add('RAW_FINGERPRINT_INVALID') }
        if ($null -ne $Record.owner_executable_sha256 -and [string]$Record.owner_executable_sha256 -notmatch '^[0-9a-f]{64}$') { $issues.Add('OWNER_EXECUTABLE_SHA256_INVALID') }
        if ($RequireOwnerIdentity) {
            if ([string]$Record.owner_creation_time_filetime_utc -notmatch '^[1-9][0-9]{0,18}$') { $issues.Add('OWNER_CREATION_IDENTITY_MISSING') }
            if ([string]::IsNullOrWhiteSpace([string]$Record.owner_process_name)) { $issues.Add('OWNER_PROCESS_NAME_MISSING') }
            if ([string]::IsNullOrWhiteSpace([string]$Record.owner_executable_path)) { $issues.Add('OWNER_EXECUTABLE_PATH_MISSING') }
            if ($null -eq $Record.owner_parent_pid -or [int]$Record.owner_parent_pid -lt 0) { $issues.Add('OWNER_PARENT_PID_MISSING') }
            if ($null -eq $Record.owner_session_id -or [int]$Record.owner_session_id -lt 0) { $issues.Add('OWNER_SESSION_ID_MISSING') }
        }
    }
    return [pscustomobject][ordered]@{ valid=($issues.Count -eq 0); issue_count=$issues.Count; issues=@($issues) }
}

function Assert-EndpointListenerRecordV1 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][AllowNull()][object]$Record,
        [switch]$RequireOwnerIdentity
    )
    $validation = Test-EndpointListenerRecordV1 -Record $Record -RequireOwnerIdentity:$RequireOwnerIdentity
    if (-not [bool]$validation.valid) { throw "EndpointListenerRecordV1 invalid: $($validation.issues -join ',')" }
    return $Record
}

function Set-EndpointListenerOwnerIdentityV1 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Record,
        [Parameter(Mandatory = $true)][object]$Identity
    )
    Assert-EndpointListenerRecordV1 $Record | Out-Null
    if (-not [bool](Get-EndpointSourcePropertyValueV1 $Identity 'exists' -Required)) { throw 'Listener owner process exited before identity enrichment.' }
    if ([bool](Get-EndpointSourcePropertyValueV1 $Identity 'pid_reuse_detected' -Required)) { throw 'Listener owner PID reuse was detected.' }
    $identityPid = ConvertTo-EndpointPositiveIntV1 (Get-EndpointSourcePropertyValueV1 $Identity 'pid' -Required) 'identity.pid'
    if ($identityPid -ne [int]$Record.owning_pid) { throw 'Listener owner identity PID mismatch.' }
    $copy = [ordered]@{}
    foreach ($field in $script:EndpointListenerRequiredFields) { $copy[$field] = $Record.PSObject.Properties[$field].Value }
    $copy.owner_process_name = [string](Get-EndpointSourcePropertyValueV1 $Identity 'process_name' -Required)
    $copy.owner_executable_path = [string](Get-EndpointSourcePropertyValueV1 $Identity 'executable_path' -Required)
    $copy.owner_executable_sha256 = Get-EndpointSourcePropertyValueV1 $Identity 'executable_sha256'
    $copy.owner_creation_time_filetime_utc = [string](Get-EndpointSourcePropertyValueV1 $Identity 'creation_time_filetime_utc' -Required)
    $copy.owner_parent_pid = [int](Get-EndpointSourcePropertyValueV1 $Identity 'parent_pid' -Required)
    $copy.owner_session_id = [int](Get-EndpointSourcePropertyValueV1 $Identity 'windows_session_id' -Required)
    $copy.owner_user_sid = Get-EndpointSourcePropertyValueV1 $Identity 'user_sid'
    $result = [pscustomobject]$copy
    Assert-EndpointListenerRecordV1 -Record $result -RequireOwnerIdentity | Out-Null
    return $result
}

function Build-EndpointListenerCanonicalKeyV1 {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Record)
    Assert-EndpointListenerRecordV1 -Record $Record -RequireOwnerIdentity | Out-Null
    $parts = @(
        [string]$Record.address_family,
        [string]$Record.local_address_normalized,
        ([int]$Record.local_port).ToString([Globalization.CultureInfo]::InvariantCulture),
        [string]$Record.tcp_state,
        ([int]$Record.owning_pid).ToString([Globalization.CultureInfo]::InvariantCulture),
        [string]$Record.owner_creation_time_filetime_utc
    )
    if (@($parts | Where-Object { $null -eq $_ -or $_.Length -eq 0 }).Count -ne 0) { throw 'Canonical listener key has a null or empty component.' }
    return [string]::Join('|', $parts)
}

Export-ModuleMember -Function @(
    'Get-Pr90Sha256', 'Get-Pr90TextSha256', 'ConvertTo-Pr90CanonicalJson',
    'Get-Pr90CanonicalSha256', 'Set-Pr90CanonicalPayloadV1',
    'Write-Pr90ImmutableText', 'Write-Pr90ImmutableJson',
    'Get-EndpointSourcePropertyValueV1', 'ConvertTo-EndpointPositiveIntV1',
    'ConvertTo-EndpointAddressV1', 'ConvertTo-EndpointTcpStateV1',
    'New-EndpointListenerRecordV1', 'Test-EndpointListenerRecordV1',
    'Assert-EndpointListenerRecordV1', 'Set-EndpointListenerOwnerIdentityV1',
    'Build-EndpointListenerCanonicalKeyV1'
)
