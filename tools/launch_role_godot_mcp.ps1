param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Supervisor", "A", "B", "C")]
    [string]$Role,

    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 65535)]
    [int]$Port,

    [string]$Worktree = (Get-Location).Path,

    [string]$GodotPath = "C:\Users\zhuye\AppData\Local\Programs\Godot\4.7\Godot_v4.7-stable_win64.exe",

    [ValidateSet("compatibility", "compatibility_angle", "forward_plus")]
    [string]$Renderer = "compatibility",

    [ValidateRange(30, 900)]
    [int]$StartupTimeoutSeconds = 300,

    [ValidateRange(1, 30)]
    [int]$HttpTimeoutSeconds = 3,

    [bool]$RequireFreshProjectCache = $true,

    [ValidatePattern("^[a-zA-Z0-9._-]*$")]
    [string]$SessionId = ""
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "role_godot_mcp_common.ps1")

$root = (Resolve-Path -LiteralPath $Worktree).Path.TrimEnd("\")
if (-not (Test-Path -LiteralPath (Join-Path $root "project.godot"))) {
    throw "Not a Godot worktree: $root"
}
if (-not (Test-Path -LiteralPath (Join-Path $root "addons\funplay_mcp\plugin.cfg"))) {
    throw "Funplay MCP addon is missing from: $root"
}
if (-not (Test-Path -LiteralPath $GodotPath)) {
    throw "Godot executable is missing: $GodotPath"
}

$projectCachePath = Join-Path $root ".godot"
if ($RequireFreshProjectCache -and (Test-Path -LiteralPath $projectCachePath)) {
    throw "MCP_PROJECT_CACHE_NOT_FRESH|path=$projectCachePath"
}

$roleSlug = $Role.ToLowerInvariant()
if ($SessionId -eq "") {
    $SessionId = "{0}-{1}-{2}" -f $roleSlug, (Get-Date -Format "yyyyMMddTHHmmssfff"), ([guid]::NewGuid().ToString("N").Substring(0, 8))
}
$controlRoot = Join-Path $root ".codex-godot"
$sessionsRoot = Join-Path $controlRoot "sessions"
$sessionRoot = Join-Path $sessionsRoot $SessionId
if (Test-Path -LiteralPath $sessionRoot) {
    throw "MCP_SESSION_ID_ALREADY_EXISTS|session_id=$SessionId|path=$sessionRoot"
}

$roamingRoot = Join-Path $sessionRoot "appdata-roaming"
$localAppDataRoot = Join-Path $sessionRoot "appdata-local"
$logRoot = Join-Path $sessionRoot "logs"
$tokenPath = Join-Path $sessionRoot "auth.token"
$endpointPath = Join-Path $sessionRoot "endpoint.txt"
$connectionPath = Join-Path $sessionRoot "connection.json"
$pidPath = Join-Path $sessionRoot "godot.pid"
$failurePath = Join-Path $sessionRoot "launch-failure.json"
$activeSessionPath = Join-Path $controlRoot "active-session.json"
foreach ($directory in @($controlRoot, $sessionsRoot, $sessionRoot, $roamingRoot, $localAppDataRoot, $logRoot)) {
    [System.IO.Directory]::CreateDirectory($directory) | Out-Null
}

if (Test-Path -LiteralPath $activeSessionPath) {
    try {
        $prior = Get-McpActiveSession -ControlRoot $controlRoot
        $priorIdentity = Test-McpProcessIdentity -Connection $prior.connection
        if ([bool]$priorIdentity.valid) {
            throw "MCP_ACTIVE_SESSION_STILL_RUNNING|pid=$($prior.connection.pid)|session_id=$($prior.connection.session_id)"
        }
    } catch {
        if ($_.Exception.Message -like "MCP_ACTIVE_SESSION_STILL_RUNNING*") {
            throw
        }
    }
}

$tokenBytes = New-Object byte[] 32
[System.Security.Cryptography.RandomNumberGenerator]::Fill($tokenBytes)
$token = [System.Convert]::ToHexString($tokenBytes).ToLowerInvariant()
Write-McpUtf8File -Path $tokenPath -Text $token

$projectText = [System.IO.File]::ReadAllText((Join-Path $root "project.godot"))
$projectNameMatch = [regex]::Match($projectText, '(?m)^config/name="([^"]+)"')
$projectName = if ($projectNameMatch.Success) { $projectNameMatch.Groups[1].Value } else { "SpaceSyndicate" }
$settingsDirectory = Join-Path $roamingRoot ("Godot\app_userdata\{0}" -f $projectName)
[System.IO.Directory]::CreateDirectory($settingsDirectory) | Out-Null
$filesystemReadinessPath = Join-Path $settingsDirectory "funplay_mcp_filesystem_readiness.json"
$settingsText = @"
[server]

enabled=true
port=$Port
auth_token="$token"
tool_profile="core"
debug_logging_enabled=false
execute_code_safety_checks_enabled=true

[tools]

disabled=Array[String]([])
"@
Write-McpUtf8File -Path (Join-Path $settingsDirectory "funplay_mcp_settings.cfg") -Text $settingsText

$endpoint = "http://127.0.0.1:$Port/"
Write-McpUtf8File -Path $endpointPath -Text $endpoint
$logPath = Join-Path $logRoot "godot.log"
$stdoutPath = Join-Path $logRoot "editor.stdout.log"
$stderrPath = Join-Path $logRoot "editor.stderr.log"
$renderingMethod = if ($Renderer -eq "forward_plus") { "forward_plus" } else { "gl_compatibility" }
$renderingDriver = switch ($Renderer) {
    "compatibility" { "opengl3" }
    "compatibility_angle" { "opengl3_angle" }
    default { "vulkan" }
}
$arguments = @(
    "--editor",
    "--path", ('"' + $root + '"'),
    "--log-file", ('"' + $logPath + '"'),
    "--rendering-method", $renderingMethod,
    "--rendering-driver", $renderingDriver,
    "--resolution", "1600x960",
    "--position", "40,40"
)
$argumentString = $arguments -join " "
$environment = @{
    "APPDATA" = $roamingRoot
    "LOCALAPPDATA" = $localAppDataRoot
}
$startProcessParameters = @{
    FilePath = $GodotPath
    ArgumentList = $argumentString
    Environment = $environment
    RedirectStandardOutput = $stdoutPath
    RedirectStandardError = $stderrPath
    WorkingDirectory = $root
    PassThru = $true
    WindowStyle = "Hidden"
}

$process = $null
$launchSucceeded = $false
try {
    $process = Start-Process @startProcessParameters
    $identity = Get-McpProcessIdentity -Process $process
    if ($null -eq $identity) {
        throw "editor_process_exited_before_ready|stage=launch"
    }
    Write-McpUtf8File -Path $pidPath -Text ([string]$process.Id)

    $deadline = [DateTimeOffset]::Now.AddSeconds($StartupTimeoutSeconds)
    $filesystemReadiness = $null
    $endpointObserved = $false
    while ([DateTimeOffset]::Now -lt $deadline) {
        $process.Refresh()
        if ($process.HasExited) {
            $native = Get-McpNativeExitEvidence -LogPath $logPath -ExitCode $process.ExitCode
            throw "editor_process_exited_before_ready|exit_code=$($native.exit_code)|signal=$($native.signal)|log=$logPath"
        }

        $listenerPid = Get-McpEndpointOwnerPid -Port $Port
        if ($listenerPid -ne 0) {
            $endpointObserved = $true
            if ($listenerPid -ne $process.Id) {
                throw "mcp_endpoint_process_mismatch|expected_pid=$($process.Id)|actual_pid=$listenerPid"
            }
        }

        if (Test-Path -LiteralPath $filesystemReadinessPath) {
            try {
                $candidateReadiness = Get-Content -Raw -LiteralPath $filesystemReadinessPath | ConvertFrom-Json
                if ([int]$candidateReadiness.editor_pid -ne $process.Id) {
                    throw "mcp_readiness_editor_pid_mismatch|expected_pid=$($process.Id)|actual_pid=$($candidateReadiness.editor_pid)"
                }
                $filesystemReadiness = $candidateReadiness
                if ([string]$filesystemReadiness.state -eq "failed") {
                    throw "mcp_initial_scan_failed|path=$filesystemReadinessPath"
                }
                if ([bool]$filesystemReadiness.initial_scan_completed -and [string]$filesystemReadiness.state -eq "ready") {
                    break
                }
            } catch {
                if ($_.Exception.Message -like "mcp_*_mismatch*" -or $_.Exception.Message -like "mcp_initial_scan_failed*") {
                    throw
                }
                $filesystemReadiness = $null
            }
        }
        Start-Sleep -Milliseconds 250
    }

    if ($null -eq $filesystemReadiness -or -not [bool]$filesystemReadiness.initial_scan_completed) {
        throw "initial_scan_timeout|pid=$($process.Id)|endpoint=$endpoint|readiness=$filesystemReadinessPath|log=$logPath"
    }
    if (-not $endpointObserved) {
        throw "mcp_endpoint_not_ready_after_initial_scan|pid=$($process.Id)|endpoint=$endpoint|log=$logPath"
    }

    $headers = @{
        "X-Funplay-MCP-Token" = $token
        "MCP-Protocol-Version" = "2025-11-25"
    }
    $projectInfo = $null
    $filesystemStatus = $null
    $postReadyDeadline = [DateTimeOffset]::Now.AddSeconds(30)
    while ([DateTimeOffset]::Now -lt $postReadyDeadline) {
        $process.Refresh()
        if ($process.HasExited) {
            $native = Get-McpNativeExitEvidence -LogPath $logPath -ExitCode $process.ExitCode
            throw "editor_process_exited_after_ready|exit_code=$($native.exit_code)|signal=$($native.signal)|log=$logPath"
        }
        try {
            $body = @{
                jsonrpc = "2.0"
                id = [guid]::NewGuid().ToString("N")
                method = "tools/call"
                params = @{ name = "get_project_info"; arguments = @{} }
            } | ConvertTo-Json -Depth 10 -Compress
            $response = Invoke-RestMethod -Uri $endpoint -Method Post -Headers $headers -ContentType "application/json" -Body $body -TimeoutSec $HttpTimeoutSeconds
            $projectInfo = $response.result.content[0].text | ConvertFrom-Json

            $body = @{
                jsonrpc = "2.0"
                id = [guid]::NewGuid().ToString("N")
                method = "tools/call"
                params = @{ name = "filesystem_scan_status"; arguments = @{} }
            } | ConvertTo-Json -Depth 10 -Compress
            $response = Invoke-RestMethod -Uri $endpoint -Method Post -Headers $headers -ContentType "application/json" -Body $body -TimeoutSec $HttpTimeoutSeconds
            $filesystemStatus = $response.result.content[0].text | ConvertFrom-Json
            if ([int]$filesystemStatus.editor_pid -ne $process.Id) {
                throw "mcp_endpoint_editor_pid_mismatch|expected_pid=$($process.Id)|actual_pid=$($filesystemStatus.editor_pid)"
            }
            if ([bool]$filesystemStatus.initial_scan_completed -and [string]$filesystemStatus.state -eq "ready") {
                break
            }
        } catch {
            $process.Refresh()
            if ($process.HasExited) {
                $native = Get-McpNativeExitEvidence -LogPath $logPath -ExitCode $process.ExitCode
                throw "editor_process_exited_before_ready|exit_code=$($native.exit_code)|signal=$($native.signal)|log=$logPath"
            }
            if ($_.Exception.Message -like "mcp_endpoint_*_mismatch*") {
                throw
            }
        }
        Start-Sleep -Milliseconds 250
    }

    if ($null -eq $projectInfo) {
        $reason = if ((Get-McpEndpointOwnerPid -Port $Port) -eq 0) { "mcp_endpoint_died_after_ready" } else { "mcp_endpoint_unresponsive_after_ready" }
        throw "$reason|pid=$($process.Id)|endpoint=$endpoint|log=$logPath"
    }
    if ($null -eq $filesystemStatus -or -not [bool]$filesystemStatus.initial_scan_completed) {
        throw "initial_scan_timeout|pid=$($process.Id)|endpoint=$endpoint|log=$logPath"
    }

    $reportedRoot = ([string]$projectInfo.project_root).Replace("/", "\").TrimEnd("\")
    if (-not $reportedRoot.Equals($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "mcp_endpoint_project_mismatch|expected=$root|actual=$reportedRoot"
    }

    $connection = [ordered]@{
        schema = "RoleGodotMcpConnectionV2"
        session_id = $SessionId
        launch_nonce = [guid]::NewGuid().ToString("N")
        role = $Role
        endpoint = $endpoint
        port = $Port
        endpoint_owner_pid = Get-McpEndpointOwnerPid -Port $Port
        pid = $process.Id
        process_start_time_utc = [string]$identity.start_time_utc
        godot_path = [string]$identity.executable_path
        worktree = $root
        project_cache_path = $projectCachePath
        project_cache_was_fresh = $RequireFreshProjectCache
        user_data_path = $roamingRoot
        local_app_data_path = $localAppDataRoot
        session_root = $sessionRoot
        token_path = $tokenPath
        log_path = $logPath
        stdout_path = $stdoutPath
        stderr_path = $stderrPath
        godot_version = [string]$projectInfo.godot_version.string
        tool_profile = [string]$projectInfo.tool_profile
        renderer = $Renderer
        rendering_method = $renderingMethod
        rendering_driver = $renderingDriver
        filesystem_state = [string]$filesystemStatus.state
        filesystem_generation = [int]$filesystemStatus.filesystem_generation
        filesystem_state_writer_count = [int]$filesystemStatus.filesystem_state_writer_count
        readiness_file_path = $filesystemReadinessPath
        pre_http_readiness_green = $true
        http_request_count_before_readiness = 0
        launched_at = [DateTimeOffset]::Now.ToString("o")
    }
    Write-McpUtf8File -Path $connectionPath -Text ($connection | ConvertTo-Json -Depth 8)
    $active = [ordered]@{
        session_id = $SessionId
        connection_path = $connectionPath
        activated_at = [DateTimeOffset]::Now.ToString("o")
    }
    Write-McpUtf8File -Path $activeSessionPath -Text ($active | ConvertTo-Json -Depth 4)
    $launchSucceeded = $true
    $connection | ConvertTo-Json -Depth 8
} catch {
    $failureMessage = $_.Exception.Message
    $cleanup = $null
    if ($null -ne $process) {
        $process.Refresh()
        if (-not $process.HasExited) {
            $cleanup = Stop-McpBoundProcess -Process $process -TimeoutSeconds 10 -AllowForcedCleanup
        }
    }
    $exitCode = if ($null -ne $process -and $process.HasExited) { $process.ExitCode } else { 0 }
    $native = Get-McpNativeExitEvidence -LogPath $logPath -ExitCode $exitCode
    $failure = [ordered]@{
        schema = "RoleGodotMcpLaunchFailureV1"
        session_id = $SessionId
        reason = $failureMessage
        editor_pid = if ($null -ne $process) { $process.Id } else { 0 }
        exit_code = $native.exit_code
        signal = $native.signal
        endpoint = $endpoint
        endpoint_alive = (Get-McpEndpointOwnerPid -Port $Port) -ne 0
        cleanup = $cleanup
        log_path = $logPath
        failed_at = [DateTimeOffset]::Now.ToString("o")
    }
    Write-McpUtf8File -Path $failurePath -Text ($failure | ConvertTo-Json -Depth 8)
    throw $failureMessage
} finally {
    if (-not $launchSucceeded -and (Test-Path -LiteralPath $activeSessionPath)) {
        try {
            $active = Get-Content -Raw -LiteralPath $activeSessionPath | ConvertFrom-Json
            if ([string]$active.session_id -eq $SessionId) {
                Remove-Item -LiteralPath $activeSessionPath -Force
            }
        } catch {
        }
    }
}
