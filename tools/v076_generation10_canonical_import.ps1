param(
    [Parameter(Mandatory = $true)]
    [string]$ExactClone,
    [Parameter(Mandatory = $true)]
    [ValidateSet("pass-001", "pass-002")]
    [string]$PassId,
    [int]$TimeoutSeconds = 1800
)

$ErrorActionPreference = "Stop"

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class Generation10MemoryStatus {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public class MEMORYSTATUSEX {
        public uint dwLength = (uint)Marshal.SizeOf(typeof(MEMORYSTATUSEX));
        public uint dwMemoryLoad;
        public ulong ullTotalPhys;
        public ulong ullAvailPhys;
        public ulong ullTotalPageFile;
        public ulong ullAvailPageFile;
        public ulong ullTotalVirtual;
        public ulong ullAvailVirtual;
        public ulong ullAvailExtendedVirtual;
    }
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern bool GlobalMemoryStatusEx([In, Out] MEMORYSTATUSEX buffer);
}
"@

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Write-Utf8([string]$Path, [string]$Text) {
    [System.IO.Directory]::CreateDirectory((Split-Path -Parent $Path)) | Out-Null
    [System.IO.File]::WriteAllText($Path, $Text, [System.Text.UTF8Encoding]::new($false))
}

function Get-GitStatusRows([string]$Root) {
    return @(git -C $Root status --porcelain=v1 -uall)
}

function Get-ExpectedImportedPaths([string]$Root) {
    $result = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    Get-ChildItem -LiteralPath $Root -Recurse -File -Filter "*.import" -Force | ForEach-Object {
        $text = Get-Content -LiteralPath $_.FullName -Raw
        foreach ($match in [regex]::Matches($text, 'res://\.godot/imported/[^"\r\n]+')) {
            $relative = $match.Value.Substring("res://".Length).Replace("/", [System.IO.Path]::DirectorySeparatorChar)
            [void]$result.Add((Join-Path $Root $relative))
        }
    }
    return @($result | Sort-Object)
}

function Get-ImportQueueLength([string[]]$ExpectedPaths) {
    $missing = 0
    foreach ($path in $ExpectedPaths) {
        if (-not (Test-Path -LiteralPath $path)) {
            $missing += 1
        }
    }
    return $missing
}

