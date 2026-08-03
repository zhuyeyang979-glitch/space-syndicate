param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "role_godot_mcp_diagnostics.ps1")

$results = [System.Collections.Generic.List[object]]::new()

function Assert-McpDiagnosticCase {
    param(
        [Parameter(Mandatory = $true)][string]$Category,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][bool]$Condition,
        [string]$Observed = ""
    )

    $results.Add([ordered]@{
        category = $Category
        name = $Name
        passed = $Condition
        observed = $Observed
    })
}

function New-McpTestEnvironment {
    param(
        [string]$GodotVersion = "4.7-stable (official)",
        [string]$ToolingHash = "tooling-a",
        [string]$Locale = "en-GB"
    )

    return [ordered]@{
        godot_executable_sha256 = "godot-exe-a"
        godot_version = $GodotVersion
        tooling_runtime_build_sha256 = $ToolingHash
        mcp_addon_tree = "3ee2dd169db12a2a99bb866d394b9a95ec107e78"
        launch_arguments_sha256 = "launch-template-a"
        locale = $Locale
        ui_locale = "ja-JP"
        powershell_version = "7.6.4"
        powershell_edition = "Core"
        platform = "windows"
        capture_backend = "start_process_win32_inherited_file_handle_v1"
        renderer = "compatibility"
        rendering_method = "gl_compatibility"
        rendering_driver = "opengl3"
        startup_timeout_seconds = 300
        recovery_import_timeout_seconds = 300
        http_timeout_seconds = 3
        initial_ready_stability_seconds = 15
        cache_layout = "fresh_external_ephemeral_mirror_v1"
    }
}

function New-McpTestDiagnostic {
    param(
        [string]$RawHash = "raw-a",
        [string]$MessageHash = "message-a",
        [string]$Text = "Unicode parsing error, some characters were replaced with U+FFFD: Unexpected NUL character",
        [string]$SourceStream = "editor_stderr",
        [string]$Stage = "startup_initial_filesystem_scan_before_endpoint_readiness",
        [string]$AssociatedPath = "",
        [string]$PreviousPath = "",
        [string]$NextPath = "",
        [string]$NearestPreviousCategory = "unicode_nul_diagnostic",
        [string]$NearestNextCategory = "unicode_nul_diagnostic",
        [bool]$PotentialDiagnostic = $true,
        [bool]$Utf8Valid = $true,
        [int]$RawNulCount = 0,
        [bool]$FailedLoad = $false,
        [bool]$ParseFailure = $false,
        [bool]$RuntimeFailure = $false
    )

    return [ordered]@{
        raw_bytes_sha256 = $RawHash
        message_bytes_sha256 = $MessageHash
        line_ending_hex = "0d0a"
        decoded_text_utf8 = $Text
        raw_utf8_valid = $Utf8Valid
        raw_nul_byte_count = $RawNulCount
        source_stream = $SourceStream
        stage = $Stage
        nearest_previous_log_record = $NearestPreviousCategory
        nearest_next_log_record = $NearestNextCategory
        previous_non_diagnostic_event = "renderer_banner"
        next_non_diagnostic_event = "project_path_event"
        associated_path = $AssociatedPath
        nearest_previous_associated_path = $PreviousPath
        nearest_next_associated_path = $NextPath
        failed_load_correlated = $FailedLoad
        parse_failure_correlated = $ParseFailure
        runtime_failure_correlated = $RuntimeFailure
        potential_diagnostic = $PotentialDiagnostic
    }
}

function New-McpTestAttempt {
    param(
        [Parameter(Mandatory = $true)][string]$Cell,
        [Parameter(Mandatory = $true)][string]$Head,
        [Parameter(Mandatory = $true)][object]$Environment,
        [object[]]$Diagnostics = @(),
        [bool]$CacheFresh = $true,
        [bool]$HeadMatch = $true,
        [bool]$Ancestor = $true,
        [bool]$ReloadGreen = $true,
        [bool]$DiscoveryGreen = $true
    )

    return [ordered]@{
        schema = "McpColdImportDiagnosticAttemptV1"
        cell_id = $Cell
        project_head = $Head
        project_tree = ("a" * 40)
        project_tree_match = $true
        project_head_match = $HeadMatch
        source_commit_is_ancestor_of_target = $Ancestor
        cache_was_fresh = $CacheFresh
        project_reload_green = $ReloadGreen
        script_discovery_green = $DiscoveryGreen
        environment = $Environment
        editor_stderr = [ordered]@{ diagnostics = @($Diagnostics) }
        diagnostic_mirror_coverage = [ordered]@{
            schema = "McpDiagnosticMirrorCoverageV2"
            green = $true
            authoritative_diagnostic_count = @($Diagnostics).Count
            mirror_diagnostic_count = @($Diagnostics).Count
            unmirrored_godot_diagnostic_count = 0
        }
    }
}

