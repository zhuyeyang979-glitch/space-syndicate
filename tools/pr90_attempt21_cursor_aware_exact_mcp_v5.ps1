[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateSet('PRE_FORMAL_EXACT_MCP_DRY_RUN','FORMAL_EXACT_SHA_MCP')][string]$ExecutionMode,
    [Parameter(Mandatory = $true)][string]$RunId,
    [Parameter(Mandatory = $true)][string]$Worktree,
    [Parameter(Mandatory = $true)][string]$EvidenceRoot,
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [Parameter(Mandatory = $true)][string]$ExpectedHeadSha,
    [Parameter(Mandatory = $true)][string]$ExpectedTreeSha,
    [Parameter(Mandatory = $true)][string]$LaunchScriptPath,
    [Parameter(Mandatory = $true)][string]$ExpectedLaunchScriptSha256,
    [Parameter(Mandatory = $true)][string]$StopScriptPath,
    [Parameter(Mandatory = $true)][string]$ExpectedStopScriptSha256,
    [Parameter(Mandatory = $true)][string]$WatchdogScriptPath,
    [Parameter(Mandatory = $true)][string]$ExpectedWatchdogScriptSha256,
    [Parameter(Mandatory = $true)][string]$StateMachineScriptPath,
    [Parameter(Mandatory = $true)][string]$ExpectedStateMachineSha256,
    [Parameter(Mandatory = $true)][string]$ContractScriptPath,
    [Parameter(Mandatory = $true)][string]$ExpectedContractSha256,
    [string]$SealedBaselinePath = '',
    [string]$ExpectedSealedBaselineSha256 = '',
    [string]$StartupToolingManifestPath = '',
    [string]$ExpectedStartupToolingManifestSha256 = '',
    [string]$StartupToolingSealPath = '',
    [string]$ExpectedStartupToolingSealSha256 = '',
    [string]$FormalAuthorizationValidationReceiptPath = '',
    [string]$ExpectedFormalAuthorizationValidationReceiptSha256 = '',
    [switch]$AllowFormalContinuation,
    [ValidateRange(1,65535)][int]$Port = 7576
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Resolve-Path -LiteralPath $StateMachineScriptPath).Path -Force
Import-Module (Resolve-Path -LiteralPath $ContractScriptPath).Path -Force

if ($ExecutionMode -ceq 'FORMAL_EXACT_SHA_MCP' -and -not $AllowFormalContinuation) {
    throw 'Formal v5 continuation requires explicit AllowFormalContinuation; dry-run never crosses play_main_scene.'
}
if ($ExecutionMode -ceq 'FORMAL_EXACT_SHA_MCP' -and [string]::IsNullOrWhiteSpace($FormalAuthorizationValidationReceiptPath)) {
    throw 'Formal v5 requires a separately sealed unconsumed authorization validation receipt.'
}

$state = Invoke-Pr90McpStartupStateMachine `
    -ExecutionMode $ExecutionMode `
    -RunId $RunId `
    -ProbeIdentity 'pr90-attempt21-v5-cursor-runbook' `
    -Worktree $Worktree `
    -EvidenceRoot $EvidenceRoot `
    -GodotPath $GodotPath `
    -ExpectedHeadSha $ExpectedHeadSha `
    -ExpectedTreeSha $ExpectedTreeSha `
    -LaunchScriptPath $LaunchScriptPath `
    -ExpectedLaunchScriptSha256 $ExpectedLaunchScriptSha256 `
    -StopScriptPath $StopScriptPath `
    -ExpectedStopScriptSha256 $ExpectedStopScriptSha256 `
    -WatchdogScriptPath $WatchdogScriptPath `
    -ExpectedWatchdogScriptSha256 $ExpectedWatchdogScriptSha256 `
    -ExpectedStateMachineSha256 $ExpectedStateMachineSha256 `
    -ExpectedContractSha256 $ExpectedContractSha256 `
    -SealedBaselinePath $SealedBaselinePath `
    -ExpectedSealedBaselineSha256 $ExpectedSealedBaselineSha256 `
    -StartupToolingManifestPath $StartupToolingManifestPath `
    -ExpectedStartupToolingManifestSha256 $ExpectedStartupToolingManifestSha256 `
    -StartupToolingSealPath $StartupToolingSealPath `
    -ExpectedStartupToolingSealSha256 $ExpectedStartupToolingSealSha256 `
    -FormalAuthorizationValidationReceiptPath $FormalAuthorizationValidationReceiptPath `
    -ExpectedFormalAuthorizationValidationReceiptSha256 $ExpectedFormalAuthorizationValidationReceiptSha256 `
    -Port $Port `
    -KeepRunningAfterM11:($ExecutionMode -ceq 'FORMAL_EXACT_SHA_MCP')

