<#
.SYNOPSIS
Runs one Godot 4.7 script or scene gate as a blocking, timeout-bounded process.

.DESCRIPTION
Uses the GUI Godot executable directly, captures the actual process exit code,
writes stdout/stderr/Godot logs to an isolated directory outside the repository,
and removes only scoped headless/game processes for this absolute project path.

Runner exit codes are the Godot exit code for a completed test, 124 for timeout,
125 when a completed process leaves a scoped runtime process (even if cleanup
succeeds), and 126 when an import bootstrap fails without a more specific exit
code. The console wrapper is deliberately rejected because it can return before
the real process.

.EXAMPLE
pwsh -File tools/invoke_godot_test.ps1 `
    -TestScript res://tests/smoke_test.gd `
    -TestArgument --check-only `
    -TimeoutSeconds 180

.EXAMPLE
pwsh -File tools/invoke_godot_test.ps1 `
    -Scene res://scenes/tools/ProductMarketRuntimeCharacterizationBench.tscn `
    -TimeoutSeconds 300

.EXAMPLE
pwsh -File tools/invoke_godot_test.ps1 `
    -TestScript res://tests/main_runtime_composition_test.gd `
    -EnsureImported `
    -ImportTimeoutSeconds 300 `
    -TimeoutSeconds 180

.EXAMPLE
pwsh -File tools/invoke_godot_test.ps1 `
    -TestScript res://tests/main_runtime_composition_test.gd `
    -RefreshImport `
    -ImportTimeoutSeconds 300 `
    -TimeoutSeconds 180
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

    [switch]$EnsureImported,

    [Alias("ForceImport")]
    [switch]$RefreshImport,

    [ValidateRange(1, 86400)]
    [int]$ImportTimeoutSeconds = 300,

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

function Get-ClassCacheAudit {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $item = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
    if ($null -eq $item -or $item.PSIsContainer) {
        return [pscustomobject][ordered]@{
            present = $false
            valid = $false
            invalid_reason = "missing"
            size = [int64]0
            mtime_utc = $null
            sha256 = $null
        }
    }

    $size = [int64]$item.Length
    $mtimeUtc = $item.LastWriteTimeUtc.ToString("o")
    $sha256 = $null
    $valid = $false
    $invalidReason = $null
    try {
        $sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
        if ($size -le 0) {
            $invalidReason = "empty"
        } else {
            $content = [IO.File]::ReadAllText($Path)
            if ($content.TrimStart().StartsWith("list=", [StringComparison]::Ordinal)) {
                $valid = $true
            } else {
                $invalidReason = "invalid_format"
            }
        }
    } catch {
        $invalidReason = "unreadable"
    }

    return [pscustomobject][ordered]@{
        present = $true
        valid = $valid
        invalid_reason = $invalidReason
        size = $size
        mtime_utc = $mtimeUtc
        sha256 = $sha256
    }
}

function Invoke-GodotBlockingProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResolvedProjectPath,
        [Parameter(Mandatory = $true)]
        [string]$ResolvedGodotPath,
        [Parameter(Mandatory = $true)]
        [string[]]$ArgumentList,
        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 86400)]
        [int]$ProcessTimeoutSeconds,
        [Parameter(Mandatory = $true)]
        [string]$StdoutPath,
        [Parameter(Mandatory = $true)]
        [string]$StderrPath,
        [Parameter(Mandatory = $true)]
        [string]$GodotLogPath
    )

    $startedAt = [DateTime]::UtcNow
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = New-GodotProcessStartInfo -ExecutablePath $ResolvedGodotPath -WorkingDirectory $ResolvedProjectPath -ArgumentList $ArgumentList
    $timedOut = $false
    $processId = $null
    $processExitCode = $null
    $cleanupProcessIds = @()

    try {
        if (-not $process.Start()) {
            throw "Godot process did not start."
        }
        $processId = $process.Id
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()

        if (-not $process.WaitForExit($ProcessTimeoutSeconds * 1000)) {
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
            Get-ProjectRuntimeProcess -ResolvedProjectPath $ResolvedProjectPath -ResolvedGodotPath $ResolvedGodotPath |
                Where-Object { $_.ProcessId -ne $processId }
        )
        foreach ($leftover in $postExitRuntime) {
            $cleanupProcessIds += [int]$leftover.ProcessId
            Stop-ScopedProcessTree -ProcessId $leftover.ProcessId
        }

        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Set-Content -LiteralPath $StdoutPath -Value $stdout -Encoding utf8 -NoNewline
        Set-Content -LiteralPath $StderrPath -Value $stderr -Encoding utf8 -NoNewline
    } finally {
        $stopwatch.Stop()
        $process.Dispose()
    }

    if (-not (Test-Path -LiteralPath $GodotLogPath -PathType Leaf)) {
        New-Item -ItemType File -Path $GodotLogPath | Out-Null
    }

    $remainingRuntime = @(Get-ProjectRuntimeProcess -ResolvedProjectPath $ResolvedProjectPath -ResolvedGodotPath $ResolvedGodotPath)
    $runnerExitCode = if ($timedOut) {
        124
    } elseif ($cleanupProcessIds.Count -gt 0 -or $remainingRuntime.Count -gt 0) {
        125
    } elseif ($null -eq $processExitCode) {
        126
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

    return [pscustomobject][ordered]@{
        status = $status
        process_id = $processId
        timeout_seconds = $ProcessTimeoutSeconds
        timed_out = $timedOut
        process_exit_code = $processExitCode
        runner_exit_code = $runnerExitCode
        started_at_utc = $startedAt.ToString("o")
        duration_seconds = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 3)
        command_arguments = @($ArgumentList)
        stdout_log = $StdoutPath
        stderr_log = $StderrPath
        godot_log = $GodotLogPath
        cleanup_process_ids = @($cleanupProcessIds)
        remaining_project_runtime_process_ids = @($remainingRuntime | ForEach-Object { [int]$_.ProcessId })
    }
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
$importStdoutPath = Join-Path $runDirectory "import.stdout.log"
$importStderrPath = Join-Path $runDirectory "import.stderr.log"
$importGodotLogPath = Join-Path $runDirectory "import.godot.log"
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

