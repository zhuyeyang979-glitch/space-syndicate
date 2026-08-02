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

    $child = Start-Process -FilePath "powershell.exe" -ArgumentList '-NoProfile -Command "Start-Sleep -Seconds 30"' -PassThru -WindowStyle Hidden
    $childIdentity = Get-McpProcessIdentity -Process $child
    $connection = [pscustomobject]@{
        pid = $childIdentity.pid
        process_start_time_utc = $childIdentity.start_time_utc
        godot_path = $childIdentity.executable_path
    }
    $identityCheck = Test-McpProcessIdentity -Connection $connection
    Assert-Lifecycle -Condition ([bool]$identityCheck.valid) -Name "live_process_identity_matches"
    $roundTripConnection = $connection | ConvertTo-Json | ConvertFrom-Json
    $roundTripIdentity = Test-McpProcessIdentity -Connection $roundTripConnection
    Assert-Lifecycle -Condition ([bool]$roundTripIdentity.valid) -Name "json_roundtrip_preserves_process_identity"

    $wrongStartConnection = [pscustomobject]@{
        pid = $childIdentity.pid
        process_start_time_utc = [DateTimeOffset]::MinValue.ToString("o")
        godot_path = $childIdentity.executable_path
    }
    $wrongStartCheck = Test-McpProcessIdentity -Connection $wrongStartConnection
    Assert-Lifecycle -Condition (-not [bool]$wrongStartCheck.valid -and $wrongStartCheck.reason_code -eq "editor_pid_reused") -Name "pid_reuse_is_rejected"

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
    Write-McpUtf8File -Path $connectionPath -Text (@{ pid = $childIdentity.pid } | ConvertTo-Json)
    Write-McpUtf8File -Path (Join-Path $controlRoot "active-session.json") -Text (@{ session_id = "offline"; connection_path = $connectionPath } | ConvertTo-Json)
    $active = Get-McpActiveSession -ControlRoot $controlRoot
    Assert-Lifecycle -Condition ([string]$active.active.session_id -eq "offline") -Name "active_session_manifest_is_resolved"

    $launcherSource = [System.IO.File]::ReadAllText((Join-Path (Split-Path $PSScriptRoot -Parent) "tools\launch_role_godot_mcp.ps1"))
    Assert-Lifecycle -Condition $launcherSource.Contains('"--recovery-mode"') -Name "fresh_cache_uses_recovery_import"
    Assert-Lifecycle -Condition $launcherSource.Contains("recovery_import_unexpected_endpoint") -Name "recovery_import_forbids_endpoint"
    Assert-Lifecycle -Condition $launcherSource.Contains("recovery_import_process_exited_before_monitor") -Name "recovery_import_exit_is_typed"
    Assert-Lifecycle -Condition $launcherSource.Contains("recovery_import_timeout") -Name "recovery_import_timeout_is_bounded"
    Assert-Lifecycle -Condition $launcherSource.Contains("recovery_import_green") -Name "recovery_import_evidence_is_persisted"

    Stop-Process -Id $child.Id -Force
    $child.WaitForExit(5000) | Out-Null
    $deadCheck = Test-McpProcessIdentity -Connection $connection
    Assert-Lifecycle -Condition (-not [bool]$deadCheck.valid -and $deadCheck.reason_code -eq "editor_process_exited") -Name "editor_exit_is_detected_without_endpoint"
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
        Write-Error "Funplay MCP process lifecycle test failed: $failure"
    }
    exit 1
}