if ([string]$state.summary.status -cne 'PASS') {
    $state.summary | ConvertTo-Json -Depth 100 -Compress
    exit 2
}
if ($ExecutionMode -ceq 'PRE_FORMAL_EXACT_MCP_DRY_RUN') {
    $state.summary | ConvertTo-Json -Depth 100 -Compress
    exit 0
}

$root = (Resolve-Path -LiteralPath $Worktree).Path.TrimEnd('\')
$invokeScript = Join-Path $root 'tools/invoke_role_godot_mcp.ps1'
$callIndex = 1000
$streamId = [string]$state.stream_id
$cursor = [int64]$state.cursor_after
$allEvents = [Collections.Generic.List[object]]::new()
$readyWitnesses = [Collections.Generic.List[object]]::new()
$pollCount = 0
$primaryFailure = $null

function Get-FormalStructured {
    param([object]$Response)
    if ($null -eq $Response.result.structuredContent) { throw 'MCP response has no structuredContent.' }
    return $Response.result.structuredContent
}

function Invoke-FormalMcp {
    param([string]$ToolName, [hashtable]$Arguments = @{}, [int]$TimeoutSeconds = 60)
    $script:callIndex += 1
    $raw = Join-Path $EvidenceRoot ('mcp-raw/{0:D4}-{1}.jsonrpc.json' -f $script:callIndex,$ToolName)
    $json = $Arguments | ConvertTo-Json -Depth 40 -Compress
    $output = @(& pwsh -NoProfile -File $script:invokeScript -Worktree $root -ToolName $ToolName -ArgumentsJson $json -TimeoutSeconds $TimeoutSeconds -RawResponsePath $raw 2>&1)
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $raw)) { throw "Formal v5 MCP call $ToolName failed: $($output -join ' ')" }
    return Get-Content -Raw -LiteralPath $raw | ConvertFrom-Json -Depth 100
}

function Test-FormalPageContract {
    param([object]$Page, [string]$ExpectedStream, [int64]$ExpectedCursor)
    $events = @($Page.events); $issues = [Collections.Generic.List[string]]::new()
    if ([string]$Page.stream_id -cne $ExpectedStream) { $issues.Add('stream_changed') }
    if ([string]$Page.event_sequence_mode -cne 'cursor') { $issues.Add('not_cursor') }
    if (-not [bool]$Page.event_sequence_complete) { $issues.Add('incomplete') }
    if ([string]$Page.continuity_status -cne 'CONTIGUOUS') { $issues.Add('continuity') }
    if ([int]$Page.event_sequence_gap_count -ne 0) { $issues.Add('gap') }
    if ([int]$Page.event_sequence_invalid_count -ne 0) { $issues.Add('invalid') }
    if ([bool]$Page.client_truncated) { $issues.Add('client_truncated') }
    if (-not [bool]$Page.success) { $issues.Add('failed') }
    $expected = $ExpectedCursor + 1
    foreach ($event in $events) {
        if ([int64]$event.event_sequence -ne $expected) { $issues.Add('event_order') }
        if ([string]$event.stream_id -cne $ExpectedStream) { $issues.Add('event_stream') }
        if ([string]$event.kind -ceq 'ready') {
            if ([string]$event.message -cne 'Runtime bridge ready.') { $issues.Add('ready_message') }
            $readyWitnesses.Add($event)
        } elseif ([string]$event.kind -ceq 'command') {
            if ([string]$event.message -notmatch ': success$') { $issues.Add('failed_command') }
        } else { $issues.Add('unexpected_event_kind') }
        $allEvents.Add($event); $expected += 1
    }
    return [pscustomobject]@{green=$issues.Count -eq 0;issues=@($issues);events=$events}
}

