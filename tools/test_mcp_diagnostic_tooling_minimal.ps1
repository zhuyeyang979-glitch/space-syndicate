param(
    [string]$FixtureRoot = "E:\ss-mcp\dm4",
    [string]$AddonSource = "E:\SpaceSyndicateWorkspace\worktrees\player-hand-zero-commit-a-exact-v3-3e73aaa8\addons\funplay_mcp",
    [string]$GodotPath = "C:\Users\Administrator\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe",
    [string]$ReportPath = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "role_godot_mcp_common.ps1")
. (Join-Path $PSScriptRoot "role_godot_mcp_diagnostics.ps1")

if (Test-Path -LiteralPath $FixtureRoot) {
    throw "MCP_DIAGNOSTIC_SELF_TEST_FIXTURE_EXISTS|path=$FixtureRoot"
}
$projectRoot = Join-Path $FixtureRoot "project"
$runtimeRoot = Join-Path $FixtureRoot "runtime"
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
$connection = $null
$stopResult = $null
$failure = ""
try {
    $launchJson = & (Join-Path $PSScriptRoot "launch_role_godot_mcp.ps1") `
        -Role Supervisor `
        -Port 28830 `
        -Worktree $projectRoot `
        -RuntimeDataBase $runtimeRoot `
        -GodotPath $GodotPath `
        -Renderer compatibility `
        -StartupTimeoutSeconds 120 `
        -RecoveryImportTimeoutSeconds 120 `
        -HttpTimeoutSeconds 3 `
        -InitialReadyStabilitySeconds 5 `
        -RequireFreshProjectCache $true `
        -SessionId "alpha04c-diag-min-v2" | Out-String
    $connection = $launchJson | ConvertFrom-Json
} catch {
    $failure = $_.Exception.Message
} finally {
    if ($null -ne $connection) {
        try {
            $stopJson = & (Join-Path $PSScriptRoot "stop_role_godot_mcp.ps1") `
                -Worktree $projectRoot `
                -RequestId "alpha04c-diag-min-stop-v2" `
                -ShutdownTimeoutSeconds 20 `
                -AllowForcedCleanup $true | Out-String
            $stopResult = $stopJson | ConvertFrom-Json
        } catch {
            if ($failure -eq "") { $failure = $_.Exception.Message }
        }
    }
}

$logsRoot = Join-Path $projectRoot ".codex-godot\sessions\alpha04c-diag-min-v2\logs"
$stderr = Get-McpRawLogSnapshot `
    -Path (Join-Path $logsRoot "editor.stderr.log") `
    -SourceStream editor_stderr `
    -Stage startup_initial_filesystem_scan_before_endpoint_readiness
$classifications = @($stderr.records | ForEach-Object {
    if ([bool]$_.potential_diagnostic) {
        [ordered]@{ classification = "unclassified" }
    } else {
        [ordered]@{ classification = "informational" }
    }
})
$gate = Get-McpDiagnosticGateV2 -Classifications $classifications
$processCount = if ($null -ne $stopResult) {
    [int]$stopResult.task_process_count_after
} else {
    @(Get-CimInstance Win32_Process | Where-Object {
        $_.Name -match '(?i)^Godot.*\.exe$' -and $_.CommandLine -like "*$projectRoot*"
    }).Count
}
$endpointCount = if ((Get-McpEndpointOwnerPid -Port 28830) -eq 0) { 0 } else { 1 }
$green = [bool]$offline.green `
    -and [bool]$gate.green `
    -and [int]$offline.false_accept_count -eq 0 `
    -and [int]$offline.false_reject_count -eq 0 `
    -and [int]$stderr.diagnostic_count -eq 0 `
    -and $null -ne $stopResult `
    -and [bool]$stopResult.stopped `
    -and [bool]$stopResult.clean_stop `
    -and $processCount -eq 0 `
    -and $endpointCount -eq 0 `
    -and $failure -eq ""
$result = [ordered]@{
    schema = "McpDiagnosticToolingMinimalSelfTestV2"
    diagnostic_tooling_self_test_green = $green
    offline_tests = $offline
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
