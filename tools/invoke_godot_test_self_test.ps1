<#
.SYNOPSIS
Exercises invoke_godot_test.ps1 import modes against isolated Godot projects.

.DESCRIPTION
Creates repository-external fixtures with paths containing spaces and verifies:
EnsureImported cold bootstrap, EnsureImported warm-cache skip, RefreshImport stale
cache refresh, refresh precedence when both switches are present, import failure
short-circuiting, and unchanged production player-state fingerprints.
#>
[CmdletBinding()]
param(
    [string]$RunnerPath = (Join-Path $PSScriptRoot "invoke_godot_test.ps1"),

    [string]$GodotPath = "C:\Users\zhuye\AppData\Local\Programs\Godot\4.7\Godot_v4.7-stable_win64.exe",

    [string]$EvidenceRoot = (Join-Path $env:LOCALAPPDATA ("SpaceSyndicate\runner_self_tests\{0}-{1}" -f [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss-fff"), ([guid]::NewGuid().ToString("N").Substring(0, 8)))),

    [string]$PlayerDataRoot = (Join-Path $env:APPDATA "Godot\app_userdata\太空辛迪加"),

    [switch]$KeepFixture
)

$ErrorActionPreference = "Stop"

function Assert-RunnerCondition {
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

function Get-FileFingerprint {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $item = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
    if ($null -eq $item -or $item.PSIsContainer) {
        return [pscustomobject][ordered]@{
            path = [IO.Path]::GetFullPath($Path)
            present = $false
            size = [int64]0
            mtime_utc = $null
            sha256 = $null
        }
    }

    return [pscustomobject][ordered]@{
        path = $item.FullName
        present = $true
        size = [int64]$item.Length
        mtime_utc = $item.LastWriteTimeUtc.ToString("o")
        sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
    }
}

function Get-PlayerStateFingerprint {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root
    )

    $paths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($name in @("campaign_progress.save", "space_syndicate_current_run.save")) {
        $paths.Add((Join-Path $Root $name)) | Out-Null
    }
    if (Test-Path -LiteralPath $Root -PathType Container) {
        foreach ($item in Get-ChildItem -LiteralPath $Root -File -ErrorAction SilentlyContinue) {
            if ($item.Extension -eq ".save") {
                $paths.Add($item.FullName) | Out-Null
            }
        }
    }
    return @($paths | Sort-Object | ForEach-Object { Get-FileFingerprint -Path $_ })
}

function New-RunnerFixture {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,
        [Parameter(Mandatory = $true)]
        [string]$UserDirName
    )

    New-Item -ItemType Directory -Force -Path (Join-Path $Root "tests") | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $Root "scripts") | Out-Null
    @"
config_version=5

[application]

config/name="Runner Refresh Import Fixture"
config/use_custom_user_dir=true
config/custom_user_dir_name="$UserDirName"

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
"@ | Set-Content -LiteralPath (Join-Path $Root "project.godot") -Encoding utf8
    @'
extends SceneTree

func _init() -> void:
	print("RUNNER_REFRESH_IMPORT_FIXTURE|PASS")
	quit(0)
'@ | Set-Content -LiteralPath (Join-Path $Root "tests\pass.gd") -Encoding utf8
    @'
class_name RunnerRefreshExistingClass
extends RefCounted
'@ | Set-Content -LiteralPath (Join-Path $Root "scripts\existing_class.gd") -Encoding utf8
}

function Invoke-RunnerCase {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$ProjectPath,
        [Parameter(Mandatory = $true)]
        [string[]]$ImportSwitches,
        [Parameter(Mandatory = $true)]
        [string]$LogRoot
    )

    $pwshPath = (Get-Command pwsh -ErrorAction Stop).Source
    $arguments = @(
        "-NoProfile",
        "-File", $RunnerPath,
        "-TestScript", "res://tests/pass.gd",
        "-ProjectPath", $ProjectPath,
        "-GodotPath", $GodotPath,
        "-LogRoot", $LogRoot,
        "-ImportTimeoutSeconds", "120",
        "-TimeoutSeconds", "60"
    ) + $ImportSwitches
    $output = @(& $pwshPath @arguments 2>&1 | ForEach-Object { $_.ToString() })
    $exitCode = $LASTEXITCODE
    $jsonLine = @($output | Where-Object { $_.TrimStart().StartsWith("{") -and $_.TrimEnd().EndsWith("}") } | Select-Object -Last 1)
    if ($jsonLine.Count -ne 1) {
        throw "$Name did not emit one machine-readable result. exit=$exitCode output=$($output -join [Environment]::NewLine)"
    }
    return [pscustomobject][ordered]@{
        name = $Name
        exit_code = $exitCode
        result = ($jsonLine[0] | ConvertFrom-Json -Depth 20)
        console_output = $output
    }
}