function Poll-FormalCursor {
    param([string]$Phase)
    $payload = Get-FormalStructured (Invoke-FormalMcp -ToolName 'get_runtime_events' -Arguments @{max_events=100;timeout_msec=10000;stream_id=$streamId;since_sequence=$cursor} -TimeoutSeconds 60)
    $result = $payload.result
    $check = Test-FormalPageContract -Page $result -ExpectedStream $streamId -ExpectedCursor $cursor
    if (-not $check.green -or [bool]$result.event_window_overflowed) { throw "Formal cursor phase $Phase failed: $($check.issues -join ',')" }
    if (@($check.events).Count -gt 0) { $script:cursor = [int64]$check.events[-1].event_sequence }
    $script:pollCount += 1
    $phasePath = Join-Path $EvidenceRoot ("phases/{0:D3}-$Phase.json" -f $script:pollCount)
    $phaseRow = [ordered]@{schema='SpaceSyndicateCursorPhaseWitnessV5';run_id=$RunId;phase=$Phase;poll_index=$script:pollCount;stream_id=$streamId;cursor_after=$cursor;event_count=@($check.events).Count;event_sequence_complete=[bool]$result.event_sequence_complete;continuity_status=[string]$result.continuity_status;events=@($check.events)}
    if (-not (Test-Path -LiteralPath $phasePath)) { Write-StartupImmutableJson -Path $phasePath -Value $phaseRow -WriteSha256Sidecar | Out-Null }
    return $result
}

function Get-FormalNode {
    param([string]$Path, [string[]]$Properties=@())
    $payload = Get-FormalStructured (Invoke-FormalMcp -ToolName 'query_runtime_node' -Arguments @{node_path=$Path;properties=@($Properties);include_children=$false;timeout_msec=30000} -TimeoutSeconds 45)
    if (-not [bool]$payload.success -or -not [bool]$payload.result.found) { throw "Runtime node missing: $Path" }
    return $payload.result
}

function Get-FormalProperty {
    param([string]$Path, [string]$Name)
    return (Get-FormalNode -Path $Path -Properties @($Name)).requested_properties.$Name
}

function Get-FormalCenter {
    param([string]$Path)
    $node = Get-FormalNode -Path $Path -Properties @('disabled')
    return @{x=([double]$node.properties.global_position.x + [double]$node.properties.size.x / 2.0);y=([double]$node.properties.global_position.y + [double]$node.properties.size.y / 2.0)}
}

function Send-FormalTaps {
    param([hashtable[]]$Centers)
    $events = @($Centers | ForEach-Object { @{type='mouse_button';button='left';position=$_;mode='tap'} })
    $payload = Get-FormalStructured (Invoke-FormalMcp -ToolName 'send_runtime_input' -Arguments @{events=$events;timeout_msec=60000} -TimeoutSeconds 60)
    if (-not [bool]$payload.success) { throw 'Formal runtime input failed.' }
}

