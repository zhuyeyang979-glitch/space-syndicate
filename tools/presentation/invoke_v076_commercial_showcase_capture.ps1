<#
.SYNOPSIS
Captures the Phase 8 commercial presentation fixture through headed Godot.

.DESCRIPTION
Runs the canonical Showcase with the repository's bounded Godot runner, uses
the Win32 client handshake, validates 13 episode directories / 39 PNGs / JSON
hashes, and publishes a runner receipt.  This is presentation-fixture evidence
only and can never claim natural gameplay, production green, or human green.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [Parameter(Mandatory = $true)]
    [string]$GodotPath,

    [Parameter(Mandatory = $true)]
    [string]$EvidenceRoot,

    [ValidatePattern('^1600x960$')]
    [string]$CaptureSize = '1600x960',

    [ValidateRange(60, 1800)]
    [int]$TimeoutSeconds = 600
)

$ErrorActionPreference = 'Stop'
$ProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path.TrimEnd('\', '/')
$GodotPath = (Resolve-Path -LiteralPath $GodotPath).Path
$EvidenceRoot = [IO.Path]::GetFullPath($EvidenceRoot)
$runnerPath = Join-Path $ProjectPath 'tools\invoke_godot_test.ps1'
$headedCapturePath = Join-Path $EvidenceRoot 'showcase_headed_client_final.png'
$probeNonce = [guid]::NewGuid().ToString('N')
$logRoot = Join-Path $env:LOCALAPPDATA "SpaceSyndicate\showcase_capture_runs\$probeNonce"
$isolatedProfileRoot = Join-Path $env:LOCALAPPDATA "SpaceSyndicate\showcase_capture_profiles\$probeNonce"
$completionMarker = 'V076_PHASE8_COMMERCIAL_PRESENTATION_CAPTURE|status=PASS|fixture_class=PRESENTATION_FIXTURE|natural_gameplay=false|human_green=false'
$episodePlanPath = Join-Path $ProjectPath 'data\presentation\v076_commercial_showcase_episode_plan.json'

function Get-PngMetadata {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "PNG is missing: $Path"
    }
    $bytes = [IO.File]::ReadAllBytes($Path)
    $signature = [byte[]](137, 80, 78, 71, 13, 10, 26, 10)
    if ($bytes.Length -lt 24) {
        throw "PNG is too short: $Path"
    }
    for ($index = 0; $index -lt $signature.Length; $index++) {
        if ($bytes[$index] -ne $signature[$index]) {
            throw "PNG signature is invalid: $Path"
        }
    }
    if ([Text.Encoding]::ASCII.GetString($bytes, 12, 4) -ne 'IHDR') {
        throw "PNG first chunk is not IHDR: $Path"
    }
    $width = (
        ([int64]$bytes[16] -shl 24) -bor
        ([int64]$bytes[17] -shl 16) -bor
        ([int64]$bytes[18] -shl 8) -bor
        [int64]$bytes[19]
    )
    $height = (
        ([int64]$bytes[20] -shl 24) -bor
        ([int64]$bytes[21] -shl 16) -bor
        ([int64]$bytes[22] -shl 8) -bor
        [int64]$bytes[23]
    )
    return [ordered]@{
        path = $Path
        width = [int]$width
        height = [int]$height
        byte_length = [int64]$bytes.Length
        sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "JSON is missing: $Path"
    }
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Write-JsonFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][object]$Value
    )
    $parent = Split-Path -Parent $Path
    [IO.Directory]::CreateDirectory($parent) | Out-Null
    $temporaryPath = "$Path.$PID.tmp"
    $json = $Value | ConvertTo-Json -Depth 100
    [IO.File]::WriteAllText(
        $temporaryPath,
        $json + [Environment]::NewLine,
        [Text.UTF8Encoding]::new($false)
    )
    Move-Item -LiteralPath $temporaryPath -Destination $Path -Force
}

if (-not (Test-Path -LiteralPath $runnerPath -PathType Leaf)) {
    throw "Godot runner is missing: $runnerPath"
}
if (-not (Test-Path -LiteralPath $episodePlanPath -PathType Leaf)) {
    throw "Episode plan is missing: $episodePlanPath"
}
[IO.Directory]::CreateDirectory($EvidenceRoot) | Out-Null
[IO.Directory]::CreateDirectory($logRoot) | Out-Null

$headSha = (& git -C $ProjectPath rev-parse HEAD).Trim()
$treeSha = (& git -C $ProjectPath rev-parse 'HEAD^{tree}').Trim()
$dirtyStatus = @(& git -C $ProjectPath status --porcelain=v1)
$preflightStatus = if ($dirtyStatus.Count -gt 0) {
    'PREFLIGHT_GREEN_DIRTY_WORKTREE'
} else {
    'PREFLIGHT_GREEN_CLEAN_WORKTREE'
}

