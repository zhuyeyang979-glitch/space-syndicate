param(
    [string]$FixtureRoot = (Join-Path ([System.IO.Path]::GetTempPath()) ("alpha04c-mcp-quiescence-{0}" -f [guid]::NewGuid().ToString("N"))),
    [string]$AddonSource = (Join-Path (Split-Path $PSScriptRoot -Parent) "addons\funplay_mcp"),
    [string]$GodotPath = "C:\Users\zhuye\AppData\Local\Programs\Godot\4.7\Godot_v4.7-stable_win64.exe",
    [ValidateRange(1, 65535)]
    [int]$Port = 28830,
    [ValidatePattern("^[a-zA-Z0-9._-]+$")]
    [string]$SessionId = "alpha04c-import-quiescence-minimal-v3",
    [string]$ReportPath = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "role_godot_mcp_common.ps1")
. (Join-Path $PSScriptRoot "role_godot_mcp_diagnostics.ps1")

function Get-McpSelfTestDirectoryManifestSha256 {
    param([Parameter(Mandatory = $true)][string]$Root)

    $resolvedRoot = (Resolve-Path -LiteralPath $Root).Path.TrimEnd("\")
    $entries = @(
        Get-ChildItem -LiteralPath $resolvedRoot -File -Recurse | Sort-Object FullName | ForEach-Object {
            $relative = $_.FullName.Substring($resolvedRoot.Length).TrimStart("\").Replace("\", "/")
            "{0}:{1}" -f $relative, (Get-McpFileSha256Hex -Path $_.FullName)
        }
    )
    return Get-McpByteSha256Hex -Bytes ([System.Text.Encoding]::UTF8.GetBytes(($entries -join "`n")))
}

if (Test-Path -LiteralPath $FixtureRoot) {
    throw "MCP_DIAGNOSTIC_SELF_TEST_FIXTURE_EXISTS|path=$FixtureRoot"
}
$projectRoot = Join-Path $FixtureRoot "project"
$runtimeRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("mcpq-{0}" -f [guid]::NewGuid().ToString("N").Substring(0, 12))
[System.IO.Directory]::CreateDirectory($projectRoot) | Out-Null
$projectText = @"
config_version=5

[application]
config/name="McpDiagnosticMinimal"
run/main_scene="res://main.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")

[editor_plugins]
enabled=PackedStringArray("res://addons/funplay_mcp/plugin.cfg")

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
"@
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
[System.IO.File]::WriteAllText((Join-Path $projectRoot "project.godot"), $projectText, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText((Join-Path $projectRoot "main.tscn"), $sceneText, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText((Join-Path $projectRoot "main.gd"), $scriptText, [System.Text.UTF8Encoding]::new($false))
$addonDestination = Join-Path $projectRoot "addons\funplay_mcp"
[System.IO.Directory]::CreateDirectory($addonDestination) | Out-Null
Get-ChildItem -Force -LiteralPath $AddonSource | Copy-Item -Destination $addonDestination -Recurse -Force

$offlineJson = & pwsh -NoProfile -File (Join-Path $PSScriptRoot "test_role_godot_mcp_diagnostics.ps1") | Out-String
$offline = $offlineJson | ConvertFrom-Json
$offlineV3Output = & pwsh -NoProfile -File (Join-Path $PSScriptRoot "test_role_godot_mcp_diagnostics_v3.ps1") | Out-String
if ($LASTEXITCODE -ne 0) {
    throw "MCP_DIAGNOSTIC_V3_OFFLINE_TEST_FAILED"
}
$connection = $null
$stopResult = $null
$rescanSelfTest = $null
$scriptValidation = $null
$sceneLoad = $null
$failure = ""
try {
    $launchJson = & (Join-Path $PSScriptRoot "launch_role_godot_mcp.ps1") `
        -Role Supervisor `
        -Port $Port `
        -Worktree $projectRoot `
        -RuntimeDataBase $runtimeRoot `
        -GodotPath $GodotPath `
        -Renderer compatibility `
        -StartupTimeoutSeconds 120 `
        -RecoveryImportTimeoutSeconds 120 `
        -HttpTimeoutSeconds 3 `
        -InitialReadyStabilitySeconds 5 `
        -RequireFreshProjectCache $true `
        -SessionId $SessionId | Out-String
    $connection = $launchJson | ConvertFrom-Json
    $rescanSelfTestJson = & (Join-Path $PSScriptRoot "self_test_role_godot_mcp_rescan.ps1") `
        -Worktree $projectRoot `
        -OperationTimeoutSeconds 90 | Out-String
    $rescanSelfTest = $rescanSelfTestJson | ConvertFrom-Json
    $scriptValidationJson = & (Join-Path $PSScriptRoot "invoke_role_godot_mcp.ps1") `
        -Worktree $projectRoot `
        -ToolName validate_script `
        -ArgumentsJson '{"path":"res://main.gd","language":"gdscript"}' `
        -TimeoutSeconds 30 | Out-String
    $scriptValidation = $scriptValidationJson | ConvertFrom-Json
    $sceneLoadJson = & (Join-Path $PSScriptRoot "invoke_role_godot_mcp.ps1") `
        -Worktree $projectRoot `
        -ToolName open_scene `
        -ArgumentsJson '{"path":"res://main.tscn"}' `
        -TimeoutSeconds 30 | Out-String
    $sceneLoad = $sceneLoadJson | ConvertFrom-Json
} catch {
    $failure = $_.Exception.Message
} finally {
    if ($null -ne $connection) {
        try {
            $stopJson = & (Join-Path $PSScriptRoot "stop_role_godot_mcp.ps1") `
                -Worktree $projectRoot `
                -RequestId "alpha04c-import-quiescence-minimal-stop-v3" `
                -ShutdownTimeoutSeconds 20 `
                -AllowForcedCleanup $true | Out-String
            $stopResult = $stopJson | ConvertFrom-Json
        } catch {
            if ($failure -eq "") { $failure = $_.Exception.Message }
        }
    }
}

$logsRoot = Join-Path $projectRoot ".codex-godot\sessions\$SessionId\logs"
$stderr = Get-McpRawLogSnapshot `
    -Path (Join-Path $logsRoot "editor.stderr.log") `
    -SourceStream editor_stderr `
    -Stage startup_initial_filesystem_scan_before_endpoint_readiness
$classifications = @($stderr.diagnostics | ForEach-Object {
    Get-McpDiagnosticClassificationV3 `
        -Diagnostic $_ `
        -Environment ([ordered]@{
            godot_executable_sha256 = Get-McpFileSha256Hex -Path $GodotPath
            godot_version = (& $GodotPath --version | Select-Object -First 1).Trim()
            tooling_runtime_build_sha256 = Get-McpFileSha256Hex -Path (Join-Path $PSScriptRoot "role_godot_mcp_diagnostics.ps1")
            mcp_addon_tree = Get-McpSelfTestDirectoryManifestSha256 -Root $AddonSource
            launch_arguments_sha256 = "minimal-self-test-v3"
            capture_backend = "file_read_all_bytes_fixed_length_v1"
        }) `
        -CurrentAttemptIsTarget $false `
        -OccurrenceScope $SessionId
})
$gate = Get-McpDiagnosticGateV3 -Classifications $classifications
$processCount = if ($null -ne $stopResult) {
    [int]$stopResult.task_process_count_after
} else {
    @(Get-CimInstance Win32_Process | Where-Object {
        $_.Name -match '(?i)^Godot.*\.exe$' -and $_.CommandLine -like "*$projectRoot*"
    }).Count
}
$endpointCount = if ((Get-McpEndpointOwnerPid -Port $Port) -eq 0) { 0 } else { 1 }
$initialStatus = if ($null -ne $rescanSelfTest) { $rescanSelfTest.filesystem_status } else { $null }
$initialQuiescenceGreen = $null -ne $connection `
    -and [bool]$connection.import_quiescence_reached `
    -and [int]$connection.active_import_operation_total -eq 0 `
    -and [int]$connection.known_reimport_depth -eq 0
$reloadQuiescenceGreen = $null -ne $initialStatus `
    -and [bool]$initialStatus.import_quiescence_reached `
    -and [int]$initialStatus.active_import_operation_total -eq 0 `
    -and [int]$initialStatus.known_reimport_depth -eq 0
$validationGreen = $null -ne $scriptValidation `
    -and -not [bool]$scriptValidation.result.isError `
    -and [bool]$scriptValidation.result.structuredContent.ok
$sceneLoadGreen = $null -ne $sceneLoad -and -not [bool]$sceneLoad.result.isError
$green = [bool]$offline.green `
    -and $offlineV3Output.Contains("DIAGNOSTIC_CLASSIFICATION_V3_TESTS") `
    -and [bool]$gate.green `
    -and [int]$offline.false_accept_count -eq 0 `
    -and [int]$offline.false_reject_count -eq 0 `
    -and [int]$stderr.diagnostic_count -eq 0 `
    -and $null -ne $rescanSelfTest `
    -and [bool]$rescanSelfTest.self_test_green `
    -and $initialQuiescenceGreen `
    -and $reloadQuiescenceGreen `
    -and $validationGreen `
    -and $sceneLoadGreen `
    -and $null -ne $stopResult `
    -and [bool]$stopResult.stopped `
    -and [bool]$stopResult.clean_stop `
    -and $processCount -eq 0 `
    -and $endpointCount -eq 0 `
    -and $failure -eq ""
$result = [ordered]@{
    schema = "McpImportQuiescenceMinimalSelfTestV3"
    diagnostic_tooling_self_test_green = $green
    import_quiescence_self_test_green = $green
    initial_import_quiescence_green = $initialQuiescenceGreen
    recovery_import_quiescence_green = $null -ne $connection -and [bool]$connection.recovery_import_green
    reload_quiescence_green = $reloadQuiescenceGreen
    script_validation_green = $validationGreen
    scene_load_green = $sceneLoadGreen
    reimport_conflict_count = @($stderr.diagnostics | Where-Object { [bool]$_.reimport_conflict_correlated }).Count
    offline_tests = $offline
    offline_v3_output = $offlineV3Output.Trim()
    rescan_self_test = $rescanSelfTest
    script_validation = $scriptValidation
    scene_load = $sceneLoad
    no_diagnostics_green = [bool]$gate.green -and [int]$stderr.diagnostic_count -eq 0
    attested_baseline_classification_green = [int]$offline.categories.classification.passed -eq [int]$offline.categories.classification.total
    target_added_diagnostic_blocked = [int]$offline.categories.false_negative_guard.passed -eq [int]$offline.categories.false_negative_guard.total
    raw_nul_does_not_crash = [int]$offline.categories.false_negative_guard.passed -eq [int]$offline.categories.false_negative_guard.total
    endpoint_stopped_cleanly = $null -ne $stopResult -and [bool]$stopResult.stopped -and [bool]$stopResult.clean_stop
    diagnostic_self_test_false_accept_count = [int]$offline.false_accept_count
    diagnostic_self_test_false_reject_count = [int]$offline.false_reject_count
    process_count_after = $processCount
    endpoint_count_after = $endpointCount
    stderr = $stderr
    stop_result = $stopResult
    failure = $failure
}
if ($ReportPath -ne "") {
    $output = [System.IO.Path]::GetFullPath($ReportPath)
    [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($output)) | Out-Null
    [System.IO.File]::WriteAllText($output, ($result | ConvertTo-Json -Depth 30), [System.Text.UTF8Encoding]::new($false))
}
$result | ConvertTo-Json -Depth 30
if (-not $green) {
    exit 1
}
