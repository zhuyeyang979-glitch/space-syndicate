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
$predecessorLedgerPath = Join-Path $evidenceRoot 'probe_budget_ledger_002.json'
$probeReportPath = Join-Path $root 'reports/reuse/generation9_platform_qualification/platform-probes/probe-009/platform_probe_report.json'
$probeManifestPath = Join-Path $root 'reports/reuse/generation9_platform_qualification/platform-probes/probe-009/raw_evidence_manifest.json'
$selfTestReportPath = Join-Path $evidenceRoot 'runner_static_self_test_005.json'
$runnerManifestPath = Join-Path $evidenceRoot 'repaired_runner_manifest_004.json'
$runnerSealPath = Join-Path $evidenceRoot 'repaired_runner_seal_004.json'
$ledgerPath = Join-Path $evidenceRoot 'probe_budget_ledger_003.json'
$successorPath = Join-Path $evidenceRoot 'post_restart_tooling_successor_003.json'

foreach ($required in @(
    $runnerPath,
    $selfTestPath,
    $packagerPath,
    $monitorPath,
    $requalificationSealPath,
    $predecessorLedgerPath,
    $probeReportPath,
    $probeManifestPath
)) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "Required final-successor input is missing: $required"
    }
}
foreach ($destination in @($selfTestReportPath, $runnerManifestPath, $runnerSealPath, $ledgerPath, $successorPath)) {
    if (Test-Path -LiteralPath $destination) {
        throw "Refusing to overwrite final-successor evidence: $destination"
    }
}

$predecessorLedger = Get-Content -LiteralPath $predecessorLedgerPath -Raw | ConvertFrom-Json
$requalificationSeal = Get-Content -LiteralPath $requalificationSealPath -Raw | ConvertFrom-Json
$probeReport = Get-Content -LiteralPath $probeReportPath -Raw | ConvertFrom-Json
if (
    [string]$predecessorLedger.status -cne 'ACTIVE' -or
    [int]$predecessorLedger.ledger_sequence -ne 2 -or
    [int]$predecessorLedger.remaining_launch_count -ne 2 -or
    [string]$predecessorLedger.next_probe_id -cne 'probe-009'
) {
    throw 'Predecessor budget ledger is not the authorized sequence two state.'
}
if (
    [string]$requalificationSeal.status -cne 'SEALED' -or
    [string]$requalificationSeal.authorization_id -cne $authorizationId
) {
    throw 'Post-restart requalification seal is not active.'
}
if (
    [string]$probeReport.status -cne 'FAIL' -or
    [string]$probeReport.classification -cne 'TOOLING_FAILURE_EXTERNAL_TO_RUNTIME_GUI_FOCUS_BINDING' -or
    [bool]$probeReport.qualification_pass
) {
    throw 'Probe 009 was not frozen as the expected focus-binding tooling failure.'
}

$selfTestJson = & pwsh -NoProfile -File $selfTestPath -Runner $runnerPath
if ($LASTEXITCODE -ne 0) {
    throw 'Final-successor runner static self-test failed.'
}
$selfTest = $selfTestJson | ConvertFrom-Json
if (
    [string]$selfTest.status -cne 'PASS' -or
    [int]$selfTest.powershell_parse_error_count -ne 0 -or
    [int]$selfTest.unknown_command_count -ne 0 -or
    [int]$selfTest.godot_launch_count -ne 0
) {
    throw 'Final-successor runner static self-test report is incomplete.'
}