$classCachePath = Join-Path $ProjectPath ".godot\global_script_class_cache.cfg"
$cacheBefore = Get-ClassCacheAudit -Path $classCachePath
$importMode = if ($RefreshImport) {
    "refresh"
} elseif ($EnsureImported) {
    "ensure"
} else {
    "none"
}
$importRequested = $importMode -ne "none"
$importReason = if ($RefreshImport) {
    "refresh_requested"
} elseif (-not $EnsureImported) {
    "not_requested"
} elseif (-not $cacheBefore.present) {
    "cache_missing"
} elseif (-not $cacheBefore.valid) {
    "cache_invalid"
} else {
    "cache_valid"
}
$importRecord = [ordered]@{
    requested = $importRequested
    mode = $importMode
    reason = $importReason
    cache_path = $classCachePath
    cache_present_before = [bool]$cacheBefore.present
    cache_valid_before = [bool]$cacheBefore.valid
    cache_invalid_reason_before = $cacheBefore.invalid_reason
    cache_size_before = [int64]$cacheBefore.size
    cache_mtime_utc_before = $cacheBefore.mtime_utc
    cache_sha256_before = $cacheBefore.sha256
    attempted = $false
    status = if ($importRequested) { "pending" } else { "not_requested" }
    process_status = $null
    succeeded = $null
    process_id = $null
    timeout_seconds = $ImportTimeoutSeconds
    timed_out = $false
    process_exit_code = $null
    runner_exit_code = $null
    started_at_utc = $null
    duration_seconds = 0.0
    command_arguments = @()
    stdout_log = $null
    stderr_log = $null
    godot_log = $null
    cleanup_process_ids = @()
    remaining_project_runtime_process_ids = @()
    cache_present_after = [bool]$cacheBefore.present
    cache_valid_after = [bool]$cacheBefore.valid
    cache_invalid_reason_after = $cacheBefore.invalid_reason
    cache_size_after = [int64]$cacheBefore.size
    cache_mtime_utc_after = $cacheBefore.mtime_utc
    cache_sha256_after = $cacheBefore.sha256
    cache_changed = $false
    cache_size_delta = [int64]0
}

