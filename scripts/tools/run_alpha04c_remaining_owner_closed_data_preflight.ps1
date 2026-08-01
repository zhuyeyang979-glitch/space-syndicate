[CmdletBinding()]
param(
    [string]$GodotPath = "",
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
)

$ErrorActionPreference = "Stop"
$ExpectedV7FileCount = 107
$ExpectedV7ByteCount = [int64]271918
$ExpectedLedgerSha256 = "607f1a15d875321a368ab071b35693857d7acf32063b4ed5578fa4f4aea9f826"

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
    [IO.File]::WriteAllText(
        $Path,
        (ConvertTo-Json -InputObject $Value -Depth 12) + [Environment]::NewLine,
        [Text.UTF8Encoding]::new($false)
    )
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
$evidenceFull = Join-Path $projectFull "reports/handoffs/alpha04c_remaining_11_owner_closed_data_preflight.json"
$parentFull = Join-Path $projectFull "reports/handoffs/alpha04c_remaining_11_owner_closed_data_preflight_parent_attestation.json"
$replayChildPath = Join-Path $projectFull "reports/handoffs/alpha04c_v7_card_inventory_save_v4_checkpoint_v2_replay_v2.json"
$replayParentPath = Join-Path $projectFull "reports/handoffs/alpha04c_v7_card_inventory_save_v4_checkpoint_v2_replay_v2_parent_attestation.json"

Assert-Condition (Test-Path -LiteralPath $GodotPath -PathType Leaf) "godot_console_missing"
Assert-Condition (-not (Test-Path -LiteralPath $evidenceFull) -and -not (Test-Path -LiteralPath $parentFull)) "remaining_owner_preflight_evidence_already_exists"
Assert-Condition (Test-Path -LiteralPath $replayChildPath -PathType Leaf) "card_inventory_replay_v2_child_missing"
Assert-Condition (Test-Path -LiteralPath $replayParentPath -PathType Leaf) "card_inventory_replay_v2_parent_missing"
Assert-Condition (@(Get-Process | Where-Object { $_.ProcessName -like "Godot*" }).Count -eq 0) "preexisting_godot_process_detected"

$replayChild = Get-Content -LiteralPath $replayChildPath -Raw | ConvertFrom-Json
$replayParent = Get-Content -LiteralPath $replayParentPath -Raw | ConvertFrom-Json
Assert-Condition (
    [bool]$replayChild.success `
        -and [bool]$replayChild.v7_card_inventory_save_v4_replay_green `
        -and [bool]$replayChild.v7_card_inventory_checkpoint_v2_replay_green `
        -and [bool]$replayChild.v7_card_inventory_restore_parity `
        -and [bool]$replayParent.parent_attestation_green
) "card_inventory_replay_v2_not_green"

$repositoryHead = (& git -C $projectFull rev-parse HEAD).Trim().ToLowerInvariant()
$branch = (& git -C $projectFull branch --show-current).Trim()
$dirtyPaths = @(& git -C $projectFull status --porcelain)
$diffCheck = @(& git -C $projectFull diff --check 2>&1)
Assert-Condition ($LASTEXITCODE -eq 0 -and $diffCheck.Count -eq 0) "remaining_owner_preflight_diff_check_failed"
Assert-Condition ($repositoryHead -cmatch "^[0-9a-f]{40}$" -and $dirtyPaths.Count -eq 0) "remaining_owner_preflight_tree_not_clean"
$remoteHead = (& git -C $projectFull rev-parse "refs/remotes/origin/$branch" 2>$null).Trim().ToLowerInvariant()
Assert-Condition ($LASTEXITCODE -eq 0 -and $remoteHead -ceq $repositoryHead) "remaining_owner_preflight_remote_checkpoint_mismatch"
& git -C $projectFull merge-base --is-ancestor a1b17423f35c9daf6868c90248bf9c952fc225ca $repositoryHead
Assert-Condition ($LASTEXITCODE -eq 0) "card_inventory_replay_v2_code_head_not_ancestor"

