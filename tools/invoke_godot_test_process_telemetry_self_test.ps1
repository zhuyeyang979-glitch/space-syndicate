<#
.SYNOPSIS
Exercises the Godot runner process-telemetry helpers without launching Godot.

.DESCRIPTION
Parses invoke_godot_test.ps1, loads only its telemetry and atomic-JSON helper
functions, samples this PowerShell process, and proves identity mismatch,
missing-process, in-worktree path, backward-CPU, and failed atomic-target
controls all fail closed. Evidence is written outside the repository.
#>
[CmdletBinding()]
param(
    [string]$RunnerPath = (Join-Path $PSScriptRoot "invoke_godot_test.ps1"),
    [string]$EvidenceRoot = (Join-Path $env:LOCALAPPDATA ("SpaceSyndicate\runner_process_telemetry_self_test\{0}-{1}" -f [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss-fff"), ([guid]::NewGuid().ToString("N").Substring(0, 8))))
)

$ErrorActionPreference = "Stop"

function Assert-Condition {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Condition,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Assert-Throws {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Action,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $threw = $false
    try {
        & $Action
    } catch {
        $threw = $true
    }
    Assert-Condition $threw $Message
}

$RunnerPath = (Resolve-Path -LiteralPath $RunnerPath).Path
$EvidenceRoot = [IO.Path]::GetFullPath($EvidenceRoot)
$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
[IO.Directory]::CreateDirectory($EvidenceRoot) | Out-Null

$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile(
    $RunnerPath,
    [ref]$tokens,
    [ref]$parseErrors
)
Assert-Condition (@($parseErrors).Count -eq 0) "Runner has PowerShell parse errors."

$helperNames = @(
    "Write-AtomicUtf8Json",
    "Assert-PathChainHasNoReparsePoint",
    "Resolve-LiveTelemetryPath",
    "New-ProcessStartToken",
    "New-ProcessTelemetryState",
    "Get-ProcessObjectResourceTelemetrySample",
    "Get-ProcessResourceTelemetrySample",
    "Update-ProcessTelemetryState",
    "Set-ProcessTelemetryFailure",
    "Publish-ProcessTelemetryState",
    "Get-TelemetryGatedRunnerOutcome",
    "Select-EffectiveProcessTelemetry",
    "Get-ProcessTelemetryResultFields",
    "Invoke-HeadedTelemetryTick"
)
foreach ($helperName in $helperNames) {
    $matches = @(
        $ast.FindAll({
            param($node)
            $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
                $node.Name -eq $helperName
        }, $true)
    )
    Assert-Condition ($matches.Count -eq 1) "Runner helper '$helperName' was not found exactly once."
    . ([scriptblock]::Create($matches[0].Extent.Text))
}

$telemetryParameter = @(
    $ast.ParamBlock.Parameters |
        Where-Object { $_.Name.VariablePath.UserPath -eq "LiveTelemetryPath" }
)
Assert-Condition ($telemetryParameter.Count -eq 1) "Runner LiveTelemetryPath parameter was not found exactly once."
Assert-Condition ($telemetryParameter[0].DefaultValue.Extent.Text -ceq '""') "LiveTelemetryPath default is not an empty string."

$runnerText = [IO.File]::ReadAllText($RunnerPath)
Assert-Condition ($runnerText.Contains('$process.WaitForExit(250)')) "Runner no longer polls the process at the expected 250 ms cadence."
Assert-Condition ($runnerText.Contains('Get-ProcessResourceTelemetrySample')) "Runner polling loop is not wired to resource sampling."
Assert-Condition ($runnerText.Contains('"telemetry_failed"')) "Runner omits fail-closed telemetry status."
Assert-Condition ($runnerText.Contains('132')) "Runner omits reserved telemetry failure exit 132."

$defaultState = New-ProcessTelemetryState
Assert-Condition (-not [bool]$defaultState.requested) "Default invocation unexpectedly requests telemetry."
Assert-Condition ($defaultState.status -eq "not_requested") "Default telemetry state is not not_requested."
Assert-Condition ((Resolve-LiveTelemetryPath -Path "" -ResolvedProjectPath $ProjectRoot) -eq "") "Empty telemetry path did not remain disabled."

$insidePath = Join-Path $ProjectRoot ".runner-live-telemetry-negative.json"
Assert-Throws {
    Resolve-LiveTelemetryPath -Path $insidePath -ResolvedProjectPath $ProjectRoot | Out-Null
} "In-worktree telemetry path was accepted."

$junctionPath = Join-Path $EvidenceRoot "project-junction"
try {
    New-Item -ItemType Junction -Path $junctionPath -Target $ProjectRoot -Force | Out-Null
    Assert-Throws {
        Resolve-LiveTelemetryPath `
            -Path (Join-Path $junctionPath "junction-telemetry.json") `
            -ResolvedProjectPath $ProjectRoot | Out-Null
    } "Telemetry path through an external junction into the worktree was accepted."
} finally {
    if (Test-Path -LiteralPath $junctionPath) {
        [IO.Directory]::Delete([IO.Path]::GetFullPath($junctionPath))
    }
}

$livePath = Join-Path $EvidenceRoot "live-telemetry.json"
$resolvedLivePath = Resolve-LiveTelemetryPath `
    -Path $livePath `
    -ResolvedProjectPath $ProjectRoot
Assert-Condition ([string]::Equals($resolvedLivePath, [IO.Path]::GetFullPath($livePath), [StringComparison]::OrdinalIgnoreCase)) "External telemetry path was not normalized exactly."

$currentProcess = [Diagnostics.Process]::GetCurrentProcess()
try {
    $processId = $currentProcess.Id
    $startTimeUtc = $currentProcess.StartTime.ToUniversalTime()
} finally {
    $currentProcess.Dispose()
}
$startToken = New-ProcessStartToken `
    -ProcessId $processId `
    -StartTimeUtc $startTimeUtc
$state = New-ProcessTelemetryState `
    -LivePath $resolvedLivePath `
    -RunId "offline-self-test" `
    -Phase "self_test" `
    -TargetPath "pwsh-current-process"
$sampleOne = Get-ProcessResourceTelemetrySample `
    -ProcessId $processId `
    -ExpectedStartToken $startToken
Update-ProcessTelemetryState -State $state -Sample $sampleOne
[Threading.Thread]::SpinWait(20000)
$sampleTwo = Get-ProcessResourceTelemetrySample `
    -ProcessId $processId `
    -ExpectedStartToken $startToken
Update-ProcessTelemetryState -State $state -Sample $sampleTwo

Assert-Condition ($state.sample_count -eq 2) "Telemetry sample count did not advance exactly twice."
Assert-Condition ($state.process_id -eq $processId) "Telemetry PID does not identify the sampled process."
Assert-Condition ($state.process_start_token -ceq $startToken) "Telemetry start token changed."
Assert-Condition ($state.godot_pid -eq $processId) "Telemetry godot_pid alias does not identify the sampled process."
Assert-Condition ($state.godot_start_token -ceq $startToken) "Telemetry godot_start_token alias changed."
Assert-Condition ($state.cpu_time_seconds -ge 0.0) "Telemetry CPU time is negative."
Assert-Condition ($state.working_set_bytes -gt 0) "Telemetry working set is not positive."
Assert-Condition ($state.peak_working_set_bytes -ge $state.working_set_bytes) "Telemetry peak is below the current working set."

Assert-Throws {
    Get-ProcessResourceTelemetrySample `
        -ProcessId $processId `
        -ExpectedStartToken "$startToken-wrong" | Out-Null
} "Wrong start token did not fail closed."
Assert-Throws {
    Get-ProcessResourceTelemetrySample `
        -ProcessId 2147483647 `
        -ExpectedStartToken "2147483647:1" | Out-Null
} "Missing PID did not fail closed."

$backwardSample = [pscustomobject][ordered]@{
    process_id = $processId
    process_start_token = $startToken
    process_started_at_utc = $startTimeUtc.ToString("o")
    sampled_at_utc = [DateTime]::UtcNow.ToString("o")
    cpu_time_seconds = [double]$state.cpu_time_seconds - 1.0
    working_set_bytes = [int64]$state.working_set_bytes
    peak_working_set_bytes = [int64]$state.peak_working_set_bytes
}
Assert-Throws {
    Update-ProcessTelemetryState -State $state -Sample $backwardSample
} "Backward CPU sample did not fail closed."

Publish-ProcessTelemetryState -State $state
$state.status = "completed"
$state.ended_at_utc = [DateTime]::UtcNow.ToString("o")
Publish-ProcessTelemetryState -State $state
$liveJson = [IO.File]::ReadAllText($resolvedLivePath) | ConvertFrom-Json -Depth 20
Assert-Condition ($liveJson.schema -eq "SpaceSyndicateGodotProcessTelemetryV1") "Atomic telemetry JSON schema mismatch."
Assert-Condition ($liveJson.status -eq "completed") "Atomic telemetry replacement did not publish the newest state."
Assert-Condition ($liveJson.sample_count -eq 2) "Atomic telemetry JSON lost the sample count."
Assert-Condition ($liveJson.peak_working_set_bytes -ge $liveJson.working_set_bytes) "Atomic telemetry JSON lost the peak working set."
Assert-Condition (@(Get-ChildItem -LiteralPath $EvidenceRoot -Filter "live-telemetry.json.*.tmp" -File).Count -eq 0) "Successful atomic publish left a temporary file."

$badTarget = Join-Path $EvidenceRoot "bad-target"
[IO.Directory]::CreateDirectory($badTarget) | Out-Null
$badState = New-ProcessTelemetryState -LivePath $badTarget
Assert-Throws {
    Publish-ProcessTelemetryState -State $badState
} "Directory telemetry target did not fail closed."
Assert-Condition (@(Get-ChildItem -LiteralPath $EvidenceRoot -Filter "bad-target.*.tmp" -File).Count -eq 0) "Failed atomic publish left a temporary file."

$telemetryFailureOutcome = Get-TelemetryGatedRunnerOutcome `
    -TelemetryFailed $true `
    -Status "passed" `
    -RunnerExitCode 0
Assert-Condition ($telemetryFailureOutcome.status -eq "telemetry_failed") "Telemetry failure did not force telemetry_failed status."
Assert-Condition ($telemetryFailureOutcome.runner_exit_code -eq 132) "Telemetry failure did not force runner exit 132."
$normalOutcome = Get-TelemetryGatedRunnerOutcome `
    -TelemetryFailed $false `
    -Status "marker_missing" `
    -RunnerExitCode 128
Assert-Condition ($normalOutcome.status -eq "marker_missing") "Non-telemetry status was changed by the telemetry gate."
Assert-Condition ($normalOutcome.runner_exit_code -eq 128) "Non-telemetry exit code was changed by the telemetry gate."

$importTelemetry = New-ProcessTelemetryState `
    -LivePath $resolvedLivePath `
    -RunId "phase-contract" `
    -Phase "import" `
    -TargetPath "res://tests/phase_contract.gd"
$importTelemetry.process_start_token = "101:1001"
$importTelemetry.sample_count = 3
$importTelemetry.cpu_time_seconds = 1.25
$importTelemetry.working_set_bytes = [int64]1024
$importTelemetry.peak_working_set_bytes = [int64]2048
$importRecord = [ordered]@{
    attempted = $true
    process_telemetry = $importTelemetry
}
$testTelemetry = New-ProcessTelemetryState `
    -LivePath $resolvedLivePath `
    -RunId "phase-contract" `
    -Phase "test" `
    -TargetPath "res://tests/phase_contract.gd"
$testTelemetry.process_start_token = "202:2002"
$testTelemetry.sample_count = 5
$testTelemetry.cpu_time_seconds = 2.5
$testTelemetry.working_set_bytes = [int64]4096
$testTelemetry.peak_working_set_bytes = [int64]8192
$testProcess = [pscustomobject]@{ process_telemetry = $testTelemetry }
$selectedImport = Select-EffectiveProcessTelemetry `
    -TestStarted $false `
    -TestProcess $null `
    -ImportRecord $importRecord
$selectedTest = Select-EffectiveProcessTelemetry `
    -TestStarted $true `
    -TestProcess $testProcess `
    -ImportRecord $importRecord
Assert-Condition ($selectedImport.phase -eq "import") "Import-only result did not retain import telemetry."
Assert-Condition ($selectedTest.phase -eq "test") "Started test result did not select test telemetry."
Assert-Condition ($importRecord.process_telemetry.phase -eq "import") "Test phase selection mutated nested import telemetry."
$resultFields = Get-ProcessTelemetryResultFields -State $selectedTest
Assert-Condition ($resultFields.process_start_token -ceq "202:2002") "Result field start token did not come from selected test telemetry."
Assert-Condition ($resultFields.godot_start_token -ceq "202:2002") "Result field Godot start token alias diverged."
Assert-Condition ($resultFields.telemetry_sample_count -eq 5) "Result field sample count diverged."
Assert-Condition ($resultFields.cpu_time_seconds -eq 2.5) "Result field CPU time diverged."
Assert-Condition ($resultFields.working_set_bytes -eq 4096) "Result field working set diverged."
Assert-Condition ($resultFields.peak_working_set_bytes -eq 8192) "Result field peak working set diverged."
Assert-Condition ($resultFields.process_telemetry.phase -eq "test") "Result field telemetry object diverged."
$disabledResultFields = Get-ProcessTelemetryResultFields -State $null
Assert-Condition ($null -eq $disabledResultFields.process_start_token) "Disabled telemetry exposed a start token."
Assert-Condition ($disabledResultFields.telemetry_sample_count -eq 0) "Disabled telemetry exposed samples."
Assert-Condition ($disabledResultFields.cpu_time_seconds -eq 0.0) "Disabled telemetry exposed CPU time."
Assert-Condition ($null -eq $disabledResultFields.process_telemetry) "Disabled telemetry exposed a telemetry object."

$childProcess = Start-Process `
    -FilePath (Get-Process -Id $PID).Path `
    -ArgumentList @("-NoProfile", "-Command", "Start-Sleep -Milliseconds 750") `
    -PassThru `
    -WindowStyle Hidden
try {
    $childStartToken = New-ProcessStartToken `
        -ProcessId $childProcess.Id `
        -StartTimeUtc $childProcess.StartTime.ToUniversalTime()
    $childState = New-ProcessTelemetryState `
        -LivePath $resolvedLivePath `
        -RunId "exit-boundary-contract" `
        -Phase "self_test" `
        -TargetPath "pwsh-child-process"
    $childInitialSample = Get-ProcessResourceTelemetrySample `
        -ProcessId $childProcess.Id `
        -ExpectedStartToken $childStartToken
    Update-ProcessTelemetryState -State $childState -Sample $childInitialSample
    $childProcess.WaitForExit()
    $childFinalSample = Get-ProcessObjectResourceTelemetrySample `
        -Process $childProcess `
        -ExpectedStartToken $childStartToken
    Update-ProcessTelemetryState -State $childState -Sample $childFinalSample
    Assert-Condition ($childState.sample_count -eq 2) "Exit-boundary process-object sample was not retained."
    Assert-Condition ($childState.cpu_time_seconds -ge $childInitialSample.cpu_time_seconds) "Exit-boundary CPU time moved backwards."
    Assert-Condition ($childState.peak_working_set_bytes -ge $childInitialSample.working_set_bytes) "Exit-boundary update lost the previously observed peak."
    $exitRaceTickInvoked = $false
    $exitRaceTick = { $exitRaceTickInvoked = $true }.GetNewClosure()
    $exitRaceWasNormal = -not (Invoke-HeadedTelemetryTick `
        -Process $childProcess `
        -TelemetryTick $exitRaceTick)
    Assert-Condition $exitRaceWasNormal "Exited headed process was misclassified as a telemetry-tick failure."
    Assert-Condition (-not $exitRaceTickInvoked) "Exited headed process invoked a telemetry tick against a stale PID."
} finally {
    if (-not $childProcess.HasExited) {
        $childProcess.Kill($true)
        $childProcess.WaitForExit(10000) | Out-Null
    }
    $childProcess.Dispose()
}

$summary = [ordered]@{
    status = "passed"
    godot_started = $false
    mcp_started = $false
    formal_started = $false
    runner_parse_error_count = @($parseErrors).Count
    helper_count = $helperNames.Count
    negative_control_count = 6
    telemetry_failure_exit_code = [int]$telemetryFailureOutcome.runner_exit_code
    import_phase_selected = [string]$selectedImport.phase
    test_phase_selected = [string]$selectedTest.phase
    result_field_contract_count = 7
    exit_boundary_sample_count = [int]$childState.sample_count
    headed_exit_race_normal = [bool]$exitRaceWasNormal
    sample_count = [int]$state.sample_count
    process_id = $processId
    process_start_token = $startToken
    cpu_time_seconds = [double]$state.cpu_time_seconds
    working_set_bytes = [int64]$state.working_set_bytes
    peak_working_set_bytes = [int64]$state.peak_working_set_bytes
    live_telemetry_path = $resolvedLivePath
    atomic_temporary_file_count = @(
        Get-ChildItem -LiteralPath $EvidenceRoot -Filter "*.tmp" -File
    ).Count
}
$summaryPath = Join-Path $EvidenceRoot "summary.json"
Write-AtomicUtf8Json -Path $summaryPath -Value $summary
$summary["summary_json"] = $summaryPath
$summary | ConvertTo-Json -Depth 10 -Compress | Write-Output
