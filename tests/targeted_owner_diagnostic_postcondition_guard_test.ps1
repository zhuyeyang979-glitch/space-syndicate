[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$orchestratorPath = Join-Path $projectRoot "scripts/tools/cold_restore_vertical_slice_orchestrator.ps1"
$preQuotaModulePath = Join-Path $projectRoot "scripts/tools/cold_restore_prequota_bootstrap.psm1"
$authorizationModulePath = Join-Path $projectRoot "scripts/tools/cold_restore_authorization_contract_v1.psm1"
$authorizationContractPath = Join-Path $projectRoot "scripts/tools/cold_restore_authorization_contract_v1.json"
Import-Module $authorizationModulePath
Import-Module $preQuotaModulePath
$targetedAuthorizationName = Get-ColdRestoreCurrentTargetedDiagnosticAuthorizationName
$targetedAuthorization = Get-ColdRestoreAuthorizationEntry $targetedAuthorizationName
$testRoot = Join-Path ([IO.Path]::GetTempPath()) (
    "alpha04c-targeted-postcondition-" + [Guid]::NewGuid().ToString("N")
)
$script:checks = 0
$script:failures = [Collections.Generic.List[string]]::new()
$script:primaryReason = ""
$script:postconditionReason = ""
$script:diagnosticCalls = 0
$script:postconditionCalls = 0
$script:quotaWrites = 0
$script:evidenceWrites = 0
$script:godotStarts = 0

function Assert-ContractCondition {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    $script:checks += 1
    if (-not $Condition) {
        $script:failures.Add($Message)
    }
}

function Get-FunctionAst {
    param(
        [Parameter(Mandatory = $true)]$Ast,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $matches = @($Ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst]
    }, $true) | Where-Object { [string]$_.Name -ceq $Name })
    if ($matches.Count -ne 1) {
        return $null
    }
    return $matches[0]
}

function Get-ThrownReason {
    param([Parameter(Mandatory = $true)][scriptblock]$Action)

    try {
        & $Action
    }
    catch {
        return [string]$_.Exception.Message
    }
    return ""
}

function Assert-ColdRestoreCondition {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$FailureCode
    )

    if (-not $Condition) {
        throw $FailureCode
    }
}

function Assert-ColdRestoreOfficialAttemptBoundary {
    param([Parameter(Mandatory = $true)][string]$ResolvedProjectPath)

    return [pscustomobject]@{ attempt_1_valid = $true; attempt_2_absent = $true }
}

function Resolve-ColdRestoreGitCommonDirectory {
    param([Parameter(Mandatory = $true)][string]$ResolvedProjectPath)
    return $testRoot
}

function Assert-ColdRestoreTargetedDiagnosticRemoteCheckpoint {
    param([string]$ResolvedProjectPath, [string]$ExpectedHead)
    return [pscustomobject]@{ remote_head_matches_local = $true }
}

function Get-ColdRestoreRuntimeFreezeObservation {
    param([string]$ResolvedProjectPath, [string]$ExpectedHead)

    return [pscustomobject]@{ expected_head = $ExpectedHead; tree_clean = $true }
}

function Assert-ColdRestoreRuntimeFreezeGreen {
    param($Observation, [string]$FailureCode)

    return $true
}

function New-ColdRestorePreQuotaContext {
    param(
        [string]$GitCommonDirectory,
        [string]$BootstrapRoot,
        [string]$RunId,
        [string]$RepositoryHead,
        [string]$Branch,
        [string]$AuthorizationId,
        [string]$QuotaLedgerPath
    )
    return [pscustomobject]@{
        attestation_path = Join-Path $testRoot "prequota.json"
        attestation_sha256 = "a" * 64
        value = [pscustomobject]@{ attestation_fingerprint = "b" * 64 }
        admission_path = Join-Path $testRoot "bootstrap.json"
        admission_sha256 = "c" * 64
        admission_fingerprint = "d" * 64
    }
}

function Update-ColdRestorePreQuotaAttestation {
    param($Context, $Updates, $FailureState)
    return [pscustomobject]@{ valid = $true }
}

function Get-ColdRestoreRolePaths {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedProjectPath,
        [Parameter(Mandatory = $true)][string]$Role
    )

    return [pscustomobject]@{
        stdout = Join-Path $testRoot "producer.stdout.log"
        stderr = Join-Path $testRoot "producer.stderr.log"
    }
}