$gitCommonRaw = (& git -C $projectFull rev-parse --git-common-dir).Trim()
$gitCommon = if ([IO.Path]::IsPathRooted($gitCommonRaw)) { [IO.Path]::GetFullPath($gitCommonRaw) } else { [IO.Path]::GetFullPath((Join-Path $projectFull $gitCommonRaw)) }
$v7Root = Join-Path $gitCommon "codex/cold_restore_v3/non-official-alpha04c-owner-capture-diagnostic-v7-registry-contract"
$v8Root = Join-Path $gitCommon "codex/cold_restore_v3/non-official-alpha04c-owner-capture-diagnostic-v8-all-owner-closed-wire"
$ledgerPath = Join-Path $v7Root "targeted_owner_capture_quota_ledger.json"
$v7Before = Get-DirectoryAttestation -Root $v7Root
$ledgerBefore = (Get-FileHash -LiteralPath $ledgerPath -Algorithm SHA256).Hash.ToLowerInvariant()
Assert-Condition ($v7Before.file_count -eq $ExpectedV7FileCount -and $v7Before.byte_count -eq $ExpectedV7ByteCount -and $ledgerBefore -ceq $ExpectedLedgerSha256) "immutable_v7_evidence_precondition_mismatch"
Assert-Condition (-not (Test-Path -LiteralPath $v8Root)) "v8_root_exists_before_authorization"

$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$tempRoot = Join-Path $tempBase ("space-syndicate-alpha04c-remaining-owner-preflight-" + [Guid]::NewGuid().ToString("N"))
$appData = Join-Path $tempRoot "appdata"
$localAppData = Join-Path $tempRoot "localappdata"
[IO.Directory]::CreateDirectory($appData) | Out-Null
[IO.Directory]::CreateDirectory($localAppData) | Out-Null

$process = $null
$childExitCode = -1
$stdout = ""
$stderr = ""
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
        "res://scripts/tools/alpha04c_remaining_owner_closed_data_preflight.gd",
        "--", "--evidence-output=$evidenceFull", "--repository-head=$repositoryHead"
    )) { $startInfo.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    Assert-Condition ($process.Start()) "remaining_owner_preflight_launch_failed"
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(120000)) {
        $process.Kill($true)
        $process.WaitForExit()
        throw "remaining_owner_preflight_timeout"
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $childExitCode = $process.ExitCode
    Assert-Condition (Test-Path -LiteralPath $evidenceFull -PathType Leaf) "remaining_owner_preflight_child_evidence_missing"
    $child = Get-Content -LiteralPath $evidenceFull -Raw | ConvertFrom-Json
    $v7After = Get-DirectoryAttestation -Root $v7Root
    $ledgerAfter = (Get-FileHash -LiteralPath $ledgerPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $v7Immutable = $v7Before.file_count -eq $v7After.file_count `
        -and $v7Before.byte_count -eq $v7After.byte_count `
        -and $v7Before.tree_fingerprint -ceq $v7After.tree_fingerprint `
        -and $ledgerBefore -ceq $ledgerAfter
    $v8Absent = -not (Test-Path -LiteralPath $v8Root)
    $taskOwnedProcessCountAfter = @(Get-Process | Where-Object { $_.ProcessName -like "Godot*" }).Count
    $outcomeValid = [bool]$child.scenario_identity_attested `
        -and [bool]$child.registry_binding_attested `
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
            ($childExitCode -eq 0 -and [bool]$child.success -and [int]$child.remaining_owner_preflight_count -eq 11) `
            -or ($childExitCode -eq 2 -and -not [bool]$child.success -and [int]$child.first_remaining_owner_failure_index -ge 8)
        )
    $executionGreen = $outcomeValid -and $v7Immutable -and $v8Absent -and $taskOwnedProcessCountAfter -eq 0
    $parent = [ordered]@{
        schema_version = 1
        preflight_id = [string]$child.preflight_id
        repository_head = $repositoryHead
        child_exit_code = [int]$childExitCode
        child_result_sha256 = (Get-FileHash -LiteralPath $evidenceFull -Algorithm SHA256).Hash.ToLowerInvariant()
        child_success = [bool]$child.success
        first_remaining_owner_failure_index = [int]$child.first_remaining_owner_failure_index
        first_remaining_owner_failure_id = [string]$child.first_remaining_owner_failure_id
        first_remaining_owner_failure_reason = [string]$child.first_remaining_owner_failure_reason
        immutable_v7_evidence_preserved = [bool]$v7Immutable
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
    Assert-Condition $executionGreen "remaining_owner_preflight_parent_attestation_failed"
    [Console]::Out.WriteLine("ALPHA04C_REMAINING_OWNER_PREFLIGHT_PARENT|" + (ConvertTo-Json -InputObject $parent -Compress -Depth 8))
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
            -and (Split-Path -Leaf $resolvedTempRoot).StartsWith("space-syndicate-alpha04c-remaining-owner-preflight-", [StringComparison]::Ordinal)) {
        Remove-Item -LiteralPath $resolvedTempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