try {
    $null = Invoke-FormalMcp -ToolName 'exit_play_mode' -Arguments @{} -TimeoutSeconds 30
    $null = Invoke-FormalMcp -ToolName 'play_main_scene' -Arguments @{} -TimeoutSeconds 60
    $null = Invoke-FormalMcp -ToolName 'wait_msec' -Arguments @{duration=2000} -TimeoutSeconds 30
    Poll-FormalCursor -Phase 'phase-1-main-scene' | Out-Null
    $rootNode = Get-FormalNode -Path 'current_scene'
    if ([string]$rootNode.scene_file_path -cne 'res://scenes/main.tscn') { throw 'Formal v5 main-scene identity mismatch.' }
    $initial = Get-FormalProperty -Path 'V075GameScreen' -Name 'acceptance_state'
    $startCenter = Get-FormalCenter 'V075GameScreen/OverlayLayer/StartOverlay/Center/Panel/Margin/Rows/PlayerButtons/V074SettingsStack/StartConfiguredButton'
    Send-FormalTaps @($startCenter)
    $null = Invoke-FormalMcp -ToolName 'wait_msec' -Arguments @{duration=500} -TimeoutSeconds 30
    Poll-FormalCursor -Phase 'phase-2-new-game' | Out-Null
    $rootNode = Get-FormalNode -Path 'V075GameScreen/RootMargin' -Properties @()
    $scrollCenter = @{x=([double]$rootNode.properties.global_position.x + [double]$rootNode.properties.size.x / 2.0);y=([double]$rootNode.properties.global_position.y + [double]$rootNode.properties.size.y / 2.0)}
    $wheel = @(1..20 | ForEach-Object { @{type='mouse_button';button='wheel_down';position=$scrollCenter;mode='tap'} })
    $wheelPayload = Get-FormalStructured (Invoke-FormalMcp -ToolName 'send_runtime_input' -Arguments @{events=$wheel;timeout_msec=60000} -TimeoutSeconds 60)
    if (-not [bool]$wheelPayload.success) { throw 'Formal v5 scroll input failed.' }
    $lockCenter = Get-FormalCenter 'V075GameScreen/RootMargin/Shell/DockPanel/DockMargin/DockRows/CommandRow/LockButton'
    $finishCenter = Get-FormalCenter 'V075GameScreen/RootMargin/Shell/DockPanel/DockMargin/DockRows/CommandRow/FinishMaintenanceButton'
    Poll-FormalCursor -Phase 'phase-3-early-match' | Out-Null
    $settled = $false; $acceptance = $initial
    for ($batch=0; $batch -lt 32; $batch += 1) {
        Send-FormalTaps @($lockCenter,$finishCenter)
        $null = Invoke-FormalMcp -ToolName 'wait_msec' -Arguments @{duration=300} -TimeoutSeconds 30
        $acceptance = Get-FormalProperty -Path 'V075GameScreen' -Name 'acceptance_state'
        $phase = if($batch -lt 4){'phase-3-early-match'}elseif($batch -lt 8){'phase-4-mid-match'}elseif($batch -lt 12){'phase-5-combat-facility'}elseif($batch -lt 16){'phase-6-victory'}else{'phase-7-settlement'}
        Poll-FormalCursor -Phase "$phase-batch-$batch" | Out-Null
        if ([bool]$acceptance.match_completed -and [bool]$acceptance.settlement_visible) { $settled = $true; break }
    }
    if (-not $settled) { throw 'Formal v5 natural UI match did not settle within 32 batches.' }
    $debug = $acceptance.runtime_acceptance_debug; $presentation = $debug.combat_presentation; $wrapper = $acceptance.combat_wrapper; $surface = $wrapper.surface
    $requiredEdges = [int]$wrapper.presentation_shared_consumer_count + [int]$wrapper.presentation_signal_connection_count + [int]$wrapper.presentation_source_bind_count
    $legacyEdges = [int]$wrapper.presentation_local_preview_consumer_count
    $duplicateEdges = [Math]::Max(0,[int]$wrapper.presentation_signal_connection_count-1) + [Math]::Max(0,[int]$wrapper.presentation_source_bind_count-1)
    $green = [bool]$acceptance.match_completed -and [bool]$acceptance.settlement_visible -and [int]$debug.final_settlement_count -eq 1 -and [int]$debug.duplicate_settlement_count -eq 0 -and [int]$presentation.applied_receipt_count -gt 0 -and [int]$presentation.collision_receipt_count -eq 0 -and [int]$presentation.duplicate_receipt_count -eq 0 -and [int]$presentation.rejected_receipt_count -eq 0 -and $requiredEdges -eq 3 -and $legacyEdges -eq 0 -and $duplicateEdges -eq 0 -and [int]$debug.runtime_error_count -eq 0 -and [int]$debug.hidden_info_violation_count -eq 0 -and [int]$debug.invalid_action_count -eq 0 -and [int]$debug.nonfinite_count -eq 0 -and [int]$surface.presentation_cue_collision_count -eq 0 -and [int]$surface.presentation_cue_duplicate_count -eq 0
    if (-not $green) { throw 'Formal v5 production acceptance/presentation gate failed.' }
    Poll-FormalCursor -Phase 'phase-7-final-settlement' | Out-Null
    if ($pollCount -le 8) { throw 'Formal v5 cursor polling count is insufficient.' }
    $formalResult = [ordered]@{schema='SpaceSyndicateCursorAwareExactMcpResultV5';run_id=$RunId;status='PASS';head_sha=$ExpectedHeadSha;tree_sha=$ExpectedTreeSha;startup_milestones=12;startup_raw_count=@(Get-ChildItem -LiteralPath (Join-Path $EvidenceRoot 'mcp-raw') -File -ErrorAction SilentlyContinue).Count;startup_phase0_count=1;stream_id=$streamId;stream_id_stable=$true;ready_witness_count=@($readyWitnesses).Count;formal_event_poll_count=$pollCount;natural_match_reached_settled=$true;final_settlement_count=[int]$debug.final_settlement_count;presentation_receipt_count=[int]$presentation.applied_receipt_count;presentation_collision_count=[int]$presentation.collision_receipt_count;duplicate_presentation_effect_count=([int]$presentation.duplicate_receipt_count+[int]$surface.presentation_cue_duplicate_count);required_presentation_edge_count=$requiredEdges;legacy_presentation_edge_count=$legacyEdges;duplicate_presentation_edge_count=$duplicateEdges;runtime_error_count=[int]$debug.runtime_error_count;hidden_info_violation_count=[int]$debug.hidden_info_violation_count;invalid_action_count=[int]$debug.invalid_action_count;nonfinite_count=[int]$debug.nonfinite_count;duplicate_settlement_count=[int]$debug.duplicate_settlement_count;canonical_payload_sha256=''}
    $formalResult.canonical_payload_sha256 = Get-StartupCanonicalSha256 $formalResult
    Write-StartupImmutableJson -Path (Join-Path $EvidenceRoot 'exact-sha-mcp-result.json') -Value $formalResult -WriteSha256Sidecar | Out-Null
} catch {
    $primaryFailure = $_
    $failure = [ordered]@{schema='SpaceSyndicateCursorAwareExactMcpFailureV5';run_id=$RunId;failed_at_utc=[DateTimeOffset]::UtcNow.ToString('o');message=$_.Exception.Message;head_sha=$ExpectedHeadSha;tree_sha=$ExpectedTreeSha;cursor=$cursor;stream_id=$streamId;startup_state_machine_result=$state.summary;disposable_clone_disposition='PRESERVED_FOR_FORENSICS';canonical_payload_sha256=''}
    $failure.canonical_payload_sha256 = Get-StartupCanonicalSha256 $failure
    Write-StartupImmutableJson -Path (Join-Path $EvidenceRoot 'exact-sha-mcp-failure.json') -Value $failure -WriteSha256Sidecar | Out-Null
} finally {
    try { if (Test-Path -LiteralPath (Join-Path $root '.codex-godot/connection.json')) { & pwsh -NoProfile -File $StopScriptPath -Worktree $root -ShutdownTimeoutSeconds 30 2>&1 | Out-Null } } catch {}
    $null = Stop-Pr90McpStartupWatchdog -State $state -TimeoutSeconds 15
}
if ($null -ne $primaryFailure) { exit 2 }
Get-Content -Raw -LiteralPath (Join-Path $EvidenceRoot 'exact-sha-mcp-result.json')