$arguments = @(
    '-NoProfile',
    '-File', $runnerPath,
    '-ProjectPath', $ProjectPath,
    '-GodotPath', $GodotPath,
    '-TestScript', 'res://tests/showcase_frame_capture.gd',
    '-HeadedClientProbe',
    '-ExpectedClientSize', $CaptureSize,
    '-ExpectedCompletionMarker', $completionMarker,
    '-TimeoutSeconds', $TimeoutSeconds,
    '-WindowProbeTimeoutSeconds', 60,
    '-LogRoot', $logRoot,
    '-IsolatedUserDataRoot', $isolatedProfileRoot,
    '-TestArgumentJson', (
        @(
            "--evidence-root=$EvidenceRoot",
            "--headed-capture-output=$headedCapturePath",
            "--window-probe-nonce=$probeNonce"
        ) | ConvertTo-Json -Compress
    )
)

& pwsh @arguments
$runnerExitCode = $LASTEXITCODE
$resultPath = Get-ChildItem -LiteralPath $logRoot -Filter result.json -File -Recurse |
    Sort-Object LastWriteTimeUtc -Descending |
    Select-Object -First 1 -ExpandProperty FullName
if ([string]::IsNullOrWhiteSpace($resultPath)) {
    throw 'Godot runner did not publish result.json'
}
$runnerResult = Read-JsonFile -Path $resultPath
if (
    $runnerExitCode -ne 0 -or
    [string]$runnerResult.status -ne 'passed' -or
    [int]$runnerResult.runner_exit_code -ne 0 -or
    [int]$runnerResult.process_exit_code -ne 0 -or
    [bool]$runnerResult.timed_out -or
    -not [bool]$runnerResult.marker_found -or
    [int]$runnerResult.script_error_count -ne 0 -or
    [int]$runnerResult.diagnostic_count -ne 0 -or
    [int]$runnerResult.task_introduced_error_count -ne 0 -or
    [int]$runnerResult.unclassified_diagnostic_count -ne 0 -or
    @($runnerResult.cleanup_process_ids).Count -ne 0 -or
    @($runnerResult.remaining_project_runtime_process_ids).Count -ne 0 -or
    -not [bool]$runnerResult.stdout_capture.strict_decode -or
    -not [bool]$runnerResult.stderr_capture.strict_decode -or
    -not [bool]$runnerResult.window_probe.exact_match
) {
    throw "Headed capture runner failed: $resultPath"
}

