<#
.SYNOPSIS
Captures the three fixed V0.7.5 desktop viewport cases through headed Godot.

.DESCRIPTION
Each case uses a fresh Godot process and isolated user profile. The underlying
runner binds the test driver to a visible Win32 client rect by PID/HWND, while
this orchestrator independently validates the driver receipt, PNG signature,
IHDR dimensions, and file hash. Automatic success remains pending human visual
review; the typed presentation fixture is not gameplay acceptance evidence.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [Parameter(Mandatory = $true)]
    [string]$GodotPath,

    [Parameter(Mandatory = $true)]
    [string]$EvidenceRoot,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{40}$')]
    [string]$SourceSha,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{40}$')]
    [string]$TreeSha,

    [ValidateRange(30, 300)]
    [int]$TimeoutSeconds = 120,

    [switch]$AllowDirtyPreflight
)

$ErrorActionPreference = "Stop"
$ProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path.TrimEnd('\', '/')
$GodotPath = (Resolve-Path -LiteralPath $GodotPath).Path
$EvidenceRoot = [IO.Path]::GetFullPath($EvidenceRoot)
$projectPrefix = $ProjectPath + [IO.Path]::DirectorySeparatorChar
if (
    $EvidenceRoot.Equals($ProjectPath, [StringComparison]::OrdinalIgnoreCase) -or
    $EvidenceRoot.StartsWith($projectPrefix, [StringComparison]::OrdinalIgnoreCase)
) {
    throw "EvidenceRoot must be outside the project worktree: $EvidenceRoot"
}
$runnerPath = Join-Path $ProjectPath "tools\invoke_godot_test.ps1"
$driverPath = "res://tests/v075_responsive_viewport_headed_capture.gd"
$mirrorRoot = Join-Path $ProjectPath ".codex-godot\mcp-validation\headed-responsive"
$cases = @(
    [ordered]@{ label = "1366x768"; width = 1366; height = 768 },
    [ordered]@{ label = "1600x960"; width = 1600; height = 960 },
    [ordered]@{ label = "1920x1080"; width = 1920; height = 1080 }
)

function Invoke-GitText {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $output = & git -C $ProjectPath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "git failed: $($Arguments -join ' ')"
    }
    return (($output | Out-String).Trim())
}

