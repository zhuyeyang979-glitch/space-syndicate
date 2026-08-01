[CmdletBinding()]
param(
    [string]$GodotPath = "",
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
)

$ErrorActionPreference = "Stop"
$ExpectedV7FileCount = 107
$ExpectedV7ByteCount = [int64]271918
$ExpectedV7LedgerSha256 = "607f1a15d875321a368ab071b35693857d7acf32063b4ed5578fa4f4aea9f826"
$MonsterReplayCodeHead = "85776d9bbc4f028816bf2b49a73cd223ee43b284"
$MonsterReplayResultHead = "f15fbaa96a12043513c5ced198079cb3c2ad11e8"
$MonsterReplayClaimSha256 = "7f3a294be80f822be30e14ec69e21fbcc5e269b8faab720a72d8d98c99a2cc42"
$MonsterReplayAdmissionSha256 = "2b41d27ed2ef9c54fb4e093ff431256088799b3979e56852b18904eca8cbe376"

function Assert-Condition {
    param([bool]$Condition, [string]$Reason)
    if (-not $Condition) { throw $Reason }
}

function Get-Sha256Text {
    param([string]$Text)
    $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [Convert]::ToHexString($sha.ComputeHash($bytes)).ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Get-DirectoryAttestation {
    param([string]$Root)
    $resolvedRoot = [IO.Path]::GetFullPath($Root)
    $files = @(Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File | Sort-Object FullName)
    $rows = @(foreach ($file in $files) {
        [ordered]@{
            relative_path = [IO.Path]::GetRelativePath($resolvedRoot, $file.FullName).Replace("\", "/")
            size = [int64]$file.Length
            sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    })
    $manifest = ConvertTo-Json -InputObject $rows -Compress -Depth 4 -AsArray
    return [ordered]@{
        file_count = [int]$files.Count
        byte_count = [int64](($files | Measure-Object Length -Sum).Sum)
        tree_fingerprint = Get-Sha256Text -Text $manifest
    }
}

function Write-JsonFile {
    param([string]$Path, $Value)
    [IO.Directory]::CreateDirectory((Split-Path -Parent $Path)) | Out-Null
    $json = (ConvertTo-Json -InputObject $Value -Depth 12) + [Environment]::NewLine
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($json)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length); $stream.Flush($true) }
    finally { $stream.Dispose() }
}

function Resolve-GodotConsolePath {
    param([string]$RequestedPath)
    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        return [IO.Path]::GetFullPath($RequestedPath)
    }
    $candidates = @()
    if (-not [string]::IsNullOrWhiteSpace($env:GODOT4_CONSOLE)) { $candidates += $env:GODOT4_CONSOLE }
    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        $candidates += (Join-Path $env:LOCALAPPDATA "Programs/Godot/4.7/Godot_v4.7-stable_win64_console.exe")
    }
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return [IO.Path]::GetFullPath($candidate) }
    }
    foreach ($commandName in @("godot4", "godot")) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue
        if ($null -ne $command) { return [IO.Path]::GetFullPath($command.Source) }
    }
    throw "godot_console_missing"
}

$projectFull = [IO.Path]::GetFullPath($ProjectPath)
$GodotPath = Resolve-GodotConsolePath -RequestedPath $GodotPath
$evidenceFull = Join-Path $projectFull "reports/handoffs/alpha04c_remaining_index_10_18_owner_closed_data_preflight.json"
$parentFull = Join-Path $projectFull "reports/handoffs/alpha04c_remaining_index_10_18_owner_closed_data_preflight_parent_attestation.json"
$priorChildPath = Join-Path $projectFull "reports/handoffs/alpha04c_remaining_11_owner_closed_data_preflight.json"
$priorParentPath = Join-Path $projectFull "reports/handoffs/alpha04c_remaining_11_owner_closed_data_preflight_parent_attestation.json"
$monsterChildPath = Join-Path $projectFull "reports/handoffs/alpha04c_monster_runtime_save_v2_replay_v1.json"
$monsterParentPath = Join-Path $projectFull "reports/handoffs/alpha04c_monster_runtime_save_v2_replay_v1_parent_attestation.json"

