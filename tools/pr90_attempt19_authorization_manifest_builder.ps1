[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ConfigPath,
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [Parameter(Mandatory = $true)][string]$OutputShaPath
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'pr90_attempt19_authority_contract.psm1') -Force
$config = Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json -Depth 100

$toolingRoot = (Resolve-Path -LiteralPath $config.import_tooling_worktree_path).Path
$toolingHead = (& git -C $toolingRoot rev-parse HEAD).Trim()
$toolingTree = (& git -C $toolingRoot rev-parse 'HEAD^{tree}').Trim()
if ($LASTEXITCODE -ne 0 -or $toolingHead -cne [string]$config.import_tooling_head_sha -or $toolingTree -cne [string]$config.import_tooling_tree_sha) {
    throw 'Tooling worktree identity does not match the authorization config.'
}
if (@(& git -C $toolingRoot status --porcelain=v1).Count -ne 0) { throw 'Tooling worktree must be clean before authorization construction.' }
if ((Get-Sha256 $config.import_runner_path) -ceq [string]$config.old_import_runner_sha256) { throw 'Attempt 19 cannot reuse the Attempt 18 import runner SHA.' }
$futureEvidenceRoot = [IO.Path]::GetFullPath([string]$config.formal_evidence_root)
if (Test-Path -LiteralPath $futureEvidenceRoot) {
    if (@(Get-ChildItem -LiteralPath $futureEvidenceRoot -Force).Count -ne 0) { throw 'Future formal evidence root must be new or empty.' }
}

$baseline = Get-Content -Raw -LiteralPath $config.sealed_baseline_path | ConvertFrom-Json -Depth 100
Assert-ProductIdentity $baseline ([string]$config.product_head_sha) ([string]$config.product_tree_sha)
if (-not [bool]$baseline.post_import_baseline_sealed) { throw 'Baseline is not sealed.' }
Assert-ExactSha256 $config.import_pass1_manifest_path ([string]$baseline.import_pass_1_manifest_sha256) | Out-Null
Assert-ExactSha256 $config.import_pass2_manifest_path ([string]$baseline.import_pass_2_manifest_sha256) | Out-Null
Assert-ExactSha256 $config.class_cache_path ([string]$baseline.class_cache_sha256) | Out-Null
Assert-ExactSha256 $config.godot_path ([string]$baseline.godot_sha256) | Out-Null
Assert-ExactSha256 $config.project_godot_path ([string]$baseline.project_godot_sha256) | Out-Null
$sourceBaseline = Get-Content -Raw -LiteralPath $config.class_cache_source_baseline_path | ConvertFrom-Json -Depth 100
Assert-ProductIdentity $sourceBaseline ([string]$config.product_head_sha) ([string]$config.product_tree_sha)
if (-not [bool]$sourceBaseline.post_import_baseline_sealed -or [string]$sourceBaseline.class_cache_sha256 -cne [string]$baseline.class_cache_sha256) { throw 'Attempt 19 class cache is not byte-identical to the Attempt 18 source baseline.' }
$oldAttempt = Get-Content -Raw -LiteralPath $config.old_attempt18_manifest_path | ConvertFrom-Json -Depth 100
if ([string]$oldAttempt.import_authority.post_import_baseline.sha256 -cne (Get-Sha256 $config.class_cache_source_baseline_path)) { throw 'Attempt 18 manifest does not bind the class-cache source baseline.' }
$controllerReceipt = Get-Content -Raw -LiteralPath $config.import_controller_receipt_path | ConvertFrom-Json -Depth 100
if ([string]$controllerReceipt.status -cne 'PASS' -or [string]$controllerReceipt.product_head_sha -cne [string]$config.product_head_sha -or
    [string]$controllerReceipt.product_tree_sha -cne [string]$config.product_tree_sha -or [string]$controllerReceipt.import_controller_sha256 -cne (Get-Sha256 $config.import_controller_path) -or
    [string]$controllerReceipt.bound_import_engine_sha256 -cne (Get-Sha256 $config.bound_import_engine_path) -or [string]$controllerReceipt.sealed_baseline_sha256 -cne (Get-Sha256 $config.sealed_baseline_path) -or
    [string]$controllerReceipt.class_cache_sha256 -cne (Get-Sha256 $config.class_cache_path) -or -not [bool]$controllerReceipt.class_cache_byte_identical_to_attempt18) { throw 'Import controller receipt contract failed.' }