function Get-PngIhdr {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "PNG does not exist: $Path"
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
    $chunkType = [Text.Encoding]::ASCII.GetString($bytes, 12, 4)
    if ($chunkType -ne "IHDR") {
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
    return [pscustomobject][ordered]@{
        width = [int]$width
        height = [int]$height
        byte_length = [int64]$bytes.Length
        sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

function Test-SizeObject {
    param(
        [Parameter(Mandatory = $true)][object]$Size,
        [Parameter(Mandatory = $true)][int]$Width,
        [Parameter(Mandatory = $true)][int]$Height
    )
    return $null -ne $Size -and [int]$Size.width -eq $Width -and [int]$Size.height -eq $Height
}

function Test-HeadedCaseEvidence {
    param(
        [Parameter(Mandatory = $true)][object]$Case,
        [Parameter(Mandatory = $true)][int]$RunnerExitCode,
        [object]$RunnerResult,
        [object]$Receipt,
        [object]$Png,
        [Parameter(Mandatory = $true)][string]$ExpectedPngPath,
        [Parameter(Mandatory = $true)][string]$ExpectedSourceSha,
        [Parameter(Mandatory = $true)][string]$ExpectedTreeSha,
        [Parameter(Mandatory = $true)][string]$ExpectedNonce
    )
    return (
        $RunnerExitCode -eq 0 -and
        $null -ne $RunnerResult -and
        [string]$RunnerResult.status -eq "passed" -and
        [bool]$RunnerResult.window_probe.exact_match -and
        [int]$RunnerResult.window_probe.stable_exact_sample_count -ge 3 -and
        [int]$RunnerResult.window_probe.client_capture.width -eq [int]$Case.width -and
        [int]$RunnerResult.window_probe.client_capture.height -eq [int]$Case.height -and
        [int]$RunnerResult.window_probe.client_capture.pre_capture_client_width -eq [int]$Case.width -and
        [int]$RunnerResult.window_probe.client_capture.pre_capture_client_height -eq [int]$Case.height -and
        [int]$RunnerResult.window_probe.client_capture.post_capture_client_width -eq [int]$Case.width -and
        [int]$RunnerResult.window_probe.client_capture.post_capture_client_height -eq [int]$Case.height -and
        [int]$RunnerResult.window_probe.client_capture.post_capture_exact_sample_count -eq 3 -and
        $null -ne $Receipt -and
        [string]$Receipt.status -eq "PASS" -and
        [string]$Receipt.expected_head_sha -eq $ExpectedSourceSha -and
        [string]$Receipt.expected_tree_sha -eq $ExpectedTreeSha -and
        [string]$Receipt.probe_nonce -eq $ExpectedNonce -and
        [string]$RunnerResult.window_probe.probe_nonce -eq $ExpectedNonce -and
        [string]$Receipt.ack_payload.probe_nonce -eq $ExpectedNonce -and
        [string]$Receipt.ready_sha256 -eq [string]$RunnerResult.window_probe.ready_sha256 -and
        [string]$Receipt.ready_sha256 -eq [string]$Receipt.ack_payload.ready_sha256 -and
        [int]$Receipt.godot_pid -eq [int]$RunnerResult.process_id -and
        [int]$Receipt.godot_pid -eq [int]$RunnerResult.window_probe.process_id -and
        [int]$Receipt.godot_pid -eq [int]$Receipt.ack_payload.process_id -and
        [int64]([string]$Receipt.native_hwnd_decimal) -ne 0 -and
        [string]$Receipt.native_hwnd_decimal -eq [string]$RunnerResult.window_probe.hwnd_decimal -and
        [string]$Receipt.native_hwnd_decimal -eq [string]$Receipt.ack_payload.hwnd_decimal -and
        [string]$Receipt.ready_path -eq [string]$RunnerResult.window_probe.ready_path -and
        [string]$Receipt.ack_path -eq [string]$RunnerResult.window_probe.ack_path -and
        [string]$Receipt.png_path -ieq $ExpectedPngPath -and
        [string]$RunnerResult.window_probe.client_capture.path -ieq $ExpectedPngPath -and
        [string]$Receipt.ack_payload.client_capture_path -ieq $ExpectedPngPath -and
        [string]$Receipt.staging_mode -eq "typed_test_projection" -and
        -not [bool]$Receipt.natural_runtime_state -and
        -not [bool]$Receipt.gameplay_acceptance -and
        (Test-SizeObject -Size $Receipt.requested_client_size -Width $Case.width -Height $Case.height) -and
        [string]$Receipt.actual_runtime_viewport_kind -eq "main_window_client" -and
        [string]$Receipt.actual_runtime_viewport_api -eq "SceneTree.root.size(Window.size)" -and
        (Test-SizeObject -Size $Receipt.actual_runtime_viewport_size -Width $Case.width -Height $Case.height) -and
        (Test-SizeObject -Size $Receipt.runtime_viewport_size -Width $Case.width -Height $Case.height) -and
        (Test-SizeObject -Size $Receipt.root_window_size -Width $Case.width -Height $Case.height) -and
        (Test-SizeObject -Size $Receipt.display_server_window_size -Width $Case.width -Height $Case.height) -and
        (Test-SizeObject -Size $Receipt.post_capture_runtime_viewport_size -Width $Case.width -Height $Case.height) -and
        (Test-SizeObject -Size $Receipt.post_capture_display_server_window_size -Width $Case.width -Height $Case.height) -and
        (Test-SizeObject -Size $Receipt.captured_image_size -Width $Case.width -Height $Case.height) -and
        $null -ne $Png -and
        [int]$Png.width -eq [int]$Case.width -and
        [int]$Png.height -eq [int]$Case.height -and
        [string]$Png.sha256 -eq [string]$Receipt.png_sha256 -and
        [string]$Png.sha256 -eq [string]$RunnerResult.window_probe.client_capture.sha256 -and
        [string]$Png.sha256 -eq [string]$Receipt.ack_payload.client_capture_sha256 -and
        [int64]$Png.byte_length -eq [int64]$Receipt.png_bytes -and
        [int64]$Png.byte_length -eq [int64]$Receipt.ack_payload.client_capture_bytes -and
        [bool]$Receipt.population_green -and
        [int]$Receipt.rival_private_card_identity_leak_count -eq 0 -and
        [int]$Receipt.military_presentation_binding_failure_count -eq 0 -and
        [bool]$Receipt.military_option_identity_green -and
        [bool]$Receipt.military_presentation_green -and
        [int]$Receipt.military_selection_fixture_count -eq 2 -and
        (@($Receipt.military_option_ids | Sort-Object -Unique).Count -eq 2)
    )
}

if (-not (Test-Path -LiteralPath $runnerPath -PathType Leaf)) {
    throw "Godot runner is missing: $runnerPath"
}
[IO.Directory]::CreateDirectory($EvidenceRoot) | Out-Null
[IO.Directory]::CreateDirectory($mirrorRoot) | Out-Null
$headBefore = Invoke-GitText -Arguments @("rev-parse", "HEAD")
$treeBefore = Invoke-GitText -Arguments @("show", "-s", "--format=%T", "HEAD")
$statusBefore = Invoke-GitText -Arguments @("status", "--porcelain=v1", "--untracked-files=all")
$identityMatches = (
    $headBefore -eq $SourceSha.ToLowerInvariant() -and
    $treeBefore -eq $TreeSha.ToLowerInvariant()
)
if (-not $identityMatches) {
    throw "Requested HEAD/tree does not match the current worktree."
}
if (-not [string]::IsNullOrEmpty($statusBefore) -and -not $AllowDirtyPreflight) {
    throw "Exact-SHA viewport capture requires a clean worktree."
}
$exactShaEvidence = [string]::IsNullOrEmpty($statusBefore)

$caseRecords = [Collections.Generic.List[object]]::new()
$failures = [Collections.Generic.List[string]]::new()
foreach ($case in $cases) {
    $caseRoot = Join-Path $EvidenceRoot ([string]$case.label)
    $logRoot = Join-Path $caseRoot "runner"
    $profileRoot = Join-Path $caseRoot "isolated-profile"
    [IO.Directory]::CreateDirectory($caseRoot) | Out-Null
    $pngPath = Join-Path $caseRoot ("v075-{0}.png" -f $case.label)
    $receiptPath = Join-Path $caseRoot "capture-receipt.json"
    $nonce = [guid]::NewGuid().ToString("N")
    $testArguments = @(
        "--case-label=$($case.label)",
        "--capture-output=$pngPath",
        "--capture-receipt=$receiptPath",
        "--expected-head-sha=$SourceSha",
        "--expected-tree-sha=$TreeSha",
        "--window-probe-nonce=$nonce"
    )
    $testArgumentJson = ConvertTo-Json -InputObject $testArguments -Compress
    $marker = "V075_RESPONSIVE_VIEWPORT_HEADED_CAPTURE|status=PASS|case=$($case.label)"
    $runnerOutput = & pwsh -NoLogo -NoProfile -File $runnerPath `
        -ProjectPath $ProjectPath `
        -GodotPath $GodotPath `
        -TestScript $driverPath `
        -HeadedClientProbe `
        -ExpectedClientSize ([string]$case.label) `
        -WindowProbeTimeoutSeconds 30 `
        -TestArgumentJson $testArgumentJson `
        -ExpectedCompletionMarker $marker `
        -LogRoot $logRoot `
        -IsolatedUserDataRoot $profileRoot `
        -TimeoutSeconds $TimeoutSeconds 2>&1
    $runnerExitCode = $LASTEXITCODE
    $runnerText = ($runnerOutput | Out-String).Trim()
    $runnerJsonLine = @(
        $runnerText -split "`r?`n" |
        Where-Object { $_.TrimStart().StartsWith("{") }
    ) | Select-Object -Last 1
    $runnerResult = $null
    if (-not [string]::IsNullOrWhiteSpace($runnerJsonLine)) {
        try {
            $runnerResult = ConvertFrom-Json -InputObject $runnerJsonLine
        } catch {
            $failures.Add("$($case.label): runner result JSON is invalid")
        }
    } else {
        $failures.Add("$($case.label): runner result JSON is missing")
    }
    $receipt = $null
    if (Test-Path -LiteralPath $receiptPath -PathType Leaf) {
        try {
            $receipt = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($receiptPath))
        } catch {
            $failures.Add("$($case.label): capture receipt JSON is invalid")
        }
    } else {
        $failures.Add("$($case.label): capture receipt is missing")
    }
    $png = $null
    try {
        $png = Get-PngIhdr -Path $pngPath
    } catch {
        $failures.Add("$($case.label): $($_.Exception.Message)")
    }
    $mirrorPath = Join-Path $mirrorRoot ("v075-{0}.png" -f $case.label)
    $mirrorResPath = "res://.codex-godot/mcp-validation/headed-responsive/v075-$($case.label).png"
    if ($null -ne $png) {
        Copy-Item -LiteralPath $pngPath -Destination $mirrorPath -Force
        $mirrorHash = (Get-FileHash -LiteralPath $mirrorPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($mirrorHash -ne [string]$png.sha256) {
            $failures.Add("$($case.label): ignored probe mirror hash differs from external authority")
        }
    }

    $caseGreen = Test-HeadedCaseEvidence `
        -Case $case `
        -RunnerExitCode $runnerExitCode `
        -RunnerResult $runnerResult `
        -Receipt $receipt `
        -Png $png `
        -ExpectedPngPath $pngPath `
        -ExpectedSourceSha $SourceSha `
        -ExpectedTreeSha $TreeSha `
        -ExpectedNonce $nonce
    $negativeControlsGreen = $false
    if ($caseGreen) {
        $wrongPng = ConvertFrom-Json -InputObject (
            $png | ConvertTo-Json -Depth 30 -Compress
        )
        $wrongPng.width = [int]$wrongPng.width + 1
        $wrongReadyReceipt = ConvertFrom-Json -InputObject (
            $receipt | ConvertTo-Json -Depth 30 -Compress
        )
        $wrongReadyReceipt.ready_sha256 = "0" * 64
        $wrongSizeReceipt = ConvertFrom-Json -InputObject (
            $receipt | ConvertTo-Json -Depth 30 -Compress
        )
        $wrongSizeReceipt.actual_runtime_viewport_size.width = (
            [int]$wrongSizeReceipt.actual_runtime_viewport_size.width + 1
        )
        $wrongNonceReceipt = ConvertFrom-Json -InputObject (
            $receipt | ConvertTo-Json -Depth 30 -Compress
        )
        $wrongNonceReceipt.probe_nonce = "forged"
        $negativeControlsGreen = (
            -not (Test-HeadedCaseEvidence -Case $case -RunnerExitCode $runnerExitCode -RunnerResult $runnerResult -Receipt $receipt -Png $wrongPng -ExpectedPngPath $pngPath -ExpectedSourceSha $SourceSha -ExpectedTreeSha $TreeSha -ExpectedNonce $nonce) -and
            -not (Test-HeadedCaseEvidence -Case $case -RunnerExitCode $runnerExitCode -RunnerResult $runnerResult -Receipt $wrongReadyReceipt -Png $png -ExpectedPngPath $pngPath -ExpectedSourceSha $SourceSha -ExpectedTreeSha $TreeSha -ExpectedNonce $nonce) -and
            -not (Test-HeadedCaseEvidence -Case $case -RunnerExitCode $runnerExitCode -RunnerResult $runnerResult -Receipt $wrongSizeReceipt -Png $png -ExpectedPngPath $pngPath -ExpectedSourceSha $SourceSha -ExpectedTreeSha $TreeSha -ExpectedNonce $nonce) -and
            -not (Test-HeadedCaseEvidence -Case $case -RunnerExitCode $runnerExitCode -RunnerResult $runnerResult -Receipt $wrongNonceReceipt -Png $png -ExpectedPngPath $pngPath -ExpectedSourceSha $SourceSha -ExpectedTreeSha $TreeSha -ExpectedNonce $nonce)
        )
    }
    $caseGreen = $caseGreen -and $negativeControlsGreen
    if (-not $caseGreen) {
        $failures.Add("$($case.label): headed dimension/presentation evidence did not pass all gates")
    }
    $caseRecords.Add([pscustomobject][ordered]@{
        label = [string]$case.label
        requested_width = [int]$case.width
        requested_height = [int]$case.height
        green = $caseGreen
        negative_control_count = 4
        negative_controls_green = $negativeControlsGreen
        runner_exit_code = $runnerExitCode
        runner_result_json = if ($null -ne $runnerResult) { [string]$runnerResult.result_json } else { "" }
        runner_window_probe = if ($null -ne $runnerResult) { $runnerResult.window_probe } else { $null }
        receipt_path = $receiptPath
        receipt = $receipt
        png = $png
        ignored_probe_mirror_path = $mirrorPath
        ignored_probe_mirror_res_path = $mirrorResPath
    })
}

$headAfter = Invoke-GitText -Arguments @("rev-parse", "HEAD")
$treeAfter = Invoke-GitText -Arguments @("show", "-s", "--format=%T", "HEAD")
$statusAfter = Invoke-GitText -Arguments @("status", "--porcelain=v1", "--untracked-files=all")
$pngHashes = @($caseRecords | ForEach-Object { if ($null -ne $_.png) { [string]$_.png.sha256 } })
$distinctPngHashes = @($pngHashes | Sort-Object -Unique).Count
$identityStable = (
    $headAfter -eq $headBefore -and
    $treeAfter -eq $treeBefore -and
    $statusAfter -eq $statusBefore
)
$allGreen = (
    $failures.Count -eq 0 -and
    @($caseRecords | Where-Object { -not $_.green }).Count -eq 0 -and
    $caseRecords.Count -eq 3 -and
    $distinctPngHashes -eq 3 -and
    $identityStable
)
if ($distinctPngHashes -ne 3) {
    $failures.Add("the three PNG SHA-256 values are not distinct")
}
if (-not $identityStable) {
    $failures.Add("worktree identity changed during viewport capture")
}
$status = if (-not $allGreen) {
    "BLOCKED"
} elseif ($exactShaEvidence) {
    "AUTOMATION_GREEN_PENDING_VISUAL_REVIEW"
} else {
    "PREFLIGHT_GREEN_DIRTY_WORKTREE"
}
$aggregate = [ordered]@{
    schema = "space_syndicate.v075.headed_responsive_capture_aggregate.v1"
    status = $status
    exact_sha_evidence = $exactShaEvidence
    visual_review_complete = $false
    source_sha = $SourceSha.ToLowerInvariant()
    tree_sha = $TreeSha.ToLowerInvariant()
    head_before = $headBefore
    tree_before = $treeBefore
    head_after = $headAfter
    tree_after = $treeAfter
    worktree_status_before = $statusBefore
    worktree_status_after = $statusAfter
    worktree_identity_stable = $identityStable
    case_count = $caseRecords.Count
    green_case_count = @($caseRecords | Where-Object { $_.green }).Count
    distinct_png_sha256_count = $distinctPngHashes
    failures = @($failures)
    cases = @($caseRecords)
}
$aggregatePath = Join-Path $EvidenceRoot "headed-responsive-capture-aggregate.json"
[IO.File]::WriteAllText(
    $aggregatePath,
    ($aggregate | ConvertTo-Json -Depth 14),
    [Text.UTF8Encoding]::new($false)
)
[pscustomobject]$aggregate | ConvertTo-Json -Depth 14 -Compress | Write-Output
exit $(if ($allGreen) { 0 } else { 1 })
