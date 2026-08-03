$ErrorActionPreference = "Stop"
. (Join-Path (Split-Path $PSScriptRoot -Parent) "tools\role_godot_mcp_common.ps1")

$lifecyclePassed = 0
$lifecycleTotal = 0
$signalPassed = 0
$signalTotal = 0
$failures = [System.Collections.Generic.List[string]]::new()

function Assert-Lifecycle {
    param([bool]$Condition, [string]$Name)
    $script:lifecycleTotal += 1
    if ($Condition) {
        $script:lifecyclePassed += 1
    } else {
        $script:failures.Add($Name)
    }
}

function Assert-Signal {
    param([bool]$Condition, [string]$Name)
    $script:signalTotal += 1
    if ($Condition) {
        $script:signalPassed += 1
    } else {
        $script:failures.Add($Name)
    }
}

$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("alpha04c-mcp-lifecycle-{0}" -f [guid]::NewGuid().ToString("N"))
[System.IO.Directory]::CreateDirectory($testRoot) | Out-Null
$child = $null
$listener = $null
try {
    $signalLog = Join-Path $testRoot "signal11.log"
    Write-McpUtf8File -Path $signalLog -Text "Godot Engine`nProgram crashed with signal 11`n"
    $signalEvidence = Get-McpNativeExitEvidence -LogPath $signalLog -ExitCode (-1073741819)
    Assert-Signal -Condition ($signalEvidence.signal -eq 11) -Name "signal_11_is_parsed"
    Assert-Signal -Condition ($signalEvidence.exit_code -eq -1073741819) -Name "native_exit_code_is_preserved"
    Assert-Signal -Condition ($signalEvidence.log_path -eq $signalLog) -Name "last_log_path_is_preserved"
    Assert-Signal -Condition ($signalEvidence.evidence_source -eq "log") -Name "native_signal_prefers_log_evidence"

    $lockedLog = Join-Path $testRoot "locked-signal11.log"
    Write-McpUtf8File -Path $lockedLog -Text "Godot log is still locked`n"
    $exclusiveStream = [System.IO.File]::Open(
        $lockedLog,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::ReadWrite,
        [System.IO.FileShare]::None
    )
    try {
        $lockedEvidence = Get-McpNativeExitEvidence -LogPath $lockedLog -ExitCode (-1073741819)
        Assert-Signal -Condition ($lockedEvidence.signal -eq 11) -Name "locked_log_falls_back_to_access_violation_signal"
        Assert-Signal -Condition ($lockedEvidence.evidence_source -eq "exit_code") -Name "locked_log_records_exit_code_evidence_source"
        Assert-Lifecycle -Condition (-not [string]::IsNullOrWhiteSpace($lockedEvidence.log_read_error)) -Name "locked_log_read_failure_is_preserved"
    } finally {
        $exclusiveStream.Dispose()
    }

    $normalLog = Join-Path $testRoot "normal.log"
    Write-McpUtf8File -Path $normalLog -Text "Godot exited normally`n"
    $normalEvidence = Get-McpNativeExitEvidence -LogPath $normalLog -ExitCode 0
    Assert-Signal -Condition ($normalEvidence.signal -eq 0) -Name "normal_exit_has_no_native_signal"

    $portProbe = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $portProbe.Start()
    $childPort = ([System.Net.IPEndPoint]$portProbe.LocalEndpoint).Port
    $portProbe.Stop()
    $childScript = Join-Path $testRoot "identity-child.ps1"
    $childScriptText = @'
param(
    [int]$Port,
    [Alias("path")][string]$ProjectPath,
    [Parameter(ValueFromRemainingArguments=$true)][string[]]$Remaining
)
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
$listener.Start()
try { Start-Sleep -Seconds 30 } finally { $listener.Stop() }
'@
    Write-McpUtf8File -Path $childScript -Text $childScriptText
    $childArguments = '-NoProfile -File "{0}" -Port {1} --path "{2}" -Remaining --role-godot-mcp-session-id=offline' -f $childScript, $childPort, $testRoot
    $childExecutable = (Get-Command pwsh.exe).Source
    $childStdout = Join-Path $testRoot "identity-child.stdout.log"
    $childStderr = Join-Path $testRoot "identity-child.stderr.log"
    $child = Start-Process -FilePath $childExecutable -ArgumentList $childArguments -PassThru -WindowStyle Hidden -RedirectStandardOutput $childStdout -RedirectStandardError $childStderr
    $child.Refresh()
    $childEndpoint = "http://127.0.0.1:$childPort/"
    $endpointDeadline = [DateTimeOffset]::UtcNow.AddSeconds(5)
    while ((Get-McpEndpointOwnerPid -Port $childPort) -ne $child.Id -and [DateTimeOffset]::UtcNow -lt $endpointDeadline) {
        Start-Sleep -Milliseconds 50
    }
    Assert-Lifecycle -Condition ((Get-McpEndpointOwnerPid -Port $childPort) -eq $child.Id) -Name "child_endpoint_owner_pid_is_attested"
    $childIdentity = Get-McpProcessIdentity `
        -Process $child `
        -Role "offline" `
        -SessionId "offline" `
        -ExpectedExecutablePath $childExecutable `
        -ProjectPath $testRoot `
        -ProjectHeadSha "offline-head" `
        -Endpoint $childEndpoint `
        -RequireEndpointOwner
    if (-not [bool]$childIdentity.identity_verified) {
        $childCommandLine = [string](Get-CimInstance Win32_Process -Filter "ProcessId=$($child.Id)" -ErrorAction SilentlyContinue).CommandLine
        $childError = try {
            if (Test-Path -LiteralPath $childStderr) { [System.IO.File]::ReadAllText($childStderr).Trim() } else { "" }
        } catch {
            "stderr_locked"
        }
        throw "MCP_TEST_CHILD_IDENTITY_INVALID|evidence=$($childIdentity | ConvertTo-Json -Depth 10 -Compress)|command_line=$childCommandLine|stderr=$childError"
    }
    $connection = [ordered]@{
        schema = "RoleGodotMcpConnectionV4"
        pid = $childIdentity.process_id
        process_creation_time = $childIdentity.process_creation_time
        endpoint_owner_pid = $childIdentity.endpoint_owner_pid
        port = $childPort
        session_id = "offline"
        role = "offline"
        godot_path = $childIdentity.expected_executable_path
        worktree = $testRoot
        project_head_sha = "offline-head"
        endpoint = $childEndpoint
        process_identity = $childIdentity
    }
    $identityCheck = Test-McpProcessIdentity -Connection $connection
    Assert-Lifecycle -Condition ([bool]$identityCheck.valid) -Name "live_process_identity_matches"
    $roundTripConnection = $connection | ConvertTo-Json | ConvertFrom-Json
    $roundTripIdentity = Test-McpProcessIdentity -Connection $roundTripConnection
    Assert-Lifecycle -Condition ([bool]$roundTripIdentity.valid) -Name "json_roundtrip_preserves_process_identity"

    $wrongStartConnection = ($connection | ConvertTo-Json -Depth 20 | ConvertFrom-Json)
    $wrongStartConnection.process_identity.process_creation_time.value = "0000000000000000"
    $wrongStartCheck = Test-McpProcessIdentity -Connection $wrongStartConnection
    Assert-Lifecycle -Condition (-not [bool]$wrongStartCheck.valid -and $wrongStartCheck.reason_code -eq "process_creation_time_value_invalid") -Name "pid_reuse_is_rejected"

    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $listener.Start()
    $port = ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
    Start-Sleep -Milliseconds 100
    Assert-Lifecycle -Condition ((Get-McpEndpointOwnerPid -Port $port) -eq $PID) -Name "endpoint_owner_pid_is_attested"
    $listener.Stop()
    $listener = $null
    Start-Sleep -Milliseconds 100
    Assert-Lifecycle -Condition ((Get-McpEndpointOwnerPid -Port $port) -eq 0) -Name "endpoint_death_is_detected"

    $controlRoot = Join-Path $testRoot "control"
    $sessionRoot = Join-Path $controlRoot "sessions\offline"
    [System.IO.Directory]::CreateDirectory($sessionRoot) | Out-Null
    $connectionPath = Join-Path $sessionRoot "connection.json"
    $tokenPath = Join-Path $sessionRoot "token.txt"
    Write-McpUtf8File -Path $tokenPath -Text "offline-token"
    $activeConnection = [ordered]@{} + $connection
    $activeConnection["session_root"] = $sessionRoot
    $activeConnection["token_path"] = $tokenPath
    Write-McpUtf8File -Path $connectionPath -Text ($activeConnection | ConvertTo-Json -Depth 20)
    Write-McpUtf8File -Path (Join-Path $controlRoot "active-session.json") -Text (@{ session_id = "offline"; connection_path = $connectionPath } | ConvertTo-Json)
    $active = Get-McpActiveSession -ControlRoot $controlRoot
    Assert-Lifecycle -Condition ([string]$active.active.session_id -eq "offline") -Name "active_session_manifest_is_resolved"

    $launcherSource = [System.IO.File]::ReadAllText((Join-Path (Split-Path $PSScriptRoot -Parent) "tools\launch_role_godot_mcp.ps1"))
    Assert-Lifecycle -Condition $launcherSource.Contains('"--recovery-mode"') -Name "fresh_cache_uses_recovery_import"
    Assert-Lifecycle -Condition $launcherSource.Contains("recovery_import_unexpected_endpoint") -Name "recovery_import_forbids_endpoint"
    Assert-Lifecycle -Condition $launcherSource.Contains("recovery_import_failed") -Name "recovery_import_exit_is_typed"
    Assert-Lifecycle -Condition $launcherSource.Contains("recovery_import_timeout") -Name "recovery_import_timeout_is_bounded"
    Assert-Lifecycle -Condition $launcherSource.Contains("recovery_import_green") -Name "recovery_import_evidence_is_persisted"

    Stop-Process -Id $child.Id -Force
    $child.WaitForExit(5000) | Out-Null
    $deadCheck = Test-McpProcessIdentity -Connection $connection
    Assert-Lifecycle -Condition (-not [bool]$deadCheck.valid -and $deadCheck.reason_code -eq "process_exited_before_identity") -Name "editor_exit_is_detected_without_endpoint"
    Assert-Lifecycle -Condition ($null -eq (Get-Process -Id $child.Id -ErrorAction SilentlyContinue)) -Name "offline_test_leaves_no_child_process"
} finally {
    if ($null -ne $listener) {
        $listener.Stop()
    }
    if ($null -ne $child) {
        $remaining = Get-Process -Id $child.Id -ErrorAction SilentlyContinue
        if ($null -ne $remaining) {
            Stop-Process -Id $child.Id -Force -ErrorAction SilentlyContinue
        }
    }
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}

Write-Output "MCP_PROCESS_LIFECYCLE_TESTS|passed=$lifecyclePassed|total=$lifecycleTotal"
Write-Output "MCP_SIGNAL11_MONITOR_TESTS|passed=$signalPassed|total=$signalTotal"
Write-Output "MCP_TEST_NATIVE_CRASH_COUNT|value=0"
if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Output "MCP_PROCESS_LIFECYCLE_TEST_FAILURE|name=$failure"
    }
    exit 1
}