function Compare-McpTestMatrix {
    param(
        [object[]]$C0Diagnostics,
        [object[]]$C1Diagnostics,
        [object[]]$C2Diagnostics,
        [object]$Environment,
        [object]$C0Environment = $null,
        [object]$C1Environment = $null,
        [object]$C2Environment = $null,
        [object[]]$C0RecoveryDiagnostics = @(),
        [object[]]$C1RecoveryDiagnostics = @(),
        [object[]]$C2RecoveryDiagnostics = @(),
        [bool]$C0Ancestor = $true,
        [bool]$CacheFresh = $true,
        [bool]$HeadMatch = $true,
        [int]$C2UnmirroredGodotDiagnostics = 0
    )

    if ($null -eq $C0Environment) { $C0Environment = $Environment }
    if ($null -eq $C1Environment) { $C1Environment = $Environment }
    if ($null -eq $C2Environment) { $C2Environment = $Environment }
    $c0 = New-McpTestAttempt -Cell C0 -Head ("0" * 40) -Environment $C0Environment -Diagnostics $C0Diagnostics -Ancestor $C0Ancestor -CacheFresh $CacheFresh -HeadMatch $HeadMatch
    $c1 = New-McpTestAttempt -Cell C1 -Head ("1" * 40) -Environment $C1Environment -Diagnostics $C1Diagnostics
    $c2 = New-McpTestAttempt -Cell C2 -Head ("2" * 40) -Environment $C2Environment -Diagnostics $C2Diagnostics
    $c0["recovery_import_stderr"] = [ordered]@{ diagnostics = @($C0RecoveryDiagnostics) }
    $c1["recovery_import_stderr"] = [ordered]@{ diagnostics = @($C1RecoveryDiagnostics) }
    $c2["recovery_import_stderr"] = [ordered]@{ diagnostics = @($C2RecoveryDiagnostics) }
    $c2["diagnostic_mirror_coverage"]["unmirrored_godot_diagnostic_count"] = $C2UnmirroredGodotDiagnostics
    $c2["diagnostic_mirror_coverage"]["green"] = $C2UnmirroredGodotDiagnostics -eq 0
    return Compare-McpColdImportDiagnosticAttemptsV2 -C0 $c0 -C1 $c1 -C2 $c2 -ChangedFiles @("scripts/runtime/player_hand_interaction_runtime_service.gd")
}

$environment = New-McpTestEnvironment
$baselineDiagnostic = New-McpTestDiagnostic
$comparison = Compare-McpTestMatrix -C0Diagnostics @($baselineDiagnostic) -C1Diagnostics @($baselineDiagnostic) -C2Diagnostics @($baselineDiagnostic) -Environment $environment
$manifest = $comparison.baseline_manifest

