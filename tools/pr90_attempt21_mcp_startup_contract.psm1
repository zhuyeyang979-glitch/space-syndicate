Set-StrictMode -Version Latest

function Get-StartupSha256 {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function ConvertTo-StartupCanonicalJson {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][AllowNull()][object]$Value)
    return ($Value | ConvertTo-Json -Depth 100 -Compress)
}

function Get-StartupCanonicalSha256 {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][AllowNull()][object]$Value)
    $copy = ConvertTo-StartupCanonicalJson -Value $Value | ConvertFrom-Json -Depth 100
    if ($null -ne $copy -and $copy.PSObject.Properties.Name -contains 'canonical_payload_sha256') {
        $copy.canonical_payload_sha256 = ''
    }
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes(
        (ConvertTo-StartupCanonicalJson -Value $copy)
    )
    return [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($bytes)
    ).ToLowerInvariant()
}

function Write-StartupImmutableBytes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][byte[]]$Bytes,
        [switch]$WriteSha256Sidecar
    )
    $full = [IO.Path]::GetFullPath($Path)
    if (Test-Path -LiteralPath $full) { throw "Refusing overwrite: $full" }
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($full)) | Out-Null
    $temporary = "$full.$([Guid]::NewGuid().ToString('N')).tmp"
    try {
        [IO.File]::WriteAllBytes($temporary, $Bytes)
        [IO.File]::Move($temporary, $full, $false)
    } finally {
        if (Test-Path -LiteralPath $temporary) {
            Remove-Item -LiteralPath $temporary -Force
        }
    }
    if ($WriteSha256Sidecar) {
        $sidecar = "$full.sha256"
        if (Test-Path -LiteralPath $sidecar) { throw "Refusing overwrite: $sidecar" }
        $line = "$(Get-StartupSha256 -Path $full)  $([IO.Path]::GetFileName($full))`n"
        $null = Write-StartupImmutableBytes -Path $sidecar -Bytes ([Text.UTF8Encoding]::new($false).GetBytes($line))
    }
    return $full
}

function Write-StartupImmutableJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][AllowNull()][object]$Value,
        [switch]$WriteSha256Sidecar
    )
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes(
        ($Value | ConvertTo-Json -Depth 100)
    )
    return Write-StartupImmutableBytes -Path $Path -Bytes $bytes -WriteSha256Sidecar:$WriteSha256Sidecar
}

function Get-McpStartupMilestoneSpecs {
    [CmdletBinding()]
    param()
    return @(
        [pscustomobject]@{ index=0;  id='M0';  name='authorization_validated';                    timeout_seconds=15; failure_class='STARTUP_M0_AUTHORIZATION_VALIDATION_FAILED' },
        [pscustomobject]@{ index=1;  id='M1';  name='execution_start_persisted';                  timeout_seconds=15; failure_class='STARTUP_M1_EXECUTION_START_PERSIST_FAILED' },
        [pscustomobject]@{ index=2;  id='M2';  name='godot_process_created';                      timeout_seconds=15; failure_class='STARTUP_M2_GODOT_PROCESS_CREATE_FAILED' },
        [pscustomobject]@{ index=3;  id='M3';  name='godot_process_identity_verified';            timeout_seconds=15; failure_class='STARTUP_M3_PROCESS_IDENTITY_FAILED' },
        [pscustomobject]@{ index=4;  id='M4';  name='mcp_endpoint_bound';                         timeout_seconds=90; failure_class='STARTUP_M4_ENDPOINT_BIND_TIMEOUT' },
        [pscustomobject]@{ index=5;  id='M5';  name='mcp_endpoint_owner_v2_verified';             timeout_seconds=30; failure_class='STARTUP_M5_ENDPOINT_OWNERSHIP_V2_FAILED' },
        [pscustomobject]@{ index=6;  id='M6';  name='jsonrpc_initialize_or_health_request_sent'; timeout_seconds=15; failure_class='STARTUP_M6_FIRST_JSONRPC_NOT_SENT' },
        [pscustomobject]@{ index=7;  id='M7';  name='first_jsonrpc_response_received';            timeout_seconds=30; failure_class='STARTUP_M7_FIRST_JSONRPC_RESPONSE_TIMEOUT' },
        [pscustomobject]@{ index=8;  id='M8';  name='first_mcp_raw_evidence_persisted';           timeout_seconds=15; failure_class='STARTUP_M8_RAW_WRITER_FAILED' },
        [pscustomobject]@{ index=9;  id='M9';  name='runtime_stream_bootstrap_received';          timeout_seconds=30; failure_class='STARTUP_M9_RUNTIME_STREAM_MISSING' },
        [pscustomobject]@{ index=10; id='M10'; name='ready_witness_persisted';                    timeout_seconds=60; failure_class='STARTUP_M10_READY_WITNESS_MISSING' },
        [pscustomobject]@{ index=11; id='M11'; name='phase_0_evidence_persisted';                 timeout_seconds=15; failure_class='STARTUP_M11_PHASE0_WRITER_FAILED' }
    )
}

