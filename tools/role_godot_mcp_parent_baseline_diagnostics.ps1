$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot "role_godot_mcp_diagnostics.ps1")

function Get-McpParentBaselineAttemptDiagnosticsV1 {
    param([Parameter(Mandatory = $true)][object]$Attempt)

    $recovery = Get-McpDiagnosticObjectValueV2 -Object $Attempt -Name "recovery_import_stderr"
    return @(
        @($Attempt.editor_stderr.diagnostics) +
        $(if ($null -ne $recovery) { @($recovery.diagnostics) } else { @() })
    )
}

function Get-McpParentBaselineDiagnosticKeyV1 {
    param(
        [Parameter(Mandatory = $true)][object]$Diagnostic,
        [Parameter(Mandatory = $true)][object]$Environment
    )

    return Get-McpDiagnosticFingerprintV3 -Diagnostic $Diagnostic -Environment $Environment
}

function Get-McpParentBaselineCountMapV1 {
    param(
        [Parameter(Mandatory = $true)][object[]]$Diagnostics,
        [Parameter(Mandatory = $true)][object]$Environment,
        [ValidateSet("all", "reimport", "unicode")][string]$Kind = "all"
    )

    $counts = [ordered]@{}
    foreach ($diagnostic in $Diagnostics) {
        $reimport = [bool](Get-McpDiagnosticObjectValueV2 -Object $diagnostic -Name "reimport_conflict_correlated" -Default $false)
        $unicode = [string](Get-McpDiagnosticObjectValueV2 -Object $diagnostic -Name "category" -Default "") -eq "unicode_nul_diagnostic"
        if ($Kind -eq "reimport" -and -not $reimport) { continue }
        if ($Kind -eq "unicode" -and -not $unicode) { continue }
        $key = Get-McpParentBaselineDiagnosticKeyV1 -Diagnostic $diagnostic -Environment $Environment
        if (-not $counts.Contains($key)) { $counts[$key] = 0 }
        $counts[$key] = [int]$counts[$key] + 1
    }
    return $counts
}

function Test-McpParentBaselineAttemptV1 {
    param(
        [Parameter(Mandatory = $true)][object]$Attempt,
        [Parameter(Mandatory = $true)][string]$ExpectedHead
    )

    return [string]$Attempt.project_head -eq $ExpectedHead `
        -and [bool]$Attempt.project_head_match `
        -and [bool]$Attempt.project_tree_match `
        -and [bool]$Attempt.cache_was_fresh `
        -and [bool]$Attempt.initial_scan_green `
        -and [bool]$Attempt.import_quiescence_green `
        -and [bool]$Attempt.project_reload_green `
        -and [bool]$Attempt.script_discovery_green `
        -and [bool](Get-McpDiagnosticObjectValueV2 -Object $Attempt -Name "stopped_cleanly" -Default $true) `
        -and [int](Get-McpDiagnosticObjectValueV2 -Object $Attempt -Name "editor_exit_code" -Default 0) -eq 0 `
        -and [int](Get-McpDiagnosticObjectValueV2 -Object $Attempt -Name "process_count_after" -Default 0) -eq 0 `
        -and [int](Get-McpDiagnosticObjectValueV2 -Object $Attempt -Name "endpoint_count_after" -Default 0) -eq 0
}

function Test-McpParentBaselineDiagnosticUncorrelatedV1 {
    param(
        [Parameter(Mandatory = $true)][object]$Diagnostic,
        [string[]]$ChangedFiles = @()
    )

    $directPaths = @(Get-McpDirectDiagnosticCorrelationPathsV3 -Diagnostic $Diagnostic)
    $changedPaths = @($directPaths | Where-Object {
        Test-McpPathInChangedFiles -AssociatedPath $_ -ChangedFiles $ChangedFiles
    })
    return $directPaths.Count -eq 0 `
        -and $changedPaths.Count -eq 0 `
        -and [string](Get-McpDiagnosticObjectValueV2 -Object $Diagnostic -Name "associated_resource" -Default "") -eq "" `
        -and -not [bool]$Diagnostic.failed_load_correlated `
        -and -not [bool]$Diagnostic.parse_failure_correlated `
        -and -not [bool]$Diagnostic.runtime_failure_correlated
}

