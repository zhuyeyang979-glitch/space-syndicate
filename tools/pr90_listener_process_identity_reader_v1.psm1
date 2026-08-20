Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'pr90_endpoint_listener_record_v1.psm1')

function Get-EndpointRawProcessSnapshotV1 {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][int]$PidValue)
    $cim = Get-CimInstance Win32_Process -Filter "ProcessId=$PidValue" -ErrorAction SilentlyContinue
    $process = Get-Process -Id $PidValue -ErrorAction SilentlyContinue
    if ($null -eq $cim -or $null -eq $process -or $process.HasExited) {
        return [pscustomobject][ordered]@{ exists=$false; pid=$PidValue }
    }
    $path = [string]$cim.ExecutablePath
    if ([string]::IsNullOrWhiteSpace($path)) { try { $path = [string]$process.Path } catch {} }
    $userSid = $null
    try {
        $owner = Invoke-CimMethod -InputObject $cim -MethodName GetOwnerSid -ErrorAction Stop
        if ([int]$owner.ReturnValue -eq 0) { $userSid = [string]$owner.Sid }
    } catch {}
    $startUtc = $process.StartTime.ToUniversalTime()
    return [pscustomobject][ordered]@{
        exists=$true
        pid=[int]$PidValue
        process_name=[string]$cim.Name
        executable_path=$path
        executable_sha256=if(-not[string]::IsNullOrWhiteSpace($path)-and(Test-Path -LiteralPath $path -PathType Leaf)){Get-Pr90Sha256 $path}else{$null}
        command_line=[string]$cim.CommandLine
        command_line_sha256=if([string]::IsNullOrWhiteSpace([string]$cim.CommandLine)){$null}else{Get-Pr90TextSha256 ([string]$cim.CommandLine)}
        creation_time_utc=$startUtc.ToString('o')
        creation_time_filetime_utc=$startUtc.ToFileTimeUtc().ToString([Globalization.CultureInfo]::InvariantCulture)
        parent_pid=[int]$cim.ParentProcessId
        windows_session_id=[int]$process.SessionId
        user_sid=$userSid
    }
}

function Compare-EndpointProcessIdentitySnapshotsV1 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Before,
        [Parameter(Mandatory = $true)][object]$After
    )
    $beforeExists = [bool](Get-EndpointSourcePropertyValueV1 $Before 'exists' -Required)
    $afterExists = [bool](Get-EndpointSourcePropertyValueV1 $After 'exists' -Required)
    $pid = [int](Get-EndpointSourcePropertyValueV1 $Before 'pid' -Required)
    if (-not $beforeExists -or -not $afterExists) {
        return [pscustomobject][ordered]@{ green=$false; failure_class='PROCESS_EXITED_DURING_IDENTITY_READ'; pid=$pid; pid_reuse_detected=$false }
    }
    $samePid = ([int](Get-EndpointSourcePropertyValueV1 $After 'pid' -Required) -eq $pid)
    $sameCreation = ([string](Get-EndpointSourcePropertyValueV1 $Before 'creation_time_filetime_utc' -Required) -ceq [string](Get-EndpointSourcePropertyValueV1 $After 'creation_time_filetime_utc' -Required))
    if (-not $samePid -or -not $sameCreation) {
        return [pscustomobject][ordered]@{ green=$false; failure_class='PID_REUSE_DETECTED'; pid=$pid; pid_reuse_detected=$true }
    }
    $samePath = ([string](Get-EndpointSourcePropertyValueV1 $Before 'executable_path' -Required) -ieq [string](Get-EndpointSourcePropertyValueV1 $After 'executable_path' -Required))
    $sameSession = ([int](Get-EndpointSourcePropertyValueV1 $Before 'windows_session_id' -Required) -eq [int](Get-EndpointSourcePropertyValueV1 $After 'windows_session_id' -Required))
    $sameParent = ([int](Get-EndpointSourcePropertyValueV1 $Before 'parent_pid' -Required) -eq [int](Get-EndpointSourcePropertyValueV1 $After 'parent_pid' -Required))
    if (-not $samePath -or -not $sameSession -or -not $sameParent) {
        return [pscustomobject][ordered]@{ green=$false; failure_class='PROCESS_IDENTITY_OBSERVER_DISAGREEMENT'; pid=$pid; pid_reuse_detected=$false }
    }
    return [pscustomobject][ordered]@{ green=$true; failure_class=''; pid=$pid; pid_reuse_detected=$false }
}

function Read-EndpointListenerOwnerIdentityV1 {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][int]$PidValue)
    $before = Get-EndpointRawProcessSnapshotV1 $PidValue
    if (-not [bool]$before.exists) {
        return [pscustomobject][ordered]@{ exists=$false; pid=$PidValue; pid_reuse_detected=$false; identity_read_green=$false; failure_class='PROCESS_NOT_FOUND' }
    }
    $after = Get-EndpointRawProcessSnapshotV1 $PidValue
    $comparison = Compare-EndpointProcessIdentitySnapshotsV1 -Before $before -After $after
    if (-not [bool]$comparison.green) {
        return [pscustomobject][ordered]@{ exists=$false; pid=$PidValue; pid_reuse_detected=[bool]$comparison.pid_reuse_detected; identity_read_green=$false; failure_class=[string]$comparison.failure_class }
    }
    $requiredGreen = (
        -not [string]::IsNullOrWhiteSpace([string]$after.process_name) -and
        -not [string]::IsNullOrWhiteSpace([string]$after.executable_path) -and
        -not [string]::IsNullOrWhiteSpace([string]$after.command_line) -and
        [string]$after.creation_time_filetime_utc -match '^[1-9][0-9]{0,18}$'
    )
    return [pscustomobject][ordered]@{
        exists=$true
        pid=[int]$after.pid
        process_name=[string]$after.process_name
        executable_path=[string]$after.executable_path
        executable_sha256=$after.executable_sha256
        command_line=[string]$after.command_line
        command_line_sha256=$after.command_line_sha256
        creation_time_utc=[string]$after.creation_time_utc
        creation_time_filetime_utc=[string]$after.creation_time_filetime_utc
        parent_pid=[int]$after.parent_pid
        windows_session_id=[int]$after.windows_session_id
        user_sid=$after.user_sid
        pid_reuse_detected=$false
        identity_read_green=$requiredGreen
        failure_class=if($requiredGreen){''}else{'PROCESS_IDENTITY_REQUIRED_FIELD_MISSING'}
    }
}

function Get-EndpointProcessAncestorChainV1 {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][int]$PidValue)
    $rows = [Collections.Generic.List[object]]::new()
    $seen = [Collections.Generic.HashSet[int]]::new()
    $current = $PidValue
    for ($index=0; $index -lt 16 -and $current -gt 0; $index+=1) {
        if (-not $seen.Add($current)) { break }
        $identity = Read-EndpointListenerOwnerIdentityV1 $current
        $rows.Add($identity)
        if (-not [bool]$identity.exists -or -not [bool]$identity.identity_read_green) { break }
        $current = [int]$identity.parent_pid
    }
    # Emit each identity row into the pipeline. Callers that require stable
    # cardinality collect the function output with @(...); wrapping the row
    # array here as one object creates a nested System.Object[] at M5.
    return @($rows)
}

Export-ModuleMember -Function @(
    'Get-EndpointRawProcessSnapshotV1', 'Compare-EndpointProcessIdentitySnapshotsV1',
    'Read-EndpointListenerOwnerIdentityV1', 'Get-EndpointProcessAncestorChainV1'
)
