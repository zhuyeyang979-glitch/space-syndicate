param(
    [Parameter(Mandatory = $true)][string]$EvidenceRoot,
    [Parameter(Mandatory = $true)][string]$DirectParentSha,
    [Parameter(Mandatory = $true)][string]$TargetSha,
    [string]$OutputPath = "",
    [ValidateRange(0, 2147483647)][int]$ExternalReimportOperationOverlapCount = 0
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "role_godot_mcp_parent_baseline_diagnostics.ps1")

$root = (Resolve-Path -LiteralPath $EvidenceRoot).Path.TrimEnd("\")
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $root "parent_baseline_disposition_v1.json"
}
$cellIds = @("C0_MAIN_A", "C1_PARENT_A", "C1_PARENT_B", "C2_TARGET_A", "C2_TARGET_B")
$attempts = [ordered]@{}
$sourceIntegrity = [System.Collections.Generic.List[object]]::new()
foreach ($cellId in $cellIds) {
    $path = Join-Path $root "$cellId\attempt.json"
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "MCP_PARENT_BASELINE_ATTEMPT_MISSING|cell=$cellId" }
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $attempts[$cellId] = Get-Content -Raw -LiteralPath $path | ConvertFrom-Json
    $sourceIntegrity.Add([ordered]@{
        cell_id = $cellId
        path = $path
        length = $bytes.Length
        sha256 = Get-McpByteSha256Hex -Bytes $bytes
    })
}

$changedFiles = @(
    "scripts/runtime/player_hand_interaction_runtime_service.gd",
    "tests/card_inventory_bench_discardability_migration_test.gd",
    "tests/card_inventory_discardability_typed_query_contract_test.gd"
)
$disposition = Compare-McpParentBaselineDiagnosticDispositionV1 `
    -Main $attempts.C0_MAIN_A `
    -ParentA $attempts.C1_PARENT_A `
    -ParentB $attempts.C1_PARENT_B `
    -TargetA $attempts.C2_TARGET_A `
    -TargetB $attempts.C2_TARGET_B `
    -DirectParentSha $DirectParentSha `
    -TargetSha $TargetSha `
    -ChangedFiles $changedFiles `
    -ExternalReimportOperationOverlapCount $ExternalReimportOperationOverlapCount

$result = [ordered]@{
    schema = "McpParentBaselineDiagnosticEvidenceDispositionV1"
    source_evidence_root = $root
    new_matrix_attempt_count = 0
    source_attempt_integrity = $sourceIntegrity.ToArray()
    changed_files = $changedFiles
    disposition = $disposition
}
$output = [System.IO.Path]::GetFullPath($OutputPath)
[System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($output)) | Out-Null
[System.IO.File]::WriteAllText($output, ($result | ConvertTo-Json -Depth 40), [System.Text.UTF8Encoding]::new($false))
$result | ConvertTo-Json -Depth 40
if ([bool]$disposition.green) { exit 0 }
exit 2
