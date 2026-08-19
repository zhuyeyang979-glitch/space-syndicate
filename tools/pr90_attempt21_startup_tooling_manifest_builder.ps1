[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ToolingWorktree,
    [Parameter(Mandatory = $true)][string]$ProductHeadSha,
    [Parameter(Mandatory = $true)][string]$ProductTreeSha,
    [Parameter(Mandatory = $true)][string]$FrozenFailureWitnessPath,
    [Parameter(Mandatory = $true)][string]$ExpectedFrozenFailureWitnessSha256,
    [Parameter(Mandatory = $true)][string]$SelfTestPath,
    [Parameter(Mandatory = $true)][string]$ExpectedSelfTestSha256,
    [Parameter(Mandatory = $true)][string]$ProbeAEvidencePath,
    [Parameter(Mandatory = $true)][string]$ExpectedProbeAEvidenceSha256,
    [Parameter(Mandatory = $true)][string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path -LiteralPath $ToolingWorktree).Path.TrimEnd('\')
Import-Module (Join-Path $PSScriptRoot 'pr90_attempt21_mcp_startup_contract.psm1') -Force

if (@(& git -C $root status --porcelain=v1 --untracked-files=all).Count -ne 0) { throw 'Startup tooling manifest requires a clean worktree and index.' }
$toolingHead = (& git -C $root rev-parse HEAD).Trim()
$toolingTree = (& git -C $root rev-parse 'HEAD^{tree}').Trim()
if ($toolingHead -notmatch '^[0-9a-f]{40}$' -or $toolingTree -notmatch '^[0-9a-f]{40}$') { throw 'Tooling git identity is invalid.' }
if ((Get-StartupSha256 $FrozenFailureWitnessPath) -cne $ExpectedFrozenFailureWitnessSha256.ToLowerInvariant()) { throw 'Frozen Attempt 20 witness hash mismatch.' }
if ((Get-StartupSha256 $SelfTestPath) -cne $ExpectedSelfTestSha256.ToLowerInvariant()) { throw 'Startup self-test hash mismatch.' }
if ((Get-StartupSha256 $ProbeAEvidencePath) -cne $ExpectedProbeAEvidenceSha256.ToLowerInvariant()) { throw 'Probe A evidence hash mismatch.' }
$frozen = Get-Content -Raw -LiteralPath $FrozenFailureWitnessPath | ConvertFrom-Json -Depth 100 -DateKind String
$selftest = Get-Content -Raw -LiteralPath $SelfTestPath | ConvertFrom-Json -Depth 100 -DateKind String
$probe = Get-Content -Raw -LiteralPath $ProbeAEvidencePath | ConvertFrom-Json -Depth 100 -DateKind String

$relativePaths = @(
    'tools/pr90_attempt19_authority_contract.psm1',
    'tools/pr90_attempt19_authorization_manifest_builder.ps1',
    'tools/pr90_attempt19_authorization_validator.ps1',
    'tools/pr90_attempt19_import_runner_v3.ps1',
    'tools/pr90_attempt19_import_controller_v3.ps1',
    'tools/pr90_attempt19_import_finalizer_dry_run.ps1',
    'tools/role_godot_mcp_process_identity.psm1',
    'tools/invoke_role_godot_mcp.ps1',
    'tools/stop_role_godot_mcp.ps1',
    'tools/launch_role_godot_mcp.ps1',
    'tools/pr90_attempt21_mcp_startup_contract.psm1',
    'tools/pr90_mcp_startup_state_machine_v1.psm1',
    'tools/pr90_attempt21_mcp_startup_watchdog.ps1',
    'tools/pr90_attempt21_mcp_startup_probe.ps1',
    'tools/pr90_attempt21_cursor_aware_exact_mcp_v5.ps1',
    'tools/pr90_attempt21_startup_boundary_selftest.ps1',
    'tools/pr90_attempt21_startup_tooling_manifest_builder.ps1',
    'tools/pr90_attempt21_startup_tooling_validator.ps1',
    'tools/pr90_attempt21_startup_tooling_seal_builder.ps1'
)
$files = @(
    foreach ($relative in $relativePaths) {
        $path = Join-Path $root $relative
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing startup tooling file: $relative" }
        [ordered]@{
            relative_path=$relative;path=[IO.Path]::GetFullPath($path);bytes=[int64](Get-Item -LiteralPath $path).Length;
            sha256=Get-StartupSha256 $path;git_blob=(& git -C $root hash-object -- $relative).Trim()
        }
    }
)
$specs = @(Get-McpStartupMilestoneSpecs)
$probePass = ([string]$probe.status -ceq 'PASS' -and [int]$probe.milestone_count -eq 12 -and [bool]$probe.startup_milestone_complete -and [bool]$probe.stops_cleanly)
$selftestPass = ([string]$selftest.status -ceq 'PASS' -and [int]$selftest.case_count -ge 28 -and [int]$selftest.pass_count -eq [int]$selftest.case_count -and [int]$selftest.startup_failure_stage_false_report_count -eq 0 -and [int]$selftest.startup_stall_false_green_count -eq 0)
$eligible = ($probePass -and $selftestPass)
$manifest = [ordered]@{
    schema='SpaceSyndicatePr90McpStartupToolingManifestV1'
    status=if($eligible){'READY'}else{'BLOCKED_PENDING_FULL_M0_M11_PROBE'}
    authorization_eligible=$eligible
    created_at_utc=[DateTimeOffset]::UtcNow.ToString('o')
    product_head_sha=$ProductHeadSha
    product_tree_sha=$ProductTreeSha
    tooling_head_sha=$toolingHead
    tooling_tree_sha=$toolingTree
    frozen_attempt_id='PR90_ATTEMPT20_EXACT_SHA_MCP'
    frozen_tooling_head_sha='657febd3a044b9040f629a98a1b9069d05a35d6a'
    frozen_tooling_tree_sha='da1fd8dfc750b5915ce67e3c7342ff2f014cb08b'
    frozen_failure_witness_path=[IO.Path]::GetFullPath($FrozenFailureWitnessPath)
    frozen_failure_witness_sha256=Get-StartupSha256 $FrozenFailureWitnessPath
    frozen_failure_witness_bytes=[int64](Get-Item -LiteralPath $FrozenFailureWitnessPath).Length
    frozen_failure_witness_json_parse_green=$true
    attempt20_startup_root_cause_class='J'
    attempt20_root_cause_detail='RUNBOOK_WAIT_LOOP_OR_TIMEOUT_STATE_MACHINE_DEFECT; endpoint/request/response historical states remain UNKNOWN.'
    attempt20_last_independently_proven_milestone='M2'
    attempt20_last_contiguous_proven_milestone='M0'
    attempt20_first_missing_ordered_milestone='M1'
    attempt20_endpoint_bound='UNKNOWN'
    attempt20_endpoint_owner_match='UNKNOWN'
    attempt20_first_jsonrpc_request_sent='UNKNOWN'
    attempt20_first_jsonrpc_response_received='UNKNOWN'
    tooling_files=$files
    startup_milestones=@($specs|ForEach-Object{[ordered]@{index=[int]$_.index;id=[string]$_.id;name=[string]$_.name;timeout_seconds=[int]$_.timeout_seconds;failure_class=[string]$_.failure_class}})
    opaque_startup_wait_count=0
    startup_selftest_path=[IO.Path]::GetFullPath($SelfTestPath)
    startup_selftest_sha256=Get-StartupSha256 $SelfTestPath
    startup_selftest_status=[string]$selftest.status
    startup_selftest_case_count=[int]$selftest.case_count
    startup_selftest_pass_count=[int]$selftest.pass_count
    startup_failure_stage_false_report_count=[int]$selftest.startup_failure_stage_false_report_count
    startup_stall_false_green_count=[int]$selftest.startup_stall_false_green_count
    probe_a_evidence_path=[IO.Path]::GetFullPath($ProbeAEvidencePath)
    probe_a_evidence_sha256=Get-StartupSha256 $ProbeAEvidencePath
    probe_a_status=[string]$probe.status
    probe_a_milestone_count=[int]$probe.milestone_count
    probe_a_first_failure_class=[string]$probe.first_failure_class
    probe_a_formal_authorization_consumed=[bool]$probe.formal_authorization_consumed
    probe_a_formal_mcp_execution_count=[int]$probe.formal_mcp_execution_count
    probe_a_authorized_run_count_consumed=[int]$probe.authorized_run_count_consumed
    product_code_change_count=0
    product_test_change_count=0
    gate_manifest_change_count=0
    formal_gate_rerun_count=0
    formal_mcp_execution_count=0
    authorized_run_count_consumed=0
    exact_sha_mcp_status='NOT_STARTED'
    viewport_started=$false
    headless_matrix_started=$false
    product_headless_2000_started=$false
    pr90_merged=$false
    v076_branch_created=$false
    new_import_runner_sha256=($files|Where-Object{$_.relative_path -ceq 'tools/pr90_attempt19_import_runner_v3.ps1'}).sha256
    new_cursor_runbook_sha256=($files|Where-Object{$_.relative_path -ceq 'tools/pr90_attempt21_cursor_aware_exact_mcp_v5.ps1'}).sha256
    new_startup_watchdog_sha256=($files|Where-Object{$_.relative_path -ceq 'tools/pr90_attempt21_mcp_startup_watchdog.ps1'}).sha256
    new_startup_state_machine_sha256=($files|Where-Object{$_.relative_path -ceq 'tools/pr90_mcp_startup_state_machine_v1.psm1'}).sha256
    new_startup_contract_sha256=($files|Where-Object{$_.relative_path -ceq 'tools/pr90_attempt21_mcp_startup_contract.psm1'}).sha256
    canonical_payload_sha256=''
}
$manifest.canonical_payload_sha256 = Get-StartupCanonicalSha256 $manifest
Write-StartupImmutableJson -Path $OutputPath -Value $manifest -WriteSha256Sidecar | Out-Null
$manifest | ConvertTo-Json -Depth 100 -Compress
