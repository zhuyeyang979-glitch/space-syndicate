param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Supervisor", "A", "B", "C")]
    [string]$Role,

    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 65535)]
    [int]$Port,

    [string]$Worktree = (Get-Location).Path,

    [string]$GodotPath = "C:\Users\zhuye\AppData\Local\Programs\Godot\4.7\Godot_v4.7-stable_win64.exe",

    [ValidateSet("compatibility", "forward_plus")]
    [string]$Renderer = "compatibility",

    [int]$StartupTimeoutSeconds = 90
)

$ErrorActionPreference = "Stop"

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

$roleSlug = $Role.ToLowerInvariant()
$localRoot = Join-Path $root ".codex-godot"
$roamingRoot = Join-Path $localRoot "appdata-roaming"
$localAppDataRoot = Join-Path $localRoot "appdata-local"
$logRoot = Join-Path $localRoot "logs"
$tokenPath = Join-Path $localRoot "auth.token"
$endpointPath = Join-Path $localRoot "endpoint.txt"
$connectionPath = Join-Path $localRoot "connection.json"
$pidPath = Join-Path $localRoot "godot.pid"

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
tool_profile="core"
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
}

$endpoint = "http://127.0.0.1:$Port/"
[System.IO.File]::WriteAllText($endpointPath, $endpoint, [System.Text.UTF8Encoding]::new($false))
$logPath = Join-Path $logRoot ("godot_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
$arguments = @(
    "--editor",
    "--path", ('"' + $root + '"'),
    "--log-file", ('"' + $logPath + '"'),
    "--resolution", "1600x960",
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
    FilePath = $GodotPath
    ArgumentList = $argumentString
    Environment = $environment
    PassThru = $true
}
$process = Start-Process @startProcessParameters
[System.IO.File]::WriteAllText($pidPath, [string]$process.Id, [System.Text.UTF8Encoding]::new($false))

$headers = @{ "X-Funplay-MCP-Token" = $token; "MCP-Protocol-Version" = "2025-11-25" }
$deadline = (Get-Date).AddSeconds($StartupTimeoutSeconds)
$projectInfo = $null
while ((Get-Date) -lt $deadline -and -not $process.HasExited) {
    Start-Sleep -Milliseconds 500
    try {
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

$reportedRoot = ([string]$projectInfo.project_root).Replace("/", "\").TrimEnd("\")
if (-not $reportedRoot.Equals($root, [System.StringComparison]::OrdinalIgnoreCase)) {
    $process.CloseMainWindow() | Out-Null
    throw "Endpoint $endpoint belongs to the wrong project: $reportedRoot"
}

$connection = [ordered]@{
    role = $Role
    endpoint = $endpoint
    port = $Port
    pid = $process.Id
    worktree = $root
    token_path = $tokenPath
    log_path = $logPath
    godot_version = [string]$projectInfo.godot_version.string
    tool_profile = [string]$projectInfo.tool_profile
    renderer = $Renderer
}
[System.IO.File]::WriteAllText(
    $connectionPath,
    ($connection | ConvertTo-Json -Depth 5),
    [System.Text.UTF8Encoding]::new($false)
)

$connection | ConvertTo-Json -Depth 5
