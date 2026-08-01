[CmdletBinding()]
param(
    [string]$GodotPath = "",
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
)

$ErrorActionPreference = "Stop"
$ExpectedV7FileCount = 107
$ExpectedV7ByteCount = [int64]271918
$ExpectedLedgerSha256 = "607f1a15d875321a368ab071b35693857d7acf32063b4ed5578fa4f4aea9f826"
$ExpectedPhaseSha256 = "eba66bdf8edc55071b862a6b1c9d1ab8073d130335408bcf76be9c373538b778"
$AuthorizationId = "alpha04c-monster-runtime-save-v2-replay-v1"
$RunId = "alpha04c-monster-runtime-replay-v1-attempt-1"

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
    return [ordered]@{
        file_count = [int]$files.Count
        byte_count = [int64](($files | Measure-Object Length -Sum).Sum)
        tree_fingerprint = Get-Sha256Text -Text $manifest
    }
}

function Write-ExclusiveJsonFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Value
    )
    [IO.Directory]::CreateDirectory((Split-Path -Parent $Path)) | Out-Null
    $json = (ConvertTo-Json -InputObject $Value -Depth 12) + [Environment]::NewLine
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($json)
    $stream = [IO.FileStream]::new($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
    }
    finally {
        $stream.Dispose()
    }
}

function Assert-Condition {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Reason
    )
    if (-not $Condition) {
        throw $Reason
    }
}

function Test-ExactJsonInt64 {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][long]$Expected
    )
    return $null -ne $Value -and $Value.GetType() -eq [long] -and [long]$Value -eq $Expected
}

function Test-ExactPropertySet {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string[]]$Expected
    )
    $actual = @($Value.PSObject.Properties.Name)
    if ($actual.Count -ne $Expected.Count) {
        return $false
    }
    foreach ($field in $Expected) {
        if ($actual -cnotcontains $field) {
            return $false
        }
    }
    return $true
}

function Resolve-GodotConsolePath {
    param([string]$RequestedPath)
    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        return [IO.Path]::GetFullPath($RequestedPath)
    }
    $candidates = @()
    if (-not [string]::IsNullOrWhiteSpace($env:GODOT4_CONSOLE)) {
        $candidates += $env:GODOT4_CONSOLE
    }
    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        $candidates += (Join-Path $env:LOCALAPPDATA "Programs/Godot/4.7/Godot_v4.7-stable_win64_console.exe")
    }
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return [IO.Path]::GetFullPath($candidate)
        }
    }
    foreach ($commandName in @("godot4", "godot")) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue
        if ($null -ne $command) {
            return [IO.Path]::GetFullPath($command.Source)
        }
    }
    throw "godot_console_missing"
}

$projectFull = [IO.Path]::GetFullPath($ProjectPath)
$GodotPath = Resolve-GodotConsolePath -RequestedPath $GodotPath
$evidenceFull = Join-Path $projectFull "reports/handoffs/alpha04c_monster_runtime_save_v2_replay_v1.json"
$parentFull = Join-Path $projectFull "reports/handoffs/alpha04c_monster_runtime_save_v2_replay_v1_parent_attestation.json"
$authorizationPath = Join-Path $projectFull "scripts/tools/monster_runtime_owner_replay_authorization_v1.json"

Assert-Condition (Test-Path -LiteralPath $GodotPath -PathType Leaf) "godot_console_missing"
Assert-Condition (Test-Path -LiteralPath $authorizationPath -PathType Leaf) "monster_replay_authorization_missing"
Assert-Condition (-not (Test-Path -LiteralPath $evidenceFull) -and -not (Test-Path -LiteralPath $parentFull)) "monster_replay_evidence_already_exists"
Assert-Condition (@(Get-Process | Where-Object { $_.ProcessName -like "Godot*" }).Count -eq 0) "preexisting_godot_process_detected"

