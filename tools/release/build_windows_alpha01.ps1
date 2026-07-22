[CmdletBinding()]
param(
    [string]$GodotPath = "",
    [string]$OutputDirectory = "",
    [string]$TempDirectory = "",
    [string]$Preset = "Windows Alpha 0.1",
    [switch]$ReplaceOutput,
    [switch]$SkipExportedSmoke,
    [switch]$RunHeadedVerification
)

$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$projectParent = Split-Path $projectRoot -Parent
$expectedOutput = [IO.Path]::GetFullPath((Join-Path $projectParent "space-syndicate-builds\playtest-alpha-0.1"))

function Get-NormalizedPath([string]$Path) {
    return [IO.Path]::GetFullPath($Path).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
}

function Assert-NativeSuccess([string]$Operation) {
    if ($LASTEXITCODE -ne 0) {
        throw "$Operation failed with exit code $LASTEXITCODE."
    }
}

function Find-FatalLines([string]$LogPath) {
    if (-not (Test-Path -LiteralPath $LogPath)) {
        return @("missing_log:$LogPath")
    }
    return @(
        Select-String -LiteralPath $LogPath -Pattern "SCRIPT ERROR|Parser Error|Parse Error|ERROR:|Failed loading resource|Cannot open file" |
            ForEach-Object { $_.Line.Trim() } |
            Where-Object { $_ -ne "" }
    )
}

function Copy-PackageFile([string]$Source, [string]$RelativeDestination, [string]$PackageRoot) {
    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
        throw "Required package file is missing: $Source"
    }
    $destination = Join-Path $PackageRoot $RelativeDestination
    [IO.Directory]::CreateDirectory((Split-Path $destination -Parent)) | Out-Null
    Copy-Item -LiteralPath $Source -Destination $destination
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = $expectedOutput
}
$outputRoot = Get-NormalizedPath $OutputDirectory
$projectRootNormalized = Get-NormalizedPath $projectRoot
if ($outputRoot.StartsWith($projectRootNormalized + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw "OutputDirectory must be outside the Git worktree: $outputRoot"
}
if ($outputRoot -ne $expectedOutput) {
    Write-Warning "Using a non-default external output directory: $outputRoot"
}

if ([string]::IsNullOrWhiteSpace($TempDirectory)) {
    $TempDirectory = Join-Path $env:TEMP "space-syndicate-codex"
}
$tempBase = Get-NormalizedPath $TempDirectory
$requiredTempBase = Get-NormalizedPath (Join-Path $env:TEMP "space-syndicate-codex")
if (-not ($tempBase -eq $requiredTempBase -or $tempBase.StartsWith($requiredTempBase + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase))) {
    throw "TempDirectory must stay under $requiredTempBase"
}

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $godotCommand = Get-Command "Godot_v4.7-stable_win64_console.exe" -ErrorAction SilentlyContinue
    if ($null -eq $godotCommand) {
        $godotCommand = Get-Command godot -ErrorAction SilentlyContinue
    }
    if ($null -eq $godotCommand) {
        throw "Godot 4.7 was not found. Pass -GodotPath explicitly."
    }
    if ($godotCommand.Name -eq "godot.cmd") {
        $candidateDirectory = Split-Path $godotCommand.Source -Parent
        $GodotPath = Join-Path $candidateDirectory "Godot_v4.7-stable_win64_console.exe"
    } else {
        $GodotPath = $godotCommand.Source
    }
}
$GodotPath = Get-NormalizedPath $GodotPath
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot executable is missing: $GodotPath"
}
$godotVersionText = (& $GodotPath --version).Trim()
Assert-NativeSuccess "Godot version query"
if (-not $godotVersionText.StartsWith("4.7.")) {
    throw "Godot 4.7 is required; found '$godotVersionText' at $GodotPath"
}

$templateRoot = Join-Path $env:APPDATA "Godot\export_templates\4.7.stable"
$releaseTemplate = Join-Path $templateRoot "windows_release_x86_64.exe"
$templateVersionFile = Join-Path $templateRoot "version.txt"
if (-not (Test-Path -LiteralPath $releaseTemplate -PathType Leaf)) {
    throw "Godot 4.7 Windows x86_64 release template is missing: $releaseTemplate"
}
if (-not (Test-Path -LiteralPath $templateVersionFile -PathType Leaf)) {
    throw "Godot 4.7 template version marker is missing: $templateVersionFile"
}
$templateVersion = (Get-Content -LiteralPath $templateVersionFile -Raw).Trim()
if (-not $templateVersion.StartsWith("4.7")) {
    throw "Unexpected export template version '$templateVersion'."
}