function Invoke-ColdRestoreTargetedOwnerCaptureDiagnostic {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedProjectPath,
        [Parameter(Mandatory = $true)][string]$HeadSha,
        [Parameter(Mandatory = $true)]$PreQuotaContext,
        [Parameter(Mandatory = $true)]$FailureState
    )

    $script:diagnosticCalls += 1
    if (-not [string]::IsNullOrEmpty($script:primaryReason)) {
        throw $script:primaryReason
    }
    return [pscustomobject]@{ fixture = "diagnostic-success" }
}

function Consume-ColdRestoreTargetedOwnerCaptureDiagnosticQuota {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedProjectPath,
        [Parameter(Mandatory = $true)][string]$HeadSha
    )

    $script:quotaWrites += 1
    throw "synthetic_quota_writer_must_not_run"
}

function Invoke-ColdRestoreAttestedProcess {
    $script:godotStarts += 1
    throw "synthetic_godot_launcher_must_not_run"
}

function Write-ColdRestoreAtomicJson {
    $script:evidenceWrites += 1
    throw "synthetic_evidence_writer_must_not_run"
}

function Assert-ColdRestoreTargetedOwnerCapturePostconditions {
    param([Parameter(Mandatory = $true)][string]$ResolvedProjectPath)

    $script:postconditionCalls += 1
    if (-not [string]::IsNullOrEmpty($script:postconditionReason)) {
        throw $script:postconditionReason
    }
}

function Reset-SyntheticCase {
    $script:primaryReason = ""
    $script:postconditionReason = ""
    $script:diagnosticCalls = 0
    $script:postconditionCalls = 0
}

