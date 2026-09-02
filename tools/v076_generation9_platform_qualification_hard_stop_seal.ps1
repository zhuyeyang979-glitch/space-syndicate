param(
    [string]$Worktree = (Get-Location).Path,
    [string]$EvidenceDirectory = 'reports/reuse/generation9_platform_qualification/post_restart_requalification'
)

$ErrorActionPreference = 'Stop'
$authorizationId = 'USER_AUTHORIZATION_V076_POST_RESTART_REQUALIFICATION_20260902'
$probeBudgetAuthorizationId = 'USER_SUPPLEMENTAL_AUTHORIZATION_V076_GENERATION9_PROBES_PLUS3_20260902'
$parentAuthorizationId = 'USER_AUTHORIZATION_V076_COMMIT_CAPACITY_AND_GENERATION9_20260902'
$root = (Resolve-Path -LiteralPath $Worktree).Path.TrimEnd('\')
$evidenceRoot = [IO.Path]::GetFullPath((Join-Path $root $EvidenceDirectory))
$predecessorLedgerPath = Join-Path $evidenceRoot 'probe_budget_ledger_003.json'
$requalificationSealPath = Join-Path $evidenceRoot 'post_restart_requalification_seal.json'
$historicalHardStopPath = Join-Path $root 'reports/reuse/generation9_platform_qualification/supplemental_system_stability_hard_stop_001.json'
$probe010ReportPath = Join-Path $root 'reports/reuse/generation9_platform_qualification/platform-probes/probe-010/platform_probe_report.json'
$probe010ManifestPath = Join-Path $root 'reports/reuse/generation9_platform_qualification/platform-probes/probe-010/raw_evidence_manifest.json'
$ledgerPath = Join-Path $evidenceRoot 'probe_budget_ledger_004.json'
$receiptPath = Join-Path $evidenceRoot 'probe_budget_exhaustion_receipt.json'
$hardStopPath = Join-Path $evidenceRoot 'platform_qualification_hard_stop_001.json'

foreach ($required in @(
    $predecessorLedgerPath,
    $requalificationSealPath,
    $historicalHardStopPath,
    $probe010ReportPath,
    $probe010ManifestPath
)) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "Required hard-stop input is missing: $required"
    }
}
foreach ($destination in @($ledgerPath, $receiptPath, $hardStopPath)) {
    if (Test-Path -LiteralPath $destination) {
        throw "Refusing to overwrite hard-stop evidence: $destination"
    }
}

$predecessorLedger = Get-Content -LiteralPath $predecessorLedgerPath -Raw | ConvertFrom-Json
$requalificationSeal = Get-Content -LiteralPath $requalificationSealPath -Raw | ConvertFrom-Json
$probe010Report = Get-Content -LiteralPath $probe010ReportPath -Raw | ConvertFrom-Json
if (
    [string]$predecessorLedger.status -cne 'ACTIVE' -or
    [int]$predecessorLedger.ledger_sequence -ne 3 -or
    [int]$predecessorLedger.remaining_launch_count -ne 1 -or
    [string]$predecessorLedger.next_probe_id -cne 'probe-010'
) {
    throw 'Predecessor budget ledger is not the authorized final-launch state.'
}
if (
    [string]$requalificationSeal.status -cne 'SEALED' -or
    [string]$requalificationSeal.authorization_id -cne $authorizationId
) {
    throw 'Post-restart requalification seal is not active.'
}
if (
    [string]$probe010Report.status -cne 'FAIL' -or
    [string]$probe010Report.classification -cne 'PRODUCT_FAILURE' -or
    [bool]$probe010Report.qualification_pass -or
    [int]$probe010Report.remaining_launch_count -ne 0
) {
    throw 'Probe 010 is not the expected frozen final product failure.'
}

$generatedAt = [DateTime]::UtcNow.ToString('o')
$utf8 = [Text.UTF8Encoding]::new($false)
function Get-Sha256 {
    param([string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}
function Write-Json {
    param([string]$Path, [object]$Value)
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 100) + "`n"), $utf8)
}

$probeReports = [ordered]@{}
foreach ($probeId in @('probe-007', 'probe-008', 'probe-009', 'probe-010')) {
    $path = Join-Path $root "reports/reuse/generation9_platform_qualification/platform-probes/$probeId/platform_probe_report.json"
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Packaged Probe report is missing: $probeId"
    }
    $report = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    $probeReports[$probeId] = [ordered]@{
        status = [string]$report.status
        classification = [string]$report.classification
        qualification_pass = [bool]$report.qualification_pass
        report_sha256 = Get-Sha256 $path
    }
}
if (@($probeReports.Keys | Where-Object {$probeReports[$_].qualification_pass}).Count -ne 0) {
    throw 'A packaged post-restart Probe unexpectedly qualified.'
}

