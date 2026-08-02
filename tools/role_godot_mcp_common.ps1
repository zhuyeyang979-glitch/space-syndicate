Set-StrictMode -Version Latest

function Write-McpUtf8File {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    $directory = [System.IO.Path]::GetDirectoryName($Path)
    [System.IO.Directory]::CreateDirectory($directory) | Out-Null
    $temporaryPath = "$Path.$PID.$([guid]::NewGuid().ToString('N')).tmp"
    [System.IO.File]::WriteAllText($temporaryPath, $Text, [System.Text.UTF8Encoding]::new($false))
    if ([System.IO.File]::Exists($Path)) {
        [System.IO.File]::Replace($temporaryPath, $Path, $null)
    } else {
        [System.IO.File]::Move($temporaryPath, $Path)
    }
}

function Get-McpProcessIdentity {
    param(
        [Parameter(Mandatory = $true)]
        [System.Diagnostics.Process]$Process
    )

    $Process.Refresh()
    if ($Process.HasExited) {
        return $null
    }
    return [ordered]@{
        pid = $Process.Id
        start_time_utc = $Process.StartTime.ToUniversalTime().ToString("o")
        executable_path = $Process.MainModule.FileName
    }
}

function Test-McpProcessIdentity {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Connection
    )

    $process = Get-Process -Id ([int]$Connection.pid) -ErrorAction SilentlyContinue
    if ($null -eq $process -or $process.HasExited) {
        return [ordered]@{ valid = $false; reason_code = "editor_process_exited"; process = $null }
    }

    try {
        $actualStart = $process.StartTime.ToUniversalTime().ToString("o")
        $actualPath = $process.MainModule.FileName
    } catch {
        return [ordered]@{ valid = $false; reason_code = "editor_process_identity_unavailable"; process = $process }
    }

    if (-not $actualStart.Equals([string]$Connection.process_start_time_utc, [System.StringComparison]::Ordinal)) {
        return [ordered]@{ valid = $false; reason_code = "editor_pid_reused"; process = $process }
    }
    if (-not $actualPath.Equals([string]$Connection.godot_path, [System.StringComparison]::OrdinalIgnoreCase)) {
        return [ordered]@{ valid = $false; reason_code = "editor_executable_mismatch"; process = $process }
    }
    return [ordered]@{ valid = $true; reason_code = "none"; process = $process }
}

function Get-McpEndpointOwnerPid {
    param(
        [Parameter(Mandatory = $true)]
        [int]$Port
    )

    $listeners = @(Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue)
    if ($listeners.Count -eq 0) {
        return 0
    }
    $ownerPids = @($listeners | Select-Object -ExpandProperty OwningProcess -Unique)
    if ($ownerPids.Count -ne 1) {
        return -1
    }
    return [int]$ownerPids[0]
}

function Get-McpNativeExitEvidence {
    param(
        [string]$LogPath,
        [int]$ExitCode
    )

    $logText = ""
    if ($LogPath -ne "" -and (Test-Path -LiteralPath $LogPath)) {
        $logText = [System.IO.File]::ReadAllText($LogPath)
    }
    $signalMatch = [regex]::Match($logText, 'Program crashed with signal\s+(\d+)')
    $signal = if ($signalMatch.Success) { [int]$signalMatch.Groups[1].Value } else { 0 }
    return [ordered]@{
        exit_code = $ExitCode
        signal = $signal
        log_path = $LogPath
    }
}

function Get-McpActiveSession {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ControlRoot
    )

    $activePath = Join-Path $ControlRoot "active-session.json"
    if (-not (Test-Path -LiteralPath $activePath)) {
        throw "Missing active MCP session metadata: $activePath"
    }
    $active = Get-Content -Raw -LiteralPath $activePath | ConvertFrom-Json
    if (-not (Test-Path -LiteralPath ([string]$active.connection_path))) {
        throw "Missing active MCP connection metadata: $($active.connection_path)"
    }
    return [ordered]@{
        active_path = $activePath
        active = $active
        connection = Get-Content -Raw -LiteralPath ([string]$active.connection_path) | ConvertFrom-Json
    }
}

function Stop-McpBoundProcess {
    param(
        [Parameter(Mandatory = $true)]
        [System.Diagnostics.Process]$Process,
        [Parameter(Mandatory = $true)]
        [int]$TimeoutSeconds,
        [switch]$AllowForcedCleanup
    )

    $acceptedClose = $Process.CloseMainWindow()
    $cleanStop = $acceptedClose -and $Process.WaitForExit($TimeoutSeconds * 1000)
    $forced = $false
    if (-not $cleanStop -and $AllowForcedCleanup -and -not $Process.HasExited) {
        Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
        $Process.WaitForExit(5000) | Out-Null
        $forced = $true
    }
    return [ordered]@{
        stopped = $Process.HasExited
        clean_stop = $cleanStop
        forced = $forced
        close_accepted = $acceptedClose
    }
}