Push-Location $projectRoot
try {
    $gitSha = (& git rev-parse HEAD).Trim()
    Assert-NativeSuccess "git rev-parse HEAD"
    $shortSha = $gitSha.Substring(0, 7)
    $dirtyLines = @(& git status --porcelain=v1 --untracked-files=all)
    Assert-NativeSuccess "git status"
    if ($dirtyLines.Count -gt 0) {
        throw "Refusing to export a dirty worktree. Commit the release foundation first.`n$($dirtyLines -join "`n")"
    }

    $runId = "alpha01-$shortSha-$([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ'))-$PID"
    $tempRoot = Join-Path $tempBase $runId
    $snapshotRoot = Join-Path $tempRoot "source"
    $packageRoot = Join-Path $tempRoot "package"
    $runtimeRoot = Join-Path $tempRoot "runtime"
    $logRoot = Join-Path $tempRoot "logs"
    foreach ($directory in @($snapshotRoot, $packageRoot, $runtimeRoot, $logRoot)) {
        [IO.Directory]::CreateDirectory($directory) | Out-Null
    }

    $sourceArchive = Join-Path $tempRoot "source.zip"
    & git archive --format=zip --output=$sourceArchive $gitSha
    Assert-NativeSuccess "git archive"
    Expand-Archive -LiteralPath $sourceArchive -DestinationPath $snapshotRoot

    $safetyJson = & python (Join-Path $snapshotRoot "tools\release\check_release_safety.py") --project $snapshotRoot --json
    Assert-NativeSuccess "release safety gate"
    $safety = $safetyJson | ConvertFrom-Json
    if ($safety.status -ne "PASS") {
        throw "Release safety gate failed: $($safetyJson -join [Environment]::NewLine)"
    }

    $editorScanLog = Join-Path $logRoot "editor_scan.log"
    & $GodotPath --headless --editor --path $snapshotRoot --log-file $editorScanLog --quit
    Assert-NativeSuccess "Godot editor scan"
    $editorFatalLines = @(Find-FatalLines $editorScanLog)
    if ($editorFatalLines.Count -gt 0) {
        throw "Godot editor scan reported fatal errors: $($editorFatalLines -join '; ')"
    }

    $exeName = "SpaceSyndicate-Alpha-0.1-Windows-x86_64.exe"
    $exePath = Join-Path $packageRoot $exeName
    $exportLog = Join-Path $logRoot "windows_export.log"
    & $GodotPath --headless --path $snapshotRoot --log-file $exportLog --export-release $Preset $exePath
    Assert-NativeSuccess "Godot Windows export"
    if (-not (Test-Path -LiteralPath $exePath -PathType Leaf)) {
        throw "Windows export did not create $exePath"
    }
    $exportFatalLines = @(Find-FatalLines $exportLog)
    if ($exportFatalLines.Count -gt 0) {
        throw "Godot Windows export reported fatal errors: $($exportFatalLines -join '; ')"
    }

    $smoke = [ordered]@{
        skipped = [bool]$SkipExportedSmoke
        exit_code = $null
        bridge_files = @()
        fatal_lines = @()
        log = $null
    }
    if (-not $SkipExportedSmoke) {
        $runtimeRoaming = Join-Path $runtimeRoot "appdata-roaming"
        $runtimeLocal = Join-Path $runtimeRoot "appdata-local"
        [IO.Directory]::CreateDirectory($runtimeRoaming) | Out-Null
        [IO.Directory]::CreateDirectory($runtimeLocal) | Out-Null
        $runtimeLog = Join-Path $logRoot "exported_headless_smoke.log"
        $process = Start-Process -FilePath $exePath `
            -ArgumentList @("--headless", "--quit-after", "10", "--log-file", ('"' + $runtimeLog + '"')) `
            -Environment @{ APPDATA = $runtimeRoaming; LOCALAPPDATA = $runtimeLocal } `
            -PassThru -Wait -WindowStyle Hidden
        $smoke.exit_code = $process.ExitCode
        $smoke.log = $runtimeLog
        $smoke.bridge_files = @(
            Get-ChildItem $runtimeRoot -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like "funplay_mcp_runtime_*" } |
                ForEach-Object { $_.FullName.Substring($runtimeRoot.Length + 1).Replace("\", "/") }
        )
        $smoke.fatal_lines = @(Find-FatalLines $runtimeLog)
        if ($process.ExitCode -ne 0 -or $smoke.bridge_files.Count -gt 0 -or $smoke.fatal_lines.Count -gt 0) {
            throw "Exported smoke failed: exit=$($process.ExitCode), bridge_files=$($smoke.bridge_files.Count), fatal_lines=$($smoke.fatal_lines.Count)"
        }
    }

    Copy-PackageFile (Join-Path $snapshotRoot "docs\tomorrow_human_playtest_checklist.md") "PLAYTEST.md" $packageRoot
    Copy-PackageFile (Join-Path $snapshotRoot "docs\third_party_assets.md") "LICENSES\THIRD_PARTY_ASSETS.md" $packageRoot
    Copy-PackageFile (Join-Path $snapshotRoot "docs\release\GODOT_ENGINE_LICENSE.txt") "LICENSES\GODOT_ENGINE_LICENSE.txt" $packageRoot
    Copy-PackageFile (Join-Path $snapshotRoot "addons\funplay_mcp\LICENSE") "LICENSES\addons\funplay_mcp\LICENSE" $packageRoot

    $licenseRoots = @(
        (Join-Path $snapshotRoot "assets\third_party")
        (Join-Path $snapshotRoot "docs\licenses")
    )
    foreach ($licenseRoot in $licenseRoots) {
        Get-ChildItem -LiteralPath $licenseRoot -Recurse -File |
            Where-Object {
                $_.FullName.StartsWith((Join-Path $snapshotRoot "docs\licenses"), [StringComparison]::OrdinalIgnoreCase) -or
                $_.Name -match '(?i)(LICENSE|NOTICE|README|CREDIT|ATTRIBUT)'
            } |
            ForEach-Object {
                $relative = [IO.Path]::GetRelativePath($snapshotRoot, $_.FullName)
                Copy-PackageFile $_.FullName (Join-Path "LICENSES" $relative) $packageRoot
            }
    }

    $headed = [ordered]@{ requested = [bool]$RunHeadedVerification; receipt = $null }
    if ($RunHeadedVerification) {
        $verifyScript = Join-Path $snapshotRoot "tools\release\verify_windows_alpha01.ps1"
        $headedJson = & pwsh -NoProfile -File $verifyScript -ExePath $exePath -TempDirectory (Join-Path $tempRoot "headed")
        Assert-NativeSuccess "headed exported executable verification"
        $headed.receipt = $headedJson | ConvertFrom-Json
    }

    $payloadFiles = @(
        Get-ChildItem -LiteralPath $packageRoot -Recurse -File |
            Where-Object { $_.Name -notin @("build_manifest.json", "SHA256SUMS") } |
            Sort-Object FullName |
            ForEach-Object {
                [ordered]@{
                    path = [IO.Path]::GetRelativePath($packageRoot, $_.FullName).Replace("\", "/")
                    bytes = $_.Length
                    sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
                }
            }
    )
    $manifest = [ordered]@{
        schema_version = 2
        release_label = "playtest-alpha-0.1"
        rc_claim = "foundation-candidate; final RC requires the PLAYTEST.md acceptance evidence"
        generated_at = [DateTime]::UtcNow.ToString("o")
        git_sha = $gitSha
        git_tree = (& git rev-parse "$gitSha^{tree}").Trim()
        source_snapshot = "git archive of the clean current commit"
        preset = $Preset
        godot = [ordered]@{
            version = $godotVersionText
            executable_sha256 = (Get-FileHash -LiteralPath $GodotPath -Algorithm SHA256).Hash.ToLowerInvariant()
            template_version = $templateVersion
            windows_release_x86_64_template_sha256 = (Get-FileHash -LiteralPath $releaseTemplate -Algorithm SHA256).Hash.ToLowerInvariant()
        }
        safety_gate = $safety
        development_bridge = [ordered]@{
            release_feature = "space_syndicate_release"
            fail_closed_guard_verified = [bool]($safety.status -eq "PASS")
            runtime_files_created = @($smoke.bridge_files)
        }
        exported_smoke = $smoke
        headed_verification = $headed
        documents = [ordered]@{
            playtest_source = "docs/tomorrow_human_playtest_checklist.md"
            license_register_source = "docs/third_party_assets.md"
            project_license = "not declared by this repository; no project license is asserted by this package"
        }
        files = $payloadFiles
        logs_directory = $logRoot
    }
    $manifestPath = Join-Path $packageRoot "build_manifest.json"
    [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false))

    $sumFiles = @(Get-ChildItem -LiteralPath $packageRoot -Recurse -File | Where-Object { $_.Name -ne "SHA256SUMS" } | Sort-Object FullName)
    $sumLines = @(
        $sumFiles | ForEach-Object {
            $relative = [IO.Path]::GetRelativePath($packageRoot, $_.FullName).Replace("\", "/")
            "$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant())  $relative"
        }
    )
    [IO.File]::WriteAllLines((Join-Path $packageRoot "SHA256SUMS"), $sumLines, [Text.UTF8Encoding]::new($false))

    if (Test-Path -LiteralPath $outputRoot) {
        if (-not $ReplaceOutput) {
            throw "Output already exists. Inspect it, then rerun with -ReplaceOutput: $outputRoot"
        }
        if ($outputRoot -ne $expectedOutput) {
            throw "-ReplaceOutput is permitted only for the canonical output directory: $expectedOutput"
        }
        Remove-Item -LiteralPath $outputRoot -Recurse -Force
    }
    [IO.Directory]::CreateDirectory((Split-Path $outputRoot -Parent)) | Out-Null
    Move-Item -LiteralPath $packageRoot -Destination $outputRoot

    [ordered]@{
        status = "PASS"
        git_sha = $gitSha
        output_directory = $outputRoot
        executable = Join-Path $outputRoot $exeName
        manifest = Join-Path $outputRoot "build_manifest.json"
        sha256sums = Join-Path $outputRoot "SHA256SUMS"
        logs_directory = $logRoot
        headed_screenshot = if ($null -ne $headed.receipt) { $headed.receipt.screenshot } else { $null }
    } | ConvertTo-Json -Depth 8
} finally {
    Pop-Location
}
