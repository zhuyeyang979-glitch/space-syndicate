[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path $root "scripts\tools\process_a_rehearsal_admission_contract.psm1"
$fixtureSourcePath = Join-Path $PSScriptRoot "process_a_rehearsal_admission_contract_test.ps1"
$contractModule = Import-Module $modulePath -Force -PassThru

$checks = 0
$failures = [Collections.Generic.List[string]]::new()
$stopwatch = [Diagnostics.Stopwatch]::StartNew()
$testRoot = Join-Path ([IO.Path]::GetTempPath()) "alpha04c process a strict integer $([Guid]::NewGuid().ToString('N'))"
[IO.Directory]::CreateDirectory($testRoot) | Out-Null

function Assert-FocusedCondition {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    $script:checks += 1
    if (-not $Condition) {
        $script:failures.Add($Message)
        [Console]::Error.WriteLine($Message)
    }
}

function Get-FileState {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not [IO.File]::Exists($Path)) {
        return "absent"
    }
    return "present:$((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant())"
}

function Assert-RealLedgersUnchanged {
    param([Parameter(Mandatory = $true)][string]$CaseName)

    foreach ($path in $script:realLedgerPaths) {
        Assert-FocusedCondition `
            ((Get-FileState $path) -ceq [string]$script:realLedgerStateBefore[$path]) `
            "$CaseName must not create or mutate real ledger $path"
    }
}

function Assert-RejectedWithoutLedger {
    param(
        [Parameter(Mandatory = $true)][string]$CaseName,
        [Parameter(Mandatory = $true)][scriptblock]$Action,
        [Parameter(Mandatory = $true)][string]$ForbiddenOutputPath
    )

    $reason = ""
    try {
        $null = & $Action
    }
    catch {
        $reason = [string]$_.Exception.Message
    }

    Assert-FocusedCondition ($reason.Length -gt 0) "$CaseName must reject the string-typed integer"
    Assert-FocusedCondition (-not [IO.File]::Exists($ForbiddenOutputPath)) "$CaseName must not publish its output ledger"
    Assert-RealLedgersUnchanged $CaseName
}

function Copy-TestValue {
    param([Parameter(Mandatory = $true)]$Value)

    return $Value | ConvertTo-Json -Depth 100 | ConvertFrom-Json -DateKind String
}

function Update-DiagnosticChain {
    param(
        [Parameter(Mandatory = $true)]$Fixture,
        [Parameter(Mandatory = $true)][scriptblock]$Mutation
    )

    $diagnostic = Read-TestJson $Fixture.evidence_path
    & $Mutation $diagnostic
    $diagnostic.scenario_identity.identity_fingerprint =
        Get-TestFingerprint $diagnostic.scenario_identity "identity_fingerprint"
    $diagnostic.diagnostic_phase_timeline.evidence_fingerprint =
        Get-TestFingerprint $diagnostic.diagnostic_phase_timeline "evidence_fingerprint"
    $diagnostic.evidence_fingerprint = Get-TestFingerprint $diagnostic "evidence_fingerprint"
    Write-TestJson $Fixture.evidence_path $diagnostic

    $diagnosticSha256 =
        (Get-FileHash -LiteralPath $Fixture.evidence_path -Algorithm SHA256).Hash.ToLowerInvariant()
    $child = Read-TestJson $Fixture.diagnostic_child_path
    $child.product_blocker = "TARGETED_OWNER_CAPTURE_DIAGNOSTIC_SHA256:$diagnosticSha256"
    $child.final_reason_code = "targeted_owner_capture_diagnostic_sha256_$diagnosticSha256"
    $child.evidence_fingerprint = Get-TestFingerprint $child "evidence_fingerprint"
    Write-TestJson $Fixture.diagnostic_child_path $child

    $parent = Read-TestJson $Fixture.diagnostic_parent_path
    $parent.child_attestation_fingerprint = [string]$child.evidence_fingerprint
    Write-TestJson $Fixture.diagnostic_parent_path $parent
}