function Get-McpStartupSpec {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$MilestoneId)
    $rows = @(Get-McpStartupMilestoneSpecs | Where-Object { $_.id -ceq $MilestoneId })
    if ($rows.Count -ne 1) { throw "Unknown startup milestone: $MilestoneId" }
    return $rows[0]
}

function Get-StartupContextValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Name,
        [AllowNull()][object]$Default = $null
    )
    if ($Context.ContainsKey($Name)) { return $Context[$Name] }
    return $Default
}

function New-McpStartupReceipt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$RunId,
        [Parameter(Mandatory = $true)][string]$ExecutionMode,
        [Parameter(Mandatory = $true)][string]$MilestoneId,
        [Parameter(Mandatory = $true)][ValidateSet('PASS','FAIL')][string]$Status,
        [Parameter(Mandatory = $true)][DateTimeOffset]$Started,
        [Parameter(Mandatory = $true)][DateTimeOffset]$Completed,
        [hashtable]$Context = @{},
        [string]$FailureClass = '',
        [string]$FailureDetail = ''
    )
    $spec = Get-McpStartupSpec -MilestoneId $MilestoneId
    $receipt = [pscustomobject][ordered]@{
        schema = 'McpStartupMilestoneV1'
        run_id = $RunId
        execution_mode = $ExecutionMode
        milestone_index = [int]$spec.index
        milestone_id = $spec.id
        milestone_name = $spec.name
        status = $Status
        started_utc = $Started.ToString('o')
        completed_utc = $Completed.ToString('o')
        elapsed_ms = [int64][Math]::Max(0, ($Completed - $Started).TotalMilliseconds)
        timeout_seconds = [int]$spec.timeout_seconds
        pid = Get-StartupContextValue $Context 'pid'
        parent_pid = Get-StartupContextValue $Context 'parent_pid'
        process_creation_identity = Get-StartupContextValue $Context 'process_creation_identity'
        process_alive = Get-StartupContextValue $Context 'process_alive'
        process_exit_code = Get-StartupContextValue $Context 'process_exit_code'
        cpu_time_delta_ms = Get-StartupContextValue $Context 'cpu_time_delta_ms'
        working_set_bytes = Get-StartupContextValue $Context 'working_set_bytes'
        port = Get-StartupContextValue $Context 'port'
        port_bound = Get-StartupContextValue $Context 'port_bound'
        endpoint_owner_pid = Get-StartupContextValue $Context 'endpoint_owner_pid'
        endpoint_ownership_contract_version = Get-StartupContextValue $Context 'endpoint_ownership_contract_version'
        endpoint_owner_process_role = Get-StartupContextValue $Context 'endpoint_owner_process_role'
        total_listener_sample_count = Get-StartupContextValue $Context 'total_listener_sample_count' 0
        consecutive_parity_sample_count = Get-StartupContextValue $Context 'consecutive_parity_sample_count' 0
        endpoint_owner_stable_window_ms = Get-StartupContextValue $Context 'endpoint_owner_stable_window_ms' 0
        connection_path = Get-StartupContextValue $Context 'connection_path'
        connection_sha256 = Get-StartupContextValue $Context 'connection_sha256'
        session_id = Get-StartupContextValue $Context 'session_id'
        session_id_source = Get-StartupContextValue $Context 'session_id_source' 'tooling_generated'
        stream_id = Get-StartupContextValue $Context 'stream_id'
        request_id = Get-StartupContextValue $Context 'request_id'
        response_id = Get-StartupContextValue $Context 'response_id'
        stdout_path = Get-StartupContextValue $Context 'stdout_path'
        stdout_size = Get-StartupContextValue $Context 'stdout_size' 0
        stderr_path = Get-StartupContextValue $Context 'stderr_path'
        stderr_size = Get-StartupContextValue $Context 'stderr_size' 0
        last_log_lines = Get-StartupContextValue $Context 'last_log_lines' @()
        connection_exists = Get-StartupContextValue $Context 'connection_exists' $false
        lock_exists = Get-StartupContextValue $Context 'lock_exists' $false
        heartbeat_exists = Get-StartupContextValue $Context 'heartbeat_exists' $false
        last_created_evidence_path = Get-StartupContextValue $Context 'last_created_evidence_path'
        evidence_path = Get-StartupContextValue $Context 'evidence_path'
        evidence_sha256 = Get-StartupContextValue $Context 'evidence_sha256'
        failure_class = if ($Status -ceq 'FAIL' -and [string]::IsNullOrWhiteSpace($FailureClass)) {
            $spec.failure_class
        } else { $FailureClass }
        failure_detail = $FailureDetail
        canonical_payload_sha256 = ''
    }
    $receipt.canonical_payload_sha256 = Get-StartupCanonicalSha256 -Value $receipt
    return $receipt
}

