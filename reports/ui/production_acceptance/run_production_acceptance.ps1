[CmdletBinding()]
param(
    [string]$GodotPath = "C:\Users\zhuye\AppData\Local\Programs\Godot\4.7\Godot_v4.7-stable_win64_console.exe",
    [int]$TimeoutSeconds = 180
)

$ErrorActionPreference = "Stop"
$ReportDir = $PSScriptRoot
$RepoRoot = (Resolve-Path (Join-Path $ReportDir "..\..\..")).Path
$DefaultSavePath = Join-Path $env:APPDATA "Godot\app_userdata\太空辛迪加\space_syndicate_current_run.save"
$QaRoot = Join-Path ([IO.Path]::GetTempPath()) ("space_syndicate_production_acceptance_" + [Guid]::NewGuid().ToString("N"))
$QaAppData = Join-Path $QaRoot "AppData\Roaming"
$QaSavePath = Join-Path $QaAppData "Godot\app_userdata\太空辛迪加\qa_current_run.save"
$StdoutPath = Join-Path $ReportDir "godot_stdout.log"
$StderrPath = Join-Path $ReportDir "godot_stderr.log"
$ConsolePath = Join-Path $ReportDir "godot_console.log"
$ClassificationPath = Join-Path $ReportDir "console_classification.json"
$RunSummaryPath = Join-Path $ReportDir "run_summary.json"
$ReportPath = Join-Path $ReportDir "report.md"
$AcceptanceResultsPath = Join-Path $ReportDir "acceptance_results.json"