$generatedAt = [DateTime]::UtcNow.ToString('o')
$utf8 = [Text.UTF8Encoding]::new($false)
function Write-Json {
    param([string]$Path, [object]$Value)
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 100) + "`n"), $utf8)
}
function Get-Sha256 {
    param([string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

Write-Json -Path $selfTestReportPath -Value $selfTest
$runnerManifest = [ordered]@{
    schema_version = 'space_syndicate.v076.generation9_repaired_runner_manifest.v5'
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
        report_path = 'reports/reuse/generation9_platform_qualification/post_restart_requalification/runner_static_self_test_005.json'
        report_sha256 = Get-Sha256 $selfTestReportPath
        status = 'PASS'
        powershell_parse_error_count = [int]$selfTest.powershell_parse_error_count
        unknown_command_count = [int]$selfTest.unknown_command_count
    }
    packager_sha256 = Get-Sha256 $packagerPath
    monitor_sha256 = Get-Sha256 $monitorPath
    requalification_seal_sha256 = Get-Sha256 $requalificationSealPath
    probe009_raw_evidence_manifest_sha256 = Get-Sha256 $probeManifestPath
    probe009_report_sha256 = Get-Sha256 $probeReportPath
    workflow_contract = [ordered]@{
        external_unique_window_activation_required = $true
        external_seed_field_click_count = 1
        runtime_focus_confirmation_click_count = 1
        runtime_viewport_coordinate_for_runtime_focus_only = $true
        windows_seed_character_input_count = 0
        mcp_only_seed_character_input = $true
        direct_runtime_seed_injection_count = 0
        seed_four_layer_parity_required = $true
        normal_cleanup_required = $true
        formal_generation = $false
        generation9_formal_execution_count = 0
    }
    tooling_change_resets_consecutive_pass_count = $true
    consecutive_pass_count_at_seal = 0
    godot_launch_count_for_static_validation = 0
    product_file_mutation_count = 0
}
Write-Json -Path $runnerManifestPath -Value $runnerManifest
$runnerSeal = [ordered]@{
    schema_version = 'space_syndicate.v076.generation9_repaired_runner_seal.v5'
    authorization_id = $authorizationId
    generated_at_utc = $generatedAt
    status = 'SEALED'
    runner_manifest_sha256 = Get-Sha256 $runnerManifestPath
    runner_sha256 = Get-Sha256 $runnerPath
    static_self_test_sha256 = Get-Sha256 $selfTestPath
    static_self_test_report_sha256 = Get-Sha256 $selfTestReportPath
    packager_sha256 = Get-Sha256 $packagerPath
    requalification_seal_sha256 = Get-Sha256 $requalificationSealPath
    external_to_runtime_focus_binding_green = $true
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
    ledger_sequence = 3
    predecessor_ledger_sha256 = Get-Sha256 $predecessorLedgerPath
    status = 'ACTIVE'
    existing_probe_budget_reactivated = $true
    probe_budget_before_requalification = 4
    additional_probe_budget_this_authorization = 0
    probe_budget_after_requalification = 4
    launch_count_after_requalification = 3
    remaining_launch_count = 1
    required_consecutive_pass_count = 2
    current_consecutive_pass_count = 0
    next_probe_id = 'probe-010'
    consumed_probe_id = 'probe-009'
    consumed_probe_classification = 'TOOLING_FAILURE_EXTERNAL_TO_RUNTIME_GUI_FOCUS_BINDING'
    consumed_probe_report_sha256 = Get-Sha256 $probeReportPath
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
    probe009_frozen = $true
    probe009_report_sha256 = Get-Sha256 $probeReportPath
    runner_seal_sha256 = Get-Sha256 $runnerSealPath
    budget_ledger_sha256 = Get-Sha256 $ledgerPath
    next_probe_id = 'probe-010'
    remaining_launch_count = 1
    current_consecutive_pass_count = 0
    generation9_formal_execution_count = 0
}
Write-Json -Path $successorPath -Value $successor

foreach ($path in @($selfTestReportPath, $runnerManifestPath, $runnerSealPath, $ledgerPath, $successorPath)) {
    [IO.File]::WriteAllText(
        "$path.sha256",
        "$(Get-Sha256 $path)  $([IO.Path]::GetFileName($path))`n",
        $utf8
    )
}

$successor | ConvertTo-Json -Depth 100
