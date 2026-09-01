<#
.SYNOPSIS
Captures headed production-natural evidence for the four presentation cues.

.DESCRIPTION
Runs two existing production-main drivers through thin headed observers.  The
Card-table sentinel proves CARD_SELECT, CARD_PLAY_PUBLIC, and
CARD_RESOLUTION_FOCUS; the independent natural Victory driver proves
FINAL_SETTLEMENT.  The aggregate report preserves both run identities instead
of pretending all four cues came from one match.  Every invocation writes to a
new evidence directory; Commercial Showcase fixture frames are never
overwritten or used as production-natural evidence.
#>
[CmdletBinding()]
param(
    [string]$ProjectPath = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),

    [string]$GodotPath = "C:\Users\Administrator\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe",

    [ValidateRange(60, 900)]
    [int]$TimeoutSeconds = 420,

    [string]$EvidenceRoot = ""
)

$ErrorActionPreference = 'Stop'
$ProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path
$GodotPath = (Resolve-Path -LiteralPath $GodotPath).Path
$runnerPath = Join-Path $ProjectPath 'tools\invoke_godot_test.ps1'
if (-not (Test-Path -LiteralPath $runnerPath -PathType Leaf)) {
    throw "Godot test runner is missing: $runnerPath"
}

$head = (& git -C $ProjectPath rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $head -notmatch '^[0-9a-f]{40}$') {
    throw 'Cannot resolve the evidence Head.'
}
$tree = (& git -C $ProjectPath rev-parse 'HEAD^{tree}').Trim()
$worktreeStatus = @(& git -C $ProjectPath status --porcelain=v1 -uall)
$timestamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fff')
$nonce = [Guid]::NewGuid().ToString('N').Substring(0, 12)
$runKey = "$timestamp-$nonce"
if ([string]::IsNullOrWhiteSpace($EvidenceRoot)) {
    $EvidenceRoot = Join-Path $ProjectPath (
        "reports\presentation\commercial_m1\production_natural_headed\$runKey"
    )
}
$EvidenceRoot = [IO.Path]::GetFullPath($EvidenceRoot)
if (Test-Path -LiteralPath $EvidenceRoot) {
    throw "Evidence root already exists; headed evidence is append-only: $EvidenceRoot"
}
[IO.Directory]::CreateDirectory($EvidenceRoot) | Out-Null

