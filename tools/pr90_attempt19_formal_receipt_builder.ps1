[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$GateManifestPath,
    [Parameter(Mandatory = $true)][string]$SourceGateManifestPath,
    [Parameter(Mandatory = $true)][string]$ManifestParityPath,
    [Parameter(Mandatory = $true)][string]$ReuseAttestationPath,
    [Parameter(Mandatory = $true)][string]$AggregatePath,
    [Parameter(Mandatory = $true)][string]$FrozenEvidenceRoot,
    [Parameter(Mandatory = $true)][string]$ExpectedGateManifestSha256,
    [Parameter(Mandatory = $true)][string]$ExpectedSourceGateManifestSha256,
    [Parameter(Mandatory = $true)][string]$ExpectedManifestParitySha256,
    [Parameter(Mandatory = $true)][string]$ExpectedReuseAttestationSha256,
    [Parameter(Mandatory = $true)][string]$ExpectedAggregateSha256,
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [Parameter(Mandatory = $true)][string]$OutputShaPath,
    [Parameter(Mandatory = $true)][string]$ExpectedHead,
    [Parameter(Mandatory = $true)][string]$ExpectedTree,
    [Parameter(Mandatory = $true)][string]$ToolingWorktree,
    [Parameter(Mandatory = $true)][string]$ToolingHead,
    [Parameter(Mandatory = $true)][string]$ToolingTree
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'pr90_attempt19_authority_contract.psm1') -Force
$toolingRoot = (Resolve-Path -LiteralPath $ToolingWorktree).Path
$actualToolingHead = (& git -C $toolingRoot rev-parse HEAD).Trim()
$actualToolingTree = (& git -C $toolingRoot rev-parse 'HEAD^{tree}').Trim()
if ($LASTEXITCODE -ne 0 -or $actualToolingHead -cne $ToolingHead -or $actualToolingTree -cne $ToolingTree -or
    @(& git -C $toolingRoot status --porcelain=v1).Count -ne 0) { throw 'Receipt builder tooling identity is not committed and clean.' }
