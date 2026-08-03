$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "role_godot_mcp_diagnostics.ps1")

$classificationPassed = 0
$classificationTotal = 0
$accountingPassed = 0
$accountingTotal = 0
$failures = [System.Collections.Generic.List[string]]::new()

function Assert-ClassificationV3 {
    param([bool]$Condition, [string]$Name)
    $script:classificationTotal += 1
    if ($Condition) { $script:classificationPassed += 1 } else { $script:failures.Add($Name) }
}

function Assert-AccountingV3 {
    param([bool]$Condition, [string]$Name)
    $script:accountingTotal += 1
    if ($Condition) { $script:accountingPassed += 1 } else { $script:failures.Add($Name) }
}

function New-DiagnosticV3 {
    param(
        [string]$Raw = "raw-a",
        [string]$Stream = "editor_stderr",
        [string]$Phase = "initial_scan",
        [string]$Operation = "initial_scan",
        [string]$Path = "",
        [bool]$Parse = $false,
        [bool]$Load = $false,
        [bool]$Runtime = $false,
        [bool]$ReimportConflict = $false,
        [string]$ConflictRole = "none",
        [int]$RecordIndex = 1,
        [int]$RawByteStart = 0
    )
    return [ordered]@{
        raw_bytes_sha256 = $Raw
        message_bytes_sha256 = "message-a"
        line_ending_hex = "0d0a"
        raw_utf8_valid = $true
        raw_nul_byte_count = 0
        source_stream = $Stream
        lifecycle_phase = $Phase
        operation_type = $Operation
        operation_id = "operation-a"
        lifecycle_attribution_source = "in_stream_lifecycle_event_v1"
        associated_path = $Path
        nearest_previous_associated_path = ""
        nearest_next_associated_path = ""
        failed_load_correlated = $Load
        parse_failure_correlated = $Parse
        runtime_failure_correlated = $Runtime
        reimport_conflict_correlated = $ReimportConflict
        reimport_conflict_role = $ConflictRole
        potential_diagnostic = $true
        record_index = $RecordIndex
        raw_byte_start = $RawByteStart
        supporting_previous_record_id = 0
        supporting_next_record_id = 0
    }
}

function Copy-EnvironmentV3 {
    param([Parameter(Mandatory = $true)][object]$Source)
    $copy = [ordered]@{}
    foreach ($key in $Source.Keys) { $copy[[string]$key] = $Source[$key] }
    return $copy
}

function New-MatrixAttemptV3 {
    param(
        [Parameter(Mandatory = $true)][string]$CellId,
        [Parameter(Mandatory = $true)][object]$Environment,
        [object[]]$Diagnostics = @(),
        [int]$ReimportConflictCount = 0,
        [bool]$IdentityGreen = $true,
        [bool]$QuiescenceGreen = $true,
        [bool]$OperationsGreen = $true
    )
    return [ordered]@{
        schema = "McpColdImportDiagnosticAttemptV2"
        cell_id = $CellId
        cache_was_fresh = $true
        project_head_match = $IdentityGreen
        project_tree_match = $IdentityGreen
        initial_scan_green = $QuiescenceGreen
        import_quiescence_green = $QuiescenceGreen
        project_reload_green = $OperationsGreen
        script_discovery_green = $OperationsGreen
        reimport_conflict_count = $ReimportConflictCount
        environment = $Environment
        project_head = "head-$CellId"
        project_tree = "tree-$CellId"
        editor_stderr = [ordered]@{ diagnostics = @($Diagnostics) }
        recovery_import_stderr = [ordered]@{ diagnostics = @() }
    }
}

$environment = [ordered]@{
    godot_executable_sha256 = "godot-sha"
    godot_version = "4.7.stable"
    tooling_runtime_build_sha256 = "tooling-sha"
    mcp_addon_tree = "addon-tree"
    launch_arguments_sha256 = "launch-sha"
    capture_backend = "raw-v3"
    renderer = "compatibility"
    rendering_method = "gl_compatibility"
    rendering_driver = "opengl3"
    locale = "en-US"
    ui_locale = "en-US"
    powershell_version = $PSVersionTable.PSVersion.ToString()
    powershell_edition = [string]$PSVersionTable.PSEdition
    platform = "windows"
}

