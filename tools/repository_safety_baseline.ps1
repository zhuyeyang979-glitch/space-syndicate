[CmdletBinding()]
param(
    [string]$ProjectPath = (Split-Path -Parent $PSScriptRoot),
    [string]$OutputDirectory = ""
)

$ErrorActionPreference = "Stop"
$ProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path
$projectFile = Join-Path $ProjectPath "project.godot"
if (-not (Test-Path -LiteralPath $projectFile)) {
    throw "project.godot was not found under $ProjectPath"
}

$projectText = Get-Content -LiteralPath $projectFile -Raw
$nameMatch = [regex]::Match($projectText, '(?m)^config/name="([^"]+)"')
$projectName = if ($nameMatch.Success) { $nameMatch.Groups[1].Value } else { "space-syndicate-sync" }
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $env:APPDATA ("Godot\app_userdata\{0}\space_syndicate_design_qa\repository_safety_baseline" -f $projectName)
}
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

function Get-FileRecord {
    param([string]$RelativePath, [string]$StatusCode)

    $normalized = $RelativePath.Trim('"')
    if ($normalized.Contains(" -> ")) {
        $normalized = $normalized.Split(" -> ")[-1]
    }
    $absolute = Join-Path $ProjectPath $normalized
    $exists = Test-Path -LiteralPath $absolute -PathType Leaf
    $extension = [IO.Path]::GetExtension($normalized).ToLowerInvariant()
    $kind = if ($extension -in @(".gd", ".tscn", ".tres", ".gdshader", ".cs")) {
        "godot_source"
    } elseif ($extension -in @(".json", ".cfg", ".md", ".txt", ".ps1", ".yml", ".yaml")) {
        "project_data"
    } elseif ($extension -eq ".uid") {
        "godot_uid"
    } else {
        "asset_or_other"
    }
    $item = if ($exists) { Get-Item -LiteralPath $absolute } else { $null }
    $forwardPath = $normalized.Replace('\', '/')
    $classification = if ($forwardPath.StartsWith('assets/third_party/')) {
        if ($extension -eq '.import') { 'third_party_import_metadata' } else { 'third_party_registered_asset' }
    } elseif ($forwardPath.StartsWith('addons/godot_mcp/cache/')) {
        'qa_generated_excluded'
    } elseif ($forwardPath.StartsWith('reports/') -and $extension -eq '.import') {
        'qa_generated_excluded'
    } elseif ($kind -in @('godot_source', 'project_data', 'godot_uid')) {
        'project_source_candidate'
    } elseif ($extension -eq '.import') {
        'godot_import_metadata'
    } else {
        'project_asset_candidate'
    }
    return [ordered]@{
        status = $StatusCode
        path = $normalized.Replace('\', '/')
        kind = $kind
        exists = $exists
        length = if ($item) { $item.Length } else { 0 }
        sha256 = if ($exists) { (Get-FileHash -Algorithm SHA256 -LiteralPath $absolute).Hash } else { "" }
        classification = $classification
        baseline_candidate = $classification -ne 'qa_generated_excluded'
    }
}

$statusLines = @(& git -c core.quotepath=false -C $ProjectPath status --porcelain=v1 -uall)
$statusRecords = @()
foreach ($line in $statusLines) {
    if ($line.Length -lt 4) {
        continue
    }
    $statusRecords += Get-FileRecord -RelativePath $line.Substring(3) -StatusCode $line.Substring(0, 2)
}
$ignoredPaths = @(& git -c core.quotepath=false -C $ProjectPath ls-files --others --ignored --exclude-standard)
$classificationSummary = @(
    $statusRecords |
        Group-Object { $_['classification'] } |
        Sort-Object Name |
        ForEach-Object {
            [ordered]@{
                classification = $_.Name
                count = $_.Count
                total_bytes = [long](($_.Group | ForEach-Object { [long]$_['length'] } | Measure-Object -Sum).Sum)
            }
        }
)
$largeFileThreshold = 10MB
$largeStatusFiles = @(
    $statusRecords |
        Where-Object { $_['exists'] -and [long]$_['length'] -ge $largeFileThreshold } |
        ForEach-Object {
            [ordered]@{
                path = $_['path']
                length = $_['length']
                classification = $_['classification']
            }
        }
)

$mainPath = Join-Path $ProjectPath "scripts\main.gd"
$mainLines = @(Get-Content -LiteralPath $mainPath)
$defaultSavePath = Join-Path $env:APPDATA ("Godot\app_userdata\{0}\space_syndicate_current_run.save" -f $projectName)
$defaultSaveExists = Test-Path -LiteralPath $defaultSavePath -PathType Leaf
$defaultSaveItem = if ($defaultSaveExists) { Get-Item -LiteralPath $defaultSavePath } else { $null }
$nightNoticePath = Join-Path $ProjectPath "assets\third_party\night_patrol\NOTICE.md"
$nightNotice = if (Test-Path -LiteralPath $nightNoticePath) { Get-Content -LiteralPath $nightNoticePath -Raw } else { "" }
$mainSceneText = Get-Content -LiteralPath (Join-Path $ProjectPath "scenes\main.tscn") -Raw

$manifest = [ordered]@{
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    project_path = $ProjectPath
    project_name = $projectName
    git = [ordered]@{
        branch = (& git -C $ProjectPath branch --show-current).Trim()
        head = (& git -C $ProjectPath rev-parse HEAD).Trim()
        status_entry_count = $statusRecords.Count
        tracked_change_count = @($statusRecords | Where-Object { $_.status -ne "??" }).Count
        untracked_count = @($statusRecords | Where-Object { $_.status -eq "??" }).Count
        clean_clone_ready = $statusRecords.Count -eq 0
        ignored_count = $ignoredPaths.Count
    }
    main = [ordered]@{
        total_lines = $mainLines.Count
        nonblank_lines = @($mainLines | Where-Object { $_.Trim().Length -gt 0 }).Count
        function_count = @($mainLines | Where-Object { $_ -match '^func\s+' }).Count
        sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $mainPath).Hash
    }
    player_save_guard = [ordered]@{
        path = $defaultSavePath
        exists = $defaultSaveExists
        length = if ($defaultSaveItem) { $defaultSaveItem.Length } else { 0 }
        last_write_utc = if ($defaultSaveItem) { $defaultSaveItem.LastWriteTimeUtc.ToString("o") } else { "" }
        sha256 = if ($defaultSaveExists) { (Get-FileHash -Algorithm SHA256 -LiteralPath $defaultSavePath).Hash } else { "" }
        read_only_audit = $true
    }
    release_blockers = @(
        [ordered]@{
            id = "night_patrol_noncommercial_runtime_dependency"
            active = $nightNotice -match 'CC BY-NC 4\.0' -and $mainSceneText.Contains('assets/third_party/night_patrol/')
            license = "CC BY-NC 4.0"
            runtime_reference_count = ([regex]::Matches($mainSceneText, 'assets/third_party/night_patrol/')).Count
            action = "Replace or remove from commercial builds; retain provenance while used in private prototypes."
        }
    )
    classification_summary = $classificationSummary
    large_file_threshold_bytes = $largeFileThreshold
    large_status_files = $largeStatusFiles
    ignored_paths = $ignoredPaths
    status_records = $statusRecords
}

$manifestPath = Join-Path $OutputDirectory "manifest.json"
$reportPath = Join-Path $OutputDirectory "report.md"
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding utf8

$report = @(
    "# Repository Safety Baseline",
    "",
    "- Generated: $($manifest.generated_at_utc)",
    "- Git HEAD: ``$($manifest.git.head)``",
    "- Branch: ``$($manifest.git.branch)``",
    "- Tracked changes: **$($manifest.git.tracked_change_count)**",
    "- Untracked paths: **$($manifest.git.untracked_count)**",
    "- Ignored paths: **$($manifest.git.ignored_count)**",
    "- Clean-clone gate ready: **$($manifest.git.clean_clone_ready)**",
    "- main.gd: **$($manifest.main.nonblank_lines)** nonblank lines / **$($manifest.main.function_count)** functions",
    "- main.gd SHA-256: ``$($manifest.main.sha256)``",
    "- Existing player save was audited read-only: **$($manifest.player_save_guard.exists)**",
    "- Night Patrol commercial blocker active: **$($manifest.release_blockers[0].active)**",
    "- Changed/untracked files at or above 10 MiB: **$($manifest.large_status_files.Count)**",
    "",
    "## Classification",
    ""
)
$report += @($classificationSummary | ForEach-Object {
    "- $($_.classification): **$($_.count)** files / **$($_.total_bytes)** bytes"
})
$report += @(
    "",
    "This tool does not add, remove, stage, commit, reset, or move repository files."
)
$report -join "`n" | Set-Content -LiteralPath $reportPath -Encoding utf8

[ordered]@{
    manifest_path = $manifestPath
    report_path = $reportPath
    tracked_change_count = $manifest.git.tracked_change_count
    untracked_count = $manifest.git.untracked_count
    ignored_count = $manifest.git.ignored_count
    large_status_file_count = $manifest.large_status_files.Count
    player_save_sha256 = $manifest.player_save_guard.sha256
    main_sha256 = $manifest.main.sha256
} | ConvertTo-Json -Compress
