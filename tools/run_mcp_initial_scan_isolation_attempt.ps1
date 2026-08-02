param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern("^[A-Z][A-Z0-9]+$")]
    [string]$CellId,

    [Parameter(Mandatory = $true)]
    [ValidateSet("minimal", "origin_main", "pr77")]
    [string]$ProjectKind,

    [Parameter(Mandatory = $true)]
    [string]$ProjectSourceSha,

    [string]$ProjectRoot = "",

    [string]$RepairWorktree = (Get-Location).Path,

    [bool]$McpAddonEnabled = $false,

    [bool]$McpEndpointEnabled = $false,

    [bool]$WrapperRequestsEnabled = $false,

    [ValidateRange(1, 65535)]
    [int]$Port = 18880,

    [ValidateSet("import", "editor_iterations")]
    [string]$RunMode = "import",

    [ValidateRange(1, 100000)]
    [int]$EditorIterations = 300,

    [ValidateRange(5, 900)]
    [int]$TimeoutSeconds = 120,

    [string]$GodotPath = "C:\Users\zhuye\AppData\Local\Programs\Godot\4.7\Godot_v4.7-stable_win64.exe",

    [string]$EvidenceRoot = "",

    [string]$LedgerPath = ""
)

$ErrorActionPreference = "Stop"

function Write-AtomicUtf8 {
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
    [System.IO.File]::Move($temporaryPath, $Path, $true)
}

function Get-FirstMatchingLine {
    param(
        [string[]]$Lines,
        [string]$Pattern
    )

    foreach ($line in $Lines) {
        if ($line -match $Pattern) {
            return $line
        }
    }
    return ""
}

function Get-ProjectName {
    param([string]$Root)

    $projectText = [System.IO.File]::ReadAllText((Join-Path $Root "project.godot"))
    $match = [regex]::Match($projectText, '(?m)^config/name="([^"]+)"')
    if ($match.Success) {
        return $match.Groups[1].Value
    }
    return "McpInitialScanIsolation"
}

function Set-FunplayPluginEnabled {
    param(
        [string]$Root,
        [bool]$Enabled
    )

    $projectPath = Join-Path $Root "project.godot"
    $projectText = [System.IO.File]::ReadAllText($projectPath)
    $pluginPath = '"res://addons/funplay_mcp/plugin.cfg"'
    if ($Enabled) {
        if (-not $projectText.Contains($pluginPath)) {
            if ($projectText -match '(?m)^enabled=PackedStringArray\(([^\r\n]*)\)') {
                $projectText = [regex]::Replace(
                    $projectText,
                    '(?m)^enabled=PackedStringArray\(([^\r\n]*)\)',
                    {
                        param($match)
                        $existing = $match.Groups[1].Value.Trim()
                        if ($existing -eq "") {
                            return "enabled=PackedStringArray($pluginPath)"
                        }
                        return "enabled=PackedStringArray($existing, $pluginPath)"
                    },
                    1
                )
            } else {
                $projectText += "`r`n[editor_plugins]`r`nenabled=PackedStringArray($pluginPath)`r`n"
            }
        }
    } else {
        $projectText = $projectText.Replace(", $pluginPath", "")
        $projectText = $projectText.Replace("$pluginPath, ", "")
        $projectText = $projectText.Replace($pluginPath, "")
    }
    [System.IO.File]::WriteAllText($projectPath, $projectText, [System.Text.UTF8Encoding]::new($false))
}

function New-MinimalProject {
    param(
        [string]$Root,
        [bool]$EnableAddon,
        [string]$AddonSource
    )

    [System.IO.Directory]::CreateDirectory($Root) | Out-Null
    $projectText = @"
; Generated MCP initial-scan isolation fixture.
config_version=5

[application]
config/name="McpInitialScanMinimal"
run/main_scene="res://main.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")

[display]
window/size/viewport_width=320
window/size/viewport_height=180

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
"@
    if ($EnableAddon) {
        $projectText += @"

[editor_plugins]
enabled=PackedStringArray("res://addons/funplay_mcp/plugin.cfg")
"@
    }
    $sceneText = @"
[gd_scene load_steps=2 format=3]

[ext_resource path="res://main.gd" type="Script" id="1"]

[node name="Main" type="Node"]
script = ExtResource("1")
"@
    $scriptText = @"
extends Node

func _ready() -> void:
	pass
"@
    [System.IO.File]::WriteAllText((Join-Path $Root "project.godot"), $projectText, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $Root "main.tscn"), $sceneText, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $Root "main.gd"), $scriptText, [System.Text.UTF8Encoding]::new($false))
    if ($EnableAddon) {
        $targetAddon = Join-Path $Root "addons\funplay_mcp"
        [System.IO.Directory]::CreateDirectory((Split-Path $targetAddon -Parent)) | Out-Null
        Copy-Item -LiteralPath $AddonSource -Destination $targetAddon -Recurse
    }
}