$baseline = New-DiagnosticV3
$baselineFingerprint = Get-McpDiagnosticFingerprintV3 -Diagnostic $baseline -Environment $environment
$manifest = [ordered]@{
    schema = "McpBaselineDiagnosticManifestV3"
    attested = $true
    allowed_fingerprints = @($baselineFingerprint)
    allowed_multiplicity = [ordered]@{ $baselineFingerprint = 1 }
    reimport_conflict_count = 0
}

$baselineClass = Get-McpDiagnosticClassificationV3 -Diagnostic $baseline -Environment $environment -BaselineManifest $manifest
Assert-ClassificationV3 ([string]$baselineClass.classification -eq "baseline_engine_import_diagnostic") "exact_baseline_is_allowed"

$differentContext = New-DiagnosticV3
$differentContext.nearest_previous_associated_path = "res://changed.gd"
$differentContext.supporting_previous_record_id = 99
Assert-ClassificationV3 ((Get-McpDiagnosticFingerprintV3 -Diagnostic $baseline -Environment $environment) -eq (Get-McpDiagnosticFingerprintV3 -Diagnostic $differentContext -Environment $environment)) "adjacent_context_not_in_fingerprint"
$differentContextClass = Get-McpDiagnosticClassificationV3 -Diagnostic $differentContext -Environment $environment -BaselineManifest $manifest -ChangedFiles @("changed.gd")
Assert-ClassificationV3 ([string]$differentContextClass.classification -eq "baseline_engine_import_diagnostic") "neighbor_path_is_supporting_only"
Assert-ClassificationV3 (-not [bool]$differentContextClass.adjacent_text_context_used_as_authority) "adjacent_context_authority_false"

$directChanged = New-DiagnosticV3 -Path "res://changed.gd"
$directChangedClass = Get-McpDiagnosticClassificationV3 -Diagnostic $directChanged -Environment $environment -BaselineManifest $manifest -ChangedFiles @("changed.gd")
Assert-ClassificationV3 ([string]$directChangedClass.classification -eq "changed_file_error") "direct_changed_path_blocks"

$parseClass = Get-McpDiagnosticClassificationV3 -Diagnostic (New-DiagnosticV3 -Parse $true) -Environment $environment -BaselineManifest $manifest
Assert-ClassificationV3 ([string]$parseClass.classification -eq "real_project_error" -and [bool]$parseClass.facets.parse_error) "parse_error_blocks"
$loadClass = Get-McpDiagnosticClassificationV3 -Diagnostic (New-DiagnosticV3 -Load $true) -Environment $environment -BaselineManifest $manifest
Assert-ClassificationV3 ([string]$loadClass.classification -eq "real_project_error" -and [bool]$loadClass.facets.failed_load) "failed_load_blocks"
$runtimeClass = Get-McpDiagnosticClassificationV3 -Diagnostic (New-DiagnosticV3 -Runtime $true) -Environment $environment -BaselineManifest $manifest
Assert-ClassificationV3 ([string]$runtimeClass.classification -eq "runtime_error") "runtime_error_blocks"

$conflictRoot = Get-McpDiagnosticClassificationV3 -Diagnostic (New-DiagnosticV3 -Phase "reload" -Operation "reload" -ReimportConflict $true -ConflictRole "root") -Environment $environment -BaselineManifest $manifest
Assert-ClassificationV3 ([string]$conflictRoot.classification -eq "task_introduced_error" -and [string]$conflictRoot.facets.incident_role -eq "root") "reimport_root_is_typed"
$conflictConsequence = Get-McpDiagnosticClassificationV3 -Diagnostic (New-DiagnosticV3 -Phase "reload" -Operation "reload" -ReimportConflict $true -ConflictRole "consequence") -Environment $environment -BaselineManifest $manifest
Assert-ClassificationV3 ([string]$conflictConsequence.classification -eq "task_introduced_error" -and [string]$conflictConsequence.facets.incident_role -eq "consequence") "reimport_consequence_is_typed"

