$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "role_godot_mcp_parent_baseline_diagnostics.ps1")

$passed = 0
$total = 0
$failures = [System.Collections.Generic.List[string]]::new()
function Assert-ParentDispositionV1 {
    param([bool]$Condition, [string]$Name)
    $script:total += 1
    if ($Condition) { $script:passed += 1 } else { $script:failures.Add($Name) }
}

function New-ParentEnvironmentV1 {
    return [ordered]@{
        godot_executable_sha256 = "godot"
        godot_version = "4.7.stable"
        tooling_runtime_build_sha256 = "tooling"
        mcp_addon_tree = "addon"
        launch_arguments_sha256 = "launch"
        capture_backend = "raw"
        renderer = "compatibility"
        rendering_method = "gl_compatibility"
        rendering_driver = "opengl3"
        locale = "en-GB"
        ui_locale = "en-GB"
        powershell_version = $PSVersionTable.PSVersion.ToString()
        powershell_edition = [string]$PSVersionTable.PSEdition
        platform = "windows"
    }
}

function New-ParentDiagnosticV1 {
    param(
        [string]$Raw = "unicode",
        [string]$Stream = "editor_stderr",
        [string]$Phase = "initial_quiescence",
        [string]$Operation = "initial_scan",
        [string]$Category = "unicode_nul_diagnostic",
        [string]$OperationId = "filesystem-initial-scan-1",
        [bool]$Reimport = $false,
        [bool]$Parse = $false,
        [bool]$Load = $false,
        [bool]$Runtime = $false,
        [string]$Path = "",
        [int]$RawNul = 0,
        [int]$RecordIndex = 1
    )
    return [ordered]@{
        raw_bytes_sha256 = $Raw
        source_stream = $Stream
        lifecycle_phase = $Phase
        operation_type = $Operation
        operation_id = $OperationId
        stage_before_marker = $true
        category = $Category
        associated_path = $Path
        associated_resource = ""
        failed_load_correlated = $Load
        parse_failure_correlated = $Parse
        runtime_failure_correlated = $Runtime
        reimport_conflict_correlated = $Reimport
        reimport_conflict_role = if ($Reimport) { "root" } else { "none" }
        raw_nul_byte_count = $RawNul
        raw_utf8_valid = $true
        potential_diagnostic = $true
        record_index = $RecordIndex
        raw_byte_start = $RecordIndex * 10
    }
}

function New-ParentAttemptV1 {
    param(
        [string]$Cell,
        [string]$Head,
        [object[]]$Editor = @(),
        [object[]]$Recovery = @()
    )
    return [ordered]@{
        schema = "McpColdImportDiagnosticAttemptV2"
        cell_id = $Cell
        project_head = $Head
        project_head_match = $true
        project_tree_match = $true
        cache_was_fresh = $true
        initial_scan_green = $true
        import_quiescence_green = $true
        project_reload_green = $true
        script_discovery_green = $true
        stopped_cleanly = $true
        editor_exit_code = 0
        process_count_after = 0
        endpoint_count_after = 0
        reimport_conflict_count = @($Editor | Where-Object { $_.reimport_conflict_correlated }).Count
        environment = New-ParentEnvironmentV1
        editor_stderr = [ordered]@{ diagnostics = @($Editor) }
        recovery_import_stderr = [ordered]@{ diagnostics = @($Recovery) }
    }
}