$receipt = Get-Content -Raw -LiteralPath $config.formal_gate_1_79_receipt_path | ConvertFrom-Json -Depth 100
Assert-ProductIdentity $receipt ([string]$config.product_head_sha) ([string]$config.product_tree_sha)
if ([string]$receipt.schema -cne 'SpaceSyndicatePr90CanonicalFormalGateReceiptV1' -or [string]$receipt.status -cne 'PASS' -or
    [int]$receipt.gate_count -ne 79 -or [int]$receipt.pass_count -ne 79 -or [int]$receipt.fail_count -ne 0 -or
    [int]$receipt.duplicate_gate_count -ne 0 -or [int]$receipt.missing_gate_count -ne 0) { throw 'Canonical Formal Receipt contract failed.' }

$finalizer = Get-Content -Raw -LiteralPath $config.import_finalizer_dry_run_path | ConvertFrom-Json -Depth 100
Assert-ProductIdentity $finalizer ([string]$config.product_head_sha) ([string]$config.product_tree_sha)
if ([string]$finalizer.schema -cne 'SpaceSyndicatePr90ImportFinalizerDryRunV1' -or [string]$finalizer.status -cne 'PASS' -or
    [string]$finalizer.tooling_head_sha -cne $toolingHead -or [string]$finalizer.tooling_tree_sha -cne $toolingTree -or
    [string]$finalizer.import_runner_sha256 -cne (Get-Sha256 $config.import_runner_path) -or
    [string]$finalizer.baseline_sha256 -cne (Get-Sha256 $config.sealed_baseline_path)) { throw 'Import Finalizer Dry-Run contract failed.' }

$selftest = Get-Content -Raw -LiteralPath $config.selftest_manifest_path | ConvertFrom-Json -Depth 100
if ([string]$selftest.status -cne 'PASS' -or [int]$selftest.case_count -lt 15 -or [int]$selftest.pass_count -ne [int]$selftest.case_count -or
    [int]$selftest.missing_prerequisite_false_accept_count -ne 0 -or [int]$selftest.stale_tooling_false_accept_count -ne 0) { throw 'Authorization V3 Self-Test is not green.' }

$toolingSeal = Get-Content -Raw -LiteralPath $config.tooling_seal_path | ConvertFrom-Json -Depth 100
if ([string]$toolingSeal.status -cne 'SEALED' -or [string]$toolingSeal.tooling_head_sha -cne $toolingHead -or
    [string]$toolingSeal.tooling_tree_sha -cne $toolingTree -or [string]$toolingSeal.import_runner_sha256 -cne (Get-Sha256 $config.import_runner_path)) { throw 'Tooling seal is not exact.' }