function Test-McpParentBaselineInternalReimportV1 {
    param(
        [Parameter(Mandatory = $true)][object]$Diagnostic,
        [string[]]$ChangedFiles = @()
    )

    return [bool](Get-McpDiagnosticObjectValueV2 -Object $Diagnostic -Name "reimport_conflict_correlated" -Default $false) `
        -and [string](Get-McpDiagnosticObjectValueV2 -Object $Diagnostic -Name "lifecycle_phase" -Default "") -eq "reimport" `
        -and [string](Get-McpDiagnosticObjectValueV2 -Object $Diagnostic -Name "operation_type" -Default "") -eq "reimport" `
        -and [string](Get-McpDiagnosticObjectValueV2 -Object $Diagnostic -Name "operation_id" -Default "") -like "filesystem-initial-scan-*" `
        -and [bool](Get-McpDiagnosticObjectValueV2 -Object $Diagnostic -Name "stage_before_marker" -Default $false) `
        -and (Test-McpParentBaselineDiagnosticUncorrelatedV1 -Diagnostic $Diagnostic -ChangedFiles $ChangedFiles)
}

function New-McpParentBaselineClassificationV1 {
    param(
        [Parameter(Mandatory = $true)][object]$Diagnostic,
        [Parameter(Mandatory = $true)][object]$Environment,
        [Parameter(Mandatory = $true)][string]$CellId,
        [ValidateSet("main", "parent", "target")][string]$ProjectRole,
        [Parameter(Mandatory = $true)][object]$ParentReimportProfile,
        [Parameter(Mandatory = $true)][object]$ParentUnicodeProfile,
        [string[]]$ChangedFiles = @()
    )

    $classification = "unclassified"
    $reason = "diagnostic_not_disposed"
    $directPaths = @(Get-McpDirectDiagnosticCorrelationPathsV3 -Diagnostic $Diagnostic)
    $changedPaths = @($directPaths | Where-Object {
        Test-McpPathInChangedFiles -AssociatedPath $_ -ChangedFiles $ChangedFiles
    })
    $reimport = [bool](Get-McpDiagnosticObjectValueV2 -Object $Diagnostic -Name "reimport_conflict_correlated" -Default $false)
    $unicode = [string](Get-McpDiagnosticObjectValueV2 -Object $Diagnostic -Name "category" -Default "") -eq "unicode_nul_diagnostic"
    $parse = [bool]$Diagnostic.parse_failure_correlated
    $failedLoad = [bool]$Diagnostic.failed_load_correlated
    $runtime = [bool]$Diagnostic.runtime_failure_correlated
    $key = Get-McpParentBaselineDiagnosticKeyV1 -Diagnostic $Diagnostic -Environment $Environment

    if ($ProjectRole -eq "main") {
        $classification = "historical_main_reference_diagnostic"
        $reason = "origin_main_is_reference_only"
    } elseif ($changedPaths.Count -gt 0) {
        $classification = "changed_file_error"
        $reason = "direct_path_matches_target_changed_file"
    } elseif ($runtime) {
        $classification = "runtime_error"
        $reason = "runtime_failure_correlation"
    } elseif ($parse -or $failedLoad) {
        $classification = "real_project_error"
        $reason = if ($parse) { "parse_failure_correlation" } else { "failed_load_correlation" }
    } elseif ($reimport) {
        $safe = Test-McpParentBaselineInternalReimportV1 -Diagnostic $Diagnostic -ChangedFiles $ChangedFiles
        if ($safe -and $ParentReimportProfile.Contains($key)) {
            $classification = "baseline_engine_internal_reimport_progress_collision"
            $reason = "exact_parent_fingerprint_initial_scan_internal_reimport_without_failure_correlation"
        } elseif ($ProjectRole -eq "target" -and -not $ParentReimportProfile.Contains($key)) {
            $classification = "task_introduced_error"
            $reason = "target_reimport_fingerprint_missing_from_direct_parent"
        } else {
            $reason = "reimport_baseline_conditions_not_met"
        }
    } elseif ($unicode) {
        $phase = [string](Get-McpDiagnosticObjectValueV2 -Object $Diagnostic -Name "lifecycle_phase" -Default "")
        $operation = [string](Get-McpDiagnosticObjectValueV2 -Object $Diagnostic -Name "operation_type" -Default "")
        $safe = Test-McpParentBaselineDiagnosticUncorrelatedV1 -Diagnostic $Diagnostic -ChangedFiles $ChangedFiles
        if ($safe `
            -and [int](Get-McpDiagnosticObjectValueV2 -Object $Diagnostic -Name "raw_nul_byte_count" -Default 0) -eq 0 `
            -and $phase -eq "initial_quiescence" `
            -and $operation -eq "initial_scan" `
            -and $ParentUnicodeProfile.Contains($key)) {
            $classification = "baseline_engine_initial_import_unicode_diagnostic"
            $reason = "exact_parent_fingerprint_initial_quiescence_environment_without_failure_correlation"
        } elseif ($phase -ne "initial_quiescence") {
            $reason = "unicode_lifecycle_phase_not_initial_quiescence"
        } elseif (-not $ParentUnicodeProfile.Contains($key)) {
            $classification = if ($ProjectRole -eq "target") { "task_introduced_error" } else { "unclassified" }
            $reason = "unicode_fingerprint_missing_from_direct_parent"
        } else {
            $reason = "unicode_baseline_conditions_not_met"
        }
    } elseif (-not [bool]$Diagnostic.potential_diagnostic) {
        $classification = "informational"
        $reason = "record_is_not_a_diagnostic"
    } elseif ($ProjectRole -eq "target") {
        $classification = "task_introduced_error"
        $reason = "target_diagnostic_missing_from_direct_parent_disposition"
    }

    return [ordered]@{
        schema = "McpParentBaselineDiagnosticClassificationV1"
        occurrence_id = "{0}:{1}:{2}:{3}" -f $CellId, [string]$Diagnostic.source_stream, [int]$Diagnostic.record_index, [int]$Diagnostic.raw_byte_start
        cell_id = $CellId
        project_role = $ProjectRole
        classification = $classification
        reason_code = $reason
        raw_fingerprint = [string]$Diagnostic.raw_bytes_sha256
        diagnostic_fingerprint = $key
        source_stream = [string]$Diagnostic.source_stream
        lifecycle_phase = [string](Get-McpDiagnosticObjectValueV2 -Object $Diagnostic -Name "lifecycle_phase" -Default "unattested")
        operation_type = [string](Get-McpDiagnosticObjectValueV2 -Object $Diagnostic -Name "operation_type" -Default "unattested")
        normalized_operation_type = if ($reimport -and (Test-McpParentBaselineInternalReimportV1 -Diagnostic $Diagnostic -ChangedFiles $ChangedFiles)) { "initial_scan_internal_reimport" } else { [string](Get-McpDiagnosticObjectValueV2 -Object $Diagnostic -Name "operation_type" -Default "unattested") }
        direct_paths = $directPaths
        facets = [ordered]@{
            reimport_conflict = $reimport
            unicode_diagnostic = $unicode
            parse_error = $parse
            failed_load = $failedLoad
            runtime_error = $runtime
            changed_file = $changedPaths.Count -gt 0
        }
    }
}

function Compare-McpParentBaselineDiagnosticDispositionV1 {
    param(
        [Parameter(Mandatory = $true)][object]$Main,
        [Parameter(Mandatory = $true)][object]$ParentA,
        [Parameter(Mandatory = $true)][object]$ParentB,
        [Parameter(Mandatory = $true)][object]$TargetA,
        [Parameter(Mandatory = $true)][object]$TargetB,
        [Parameter(Mandatory = $true)][string]$DirectParentSha,
        [Parameter(Mandatory = $true)][string]$TargetSha,
        [string[]]$ChangedFiles = @(),
        [ValidateRange(0, 2147483647)][int]$ExternalReimportOperationOverlapCount = 0
    )

    $attempts = @($Main, $ParentA, $ParentB, $TargetA, $TargetB)
    $roles = @("main", "parent", "parent", "target", "target")
    $expectedHeads = @([string]$Main.project_head, $DirectParentSha, $DirectParentSha, $TargetSha, $TargetSha)
    for ($index = 0; $index -lt $attempts.Count; $index += 1) {
        if (-not (Test-McpParentBaselineAttemptV1 -Attempt $attempts[$index] -ExpectedHead $expectedHeads[$index])) {
            return [ordered]@{ schema = "McpParentBaselineDiagnosticDispositionV1"; valid = $false; green = $false; reason_code = "attempt_identity_or_lifecycle_invalid" }
        }
    }

    $environmentFingerprints = @($attempts | ForEach-Object {
        "{0}:{1}" -f `
            (Get-McpDiagnosticGodotEnvironmentFingerprintV3 -Environment $_.environment), `
            (Get-McpDiagnosticToolingEnvironmentFingerprintV3 -Environment $_.environment)
    } | Sort-Object -Unique)
    if ($environmentFingerprints.Count -ne 1) {
        return [ordered]@{ schema = "McpParentBaselineDiagnosticDispositionV1"; valid = $false; green = $false; reason_code = "diagnostic_environment_mismatch" }
    }

    $diagnostics = [object[]]::new(5)
    for ($index = 0; $index -lt $attempts.Count; $index += 1) {
        $diagnostics[$index] = @(Get-McpParentBaselineAttemptDiagnosticsV1 -Attempt $attempts[$index])
    }
    $parentReimportA = Get-McpParentBaselineCountMapV1 -Diagnostics @($diagnostics[1]) -Environment $ParentA.environment -Kind reimport
    $parentReimportB = Get-McpParentBaselineCountMapV1 -Diagnostics @($diagnostics[2]) -Environment $ParentB.environment -Kind reimport
    $parentUnicodeA = Get-McpParentBaselineCountMapV1 -Diagnostics @($diagnostics[1]) -Environment $ParentA.environment -Kind unicode
    $parentUnicodeB = Get-McpParentBaselineCountMapV1 -Diagnostics @($diagnostics[2]) -Environment $ParentB.environment -Kind unicode
    $targetReimportA = Get-McpParentBaselineCountMapV1 -Diagnostics @($diagnostics[3]) -Environment $TargetA.environment -Kind reimport
    $targetReimportB = Get-McpParentBaselineCountMapV1 -Diagnostics @($diagnostics[4]) -Environment $TargetB.environment -Kind reimport
    $targetUnicodeA = Get-McpParentBaselineCountMapV1 -Diagnostics @($diagnostics[3]) -Environment $TargetA.environment -Kind unicode
    $targetUnicodeB = Get-McpParentBaselineCountMapV1 -Diagnostics @($diagnostics[4]) -Environment $TargetB.environment -Kind unicode

    $parentReimportProfile = [ordered]@{}
    foreach ($key in @($parentReimportA.Keys + $parentReimportB.Keys | Sort-Object -Unique)) {
        $a = if ($parentReimportA.Contains($key)) { [int]$parentReimportA[$key] } else { 0 }
        $b = if ($parentReimportB.Contains($key)) { [int]$parentReimportB[$key] } else { 0 }
        if ($a -gt 0 -and $b -gt 0) { $parentReimportProfile[$key] = [Math]::Max($a, $b) }
    }
    $parentUnicodeProfile = [ordered]@{}
    foreach ($key in @($parentUnicodeA.Keys + $parentUnicodeB.Keys | Sort-Object -Unique)) {
        $a = if ($parentUnicodeA.Contains($key)) { [int]$parentUnicodeA[$key] } else { 0 }
        $b = if ($parentUnicodeB.Contains($key)) { [int]$parentUnicodeB[$key] } else { 0 }
        if ($a -gt 0 -and $b -gt 0) { $parentUnicodeProfile[$key] = [Math]::Max($a, $b) }
    }

    $newReimportFingerprintCount = @($targetReimportA.Keys + $targetReimportB.Keys | Sort-Object -Unique | Where-Object { -not $parentReimportProfile.Contains($_) }).Count

    $additionalUnicodeFingerprintCount = @($targetUnicodeA.Keys + $targetUnicodeB.Keys | Sort-Object -Unique | Where-Object { -not $parentUnicodeProfile.Contains($_) }).Count
    $parentReimportCounts = @([int]$ParentA.reimport_conflict_count, [int]$ParentB.reimport_conflict_count)
    $targetReimportCounts = @([int]$TargetA.reimport_conflict_count, [int]$TargetB.reimport_conflict_count)
    $parentReimportMaximum = [Math]::Max($parentReimportCounts[0], $parentReimportCounts[1])
    $targetReimportMaximum = [Math]::Max($targetReimportCounts[0], $targetReimportCounts[1])

    $ledger = [System.Collections.Generic.List[object]]::new()
    for ($index = 0; $index -lt $attempts.Count; $index += 1) {
        foreach ($diagnostic in @($diagnostics[$index])) {
            $ledger.Add((New-McpParentBaselineClassificationV1 `
                -Diagnostic $diagnostic `
                -Environment $attempts[$index].environment `
                -CellId ([string]$attempts[$index].cell_id) `
                -ProjectRole $roles[$index] `
                -ParentReimportProfile $parentReimportProfile `
                -ParentUnicodeProfile $parentUnicodeProfile `
                -ChangedFiles $ChangedFiles))
        }
    }

    $classes = @(
        "baseline_engine_internal_reimport_progress_collision",
        "baseline_engine_initial_import_unicode_diagnostic",
        "historical_main_reference_diagnostic",
        "real_project_error",
        "changed_file_error",
        "task_introduced_error",
        "runtime_error",
        "wrapper_artifact",
        "informational",
        "unclassified"
    )
    $counts = [ordered]@{}
    foreach ($name in $classes) { $counts[$name] = 0 }
    $occurrenceIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $duplicates = 0
    foreach ($item in $ledger) {
        $name = [string]$item.classification
        if (-not $counts.Contains($name)) { $name = "unclassified" }
        $counts[$name] = [int]$counts[$name] + 1
        if (-not $occurrenceIds.Add([string]$item.occurrence_id)) { $duplicates += 1 }
    }
    $classifiedTotal = 0
    foreach ($name in $classes) { $classifiedTotal += [int]$counts[$name] }
    $accountingReconciled = $classifiedTotal -eq $ledger.Count -and $duplicates -eq 0
    $targetLedger = @($ledger | Where-Object { [string]$_.project_role -eq "target" })
    $targetRealProjectErrors = @($targetLedger | Where-Object { [string]$_.classification -eq "real_project_error" }).Count
    $targetChangedFileErrors = @($targetLedger | Where-Object { [string]$_.classification -eq "changed_file_error" }).Count
    $targetTaskIntroducedErrors = @($targetLedger | Where-Object { [string]$_.classification -eq "task_introduced_error" }).Count
    $targetRuntimeErrors = @($targetLedger | Where-Object { [string]$_.classification -eq "runtime_error" }).Count
    $targetUnclassified = @($targetLedger | Where-Object { [string]$_.classification -eq "unclassified" }).Count
    $allReimportClassified = @($targetLedger | Where-Object { [bool]$_.facets.reimport_conflict -and [string]$_.classification -ne "baseline_engine_internal_reimport_progress_collision" }).Count -eq 0
    $allUnicodeClassified = @($targetLedger | Where-Object { [bool]$_.facets.unicode_diagnostic -and [string]$_.classification -ne "baseline_engine_initial_import_unicode_diagnostic" }).Count -eq 0

    $green = $accountingReconciled `
        -and $ExternalReimportOperationOverlapCount -eq 0 `
        -and $newReimportFingerprintCount -eq 0 `
        -and $targetReimportMaximum -le $parentReimportMaximum `
        -and $additionalUnicodeFingerprintCount -eq 0 `
        -and $targetRealProjectErrors -eq 0 `
        -and $targetChangedFileErrors -eq 0 `
        -and $targetTaskIntroducedErrors -eq 0 `
        -and $targetRuntimeErrors -eq 0 `
        -and $targetUnclassified -eq 0

    return [ordered]@{
        schema = "McpParentBaselineDiagnosticDispositionV1"
        valid = $true
        green = $green
        reason_code = if ($green) { "none" } elseif ($targetUnclassified -gt 0) { "target_unclassified_diagnostic" } elseif ($targetTaskIntroducedErrors -gt 0) { "target_task_introduced_error" } elseif ($newReimportFingerprintCount -gt 0) { "target_new_reimport_fingerprint" } elseif ($targetReimportMaximum -gt $parentReimportMaximum) { "target_reimport_count_exceeds_parent" } elseif ($additionalUnicodeFingerprintCount -gt 0) { "target_additional_unicode_fingerprint" } elseif ($ExternalReimportOperationOverlapCount -gt 0) { "external_reimport_operation_overlap" } else { "diagnostic_gate_not_green" }
        direct_parent_baseline_sha = $DirectParentSha
        target_sha = $TargetSha
        direct_parent_baseline_used = $true
        main_reference_only = $true
        main_used_as_target_diff_baseline = $false
        parent_baseline_reimport_conflict_counts = $parentReimportCounts
        target_reimport_conflict_counts = $targetReimportCounts
        parent_baseline_reimport_conflict_max_count = $parentReimportMaximum
        target_new_reimport_conflict_fingerprint_count = $newReimportFingerprintCount
        external_reimport_operation_overlap_count = $ExternalReimportOperationOverlapCount
        reimport_diagnostic_final_class = if ($allReimportClassified) { "baseline_engine_internal_reimport_progress_collision" } else { "unclassified" }
        unicode_diagnostic_final_class = if ($allUnicodeClassified) { "baseline_engine_initial_import_unicode_diagnostic" } else { "unclassified" }
        target_additional_unicode_fingerprint_count = $additionalUnicodeFingerprintCount
        total_diagnostic_count = $ledger.Count
        counts = $counts
        diagnostic_accounting_reconciled = $accountingReconciled
        duplicate_diagnostic_classification_count = $duplicates
        target_real_project_error_count = $targetRealProjectErrors
        target_changed_file_error_count = $targetChangedFileErrors
        target_task_introduced_error_count = $targetTaskIntroducedErrors
        target_runtime_error_count = $targetRuntimeErrors
        target_unclassified_diagnostic_count = $targetUnclassified
        exact_sha_attempt_3_authorized = $green
        unicode_baseline_allow_scope = "exact_raw_fingerprint_parent_baseline_phase_environment"
        ledger = $ledger.ToArray()
    }
}