$builderRelative = [IO.Path]::GetRelativePath($toolingRoot, $MyInvocation.MyCommand.Path).Replace('\','/')
$modulePath = Join-Path $PSScriptRoot 'pr90_attempt19_authority_contract.psm1'
$moduleRelative = [IO.Path]::GetRelativePath($toolingRoot, $modulePath).Replace('\','/')
foreach ($relative in @($builderRelative,$moduleRelative)) {
    & git -C $toolingRoot ls-files --error-unmatch -- $relative 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Receipt tooling is not tracked: $relative" }
}

$sources = Test-CanonicalGateSources `
    -GateManifestPath $GateManifestPath `
    -SourceGateManifestPath $SourceGateManifestPath `
    -ManifestParityPath $ManifestParityPath `
    -ReuseAttestationPath $ReuseAttestationPath `
    -AggregatePath $AggregatePath `
    -FrozenEvidenceRoot $FrozenEvidenceRoot `
    -ExpectedGateManifestSha256 $ExpectedGateManifestSha256 `
    -ExpectedSourceGateManifestSha256 $ExpectedSourceGateManifestSha256 `
    -ExpectedManifestParitySha256 $ExpectedManifestParitySha256 `
    -ExpectedReuseAttestationSha256 $ExpectedReuseAttestationSha256 `
    -ExpectedAggregateSha256 $ExpectedAggregateSha256 `
    -ExpectedHead $ExpectedHead `
    -ExpectedTree $ExpectedTree

$specById = @{}
foreach ($spec in $sources.gate_manifest.gates) { $specById[[int]$spec.id] = $spec }
$rows = [Collections.Generic.List[object]]::new()
foreach ($verified in $sources.reuse_rows) {
    $src = $verified.source
    $spec = $specById[[int]$src.gate_id]
    $rows.Add([pscustomobject][ordered]@{
        gate_id = [int]$src.gate_id
        script = [string]$spec.script
        status = 'PASS'
        source_kind = 'FROZEN_GATE_1_TO_77_RAW_RESULT_AND_RECEIPT'
        authority_path = [IO.Path]::GetFullPath($ReuseAttestationPath)
        authority_sha256 = Get-Sha256 $ReuseAttestationPath
        raw_result_path = [IO.Path]::GetFullPath($verified.result_path)
        raw_result_sha256 = [string]$src.result_sha256
        receipt_path = [IO.Path]::GetFullPath($verified.receipt_path)
        receipt_sha256 = [string]$src.receipt_sha256
        manifest_marker = [string]$verified.spec.marker
        raw_result_status = [string]$verified.raw.status
        stdout_capture_sha256 = [string]$verified.raw.stdout_capture.sha256
        stderr_capture_sha256 = [string]$verified.raw.stderr_capture.sha256
        eligible = [bool]$src.eligible
        checks = $src.checks
    })
}
foreach ($src in $sources.continuation_rows) {
    $spec = $specById[[int]$src.gate_id]
    $marker = Get-Content -Raw -LiteralPath $src.marker_validation_path | ConvertFrom-Json -Depth 100
    if ([string]$marker.status -cne 'PASS') { throw "Continuation marker for gate $($src.gate_id) is not PASS." }
    $rows.Add([pscustomobject][ordered]@{
        gate_id = [int]$src.gate_id
        script = [string]$spec.script
        status = 'PASS'
        source_kind = 'CANDIDATE_GATE_78_79_RAW_RESULT_AND_AGGREGATE_RECEIPT'
        authority_path = [IO.Path]::GetFullPath($AggregatePath)
        authority_sha256 = Get-Sha256 $AggregatePath
        raw_result_path = [IO.Path]::GetFullPath([string]$src.result_path)
        raw_result_sha256 = [string]$src.result_sha256
        marker_validation_path = [IO.Path]::GetFullPath([string]$src.marker_validation_path)
        marker_validation_sha256 = Get-Sha256 ([string]$src.marker_validation_path)
        manifest_marker = [string]$spec.marker
        aggregate_expected_marker = [string]$src.expected_marker
        receipt_object_sha256 = Get-CanonicalObjectSha256 $src
        receipt_schema = [string]$src.schema
        eligible = $true
    })
}
$rows = @($rows | Sort-Object gate_id)
$ids = @($rows.gate_id)
if ($rows.Count -ne 79 -or @($ids | Sort-Object -Unique).Count -ne 79 -or @(Compare-Object $ids (1..79)).Count -ne 0) {
    throw 'Canonical receipt rows are not exactly unique gates 1..79.'
}
$payload = [pscustomobject][ordered]@{
    schema = 'SpaceSyndicatePr90CanonicalFormalGateReceiptV1'
    receipt_id = 'pr90-770d-canonical-formal-gate-1-79-attempt19-001'
    status = 'PASS'
    created_at_utc = [DateTimeOffset]::UtcNow.ToString('o')
    head_sha = $ExpectedHead
    tree_sha = $ExpectedTree
    tooling_head_sha = $ToolingHead
    tooling_tree_sha = $ToolingTree
    gate_count = 79
    pass_count = 79
    fail_count = 0
    duplicate_gate_count = 0
    missing_gate_count = 0
    gate_manifest_path = [IO.Path]::GetFullPath($GateManifestPath)
    gate_manifest_sha256 = Get-Sha256 $GateManifestPath
    source_gate_manifest_path = [IO.Path]::GetFullPath($SourceGateManifestPath)
    source_gate_manifest_sha256 = Get-Sha256 $SourceGateManifestPath
    gate_manifest_repair_parity_path = [IO.Path]::GetFullPath($ManifestParityPath)
    gate_manifest_repair_parity_sha256 = Get-Sha256 $ManifestParityPath
    reuse_attestation_path = [IO.Path]::GetFullPath($ReuseAttestationPath)
    reuse_attestation_sha256 = Get-Sha256 $ReuseAttestationPath
    candidate_aggregate_path = [IO.Path]::GetFullPath($AggregatePath)
    candidate_aggregate_sha256 = Get-Sha256 $AggregatePath
    gate_78_marker_repair_contract_path = [IO.Path]::GetFullPath([string]$sources.gate_manifest.gate_marker_contract_path)
    gate_78_marker_repair_contract_sha256 = Get-Sha256 ([string]$sources.gate_manifest.gate_marker_contract_path)
    gate_78_marker_repair_authorization_status = [string]$sources.marker_contract.authorization_status
    gate_78_marker_repair_expected_checks = [int]$sources.marker_contract.expected_checks
    frozen_gate_1_77_evidence_root = [IO.Path]::GetFullPath($FrozenEvidenceRoot)
    receipt_builder_path = [IO.Path]::GetFullPath($MyInvocation.MyCommand.Path)
    receipt_builder_sha256 = Get-Sha256 $MyInvocation.MyCommand.Path
    authority_module_path = [IO.Path]::GetFullPath($modulePath)
    authority_module_sha256 = Get-Sha256 $modulePath
    gate_rows = $rows
    canonical_payload_sha256 = ''
}
$payload.canonical_payload_sha256 = Get-CanonicalPayloadSha256 $payload
Write-ImmutableJson -Path $OutputPath -Value $payload
Write-ImmutableSha256Sidecar -Path $OutputShaPath -TargetPath $OutputPath
[pscustomobject][ordered]@{
    status = 'PASS'
    receipt_path = [IO.Path]::GetFullPath($OutputPath)
    receipt_sha256 = Get-Sha256 $OutputPath
    receipt_sha_sidecar = [IO.Path]::GetFullPath($OutputShaPath)
    canonical_payload_sha256 = $payload.canonical_payload_sha256
    gate_count = 79
    pass_count = 79
    fail_count = 0
    duplicate_gate_count = 0
    missing_gate_count = 0
} | ConvertTo-Json -Compress