$emptyGate = Get-McpDiagnosticGateV2 -Classifications @()
Assert-McpDiagnosticCase classification no_diagnostics_green ([bool]$emptyGate.green) ($emptyGate | ConvertTo-Json -Compress)
$baselineClass = Get-McpDiagnosticClassificationV2 -Diagnostic $baselineDiagnostic -Environment $environment -BaselineManifest $manifest
Assert-McpDiagnosticCase classification attested_baseline ([string]$baselineClass.classification -eq "baseline_engine_import_diagnostic") ([string]$baselineClass.classification)
$newDiagnostic = New-McpTestDiagnostic -RawHash "raw-new"
$newClass = Get-McpDiagnosticClassificationV2 -Diagnostic $newDiagnostic -Environment $environment -BaselineManifest $manifest
Assert-McpDiagnosticCase classification target_introduced ([string]$newClass.classification -eq "task_introduced_error") ([string]$newClass.classification)
$parseClass = Get-McpDiagnosticClassificationV2 -Diagnostic (New-McpTestDiagnostic -ParseFailure $true) -Environment $environment -BaselineManifest $manifest
Assert-McpDiagnosticCase classification parse_error ([string]$parseClass.classification -eq "project_script_parse_error") ([string]$parseClass.classification)
$loadClass = Get-McpDiagnosticClassificationV2 -Diagnostic (New-McpTestDiagnostic -FailedLoad $true) -Environment $environment -BaselineManifest $manifest
Assert-McpDiagnosticCase classification resource_load_error ([string]$loadClass.classification -eq "project_resource_load_error") ([string]$loadClass.classification)
$runtimeClass = Get-McpDiagnosticClassificationV2 -Diagnostic (New-McpTestDiagnostic -RuntimeFailure $true) -Environment $environment -BaselineManifest $manifest
Assert-McpDiagnosticCase classification runtime_error ([string]$runtimeClass.classification -eq "project_runtime_error") ([string]$runtimeClass.classification)
$changedClass = Get-McpDiagnosticClassificationV2 -Diagnostic (New-McpTestDiagnostic -AssociatedPath "res://scripts/runtime/player_hand_interaction_runtime_service.gd") -Environment $environment -BaselineManifest $manifest -ChangedFiles @("scripts/runtime/player_hand_interaction_runtime_service.gd")
Assert-McpDiagnosticCase classification changed_file_error ([string]$changedClass.classification -eq "changed_file_error") ([string]$changedClass.classification)
$contextChangedClass = Get-McpDiagnosticClassificationV2 -Diagnostic (New-McpTestDiagnostic -NextPath "res://scripts/runtime/player_hand_interaction_runtime_service.gd") -Environment $environment -BaselineManifest $manifest -ChangedFiles @("scripts/runtime/player_hand_interaction_runtime_service.gd")
Assert-McpDiagnosticCase classification changed_context_error ([string]$contextChangedClass.classification -eq "changed_file_error") ([string]$contextChangedClass.classification)
$wrapperClass = Get-McpDiagnosticClassificationV2 -Diagnostic (New-McpTestDiagnostic -Utf8Valid $false) -Environment $environment -GodotHasCorrespondingDiagnostic $false -WrapperDecodeEvidence $true
Assert-McpDiagnosticCase classification wrapper_artifact_proven ([string]$wrapperClass.classification -eq "wrapper_decode_artifact") ([string]$wrapperClass.classification)
$notWrapperClass = Get-McpDiagnosticClassificationV2 -Diagnostic (New-McpTestDiagnostic -Utf8Valid $false) -Environment $environment -GodotHasCorrespondingDiagnostic $false -WrapperDecodeEvidence $false
Assert-McpDiagnosticCase classification invalid_utf8_without_proof_unclassified ([string]$notWrapperClass.classification -eq "unclassified") ([string]$notWrapperClass.classification)
$invalidNonKeywordClass = Get-McpDiagnosticClassificationV2 -Diagnostic (New-McpTestDiagnostic -Utf8Valid $false -PotentialDiagnostic $false) -Environment $environment -GodotHasCorrespondingDiagnostic $false -WrapperDecodeEvidence $false
Assert-McpDiagnosticCase false_negative_guard invalid_utf8_nonkeyword_fails_closed ([string]$invalidNonKeywordClass.classification -eq "unclassified") ([string]$invalidNonKeywordClass.classification)
$rawNulClass = Get-McpDiagnosticClassificationV2 -Diagnostic (New-McpTestDiagnostic -RawNulCount 1 -PotentialDiagnostic $false) -Environment $environment -BaselineManifest $manifest
Assert-McpDiagnosticCase false_negative_guard raw_nul_nonkeyword_fails_closed ([string]$rawNulClass.classification -eq "unclassified") ([string]$rawNulClass.classification)
$infoClass = Get-McpDiagnosticClassificationV2 -Diagnostic (New-McpTestDiagnostic -PotentialDiagnostic $false) -Environment $environment
Assert-McpDiagnosticCase classification informational ([string]$infoClass.classification -eq "informational") ([string]$infoClass.classification)
$missingClass = Get-McpDiagnosticClassificationV2 -Diagnostic $baselineDiagnostic -Environment $environment
Assert-McpDiagnosticCase classification missing_baseline_unclassified ([string]$missingClass.classification -eq "unclassified") ([string]$missingClass.classification)
$blockingGate = Get-McpDiagnosticGateV2 -Classifications @($newClass)
Assert-McpDiagnosticCase classification task_introduced_gate_blocks (-not [bool]$blockingGate.green) ($blockingGate | ConvertTo-Json -Compress)