function Get-McpStartupMilestonePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$EvidenceRoot,
        [Parameter(Mandatory = $true)][string]$MilestoneId
    )
    $spec = Get-McpStartupSpec -MilestoneId $MilestoneId
    return Join-Path ([IO.Path]::GetFullPath($EvidenceRoot)) (
        'milestones/{0:D2}-{1}-{2}.receipt.json' -f $spec.index, $spec.id, $spec.name
    )
}

function Write-McpStartupMilestone {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$EvidenceRoot,
        [Parameter(Mandatory = $true)][object]$Receipt
    )
    $path = Get-McpStartupMilestonePath -EvidenceRoot $EvidenceRoot -MilestoneId ([string]$Receipt.milestone_id)
    $spec = Get-McpStartupSpec -MilestoneId ([string]$Receipt.milestone_id)
    $existing = @(
        Get-ChildItem -LiteralPath (Join-Path ([IO.Path]::GetFullPath($EvidenceRoot)) 'milestones') `
            -Filter ('{0:D2}-{1}-*.receipt.json' -f $spec.index, $spec.id) `
            -File -ErrorAction SilentlyContinue
    )
    if ($existing.Count -ne 0) { throw "Milestone $($spec.id) already has a terminal receipt." }
    $null = Write-StartupImmutableJson -Path $path -Value $Receipt -WriteSha256Sidecar
    return $path
}

function Read-McpStartupMilestones {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$EvidenceRoot)
    $directory = Join-Path ([IO.Path]::GetFullPath($EvidenceRoot)) 'milestones'
    return @(
        Get-ChildItem -LiteralPath $directory -Filter '*.receipt.json' -File -ErrorAction SilentlyContinue |
            Sort-Object Name |
            ForEach-Object { Get-Content -Raw -LiteralPath $_.FullName | ConvertFrom-Json -Depth 100 -DateKind String }
    )
}

