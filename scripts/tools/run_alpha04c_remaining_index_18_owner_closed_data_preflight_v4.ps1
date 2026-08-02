[CmdletBinding()]
param(
    [string]$GodotPath = "",
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
)

$ErrorActionPreference = "Stop"
$ExpectedV7FileCount = 107
$ExpectedV7ByteCount = [int64]271918
$ExpectedV7LedgerSha256 = "607f1a15d875321a368ab071b35693857d7acf32063b4ed5578fa4f4aea9f826"
$ExpectedAttemptV3FileCount = 3
$ExpectedAttemptV3ByteCount = [int64]1956
$ExpectedAttemptV3TreeFingerprint = "4ce5aab7f70871bf61f2b6612bb40ad9786800cbe2d31c021a3a60d087b8a2a9"
$ExpectedVictoryReplayFileCount = 2
$ExpectedVictoryReplayByteCount = [int64]917
$ExpectedVictoryReplayTreeFingerprint = "85582a789ae4fde3b00908a32beb85ece9ae86a8311e4d9115fe8a3b397fd57b"
$AttemptId = "alpha04c-remaining-owner-preflight-index18-attempt-v4"

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

function Write-ExclusiveJsonFile {
    param([string]$Path, $Value)
    [IO.Directory]::CreateDirectory((Split-Path -Parent $Path)) | Out-Null
    $json = (ConvertTo-Json -InputObject $Value -Depth 16) + [Environment]::NewLine
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($json)
    $stream = [IO.FileStream]::new($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length); $stream.Flush($true) }
    finally { $stream.Dispose() }
}

function Test-ExactJsonInt64 {
    param($Value, [long]$Expected)
    return $null -ne $Value -and $Value.GetType() -eq [long] -and [long]$Value -eq $Expected
}