function Get-SaveFingerprint {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [ordered]@{
            path = $Path
            exists = $false
            length = 0
            last_write_utc = $null
            sha256 = ""
        }
    }
    $Item = Get-Item -LiteralPath $Path
    return [ordered]@{
        path = $Item.FullName
        exists = $true
        length = $Item.Length
        last_write_utc = $Item.LastWriteTimeUtc.ToString("O")
        sha256 = (Get-FileHash -LiteralPath $Item.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

function Test-FingerprintEqual {
    param($Before, $After)
    return ($Before | ConvertTo-Json -Compress) -ceq ($After | ConvertTo-Json -Compress)
}

function Get-ConsoleClassification {
    param([string[]]$Lines)
    $Entries = @()
    for ($Index = 0; $Index -lt $Lines.Count; $Index++) {
        $Line = $Lines[$Index]
        if ([string]::IsNullOrWhiteSpace($Line)) {
            continue
        }
        $Severity = $null
        $Category = $null
        if ($Line -match "(?i)ObjectDB instances leaked|Resources still in use|RID allocations.*leaked|orphan StringName") {
            $Severity = "error"
            $Category = "resource_lifecycle"
        } elseif ($Line -match "(?i)SCRIPT ERROR|Parse Error|Invalid call|Invalid access") {
            $Severity = "error"
            $Category = "gdscript"
        } elseif ($Line -match "(?i)shader|Vulkan|RenderingDevice|rendering driver") {
            if ($Line -match "(?i)ERROR:|FATAL|CRASH") {
                $Severity = "error"
                $Category = "rendering"
            } elseif ($Line -match "(?i)WARNING:") {
                $Severity = "warning"
                $Category = "rendering"
            }
        } elseif ($Line -match "(?i)audio|WASAPI") {
            if ($Line -match "(?i)ERROR:|FATAL|CRASH") {
                $Severity = "error"
                $Category = "audio"
            } elseif ($Line -match "(?i)WARNING:") {
                $Severity = "warning"
                $Category = "audio"
            }
        } elseif ($Line -match "(?i)ERROR:|FATAL|CRASH|EXCEPTION") {
            $Severity = "error"
            $Category = "engine"
        } elseif ($Line -match "(?i)WARNING:") {
            $Severity = "warning"
            $Category = "engine"
        }
        if ($null -ne $Severity) {
            $Entries += [ordered]@{
                line = $Index + 1
                severity = $Severity
                category = $Category
                text = $Line
            }
        }
    }
    $Errors = @($Entries | Where-Object severity -eq "error")
    $Warnings = @($Entries | Where-Object severity -eq "warning")
    $ByCategory = [ordered]@{}
    foreach ($Entry in $Entries) {
        if (-not $ByCategory.Contains($Entry.category)) {
            $ByCategory[$Entry.category] = 0
        }
        $ByCategory[$Entry.category]++
    }
    return [ordered]@{
        error_count = $Errors.Count
        warning_count = $Warnings.Count
        by_category = $ByCategory
        entries = $Entries
        pass = $Errors.Count -eq 0
    }
}

if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot 4.7 console executable not found: $GodotPath"
}

$Version = (& $GodotPath --version).Trim()
if ($Version -notmatch "^4\.7\.") {
    throw "Expected Godot 4.7, got: $Version"
}

$SourceRevision = (git -C $RepoRoot rev-parse HEAD).Trim()
$SaveBefore = Get-SaveFingerprint -Path $DefaultSavePath
$OriginalAppData = $env:APPDATA
$OriginalDefaultSave = $env:SPACE_SYNDICATE_DEFAULT_SAVE_PATH
$OriginalQaSave = $env:SPACE_SYNDICATE_QA_SAVE_PATH
$OriginalQaRoot = $env:SPACE_SYNDICATE_QA_PROFILE_ROOT
$OriginalRevision = $env:SPACE_SYNDICATE_SOURCE_REVISION
$TimedOut = $false
$ExitCode = -1
$Stdout = ""
$Stderr = ""
$QaProfileRemoved = $false

New-Item -ItemType Directory -Path $QaAppData -Force | Out-Null

try {
    $env:APPDATA = $QaAppData
    $env:SPACE_SYNDICATE_DEFAULT_SAVE_PATH = $DefaultSavePath
    $env:SPACE_SYNDICATE_QA_SAVE_PATH = $QaSavePath
    $env:SPACE_SYNDICATE_QA_PROFILE_ROOT = $QaRoot
    $env:SPACE_SYNDICATE_SOURCE_REVISION = $SourceRevision

    $StartInfo = [Diagnostics.ProcessStartInfo]::new()
    $StartInfo.FileName = $GodotPath
    $StartInfo.WorkingDirectory = $RepoRoot
    $StartInfo.UseShellExecute = $false
    $StartInfo.RedirectStandardOutput = $true
    $StartInfo.RedirectStandardError = $true
    $StartInfo.CreateNoWindow = $false
    foreach ($Argument in @(
        "--path", $RepoRoot,
        "--windowed",
        "--resolution", "1280x720",
        "--position", "20,20",
        "--script", "res://reports/ui/production_acceptance/production_acceptance.gd"
    )) {
        [void]$StartInfo.ArgumentList.Add($Argument)
    }

    $Process = [Diagnostics.Process]::new()
    $Process.StartInfo = $StartInfo
    [void]$Process.Start()
    $StdoutTask = $Process.StandardOutput.ReadToEndAsync()
    $StderrTask = $Process.StandardError.ReadToEndAsync()
    if (-not $Process.WaitForExit($TimeoutSeconds * 1000)) {
        $TimedOut = $true
        $Process.Kill($true)
        $Process.WaitForExit()
    }
    $Stdout = $StdoutTask.GetAwaiter().GetResult()
    $Stderr = $StderrTask.GetAwaiter().GetResult()
    $ExitCode = $Process.ExitCode
} finally {
    $env:APPDATA = $OriginalAppData
    $env:SPACE_SYNDICATE_DEFAULT_SAVE_PATH = $OriginalDefaultSave
    $env:SPACE_SYNDICATE_QA_SAVE_PATH = $OriginalQaSave
    $env:SPACE_SYNDICATE_QA_PROFILE_ROOT = $OriginalQaRoot
    $env:SPACE_SYNDICATE_SOURCE_REVISION = $OriginalRevision

    $TempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    $ResolvedQaRoot = [IO.Path]::GetFullPath($QaRoot)
    $SafeQaLeaf = Split-Path -Leaf $ResolvedQaRoot
    if ($ResolvedQaRoot.StartsWith($TempRoot, [StringComparison]::OrdinalIgnoreCase) -and $SafeQaLeaf.StartsWith("space_syndicate_production_acceptance_")) {
        if (Test-Path -LiteralPath $ResolvedQaRoot) {
            Remove-Item -LiteralPath $ResolvedQaRoot -Recurse -Force
        }
        $QaProfileRemoved = -not (Test-Path -LiteralPath $ResolvedQaRoot)
    }
}

$SaveAfter = Get-SaveFingerprint -Path $DefaultSavePath
$WrapperSaveUnchanged = Test-FingerprintEqual -Before $SaveBefore -After $SaveAfter
[IO.File]::WriteAllText($StdoutPath, $Stdout, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText($StderrPath, $Stderr, [Text.UTF8Encoding]::new($false))
$ConsoleText = "===== STDOUT =====`r`n$Stdout`r`n===== STDERR =====`r`n$Stderr"
[IO.File]::WriteAllText($ConsolePath, $ConsoleText, [Text.UTF8Encoding]::new($false))
$ConsoleLines = $ConsoleText -split "`r?`n"
$Classification = Get-ConsoleClassification -Lines $ConsoleLines
$Classification | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ClassificationPath -Encoding utf8NoBOM

$Acceptance = $null
if (Test-Path -LiteralPath $AcceptanceResultsPath -PathType Leaf) {
    $Acceptance = Get-Content -LiteralPath $AcceptanceResultsPath -Raw | ConvertFrom-Json
}
$MarkerPass = $Stdout -match "PRODUCTION_ACCEPTANCE_STATUS=PASS"
$CleanStopMarker = $Stdout -match "PRODUCTION_ACCEPTANCE_CLEAN_STOP_READY=true"
$RuntimePass = $null -ne $Acceptance -and $Acceptance.status -eq "PASS"
$OverallPass = $RuntimePass -and $MarkerPass -and $CleanStopMarker -and -not $TimedOut -and $ExitCode -eq 0 -and $Classification.pass -and $WrapperSaveUnchanged -and $QaProfileRemoved

$RunSummary = [ordered]@{
    status = $(if ($OverallPass) { "PASS" } else { "FAIL" })
    source_revision = $SourceRevision
    godot_version = $Version
    command = "$GodotPath --path $RepoRoot --windowed --resolution 1280x720 --position 20,20 --script res://reports/ui/production_acceptance/production_acceptance.gd"
    blocking_wait = $true
    timeout_seconds = $TimeoutSeconds
    timed_out = $TimedOut
    process_exit_code = $ExitCode
    runtime_result_present = $null -ne $Acceptance
    runtime_status = $(if ($null -ne $Acceptance) { $Acceptance.status } else { "MISSING" })
    pass_marker = $MarkerPass
    clean_stop_marker = $CleanStopMarker
    qa_profile_removed = $QaProfileRemoved
    default_save_before = $SaveBefore
    default_save_after = $SaveAfter
    default_save_metadata_and_sha256_unchanged = $WrapperSaveUnchanged
    console = $Classification
}
$RunSummary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $RunSummaryPath -Encoding utf8NoBOM

$FailureLines = @()
if ($null -ne $Acceptance -and $Acceptance.failures.Count -gt 0) {
    $FailureLines += @($Acceptance.failures | ForEach-Object { "- Runtime: $_" })
}
if ($Classification.error_count -gt 0) {
    $FailureLines += @($Classification.entries | Where-Object severity -eq "error" | ForEach-Object { "- Console [$($_.category)]: $($_.text)" })
}
if (-not $WrapperSaveUnchanged) { $FailureLines += "- Default save metadata/SHA256 changed." }
if (-not $QaProfileRemoved) { $FailureLines += "- QA profile cleanup failed." }
if ($TimedOut) { $FailureLines += "- Godot exceeded the blocking timeout and was terminated." }
if ($FailureLines.Count -eq 0) { $FailureLines = @("- None.") }

$Weather = if ($null -ne $Acceptance) { $Acceptance.weather_states } else { $null }
$Economy = if ($null -ne $Acceptance) { $Acceptance.economy_scroll } else { $null }
$Modules = if ($null -ne $Acceptance) { $Acceptance.module_gate } else { $null }
$ReportLines = @(
    "# Space Syndicate 1280x720 Production Acceptance",
    "",
    "- **Result:** $(if ($OverallPass) { 'PASS' } else { 'FAIL' })",
    "- **Revision:** ``$SourceRevision``",
    "- **Engine:** ``$Version`` (headed, blocking, 1280x720)",
    "- **Scene:** ``res://scenes/main.tscn``",
    "- **Process:** exit ``$ExitCode``; timeout ``$TimedOut``; clean-stop marker ``$CleanStopMarker``",
    "- **Default save:** metadata + SHA256 unchanged ``$WrapperSaveUnchanged``",
    "- **QA profile:** independent override installed before Main entered tree; temporary profile removed ``$QaProfileRemoved``",
    "",
    "## Runtime Gates",
    "",
    "| Gate | Result | Evidence |",
    "| --- | --- | --- |",
    "| Normal core table | $(if ($null -ne $Acceptance -and $Acceptance.core_table.runtime_game_screen_visible) { 'PASS' } else { 'FAIL' }) | ``01_normal_core_table_1280x720.png`` |",
    "| Weather forecast | $(if ($null -ne $Weather -and $Weather.forecast.pass) { 'PASS' } else { 'FAIL' }) | ``02_weather_forecast_1280x720.png`` |",
    "| Weather active-only review frame | $(if ($null -ne $Weather -and $Weather.active.pass) { 'PASS' } else { 'FAIL' }) | ``03_weather_active_1280x720.png`` |",
    "| Weather active + forecast dual | $(if ($null -ne $Weather -and $Weather.dual.pass) { 'PASS' } else { 'FAIL' }) | ``04_weather_dual_1280x720.png`` |",
    "| Economy reopen scroll-to-top | $(if ($null -ne $Economy -and $Economy.pass) { 'PASS' } else { 'FAIL' }) | before ``$($Economy.actual_before_close)``; reopened ``$($Economy.actual_after_reopen)`` |",
    "| PublicTrack / RightInspector / PlayerBoard complete frames | $(if ($null -ne $Modules -and $Modules.pass) { 'PASS' } else { 'FAIL' }) | ``07_card_track_inspector_player_board_1280x720.png`` |",
    "| Pixel gate | $(if ($null -ne $Acceptance -and $Acceptance.captures.PSObject.Properties.Value.pass -notcontains $false) { 'PASS' } else { 'FAIL' }) | ``pixel_gate.json`` |",
    "| Scene tree | $(if (Test-Path -LiteralPath (Join-Path $ReportDir 'scene_tree.json')) { 'CAPTURED' } else { 'MISSING' }) | ``scene_tree.json`` |",
    "",
    "Weather activation used the production transition. For the active-only frame, the already generated next forecast was held for one QA frame and restored unchanged for the dual frame. No city, monster, or route arrays were fabricated; the final card-track frame comes from production ``_use_skill(0)``.",
    "",
    "## Console Classification",
    "",
    "- Errors: ``$($Classification.error_count)``",
    "- Warnings: ``$($Classification.warning_count)``",
    "- Categories: ``$(($Classification.by_category | ConvertTo-Json -Compress))``",
    "- Full evidence: ``godot_console.log`` and ``console_classification.json``",
    "",
    "## Failures",
    ""
) + $FailureLines + @(
    "",
    "## Evidence Index",
    "",
    "Structured runtime facts are in ``acceptance_results.json``; renderer/runtime facts in ``runtime_environment.json``; independent save fingerprints in ``save_integrity.json`` and ``run_summary.json``. Every PNG records its SHA256 and sampled pixel metrics in ``pixel_gate.json``."
)
[IO.File]::WriteAllText($ReportPath, ($ReportLines -join "`r`n") + "`r`n", [Text.UTF8Encoding]::new($false))

Write-Output "PRODUCTION_ACCEPTANCE_WRAPPER_STATUS=$(if ($OverallPass) { 'PASS' } else { 'FAIL' })"
Write-Output "PRODUCTION_ACCEPTANCE_WRAPPER_REPORT=$ReportPath"
if (-not $OverallPass) {
    exit 1
}
