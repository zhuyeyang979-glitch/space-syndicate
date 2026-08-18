param(
    [string]$Worktree = (Get-Location).Path,

    [ValidateRange(1, 120)]
    [int]$ShutdownTimeoutSeconds = 20
)

$ErrorActionPreference = "Stop"

$processIdentityModule = Join-Path `
    $PSScriptRoot `
    "role_godot_mcp_process_identity.psm1"
Import-Module -Name $processIdentityModule -Force -ErrorAction Stop

$root = (Resolve-Path -LiteralPath $Worktree).Path.TrimEnd("\")
$localRoot = Join-Path $root ".codex-godot"
$connectionPath = Join-Path $localRoot "connection.json"
$pidPath = Join-Path $localRoot "godot.pid"
$endpointPath = Join-Path $localRoot "endpoint.txt"
$connection = if (Test-Path -LiteralPath $connectionPath) {
    Get-Content -LiteralPath $connectionPath -Raw | ConvertFrom-Json
} else {
    $null
}

function Test-CommandLineWorktreeBinding {
    param(
        [Parameter(Mandatory = $true)][string]$CommandLine,
        [Parameter(Mandatory = $true)][string]$ExpectedRoot
    )
    if ([string]::IsNullOrWhiteSpace($CommandLine)) { return $false }
    foreach ($rootForm in @($ExpectedRoot, $ExpectedRoot.Replace("\", "/"))) {
        $escapedRoot = [Regex]::Escape($rootForm.TrimEnd("\", "/"))
        $pattern = '(?i)(?:^|\s)--path(?:\s+|=)(?:"' +
            $escapedRoot + '"|' + $escapedRoot + ')(?=\s|$)'
        if ([Regex]::IsMatch($CommandLine, $pattern)) { return $true }
    }
    return $false
}

function Remove-RoleIdentityMetadata {
    foreach ($path in @($pidPath, $connectionPath, $endpointPath)) {
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Force -ErrorAction Stop
        }
    }
}

function Get-EndpointListeners {
    if ($null -eq $connection -or [int]$connection.port -le 0) {
        return @()
    }
    return @(
        Get-NetTCPConnection -State Listen -ErrorAction Stop |
            Where-Object { [int]$_.LocalPort -eq [int]$connection.port }
    )
}

function Get-EndpointCount {
    return @(Get-EndpointListeners).Count
}

function Get-OwnedProcessRows {
    if ($null -eq $connection) {
        return @()
    }
    $expectedExe = [string]$connection.godot_path
    return @(
        Get-CimInstance Win32_Process -ErrorAction Stop |
        Where-Object {
            [string]$_.ExecutablePath -ieq $expectedExe -and
            (Test-CommandLineWorktreeBinding `
                -CommandLine ([string]$_.CommandLine) `
                -ExpectedRoot $root)
        }
    )
}

function Get-OwnedProcessCount {
    return @(Get-OwnedProcessRows).Count
}

if (-not (Test-Path -LiteralPath $pidPath)) {
    $endpointCount = Get-EndpointCount
    $ownedCount = Get-OwnedProcessCount
    $result = [ordered]@{
        stopped = $endpointCount -eq 0 -and $ownedCount -eq 0
        already_exited = $true
        identity_verified = $false
        pid = if ($null -ne $connection) { [int]$connection.pid } else { 0 }
        process_count_after = $ownedCount
        endpoint_count_after = $endpointCount
    }
    if ($result.stopped) {
        Remove-RoleIdentityMetadata
    }
    $result | ConvertTo-Json -Depth 5
    if (-not $result.stopped) { exit 1 }
    exit 0
}

if ($null -eq $connection) {
    throw "Missing role-local MCP connection metadata: $connectionPath"
}
$reportedRoot = ([string]$connection.worktree).TrimEnd("\")
if (-not $reportedRoot.Equals($root, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Role-local MCP metadata belongs to another worktree: $reportedRoot"
}
$pidText = [IO.File]::ReadAllText($pidPath).Trim()
if ($pidText -notmatch "^\d+$" -or [int]$pidText -ne [int]$connection.pid) {
    throw "Godot PID metadata is invalid or inconsistent."
}

$process = Get-Process -Id ([int]$pidText) -ErrorAction SilentlyContinue
$identityVerified = $false
$wasAlreadyExited = $null -eq $process -or $process.HasExited
$normalCloseRequested = $false
$forcedStop = $false
if ($null -eq $process -or $process.HasExited) {
    $unexpectedListeners = @(Get-EndpointListeners)
    if ($unexpectedListeners.Count -ne 0) {
        throw "Stored role process exited, but its MCP port is owned by another process."
    }
}
if ($null -ne $process -and -not $process.HasExited) {
    try {
        $startIdentityMatches = Test-RoleGodotProcessStartIdentity `
            -ExpectedToken $connection.process_start_time_utc `
            -ActualStartTime $process.StartTime
    } catch {
        throw "Stored role process creation-time token is invalid."
    }
    $actualPath = $process.Path
    $processCommand = Get-CimInstance `
        Win32_Process `
        -Filter "ProcessId = $($process.Id)" `
        -ErrorAction Stop
    $identityVerified = (
        $startIdentityMatches -and
        [string]$actualPath -ieq [string]$connection.godot_path -and
        (Test-CommandLineWorktreeBinding `
            -CommandLine ([string]$processCommand.CommandLine) `
            -ExpectedRoot $root)
    )
    if (-not $identityVerified) {
        throw "Refusing to stop PID $pidText because role identity did not match."
    }
    $listeners = @(Get-EndpointListeners)
    if (
        $listeners.Count -ne 1 -or
        [int]$listeners[0].OwningProcess -ne [int]$pidText -or
        [int]$connection.endpoint_owner_pid -ne [int]$pidText
    ) {
        throw "Refusing to stop because MCP endpoint ownership is inconsistent."
    }
    $normalCloseRequested = $process.CloseMainWindow()
    $exitedNormally = $normalCloseRequested -and $process.WaitForExit(
        $ShutdownTimeoutSeconds * 1000
    )
    if (-not $exitedNormally) {
        Stop-Process -Id $process.Id -Force -ErrorAction Stop
        $forcedStop = $true
        if (-not $process.WaitForExit($ShutdownTimeoutSeconds * 1000)) {
            throw "Verified role Godot did not exit after scoped force-stop (PID $pidText)."
        }
    }
}

$deadline = [DateTime]::UtcNow.AddSeconds($ShutdownTimeoutSeconds)
do {
    $endpointCount = Get-EndpointCount
    $ownedCount = Get-OwnedProcessCount
    if ($endpointCount -eq 0 -and $ownedCount -eq 0) { break }
    Start-Sleep -Milliseconds 100
} while ([DateTime]::UtcNow -lt $deadline)

$stopped = $endpointCount -eq 0 -and $ownedCount -eq 0
if ($stopped) {
    Remove-RoleIdentityMetadata
}

$result = [ordered]@{
    stopped = $stopped
    already_exited = $wasAlreadyExited
    identity_verified = $identityVerified
    normal_close_requested = $normalCloseRequested
    forced_stop = $forcedStop
    pid = [int]$pidText
    process_count_after = $ownedCount
    endpoint_count_after = $endpointCount
}
$result | ConvertTo-Json -Depth 5
if (-not $result.stopped) { exit 1 }