function Test-McpStartupReceiptSequence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Receipts,
        [switch]$RequireComplete
    )
    $expected = @(Get-McpStartupMilestoneSpecs)
    $rows = @($Receipts)
    $duplicateCount = 0
    foreach ($group in @($rows | Group-Object milestone_id)) {
        if ($group.Count -gt 1) { $duplicateCount += ($group.Count - 1) }
    }
    $gapCount = 0
    $outOfOrderCount = 0
    $invalidStatusCount = 0
    $canonicalMismatchCount = 0
    $evidenceMismatchCount = 0
    $timeOrderMismatchCount = 0
    $failCount = @($rows | Where-Object { [string]$_.status -ceq 'FAIL' }).Count
    $passAfterFailCount = 0
    $failureSeen = $false
    $previousCompleted = $null
    for ($index = 0; $index -lt $rows.Count; $index += 1) {
        $row = $rows[$index]
        if ($index -ge $expected.Count -or [string]$row.milestone_id -cne [string]$expected[$index].id) {
            $outOfOrderCount += 1
        }
        if ([string]$row.status -notin @('PASS','FAIL')) { $invalidStatusCount += 1 }
        if ($failureSeen) { $passAfterFailCount += 1 }
        if ([string]$row.status -ceq 'FAIL') { $failureSeen = $true }
        try {
            if ((Get-StartupCanonicalSha256 -Value $row) -cne [string]$row.canonical_payload_sha256) { $canonicalMismatchCount += 1 }
        } catch { $canonicalMismatchCount += 1 }
        if (-not [string]::IsNullOrWhiteSpace([string]$row.evidence_path)) {
            if (-not (Test-Path -LiteralPath ([string]$row.evidence_path) -PathType Leaf)) {
                $evidenceMismatchCount += 1
            } elseif ((Get-StartupSha256 -Path ([string]$row.evidence_path)) -cne [string]$row.evidence_sha256) {
                $evidenceMismatchCount += 1
            }
        }
        try {
            $started = [DateTimeOffset]::Parse([string]$row.started_utc, [Globalization.CultureInfo]::InvariantCulture)
            $completed = [DateTimeOffset]::Parse([string]$row.completed_utc, [Globalization.CultureInfo]::InvariantCulture)
            if ($completed -lt $started -or ($null -ne $previousCompleted -and $started -lt $previousCompleted)) { $timeOrderMismatchCount += 1 }
            $previousCompleted = $completed
        } catch { $timeOrderMismatchCount += 1 }
    }
    if ($RequireComplete -and $rows.Count -ne $expected.Count) {
        $gapCount = [Math]::Abs($expected.Count - $rows.Count)
    }
    $rawIndex = -1
    $phaseIndex = -1
    for ($index = 0; $index -lt $rows.Count; $index += 1) {
        if ([string]$rows[$index].milestone_id -ceq 'M8') { $rawIndex = $index }
        if ([string]$rows[$index].milestone_id -ceq 'M11') { $phaseIndex = $index }
    }
    $rawBeforePhase = ($phaseIndex -lt 0 -or ($rawIndex -ge 0 -and $rawIndex -lt $phaseIndex))
    $prefixGreen = (
        $duplicateCount -eq 0 -and
        $outOfOrderCount -eq 0 -and
        $invalidStatusCount -eq 0 -and
        $failCount -le 1 -and
        $passAfterFailCount -eq 0 -and
        $canonicalMismatchCount -eq 0 -and
        $evidenceMismatchCount -eq 0 -and
        $timeOrderMismatchCount -eq 0 -and
        $rawBeforePhase
    )
    $complete = (
        $prefixGreen -and
        $rows.Count -eq $expected.Count -and
        $failCount -eq 0 -and
        @($rows | Where-Object { [string]$_.status -cne 'PASS' }).Count -eq 0
    )
    return [pscustomobject][ordered]@{
        green = if ($RequireComplete) { $complete } else { $prefixGreen }
        prefix_green = $prefixGreen
        complete = $complete
        receipt_count = $rows.Count
        pass_count = @($rows | Where-Object { [string]$_.status -ceq 'PASS' }).Count
        fail_count = $failCount
        duplicate_count = $duplicateCount
        gap_count = $gapCount
        out_of_order_count = $outOfOrderCount
        invalid_status_count = $invalidStatusCount
        pass_after_fail_count = $passAfterFailCount
        canonical_mismatch_count = $canonicalMismatchCount
        evidence_mismatch_count = $evidenceMismatchCount
        time_order_mismatch_count = $timeOrderMismatchCount
        mcp_raw_before_phase_evidence = $rawBeforePhase
        terminal_milestone = if ($rows.Count -gt 0) { [string]$rows[-1].milestone_id } else { '' }
    }
}

