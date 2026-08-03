param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Supervisor", "A", "B", "C")]
    [string]$Role,

    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 65535)]
    [int]$Port,

    [string]$Worktree = (Get-Location).Path,

    [string]$RuntimeDataBase = "",

    [string]$GodotPath = "C:\Users\zhuye\AppData\Local\Programs\Godot\4.7\Godot_v4.7-stable_win64.exe",

    [ValidateSet("compatibility", "compatibility_angle", "forward_plus")]
    [string]$Renderer = "compatibility",

    [ValidateRange(30, 900)]
    [int]$StartupTimeoutSeconds = 300,

    [ValidateRange(30, 900)]
    [int]$RecoveryImportTimeoutSeconds = 300,

    [ValidateRange(1, 30)]
    [int]$HttpTimeoutSeconds = 3,

    [ValidateRange(5, 60)]
    [int]$InitialReadyStabilitySeconds = 15,

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
$GodotPath = ConvertTo-McpNormalizedPath -Path $GodotPath
if ($GodotPath -eq "" -or -not (Test-Path -LiteralPath $GodotPath)) {
    throw "Godot executable is missing: $GodotPath"
}
$projectHeadSha = ""
try {
    $gitHead = @(& git -C $root rev-parse HEAD 2>$null)
    if ($LASTEXITCODE -eq 0 -and $gitHead.Count -eq 1 -and [string]$gitHead[0] -match '^[0-9a-fA-F]{40}$') {
        $projectHeadSha = ([string]$gitHead[0]).ToLowerInvariant()
    }
} catch {
    $projectHeadSha = ""
}
if ($projectHeadSha -eq "") {
    $projectBytes = [System.IO.File]::ReadAllBytes((Join-Path $root "project.godot"))
    $projectHash = [System.Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($projectBytes)).ToLowerInvariant()
    $projectHeadSha = "unversioned:$projectHash"
}