Assert-McpDiagnosticCase baseline_fingerprint global_matrix_green ([bool]$comparison.green) ($comparison | ConvertTo-Json -Depth 4 -Compress)
$targetAdded = Compare-McpTestMatrix -C0Diagnostics @($baselineDiagnostic) -C1Diagnostics @($baselineDiagnostic) -C2Diagnostics @($baselineDiagnostic, $newDiagnostic) -Environment $environment
Assert-McpDiagnosticCase baseline_fingerprint target_added_blocked (-not [bool]$targetAdded.green) ([string]$targetAdded.target_additional_diagnostic_count)
$partialManifestValidation = Test-McpBaselineManifestV2 -Manifest $targetAdded.baseline_manifest -Environment $environment -AllowForensicPartial
Assert-McpDiagnosticCase baseline_fingerprint partial_baseline_attestation_valid ([bool]$partialManifestValidation.valid) ([string]$partialManifestValidation.reason_code)
$partialStrictValidation = Test-McpBaselineManifestV2 -Manifest $targetAdded.baseline_manifest -Environment $environment
Assert-McpDiagnosticCase false_negative_guard forensic_partial_manifest_not_acceptance (-not [bool]$partialStrictValidation.valid) ([string]$partialStrictValidation.reason_code)
$partialBaselineClass = Get-McpDiagnosticClassificationV2 -Diagnostic $baselineDiagnostic -Environment $environment -BaselineManifest $targetAdded.baseline_manifest
$partialNewClass = Get-McpDiagnosticClassificationV2 -Diagnostic $newDiagnostic -Environment $environment -BaselineManifest $targetAdded.baseline_manifest
$partialGate = Get-McpDiagnosticGateV2 -Classifications @($partialBaselineClass, $partialNewClass)
Assert-McpDiagnosticCase false_negative_guard partial_manifest_blocks_target_addition (
    [string]$partialBaselineClass.classification -eq "baseline_engine_import_diagnostic" `
        -and [string]$partialNewClass.classification -eq "task_introduced_error" `
        -and -not [bool]$partialGate.green
) ($partialGate | ConvertTo-Json -Compress)
$acceptanceGate = Get-McpDiagnosticGateV2 `
    -Classifications @($baselineClass) `
    -BaselineManifest $manifest `
    -Environment $environment `
    -CurrentProjectHead ("2" * 40) `
    -CurrentProjectTree ("a" * 40)
Assert-McpDiagnosticCase baseline_fingerprint exact_multiplicity_gate_green ([bool]$acceptanceGate.green) ($acceptanceGate | ConvertTo-Json -Compress)
$duplicateBaselineGate = Get-McpDiagnosticGateV2 `
    -Classifications @($baselineClass, $baselineClass) `
    -BaselineManifest $manifest `
    -Environment $environment `
    -CurrentProjectHead ("2" * 40) `
    -CurrentProjectTree ("a" * 40)