function Update-PolicyChainToStringSchema {
    param([Parameter(Mandatory = $true)]$Fixture)

    $policy = Read-TestJson $Fixture.policy_path
    $policy.schema_version = "1"
    Write-TestJson $Fixture.policy_path $policy
    $policySha256 =
        (Get-FileHash -LiteralPath $Fixture.policy_path -Algorithm SHA256).Hash.ToLowerInvariant()

    $quota = Read-TestJson $Fixture.diagnostic_quota_path
    $quota.role_timeout_policy_sha256 = $policySha256
    Write-TestJson $Fixture.diagnostic_quota_path $quota

    $parent = Read-TestJson $Fixture.diagnostic_parent_path
    $parent.timeout_policy_fingerprint = $policySha256
    Write-TestJson $Fixture.diagnostic_parent_path $parent
}

function New-ValidTemporaryLaunch {
    param([Parameter(Mandatory = $true)][string]$Name)

    $fixture = New-TestFixture $Name
    $admission = Invoke-TestAdmission $fixture
    Write-TestJson $fixture.launch_attestation_path (New-TestLaunchAttestation $admission.launch_authorization)
    $launch = Complete-TestLaunch $fixture $admission
    return [pscustomobject]@{
        fixture = $fixture
        admission = $admission
        launch = $launch
    }
}

# Reuse only declarations from the established synthetic fixture. The test body is never dot-sourced.
$tokens = $null
$parseErrors = $null
$fixtureAst = [Management.Automation.Language.Parser]::ParseFile(
    $fixtureSourcePath,
    [ref]$tokens,
    [ref]$parseErrors
)
if (@($parseErrors).Count -ne 0) {
    throw "process_a_rehearsal_fixture_source_parse_failed"
}

$requiredVariables = @(
    "head", "scenarioFingerprint", "prerequisiteFingerprint", "sha", "officialAttempt1Sha",
    "officialAttempt1Text", "sectionOrder", "ownerOrder"
)
$assignmentByName = @{}
foreach ($statement in $fixtureAst.EndBlock.Statements) {
    if ($statement -isnot [Management.Automation.Language.AssignmentStatementAst] `
        -or $statement.Left -isnot [Management.Automation.Language.VariableExpressionAst]) {
        continue
    }
    $name = [string]$statement.Left.VariablePath.UserPath
    if ($name -in $requiredVariables -and -not $assignmentByName.ContainsKey($name)) {
        $assignmentByName[$name] = $statement
    }
}
foreach ($name in $requiredVariables) {
    if (-not $assignmentByName.ContainsKey($name)) {
        throw "process_a_rehearsal_fixture_variable_missing_$name"
    }
    . ([scriptblock]::Create($assignmentByName[$name].Extent.Text))
}

$requiredHelpers = @(
    "Get-TestFingerprint", "ConvertTo-TestCanonicalJson", "Write-TestJson",
    "Read-TestJson", "Seal-TestValue", "New-TestDiagnostic", "New-TestPolicy",
    "New-TestDiagnosticQuotaLedger", "New-TestDiagnosticLaunchAttestation",
    "New-TestDiagnosticManifest", "New-TestDiagnosticChildCompletionAttestation",
    "New-TestDiagnosticParentExitAttestation", "New-TestFixture",
    "Invoke-TestAdmission", "New-TestLaunchAttestation", "Complete-TestLaunch"
)
$functionByName = @{}
foreach ($statement in $fixtureAst.EndBlock.Statements) {
    if ($statement -is [Management.Automation.Language.FunctionDefinitionAst] `
        -and $statement.Name -in $requiredHelpers) {
        $functionByName[$statement.Name] = $statement
    }
}
foreach ($name in $requiredHelpers) {
    if (-not $functionByName.ContainsKey($name)) {
        throw "process_a_rehearsal_fixture_helper_missing_$name"
    }
    . ([scriptblock]::Create($functionByName[$name].Extent.Text))
}

