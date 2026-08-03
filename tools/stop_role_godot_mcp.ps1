param(
    [string]$Worktree = (Get-Location).Path,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RequestId,

    [ValidateRange(1, 120)]
    [int]$ShutdownTimeoutSeconds = 20,

    [bool]$AllowForcedCleanup = $true
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "role_godot_mcp_common.ps1")

$root = (Resolve-Path -LiteralPath $Worktree).Path.TrimEnd("\")
$controlRoot = Join-Path $root ".codex-godot"
$session = Get-McpActiveSession -ControlRoot $controlRoot
$connection = $session.connection
$identity = Test-McpProcessIdentity -Connection $connection
$endpointOwnerBefore = Get-McpEndpointOwnerPid -Port ([int]$connection.port)

if (-not [bool]$identity.valid) {
    $unverifiedPid = ConvertTo-McpInt32Value -Value (Get-McpOptionalProperty -Object $connection -Name "pid")
    $unverifiedProcess = if ($unverifiedPid.valid -and [int]$unverifiedPid.value -gt 0) {
        Get-Process -Id ([int]$unverifiedPid.value) -ErrorAction SilentlyContinue
    } else {
        $null
    }
    if ($endpointOwnerBefore -ne 0 -or $null -ne $unverifiedProcess) {
        throw "MCP_STOP_IDENTITY_FAILURE|reason_code=$($identity.reason_code)|endpoint_owner_pid=$endpointOwnerBefore"
    }
    Remove-Item -LiteralPath $session.active_path -Force
    [pscustomobject]@{
        stopped = $true
        clean_stop = $false
        already_exited = $true
        request_id = $RequestId
        pid = [int]$connection.pid
        endpoint_alive_after = $false
        task_process_count_after = 0
        reason_code = [string]$identity.reason_code
    } | ConvertTo-Json -Depth 5
    exit 0
}

if ($endpointOwnerBefore -ne [int]$connection.pid) {
    throw "MCP_STOP_ENDPOINT_PROCESS_MISMATCH|expected_pid=$($connection.pid)|actual_pid=$endpointOwnerBefore"
}

$storedProcessIdentity = Get-McpOptionalProperty -Object $connection -Name "process_identity"
$expectedCreationTimeToken = Get-McpOptionalProperty -Object $storedProcessIdentity -Name "process_creation_time"
$stopResult = Stop-McpBoundProcess `
    -Process $identity.process `
    -TimeoutSeconds $ShutdownTimeoutSeconds `
    -ExpectedCreationTimeToken $expectedCreationTimeToken `
    -AllowForcedCleanup:$AllowForcedCleanup
$endpointDeadline = [DateTimeOffset]::Now.AddSeconds(5)
do {
    $endpointOwnerAfter = Get-McpEndpointOwnerPid -Port ([int]$connection.port)
    if ($endpointOwnerAfter -eq 0) {
        break
    }
    Start-Sleep -Milliseconds 100
} while ([DateTimeOffset]::Now -lt $endpointDeadline)

$endpointOwnerAfter = Get-McpEndpointOwnerPid -Port ([int]$connection.port)
$processAfter = Get-Process -Id ([int]$connection.pid) -ErrorAction SilentlyContinue
$processCountAfter = if ($null -eq $processAfter -or $processAfter.HasExited) { 0 } else { 1 }
$stopped = [bool]$stopResult.stopped -and $endpointOwnerAfter -eq 0 -and $processCountAfter -eq 0
if ($stopped) {
    if (Test-Path -LiteralPath (Join-Path ([string]$connection.session_root) "godot.pid")) {
        Remove-Item -LiteralPath (Join-Path ([string]$connection.session_root) "godot.pid") -Force
    }
    Remove-Item -LiteralPath $session.active_path -Force
}

$result = [ordered]@{
    stopped = $stopped
    clean_stop = [bool]$stopResult.clean_stop -and -not [bool]$stopResult.forced
    forced = [bool]$stopResult.forced
    already_exited = $false
    request_id = $RequestId
    pid = [int]$connection.pid
    endpoint_owner_pid_before = $endpointOwnerBefore
    endpoint_owner_pid_after = $endpointOwnerAfter
    endpoint_alive_after = $endpointOwnerAfter -ne 0
    task_process_count_after = $processCountAfter
}
$result | ConvertTo-Json -Depth 5
if (-not $stopped -or -not [bool]$result.clean_stop) {
    exit 1
}
