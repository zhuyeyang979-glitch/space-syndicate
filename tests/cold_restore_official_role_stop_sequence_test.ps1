[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$orchestratorPath = Join-Path $projectRoot "scripts/tools/cold_restore_vertical_slice_orchestrator.ps1"
$authorizationModulePath = Join-Path $projectRoot "scripts/tools/cold_restore_authorization_contract_v1.psm1"
Import-Module $authorizationModulePath
$script:checks = 0
$script:failures = [Collections.Generic.List[string]]::new()
$script:roleCalls = [Collections.Generic.List[string]]::new()
$script:failedRole = ""
$script:compareCalls = 0
$ORCHESTRATOR_SCHEMA_VERSION = 4
$FORMAL_FULL_RUN = $false
$DriverExecutionReady = $true
$RunId = Get-ColdRestoreAuthorizationRunId "official_attempt_2" ("a" * 40)
$ProcessSequence = @("Process A", "Process B", "Process C")

function Assert-SequenceCondition {
    param([bool]$Condition, [string]$Message)
    $script:checks += 1
    if (-not $Condition) { $script:failures.Add($Message) }
}

function Invoke-ColdRestoreRole {
    param([string]$Role)
    $script:roleCalls.Add($Role)
    if ($Role -ceq $script:failedRole) { throw "${Role}_fixture_failed" }
    return [pscustomobject]@{
        manifest = [pscustomobject]@{
            process_role = $Role
            queue_trigger_resolution_id = 73
            queue_trigger_stable_target_fingerprint = "a" * 64
        }
    }
}

function Compare-ColdRestoreManifests {
    $script:compareCalls += 1
    return [pscustomobject]@{ success = $true }
}

function Invoke-Fixture {
    param([string]$FailedRole)
    $script:roleCalls.Clear()
    $script:failedRole = $FailedRole
    $script:compareCalls = 0
    $script:OfficialAttempt2Progress = [ordered]@{
        claim_created = $true
        process_a_started = $false; process_a_completed = $false
        process_b_started = $false; process_b_completed = $false
        process_c_started = $false; process_c_completed = $false
        comparison_started = $false; comparison_completed = $false
    }
    $reason = ""
    try {
        $result = Invoke-ColdRestoreOfficialRoleChain "fixture" ("b" * 40) ("c" * 64) ([pscustomobject]@{})
    }
    catch {
        $reason = [string]$_.Exception.Message
        $result = $null
    }
    return [pscustomobject]@{
        calls = @($script:roleCalls)
        compare_calls = $script:compareCalls
        reason = $reason
        result = $result
        progress = [pscustomobject]$script:OfficialAttempt2Progress
    }
}

try {
    $tokens = $null
    $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($orchestratorPath, [ref]$tokens, [ref]$errors)
    Assert-SequenceCondition (@($errors).Count -eq 0) "orchestrator parses"
    $functions = @($ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] `
            -and [string]$node.Name -ceq "Invoke-ColdRestoreOfficialRoleChain"
    }, $true))
    Assert-SequenceCondition ($functions.Count -eq 1) "official role-chain function exists exactly once"
    if ($functions.Count -eq 1) {
        . ([scriptblock]::Create($functions[0].Extent.Text))
        $source = [string]$functions[0].Extent.Text
        $a = $source.IndexOf('"producer"', [StringComparison]::Ordinal)
        $b = $source.IndexOf('"consumer"', [StringComparison]::Ordinal)
        $c = $source.IndexOf('"validator"', [StringComparison]::Ordinal)
        $compare = $source.IndexOf("Compare-ColdRestoreManifests", [StringComparison]::Ordinal)
        Assert-SequenceCondition ($a -ge 0 -and $a -lt $b -and $b -lt $c -and $c -lt $compare) "A, B, C and comparison are strictly ordered"

        $failA = Invoke-Fixture "producer"
        Assert-SequenceCondition (($failA.calls -join ",") -ceq "producer" -and $failA.compare_calls -eq 0 -and $failA.reason -ceq "producer_fixture_failed") "A failure starts neither B nor C"
        Assert-SequenceCondition ([bool]$failA.progress.process_a_started -and -not [bool]$failA.progress.process_a_completed -and -not [bool]$failA.progress.process_b_started) "A failure records B and C as not started"
        $failB = Invoke-Fixture "consumer"
        Assert-SequenceCondition (($failB.calls -join ",") -ceq "producer,consumer" -and $failB.compare_calls -eq 0 -and $failB.reason -ceq "consumer_fixture_failed") "B failure starts no C"
        Assert-SequenceCondition ([bool]$failB.progress.process_a_completed -and [bool]$failB.progress.process_b_started -and -not [bool]$failB.progress.process_b_completed -and -not [bool]$failB.progress.process_c_started) "B failure records C as not started"
        $failC = Invoke-Fixture "validator"
        Assert-SequenceCondition (($failC.calls -join ",") -ceq "producer,consumer,validator" -and $failC.compare_calls -eq 0 -and $failC.reason -ceq "validator_fixture_failed") "C failure cannot reach comparison"
        Assert-SequenceCondition ([bool]$failC.progress.process_b_completed -and [bool]$failC.progress.process_c_started -and -not [bool]$failC.progress.process_c_completed -and -not [bool]$failC.progress.comparison_started) "C failure records comparison as not run"
        $green = Invoke-Fixture ""
        Assert-SequenceCondition (($green.calls -join ",") -ceq "producer,consumer,validator" -and $green.compare_calls -eq 1 -and $null -ne $green.result) "green chain runs A, B, C and comparison once"
        Assert-SequenceCondition ([bool]$green.progress.process_c_completed -and [bool]$green.progress.comparison_completed) "green chain records all roles and comparison complete"
    }

    foreach ($functionName in @(
        "New-AllowlistedResult",
        "Get-ColdRestoreOfficialAttempt2RoleStatus",
        "Get-ColdRestoreOfficialAttempt2FailureClass",
        "New-ColdRestoreOfficialAttempt2FailureResult"
    )) {
        $matches = @($ast.FindAll({
            param($node)
            $node -is [Management.Automation.Language.FunctionDefinitionAst] `
                -and [string]$node.Name -ceq $functionName
        }, $true))
        Assert-SequenceCondition ($matches.Count -eq 1) "$functionName exists exactly once"
        if ($matches.Count -eq 1) { . ([scriptblock]::Create($matches[0].Extent.Text)) }
    }
    $script:OfficialAttempt2Progress = [ordered]@{
        claim_created = $true
        process_a_started = $true; process_a_completed = $true
        process_b_started = $true; process_b_completed = $false
        process_c_started = $false; process_c_completed = $false
        comparison_started = $false; comparison_completed = $false
    }
    $failureResult = New-ColdRestoreOfficialAttempt2FailureResult "consumer_restore_failed"
    Assert-SequenceCondition ([string]$failureResult.official_attempt_2_failure_class -ceq "PROCESS_B_RESTORE_FAILED" `
        -and [string]$failureResult.process_a_status -ceq "GREEN" `
        -and [string]$failureResult.process_b_status -ceq "FAILED" `
        -and [string]$failureResult.process_c_status -ceq "NOT_RUN" `
        -and [string]$failureResult.comparison_status -ceq "NOT_RUN") "official failure projection preserves role GREEN, FAILED, and NOT_RUN states"
    Assert-SequenceCondition ([string]$failureResult.restore_deltas_zero -ceq "NOT_RUN" `
        -and [string]$failureResult.terminal_quiescent_frames -ceq "NOT_RUN") "unreached comparison evidence is never projected as false or zero"
    Assert-SequenceCondition ((Get-ColdRestoreOfficialAttempt2FailureClass "consumer_read_failed") `
        -ceq "PROCESS_B_RESTORE_FAILED") "Process B read failures map to the authorized restore class"
    Assert-SequenceCondition ((Get-ColdRestoreOfficialAttempt2FailureClass "consumer_exact_recapture_mismatch") `
        -ceq "PROCESS_B_RESTORE_FAILED") "Process B recapture failures map to the authorized restore class"
    $script:OfficialAttempt2Progress.claim_created = $false
    $script:OfficialAttempt2Progress.process_a_started = $false
    Assert-SequenceCondition ((Get-ColdRestoreOfficialAttempt2FailureClass "official_preclaim_failed") `
        -ceq "ENVIRONMENT_FAILURE") "preclaim failures use the authorized environment class"

    $orchestratorSource = [IO.File]::ReadAllText($orchestratorPath)
    $roleStart = $orchestratorSource.IndexOf("function Invoke-ColdRestoreRole", [StringComparison]::Ordinal)
    $roleEnd = $orchestratorSource.IndexOf("function Invoke-ColdRestoreOfficialRoleChain", $roleStart, [StringComparison]::Ordinal)
    $roleSource = $orchestratorSource.Substring($roleStart, $roleEnd - $roleStart)
    Assert-SequenceCondition ($roleSource.IndexOf('Assert-ColdRestoreCondition ([bool]$manifest.success)', [StringComparison]::Ordinal) -ge 0 -and $roleSource.IndexOf('Assert-ColdRestoreCondition ([bool]$manifest.success)', [StringComparison]::Ordinal) -lt $roleSource.LastIndexOf("return [pscustomobject]", [StringComparison]::Ordinal)) "each role rejects a failed manifest before returning to dispatch"
    $authorizationIndex = $orchestratorSource.IndexOf('$authorization = Assert-AndConsumeOfficialColdRestoreAuthorization $resolvedProjectPath $headSha', [StringComparison]::Ordinal)
    $chainIndex = $orchestratorSource.IndexOf('$chain = Invoke-ColdRestoreOfficialRoleChain', $authorizationIndex, [StringComparison]::Ordinal)
    Assert-SequenceCondition ($authorizationIndex -ge 0 -and $chainIndex -gt $authorizationIndex) "authorization must complete before Process A can start"
    Assert-SequenceCondition (-not $orchestratorSource.Contains('return "HARNESS_FAILURE"') `
        -and $orchestratorSource.Contains('return "ENVIRONMENT_FAILURE"')) "official failure classes stay inside the authorized closed enum"
    $publishIndex = $orchestratorSource.IndexOf('$claimFingerprint = cold_restore_official_attempt2_contract\Publish-ColdRestoreOfficialAttempt2Claim', [StringComparison]::Ordinal)
    $consumedCatchIndex = $orchestratorSource.IndexOf('if ([IO.File]::Exists($ledgerPath))', $publishIndex, [StringComparison]::Ordinal)
    $progressIndex = $orchestratorSource.IndexOf('$script:OfficialAttempt2Progress.claim_created = $true', $consumedCatchIndex, [StringComparison]::Ordinal)
    Assert-SequenceCondition ($publishIndex -ge 0 -and $consumedCatchIndex -gt $publishIndex -and $progressIndex -gt $consumedCatchIndex) "a published claim is reported consumed even when postpublication validation throws"
}
catch {
    $script:failures.Add("unexpected exception: $($_.Exception.Message)")
}

$status = if ($script:failures.Count -eq 0) { "PASS" } else { "FAIL" }
Write-Output "COLD_RESTORE_OFFICIAL_ROLE_STOP_SEQUENCE|status=$status|checks=$script:checks|failures=$($script:failures.Count)"
foreach ($failure in $script:failures) { Write-Output "FAIL|$failure" }
if ($script:failures.Count -gt 0) { exit 1 }
exit 0