function Test-ExactPropertySet {
    param($Value, [string[]]$Expected)
    $actual = @($Value.PSObject.Properties.Name)
    if ($actual.Count -ne $Expected.Count) { return $false }
    foreach ($field in $Expected) {
        if ($actual -cnotcontains $field) { return $false }
    }
    return $true
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
$evidenceFull = Join-Path $projectFull "reports/handoffs/alpha04c_remaining_owner_preflight_index18_attempt_v4.json"
$parentFull = Join-Path $projectFull "reports/handoffs/alpha04c_remaining_owner_preflight_index18_attempt_v4_parent_attestation.json"
$authorizationPath = Join-Path $projectFull "scripts/tools/remaining_owner_closed_data_preflight_attempt_v4_authorization.json"
$priorAttemptChildPath = Join-Path $projectFull "reports/handoffs/alpha04c_remaining_owner_preflight_index16_18_attempt_v3.json"
$priorAttemptParentPath = Join-Path $projectFull "reports/handoffs/alpha04c_remaining_owner_preflight_index16_18_attempt_v3_parent_attestation.json"
$victoryReplayChildPath = Join-Path $projectFull "reports/handoffs/alpha04c_victory_control_owner_replay_v1.json"
$victoryReplayParentPath = Join-Path $projectFull "reports/handoffs/alpha04c_victory_control_owner_replay_v1_parent_attestation.json"

Assert-Condition (Test-Path -LiteralPath $GodotPath -PathType Leaf) "godot_console_missing"
Assert-Condition (Test-Path -LiteralPath $authorizationPath -PathType Leaf) "remaining_owner_preflight_attempt_v4_authorization_missing"
Assert-Condition (-not (Test-Path -LiteralPath $evidenceFull) -and -not (Test-Path -LiteralPath $parentFull)) "remaining_owner_preflight_attempt_v4_evidence_already_exists"
Assert-Condition (@(Get-Process | Where-Object { $_.ProcessName -like "Godot*" }).Count -eq 0) "preexisting_godot_process_detected"

$authorization = Get-Content -LiteralPath $authorizationPath -Raw | ConvertFrom-Json
Assert-Condition (
    (Test-ExactPropertySet -Value $authorization -Expected @(
        "schema_version", "contract_id", "attempt_id", "start_index", "end_index",
        "qualified_prior_owner_count", "attempt_count_before", "authorized_new_attempt_count",
        "attempt_count_after", "targeted_owner_capture_diagnostic_count_before",
        "targeted_owner_capture_diagnostic_count_after", "prior_attempt_v3_child_sha256",
        "prior_attempt_v3_parent_sha256", "victory_replay_child_sha256",
        "victory_replay_parent_sha256", "victory_replay_evidence_commit",
        "pr77_victory_merge_commit"
    )) `
        -and (Test-ExactJsonInt64 -Value $authorization.schema_version -Expected 1) `
        -and [string]$authorization.contract_id -ceq "RemainingOwnerClosedDataPreflightAttemptV4Authorization" `
        -and [string]$authorization.attempt_id -ceq $AttemptId `
        -and (Test-ExactJsonInt64 -Value $authorization.start_index -Expected 18) `
        -and (Test-ExactJsonInt64 -Value $authorization.end_index -Expected 18) `
        -and (Test-ExactJsonInt64 -Value $authorization.qualified_prior_owner_count -Expected 10) `
        -and (Test-ExactJsonInt64 -Value $authorization.attempt_count_before -Expected 0) `
        -and (Test-ExactJsonInt64 -Value $authorization.authorized_new_attempt_count -Expected 1) `
        -and (Test-ExactJsonInt64 -Value $authorization.attempt_count_after -Expected 1) `
        -and (Test-ExactJsonInt64 -Value $authorization.targeted_owner_capture_diagnostic_count_before -Expected 7) `
        -and (Test-ExactJsonInt64 -Value $authorization.targeted_owner_capture_diagnostic_count_after -Expected 7)
) "remaining_owner_preflight_attempt_v4_authorization_invalid"

foreach ($path in @($priorAttemptChildPath, $priorAttemptParentPath, $victoryReplayChildPath, $victoryReplayParentPath)) {
    Assert-Condition (Test-Path -LiteralPath $path -PathType Leaf) "remaining_owner_preflight_v4_prerequisite_evidence_missing"
}
Assert-Condition ((Get-FileHash -LiteralPath $priorAttemptChildPath -Algorithm SHA256).Hash.ToLowerInvariant() -ceq [string]$authorization.prior_attempt_v3_child_sha256) "prior_attempt_v3_child_hash_mismatch"
Assert-Condition ((Get-FileHash -LiteralPath $priorAttemptParentPath -Algorithm SHA256).Hash.ToLowerInvariant() -ceq [string]$authorization.prior_attempt_v3_parent_sha256) "prior_attempt_v3_parent_hash_mismatch"
Assert-Condition ((Get-FileHash -LiteralPath $victoryReplayChildPath -Algorithm SHA256).Hash.ToLowerInvariant() -ceq [string]$authorization.victory_replay_child_sha256) "victory_replay_child_hash_mismatch"
Assert-Condition ((Get-FileHash -LiteralPath $victoryReplayParentPath -Algorithm SHA256).Hash.ToLowerInvariant() -ceq [string]$authorization.victory_replay_parent_sha256) "victory_replay_parent_hash_mismatch"

$priorChild = Get-Content -LiteralPath $priorAttemptChildPath -Raw | ConvertFrom-Json
$priorParent = Get-Content -LiteralPath $priorAttemptParentPath -Raw | ConvertFrom-Json
Assert-Condition (
    -not [bool]$priorChild.success `
        -and [int]$priorChild.total_remaining_owner_preflight_count -eq 10 `
        -and [int]$priorChild.total_remaining_owner_preflight_green_count -eq 9 `
        -and [int]$priorChild.first_remaining_owner_failure_index -eq 17 `
        -and [string]$priorChild.first_remaining_owner_failure_id -ceq "victory_control" `
        -and [bool]$priorParent.parent_attestation_green
) "prior_attempt_v3_evidence_invalid"

$victoryReplayChild = Get-Content -LiteralPath $victoryReplayChildPath -Raw | ConvertFrom-Json
$victoryReplayParent = Get-Content -LiteralPath $victoryReplayParentPath -Raw | ConvertFrom-Json
Assert-Condition (
    [bool]$victoryReplayChild.success `
        -and [bool]$victoryReplayChild.victory_save_v3_replay_green `
        -and [bool]$victoryReplayChild.victory_payload_closed `
        -and [bool]$victoryReplayChild.victory_restore_parity `
        -and [bool]$victoryReplayChild.victory_fresh_world_facts_gate_green `
        -and [bool]$victoryReplayChild.victory_exact_once_green `
        -and [int]$victoryReplayChild.targeted_owner_capture_diagnostic_count_after -eq 7 `
        -and [bool]$victoryReplayParent.parent_attestation_green
) "victory_control_replay_v1_not_green"

$repositoryHead = (& git -C $projectFull rev-parse HEAD).Trim().ToLowerInvariant()
$branch = (& git -C $projectFull branch --show-current).Trim()
$dirtyPaths = @(& git -C $projectFull status --porcelain)
$diffCheck = @(& git -C $projectFull diff --check 2>&1)
Assert-Condition ($LASTEXITCODE -eq 0 -and $diffCheck.Count -eq 0) "remaining_owner_preflight_attempt_v4_diff_check_failed"
Assert-Condition ($repositoryHead -cmatch "^[0-9a-f]{40}$" -and $dirtyPaths.Count -eq 0) "remaining_owner_preflight_attempt_v4_tree_not_clean"
Assert-Condition ($branch -ceq "codex/alpha04c-save-resume-cold-restore-5b8601b") "remaining_owner_preflight_attempt_v4_branch_invalid"
$remoteHead = (& git -C $projectFull rev-parse "refs/remotes/origin/$branch" 2>$null).Trim().ToLowerInvariant()
Assert-Condition ($LASTEXITCODE -eq 0 -and $remoteHead -ceq $repositoryHead) "remaining_owner_preflight_attempt_v4_remote_checkpoint_mismatch"
& git -C $projectFull merge-base --is-ancestor ([string]$authorization.victory_replay_evidence_commit) $repositoryHead
Assert-Condition ($LASTEXITCODE -eq 0) "victory_replay_evidence_not_ancestor"
& git -C $projectFull merge-base --is-ancestor ([string]$authorization.pr77_victory_merge_commit) $repositoryHead
Assert-Condition ($LASTEXITCODE -eq 0) "pr77_victory_merge_not_ancestor"

$gitCommonRaw = (& git -C $projectFull rev-parse --git-common-dir).Trim()
$gitCommon = if ([IO.Path]::IsPathRooted($gitCommonRaw)) { [IO.Path]::GetFullPath($gitCommonRaw) } else { [IO.Path]::GetFullPath((Join-Path $projectFull $gitCommonRaw)) }
$v7Root = Join-Path $gitCommon "codex/cold_restore_v3/non-official-alpha04c-owner-capture-diagnostic-v7-registry-contract"
$v8Root = Join-Path $gitCommon "codex/cold_restore_v3/non-official-alpha04c-owner-capture-diagnostic-v8-all-owner-closed-wire"
$v7LedgerPath = Join-Path $v7Root "targeted_owner_capture_quota_ledger.json"
$attemptV3Root = Join-Path $gitCommon "codex/cold_restore_v3/non-official-alpha04c-remaining-owner-preflight-index16-18-attempt-v3"
$victoryReplayRoot = Join-Path $gitCommon "codex/cold_restore_v3/non-official-alpha04c-victory-control-replay-v1"
$attemptRoot = Join-Path $gitCommon "codex/cold_restore_v3/non-official-alpha04c-remaining-owner-preflight-index18-attempt-v4"
$claimPath = Join-Path $attemptRoot "preflight_attempt_claim.json"
$admissionPath = Join-Path $attemptRoot "preflight_child_admission.json"
$consumedPath = Join-Path $attemptRoot "preflight_child_admission_consumed.json"
$ledgerPath = Join-Path $attemptRoot "remaining_owner_preflight_attempt_ledger.json"
$v7Before = Get-DirectoryAttestation -Root $v7Root
$v7LedgerBefore = (Get-FileHash -LiteralPath $v7LedgerPath -Algorithm SHA256).Hash.ToLowerInvariant()
$attemptV3Before = Get-DirectoryAttestation -Root $attemptV3Root
$victoryReplayBefore = Get-DirectoryAttestation -Root $victoryReplayRoot
Assert-Condition ($v7Before.file_count -eq $ExpectedV7FileCount -and $v7Before.byte_count -eq $ExpectedV7ByteCount -and $v7LedgerBefore -ceq $ExpectedV7LedgerSha256) "immutable_v7_evidence_precondition_mismatch"
Assert-Condition ($attemptV3Before.file_count -eq $ExpectedAttemptV3FileCount -and $attemptV3Before.byte_count -eq $ExpectedAttemptV3ByteCount -and $attemptV3Before.tree_fingerprint -ceq $ExpectedAttemptV3TreeFingerprint) "immutable_attempt_v3_evidence_precondition_mismatch"
Assert-Condition ($victoryReplayBefore.file_count -eq $ExpectedVictoryReplayFileCount -and $victoryReplayBefore.byte_count -eq $ExpectedVictoryReplayByteCount -and $victoryReplayBefore.tree_fingerprint -ceq $ExpectedVictoryReplayTreeFingerprint) "immutable_victory_replay_evidence_precondition_mismatch"
Assert-Condition (-not (Test-Path -LiteralPath $v8Root)) "v8_root_exists_before_remaining_owner_preflight_v4"
Assert-Condition (-not (Test-Path -LiteralPath $attemptRoot)) "remaining_owner_preflight_attempt_v4_already_claimed"

$startedAt = [DateTimeOffset]::UtcNow.ToString("o")
$claim = [ordered]@{
    schema_version = 1
    claim_id = "RemainingOwnerClosedDataPreflightAttemptClaimV4"
    attempt_id = $AttemptId
    frozen_code_head = $repositoryHead
    start_index = 18
    end_index = 18
    attempt_count_before = 0
    authorized_new_attempt_count = 1
    attempt_count_after = 1
    started_at = $startedAt
    private_payload_redacted = $true
}
Write-ExclusiveJsonFile -Path $claimPath -Value $claim
$claimSha256 = (Get-FileHash -LiteralPath $claimPath -Algorithm SHA256).Hash.ToLowerInvariant()
$admission = [ordered]@{
    schema_version = 1
    admission_id = "RemainingOwnerClosedDataPreflightChildAdmissionV4"
    claim_sha256 = $claimSha256
    attempt_id = $AttemptId
    frozen_code_head = $repositoryHead
}
Write-ExclusiveJsonFile -Path $admissionPath -Value $admission

$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$tempRoot = Join-Path $tempBase ("space-syndicate-alpha04c-remaining-index-18-preflight-v4-" + [Guid]::NewGuid().ToString("N"))
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
        "res://scripts/tools/alpha04c_remaining_index_18_owner_closed_data_preflight_v4.gd",
        "--", "--evidence-output=$evidenceFull", "--repository-head=$repositoryHead",
        "--preflight-claim-path=$claimPath", "--preflight-claim-sha256=$claimSha256",
        "--preflight-admission-path=$admissionPath", "--preflight-consumed-path=$consumedPath"
    )) { $startInfo.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    Assert-Condition ($process.Start()) "remaining_owner_preflight_attempt_v4_launch_failed"
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(120000)) {
        $process.Kill($true)
        $process.WaitForExit()
        throw "remaining_owner_preflight_attempt_v4_timeout"
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $childExitCode = $process.ExitCode
    Assert-Condition (Test-Path -LiteralPath $evidenceFull -PathType Leaf) "remaining_owner_preflight_attempt_v4_child_evidence_missing"
    Assert-Condition ((Test-Path -LiteralPath $consumedPath -PathType Leaf) -and -not (Test-Path -LiteralPath $admissionPath)) "remaining_owner_preflight_attempt_v4_admission_not_consumed"
    $child = Get-Content -LiteralPath $evidenceFull -Raw | ConvertFrom-Json
    $ownerResults = @($child.owner_results)
    $row = $ownerResults[0]
    $rowValid = $ownerResults.Count -eq 1 `
        -and (Test-ExactPropertySet -Value $row -Expected @(
            "owner_index", "section_id", "owner_id", "capture_method", "payload_present",
            "payload_dictionary", "payload_nonempty", "payload_closed_data", "state_version",
            "ruleset_id", "leaf_count", "non_closed_leaf_count", "non_closed_type_counts",
            "first_non_closed_path", "first_non_closed_type", "capture_mutation_count",
            "rng_draw_delta", "world_time_delta", "public_log_delta", "private_feedback_delta",
            "reason_code", "checkpoint_method"
        )) `
        -and [int]$row.owner_index -eq 18 `
        -and [string]$row.section_id -ceq "session" `
        -and [string]$row.owner_id -ceq "game_session" `
        -and [string]$row.capture_method -ceq "to_save_data" `
        -and [string]$row.checkpoint_method -ceq "capture_runtime_checkpoint" `
        -and [int]$row.state_version -eq 3 `
        -and [bool]$row.payload_present `
        -and [bool]$row.payload_dictionary `
        -and [bool]$row.payload_nonempty `
        -and [bool]$row.payload_closed_data `
        -and [int]$row.non_closed_leaf_count -eq 0 `
        -and [int]$row.capture_mutation_count -eq 0 `
        -and [int]$row.rng_draw_delta -eq 0 `
        -and [int]$row.world_time_delta -eq 0 `
        -and [int]$row.public_log_delta -eq 0 `
        -and [int]$row.private_feedback_delta -eq 0 `
        -and [string]$row.reason_code -ceq "none"
    $successOutcome = $childExitCode -eq 0 `
        -and [bool]$child.success `
        -and [bool]$child.final_session_owner_preflight_green `
        -and [int]$child.new_remaining_owner_preflight_count -eq 1 `
        -and [int]$child.new_remaining_owner_preflight_green_count -eq 1 `
        -and [int]$child.total_remaining_owner_preflight_count -eq 11 `
        -and [int]$child.total_remaining_owner_preflight_green_count -eq 11 `
        -and [int]$child.remaining_owner_non_closed_leaf_count -eq 0 `
        -and [int]$child.remaining_owner_capture_mutation_count -eq 0
    $blockedOutcome = $childExitCode -eq 2 `
        -and -not [bool]$child.success `
        -and [int]$child.first_remaining_owner_failure_index -eq 18 `
        -and [string]$child.first_remaining_owner_failure_id -ceq "game_session"
    $v7After = Get-DirectoryAttestation -Root $v7Root
    $v7LedgerAfter = (Get-FileHash -LiteralPath $v7LedgerPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $attemptV3After = Get-DirectoryAttestation -Root $attemptV3Root
    $victoryReplayAfter = Get-DirectoryAttestation -Root $victoryReplayRoot
    $v7Immutable = $v7Before.file_count -eq $v7After.file_count `
        -and $v7Before.byte_count -eq $v7After.byte_count `
        -and $v7Before.tree_fingerprint -ceq $v7After.tree_fingerprint `
        -and $v7LedgerBefore -ceq $v7LedgerAfter
    $attemptV3Immutable = $attemptV3Before.file_count -eq $attemptV3After.file_count `
        -and $attemptV3Before.byte_count -eq $attemptV3After.byte_count `
        -and $attemptV3Before.tree_fingerprint -ceq $attemptV3After.tree_fingerprint
    $victoryReplayImmutable = $victoryReplayBefore.file_count -eq $victoryReplayAfter.file_count `
        -and $victoryReplayBefore.byte_count -eq $victoryReplayAfter.byte_count `
        -and $victoryReplayBefore.tree_fingerprint -ceq $victoryReplayAfter.tree_fingerprint `
        -and (Get-FileHash -LiteralPath $victoryReplayChildPath -Algorithm SHA256).Hash.ToLowerInvariant() -ceq [string]$authorization.victory_replay_child_sha256 `
        -and (Get-FileHash -LiteralPath $victoryReplayParentPath -Algorithm SHA256).Hash.ToLowerInvariant() -ceq [string]$authorization.victory_replay_parent_sha256
    $v8Absent = -not (Test-Path -LiteralPath $v8Root)
    $saveArtifacts = @(Get-ChildItem -LiteralPath $tempRoot -Recurse -File | Where-Object {
        $_.Name -like "*.save*" -or $_.Name -like "*.tmp*" -or $_.Name -like "*.backup*"
    })
    $taskOwnedProcessCountAfter = @(Get-Process | Where-Object { $_.ProcessName -like "Godot*" }).Count
    $outcomeValid = [string]$child.attempt_id -ceq $AttemptId `
        -and [string]$child.repository_head -ceq $repositoryHead `
        -and [bool]$child.attempt_child_admission_consumed `
        -and [bool]$child.scenario_identity_attested `
        -and [bool]$child.registry_binding_attested `
        -and [bool]$child.target_binding_attested `
        -and [bool]$child.victory_control_replay_v1_green `
        -and [int]$child.remaining_owner_preflight_attempt_count_delta -eq 1 `
        -and [int]$child.remaining_owner_preflight_concurrent_execution_count -eq 1 `
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
        -and $rowValid `
        -and ($successOutcome -or $blockedOutcome)
    $parentGreen = $outcomeValid -and $v7Immutable -and $attemptV3Immutable `
        -and $victoryReplayImmutable -and $v8Absent -and $saveArtifacts.Count -eq 0 `
        -and $taskOwnedProcessCountAfter -eq 0
    $childCompletionSha256 = (Get-FileHash -LiteralPath $evidenceFull -Algorithm SHA256).Hash.ToLowerInvariant()
    $completedAt = [DateTimeOffset]::UtcNow.ToString("o")
    $firstFailure = if ([bool]$child.success) { [ordered]@{} } else {
        [ordered]@{
            owner_index = [int]$child.first_remaining_owner_failure_index
            owner_id = [string]$child.first_remaining_owner_failure_id
            reason_code = [string]$child.first_remaining_owner_failure_reason
        }
    }
    $parentCore = [ordered]@{
        schema_version = 1
        attempt_id = $AttemptId
        frozen_code_head = $repositoryHead
        child_exit_code = [int]$childExitCode
        child_completion_sha256 = $childCompletionSha256
        child_success = [bool]$child.success
        child_attestation_green = [bool]$outcomeValid
        immutable_v7_evidence_preserved = [bool]$v7Immutable
        immutable_attempt_v3_evidence_preserved = [bool]$attemptV3Immutable
        immutable_victory_replay_evidence_preserved = [bool]$victoryReplayImmutable
        v8_authorization_root_absent = [bool]$v8Absent
        preflight_production_fixed_slot_write_count = [int]$saveArtifacts.Count
        remaining_owner_preflight_attempt_count_delta = 1
        remaining_owner_preflight_concurrent_execution_count = 1
        task_owned_process_count_after = [int]$taskOwnedProcessCountAfter
        first_failure = $firstFailure
        parent_attestation_green = [bool]$parentGreen
        private_payload_redacted = $true
    }
    $parentExitSha256 = Get-Sha256Text -Text (ConvertTo-Json -InputObject $parentCore -Compress -Depth 12)
    $ledger = [ordered]@{
        schema_version = 1
        contract_id = "RemainingOwnerClosedDataPreflightAttemptV4"
        attempt_id = $AttemptId
        frozen_code_head = $repositoryHead
        start_index = 18
        end_index = 18
        scenario_identity_fingerprint = [string]$child.scenario_identity_fingerprint
        registry_binding_fingerprint = [string]$child.registry_binding_fingerprint
        child_completion_sha256 = $childCompletionSha256
        parent_exit_sha256 = $parentExitSha256
        started_at = $startedAt
        completed_at = $completedAt
        status = if ([bool]$child.success) { "GREEN" } else { "BLOCKED" }
        first_failure = $firstFailure
        attempt_count_before = 0
        authorized_new_attempt_count = 1
        attempt_count_after = 1
        concurrent_execution_count = 1
        diagnostic_quota_claim_count = 0
        private_payload_redacted = $true
    }
    Write-ExclusiveJsonFile -Path $ledgerPath -Value $ledger
    $parent = [ordered]@{}
    foreach ($entry in $parentCore.GetEnumerator()) { $parent[$entry.Key] = $entry.Value }
    $parent["parent_exit_sha256"] = $parentExitSha256
    $parent["attempt_ledger_sha256"] = (Get-FileHash -LiteralPath $ledgerPath -Algorithm SHA256).Hash.ToLowerInvariant()
    Write-ExclusiveJsonFile -Path $parentFull -Value $parent
    Assert-Condition $parentGreen "remaining_owner_preflight_attempt_v4_parent_attestation_failed"
    [Console]::Out.WriteLine("ALPHA04C_REMAINING_INDEX_18_OWNER_PREFLIGHT_V4_PARENT|" + (ConvertTo-Json -InputObject $parent -Compress -Depth 12))
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
            -and (Split-Path -Leaf $resolvedTempRoot).StartsWith("space-syndicate-alpha04c-remaining-index-18-preflight-v4-", [StringComparison]::Ordinal)) {
        Remove-Item -LiteralPath $resolvedTempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