$parentHead = "parent"
$targetHead = "target"
$unicode = New-ParentDiagnosticV1
$reimport = New-ParentDiagnosticV1 -Raw "reimport" -Phase "reimport" -Operation "reimport" -Category "reimport_task_conflict_root" -Reimport $true -RecordIndex 2
$mainParse = New-ParentDiagnosticV1 -Raw "main-parse" -Phase "recovery_import" -Operation "cold_cache_bootstrap" -Category "script_parse_error" -Parse $true -RecordIndex 3
$main = New-ParentAttemptV1 -Cell "C0_MAIN_A" -Head "main" -Editor @($mainParse)
$parentA = New-ParentAttemptV1 -Cell "C1_PARENT_A" -Head $parentHead -Editor @($unicode, $reimport)
$parentB = New-ParentAttemptV1 -Cell "C1_PARENT_B" -Head $parentHead -Editor @($unicode, $reimport)
$targetA = New-ParentAttemptV1 -Cell "C2_TARGET_A" -Head $targetHead -Editor @($unicode)
$targetB = New-ParentAttemptV1 -Cell "C2_TARGET_B" -Head $targetHead -Editor @($unicode, $reimport)
$green = Compare-McpParentBaselineDiagnosticDispositionV1 -Main $main -ParentA $parentA -ParentB $parentB -TargetA $targetA -TargetB $targetB -DirectParentSha $parentHead -TargetSha $targetHead
Assert-ParentDispositionV1 ([bool]$green.green) "stable_direct_parent_baseline_is_green"
Assert-ParentDispositionV1 ([string]$green.reimport_diagnostic_final_class -eq "baseline_engine_internal_reimport_progress_collision") "internal_reimport_is_parent_baseline"
Assert-ParentDispositionV1 ([string]$green.unicode_diagnostic_final_class -eq "baseline_engine_initial_import_unicode_diagnostic") "initial_quiescence_unicode_is_parent_baseline"
Assert-ParentDispositionV1 ([int]$green.target_new_reimport_conflict_fingerprint_count -eq 0) "no_new_reimport_fingerprint"
Assert-ParentDispositionV1 ([int]$green.target_additional_unicode_fingerprint_count -eq 0) "no_new_unicode_fingerprint"
Assert-ParentDispositionV1 ([int]$green.counts.historical_main_reference_diagnostic -eq 1 -and [int]$green.target_real_project_error_count -eq 0) "main_parse_is_historical_only"
Assert-ParentDispositionV1 ([bool]$green.diagnostic_accounting_reconciled -and [int]$green.duplicate_diagnostic_classification_count -eq 0) "accounting_reconciles"

$newReimport = New-ParentDiagnosticV1 -Raw "target-new-reimport" -Phase "reimport" -Operation "reimport" -Category "reimport_task_conflict_root" -Reimport $true -RecordIndex 4
$newTargetB = New-ParentAttemptV1 -Cell "C2_TARGET_B" -Head $targetHead -Editor @($unicode, $newReimport)
$newFingerprint = Compare-McpParentBaselineDiagnosticDispositionV1 -Main $main -ParentA $parentA -ParentB $parentB -TargetA $targetA -TargetB $newTargetB -DirectParentSha $parentHead -TargetSha $targetHead
Assert-ParentDispositionV1 (-not [bool]$newFingerprint.green -and [int]$newFingerprint.target_new_reimport_conflict_fingerprint_count -eq 1) "new_target_reimport_fingerprint_blocks"

$pathReimport = New-ParentDiagnosticV1 -Raw "reimport" -Phase "reimport" -Operation "reimport" -Category "reimport_task_conflict_root" -Reimport $true -Path "res://changed.gd" -RecordIndex 5
$pathTargetB = New-ParentAttemptV1 -Cell "C2_TARGET_B" -Head $targetHead -Editor @($unicode, $pathReimport)
$pathBlocked = Compare-McpParentBaselineDiagnosticDispositionV1 -Main $main -ParentA $parentA -ParentB $parentB -TargetA $targetA -TargetB $pathTargetB -DirectParentSha $parentHead -TargetSha $targetHead -ChangedFiles @("changed.gd")
Assert-ParentDispositionV1 (-not [bool]$pathBlocked.green -and [int]$pathBlocked.target_changed_file_error_count -eq 1) "changed_path_blocks"

