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
        $actualStart = [DateTimeOffset]$process.StartTime.ToUniversalTime()
        $expectedStart = if ($Connection.process_start_time_utc -is [DateTime]) {
            [DateTimeOffset]$Connection.process_start_time_utc.ToUniversalTime()
        } else {
            [DateTimeOffset]::Parse(
                [string]$Connection.process_start_time_utc,
                [System.Globalization.CultureInfo]::InvariantCulture,
                [System.Globalization.DateTimeStyles]::RoundtripKind
            )
        }
        $actualPath = $process.MainModule.FileName
    } catch {
        return [ordered]@{ valid = $false; reason_code = "editor_process_identity_unavailable"; process = $process }
    }

    $startDeltaTicks = [Math]::Abs($actualStart.UtcDateTime.Ticks - $expectedStart.UtcDateTime.Ticks)
    if ($startDeltaTicks -gt [TimeSpan]::TicksPerMillisecond) {
        return [ordered]@{ valid = $false; reason_code = "editor_pid_reused"; process = $process }
    }
    if (-not $actualPath.Equals([string]$Connection.godot_path, [System.StringComparison]::OrdinalIgnoreCase)) {
        return [ordered]@{ valid = $false; reason_code = "editor_executable_mismatch"; process = $process }
    }
    return [ordered]@{ valid = $true; reason_code = "none"; process = $process }
}

function Get-McpOptionalProperty {
    param(
        [AllowNull()]
        [object]$Object,
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($null -eq $Object) {
        return $null
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
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
    $logReadError = ""
    if ($LogPath -ne "" -and (Test-Path -LiteralPath $LogPath)) {
        $stream = $null
        $reader = $null
        try {
            $share = [System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete
            $stream = [System.IO.File]::Open(
                $LogPath,
                [System.IO.FileMode]::Open,
                [System.IO.FileAccess]::Read,
                $share
            )
            $reader = [System.IO.StreamReader]::new($stream, [System.Text.Encoding]::UTF8, $true)
            $logText = $reader.ReadToEnd()
        } catch {
            $logReadError = $_.Exception.Message
        } finally {
            if ($null -ne $reader) {
                $reader.Dispose()
            } elseif ($null -ne $stream) {
                $stream.Dispose()
            }
        }
    }
    $signalMatch = [regex]::Match($logText, 'Program crashed with signal\s+(\d+)')
    $signal = if ($signalMatch.Success) {
        [int]$signalMatch.Groups[1].Value
    } elseif ($ExitCode -eq -1073741819) {
        11
    } else {
        0
    }
    return [ordered]@{
        exit_code = $ExitCode
        signal = $signal
        log_path = $LogPath
        log_read_error = $logReadError
        evidence_source = if ($signalMatch.Success) { "log" } elseif ($signal -ne 0) { "exit_code" } else { "none" }
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
