[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$orchestratorPath = Join-Path $projectRoot "scripts/tools/cold_restore_vertical_slice_orchestrator.ps1"

$script:checks = 0
$script:failures = [Collections.Generic.List[string]]::new()

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

function Test-SourceContainsAll {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string[]]$Markers
    )

    foreach ($marker in $Markers) {
        if ($Source.IndexOf($marker, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
            return $false
        }
    }
    return $true
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

function Get-CommandAsts {
    param([Parameter(Mandatory = $true)]$Ast)

    return @($Ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.CommandAst]
    }, $true))
}

function Get-AssignmentVariables {
    param(
        [Parameter(Mandatory = $true)]$Ast,
        [Parameter(Mandatory = $true)][string[]]$RightMarkers
    )

    $variables = [Collections.Generic.List[string]]::new()
    $assignments = @($Ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.AssignmentStatementAst]
    }, $true))
    foreach ($assignment in $assignments) {
        if (-not (Test-SourceContainsAll ([string]$assignment.Right.Extent.Text) $RightMarkers)) {
            continue
        }
        $leftSource = [string]$assignment.Left.Extent.Text
        if ($leftSource -cmatch '^\$[A-Za-z_][A-Za-z0-9_]*$') {
            $variables.Add($leftSource)
        }
    }
    return @($variables | Select-Object -Unique)
}

