[CmdletBinding()]
param([switch]$SupervisionOnly)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$modulePath = Join-Path $projectRoot "scripts/tools/cold_restore_attested_process.psm1"
$orchestratorPath = Join-Path $projectRoot "scripts/tools/cold_restore_vertical_slice_orchestrator.ps1"
$fixturePath = Join-Path $projectRoot "tests/fixtures/cold_restore_attestation_fixture_child.ps1"
$godotFixturePath = "res://tests/fixtures/cold_restore_godot_attestation_fixture.gd"
Import-Module $modulePath -Force

$script:checks = 0
$script:failures = [Collections.Generic.List[string]]::new()
$repositoryHead = "d" * 40
$measurementHead = "c" * 40
$scenarioFingerprint = "a" * 64
$root = Join-Path ([IO.Path]::GetTempPath()) ("space syndicate wrapper 测试 " + [Guid]::NewGuid().ToString("N"))
[IO.Directory]::CreateDirectory($root) | Out-Null

function Assert-WrapperCondition {
    param([bool]$Condition, [string]$Message)
    $script:checks += 1
    if (-not $Condition) {
        $script:failures.Add($Message)
    }
}

function Get-OrchestratorFunctionSource {
    param(
        [Parameter(Mandatory = $true)]$Ast,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $functions = @($Ast.FindAll({
        param($Node)
        $Node -is [Management.Automation.Language.FunctionDefinitionAst]
    }, $true))
    $matches = @($functions | Where-Object { [string]$_.Name -ceq $Name })
    if ($matches.Count -ne 1) {
        return ""
    }
    return [string]$matches[0].Extent.Text
}

function Invoke-TargetedModeConflictFixture {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    $runId = "wrapper-targeted-conflict-$Name-$([Guid]::NewGuid().ToString('N'))"
    $output = @(& (Get-Command pwsh).Source `
        -NoProfile `
        -File $orchestratorPath `
        -ProjectPath $projectRoot `
        -RunId $runId `
        -TargetedOwnerCaptureDiagnostic `
        @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
    $jsonLine = @($output | ForEach-Object { [string]$_ } | Where-Object { $_.StartsWith("{") } | Select-Object -Last 1)
    $result = $null
    if ($jsonLine.Count -eq 1) {
        try {
            $result = $jsonLine[0] | ConvertFrom-Json
        }
        catch {
            $result = $null
        }
    }
    return [pscustomobject]@{
        exit_code = $exitCode
        result = $result
    }
}

function Invoke-FixtureCase {
    param(
        [Parameter(Mandatory = $true)][string]$Mode,
        [int]$TimeoutSeconds = 5,
        [string]$PathSuffix = ""
    )

    $runId = "wrapper-$Mode-$([Guid]::NewGuid().ToString('N'))"
    $caseRoot = Join-Path $root ("case $Mode $PathSuffix")
    if ($PathSuffix -ne "") {
        $caseRoot = Join-Path $caseRoot ("long-segment-" + ("x" * 80))
    }
    $childPath = Join-Path $caseRoot "child/qualification.completion.json"
    $parentPath = Join-Path $caseRoot "parent/qualification.exit.json"
    $stdoutPath = Join-Path $caseRoot "parent/qualification.stdout.log"
    $stderrPath = Join-Path $caseRoot "parent/qualification.stderr.log"
    $arguments = @(
        "-NoProfile",
        "-File", $fixturePath,
        "-ModulePath", $modulePath,
        "-RunId", $runId,
        "-Role", "qualification",
        "-RepositoryHead", $repositoryHead,
        "-ChildAttestationPath", $childPath,
        "-Mode", $Mode
    )
    $result = Invoke-ColdRestoreAttestedProcess `
        -ExecutablePath (Get-Command pwsh).Source `
        -WorkingDirectory $projectRoot `
        -ArgumentList $arguments `
        -RunId $runId `
        -Role "qualification" `
        -RepositoryHead $repositoryHead `
        -ChildAttestationPath $childPath `
        -ParentAttestationPath $parentPath `
        -StdoutPath $stdoutPath `
        -StderrPath $stderrPath `
        -TimeoutSeconds $TimeoutSeconds
    return [pscustomobject]@{
        result = $result
        run_id = $runId
        child_path = $childPath
        parent_path = $parentPath
        stdout_path = $stdoutPath
        stderr_path = $stderrPath
    }
}

function New-WrapperTimeoutPolicy {
    param(
        [int]$ProcessAAbsoluteTimeoutSeconds = 5,
        [int]$ProcessANoProgressTimeoutSeconds = 1
    )

    function New-RoleEntry {
        param(
            [int]$AbsoluteTimeoutSeconds,
            [int]$NoProgressTimeoutSeconds,
            [string]$TimeoutReason,
            [bool]$ContractOnly
        )
        return [pscustomobject][ordered]@{
            absolute_timeout_seconds = $AbsoluteTimeoutSeconds
            no_progress_timeout_seconds = $NoProgressTimeoutSeconds
            timeout_reason_code = $TimeoutReason
            cleanup_policy = "kill_task_tree_then_verify_pid_and_creation_time"
            contract_only_in_this_task = $ContractOnly
        }
    }

    $policy = [pscustomobject][ordered]@{
        schema_version = 1
        policy_id = "ColdRestoreRoleTimeoutPolicyV1"
        policy_source = "alpha04c_wrapper_fixture"
        measurement_head = $measurementHead
        measurement_run_id = "wrapper-policy-fixture"
        poll_interval_ms = 50
        normal_exit_grace_seconds = 2
        stream_drain_grace_seconds = 2
        process_tree_cleanup_grace_seconds = 2
        progress_heartbeat_fields = @(
            "phase",
            "world_time",
            "owner_index",
            "queue_revision",
            "save_phase",
            "last_evidence_write_time"
        )
        roles = [pscustomobject][ordered]@{
            targeted_owner_diagnostic = New-RoleEntry 5 2 "targeted_owner_diagnostic_timeout" $false
            process_a = New-RoleEntry `
                $ProcessAAbsoluteTimeoutSeconds `
                $ProcessANoProgressTimeoutSeconds `
                "process_a_timeout" `
                $false
            process_b = New-RoleEntry 5 2 "process_b_timeout" $true
            process_c = New-RoleEntry 5 2 "process_c_timeout" $true
        }
    }
    return $policy
}

function Invoke-PolicyFixtureCase {
    param(
        [Parameter(Mandatory = $true)][string]$Mode,
        [int]$AbsoluteTimeoutSeconds = 5,
        [int]$NoProgressTimeoutSeconds = 1,
        [string]$PathSuffix = "",
        [string]$ExpectedScenarioFingerprint = $scenarioFingerprint
    )

    $policyRole = "process_a"
    $runId = "wrapper-$Mode-$([Guid]::NewGuid().ToString('N'))"
    $caseRoot = Join-Path $root ("policy case $Mode $PathSuffix")
    if ($PathSuffix -ne "") {
        $caseRoot = Join-Path $caseRoot ("long-segment-" + ("y" * 80))
    }
    $childPath = Join-Path $caseRoot "child/producer.completion.json"
    $parentPath = Join-Path $caseRoot "parent/producer.exit.json"
    $stdoutPath = Join-Path $caseRoot "parent/producer.stdout.log"
    $stderrPath = Join-Path $caseRoot "parent/producer.stderr.log"
    $heartbeatRoot = Join-Path $caseRoot "diagnostics"
    $heartbeatEventDirectory = Join-Path $heartbeatRoot "$policyRole.heartbeat.events"
    $heartbeatPath = Join-Path $heartbeatRoot "$policyRole.heartbeat.json"
    $policy = New-WrapperTimeoutPolicy $AbsoluteTimeoutSeconds $NoProgressTimeoutSeconds
    $policyPath = Join-Path $caseRoot "policy/ColdRestoreRoleTimeoutPolicyV1.json"
    [IO.Directory]::CreateDirectory((Split-Path -Parent $policyPath)) | Out-Null
    [IO.File]::WriteAllText(
        $policyPath,
        ($policy | ConvertTo-Json -Depth 12),
        [Text.UTF8Encoding]::new($false)
    )
    $policyFingerprint = (Get-FileHash -LiteralPath $policyPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $policy = [IO.File]::ReadAllText($policyPath, [Text.UTF8Encoding]::new($false)) | ConvertFrom-Json
    $arguments = @(
        "-NoProfile",
        "-File", $fixturePath,
        "-ModulePath", $modulePath,
        "-RunId", $runId,
        "-Role", "producer",
        "-RepositoryHead", $repositoryHead,
        "-ChildAttestationPath", $childPath,
        "-Mode", $Mode,
        "-ProgressHeartbeatEventDirectory", $heartbeatEventDirectory,
        "-PolicyRole", $policyRole,
        "-PolicyFingerprint", $policyFingerprint
    )
    $result = Invoke-ColdRestoreAttestedProcess `
        -ExecutablePath (Get-Command pwsh).Source `
        -WorkingDirectory $projectRoot `
        -ArgumentList $arguments `
        -RunId $runId `
        -Role "producer" `
        -RepositoryHead $repositoryHead `
        -ChildAttestationPath $childPath `
        -ParentAttestationPath $parentPath `
        -StdoutPath $stdoutPath `
        -StderrPath $stderrPath `
        -TimeoutPolicy $policy `
        -TimeoutPolicyPath $policyPath `
        -ExpectedPolicyFingerprint $policyFingerprint `
        -PolicyRole $policyRole `
        -ProgressHeartbeatEventDirectory $heartbeatEventDirectory `
        -ProgressHeartbeatPath $heartbeatPath `
        -ExpectedScenarioFingerprint $ExpectedScenarioFingerprint
    return [pscustomobject]@{
        result = $result
        policy = $policy
        policy_fingerprint = $policyFingerprint
        policy_path = $policyPath
        parent_path = $parentPath
        heartbeat_path = $heartbeatPath
        stdout_path = $stdoutPath
        stderr_path = $stderrPath
    }
}

try {
    $invokeParameters = (Get-Command Invoke-ColdRestoreAttestedProcess).Parameters.Keys
    $requiredInvokeParameters = @(
        "TimeoutPolicy",
        "TimeoutPolicyPath",
        "ExpectedPolicyFingerprint",
        "ExpectedScenarioFingerprint",
        "PolicyRole",
        "ProgressHeartbeatEventDirectory",
        "ProgressHeartbeatPath"
    )
    Assert-WrapperCondition (@($requiredInvokeParameters | Where-Object {
        $_ -notin $invokeParameters
    }).Count -eq 0) "Invoke-ColdRestoreAttestedProcess must expose the complete role-policy and heartbeat API"

    if (-not $SupervisionOnly) {
    $orchestratorTokens = $null
    $orchestratorParseErrors = $null
    $orchestratorAst = [Management.Automation.Language.Parser]::ParseFile(
        $orchestratorPath,
        [ref]$orchestratorTokens,
        [ref]$orchestratorParseErrors
    )
    $orchestratorSource = Get-Content -LiteralPath $orchestratorPath -Raw -Encoding UTF8
    $moduleSource = Get-Content -LiteralPath $modulePath -Raw -Encoding UTF8
    Assert-WrapperCondition ($orchestratorParseErrors.Count -eq 0) "orchestrator source must parse before targeted diagnostic contracts are inspected"

    $targetedParameter = @($orchestratorAst.ParamBlock.Parameters | Where-Object {
        [string]$_.Name.VariablePath.UserPath -ceq "TargetedOwnerCaptureDiagnostic"
    })
    $authorizationParameter = @($orchestratorAst.ParamBlock.Parameters | Where-Object {
        [string]$_.Name.VariablePath.UserPath -ceq "AuthorizedOfficialColdRestoreCount"
    })
    Assert-WrapperCondition ($targetedParameter.Count -eq 1) "TargetedOwnerCaptureDiagnostic must remain an explicit orchestrator mode"
    Assert-WrapperCondition ($authorizationParameter.Count -eq 1 `
        -and [string]$authorizationParameter[0].DefaultValue.Extent.Text -ceq "0") "Targeted diagnostics must inherit AuthorizedOfficialColdRestoreCount=0"

    $modeGateStart = $orchestratorSource.IndexOf('$selectedModeCount = @(', [StringComparison]::Ordinal)
    $modeGateEnd = if ($modeGateStart -ge 0) {
        $orchestratorSource.IndexOf('if ($ContractManifestPath -ne "")', $modeGateStart, [StringComparison]::Ordinal)
    }
    else {
        -1
    }
    $modeGate = if ($modeGateStart -ge 0 -and $modeGateEnd -gt $modeGateStart) {
        $orchestratorSource.Substring($modeGateStart, $modeGateEnd - $modeGateStart)
    }
    else {
        ""
    }
    $modeGateFragments = @(
        '[bool]$QualificationProbe',
        '[bool]$TargetedOwnerCaptureDiagnostic',
        '[bool]$NonOfficialProcessA',
        '[bool]$EnableColdRestoreExecution',
        '($ContractManifestPath -ne "")',
        'Assert-ColdRestoreCondition ($selectedModeCount -le 1) "execution_mode_conflict"'
    )
    Assert-WrapperCondition (@($modeGateFragments | Where-Object { -not $modeGate.Contains($_) }).Count -eq 0) "TargetedOwnerCaptureDiagnostic must share the mutually exclusive execution-mode gate"

    foreach ($conflict in @(
        [pscustomobject]@{ name = "qualification"; arguments = @("-QualificationProbe") },
        [pscustomobject]@{ name = "non-official-a"; arguments = @("-NonOfficialProcessA") },
        [pscustomobject]@{ name = "official"; arguments = @("-EnableColdRestoreExecution") },
        [pscustomobject]@{ name = "manifest"; arguments = @("-ContractManifestPath", (Join-Path $root "unused-manifest.json")) }
    )) {
        $conflictResult = Invoke-TargetedModeConflictFixture $conflict.name $conflict.arguments
        Assert-WrapperCondition ($conflictResult.exit_code -ne 0 `
            -and $null -ne $conflictResult.result `
            -and -not [bool]$conflictResult.result.success `
            -and [string]$conflictResult.result.failure_code -ceq "execution_mode_conflict") "TargetedOwnerCaptureDiagnostic must reject the $($conflict.name) mode before launch"
    }

    $targetedFunctionSource = Get-OrchestratorFunctionSource $orchestratorAst "Invoke-ColdRestoreTargetedOwnerCaptureDiagnostic"
    $targetedValidationSource = Get-OrchestratorFunctionSource $orchestratorAst "Assert-ColdRestoreTargetedDiagnosticV2"
    $targetedGuardSource = Get-OrchestratorFunctionSource $orchestratorAst "Invoke-ColdRestoreTargetedOwnerCaptureGuarded"
    Assert-WrapperCondition ($targetedFunctionSource.Contains('($AuthorizedOfficialColdRestoreCount -eq 0) "targeted_owner_capture_official_authorization_forbidden"')) "Targeted diagnostics must require AuthorizedOfficialColdRestoreCount=0"
    Assert-WrapperCondition (-not $targetedFunctionSource.Contains("Assert-AndConsumeOfficialColdRestoreAuthorization") `
        -and $targetedFunctionSource.Contains('$launchAuthorization = $diagnosticQuota.launch_authorization') `
        -and $targetedFunctionSource.Contains('-LaunchAuthorization $launchAuthorization') `
        -and $targetedFunctionSource.Contains('-LaunchAttestationPath $launchAttestationPath')) "Targeted diagnostics must use their quota-bound nonofficial launch authorization without consuming official authorization"

    $cleanExitFragments = @(
        '[bool]$run.wrapper_exit_green',
        '-not [bool]$run.child.save_written',
        '[bool]$run.parent.child_attestation_valid',
        '[int]$run.parent.exit_code -eq 0',
        '-not [bool]$run.parent.timed_out',
        '-not [bool]$run.parent.terminated_by_parent',
        '[int]$run.parent.task_owned_process_count_after -eq 0',
        '-not [bool]$diagnostic.save_file_exists',
        '$saveArtifacts.Count -eq 0'
    )
    $targetedClosureSource = $targetedFunctionSource + [Environment]::NewLine + $targetedValidationSource
    Assert-WrapperCondition (@($cleanExitFragments | Where-Object {
        $targetedClosureSource.IndexOf($_, [StringComparison]::OrdinalIgnoreCase) -lt 0
    }).Count -eq 0) "Targeted diagnostics must require zero Save files and a clean attested exit"
    Assert-WrapperCondition ($moduleSource.Contains('catch {`r`n        throw "process_snapshot_failed"'.Replace('`r`n', [Environment]::NewLine)) `
        -or $moduleSource.Contains("catch {`n        throw `"process_snapshot_failed`"")) "Process enumeration failure must fail closed"
    Assert-WrapperCondition ($targetedFunctionSource.Contains('$timeout = Get-ColdRestoreRoleTimeout "targeted_owner_diagnostic"') `
        -and $targetedFunctionSource.Contains('[int]$timeout.absolute_timeout_seconds -eq 120') `
        -and $targetedFunctionSource.Contains('[int]$timeout.no_progress_timeout_seconds -eq 30') `
        -and $targetedFunctionSource.Contains('-ExpectedScenarioFingerprint $ExpectedScenarioFingerprint')) "Targeted diagnostics must bind the authorized 120/30 role policy and scenario"
    Assert-WrapperCondition ($targetedFunctionSource.Contains('$RunId -ceq "alpha04c-owner-capture-diagnostic-$($HeadSha.Substring(0, 12))"')) "Targeted diagnostic identity must bind its run id to the measured HEAD"
    Assert-WrapperCondition ($targetedGuardSource.Contains('Assert-ColdRestoreTargetedOwnerCapturePostconditions $ResolvedProjectPath') `
        -and $targetedGuardSource.Contains('$primaryFailure = $_') `
        -and $targetedGuardSource.Contains('$postconditionFailure = $_') `
        -and $targetedGuardSource.Contains('throw $primaryFailure') `
        -and $targetedGuardSource.Contains('throw $postconditionFailure')) "Targeted Save and privacy scans must run after launch without replacing a primary failure"

    $targetedInvocationIndex = $orchestratorSource.IndexOf('$targetedDiagnostic = Invoke-ColdRestoreTargetedOwnerCaptureGuarded', [StringComparison]::Ordinal)
    $targetedExitIndex = if ($targetedInvocationIndex -ge 0) {
        $orchestratorSource.IndexOf('exit 0', $targetedInvocationIndex, [StringComparison]::Ordinal)
    }
    else {
        -1
    }
    $officialAuthorizationIndex = $orchestratorSource.IndexOf('$authorization = Assert-AndConsumeOfficialColdRestoreAuthorization', [StringComparison]::Ordinal)
    Assert-WrapperCondition ($targetedInvocationIndex -ge 0 `
        -and $targetedExitIndex -gt $targetedInvocationIndex `
        -and $officialAuthorizationIndex -gt $targetedExitIndex) "Targeted diagnostic dispatch must exit before the official authorization path"
    }

    $green = Invoke-FixtureCase "valid_green"
    Assert-WrapperCondition ([bool]$green.result.wrapper_exit_green) "valid child must produce a green wrapper"
    Assert-WrapperCondition ([bool]$green.result.parent.observed_exit -and [int]$green.result.parent.exit_code -eq 0) "parent must observe exact zero exit"
    Assert-WrapperCondition ([bool]$green.result.parent.child_attestation_valid) "parent must validate child completion"
    Assert-WrapperCondition ([int]$green.result.parent.task_owned_process_count_after -eq 0) "valid child must leave no task-owned process"
    Assert-WrapperCondition ((Get-FileHash $green.stdout_path -Algorithm SHA256).Hash.ToLowerInvariant() -eq [string]$green.result.parent.stdout_sha256) "stdout SHA-256 must bind the captured file"
    Assert-WrapperCondition ((Get-FileHash $green.stderr_path -Algorithm SHA256).Hash.ToLowerInvariant() -eq [string]$green.result.parent.stderr_sha256) "stderr SHA-256 must bind the captured file"

    $blocked = Invoke-FixtureCase "valid_blocked"
    Assert-WrapperCondition ([bool]$blocked.result.wrapper_exit_green) "product Queue blocker must keep the wrapper green"
    Assert-WrapperCondition (-not [bool]$blocked.result.child.qualification_green -and [int]$blocked.result.child.queue_count -eq 0) "blocked product result must remain explicit"
    Assert-WrapperCondition ([string]$blocked.result.child.product_blocker -eq "BLOCKED_BY_NO_LEGAL_QUEUE_ACCEPTANCE_SCENARIO") "blocked product result must carry the closed blocker"
    Assert-WrapperCondition ([int]$blocked.result.parent.exit_code -eq 0) "product blocker must exit zero"

    $expectedFaults = [ordered]@{
        missing = "child_attestation_missing"
        truncated = "child_attestation_json_invalid"
        wrong_schema = "child_attestation_schema_invalid"
        wrong_run_id = "child_attestation_run_id_mismatch"
        wrong_role = "child_attestation_role_mismatch"
        wrong_head = "child_attestation_repository_head_mismatch"
        wrong_fingerprint = "child_attestation_fingerprint_invalid"
        stale = "child_attestation_stale"
    }
    foreach ($mode in $expectedFaults.Keys) {
        $fault = Invoke-FixtureCase $mode
        Assert-WrapperCondition (-not [bool]$fault.result.wrapper_exit_green) "$mode must fail the wrapper"
        Assert-WrapperCondition ([string]$fault.result.wrapper_reason_code -eq [string]$expectedFaults[$mode]) "$mode must preserve its exact reason"
    }

    foreach ($mode in @("nonzero", "write_failure", "readback_failure")) {
        $fault = Invoke-FixtureCase $mode
        Assert-WrapperCondition (-not [bool]$fault.result.wrapper_exit_green -and [int]$fault.result.parent.exit_code -ne 0) "$mode must preserve a nonzero Harness exit"
        Assert-WrapperCondition ([string]$fault.result.wrapper_reason_code -eq "child_process_exit_nonzero") "$mode must be classified as a Harness process failure"
    }

    $timeout = Invoke-FixtureCase "timeout" 1
    Assert-WrapperCondition (-not [bool]$timeout.result.wrapper_exit_green -and [bool]$timeout.result.parent.timed_out) "timeout must be explicit"
    Assert-WrapperCondition ([bool]$timeout.result.parent.terminated_by_parent) "timeout must record parent termination"
    Assert-WrapperCondition ([int]$timeout.result.parent.task_owned_process_count_after -eq 0) "timeout cleanup must leave zero task-owned processes"

    $residual = Invoke-FixtureCase "residual"
    Assert-WrapperCondition (-not [bool]$residual.result.wrapper_exit_green) "a surviving descendant must fail the wrapper"
    Assert-WrapperCondition ([bool]$residual.result.parent.terminated_by_parent) "descendant cleanup must be recorded"
    Assert-WrapperCondition ([int]$residual.result.parent.task_owned_process_count_after -eq 0) "descendant cleanup must finish at zero"
    Assert-WrapperCondition (@($residual.result.observed_task_process_identities).Count -ge 2 `
        -and @($residual.result.observed_task_process_identities | Where-Object {
            [int]$_.process_id -le 0 `
                -or [string]$_.creation_time_utc_ticks -notmatch '^[1-9][0-9]{0,18}$' `
                -or ([int64]$_.creation_time_utc_ticks % 10) -ne 0
        }).Count -eq 0) "task ownership must bind every observed PID to exact creation-time ticks"

    $pathCase = Invoke-FixtureCase "valid_green" 5 "中文 path"
    Assert-WrapperCondition ([bool]$pathCase.result.wrapper_exit_green) "space, Unicode, and long paths must round-trip"

    $validPolicy = New-WrapperTimeoutPolicy
    $validPolicyFingerprint = Get-ColdRestoreTextSha256 ($validPolicy | ConvertTo-Json -Depth 12)
    $validPolicyReport = Test-ColdRestoreRoleTimeoutPolicy `
        -Value $validPolicy `
        -ExpectedRepositoryHead $repositoryHead `
        -ExpectedPolicyFingerprint $validPolicyFingerprint `
        -PolicyRole "process_a" `
        -ExpectedProcessRole "producer"
    Assert-WrapperCondition ([bool]$validPolicyReport.valid `
        -and [string]$validPolicyReport.fingerprint -eq $validPolicyFingerprint `
        -and [string]$validPolicy.measurement_head -ne $repositoryHead) "ColdRestoreRoleTimeoutPolicyV1 accepts a distinct measured baseline and binds the supplied raw-file fingerprint"

    $invalidMeasurementPolicy = $validPolicy | ConvertTo-Json -Depth 12 | ConvertFrom-Json
    $invalidMeasurementPolicy.measurement_head = "not-a-sha"
    $invalidMeasurementReport = Test-ColdRestoreRoleTimeoutPolicy `
        -Value $invalidMeasurementPolicy `
        -ExpectedRepositoryHead $repositoryHead `
        -ExpectedPolicyFingerprint $validPolicyFingerprint `
        -PolicyRole "process_a" `
        -ExpectedProcessRole "producer"
    Assert-WrapperCondition (-not [bool]$invalidMeasurementReport.valid `
        -and [string]$invalidMeasurementReport.reason_code -eq "role_timeout_policy_measurement_head_invalid") "measurement_head must remain a legal SHA without equaling the execution HEAD"

    $overCapPolicy = $validPolicy | ConvertTo-Json -Depth 12 | ConvertFrom-Json
    $overCapPolicy.roles.targeted_owner_diagnostic.absolute_timeout_seconds = 121
    $overCapReport = Test-ColdRestoreRoleTimeoutPolicy `
        -Value $overCapPolicy `
        -ExpectedRepositoryHead $repositoryHead `
        -ExpectedPolicyFingerprint $validPolicyFingerprint `
        -PolicyRole "targeted_owner_diagnostic" `
        -ExpectedProcessRole "producer"
    Assert-WrapperCondition (-not [bool]$overCapReport.valid `
        -and [string]$overCapReport.reason_code -eq "role_timeout_policy_entry_bound_invalid") "role policy rejects a targeted diagnostic absolute timeout above 120 seconds"

    foreach ($capCase in @(
        [pscustomobject]@{ role = "process_a"; value = 181; process_role = "producer" },
        [pscustomobject]@{ role = "process_b"; value = 361; process_role = "consumer" },
        [pscustomobject]@{ role = "process_c"; value = 181; process_role = "validator" }
    )) {
        $overRoleCapPolicy = $validPolicy | ConvertTo-Json -Depth 12 | ConvertFrom-Json
        $overRoleCapPolicy.roles.($capCase.role).absolute_timeout_seconds = $capCase.value
        $overRoleCapReport = Test-ColdRestoreRoleTimeoutPolicy `
            -Value $overRoleCapPolicy `
            -ExpectedRepositoryHead $repositoryHead `
            -ExpectedPolicyFingerprint $validPolicyFingerprint `
            -PolicyRole $capCase.role `
            -ExpectedProcessRole $capCase.process_role
        Assert-WrapperCondition (-not [bool]$overRoleCapReport.valid `
            -and [string]$overRoleCapReport.reason_code -eq "role_timeout_policy_entry_bound_invalid") "$($capCase.role) rejects an absolute timeout above its authorized cap"
    }

    $extraFieldPolicy = $validPolicy | ConvertTo-Json -Depth 12 | ConvertFrom-Json
    $extraFieldPolicy | Add-Member -NotePropertyName unexpected_timeout_override -NotePropertyValue 9
    $extraFieldReport = Test-ColdRestoreRoleTimeoutPolicy `
        -Value $extraFieldPolicy `
        -ExpectedRepositoryHead $repositoryHead `
        -ExpectedPolicyFingerprint $validPolicyFingerprint `
        -PolicyRole "process_a" `
        -ExpectedProcessRole "producer"
    Assert-WrapperCondition (-not [bool]$extraFieldReport.valid `
        -and [string]$extraFieldReport.reason_code -eq "role_timeout_policy_field_set_invalid") "role policy rejects unknown override fields"

    $wrongCaseRoleReport = Test-ColdRestoreRoleTimeoutPolicy `
        -Value $validPolicy `
        -ExpectedRepositoryHead $repositoryHead `
        -ExpectedPolicyFingerprint $validPolicyFingerprint `
        -PolicyRole "PROCESS_A" `
        -ExpectedProcessRole "producer"
    Assert-WrapperCondition (-not [bool]$wrongCaseRoleReport.valid `
        -and [string]$wrongCaseRoleReport.reason_code -eq "role_timeout_policy_role_invalid") "role IDs are exact and case-sensitive"

    $policyGreen = Invoke-PolicyFixtureCase "policy_green" 5 1 "中文 heartbeat path"
    $policyGreenHeartbeat = Get-Content -LiteralPath $policyGreen.heartbeat_path -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-WrapperCondition ([bool]$policyGreen.result.wrapper_exit_green `
        -and [int]$policyGreen.result.parent.schema_version -eq 2 `
        -and [string]$policyGreen.result.parent.policy_role -eq "process_a" `
        -and [string]$policyGreen.result.parent.timeout_kind -eq "none") "semantic heartbeat progress produces a green ParentExitAttestationV2"
    Assert-WrapperCondition ([string]$policyGreen.result.parent.timeout_policy_fingerprint -eq [string]$policyGreen.policy_fingerprint `
        -and [string]$policyGreen.result.timeout_policy_fingerprint -eq ((Get-FileHash -LiteralPath $policyGreen.policy_path -Algorithm SHA256).Hash.ToLowerInvariant()) `
        -and [string]$policyGreen.policy.measurement_head -eq $measurementHead `
        -and [string]$policyGreenHeartbeat.repository_head -eq $repositoryHead `
        -and [string]$policyGreen.result.parent.progress_heartbeat_fingerprint -eq [string]$policyGreenHeartbeat.evidence_fingerprint `
        -and [string]$policyGreen.result.parent.progress_semantic_fingerprint -match '^[0-9a-f]{64}$' `
        -and [int]$policyGreen.result.parent.progress_heartbeat_sequence -eq 3 `
        -and [string]$policyGreen.result.parent.progress_phase -eq "quit_requested") "Parent Exit binds the exact timeout policy and final heartbeat evidence"
    Assert-WrapperCondition ([string]$policyGreen.result.parent.task_owned_process_identity_fingerprint -match '^[0-9a-f]{64}$' `
        -and @($policyGreen.result.observed_task_process_identities).Count -ge 1) "Parent Exit fingerprints PID plus creation-time ownership"

    $scenarioMismatch = Invoke-PolicyFixtureCase "policy_green" 5 1 "scenario mismatch" ("b" * 64)
    Assert-WrapperCondition (-not [bool]$scenarioMismatch.result.wrapper_exit_green `
        -and [string]$scenarioMismatch.result.wrapper_reason_code -eq "child_attestation_scenario_fingerprint_mismatch" `
        -and [int]$scenarioMismatch.result.parent.task_owned_process_count_after -eq 0) "Wrapper rejects a Child attestation from a different scenario and leaves no owned process"

    $mutatedPolicyRoot = Join-Path $root "mutated policy object"
    $mutatedPolicyPath = Join-Path $mutatedPolicyRoot "ColdRestoreRoleTimeoutPolicyV1.json"
    [IO.Directory]::CreateDirectory($mutatedPolicyRoot) | Out-Null
    $mutatedPolicy = New-WrapperTimeoutPolicy 5 1
    [IO.File]::WriteAllText($mutatedPolicyPath, ($mutatedPolicy | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false))
    $mutatedPolicyFingerprint = (Get-FileHash -LiteralPath $mutatedPolicyPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $mutatedPolicyObject = [IO.File]::ReadAllText($mutatedPolicyPath, [Text.UTF8Encoding]::new($false)) | ConvertFrom-Json
    $mutatedPolicyObject.roles.process_a.absolute_timeout_seconds = 4
    $mutatedPolicyRejected = $false
    try {
        $null = Invoke-ColdRestoreAttestedProcess `
            -ExecutablePath (Get-Command pwsh).Source `
            -WorkingDirectory $projectRoot `
            -ArgumentList @("-NoProfile", "-Command", "exit 0") `
            -RunId "wrapper-mutated-policy-$([Guid]::NewGuid().ToString('N'))" `
            -Role "producer" `
            -RepositoryHead $repositoryHead `
            -ChildAttestationPath (Join-Path $mutatedPolicyRoot "child/producer.completion.json") `
            -ParentAttestationPath (Join-Path $mutatedPolicyRoot "parent/producer.exit.json") `
            -StdoutPath (Join-Path $mutatedPolicyRoot "parent/producer.stdout.log") `
            -StderrPath (Join-Path $mutatedPolicyRoot "parent/producer.stderr.log") `
            -TimeoutPolicy $mutatedPolicyObject `
            -TimeoutPolicyPath $mutatedPolicyPath `
            -ExpectedPolicyFingerprint $mutatedPolicyFingerprint `
            -PolicyRole "process_a" `
            -ProgressHeartbeatEventDirectory (Join-Path $mutatedPolicyRoot "heartbeat.events") `
            -ProgressHeartbeatPath (Join-Path $mutatedPolicyRoot "heartbeat.json") `
            -ExpectedScenarioFingerprint $scenarioFingerprint
    }
    catch {
        $mutatedPolicyRejected = [string]$_.Exception.Message -ceq "role_timeout_policy_content_mismatch"
    }
    Assert-WrapperCondition $mutatedPolicyRejected "Wrapper independently rejects a mutated policy object even when the policy file and supplied fingerprint still match"

    $noProgress = Invoke-PolicyFixtureCase "policy_no_progress" 4 1
    Assert-WrapperCondition (-not [bool]$noProgress.result.wrapper_exit_green `
        -and [bool]$noProgress.result.parent.timed_out `
        -and [bool]$noProgress.result.parent.terminated_by_parent `
        -and [string]$noProgress.result.parent.timeout_kind -eq "no_progress" `
        -and [string]$noProgress.result.wrapper_reason_code -eq "process_a_no_progress_timeout" `
        -and [int]$noProgress.result.parent.task_owned_process_count_after -eq 0) "timestamp-only heartbeat writes and stdout cannot renew the semantic progress lease"

    $absolute = Invoke-PolicyFixtureCase "policy_absolute" 2 1
    Assert-WrapperCondition (-not [bool]$absolute.result.wrapper_exit_green `
        -and [bool]$absolute.result.parent.timed_out `
        -and [string]$absolute.result.parent.timeout_kind -eq "absolute" `
        -and [string]$absolute.result.wrapper_reason_code -eq "process_a_absolute_timeout" `
        -and [int]$absolute.result.parent.progress_heartbeat_sequence -ge 2) "semantic progress cannot extend the absolute role deadline"

    $heartbeatFaults = [ordered]@{
        policy_bad_fingerprint = "progress_heartbeat_fingerprint_invalid"
        policy_wrong_run = "progress_heartbeat_run_id_mismatch"
        policy_wrong_head = "progress_heartbeat_repository_head_mismatch"
        policy_wrong_policy = "progress_heartbeat_policy_fingerprint_mismatch"
        policy_wrong_heartbeat_id = "progress_heartbeat_schema_invalid"
        policy_sequence_gap = "progress_heartbeat_sequence_invalid"
    }
    foreach ($mode in $heartbeatFaults.Keys) {
        $heartbeatFault = Invoke-PolicyFixtureCase $mode 5 2
        Assert-WrapperCondition (-not [bool]$heartbeatFault.result.wrapper_exit_green `
            -and -not [bool]$heartbeatFault.result.parent.timed_out `
            -and [bool]$heartbeatFault.result.parent.terminated_by_parent `
            -and [string]$heartbeatFault.result.wrapper_reason_code -eq [string]$heartbeatFaults[$mode] `
            -and [int]$heartbeatFault.result.parent.task_owned_process_count_after -eq 0) "$mode must fail closed and clean only the identity-pinned process tree"
    }

    $missingHeartbeat = Invoke-PolicyFixtureCase "policy_missing" 5 2
    Assert-WrapperCondition (-not [bool]$missingHeartbeat.result.wrapper_exit_green `
        -and [string]$missingHeartbeat.result.wrapper_reason_code -eq "progress_heartbeat_missing" `
        -and [bool]$missingHeartbeat.result.parent.child_attestation_valid `
        -and -not [bool]$missingHeartbeat.result.parent.progress_heartbeat_found) "a zero-exit child without heartbeat evidence fails closed"

    $exclusivePath = Join-Path $root "exclusive/official_claim_ledger.json"
    $exclusiveValue = [pscustomobject][ordered]@{ schema_version = 1; authorization_id = "fixture" }
    $exclusiveFingerprint = Write-ColdRestoreExclusiveJson $exclusivePath $exclusiveValue
    $exclusiveSecondWriteRejected = $false
    try {
        $null = Write-ColdRestoreExclusiveJson $exclusivePath ([pscustomobject]@{ attempted_run_id = "different-run-id" })
    }
    catch {
        $exclusiveSecondWriteRejected = $true
    }
    $exclusiveReadback = Get-Content -LiteralPath $exclusivePath -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-WrapperCondition ($exclusiveFingerprint -match '^[0-9a-f]{64}$') "exclusive claim writer returns a stable SHA-256 fingerprint"
    Assert-WrapperCondition ($exclusiveSecondWriteRejected -and [string]$exclusiveReadback.authorization_id -eq "fixture") "a different RunId cannot mint or overwrite another authorization at the fixed claim path"

    $racePath = Join-Path $root "exclusive-race/official_claim_ledger.json"
    $raceStartTicks = [DateTime]::UtcNow.AddMilliseconds(500).Ticks.ToString([Globalization.CultureInfo]::InvariantCulture)
    $raceJobs = foreach ($raceRunId in @("run-id-alpha", "run-id-beta")) {
        Start-Job -ScriptBlock {
            param($ImportedModulePath, $TargetPath, $CandidateRunId, $StartTicks)
            Import-Module $ImportedModulePath -Force
            $startAt = [DateTime]::new([int64]$StartTicks, [DateTimeKind]::Utc)
            while ([DateTime]::UtcNow -lt $startAt) { Start-Sleep -Milliseconds 5 }
            try {
                $null = Write-ColdRestoreExclusiveJson $TargetPath ([pscustomobject][ordered]@{ schema_version = 1; run_id = $CandidateRunId })
                [pscustomobject]@{ run_id = $CandidateRunId; won = $true }
            }
            catch {
                [pscustomobject]@{ run_id = $CandidateRunId; won = $false }
            }
        } -ArgumentList $modulePath, $racePath, $raceRunId, $raceStartTicks
    }
    $raceResults = @($raceJobs | Wait-Job | Receive-Job)
    $raceJobs | Remove-Job -Force
    $raceWinner = Get-Content -LiteralPath $racePath -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-WrapperCondition (@($raceResults | Where-Object { [bool]$_.won }).Count -eq 1 `
        -and @($raceResults | Where-Object { -not [bool]$_.won }).Count -eq 1 `
        -and [string]$raceWinner.run_id -in @("run-id-alpha", "run-id-beta")) "two different RunIds racing the fixed path consume exactly one authorization"

    $launchRunId = "wrapper-launch-$([Guid]::NewGuid().ToString('N'))"
    $launchRoot = Join-Path $root "launch-case"
    $launchChild = Join-Path $launchRoot "child/producer.completion.json"
    $launchParent = Join-Path $launchRoot "parent/producer.exit.json"
    $launchStdout = Join-Path $launchRoot "parent/producer.stdout.log"
    $launchStderr = Join-Path $launchRoot "parent/producer.stderr.log"
    $launchPath = Join-Path $launchRoot "launch/producer.authorized.json"
    $launchArguments = @(
        "-NoProfile",
        "-File", $fixturePath,
        "-ModulePath", $modulePath,
        "-RunId", $launchRunId,
        "-Role", "producer",
        "-RepositoryHead", $repositoryHead,
        "-ChildAttestationPath", $launchChild,
        "-Mode", "valid_green"
    )
    $launchContext = [pscustomobject][ordered]@{
        authorization_id = "alpha04c-p0-cold-restore-depth1-seed900626424-v1"
        claim_fingerprint = "a" * 64
        claim_nonce = "b" * 32
        source_head_sha = $repositoryHead
        scenario_fingerprint = "c" * 64
        run_id = $launchRunId
        process_role = "producer"
        launch_nonce = "d" * 32
        orchestrator_process_id = $PID
        orchestrator_creation_time_utc_ticks = ([Diagnostics.Process]::GetCurrentProcess().StartTime.ToUniversalTime().Ticks).ToString([Globalization.CultureInfo]::InvariantCulture)
    }
    $launchRun = Invoke-ColdRestoreAttestedProcess `
        -ExecutablePath (Get-Command pwsh).Source `
        -WorkingDirectory $projectRoot `
        -ArgumentList $launchArguments `
        -RunId $launchRunId `
        -Role "producer" `
        -RepositoryHead $repositoryHead `
        -ChildAttestationPath $launchChild `
        -ParentAttestationPath $launchParent `
        -StdoutPath $launchStdout `
        -StderrPath $launchStderr `
        -TimeoutSeconds 5 `
        -LaunchAttestationPath $launchPath `
        -LaunchAuthorization $launchContext
    $launchEvidence = Get-Content -LiteralPath $launchPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-WrapperCondition ([bool]$launchRun.wrapper_exit_green) "a launch-authorized child preserves ChildCompletionAttestationV1 and ParentExitAttestationV1"
    Assert-WrapperCondition ([int]$launchEvidence.wrapper_process_id -eq [int]$launchRun.parent.child_pid -and [int]$launchEvidence.engine_process_id -eq [int]$launchRun.parent.child_pid) "launch attestation binds the exact wrapper/engine process for a direct child"
    Assert-WrapperCondition ([int]$launchEvidence.orchestrator_process_id -eq $PID -and [string]$launchEvidence.launch_nonce -eq [string]$launchContext.launch_nonce) "launch attestation binds orchestrator identity and one role nonce"

    $engineArguments = New-ColdRestoreGodotArgumentList `
        -EngineArgumentList @("--headless", "--check-only", "--path", $projectRoot, "--script", "res://tests/smoke_test.gd") `
        -UserArgumentList @("--cold-restore-contract-only")
    $separatorIndex = [Array]::IndexOf($engineArguments, "--")
    $checkOnlyIndex = [Array]::IndexOf($engineArguments, "--check-only")
    Assert-WrapperCondition ($checkOnlyIndex -ge 0 -and $checkOnlyIndex -lt $separatorIndex) "--check-only must be before the user separator"
    $rejectedEngineArgument = $false
    try {
        $null = New-ColdRestoreGodotArgumentList -EngineArgumentList @("--headless") -UserArgumentList @("--check-only")
    }
    catch {
        $rejectedEngineArgument = $_.Exception.Message -eq "godot_engine_argument_after_separator"
    }
    Assert-WrapperCondition $rejectedEngineArgument "engine-only arguments after -- must fail closed"

    $godotCommand = (Get-Command godot -CommandType Application).Source
    $godotConsole = @(
        Get-ChildItem -LiteralPath (Split-Path -Parent $godotCommand) -Filter "Godot*_console.exe" -File
    )[0].FullName
    $godotRunId = "wrapper-godot-$([Guid]::NewGuid().ToString('N'))"
    $godotRoot = Join-Path $projectRoot ".godot/cold_restore_attestation_v1/$godotRunId"
    $godotLaunchPath = Join-Path $godotRoot "launch/qualification.authorized.json"
    $godotLaunchContext = [pscustomobject][ordered]@{
        authorization_id = "alpha04c-p0-cold-restore-depth1-seed900626424-v1"
        claim_fingerprint = "1" * 64
        claim_nonce = "2" * 32
        source_head_sha = $repositoryHead
        scenario_fingerprint = "3" * 64
        run_id = $godotRunId
        process_role = "qualification"
        launch_nonce = "4" * 32
        orchestrator_process_id = $PID
        orchestrator_creation_time_utc_ticks = ([Diagnostics.Process]::GetCurrentProcess().StartTime.ToUniversalTime().Ticks).ToString([Globalization.CultureInfo]::InvariantCulture)
    }
    $godotArguments = New-ColdRestoreGodotArgumentList `
        -EngineArgumentList @("--headless", "--path", $projectRoot, "--script", $godotFixturePath) `
        -UserArgumentList @("--fixture-run-id=$godotRunId", "--fixture-repository-head=$repositoryHead", "--cold-restore-launch-nonce=$($godotLaunchContext.launch_nonce)")
    $godotRun = Invoke-ColdRestoreAttestedProcess `
        -ExecutablePath $godotConsole `
        -WorkingDirectory $projectRoot `
        -ArgumentList $godotArguments `
        -RunId $godotRunId `
        -Role "qualification" `
        -RepositoryHead $repositoryHead `
        -ChildAttestationPath (Join-Path $godotRoot "child/qualification.completion.json") `
        -ParentAttestationPath (Join-Path $godotRoot "parent/qualification.exit.json") `
        -StdoutPath (Join-Path $godotRoot "parent/qualification.stdout.log") `
        -StderrPath (Join-Path $godotRoot "parent/qualification.stderr.log") `
        -TimeoutSeconds 10 `
        -LaunchAttestationPath $godotLaunchPath `
        -LaunchAuthorization $godotLaunchContext
    Assert-WrapperCondition ([bool]$godotRun.wrapper_exit_green) "real Godot console wrapper and engine child must complete one attested run"
    $enginePidMatch = [regex]::Match([string]$godotRun.stdout, 'GODOT_ATTESTATION_FIXTURE\|pid=(\d+)')
    $enginePid = if ($enginePidMatch.Success) { [int]$enginePidMatch.Groups[1].Value } else { 0 }
    Assert-WrapperCondition ($enginePid -gt 0 -and @($godotRun.observed_task_process_ids) -contains $enginePid) "parent must observe the real Godot engine PID behind the console wrapper"
    $godotLaunchEvidence = Get-Content -LiteralPath $godotLaunchPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-WrapperCondition ([int]$godotLaunchEvidence.engine_process_id -eq $enginePid `
        -and [int]$godotLaunchEvidence.wrapper_process_id -eq [int]$godotRun.parent.child_pid `
        -and [int]$godotLaunchEvidence.engine_process_id -ne [int]$godotLaunchEvidence.wrapper_process_id `
        -and [int]$godotLaunchEvidence.engine_parent_process_id -eq [int]$godotLaunchEvidence.wrapper_process_id) "real Godot launch attestation waits for and binds OS.get_process_id behind the console executable"
    Assert-WrapperCondition ([int]$godotRun.parent.task_owned_process_count_after -eq 0) "real console wrapper and engine must both exit"

    $duplicateRoot = Join-Path $root "duplicate"
    $duplicateChild = Join-Path $duplicateRoot "child/qualification.completion.json"
    [IO.Directory]::CreateDirectory((Split-Path -Parent $duplicateChild)) | Out-Null
    [IO.File]::WriteAllText($duplicateChild, "{}", [Text.UTF8Encoding]::new($false))
    $duplicateRun = "wrapper-duplicate-$([Guid]::NewGuid().ToString('N'))"
    $duplicateResult = Invoke-ColdRestoreAttestedProcess `
        -ExecutablePath (Get-Command pwsh).Source `
        -WorkingDirectory $projectRoot `
        -ArgumentList @("-NoProfile", "-Command", "exit 0") `
        -RunId $duplicateRun `
        -Role "qualification" `
        -RepositoryHead $repositoryHead `
        -ChildAttestationPath $duplicateChild `
        -ParentAttestationPath (Join-Path $duplicateRoot "parent/qualification.exit.json") `
        -StdoutPath (Join-Path $duplicateRoot "parent/stdout.log") `
        -StderrPath (Join-Path $duplicateRoot "parent/stderr.log") `
        -TimeoutSeconds 5
    Assert-WrapperCondition (-not [bool]$duplicateResult.wrapper_exit_green -and [string]$duplicateResult.wrapper_reason_code -eq "evidence_collision") "duplicate final attestation must fail before launch"

    if ($script:failures.Count -gt 0) {
        foreach ($failure in $script:failures) {
            Write-Error "WRAPPER ATTESTATION FAILURE: $failure"
        }
        exit 1
    }
    Write-Output "WRAPPER ATTESTATION PASS $script:checks checks"
    exit 0
}
finally {
    $resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    $resolvedRoot = [IO.Path]::GetFullPath($root)
    if ($resolvedRoot.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase) `
        -and [IO.Directory]::Exists($resolvedRoot)) {
        Remove-Item -LiteralPath $resolvedRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    $godotEvidenceRoot = Join-Path $projectRoot ".godot/cold_restore_attestation_v1"
    if (Test-Path -LiteralPath $godotEvidenceRoot -PathType Container) {
        Get-ChildItem -LiteralPath $godotEvidenceRoot -Directory -Filter "wrapper-godot-*" | ForEach-Object {
            $resolvedCandidate = [IO.Path]::GetFullPath($_.FullName)
            $resolvedEvidenceRoot = [IO.Path]::GetFullPath($godotEvidenceRoot)
            if ($resolvedCandidate.StartsWith($resolvedEvidenceRoot, [StringComparison]::OrdinalIgnoreCase)) {
                Remove-Item -LiteralPath $resolvedCandidate -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