# Preserve the successful bounded-run receipt inside the milestone evidence.
# Only the explicit runner logs and Win32 handshake documents are archived;
# isolated user data, shader caches, and Vulkan caches are deliberately excluded.
$runnerArchiveRoot = Join-Path $EvidenceRoot ("runner\" + [string]$runnerResult.run_id)
[IO.Directory]::CreateDirectory($runnerArchiveRoot) | Out-Null
$runnerArchiveRows = [Collections.Generic.List[object]]::new()
$runnerArchiveSources = @(
    [pscustomobject]@{ name = 'result.json'; path = $resultPath },
    [pscustomobject]@{ name = 'stdout.log'; path = [string]$runnerResult.stdout_log },
    [pscustomobject]@{ name = 'stderr.log'; path = [string]$runnerResult.stderr_log },
    [pscustomobject]@{ name = 'godot.log'; path = [string]$runnerResult.godot_log },
    [pscustomobject]@{ name = 'stdout.raw.bin'; path = [string]$runnerResult.stdout_raw_log },
    [pscustomobject]@{ name = 'stderr.raw.bin'; path = [string]$runnerResult.stderr_raw_log },
    [pscustomobject]@{ name = 'window-ready.json'; path = [string]$runnerResult.window_probe.ready_path },
    [pscustomobject]@{ name = 'window-ack.json'; path = [string]$runnerResult.window_probe.ack_path }
)
foreach ($source in $runnerArchiveSources) {
    if ([string]::IsNullOrWhiteSpace([string]$source.path) -or -not (Test-Path -LiteralPath ([string]$source.path) -PathType Leaf)) {
        throw "Successful runner archive source is missing: $($source.name)"
    }
    $destination = Join-Path $runnerArchiveRoot ([string]$source.name)
    Copy-Item -LiteralPath ([string]$source.path) -Destination $destination -Force
    $runnerArchiveRows.Add([pscustomobject][ordered]@{
        name = [string]$source.name
        path = $destination
        byte_length = [int64](Get-Item -LiteralPath $destination).Length
        sha256 = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
    })
}

$plan = Read-JsonFile -Path $episodePlanPath
if (
    [int]$plan.schema_version -ne 1 -or
    [string]$plan.contract_id -ne 'space_syndicate.v076.commercial_showcase_episode_plan.v1'
) {
    throw 'Episode plan schema is invalid'
}
$episodes = @($plan.episodes)
if ($episodes.Count -ne 13) {
    throw "Expected 13 episodes, found $($episodes.Count)"
}
$pngRows = [Collections.Generic.List[object]]::new()
$evidenceRows = [Collections.Generic.List[object]]::new()
foreach ($episode in $episodes) {
    $episodeDirectory = Join-Path $EvidenceRoot ([string]$episode.capture_directory)
    foreach ($phase in @('start', 'mid', 'end')) {
        $png = Get-PngMetadata -Path (Join-Path $episodeDirectory "$phase.png")
        if ($png.width -ne 1600 -or $png.height -ne 960 -or $png.byte_length -le 0) {
            throw "Invalid capture PNG for $($episode.episode_id)/$phase"
        }
        $pngRows.Add([pscustomobject]$png)
    }
    $evidencePath = Join-Path $episodeDirectory 'evidence.json'
    $evidence = Read-JsonFile -Path $evidencePath
    if (
        [string]$evidence.status -ne 'PASS' -or
        [string]$evidence.episode_id -ne [string]$episode.episode_id -or
        [string]$evidence.fixture_class -ne 'PRESENTATION_FIXTURE' -or
        [bool]$evidence.natural_gameplay -or
        [bool]$evidence.human_green -or
        [string]$evidence.actual_cue_id -ne [string]$episode.expected_cue_id -or
        @($evidence.frames).Count -ne 3 -or
        -not [bool]$evidence.replay.suppressed -or
        -not [bool]$evidence.finished
    ) {
        throw "Episode evidence is invalid: $evidencePath"
    }
    $evidenceRows.Add([pscustomobject][ordered]@{
        episode_id = [string]$episode.episode_id
        path = $evidencePath
        sha256 = (Get-FileHash -LiteralPath $evidencePath -Algorithm SHA256).Hash.ToLowerInvariant()
    })
}
if ($pngRows.Count -ne 39) {
    throw "Expected 39 PNGs, found $($pngRows.Count)"
}

$manifest = Read-JsonFile -Path (Join-Path $EvidenceRoot 'showcase_capture_manifest.json')
$performance = Read-JsonFile -Path (Join-Path $EvidenceRoot 'performance_report.json')
$exactOnce = Read-JsonFile -Path (Join-Path $EvidenceRoot 'animation_exact_once_report.json')
$headedPng = Get-PngMetadata -Path $headedCapturePath
if (
    [string]$manifest.status -ne 'AUTOMATION_GREEN_PENDING_VISUAL_REVIEW' -or
    [string]$manifest.fixture_class -ne 'PRESENTATION_FIXTURE' -or
    [bool]$manifest.natural_gameplay -or
    [bool]$manifest.human_green -or
    [int]$manifest.episode_count -ne 13 -or
    [int]$manifest.frame_count -ne 39 -or
    [string]$performance.status -ne 'AUTOMATION_GREEN_PENDING_VISUAL_REVIEW' -or
    [string]$performance.fixture_class -ne 'PRESENTATION_FIXTURE' -or
    [string]$exactOnce.status -ne 'PASS' -or
    [int]$exactOnce.episode_count -ne 13 -or
    $headedPng.width -ne 1600 -or
    $headedPng.height -ne 960
) {
    throw 'Commercial showcase aggregate evidence is invalid'
}

$receiptPath = Join-Path $EvidenceRoot 'capture_runner_report.json'
$receipt = [ordered]@{
    schema = 'V076CommercialPresentationCaptureRunnerReportV1'
    status = 'AUTOMATION_GREEN_PENDING_VISUAL_REVIEW'
    preflight_status = $preflightStatus
    fixture_class = 'PRESENTATION_FIXTURE'
    natural_gameplay = $false
    gameplay_green = $false
    human_green = $false
    production_green = $false
    human_retest_deferred = $true
    step13_status = 'PENDING'
    captured_at_utc = [DateTime]::UtcNow.ToString('o')
    head_sha = $headSha
    head_tree_sha = $treeSha
    dirty_worktree_preserved = ($dirtyStatus.Count -gt 0)
    runner_result_path = (Join-Path $runnerArchiveRoot 'result.json')
    runner_result_sha256 = (Get-FileHash -LiteralPath (Join-Path $runnerArchiveRoot 'result.json') -Algorithm SHA256).Hash.ToLowerInvariant()
    runner_archive_path = $runnerArchiveRoot
    runner_archive_excludes_isolated_user_data = $true
    runner_archive_files = @($runnerArchiveRows)
    headed_client_capture = $headedPng
    episode_count = $episodes.Count
    frame_count = $pngRows.Count
    frames = @($pngRows)
    episode_evidence = @($evidenceRows)
    remaining_project_runtime_process_ids = @($runnerResult.remaining_project_runtime_process_ids)
}
Write-JsonFile -Path $receiptPath -Value $receipt
Write-Output (
    'V076_COMMERCIAL_SHOWCASE_CAPTURE_WRAPPER|status=PASS' +
    '|fixture_class=PRESENTATION_FIXTURE|natural_gameplay=false' +
    '|human_green=false|episodes=13|frames=39' +
    "|runner_result=$resultPath|receipt=$receiptPath"
)