Assert-McpDiagnosticCase false_negative_guard duplicate_baseline_multiplicity_blocks (
    -not [bool]$duplicateBaselineGate.green -and [int]$duplicateBaselineGate.baseline_multiplicity_mismatch_count -eq 1
) ($duplicateBaselineGate | ConvertTo-Json -Compress)
$targetCount = Compare-McpTestMatrix -C0Diagnostics @($baselineDiagnostic) -C1Diagnostics @($baselineDiagnostic) -C2Diagnostics @($baselineDiagnostic, $baselineDiagnostic) -Environment $environment
Assert-McpDiagnosticCase baseline_fingerprint target_count_increase_blocked (-not [bool]$targetCount.green) ([string]$targetCount.target_additional_diagnostic_count)
$rawDifferent = Compare-McpTestMatrix -C0Diagnostics @($baselineDiagnostic) -C1Diagnostics @($baselineDiagnostic) -C2Diagnostics @((New-McpTestDiagnostic -RawHash "raw-b")) -Environment $environment
Assert-McpDiagnosticCase baseline_fingerprint same_message_raw_diff_blocked (-not [bool]$rawDifferent.green) ([string]$rawDifferent.target_additional_diagnostic_count)
$pathDifferent = Compare-McpTestMatrix -C0Diagnostics @($baselineDiagnostic) -C1Diagnostics @($baselineDiagnostic) -C2Diagnostics @((New-McpTestDiagnostic -AssociatedPath "res://other.gd")) -Environment $environment
Assert-McpDiagnosticCase baseline_fingerprint raw_same_path_diff_blocked (-not [bool]$pathDifferent.green) ([string]$pathDifferent.target_additional_diagnostic_count)
$sourceDifferent = Compare-McpTestMatrix -C0Diagnostics @($baselineDiagnostic) -C1Diagnostics @($baselineDiagnostic) -C2Diagnostics @((New-McpTestDiagnostic -SourceStream "recovery_import_stderr")) -Environment $environment
Assert-McpDiagnosticCase baseline_fingerprint source_stream_diff_blocked (-not [bool]$sourceDifferent.green) ([string]$sourceDifferent.target_additional_diagnostic_count)
$stageDifferent = Compare-McpTestMatrix -C0Diagnostics @($baselineDiagnostic) -C1Diagnostics @($baselineDiagnostic) -C2Diagnostics @((New-McpTestDiagnostic -Stage "runtime")) -Environment $environment
Assert-McpDiagnosticCase baseline_fingerprint stage_diff_blocked (-not [bool]$stageDifferent.green) ([string]$stageDifferent.target_additional_diagnostic_count)
$toolingEnvironment = New-McpTestEnvironment -ToolingHash "tooling-b"
$toolingMismatch = Compare-McpTestMatrix -C0Diagnostics @($baselineDiagnostic) -C1Diagnostics @($baselineDiagnostic) -C2Diagnostics @($baselineDiagnostic) -Environment $environment -C2Environment $toolingEnvironment
Assert-McpDiagnosticCase baseline_fingerprint tooling_change_blocked (-not [bool]$toolingMismatch.valid -and [string]$toolingMismatch.reason_code -eq "diagnostic_environment_mismatch") ([string]$toolingMismatch.reason_code)
$versionEnvironment = New-McpTestEnvironment -GodotVersion "4.8"
$versionMismatch = Compare-McpTestMatrix -C0Diagnostics @($baselineDiagnostic) -C1Diagnostics @($baselineDiagnostic) -C2Diagnostics @($baselineDiagnostic) -Environment $environment -C1Environment $versionEnvironment
Assert-McpDiagnosticCase baseline_fingerprint godot_version_change_blocked (-not [bool]$versionMismatch.valid) ([string]$versionMismatch.reason_code)
$localeEnvironment = New-McpTestEnvironment -Locale "zh-CN"
$localeMismatch = Compare-McpTestMatrix -C0Diagnostics @($baselineDiagnostic) -C1Diagnostics @($baselineDiagnostic) -C2Diagnostics @($baselineDiagnostic) -Environment $environment -C0Environment $localeEnvironment
Assert-McpDiagnosticCase baseline_fingerprint locale_change_blocked (-not [bool]$localeMismatch.valid) ([string]$localeMismatch.reason_code)
$corruptManifest = $manifest | ConvertTo-Json -Depth 10 | ConvertFrom-Json
$corruptManifest.target_head = "tampered"
$corruptValidation = Test-McpBaselineManifestV2 -Manifest $corruptManifest -Environment $environment
Assert-McpDiagnosticCase baseline_fingerprint corrupt_manifest_blocked (-not [bool]$corruptValidation.valid -and [string]$corruptValidation.reason_code -eq "baseline_fingerprint_file_corrupt") ([string]$corruptValidation.reason_code)
$roundtripManifest = $manifest | ConvertTo-Json -Depth 10 | ConvertFrom-Json
$roundtripValidation = Test-McpBaselineManifestV2 -Manifest $roundtripManifest -Environment $environment -ExpectedTargetHead ("2" * 40) -ExpectedTargetTree ("a" * 40)
Assert-McpDiagnosticCase baseline_fingerprint valid_manifest_json_roundtrip ([bool]$roundtripValidation.valid -and [bool]$roundtripValidation.acceptance_valid) ([string]$roundtripValidation.reason_code)
$targetTreeBinding = Test-McpBaselineManifestV2 -Manifest $roundtripManifest -Environment $environment -ExpectedTargetHead ("2" * 40) -ExpectedTargetTree ("b" * 40)
Assert-McpDiagnosticCase false_negative_guard manifest_target_tree_binding_enforced (-not [bool]$targetTreeBinding.valid -and [string]$targetTreeBinding.reason_code -eq "baseline_target_tree_mismatch") ([string]$targetTreeBinding.reason_code)
$missingValidation = Test-McpBaselineManifestV2 -Manifest $null -Environment $environment
Assert-McpDiagnosticCase baseline_fingerprint missing_manifest_blocked (-not [bool]$missingValidation.valid -and [string]$missingValidation.reason_code -eq "baseline_fingerprint_missing") ([string]$missingValidation.reason_code)
$nonAncestor = Compare-McpTestMatrix -C0Diagnostics @($baselineDiagnostic) -C1Diagnostics @($baselineDiagnostic) -C2Diagnostics @($baselineDiagnostic) -Environment $environment -C0Ancestor $false
Assert-McpDiagnosticCase baseline_fingerprint non_ancestor_blocked (-not [bool]$nonAncestor.valid -and [string]$nonAncestor.reason_code -eq "baseline_commit_not_ancestor") ([string]$nonAncestor.reason_code)
$reusedCache = Compare-McpTestMatrix -C0Diagnostics @($baselineDiagnostic) -C1Diagnostics @($baselineDiagnostic) -C2Diagnostics @($baselineDiagnostic) -Environment $environment -CacheFresh $false
Assert-McpDiagnosticCase baseline_fingerprint cache_reuse_blocked (-not [bool]$reusedCache.valid -and [string]$reusedCache.reason_code -eq "cache_reused_attempt") ([string]$reusedCache.reason_code)
$headMismatch = Compare-McpTestMatrix -C0Diagnostics @($baselineDiagnostic) -C1Diagnostics @($baselineDiagnostic) -C2Diagnostics @($baselineDiagnostic) -Environment $environment -HeadMatch $false
Assert-McpDiagnosticCase baseline_fingerprint project_head_mismatch_blocked (-not [bool]$headMismatch.valid -and [string]$headMismatch.reason_code -eq "project_head_mismatch") ([string]$headMismatch.reason_code)
$parentOnly = Compare-McpTestMatrix -C0Diagnostics @() -C1Diagnostics @($baselineDiagnostic) -C2Diagnostics @($baselineDiagnostic) -Environment $environment
Assert-McpDiagnosticCase baseline_fingerprint parent_chain_baseline_attested ([bool]$parentOnly.green -and [string]$parentOnly.baseline_manifest.baseline_scope -eq "parent_chain_only") ([string]$parentOnly.baseline_manifest.baseline_scope)
$unstableCounts = Compare-McpTestMatrix -C0Diagnostics @($baselineDiagnostic) -C1Diagnostics @($baselineDiagnostic, $baselineDiagnostic) -C2Diagnostics @($baselineDiagnostic) -Environment $environment
Assert-McpDiagnosticCase baseline_fingerprint unstable_cross_commit_count_blocked (-not [bool]$unstableCounts.green) ([string]$unstableCounts.target_additional_diagnostic_count)
$recoveryParse = New-McpTestDiagnostic -SourceStream "recovery_import_stderr" -Stage "recovery_cold_import" -ParseFailure $true
$recoveryOnlyError = Compare-McpTestMatrix -C0Diagnostics @() -C1Diagnostics @() -C2Diagnostics @() -C0RecoveryDiagnostics @() -C1RecoveryDiagnostics @() -C2RecoveryDiagnostics @($recoveryParse) -Environment $environment
Assert-McpDiagnosticCase false_negative_guard recovery_only_parse_error_blocks (-not [bool]$recoveryOnlyError.green -and [int]$recoveryOnlyError.matrix_real_project_error_count -eq 1) ($recoveryOnlyError | ConvertTo-Json -Depth 5 -Compress)
$unmirroredGodot = Compare-McpTestMatrix -C0Diagnostics @() -C1Diagnostics @() -C2Diagnostics @() -Environment $environment -C2UnmirroredGodotDiagnostics 1
Assert-McpDiagnosticCase false_negative_guard unmirrored_godot_diagnostic_blocks (-not [bool]$unmirroredGodot.green -and [int]$unmirroredGodot.matrix_unmirrored_godot_diagnostic_count -eq 1) ($unmirroredGodot | ConvertTo-Json -Depth 5 -Compress)

