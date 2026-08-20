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
$baseToolingHead = '073b3c3d92de7d17086cc4d40c06f1ef8d13b811'
$baseToolingTree = 'cecabaadf5bdb4b79234bd1b31586a89742ddb54'
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
$newProbeEvidence = ([string]$probe.probe_id -ceq 'pr90-mcp-endpoint-ownership-v2-post-repair-m0-m11-002')
$newProbeExecutionCount = if ($newProbeEvidence) { [int]$probe.post_repair_probe_execution_count } else { 0 }
$probePass = (
    [string]$probe.status -ceq 'PASS' -and $newProbeEvidence -and [int]$probe.post_repair_probe_execution_count -eq 1 -and
    [int]$probe.new_probe_execution_count -eq 1 -and -not [bool]$probe.automatic_retry_allowed -and -not [bool]$probe.second_new_probe_created -and
    [int]$probe.milestone_count -eq 12 -and [bool]$probe.startup_milestone_complete -and [bool]$probe.startup_milestone_order_green -and [bool]$probe.stops_cleanly -and
    [bool]$probe.endpoint_ownership_contract_v2_implemented -and [int]$probe.endpoint_ownership_contract_version -eq 2 -and
    [int]$probe.total_listener_sample_count -ge 5 -and [int]$probe.consecutive_parity_sample_count -ge 3 -and [double]$probe.endpoint_owner_stable_window_ms -ge 1000 -and
    [int]$probe.endpoint_listener_observer_source_count -eq 2 -and [bool]$probe.endpoint_listener_observer_parity -and [int]$probe.endpoint_listener_a_only_count -eq 0 -and [int]$probe.endpoint_listener_b_only_count -eq 0 -and
    [bool]$probe.endpoint_owner_is_gui_engine -and -not [bool]$probe.endpoint_owner_is_console_wrapper -and [bool]$probe.endpoint_owner_is_descendant_of_launcher -and
    [bool]$probe.endpoint_owner_command_line_fixture_match -and [bool]$probe.endpoint_owner_windows_session_match -and [bool]$probe.endpoint_owner_user_sid_match -and
    [int]$probe.endpoint_owner_pid_changed_count -eq 0 -and [int]$probe.endpoint_owner_creation_identity_changed_count -eq 0 -and [int]$probe.endpoint_owner_process_lineage_changed_count -eq 0 -and
    [int]$probe.multiple_active_endpoint_owner_count -eq 0 -and [int]$probe.prelaunch_godot_process_count -eq 0 -and [int]$probe.prelaunch_protected_port_listener_count -eq 0 -and
    [bool]$probe.first_jsonrpc_request_sent -and [bool]$probe.first_jsonrpc_response_received -and [int]$probe.m6_to_m11_execution_count -eq 6 -and
    [bool]$probe.first_mcp_raw_evidence_persisted -and [bool]$probe.runtime_stream_bootstrap_received -and [bool]$probe.ready_witness_persisted -and [bool]$probe.phase0_evidence_persisted -and
    [int]$probe.play_main_scene_count -eq 0 -and [int]$probe.product_match_count -eq 0 -and [int]$probe.formal_mcp_execution_count -eq 0 -and [int]$probe.authorized_run_count_consumed -eq 0 -and
    -not [bool]$probe.forced_stop -and [int]$probe.godot_process_count_after -eq 0 -and [int]$probe.port_7576_count_after -eq 0 -and [int]$probe.port_7586_count_after -eq 0 -and [int]$probe.unrelated_process_termination_count -eq 0
)
$selftestPass = (
    [string]$selftest.status -ceq 'PASS' -and [int]$selftest.case_count -ge 60 -and [int]$selftest.pass_count -eq [int]$selftest.case_count -and
    [int]$selftest.endpoint_ownership_contract_version -eq 2 -and [int]$selftest.endpoint_ownership_v2_case_count -ge 15 -and
    [int]$selftest.endpoint_ownership_v2_pass_count -eq [int]$selftest.endpoint_ownership_v2_case_count -and [int]$selftest.endpoint_ownership_v2_false_green_count -eq 0 -and
    [int]$selftest.zero_cardinality_case_count -ge 13 -and [int]$selftest.zero_cardinality_pass_count -eq [int]$selftest.zero_cardinality_case_count -and
    [int]$selftest.zero_cardinality_false_green_count -eq 0 -and [int]$selftest.powershell_parse_error_count -eq 0 -and
    [int]$selftest.startup_failure_stage_false_report_count -eq 0 -and [int]$selftest.startup_stall_false_green_count -eq 0
)
$probeBReady = ($probePass -and $selftestPass)
$manifest = [ordered]@{
    schema='SpaceSyndicatePr90McpStartupToolingManifestV2'
    status=if($probeBReady){'READY_FOR_PR90_STARTUP_PROBE_B_AUTHORIZATION'}else{'BLOCKED_PENDING_NEW_POST_REPAIR_M0_M11_PROBE'}
    authorization_eligible=$false
    startup_probe_b_authorization_eligible=$probeBReady
    ready_for_new_exact_sha_mcp_authorization=$false
    authorization_id='PR90_MCP_ENDPOINT_OWNERSHIP_V2_POST_REPAIR_PROBE_CONTROLLER_ZERO_CARDINALITY_TOOLING_REPAIR_AND_NEW_PROBE_AUTHORIZATION'
    authorized_post_repair_probe_id='pr90-mcp-endpoint-ownership-v2-post-repair-m0-m11-002'
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
    frozen_failed_probe_id='pr90-mcp-endpoint-ownership-v2-post-repair-m0-m11-001'
    frozen_failed_probe_execution_count=1
    frozen_failed_probe_failure_evidence_sha256='428d2bb920d03f028fe1b87f2d8d3dda3ff515e842ee98a03019a0a943827d47'
    frozen_failed_probe_terminal_manifest_sha256='d576d29aeedf4752c30cb1b4e6b3a2e615f00e16eb6dc54de18eb30a2563c64c'
    frozen_failed_probe_result_sha256='3e8966fe1f37f505850b5017806861dd979dff4c65f5e8c9a28ade63df109e6c'
    frozen_failed_probe_attestation_sha256='8847a47a7ef1d342705c06eaaee58b8a8ff982dc044a68d4daaa5c1cb9a1dd13'
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
