[CmdletBinding()]
param(
    [string]$GodotPath = "C:\Users\zhuye\AppData\Local\Programs\Godot\4.7\Godot_v4.7-stable_win64_console.exe",
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path,
    [string]$EvidenceOutput = (Join-Path $ProjectPath "reports/handoffs/alpha04c_v7_card_inventory_save_v4_checkpoint_v2_replay.json"),
    [string]$ParentOutput = (Join-Path $ProjectPath "reports/handoffs/alpha04c_v7_card_inventory_save_v4_checkpoint_v2_parent_attestation.json")
)

$ErrorActionPreference = "Stop"
$ReplayRunId = "alpha04c-v7-card-inventory-save-v4-checkpoint-v2-replay"
$ExpectedV7FileCount = 107
$ExpectedV7ByteCount = [int64]271918
$ExpectedLedgerSha256 = "607f1a15d875321a368ab071b35693857d7acf32063b4ed5578fa4f4aea9f826"
$ExpectedPhaseSha256 = "eba66bdf8edc55071b862a6b1c9d1ab8073d130335408bcf76be9c373538b778"

function Get-Sha256Text {
    param([Parameter(Mandatory = $true)][string]$Text)
    $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return [Convert]::ToHexString($sha.ComputeHash($bytes)).ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Get-DirectoryAttestation {
    param([Parameter(Mandatory = $true)][string]$Root)
    $resolvedRoot = [IO.Path]::GetFullPath($Root)
    $files = @(Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File | Sort-Object FullName)
    $rows = @(
        foreach ($file in $files) {
            [ordered]@{
                relative_path = [IO.Path]::GetRelativePath($resolvedRoot, $file.FullName).Replace("\", "/")
                size = [int64]$file.Length
                sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            }
        }
    )
    $manifest = ConvertTo-Json -InputObject $rows -Compress -Depth 4 -AsArray
    [ordered]@{
        file_count = [int]$files.Count
        byte_count = [int64](($files | Measure-Object Length -Sum).Sum)
        tree_fingerprint = Get-Sha256Text -Text $manifest
    }
}

function Write-JsonFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Value
    )
    $directory = Split-Path -Parent $Path
    [IO.Directory]::CreateDirectory($directory) | Out-Null
    $json = ConvertTo-Json -InputObject $Value -Depth 12
    [IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
}

$projectFull = [IO.Path]::GetFullPath($ProjectPath)
$evidenceFull = [IO.Path]::GetFullPath($EvidenceOutput)
$parentFull = [IO.Path]::GetFullPath($ParentOutput)
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "godot_console_missing"
}
if ((Test-Path -LiteralPath $evidenceFull) -or (Test-Path -LiteralPath $parentFull)) {
    throw "replay_evidence_already_exists"
}
$preexistingGodot = @(Get-Process | Where-Object {
    $_.ProcessName -like "Godot*" -and $_.Path -eq [IO.Path]::GetFullPath($GodotPath)
})
if ($preexistingGodot.Count -ne 0) {
    throw "preexisting_godot_process_detected"
}

$gitCommonRaw = (& git -C $projectFull rev-parse --git-common-dir).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($gitCommonRaw)) {
    throw "git_common_directory_unavailable"
}
$gitCommon = if ([IO.Path]::IsPathRooted($gitCommonRaw)) {
    [IO.Path]::GetFullPath($gitCommonRaw)
}
else {
    [IO.Path]::GetFullPath((Join-Path $projectFull $gitCommonRaw))
}
$repositoryHead = (& git -C $projectFull rev-parse HEAD).Trim().ToLowerInvariant()
if ($LASTEXITCODE -ne 0 -or $repositoryHead -notmatch "^[0-9a-f]{40}$") {
    throw "repository_head_unavailable"
}

$v7Root = Join-Path $gitCommon "codex/cold_restore_v3/non-official-alpha04c-owner-capture-diagnostic-v7-registry-contract"
$ledgerPath = Join-Path $v7Root "targeted_owner_capture_quota_ledger.json"
$phasePath = Join-Path $v7Root "evidence/diagnostics/phase_events/0024.snapshot.json"
if (-not (Test-Path -LiteralPath $ledgerPath -PathType Leaf) -or -not (Test-Path -LiteralPath $phasePath -PathType Leaf)) {
    throw "immutable_v7_evidence_missing"
}