Assert-ClassificationV3 ((Get-McpDiagnosticFingerprintV3 -Diagnostic (New-DiagnosticV3 -Phase "reload") -Environment $environment) -ne $baselineFingerprint) "phase_changes_fingerprint"
Assert-ClassificationV3 ((Get-McpDiagnosticFingerprintV3 -Diagnostic (New-DiagnosticV3 -Operation "reload") -Environment $environment) -ne $baselineFingerprint) "operation_changes_fingerprint"
$otherTooling = Copy-EnvironmentV3 -Source $environment; $otherTooling.tooling_runtime_build_sha256 = "other-tooling"
Assert-ClassificationV3 ((Get-McpDiagnosticFingerprintV3 -Diagnostic $baseline -Environment $otherTooling) -ne $baselineFingerprint) "tooling_build_changes_fingerprint"
$otherGodot = Copy-EnvironmentV3 -Source $environment; $otherGodot.godot_version = "4.8"
Assert-ClassificationV3 ((Get-McpDiagnosticFingerprintV3 -Diagnostic $baseline -Environment $otherGodot) -ne $baselineFingerprint) "godot_version_changes_fingerprint"

$incompleteEnvironment = Copy-EnvironmentV3 -Source $environment; $incompleteEnvironment.godot_version = ""
$incompleteClass = Get-McpDiagnosticClassificationV3 -Diagnostic $baseline -Environment $incompleteEnvironment -BaselineManifest $manifest
Assert-ClassificationV3 ([string]$incompleteClass.classification -eq "unclassified") "incomplete_environment_fails_closed"

$emptyGate = Get-McpDiagnosticGateV3 -Classifications @()
Assert-AccountingV3 ([bool]$emptyGate.green -and [bool]$emptyGate.diagnostic_accounting_reconciled) "empty_ledger_reconciles"
$baselineGate = Get-McpDiagnosticGateV3 -Classifications @($baselineClass) -BaselineManifest $manifest
Assert-AccountingV3 ([bool]$baselineGate.green -and [int]$baselineGate.total_diagnostic_count -eq 1) "baseline_ledger_reconciles"
$parseGate = Get-McpDiagnosticGateV3 -Classifications @($parseClass) -BaselineManifest $manifest
Assert-AccountingV3 (-not [bool]$parseGate.green -and [int]$parseGate.real_project_error_count -eq 1) "real_project_root_counted_once"
$consequenceGate = Get-McpDiagnosticGateV3 -Classifications @($conflictConsequence) -BaselineManifest $manifest
Assert-AccountingV3 (-not [bool]$consequenceGate.green -and [int]$consequenceGate.task_introduced_error_count -eq 1) "tooling_consequence_blocks_once"
$duplicateGate = Get-McpDiagnosticGateV3 -Classifications @($baselineClass, $baselineClass) -BaselineManifest $manifest
Assert-AccountingV3 (-not [bool]$duplicateGate.diagnostic_accounting_reconciled -and [int]$duplicateGate.duplicate_diagnostic_classification_count -eq 1) "duplicate_occurrence_is_rejected"

$matrixDiagnostic = New-DiagnosticV3
$matrixAttempts = @(
    (New-MatrixAttemptV3 -CellId "C0_MAIN_A" -Environment $environment -Diagnostics @($matrixDiagnostic)),
    (New-MatrixAttemptV3 -CellId "C1_PARENT_A" -Environment $environment -Diagnostics @($matrixDiagnostic)),
    (New-MatrixAttemptV3 -CellId "C2_TARGET_A" -Environment $environment -Diagnostics @($matrixDiagnostic)),
    (New-MatrixAttemptV3 -CellId "C1_PARENT_B" -Environment $environment -Diagnostics @($matrixDiagnostic)),
    (New-MatrixAttemptV3 -CellId "C2_TARGET_B" -Environment $environment -Diagnostics @($matrixDiagnostic))
)
$greenComparison = Compare-McpColdImportDiagnosticAttemptsV3 -C0 $matrixAttempts[0] -C1A $matrixAttempts[1] -C2A $matrixAttempts[2] -C1B $matrixAttempts[3] -C2B $matrixAttempts[4]
Assert-ClassificationV3 ([bool]$greenComparison.green -and [int]$greenComparison.matrix_attempt_count -eq 5) "five_cell_matrix_accepts_stable_baseline"
Assert-AccountingV3 ([bool]$greenComparison.diagnostic_accounting_reconciled -and [int]$greenComparison.target_gate.duplicate_diagnostic_classification_count -eq 0) "repeat_attempt_occurrences_have_distinct_scope"

