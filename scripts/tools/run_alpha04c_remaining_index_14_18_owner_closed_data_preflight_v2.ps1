[CmdletBinding()]
param(
    [string]$GodotPath = "",
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
)

$ErrorActionPreference = "Stop"
$ExpectedV7FileCount = 107
$ExpectedV7ByteCount = [int64]271918
$ExpectedV7LedgerSha256 = "607f1a15d875321a368ab071b35693857d7acf32063b4ed5578fa4f4aea9f826"
$ReplayV2ChildSha256 = "cc276abb07b33a78fc5e2905c677d58cb0b2f7712b2bce4aae40804e991099ee"
$ReplayV2ParentSha256 = "87cd286b6007da43fee2614a11478bfc7a04f7eb58da75f6fd7c544c97ac5a89"
$ReplayV2EvidenceCommit = "178e7f5936d93533f278e708d51e4b96d93d55f4"
$AttemptId = "alpha04c-remaining-owner-preflight-index14-18-attempt-v2"

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
$evidenceFull = Join-Path $projectFull "reports/handoffs/alpha04c_remaining_owner_preflight_index14_18_attempt_v2.json"
$parentFull = Join-Path $projectFull "reports/handoffs/alpha04c_remaining_owner_preflight_index14_18_attempt_v2_parent_attestation.json"
$authorizationPath = Join-Path $projectFull "scripts/tools/remaining_owner_closed_data_preflight_attempt_v2_authorization.json"
$replayChildPath = Join-Path $projectFull "reports/handoffs/alpha04c_card_resolution_execution_replay_v2_authoritative_parity.json"
$replayParentPath = Join-Path $projectFull "reports/handoffs/alpha04c_card_resolution_execution_replay_v2_authoritative_parity_parent_attestation.json"

Assert-Condition (Test-Path -LiteralPath $GodotPath -PathType Leaf) "godot_console_missing"
Assert-Condition (Test-Path -LiteralPath $authorizationPath -PathType Leaf) "remaining_owner_preflight_attempt_v2_authorization_missing"
Assert-Condition (-not (Test-Path -LiteralPath $evidenceFull) -and -not (Test-Path -LiteralPath $parentFull)) "remaining_owner_preflight_attempt_v2_evidence_already_exists"
Assert-Condition (@(Get-Process | Where-Object { $_.ProcessName -like "Godot*" }).Count -eq 0) "preexisting_godot_process_detected"

$authorization = Get-Content -LiteralPath $authorizationPath -Raw | ConvertFrom-Json
Assert-Condition (
    (Test-ExactPropertySet -Value $authorization -Expected @(
        "schema_version", "contract_id", "attempt_id", "start_index", "end_index",
        "attempt_count_before", "authorized_new_attempt_count", "attempt_count_after",
        "targeted_owner_capture_diagnostic_count_before", "targeted_owner_capture_diagnostic_count_after"
    )) `
        -and (Test-ExactJsonInt64 -Value $authorization.schema_version -Expected 1) `
        -and [string]$authorization.contract_id -ceq "RemainingOwnerClosedDataPreflightAttemptV2Authorization" `
        -and [string]$authorization.attempt_id -ceq $AttemptId `
        -and (Test-ExactJsonInt64 -Value $authorization.start_index -Expected 14) `
        -and (Test-ExactJsonInt64 -Value $authorization.end_index -Expected 18) `
        -and (Test-ExactJsonInt64 -Value $authorization.attempt_count_before -Expected 0) `
        -and (Test-ExactJsonInt64 -Value $authorization.authorized_new_attempt_count -Expected 1) `
        -and (Test-ExactJsonInt64 -Value $authorization.attempt_count_after -Expected 1) `
        -and (Test-ExactJsonInt64 -Value $authorization.targeted_owner_capture_diagnostic_count_before -Expected 7) `
        -and (Test-ExactJsonInt64 -Value $authorization.targeted_owner_capture_diagnostic_count_after -Expected 7)
) "remaining_owner_preflight_attempt_v2_authorization_invalid"

