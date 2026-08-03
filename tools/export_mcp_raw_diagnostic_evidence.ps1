param(
    [Parameter(Mandatory = $true)][string]$AttemptId,
    [Parameter(Mandatory = $true)][string]$ControlEvidenceRoot,
    [Parameter(Mandatory = $true)][string]$OutputPath
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "role_godot_mcp_diagnostics.ps1")

$root = (Resolve-Path -LiteralPath $ControlEvidenceRoot).Path.TrimEnd("\")
$logs = Join-Path $root "logs"
$connectionPath = Join-Path $root "connection.json"
$connection = if (Test-Path -LiteralPath $connectionPath -PathType Leaf) {
    Get-Content -Raw -LiteralPath $connectionPath | ConvertFrom-Json
} else {
    $null
}

$editor = Get-McpRawLogSnapshot `
    -Path (Join-Path $logs "editor.stderr.log") `
    -SourceStream editor_stderr `
    -Stage startup_initial_filesystem_scan_before_endpoint_readiness
$recovery = Get-McpRawLogSnapshot `
    -Path (Join-Path $logs "recovery-import.stderr.log") `
    -SourceStream recovery_import_stderr `
    -Stage recovery_cold_import
$godot = Get-McpRawLogSnapshot `
    -Path (Join-Path $logs "godot.log") `
    -SourceStream godot_log `
    -Stage editor_lifecycle
$recoveryGodot = Get-McpRawLogSnapshot `
    -Path (Join-Path $logs "recovery-import.godot.log") `
    -SourceStream recovery_import_godot_log `
    -Stage recovery_cold_import

$editorUnicode = @($editor.diagnostics | Where-Object { [string]$_.category -eq "unicode_nul_diagnostic" })
$recoveryUnicode = @($recovery.diagnostics | Where-Object { [string]$_.category -eq "unicode_nul_diagnostic" })
$godotUnicode = @($godot.diagnostics | Where-Object { [string]$_.category -eq "unicode_nul_diagnostic" })
$editorMessageHashes = @($editorUnicode | ForEach-Object { [string]$_.message_bytes_sha256 })
$godotMessageHashes = @($godotUnicode | ForEach-Object { [string]$_.message_bytes_sha256 })
$strictUtf8 = @($editorUnicode | Where-Object { -not [bool]$_.raw_utf8_valid }).Count -eq 0
$decoderInserted = 0
foreach ($diagnostic in $editorUnicode) {
    $decoderInserted += [int]$diagnostic.decoder_inserted_replacement_count
}
$failedLoadCount = @($editor.records | Where-Object { [bool]$_.failed_load_correlated }).Count
$parseFailureCount = @($editor.records | Where-Object { [bool]$_.parse_failure_correlated }).Count
$runtimeFailureCount = @($editor.records | Where-Object { [bool]$_.runtime_failure_correlated }).Count
$wrapperArtifactProven = (-not $strictUtf8) -and $decoderInserted -gt 0 -and $godotUnicode.Count -eq 0
$independentGodotMirrorMatches = $editorMessageHashes.Count -eq $godotMessageHashes.Count `
    -and (@(Compare-Object -ReferenceObject $editorMessageHashes -DifferenceObject $godotMessageHashes).Count -eq 0)

$report = [ordered]@{
    schema = "McpRawDiagnosticAttributionReportV2"
    task_id = "ALPHA_0_4_C_MCP_COLD_IMPORT_UNICODE_NUL_BASELINE_ATTRIBUTION_GATE_REPAIR_AND_EXACT_SHA_ACCEPTANCE"
    attempt_id = $AttemptId
    source_evidence_root = $root
    source_evidence_mutated = $false
    connection = $connection
    editor_stderr = $editor
    recovery_import_stderr = $recovery
    godot_log_independent_mirror = $godot
    recovery_import_godot_log_independent_mirror = $recoveryGodot
    attempt_unicode_diagnostic_raw_count = $editorUnicode.Count
    raw_stderr_nul_count = [int]$editor.raw_nul_count
    stderr_strict_utf8 = $strictUtf8
    stderr_decoder_inserted_replacement_count = [int]$decoderInserted
    godot_internal_input_nul_diagnostic = $editorUnicode.Count -gt 0 -and [int]$editor.raw_nul_count -eq 0
    wrapper_decode_artifact_proven = $wrapperArtifactProven
    independent_godot_log_message_multiset_matches = $independentGodotMirrorMatches
    editor_framed_raw_fingerprints = @($editorUnicode | ForEach-Object { [string]$_.raw_bytes_sha256 })
    editor_message_raw_fingerprints = $editorMessageHashes
    recovery_unicode_diagnostic_count = $recoveryUnicode.Count
    failed_load_correlated_count = $failedLoadCount
    parse_failure_correlated_count = $parseFailureCount
    runtime_failure_correlated_count = $runtimeFailureCount
    historical_classification = "unclassified"
    historical_result = "BLOCKED_BY_UNCLASSIFIED_COLD_IMPORT_DIAGNOSTICS_AT_TIME_OF_RUN"
    attempt_result_rewritten = $false
}

$output = [System.IO.Path]::GetFullPath($OutputPath)
[System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($output)) | Out-Null
[System.IO.File]::WriteAllText($output, ($report | ConvertTo-Json -Depth 30), [System.Text.UTF8Encoding]::new($false))
$report | ConvertTo-Json -Depth 30