$toolRows = [Collections.Generic.List[object]]::new()
foreach ($pathValue in @($config.authorized_tooling_paths)) {
    $path = (Resolve-Path -LiteralPath ([string]$pathValue)).Path
    if (-not (Test-PathWithinRoot -Path $path -Root $toolingRoot)) { throw "Authorized tooling path is outside tooling root: $path" }
    $relative = [IO.Path]::GetRelativePath($toolingRoot, $path).Replace('\','/')
    $blob = (& git -C $toolingRoot hash-object -- $relative).Trim()
    if ($LASTEXITCODE -ne 0) { throw "Unable to hash tooling blob: $relative" }
    $toolRows.Add([pscustomobject][ordered]@{
        relative_path = $relative
        path = $path
        byte_count = (Get-Item -LiteralPath $path).Length
        sha256 = Get-Sha256 $path
        git_blob_sha = $blob
    })
}
$toolRows = @($toolRows | Sort-Object relative_path)
$manifest = [pscustomobject][ordered]@{
    authorization_schema_version = 'SpaceSyndicatePr90CanonicalImportAuthorityV3'
    authorization_id = [string]$config.authorization_id
    authorization_status = 'AUTHORIZED_FOR_ONE_EXACT_SHA_MCP_AFTER_PREREQUISITES'
    created_at_utc = [DateTimeOffset]::UtcNow.ToString('o')
    authorized_run_count = 1
    automatic_retry_allowed = $false
    formal_run_id = [string]$config.formal_run_id
    formal_evidence_root = [IO.Path]::GetFullPath([string]$config.formal_evidence_root)
    product_head_sha = [string]$config.product_head_sha
    product_tree_sha = [string]$config.product_tree_sha
    import_tooling_branch = [string]$config.import_tooling_branch
    import_tooling_head_sha = $toolingHead
    import_tooling_tree_sha = $toolingTree
    import_tooling_worktree_path = $toolingRoot
    import_runner_path = [IO.Path]::GetFullPath([string]$config.import_runner_path)
    import_runner_sha256 = Get-Sha256 $config.import_runner_path
    authorization_builder_path = [IO.Path]::GetFullPath([string]$config.authorization_builder_path)
    authorization_builder_sha256 = Get-Sha256 $config.authorization_builder_path
    authorization_validator_path = [IO.Path]::GetFullPath([string]$config.authorization_validator_path)
    authorization_validator_sha256 = Get-Sha256 $config.authorization_validator_path
    authorized_tooling_file_count = $toolRows.Count
    authorized_tooling_files = $toolRows
    sealed_baseline_path = [IO.Path]::GetFullPath([string]$config.sealed_baseline_path)
    sealed_baseline_sha256 = Get-Sha256 $config.sealed_baseline_path
    import_pass1_manifest_path = [IO.Path]::GetFullPath([string]$config.import_pass1_manifest_path)
    import_pass1_manifest_sha256 = Get-Sha256 $config.import_pass1_manifest_path
    import_pass2_manifest_path = [IO.Path]::GetFullPath([string]$config.import_pass2_manifest_path)
    import_pass2_manifest_sha256 = Get-Sha256 $config.import_pass2_manifest_path
    warmup_log_path = [IO.Path]::GetFullPath([string]$config.warmup_log_path)
    warmup_log_sha256 = Get-Sha256 $config.warmup_log_path
    class_cache_path = [IO.Path]::GetFullPath([string]$config.class_cache_path)
    class_cache_sha256 = Get-Sha256 $config.class_cache_path
    class_cache_bytes = (Get-Item -LiteralPath $config.class_cache_path).Length
    class_cache_product_head_sha = [string]$config.product_head_sha
    class_cache_product_tree_sha = [string]$config.product_tree_sha
    class_cache_godot_version = [string]$baseline.godot_version
    class_cache_godot_executable_sha256 = [string]$baseline.godot_sha256
    class_cache_source_baseline_path = [IO.Path]::GetFullPath([string]$config.class_cache_source_baseline_path)
    class_cache_source_baseline_sha256 = Get-Sha256 $config.class_cache_source_baseline_path
    formal_gate_1_79_receipt_path = [IO.Path]::GetFullPath([string]$config.formal_gate_1_79_receipt_path)
    formal_gate_1_79_receipt_sha256 = Get-Sha256 $config.formal_gate_1_79_receipt_path
    formal_gate_1_79_receipt_schema_version = [string]$receipt.schema
    formal_gate_1_79_receipt_head_sha = [string]$receipt.head_sha
    formal_gate_1_79_receipt_tree_sha = [string]$receipt.tree_sha
    formal_gate_1_79_receipt_gate_count = [int]$receipt.gate_count
    formal_gate_1_79_receipt_pass_count = [int]$receipt.pass_count
    formal_gate_1_79_receipt_fail_count = [int]$receipt.fail_count
    formal_gate_1_79_receipt_duplicate_gate_count = [int]$receipt.duplicate_gate_count
    formal_gate_1_79_receipt_missing_gate_count = [int]$receipt.missing_gate_count
    import_finalizer_dry_run_path = [IO.Path]::GetFullPath([string]$config.import_finalizer_dry_run_path)
    import_finalizer_dry_run_evidence_sha256 = Get-Sha256 $config.import_finalizer_dry_run_path
    import_finalizer_dry_run_schema_version = [string]$finalizer.schema
    import_finalizer_dry_run_product_head_sha = [string]$finalizer.product_head_sha
    import_finalizer_dry_run_product_tree_sha = [string]$finalizer.product_tree_sha
    import_finalizer_dry_run_tooling_head_sha = [string]$finalizer.tooling_head_sha
    import_finalizer_dry_run_tooling_tree_sha = [string]$finalizer.tooling_tree_sha
    import_finalizer_dry_run_import_runner_sha256 = [string]$finalizer.import_runner_sha256
    import_finalizer_dry_run_baseline_sha256 = [string]$finalizer.baseline_sha256
    import_finalizer_dry_run_status = [string]$finalizer.status
    godot_path = [IO.Path]::GetFullPath([string]$config.godot_path)
    godot_version = [string]$baseline.godot_version
    godot_executable_sha256 = Get-Sha256 $config.godot_path
    project_godot_path = [IO.Path]::GetFullPath([string]$config.project_godot_path)
    project_godot_sha256 = Get-Sha256 $config.project_godot_path
    cursor_runbook_path = [IO.Path]::GetFullPath([string]$config.cursor_runbook_path)
    cursor_runbook_sha256 = Get-Sha256 $config.cursor_runbook_path
    import_controller_path = [IO.Path]::GetFullPath([string]$config.import_controller_path)
    import_controller_sha256 = Get-Sha256 $config.import_controller_path
    import_controller_receipt_path = [IO.Path]::GetFullPath([string]$config.import_controller_receipt_path)
    import_controller_receipt_sha256 = Get-Sha256 $config.import_controller_receipt_path
    bound_import_engine_path = [IO.Path]::GetFullPath([string]$config.bound_import_engine_path)
    bound_import_engine_sha256 = Get-Sha256 $config.bound_import_engine_path
    import_finalizer_path = [IO.Path]::GetFullPath([string]$config.import_finalizer_path)
    import_finalizer_sha256 = Get-Sha256 $config.import_finalizer_path
    selftest_manifest_path = [IO.Path]::GetFullPath([string]$config.selftest_manifest_path)
    selftest_manifest_sha256 = Get-Sha256 $config.selftest_manifest_path
    formal_dry_run_path = [IO.Path]::GetFullPath([string]$config.formal_dry_run_path)
    formal_dry_run_sha256 = Get-Sha256 $config.formal_dry_run_path
    tooling_seal_path = [IO.Path]::GetFullPath([string]$config.tooling_seal_path)
    tooling_seal_sha256 = Get-Sha256 $config.tooling_seal_path
    old_attempt18_manifest_path = [IO.Path]::GetFullPath([string]$config.old_attempt18_manifest_path)
    old_attempt18_manifest_sha256 = Get-Sha256 $config.old_attempt18_manifest_path
    old_import_runner_sha256 = [string]$config.old_import_runner_sha256
    formal_mcp_execution_count = 0
    authorized_run_count_consumed = 0
    conditional_next_stages = @()
    canonical_payload_sha256 = ''
}
$manifest.canonical_payload_sha256 = Get-CanonicalPayloadSha256 $manifest
$requiredFieldCount = @(Get-RequiredManifestFields).Count
if (@($manifest.PSObject.Properties.Name).Count -ne $requiredFieldCount) { throw 'Builder/validator required field contract drift.' }
Write-ImmutableJson -Path $OutputPath -Value $manifest
Write-ImmutableSha256Sidecar -Path $OutputShaPath -TargetPath $OutputPath
[pscustomobject][ordered]@{
    status = 'PASS'
    manifest_path = [IO.Path]::GetFullPath($OutputPath)
    manifest_sha256 = Get-Sha256 $OutputPath
    declared_field_count = @($manifest.PSObject.Properties.Name).Count
    import_runner_sha256 = $manifest.import_runner_sha256
    tooling_head_sha = $toolingHead
    tooling_tree_sha = $toolingTree
} | ConvertTo-Json -Compress
