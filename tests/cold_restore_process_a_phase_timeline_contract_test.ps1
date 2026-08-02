[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$modulePath = Join-Path $projectRoot "scripts/tools/cold_restore_attested_process.psm1"
Import-Module $modulePath -Force

$script:checks = 0
$script:failures = [Collections.Generic.List[string]]::new()
$runId = "phase-timeline-$([Guid]::NewGuid().ToString('N'))"
$repositoryHead = "d" * 40
$scenarioFingerprint = "a" * 64
$root = Join-Path ([IO.Path]::GetTempPath()) ("space syndicate phase timeline 测试 " + [Guid]::NewGuid().ToString("N"))
$eventDirectory = Join-Path $root "events"
$timelinePath = Join-Path $root "producer.phase_timeline.json"
[IO.Directory]::CreateDirectory($eventDirectory) | Out-Null

function Assert-TimelineCondition {
    param([bool]$Condition, [string]$Message)
    $script:checks += 1
    if (-not $Condition) {
        $script:failures.Add($Message)
    }
}

function New-PhaseRow {
    param(
        [Parameter(Mandatory = $true)][string]$PhaseId,
        [Parameter(Mandatory = $true)][int64]$Entered,
        [int64]$Completed = 0
    )
    return [pscustomobject][ordered]@{
        phase_id = $PhaseId
        entered_monotonic_ms = $Entered
        completed_monotonic_ms = $Completed
        duration_ms = $(if ($Completed -gt 0) { $Completed - $Entered } else { 0 })
        success = $Completed -gt 0
        reason_code = $(if ($Completed -gt 0) { "ok" } else { "in_progress" })
        evidence_fingerprint = ""
    }
}

function New-TimelineSnapshot {
    param(
        [Parameter(Mandatory = $true)][int]$Sequence,
        [Parameter(Mandatory = $true)][object[]]$Rows,
        [string]$CandidateRunId = $runId,
        [string]$CandidateHead = $repositoryHead
    )
    $lastRow = @($Rows)[@($Rows).Count - 1]
    $lastCompleted = @($Rows | Where-Object { [int64]$_.completed_monotonic_ms -gt 0 })
    $value = [pscustomobject][ordered]@{
        schema_version = 1
        timeline_id = "ProcessAPhaseTimelineV1"
        run_id = $CandidateRunId
        role = "producer"
        repository_head = $CandidateHead
        scenario_fingerprint = $scenarioFingerprint
        official = $false
        process_start_monotonic_ms = [int64]1000
        snapshot_sequence = $Sequence
        phase_rows = @($Rows)
        current_phase = $(if ([int64]$lastRow.completed_monotonic_ms -eq 0) { [string]$lastRow.phase_id } else { "" })
        last_completed_phase = $(if ($lastCompleted.Count -gt 0) { [string]$lastCompleted[-1].phase_id } else { "" })
        last_progress_monotonic_ms = [int64]$(if ([int64]$lastRow.completed_monotonic_ms -gt 0) { [int64]$lastRow.completed_monotonic_ms } else { [int64]$lastRow.entered_monotonic_ms })
        save_file_exists = $false
        save_file_bytes = [int64]0
        save_file_sha256 = ""
        child_completion_written = $false
        allowlisted_manifest_written = $false
        quit_requested = $false
        timeline_fingerprint = ""
    }
    $value.timeline_fingerprint = Get-ColdRestoreEvidenceFingerprint $value "timeline_fingerprint"
    return $value
}

function Write-TimelineEvent {
    param([Parameter(Mandatory = $true)]$Value)
    $path = Join-Path $eventDirectory ("{0:D6}.snapshot.json" -f [int]$Value.snapshot_sequence)
    Write-ColdRestoreAtomicJson $path $Value | Out-Null
    return $path
}

try {
    $snapshot1 = New-TimelineSnapshot 1 @((New-PhaseRow "child_bootstrap" 1000))
    $event1 = Write-TimelineEvent $snapshot1
    $sync1 = Sync-ColdRestoreProcessAPhaseTimeline $eventDirectory $timelinePath $runId $repositoryHead
    Assert-TimelineCondition ([bool]$sync1.valid -and [bool]$sync1.found -and [int]$sync1.value.snapshot_sequence -eq 1) "first event installs a stable timeline"
    Assert-TimelineCondition ((Get-Content -LiteralPath $timelinePath -Raw -Encoding UTF8 | ConvertFrom-Json).timeline_fingerprint -eq $snapshot1.timeline_fingerprint) "stable timeline readback matches the first event"

    $snapshot2 = New-TimelineSnapshot 2 @((New-PhaseRow "child_bootstrap" 1000 1010))
    $event2 = Write-TimelineEvent $snapshot2
    $sync2 = Sync-ColdRestoreProcessAPhaseTimeline $eventDirectory $timelinePath $runId $repositoryHead
    Assert-TimelineCondition ([bool]$sync2.valid -and [int]$sync2.value.snapshot_sequence -eq 2) "atomic replacement advances the stable timeline"
    Assert-TimelineCondition (@(Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object { $_.Name -match '\.(tmp|swap)\.' }).Count -eq 0) "atomic replacement leaves no temp or swap artifact"
    $idempotent = Sync-ColdRestoreProcessAPhaseTimeline $eventDirectory $timelinePath $runId $repositoryHead
    Assert-TimelineCondition ([bool]$idempotent.valid -and [int]$idempotent.value.snapshot_sequence -eq 2) "re-reading the same events is idempotent"

    $wrongRun = New-TimelineSnapshot 3 @(
        (New-PhaseRow "child_bootstrap" 1000 1010),
        (New-PhaseRow "scene_loaded" 1010)
    ) "$runId-wrong" $repositoryHead
    $wrongRunPath = Write-TimelineEvent $wrongRun
    $wrongRunSync = Sync-ColdRestoreProcessAPhaseTimeline $eventDirectory $timelinePath $runId $repositoryHead
    Assert-TimelineCondition (-not [bool]$wrongRunSync.valid -and [string]$wrongRunSync.reason_code -eq "phase_timeline_run_id_mismatch") "wrong run ID event is rejected"
    Remove-Item -LiteralPath $wrongRunPath -Force

    $wrongHead = New-TimelineSnapshot 3 @(
        (New-PhaseRow "child_bootstrap" 1000 1010),
        (New-PhaseRow "scene_loaded" 1010)
    ) $runId ("c" * 40)
    $wrongHeadPath = Write-TimelineEvent $wrongHead
    $wrongHeadSync = Sync-ColdRestoreProcessAPhaseTimeline $eventDirectory $timelinePath $runId $repositoryHead
    Assert-TimelineCondition (-not [bool]$wrongHeadSync.valid -and [string]$wrongHeadSync.reason_code -eq "phase_timeline_repository_head_mismatch") "wrong HEAD event is rejected"
    Remove-Item -LiteralPath $wrongHeadPath -Force

    $snapshot3 = New-TimelineSnapshot 3 @(
        (New-PhaseRow "child_bootstrap" 1000 1010),
        (New-PhaseRow "scene_loaded" 1010)
    )
    $event3 = Write-TimelineEvent $snapshot3
    $sync3 = Sync-ColdRestoreProcessAPhaseTimeline $eventDirectory $timelinePath $runId $repositoryHead
    Assert-TimelineCondition ([bool]$sync3.valid -and [int]$sync3.value.snapshot_sequence -eq 3) "next ordered phase advances"

    $truncated = New-TimelineSnapshot 4 @((New-PhaseRow "child_bootstrap" 1000 1010))
    $truncatedPath = Write-TimelineEvent $truncated
    $truncatedSync = Sync-ColdRestoreProcessAPhaseTimeline $eventDirectory $timelinePath $runId $repositoryHead
    Assert-TimelineCondition (-not [bool]$truncatedSync.valid -and [string]$truncatedSync.reason_code -eq "phase_timeline_truncated") "truncated timeline event is rejected"
    Remove-Item -LiteralPath $truncatedPath -Force

    $truncatedJsonPath = Join-Path $eventDirectory "000004.snapshot.json"
    [IO.File]::WriteAllText($truncatedJsonPath, '{"schema_version":1', [Text.UTF8Encoding]::new($false))
    $invalidJsonSync = Sync-ColdRestoreProcessAPhaseTimeline $eventDirectory $timelinePath $runId $repositoryHead
    Assert-TimelineCondition (-not [bool]$invalidJsonSync.valid -and [string]$invalidJsonSync.reason_code -eq "phase_timeline_event_json_invalid") "truncated JSON event is rejected without replacing the stable file"
    $stableAfterFault = Get-Content -LiteralPath $timelinePath -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-TimelineCondition ([int]$stableAfterFault.snapshot_sequence -eq 3) "stable timeline remains intact after a truncated event"
    Remove-Item -LiteralPath $truncatedJsonPath -Force

    if ($script:failures.Count -gt 0) {
        foreach ($failure in $script:failures) {
            Write-Error "PROCESS A PHASE TIMELINE FAILURE: $failure"
        }
        exit 1
    }
    Write-Output "PROCESS A PHASE TIMELINE CONTRACT PASS $script:checks checks"
    exit 0
}
finally {
    $resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    $resolvedRoot = [IO.Path]::GetFullPath($root)
    if ($resolvedRoot.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase) -and [IO.Directory]::Exists($resolvedRoot)) {
        Remove-Item -LiteralPath $resolvedRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
