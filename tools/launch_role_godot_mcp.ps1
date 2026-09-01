param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Supervisor", "A", "B", "C")]
    [string]$Role,

    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 65535)]
    [int]$Port,

    [string]$Worktree = (Get-Location).Path,

    [string]$GodotPath = $env:V075_GODOT_PATH,

    [ValidateSet("compatibility", "forward_plus")]
    [string]$Renderer = "compatibility",

    [ValidateSet("core", "full")]
    [string]$ToolProfile = "core",

    [ValidateRange(640, 7680)]
    [int]$ResolutionWidth = 1600,

    [ValidateRange(480, 4320)]
    [int]$ResolutionHeight = 960,

    [int]$StartupTimeoutSeconds = 90
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    throw "GodotPath is required (or set V075_GODOT_PATH)."
}

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
$resolvedGodotPath = (Resolve-Path -LiteralPath $GodotPath).Path

$roleSlug = $Role.ToLowerInvariant()
$localRoot = Join-Path $root ".codex-godot"
$roamingRoot = Join-Path $localRoot "appdata-roaming"
$localAppDataRoot = Join-Path $localRoot "appdata-local"
$logRoot = Join-Path $localRoot "logs"
$tokenPath = Join-Path $localRoot "auth.token"
$endpointPath = Join-Path $localRoot "endpoint.txt"
$connectionPath = Join-Path $localRoot "connection.json"
$pidPath = Join-Path $localRoot "godot.pid"

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

function Get-PortListeners {
    param([Parameter(Mandatory = $true)][int]$LocalPort)
    return @(
        Get-NetTCPConnection -State Listen -ErrorAction Stop |
            Where-Object { [int]$_.LocalPort -eq $LocalPort }
    )
}

function Get-RoleProcessRows {
    return @(
        Get-CimInstance Win32_Process -ErrorAction Stop |
            Where-Object {
                [string]$_.ExecutablePath -ieq $resolvedGodotPath -and
                (Test-CommandLineWorktreeBinding `
                    -CommandLine ([string]$_.CommandLine) `
                    -ExpectedRoot $root)
            }
    )
}

foreach ($directory in @($localRoot, $roamingRoot, $localAppDataRoot, $logRoot)) {
    [System.IO.Directory]::CreateDirectory($directory) | Out-Null
}

if (Test-Path -LiteralPath $tokenPath) {
    $token = [System.IO.File]::ReadAllText($tokenPath).Trim()
} else {
    $tokenBytes = New-Object byte[] 32
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($tokenBytes)
    $token = [System.Convert]::ToHexString($tokenBytes).ToLowerInvariant()
    [System.IO.File]::WriteAllText($tokenPath, $token, [System.Text.UTF8Encoding]::new($false))
}
if ($token -notmatch "^[0-9a-f]{64}$") {
    throw "Invalid local Funplay MCP token at: $tokenPath"
}

$settingsText = @"
[server]

enabled=true
port=$Port
auth_token="$token"
tool_profile="$ToolProfile"
debug_logging_enabled=false
execute_code_safety_checks_enabled=true

[tools]

disabled=Array[String]([])
"@

$settingsDirectory = Join-Path $roamingRoot "Godot\app_userdata\太空辛迪加"
[System.IO.Directory]::CreateDirectory($settingsDirectory) | Out-Null
[System.IO.File]::WriteAllText(
    (Join-Path $settingsDirectory "funplay_mcp_settings.cfg"),
    $settingsText,
    [System.Text.UTF8Encoding]::new($false)
)

if (Test-Path -LiteralPath $pidPath) {
    $existingPidText = [System.IO.File]::ReadAllText($pidPath).Trim()
    if ($existingPidText -match "^\d+$") {
        $existingProcess = Get-Process -Id ([int]$existingPidText) -ErrorAction SilentlyContinue
        if ($existingProcess -ne $null -and -not $existingProcess.HasExited) {
            throw "Role $Role already has a live Godot process (PID $existingPidText)."
        }
    }
    Remove-Item -LiteralPath $pidPath -Force -ErrorAction SilentlyContinue
}