foreach ($path in @($replayChildPath, $replayParentPath)) {
    Assert-Condition (Test-Path -LiteralPath $path -PathType Leaf) "execution_replay_v2_evidence_missing"
}
Assert-Condition ((Get-FileHash -LiteralPath $replayChildPath -Algorithm SHA256).Hash.ToLowerInvariant() -ceq $ReplayV2ChildSha256) "execution_replay_v2_child_hash_mismatch"
Assert-Condition ((Get-FileHash -LiteralPath $replayParentPath -Algorithm SHA256).Hash.ToLowerInvariant() -ceq $ReplayV2ParentSha256) "execution_replay_v2_parent_hash_mismatch"
$replayChild = Get-Content -LiteralPath $replayChildPath -Raw | ConvertFrom-Json
$replayParent = Get-Content -LiteralPath $replayParentPath -Raw | ConvertFrom-Json
Assert-Condition (
    [bool]$replayChild.success `
        -and [bool]$replayChild.execution_replay_v2_authoritative_restore_parity `
        -and [bool]$replayChild.execution_replay_v2_exact_once_green `
        -and [bool]$replayChild.execution_replay_v2_payload_closed `
        -and [int]$replayChild.replay_attempt_count_after -eq 2 `
        -and [int]$replayChild.targeted_owner_capture_diagnostic_count_after -eq 7 `
        -and [bool]$replayParent.parent_attestation_green `
        -and [int]$replayParent.replay_attempt_count_after -eq 2
) "execution_replay_v2_not_green"

$repositoryHead = (& git -C $projectFull rev-parse HEAD).Trim().ToLowerInvariant()
$branch = (& git -C $projectFull branch --show-current).Trim()
$dirtyPaths = @(& git -C $projectFull status --porcelain)
$diffCheck = @(& git -C $projectFull diff --check 2>&1)
Assert-Condition ($LASTEXITCODE -eq 0 -and $diffCheck.Count -eq 0) "remaining_owner_preflight_attempt_v2_diff_check_failed"
Assert-Condition ($repositoryHead -cmatch "^[0-9a-f]{40}$" -and $dirtyPaths.Count -eq 0) "remaining_owner_preflight_attempt_v2_tree_not_clean"
Assert-Condition ($branch -ceq "codex/alpha04c-save-resume-cold-restore-5b8601b") "remaining_owner_preflight_attempt_v2_branch_invalid"
$remoteHead = (& git -C $projectFull rev-parse "refs/remotes/origin/$branch" 2>$null).Trim().ToLowerInvariant()
Assert-Condition ($LASTEXITCODE -eq 0 -and $remoteHead -ceq $repositoryHead) "remaining_owner_preflight_attempt_v2_remote_checkpoint_mismatch"
& git -C $projectFull merge-base --is-ancestor $ReplayV2EvidenceCommit $repositoryHead
Assert-Condition ($LASTEXITCODE -eq 0) "execution_replay_v2_evidence_not_ancestor"

$gitCommonRaw = (& git -C $projectFull rev-parse --git-common-dir).Trim()
$gitCommon = if ([IO.Path]::IsPathRooted($gitCommonRaw)) { [IO.Path]::GetFullPath($gitCommonRaw) } else { [IO.Path]::GetFullPath((Join-Path $projectFull $gitCommonRaw)) }
$v7Root = Join-Path $gitCommon "codex/cold_restore_v3/non-official-alpha04c-owner-capture-diagnostic-v7-registry-contract"
$v8Root = Join-Path $gitCommon "codex/cold_restore_v3/non-official-alpha04c-owner-capture-diagnostic-v8-all-owner-closed-wire"
$v7LedgerPath = Join-Path $v7Root "targeted_owner_capture_quota_ledger.json"
$attemptRoot = Join-Path $gitCommon "codex/cold_restore_v3/non-official-alpha04c-remaining-owner-preflight-index14-18-attempt-v2"
$claimPath = Join-Path $attemptRoot "preflight_attempt_claim.json"
$admissionPath = Join-Path $attemptRoot "preflight_child_admission.json"
$consumedPath = Join-Path $attemptRoot "preflight_child_admission_consumed.json"
$ledgerPath = Join-Path $attemptRoot "remaining_owner_preflight_attempt_ledger.json"
$v7Before = Get-DirectoryAttestation -Root $v7Root
$v7LedgerBefore = (Get-FileHash -LiteralPath $v7LedgerPath -Algorithm SHA256).Hash.ToLowerInvariant()
Assert-Condition ($v7Before.file_count -eq $ExpectedV7FileCount -and $v7Before.byte_count -eq $ExpectedV7ByteCount -and $v7LedgerBefore -ceq $ExpectedV7LedgerSha256) "immutable_v7_evidence_precondition_mismatch"
Assert-Condition (-not (Test-Path -LiteralPath $v8Root)) "v8_root_exists_before_remaining_owner_preflight"
Assert-Condition (-not (Test-Path -LiteralPath $attemptRoot)) "remaining_owner_preflight_attempt_v2_already_claimed"

$startedAt = [DateTimeOffset]::UtcNow.ToString("o")
$claim = [ordered]@{
    schema_version = 1
    claim_id = "RemainingOwnerClosedDataPreflightAttemptClaimV2"
    attempt_id = $AttemptId
    frozen_code_head = $repositoryHead
    start_index = 14
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
    admission_id = "RemainingOwnerClosedDataPreflightChildAdmissionV2"
    claim_sha256 = $claimSha256
    attempt_id = $AttemptId
    frozen_code_head = $repositoryHead
}
Write-ExclusiveJsonFile -Path $admissionPath -Value $admission

$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$tempRoot = Join-Path $tempBase ("space-syndicate-alpha04c-remaining-index-14-18-preflight-v2-" + [Guid]::NewGuid().ToString("N"))
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
        "res://scripts/tools/alpha04c_remaining_index_14_18_owner_closed_data_preflight_v2.gd",
        "--", "--evidence-output=$evidenceFull", "--repository-head=$repositoryHead",
        "--preflight-claim-path=$claimPath", "--preflight-claim-sha256=$claimSha256",
        "--preflight-admission-path=$admissionPath", "--preflight-consumed-path=$consumedPath"
    )) { $startInfo.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    Assert-Condition ($process.Start()) "remaining_owner_preflight_attempt_v2_launch_failed"
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(120000)) {
        $process.Kill($true)
        $process.WaitForExit()
        throw "remaining_owner_preflight_attempt_v2_timeout"
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $childExitCode = $process.ExitCode
    Assert-Condition (Test-Path -LiteralPath $evidenceFull -PathType Leaf) "remaining_owner_preflight_attempt_v2_child_evidence_missing"
    Assert-Condition ((Test-Path -LiteralPath $consumedPath -PathType Leaf) -and -not (Test-Path -LiteralPath $admissionPath)) "remaining_owner_preflight_attempt_v2_admission_not_consumed"
    $child = Get-Content -LiteralPath $evidenceFull -Raw | ConvertFrom-Json
    $ownerResults = @($child.owner_results)
    $rowsValid = $true
    for ($index = 0; $index -lt $ownerResults.Count; $index += 1) {
        $row = $ownerResults[$index]
        $rowsValid = $rowsValid `
            -and (Test-ExactPropertySet -Value $row -Expected @(
                "owner_index", "section_id", "owner_id", "capture_method", "payload_present",
                "payload_dictionary", "payload_nonempty", "payload_closed_data", "state_version",
                "ruleset_id", "leaf_count", "non_closed_leaf_count", "non_closed_type_counts",
                "first_non_closed_path", "first_non_closed_type", "capture_mutation_count",
                "rng_draw_delta", "world_time_delta", "public_log_delta", "private_feedback_delta",
                "reason_code"
            )) `
            -and [int]$row.owner_index -eq (14 + $index) `
            -and [int]$row.capture_mutation_count -eq 0 `
            -and [int]$row.rng_draw_delta -eq 0 `
            -and [int]$row.world_time_delta -eq 0 `
            -and [int]$row.public_log_delta -eq 0 `
            -and [int]$row.private_feedback_delta -eq 0
    }
    $successOutcome = $childExitCode -eq 0 `
        -and [bool]$child.success `
        -and $ownerResults.Count -eq 5 `
        -and [int]$child.new_remaining_owner_preflight_green_count -eq 5 `
        -and [int]$child.total_remaining_owner_preflight_count -eq 11 `
        -and [int]$child.total_remaining_owner_preflight_green_count -eq 11
    $blockedOutcome = $childExitCode -eq 2 `
        -and -not [bool]$child.success `
        -and [int]$child.first_remaining_owner_failure_index -ge 14 `
        -and [int]$child.first_remaining_owner_failure_index -le 18 `
        -and $ownerResults.Count -eq ([int]$child.first_remaining_owner_failure_index - 13)
    $v7After = Get-DirectoryAttestation -Root $v7Root
    $v7LedgerAfter = (Get-FileHash -LiteralPath $v7LedgerPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $v7Immutable = $v7Before.file_count -eq $v7After.file_count `
        -and $v7Before.byte_count -eq $v7After.byte_count `
        -and $v7Before.tree_fingerprint -ceq $v7After.tree_fingerprint `
        -and $v7LedgerBefore -ceq $v7LedgerAfter
    $v8Absent = -not (Test-Path -LiteralPath $v8Root)
    $taskOwnedProcessCountAfter = @(Get-Process | Where-Object { $_.ProcessName -like "Godot*" }).Count
    $outcomeValid = [string]$child.attempt_id -ceq $AttemptId `
        -and [string]$child.repository_head -ceq $repositoryHead `
        -and [bool]$child.attempt_child_admission_consumed `
        -and [bool]$child.scenario_identity_attested `
        -and [bool]$child.registry_binding_attested `
        -and [bool]$child.execution_replay_v2_green `
        -and [int]$child.remaining_owner_preflight_attempt_count_delta -eq 1 `
        -and [int]$child.remaining_owner_preflight_concurrent_execution_count -eq 1 `
        -and [int]$child.targeted_owner_capture_diagnostic_count_before -eq 7 `
        -and [int]$child.targeted_owner_capture_diagnostic_count_after -eq 7 `
        -and [int]$child.preflight_diagnostic_count_delta -eq 0 `
        -and [int]$child.preflight_quota_claim_count -eq 0 `
        -and [int]$child.preflight_full_owner_audit_count -eq 0 `
        -and [int]$child.preflight_process_a_count -eq 0 `
        -and -not [bool]$child.v8_authorization_created `
        -and -not [bool]$child.v8_run_id_created `
        -and [bool]$child.private_payload_redacted `
        -and $rowsValid `
        -and ($successOutcome -or $blockedOutcome)
    $parentGreen = $outcomeValid -and $v7Immutable -and $v8Absent -and $taskOwnedProcessCountAfter -eq 0
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
        v8_authorization_root_absent = [bool]$v8Absent
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
        contract_id = "RemainingOwnerClosedDataPreflightAttemptV2"
        attempt_id = $AttemptId
        frozen_code_head = $repositoryHead
        start_index = 14
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
    Assert-Condition $parentGreen "remaining_owner_preflight_attempt_v2_parent_attestation_failed"
    [Console]::Out.WriteLine("ALPHA04C_REMAINING_INDEX_14_18_OWNER_PREFLIGHT_V2_PARENT|" + (ConvertTo-Json -InputObject $parent -Compress -Depth 12))
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
            -and (Split-Path -Leaf $resolvedTempRoot).StartsWith("space-syndicate-alpha04c-remaining-index-14-18-preflight-v2-", [StringComparison]::Ordinal)) {
        Remove-Item -LiteralPath $resolvedTempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
