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
        [Parameter(Mandatory = $true)][string[]]$RightMarkers,
        [string]$RightPattern = ""
    )

    $variables = [Collections.Generic.List[string]]::new()
    $assignments = @($Ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.AssignmentStatementAst]
    }, $true))
    foreach ($assignment in $assignments) {
        $rightSource = [string]$assignment.Right.Extent.Text
        if (-not (Test-SourceContainsAll $rightSource $RightMarkers)) {
            continue
        }
        if ($RightPattern -ne "" -and $rightSource -notmatch $RightPattern) {
            continue
        }
        $leftSource = [string]$assignment.Left.Extent.Text
        if ($leftSource -match '^\$[A-Za-z_][A-Za-z0-9_]*$') {
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
            -and ($Pattern -eq "" -or $source -match $Pattern)) {
            return $true
        }
    }
    return $false
}

function Test-ArtifactComparisonBinding {
    param(
        [Parameter(Mandatory = $true)]$FunctionAst,
        [Parameter(Mandatory = $true)][object[]]$Assertions,
        [Parameter(Mandatory = $true)][string]$AtomicVariable,
        [Parameter(Mandatory = $true)][string]$StdoutVariable
    )

    $comparisonPattern = '(?i)(?:-c?eq|Compare-Object)'
    if (Test-AnyAssertion $Assertions @($AtomicVariable, $StdoutVariable) $comparisonPattern) {
        return $true
    }

    $derivedPattern = '(?i)(?:ConvertTo-Json|fingerprint|sha256|Get-FileHash|Get-ColdRestoreTextSha256)'
    $atomicCandidates = @($AtomicVariable) + @(
        Get-AssignmentVariables $FunctionAst @($AtomicVariable) $derivedPattern
    )
    $stdoutCandidates = @($StdoutVariable) + @(
        Get-AssignmentVariables $FunctionAst @($StdoutVariable) $derivedPattern
    )
    foreach ($atomicCandidate in @($atomicCandidates | Select-Object -Unique)) {
        foreach ($stdoutCandidate in @($stdoutCandidates | Select-Object -Unique)) {
            if ($atomicCandidate -ceq $stdoutCandidate) {
                continue
            }
            if (Test-AnyAssertion $Assertions @($atomicCandidate, $stdoutCandidate) $comparisonPattern) {
                return $true
            }
        }
    }
    return $false
}

function Test-ParentStdoutShaBinding {
    param(
        [Parameter(Mandatory = $true)]$FunctionAst,
        [Parameter(Mandatory = $true)][object[]]$Assertions
    )

    $hashPattern = '(?i)(?:Get-FileHash|Get-ColdRestoreTextSha256)'
    if (Test-AnyAssertion $Assertions @('$paths.stdout', '$run.parent.stdout_sha256') $hashPattern) {
        return $true
    }
    $hashVariables = Get-AssignmentVariables $FunctionAst @('$paths.stdout') $hashPattern
    foreach ($hashVariable in $hashVariables) {
        if (Test-AnyAssertion $Assertions @($hashVariable, '$run.parent.stdout_sha256') '(?i)-c?eq') {
            return $true
        }
    }
    return $false
}

$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile(
    $orchestratorPath,
    [ref]$tokens,
    [ref]$parseErrors
)
Assert-ContractCondition ($parseErrors.Count -eq 0) "orchestrator parses without PowerShell syntax errors"

$rehearsalFunction = Get-FunctionAst $ast "Invoke-ColdRestoreNonOfficialProcessA"
Assert-ContractCondition ($null -ne $rehearsalFunction) "orchestrator has exactly one nonofficial Process A function"