function Get-StartupFileTail {
    [CmdletBinding()]
    param(
        [string]$Path,
        [ValidateRange(256,65536)][int]$MaximumBytes = 16384,
        [ValidateRange(1,100)][int]$MaximumLines = 20
    )
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return @()
    }
    $stream = $null
    try {
        $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
        $count = [int][Math]::Min($MaximumBytes, $stream.Length)
        [void]$stream.Seek(-$count, [IO.SeekOrigin]::End)
        $buffer = [byte[]]::new($count)
        $read = $stream.Read($buffer, 0, $count)
        $text = [Text.UTF8Encoding]::new($false, $false).GetString($buffer, 0, $read)
        return @($text -split "`r?`n" | Select-Object -Last $MaximumLines)
    } finally {
        if ($null -ne $stream) { $stream.Dispose() }
    }
}

function Get-McpStartupProcessSnapshot {
    [CmdletBinding()]
    param(
        [int]$ProcessId = 0,
        [double]$BaselineCpuSeconds = 0,
        [string]$StdoutPath = '',
        [string]$StderrPath = '',
        [int]$Port = 0,
        [string]$EvidenceRoot = '',
        [string]$ConnectionPath = '',
        [string[]]$LockPaths = @(),
        [string[]]$HeartbeatPaths = @()
    )
    $process = if ($ProcessId -gt 0) { Get-Process -Id $ProcessId -ErrorAction SilentlyContinue } else { $null }
    $listeners = @()
    if ($Port -gt 0) {
        $listeners = @(Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue)
    }
    $lastEvidence = $null
    if (-not [string]::IsNullOrWhiteSpace($EvidenceRoot) -and (Test-Path -LiteralPath $EvidenceRoot)) {
        $lastEvidence = Get-ChildItem -LiteralPath $EvidenceRoot -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -ne '.tmp' } |
            Sort-Object LastWriteTimeUtc -Descending |
            Select-Object -First 1
    }
    $stdoutSize = if ($StdoutPath -and (Test-Path -LiteralPath $StdoutPath)) {
        [int64](Get-Item -LiteralPath $StdoutPath).Length
    } else { [int64]0 }
    $stderrSize = if ($StderrPath -and (Test-Path -LiteralPath $StderrPath)) {
        [int64](Get-Item -LiteralPath $StderrPath).Length
    } else { [int64]0 }
    $stdoutTail = @(Get-StartupFileTail -Path $StdoutPath -MaximumLines 10)
    $stderrTail = @(Get-StartupFileTail -Path $StderrPath -MaximumLines 10)
    return [pscustomobject][ordered]@{
        pid = if ($Pid -gt 0) { $Pid } else { $null }
        process_alive = $null -ne $process
        process_exit_code = if ($null -ne $process) { $null } else { 'UNKNOWN' }
        cpu_time_delta_ms = if ($null -ne $process) {
            [int64][Math]::Max(0, (($process.CPU - $BaselineCpuSeconds) * 1000))
        } else { $null }
        working_set_bytes = if ($null -ne $process) { [int64]$process.WorkingSet64 } else { [int64]0 }
        port_bound = $listeners.Count -gt 0
        endpoint_owner_pid = if ($listeners.Count -eq 1) { [int]$listeners[0].OwningProcess } else { $null }
        listener_count = $listeners.Count
        stdout_path = $StdoutPath
        stdout_size = $stdoutSize
        stderr_path = $StderrPath
        stderr_size = $stderrSize
        last_log_lines = @($stdoutTail + $stderrTail | Where-Object { $null -ne $_ })
        connection_exists = (-not [string]::IsNullOrWhiteSpace($ConnectionPath) -and (Test-Path -LiteralPath $ConnectionPath))
        lock_exists = @($LockPaths | Where-Object { Test-Path -LiteralPath $_ }).Count -gt 0
        heartbeat_exists = @($HeartbeatPaths | Where-Object { Test-Path -LiteralPath $_ }).Count -gt 0
        last_created_evidence_path = if ($null -ne $lastEvidence) { $lastEvidence.FullName } else { $null }
    }
}

