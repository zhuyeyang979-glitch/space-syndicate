param(
    [Parameter(Mandatory = $true)][string]$EvidenceRoot,
    [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "role_godot_mcp_diagnostics.ps1")

$root = (Resolve-Path -LiteralPath $EvidenceRoot).Path.TrimEnd("\")
if ($OutputPath -eq "") {
    $OutputPath = Join-Path $root "reclassification_v2.json"
}
$attempts = @()
$rawIntegrity = [System.Collections.Generic.List[object]]::new()
foreach ($cell in @("C0", "C1", "C2")) {
    $attemptPath = Join-Path $root "$cell\attempt.json"
    $attempt = Get-Content -Raw -LiteralPath $attemptPath | ConvertFrom-Json
    $sourcePath = [string]$attempt.editor_stderr.source_path
    $expectedEditorSha = [string]$attempt.editor_stderr.file_sha256
    $expectedEditorLength = [int64]$attempt.editor_stderr.file_length
    $currentEditor = Get-McpRawLogSnapshot `
        -Path $sourcePath `
        -SourceStream editor_stderr `
        -Stage startup_initial_filesystem_scan_before_endpoint_readiness
    $recoverySourcePath = [string]$attempt.recovery_import_stderr.source_path
    $expectedRecoverySha = [string]$attempt.recovery_import_stderr.file_sha256
    $expectedRecoveryLength = [int64]$attempt.recovery_import_stderr.file_length
    $currentRecovery = Get-McpRawLogSnapshot `
        -Path $recoverySourcePath `
        -SourceStream recovery_import_stderr `
        -Stage recovery_cold_import
    foreach ($integrity in @(
        [ordered]@{ stream = "editor_stderr"; expected_sha = $expectedEditorSha; expected_length = $expectedEditorLength; current = $currentEditor },
        [ordered]@{ stream = "recovery_import_stderr"; expected_sha = $expectedRecoverySha; expected_length = $expectedRecoveryLength; current = $currentRecovery }
    )) {
        $match = [string]$integrity.current.file_sha256 -eq [string]$integrity.expected_sha `
            -and [int64]$integrity.current.file_length -eq [int64]$integrity.expected_length
        $rawIntegrity.Add([ordered]@{
            cell = $cell
            stream = [string]$integrity.stream
            expected_sha256 = [string]$integrity.expected_sha
            current_sha256 = [string]$integrity.current.file_sha256
            expected_length = [int64]$integrity.expected_length
            current_length = [int64]$integrity.current.file_length
            match = $match
        })
        if (-not $match) {
            throw "MCP_MATRIX_RAW_LOG_MUTATED|cell=$cell|stream=$($integrity.stream)"
        }
    }
    $attempt.editor_stderr = $currentEditor
    $attempt.recovery_import_stderr = $currentRecovery
    $editorGodotPath = [string]$attempt.godot_log_independent_mirror.source_path
    $editorGodot = Get-McpRawLogSnapshot -Path $editorGodotPath -SourceStream godot_log -Stage editor_lifecycle
    $recoveryGodotPath = Join-Path (Split-Path -Parent $recoverySourcePath) "recovery-import.godot.log"
    $recoveryGodot = Get-McpRawLogSnapshot -Path $recoveryGodotPath -SourceStream recovery_import_godot_log -Stage recovery_cold_import
    $attempt.godot_log_independent_mirror = $editorGodot
    $attempt | Add-Member -NotePropertyName recovery_import_godot_log_independent_mirror -NotePropertyValue $recoveryGodot -Force
    $attempt | Add-Member -NotePropertyName diagnostic_mirror_coverage -NotePropertyValue (Compare-McpDiagnosticMirrorCoverageV2 `
        -AuthoritativeDiagnostics @($currentEditor.diagnostics + $currentRecovery.diagnostics) `
        -MirrorDiagnostics @($editorGodot.diagnostics + $recoveryGodot.diagnostics)) -Force
    $attempts += $attempt
}

$changedScripts = @(
    "scripts/runtime/player_hand_interaction_runtime_service.gd",
    "tests/card_inventory_bench_discardability_migration_test.gd",
    "tests/card_inventory_discardability_typed_query_contract_test.gd"
)
$comparison = Compare-McpColdImportDiagnosticAttemptsV2 `
    -C0 $attempts[0] `
    -C1 $attempts[1] `
    -C2 $attempts[2] `
    -ChangedFiles $changedScripts
$targetDiagnostics = @($attempts[2].editor_stderr.diagnostics + $attempts[2].recovery_import_stderr.diagnostics)
$classifications = @($targetDiagnostics | ForEach-Object {
    Get-McpDiagnosticClassificationV2 `
        -Diagnostic $_ `
        -Environment $attempts[2].environment `
        -BaselineManifest $comparison.baseline_manifest `
        -ChangedFiles $changedScripts `
        -CurrentAttemptIsTarget $true `
        -CurrentProjectHead ([string]$attempts[2].project_head) `
        -CurrentProjectTree ([string]$attempts[2].project_tree)
})
$gate = Get-McpDiagnosticGateV2 `
    -Classifications $classifications `
    -BaselineManifest $comparison.baseline_manifest `
    -Environment $attempts[2].environment `
    -CurrentProjectHead ([string]$attempts[2].project_head) `
    -CurrentProjectTree ([string]$attempts[2].project_tree)
$classifierPath = Join-Path $PSScriptRoot "role_godot_mcp_diagnostics.ps1"
$result = [ordered]@{
    schema = "McpColdImportDiagnosticEvidenceReclassificationV2"
    source_matrix_result = Join-Path $root "result.json"
    real_attempt_count_added = 0
    raw_logs_mutated = @($rawIntegrity | Where-Object { -not [bool]$_.match }).Count -gt 0
    raw_log_integrity = $rawIntegrity.ToArray()
    classifier_source_path = $classifierPath
    classifier_source_sha256 = Get-McpFileSha256Hex -Path $classifierPath
    capture_tooling_runtime_build_sha256 = [string]$attempts[2].environment.tooling_runtime_build_sha256
    c0_raw_record_count = [int]$attempts[0].editor_stderr.record_count
    c1_raw_record_count = [int]$attempts[1].editor_stderr.record_count
    c2_raw_record_count = [int]$attempts[2].editor_stderr.record_count
    c0_recovery_raw_record_count = [int]$attempts[0].recovery_import_stderr.record_count
    c1_recovery_raw_record_count = [int]$attempts[1].recovery_import_stderr.record_count
    c2_recovery_raw_record_count = [int]$attempts[2].recovery_import_stderr.record_count
    c0_diagnostic_event_count = [int]$attempts[0].editor_stderr.diagnostic_count
    c1_diagnostic_event_count = [int]$attempts[1].editor_stderr.diagnostic_count
    c2_diagnostic_event_count = [int]$attempts[2].editor_stderr.diagnostic_count
    c0_recovery_diagnostic_event_count = [int]$attempts[0].recovery_import_stderr.diagnostic_count
    c1_recovery_diagnostic_event_count = [int]$attempts[1].recovery_import_stderr.diagnostic_count
    c2_recovery_diagnostic_event_count = [int]$attempts[2].recovery_import_stderr.diagnostic_count
    c0_total_diagnostic_event_count = [int]$attempts[0].editor_stderr.diagnostic_count + [int]$attempts[0].recovery_import_stderr.diagnostic_count
    c1_total_diagnostic_event_count = [int]$attempts[1].editor_stderr.diagnostic_count + [int]$attempts[1].recovery_import_stderr.diagnostic_count
    c2_total_diagnostic_event_count = [int]$attempts[2].editor_stderr.diagnostic_count + [int]$attempts[2].recovery_import_stderr.diagnostic_count
    comparison = $comparison
    target_classifications = $classifications
    target_gate = $gate
    exact_sha_attempt_3_authorized = [bool]$comparison.green -and [bool]$gate.green
    blocking_reason = if ([int]$comparison.target_additional_diagnostic_count -gt 0) {
        "target_additional_diagnostic_count_nonzero"
    } elseif (-not [bool]$gate.green) {
        "diagnostic_gate_not_green"
    } else {
        "none"
    }
}
$output = [System.IO.Path]::GetFullPath($OutputPath)
[System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($output)) | Out-Null
[System.IO.File]::WriteAllText($output, ($result | ConvertTo-Json -Depth 30), [System.Text.UTF8Encoding]::new($false))
$result | ConvertTo-Json -Depth 30
if ([bool]$result.exact_sha_attempt_3_authorized) {
    exit 0
}
exit 2