$ledger = [ordered]@{
    schema_version = 'space_syndicate.v076.generation9_probe_budget_ledger.v1'
    authorization_id = $authorizationId
    probe_budget_authorization_id = $probeBudgetAuthorizationId
    parent_authorization_id = $parentAuthorizationId
    generated_at_utc = $generatedAt
    append_only = $true
    ledger_sequence = 4
    predecessor_ledger_sha256 = Get-Sha256 $predecessorLedgerPath
    status = 'EXHAUSTED_HARD_STOP'
    existing_probe_budget_reactivated = $true
    probe_budget_before_requalification = 4
    additional_probe_budget_this_authorization = 0
    probe_budget_after_requalification = 4
    launch_count_after_requalification = 4
    remaining_launch_count = 0
    required_consecutive_pass_count = 2
    current_consecutive_pass_count = 0
    next_probe_id = $null
    consumed_probe_id = 'probe-010'
    consumed_probe_classification = 'PRODUCT_FAILURE'
    consumed_probe_report_sha256 = Get-Sha256 $probe010ReportPath
    hard_stop_code = 'PROBE_BUDGET_EXHAUSTED_WITHOUT_TWO_CONSECUTIVE_PASS'
    generation9_formal_execution_count = 0
    generation10_creation_count = 0
}
Write-Json -Path $ledgerPath -Value $ledger
$receipt = [ordered]@{
    schema_version = 'space_syndicate.v076.generation9_probe_budget_exhaustion_receipt.v1'
    authorization_id = $authorizationId
    generated_at_utc = $generatedAt
    status = 'HARD_STOP'
    authorized_launch_count = 4
    actual_launch_count = 4
    remaining_launch_count = 0
    required_consecutive_pass_count = 2
    achieved_consecutive_pass_count = 0
    probes = $probeReports
    final_budget_ledger_sha256 = Get-Sha256 $ledgerPath
    generation9_formal_execution_count = 0
    generation9_automatic_retry_count = 0
    generation10_creation_count = 0
}
Write-Json -Path $receiptPath -Value $receipt
$hardStop = [ordered]@{
    schema_version = 'space_syndicate.v076.generation9_platform_qualification_hard_stop.v1'
    authorization_id = $authorizationId
    generated_at_utc = $generatedAt
    status = 'HARD_STOP'
    hard_stop_code = 'PROBE_BUDGET_EXHAUSTED_WITHOUT_TWO_CONSECUTIVE_PASS'
    authorized_stop_condition_number = 7
    reason = 'All four post-restart nonformal Probe launches were consumed without two consecutive complete PASS results.'
    final_probe_id = 'probe-010'
    final_probe_classification = 'PRODUCT_FAILURE_SEED_UI_MCP_KEY_EVENT_READBACK'
    final_probe_report_sha256 = Get-Sha256 $probe010ReportPath
    final_probe_raw_evidence_manifest_sha256 = Get-Sha256 $probe010ManifestPath
    final_probe_observed = [ordered]@{
        commercial_menu_closed = $true
        start_overlay_visible = $true
        external_unique_window_focus_witness = 'PASS'
        external_visible_seed_click_count = 1
        runtime_seed_focus_confirmation_click_count = 1
        mcp_backspace_event_count = 12
        mcp_seed_character_event_count = 9
        requested_seed = 917592522
        visible_seed_after_input = 900626424
        seed_four_layer_parity = $false
        milestone_pass_count = 10
        milestone_required_count = 12
        import_event_growth = 0
        maximum_import_queue_length = 0
        normal_cleanup = $true
        forced_stop = $false
        terminal_process_count = 0
        terminal_listener_count = 0
    }
    exact_platform_head_sha = (git -C $root rev-parse HEAD).Trim()
    exact_platform_tree_sha = (git -C $root rev-parse 'HEAD^{tree}').Trim()
    product_candidate_head_sha = '32b1a4d0e4b47735c98a09d5f5cd034a160d870d'
    product_candidate_tree_sha = '5e6945f14e37b9416192f1945561b503f02fe49d'
    post_restart_requalification_seal_sha256 = Get-Sha256 $requalificationSealPath
    historical_system_stability_hard_stop_sha256 = Get-Sha256 $historicalHardStopPath
    historical_system_stability_hard_stop_modification_count = 0
    budget_exhaustion_receipt_sha256 = Get-Sha256 $receiptPath
    final_budget_ledger_sha256 = Get-Sha256 $ledgerPath
    frozen_probe_rewrite_count = 0
    product_file_mutation_count = 0
    direct_filesystem_product_edit_count = 0
    preserved_untracked_uid_count = 295
    generation9_formal_execution_count = 0
    generation9_automatic_retry_count = 0
    generation10_creation_count = 0
    step11_status = 'NOT_STARTED_HARD_STOP'
    required_gate_status = 'NOT_STARTED_HARD_STOP'
    commercial_resume_status = 'NOT_STARTED_HARD_STOP'
    human_retest_deferred = $true
    human_green = $false
    next_action_requires_new_authorization = $true
    required_next_authority = 'MCP_ONLY_PRODUCT_SEED_UI_FOCUS_REPAIR_PLUS_NEW_NONFORMAL_PROBE_BUDGET'
}
Write-Json -Path $hardStopPath -Value $hardStop

foreach ($path in @($ledgerPath, $receiptPath, $hardStopPath)) {
    [IO.File]::WriteAllText(
        "$path.sha256",
        "$(Get-Sha256 $path)  $([IO.Path]::GetFileName($path))`n",
        $utf8
    )
}

$hardStop | ConvertTo-Json -Depth 100