function Test-AnyAssertion {
    param(
        [Parameter(Mandatory = $true)][object[]]$Assertions,
        [Parameter(Mandatory = $true)][string[]]$Markers,
        [string]$Pattern = ""
    )

    foreach ($assertion in $Assertions) {
        $source = [string]$assertion.Extent.Text
        if ((Test-SourceContainsAll $source $Markers) `
            -and ($Pattern -eq "" -or $source -cmatch $Pattern)) {
            return $true
        }
    }
    return $false
}

function Test-ExpectedIdentityBinding {
    param(
        [Parameter(Mandatory = $true)][object[]]$Assertions,
        [Parameter(Mandatory = $true)][string]$Observed,
        [Parameter(Mandatory = $true)][string]$Expected
    )

    return Test-AnyAssertion $Assertions @($Observed, $Expected) '(?:-ceq|-eq)'
}

$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile(
    $orchestratorPath,
    [ref]$tokens,
    [ref]$parseErrors
)
Assert-ContractCondition ($parseErrors.Count -eq 0) "orchestrator parses without PowerShell syntax errors"

$targeted = Get-FunctionAst $ast "Invoke-ColdRestoreTargetedOwnerCaptureDiagnostic"
$diagnosticAdmission = Get-FunctionAst $ast "Get-ColdRestoreProcessARehearsalDiagnosticAdmission"
$consumeAdmission = Get-FunctionAst $ast "Consume-ColdRestoreProcessARehearsalQuota"
Assert-ContractCondition ($null -ne $targeted) "targeted Owner diagnostic function exists exactly once"
Assert-ContractCondition ($null -ne $diagnosticAdmission) "diagnostic admission path function exists exactly once"
Assert-ContractCondition ($null -ne $consumeAdmission) "rehearsal admission consumer exists exactly once"

if ($null -ne $targeted) {
    $commands = Get-CommandAsts $targeted
    $assertions = @($commands | Where-Object {
        [string]$_.GetCommandName() -ceq "Assert-ColdRestoreCondition"
    })

    $atomicAssignments = @(
        Get-AssignmentVariables $targeted @('Read-ColdRestoreJsonArtifact', '$paths.child_result')
    )
    $stdoutAssignments = @(
        Get-AssignmentVariables $targeted @('Read-ColdRestoreManifest', '$paths.stdout', '"producer"', '$RunId')
    )
    Assert-ContractCondition ($atomicAssignments.Count -eq 1) "targeted path reads exactly one atomic child_result manifest"
    Assert-ContractCondition ($stdoutAssignments.Count -eq 1) "targeted path reads exactly one stdout marker manifest"

    $atomicVariable = if ($atomicAssignments.Count -eq 1) { $atomicAssignments[0] } else { '$manifest' }
    $stdoutVariable = if ($stdoutAssignments.Count -eq 1) { $stdoutAssignments[0] } else { '$stdoutManifest' }
    $atomicCanonicalAssignments = @(
        Get-AssignmentVariables $targeted @('ConvertTo-ColdRestoreCanonicalJson', $atomicVariable)
    )
    $stdoutCanonicalAssignments = @(
        Get-AssignmentVariables $targeted @('ConvertTo-ColdRestoreCanonicalJson', $stdoutVariable)
    )
    Assert-ContractCondition ($atomicCanonicalAssignments.Count -eq 1) "targeted path canonicalizes the atomic manifest"
    Assert-ContractCondition ($stdoutCanonicalAssignments.Count -eq 1) "targeted path canonicalizes the stdout manifest"

    $atomicCanonical = if ($atomicCanonicalAssignments.Count -eq 1) {
        $atomicCanonicalAssignments[0]
    }
    else {
        '$manifestCanonical'
    }
    $stdoutCanonical = if ($stdoutCanonicalAssignments.Count -eq 1) {
        $stdoutCanonicalAssignments[0]
    }
    else {
        '$stdoutManifestCanonical'
    }
    Assert-ContractCondition (
        (Test-AnyAssertion $assertions @($atomicCanonical, $stdoutCanonical) '-ceq')
    ) "targeted path requires canonical atomic/stdout manifest equality"

    $stdoutHashAssignments = @(
        Get-AssignmentVariables $targeted @('Get-FileHash', '$paths.stdout', 'SHA256')
    )
    Assert-ContractCondition ($stdoutHashAssignments.Count -eq 1) "targeted path hashes the captured stdout file exactly once"
    $stdoutHashVariable = if ($stdoutHashAssignments.Count -eq 1) {
        $stdoutHashAssignments[0]
    }
    else {
        '$stdoutSha256'
    }
    Assert-ContractCondition (
        (Test-AnyAssertion $assertions @($stdoutHashVariable, '$run.parent.stdout_sha256') '-ceq')
    ) "targeted path binds stdout bytes to Parent stdout_sha256"

    foreach ($binding in @(
        [pscustomobject]@{ observed = '$run.child.run_id'; expected = '$RunId'; message = 'Child run ID binds to expected run' },
        [pscustomobject]@{ observed = "$atomicVariable.run_id"; expected = '$RunId'; message = 'atomic manifest run ID binds to expected run' },
        [pscustomobject]@{ observed = '$timeline.run_id'; expected = '$RunId'; message = 'timeline run ID binds to expected run' },
        [pscustomobject]@{ observed = '$run.child.repository_head'; expected = '$HeadSha'; message = 'Child HEAD binds to expected HEAD' },
        [pscustomobject]@{ observed = "$atomicVariable.head_sha"; expected = '$HeadSha'; message = 'atomic manifest HEAD binds to expected HEAD' },
        [pscustomobject]@{ observed = '$timeline.repository_head'; expected = '$HeadSha'; message = 'timeline HEAD binds to expected HEAD' },
        [pscustomobject]@{ observed = '$run.child.scenario_fingerprint'; expected = '$ExpectedScenarioFingerprint'; message = 'Child scenario binds to expected scenario' },
        [pscustomobject]@{ observed = "$atomicVariable.scenario_fingerprint"; expected = '$ExpectedScenarioFingerprint'; message = 'atomic manifest scenario binds to expected scenario' },
        [pscustomobject]@{ observed = '$timeline.scenario_fingerprint'; expected = '$ExpectedScenarioFingerprint'; message = 'timeline scenario binds to expected scenario' }
    )) {
        Assert-ContractCondition (
            (Test-ExpectedIdentityBinding $assertions $binding.observed $binding.expected)
        ) $binding.message
    }
    Assert-ContractCondition (
        (Test-AnyAssertion $assertions @(($atomicVariable + '.process_id'), '$launchEvidence.value.engine_process_id') '(?:-eq|-ceq)')
    ) "atomic manifest process_id equals the attested engine PID"

    Assert-ContractCondition ($atomicCanonicalAssignments.Count -eq 1 `
        -and $stdoutCanonicalAssignments.Count -eq 1 `
        -and (Test-ExpectedIdentityBinding $assertions ($atomicVariable + '.run_id') '$RunId') `
        -and (Test-ExpectedIdentityBinding $assertions ($atomicVariable + '.head_sha') '$HeadSha') `
        -and (Test-ExpectedIdentityBinding $assertions ($atomicVariable + '.scenario_fingerprint') '$ExpectedScenarioFingerprint')) `
        "canonical equality carries atomic run, HEAD, and scenario identity to the stdout manifest"
}

if ($null -ne $diagnosticAdmission) {
    $source = [string]$diagnosticAdmission.Extent.Text
    Assert-ContractCondition (
        (Test-SourceContainsAll $source @(
            '$diagnosticRunId',
            'Get-ColdRestoreAuthorizationRunId',
            'Resolve-ColdRestoreGitCommonDirectory',
            '$TargetedOwnerCaptureEvidenceRootRelativePath',
            '$diagnosticRoot',
            'targeted_owner_capture_diagnostic_v3'
        ))
    ) "diagnostic evidence root binds the HEAD-derived run ID to the authorization contract"
    Assert-ContractCondition (
        (Test-SourceContainsAll $source @(
            'launch_attestation_path',
            '$diagnosticRoot',
            '$quotaLedger.orchestrator_process_id',
            'producer.authorized.json'
        ))
    ) "diagnostic admission returns the fixed launch attestation path"
    Assert-ContractCondition (
        (Test-SourceContainsAll $source @(
            'manifest_path',
            '$diagnosticRoot',
            'child\producer.result.json'
        ))
    ) "diagnostic admission returns the fixed atomic manifest path"
}

if ($null -ne $consumeAdmission) {
    $newAdmissionCalls = @(Get-CommandAsts $consumeAdmission | Where-Object {
        [string]$_.GetCommandName() -ceq "New-ProcessARehearsalAdmission"
    })
    Assert-ContractCondition ($newAdmissionCalls.Count -eq 1) "rehearsal quota consumer calls New-ProcessARehearsalAdmission exactly once"
    $newAdmissionSource = if ($newAdmissionCalls.Count -eq 1) {
        [string]$newAdmissionCalls[0].Extent.Text
    }
    else {
        ""
    }
    Assert-ContractCondition (
        $newAdmissionSource -cmatch '(?s)-DiagnosticLaunchAttestationPath\s+\$DiagnosticAdmission\.launch_attestation_path'
    ) "New admission receives the fixed diagnostic launch attestation path"
    Assert-ContractCondition (
        $newAdmissionSource -cmatch '(?s)-DiagnosticManifestPath\s+\$DiagnosticAdmission\.manifest_path'
    ) "New admission receives the fixed diagnostic atomic manifest path"
}

$status = if ($script:failures.Count -eq 0) { "PASS" } else { "FAIL" }
Write-Output "TARGETED_OWNER_DIAGNOSTIC_MANIFEST_BINDING_CONTRACT_TEST|status=$status|checks=$script:checks|failures=$($script:failures.Count)"
foreach ($failure in $script:failures) {
    Write-Output "FAIL|$failure"
}
if ($script:failures.Count -gt 0) {
    exit 1
}
exit 0