try {
    [IO.Directory]::CreateDirectory($testRoot) | Out-Null
    [IO.File]::WriteAllText(
        (Join-Path $testRoot "unrelated.log"),
        "fixture",
        [Text.UTF8Encoding]::new($false)
    )

    $tokens = $null
    $parseErrors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile(
        $orchestratorPath,
        [ref]$tokens,
        [ref]$parseErrors
    )
    Assert-ContractCondition (@($parseErrors).Count -eq 0) "orchestrator parses"

    $postconditions = Get-FunctionAst $ast "Assert-ColdRestoreTargetedOwnerCapturePostconditions"
    $guarded = Get-FunctionAst $ast "Invoke-ColdRestoreTargetedOwnerCaptureGuarded"
    $targetedInvoke = Get-FunctionAst $ast "Invoke-ColdRestoreTargetedOwnerCaptureDiagnostic"
    $outputBuilder = Get-FunctionAst $ast "New-ColdRestoreTargetedOwnerCaptureOutput"
    Assert-ContractCondition ($null -ne $postconditions) "targeted postconditions exist exactly once"
    Assert-ContractCondition ($null -ne $guarded) "guarded targeted invocation exists exactly once"
    Assert-ContractCondition ($null -ne $targetedInvoke) "targeted diagnostic invocation exists exactly once"
    Assert-ContractCondition ($null -ne $outputBuilder) "targeted diagnostic output builder exists exactly once"

    if ($null -ne $outputBuilder) {
        . ([scriptblock]::Create($outputBuilder.Extent.Text))
        $script:RunId = Get-ColdRestoreAuthorizationRunId `
            $targetedAuthorizationName ("a" * 40)
        $script:TargetedOwnerCaptureDriverId = "alpha04c_$targetedAuthorizationName"
        foreach ($case in @(
            [pscustomobject]@{ kind = "ALL_OWNERS_CAPTURED"; success = $true; code = "" },
            [pscustomobject]@{ kind = "OWNER_CAPTURE_FAILURE"; success = $false; code = "owner_capture_failed" },
            [pscustomobject]@{ kind = "POST_CAPTURE_FAILURE"; success = $false; code = "owner_capture_post_validation_failed" },
            [pscustomobject]@{ kind = "PRE_OWNER_FAILURE"; success = $false; code = "owner_diagnostic_pre_audit_failure" }
        )) {
            $fixture = [pscustomobject]@{
                diagnostic_result_kind = $case.kind
                diagnostic_path = Join-Path $testRoot "diagnostic.json"
                diagnostic = [pscustomobject]@{
                    first_failure = [pscustomobject]@{}
                    post_capture_failure = [pscustomobject]@{}
                    repository_head = "a" * 40
                    scenario_identity_attested = $false
                    registry_binding_attested = $case.kind -ne "PRE_OWNER_FAILURE"
                    scenario_identity = [pscustomobject]@{}
                    scenario_identity_failure = [pscustomobject]@{}
                    owner_audit_started = $case.kind -ne "PRE_OWNER_FAILURE"
                    owner_audit_completed = $case.kind -in @("ALL_OWNERS_CAPTURED", "OWNER_CAPTURE_FAILURE", "POST_CAPTURE_FAILURE")
                    first_owner_capture_index = -1
                    last_completed_owner_capture_index = $(if ($case.kind -eq "ALL_OWNERS_CAPTURED") { 18 } else { -1 })
                    owner_capture_attempted_count = $(if ($case.kind -eq "ALL_OWNERS_CAPTURED") { 19 } else { 0 })
                    owner_capture_succeeded_count = $(if ($case.kind -eq "ALL_OWNERS_CAPTURED") { 19 } else { 0 })
                    owner_capture_failed_count = $(if ($case.kind -eq "OWNER_CAPTURE_FAILURE") { 1 } else { 0 })
                    post_capture_validation = $(if ($case.kind -eq "ALL_OWNERS_CAPTURED") { "PASSED" } else { "NOT_RUN" })
                }
                run = [pscustomobject]@{ parent = [pscustomobject]@{
                    child_attestation_valid = $true
                    wrapper_exit_green = $true
                    exit_code = 0
                    timed_out = $false
                    terminated_by_parent = $false
                    task_owned_process_count_after = 0
                } }
                prequota = [pscustomobject]@{
                    path = "prequota.json"; sha256 = "1" * 64; fingerprint = "2" * 64
                    admission_sha256 = "3" * 64; admission_fingerprint = "4" * 64
                }
            }
            $output = New-ColdRestoreTargetedOwnerCaptureOutput $fixture
            Assert-ContractCondition (
                [bool]$output.success -eq [bool]$case.success `
                    -and [bool]$output.process_a_rehearsal_authorized -eq [bool]$case.success `
                    -and [string]$output.failure_code -ceq [string]$case.code
            ) "only ALL_OWNERS_CAPTURED authorizes Process A rehearsal ($($case.kind))"
        }
    }

    if ($null -ne $postconditions) {
        $script:UserDataRoot = $testRoot
        . ([scriptblock]::Create($postconditions.Extent.Text))
        $emptyArtifactReason = Get-ThrownReason {
            Assert-ColdRestoreTargetedOwnerCapturePostconditions $projectRoot
        }
        Assert-ContractCondition ($emptyArtifactReason -ceq "") "empty Save artifact set is accepted under StrictMode"

        $savePath = Join-Path $testRoot "saves/forbidden.save"
        [IO.Directory]::CreateDirectory((Split-Path -Parent $savePath)) | Out-Null
        [IO.File]::WriteAllText($savePath, "forbidden", [Text.UTF8Encoding]::new($false))
        $saveArtifactReason = Get-ThrownReason {
            Assert-ColdRestoreTargetedOwnerCapturePostconditions $projectRoot
        }
        Assert-ContractCondition ($saveArtifactReason -ceq "targeted_owner_capture_unexpected_save") "Save artifacts remain fail closed"
        [IO.File]::Delete($savePath)
        [IO.Directory]::Delete((Split-Path -Parent $savePath))
    }

    function Assert-ColdRestoreTargetedOwnerCapturePostconditions {
        param([Parameter(Mandatory = $true)][string]$ResolvedProjectPath)

        $script:postconditionCalls += 1
        if (-not [string]::IsNullOrEmpty($script:postconditionReason)) {
            throw $script:postconditionReason
        }
    }

    if ($null -ne $guarded) {
        . ([scriptblock]::Create($guarded.Extent.Text))
        $script:RunId = Get-ColdRestoreAuthorizationRunId `
            $targetedAuthorizationName ("a" * 40)
        $script:TargetedOwnerCaptureAuthorizationName = $targetedAuthorizationName
        $script:TargetedOwnerCaptureQuotaLedgerRelativePath = [string]$targetedAuthorization.quota_ledger_relative_path
        $script:TargetedOwnerCaptureBootstrapRelativeRoot = [string]$targetedAuthorization.bootstrap_root_relative_path
        $script:TargetedOwnerCaptureAuthorizationId = [string]$targetedAuthorization.authorization_id
        $script:AuthorizationContractPath = $authorizationContractPath
        $script:AuthorizationContractSha256 = (
            Get-FileHash -LiteralPath $authorizationContractPath -Algorithm SHA256
        ).Hash.ToLowerInvariant()

        Reset-SyntheticCase
        $success = Invoke-ColdRestoreTargetedOwnerCaptureGuarded $projectRoot ("a" * 40)
        Assert-ContractCondition ([string]$success.fixture -ceq "diagnostic-success") "success returns the diagnostic result"
        Assert-ContractCondition ($script:diagnosticCalls -eq 1 -and $script:postconditionCalls -eq 1) "success runs diagnostic and postconditions once"

        Reset-SyntheticCase
        $script:primaryReason = "targeted_owner_capture_primary_fixture_failed"
        $script:RunId = Get-ColdRestoreAuthorizationRunId `
            $targetedAuthorizationName ("b" * 40)
        $primaryOnly = Get-ThrownReason {
            Invoke-ColdRestoreTargetedOwnerCaptureGuarded $projectRoot ("b" * 40) | Out-Null
        }
        Assert-ContractCondition ($primaryOnly -ceq $script:primaryReason) "primary typed failure survives successful postconditions"
        Assert-ContractCondition ($script:diagnosticCalls -eq 1 -and $script:postconditionCalls -eq 1) "postconditions still run after a primary failure"

        Reset-SyntheticCase
        $script:primaryReason = "targeted_owner_capture_primary_fixture_failed"
        $script:postconditionReason = "targeted_owner_capture_postcondition_fixture_failed"
        $script:RunId = Get-ColdRestoreAuthorizationRunId `
            $targetedAuthorizationName ("c" * 40)
        $both = Get-ThrownReason {
            Invoke-ColdRestoreTargetedOwnerCaptureGuarded $projectRoot ("c" * 40) | Out-Null
        }
        Assert-ContractCondition ($both -ceq $script:primaryReason) "primary typed failure outranks postcondition failure"
        Assert-ContractCondition ($script:diagnosticCalls -eq 1 -and $script:postconditionCalls -eq 1) "dual failure runs each boundary once"

        Reset-SyntheticCase
        $script:postconditionReason = "targeted_owner_capture_postcondition_fixture_failed"
        $script:RunId = Get-ColdRestoreAuthorizationRunId `
            $targetedAuthorizationName ("d" * 40)
        $postconditionOnly = Get-ThrownReason {
            Invoke-ColdRestoreTargetedOwnerCaptureGuarded $projectRoot ("d" * 40) | Out-Null
        }
        Assert-ContractCondition ($postconditionOnly -ceq $script:postconditionReason) "postcondition failure surfaces when no primary failure exists"
        Assert-ContractCondition ($script:diagnosticCalls -eq 1 -and $script:postconditionCalls -eq 1) "postcondition-only case runs each boundary once"
    }

    if ($null -ne $targetedInvoke) {
        . ([scriptblock]::Create($targetedInvoke.Extent.Text))
        $targetedInvokeSource = [string]$targetedInvoke.Extent.Text
        Assert-ContractCondition (
            $targetedInvokeSource.IndexOf('throw (cold_restore_attested_process\New-ColdRestoreFailureException $FailureState)', [StringComparison]::Ordinal) -ge 0 -and
            $targetedInvokeSource.IndexOf('$run.secondary_failure_codes', [StringComparison]::Ordinal) -lt 0 -and
            $targetedInvokeSource.IndexOf('"wrapper_supervision"', [StringComparison]::Ordinal) -lt 0
        ) "targeted path throws the wrapper-owned shared failure state without replaying secondary reasons"
        $script:RunId = "$([string]$targetedAuthorization.run_id_prefix)-000000000000"
        $script:AuthorizedOfficialColdRestoreCount = 0
        $script:ExpectedScenarioFingerprint = "f" * 64
        $script:TargetedOwnerCaptureScenarioFingerprint = $script:ExpectedScenarioFingerprint
        $failureState = New-ColdRestorePrimaryFailureState
        $preQuotaReason = Get-ThrownReason {
            Invoke-ColdRestoreTargetedOwnerCaptureDiagnostic `
                $projectRoot ("e" * 40) ([pscustomobject]@{}) $failureState | Out-Null
        }
        Assert-ContractCondition ($preQuotaReason -ceq "targeted_owner_capture_run_id_invalid") "real targeted path preserves a typed pre-quota reason"
        Assert-ContractCondition ($script:quotaWrites -eq 0) "real pre-quota rejection does not call the quota writer"
        Assert-ContractCondition ($script:godotStarts -eq 0) "real pre-quota rejection does not call the Godot launcher"
        Assert-ContractCondition ($script:evidenceWrites -eq 0) "real pre-quota rejection does not call the evidence writer"
    }

    $source = [IO.File]::ReadAllText($orchestratorPath)
    Assert-ContractCondition (
        $source.IndexOf(
            '$targetedDiagnostic = Invoke-ColdRestoreTargetedOwnerCaptureGuarded $resolvedProjectPath $headSha',
            [StringComparison]::Ordinal
        ) -ge 0
    ) "top-level targeted mode uses the guarded invocation"
    Assert-ContractCondition (
        $source.IndexOf("New-ColdRestorePrimaryFailureState", [StringComparison]::Ordinal) -ge 0 -and
        $source.IndexOf("postcondition_validation", [StringComparison]::Ordinal) -ge 0 -and
        $source.IndexOf("Get-ColdRestoreFailureProjection", [StringComparison]::Ordinal) -ge 0 -and
        $source.IndexOf("New-ColdRestoreFailureException", [StringComparison]::Ordinal) -ge 0
    ) "guarded invocation encodes primary-before-postcondition precedence"

    $targetedCatches = @($ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.CatchClauseAst] -and
            $node.Extent.Text.IndexOf('$TargetedOwnerCaptureDriverId', [StringComparison]::Ordinal) -ge 0
    }, $true))
    Assert-ContractCondition ($targetedCatches.Count -eq 1) "top-level targeted allowlist catch exists exactly once"
    $targetedCatchSource = if ($targetedCatches.Count -eq 1) {
        [string]$targetedCatches[0].Extent.Text
    }
    else {
        ""
    }
    Assert-ContractCondition (
        $targetedCatchSource.IndexOf('Get-ColdRestoreFailureProjectionFromError', [StringComparison]::Ordinal) -ge 0 -and
        $targetedCatchSource.IndexOf("'^[a-z0-9_]{1,128}$'", [StringComparison]::Ordinal) -ge 0 -and
        $targetedCatchSource.IndexOf('failure_code = $safeFailureCode', [StringComparison]::Ordinal) -ge 0
    ) "top-level targeted allowlist projects the exact safe typed failure code"
    Assert-ContractCondition ($primaryOnly -ceq "targeted_owner_capture_primary_fixture_failed") "guarded primary reason remains safe for the real allowlist projection"

    Assert-ContractCondition ($script:quotaWrites -eq 0) "fixtures write no quota ledger"
    Assert-ContractCondition ($script:evidenceWrites -eq 0) "fixtures write no diagnostic evidence"
    Assert-ContractCondition ($script:godotStarts -eq 0) "fixtures start no Godot process"
    Assert-ContractCondition (-not [IO.Directory]::Exists((Join-Path $testRoot "quota"))) "quota artifact root remains absent"
    Assert-ContractCondition (-not [IO.Directory]::Exists((Join-Path $testRoot "evidence"))) "evidence artifact root remains absent"
}
catch {
    $script:failures.Add("unexpected exception: $($_.Exception.Message)")
}
finally {
    $resolvedTestRoot = [IO.Path]::GetFullPath($testRoot)
    $resolvedTempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolvedTestRoot.StartsWith($resolvedTempRoot, [StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetFileName($resolvedTestRoot).StartsWith("alpha04c-targeted-postcondition-", [StringComparison]::Ordinal)) {
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$status = if ($script:failures.Count -eq 0) { "PASS" } else { "FAIL" }
Write-Output "TARGETED_OWNER_DIAGNOSTIC_POSTCONDITION_GUARD_TEST|status=$status|checks=$script:checks|failures=$($script:failures.Count)"
foreach ($failure in $script:failures) {
    Write-Output "FAIL|$failure"
}
if ($script:failures.Count -gt 0) {
    exit 1
}
exit 0
