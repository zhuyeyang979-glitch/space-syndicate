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
$runnerPath = Join-Path $root 'tools/v076_generation9_platform_probe.ps1'
$selfTestPath = Join-Path $root 'tools/v076_generation9_platform_probe_static_self_test.ps1'
$packagerPath = Join-Path $root 'tools/v076_generation9_platform_probe_packager.ps1'
$monitorPath = 'C:\Users\Administrator\Documents\Codex\2026-08-20\qu\outputs\v076-generation9-platform-qualification\monitor_generation9_probe.ps1'
$requalificationSealPath = Join-Path $evidenceRoot 'post_restart_requalification_seal.json'
$predecessorLedgerPath = Join-Path $evidenceRoot 'probe_budget_ledger_000.json'
$probe007ManifestPath = Join-Path $root 'reports/reuse/generation9_platform_qualification/platform-probes/probe-007/raw_evidence_manifest.json'
$probe007ReportPath = Join-Path $root 'reports/reuse/generation9_platform_qualification/platform-probes/probe-007/platform_probe_report.json'
$selfTestReportPath = Join-Path $evidenceRoot 'runner_static_self_test_003.json'
$runnerManifestPath = Join-Path $evidenceRoot 'repaired_runner_manifest_002.json'
$runnerSealPath = Join-Path $evidenceRoot 'repaired_runner_seal_002.json'
$ledgerPath = Join-Path $evidenceRoot 'probe_budget_ledger_001.json'
$successorPath = Join-Path $evidenceRoot 'post_restart_tooling_successor_001.json'

foreach ($required in @(
    $runnerPath,
    $selfTestPath,
    $packagerPath,
    $monitorPath,
    $requalificationSealPath,
    $predecessorLedgerPath,
    $probe007ManifestPath,
    $probe007ReportPath
)) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "Required successor-seal input is missing: $required"
    }
}
foreach ($destination in @(
    $selfTestReportPath,
    $runnerManifestPath,
    $runnerSealPath,
    $ledgerPath,
    $successorPath
)) {
    if (Test-Path -LiteralPath $destination) {
        throw "Refusing to overwrite successor evidence: $destination"
    }
}

$predecessorLedger = Get-Content -LiteralPath $predecessorLedgerPath -Raw | ConvertFrom-Json
$requalificationSeal = Get-Content -LiteralPath $requalificationSealPath -Raw | ConvertFrom-Json
$probe007Report = Get-Content -LiteralPath $probe007ReportPath -Raw | ConvertFrom-Json
if (
    [string]$predecessorLedger.status -cne 'ACTIVE' -or
    [int]$predecessorLedger.ledger_sequence -ne 0 -or
    [int]$predecessorLedger.remaining_launch_count -ne 4 -or
    [string]$predecessorLedger.next_probe_id -cne 'probe-007'
) {
    throw 'Predecessor budget ledger is not the authorized sequence zero state.'
}
if (
    [string]$requalificationSeal.status -cne 'SEALED' -or
    [string]$requalificationSeal.authorization_id -cne $authorizationId
) {
    throw 'Post-restart requalification seal is not active.'
}
if (
    [string]$probe007Report.status -cne 'FAIL' -or
    [string]$probe007Report.classification -cne 'TOOLING_FAILURE_WINDOW_COORDINATE_MAPPING' -or
    [bool]$probe007Report.qualification_pass
) {
    throw 'Probe 007 was not frozen as the expected tooling failure.'
}

$selfTestJson = & pwsh -NoProfile -File $selfTestPath -Runner $runnerPath
if ($LASTEXITCODE -ne 0) {
    throw 'Repaired runner static self-test failed.'
}
$selfTest = $selfTestJson | ConvertFrom-Json
if (
    [string]$selfTest.status -cne 'PASS' -or
    [int]$selfTest.powershell_parse_error_count -ne 0 -or
    [int]$selfTest.unknown_command_count -ne 0 -or
    [string]$selfTest.screenshot_coordinate_space_contract -cne 'PASS' -or
    [int]$selfTest.godot_launch_count -ne 0
) {
    throw 'Repaired runner static self-test report is incomplete.'
}