Assert-McpDiagnosticCase changed_file_correlation direct_res_path (Test-McpPathInChangedFiles -AssociatedPath "res://scripts/runtime/player_hand_interaction_runtime_service.gd" -ChangedFiles @("scripts/runtime/player_hand_interaction_runtime_service.gd"))
Assert-McpDiagnosticCase changed_file_correlation windows_separator_normalized (Test-McpPathInChangedFiles -AssociatedPath "res://scripts\runtime\player_hand_interaction_runtime_service.gd" -ChangedFiles @("scripts/runtime/player_hand_interaction_runtime_service.gd"))
Assert-McpDiagnosticCase changed_file_correlation unrelated_path_rejected (-not (Test-McpPathInChangedFiles -AssociatedPath "res://scripts/runtime/other.gd" -ChangedFiles @("scripts/runtime/player_hand_interaction_runtime_service.gd")))
Assert-McpDiagnosticCase changed_file_correlation empty_path_rejected (-not (Test-McpPathInChangedFiles -AssociatedPath "" -ChangedFiles @("scripts/runtime/player_hand_interaction_runtime_service.gd")))
Assert-McpDiagnosticCase changed_file_correlation nearest_import_changed_detected ([bool]$contextChangedClass.changed_file_correlated) ($contextChangedClass | ConvertTo-Json -Compress)
Assert-McpDiagnosticCase changed_file_correlation quoted_line_path_normalized (Test-McpPathInChangedFiles -AssociatedPath 'res://scripts/runtime/player_hand_interaction_runtime_service.gd":42' -ChangedFiles @("scripts/runtime/player_hand_interaction_runtime_service.gd"))
Assert-McpDiagnosticCase changed_file_correlation absolute_mirror_path_normalized (Test-McpPathInChangedFiles -AssociatedPath 'E:\ss-mcp\cu2\m\c2\scripts\runtime\player_hand_interaction_runtime_service.gd:42' -ChangedFiles @("scripts/runtime/player_hand_interaction_runtime_service.gd"))