function Get-EndpointAlive {
    param([int]$EndpointPort)

    if ($EndpointPort -le 0) {
        return $false
    }
    $listeners = @(Get-NetTCPConnection -State Listen -LocalPort $EndpointPort -ErrorAction SilentlyContinue)
    return $listeners.Count -gt 0
}

$repairRoot = (Resolve-Path -LiteralPath $RepairWorktree).Path.TrimEnd("\")
if (-not (Test-Path -LiteralPath $GodotPath)) {
    throw "Godot executable is missing: $GodotPath"
}
if ($McpEndpointEnabled -and -not $McpAddonEnabled) {
    throw "MCP endpoint cannot be enabled while the addon is disabled."
}
if ($WrapperRequestsEnabled -and -not $McpEndpointEnabled) {
    throw "Wrapper requests require an enabled MCP endpoint."
}

if ($EvidenceRoot -eq "") {
    $EvidenceRoot = Join-Path (Split-Path $repairRoot -Parent) "alpha04c-mcp-signal11-isolation-evidence"
}
if ($LedgerPath -eq "") {
    $LedgerPath = Join-Path $repairRoot "reports\handoffs\alpha04c_mcp_initial_scan_attempt_ledger.json"
}

$startedAt = [DateTimeOffset]::Now
$attemptId = "{0}-{1}-{2}" -f $CellId.ToLowerInvariant(), $startedAt.ToString("yyyyMMddTHHmmssfff"), ([guid]::NewGuid().ToString("N").Substring(0, 8))
$attemptRoot = Join-Path $EvidenceRoot $attemptId
$logRoot = Join-Path $attemptRoot "logs"
$roamingRoot = Join-Path $attemptRoot "appdata-roaming"
$localAppDataRoot = Join-Path $attemptRoot "appdata-local"
[System.IO.Directory]::CreateDirectory($logRoot) | Out-Null
[System.IO.Directory]::CreateDirectory($roamingRoot) | Out-Null
[System.IO.Directory]::CreateDirectory($localAppDataRoot) | Out-Null

if ($ProjectKind -eq "minimal") {
    $resolvedProjectRoot = Join-Path $attemptRoot "project"
    $minimalProjectParameters = @{
        Root = $resolvedProjectRoot
        EnableAddon = $McpAddonEnabled
        AddonSource = Join-Path $repairRoot "addons\funplay_mcp"
    }
    New-MinimalProject @minimalProjectParameters
    $fixtureHashInput = @(
        [System.IO.File]::ReadAllText((Join-Path $resolvedProjectRoot "project.godot")),
        [System.IO.File]::ReadAllText((Join-Path $resolvedProjectRoot "main.tscn")),
        [System.IO.File]::ReadAllText((Join-Path $resolvedProjectRoot "main.gd"))
    ) -join "`n"
    $hashBytes = [System.Text.Encoding]::UTF8.GetBytes($fixtureHashInput)
    $ProjectSourceSha = [System.Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($hashBytes)).ToLowerInvariant()
} else {
    if ($ProjectRoot -eq "") {
        throw "ProjectRoot is required for non-minimal attempts."
    }
    $resolvedProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path.TrimEnd("\")
    if (Test-Path -LiteralPath (Join-Path $resolvedProjectRoot ".godot")) {
        throw "Attempt project cache already exists; refusing to reuse it: $resolvedProjectRoot\.godot"
    }
    Set-FunplayPluginEnabled -Root $resolvedProjectRoot -Enabled $McpAddonEnabled
}

$projectCachePath = Join-Path $resolvedProjectRoot ".godot"
$projectName = Get-ProjectName -Root $resolvedProjectRoot
$token = [guid]::NewGuid().ToString("N") + [guid]::NewGuid().ToString("N")
$settingsDirectory = Join-Path $roamingRoot ("Godot\app_userdata\{0}" -f $projectName)
[System.IO.Directory]::CreateDirectory($settingsDirectory) | Out-Null
$settingsText = @"
[server]

enabled=$($McpEndpointEnabled.ToString().ToLowerInvariant())
port=$Port
auth_token="$token"
tool_profile="core"
debug_logging_enabled=false
execute_code_safety_checks_enabled=true

[tools]

disabled=Array[String]([])
"@
[System.IO.File]::WriteAllText(
    (Join-Path $settingsDirectory "funplay_mcp_settings.cfg"),
    $settingsText,
    [System.Text.UTF8Encoding]::new($false)
)

$stdoutPath = Join-Path $logRoot "editor.stdout.log"
$stderrPath = Join-Path $logRoot "editor.stderr.log"
$godotLogPath = Join-Path $logRoot "godot.log"
$wrapperLogPath = Join-Path $logRoot "wrapper.log"
$endpoint = if ($McpEndpointEnabled) { "http://127.0.0.1:$Port/" } else { "none" }
$arguments = @()
if ($RunMode -eq "import") {
    $arguments += "--import"
} else {
    $arguments += "--editor"
}
$arguments += @(
    "--path", ('"' + $resolvedProjectRoot + '"'),
    "--log-file", ('"' + $godotLogPath + '"'),
    "--rendering-method", "gl_compatibility",
    "--rendering-driver", "opengl3_angle"
)
if ($RunMode -eq "editor_iterations") {
    $arguments += @("--quit-after", [string]$EditorIterations, "--resolution", "640x360", "--position", "40,40")
}
$argumentString = $arguments -join " "
$environment = @{
    "APPDATA" = $roamingRoot
    "LOCALAPPDATA" = $localAppDataRoot
}

$wrapperLines = [System.Collections.Generic.List[string]]::new()
$wrapperLines.Add("attempt_id=$attemptId")
$wrapperLines.Add("started_at=$($startedAt.ToString('o'))")
$wrapperLines.Add("project_root=$resolvedProjectRoot")
$wrapperLines.Add("endpoint=$endpoint")
$wrapperLines.Add("arguments=$argumentString")

$startProcessParameters = @{
    FilePath = $GodotPath
    ArgumentList = $argumentString
    Environment = $environment
    RedirectStandardOutput = $stdoutPath
    RedirectStandardError = $stderrPath
    PassThru = $true
    WindowStyle = "Hidden"
    WorkingDirectory = $resolvedProjectRoot
}
$process = Start-Process @startProcessParameters
$editorPid = $process.Id
$wrapperLines.Add("editor_pid=$editorPid")

$endpointObserved = $false
$wrapperRequestsAttempted = $false
$wrapperRequestsSucceeded = -not $WrapperRequestsEnabled
$wrapperRequestRecords = @()
$timedOut = $false
$deadline = [DateTimeOffset]::Now.AddSeconds($TimeoutSeconds)
while (-not $process.HasExited -and [DateTimeOffset]::Now -lt $deadline) {
    if ($McpEndpointEnabled -and (Get-EndpointAlive -EndpointPort $Port)) {
        $endpointObserved = $true
    }
    if ($WrapperRequestsEnabled -and $endpointObserved -and -not $wrapperRequestsAttempted) {
        $wrapperRequestsAttempted = $true
        $requestFailures = 0
        foreach ($toolName in @("get_godot_version", "get_project_info", "filesystem_scan_status")) {
            $requestStarted = [DateTimeOffset]::Now
            $jsonRpcId = [guid]::NewGuid().ToString("N")
            $body = @{
                jsonrpc = "2.0"
                id = $jsonRpcId
                method = "tools/call"
                params = @{
                    name = $toolName
                    arguments = @{}
                }
            } | ConvertTo-Json -Depth 10 -Compress
            try {
                $response = Invoke-RestMethod `
                    -Uri $endpoint `
                    -Method Post `
                    -Headers @{
                        "X-Funplay-MCP-Token" = $token
                        "MCP-Protocol-Version" = "2025-11-25"
                    } `
                    -ContentType "application/json" `
                    -Body $body `
                    -TimeoutSec 5
                $wrapperRequestRecords += [ordered]@{
                    tool_name = $toolName
                    jsonrpc_request_id = $jsonRpcId
                    started_at = $requestStarted.ToString("o")
                    completed_at = [DateTimeOffset]::Now.ToString("o")
                    ok = $null -eq $response.error
                    response_error = $response.error
                }
                if ($null -ne $response.error) {
                    $requestFailures += 1
                }
            } catch {
                $requestFailures += 1
                $process.Refresh()
                $wrapperRequestRecords += [ordered]@{
                    tool_name = $toolName
                    jsonrpc_request_id = $jsonRpcId
                    started_at = $requestStarted.ToString("o")
                    completed_at = [DateTimeOffset]::Now.ToString("o")
                    ok = $false
                    response_error = $_.Exception.Message
                    editor_alive = -not $process.HasExited
                }
                if ($process.HasExited) {
                    break
                }
            }
        }
        $wrapperRequestsSucceeded = $requestFailures -eq 0 -and $wrapperRequestRecords.Count -eq 3
    }
    Start-Sleep -Milliseconds 50
    $process.Refresh()
}

if (-not $process.HasExited) {
    $timedOut = $true
    $wrapperLines.Add("timeout=true")
    $process.CloseMainWindow() | Out-Null
    if (-not $process.WaitForExit(5000)) {
        Stop-Process -Id $editorPid -Force -ErrorAction SilentlyContinue
        $process.WaitForExit(5000) | Out-Null
    }
}
$process.WaitForExit()
$exitCode = $process.ExitCode
$completedAt = [DateTimeOffset]::Now
$endpointAliveAfter = if ($McpEndpointEnabled) { Get-EndpointAlive -EndpointPort $Port } else { $false }
$editorAliveAfter = $null -ne (Get-Process -Id $editorPid -ErrorAction SilentlyContinue)

$allText = if (Test-Path -LiteralPath $godotLogPath) {
    [System.IO.File]::ReadAllText($godotLogPath)
} else {
    $fallbackText = @()
    foreach ($path in @($stdoutPath, $stderrPath)) {
        if (Test-Path -LiteralPath $path) {
            $fallbackText += [System.IO.File]::ReadAllText($path)
        }
    }
    $fallbackText -join "`n"
}
$allLines = $allText -split "`r?`n"
$signalMatch = [regex]::Match($allText, 'Program crashed with signal\s+(\d+)')
$nativeSignal = if ($signalMatch.Success) { [int]$signalMatch.Groups[1].Value } else { 0 }
$nativeStackAvailable = [regex]::IsMatch($allText, '(?m)^\[1\]\s+[0-9a-fA-F]+')
$firstError = Get-FirstMatchingLine -Lines $allLines -Pattern '^(SCRIPT ERROR|ERROR:|Unicode parsing error|CrashHandlerException)'
$lastError = ""
foreach ($line in $allLines) {
    if ($line -match '^(SCRIPT ERROR|ERROR:|Unicode parsing error|CrashHandlerException)') {
        $lastError = $line
    }
}
$firstScriptError = Get-FirstMatchingLine -Lines $allLines -Pattern '^SCRIPT ERROR:'
$firstFailedLoad = Get-FirstMatchingLine -Lines $allLines -Pattern '^ERROR: Failed to load script'
$firstUnicode = Get-FirstMatchingLine -Lines $allLines -Pattern '^Unicode parsing error'
$scriptErrorCount = @($allLines | Where-Object { $_ -match '^SCRIPT ERROR:' }).Count
$failedLoadCount = @($allLines | Where-Object { $_ -match '^ERROR: Failed to load script' }).Count
$unicodeCount = @($allLines | Where-Object { $_ -match '^Unicode parsing error' }).Count

$dumpCandidates = @()
foreach ($crashRoot in @(
    (Join-Path $localAppDataRoot "CrashDumps"),
    (Join-Path $env:LOCALAPPDATA "CrashDumps")
)) {
    if (Test-Path -LiteralPath $crashRoot) {
        $dumpCandidates += @(Get-ChildItem -LiteralPath $crashRoot -Filter "*.$editorPid.dmp" -ErrorAction SilentlyContinue)
    }
}
$nativeDumpPath = ""
if ($dumpCandidates.Count -gt 0) {
    $dump = $dumpCandidates | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $nativeDumpPath = Join-Path $logRoot $dump.Name
    Copy-Item -LiteralPath $dump.FullName -Destination $nativeDumpPath
}

$projectCacheObserved = Test-Path -LiteralPath $projectCachePath
$filesystemCacheFiles = @(
    Get-ChildItem -LiteralPath (Join-Path $projectCachePath "editor") -Filter "filesystem_cache*" -File -ErrorAction SilentlyContinue
)
$filesystemCacheObserved = $filesystemCacheFiles.Count -gt 0
$initialScanCompleted = $false
if (-not $timedOut -and $nativeSignal -eq 0 -and $exitCode -eq 0 -and $projectCacheObserved) {
    if ($RunMode -eq "import") {
        $initialScanCompleted = $true
    } elseif ($filesystemCacheObserved) {
        $initialScanCompleted = $true
    }
}
$wrapperRequestLogPath = Join-Path $logRoot "mcp_requests.json"
$wrapperRequestJson = if ($wrapperRequestRecords.Count -eq 0) {
    "[]"
} else {
    $wrapperRequestRecords | ConvertTo-Json -Depth 12
}
Write-AtomicUtf8 -Path $wrapperRequestLogPath -Text $wrapperRequestJson
$cellSucceeded = (
    $initialScanCompleted `
        -and (-not $McpEndpointEnabled -or $endpointObserved) `
        -and $wrapperRequestsSucceeded
)
$status = if ($cellSucceeded) { "green" } else { "failed" }
$reasonCode = if ($WrapperRequestsEnabled -and -not $wrapperRequestsSucceeded) {
    "wrapper_readiness_request_failed"
} elseif ($initialScanCompleted -and $McpEndpointEnabled -and -not $endpointObserved) {
    "endpoint_not_observed_during_scan"
} elseif ($initialScanCompleted) {
    "initial_scan_completed"
} elseif (-not $projectCacheObserved) {
    "project_path_not_honored"
} elseif ($timedOut) {
    "initial_scan_timeout"
} elseif ($nativeSignal -ne 0) {
    "native_signal_$nativeSignal"
} elseif ($exitCode -ne 0) {
    "editor_exit_code_$exitCode"
} else {
    "initial_scan_not_attested"
}

$wrapperLines.Add("completed_at=$($completedAt.ToString('o'))")
$wrapperLines.Add("native_exit_signal=$nativeSignal")
$wrapperLines.Add("native_exit_code=$exitCode")
$wrapperLines.Add("status=$status")
$wrapperLines.Add("reason_code=$reasonCode")
[System.IO.File]::WriteAllLines($wrapperLogPath, $wrapperLines, [System.Text.UTF8Encoding]::new($false))

$attempt = [ordered]@{
    schema = "McpInitialScanIsolationAttemptV1"
    attempt_id = $attemptId
    matrix_cell_id = $CellId
    project_source_sha = $ProjectSourceSha
    project_kind = $ProjectKind
    mcp_addon_enabled = $McpAddonEnabled
    mcp_endpoint_enabled = $McpEndpointEnabled
    wrapper_requests_enabled = $WrapperRequestsEnabled
    editor_pid = $editorPid
    endpoint = $endpoint
    project_cache_path = $projectCachePath
    user_data_path = $roamingRoot
    local_app_data_path = $localAppDataRoot
    log_root = $logRoot
    started_at = $startedAt.ToString("o")
    completed_at = $completedAt.ToString("o")
    initial_scan_started = $true
    initial_scan_completed = $initialScanCompleted
    first_script_error = $firstScriptError
    first_failed_script_load = $firstFailedLoad
    first_unicode_diagnostic = $firstUnicode
    first_error = $firstError
    last_error = $lastError
    script_error_count = $scriptErrorCount
    failed_script_load_count = $failedLoadCount
    unicode_diagnostic_count = $unicodeCount
    native_exit_signal = $nativeSignal
    native_exit_code = $exitCode
    native_stack_available = $nativeStackAvailable
    native_dump_path = $nativeDumpPath
    project_cache_observed = $projectCacheObserved
    filesystem_cache_observed = $filesystemCacheObserved
    filesystem_cache_files = @($filesystemCacheFiles | ForEach-Object { $_.Name })
    editor_alive_after_scan = $editorAliveAfter
    endpoint_observed_during_scan = $endpointObserved
    endpoint_alive_after_scan = $endpointAliveAfter
    wrapper_requests_attempted = $wrapperRequestsAttempted
    wrapper_requests_succeeded = $wrapperRequestsSucceeded
    wrapper_request_count = $wrapperRequestRecords.Count
    wrapper_request_log_path = $wrapperRequestLogPath
    timed_out = $timedOut
    status = $status
    reason_code = $reasonCode
}

$attemptJson = $attempt | ConvertTo-Json -Depth 12
Write-AtomicUtf8 -Path (Join-Path $attemptRoot "attempt.json") -Text $attemptJson

$ledger = if (Test-Path -LiteralPath $LedgerPath) {
    Get-Content -Raw -LiteralPath $LedgerPath | ConvertFrom-Json -AsHashtable
} else {
    [ordered]@{
        schema = "McpInitialScanIsolationAttemptLedgerV1"
        task_id = "ALPHA_0_4_C_PR77_MCP_INITIAL_SCAN_SIGNAL_11_ROOT_CAUSE_ISOLATION_AND_HARDENING_CONTINUATION"
        isolation_attempt_concurrent_count_max = 1
        attempts = @()
    }
}
if (@($ledger.attempts | Where-Object { $_.attempt_id -eq $attemptId }).Count -ne 0) {
    throw "Duplicate attempt id: $attemptId"
}
$ledger.attempts += $attempt
$ledger.updated_at = $completedAt.ToString("o")
Write-AtomicUtf8 -Path $LedgerPath -Text ($ledger | ConvertTo-Json -Depth 15)

$attempt | ConvertTo-Json -Depth 12
if ($status -ne "green") {
    exit 1
}
