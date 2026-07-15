<#
.SYNOPSIS
Runs one Godot 4.7 script or scene gate as a blocking, timeout-bounded process.

.DESCRIPTION
Uses the GUI Godot executable directly, captures the actual process exit code,
writes stdout/stderr/Godot logs to an isolated directory outside the repository,
and removes only scoped headless/game processes for this absolute project path.

Runner exit codes are the Godot exit code for a completed test, 124 for timeout,
and 125 when a completed test leaves a scoped runtime process (even if cleanup
succeeds). The console wrapper is deliberately rejected because it can return
before the real process.

.EXAMPLE
pwsh -File tools/invoke_godot_test.ps1 `
    -TestScript res://tests/smoke_test.gd `
    -TestArgument --check-only `
    -TimeoutSeconds 180

.EXAMPLE
pwsh -File tools/invoke_godot_test.ps1 `
    -Scene res://scenes/tools/ProductMarketRuntimeCharacterizationBench.tscn `
    -TimeoutSeconds 300
#>
[CmdletBinding(DefaultParameterSetName = "Script")]
param(
    [Parameter(Mandatory = $true, ParameterSetName = "Script")]
    [ValidatePattern('^res://.+\.gd$')]
    [string]$TestScript,

    [Parameter(Mandatory = $true, ParameterSetName = "Scene")]
    [ValidatePattern('^res://.+\.tscn$')]
    [string]$Scene,

    [string]$ProjectPath = (Split-Path -Parent $PSScriptRoot),

    [string]$GodotPath = "C:\Users\zhuye\AppData\Local\Programs\Godot\4.7\Godot_v4.7-stable_win64.exe",

    [ValidateRange(1, 86400)]
    [int]$TimeoutSeconds = 180,

    [string[]]$TestArgument = @(),

    [string]$LogRoot = (Join-Path $env:LOCALAPPDATA "SpaceSyndicate\godot_test_runs")
)

$ErrorActionPreference = "Stop"

function Test-CommandLineContains {
    param(
        [AllowNull()]
        [string]$CommandLine,
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    if ([string]::IsNullOrEmpty($CommandLine)) {
        return $false
    }
    return $CommandLine.IndexOf($Value, [StringComparison]::OrdinalIgnoreCase) -ge 0
}

function Get-ProjectRuntimeProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResolvedProjectPath,
        [Parameter(Mandatory = $true)]
        [string]$ResolvedGodotPath
    )

    $forwardProjectPath = $ResolvedProjectPath.Replace('\', '/')
    return @(
        Get-CimInstance Win32_Process |
            Where-Object {
                if ($_.Name -notlike "Godot*.exe") {
                    return $false
                }

                $sameExecutable = -not [string]::IsNullOrEmpty($_.ExecutablePath) -and
                    [string]::Equals(
                        [IO.Path]::GetFullPath($_.ExecutablePath),
                        $ResolvedGodotPath,
                        [StringComparison]::OrdinalIgnoreCase
                    )
                if (-not $sameExecutable) {
                    return $false
                }

                $hasProjectPath = (Test-CommandLineContains -CommandLine $_.CommandLine -Value $ResolvedProjectPath) -or
                    (Test-CommandLineContains -CommandLine $_.CommandLine -Value $forwardProjectPath)
                if (-not $hasProjectPath) {
                    return $false
                }

                $isHeadless = Test-CommandLineContains -CommandLine $_.CommandLine -Value "--headless"
                $isEditor = Test-CommandLineContains -CommandLine $_.CommandLine -Value "--editor"
                return $isHeadless -or -not $isEditor
            }
    )
}

function Stop-ScopedProcessTree {
    param(
        [Parameter(Mandatory = $true)]
        [int]$ProcessId
    )

    try {
        $target = [Diagnostics.Process]::GetProcessById($ProcessId)
    } catch {
        return
    }

    try {
        $target.Kill($true)
    } catch {
        try {
            $target.Kill()
        } catch {
            return
        }
    }

    try {
        $target.WaitForExit(10000) | Out-Null
    } catch {
        # The process may disappear between Kill and WaitForExit.
    } finally {
        $target.Dispose()
    }
}

function New-GodotProcessStartInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExecutablePath,
        [Parameter(Mandatory = $true)]
        [string]$WorkingDirectory,
        [Parameter(Mandatory = $true)]
        [string[]]$ArgumentList
    )

    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $ExecutablePath
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in $ArgumentList) {
        $startInfo.ArgumentList.Add($argument)
    }
    return $startInfo
}

$ProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path.TrimEnd('\', '/')
$GodotPath = (Resolve-Path -LiteralPath $GodotPath).Path
$LogRoot = [IO.Path]::GetFullPath($LogRoot)

if (-not (Test-Path -LiteralPath (Join-Path $ProjectPath "project.godot") -PathType Leaf)) {
    throw "project.godot was not found under $ProjectPath"
}
if ([IO.Path]::GetFileName($GodotPath) -match '(?i)_console\.exe$') {
    throw "The console wrapper is not accepted because it can return before the Godot test process: $GodotPath"
}

$godotVersion = (Get-Item -LiteralPath $GodotPath).VersionInfo.ProductVersion
if ($godotVersion -notmatch '^4\.7(?:\.|$)') {
    throw "Godot 4.7 is required, but $GodotPath reports ProductVersion '$godotVersion'."
}

$targetType = if ($PSCmdlet.ParameterSetName -eq "Scene") { "scene" } else { "script" }
$targetPath = if ($targetType -eq "scene") { $Scene } else { $TestScript }
$relativeTargetPath = $targetPath.Substring("res://".Length).Replace('/', [IO.Path]::DirectorySeparatorChar)
$absoluteTargetPath = [IO.Path]::GetFullPath((Join-Path $ProjectPath $relativeTargetPath))
$projectPrefix = $ProjectPath + [IO.Path]::DirectorySeparatorChar
if (-not $absoluteTargetPath.StartsWith($projectPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Godot target must stay inside the project: $targetPath"
}
if (-not (Test-Path -LiteralPath $absoluteTargetPath -PathType Leaf)) {
    throw "Godot target was not found: $absoluteTargetPath"
}

$preexistingRuntime = @(Get-ProjectRuntimeProcess -ResolvedProjectPath $ProjectPath -ResolvedGodotPath $GodotPath)
if ($preexistingRuntime.Count -gt 0) {
    $ids = ($preexistingRuntime | ForEach-Object { $_.ProcessId }) -join ", "
    throw "Refusing to overlap an existing Godot headless/game process for this project. PIDs: $ids"
}

$testName = [IO.Path]::GetFileNameWithoutExtension($absoluteTargetPath)
$safeTestName = [regex]::Replace($testName, '[^A-Za-z0-9_.-]', '_')
$runId = "{0}-{1}-{2}" -f [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss-fff"), $safeTestName, ([guid]::NewGuid().ToString("N").Substring(0, 8))
$runDirectory = Join-Path $LogRoot $runId
New-Item -ItemType Directory -Force -Path $runDirectory | Out-Null

$stdoutPath = Join-Path $runDirectory "stdout.log"
$stderrPath = Join-Path $runDirectory "stderr.log"
$godotLogPath = Join-Path $runDirectory "godot.log"
$resultPath = Join-Path $runDirectory "result.json"
$arguments = @(
    "--headless",
    "--path", $ProjectPath,
    "--log-file", $godotLogPath
)
if ($targetType -eq "scene") {
    $arguments += @("--scene", $Scene)
} else {
    $arguments += @("--script", $TestScript)
}
$arguments += @($TestArgument)

$startedAt = [DateTime]::UtcNow
$stopwatch = [Diagnostics.Stopwatch]::StartNew()
$process = [Diagnostics.Process]::new()
$process.StartInfo = New-GodotProcessStartInfo -ExecutablePath $GodotPath -WorkingDirectory $ProjectPath -ArgumentList $arguments
$timedOut = $false
$processExitCode = $null
$cleanupProcessIds = @()

try {
    if (-not $process.Start()) {
        throw "Godot process did not start."
    }
    $processId = $process.Id
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()

    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        $timedOut = $true
        Stop-ScopedProcessTree -ProcessId $processId
    }

    try {
        $process.WaitForExit()
        $process.Refresh()
        $processExitCode = $process.ExitCode
    } catch {
        $processExitCode = $null
    }

    $postExitRuntime = @(
        Get-ProjectRuntimeProcess -ResolvedProjectPath $ProjectPath -ResolvedGodotPath $GodotPath |
            Where-Object { $_.ProcessId -ne $processId }
    )
    foreach ($leftover in $postExitRuntime) {
        $cleanupProcessIds += [int]$leftover.ProcessId
        Stop-ScopedProcessTree -ProcessId $leftover.ProcessId
    }

    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    Set-Content -LiteralPath $stdoutPath -Value $stdout -Encoding utf8 -NoNewline
    Set-Content -LiteralPath $stderrPath -Value $stderr -Encoding utf8 -NoNewline
} finally {
    $stopwatch.Stop()
    $process.Dispose()
}

if (-not (Test-Path -LiteralPath $godotLogPath -PathType Leaf)) {
    New-Item -ItemType File -Path $godotLogPath | Out-Null
}

$remainingRuntime = @(Get-ProjectRuntimeProcess -ResolvedProjectPath $ProjectPath -ResolvedGodotPath $GodotPath)

$runnerExitCode = if ($timedOut) {
    124
} elseif ($cleanupProcessIds.Count -gt 0 -or $remainingRuntime.Count -gt 0) {
    125
} else {
    [int]$processExitCode
}
$status = if ($timedOut) {
    "timed_out"
} elseif ($remainingRuntime.Count -gt 0) {
    "orphaned"
} elseif ($cleanupProcessIds.Count -gt 0) {
    "orphan_cleaned"
} elseif ($processExitCode -eq 0) {
    "passed"
} else {
    "failed"
}

$result = [ordered]@{
    run_id = $runId
    status = $status
    target_type = $targetType
    target_path = $targetPath
    test_script = if ($targetType -eq "script") { $TestScript } else { $null }
    scene = if ($targetType -eq "scene") { $Scene } else { $null }
    test_arguments = @($TestArgument)
    project_path = $ProjectPath
    godot_path = $GodotPath
    godot_product_version = $godotVersion
    process_id = $processId
    timeout_seconds = $TimeoutSeconds
    timed_out = $timedOut
    process_exit_code = $processExitCode
    runner_exit_code = $runnerExitCode
    started_at_utc = $startedAt.ToString("o")
    duration_seconds = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 3)
    command_arguments = $arguments
    stdout_log = $stdoutPath
    stderr_log = $stderrPath
    godot_log = $godotLogPath
    cleanup_process_ids = @($cleanupProcessIds)
    remaining_project_runtime_process_ids = @($remainingRuntime | ForEach-Object { [int]$_.ProcessId })
}
$result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $resultPath -Encoding utf8
$result["result_json"] = $resultPath
$result | ConvertTo-Json -Depth 5 -Compress | Write-Output
exit $runnerExitCode