$projectCachePath = Join-Path $root ".godot"
$projectCacheWasFresh = -not (Test-Path -LiteralPath $projectCachePath)
if ($RequireFreshProjectCache -and -not $projectCacheWasFresh) {
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

$runtimeDataBasePath = if ($RuntimeDataBase -eq "") {
    Join-Path ([System.IO.Path]::GetTempPath()) "space-syndicate-mcp"
} else {
    [System.IO.Path]::GetFullPath($RuntimeDataBase)
}
$runtimeDataRoot = Join-Path $runtimeDataBasePath $SessionId
if (Test-Path -LiteralPath $runtimeDataRoot) {
    throw "MCP_RUNTIME_DATA_ID_ALREADY_EXISTS|session_id=$SessionId|path=$runtimeDataRoot"
}

$roamingRoot = Join-Path $runtimeDataRoot "r"
$localAppDataRoot = Join-Path $runtimeDataRoot "l"
$tempRoot = Join-Path $runtimeDataRoot "t"
$logRoot = Join-Path $sessionRoot "logs"
$tokenPath = Join-Path $sessionRoot "auth.token"
$endpointPath = Join-Path $sessionRoot "endpoint.txt"
$connectionPath = Join-Path $sessionRoot "connection.json"
$pidPath = Join-Path $sessionRoot "godot.pid"
$recoveryImportPidPath = Join-Path $sessionRoot "recovery-import.pid"
$failurePath = Join-Path $sessionRoot "launch-failure.json"
$activeSessionPath = Join-Path $controlRoot "active-session.json"
foreach ($directory in @($controlRoot, $sessionsRoot, $sessionRoot, $runtimeDataBasePath, $runtimeDataRoot, $roamingRoot, $localAppDataRoot, $tempRoot, $logRoot)) {
    [System.IO.Directory]::CreateDirectory($directory) | Out-Null
}

if (Test-Path -LiteralPath $activeSessionPath) {
    try {
        $prior = Get-McpActiveSession -ControlRoot $controlRoot
        $priorIdentity = Test-McpProcessIdentity -Connection $prior.connection
        if ([bool]$priorIdentity.valid) {
            throw "MCP_ACTIVE_SESSION_STILL_RUNNING|pid=$($prior.connection.pid)|session_id=$($prior.connection.session_id)"
        }
        $priorPid = [int](Get-McpOptionalProperty -Object $prior.connection -Name "pid")
        $priorProcess = if ($priorPid -gt 0) { Get-Process -Id $priorPid -ErrorAction SilentlyContinue } else { $null }
        $priorPort = try { ([Uri]([string]$prior.connection.endpoint)).Port } catch { 0 }
        $priorEndpointOwner = if ($priorPort -gt 0) { Get-McpEndpointOwnerPid -Port $priorPort } else { 0 }
        if ($null -ne $priorProcess -or $priorEndpointOwner -ne 0) {
            throw "MCP_ACTIVE_SESSION_IDENTITY_FAILURE|reason_code=$($priorIdentity.reason_code)|pid=$priorPid|endpoint_owner_pid=$priorEndpointOwner"
        }
    } catch {
        if ($_.Exception.Message -like "MCP_ACTIVE_SESSION_STILL_RUNNING*" -or $_.Exception.Message -like "MCP_ACTIVE_SESSION_IDENTITY_FAILURE*") {
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
$shaderCachePathProbe = Join-Path $settingsDirectory ("shader_cache\SceneForwardClusteredShaderRD\{0}" -f ("0" * 64))
if ($shaderCachePathProbe.Length -ge 240) {
    throw "MCP_RUNTIME_DATA_PATH_TOO_LONG|length=$($shaderCachePathProbe.Length)|path=$shaderCachePathProbe"
}
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
$recoveryImportLogPath = Join-Path $logRoot "recovery-import.godot.log"
$recoveryImportStdoutPath = Join-Path $logRoot "recovery-import.stdout.log"
$recoveryImportStderrPath = Join-Path $logRoot "recovery-import.stderr.log"
$renderingMethod = if ($Renderer -eq "forward_plus") { "forward_plus" } else { "gl_compatibility" }
$renderingDriver = switch ($Renderer) {
    "compatibility" { "opengl3" }
    "compatibility_angle" { "opengl3_angle" }
    default { "vulkan" }
}
$editorArguments = @(
    "--editor",
    "--path", ('"' + $root + '"'),
    "--log-file", ('"' + $logPath + '"'),
    "--rendering-method", $renderingMethod,
    "--rendering-driver", $renderingDriver,
    "--resolution", "1600x960",
    "--position", "40,40",
    "--",
    "--role-godot-mcp-session-id=$SessionId",
    "--role-godot-mcp-role=$Role"
)
$argumentString = $editorArguments -join " "
$recoveryImportArguments = @(
    "--import",
    "--recovery-mode",
    "--path", ('"' + $root + '"'),
    "--log-file", ('"' + $recoveryImportLogPath + '"'),
    "--rendering-method", $renderingMethod,
    "--rendering-driver", $renderingDriver,
    "--",
    "--role-godot-mcp-session-id=$SessionId-recovery-import",
    "--role-godot-mcp-role=$Role-recovery-import"
)
$recoveryImportArgumentString = $recoveryImportArguments -join " "
$environment = @{
    "APPDATA" = $roamingRoot
    "LOCALAPPDATA" = $localAppDataRoot
    "TEMP" = $tempRoot
    "TMP" = $tempRoot
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
$recoveryImportStartProcessParameters = @{
    FilePath = $GodotPath
    ArgumentList = $recoveryImportArgumentString
    Environment = $environment
    RedirectStandardOutput = $recoveryImportStdoutPath
    RedirectStandardError = $recoveryImportStderrPath
    WorkingDirectory = $root
    PassThru = $true
    WindowStyle = "Hidden"
}

$process = $null
$recoveryImportProcess = $null
$recoveryImportIdentity = $null
$recoveryImportCompleted = -not $RequireFreshProjectCache
$recoveryImportStartedAt = $null
$recoveryImportCompletedAt = $null
$launchSucceeded = $false
try {
    if ($RequireFreshProjectCache) {
        $recoveryImportStartedAt = [DateTimeOffset]::Now
        $recoveryImportProcess = Start-Process @recoveryImportStartProcessParameters
        $recoveryImportIdentity = Get-McpProcessIdentity `
            -Process $recoveryImportProcess `
            -Role "$Role-recovery-import" `
            -SessionId "$SessionId-recovery-import" `
            -ExpectedExecutablePath $GodotPath `
            -ProjectPath $root `
            -ProjectHeadSha $projectHeadSha `
            -Endpoint $endpoint
        if (-not [bool]$recoveryImportIdentity.identity_verified) {
            throw "MCP_PROCESS_IDENTITY_FAILURE|stage=recovery_import_launch|reason_code=$($recoveryImportIdentity.failure_reason)|pid=$($recoveryImportProcess.Id)"
        }
        Write-McpUtf8File -Path $recoveryImportPidPath -Text ([string]$recoveryImportProcess.Id)

        $recoveryImportDeadline = [DateTimeOffset]::Now.AddSeconds($RecoveryImportTimeoutSeconds)
        while (-not $recoveryImportProcess.HasExited -and [DateTimeOffset]::Now -lt $recoveryImportDeadline) {
            if ((Get-McpEndpointOwnerPid -Port $Port) -ne 0) {
                throw "recovery_import_unexpected_endpoint|pid=$($recoveryImportProcess.Id)|endpoint=$endpoint"
            }
            Start-Sleep -Milliseconds 100
            $recoveryImportProcess.Refresh()
        }
        if (-not $recoveryImportProcess.HasExited) {
            $recoveryCleanup = Stop-McpBoundProcess -Process $recoveryImportProcess -TimeoutSeconds 10 -AllowForcedCleanup
            throw "recovery_import_timeout|pid=$($recoveryImportProcess.Id)|timeout_seconds=$RecoveryImportTimeoutSeconds|cleanup=$($recoveryCleanup | ConvertTo-Json -Compress)"
        }
        $recoveryImportProcess.WaitForExit()
        $recoveryImportNative = Get-McpNativeExitEvidence -LogPath $recoveryImportLogPath -ExitCode $recoveryImportProcess.ExitCode
        if ($recoveryImportProcess.ExitCode -ne 0) {
            throw "recovery_import_failed|exit_code=$($recoveryImportNative.exit_code)|signal=$($recoveryImportNative.signal)|log=$recoveryImportLogPath"
        }
        if (-not (Test-Path -LiteralPath $projectCachePath)) {
            throw "recovery_import_cache_missing|path=$projectCachePath|log=$recoveryImportLogPath"
        }
        if ((Get-McpEndpointOwnerPid -Port $Port) -ne 0) {
            throw "recovery_import_endpoint_leaked|pid=$($recoveryImportProcess.Id)|endpoint=$endpoint"
        }
        if (Test-Path -LiteralPath $filesystemReadinessPath) {
            throw "recovery_import_plugin_not_disabled|readiness=$filesystemReadinessPath"
        }
        $recoveryImportCompleted = $true
        $recoveryImportCompletedAt = [DateTimeOffset]::Now
    }

    $process = Start-Process @startProcessParameters
    $identity = Get-McpProcessIdentity `
        -Process $process `
        -Role $Role `
        -SessionId $SessionId `
        -ExpectedExecutablePath $GodotPath `
        -ProjectPath $root `
        -ProjectHeadSha $projectHeadSha `
        -Endpoint $endpoint
    if (-not [bool]$identity.identity_verified) {
        throw "MCP_PROCESS_IDENTITY_FAILURE|stage=editor_launch|reason_code=$($identity.failure_reason)|pid=$($process.Id)"
    }
    Write-McpUtf8File -Path $pidPath -Text ([string]$process.Id)

    $deadline = [DateTimeOffset]::Now.AddSeconds($StartupTimeoutSeconds)
    $filesystemReadiness = $null
    $endpointObserved = $false
    $readyObservedAt = $null
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
                    if ($null -eq $readyObservedAt) {
                        $readyObservedAt = [DateTimeOffset]::Now
                    }
                    if (([DateTimeOffset]::Now - $readyObservedAt).TotalSeconds -ge $InitialReadyStabilitySeconds) {
                        break
                    }
                } else {
                    $readyObservedAt = $null
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
    if ($null -eq $readyObservedAt -or ([DateTimeOffset]::Now - $readyObservedAt).TotalSeconds -lt $InitialReadyStabilitySeconds) {
        throw "initial_scan_stability_timeout|pid=$($process.Id)|readiness=$filesystemReadinessPath|log=$logPath"
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

    $verifiedIdentity = Get-McpProcessIdentity `
        -Process $process `
        -Role $Role `
        -SessionId $SessionId `
        -ExpectedExecutablePath $GodotPath `
        -ExpectedCreationTimeUtc ([string]$identity.process_creation_time_utc) `
        -ProjectPath $root `
        -ProjectHeadSha $projectHeadSha `
        -Endpoint $endpoint `
        -RequireEndpointOwner
    if (-not [bool]$verifiedIdentity.identity_verified) {
        throw "MCP_PROCESS_IDENTITY_FAILURE|stage=endpoint_binding|reason_code=$($verifiedIdentity.failure_reason)|pid=$($process.Id)"
    }
    if (-not ([string]$verifiedIdentity.command_line_sha256).Equals([string]$identity.command_line_sha256, [System.StringComparison]::Ordinal)) {
        throw "MCP_PROCESS_IDENTITY_FAILURE|stage=endpoint_binding|reason_code=process_command_line_mismatch|pid=$($process.Id)"
    }

    $connection = [ordered]@{
        schema = "RoleGodotMcpConnectionV3"
        session_id = $SessionId
        launch_nonce = [guid]::NewGuid().ToString("N")
        role = $Role
        endpoint = $endpoint
        port = $Port
        endpoint_owner_pid = [int]$verifiedIdentity.endpoint_owner_pid
        pid = [int]$verifiedIdentity.process_id
        process_start_time_utc = [string]$verifiedIdentity.process_creation_time_utc
        godot_path = [string]$verifiedIdentity.observed_executable_path
        project_head_sha = $projectHeadSha
        process_identity = $verifiedIdentity
        worktree = $root
        project_cache_path = $projectCachePath
        project_cache_was_fresh = $projectCacheWasFresh
        recovery_import_performed = $RequireFreshProjectCache
        recovery_import_green = $recoveryImportCompleted
        recovery_import_pid = if ($null -ne $recoveryImportProcess) { $recoveryImportProcess.Id } else { 0 }
        recovery_import_process_start_time_utc = if ($null -ne $recoveryImportIdentity) { [string]$recoveryImportIdentity.process_creation_time_utc } else { "" }
        recovery_import_started_at = if ($null -ne $recoveryImportStartedAt) { $recoveryImportStartedAt.ToString("o") } else { "" }
        recovery_import_completed_at = if ($null -ne $recoveryImportCompletedAt) { $recoveryImportCompletedAt.ToString("o") } else { "" }
        recovery_import_timeout_seconds = $RecoveryImportTimeoutSeconds
        recovery_import_log_path = $recoveryImportLogPath
        recovery_import_stdout_path = $recoveryImportStdoutPath
        recovery_import_stderr_path = $recoveryImportStderrPath
        recovery_import_endpoint_count = 0
        runtime_data_root = $runtimeDataRoot
        user_data_path = $roamingRoot
        project_user_data_path = $settingsDirectory
        local_app_data_path = $localAppDataRoot
        temp_path = $tempRoot
        runtime_path_length_probe = $shaderCachePathProbe.Length
        runtime_path_length_headroom_green = $true
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
        initial_ready_stability_seconds = $InitialReadyStabilitySeconds
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
    $recoveryCleanup = $null
    if ($null -ne $process) {
        try {
            $expectedCreationTime = if ($null -ne $identity) { [string]$identity.process_creation_time_utc } else { "" }
            $cleanup = Stop-McpBoundProcess `
                -Process $process `
                -TimeoutSeconds 10 `
                -ExpectedCreationTimeUtc $expectedCreationTime `
                -AllowForcedCleanup
        } catch {
            $cleanup = [ordered]@{ stopped = $false; clean_stop = $false; forced = $false; failure_reason = "cleanup_identity_unavailable" }
        }
    }
    if ($null -ne $recoveryImportProcess) {
        try {
            $expectedRecoveryCreationTime = if ($null -ne $recoveryImportIdentity) { [string]$recoveryImportIdentity.process_creation_time_utc } else { "" }
            $recoveryCleanup = Stop-McpBoundProcess `
                -Process $recoveryImportProcess `
                -TimeoutSeconds 10 `
                -ExpectedCreationTimeUtc $expectedRecoveryCreationTime `
                -AllowForcedCleanup
        } catch {
            $recoveryCleanup = [ordered]@{ stopped = $false; clean_stop = $false; forced = $false; failure_reason = "cleanup_identity_unavailable" }
        }
    }
    $failureProcess = if ($null -ne $process) { $process } else { $recoveryImportProcess }
    $failureLogPath = if ($null -ne $process) { $logPath } else { $recoveryImportLogPath }
    $failureHasExited = Get-McpSafeProperty -Object $failureProcess -Name "HasExited"
    $failureExitCode = Get-McpSafeProperty -Object $failureProcess -Name "ExitCode"
    $exitCode = if ($failureHasExited.found `
        -and [string]::IsNullOrWhiteSpace([string]$failureHasExited.error) `
        -and [bool]$failureHasExited.value `
        -and $failureExitCode.found `
        -and [string]::IsNullOrWhiteSpace([string]$failureExitCode.error)) {
        [int]$failureExitCode.value
    } else {
        0
    }
    $editorPidProperty = Get-McpSafeProperty -Object $process -Name "Id"
    $recoveryPidProperty = Get-McpSafeProperty -Object $recoveryImportProcess -Name "Id"
    $native = Get-McpNativeExitEvidence -LogPath $failureLogPath -ExitCode $exitCode
    $failure = [ordered]@{
        schema = "RoleGodotMcpLaunchFailureV1"
        session_id = $SessionId
        reason = $failureMessage
        editor_pid = if ($editorPidProperty.found -and [string]::IsNullOrWhiteSpace([string]$editorPidProperty.error)) { [int]$editorPidProperty.value } else { 0 }
        exit_code = $native.exit_code
        signal = $native.signal
        endpoint = $endpoint
        endpoint_alive = (Get-McpEndpointOwnerPid -Port $Port) -ne 0
        cleanup = $cleanup
        recovery_import_cleanup = $recoveryCleanup
        recovery_import_performed = $RequireFreshProjectCache
        recovery_import_green = $recoveryImportCompleted
        recovery_import_pid = if ($recoveryPidProperty.found -and [string]::IsNullOrWhiteSpace([string]$recoveryPidProperty.error)) { [int]$recoveryPidProperty.value } else { 0 }
        recovery_import_log_path = $recoveryImportLogPath
        runtime_data_root = $runtimeDataRoot
        log_path = $failureLogPath
        failed_at = [DateTimeOffset]::Now.ToString("o")
    }
    Write-McpUtf8File -Path $failurePath -Text ($failure | ConvertTo-Json -Depth 8)
    throw
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