$authorization = Get-Content -LiteralPath $authorizationPath -Raw | ConvertFrom-Json
Assert-Condition (
    (Test-ExactPropertySet -Value $authorization -Expected @(
        "schema_version",
        "contract_id",
        "authorization_id",
        "run_id_prefix",
        "run_id",
        "replay_attempt_count_before",
        "authorized_new_replay_count",
        "replay_attempt_count_after",
        "targeted_owner_capture_diagnostic_count_before",
        "targeted_owner_capture_diagnostic_count_after"
    )) `
        -and (Test-ExactJsonInt64 -Value $authorization.schema_version -Expected 1) `
        -and [string]$authorization.contract_id -ceq "MonsterRuntimeOwnerReplayAuthorizationV1" `
        -and [string]$authorization.authorization_id -ceq $AuthorizationId `
        -and [string]$authorization.run_id_prefix -ceq "alpha04c-monster-runtime-replay-v1" `
        -and [string]$authorization.run_id -ceq $RunId `
        -and (Test-ExactJsonInt64 -Value $authorization.replay_attempt_count_before -Expected 0) `
        -and (Test-ExactJsonInt64 -Value $authorization.authorized_new_replay_count -Expected 1) `
        -and (Test-ExactJsonInt64 -Value $authorization.replay_attempt_count_after -Expected 1) `
        -and (Test-ExactJsonInt64 -Value $authorization.targeted_owner_capture_diagnostic_count_before -Expected 7) `
        -and (Test-ExactJsonInt64 -Value $authorization.targeted_owner_capture_diagnostic_count_after -Expected 7)
) "monster_replay_authorization_invalid"

$gitCommonRaw = (& git -C $projectFull rev-parse --git-common-dir).Trim()
Assert-Condition ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitCommonRaw)) "git_common_directory_unavailable"
$gitCommon = if ([IO.Path]::IsPathRooted($gitCommonRaw)) {
    [IO.Path]::GetFullPath($gitCommonRaw)
}
else {
    [IO.Path]::GetFullPath((Join-Path $projectFull $gitCommonRaw))
}
$repositoryHead = (& git -C $projectFull rev-parse HEAD).Trim().ToLowerInvariant()
$branch = (& git -C $projectFull branch --show-current).Trim()
$dirtyPaths = @(& git -C $projectFull status --porcelain)
$diffCheck = @(& git -C $projectFull diff --check 2>&1)
Assert-Condition ($repositoryHead -cmatch "^[0-9a-f]{40}$") "repository_head_unavailable"
Assert-Condition ($LASTEXITCODE -eq 0 -and $diffCheck.Count -eq 0) "monster_replay_git_diff_check_failed"
Assert-Condition ($dirtyPaths.Count -eq 0) "monster_replay_tree_not_clean"
Assert-Condition ($branch -cmatch "^codex/alpha04c-monster-save-v2-[0-9a-f]{7,12}$") "monster_replay_branch_invalid"
$remoteHead = (& git -C $projectFull rev-parse "refs/remotes/origin/$branch" 2>$null).Trim().ToLowerInvariant()
Assert-Condition ($LASTEXITCODE -eq 0 -and $remoteHead -ceq $repositoryHead) "monster_replay_remote_checkpoint_mismatch"
& git -C $projectFull merge-base --is-ancestor 8fc4b78c05327e330f9f0bbd2f065420535fe8be $repositoryHead
Assert-Condition ($LASTEXITCODE -eq 0) "card_inventory_repair_head_not_ancestor"
& git -C $projectFull merge-base --is-ancestor 1964e6e8d86543f88781b91a239064d1a87b3e89 $repositoryHead
Assert-Condition ($LASTEXITCODE -eq 0) "pr77_replay_baseline_not_ancestor"

