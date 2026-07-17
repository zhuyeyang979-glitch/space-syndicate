<#
.SYNOPSIS
Proves the generic Godot runner reports script-error / missing-marker / pass.

.DESCRIPTION
Copies three repository fixtures into one temporary minimal Godot project, runs
each through invoke_godot_test.ps1, verifies fail/fail/pass semantics and stable
summary fields, and confirms the player's default save fingerprints are
unchanged. Evidence logs remain outside the repository; the temporary project is
removed after the check unless -KeepFixture is supplied.
#>
[CmdletBinding()]
param(
    [string]$RunnerPath = (Join-Path $PSScriptRoot "invoke_godot_test.ps1"),

    [string]$GodotPath = "C:\Users\Administrator\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe",

    [string]$EvidenceRoot = (Join-Path $env:LOCALAPPDATA ("SpaceSyndicate\runner_failure_detection\{0}-{1}" -f [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss-fff"), ([guid]::NewGuid().ToString("N").Substring(0, 8)))),

    [string]$PlayerDataRoot = (Join-Path $env:APPDATA "Godot\app_userdata\太空辛迪加"),

    [switch]$KeepFixture
)

$ErrorActionPreference = "Stop"
$completionMarker = "GODOT_TEST_RUNNER_FIXTURE_COMPLETE"

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

function Get-SaveFingerprint {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root
    )

    $records = [Collections.Generic.List[object]]::new()
    foreach ($name in @("campaign_progress.save", "space_syndicate_current_run.save")) {
        $path = Join-Path $Root $name
        $item = Get-Item -LiteralPath $path -ErrorAction SilentlyContinue
        $records.Add([pscustomobject][ordered]@{
            path = [IO.Path]::GetFullPath($path)
            present = $null -ne $item
            size = if ($null -ne $item) { [int64]$item.Length } else { [int64]0 }
            mtime_utc = if ($null -ne $item) { $item.LastWriteTimeUtc.ToString("o") } else { $null }
            sha256 = if ($null -ne $item) { (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash } else { $null }
        })
    }
    return @($records)
}

function Invoke-RunnerFixture {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$TestScript,
        [Parameter(Mandatory = $true)]
        [string]$ProjectPath
    )

    $arguments = @(
        "-NoProfile",
        "-File", $RunnerPath,
        "-TestScript", $TestScript,
        "-ProjectPath", $ProjectPath,
        "-GodotPath", $GodotPath,
        "-LogRoot", (Join-Path $EvidenceRoot "godot-runs"),
        "-ExpectedCompletionMarker", $completionMarker,
        "-TimeoutSeconds", "30"
    )
    $output = @(& (Get-Command pwsh -ErrorAction Stop).Source @arguments 2>&1 | ForEach-Object { $_.ToString() })
    $exitCode = $LASTEXITCODE
    $jsonLine = @(
        $output |
            Where-Object { $_.TrimStart().StartsWith("{") -and $_.TrimEnd().EndsWith("}") } |
            Select-Object -Last 1
    )
    if ($jsonLine.Count -ne 1) {
        throw "$Name did not emit one JSON summary. exit=$exitCode output=$($output -join [Environment]::NewLine)"
    }
    return [pscustomobject][ordered]@{
        name = $Name
        exit_code = $exitCode
        result = ($jsonLine[0] | ConvertFrom-Json -Depth 20)
    }
}

function Remove-VerifiedFixture {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$AllowedRoot
    )

    $fullPath = [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
    $fullRoot = [IO.Path]::GetFullPath($AllowedRoot).TrimEnd('\', '/')
    if (-not $fullPath.StartsWith($fullRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove fixture outside verified root: $fullPath"
    }
    if (Test-Path -LiteralPath $fullPath) {
        Remove-Item -LiteralPath $fullPath -Recurse -Force
    }
}

$RunnerPath = (Resolve-Path -LiteralPath $RunnerPath).Path
$GodotPath = (Resolve-Path -LiteralPath $GodotPath).Path
$EvidenceRoot = [IO.Path]::GetFullPath($EvidenceRoot)
$sourceFixtureRoot = Join-Path (Split-Path -Parent $PSScriptRoot) "tests\fixtures\godot_test_runner"
$fixtureParent = Join-Path ([IO.Path]::GetTempPath()) "SpaceSyndicate Godot Runner Fixtures"
$fixtureRoot = Join-Path $fixtureParent ([guid]::NewGuid().ToString("N"))
$fixtureTestRoot = Join-Path $fixtureRoot "tests\fixtures\godot_test_runner"
$summaryPath = Join-Path $EvidenceRoot "summary.json"
$playerStateBefore = Get-SaveFingerprint -Root $PlayerDataRoot

New-Item -ItemType Directory -Force -Path $fixtureTestRoot | Out-Null
New-Item -ItemType Directory -Force -Path $EvidenceRoot | Out-Null
@"
config_version=5

[application]

config/name="Godot Test Runner Failure Detection Fixture"
config/use_custom_user_dir=true
config/custom_user_dir_name="GodotTestRunnerFailureDetection"

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
"@ | Set-Content -LiteralPath (Join-Path $fixtureRoot "project.godot") -Encoding utf8
foreach ($name in @("script_error_exit_zero.gd", "missing_marker.gd", "normal_with_marker.gd")) {
    Copy-Item -LiteralPath (Join-Path $sourceFixtureRoot $name) -Destination (Join-Path $fixtureTestRoot $name)
}

try {
    $scriptError = Invoke-RunnerFixture `
        -Name "script_error_exit_zero" `
        -TestScript "res://tests/fixtures/godot_test_runner/script_error_exit_zero.gd" `
        -ProjectPath $fixtureRoot
    $missingMarker = Invoke-RunnerFixture `
        -Name "missing_marker" `
        -TestScript "res://tests/fixtures/godot_test_runner/missing_marker.gd" `
        -ProjectPath $fixtureRoot
    $normal = Invoke-RunnerFixture `
        -Name "normal_with_marker" `
        -TestScript "res://tests/fixtures/godot_test_runner/normal_with_marker.gd" `
        -ProjectPath $fixtureRoot

    Assert-Condition ($scriptError.exit_code -eq 127) "Script-error fixture did not return runner exit 127."
    Assert-Condition ($scriptError.result.status -eq "script_error") "Script-error fixture did not report status=script_error."
    Assert-Condition ($scriptError.result.process_exit_code -eq 0) "Script-error fixture did not prove Godot itself exited zero."
    Assert-Condition ($scriptError.result.script_error_count -gt 0) "Script-error fixture reported no script errors."
    Assert-Condition ($scriptError.result.marker_found -eq $true) "Script-error fixture did not reach its deferred completion marker."

    Assert-Condition ($missingMarker.exit_code -eq 128) "Missing-marker fixture did not return runner exit 128."
    Assert-Condition ($missingMarker.result.status -eq "marker_missing") "Missing-marker fixture did not report status=marker_missing."
    Assert-Condition ($missingMarker.result.process_exit_code -eq 0) "Missing-marker fixture did not preserve the Godot zero exit."
    Assert-Condition ($missingMarker.result.script_error_count -eq 0) "Missing-marker fixture unexpectedly reported a script error."
    Assert-Condition ($missingMarker.result.marker_found -eq $false) "Missing-marker fixture falsely found the marker."

    Assert-Condition ($normal.exit_code -eq 0) "Normal fixture did not pass."
    Assert-Condition ($normal.result.status -eq "passed") "Normal fixture did not report status=passed."
    Assert-Condition ($normal.result.script_error_count -eq 0) "Normal fixture reported a script error."
    Assert-Condition ($normal.result.marker_found -eq $true) "Normal fixture did not find the completion marker."

    foreach ($case in @($scriptError, $missingMarker, $normal)) {
        foreach ($field in @("status", "exit_code", "timed_out", "script_error_count", "marker_found", "duration")) {
            Assert-Condition ($null -ne $case.result.PSObject.Properties[$field]) "$($case.name) omitted stable summary field '$field'."
        }
        Assert-Condition (-not $case.result.timed_out) "$($case.name) timed out."
        Assert-Condition (@($case.result.remaining_project_runtime_process_ids).Count -eq 0) "$($case.name) left a scoped Godot process."
        Assert-Condition ($case.result.appdata.StartsWith($case.result.isolated_user_data_root, [StringComparison]::OrdinalIgnoreCase)) "$($case.name) APPDATA is not isolated."
        Assert-Condition ($case.result.localappdata.StartsWith($case.result.isolated_user_data_root, [StringComparison]::OrdinalIgnoreCase)) "$($case.name) LOCALAPPDATA is not isolated."
    }

    $playerStateAfter = Get-SaveFingerprint -Root $PlayerDataRoot
    $playerStateUnchanged = (ConvertTo-Json $playerStateBefore -Depth 5 -Compress) -ceq
        (ConvertTo-Json $playerStateAfter -Depth 5 -Compress)
    Assert-Condition $playerStateUnchanged "Default player save fingerprints changed during runner self-test."

    $summary = [ordered]@{
        status = "passed"
        fixture_root = $fixtureRoot
        evidence_root = $EvidenceRoot
        player_state_unchanged = $playerStateUnchanged
        player_state_before = $playerStateBefore
        player_state_after = $playerStateAfter
        cases = @($scriptError, $missingMarker, $normal)
    }
    $summary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $summaryPath -Encoding utf8
    $summary["summary_json"] = $summaryPath
    $summary | ConvertTo-Json -Depth 5 -Compress | Write-Output
} catch {
    $failureSummary = [ordered]@{
        status = "failed"
        error = $_.Exception.Message
        fixture_root = $fixtureRoot
        evidence_root = $EvidenceRoot
    }
    $failureSummary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $summaryPath -Encoding utf8
    Write-Error $_.Exception.Message
    exit 1
} finally {
    if (-not $KeepFixture) {
        Remove-VerifiedFixture -Path $fixtureRoot -AllowedRoot $fixtureParent
    }
}