$existingRoleProcesses = @(Get-RoleProcessRows)
if ($existingRoleProcesses.Count -ne 0) {
    $existingRolePids = @($existingRoleProcesses | Select-Object -ExpandProperty ProcessId)
    throw "Worktree already has a live Godot process (PID(s): $($existingRolePids -join ','))."
}
$existingListeners = @(Get-PortListeners -LocalPort $Port)
if ($existingListeners.Count -ne 0) {
    $owners = @($existingListeners | Select-Object -ExpandProperty OwningProcess -Unique)
    throw "MCP port $Port is already listening (owner PID(s): $($owners -join ','))."
}

$endpoint = "http://127.0.0.1:$Port/"
[System.IO.File]::WriteAllText($endpointPath, $endpoint, [System.Text.UTF8Encoding]::new($false))
$logPath = Join-Path $logRoot ("godot_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
$arguments = @(
    "--editor",
    "--path", ('"' + $root + '"'),
    "--log-file", ('"' + $logPath + '"'),
    "--resolution", ("{0}x{1}" -f $ResolutionWidth, $ResolutionHeight),
    "--position", "40,40"
)
if ($Renderer -eq "compatibility") {
    $arguments += @("--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3_angle")
} else {
    $arguments += @("--rendering-method", "forward_plus", "--rendering-driver", "vulkan")
}
$argumentString = $arguments -join " "
$environment = @{
    "APPDATA" = $roamingRoot
    "LOCALAPPDATA" = $localAppDataRoot
}

$startProcessParameters = @{
    FilePath = $resolvedGodotPath
    ArgumentList = $argumentString
    Environment = $environment
    PassThru = $true
}
$process = $null
try {
    $process = Start-Process @startProcessParameters
    $processStartTimeUtc = $process.StartTime.ToUniversalTime().ToString("o")
    [System.IO.File]::WriteAllText($pidPath, [string]$process.Id, [System.Text.UTF8Encoding]::new($false))

    $headers = @{ "X-Funplay-MCP-Token" = $token; "MCP-Protocol-Version" = "2025-11-25" }
    $deadline = (Get-Date).AddSeconds($StartupTimeoutSeconds)
    $projectInfo = $null
    while ((Get-Date) -lt $deadline -and -not $process.HasExited) {
        Start-Sleep -Milliseconds 500
        try {
            $roleListeners = @(Get-PortListeners -LocalPort $Port)
            if (
                $roleListeners.Count -ne 1 -or
                [int]$roleListeners[0].OwningProcess -ne $process.Id
            ) {
                throw "Role endpoint is not exclusively owned by the launched PID."
            }
            $body = @{
                jsonrpc = "2.0"
                id = 1
                method = "tools/call"
                params = @{ name = "get_project_info"; arguments = @{} }
            } | ConvertTo-Json -Depth 10 -Compress
            $requestParameters = @{
                Uri = $endpoint
                Method = "Post"
                Headers = $headers
                ContentType = "application/json"
                Body = $body
                TimeoutSec = 5
            }
            $response = Invoke-RestMethod @requestParameters
            if ($null -ne $response.error -or [bool]$response.result.isError) {
                throw "get_project_info returned an MCP error."
            }
            $projectInfo = $response.result.content[0].text | ConvertFrom-Json
            break
        } catch {
            $projectInfo = $null
        }
    }

    if ($process.HasExited) {
        throw "Godot exited during startup with code $($process.ExitCode). See: $logPath"
    }
    if ($projectInfo -eq $null) {
        throw "Funplay MCP did not become ready at $endpoint. Godot PID: $($process.Id); log: $logPath"
    }

    if ([string]$projectInfo.tool_profile -cne $ToolProfile) {
        throw "Funplay MCP tool profile mismatch: requested $ToolProfile, reported $($projectInfo.tool_profile)."
    }

    $reportedRoot = ([string]$projectInfo.project_root).Replace("/", "\").TrimEnd("\")
    if (-not $reportedRoot.Equals($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Endpoint $endpoint belongs to the wrong project: $reportedRoot"
    }
    $commandLine = [string](
        Get-CimInstance Win32_Process -Filter "ProcessId = $($process.Id)" |
        Select-Object -ExpandProperty CommandLine
    )
    $readyListeners = @(Get-PortListeners -LocalPort $Port)
    if ($readyListeners.Count -ne 1) {
        throw "Ready MCP endpoint does not have exactly one listener."
    }
    $endpointOwnerPid = [int]$readyListeners[0].OwningProcess
    if ($endpointOwnerPid -ne $process.Id) {
        throw "Ready MCP endpoint is not owned by the launched Godot PID."
    }

    $connection = [ordered]@{
    role = $Role
    endpoint = $endpoint
    port = $Port
    pid = $process.Id
    worktree = $root
    godot_path = $resolvedGodotPath
    process_start_time_utc = $processStartTimeUtc
    command_line = $commandLine
    endpoint_owner_pid = $endpointOwnerPid
    token_path = $tokenPath
    log_path = $logPath
    godot_version = [string]$projectInfo.godot_version.string
    tool_profile = [string]$projectInfo.tool_profile
    renderer = $Renderer
    resolution = ("{0}x{1}" -f $ResolutionWidth, $ResolutionHeight)
    }
    [System.IO.File]::WriteAllText(
        $connectionPath,
        ($connection | ConvertTo-Json -Depth 5),
        [System.Text.UTF8Encoding]::new($false)
    )

    $connection | ConvertTo-Json -Depth 5
} catch {
    $launchError = $_
    $cleanupFailures = [Collections.Generic.List[string]]::new()
    if ($null -ne $process) {
        $currentProcess = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
        if ($null -ne $currentProcess -and -not $currentProcess.HasExited) {
            try {
                $currentRow = Get-CimInstance `
                    Win32_Process `
                    -Filter "ProcessId = $($process.Id)" `
                    -ErrorAction Stop
                $identityMatches = (
                    $currentProcess.StartTime.ToUniversalTime().ToString("o") -ceq $processStartTimeUtc -and
                    [string]$currentProcess.Path -ieq $resolvedGodotPath -and
                    (Test-CommandLineWorktreeBinding `
                        -CommandLine ([string]$currentRow.CommandLine) `
                        -ExpectedRoot $root)
                )
                if (-not $identityMatches) {
                    $cleanupFailures.Add("Launched PID identity changed before cleanup.")
                } else {
                    [void]$currentProcess.CloseMainWindow()
                    if (-not $currentProcess.WaitForExit(5000)) {
                        Stop-Process -Id $currentProcess.Id -Force -ErrorAction Stop
                        if (-not $currentProcess.WaitForExit(5000)) {
                            $cleanupFailures.Add("Launched Godot PID did not exit after scoped force-stop.")
                        }
                    }
                }
            } catch {
                $cleanupFailures.Add("Scoped launch cleanup failed: $($_.Exception.Message)")
            }
        }
    }
    try {
        $remainingRoleProcesses = @(Get-RoleProcessRows)
        $remainingListeners = @(Get-PortListeners -LocalPort $Port)
        if ($remainingRoleProcesses.Count -ne 0) {
            $cleanupFailures.Add("Role process count after failed launch is $($remainingRoleProcesses.Count).")
        }
        if ($remainingListeners.Count -ne 0) {
            $cleanupFailures.Add("Endpoint count after failed launch is $($remainingListeners.Count).")
        }
    } catch {
        $cleanupFailures.Add("Failed to verify launch cleanup: $($_.Exception.Message)")
    }
    if ($cleanupFailures.Count -eq 0) {
        Remove-Item -LiteralPath $pidPath -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $endpointPath -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $connectionPath -Force -ErrorAction SilentlyContinue
        throw $launchError
    }
    throw "Launch failed ($($launchError.Exception.Message)); cleanup was not attested: $($cleanupFailures -join ' ')"
}