function ConvertTo-StartupProcessArgument {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value)
    if ($Value.Length -eq 0) { return '""' }
    if ($Value -notmatch '[\s"]') { return $Value }
    $builder = [Text.StringBuilder]::new()
    [void]$builder.Append('"')
    $backslashes = 0
    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq '\') { $backslashes += 1; continue }
        if ($character -eq '"') {
            [void]$builder.Append(('\' * (($backslashes * 2) + 1)))
            [void]$builder.Append('"')
            $backslashes = 0
            continue
        }
        if ($backslashes -gt 0) { [void]$builder.Append(('\' * $backslashes)); $backslashes = 0 }
        [void]$builder.Append($character)
    }
    if ($backslashes -gt 0) { [void]$builder.Append(('\' * ($backslashes * 2))) }
    [void]$builder.Append('"')
    return $builder.ToString()
}

function Start-StartupChildProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$ArgumentList,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [Parameter(Mandatory = $true)][string]$StdoutPath,
        [Parameter(Mandatory = $true)][string]$StderrPath
    )
    foreach ($path in @($StdoutPath, $StderrPath)) {
        if (Test-Path -LiteralPath $path) { throw "Refusing overwrite: $path" }
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($path))) | Out-Null
    }
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = (Resolve-Path -LiteralPath $FilePath).Path
    $info.WorkingDirectory = [IO.Path]::GetFullPath($WorkingDirectory)
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.Arguments = (($ArgumentList | ForEach-Object { ConvertTo-StartupProcessArgument -Value $_ }) -join ' ')
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    if (-not $process.Start()) { throw "Failed to start child process: $FilePath" }
    $stdoutStream = [IO.File]::Open($StdoutPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::ReadWrite)
    $stderrStream = [IO.File]::Open($StderrPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::ReadWrite)
    $stdoutTask = $process.StandardOutput.BaseStream.CopyToAsync($stdoutStream)
    $stderrTask = $process.StandardError.BaseStream.CopyToAsync($stderrStream)
    return [pscustomobject]@{
        process = $process
        stdout_stream = $stdoutStream
        stderr_stream = $stderrStream
        stdout_task = $stdoutTask
        stderr_task = $stderrTask
        stdout_path = [IO.Path]::GetFullPath($StdoutPath)
        stderr_path = [IO.Path]::GetFullPath($StderrPath)
    }
}

function Complete-StartupChildProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Child,
        [ValidateRange(0,3600)][int]$TimeoutSeconds,
        [switch]$KillOnTimeout
    )
    $milliseconds = [int][Math]::Min([int]::MaxValue, $TimeoutSeconds * 1000)
    $exited = $Child.process.WaitForExit($milliseconds)
    if (-not $exited -and $KillOnTimeout) {
        try { $Child.process.Kill($true) } catch {}
        [void]$Child.process.WaitForExit(5000)
    }
    if ($Child.process.HasExited) {
        [void]$Child.stdout_task.Wait(5000)
        [void]$Child.stderr_task.Wait(5000)
    }
    try { $Child.stdout_stream.Flush() } catch {}
    try { $Child.stderr_stream.Flush() } catch {}
    try { $Child.stdout_stream.Dispose() } catch {}
    try { $Child.stderr_stream.Dispose() } catch {}
    return [pscustomobject]@{
        exited = $Child.process.HasExited
        exit_code = if ($Child.process.HasExited) { [int]$Child.process.ExitCode } else { $null }
        pid = [int]$Child.process.Id
        stdout_path = $Child.stdout_path
        stderr_path = $Child.stderr_path
    }
}

