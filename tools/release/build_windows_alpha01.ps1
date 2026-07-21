[CmdletBinding()]
param(
    [string]$GodotPath = "",
    [string]$OutputDirectory = "builds/alpha01",
    [string]$Preset = "Windows Alpha 0.1",
    [switch]$SkipExportedSmoke
)

$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $godotCommand = Get-Command godot -ErrorAction SilentlyContinue
    if ($null -eq $godotCommand) {
        throw "Godot 4.7 was not found. Pass -GodotPath explicitly."
    }
    $candidateDirectory = Split-Path $godotCommand.Source -Parent
    $GodotPath = Join-Path $candidateDirectory "Godot_v4.7-stable_win64_console.exe"
}
$GodotPath = [IO.Path]::GetFullPath($GodotPath)
if (-not (Test-Path -LiteralPath $GodotPath)) {
    throw "Godot executable is missing: $GodotPath"
}
$godotProductVersion = [Diagnostics.FileVersionInfo]::GetVersionInfo($GodotPath).ProductVersion
if ([string]::IsNullOrWhiteSpace($godotProductVersion) -or -not $godotProductVersion.StartsWith("4.7")) {
    throw "Godot 4.7 is required: $GodotPath"
}

Push-Location $projectRoot
try {
    & python tools/release/check_release_safety.py --project . --json
    if ($LASTEXITCODE -ne 0) {
        throw "Release safety gate failed. No export was produced."
    }

    $outputRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot $OutputDirectory))
    if (-not $outputRoot.StartsWith($projectRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "OutputDirectory must stay inside the project worktree."
    }
    [IO.Directory]::CreateDirectory($outputRoot) | Out-Null
    $exePath = Join-Path $outputRoot "SpaceSyndicate-Alpha-0.1-Windows-x86_64.exe"
    $exportLog = Join-Path $outputRoot "windows_export.log"

    & $GodotPath --headless --path $projectRoot --log-file $exportLog --export-release $Preset $exePath
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $exePath)) {
        throw "Windows export failed. See $exportLog"
    }

    $smoke = [ordered]@{ skipped = [bool]$SkipExportedSmoke; exit_code = $null; bridge_files = @(); error_lines = @() }
    if (-not $SkipExportedSmoke) {
        $runtimeRoot = Join-Path $outputRoot "isolated-runtime"
        $runtimeRoaming = Join-Path $runtimeRoot "appdata-roaming"
        $runtimeLocal = Join-Path $runtimeRoot "appdata-local"
        [IO.Directory]::CreateDirectory($runtimeRoaming) | Out-Null
        [IO.Directory]::CreateDirectory($runtimeLocal) | Out-Null
        $runtimeLog = Join-Path $outputRoot "exported_smoke.log"
        $process = Start-Process -FilePath $exePath `
            -ArgumentList @("--headless", "--quit-after", "10", "--log-file", ('"' + $runtimeLog + '"')) `
            -Environment @{ APPDATA = $runtimeRoaming; LOCALAPPDATA = $runtimeLocal } `
            -PassThru -Wait -WindowStyle Hidden
        $smoke.exit_code = $process.ExitCode
        $smoke.bridge_files = @(
            Get-ChildItem $runtimeRoot -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like "funplay_mcp_runtime_*" } |
                ForEach-Object { $_.FullName.Substring($runtimeRoot.Length + 1) }
        )
        if (Test-Path -LiteralPath $runtimeLog) {
            $smoke.error_lines = @(
                Select-String -LiteralPath $runtimeLog -Pattern "SCRIPT ERROR|Parser Error|ERROR:" |
                    ForEach-Object { $_.Line }
            )
        }
        if ($process.ExitCode -ne 0 -or $smoke.bridge_files.Count -gt 0 -or $smoke.error_lines.Count -gt 0) {
            throw "Exported smoke failed: exit=$($process.ExitCode), bridge_files=$($smoke.bridge_files.Count), errors=$($smoke.error_lines.Count)"
        }
    }

    $manifest = [ordered]@{
        schema_version = 1
        generated_at = (Get-Date).ToUniversalTime().ToString("o")
        git_sha = (git rev-parse HEAD).Trim()
        preset = $Preset
        godot_version = $godotProductVersion
        executable = $exePath.Substring($projectRoot.Length + 1).Replace("\", "/")
        executable_bytes = (Get-Item -LiteralPath $exePath).Length
        executable_sha256 = (Get-FileHash -LiteralPath $exePath -Algorithm SHA256).Hash.ToLowerInvariant()
        exported_smoke = $smoke
    }
    $manifestPath = Join-Path $outputRoot "build_manifest.json"
    [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    $manifest | ConvertTo-Json -Depth 8
} finally {
    Pop-Location
}