$v7Root = Join-Path $gitCommon "codex/cold_restore_v3/non-official-alpha04c-owner-capture-diagnostic-v7-registry-contract"
$ledgerPath = Join-Path $v7Root "targeted_owner_capture_quota_ledger.json"
$phasePath = Join-Path $v7Root "evidence/diagnostics/phase_events/0024.snapshot.json"
$v8Root = Join-Path $gitCommon "codex/cold_restore_v3/non-official-alpha04c-owner-capture-diagnostic-v8-all-owner-closed-wire"
Assert-Condition (Test-Path -LiteralPath $ledgerPath -PathType Leaf) "immutable_v7_ledger_missing"
Assert-Condition (Test-Path -LiteralPath $phasePath -PathType Leaf) "immutable_v7_phase_missing"
Assert-Condition (-not (Test-Path -LiteralPath $v8Root)) "v8_root_created_before_monster_replay"
$v7Before = Get-DirectoryAttestation -Root $v7Root
$ledgerBefore = (Get-FileHash -LiteralPath $ledgerPath -Algorithm SHA256).Hash.ToLowerInvariant()
$phaseBefore = (Get-FileHash -LiteralPath $phasePath -Algorithm SHA256).Hash.ToLowerInvariant()
Assert-Condition (
    $v7Before.file_count -eq $ExpectedV7FileCount `
        -and $v7Before.byte_count -eq $ExpectedV7ByteCount `
        -and $ledgerBefore -ceq $ExpectedLedgerSha256 `
        -and $phaseBefore -ceq $ExpectedPhaseSha256
) "immutable_v7_evidence_precondition_mismatch"

$replayRoot = Join-Path $gitCommon "codex/cold_restore_v3/non-official-alpha04c-monster-runtime-replay-v1"
$claimPath = Join-Path $replayRoot "replay_attempt_claim.json"
$admissionPath = Join-Path $replayRoot "replay_child_admission.json"
$consumedPath = Join-Path $replayRoot "replay_child_admission_consumed.json"
Assert-Condition (-not (Test-Path -LiteralPath $replayRoot)) "monster_replay_attempt_already_claimed"
$claim = [ordered]@{
    schema_version = 1
    claim_id = "MonsterRuntimeOwnerReplayAttemptClaimV1"
    authorization_id = $AuthorizationId
    run_id = $RunId
    repository_head = $repositoryHead
    replay_attempt_count_before = 0
    authorized_new_replay_count = 1
    replay_attempt_count_after = 1
    targeted_owner_capture_diagnostic_count_before = 7
    targeted_owner_capture_diagnostic_count_after = 7
    private_payload_redacted = $true
}
Write-ExclusiveJsonFile -Path $claimPath -Value $claim
$claimSha256 = (Get-FileHash -LiteralPath $claimPath -Algorithm SHA256).Hash.ToLowerInvariant()
$admission = [ordered]@{
    schema_version = 1
    admission_id = "MonsterRuntimeOwnerReplayChildAdmissionV1"
    claim_sha256 = $claimSha256
    authorization_id = $AuthorizationId
    run_id = $RunId
    repository_head = $repositoryHead
}
Write-ExclusiveJsonFile -Path $admissionPath -Value $admission

$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$tempRoot = Join-Path $tempBase ("space-syndicate-alpha04c-monster-replay-v1-" + [Guid]::NewGuid().ToString("N"))
$appData = Join-Path $tempRoot "appdata"
$localAppData = Join-Path $tempRoot "localappdata"
[IO.Directory]::CreateDirectory($appData) | Out-Null
[IO.Directory]::CreateDirectory($localAppData) | Out-Null

$childExitCode = -1
$stdout = ""
$stderr = ""
$process = $null
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
    foreach ($argument in @(
        "--headless", "--path", $projectFull, "--script",
        "res://scripts/tools/alpha04c_monster_runtime_nonconsuming_replay.gd",
        "--", "--evidence-output=$evidenceFull", "--repository-head=$repositoryHead",
        "--replay-claim-path=$claimPath", "--replay-claim-sha256=$claimSha256",
        "--replay-admission-path=$admissionPath", "--replay-consumed-path=$consumedPath"
    )) {
        $startInfo.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    Assert-Condition ($process.Start()) "monster_replay_godot_launch_failed"
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(120000)) {
        $process.Kill($true)
        $process.WaitForExit()
        throw "monster_replay_timeout"
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $childExitCode = $process.ExitCode
    Assert-Condition (Test-Path -LiteralPath $evidenceFull -PathType Leaf) "monster_replay_child_evidence_missing"
    $childResult = Get-Content -LiteralPath $evidenceFull -Raw | ConvertFrom-Json
    $v7After = Get-DirectoryAttestation -Root $v7Root
    $ledgerAfter = (Get-FileHash -LiteralPath $ledgerPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $phaseAfter = (Get-FileHash -LiteralPath $phasePath -Algorithm SHA256).Hash.ToLowerInvariant()
    $taskOwnedProcessCountAfter = @(Get-Process | Where-Object { $_.ProcessName -like "Godot*" }).Count
    $godotVersion = if ($stdout -match "Godot Engine v([^\s]+)") { $Matches[1] } else { "unknown" }
    $immutable = $v7Before.file_count -eq $v7After.file_count `
        -and $v7Before.byte_count -eq $v7After.byte_count `
        -and $v7Before.tree_fingerprint -ceq $v7After.tree_fingerprint `
        -and $ledgerBefore -ceq $ledgerAfter `
        -and $phaseBefore -ceq $phaseAfter
    $childGreen = $childExitCode -eq 0 `
        -and [bool]$childResult.success `
        -and [string]$childResult.replay_run_id -ceq $RunId `
        -and [string]$childResult.replay_authorization_id -ceq $AuthorizationId `
        -and [bool]$childResult.monster_runtime_replay_scenario_identity_green `
        -and [bool]$childResult.monster_runtime_replay_registry_binding_green `
        -and [bool]$childResult.monster_runtime_save_v2_replay_green `
        -and [bool]$childResult.monster_runtime_payload_closed `
        -and [bool]$childResult.monster_runtime_restore_parity `
        -and [int]$childResult.monster_runtime_capture_mutation_count -eq 0 `
        -and [int]$childResult.replay_diagnostic_count_delta -eq 0 `
        -and [int]$childResult.replay_quota_claim_count -eq 0 `
        -and [int]$childResult.replay_full_owner_audit_count -eq 0 `
        -and [int]$childResult.replay_production_fixed_slot_write_count -eq 0 `
        -and [int]$childResult.replay_process_a_count -eq 0

    $parent = [ordered]@{
        schema_version = 1
        replay_run_id = $RunId
        replay_authorization_id = $AuthorizationId
        repository_head = $repositoryHead
        child_exit_code = [int]$childExitCode
        child_result_sha256 = (Get-FileHash -LiteralPath $evidenceFull -Algorithm SHA256).Hash.ToLowerInvariant()
        child_stderr_sha256 = Get-Sha256Text -Text $stderr
        godot_version = $godotVersion
        isolated_appdata = $true
        isolated_localappdata = $true
        replay_attempt_count_before = 0
        authorized_new_replay_count = 1
        replay_attempt_count_after = 1
        immutable_v7_evidence_preserved = [bool]$immutable
        v7_evidence_tree_fingerprint_before = $v7Before.tree_fingerprint
        v7_evidence_tree_fingerprint_after = $v7After.tree_fingerprint
        v7_quota_ledger_sha256_before = $ledgerBefore
        v7_quota_ledger_sha256_after = $ledgerAfter
        replay_diagnostic_count_delta = 0
        replay_quota_claim_count = 0
        replay_full_owner_audit_count = 0
        replay_production_fixed_slot_write_count = 0
        replay_process_a_count = 0
        v8_root_created = [bool](Test-Path -LiteralPath $v8Root)
        task_owned_process_count_after = [int]$taskOwnedProcessCountAfter
        child_success = [bool]$childResult.success
        parent_attestation_green = [bool]($childGreen -and $immutable -and -not (Test-Path -LiteralPath $v8Root) -and $taskOwnedProcessCountAfter -eq 0)
        private_payload_redacted = $true
    }
    Write-ExclusiveJsonFile -Path $parentFull -Value $parent
    Assert-Condition ([bool]$parent.parent_attestation_green) "monster_replay_parent_attestation_failed"
    [Console]::Out.WriteLine("ALPHA04C_MONSTER_RUNTIME_REPLAY_V1_PARENT|" + (ConvertTo-Json -InputObject $parent -Compress -Depth 8))
}
finally {
    if ($null -ne $process) {
        try {
            if (-not $process.HasExited) {
                $process.Kill($true)
                $process.WaitForExit()
            }
        }
        catch {
        }
        finally {
            $process.Dispose()
        }
    }
    $resolvedTempRoot = [IO.Path]::GetFullPath($tempRoot)
    if ($resolvedTempRoot.StartsWith($tempBase, [StringComparison]::OrdinalIgnoreCase) `
            -and (Split-Path -Leaf $resolvedTempRoot).StartsWith("space-syndicate-alpha04c-monster-replay-v1-", [StringComparison]::Ordinal)) {
        Remove-Item -LiteralPath $resolvedTempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