function Invoke-HeadedNaturalRun {
    param(
        [Parameter(Mandatory = $true)][string]$RunName,
        [Parameter(Mandatory = $true)][string]$TestScript,
        [Parameter(Mandatory = $true)][string]$CompletionMarker
    )
    $runEvidenceRoot = Join-Path $EvidenceRoot $RunName
    $runLogRoot = Join-Path $env:LOCALAPPDATA (
        "SpaceSyndicate\production_natural_cue_capture_runs\$runKey\$RunName"
    )
    # Keep Godot's user:// profile deliberately short.  Forward+ shader-cache
    # entries add several nested hash components; placing the profile beneath
    # the long evidence/log path can cross Windows MAX_PATH and makes Godot
    # report a misleading `ERROR: Can't create shader cache folder` even when
    # the project itself is healthy.  Logs and evidence remain in their normal
    # append-only locations; only the disposable per-run profile is shortened.
    $profileRoot = Join-Path ([IO.Path]::GetTempPath()) (
        "SSV076N-$runKey-$RunName"
    )
    $headedCapturePath = Join-Path $runEvidenceRoot 'headed_client.png'
    $runNonce = "$nonce-$RunName"
    $arguments = @(
        "--evidence-root=$runEvidenceRoot",
        "--headed-capture-output=$headedCapturePath",
        "--probe-nonce=$runNonce",
        "--evidence-head=$head"
    )
    $argumentJson = ConvertTo-Json -Compress -InputObject $arguments
    $runnerOutput = @(& pwsh -NoProfile -File $runnerPath `
        -ProjectPath $ProjectPath `
        -GodotPath $GodotPath `
        -TestScript $TestScript `
        -TestArgumentJson $argumentJson `
        -HeadedClientProbe `
        -ExpectedClientSize '1600x960' `
        -WindowProbeTimeoutSeconds 60 `
        -TimeoutSeconds $TimeoutSeconds `
        -ExpectedCompletionMarker $CompletionMarker `
        -LogRoot $runLogRoot `
        -IsolatedUserDataRoot $profileRoot)
    $runnerExitCode = $LASTEXITCODE
    if ($runnerExitCode -ne 0) {
        throw "$RunName headed capture runner failed with $runnerExitCode."
    }
    $runnerResult = $runnerOutput | Select-Object -Last 1 | ConvertFrom-Json
    if (
        [string]$runnerResult.status -ne 'passed' -or
        [int]$runnerResult.runner_exit_code -ne 0 -or
        [int]$runnerResult.process_exit_code -ne 0 -or
        -not [bool]$runnerResult.marker_found -or
        [int]$runnerResult.script_error_count -ne 0 -or
        [int]$runnerResult.diagnostic_count -ne 0 -or
        [int]$runnerResult.task_introduced_error_count -ne 0 -or
        @($runnerResult.remaining_project_runtime_process_ids).Count -ne 0 -or
        -not [bool]$runnerResult.stdout_capture.strict_decode -or
        -not [bool]$runnerResult.stderr_capture.strict_decode -or
        -not [bool]$runnerResult.window_probe.exact_match
    ) {
        throw "$RunName runner receipt is not clean: $($runnerResult.result_json)"
    }
    $manifestPath = Join-Path $runEvidenceRoot 'manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "$RunName capture manifest is missing: $manifestPath"
    }
    $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
    if (
        [string]$manifest.status -ne 'PASS' -or
        [string]$manifest.evidence_class -ne 'PRODUCTION_NATURAL_AUTOMATION_HEADED' -or
        -not [bool]$manifest.natural_gameplay_automation -or
        [bool]$manifest.presentation_fixture -or
        [int]$manifest.fixture_receipt_count -ne 0 -or
        [bool]$manifest.human_green -or
        [string]$manifest.step13_status -ne 'PENDING' -or
        [string]$manifest.step14_status -ne 'PENDING' -or
        [string]$manifest.step15_status -ne 'PENDING'
    ) {
        throw "$RunName manifest has an invalid evidence boundary."
    }
    return [pscustomobject]@{
        name = $RunName
        result = $runnerResult
        manifest = $manifest
        manifest_path = $manifestPath
        evidence_root = $runEvidenceRoot
    }
}

$commonMarkerSuffix = (
    '|evidence_class=PRODUCTION_NATURAL_AUTOMATION_HEADED' +
    '|natural_gameplay_automation=true|fixture_receipt_count=0' +
    '|human_green=false|step13_15=pending'
)
$cardRun = Invoke-HeadedNaturalRun `
    -RunName 'card_table' `
    -TestScript 'res://tests/v076_production_natural_card_table_headed_capture.gd' `
    -CompletionMarker (
        'V076_PRODUCTION_NATURAL_CARD_TABLE_HEADED_CAPTURE|status=PASS' +
        $commonMarkerSuffix
    )
$finalRun = Invoke-HeadedNaturalRun `
    -RunName 'final_settlement' `
    -TestScript 'res://tests/v076_production_natural_final_settlement_headed_capture.gd' `
    -CompletionMarker (
        'V076_PRODUCTION_NATURAL_FINAL_SETTLEMENT_HEADED_CAPTURE|status=PASS' +
        $commonMarkerSuffix
    )

$expectedCues = @(
    'CARD_SELECT',
    'CARD_PLAY_PUBLIC',
    'CARD_RESOLUTION_FOCUS',
    'FINAL_SETTLEMENT'
)
$cueRecords = @($cardRun.manifest.cue_records) + @($finalRun.manifest.cue_records)
$actualCues = @($cueRecords | ForEach-Object { [string]$_.cue_id })
$frameCount = [int]$cardRun.manifest.frame_count + [int]$finalRun.manifest.frame_count
if (
    [int]$cardRun.manifest.frame_count -ne 9 -or
    [int]$finalRun.manifest.frame_count -ne 3 -or
    $frameCount -ne 12 -or
    @(Compare-Object $expectedCues $actualCues).Count -ne 0 -or
    @($cueRecords | Where-Object {
        -not [bool]$_.production_aggregate_parity -or
        -not [bool]$_.fixture_counter_zero -or
        -not [bool]$_.lineage_green -or
        -not [bool]$_.capture_identity_green -or
        (
            [string]$_.cue_id -ne 'FINAL_SETTLEMENT' -and
            (
                [int]$_.director_queue_count_for_receipt -ne 1 -or
                [int]$_.director_finish_count_for_receipt -ne 1
            )
        ) -or
        -not [bool]$_.frames_green
    }).Count -ne 0
) {
    throw 'The two headed runs did not prove all four natural cue contracts.'
}

$sourcePaths = @(
    'tests/v076_production_natural_card_table_headed_capture.gd',
    'tests/v076_production_natural_final_settlement_headed_capture.gd',
    'tests/v076_alpha07_card_table_flow_readiness_test.gd',
    'tests/v076_production_victory_audit_readiness_test.gd',
    'tools/presentation/invoke_v076_production_natural_card_table_capture.ps1'
)
$sourceHashes = @($sourcePaths | ForEach-Object {
    $sourcePath = Join-Path $ProjectPath $_
    [ordered]@{
        path = $_
        sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourcePath).Hash.ToLowerInvariant()
    }
})
$manifestPath = Join-Path $EvidenceRoot 'manifest.json'
$aggregateManifest = [ordered]@{
    schema = 'V076ProductionNaturalFourCueHeadedEvidenceV1'
    status = 'PASS_AUTOMATED_NATURAL_PRODUCTION_HEADED_ONLY'
    evidence_class = 'PRODUCTION_NATURAL_AUTOMATION_HEADED'
    recorded_at_utc = [DateTime]::UtcNow.ToString('o')
    evaluated_source = if ($worktreeStatus.Count -gt 0) { 'HEAD_PLUS_PRESERVED_WORKTREE' } else { 'COMMITTED_HEAD' }
    include_worktree = ($worktreeStatus.Count -gt 0)
    evidence_head = $head
    evidence_head_tree = $tree
    source_hashes = $sourceHashes
    production_main_scene = 'res://scenes/main.tscn'
    natural_gameplay_automation = $true
    presentation_fixture = $false
    fixture_receipt_count = 0
    human_executed = $false
    human_confirmed = $false
    human_green = $false
    production_green = $false
    commercial_m1_green = $false
    step13_status = 'PENDING'
    step14_status = 'PENDING'
    step15_status = 'PENDING'
    cue_count = $cueRecords.Count
    frame_count = $frameCount
    cues = $cueRecords
    runs = @(
        [ordered]@{
            role = 'NON_TERMINAL_CARD_TABLE_NATURAL_DRIVER'
            run_id = [string]$cardRun.result.run_id
            test_script = [string]$cardRun.result.test_script
            manifest = [string]$cardRun.manifest_path
            frame_count = [int]$cardRun.manifest.frame_count
            headed_client_capture = [string]$cardRun.result.window_probe.client_capture.path
        },
        [ordered]@{
            role = 'TERMINAL_VICTORY_NATURAL_DRIVER'
            run_id = [string]$finalRun.result.run_id
            test_script = [string]$finalRun.result.test_script
            manifest = [string]$finalRun.manifest_path
            frame_count = [int]$finalRun.manifest.frame_count
            headed_client_capture = [string]$finalRun.result.window_probe.client_capture.path
        }
    )
    showcase_fixture_boundary = [ordered]@{
        evidence_used = $false
        fixture_class = 'PRESENTATION_FIXTURE'
        natural_gameplay = $false
        may_support_this_production_natural_claim = $false
    }
}
[IO.File]::WriteAllText(
    $manifestPath,
    (ConvertTo-Json -Depth 100 -InputObject $aggregateManifest) + [Environment]::NewLine,
    [Text.UTF8Encoding]::new($false)
)

$runnerReportPath = Join-Path $EvidenceRoot 'runner_report.json'
$runnerRows = @(@($cardRun, $finalRun) | ForEach-Object {
    $runnerResult = $_.result
    [ordered]@{
        role = [string]$_.name
        run_id = [string]$runnerResult.run_id
        duration_seconds = [double]$runnerResult.duration_seconds
        result_json = [string]$runnerResult.result_json
        result_json_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $runnerResult.result_json).Hash.ToLowerInvariant()
        stdout_sha256 = [string]$runnerResult.stdout_capture.sha256
        stderr_sha256 = [string]$runnerResult.stderr_capture.sha256
        process_exit_code = [int]$runnerResult.process_exit_code
        runner_exit_code = [int]$runnerResult.runner_exit_code
        marker_found = [bool]$runnerResult.marker_found
        isolated_user_data_root = [string]$runnerResult.isolated_user_data_root
        exact_window_match = [bool]$runnerResult.window_probe.exact_match
        headed_client_capture = [string]$runnerResult.window_probe.client_capture.path
        headed_client_capture_sha256 = [string]$runnerResult.window_probe.client_capture.sha256
        diagnostic_count = [int]$runnerResult.diagnostic_count
        task_introduced_error_count = [int]$runnerResult.task_introduced_error_count
        residual_process_count = @($runnerResult.remaining_project_runtime_process_ids).Count
    }
})
$runnerReport = [ordered]@{
    schema = 'V076ProductionNaturalFourCueHeadedRunnerReportV1'
    status = 'PASS'
    evidence_class = 'PRODUCTION_NATURAL_AUTOMATION_HEADED'
    recorded_at_utc = [DateTime]::UtcNow.ToString('o')
    evidence_head = $head
    run_count = 2
    runs = $runnerRows
    cue_count = $cueRecords.Count
    frame_count = $frameCount
    fixture_receipt_count = 0
    natural_gameplay_automation = $true
    human_executed = $false
    human_confirmed = $false
    human_green = $false
    production_green = $false
    commercial_m1_green = $false
    step13_status = 'PENDING'
    step14_status = 'PENDING'
    step15_status = 'PENDING'
}
[IO.File]::WriteAllText(
    $runnerReportPath,
    (ConvertTo-Json -Depth 40 -InputObject $runnerReport) + [Environment]::NewLine,
    [Text.UTF8Encoding]::new($false)
)

Write-Output (
    'V076_PRODUCTION_NATURAL_FOUR_CUE_CAPTURE_WRAPPER|status=PASS' +
    '|evidence_class=PRODUCTION_NATURAL_AUTOMATION_HEADED' +
    '|natural_gameplay_automation=true|fixture_receipt_count=0' +
    '|human_green=false|step13_15=pending|run_count=2|cue_count=4|frame_count=12' +
    "|evidence_root=$EvidenceRoot|manifest=$manifestPath" +
    "|runner_report=$runnerReportPath"
)
