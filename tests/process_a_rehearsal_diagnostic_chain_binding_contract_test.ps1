[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$modulePath = Join-Path $projectRoot "scripts/tools/process_a_rehearsal_admission_contract.psm1"
$orchestratorPath = Join-Path $projectRoot "scripts/tools/cold_restore_vertical_slice_orchestrator.ps1"
$script:checks = 0
$script:failures = [Collections.Generic.List[string]]::new()

function Assert-ContractCondition {
    param([bool]$Condition, [string]$Message)
    $script:checks += 1
    if (-not $Condition) { $script:failures.Add($Message) }
}

function Get-FunctionAst {
    param($Ast, [string]$Name)
    $matches = @($Ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst]
    }, $true) | Where-Object { [string]$_.Name -ceq $Name })
    return $(if ($matches.Count -eq 1) { $matches[0] } else { $null })
}

function Test-ContainsAll {
    param([string]$Source, [string[]]$Markers)
    foreach ($marker in $Markers) {
        if ($Source.IndexOf($marker, [StringComparison]::OrdinalIgnoreCase) -lt 0) { return $false }
    }
    return $true
}

$moduleTokens = $null
$moduleErrors = $null
$moduleAst = [Management.Automation.Language.Parser]::ParseFile($modulePath, [ref]$moduleTokens, [ref]$moduleErrors)
$orchestratorTokens = $null
$orchestratorErrors = $null
$orchestratorAst = [Management.Automation.Language.Parser]::ParseFile($orchestratorPath, [ref]$orchestratorTokens, [ref]$orchestratorErrors)
Assert-ContractCondition ($moduleErrors.Count -eq 0 -and $orchestratorErrors.Count -eq 0) "PowerShell sources parse"

$newAdmission = Get-FunctionAst $moduleAst "New-ProcessARehearsalAdmission"
$admissionEvidence = Get-FunctionAst $moduleAst "Get-ProcessARehearsalAdmissionEvidence"
$completeLaunch = Get-FunctionAst $moduleAst "Complete-ProcessARehearsalLaunch"
$consumeAdmission = Get-FunctionAst $orchestratorAst "Consume-ColdRestoreProcessARehearsalQuota"
$diagnosticAdmission = Get-FunctionAst $orchestratorAst "Get-ColdRestoreProcessARehearsalDiagnosticAdmission"
foreach ($entry in @(
    [pscustomobject]@{ value = $newAdmission; name = "New admission" },
    [pscustomobject]@{ value = $admissionEvidence; name = "Admission evidence" },
    [pscustomobject]@{ value = $completeLaunch; name = "Complete launch" },
    [pscustomobject]@{ value = $consumeAdmission; name = "Orchestrator admission" },
    [pscustomobject]@{ value = $diagnosticAdmission; name = "Diagnostic path derivation" }
)) {
    Assert-ContractCondition ($null -ne $entry.value) "$($entry.name) function exists exactly once"
}

$pathParameters = @(
    "AdmissionEvidencePath",
    "DiagnosticQuotaLedgerPath",
    "DiagnosticChildAttestationPath",
    "DiagnosticParentAttestationPath",
    "DiagnosticStdoutPath",
    "DiagnosticStderrPath",
    "TimeoutPolicyPath"
)
$newSource = [string]$newAdmission.Extent.Text
$evidenceSource = [string]$admissionEvidence.Extent.Text
$completeSource = [string]$completeLaunch.Extent.Text
foreach ($name in $pathParameters) {
    Assert-ContractCondition ($newAdmission.Body.ParamBlock.Parameters.Name.VariablePath.UserPath -ccontains $name) "New admission accepts $name"
    Assert-ContractCondition ($newSource.IndexOf("`$$name", [StringComparison]::OrdinalIgnoreCase) -ge 0) "New admission propagates $name"
}