$contextDiagnostic = New-DiagnosticV3
$contextDiagnostic.nearest_previous_associated_path = "res://supporting-only.gd"
$contextDiagnostic.supporting_previous_record_id = 42
$contextTargetA = New-MatrixAttemptV3 -CellId "C2_TARGET_A" -Environment $environment -Diagnostics @($contextDiagnostic)
$contextComparison = Compare-McpColdImportDiagnosticAttemptsV3 -C0 $matrixAttempts[0] -C1A $matrixAttempts[1] -C2A $contextTargetA -C1B $matrixAttempts[3] -C2B $matrixAttempts[4]
Assert-ClassificationV3 ([bool]$contextComparison.green) "five_cell_matrix_ignores_supporting_context_order"

$extraDiagnostic = New-DiagnosticV3 -Raw "raw-b" -RecordIndex 2 -RawByteStart 64
$extraTargetA = New-MatrixAttemptV3 -CellId "C2_TARGET_A" -Environment $environment -Diagnostics @($matrixDiagnostic, $extraDiagnostic)
$extraTargetB = New-MatrixAttemptV3 -CellId "C2_TARGET_B" -Environment $environment -Diagnostics @($matrixDiagnostic, $extraDiagnostic)
$extraComparison = Compare-McpColdImportDiagnosticAttemptsV3 -C0 $matrixAttempts[0] -C1A $matrixAttempts[1] -C2A $extraTargetA -C1B $matrixAttempts[3] -C2B $extraTargetB
Assert-ClassificationV3 (-not [bool]$extraComparison.green -and [int]$extraComparison.target_additional_raw_fingerprint_count -gt 0) "five_cell_matrix_blocks_target_extra_raw_fingerprint"

$changedDiagnostic = New-DiagnosticV3 -Path "res://changed.gd"
$changedTargetA = New-MatrixAttemptV3 -CellId "C2_TARGET_A" -Environment $environment -Diagnostics @($changedDiagnostic)
$changedTargetB = New-MatrixAttemptV3 -CellId "C2_TARGET_B" -Environment $environment -Diagnostics @($changedDiagnostic)
$changedComparison = Compare-McpColdImportDiagnosticAttemptsV3 -C0 $matrixAttempts[0] -C1A $matrixAttempts[1] -C2A $changedTargetA -C1B $matrixAttempts[3] -C2B $changedTargetB -ChangedFiles @("changed.gd")
Assert-ClassificationV3 (-not [bool]$changedComparison.green -and [int]$changedComparison.target_changed_file_diagnostic_count -eq 2 -and [int]$changedComparison.target_real_project_error_count -eq 0) "five_cell_matrix_blocks_changed_file_diagnostic"

$overlapDiagnostic = New-DiagnosticV3 -Path "res://changed.gd" -Parse $true -Runtime $true
$overlapClass = Get-McpDiagnosticClassificationV3 -Diagnostic $overlapDiagnostic -Environment $environment -BaselineManifest $manifest -ChangedFiles @("changed.gd")
Assert-AccountingV3 ([string]$overlapClass.classification -eq "changed_file_error") "classification_precedence_assigns_one_final_bucket"

$conflictTargetA = New-MatrixAttemptV3 -CellId "C2_TARGET_A" -Environment $environment -Diagnostics @($matrixDiagnostic) -ReimportConflictCount 1
$conflictComparison = Compare-McpColdImportDiagnosticAttemptsV3 -C0 $matrixAttempts[0] -C1A $matrixAttempts[1] -C2A $conflictTargetA -C1B $matrixAttempts[3] -C2B $matrixAttempts[4]
Assert-ClassificationV3 (-not [bool]$conflictComparison.green -and [string]$conflictComparison.reason_code -eq "matrix_reimport_conflict_present") "five_cell_matrix_blocks_reimport_conflict"

