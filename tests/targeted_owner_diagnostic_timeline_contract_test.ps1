[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$orchestratorPath = Join-Path $projectRoot "scripts/tools/cold_restore_vertical_slice_orchestrator.ps1"
$phaseIds = @(
    "child_bootstrap", "scene_loaded", "session_started",
    "real_commodity_claim_complete", "real_normal_card_purchase_complete",
    "real_facility_economy_complete", "first_sale_receipt_complete",
    "ai_nondefault_state_complete", "queue_entry_committed", "restore_barrier_entered",
    "save_intent_submitted", "save_capture_complete", "envelope_encode_complete",
    "atomic_write_complete", "save_readback_complete", "allowlisted_manifest_complete",
    "child_completion_attestation_complete", "runtime_cleanup_complete", "quit_requested"
)
$notApplicableIds = @(
    "save_intent_submitted", "save_capture_complete", "envelope_encode_complete",
    "atomic_write_complete", "save_readback_complete"
)
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

function New-TargetedTimelineFixture {
    $rows = foreach ($phaseId in $phaseIds) {
        $notApplicable = $notApplicableIds -ccontains $phaseId
        [pscustomobject][ordered]@{
            phase_id = $phaseId
            success = -not $notApplicable
            reason_code = if ($notApplicable) { "not_applicable_targeted_diagnostic" } else { "ok" }
        }
    }
    return [pscustomobject]@{ phase_rows = @($rows) }
}

$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile(
    $orchestratorPath,
    [ref]$tokens,
    [ref]$parseErrors
)
Assert-ContractCondition (@($parseErrors).Count -eq 0) "orchestrator parses"
$functions = @($ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
        [string]$node.Name -ceq "Test-ColdRestoreTargetedDiagnosticTimeline"
}, $true))
Assert-ContractCondition ($functions.Count -eq 1) "targeted timeline validator exists exactly once"
if ($functions.Count -eq 1) {
    . ([scriptblock]::Create($functions[0].Extent.Text))
}

$valid = New-TargetedTimelineFixture
Assert-ContractCondition (Test-ColdRestoreTargetedDiagnosticTimeline $valid) "closed 19-row targeted timeline is accepted"

foreach ($phaseId in $notApplicableIds) {
    $wrongReason = New-TargetedTimelineFixture
    ($wrongReason.phase_rows | Where-Object { $_.phase_id -ceq $phaseId }).reason_code = "skipped_after_role_failure"
    Assert-ContractCondition (-not (Test-ColdRestoreTargetedDiagnosticTimeline $wrongReason)) "$phaseId rejects generic failure skip"
}

$unexpectedFailure = New-TargetedTimelineFixture
($unexpectedFailure.phase_rows | Where-Object { $_.phase_id -ceq "session_started" }).success = $false
($unexpectedFailure.phase_rows | Where-Object { $_.phase_id -ceq "session_started" }).reason_code = "session_failed"
Assert-ContractCondition (-not (Test-ColdRestoreTargetedDiagnosticTimeline $unexpectedFailure)) "non-N/A failure is rejected"

$missing = New-TargetedTimelineFixture
$missing.phase_rows = @($missing.phase_rows | Where-Object { $_.phase_id -cne "atomic_write_complete" })
Assert-ContractCondition (-not (Test-ColdRestoreTargetedDiagnosticTimeline $missing)) "truncated timeline is rejected"

$duplicate = New-TargetedTimelineFixture
$duplicate.phase_rows += $duplicate.phase_rows[10]
Assert-ContractCondition (-not (Test-ColdRestoreTargetedDiagnosticTimeline $duplicate)) "duplicate timeline row is rejected"

$wrongSuccess = New-TargetedTimelineFixture
($wrongSuccess.phase_rows | Where-Object { $_.phase_id -ceq "save_capture_complete" }).success = $true
Assert-ContractCondition (-not (Test-ColdRestoreTargetedDiagnosticTimeline $wrongSuccess)) "N/A phase cannot claim success"
Assert-ContractCondition (-not (Test-ColdRestoreTargetedDiagnosticTimeline $null)) "missing timeline is rejected"

$orchestratorSource = [IO.File]::ReadAllText($orchestratorPath)
Assert-ContractCondition (
    $orchestratorSource.Contains("Test-ColdRestoreTargetedDiagnosticTimeline `$timeline") -and
    $orchestratorSource.Contains("not_applicable_targeted_diagnostic")
) "targeted parent gate invokes the dedicated N/A contract"

$status = if ($script:failures.Count -eq 0) { "PASS" } else { "FAIL" }
Write-Output "TARGETED_OWNER_DIAGNOSTIC_TIMELINE_CONTRACT_TEST|status=$status|checks=$script:checks|failures=$($script:failures.Count)"
foreach ($failure in $script:failures) {
    Write-Output "FAIL|$failure"
}
if ($script:failures.Count -gt 0) {
    exit 1
}
exit 0
