[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ManifestPath,
    [Parameter(Mandatory = $true)][string]$ManifestShaPath,
    [Parameter(Mandatory = $true)][string]$PreFormalDryRunPath,
    [Parameter(Mandatory = $true)][string]$ClassCacheReviewPath,
    [Parameter(Mandatory = $true)][string]$FormalReceiptReviewPath,
    [Parameter(Mandatory = $true)][string]$AuthorizationReviewPath,
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [Parameter(Mandatory = $true)][string]$OutputShaPath,
    [Parameter(Mandatory = $true)][string]$OutputMarkdownPath
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'pr90_attempt19_authority_contract.psm1') -Force
$manifest = Get-Content -Raw -LiteralPath $ManifestPath | ConvertFrom-Json -Depth 100
$sidecar = Read-Sha256Sidecar $ManifestShaPath
if ([string]$sidecar.sha256 -cne (Get-Sha256 $ManifestPath)) { throw 'Manifest SHA sidecar mismatch.' }
$dryRun = Get-Content -Raw -LiteralPath $PreFormalDryRunPath | ConvertFrom-Json -Depth 100
if ([string]$dryRun.status -cne 'PASS' -or [bool]$dryRun.formal_mcp_started -or [bool]$dryRun.authorization_consumed -or
    [int]$dryRun.product_process_count -ne 0 -or [int]$dryRun.authorization_field_mismatch_count -ne 0 -or
    [int]$dryRun.authorization_declared_field_count -ne [int]$dryRun.authorization_validated_field_count) {
    throw 'Pre-formal authorization dry-run is not sealable.'
}
function Read-ReviewReceipt([string]$Path,[string]$ExpectedLane,[string[]]$RequiredRoles) {
    $review = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth 100
    if ([string]$review.schema -cne 'SpaceSyndicateIndependentReviewReceiptV1' -or [string]$review.lane -cne $ExpectedLane -or
        [string]$review.status -cne 'GO' -or [int]$review.p0_count -ne 0 -or [int]$review.p1_count -ne 0 -or
        [string]$review.product_head_sha -cne [string]$manifest.product_head_sha -or [string]$review.product_tree_sha -cne [string]$manifest.product_tree_sha -or
        [string]$review.tooling_head_sha -cne [string]$manifest.import_tooling_head_sha -or [string]$review.tooling_tree_sha -cne [string]$manifest.import_tooling_tree_sha -or
        [int]$review.formal_mcp_count -ne 0) { throw "Independent Review $ExpectedLane is not a sealable GO receipt." }
    $roles = @($review.reviewed_evidence.role)
    foreach ($role in $RequiredRoles) { if ($roles -cnotcontains $role) { throw "Independent Review $ExpectedLane omitted evidence role: $role" } }
    foreach ($row in @($review.reviewed_evidence)) {
        Assert-ExactSha256 ([string]$row.path) ([string]$row.sha256) | Out-Null
    }
    if ([string]$review.canonical_payload_sha256 -cne (Get-CanonicalPayloadSha256 $review)) { throw "Independent Review $ExpectedLane canonical payload mismatch." }
    return $review
}
$reviewA = Read-ReviewReceipt -Path $ClassCacheReviewPath -ExpectedLane 'A_CLASS_CACHE_AND_BASELINE' -RequiredRoles @('class_cache_source_baseline','sealed_baseline','class_cache','finalizer_dry_run')
$reviewB = Read-ReviewReceipt -Path $FormalReceiptReviewPath -ExpectedLane 'B_CANONICAL_FORMAL_RECEIPT' -RequiredRoles @('formal_receipt','gate_manifest','receipt_builder','authority_module')
$reviewC = Read-ReviewReceipt -Path $AuthorizationReviewPath -ExpectedLane 'C_FINALIZER_AND_AUTHORIZATION' -RequiredRoles @('authorization_manifest','authorization_validator','pre_formal_dry_run','selftest','tooling_seal','finalizer_dry_run')
$seal = [pscustomobject][ordered]@{
    schema = 'SpaceSyndicatePr90CanonicalImportAuthorityV3Attempt19SealV1'
    seal_id = 'pr90-canonical-import-authority-v3-attempt19-seal-001'
    status = 'SEALED'
    sealed_at_utc = [DateTimeOffset]::UtcNow.ToString('o')
    authorization_id = [string]$manifest.authorization_id
    authorization_manifest_path = [IO.Path]::GetFullPath($ManifestPath)
    authorization_manifest_sha256 = Get-Sha256 $ManifestPath
    authorization_manifest_sha_sidecar_path = [IO.Path]::GetFullPath($ManifestShaPath)
    authorization_manifest_sha_sidecar_sha256 = Get-Sha256 $ManifestShaPath
    product_head_sha = [string]$manifest.product_head_sha
    product_tree_sha = [string]$manifest.product_tree_sha
    import_tooling_head_sha = [string]$manifest.import_tooling_head_sha
    import_tooling_tree_sha = [string]$manifest.import_tooling_tree_sha
    import_runner_sha256 = [string]$manifest.import_runner_sha256
    authorization_builder_sha256 = [string]$manifest.authorization_builder_sha256
    authorization_validator_sha256 = [string]$manifest.authorization_validator_sha256
    sealed_baseline_sha256 = [string]$manifest.sealed_baseline_sha256
    import_pass1_manifest_sha256 = [string]$manifest.import_pass1_manifest_sha256
    import_pass2_manifest_sha256 = [string]$manifest.import_pass2_manifest_sha256
    warmup_log_sha256 = [string]$manifest.warmup_log_sha256
    class_cache_sha256 = [string]$manifest.class_cache_sha256
    formal_gate_1_79_receipt_sha256 = [string]$manifest.formal_gate_1_79_receipt_sha256
    import_finalizer_dry_run_evidence_sha256 = [string]$manifest.import_finalizer_dry_run_evidence_sha256
    godot_executable_sha256 = [string]$manifest.godot_executable_sha256
    project_godot_sha256 = [string]$manifest.project_godot_sha256
    cursor_runbook_sha256 = [string]$manifest.cursor_runbook_sha256
    import_controller_sha256 = [string]$manifest.import_controller_sha256
    import_finalizer_sha256 = [string]$manifest.import_finalizer_sha256
    selftest_manifest_sha256 = [string]$manifest.selftest_manifest_sha256
    formal_dry_run_sha256 = [string]$manifest.formal_dry_run_sha256
    tooling_seal_sha256 = [string]$manifest.tooling_seal_sha256
    pre_formal_authorization_dry_run_path = [IO.Path]::GetFullPath($PreFormalDryRunPath)
    pre_formal_authorization_dry_run_sha256 = Get-Sha256 $PreFormalDryRunPath
    authorization_declared_field_count = [int]$dryRun.authorization_declared_field_count
    authorization_validated_field_count = [int]$dryRun.authorization_validated_field_count
    authorization_field_mismatch_count = 0
    class_cache_review_path = [IO.Path]::GetFullPath($ClassCacheReviewPath)
    class_cache_review_sha256 = Get-Sha256 $ClassCacheReviewPath
    class_cache_review_p0 = [int]$reviewA.p0_count
    class_cache_review_p1 = [int]$reviewA.p1_count
    class_cache_review = [string]$reviewA.status
    formal_receipt_review_path = [IO.Path]::GetFullPath($FormalReceiptReviewPath)
    formal_receipt_review_sha256 = Get-Sha256 $FormalReceiptReviewPath
    formal_receipt_review_p0 = [int]$reviewB.p0_count
    formal_receipt_review_p1 = [int]$reviewB.p1_count
    formal_receipt_review = [string]$reviewB.status
    authorization_review_path = [IO.Path]::GetFullPath($AuthorizationReviewPath)
    authorization_review_sha256 = Get-Sha256 $AuthorizationReviewPath
    authorization_review_p0 = [int]$reviewC.p0_count
    authorization_review_p1 = [int]$reviewC.p1_count
    authorization_review = [string]$reviewC.status
    authorized_run_count = 1
    automatic_retry_allowed = $false
    formal_mcp_execution_count = 0
    authorized_run_count_consumed = 0
    exact_sha_mcp_status = 'NOT_STARTED'
    viewport_started = $false
    headless_matrix_started = $false
    product_headless_2000_started = $false
    pr90_merged = $false
    v076_branch_created = $false
    canonical_payload_sha256 = ''
}
$seal.canonical_payload_sha256 = Get-CanonicalPayloadSha256 $seal
Write-ImmutableJson -Path $OutputPath -Value $seal
Write-ImmutableSha256Sidecar -Path $OutputShaPath -TargetPath $OutputPath
if (Test-Path -LiteralPath $OutputMarkdownPath) { throw "Refusing to overwrite immutable seal: $OutputMarkdownPath" }
$markdown = @"
# PR90 Attempt 19 Authorization Seal

