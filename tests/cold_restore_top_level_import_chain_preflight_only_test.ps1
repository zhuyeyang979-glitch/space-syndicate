[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$orchestratorPath = Join-Path $projectRoot "scripts/tools/cold_restore_vertical_slice_orchestrator.ps1"
$contractPath = Join-Path $projectRoot "scripts/tools/cold_restore_authorization_contract_v1.json"
$pwshPath = (Get-Command pwsh -CommandType Application -ErrorAction Stop).Source
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) (
    "alpha04c preflight only 中文 空格 " + [Guid]::NewGuid().ToString("N")
)
$script:checks = 0
$script:failures = [Collections.Generic.List[string]]::new()

function Assert-PreflightOnlyCondition {
    param([bool]$Condition, [string]$Message)

    $script:checks += 1
    if (-not $Condition) {
        $script:failures.Add($Message)
    }
}

function Get-PreflightTextSha256 {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)

    return [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))
    ).ToLowerInvariant()
}

function Get-ProtectedRootSnapshot {
    param([Parameter(Mandatory = $true)][string[]]$Paths)

    $rows = [Collections.Generic.List[object]]::new()
    foreach ($path in @($Paths | Sort-Object -Unique)) {
        $resolved = [IO.Path]::GetFullPath($path)
        if ([IO.File]::Exists($resolved)) {
            $rows.Add([pscustomobject][ordered]@{
                root = $resolved
                relative_path = "."
                kind = "file"
                length = [int64](Get-Item -LiteralPath $resolved).Length
                sha256 = (Get-FileHash -LiteralPath $resolved -Algorithm SHA256).Hash.ToLowerInvariant()
            })
            continue
        }
        if (-not [IO.Directory]::Exists($resolved)) {
            $rows.Add([pscustomobject][ordered]@{
                root = $resolved
                relative_path = "."
                kind = "absent"
                length = [int64]0
                sha256 = ""
            })
            continue
        }
        $rows.Add([pscustomobject][ordered]@{
            root = $resolved
            relative_path = "."
            kind = "directory"
            length = [int64]0
            sha256 = ""
        })
        foreach ($item in @(Get-ChildItem -LiteralPath $resolved -Recurse -Force |
                Sort-Object FullName)) {
            $relative = [IO.Path]::GetRelativePath($resolved, $item.FullName)
            if ($item.PSIsContainer) {
                $rows.Add([pscustomobject][ordered]@{
                    root = $resolved
                    relative_path = $relative
                    kind = "directory"
                    length = [int64]0
                    sha256 = ""
                })
            }
            else {
                $rows.Add([pscustomobject][ordered]@{
                    root = $resolved
                    relative_path = $relative
                    kind = "file"
                    length = [int64]$item.Length
                    sha256 = (Get-FileHash -LiteralPath $item.FullName `
                        -Algorithm SHA256).Hash.ToLowerInvariant()
                })
            }
        }
    }
    $json = @($rows) | ConvertTo-Json -Depth 8 -Compress
    return [pscustomobject]@{
        rows = @($rows)
        fingerprint = Get-PreflightTextSha256 $json
    }
}

function Get-ResultProperty {
    param(
        [AllowNull()]$Value,
        [Parameter(Mandatory = $true)][string]$Name,
        [AllowNull()]$Default = $null
    )

    if ($null -eq $Value -or $Value.PSObject.Properties.Name -cnotcontains $Name) {
        return $Default
    }
    return $Value.$Name
}

$results = [Collections.Generic.List[object]]::new()
$freshProcessRuns = 0

try {
    [IO.Directory]::CreateDirectory($tempRoot) | Out-Null
    Assert-PreflightOnlyCondition (
        $tempRoot -cmatch '\s' -and $tempRoot -cmatch '[^\u0000-\u007f]'
    ) "test control root contains spaces and non-ASCII characters"
    Assert-PreflightOnlyCondition (
        [IO.File]::Exists($orchestratorPath) -and [IO.File]::Exists($contractPath)
    ) "real Orchestrator and production authorization contract exist"

    $repositoryHead = (& git -C $projectRoot rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or $repositoryHead -cnotmatch '^[0-9a-f]{40}$') {
        throw "preflight repository HEAD unavailable"
    }
    $runId = "alpha04c-owner-capture-diagnostic-v4-importchain-$($repositoryHead.Substring(0, 12))"
    $contract = [IO.File]::ReadAllText(
        $contractPath,
        [Text.UTF8Encoding]::new($false)
    ) | ConvertFrom-Json -DateKind String
    $authorization = $contract.targeted_owner_capture_diagnostic_v4_importchain
    Assert-PreflightOnlyCondition (
        [string]$authorization.authorization_id -ceq
            "alpha04c-targeted-owner-capture-diagnostic-v4-importchain" -and
        [string]$authorization.run_id_prefix -ceq
            "alpha04c-owner-capture-diagnostic-v4-importchain"
    ) "preflight binds the exact V4 production authorization"

    $gitCommonRaw = (& git -C $projectRoot rev-parse --git-common-dir).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($gitCommonRaw)) {
        throw "git common directory unavailable"
    }
    $gitCommon = if ([IO.Path]::IsPathFullyQualified($gitCommonRaw)) {
        [IO.Path]::GetFullPath($gitCommonRaw)
    }
    else {
        [IO.Path]::GetFullPath((Join-Path $projectRoot $gitCommonRaw))
    }
    $protectedPaths = @(
        Join-Path $gitCommon ([string]$authorization.quota_ledger_relative_path)
        Join-Path $gitCommon ([string]$authorization.evidence_root_relative_path)
        Join-Path $gitCommon ([string]$authorization.bootstrap_root_relative_path)
    )
    $protectedBefore = Get-ProtectedRootSnapshot $protectedPaths

    foreach ($runIndex in 1..3) {
        $startInfo = [Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = $pwshPath
        $startInfo.WorkingDirectory = $projectRoot
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        foreach ($argument in @(
                "-NoProfile",
                "-NonInteractive",
                "-File", $orchestratorPath,
                "-ProjectPath", $projectRoot,
                "-GodotPath", "__PREFLIGHT_ONLY_MUST_NOT_RESOLVE_GODOT__",
                "-RunId", $runId,
                "-TopLevelImportChainPreflightOnly"
            )) {
            $startInfo.ArgumentList.Add($argument)
        }
        $process = [Diagnostics.Process]::new()
        $process.StartInfo = $startInfo
        if (-not $process.Start()) {
            throw "preflight fresh process start failed: $runIndex"
        }
        $freshProcessRuns += 1
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(30000)) {
            $process.Kill($true)
            $process.WaitForExit()
            throw "preflight fresh process timed out: $runIndex"
        }
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        $jsonLines = @(
            $stdout -split "`r?`n" |
                Where-Object { $_.TrimStart().StartsWith("{", [StringComparison]::Ordinal) }
        )
        if ($jsonLines.Count -ne 1) {
            throw "preflight result JSON count invalid: run=$runIndex count=$($jsonLines.Count) stderr=$stderr"
        }
        $value = $jsonLines[0] | ConvertFrom-Json -DateKind String
        $value | Add-Member -NotePropertyName fresh_process_id -NotePropertyValue $process.Id
        $value | Add-Member -NotePropertyName fresh_process_exit_code -NotePropertyValue $process.ExitCode
        $value | Add-Member -NotePropertyName fresh_process_stderr -NotePropertyValue $stderr
        $results.Add($value)
    }

    $protectedAfter = Get-ProtectedRootSnapshot $protectedPaths
    Assert-PreflightOnlyCondition ($freshProcessRuns -eq 3) "exactly three fresh pwsh processes ran"
    Assert-PreflightOnlyCondition ($results.Count -eq 3) "exactly three preflight attestations returned"
    Assert-PreflightOnlyCondition (
        @($results | ForEach-Object { [int]$_.fresh_process_id } |
            Sort-Object -Unique).Count -eq 3
    ) "all preflights used distinct process identities"
    Assert-PreflightOnlyCondition (
        [string]$protectedBefore.fingerprint -ceq [string]$protectedAfter.fingerprint
    ) "formal V4 quota, evidence, and prequota roots are byte-for-byte unchanged"

    foreach ($result in $results) {
        $runIndex = $results.IndexOf($result) + 1
        Assert-PreflightOnlyCondition (
            [int]$result.fresh_process_exit_code -eq 0 -and
            [string]$result.fresh_process_stderr -ceq ""
        ) "preflight run $runIndex exits zero without stderr"
        Assert-PreflightOnlyCondition (
            [int]$result.schema_version -eq 1 -and
            [string]$result.attestation_id -ceq "TopLevelImportChainPreflightAttestationV1" -and
            [bool]$result.success -and [string]$result.failure_code -ceq ""
        ) "preflight run $runIndex returns a GREEN V1 attestation"
        Assert-PreflightOnlyCondition (
            [string]$result.run_id -ceq $runId -and
            [string]$result.repository_head -ceq $repositoryHead -and
            [string]$result.authorization_name -ceq
                "targeted_owner_capture_diagnostic_v4_importchain" -and
            [string]$result.authorization_id -ceq
                "alpha04c-targeted-owner-capture-diagnostic-v4-importchain"
        ) "preflight run $runIndex binds exact V4 identity and HEAD"
        Assert-PreflightOnlyCondition (
            [int]$result.runtime_import_force_count -eq 0 -and
            [int]$result.runtime_local_force_import_count -eq 0 -and
            [int]$result.ambient_script_scope_command_dependency_count -eq 0
        ) "preflight run $runIndex has a clean import audit"
        Assert-PreflightOnlyCondition (
            [bool]$result.evidence_fingerprint_command_present_before_admission -and
            [bool]$result.evidence_fingerprint_command_present_after_admission -and
            [bool]$result.attested_process_module_identity_stable -and
            [bool]$result.evidence_fingerprint_result_parity -and
            [bool]$result.prequota_context_parameters_valid
        ) "preflight run $runIndex preserves command identity and prequota binding"
        Assert-PreflightOnlyCondition (
            [string]$result.attested_process_module_sha256 -cmatch '^[0-9a-f]{64}$' -and
            [string]$result.evidence_fingerprint_probe_result -cmatch '^[0-9a-f]{64}$' -and
            [string]$result.command_set_fingerprint -cmatch '^[0-9a-f]{64}$' -and
            [string]$result.command_argument_fingerprint -cmatch '^[0-9a-f]{64}$' -and
            [string]$result.runtime_freeze_observation_fingerprint -cmatch '^[0-9a-f]{64}$' -and
            [string]$result.evidence_fingerprint -cmatch '^[0-9a-f]{64}$'
        ) "preflight run $runIndex emits complete machine fingerprints"
        Assert-PreflightOnlyCondition (
            [int]$result.quota_claim_count -eq 0 -and
            [int]$result.diagnostic_count_delta -eq 0 -and
            [int]$result.godot_launch_count -eq 0 -and
            [int]$result.save_write_count -eq 0
        ) "preflight run $runIndex has zero quota, diagnostic, Godot, and Save deltas"
        Assert-PreflightOnlyCondition (
            [bool]$result.quota_ledger_exists_before -eq
                [bool]$result.quota_ledger_exists_after -and
            [bool]$result.evidence_root_exists_before -eq
                [bool]$result.evidence_root_exists_after -and
            [bool]$result.bootstrap_root_exists_before -eq
                [bool]$result.bootstrap_root_exists_after
        ) "preflight run $runIndex leaves all formal root existence states unchanged"
        Assert-PreflightOnlyCondition (
            -not [bool]$result.official -and
            -not [bool]$result.formal -and
            -not [bool]$result.official_authorization_consumed -and
            [bool]$result.normal_exit_requested
        ) "preflight run $runIndex remains non-official and requests normal exit"
    }

    foreach ($field in @(
            "attested_process_module_name",
            "attested_process_module_path",
            "attested_process_module_sha256",
            "evidence_fingerprint_probe_result",
            "command_set_fingerprint",
            "command_argument_fingerprint",
            "runtime_freeze_observation_fingerprint",
            "evidence_fingerprint"
        )) {
        $values = @(
            $results | ForEach-Object { [string](Get-ResultProperty $_ $field "") } |
                Sort-Object -Unique
        )
        Assert-PreflightOnlyCondition (
            $values.Count -eq 1 -and -not [string]::IsNullOrEmpty($values[0])
        ) "preflight $field is stable across three fresh processes"
    }
}
catch {
    $script:failures.Add("unexpected exception: $($_.Exception.Message)")
}
finally {
    $resolvedRoot = [IO.Path]::GetFullPath($tempRoot)
    $resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolvedRoot.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetFileName($resolvedRoot).StartsWith(
            "alpha04c preflight only 中文 空格 ",
            [StringComparison]::Ordinal
        )) {
        Remove-Item -LiteralPath $resolvedRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$passedRuns = @(
    $results | Where-Object {
        [int](Get-ResultProperty $_ "fresh_process_exit_code" -1) -eq 0 -and
        [bool](Get-ResultProperty $_ "success" $false)
    }
).Count
$status = if ($script:failures.Count -eq 0) { "PASS" } else { "FAIL" }
Write-Output "COLD_RESTORE_TOP_LEVEL_IMPORT_CHAIN_PREFLIGHT_ONLY|status=$status|checks=$script:checks|failures=$($script:failures.Count)|fresh_process_runs=$freshProcessRuns|passed_runs=$passedRuns/3|quota_delta=0|diagnostic_delta=0|godot_delta=0|save_delta=0|formal_root_write_count=0"
foreach ($failure in $script:failures) {
    Write-Output "FAIL|$failure"
}
if ($script:failures.Count -gt 0) { exit 1 }
exit 0