$neighborPathDiagnostic = New-McpTestDiagnostic -NextPath "res://scripts/runtime/unrelated.gd"
$neighborPathComparison = Compare-McpTestMatrix -C0Diagnostics @($baselineDiagnostic) -C1Diagnostics @($baselineDiagnostic) -C2Diagnostics @($neighborPathDiagnostic) -Environment $environment
Assert-McpDiagnosticCase false_negative_guard neighboring_project_path_blocks_baseline (-not [bool]$neighborPathComparison.green -and [int]$neighborPathComparison.target_non_equivalent_diagnostic_count -eq 1) ($neighborPathComparison | ConvertTo-Json -Depth 5 -Compress)
$neighborPathClass = Get-McpDiagnosticClassificationV2 -Diagnostic $neighborPathDiagnostic -Environment $environment -BaselineManifest $neighborPathComparison.baseline_manifest
Assert-McpDiagnosticCase false_negative_guard neighboring_project_path_not_baseline ([string]$neighborPathClass.classification -ne "baseline_engine_import_diagnostic") ([string]$neighborPathClass.classification)
$immediateCategoryDiagnostic = New-McpTestDiagnostic -NearestNextCategory "engine_editor_error"
$immediateCategoryComparison = Compare-McpTestMatrix -C0Diagnostics @($baselineDiagnostic) -C1Diagnostics @($baselineDiagnostic) -C2Diagnostics @($immediateCategoryDiagnostic) -Environment $environment
Assert-McpDiagnosticCase false_negative_guard immediate_neighbor_category_in_fingerprint (-not [bool]$immediateCategoryComparison.green -and [int]$immediateCategoryComparison.target_non_equivalent_diagnostic_count -eq 1) ($immediateCategoryComparison | ConvertTo-Json -Depth 5 -Compress)

$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("mcp-diagnostic-test-" + [guid]::NewGuid().ToString("N"))
[System.IO.Directory]::CreateDirectory($temporaryRoot) | Out-Null
try {
    $literalPath = Join-Path $temporaryRoot "literal.stderr.log"
    $literal = "Unicode parsing error, some characters were replaced with $([char]0xfffd) (U+FFFD): Unexpected NUL character`r`n"
    [System.IO.File]::WriteAllBytes($literalPath, [System.Text.UTF8Encoding]::new($false).GetBytes($literal))
    $literalSnapshot = Get-McpRawLogSnapshot -Path $literalPath -SourceStream editor_stderr -Stage startup
    Assert-McpDiagnosticCase false_negative_guard literal_replacement_not_decoder_artifact ([bool]$literalSnapshot.records[0].raw_utf8_valid -and [int]$literalSnapshot.records[0].literal_replacement_codepoint_count -eq 1 -and [int]$literalSnapshot.records[0].decoder_inserted_replacement_count -eq 0) ($literalSnapshot.records[0] | ConvertTo-Json -Compress)
    Assert-McpDiagnosticCase false_negative_guard crlf_framed_hash_preserved ([string]$literalSnapshot.records[0].raw_bytes_sha256 -ne [string]$literalSnapshot.records[0].message_bytes_sha256) ($literalSnapshot.records[0] | ConvertTo-Json -Compress)

    $nulPath = Join-Path $temporaryRoot "nul.stderr.log"
    [System.IO.File]::WriteAllBytes($nulPath, [byte[]](65, 0, 66, 13, 10))
    $nulSnapshot = Get-McpRawLogSnapshot -Path $nulPath -SourceStream editor_stderr -Stage startup
    Assert-McpDiagnosticCase false_negative_guard raw_nul_does_not_crash ([int]$nulSnapshot.raw_nul_count -eq 1 -and [int]$nulSnapshot.records[0].raw_nul_byte_count -eq 1) ($nulSnapshot | ConvertTo-Json -Depth 4 -Compress)

    $invalidPath = Join-Path $temporaryRoot "invalid.stderr.log"
    [System.IO.File]::WriteAllBytes($invalidPath, [byte[]](0x66, 0x80, 0x0a))
    $invalidSnapshot = Get-McpRawLogSnapshot -Path $invalidPath -SourceStream editor_stderr -Stage startup
    Assert-McpDiagnosticCase false_negative_guard invalid_utf8_detected (-not [bool]$invalidSnapshot.records[0].raw_utf8_valid -and [int]$invalidSnapshot.records[0].decoder_inserted_replacement_count -gt 0) ($invalidSnapshot.records[0] | ConvertTo-Json -Compress)

    $emptyPath = Join-Path $temporaryRoot "empty.stderr.log"
    [System.IO.File]::WriteAllBytes($emptyPath, [byte[]]::new(0))
    $emptySnapshot = Get-McpRawLogSnapshot -Path $emptyPath -SourceStream editor_stderr -Stage startup
    Assert-McpDiagnosticCase false_negative_guard empty_log_has_valid_sha_and_zero_records (
        [string]$emptySnapshot.file_sha256 -eq "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" `
            -and [int]$emptySnapshot.record_count -eq 0 `
            -and [int]$emptySnapshot.diagnostic_count -eq 0
    ) ($emptySnapshot | ConvertTo-Json -Compress)

    $pathContextPath = Join-Path $temporaryRoot "path-context.godot.log"
    $pathContextText = "res://scripts/runtime/player_hand_interaction_runtime_service.gd: import`r`nordinary event`r`n$literal"
    [System.IO.File]::WriteAllBytes($pathContextPath, [System.Text.UTF8Encoding]::new($false).GetBytes($pathContextText))
    $pathContextSnapshot = Get-McpRawLogSnapshot -Path $pathContextPath -SourceStream godot_log -Stage startup
    $pathContextDiagnostic = @($pathContextSnapshot.diagnostics | Where-Object { [string]$_.category -eq "unicode_nul_diagnostic" })[0]
    Assert-McpDiagnosticCase changed_file_correlation path_scan_skips_intermediate_pathless_event (
        Test-McpPathInChangedFiles -AssociatedPath ([string]$pathContextDiagnostic.nearest_previous_associated_path) -ChangedFiles @("scripts/runtime/player_hand_interaction_runtime_service.gd")
    ) ([string]$pathContextDiagnostic.nearest_previous_associated_path)
} finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}