$gitCommonRaw = [string](& git -C $root rev-parse --git-common-dir)
if ([string]::IsNullOrWhiteSpace($gitCommonRaw)) {
    throw "process_a_rehearsal_git_common_dir_missing"
}
$gitCommonPath = if ([IO.Path]::IsPathRooted($gitCommonRaw.Trim())) {
    [IO.Path]::GetFullPath($gitCommonRaw.Trim())
}
else {
    [IO.Path]::GetFullPath((Join-Path $root $gitCommonRaw.Trim()))
}
$realLedgerPaths = @(
    (Join-Path $gitCommonPath "codex\cold_restore_v3\official-alpha04c-depth1-seed900626424\official_claim_ledger.json"),
    (Join-Path $gitCommonPath "codex\cold_restore_v3\non-official-alpha04c-owner-capture-attestation-12691a8\targeted_owner_capture_quota_ledger.json"),
    (Join-Path $gitCommonPath "codex\cold_restore_v3\non-official-alpha04c-final-cold-closure-3b30615\targeted_owner_capture_quota_ledger.json"),
    (Join-Path $gitCommonPath "codex\cold_restore_v3\non-official-alpha04c-process-a-rehearsal-v1\process_a_rehearsal_quota_ledger.json"),
    (Join-Path $gitCommonPath "codex\cold_restore_v3\non-official-alpha04c-process-a-rehearsal-v1\process_a_rehearsal_launch_ledger.json"),
    (Join-Path $gitCommonPath "codex\cold_restore_v3\official-alpha04c-attempt-2-depth1-seed900626424\official_attempt_2_claim.json")
)
$realLedgerStateBefore = @{}
foreach ($path in $realLedgerPaths) {
    $realLedgerStateBefore[$path] = Get-FileState $path
}