function Test-StartupStageElapsed {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$MilestoneId,
        [Parameter(Mandatory = $true)][DateTimeOffset]$Started
    )
    $spec = Get-McpStartupSpec -MilestoneId $MilestoneId
    $elapsed = ([DateTimeOffset]::UtcNow - $Started).TotalSeconds
    if ($elapsed -gt [double]$spec.timeout_seconds) {
        throw "$MilestoneId exceeded its $($spec.timeout_seconds)-second stage timeout."
    }
}

function Get-McpStartupBoundaryClassification {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][hashtable]$Facts)
    function Fact([string]$Name, [object]$Default = $true) {
        if ($Facts.ContainsKey($Name)) { return $Facts[$Name] }
        return $Default
    }
    if (-not [bool](Fact 'process_created')) { return [pscustomobject]@{ milestone='M2'; failure_class='STARTUP_M2_GODOT_PROCESS_CREATE_FAILED'; green=$false } }
    if (-not [bool](Fact 'process_identity_verified')) { return [pscustomobject]@{ milestone='M3'; failure_class='STARTUP_M3_PROCESS_IDENTITY_FAILED'; green=$false } }
    if (-not [bool](Fact 'process_alive_before_endpoint')) { return [pscustomobject]@{ milestone='M4'; failure_class='STARTUP_M4_PROCESS_EXITED_BEFORE_ENDPOINT'; green=$false } }
    if (-not [bool](Fact 'endpoint_bound')) { return [pscustomobject]@{ milestone='M4'; failure_class='STARTUP_M4_ENDPOINT_BIND_TIMEOUT'; green=$false } }
    $ownershipV2Green = if ($Facts.ContainsKey('endpoint_ownership_v2_green')) { [bool](Fact 'endpoint_ownership_v2_green') } else { [bool](Fact 'endpoint_owner_match') }
    if (-not $ownershipV2Green) { return [pscustomobject]@{ milestone='M5'; failure_class='STARTUP_M5_ENDPOINT_OWNERSHIP_V2_FAILED'; green=$false } }
    if (-not [bool](Fact 'connection_file_exists')) { return [pscustomobject]@{ milestone='M5'; failure_class='STARTUP_M5_CONNECTION_FILE_MISSING'; green=$false } }
    if (-not [bool](Fact 'session_id_match')) { return [pscustomobject]@{ milestone='M5'; failure_class='STARTUP_M5_SESSION_ID_MISMATCH'; green=$false } }
    if (-not [bool](Fact 'first_request_sent')) { return [pscustomobject]@{ milestone='M6'; failure_class='STARTUP_M6_FIRST_JSONRPC_NOT_SENT'; green=$false } }
    if (-not [bool](Fact 'first_response_received')) { return [pscustomobject]@{ milestone='M7'; failure_class='STARTUP_M7_FIRST_JSONRPC_RESPONSE_TIMEOUT'; green=$false } }
    if (-not [bool](Fact 'first_response_success')) { return [pscustomobject]@{ milestone='M7'; failure_class='STARTUP_M7_FIRST_JSONRPC_RESPONSE_ERROR'; green=$false } }
    if (-not [bool](Fact 'raw_persisted')) { return [pscustomobject]@{ milestone='M8'; failure_class='STARTUP_M8_RAW_WRITER_FAILED'; green=$false } }
    if (-not [bool](Fact 'stream_received')) { return [pscustomobject]@{ milestone='M9'; failure_class='STARTUP_M9_RUNTIME_STREAM_MISSING'; green=$false } }
    if (-not [bool](Fact 'ready_persisted')) { return [pscustomobject]@{ milestone='M10'; failure_class='STARTUP_M10_READY_WITNESS_MISSING'; green=$false } }
    if (-not [bool](Fact 'phase0_persisted')) { return [pscustomobject]@{ milestone='M11'; failure_class='STARTUP_M11_PHASE0_WRITER_FAILED'; green=$false } }
    if (-not [bool](Fact 'raw_before_phase')) { return [pscustomobject]@{ milestone='M11'; failure_class='STARTUP_M11_PHASE_WRITER_RAN_BEFORE_RAW'; green=$false } }
    if ([int](Fact 'watchdog_gap_count' 0) -ne 0) { return [pscustomobject]@{ milestone='M11'; failure_class='STARTUP_WATCHDOG_OBSERVATION_GAP'; green=$false } }
    if (-not [bool](Fact 'clean_stop')) { return [pscustomobject]@{ milestone='M11'; failure_class='STARTUP_CLEAN_STOP_FAILED'; green=$false } }
    if ([int](Fact 'residual_process_count' 0) -ne 0) { return [pscustomobject]@{ milestone='M11'; failure_class='STARTUP_RESIDUAL_PROCESS'; green=$false } }
    if ([int](Fact 'residual_port_count' 0) -ne 0) { return [pscustomobject]@{ milestone='M11'; failure_class='STARTUP_RESIDUAL_PORT'; green=$false } }
    return [pscustomobject]@{ milestone='M11'; failure_class=''; green=$true }
}