function Remove-VerifiedTree {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$AllowedRoot
    )

    $resolvedPath = [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
    $resolvedRoot = [IO.Path]::GetFullPath($AllowedRoot).TrimEnd('\', '/')
    $requiredPrefix = $resolvedRoot + [IO.Path]::DirectorySeparatorChar
    if (-not $resolvedPath.StartsWith($requiredPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove path outside the verified root: $resolvedPath"
    }
    if (Test-Path -LiteralPath $resolvedPath) {
        Remove-Item -LiteralPath $resolvedPath -Recurse -Force
    }
}

$RunnerPath = (Resolve-Path -LiteralPath $RunnerPath).Path
$GodotPath = (Resolve-Path -LiteralPath $GodotPath).Path
$EvidenceRoot = [IO.Path]::GetFullPath($EvidenceRoot)
$fixtureParent = Join-Path ([IO.Path]::GetTempPath()) "SpaceSyndicate Runner Self Tests"
$fixtureId = [guid]::NewGuid().ToString("N").Substring(0, 12)
$fixtureRoot = Join-Path $fixtureParent "Refresh Import Fixture $fixtureId"
$failureFixtureRoot = Join-Path $fixtureParent "Import Failure Fixture $fixtureId"
$validUserDirName = "SpaceSyndicateRunnerRefresh_$fixtureId"
$failureUserDirName = "SpaceSyndicateRunnerFailure_$fixtureId"
$godotUserRoot = Join-Path $env:APPDATA "Godot\app_userdata"
$summaryPath = Join-Path $EvidenceRoot "self_test_summary.json"
$summary = $null

New-Item -ItemType Directory -Force -Path $EvidenceRoot | Out-Null
$playerStateBefore = Get-PlayerStateFingerprint -Root $PlayerDataRoot

try {
    New-RunnerFixture -Root $fixtureRoot -UserDirName $validUserDirName
    New-RunnerFixture -Root $failureFixtureRoot -UserDirName $failureUserDirName

    $cold = Invoke-RunnerCase -Name "ensure_cold_bootstrap" -ProjectPath $fixtureRoot -ImportSwitches @("-EnsureImported") -LogRoot (Join-Path $EvidenceRoot "godot runs")
    Assert-RunnerCondition ($cold.exit_code -eq 0) "EnsureImported cold bootstrap did not pass."
    Assert-RunnerCondition ($cold.result.import.mode -eq "ensure" -and $cold.result.import.reason -eq "cache_missing") "Cold bootstrap did not report ensure/cache_missing."
    Assert-RunnerCondition ($cold.result.import.attempted -and $cold.result.import.succeeded -and $cold.result.import.status -eq "bootstrapped") "Cold bootstrap did not run one successful import."
    Assert-RunnerCondition (-not $cold.result.import.cache_present_before -and $cold.result.import.cache_valid_after) "Cold bootstrap cache audit is inconsistent."
    Assert-RunnerCondition ($cold.result.test_started) "Cold bootstrap did not start the test after import."

    $warm = Invoke-RunnerCase -Name "ensure_existing_cache_skip" -ProjectPath $fixtureRoot -ImportSwitches @("-EnsureImported") -LogRoot (Join-Path $EvidenceRoot "godot runs")
    Assert-RunnerCondition ($warm.exit_code -eq 0) "EnsureImported warm-cache run did not pass."
    Assert-RunnerCondition ($warm.result.import.mode -eq "ensure" -and $warm.result.import.reason -eq "cache_valid") "Warm EnsureImported did not report cache_valid."
    Assert-RunnerCondition (-not $warm.result.import.attempted -and $warm.result.import.succeeded -and $warm.result.import.status -eq "cache_valid") "Warm EnsureImported did not skip import."
    Assert-RunnerCondition ($warm.result.import.cache_sha256_before -eq $warm.result.import.cache_sha256_after) "Warm EnsureImported changed the cache unexpectedly."

    $addedClassName = "RunnerRefreshAddedClass"
    @"
class_name $addedClassName
extends RefCounted
"@ | Set-Content -LiteralPath (Join-Path $fixtureRoot "scripts\added_class.gd") -Encoding utf8
    $cachePath = Join-Path $fixtureRoot ".godot\global_script_class_cache.cfg"
    Assert-RunnerCondition (-not ([IO.File]::ReadAllText($cachePath).Contains($addedClassName))) "Fixture cache was not stale before RefreshImport."

    $refresh = Invoke-RunnerCase -Name "refresh_existing_stale_cache" -ProjectPath $fixtureRoot -ImportSwitches @("-EnsureImported", "-RefreshImport") -LogRoot (Join-Path $EvidenceRoot "godot runs")
    Assert-RunnerCondition ($refresh.exit_code -eq 0) "RefreshImport stale-cache run did not pass."
    Assert-RunnerCondition ($refresh.result.import.mode -eq "refresh" -and $refresh.result.import.reason -eq "refresh_requested") "RefreshImport did not take precedence over EnsureImported."
    Assert-RunnerCondition ($refresh.result.import.attempted -and $refresh.result.import.succeeded -and $refresh.result.import.status -eq "refreshed") "RefreshImport did not run one successful import."
    Assert-RunnerCondition (@($refresh.result.import.command_arguments | Where-Object { $_ -eq "--import" }).Count -eq 1) "RefreshImport did not invoke exactly one --import."
    Assert-RunnerCondition ($refresh.result.import.cache_changed -and $refresh.result.import.cache_sha256_before -ne $refresh.result.import.cache_sha256_after) "Stale RefreshImport did not change the cache fingerprint."
    Assert-RunnerCondition (-not [string]::IsNullOrEmpty($refresh.result.import.cache_mtime_utc_before) -and -not [string]::IsNullOrEmpty($refresh.result.import.cache_mtime_utc_after)) "RefreshImport did not record cache mtimes."
    Assert-RunnerCondition ([IO.File]::ReadAllText($cachePath).Contains($addedClassName)) "Refreshed cache did not register the added class_name."
    Assert-RunnerCondition ($refresh.result.test_started) "RefreshImport did not start the test after import."

    Set-Content -LiteralPath $cachePath -Value "not a valid Godot class cache" -Encoding utf8
    $invalid = Invoke-RunnerCase -Name "ensure_invalid_cache_bootstrap" -ProjectPath $fixtureRoot -ImportSwitches @("-EnsureImported") -LogRoot (Join-Path $EvidenceRoot "godot runs")
    Assert-RunnerCondition ($invalid.exit_code -eq 0) "EnsureImported invalid-cache bootstrap did not pass."
    Assert-RunnerCondition ($invalid.result.import.mode -eq "ensure" -and $invalid.result.import.reason -eq "cache_invalid") "Invalid cache did not report ensure/cache_invalid."
    Assert-RunnerCondition ($invalid.result.import.cache_invalid_reason_before -eq "invalid_format") "Invalid cache format was not audited."
    Assert-RunnerCondition ($invalid.result.import.attempted -and $invalid.result.import.succeeded -and $invalid.result.import.status -eq "bootstrapped") "Invalid cache was not rebuilt."
    Assert-RunnerCondition ($invalid.result.import.cache_valid_after -and $invalid.result.test_started) "Invalid cache rebuild did not produce a valid cache before test start."

    Set-Content -LiteralPath (Join-Path $failureFixtureRoot ".godot") -Value "blocks the cache directory" -Encoding utf8
    $failure = Invoke-RunnerCase -Name "import_failure_short_circuit" -ProjectPath $failureFixtureRoot -ImportSwitches @("-EnsureImported") -LogRoot (Join-Path $EvidenceRoot "godot runs")
    Assert-RunnerCondition ($failure.exit_code -ne 0) "Import failure fixture unexpectedly returned success."
    Assert-RunnerCondition ($failure.result.import.attempted -and -not $failure.result.import.succeeded) "Import failure was not recorded."
    Assert-RunnerCondition (-not $failure.result.test_started) "Test started after import failure."
    Assert-RunnerCondition ($failure.result.import.process_exit_code -ne 0 -or -not $failure.result.import.cache_valid_after) "Failure result recorded neither a nonzero import exit nor an invalid cache."

    foreach ($case in @($cold, $warm, $refresh, $invalid, $failure)) {
        Assert-RunnerCondition (@($case.result.remaining_project_runtime_process_ids).Count -eq 0) "$($case.name) left a scoped runtime process."
        Assert-RunnerCondition (@($case.result.import.remaining_project_runtime_process_ids).Count -eq 0) "$($case.name) import left a scoped runtime process."
        if ($case.result.import.attempted) {
            foreach ($logPath in @($case.result.import.stdout_log, $case.result.import.stderr_log, $case.result.import.godot_log)) {
                Assert-RunnerCondition (-not [string]::IsNullOrEmpty($logPath) -and (Test-Path -LiteralPath $logPath -PathType Leaf)) "$($case.name) did not retain an independent import log."
            }
        }
    }

    $playerStateAfter = Get-PlayerStateFingerprint -Root $PlayerDataRoot
    $playerStateUnchanged = (ConvertTo-Json $playerStateBefore -Depth 5 -Compress) -ceq (ConvertTo-Json $playerStateAfter -Depth 5 -Compress)
    Assert-RunnerCondition $playerStateUnchanged "Production player-state metadata or SHA-256 changed during isolated runner self-test."

    $summary = [ordered]@{
        status = "passed"
        evidence_root = $EvidenceRoot
        fixture_paths_contained_spaces = $fixtureRoot.Contains(" ") -and $failureFixtureRoot.Contains(" ")
        player_data_root = [IO.Path]::GetFullPath($PlayerDataRoot)
        player_state_unchanged = $playerStateUnchanged
        player_state_before = $playerStateBefore
        player_state_after = $playerStateAfter
        cases = @($cold, $warm, $refresh, $invalid, $failure)
    }
    $summary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $summaryPath -Encoding utf8
    $summary["summary_json"] = $summaryPath
    $summary | ConvertTo-Json -Depth 5 -Compress | Write-Output
} catch {
    $playerStateAfter = Get-PlayerStateFingerprint -Root $PlayerDataRoot
    $summary = [ordered]@{
        status = "failed"
        error = $_.Exception.Message
        evidence_root = $EvidenceRoot
        player_data_root = [IO.Path]::GetFullPath($PlayerDataRoot)
        player_state_unchanged = (ConvertTo-Json $playerStateBefore -Depth 5 -Compress) -ceq (ConvertTo-Json $playerStateAfter -Depth 5 -Compress)
        player_state_before = $playerStateBefore
        player_state_after = $playerStateAfter
    }
    $summary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $summaryPath -Encoding utf8
    Write-Error $_.Exception.Message
    exit 1
} finally {
    if (-not $KeepFixture) {
        Remove-VerifiedTree -Path $fixtureRoot -AllowedRoot $fixtureParent
        Remove-VerifiedTree -Path $failureFixtureRoot -AllowedRoot $fixtureParent
        Remove-VerifiedTree -Path (Join-Path $godotUserRoot $validUserDirName) -AllowedRoot $godotUserRoot
        Remove-VerifiedTree -Path (Join-Path $godotUserRoot $failureUserDirName) -AllowedRoot $godotUserRoot
    }
}
