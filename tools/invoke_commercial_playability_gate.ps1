<#
.SYNOPSIS
Runs the commercial playability gate as isolated, observable, timeout-bounded stages.

.DESCRIPTION
Each stage runs in a fresh Godot 4.7 process with its own APPDATA/LOCALAPPDATA roots.
The orchestrator enforces both a per-stage timeout and a total wall-clock budget, so
the gate cannot silently occupy a machine for several minutes without identifying
the first unfinished stage.

The script never uses the player's default user:// directory. It writes evidence only
below the ignored `.codex-godot/commercial-gate-runs` directory in this worktree.
#>
[CmdletBinding()]
param(
    [string]$ProjectPath = (Split-Path -Parent $PSScriptRoot),

    [string]$GodotPath = "C:\Users\Administrator\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe",

    [ValidateRange(1, 300)]
    [int]$StageTimeoutSeconds = 20,

    [ValidateRange(1, 300)]
    [int]$OverallTimeoutSeconds = 90,

    [ValidateSet(
        "documentation",
        "layout_1280",
        "layout_1600",
        "layout_1920",
        "cta_open_rack",
        "cta_buy_recovery",
        "optional_summon",
        "action_chain"
    )]
    [string[]]$Stage = @(
        "documentation",
        "layout_1280",
        "layout_1600",
        "layout_1920",
        "cta_open_rack",
        "cta_buy_recovery",
        "optional_summon",
        "action_chain"
    ),

    [string]$EvidenceRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) ".codex-godot\commercial-gate-runs")
)

$ErrorActionPreference = "Stop"

function Stop-ProcessTree {
    param([Parameter(Mandatory = $true)][Diagnostics.Process]$Process)

    if ($Process.HasExited) {
        return $true
    }
    try {
        $Process.Kill($true)
    } catch {
        try {
            $Process.Kill()
        } catch {
            return $false
        }
    }
    try {
        return $Process.WaitForExit(10000)
    } catch {
        return $Process.HasExited
    }
}

