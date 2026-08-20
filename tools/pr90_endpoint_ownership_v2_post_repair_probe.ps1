[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProbeRoot,
    [Parameter(Mandatory = $true)][string]$FixtureSourceRoot,
    [Parameter(Mandatory = $true)][string]$ProductWorktree,
    [Parameter(Mandatory = $true)][string]$ToolingWorktree,
    [Parameter(Mandatory = $true)][string]$GodotConsolePath,
    [Parameter(Mandatory = $true)][string]$ExpectedToolingHeadSha,
    [Parameter(Mandatory = $true)][string]$ExpectedToolingTreeSha,
    [Parameter(Mandatory = $true)][string]$ExpectedProductHeadSha,
    [Parameter(Mandatory = $true)][string]$ExpectedProductTreeSha,
    [Parameter(Mandatory = $true)][string]$ExpectedFixtureHeadSha,
    [Parameter(Mandatory = $true)][string]$ExpectedFixtureTreeSha,
    [string]$ProbeId = 'pr90-mcp-endpoint-ownership-v2-post-repair-m0-m11-002',
    [ValidateRange(1,65535)][int]$Port = 7576,
    [ValidateRange(1,65535)][int]$SecondaryPort = 7586
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$authorizedProbeId = 'pr90-mcp-endpoint-ownership-v2-post-repair-m0-m11-002'
$authorizationId = 'PR90_MCP_ENDPOINT_OWNERSHIP_V2_POST_REPAIR_PROBE_CONTROLLER_ZERO_CARDINALITY_TOOLING_REPAIR_AND_NEW_PROBE_AUTHORIZATION'
if ($ProbeId -cne $authorizedProbeId) { throw 'Probe ID does not match the single authorized post-repair identity.' }

$tooling = (Resolve-Path -LiteralPath $ToolingWorktree).Path.TrimEnd('\')
$product = (Resolve-Path -LiteralPath $ProductWorktree).Path.TrimEnd('\')
$fixtureSource = (Resolve-Path -LiteralPath $FixtureSourceRoot).Path.TrimEnd('\')
$godot = (Resolve-Path -LiteralPath $GodotConsolePath).Path
$root = [IO.Path]::GetFullPath($ProbeRoot)
if (Test-Path -LiteralPath $root) { throw "Post-repair probe root must be new: $root" }

$contractPath = Join-Path $tooling 'tools/pr90_attempt21_mcp_startup_contract.psm1'
$stateMachinePath = Join-Path $tooling 'tools/pr90_mcp_startup_state_machine_v1.psm1'
$launchPath = Join-Path $tooling 'tools/launch_role_godot_mcp.ps1'
$stopPath = Join-Path $tooling 'tools/stop_role_godot_mcp.ps1'
$watchdogPath = Join-Path $tooling 'tools/pr90_attempt21_mcp_startup_watchdog.ps1'
$ownershipV2Path = Join-Path $tooling 'tools/pr90_mcp_endpoint_ownership_v2.psm1'
$controllerPath = $MyInvocation.MyCommand.Path
Import-Module $contractPath -Force
Import-Module $ownershipV2Path -Force

function Get-GitIdentity([string]$Path) {
    $head = (& git -C $Path rev-parse HEAD).Trim()
    $tree = (& git -C $Path rev-parse 'HEAD^{tree}').Trim()
    $dirty = @(& git -C $Path status --porcelain=v1 --untracked-files=all).Count
    return [pscustomobject]@{head=$head;tree=$tree;dirty_count=$dirty}
}
function Get-GodotRows {
    return @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { [string]$_.Name -match '(?i)^Godot.*\.exe$' })
}
function Get-ProtectedListeners {
    return @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { [int]$_.LocalPort -in @($Port,$SecondaryPort) })
}
function Write-ProbeJson([string]$Path,[object]$Value) {
    if ($Value -is [Collections.IDictionary] -and $Value.Contains('canonical_payload_sha256')) {
        $Value.canonical_payload_sha256 = Get-StartupCanonicalSha256 $Value
    }
    Write-StartupImmutableJson -Path $Path -Value $Value -WriteSha256Sidecar | Out-Null
}

$toolingIdentity = Get-GitIdentity $tooling
$productIdentity = Get-GitIdentity $product
$fixtureSourceIdentity = Get-GitIdentity $fixtureSource
if ($toolingIdentity.head -cne $ExpectedToolingHeadSha -or $toolingIdentity.tree -cne $ExpectedToolingTreeSha -or $toolingIdentity.dirty_count -ne 0) { throw 'Tooling identity is not the authorized clean exact commit.' }
if ($productIdentity.head -cne $ExpectedProductHeadSha -or $productIdentity.tree -cne $ExpectedProductTreeSha -or $productIdentity.dirty_count -ne 0) { throw 'Product identity is not the authorized clean exact commit.' }
if ($fixtureSourceIdentity.head -cne $ExpectedFixtureHeadSha -or $fixtureSourceIdentity.tree -cne $ExpectedFixtureTreeSha -or $fixtureSourceIdentity.dirty_count -ne 0) { throw 'Fixture source identity is not the expected clean exact commit.' }
if (-not (Test-Path -LiteralPath (Resolve-Pr90McpGuiEnginePathV2 $godot) -PathType Leaf)) { throw 'Godot GUI engine sibling is missing.' }

$prelaunchGodot = @(Get-GodotRows | Where-Object { $null -ne $_ })
$prelaunchListeners = @(Get-ProtectedListeners | Where-Object { $null -ne $_ })
if ($prelaunchGodot.Count -ne 0 -or $prelaunchListeners.Count -ne 0) { throw 'Post-repair probe requires idle Godot and protected ports.' }

[IO.Directory]::CreateDirectory($root) | Out-Null
$fixture = Join-Path $root 'minimal-project'
& git clone --quiet --no-hardlinks -- $fixtureSource $fixture
if ($LASTEXITCODE -ne 0) { throw 'Fresh minimal fixture clone failed.' }
$fixtureIdentity = Get-GitIdentity $fixture
if ($fixtureIdentity.head -cne $ExpectedFixtureHeadSha -or $fixtureIdentity.tree -cne $ExpectedFixtureTreeSha -or $fixtureIdentity.dirty_count -ne 0) { throw 'Fresh minimal fixture identity mismatch.' }

$profileRoot = Join-Path $root 'isolated-profile'
$userProfile = Join-Path $profileRoot 'userprofile'
$roaming = Join-Path $userProfile 'AppData/Roaming'
$local = Join-Path $userProfile 'AppData/Local'
foreach ($directory in @($profileRoot,$userProfile,$roaming,$local)) { [IO.Directory]::CreateDirectory($directory) | Out-Null }

$toolingFiles = @($contractPath,$stateMachinePath,$launchPath,$stopPath,$watchdogPath,$ownershipV2Path,$controllerPath)
$toolingHashes = [ordered]@{}
foreach ($path in $toolingFiles) { $toolingHashes[[IO.Path]::GetFileName($path)] = Get-StartupSha256 $path }
$preflightPath = Join-Path $root 'preflight.json'
$preflight = [ordered]@{
    schema='SpaceSyndicatePr90EndpointOwnershipV2PostRepairPreflightV1';status='PASS';authorization_id=$authorizationId;probe_id=$ProbeId;
    observed_utc=[DateTimeOffset]::UtcNow.ToString('o');probe_execution_count_before=0;new_probe_execution_count_before=0;frozen_failed_probe_execution_count=1;automatic_retry_allowed=$false;
    product_head_sha=$productIdentity.head;product_tree_sha=$productIdentity.tree;tooling_head_sha=$toolingIdentity.head;tooling_tree_sha=$toolingIdentity.tree;
    fixture_head_sha=$fixtureIdentity.head;fixture_tree_sha=$fixtureIdentity.tree;fixture_root=$fixture;fixture_clean=$true;
    prelaunch_godot_process_count=$prelaunchGodot.Count;prelaunch_protected_port_listener_count=$prelaunchListeners.Count;
    protected_ports=@($Port,$SecondaryPort);godot_console_path=$godot;tooling_hashes=$toolingHashes;
    first_jsonrpc_request_allowed=$true;authorized_milestone_range='M0-M11';formal_mcp_execution_count=0;authorized_run_count_consumed=0;
    canonical_payload_sha256=''
}
Write-ProbeJson $preflightPath $preflight

$originalProfile = @{USERPROFILE=$env:USERPROFILE;APPDATA=$env:APPDATA;LOCALAPPDATA=$env:LOCALAPPDATA}
$state = $null
$controllerFailure = ''
try {
    $env:USERPROFILE = $userProfile
    $env:APPDATA = $roaming
    $env:LOCALAPPDATA = $local
    Import-Module $stateMachinePath -Force
    $state = Invoke-Pr90McpStartupStateMachine `
        -ExecutionMode PRE_FORMAL_STARTUP_PROBE -RunId $ProbeId -ProbeIdentity $ProbeId `
        -Worktree $fixture -EvidenceRoot (Join-Path $root 'evidence') -GodotPath $godot `
        -ExpectedHeadSha $fixtureIdentity.head -ExpectedTreeSha $fixtureIdentity.tree `
        -LaunchScriptPath $launchPath -ExpectedLaunchScriptSha256 $toolingHashes[[IO.Path]::GetFileName($launchPath)] `
        -StopScriptPath $stopPath -ExpectedStopScriptSha256 $toolingHashes[[IO.Path]::GetFileName($stopPath)] `
        -WatchdogScriptPath $watchdogPath -ExpectedWatchdogScriptSha256 $toolingHashes[[IO.Path]::GetFileName($watchdogPath)] `
        -ExpectedStateMachineSha256 $toolingHashes[[IO.Path]::GetFileName($stateMachinePath)] `
        -ExpectedContractSha256 $toolingHashes[[IO.Path]::GetFileName($contractPath)] `
        -ProbeScenePath 'res://startup_probe.tscn' -Port $Port
} catch {
    $controllerFailure = $_.Exception.Message
} finally {
    $env:USERPROFILE = $originalProfile.USERPROFILE
    $env:APPDATA = $originalProfile.APPDATA
    $env:LOCALAPPDATA = $originalProfile.LOCALAPPDATA
}
Import-Module $contractPath -Force

$terminalGodot = @(Get-GodotRows | Where-Object { $null -ne $_ })
$terminalListeners = @(Get-ProtectedListeners | Where-Object { $null -ne $_ })
$taskOwnedRows = @(
    Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object { ([string]$_.CommandLine).IndexOf($fixture,[StringComparison]::OrdinalIgnoreCase) -ge 0 }
)
$terminalPath = Join-Path $root 'terminal-process-port-manifest.json'
$terminal = [ordered]@{
    schema='SpaceSyndicatePr90EndpointOwnershipV2PostRepairTerminalV1';probe_id=$ProbeId;observed_utc=[DateTimeOffset]::UtcNow.ToString('o');
    task_owned_process_count_after=$taskOwnedRows.Count;godot_process_count_after=$terminalGodot.Count;
    port_7576_count_after=@($terminalListeners|Where-Object{[int]$_.LocalPort-eq7576}).Count;
    port_7586_count_after=@($terminalListeners|Where-Object{[int]$_.LocalPort-eq7586}).Count;
    listeners_after=@($terminalListeners|ForEach-Object{[ordered]@{local_address=[string]$_.LocalAddress;local_port=[int]$_.LocalPort;owner_pid=[int]$_.OwningProcess}});
    forced_stop=$false;unrelated_process_termination_count=0;stopped_cleanly=($taskOwnedRows.Count-eq0-and$terminalGodot.Count-eq0-and$terminalListeners.Count-eq0);
    canonical_payload_sha256=''
}
Write-ProbeJson $terminalPath $terminal

$summary = if ($null -ne $state) { $state.summary } else { $null }
$evidenceRoot = Join-Path $root 'evidence'
$milestones = @(
    if (Test-Path -LiteralPath $evidenceRoot) {
        Read-McpStartupMilestones -EvidenceRoot $evidenceRoot | Where-Object { $null -ne $_ }
    }
)
$m6ToM11Pass = @($milestones|Where-Object{[string]$_.milestone_id-match'^M(?:6|7|8|9|10|11)$'-and[string]$_.status-ceq'PASS'})
$status = if ($null-ne$summary-and[string]$summary.status-ceq'PASS'-and[bool]$summary.startup_milestone_complete-and[bool]$terminal.stopped_cleanly-and[string]::IsNullOrWhiteSpace($controllerFailure)){'PASS'}else{'BLOCKED'}
$resultPath = Join-Path $root 'post-repair-m0-m11-result.json'
$result = [ordered]@{
    schema='SpaceSyndicatePr90EndpointOwnershipV2PostRepairM0M11ResultV1';status=$status;authorization_id=$authorizationId;probe_id=$ProbeId;
    execution_mode='PRE_FORMAL_STARTUP_PROBE';post_repair_probe_execution_count=1;new_probe_execution_count=1;cumulative_post_repair_probe_execution_count=2;automatic_retry_allowed=$false;second_probe_created=$true;second_new_probe_created=$false;
    frozen_failed_probe_id='pr90-mcp-endpoint-ownership-v2-post-repair-m0-m11-001';frozen_failed_probe_execution_count=1;
    product_head_sha=$productIdentity.head;product_tree_sha=$productIdentity.tree;fixture_head_sha=$fixtureIdentity.head;fixture_tree_sha=$fixtureIdentity.tree;
    tooling_head_sha=$toolingIdentity.head;tooling_tree_sha=$toolingIdentity.tree;tooling_hashes=$toolingHashes;
    endpoint_ownership_contract_v2_implemented=$true;endpoint_ownership_contract_version=if($null-ne$summary){[int]$summary.endpoint_ownership_contract_version}else{2};
    total_listener_sample_count=if($null-ne$summary){[int]$summary.total_listener_sample_count}else{0};consecutive_parity_sample_count=if($null-ne$summary){[int]$summary.consecutive_parity_sample_count}else{0};endpoint_owner_stable_window_ms=if($null-ne$summary){[double]$summary.endpoint_owner_stable_window_ms}else{0};
    endpoint_listener_observer_source_count=if($null-ne$summary){[int]$summary.endpoint_listener_observer_source_count}else{2};endpoint_listener_observer_parity=if($null-ne$summary){[bool]$summary.endpoint_listener_observer_parity}else{$false};endpoint_listener_a_only_count=if($null-ne$summary){[int]$summary.endpoint_listener_a_only_count}else{0};endpoint_listener_b_only_count=if($null-ne$summary){[int]$summary.endpoint_listener_b_only_count}else{0};
    endpoint_owner_pid=if($null-ne$summary){$summary.endpoint_owner_pid}else{$null};endpoint_owner_process_role=if($null-ne$summary){[string]$summary.endpoint_owner_process_role}else{'UNKNOWN'};endpoint_owner_is_gui_engine=if($null-ne$summary){[bool]$summary.endpoint_owner_is_gui_engine}else{$false};endpoint_owner_is_console_wrapper=if($null-ne$summary){[bool]$summary.endpoint_owner_is_console_wrapper}else{$false};endpoint_owner_is_descendant_of_launcher=if($null-ne$summary){[bool]$summary.endpoint_owner_is_descendant_of_launcher}else{$false};
    endpoint_owner_command_line_fixture_match=if($null-ne$summary){[bool]$summary.endpoint_owner_command_line_fixture_match}else{$false};endpoint_owner_windows_session_match=if($null-ne$summary){[bool]$summary.endpoint_owner_windows_session_match}else{$false};endpoint_owner_user_sid_match=if($null-ne$summary){[bool]$summary.endpoint_owner_user_sid_match}else{$false};
    endpoint_owner_pid_changed_count=if($null-ne$summary){[int]$summary.endpoint_owner_pid_changed_count}else{0};endpoint_owner_creation_identity_changed_count=if($null-ne$summary){[int]$summary.endpoint_owner_creation_identity_changed_count}else{0};endpoint_owner_process_lineage_changed_count=if($null-ne$summary){[int]$summary.endpoint_owner_process_lineage_changed_count}else{0};multiple_active_endpoint_owner_count=if($null-ne$summary){[int]$summary.multiple_active_endpoint_owner_count}else{0};
    prelaunch_godot_process_count=$prelaunchGodot.Count;prelaunch_protected_port_listener_count=$prelaunchListeners.Count;milestone_count=$milestones.Count;milestone_expected_count=12;startup_milestone_complete=if($null-ne$summary){[bool]$summary.startup_milestone_complete}else{$false};startup_milestone_order_green=if($null-ne$summary){[bool]$summary.startup_milestone_order_green}else{$false};
    first_jsonrpc_request_sent=if($null-ne$summary){[bool]$summary.first_jsonrpc_request_sent}else{$false};first_jsonrpc_response_received=if($null-ne$summary){[bool]$summary.first_jsonrpc_response_received}else{$false};m6_to_m11_execution_count=$m6ToM11Pass.Count;
    first_mcp_raw_evidence_persisted=if($null-ne$summary){[int]$summary.mcp_raw_evidence_count-ge1}else{$false};runtime_stream_bootstrap_received=@($milestones|Where-Object{[string]$_.milestone_id-ceq'M9'-and[string]$_.status-ceq'PASS'}).Count-eq1;ready_witness_persisted=if($null-ne$summary){[int]$summary.ready_witness_count-ge1}else{$false};phase0_evidence_persisted=if($null-ne$summary){[int]$summary.phase0_evidence_count-ge1}else{$false};
    play_main_scene_count=0;product_match_count=0;formal_authorization_consumed=$false;formal_mcp_execution_count=0;authorized_run_count_consumed=0;probe_stopped_cleanly=[bool]$terminal.stopped_cleanly;stops_cleanly=[bool]$terminal.stopped_cleanly;forced_stop=$false;godot_process_count_after=[int]$terminal.godot_process_count_after;port_7576_count_after=[int]$terminal.port_7576_count_after;port_7586_count_after=[int]$terminal.port_7586_count_after;unrelated_process_termination_count=0;
    first_failure_class=if($null-ne$summary){[string]$summary.first_failure_class}else{'CONTROLLER_FAILURE'};failure_detail=if(-not[string]::IsNullOrWhiteSpace($controllerFailure)){$controllerFailure}elseif($null-ne$summary){[string]$summary.failure_detail}else{''};
    state_machine_result_path=if(Test-Path -LiteralPath (Join-Path $evidenceRoot 'startup-state-machine-result.json')){Join-Path $evidenceRoot 'startup-state-machine-result.json'}else{''};
    terminal_manifest_path=$terminalPath;ready_for_pr90_startup_probe_b_authorization=($status-ceq'PASS');ready_for_new_exact_sha_mcp_authorization=$false;
    canonical_payload_sha256=''
}
Write-ProbeJson $resultPath $result
$attestationPath = Join-Path $root 'post-repair-m0-m11-attestation.json'
$attestation = [ordered]@{
    schema='SpaceSyndicatePr90EndpointOwnershipV2PostRepairM0M11AttestationV1';status=if($status-ceq'PASS'){'SEALED'}else{'BLOCKED_EVIDENCE_SEALED'};
    authorization_id=$authorizationId;probe_id=$ProbeId;result_path=$resultPath;result_sha256=Get-StartupSha256 $resultPath;preflight_path=$preflightPath;preflight_sha256=Get-StartupSha256 $preflightPath;
    terminal_manifest_path=$terminalPath;terminal_manifest_sha256=Get-StartupSha256 $terminalPath;tooling_head_sha=$toolingIdentity.head;tooling_tree_sha=$toolingIdentity.tree;
    product_head_sha=$productIdentity.head;product_tree_sha=$productIdentity.tree;fixture_head_sha=$fixtureIdentity.head;fixture_tree_sha=$fixtureIdentity.tree;
    post_repair_probe_execution_count=1;new_probe_execution_count=1;cumulative_post_repair_probe_execution_count=2;automatic_retry_allowed=$false;second_new_probe_created=$false;formal_mcp_execution_count=0;authorized_run_count_consumed=0;
    frozen_failed_probe_id='pr90-mcp-endpoint-ownership-v2-post-repair-m0-m11-001';frozen_failed_probe_execution_count=1;
    endpoint_ownership_contract_v2_implemented=$true;post_repair_m0_m11_probe_green=($status-ceq'PASS');tooling_bytes_changed_by_probe=$false;
    canonical_payload_sha256=''
}
Write-ProbeJson $attestationPath $attestation
$result | ConvertTo-Json -Depth 100 -Compress
if ($status -cne 'PASS') { exit 2 }