- Status: `SEALED`
- Authorization ID: `$($seal.authorization_id)`
- Product Head / Tree: `$($seal.product_head_sha)` / `$($seal.product_tree_sha)`
- Tooling Head / Tree: `$($seal.import_tooling_head_sha)` / `$($seal.import_tooling_tree_sha)`
- Manifest SHA-256: `$($seal.authorization_manifest_sha256)`
- Import Runner SHA-256: `$($seal.import_runner_sha256)`
- Canonical Formal Receipt SHA-256: `$($seal.formal_gate_1_79_receipt_sha256)`
- Import Finalizer Dry-Run SHA-256: `$($seal.import_finalizer_dry_run_evidence_sha256)`
- Pre-formal Dry-Run SHA-256: `$($seal.pre_formal_authorization_dry_run_sha256)`
- Class Cache Review: `GO` (`P0=0`, `P1=0`)
- Formal Receipt Review: `GO` (`P0=0`, `P1=0`)
- Authorization Review: `GO` (`P0=0`, `P1=0`)
- Formal MCP: `NOT_STARTED` (`execution_count=0`, `authorization_consumed=0`)

This seal authorizes no execution by itself. It preserves one future Exact-SHA MCP authorization request only.
"@
[IO.File]::WriteAllText([IO.Path]::GetFullPath($OutputMarkdownPath), $markdown, [Text.UTF8Encoding]::new($false))
$seal | ConvertTo-Json -Depth 100 -Compress