$importReady = $true
$importFailureStatus = $null
$importFailureExitCode = $null
if ($importMode -eq "ensure" -and $cacheBefore.valid) {
    $importRecord.status = "cache_valid"
    $importRecord.succeeded = $true
} elseif ($importRequested) {
    $importArguments = @(
        "--headless",
        "--path", $ProjectPath,
        "--log-file", $importGodotLogPath,
        "--import"
    )
    $importRecord.attempted = $true
    $importProcess = Invoke-GodotBlockingProcess `
        -ResolvedProjectPath $ProjectPath `
        -ResolvedGodotPath $GodotPath `
        -ArgumentList $importArguments `
        -ProcessTimeoutSeconds $ImportTimeoutSeconds `
        -StdoutPath $importStdoutPath `
        -StderrPath $importStderrPath `
        -GodotLogPath $importGodotLogPath
    $importRecord.process_status = $importProcess.status
    foreach ($property in $importProcess.PSObject.Properties) {
        if ($property.Name -ne "status") {
            $importRecord[$property.Name] = $property.Value
        }
    }
    $cacheAfter = Get-ClassCacheAudit -Path $classCachePath
    $importRecord.cache_present_after = [bool]$cacheAfter.present
    $importRecord.cache_valid_after = [bool]$cacheAfter.valid
    $importRecord.cache_invalid_reason_after = $cacheAfter.invalid_reason
    $importRecord.cache_size_after = [int64]$cacheAfter.size
    $importRecord.cache_mtime_utc_after = $cacheAfter.mtime_utc
    $importRecord.cache_sha256_after = $cacheAfter.sha256
    $importRecord.cache_changed = $cacheBefore.sha256 -ne $cacheAfter.sha256
    $importRecord.cache_size_delta = [int64]$cacheAfter.size - [int64]$cacheBefore.size
    $importReady = $importProcess.status -eq "passed" -and [bool]$cacheAfter.valid
    $importRecord.succeeded = $importReady
    if ($importReady) {
        $importRecord.status = if ($importMode -eq "refresh") { "refreshed" } else { "bootstrapped" }
    } elseif ($importProcess.status -eq "passed") {
        if (-not $cacheAfter.present) {
            $importRecord.status = "cache_missing_after_import"
            $importFailureStatus = "import_cache_missing"
        } else {
            $importRecord.status = "cache_invalid_after_import"
            $importFailureStatus = "import_cache_invalid"
        }
        $importFailureExitCode = 126
    } else {
        $importRecord.status = $importProcess.status
        $importFailureStatus = "import_$($importProcess.status)"
        $importFailureExitCode = [int]$importProcess.runner_exit_code
        if ($importFailureExitCode -eq 0) {
            $importFailureExitCode = 126
        }
    }
}

$testStarted = $false
$testProcess = $null
if ($importReady) {
    $testStarted = $true
    $testProcess = Invoke-GodotBlockingProcess `
        -ResolvedProjectPath $ProjectPath `
        -ResolvedGodotPath $GodotPath `
        -ArgumentList $arguments `
        -ProcessTimeoutSeconds $TimeoutSeconds `
        -StdoutPath $stdoutPath `
        -StderrPath $stderrPath `
        -GodotLogPath $godotLogPath
}

$status = if ($testStarted) { $testProcess.status } else { $importFailureStatus }
$runnerExitCode = if ($testStarted) { [int]$testProcess.runner_exit_code } else { [int]$importFailureExitCode }
$remainingRuntime = @(Get-ProjectRuntimeProcess -ResolvedProjectPath $ProjectPath -ResolvedGodotPath $GodotPath)
$reportedCommandArguments = [Collections.Generic.List[string]]::new()
$reportedCleanupProcessIds = [Collections.Generic.List[int]]::new()
if ($testStarted) {
    foreach ($argument in $arguments) {
        $reportedCommandArguments.Add([string]$argument)
    }
    foreach ($cleanupProcessId in @($testProcess.cleanup_process_ids)) {
        $reportedCleanupProcessIds.Add([int]$cleanupProcessId)
    }
} else {
    foreach ($cleanupProcessId in @($importRecord.cleanup_process_ids)) {
        $reportedCleanupProcessIds.Add([int]$cleanupProcessId)
    }
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
    ensure_imported = [bool]$EnsureImported
    refresh_import = [bool]$RefreshImport
    import_mode = $importMode
    import_status = $importRecord.status
    import = $importRecord
    test_started = $testStarted
    process_id = if ($testStarted) { $testProcess.process_id } else { $null }
    timeout_seconds = $TimeoutSeconds
    timed_out = if ($testStarted) { $testProcess.timed_out } else { $importRecord.timed_out }
    process_exit_code = if ($testStarted) { $testProcess.process_exit_code } else { $null }
    runner_exit_code = $runnerExitCode
    started_at_utc = if ($testStarted) { $testProcess.started_at_utc } else { $importRecord.started_at_utc }
    duration_seconds = if ($testStarted) { $testProcess.duration_seconds } else { $importRecord.duration_seconds }
    command_arguments = $reportedCommandArguments
    stdout_log = if ($testStarted) { $stdoutPath } else { $null }
    stderr_log = if ($testStarted) { $stderrPath } else { $null }
    godot_log = if ($testStarted) { $godotLogPath } else { $null }
    cleanup_process_ids = $reportedCleanupProcessIds
    remaining_project_runtime_process_ids = @($remainingRuntime | ForEach-Object { [int]$_.ProcessId })
}
$result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $resultPath -Encoding utf8
$result["result_json"] = $resultPath
$result | ConvertTo-Json -Depth 5 -Compress | Write-Output
exit $runnerExitCode