$diagnosticSource = [System.IO.File]::ReadAllText((Join-Path $PSScriptRoot "role_godot_mcp_diagnostics.ps1"))
Assert-McpDiagnosticCase false_negative_guard no_global_unicode_message_allowlist (-not [regex]::IsMatch($diagnosticSource, '(?i)contains\([^\r\n]*Unicode parsing error'))
Assert-McpDiagnosticCase false_negative_guard no_hardcoded_allowed_error_count (-not [regex]::IsMatch($diagnosticSource, '(?i)allowed_error_count\s*=\s*6'))
$unknownGate = Get-McpDiagnosticGateV2 -Classifications @([ordered]@{ classification = "future_unknown_category" })
Assert-McpDiagnosticCase false_negative_guard unknown_category_fails_closed (-not [bool]$unknownGate.green -and [int]$unknownGate.unclassified_diagnostic_count -eq 1) ($unknownGate | ConvertTo-Json -Compress)
$failedLoadGate = Get-McpDiagnosticGateV2 -Classifications @($loadClass)
Assert-McpDiagnosticCase false_negative_guard failed_load_gate_blocks (-not [bool]$failedLoadGate.green) ($failedLoadGate | ConvertTo-Json -Compress)
$runtimeGate = Get-McpDiagnosticGateV2 -Classifications @($runtimeClass)
Assert-McpDiagnosticCase false_negative_guard runtime_gate_blocks (-not [bool]$runtimeGate.green) ($runtimeGate | ConvertTo-Json -Compress)
$corruptClass = Get-McpDiagnosticClassificationV2 -Diagnostic $baselineDiagnostic -Environment $environment -BaselineManifest $corruptManifest
Assert-McpDiagnosticCase false_negative_guard corrupt_manifest_cannot_allow ([string]$corruptClass.classification -eq "unclassified") ([string]$corruptClass.classification)

$categories = [ordered]@{}
foreach ($category in @("classification", "baseline_fingerprint", "changed_file_correlation", "false_negative_guard")) {
    $cases = @($results | Where-Object { [string]$_.category -eq $category })
    $categories[$category] = [ordered]@{
        passed = @($cases | Where-Object { [bool]$_.passed }).Count
        total = $cases.Count
    }
}
$failures = @($results | Where-Object { -not [bool]$_.passed })
$falseAcceptCount = @($failures | Where-Object {
    [string]$_.category -in @("baseline_fingerprint", "changed_file_correlation", "false_negative_guard")
}).Count
$falseRejectCount = @($failures | Where-Object { [string]$_.category -eq "classification" }).Count
$summary = [ordered]@{
    schema = "McpDiagnosticClassificationOfflineTestResultV2"
    green = $failures.Count -eq 0
    total_passed = @($results | Where-Object { [bool]$_.passed }).Count
    total = $results.Count
    false_accept_count = $falseAcceptCount
    false_reject_count = $falseRejectCount
    categories = $categories
    failures = $failures
    cases = $results.ToArray()
}
$summary | ConvertTo-Json -Depth 12
if ($failures.Count -gt 0) {
    exit 1
}