if ($null -ne $rehearsalFunction) {
    $functionSource = [string]$rehearsalFunction.Extent.Text
    $commands = Get-CommandAsts $rehearsalFunction
    $assertions = @($commands | Where-Object {
        [string]$_.GetCommandName() -ceq "Assert-ColdRestoreCondition"
    })

    $timeoutReadIndex = $functionSource.IndexOf('$timeout = Get-ColdRestoreRoleTimeout "process_a"', [StringComparison]::Ordinal)
    $timeoutGateIndex = $functionSource.IndexOf('"process_a_rehearsal_timeout_policy_invalid"', [StringComparison]::Ordinal)
    $quotaIndex = $functionSource.IndexOf('Consume-ColdRestoreProcessARehearsalQuota', [StringComparison]::Ordinal)
    Assert-ContractCondition (
        $timeoutReadIndex -ge 0 -and $timeoutGateIndex -gt $timeoutReadIndex -and $quotaIndex -gt $timeoutGateIndex `
            -and (Test-SourceContainsAll $functionSource @(
                '$timeout.absolute_timeout_seconds -eq 180',
                '$timeout.no_progress_timeout_seconds -eq 60'
            ))
    ) "Process A 180/60 timeout is exact and validated before rehearsal quota consumption"

    $initialPrerequisiteIndex = $functionSource.IndexOf(
        '$stage3Prerequisites = Assert-ColdRestoreProcessARehearsalPrerequisites',
        [StringComparison]::Ordinal
    )
    $revalidatedPrerequisiteIndex = $functionSource.IndexOf(
        '$revalidatedStage3Prerequisites = Assert-ColdRestoreProcessARehearsalPrerequisites',
        [StringComparison]::Ordinal
    )
    $prerequisiteDriftGateIndex = $functionSource.IndexOf(
        '"process_a_rehearsal_prerequisites_changed_after_admission"',
        [StringComparison]::Ordinal
    )
    $postCommitSourceGateIndex = $functionSource.IndexOf(
        'Assert-ProcessARehearsalAdmissionSourcesUnchanged',
        [StringComparison]::Ordinal
    )
    Assert-ContractCondition (
        $initialPrerequisiteIndex -ge 0 -and $initialPrerequisiteIndex -lt $quotaIndex `
            -and $revalidatedPrerequisiteIndex -gt $quotaIndex `
            -and $prerequisiteDriftGateIndex -gt $revalidatedPrerequisiteIndex `
            -and $postCommitSourceGateIndex -gt $prerequisiteDriftGateIndex
    ) "Stage 3 prerequisites are recomputed and compared immediately after admission commit"
    Assert-ContractCondition (
        $functionSource.Contains(
            '-PrerequisiteEvidenceFingerprint ([string]$revalidatedStage3Prerequisites.evidence_fingerprint)'
        )
    ) "post-admission source and launch gates consume the revalidated prerequisite fingerprint"

    $atomicAssignments = @(
        Get-AssignmentVariables $rehearsalFunction @('Read-ColdRestoreJsonArtifact', '$paths.child_result')
    )
    $stdoutAssignments = @(
        Get-AssignmentVariables $rehearsalFunction @('Read-ColdRestoreManifest', '$paths.stdout')
    )
    Assert-ContractCondition ($atomicAssignments.Count -eq 1) "rehearsal reads exactly one atomic child-result manifest"
    Assert-ContractCondition ($stdoutAssignments.Count -eq 1) "rehearsal reads exactly one manifest from captured stdout"

    $atomicVariable = if ($atomicAssignments.Count -eq 1) { $atomicAssignments[0] } else { '$manifest' }
    $stdoutVariable = if ($stdoutAssignments.Count -eq 1) { $stdoutAssignments[0] } else { '$stdoutManifest' }
    Assert-ContractCondition (
        (Test-ArtifactComparisonBinding $rehearsalFunction $assertions $atomicVariable $stdoutVariable)
    ) "atomic and stdout manifests are compared before rehearsal acceptance"
    Assert-ContractCondition (
        (Test-ParentStdoutShaBinding $rehearsalFunction $assertions)
    ) "stdout manifest bytes are bound to Parent stdout_sha256"

    Assert-ContractCondition (
        (Test-AnyAssertion $assertions @('$timeline.scenario_fingerprint', '$ExpectedScenarioFingerprint') '(?i)-c?eq')
    ) "timeline scenario_fingerprint equals the expected scenario"
    Assert-ContractCondition (
        (Test-AnyAssertion $assertions @('$timeline.official', '-not'))
    ) "timeline is explicitly nonofficial"
    Assert-ContractCondition (
        (Test-AnyAssertion $assertions @('$timeline.phase_rows', '.Count', '19') '(?i)-c?eq')
    ) "timeline has exactly 19 phase rows"

    $allPhaseRowsGreen = Test-AnyAssertion `
        $assertions `
        @('$timeline.phase_rows', 'success') `
        '(?i)(?:Where-Object|\.Where\s*\()'
    if (-not $allPhaseRowsGreen) {
        $derivedPhaseVariables = Get-AssignmentVariables `
            $rehearsalFunction `
            @('$timeline.phase_rows', 'success') `
            '(?i)(?:Where-Object|\.Where\s*\()'
        foreach ($phaseVariable in $derivedPhaseVariables) {
            if (Test-AnyAssertion $assertions @($phaseVariable) '(?i)(?:-c?eq\s+(?:0|19)|-not)') {
                $allPhaseRowsGreen = $true
                break
            }
        }
    }
    Assert-ContractCondition $allPhaseRowsGreen "all 19 timeline phase rows must report success"

    $comparisonPattern = '(?i)-c?eq'
    Assert-ContractCondition (
        (Test-AnyAssertion $assertions @('$run.child.run_id', '$RunId') $comparisonPattern) `
        -and (Test-AnyAssertion $assertions @('$manifest.run_id', '$RunId') $comparisonPattern) `
        -and (Test-AnyAssertion $assertions @('$timeline.run_id', '$RunId') $comparisonPattern)
    ) "child, manifest, and timeline run IDs bind to the expected run"
    Assert-ContractCondition (
        (Test-AnyAssertion $assertions @('$run.child.repository_head', '$HeadSha') $comparisonPattern) `
        -and (Test-AnyAssertion $assertions @('$manifest.head_sha', '$HeadSha') $comparisonPattern) `
        -and (Test-AnyAssertion $assertions @('$timeline.repository_head', '$HeadSha') $comparisonPattern)
    ) "child, manifest, and timeline HEADs bind to the expected HEAD"
    Assert-ContractCondition (
        (Test-AnyAssertion $assertions @('$run.child.scenario_fingerprint', '$ExpectedScenarioFingerprint') $comparisonPattern) `
        -and (Test-AnyAssertion $assertions @('$timeline.scenario_fingerprint', '$ExpectedScenarioFingerprint') $comparisonPattern)
    ) "child and timeline scenario fingerprints bind to the expected scenario"

    $roleCallsInsideRehearsal = @($commands | Where-Object {
        [string]$_.GetCommandName() -ceq "Invoke-ColdRestoreRole"
    })
    Assert-ContractCondition ($roleCallsInsideRehearsal.Count -eq 0) "nonofficial Process A function cannot launch Process B or C"

    $dispatchBlocks = @($ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.IfStatementAst]
    }, $true) | Where-Object {
        Test-SourceContainsAll ([string]$_.Extent.Text) @('$NonOfficialProcessA', 'Invoke-ColdRestoreNonOfficialProcessA')
    })
    Assert-ContractCondition ($dispatchBlocks.Count -eq 1) "orchestrator has one nonofficial Process A dispatch block"
    if ($dispatchBlocks.Count -eq 1) {
        $dispatchSource = [string]$dispatchBlocks[0].Extent.Text
        Assert-ContractCondition ($dispatchSource -match '(?im)^\s*exit\s+0\s*$') "nonofficial Process A dispatch exits before official roles"

        $allCommands = Get-CommandAsts $ast
        $chainFunction = Get-FunctionAst $ast "Invoke-ColdRestoreOfficialRoleChain"
        $chainCommands = Get-CommandAsts $chainFunction
        $consumerCalls = @($chainCommands | Where-Object {
            [string]$_.GetCommandName() -ceq "Invoke-ColdRestoreRole" `
                -and [string]$_.Extent.Text -match '(?i)["'']consumer["'']'
        })
        $validatorCalls = @($chainCommands | Where-Object {
            [string]$_.GetCommandName() -ceq "Invoke-ColdRestoreRole" `
                -and [string]$_.Extent.Text -match '(?i)["'']validator["'']'
        })
        $officialChainDispatch = @($allCommands | Where-Object {
            [string]$_.GetCommandName() -ceq "Invoke-ColdRestoreOfficialRoleChain" `
                -and $_.Extent.StartOffset -gt $dispatchBlocks[0].Extent.EndOffset
        })
        $officialRolesAfterExit = $consumerCalls.Count -eq 1 `
            -and $validatorCalls.Count -eq 1 `
            -and $officialChainDispatch.Count -eq 1
        Assert-ContractCondition $officialRolesAfterExit "Process B and C calls exist only after the exited nonofficial branch"
    }
}

$status = if ($script:failures.Count -eq 0) { "PASS" } else { "FAIL" }
Write-Output "PROCESS_A_REHEARSAL_EVIDENCE_BINDING_CONTRACT_TEST|status=$status|checks=$script:checks|failures=$($script:failures.Count)"
foreach ($failure in $script:failures) {
    Write-Output "FAIL|$failure"
}
if ($script:failures.Count -gt 0) {
    exit 1
}
exit 0
