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
$baseToolingHead = 'd0264a1b819b6acc4f1857d79b15f6a95b0c6ecc'
$baseToolingTree = 'fd1117ddf7bbc254dedfa5e160f34e0f2c9fd3d1'
$toolingParent = (& git -C $root rev-parse 'HEAD^').Trim()
$newToolingCommitCount = [int](& git -C $root rev-list --count "$baseToolingHead..HEAD")
if ($toolingParent -cne $baseToolingHead -or $newToolingCommitCount -ne 1 -or (& git -C $root rev-parse "$baseToolingHead^{tree}").Trim() -cne $baseToolingTree) { throw 'Tooling is not the single authorized child of the frozen base identity.' }
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
    'tools/pr90_endpoint_listener_record_v1.psm1',
    'tools/pr90_endpoint_listener_key_formatter_v1.psm1',
    'tools/pr90_getnettcp_listener_adapter_v1.psm1',
    'tools/pr90_netstat_listener_adapter_v1.psm1',
    'tools/pr90_listener_process_identity_reader_v1.psm1',
    'tools/pr90_listener_parity_validator_v1.psm1',
    'tools/pr90_m5_passive_contract_v1.psm1',
    'tools/pr90_mcp_endpoint_ownership_v2.psm1',
    'tools/pr90_attempt21_mcp_startup_contract.psm1',
    'tools/pr90_mcp_startup_state_machine_v1.psm1',
    'tools/pr90_attempt21_mcp_startup_watchdog.ps1',
    'tools/pr90_attempt21_mcp_startup_probe.ps1',
    'tools/pr90_attempt21_cursor_aware_exact_mcp_v5.ps1',
    'tools/pr90_endpoint_ownership_v2_post_repair_probe.ps1',
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
$frozenProbeEvidence = (
    [string]$probe.probe_id -ceq 'pr90-mcp-endpoint-ownership-v2-post-repair-m0-m11-003' -and
    [string]$probe.status -ceq 'BLOCKED' -and [string]$probe.first_failure_class -ceq 'STARTUP_M9_RUNTIME_STREAM_MISSING' -and
    [int]$probe.post_repair_probe_execution_count -eq 1 -and [int]$probe.new_probe_execution_count -eq 1 -and
    [int]$probe.cumulative_post_repair_probe_execution_count -eq 3 -and -not [bool]$probe.automatic_retry_allowed -and
    -not [bool]$probe.second_new_probe_created -and [bool]$probe.stops_cleanly -and -not [bool]$probe.forced_stop -and
    [int]$probe.godot_process_count_after -eq 0 -and [int]$probe.port_7576_count_after -eq 0 -and
    [int]$probe.port_7586_count_after -eq 0 -and [int]$probe.unrelated_process_termination_count -eq 0
)
if (-not $frozenProbeEvidence) { throw 'Probe 003 is not the exact frozen M9 failure witness.' }
$newProbeExecutionCount = 0
$probePass = $false
$selftestPass = (
    [string]$selftest.status -ceq 'PASS' -and [int]$selftest.case_count -ge 100 -and [int]$selftest.pass_count -eq [int]$selftest.case_count -and
    [int]$selftest.endpoint_ownership_contract_version -eq 2 -and [int]$selftest.endpoint_ownership_v2_case_count -ge 15 -and
    [int]$selftest.endpoint_ownership_v2_pass_count -eq [int]$selftest.endpoint_ownership_v2_case_count -and [int]$selftest.endpoint_ownership_v2_false_green_count -eq 0 -and
    [int]$selftest.zero_cardinality_case_count -ge 13 -and [int]$selftest.zero_cardinality_pass_count -eq [int]$selftest.zero_cardinality_case_count -and
    [int]$selftest.zero_cardinality_false_green_count -eq 0 -and
    [int]$selftest.optional_property_case_count -ge 12 -and [int]$selftest.optional_property_pass_count -eq [int]$selftest.optional_property_case_count -and [int]$selftest.optional_property_false_green_count -eq 0 -and
    [int]$selftest.runtime_bridge_bootstrap_case_count -ge 16 -and [int]$selftest.runtime_bridge_bootstrap_pass_count -eq [int]$selftest.runtime_bridge_bootstrap_case_count -and [int]$selftest.runtime_bridge_bootstrap_false_green_count -eq 0 -and
    [int]$selftest.failure_cleanup_case_count -ge 12 -and [int]$selftest.failure_cleanup_pass_count -eq [int]$selftest.failure_cleanup_case_count -and [int]$selftest.failure_cleanup_false_green_count -eq 0 -and [int]$selftest.failure_cleanup_unrelated_termination_count -eq 0 -and
    [int]$selftest.powershell_parse_error_count -eq 0 -and
    [int]$selftest.startup_failure_stage_false_report_count -eq 0 -and [int]$selftest.startup_stall_false_green_count -eq 0
)
if (-not $selftestPass) { throw 'M9 runtime bridge tooling self-test is not an exact PASS.' }
$probeBReady = $false
$manifest = [ordered]@{
    schema='SpaceSyndicatePr90McpStartupToolingManifestV2'
    status='SEALED_FOR_AUTHORIZED_POST_REPAIR_M0_M11_PROBE'
    authorization_eligible=$false
    startup_probe_b_authorization_eligible=$probeBReady
    ready_for_new_exact_sha_mcp_authorization=$false
    authorization_id='PR90_MCP_ENDPOINT_OWNERSHIP_V2_POST_REPAIR_M9_RUNTIME_BRIDGE_HEARTBEAT_BOOTSTRAP_NEW_PROBE_CONTROLLER_AND_M0_M11_PROBE_AUTHORIZATION'
    authorized_post_repair_probe_id='pr90-mcp-endpoint-ownership-v2-post-repair-m0-m11-004'
    authorized_post_repair_probe_count=1
    authorized_new_probe_count=1
    new_probe_execution_count=$newProbeExecutionCount
    automatic_retry_allowed=$false
    created_at_utc=[DateTimeOffset]::UtcNow.ToString('o')
    product_head_sha=$ProductHeadSha
    product_tree_sha=$ProductTreeSha
    tooling_head_sha=$toolingHead
    tooling_tree_sha=$toolingTree
    base_tooling_head_sha=$baseToolingHead
    base_tooling_tree_sha=$baseToolingTree
    new_tooling_commit_count=$newToolingCommitCount
    frozen_failed_probe_id='pr90-mcp-endpoint-ownership-v2-post-repair-m0-m11-003'
    frozen_failed_probe_execution_count=1
    frozen_failed_probe_cumulative_execution_count=3
    frozen_failed_probe_tooling_head_sha='d7386e901f2d0f4fdf994f640f6e91b49d7d5ed8'
    frozen_failed_probe_tooling_tree_sha='7b756bb9f3039125e63d035d49eb5776ca60178a'
    frozen_failed_probe_failure_evidence_sha256='4a7ef49aa6ac64dd61b90ac51f32fa1938c78894b312f7b3c776c485e1a0f6f8'
    frozen_failed_probe_terminal_manifest_sha256='39138585999d6f5e403df1a897ef0163fe48964c22ab3f1a7a81730cbac2e689'
    frozen_failed_probe_result_sha256='2846a76ca673095b08c045875d921d0059034f78557a95fcf73ec9ad2072b5b8'
    frozen_failed_probe_attestation_sha256='d669b5fe0791e4ee1bf1cb1475417ee2a708db53741d07158647339e22818321'
    frozen_failed_probe_cleanup_sha256='39138585999d6f5e403df1a897ef0163fe48964c22ab3f1a7a81730cbac2e689'
    frozen_failed_probe_enter_play_mode_raw_sha256='85b67a9d08541358c69f4874835acd69a39aa974db53cb5444d6ad120a7141fd'
    frozen_failed_probe_get_runtime_events_raw_sha256='c6e306d57ca02c9d6644c3507db7ada7f1c8e79d87bc248b17a0e8fdae1f9825'
    frozen_failed_probe_exit_play_mode_raw_sha256='ffa160d30fa8b7c0cfb31e297c4fd08a9d8b1a345a0288641473d6b30d663eb7'
    frozen_failed_probe_watchdog_timeline_sha256='7e24b20197727a29706d31b51dcbccbafa4ab7e47041b59e923f319ee58908e7'
    frozen_failed_probe_watchdog_summary_sha256='f593ff7b56595fa11dd6e0034e8e54a7f57af4a5ed8608ca70e15c99eaf8eccb'
    m9_root_cause_class='TOOLING_MAIN_THREAD_RUNTIME_BOOTSTRAP_SCHEDULING_RACE'
    m9_root_cause_formally_attested=$true
    m9_root_cause_detail='enter_play_mode returned before the runtime bridge published state; the immediate synchronous get_runtime_events request blocked the editor main-thread poll loop for its full timeout.'
    runtime_bridge_ready_status_poll_before_event_bootstrap=$true
    runtime_bridge_ready_status_max_age_ms=3000
    runtime_bridge_status_poll_interval_ms=250
    runtime_bridge_bootstrap_requested_timeout_ms=10000
    runtime_bridge_m9_completion_margin_ms=2000
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
    endpoint_ownership_contract_version=2
    endpoint_ownership_v2_selftest_case_count=[int]$selftest.endpoint_ownership_v2_case_count
    endpoint_ownership_v2_selftest_pass_count=[int]$selftest.endpoint_ownership_v2_pass_count
    endpoint_ownership_v2_false_green_count=[int]$selftest.endpoint_ownership_v2_false_green_count
    zero_cardinality_selftest_case_count=[int]$selftest.zero_cardinality_case_count
    zero_cardinality_selftest_pass_count=[int]$selftest.zero_cardinality_pass_count
    zero_cardinality_false_green_count=[int]$selftest.zero_cardinality_false_green_count
    optional_property_selftest_case_count=[int]$selftest.optional_property_case_count
    optional_property_selftest_pass_count=[int]$selftest.optional_property_pass_count
    optional_property_false_green_count=[int]$selftest.optional_property_false_green_count
    runtime_bridge_bootstrap_selftest_case_count=[int]$selftest.runtime_bridge_bootstrap_case_count
    runtime_bridge_bootstrap_selftest_pass_count=[int]$selftest.runtime_bridge_bootstrap_pass_count
    runtime_bridge_bootstrap_false_green_count=[int]$selftest.runtime_bridge_bootstrap_false_green_count
    failure_cleanup_selftest_case_count=[int]$selftest.failure_cleanup_case_count
    failure_cleanup_selftest_pass_count=[int]$selftest.failure_cleanup_pass_count
    failure_cleanup_false_green_count=[int]$selftest.failure_cleanup_false_green_count
    failure_cleanup_unrelated_termination_count=[int]$selftest.failure_cleanup_unrelated_termination_count
    powershell_parse_error_count=[int]$selftest.powershell_parse_error_count
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
    post_repair_probe_execution_count=$newProbeExecutionCount
    post_repair_probe_m0_m11_green=$probePass
    endpoint_ownership_contract_v2_implemented=[bool]$probe.endpoint_ownership_contract_v2_implemented
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
    new_endpoint_ownership_v2_sha256=($files|Where-Object{$_.relative_path -ceq 'tools/pr90_mcp_endpoint_ownership_v2.psm1'}).sha256
    new_post_repair_probe_controller_sha256=($files|Where-Object{$_.relative_path -ceq 'tools/pr90_endpoint_ownership_v2_post_repair_probe.ps1'}).sha256
    canonical_payload_sha256=''
}
$manifest.canonical_payload_sha256 = Get-StartupCanonicalSha256 $manifest
Write-StartupImmutableJson -Path $OutputPath -Value $manifest -WriteSha256Sidecar | Out-Null
$manifest | ConvertTo-Json -Depth 100 -Compress