function Get-ImportedManifest([string]$Root) {
    $importedRoot = Join-Path $Root ".godot/imported"
    if (-not (Test-Path -LiteralPath $importedRoot)) {
        return @()
    }
    return @(Get-ChildItem -LiteralPath $importedRoot -Recurse -File -Force | Sort-Object FullName | ForEach-Object {
        [ordered]@{
            path = [System.IO.Path]::GetRelativePath($Root, $_.FullName).Replace("\", "/")
            size_bytes = [int64]$_.Length
            sha256 = Get-Sha256 $_.FullName
        }
    })
}

function Get-ManifestFingerprint([object[]]$Manifest) {
    $canonical = @($Manifest | ForEach-Object {"$($_.path)|$($_.size_bytes)|$($_.sha256)"}) -join "`n"
    $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($canonical)
    $hash = [System.Security.Cryptography.SHA256]::HashData($bytes)
    return [System.Convert]::ToHexString($hash).ToLowerInvariant()
}

$root = (Resolve-Path -LiteralPath $ExactClone).Path.TrimEnd("\")
if (-not (Test-Path -LiteralPath (Join-Path $root "project.godot"))) {
    throw "ExactClone is not a Godot project: $root"
}

$head = (git -C $root rev-parse HEAD).Trim()
$tree = (git -C $root rev-parse "HEAD^{tree}").Trim()
$branch = git -C $root branch --show-current
if ([string]::IsNullOrWhiteSpace($branch)) { $branch = "DETACHED" }
$statusBefore = @(Get-GitStatusRows $root)
$trackedBefore = @($statusBefore | Where-Object {$_ -notmatch '^\?\?'})
$untrackedBefore = @($statusBefore | Where-Object {$_ -match '^\?\?'})
$unexpectedUntrackedBefore = @($untrackedBefore | Where-Object {
    $path = $_.Substring(3).Replace("\", "/")
    $path -notlike "*.uid" -and
        $path -notlike "reports/reuse/full_convergence/generation10/canonical_import_terminal_repair_001/*"
})
$indexBefore = @($statusBefore | Where-Object {$_.Substring(0, 1) -notin @(" ", "?")})
$cacheRoot = Join-Path $root ".godot"

if ($PassId -eq "pass-001") {
    if ($trackedBefore.Count -ne 0 -or $indexBefore.Count -ne 0 -or $unexpectedUntrackedBefore.Count -ne 0) {
        throw "Canonical pass 1 requires zero tracked/index/unexpected-untracked rows; found tracked=$($trackedBefore.Count), index=$($indexBefore.Count), unexpected_untracked=$($unexpectedUntrackedBefore.Count)."
    }
    if (Test-Path -LiteralPath $cacheRoot) {
        throw "Canonical pass 1 requires an absent .godot cache; refusing to reuse an unsealed cache."
    }
} else {
    $pass1Report = Join-Path $root "reports/reuse/full_convergence/generation10/canonical_import_terminal_repair_001/pass-001/canonical_import_report.json"
    if (-not (Test-Path -LiteralPath $pass1Report)) {
        throw "Canonical pass 2 requires the sealed pass 1 report."
    }
    if (-not (Test-Path -LiteralPath $cacheRoot)) {
        throw "Canonical pass 2 requires the pass 1 cache."
    }
    if ($indexBefore.Count -ne 0) {
        throw "Canonical pass 2 requires an unchanged index."
    }
}

$godotCommand = Get-Command godot -ErrorAction Stop
$godotCommandPath = (Resolve-Path -LiteralPath $godotCommand.Source).Path
$godotPath = $godotCommandPath
if ([System.IO.Path]::GetExtension($godotCommandPath).Equals(".cmd", [System.StringComparison]::OrdinalIgnoreCase)) {
    $shimText = Get-Content -LiteralPath $godotCommandPath -Raw
    $shimMatch = [regex]::Match($shimText, '"%~dp0(?<exe>Godot_[^"\r\n]+\.exe)"')
    if (-not $shimMatch.Success) {
        throw "Unable to resolve the Godot executable from launcher: $godotCommandPath"
    }
    $godotPath = (Resolve-Path -LiteralPath (Join-Path (Split-Path -Parent $godotCommandPath) $shimMatch.Groups["exe"].Value)).Path
}
$godotVersion = (& $godotPath --version).Trim()
if ($godotVersion -notmatch '^4\.7\.') {
    throw "Generation 10 is pinned to Godot 4.7.x; observed: $godotVersion"
}

$externalRoot = Join-Path "D:\ss-v076-generation10-terminal-canonical-evidence-001-20260902" $PassId
if (Test-Path -LiteralPath $externalRoot) {
    throw "Refusing to overwrite an existing canonical import pass: $externalRoot"
}
[System.IO.Directory]::CreateDirectory($externalRoot) | Out-Null
$stdoutPath = Join-Path $externalRoot "godot.stdout.log"
$stderrPath = Join-Path $externalRoot "godot.stderr.log"
$engineLogPath = Join-Path $externalRoot "godot.engine.log"
$samplesPath = Join-Path $externalRoot "memory_samples.jsonl"

$roleLocalRoot = Join-Path $root ".codex-godot"
$roamingRoot = Join-Path $roleLocalRoot "generation10-terminal-canonical-001-$PassId-appdata-roaming"
$localAppDataRoot = Join-Path $roleLocalRoot "generation10-terminal-canonical-001-$PassId-appdata-local"
[System.IO.Directory]::CreateDirectory($roamingRoot) | Out-Null
[System.IO.Directory]::CreateDirectory($localAppDataRoot) | Out-Null

$expectedPaths = @(Get-ExpectedImportedPaths $root)
$initialQueueLength = Get-ImportQueueLength $expectedPaths
$startCapacity = [Generation10MemoryStatus+MEMORYSTATUSEX]::new()
if (-not [Generation10MemoryStatus]::GlobalMemoryStatusEx($startCapacity)) {
    throw "GlobalMemoryStatusEx failed before canonical import."
}

if ($startCapacity.ullAvailPageFile -lt 8589934592) { throw "CANONICAL_IMPORT_COMMIT_CAPACITY_BELOW_8GIB" }

$arguments = @(
    "--editor",
    "--import",
    "--path", ('"' + $root + '"'),
    "--log-file", ('"' + $engineLogPath + '"'),
    "--rendering-method", "gl_compatibility",
    "--rendering-driver", "opengl3_angle",
    "--verbose"
) -join " "

$process = Start-Process -WindowStyle Hidden -FilePath $godotPath -ArgumentList $arguments -Environment @{
    APPDATA = $roamingRoot
    LOCALAPPDATA = $localAppDataRoot
} -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -PassThru

$startedAt = $process.StartTime.ToUniversalTime()
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$timedOut = $false
$sampleCount = 0
$peakWorking = [int64]0
$peakPrivate = [int64]0
$minimumAvailablePhysical = [uint64]::MaxValue
$minimumAvailableCommit = [uint64]::MaxValue
$maximumQueueLength = $initialQueueLength
$lastQueueLength = $initialQueueLength

while (-not $process.HasExited) {
    if ((Get-Date) -ge $deadline) {
        $timedOut = $true
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        [void]$process.WaitForExit(10000)
        break
    }

    $memory = [Generation10MemoryStatus+MEMORYSTATUSEX]::new()
    if (-not [Generation10MemoryStatus]::GlobalMemoryStatusEx($memory)) {
        throw "GlobalMemoryStatusEx failed during canonical import."
    }
    $liveProcess = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
    $working = if ($null -ne $liveProcess) {[int64]$liveProcess.WorkingSet64} else {[int64]0}
    $private = if ($null -ne $liveProcess) {[int64]$liveProcess.PrivateMemorySize64} else {[int64]0}
    $handles = if ($null -ne $liveProcess) {[int64]$liveProcess.HandleCount} else {[int64]0}
    $threads = if ($null -ne $liveProcess) {[int64]$liveProcess.Threads.Count} else {[int64]0}
    $lastQueueLength = Get-ImportQueueLength $expectedPaths

    $peakWorking = [math]::Max($peakWorking, $working)
    $peakPrivate = [math]::Max($peakPrivate, $private)
    $minimumAvailablePhysical = [math]::Min($minimumAvailablePhysical, $memory.ullAvailPhys)
    $minimumAvailableCommit = [math]::Min($minimumAvailableCommit, $memory.ullAvailPageFile)
    $maximumQueueLength = [math]::Max($maximumQueueLength, $lastQueueLength)

    $sample = [ordered]@{
        captured_at_utc = (Get-Date).ToUniversalTime().ToString("o")
        elapsed_milliseconds = [int64]((Get-Date).ToUniversalTime() - $startedAt).TotalMilliseconds
        godot_pid = [int64]$process.Id
        godot_working_set_bytes = $working
        godot_private_bytes = $private
        godot_commit_size_bytes = $private
        godot_handle_count = $handles
        godot_thread_count = $threads
        system_available_physical_bytes = [uint64]$memory.ullAvailPhys
        system_available_commit_bytes = [uint64]$memory.ullAvailPageFile
        system_commit_used_bytes = [uint64]($memory.ullTotalPageFile - $memory.ullAvailPageFile)
        system_commit_limit_bytes = [uint64]$memory.ullTotalPageFile
        import_queue_length = $lastQueueLength
        import_queue_basis = "missing expected .godot/imported outputs referenced by project .import metadata"
    }
    [System.IO.File]::AppendAllText($samplesPath, ($sample | ConvertTo-Json -Depth 5 -Compress) + "`n", [System.Text.UTF8Encoding]::new($false))
    $sampleCount += 1
    Start-Sleep -Milliseconds 250
    $process.Refresh()
}

if (-not $process.HasExited) {
    [void]$process.WaitForExit(10000)
}
$finishedAt = (Get-Date).ToUniversalTime()
$exitCode = if ($process.HasExited) {$process.ExitCode} else {-1}
$stdout = if (Test-Path -LiteralPath $stdoutPath) {Get-Content -LiteralPath $stdoutPath -Raw} else {""}
$stderr = if (Test-Path -LiteralPath $stderrPath) {Get-Content -LiteralPath $stderrPath -Raw} else {""}
$engineLog = if (Test-Path -LiteralPath $engineLogPath) {Get-Content -LiteralPath $engineLogPath -Raw} else {""}
$combinedLog = $stdout + "`n" + $stderr + "`n" + $engineLog

$finalQueueLength = Get-ImportQueueLength $expectedPaths
$manifest = @(Get-ImportedManifest $root)
$manifestFingerprint = Get-ManifestFingerprint $manifest
$classCachePath = Join-Path $root ".godot/global_script_class_cache.cfg"
$statusAfter = @(Get-GitStatusRows $root)
$trackedAfter = @($statusAfter | Where-Object {$_ -notmatch '^\?\?'})
$untrackedAfter = @($statusAfter | Where-Object {$_ -match '^\?\?'})
$unexpectedUntrackedAfter = @($untrackedAfter | Where-Object {
    $path = $_.Substring(3).Replace("\", "/")
    $path -notlike "*.uid" -and
        $path -notlike "reports/reuse/full_convergence/generation10/canonical_import_terminal_repair_001/*"
})
$indexAfter = @($statusAfter | Where-Object {$_.Substring(0, 1) -notin @(" ", "?")})
$trackedImportAfter = @($trackedAfter | Where-Object {$_.Substring(3) -like "*.import"})
$untrackedUidAfter = @($untrackedAfter | Where-Object {$_.Substring(3) -like "*.uid"})

$report = [ordered]@{
    schema_version = "space_syndicate.v076.generation10_terminal_repair_canonical_import.v1"
    authorization_id = "USER_CONFIRMED_GENERATION10_TERMINAL_DRAIN_REPAIR_20260902"
    pass_id = $PassId
    status = if (-not $timedOut -and $exitCode -eq 0 -and $finalQueueLength -eq 0 -and $indexAfter.Count -eq 0 -and $trackedAfter.Count -eq 0 -and $unexpectedUntrackedAfter.Count -eq 0 -and $combinedLog -notmatch 'FATAL: Condition "_copy_on_write\(\)" is true|Parameter "mem(?:_new)?" is null') {"PASS"} else {"FAIL"}
    exact_clone_path = $root
    branch = $branch
    head_sha = $head
    tree_sha = $tree
    godot_path = $godotPath
    godot_launcher_path = $godotCommandPath
    godot_version = $godotVersion
    command_mode = "--editor --import --rendering-method gl_compatibility --rendering-driver opengl3_angle"
    renderer_identity = "gl_compatibility/opengl3_angle"
    correction_id = "generation10-terminal-observer-repair-001"
    started_at_utc = $startedAt.ToString("o")
    finished_at_utc = $finishedAt.ToString("o")
    elapsed_milliseconds = [int64]($finishedAt - $startedAt).TotalMilliseconds
    process = [ordered]@{
        pid = [int64]$process.Id
        exit_code = [int64]$exitCode
        timeout = $timedOut
        process_crash = (-not $timedOut -and $exitCode -ne 0)
        clean_exit = (-not $timedOut -and $exitCode -eq 0)
    }
    monitoring = [ordered]@{
        interval_milliseconds = 250
        sample_count = $sampleCount
        sampled_process_kind = "GODOT_GUI_ENGINE"
        samples_external_path = $samplesPath
        samples_sha256 = if (Test-Path -LiteralPath $samplesPath) {Get-Sha256 $samplesPath} else {$null}
        peak_working_set_bytes = $peakWorking
        peak_private_bytes = $peakPrivate
        minimum_available_physical_bytes = [uint64]$minimumAvailablePhysical
        minimum_available_commit_bytes = [uint64]$minimumAvailableCommit
    }
    import_queue = [ordered]@{
        expected_output_count = $expectedPaths.Count
        initial_pending_count = $initialQueueLength
        maximum_pending_count = $maximumQueueLength
        final_pending_count = $finalQueueLength
        queue_zero_at_normal_exit = (-not $timedOut -and $exitCode -eq 0 -and $finalQueueLength -eq 0)
    }
    import_cache = [ordered]@{
        imported_file_count = $manifest.Count
        imported_manifest_fingerprint_sha256 = $manifestFingerprint
        class_cache_present = Test-Path -LiteralPath $classCachePath
        class_cache_sha256 = if (Test-Path -LiteralPath $classCachePath) {Get-Sha256 $classCachePath} else {$null}
    }
    error_counts = [ordered]@{
        memory_allocation_mem_null_count = @([regex]::Matches($combinedLog, 'Parameter "mem" is null')).Count
        memory_allocation_mem_new_null_count = @([regex]::Matches($combinedLog, 'Parameter "mem_new" is null')).Count
        fatal_copy_on_write_count = @([regex]::Matches($combinedLog, 'FATAL: Condition "_copy_on_write\(\)" is true')).Count
        unable_to_create_local_rendering_device_count = @([regex]::Matches($combinedLog, 'Unable to create a local RenderingDevice')).Count
        import_error_count = @([regex]::Matches($combinedLog, 'ERROR: Error importing')).Count
        script_error_count = @([regex]::Matches($combinedLog, 'SCRIPT ERROR:')).Count
    }
    git_state = [ordered]@{
        status_before_count = $statusBefore.Count
        status_after_count = $statusAfter.Count
        index_change_count = $indexAfter.Count
        tracked_delta_count = $trackedAfter.Count
        tracked_import_delta_count = $trackedImportAfter.Count
        untracked_count = $untrackedAfter.Count
        untracked_uid_count = $untrackedUidAfter.Count
        unexpected_untracked_count = $unexpectedUntrackedAfter.Count
        tracked_delta_paths = @($trackedAfter | ForEach-Object {$_.Substring(3)})
        untracked_uid_paths = @($untrackedUidAfter | ForEach-Object {$_.Substring(3)})
    }
    raw_logs = [ordered]@{
        stdout_external_path = $stdoutPath
        stdout_sha256 = Get-Sha256 $stdoutPath
        stderr_external_path = $stderrPath
        stderr_sha256 = Get-Sha256 $stderrPath
        engine_log_external_path = $engineLogPath
        engine_log_sha256 = Get-Sha256 $engineLogPath
    }
}

$repoOutputRoot = Join-Path $root "reports/reuse/full_convergence/generation10/canonical_import_terminal_repair_001/$PassId"
[System.IO.Directory]::CreateDirectory($repoOutputRoot) | Out-Null
$manifestPath = Join-Path $repoOutputRoot "imported_manifest.json"
$reportPath = Join-Path $repoOutputRoot "canonical_import_report.json"
Write-Utf8 $manifestPath (($manifest | ConvertTo-Json -Depth 8) + "`n")
$report.import_cache.imported_manifest_path = [System.IO.Path]::GetRelativePath($root, $manifestPath).Replace("\", "/")
$report.import_cache.imported_manifest_sha256 = Get-Sha256 $manifestPath
Write-Utf8 $reportPath (($report | ConvertTo-Json -Depth 30) + "`n")
Write-Utf8 ($manifestPath + ".sha256") ((Get-Sha256 $manifestPath) + "  imported_manifest.json`n")
Write-Utf8 ($reportPath + ".sha256") ((Get-Sha256 $reportPath) + "  canonical_import_report.json`n")

if (@($report.error_counts.Values | Where-Object { $_ -ne 0 }).Count -ne 0) { $report.status = "FAIL"; Write-Utf8 $reportPath (($report | ConvertTo-Json -Depth 30) + "`n"); Write-Utf8 ($reportPath + ".sha256") ((Get-Sha256 $reportPath) + "  canonical_import_report.json`n") }
$report | ConvertTo-Json -Depth 8
if ($report.status -ne "PASS") {
    exit 65
}