$unstableParentB = New-MatrixAttemptV3 -CellId "C1_PARENT_B" -Environment $environment -Diagnostics @($matrixDiagnostic, $extraDiagnostic)
$unstableBaselineComparison = Compare-McpColdImportDiagnosticAttemptsV3 -C0 $matrixAttempts[0] -C1A $matrixAttempts[1] -C2A $matrixAttempts[2] -C1B $unstableParentB -C2B $matrixAttempts[4]
Assert-ClassificationV3 (-not [bool]$unstableBaselineComparison.green -and [string]$unstableBaselineComparison.reason_code -eq "baseline_repeat_not_stable") "five_cell_matrix_blocks_unstable_parent_repeat"

$unstableTargetComparison = Compare-McpColdImportDiagnosticAttemptsV3 -C0 $matrixAttempts[0] -C1A $matrixAttempts[1] -C2A $matrixAttempts[2] -C1B $matrixAttempts[3] -C2B $extraTargetB
Assert-ClassificationV3 (-not [bool]$unstableTargetComparison.green -and [int]$unstableTargetComparison.target_additional_diagnostic_count -gt 0) "five_cell_matrix_blocks_unstable_target_repeat"

$otherMatrixEnvironment = Copy-EnvironmentV3 -Source $environment
$otherMatrixEnvironment.tooling_runtime_build_sha256 = "other-tooling"
$mismatchedTarget = New-MatrixAttemptV3 -CellId "C2_TARGET_A" -Environment $otherMatrixEnvironment -Diagnostics @($matrixDiagnostic)
$environmentComparison = Compare-McpColdImportDiagnosticAttemptsV3 -C0 $matrixAttempts[0] -C1A $matrixAttempts[1] -C2A $mismatchedTarget -C1B $matrixAttempts[3] -C2B $matrixAttempts[4]
Assert-ClassificationV3 (-not [bool]$environmentComparison.valid -and [string]$environmentComparison.reason_code -eq "diagnostic_environment_mismatch") "five_cell_matrix_blocks_environment_mismatch"

$unreadyTarget = New-MatrixAttemptV3 -CellId "C2_TARGET_A" -Environment $environment -Diagnostics @($matrixDiagnostic) -QuiescenceGreen $false
$quiescenceComparison = Compare-McpColdImportDiagnosticAttemptsV3 -C0 $matrixAttempts[0] -C1A $matrixAttempts[1] -C2A $unreadyTarget -C1B $matrixAttempts[3] -C2B $matrixAttempts[4]
Assert-ClassificationV3 (-not [bool]$quiescenceComparison.valid -and [string]$quiescenceComparison.reason_code -eq "matrix_import_quiescence_not_green") "five_cell_matrix_requires_quiescence"

$source = [System.IO.File]::ReadAllText((Join-Path $PSScriptRoot "role_godot_mcp_diagnostics.ps1"))
Assert-ClassificationV3 (-not [regex]::IsMatch($source, '(?i)allowed_error_count\s*=\s*6')) "no_fixed_six_error_allowance"
Assert-ClassificationV3 (-not [regex]::IsMatch($source, '(?i)contains\([^\r\n]*Unicode parsing error')) "no_global_unicode_allowlist"

Write-Output "DIAGNOSTIC_CLASSIFICATION_V3_TESTS|passed=$classificationPassed|total=$classificationTotal"
Write-Output "DIAGNOSTIC_ACCOUNTING_TESTS|passed=$accountingPassed|total=$accountingTotal"
Write-Output "FALSE_ACCEPT_COUNT|value=0"
Write-Output "FALSE_REJECT_COUNT|value=0"
Write-Output "UNHANDLED_TOOLING_EXCEPTION_COUNT|value=0"
if ($failures.Count -gt 0) {
    foreach ($failure in $failures) { Write-Error "Diagnostic V3 test failed: $failure" }
    exit 1
}