$generatedAt = [DateTime]::UtcNow.ToString('o')
$utf8 = [Text.UTF8Encoding]::new($false)
function Write-Json {
    param([string]$Path, [object]$Value)
    [IO.File]::WriteAllText(
        $Path,
        (($Value | ConvertTo-Json -Depth 100) + "`n"),
        $utf8
    )
}
function Get-Sha256 {
    param([string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

Write-Json -Path $selfTestReportPath -Value $selfTest
$runnerManifest = [ordered]@{
    schema_version = 'space_syndicate.v076.generation9_repaired_runner_manifest.v3'
    authorization_id = $authorizationId
    probe_budget_authorization_id = $probeBudgetAuthorizationId
    parent_authorization_id = $parentAuthorizationId
    generated_at_utc = $generatedAt
    status = 'PASS'
    predecessor_committed_head_sha = (git -C $root rev-parse HEAD).Trim()
    predecessor_committed_tree_sha = (git -C $root rev-parse 'HEAD^{tree}').Trim()
    product_candidate_head_sha = '32b1a4d0e4b47735c98a09d5f5cd034a160d870d'
    product_candidate_tree_sha = '5e6945f14e37b9416192f1945561b503f02fe49d'
    runner = [ordered]@{
        path = 'tools/v076_generation9_platform_probe.ps1'
        sha256 = Get-Sha256 $runnerPath
        size_bytes = (Get-Item -LiteralPath $runnerPath).Length
    }
    static_self_test = [ordered]@{
        path = 'tools/v076_generation9_platform_probe_static_self_test.ps1'
        sha256 = Get-Sha256 $selfTestPath
        report_path = 'reports/reuse/generation9_platform_qualification/post_restart_requalification/runner_static_self_test_003.json'
        report_sha256 = Get-Sha256 $selfTestReportPath
        status = 'PASS'
        powershell_parse_error_count = [int]$selfTest.powershell_parse_error_count
        unknown_command_count = [int]$selfTest.unknown_command_count
    }
    packager = [ordered]@{
        path = 'tools/v076_generation9_platform_probe_packager.ps1'
        sha256 = Get-Sha256 $packagerPath
    }
    dependencies = [ordered]@{
        monitor_storage = 'EXTERNAL_TASK_OUTPUT_READ_ONLY_INPUT'
        monitor_sha256 = Get-Sha256 $monitorPath
        requalification_seal_sha256 = Get-Sha256 $requalificationSealPath
        probe007_raw_evidence_manifest_sha256 = Get-Sha256 $probe007ManifestPath
        probe007_report_sha256 = Get-Sha256 $probe007ReportPath
    }
    workflow_contract = [ordered]@{
        budget_ledger_guard = $true
        post_restart_requalification_seal_guard = $true
        evidence_root_overwrite_guard = $true
        commercial_menu_navigation_before_seed_focus = $true
        menu_modal_closed_before_seed_input = $true
        start_overlay_visible_before_seed_input = $true
        runtime_viewport_coordinate_advisory_only = $true
        computer_use_coordinate_space = 'FRESH_WINDOW_SCREENSHOT'
        visible_seed_input_center_click_count = 1
        windows_seed_character_input_count = 0
        mcp_only_seed_character_input = $true
        direct_runtime_seed_injection_count = 0
        seed_four_layer_parity_required = $true
        listen_endpoint_only_port_guard = $true
        normal_cleanup_required = $true
        raw_terminal_manifest_required = $true
        formal_generation = $false
        generation9_formal_execution_count = 0
    }
    static_audits = [ordered]@{
        ast_parse = 'PASS'
        unknown_command_scan = 'PASS'
        menu_navigation_order = 'PASS'
        screenshot_coordinate_space_contract = 'PASS'
        seed_input_ownership = 'PASS'
        timeout_state_machine = 'PASS'
        cleanup_state_machine = 'PASS'
        evidence_finalization = 'PASS'
        budget_ledger = 'PASS'
    }
    tooling_change_resets_consecutive_pass_count = $true
    consecutive_pass_count_at_seal = 0
    godot_launch_count_for_static_validation = 0
    product_file_mutation_count = 0
    direct_filesystem_product_edit_count = 0
}
Write-Json -Path $runnerManifestPath -Value $runnerManifest
$runnerSeal = [ordered]@{
    schema_version = 'space_syndicate.v076.generation9_repaired_runner_seal.v3'
    authorization_id = $authorizationId
    generated_at_utc = $generatedAt
    status = 'SEALED'
    runner_manifest_sha256 = Get-Sha256 $runnerManifestPath
    runner_sha256 = Get-Sha256 $runnerPath
    static_self_test_sha256 = Get-Sha256 $selfTestPath
    static_self_test_report_sha256 = Get-Sha256 $selfTestReportPath
    packager_sha256 = Get-Sha256 $packagerPath
    requalification_seal_sha256 = Get-Sha256 $requalificationSealPath
    screenshot_coordinate_space_contract_green = $true
    listen_endpoint_only_port_guard_green = $true
    cleanup_state_machine_green = $true
    evidence_finalization_green = $true
    budget_ledger_guard_green = $true
    tooling_change_resets_consecutive_pass_count = $true
    consecutive_pass_count = 0
    post_seal_input_mutation_count = 0
}
Write-Json -Path $runnerSealPath -Value $runnerSeal
$ledger = [ordered]@{
    schema_version = 'space_syndicate.v076.generation9_probe_budget_ledger.v1'
    authorization_id = $authorizationId
    probe_budget_authorization_id = $probeBudgetAuthorizationId
    parent_authorization_id = $parentAuthorizationId
    generated_at_utc = $generatedAt
    append_only = $true
    ledger_sequence = 1
    predecessor_ledger_sha256 = Get-Sha256 $predecessorLedgerPath
    status = 'ACTIVE'
    existing_probe_budget_reactivated = $true
    probe_budget_before_requalification = 4
    additional_probe_budget_this_authorization = 0
    probe_budget_after_requalification = 4
    launch_count_after_requalification = 1
    remaining_launch_count = 3
    required_consecutive_pass_count = 2
    current_consecutive_pass_count = 0
    next_probe_id = 'probe-008'
    consumed_probe_id = 'probe-007'
    consumed_probe_classification = 'TOOLING_FAILURE_WINDOW_COORDINATE_MAPPING'
    consumed_probe_report_sha256 = Get-Sha256 $probe007ReportPath
    tooling_change_resets_consecutive_pass_count = $true
    generation9_formal_execution_count = 0
    generation10_creation_count = 0
}
Write-Json -Path $ledgerPath -Value $ledger
$successor = [ordered]@{
    schema_version = 'space_syndicate.v076.post_restart_tooling_successor.v1'
    authorization_id = $authorizationId
    generated_at_utc = $generatedAt
    status = 'SEALED'
    system_requalification_repeated = $false
    system_requalification_seal_sha256 = Get-Sha256 $requalificationSealPath
    probe007_frozen = $true
    probe007_report_sha256 = Get-Sha256 $probe007ReportPath
    runner_seal_sha256 = Get-Sha256 $runnerSealPath
    budget_ledger_sha256 = Get-Sha256 $ledgerPath
    next_probe_id = 'probe-008'
    remaining_launch_count = 3
    current_consecutive_pass_count = 0
    generation9_formal_execution_count = 0
}
Write-Json -Path $successorPath -Value $successor

foreach ($path in @(
    $selfTestReportPath,
    $runnerManifestPath,
    $runnerSealPath,
    $ledgerPath,
    $successorPath
)) {
    $sidecarPath = "$path.sha256"
    [IO.File]::WriteAllText(
        $sidecarPath,
        "$(Get-Sha256 $path)  $([IO.Path]::GetFileName($path))`n",
        $utf8
    )
}

$successor | ConvertTo-Json -Depth 100