foreach ($marker in @(
    '$quotaArtifact.sha256',
    '$artifact.sha256',
    '$childArtifact.sha256',
    '$child.evidence_fingerprint',
    '$parentArtifact.sha256',
    '$stdoutSha256',
    '$stderrSha256',
    '$ExpectedTimeoutPolicyFingerprint'
)) {
    Assert-ContractCondition ($evidenceSource.Contains($marker, [StringComparison]::Ordinal)) "Admission evidence binds $marker"
}
Assert-ContractCondition (Test-ContainsAll $evidenceSource @(
    '$parent.schema_version',
    '$parent.stdout_sha256',
    '$parent.stderr_sha256',
    '$parent.child_attestation_fingerprint',
    '$parent.wrapper_exit_green',
    '$parent.task_owned_process_count_after'
)) "Parent Exit V2 is validated as a closed exit proof"

$requiredSummaryFields = @(
    "admission_evidence_sha256",
    "diagnostic_quota_ledger_sha256",
    "diagnostic_child_attestation_sha256",
    "diagnostic_child_attestation_fingerprint",
    "diagnostic_parent_attestation_sha256",
    "diagnostic_stdout_sha256",
    "diagnostic_stderr_sha256",
    "timeout_policy_fingerprint"
)
$moduleSource = [IO.File]::ReadAllText($modulePath)
foreach ($field in $requiredSummaryFields) {
    Assert-ContractCondition ($moduleSource.IndexOf('"' + $field + '"', [StringComparison]::Ordinal) -ge 0) "Admission ledger declares $field"
    Assert-ContractCondition ($newSource.IndexOf($field, [StringComparison]::Ordinal) -ge 0) "Admission ledger writes $field"
}
foreach ($name in $pathParameters) {
    Assert-ContractCondition ($completeLaunch.Body.ParamBlock.Parameters.Name.VariablePath.UserPath -ccontains $name) "Launch completion rechecks $name"
}
Assert-ContractCondition (Test-ContainsAll $completeSource @(
    'Get-FileHash',
    '$ledger.diagnostic_quota_ledger_sha256',
    '$ledger.diagnostic_child_attestation_sha256',
    '$ledger.diagnostic_parent_attestation_sha256',
    '$ledger.diagnostic_stdout_sha256',
    '$ledger.diagnostic_stderr_sha256'
)) "Launch completion rechecks every diagnostic-chain byte source"

$diagnosticSource = [string]$diagnosticAdmission.Extent.Text
Assert-ContractCondition (Test-ContainsAll $diagnosticSource @(
    '$diagnosticRunId',
    'Get-ColdRestoreAuthorizationRunId',
    'Resolve-ColdRestoreGitCommonDirectory',
    '$TargetedOwnerCaptureEvidenceRootRelativePath',
    'owner_capture_audit.json',
    'producer.completion.json',
    'producer.exit.json',
    'producer.stdout.log',
    'producer.stderr.log'
)) "Diagnostic evidence paths bind the HEAD-derived run ID to the authorization-contract root"

$consumeSource = [string]$consumeAdmission.Extent.Text
Assert-ContractCondition (Test-ContainsAll $consumeSource @(
    'Resolve-ColdRestoreGitCommonDirectory',
    '$TargetedOwnerCaptureQuotaLedgerRelativePath',
    '$ProcessARehearsalQuotaLedgerRelativePath',
    '$ProcessARehearsalLaunchLedgerRelativePath',
    'New-ProcessARehearsalAdmission',
    '-DiagnosticQuotaLedgerPath',
    '-DiagnosticChildAttestationPath',
    '-DiagnosticParentAttestationPath',
    '-DiagnosticStdoutPath',
    '-DiagnosticStderrPath'
)) "Orchestrator anchors quota and rehearsal ledgers to git-common and passes the fixed chain"

$forbidden = @('owner_state', 'section_payloads', 'private_hand', 'ai_memory', 'commodity_inventory')
foreach ($token in $forbidden) {
    Assert-ContractCondition ($moduleSource.IndexOf($token, [StringComparison]::OrdinalIgnoreCase) -lt 0) "Admission module excludes raw private token $token"
}

$status = if ($script:failures.Count -eq 0) { "PASS" } else { "FAIL" }
Write-Output "PROCESS_A_REHEARSAL_DIAGNOSTIC_CHAIN_BINDING_CONTRACT_TEST|status=$status|checks=$script:checks|failures=$($script:failures.Count)"
foreach ($failure in $script:failures) { Write-Output "FAIL|$failure" }
if ($script:failures.Count -gt 0) { exit 1 }
exit 0