$projectRoot = (Resolve-Path -LiteralPath $ProjectPath).Path.TrimEnd("\")
$godotExecutable = (Resolve-Path -LiteralPath $GodotPath).Path
$evidenceBase = [IO.Path]::GetFullPath($EvidenceRoot)
$projectPrefix = $projectRoot + [IO.Path]::DirectorySeparatorChar
$testPath = [IO.Path]::GetFullPath((Join-Path $projectRoot "tests\commercial_playability_gate_test.gd"))

if (-not $testPath.StartsWith($projectPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Commercial gate must remain inside the project."
}
if (-not (Test-Path -LiteralPath $testPath -PathType Leaf)) {
    throw "Commercial gate script is missing: $testPath"
}
if ((Get-Item -LiteralPath $godotExecutable).VersionInfo.ProductVersion -notmatch '^4\.7(?:\.|$)') {
    throw "Godot 4.7 is required: $godotExecutable"
}

$runId = "{0}-{1}" -f [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss-fff"), ([guid]::NewGuid().ToString("N").Substring(0, 8))
$runRoot = Join-Path $evidenceBase $runId
[IO.Directory]::CreateDirectory($runRoot) | Out-Null

$suiteStopwatch = [Diagnostics.Stopwatch]::StartNew()
$results = [Collections.Generic.List[object]]::new()
$failureCount = 0
$firstBlockingStage = ""

foreach ($stageId in $Stage) {
    $remainingSeconds = $OverallTimeoutSeconds - [int][Math]::Floor($suiteStopwatch.Elapsed.TotalSeconds)
    if ($remainingSeconds -le 0) {
        $failureCount += 1
        if ([string]::IsNullOrEmpty($firstBlockingStage)) {
            $firstBlockingStage = $stageId
        }
        $results.Add([pscustomobject][ordered]@{
            stage = $stageId
            status = "not_run_overall_timeout"
            duration_seconds = 0.0
            exit_code = $null
            timeout_seconds = 0
            stage_duration_ms = $null
            stdout_log = $null
            stderr_log = $null
            godot_log = $null
        })
        continue
    }

    $effectiveTimeoutSeconds = [Math]::Max(1, [Math]::Min($StageTimeoutSeconds, $remainingSeconds))
    $stageRoot = Join-Path $runRoot $stageId
    $appData = Join-Path $stageRoot "appdata-roaming"
    $localAppData = Join-Path $stageRoot "appdata-local"
    [IO.Directory]::CreateDirectory($appData) | Out-Null
    [IO.Directory]::CreateDirectory($localAppData) | Out-Null
    $stdoutPath = Join-Path $stageRoot "stdout.log"
    $stderrPath = Join-Path $stageRoot "stderr.log"
    $godotLogPath = Join-Path $stageRoot "godot.log"

    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $godotExecutable
    $startInfo.WorkingDirectory = $projectRoot
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.Environment["APPDATA"] = $appData
    $startInfo.Environment["LOCALAPPDATA"] = $localAppData
    foreach ($argument in @(
        "--headless",
        "--path", $projectRoot,
        "--log-file", $godotLogPath,
        "--script", "res://tests/commercial_playability_gate_test.gd",
        "--commercial-stage=$stageId"
    )) {
        $startInfo.ArgumentList.Add($argument)
    }

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $stageStopwatch = [Diagnostics.Stopwatch]::StartNew()
    $timedOut = $false
    $terminatedAfterTimeout = $true
    $exitCode = $null
    try {
        if (-not $process.Start()) {
            throw "Godot did not start for stage $stageId."
        }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($effectiveTimeoutSeconds * 1000)) {
            $timedOut = $true
            $terminatedAfterTimeout = Stop-ProcessTree -Process $process
        }
        if (-not $timedOut -or $terminatedAfterTimeout) {
            $process.WaitForExit()
            $process.Refresh()
            $exitCode = $process.ExitCode
        } else {
            $exitCode = $null
        }
        $stdout = if ($stdoutTask.IsCompleted) {
            $stdoutTask.GetAwaiter().GetResult()
        } else {
            "Commercial gate timed out and stdout did not close within the bounded termination window."
        }
        $stderr = if ($stderrTask.IsCompleted) {
            $stderrTask.GetAwaiter().GetResult()
        } else {
            "Commercial gate timed out and stderr did not close within the bounded termination window."
        }
        [IO.File]::WriteAllText($stdoutPath, $stdout, [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText($stderrPath, $stderr, [Text.UTF8Encoding]::new($false))
    } finally {
        $stageStopwatch.Stop()
        $process.Dispose()
    }

    $stageDurationMs = $null
    $stageEndMatch = [regex]::Match(
        $stdout,
        "COMMERCIAL_GATE_STAGE_END\|stage=$([regex]::Escape($stageId))\|duration_ms=(\d+)\|failures=(\d+)"
    )
    if ($stageEndMatch.Success) {
        $stageDurationMs = [int64]$stageEndMatch.Groups[1].Value
    }
    $godotLog = if (Test-Path -LiteralPath $godotLogPath -PathType Leaf) {
        [IO.File]::ReadAllText($godotLogPath)
    } else {
        ""
    }
    $combinedDiagnosticLog = @($stdout, $stderr, $godotLog) -join "`n"
    $engineErrorMatches = [regex]::Matches(
        $combinedDiagnosticLog,
        "(?m)^(?:SCRIPT ERROR:|ERROR: Failed to load script|ERROR: Failed to parse script|.*Parse Error:).*$"
    )
    $engineErrorCount = $engineErrorMatches.Count
    $firstEngineError = if ($engineErrorCount -gt 0) {
        $engineErrorMatches[0].Value.Trim()
    } else {
        ""
    }
    $status = if ($timedOut) {
        "timed_out"
    } elseif ($exitCode -eq 0 -and $engineErrorCount -eq 0 -and $stageEndMatch.Success) {
        "passed"
    } else {
        "failed"
    }
    if ($status -ne "passed") {
        $failureCount += 1
        if ([string]::IsNullOrEmpty($firstBlockingStage)) {
            $firstBlockingStage = $stageId
        }
    }
    $result = [pscustomobject][ordered]@{
        stage = $stageId
        status = $status
        duration_seconds = [Math]::Round($stageStopwatch.Elapsed.TotalSeconds, 3)
        exit_code = $exitCode
        timeout_seconds = $effectiveTimeoutSeconds
        terminated_after_timeout = $terminatedAfterTimeout
        stage_duration_ms = $stageDurationMs
        engine_error_count = $engineErrorCount
        first_engine_error = $firstEngineError
        stdout_log = $stdoutPath
        stderr_log = $stderrPath
        godot_log = $godotLogPath
    }
    $results.Add($result)
    Write-Output ("COMMERCIAL_GATE_ORCHESTRATOR|stage={0}|status={1}|duration_seconds={2}|exit_code={3}|engine_errors={4}" -f `
        $stageId, $status, $result.duration_seconds, $exitCode, $engineErrorCount)
}

$suiteStopwatch.Stop()
$summary = [ordered]@{
    run_id = $runId
    status = if ($failureCount -eq 0) { "passed" } else { "failed" }
    project_path = $projectRoot
    godot_path = $godotExecutable
    stage_timeout_seconds = $StageTimeoutSeconds
    overall_timeout_seconds = $OverallTimeoutSeconds
    duration_seconds = [Math]::Round($suiteStopwatch.Elapsed.TotalSeconds, 3)
    failure_count = $failureCount
    first_blocking_stage = $firstBlockingStage
    stages = @($results)
}
$summaryPath = Join-Path $runRoot "summary.json"
[IO.File]::WriteAllText(
    $summaryPath,
    ($summary | ConvertTo-Json -Depth 6),
    [Text.UTF8Encoding]::new($false)
)
Write-Output ("COMMERCIAL_GATE_ORCHESTRATOR_SUMMARY|status={0}|duration_seconds={1}|failures={2}|first_blocking_stage={3}|summary={4}" -f `
    $summary.status, $summary.duration_seconds, $failureCount, $firstBlockingStage, $summaryPath)
exit $failureCount