$externalOverlap = Compare-McpParentBaselineDiagnosticDispositionV1 -Main $main -ParentA $parentA -ParentB $parentB -TargetA $targetA -TargetB $targetB -DirectParentSha $parentHead -TargetSha $targetHead -ExternalReimportOperationOverlapCount 1
Assert-ParentDispositionV1 (-not [bool]$externalOverlap.green -and [string]$externalOverlap.reason_code -eq "external_reimport_operation_overlap") "external_overlap_blocks"

$recoveryUnicode = New-ParentDiagnosticV1 -Stream "recovery_import_stderr" -Phase "recovery_import" -Operation "cold_cache_bootstrap" -RecordIndex 6
$parentRecoveryA = New-ParentAttemptV1 -Cell "C1_PARENT_A" -Head $parentHead -Editor @($unicode, $reimport) -Recovery @($recoveryUnicode)
$parentRecoveryB = New-ParentAttemptV1 -Cell "C1_PARENT_B" -Head $parentHead -Editor @($unicode, $reimport) -Recovery @($recoveryUnicode)
$targetRecoveryA = New-ParentAttemptV1 -Cell "C2_TARGET_A" -Head $targetHead -Editor @($unicode) -Recovery @($recoveryUnicode)
$targetRecoveryB = New-ParentAttemptV1 -Cell "C2_TARGET_B" -Head $targetHead -Editor @($unicode, $reimport) -Recovery @($recoveryUnicode)
$recoveryBlocked = Compare-McpParentBaselineDiagnosticDispositionV1 -Main $main -ParentA $parentRecoveryA -ParentB $parentRecoveryB -TargetA $targetRecoveryA -TargetB $targetRecoveryB -DirectParentSha $parentHead -TargetSha $targetHead
Assert-ParentDispositionV1 (-not [bool]$recoveryBlocked.green -and [int]$recoveryBlocked.target_unclassified_diagnostic_count -eq 2) "recovery_phase_unicode_fails_closed"

$nulUnicode = New-ParentDiagnosticV1 -RawNul 1 -RecordIndex 7
$nulParentA = New-ParentAttemptV1 -Cell "C1_PARENT_A" -Head $parentHead -Editor @($nulUnicode, $reimport)
$nulParentB = New-ParentAttemptV1 -Cell "C1_PARENT_B" -Head $parentHead -Editor @($nulUnicode, $reimport)
$nulTargetA = New-ParentAttemptV1 -Cell "C2_TARGET_A" -Head $targetHead -Editor @($nulUnicode)
$nulTargetB = New-ParentAttemptV1 -Cell "C2_TARGET_B" -Head $targetHead -Editor @($nulUnicode, $reimport)
$nulBlocked = Compare-McpParentBaselineDiagnosticDispositionV1 -Main $main -ParentA $nulParentA -ParentB $nulParentB -TargetA $nulTargetA -TargetB $nulTargetB -DirectParentSha $parentHead -TargetSha $targetHead
Assert-ParentDispositionV1 (-not [bool]$nulBlocked.green -and [int]$nulBlocked.target_unclassified_diagnostic_count -eq 2) "raw_nul_unicode_fails_closed"

$source = [System.IO.File]::ReadAllText((Join-Path $PSScriptRoot "role_godot_mcp_parent_baseline_diagnostics.ps1"))
Assert-ParentDispositionV1 (-not [regex]::IsMatch($source, '(?i)allowed_(unicode_)?error_count\s*=\s*[36]')) "no_fixed_count_allowance"
Assert-ParentDispositionV1 (-not [regex]::IsMatch($source, '(?i)contains\([^\r\n]*Unicode parsing error')) "no_unicode_message_allowlist"
Assert-ParentDispositionV1 (-not $source.Contains("initial_scan_quiescing") -and -not $source.Contains("reload_quiescing")) "no_import_quiescence_state_change"

Write-Output "MCP_PARENT_BASELINE_DISPOSITION_TESTS|passed=$passed|total=$total"
if ($failures.Count -gt 0) {
    foreach ($failure in $failures) { Write-Error "Parent baseline disposition test failed: $failure" }
    exit 1
}
