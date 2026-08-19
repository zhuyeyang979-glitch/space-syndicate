[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ObservationRoot,
    [Parameter(Mandatory = $true)][string]$EvidenceRoot,
    [Parameter(Mandatory = $true)][string]$Worktree,
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [Parameter(Mandatory = $true)][string]$LaunchReceiptPath,
    [Parameter(Mandatory = $true)][string]$StopSignalPath,
    [Parameter(Mandatory = $true)][string]$ReadySignalPath,
    [string]$PortsCsv = '7576,7586',
    [ValidateRange(250,5000)][int]$IntervalMilliseconds = 1000
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-AtomicText {
    param([string]$Path, [string]$Text)
    if (Test-Path -LiteralPath $Path) { throw "Refusing overwrite: $Path" }
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Path))) | Out-Null
    $temporary = "$Path.$([Guid]::NewGuid().ToString('N')).tmp"
    try {
        [IO.File]::WriteAllText($temporary, $Text, [Text.UTF8Encoding]::new($false))
        [IO.File]::Move($temporary, $Path, $false)
    } finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
    }
}

function Test-CommandLineWorktreeBinding {
    param([string]$CommandLine, [string]$ExpectedRoot)
    if ([string]::IsNullOrWhiteSpace($CommandLine)) { return $false }
    foreach ($rootForm in @($ExpectedRoot, $ExpectedRoot.Replace('\','/'))) {
        $escapedRoot = [Regex]::Escape($rootForm.TrimEnd('\','/'))
        $pattern = '(?i)(?:^|\s)--path(?:\s+|=)(?:"' + $escapedRoot + '"|' + $escapedRoot + ')(?=\s|$)'
        if ([Regex]::IsMatch($CommandLine, $pattern)) { return $true }
    }
    return $false
}

function Get-FileMeta {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return [ordered]@{ exists=$false; path=''; bytes=0; sha256=''; last_write_utc=$null }
    }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [ordered]@{ exists=$false; path=[IO.Path]::GetFullPath($Path); bytes=0; sha256=''; last_write_utc=$null }
    }
    $item = Get-Item -LiteralPath $Path
    $hash = ''
    try { $hash = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant() } catch { $hash = 'GROWING_OR_LOCKED' }
    return [ordered]@{
        exists = $true
        path = $item.FullName
        bytes = [int64]$item.Length
        sha256 = $hash
        last_write_utc = $item.LastWriteTimeUtc.ToString('o')
    }
}

$root = [IO.Path]::GetFullPath($ObservationRoot)
$evidence = [IO.Path]::GetFullPath($EvidenceRoot)
$worktreeRoot = (Resolve-Path -LiteralPath $Worktree).Path.TrimEnd('\')
$godot = (Resolve-Path -LiteralPath $GodotPath).Path
$timelinePath = Join-Path $root 'watchdog-timeline.jsonl'
$summaryPath = Join-Path $root 'watchdog-summary.json'
foreach ($path in @($timelinePath,$summaryPath,$ReadySignalPath)) {
    if (Test-Path -LiteralPath $path) { throw "Watchdog evidence already exists: $path" }
}
$ports = @(
    $PortsCsv.Split(',') |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne '' } |
        ForEach-Object {
            $value = 0
            if (-not [int]::TryParse($_, [ref]$value) -or $value -lt 1 -or $value -gt 65535) {
                throw "Invalid watchdog port: $_"
            }
            $value
        } |
        Sort-Object -Unique
)
if ($ports.Count -eq 0) { throw 'Watchdog requires at least one port.' }

[IO.Directory]::CreateDirectory($root) | Out-Null
$utf8 = [Text.UTF8Encoding]::new($false)
$started = [DateTimeOffset]::UtcNow
$sampleCount = 0
$gapCount = 0
$lastSample = $null
$firstGodotSample = 0
$watchdogEndpointOwner = $false
$watchdogParentReplacement = $false
$seenProcesses = @{}
$lastStdoutBytes = [int64]0
$lastStderrBytes = [int64]0
$watchdogWrittenPaths = [Collections.Generic.List[string]]::new()
$openHandleCount = 0
$watchdogFailure = $null
$launchPid = 0
$stdoutPath = ''
$stderrPath = ''

$initialRows = @(
    Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object {
            [string]$_.ExecutablePath -ieq $godot -and
            (Test-CommandLineWorktreeBinding -CommandLine ([string]$_.CommandLine) -ExpectedRoot $worktreeRoot)
        }
)
$initialGodotProcessCount = $initialRows.Count
Write-AtomicText -Path $ReadySignalPath -Text ($started.ToString('o'))
$watchdogWrittenPaths.Add([IO.Path]::GetFullPath($ReadySignalPath))

try {
    while (-not (Test-Path -LiteralPath $StopSignalPath)) {
        $now = [DateTimeOffset]::UtcNow
        if ($null -ne $lastSample -and ($now - $lastSample).TotalMilliseconds -gt ($IntervalMilliseconds * 2.5)) {
            $gapCount += 1
        }
        $lastSample = $now
        $sampleCount += 1

        if ($launchPid -eq 0 -and (Test-Path -LiteralPath $LaunchReceiptPath -PathType Leaf)) {
            try {
                $launch = Get-Content -Raw -LiteralPath $LaunchReceiptPath | ConvertFrom-Json -Depth 40
                $launchPid = [int]$launch.pid
                $stdoutPath = [string]$launch.stdout_path
                $stderrPath = [string]$launch.stderr_path
            } catch {}
        }

        $processRows = @(
            Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
                Where-Object {
                    [string]$_.ExecutablePath -ieq $godot -and
                    (Test-CommandLineWorktreeBinding -CommandLine ([string]$_.CommandLine) -ExpectedRoot $worktreeRoot)
                } |
                ForEach-Object {
                    $process = Get-Process -Id ([int]$_.ProcessId) -ErrorAction SilentlyContinue
                    $commandBytes = $utf8.GetBytes([string]$_.CommandLine)
                    $row = [ordered]@{
                        pid = [int]$_.ProcessId
                        parent_pid = [int]$_.ParentProcessId
                        name = [string]$_.Name
                        creation_date = [string]$_.CreationDate
                        command_line_sha256 = [Convert]::ToHexString(
                            [Security.Cryptography.SHA256]::HashData($commandBytes)
                        ).ToLowerInvariant()
                        cpu_seconds = if ($null -ne $process) { [double]$process.CPU } else { $null }
                        working_set_bytes = if ($null -ne $process) { [int64]$process.WorkingSet64 } else { [int64]0 }
                    }
                    $key = [string]$row.pid
                    if (-not $seenProcesses.ContainsKey($key)) {
                        $seenProcesses[$key] = [ordered]@{
                            pid=$row.pid; parent_pid=$row.parent_pid; first_seen_utc=$now.ToString('o');
                            creation_date=$row.creation_date; last_seen_utc=$now.ToString('o'); exited_observed=$false
                        }
                    } else {
                        $seenProcesses[$key].last_seen_utc = $now.ToString('o')
                    }
                    if ($row.parent_pid -eq $PID) { $watchdogParentReplacement = $true }
                    $row
                }
        )
        if ($processRows.Count -gt 0 -and $firstGodotSample -eq 0) { $firstGodotSample = $sampleCount }

        $listeners = @(
            Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
                Where-Object { [int]$_.LocalPort -in $ports } |
                ForEach-Object {
                    if ([int]$_.OwningProcess -eq $PID) { $watchdogEndpointOwner = $true }
                    [ordered]@{ port=[int]$_.LocalPort; owner_pid=[int]$_.OwningProcess; address=[string]$_.LocalAddress }
                }
        )
        $stdoutMeta = Get-FileMeta -Path $stdoutPath
        $stderrMeta = Get-FileMeta -Path $stderrPath
        $stdoutGrowth = [int64]$stdoutMeta.bytes - $lastStdoutBytes
        $stderrGrowth = [int64]$stderrMeta.bytes - $lastStderrBytes
        $lastStdoutBytes = [int64]$stdoutMeta.bytes
        $lastStderrBytes = [int64]$stderrMeta.bytes

        $connectionPath = Join-Path $worktreeRoot '.codex-godot/connection.json'
        $pidPath = Join-Path $worktreeRoot '.codex-godot/godot.pid'
        $endpointPath = Join-Path $worktreeRoot '.codex-godot/endpoint.txt'
        $lockRows = @(Get-ChildItem -LiteralPath (Join-Path $worktreeRoot '.codex-godot') -Filter '*.lock' -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object { Get-FileMeta $_.FullName })
        $heartbeatRows = @(Get-ChildItem -LiteralPath (Join-Path $worktreeRoot '.codex-godot') -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'heartbeat' } | ForEach-Object { Get-FileMeta $_.FullName })
        $milestones = @(
            Get-ChildItem -LiteralPath (Join-Path $evidence 'milestones') -Filter '*.receipt.json' -File -ErrorAction SilentlyContinue |
                Sort-Object Name |
                ForEach-Object {
                    $json = $null
                    try { $json = Get-Content -Raw -LiteralPath $_.FullName | ConvertFrom-Json -Depth 20 } catch {}
                    [ordered]@{
                        name=$_.Name; sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant();
                        milestone_id=if($null-ne$json){[string]$json.milestone_id}else{''};
                        status=if($null-ne$json){[string]$json.status}else{'PARSE_ERROR'}
                    }
                }
        )
        $entry = [ordered]@{
            schema = 'McpStartupWatchdogSampleV1'
            sample_index = $sampleCount
            observed_utc = $now.ToString('o')
            launch_pid = if($launchPid -gt 0){$launchPid}else{$null}
            processes = $processRows
            listeners = $listeners
            stdout = $stdoutMeta
            stdout_growth_bytes = $stdoutGrowth
            stderr = $stderrMeta
            stderr_growth_bytes = $stderrGrowth
            connection = Get-FileMeta -Path $connectionPath
            pid_file = Get-FileMeta -Path $pidPath
            endpoint_file = Get-FileMeta -Path $endpointPath
            locks = $lockRows
            heartbeats = $heartbeatRows
            mcp_raw_count = @(Get-ChildItem -LiteralPath (Join-Path $evidence 'mcp-raw') -File -ErrorAction SilentlyContinue).Count
            phase_count = @(Get-ChildItem -LiteralPath (Join-Path $evidence 'phases') -File -ErrorAction SilentlyContinue).Count
            milestones = $milestones
        }
        [IO.File]::AppendAllText($timelinePath, (($entry | ConvertTo-Json -Depth 30 -Compress) + "`n"), $utf8)
        if (-not $watchdogWrittenPaths.Contains([IO.Path]::GetFullPath($timelinePath))) {
            $watchdogWrittenPaths.Add([IO.Path]::GetFullPath($timelinePath))
        }
        Start-Sleep -Milliseconds $IntervalMilliseconds
    }
} catch {
    $watchdogFailure = $_
} finally {
    $ended = [DateTimeOffset]::UtcNow
    $liveExactProcesses = @(
        Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
            Where-Object {
                [string]$_.ExecutablePath -ieq $godot -and
                (Test-CommandLineWorktreeBinding -CommandLine ([string]$_.CommandLine) -ExpectedRoot $worktreeRoot)
            }
    )
    foreach ($key in @($seenProcesses.Keys)) {
        if (@($liveExactProcesses | Where-Object { [string]$_.ProcessId -ceq $key }).Count -eq 0) {
            $seenProcesses[$key].exited_observed = $true
            $seenProcesses[$key].exit_observed_utc = $ended.ToString('o')
            $seenProcesses[$key].exit_code = 'UNKNOWN'
        }
    }
    $residualListeners = @(
        Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
            Where-Object { [int]$_.LocalPort -in $ports }
    )
    $startedBeforeGodot = (
        $initialGodotProcessCount -eq 0 -and
        $firstGodotSample -gt 1
    )
    $evidenceWriterRole = @(
        $watchdogWrittenPaths |
            Where-Object {
                $_.StartsWith((Join-Path $evidence 'mcp-raw'), [StringComparison]::OrdinalIgnoreCase) -or
                $_.StartsWith((Join-Path $evidence 'phases'), [StringComparison]::OrdinalIgnoreCase)
            }
    ).Count -gt 0
    $statusGreen = (
        $sampleCount -gt 0 -and
        $gapCount -eq 0 -and
        $startedBeforeGodot -and
        $firstGodotSample -gt 0 -and
        -not $watchdogEndpointOwner -and
        -not $watchdogParentReplacement -and
        -not $evidenceWriterRole -and
        $openHandleCount -eq 0 -and
        $null -eq $watchdogFailure -and
        $liveExactProcesses.Count -eq 0 -and
        $residualListeners.Count -eq 0
    )
    $summary = [ordered]@{
        schema = 'McpStartupWatchdogV1'
        status = if($statusGreen){'PASS'}else{'FAIL'}
        started_utc = $started.ToString('o')
        completed_utc = $ended.ToString('o')
        watchdog_pid = $PID
        interval_milliseconds = $IntervalMilliseconds
        ports = $ports
        sample_count = $sampleCount
        observation_gap_count = $gapCount
        initial_godot_process_count = $initialGodotProcessCount
        first_godot_sample_index = $firstGodotSample
        godot_process_observed = $firstGodotSample -gt 0
        started_before_godot_process = $startedBeforeGodot
        endpoint_owner_role = $watchdogEndpointOwner
        evidence_writer_role = $evidenceWriterRole
        product_parent_replacement = $watchdogParentReplacement
        open_handle_count_after = $openHandleCount
        observed_processes = @($seenProcesses.Values)
        residual_exact_godot_process_count = $liveExactProcesses.Count
        residual_port_listener_count = $residualListeners.Count
        timeline_path = [IO.Path]::GetFullPath($timelinePath)
        timeline_sha256 = if(Test-Path -LiteralPath $timelinePath){(Get-FileHash -LiteralPath $timelinePath -Algorithm SHA256).Hash.ToLowerInvariant()}else{''}
        watchdog_written_paths = @($watchdogWrittenPaths)
        failure_detail = if($null-ne$watchdogFailure){$watchdogFailure.Exception.Message}else{''}
    }
    Write-AtomicText -Path $summaryPath -Text ($summary | ConvertTo-Json -Depth 30)
}
if ($null -ne $watchdogFailure) { throw $watchdogFailure }