try {
    $policyFixture = New-TestFixture "policy-schema-string"
    Update-PolicyChainToStringSchema $policyFixture
    Assert-RejectedWithoutLedger "policy schema string" {
        Invoke-TestAdmission $policyFixture
    } $policyFixture.admission_path

    foreach ($identityCase in @(
        [pscustomobject]@{ name = "identity-schema-string"; field = "schema_version" },
        [pscustomobject]@{ name = "identity-session-generation-string"; field = "session_generation" },
        [pscustomobject]@{ name = "identity-world-revision-string"; field = "world_revision" }
    )) {
        $fixture = New-TestFixture $identityCase.name
        $field = [string]$identityCase.field
        Update-DiagnosticChain $fixture {
            param($diagnostic)
            $diagnostic.scenario_identity.$field = [string]$diagnostic.scenario_identity.$field
        }
        Assert-RejectedWithoutLedger "Diagnostic identity $field string" {
            Invoke-TestAdmission $fixture
        } $fixture.admission_path
    }

    $timelineFixture = New-TestFixture "timeline-schema-string"
    Update-DiagnosticChain $timelineFixture {
        param($diagnostic)
        $diagnostic.diagnostic_phase_timeline.schema_version =
            [string]$diagnostic.diagnostic_phase_timeline.schema_version
    }
    Assert-RejectedWithoutLedger "timeline schema string" {
        Invoke-TestAdmission $timelineFixture
    } $timelineFixture.admission_path

    $admissionLedgerFixture = New-TestFixture "admission-ledger-schema-string"
    $admission = Invoke-TestAdmission $admissionLedgerFixture
    $forgedAdmission = Copy-TestValue $admission.value
    $forgedAdmission.schema_version = "3"
    $forgedAdmission.ledger_fingerprint = Get-TestFingerprint $forgedAdmission "ledger_fingerprint"
    $forgedAdmissionPath = Join-Path $admissionLedgerFixture.root "ledger\forged-admission-schema-string.json"
    Write-TestJson $forgedAdmissionPath $forgedAdmission
    Assert-RejectedWithoutLedger "admission ledger schema string" {
        Read-ProcessARehearsalAdmissionLedger $forgedAdmissionPath
    } $admissionLedgerFixture.launch_path

    $launchSchemaFixture = New-TestFixture "launch-attestation-schema-string"
    $launchSchemaAdmission = Invoke-TestAdmission $launchSchemaFixture
    $launchSchemaAttestation = New-TestLaunchAttestation $launchSchemaAdmission.launch_authorization
    $launchSchemaAttestation.schema_version = "1"
    Write-TestJson $launchSchemaFixture.launch_attestation_path $launchSchemaAttestation
    Assert-RejectedWithoutLedger "launch attestation schema string" {
        Complete-TestLaunch $launchSchemaFixture $launchSchemaAdmission
    } $launchSchemaFixture.launch_path

    $launchPidFixture = New-TestFixture "launch-attestation-pid-strings"
    $launchPidAdmission = Invoke-TestAdmission $launchPidFixture
    $launchPidAttestation = New-TestLaunchAttestation $launchPidAdmission.launch_authorization
    foreach ($field in @(
        "orchestrator_process_id", "wrapper_process_id", "wrapper_parent_process_id",
        "engine_process_id", "engine_parent_process_id"
    )) {
        $launchPidAttestation.$field = [string]$launchPidAttestation.$field
    }
    Write-TestJson $launchPidFixture.launch_attestation_path $launchPidAttestation
    Assert-RejectedWithoutLedger "launch attestation PID strings" {
        Complete-TestLaunch $launchPidFixture $launchPidAdmission
    } $launchPidFixture.launch_path

    $launchLedgerFixture = New-ValidTemporaryLaunch "launch-ledger-string-types"
    $forgedLaunchSchema = Copy-TestValue $launchLedgerFixture.launch.value
    $forgedLaunchSchema.schema_version = "1"
    $forgedLaunchSchema.ledger_fingerprint = Get-TestFingerprint $forgedLaunchSchema "ledger_fingerprint"
    $forgedLaunchSchemaPath = Join-Path $launchLedgerFixture.fixture.root "ledger\forged-launch-schema-string.json"
    Write-TestJson $forgedLaunchSchemaPath $forgedLaunchSchema
    $unusedSchemaOutput = Join-Path $launchLedgerFixture.fixture.root "ledger\unexpected-schema-output.json"
    Assert-RejectedWithoutLedger "launch ledger schema string" {
        Read-ProcessARehearsalLaunchLedger $forgedLaunchSchemaPath
    } $unusedSchemaOutput

    $forgedLaunchPids = Copy-TestValue $launchLedgerFixture.launch.value
    foreach ($field in @(
        "orchestrator_process_id", "wrapper_process_id", "wrapper_parent_process_id",
        "engine_process_id", "engine_parent_process_id"
    )) {
        $forgedLaunchPids.$field = [string]$forgedLaunchPids.$field
    }
    $forgedLaunchPids.ledger_fingerprint = Get-TestFingerprint $forgedLaunchPids "ledger_fingerprint"
    $forgedLaunchPidsPath = Join-Path $launchLedgerFixture.fixture.root "ledger\forged-launch-pid-strings.json"
    Write-TestJson $forgedLaunchPidsPath $forgedLaunchPids
    $unusedPidOutput = Join-Path $launchLedgerFixture.fixture.root "ledger\unexpected-pid-output.json"
    Assert-RejectedWithoutLedger "launch ledger PID strings" {
        Read-ProcessARehearsalLaunchLedger $forgedLaunchPidsPath
    } $unusedPidOutput
}
catch {
    $failures.Add("unexpected test harness failure: $([string]$_.Exception.Message)")
    [Console]::Error.WriteLine($failures[$failures.Count - 1])
}
finally {
    Assert-RealLedgersUnchanged "final boundary"
    $resolvedTestRoot = [IO.Path]::GetFullPath($testRoot)
    $resolvedTempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolvedTestRoot.StartsWith($resolvedTempRoot, [StringComparison]::OrdinalIgnoreCase) `
        -and [IO.Path]::GetFileName($resolvedTestRoot).StartsWith(
            "alpha04c process a strict integer ",
            [StringComparison]::Ordinal
        )) {
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$stopwatch.Stop()
Assert-FocusedCondition ($stopwatch.Elapsed.TotalSeconds -le 30.0) "strict-integer fixture must finish within 30 seconds"
$status = if ($failures.Count -eq 0) { "PASS" } else { "FAIL" }
Write-Output (
    "PROCESS_A_REHEARSAL_ADMISSION_STRICT_INTEGER_TEST|status={0}|checks={1}|failures={2}|wall_seconds={3:F3}" -f `
        $status, $checks, $failures.Count, $stopwatch.Elapsed.TotalSeconds
)

if ($failures.Count -gt 0) {
    exit 1
}