Assert-Condition (Test-Path -LiteralPath $GodotPath -PathType Leaf) "godot_console_missing"
Assert-Condition (-not (Test-Path -LiteralPath $evidenceFull) -and -not (Test-Path -LiteralPath $parentFull)) "remaining_index_10_18_preflight_evidence_already_exists"
foreach ($requiredPath in @($priorChildPath, $priorParentPath, $monsterChildPath, $monsterParentPath)) {
    Assert-Condition (Test-Path -LiteralPath $requiredPath -PathType Leaf) "remaining_index_10_18_preflight_prerequisite_evidence_missing"
}
Assert-Condition (@(Get-Process | Where-Object { $_.ProcessName -like "Godot*" }).Count -eq 0) "preexisting_godot_process_detected"

$priorChild = Get-Content -LiteralPath $priorChildPath -Raw | ConvertFrom-Json
$priorParent = Get-Content -LiteralPath $priorParentPath -Raw | ConvertFrom-Json
$priorOwnerEight = @($priorChild.owner_results | Where-Object { [int]$_.owner_index -eq 8 })
Assert-Condition (
    $priorOwnerEight.Count -eq 1 `
        -and [bool]$priorOwnerEight[0].payload_closed_data `
        -and [int]$priorOwnerEight[0].capture_mutation_count -eq 0 `
        -and [int]$priorOwnerEight[0].rng_draw_delta -eq 0 `
        -and [int]$priorOwnerEight[0].world_time_delta -eq 0 `
        -and [int]$priorOwnerEight[0].public_log_delta -eq 0 `
        -and [int]$priorOwnerEight[0].private_feedback_delta -eq 0 `
        -and [bool]$priorParent.parent_execution_attestation_green
) "player_organization_preflight_not_green"

$monsterChild = Get-Content -LiteralPath $monsterChildPath -Raw | ConvertFrom-Json
$monsterParent = Get-Content -LiteralPath $monsterParentPath -Raw | ConvertFrom-Json
Assert-Condition (
    [bool]$monsterChild.success `
        -and [string]$monsterChild.repository_head -ceq $MonsterReplayCodeHead `
        -and [bool]$monsterChild.monster_runtime_save_v2_replay_green `
        -and [bool]$monsterChild.monster_runtime_payload_closed `
        -and [bool]$monsterChild.monster_runtime_restore_parity `
        -and [int]$monsterChild.monster_runtime_capture_mutation_count -eq 0 `
        -and [bool]$monsterParent.parent_attestation_green
) "monster_runtime_replay_v1_not_green"

$repositoryHead = (& git -C $projectFull rev-parse HEAD).Trim().ToLowerInvariant()
$branch = (& git -C $projectFull branch --show-current).Trim()
$dirtyPaths = @(& git -C $projectFull status --porcelain)
$diffCheck = @(& git -C $projectFull diff --check 2>&1)
Assert-Condition ($LASTEXITCODE -eq 0 -and $diffCheck.Count -eq 0) "remaining_index_10_18_preflight_diff_check_failed"
Assert-Condition ($repositoryHead -cmatch "^[0-9a-f]{40}$" -and $dirtyPaths.Count -eq 0) "remaining_index_10_18_preflight_tree_not_clean"
$remoteHead = (& git -C $projectFull rev-parse "refs/remotes/origin/$branch" 2>$null).Trim().ToLowerInvariant()
Assert-Condition ($LASTEXITCODE -eq 0 -and $remoteHead -ceq $repositoryHead) "remaining_index_10_18_preflight_remote_checkpoint_mismatch"
& git -C $projectFull merge-base --is-ancestor $MonsterReplayResultHead $repositoryHead
Assert-Condition ($LASTEXITCODE -eq 0) "monster_runtime_replay_result_head_not_ancestor"
& git -C $projectFull merge-base --is-ancestor $MonsterReplayResultHead "origin/codex/alpha04c-save-resume-cold-restore-5b8601b"
Assert-Condition ($LASTEXITCODE -eq 0) "pr77_missing_monster_runtime_replay_result"

$gitCommonRaw = (& git -C $projectFull rev-parse --git-common-dir).Trim()
$gitCommon = if ([IO.Path]::IsPathRooted($gitCommonRaw)) { [IO.Path]::GetFullPath($gitCommonRaw) } else { [IO.Path]::GetFullPath((Join-Path $projectFull $gitCommonRaw)) }
$v7Root = Join-Path $gitCommon "codex/cold_restore_v3/non-official-alpha04c-owner-capture-diagnostic-v7-registry-contract"
$v8Root = Join-Path $gitCommon "codex/cold_restore_v3/non-official-alpha04c-owner-capture-diagnostic-v8-all-owner-closed-wire"
$monsterReplayRoot = Join-Path $gitCommon "codex/cold_restore_v3/non-official-alpha04c-monster-runtime-replay-v1"
$v7LedgerPath = Join-Path $v7Root "targeted_owner_capture_quota_ledger.json"
$monsterClaimPath = Join-Path $monsterReplayRoot "replay_attempt_claim.json"
$monsterAdmissionPath = Join-Path $monsterReplayRoot "replay_child_admission_consumed.json"
$v7Before = Get-DirectoryAttestation -Root $v7Root
$monsterReplayBefore = Get-DirectoryAttestation -Root $monsterReplayRoot
$v7LedgerBefore = (Get-FileHash -LiteralPath $v7LedgerPath -Algorithm SHA256).Hash.ToLowerInvariant()
Assert-Condition ($v7Before.file_count -eq $ExpectedV7FileCount -and $v7Before.byte_count -eq $ExpectedV7ByteCount -and $v7LedgerBefore -ceq $ExpectedV7LedgerSha256) "immutable_v7_evidence_precondition_mismatch"
Assert-Condition ($monsterReplayBefore.file_count -eq 2 -and $monsterReplayBefore.byte_count -eq 917) "immutable_monster_replay_evidence_precondition_mismatch"
Assert-Condition ((Get-FileHash -LiteralPath $monsterClaimPath -Algorithm SHA256).Hash.ToLowerInvariant() -ceq $MonsterReplayClaimSha256) "monster_replay_claim_mismatch"
Assert-Condition ((Get-FileHash -LiteralPath $monsterAdmissionPath -Algorithm SHA256).Hash.ToLowerInvariant() -ceq $MonsterReplayAdmissionSha256) "monster_replay_consumed_admission_mismatch"
Assert-Condition (-not (Test-Path -LiteralPath (Join-Path $monsterReplayRoot "replay_child_admission.json"))) "monster_replay_unconsumed_admission_exists"
Assert-Condition (-not (Test-Path -LiteralPath $v8Root)) "v8_root_exists_before_authorization"

$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$tempRoot = Join-Path $tempBase ("space-syndicate-alpha04c-remaining-index-10-18-preflight-" + [Guid]::NewGuid().ToString("N"))
$appData = Join-Path $tempRoot "appdata"
$localAppData = Join-Path $tempRoot "localappdata"
[IO.Directory]::CreateDirectory($appData) | Out-Null
[IO.Directory]::CreateDirectory($localAppData) | Out-Null

$process = $null
$childExitCode = -1
try {
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $GodotPath
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.WorkingDirectory = $projectFull
    $startInfo.Environment["APPDATA"] = $appData
    $startInfo.Environment["LOCALAPPDATA"] = $localAppData
    foreach ($argument in @(
        "--headless", "--path", $projectFull, "--script",
        "res://scripts/tools/alpha04c_remaining_index_10_18_owner_closed_data_preflight.gd",
        "--", "--evidence-output=$evidenceFull", "--repository-head=$repositoryHead"
    )) { $startInfo.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    Assert-Condition ($process.Start()) "remaining_index_10_18_preflight_launch_failed"
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(120000)) {
        $process.Kill($true)
        $process.WaitForExit()
        throw "remaining_index_10_18_preflight_timeout"
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $childExitCode = $process.ExitCode
    Assert-Condition (Test-Path -LiteralPath $evidenceFull -PathType Leaf) "remaining_index_10_18_preflight_child_evidence_missing"
    $child = Get-Content -LiteralPath $evidenceFull -Raw | ConvertFrom-Json
    $v7After = Get-DirectoryAttestation -Root $v7Root
    $monsterReplayAfter = Get-DirectoryAttestation -Root $monsterReplayRoot
    $v7LedgerAfter = (Get-FileHash -LiteralPath $v7LedgerPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $v7Immutable = $v7Before.file_count -eq $v7After.file_count `
        -and $v7Before.byte_count -eq $v7After.byte_count `
        -and $v7Before.tree_fingerprint -ceq $v7After.tree_fingerprint `
        -and $v7LedgerBefore -ceq $v7LedgerAfter
    $monsterReplayImmutable = $monsterReplayBefore.file_count -eq $monsterReplayAfter.file_count `
        -and $monsterReplayBefore.byte_count -eq $monsterReplayAfter.byte_count `
        -and $monsterReplayBefore.tree_fingerprint -ceq $monsterReplayAfter.tree_fingerprint
    $v8Absent = -not (Test-Path -LiteralPath $v8Root)
    $taskOwnedProcessCountAfter = @(Get-Process | Where-Object { $_.ProcessName -like "Godot*" }).Count
    $outcomeValid = [bool]$child.scenario_identity_attested `
        -and [bool]$child.registry_binding_attested `
        -and [bool]$child.prior_player_organization_preflight_green `
        -and [bool]$child.repaired_monster_runtime_replay_green `
        -and [int]$child.targeted_owner_capture_diagnostic_count_before -eq 7 `
        -and [int]$child.targeted_owner_capture_diagnostic_count_after -eq 7 `
        -and [int]$child.preflight_diagnostic_count_delta -eq 0 `
        -and [int]$child.preflight_quota_claim_count -eq 0 `
        -and [int]$child.preflight_full_owner_audit_count -eq 0 `
        -and [int]$child.preflight_production_fixed_slot_write_count -eq 0 `
        -and [int]$child.preflight_process_a_count -eq 0 `
        -and -not [bool]$child.v8_authorization_created `
        -and -not [bool]$child.v8_run_id_created `
        -and [bool]$child.private_payload_redacted `
        -and (
            ($childExitCode -eq 0 -and [bool]$child.success -and [int]$child.new_remaining_owner_preflight_count -eq 9 -and [int]$child.total_remaining_owner_preflight_green_count -eq 11) `
            -or ($childExitCode -eq 2 -and -not [bool]$child.success -and [int]$child.first_remaining_owner_failure_index -ge 10)
        )
    $executionGreen = $outcomeValid -and $v7Immutable -and $monsterReplayImmutable -and $v8Absent -and $taskOwnedProcessCountAfter -eq 0
    $parent = [ordered]@{
        schema_version = 1
        preflight_id = [string]$child.preflight_id
        repository_head = $repositoryHead
        child_exit_code = [int]$childExitCode
        child_result_sha256 = (Get-FileHash -LiteralPath $evidenceFull -Algorithm SHA256).Hash.ToLowerInvariant()
        child_success = [bool]$child.success
        new_remaining_owner_preflight_count = [int]$child.new_remaining_owner_preflight_count
        new_remaining_owner_preflight_green_count = [int]$child.new_remaining_owner_preflight_green_count
        total_remaining_owner_preflight_count = [int]$child.total_remaining_owner_preflight_count
        total_remaining_owner_preflight_green_count = [int]$child.total_remaining_owner_preflight_green_count
        first_remaining_owner_failure_index = [int]$child.first_remaining_owner_failure_index
        first_remaining_owner_failure_id = [string]$child.first_remaining_owner_failure_id
        first_remaining_owner_failure_reason = [string]$child.first_remaining_owner_failure_reason
        immutable_v7_evidence_preserved = [bool]$v7Immutable
        immutable_monster_replay_evidence_preserved = [bool]$monsterReplayImmutable
        v8_authorization_root_absent = [bool]$v8Absent
        preflight_diagnostic_count_delta = 0
        preflight_quota_claim_count = 0
        preflight_full_owner_audit_count = 0
        preflight_production_fixed_slot_write_count = 0
        preflight_process_a_count = 0
        task_owned_process_count_after = [int]$taskOwnedProcessCountAfter
        parent_execution_attestation_green = [bool]$executionGreen
        private_payload_redacted = $true
    }
    Write-JsonFile -Path $parentFull -Value $parent
    Assert-Condition $executionGreen "remaining_index_10_18_preflight_parent_attestation_failed"
    [Console]::Out.WriteLine("ALPHA04C_REMAINING_INDEX_10_18_OWNER_PREFLIGHT_PARENT|" + (ConvertTo-Json -InputObject $parent -Compress -Depth 8))
    exit $childExitCode
}
finally {
    if ($null -ne $process) {
        try {
            if (-not $process.HasExited) { $process.Kill($true); $process.WaitForExit() }
        }
        catch { }
        finally { $process.Dispose() }
    }
    $resolvedTempRoot = [IO.Path]::GetFullPath($tempRoot)
    if ($resolvedTempRoot.StartsWith($tempBase, [StringComparison]::OrdinalIgnoreCase) `
            -and (Split-Path -Leaf $resolvedTempRoot).StartsWith("space-syndicate-alpha04c-remaining-index-10-18-preflight-", [StringComparison]::Ordinal)) {
        Remove-Item -LiteralPath $resolvedTempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