function Get-McpStartupObservationClassification {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][hashtable]$Facts)
    if ($Facts.ContainsKey('stage_timeout_milestone') -and -not [string]::IsNullOrWhiteSpace([string]$Facts.stage_timeout_milestone)) {
        return [pscustomobject]@{ observation_class='STAGE_TIMEOUT'; milestone=[string]$Facts.stage_timeout_milestone; green=$false }
    }
    if ($Facts.ContainsKey('cold_import_unexpected') -and [bool]$Facts.cold_import_unexpected) {
        return [pscustomobject]@{ observation_class='COLD_IMPORT_UNEXPECTED'; milestone='M2'; green=$false }
    }
    if ($Facts.ContainsKey('stderr_error') -and [bool]$Facts.stderr_error) {
        return [pscustomobject]@{ observation_class='STDERR_ERROR'; milestone='M2'; green=$false }
    }
    if ($Facts.ContainsKey('stdout_stalled') -and [bool]$Facts.stdout_stalled) {
        return [pscustomobject]@{ observation_class='STDOUT_STALLED'; milestone='M2'; green=$false }
    }
    if ($Facts.ContainsKey('watchdog_gap_count') -and [int]$Facts.watchdog_gap_count -ne 0) {
        return [pscustomobject]@{ observation_class='WATCHDOG_OBSERVATION_GAP'; milestone='M11'; green=$false }
    }
    return [pscustomobject]@{ observation_class='NONE'; milestone=''; green=$true }
}

Export-ModuleMember -Function @(
    'Get-StartupSha256','ConvertTo-StartupCanonicalJson','Get-StartupCanonicalSha256',
    'Write-StartupImmutableBytes','Write-StartupImmutableJson','Get-McpStartupMilestoneSpecs',
    'Get-McpStartupSpec','New-McpStartupReceipt','Get-McpStartupMilestonePath',
    'Write-McpStartupMilestone','Read-McpStartupMilestones','Test-McpStartupReceiptSequence',
    'Get-StartupFileTail','Get-McpStartupProcessSnapshot','ConvertTo-StartupProcessArgument',
    'Start-StartupChildProcess','Complete-StartupChildProcess','Test-StartupStageElapsed',
    'Get-McpStartupBoundaryClassification','Get-McpStartupObservationClassification'
)