$v7Before = Get-DirectoryAttestation -Root $v7Root
$ledgerBefore = (Get-FileHash -LiteralPath $ledgerPath -Algorithm SHA256).Hash.ToLowerInvariant()
$phaseBefore = (Get-FileHash -LiteralPath $phasePath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($v7Before.file_count -ne $ExpectedV7FileCount `
        -or $v7Before.byte_count -ne $ExpectedV7ByteCount `
        -or $ledgerBefore -ne $ExpectedLedgerSha256 `
        -or $phaseBefore -ne $ExpectedPhaseSha256) {
    throw "immutable_v7_evidence_precondition_mismatch"
}

$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$tempRoot = Join-Path $tempBase ("space-syndicate-alpha04c-card-inventory-replay-" + [Guid]::NewGuid().ToString("N"))
$appData = Join-Path $tempRoot "appdata"
$localAppData = Join-Path $tempRoot "localappdata"
$stdoutPath = Join-Path $tempRoot "godot.stdout.log"
$stderrPath = Join-Path $tempRoot "godot.stderr.log"
[IO.Directory]::CreateDirectory($appData) | Out-Null
[IO.Directory]::CreateDirectory($localAppData) | Out-Null

$childExitCode = -1
$childProcessId = -1
$stdout = ""
$stderr = ""
try {
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = [IO.Path]::GetFullPath($GodotPath)
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.WorkingDirectory = $projectFull
    $startInfo.Environment["APPDATA"] = $appData
    $startInfo.Environment["LOCALAPPDATA"] = $localAppData
    $startInfo.ArgumentList.Add("--headless")
    $startInfo.ArgumentList.Add("--path")
    $startInfo.ArgumentList.Add($projectFull)
    $startInfo.ArgumentList.Add("--script")
    $startInfo.ArgumentList.Add("res://scripts/tools/alpha04c_v7_card_inventory_nonconsuming_replay.gd")
    $startInfo.ArgumentList.Add("--")
    $startInfo.ArgumentList.Add("--evidence-output=$evidenceFull")
    $startInfo.ArgumentList.Add("--repository-head=$repositoryHead")

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    if (-not $process.Start()) {
        throw "godot_replay_launch_failed"
    }
    $childProcessId = $process.Id
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $childExitCode = $process.ExitCode
    [IO.File]::WriteAllText($stdoutPath, $stdout, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($stderrPath, $stderr, [Text.UTF8Encoding]::new($false))
    $process.Dispose()

    if (-not (Test-Path -LiteralPath $evidenceFull -PathType Leaf)) {
        throw "replay_child_evidence_missing"
    }
    $childResult = Get-Content -LiteralPath $evidenceFull -Raw | ConvertFrom-Json
    $v7After = Get-DirectoryAttestation -Root $v7Root
    $ledgerAfter = (Get-FileHash -LiteralPath $ledgerPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $phaseAfter = (Get-FileHash -LiteralPath $phasePath -Algorithm SHA256).Hash.ToLowerInvariant()
    $taskOwnedProcessCountAfter = @(Get-Process -Id $childProcessId -ErrorAction SilentlyContinue).Count
    $godotVersion = if ($stdout -match "Godot Engine v([^\s]+)") { $Matches[1] } else { "unknown" }
    $immutable = $v7Before.file_count -eq $v7After.file_count `
        -and $v7Before.byte_count -eq $v7After.byte_count `
        -and $v7Before.tree_fingerprint -eq $v7After.tree_fingerprint `
        -and $ledgerBefore -eq $ledgerAfter `
        -and $phaseBefore -eq $phaseAfter

    $parent = [ordered]@{
        schema_version = 1
        replay_run_id = $ReplayRunId
        repository_head = $repositoryHead
        child_exit_code = [int]$childExitCode
        child_result_sha256 = (Get-FileHash -LiteralPath $evidenceFull -Algorithm SHA256).Hash.ToLowerInvariant()
        godot_version = $godotVersion
        isolated_appdata = $true
        isolated_localappdata = $true
        v7_evidence_file_count_before = [int]$v7Before.file_count
        v7_evidence_file_count_after = [int]$v7After.file_count
        v7_evidence_byte_count_before = [int64]$v7Before.byte_count
        v7_evidence_byte_count_after = [int64]$v7After.byte_count
        v7_evidence_tree_fingerprint_before = $v7Before.tree_fingerprint
        v7_evidence_tree_fingerprint_after = $v7After.tree_fingerprint
        v7_quota_ledger_sha256_before = $ledgerBefore
        v7_quota_ledger_sha256_after = $ledgerAfter
        v7_failure_phase_sha256_before = $phaseBefore
        v7_failure_phase_sha256_after = $phaseAfter
        immutable_v7_evidence_preserved = [bool]$immutable
        replay_diagnostic_count_delta = 0
        replay_quota_claim_count = 0
        replay_full_owner_audit_count = 0
        replay_production_fixed_slot_write_count = 0
        replay_process_a_count = 0
        task_owned_process_count_after = [int]$taskOwnedProcessCountAfter
        child_success = [bool]$childResult.success
        parent_attestation_green = [bool]($childExitCode -eq 0 -and $childResult.success -and $immutable -and $taskOwnedProcessCountAfter -eq 0)
        private_payload_redacted = $true
    }
    Write-JsonFile -Path $parentFull -Value $parent
    if (-not $parent.parent_attestation_green) {
        throw "v7_card_inventory_replay_parent_attestation_failed"
    }
    [Console]::Out.WriteLine("ALPHA04C_V7_CARD_INVENTORY_REPLAY_PARENT|" + (ConvertTo-Json -InputObject $parent -Compress -Depth 8))
}
finally {
    $resolvedTempRoot = [IO.Path]::GetFullPath($tempRoot)
    if ($resolvedTempRoot.StartsWith($tempBase, [StringComparison]::OrdinalIgnoreCase) `
            -and (Split-Path -Leaf $resolvedTempRoot).StartsWith("space-syndicate-alpha04c-card-inventory-replay-", [StringComparison]::Ordinal)) {
        Remove-Item -LiteralPath $resolvedTempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
